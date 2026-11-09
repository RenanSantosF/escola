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
	CharacterModelBuilder.rebuild_mesh(skeleton, a)
	scale = Vector3.ONE * a.height_scale


func _build() -> void:
	skeleton = CharacterModelBuilder.build(appearance)
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


func _process(delta: float) -> void:
	if not manual_update:
		animator.update(delta)


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
