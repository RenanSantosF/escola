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

Botões de vídeo só aparecem quando há vídeo carregado (nada de botão falso) e a
recompensa só é dada se o vídeo foi assistido até o fim.

Público infantil: tratamento infantil (COPPA), menor de idade (LGPD/GDPR) e
classificação **G** em todas as solicitações; sem ID de publicidade.
