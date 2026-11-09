extends Minigame
## Guerra de bolinhas de papel no espaço de convivência: 45 s, 4 colegas.
## Arremesse (botão amarelo, mira automática no colega à frente) e desvie
## das bolinhas deles (correr/pular). Cada acerto vale ponto; 3 vidas.

const AREA := Rect2(34, -22, 24, 18)
const TIME := 45.0

var foes: Array[NPC] = []
var hits := 0
var lives := 3
var _shots: Array = []  # {node, pos, vel, from_player, alive}
var _root: Node3D
var _cd := 0.0
var _npc_t := 2.0
var _inv := 0.0


func begin() -> void:
	for n in npcs.classmates:
		if n.activity != "minigame" and foes.size() < 4:
			foes.append(n)
	take_npcs(foes)
	_root = Node3D.new()
	world.add_child(_root)
	player.force_stand()
	player.global_position = Vector3(46, 0.05, -5.5)
	player.yaw = PI
	if player.camera_rig:
		player.camera_rig.yaw = 0.0
		player.camera_rig.snap_to_target()
	for i in foes.size():
		foes[i].teleport(Vector3(38 + i * 5.0, 0.05, -18), 0.0)
	time_left = TIME
	countdown(3.0)
	super.begin()


func play_label() -> String:
	return "Arremessar"


func on_play() -> bool:
	if _cd > 0.0 or _countdown > 0.0:
		return true
	_cd = 0.6
	var fwd := Vector3(sin(player.yaw), 0, cos(player.yaw))
	var best: NPC = null
	var bs := INF
	for f in foes:
		var to := f.global_position - player.global_position
		to.y = 0
		var s := fwd.angle_to(to.normalized()) * 6.0 + to.length() * 0.1
		if s < bs:
			bs = s
			best = f
	player.visual.play("throw")
	var start := player.global_position + Vector3(0, 1.5, 0) + fwd * 0.4
	var aim: Vector3 = best.global_position + Vector3(0, 1.0, 0) if best else start + fwd * 10.0
	get_tree().create_timer(0.35).timeout.connect(func(): _spawn_shot(start, aim, true))
	return true


func _spawn_shot(start: Vector3, aim: Vector3, from_player: bool) -> void:
	if not running:
		return
	var d := aim - start
	var speed := 12.0 if from_player else 9.0
	var t := d.length() / speed
	var vel := d / maxf(t, 0.05) + Vector3(0, 0.5 * 9.8 * t, 0)
	var md := MeshData.new()
	md.cur_color = Color("f4f1e8") if from_player else Color("ffe9a8")
	md.add_sphere(Transform3D(), 0.06, 8, 6)
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	_root.add_child(mi)
	_shots.append({"node": mi, "pos": start, "vel": vel, "from_player": from_player, "alive": true})
	AudioManager.play_3d("whoosh", start, -8.0)


func tick(delta: float) -> void:
	if not running:
		return
	if counting(delta):
		return
	_cd = maxf(_cd - delta, 0.0)
	_inv = maxf(_inv - delta, 0.0)
	time_left -= delta
	hud.set_minigame_text("Guerra de papel  ·  Acertos: %d  ·  Vidas: %s  ·  %s" % [hits, "♥".repeat(lives), fmt_time(time_left)])
	if time_left <= 0.0:
		_finish()
		return
	# NPCs correm pela área e arremessam no jogador
	_npc_t -= delta
	for f in foes:
		if not f.moving:
			f.go_to(Vector3(randf_range(AREA.position.x, AREA.end.x), 0.05, randf_range(AREA.position.y, AREA.end.y)), randf() < 0.5)
	if _npc_t <= 0.0:
		_npc_t = randf_range(1.2, 2.2)
		var f: NPC = foes.pick_random()
		f.stop()
		f.face(player.global_position)
		f.visual.play("throw")
		f.say(["Toma!", "Lá vai!", "Hahaha!"].pick_random(), 1.0)
		var start := f.global_position + Vector3(0, 1.5, 0)
		var lead := Vector3(player.velocity.x, 0, player.velocity.z) * 0.35
		var aim := player.global_position + Vector3(0, 1.0, 0) + lead + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		get_tree().create_timer(0.45).timeout.connect(func(): _spawn_shot(start, aim, false))
	# bolinhas em voo
	for s in _shots:
		if not s.alive:
			continue
		s.vel += Vector3(0, -9.8, 0) * delta
		s.pos += s.vel * delta
		s.node.global_position = s.pos
		if s.pos.y < 0.05:
			s.alive = false
			s.node.queue_free()
			continue
		if s.from_player:
			for f in foes:
				if (f.global_position + Vector3(0, 1.0, 0)).distance_to(s.pos) < 0.55:
					hits += 1
					s.alive = false
					s.node.queue_free()
					f.visual.play("hit")
					f.say(["Ai!", "Me pegou!", "Não valeu!"].pick_random(), 1.0)
					AudioManager.play_3d("bonk", f.global_position, -8.0)
					break
		elif _inv <= 0.0 and (player.global_position + Vector3(0, 1.0, 0)).distance_to(s.pos) < 0.5:
			s.alive = false
			s.node.queue_free()
			lives -= 1
			_inv = 1.0
			player.visual.play("hit")
			AudioManager.play_ui("bonk", -6.0)
			if lives <= 0:
				_finish()
				return
	_shots = _shots.filter(func(s): return s.alive)
	# limite da área
	var p := player.global_position
	player.global_position.x = clampf(p.x, AREA.position.x - 2.0, AREA.end.x + 2.0)
	player.global_position.z = clampf(p.z, AREA.position.y - 2.0, AREA.end.y + 2.0)


func _finish() -> void:
	if not running:
		return
	var won := 1 if hits >= 8 and lives > 0 else (0 if hits >= 4 else -1)
	end_game(won, "%d acertos" % hits, 5 + hits * 2, 10 + hits * 3, {"score": hits})


func cleanup() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	super.cleanup()
