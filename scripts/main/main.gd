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
	profile_menu.closed.connect(_refresh_hello)  # menu: o boneco do palco troca de roupa junto
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
var _lobby_stage: CharacterStage
var _tap_hint: Control
var _lvl_badge: Label
var _xp_bar: ProgressBar
var _coins_lbl: Label


func _soft_box(col: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 20
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	return sb


func _round_btn(icon: String, text: String, col: Color, cb: Callable, d := 96) -> LobbyButton:
	var b := LobbyButton.new()
	b.round_icon = true
	b.icon_name = icon
	b.text = text
	b.color = col
	b.font_size = 22
	b.custom_minimum_size = Vector2(d, d + (40 if text != "" else 6))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	return b


## Balãozinho de fala (dica do lobby).
func _bubble(text: String) -> Control:
	var p := PanelContainer.new()
	var sb := _soft_box(Color.WHITE, 22)
	p.add_theme_stylebox_override("panel", sb)
	var l := UITheme.title_label(text, 22, Color("ff4d6d"))
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := p.create_tween().set_loops()
	tw.tween_property(p, "position:y", -8.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE)
	tw.tween_property(p, "position:y", 8.0, 0.6).as_relative().set_trans(Tween.TRANS_SINE)
	return p


## Lobby: abre a mochila numa aba (Visual, Conquistas...) sem começar o jogo.
func _open_lobby_tab(tab: String) -> void:
	if profile_menu == null:
		return
	profile_menu.from_lobby = true
	profile_menu.open_tab(tab)


func _open_lobby_look() -> void:
	_open_lobby_tab("visual")


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
	# ---- lobby: céu animado, logo, o personagem no palco e botões grandes
	_menu.add_child(LobbyBackground.new())
	var lobby := Control.new()
	lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lobby.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(lobby)
	_menu_box = lobby  # o lobby inteiro aparece/some junto
	# logo
	var logo := LobbyLogo.new()
	logo.title = GAME_TITLE.to_upper()
	logo.ribbon = GAME_SUB.to_upper()
	logo.anchor_left = 0.5
	logo.anchor_right = 0.5
	logo.offset_left = -330
	logo.offset_right = 330
	logo.offset_top = 6
	logo.offset_bottom = 170
	logo.font_size = 80
	lobby.add_child(logo)
	# personagem no palco (arrasta para girar, toque para uma graça)
	_lobby_stage = CharacterStage.new()
	_lobby_stage.anchor_left = 0.5
	_lobby_stage.anchor_right = 0.5
	_lobby_stage.anchor_top = 0.5
	_lobby_stage.anchor_bottom = 0.5
	_lobby_stage.offset_left = -210
	_lobby_stage.offset_right = 210
	_lobby_stage.offset_top = -150
	_lobby_stage.offset_bottom = 225
	lobby.add_child(_lobby_stage)
	_lobby_stage.tapped.connect(func():
		if is_instance_valid(_tap_hint):
			var tw := _tap_hint.create_tween()
			tw.tween_property(_tap_hint, "modulate:a", 0.0, 0.3)
			tw.tween_callback(_tap_hint.queue_free))
	_tap_hint = _bubble("Toque em mim!")
	_tap_hint.anchor_left = 0.5
	_tap_hint.anchor_top = 0.5
	_tap_hint.offset_left = 120
	_tap_hint.offset_top = -120
	lobby.add_child(_tap_hint)
	# cartão do jogador (canto de cima à esquerda)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _soft_box(Color(1, 1, 1, 0.92), 26))
	card.position = Vector2(22, 18)
	lobby.add_child(card)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 12)
	card.add_child(ch)
	_lvl_badge = Label.new()
	_lvl_badge.custom_minimum_size = Vector2(64, 64)
	_lvl_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lvl_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lvl_badge.add_theme_font_override("font", UITheme.bold_font())
	_lvl_badge.add_theme_font_size_override("font_size", 30)
	_lvl_badge.add_theme_color_override("font_color", Color.WHITE)
	var lb := StyleBoxFlat.new()
	lb.bg_color = Color("ff7a1a")
	lb.set_corner_radius_all(32)
	lb.border_color = Color("ffd23f")
	lb.set_border_width_all(4)
	_lvl_badge.add_theme_stylebox_override("normal", lb)
	ch.add_child(_lvl_badge)
	var cv2 := VBoxContainer.new()
	cv2.add_theme_constant_override("separation", 2)
	ch.add_child(cv2)
	_hello_lbl = UITheme.title_label("", 26, UITheme.DARK)
	_hello_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cv2.add_child(_hello_lbl)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(220, 16)
	_xp_bar.show_percentage = false
	_xp_bar.add_theme_stylebox_override("background", UITheme.box(Color("dfe6f3"), 8))
	_xp_bar.add_theme_stylebox_override("fill", UITheme.box(Color("6be36b"), 8))
	cv2.add_child(_xp_bar)
	_stats_lbl = Label.new()
	_stats_lbl.add_theme_font_size_override("font_size", 16)
	_stats_lbl.add_theme_color_override("font_color", Color(UITheme.DARK, 0.7))
	cv2.add_child(_stats_lbl)
	# moedas + configurações (canto de cima à direita)
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 14)
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_left = -330
	tr.offset_right = -22
	tr.offset_top = 18
	tr.alignment = BoxContainer.ALIGNMENT_END
	lobby.add_child(tr)
	var coins := PanelContainer.new()
	coins.add_theme_stylebox_override("panel", _soft_box(Color(1, 1, 1, 0.92), 30))
	coins.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	coins.add_child(crow)
	var ci := CoinIcon.new()
	ci.custom_minimum_size = Vector2(36, 36)
	crow.add_child(ci)
	_coins_lbl = UITheme.title_label("0", 28, Color("b7791f"))
	crow.add_child(_coins_lbl)
	tr.add_child(coins)
	tr.add_child(_round_btn("gear", "", Color("5b6b8c"), _open_menu_settings, 76))
	# lado esquerdo: Visual e Amigos; lado direito: Conquistas e Créditos
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 40)
	left.anchor_top = 0.5
	left.anchor_bottom = 0.5
	left.offset_left = 70
	left.offset_right = 182
	left.offset_top = -150
	lobby.add_child(left)
	left.add_child(_round_btn("shirt", "Visual", Color("ff4d9a"), _open_lobby_look, 112))
	left.add_child(_round_btn("friends", "Amigos", Color("3e8bff"), _on_friends_pressed, 112))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 40)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 0.5
	right.anchor_bottom = 0.5
	right.offset_left = -182
	right.offset_right = -70
	right.offset_top = -150
	lobby.add_child(right)
	right.add_child(_round_btn("star", "Conquistas", Color("ffb020"), func(): _open_lobby_tab("conquistas"), 112))
	right.add_child(_round_btn("bag", "Mochila", Color("8b5cf6"), func(): _open_lobby_tab("colecoes"), 112))
	# JOGAR (embaixo, no meio): o único botão grande da tela
	var play := LobbyButton.new()
	play.text = "JOGAR"
	play.sub = "entrar na escola"
	play.icon_name = "play"
	play.color = Color("22c55e")
	play.primary = true
	play.font_size = 46
	play.anchor_left = 0.5
	play.anchor_right = 0.5
	play.anchor_top = 1.0
	play.anchor_bottom = 1.0
	play.offset_left = -200
	play.offset_right = 200
	play.offset_top = -132
	play.offset_bottom = -22
	play.pressed.connect(_on_play_quick)
	lobby.add_child(play)
	_lobby_status = Label.new()
	_lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_status.add_theme_font_override("font", UITheme.bold_font())
	_lobby_status.add_theme_font_size_override("font_size", 24)
	_lobby_status.add_theme_color_override("font_color", Color.WHITE)
	_lobby_status.add_theme_color_override("font_outline_color", Color(0.06, 0.1, 0.3))
	_lobby_status.add_theme_constant_override("outline_size", 8)
	_lobby_status.anchor_left = 0.5
	_lobby_status.anchor_right = 0.5
	_lobby_status.anchor_top = 1.0
	_lobby_status.anchor_bottom = 1.0
	_lobby_status.offset_left = -300
	_lobby_status.offset_right = 300
	_lobby_status.offset_top = -172
	_lobby_status.offset_bottom = -136
	lobby.add_child(_lobby_status)
	var credits_btn := Button.new()
	credits_btn.text = "Créditos"
	credits_btn.flat = true
	credits_btn.focus_mode = Control.FOCUS_NONE
	credits_btn.add_theme_font_size_override("font_size", 18)
	credits_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	credits_btn.anchor_left = 0.0
	credits_btn.anchor_top = 1.0
	credits_btn.anchor_bottom = 1.0
	credits_btn.offset_left = 22
	credits_btn.offset_top = -52
	credits_btn.offset_bottom = -14
	credits_btn.pressed.connect(_open_credits)
	lobby.add_child(credits_btn)

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
	get_viewport().disable_3d = true
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
	get_viewport().disable_3d = false
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
	var has := AccountManager.has_account()
	if _hello_lbl:
		_hello_lbl.text = ("Olá, %s!" % AccountManager.nickname()) if has else "Olá!"
	var lv := GameManager.level()
	var xp := int(SaveManager.section("player").get("xp", 0))
	var need := maxi(GameManager.xp_for_level(lv), 1)
	if _stats_lbl:
		_stats_lbl.text = "Nível %d  ·  faltam %d XP para o %d" % [lv, maxi(need - xp, 0), lv + 1]
	if _lvl_badge:
		_lvl_badge.text = str(lv)
	if _xp_bar:
		_xp_bar.max_value = need
		_xp_bar.value = xp
	if _coins_lbl:
		_coins_lbl.text = str(GameManager.coins())
	# o boneco do palco com o visual de agora
	if _lobby_stage:
		_lobby_stage.set_appearance(Progression.appearance_with())


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
	var created := _online_menu.last_mode == "create"
	_start_game()
	if created:
		# o código bem grande: é só falar para o amigo ("Entrar com código" no menu dele)
		var code := str(m.get("code", ""))
		get_tree().create_timer(1.2).timeout.connect(func():
			hud.show_banner("Sua sala: %s" % "  ".join(code.split("")), "Fale esse código para o amigo tocar em Amigos > Entrar com código", 6.0)
			AudioManager.play_ui("reward", -4.0))


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
