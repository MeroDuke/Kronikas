import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { once } from 'node:events';
import test from 'node:test';

import { createAuthServer } from './server.mjs';

test('GitHub callback is bound to state and delivers the expiring token once', async (t) => {
  let exchanged;
  const server = createAuthServer({
    clientId: 'fixture-app',
    clientSecret: 'fixture-secret',
    publicUrl: 'https://auth.example',
    fetchToken: async (url, options) => {
      exchanged = { url, body: options.body };
      return Response.json({ access_token: 'ghu_fixture', expires_in: 3600 });
    },
  }).listen(0, '127.0.0.1');
  t.after(() => { server.closeAllConnections(); server.close(); });
  await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;
  const request = (path, ticket) => fetch(base + path, {
    method: 'POST',
    headers: ticket ? { Authorization: `Bearer ${ticket}` } : {},
  });

  const start = await request('/github/start');
  assert.equal(start.status, 201);
  assert.equal(start.headers.get('Cache-Control'), 'no-store');
  const { ticket, authorizeUrl } = await start.json();
  const authorize = new URL(authorizeUrl);
  const state = authorize.searchParams.get('state');
  assert.notEqual(ticket, state);
  assert.equal(authorize.searchParams.get('code_challenge_method'), 'S256');
  assert.equal((await request('/github/result', ticket)).status, 202);
  assert.equal((await request('/github/result', state)).status, 404);
  assert.equal((await fetch(base + '/github/callback?state=invalid&code=fixture')).status, 400);
  assert.equal(exchanged, undefined);

  const callback = `/github/callback?state=${state}&code=fixture`;
  const approved = await fetch(base + callback);
  assert.equal(approved.status, 200);
  assert.equal((await approved.text()).includes('ghu_fixture'), false);
  assert.equal(exchanged.body.get('client_secret'), 'fixture-secret');
  const challenge = createHash('sha256').update(exchanged.body.get('code_verifier')).digest('base64url');
  assert.equal(challenge, authorize.searchParams.get('code_challenge'));
  assert.equal((await fetch(base + callback)).status, 400);
  assert.deepEqual(await (await request('/github/result', ticket)).json(),
    { status: 'authorized', token: 'ghu_fixture' });
  assert.equal((await request('/github/result', ticket)).status, 404);

  const denied = await (await request('/github/start')).json();
  const deniedState = new URL(denied.authorizeUrl).searchParams.get('state');
  assert.equal((await fetch(base + `/github/callback?state=${deniedState}&error=access_denied`)).status, 400);
  assert.deepEqual(await (await request('/github/result', denied.ticket)).json(), { status: 'denied' });
});
