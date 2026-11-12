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

test('salas: todas abertas, entrada rápida prioriza salas existentes, código junta amigos', () => {
  const rm = new RoomManager();
  const codes = new Set();
  for (let i = 0; i < MAX_PER_ROOM + 1; i++) codes.add(rm.quick({ id: 'p' + i }).code);
  assert.equal(codes.size, 2);
  const first = rm.get([...codes][0]);
  assert.equal(first.snapshot('p0').length, MAX_PER_ROOM - 1);
  // sala criada por um amigo é ABERTA: quem entra pela entrada rápida pode cair nela
  const rm2 = new RoomManager();
  const nova = rm2.create({ id: 'dono' });
  assert.equal(nova.private, false);
  assert.match(nova.code, /^\d{4}$/);
  assert.equal(rm2.joinCode({ id: 'amigo' }, nova.code).code, nova.code);
  assert.equal(rm2.quick({ id: 'estranho' }).code, nova.code, 'entrada rápida prioriza a sala que já existe');
  assert.ok(rm2.joinCode({ id: 'x' }, '0000').error);
  // entre duas salas, a rápida vai para a mais cheia
  const outra = rm2.create({ id: 'sozinho' });
  assert.equal(rm2.quick({ id: 'novo' }).code, nova.code);
  assert.notEqual(outra.code, nova.code);
});

test('salas: cada um tem sua carteira; quem cai e volta logo recupera a mesma', () => {
  const rm = new RoomManager();
  const a = { id: 'a' }; const b = { id: 'b' }; const c = { id: 'c' };
  const room = rm.create(a);
  rm.joinCode(b, room.code);
  rm.joinCode(c, room.code);
  const da = room.desks.get('a'); const db = room.desks.get('b'); const dc = room.desks.get('c');
  assert.equal(new Set([da, db, dc]).size, 3, 'carteiras diferentes');
  rm.leave(b);
  const d = { id: 'd' };
  rm.joinCode(d, room.code);
  assert.notEqual(room.desks.get('d'), db, 'a carteira de quem caiu fica guardada um tempo');
  rm.joinCode({ id: 'b' }, room.code);
  assert.equal(room.desks.get('b'), db, 'voltou e recuperou a mesma carteira');
  assert.equal(Object.keys(room.deskMap()).length, 4);
});

test('salas: quem minimiza o app e volta encontra a mesma sala (vazia espera 5 min)', () => {
  const { EMPTY_KEEP_MS } = require('../src/rooms');
  const rm = new RoomManager();
  const p = { id: 'solo' };
  const room = rm.create(p);
  rm.leave(p);
  assert.ok(rm.get(room.code), 'a sala continua lá');
  const p2 = { id: 'solo' };
  assert.equal(rm.joinCode(p2, room.code).code, room.code);
  assert.equal(room.desks.get('solo'), 0, 'mesma carteira');
  rm.leave(p2);
  rm.prune(Date.now() + EMPTY_KEEP_MS + 1000);
  assert.ok(!rm.get(room.code), 'depois de muito tempo vazia, some');
  // entrada rápida não manda ninguém para sala vazia
  const px = { id: 'x' };
  const r2 = rm.create(px); rm.leave(px);
  assert.notEqual(rm.quick({ id: 'y' }).code, r2.code);
});

test('relógio: fases na ordem, dia seguinte e quem chega no meio sabe quanto falta', () => {
  const { SchoolClock, PHASES } = require('../src/clock');
  const t0 = 1000000;
  const c = new SchoolClock(t0, { scale: 0.01 });
  assert.equal(c.state(t0).phase, 'arrival');
  let t = t0;
  const seen = [];
  for (let i = 0; i < PHASES.length; i++) {
    t = c.endsAt;
    for (const st of c.tick(t)) seen.push(st.phase);
  }
  assert.deepEqual(seen, ['class1', 'recess', 'return', 'class2', 'end', 'arrival']);
  assert.equal(c.day, 2);
  const mid = c.state(t + 300);
  assert.equal(mid.phase, 'arrival');
  assert.ok(mid.left <= Math.ceil(c.duration(0) / 1000));
  // atraso grande: pula várias fases de uma vez sem travar
  const c2 = new SchoolClock(0, { scale: 0.001 });
  assert.ok(c2.tick(10 * 60 * 1000).length > 6);
});

test('brincadeiras: rodada com quem chega depois, vez com fila e time com troca de anfitrião', () => {
  const { GameHub } = require('../src/games');
  const room = { phase: 'recess' };
  const hub = new GameHub(room);
  const t = 5000;
  // fora do recreio não dá
  room.phase = 'class1';
  assert.ok(hub.join('aviao', 'a', {}, t).error);
  room.phase = 'recess';
  // RODADA: a começa sozinho (sem espera); b entra no meio; acaba quando os dois terminam
  hub.join('aviao', 'a', { wait: false }, t);
  hub.tick(t);
  assert.equal(hub.sessions.get('aviao').state, 'playing');
  hub.join('aviao', 'b', {}, t + 1000);
  hub.score('aviao', 'a', 30, true, t + 2000);
  assert.equal(hub.sessions.get('aviao').state, 'playing', 'espera quem entrou depois');
  hub.score('aviao', 'b', 45, true, t + 3000);
  const r = hub.sessions.get('aviao');
  assert.equal(r.state, 'results');
  assert.equal(r.ranking[0].id, 'b');
  // VEZ: fila; quem chega espera; quem sai na vez passa a vez
  hub.join('amarelinha', 'a', { wait: true }, t);
  hub.join('amarelinha', 'b', {}, t + 100);
  assert.equal(hub.sessions.get('amarelinha').state, 'lobby');
  assert.ok(hub.start('amarelinha', 'a', null, t + 200));
  const s = hub.sessions.get('amarelinha');
  assert.equal(s.current, 'a');
  hub.join('amarelinha', 'c', {}, t + 300);
  assert.deepEqual(s.queue, ['b', 'c']);
  hub.score('amarelinha', 'a', 10, true, t + 400);
  assert.equal(s.current, 'b');
  hub.leave('amarelinha', 'b', t + 500);
  assert.equal(s.current, 'c');
  hub.score('amarelinha', 'c', 12, true, t + 600);
  assert.equal(s.state, 'results');
  // entrar em outra brincadeira tira da anterior
  hub.join('corda', 'z', {}, t);
  hub.join('pontaria', 'z', {}, t);
  assert.ok(!hub.sessions.get('corda'), 'saiu da corda (sessão vazia fecha)');
  // TIME: times equilibrados; anfitrião sai e o time dele vira o "a"
  for (const id of ['h', 'p1', 'p2', 'p3']) hub.join('futebol', id, { wait: true }, t);
  const f = hub.sessions.get('futebol');
  assert.equal(f.teams.h, 'a');
  assert.equal(f.teamCount('a'), 2);
  assert.equal(f.teamCount('b'), 2);
  hub.start('futebol', 'h', { size: 4, difficulty: 1, bots: true }, t);
  assert.ok(hub.relay('futebol', 'h', { a: 1, b: 0, t: 90 }).to.length === 3);
  assert.deepEqual(hub.relay('futebol', 'p1', { k: 'chute' }).to, ['h']);
  hub.join('futebol', 'late', {}, t + 1000);
  assert.ok(['a', 'b'].includes(f.teams.late));
  const before = f.teams.p1;
  hub.leave('futebol', 'h', t + 2000);
  assert.equal(f.teams[f.host], 'a', 'o novo anfitrião fica no time a');
  assert.ok(f.hostState.swapped || before === 'a');
  // o sinal toca: termina com o placar de agora
  hub.endAll(t + 3000);
  assert.equal(f.state, 'results');
  hub.tick(t + 3000 + 7000);
  assert.ok(!hub.sessions.get('futebol'));
});
test('queimada e futebol: sem bots, sozinho não começa', () => {
  const { GameHub } = require('../src/games');
  for (const gid of ['queimada', 'futebol']) {
    const room = { phase: 'recess', players: new Map([['a', { pos: [0, 0, 0] }], ['b', { pos: [1, 0, 0] }]]) };
    const hub = new GameHub(room);
    hub.join(gid, 'a', { wait: false }, 1000);
    hub.tick(1000);
    assert.equal(hub.sessions.get(gid).state, 'lobby', gid + ': sozinho espera a turma');
    assert.ok(hub.takeEvents().some((e) => e.kind === 'need_players'));
    hub.join(gid, 'b', {}, 1100);
    hub.start(gid, 'a', {}, 1200);
    hub.tick(60000);
    assert.equal(hub.sessions.get(gid).state, 'playing', gid + ': com 2 começa');
    const s = hub.sessions.get(gid);
    assert.notEqual(s.teams.a, s.teams.b, gid + ': um em cada time');
  }
});
test('esconde-esconde: um conta, os outros se escondem, chegar perto acha; precisa de 2', () => {
  const { GameHub } = require('../src/games');
  const pos = { a: [0, 0, 0], b: [20, 0, 0], c: [-20, 0, 0] };
  const room = { phase: 'recess', players: new Map(Object.entries(pos).map(([id, p]) => [id, { pos: p }])) };
  const hub = new GameHub(room);
  const t = 1000;
  hub.join('esconde', 'a', { wait: false }, t);
  hub.tick(t);
  assert.equal(hub.sessions.get('esconde').state, 'lobby', 'sozinho não começa');
  assert.ok(hub.takeEvents().some((e) => e.kind === 'need_players'));
  hub.join('esconde', 'b', {}, t + 100);
  hub.join('esconde', 'c', {}, t + 200);
  hub.tick(t + 20000);
  const s = hub.sessions.get('esconde');
  assert.equal(s.state, 'playing');
  const seeker = s.hide.seeker;
  assert.equal(s.hide.phase, 'hiding');
  hub.tick(t + 20000 + 21000);
  assert.equal(s.hide.phase, 'seeking');
  assert.ok(hub.join('esconde', 'd', {}, t + 41500).error, 'procurando: novo jogador espera a próxima');
  const hiders = ['a', 'b', 'c'].filter((x) => x !== seeker);
  // o procurador chega pertinho do primeiro escondido
  room.players.get(seeker).pos = [room.players.get(hiders[0]).pos[0] + 1, 0, 0];
  hub.tick(t + 50000);
  assert.deepEqual(s.hide.found, [hiders[0]]);
  room.players.get(seeker).pos = [room.players.get(hiders[1]).pos[0] - 1, 0, 0];
  hub.tick(t + 60000);
  assert.equal(s.state, 'results', 'achou todo mundo: acabou');
  assert.equal(s.scores[seeker], 20);
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
  assert.equal(a.canFreeChat(acc), true);
  acc.freeChat = false; // responsável restringiu às frases prontas
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

test('servidor: criar sala e amigo entra pelo código; desconhecido cai na sala que já existe', async () => {
  const srv = createServer({ adminToken: 'x', dataDir: '' });
  await new Promise((r) => srv.server.listen(0, r));
  const port = srv.server.address().port;
  const a = await connect(port);
  a.ws.send(JSON.stringify({ t: 'hello', age: 9, mode: 'create' }));
  await wait(60);
  const wa = a.inbox.find((m) => m.t === 'welcome');
  assert.ok(!wa.private && /^\d{4}$/.test(wa.code));
  assert.equal(wa.clock.phase, 'arrival');
  assert.equal(wa.desk, 0);
  const b = await connect(port);
  b.ws.send(JSON.stringify({ t: 'hello', age: 9, mode: 'code', code: '0001' }));
  await wait(60);
  assert.ok(b.inbox.some((m) => m.t === 'join_error'));
  b.ws.send(JSON.stringify({ t: 'hello', age: 9, mode: 'code', code: wa.code }));
  await wait(60);
  const wb = b.inbox.find((m) => m.t === 'welcome');
  assert.equal(wb.code, wa.code);
  assert.equal(wb.desk, 1);
  assert.ok(a.inbox.some((m) => m.t === 'desks' && Object.keys(m.map).length === 2));
  const c = await connect(port);
  c.ws.send(JSON.stringify({ t: 'hello', age: 9, mode: 'quick' }));
  await wait(60);
  assert.equal(c.inbox.find((m) => m.t === 'welcome').code, wa.code);
  a.ws.close(); b.ws.close(); c.ws.close();
  srv.close();
});

test('servidor: relógio igual para todos e brincadeira compartilhada pelo websocket', async () => {
  const srv = createServer({ adminToken: 'x', dataDir: '', clockScale: 0.004 }); // chegada = 300 ms
  await new Promise((r) => srv.server.listen(0, r));
  const port = srv.server.address().port;
  const a = await connect(port);
  a.ws.send(JSON.stringify({ t: 'hello', age: 9, mode: 'create' }));
  await wait(60);
  const code = a.inbox.find((m) => m.t === 'welcome').code;
  // espera chegar no recreio (chegada 300 ms + aula 960 ms)
  await wait(1500);
  const clocks = a.inbox.filter((m) => m.t === 'clock').map((m) => m.phase);
  assert.deepEqual(clocks.slice(0, 2), ['class1', 'recess']);
  const b = await connect(port);
  b.ws.send(JSON.stringify({ t: 'hello', age: 9, mode: 'code', code }));
  await wait(80);
  assert.equal(b.inbox.find((m) => m.t === 'welcome').clock.phase, 'recess', 'quem chega depois recebe a fase atual');
  a.ws.send(JSON.stringify({ t: 'mg_join', gid: 'futebol', wait: true }));
  await wait(40);
  assert.ok(b.inbox.some((m) => m.t === 'mg' && m.list.some((g) => g.gid === 'futebol' && g.players.length === 1)), 'quem está perto vê que tem futebol rolando');
  b.ws.send(JSON.stringify({ t: 'mg_join', gid: 'futebol' }));
  await wait(40);
  a.ws.send(JSON.stringify({ t: 'mg_start', gid: 'futebol', opts: { size: 3, bots: true } }));
  await wait(60);
  assert.ok(b.inbox.some((m) => m.t === 'mg_event' && m.kind === 'start' && m.host));
  a.ws.send(JSON.stringify({ t: 'mg_relay', gid: 'futebol', d: { a: 1, b: 0, ball: [40, 0.3, -49] } }));
  b.ws.send(JSON.stringify({ t: 'mg_relay', gid: 'futebol', d: { k: 'chute', p: 0.8 } }));
  await wait(60);
  assert.ok(b.inbox.some((m) => m.t === 'mg_relay' && m.d.ball), 'estado do anfitrião chega aos outros');
  assert.ok(a.inbox.some((m) => m.t === 'mg_relay' && m.d.k === 'chute'), 'comando do colega chega ao anfitrião');
  // fora do recreio a brincadeira acaba com resultado para todos
  for (let i = 0; i < 80 && !b.inbox.some((m) => m.t === 'mg_event' && m.kind === 'results' && m.gid === 'futebol'); i++) await wait(100);
  const gotResults = b.inbox.some((m) => m.t === 'mg_event' && m.kind === 'results' && m.gid === 'futebol');
  a.ws.close(); b.ws.close();
  srv.close();
  assert.ok(gotResults);
  return;
  a.ws.close(); b.ws.close();
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
  a.ws.send(JSON.stringify({ t: 'chat', text: 'seu idiota' }));
  await wait(250);
  assert.ok(b.inbox.some((m) => m.t === 'states' && m.list.some((s) => s.id === wa.id)));
  assert.ok(b.inbox.some((m) => m.t === 'chat' && m.text === 'Oi! Tudo bem?'));
  // chat digitado liberado, mas sempre filtrado
  assert.ok(b.inbox.some((m) => m.t === 'chat' && m.text === 'oi'));
  assert.ok(!b.inbox.some((m) => m.t === 'chat' && /idiota/.test(m.text)));
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

test('pique-pega: quem entra no meio tem imunidade e o placar é por porcentagem', () => {
  const { TagGame } = require('../src/tag_game');
  const g = new TagGame({}, 0);
  g.invite('a', 0); g.join('b', 0);
  g.start(0);
  g.it = 'a'; g.itSince = 0;
  const pos = { a: [0, 0, 0], b: [10, 0, 0], c: [0.5, 0, 0] };
  g.tick((id) => pos[id], 30000); // a foi pegador 30 s
  g.join('c', 30000);
  g.lastTagAt = 0;
  assert.deepEqual(g.tick((id) => pos[id], 31000).filter((e) => e.kind === 'tagged'), [], 'recém-chegado não é pego na hora');
  const evs = g.tick((id) => pos[id], 34000);
  assert.ok(evs.some((e) => e.kind === 'tagged' && e.to === 'c'));
  const res = g.results(60000);
  const c = res.find((r) => r.id === 'c');
  assert.equal(c.secondsPlayed, 30);
  assert.ok(res.every((r) => Number.isFinite(r.pctIt)));
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
  await wait(60);
  assert.ok(a.inbox.some((m) => m.t === 'notice' && /recreio/.test(m.text)), 'fora do recreio não tem pique-pega');
  for (const r of srv.rooms.rooms.values()) r.clock.jump('recess');
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

test('contas: criar com apelido da lista, recuperar, progresso e apagar', async () => {
  const srv = createServer({ adminToken: 'x', dataDir: '' });
  await new Promise((r) => srv.server.listen(0, r));
  const base = 'http://127.0.0.1:' + srv.server.address().port;
  const post = (u, b, h = {}) => fetch(base + u, { method: 'POST', headers: h, body: JSON.stringify(b) });
  const { names } = await (await fetch(base + '/api/account/names')).json();
  assert.equal(names.length, 6);
  assert.equal((await post('/api/account/register', { name: 'Maria Silva', age: 9 })).status, 400); // nome livre não
  const reg = await (await post('/api/account/register', { name: names[0], age: 9 })).json();
  assert.ok(reg.ok && reg.token && /^[A-Z]+-[A-Z]+-[A-Z]+-[A-Z]+-\d{2}$/.test(reg.code));
  // salva progresso
  const save = { player: { level: 7, coins: 1234, appearance: { shirt_color: 'ff0000' } }, inventory: { owned: ['skin_ninja'] } };
  let r = await fetch(base + '/api/progress', { method: 'PUT', headers: { 'x-token': reg.token }, body: JSON.stringify({ save, savedAt: 1000 }) });
  assert.equal(r.status, 200);
  // progresso mais velho não sobrescreve
  r = await fetch(base + '/api/progress', { method: 'PUT', headers: { 'x-token': reg.token }, body: JSON.stringify({ save: {}, savedAt: 500 }) });
  assert.equal(r.status, 409);
  // outro celular: recupera com o código (minúsculo e com espaços também vale)
  const rec = await (await post('/api/account/recover', { code: reg.code.toLowerCase().replace(/-/g, ' ') })).json();
  assert.ok(rec.ok);
  assert.equal(rec.account.name, names[0]);
  assert.equal(rec.account.progress.player.coins, 1234);
  assert.notEqual(rec.token, reg.token);
  assert.equal((await fetch(base + '/api/account/me', { headers: { 'x-token': reg.token } })).status, 401); // token velho caiu
  assert.equal((await post('/api/account/recover', { code: 'BOLA-SOL-LUA-RIO-00' })).status, 404);
  // apagar conta (LGPD)
  assert.equal((await fetch(base + '/api/account', { method: 'DELETE', headers: { 'x-token': rec.token } })).status, 200);
  assert.equal((await fetch(base + '/api/account/me', { headers: { 'x-token': rec.token } })).status, 401);
  srv.close();
});

test('contas: limite de tentativas de recuperação', async () => {
  const srv = createServer({ adminToken: 'x', dataDir: '' });
  await new Promise((r) => srv.server.listen(0, r));
  const base = 'http://127.0.0.1:' + srv.server.address().port;
  let last = 0;
  for (let i = 0; i < 10; i++) {
    last = (await fetch(base + '/api/account/recover', { method: 'POST', body: JSON.stringify({ code: 'X-' + i }) })).status;
  }
  assert.equal(last, 429);
  srv.close();
});


test('contas: nome único digitado com checagem ao vivo, senha e login', async () => {
  const srv = createServer({ adminToken: 'x', dataDir: '' });
  await new Promise((r) => srv.server.listen(0, r));
  const base = 'http://127.0.0.1:' + srv.server.address().port;
  const chk = async (n) => (await fetch(base + '/api/account/check?name=' + encodeURIComponent(n))).json();
  const post = async (u, b) => { const r = await fetch(base + u, { method: 'POST', body: JSON.stringify(b) }); return { status: r.status, body: await r.json() }; };
  assert.equal((await chk('Leo_Gamer')).available, true);
  assert.equal((await chk('ab')).available, false);
  assert.equal((await chk('nome com espaço')).available, false);
  assert.equal((await chk('idiota123')).available, false);
  assert.equal((await chk('maria11987654321')).available, false); // parece telefone
  assert.equal((await chk('admin_legal')).available, false);
  let r = await post('/api/account/signup', { name: 'Leo_Gamer', password: '123', age: 9 });
  assert.equal(r.status, 400);
  r = await post('/api/account/signup', { name: 'Leo_Gamer', password: 'bola1234', age: 9 });
  assert.ok(r.body.ok && r.body.token);
  // mesmo nome com outra caixa/acento já está em uso
  assert.equal((await chk('leo_gamer')).available, false);
  assert.equal((await chk('Léo_Gamer')).available, false);
  assert.equal((await post('/api/account/signup', { name: 'LEO_GAMER', password: 'outra123', age: 9 })).status, 409);
  // login: senha errada não entra, certa entra e troca o token
  assert.equal((await post('/api/account/login', { name: 'leo_gamer', password: 'errada' })).status, 401);
  const ok = await post('/api/account/login', { name: 'leo_gamer', password: 'bola1234' });
  assert.ok(ok.body.ok);
  assert.notEqual(ok.body.token, r.body.token);
  assert.equal(ok.body.account.name, 'Leo_Gamer');
  srv.close();
});

test('salas: até 36 jogadores em três turmas de 12 (Sala 5, Sala 6, Sala 4)', () => {
  const rm = new RoomManager();
  const first = { id: 'p0' };
  const room = rm.create(first);
  for (let i = 1; i < 36; i++) assert.ok(!rm.joinCode({ id: 'p' + i }, room.code).error);
  assert.equal(room.players.size, 36);
  const desks = [...room.desks.values()].sort((a, b) => a - b);
  assert.deepEqual(desks, [...Array(36).keys()], 'uma carteira para cada, 12 por turma');
  assert.ok(rm.joinCode({ id: 'extra' }, room.code).error, 'a 37ª pessoa não entra');
  const other = rm.quick({ id: 'novo' });
  assert.notEqual(other.code, room.code, 'entrada rápida abre outra escola quando lota');
  // saiu alguém da Turma A: quem chega ocupa a vaga dela (a turma A enche primeiro)
  rm.leave(room.players.get('p3'));
  room.deskHold.clear();
  rm.joinCode({ id: 'p99' }, room.code);
  assert.equal(room.desks.get('p99'), 3);
});

test('servidor: com a escola cheia, colega longe chega menos vezes (perto: sempre)', async () => {
  const srv = createServer({ adminToken: 'x', dataDir: '' });
  await new Promise((r) => srv.server.listen(0, r));
  const port = srv.server.address().port;
  const socks = [];
  for (let i = 0; i < 10; i++) {
    const c = await connect(port);
    c.ws.send(JSON.stringify({ t: 'hello', age: 10 }));
    socks.push(c);
    await wait(20);
  }
  await wait(100);
  const ids = socks.map((c) => c.inbox.find((m) => m.t === 'welcome').id);
  const me = socks[0];
  // todos perto de mim, menos o último (a 100 m); todos andam por 1,2 s
  const t0 = Date.now();
  me.inbox.length = 0;
  while (Date.now() - t0 < 1200) {
    const k = (Date.now() - t0) / 1000;
    socks.forEach((c, i) => c.ws.send(JSON.stringify({ t: 'state', pos: [i === 9 ? 100 + k : k, 0, 0], yaw: 0, anim: 'walk' })));
    await wait(50);
  }
  await wait(300);
  const count = (id) => me.inbox.filter((m) => m.t === 'states' && m.list.some((s) => s.id === id)).length;
  const near = count(ids[1]);
  const far = count(ids[9]);
  assert.ok(near >= 8, 'perto: ~10 por segundo (' + near + ')');
  assert.ok(far >= 1 && far <= near / 2, 'longe: bem menos vezes (' + far + ' x ' + near + ')');
  assert.ok(!me.inbox.some((m) => m.t === 'states' && m.list.some((s) => s.id === ids[0])), 'não recebe a si mesmo');
  socks.forEach((c) => c.ws.close());
  srv.close();
});

test('amigos: pedido pelo nome, aceitar, ver em qual sala está e convidar', async () => {
  const srv = createServer({ adminToken: 'x', dataDir: '' });
  await new Promise((r) => srv.server.listen(0, r));
  const port = srv.server.address().port;
  const base = 'http://127.0.0.1:' + port;
  const post = async (path, body, token) => (await fetch(base + path, { method: 'POST', headers: { 'content-type': 'application/json', ...(token ? { 'x-token': token } : {}) }, body: JSON.stringify(body) })).json();
  const get = async (path, token) => (await fetch(base + path, { headers: { 'x-token': token } })).json();
  const a = await post('/api/account/signup', { name: 'Ana_Foguete', password: 'segredo1', age: 9 });
  const b = await post('/api/account/signup', { name: 'Beto_Raio', password: 'segredo2', age: 10 });
  assert.ok(a.ok && b.ok);
  // Ana pede pelo nome; Beto vê o pedido
  let r = await post('/api/friends/add', { name: 'beto_raio' }, a.token);
  assert.equal(r.status, 'sent');
  assert.equal((await post('/api/friends/add', { name: 'Ninguem_Aqui' }, a.token)).ok, false);
  let lb = await get('/api/friends', b.token);
  assert.equal(lb.list[0].status, 'incoming');
  assert.equal(lb.list[0].name, 'Ana_Foguete');
  // Beto aceita: viram amigos
  r = await post('/api/friends/accept', { id: lb.list[0].id }, b.token);
  assert.equal(r.list[0].status, 'friend');
  // Beto entra numa sala: Ana vê o código para entrar junto
  const wb = await connect(port);
  wb.ws.send(JSON.stringify({ t: 'hello', token: b.token, age: 10, mode: 'create' }));
  await wait(150);
  const welcomeB = wb.inbox.find((m) => m.t === 'welcome');
  const la = await get('/api/friends', a.token);
  assert.ok(la.list[0].online && la.list[0].code === welcomeB.code, 'amigo online com o código da sala');
  // Ana entra em outra sala e convida o Beto
  const wa = await connect(port);
  wa.ws.send(JSON.stringify({ t: 'hello', token: a.token, age: 9, mode: 'create' }));
  await wait(150);
  const welcomeA = wa.inbox.find((m) => m.t === 'welcome');
  wa.ws.send(JSON.stringify({ t: 'friend_invite', id: welcomeB.id }));
  await wait(150);
  const inv = wb.inbox.find((m) => m.t === 'friend_invite');
  assert.ok(inv && inv.code === welcomeA.code && inv.name === 'Ana_Foguete', 'convite chega com o código');
  // remover
  r = await post('/api/friends/remove', { id: welcomeB.id }, a.token);
  assert.equal(r.list.length, 0);
  wa.ws.close(); wb.ws.close();
  srv.close();
});
