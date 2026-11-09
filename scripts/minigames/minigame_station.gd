class_name MinigameStation
extends Interactable
## Ponto do mapa onde se começa um minijogo (ativo só no recreio).

var game_id := ""
var mgr: Node


func _ready() -> void:
	super._ready()
	interact_radius = 2.2


func can_interact(_player: Node) -> bool:
	return mgr != null and mgr.can_start()


func interact(_player: Node) -> void:
	if mgr:
		mgr.start(game_id)
