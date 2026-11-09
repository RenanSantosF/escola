class_name NPCSocial
extends Node
## Comportamento social dos alunos-bot (roda poucas vezes por segundo):
## - cumprimentam o jogador quando ele chega perto (mais animados se forem amigos)
## - amigos às vezes vêm andar junto com o jogador no recreio
## - comemoram quando o jogador ganha uma brincadeira por perto
## - param de correr e "disfarçam" quando o diretor passa
## - olham para o jogador quando ele corre/pula perto

const TICK := 0.4

var mgr: NPCManager
var player: PlayerController
var _t := 0.0
var _greeted := {}  # npc -> tempo do último cumprimento
var _follower: NPC = null
var _follow_t := 0.0
var _follow_cd := 40.0
var _now := 0.0


func setup(m: NPCManager, p: PlayerController) -> void:
	mgr = m
	player = p


func _process(delta: float) -> void:
	if player == null or not GameManager.is_playing():
		return
	_now += delta
	_t -= delta
	_follow_cd -= delta
	if _t > 0.0:
		return
	_t = TICK
	var pp := player.global_position
	var recess := mgr.phase == "recess"
	var director_near := mgr.director and mgr.director.active and mgr.director.activity == "patrol"
	for n in mgr.npcs:
		if not n.active or n.role != "student" or n.talking_to_player or n.activity == "minigame":
			continue
		var d := n.global_position.distance_to(pp)
		# 1) cumprimento
		if d < 4.0 and d > 0.8 and not n.sitting and _now - float(_greeted.get(n, -999.0)) > 75.0 and randf() < 0.5:
			_greeted[n] = _now
			_greet(n)
			continue
		# 2) olhar quando o jogador agita perto
		if d < 7.0 and not n.moving and not n.sitting and player.velocity.length() > 4.0 and randf() < 0.3:
			n.face(pp)
		# 3) diretor por perto: quem corre, anda
		if director_near and n.running and n.global_position.distance_to(mgr.director.global_position) < 12.0:
			n.running = false
			if randf() < 0.25:
				n.say(["Disfarça, o diretor!", "Anda, anda, não corre!", "Opa, o diretor tá vendo..."].pick_random(), 2.0)
	if recess:
		_update_follower()
	elif _follower:
		_stop_follow()


func _greet(n: NPC) -> void:
	var lv := Friendship.level(str(n.data.get("id", "")))
	var line: String
	if lv >= 4:
		line = ["Meu melhor amigo chegou!", "Ei! Vem brincar comigo!", "Até que enfim você chegou!"].pick_random()
	elif lv >= 2:
		line = ["E aí, parceiro!", "Opa, tudo certo?", "Oi de novo!", "Bora fazer alguma coisa?"].pick_random()
	else:
		line = ["Oi!", "Olá!", "Bom dia!", "E aí?", "Tudo bem?"].pick_random()
	n.face(player.global_position)
	n.say(line, 2.2)
	if n.visual.animator.upper_action == "":
		n.visual.play("wave")


func _update_follower() -> void:
	if _follower:
		_follow_t -= TICK
		if not is_instance_valid(_follower) or not _follower.active or _follower.activity == "minigame" or _follow_t <= 0.0 or player.minigame != null:
			_stop_follow()
			return
		var d := _follower.global_position.distance_to(player.global_position)
		if d > 3.2:
			var side := player.global_basis.x * 1.2
			_follower.go_to(player.global_position + side, d > 7.0)
		elif not _follower.moving:
			_follower.face(player.global_position + Vector3(sin(player.yaw), 0, cos(player.yaw)) * 3.0)
		return
	if _follow_cd > 0.0 or player.minigame != null:
		return
	# um amigo (amizade 2+) perto e à toa vem andar junto
	for n in mgr.classmates:
		if not n.active or n.sitting or n.talking_to_player or n.activity in ["minigame", "queue", "football"]:
			continue
		if Friendship.level(str(n.data.get("id", ""))) < 2:
			continue
		if n.global_position.distance_to(player.global_position) < 14.0:
			_follower = n
			_follow_t = randf_range(25.0, 45.0)
			mgr._leave_activity(n)
			n.activity = "follow"
			n.say(["Posso ir junto?", "Espera eu!", "Vou com você!"].pick_random(), 2.2)
			break
	_follow_cd = 50.0


func _stop_follow() -> void:
	if _follower and is_instance_valid(_follower):
		_follower.activity = "wander"
		if randf() < 0.5:
			_follower.say(["Vou ali e já volto!", "Foi legal andar com você!", "Te vejo depois!"].pick_random(), 2.0)
	_follower = null
	_follow_cd = 45.0


## Chamado pelo MinigameManager ao terminar uma brincadeira.
func on_minigame_finished(result: Dictionary) -> void:
	if int(result.get("won", 0)) <= 0:
		return
	var pp := player.global_position
	var k := 0
	for n in mgr.npcs:
		if k >= 4:
			break
		if n.active and n.role == "student" and not n.sitting and n.activity != "minigame" and n.global_position.distance_to(pp) < 12.0:
			k += 1
			n.face(pp)
			n.visual.play(["clap", "celebrate"].pick_random())
			n.say(["Boa!!", "Mandou bem!", "Que demais!", "Campeão!", "Uhuul!"].pick_random(), 2.0)
