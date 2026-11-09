class_name VehicleVisual
extends Node3D
## Malhas do skate, patinete e bicicleta (rodas giram com a velocidade).

var kind := ""
var _wheels: Array[Node3D] = []
var _spin := 0.0


static func create(k: String) -> VehicleVisual:
	var v := VehicleVisual.new()
	v.kind = k
	v._build()
	return v


func _part(md: MeshData) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	add_child(mi)
	return mi


func _wheel(pos: Vector3, r: float, w: float, col: Color, spokes := false) -> void:
	var piv := Node3D.new()
	piv.position = pos
	add_child(piv)
	var md := MeshData.new()
	md.cur_color = col
	md.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), r, r, w, 14)
	if spokes:
		md.cur_color = Color("dfe6e9")
		md.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), r * 0.82, r * 0.82, w + 0.004, 14)
		md.cur_color = Color("7f8c8d")
		for k in 4:
			md.add_box(Transform3D(Basis(Vector3.RIGHT, k * PI / 4.0), Vector3.ZERO), Vector3(w + 0.01, r * 1.6, 0.015))
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	piv.add_child(mi)
	_wheels.append(piv)


func _build() -> void:
	var md := MeshData.new()
	match kind:
		"skate":
			md.cur_color = Color("e74c3c")
			md.add_capsule(Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1, 1, 0.18)), Vector3(0, 0.085, 0)), 0.11, 0.82, 10, 6)
			md.cur_color = Color("2d3436")
			md.add_box(Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(0.2, 0.006, 0.76))
			md.cur_color = Color("b2bec3")
			for z: float in [-0.25, 0.25]:
				md.add_box(Transform3D(Basis(), Vector3(0, 0.055, z)), Vector3(0.16, 0.03, 0.05))
			_part(md)
			for x: float in [-0.08, 0.08]:
				for z: float in [-0.25, 0.25]:
					_wheel(Vector3(x, 0.035, z), 0.035, 0.035, Color("f1c40f"))
		"patinete":
			md.cur_color = Color("3498db")
			md.add_box(Transform3D(Basis(), Vector3(0, 0.08, 0)), Vector3(0.14, 0.03, 0.62))
			md.cur_color = Color("95a5a6")
			md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, 0.55, 0.36)), 0.02, 0.02, 0.95, 6)
			md.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 1.02, 0.43)), 0.018, 0.018, 0.5, 6)
			md.cur_color = Color("2d3436")
			for x: float in [-0.25, 0.25]:
				md.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x, 1.02, 0.43)), 0.025, 0.025, 0.1, 6)
			_part(md)
			_wheel(Vector3(0, 0.05, 0.36), 0.05, 0.03, Color("2d3436"))
			_wheel(Vector3(0, 0.05, -0.3), 0.05, 0.03, Color("2d3436"))
		"bike":
			var fc := Color("e84393")
			md.cur_color = fc
			md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, 1.0), Vector3(0, 0.6, 0.1)), 0.025, 0.025, 0.72, 6)
			md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 0.55, -0.18)), 0.025, 0.025, 0.5, 6)
			md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.37, -0.25)), 0.022, 0.022, 0.42, 6)
			md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 0.62, 0.43)), 0.025, 0.025, 0.62, 6)
			md.cur_color = Color("2d3436")
			md.add_box(Transform3D(Basis(), Vector3(0, 0.84, -0.27)), Vector3(0.13, 0.05, 0.24))
			md.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.93, 0.5)), 0.018, 0.018, 0.56, 6)
			md.cur_color = Color("b2bec3")
			md.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.33, 0.0)), 0.07, 0.07, 0.04, 10)
			_part(md)
			_wheel(Vector3(0, 0.33, 0.56), 0.33, 0.04, Color("2d3436"), true)
			_wheel(Vector3(0, 0.33, -0.48), 0.33, 0.04, Color("2d3436"), true)


func spin(speed: float, delta: float) -> void:
	var r := 0.33 if kind == "bike" else 0.04
	_spin += speed * delta / r
	for w in _wheels:
		w.rotation.x = _spin
