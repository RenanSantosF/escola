'use strict';
// Servidor online do Recreio (Railway). HTTP para saúde/moderação +
// WebSocket para o jogo. Protocolo: mensagens JSON {t: tipo, ...}.
//
// Cliente -> servidor
//   {t:'hello', token?, age, level, look, mode, code?} entra com a conta;
//        mode: 'quick' (sala pública) | 'create' (sala privada nova) | 'code'
//   {t:'state', pos:[x,y,z], yaw, anim}             até ~10x por segundo
//   {t:'quick', i}                                   frase pronta (índice)
//   {t:'chat', text}                                 texto livre (só se liberado)
//   {t:'report', target, reason}                     denuncia jogador
//   {t:'block', target}                              bloqueia jogador
//   {t:'quick'|'chat', ..., ch:'near'}               canal "Perto de mim" (18 m)
//   {t:'emote', name}                                reação (aceno, comemorar...)
//   {t:'tag_invite'|'tag_join'|'tag_leave'|'tag_start'}  pique-pega online
//   {t:'mg_join', gid, wait?, opts?} {t:'mg_leave', gid} {t:'mg_start', gid, opts?}
//   {t:'mg_opts', gid, opts} {t:'mg_score', gid, score, final} {t:'mg_team_result', gid, a, b}
//   {t:'mg_relay', gid, d}                           jogo de time (anfitrião <-> outros)
//   {t:'direct', to, kind, data}                     missão em grupo (convite/estado)
// Servidor -> cliente
//   {t:'clock', day, phase, index, startedAt, endsAt, now, seed, left}  relógio da escola
//   {t:'desks', map:{id: carteira}}                  carteiras reservadas na Sala 5
//   {t:'mg', list:[estado]} {t:'mg_event', gid, kind, ...} {t:'mg_relay', gid, from, d}
//   {t:'direct', from, fromName, kind, data}
//   {t:'welcome', token, id, name, room, code, private, freeChat, quick, players, phase}
//   {t:'join_error', text}   código errado / sala cheia (a conexão continua)
//   {t:'join', player} {t:'leave', id} {t:'states', list}
//   {t:'chat', id, name, text, ch} {t:'notice', text} {t:'emote', id, name}
//   {t:'tag', state, host, players, it, lobbyLeft, left, names}
//   {t:'tag_event', kind:'invite'|'start'|'tagged'|'end'|'cancel', ...}

const http = require('http');
const { WebSocketServer } = require('ws');
const { check, QUICK_PHRASES } = require('./chat_filter');
const { Safety } = require('./safety');
const { RoomManager } = require('./rooms');
const { Accounts, sha, nameKey, nameProblem, checkPassword } = require('./accounts');
const { Analytics } = require('./analytics');
const { TagGame } = require('./tag_game');
const { CATALOG } = require('./games');
const { Database } = require('./db');
const gameSettings = require('./settings');
const { Friends } = require('./friends');

const NEAR_DIST = 18; // metros do canal "Perto de mim"
const EMOTES = new Set(['wave', 'celebrate', 'clap', 'sad', 'stretch', 'scratch_head', 'look_around', 'raise_hand']);
const fs = require('fs');
const path = require('path');

const ADMIN_HTML = path.join(__dirname, '..', 'public', 'admin.html');

const TICK_MS = 100;
const MAX_MSG_BYTES = 2048;

function createServer(opts = {}) {
  const adminToken = opts.adminToken ?? process.env.ADMIN_TOKEN ?? '';
  const db = opts.db || new Database(opts.dbUrl !== undefined ? { url: opts.dbUrl } : {});
  const dbSafe = (p) => { if (p && p.catch) p.catch((e) => console.error('db:', e.message)); };
  const accounts = opts.accounts || new Accounts();
  const safety = opts.safety || new Safety({
    onMute: (id, until) => dbSafe(db.saveMute(id, until)),
    onReport: (e) => dbSafe(db.insertReport(e)),
    onBlock: (id, other) => dbSafe(db.saveBlock(id, other)),
  });
  const friends = opts.friends || new Friends();
  const online = new Map(); // id da conta -> jogador conectado (para amigos: "está na sala 1234")
  // CLOCK_SCALE/CLOCK_START só para testes locais (o dia inteiro em segundos, ou já no recreio)
  const rooms = new RoomManager({ clock: { scale: opts.clockScale ?? (Number(process.env.CLOCK_SCALE) || 1), startPhase: opts.clockStart ?? process.env.CLOCK_START } });
  const analytics = opts.analytics || new Analytics({
    ...(opts.dataDir !== undefined ? { dataDir: opts.dataDir } : {}),
    ...(db.enabled ? { dataDir: '' } : {}),
    onIngest: (list) => dbSafe(db.insertEvents(list)),
  });
  // carrega o que está no banco (contas são buscadas sob demanda no login)
  const ready = (async () => {
    if (!db.enabled) return false;
    try {
      await db.init();
      analytics.events = await db.loadEvents();
      safety.reports = await db.loadReports();
      for (const [id, until] of await db.loadMutes()) safety.mutedUntil.set(id, until);
      for (const [id, other] of await db.loadBlocks()) safety.block(id, other, false);
      friends.load(await db.loadFriends());
      gameSettings.apply(await db.loadSettings().catch(() => null));
      console.log('Banco de dados conectado: ' + analytics.events.length + ' eventos carregados');
      return true;
    } catch (e) {
      console.error('db: não conectou (seguindo em memória):', e.message);
      return false;
    }
  })();
  const recentChat = new Map(); // roomId -> últimas mensagens (contexto p/ denúncia)

  function isAdmin(req) {
    return adminToken !== '' && req.headers['x-admin-token'] === adminToken;
  }

  // limite de tentativas por IP (criação de conta / recuperação)
  const attempts = new Map();
  function limited(req, key, max, windowMs) {
    const ip = String(req.headers['x-forwarded-for'] || req.socket.remoteAddress || '?').split(',')[0].trim();
    const k = key + ':' + ip;
    const now = Date.now();
    const list = (attempts.get(k) || []).filter((t) => now - t < windowMs);
    list.push(now);
    attempts.set(k, list);
    return list.length > max;
  }

  async function accountFromToken(token) {
    token = String(token || '').slice(0, 80);
    if (!token) return null;
    if (accounts.byToken.has(token)) return accounts.byToken.get(token);
    if (db.ready) {
      const found = await db.findAccount(token).catch(() => null);
      if (found) return accounts.adopt(found);
    }
    return null;
  }

  /** Lista de amigos com quem está jogando agora (e em qual sala). */
  function friendList(id) {
    const order = { incoming: 0, friend: 1, outgoing: 2 };
    return friends.list(id).map((f) => {
      const p = online.get(f.id);
      const r = p && f.status === 'friend' ? rooms.get(p.roomId) : null;
      return { ...f, online: !!r, code: r ? r.code : '', players: r ? r.players.size : 0, full: r ? r.players.size >= r.info().max : false };
    }).sort((x, y) => (order[x.status] - order[y.status]) || (y.online - x.online) || x.name.localeCompare(y.name));
  }

  const publicAccount = (a, withProgress = false) => ({
    id: a.id, name: a.name, age: a.age, level: a.level, registered: !!a.registered,
    ...(withProgress ? { progress: a.progress || null, progressAt: a.progressAt || 0 } : {}),
  });

  function liveInfo() {
    let online = 0;
    for (const r of rooms.rooms.values()) online += r.players.size;
    return { online, rooms: rooms.rooms.size, reports: safety.reports.length };
  }

  function readJson(req, limit = 4096) {
    return new Promise((resolve) => {
      let body = '';
      req.on('data', (c) => { body += c; if (body.length > limit) req.destroy(); });
      req.on('end', () => { try { resolve(JSON.parse(body || '{}')); } catch { resolve({}); } });
    });
  }

  const server = http.createServer(async (req, res) => {
    const json = (code, obj) => { res.writeHead(code, { 'content-type': 'application/json', 'cache-control': 'no-store' }); res.end(JSON.stringify(obj)); };
    const url = (req.url || '/').split('?')[0];
    if (url === '/health') {
      const l = liveInfo();
      return json(200, { ok: true, rooms: l.rooms, players: l.online, db: db.ready });
    }
    // Páginas públicas exigidas pela Google Play / AdMob
    if (url === '/privacidade' || url === '/excluir-conta') {
      const file = path.join(__dirname, '..', 'public', url.slice(1) + '.html');
      const mail = String(process.env.CONTACT_EMAIL || '').replace(/[<>"'&]/g, '');
      const contato = mail ? 'Fale com a gente: <a href="mailto:' + mail + '">' + mail + '</a>' : 'Fale com a gente pelo e-mail de contato informado na página do jogo na Google Play.';
      const html = fs.readFileSync(file, 'utf8').replace(/\{\{CONTATO\}\}/g, contato).replace(/\{\{DATA\}\}/g, '12/11/2026');
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
      return res.end(html);
    }
    if (url === '/app-ads.txt') {
      res.writeHead(200, { 'content-type': 'text/plain; charset=utf-8' });
      return res.end('google.com, pub-4311255826061303, DIRECT, f08c47fec0942fa0\n');
    }
    if (url === '/' || url === '/admin') {
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
      return res.end(fs.readFileSync(ADMIN_HTML));
    }
    // Estatísticas anônimas enviadas pelo jogo
    if (url === '/api/events' && req.method === 'POST') {
      const b = await readJson(req, 65536);
      const n = analytics.ingest(String(b.uid || ''), b.events);
      return json(200, { ok: true, accepted: n });
    }
    // ---------------------------------------------------------- amigos
    if (url.startsWith('/api/friends')) {
      const me = await accountFromToken(req.headers['x-token']);
      if (!me) return json(401, { ok: false, error: 'Entre na sua conta.' });
      if (url === '/api/friends' && req.method === 'GET') return json(200, { ok: true, list: friendList(me.id) });
      if (req.method !== 'POST') return json(404, { ok: false });
      if (limited(req, 'friends', 60, 60000)) return json(429, { ok: false, error: 'Calma! Tente de novo daqui a pouco.' });
      const b = await readJson(req);
      if (url === '/api/friends/add') {
        const key = nameKey(String(b.name || '').trim());
        let other = accounts.byName.get(key) || null;
        let info = other ? { id: other.id, name: other.name } : await db.idByName(key).catch(() => null);
        if (!info) return json(404, { ok: false, error: 'Não achei ninguém com esse nome. Confira as letras!' });
        if (safety.isBlocked(me.id, info.id) || safety.isBlocked(info.id, me.id)) return json(403, { ok: false, error: 'Não dá para adicionar esse jogador.' });
        const r = friends.request(me.id, me.name, info.id, info.name);
        if (r.status === 'error') return json(400, { ok: false, error: r.error });
        if (r.pair) dbSafe(db.saveFriend(r.pair));
        const target = online.get(info.id);
        if (target && r.status === 'sent') send(target.ws, { t: 'friend_request', from: me.id, name: me.name });
        if (target && r.status === 'friends') send(target.ws, { t: 'friend_notice', text: me.name + ' agora é seu amigo!' });
        const text = r.status === 'friends' ? 'Agora vocês são amigos!' : (r.status === 'already' ? 'Vocês já são amigos (ou o pedido já foi).' : 'Pedido enviado! Quando ' + info.name + ' aceitar, aparece na lista.');
        return json(200, { ok: true, status: r.status, text, list: friendList(me.id) });
      }
      if (url === '/api/friends/accept') {
        const p = friends.accept(me.id, String(b.id || ''));
        if (!p) return json(404, { ok: false, error: 'Pedido não encontrado.' });
        dbSafe(db.saveFriend(p));
        const target = online.get(String(b.id));
        if (target) send(target.ws, { t: 'friend_notice', text: me.name + ' aceitou sua amizade!' });
        return json(200, { ok: true, list: friendList(me.id) });
      }
      if (url === '/api/friends/remove') {
        const p = friends.remove(me.id, String(b.id || ''));
        if (p) dbSafe(db.deleteFriend(p.a, p.b));
        return json(200, { ok: true, list: friendList(me.id) });
      }
      return json(404, { ok: false });
    }
    // ---------------------------------------------------------- contas
    // nome escolhido pela criança: checagem ao vivo
    if (url === '/api/account/check' && req.method === 'GET') {
      const name = new URL(req.url, 'http://x').searchParams.get('name') || '';
      const why = nameProblem(name);
      if (why) return json(200, { ok: true, available: false, reason: why });
      const key = nameKey(name);
      const taken = accounts.byName.has(key) || await db.nameTaken(key).catch(() => false);
      return json(200, { ok: true, available: !taken, reason: taken ? 'Esse nome já tem dono. Tente outro!' : '' });
    }
    if (url === '/api/account/signup' && req.method === 'POST') {
      if (limited(req, 'reg', 20, 3600000)) return json(429, { ok: false, error: 'Muitas contas criadas. Tente mais tarde.' });
      const b = await readJson(req);
      const why = nameProblem(b.name);
      if (why) return json(400, { ok: false, error: why });
      const pw = String(b.password || '');
      if (pw.length < 6 || pw.length > 40) return json(400, { ok: false, error: 'A senha precisa ter de 6 a 40 caracteres.' });
      const key = nameKey(b.name);
      if (accounts.byName.has(key) || await db.nameTaken(key).catch(() => false)) {
        return json(409, { ok: false, error: 'Esse nome já tem dono. Tente outro!' });
      }
      const acc = accounts.registerWithPassword({ name: b.name, password: pw, age: b.age });
      try {
        await db.saveAccount(acc);
      } catch (e) {
        accounts.remove(acc);
        return json(409, { ok: false, error: 'Esse nome já tem dono. Tente outro!' });
      }
      return json(200, { ok: true, token: acc.token, account: publicAccount(acc) });
    }
    if (url === '/api/account/login' && req.method === 'POST') {
      if (limited(req, 'login', 10, 600000)) return json(429, { ok: false, error: 'Muitas tentativas. Espere 10 minutos.' });
      const b = await readJson(req);
      const key = nameKey(b.name);
      let acc = accounts.byName.get(key) || null;
      if (!acc && db.ready) {
        const tmp = require('crypto').randomBytes(18).toString('hex');
        const found = await db.findByName(key, tmp).catch(() => null);
        if (found) acc = accounts.adopt(found);
      }
      if (!acc || !checkPassword(String(b.password || ''), acc.passHash)) {
        return json(401, { ok: false, error: 'Nome ou senha errados.' });
      }
      accounts.rotateToken(acc);
      dbSafe(db.saveAccount(acc));
      return json(200, { ok: true, token: acc.token, account: publicAccount(acc, true) });
    }
    if (url === '/api/account/names' && req.method === 'GET') {
      return json(200, { names: Accounts.nameOptions(6) });
    }
    if (url === '/api/account/register' && req.method === 'POST') {
      if (limited(req, 'reg', 20, 3600000)) return json(429, { ok: false, error: 'Muitas contas criadas. Tente mais tarde.' });
      const b = await readJson(req);
      if (!Accounts.validName(b.name)) return json(400, { ok: false, error: 'Escolha um dos apelidos da lista.' });
      const { acc, code } = accounts.register({ name: b.name, age: b.age });
      dbSafe(db.saveAccount(acc));
      return json(200, { ok: true, token: acc.token, code, account: publicAccount(acc) });
    }
    if (url === '/api/account/recover' && req.method === 'POST') {
      if (limited(req, 'rec', 8, 600000)) return json(429, { ok: false, error: 'Muitas tentativas. Espere 10 minutos.' });
      const b = await readJson(req);
      const hash = sha(Accounts.normalizeCode(b.code));
      const newToken = require('crypto').randomBytes(18).toString('hex');
      let acc = accounts.byRecovery.get(hash) || null;
      if (acc) {
        accounts.byToken.delete(acc.token);
        acc.token = newToken;
        accounts.adopt(acc);
        dbSafe(db.saveAccount(acc));
      } else if (db.ready) {
        const found = await db.findByRecovery(hash, newToken).catch(() => null);
        if (found) acc = accounts.adopt(found);
      }
      if (!acc) return json(404, { ok: false, error: 'Código não encontrado. Confira as palavras e o número.' });
      return json(200, { ok: true, token: acc.token, account: publicAccount(acc, true) });
    }
    if (url === '/api/account/me' && req.method === 'GET') {
      const acc = await accountFromToken(req.headers['x-token']);
      if (!acc) return json(401, { ok: false });
      return json(200, { ok: true, account: publicAccount(acc, true) });
    }
    if (url === '/api/progress' && req.method === 'PUT') {
      const acc = await accountFromToken(req.headers['x-token']);
      if (!acc) return json(401, { ok: false });
      const b = await readJson(req, 300000);
      if (!accounts.setProgress(acc, b.save, b.savedAt)) return json(409, { ok: false, progressAt: acc.progressAt });
      dbSafe(db.saveProgress(acc));
      return json(200, { ok: true, progressAt: acc.progressAt });
    }
    if (url === '/api/account' && req.method === 'DELETE') {
      const acc = await accountFromToken(req.headers['x-token']);
      if (!acc) return json(401, { ok: false });
      accounts.remove(acc);
      await db.deleteAccount(acc.id).catch(() => {});
      return json(200, { ok: true });
    }
    if (url === '/api/rooms' && req.method === 'GET') {
      return json(200, { rooms: rooms.publicList(), online: liveInfo().online });
    }
    // Painel do administrador (protegido por ADMIN_TOKEN)
    if (url === '/api/admin/stats' && req.method === 'GET') {
      if (!isAdmin(req)) return json(403, { ok: false, error: 'token inválido' });
      const st = analytics.stats(liveInfo());
      st.live.roomList = [...rooms.rooms.values()].map((r) => ({ ...r.info(), ages: [...r.players.values()].map((p) => p.acc.age) }));
      st.reports = safety.reports.slice(-50).reverse();
      st.storage = db.ready ? 'banco PostgreSQL' : (analytics.file ? 'volume' : 'memória (zera ao reiniciar)');
      st.db = db.ready ? await db.counts().catch(() => null) : null;
      return json(200, st);
    }
    if ((url === '/mod/reports' || url === '/api/admin/reports') && req.method === 'GET') {
      if (!isAdmin(req)) return json(403, { ok: false });
      return json(200, { reports: safety.reports.slice(-200) });
    }
    if ((url === '/mod/mute' || url === '/api/admin/mute') && req.method === 'POST') {
      if (!isAdmin(req)) return json(403, { ok: false });
      const b = await readJson(req);
      safety.mute(String(b.id || ''), (b.minutes | 0 || 60) * 60000);
      return json(200, { ok: true });
    }
    // Configurações do jogo (bots nas brincadeiras de time)
    if (url === '/api/admin/settings' && req.method === 'GET') {
      if (!isAdmin(req)) return json(403, { ok: false });
      return json(200, { ok: true, settings: gameSettings.publicSettings() });
    }
    if (url === '/api/admin/settings' && req.method === 'POST') {
      if (!isAdmin(req)) return json(403, { ok: false });
      const b = await readJson(req);
      const now = gameSettings.apply(b);
      await db.saveSettings({ botsEnabled: now.botsEnabled, botsPerTeam: now.botsPerTeam }).catch(() => false);
      return json(200, { ok: true, settings: now, saved: db.ready });
    }
    // Liberação de chat livre por responsável (validado pela moderação)
    if ((url === '/parent/unlock' || url === '/api/admin/unlock') && req.method === 'POST') {
      if (!isAdmin(req)) return json(403, { ok: false });
      const b = await readJson(req);
      const acc = accounts.findById(String(b.id || ''));
      if (acc) acc.freeChat = b.allow ? null : false;
      const inDb = await db.setFreeChat(String(b.id || ''), b.allow).catch(() => false);
      return (acc || inDb) ? json(200, { ok: true }) : json(404, { ok: false });
    }
    json(404, { ok: false });
  });

  const wss = new WebSocketServer({ server, maxPayload: MAX_MSG_BYTES });

  function send(ws, obj) {
    if (ws.readyState === 1) ws.send(JSON.stringify(obj));
  }

  function broadcast(room, obj, exceptId, filterFn) {
    const s = JSON.stringify(obj);
    for (const p of room.players.values()) {
      if (p.id === exceptId) continue;
      if (filterFn && !filterFn(p)) continue;
      if (p.ws.readyState === 1) p.ws.send(s);
    }
  }

  function near(a, b) {
    return Math.hypot(a.pos[0] - b.pos[0], a.pos[2] - b.pos[2]) <= NEAR_DIST && Math.abs(a.pos[1] - b.pos[1]) < 6;
  }

  function pushChat(room, p, text, ch = 'all') {
    const list = recentChat.get(room.id) || [];
    list.push({ id: p.id, text, ch, at: Date.now() });
    if (list.length > 30) list.shift();
    recentChat.set(room.id, list);
    const nearOnly = ch === 'near';
    broadcast(room, { t: 'chat', id: p.id, name: p.name, text, ch: nearOnly ? 'near' : 'all' }, null,
      (viewer) => !safety.isBlocked(viewer.id, p.id) && (!nearOnly || viewer.id === p.id || near(viewer, p)));
  }

  const DIRECT_KINDS = new Set(['party_invite', 'party_accept', 'party_decline', 'party_state', 'party_step', 'party_leave']);

  /** Limite simples de mensagens por segundo (por tipo). */
  function rate(player, key, perSec) {
    const now = Date.now();
    const b = (player.rates ||= {});
    const e = b[key] && now - b[key].t < 1000 ? b[key] : (b[key] = { t: now, n: 0 });
    e.n++;
    return e.n <= perSec;
  }

  function flushGames(room) {
    const list = room.games.takeDirty();
    if (list.length) broadcast(room, { t: 'mg', list });
    for (const e of room.games.takeEvents()) broadcast(room, { t: 'mg_event', ...e });
  }

  function names(room) {
    const out = {};
    for (const p of room.players.values()) out[p.id] = p.name;
    return out;
  }

  function sendTag(room) {
    if (!room.tag) return;
    broadcast(room, { t: 'tag', ...room.tag.snapshot(), names: names(room) });
  }

  function tagEvents(room, evs) {
    for (const e of evs) {
      if (e.kind === 'end') e.results = e.results.map((r) => ({ ...r, name: (room.players.get(r.id) || {}).name || '?' }));
      broadcast(room, { t: 'tag_event', ...e, names: names(room) });
    }
    if (evs.length) sendTag(room);
    if (room.tag && room.tag.state === 'over') room.tag = null;
  }

  wss.on('connection', (ws) => {
    ws.isAlive = true;
    ws.on('pong', () => { ws.isAlive = true; });
    let player = null;
    let room = null;
    let pendingHello = false;

    async function handleHello(m) {
      const token = typeof m.token === 'string' ? m.token.slice(0, 80) : '';
      // conta que já existe no banco (outro dia, outro deploy)
      if (token && !accounts.byToken.has(token) && db.ready) {
        const found = await db.findAccount(token).catch(() => null);
        if (found) accounts.adopt(found);
      }
      if (ws.readyState !== 1) return;
      const acc = accounts.getOrCreate(token, { age: m.age, level: m.level, look: m.look });
      if (Number.isFinite(m.age)) acc.age = Math.max(5, Math.min(18, m.age | 0));
      dbSafe(db.saveAccount(acc));
      player = { id: acc.id, name: acc.name, level: acc.level, look: acc.look, pos: [0, 0, 70], yaw: 0, anim: 'idle', ws, acc, dirty: true };
      let r;
      if (m.mode === 'create') r = rooms.create(player);
      else if (m.mode === 'code') r = rooms.joinCode(player, String(m.code || '').slice(0, 8));
      else r = rooms.quick(player);
      if (r.error) {
        player = null;
        return send(ws, { t: 'join_error', text: r.error });
      }
      room = r;
      online.set(acc.id, player);
      send(ws, {
        t: 'welcome', token: acc.token, id: acc.id, name: acc.name, room: room.id, code: room.code, private: room.private,
        freeChat: accounts.canFreeChat(acc), quick: QUICK_PHRASES, players: room.snapshot(acc.id), phase: room.phase,
        clock: room.clock.state(), desks: room.deskMap(), desk: room.desks.get(acc.id) ?? -1, games: room.games.all(),
      });
      if (room.tag) send(ws, { t: 'tag', ...room.tag.snapshot(), names: names(room) });
      broadcast(room, { t: 'join', player: { id: player.id, name: player.name, level: player.level, look: player.look, pos: player.pos, yaw: player.yaw, anim: player.anim } }, player.id);
      broadcast(room, { t: 'count', n: room.players.size });
      broadcast(room, { t: 'desks', map: room.deskMap() }, player.id);
    }

    ws.on('message', (raw) => {
      let m;
      try { m = JSON.parse(raw.toString()); } catch { return; }
      if (!m || typeof m.t !== 'string') return;
      if (!player) {
        if (m.t !== 'hello' || pendingHello) return;
        pendingHello = true;
        handleHello(m).catch((e) => console.error('hello:', e.message)).finally(() => { pendingHello = false; });
        return;
      }
      switch (m.t) {
        case 'state': {
          if (Array.isArray(m.pos) && m.pos.length === 3 && m.pos.every(Number.isFinite)) {
            player.pos = m.pos.map((v) => Math.round(v * 100) / 100);
          }
          if (Number.isFinite(m.yaw)) player.yaw = Math.round(m.yaw * 100) / 100;
          if (typeof m.anim === 'string') player.anim = m.anim.slice(0, 16);
          player.dirty = true;
          break;
        }
        case 'quick': {
          const i = m.i | 0;
          if (i < 0 || i >= QUICK_PHRASES.length) return;
          const why = safety.canSend(player.id);
          if (why) return send(ws, { t: 'notice', text: why });
          pushChat(room, player, QUICK_PHRASES[i], m.ch === 'near' ? 'near' : 'all');
          break;
        }
        case 'chat': {
          if (!accounts.canFreeChat(player.acc)) {
            return send(ws, { t: 'notice', text: 'Use as frases rápidas. O chat livre precisa ser liberado por um responsável.' });
          }
          const why = safety.canSend(player.id);
          if (why) return send(ws, { t: 'notice', text: why });
          const r = check(m.text);
          if (!r.ok) {
            const muted = safety.onBlockedMessage(player.id);
            return send(ws, { t: 'notice', text: muted ? 'Você foi silenciado por 10 minutos.' : r.reason });
          }
          pushChat(room, player, r.text, m.ch === 'near' ? 'near' : 'all');
          break;
        }
        case 'report': {
          const target = String(m.target || '');
          const ctx = (recentChat.get(room.id) || []).filter((c) => c.id === target).slice(-5);
          const r = safety.report(player.id, target, String(m.reason || 'outro'), { room: room.id, messages: ctx });
          send(ws, { t: 'notice', text: r.ok ? 'Obrigado! A denúncia foi enviada para a equipe.' : 'Não foi possível denunciar.' });
          if (r.ok) safety.block(player.id, target);
          break;
        }
        case 'emote': {
          const name = String(m.name || '');
          if (!EMOTES.has(name)) return;
          if (player.lastEmote && Date.now() - player.lastEmote < 800) return;
          player.lastEmote = Date.now();
          broadcast(room, { t: 'emote', id: player.id, name }, player.id);
          break;
        }
        case 'tag_invite': {
          if (room.phase !== 'recess') return send(ws, { t: 'notice', text: 'O pique-pega é no recreio!' });
          if (room.tag && room.tag.state !== 'over') {
            room.tag.join(player.id);
            sendTag(room);
            return send(ws, { t: 'notice', text: 'Já tem um pique-pega rolando: você entrou!' });
          }
          room.tag = new TagGame(room);
          room.tag.invite(player.id);
          broadcast(room, { t: 'tag_event', kind: 'invite', from: player.id, fromName: player.name, names: names(room) });
          sendTag(room);
          break;
        }
        case 'tag_join': {
          if (room.tag && room.tag.join(player.id)) sendTag(room);
          break;
        }
        case 'tag_leave': {
          if (room.tag) {
            room.tag.leave(player.id);
            sendTag(room);
          }
          break;
        }
        case 'tag_start': {
          if (room.tag && room.tag.state === 'lobby' && room.tag.host === player.id) {
            if (room.tag.start()) tagEvents(room, [{ kind: 'start', it: room.tag.it }]);
            else send(ws, { t: 'notice', text: 'Precisa de pelo menos 2 jogadores para começar.' });
          }
          break;
        }
        case 'mg_join': {
          const gid = String(m.gid || '');
          if (!CATALOG[gid]) return;
          const r = room.games.join(gid, player.id, { wait: !!m.wait, opts: m.opts });
          if (r.error) send(ws, { t: 'mg_error', gid, text: r.error });
          flushGames(room);
          break;
        }
        case 'mg_leave': {
          room.games.leave(String(m.gid || ''), player.id);
          flushGames(room);
          break;
        }
        case 'mg_start': {
          room.games.start(String(m.gid || ''), player.id, m.opts);
          flushGames(room);
          break;
        }
        case 'mg_opts': {
          room.games.setOpts(String(m.gid || ''), player.id, m.opts);
          flushGames(room);
          break;
        }
        case 'mg_score': {
          room.games.score(String(m.gid || ''), player.id, m.score, !!m.final);
          flushGames(room);
          break;
        }
        case 'mg_team_result': {
          room.games.teamResult(String(m.gid || ''), player.id, { a: m.a, b: m.b });
          flushGames(room);
          break;
        }
        case 'mg_relay': {
          if (!rate(player, 'relay', 25)) return;
          const gid = String(m.gid || '');
          const r = room.games.relay(gid, player.id, m.d);
          if (!r) return;
          const out = JSON.stringify({ t: 'mg_relay', gid, from: player.id, d: m.d });
          for (const id of r.to) {
            const p = room.players.get(id);
            if (p && p.ws.readyState === 1) p.ws.send(out);
          }
          break;
        }
        case 'direct': {
          if (!rate(player, 'direct', 20)) { if (process.env.NET_DEBUG) console.log('direct: limite', player.name); return; }
          const kind = String(m.kind || '');
          if (!DIRECT_KINDS.has(kind)) return;
          const to = room.players.get(String(m.to || ''));
          if (!to || to.id === player.id || safety.isBlocked(player.id, to.id) || safety.isBlocked(to.id, player.id)) return;
          if (JSON.stringify(m.data ?? null).length > 1500) return;
          if (process.env.NET_DEBUG) console.log('direct', kind, player.name, '->', to.name);
          send(to.ws, { t: 'direct', from: player.id, fromName: player.name, kind, data: m.data ?? null });
          break;
        }
        case 'look': {
          // troca de skin/roupa: os outros veem na hora
          if (m.look && typeof m.look === 'object' && JSON.stringify(m.look).length < 1500) {
            player.look = m.look;
            player.acc.look = m.look;
            if (Number.isFinite(m.level)) player.level = Math.max(1, Math.min(99, m.level | 0));
            broadcast(room, { t: 'look', id: player.id, look: player.look, level: player.level }, player.id);
            player.acc.level = player.level;
            dbSafe(db.saveAccount(player.acc));
          }
          break;
        }
        case 'friend_invite': {
          // chama um amigo para a minha sala (ele recebe um aviso com "Entrar")
          if (!rate(player, 'invite', 2)) return;
          const fid = String(m.id || '');
          if (!friends.areFriends(player.id, fid)) return;
          const to = online.get(fid);
          if (!to) return send(ws, { t: 'notice', text: 'Seu amigo não está jogando agora.' });
          if (to.roomId === room.code) return send(ws, { t: 'notice', text: 'Seu amigo já está na mesma sala!' });
          send(to.ws, { t: 'friend_invite', from: player.id, name: player.name, code: room.code });
          send(ws, { t: 'notice', text: 'Convite enviado!' });
          break;
        }
        case 'block': {
          safety.block(player.id, String(m.target || ''));
          send(ws, { t: 'notice', text: 'Jogador bloqueado.' });
          break;
        }
      }
    });
    ws.on('close', () => {
      if (!player) return;
      if (online.get(player.id) === player) online.delete(player.id);
      const r = rooms.leave(player);
      if (r) {
        if (r.tag) {
          r.tag.leave(player.id);
          sendTag(r);
        }
        broadcast(r, { t: 'leave', id: player.id });
        broadcast(r, { t: 'count', n: r.players.size });
        broadcast(r, { t: 'desks', map: r.deskMap() });
        flushGames(r);
      }
    });
  });

  // Posições dos colegas. Com a escola cheia, cada um recebe 10x/s só quem está
  // PERTO (NEAR_M); quem está longe vai 2x/s. Corta a banda sem ninguém notar
  // (de longe o colega é pequeno e o celular interpola entre as amostras).
  const NEAR_M = 45;
  const FAR_EVERY = 5;
  function sendStates(r) {
    r.tickN = (r.tickN || 0) + 1;
    const moved = [];
    for (const p of r.players.values()) {
      if (p.dirty) {
        p.dirty = false;
        p.lastMove = r.tickN;
        p.stateJson = JSON.stringify({ id: p.id, pos: p.pos, yaw: p.yaw, anim: p.anim });
      }
      if (p.lastMove && r.tickN - p.lastMove < FAR_EVERY) moved.push(p);
    }
    if (!moved.length) return;
    const farTick = r.tickN % FAR_EVERY === 0;
    const small = r.players.size <= 8;
    for (const to of r.players.values()) {
      if (to.ws.readyState !== 1) continue;
      const parts = [];
      for (const p of moved) {
        if (p === to) continue;
        const fresh = p.lastMove === r.tickN;
        if (small) { if (fresh) parts.push(p.stateJson); continue; }
        const a = p.pos || [0, 0, 0];
        const b = to.pos || [0, 0, 0];
        const dx = a[0] - b[0];
        const dz = a[2] - b[2];
        const near = dx * dx + dz * dz < NEAR_M * NEAR_M;
        if (near ? fresh : farTick) parts.push(p.stateJson);
      }
      if (parts.length) to.ws.send('{"t":"states","list":[' + parts.join(',') + ']}');
    }
  }

  // envia estados agregados por sala (~10 Hz)
  const timer = setInterval(() => {
    rooms.prune();
    for (const r of rooms.rooms.values()) {
      sendStates(r);
      // relógio da escola: a mesma fase para todos
      for (const st of r.clock.tick()) {
        if (st.phase !== 'recess') {
          r.games.endAll();
          if (r.tag && r.tag.state !== 'over') {
            r.tag.ends = Math.min(r.tag.ends || Date.now(), Date.now());
            if (r.tag.state === 'lobby') { r.tag.state = 'over'; tagEvents(r, [{ kind: 'cancel', text: 'O sinal tocou!' }]); }
          }
        }
        broadcast(r, { t: 'clock', ...st });
      }
      r.games.tick();
      flushGames(r);
      // pique-pega: o servidor confere quem encostou em quem
      if (r.tag) {
        const evs = r.tag.tick((id) => (r.players.get(id) || {}).pos);
        tagEvents(r, evs);
        r.tagSync = (r.tagSync || 0) + 1;
        if (r.tag && r.tagSync % 10 === 0) sendTag(r); // relógio 1x por segundo
      }
    }
  }, TICK_MS);
  // mantém a conexão viva no Railway e derruba quem caiu sem avisar
  const heartbeat = setInterval(() => {
    for (const ws of wss.clients) {
      if (ws.isAlive === false) { ws.terminate(); continue; }
      ws.isAlive = false;
      ws.ping();
    }
  }, 25000);
  const flushTimer = setInterval(() => analytics.flush(), 10000);
  server.on('close', () => { clearInterval(timer); clearInterval(heartbeat); clearInterval(flushTimer); analytics.flush(); });

  return { server, wss, rooms, accounts, safety, analytics, db, ready, friends, online, close: () => { clearInterval(timer); clearInterval(heartbeat); clearInterval(flushTimer); analytics.flush(); wss.close(); server.close(); server.closeAllConnections(); } };
}

if (require.main === module) {
  const port = Number(process.env.PORT) || 8080;
  const app = createServer();
  app.ready.then((dbOk) => {
    const where = dbOk ? 'banco PostgreSQL' : (app.analytics.file ? app.analytics.file : 'memória');
    app.server.listen(port, () => console.log('Recreio online na porta ' + port + ' · dados em ' + where));
  });
  // Railway manda SIGTERM ao reiniciar: grava o que falta antes de sair
  process.on('SIGTERM', async () => {
    app.analytics.flush();
    await app.db.close().catch(() => {});
    process.exit(0);
  });
}

module.exports = { createServer };
