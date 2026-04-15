import test from 'node:test';
import assert from 'node:assert/strict';
import { server } from '../src/server.js';

async function req(path, options = {}) {
  const res = await fetch(`http://127.0.0.1:3430${path}`, options);
  return res;
}

test('API 主链路可用', async (t) => {
  await new Promise((resolve) => server.listen(3430, resolve));
  t.after(() => server.close());

  const health = await req('/api/v1/health');
  const h = await health.json();
  assert.equal(h.data.ok, true);

  const onchain = await req('/api/v1/onchain/data', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-user-id': 'u-admin' },
    body: JSON.stringify({ tenantId: 't1', chainId: 'evm-testnet', bizKey: 'b1', payload: { hello: 'world' } }),
  });
  const o = await onchain.json();
  assert.equal(Boolean(o.data.taskId), true);

  const explorer = await req('/api/v1/explorer/overview', { headers: { 'x-user-id': 'u-admin' } });
  const e = await explorer.json();
  assert.equal(Array.isArray(e.data), true);

  const forbidden = await req('/api/v1/contracts/deploy', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-user-id': 'u-ops' },
    body: JSON.stringify({ templateId: 'tpl', chainIds: ['evm-testnet'] }),
  });
  assert.equal(forbidden.status, 403);
});
