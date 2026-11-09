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

test('salas: entrar no meio da partida e lotação', () => {
  const rm = new RoomManager();
  const rooms = new Set();
  for (let i = 0; i < MAX_PER_ROOM + 1; i++) rooms.add(rm.join({ id: 'p' + i }, null).id);
  assert.equal(rooms.size, 2);
  const r = rm.get('sala-1');
  assert.equal(r.snapshot('p0').length, MAX_PER_ROOM - 1);
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

test('servidor: hello, estados, frases rápidas e chat bloqueado para menores', async () => {
  const srv = createServer({ adminToken: 'x' });
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
  assert.ok(b.inbox.some((m) => m.t === 'chat' && m.text === 'Oi!'));
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
