class_name ShopCatalog
extends RefCounted
## Catálogo da loja. "look" = campos da CharacterAppearance aplicados ao equipar.
## Itens "consumable" não ficam no inventário (pacotes de figurinha/gude).

const CATEGORIES := [
	["camiseta", "Camisetas"], ["calca", "Calças"], ["calcado", "Tênis"], ["mochila", "Mochilas"],
	["bone", "Bonés"], ["penteado", "Penteados"], ["acessorio", "Acessórios"], ["decoracao", "Decoração"],
	["gude", "Bolinhas de gude"], ["figurinha", "Figurinhas"], ["veiculo", "Skate e bike"],
]

const ITEMS := [
	# camisetas
	{"id": "cam_uniforme", "cat": "camiseta", "name": "Uniforme da escola", "price": 0, "lvl": 1, "look": {"shirt_color": "f4f4f0", "shirt_trim": "2f6fd0", "shirt_logo": true}},
	{"id": "cam_uniforme_v", "cat": "camiseta", "name": "Uniforme gola vermelha", "price": 40, "lvl": 1, "look": {"shirt_color": "f4f4f0", "shirt_trim": "d63c3c", "shirt_logo": true}},
	{"id": "cam_amarela", "cat": "camiseta", "name": "Camiseta amarela", "price": 60, "lvl": 2, "look": {"shirt_color": "f2b632", "shirt_trim": "c98f12", "shirt_logo": false}},
	{"id": "cam_verde", "cat": "camiseta", "name": "Camiseta verde", "price": 60, "lvl": 2, "look": {"shirt_color": "3aa45b", "shirt_trim": "2a7a43", "shirt_logo": false}},
	{"id": "cam_roxa", "cat": "camiseta", "name": "Camiseta roxa", "price": 80, "lvl": 3, "look": {"shirt_color": "8e5bd1", "shirt_trim": "6a3fa8", "shirt_logo": false}},
	{"id": "cam_laranja", "cat": "camiseta", "name": "Camiseta laranja", "price": 80, "lvl": 3, "look": {"shirt_color": "ff8a3d", "shirt_trim": "d96a20", "shirt_logo": false}},
	{"id": "cam_time", "cat": "camiseta", "name": "Camisa do time", "price": 150, "lvl": 5, "look": {"shirt_color": "2f6fd0", "shirt_trim": "f2c230", "shirt_logo": true}},
	# calças
	{"id": "cal_bermuda", "cat": "calca", "name": "Bermuda azul-marinho", "price": 0, "lvl": 1, "look": {"pants_color": "23325c", "long_pants": false}},
	{"id": "cal_jeans", "cat": "calca", "name": "Calça jeans", "price": 70, "lvl": 1, "look": {"pants_color": "3f5f99", "long_pants": true}},
	{"id": "cal_preta", "cat": "calca", "name": "Bermuda preta", "price": 50, "lvl": 2, "look": {"pants_color": "2b2b2b", "long_pants": false}},
	{"id": "cal_marrom", "cat": "calca", "name": "Calça marrom", "price": 90, "lvl": 3, "look": {"pants_color": "6b4f2b", "long_pants": true}},
	{"id": "cal_verde", "cat": "calca", "name": "Calça verde", "price": 110, "lvl": 4, "look": {"pants_color": "2d5a3b", "long_pants": true}},
	# tênis
	{"id": "ten_branco", "cat": "calcado", "name": "Tênis branco", "price": 0, "lvl": 1, "look": {"shoe_color": "f2f2f2"}},
	{"id": "ten_preto", "cat": "calcado", "name": "Tênis preto", "price": 45, "lvl": 1, "look": {"shoe_color": "1f1f1f"}},
	{"id": "ten_vermelho", "cat": "calcado", "name": "Tênis vermelho", "price": 70, "lvl": 2, "look": {"shoe_color": "d63c3c"}},
	{"id": "ten_azul", "cat": "calcado", "name": "Tênis azul", "price": 70, "lvl": 2, "look": {"shoe_color": "2f6fd0"}},
	{"id": "ten_amarelo", "cat": "calcado", "name": "Tênis amarelo-ouro", "price": 160, "lvl": 5, "look": {"shoe_color": "f2c230"}},
	# mochilas
	{"id": "moc_vermelha", "cat": "mochila", "name": "Mochila vermelha", "price": 0, "lvl": 1, "look": {"backpack": true, "backpack_color": "d63c3c"}},
	{"id": "moc_azul", "cat": "mochila", "name": "Mochila azul", "price": 50, "lvl": 1, "look": {"backpack": true, "backpack_color": "2f6fd0"}},
	{"id": "moc_amarela", "cat": "mochila", "name": "Mochila amarela", "price": 60, "lvl": 2, "look": {"backpack": true, "backpack_color": "f2c230"}},
	{"id": "moc_rosa", "cat": "mochila", "name": "Mochila rosa", "price": 60, "lvl": 2, "look": {"backpack": true, "backpack_color": "ff7eb6"}},
	{"id": "moc_roxa", "cat": "mochila", "name": "Mochila roxa galáxia", "price": 140, "lvl": 4, "look": {"backpack": true, "backpack_color": "5b3fa0"}},
	{"id": "moc_nenhuma", "cat": "mochila", "name": "Sem mochila", "price": 0, "lvl": 1, "look": {"backpack": false}},
	# bonés
	{"id": "bon_nenhum", "cat": "bone", "name": "Sem boné", "price": 0, "lvl": 1, "look": {"cap": false}},
	{"id": "bon_azul", "cat": "bone", "name": "Boné azul", "price": 55, "lvl": 1, "look": {"cap": true, "cap_color": "2f6fd0"}},
	{"id": "bon_vermelho", "cat": "bone", "name": "Boné vermelho", "price": 55, "lvl": 2, "look": {"cap": true, "cap_color": "e04a3a"}},
	{"id": "bon_verde", "cat": "bone", "name": "Boné verde", "price": 75, "lvl": 3, "look": {"cap": true, "cap_color": "3aa45b"}},
	{"id": "bon_dourado", "cat": "bone", "name": "Boné dourado", "price": 200, "lvl": 6, "look": {"cap": true, "cap_color": "e8b923"}},
	# penteados
	{"id": "pen_curto", "cat": "penteado", "name": "Cabelo curto", "price": 0, "lvl": 1, "look": {"hair_style": "curto"}},
	{"id": "pen_espetado", "cat": "penteado", "name": "Espetado", "price": 40, "lvl": 1, "look": {"hair_style": "espetado"}},
	{"id": "pen_franja", "cat": "penteado", "name": "Franja", "price": 40, "lvl": 1, "look": {"hair_style": "franja"}},
	{"id": "pen_raspado", "cat": "penteado", "name": "Raspado", "price": 30, "lvl": 1, "look": {"hair_style": "raspado"}},
	{"id": "pen_longo", "cat": "penteado", "name": "Longo", "price": 60, "lvl": 2, "look": {"hair_style": "longo"}},
	{"id": "pen_rabo", "cat": "penteado", "name": "Rabo de cavalo", "price": 60, "lvl": 2, "look": {"hair_style": "rabo"}},
	{"id": "pen_cacheado", "cat": "penteado", "name": "Cacheado", "price": 70, "lvl": 2, "look": {"hair_style": "cacheado"}},
	{"id": "pen_black", "cat": "penteado", "name": "Black power", "price": 90, "lvl": 3, "look": {"hair_style": "black_power"}},
	{"id": "tin_castanho", "cat": "penteado", "name": "Cor: castanho", "price": 0, "lvl": 1, "look": {"hair_color": "3b2417"}},
	{"id": "tin_preto", "cat": "penteado", "name": "Cor: preto", "price": 25, "lvl": 1, "look": {"hair_color": "1d1612"}},
	{"id": "tin_loiro", "cat": "penteado", "name": "Cor: loiro", "price": 50, "lvl": 2, "look": {"hair_color": "d9b25f"}},
	{"id": "tin_ruivo", "cat": "penteado", "name": "Cor: ruivo", "price": 50, "lvl": 2, "look": {"hair_color": "a32e1d"}},
	{"id": "tin_azul", "cat": "penteado", "name": "Cor: azul (ousado!)", "price": 180, "lvl": 6, "look": {"hair_color": "2f6fd0"}},
	# acessórios
	{"id": "ace_sem_oculos", "cat": "acessorio", "name": "Sem óculos", "price": 0, "lvl": 1, "look": {"glasses": false}},
	{"id": "ace_oculos", "cat": "acessorio", "name": "Óculos de grau", "price": 65, "lvl": 1, "look": {"glasses": true}},
	# decoração da carteira (aparece na sua carteira da Sala 5)
	{"id": "dec_estojo", "cat": "decoracao", "name": "Estojo colorido", "price": 35, "lvl": 1, "decor": "estojo"},
	{"id": "dec_planta", "cat": "decoracao", "name": "Plantinha na carteira", "price": 60, "lvl": 2, "decor": "planta"},
	{"id": "dec_caneca", "cat": "decoracao", "name": "Caneca de lápis", "price": 45, "lvl": 2, "decor": "caneca"},
	{"id": "dec_globo", "cat": "decoracao", "name": "Mini globo", "price": 120, "lvl": 4, "decor": "globo"},
	{"id": "dec_trofeu", "cat": "decoracao", "name": "Mini troféu", "price": 220, "lvl": 6, "decor": "trofeu"},
	# veículos (caros: exigem dias de jogo)
	{"id": "vei_skate", "cat": "veiculo", "name": "Skate", "price": 900, "lvl": 4, "vehicle": "skate"},
	{"id": "vei_patinete", "cat": "veiculo", "name": "Patinete", "price": 1300, "lvl": 5, "vehicle": "patinete"},
	{"id": "vei_bike", "cat": "veiculo", "name": "Bicicleta", "price": 2000, "lvl": 6, "vehicle": "bike"},
	# consumíveis
	{"id": "gude_saco", "cat": "gude", "name": "Saquinho com 3 bolinhas", "price": 30, "lvl": 1, "consumable": true},
	{"id": "fig_pacote", "cat": "figurinha", "name": "Pacote com 4 figurinhas", "price": 25, "lvl": 1, "consumable": true},
]

const DEFAULT_OWNED := ["cam_uniforme", "cal_bermuda", "ten_branco", "moc_vermelha", "moc_nenhuma", "bon_nenhum",
	"pen_curto", "tin_castanho", "ace_sem_oculos"]


static func by_cat(cat: String) -> Array:
	return ITEMS.filter(func(i): return i.cat == cat)


static func get_item(id: String) -> Dictionary:
	for i in ITEMS:
		if i.id == id:
			return i
	return {}


## Cor representativa para o cartão da loja.
static func swatch(item: Dictionary) -> Color:
	var look: Dictionary = item.get("look", {})
	for k in ["shirt_color", "pants_color", "shoe_color", "backpack_color", "cap_color", "hair_color"]:
		if look.has(k):
			return Color(look[k])
	match item.cat:
		"decoracao": return Color("a0663a")
		"gude": return Color("3fa7d6")
		"figurinha": return Color("f2b632")
		"veiculo": return Color("e74c3c")
		"penteado": return Color("3b2417")
		"acessorio": return Color("1c1c1c")
	return Color("cccccc")
