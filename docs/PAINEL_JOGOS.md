# Painel dos Jogos

O painel do servidor (`/admin`, mesmo `ADMIN_TOKEN` de sempre) mostra as
métricas de **todos os jogos da casa**, não só do Recess Club.

## Abas

- **🏆 Todos os jogos** — ranking dos últimos 7 dias com nota de destaque
  (0–100), quem está jogando agora, ativos, crescimento contra a semana
  anterior, novos, sessão média, minutos por jogador, retenção D1/D7, horas
  jogadas e gráficos de jogadores e minutos por dia de cada jogo.
- **Uma aba por jogo** — escolha o período (hoje, 7, 14, 30, 90 dias):
  - jogando agora, ativos, novos, hoje/7/30 dias, tempo médio por sessão,
    tempo por jogador, sessões, horas, retenção D1/D7/D30 — todos com a
    variação contra o período anterior;
  - novos x que voltaram por dia, tempo médio por sessão por dia;
  - curva de retenção (D0–D30) e evolução da retenção D1 por dia de entrada
    (mostra se a retenção está aumentando);
  - mapa de calor dia da semana × hora (horário de Brasília);
  - duração das sessões, minutos por dia, coortes semanais;
  - **quem entrou**: sessões recentes com horário, quanto ficou, visita nº,
    versão e plataforma; jogadores mais dedicados; fases/partidas.
- A aba **Recess Club** traz também o painel antigo (loja, brincadeiras,
  bots, versão mínima, salas e denúncias).

A nota de destaque junta alcance (35%), minutos por jogador (25%), retenção
D1 (25%) e crescimento (15%), cada um comparado com o melhor jogo.

## Como os jogos enviam

Cada jogo tem o autoload `Telemetry` (`telemetry.gd`) com o `GAME_ID` dele:

| Jogo | GAME_ID |
|---|---|
| Recess Club | `escola` (usa o `autoloads/telemetry.gd` próprio e `/api/events`) |
| Aqua Caos | `aqua-caos` |
| Arrow Survival | `arrow-survival` |
| Gross to Glow | `gross-to-glow` |
| Road Rush 3D | `road-rush` |
| Lanche em Pânico | `lanche-em-panico` |

`POST /api/games/events` com `{game, uid, events}`:
`session_start` (versão, plataforma, idioma), `heartbeat` a cada minuto,
`session_end`, `level` (`Telemetry.level(fase, venceu, pontos)`) e `event`
(`Telemetry.event("nome", {...})`). O servidor guarda **uma linha por
sessão** (não cada heartbeat) nas tabelas `game_sessions`, `game_players` e
`game_events` do PostgreSQL (ou em `DATA_DIR/games.jsonl` sem banco).

Nada é enviado rodando pelo editor nem nos testes headless. O `uid` é um
código aleatório salvo em `user://telemetry.cfg` — sem nome, e-mail,
localização ou ID de publicidade.

### Novo jogo

1. Acrescente o jogo em `GAMES` no `server/src/game_stats.js` (id, nome,
   emoji e cor — a cor fica fixa para o jogo).
2. Copie um `telemetry.gd` para o jogo, troque `GAME_ID` e registre como
   autoload `Telemetry`.
3. Chame `Telemetry.level(...)` onde a fase/partida termina.
4. Atualize a política de privacidade do jogo (estatísticas anônimas) e o
   formulário de Segurança dos dados na Play Console.
