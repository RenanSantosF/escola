extends Node
## Cena principal: carrega o mundo com tela de carregamento, mostra o menu
## principal sobre a escola (câmera em vitrine) e inicia o jogo.

var world: SchoolWorld
var player: PlayerController
var camera_rig: CameraController
var hud: HUD
var npcs: NPCManager
var nav: NavGraph
var school_day: SchoolDay
var minigames: MinigameManager
var discipline: DisciplineSystem
var events: SchoolEvents
var progression: Progression
var quests: QuestSystem
var profile_menu: ProfileMenu
var _day_started := false
var ui_layer: CanvasLayer
var _loading: Control
var _loading_bar: ProgressBar
var _loading_text: Label
var _menu: Control
var _menu_settings: SettingsPanel
var _menu_box: Control
var _credits: Control


func _ready() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	_build_loading()
	await get_tree().process_frame
	await get_tree().process_frame

	world = SchoolWorld.new()
	world.name = "World"
	add_child(world)
	await world.build(_on_progress)
	await _warm_up()

	player = preload("res://scenes/character/player.tscn").instantiate()
	var sp := world.spawn_point()
	player.position = sp.origin
	player.rotation.y = sp.basis.get_euler().y
	player.world = world
	world.add_child(player)
	world.set_player(player)

	camera_rig = CameraController.new()
	camera_rig.name = "CameraRig"
	camera_rig.target = player
	add_child(camera_rig)
	player.camera_rig = camera_rig
	camera_rig.yaw = player.yaw + PI
	camera_rig.snap_to_target()
	camera_rig.camera.make_current()
	world._apply_quality()

	# Navegação e NPCs (precisa das colisões já registradas na física)
	_on_progress(0.98, "Chamando os alunos...")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var t0 := Time.get_ticks_msec()
	nav = NavGraph.new()
	nav.build(world, world.builder, SchoolBuilder.LOT)
	print("NavGraph: %d pontos (%d conectados) em %d ms" % [nav.points.size(), nav.connected_count(), Time.get_ticks_msec() - t0])
	npcs = NPCManager.new()
	npcs.name = "NPCs"
	world.add_child(npcs)
	npcs.player = player
	npcs.setup(world, nav)

	hud = HUD.new()
	hud.name = "HUD"
	ui_layer.add_child(hud)
	hud.bind(player, camera_rig, world)
	hud.main_menu_cb = _back_to_menu

	school_day = SchoolDay.new()
	school_day.name = "SchoolDay"
	add_child(school_day)
	school_day.setup(world, npcs, player, hud)
	minigames = MinigameManager.new()
	minigames.name = "Minigames"
	add_child(minigames)
	minigames.setup(world, npcs, player, hud, school_day)
	hud.mission_cancel_check = func() -> bool:
		return (quests != null and quests.active_id != "") or (events != null and not events.mission.is_empty())
	hud.mission_cancel = func():
		if quests and quests.active_id != "":
			quests.abandon()
			GameManager.show_toast("Missão cancelada. Você pode pegar outra!")
		elif events and not events.mission.is_empty():
			events._fail_mission("Missão cancelada.")
	var trail := GuideTrail.new()
	trail.name = "GuideTrail"
	world.add_child(trail)
	trail.setup(hud, player, npcs.nav)
	var social := NPCSocial.new()
	social.name = "NPCSocial"
	add_child(social)
	social.setup(npcs, player)
	minigames.game_finished.connect(social.on_minigame_finished)
	discipline = DisciplineSystem.new()
	discipline.name = "Discipline"
	add_child(discipline)
	discipline.setup(npcs, player, hud, school_day, world)
	minigames.discipline = discipline
	school_day.discipline = discipline
	discipline.truant_caught.connect(func():
		# depois da diretoria, volta direto para a carteira
		await get_tree().create_timer(0.3).timeout
		while discipline.in_cutscene:
			await get_tree().process_frame
		if school_day.phase == SchoolDay.Phase.CLASS_1 or school_day.phase == SchoolDay.Phase.CLASS_2:
			player.global_position = npcs.player_desk.global_position
			player.sit_on(npcs.player_desk))
	player.picked_up.connect(discipline.on_player_picked)
	GameManager.shoved.connect(discipline.on_shove)
	events = SchoolEvents.new()
	events.name = "Events"
	add_child(events)
	events.setup(npcs, player, hud, school_day, world, minigames, discipline)
	school_day.events = events
	quests = QuestSystem.new()
	quests.name = "Quests"
	add_child(quests)
	quests.setup(npcs, player, hud, school_day, world)
	school_day.quests = quests
	progression = Progression.new()
	progression.name = "Progression"
	add_child(progression)
	progression.setup(player, world, npcs, school_day, minigames)
	profile_menu = ProfileMenu.new()
	profile_menu.progression = progression
	profile_menu.minigames = minigames
	ui_layer.add_child(profile_menu)
	hud.controls.bag_pressed.connect(profile_menu.open_menu)
	progression.inventory_changed.connect(func():
		if NetworkManager.is_online():
			NetworkManager.send_look())
	ui_layer.move_child(_loading, -1)

	_build_menu()
	_show_menu()
	var tw := create_tween()
	tw.tween_property(_loading, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_loading.queue_free)
	AudioManager.set_ambient("ambient_outdoor", -6.0)

	# Atalho para testes automatizados: --autoplay inicia direto.
	if "--autoplay" in OS.get_cmdline_user_args():
		_start_game()


func _on_progress(f: float, text: String) -> void:
	if _loading_bar:
		_loading_bar.value = f * 100.0
		_loading_text.text = text


# ------------------------------------------------------------- carregamento

## Aquecimento (atrás da tela de carregamento): desenha uma vez todas as
## partes da escola, salas escondidas e efeitos, para o celular compilar os
## shaders AGORA e não travar no meio do jogo na primeira vez que algo aparece.
func _warm_up() -> void:
	_on_progress(0.97, "Preparando tudo para não travar...")
	var hidden: Array = []
	for n in world._chunk_nodes.values():
		var node := n as Node3D
		if node and not node.visible:
			node.visible = true
			hidden.append(node)
	var vp := get_viewport()
	var occl := vp.use_occlusion_culling
	vp.use_occlusion_culling = false
	var cam := Camera3D.new()
	cam.far = 600.0
	cam.fov = 100.0
	add_child(cam)
	cam.make_current()
	var sp: Vector3 = world.spawn_point().origin
	for e in Effects.TYPES:
		Effects.burst(sp + Vector3(0, 1.0, -2.0), e)
	var views := [[Vector3(0, 90, 20), Vector3(0, 0, -10)], [Vector3(0, 60, -100), Vector3(0, 0, -100)],
		[sp + Vector3(0, 2, 4), sp + Vector3(0, 1, 0)]]
	for v in views:
		cam.global_position = v[0]
		cam.look_at(v[1], Vector3.FORWARD if absf((v[0] - v[1]).normalized().y) > 0.95 else Vector3.UP)
		for i in 2:
			await get_tree().process_frame
	for node in hidden:
		(node as Node3D).visible = false
	vp.use_occlusion_culling = occl
	cam.queue_free()
	await get_tree().process_frame


func _build_loading() -> void:
	_loading = Control.new()
	_loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading.theme = UITheme.get_theme()
	ui_layer.add_child(_loading)
	var bg := ColorRect.new()
	bg.color = Color("ffcf3f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	center.add_child(v)
	var title := UITheme.title_label("RECREIO", 96, Color("1f2a44"))
	v.add_child(title)
	var sub := UITheme.title_label("Minha Vida na Escola", 34, Color("c0392b"))
	v.add_child(sub)
	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(520, 30)
	_loading_bar.show_percentage = false
	var fill := UITheme.box(Color("2f6fd0"), 12)
	var bgs := UITheme.box(Color(1, 1, 1, 0.6), 12)
	_loading_bar.add_theme_stylebox_override("fill", fill)
	_loading_bar.add_theme_stylebox_override("background", bgs)
	v.add_child(_loading_bar)
	_loading_text = Label.new()
	_loading_text.text = "Abrindo o portão..."
	_loading_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_loading_text)


# ------------------------------------------------------------- menu

const GAME_TITLE := "Turma Viva"
const GAME_SUB := "Recreio"
var _stats_lbl: Label
var _lobby_status: Label
var _joining := false


func _lobby_button(text: String, col: Color, cb: Callable, h := 64, fs := 24, border := Color(0, 0, 0, 0)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", fs)
	for st in ["normal", "hover", "focus"]:
		var sb := UITheme.box(col if st != "hover" else col.lightened(0.08), 8, border, 2 if border.a > 0 else 0, 0)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("pressed", UITheme.box(col.darkened(0.15), 8, border, 2 if border.a > 0 else 0, 0))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		cb.call())
	return b


## JOGAR: cai direto numa turma (a conta já foi criada antes de chegar aqui).
func _on_play_quick() -> void:
	if not AccountManager.has_account():
		_show_account()
		return
	if _joining:
		return
	_lobby_status.text = "Entrando na escola..."
	_join_online("quick", "")


func _on_friends_pressed() -> void:
	if not AccountManager.has_account():
		_show_account()
		return
	_menu_box.visible = false
	_online_menu.reset()
	_online_menu.visible = true


func _show_account() -> void:
	_menu_box.visible = false
	_account_screen.show_start()
	_account_screen.visible = true


func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.theme = UITheme.get_theme()
	ui_layer.add_child(_menu)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.06, 0.1, 0.24, 0.0))
	g.set_color(1, Color(0.06, 0.1, 0.24, 0.55))
	gt.gradient = g
	gt.fill_from = Vector2(1, 0)
	gt.fill_to = Vector2(0, 0)
	grad.texture = gt
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(grad)

	# ---- lobby: coluna escura à esquerda com o nome, a saudação e o JOGAR
	var side := PanelContainer.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(UITheme.NAVY, 0.9)
	ssb.border_color = Color(UITheme.TEAL, 0.9)
	ssb.border_width_right = 3
	ssb.content_margin_left = 64
	ssb.content_margin_right = 48
	ssb.content_margin_top = 56
	ssb.content_margin_bottom = 40
	side.add_theme_stylebox_override("panel", ssb)
	side.anchor_bottom = 1.0
	side.offset_right = 560
	_menu.add_child(side)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 14)
	side.add_child(_menu_box)
	var title := UITheme.title_label(GAME_TITLE.to_upper(), 78, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu_box.add_child(title)
	var sub := UITheme.title_label("  ".join(GAME_SUB.to_upper().split("")), 26, UITheme.TEAL)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu_box.add_child(sub)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.12)
	line.custom_minimum_size = Vector2(0, 2)
	_menu_box.add_child(line)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_box.add_child(spacer)
	_hello_lbl = UITheme.title_label("", 30, Color.WHITE)
	_hello_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu_box.add_child(_hello_lbl)
	_stats_lbl = Label.new()
	_stats_lbl.add_theme_font_size_override("font_size", 20)
	_stats_lbl.add_theme_color_override("font_color", Color(UITheme.MIST, 0.75))
	_menu_box.add_child(_stats_lbl)
	var play_btn := _lobby_button("JOGAR", UITheme.TEAL, _on_play_quick, 88, 38)
	_menu_box.add_child(play_btn)
	_menu_box.add_child(_lobby_button("Amigos  ·  criar sala ou entrar com código", UITheme.NAVY_2, _on_friends_pressed, 64, 22, UITheme.SKY))
	_lobby_status = Label.new()
	_lobby_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lobby_status.add_theme_font_size_override("font_size", 20)
	_lobby_status.add_theme_color_override("font_color", UITheme.SKY)
	_menu_box.add_child(_lobby_status)
	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_box.add_child(spacer2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_menu_box.add_child(row)
	row.add_child(_lobby_button("Configurações", Color(1, 1, 1, 0.08), _open_menu_settings, 50, 19, Color(1, 1, 1, 0.25)))
	row.add_child(_lobby_button("Créditos", Color(1, 1, 1, 0.08), _open_credits, 50, 19, Color(1, 1, 1, 0.25)))
	if OS.get_name() not in ["Android", "iOS", "Web"]:
		row.add_child(_lobby_button("Sair", Color(1, 1, 1, 0.08), func(): get_tree().quit(), 50, 19, Color(1, 1, 1, 0.25)))
	_menu_box = side  # o painel inteiro aparece/some junto

	var ver := Label.new()
	ver.text = "v%s" % ProjectSettings.get_setting("application/config/version")
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-110, -44)
	_menu.add_child(ver)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(center)
	_menu_settings = SettingsPanel.new()
	_menu_settings.visible = false
	center.add_child(_menu_settings)
	_menu_settings.closed.connect(func():
		_menu_settings.visible = false
		_menu_box.visible = true)

	_online_menu = OnlineMenu.new()
	_online_menu.visible = false
	center.add_child(_online_menu)
	_online_menu.back.connect(func():
		_stop_online()
		_online_menu.visible = false
		_menu_box.visible = true)
	_online_menu.chosen.connect(_join_online)

	_account_screen = AccountScreen.new()
	_account_screen.visible = false
	center.add_child(_account_screen)
	_account_screen.back.connect(func():
		# sem conta não tem lobby: volta para o começo da criação
		if not AccountManager.has_account():
			_account_screen.show_start()
			return
		_account_screen.visible = false
		_menu_box.visible = true)
	_account_screen.done.connect(func(imported):
		_account_screen.visible = false
		_refresh_hello()
		if imported:
			# progresso de outro celular: recarrega o mundo com ele
			get_tree().reload_current_scene()
			return
		# conta criada: agora sim o lobby
		_menu_box.visible = true)

	_credits = PanelContainer.new()
	_credits.visible = false
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	_credits.add_child(cv)
	cv.add_child(UITheme.title_label("Créditos", 40))
	var txt := Label.new()
	txt.text = "Turma Viva: Recreio\nFeito com Godot Engine 4.3 (licença MIT)\n\nModelos, texturas, animações e sons gerados\nproceduralmente para este projeto.\n\nPara todos que já esperaram ansiosos pelo sinal do recreio."
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(txt)
	cv.add_child(UITheme.make_button("Voltar", func():
		_credits.visible = false
		_menu_box.visible = true, 260))
	center.add_child(_credits)


func _open_menu_settings() -> void:
	_menu_box.visible = false
	_menu_settings.visible = true


func _open_credits() -> void:
	_menu_box.visible = false
	_credits.visible = true


func _show_menu() -> void:
	_refresh_hello()
	# jogou em outro celular? baixa o progresso mais novo da nuvem
	if not _synced and AccountManager.has_account() and not "--autoplay" in OS.get_cmdline_user_args():
		_synced = true
		_sync_start()
	GameManager.set_state(GameManager.State.MENU)
	_menu.visible = true
	_menu_box.visible = true
	_joining = false
	if _lobby_status:
		_lobby_status.text = ""
	# primeira vez: cria a conta antes de ver o lobby
	if not AccountManager.has_account() and not _is_test_run():
		_show_account()
	_menu.modulate.a = 1.0
	camera_rig.set_showcase(true)
	AudioManager.play_music("music_menu", -10.0)


func _is_test_run() -> bool:
	return " ".join(OS.get_cmdline_args()).contains("res://tests/")


func _sync_start() -> void:
	if await AccountManager.sync_on_start():
		get_tree().reload_current_scene()


func _on_play_pressed() -> void:
	if Learning.has_age():
		_start_game()
	else:
		_menu_box.visible = false
		var p := AgePicker.new()
		_menu.add_child(p)
		p.confirmed.connect(func(_a):
			p.queue_free()
			_start_game())


func _start_game() -> void:
	AudioManager.play_ui("ui_confirm")
	var tw := create_tween()
	tw.tween_property(_menu, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): _menu.visible = false)
	camera_rig.set_showcase(false)
	GameManager.set_state(GameManager.State.PLAYING)
	if not _day_started:
		_day_started = true
		school_day.start_day()


# =================================================================== online

var online: OnlineSession
var _online_menu: OnlineMenu
var _join_timer: SceneTreeTimer


var _account_screen: AccountScreen
var _hello_lbl: Label
var _synced := false


func _refresh_hello() -> void:
	if _hello_lbl:
		_hello_lbl.text = ("Olá, %s!" % AccountManager.nickname()) if AccountManager.has_account() else ""
	if _stats_lbl:
		_stats_lbl.text = "Nível %d  ·  %d moedas" % [GameManager.level(), GameManager.coins()] if AccountManager.has_account() else ""


## O jogo é só online: precisa de conta (criada uma vez) e de internet.
func _on_online_pressed() -> void:
	_menu_box.visible = false
	if not AccountManager.has_account():
		_account_screen.show_start()
		_account_screen.visible = true
		return
	_online_menu.reset()
	_online_menu.visible = true


func _join_online(mode: String, code: String) -> void:
	_joining = mode == "quick" and not _online_menu.visible
	if online == null:
		online = OnlineSession.new()
		online.name = "Online"
		add_child(online)
		online.npcs = npcs
		online.day = school_day
		online.setup(player, world, ui_layer, hud)
	for c in NetworkManager.welcomed.get_connections():
		if c.callable == _on_online_welcome:
			NetworkManager.welcomed.disconnect(_on_online_welcome)
	NetworkManager.welcomed.connect(_on_online_welcome, CONNECT_ONE_SHOT)
	if not NetworkManager.join_error.is_connected(_on_online_error):
		NetworkManager.join_error.connect(_on_online_error)
	NetworkManager.join(mode, code)
	_join_timer = get_tree().create_timer(12.0)
	_join_timer.timeout.connect(func():
		if (_online_menu.visible or _joining) and not NetworkManager.is_online():
			_joining = false
			_lobby_status.text = "Não consegui conectar. Confira a internet e tente de novo."
			NetworkManager.leave()
			_online_menu.set_status("Não consegui conectar. Confira a internet e tente de novo.", true))


func _on_online_welcome(m: Dictionary) -> void:
	if not (_online_menu.visible or _joining):
		return
	_joining = false
	if _lobby_status:
		_lobby_status.text = ""
	_online_menu.visible = false
	if _online_menu.last_mode == "create":
		GameManager.show_toast("Sala %s criada! Passe o código para os amigos entrarem juntos." % m.get("code", ""))
	_start_game()


func _on_online_error(text: String) -> void:
	if _joining:
		_joining = false
		_lobby_status.text = text
		NetworkManager.leave()
		return
	if _online_menu.visible:
		NetworkManager.leave()
		_online_menu.set_status(text, true)


func _stop_online() -> void:
	NetworkManager.leave()
	school_day.unsync()
	if online:
		online.chat_panel.queue_free()
		online.queue_free()
		online = null


func _back_to_menu() -> void:
	_stop_online()
	_show_menu()
