class_name WaterFountain
extends Interactable
## Bebedouro: o personagem se curva e bebe água (com partículas e som).

var spout := Vector3.ZERO
var _particles: GPUParticles3D


func _ready() -> void:
	super._ready()
	prompt = "Beber água"
	interact_radius = 1.0
	_particles = GPUParticles3D.new()
	_particles.emitting = false
	_particles.one_shot = false
	_particles.amount = 16
	_particles.lifetime = 0.35
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0.4)
	pm.spread = 8.0
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, -6, 0)
	pm.scale_min = 0.4
	pm.scale_max = 0.6
	_particles.process_material = pm
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.85, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	_particles.draw_pass_1 = mesh
	_particles.visibility_range_end = 30.0
	_particles.visibility_aabb = AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1.5, 1))
	add_child(_particles)
	_particles.global_position = spout if spout != Vector3.ZERO else global_position + Vector3(0, 1.0, 0)
	_particles.global_rotation = Vector3(0, global_rotation.y + PI, 0)


func interact(player: Node) -> void:
	if busy:
		return
	if player.has_method("use_fountain"):
		busy = true
		player.use_fountain(self)


func start_water() -> void:
	_particles.emitting = true
	AudioManager.play_3d("drink", global_position + Vector3(0, 1, 0), -4.0)


func stop_water() -> void:
	_particles.emitting = false
	busy = false
