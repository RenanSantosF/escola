# Modo online (base pronta — desligado por padrão)

O jogo já tem a base para o modo online: servidor em `server/` (Node.js, pronto
para o Railway) e cliente no Godot (`autoloads/network_manager.gd`,
`scripts/online/`). Enquanto `NetworkManager.SERVER_URL` estiver vazio, a opção
online nem aparece nas configurações e o jogo é 100% offline.

## Como colocar no ar (Railway)

1. No Railway: **New Project → Deploy from GitHub repo**, apontando para a pasta
   `server/` (Root Directory = `server`). O `Dockerfile` e o `railway.json` já
   estão prontos (health check em `/health`).
2. Variáveis: `ADMIN_TOKEN` (segredo longo, para moderação). A `PORT` o Railway define.
3. Gere um domínio público e coloque em `autoloads/network_manager.gd`:
   `const SERVER_URL := "wss://SEU-APP.up.railway.app"`.
4. Exporte o APK de novo. Em **Configurações → Online (beta)** a criança ativa o modo.

Testes do servidor: `cd server && npm install && npm test`.

## Como funciona

- **Conta**: convidado com token salvo no aparelho. A criança **não** digita
  e-mail, senha, nome real nem apelido — o nome é gerado ("Foguete Azul 42").
  O token volta para a mesma conta; nível e aparência vêm do save.
- **Salas** (turmas) de até 20 crianças. Quem entra no meio recebe na hora a lista
  de quem já está lá (posição, aparência, nível). Sala cheia → próxima sala.
- **Sincronização**: cada cliente manda posição/direção/animação ~10×/s; o servidor
  agrupa e repassa por sala a cada 100 ms. Os colegas aparecem com o mesmo modelo
  leve dos NPCs, interpolados, com nome e nível em cima da cabeça.
- Cada jogador continua com o próprio progresso (moedas, nível, itens): os mais
  experientes têm mais recursos, como pedido.

## Segurança das crianças

| Proteção | Como |
|---|---|
| Chat rápido | Menores de 13 só usam **frases prontas** ("Bora jogar queimada?", "Valeu!"...). |
| Chat livre | Só 13+ **ou** liberado por um responsável (endpoint `/parent/unlock`, via moderação). |
| Filtro de palavras | Palavrões, ofensas e variações (l33t, acentos, letras repetidas, "p.a.l.a.v.r.a"). Filtrado no aparelho e de novo no servidor. |
| Dados pessoais | Bloqueia telefone, e-mail, links, redes sociais, @perfil, endereço, CEP e pedidos como "onde você mora", "manda foto". |
| Anti-flood | Máx. 5 mensagens a cada 10 s. |
| Silêncio automático | 3 mensagens bloqueadas → 10 min sem chat. 3 crianças diferentes denunciando → silêncio + fila de moderação. |
| Denúncia | Tocar na mensagem → motivo (palavras feias, incomodando, pediu dados, nome estranho, outro). Vai com as últimas mensagens do denunciado como contexto. Quem denuncia já bloqueia automaticamente. |
| Bloqueio | Quem bloqueia deixa de ver e de ser visto no chat. |
| Moderação | `GET /mod/reports` e `POST /mod/mute` (header `x-admin-token`). |
| Sem histórico | O chat mostra só as últimas 6 linhas e nada é salvo no aparelho. |
| Aviso fixo | "Nunca conte seu nome, endereço, escola ou telefone." |

## LGPD / COPPA — o que falta antes de abrir para o público

- Consentimento verificável do responsável para menores (LGPD art. 14 / COPPA):
  um painel do responsável (web) que libera o chat livre e permite apagar a conta.
- Política de privacidade e termos em linguagem simples; classificação indicativa.
- Guardar denúncias e mensagens denunciadas por tempo limitado (ex.: 90 dias).
- Moderadores humanos com rotina diária de revisão da fila; lista de palavras
  revisada sempre.
- Google Play: categoria "Famílias" exige SDKs certificados e nada de anúncios
  personalizados para crianças (ver docs/MONETIZACAO.md).

## Banco de dados (Postgres no Railway) — esquema sugerido

```sql
create table accounts (
  id text primary key, token_hash text unique not null, name text not null,
  age smallint not null, level int default 1, look jsonb default '{}',
  free_chat boolean default false, parent_contact_hash text,
  created_at timestamptz default now(), deleted_at timestamptz
);
create table progress (account_id text references accounts(id), data jsonb, updated_at timestamptz);
create table reports (
  id bigserial primary key, at timestamptz default now(), reporter_id text, target_id text,
  reason text, context jsonb, status text default 'aberta', reviewed_by text
);
create table mutes (account_id text, until timestamptz, reason text);
create table blocks (account_id text, blocked_id text, primary key (account_id, blocked_id));
```

Hoje o servidor guarda tudo em memória (reiniciou = zera). Trocar `Accounts` e
`Safety` por versões com Postgres não muda o protocolo.

## Protocolo (JSON por WebSocket)

Cliente → servidor: `hello {token, age, level, look, room}`, `state {pos, yaw, anim}`,
`quick {i}`, `chat {text}`, `report {target, reason}`, `block {target}`.
Servidor → cliente: `welcome`, `join`, `leave`, `states`, `chat`, `notice`.
Detalhes em `server/src/server.js`.

## Próximos passos do online

- Sincronizar a fase do dia por sala (o servidor já tem `room.phase`).
- Brincadeiras entre jogadores (queimada/futebol multiplayer).
- Salvar progresso no servidor (para trocar de celular sem perder nada).
