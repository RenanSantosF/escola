class_name ChatPanel
extends Control
## Chat seguro para crianças: frases rápidas (sempre), texto livre só se
## liberado por responsável/13+, e tocar numa mensagem abre Denunciar /
## Bloquear. Mostra só as últimas mensagens (nada fica salvo no aparelho).

const MAX_LINES := 6
const REASONS := [["linguagem", "Palavras feias"], ["assedio", "Me incomodando"],
	["dados_pessoais", "Pediu dados pessoais"], ["nome_inadequado", "Nome estranho"], ["outro", "Outro motivo"]]

var _open := false
var _toggle: Button
var _box: PanelContainer
var _lines: VBoxContainer
var _phrases: GridContainer
var _input: LineEdit
var _menu: PanelContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(16, 230)
	size = Vector2(430, 420)
	_toggle = UITheme.make_button("Chat", func(): set_open(not _open), 120)
	_toggle.position = Vector2.ZERO
	add_child(_toggle)
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.CREAM, 0.94), 18, UITheme.DARK, 3, 3))
	_box.position = Vector2(0, 70)
	_box.custom_minimum_size = Vector2(430, 0)
	_box.visible = false
	add_child(_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_box.add_child(v)
	var tip := Label.new()
	tip.text = "Nunca conte seu nome, endereço, escola ou telefone. Toque numa mensagem para denunciar."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", UITheme.RED)
	v.add_child(tip)
	_lines = VBoxContainer.new()
	v.add_child(_lines)
	_phrases = GridContainer.new()
	_phrases.columns = 3
	v.add_child(_phrases)
	_input = LineEdit.new()
	_input.placeholder_text = "Escreva (sem dados pessoais)..."
	_input.max_length = 80
	_input.visible = false
	_input.text_submitted.connect(func(t):
		NetworkManager.send_chat(t)
		_input.text = "")
	v.add_child(_input)


func set_open(on: bool) -> void:
	_open = on
	_box.visible = on
	AudioManager.play_ui("ui_click")


func setup_phrases(list: Array, free_chat: bool) -> void:
	for c in _phrases.get_children():
		c.queue_free()
	for i in list.size():
		var idx := i
		var b := Button.new()
		b.text = str(list[i])
		b.add_theme_font_size_override("font_size", 15)
		b.clip_text = true
		b.custom_minimum_size = Vector2(134, 40)
		b.pressed.connect(func(): NetworkManager.send_quick(idx))
		_phrases.add_child(b)
	_input.visible = free_chat


func add_line(sender_id: String, text: String, system: bool) -> void:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.custom_minimum_size = Vector2(410, 30)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", UITheme.ORANGE.darkened(0.2) if system else UITheme.DARK)
	if sender_id != "":
		b.pressed.connect(func(): _open_menu(sender_id))
	_lines.add_child(b)
	while _lines.get_child_count() > MAX_LINES:
		var c := _lines.get_child(0)
		_lines.remove_child(c)
		c.queue_free()


func _open_menu(target: String) -> void:
	if _menu:
		_menu.queue_free()
	_menu = PanelContainer.new()
	_menu.add_theme_stylebox_override("panel", UITheme.box(Color.WHITE, 18, UITheme.DARK, 3, 3))
	_menu.position = Vector2(440, 70)
	add_child(_menu)
	var v := VBoxContainer.new()
	_menu.add_child(v)
	v.add_child(UITheme.title_label("Denunciar por:", 22))
	for r in REASONS:
		var reason: String = r[0]
		v.add_child(UITheme.make_button(r[1], func():
			NetworkManager.report(target, reason)
			_menu.queue_free(), 260))
	v.add_child(UITheme.make_button("Só bloquear", func():
		NetworkManager.block(target)
		_menu.queue_free(), 260))
	v.add_child(UITheme.make_button("Cancelar", func(): _menu.queue_free(), 260))
