extends Node
## Arquitetura de monetização (Google AdMob) — DESATIVADA por padrão.
##
## Regras do projeto (ver docs/MONETIZACAO.md):
## - Nenhum anúncio é obrigatório para progredir ou liberar o recreio.
## - Recompensado é sempre voluntário (ex.: dobrar moedas no fim do dia).
## - Intersticial só em transições calmas (fim do dia), com limite de
##   frequência, nunca durante aulas, minijogos ou nos primeiros dias.
## - Público infantil: conteúdo "G", tratamento child-directed e sem
##   anúncios personalizados (Políticas para Famílias do Google Play).
## - Sem provedor real carregado, nada é exibido (sem botões falsos).

signal rewarded_completed(placement: String)
signal rewarded_failed(placement: String)

const CONFIG_PATH := "res://ads_config.cfg"

var enabled := false
var child_directed := true
var max_rating := "G"
var interstitial_min_days := 3
var interstitial_every_days := 3
var rewarded_unit := ""
var interstitial_unit := ""
## Provedor concreto (objeto com load_rewarded/show_rewarded/...). Plugins
## AdMob se registram aqui via register_provider(); veja a documentação.
var provider: Object = null
var _last_interstitial_day := -99


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		enabled = bool(cfg.get_value("ads", "enabled", false))
		child_directed = bool(cfg.get_value("ads", "child_directed", true))
		max_rating = str(cfg.get_value("ads", "max_ad_content_rating", "G"))
		interstitial_min_days = int(cfg.get_value("ads", "interstitial_min_days", 3))
		interstitial_every_days = int(cfg.get_value("ads", "interstitial_every_days", 3))
		var os_key := "android" if OS.get_name() == "Android" else "test"
		rewarded_unit = str(cfg.get_value(os_key, "rewarded_unit", ""))
		interstitial_unit = str(cfg.get_value(os_key, "interstitial_unit", ""))


## Um plugin de anúncios chama isto depois de inicializar o SDK.
## O provedor deve implementar: is_rewarded_ready(), show_rewarded(unit, cb_ok, cb_fail),
## is_interstitial_ready(), show_interstitial(unit).
func register_provider(p: Object) -> void:
	provider = p


func is_active() -> bool:
	return enabled and provider != null


func can_show_rewarded() -> bool:
	return is_active() and provider.call("is_rewarded_ready")


## Recompensado voluntário. on_reward só é chamado se o anúncio foi visto.
func show_rewarded(placement: String, on_reward: Callable) -> void:
	if not can_show_rewarded():
		rewarded_failed.emit(placement)
		return
	var was_state: int = GameManager.state
	GameManager.set_state(GameManager.State.PAUSED)
	provider.call("show_rewarded", rewarded_unit,
		func():
			GameManager.set_state(was_state)
			on_reward.call()
			rewarded_completed.emit(placement),
		func():
			GameManager.set_state(was_state)
			rewarded_failed.emit(placement))


## Intersticial somente na transição de fim de dia, com limite de frequência.
func maybe_show_interstitial(day_number: int) -> void:
	if not is_active() or day_number < interstitial_min_days:
		return
	if day_number - _last_interstitial_day < interstitial_every_days:
		return
	if provider.call("is_interstitial_ready"):
		_last_interstitial_day = day_number
		provider.call("show_interstitial", interstitial_unit)
