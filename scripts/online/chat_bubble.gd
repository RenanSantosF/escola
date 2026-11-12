class_name ChatBubble
extends Node3D
## Balãozinho de fala em cima da cabeça (chat): fundo branco arredondado,
## texto escuro, sempre virado para a câmera. Some sozinho depois de uns
## segundos (mais tempo para mensagens maiores).

const WIDTH_PX := 380.0
const FONT_SIZE := 34
const PIXEL := 0.0024

var _label: Label3D
var _bg: MeshInstance3D
var _tail: MeshInstance3D
var _t := 0.0
var _mat: StandardMaterial3D


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat.albedo_color = Color(1, 1, 1, 0.96)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.render_priority = 1
	_bg = MeshInstance3D.new()
	_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bg.material_override = _mat
	add_child(_bg)
	_tail = MeshInstance3D.new()
	_tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tail.material_override = _mat
	var tm := PrismMesh.new()
	tm.size = Vector3(0.12, 0.09, 0.01)
	_tail.mesh = tm
	_tail.rotation.z = PI
	add_child(_tail)
	_label = Label3D.new()
	_label.font = UITheme.bold_font()
	_label.font_size = FONT_SIZE
	_label.pixel_size = PIXEL
	_label.modulate = Color("1f2a44")
	_label.outline_size = 0
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.width = WIDTH_PX
	_label.render_priority = 2
	_label.no_depth_test = false
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(_label)
	visible = false


func show_text(text: String) -> void:
	if _label == null:
		await ready
	_label.text = text
	var f := UITheme.bold_font()
	var one := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var w := minf(one.x, WIDTH_PX)
	var sz := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, WIDTH_PX, FONT_SIZE)
	var lines := maxf(1.0, ceil(sz.y / maxf(f.get_height(FONT_SIZE), 1.0)))
	var h_px := lines * f.get_height(FONT_SIZE)
	_label.width = maxf(w + 4.0, 40.0)
	# fundo do tamanho do texto (+ margem), com a parte de baixo na altura do nó
	var bw := (w + 44.0) * PIXEL
	var bh := (h_px + 28.0) * PIXEL
	var q := QuadMesh.new()
	q.size = Vector2(bw, bh)
	_bg.mesh = q
	_bg.position = Vector3(0, bh * 0.5, 0)
	_label.position = Vector3(0, bh * 0.5, 0.01)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tail.position = Vector3(0, -0.06, 0)
	_t = clampf(4.0 + text.length() * 0.08, 4.0, 9.0)
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		visible = false
		set_process(false)
