class_name Seat
extends Interactable
## Assento: a origem do nó é onde ficam os pés do personagem sentado,
## e a rotação Y indica para onde ele olha.

var occupant: Node = null
var seat_top := 0.47


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


func release() -> void:
	occupant = null
