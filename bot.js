import { Client, GatewayIntentBits, Partials } from 'discord.js';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { execFile, spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const ROOT = dirname(fileURLToPath(import.meta.url));

// ── 加载配置 ──

const envFile = readFileSync(join(ROOT, '.env'), 'utf-8');
for (const line of envFile.split('\n')) {
  const m = line.match(/^([^#=]+)=(.+)$/);
  if (m) process.env[m[1].trim()] = m[2].trim();
}

const TOKEN = process.env.DISCORD_BOT_TOKEN;
if (!TOKEN) { console.error('缺少 DISCORD_BOT_TOKEN'); process.exit(1); }

const CHANNEL_IDS = JSON.parse(readFileSync(join(ROOT, 'config/channels.json'), 'utf-8')).discord;

// channel ID → 频道角色
const idToRole = Object.fromEntries(Object.entries(CHANNEL_IDS).map(([k, v]) => [v, k]));

// ── Discord Client ──

const client = new Client({
  intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages, GatewayIntentBits.MessageContent],
  partials: [Partials.Channel],
});

client.once('ready', () => {
  console.log(`✅ Bot 上线: ${client.user.tag}`);
  console.log(`📡 监听频道: ${Object.keys(CHANNEL_IDS).join(', ')}`);
});

// ── 消息路由 ──

client.on('messageCreate', async (msg) => {
  if (msg.author.bot) return;

  // 获取父频道角色（Thread 里的消息取 parent channel）
  const parentId = msg.channel.isThread() ? msg.channel.parentId : msg.channelId;
  const role = idToRole[parentId];
  if (!role) return;

  const text = msg.content.trim();
  if (!text) return;

  const user = { id: msg.author.id, name: msg.author.displayName || msg.author.username };
  console.log(`[#${role}] ${user.name}: ${text.slice(0, 60)}`);

  if (role === 'product') return handleProduct(msg, text, user);
  if (role === 'bugs') return handleBug(msg, text, user);
});

// ── #product: 新需求 → 研发流水线 ──

async function handleProduct(msg, text, user) {
  // 解析 slug: "新项目：hello-cli 做一个打招呼工具" 或纯描述
  const m = text.match(/^(?:新项目|新需求|project)[：:\s]+(\S+)\s*([\s\S]*)/i);
  const slug = m ? m[1].toLowerCase().replace(/[^a-z0-9-]/g, '-') : `proj-${Date.now().toString(36).slice(-6)}`;
  const requirement = m ? (m[2] || text) : text;

  await msg.reply(`📋 收到！正在为 **${slug}** 启动研发流水线...\n各频道讨论区会同步更新进度。`);

  // 全部异步，不阻塞 bot
  pipeline(slug, requirement, user);
}

async function handleBug(msg, text, user) {
  const slug = `bug-${Date.now().toString(36).slice(-6)}`;
  await msg.reply(`🐛 收到 Bug 报告！排查流程 **${slug}** 已启动。`);
  // TODO: bugfix pipeline
  console.log(`[bot] bugfix 流程待实现: ${slug}`);
}

// ── 流水线编排 ──

async function pipeline(slug, requirement, user) {
  try {
    // 1. Init
    console.log(`[${slug}] ➜ init`);
    await run('./bin/init-project.sh', { SLUG: slug });

    // 2. PM Agent → PRD
    console.log(`[${slug}] ➜ requirements`);
    const prdRaw = await run('./bin/requirements.sh', {
      REPO: '.', REQUIREMENT: requirement, PROJECT_NAME: slug, REQUEST_ID: slug,
    });

    // 保存 PRD
    const prdJson = extractJson(prdRaw);
    const prdPath = join(ROOT, 'projects', slug, 'docs', 'prd.md');
    mkdirSync(dirname_of(prdPath), { recursive: true });
    writeFileSync(prdPath, prdJson);

    // Handoff → design
    console.log(`[${slug}] ➜ handoff requirements → design`);
    await run('./bin/save-and-handoff.sh', {
      SLUG: slug, SUMMARY: '需求文档已完成', USER_ID: user.id, USER_NAME: user.name, CHANNEL: 'discord',
    });

    // 3. Architect Agent → Design
    console.log(`[${slug}] ➜ design`);
    const designRaw = await run('./bin/design.sh', { REPO: '.', REQUEST_ID: slug }, prdJson);

    const designJson = extractJson(designRaw);
    const designPath = join(ROOT, 'projects', slug, 'docs', 'tech-design.md');
    writeFileSync(designPath, designJson);

    // Handoff → development
    console.log(`[${slug}] ➜ handoff design → development`);
    await run('./bin/save-and-handoff.sh', {
      SLUG: slug, SUMMARY: '技术设计已完成', USER_ID: user.id, USER_NAME: user.name, CHANNEL: 'discord',
    });

    // 4. Task Breakdown
    console.log(`[${slug}] ➜ task-breakdown`);
    const tasksRaw = await run('./bin/task-breakdown.sh', { REPO: '.', REQUEST_ID: slug }, designJson);
    const tasksJson = extractJson(tasksRaw);

    // 5. Developer Agent
    console.log(`[${slug}] ➜ develop`);
    await run('./bin/develop.sh', { REPO: '.', REQUEST_ID: slug }, tasksJson);

    // 6. Review Loop
    console.log(`[${slug}] ➜ review`);
    const reviewResult = await run('./bin/review-loop.sh', { REPO: '.', REQUEST_ID: slug, MAX_ROUNDS: '3' });

    // 7. Testing
    console.log(`[${slug}] ➜ test`);
    await run('./bin/test.sh', { REPO: '.', REQUEST_ID: slug }, prdJson);

    // 8. Metrics
    console.log(`[${slug}] ➜ metrics`);
    await run('./bin/log-metric.sh', { REQUEST_ID: slug, WORKFLOW: 'product-dev' }, reviewResult);

    console.log(`[${slug}] ✅ 流水线完成`);

  } catch (err) {
    console.error(`[${slug}] ❌ 流水线出错:`, err.message);
  }
}

// ── 工具函数 ──

function run(script, env = {}, stdin = '') {
  return new Promise((resolve, reject) => {
    const child = spawn(script, [], {
      env: { ...process.env, ...env },
      cwd: ROOT,
      shell: true,
    });

    let stdout = '';
    let stderr = '';

    if (stdin) child.stdin.write(stdin);
    child.stdin.end();

    child.stdout.on('data', (d) => { stdout += d; });
    child.stderr.on('data', (d) => {
      stderr += d;
      process.stderr.write(d); // 实时输出到终端
    });

    child.on('close', (code) => {
      if (code !== 0 && !stdout) reject(new Error(`${script} exited ${code}: ${stderr.slice(-200)}`));
      else resolve(stdout);
    });
  });
}

function extractJson(text) {
  // ```json ... ``` 块
  const m = text.match(/```json\n([\s\S]*?)\n```/);
  if (m) { try { JSON.parse(m[1]); return m[1]; } catch {} }
  // 直接 JSON
  try { JSON.parse(text); return text; } catch {}
  // 最后一行 JSON
  const last = text.split('\n').filter(l => l.startsWith('{')).pop();
  if (last) { try { JSON.parse(last); return last; } catch {} }
  return text;
}

function dirname_of(p) { return p.replace(/\/[^/]+$/, ''); }

// ── 启动 ──

client.login(TOKEN);
