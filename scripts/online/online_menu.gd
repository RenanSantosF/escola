class_name OnlineMenu
extends PanelContainer
## Tela "Jogar online": entrar numa sala aberta, criar sala para jogar com
## amigos (gera um código de 4 números) ou entrar com o código de um amigo.

signal chosen(mode: String, code: String)
signal back

var _status: Label
var _main: VBoxContainer
var _pad: VBoxContainer
var _code_lbl: Label
var _code := ""
var _busy := false


func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.CREAM, 0.97), 28, UITheme.DARK, 4, 6))
	custom_minimum_size = Vector2(760, 0)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	var t := UITheme.title_label("Jogar online", 52, UITheme.BLUE)
	root.add_child(t)
	var sub := Label.new()
	sub.text = "Todas as salas são abertas: o código serve para os amigos\ncaírem juntos na mesma sala."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	root.add_child(sub)

	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 12)
	root.add_child(_main)
	_main.add_child(_big("Entrar numa sala", "Vai para uma turma que já está jogando", UITheme.GREEN, func(): _go("quick", "")))
	_main.add_child(_big("Criar sala nova", "Sala aberta: passe o código para os amigos entrarem juntos", UITheme.ORANGE, func(): _go("create", "")))
	_main.add_child(_big("Entrar com código", "Digite o código que o amigo passou", UITheme.BLUE, _open_pad))

	_pad = VBoxContainer.new()
	_pad.visible = false
	_pad.add_theme_constant_override("separation", 10)
	root.add_child(_pad)
	_code_lbl = UITheme.title_label("_ _ _ _", 60, UITheme.DARK)
	_pad.add_child(_code_lbl)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var cc := CenterContainer.new()
	cc.add_child(grid)
	_pad.add_child(cc)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "OK"]:
		var key: String = k
		var b := Button.new()
		b.text = "Apagar" if k == "<" else k
		b.custom_minimum_size = Vector2(150, 74)
		b.add_theme_font_size_override("font_size", 34 if k.length() == 1 and k != "<" else 24)
		var col := UITheme.GREEN if k == "OK" else (UITheme.RED if k == "<" else Color.WHITE)
		for st in ["normal", "hover", "focus"]:
			b.add_theme_stylebox_override(st, UITheme.box(col, 16, UITheme.DARK, 3, 5))
		b.add_theme_stylebox_override("pressed", UITheme.box(col.darkened(0.15), 16, UITheme.DARK, 3, 2))
		b.add_theme_color_override("font_color", UITheme.DARK if col == Color.WHITE else Color.WHITE)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): _key(key))
		grid.add_child(b)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 22)
	root.add_child(_status)
	var safety := Label.new()
	safety.text = "Nunca conte seu nome, endereço, escola ou telefone. Peça para um adulto acompanhar."
	safety.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	safety.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	safety.add_theme_font_size_override("font_size", 17)
	safety.add_theme_color_override("font_color", UITheme.RED)
	root.add_child(safety)
	var bk := UITheme.make_button("Voltar", func():
		if _pad.visible:
			_pad.visible = false
			_main.visible = true
			_status.text = ""
		else:
			NetworkManager.leave()
			_busy = false
			back.emit(), 260)
	bk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(bk)


func _big(title: String, desc: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(700, 92)
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, UITheme.box(col, 22, col.darkened(0.35), 3, 6))
	b.add_theme_stylebox_override("pressed", UITheme.box(col.darkened(0.12), 22, col.darkened(0.35), 3, 2))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var l1 := UITheme.title_label(title, 34, Color.WHITE)
	l1.add_theme_constant_override("outline_size", 8)
	l1.add_theme_color_override("font_outline_color", col.darkened(0.45))
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l1)
	var l2 := Label.new()
	l2.text = desc
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.add_theme_font_size_override("font_size", 19)
	l2.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l2)
	b.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		cb.call())
	return b


func _open_pad() -> void:
	_code = ""
	_refresh_code()
	_main.visible = false
	_pad.visible = true
	_status.text = ""


func _key(k: String) -> void:
	AudioManager.play_ui("ui_click", -6.0)
	if k == "<":
		_code = _code.substr(0, maxi(_code.length() - 1, 0))
	elif k == "OK":
		if _code.length() == 4:
			_go("code", _code)
		else:
			set_status("O código tem 4 números.", true)
	elif _code.length() < 4:
		_code += k
	_refresh_code()


func _refresh_code() -> void:
	var s := ""
	for i in 4:
		s += (_code[i] if i < _code.length() else "_") + ("" if i == 3 else " ")
	_code_lbl.text = s


var last_mode := ""


func _go(mode: String, code: String) -> void:
	if _busy:
		return
	_busy = true
	last_mode = mode
	set_status("Conectando...", false)
	chosen.emit(mode, code)


func set_status(text: String, error: bool) -> void:
	_busy = not error and text != ""
	_status.text = text
	_status.add_theme_color_override("font_color", UITheme.RED if error else UITheme.DARK)


func reset() -> void:
	_busy = false
	_pad.visible = false
	_main.visible = true
	_status.text = ""
