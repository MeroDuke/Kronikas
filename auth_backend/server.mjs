import { createHash, randomBytes } from 'node:crypto';
import { createServer } from 'node:http';
import { pathToFileURL } from 'node:url';

const lifetime = 5 * 60_000;
const random = () => randomBytes(32).toString('base64url');
const callbackPath = '/github/callback';

export function createAuthServer({ clientId, clientSecret, publicUrl, fetchToken = fetch }) {
  const callback = new URL(callbackPath, publicUrl);
  if (!clientId || !clientSecret || callback.protocol !== 'https:') {
    throw new Error('GitHub App credentials and an HTTPS public URL are required.');
  }

  const flows = new Map();
  const states = new Map();

  function remove(flow) {
    clearTimeout(flow.timer);
    flows.delete(flow.ticket);
    states.delete(flow.state);
  }

  const server = createServer(async (request, response) => {
    let path;
    try {
      path = new URL(request.url, callback);
    } catch {
      response.writeHead(400).end();
      return;
    }
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('Referrer-Policy', 'no-referrer');
    response.setHeader('X-Content-Type-Options', 'nosniff');

    function json(status, value) {
      response.writeHead(status, { 'Content-Type': 'application/json' });
      response.end(JSON.stringify(value));
    }

    function finish(status, message) {
      response.writeHead(status, { 'Content-Type': 'text/plain; charset=utf-8' });
      response.end(message);
    }

    if (request.method === 'POST' && path.pathname === '/github/start') {
      for (const flow of flows.values()) {
        if (flow.expires <= Date.now()) remove(flow);
      }
      if (flows.size >= 256) return json(503, { status: 'busy' });

      const flow = {
        ticket: random(), state: random(), verifier: random(),
        expires: Date.now() + lifetime, status: 'pending',
      };
      flow.timer = setTimeout(() => remove(flow), lifetime).unref();
      flows.set(flow.ticket, flow);
      states.set(flow.state, flow);
      const authorize = new URL('https://github.com/login/oauth/authorize');
      authorize.search = new URLSearchParams({
        client_id: clientId, redirect_uri: callback.href, state: flow.state,
        code_challenge: createHash('sha256').update(flow.verifier).digest('base64url'),
        code_challenge_method: 'S256', scope: 'offline_access',
      });
      return json(201, { ticket: flow.ticket, authorizeUrl: authorize.href });
    }

    if (request.method === 'POST' && path.pathname === '/github/result') {
      const flow = flows.get((request.headers.authorization ?? '').replace(/^Bearer /, ''));
      if (!flow || flow.expires <= Date.now()) {
        if (flow) remove(flow);
        return json(404, { status: 'expired' });
      }
      if (flow.status === 'pending') return json(202, { status: 'pending' });
      remove(flow);
      return json(200, { status: flow.status, token: flow.token });
    }

    if (request.method === 'GET' && path.pathname === callbackPath) {
      const flow = states.get(path.searchParams.get('state'));
      if (!flow || flow.expires <= Date.now()) return finish(400, 'A bejelentkezés lejárt.');
      states.delete(flow.state);
      const code = path.searchParams.get('code');
      if (path.searchParams.has('error') || !code) {
        flow.status = 'denied';
        return finish(400, 'A GitHub-hozzáférést nem engedélyezted. Térj vissza a Krónikásba.');
      }
      try {
        const upstream = await fetchToken('https://github.com/login/oauth/access_token', {
          method: 'POST',
          headers: { Accept: 'application/json', 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({
            client_id: clientId, client_secret: clientSecret, code,
            redirect_uri: callback.href, code_verifier: flow.verifier,
          }),
          signal: AbortSignal.timeout(15_000),
        });
        const result = await upstream.json();
        if (!upstream.ok || typeof result.access_token !== 'string' ||
            !result.access_token.startsWith('ghu_') || !Number.isFinite(result.expires_in) ||
            result.expires_in <= 0 || flow.expires <= Date.now()) {
          throw new Error('GitHub token exchange failed.');
        }
        flow.token = result.access_token;
        flow.status = 'authorized';
        return finish(200, 'GitHub csatlakoztatva. Térj vissza a Krónikásba a repó kiválasztásához.');
      } catch {
        flow.status = 'failed';
        return finish(502, 'A GitHub-belépés sikertelen. Térj vissza a Krónikásba, és próbáld újra.');
      }
    }

    return json(404, { status: 'not-found' });
  });
  server.on('close', () => {
    for (const flow of flows.values()) remove(flow);
  });
  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  createAuthServer({
    clientId: process.env.GITHUB_APP_CLIENT_ID,
    clientSecret: process.env.GITHUB_APP_CLIENT_SECRET,
    publicUrl: process.env.KRONIKAS_AUTH_PUBLIC_URL,
  }).listen(Number(process.env.PORT ?? 8080), '0.0.0.0');
}
