class_name PickupItem
extends RigidBody3D
## Objeto que pode ser pego e arremessado (bolinha de papel etc.).

@export var prompt := "Pegar"
@export var interact_radius := 1.2
@export var item_kind := "paper_ball"

var held_by: Node = null
var thrower: Node = null
var _home_parent: Node = null
var _spawn := Vector3.ZERO
var _sleep_timer := 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("pickup")
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	_spawn = global_position
	_home_parent = get_parent()
	body_entered.connect(_on_body_entered)


static func create_paper_ball() -> PickupItem:
	var p := PickupItem.new()
	p.item_kind = "paper_ball"
	p.prompt = "Pegar bolinha de papel"
	p.mass = 0.05
	p.linear_damp = 0.3
	p.angular_damp = 1.0
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.3
	pm.friction = 0.9
	p.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.06
	cs.shape = sh
	p.add_child(cs)
	var mi := MeshInstance3D.new()
	var md := MeshData.new()
	var r := RandomNumberGenerator.new()
	r.seed = 3
	md.cur_color = Color("f4f1e8")
	md.add_sphere(Transform3D(Basis(), Vector3.ZERO), 0.065, 8, 6)
	# amassados
	for i in 6:
		md.cur_color = Color("e6e1d4")
		var d := Vector3(r.randf_range(-1, 1), r.randf_range(-1, 1), r.randf_range(-1, 1)).normalized()
		md.add_box(Transform3D(Basis(d.cross(Vector3.UP).normalized() if absf(d.y) < 0.9 else Vector3.RIGHT, r.randf() * 2.0), d * 0.05), Vector3(0.05, 0.03, 0.05))
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	mi.visibility_range_end = 35.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)
	return p


## Objetos da tarefa "ache e traga" (apagador, livro, giz, caderno).
static func create_item(kind: String) -> PickupItem:
	var p := PickupItem.new()
	p.item_kind = kind
	p.mass = 0.3
	p.linear_damp = 0.5
	p.angular_damp = 2.0
	var names := {"apagador": "Pegar o apagador", "livro": "Pegar o livro", "giz": "Pegar a caixa de giz", "caderno": "Pegar o caderno"}
	p.prompt = names.get(kind, "Pegar")
	var size := Vector3(0.18, 0.06, 0.08)
	var md := MeshData.new()
	match kind:
		"apagador":
			md.cur_color = Color("8a5a32")
			md.add_box(Transform3D(Basis(), Vector3(0, 0.02, 0)), Vector3(0.16, 0.04, 0.07))
			md.cur_color = Color("3d3d3d")
			md.add_box(Transform3D(Basis(), Vector3(0, -0.015, 0)), Vector3(0.16, 0.03, 0.07))
			size = Vector3(0.16, 0.07, 0.07)
		"livro":
			md.cur_color = Color("c0392b")
			md.add_box(Transform3D(Basis(), Vector3.ZERO), Vector3(0.2, 0.04, 0.26))
			md.cur_color = Color("f5f0e1")
			md.add_box(Transform3D(Basis(), Vector3(0.008, 0, 0)), Vector3(0.19, 0.03, 0.25))
			size = Vector3(0.2, 0.04, 0.26)
		"giz":
			md.cur_color = Color("f1c40f")
			md.add_box(Transform3D(Basis(), Vector3.ZERO), Vector3(0.12, 0.06, 0.08))
			md.cur_color = Color.WHITE
			for i in 4:
				md.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.04, -0.03 + i * 0.02)), 0.006, 0.006, 0.08, 5)
			size = Vector3(0.12, 0.08, 0.08)
		_:
			md.cur_color = Color("2e86de")
			md.add_box(Transform3D(Basis(), Vector3.ZERO), Vector3(0.21, 0.02, 0.28))
			md.cur_color = Color("ecf0f1")
			md.add_box(Transform3D(Basis(), Vector3(0, 0.012, 0)), Vector3(0.18, 0.004, 0.24))
			size = Vector3(0.21, 0.03, 0.28)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	p.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	p.add_child(mi)
	# brilho sutil para ajudar a achar
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.9, 0.5)
	glow.light_energy = 0.6
	glow.omni_range = 0.8
	glow.shadow_enabled = false
	p.add_child(glow)
	return p


func get_prompt(_player: Node) -> String:
	return prompt


func can_interact(_player: Node) -> bool:
	return held_by == null


func interact_point() -> Vector3:
	return global_position


func interact(player: Node) -> void:
	if held_by == null and player.has_method("pick_up"):
		player.pick_up(self)


func attach_to(slot: Node3D, holder: Node) -> void:
	held_by = holder
	freeze = true
	collision_layer = 0
	collision_mask = 0
	reparent(slot, false)
	position = Vector3(0, -0.09, 0.05)
	rotation = Vector3.ZERO


func throw_from(world_parent: Node, from: Vector3, velocity: Vector3) -> void:
	reparent(world_parent if world_parent else _home_parent, false)
	global_position = from
	held_by = null
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8
	freeze = false
	linear_velocity = velocity
	angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	sleeping = false


func _physics_process(_delta: float) -> void:
	if held_by == null and global_position.y < -5.0:
		global_position = _spawn
		linear_velocity = Vector3.ZERO


func _on_body_entered(body: Node) -> void:
	if linear_velocity.length() > 3.0 and body.has_method("on_hit_by_object") and body != thrower:
		body.on_hit_by_object(self)
	if body is StaticBody3D:
		thrower = null
