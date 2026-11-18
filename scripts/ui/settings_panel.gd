class_name SettingsPanel
extends PanelContainer
## Painel de configurações (gráficos, áudio, controles). Reutilizado no
## menu principal e na pausa.

signal closed


const PAGES := [["geral", "Geral"], ["audio", "Som"], ["controles", "Controles"], ["conta", "Conta e privacidade"]]
var _page := "geral"
var _body: VBoxContainer
var _page_btns := {}


func _ready() -> void:
	theme = UITheme.get_theme()
	custom_minimum_size = Vector2(920, 560)
	add_theme_stylebox_override("panel", UITheme.card(UITheme.CARD, 18))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	var title := UITheme.title_label("Configurações", 32, UITheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UITheme.make_button("Fechar", func(): closed.emit(), 140)
	close.custom_minimum_size = Vector2(140, 52)
	UITheme.style_button(close, UITheme.CARD_2, true)
	close.add_theme_font_size_override("font_size", 20)
	head.add_child(close)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	root.add_child(body)
	# menu das seções (esquerda)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(230, 0)
	nav.add_theme_constant_override("separation", 8)
	body.add_child(nav)
	for pg in PAGES:
		var pid: String = pg[0]
		var b := Button.new()
		b.text = pg[1]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(230, 54)
		b.add_theme_font_size_override("font_size", 21)
		b.pressed.connect(func():
			AudioManager.play_ui("ui_click")
			_page = pid
			_build_page())
		nav.add_child(b)
		_page_btns[pid] = b
	# conteúdo da seção (direita)
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 12
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 16)
	scroll.add_child(_body)
	_build_page()


func _build_page() -> void:
	for pid in _page_btns.keys():
		var on: bool = pid == _page
		UITheme.style_button(_page_btns[pid], UITheme.ACCENT_SOFT if on else UITheme.CARD, true, 10)
		_page_btns[pid].add_theme_color_override("font_color", UITheme.ACCENT if on else UITheme.INK_2)
		_page_btns[pid].add_theme_color_override("font_hover_color", UITheme.ACCENT if on else UITheme.INK)
		for st in ["normal", "hover", "pressed"]:
			var sb := UITheme.box(UITheme.ACCENT_SOFT if on else Color(0, 0, 0, 0), 10)
			sb.content_margin_left = 16
			_page_btns[pid].add_theme_stylebox_override(st, sb)
	for c in _body.get_children():
		c.queue_free()
	var v := _body
	match _page:
		"geral":
			v.add_child(_section("Qualidade dos gráficos"))
			var q := HBoxContainer.new()
			q.add_theme_constant_override("separation", 10)
			var names := ["Baixa", "Média", "Alta"]
			for i in 3:
				var idx := i
				var b := UITheme.chip(names[i], Settings.quality() == i, func():
					Settings.set_value("quality", idx)
					_build_page(), 21)
				b.custom_minimum_size = Vector2(150, 54)
				q.add_child(b)
			v.add_child(q)
			v.add_child(_hint("Baixa deixa o jogo mais leve em celulares simples."))
			v.add_child(_check("Limitar a 30 FPS (economiza bateria)", "fps_limit_30"))
			v.add_child(_check("Mostrar FPS", "show_fps"))
			v.add_child(_check("Notificações (amigo online e lembretes)", "notifications"))
			v.add_child(_section("Atividades da aula"))
			var age_btn := UITheme.make_button("Idade: %d anos (%s)" % [Learning.age(), Learning.grade_name()], func():
				var layer := CanvasLayer.new()
				layer.layer = 30
				get_tree().root.add_child(layer)
				var picker := AgePicker.new()
				picker.process_mode = Node.PROCESS_MODE_ALWAYS
				layer.add_child(picker)
				picker.confirmed.connect(func(_a):
					layer.queue_free()
					GameManager.show_toast("Idade atualizada: atividades do %s" % Learning.grade_name())
					_build_page()), 420)
			UITheme.style_button(age_btn, UITheme.CARD_2, true)
			age_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			v.add_child(age_btn)
		"audio":
			v.add_child(_section("Volume"))
			v.add_child(_slider("Música", "music_volume", 0.0, 1.0))
			v.add_child(_slider("Efeitos", "sfx_volume", 0.0, 1.0))
			v.add_child(_slider("Ambiente", "ambient_volume", 0.0, 1.0))
		"controles":
			v.add_child(_section("Câmera e botões"))
			v.add_child(_slider("Sensibilidade da câmera", "camera_sensitivity", 0.3, 2.5))
			v.add_child(_slider("Opacidade dos botões", "controls_opacity", 0.3, 1.0))
			v.add_child(_check("Inverter eixo vertical da câmera", "invert_y"))
		"conta":
			v.add_child(_section("Minha conta"))
			var acc_lbl := UITheme.text_label(("Apelido: %s" % AccountManager.nickname()) if AccountManager.has_account() else "Sem conta neste celular.", 22, UITheme.INK)
			v.add_child(acc_lbl)
			if AccountManager.has_account():
				var del_btn := UITheme.make_button("Apagar minha conta", func(): pass, 360)
				UITheme.style_button(del_btn, Color("ef4444"))
				del_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				var confirm := [false]
				del_btn.pressed.connect(func():
					if not confirm[0]:
						confirm[0] = true
						del_btn.text = "Toque de novo para APAGAR tudo"
						return
					del_btn.disabled = true
					del_btn.text = "Apagando..."
					var ok: bool = await AccountManager.delete_account()
					del_btn.text = "Conta apagada" if ok else "Sem conexão. Tente depois."
					if ok:
						get_tree().reload_current_scene())
				v.add_child(del_btn)
			v.add_child(_section("Privacidade"))
			v.add_child(_check("Enviar estatísticas anônimas (tempo de jogo, compras com moedas do jogo)", "share_stats"))
	UITheme.scroll_friendly(v)


func _hint(text: String) -> Label:
	return UITheme.text_label(text, 17, UITheme.INK_2, true)


func _section(text: String) -> Control:
	var l := UITheme.title_label(text, 24, UITheme.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


func _slider(text: String, key: String, mn: float, mx: float) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.05
	s.value = float(Settings.get_value(key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 44)
	s.focus_mode = Control.FOCUS_NONE
	var val := Label.new()
	val.custom_minimum_size = Vector2(70, 0)
	val.text = "%d%%" % int(s.value / mx * 100.0) if key != "camera_sensitivity" else "%.1fx" % s.value
	s.value_changed.connect(func(x: float):
		Settings.set_value(key, x, false)
		val.text = "%d%%" % int(x / mx * 100.0) if key != "camera_sensitivity" else "%.1fx" % x)
	s.drag_ended.connect(func(_c): Settings.save_settings())
	h.add_child(s)
	h.add_child(val)
	return h


func _check(text: String, key: String) -> Control:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = bool(Settings.get_value(key))
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on: bool):
		AudioManager.play_ui("ui_click")
		Settings.set_value(key, on))
	return c
