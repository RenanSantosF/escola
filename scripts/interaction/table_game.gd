class_name TableGame
extends Interactable
## Mesa de jogo (xadrez, pingue-pongue, jogo da velha, memória): toca e abre
## o jogo numa tela própria (TableGames). O personagem fica parado na mesa.

const PROMPTS := {"xadrez": "Jogar xadrez", "pingpong": "Jogar pingue-pongue", "velha": "Jogo da velha", "memoria": "Jogo da memória"}

var kind := "xadrez"
var _player: PlayerController = null


func _ready() -> void:
	super._ready()
	prompt = PROMPTS.get(kind, "Jogar")
	interact_radius = 1.4


func can_interact(p: Node) -> bool:
	return _player == null and (p as PlayerController).mode == PlayerController.Mode.FREE and (p as PlayerController).minigame == null


func interact(player: Node) -> void:
	var p := player as PlayerController
	if p == null or _player != null:
		return
	var hud := get_tree().get_first_node_in_group("hud") as Control
	if hud == null:
		return
	_player = p
	p.input_enabled = false
	p.velocity = Vector3.ZERO
	var to := global_position - p.global_position
	if Vector2(to.x, to.z).length() > 0.1:
		p.yaw = atan2(to.x, to.z)
		p.visual.rotation.y = p.yaw
	p.visual.play("scratch_head" if kind == "xadrez" else "interact")
	var ctrl_vis: bool = hud.get("controls").visible
	hud.get("controls").visible = false
	TableGames.open(hud, kind, func(_won):
		if is_instance_valid(p):
			p.input_enabled = true
			p.visual.stop_action()
		if is_instance_valid(hud):
			hud.get("controls").visible = ctrl_vis or GameManager.is_playing()
		_player = null
		GameManager.add_stat("jogos_mesa"))
