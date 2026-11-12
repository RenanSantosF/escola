extends Node
## Anúncios (Google AdMob) do Recess Club.
##
## Regras (público infantil, Políticas para Famílias do Google Play):
## - Nada de anúncio para progredir: premiado é sempre opcional e o botão só
##   aparece quando existe um vídeo carregado de verdade.
## - Intersticial: no máximo UM por dia, só na transição de fim de dia (nunca
##   na abertura do jogo, em aula, brincadeira ou conversa), e não no 1º dia.
## - Sempre tratamento infantil, menor de idade e conteúdo "G"; sem ID de
##   publicidade (removido do manifesto pelo addon recess_ads).
## - APK de teste (debug) usa as unidades de TESTE do Google; a versão da loja
##   (release) usa as unidades reais do ads_config.cfg.

signal rewarded_completed(placement: String)
signal rewarded_failed(placement: String)
signal availability_changed  ## um vídeo ficou pronto (ou acabou): a tela pode mostrar/esconder botões

const CONFIG_PATH := "res://ads_config.cfg"
## Prêmios em vídeo: quantas vezes por dia cada um pode ser usado.
const PLACEMENTS := {
	"dobrar_dia": {"per_day": 1, "title": "Dobrar as moedas do dia"},
	"moedas_extra": {"per_day": 3, "title": "Ganhar moedas", "coins": 40},
	"xp_brincadeira": {"per_day": 3, "title": "XP em dobro na brincadeira"},
}

var enabled := false
var child_directed := true
var max_rating := "G"
var rewarded_unit := ""
var interstitial_unit := ""
## Provedor concreto: AdMobProvider (celular) ou um falso nos testes.
## Interface: is_rewarded_ready(), show_rewarded(unit, ok, fail),
## is_interstitial_ready(), show_interstitial(unit).
var provider: Object = null
var _last_interstitial_day := -99  # compatibilidade com testes antigos


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		enabled = bool(cfg.get_value("ads", "enabled", false))
		child_directed = bool(cfg.get_value("ads", "child_directed", true))
		max_rating = str(cfg.get_value("ads", "max_ad_content_rating", "G"))
		# teste no APK de desenvolvimento; reais só na versão da loja
		var key := "android" if OS.get_name() == "Android" and not OS.is_debug_build() else "test"
		rewarded_unit = str(cfg.get_value(key, "rewarded_unit", ""))
		interstitial_unit = str(cfg.get_value(key, "interstitial_unit", ""))
	if enabled and Engine.has_singleton("RecessAds"):
		var p := AdMobProvider.new(Engine.get_singleton("RecessAds"), self)
		register_provider(p)
		p.start()


func register_provider(p: Object) -> void:
	provider = p


func is_active() -> bool:
	return enabled and provider != null


func can_show_rewarded() -> bool:
	return is_active() and bool(provider.call("is_rewarded_ready"))


# ------------------------------------------------------------ limites diários

func _today() -> String:
	return Time.get_date_string_from_system()


func _ads_save() -> Dictionary:
	var s: Dictionary = SaveManager.section("ads")
	if str(s.get("date", "")) != _today():
		s["date"] = _today()
		s["counts"] = {}
	if not s.has("first_day"):
		s["first_day"] = _today()
	return s


func uses_left(placement: String) -> int:
	var per := int(PLACEMENTS.get(placement, {}).get("per_day", 1))
	return maxi(per - int((_ads_save().counts as Dictionary).get(placement, 0)), 0)


## Pode oferecer este prêmio agora? (vídeo pronto e ainda tem vezes hoje)
func can_offer(placement: String) -> bool:
	return can_show_rewarded() and uses_left(placement) > 0


## Premiado voluntário. on_reward só é chamado se a criança viu o vídeo até o fim.
func show_rewarded(placement: String, on_reward: Callable) -> void:
	if not can_show_rewarded() or (PLACEMENTS.has(placement) and uses_left(placement) <= 0):
		rewarded_failed.emit(placement)
		return
	var was_state: int = GameManager.state
	GameManager.set_state(GameManager.State.PAUSED)
	AudioServer.set_bus_mute(0, true)
	provider.call("show_rewarded", rewarded_unit,
		func():
			AudioServer.set_bus_mute(0, false)
			GameManager.set_state(was_state)
			var s := _ads_save()
			(s.counts as Dictionary)[placement] = int((s.counts as Dictionary).get(placement, 0)) + 1
			on_reward.call()
			Telemetry.track("ad_reward", {"placement": placement})
			rewarded_completed.emit(placement)
			availability_changed.emit(),
		func():
			AudioServer.set_bus_mute(0, false)
			GameManager.set_state(was_state)
			rewarded_failed.emit(placement)
			availability_changed.emit())


## Prêmio "moedas extras" da loja (vídeo -> +40 moedas).
func reward_coins() -> int:
	return int(PLACEMENTS.moedas_extra.coins)


## Intersticial do dia: no máximo um por dia, no fim do dia escolar.
func maybe_show_interstitial(_day_number := 0) -> bool:
	if not is_active():
		return false
	var s := _ads_save()
	if str(s.get("first_day", "")) == _today():
		return false  # primeiro dia jogando: sem anúncio
	if str(s.get("interstitial_date", "")) == _today():
		return false
	if not bool(provider.call("is_interstitial_ready")):
		return false
	s["interstitial_date"] = _today()
	AudioServer.set_bus_mute(0, true)
	provider.call("show_interstitial", interstitial_unit)
	get_tree().create_timer(0.5).timeout.connect(func(): AudioServer.set_bus_mute(0, false))
	Telemetry.track("ad_interstitial", {})
	return true


# ====================================================================== AdMob

## Fala com o plugin Android (addons/recess_ads/bin/recess_ads.aar).
class AdMobProvider extends RefCounted:
	var api: Object
	var mgr: Node
	var _ok: Callable
	var _fail: Callable
	var _retry_r := 5.0
	var _retry_i := 5.0

	func _init(singleton: Object, manager: Node) -> void:
		api = singleton
		mgr = manager

	func start() -> void:
		api.connect("initialized", func(): _on_main(func():
			_load_r()
			_load_i()))
		api.connect("rewarded_loaded", func(): _on_main(func():
			_retry_r = 5.0
			mgr.availability_changed.emit()))
		api.connect("rewarded_failed_to_load", func(_e): _on_main(func(): _later(true)))
		api.connect("rewarded_closed", func(earned): _on_main(func():
			if earned and _ok.is_valid():
				_ok.call()
			elif _fail.is_valid():
				_fail.call()
			_ok = Callable()
			_fail = Callable()
			_load_r()))
		api.connect("interstitial_loaded", func(): _on_main(func(): _retry_i = 5.0))
		api.connect("interstitial_failed_to_load", func(_e): _on_main(func(): _later(false)))
		api.connect("interstitial_closed", func(): _on_main(func(): _load_i()))
		api.connect("show_failed", func(kind, _e): _on_main(func():
			if kind == "rewarded":
				if _fail.is_valid():
					_fail.call()
				_ok = Callable()
				_fail = Callable()
				_load_r()
			else:
				_load_i()))
		api.call("init_ads", mgr.child_directed, mgr.max_rating)

	## Os sinais do Java chegam fora do laço principal: executa no próximo quadro.
	func _on_main(f: Callable) -> void:
		f.call_deferred()

	func _load_r() -> void:
		if mgr.rewarded_unit != "":
			api.call("load_rewarded", mgr.rewarded_unit)

	func _load_i() -> void:
		if mgr.interstitial_unit != "":
			api.call("load_interstitial", mgr.interstitial_unit)

	## Falhou ao carregar (sem internet, sem anúncio): tenta de novo mais tarde.
	func _later(rewarded: bool) -> void:
		var wait := _retry_r if rewarded else _retry_i
		if rewarded:
			_retry_r = minf(_retry_r * 2.0, 300.0)
		else:
			_retry_i = minf(_retry_i * 2.0, 300.0)
		mgr.get_tree().create_timer(wait).timeout.connect(_load_r if rewarded else _load_i)

	func is_rewarded_ready() -> bool:
		return bool(api.call("is_rewarded_ready"))

	func show_rewarded(_unit: String, ok: Callable, fail: Callable) -> void:
		_ok = ok
		_fail = fail
		api.call("show_rewarded")

	func is_interstitial_ready() -> bool:
		return bool(api.call("is_interstitial_ready"))

	func show_interstitial(_unit: String) -> void:
		api.call("show_interstitial")
