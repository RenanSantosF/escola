class_name DailyGift
extends RefCounted
## PRESENTE DO DIA: entrar no jogo em dias seguidos dá prêmios cada vez
## melhores (7 dias; no 7º, diamantes e um pacote). Pulou um dia: recomeça.

const REWARDS := [
	{"coins": 50}, {"coins": 80}, {"packs": 1}, {"coins": 120}, {"diamonds": 5}, {"coins": 200}, {"diamonds": 15, "coins": 300},
]


static func _today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


static func data() -> Dictionary:
	return SaveManager.section("daily_gift")


## Dia da sequência que pode ser pego hoje (1..7), ou 0 se já pegou hoje.
static func available_day() -> int:
	var d := data()
	var last := int(d.get("last", -10))
	var t := _today()
	if last == t:
		return 0
	var streak := int(d.get("streak", 0))
	if last != t - 1:
		streak = 0
	return streak % REWARDS.size() + 1


static func claim() -> String:
	var day := available_day()
	if day == 0:
		return ""
	var d := data()
	d["streak"] = day
	d["last"] = _today()
	var r: Dictionary = REWARDS[day - 1]
	var parts := []
	if r.has("coins"):
		GameManager.add_rewards(0, int(r.coins))
		parts.append("%d moedas" % int(r.coins))
	if r.has("diamonds"):
		GameManager.add_diamonds(int(r.diamonds))
		parts.append("%d diamantes" % int(r.diamonds))
	if r.has("packs"):
		for i in int(r.packs):
			Stickers.open_pack()
		parts.append("%d pacote de figurinhas" % int(r.packs))
	SaveManager.save_game()
	return ", ".join(parts)


static func reward_text(i: int) -> String:
	var r: Dictionary = REWARDS[i]
	var parts := []
	if r.has("coins"):
		parts.append("%d moedas" % int(r.coins))
	if r.has("diamonds"):
		parts.append("%d diamantes" % int(r.diamonds))
	if r.has("packs"):
		parts.append("figurinhas")
	return " + ".join(parts)
