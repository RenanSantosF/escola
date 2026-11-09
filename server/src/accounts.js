'use strict';
// Contas: convidado com token (sem e-mail/senha da criança). Progresso fica
// ligado ao token. Faixa etária decide o chat:
//  - menor de 13: só chat rápido (frases prontas), a menos que um
//    responsável libere com o código parental (LGPD/COPPA)
//  - 13+: chat livre filtrado
// Persistência: em memória aqui; em produção use Postgres no Railway
// (tabela accounts — ver docs/ONLINE.md).

const crypto = require('crypto');

const NAME_PARTS_A = ['Craque', 'Foguete', 'Gênio', 'Ninja', 'Raio', 'Estrela', 'Pirata', 'Robô', 'Tigre', 'Coruja'];
const NAME_PARTS_B = ['Azul', 'Dourado', 'Veloz', 'Feliz', 'Sabido', 'Corajoso', 'Brilhante', 'Legal'];

class Accounts {
  constructor() {
    this.byToken = new Map();
  }
  /** Nomes são gerados (crianças não digitam nome real nem apelido livre). */
  static randomName() {
    const a = NAME_PARTS_A[crypto.randomInt(NAME_PARTS_A.length)];
    const b = NAME_PARTS_B[crypto.randomInt(NAME_PARTS_B.length)];
    return a + ' ' + b + ' ' + crypto.randomInt(10, 99);
  }
  getOrCreate(token, info = {}) {
    if (token && this.byToken.has(token)) {
      const acc = this.byToken.get(token);
      if (info.level) acc.level = Math.max(acc.level, info.level | 0);
      if (info.look) acc.look = info.look;
      return acc;
    }
    const acc = {
      token: crypto.randomBytes(18).toString('hex'),
      id: crypto.randomBytes(6).toString('hex'),
      name: Accounts.randomName(),
      age: Math.max(5, Math.min(18, info.age | 0 || 9)),
      level: Math.max(1, info.level | 0 || 1),
      look: info.look || {},
      freeChat: false, // liberado só com código parental
      createdAt: new Date().toISOString(),
    };
    this.byToken.set(acc.token, acc);
    return acc;
  }
  /** Coloca na memória uma conta vinda do banco. */
  adopt(acc) {
    this.byToken.set(acc.token, acc);
    return acc;
  }
  findById(id) {
    for (const a of this.byToken.values()) if (a.id === id) return a;
    return null;
  }
  canFreeChat(acc) {
    return acc.age >= 13 || acc.freeChat === true;
  }
}

module.exports = { Accounts };
