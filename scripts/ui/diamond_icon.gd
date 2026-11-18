class_name DiamondIcon
extends Control
## Diamante azul desenhado em vetor (moeda especial).

@export var radius := 12.0


func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.0 + 2.0, radius * 2.0 + 2.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := radius
	var top := PackedVector2Array([c + Vector2(-r * 0.95, -r * 0.25), c + Vector2(-r * 0.5, -r * 0.8), c + Vector2(r * 0.5, -r * 0.8), c + Vector2(r * 0.95, -r * 0.25)])
	var bottom := PackedVector2Array([c + Vector2(-r * 0.95, -r * 0.25), c + Vector2(r * 0.95, -r * 0.25), c + Vector2(0, r * 0.95)])
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.95, -r * 0.1), c + Vector2(r * 0.95, -r * 0.1), c + Vector2(0, r * 1.1)]), Color(0, 0, 0, 0.2))
	draw_colored_polygon(top, Color("7fe3ff"))
	draw_colored_polygon(bottom, Color("2f9be0"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.3, -r * 0.25), c + Vector2(r * 0.3, -r * 0.25), c + Vector2(0, r * 0.95)]), Color("59c4f5"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.5, -r * 0.8), c + Vector2(-r * 0.15, -r * 0.8), c + Vector2(-r * 0.3, -r * 0.25)]), Color(1, 1, 1, 0.65))
	var outline := top.duplicate()
	outline.append_array(PackedVector2Array([c + Vector2(0, r * 0.95), top[0]]))
	draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], c + Vector2(0, r * 0.95), top[0]]), Color("155a8a"), maxf(r * 0.12, 1.5), true)
