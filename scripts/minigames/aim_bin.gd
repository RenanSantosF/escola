extends Minigame
## Pontaria: acertar bolinhas de papel nas lixeiras de coleta seletiva.
## 10 bolinhas; mira com o joystick, força com o botão amarelo (toque
## para carregar, toque de novo para arremessar). Cada lixeira vale pontos.

const BIN_Z := -24.0
const BINS := [Vector3(23.4, 0.0, -24.0), Vector3(23.8, 0.0, -24.0), Vector3(24.2, 0.0, -24.0), Vector3(24.6, 0.0, -24.0)]
const BIN_POINTS := [10, 20, 30, 50]
const BIN_NAMES := ["papel", "plástico", "vidro", "metal"]
const FROM := Vector3(24, 0.05, -17.5)

var balls_left := 10
var score := 0
var _yaw := PI
var _power := 0.0
var _power_dir := 1.0
var _charging := false
var _flying: Array = []  # {node, pos, vel, done}
var _root: Node3D


func begin() -> void:
	_root = Node3D.new()
	world.add_child(_root)
	player.force_stand()
	player.global_position = FROM
	player.yaw = PI
	player.movement_locked = true
	if player.camera_rig:
		player.camera_rig.set_override(Transform3D(Basis(), FROM + Vector3(0.9, 2.2, 2.6)).looking_at(Vector3(24, 0.6, -24), Vector3.UP))
	super.begin()
	_update_hud()


func _update_hud() -> void:
	hud.set_minigame_text("Pontaria  ·  %d pontos  ·  %d bolinhas  ·  azul=10 verm.=20 verde=30 amarela=50" % [score, balls_left])


func play_label() -> String:
	return "Arremessar!" if _charging else "Força"


func interact_label() -> String:
	return "Sair"


func on_interact() -> bool:
	_finish()
	return true


func on_play() -> bool:
	if balls_left <= 0:
		return true
	if not _charging:
		_charging = true
		_power = 0.0
	else:
		_charging = false
		hud.set_meter(-1.0)
		_throw()
	return true


func _throw() -> void:
	balls_left -= 1
	player.visual.play("throw")
	var dir := Vector3(sin(_yaw), 0, cos(_yaw))
	var speed := lerpf(4.0, 10.0, _power)
	var vel := dir * speed * 0.8 + Vector3(0, speed * 0.6, 0)
	var md := MeshData.new()
	md.cur_color = Color("f4f1e8")
	md.add_sphere(Transform3D(), 0.06, 8, 6)
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	_root.add_child(mi)
	var start := FROM + Vector3(0, 1.5, 0) + dir * 0.3
	mi.global_position = start
	get_tree().create_timer(0.4).timeout.connect(func():
		_flying.append({"node": mi, "pos": start, "vel": vel, "done": false}))
	_update_hud()


func tick(delta: float) -> void:
	if not running:
		return
	var mv := player.read_move_raw()
	_yaw -= mv.x * delta * 0.7
	_yaw = clampf(_yaw, PI - 0.6, PI + 0.6)
	player.yaw = _yaw
	if _charging:
		_power += _power_dir * delta * 0.85
		if _power >= 1.0 or _power <= 0.0:
			_power_dir *= -1.0
			_power = clampf(_power, 0.0, 1.0)
		hud.set_meter(_power)
	for f in _flying:
		if f.done:
			continue
		var prev: Vector3 = f.pos
		f.vel += Vector3(0, -9.8, 0) * delta
		f.pos += f.vel * delta
		f.node.global_position = f.pos
		# entrou numa lixeira? (topo a 0.75 m, raio 0.17)
		if prev.y > 0.75 and f.pos.y <= 0.75:
			for k in BINS.size():
				if Vector2(f.pos.x - BINS[k].x, f.pos.z - BINS[k].z).length() < 0.17:
					f.done = true
					score += BIN_POINTS[k]
					AudioManager.play_ui("ui_confirm", -4.0)
					GameManager.show_toast("Cesta no lixo de %s! +%d" % [BIN_NAMES[k], BIN_POINTS[k]])
					f.node.visible = false
		if f.pos.y < 0.04:
			f.done = true
	_update_hud()
	player._emit_context()
	if balls_left <= 0 and _flying.all(func(f): return f.done):
		_finish()


func _finish() -> void:
	if not running:
		return
	var won := 1 if score >= 100 else (0 if score >= 40 else -1)
	if score >= 200:
		GameManager.unlock_achievement("mira_certeira")
	end_game(won, "Pontaria: %d pontos" % score, 4 + score / 12, 8 + score / 6, {"score": score})


func cleanup() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	super.cleanup()
