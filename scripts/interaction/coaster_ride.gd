class_name CoasterRide
extends Interactable
## Montanha-russa com TREM de 4 carrinhos (16 lugares) e FILA.
## O trem segue um horário: fica parado na estação EMBARQUE segundos e
## depois faz a viagem (sempre igual, CoasterTrack.ride_table). O horário
## vem do relógio do servidor quando online — todo mundo vê o MESMO trem
## e quem chega com ele andando entra na fila e vai na próxima remessa.
## Andando: botão "1ª pessoa" troca a câmera (vê o looping de dentro!).

const BOARD := 16.0         # segundos parado na estação
const UNLOAD := 2.0
const CARS := 4
const SPACING := 2.7        # distância entre carrinhos
const SEATS_PER_CAR := 4
const CAR_COLORS := [Color("e53935"), Color("2f80ed"), Color("ffb300"), Color("27ae60")]

var cars: Array[Node3D] = []
var riding := false
var queued := false
var seat := -1
var first_person := true
## Olhar em volta (arrastando o dedo na tela): giro e inclinação da câmera.
var _look_yaw := 0.0
var _look_pitch := 0.0
var _drag_t := 0.0
var _player: PlayerController
var _cam_btn: Button
var _cam_xf := Transform3D()
var _was_board := true
var _queue_spot := Vector3.ZERO
var _yay := false
var _local_offset := 0.0  # sozinho: o relógio local começa com o trem chegando


func _ready() -> void:
	super._ready()
	add_to_group("coaster_ride")
	interact_radius = 3.4
	prompt = "Montanha-russa"
	CoasterTrack.ride_table()
	for i in CARS:
		var car := make_car(CAR_COLORS[i % CAR_COLORS.size()], i == 0)
		car.top_level = true
		add_child(car)
		cars.append(car)
	_local_offset = -Time.get_ticks_msec() / 1000.0 + BOARD * 0.25
	set_process(true)


## Carrinho bonito: corpo arredondado com faixas, banco preto, trava de
## segurança amarela, rodinhas nos truques; o da frente tem bico e farol.
static func make_car(col: Color, front: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Carrinho"
	var md := MeshData.new()
	var dark := col.darkened(0.3)
	md.cur_color = Color("2c3e50")
	md.add_box(Transform3D(Basis(), Vector3(0, 0.27, 0)), Vector3(1.3, 0.1, 2.3))
	md.cur_color = col
	md.add_box(Transform3D(Basis(), Vector3(0, 0.48, 0)), Vector3(1.32, 0.36, 2.25))
	md.cur_color = Color.WHITE
	for sx in [-1.0, 1.0]:
		md.add_box(Transform3D(Basis(), Vector3(sx * 0.665, 0.52, 0)), Vector3(0.02, 0.07, 2.1))
	md.cur_color = dark
	md.add_box(Transform3D(Basis(), Vector3(0, 0.72, 1.08)), Vector3(1.32, 0.2, 0.12))
	md.add_box(Transform3D(Basis(), Vector3(0, 0.72, -0.05)), Vector3(1.32, 0.16, 0.1))
	# bancos (2 fileiras x 2) com encosto alto
	for row_z in [0.45, -0.6]:
		md.cur_color = Color("1d1d1d")
		md.add_box(Transform3D(Basis(), Vector3(0, 0.62, row_z)), Vector3(1.1, 0.1, 0.5))
		md.add_box(Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, 0.95, row_z - 0.27)), Vector3(1.1, 0.62, 0.1))
		# trava de segurança
		md.cur_color = Color("ffd23f")
		for sx in [-0.36, 0.36]:
			md.add_box(Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(sx, 0.98, row_z + 0.18)), Vector3(0.06, 0.06, 0.4))
	if front:
		md.cur_color = col
		md.add_box(Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.58, 1.32)), Vector3(1.2, 0.3, 0.55))
		md.cur_color = Color("fff3b0")
		for sx in [-0.4, 0.4]:
			md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx, 0.55, 1.58)), 0.09, 0.09, 0.04, 10)
		md.cur_color = Color.WHITE
		md.add_box(Transform3D(Basis(), Vector3(0, 0.68, 1.44)), Vector3(0.5, 0.18, 0.02))
	# rodinhas (embaixo, presas no trilho)
	md.cur_color = Color("4a4f57")
	for z in [0.75, -0.75]:
		for sx in [-0.48, 0.48]:
			md.add_box(Transform3D(Basis(), Vector3(sx, 0.08, z)), Vector3(0.16, 0.22, 0.3))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.35
	mat.metallic = 0.15
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(mat)
	root.add_child(mi)
	return root


# ------------------------------------------------------------------ horário

func cycle() -> float:
	return BOARD + CoasterTrack.ride_time + UNLOAD


func _now() -> float:
	if NetworkManager.is_online() and not NetworkManager.clock.is_empty():
		return NetworkManager.server_now_ms() / 1000.0
	return Time.get_ticks_msec() / 1000.0 + _local_offset


## {board: parado na estação?, left: segundos para sair/voltar, tau: tempo de viagem}
func state() -> Dictionary:
	var t := fposmod(_now(), cycle())
	if t < BOARD:
		return {"board": true, "left": BOARD - t, "tau": 0.0}
	var tau := t - BOARD
	return {"board": false, "left": cycle() - t, "tau": minf(tau, CoasterTrack.ride_time)}


## Distância do ÚLTIMO carrinho ao longo do trilho.
func train_s() -> float:
	var st := state()
	if st.board:
		return 0.0
	return CoasterTrack.s_at_time(st.tau)


func car_xf(i: int) -> Transform3D:
	var s := train_s() + (CARS - 1 - i) * SPACING
	var f := CoasterTrack.frame_at(s)
	return Transform3D(f.basis, f.origin + f.basis.y * 0.18)


## Lugar k: carrinho k/4, fileira e lado.
func seat_xf(k: int) -> Transform3D:
	var car := k / SEATS_PER_CAR
	var r := k % SEATS_PER_CAR
	var local := Vector3(-0.3 if r % 2 == 0 else 0.3, 0.17, 0.42 if r < 2 else -0.62)
	var xf := car_xf(car)
	return Transform3D(xf.basis, xf * local)


# ------------------------------------------------------------------ interação

func interact_point() -> Vector3:
	return global_position


func can_interact(p: Node) -> bool:
	return not riding and (p as PlayerController).mode == PlayerController.Mode.FREE and (p as PlayerController).minigame == null


func get_prompt(_p: Node) -> String:
	var st := state()
	if queued:
		return "Sair da fila"
	if st.board:
		return "Entrar no trem! (sai em %ds)" % ceili(st.left)
	return "Entrar na fila (próximo trem em %ds)" % ceili(st.left + 0.0)


func interact(p: Node) -> void:
	_player = p as PlayerController
	if _player == null or riding:
		return
	if queued:
		_leave_queue("Você saiu da fila.")
		return
	if state().board:
		_board()
	else:
		_join_queue()


func _join_queue() -> void:
	queued = true
	var q: Dictionary = _coaster_info()
	_queue_spot = q.get("queue", global_position + Vector3(4, 0, 4)) + Vector3(-1.5, 0.05, 0.6)
	_player.global_position = _queue_spot
	_player.velocity = Vector3.ZERO
	_player.yaw = PI * 0.5
	GameManager.show_toast("Você está na FILA. O trem que está andando volta já: você vai no próximo!")


func _coaster_info() -> Dictionary:
	var w := get_parent()
	if w and w.get("builder"):
		return w.builder.coaster
	return {}


func _leave_queue(msg: String) -> void:
	queued = false
	if msg != "":
		GameManager.show_toast(msg)


func _pick_seat() -> int:
	if NetworkManager.is_online() and NetworkManager.my_id != "":
		return absi(hash(NetworkManager.my_id)) % (CARS * SEATS_PER_CAR)
	return 1  # sozinho: primeiro carrinho, para ver a pista na frente


func _board() -> void:
	queued = false
	riding = true
	_was_board = true  # embarcou agora: não confundir com a chegada
	seat = _pick_seat()
	var p := _player
	if p.riding:
		p.toggle_ride()
	p.set_meta("ride", "coaster")
	p.input_enabled = false
	p.movement_locked = true
	p.collision_mask = 0
	p.velocity = Vector3.ZERO
	p.visual.play("sit_down")
	_yay = false
	first_person = true  # começa em 1ª pessoa (como se estivesse sentado no carrinho)
	_look_yaw = 0.0
	_look_pitch = 0.0
	_add_cam_button()
	_cam_xf = _first_xf()
	if p.camera_rig:
		p.camera_rig.set_override(_cam_xf)
	AudioManager.play_ui("ui_confirm", -4.0)
	GameManager.show_toast("Trava fechada! O trem sai em %ds. Arraste o dedo para olhar em volta." % ceili(state().left))


func _unload() -> void:
	riding = false
	var p := _player
	if p == null or not is_instance_valid(p):
		return
	_remove_cam_button()
	p.remove_meta("ride")
	p.visual.stop_action()
	p.visual.transform = Transform3D(Basis(Vector3.UP, p.yaw), Vector3.ZERO)
	p.collision_mask = 1 | 4 | 8
	p.input_enabled = true
	p.movement_locked = false
	if p.camera_rig:
		p.camera_rig.set_override(null)
		p.camera_rig.override_cam.fov = 70.0
	var q: Dictionary = _coaster_info()
	p.global_position = q.get("platform", global_position) + Vector3(0, 0.1, 0.8)
	p.velocity = Vector3.ZERO
	p.visual.play("celebrate")
	Effects.burst(p.global_position + Vector3(0, 1.0, 0), "confetti")
	GameManager.add_stat("montanha_russa")


## Libera o jogador se algo (aula, castigo) precisar dele no meio do passeio.
func eject() -> void:
	queued = false
	if riding:
		_unload()


# ------------------------------------------------------------------ câmera

func _add_cam_button() -> void:
	var hud := get_tree().get_first_node_in_group("hud") as Control
	if hud == null:
		return
	_cam_btn = UITheme.make_button("Ver de fora", func():
		first_person = not first_person
		_look_yaw = 0.0
		_look_pitch = 0.0
		_cam_btn.text = "Ver de fora" if first_person else "Ver em 1ª pessoa", 300)
	_cam_btn.focus_mode = Control.FOCUS_NONE
	_cam_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_cam_btn.position = Vector2(hud.size.x * 0.5 - 150, hud.size.y - 110)
	_cam_btn.z_index = 20
	hud.add_child(_cam_btn)


func _remove_cam_button() -> void:
	if is_instance_valid(_cam_btn):
		_cam_btn.queue_free()
	_cam_btn = null


## Arrastar na tela gira a câmera (1ª pessoa: olha em volta; de fora: dá a volta no trem).
func _unhandled_input(event: InputEvent) -> void:
	if not riding:
		return
	var rel := Vector2.ZERO
	if event is InputEventScreenDrag:
		rel = (event as InputEventScreenDrag).relative
	elif event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		rel = (event as InputEventMouseMotion).relative
	if rel == Vector2.ZERO:
		return
	_look_yaw = _look_yaw - rel.x * 0.006
	if first_person:
		_look_yaw = clampf(_look_yaw, -2.6, 2.6)
	_look_pitch = clampf(_look_pitch - rel.y * 0.005, -1.0, 0.9)
	_drag_t = 2.0


func _first_xf() -> Transform3D:
	var sx := seat_xf(seat)
	var up := sx.basis.y.normalized()
	var eye := sx * Vector3(0, 1.15, 0.12)
	var fwd := sx.basis.z.normalized().rotated(up, _look_yaw)
	var right := fwd.cross(up).normalized()
	fwd = fwd.rotated(right, -_look_pitch)
	return Transform3D(Basis(), eye).looking_at(eye + fwd * 6.0, up)


func _third_xf() -> Transform3D:
	var c0 := car_xf(0)
	var fwd := c0.basis.z
	var flat := Vector3(fwd.x, 0, fwd.z)
	if flat.length() < 0.2:
		flat = Vector3(0, 0, 1)
	flat = flat.normalized().rotated(Vector3.UP, _look_yaw)
	var mid := car_xf(1).origin
	var eye := mid - flat * 9.0 + Vector3.UP * (4.5 + _look_pitch * 4.0)
	# nunca embaixo da terra nem do trilho
	eye.y = maxf(eye.y, maxf(ParkHill.height(eye.x, eye.z), 0.0) + 1.5)
	return Transform3D(Basis(), eye).looking_at(mid + Vector3.UP * 0.5, Vector3.UP)


# ------------------------------------------------------------------ quadro a quadro

func _process(delta: float) -> void:
	for i in CARS:
		cars[i].global_transform = car_xf(i)
	var st := state()
	var board_now: bool = st.board
	if queued and _player and is_instance_valid(_player):
		if _player.global_position.distance_to(_queue_spot) > 5.0:
			_leave_queue("Você saiu da fila.")
		elif board_now:
			_board()
	if riding and _player and is_instance_valid(_player):
		var p := _player
		var sx := seat_xf(seat)
		p.global_position = sx.origin
		p.velocity = Vector3.ZERO
		p.visual.global_transform = sx
		if not board_now and not _yay and st.tau > CoasterTrack.lift.y / CoasterTrack.LIFT_V * 0.9:
			pass
		var v := CoasterTrack.speed_at_time(st.tau) if not board_now else 0.0
		if v > 18.0 and not _yay:
			_yay = true
			GameManager.show_toast("UHUUUUL!")
		elif v < 8.0:
			_yay = false
		# soltou o dedo: a câmera volta devagar para a frente
		_drag_t -= delta
		if _drag_t <= 0.0 and first_person:
			_look_yaw = move_toward(_look_yaw, 0.0, delta * 1.2)
			_look_pitch = move_toward(_look_pitch, 0.0, delta * 0.8)
		if p.camera_rig:
			var want := _first_xf() if first_person else _third_xf()
			var k := 1.0 - exp(-(30.0 if first_person else 6.0) * delta)
			_cam_xf = Transform3D(_cam_xf.basis.slerp(want.basis, k).orthonormalized(), _cam_xf.origin.lerp(want.origin, k))
			if first_person:
				_cam_xf = want
			p.camera_rig.override_snap = true
			p.camera_rig.set_override(_cam_xf)
			p.camera_rig.override_cam.global_transform = _cam_xf
			p.camera_rig.override_cam.fov = lerpf(p.camera_rig.override_cam.fov, 72.0 + clampf(v - 10.0, 0.0, 20.0) * 0.6, k)
		# a viagem acabou: o trem chegou e começa o próximo embarque
		if board_now and not _was_board:
			_unload()
	_was_board = board_now
