class_name ProfileMenu
extends Control
## Menu "Mochila": loja com prévia 3D (experimente antes de comprar),
## guarda-roupa, coleções (álbum de figurinhas e bolinhas), missões
## diárias, conquistas, amigos e ficha (reputação/ocorrências).

signal closed

const TABS := [["brincadeiras", "Brincadeiras"], ["passe", "Passe do Recreio"], ["loja", "Loja"], ["visual", "Guarda-roupa"], ["colecoes", "Coleções"], ["missoes", "Missões"],
	["conquistas", "Conquistas"], ["amigos", "Amigos"], ["ficha", "Ficha"]]

var progression: Progression
var minigames: Node
var _tab := "loja"
var _cat := "destaques"
var _selected := ""
var _content: VBoxContainer
var _side: VBoxContainer
var _stage: CharacterStage
var _last_look := ""
var _coins: Label
var _info: Label
var _action: Button
var _ad_action: Button  ## "Ganhar com vídeo (1/3)" (só aparece com vídeo pronto)
var _tab_buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var bg := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color("1b2a6b", 0.96))
	g.set_color(1, Color("5a2d91", 0.96))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 1)
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
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
		UITheme.dark_text(b)
		b.text = t[1]
		b.custom_minimum_size = Vector2(196, 58)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 25)
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
	scroll.scroll_deadzone = 12  # arrastar o dedo rola; toque curto seleciona
	panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)
	# lateral: prévia + moedas + ação
	_side = VBoxContainer.new()
	_side.custom_minimum_size = Vector2(280, 0)
	_side.add_theme_constant_override("separation", 10)
	root.add_child(_side)
	_coins = UITheme.title_label("", 23, Color("ffe08a"))
	_side.add_child(_coins)
	# palco do personagem: arraste para girar, pinça para aproximar, toque = graça
	_stage = CharacterStage.new()
	_stage.custom_minimum_size = Vector2(300, 400)
	_stage.auto_emotes = false
	_stage.podium_color = Color("b46bff")
	_side.add_child(_stage)
	var hint := Label.new()
	hint.text = "Arraste para girar  ·  pinça para aproximar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_side.add_child(hint)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", Color.WHITE)
	_info.add_theme_font_size_override("font_size", 22)
	_info.custom_minimum_size = Vector2(300, 60)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_side.add_child(_info)
	_action = UITheme.make_button("", _on_action, 300)
	_side.add_child(_action)
	_ad_action = UITheme.make_button("", _on_ad_action, 300)
	_ad_action.add_theme_stylebox_override("normal", UITheme.box(Color("9be37a"), 18, Color("5aa83a"), 0, 6))
	UITheme.dark_text(_ad_action)
	_ad_action.visible = false
	_side.add_child(_ad_action)
	# compras com dinheiro de verdade: atualiza a tela e avisa
	Billing.delivered.connect(func(_t):
		if visible:
			_refresh())
	Billing.purchase_failed.connect(func(t): GameManager.show_toast(t))
	Billing.premium_changed.connect(func(_on):
		if visible:
			_refresh())


var from_lobby := false  ## aberto pelo menu (antes de entrar na escola)


## Abre direto numa aba (o menu usa para Visual, Conquistas e Mochila).
func open_tab(tab: String) -> void:
	open_menu()
	_tab = tab
	_selected = ""
	_refresh()


func open_menu() -> void:
	visible = true
	get_parent().move_child(self, -1)
	GameManager.overlay_open = true
	# a mochila cobre a tela toda: não precisa desenhar a escola por trás
	get_viewport().disable_3d = true
	if not from_lobby:
		GameManager.set_state(GameManager.State.PAUSED)
	_stage.set_appearance(Progression.appearance_with())
	_selected = ""
	_refresh()


func close_menu() -> void:
	visible = false
	if not from_lobby:
		get_viewport().disable_3d = false
		GameManager.set_state(GameManager.State.PLAYING)
	from_lobby = false
	GameManager.overlay_open = false
	closed.emit()


func _process(delta: float) -> void:
	pass


func _refresh() -> void:
	for t in _tab_buttons.keys():
		var on: bool = t == _tab
		var base := UITheme.YELLOW if t != "passe" else Color("c9a8ff")
		_tab_buttons[t].add_theme_stylebox_override("normal", UITheme.box(UITheme.ORANGE if on else base, 18, UITheme.DARK.lerp(UITheme.YELLOW, 0.5), 0, 6))
	var pend := RecessPass.pending()
	_tab_buttons["passe"].text = "Passe (%d!)" % pend if pend > 0 else "Passe do Recreio"
	for c in _content.get_children():
		c.queue_free()
	_coins.text = "Nível %d" % GameManager.level()
	var show_preview := _tab in ["loja", "visual"]
	if _tab == "brincadeiras" and not GameManager.overlay_open:
		pass
	_side.get_child(1).visible = show_preview
	_side.get_child(2).visible = show_preview
	_action.visible = false
	_info.text = ""
	match _tab:
		"loja", "visual":
			_build_items(_tab == "loja")
		"passe":
			_build_pass()
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
	UITheme.scroll_friendly(_content)


func _title(t: String) -> void:
	var l := UITheme.title_label(t, 38)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_content.add_child(l)


func _build_items(shop: bool) -> void:
	if shop:
		_build_shop_header()
	else:
		_title("Seu guarda-roupa")
		# menino ou menina
		var gh := HBoxContainer.new()
		gh.add_theme_constant_override("separation", 8)
		_content.add_child(gh)
		var cur_girl: bool = GameManager.player.visual.appearance.girl if GameManager.player else false
		for opt in [["Menino", false], ["Menina", true]]:
			var g_on: bool = opt[1] == cur_girl
			var gb := Button.new()
			UITheme.dark_text(gb)
			gb.text = opt[0]
			gb.focus_mode = Control.FOCUS_NONE
			gb.custom_minimum_size = Vector2(150, 50)
			gb.add_theme_font_size_override("font_size", 21)
			for st in ["normal", "hover", "pressed", "focus"]:
				gb.add_theme_stylebox_override(st, UITheme.box(UITheme.TEAL if g_on else Color("e3e8f2"), 8, Color(0, 0, 0, 0), 0, 3))
			gb.add_theme_color_override("font_color", Color.WHITE if g_on else UITheme.DARK)
			var girl: bool = opt[1]
			gb.pressed.connect(func():
				var a: CharacterAppearance = GameManager.player.visual.appearance
				a.set_girl(girl)
				GameManager.player.set_appearance(a)
				if NetworkManager.is_online():
					NetworkManager.send_look()
				_refresh())
			gh.add_child(gb)
	# categorias (chips grandes)
	# categorias numa fileira só, rolando para o lado (sobra espaço para os itens)
	var cat_scroll := ScrollContainer.new()
	cat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cat_scroll.custom_minimum_size = Vector2(0, 62)
	cat_scroll.scroll_deadzone = 12
	_content.add_child(cat_scroll)
	var cats := HBoxContainer.new()
	cats.add_theme_constant_override("separation", 8)
	cat_scroll.add_child(cats)
	if not shop and _cat in ["destaques", "diamantes"]:
		_cat = "skin"
	var cat_list: Array = ShopCatalog.CATEGORIES.duplicate()
	if shop:
		cat_list = [["destaques", "Destaques"], ["diamantes", "Diamantes e moedas"]] + cat_list
	for c in cat_list:
		if not shop and c[0] in ["gude", "figurinha", "decoracao", "pacote"]:
			continue
		var b := Button.new()
		UITheme.dark_text(b)
		b.text = c[1]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 21)
		b.custom_minimum_size = Vector2(0, 50)
		var cid: String = c[0]
		var on := cid == _cat
		var col := UITheme.TEAL if on else Color("eef3fa")
		if cid == "skin" and not on:
			col = Color("e9ddff")
		elif cid == "destaques" and not on:
			col = Color("ffe08a")
		elif cid == "diamantes" and not on:
			col = Color("bfe9ff")
		for st in ["normal", "hover", "pressed", "focus"]:
			var sb := UITheme.box(col, 26, UITheme.DARK if on else Color(0, 0, 0, 0), 3 if on else 0, 4)
			sb.content_margin_left = 14
			sb.content_margin_right = 14
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_color_override("font_color", Color.WHITE if on else UITheme.DARK)
		b.add_theme_color_override("font_hover_color", Color.WHITE if on else UITheme.DARK)
		b.pressed.connect(func():
			AudioManager.play_ui("ui_click")
			_cat = cid
			_selected = ""
			_refresh())
		cats.add_child(b)
	if shop and _cat == "destaques":
		_build_featured()
		return
	if shop and _cat == "diamantes":
		_build_money_store()
		return
	var grid := GridContainer.new()
	var avail := get_viewport_rect().size.x - 196.0 - 300.0 - 80.0
	grid.columns = clampi(int(avail / 214.0), 2, 5)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_content.add_child(grid)
	var any := false
	for item in ShopCatalog.by_cat(_cat):
		var owned := Progression.owns(item.id)
		if not shop and not owned:
			continue
		grid.add_child(_card(item, owned, shop))
		any = true
	if not any:
		_row("Nada aqui ainda", "Compre itens na Loja para usar no guarda-roupa.")


## Faixa do topo da loja: moedas + ofertas do dia + oferta relâmpago.
func _build_shop_header() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_content.add_child(head)
	var t := UITheme.title_label("Loja do Recreio", 42, Color("ffcf3f"))
	t.add_theme_constant_override("outline_size", 10)
	t.add_theme_color_override("font_outline_color", UITheme.DARK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(t)
	head.add_child(_coin_pill(GameManager.coins(), 30))
	var dp := _diamond_pill(GameManager.diamonds(), 30)
	head.add_child(dp)
	# premiado opcional: vídeo -> moedas (só aparece com vídeo pronto; 3 por dia)
	if AdsManager.can_offer("moedas_extra"):
		var left := AdsManager.uses_left("moedas_extra")
		var vb: Button
		vb = UITheme.make_button("Ver vídeo: +%d moedas (%d hoje)" % [AdsManager.reward_coins(), left], func():
			vb.disabled = true
			AdsManager.show_rewarded("moedas_extra", func():
				GameManager.add_rewards(0, AdsManager.reward_coins())
				GameManager.show_toast("Você ganhou %d moedas!" % AdsManager.reward_coins())
				AudioManager.play_ui("coin")
				if visible:
					_refresh()), 300)
		vb.custom_minimum_size = Vector2(300, 60)
		vb.add_theme_stylebox_override("normal", UITheme.box(Color("9be37a"), 18, Color("5aa83a"), 0, 6))
		UITheme.dark_text(vb)
		head.add_child(vb)
	# ofertas
	var deals := ShopCatalog.deals()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)
	for id in deals.keys():
		var it := ShopCatalog.get_item(id)
		if it.is_empty():
			continue
		row.add_child(_deal_card(it, int(deals[id])))


func _deal_card(item: Dictionary, off: int) -> Control:
	var flash := off >= 50
	var b := Button.new()
	UITheme.dark_text(b)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(196 if flash else 148, 132)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c1 := Color("ff4d6d") if flash else Color("2f8be0")
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := UITheme.box(c1, 20, Color.WHITE if item.id == _selected else c1.darkened(0.3), 4, 6)
		b.add_theme_stylebox_override(st, sb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 6
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var tag := _label(("RELÂMPAGO -%d%%" % off) if flash else ("OFERTA -%d%%" % off), 16, Color("fff3b0"))
	v.add_child(tag)
	var nm := _label(item.name, 18, Color.WHITE)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	v.add_child(nm)
	var pr := HBoxContainer.new()
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var old := _label(str(item.price), 16, Color(1, 1, 1, 0.65))
	pr.add_child(old)
	pr.add_child(_label(" > ", 16, Color.WHITE))
	var ci := CoinIcon.new()
	ci.radius = 11
	pr.add_child(ci)
	pr.add_child(_label(" " + str(ShopCatalog.price_of(item)), 24, Color.WHITE))
	v.add_child(pr)
	if flash:
		var s := ShopCatalog.seconds_to_midnight()
		v.add_child(_label("Acaba em %02d:%02d" % [s / 3600, (s % 3600) / 60], 15, Color("fff3b0")))
	b.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		_cat = item.cat
		_selected = item.id
		_refresh())
	return b


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UITheme.bold_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _diamond_pill(amount: int, size := 24) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var sb := UITheme.box(UITheme.DARK, 24, Color("59c4f5"), 3, 0)
	sb.content_margin_left = 12
	sb.content_margin_right = 16
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(h)
	var di := DiamondIcon.new()
	di.radius = size * 0.5
	h.add_child(di)
	h.add_child(_label("%d  +" % amount, size, Color("bfe9ff")))
	b.custom_minimum_size = Vector2(130 + str(amount).length() * 16, size + 18)
	b.pressed.connect(func():
		_cat = "diamantes"
		_refresh())
	return b


func _coin_pill(amount: int, size := 24) -> Control:
	var p := PanelContainer.new()
	var sb := UITheme.box(UITheme.DARK, 24, Color("ffcf3f"), 3, 0)
	sb.content_margin_left = 12
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var ci := CoinIcon.new()
	ci.radius = size * 0.5
	h.add_child(ci)
	h.add_child(_label(str(amount), size, Color("ffe08a")))
	return p


func _card(item: Dictionary, owned: bool, shop := true) -> Control:
	var b := Button.new()
	UITheme.dark_text(b)
	b.custom_minimum_size = Vector2(200, 228)
	b.focus_mode = Control.FOCUS_NONE
	var locked := GameManager.level() < int(item.lvl)
	var rar := ShopCatalog.rarity_of(item)
	var rcol: Color = ShopCatalog.RARITY[rar][1]
	var sel: bool = item.id == _selected
	var bg := Color("fffaf0") if not locked else Color("e3e0d8")
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := UITheme.box(bg, 20, Color.WHITE if sel else rcol, 6 if sel else 4, 6)
		if sel:
			sb.shadow_color = Color(1, 0.85, 0.2, 0.7)
			sb.shadow_size = 10
		b.add_theme_stylebox_override(st, sb)
	# ícone desenhado do item (fundo da raridade, brilho nos épicos/lendários)
	var icon := ItemIcon.new(item)
	icon.position = Vector2(6, 6)
	icon.size = Vector2(188, 124)
	b.add_child(icon)
	if locked:
		var lk := ColorRect.new()
		lk.color = Color(0, 0, 0, 0.35)
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lk.position = icon.position
		lk.size = icon.size
		b.add_child(lk)
	var rl := _label(ShopCatalog.RARITY[rar][0].to_upper(), 14, Color.WHITE)
	rl.position = Vector2(12, 10)
	rl.add_theme_constant_override("outline_size", 6)
	rl.add_theme_color_override("font_outline_color", rcol.darkened(0.4))
	b.add_child(rl)
	if item.get("animated", false) or item.get("pass", false):
		var tg := _tag("PASSE" if item.get("pass", false) else "ANIMADO", Color("9b59ff") if item.get("pass", false) else Color("ff4d6d"))
		tg.position = Vector2(118, 8)
		b.add_child(tg)
	var nm := _label(item.name, 18, UITheme.DARK)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.position = Vector2(8, 132)
	nm.size = Vector2(184, 50)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(nm)
	# preço / estado
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.position = Vector2(8, 186)
	foot.size = Vector2(184, 34)
	foot.add_theme_constant_override("separation", 6)
	b.add_child(foot)
	var off := ShopCatalog.discount_of(item.id)
	if progression.is_equipped(item.id):
		foot.add_child(_tag("VESTINDO", UITheme.GREEN))
	elif owned and not item.get("consumable", false):
		foot.add_child(_tag("É SEU", Color("2f8be0")))
	elif item.get("pass", false):
		foot.add_child(_tag("NO PASSE", Color("9b59ff")))
	elif locked:
		foot.add_child(_tag("NÍVEL %d" % item.lvl, Color("8a8f99")))
	elif ShopCatalog.diamonds_of(item) > 0:
		var di := DiamondIcon.new()
		di.radius = 13
		foot.add_child(di)
		foot.add_child(_label(str(ShopCatalog.diamonds_of(item)), 26, Color("1f6fb0")))
	elif int(item.price) == 0:
		foot.add_child(_tag("GRÁTIS", UITheme.GREEN))
	else:
		var ci := CoinIcon.new()
		ci.radius = 12
		foot.add_child(ci)
		foot.add_child(_label(str(ShopCatalog.price_of(item)), 26, UITheme.DARK))
		if off > 0:
			foot.add_child(_tag("-%d%%" % off, Color("ff4d6d")))
		if item.has("bundle") or item.has("bundle_packs"):
			foot.add_child(_tag("-%d" % maxi(ShopCatalog.bundle_value(item) - int(item.price), 0), UITheme.ORANGE))
	b.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		_selected = item.id
		_refresh()
		# vitrine grande: personagem usando o item (antes/depois)
		var sc := ItemShowcase.open(self, self, item.id)
		sc.done.connect(func(): _refresh()))
	return b


func _tag(text: String, col: Color) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UITheme.box(col, 10, Color(0, 0, 0, 0), 0, 0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(_label(text, 16, Color.WHITE))
	return p


func _update_preview() -> void:
	if _stage == null:
		return
	var extra := []
	if _selected != "" and ShopCatalog.get_item(_selected).has("look"):
		extra.append(_selected)
	# trocou o que está vestindo: gira com brilhinho e aproxima no que mudou
	var key := ",".join(extra)
	var changed := key != _last_look
	_last_look = key
	_stage.set_appearance(Progression.appearance_with(extra), changed and key != "")
	if changed and _selected != "":
		var cat := str(ShopCatalog.get_item(_selected).get("cat", ""))
		_stage.focus("head" if cat in ["bone", "penteado", "acessorio"] else "body")
		if cat == "calcado":
			_stage.play("hop_two")
		elif cat in ["camiseta", "skin", "mochila"]:
			_stage.play("celebrate")
	if _selected == "" or not (_tab in ["loja", "visual"]):
		return
	var item := ShopCatalog.get_item(_selected)
	var owned := Progression.owns(_selected)
	var need := ShopCatalog.ad_cost(_selected)
	_ad_action.visible = need > 0 and not owned and GameManager.level() >= int(item.lvl) and AdsManager.can_offer("item_video")
	if _ad_action.visible:
		_ad_action.disabled = false
		_ad_action.text = ("Ganhar com vídeo" if need == 1 else "Ganhar com vídeos (%d/%d)" % [AdsManager.item_views(_selected), need])
	_action.visible = true
	_action.disabled = false
	if owned and not item.get("consumable", false):
		_action.text = "Equipado" if progression.is_equipped(_selected) else "Equipar"
		_action.disabled = progression.is_equipped(_selected) or not (item.has("look") or item.has("vehicle"))
		_info.text = item.name + ("\n(fica na sua carteira da sala)" if item.cat == "decoracao" else "") + ("\n" + str(item.desc) if item.has("desc") else "")
		if item.cat == "emote":
			_action.text = "Já é seu"
			_action.disabled = true
			_info.text += "\nUse no botão de emoji (carinha) da tela."
	else:
		var price := ShopCatalog.price_of(item)
		var off := ShopCatalog.discount_of(item.id)
		_action.text = "Comprar por %d" % price
		_action.disabled = GameManager.level() < int(item.lvl) or GameManager.coins() < price
		var lines := [item.name]
		if item.has("desc"):
			lines.append(str(item.desc))
		lines.append(("De %d por %d moedas (-%d%%)" % [item.price, price, off]) if off > 0 else "Preço: %d moedas" % price)
		if GameManager.level() < int(item.lvl):
			lines.append("Libera no nível %d" % item.lvl)
		elif GameManager.coins() < price:
			lines.append("Faltam %d moedas" % (price - GameManager.coins()))
		_info.text = "\n".join(lines)


func _on_ad_action() -> void:
	var id := _selected
	if id == "" or Progression.owns(id):
		return
	_ad_action.disabled = true
	AdsManager.show_rewarded("item_video", func():
		if AdsManager.add_item_view(id):
			if progression.grant(id):
				AudioManager.play_ui("celebrate", -4.0)
				GameManager.show_toast("Você ganhou: %s!" % ShopCatalog.get_item(id).name)
				if ShopCatalog.get_item(id).has("look"):
					progression.equip(id)
		else:
			GameManager.show_toast("Falta%s %d vídeo%s para ganhar!" % ["m" if ShopCatalog.ad_cost(id) - AdsManager.item_views(id) > 1 else "", ShopCatalog.ad_cost(id) - AdsManager.item_views(id), "s" if ShopCatalog.ad_cost(id) - AdsManager.item_views(id) > 1 else ""])
		if visible:
			_refresh())
	if not AdsManager.can_show_rewarded():
		_ad_action.disabled = false


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
		elif item.has("look") or item.has("kart"):
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


# ------------------------------------------------------------ destaques e loja de diamantes

func _section(t: String, col := Color("ffcf3f")) -> void:
	var l := UITheme.title_label(t, 30, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", UITheme.DARK)
	_content.add_child(l)


func _grid_of(ids: Array) -> void:
	var grid := GridContainer.new()
	var avail := get_viewport_rect().size.x - 196.0 - 300.0 - 80.0
	grid.columns = clampi(int(avail / 214.0), 2, 5)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_content.add_child(grid)
	for id in ids:
		var it := ShopCatalog.get_item(id)
		if not it.is_empty():
			grid.add_child(_card(it, Progression.owns(id), true))


## Vitrine principal: pacote de boas-vindas, lendários de diamante, novidades e passe.
func _build_featured() -> void:
	if not StoreOffers.starter_bought():
		_content.add_child(_starter_banner())
	# chamada do passe
	var pb := UITheme.make_button("PASSE DO RECREIO: skins, emojis animados, karts e diamantes  >", func(): open_tab("passe"), 200)
	pb.custom_minimum_size = Vector2(0, 64)
	pb.add_theme_stylebox_override("normal", UITheme.box(Color("9b59ff"), 20, Color("6a2fd6"), 0, 6))
	pb.add_theme_color_override("font_color", Color.WHITE)
	pb.add_theme_font_size_override("font_size", 21)
	_content.add_child(pb)
	_section("Lendários de diamante", Color("7fe3ff"))
	_grid_of(["skin_princesa", "skin_cavaleiro", "skin_craque_neon", "aura_dourada", "emo_backflip", "aura_notas"])
	_section("Novidades")
	_grid_of(["skin_tigre", "skin_rock", "skin_surfista", "cam_estrela", "cam_raio", "cam_xadrez", "emo_dance", "emo_robot"])
	_section("Karts com design (só no Passe)", Color("9b59ff"))
	_grid_of(["kart_turbo", "kart_foguete", "kart_campeao", "kart_neon"])
	# rodízio diário: 4 itens diferentes por dia
	_section("Seleção do dia")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("selecao-" + Time.get_date_string_from_system())
	var pool := ShopCatalog.ITEMS.filter(func(i): return (int(i.get("price", 0)) >= 100 or ShopCatalog.diamonds_of(i) > 0) and not i.get("pass", false) and not i.get("legacy", false) and not i.get("consumable", false))
	var pick := []
	while pick.size() < 4 and not pool.is_empty():
		var it: Dictionary = pool.pop_at(rng.randi() % pool.size())
		pick.append(it.id)
	_grid_of(pick)


func _starter_banner() -> Control:
	var st: Dictionary = StoreOffers.STARTER
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 170)
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, UITheme.box(Color("ff8a1f"), 24, Color("ffd23f"), 5, 8))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -14
	h.offset_top = 10
	h.offset_bottom = -10
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := ItemIcon.new(ShopCatalog.get_item(str(st.item)))
	ic.custom_minimum_size = Vector2(190, 140)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var t := _label("PACOTE DE BOAS-VINDAS (só 1 vez!)", 24, Color.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var d := _label("Skin lendária Cavaleiro Dourado + %d diamantes + %d moedas" % [int(st.diamonds), int(st.coins)], 20, Color("fff3b0"))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var pr := _label(Billing.price_of(str(st.id)), 34, Color.WHITE)
	pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(pr)
	b.pressed.connect(func(): _confirm_money(str(st.id), "Pacote de Boas-vindas"))
	return b


## Diamantes e moedas com dinheiro de verdade + troca de diamantes por moedas.
func _build_money_store() -> void:
	var warn := _label("Compras com dinheiro de verdade: peça para um ADULTO. A compra é feita pela Play Store, com a senha do responsável.", 18, Color("c0392b"))
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(warn)
	if not StoreOffers.starter_bought():
		_content.add_child(_starter_banner())
	_section("Diamantes", Color("7fe3ff"))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 12)
	_content.add_child(row)
	for o in StoreOffers.DIAMONDS:
		row.add_child(_money_card(o, true))
	_section("Moedas")
	var row2 := HFlowContainer.new()
	row2.add_theme_constant_override("h_separation", 12)
	row2.add_theme_constant_override("v_separation", 12)
	_content.add_child(row2)
	for o in StoreOffers.COINS:
		row2.add_child(_money_card(o, false))
	_section("Trocar diamantes por moedas")
	var row3 := HFlowContainer.new()
	row3.add_theme_constant_override("h_separation", 12)
	_content.add_child(row3)
	for i in StoreOffers.EXCHANGE.size():
		var e: Array = StoreOffers.EXCHANGE[i]
		var idx := i
		var eb := UITheme.make_button("%d diamantes  >  %d moedas" % [int(e[0]), int(e[1])], func():
			if StoreOffers.exchange(idx):
				GameManager.show_toast("Trocou! +%d moedas" % int(e[1]))
			else:
				GameManager.show_toast("Diamantes insuficientes.")
			_refresh(), 300)
		eb.disabled = GameManager.diamonds() < int(e[0])
		row3.add_child(eb)


func _money_card(o: Dictionary, dia: bool) -> Control:
	var b := Button.new()
	UITheme.dark_text(b)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(200, 210)
	var col := Color("bfe9ff") if dia else Color("fff1b8")
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, UITheme.box(col, 22, Color("2f9be0") if dia else Color("f5b400"), 4, 6))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 10
	v.offset_bottom = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	if str(o.get("tag", "")) != "":
		var tg := _tag(str(o.tag), Color("ff4d6d"))
		v.add_child(tg)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cc)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(hb)
	var n := 1 + mini(int(o.get("diamonds", o.get("coins", 0))) / 300, 3) if dia else 1 + mini(int(o.get("coins", 0)) / 5000, 3)
	for i in n:
		if dia:
			var di := DiamondIcon.new()
			di.radius = 22
			hb.add_child(di)
		else:
			var ci := CoinIcon.new()
			ci.radius = 20
			hb.add_child(ci)
	var amount := int(o.get("diamonds", 0)) if dia else int(o.get("coins", 0))
	v.add_child(_label(str(amount), 36, UITheme.DARK))
	if int(o.get("bonus", 0)) > 0:
		v.add_child(_label("+%d de bônus" % int(o.bonus), 18, Color("1f9e4a")))
	v.add_child(_label(Billing.price_of(str(o.id)), 26, Color("1f6fb0") if dia else Color("b7791f")))
	b.pressed.connect(func(): _confirm_money(str(o.id), ("%d diamantes" % (amount + int(o.get("bonus", 0)))) if dia else "%d moedas" % amount))
	return b


## Confirmação antes de abrir a compra da Play Store.
func _confirm_money(id: String, what: String) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Comprar com dinheiro de verdade"
	dlg.dialog_text = "%s por %s.\n\nPeça para um adulto confirmar.\nA compra é feita pela Play Store." % [what, Billing.price_of(id)]
	dlg.ok_button_text = "Comprar"
	dlg.cancel_button_text = "Agora não"
	add_child(dlg)
	dlg.confirmed.connect(func():
		Billing.buy(id)
		dlg.queue_free())
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered()


# ------------------------------------------------------------ passe do recreio

func _build_pass() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_content.add_child(head)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tv)
	var t := UITheme.title_label("Passe do Recreio", 42, Color("c9a8ff"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.add_theme_constant_override("outline_size", 10)
	t.add_theme_color_override("font_outline_color", UITheme.DARK)
	tv.add_child(t)
	var sub := _label("%s  ·  acaba em %d dia(s)  ·  nível %d de %d" % [RecessPass.season_name(), RecessPass.days_left(), RecessPass.tier(), RecessPass.TIERS], 20, UITheme.DARK)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(sub)
	# barra de progresso do nível
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = RecessPass.tier_progress()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 22)
	bar.add_theme_stylebox_override("background", UITheme.box(Color("d9d2ea"), 11))
	bar.add_theme_stylebox_override("fill", UITheme.box(Color("c9a8ff"), 11))
	tv.add_child(bar)
	var xpl := _label("Ganhe XP jogando (aulas, brincadeiras, missões): %d / %d XP para o próximo nível" % [RecessPass.xp() % RecessPass.TIER_XP, RecessPass.TIER_XP], 16, Color("5b6b8c"))
	xpl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(xpl)
	if RecessPass.is_premium():
		head.add_child(_tag("PREMIUM ATIVO", Color("9b59ff")))
	else:
		var buy := UITheme.make_button("Comprar\n%s / mês" % Billing.price_text, func():
			Billing.buy_pass()
			await get_tree().create_timer(0.3).timeout
			if visible:
				_refresh(), 260)
		buy.custom_minimum_size = Vector2(260, 72)
		buy.add_theme_font_size_override("font_size", 22)
		buy.add_theme_stylebox_override("normal", UITheme.box(Color("9b59ff"), 20, Color("6a2fd6"), 0, 6))
		buy.add_theme_color_override("font_color", Color.WHITE)
		head.add_child(buy)
	if not RecessPass.is_premium():
		var why := _label(RecessPass.premium_summary(), 20, Color("7b3fe0"))
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(why)
	# trilhas: premium em cima, grátis embaixo (rola para o lado)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 420)
	sc.scroll_deadzone = 12
	_content.add_child(sc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	sc.add_child(row)
	var first_open := -1
	for i in range(1, RecessPass.TIERS + 1):
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		row.add_child(col)
		var reached := RecessPass.tier() >= i
		var num := _label("Nível %d" % i, 20, Color("e67e22") if reached else Color("8a8f99"))
		col.add_child(num)
		col.add_child(_pass_cell("prem", i))
		col.add_child(_pass_cell("free", i))
		if first_open < 0 and (RecessPass.can_claim("free", i) or RecessPass.can_claim("prem", i) or not reached):
			first_open = i
	# rola até o primeiro prêmio a pegar
	get_tree().process_frame.connect(func():
		if is_instance_valid(sc):
			sc.scroll_horizontal = maxi((first_open - 2) * 170, 0), CONNECT_ONE_SHOT)
	_build_challenges()
	if Billing.can_test() and not RecessPass.is_premium():
		_content.add_child(_label("(versão de desenvolvimento: \"Comprar\" ativa o passe de teste)", 14, Color("8a8f99")))


## Desafios da semana: cada um dá XP do passe (é jogando que se libera os prêmios).
func _build_challenges() -> void:
	_section("Desafios da semana (dão XP do passe)", Color("c9a8ff"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_content.add_child(grid)
	var list := RecessPass.challenges()
	for i in list.size():
		var e: Dictionary = list[i]
		var prog := RecessPass.challenge_progress(e)
		var done: bool = prog >= int(e.target)
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(330, 0)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_stylebox_override("panel", UITheme.box(Color("efe4ff") if not bool(e.claimed) else Color("dcdce4"), 16, Color("9b59ff") if done and not bool(e.claimed) else Color(0, 0, 0, 0), 3, 3))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		p.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var l := _label(str(e.desc) % int(e.target), 18, UITheme.DARK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		var bar := ProgressBar.new()
		bar.max_value = float(e.target)
		bar.value = float(prog)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		bar.add_theme_stylebox_override("background", UITheme.box(Color("d9d2ea"), 7))
		bar.add_theme_stylebox_override("fill", UITheme.box(Color("9b59ff"), 7))
		v.add_child(bar)
		var info := _label("%d/%d  ·  +%d XP" % [prog, int(e.target), int(e.xp)], 15, Color("5b6b8c"))
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(info)
		if bool(e.claimed):
			h.add_child(_tag("FEITO", Color("8a8f99")))
		elif done:
			var idx := i
			var cb := UITheme.make_button("Pegar XP", func():
				if RecessPass.claim_challenge(idx):
					GameManager.show_toast("+%d XP do passe!" % int(e.xp))
				_refresh(), 140)
			h.add_child(cb)


func _pass_cell(track: String, tier_i: int) -> Control:
	var r := RecessPass.reward(track, tier_i)
	var b := Button.new()
	UITheme.dark_text(b)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(160, 180)
	var prem := track == "prem"
	var bgc := Color("efe4ff") if prem else Color("fffaf0")
	var border := Color("9b59ff") if prem else Color("c9b98f")
	if RecessPass.claimed(track, tier_i):
		bgc = bgc.darkened(0.25)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, UITheme.box(bgc, 18, border, 4, 4))
	if r.is_empty():
		b.disabled = true
		return b
	var icon_item: Dictionary = {}
	var txt := ""
	if r.has("item"):
		icon_item = ShopCatalog.get_item(str(r.item))
		txt = str(icon_item.get("name", ""))
	elif r.has("coins"):
		txt = "%d moedas" % int(r.coins)
	elif r.has("diamonds"):
		txt = "%d diamantes" % int(r.diamonds)
	else:
		var pk: Dictionary = r.packs
		txt = "%d pacote(s)" % int(pk.values()[0])
		icon_item = {"cat": "figurinha" if pk.has("figurinha") else "gude", "id": "", "price": 0}
	if not icon_item.is_empty():
		var ic := ItemIcon.new(icon_item)
		ic.position = Vector2(8, 8)
		ic.size = Vector2(144, 96)
		b.add_child(ic)
	elif r.has("diamonds"):
		var di := DiamondIcon.new()
		di.radius = 32
		di.position = Vector2(46, 20)
		b.add_child(di)
	else:
		var ci := CoinIcon.new()
		ci.radius = 30
		ci.position = Vector2(50, 22)
		b.add_child(ci)
	var l := _label(txt, 16, UITheme.DARK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(6, 106)
	l.size = Vector2(148, 40)
	b.add_child(l)
	var state := ""
	var scol := UITheme.GREEN
	if RecessPass.claimed(track, tier_i):
		state = "PEGO"
		scol = Color("8a8f99")
	elif RecessPass.can_claim(track, tier_i):
		state = "PEGAR!"
		scol = Color("ff4d6d")
	elif prem and not RecessPass.is_premium():
		state = "PREMIUM"
		scol = Color("9b59ff")
	else:
		state = "NÍVEL %d" % tier_i
		scol = Color("8a8f99")
	var tg := _tag(state, scol)
	tg.position = Vector2(30, 148)
	b.add_child(tg)
	b.pressed.connect(func():
		if RecessPass.can_claim(track, tier_i):
			var got := RecessPass.claim(track, tier_i)
			if got != "":
				GameManager.show_toast("Você ganhou: %s!" % got)
				if r.has("item") and ShopCatalog.get_item(str(r.item)).has("look"):
					progression.equip(str(r.item))
			_refresh()
		elif r.has("item"):
			ItemShowcase.open(self, self, str(r.item)).done.connect(func(): _refresh())
		elif prem and not RecessPass.is_premium():
			GameManager.show_toast("Prêmio da trilha PREMIUM: compre o Passe do Recreio!"))
	return b


func _build_games() -> void:
	_title("Brincadeiras do recreio")
	var tip := _label("Cada brincadeira custa poucas moedas. Ganhe moedas nas AULAS: cada acerto vale %d (e tentar vale %d)!" % [SchoolDay.COIN_RIGHT, SchoolDay.COIN_TRY], 18, Color("8a5a00"))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(tip)
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
		a.text = "%s  ·  %d moedas" % [g.title, int(MinigameManager.PRICES.get(gid, 3))]
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
		var bv := VBoxContainer.new()
		bv.add_theme_constant_override("separation", 6)
		bv.add_child(go)
		var how := UITheme.make_button("Como jogar", func():
			if minigames:
				minigames.show_tutorial(gid, func(): pass), 220)
		how.custom_minimum_size = Vector2(220, 50)
		how.add_theme_font_size_override("font_size", 19)
		bv.add_child(how)
		h.add_child(bv)
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
	_title("Meus amigos")
	if NetworkManager.is_online() and NetworkManager.room_code != "":
		_row("Sua sala: %s" % NetworkManager.room_code, "Fale esse código para um amigo entrar (Amigos > Entrar com código), ou toque em Chamar.", Color("ffe08a"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_content.add_child(box)
	var wait := Label.new()
	wait.text = "Carregando..."
	wait.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(wait)
	_fill_real_friends(box)
	_title("Colegas da turma")
	for s in NPCRoster.STUDENTS:
		var lv := Friendship.level(s.id)
		var pts := Friendship.points(s.id)
		var nxt: int = Friendship.LEVELS[mini(lv + 1, Friendship.LEVELS.size() - 1)]
		_row("%s — %s" % [s.name, Friendship.LEVEL_NAMES[lv]], "Gosta de: %s   ·   %d/%d pontos" % [_likes(s.personality), pts, nxt])


## Amigos de verdade (contas): quem está na escola dá para CHAMAR para a minha
## sala ou IR para a sala dele. Adicionar e aceitar pedidos: tela Amigos do menu.
func _fill_real_friends(box: VBoxContainer) -> void:
	var r: Dictionary = await AccountManager.friends_list()
	if not is_instance_valid(box):
		return
	for c in box.get_children():
		c.queue_free()
	var list: Array = r.get("list", [])
	if not r.get("ok", false) or list.is_empty():
		var l := Label.new()
		l.text = "Adicione amigos pelo nome de jogador na tela Amigos do menu (botão azul)."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_font_size_override("font_size", 20)
		box.add_child(l)
		return
	for f in list:
		var st := str(f.get("status", ""))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		box.add_child(h)
		var on := bool(f.get("online", false))
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color("9be37a") if on else Color.WHITE)
		var code := str(f.get("code", ""))
		var here := on and code == NetworkManager.room_code
		lbl.text = "%s  ·  %s" % [f.name, ("aqui na sua sala!" if here else ("na sala %s" % code)) if on else ("quer ser seu amigo" if st == "incoming" else ("pedido enviado" if st == "outgoing" else "fora do jogo"))]
		h.add_child(lbl)
		var id := str(f.get("id", ""))
		if st == "incoming":
			h.add_child(UITheme.make_button("Aceitar", func():
				await AccountManager.friend_accept(id)
				_fill_real_friends(box), 160))
		elif st == "friend" and on and not here and NetworkManager.is_online():
			h.add_child(UITheme.make_button("Chamar", func():
				NetworkManager.invite_friend(id)
				GameManager.show_toast("Convite enviado para %s!" % f.name), 150))
			h.add_child(UITheme.make_button("Ir até lá", func():
				close_menu()
				var s := get_tree().get_first_node_in_group("online_session")
				if s:
					s.switch_room(code), 160))
		elif st == "friend" and not on:
			pass


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
