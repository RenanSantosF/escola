'use strict';
// Banco de perguntas das aulas. A base vem de data/questions.json (a mesma
// lista que vai dentro do jogo); a equipe adiciona/edita/desativa perguntas
// pelo painel e elas ficam no Postgres (tabela questions). O jogo baixa a
// lista ao abrir (GET /api/questions?v=<versão que já tem>).

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const FILE = path.join(__dirname, '..', 'data', 'questions.json');
const SUBJECTS = ['Matemática', 'Português', 'Ciências', 'Geografia', 'História', 'Inglês', 'Artes',
  'Música', 'Física', 'Química', 'Informática', 'Educação Física'];

function clean(q) {
  const w = Array.isArray(q.w) ? q.w.map((x) => String(x).trim().slice(0, 80)).filter(Boolean) : [];
  const out = {
    s: String(q.s || '').trim(), a: Math.max(1, Math.min(9, q.a | 0 || 1)), b: Math.max(1, Math.min(9, q.b | 0 || 9)),
    q: String(q.q || '').trim().slice(0, 200), c: String(q.c || '').trim().slice(0, 80), w: w.slice(0, 3),
    e: String(q.e || '').trim().slice(0, 240), active: q.active !== false,
  };
  if (out.b < out.a) out.b = out.a;
  return out;
}

function problem(q) {
  if (!SUBJECTS.includes(q.s)) return 'Matéria inválida';
  if (q.q.length < 5) return 'Escreva a pergunta';
  if (!q.c) return 'Escreva a resposta certa';
  if (q.w.length < 3) return 'Escreva 3 respostas erradas';
  if (q.w.includes(q.c) || new Set(q.w).size < 3) return 'As respostas precisam ser diferentes';
  return '';
}

class QuestionBank {
  constructor(opts = {}) {
    this.base = [];
    try {
      const data = JSON.parse(fs.readFileSync(opts.file || FILE, 'utf8'));
      this.base = (data.questions || []).map(clean).filter((q) => !problem(q));
      this.baseVersion = data.version | 0;
    } catch (e) {
      console.error('perguntas: não leu', e.message);
      this.baseVersion = 0;
    }
    this.extra = new Map(); // texto da pergunta -> pergunta (do banco/painel)
    this._payload = null;
  }

  load(rows) {
    for (const r of rows || []) this.extra.set(r.q, { ...clean(r), id: r.id });
    this._payload = null;
  }

  add(raw) {
    const q = clean(raw);
    const err = problem(q);
    if (err) return { error: err };
    this.extra.set(q.q, q);
    this._payload = null;
    return { q };
  }

  /** Lista final: base + banco (o banco sobrescreve/desativa pela pergunta). */
  all() {
    const map = new Map();
    for (const q of this.base) map.set(q.q, q);
    for (const q of this.extra.values()) map.set(q.q, q);
    return [...map.values()].filter((q) => q.active !== false);
  }

  payload() {
    if (!this._payload) {
      const questions = this.all().map(({ s, a, b, q, c, w, e }) => ({ s, a, b, q, c, w, e }));
      const h = crypto.createHash('sha1').update(JSON.stringify(questions)).digest();
      const version = h.readUInt32BE(0) % 2000000000 + 1;
      this._payload = { version, count: questions.length, questions };
    }
    return this._payload;
  }

  counts() {
    const c = {};
    for (const q of this.all()) c[q.s] = (c[q.s] || 0) + 1;
    return c;
  }
}

module.exports = { QuestionBank, SUBJECTS, clean, problem };
