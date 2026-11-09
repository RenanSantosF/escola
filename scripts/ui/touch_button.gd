class_name TouchButton
extends Control
## Botão circular para toque com ícone desenhado em vetor (não depende de
## fontes de emoji). A entrada é roteada pelo MobileControls (multi-toque).

signal pressed
signal released

enum Icon { RUN, INTERACT, JUMP, PLAY, PAUSE, EMOTE, MAP, BAG }

@export var icon: Icon = Icon.INTERACT
@export var base_color := Color("ffcf3f")
@export var label := ""
@export var toggle := false

var is_down := false
var toggled_on := false
var highlight := false
var _scale := 1.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UITheme.bold_font()


func _process(delta: float) -> void:
	var target := 0.88 if is_down else (1.06 if highlight else 1.0)
	_scale = lerpf(_scale, target, 1.0 - exp(-18.0 * delta))
	queue_redraw()


func press() -> void:
	is_down = true
	if toggle:
		toggled_on = not toggled_on
	pressed.emit()


func release() -> void:
	is_down = false
	released.emit()


func contains(p: Vector2) -> bool:
	var c := get_global_rect().get_center()
	return p.distance_to(c) <= size.x * 0.62


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5 * _scale
	var c := size * 0.5
	var active := is_down or toggled_on
	var col := base_color.lightened(0.15) if active else base_color
	# sombra + base + aro
	draw_circle(c + Vector2(0, r * 0.08), r, Color(0, 0, 0, 0.25))
	draw_circle(c, r, Color(col, 0.92 if active else 0.78))
	draw_arc(c, r - 2.0, 0, TAU, 48, Color(1, 1, 1, 0.85), 3.0, true)
	if highlight and not active:
		draw_arc(c, r + 4.0, 0, TAU, 48, Color(1, 1, 1, 0.6 + 0.3 * sin(Time.get_ticks_msec() * 0.008)), 3.0, true)
	var ic := Color("1f2a44")
	var s := r * 0.42
	match icon:
		Icon.RUN:
			for k in 2:
				var o := c + Vector2(-s * 0.35 + k * s * 0.6, 0)
				draw_polyline(PackedVector2Array([o + Vector2(-s * 0.35, -s * 0.6), o + Vector2(s * 0.3, 0), o + Vector2(-s * 0.35, s * 0.6)]), ic, r * 0.13, true)
		Icon.INTERACT:
			draw_circle(c + Vector2(0, -s * 0.1), s * 0.62, Color(ic, 0.0))
			draw_arc(c + Vector2(0, -s * 0.1), s * 0.6, 0, TAU, 32, ic, r * 0.1, true)
			draw_circle(c + Vector2(0, -s * 0.1), s * 0.22, ic)
			draw_line(c + Vector2(s * 0.42, s * 0.32), c + Vector2(s * 0.8, s * 0.7), ic, r * 0.12, true)
		Icon.JUMP:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.85), c + Vector2(s * 0.7, 0), c + Vector2(-s * 0.7, 0)]), ic)
			draw_line(c + Vector2(0, -s * 0.1), c + Vector2(0, s * 0.8), ic, r * 0.16, true)
		Icon.PLAY:
			draw_circle(c, s * 0.8, Color.WHITE)
			draw_arc(c, s * 0.8, 0, TAU, 32, ic, r * 0.06, true)
			var pts := PackedVector2Array()
			for k in 5:
				var a := -PI * 0.5 + k * TAU / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * s * 0.32)
			draw_colored_polygon(pts, ic)
		Icon.PAUSE:
			draw_rect(Rect2(c + Vector2(-s * 0.5, -s * 0.6), Vector2(s * 0.32, s * 1.2)), ic)
			draw_rect(Rect2(c + Vector2(s * 0.18, -s * 0.6), Vector2(s * 0.32, s * 1.2)), ic)
		Icon.EMOTE:
			draw_circle(c, s * 0.85, Color("ffe08a"))
			draw_arc(c, s * 0.85, 0, TAU, 32, ic, r * 0.06, true)
			draw_circle(c + Vector2(-s * 0.3, -s * 0.2), s * 0.12, ic)
			draw_circle(c + Vector2(s * 0.3, -s * 0.2), s * 0.12, ic)
			draw_arc(c + Vector2(0, s * 0.05), s * 0.45, 0.3, PI - 0.3, 16, ic, r * 0.07, true)
		Icon.BAG:
			draw_rect(Rect2(c - Vector2(s * 0.6, s * 0.45), Vector2(s * 1.2, s * 1.15)), Color("e04a3a"))
			draw_rect(Rect2(c - Vector2(s * 0.6, s * 0.45), Vector2(s * 1.2, s * 1.15)), ic, false, r * 0.06)
			draw_arc(c + Vector2(0, -s * 0.45), s * 0.35, PI, TAU, 12, ic, r * 0.07, true)
			draw_rect(Rect2(c + Vector2(-s * 0.35, s * 0.05), Vector2(s * 0.7, s * 0.35)), Color("ffcf3f"))
		Icon.MAP:
			draw_rect(Rect2(c - Vector2(s * 0.8, s * 0.6), Vector2(s * 1.6, s * 1.2)), Color("a8e6a1"))
			draw_rect(Rect2(c - Vector2(s * 0.8, s * 0.6), Vector2(s * 1.6, s * 1.2)), ic, false, r * 0.06)
			draw_circle(c + Vector2(s * 0.2, -s * 0.1), s * 0.2, Color("e04a3a"))
	if label != "":
		var fs := int(clampf(r * 0.3, 13.0, 22.0))
		var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var tp := Vector2(c.x - tw * 0.5, size.y + fs + 2)
		draw_string_outline(_font, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.6))
		draw_string(_font, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
