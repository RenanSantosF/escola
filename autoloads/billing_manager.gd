extends Node
## Compras pela Google Play (plugin RecessBilling do android_plugin).
## Hoje só o PASSE DO RECREIO (assinatura mensal de R$ 11,99).
## Fora do Android (editor/PC) a compra não existe: em versão de
## desenvolvimento aparece "testar" para conferir os prêmios.

signal premium_changed(active: bool)
signal price_known(text: String)
signal purchase_failed(text: String)
## Diamantes/moedas entregues (texto do que ganhou).
signal delivered(text: String)

var _api: Object = null
var is_ready := false
var price_text := RecessPass.PRICE_TEXT
## Preços da Play Store (moeda local) por produto.
var prices := {}


func _ready() -> void:
	if Engine.has_singleton("RecessBilling"):
		_api = Engine.get_singleton("RecessBilling")
		_api.connect("billing_ready", _on_ready)
		_api.connect("billing_error", func(code, msg): print("billing: erro ", code, " ", msg))
		_api.connect("product_info", func(id, price):
			if str(price) == "":
				return
			prices[str(id)] = str(price)
			if str(id) == RecessPass.PRODUCT_ID:
				price_text = str(price)
			price_known.emit(str(price)))
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
	if _api.has_method("query_inapp"):
		_api.query_inapp(",".join(StoreOffers.all_ids()))
		_api.query_inapp_purchases()


func buy_pass() -> void:
	if available():
		_api.purchase(RecessPass.PRODUCT_ID)
	elif can_test():
		RecessPass.grant_premium()
		premium_changed.emit(true)
	else:
		purchase_failed.emit("A loja da Play Store não está disponível agora. Tente de novo mais tarde.")


## Preço para mostrar: o da Play Store, ou o do Brasil (catálogo).
func price_of(id: String) -> String:
	if prices.has(id):
		return prices[id]
	return str(StoreOffers.find(id).get("price", ""))


## Compra de diamantes/moedas/pacote inicial.
func buy(id: String) -> void:
	if id == StoreOffers.STARTER.id and StoreOffers.starter_bought():
		purchase_failed.emit("Você já tem o Pacote de Boas-vindas!")
		return
	if available() and _api.has_method("purchase_inapp"):
		_api.purchase_inapp(id)
	elif can_test():
		var got := StoreOffers.deliver(id)
		delivered.emit(got)
	else:
		purchase_failed.emit("A loja da Play Store não está disponível agora. Tente de novo mais tarde.")


func _on_purchase(id: String, token: String, acknowledged: bool) -> void:
	if id != RecessPass.PRODUCT_ID:
		if StoreOffers.find(id).is_empty():
			return
		var pl: Dictionary = SaveManager.section("player")
		var done: Array = pl.get("iap_tokens", [])
		if not token in done:
			done.append(token)
			while done.size() > 200:
				done.pop_front()
			pl["iap_tokens"] = done
			var got := StoreOffers.deliver(id)
			GameManager.show_toast("Compra feita! Você ganhou: %s" % got)
			delivered.emit(got)
		# só consome depois que o prêmio ficou gravado (se não gravar, a Play Store
		# devolve a compra na próxima abertura e o jogo entrega de novo)
		if not SaveManager.save_game():
			return
		# o pacote inicial não se consome (fica marcado como comprado)
		if id != StoreOffers.STARTER.id:
			_api.consume(token)
		elif not acknowledged:
			_api.acknowledge(token)
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
