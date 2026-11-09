class_name Seat
extends Interactable
## Assento: a origem do nó é onde ficam os pés do personagem sentado,
## e a rotação Y indica para onde ele olha.

var occupant: Node = null
var seat_top := 0.47
var room := ""
## Distância (ao longo da frente do assento) do ponto de aproximação dos NPCs.
var approach := 0.55
var swing := false
var _swing_t := 0.0


func _ready() -> void:
	super._ready()
	interact_radius = 1.1


func can_interact(_player: Node) -> bool:
	return occupant == null


## O ponto de interação fica um pouco à frente do assento.
func interact_point() -> Vector3:
	return global_position + global_basis.z * 0.35


func interact(player: Node) -> void:
	if occupant != null:
		return
	if player.has_method("sit_on"):
		player.sit_on(self)


func occupy(who: Node) -> void:
	occupant = who
	_swing_t = 0.0


func release() -> void:
	if occupant and swing and occupant.get("visual"):
		occupant.visual.position = Vector3.ZERO
		occupant.visual.rotation.x = 0.0
	occupant = null


func _process(delta: float) -> void:
	# balanço do parquinho: quem estiver sentado vai e volta
	if not swing or occupant == null:
		return
	var v: Node3D = occupant.get("visual")
	if v == null:
		return
	_swing_t += delta
	var a := sin(_swing_t * 2.2) * 0.45 * minf(_swing_t * 0.5, 1.0)
	v.rotation.x = -a
	var fwd := Vector3(sin(global_rotation.y), 0, cos(global_rotation.y))
	v.position = Vector3(0, (1.0 - cos(a)) * 2.0, 0) + fwd * sin(a) * 2.0
