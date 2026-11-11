class_name WishFountain
extends Interactable
## Chafariz: água animada, jatos e "jogar uma moedinha e fazer um pedido".

var radius := 2.5
var top := Vector3.ZERO
static var _water_mat: ShaderMaterial


func _ready() -> void:
	super._ready()
	prompt = "Jogar moedinha e fazer um pedido"
	interact_radius = radius + 1.4
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 32
	mi.mesh = cm
	mi.material_override = water_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var top_pool := MeshInstance3D.new()
	var cm2 := CylinderMesh.new()
	cm2.top_radius = 0.9
	cm2.bottom_radius = 0.9
	cm2.height = 0.02
	top_pool.mesh = cm2
	top_pool.material_override = water_material()
	top_pool.position = top - global_position - Vector3(0, 0.6, 0) if top != Vector3.ZERO else Vector3(0, 1.4, 0)
	add_child(top_pool)
	var jets := GPUParticles3D.new()
	jets.amount = 60 if Settings.quality() != Settings.Quality.LOW else 24
	jets.lifetime = 1.1
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 18.0
	pm.initial_velocity_min = 2.6
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	jets.process_material = pm
	var drop := SphereMesh.new()
	drop.radius = 0.035
	drop.height = 0.07
	drop.radial_segments = 6
	drop.rings = 3
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.75, 0.92, 1.0, 0.75)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = dm
	jets.draw_pass_1 = drop
	jets.position = (top - global_position) if top != Vector3.ZERO else Vector3(0, 2.0, 0)
	jets.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	jets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(jets)


static func water_material() -> ShaderMaterial:
	if _water_mat:
		return _water_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode specular_schlick_ggx;
void fragment() {
	vec2 p = UV * 12.0;
	float w = sin(p.x * 1.7 + TIME * 2.1) * 0.5 + sin(p.y * 2.3 - TIME * 1.6) * 0.5;
	w += sin((p.x + p.y) * 3.1 + TIME * 3.0) * 0.3;
	vec3 deep = vec3(0.10, 0.45, 0.75);
	vec3 light = vec3(0.45, 0.85, 1.0);
	ALBEDO = mix(deep, light, w * 0.25 + 0.5);
	ROUGHNESS = 0.08;
	METALLIC = 0.1;
	SPECULAR = 0.9;
	NORMAL_MAP = normalize(vec3(sin(p.x * 2.0 + TIME * 2.0) * 0.3 + 0.5, cos(p.y * 2.0 - TIME * 1.7) * 0.3 + 0.5, 1.0));
}
"""
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = sh
	return _water_mat


func interact(player: Node) -> void:
	if not GameManager.spend_coins(1):
		GameManager.show_toast("Você precisa de 1 moeda.")
		return
	(player as PlayerController).visual.play("throw")
	AudioManager.play_3d("drink", global_position + Vector3(0, 0.6, 0), -2.0)
	Effects.burst(global_position + Vector3(0, 0.6, 0), "sparkle")
	var r := randf()
	if r < 0.12:
		Stickers.give_random(randf() < 0.2)
	elif r < 0.4:
		GameManager.add_rewards(8, 0)
		GameManager.show_toast("O pedido deu sorte: +8 XP!")
	else:
		GameManager.add_rewards(2, 0)
		GameManager.show_toast(["Que seu pedido se realize!", "A água brilhou... será sorte?", "Pedido feito!"].pick_random())
	GameManager.add_stat("pedidos")
