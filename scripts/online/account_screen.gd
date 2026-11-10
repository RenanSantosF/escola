class_name AccountScreen
extends PanelContainer
## Criar conta / entrar com código de recuperação.
## 1) Criar: idade -> escolher apelido (lista do servidor) -> mostrar o código
##    de recuperação ("anote com um adulto").
## 2) Já tenho conta: digitar o código (palavras + número).

signal done(imported: bool)
signal back

var _v: VBoxContainer
var _status: Label
var _age := 9
var _busy := false


func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.CREAM, 0.98), 28, UITheme.DARK, 4, 6))
	custom_minimum_size = Vector2(820, 0)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	_v = VBoxContainer.new()
	_v.add_theme_constant_override("separation", 12)
	root.add_child(_v)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 22)
	root.add_child(_status)
	show_start()


func _clear() -> void:
	for c in _v.get_children():
		c.queue_free()
	_status.text = ""


func _title(t: String, sub := "") -> void:
	_v.add_child(UITheme.title_label(t, 46, UITheme.BLUE))
	if sub != "":
		var l := Label.new()
		l.text = sub
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 23)
		_v.add_child(l)


func _big(text: String, col: Color, cb: Callable, w := 620) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 76)
	b.add_theme_font_size_override("font_size", 30)
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, UITheme.box(col, 22, col.darkened(0.35), 3, 6))
	b.add_theme_stylebox_override("pressed", UITheme.box(col.darkened(0.12), 22, col.darkened(0.35), 3, 2))
	b.add_theme_color_override("font_color", Color.WHITE if col.get_luminance() < 0.7 else UITheme.DARK)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		cb.call())
	_v.add_child(b)
	return b


func _set_status(t: String, err := false) -> void:
	_status.text = t
	_status.add_theme_color_override("font_color", UITheme.RED if err else UITheme.DARK)


# ---------------------------------------------------------------- telas

func show_start() -> void:
	_clear()
	_title("Bem-vindo ao Recreio!", "Para jogar com a turma, crie sua conta. Não pedimos nome, e-mail nem telefone.")
	_big("Criar minha conta", UITheme.GREEN, _ask_age)
	_big("Já tenho conta (tenho o código)", UITheme.BLUE, show_recover)
	_big("Voltar", Color("d9d4c7"), func(): back.emit(), 300)


func _ask_age() -> void:
	visible = false
	var p := AgePicker.new()
	get_parent().add_child(p)
	p.confirmed.connect(func(a):
		_age = a
		p.queue_free()
		visible = true
		show_names())


func show_names() -> void:
	_clear()
	_title("Escolha seu apelido", "Esse é o nome que os colegas vão ver. Para sua segurança, ele é escolhido da lista.")
	_set_status("Carregando nomes...")
	var names: Array = await AccountManager.fetch_names()
	if not is_inside_tree():
		return
	_status.text = ""
	if names.is_empty():
		_set_status("Sem conexão com o servidor. Confira a internet e tente de novo.", true)
		_big("Tentar de novo", UITheme.ORANGE, show_names, 360)
		_big("Voltar", Color("d9d4c7"), show_start, 300)
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var cc := CenterContainer.new()
	cc.add_child(grid)
	_v.add_child(cc)
	var cols := [Color("ff8a3d"), Color("2f8be0"), Color("2fae6a"), Color("9b59ff"), Color("e84393"), Color("14b8a6")]
	for i in names.size():
		var nick: String = names[i]
		var b := Button.new()
		b.text = nick
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(360, 70)
		b.add_theme_font_size_override("font_size", 27)
		var col: Color = cols[i % cols.size()]
		for st in ["normal", "hover", "focus"]:
			b.add_theme_stylebox_override(st, UITheme.box(col, 20, col.darkened(0.35), 3, 5))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.pressed.connect(func(): _create(nick))
		grid.add_child(b)
	_big("Ver outros nomes", Color("ffcf3f"), show_names, 360)


func _create(nick: String) -> void:
	if _busy:
		return
	_busy = true
	_set_status("Criando sua conta...")
	var r: Dictionary = await AccountManager.register(nick, _age)
	_busy = false
	if not r.get("ok", false):
		_set_status(str(r.get("error", "Não deu certo. Tente de novo.")), true)
		return
	_show_code(nick, str(r.get("code", "")))


func _show_code(nick: String, code: String) -> void:
	_clear()
	_title("Conta criada, %s!" % nick, "Este é o seu CÓDIGO SECRETO. Anote num papel ou mostre para um adulto guardar. Com ele você entra em outro celular sem perder nada.")
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(Color("1f2a44"), 18, Color("ffcf3f"), 4, 0))
	var l := UITheme.title_label(code.replace("-", "  "), 40, Color("ffe08a"))
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_v.add_child(p)
	var warn := Label.new()
	warn.text = "Não mostre o código para outras crianças do jogo."
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.add_theme_font_size_override("font_size", 20)
	warn.add_theme_color_override("font_color", UITheme.RED)
	_v.add_child(warn)
	_big("Já anotei! Vamos jogar", UITheme.GREEN, func(): done.emit(false))


func show_recover() -> void:
	_clear()
	_title("Entrar com o código", "Digite as 4 palavras e o número do seu código secreto.")
	var edit := LineEdit.new()
	edit.placeholder_text = "Ex.: BOLA SOL LUA RIO 47"
	edit.custom_minimum_size = Vector2(620, 68)
	edit.add_theme_font_size_override("font_size", 30)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	edit.max_length = 60
	_v.add_child(edit)
	_big("Entrar", UITheme.GREEN, func(): _recover(edit.text), 360)
	_big("Voltar", Color("d9d4c7"), show_start, 300)


func _recover(code: String) -> void:
	if _busy or code.strip_edges() == "":
		return
	_busy = true
	_set_status("Procurando sua conta...")
	var r: Dictionary = await AccountManager.recover(code)
	_busy = false
	if not r.get("ok", false):
		_set_status(str(r.get("error", "Código não encontrado.")), true)
		return
	_set_status("Bem-vindo de volta, %s!" % AccountManager.nickname())
	done.emit(bool(r.get("imported", false)))
