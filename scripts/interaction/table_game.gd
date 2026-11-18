class_name TableGame
extends Interactable
## Mesa de jogo (xadrez, pingue-pongue, jogo da velha, memória). Joga-se
## chegando AO LADO da mesa: no banquinho (xadrez, velha, memória) ou na
## ponta (pingue-pongue). Cada mesa tem dois lugares; online, quem senta do
## outro lado joga CONTRA você (xadrez e pingue-pongue). Sozinho: contra o
## computador ou 2 jogadores no mesmo celular.

const PROMPTS := {"xadrez": "Jogar xadrez", "pingpong": "Jogar pingue-pongue", "velha": "Jogo da velha", "memoria": "Jogo da memória"}

var kind := "xadrez"
## Lugares dos jogadores (relativos ao centro da mesa).
var sides: Array = []
var _player: PlayerController = null
var my_side := -1


func _ready() -> void:
	super._ready()
	add_to_group("game_table")
	prompt = PROMPTS.get(kind, "Jogar")
	interact_radius = 1.1
	if sides.is_empty():
		sides = [Vector3(-0.75, 0, 0), Vector3(0.75, 0, 0)]


## Chave da mesa (igual em todos os celulares).
func key() -> String:
	return "%s@%d,%d,%d" % [kind, roundi(global_position.x * 10), roundi(global_position.y * 10), roundi(global_position.z * 10)]


func side_pos(i: int) -> Vector3:
	return global_position + (sides[i] as Vector3)


## O jogador interage pelo lugar livre mais perto dele (nunca pelo meio da sala).
func _nearest_side(from: Vector3) -> int:
	var best := -1
	var bd := INF
	for i in sides.size():
		if _taken_by_remote(i):
			continue
		var d := side_pos(i).distance_to(from)
		if d < bd:
			bd = d
			best = i
	return best


func interact_point() -> Vector3:
	var p := GameManager.player as Node3D
	var i := _nearest_side(p.global_position) if p else 0
	return side_pos(maxi(i, 0))


## Um colega online já está sentado neste lugar?
func _taken_by_remote(i: int) -> bool:
	return remote_at(i) != ""


## Id do colega online sentado no lugar i ("" = livre).
func remote_at(i: int) -> String:
	var sess := get_tree().get_first_node_in_group("online_session")
	if sess == null or not NetworkManager.is_online():
		return ""
	var sp := side_pos(i)
	for id in sess.remotes.keys():
		var r: Dictionary = sess.remotes[id]
		if str(r.get("anim", "")) == "mesa" and (r.to as Vector3).distance_to(sp) < 0.9:
			return str(id)
	return ""


func can_interact(p: Node) -> bool:
	var pc := p as PlayerController
	return _player == null and pc.mode == PlayerController.Mode.FREE and pc.minigame == null and _nearest_side(pc.global_position) >= 0


func interact(player: Node) -> void:
	var p := player as PlayerController
	if p == null or _player != null:
		return
	var hud := get_tree().get_first_node_in_group("hud") as Control
	if hud == null:
		return
	var i := _nearest_side(p.global_position)
	if i < 0:
		GameManager.show_toast("Os dois lugares desta mesa estão ocupados!")
		return
	_player = p
	my_side = i
	p.input_enabled = false
	p.velocity = Vector3.ZERO
	# vai para o lugar AO LADO da mesa, virado para ela
	var sp := side_pos(i)
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "global_position", Vector3(sp.x, p.global_position.y, sp.z), 0.3)
	var to := global_position - sp
	p.yaw = atan2(to.x, to.z)
	p.visual.rotation.y = p.yaw
	p.set_meta("mesa", key())
	if kind == "pingpong":
		p.visual.play("interact")
	else:
		p.visual.play("sit_down")
	var ctrl_vis: bool = hud.get("controls").visible
	hud.get("controls").visible = false
	var tg := TableGames.open(hud, kind, func(_won):
		if is_instance_valid(p):
			p.input_enabled = true
			p.visual.stop_action()
			p.remove_meta("mesa")
		if is_instance_valid(hud):
			hud.get("controls").visible = ctrl_vis or GameManager.is_playing()
		_player = null
		my_side = -1
		GameManager.add_stat("jogos_mesa"))
	tg.attach_table(self, i)
