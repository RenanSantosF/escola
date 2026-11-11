'use strict';
// Relógio da escola de cada sala: o SERVIDOR decide a fase do dia e todo
// mundo da sala vive o mesmo momento (chegada, aula, recreio, volta, aula,
// saída). Quem entra no meio recebe a fase atual e quanto falta.
//
// state() -> {day, phase, index, startedAt, endsAt, seed}

const PHASES = [
  { id: 'arrival', ms: 75000 },
  { id: 'class1', ms: 240000 },
  { id: 'recess', ms: 720000 }, // 12 min: tempo de sobra para brincar
  { id: 'return', ms: 60000 },
  { id: 'class2', ms: 180000 },
  { id: 'end', ms: 45000 },
];

class SchoolClock {
  /**
   * opts.scale: multiplica as durações (testes rodam o dia em segundos).
   * opts.startPhase: fase inicial (padrão: chegada).
   */
  constructor(now = Date.now(), opts = {}) {
    this.scale = Number(opts.scale) > 0 ? Number(opts.scale) : 1;
    this.day = 1;
    this.index = Math.max(0, PHASES.findIndex((p) => p.id === (opts.startPhase || 'arrival')));
    this.startedAt = now;
    this.seed = Math.floor(Math.random() * 1e9);
  }

  duration(i) { return Math.round(PHASES[i].ms * this.scale); }

  get endsAt() { return this.startedAt + this.duration(this.index); }

  /** Avança as fases vencidas. Retorna a lista de fases que começaram. */
  tick(now = Date.now()) {
    const started = [];
    let guard = 0;
    while (now >= this.endsAt && guard++ < 20) {
      const end = this.endsAt;
      this.index++;
      if (this.index >= PHASES.length) {
        this.index = 0;
        this.day++;
        this.seed = Math.floor(Math.random() * 1e9);
      }
      this.startedAt = end;
      started.push(this.state(now));
    }
    return started;
  }

  /** Pula direto para uma fase (painel/testes). */
  jump(phaseId, now = Date.now()) {
    const i = PHASES.findIndex((p) => p.id === phaseId);
    if (i < 0) return false;
    this.index = i;
    this.startedAt = now;
    return true;
  }

  state(now = Date.now()) {
    return {
      day: this.day, phase: PHASES[this.index].id, index: this.index,
      startedAt: this.startedAt, endsAt: this.endsAt, now, seed: this.seed,
      left: Math.max(0, Math.ceil((this.endsAt - now) / 1000)),
    };
  }
}

module.exports = { SchoolClock, PHASES };
