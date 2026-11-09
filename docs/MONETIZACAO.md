# Monetização (preparada, desativada)

A arquitetura está pronta em `autoloads/ads_manager.gd` + `ads_config.cfg`, mas
**desligada** (`enabled=false`). Nada de anúncio aparece até você ativar.

## Princípios (obrigatórios no código)

- Nenhum anúncio é necessário para progredir ou liberar o recreio.
- **Recompensado** é sempre voluntário: hoje existe um ponto de uso, "Dobrar moedas"
  no resumo do fim do dia. O botão **só aparece** se houver um anúncio real carregado
  (`AdsManager.can_show_rewarded()`): não há botões falsos nem recompensas prometidas
  sem anúncio.
- **Intersticial** só na transição de fim de dia, nunca antes do dia 3 e no máximo
  a cada 3 dias (`interstitial_min_days`, `interstitial_every_days`). Nunca durante
  aulas, minijogos ou diálogos.
- Público infantil: `child_directed=true` e `max_ad_content_rating="G"`; não solicite
  anúncios personalizados.

## Como ativar (quando a versão de testes estiver pronta)

1. Instale um plugin AdMob para Godot 4.3 (ex.: *Godot AdMob Plugin* da Poing Studios,
   via AssetLib) e ative a exportação com Gradle (`gradle_build/use_gradle_build=true`).
2. Crie um script provedor que inicializa o SDK com as flags de público infantil e
   implementa:
   ```gdscript
   func is_rewarded_ready() -> bool
   func show_rewarded(unit: String, on_ok: Callable, on_fail: Callable) -> void
   func is_interstitial_ready() -> bool
   func show_interstitial(unit: String) -> void
   ```
   e chame `AdsManager.register_provider(seu_provedor)` depois de carregar o SDK.
   (`tests/mock_ads_provider.gd` mostra a interface usada nos testes.)
3. Teste com as unidades de **teste** do Google (já em `ads_config.cfg` → `[test]`).
4. Crie as unidades reais no AdMob, coloque em `[android]` e só então `enabled=true`.
5. Configure o formulário de **Famílias** e "Contém anúncios" no Play Console.

## Outras fontes

Itens cosméticos opcionais podem ser vendidos com moedas do jogo (já existe a loja);
compras com dinheiro real não estão implementadas.
