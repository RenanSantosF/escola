class_name Stickers
extends RefCounted
## Álbum de figurinhas "Craques do Recreio" (coleção salva no save).

const ALBUM := [
	{"id": "f01", "name": "Goleiro Voador", "rare": false}, {"id": "f02", "name": "Artilheira da Quadra", "rare": false},
	{"id": "f03", "name": "Rei da Queimada", "rare": false}, {"id": "f04", "name": "Mestre da Gude", "rare": false},
	{"id": "f05", "name": "Piloto de Papel", "rare": false}, {"id": "f06", "name": "Campeã da Corda", "rare": false},
	{"id": "f07", "name": "Velocista do Pátio", "rare": false}, {"id": "f08", "name": "Tia da Cantina", "rare": false},
	{"id": "f09", "name": "Diretor Bravo", "rare": false}, {"id": "f10", "name": "Inspetora Atenta", "rare": false},
	{"id": "f11", "name": "Professora Sorridente", "rare": false}, {"id": "f12", "name": "Coxinha Dourada", "rare": false},
	{"id": "f13", "name": "Sinal do Recreio", "rare": false}, {"id": "f14", "name": "Ipê Amarelo", "rare": false},
	{"id": "f15", "name": "Bola de Capotão", "rare": false}, {"id": "f16", "name": "Mochila Lendária", "rare": false},
	{"id": "f17", "name": "Lousa Mágica", "rare": false}, {"id": "f18", "name": "Aviãozinho Supersônico", "rare": false},
	{"id": "f19", "name": "Amarelinha Infinita", "rare": false}, {"id": "f20", "name": "Gangorra Maluca", "rare": false},
	{"id": "r01", "name": "Taça do Torneio (brilhante)", "rare": true}, {"id": "r02", "name": "Gude Galáxia (brilhante)", "rare": true},
	{"id": "r03", "name": "Mascote da Escola (brilhante)", "rare": true}, {"id": "r04", "name": "Recreio Eterno (brilhante)", "rare": true},
]


static func owned() -> Dictionary:
	var col: Dictionary = SaveManager.section("collections")
	if not col.has("figurinhas"):
		col["figurinhas"] = {}
	return col.figurinhas


static func count_unique() -> int:
	return owned().size()


static func entry(id: String) -> Dictionary:
	for e in ALBUM:
		if e.id == id:
			return e
	return {}


## Dá uma figurinha (rara ou comum) e retorna o registro.
static func give_random(rare := false) -> Dictionary:
	var pool := ALBUM.filter(func(e): return e.rare == rare)
	var e: Dictionary = pool.pick_random()
	give(e.id)
	return e


static func give(id: String) -> void:
	var o := owned()
	var e := entry(id)
	var is_new := not o.has(id)
	o[id] = int(o.get(id, 0)) + 1
	GameManager.show_toast(("Nova figurinha: %s!" if is_new else "Figurinha repetida: %s") % e.get("name", id))
	if count_unique() >= ALBUM.size():
		GameManager.unlock_achievement("album_completo")


## Pacote com 4 figurinhas (raras com 10% de chance cada).
static func open_pack() -> Array:
	var got := []
	for i in 4:
		got.append(give_random(randf() < 0.1))
	return got
