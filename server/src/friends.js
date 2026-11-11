'use strict';
// Amizades entre contas. Para segurança das crianças, amizade só existe quando
// os DOIS aceitam: quem adiciona pelo nome manda um PEDIDO; o outro aceita.
// Guardado em memória e (se houver banco) na tabela friends.
//
// pares: chave "a|b" (ids em ordem) -> {a, b, aName, bName, from, status}
//   status: 'pending' (from pediu) | 'friends'

const MAX_FRIENDS = 60;

class Friends {
  constructor() {
    this.pairs = new Map();
  }

  static key(x, y) {
    return x < y ? x + '|' + y : y + '|' + x;
  }

  load(rows) {
    for (const r of rows) this.pairs.set(Friends.key(r.a, r.b), { ...r });
  }

  _count(id) {
    let n = 0;
    for (const p of this.pairs.values()) if (p.status === 'friends' && (p.a === id || p.b === id)) n++;
    return n;
  }

  /**
   * Pedido de amizade. Se o outro já tinha pedido, viram amigos na hora.
   * Retorna {status:'sent'|'friends'|'already'|'error', pair?, error?}
   */
  request(me, meName, other, otherName) {
    if (me === other) return { status: 'error', error: 'Esse é você!' };
    const k = Friends.key(me, other);
    const p = this.pairs.get(k);
    if (p && p.status === 'friends') return { status: 'already', pair: p };
    if (this._count(me) >= MAX_FRIENDS) return { status: 'error', error: 'Sua lista de amigos está cheia.' };
    if (p && p.status === 'pending') {
      if (p.from === other) {
        p.status = 'friends';
        return { status: 'friends', pair: p };
      }
      return { status: 'already', pair: p };
    }
    const [a, b] = me < other ? [me, other] : [other, me];
    const pair = { a, b, aName: a === me ? meName : otherName, bName: b === me ? meName : otherName, from: me, status: 'pending' };
    this.pairs.set(k, pair);
    return { status: 'sent', pair };
  }

  /** Aceita um pedido que recebeu. */
  accept(me, other) {
    const p = this.pairs.get(Friends.key(me, other));
    if (!p || p.status !== 'pending' || p.from === me) return null;
    p.status = 'friends';
    return p;
  }

  /** Remove amizade ou recusa/cancela pedido. */
  remove(me, other) {
    const k = Friends.key(me, other);
    const p = this.pairs.get(k);
    if (!p) return null;
    this.pairs.delete(k);
    return p;
  }

  areFriends(x, y) {
    const p = this.pairs.get(Friends.key(x, y));
    return !!p && p.status === 'friends';
  }

  /** Lista de um jogador: [{id, name, status:'friend'|'incoming'|'outgoing'}] */
  list(me) {
    const out = [];
    for (const p of this.pairs.values()) {
      if (p.a !== me && p.b !== me) continue;
      const other = p.a === me ? p.b : p.a;
      const name = p.a === me ? p.bName : p.aName;
      const status = p.status === 'friends' ? 'friend' : (p.from === me ? 'outgoing' : 'incoming');
      out.push({ id: other, name, status });
    }
    return out;
  }

  removeAll(id) {
    for (const [k, p] of this.pairs) if (p.a === id || p.b === id) this.pairs.delete(k);
  }
}

module.exports = { Friends, MAX_FRIENDS };
