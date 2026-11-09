class_name AimArc
extends Node3D
## Mira visual: arco pontilhado da trajetória + anel no ponto de queda.
## A trajetória mostrada é exatamente a usada no arremesso.

const G := 9.8

var _line: MeshInstance3D
var _ring: MeshInstance3D
var _mat: StandardMaterial3D
var color := Color("ffcf3f")


func _ready() -> void:
	top_level = true
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.no_depth_test = true
	_mat.render_priority = 10
	_line = MeshInstance3D.new()
	_line.material_override = _mat
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_ring = MeshInstance3D.new()
	var md := MeshData.new()
	md.cur_color = Color.WHITE
	for k in 16:
		var a := k * TAU / 16.0
		md.add_box(Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a)) * 0.45), Vector3(0.06, 0.02, 0.15))
	md.add_sphere(Transform3D(), 0.08, 6, 4)
	_ring.mesh = md.build_mesh(_mat)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	visible = false


## Velocidade inicial para acertar `target` saindo de `from` a `speed` m/s
## (trajetória baixa e direta, como um arremesso de criança).
static func solve(from: Vector3, target: Vector3, speed: float) -> Vector3:
	var d := target - from
	var flat := Vector2(d.x, d.z).length()
	var t := maxf(flat / speed, 0.15)
	return Vector3(d.x / t, d.y / t + 0.5 * G * t, d.z / t)


## Desenha o arco e retorna o ponto de queda (y do chão = ground_y).
func show_arc(from: Vector3, vel: Vector3, ground_y := 0.05, tint := Color("ffcf3f")) -> Vector3:
	visible = true
	global_position = Vector3.ZERO
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var p := from
	var v := vel
	var dt := 0.04
	var land := from
	for i in 70:
		var np := p + v * dt
		v.y -= G * dt
		if i % 2 == 0:
			im.surface_set_color(Color(tint, 0.95))
			im.surface_add_vertex(p)
			im.surface_add_vertex(np)
		p = np
		land = p
		if p.y <= ground_y:
			break
	im.surface_end()
	_line.mesh = im
	_ring.global_position = Vector3(land.x, ground_y + 0.03, land.z)
	(_ring.material_override if _ring.material_override else _mat).albedo_color = Color.WHITE
	return land


func hide_arc() -> void:
	visible = false
