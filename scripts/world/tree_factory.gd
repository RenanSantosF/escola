class_name TreeFactory
extends RefCounted
## Árvores com MultiMesh (1 draw call por parte/tipo para a escola toda)
## e balanço de vento no shader de folhagem.

const TYPES := ["copa", "ipe", "palmeira", "arbusto", "pinheiro"]

static var _meshes: Dictionary = {}


static func _build_meshes() -> void:
	if not _meshes.is_empty():
		return
	var trunk_col := Color("6e4a2e")
	var green := Color("3f8a3a")
	# copa: árvore frondosa (mangueira/oiti)
	var t := MeshData.new()
	t.cur_color = trunk_col
	t.add_cylinder(Transform3D(Basis(), Vector3(0, 1.3, 0)), 0.17, 0.26, 2.6, 8)
	t.add_cylinder(Transform3D(Basis(Vector3.FORWARD, 0.6), Vector3(0.35, 2.6, 0)), 0.07, 0.12, 1.2, 6)
	t.add_cylinder(Transform3D(Basis(Vector3.FORWARD, -0.5), Vector3(-0.3, 2.7, 0.1)), 0.07, 0.11, 1.1, 6)
	var f := MeshData.new()
	var blobs := [[Vector3(0, 3.6, 0), 1.9], [Vector3(1.2, 3.2, 0.3), 1.3], [Vector3(-1.1, 3.3, -0.2), 1.35],
		[Vector3(0.2, 3.3, 1.1), 1.25], [Vector3(-0.2, 3.4, -1.1), 1.3], [Vector3(0.3, 4.5, 0.1), 1.2]]
	var shade := [1.0, 0.9, 0.85, 0.95, 0.88, 1.08]
	for i in blobs.size():
		f.cur_color = green * shade[i]
		f.cur_color.a = 1.0
		f.add_sphere(Transform3D(Basis.from_scale(Vector3(1, 0.82, 1)), blobs[i][0]), blobs[i][1], 10, 7)
	_meshes["copa"] = [t, f]

	# ipê: tronco fino e copa achatada florida
	t = MeshData.new()
	t.cur_color = trunk_col.darkened(0.1)
	t.add_cylinder(Transform3D(Basis(), Vector3(0, 1.6, 0)), 0.11, 0.17, 3.2, 7)
	t.add_cylinder(Transform3D(Basis(Vector3.FORWARD, 0.7), Vector3(0.4, 3.2, 0)), 0.05, 0.08, 1.2, 5)
	t.add_cylinder(Transform3D(Basis(Vector3.FORWARD, -0.7), Vector3(-0.4, 3.2, 0)), 0.05, 0.08, 1.2, 5)
	f = MeshData.new()
	for i in 7:
		var a := i * TAU / 7.0
		var p := Vector3(cos(a) * 1.0, 3.9 + (i % 2) * 0.3, sin(a) * 1.0)
		f.cur_color = Color(1, 1, 1) * (0.88 + 0.12 * (i % 3) / 2.0)
		f.cur_color.a = 1.0
		f.add_sphere(Transform3D(Basis.from_scale(Vector3(1, 0.6, 1)), p), 1.05, 9, 6)
	f.cur_color = Color.WHITE
	f.add_sphere(Transform3D(Basis.from_scale(Vector3(1, 0.6, 1)), Vector3(0, 4.3, 0)), 1.3, 10, 6)
	_meshes["ipe"] = [t, f]

	# palmeira
	t = MeshData.new()
	t.cur_color = Color("8d7b62")
	for i in 6:
		var y := 0.6 + i * 1.1
		t.add_cylinder(Transform3D(Basis(Vector3.FORWARD, 0.03 * i), Vector3(0.05 * i, y, 0)), 0.15 - i * 0.008, 0.18 - i * 0.008, 1.15, 8)
	f = MeshData.new()
	for i in 9:
		var a := i * TAU / 9.0
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.45 + (i % 2) * 0.25)
		f.cur_color = Color("4f9a3c") * (0.9 + 0.1 * (i % 3))
		f.cur_color.a = 1.0
		f.add_box(Transform3D(b, Vector3(0.3, 6.6, 0) + b * Vector3(0, 0, 1.3)), Vector3(0.55, 0.06, 2.6))
	f.cur_color = Color("6e8f3a")
	f.add_sphere(Transform3D(Basis(), Vector3(0.3, 6.6, 0)), 0.35, 8, 6)
	_meshes["palmeira"] = [t, f]

	# arbusto
	t = MeshData.new()
	t.cur_color = trunk_col
	t.add_cylinder(Transform3D(Basis(), Vector3(0, 0.15, 0)), 0.05, 0.07, 0.3, 5)
	f = MeshData.new()
	for i in 4:
		var a := i * TAU / 4.0
		f.cur_color = Color("3d8b3d") * (0.9 + 0.08 * i)
		f.cur_color.a = 1.0
		f.add_sphere(Transform3D(Basis(), Vector3(cos(a) * 0.35, 0.55, sin(a) * 0.35)), 0.5, 8, 6)
	f.cur_color = Color("4a9a45")
	f.add_sphere(Transform3D(Basis(), Vector3(0, 0.8, 0)), 0.55, 8, 6)
	_meshes["arbusto"] = [t, f]

	# pinheiro (cipreste estilizado)
	t = MeshData.new()
	t.cur_color = trunk_col
	t.add_cylinder(Transform3D(Basis(), Vector3(0, 0.6, 0)), 0.1, 0.14, 1.2, 6)
	f = MeshData.new()
	for i in 3:
		f.cur_color = Color("2f6e3a") * (0.9 + 0.08 * i)
		f.cur_color.a = 1.0
		f.add_cylinder(Transform3D(Basis(), Vector3(0, 1.6 + i * 1.2, 0)), 0.15, 1.3 - i * 0.3, 2.0, 10)
	_meshes["pinheiro"] = [t, f]


## trees: Array de {type, pos, scale, rot, color}
static func build(parent: Node3D, trees: Array, shadows: bool) -> void:
	_build_meshes()
	var by_type := {}
	for tr in trees:
		if not by_type.has(tr.type):
			by_type[tr.type] = []
		by_type[tr.type].append(tr)
	for type in by_type.keys():
		var list: Array = by_type[type]
		var parts: Array = _meshes[type]
		for pi in 2:
			var md: MeshData = parts[pi]
			var mesh := md.build_mesh(SchoolMaterials.get_mat("plain" if pi == 0 else "foliage"))
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = list.size()
			for i in list.size():
				var tr: Dictionary = list[i]
				var xf := Transform3D(Basis(Vector3.UP, tr.rot).scaled(Vector3.ONE * tr.scale), tr.pos)
				mm.set_instance_transform(i, xf)
				var tint: Color = tr.color if type == "ipe" else Color.WHITE * (0.92 + 0.16 * fposmod(tr.pos.x * 0.37 + tr.pos.z * 0.61, 1.0))
				tint.a = 1.0
				mm.set_instance_color(i, Color.WHITE if pi == 0 else tint)
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%s" % [type, "trunk" if pi == 0 else "crown"]
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mmi)


static func trunk_radius(type: String) -> float:
	match type:
		"copa": return 0.3
		"ipe": return 0.2
		"palmeira": return 0.22
		"pinheiro": return 0.18
	return 0.0
