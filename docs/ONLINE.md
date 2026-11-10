# Modo online (base pronta — desligado por padrão)

O jogo já tem a base para o modo online: servidor em `server/` (Node.js, pronto
para o Railway) e cliente no Godot (`autoloads/network_manager.gd`,
`scripts/online/`). Sem endereço de servidor configurado o jogo é 100% offline.

## Servidor no ar

Servidor oficial: `https://escola-production-061f.up.railway.app` (já fixo no jogo em
`NetworkManager.SERVER_URL`; ninguém precisa colar endereço).

- **Painel do administrador:** abra `https://escola-production-061f.up.railway.app/admin`
  e entre com o `ADMIN_TOKEN` (variável do serviço no Railway).
- **Banco de dados (recomendado):** no projeto do Railway → **+ New → Database → Add
  PostgreSQL**. Depois, no serviço do jogo → **Variables → New Variable** → nome
  `DATABASE_URL`, valor `${{Postgres.DATABASE_URL}}` (o Railway completa sozinho; ninguém
  copia senha). No próximo deploy o servidor cria as tabelas e passa a guardar contas,
  denúncias, silenciamentos, bloqueios e estatísticas. Confira em `/health` → `"db": true`.
  (Sem banco, dá para usar um Volume em `/data` com `DATA_DIR=/data`; sem nenhum dos dois,
  tudo fica em memória e zera a cada deploy.)
- Deploy: Railway → serviço → Settings → Source (branch do GitHub) e Root Directory `/server`.

Testes do servidor: `cd server && npm install && npm test`.
Teste ponta a ponta local: `cd server && PORT=8131 node src/server.js` e
`godot --headless --path . res://tests/online_probe.tscn -- --url=ws://127.0.0.1:8131`.

## Contas (o jogo agora é só online)

- **Criar conta:** idade → apelido escolhido de uma lista gerada pelo servidor (nunca
  texto livre) → **código secreto** de recuperação (4 palavras + número, ex.:
  `BOLA SOL LUA RIO 47`) para anotar com um adulto. Sem e-mail, senha, telefone ou nome.
- **Outro celular:** "Já tenho conta" → digitar o código → o progresso volta inteiro
  (moedas, itens, skins, nível, amizades...). O token do aparelho antigo deixa de valer.
- **Progresso na nuvem:** enviado a cada salvamento (no máximo a cada 20 s) e ao sair;
  ao abrir o jogo, se a nuvem tiver progresso mais novo, ele é baixado.
- **Apagar conta (LGPD):** Configurações → Minha conta → Apagar minha conta.
- Rotas: `GET /api/account/names`, `POST /api/account/register`, `POST /api/account/recover`
  (limite de 8 tentativas a cada 10 min por IP), `GET /api/account/me`, `PUT /api/progress`,
  `DELETE /api/account`. Token e código guardados só como hash no banco.
- Sem internet não dá para jogar: o jogo avisa "Reconectando..." e, depois de 25 s,
  oferece "Tentar de novo" ou "Voltar ao menu".

## Jogar online (no jogo)

Menu principal → **Jogar online**:
- **Entrar numa sala** — cai na turma pública com mais gente (até 20).
- **Criar sala com amigos** — sala PRIVADA com código de 4 números (mostrado no topo da tela).
- **Entrar com código** — teclado numérico grande para digitar o código do amigo.

Os alunos-bot continuam no online: a cada jogador a mais na sala, 2 alunos-bot de outras
turmas deixam de aparecer no recreio, com um mínimo de 4. Os colegas de turma (que dão
missões), o Seu Zé, a Dona Lúcia e os adultos ficam sempre.

## Chat, reações e pique-pega

- **Canais:** "Todos da sala" e "Perto de mim" (só quem está a até 18 m recebe).
  Frases rápidas sempre; texto livre só para 13+ ou com liberação do responsável.
- **Reações:** acenar, comemorar, palmas, levantar a mão — os outros veem o personagem fazer.
- **Pique-pega online:** botão "Pique-pega!" chama a sala toda (convite na tela de todos).
  Quem aceita vai para a árvore do pátio central (seta vermelha). Começa depois de 20 s ou
  quando quem chamou toca em "Começar agora" (mínimo 2). O **servidor** confere quem
  encostou em quem (< 1,4 m), com 3 s de "não vale pegar de volta". 2 minutos; ganha quem
  passou menos tempo como pegador (1º: 40 moedas, 2º: 25, 3º: 15, demais: 8). Enquanto
  brincam, o recreio de quem está jogando não acaba.

## Chamada de voz — decisão

Não implementada de propósito. Para crianças menores de 13, voz ao vivo é o canal mais
difícil de moderar (não dá para filtrar palavrão nem pedido de dado pessoal em tempo
real) e a voz é dado pessoal pela LGPD/COPPA. A Google Play (programa Famílias) exige
cuidado extra com comunicação entre usuários. Se for fazer no futuro: só 13+ com
consentimento do responsável, só entre amigos aceitos, botão "aperte para falar",
botão de denúncia e silenciar na hora — e exige servidor de voz (WebRTC + TURN) e um
plugin nativo no Godot. A alternativa segura já existente são as frases rápidas, o canal
"Perto de mim" e as reações.

## Painel e estatísticas anônimas

O jogo envia (a cada minuto, se houver internet e a opção estiver ligada em
Configurações → Privacidade) eventos anônimos: início/fim de sessão (idade e nível),
compras com moedas do jogo, brincadeiras, missões e dias concluídos. Cada aparelho tem
um código aleatório — sem nome, e-mail, telefone, localização ou ID de publicidade.

O painel mostra: online agora e salas abertas (com idades), total de jogadores, ativos
24 h/7 dias, novos, retenção, tempo médio e mediano por sessão, horas jogadas, gráfico
de 14 dias, idades, tempo médio por idade, níveis, horários de pico, itens mais
comprados, maiores/menores/recentes compras, moedas por categoria, brincadeiras mais
jogadas (com % de vitória), missões concluídas e denúncias recentes com contexto.

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

Com `DATABASE_URL` o servidor cria estas tabelas sozinho (`server/src/db.js`): accounts
(token guardado só como hash SHA-256), events, reports, mutes e blocks. Testes com banco
real: `TEST_DATABASE_URL=postgres://... npm test`.

## Protocolo (JSON por WebSocket)

Cliente → servidor: `hello {token, age, level, look, room}`, `state {pos, yaw, anim}`,
`quick {i}`, `chat {text}`, `report {target, reason}`, `block {target}`.
Servidor → cliente: `welcome`, `join`, `leave`, `states`, `chat`, `notice`.
Detalhes em `server/src/server.js`.

## Próximos passos do online

- Sincronizar a fase do dia por sala (o servidor já tem `room.phase`).
- Brincadeiras entre jogadores (queimada/futebol multiplayer).
- Salvar progresso no servidor (para trocar de celular sem perder nada).
