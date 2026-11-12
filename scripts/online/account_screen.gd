class_name AccountScreen
extends PanelContainer
## Criar conta / Entrar.
## Criar: idade -> NOME ÚNICO digitado (checado na hora se está livre) ->
## senha (2x). O nome é o login. Entrar: nome + senha, em qualquer celular.
## Sem e-mail ou telefone. O nome é filtrado (palavrões, dados pessoais).

signal done(imported: bool)
signal back

var _v: VBoxContainer
var _status: Label
var _age := 9
var _busy := false
var _name_ok := false
var _check_seq := 0


func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.box(Color(1, 1, 1, 0.97), 16, UITheme.LINE, 2, 0))
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
	_v.add_child(UITheme.title_label(t, 44, UITheme.NAVY))
	if sub != "":
		var l := Label.new()
		l.text = sub
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 22)
		_v.add_child(l)


func _big(text: String, col: Color, cb: Callable, w := 620) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 72)
	b.add_theme_font_size_override("font_size", 30)
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, UITheme.box(col, 10, col.darkened(0.3), 0, 4))
	b.add_theme_stylebox_override("pressed", UITheme.box(col.darkened(0.12), 10, col.darkened(0.3), 0, 1))
	b.add_theme_stylebox_override("disabled", UITheme.box(Color("d5dbe6"), 10, Color("aab3c5"), 0, 2))
	b.add_theme_color_override("font_color", Color.WHITE if col.get_luminance() < 0.7 else UITheme.DARK)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		cb.call())
	_v.add_child(b)
	return b


func _field(placeholder: String, secret := false) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.custom_minimum_size = Vector2(560, 66)
	e.add_theme_font_size_override("font_size", 28)
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	e.max_length = 40
	for st in ["normal", "focus"]:
		e.add_theme_stylebox_override(st, UITheme.box(Color.WHITE, 10, UITheme.TEAL if st == "focus" else UITheme.LINE, 2, 0))
	_v.add_child(e)
	return e


func _hint(text: String, col := UITheme.DARK) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", col)
	_v.add_child(l)
	return l


func _set_status(t: String, err := false) -> void:
	_status.text = t
	_status.add_theme_color_override("font_color", UITheme.RED if err else UITheme.DARK)


# ---------------------------------------------------------------- telas

func show_start() -> void:
	_clear()
	_title("Bem-vindo ao Recess Club!", "Crie seu nome de jogador e uma senha. Não pedimos e-mail nem telefone.")
	_big("Criar minha conta", UITheme.TEAL, _ask_age)
	_big("Já tenho conta: Entrar", UITheme.NAVY_2, show_login)
	if AccountManager.has_account():
		_big("Voltar", Color("e3e8f2"), func(): back.emit(), 300)


func _ask_age() -> void:
	visible = false
	var p := AgePicker.new()
	get_parent().add_child(p)
	p.confirmed.connect(func(a):
		_age = a
		p.queue_free()
		visible = true
		show_gender())


## Menino ou menina (muda o visual de partida; dá para trocar depois na mochila).
func show_gender() -> void:
	_clear()
	_title("Você é...", "Toque no seu personagem! (dá para girar arrastando)")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_v.add_child(row)
	var base: CharacterAppearance = Progression.appearance_with()
	for girl in [false, true]:
		var col := Color("3e8bff") if not girl else Color("ff4d9a")
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 8)
		row.add_child(card)
		var st := CharacterStage.new()
		st.custom_minimum_size = Vector2(240, 300)
		st.podium_color = col
		st.base_dist = 3.4
		card.add_child(st)
		var a := CharacterAppearance.from_dict(base.to_dict())
		a.set_girl(girl)
		st.set_appearance.call_deferred(a)
		var g: bool = girl
		st.tapped.connect(func():
			st.play("celebrate")
			get_tree().create_timer(0.8).timeout.connect(func(): _set_gender(g)))
		var b := _big("Menina" if girl else "Menino", col, func(): _set_gender(g), 240)
		b.get_parent().remove_child(b)
		card.add_child(b)


func _set_gender(girl: bool) -> void:
	var pl := GameManager.player
	if pl and pl.get("visual"):
		var a: CharacterAppearance = pl.visual.appearance
		a.set_girl(girl)
		pl.set_appearance(a)
	else:
		var d: Dictionary = SaveManager.section("player").get("appearance", {})
		d["girl"] = girl
		SaveManager.section("player")["appearance"] = d
	show_signup()


func show_signup() -> void:
	_clear()
	_name_ok = false
	_title("Crie sua conta", "Seu NOME DE JOGADOR é único e serve para entrar. Não use seu nome verdadeiro nem sobrenome!")
	var name_edit := _field("Nome de jogador (ex.: Foguete_Azul)")
	name_edit.max_length = 16
	var name_hint := _hint("3 a 16 letras, números ou _", Color("6b7690"))
	var pw := _field("Senha (mínimo 6)", true)
	var pw2 := _field("Repita a senha", true)
	var pw_hint := _hint("Peça para um adulto anotar a senha num lugar seguro.", Color("6b7690"))
	var create := _big("Criar conta", UITheme.TEAL, func(): pass, 420)
	create.disabled = true
	var refresh := func():
		var ok_pw := pw.text.length() >= 6 and pw.text == pw2.text
		if pw2.text != "" and pw.text != pw2.text:
			pw_hint.text = "As senhas estão diferentes."
			pw_hint.add_theme_color_override("font_color", UITheme.RED)
		elif pw.text != "" and pw.text.length() < 6:
			pw_hint.text = "A senha precisa de pelo menos 6 caracteres."
			pw_hint.add_theme_color_override("font_color", UITheme.RED)
		else:
			pw_hint.text = "Peça para um adulto anotar a senha num lugar seguro."
			pw_hint.add_theme_color_override("font_color", Color("6b7690"))
		create.disabled = not (_name_ok and ok_pw) or _busy
	pw.text_changed.connect(func(_t): refresh.call())
	pw2.text_changed.connect(func(_t): refresh.call())
	name_edit.text_changed.connect(func(t: String):
		_name_ok = false
		refresh.call()
		_check_seq += 1
		var seq := _check_seq
		if t.strip_edges().length() < 3:
			name_hint.text = "3 a 16 letras, números ou _"
			name_hint.add_theme_color_override("font_color", Color("6b7690"))
			return
		name_hint.text = "Verificando..."
		name_hint.add_theme_color_override("font_color", Color("6b7690"))
		# espera a criança parar de digitar um pouquinho
		await get_tree().create_timer(0.45).timeout
		if seq != _check_seq or not is_inside_tree():
			return
		var res: Dictionary = await AccountManager.check_name(t.strip_edges())
		if seq != _check_seq or not is_inside_tree():
			return
		_name_ok = bool(res.get("available", false))
		if _name_ok:
			name_hint.text = "✔ \"%s\" está livre!" % t.strip_edges()
			name_hint.add_theme_color_override("font_color", UITheme.GREEN.darkened(0.2))
		else:
			name_hint.text = "✘ " + str(res.get("reason", "Indisponível."))
			name_hint.add_theme_color_override("font_color", UITheme.RED)
		refresh.call())
	create.pressed.connect(func(): _signup(name_edit.text.strip_edges(), pw.text))
	_big("Voltar", Color("e3e8f2"), show_start, 300)


func _signup(nick: String, pw: String) -> void:
	if _busy:
		return
	_busy = true
	_set_status("Criando sua conta...")
	var r: Dictionary = await AccountManager.signup(nick, pw, _age)
	_busy = false
	if not r.get("ok", false):
		_set_status(str(r.get("error", "Não deu certo. Tente de novo.")), true)
		return
	_set_status("Conta criada! Bem-vindo, %s!" % nick)
	await get_tree().create_timer(0.8).timeout
	done.emit(false)


func show_login() -> void:
	_clear()
	_title("Entrar", "Digite seu nome de jogador e sua senha.")
	var name_edit := _field("Nome de jogador")
	var pw := _field("Senha", true)
	pw.text_submitted.connect(func(_t): _login(name_edit.text.strip_edges(), pw.text))
	_big("Entrar", UITheme.TEAL, func(): _login(name_edit.text.strip_edges(), pw.text), 420)
	_big("Voltar", Color("e3e8f2"), show_start, 300)


func _login(nick: String, pw: String) -> void:
	if _busy or nick == "" or pw == "":
		return
	_busy = true
	_set_status("Entrando...")
	var r: Dictionary = await AccountManager.login(nick, pw)
	_busy = false
	if not r.get("ok", false):
		_set_status(str(r.get("error", "Nome ou senha errados.")), true)
		return
	_set_status("Bem-vindo de volta, %s!" % AccountManager.nickname())
	done.emit(bool(r.get("imported", false)))
