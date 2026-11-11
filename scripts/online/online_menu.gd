class_name OnlineMenu
extends PanelContainer
## Tela "Amigos" do menu:
##  - lista dos amigos (quem está na escola agora aparece com "Entrar");
##  - pedidos de amizade recebidos (Aceitar / Recusar);
##  - adicionar amigo pelo NOME DE JOGADOR (o outro precisa aceitar);
##  - criar sala (aparece o código para falar ao amigo) ou entrar com código.

signal chosen(mode: String, code: String)
signal back

var _status: Label
var _main: VBoxContainer
var _pad: VBoxContainer
var _code_lbl: Label
var _code := ""
var _busy := false
var _list_box: VBoxContainer
var _add_edit: LineEdit
var _add_btn: Button
var _add_msg: Label
var _refresh_t := 0.0
var _loading := false
var last_mode := ""
var friends: Array = []


func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.box(Color(1, 1, 1, 0.97), 22, UITheme.LINE, 2, 0))
	custom_minimum_size = Vector2(900, 0)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	root.add_child(UITheme.title_label("Amigos", 46, UITheme.NAVY))

	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 12)
	root.add_child(_main)
	# adicionar pelo nome
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 10)
	_main.add_child(add_row)
	_add_edit = LineEdit.new()
	_add_edit.placeholder_text = "Nome de jogador do amigo (ex.: Foguete_Azul)"
	_add_edit.custom_minimum_size = Vector2(0, 62)
	_add_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_edit.max_length = 16
	_add_edit.add_theme_font_size_override("font_size", 24)
	for st in ["normal", "focus"]:
		var eb := UITheme.box(Color.WHITE, 14, UITheme.TEAL if st == "focus" else Color("c5cfe0"), 3, 0)
		eb.content_margin_left = 16
		_add_edit.add_theme_stylebox_override(st, eb)
	_add_edit.add_theme_color_override("font_color", UITheme.DARK)
	_add_edit.add_theme_color_override("font_placeholder_color", Color("9aa5b8"))
	_add_edit.add_theme_color_override("caret_color", UITheme.DARK)
	_add_edit.text_submitted.connect(func(_t): _add_friend())
	add_row.add_child(_add_edit)
	_add_btn = _small_btn("Adicionar", UITheme.TEAL, _add_friend, 190)
	add_row.add_child(_add_btn)
	_add_msg = Label.new()
	_add_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_msg.add_theme_font_size_override("font_size", 18)
	_add_msg.add_theme_color_override("font_color", Color("6b7690"))
	_add_msg.text = "O amigo precisa aceitar o pedido. Só adicione quem você conhece!"
	_main.add_child(_add_msg)
	# lista
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	scroll.add_theme_stylebox_override("panel", UITheme.box(Color("eef3fb"), 16))
	_main.add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_list_box)
	# criar sala / entrar com código
	var rr := HBoxContainer.new()
	rr.add_theme_constant_override("separation", 12)
	_main.add_child(rr)
	rr.add_child(_big("Criar sala", "Aparece um código: fale para o amigo", Color("22c55e"), func(): _go("create", "")))
	rr.add_child(_big("Entrar com código", "Digite o código que o amigo falou", UITheme.NAVY_2, _open_pad))

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
		b.custom_minimum_size = Vector2(150, 70)
		b.add_theme_font_size_override("font_size", 34 if k.length() == 1 and k != "<" else 24)
		var col := UITheme.TEAL if k == "OK" else (UITheme.RED if k == "<" else Color.WHITE)
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
	var bk := UITheme.make_button("Voltar", func():
		if _pad.visible:
			_pad.visible = false
			_main.visible = true
			_status.text = ""
		else:
			NetworkManager.leave()
			_busy = false
			back.emit(), 240)
	bk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(bk)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _pad.visible:
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 10.0
		refresh_list()


# ---------------------------------------------------------- lista

func refresh_list() -> void:
	if _loading:
		return
	_loading = true
	var r: Dictionary = await AccountManager.friends_list()
	_loading = false
	if not is_inside_tree():
		return
	if r.get("ok", false):
		friends = r.get("list", [])
		_build_list()
	elif friends.is_empty():
		_clear_list()
		_list_box.add_child(_info_row(str(r.get("error", "Não deu para carregar os amigos agora."))))


func _clear_list() -> void:
	for c in _list_box.get_children():
		c.queue_free()


func _build_list() -> void:
	_clear_list()
	if friends.is_empty():
		_list_box.add_child(_info_row("Você ainda não tem amigos aqui. Adicione pelo nome de jogador ali em cima!"))
		return
	for f in friends:
		_list_box.add_child(_friend_row(f))


func _info_row(text: String) -> Control:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(820, 90)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", Color("6b7690"))
	return l


func _friend_row(f: Dictionary) -> Control:
	var st := str(f.get("status", ""))
	var on := bool(f.get("online", false))
	var row := PanelContainer.new()
	var bg := Color("fff7d6") if st == "incoming" else Color.WHITE
	var sb := UITheme.box(bg, 14, Color("d8e0ee"), 2, 0)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	# bolinha com a inicial (verde = na escola agora)
	var av := Label.new()
	var name := str(f.get("name", "?"))
	av.text = name.substr(0, 1).to_upper()
	av.custom_minimum_size = Vector2(52, 52)
	av.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.add_theme_font_override("font", UITheme.bold_font())
	av.add_theme_font_size_override("font_size", 26)
	av.add_theme_color_override("font_color", Color.WHITE)
	var col := Color("22c55e") if on else (Color("ffb020") if st == "incoming" else Color("9aa5b8"))
	var ab := StyleBoxFlat.new()
	ab.bg_color = col
	ab.set_corner_radius_all(26)
	av.add_theme_stylebox_override("normal", ab)
	h.add_child(av)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	v.add_child(UITheme.title_label(name, 24, UITheme.DARK))
	(v.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color("6b7690"))
	v.add_child(sub)
	var id := str(f.get("id", ""))
	match st:
		"incoming":
			sub.text = "quer ser seu amigo!"
			h.add_child(_small_btn("Aceitar", Color("22c55e"), func(): _accept(id), 140))
			h.add_child(_small_btn("Recusar", Color("e05a4a"), func(): _remove(id), 130))
		"outgoing":
			sub.text = "pedido enviado · esperando aceitar"
			h.add_child(_small_btn("Cancelar", Color("9aa5b8"), func(): _remove(id), 140))
		_:
			if on:
				var full := bool(f.get("full", false))
				sub.text = "na escola agora · sala %s · %d jogando" % [str(f.get("code", "")), int(f.get("players", 0))]
				sub.add_theme_color_override("font_color", Color("15803d"))
				var code := str(f.get("code", ""))
				var go := _small_btn("Sala cheia" if full else "Entrar", Color("22c55e"), func(): _go("code", code), 150)
				go.disabled = full
				h.add_child(go)
			else:
				sub.text = "fora do jogo"
			var rm := _small_btn("x", Color("cfd6e3"), func(): _confirm_remove(id, name), 56)
			rm.tooltip_text = "Desfazer amizade"
			h.add_child(rm)
	return row


func _small_btn(text: String, col: Color, cb: Callable, w := 150) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 56)
	b.add_theme_font_size_override("font_size", 22)
	for s in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(s, UITheme.box(col, 14, col.darkened(0.3), 0, 4))
	b.add_theme_stylebox_override("pressed", UITheme.box(col.darkened(0.12), 14, col.darkened(0.3), 0, 1))
	b.add_theme_stylebox_override("disabled", UITheme.box(Color("dfe4ec"), 14, Color("c5ccd8"), 0, 2))
	b.add_theme_color_override("font_color", Color.WHITE if col.get_luminance() < 0.7 else UITheme.DARK)
	b.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		cb.call())
	return b


func _add_friend() -> void:
	var n := _add_edit.text.strip_edges()
	if n.length() < 3:
		_say_add("Digite o nome de jogador do amigo.", true)
		return
	_add_btn.disabled = true
	_say_add("Procurando...", false)
	var r: Dictionary = await AccountManager.friend_add(n)
	_add_btn.disabled = false
	if r.get("ok", false):
		_add_edit.text = ""
		_say_add(str(r.get("text", "Pedido enviado!")), false)
		AudioManager.play_ui("reward", -6.0)
		friends = r.get("list", friends)
		_build_list()
	else:
		_say_add(str(r.get("error", "Não deu certo. Tente de novo.")), true)


func _say_add(t: String, err: bool) -> void:
	_add_msg.text = t
	_add_msg.add_theme_color_override("font_color", UITheme.RED if err else Color("15803d"))


func _accept(id: String) -> void:
	var r: Dictionary = await AccountManager.friend_accept(id)
	if r.get("ok", false):
		AudioManager.play_ui("reward", -6.0)
		friends = r.get("list", friends)
		_build_list()


func _remove(id: String) -> void:
	var r: Dictionary = await AccountManager.friend_remove(id)
	if r.get("ok", false):
		friends = r.get("list", friends)
		_build_list()


func _confirm_remove(id: String, name: String) -> void:
	var d := ConfirmationDialog.new()
	d.dialog_text = "Desfazer a amizade com %s?" % name
	d.ok_button_text = "Desfazer"
	d.cancel_button_text = "Não"
	add_child(d)
	d.confirmed.connect(func(): _remove(id))
	d.visibility_changed.connect(func():
		if not d.visible:
			d.queue_free())
	d.popup_centered()


# ---------------------------------------------------------- salas

func _big(title: String, desc: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 90)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, UITheme.box(col, 16, col.darkened(0.3), 0, 5))
	b.add_theme_stylebox_override("pressed", UITheme.box(col.darkened(0.12), 16, col.darkened(0.3), 0, 1))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var l1 := UITheme.title_label(title, 30, Color.WHITE)
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l1)
	var l2 := Label.new()
	l2.text = desc
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.add_theme_font_size_override("font_size", 17)
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
	_refresh_t = 0.0  # recarrega a lista ao abrir
