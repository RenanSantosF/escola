class_name Trampoline
extends Node3D
## Cama elástica: quem pisa nela quica alto (cada pulo um pouco mais alto).
## Não precisa de botão: é só subir. O botão de pular dá um pulo extra.

const RADIUS := 1.8
const BOUNCE := [7.5, 9.0, 10.5, 11.5]

var _n := 0
var _cd := 0.0


func _ready() -> void:
	# colisão do pano (para pisar)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.05
	shape.height = 0.2
	cs.shape = shape
	cs.position = Vector3(0, -0.1, 0)
	body.add_child(cs)
	add_child(body)


func _physics_process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	var p := GameManager.player as PlayerController
	if p == null or not is_instance_valid(p):
		return
	var d := p.global_position - global_position
	if absf(d.y) > 0.4 or Vector2(d.x, d.z).length() > RADIUS:
		if Vector2(d.x, d.z).length() > RADIUS + 1.0:
			_n = 0
		return
	if _cd > 0.0 or p.mode != PlayerController.Mode.FREE or p.velocity.y > 0.5:
		return
	_cd = 0.35
	p.velocity.y = BOUNCE[mini(_n, BOUNCE.size() - 1)]
	_n += 1
	p.visual.play("jump")
	AudioManager.play_3d("boing", global_position, -3.0, 0.1)
	if _n == 4:
		GameManager.show_toast("Que alto!")
		GameManager.add_stat("cama_elastica")
