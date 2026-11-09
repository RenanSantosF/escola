class_name ClassroomUI
extends Control
## Painel das tarefas da aula com visual de lousa. Mostra uma tarefa por
## vez (escolha, ordenar, ligar, achar objeto) e dá feedback visual/sonoro.

signal answered(correct: bool)
signal find_accepted

const BOARD := Color("2f5a43")
const CHALK := Color("f4f4ee")

var _panel: PanelContainer
var _header: Label
var _prompt: Label
var _body: VBoxContainer
var _feedback: Label
var _dots: HBoxContainer
var _task: Dictionary = {}
var _locked := false
var _order_seq: Array = []
var _match_left := -1
var _match_done := 0
var _match_errors := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.get_theme()
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	var sb := UITheme.box(BOARD, 18, Color("8a5a32"), 10)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = Vector2(780, 0)
	center.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_panel.add_child(v)
	var top := HBoxContainer.new()
	_header = UITheme.title_label("", 22, Color("ffe08a"))
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_header)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 6)
	top.add_child(_dots)
	v.add_child(top)
	_prompt = UITheme.title_label("", 34, CHALK)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.custom_minimum_size = Vector2(700, 0)
	v.add_child(_prompt)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	_body.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_body)
	_feedback = UITheme.title_label("", 30, Color.WHITE)
	_feedback.custom_minimum_size = Vector2(0, 40)
	v.add_child(_feedback)


func show_task(task: Dictionary, index: int, total: int, results: Array) -> void:
	_task = task
	_locked = false
	_feedback.text = ""
	_header.text = "Tarefa %d de %d  ·  %s" % [index + 1, total, task.subject]
	_prompt.text = task.prompt
	for c in _dots.get_children():
		c.queue_free()
	for i in total:
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(18, 18)
		d.color = Color(1, 1, 1, 0.25)
		if i < results.size():
			d.color = Color("6be36b") if results[i] else Color("e05a4a")
		elif i == index:
			d.color = Color("ffe08a")
		_dots.add_child(d)
	for c in _body.get_children():
		c.queue_free()
	match task.type:
		"math", "word", "quiz":
			_build_choice()
		"order":
			_build_order()
		"match":
			_build_match()
		"find":
			_build_find()
	visible = true
	_panel.scale = Vector2(0.9, 0.9)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.3)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.2)


func hide_panel() -> void:
	visible = false


func _chalk_button(text: String, w := 330) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 66)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 30 if text.length() < 14 else 24)
	b.add_theme_stylebox_override("normal", UITheme.box(Color("fdf6e3"), 14, Color("c9b98f"), 0, 5))
	b.add_theme_stylebox_override("hover", UITheme.box(Color("fffaf0"), 14, Color("c9b98f"), 0, 5))
	b.add_theme_stylebox_override("pressed", UITheme.box(Color("ffe08a"), 14, Color("c9a03f"), 0, 2))
	return b


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 12)
	var c := CenterContainer.new()
	c.add_child(g)
	_body.add_child(c)
	return g


# ------------------------------------------------------------ escolha

func _build_choice() -> void:
	var g := _grid(2)
	for i in _task.options.size():
		var b := _chalk_button(str(_task.options[i]))
		var idx = i
		b.pressed.connect(func(): _on_choice(idx, b))
		g.add_child(b)


func _on_choice(i: int, b: Button) -> void:
	if _locked:
		return
	_locked = true
	var ok := ClassroomTasks.check_choice(_task, i)
	_color_button(b, ok)
	if not ok:
		# mostra a resposta certa
		var g := (_body.get_child(0) as CenterContainer).get_child(0)
		_color_button(g.get_child(int(_task.answer)), true)
	_finish(ok, "" if ok else "A resposta era: %s" % _task.options[_task.answer])


func _color_button(b: Button, ok: bool) -> void:
	var col := Color("6be36b") if ok else Color("ff8a7a")
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, UITheme.box(col, 14, col.darkened(0.3), 0, 5))


# ------------------------------------------------------------ ordenar

func _build_order() -> void:
	_order_seq = []
	var g := _grid(mini(_task.items.size(), 5))
	for i in _task.items.size():
		var b := _chalk_button(str(_task.items[i]), 150)
		var idx = i
		b.pressed.connect(func(): _on_order(idx, b))
		g.add_child(b)
	var reset := UITheme.make_button("Recomeçar", func(): _reset_order(g), 220)
	reset.custom_minimum_size = Vector2(220, 50)
	reset.add_theme_font_size_override("font_size", 22)
	var c := CenterContainer.new()
	c.add_child(reset)
	_body.add_child(c)


func _on_order(i: int, b: Button) -> void:
	if _locked or i in _order_seq:
		return
	_order_seq.append(i)
	b.text = "%d. %s" % [_order_seq.size(), _task.items[i]]
	b.add_theme_stylebox_override("normal", UITheme.box(Color("ffe08a"), 14, Color("c9a03f"), 0, 3))
	AudioManager.play_ui("ui_click", -6.0, 0.1)
	if _order_seq.size() == _task.items.size():
		_locked = true
		var ok := ClassroomTasks.check_order(_task, _order_seq)
		var right := []
		for k in _task.answer_order:
			right.append(_task.items[k])
		_finish(ok, "" if ok else "Ordem certa: " + " ".join(right))


func _reset_order(g: GridContainer) -> void:
	if _locked:
		return
	_order_seq = []
	for i in g.get_child_count():
		var b := g.get_child(i) as Button
		b.text = str(_task.items[i])
		b.add_theme_stylebox_override("normal", UITheme.box(Color("fdf6e3"), 14, Color("c9b98f"), 0, 5))


# ------------------------------------------------------------ ligar

func _build_match() -> void:
	_match_left = -1
	_match_done = 0
	_match_errors = 0
	var g := _grid(2)
	var lefts := []
	var rights := []
	for i in _task.left.size():
		var bl := _chalk_button(str(_task.left[i]), 300)
		var br := _chalk_button(str(_task.right[i]), 300)
		lefts.append(bl)
		rights.append(br)
		g.add_child(bl)
		g.add_child(br)
	for i in lefts.size():
		var idx := i
		lefts[i].pressed.connect(func(): _on_match_left(idx, lefts))
		rights[i].pressed.connect(func(): _on_match_right(idx, lefts, rights))


func _on_match_left(i: int, lefts: Array) -> void:
	if _locked or lefts[i].disabled:
		return
	_match_left = i
	for k in lefts.size():
		if not lefts[k].disabled:
			lefts[k].add_theme_stylebox_override("normal", UITheme.box(Color("ffe08a") if k == i else Color("fdf6e3"), 14, Color("c9b98f"), 0, 5))


func _on_match_right(j: int, lefts: Array, rights: Array) -> void:
	if _locked or _match_left == -1 or rights[j].disabled:
		return
	if ClassroomTasks.check_match(_task, _match_left, j):
		_color_button(lefts[_match_left], true)
		_color_button(rights[j], true)
		lefts[_match_left].disabled = true
		rights[j].disabled = true
		_match_done += 1
		AudioManager.play_ui("pickup", -6.0)
		_match_left = -1
		if _match_done == _task.left.size():
			_locked = true
			_finish(_match_errors <= 1, "" if _match_errors <= 1 else "Quase! Muitos erros desta vez.")
	else:
		_match_errors += 1
		AudioManager.play_ui("bonk", -12.0, 0.1)
		var b: Button = rights[j]
		var tw := create_tween()
		tw.tween_property(b, "modulate", Color(1, 0.5, 0.5), 0.1)
		tw.tween_property(b, "modulate", Color.WHITE, 0.25)


# ------------------------------------------------------------ achar objeto

func _build_find() -> void:
	var b := _chalk_button("Pode deixar!", 320)
	b.pressed.connect(func():
		visible = false
		find_accepted.emit())
	var c := CenterContainer.new()
	c.add_child(b)
	_body.add_child(c)


# ------------------------------------------------------------ feedback

func _finish(ok: bool, extra: String) -> void:
	_feedback.text = ("Muito bem! +10" if ok else "Não foi dessa vez...") + ("" if extra == "" else "\n" + extra)
	_feedback.add_theme_color_override("font_color", Color("9dff9d") if ok else Color("ffb3a8"))
	AudioManager.play_ui("ui_confirm" if ok else "bonk", -2.0 if ok else -10.0)
	if not ok:
		var tw := create_tween()
		var p := _panel.position
		for k in 4:
			tw.tween_property(_panel, "position", p + Vector2(10 if k % 2 == 0 else -10, 0), 0.04)
		tw.tween_property(_panel, "position", p, 0.04)
	get_tree().create_timer(1.6 if ok else 2.4).timeout.connect(func():
		visible = false
		answered.emit(ok))
