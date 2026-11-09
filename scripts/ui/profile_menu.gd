class_name ProfileMenu
extends Control
## Menu "Mochila": loja com prévia 3D (experimente antes de comprar),
## guarda-roupa, coleções (álbum de figurinhas e bolinhas), missões
## diárias, conquistas, amigos e ficha (reputação/ocorrências).

signal closed

const TABS := [["brincadeiras", "Brincadeiras"], ["loja", "Loja"], ["visual", "Guarda-roupa"], ["colecoes", "Coleções"], ["missoes", "Missões"],
	["conquistas", "Conquistas"], ["amigos", "Amigos"], ["ficha", "Ficha"]]

var progression: Progression
var minigames: Node
var _tab := "loja"
var _cat := "camiseta"
var _selected := ""
var _content: VBoxContainer
var _side: VBoxContainer
var _preview_vp: SubViewport
var _preview_char: CharacterVisual
var _coins: Label
var _info: Label
var _action: Button
var _tab_buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.09, 0.18, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 18)
	add_child(margin)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	# abas
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	for t in TABS:
		var b := Button.new()
		b.text = t[1]
		b.custom_minimum_size = Vector2(190, 56)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 22)
		var tid: String = t[0]
		b.pressed.connect(func():
			AudioManager.play_ui("ui_click")
			_tab = tid
			_selected = ""
			_refresh())
		tabs.add_child(b)
		_tab_buttons[tid] = b
	var close := UITheme.make_button("Fechar", close_menu, 190)
	close.add_theme_stylebox_override("normal", UITheme.box(Color("e05a4a"), 18, Color("a33a2c"), 0, 6))
	tabs.add_child(close)
	# conteúdo
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)
	# lateral: prévia + moedas + ação
	_side = VBoxContainer.new()
	_side.custom_minimum_size = Vector2(300, 0)
	_side.add_theme_constant_override("separation", 10)
	root.add_child(_side)
	_coins = UITheme.title_label("", 26, Color("ffe08a"))
	_side.add_child(_coins)
	var vpc := SubViewportContainer.new()
	vpc.custom_minimum_size = Vector2(300, 380)
	vpc.stretch = true
	_side.add_child(vpc)
	_preview_vp = SubViewport.new()
	_preview_vp.own_world_3d = true
	_preview_vp.transparent_bg = true
	_preview_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	vpc.add_child(_preview_vp)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	_preview_vp.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.environment.ambient_light_energy = 0.7
	_preview_vp.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, 2.9)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	cam.fov = 40
	_preview_vp.add_child(cam)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", Color.WHITE)
	_info.add_theme_font_size_override("font_size", 20)
	_info.custom_minimum_size = Vector2(300, 60)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_side.add_child(_info)
	_action = UITheme.make_button("", _on_action, 300)
	_side.add_child(_action)


func open_menu() -> void:
	visible = true
	get_parent().move_child(self, -1)
	GameManager.overlay_open = true
	GameManager.set_state(GameManager.State.PAUSED)
	if _preview_char == null:
		_preview_char = CharacterVisual.new()
		_preview_char.appearance = Progression.appearance_with()
		_preview_vp.add_child(_preview_char)
	_selected = ""
	_refresh()


func close_menu() -> void:
	visible = false
	GameManager.set_state(GameManager.State.PLAYING)
	GameManager.overlay_open = false
	closed.emit()


func _process(delta: float) -> void:
	if visible and _preview_char:
		_preview_char.rotation.y += delta * 0.6


func _refresh() -> void:
	for t in _tab_buttons.keys():
		var on: bool = t == _tab
		_tab_buttons[t].add_theme_stylebox_override("normal", UITheme.box(UITheme.ORANGE if on else UITheme.YELLOW, 18, UITheme.DARK.lerp(UITheme.YELLOW, 0.5), 0, 6))
	for c in _content.get_children():
		c.queue_free()
	_coins.text = "Moedas: %d   ·   Nível %d" % [GameManager.coins(), GameManager.level()]
	var show_preview := _tab in ["loja", "visual"]
	if _tab == "brincadeiras" and not GameManager.overlay_open:
		pass
	_side.get_child(1).visible = show_preview
	_action.visible = false
	_info.text = ""
	match _tab:
		"loja", "visual":
			_build_items(_tab == "loja")
		"brincadeiras":
			_build_games()
		"colecoes":
			_build_collections()
		"missoes":
			_build_missions()
		"conquistas":
			_build_achievements()
		"amigos":
			_build_friends()
		"ficha":
			_build_record()
	_update_preview()


func _title(t: String) -> void:
	var l := UITheme.title_label(t, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_content.add_child(l)


func _build_items(shop: bool) -> void:
	_title("Loja do Recreio" if shop else "Seu guarda-roupa")
	var cats := HFlowContainer.new()
	cats.add_theme_constant_override("h_separation", 6)
	cats.add_theme_constant_override("v_separation", 6)
	_content.add_child(cats)
	for c in ShopCatalog.CATEGORIES:
		if not shop and c[0] in ["gude", "figurinha", "decoracao"]:
			continue
		var b := Button.new()
		b.text = c[1]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 18)
		b.custom_minimum_size = Vector2(0, 44)
		var cid: String = c[0]
		if cid == _cat:
			b.add_theme_stylebox_override("normal", UITheme.box(UITheme.ORANGE, 14))
		b.pressed.connect(func():
			_cat = cid
			_selected = ""
			_refresh())
		cats.add_child(b)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_content.add_child(grid)
	for item in ShopCatalog.by_cat(_cat):
		var owned := Progression.owns(item.id)
		if not shop and not owned:
			continue
		grid.add_child(_card(item, owned))


func _card(item: Dictionary, owned: bool) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(200, 92)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	var locked := GameManager.level() < int(item.lvl)
	var status := ""
	if progression.is_equipped(item.id):
		status = "Equipado"
	elif owned and not item.get("consumable", false):
		status = "Seu"
	elif locked:
		status = "Nível %d" % item.lvl
	else:
		status = "%d moedas" % item.price if item.price > 0 else "Grátis"
	b.text = "%s\n%s" % [item.name, status]
	b.add_theme_font_size_override("font_size", 17)
	var col := ShopCatalog.swatch(item)
	var sel: bool = item.id == _selected
	var sb := UITheme.box(Color("fff8e7") if not locked else Color("d9d4c7"), 14, UITheme.ORANGE if sel else col, 6 if sel else 4, 0)
	sb.border_width_left = 14
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		_selected = item.id
		_refresh())
	return b


func _update_preview() -> void:
	if _preview_char == null:
		return
	var extra := []
	if _selected != "" and ShopCatalog.get_item(_selected).has("look"):
		extra.append(_selected)
	_preview_char.set_appearance(Progression.appearance_with(extra))
	if _selected == "" or not (_tab in ["loja", "visual"]):
		return
	var item := ShopCatalog.get_item(_selected)
	var owned := Progression.owns(_selected)
	_action.visible = true
	_action.disabled = false
	if owned and not item.get("consumable", false):
		_action.text = "Equipado" if progression.is_equipped(_selected) else "Equipar"
		_action.disabled = progression.is_equipped(_selected) or not (item.has("look") or item.has("vehicle"))
		_info.text = item.name + ("\n(fica na sua carteira da sala)" if item.cat == "decoracao" else "")
	else:
		_action.text = "Comprar (%d)" % item.price
		_action.disabled = GameManager.level() < int(item.lvl) or GameManager.coins() < int(item.price)
		_info.text = "%s\nPreço: %d moedas%s" % [item.name, item.price, "" if GameManager.level() >= int(item.lvl) else "\nLibera no nível %d" % item.lvl]


func _on_action() -> void:
	if _selected == "":
		return
	var item := ShopCatalog.get_item(_selected)
	if Progression.owns(_selected) and not item.get("consumable", false):
		progression.equip(_selected)
	else:
		var err := progression.buy(_selected)
		if err != "":
			GameManager.show_toast(err)
		elif item.has("look"):
			progression.equip(_selected)
	_refresh()


func _row(text: String, sub: String, col := Color("fff8e7")) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(col, 14))
	var v := VBoxContainer.new()
	var a := Label.new()
	a.text = text
	a.add_theme_font_override("font", UITheme.bold_font())
	a.add_theme_font_size_override("font_size", 22)
	var b := Label.new()
	b.text = sub
	b.add_theme_font_size_override("font_size", 18)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(a)
	v.add_child(b)
	p.add_child(v)
	_content.add_child(p)


func _build_games() -> void:
	_title("Brincadeiras do recreio")
	var stats: Dictionary = SaveManager.section("stats")
	for gid in MinigameManager.GAMES.keys():
		var g: Dictionary = MinigameManager.GAMES[gid]
		var st: Dictionary = stats.get("mg_" + gid, {}) if stats.get("mg_" + gid) is Dictionary else {}
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UITheme.box(Color(g.color).lerp(Color.WHITE, 0.7), 14))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var a := Label.new()
		a.text = g.title
		a.add_theme_font_override("font", UITheme.bold_font())
		a.add_theme_font_size_override("font_size", 22)
		var b := Label.new()
		b.text = "%s\nJogou %d · venceu %d · recorde %d" % [g.desc, int(st.get("played", 0)), int(st.get("won", 0)), int(st.get("best", 0))]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 17)
		v.add_child(a)
		v.add_child(b)
		h.add_child(v)
		var go := UITheme.make_button("Mostrar no mapa", func():
			if minigames:
				minigames.guide_to(gid)
			close_menu(), 220)
		go.custom_minimum_size = Vector2(220, 56)
		go.add_theme_font_size_override("font_size", 19)
		h.add_child(go)
		p.add_child(h)
		_content.add_child(p)


func _build_collections() -> void:
	_title("Álbum: Craques do Recreio (%d/%d)" % [Stickers.count_unique(), Stickers.ALBUM.size()])
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	var owned := Stickers.owned()
	for e in Stickers.ALBUM:
		var has := owned.has(e.id)
		var l := Label.new()
		l.custom_minimum_size = Vector2(170, 70)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.text = (e.name + ("\n×%d" % owned[e.id] if int(owned[e.id]) > 1 else "")) if has else "?"
		l.add_theme_font_size_override("font_size", 16)
		var bgc := (Color("ffe08a") if e.rare else Color("fff8e7")) if has else Color(1, 1, 1, 0.25)
		l.add_theme_stylebox_override("normal", UITheme.box(bgc, 10))
		grid.add_child(l)
	_title("Bolinhas de gude")
	var gude: Dictionary = SaveManager.section("collections").get("gude", {})
	var types: Array = preload("res://scripts/minigames/marbles.gd").TYPES
	for t in types:
		_row("%s: %d" % [t.name, int(gude.get(t.id, 0))], "", Color(t.color).lerp(Color.WHITE, 0.6))


func _build_missions() -> void:
	_title("Missões de hoje")
	for e in progression.daily_list():
		var p := progression.progress_of(e)
		var done: bool = e.done
		_row(("✔ " if done else "") + (str(e.desc) % e.target), "%d/%d   ·   recompensa: %d moedas" % [p, e.target, e.coins], Color("c8f2c8") if done else Color("fff8e7"))
	if progression.daily_list().is_empty():
		_row("Sem missões ainda", "As missões aparecem no começo de cada dia.")


func _build_achievements() -> void:
	var got: Dictionary = SaveManager.section("achievements")
	_title("Conquistas (%d/%d)" % [got.size(), Progression.ACHIEVEMENTS.size()])
	for id in Progression.ACHIEVEMENTS.keys():
		var a: Array = Progression.ACHIEVEMENTS[id]
		var has := got.has(id)
		_row(("★ " if has else "☆ ") + a[0], a[1], Color("ffe08a") if has else Color("e8e4da"))


func _build_friends() -> void:
	_title("Amigos")
	for s in NPCRoster.STUDENTS:
		var lv := Friendship.level(s.id)
		var pts := Friendship.points(s.id)
		var nxt: int = Friendship.LEVELS[mini(lv + 1, Friendship.LEVELS.size() - 1)]
		_row("%s — %s" % [s.name, Friendship.LEVEL_NAMES[lv]], "Gosta de: %s   ·   %d/%d pontos" % [_likes(s.personality), pts, nxt])


func _likes(p: String) -> String:
	return {"futebol": "futebol", "competitivo": "competições e corridas", "engracado": "piadas", "timido": "biblioteca e lugares calmos",
		"colecionador": "figurinhas e gude", "comilao": "a cantina", "agitado": "pega-pega e queimada", "estudioso": "estudar e aviãozinhos"}.get(p, "brincar")


func _build_record() -> void:
	var d := DisciplineSystem.data()
	_title("Sua ficha")
	var prog: Dictionary = SaveManager.section("progress")
	var acts: Dictionary = prog.get("activities", {})
	_row("Dias de aula: %d" % int(prog.get("days_completed", 0)), "Tarefas certas: %d de %d" % [int(acts.get("tarefas_certas", 0)), int(acts.get("tarefas_feitas", 0))])
	var rep := DisciplineSystem.reputation()
	var rep_txt := "Exemplar" if rep >= 80 else ("Boa" if rep >= 60 else ("Regular" if rep >= 40 else "Precisa melhorar"))
	_row("Reputação: %d/100 (%s)" % [rep, rep_txt], "Dias seguidos sem bronca: %d" % int(d.get("clean_days", 0)))
	_row("Ocorrências: %d (ativas: %d)" % [int(d.get("occurrences", 0)), int(d.get("active", 0))], "Bom comportamento perdoa ocorrências com o tempo.")
	var stats: Dictionary = SaveManager.section("stats")
	_row("Estatísticas", "Chutes: %d · Gols: %d · Arremessos: %d · Lanches: %d · Missões: %d · Tempo de jogo: %d min" % [
		int(stats.get("kicks", 0)), int(stats.get("gols", 0)), int(stats.get("throws", 0)), int(stats.get("lanches", 0)),
		int(stats.get("missoes", 0)), int(float(stats.get("play_time", 0.0)) / 60.0)])
