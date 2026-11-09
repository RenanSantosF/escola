class_name Friendship
extends RefCounted
## Amizades com alunos nomeados (salvas em SaveManager.friendships).
## Pontos sobem conversando, brincando junto e ajudando; nível 0–5.

const LEVELS := [0, 10, 25, 45, 70, 100]
const LEVEL_NAMES := ["Desconhecido", "Colega", "Conhecido", "Amigo", "Bom amigo", "Melhor amigo"]


static func points(id: String) -> int:
	var f: Dictionary = SaveManager.section("friendships")
	return int(f.get(id, {}).get("points", 0))


static func level(id: String) -> int:
	var p := points(id)
	var lv := 0
	for i in LEVELS.size():
		if p >= LEVELS[i]:
			lv = i
	return lv


static func add(id: String, amount: int, reason := "") -> void:
	if id == "":
		return
	var f: Dictionary = SaveManager.section("friendships")
	var entry: Dictionary = f.get(id, {"points": 0, "talks_day": 0, "last_day": 0})
	var before := level(id)
	entry["points"] = clampi(int(entry.get("points", 0)) + amount, 0, 150)
	f[id] = entry
	var after := level(id)
	if after > before:
		GameManager.show_toast("Amizade subiu: %s agora é %s!" % [GameManager.npc_display_name(id), LEVEL_NAMES[after]])
	GameManager.friendship_changed.emit(id, int(entry.points), reason)


## Conversar dá pontos, limitado a 3 conversas por dia com cada um.
static func on_talk(npc: Node) -> void:
	if npc == null or npc.get("role") != "student":
		return
	var id: String = npc.data.get("id", "")
	var f: Dictionary = SaveManager.section("friendships")
	var entry: Dictionary = f.get(id, {"points": 0, "talks_day": 0, "last_day": 0})
	var today := int(SaveManager.section("progress").get("days_completed", 0)) + 1
	if int(entry.get("last_day", 0)) != today:
		entry["last_day"] = today
		entry["talks_day"] = 0
	if int(entry.talks_day) >= 3:
		f[id] = entry
		return
	entry["talks_day"] = int(entry.talks_day) + 1
	f[id] = entry
	add(id, 3, "conversa")
