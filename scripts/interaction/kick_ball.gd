class_name KickBall
extends RigidBody3D
## Bola com física (futebol, queimada, basquete). Pode ser conduzida
## encostando nela e chutada com o botão de brincadeira.

const KINDS := {
	"football": {"radius": 0.11, "mass": 0.43, "bounce": 0.55, "colors": [Color("f7f7f7"), Color("1c1c1c")]},
	"dodgeball": {"radius": 0.12, "mass": 0.3, "bounce": 0.7, "colors": [Color("e53935"), Color("c62828")]},
	"basketball": {"radius": 0.12, "mass": 0.6, "bounce": 0.75, "colors": [Color("e67e22"), Color("3b2412")]},
}

var kind := "football"
var radius := 0.11
var _spawn := Vector3.ZERO
var _bounce_cd := 0.0


static func create(ball_kind: String) -> KickBall:
	var b := KickBall.new()
	b.kind = ball_kind if KINDS.has(ball_kind) else "football"
	var k: Dictionary = KINDS[b.kind]
	b.radius = k.radius
	b.mass = k.mass
	b.linear_damp = 0.35
	b.angular_damp = 0.8
	b.continuous_cd = true
	b.contact_monitor = true
	b.max_contacts_reported = 3
	b.can_sleep = true
	var pm := PhysicsMaterial.new()
	pm.bounce = k.bounce
	pm.friction = 0.7
	pm.rough = true
	b.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = b.radius
	cs.shape = sh
	b.add_child(cs)
	var md := MeshData.new()
	md.cur_color = k.colors[0]
	md.add_sphere(Transform3D(Basis(), Vector3.ZERO), b.radius, 14, 10)
	md.cur_color = k.colors[1]
	if b.kind == "football":
		# gomos pretos
		var dirs := [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
		for d: Vector3 in dirs:
			var axis := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
			var basis := Basis(axis, Vector3.UP.angle_to(d)) if absf(d.y) < 0.99 else (Basis() if d.y > 0 else Basis(Vector3.RIGHT, PI))
			md.add_cylinder(Transform3D(basis, d * (b.radius * 0.93)), b.radius * 0.38, b.radius * 0.38, b.radius * 0.18, 5)
	elif b.kind == "basketball":
		for i in 3:
			md.add_box(Transform3D(Basis(Vector3.UP, i * PI / 3.0), Vector3.ZERO), Vector3(b.radius * 2.02, b.radius * 0.08, b.radius * 0.08))
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	mi.visibility_range_end = 70.0
	b.add_child(mi)
	return b


func _ready() -> void:
	add_to_group("ball")
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8
	_spawn = global_position
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_bounce_cd = maxf(_bounce_cd - delta, 0.0)
	if global_position.y < -5.0 or global_position.length() > 300.0:
		reset_ball()


func reset_ball() -> void:
	global_position = _spawn
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func kick(direction: Vector3, power: float, lift: float) -> void:
	sleeping = false
	var dir := direction.normalized()
	apply_central_impulse((dir * power + Vector3.UP * lift) * mass)
	angular_velocity += dir.cross(Vector3.UP) * -power * 2.0
	AudioManager.play_3d("kick", global_position, -2.0)


func nudge(direction: Vector3, strength: float) -> void:
	sleeping = false
	apply_central_impulse(direction * strength * mass)


func _on_body_entered(_body: Node) -> void:
	if _bounce_cd <= 0.0 and linear_velocity.length() > 2.0:
		_bounce_cd = 0.12
		AudioManager.play_3d("ball_bounce", global_position, -6.0 + minf(linear_velocity.length(), 8.0))
