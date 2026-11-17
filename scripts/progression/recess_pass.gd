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
const FREE := {
	1: {"coins": 30}, 2: {"packs": {"figurinha": 1}}, 4: {"coins": 40}, 6: {"packs": {"gude": 1}}, 8: {"coins": 50},
	10: {"item": "emo_clap"}, 12: {"coins": 60}, 14: {"packs": {"figurinha": 2}}, 16: {"coins": 70}, 18: {"packs": {"gude": 1}},
	20: {"coins": 80}, 22: {"packs": {"figurinha": 2}}, 24: {"coins": 90}, 26: {"packs": {"gude": 2}}, 28: {"coins": 100},
	30: {"item": "emo_celebrate"},
}
const PREMIUM := {
	1: {"item": "emo_floss"}, 2: {"coins": 120}, 3: {"item": "skin_pirata"}, 4: {"packs": {"figurinha": 3}},
	5: {"item": "emo_dance"}, 6: {"coins": 150}, 7: {"item": "aura_fogo"}, 8: {"packs": {"gude": 2}},
	9: {"item": "emo_laugh"}, 10: {"item": "skin_dragao"}, 11: {"coins": 180}, 12: {"item": "emo_flex"},
	13: {"packs": {"figurinha": 4}}, 14: {"item": "aura_coracoes"}, 15: {"item": "emo_heart"}, 16: {"coins": 200},
	17: {"item": "skin_neon"}, 18: {"item": "aura_raio"}, 19: {"packs": {"gude": 3}}, 20: {"item": "emo_robot"},
	21: {"coins": 250}, 22: {"item": "aura_estrelas"}, 23: {"packs": {"figurinha": 5}}, 24: {"item": "emo_spin"},
	25: {"coins": 300}, 26: {"item": "aura_neve"}, 27: {"item": "tin_rosa"}, 28: {"coins": 400},
	29: {"item": "aura_arco"}, 30: {"item": "skin_unicornio"},
}


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
	SaveManager.save_game()


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
	var n := 0
	for t in range(1, tier() + 1):
		if can_claim("free", t):
			n += 1
		if can_claim("prem", t):
			n += 1
	return n


## Itens exclusivos que o passe premium traz (para a vitrine).
static func premium_items() -> Array:
	var out := []
	for t in PREMIUM.keys():
		var r: Dictionary = PREMIUM[t]
		if r.has("item"):
			out.append(r.item)
	return out
