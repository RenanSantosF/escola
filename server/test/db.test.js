'use strict';
// Testes com PostgreSQL de verdade. Rodam só se TEST_DATABASE_URL existir:
//   TEST_DATABASE_URL=postgres://postgres@127.0.0.1:5499/recreio_test npm test
const test = require('node:test');
const assert = require('node:assert');
const WebSocket = require('ws');
const { createServer } = require('../src/server');
const { Database } = require('../src/db');

const URL = process.env.TEST_DATABASE_URL || '';
const skip = URL ? false : 'sem TEST_DATABASE_URL';
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

async function start() {
  const srv = createServer({ adminToken: 'x', dataDir: '', dbUrl: URL });
  assert.equal(await srv.ready, true);
  await new Promise((r) => srv.server.listen(0, r));
  return srv;
}
function hello(port, msg) {
  return new Promise((resolve) => {
    const ws = new WebSocket('ws://127.0.0.1:' + port);
    ws.on('open', () => ws.send(JSON.stringify(msg)));
    ws.on('message', (d) => {
      const m = JSON.parse(d.toString());
      if (m.t === 'welcome') resolve({ ws, m });
    });
  });
}

test('banco: limpa as tabelas', { skip }, async () => {
  const db = new Database({ url: URL });
  await db.init();
  await db.pool.query('truncate accounts, events, reports, mutes, blocks');
  await db.close();
});

test('banco: conta, denúncia, silêncio e estatísticas sobrevivem ao reinício', { skip }, async () => {
  let srv = await start();
  let port = srv.server.address().port;
  const a = await hello(port, { t: 'hello', age: 8, level: 4, mode: 'quick' });
  const b = await hello(port, { t: 'hello', age: 10, mode: 'quick' });
  b.ws.send(JSON.stringify({ t: 'report', target: a.m.id, reason: 'linguagem' }));
  await fetch('http://127.0.0.1:' + port + '/api/events', { method: 'POST', body: JSON.stringify({ uid: 'abcdef12', events: [{ type: 'session_start', data: { age: 8 } }, { type: 'purchase', data: { item: 'skin_ninja', name: 'Ninja', price: 600, category: 'skin' } }] }) });
  srv.safety.mute(a.m.id, 60000);
  await wait(300);
  a.ws.close(); b.ws.close();
  srv.close();
  await srv.db.close();

  // "deploy novo": servidor do zero, mesmo banco
  srv = await start();
  port = srv.server.address().port;
  const again = await hello(port, { t: 'hello', token: a.m.token, age: 8, mode: 'quick' });
  assert.equal(again.m.id, a.m.id);
  assert.equal(again.m.name, a.m.name);
  assert.ok(srv.safety.isMuted(a.m.id));
  const st = await (await fetch('http://127.0.0.1:' + port + '/api/admin/stats', { headers: { 'x-admin-token': 'x' } })).json();
  assert.equal(st.storage, 'banco PostgreSQL');
  assert.equal(st.purchases.biggest[0].price, 600);
  assert.ok(st.reports.some((r) => r.targetId === a.m.id && r.reason === 'linguagem'));
  assert.ok(st.db.accounts >= 2);
  const health = await (await fetch('http://127.0.0.1:' + port + '/health')).json();
  assert.equal(health.db, true);
  again.ws.close();
  srv.close();
  await srv.db.close();
});

test('banco: token guardado só como hash', { skip }, async () => {
  const db = new Database({ url: URL });
  await db.init();
  const r = await db.pool.query('select token_hash from accounts limit 1');
  assert.match(r.rows[0].token_hash, /^[a-f0-9]{64}$/);
  await db.close();
});

test('banco: conta registrada e progresso voltam depois do deploy; recuperação no banco', { skip }, async () => {
  let srv = await start();
  let base = 'http://127.0.0.1:' + srv.server.address().port;
  const { names } = await (await fetch(base + '/api/account/names')).json();
  const reg = await (await fetch(base + '/api/account/register', { method: 'POST', body: JSON.stringify({ name: names[1], age: 11 }) })).json();
  await fetch(base + '/api/progress', { method: 'PUT', headers: { 'x-token': reg.token }, body: JSON.stringify({ save: { player: { coins: 777, level: 5 } }, savedAt: Date.now() }) });
  await wait(200);
  srv.close();
  await srv.db.close();
  srv = await start();
  base = 'http://127.0.0.1:' + srv.server.address().port;
  const me = await (await fetch(base + '/api/account/me', { headers: { 'x-token': reg.token } })).json();
  assert.equal(me.account.progress.player.coins, 777);
  const rec = await (await fetch(base + '/api/account/recover', { method: 'POST', body: JSON.stringify({ code: reg.code }) })).json();
  assert.ok(rec.ok);
  assert.equal(rec.account.progress.player.coins, 777);
  srv.close();
  await srv.db.close();
});


test('banco: nome+senha sobrevivem ao deploy e o nome continua único', { skip }, async () => {
  let srv = await start();
  let base = 'http://127.0.0.1:' + srv.server.address().port;
  const nm = 'Tester_' + Math.floor(Math.random() * 9000 + 1000);
  const r = await (await fetch(base + '/api/account/signup', { method: 'POST', body: JSON.stringify({ name: nm, password: 'senha123', age: 10 }) })).json();
  assert.ok(r.ok);
  await wait(200);
  srv.close();
  await srv.db.close();
  srv = await start();
  base = 'http://127.0.0.1:' + srv.server.address().port;
  const c = await (await fetch(base + '/api/account/check?name=' + nm.toLowerCase())).json();
  assert.equal(c.available, false);
  const l = await fetch(base + '/api/account/login', { method: 'POST', body: JSON.stringify({ name: nm, password: 'senha123' }) });
  assert.equal(l.status, 200);
  srv.close();
  await srv.db.close();
});
