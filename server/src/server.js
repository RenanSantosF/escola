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
// Servidor -> cliente
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
const { Accounts } = require('./accounts');
const { Analytics } = require('./analytics');
const { TagGame } = require('./tag_game');

const NEAR_DIST = 18; // metros do canal "Perto de mim"
const EMOTES = new Set(['wave', 'celebrate', 'clap', 'sad', 'stretch', 'scratch_head', 'look_around', 'raise_hand']);
const fs = require('fs');
const path = require('path');

const ADMIN_HTML = path.join(__dirname, '..', 'public', 'admin.html');

const TICK_MS = 100;
const MAX_MSG_BYTES = 2048;

function createServer(opts = {}) {
  const adminToken = opts.adminToken ?? process.env.ADMIN_TOKEN ?? '';
  const accounts = opts.accounts || new Accounts();
  const safety = opts.safety || new Safety();
  const rooms = new RoomManager();
  const analytics = opts.analytics || new Analytics(opts.dataDir !== undefined ? { dataDir: opts.dataDir } : {});
  const recentChat = new Map(); // roomId -> últimas mensagens (contexto p/ denúncia)

  function isAdmin(req) {
    return adminToken !== '' && req.headers['x-admin-token'] === adminToken;
  }

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
      return json(200, { ok: true, rooms: l.rooms, players: l.online });
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
    if (url === '/api/rooms' && req.method === 'GET') {
      return json(200, { rooms: rooms.publicList(), online: liveInfo().online });
    }
    // Painel do administrador (protegido por ADMIN_TOKEN)
    if (url === '/api/admin/stats' && req.method === 'GET') {
      if (!isAdmin(req)) return json(403, { ok: false, error: 'token inválido' });
      const st = analytics.stats(liveInfo());
      st.live.roomList = [...rooms.rooms.values()].map((r) => ({ ...r.info(), ages: [...r.players.values()].map((p) => p.acc.age) }));
      st.reports = safety.reports.slice(-50).reverse();
      st.storage = analytics.file ? 'volume' : 'memória (zera ao reiniciar)';
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
    // Liberação de chat livre por responsável (validado pela moderação)
    if ((url === '/parent/unlock' || url === '/api/admin/unlock') && req.method === 'POST') {
      if (!isAdmin(req)) return json(403, { ok: false });
      const b = await readJson(req);
      for (const acc of accounts.byToken.values()) {
        if (acc.id === b.id) { acc.freeChat = !!b.allow; return json(200, { ok: true }); }
      }
      return json(404, { ok: false });
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
    ws.on('message', (raw) => {
      let m;
      try { m = JSON.parse(raw.toString()); } catch { return; }
      if (!m || typeof m.t !== 'string') return;
      if (!player) {
        if (m.t !== 'hello') return;
        const acc = accounts.getOrCreate(typeof m.token === 'string' ? m.token : '', { age: m.age, level: m.level, look: m.look });
        player = { id: acc.id, name: acc.name, level: acc.level, look: acc.look, pos: [0, 0, 70], yaw: 0, anim: 'idle', ws, acc, dirty: true };
        let r;
        if (m.mode === 'create') r = rooms.create(player, true);
        else if (m.mode === 'code') r = rooms.joinCode(player, m.code);
        else r = rooms.join(player, typeof m.room === 'string' ? m.room.slice(0, 8) : null);
        if (r.error) {
          player = null;
          return send(ws, { t: 'join_error', text: r.error });
        }
        room = r;
        send(ws, {
          t: 'welcome', token: acc.token, id: acc.id, name: acc.name, room: room.id, code: room.code, private: room.private,
          freeChat: accounts.canFreeChat(acc), quick: QUICK_PHRASES, players: room.snapshot(acc.id), phase: room.phase,
        });
        broadcast(room, { t: 'join', player: { id: player.id, name: player.name, level: player.level, look: player.look, pos: player.pos, yaw: player.yaw, anim: player.anim } }, player.id);
        broadcast(room, { t: 'count', n: room.players.size });
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
        case 'look': {
          // troca de skin/roupa: os outros veem na hora
          if (m.look && typeof m.look === 'object' && JSON.stringify(m.look).length < 1500) {
            player.look = m.look;
            player.acc.look = m.look;
            if (Number.isFinite(m.level)) player.level = Math.max(1, Math.min(99, m.level | 0));
            broadcast(room, { t: 'look', id: player.id, look: player.look, level: player.level }, player.id);
          }
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
      const r = rooms.leave(player);
      if (r) {
        if (r.tag) {
          r.tag.leave(player.id);
          sendTag(r);
        }
        broadcast(r, { t: 'leave', id: player.id });
        broadcast(r, { t: 'count', n: r.players.size });
      }
    });
  });

  // envia estados agregados por sala (~10 Hz)
  const timer = setInterval(() => {
    for (const r of rooms.rooms.values()) {
      const list = [];
      for (const p of r.players.values()) {
        if (!p.dirty) continue;
        p.dirty = false;
        list.push({ id: p.id, pos: p.pos, yaw: p.yaw, anim: p.anim });
      }
      if (list.length) broadcast(r, { t: 'states', list });
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

  return { server, wss, rooms, accounts, safety, analytics, close: () => { clearInterval(timer); clearInterval(heartbeat); clearInterval(flushTimer); analytics.flush(); wss.close(); server.close(); server.closeAllConnections(); } };
}

if (require.main === module) {
  const port = Number(process.env.PORT) || 8080;
  const app = createServer();
  app.server.listen(port, () => console.log('Recreio online na porta ' + port + (app.analytics.file ? ' · dados em ' + app.analytics.file : ' · dados em memória')));
  // Railway manda SIGTERM ao reiniciar: grava o que falta antes de sair
  process.on('SIGTERM', () => { app.analytics.flush(); process.exit(0); });
}

module.exports = { createServer };
