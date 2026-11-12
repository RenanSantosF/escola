# Preparação para a Google Play

## Checklist técnico

- [x] Orientação paisagem (`display/window/handheld/orientation=4`, sensor landscape)
- [x] Renderer Mobile com fallback automático para OpenGL ES 3
- [x] Ícones: `assets/icons/icon_192.png` e adaptativos 432 px (frente/fundo)
- [x] Pacote `com.recreio.minhavidanaescola`, versão 0.1.0 (code 1)
- [x] arm64-v8a + armeabi-v7a; nenhuma permissão perigosa. Usa INTERNET (permissão
      normal) só para o modo online opcional — declarar na Segurança dos dados.
- [x] Save local; nada é enviado para servidores
- [ ] Exportar **AAB** (`gradle_build/export_format=1`, requer Gradle build) com
      keystore de release
- [ ] Testar em pelo menos 1 aparelho de entrada (2–3 GB RAM) e 1 intermediário
- [ ] Capturas de tela (paisagem) e vídeo curto para a página da loja

## Classificação e público

- Público-alvo: 6–12 anos e todas as idades → programa **Famílias** do Google Play.
- Conteúdo: humor leve, sem violência (a "queimada" usa bolas macias, sem dano;
  quem é atingido apenas sai por alguns segundos), sem compras com dinheiro real,
  sem chat, sem coleta de dados pessoais.
- Questionário IARC: esperado **Livre (L)**.

## Rascunho da descrição

**Recess Club — Minha Vida na Escola**

Volte aos melhores momentos da escola! Faça as tarefas rapidinho, espere o sinal
tocar e corra para o recreio: futebol na quadra, queimada, bolinha de gude,
aviãozinho de papel, pular corda, corrida no pátio e guerra de bolinhas de papel.
Faça amigos, ajude os colegas, complete o álbum de figurinhas, personalize seu
personagem e... cuidado com o diretor!

## Rascunho de política de privacidade

> O jogo "Recess Club — Minha Vida na Escola" não coleta, armazena em servidores nem
> compartilha dados pessoais. O progresso fica salvo somente no próprio aparelho.
> O jogo não possui chat nem contas de usuário. Caso anúncios sejam ativados em
> versões futuras, eles seguirão as Políticas para Famílias do Google Play
> (anúncios não personalizados e adequados para crianças) e esta política será
> atualizada antes da publicação. Contato: [seu e-mail de desenvolvedor].

Publique esse texto numa página pública (ex.: GitHub Pages) e informe o link no Play Console.
