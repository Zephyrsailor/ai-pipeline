import http from 'node:http';
import { fileURLToPath } from 'node:url';
import { parseJson, json, response, error } from './utils/http.js';
import { submitOnchain, getOnchainTask } from './services/onchainService.js';
import { overview, search } from './services/explorerService.js';
import { deployContract, getDeployJob } from './services/contractService.js';
import { listChainsAndNodes, setNodeHealth, alerts } from './services/chainOpsService.js';
import { registerDid, revokeDid, listDid } from './services/didService.js';
import { authorize } from './iam/rbac.js';
import { appendAudit, listAudits } from './services/auditService.js';

const port = Number(process.env.PORT || 3300);

function requirePerm(req, perm) {
  const userId = req.headers['x-user-id'] || 'u-admin';
  if (!authorize(String(userId), perm)) return { ok: false, userId };
  return { ok: true, userId };
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const requestId = req.headers['x-request-id'] || `req-${Date.now()}`;

  if (req.method === 'GET' && url.pathname === '/api/v1/health') {
    return json(res, 200, response({ service: 'baas-crosschain-platform', ok: true }, requestId));
  }

  if (req.method === 'POST' && url.pathname === '/api/v1/onchain/data') {
    const auth = requirePerm(req, 'onchain:write');
    if (!auth.ok) return json(res, 403, error('forbidden', 403, requestId));
    const body = await parseJson(req);
    const task = submitOnchain(body);
    appendAudit({ actor: auth.userId, action: 'onchain.submit', resource: task.taskId });
    return json(res, 200, response(task, requestId));
  }

  if (req.method === 'GET' && url.pathname.startsWith('/api/v1/onchain/tasks/')) {
    const auth = requirePerm(req, 'onchain:read');
    if (!auth.ok) return json(res, 403, error('forbidden', 403, requestId));
    const taskId = url.pathname.split('/').pop();
    const task = getOnchainTask(taskId);
    if (!task) return json(res, 404, error('task not found', 404, requestId));
    return json(res, 200, response(task, requestId));
  }

  if (req.method === 'GET' && url.pathname === '/api/v1/explorer/overview') {
    const auth = requirePerm(req, 'explorer:read');
    if (!auth.ok) return json(res, 403, error('forbidden', 403, requestId));
    return json(res, 200, response(overview(), requestId));
  }

  if (req.method === 'GET' && url.pathname === '/api/v1/explorer/search') {
    const auth = requirePerm(req, 'explorer:read');
    if (!auth.ok) return json(res, 403, error('forbidden', 403, requestId));
    return json(res, 200, response(search(url.searchParams.get('q') || ''), requestId));
  }

  if (req.method === 'POST' && url.pathname === '/api/v1/contracts/deploy') {
    const auth = requirePerm(req, 'contract:deploy');
    if (!auth.ok) return json(res, 403, error('forbidden', 403, requestId));
    const body = await parseJson(req);
    const job = deployContract(body);
    appendAudit({ actor: auth.userId, action: 'contract.deploy', resource: job.jobId });
    return json(res, 200, response(job, requestId));
  }

  if (req.method === 'GET' && url.pathname.startsWith('/api/v1/contracts/jobs/')) {
    const id = url.pathname.split('/').pop();
    const job = getDeployJob(id);
    if (!job) return json(res, 404, error('job not found', 404, requestId));
    return json(res, 200, response(job, requestId));
  }

  if (req.method === 'GET' && url.pathname === '/api/v1/chainops') {
    return json(res, 200, response(listChainsAndNodes(), requestId));
  }

  if (req.method === 'POST' && url.pathname === '/api/v1/chainops/node/health') {
    const body = await parseJson(req);
    const node = setNodeHealth(body.nodeId, body.healthy);
    if (!node) return json(res, 404, error('node not found', 404, requestId));
    return json(res, 200, response(node, requestId));
  }

  if (req.method === 'GET' && url.pathname === '/api/v1/chainops/alerts') {
    return json(res, 200, response(alerts(), requestId));
  }

  if (req.method === 'POST' && url.pathname === '/api/v1/did/register') {
    const body = await parseJson(req);
    return json(res, 200, response(registerDid(body), requestId));
  }

  if (req.method === 'POST' && url.pathname === '/api/v1/did/revoke') {
    const body = await parseJson(req);
    const did = revokeDid(body.did);
    if (!did) return json(res, 404, error('did not found', 404, requestId));
    return json(res, 200, response(did, requestId));
  }

  if (req.method === 'GET' && url.pathname === '/api/v1/did/list') {
    return json(res, 200, response(listDid(), requestId));
  }

  if (req.method === 'GET' && url.pathname === '/api/v1/audit/logs') {
    return json(res, 200, response(listAudits(100), requestId));
  }

  return json(res, 404, error('not found', 404, requestId));
});

const isDirect = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isDirect) {
  server.listen(port, () => {
    console.log(`baas-crosschain-platform listening on http://localhost:${port}`);
  });
}

export { server };
