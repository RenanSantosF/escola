'use strict';
const test = require('node:test');
const assert = require('node:assert');
const WebSocket = require('ws');
const { check } = require('../src/chat_filter');
const { Safety } = require('../src/safety');
const { RoomManager, MAX_PER_ROOM } = require('../src/rooms');
const { Accounts } = require('../src/accounts');
const { createServer } = require('../src/server');

test('filtro de chat bloqueia palavrões, disfarces e dados pessoais', () => {
  assert.equal(check('Bora jogar bola?').ok, true);
  assert.equal(check('seu idiota').ok, false);
  assert.equal(check('1d1ot4').ok, false);
  assert.equal(check('meu zap 11 98765-4321').ok, false);
  assert.equal(check('manda email pra mim a@b.com').ok, false);
  assert.equal(check('entra em www.site.com').ok, false);
  assert.equal(check('').ok, false);
  assert.equal(check('VAMOS JOGAR AGORA').text, 'vamos jogar agora');
});

test('segurança: limite, auto-silêncio e denúncias', () => {
  const s = new Safety();
  const t = 1000;
  for (let i = 0; i < 5; i++) assert.equal(s.canSend('a', t), null);
  assert.ok(s.canSend('a', t));
  assert.equal(s.canSend('a', t + 11000), null);
  assert.equal(s.onBlockedMessage('b', t), false);
  s.onBlockedMessage('b', t);
  assert.equal(s.onBlockedMessage('b', t), true);
  assert.ok(s.isMuted('b', t + 1));
  assert.equal(s.report('x', 'x', 'outro').ok, false);
  s.report('r1', 'c', 'linguagem');
  s.report('r1', 'c', 'linguagem');
  assert.equal(s.isMuted('c'), false);
  s.report('r2', 'c', 'linguagem');
  assert.equal(s.report('r3', 'c', 'assedio').autoMuted, true);
  s.block('a', 'b');
  assert.ok(s.isBlocked('b', 'a'));
});

test('salas: entrada rápida, lotação, criar e entrar com código', () => {
  const rm = new RoomManager();
  const codes = new Set();
  for (let i = 0; i < MAX_PER_ROOM + 1; i++) codes.add(rm.quick({ id: 'p' + i }).code);
  assert.equal(codes.size, 2);
  const first = rm.get([...codes][0]);
  assert.equal(first.snapshot('p0').length, MAX_PER_ROOM - 1);
  const priv = rm.create({ id: 'dono' });
  assert.equal(priv.private, true);
  assert.match(priv.code, /^\d{4}$/);
  // entrada rápida nunca cai em sala privada
  for (let i = 0; i < 5; i++) assert.notEqual(rm.quick({ id: 'q' + i }).code, priv.code);
  assert.equal(rm.joinCode({ id: 'amigo' }, priv.code).code, priv.code);
  assert.ok(rm.joinCode({ id: 'x' }, '0000').error);
  assert.ok(rm.publicList().every((r) => !r.private));
});

test('estatísticas: sessões, idades e compras', () => {
  const { Analytics } = require('../src/analytics');
  const a = new Analytics({ dataDir: '' });
  const now = Date.now();
  assert.equal(a.ingest('nao-hex!', [{ type: 'session_start' }]), 0);
  a.ingest('aaaa1111', [{ type: 'session_start', at: now, data: { age: 8, level: 2 } }, { type: 'purchase', data: { item: 'vei_bike', name: 'Bicicleta', price: 2000, category: 'veiculo' } }, { type: 'session_end', data: { seconds: 600 } }]);
  a.ingest('bbbb2222', [{ type: 'session_start', data: { age: 11 } }, { type: 'purchase', data: { item: 'bone', name: 'Boné', price: 40, category: 'acessorio' } }, { type: 'session_end', data: { seconds: 1200 } }, { type: 'tipo_invalido' }]);
  const st = a.stats({ online: 3 });
  assert.equal(st.players.total, 2);
  assert.equal(st.ages[8], 1);
  assert.equal(st.sessions.avgMinutes, 15);
  assert.equal(st.purchases.biggest[0].price, 2000);
  assert.equal(st.purchases.smallest[0].price, 40);
  assert.equal(st.purchases.coins, 2040);
  assert.equal(st.live.online, 3);
});

test('contas: token volta à mesma conta, chat livre só 13+', () => {
  const a = new Accounts();
  const acc = a.getOrCreate('', { age: 8, level: 3 });
  assert.equal(a.getOrCreate(acc.token, { level: 5 }).id, acc.id);
  assert.equal(acc.level, 5);
  assert.equal(a.canFreeChat(acc), false);
  assert.equal(a.canFreeChat(a.getOrCreate('', { age: 14 })), true);
});

function connect(port) {
  return new Promise((resolve) => {
    const ws = new WebSocket('ws://127.0.0.1:' + port);
    const inbox = [];
    ws.on('message', (d) => inbox.push(JSON.parse(d.toString())));
    ws.on('open', () => resolve({ ws, inbox }));
  });
}
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

test('servidor: painel protegido e eventos', async () => {
  const srv = createServer({ adminToken: 'segredo', dataDir: '' });
  await new Promise((r) => srv.server.listen(0, r));
  const base = 'http://127.0.0.1:' + srv.server.address().port;
  assert.equal((await fetch(base + '/api/admin/stats')).status, 403);
  const ev = await fetch(base + '/api/events', { method: 'POST', body: JSON.stringify({ uid: 'abcd1234', events: [{ type: 'session_start', data: { age: 9 } }] }) });
  assert.equal((await ev.json()).accepted, 1);
  const st = await (await fetch(base + '/api/admin/stats', { headers: { 'x-admin-token': 'segredo' } })).json();
  assert.equal(st.players.total, 1);
  const html = await (await fetch(base + '/admin')).text();
  assert.ok(html.includes('Painel'));
  srv.close();
});

test('servidor: criar sala e amigo entra pelo código', async () => {
  const srv = createServer({ adminToken: 'x', dataDir: '' });
  await new Promise((r) => srv.server.listen(0, r));
  const port = srv.server.address().port;
  const a = await connect(port);
  a.ws.send(JSON.stringify({ t: 'hello', age: 9, mode: 'create' }));
  await wait(60);
  const wa = a.inbox.find((m) => m.t === 'welcome');
  assert.ok(wa.private && /^\d{4}$/.test(wa.code));
  const b = await connect(port);
  b.ws.send(JSON.stringify({ t: 'hello', age: 9, mode: 'code', code: '0001' }));
  await wait(60);
  assert.ok(b.inbox.some((m) => m.t === 'join_error'));
  b.ws.send(JSON.stringify({ t: 'hello', age: 9, mode: 'code', code: wa.code }));
  await wait(60);
  const wb = b.inbox.find((m) => m.t === 'welcome');
  assert.equal(wb.code, wa.code);
  const c = await connect(port);
  c.ws.send(JSON.stringify({ t: 'hello', age: 9, mode: 'quick' }));
  await wait(60);
  assert.notEqual(c.inbox.find((m) => m.t === 'welcome').code, wa.code);
  a.ws.close(); b.ws.close(); c.ws.close();
  srv.close();
});

test('servidor: hello, estados, frases rápidas e chat bloqueado para menores', async () => {
  const srv = createServer({ adminToken: 'x', dataDir: '' });
  await new Promise((r) => srv.server.listen(0, r));
  const port = srv.server.address().port;
  const a = await connect(port);
  const b = await connect(port);
  a.ws.send(JSON.stringify({ t: 'hello', age: 9, level: 2 }));
  await wait(50);
  b.ws.send(JSON.stringify({ t: 'hello', age: 9 }));
  await wait(50);
  const wa = a.inbox.find((m) => m.t === 'welcome');
  const wb = b.inbox.find((m) => m.t === 'welcome');
  assert.equal(wa.room, wb.room);
  assert.equal(wb.players.length, 1); // b viu a ao entrar no meio
  assert.ok(a.inbox.some((m) => m.t === 'join'));
  a.ws.send(JSON.stringify({ t: 'state', pos: [1, 0, 2], yaw: 1, anim: 'run' }));
  a.ws.send(JSON.stringify({ t: 'quick', i: 0 }));
  a.ws.send(JSON.stringify({ t: 'chat', text: 'oi' }));
  await wait(250);
  assert.ok(b.inbox.some((m) => m.t === 'states' && m.list.some((s) => s.id === wa.id)));
  assert.ok(b.inbox.some((m) => m.t === 'chat' && m.text === 'Oi! Tudo bem?'));
  assert.ok(!b.inbox.some((m) => m.t === 'chat' && m.text === 'oi'));
  assert.ok(a.inbox.some((m) => m.t === 'notice'));
  // bloqueio: b bloqueia a e não recebe mais mensagens
  b.ws.send(JSON.stringify({ t: 'block', target: wa.id }));
  await wait(50);
  b.inbox.length = 0;
  a.ws.send(JSON.stringify({ t: 'quick', i: 1 }));
  await wait(100);
  assert.ok(!b.inbox.some((m) => m.t === 'chat'));
  a.ws.close(); b.ws.close();
  srv.close();
});

test('pique-pega: lobby, sorteio, pegar, imunidade e resultado', () => {
  const { TagGame } = require('../src/tag_game');
  const g = new TagGame({}, 0);
  g.invite('a', 0);
  g.join('b');
  g.join('c');
  const pos = { a: [0, 0, 0], b: [10, 0, 0], c: [20, 0, 0] };
  let ev = g.tick((id) => pos[id], 25000);
  assert.equal(ev[0].kind, 'start');
  assert.equal(g.state, 'playing');
  g.it = 'a'; g.itSince = 25000; g.lastTagAt = 0; g.lastTagger = null;
  pos.b = [1, 0, 0]; // b encostou no pegador
  ev = g.tick((id) => pos[id], 30000);
  assert.deepEqual(ev[0], { kind: 'tagged', from: 'a', to: 'b' });
  assert.equal(g.it, 'b');
  // não vale pegar de volta logo em seguida
  ev = g.tick((id) => pos[id], 31500);
  assert.equal(ev.length, 0);
  ev = g.tick((id) => pos[id], 34000);
  assert.equal(ev[0].to, 'a');
  ev = g.tick((id) => pos[id], 30000 + 125000);
  assert.equal(ev[0].kind, 'end');
  assert.equal(ev[0].results[0].id, 'c'); // c nunca foi pegador
});

test('pique-pega: cancela sem jogadores suficientes', () => {
  const { TagGame } = require('../src/tag_game');
  const g = new TagGame({}, 0);
  g.invite('a', 0);
  const ev = g.tick(() => [0, 0, 0], 21000);
  assert.equal(ev[0].kind, 'cancel');
});

test('servidor: canal Perto, reações e convite de pique-pega', async () => {
  const srv = createServer({ adminToken: 'x', dataDir: '' });
  await new Promise((r) => srv.server.listen(0, r));
  const port = srv.server.address().port;
  const [a, b, c] = [await connect(port), await connect(port), await connect(port)];
  for (const p of [a, b, c]) { p.ws.send(JSON.stringify({ t: 'hello', age: 9, mode: 'quick' })); await wait(40); }
  a.ws.send(JSON.stringify({ t: 'state', pos: [0, 0, 0], yaw: 0, anim: 'idle' }));
  b.ws.send(JSON.stringify({ t: 'state', pos: [5, 0, 0], yaw: 0, anim: 'idle' }));
  c.ws.send(JSON.stringify({ t: 'state', pos: [80, 0, 0], yaw: 0, anim: 'idle' }));
  await wait(60);
  a.ws.send(JSON.stringify({ t: 'quick', i: 1, ch: 'near' }));
  a.ws.send(JSON.stringify({ t: 'emote', name: 'wave' }));
  a.ws.send(JSON.stringify({ t: 'tag_invite' }));
  await wait(120);
  assert.ok(b.inbox.some((m) => m.t === 'chat' && m.ch === 'near'));
  assert.ok(!c.inbox.some((m) => m.t === 'chat' && m.ch === 'near'));
  assert.ok(c.inbox.some((m) => m.t === 'emote' && m.name === 'wave'));
  assert.ok(c.inbox.some((m) => m.t === 'tag_event' && m.kind === 'invite'));
  b.ws.send(JSON.stringify({ t: 'tag_join' }));
  await wait(60);
  a.ws.send(JSON.stringify({ t: 'tag_start' }));
  await wait(120);
  assert.ok(b.inbox.some((m) => m.t === 'tag_event' && m.kind === 'start'));
  const last = [...b.inbox].reverse().find((m) => m.t === 'tag');
  assert.equal(last.state, 'playing');
  assert.equal(last.players.length, 2);
  for (const p of [a, b, c]) p.ws.close();
  srv.close();
});
