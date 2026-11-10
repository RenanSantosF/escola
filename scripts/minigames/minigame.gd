class_name Minigame
extends Node
## Base dos minijogos do recreio. Cada minijogo é independente: tem regras,
## placar, interface (texto + barra de força) e recompensas próprias.
## Recebe os botões do jogador via on_play/on_interact/on_jump.

signal finished(result: Dictionary)

var mgr: Node  # MinigameManager
var player: PlayerController
var npcs: NPCManager
var world: SchoolWorld
var hud: HUD
var title := "Minijogo"
var id := "minijogo"
var time_left := 0.0
var running := false
var participants: Array[NPC] = []
var _countdown := 0.0
## Brincadeira online (vazio = sozinho): {gid, kind, players, host, teams, opts, me, index}.
var net: Dictionary = {}


## Partida da turma (mesmo que só eu tenha começado: outros podem entrar).
func is_net() -> bool:
	return not net.is_empty()


## Tem outros jogadores de verdade nesta partida?
func is_multi() -> bool:
	return not net.is_empty() and (net.get("players", []) as Array).size() > 1


func setup(manager: Node) -> void:
	mgr = manager
	player = manager.player
	npcs = manager.npcs
	world = manager.world
	hud = manager.hud


## Começa o jogo (subclasses chamam super.begin() no fim).
func begin() -> void:
	running = true
	player.minigame = self
	player._emit_context(true)


func on_play() -> bool:
	return false


func on_play_release() -> bool:
	return false


func on_interact() -> bool:
	return false


func on_interact_release() -> bool:
	return false


func on_jump() -> bool:
	return false


func play_label() -> String:
	return ""


## Botões escondidos durante esta brincadeira ("run", "jump", "emote", "ride", "interact").
func hidden_buttons() -> Array:
	return mgr.HIDE.get(id, []) if mgr else []


func interact_label() -> String:
	return ""


func tick(_delta: float) -> void:
	pass


## Alunos para a brincadeira (colegas de treino se não tiver ninguém por perto).
func students(count: int, near: Vector3, prefer: Array = []) -> Array[NPC]:
	return npcs.students_for_game(count, near, prefer)


## Reserva NPCs (o gerenciador de NPCs deixa de comandá-los).
func take_npcs(list: Array) -> void:
	for n in list:
		if n == null:
			continue
		n.force_unseat()
		n.stop()
		npcs._leave_activity(n)
		n.activity = "minigame"
		n.set_active(true)
		participants.append(n)


func countdown(seconds := 3.0) -> void:
	_countdown = seconds


## Retorna true enquanto a contagem regressiva estiver ativa.
func counting(delta: float) -> bool:
	if _countdown <= 0.0:
		return false
	var before := ceili(_countdown)
	_countdown -= delta
	var now := ceili(_countdown)
	if now != before or _countdown <= 0.0:
		if _countdown <= 0.0:
			hud.show_banner("Valendo!", "")
			AudioManager.play_ui("ui_confirm")
		else:
			hud.show_banner(str(now), title)
			AudioManager.play_ui("ui_click")
	return _countdown > 0.0


## Encerra com resultado. won: -1 perdeu, 0 empate, 1 venceu.
func end_game(won: int, summary: String, coins: int, xp: int, extra := {}) -> void:
	if not running:
		return
	running = false
	hud.set_minigame_text("")
	hud.set_meter(-1.0)
	player.minigame = null
	player.movement_locked = false
	if player.camera_rig:
		player.camera_rig.set_override(null)
	var mult: float = mgr.get("reward_mult") if mgr and mgr.get("reward_mult") != null else 1.0
	coins = int(coins * mult)
	xp = int(xp * mult)
	GameManager.add_rewards(xp, coins)
	var head := "Vitória!" if won > 0 else ("Empate!" if won == 0 else "Não foi dessa vez!")
	hud.show_banner(head, "%s  (+%d moedas, +%d XP)" % [summary, coins, xp])
	if won > 0:
		player.visual.play("celebrate")
		AudioManager.play_ui("celebrate", -4.0)
		Effects.burst(player.global_position + Vector3(0, 1.8, 0), "confetti")
	elif won < 0:
		player.visual.play("sad")
	for n in participants:
		if is_instance_valid(n) and n.role == "student":
			Friendship.add(n.data.get("id", ""), 2 if won >= 0 else 1, id)
	var stats: Dictionary = SaveManager.section("stats")
	var key := "mg_" + id
	var s: Dictionary = stats.get(key, {"played": 0, "won": 0, "best": 0})
	s["played"] = int(s.get("played", 0)) + 1
	if won > 0:
		s["won"] = int(s.get("won", 0)) + 1
	if extra.has("score"):
		s["best"] = maxi(int(s.get("best", 0)), int(extra.score))
	stats[key] = s
	var result := {"id": id, "won": won, "summary": summary, "coins": coins, "xp": xp}
	result.merge(extra)
	cleanup()
	finished.emit(result)


## Libera NPCs e objetos. Subclasses estendem.
func cleanup() -> void:
	for n in participants:
		if is_instance_valid(n) and n in npcs.practice:
			npcs.release_practice(n)
			continue
		if is_instance_valid(n) and n.activity == "minigame":
			n.activity = "wander"
			n.running = false
			if npcs.phase == "recess":
				npcs._start_recess_for(n, false)
	participants.clear()
	player._emit_context(true)


static func fmt_time(t: float) -> String:
	var s := maxi(int(ceil(t)), 0)
	return "%d:%02d" % [s / 60, s % 60]
