export function json(res, code, data) {
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(data));
}

export async function parseJson(req) {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  const raw = Buffer.concat(chunks).toString('utf8') || '{}';
  return JSON.parse(raw);
}

export function response(data, requestId = '') {
  return { code: 0, message: 'ok', data, requestId };
}

export function error(message, code = 1, requestId = '') {
  return { code, message, data: null, requestId };
}
