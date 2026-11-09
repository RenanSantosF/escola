class_name Minimap
extends Control
## Minimapa (canto superior) e mapa completo da escola ao tocar.
## Desenhado a partir dos dados de layout — sem texturas extras.

signal toggled_full(is_full: bool)

var world: Node
var player: Node3D
var view_radius := 42.0
var full := false
var _font: Font
var _zones: Array = []
var _shapes: Array = []
var _lot := Rect2(-90, -75, 180, 150)
var _timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = UITheme.bold_font()
	clip_contents = true


func setup(w: Node, p: Node3D) -> void:
	world = w
	player = p
	var md: Dictionary = w.get_map_data()
	_zones = md.zones.duplicate()
	_zones.sort_custom(func(a, b): return a.priority < b.priority)
	_shapes = md.shapes
	_lot = md.lot


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		full = not full
		toggled_full.emit(full)
		AudioManager.play_ui("ui_click")
		accept_event()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.1
		queue_redraw()


func _w2m(p: Vector2, center: Vector2, scale: float) -> Vector2:
	return size * 0.5 + (p - center) * scale


func _draw() -> void:
	if player == null:
		return
	var pp := Vector2(player.global_position.x, player.global_position.z)
	var center := pp
	var scale := minf(size.x, size.y) * 0.5 / view_radius
	if full:
		center = _lot.get_center()
		scale = minf(size.x / (_lot.size.x + 10.0), size.y / (_lot.size.y + 10.0))
	var bg := Rect2(Vector2.ZERO, size)
	draw_rect(bg, Color("6fae5c"))
	for z in _zones:
		if z.color.a <= 0.0 or z.name in ["Rua da Escola"]:
			continue
		var r: Rect2 = z.rect
		var a := _w2m(r.position, center, scale)
		var b := _w2m(r.end, center, scale)
		var mr := Rect2(a, b - a).intersection(bg)
		if mr.has_area():
			draw_rect(mr, z.color)
	for s in _shapes:
		var r2: Rect2 = s.rect
		var a2 := _w2m(r2.position, center, scale)
		var b2 := _w2m(r2.end, center, scale)
		var mr2 := Rect2(a2, b2 - a2).intersection(bg)
		if mr2.has_area():
			draw_rect(mr2, s.color)
			draw_rect(mr2, Color(0, 0, 0, 0.35), false, 1.5)
	# muro
	var la := _w2m(_lot.position, center, scale)
	var lb := _w2m(_lot.end, center, scale)
	draw_rect(Rect2(la, lb - la), Color("f4f1ea"), false, 3.0)
	# rótulos no mapa completo
	if full:
		var placed: Array = []
		for z in _zones:
			if not z.has("rect") or z.priority < 4 or z.rect.size.x * z.rect.size.y < 60.0:
				continue
			var c := _w2m(z.rect.get_center(), center, scale)
			var txt: String = z.name
			var fs := 13
			var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var rect := Rect2(c - Vector2(tw * 0.5, fs * 0.5), Vector2(tw, fs))
			var overlap := false
			for o in placed:
				if o.intersects(rect.grow(2)):
					overlap = true
					break
			if overlap:
				continue
			placed.append(rect)
			draw_string_outline(_font, c + Vector2(-tw * 0.5, fs * 0.4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(1, 1, 1, 0.9))
			draw_string(_font, c + Vector2(-tw * 0.5, fs * 0.4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("1f2a44"))
	# jogador (seta na direção em que olha)
	var pc := _w2m(pp, center, scale)
	var yaw: float = player.get("yaw") if player.get("yaw") != null else 0.0
	var dir := Vector2(sin(yaw), cos(yaw))
	var side := dir.orthogonal()
	var arrow := PackedVector2Array([pc + dir * 11.0, pc - dir * 7.0 + side * 7.0, pc - dir * 3.0, pc - dir * 7.0 - side * 7.0])
	draw_colored_polygon(arrow, Color("e04a3a"))
	draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[3], arrow[0]]), Color.WHITE, 2.0, true)
	draw_rect(bg, Color(1, 1, 1, 0.9), false, 4.0)
	if not full:
		draw_string_outline(_font, Vector2(size.x - 18, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.6))
		draw_string(_font, Vector2(size.x - 18, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
