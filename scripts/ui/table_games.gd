class_name TableGames
extends Control
## Jogos de mesa da Sala de Jogos e da Sala de Xadrez, numa tela própria:
##   xadrez (regras completas, contra o computador), pingue-pongue (arraste o
##   dedo para mexer a raquete), jogo da velha e jogo da memória.
## Abra com TableGames.open(hud, tipo, ao_fechar). Vitória dá XP uma vez por dia.

signal closed(won: bool)

const TITLES := {"xadrez": "Xadrez", "pingpong": "Pingue-pongue", "velha": "Jogo da Velha", "memoria": "Jogo da Memória"}
const XP := {"xadrez": 12, "pingpong": 8, "velha": 4, "memoria": 5}
const INK := Color("2d3047")

var kind := "xadrez"
var _board: Control
var _status: Label
var _title: Label
var _level := 1
var _level_btn: Button
var _won_any := false
var _phase0 := -1


static func open(hud: Control, k: String, on_close: Callable) -> TableGames:
	var t := TableGames.new()
	t.kind = k
	t.closed.connect(func(w): on_close.call(w))
	hud.add_child(t)
	return t


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50  # por cima do contador de aula e dos avisos da HUD
	var sd := get_tree().get_first_node_in_group("school_day")
	if sd:
		_phase0 = int(sd.phase)
	_build()
	_new_round()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.16, 0.86)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	match kind:
		"xadrez":
			_board = _Chess.new()
		"pingpong":
			_board = _Pong.new()
		"velha":
			_board = _Tic.new()
		_:
			_board = _Memory.new()
	_board.set("ui", self)
	add_child(_board)
	var side := VBoxContainer.new()
	side.name = "Side"
	side.add_theme_constant_override("separation", 14)
	add_child(side)
	_title = UITheme.title_label(TITLES.get(kind, kind), 40, Color("ffd27a"))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_title)
	_status = Label.new()
	_status.add_theme_font_override("font", UITheme.bold_font())
	_status.add_theme_font_size_override("font_size", 26)
	_status.add_theme_color_override("font_color", Color.WHITE)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 120)
	side.add_child(_status)
	if kind in ["xadrez", "pingpong", "velha"]:
		_level_btn = UITheme.make_button("", func():
			_level = 1 - _level
			_paint_level()
			_new_round(), 300)
		side.add_child(_level_btn)
		_paint_level()
	side.add_child(UITheme.make_button("Recomeçar", _new_round, 300))
	var quit := UITheme.make_button("Sair", func(): close(), 300)
	quit.add_theme_stylebox_override("normal", UITheme.box(Color("e74c3c"), 18, Color("a93226"), 0, 5))
	side.add_child(quit)
	resized.connect(_layout)
	_layout()


func _paint_level() -> void:
	if _level_btn:
		_level_btn.text = "Nível: " + ("Fácil" if _level == 0 else "Normal")


func _layout() -> void:
	var vs := size
	if vs.x < 10.0:
		vs = get_viewport_rect().size
	var side: Control = get_node("Side")
	var landscape := vs.x >= vs.y * 1.1
	if landscape:
		var bs := minf(vs.y * 0.9, vs.x - 380.0)
		var w := bs if kind != "pingpong" else bs * 0.62
		_board.position = Vector2((vs.x - 340.0 - w) * 0.5, (vs.y - bs) * 0.5)
		_board.size = Vector2(w, bs)
		side.position = Vector2(vs.x - 330.0, vs.y * 0.12)
		side.size = Vector2(300, vs.y * 0.8)
	else:
		var bs2 := minf(vs.x * 0.94, vs.y * 0.62)
		var w2 := bs2 if kind != "pingpong" else bs2 * 0.62
		_board.position = Vector2((vs.x - w2) * 0.5, vs.y * 0.05)
		_board.size = Vector2(w2, bs2)
		side.position = Vector2((vs.x - 300.0) * 0.5, vs.y * 0.05 + bs2 + 16.0)
		side.size = Vector2(300, vs.y * 0.3)


func _process(_delta: float) -> void:
	# o sinal tocou (aula/fim do recreio): fecha sozinho
	var sd := get_tree().get_first_node_in_group("school_day")
	if sd and _phase0 >= 0 and int(sd.phase) != _phase0:
		GameManager.show_toast("O sinal tocou! O jogo de mesa ficou para depois.")
		close()


func _new_round() -> void:
	_board.call("reset", _level)


func set_status(t: String) -> void:
	_status.text = t


## O jogo acabou: won 1 = venceu, 0 = empate, -1 = perdeu.
func finish(won: int, text: String) -> void:
	set_status(text)
	if won > 0:
		_won_any = true
		AudioManager.play_ui("win", -4.0)
		var st: Dictionary = SaveManager.section("stats")
		var done: Dictionary = st.get("atividades_dia", {})
		var today := int(SaveManager.section("progress").get("days_completed", 0))
		var k := "mesa_" + kind
		if int(done.get(k, -1)) != today:
			done[k] = today
			st["atividades_dia"] = done
			GameManager.add_rewards(int(XP.get(kind, 4)), 0)
			GameManager.show_toast("Venceu no %s! (+%d XP)" % [TITLES.get(kind, kind), int(XP.get(kind, 4))])
		GameManager.add_stat("vitorias_mesa")
	elif won < 0:
		AudioManager.play_ui("lose", -6.0)
	else:
		AudioManager.play_ui("reward", -6.0)


func close() -> void:
	if is_queued_for_deletion():
		return
	set_process(false)
	closed.emit(_won_any)
	queue_free()


# ====================================================================== xadrez

class _Chess extends Control:
	var ui: TableGames
	var st: Dictionary
	var sel := -1
	var targets: Array = []
	var last: Array = []
	var level := 1
	var over := false
	var thinking := false

	func reset(lv: int) -> void:
		level = lv
		st = ChessRules.new_game()
		sel = -1
		targets = []
		last = []
		over = false
		thinking = false
		ui.set_status("Você joga com as BRANCAS.\nToque numa peça e depois onde ela vai.")
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		var pos := Vector2.ZERO
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pos = e.position
		else:
			return
		accept_event()
		if over or thinking or st.turn != "w":
			return
		var cs := size.x / 8.0
		var sq := int(pos.y / cs) * 8 + int(pos.x / cs)
		if sq < 0 or sq >= 64:
			return
		for m in targets:
			if m[1] == sq:
				_play(m)
				return
		if ChessRules.side_of(st.b[sq]) == "w":
			sel = sq
			targets = ChessRules.legal_moves(st).filter(func(m): return m[0] == sq)
			AudioManager.play_ui("ui_click", -10.0)
		else:
			sel = -1
			targets = []
		queue_redraw()

	func _play(m: Array) -> void:
		var capture: bool = st.b[m[1]] != ""
		st = ChessRules.apply(st, m)
		last = m
		sel = -1
		targets = []
		AudioManager.play_ui("clack" if not capture else "catch", -6.0)
		queue_redraw()
		if _check_end():
			return
		if st.turn == "b":
			thinking = true
			ui.set_status("O computador está pensando...")
			await get_tree().create_timer(0.35).timeout
			if not is_inside_tree() or over:
				return
			var mv := ChessRules.pick_move(st, level)
			thinking = false
			if not mv.is_empty():
				_play(mv)
		else:
			ui.set_status("Xeque! Proteja o seu rei." if ChessRules.in_check(st, "w") else "Sua vez.")

	func _check_end() -> bool:
		var s := ChessRules.status(st)
		if s == "":
			return false
		over = true
		if s == "mate":
			if st.turn == "b":
				ui.finish(1, "XEQUE-MATE!\nVocê venceu!")
			else:
				ui.finish(-1, "Xeque-mate...\nO computador venceu. Tente de novo!")
		else:
			ui.finish(0, "Empate!")
		return true

	func _draw() -> void:
		var cs := size.x / 8.0
		var check_k := ChessRules.king_sq(st.b, st.turn) if ChessRules.in_check(st, st.turn) else -1
		for sq in 64:
			var r := sq / 8
			var c := sq % 8
			var rect := Rect2(c * cs, r * cs, cs, cs)
			var col := Color("fff3d6") if (r + c) % 2 == 0 else Color("6fbf9a")
			if sq == sel:
				col = Color("ffd23f")
			elif not last.is_empty() and (sq == last[0] or sq == last[1]):
				col = col.lerp(Color("ffe680"), 0.55)
			if sq == check_k:
				col = Color("ff6b6b")
			draw_rect(rect, col)
			var p: String = st.b[sq]
			if p != "":
				TableGames.draw_piece(self, p.to_lower(), ChessRules.is_white(p), rect)
		for m in targets:
			var t: int = m[1]
			var center := Vector2((t % 8 + 0.5) * cs, (t / 8 + 0.5) * cs)
			if st.b[t] != "":
				draw_arc(center, cs * 0.44, 0, TAU, 32, Color(0.1, 0.5, 0.2, 0.75), cs * 0.07, true)
			else:
				draw_circle(center, cs * 0.14, Color(0.1, 0.45, 0.2, 0.6))
		draw_rect(Rect2(Vector2.ZERO, size), Color("3d2b1f"), false, 6.0)


## Peça de xadrez desenhada em vetor (não depende de fonte com símbolos).
static func draw_piece(ci: CanvasItem, t: String, white: bool, r: Rect2) -> void:
	var fill := Color("fdfaf2") if white else Color("2d3047")
	var line := Color("2d3047") if white else Color("e8e8f0")
	var lw := maxf(r.size.x * 0.035, 1.5)
	var P := func(pts: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for q in pts:
			out.append(r.position + Vector2(q[0], q[1]) * r.size)
		return out
	var shape := func(pts: Array) -> void:
		var poly: PackedVector2Array = P.call(pts)
		ci.draw_colored_polygon(poly, fill)
		poly.append(poly[0])
		ci.draw_polyline(poly, line, lw, true)
	var circle := func(x: float, y: float, rad: float) -> void:
		var c := r.position + Vector2(x, y) * r.size
		ci.draw_circle(c, rad * r.size.x, fill)
		ci.draw_arc(c, rad * r.size.x, 0, TAU, 24, line, lw, true)
	# sombrinha e base
	ci.draw_circle(r.position + Vector2(0.5, 0.86) * r.size, r.size.x * 0.05, Color(0, 0, 0, 0))
	match t:
		"p":
			shape.call([[0.34, 0.8], [0.42, 0.52], [0.58, 0.52], [0.66, 0.8]])
			circle.call(0.5, 0.4, 0.13)
		"r":
			shape.call([[0.32, 0.8], [0.34, 0.42], [0.66, 0.42], [0.68, 0.8]])
			shape.call([[0.27, 0.43], [0.27, 0.2], [0.37, 0.2], [0.37, 0.28], [0.45, 0.28], [0.45, 0.2], [0.55, 0.2], [0.55, 0.28], [0.63, 0.28], [0.63, 0.2], [0.73, 0.2], [0.73, 0.43]])
		"n":
			shape.call([[0.3, 0.8], [0.38, 0.55], [0.26, 0.48], [0.28, 0.36], [0.44, 0.2], [0.48, 0.1], [0.56, 0.18], [0.7, 0.3], [0.74, 0.52], [0.68, 0.8]])
			ci.draw_circle(r.position + Vector2(0.47, 0.3) * r.size, r.size.x * 0.035, line)
		"b":
			shape.call([[0.34, 0.8], [0.42, 0.55], [0.58, 0.55], [0.66, 0.8]])
			circle.call(0.5, 0.42, 0.15)
			circle.call(0.5, 0.2, 0.055)
			ci.draw_line(r.position + Vector2(0.45, 0.36) * r.size, r.position + Vector2(0.56, 0.46) * r.size, line, lw, true)
		"q":
			shape.call([[0.32, 0.8], [0.38, 0.52], [0.62, 0.52], [0.68, 0.8]])
			shape.call([[0.3, 0.54], [0.24, 0.24], [0.38, 0.38], [0.44, 0.18], [0.5, 0.36], [0.56, 0.18], [0.62, 0.38], [0.76, 0.24], [0.7, 0.54]])
			for q in [[0.24, 0.22], [0.44, 0.16], [0.56, 0.16], [0.76, 0.22]]:
				circle.call(q[0], q[1], 0.04)
		"k":
			shape.call([[0.32, 0.8], [0.38, 0.5], [0.62, 0.5], [0.68, 0.8]])
			shape.call([[0.3, 0.52], [0.3, 0.34], [0.7, 0.34], [0.7, 0.52]])
			shape.call([[0.46, 0.34], [0.46, 0.24], [0.38, 0.24], [0.38, 0.17], [0.46, 0.17], [0.46, 0.08], [0.54, 0.08], [0.54, 0.17], [0.62, 0.17], [0.62, 0.24], [0.54, 0.24], [0.54, 0.34]])
	shape.call([[0.24, 0.9], [0.26, 0.8], [0.74, 0.8], [0.76, 0.9]])


# ================================================================ pingue-pongue

class _Pong extends Control:
	var ui: TableGames
	var level := 1
	var me := 0
	var cpu := 0
	var px := 0.5  # raquetes (fração da largura)
	var cx := 0.5
	var target_x := 0.5
	var ball := Vector2(0.5, 0.5)  # em frações (x da largura, y da altura)
	var vel := Vector2.ZERO
	var serve_t := 1.2
	var server := 0  # 0 = eu saco, 1 = computador
	var rally := 0
	var over := false
	var _cpu_err := 0.0
	const PAD_W := 0.24
	const PAD_Y_ME := 0.9
	const PAD_Y_CPU := 0.1
	const BALL_R := 0.028
	const TO := 7

	func reset(lv: int) -> void:
		level = lv
		me = 0
		cpu = 0
		over = false
		server = 0
		_serve_setup()
		ui.set_status("Arraste o dedo na mesa para mexer a raquete.\nQuem fizer %d pontos vence!" % TO)

	func _serve_setup() -> void:
		serve_t = 1.0
		rally = 0
		vel = Vector2.ZERO
		ball = Vector2(px if server == 0 else cx, PAD_Y_ME - 0.05 if server == 0 else PAD_Y_CPU + 0.05)

	func _gui_input(e: InputEvent) -> void:
		# o toque chega como mouse (emulação do Godot): um evento só por toque
		if e is InputEventMouseMotion or e is InputEventMouseButton:
			target_x = clampf(e.position.x / maxf(size.x, 1.0), PAD_W * 0.5, 1.0 - PAD_W * 0.5)
			accept_event()

	func _process(delta: float) -> void:
		if over or size.x < 10.0:
			return
		var asp := size.y / size.x  # a bola anda igual nos dois eixos
		px = move_toward(px, target_x, delta * 3.2)
		if serve_t > 0.0:
			serve_t -= delta
			ball = Vector2(px if server == 0 else cx, PAD_Y_ME - 0.05 if server == 0 else PAD_Y_CPU + 0.05)
			if serve_t <= 0.0:
				var dir := -1.0 if server == 0 else 1.0
				vel = Vector2(randf_range(-0.25, 0.25), dir * 0.62)
				AudioManager.play_ui("ball_bounce", -6.0)
		else:
			ball.x += vel.x * delta
			ball.y += vel.y * delta / asp
			if ball.x < BALL_R or ball.x > 1.0 - BALL_R:
				ball.x = clampf(ball.x, BALL_R, 1.0 - BALL_R)
				vel.x = -vel.x
				AudioManager.play_ui("ball_bounce", -12.0)
			# minha raquete
			if vel.y > 0.0 and ball.y >= PAD_Y_ME - 0.02 and ball.y <= PAD_Y_ME + 0.03 and absf(ball.x - px) < PAD_W * 0.5 + BALL_R:
				_hit((ball.x - px) / (PAD_W * 0.5), -1.0)
			elif vel.y < 0.0 and ball.y <= PAD_Y_CPU + 0.02 and ball.y >= PAD_Y_CPU - 0.03 and absf(ball.x - cx) < PAD_W * 0.5 + BALL_R:
				_hit((ball.x - cx) / (PAD_W * 0.5), 1.0)
			if ball.y > 1.02:
				_point(1)
			elif ball.y < -0.02:
				_point(0)
		# computador: segue a bola com um errinho e velocidade limitada
		var aim := ball.x + _cpu_err if vel.y < 0.0 else 0.5
		var cpu_speed := (0.95 if level == 0 else 1.35) + rally * 0.03
		cx = move_toward(cx, clampf(aim, PAD_W * 0.5, 1.0 - PAD_W * 0.5), delta * cpu_speed)
		queue_redraw()

	func _hit(off: float, dir: float) -> void:
		rally += 1
		var speed := minf(vel.length() * 1.06, 1.7)
		vel = Vector2(clampf(off, -1.0, 1.0) * 0.75 + randf_range(-0.05, 0.05), dir * maxf(speed * 0.8, 0.55))
		if vel.length() < speed:
			vel = vel.normalized() * speed
		if dir > 0.0:
			# o computador erra a mira de vez em quando
			_cpu_err = 0.0
		else:
			_cpu_err = randf_range(-1.0, 1.0) * (0.16 if level == 0 else 0.1)
		AudioManager.play_ui_pitch("ball_bounce", 1.0 + minf(rally * 0.03, 0.4), -4.0)

	func _point(who: int) -> void:
		if who == 0:
			me += 1
			AudioManager.play_ui("point", -4.0)
		else:
			cpu += 1
			AudioManager.play_ui("bonk", -8.0)
		if me >= TO or cpu >= TO:
			over = true
			if me > cpu:
				ui.finish(1, "Você venceu de %d a %d!" % [me, cpu])
			else:
				ui.finish(-1, "O computador venceu de %d a %d.\nTente de novo!" % [cpu, me])
			queue_redraw()
			return
		server = 1 - server if (me + cpu) % 2 == 0 else server
		ui.set_status("Você %d  x  %d Computador" % [me, cpu])
		_serve_setup()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(-8, -8, w + 16, h + 16), Color("2c3e50"))
		draw_rect(Rect2(0, 0, w, h), Color("1e6fd0"))
		draw_rect(Rect2(0, 0, w, h), Color.WHITE, false, 4.0)
		draw_line(Vector2(w * 0.5, 0), Vector2(w * 0.5, h), Color(1, 1, 1, 0.6), 2.0)
		draw_rect(Rect2(-10, h * 0.5 - 3, w + 20, 6), Color("ecf0f1"))
		var pw := PAD_W * w
		draw_rect(Rect2(cx * w - pw * 0.5, PAD_Y_CPU * h - 9, pw, 18), Color("e74c3c"))
		draw_rect(Rect2(px * w - pw * 0.5, PAD_Y_ME * h - 9, pw, 18), Color("2ecc71"))
		draw_circle(Vector2(ball.x * w, ball.y * h + 6), BALL_R * w, Color(0, 0, 0, 0.25))
		draw_circle(Vector2(ball.x * w, ball.y * h), BALL_R * w, Color("fff3d6"))
		var f := UITheme.bold_font()
		draw_string(f, Vector2(12, h * 0.5 - 14), str(cpu), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, 0.75))
		draw_string(f, Vector2(12, h * 0.5 + 46), str(me), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, 0.75))


# ================================================================ jogo da velha

class _Tic extends Control:
	var ui: TableGames
	var cells: Array = []
	var level := 1
	var over := false
	var busy := false
	const LINES := [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]

	func reset(lv: int) -> void:
		level = lv
		cells = ["", "", "", "", "", "", "", "", ""]
		over = false
		busy = false
		ui.set_status("Você é o X. Faça três em linha!")
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		var pos := Vector2.ZERO
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pos = e.position
		else:
			return
		accept_event()
		if over or busy:
			return
		var i := int(pos.y / (size.y / 3.0)) * 3 + int(pos.x / (size.x / 3.0))
		if i < 0 or i > 8 or cells[i] != "":
			return
		cells[i] = "X"
		AudioManager.play_ui("ui_click", -6.0)
		queue_redraw()
		if _end():
			return
		busy = true
		await get_tree().create_timer(0.45).timeout
		if not is_inside_tree():
			return
		busy = false
		cells[_cpu_move()] = "O"
		AudioManager.play_ui("clack", -8.0)
		queue_redraw()
		_end()

	func _winner() -> String:
		for l in LINES:
			if cells[l[0]] != "" and cells[l[0]] == cells[l[1]] and cells[l[1]] == cells[l[2]]:
				return cells[l[0]]
		return "" if "" in cells else "="

	func _end() -> bool:
		var w := _winner()
		if w == "":
			return false
		over = true
		if w == "X":
			ui.finish(1, "Três em linha! Você venceu!")
		elif w == "O":
			ui.finish(-1, "O computador fez três em linha.\nTente de novo!")
		else:
			ui.finish(0, "Deu velha! (empate)")
		return true

	func _cpu_move() -> int:
		# ganha se der, bloqueia se precisar, senão centro/cantos (no fácil às vezes erra)
		for who in ["O", "X"]:
			for l in LINES:
				var marks := 0
				var empty := -1
				for k in l:
					if cells[k] == who:
						marks += 1
					elif cells[k] == "":
						empty = k
				if marks == 2 and empty >= 0 and not (level == 0 and who == "X" and randf() < 0.4):
					return empty
		var free: Array = []
		for i in 9:
			if cells[i] == "":
				free.append(i)
		if level == 1 and cells[4] == "":
			return 4
		var corners := free.filter(func(i): return i in [0, 2, 6, 8])
		if level == 1 and not corners.is_empty():
			return corners.pick_random()
		return free.pick_random()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("fff3d6"))
		var cw := size.x / 3.0
		var ch := size.y / 3.0
		for k in [1, 2]:
			draw_line(Vector2(cw * k, 12), Vector2(cw * k, size.y - 12), Color("2d3047"), 8.0, true)
			draw_line(Vector2(12, ch * k), Vector2(size.x - 12, ch * k), Color("2d3047"), 8.0, true)
		for i in 9:
			var c := Vector2((i % 3 + 0.5) * cw, (i / 3 + 0.5) * ch)
			var s := minf(cw, ch) * 0.3
			if cells[i] == "X":
				draw_line(c - Vector2(s, s), c + Vector2(s, s), Color("e74c3c"), 14.0, true)
				draw_line(c + Vector2(-s, s), c + Vector2(s, -s), Color("e74c3c"), 14.0, true)
			elif cells[i] == "O":
				draw_arc(c, s, 0, TAU, 40, Color("2f6fd0"), 14.0, true)


# ================================================================ memória

class _Memory extends Control:
	var ui: TableGames
	var cards: Array = []  # índice da figura
	var shown: Array = []  # 0 escondida, 1 virada, 2 achada
	var open_now: Array = []
	var moves := 0
	var busy := false
	const SHAPES := 8
	const COLS := [Color("e74c3c"), Color("f39c12"), Color("f1c40f"), Color("2ecc71"), Color("1abc9c"), Color("3498db"), Color("9b59b6"), Color("ff6fae")]

	func reset(_lv: int) -> void:
		cards = []
		for i in SHAPES:
			cards.append(i)
			cards.append(i)
		cards.shuffle()
		shown = []
		shown.resize(16)
		shown.fill(0)
		open_now = []
		moves = 0
		busy = false
		ui.set_status("Ache os pares iguais!\nJogadas: 0")
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		var pos := Vector2.ZERO
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pos = e.position
		else:
			return
		accept_event()
		if busy:
			return
		var i := int(pos.y / (size.y / 4.0)) * 4 + int(pos.x / (size.x / 4.0))
		if i < 0 or i > 15 or shown[i] != 0:
			return
		shown[i] = 1
		open_now.append(i)
		AudioManager.play_ui("ui_click", -8.0)
		queue_redraw()
		if open_now.size() < 2:
			return
		moves += 1
		var a: int = open_now[0]
		var b: int = open_now[1]
		open_now = []
		if cards[a] == cards[b]:
			shown[a] = 2
			shown[b] = 2
			AudioManager.play_ui("point", -6.0)
			if not 0 in shown and not 1 in shown:
				ui.finish(1, "Achou todos os pares em %d jogadas!" % moves)
				return
		else:
			busy = true
			await get_tree().create_timer(0.75).timeout
			if not is_inside_tree():
				return
			shown[a] = 0
			shown[b] = 0
			busy = false
		ui.set_status("Ache os pares iguais!\nJogadas: %d" % moves)
		queue_redraw()

	func _draw() -> void:
		var cw := size.x / 4.0
		var ch := size.y / 4.0
		for i in 16:
			var r := Rect2((i % 4) * cw + 6, (i / 4) * ch + 6, cw - 12, ch - 12)
			if shown[i] == 0:
				draw_style_box(UITheme.box(Color("3d6fd8"), 14, Color("2a4f9c"), 0, 5), r)
				draw_string(UITheme.bold_font(), r.position + Vector2(r.size.x * 0.5 - 12, r.size.y * 0.62), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r.size.y * 0.4), Color(1, 1, 1, 0.8))
				continue
			draw_style_box(UITheme.box(Color("fff3d6") if shown[i] == 1 else Color("d8f5d8"), 14, Color("c9b98f"), 0, 5), r)
			_shape(cards[i], r.get_center(), minf(r.size.x, r.size.y) * 0.32)

	func _shape(k: int, c: Vector2, s: float) -> void:
		var col: Color = COLS[k]
		match k:
			0:
				draw_circle(c, s, col)
			1:
				draw_rect(Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), col)
			2:
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, s * 0.8), c + Vector2(-s, s * 0.8)]), col)
			3:
				var pts := PackedVector2Array()
				for j in 10:
					var a := -PI * 0.5 + j * PI / 5.0
					pts.append(c + Vector2(cos(a), sin(a)) * (s if j % 2 == 0 else s * 0.45))
				draw_colored_polygon(pts, col)
			4:
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), col)
			5:
				var hx := PackedVector2Array()
				for j in 6:
					hx.append(c + Vector2(cos(j * TAU / 6.0), sin(j * TAU / 6.0)) * s)
				draw_colored_polygon(hx, col)
			6:
				draw_rect(Rect2(c - Vector2(s, s * 0.3), Vector2(s * 2.0, s * 0.6)), col)
				draw_rect(Rect2(c - Vector2(s * 0.3, s), Vector2(s * 0.6, s * 2.0)), col)
			_:
				draw_circle(c + Vector2(-s * 0.45, -s * 0.2), s * 0.5, col)
				draw_circle(c + Vector2(s * 0.45, -s * 0.2), s * 0.5, col)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.93, 0), c + Vector2(s * 0.93, 0), c + Vector2(0, s * 0.95)]), col)
