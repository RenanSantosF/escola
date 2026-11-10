extends Minigame
## Corrida na pista pintada do pátio: 80 m contra dois colegas.
## O personagem corre sozinho na raia: TOQUE RÁPIDO no botão "Correr!" para
## ganhar velocidade (barra de energia). Pular (na hora certa) dá impulso.

const START_X := -42.0
const FINISH_X := 38.0
const LANES := [-21.0, -21.5, -20.4]

var rivals: Array[NPC] = []
var _speeds := {}
var _finished_order: Array = []
var _player_done := false
var _elapsed := 0.0
var energy := 0.3
var _base_run := 5.0


func begin() -> void:
	if is_multi():
		# corrida com amigos: cada um na sua raia (sem bots), todos largam juntos
		var idx := maxi(int(net.get("index", 0)), 0)
		player.force_stand()
		player.global_position = Vector3(START_X, 0.05, -22.4 + idx * 1.05)
		player.yaw = PI * 0.5
		player.velocity = Vector3.ZERO
		player.movement_locked = true
		if player.camera_rig:
			player.camera_rig.yaw = player.yaw + PI
			player.camera_rig.pitch = -14.0
			player.camera_rig.snap_to_target()
		countdown(3.0)
		super.begin()
		hud.set_minigame_text("Corrida com a turma! Prepare o botão Correr")
		return
	for n in students(2, Vector3(START_X, 0.05, -24.0), ["bia", "rafa", "lucas"]):
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
	if _countdown <= 0.0:
		energy = minf(energy + 0.11, 1.0)
	else:
		# largada: tocar antes do "Já" queima um pouco
		energy = maxf(energy - 0.05, 0.0)
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
		_base_run = player.run_speed
		player.forced_dir = Vector3(1, 0, 0)
		for i in rivals.size():
			var base := randf_range(4.7, 5.3)
			if rivals[i].personality == "competitivo":
				base += 0.15
			_speeds[rivals[i]] = base
			rivals[i].running = true
			rivals[i].run_speed = base
			rivals[i].go_to(Vector3(FINISH_X + 3.0, 0.05, LANES[i + 1]), true)
	_elapsed += delta
	energy = maxf(energy - delta * 0.32, 0.0)
	player.run_speed = 3.6 + energy * 3.0
	hud.set_meter(energy)
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
	if is_multi():
		hud.set_minigame_text("Corrida com a turma  ·  faltam %d m  ·  %.1f s  ·  TOQUE RÁPIDO em Correr!" % [int(left), _elapsed])
	else:
		hud.set_minigame_text("Corrida  ·  %dº lugar  ·  faltam %d m  ·  %.1f s  ·  TOQUE RÁPIDO em Correr!" % [pos, int(left), _elapsed])
	if _player_done or _elapsed > 40.0:
		_finish()


func _finish() -> void:
	var place := _finished_order.find(player) + 1
	if place == 0:
		place = 3
	var won := 1 if place == 1 else (0 if place == 2 else -1)
	if is_multi():
		won = 0  # quem ganhou é decidido pelo placar da turma (menor tempo)
	if won > 0:
		GameManager.unlock_achievement("velocista")
	var best: float = SaveManager.section("stats").get("corrida_recorde", 999.0)
	if _player_done and _elapsed < best:
		SaveManager.section("stats")["corrida_recorde"] = _elapsed
	end_game(won, "%dº lugar em %.1f s" % [place, _elapsed], [0, 20, 10, 5][place], [0, 30, 18, 10][place], {"score": place, "time": snappedf(_elapsed, 0.01)})


func cleanup() -> void:
	player.forced_dir = Vector3.ZERO
	player.run_speed = _base_run
	player.run_active = false
	hud.set_meter(-1.0)
	for r in rivals:
		if is_instance_valid(r):
			r.run_speed = 4.3
	super.cleanup()
