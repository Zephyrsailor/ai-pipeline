/**
 * bot.js — Discord 适配器
 *
 * 职责：
 * 1. 收 Discord 消息 → 调 Lobster 启动流水线
 * 2. Lobster 返回 needs_approval → 在 #dashboard 发审批 Embed + 按钮
 * 3. 用户点按钮 → 调 Lobster resume
 * 4. #dashboard 命令（状态、统计）
 *
 * 不含任何业务逻辑。编排由 Lobster 控制。
 */

import {
  Client, GatewayIntentBits, Partials,
  EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle,
} from 'discord.js';
import { readFileSync, readdirSync, existsSync } from 'fs';
import { execFile } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const ROOT = dirname(fileURLToPath(import.meta.url));
const LOBSTER = join(ROOT, '..', '..', '..', 'lab', 'lobster', 'bin', 'lobster.js');

// ── 加载配置 ──

for (const line of readFileSync(join(ROOT, '.env'), 'utf-8').split('\n')) {
  const m = line.match(/^([^#=]+)=(.+)$/);
  if (m) process.env[m[1].trim()] = m[2].trim();
}

const TOKEN = process.env.DISCORD_BOT_TOKEN;
if (!TOKEN) { console.error('缺少 DISCORD_BOT_TOKEN'); process.exit(1); }

const CHANNELS = JSON.parse(readFileSync(join(ROOT, 'config/channels.json'), 'utf-8')).discord;
const ROLES = JSON.parse(readFileSync(join(ROOT, 'config/roles.json'), 'utf-8'));
const idToRole = Object.fromEntries(Object.entries(CHANNELS).map(([k, v]) => [v, k]));

// 活跃流水线：slug → { resumeToken, approvalPhase }
const activePipelines = new Map();

// ── Discord Client ──

const client = new Client({
  intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages, GatewayIntentBits.MessageContent],
  partials: [Partials.Channel],
});

client.once('ready', () => console.log(`✅ Bot 上线: ${client.user.tag}`));

// ══════════════════════════════════════════════════════════════
// 消息路由
// ══════════════════════════════════════════════════════════════

client.on('messageCreate', async (msg) => {
  if (msg.author.bot) return;
  const parentId = msg.channel.isThread() ? msg.channel.parentId : msg.channelId;
  const role = idToRole[parentId];
  if (!role) return;

  const text = msg.content.trim();
  if (!text) return;

  if (role === 'product') return handleProduct(msg, text);
  if (role === 'dashboard') return handleDashboard(msg, text);
});

// ══════════════════════════════════════════════════════════════
// #product: 新需求 → 调 Lobster
// ══════════════════════════════════════════════════════════════

async function handleProduct(msg, text) {
  const m = text.match(/^(?:新项目|新需求|project)[：:\s]+(\S+)\s*([\s\S]*)/i);
  if (!m) return;

  const slug = m[1].toLowerCase().replace(/[^a-z0-9-]/g, '-');
  let body = m[2] || text;

  // 解析审批人
  const approvers = parseApprovers(body);
  // 清理审批人文本，剩下的就是需求描述
  body = body.replace(/(?:PRD|需求|设计|技术|测试|QA|发布|上线)审批[:：]\s*(?:<@!?\d+>\s*)*/gi, '').trim();
  const requirement = body || text;

  const user = {
    id: msg.author.id,
    name: msg.author.displayName || msg.author.username,
    channel: 'discord',
  };

  await msg.reply(`📋 收到！正在为 **${slug}** 启动研发流水线...`);

  // 调 Lobster 启动流水线
  const args = {
    slug,
    requirement,
    repo: '.',
    user_id: user.id,
    user_name: user.name,
    channel: 'discord',
  };

  runLobster('product-dev', args, slug);
}

function parseApprovers(text) {
  const approvers = {};
  const patterns = [
    { key: 'requirements', re: /(?:PRD|需求)审批[:：]\s*((?:<@!?\d+>\s*)+)/i },
    { key: 'design', re: /(?:设计|技术)审批[:：]\s*((?:<@!?\d+>\s*)+)/i },
    { key: 'testing', re: /(?:测试|QA)审批[:：]\s*((?:<@!?\d+>\s*)+)/i },
    { key: 'release', re: /(?:发布|上线)审批[:：]\s*((?:<@!?\d+>\s*)+)/i },
  ];
  for (const { key, re } of patterns) {
    const m = text.match(re);
    if (m) approvers[key] = [...m[1].matchAll(/<@!?(\d+)>/g)].map(x => x[1]);
  }
  return approvers;
}

// ══════════════════════════════════════════════════════════════
// Lobster 调用
// ══════════════════════════════════════════════════════════════

function runLobster(workflow, args, slug) {
  const argsJson = JSON.stringify(args);
  const cmd = [LOBSTER, 'run', '--mode', 'tool', '--file', `workflows/${workflow}.lobster`, '--args-json', argsJson];

  console.log(`[${slug}] 启动 Lobster: ${workflow}`);

  execFile('node', cmd, { cwd: ROOT, maxBuffer: 10 * 1024 * 1024, timeout: 600000 }, (err, stdout, stderr) => {
    if (stderr) process.stderr.write(stderr);

    let result;
    try { result = JSON.parse(stdout); } catch {
      console.error(`[${slug}] Lobster 输出解析失败:`, stdout?.slice(0, 200));
      return;
    }

    handleLobsterResult(slug, workflow, result);
  });
}

function resumeLobster(slug, token, approve) {
  const cmd = [LOBSTER, 'resume', '--token', token, '--approve', approve ? 'yes' : 'no'];

  console.log(`[${slug}] Lobster resume: ${approve ? 'approved' : 'rejected'}`);

  execFile('node', cmd, { cwd: ROOT, maxBuffer: 10 * 1024 * 1024, timeout: 600000 }, (err, stdout, stderr) => {
    if (stderr) process.stderr.write(stderr);

    let result;
    try { result = JSON.parse(stdout); } catch {
      console.error(`[${slug}] Lobster resume 解析失败:`, stdout?.slice(0, 200));
      return;
    }

    const pipeline = activePipelines.get(slug);
    handleLobsterResult(slug, pipeline?.workflow || 'product-dev', result);
  });
}

async function handleLobsterResult(slug, workflow, result) {
  if (!result.ok) {
    console.error(`[${slug}] Lobster 失败:`, JSON.stringify(result));
    return;
  }

  if (result.status === 'needs_approval') {
    // 存储 token，等用户审批
    const token = result.requiresApproval?.resumeToken;
    const prompt = result.requiresApproval?.prompt || '';

    // 推断当前审批阶段
    const phase = inferApprovalPhase(prompt);

    activePipelines.set(slug, { resumeToken: token, workflow, phase });

    // 在 #dashboard 发审批请求
    await postApprovalEmbed(slug, phase, prompt, result.requiresApproval);

    console.log(`[${slug}] 等待审批: ${phase}`);

  } else if (result.status === 'ok') {
    activePipelines.delete(slug);
    await postCompletionEmbed(slug);
    console.log(`[${slug}] ✅ 流水线完成`);
  }

  // 更新看板
  await updateBoard();
}

function inferApprovalPhase(prompt) {
  if (/prd|requirements|需求/i.test(prompt)) return 'requirements';
  if (/design|设计/i.test(prompt)) return 'design';
  if (/test|测试/i.test(prompt)) return 'testing';
  if (/release|发布/i.test(prompt)) return 'release';
  return 'unknown';
}

// ══════════════════════════════════════════════════════════════
// 按钮交互
// ══════════════════════════════════════════════════════════════

client.on('interactionCreate', async (interaction) => {
  if (!interaction.isButton()) return;

  const [action, slug] = interaction.customId.split(':');
  const pipeline = activePipelines.get(slug);

  if (action === 'approve' || action === 'reject') {
    if (!pipeline?.resumeToken) {
      return interaction.reply({ content: '⚠️ 该审批已过期或已处理', ephemeral: true });
    }

    // 权限校验
    const allowed = getApprovers(slug, pipeline.phase);
    if (allowed.length > 0 && !allowed.includes(interaction.user.id)) {
      return interaction.reply({
        content: `❌ 你不是该阶段的审批人。审批人：${allowed.map(id => `<@${id}>`).join(' ')}`,
        ephemeral: true,
      });
    }

    const userName = interaction.user.displayName || interaction.user.username;
    const approved = action === 'approve';

    // 更新 Embed
    await interaction.update({
      embeds: [buildResultEmbed(slug, pipeline.phase, approved, userName)],
      components: [],
    });

    // 调 Lobster resume
    resumeLobster(slug, pipeline.resumeToken, approved);
  }

  if (action === 'detail') {
    const state = loadState(slug);
    if (state) {
      await interaction.reply({ embeds: [buildProjectEmbed(state)], ephemeral: true });
    }
  }
});

// ══════════════════════════════════════════════════════════════
// #dashboard 命令
// ══════════════════════════════════════════════════════════════

async function handleDashboard(msg, text) {
  if (text === '状态' || text === '看板') return updateBoard(msg.channel);
  if (text === '统计') return postMetrics(msg.channel);

  // 查项目
  const state = loadState(text);
  if (state) return msg.reply({ embeds: [buildProjectEmbed(state)] });
}

// ══════════════════════════════════════════════════════════════
// Embed 构建
// ══════════════════════════════════════════════════════════════

async function postApprovalEmbed(slug, phase, prompt, approvalData) {
  const channel = await client.channels.fetch(CHANNELS.dashboard);
  const phaseConfig = ROLES.approval_phases[phase];
  const approverIds = getApprovers(slug, phase);
  const mentions = approverIds.length > 0
    ? approverIds.map(id => `<@${id}>`).join(' ')
    : `@${phaseConfig?.default_role || 'everyone'}`;

  const embed = new EmbedBuilder()
    .setColor(0xffaa00)
    .setTitle(`📋 [${slug}] ${phaseConfig?.name || phase} 待审批`)
    .setDescription(`${phaseConfig?.description || prompt}\n\n审批人：${mentions}`)
    .addFields(
      { name: '项目', value: slug, inline: true },
      { name: '阶段', value: phaseConfig?.name || phase, inline: true },
    )
    .setTimestamp();

  const row = new ActionRowBuilder().addComponents(
    new ButtonBuilder().setCustomId(`detail:${slug}`).setLabel('查看详情').setStyle(ButtonStyle.Secondary),
    new ButtonBuilder().setCustomId(`approve:${slug}`).setLabel('批准').setStyle(ButtonStyle.Success),
    new ButtonBuilder().setCustomId(`reject:${slug}`).setLabel('驳回').setStyle(ButtonStyle.Danger),
  );

  await channel.send({ content: mentions, embeds: [embed], components: [row] });
}

async function postCompletionEmbed(slug) {
  const channel = await client.channels.fetch(CHANNELS.dashboard);
  const embed = new EmbedBuilder()
    .setColor(0x00cc66)
    .setTitle(`🎉 [${slug}] 流水线完成`)
    .setDescription('所有阶段已完成！')
    .setTimestamp();
  await channel.send({ embeds: [embed] });
}

function buildResultEmbed(slug, phase, approved, userName) {
  const phaseConfig = ROLES.approval_phases[phase];
  return new EmbedBuilder()
    .setColor(approved ? 0x00cc66 : 0xcc3333)
    .setTitle(`${approved ? '✅' : '❌'} [${slug}] ${phaseConfig?.name || phase} ${approved ? '已批准' : '已驳回'}`)
    .setDescription(`由 ${userName} ${approved ? '批准' : '驳回'}`)
    .setTimestamp();
}

function buildProjectEmbed(state) {
  const phases = ['requirements', 'design', 'development', 'testing', 'release'];
  const names = { requirements: '需求', design: '设计', development: '开发', testing: '测试', release: '发布' };
  const icons = { completed: '🟢', in_progress: '🔵', pending: '⚪' };

  const pipeline = phases.map(p => {
    const s = state.phases[p]?.status || 'pending';
    const hasPendingApproval = activePipelines.get(state.project)?.phase === p;
    const icon = hasPendingApproval ? '🟡' : (icons[s] || '⚪');
    return `${icon} ${names[p]}`;
  }).join(' → ');

  return new EmbedBuilder()
    .setColor(0x5865F2)
    .setTitle(`📦 ${state.project}`)
    .setDescription(pipeline)
    .addFields(
      { name: '当前阶段', value: names[state.current_phase] || state.current_phase, inline: true },
      { name: '创建时间', value: state.created_at?.slice(0, 16) || 'N/A', inline: true },
    )
    .setTimestamp();
}

// ══════════════════════════════════════════════════════════════
// 看板（置顶自动更新）
// ══════════════════════════════════════════════════════════════

let boardMessageId = null;

async function updateBoard(channel) {
  if (!channel) {
    try { channel = await client.channels.fetch(CHANNELS.dashboard); } catch { return; }
  }
  const embed = buildBoardEmbed();
  if (boardMessageId) {
    try {
      const msg = await channel.messages.fetch(boardMessageId);
      await msg.edit({ embeds: [embed] });
      return;
    } catch { /* gone, create new */ }
  }
  const msg = await channel.send({ embeds: [embed] });
  boardMessageId = msg.id;
}

function buildBoardEmbed() {
  const projects = listProjects();
  const phases = ['requirements', 'design', 'development', 'testing', 'release'];
  const names = ['需求', '设计', '开发', '测试', '发布'];
  const icons = { completed: '●', in_progress: '◉', pending: '○' };

  let desc = '';
  if (projects.length === 0) {
    desc = '暂无项目。在 #product 频道发送\n`新项目：项目名 需求描述`\n来创建。';
  } else {
    for (const p of projects) {
      const state = loadState(p.project);
      if (!state) continue;
      const bar = phases.map(ph => {
        const s = state.phases[ph]?.status || 'pending';
        const waiting = activePipelines.get(p.project)?.phase === ph;
        return waiting ? '🟡' : (icons[s] || '○');
      }).join('━');
      desc += `**${p.project}**  ${bar}\n\`${names.join('  ')}\`\n\n`;
    }
  }

  const metrics = loadMetrics();

  return new EmbedBuilder()
    .setColor(0x5865F2)
    .setTitle('📊 研发指挥中心')
    .setDescription(desc)
    .setFooter({ text: `活跃: ${projects.length} | 完成: ${metrics.completed} | 成功率: ${metrics.successRate}` })
    .setTimestamp();
}

// ══════════════════════════════════════════════════════════════
// 统计
// ══════════════════════════════════════════════════════════════

async function postMetrics(channel) {
  const m = loadMetrics();
  const embed = new EmbedBuilder()
    .setColor(0x5865F2)
    .setTitle('📈 流水线统计')
    .addFields(
      { name: '总运行', value: `${m.total}`, inline: true },
      { name: '成功', value: `${m.completed}`, inline: true },
      { name: '成功率', value: m.successRate, inline: true },
      { name: '平均审查轮次', value: m.avgRounds, inline: true },
    )
    .setTimestamp();
  await channel.send({ embeds: [embed] });
}

// ══════════════════════════════════════════════════════════════
// 数据读取（只读，不写）
// ══════════════════════════════════════════════════════════════

function loadState(slug) {
  const f = join(ROOT, 'projects', slug, '.pipeline', 'state.json');
  try { return JSON.parse(readFileSync(f, 'utf-8')); } catch { return null; }
}

function listProjects() {
  const dir = join(ROOT, 'projects');
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter(d => existsSync(join(dir, d, '.pipeline', 'state.json')))
    .map(d => ({ project: d }));
}

function getApprovers(slug, phase) {
  const state = loadState(slug);
  return state?.approvers?.[phase] || [];
}

function loadMetrics() {
  const f = join(ROOT, 'data', 'metrics.tsv');
  if (!existsSync(f)) return { total: 0, completed: 0, successRate: 'N/A', avgRounds: 'N/A' };
  const lines = readFileSync(f, 'utf-8').trim().split('\n').slice(1);
  const total = lines.length;
  const completed = lines.filter(l => l.includes('\tsuccess\t')).length;
  const rounds = lines.map(l => parseInt(l.split('\t')[5]) || 0);
  const avg = rounds.length ? (rounds.reduce((a, b) => a + b, 0) / rounds.length).toFixed(1) : '0';
  return { total, completed, successRate: total ? `${Math.round(completed / total * 100)}%` : 'N/A', avgRounds: avg };
}

// ── 启动 ──

client.login(TOKEN);
