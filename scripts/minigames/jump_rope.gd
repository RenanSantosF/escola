extends Minigame
## Pular corda: dois colegas batem a corda, que acelera aos poucos.
## Pule quando a corda passar pelo chão. Cada pulo vale ponto.
## Barra de ritmo mostra quando pular; 3 vidas; a corda é grossa e visível.

const CENTER := Vector3(-24, 0.05, -2)
const HALF := 1.7

var turners: Array[NPC] = []
var _angle := PI * 0.5
var _speed := 3.6
var jumps := 0
var points := 0
var perfects := 0
var _level := 0
var _was_low := false
var _rope: MeshInstance3D
var _fail_t := 0.0
var lives := 3
var _jump_t := 99.0  # segundos desde o último pulo
var _rope_mat: StandardMaterial3D


func begin() -> void:
	for n in students(2, CENTER):
		turners.append(n)
	take_npcs(turners)
	player.force_stand()
	player.global_position = CENTER
	player.yaw = 0.0
	player.velocity = Vector3.ZERO
	player.movement_locked = true
	if player.camera_rig:
		player.camera_rig.set_override(Transform3D(Basis(), CENTER + Vector3(3.2, 2.0, 3.6)).looking_at(CENTER + Vector3(0, 0.9, 0), Vector3.UP))
	for i in turners.size():
		var sx := -1.0 if i == 0 else 1.0
		turners[i].teleport(CENTER + Vector3(sx * (HALF + 0.35), 0, 0), -PI * 0.5 * sx)
	_rope = MeshInstance3D.new()
	world.add_child(_rope)
	countdown(3.0)
	super.begin()


func play_label() -> String:
	return "Pular"


func on_play() -> bool:
	return on_jump()


func on_jump() -> bool:
	if player.is_on_floor() and _countdown <= 0.0 and _fail_t <= 0.0:
		player.velocity.y = 3.9
		_jump_t = 0.0
	return true


func _rope_point(t: float) -> Vector3:
	# corda em arco que gira em torno do eixo X (entre as mãos dos colegas)
	var x := lerpf(-HALF, HALF, t)
	var sag := 1.0 - pow(2.0 * t - 1.0, 2.0)
	var r := 0.95 * sag
	return CENTER + Vector3(x, 0.95 + sin(_angle) * r, cos(_angle) * r)


func _draw_rope() -> void:
	# corda grossa (tubo simples de 4 lados) para ver bem no celular
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.035
	var offs := [Vector3(0, w, 0), Vector3(0, 0, w), Vector3(0, -w, 0), Vector3(0, 0, -w)]
	for k in 20:
		var p0 := _rope_point(k / 20.0)
		var p1 := _rope_point((k + 1) / 20.0)
		for j in 4:
			var a0: Vector3 = offs[j]
			var a1: Vector3 = offs[(j + 1) % 4]
			im.surface_set_color(Color("ff3d6e") if j % 2 == 0 else Color("d81b4f"))
			im.surface_add_vertex(p0 + a0)
			im.surface_add_vertex(p1 + a0)
			im.surface_add_vertex(p1 + a1)
			im.surface_add_vertex(p0 + a0)
			im.surface_add_vertex(p1 + a1)
			im.surface_add_vertex(p0 + a1)
	im.surface_end()
	_rope.mesh = im
	if _rope_mat == null:
		_rope_mat = StandardMaterial3D.new()
		_rope_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_rope_mat.vertex_color_use_as_albedo = true
		_rope_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_rope.material_override = _rope_mat


func tick(delta: float) -> void:
	if not running:
		return
	_draw_rope()
	if counting(delta):
		return
	if _fail_t > 0.0:
		_fail_t -= delta
		_was_low = false
		return
	_angle += _speed * delta
	_speed = minf(_speed + delta * 0.05, 7.0)
	_jump_t += delta
	# barra de ritmo: enche até a corda chegar no chão
	var to_low := fposmod(1.5 * PI - _angle, TAU)
	hud.set_meter(1.0 - to_low / TAU)
	for t in turners:
		t.face(CENTER)
		if t.visual.animator.upper_action == "":
			t.visual.play("talk")
	# corda no chão (ponto mais baixo): sin(angle) ~ -1
	var low := sin(_angle) < -0.93
	if low and not _was_low:
		var feet_y := player.global_position.y
		# perdoa um pouquinho: pulou há pouco ou está no ar
		if feet_y > 0.14 or (_jump_t < 0.12 and not player.is_on_floor()):
			jumps += 1
			# no alto do pulo quando a corda passa = perfeito (vale 2)
			var perfect := feet_y - CENTER.y > 0.38
			if perfect:
				perfects += 1
				points += 2
				popup(player.global_position + Vector3(0, 2.1, 0), "Perfeito! +2", Color("6be36b"), 56)
			else:
				points += 1
			AudioManager.play_combo(jumps % 9, -6.0)
			var lv := jumps / 10
			if lv > _level:
				_level = lv
				_speed = minf(_speed + 0.35, 7.5)
				hud.show_banner("%d pulos!" % jumps, "A corda vai acelerar!")
				AudioManager.play_ui("combo", -4.0)
				for t in turners:
					t.say(["Isso!", "Não para!", "Mais rápido!"].pick_random(), 1.2)
		else:
			_trip()
			return
	_was_low = low
	hud.set_minigame_text("Pular corda  ·  %d pontos (%d pulos, %d perfeitos)  ·  Vidas: %d  ·  pule quando a barra encher" % [points, jumps, perfects, lives])


func _trip() -> void:
	note_miss()
	lives -= 1
	player.visual.play("hit")
	AudioManager.play_ui("trip", -4.0)
	if lives <= 0:
		_fail()
		return
	GameManager.show_toast("A corda bateu no pé! Restam %d vidas" % lives)
	for t in turners:
		t.say(["Ops!", "De novo!", "Quase!"].pick_random(), 1.2)
	_fail_t = 1.2
	_speed = maxf(_speed - 0.8, 3.6)
	_angle = PI * 0.5


func _fail() -> void:
	hud.set_meter(-1.0)
	var won := 1 if points >= 25 else (0 if points >= 10 else -1)
	if jumps >= 30:
		GameManager.unlock_achievement("corda_30")
	end_game(won, "%d pontos  ·  %d pulos (%d perfeitos)" % [points, jumps, perfects], 0, 8 + points, {"score": points})


func cleanup() -> void:
	if is_instance_valid(_rope):
		_rope.queue_free()
	super.cleanup()


func hints() -> Dictionary:
	return {"start": "Pule (botão azul) quando a barra ENCHER: é quando a corda chega no chão.", "idle": "Toque em Pular quando a barra embaixo encher.", "miss": "Não pule cedo! Espere a barra encher bem no final e pule."}
