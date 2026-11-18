class_name RideTrack
extends Interactable
## Atração sobre trilho: tobogã gigante (sobe pelo elevador e escorrega) ou
## montanha-russa (carrinho com subida na corrente e duas voltas).
## A velocidade vem da altura (energia): desce rápido, sobe devagar.

const G := 9.8

var kind := "slide"
var points: PackedVector3Array = []
var laps := 1
var lift := Vector2(-1, -1)  # trecho com corrente (fração da volta)
var lift_top := Vector3.ZERO  # tobogã: topo da torre
## Tobogã: elevador de verdade no meio da torre (cabine de vidro que sobe).
var elevator := Vector3.INF  # base do poço (chão)
var elevator_top := 0.0      # altura do piso lá em cima
var _cabin: Node3D
var _cabin_y := 0.0
var _pad: MeshInstance3D

var _rider: PlayerController = null
var _cum: PackedFloat32Array = []
var _total := 0.0
var _s := 0.0
var _v := 0.0
var _lap := 0
var _phase := ""  # "lift_up" | "ride"
var _t := 0.0
var _from := Vector3.ZERO
var _cart: Node3D = null
var _shouted := false
var _wind: AudioStreamPlayer
var _clack_d := 0.0


func _ready() -> void:
	super._ready()
	interact_radius = 2.2
	process_physics_priority = 100  # depois do jogador: a posição do trilho vence
	set_physics_process(false)
	_cum.resize(points.size())
	var acc := 0.0
	for i in points.size():
		if i > 0:
			acc += points[i - 1].distance_to(points[i])
		_cum[i] = acc
	_total = acc
	_wind = AudioStreamPlayer.new()
	_wind.bus = "SFX"
	_wind.stream = AudioManager.get_stream("wind")
	if _wind.stream is AudioStreamWAV:
		var w := _wind.stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = int(w.get_length() * w.mix_rate)
	_wind.volume_db = -80.0
	add_child(_wind)
	if kind == "coaster":
		_cart = _make_cart()
		add_child(_cart)
		_cart.top_level = true
		_place_cart(0.0)
	if kind == "slide" and elevator != Vector3.INF:
		_build_elevator()
		set_process(true)


## Cabine colorida com vidro e luz no teto + marca no chão da porta.
func _build_elevator() -> void:
	_cabin = Node3D.new()
	_cabin.name = "Elevador"
	_cabin.top_level = true
	add_child(_cabin)
	var md := MeshData.new()
	md.cur_color = Color("ffd23f")
	for sx in [-0.68, 0.68]:
		for sz in [-0.68, 0.68]:
			md.add_box(Transform3D(Basis(), Vector3(sx, 1.15, sz)), Vector3(0.1, 2.3, 0.1))
	md.cur_color = Color("ff4d6d")
	md.add_box(Transform3D(Basis(), Vector3(0, 2.32, 0)), Vector3(1.5, 0.1, 1.5))
	md.cur_color = Color("dfe6ee")
	md.add_box(Transform3D(Basis(), Vector3(0, 0.03, 0)), Vector3(1.46, 0.06, 1.46))
	md.cur_color = Color("8a96a3")
	md.add_box(Transform3D(Basis(), Vector3(0, 1.0, -0.66)), Vector3(1.3, 0.06, 0.04))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.5
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(mat)
	_cabin.add_child(mi)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.85, 1.0, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [[Vector3(0, 1.15, -0.7), Vector3(1.36, 2.2, 0.02)], [Vector3(-0.7, 1.15, 0), Vector3(0.02, 2.2, 1.36)], [Vector3(0.7, 1.15, 0), Vector3(0.02, 2.2, 1.36)]]:
		var g := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = side[1]
		g.mesh = bm
		g.material_override = glass
		g.position = side[0]
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cabin.add_child(g)
	var light := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.12
	light.mesh = sm
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("fff3b0")
	lm.emission_enabled = true
	lm.emission = Color("ffe680")
	light.material_override = lm
	light.position = Vector3(0, 2.25, 0)
	_cabin.add_child(light)
	_cabin.global_position = elevator
	_cabin_y = 0.0
	# marca piscando no chão da porta: "entre aqui"
	_pad = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.75
	tm.outer_radius = 0.95
	tm.rings = 24
	tm.ring_segments = 6
	_pad.mesh = tm
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color(1.0, 0.85, 0.2, 0.8)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pad.material_override = pm
	_pad.scale = Vector3(1, 0.15, 1)
	_pad.top_level = true
	add_child(_pad)
	_pad.global_position = global_position + Vector3(0, 0.22, 0)


var _pad_t := 0.0


func _process(delta: float) -> void:
	if _pad == null:
		return
	_pad_t += delta
	var k := 0.5 + 0.5 * sin(_pad_t * 4.0)
	_pad.visible = _rider == null
	(_pad.material_override as StandardMaterial3D).albedo_color.a = 0.35 + 0.5 * k
	_pad.scale = Vector3(1.0 + 0.08 * k, 0.15, 1.0 + 0.08 * k)
	# sem ninguém: a cabine desce sozinha e espera na porta
	if _rider == null and _cabin and _cabin_y > 0.0:
		_cabin_y = maxf(_cabin_y - delta * 4.0, 0.0)
		_cabin.global_position = elevator + Vector3(0, _cabin_y, 0)


func can_interact(_player: Node) -> bool:
	return _rider == null and points.size() > 2


func interact(player: Node) -> void:
	var p := player as PlayerController
	if p == null or _rider != null or p.mode != PlayerController.Mode.FREE or p.riding or p.minigame != null:
		return
	if p.held_item:
		return
	_rider = p
	p.set_meta("ride", kind)  # os colegas online veem sentado no brinquedo
	p.input_enabled = false
	p.movement_locked = true
	p.velocity = Vector3.ZERO
	_s = 0.0
	_v = 2.0
	_lap = 0
	_shouted = false
	if kind == "slide":
		_phase = "lift_up"
		_t = 0.0
		_from = p.global_position
		p.visual.play("wave")
		AudioManager.play_3d("whoosh", global_position, -6.0)
	else:
		_phase = "ride"
		p.visual.play("sit_down")
		AudioManager.play_3d("ui_confirm", global_position, -4.0)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var p := _rider
	if p == null or not is_instance_valid(p):
		_end(false)
		return
	p.velocity = Vector3.ZERO
	if _phase == "lift_up":
		if _cabin:
			_elevator_step(p, delta)
			return
		# (sem cabine) sobe direto
		_t += delta / 3.0
		var f := smoothstep(0.0, 1.0, minf(_t, 1.0))
		var mid := Vector3(lift_top.x, _from.y, lift_top.z)
		var pos := _from.lerp(mid, minf(f * 3.0, 1.0)) if f < 0.33 else mid.lerp(lift_top, (f - 0.33) / 0.67)
		p.global_position = pos
		if _t >= 1.0:
			_phase = "ride"
			_v = 3.0
			p.visual.play("sit_down")
			AudioManager.play_3d("whoosh", lift_top, -2.0)
		return
	# energia: a altura vira velocidade (com atrito)
	var dir := _dir_at(_s)
	var on_lift := false
	if lift.x >= 0.0:
		var u := _s / _total
		on_lift = u >= lift.x and u <= lift.y
	if on_lift:
		_v = move_toward(_v, 5.0, delta * 4.0)
	else:
		_v += -G * dir.y * delta * (1.0 if kind == "coaster" else 0.95)
		_v -= _v * (0.03 if kind == "coaster" else 0.035) * delta
		_v = clampf(_v, 4.0 if kind == "coaster" else 4.5, 26.0 if kind == "coaster" else 17.0)
	if _v > 13.0 and not _shouted:
		_shouted = true
		GameManager.show_toast("Uhuuul!")
	elif _v < 6.0:
		_shouted = false
	_s += _v * delta
	# som: vento cresce com a velocidade; na corrente, clec-clec
	if _wind and _wind.stream:
		if not _wind.playing:
			_wind.play()
		_wind.volume_db = lerpf(-30.0, -2.0, clampf((_v - 3.0) / 16.0, 0.0, 1.0))
		_wind.pitch_scale = lerpf(0.8, 1.6, clampf(_v / 22.0, 0.0, 1.0))
	if on_lift:
		_clack_d += _v * delta
		if _clack_d > 0.6:
			_clack_d = 0.0
			AudioManager.play_ui("clack", -8.0, 0.05)
	if _s >= _total:
		_lap += 1
		if _lap >= laps:
			_s = _total
			_place(p)
			_end(true)
			return
		_s -= _total
	_place(p)


## Elevador: entra na cabine (0,7 s), sobe (5 s, com "plim"), sai na
## plataforma lá em cima e vai até a boca do tobogã.
const ELEV_IN := 0.7
const ELEV_UP := 5.0
const ELEV_OUT := 0.9


func _elevator_step(p: PlayerController, delta: float) -> void:
	_t += delta
	var h := elevator_top - elevator.y
	if _t < ELEV_IN:
		var f := _t / ELEV_IN
		p.global_position = _from.lerp(elevator + Vector3(0, 0.08, 0), f)
		var to := elevator - _from
		p.yaw = atan2(to.x, to.z)
		p.visual.rotation.y = p.yaw
		_cabin_y = 0.0
	elif _t < ELEV_IN + ELEV_UP:
		var f2 := smoothstep(0.0, 1.0, (_t - ELEV_IN) / ELEV_UP)
		_cabin_y = f2 * h
		p.global_position = elevator + Vector3(0, _cabin_y + 0.08, 0)
		if not _shouted and f2 > 0.02:
			_shouted = true
			AudioManager.play_ui("ui_confirm", -8.0)
			if p.camera_rig:
				p.camera_rig.distance = 6.5
	elif _t < ELEV_IN + ELEV_UP + ELEV_OUT:
		var f3 := (_t - ELEV_IN - ELEV_UP) / ELEV_OUT
		_cabin_y = h
		var top_floor := elevator + Vector3(0, h + 0.08, 0)
		p.global_position = top_floor.lerp(lift_top, f3)
		var to2 := lift_top - top_floor
		p.yaw = atan2(to2.x, to2.z)
		p.visual.rotation.y = p.yaw
	else:
		_shouted = false
		_phase = "ride"
		_v = 3.0
		p.visual.play("sit_down")
		AudioManager.play_ui("reward", -6.0)
		AudioManager.play_3d("whoosh", lift_top, -2.0)
	_cabin.global_position = elevator + Vector3(0, _cabin_y, 0)


func _dir_at(s: float) -> Vector3:
	var i := _index_at(s)
	return (points[mini(i + 1, points.size() - 1)] - points[i]).normalized()


func _index_at(s: float) -> int:
	# busca binária no comprimento acumulado
	var lo := 0
	var hi := _cum.size() - 1
	while hi - lo > 1:
		var m := (lo + hi) >> 1
		if _cum[m] <= s:
			lo = m
		else:
			hi = m
	return lo


func _pos_at(s: float) -> Vector3:
	var i := _index_at(s)
	var j := mini(i + 1, points.size() - 1)
	var seg := maxf(_cum[j] - _cum[i], 0.001)
	return points[i].lerp(points[j], clampf((s - _cum[i]) / seg, 0.0, 1.0))


func _place(p: PlayerController) -> void:
	var pos := _pos_at(_s)
	var dir := _dir_at(_s)
	p.yaw = atan2(dir.x, dir.z)
	p.visual.rotation.y = p.yaw
	if kind == "coaster":
		_place_cart(_s)
		p.global_position = pos + Vector3(0, 0.12, 0)
	else:
		p.global_position = pos + Vector3(0, 0.05, 0)


func _place_cart(s: float) -> void:
	if _cart == null or points.size() < 2:
		return
	var pos := _pos_at(s)
	var dir := _dir_at(s)
	_cart.global_position = pos
	if dir.length() > 0.01:
		var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
		_cart.global_basis = Basis.looking_at(dir, up)


func _end(ok: bool) -> void:
	set_physics_process(false)
	if _wind:
		_wind.stop()
	var p := _rider
	_rider = null
	if kind == "coaster":
		_s = 0.0
		_place_cart(0.0)
	if p == null or not is_instance_valid(p):
		return
	p.remove_meta("ride")
	p.visual.stop_action()
	if kind == "slide" and p.camera_rig:
		p.camera_rig.distance = 4.6
	if ok:
		# desembarque: tobogã no fim do tubo, montanha-russa na plataforma
		if kind == "coaster":
			p.global_position = global_position + Vector3(0, 0.1, 0.6)
		else:
			var end := points[points.size() - 1]
			var dir := _dir_at(_total - 0.5)
			p.global_position = end + Vector3(dir.x, 0, dir.z).normalized() * 1.2 + Vector3(0, 0.2, 0)
		p.visual.play("celebrate")
		Effects.burst(p.global_position + Vector3(0, 1.0, 0), "confetti" if kind == "coaster" else "dust")
		GameManager.add_stat("escorregadas" if kind == "slide" else "montanha_russa")
		if kind == "slide" and int(SaveManager.section("stats").get("escorregadas", 0)) >= 10:
			GameManager.unlock_achievement("escorrega_10")
	p.input_enabled = true
	p.movement_locked = false


## Libera o jogador se algo (aula, castigo) precisar dele no meio do passeio.
func eject() -> void:
	if _rider != null:
		_end(false)


func _make_cart() -> Node3D:
	return make_cart()


## Carrinho (também usado para mostrar o carrinho de um colega online).
static func make_cart() -> Node3D:
	var root := Node3D.new()
	root.name = "Carrinho"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffd23f")
	mat.roughness = 0.5
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("e53935")
	red.roughness = 0.4
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 0.45, 1.5)
	body.mesh = bm
	body.material_override = red
	body.position = Vector3(0, 0.3, 0)
	root.add_child(body)
	var front := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.96, 0.5, 0.25)
	front.mesh = fm
	front.material_override = mat
	front.position = Vector3(0, 0.55, -0.7)
	root.add_child(front)
	var back := MeshInstance3D.new()
	back.mesh = fm
	back.material_override = mat
	back.position = Vector3(0, 0.6, 0.65)
	root.add_child(back)
	for m in [body, front, back]:
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
