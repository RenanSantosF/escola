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
	AudioManager.music_game(true)
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
			AudioManager.play_ui("countdown_go", -2.0)
		else:
			hud.show_banner(str(now), title)
			AudioManager.play_ui("countdown_tick", -3.0)
	return _countdown > 0.0


## Encerra com resultado. won: -1 perdeu, 0 empate, 1 venceu.
func end_game(won: int, summary: String, coins: int, xp: int, extra := {}) -> void:
	if not running:
		return
	running = false
	hud.hide_hint()
	hud.set_minigame_text("")
	hud.set_meter(-1.0)
	player.minigame = null
	player.movement_locked = false
	if player.camera_rig:
		player.camera_rig.set_override(null)
	var mult: float = mgr.get("reward_mult") if mgr and mgr.get("reward_mult") != null else 1.0
	# moedas só vêm das aulas (incentivo a estudar); brincar dá XP
	xp = int((xp + coins) * mult)
	coins = 0
	GameManager.add_rewards(xp, 0)
	var head := "Vitória!" if won > 0 else ("Empate!" if won == 0 else "Não foi dessa vez!")
	# cartão de resultado: estrelas, resumo, recorde e "Jogar de novo"
	var st0: Dictionary = SaveManager.section("stats").get("mg_" + id, {})
	var prev_best := int(st0.get("best", 0))
	var new_rec: bool = extra.has("score") and int(st0.get("played", 0)) > 0 and int(extra.score) > prev_best and id != "corrida"
	var stars := 3 if won > 0 else (2 if won == 0 else 1)
	var rec_txt := ""
	if extra.has("score") and id != "corrida":
		rec_txt = "NOVO RECORDE!" if new_rec else "Seu recorde: %d" % maxi(prev_best, int(extra.score))
	var again := Callable()
	if mgr and not is_net() and summary != "O sinal tocou!" and summary != "Mudou de sala":
		var gid := id
		var m = mgr
		again = func():
			if not m.start(gid):
				GameManager.show_toast("Agora não dá: brincadeiras só no recreio!" if not m.is_recess() else "Espere um pouquinho e tente de novo.")
	hud.show_result(title, head, summary, stars, xp, rec_txt, again)
	if won > 0:
		player.visual.play("celebrate")
		AudioManager.play_ui("win", -3.0)
		Effects.burst(player.global_position + Vector3(0, 1.8, 0), "confetti")
	elif won < 0:
		player.visual.play("sad")
		AudioManager.play_ui("lose", -5.0)
	else:
		AudioManager.play_ui("reward", -4.0)
	AudioManager.music_game(false)
	for n in participants:
		if is_instance_valid(n) and n.role == "student":
			Friendship.add(n.data.get("id", ""), 2 if won >= 0 else 1, id)
	var stats: Dictionary = SaveManager.section("stats")
	var key := "mg_" + id
	var s: Dictionary = stats.get(key, {"played": 0, "won": 0, "best": 0})
	if new_rec:
		get_tree().create_timer(0.6).timeout.connect(func(): AudioManager.play_ui("levelup", -4.0))
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


# ------------------------------------------------------------- dicas
## Dicas temporárias: no começo (só nas primeiras partidas), quando a criança
## fica parada sem jogar e quando erra várias vezes seguidas. Cada dica aparece
## no máximo uma vez por partida e some sozinha.
var _hinted := {}
var _idle_t := 0.0
var _misses := 0


## Dicas desta brincadeira: {"start": ..., "idle": ..., "miss": ...}
func hints() -> Dictionary:
	return {}


func hint(key: String, text := "") -> void:
	if _hinted.has(key) or not running:
		return
	var t := text if text != "" else str(hints().get(key, ""))
	if t == "":
		return
	_hinted[key] = true
	hud.show_hint(t)


## O jogador fez alguma coisa (o manager chama a cada botão).
func note_input() -> void:
	_idle_t = 0.0


## Errou: depois de 2 erros seguidos, mostra a dica de erro.
func note_miss() -> void:
	_misses += 1
	if _misses >= 2:
		hint("miss")


func note_hit() -> void:
	_misses = 0


## Chamado todo quadro pelo manager (antes do tick do jogo).
func hint_tick(delta: float) -> void:
	if not running:
		return
	if _countdown > 0.0:
		_idle_t = 0.0
		return
	if not _hinted.has("start_checked"):
		_hinted["start_checked"] = true
		var plays := int((SaveManager.section("stats").get("mg_" + id, {}) as Dictionary).get("played", 0))
		if plays < 3:
			get_tree().create_timer(0.8).timeout.connect(func(): hint("start"))
	_idle_t += delta
	# andar também conta como jogar (futebol, esconde, guerra...)
	if player.read_move_raw().length() > 0.2:
		_idle_t = 0.0
	if _idle_t > 7.0:
		hint("idle")


# ------------------------------------------------------------- diversão comum
## Sequência de acertos: cada acerto soa um tom acima; 3 seguidos = x2, 6 = x3.
var combo := 0
var best_combo := 0
var _last_tick_s := -1


func combo_mult() -> int:
	return 3 if combo >= 6 else (2 if combo >= 3 else 1)


## Acertou: soma na sequência e devolve o multiplicador.
func add_combo() -> int:
	note_hit()
	combo += 1
	best_combo = maxi(best_combo, combo)
	AudioManager.play_combo(mini(combo - 1, 8))
	if combo == 3:
		hud.show_banner("COMBO x2!", "3 seguidos: pontos em dobro")
		AudioManager.play_ui("combo", -3.0)
	elif combo == 6:
		hud.show_banner("PEGANDO FOGO! x3", "6 seguidos!")
		AudioManager.play_ui("crowd_cheer", -8.0)
		Effects.burst(player.global_position + Vector3(0, 2.0, 0), "confetti")
	return combo_mult()


## Errou: a sequência acaba.
func break_combo() -> void:
	note_miss()
	if combo >= 3:
		GameManager.show_toast("Sequência de %d acabou!" % combo)
	combo = 0


## Número que sobe e some no lugar (ex.: "+20").
func popup(pos: Vector3, text: String, color := Color("ffd23f"), size := 72) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font = UITheme.bold_font()
	l.font_size = size
	l.outline_size = 18
	l.outline_modulate = Color(0, 0, 0, 0.75)
	l.modulate = color
	l.pixel_size = 0.006
	world.add_child(l)
	l.global_position = pos
	l.scale = Vector3.ONE * 0.4
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector3.ONE, 0.08)
	tw.parallel().tween_property(l, "global_position", pos + Vector3(0, 1.2, 0), 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


## Tique-taque nos últimos 10 segundos (chame todo quadro com o tempo que falta).
func tick_clock(left: float) -> void:
	var s := int(ceil(left))
	if s != _last_tick_s:
		_last_tick_s = s
		if s <= 10 and s > 0:
			AudioManager.play_ui("timer_warn", -6.0 if s > 5 else -2.0)
			if s == 10:
				hud.show_banner("10 segundos!", "Últimos segundos valem DOBRO" if double_end() else "")


## Últimos 10 s valem dobro? (os jogos de tempo ligam)
func double_end() -> bool:
	return false


static func fmt_time(t: float) -> String:
	var s := maxi(int(ceil(t)), 0)
	return "%d:%02d" % [s / 60, s % 60]
