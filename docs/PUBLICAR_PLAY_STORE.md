# Publicar o Recess Club na Google Play

Arquivos que você recebeu:

| Arquivo | Para quê |
|---|---|
| `recess-club.aab` | O que vai para a Play Store (versão 1.0.0, código 1). Anúncios **reais**. |
| `recess-club.apk` | Para testar no seu celular. Anúncios de **teste** do Google (pode clicar à vontade). |
| `recess-club-upload.keystore` + `LEIA-chave-de-upload.txt` | Chave de upload. **Guarde os dois** (Drive + gerenciador de senhas). Toda atualização precisa dela. |

> Não clique nos anúncios reais do seu próprio app (a conta AdMob pode ser suspensa).
> Para testar, use o APK (anúncios de teste).

## 0. Antes de tudo (5 minutos)

1. **Railway → Variables** do serviço do jogo: crie `CONTACT_EMAIL` com o e-mail de
   contato do desenvolvedor (aparece na política de privacidade). Faça o **redeploy**.
2. Confira no navegador:
   - Política: `https://escola-production-061f.up.railway.app/privacidade`
   - Excluir conta: `https://escola-production-061f.up.railway.app/excluir-conta`
   - app-ads.txt: `https://escola-production-061f.up.railway.app/app-ads.txt`

## 1. Criar o app no Play Console

1. [play.google.com/console](https://play.google.com/console) → **Criar app**.
2. Nome: **Recess Club** · Idioma padrão: Português (Brasil) · **Jogo** · **Gratuito**.
3. Aceite as declarações.

> Contas pessoais novas precisam de um **teste fechado com 12 testadores por 14 dias**
> antes de liberar a produção. Comece por: **Testar → Teste fechado** → crie a faixa,
> envie o `.aab` e convide os testadores (lista de e-mails ou Grupo do Google).

## 2. Enviar o AAB

**Testar → Teste fechado (ou Produção) → Criar versão**

1. Na primeira vez, aceite a **Assinatura de apps do Google Play** (o Google guarda a
   chave final; a sua é só a de upload).
2. Envie `recess-club.aab`.
3. Nome da versão: `1.0.0` · Notas: "Primeira versão do Recess Club!"

O jogo já está no **Godot 4.7.2**: as bibliotecas de 64 bits são alinhadas em
**16 KB** (exigência do Google para Android 15+), alvo **Android 16 (API 36)**.

## 3. Conteúdo do app (Política → Conteúdo do app)

| Item | Resposta |
|---|---|
| Política de privacidade | `https://escola-production-061f.up.railway.app/privacidade` |
| Acesso ao app | "Todas as funcionalidades estão disponíveis sem acesso especial" (a criança cria a conta no jogo; se pedirem, crie uma conta de teste e informe nome e senha) |
| Anúncios | **Sim, o app contém anúncios** |
| Classificação do conteúdo (IARC) | Categoria Jogo. Violência: não. Interação entre usuários: **sim** (chat filtrado e moderado). Compartilha localização: não. Compras digitais: não. Esperado: **Livre** |
| Público-alvo | Faixas **6–8, 9–12** (pode incluir 13–15). Isso coloca o app no programa **Famílias** |
| Apps para crianças | Os anúncios usam SDK certificado (AdMob) com tratamento infantil — responda que sim, segue as políticas para Famílias |
| ID de publicidade | **Não** usa o ID de publicidade (a permissão foi removida do app) |
| App de governo / financeiro / saúde | Não |
| Segurança dos dados | ver abaixo |
| Exclusão de conta | `https://escola-production-061f.up.railway.app/excluir-conta` (e "pelo app: Configurações → Apagar minha conta") |

### Segurança dos dados (Data safety)

- O app coleta ou compartilha dados? **Sim**. Criptografados em trânsito? **Sim**.
  Usuário pode pedir exclusão? **Sim**.
- **Informações pessoais → Nome de usuário/ID** (apelido de jogador): coletado,
  não compartilhado, obrigatório. Finalidade: funcionalidade do app, gerenciamento da conta.
- **Mensagens no app** (chat): coletado, não compartilhado. Finalidade: funcionalidade,
  segurança/prevenção de fraude (moderação de denúncias).
- **Atividade no app → Interações / Histórico do jogo** (progresso): coletado.
  Finalidade: funcionalidade, análise (estatísticas anônimas).
- **Informações do app e desempenho → Diagnóstico**: coletado pelo SDK de anúncios.
- **Identificadores do dispositivo**: o app **não** usa o ID de publicidade; o AdMob
  pode processar IP/modelo do aparelho para entregar o anúncio → marque
  "Identificadores do dispositivo ou outros IDs" como compartilhado com finalidade
  **Publicidade ou marketing**, se o formulário pedir.
- Senha: guardada só criptografada (não precisa declarar como dado coletado à parte).

## 4. Página da loja

- **Nome:** Recess Club
- **Descrição curta (80):** Brinque no recreio online com a turma: futebol, queimada, xadrez e muito mais!
- **Descrição completa:**

  > Bem-vindo ao **Recess Club**, a escola mais divertida do celular!
  >
  > Faça as tarefas da aula, espere o sinal tocar e corra para o recreio com a turma
  > ONLINE: futebol, queimada, pique-pega, esconde-esconde, bolinha de gude,
  > aviãozinho, pular corda, basquete e muito mais. Ande na montanha-russa gigante,
  > desça o tobogã, pule na cama elástica e jogue xadrez, pingue-pongue e jogo da
  > memória na Sala de Jogos.
  >
  > Personalize o seu personagem, faça amigos, complete missões e aprenda brincando:
  > as perguntas se ajustam à idade da criança.
  >
  > Seguro para crianças: sem nome verdadeiro, sem e-mail, chat com filtro e denúncia,
  > anúncios adequados para crianças e sem compras com dinheiro real.
- **Ícone 512×512:** `icon.png` do projeto.
- **Gráfico de recursos 1024×500:** pode pedir que eu gero.
- **Capturas de tela:** mínimo 2 de celular (16:9 deitado). Pode pedir que eu gero do jogo.
- **Categoria:** Jogos → **Educativo** (ou Casual) · Tags: escola, crianças, multijogador.
- **E-mail de contato:** obrigatório. **Site:** `https://escola-production-061f.up.railway.app`
  (o mesmo domínio do `app-ads.txt`).

## 5. AdMob

1. No AdMob → **Apps → Recess Club → Configurações do app**: vincule ao app da
   Google Play quando ele estiver publicado (pode levar alguns dias para aparecer).
2. **app-ads.txt:** o site da página da loja precisa ser o domínio do servidor (passo 4).
   O AdMob verifica sozinho em até 24 h.
3. Em **Configurações de bloqueio**, deixe as categorias sensíveis bloqueadas
   (o app já pede só anúncios "G").
4. Configure em **Privacidade e mensagens** se o AdMob pedir. Como o app é para
   crianças, ele já envia "tratamento infantil" e "menor de idade" em todas as solicitações.

## 6. Atualizações futuras

A cada nova versão, aumente `version/code` (2, 3, 4...) no export e assine com a
**mesma chave de upload**. Eu cuido disso quando você pedir uma nova versão: só me
envie a chave e a senha de novo se for outra sessão.
