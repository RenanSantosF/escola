class_name MeshData
extends RefCounted
## Acumulador de geometria procedural.
## Usado tanto pelos personagens (com ossos/pesos) quanto pelo cenário
## (com UV em escala de mundo). Junta muitas peças em uma única malha,
## reduzindo drasticamente as draw calls no celular.

var v := PackedVector3Array()
var n := PackedVector3Array()
var c := PackedColorArray()
var uv := PackedVector2Array()
var bones := PackedInt32Array()
var weights := PackedFloat32Array()
var idx := PackedInt32Array()

var use_uv := false
var use_bones := false
var cur_bone := 0
var cur_color := Color.WHITE
## Metros de mundo por repetição de textura.
var uv_scale := 2.0


func is_empty() -> bool:
	return v.is_empty()


func vertex_count() -> int:
	return v.size()


func add_vertex(p: Vector3, nn: Vector3) -> int:
	v.append(p)
	n.append(nn)
	c.append(cur_color)
	if use_bones:
		bones.append_array([cur_bone, 0, 0, 0])
		weights.append_array([1.0, 0.0, 0.0, 0.0])
	if use_uv:
		uv.append(_world_uv(p, nn))
	return v.size() - 1


func _world_uv(p: Vector3, nn: Vector3) -> Vector2:
	var a := nn.abs()
	var res: Vector2
	if a.y >= a.x and a.y >= a.z:
		res = Vector2(p.x, p.z)
	elif a.x >= a.z:
		res = Vector2(p.z, -p.y)
	else:
		res = Vector2(p.x, -p.y)
	return res / uv_scale


## Adiciona um triângulo garantindo a orientação correta (face frontal
## apontando para o lado das normais), independente da ordem recebida.
func tri(i0: int, i1: int, i2: int) -> void:
	var fn := (v[i1] - v[i0]).cross(v[i2] - v[i0])
	var vn := n[i0] + n[i1] + n[i2]
	# Godot usa ordem horária para faces frontais.
	if fn.dot(vn) > 0.0:
		idx.append_array([i0, i2, i1])
	else:
		idx.append_array([i0, i1, i2])


func quad(a: int, b: int, cc: int, d: int) -> void:
	tri(a, b, cc)
	tri(a, cc, d)


static func _xn(xf: Transform3D, nn: Vector3) -> Vector3:
	return (xf.basis.inverse().transposed() * nn).normalized()


# ------------------------------------------------------------------ primitivas

func add_box(xf: Transform3D, size: Vector3) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z)],
		[Vector3.LEFT, Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z)],
		[Vector3.UP, Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z)],
		[Vector3.DOWN, Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z)],
		[Vector3.BACK, Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)],
		[Vector3.FORWARD, Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)],
	]
	for f in faces:
		var nn := _xn(xf, f[0])
		var i0 := add_vertex(xf * f[1], nn)
		var i1 := add_vertex(xf * f[2], nn)
		var i2 := add_vertex(xf * f[3], nn)
		var i3 := add_vertex(xf * f[4], nn)
		quad(i0, i1, i2, i3)


## Caixa só com as faces indicadas (economia de vértices em paredes/pisos).
func add_box_faces(xf: Transform3D, size: Vector3, skip_bottom := true) -> void:
	if not skip_bottom:
		add_box(xf, size)
		return
	var h := size * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z)],
		[Vector3.LEFT, Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z)],
		[Vector3.UP, Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z)],
		[Vector3.BACK, Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)],
		[Vector3.FORWARD, Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)],
	]
	for f in faces:
		var nn := _xn(xf, f[0])
		var i0 := add_vertex(xf * f[1], nn)
		var i1 := add_vertex(xf * f[2], nn)
		var i2 := add_vertex(xf * f[3], nn)
		var i3 := add_vertex(xf * f[4], nn)
		quad(i0, i1, i2, i3)


## Plano retangular (normal = eixo Y local).
func add_plane(xf: Transform3D, size: Vector2) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var nn := _xn(xf, Vector3.UP)
	var i0 := add_vertex(xf * Vector3(-hx, 0, -hz), nn)
	var i1 := add_vertex(xf * Vector3(-hx, 0, hz), nn)
	var i2 := add_vertex(xf * Vector3(hx, 0, hz), nn)
	var i3 := add_vertex(xf * Vector3(hx, 0, -hz), nn)
	quad(i0, i1, i2, i3)


## Esfera UV. cap_angle < PI gera uma calota ao redor do eixo +Y local.
func add_sphere(xf: Transform3D, radius: float, segments := 10, rings := 7, cap_angle := PI) -> void:
	var start := v.size()
	for r in rings + 1:
		var phi := cap_angle * float(r) / rings
		var y := cos(phi)
		var sr := sin(phi)
		for s in segments + 1:
			var th := TAU * float(s) / segments
			var local := Vector3(sr * cos(th), y, sr * sin(th))
			add_vertex(xf * (local * radius), _xn(xf, local))
	for r in rings:
		for s in segments:
			var a := start + r * (segments + 1) + s
			var b := a + 1
			var d := a + segments + 1
			var e := d + 1
			if r == 0:
				tri(a, d, e)
			elif r == rings - 1 and cap_angle >= PI - 0.001:
				tri(a, b, d)
			else:
				quad(a, b, e, d)


## Cápsula ao longo do eixo Y local (height = altura total).
func add_capsule(xf: Transform3D, radius: float, height: float, segments := 10, rings := 8) -> void:
	var half := maxf(height * 0.5 - radius, 0.0)
	var start := v.size()
	var hr := rings / 2
	var total_rings := hr * 2 + 1
	for r in total_rings + 1:
		var phi: float
		var off: float
		if r <= hr:
			phi = (PI * 0.5) * float(r) / hr
			off = half
		else:
			phi = PI * 0.5 + (PI * 0.5) * float(r - hr - 1) / hr
			off = -half
		var y := cos(phi)
		var sr := sin(phi)
		for s in segments + 1:
			var th := TAU * float(s) / segments
			var dir := Vector3(sr * cos(th), y, sr * sin(th))
			add_vertex(xf * (dir * radius + Vector3(0, off, 0)), _xn(xf, dir))
	for r in total_rings:
		for s in segments:
			var a := start + r * (segments + 1) + s
			var b := a + 1
			var d := a + segments + 1
			var e := d + 1
			if r == 0:
				tri(a, d, e)
			elif r == total_rings - 1:
				tri(a, b, d)
			else:
				quad(a, b, e, d)


## Cilindro/cone ao longo do eixo Y local, centrado na origem.
func add_cylinder(xf: Transform3D, r_top: float, r_bottom: float, height: float, segments := 10, caps := true) -> void:
	var hh := height * 0.5
	var slope := (r_bottom - r_top) / maxf(height, 0.0001)
	var start := v.size()
	for s in segments + 1:
		var th := TAU * float(s) / segments
		var dir := Vector3(cos(th), 0, sin(th))
		var nn := _xn(xf, Vector3(dir.x, slope, dir.z).normalized())
		add_vertex(xf * Vector3(dir.x * r_top, hh, dir.z * r_top), nn)
		add_vertex(xf * Vector3(dir.x * r_bottom, -hh, dir.z * r_bottom), nn)
	for s in segments:
		var a := start + s * 2
		quad(a, a + 2, a + 3, a + 1)
	if not caps:
		return
	for side in [1, -1]:
		var r := r_top if side == 1 else r_bottom
		if r <= 0.0001:
			continue
		var nn := _xn(xf, Vector3(0, side, 0))
		var center := add_vertex(xf * Vector3(0, hh * side, 0), nn)
		var ring_start := v.size()
		for s in segments + 1:
			var th := TAU * float(s) / segments
			add_vertex(xf * Vector3(cos(th) * r, hh * side, sin(th) * r), nn)
		for s in segments:
			tri(center, ring_start + s, ring_start + s + 1)


# ------------------------------------------------------------------ saída

func to_arrays() -> Array:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	if use_uv:
		arr[Mesh.ARRAY_TEX_UV] = uv
	if use_bones:
		arr[Mesh.ARRAY_BONES] = bones
		arr[Mesh.ARRAY_WEIGHTS] = weights
	arr[Mesh.ARRAY_INDEX] = idx
	return arr


func commit_to(mesh: ArrayMesh, material: Material) -> void:
	if v.is_empty():
		return
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, to_arrays())
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


func build_mesh(material: Material) -> ArrayMesh:
	var m := ArrayMesh.new()
	commit_to(m, material)
	return m
