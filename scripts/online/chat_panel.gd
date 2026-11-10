class_name ChatPanel
extends Control
## Chat das crianças:
## - digitar (sempre filtrado: palavrões e dados pessoais) + botão Enviar
## - frases rápidas em "chips" e reações (acenar, comemorar...)
## - canais "Todos da sala" e "Perto de mim" (18 m)
## - tocar numa mensagem: Denunciar / Bloquear
## - botão para chamar a sala para um pique-pega
## Mostra só as últimas mensagens (nada fica salvo no aparelho).

signal tag_pressed

const MAX_LINES := 7
const REASONS := [["linguagem", "Palavras feias"], ["assedio", "Me incomodando"],
	["dados_pessoais", "Pediu dados pessoais"], ["nome_inadequado", "Nome estranho"], ["outro", "Outro motivo"]]
const REACTIONS := [["Acenar", "wave"], ["Comemorar", "celebrate"], ["Palmas", "clap"], ["Mão", "raise_hand"]]
const BG := Color(0.08, 0.11, 0.22, 0.86)
const CHIP := Color(1, 1, 1, 0.12)

var channel := "all"
var player: PlayerController
var _open := false
var _toggle: Button
var _tag_btn: Button
var _box: PanelContainer
var _lines: VBoxContainer
var _phrases: HFlowContainer
var _input: LineEdit
var _send: Button
var _menu: PanelContainer
var _tab_all: Button
var _tab_near: Button
var _unread := 0
var _room_lbl: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(16, 244)
	size = Vector2(520, 460)
	_toggle = _pill("Chat", Color("2f8be0"), func(): set_open(not _open))
	_toggle.position = Vector2.ZERO
	add_child(_toggle)
	_tag_btn = _pill("Pique-pega", Color("ff4d6d"), func():
		AudioManager.play_ui("ui_click")
		tag_pressed.emit())
	_tag_btn.position = Vector2(150, 0)
	add_child(_tag_btn)
	_box = PanelContainer.new()
	var sb := UITheme.box(BG, 20, Color(1, 1, 1, 0.18), 2, 0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	_box.add_theme_stylebox_override("panel", sb)
	_box.position = Vector2(0, 64)
	_box.custom_minimum_size = Vector2(520, 0)
	_box.visible = false
	add_child(_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_box.add_child(v)
	# cabeçalho: canais + sala
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	_tab_all = _tab_button("Todos", "all")
	_tab_near = _tab_button("Perto de mim", "near")
	head.add_child(_tab_all)
	head.add_child(_tab_near)
	_room_lbl = Label.new()
	_room_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_room_lbl.add_theme_font_size_override("font_size", 16)
	_room_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	head.add_child(_room_lbl)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 2)
	_lines.custom_minimum_size = Vector2(0, 150)
	v.add_child(_lines)
	# digitar
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_input = LineEdit.new()
	_input.placeholder_text = "Escreva uma mensagem..."
	_input.max_length = 80
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.custom_minimum_size = Vector2(0, 50)
	_input.add_theme_font_size_override("font_size", 20)
	_input.add_theme_color_override("font_color", Color.WHITE)
	_input.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.45))
	for st in ["normal", "focus"]:
		_input.add_theme_stylebox_override(st, UITheme.box(Color(1, 1, 1, 0.1 if st == "normal" else 0.16), 14, Color(1, 1, 1, 0.25 if st == "normal" else 0.6), 2, 0))
	_input.text_submitted.connect(func(_t): _send_text())
	row.add_child(_input)
	_send = _pill("Enviar", UITheme.GREEN, _send_text, 110)
	row.add_child(_send)
	var tip := Label.new()
	tip.text = "Não conte nome verdadeiro, endereço, escola ou telefone. Toque numa mensagem para denunciar."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color("ffb3a8"))
	v.add_child(tip)
	_phrases = HFlowContainer.new()
	_phrases.add_theme_constant_override("h_separation", 6)
	_phrases.add_theme_constant_override("v_separation", 6)
	v.add_child(_phrases)
	var rx := HBoxContainer.new()
	rx.add_theme_constant_override("separation", 6)
	v.add_child(rx)
	for r in REACTIONS:
		var em: String = r[1]
		rx.add_child(_chip(r[0], func():
			if player:
				player.emote(em), Color("ffcf3f"), UITheme.DARK))
	_refresh_tabs()


func _pill(text: String, col: Color, cb: Callable, w := 136) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 54)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, UITheme.box(col, 27, col.darkened(0.35), 0, 4))
	b.add_theme_stylebox_override("pressed", UITheme.box(col.darkened(0.15), 27, col.darkened(0.35), 0, 1))
	b.pressed.connect(cb)
	return b


func _chip(text: String, cb: Callable, col := CHIP, font_col := Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", font_col)
	b.add_theme_color_override("font_hover_color", font_col)
	b.custom_minimum_size = Vector2(0, 40)
	for st in ["normal", "hover", "focus"]:
		var sb := UITheme.box(col, 20, Color(0, 0, 0, 0), 0, 0)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		b.add_theme_stylebox_override(st, sb)
	var sp := UITheme.box(col.lightened(0.2), 20, Color(0, 0, 0, 0), 0, 0)
	sp.content_margin_left = 12
	sp.content_margin_right = 12
	b.add_theme_stylebox_override("pressed", sp)
	b.pressed.connect(cb)
	return b


func _send_text() -> void:
	var t := _input.text.strip_edges()
	if t == "":
		return
	NetworkManager.send_chat(t, channel)
	_input.text = ""
	AudioManager.play_ui("ui_click", -8.0)


## Só os botões e a caixa aberta bloqueiam o toque (o resto da área do
## painel deixa o analógico e a câmera funcionarem).
func blocks_point(p: Vector2) -> bool:
	for c in get_children():
		if c is Control and (c as Control).visible and (c as Control).get_global_rect().has_point(p):
			return true
	return false


func _tab_button(text: String, ch: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(func():
		channel = ch
		AudioManager.play_ui("ui_click", -6.0)
		_refresh_tabs())
	return b


func _refresh_tabs() -> void:
	for pair in [[_tab_all, "all"], [_tab_near, "near"]]:
		var on: bool = pair[1] == channel
		var b: Button = pair[0]
		for st in ["normal", "hover", "focus", "pressed"]:
			var sb := UITheme.box(UITheme.BLUE if on else CHIP, 19, Color(0, 0, 0, 0), 0, 0)
			sb.content_margin_left = 14
			sb.content_margin_right = 14
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_color_override("font_color", Color.WHITE if on else Color(1, 1, 1, 0.75))
		b.add_theme_color_override("font_hover_color", Color.WHITE)


func set_open(on: bool) -> void:
	_open = on
	_box.visible = on
	if on:
		_unread = 0
		_toggle.text = "Chat"
	else:
		_input.release_focus()
		if _menu and is_instance_valid(_menu):
			_menu.queue_free()
	AudioManager.play_ui("ui_click")


func set_room(code: String) -> void:
	_room_lbl.text = ("Sala " + code) if code != "" else ""


func setup_phrases(list: Array, free_chat: bool) -> void:
	for c in _phrases.get_children():
		c.queue_free()
	for i in list.size():
		var idx := i
		_phrases.add_child(_chip(str(list[i]), func(): NetworkManager.send_quick(idx, channel)))
	_input.editable = free_chat
	_input.placeholder_text = "Escreva uma mensagem..." if free_chat else "Um responsável deixou só as frases prontas"
	_send.disabled = not free_chat


func add_line(sender_id: String, text: String, system: bool, ch := "all") -> void:
	var b := Button.new()
	b.text = ("[Perto] " if ch == "near" and not system else "") + text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size = Vector2(480, 26)
	b.add_theme_font_size_override("font_size", 18)
	var col := Color.WHITE
	if system:
		col = Color("ffd27a")
	elif ch == "near":
		col = Color("8ff0b4")
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col)
	if sender_id != "":
		b.pressed.connect(func(): _open_menu(sender_id))
	_lines.add_child(b)
	while _lines.get_child_count() > MAX_LINES:
		var c := _lines.get_child(0)
		_lines.remove_child(c)
		c.queue_free()
	if not _open and not system:
		_unread += 1
		_toggle.text = "Chat %d" % _unread


func _open_menu(target: String) -> void:
	if _menu and is_instance_valid(_menu):
		_menu.queue_free()
	_menu = PanelContainer.new()
	_menu.add_theme_stylebox_override("panel", UITheme.box(Color.WHITE, 18, UITheme.DARK, 3, 3))
	_menu.position = Vector2(530, 64)
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
