extends Minigame
## Corrida com barreiras na pista pintada do pátio: 80 m contra dois colegas.
## O personagem corre sozinho na raia: TOQUE RÁPIDO no botão "Correr!" para
## ganhar velocidade (barra de energia) e PULE as 3 barreiras: passar limpo dá
## impulso; tropeçar faz perder velocidade. Os rivais também tropeçam às vezes.

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
const HURDLES := [-24.0, -4.0, 16.0]
var _root: Node3D
var _passed := {}  # índice da barreira -> true (para o jogador)
var _rival_passed := {}
var _slow_t := 0.0
var _rival_slow := {}
var clean := 0
var trips := 0


func _build_hurdles(lanes: Array) -> void:
	_root = Node3D.new()
	world.add_child(_root)
	var md := MeshData.new()
	for hx in HURDLES:
		for lz in lanes:
			md.cur_color = Color("f4f7fa")
			md.add_box(Transform3D(Basis(), Vector3(hx, 0.36, lz)), Vector3(0.08, 0.1, 0.9))
			md.cur_color = Color("e53935")
			md.add_box(Transform3D(Basis(), Vector3(hx, 0.36, lz - 0.2)), Vector3(0.085, 0.105, 0.18))
			md.add_box(Transform3D(Basis(), Vector3(hx, 0.36, lz + 0.2)), Vector3(0.085, 0.105, 0.18))
			md.cur_color = Color("37474f")
			for sz in [-0.43, 0.43]:
				md.add_box(Transform3D(Basis(), Vector3(hx, 0.2, lz + sz)), Vector3(0.05, 0.4, 0.05))
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	_root.add_child(mi)


func begin() -> void:
	if is_multi():
		# corrida com amigos: cada um na sua raia (sem bots), todos largam juntos
		var idx := maxi(int(net.get("index", 0)), 0)
		player.force_stand()
		player.global_position = Vector3(START_X, 0.05, -22.4 + idx * 1.05)
		var lanes := []
		for k in 4:
			lanes.append(-22.4 + k * 1.05)
		_build_hurdles(lanes)
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
	_build_hurdles(LANES)
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
		energy = minf(energy + 0.12, 1.0)
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
	energy = maxf(energy - delta * 0.28, 0.0)
	_slow_t = maxf(_slow_t - delta, 0.0)
	player.run_speed = (3.6 + energy * 3.2) * (0.45 if _slow_t > 0.0 else 1.0)
	hud.set_meter(energy)
	_check_hurdles()
	# variação de ritmo (arrancada e cansaço) e barreiras dos rivais
	for r in rivals:
		var b: float = _speeds.get(r, 4.8)
		var slow: float = maxf(float(_rival_slow.get(r, 0.0)) - delta, 0.0)
		_rival_slow[r] = slow
		r.run_speed = (b + sin(_elapsed * 1.3 + hash(r.name) % 7) * 0.35) * (0.45 if slow > 0.0 else 1.0)
		for i in HURDLES.size():
			var key := "%s_%d" % [r.name, i]
			if not _rival_passed.has(key) and r.global_position.x >= HURDLES[i]:
				_rival_passed[key] = true
				if randf() < 0.25:
					_rival_slow[r] = 0.8
					r.visual.play("hit")
					AudioManager.play_3d("trip", r.global_position, -8.0)
				else:
					r.visual.play("hop_one")
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
	if hud_hurdle_near():
		pass
	elif is_multi():
		hud.set_minigame_text("Corrida com a turma  ·  faltam %d m  ·  %.1f s  ·  TOQUE RÁPIDO em Correr!" % [int(left), _elapsed])
	else:
		hud.set_minigame_text("Corrida  ·  %dº lugar  ·  faltam %d m  ·  %.1f s  ·  TOQUE RÁPIDO em Correr!" % [pos, int(left), _elapsed])
	if _player_done or _elapsed > 40.0:
		_finish()


## Barreiras do jogador: passou por cima (pés acima de 0,32 m) ou tropeçou.
func _check_hurdles() -> void:
	for i in HURDLES.size():
		if _passed.has(i):
			continue
		if player.global_position.x >= HURDLES[i]:
			_passed[i] = true
			if player.global_position.y > 0.32:
				clean += 1
				energy = minf(energy + 0.2, 1.0)
				AudioManager.play_combo(clean)
				popup(player.global_position + Vector3(0, 2.0, 0), "Pulou! +impulso", Color("6be36b"), 56)
			else:
				trips += 1
				_slow_t = 0.8
				energy = maxf(energy - 0.25, 0.0)
				player.visual.play("hit")
				AudioManager.play_ui("trip", -4.0)
				popup(player.global_position + Vector3(0, 2.0, 0), "Tropeçou!", Color("ff6b6b"), 56)
		elif HURDLES[i] - player.global_position.x < 3.2 and HURDLES[i] - player.global_position.x > 0.0:
			hud.set_minigame_text("BARREIRA!  PULE AGORA!")
			return


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
	end_game(won, "%dº lugar em %.1f s  ·  %d barreiras limpas" % [place, _elapsed, clean], [0, 20, 10, 5][place], [0, 30, 18, 10][place], {"score": place, "time": snappedf(_elapsed, 0.01)})


func hud_hurdle_near() -> bool:
	for i in HURDLES.size():
		var dx: float = HURDLES[i] - player.global_position.x
		if not _passed.has(i) and dx > 0.0 and dx < 3.2:
			return true
	return false


func cleanup() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	player.forced_dir = Vector3.ZERO
	player.run_speed = _base_run
	player.run_active = false
	hud.set_meter(-1.0)
	for r in rivals:
		if is_instance_valid(r):
			r.run_speed = 4.3
	super.cleanup()
