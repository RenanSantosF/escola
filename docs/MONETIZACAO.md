# Monetização (Google AdMob) — ATIVA

- Plugin Android próprio: `android_plugin/` (Java) → `addons/recess_ads/bin/recess_ads.aar`.
  Recompilar: `cd android_plugin && gradle assembleRelease` (JDK 17, ANDROID_HOME, compila com godot-lib 4.7.2).
- Addon do editor `addons/recess_ads` (ativado em project.godot): inclui o AAR, o SDK
  `play-services-ads` e o ID do app no manifesto; remove o ID de publicidade.
  Exige **build Gradle** no export (já ligado).
- `autoloads/ads_manager.gd` + `ads_config.cfg`: unidades reais na versão da loja,
  unidades de TESTE do Google no APK de desenvolvimento.

## Onde aparecem

| Tipo | Onde | Limite |
|---|---|---|
| Intersticial | Fim do dia escolar (resumo do dia) | 1 por dia, nunca no 1º dia de jogo |
| Premiado | Resumo do dia: dobrar moedas do dia | 1 por dia |
| Premiado | Loja (mochila): +40 moedas | 3 por dia |
| Premiado | Fim de brincadeira: XP em dobro | 3 por dia |
| Premiado | Castigo no banco do hall: sair antes dos 3 minutos | 3 por dia |
| Premiado | Loja: itens que também saem com vídeos (`ShopCatalog.AD_ITEMS`, 1 a 5 vídeos) | 10 vídeos por dia |

Botões de vídeo só aparecem quando há vídeo carregado (nada de botão falso) e a
recompensa só é dada se o vídeo foi assistido até o fim.

Público infantil: tratamento infantil (COPPA), menor de idade (LGPD/GDPR) e
classificação **G** em todas as solicitações; sem ID de publicidade.

# Passe do Recreio (assinatura mensal R$ 11,99)

- Código: `scripts/progression/recess_pass.gd` (temporada = mês do calendário, 30 níveis,
  250 XP por nível; todo XP do jogo também conta para o passe), tela na mochila
  (aba **Passe do Recreio**) e `autoloads/billing_manager.gd` (compra).
- Trilha grátis: moedas, pacotes e 2 emojis. Trilha premium: 4 skins exclusivas
  (Dragão Dourado, Robô Neon, Unicórnio Mágico, Capitão Pirata), 7 emojis ANIMADOS,
  6 efeitos (auras) e mais de 1.800 moedas. Itens com `"pass": true` não se compram.
- Emojis animados fora do passe custam 800–1.200 moedas (de propósito: valorizar o passe).

## Configurar na Play Console
Passo a passo bem detalhado: [CRIAR_ASSINATURA_PASSE.md](CRIAR_ASSINATURA_PASSE.md).
O plugin é recompilado automaticamente pelo GitHub Actions (`.github/workflows/android-plugin.yml`).

1. Monetizar > Produtos > **Assinaturas** > criar `passe_recreio_mensal`.
2. Plano base mensal, renovação automática, preço **R$ 11,99** (Brasil).
3. Política de Famílias: compras só com aprovação do responsável (o Google cuida disso
   na conta da criança; o jogo nunca pede dados de pagamento).
4. Recompilar o plugin Android (agora inclui `RecessBilling` e `RecessNotify`):
   `cd android_plugin && gradle assembleRelease` e copiar o AAR para
   `addons/recess_ads/bin/recess_ads.aar`. O addon já adiciona as dependências
   `com.android.billingclient:billing:7.1.1` e `androidx.work:work-runtime:2.9.1`.
5. Testar com uma conta de "testador de licença" (compras de teste não cobram).

Fluxo: `Billing.buy_pass()` → plugin abre a tela do Google → `purchase_ok` →
`RecessPass.grant_premium()` (30 dias) → reconhece a compra (`acknowledge`).
Ao abrir o jogo, `query_purchases` renova o premium se a assinatura continua ativa.
Fora do Android, em versão de desenvolvimento, "Comprar" ativa um passe de TESTE.

# Notificações

- `autoloads/notifier.gd` + plugin `RecessNotify` (Java): pede a permissão (Android 13+),
  agenda lembretes quando o jogo vai para segundo plano (22 h, 3 dias e "prêmio do
  passe esperando") e cancela quando a criança volta.
- Amigo online: com o jogo ABERTO o servidor manda `friend_online` (aviso na tela);
  com o jogo FECHADO, um trabalho do Android (WorkManager, ~15 min) consulta
  `GET /api/friends/online` com o token da conta e notifica "fulano está jogando agora!".
- Dá para desligar em Configurações > "Notificações".
