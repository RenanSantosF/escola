class_name DialogueUI
extends Control
## Caixa de diálogo na parte de baixo da tela (efeito de digitação).
## Toque para avançar; opções opcionais na última fala.

signal finished(choice: int)

var _panel: PanelContainer
var _name: Label
var _text: Label
var _hint: Label
var _options: HBoxContainer
var _lines: Array = []
var _options_list: Array = []
var _i := 0
var _chars := 0.0
var _typing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.get_theme()
	visible = false
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UITheme.box(Color(1, 0.98, 0.92, 0.97), 22, Color("e2c98a"), 4))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)
	_name = UITheme.title_label("", 26, UITheme.BLUE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(_name)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 28)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 76)
	v.add_child(_text)
	_options = HBoxContainer.new()
	_options.add_theme_constant_override("separation", 12)
	_options.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(_options)
	_hint = Label.new()
	_hint.text = "Toque para continuar ▸"
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color("9a8a60"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_hint)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vs := get_viewport_rect().size
	var w := minf(vs.x - 80.0, 980.0)
	_panel.size = Vector2(w, 0)
	_panel.position = Vector2((vs.x - w) * 0.5, vs.y - 220.0)


func is_open() -> bool:
	return visible


func open(speaker: String, lines: Array, options: Array = []) -> void:
	_lines = lines
	_options_list = options
	_i = 0
	_name.text = speaker
	visible = true
	_layout()
	_show_line()


func _show_line() -> void:
	var line = _lines[_i]
	if line is Array:
		_name.text = str(line[0])
		_text.text = str(line[1])
	else:
		_text.text = str(line)
	_chars = 0.0
	_text.visible_characters = 0
	_typing = true
	for c in _options.get_children():
		c.queue_free()
	_hint.visible = true


func _process(delta: float) -> void:
	if not visible or not _typing:
		return
	_chars += delta * 45.0
	_text.visible_characters = int(_chars)
	if _chars >= _text.text.length():
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	if true:
		if _i == _lines.size() - 1 and not _options_list.is_empty():
			_hint.visible = false
			for k in _options_list.size():
				var idx := k
				var b := UITheme.make_button(_options_list[k], func(): _close(idx), 200)
				b.custom_minimum_size = Vector2(200, 52)
				b.add_theme_font_size_override("font_size", 22)
				_options.add_child(b)


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		_panel.accept_event()


func advance() -> void:
	if _typing:
		_finish_typing()
		return
	if _i == _lines.size() - 1 and not _options_list.is_empty():
		return
	_i += 1
	AudioManager.play_ui("ui_click", -8.0)
	if _i >= _lines.size():
		_close(-1)
	else:
		_show_line()


func _close(choice: int) -> void:
	visible = false
	finished.emit(choice)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("interact") or event.is_action_pressed("jump")):
		advance()
		get_viewport().set_input_as_handled()
