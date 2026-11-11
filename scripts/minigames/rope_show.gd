class_name RopeShow
extends Node3D
## Corda de pular vista por quem está DE FORA (online): dois batedores e a
## corda girando no mesmo tempo de quem está pulando, mais o placar de pulos.
## Quem pula manda "r<ângulo>,<velocidade>,<pulos>" no estado (anim) e cada
## celular por perto desenha a corda aqui (sem bots, sem física).

const CENTER := Vector3(-24, 0.05, -2)
const HALF := 1.7

var angle := 0.0
var speed := 3.6
var jumps := 0
var _age := 0.0
var _rope: MeshInstance3D
var _mat: StandardMaterial3D
var _label: Label3D
var _turners: Array[CharacterVisual] = []


## Lê o código que vem no anim ("r1.23,4.56,7"). Vazio = não está pulando.
static func parse(anim: String) -> Array:
	if not anim.begins_with("r") or anim.count(",") != 2:
		return []
	var parts := anim.substr(1).split(",")
	if parts.size() != 3 or not parts[0].is_valid_float() or not parts[1].is_valid_float():
		return []
	return [float(parts[0]), float(parts[1]), int(parts[2])]


static func encode(a: float, s: float, j: int) -> String:
	return "r%.2f,%.1f,%d" % [fposmod(a, TAU), s, j]


func _ready() -> void:
	global_position = Vector3.ZERO
	_rope = MeshInstance3D.new()
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rope)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rope.material_override = _mat
	for i in 2:
		var v := CharacterVisual.new()
		v.detail = 0.6
		v.appearance = CharacterAppearance.random(4400 + i * 17, true)
		add_child(v)
		var sx := -1.0 if i == 0 else 1.0
		v.global_position = CENTER + Vector3(sx * (HALF + 0.35), 0, 0)
		v.rotation.y = -PI * 0.5 * sx
		_turners.append(v)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font = UITheme.bold_font()
	_label.font_size = 64
	_label.outline_size = 14
	_label.modulate = Color("ffd23f")
	_label.pixel_size = 0.006
	add_child(_label)
	_label.global_position = CENTER + Vector3(0, 2.6, 0)


## Chegou um estado novo de quem está pulando.
func sync(a: float, s: float, j: int) -> void:
	# corrige suave (sem pulos bruscos na corda)
	var diff := wrapf(a - angle, -PI, PI)
	angle += diff if absf(diff) > 1.2 else diff * 0.5
	speed = s
	if j > jumps:
		AudioManager.play_3d("point", CENTER + Vector3(0, 1, 0), -14.0, 0.1)
	jumps = j
	_age = 0.0


func is_stale() -> bool:
	return _age > 1.5


func _process(delta: float) -> void:
	_age += delta
	angle += speed * delta
	_label.text = "%d pulos" % jumps
	for t in _turners:
		if t.animator.upper_action == "":
			t.play("talk")
	_draw()


func _point(t: float) -> Vector3:
	var x := lerpf(-HALF, HALF, t)
	var sag := 1.0 - pow(2.0 * t - 1.0, 2.0)
	var r := 0.95 * sag
	return CENTER + Vector3(x, 0.95 + sin(angle) * r, cos(angle) * r)


func _draw() -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.035
	var offs := [Vector3(0, w, 0), Vector3(0, 0, w), Vector3(0, -w, 0), Vector3(0, 0, -w)]
	for k in 16:
		var p0 := _point(k / 16.0)
		var p1 := _point((k + 1) / 16.0)
		for j in 4:
			var a0: Vector3 = offs[j]
			var a1: Vector3 = offs[(j + 1) % 4]
			im.surface_set_color(Color("ff3d6e") if j % 2 == 0 else Color("d81b4f"))
			im.surface_add_vertex(p0 + a0)
			im.surface_add_vertex(p1 + a0)
			im.surface_add_vertex(p1 + a1)
			im.surface_add_vertex(p0 + a0)
			im.surface_add_vertex(p1 + a1)
			im.surface_add_vertex(p0 + a1)
	im.surface_end()
	_rope.mesh = im
