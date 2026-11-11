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
	if kind == "coaster":
		_cart = _make_cart()
		add_child(_cart)
		_cart.top_level = true
		_place_cart(0.0)


func can_interact(_player: Node) -> bool:
	return _rider == null and points.size() > 2


func interact(player: Node) -> void:
	var p := player as PlayerController
	if p == null or _rider != null or p.mode != PlayerController.Mode.FREE or p.riding or p.minigame != null:
		return
	if p.held_item:
		return
	_rider = p
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
		# elevador da torre
		_t += delta / 2.6
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
		_v = move_toward(_v, 3.6, delta * 4.0)
	else:
		_v += -G * dir.y * delta * (0.92 if kind == "coaster" else 0.75)
		_v -= _v * (0.04 if kind == "coaster" else 0.12) * delta
		_v = clampf(_v, 3.2 if kind == "coaster" else 2.6, 17.0 if kind == "coaster" else 11.0)
	if _v > 11.0 and not _shouted:
		_shouted = true
		GameManager.show_toast("Uhuuul!")
	elif _v < 6.0:
		_shouted = false
	_s += _v * delta
	if _s >= _total:
		_lap += 1
		if _lap >= laps:
			_s = _total
			_place(p)
			_end(true)
			return
		_s -= _total
	_place(p)


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
	var p := _rider
	_rider = null
	if kind == "coaster":
		_s = 0.0
		_place_cart(0.0)
	if p == null or not is_instance_valid(p):
		return
	p.visual.stop_action()
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
