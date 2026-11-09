extends Minigame
## Corrida na pista pintada do pátio: 80 m contra dois colegas.
## Use o botão Correr! Os adversários têm fôlego e arrancadas variadas.

const START_X := -42.0
const FINISH_X := 38.0
const LANES := [-21.0, -21.5, -20.4]

var rivals: Array[NPC] = []
var _speeds := {}
var _finished_order: Array = []
var _player_done := false
var _elapsed := 0.0


func begin() -> void:
	var prefer := ["bia", "rafa", "lucas"]
	for nid in prefer:
		for n in npcs.npcs:
			if n.data.get("id", "") == nid and n.activity != "minigame" and rivals.size() < 2:
				rivals.append(n)
	for n in npcs.classmates:
		if rivals.size() >= 2:
			break
		if not n in rivals and n.activity != "minigame":
			rivals.append(n)
	take_npcs(rivals)
	player.force_stand()
	player.global_position = Vector3(START_X, 0.05, LANES[0])
	player.yaw = PI * 0.5
	player.velocity = Vector3.ZERO
	player.movement_locked = true
	if player.camera_rig:
		player.camera_rig.yaw = player.yaw + PI
		player.camera_rig.pitch = -14.0
		player.camera_rig.snap_to_target()
	for i in rivals.size():
		rivals[i].teleport(Vector3(START_X, 0.05, LANES[i + 1]), PI * 0.5)
		rivals[i].visual.play("look_around")
	countdown(3.0)
	super.begin()
	hud.set_minigame_text("Corrida! Prepare o botão Correr")


func play_label() -> String:
	return "Correr!"


func on_play() -> bool:
	player.run_active = true
	return true


func on_jump() -> bool:
	return _countdown > 0.0


func tick(delta: float) -> void:
	if not running:
		return
	if counting(delta):
		return
	if player.movement_locked:
		player.movement_locked = false
		player.run_active = true
		for i in rivals.size():
			var base := randf_range(4.55, 5.05)
			if rivals[i].personality == "competitivo":
				base += 0.15
			_speeds[rivals[i]] = base
			rivals[i].running = true
			rivals[i].run_speed = base
			rivals[i].go_to(Vector3(FINISH_X + 3.0, 0.05, LANES[i + 1]), true)
	_elapsed += delta
	# variação de ritmo (arrancada e cansaço)
	for r in rivals:
		var b: float = _speeds.get(r, 4.8)
		r.run_speed = b + sin(_elapsed * 1.3 + hash(r.name) % 7) * 0.35
		if r.global_position.x >= FINISH_X and not r in _finished_order:
			_finished_order.append(r)
	if not _player_done and player.global_position.x >= FINISH_X:
		_player_done = true
		_finished_order.append(player)
	var pos := 1
	for r in rivals:
		if r.global_position.x > player.global_position.x:
			pos += 1
	var left := maxf(FINISH_X - player.global_position.x, 0.0)
	hud.set_minigame_text("Corrida  ·  %dº lugar  ·  faltam %d m  ·  %.1f s" % [pos, int(left), _elapsed])
	if _player_done or _elapsed > 40.0:
		_finish()


func _finish() -> void:
	var place := _finished_order.find(player) + 1
	if place == 0:
		place = 3
	var won := 1 if place == 1 else (0 if place == 2 else -1)
	if won > 0:
		GameManager.unlock_achievement("velocista")
	var best: float = SaveManager.section("stats").get("corrida_recorde", 999.0)
	if _player_done and _elapsed < best:
		SaveManager.section("stats")["corrida_recorde"] = _elapsed
	end_game(won, "%dº lugar em %.1f s" % [place, _elapsed], [0, 20, 10, 5][place], [0, 30, 18, 10][place], {"score": place})


func cleanup() -> void:
	for r in rivals:
		if is_instance_valid(r):
			r.run_speed = 4.3
	super.cleanup()
