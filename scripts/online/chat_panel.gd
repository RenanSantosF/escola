class_name ChatPanel
extends Control
## Chat seguro para crianças:
## - dois canais: "Todos" (a sala inteira) e "Perto de mim" (até 18 m)
## - frases rápidas sempre; texto livre só se liberado por responsável/13+
## - reações (acenar, comemorar, palmas...) que os outros veem no personagem
## - botão para chamar a sala para um pique-pega
## - tocar numa mensagem abre Denunciar / Bloquear
## Mostra só as últimas mensagens (nada fica salvo no aparelho).

signal tag_pressed

const MAX_LINES := 6
const REASONS := [["linguagem", "Palavras feias"], ["assedio", "Me incomodando"],
	["dados_pessoais", "Pediu dados pessoais"], ["nome_inadequado", "Nome estranho"], ["outro", "Outro motivo"]]
const REACTIONS := [["Acenar", "wave"], ["Comemorar", "celebrate"], ["Palmas", "clap"], ["Levantar a mão", "raise_hand"]]

var channel := "all"
var player: PlayerController
var _open := false
var _toggle: Button
var _box: PanelContainer
var _lines: VBoxContainer
var _phrases: GridContainer
var _input: LineEdit
var _menu: PanelContainer
var _tab_all: Button
var _tab_near: Button
var _unread := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(16, 230)
	size = Vector2(470, 440)
	_toggle = UITheme.make_button("Chat", func(): set_open(not _open), 130)
	_toggle.position = Vector2.ZERO
	add_child(_toggle)
	var tag := UITheme.make_button("Pique-pega!", func():
		AudioManager.play_ui("ui_click")
		tag_pressed.emit(), 190)
	tag.position = Vector2(140, 0)
	for st in ["normal", "hover", "focus"]:
		tag.add_theme_stylebox_override(st, UITheme.box(Color("ff4d6d"), 18, UITheme.DARK, 3, 5))
	tag.add_theme_color_override("font_color", Color.WHITE)
	add_child(tag)
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.CREAM, 0.95), 18, UITheme.DARK, 3, 3))
	_box.position = Vector2(0, 70)
	_box.custom_minimum_size = Vector2(470, 0)
	_box.visible = false
	add_child(_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_box.add_child(v)
	# canais
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	_tab_all = _tab_button("Todos da sala", "all")
	_tab_near = _tab_button("Perto de mim", "near")
	tabs.add_child(_tab_all)
	tabs.add_child(_tab_near)
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
	# reações
	var rx := HBoxContainer.new()
	rx.add_theme_constant_override("separation", 4)
	v.add_child(rx)
	for r in REACTIONS:
		var em: String = r[1]
		var b := Button.new()
		b.text = r[0]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		b.custom_minimum_size = Vector2(112, 38)
		b.add_theme_stylebox_override("normal", UITheme.box(Color("ffe08a"), 12, UITheme.DARK, 2, 3))
		b.add_theme_color_override("font_color", UITheme.DARK)
		b.pressed.connect(func():
			if player:
				player.emote(em))
		rx.add_child(b)
	_input = LineEdit.new()
	_input.placeholder_text = "Escreva (sem dados pessoais)..."
	_input.max_length = 80
	_input.visible = false
	_input.text_submitted.connect(func(t):
		NetworkManager.send_chat(t, channel)
		_input.text = "")
	v.add_child(_input)
	_refresh_tabs()


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
	b.custom_minimum_size = Vector2(200, 40)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func():
		channel = ch
		AudioManager.play_ui("ui_click", -6.0)
		_refresh_tabs())
	return b


func _refresh_tabs() -> void:
	for pair in [[_tab_all, "all"], [_tab_near, "near"]]:
		var on: bool = pair[1] == channel
		var b: Button = pair[0]
		for st in ["normal", "hover", "focus"]:
			b.add_theme_stylebox_override(st, UITheme.box(UITheme.BLUE if on else Color("e4e9f2"), 12, UITheme.DARK if on else Color(0, 0, 0, 0), 2 if on else 0, 3))
		b.add_theme_color_override("font_color", Color.WHITE if on else UITheme.DARK)
		b.add_theme_color_override("font_hover_color", Color.WHITE if on else UITheme.DARK)


func set_open(on: bool) -> void:
	_open = on
	_box.visible = on
	if on:
		_unread = 0
		_toggle.text = "Chat"
	AudioManager.play_ui("ui_click")


func setup_phrases(list: Array, free_chat: bool) -> void:
	for c in _phrases.get_children():
		c.queue_free()
	for i in list.size():
		var idx := i
		var b := Button.new()
		b.text = str(list[i])
		b.add_theme_font_size_override("font_size", 14)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(150, 38)
		b.tooltip_text = str(list[i])
		b.pressed.connect(func(): NetworkManager.send_quick(idx, channel))
		_phrases.add_child(b)
	_input.visible = free_chat


func add_line(sender_id: String, text: String, system: bool, ch := "all") -> void:
	var b := Button.new()
	b.text = ("[Perto] " if ch == "near" and not system else "") + text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.custom_minimum_size = Vector2(450, 30)
	b.add_theme_font_size_override("font_size", 17)
	var col := UITheme.DARK
	if system:
		col = UITheme.ORANGE.darkened(0.2)
	elif ch == "near":
		col = Color("1f7a4a")
	b.add_theme_color_override("font_color", col)
	if sender_id != "":
		b.pressed.connect(func(): _open_menu(sender_id))
	_lines.add_child(b)
	while _lines.get_child_count() > MAX_LINES:
		var c := _lines.get_child(0)
		_lines.remove_child(c)
		c.queue_free()
	if not _open and not system:
		_unread += 1
		_toggle.text = "Chat (%d)" % _unread


func _open_menu(target: String) -> void:
	if _menu:
		_menu.queue_free()
	_menu = PanelContainer.new()
	_menu.add_theme_stylebox_override("panel", UITheme.box(Color.WHITE, 18, UITheme.DARK, 3, 3))
	_menu.position = Vector2(480, 70)
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
