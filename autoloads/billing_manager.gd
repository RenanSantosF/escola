extends Node
## Compras pela Google Play (plugin RecessBilling do android_plugin).
## Hoje só o PASSE DO RECREIO (assinatura mensal de R$ 11,99).
## Fora do Android (editor/PC) a compra não existe: em versão de
## desenvolvimento aparece "testar" para conferir os prêmios.

signal premium_changed(active: bool)
signal price_known(text: String)
signal purchase_failed(text: String)

var _api: Object = null
var is_ready := false
var price_text := RecessPass.PRICE_TEXT


func _ready() -> void:
	if Engine.has_singleton("RecessBilling"):
		_api = Engine.get_singleton("RecessBilling")
		_api.connect("billing_ready", _on_ready)
		_api.connect("billing_error", func(code, msg): print("billing: erro ", code, " ", msg))
		_api.connect("product_info", func(_id, price):
			if str(price) != "":
				price_text = str(price)
			price_known.emit(price_text))
		_api.connect("purchase_ok", _on_purchase)
		_api.connect("purchase_failed", func(code, msg):
			if int(code) != 1:  # 1 = a criança/o responsável cancelou
				purchase_failed.emit("Não deu para comprar agora (%s)." % str(msg)))
		_api.connect("purchases_done", func(): pass)
		_api.connect_billing()


func available() -> bool:
	return _api != null and is_ready


## Versão de desenvolvimento fora do celular: botão de teste.
func can_test() -> bool:
	return _api == null and OS.is_debug_build() and not OS.has_feature("android")


func _on_ready() -> void:
	is_ready = true
	_api.query_product(RecessPass.PRODUCT_ID)
	_api.query_purchases()


func buy_pass() -> void:
	if available():
		_api.purchase(RecessPass.PRODUCT_ID)
	elif can_test():
		RecessPass.grant_premium()
		premium_changed.emit(true)
	else:
		purchase_failed.emit("A loja da Play Store não está disponível agora. Tente de novo mais tarde.")


func _on_purchase(id: String, token: String, acknowledged: bool) -> void:
	if id != RecessPass.PRODUCT_ID:
		return
	var d := RecessPass.data()
	var seen: Array = d.get("tokens", [])
	if not token in seen:
		# compra nova: libera o passe por 30 dias
		seen.append(token)
		d["tokens"] = seen
		RecessPass.grant_premium()
		GameManager.show_toast("Passe do Recreio ativado! Pegue seus prêmios na mochila.")
		Telemetry.track("pass_bought", {"season": RecessPass.season_id()})
	elif not RecessPass.is_premium():
		# assinatura renovada (o Google cobrou de novo): mais 30 dias
		RecessPass.grant_premium()
	if not acknowledged:
		_api.acknowledge(token)
	premium_changed.emit(true)
