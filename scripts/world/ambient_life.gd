class_name AmbientLife
extends Node3D
## Vida no cenário, barata para o celular: nuvens que passam, pássaros
## voando em círculos, borboletas nos jardins, bandeirinhas no pátio e
## canteiros floridos. Poucas malhas; animação por transformações simples.

const FLAG_COLS := [Color("ff4d6d"), Color("ffd23f"), Color("3ec1ff"), Color("4ee07a"), Color("b46bff"), Color("ff8a3d")]
const FLOWER_COLS := [Color("ff4d6d"), Color("ffd23f"), Color("ffffff"), Color("b46bff"), Color("ff8fc7"), Color("ff8a3d")]

var _clouds: Node3D
var _birds: Array = []  # [node, centro, raio, altura, fase, vel]
var _butterflies: Array = []  # [node, centro, fase]
var _t := 0.0


func build() -> void:
	_build_clouds()
	_build_bunting()
	_build_flowers()
	for i in 7:
		_birds.append([_bird(), Vector3(randf_range(-40, 40), 0, randf_range(-40, 40)), randf_range(14, 30),
			randf_range(16, 26), randf() * TAU, randf_range(0.18, 0.32) * (1 if randf() < 0.5 else -1)])
	var spots := [Vector3(-4, 0, -64), Vector3(0, 0, 58), Vector3(-75, 0, 4), Vector3(9, 0, 57), Vector3(-9, 0, 57), Vector3(-70, 0, -45)]
	for i in 12:
		var c: Vector3 = spots[i % spots.size()] + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		_butterflies.append([_butterfly(FLOWER_COLS[i % FLOWER_COLS.size()]), c, randf() * TAU])


func _mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _build_clouds() -> void:
	_clouds = Node3D.new()
	add_child(_clouds)
	var md := MeshData.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 16:
		var a := rng.randf() * TAU
		var d := rng.randf_range(140, 260)
		var c := Vector3(cos(a) * d, rng.randf_range(55, 85), sin(a) * d)
		for k in rng.randi_range(3, 5):
			var off := Vector3(rng.randf_range(-14, 14), rng.randf_range(-2, 3), rng.randf_range(-7, 7))
			var r := rng.randf_range(7, 13)
			md.cur_color = Color("ffffff").lerp(Color("dbe9f7"), rng.randf() * 0.5)
			md.add_sphere(Transform3D(Basis().scaled(Vector3(1.6, 0.55, 1.0)), c + off), r, 10, 6)
	var mi := MeshInstance3D.new()
	var m := _mat()
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.disable_fog = true
	mi.mesh = md.build_mesh(m)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clouds.add_child(mi)


func _bunting_string(md: MeshData, a: Vector3, b: Vector3, sag: float, seed_k: int) -> void:
	var n := int(a.distance_to(b) / 1.05)
	md.cur_color = Color("f5f5f5")
	for k in n:
		var t := float(k) / n
		var p := a.lerp(b, t) + Vector3(0, -sag * sin(PI * t), 0)
		var dir := (b - a).normalized()
		md.cur_color = FLAG_COLS[(k + seed_k) % FLAG_COLS.size()]
		# triângulo (bandeirinha)
		var w := 0.22
		var i0 := md.add_vertex(p + dir * -w, Vector3.UP)
		var i1 := md.add_vertex(p + dir * w, Vector3.UP)
		var i2 := md.add_vertex(p + Vector3(0, -0.5, 0), Vector3.UP)
		md.tri(i0, i1, i2)
		md.tri(i0, i2, i1)


func _build_bunting() -> void:
	var md := MeshData.new()
	var poles := MeshData.new()
	poles.cur_color = Color("e6eef5")
	var lines := [[Vector3(-30, 5.4, -4), Vector3(30, 5.4, -4)], [Vector3(-30, 5.4, -15), Vector3(30, 5.4, -15)],
		[Vector3(-30, 5.4, -4), Vector3(30, 5.4, -15)], [Vector3(-12, 4.6, 50), Vector3(12, 4.6, 50)]]
	var k := 0
	for l in lines:
		_bunting_string(md, l[0], l[1], 1.1, k)
		k += 2
		for e: Vector3 in l:
			poles.add_cylinder(Transform3D(Basis(), Vector3(e.x, e.y * 0.5, e.z)), 0.06, 0.08, e.y, 8)
			poles.cur_color = Color("3ec1ff")
			poles.add_sphere(Transform3D(Basis(), e + Vector3(0, 0.1, 0)), 0.12, 8, 5)
			poles.cur_color = Color("e6eef5")
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(_mat())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 90.0
	add_child(mi)
	var pm := MeshInstance3D.new()
	pm.mesh = poles.build_mesh(SchoolMaterials.get_mat("plain"))
	pm.visibility_range_end = 120.0
	add_child(pm)


func _build_flowers() -> void:
	# tufos de flores coloridas ao redor da praça, entrada e jardins
	var md := MeshData.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var beds := [[Vector3(0, 0.42, 58), 5.6, 34], [Vector3(-75, 0.05, 4), 3.0, 16], [Vector3(-22, 0.05, 66), 2.6, 14],
		[Vector3(22, 0.05, 66), 2.6, 14], [Vector3(-60, 0.05, 20), 2.4, 10], [Vector3(58, 0.05, 20), 2.4, 10]]
	for b in beds:
		var c: Vector3 = b[0]
		for i in int(b[2]):
			var a := rng.randf() * TAU
			var r: float = b[1] if c.y > 0.3 else rng.randf() * b[1]
			var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
			md.cur_color = Color("2f9e44").lerp(Color("5cc85a"), rng.randf())
			md.add_sphere(Transform3D(Basis().scaled(Vector3(1, 0.7, 1)), p + Vector3(0, 0.12, 0)), 0.22, 7, 4)
			md.cur_color = FLOWER_COLS[rng.randi() % FLOWER_COLS.size()]
			for f in 3:
				var fp := p + Vector3(rng.randf_range(-0.15, 0.15), 0.3 + rng.randf() * 0.08, rng.randf_range(-0.15, 0.15))
				md.add_sphere(Transform3D(Basis(), fp), 0.06, 6, 4)
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 60.0
	add_child(mi)


func _bird() -> MeshInstance3D:
	var md := MeshData.new()
	md.cur_color = Color("2b3445")
	for sx: float in [1.0, -1.0]:
		var i0 := md.add_vertex(Vector3(0, 0, 0.12), Vector3.UP)
		var i1 := md.add_vertex(Vector3(0.45 * sx, 0.06, -0.05), Vector3.UP)
		var i2 := md.add_vertex(Vector3(0, 0, -0.15), Vector3.UP)
		md.tri(i0, i1, i2)
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(_mat())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _butterfly(col: Color) -> MeshInstance3D:
	var md := MeshData.new()
	md.cur_color = col
	for sx: float in [1.0, -1.0]:
		var i0 := md.add_vertex(Vector3(0, 0, 0.03), Vector3.UP)
		var i1 := md.add_vertex(Vector3(0.09 * sx, 0, 0.07), Vector3.UP)
		var i2 := md.add_vertex(Vector3(0.08 * sx, 0, -0.06), Vector3.UP)
		md.tri(i0, i1, i2)
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(_mat())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 30.0
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	if _clouds:
		_clouds.rotation.y += delta * 0.004
	for b in _birds:
		var node: MeshInstance3D = b[0]
		var ang: float = b[4] + _t * b[5]
		var c: Vector3 = b[1]
		var p := c + Vector3(cos(ang) * b[2], b[3] + sin(_t * 0.7 + b[4]) * 1.5, sin(ang) * b[2])
		var tangent := Vector3(-sin(ang), 0, cos(ang)) * signf(b[5])
		node.global_position = p
		node.look_at(p + tangent, Vector3.UP)
		node.scale = Vector3(1, 1 + sin(_t * 9.0 + b[4]) * 2.2, 1)
	for f in _butterflies:
		var node: MeshInstance3D = f[0]
		var ph: float = f[2]
		var c: Vector3 = f[1]
		var p := c + Vector3(sin(_t * 0.9 + ph) * 1.6, 0.7 + sin(_t * 2.3 + ph) * 0.35, sin(_t * 0.6 + ph * 2.0) * 1.3)
		node.global_position = p + Vector3(0, c.y, 0)
		node.rotation.y = _t * 0.9 + ph
		node.rotation.z = 0.0
		node.scale = Vector3(absf(sin(_t * 14.0 + ph)) * 0.9 + 0.1, 1, 1)
