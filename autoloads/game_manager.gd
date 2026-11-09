extends Node
## Estado global do jogo: modo atual, pausa, referências principais e
## registro das ações de entrada (teclado/gamepad para testes no PC).

signal state_changed(new_state: int)
signal zone_changed(zone_name: String, indoor: bool)
signal toast(message: String)
signal rewards_changed(xp: int, coins: int, level: int)
signal level_up(new_level: int)
signal behavior_reported(kind: String)
signal friendship_changed(id: String, points: int, reason: String)

enum State { BOOT, MENU, PLAYING, PAUSED }

var state: int = State.BOOT
var player: Node = null
var world: Node = null
var current_zone := ""
## Menu sobreposto (mochila) aberto: pausa sem mostrar a tela de pausa.
var overlay_open := false
var _play_time_accum := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()


func _process(delta: float) -> void:
	if state == State.PLAYING:
		_play_time_accum += delta
		if _play_time_accum >= 10.0:
			var stats: Dictionary = SaveManager.section("stats")
			stats.play_time = float(stats.get("play_time", 0.0)) + _play_time_accum
			_play_time_accum = 0.0


func set_state(s: int) -> void:
	if s == state:
		return
	state = s
	get_tree().paused = (s == State.PAUSED)
	state_changed.emit(s)


func is_playing() -> bool:
	return state == State.PLAYING


func toggle_pause() -> void:
	if state == State.PLAYING:
		set_state(State.PAUSED)
	elif state == State.PAUSED:
		set_state(State.PLAYING)


func set_zone(zone_name: String, indoor: bool) -> void:
	if zone_name == current_zone:
		return
	current_zone = zone_name
	zone_changed.emit(zone_name, indoor)


func show_toast(message: String) -> void:
	toast.emit(message)


## XP necessária para ir do nível n ao n+1.
static func xp_for_level(n: int) -> int:
	return 100 + (n - 1) * 60


func level() -> int:
	return int(SaveManager.section("player").get("level", 1))


func coins() -> int:
	return int(SaveManager.section("player").get("coins", 0))


func add_rewards(xp: int, coin_amount: int) -> void:
	var p: Dictionary = SaveManager.section("player")
	p["coins"] = maxi(int(p.get("coins", 0)) + coin_amount, 0)
	var lv := int(p.get("level", 1))
	var cur := int(p.get("xp", 0)) + xp
	while cur >= xp_for_level(lv):
		cur -= xp_for_level(lv)
		lv += 1
		level_up.emit(lv)
		show_toast("Subiu para o nível %d!" % lv)
		if player:
			Effects.burst(player.global_position + Vector3(0, 2.0, 0), "confetti")
		AudioManager.play_ui("celebrate", -4.0)
	p["xp"] = cur
	p["level"] = lv
	rewards_changed.emit(cur, int(p.coins), lv)


func spend_coins(amount: int) -> bool:
	var p: Dictionary = SaveManager.section("player")
	if int(p.get("coins", 0)) < amount:
		return false
	p["coins"] = int(p.coins) - amount
	rewards_changed.emit(int(p.get("xp", 0)), int(p.coins), level())
	return true


signal achievement_unlocked(id: String)
signal shoved(npc: Node)


func report_shove(npc: Node) -> void:
	shoved.emit(npc)


## Conquistas (catálogo em Achievements). Retorna true se for nova.
func unlock_achievement(id: String) -> bool:
	var a: Dictionary = SaveManager.section("achievements")
	if a.has(id):
		return false
	a[id] = {"day": int(SaveManager.section("progress").get("days_completed", 0)) + 1}
	achievement_unlocked.emit(id)
	return true


## Comportamentos (o sistema disciplinar escuta este sinal).
func report_behavior(kind: String) -> void:
	behavior_reported.emit(kind)


func npc_display_name(id: String) -> String:
	for s in NPCRoster.STUDENTS:
		if s.id == id:
			return s.name
	return id


func add_stat(key: String, amount := 1) -> void:
	var stats: Dictionary = SaveManager.section("stats")
	stats[key] = int(stats.get(key, 0)) + amount


func _notification(what: int) -> void:
	# Salva ao sair ou quando o Android coloca o app em segundo plano.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state == State.PLAYING:
			set_state(State.PAUSED)
		SaveManager.save_game()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Botão "voltar" do Android abre/fecha a pausa.
		toggle_pause()


func _register_input() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT],
		"jump": [KEY_SPACE],
		"interact": [KEY_E],
		"play": [KEY_F],
		"emote": [KEY_Q],
		"pause": [KEY_ESCAPE, KEY_P],
		"cam_left": [KEY_J],
		"cam_right": [KEY_L],
	}
	for action in map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	var pads := {
		"jump": JOY_BUTTON_A, "interact": JOY_BUTTON_X, "play": JOY_BUTTON_B,
		"run": JOY_BUTTON_RIGHT_SHOULDER, "pause": JOY_BUTTON_START, "emote": JOY_BUTTON_Y,
	}
	for action in pads.keys():
		var jb := InputEventJoypadButton.new()
		jb.button_index = pads[action]
		InputMap.action_add_event(action, jb)
	var axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"cam_left": [JOY_AXIS_RIGHT_X, -1.0], "cam_right": [JOY_AXIS_RIGHT_X, 1.0],
	}
	for action in axes.keys():
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[action][0]
		jm.axis_value = axes[action][1]
		InputMap.action_add_event(action, jm)
