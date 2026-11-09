class_name CoinIcon
extends Control
## Moedinha dourada desenhada em vetor (não depende de fonte de emoji).

@export var radius := 12.0


func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.0 + 2.0, radius * 2.0 + 2.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c + Vector2(0, 1.5), radius, Color(0, 0, 0, 0.25))
	draw_circle(c, radius, Color("f5b400"))
	draw_circle(c, radius * 0.72, Color("ffd84a"))
	draw_arc(c, radius * 0.72, 0, TAU, 24, Color("d99a00"), maxf(radius * 0.12, 1.5), true)
	draw_rect(Rect2(c + Vector2(-radius * 0.12, -radius * 0.42), Vector2(radius * 0.24, radius * 0.84)), Color("d99a00"))
