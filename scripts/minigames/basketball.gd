extends Minigame
## Basquete: arremessos na cesta da quadrinha do Parque do Morro. 3 marcas no chão (perto,
## meio, longe = 2, 2 e 3 pontos); 4 bolas por marca. Joystick mira, SEGURE
## o botão amarelo (a linha mostra o arco) e SOLTE. Força certa = cesta;
## quase = bate no aro e às vezes cai!

const HOOP := Vector3(ParkHill.COURT.x + 6.0, 3.05, ParkHill.COURT.y)  # centro do aro
const SPOTS := [Vector3(ParkHill.COURT.x + 2.5, 0.05, ParkHill.COURT.y), Vector3(ParkHill.COURT.x + 0.5, 0.05, ParkHill.COURT.y + 2.5), Vector3(ParkHill.COURT.x - 2.0, 0.05, ParkHill.COURT.y)]
const POINTS := [2, 2, 3]
const BALLS_PER_SPOT := 4

var score := 0
var made := 0
var spot_i := 0
var balls_left := BALLS_PER_SPOT
var _power := 0.0
var _power_dir := 1.0
var _charging := false
var _yaw := 0.0
var _ball: MeshInstance3D
var _flying := false
var _root: Node3D
var _arc: AimArc
var _ideal := 0.5


func begin() -> void:
	_root = Node3D.new()
	world.add_child(_root)
	_arc = AimArc.new()
	_root.add_child(_arc)
	var md := MeshData.new()
	md.cur_color = Color("ff7a1a")
	md.add_sphere(Transform3D(), 0.13, 12, 8)
	md.cur_color = Color("3a1f0f")
	md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.132, 0.132, 0.012, 14, false)
	_ball = MeshInstance3D.new()
	_ball.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	_root.add_child(_ball)
	_ball.visible = false
	player.force_stand()
	player.movement_locked = true
	_go_spot(0)
	super.begin()
	hud.show_banner("Basquete!", "Segure para mirar e solte na força certa")


func _go_spot(i: int) -> void:
	spot_i = i
	balls_left = BALLS_PER_SPOT
	var sp: Vector3 = SPOTS[i]
	player.global_position = sp
	var to := HOOP - sp
	_yaw = atan2(to.x, to.z)
	player.yaw = _yaw
	if player.camera_rig:
		var back := -Vector3(sin(_yaw), 0, cos(_yaw))
		player.camera_rig.set_override(Transform3D(Basis(), sp + back * 3.0 + Vector3(0.8, 2.2, 0)).looking_at(HOOP + Vector3(0, -0.8, 0), Vector3.UP))
	# força ideal para esta distância (velocidade de AimArc.solve)
	_ideal = clampf((Vector2(to.x, to.z).length() - 2.5) / 7.5, 0.15, 0.9)
	_update_hud()


func _update_hud() -> void:
	hud.set_minigame_text("Basquete  ·  %d pontos  ·  marca %d de 3 (vale %d)  ·  bolas: %d" % [score, spot_i + 1, POINTS[spot_i], balls_left])


func play_label() -> String:
	return "Soltar!" if _charging else "Segure: arremesso"


func interact_label() -> String:
	return "Sair"


func on_interact() -> bool:
	_finish()
	return true


func on_play() -> bool:
	if _flying or balls_left <= 0:
		return true
	_charging = true
	_power = 0.0
	_power_dir = 1.0
	return true


func on_play_release() -> bool:
	if _charging:
		_charging = false
		hud.set_meter(-1.0)
		_arc.hide_arc()
		_shoot()
	return true


func _velocity(power: float) -> Vector3:
	var from := player.global_position + Vector3(0, 1.7, 0)
	var dir := Vector3(sin(_yaw), 0, cos(_yaw))
	var dist := Vector2(HOOP.x - from.x, HOOP.z - from.z).length()
	# alcance horizontal cresce com a força; arco alto e bonito
	var reach := dist * lerpf(0.55, 1.45, (power - _ideal) * 1.6 + 0.5)
	var t := 0.95 + dist * 0.05
	var vy := (HOOP.y + 0.15 - from.y + 0.5 * 9.8 * t * t) / t
	return dir * (reach / t) + Vector3(0, vy, 0)


func _shoot() -> void:
	balls_left -= 1
	player.visual.play("throw")
	var from := player.global_position + Vector3(0, 1.7, 0)
	var vel := _velocity(_power)
	var err := absf(_power - _ideal)
	_flying = true
	_ball.visible = true
	var t_total := 1.0 + Vector2(HOOP.x - from.x, HOOP.z - from.z).length() * 0.05
	var tw := create_tween()
	tw.tween_method(func(t: float):
		_ball.global_position = from + vel * t + Vector3(0, -4.9 * t * t, 0)
		_ball.rotate_x(0.25), 0.0, t_total, t_total)
	await tw.finished
	if not running:
		return
	if err < 0.09:
		_score("CESTA!", POINTS[spot_i])
		await _drop_through()
	elif err < 0.16 and randf() < 0.45:
		_score("Bateu no aro... e caiu!", POINTS[spot_i])
		await _drop_through()
	else:
		AudioManager.play_ui("bonk", -8.0)
		GameManager.show_toast("Bateu no aro! " + ("Mais força!" if _power < _ideal else "Menos força!"))
		var tw2 := create_tween()
		tw2.tween_property(_ball, "global_position", _ball.global_position + Vector3(randf_range(-1, 1), -2.9, randf_range(-1, 1)), 0.6)
		await tw2.finished
	_ball.visible = false
	_flying = false
	if balls_left <= 0:
		if spot_i < SPOTS.size() - 1:
			_go_spot(spot_i + 1)
			GameManager.show_toast("Próxima marca: mais longe!")
		else:
			_finish()
	_update_hud()


func _score(msg: String, pts: int) -> void:
	score += pts
	made += 1
	AudioManager.play_ui("ui_confirm", -2.0)
	GameManager.show_toast("%s +%d" % [msg, pts])
	Effects.burst(HOOP, "confetti")


func _drop_through() -> void:
	var tw := create_tween()
	tw.tween_property(_ball, "global_position", HOOP + Vector3(0, -1.6, 0), 0.45).from(HOOP + Vector3(0, 0.05, 0))
	await tw.finished


func tick(delta: float) -> void:
	if not running:
		return
	var mv := player.read_move_raw()
	_yaw -= mv.x * delta * 0.5
	player.yaw = _yaw
	if _charging:
		_power += _power_dir * delta * 0.55
		if _power >= 1.0 or _power <= 0.0:
			_power_dir *= -1.0
			_power = clampf(_power, 0.0, 1.0)
		hud.set_meter(_power)
		_arc.show_arc(player.global_position + Vector3(0, 1.7, 0), _velocity(_power), 0.05, Color("6be36b") if absf(_power - _ideal) < 0.09 else Color("ffcf3f"))
	player._emit_context()


func _finish() -> void:
	if not running:
		return
	var won := 1 if score >= 14 else (0 if score >= 8 else -1)
	if made >= 10:
		GameManager.unlock_achievement("cestinha")
	end_game(won, "Basquete: %d pontos (%d cestas)" % [score, made], 5 + score, 10 + score * 2, {"score": score})


func cleanup() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	super.cleanup()
