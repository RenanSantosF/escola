'use strict';
// Contas das crianças — sem e-mail, senha, telefone ou nome real.
// - Criar conta: a criança escolhe um APELIDO de uma lista gerada pelo
//   servidor (nunca texto livre) e informa a idade.
// - Recebe um CÓDIGO DE RECUPERAÇÃO (palavras + número, ex.: BOLA-SOL-LUA-RIO-47)
//   para entrar em outro celular. Guardado só como hash.
// - O progresso do jogo (moedas, itens, nível...) fica salvo no servidor.
// - Faixa etária decide o chat: menor de 13 só frases prontas, a menos que
//   um responsável libere (LGPD/COPPA); 13+ chat livre filtrado.
// Persistência: memória + banco (db.js) quando DATABASE_URL existe.

const crypto = require('crypto');

const NAME_PARTS_A = ['Craque', 'Foguete', 'Gênio', 'Ninja', 'Raio', 'Estrela', 'Pirata', 'Robô', 'Tigre', 'Coruja',
  'Cometa', 'Panda', 'Dragão', 'Capitão', 'Mestre', 'Golfinho', 'Falcão', 'Trovão'];
const NAME_PARTS_B = ['Azul', 'Dourado', 'Veloz', 'Feliz', 'Sabido', 'Corajoso', 'Brilhante', 'Legal', 'Verde', 'Esperto',
  'Gentil', 'Radical', 'Mágico', 'Animado'];
const CODE_WORDS = ['BOLA', 'SOL', 'LUA', 'RIO', 'MAR', 'GATO', 'PATO', 'CASA', 'FLOR', 'NUVEM', 'PIPA', 'UVA', 'SAPO',
  'TATU', 'LEAO', 'ONCA', 'ARARA', 'MILHO', 'BOLO', 'SUCO', 'TREM', 'BARCO', 'FOCA', 'ZEBRA', 'MANGA', 'CAJU', 'COCO',
  'PIAO', 'DADO', 'LAPIS', 'LIVRO', 'ESTRELA', 'RAIO', 'VENTO', 'CHUVA', 'NEVE', 'FOGO', 'PEDRA', 'AREIA', 'ILHA'];

const sha = (t) => crypto.createHash('sha256').update(String(t)).digest('hex');
const PROGRESS_MAX = 256 * 1024;

class Accounts {
  constructor() {
    this.byToken = new Map();
    this.byRecovery = new Map(); // hash -> conta
  }

  static randomName() {
    const a = NAME_PARTS_A[crypto.randomInt(NAME_PARTS_A.length)];
    const b = NAME_PARTS_B[crypto.randomInt(NAME_PARTS_B.length)];
    return a + ' ' + b + ' ' + crypto.randomInt(10, 99);
  }

  /** Opções de apelido para a criança escolher. */
  static nameOptions(n = 6) {
    const set = new Set();
    while (set.size < n) set.add(Accounts.randomName());
    return [...set];
  }

  /** Só aceita apelidos no formato gerado (proteção contra nome real/ofensivo). */
  static validName(name) {
    const m = /^(\S+) (\S+) (\d{2})$/.exec(String(name || ''));
    return !!m && NAME_PARTS_A.includes(m[1]) && NAME_PARTS_B.includes(m[2]);
  }

  static newRecoveryCode() {
    const w = [];
    for (let i = 0; i < 4; i++) w.push(CODE_WORDS[crypto.randomInt(CODE_WORDS.length)]);
    return w.join('-') + '-' + crypto.randomInt(10, 99);
  }

  static normalizeCode(code) {
    return String(code || '').toUpperCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^A-Z0-9]+/g, '-').replace(/^-|-$/g, '');
  }

  _new(info = {}) {
    return {
      token: crypto.randomBytes(18).toString('hex'),
      id: crypto.randomBytes(6).toString('hex'),
      name: Accounts.validName(info.name) ? info.name : Accounts.randomName(),
      age: Math.max(5, Math.min(18, info.age | 0 || 9)),
      level: Math.max(1, info.level | 0 || 1),
      look: info.look || {},
      freeChat: false, // liberado só por responsável
      registered: false,
      progress: null,
      progressAt: 0,
      createdAt: new Date().toISOString(),
    };
  }

  /** Conta registrada: apelido escolhido + código de recuperação. */
  register(info = {}) {
    const acc = this._new(info);
    acc.registered = true;
    const code = Accounts.newRecoveryCode();
    acc.recoveryHash = sha(Accounts.normalizeCode(code));
    this.adopt(acc);
    return { acc, code };
  }

  /** Busca pela recuperação (memória). */
  findByRecovery(code) {
    return this.byRecovery.get(sha(Accounts.normalizeCode(code))) || null;
  }

  getOrCreate(token, info = {}) {
    if (token && this.byToken.has(token)) {
      const acc = this.byToken.get(token);
      if (info.level) acc.level = Math.max(acc.level, info.level | 0);
      if (info.look) acc.look = info.look;
      return acc;
    }
    const acc = this._new(info);
    this.adopt(acc);
    return acc;
  }

  /** Coloca na memória uma conta (nova ou vinda do banco). */
  adopt(acc) {
    this.byToken.set(acc.token, acc);
    if (acc.recoveryHash) this.byRecovery.set(acc.recoveryHash, acc);
    return acc;
  }

  findById(id) {
    for (const a of this.byToken.values()) if (a.id === id) return a;
    return null;
  }

  remove(acc) {
    this.byToken.delete(acc.token);
    if (acc.recoveryHash) this.byRecovery.delete(acc.recoveryHash);
  }

  /** Guarda o progresso; o mais novo vence. Retorna false se inválido/antigo. */
  setProgress(acc, save, savedAt) {
    const json = JSON.stringify(save || {});
    if (json.length > PROGRESS_MAX || typeof save !== 'object' || Array.isArray(save)) return false;
    const at = Number(savedAt) || Date.now();
    if (acc.progressAt && at < acc.progressAt) return false;
    acc.progress = save;
    acc.progressAt = at;
    const p = save.player || {};
    if (p.level) acc.level = Math.max(1, Math.min(999, p.level | 0));
    if (p.appearance && typeof p.appearance === 'object') acc.look = p.appearance;
    return true;
  }

  canFreeChat(acc) {
    return acc.age >= 13 || acc.freeChat === true;
  }
}

module.exports = { Accounts, sha, PROGRESS_MAX };
