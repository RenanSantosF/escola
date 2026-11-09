extends Minigame
## Pular corda: dois colegas batem a corda, que acelera aos poucos.
## Pule (botão azul) quando a corda passar pelo chão. Cada pulo vale ponto.

const CENTER := Vector3(-24, 0.05, -2)
const HALF := 1.7

var turners: Array[NPC] = []
var _angle := PI * 0.5
var _speed := 3.6
var jumps := 0
var _was_low := false
var _rope: MeshInstance3D
var _fail_t := 0.0


func begin() -> void:
	for n in npcs.classmates:
		if n.activity != "minigame" and turners.size() < 2:
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
	if player.is_on_floor() and _countdown <= 0.0:
		player.velocity.y = 3.8
	return true


func _rope_point(t: float) -> Vector3:
	# corda em arco que gira em torno do eixo X (entre as mãos dos colegas)
	var x := lerpf(-HALF, HALF, t)
	var sag := 1.0 - pow(2.0 * t - 1.0, 2.0)
	var r := 0.95 * sag
	return CENTER + Vector3(x, 0.95 + sin(_angle) * r, cos(_angle) * r)


func _draw_rope() -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in 16:
		im.surface_set_color(Color("e04a3a"))
		im.surface_add_vertex(_rope_point(k / 16.0))
		im.surface_add_vertex(_rope_point((k + 1) / 16.0))
	im.surface_end()
	_rope.mesh = im
	if _rope.material_override == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		_rope.material_override = m


func tick(delta: float) -> void:
	if not running:
		return
	_draw_rope()
	if counting(delta):
		return
	_angle += _speed * delta
	_speed = minf(_speed + delta * 0.06, 7.5)
	for t in turners:
		t.face(CENTER)
		if t.visual.animator.upper_action == "":
			t.visual.play("talk")
	# corda no chão (ponto mais baixo): sin(angle) ~ -1
	var low := sin(_angle) < -0.93
	if low and not _was_low:
		var feet_y := player.global_position.y
		if feet_y > 0.2:
			jumps += 1
			AudioManager.play_ui("ui_click", -6.0, 0.1)
			if jumps % 10 == 0:
				GameManager.show_toast("%d pulos!" % jumps)
				for t in turners:
					t.say(["Isso!", "Não para!", "Mais rápido!"].pick_random(), 1.2)
		else:
			_fail()
			return
	_was_low = low
	hud.set_minigame_text("Pular corda  ·  %d pulos  ·  pule quando a corda tocar o chão" % jumps)


func _fail() -> void:
	player.visual.play("hit")
	AudioManager.play_ui("bonk", -6.0)
	var won := 1 if jumps >= 15 else (0 if jumps >= 7 else -1)
	if jumps >= 30:
		GameManager.unlock_achievement("corda_30")
	end_game(won, "%d pulos seguidos" % jumps, 4 + jumps / 2, 8 + jumps, {"score": jumps})


func cleanup() -> void:
	if is_instance_valid(_rope):
		_rope.queue_free()
	super.cleanup()
