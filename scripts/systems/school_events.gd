class_name SchoolEvents
extends Node
## Eventos espontâneos (variam a cada dia, sem repetir no mesmo dia) e
## pequenas missões pedidas por colegas.
##
## Eventos: bola nova, torneio relâmpago (moedas em dobro), inspetora
## chamando atenção de um aluno, figurinha rara, colega pede ajuda (missão),
## diretor no pátio, lanche especial na cantina, recado para um amigo.

signal event_started(id: String)
signal mission_changed(text: String)

const EVENTS := ["bola_nova", "torneio", "bronca", "figurinha", "ajuda", "diretor", "lanche", "recado"]
const LOST_ITEMS := [
	{"item": "livro", "name": "meu livro de histórias"}, {"item": "caderno", "name": "meu caderno azul"},
	{"item": "apagador", "name": "o apagador da sala"}, {"item": "giz", "name": "minha caixa de giz de cera"},
]

var npcs: NPCManager
var player: PlayerController
var hud: HUD
var day: SchoolDay
var world: SchoolWorld
var minigames: MinigameManager
var discipline: DisciplineSystem
var _t := 25.0
var _done_today: Array = []
var mission: Dictionary = {}  # {type, giver, item_node, target_npc, text}
var special_snack := false
var _extra_balls: Array = []


func setup(m: NPCManager, p: PlayerController, h: HUD, d: SchoolDay, w: SchoolWorld, mg: MinigameManager, disc: DisciplineSystem) -> void:
	npcs = m
	player = p
	hud = h
	day = d
	world = w
	minigames = mg
	discipline = disc
	d.phase_changed.connect(_on_phase)
	d.day_finished.connect(func(_s): _done_today.clear())


func _on_phase(p: int) -> void:
	if p == SchoolDay.Phase.RECESS:
		_t = randf_range(12.0, 25.0)
	else:
		minigames.reward_mult = 1.0
		special_snack = false
		for b in _extra_balls:
			if is_instance_valid(b):
				b.queue_free()
		_extra_balls.clear()
		if not mission.is_empty() and p == SchoolDay.Phase.RETURN:
			_fail_mission("O recreio acabou antes de terminar a missão.")


func _process(delta: float) -> void:
	if not GameManager.is_playing() or day.phase != SchoolDay.Phase.RECESS or discipline.in_cutscene:
		return
	_t -= delta
	if _t <= 0.0:
		_t = randf_range(40.0, 65.0)
		trigger_random()
	_update_mission()


func trigger_random() -> void:
	var options := EVENTS.filter(func(e): return not e in _done_today)
	if not mission.is_empty():
		options.erase("ajuda")
		options.erase("recado")
	if options.is_empty():
		return
	trigger(options.pick_random())


func _named(id: String) -> NPC:
	for n in npcs.npcs:
		if n.data.get("id", "") == id and n.active:
			return n
	return null


func _any_student_near(r := 40.0) -> NPC:
	var cands: Array[NPC] = []
	for n in npcs.npcs:
		if n.active and n.role == "student" and n.activity != "minigame" and n.global_position.distance_to(player.global_position) < r:
			cands.append(n)
	return cands.pick_random() if not cands.is_empty() else null


func trigger(id: String) -> void:
	_done_today.append(id)
	event_started.emit(id)
	match id:
		"bola_nova":
			var lucas := _named("lucas")
			var at: Vector3 = lucas.global_position if lucas else Vector3(5, 0.3, -5)
			var b := KickBall.create("football")
			b.position = at + Vector3(0.8, 0.4, 0.8)
			world.get_node("Dynamic").add_child(b)
			_extra_balls.append(b)
			hud.show_banner("Bola nova!", "O Lucas trouxe uma bola nova para o pátio!")
			if lucas:
				lucas.say("Olha minha bola nova!", 3.0)
		"torneio":
			minigames.reward_mult = 2.0
			hud.show_banner("Torneio relâmpago!", "Futebol na quadra vale recompensa em DOBRO neste recreio")
		"bronca":
			var s := _any_student_near(60.0)
			if s:
				npcs.inspector.go_to(s.global_position + Vector3(0.9, 0, 0.9), false, func():
					npcs.inspector.face(s.global_position)
					npcs.inspector.say(["Desce daí, menino!", "Isso é lugar de jogar lixo?", "Sem empurra-empurra!"].pick_random(), 3.0)
					s.visual.play("sad"))
				GameManager.show_toast("A Dona Cida está chamando atenção de alguém...")
		"figurinha":
			var j := _named("julia")
			hud.show_banner("Figurinha rara!", "A Júlia conseguiu uma figurinha brilhante. Vá falar com ela!")
			if j:
				j.say("Olha essa figurinha brilhante!!", 4.0)
				j.activity_data["rare_sticker"] = true
		"ajuda":
			_start_fetch_mission()
		"diretor":
			npcs.director.activity = "patrol"
			npcs.director.go_to(Vector3(0, 0.05, -8))
			hud.show_banner("O diretor está no pátio!", "Melhor não sair correndo por aí...")
		"lanche":
			special_snack = true
			hud.show_banner("Lanche especial!", "Hoje a cantina tem bolo de chocolate!")
			npcs.cook.say("Bolo de chocolate saindo!", 4.0)
			for i in 3:
				var s2 := _any_student_near(80.0)
				if s2 and s2.activity != "queue":
					npcs._leave_activity(s2)
					npcs._try_activity(s2, "queue", true)
		"recado":
			_start_deliver_mission()


# ------------------------------------------------------------- missões

func _start_fetch_mission() -> void:
	var giver := _any_student_near(35.0)
	if giver == null:
		return
	var it: Dictionary = LOST_ITEMS.pick_random()
	var node := PickupItem.create_item(it.item)
	var pos := npcs.nav.random_point(RandomNumberGenerator.new(), Rect2(giver.global_position.x - 25, giver.global_position.z - 25, 50, 50))
	node.position = pos + Vector3(0, 0.3, 0)
	world.get_node("Dynamic").add_child(node)
	mission = {"type": "fetch", "giver": giver, "item_node": node, "text": "Ache %s do(a) %s e devolva" % [it.name.replace("meu ", "o ").replace("minha ", "a "), giver.display_name]}
	npcs._leave_activity(giver)
	giver.activity = "waiting_help"
	giver.go_to(player.global_position + Vector3(1.2, 0, 1.2), true, func():
		giver.face(player.global_position)
		giver.say("Me ajuda? Perdi %s!" % it.name, 3.5))
	hud.show_banner("Um colega precisa de ajuda!", mission.text)
	mission_changed.emit(mission.text)


func _start_deliver_mission() -> void:
	var giver := _any_student_near(30.0)
	var target: NPC = null
	var cands := npcs.classmates.filter(func(n): return n.active and n != giver and n.activity != "minigame")
	if giver == null or cands.is_empty():
		return
	target = cands.pick_random()
	mission = {"type": "deliver", "giver": giver, "target_npc": target, "text": "Entregue o bilhete de %s para %s" % [giver.display_name, target.display_name]}
	giver.say("Entrega esse bilhete pro(a) %s?" % target.display_name, 3.5)
	hud.show_banner("Recado!", mission.text)
	mission_changed.emit(mission.text)


func _update_mission() -> void:
	if mission.is_empty():
		return
	hud.set_mission(mission.text if not discipline.restricted else hud._mission.text)


## Prompts especiais ao falar com NPCs (chamado pelo SchoolDay).
func npc_prompt(npc: NPC) -> String:
	if not mission.is_empty():
		if mission.type == "fetch" and npc == mission.giver and player.held_item == mission.item_node:
			return "Devolver para %s" % npc.display_name
		if mission.type == "deliver" and npc == mission.target_npc:
			return "Entregar bilhete"
	if npc.activity_data.get("rare_sticker", false):
		return "Ver figurinha rara"
	if npc == npcs.cook and day.phase == SchoolDay.Phase.RECESS:
		return "Comprar lanche (%d moedas)" % (8 if special_snack else 5)
	return ""


func npc_interact(npc: NPC) -> bool:
	if not mission.is_empty():
		if mission.type == "fetch" and npc == mission.giver and player.held_item == mission.item_node:
			var node: PickupItem = mission.item_node
			player.held_item = null
			node.queue_free()
			_complete_mission(npc, "Valeu demais! Você é demais!")
			return true
		if mission.type == "deliver" and npc == mission.target_npc:
			npc.visual.play("celebrate")
			Friendship.add(mission.giver.data.get("id", ""), 5, "recado")
			_complete_mission(npc, "Um bilhete pra mim? Que legal!")
			return true
	if npc.activity_data.get("rare_sticker", false):
		npc.activity_data.erase("rare_sticker")
		day.dialogue.open(npc.display_name, ["Olha que linda! É brilhante!", "Tenho uma repetida... toma, é sua!"])
		Stickers.give_random(true)
		Friendship.add(npc.data.get("id", ""), 4, "figurinha")
		return true
	if npc == npcs.cook and day.phase == SchoolDay.Phase.RECESS:
		var price := 8 if special_snack else 5
		if GameManager.spend_coins(price):
			npc.say("Aqui está, querido!", 2.0)
			player.visual.play("celebrate")
			GameManager.add_rewards(6 if special_snack else 3, 0)
			GameManager.add_stat("lanches")
			if special_snack:
				GameManager.unlock_achievement("bolo_de_chocolate")
			GameManager.show_toast("Você comeu %s! Delícia." % ("bolo de chocolate" if special_snack else "uma coxinha"))
		else:
			npc.say("Faltou moeda, querido...", 2.0)
		return true
	return false


func _complete_mission(npc: NPC, line: String) -> void:
	npc.say(line, 3.0)
	Friendship.add(npc.data.get("id", ""), 8, "missao")
	discipline.change_reputation(4)
	GameManager.add_rewards(25, 15)
	GameManager.add_stat("missoes")
	hud.show_banner("Missão cumprida!", "+15 moedas, +25 XP, amizade e reputação")
	if npc.activity in ["waiting_help"]:
		npc.activity = "wander"
	mission = {}
	hud.set_mission("")
	mission_changed.emit("")


func _fail_mission(msg: String) -> void:
	if mission.get("item_node") and is_instance_valid(mission.item_node):
		mission.item_node.queue_free()
	mission = {}
	hud.set_mission("")
	GameManager.show_toast(msg)
	mission_changed.emit("")
