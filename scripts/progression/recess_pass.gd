class_name RecessPass
extends RefCounted
## PASSE DO RECREIO (mensal, R$ 11,99). Cada mês é uma temporada nova com
## 30 níveis: jogando (aulas, brincadeiras, missões) você ganha XP do passe
## e libera prêmios. Trilha GRÁTIS para todos; trilha PREMIUM para quem
## comprou o passe: skins exclusivas, emojis animados, efeitos (auras) e
## muitas moedas. Os emojis animados custam bem caro fora do passe.

const PRODUCT_ID := "passe_recreio_mensal"
const PRICE_TEXT := "R$ 11,99"
const TIERS := 30
const TIER_XP := 250
const DAYS := 30

## Prêmio: {"coins": n} | {"item": id} | {"packs": {"figurinha": n, "gude": n}}
## Trilha GRÁTIS: poucos prêmios (o kart com design só no último nível).
const FREE := {
	3: {"coins": 20}, 6: {"packs": {"figurinha": 1}}, 10: {"item": "emo_clap"}, 14: {"coins": 30},
	18: {"packs": {"gude": 1}}, 22: {"coins": 40}, 26: {"diamonds": 5}, 30: {"item": "kart_esportivo"},
}
## Trilha premium: um prêmio em TODO nível — já começa com um kart com design
## (aerofólio gigante e carburadores) e os melhores ficam no fim.
const PREMIUM := {
	1: {"item": "kart_turbo"}, 2: {"item": "emo_floss"}, 3: {"diamonds": 20}, 4: {"item": "skin_pirata"},
	5: {"item": "emo_dance"}, 6: {"coins": 150}, 7: {"item": "aura_fogo"}, 8: {"diamonds": 25},
	9: {"item": "kart_neon"}, 10: {"item": "skin_dragao"}, 11: {"item": "emo_laugh"}, 12: {"coins": 200},
	13: {"item": "emo_flex"}, 14: {"item": "aura_coracoes"}, 15: {"item": "emo_heart"}, 16: {"item": "kart_foguete"},
	17: {"item": "skin_neon"}, 18: {"item": "aura_raio"}, 19: {"item": "emo_guitar"}, 20: {"item": "aura_arco"},
	21: {"item": "emo_robot"}, 22: {"item": "aura_estrelas"}, 23: {"item": "kart_arco"}, 24: {"item": "emo_spin"},
	25: {"diamonds": 50}, 26: {"item": "aura_neve"}, 27: {"item": "emo_backflip"}, 28: {"coins": 400},
	29: {"item": "kart_campeao"}, 30: {"item": "skin_unicornio"},
}

## DESAFIOS DA SEMANA: 6 por semana (iguais para todos), cada um dá XP do passe.
## key "mg_x" = partidas jogadas de x; "mgw_x" = partidas vencidas; o resto = estatística.
const CHALLENGE_POOL := [
	{"key": "mg_kart", "target": 3, "desc": "Corra %d vezes no kart", "xp": 400},
	{"key": "mgw_kart", "target": 1, "desc": "Ganhe %d corrida de kart", "xp": 500},
	{"key": "mg_pipa", "target": 2, "desc": "Solte pipa %d vezes no Morro", "xp": 300},
	{"key": "montanha_russa", "target": 2, "desc": "Ande %d vezes na montanha-russa", "xp": 300},
	{"key": "acertos", "target": 15, "desc": "Acerte %d tarefas nas aulas", "xp": 450},
	{"key": "mg_futebol", "target": 2, "desc": "Jogue %d partidas de futebol", "xp": 350},
	{"key": "mg_queimada", "target": 2, "desc": "Jogue %d partidas de queimada", "xp": 350},
	{"key": "mg_esconde", "target": 2, "desc": "Brinque %d vezes de esconde-esconde", "xp": 300},
	{"key": "escorregadas", "target": 3, "desc": "Desça %d vezes o tobogã gigante", "xp": 250},
	{"key": "jogos_mesa", "target": 3, "desc": "Jogue %d vezes nas mesas (xadrez, pingue-pongue...)", "xp": 300},
	{"key": "vitorias", "target": 5, "desc": "Vença %d brincadeiras", "xp": 450},
	{"key": "missoes", "target": 2, "desc": "Ajude %d colegas (missões)", "xp": 400},
	{"key": "mg_basquete", "target": 2, "desc": "Jogue basquete %d vezes", "xp": 250},
	{"key": "mg_gude", "target": 2, "desc": "Jogue bolinha de gude %d vezes", "xp": 250},
	{"key": "dias", "target": 3, "desc": "Termine %d dias de aula", "xp": 500},
]
const CHALLENGES := 6


static func data() -> Dictionary:
	var d: Dictionary = SaveManager.section("pass")
	var season := season_id()
	if str(d.get("season", "")) != season:
		# temporada nova: zera o progresso (o premium continua até vencer)
		d["season"] = season
		d["xp"] = 0
		d["claimed_free"] = []
		d["claimed_prem"] = []
	return d


static func season_id() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d-%02d" % [int(t.year), int(t.month)]


static func season_name() -> String:
	var months := ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
	var t := Time.get_datetime_dict_from_system()
	return "Temporada de %s" % months[int(t.month) - 1]


static func days_left() -> int:
	var t := Time.get_datetime_dict_from_system()
	var days_in: int = [31, 29 if int(t.year) % 4 == 0 else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][int(t.month) - 1]
	return maxi(days_in - int(t.day) + 1, 1)


static func xp() -> int:
	return int(data().get("xp", 0))


static func tier() -> int:
	return mini(xp() / TIER_XP, TIERS)


static func tier_progress() -> float:
	if tier() >= TIERS:
		return 1.0
	return float(xp() % TIER_XP) / TIER_XP


static func add_xp(amount: int) -> void:
	var d := data()
	var before := tier()
	d["xp"] = int(d.get("xp", 0)) + amount
	if tier() > before and Engine.get_main_loop():
		GameManager.show_toast("Passe do Recreio: nível %d liberado! Abra a mochila para pegar o prêmio." % tier())


## Premium ativo? (compra pela Play Store; vale 30 dias / renovação mensal)
static func is_premium() -> bool:
	return int(data().get("premium_until", 0)) > int(Time.get_unix_time_from_system())


static func grant_premium(days := DAYS) -> void:
	var d := data()
	var now := int(Time.get_unix_time_from_system())
	d["premium_until"] = maxi(int(d.get("premium_until", 0)), now) + days * 86400
	SaveManager.save_game(false)


static func reward(track: String, t: int) -> Dictionary:
	return (PREMIUM if track == "prem" else FREE).get(t, {})


static func claimed(track: String, t: int) -> bool:
	return t in (data().get("claimed_" + track, []) as Array)


static func can_claim(track: String, t: int) -> bool:
	if reward(track, t).is_empty() or claimed(track, t) or tier() < t:
		return false
	return track == "free" or is_premium()


## Pega o prêmio. Retorna o texto do que ganhou ("" = não deu).
static func claim(track: String, t: int) -> String:
	if not can_claim(track, t):
		return ""
	var r := reward(track, t)
	var d := data()
	(d["claimed_" + track] as Array).append(t)
	var txt := ""
	if r.has("coins"):
		GameManager.add_rewards(0, int(r.coins))
		txt = "+%d moedas" % int(r.coins)
	elif r.has("diamonds"):
		GameManager.add_diamonds(int(r.diamonds))
		txt = "+%d diamantes" % int(r.diamonds)
	elif r.has("item"):
		var it := ShopCatalog.get_item(str(r.item))
		var inv: Dictionary = SaveManager.section("inventory")
		if not str(r.item) in inv.get("owned", []):
			(inv["owned"] as Array).append(str(r.item))
		txt = str(it.get("name", r.item))
	elif r.has("packs"):
		var parts := []
		for k in (r.packs as Dictionary).keys():
			for i in int(r.packs[k]):
				if k == "figurinha":
					Stickers.open_pack()
				else:
					var col: Dictionary = SaveManager.section("collections")
					var gude: Dictionary = col.get("gude", {})
					for j in 3:
						var tp: Dictionary = preload("res://scripts/minigames/marbles.gd").TYPES.pick_random()
						gude[tp.id] = int(gude.get(tp.id, 0)) + 1
					col["gude"] = gude
			parts.append("%d pacote(s) de %s" % [int(r.packs[k]), "figurinha" if k == "figurinha" else "gude"])
		txt = ", ".join(parts)
	SaveManager.save_game()
	AudioManager.play_ui("celebrate", -4.0)
	return txt


## Quantos prêmios esperando para pegar (bolinha vermelha na mochila).
static func pending() -> int:
	var n := challenges_ready()
	for t in range(1, tier() + 1):
		if can_claim("free", t):
			n += 1
		if can_claim("prem", t):
			n += 1
	return n


## Resumo do que a trilha premium dá (texto da chamada para comprar).
static func premium_summary() -> String:
	var n := {"skin": 0, "emote": 0, "aura": 0, "kart": 0}
	var dia := 0
	var coins := 0
	for t in PREMIUM.keys():
		var r: Dictionary = PREMIUM[t]
		if r.has("item"):
			var c := str(ShopCatalog.get_item(str(r.item)).get("cat", ""))
			if n.has(c):
				n[c] = int(n[c]) + 1
		dia += int(r.get("diamonds", 0))
		coins += int(r.get("coins", 0))
	return "Com o passe: %d karts com design (já no nível 1!), %d skins exclusivas, %d emojis ANIMADOS, %d efeitos, %d diamantes e %d moedas!" % [n.kart, n.skin, n.emote, n.aura, dia, coins]


## Itens exclusivos que o passe premium traz (para a vitrine).
static func premium_items() -> Array:
	var out := []
	for t in PREMIUM.keys():
		var r: Dictionary = PREMIUM[t]
		if r.has("item"):
			out.append(r.item)
	return out



# ------------------------------------------------------------------ desafios da semana

static func week_id() -> String:
	var unix := int(Time.get_unix_time_from_system())
	# semanas começando na segunda-feira (01/01/1970 foi quinta)
	return str((unix / 86400 + 3) / 7)


static func stat(key: String) -> int:
	var st: Dictionary = SaveManager.section("stats")
	if key.begins_with("mgw_"):
		var d: Variant = st.get("mg_" + key.substr(4))
		return int((d as Dictionary).get("won", 0)) if d is Dictionary else 0
	if key.begins_with("mg_"):
		var d2: Variant = st.get(key)
		return int((d2 as Dictionary).get("played", 0)) if d2 is Dictionary else 0
	if key == "dias":
		return int(SaveManager.section("progress").get("days_completed", 0))
	return int(st.get(key, 0))


## Os 6 desafios da semana (com o progresso guardado).
static func challenges() -> Array:
	var d := data()
	var w := week_id()
	if str(d.get("week", "")) != w or not (d.get("challenges") is Array):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("desafios-" + w)
		var pool: Array = CHALLENGE_POOL.duplicate()
		var list := []
		for i in CHALLENGES:
			var e: Dictionary = pool.pop_at(rng.randi() % pool.size()).duplicate()
			e["base"] = stat(e.key)
			e["claimed"] = false
			list.append(e)
		d["week"] = w
		d["challenges"] = list
	return d["challenges"]


static func challenge_progress(e: Dictionary) -> int:
	return clampi(stat(str(e.key)) - int(e.base), 0, int(e.target))


static func claim_challenge(i: int) -> bool:
	var list := challenges()
	if i < 0 or i >= list.size():
		return false
	var e: Dictionary = list[i]
	if bool(e.claimed) or challenge_progress(e) < int(e.target):
		return false
	e["claimed"] = true
	add_xp(int(e.xp))
	AudioManager.play_ui("celebrate", -4.0)
	SaveManager.save_game()
	return true


static func challenges_ready() -> int:
	var n := 0
	for e in challenges():
		if not bool(e.claimed) and challenge_progress(e) >= int(e.target):
			n += 1
	return n
