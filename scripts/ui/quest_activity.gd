class_name QuestActivity
extends Control
## Atividades jogáveis dentro das missões (tela por cima do jogo):
## - "piano": aprender uma música nota a nota (ouvir -> repetir trecho por trecho),
##   com o nome das notas (Dó, Ré, Mi...) e dica de grave/agudo;
## - "sort": separar cada resíduo na lixeira certa (coleta seletiva);
## - "mix": misturar tintas primárias para descobrir as cores secundárias;
## - "order": tocar os cartões na ordem certa (linha do tempo, ciclo da planta...).
## Emite finished(score 0..1). Feita para toque: botões grandes.

signal finished(score: float)

const NOTE_NAMES := ["Dó", "Ré", "Mi", "Fá", "Sol", "Lá", "Si", "Dó"]
const NOTE_FREQ := [261.63, 293.66, 329.63, 349.23, 392.0, 440.0, 493.88, 523.25]
const KEY_COLORS := ["ff6b6b", "ffa94d", "ffd43b", "69db7c", "38d9a9", "4dabf7", "9775fa", "f783ac"]
## Melodias de domínio público, em trechos (índices em NOTE_NAMES).
const SONGS := [
	{"name": "Brilha, brilha, estrelinha", "parts": [[0, 0, 4, 4, 5, 5, 4], [3, 3, 2, 2, 1, 1, 0], [4, 4, 3, 3, 2, 2, 1], [4, 4, 3, 3, 2, 2, 1]]},
	{"name": "Hino à Alegria (Beethoven)", "parts": [[2, 2, 3, 4, 4, 3, 2, 1], [0, 0, 1, 2, 2, 1, 1], [2, 2, 3, 4, 4, 3, 2, 1], [0, 0, 1, 2, 1, 0, 0]]},
	{"name": "Escala de Dó (aquecimento)", "parts": [[0, 1, 2, 3], [4, 5, 6, 7], [7, 6, 5, 4], [3, 2, 1, 0]]},
]
const BINS := [
	{"id": "papel", "name": "PAPEL", "col": "2f6fd0"},
	{"id": "plastico", "name": "PLÁSTICO", "col": "e03a3a"},
	{"id": "vidro", "name": "VIDRO", "col": "2fa84f"},
	{"id": "metal", "name": "METAL", "col": "f2c12e"},
	{"id": "organico", "name": "ORGÂNICO", "col": "8a5a2b"},
]
const WASTE := [
	["Jornal velho", "papel", "Papel limpo vai na AZUL e vira papel novo!"],
	["Caixa de papelão", "papel", "Papelão é papel: lixeira AZUL."],
	["Folha de caderno", "papel", "Folha de caderno é papel: AZUL."],
	["Garrafa PET", "plastico", "Garrafa PET é plástico: lixeira VERMELHA."],
	["Copo descartável", "plastico", "Copinho descartável é plástico: VERMELHA."],
	["Embalagem de iogurte", "plastico", "Pote de iogurte é plástico: VERMELHA (lave antes!)."],
	["Pote de vidro", "vidro", "Vidro vai na VERDE e pode ser derretido e reusado."],
	["Garrafa de vidro", "vidro", "Garrafa de vidro: lixeira VERDE."],
	["Latinha de suco", "metal", "Latinha é metal (alumínio): AMARELA."],
	["Lata de milho", "metal", "Lata de conserva é metal: AMARELA."],
	["Casca de banana", "organico", "Casca de fruta é orgânico: MARROM. Vira adubo!"],
	["Resto de maçã", "organico", "Resto de comida é orgânico: lixeira MARROM."],
	["Saquinho de chá", "organico", "Saquinho de chá usado é orgânico: MARROM."],
]
const PAINTS := {"vermelho": "e03a3a", "amarelo": "f6c91f", "azul": "2f6fd0"}
const MIXES := {"amarelo+vermelho": ["laranja", "ff8a2a"], "azul+vermelho": ["roxo", "8a4fd0"], "amarelo+azul": ["verde", "3aa45b"]}

var kind := "piano"
var data: Dictionary = {}
var _root: VBoxContainer
var _title: Label
var _info: Label
var _body: Control
var _player: AudioStreamPlayer
var _tones := {}
var _done := false
# piano
var _song: Dictionary
var _part := 0
var _pos := 0
var _keys: Array[Button] = []
var _seq_row: HBoxContainer
var _listening := false
var _mistakes := 0
var _idle := 0.0
# sort
var _queue: Array = []
var _cur: Array = []
var _sorted := 0
var _right := 0
var _item_lbl: Label
# mix
var _goals: Array = []
var _picked: Array[String] = []
var _flask: Panel
var _mix_lbl: Label


static func open(parent: Node, what: String, extra: Dictionary = {}) -> QuestActivity:
	var a := QuestActivity.new()
	a.kind = what
	a.data = extra
	parent.add_child(a)
	return a


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.07, 0.15, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.CREAM, 0.99), 30, UITheme.DARK, 4, 8))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1080, 600)
	panel.position = Vector2(-540, -300)
	add_child(panel)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 12)
	panel.add_child(_root)
	_title = UITheme.title_label("", 40, UITheme.BLUE)
	_root.add_child(_title)
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 24)
	_info.add_theme_color_override("font_color", UITheme.DARK)
	_root.add_child(_info)
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(_body as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	(_body as VBoxContainer).add_theme_constant_override("separation", 16)
	_root.add_child(_body)
	_player = AudioStreamPlayer.new()
	_player.bus = "SFX"
	_player.max_polyphony = 4
	add_child(_player)
	match kind:
		"piano":
			_setup_piano()
		"sort":
			_setup_sort()
		"mix":
			_setup_mix()
		"order":
			_setup_order()
		_:
			_finish(1.0)


func _finish(score: float) -> void:
	if _done:
		return
	_done = true
	finished.emit(score)
	queue_free()


func _big_button(text: String, col: Color, cb: Callable, size := Vector2(170, 90), font := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", font)
	var fc := Color.WHITE if col.get_luminance() < 0.62 else UITheme.DARK
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(st, fc)
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, UITheme.box(col, 20, col.darkened(0.35), 3, 7))
	b.add_theme_stylebox_override("pressed", UITheme.box(col.lightened(0.15), 20, col.darkened(0.35), 3, 2))
	b.add_theme_stylebox_override("disabled", UITheme.box(col.darkened(0.25), 20, col.darkened(0.45), 3, 2))
	b.pressed.connect(cb)
	return b


# ---------------------------------------------------------------- som

## Som de piano sintetizado (harmônicos com decaimento), guardado em cache.
func _tone(freq: float) -> AudioStreamWAV:
	if _tones.has(freq):
		return _tones[freq]
	var rate := 22050
	var n := int(rate * 1.1)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var env := minf(t / 0.006, 1.0) * exp(-t * 3.2)
		var s := sin(TAU * freq * t) + 0.45 * sin(TAU * freq * 2.0 * t) * exp(-t * 2.0) + 0.22 * sin(TAU * freq * 3.0 * t) * exp(-t * 4.0) + 0.08 * sin(TAU * freq * 4.0 * t) * exp(-t * 6.0)
		var v := int(clampf(s * env * 0.42, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	_tones[freq] = w
	return w


func _play_note(i: int) -> void:
	_player.stream = _tone(NOTE_FREQ[i])
	_player.play()


# ---------------------------------------------------------------- piano

func _setup_piano() -> void:
	# primeira vez: Brilha, brilha; depois varia
	var plays := int(SaveManager.section("stats").get("piano_songs", 0))
	_song = SONGS[plays % SONGS.size()]
	SaveManager.section("stats")["piano_songs"] = plays + 1
	_title.text = "Piano: %s" % _song.name
	_seq_row = HBoxContainer.new()
	_seq_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_seq_row.add_theme_constant_override("separation", 8)
	_body.add_child(_seq_row)
	var kb := HBoxContainer.new()
	kb.alignment = BoxContainer.ALIGNMENT_CENTER
	kb.add_theme_constant_override("separation", 6)
	_body.add_child(kb)
	for i in NOTE_NAMES.size():
		var idx := i
		var b := _big_button(NOTE_NAMES[i], Color("fbfbf7"), func(): _press_key(idx), Vector2(112, 230), 26)
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_BOTTOM
		# faixa colorida embaixo de cada tecla ajuda a memorizar
		var strip := ColorRect.new()
		strip.color = Color(KEY_COLORS[i])
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		strip.offset_top = -26
		strip.offset_bottom = -12
		strip.offset_left = 12
		strip.offset_right = -12
		b.add_child(strip)
		_keys.append(b)
		kb.add_child(b)
	var hint := Label.new()
	hint.text = "Da esquerda (grave) para a direita (agudo)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 19)
	hint.add_theme_color_override("font_color", Color("6b7690"))
	_body.add_child(hint)
	_start_part()


func _start_part() -> void:
	_pos = 0
	for c in _seq_row.get_children():
		c.queue_free()
	var part: Array = _song.parts[_part]
	for i in part.size():
		var l := Label.new()
		l.text = NOTE_NAMES[part[i]]
		l.custom_minimum_size = Vector2(78, 44)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_stylebox_override("normal", UITheme.box(Color(KEY_COLORS[part[i]]).lightened(0.35), 14, Color(0, 0, 0, 0), 0, 0))
		_seq_row.add_child(l)
	_info.text = "Trecho %d de %d — ouça primeiro..." % [_part + 1, _song.parts.size()]
	_demo()


func _demo() -> void:
	_listening = true
	_set_keys_enabled(false)
	var part: Array = _song.parts[_part]
	await get_tree().create_timer(0.6).timeout
	for i in part.size():
		if not is_inside_tree():
			return
		_play_note(part[i])
		_flash(part[i], i)
		await get_tree().create_timer(0.48).timeout
	if not is_inside_tree():
		return
	_listening = false
	_set_keys_enabled(true)
	_info.text = "Agora é sua vez! Toque as notas na ordem."
	_mark(0)


func _set_keys_enabled(on: bool) -> void:
	for k in _keys:
		k.disabled = not on


func _flash(key: int, seq_i := -1) -> void:
	var k := _keys[key]
	var tw := create_tween()
	k.modulate = Color(KEY_COLORS[key]).lightened(0.2)
	tw.tween_property(k, "modulate", Color.WHITE, 0.35)
	if seq_i >= 0 and seq_i < _seq_row.get_child_count():
		var l := _seq_row.get_child(seq_i) as Control
		l.scale = Vector2(1.15, 1.15)
		create_tween().tween_property(l, "scale", Vector2.ONE, 0.3)


func _mark(i: int) -> void:
	for j in _seq_row.get_child_count():
		var l := _seq_row.get_child(j) as Label
		l.modulate = Color(1, 1, 1, 0.45) if j < i else Color.WHITE
		l.add_theme_color_override("font_color", UITheme.BLUE if j == i else UITheme.DARK)


func _process(delta: float) -> void:
	if kind != "piano" or _listening or _done or _song.is_empty():
		return
	_idle += delta
	if _idle > 3.0:
		# dica: a próxima tecla pisca
		_idle = 1.8
		var part: Array = _song.parts[_part]
		if _pos < part.size():
			_flash(part[_pos])


func _press_key(i: int) -> void:
	if _listening or _done:
		return
	_idle = 0.0
	_play_note(i)
	_flash(i)
	var part: Array = _song.parts[_part]
	if i == part[_pos]:
		_pos += 1
		_mark(_pos)
		if _pos >= part.size():
			_part += 1
			if _part >= _song.parts.size():
				_info.text = "Você tocou \"%s\" inteira! Bravo!" % _song.name
				_set_keys_enabled(false)
				AudioManager.play_ui("applause", -6.0)
				var score := clampf(1.0 - _mistakes * 0.08, 0.3, 1.0)
				get_tree().create_timer(1.8).timeout.connect(func(): _finish(score))
			else:
				_info.text = "Isso! Próximo trecho..."
				AudioManager.play_ui("ui_confirm", -6.0)
				get_tree().create_timer(0.9).timeout.connect(_start_part)
	else:
		_mistakes += 1
		var want: int = part[_pos]
		var dir := "mais AGUDA (à direita)" if want > i else "mais GRAVE (à esquerda)"
		_info.text = "Essa foi %s. A certa é %s, uma nota %s." % [NOTE_NAMES[i], NOTE_NAMES[want], dir]
		_flash(want)


# ---------------------------------------------------------------- coleta seletiva

func _setup_sort() -> void:
	_title.text = "Coleta seletiva"
	_info.text = "Toque na lixeira certa para cada resíduo."
	var pool := WASTE.duplicate()
	pool.shuffle()
	# garante pelo menos um de cada tipo
	var by_type := {}
	for w in pool:
		if not by_type.has(w[1]):
			by_type[w[1]] = w
	_queue = by_type.values()
	for w in pool:
		if _queue.size() >= 8:
			break
		if not (w in _queue):
			_queue.append(w)
	_queue.shuffle()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.box(Color.WHITE, 24, Color("c9c3b4"), 3, 5))
	card.custom_minimum_size = Vector2(520, 120)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body.add_child(card)
	_item_lbl = UITheme.title_label("", 44)
	_item_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(_item_lbl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_body.add_child(row)
	for b in BINS:
		var id: String = b.id
		var btn := _big_button(b.name, Color(b.col), func(): _drop(id), Vector2(184, 170), 24)
		# "boca" da lixeira
		var lid := ColorRect.new()
		lid.color = Color(0, 0, 0, 0.28)
		lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lid.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		lid.offset_left = 22
		lid.offset_right = -22
		lid.offset_top = 16
		lid.offset_bottom = 30
		btn.add_child(lid)
		row.add_child(btn)
	_next_item()


func _next_item() -> void:
	if _queue.is_empty():
		var score := float(_right) / maxf(float(_sorted), 1.0)
		_item_lbl.text = "Tudo separado!"
		_info.text = "Você acertou %d de %d de primeira. Reciclar economiza água, energia e árvores!" % [_right, _sorted]
		AudioManager.play_ui("applause", -6.0)
		get_tree().create_timer(2.2).timeout.connect(func(): _finish(score))
		return
	_cur = _queue.pop_front()
	_sorted += 1
	_item_lbl.text = _cur[0]
	_item_lbl.modulate = Color.WHITE
	_mistakes = 0


func _drop(bin_id: String) -> void:
	if _done or _cur.is_empty():
		return
	if bin_id == _cur[1]:
		if _mistakes == 0:
			_right += 1
		AudioManager.play_ui("pickup")
		_info.text = "Certo! " + str(_cur[2])
		_cur = []
		var tw := create_tween()
		tw.tween_property(_item_lbl, "modulate", Color(1, 1, 1, 0), 0.25)
		tw.tween_callback(_next_item)
	else:
		_mistakes += 1
		AudioManager.play_ui("bonk", -8.0)
		_info.text = "Ops! Não é aí. Dica: " + str(_cur[2])


# ---------------------------------------------------------------- mistura de cores

func _setup_mix() -> void:
	_title.text = "Laboratório: mistura de cores"
	_goals = MIXES.keys()
	_goals.shuffle()
	_flask = Panel.new()
	_flask.custom_minimum_size = Vector2(200, 200)
	_flask.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body.add_child(_flask)
	_mix_lbl = UITheme.title_label("", 30)
	_body.add_child(_mix_lbl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_body.add_child(row)
	for p in PAINTS:
		var name: String = p
		row.add_child(_big_button(name.capitalize(), Color(PAINTS[p]), func(): _add_paint(name), Vector2(200, 96), 28))
	row.add_child(_big_button("Esvaziar", Color("d9d4c7"), func(): _reset_flask(), Vector2(170, 96), 24))
	_reset_flask()


func _goal_name() -> String:
	return str(MIXES[_goals[0]][0]) if not _goals.is_empty() else ""


func _reset_flask() -> void:
	_picked.clear()
	_paint_flask(Color(1, 1, 1, 0.6))
	_mix_lbl.text = "Frasco vazio"
	if not _goals.is_empty():
		_info.text = "Faça a cor %s misturando DUAS tintas." % _goal_name().to_upper()


func _paint_flask(c: Color) -> void:
	_flask.add_theme_stylebox_override("panel", UITheme.box(c, 100, UITheme.DARK, 5, 0))


func _add_paint(p: String) -> void:
	if _done or _goals.is_empty():
		return
	AudioManager.play_ui("drink", -8.0)
	if _picked.size() >= 2 or p in _picked:
		_picked.clear()
	_picked.append(p)
	if _picked.size() == 1:
		_paint_flask(Color(PAINTS[p]))
		_mix_lbl.text = p.capitalize() + " + ..."
		return
	var key_parts := _picked.duplicate()
	key_parts.sort()
	var key := "+".join(key_parts)
	var res: Array = MIXES.get(key, ["?", "777777"])
	_paint_flask(Color(res[1]))
	_mix_lbl.text = "%s + %s = %s" % [_picked[0].capitalize(), _picked[1].capitalize(), str(res[0]).to_upper()]
	if res[0] == _goal_name():
		_goals.pop_front()
		AudioManager.play_ui("ui_confirm")
		if _goals.is_empty():
			_info.text = "Você descobriu as 3 cores SECUNDÁRIAS: laranja, roxo e verde! Vermelho, amarelo e azul são as PRIMÁRIAS."
			get_tree().create_timer(2.6).timeout.connect(func(): _finish(clampf(1.0 - _mistakes * 0.15, 0.3, 1.0)))
		else:
			_info.text = "Isso! Agora faça %s." % _goal_name().to_upper()
			get_tree().create_timer(1.3).timeout.connect(func():
				if not _done:
					_picked.clear()
					_paint_flask(Color(1, 1, 1, 0.6))
					_mix_lbl.text = "Frasco limpo")
	else:
		_mistakes += 1
		_info.text = "Deu %s, não %s. Esvazie e tente outra dupla!" % [res[0], _goal_name()]


# ---------------------------------------------------------------- ordenar

var _order: Array = []
var _order_i := 0
var _slots: HBoxContainer


func _setup_order() -> void:
	_title.text = str(data.get("title", "Coloque em ordem"))
	_info.text = str(data.get("hint", "Toque nos cartões na ordem certa."))
	_order = data.get("items", [])
	_slots = HBoxContainer.new()
	_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots.add_theme_constant_override("separation", 10)
	_body.add_child(_slots)
	for i in _order.size():
		var l := Label.new()
		l.text = "%d" % (i + 1)
		l.custom_minimum_size = Vector2(floorf((1010.0 - 10.0 * (_order.size() - 1)) / maxf(_order.size(), 1)), 96)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", UITheme.DARK)
		l.add_theme_stylebox_override("normal", UITheme.box(Color(1, 1, 1, 0.6), 14, Color("c9c3b4"), 2, 0))
		_slots.add_child(l)
	var cards := HFlowContainer.new()
	cards.alignment = FlowContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("h_separation", 12)
	cards.add_theme_constant_override("v_separation", 12)
	_body.add_child(cards)
	var shuffled := _order.duplicate()
	while shuffled == _order and _order.size() > 1:
		shuffled.shuffle()
	var cols := ["ff8a3d", "2f8be0", "3aa45b", "9775fa", "e04a3a", "f2c12e"]
	for i in shuffled.size():
		var txt: String = shuffled[i]
		var b := _big_button(txt, Color(cols[i % cols.size()]), func(): pass, Vector2(240, 84), 21)
		b.pressed.connect(_pick_card.bind(txt, b))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cards.add_child(b)


func _pick_card(txt: String, b: Button) -> void:
	if _done or _order_i >= _order.size():
		return
	if txt == _order[_order_i]:
		AudioManager.play_ui("pickup")
		var l := _slots.get_child(_order_i) as Label
		l.text = txt
		l.add_theme_stylebox_override("normal", UITheme.box(Color("c8f0d2"), 14, UITheme.GREEN, 3, 0))
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.35)
		_order_i += 1
		if _order_i >= _order.size():
			_info.text = str(data.get("success", "Perfeito, tudo em ordem!"))
			AudioManager.play_ui("applause", -6.0)
			get_tree().create_timer(2.2).timeout.connect(func(): _finish(clampf(1.0 - _mistakes * 0.15, 0.3, 1.0)))
		else:
			_info.text = "Isso! E depois?"
	else:
		_mistakes += 1
		AudioManager.play_ui("bonk", -8.0)
		_info.text = "Ainda não é a vez de \"%s\". Pense no que vem antes!" % txt
