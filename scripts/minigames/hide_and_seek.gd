extends Minigame
## Esconde-esconde no Parque do Morro. Sozinho, alterna as rodadas:
##  • VOCÊ PROCURA: conta até 10 de olhos fechados enquanto 5 colegas se
##    escondem; ache todos chegando perto (quente/frio, risadinhas, pistas).
##  • VOCÊ SE ESCONDE: um colega conta e depois procura; esconda-se e
##    AGACHE (botão amarelo) — agachado ele precisa chegar bem pertinho.
## A brincadeira tem LIMITE: só vale dentro da área marcada com bandeirinhas.

const BASE := Vector3(0, 0.05, -82)
const TIME := 150.0
const FIND_DIST := 3.0
## Área do esconde-esconde (x, z, largura, profundidade): bandeirinhas em volta.
const GAME_AREA := Rect2(-60, -122, 120, 44)
const HIDE_COUNT := 15.0   # você se esconde: segundos para achar um lugar
const SURVIVE := 75.0      # e precisa ficar sem ser achado por esse tempo
const SEEN_DIST := 2.6     # o procurador acha você em pé a essa distância...
const SEEN_DIST_CROUCH := 1.3  # ...e agachado só bem pertinho

var hiders: Array = []  # [{npc, spot, found, t}]
var found := 0
var role := "seek"  # "seek" (você procura) ou "hide" (você se esconde)
var _counting := 4.5
var _hint_t := 25.0
var _heat_t := 0.0
var _blind: ColorRect
var _flags: Node3D
var _out_warn_t := 0.0
var seeker: NPC
var _seek_targets: Array = []
var _seek_t := 0.0
var _caught := false


func begin() -> void:
	_build_flags()
	if is_net():
		_net_begin()
		return
	var st: Dictionary = SaveManager.section("stats")
	var rounds := int(st.get("esconde_rodadas", 0))
	st["esconde_rodadas"] = rounds + 1
	role = "seek" if rounds % 2 == 0 else "hide"
	var cands: Array[NPC] = students(5 if role == "seek" else 4, Vector3(-4.0, 0.05, -78.0))
	cands.shuffle()
	if role == "hide" and not cands.is_empty():
		seeker = cands.pop_front()
	var spots := _hide_spots()
	spots.shuffle()
	var k := 0
	for n in cands:
		if hiders.size() >= 5 or k >= spots.size():
			break
		hiders.append({"npc": n, "spot": spots[k], "found": false, "t": 0.0})
		k += 1
	var list: Array = hiders.map(func(h): return h.npc)
	if seeker:
		list.append(seeker)
	take_npcs(list)
	for h in hiders:
		var n: NPC = h.npc
		n.teleport(BASE + Vector3(randf_range(-2, 2), 0, randf_range(-1.5, 1.5)), PI)
		n.go_to(h.spot, true, func(): n.visual.play("crouch"))
	player.force_stand()
	player.global_position = BASE + Vector3(0, 0, 2.0)
	player.yaw = 0.0
	if role == "seek":
		player.movement_locked = true
		_blind = ColorRect.new()
		_blind.color = Color(0.05, 0.07, 0.15, 0.88)
		_blind.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_blind.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(_blind)
		time_left = TIME
	else:
		_counting = HIDE_COUNT
		time_left = SURVIVE
		if seeker:
			seeker.teleport(BASE + Vector3(0, 0, -0.5), 0.0)
			seeker.visual.play("look_around")
			seeker.say("Vou contar até 15!", 2.5)
	super.begin()
	if role == "seek":
		hud.show_banner("Você procura!", "Contando até 10... não vale espiar!")
	else:
		hud.show_banner("Esconda-se!", "%s vai contar até 15. Corra e AGACHE (botão amarelo)!" % (seeker.display_name if seeker else "Alguém"))


## Lugares para se esconder dentro da área: atrás de árvores, do coreto, do
## palco, das pedras do lago e do morrinho (nunca dentro do lago).
func _hide_spots() -> Array:
	var out := []
	for t in world.builder.trees:
		var p: Vector3 = t.pos
		if not GAME_AREA.grow(-2.0).has_point(Vector2(p.x, p.z)) or p.z > -88.0:
			continue
		var away := Vector3(p.x - BASE.x, 0, p.z - BASE.z).normalized()
		var s := p + away * 1.1
		s.y = ParkHill.height(s.x, s.z) + 0.05
		if s.y < ParkHill.WATER_Y + 0.3:
			continue
		out.append(s)
	for extra in [Vector3(ParkHill.HILL.x - 4.0, 0, ParkHill.HILL.z - 2.0), Vector3(ParkHill.AMPHI.x + 3.0, 0, ParkHill.AMPHI.y - 8.6),
			Vector3(ParkHill.LAKE.x + 6.0, 0, ParkHill.LAKE.y - 9.5)]:
		var e: Vector3 = extra
		if not GAME_AREA.has_point(Vector2(e.x, e.z)):
			continue
		e.y = ParkHill.height(e.x, e.z) + 0.05
		out.append(e)
	return out


## Bandeirinhas coloridas marcando o limite da brincadeira.
func _build_flags() -> void:
	_flags = Node3D.new()
	_flags.name = "LimiteEsconde"
	var md := MeshData.new()
	var cols := [Color("ff4d6d"), Color("ffd23f"), Color("3ec1d3"), Color("6be36b")]
	var pts := []
	var step := 6.0
	var r := GAME_AREA
	var x := r.position.x
	while x <= r.end.x:
		pts.append(Vector2(x, r.position.y))
		pts.append(Vector2(x, r.end.y))
		x += step
	var z := r.position.y + step
	while z < r.end.y:
		pts.append(Vector2(r.position.x, z))
		pts.append(Vector2(r.end.x, z))
		z += step
	for i in pts.size():
		var p: Vector2 = pts[i]
		var y := ParkHill.height(p.x, p.y)
		md.cur_color = Color("ecf0f1")
		md.add_box(Transform3D(Basis(), Vector3(p.x, y + 0.6, p.y)), Vector3(0.06, 1.2, 0.06))
		md.cur_color = cols[i % cols.size()]
		md.add_box(Transform3D(Basis(), Vector3(p.x + 0.22, y + 1.05, p.y)), Vector3(0.42, 0.28, 0.03))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flags.add_child(mi)
	world.add_child(_flags)


## Fora da área? Volta para dentro (com aviso).
func _keep_inside(delta: float) -> void:
	_out_warn_t -= delta
	var p := player.global_position
	var r := GAME_AREA
	if r.has_point(Vector2(p.x, p.z)):
		return
	var cx := clampf(p.x, r.position.x + 0.8, r.end.x - 0.8)
	var cz := clampf(p.z, r.position.y + 0.8, r.end.y - 0.8)
	player.global_position = Vector3(cx, maxf(p.y, ParkHill.height(cx, cz) + 0.05), cz)
	player.velocity = Vector3.ZERO
	if _out_warn_t <= 0.0:
		_out_warn_t = 2.5
		GameManager.show_toast("Fora da área! O esconde-esconde é só dentro das bandeirinhas.")
		AudioManager.play_ui("ui_error", -6.0)


func play_label() -> String:
	if _can_crouch():
		return "Levantar" if player.crouching else "Agachar"
	return ""


func on_play() -> bool:
	if _can_crouch():
		player.set_crouch(not player.crouching)
		player._emit_context(true)
		return true
	return false


func _can_crouch() -> bool:
	if not running:
		return false
	if is_net():
		return _seeker != _me and _seeker != "" and not (_me in _found_ids)
	return role == "hide" and not _caught


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
	if _counting <= 0.0 or role == "hide" or is_net():
		_keep_inside(delta)
	if is_net():
		_net_tick(delta)
		return
	_watch_hiders(delta)
	if role == "hide":
		_tick_hide(delta)
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
			hud.show_banner("Lá vou eu!", "Procure os %d colegas dentro das bandeirinhas" % hiders.size())
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
		var d := Vector2(n.global_position.x - pp.x, n.global_position.z - pp.z).length()
		nearest = minf(nearest, d)
		if d < FIND_DIST and absf(n.global_position.y - pp.y) < 2.5:
			_found(h)
		elif d < 6.0 and not h.get("ran", false) and randf() < 0.35:
			# fujão! corre para outro esconderijo perto (dá para pegar correndo)
			h["ran"] = true
			var spots := _hide_spots().filter(func(q: Vector3):
				var dq := q.distance_to(n.global_position)
				return dq > 8.0 and dq < 20.0)
			if spots.is_empty():
				continue
			var far: Vector3 = spots.pick_random()
			h.spot = far
			h.t = 0.0
			n.visual.stop_action()
			n.running = true
			n.run_speed = 4.2
			n.go_to(far, true, func():
				if is_instance_valid(n) and not h.found:
					n.visual.play("crouch"))
			n.say("Não me pega!", 1.6)
			AudioManager.play_3d("whoosh", n.global_position, -4.0)
		elif d < 9.0 and randf() < delta * 0.25:
			n.say(["hihi...", "shhh!", "*risadinha*"].pick_random(), 1.4)
	_heat_t -= delta
	var heat := "Quente!" if nearest < 7.0 else ("Morno" if nearest < 15.0 else "Frio")
	if nearest < 15.0 and _heat_t <= 0.0:
		_heat_t = 0.25 if nearest < 7.0 else 0.6
		AudioManager.play_ui("timer_warn", -14.0 if nearest >= 7.0 else -9.0)
	_hint_t -= delta
	if _hint_t <= 0.0:
		_hint_t = 25.0
		_hint()
	var m := int(maxf(time_left, 0.0))
	hud.set_minigame_text("Esconde-esconde  ·  achou %d de %d  ·  %d:%02d  ·  %s" % [found, hiders.size(), m / 60, m % 60, heat])
	if found >= hiders.size() or time_left <= 0.0:
		_finish()


## Quem ficou preso no caminho (árvore, pedra, morro) aparece no esconderijo.
func _watch_hiders(delta: float) -> void:
	for h in hiders:
		if h.found:
			continue
		var n: NPC = h.npc
		if not is_instance_valid(n):
			continue
		h.t += delta
		var far: bool = Vector2(n.global_position.x - h.spot.x, n.global_position.z - h.spot.z).length() > 1.5
		if far and h.t > 14.0 and (not n.moving or h.t > 22.0):
			n.teleport(h.spot, n.yaw)
			n.visual.play("crouch")
			h.t = 0.0
		if not GAME_AREA.grow(1.0).has_point(Vector2(n.global_position.x, n.global_position.z)):
			n.teleport(h.spot, n.yaw)
			h.t = 0.0


# ---------------------------------------------------------------- você se esconde

func _tick_hide(delta: float) -> void:
	if _caught:
		return
	if _counting > 0.0:
		var before := ceili(_counting)
		_counting -= delta
		var now := ceili(_counting)
		if now != before and now > 0:
			hud.set_minigame_text("%s está contando... %d  ·  esconda-se e AGACHE!" % [seeker.display_name if seeker else "", 16 - now])
			AudioManager.play_ui("ui_click", -12.0)
		if _counting <= 0.0:
			AudioManager.play_ui("whistle", -6.0)
			hud.show_banner("Lá vem ele!", "Fique quietinho e agachado!")
			if seeker:
				seeker.visual.stop_action()
				seeker.say("Lá vou eu!", 2.0)
				seeker.running = true
				seeker.run_speed = 3.4
				_seek_targets = _hide_spots()
				_seek_targets.shuffle()
				_seek_targets = _seek_targets.slice(0, 10)
		return
	time_left -= delta
	tick_clock(time_left)
	if seeker == null:
		_finish()
		return
	var pp := player.global_position
	var sp := seeker.global_position
	var d := Vector2(pp.x - sp.x, pp.z - sp.z).length()
	var see := SEEN_DIST_CROUCH if player.crouching else SEEN_DIST
	if d < see and absf(pp.y - sp.y) < 2.5:
		_caught = true
		player.set_crouch(false)
		seeker.face(pp)
		seeker.say("Achei você!", 2.5)
		seeker.visual.play("celebrate")
		hud.show_banner("Te achou!", "Na próxima, agache atrás de uma árvore!")
		get_tree().create_timer(2.0).timeout.connect(_finish)
		return
	# o procurador acha também os colegas-bot no caminho
	for h in hiders:
		if not h.found and (h.npc as NPC).global_position.distance_to(sp) < 2.4:
			h.found = true
			found += 1
			(h.npc as NPC).visual.stop_action()
			(h.npc as NPC).say("Ah, me achou!", 2.0)
			seeker.say("Achei %s!" % (h.npc as NPC).display_name, 1.8)
	# vai de esconderijo em esconderijo; em pé e perto, ele percebe você
	_seek_t -= delta
	var noticed := not player.crouching and d < 10.0
	if noticed and _seek_t <= 0.0:
		_seek_t = 1.0
		seeker.say("Hum... ouvi alguma coisa!", 1.4)
		seeker.go_to(pp, true)
	elif not seeker.moving and _seek_t <= 0.0:
		_seek_t = randf_range(0.6, 1.4)
		if _seek_targets.is_empty():
			_seek_targets = _hide_spots()
			_seek_targets.shuffle()
		var tgt: Vector3 = _seek_targets.pop_front()
		# às vezes ele "chuta" perto de onde você está (mais emoção)
		if randf() < 0.3:
			tgt = pp + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
			tgt.x = clampf(tgt.x, GAME_AREA.position.x + 1, GAME_AREA.end.x - 1)
			tgt.z = clampf(tgt.z, GAME_AREA.position.y + 1, GAME_AREA.end.y - 1)
			tgt.y = ParkHill.height(tgt.x, tgt.z) + 0.05
		seeker.go_to(tgt, randf() < 0.5)
	var heat := "PERTO!" if d < 7.0 else ("chegando..." if d < 14.0 else "longe")
	var m := int(maxf(time_left, 0.0))
	hud.set_minigame_text("Escondido  ·  %d:%02d  ·  procurador: %s%s" % [m / 60, m % 60, heat, "  ·  agachado" if player.crouching else "  ·  AGACHE!"])
	if time_left <= 0.0:
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
			var fuzz := p + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
			hud.minimap.set_markers("pista", [{"pos": fuzz, "color": Color("ff4d6d"), "icon": "?"}])
			GameManager.show_toast("Pista: ouvi uma risada perto do ponto \"?\" do mapa!")
			get_tree().create_timer(9.0).timeout.connect(func():
				if is_instance_valid(hud):
					hud.minimap.set_markers("pista", []))
			return


func _finish() -> void:
	if not running:
		return
	if role == "hide":
		var safe := not _caught
		end_game(1 if safe else -1, "Esconde-esconde: %s" % ("ninguém te achou!" if safe else "te acharam"), 22 if safe else 6, 30 if safe else 10, {"score": int(SURVIVE - maxf(time_left, 0.0))})
		return
	var total := hiders.size()
	var won := 1 if found >= total and total > 0 else -1
	if found >= total and total > 0 and time_left > TIME * 0.5:
		GameManager.unlock_achievement("detetive")
	end_game(won, "Esconde-esconde: achou %d de %d" % [found, total], 6 + found * 4, 12 + found * 6, {"score": found})


func cleanup() -> void:
	if is_instance_valid(_blind):
		_blind.queue_free()
	if is_instance_valid(_flags):
		_flags.queue_free()
	player.set_crouch(false)
	hud.minimap.set_markers("pista", [])
	for h in hiders:
		var n: NPC = h.npc
		if is_instance_valid(n):
			n.visual.stop_action()
	if is_instance_valid(seeker):
		seeker.visual.stop_action()
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
		hud.show_banner("Esconda-se!", "%s vai procurar. Esconda-se e AGACHE (botão amarelo)!" % NetworkManager.name_of(_seeker))


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
		player.set_crouch(false)
		player._emit_context(true)
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


func hints() -> Dictionary:
	if role == "hide" or (is_net() and _seeker != _me):
		return {"start": "Corra para trás de uma árvore e aperte AGACHAR: agachado é muito mais difícil de achar!", "idle": "Fique agachado e quietinho!", "miss": ""}
	return {"start": "Siga o QUENTE ou FRIO e o som: quanto mais rápido, mais perto!", "idle": "Ande pelo parque: atrás das árvores, do coreto e perto do lago.", "miss": ""}
