# Como criar a assinatura do Passe do Recreio (passo a passo)

Você só faz isso **uma vez**. Leva uns 15 minutos.

## Antes de começar
O plugin Android já é compilado sozinho pelo GitHub (aba **Actions** → "Plugin Android").
Quando ele terminar com ✅, gere a versão nova do jogo no Godot como você já faz
(Projeto → Exportar → Android) e envie para a Play Console no **Teste interno**.
> A Play Console só deixa criar assinaturas depois que recebe uma versão do app que
> tem o sistema de compras. Por isso: primeiro envie a versão nova, depois crie a assinatura.

## 1. Abrir a parte de assinaturas
1. Entre em **play.google.com/console** e clique no app **Recess Club**.
2. No menu da esquerda: **Monetizar com o Google Play** → **Produtos** → **Assinaturas**.
3. Se pedir para configurar uma **conta de comerciante (pagamentos)**, siga o que a tela
   pedir (dados bancários para receber o dinheiro). Sem isso o Google não libera vendas.

## 2. Criar a assinatura
1. Clique em **Criar assinatura**.
2. **ID do produto**: digite exatamente `passe_recreio_mensal`
   (tudo minúsculo, com os sublinhados — o jogo procura por esse nome).
3. **Nome**: `Passe do Recreio`.
4. Clique em **Criar**.

## 3. Criar o plano mensal (o preço)
1. Dentro da assinatura, clique em **Adicionar plano básico**.
2. **ID do plano**: `mensal`.
3. **Tipo**: **Renovação automática**. **Período de cobrança**: **1 mês**.
4. Em **Preços**, clique em **Definir preços** → escolha **Brasil** → digite **11,99**.
   (Pode deixar o Google converter o preço para os outros países.)
5. Clique em **Salvar** e depois em **Ativar**.

## 4. Testar sem pagar
1. Menu da esquerda: **Configuração** → **Teste de licença**.
2. Adicione o seu e-mail do Google (o do celular onde vai testar) e salve.
3. No celular com o jogo do Teste interno: Mochila → **Passe do Recreio** → **Comprar**.
   Vai aparecer a tela do Google dizendo que é uma compra de teste (não cobra nada).
4. Depois de comprar, os prêmios da trilha premium ficam liberados para pegar.

## Pronto!
Quando for publicar a versão para todo mundo, a assinatura já estará valendo.

### Se algo der errado
- **"O item que você pediu não está disponível"**: o ID não está igual a
  `passe_recreio_mensal`, o plano não foi ativado, ou o celular está com uma versão
  antiga do jogo (instale a do Teste interno).
- **O botão Comprar não faz nada**: a versão do jogo foi gerada antes do plugin novo.
  Confira se o "Plugin Android" no GitHub terminou com ✅ e exporte o jogo de novo.
