extends Node
## Estado global do jogo: modo atual, pausa, referências principais e
## registro das ações de entrada (teclado/gamepad para testes no PC).

signal state_changed(new_state: int)
signal zone_changed(zone_name: String, indoor: bool)
signal toast(message: String)

enum State { BOOT, MENU, PLAYING, PAUSED }

var state: int = State.BOOT
var player: Node = null
var world: Node = null
var current_zone := ""
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
