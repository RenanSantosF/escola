class_name CharacterVisual
extends Node3D
## Nó visual de um personagem: cria o esqueleto + malha a partir da
## aparência e dirige o animador procedural. Usado pelo jogador e NPCs.

signal action_event(action: String, event: String)
signal action_finished(action: String)
signal footstep(side: int)

var appearance: CharacterAppearance
## Se true, quem controla chama animator.update() (LOD de NPCs).
var manual_update := false
var skeleton: Skeleton3D
var animator := CharacterAnimator.new()
var _hand_attach: BoneAttachment3D


func _ready() -> void:
	if appearance == null:
		appearance = CharacterAppearance.new()
	_build()


func set_appearance(a: CharacterAppearance) -> void:
	appearance = a
	if skeleton == null:
		return
	CharacterModelBuilder.rebuild_mesh(skeleton, a, detail)
	scale = Vector3.ONE * a.height_scale
	_update_aura()


func _build() -> void:
	skeleton = CharacterModelBuilder.build(appearance, detail)
	add_child(skeleton)
	scale = Vector3.ONE * appearance.height_scale
	animator.setup(skeleton)
	animator.action_event.connect(func(a, e): action_event.emit(a, e))
	animator.action_finished.connect(func(a): action_finished.emit(a))
	animator.footstep.connect(func(s): footstep.emit(s))
	_hand_attach = BoneAttachment3D.new()
	_hand_attach.name = "RightHandSlot"
	_hand_attach.bone_name = "RightHand"
	skeleton.add_child(_hand_attach)
	_update_aura()


# ---- aura (efeito de partículas em volta do personagem)
var _aura: GPUParticles3D
var _aura_kind := ""
const AURAS := {
	"estrelas": [Color("ffd23f"), "star", 1.0], "coracoes": [Color("ff3b6b"), "heart", 0.8],
	"fogo": [Color("ff7a1a"), "fire", 1.6], "neve": [Color("dff3ff"), "snow", -0.5],
	"arco_iris": [Color.WHITE, "rainbow", 1.0], "raio": [Color("4fc3ff"), "bolt", 1.2],
}


func _update_aura() -> void:
	var kind := appearance.aura if appearance else ""
	if kind == _aura_kind:
		return
	_aura_kind = kind
	if is_instance_valid(_aura):
		_aura.queue_free()
		_aura = null
	if not AURAS.has(kind):
		return
	var cfg: Array = AURAS[kind]
	_aura = GPUParticles3D.new()
	_aura.name = "Aura"
	_aura.amount = 26
	_aura.lifetime = 1.6
	_aura.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.45
	pm.emission_ring_inner_radius = 0.3
	pm.emission_ring_height = 0.1
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.4 * absf(float(cfg[2]))
	pm.initial_velocity_max = 0.9 * absf(float(cfg[2]))
	pm.gravity = Vector3(0, -0.6 if float(cfg[2]) < 0.0 else 0.15, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	if kind == "arco_iris":
		var g := Gradient.new()
		g.colors = PackedColorArray([Color("e53935"), Color("ffd23f"), Color("27ae60"), Color("2f80ed"), Color("8e44ad")])
		g.offsets = PackedFloat32Array([0, 0.25, 0.5, 0.75, 1])
		var gt := GradientTexture1D.new()
		gt.gradient = g
		pm.color_initial_ramp = gt
	_aura.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	var icon_kind: String = {"star": "star", "heart": "heart", "fire": "sparkle", "snow": "sparkle", "rainbow": "star", "bolt": "bolt"}[cfg[1]]
	m.albedo_texture = EmoteFX.icon(icon_kind, cfg[0])
	q.material = m
	_aura.draw_pass_1 = q
	_aura.position = Vector3(0, 0.1, 0)
	add_child(_aura)


func _process(delta: float) -> void:
	if not manual_update:
		animator.update(delta)


var _shadow_on := true
## Detalhe da malha: 1.0 = completo (jogador); bots usam menos polígonos.
var detail := 1.0


## Liga/desliga a sombra do personagem (LOD de sombra dos NPCs).
func set_shadow(on: bool) -> void:
	if on == _shadow_on:
		return
	_shadow_on = on
	for c in skeleton.get_children() if skeleton else []:
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func stop_upper(fade := true) -> void:
	animator.stop_upper(fade)


func play(action_name: String, speed_scale := 1.0) -> bool:
	return animator.play(action_name, speed_scale)


func stop_action(fade := true) -> void:
	animator.stop_action(fade)


func hand_slot() -> Node3D:
	return _hand_attach


## Posição global aproximada da mão direita (para objetos segurados).
func hand_position() -> Vector3:
	return _hand_attach.global_position if _hand_attach else global_position + Vector3.UP
