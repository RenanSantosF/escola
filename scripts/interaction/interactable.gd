class_name Interactable
extends Node3D
## Base de objetos interativos (assentos, bebedouros...).
## O jogador procura nós do grupo "interactable" próximos e chama interact().

@export var prompt := "Usar"
@export var interact_radius := 1.3

var busy := false


func _ready() -> void:
	add_to_group("interactable")


func get_prompt(_player: Node) -> String:
	return prompt


func can_interact(_player: Node) -> bool:
	return not busy


func interact_point() -> Vector3:
	return global_position


func interact(_player: Node) -> void:
	pass
