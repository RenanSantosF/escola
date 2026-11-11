extends Node
## Efeitos de partículas com pool (nada é instanciado durante o jogo):
## confete (gols, vitórias, nível), poeira (chutes, aterrissagens, freadas)
## e brilho (itens, conquistas). Quantidade reduzida na qualidade Baixa.

const POOL := 3
const TYPES := ["confetti", "dust", "sparkle"]

var _pools := {}
var _next := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ensure(type: String) -> void:
	if _pools.has(type):
		return
	var list: Array[GPUParticles3D] = []
	for i in POOL:
		var p := _make(type)
		add_child(p)
		list.append(p)
	_pools[type] = list
	_next[type] = 0


func _make(type: String) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 6, 8))
	var pm := ParticleProcessMaterial.new()
	var mesh: Mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	match type:
		"confetti":
			p.amount = 48
			p.lifetime = 1.8
			pm.direction = Vector3(0, 1, 0)
			pm.spread = 50.0
			pm.initial_velocity_min = 4.0
			pm.initial_velocity_max = 7.0
			pm.gravity = Vector3(0, -5.0, 0)
			pm.damping_min = 1.5
			pm.damping_max = 2.5
			pm.angular_velocity_min = -400.0
			pm.angular_velocity_max = 400.0
			pm.angle_min = 0.0
			pm.angle_max = 360.0
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
			g.colors = PackedColorArray([Color("e74c3c"), Color("f1c40f"), Color("2ecc71"), Color("3498db"), Color("e84393")])
			var gt := GradientTexture1D.new()
			gt.gradient = g
			pm.color_initial_ramp = gt
			var q := QuadMesh.new()
			q.size = Vector2(0.07, 0.04)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			mat.billboard_keep_scale = true
			q.material = mat
			mesh = q
		"dust":
			p.amount = 12
			p.lifetime = 0.7
			pm.direction = Vector3(0, 1, 0)
			pm.spread = 80.0
			pm.initial_velocity_min = 0.6
			pm.initial_velocity_max = 1.4
			pm.gravity = Vector3(0, 0.3, 0)
			pm.damping_min = 2.0
			pm.damping_max = 3.0
			pm.scale_min = 0.6
			pm.scale_max = 1.3
			var sc := Curve.new()
			sc.add_point(Vector2(0, 0.4))
			sc.add_point(Vector2(1, 1.4))
			var sct := CurveTexture.new()
			sct.curve = sc
			pm.scale_curve = sct
			pm.color = Color(0.82, 0.76, 0.64, 0.55)
			var ga := Gradient.new()
			ga.colors = PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)])
			var gat := GradientTexture1D.new()
			gat.gradient = ga
			pm.color_ramp = gat
			var s := SphereMesh.new()
			s.radius = 0.09
			s.height = 0.14
			s.radial_segments = 6
			s.rings = 3
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			s.material = mat
			mesh = s
		_:
			p.amount = 16
			p.lifetime = 0.9
			pm.direction = Vector3(0, 1, 0)
			pm.spread = 180.0
			pm.initial_velocity_min = 1.0
			pm.initial_velocity_max = 2.2
			pm.gravity = Vector3(0, -1.0, 0)
			pm.color = Color("fff3a0")
			var q2 := QuadMesh.new()
			q2.size = Vector2(0.06, 0.06)
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			q2.material = mat
			mesh = q2
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func burst(pos: Vector3, type := "confetti") -> void:
	if type == "dust" and Settings.quality() == Settings.Quality.LOW:
		return
	_ensure(type)
	var list: Array = _pools[type]
	var p: GPUParticles3D = list[_next[type]]
	_next[type] = (_next[type] + 1) % POOL
	p.global_position = pos
	p.amount_ratio = 0.5 if Settings.quality() == Settings.Quality.LOW else 1.0
	p.restart()
	p.emitting = true
