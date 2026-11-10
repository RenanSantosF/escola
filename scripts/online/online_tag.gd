class_name OnlineTag
extends Node
## Pique-pega online (o servidor decide quem pegou quem). Aqui fica a parte
## visual e a interface: convite para a sala toda, espera no pátio (ponto
## de encontro na árvore central), marcador vermelho sobre o pegador,
## placar ao final e prêmios. Enquanto brinca, o recreio não acaba.

const MEET_POINT := Vector3(0, 0.05, -10)
const REWARDS := [[40, 50], [25, 35], [15, 25]]  # [moedas, xp] por colocação

var session: OnlineSession
var player: PlayerController
var hud: HUD
var day: SchoolDay
var st: Dictionary = {}
var _invite_box: PanelContainer
var _ctrl_box: HBoxContainer
var _start_btn: Button
var _marker: Node3D
var _was_it := false


func setup(s: OnlineSession, p: PlayerController, h: HUD, d: SchoolDay, ui_parent: Node) -> void:
	session = s
	player = p
	hud = h
	day = d
	NetworkManager.tag_state.connect(_on_state)
	NetworkManager.tag_event.connect(_on_event)
	_marker = _make_marker()
	_marker.visible = false
	player.get_parent().add_child(_marker)
	# convite
	_invite_box = PanelContainer.new()
	_invite_box.add_theme_stylebox_override("panel", UITheme.box(Color("ff4d6d"), 22, Color.WHITE, 4, 6))
	_invite_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_invite_box.position = Vector2(-280, 120)
	_invite_box.custom_minimum_size = Vector2(560, 0)
	_invite_box.visible = false
	ui_parent.add_child(_invite_box)
	# botões durante a espera/jogo
	_ctrl_box = HBoxContainer.new()
	_ctrl_box.add_theme_constant_override("separation", 10)
	_ctrl_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_ctrl_box.position = Vector2(-200, 160)
	_ctrl_box.visible = false
	ui_parent.add_child(_ctrl_box)
	_start_btn = UITheme.make_button("Começar agora", func(): NetworkManager.tag_start(), 220)
	_ctrl_box.add_child(_start_btn)
	_ctrl_box.add_child(UITheme.make_button("Sair do pique-pega", func():
		NetworkManager.tag_leave()
		_leave_local(), 240))
	if hud and hud.controls:
		hud.controls.blockers.append(_invite_box)
		hud.controls.blockers.append(_ctrl_box)


func _exit_tree() -> void:
	for n in [_invite_box, _ctrl_box, _marker]:
		if is_instance_valid(n):
			n.queue_free()
	if day:
		day.hold_recess = false


func can_play() -> bool:
	return day == null or day.phase in [SchoolDay.Phase.RECESS, SchoolDay.Phase.ARRIVAL, SchoolDay.Phase.DAY_END]


## Botão "Pique-pega!" do chat.
func invite() -> void:
	if player.minigame != null:
		GameManager.show_toast("Termine a brincadeira antes de chamar o pique-pega.")
		return
	if not NetworkManager.is_online():
		GameManager.show_toast("Conectando ao online...")
		return
	if not can_play():
		GameManager.show_toast("Agora é hora de aula! Chame o pique-pega no recreio.")
		return
	NetworkManager.tag_invite()


func in_game() -> bool:
	return NetworkManager.my_id in st.get("players", [])


func _on_event(ev: Dictionary) -> void:
	var names: Dictionary = ev.get("names", {})
	match str(ev.get("kind", "")):
		"invite":
			if str(ev.get("from", "")) == NetworkManager.my_id:
				hud.show_banner("Pique-pega chamado!", "Esperando a turma no pátio central (árvore grande)")
			elif player.minigame == null and can_play():
				_show_invite(str(ev.get("fromName", "Alguém")))
		"start":
			_invite_box.visible = false
			if in_game():
				var it := str(ev.get("it", ""))
				AudioManager.play_ui("whistle", -4.0)
				if it == NetworkManager.my_id:
					hud.show_banner("VOCÊ É O PEGADOR!", "Corra e encoste em alguém!")
				else:
					hud.show_banner("Valendo!", "%s é o pegador. Corre!" % names.get(it, "?"))
		"tagged":
			var to := str(ev.get("to", ""))
			var from := str(ev.get("from", ""))
			if to == NetworkManager.my_id:
				hud.show_banner("Te pegaram!", "Agora você é o pegador!")
				Effects.burst(player.global_position + Vector3(0, 1.2, 0), "dust")
				AudioManager.play_ui("bonk", -4.0)
			elif from == NetworkManager.my_id:
				hud.show_banner("Peguei!", "%s é o pegador agora. Foge!" % names.get(to, "?"))
				AudioManager.play_ui("ui_confirm", -2.0)
			elif in_game():
				GameManager.show_toast("%s pegou %s!" % [names.get(from, "?"), names.get(to, "?")])
		"end":
			_finish(ev.get("results", []))
		"cancel":
			_invite_box.visible = false
			if in_game() or st.get("host", "") == NetworkManager.my_id:
				GameManager.show_toast(str(ev.get("text", "Pique-pega cancelado.")))
			_leave_local()


func _show_invite(from_name: String) -> void:
	for c in _invite_box.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_invite_box.add_child(v)
	var t := UITheme.title_label("Pique-pega!", 40, Color.WHITE)
	t.add_theme_constant_override("outline_size", 8)
	t.add_theme_color_override("font_outline_color", Color("8a1030"))
	v.add_child(t)
	var l := Label.new()
	l.text = "%s está chamando todo mundo para brincar no pátio central!" % from_name
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color.WHITE)
	v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	h.add_child(UITheme.make_button("Bora!", func():
		_invite_box.visible = false
		if not can_play():
			GameManager.show_toast("Você está na aula! Termine para brincar.")
			return
		NetworkManager.tag_join(), 200))
	h.add_child(UITheme.make_button("Agora não", func(): _invite_box.visible = false, 200))
	_invite_box.visible = true
	AudioManager.play_ui("whistle", -8.0)
	# o convite some sozinho depois de um tempo
	get_tree().create_timer(18.0).timeout.connect(func():
		if is_instance_valid(_invite_box):
			_invite_box.visible = false)


func _on_state(m: Dictionary) -> void:
	st = m
	var mine := in_game()
	var state := str(m.get("state", ""))
	day.hold_recess = mine and state in ["lobby", "playing"] and not day.synced
	_ctrl_box.visible = mine and state in ["lobby", "playing"]
	_start_btn.visible = state == "lobby" and str(m.get("host", "")) == NetworkManager.my_id and (m.get("players", []) as Array).size() >= 2
	var names: Dictionary = m.get("names", {})
	if not mine:
		_marker.visible = false
		if state == "over" or state == "":
			_leave_local()
		return
	if state == "lobby":
		hud.set_minigame_text("Pique-pega · %d na turma · começa em %d s · vá para a árvore do pátio" % [(m.get("players", []) as Array).size(), int(m.get("lobbyLeft", 0))])
		hud.set_game_point(MEET_POINT + Vector3(0, 1.0, 0))
	elif state == "playing":
		var it := str(m.get("it", ""))
		var is_me := it == NetworkManager.my_id
		var left := int(m.get("left", 0))
		hud.set_minigame_text("PIQUE-PEGA · %s · %d:%02d" % ["VOCÊ é o pegador!" if is_me else "Pegador: " + str(names.get(it, "?")), left / 60, left % 60])
		hud.set_game_point(null)
		_attach_marker(it)
		if is_me and not _was_it:
			player.run_active = true
		_was_it = is_me


func _attach_marker(id: String) -> void:
	var target: Node3D = null
	if id == NetworkManager.my_id:
		target = player
	elif session.remotes.has(id):
		target = session.remotes[id].root
	if target == null:
		_marker.visible = false
		return
	if _marker.get_parent() != target:
		_marker.get_parent().remove_child(_marker)
		target.add_child(_marker)
		_marker.position = Vector3(0, 2.45, 0)
	_marker.visible = true


func _process(delta: float) -> void:
	if _marker and _marker.visible:
		_marker.rotate_y(delta * 3.0)
		_marker.position.y = 2.45 + sin(Time.get_ticks_msec() * 0.006) * 0.1


func _make_marker() -> Node3D:
	var md := MeshData.new()
	md.cur_color = Color("ff2d55")
	md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0, 0)), 0.0, 0.22, 0.42, 12)
	md.cur_color = Color("ffffff")
	md.add_sphere(Transform3D(Basis(), Vector3(0, 0.32, 0)), 0.1, 8, 6)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.render_priority = 5
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(m)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var n := Node3D.new()
	n.add_child(mi)
	return n


func _finish(results: Array) -> void:
	var lines := []
	var my_rank := -1
	for i in results.size():
		var r: Dictionary = results[i]
		# justo para quem chegou depois: conta a porcentagem do tempo que jogou
		lines.append("%dº %s — pegador em %d%% do tempo, %d pegadas" % [i + 1, r.get("name", "?"), int(r.get("pctIt", 0)), int(r.get("tags", 0))])
		if str(r.get("id", "")) == NetworkManager.my_id:
			my_rank = i
	if my_rank >= 0:
		var rw: Array = REWARDS[my_rank] if my_rank < REWARDS.size() else [8, 15]
		GameManager.add_rewards(rw[1], rw[0])
		GameManager.add_stat("vitorias" if my_rank == 0 else "mg_pique")
		Telemetry.track("minigame", {"id": "pique_pega_online", "won": my_rank == 0})
		hud.show_banner("%dº lugar no pique-pega!" % (my_rank + 1), "+%d moedas, +%d XP" % [rw[0], rw[1]])
		if my_rank == 0:
			Effects.burst(player.global_position + Vector3(0, 2, 0), "confetti")
			AudioManager.play_ui("celebrate", -4.0)
		session.chat_panel.add_line("", "Resultado do pique-pega:", true)
		for l in lines.slice(0, 5):
			session.chat_panel.add_line("", l, true)
	_leave_local()


func _leave_local() -> void:
	st = {}
	_marker.visible = false
	_ctrl_box.visible = false
	_was_it = false
	hud.set_minigame_text("")
	hud.set_game_point(null)
	if day:
		day.hold_recess = false
