extends Minigame
## Esconde-esconde no Parque do Morro: você conta até 10 de olhos fechados
## enquanto 5 colegas se escondem (atrás de árvores, do coreto, do palco...).
## Ache todos em 2 minutos chegando perto deles. Dicas: risadinhas quando
## você chega perto e, de tempos em tempos, uma pista no minimapa.

const BASE := Vector3(0, 0.05, -82)
const TIME := 120.0
const FIND_DIST := 2.6

var hiders: Array = []  # [{npc, spot, found}]
var found := 0
var _counting := 4.5
var _hint_t := 35.0
var _heat_t := 0.0
var _blind: ColorRect


func begin() -> void:
	if is_net():
		_net_begin()
		return
	var cands: Array[NPC] = students(5, Vector3(-4.0, 0.05, -78.0))
	cands.shuffle()
	var spots := _hide_spots()
	spots.shuffle()
	var k := 0
	for n in cands:
		if hiders.size() >= 5 or k >= spots.size():
			break
		hiders.append({"npc": n, "spot": spots[k], "found": false})
		k += 1
	var list: Array = hiders.map(func(h): return h.npc)
	take_npcs(list)
	for h in hiders:
		var n: NPC = h.npc
		n.teleport(BASE + Vector3(randf_range(-2, 2), 0, randf_range(-1.5, 1.5)), PI)
		n.go_to(h.spot, true, func(): n.visual.play("crouch"))
	player.force_stand()
	player.global_position = BASE + Vector3(0, 0, 2.0)
	player.yaw = 0.0  # de costas para o parque, contando
	player.movement_locked = true
	# "olhos fechados"
	_blind = ColorRect.new()
	_blind.color = Color(0.05, 0.07, 0.15, 0.88)
	_blind.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_blind)
	time_left = TIME
	super.begin()
	hud.show_banner("Esconde-esconde!", "Contando até 10... não vale espiar!")


## Lugares para se esconder: atrás de árvores do parque, do coreto, do palco,
## das pedras do lago e do morrinho.
func _hide_spots() -> Array:
	var out := []
	var area := ParkHill.AREA
	for t in world.builder.trees:
		var p: Vector3 = t.pos
		if not area.has_point(Vector2(p.x, p.z)) or p.z > -88.0:
			continue
		# lado da árvore oposto à base
		var away := Vector3(p.x - BASE.x, 0, p.z - BASE.z).normalized()
		var s := p + away * 1.1
		s.y = ParkHill.height(s.x, s.z) + 0.05
		out.append(s)
	for extra in [Vector3(ParkHill.HILL.x - 4.0, 0, ParkHill.HILL.z - 2.0), Vector3(ParkHill.AMPHI.x + 3.0, 0, ParkHill.AMPHI.y - 8.6),
			Vector3(ParkHill.LAKE.x + 6.0, 0, ParkHill.LAKE.y - 9.5), Vector3(ParkHill.SMALL_HILL.x, 0, ParkHill.SMALL_HILL.z - 8.0)]:
		var e: Vector3 = extra
		e.y = ParkHill.height(e.x, e.z) + 0.05
		out.append(e)
	return out


func play_label() -> String:
	return ""


func interact_label() -> String:
	return "Desistir"


func on_interact() -> bool:
	if is_net() and mgr and mgr.online_play:
		mgr.online_play.leave()
		return true
	_finish()
	return true


func tick(delta: float) -> void:
	if not running:
		return
	if is_net():
		_net_tick(delta)
		return
	if _counting > 0.0:
		var before := ceili(_counting * 2.2)
		_counting -= delta
		var now := ceili(_counting * 2.2)
		if now != before and now > 0:
			hud.set_minigame_text("Contando... %d" % (11 - now))
			AudioManager.play_ui("ui_click", -10.0)
		if _counting <= 0.0:
			player.movement_locked = false
			if is_instance_valid(_blind):
				var tw := create_tween()
				tw.tween_property(_blind, "color:a", 0.0, 0.4)
				tw.tween_callback(_blind.queue_free)
			hud.show_banner("Lá vou eu!", "Procure os 5 colegas pelo parque")
			AudioManager.play_ui("whistle", -6.0)
		return
	time_left -= delta
	tick_clock(time_left)
	var pp := player.global_position
	var nearest := INF
	for h in hiders:
		if h.found:
			continue
		var n: NPC = h.npc
		var d := n.global_position.distance_to(pp)
		nearest = minf(nearest, d)
		if d < FIND_DIST:
			_found(h)
		elif d < 6.0 and not h.get("ran", false) and randf() < 0.4:
			# fujão! corre para outro esconderijo (dá para pegar correndo)
			h["ran"] = true
			var spots := _hide_spots()
			var far: Vector3 = spots.pick_random() if not spots.is_empty() else n.global_position + Vector3(8, 0, 0)
			n.visual.stop_action()
			n.running = true
			n.run_speed = 4.6
			n.go_to(far, true, func():
				if is_instance_valid(n) and not h.found:
					n.visual.play("crouch"))
			n.say("Não me pega!", 1.6)
			AudioManager.play_3d("whoosh", n.global_position, -4.0)
		elif d < 9.0 and randf() < delta * 0.25:
			n.say(["hihi...", "shhh!", "*risadinha*"].pick_random(), 1.4)
	# quente ou frio: batida mais rápida quanto mais perto
	_heat_t -= delta
	var heat := "Quente!" if nearest < 7.0 else ("Morno" if nearest < 15.0 else "Frio")
	if nearest < 15.0 and _heat_t <= 0.0:
		_heat_t = 0.25 if nearest < 7.0 else 0.6
		AudioManager.play_ui("timer_warn", -14.0 if nearest >= 7.0 else -9.0)
	_hint_t -= delta
	if _hint_t <= 0.0:
		_hint_t = 30.0
		_hint()
	var m := int(maxf(time_left, 0.0))
	hud.set_minigame_text("Esconde-esconde  ·  achou %d de %d  ·  %d:%02d  ·  %s" % [found, hiders.size(), m / 60, m % 60, heat])
	if found >= hiders.size() or time_left <= 0.0:
		_finish()


func _found(h: Dictionary) -> void:
	h.found = true
	found += 1
	var n: NPC = h.npc
	n.visual.stop_action()
	n.face(player.global_position)
	n.say(["Ah, me achou!", "Puxa! Achou!", "Como você me viu?!"].pick_random(), 2.2)
	n.visual.play("sad" if randf() < 0.4 else "celebrate")
	add_combo()
	popup(n.global_position + Vector3(0, 2.2, 0), "Achei! %d/%d" % [found, hiders.size()], Color("6be36b"))
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(n):
			n.go_to(BASE + Vector3(randf_range(-3, 3), 0, randf_range(-1, 1)), true))


func _hint() -> void:
	for h in hiders:
		if not h.found:
			var p: Vector3 = (h.npc as NPC).global_position
			var fuzz := p + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
			hud.minimap.set_markers("pista", [{"pos": fuzz, "color": Color("ff4d6d"), "icon": "?"}])
			GameManager.show_toast("Pista: ouvi uma risada perto do ponto \"?\" do mapa!")
			get_tree().create_timer(9.0).timeout.connect(func():
				if is_instance_valid(hud):
					hud.minimap.set_markers("pista", []))
			return


func _finish() -> void:
	if not running:
		return
	var total := hiders.size()
	var won := 1 if found >= total and total > 0 else (0 if found >= 3 else -1)
	if found >= total and total > 0 and time_left > TIME * 0.5:
		GameManager.unlock_achievement("detetive")
	end_game(won, "Esconde-esconde: achou %d de %d" % [found, total], 6 + found * 4, 12 + found * 6, {"score": found})


func cleanup() -> void:
	if is_instance_valid(_blind):
		_blind.queue_free()
	hud.minimap.set_markers("pista", [])
	for h in hiders:
		var n: NPC = h.npc
		if is_instance_valid(n):
			n.visual.stop_action()
	super.cleanup()



# ================================================================ com a turma
# O servidor decide quem procura, as fases e quem foi achado (chegar pertinho).

var _me := ""
var _seeker := ""
var _phase := ""
var _found_ids: Array = []
var _state_ms := 0
var _left0 := 0


func _net_begin() -> void:
	_me = str(net.get("me", ""))
	player.force_stand()
	player.global_position = BASE + Vector3(randf_range(-2, 2), 0, 2.0 + randf_range(-1, 1))
	player.yaw = 0.0
	time_left = TIME
	super.begin()
	_read_state()
	if _seeker == _me:
		hud.show_banner("Você procura!", "Feche os olhos e conte... sem espiar!")
	else:
		hud.show_banner("Esconda-se!", "%s vai procurar. Corra para um esconderijo!" % NetworkManager.name_of(_seeker))


func _read_state() -> void:
	var g := NetworkManager.game_state("esconde")
	var h: Variant = g.get("hide")
	if not (h is Dictionary):
		return
	var phase := str(h.get("phase", ""))
	var found: Array = h.get("found", [])
	if phase != _phase or found.size() != _found_ids.size() or _seeker == "":
		_state_ms = Time.get_ticks_msec()
		_left0 = int(h.get("left", 0))
	_seeker = str(h.get("seeker", ""))
	if phase != _phase:
		_on_phase(phase)
	for id in found:
		if not id in _found_ids:
			_found_ids.append(id)
			_on_found(str(id))
	_phase = phase


func _on_phase(phase: String) -> void:
	var seeker := _seeker == _me
	if phase == "hiding" and seeker:
		player.movement_locked = true
		if _blind == null:
			_blind = ColorRect.new()
			_blind.color = Color(0.05, 0.07, 0.15, 0.9)
			_blind.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_blind.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hud.add_child(_blind)
	elif phase == "seeking":
		player.movement_locked = false
		if is_instance_valid(_blind):
			var tw := create_tween()
			tw.tween_property(_blind, "color:a", 0.0, 0.4)
			tw.tween_callback(_blind.queue_free)
		AudioManager.play_ui("whistle", -6.0)
		hud.show_banner("Lá vou eu!" if seeker else "Shhh! Fique escondido!", "Procure a turma pelo parque" if seeker else "%s está procurando" % NetworkManager.name_of(_seeker))


func _on_found(id: String) -> void:
	AudioManager.play_ui("ui_confirm", -2.0)
	if id == _me:
		hud.show_banner("Te acharam!", "%s te achou. Espere na base." % NetworkManager.name_of(_seeker))
		player.global_position = BASE + Vector3(randf_range(-3, 3), 0, randf_range(-1, 1))
		player.velocity = Vector3.ZERO
	elif _seeker == _me:
		GameManager.show_toast("Achou %s!" % NetworkManager.name_of(id))
	else:
		GameManager.show_toast("%s foi achado!" % NetworkManager.name_of(id))


func _net_tick(_delta: float) -> void:
	_read_state()
	var left := maxi(_left0 - int((Time.get_ticks_msec() - _state_ms) / 1000), 0)
	var hiders := (net.get("players", []) as Array).size() - 1
	match _phase:
		"hiding":
			hud.set_minigame_text(("Contando... %d" if _seeker == _me else "Esconda-se! %d s") % left)
		"seeking":
			if _seeker == _me:
				hud.set_minigame_text("Procurando  ·  achou %d de %d  ·  %d:%02d  ·  chegue pertinho!" % [_found_ids.size(), maxi(hiders, 0), left / 60, left % 60])
			elif _me in _found_ids:
				hud.set_minigame_text("Você foi achado  ·  torça pelos outros  ·  %d:%02d" % [left / 60, left % 60])
			else:
				hud.set_minigame_text("Escondido  ·  %d:%02d  ·  não deixe %s chegar perto!" % [left / 60, left % 60, NetworkManager.name_of(_seeker)])
		_:
			hud.set_minigame_text("Esconde-esconde · esperando a turma...")


## Fim (o servidor mandou o placar).
func on_net_event(ev: Dictionary) -> void:
	if str(ev.get("kind", "")) != "results" or not running:
		return
	var won := 0
	if _seeker == _me:
		won = 1 if _found_ids.size() * 2 >= maxi((net.get("players", []) as Array).size() - 1, 1) else -1
	else:
		won = -1 if _me in _found_ids else 1
	var summary := ("Você achou %d" % _found_ids.size()) if _seeker == _me else ("Te acharam!" if won < 0 else "Ninguém te achou!")
	end_game(won, "Esconde-esconde: " + summary, 6 + _found_ids.size() * 4 if _seeker == _me else (16 if won > 0 else 6), 14 if won > 0 else 8)
