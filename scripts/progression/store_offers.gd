class_name StoreOffers
extends RefCounted
## Ofertas com DINHEIRO DE VERDADE (Google Play) e a troca de diamantes.
## Os preços mostrados vêm da Play Store (moeda local); estes são os do Brasil.
## Público infantil: a compra sempre passa pela tela do Google (com a senha /
## aprovação do responsável) e o jogo mostra o aviso "peça para um adulto".

## Pacotes de diamantes (consumíveis).
const DIAMONDS := [
	{"id": "diamantes_60", "diamonds": 60, "bonus": 0, "price": "R$ 4,99", "tag": ""},
	{"id": "diamantes_150", "diamonds": 150, "bonus": 15, "price": "R$ 9,99", "tag": "+10% BÔNUS"},
	{"id": "diamantes_400", "diamonds": 400, "bonus": 60, "price": "R$ 24,99", "tag": "MAIS VENDIDO"},
	{"id": "diamantes_900", "diamonds": 900, "bonus": 200, "price": "R$ 49,99", "tag": "MELHOR VALOR"},
]
## Pacotes de moedas (consumíveis).
const COINS := [
	{"id": "moedas_2000", "coins": 2000, "price": "R$ 4,99", "tag": ""},
	{"id": "moedas_5000", "coins": 5000, "price": "R$ 9,99", "tag": "+25%"},
	{"id": "moedas_15000", "coins": 15000, "price": "R$ 24,99", "tag": "MELHOR VALOR"},
]
## Pacote de boas-vindas: só UMA vez por conta.
const STARTER := {"id": "pacote_inicial", "diamonds": 150, "coins": 3000, "item": "skin_cavaleiro", "price": "R$ 7,99"}
## Troca dentro do jogo: diamantes -> moedas.
const EXCHANGE := [[10, 600], [50, 3300], [120, 8500]]


static func all_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for d in DIAMONDS:
		out.append(d.id)
	for c in COINS:
		out.append(c.id)
	out.append(STARTER.id)
	return out


static func find(id: String) -> Dictionary:
	for d in DIAMONDS + COINS:
		if d.id == id:
			return d
	return STARTER if id == STARTER.id else {}


static func starter_bought() -> bool:
	return bool(SaveManager.section("player").get("starter_bought", false))


## Entrega o que foi comprado. Retorna o texto do que ganhou.
static func deliver(id: String) -> String:
	var o := find(id)
	if o.is_empty():
		return ""
	var parts := []
	var dia := int(o.get("diamonds", 0)) + int(o.get("bonus", 0))
	if dia > 0:
		GameManager.add_diamonds(dia, false)  # grava tudo de uma vez no fim (compra + prêmios)
		parts.append("%d diamantes" % dia)
	if int(o.get("coins", 0)) > 0:
		GameManager.add_rewards(0, int(o.coins))
		parts.append("%d moedas" % int(o.coins))
	if o.has("item"):
		var inv: Dictionary = SaveManager.section("inventory")
		if not str(o.item) in inv.get("owned", []):
			(inv["owned"] as Array).append(str(o.item))
		parts.append(str(ShopCatalog.get_item(str(o.item)).get("name", o.item)))
	if id == STARTER.id:
		SaveManager.section("player")["starter_bought"] = true
	SaveManager.save_game()
	Telemetry.track("iap", {"product": id})
	return ", ".join(parts)


## Troca diamantes por moedas (dentro do jogo).
static func exchange(i: int) -> bool:
	var e: Array = EXCHANGE[i]
	if not GameManager.spend_diamonds(int(e[0])):
		return false
	GameManager.add_rewards(0, int(e[1]))
	SaveManager.save_game()  # grava as moedas junto (os diamantes já foram descontados)
	return true
