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
	discipline = DisciplineSystem.new()
	discipline.name = "Discipline"
	add_child(discipline)
	discipline.setup(npcs, player, hud, school_day, world)
	minigames.discipline = discipline
	player.picked_up.connect(discipline.on_player_picked)
	events = SchoolEvents.new()
	events.name = "Events"
	add_child(events)
	events.setup(npcs, player, hud, school_day, world, minigames, discipline)
	school_day.events = events
	progression = Progression.new()
	progression.name = "Progression"
	add_child(progression)
	progression.setup(player, world, npcs, school_day, minigames)
	profile_menu = ProfileMenu.new()
	profile_menu.progression = progression
	ui_layer.add_child(profile_menu)
	hud.controls.bag_pressed.connect(profile_menu.open_menu)
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

func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.theme = UITheme.get_theme()
	ui_layer.add_child(_menu)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.1, 0.25, 0.0))
	g.set_color(1, Color(0.05, 0.1, 0.25, 0.65))
	gt.gradient = g
	gt.fill_from = Vector2(1, 0)
	gt.fill_to = Vector2(0, 0)
	grad.texture = gt
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(grad)

	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 16)
	_menu_box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_menu_box.position = Vector2(80, -250)
	_menu.add_child(_menu_box)
	var title := UITheme.title_label("RECREIO", 110, Color("ffcf3f"))
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_outline_color", Color("1f2a44"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu_box.add_child(title)
	var sub := UITheme.title_label("Minha Vida na Escola", 36, Color.WHITE)
	sub.add_theme_constant_override("outline_size", 10)
	sub.add_theme_color_override("font_outline_color", Color("1f2a44"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu_box.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	_menu_box.add_child(spacer)
	_menu_box.add_child(UITheme.make_button("Jogar", _start_game, 360))
	_menu_box.add_child(UITheme.make_button("Configurações", _open_menu_settings, 360))
	_menu_box.add_child(UITheme.make_button("Créditos", _open_credits, 360))
	if OS.get_name() not in ["Android", "iOS", "Web"]:
		_menu_box.add_child(UITheme.make_button("Sair", func(): get_tree().quit(), 360))

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

	_credits = PanelContainer.new()
	_credits.visible = false
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	_credits.add_child(cv)
	cv.add_child(UITheme.title_label("Créditos", 40))
	var txt := Label.new()
	txt.text = "Recreio — Minha Vida na Escola\nFeito com Godot Engine 4.3 (licença MIT)\n\nModelos, texturas, animações e sons gerados\nproceduralmente para este projeto.\n\nPara todos que já esperaram ansiosos pelo sinal do recreio."
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
	GameManager.set_state(GameManager.State.MENU)
	_menu.visible = true
	_menu_box.visible = true
	_menu.modulate.a = 1.0
	camera_rig.set_showcase(true)
	AudioManager.play_music("music_menu", -10.0)


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


func _back_to_menu() -> void:
	_show_menu()
