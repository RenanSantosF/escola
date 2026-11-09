class_name SettingsPanel
extends PanelContainer
## Painel de configurações (gráficos, áudio, controles). Reutilizado no
## menu principal e na pausa.

signal closed


func _ready() -> void:
	theme = UITheme.get_theme()
	custom_minimum_size = Vector2(760, 0)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 470)
	margin.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	scroll.add_child(v)
	v.add_child(UITheme.title_label("Configurações", 38))

	v.add_child(_section("Gráficos"))
	var q := HBoxContainer.new()
	q.add_theme_constant_override("separation", 10)
	q.alignment = BoxContainer.ALIGNMENT_CENTER
	var names := ["Baixa", "Média", "Alta"]
	var group := ButtonGroup.new()
	for i in 3:
		var b := Button.new()
		b.text = names[i]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(190, 60)
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = Settings.quality() == i
		var idx := i
		b.pressed.connect(func():
			AudioManager.play_ui("ui_click")
			Settings.set_value("quality", idx))
		b.add_theme_stylebox_override("pressed", UITheme.box(UITheme.ORANGE, 18, UITheme.DARK, 3, 3))
		q.add_child(b)
	v.add_child(q)
	v.add_child(_check("Limitar a 30 FPS (economiza bateria)", "fps_limit_30"))
	v.add_child(_check("Mostrar FPS", "show_fps"))

	v.add_child(_section("Áudio"))
	v.add_child(_slider("Música", "music_volume", 0.0, 1.0))
	v.add_child(_slider("Efeitos", "sfx_volume", 0.0, 1.0))
	v.add_child(_slider("Ambiente", "ambient_volume", 0.0, 1.0))

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
			GameManager.show_toast("Idade atualizada: atividades do %s" % Learning.grade_name())), 420)
	v.add_child(age_btn)

	v.add_child(_section("Controles"))
	v.add_child(_slider("Sensibilidade da câmera", "camera_sensitivity", 0.3, 2.5))
	v.add_child(_slider("Opacidade dos botões", "controls_opacity", 0.3, 1.0))
	v.add_child(_check("Inverter eixo vertical da câmera", "invert_y"))

	var close := UITheme.make_button("Voltar", func(): closed.emit(), 260)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)


func _section(text: String) -> Control:
	var l := UITheme.title_label(text, 26, UITheme.BLUE)
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
