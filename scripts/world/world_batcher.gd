class_name WorldBatcher
extends RefCounted
## Agrupa geometria estática por material dentro de um "chunk" (região),
## gerando 1 MeshInstance3D por material e 1 StaticBody3D com caixas de
## colisão. Chunks pequenos permitem frustum culling eficiente.

var name := ""
var data := {}  # chave "material|sombra" -> MeshData
var colliders: Array = []  # [Transform3D, Vector3 size] ou [Transform3D, "cyl", r, h]
var visibility_end := 0.0
var cast_shadows := true
var occluders: Array = []  # [Transform3D, Vector3 size]


func _init(chunk_name := "") -> void:
	name = chunk_name


func _md(mat: String, shadow := true) -> MeshData:
	var group := SchoolMaterials.group_of(mat)
	var key := group + ("|s" if shadow else "|n")
	if not data.has(key):
		var m := MeshData.new()
		m.use_uv = true
		m.use_uv2 = group == "world"
		data[key] = m
	var md: MeshData = data[key]
	md.uv_scale = SchoolMaterials.uv_scale(mat)
	md.cur_uv2 = SchoolMaterials.uv2_of(mat)
	return md


func box(mat: String, center: Vector3, size: Vector3, color: Color, rot_y := 0.0, shadow := true) -> void:
	var md := _md(mat, shadow)
	md.cur_color = color
	md.add_box(Transform3D(Basis(Vector3.UP, rot_y), center), size)


## Caixa sem a face inferior (pisos, paredes apoiadas no chão).
func slab(mat: String, center: Vector3, size: Vector3, color: Color, shadow := false) -> void:
	var md := _md(mat, shadow)
	md.cur_color = color
	md.add_box_faces(Transform3D(Basis(), center), size, true)


func box_xf(mat: String, xf: Transform3D, size: Vector3, color: Color, shadow := true) -> void:
	var md := _md(mat, shadow)
	md.cur_color = color
	md.add_box(xf, size)


func cylinder(mat: String, center: Vector3, r_top: float, r_bottom: float, h: float, color: Color, seg := 10, shadow := true) -> void:
	var md := _md(mat, shadow)
	md.cur_color = color
	md.add_cylinder(Transform3D(Basis(), center), r_top, r_bottom, h, seg)


func cylinder_xf(mat: String, xf: Transform3D, r_top: float, r_bottom: float, h: float, color: Color, seg := 10, shadow := true) -> void:
	var md := _md(mat, shadow)
	md.cur_color = color
	md.add_cylinder(xf, r_top, r_bottom, h, seg)


func sphere(mat: String, center: Vector3, r: float, color: Color, scale := Vector3.ONE, seg := 10, rings := 7, shadow := true) -> void:
	var md := _md(mat, shadow)
	md.cur_color = color
	md.add_sphere(Transform3D(Basis.from_scale(scale), center), r, seg, rings)


func plane(mat: String, center: Vector3, size: Vector2, color: Color, rot_y := 0.0) -> void:
	var md := _md(mat, false)
	md.cur_color = color
	md.add_plane(Transform3D(Basis(Vector3.UP, rot_y), center), size)


## Triângulo/polígono vertical (oitões de telhado etc.).
func triangle(mat: String, a: Vector3, b: Vector3, c: Vector3, color: Color, double_sided := true) -> void:
	var md := _md(mat, true)
	md.cur_color = color
	var nn := (b - a).cross(c - a).normalized()
	for side in ([1.0, -1.0] if double_sided else [1.0]):
		var n2: Vector3 = nn * side
		var i0 := md.add_vertex(a, n2)
		var i1 := md.add_vertex(b, n2)
		var i2 := md.add_vertex(c, n2)
		md.tri(i0, i1, i2)


func collider(center: Vector3, size: Vector3, rot_y := 0.0) -> void:
	colliders.append([Transform3D(Basis(Vector3.UP, rot_y), center), size])


func collider_xf(xf: Transform3D, size: Vector3) -> void:
	colliders.append([xf, size])


func collider_cyl(center: Vector3, r: float, h: float) -> void:
	colliders.append([Transform3D(Basis(), center), "cyl", r, h])


func occluder(center: Vector3, size: Vector3) -> void:
	occluders.append([Transform3D(Basis(), center), size])


func vertex_count() -> int:
	var n := 0
	for k in data.keys():
		n += data[k].vertex_count()
	return n


## Cria os nós finais sob `parent`. Retorna o Node3D do chunk.
func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = name if name != "" else "Chunk"
	parent.add_child(root)
	for key in data.keys():
		var md: MeshData = data[key]
		if md.is_empty():
			continue
		var parts: PackedStringArray = key.split("|")
		var mi := MeshInstance3D.new()
		mi.name = parts[0]
		mi.mesh = md.build_mesh(SchoolMaterials.get_mat(parts[0]))
		var shadow := parts[1] == "s" and cast_shadows
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if visibility_end > 0.0:
			mi.visibility_range_end = visibility_end
			mi.visibility_range_end_margin = 4.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		root.add_child(mi)
	if not colliders.is_empty():
		var body := StaticBody3D.new()
		body.name = "Collision"
		body.collision_layer = 1
		body.collision_mask = 0
		root.add_child(body)
		for c in colliders:
			var cs := CollisionShape3D.new()
			if c.size() == 2:
				var shape := BoxShape3D.new()
				shape.size = c[1]
				cs.shape = shape
			else:
				var cyl := CylinderShape3D.new()
				cyl.radius = c[2]
				cyl.height = c[3]
				cs.shape = cyl
			cs.transform = c[0]
			body.add_child(cs)
	for o in occluders:
		var oi := OccluderInstance3D.new()
		var bo := BoxOccluder3D.new()
		bo.size = o[1]
		oi.occluder = bo
		oi.transform = o[0]
		root.add_child(oi)
	return root
