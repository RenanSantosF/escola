class_name ProfileMenu
extends Control
## Menu "Mochila": loja com prévia 3D (experimente antes de comprar),
## guarda-roupa, coleções (álbum de figurinhas e bolinhas), missões
## diárias, conquistas, amigos e ficha (reputação/ocorrências).

signal closed

const TABS := [["loja", "Loja"], ["visual", "Guarda-roupa"], ["passe", "Passe"], ["brincadeiras", "Brincadeiras"], ["colecoes", "Coleções"],
	["missoes", "Missões"], ["conquistas", "Conquistas"], ["amigos", "Amigos"], ["ficha", "Ficha"]]
const SIDE_W := 360.0
## Loja com poucas abas: as roupas ficam juntas (com subtítulos) e o resto em "Extras".
const SHOP_GROUPS := [
	["destaques", "Destaques", []], ["skin", "Skins", ["skin"]],
	["roupas", "Roupas", ["camiseta", "calca", "calcado", "mochila", "bone"]],
	["cabelo", "Cabelo e acessórios", ["penteado", "acessorio"]],
	["aura", "Efeitos", ["aura"]], ["emote", "Emojis", ["emote"]], ["kart", "Karts", ["kart"]],
	["extras", "Extras", ["pacote", "veiculo", "decoracao", "gude", "figurinha"]],
	["diamantes", "Diamantes", []],
]

var progression: Progression
var minigames: Node
var _tab := "loja"
var _cat := "destaques"
var _selected := ""
var _content: VBoxContainer
var _side: VBoxContainer
var _stage: CharacterStage
var _last_look := ""
var _info: Label
var _action: Button
var _ad_action: Button  ## "Ganhar com vídeo (1/3)" (só aparece com vídeo pronto)
var _tab_buttons := {}
var _wallet: HBoxContainer
var _side_panel: PanelContainer
var _kart_stage: KartStage
var _item_name: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 20)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)
	# barra de cima: voltar | abas | moedas e diamantes
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	var close := Button.new()
	close.text = "‹  Voltar"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(130, 52)
	close.add_theme_font_size_override("font_size", 20)
	UITheme.style_button(close, UITheme.CARD, true)
	close.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		close_menu())
	top.add_child(close)
	var tab_scroll := ScrollContainer.new()
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_scroll.custom_minimum_size = Vector2(0, 56)
	tab_scroll.scroll_deadzone = 12
	top.add_child(tab_scroll)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tab_scroll.add_child(tabs)
	for t in TABS:
		var tid: String = t[0]
		var b := UITheme.chip(t[1], false, func():
			_tab = tid
			_selected = ""
			_refresh(), 20)
		b.custom_minimum_size = Vector2(0, 52)
		tabs.add_child(b)
		_tab_buttons[tid] = b
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 8)
	top.add_child(wallet)
	_wallet = wallet
	# corpo: conteúdo (cartão branco com rolagem) + vitrine fixa ao lado
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	col.add_child(body)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UITheme.card(UITheme.CARD, 16))
	body.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12  # arrastar o dedo rola; toque curto seleciona
	panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	scroll.add_child(_content)
	# vitrine: o personagem (ou o kart) usando o item escolhido, nome, preço e botão
	var side_panel := PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(SIDE_W, 0)
	side_panel.add_theme_stylebox_override("panel", UITheme.card(UITheme.CARD, 16))
	body.add_child(side_panel)
	_side_panel = side_panel
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 10)
	side_panel.add_child(_side)
	_stage = CharacterStage.new()
	_stage.custom_minimum_size = Vector2(SIDE_W - 36, 330)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.auto_emotes = false
	_stage.podium_color = UITheme.ACCENT
	_side.add_child(_stage)
	_kart_stage = KartStage.new()
	_kart_stage.custom_minimum_size = Vector2(SIDE_W - 36, 330)
	_kart_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_kart_stage.visible = false
	_side.add_child(_kart_stage)
	_item_name = UITheme.title_label("", 26, UITheme.INK)
	_item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_side.add_child(_item_name)
	_info = UITheme.text_label("", 17, UITheme.INK_2, true)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.custom_minimum_size = Vector2(SIDE_W - 36, 0)
	_side.add_child(_info)
	_action = UITheme.make_button("", _on_action, SIDE_W - 36)
	_action.custom_minimum_size = Vector2(SIDE_W - 36, 60)
	_side.add_child(_action)
	_ad_action = UITheme.make_button("", _on_ad_action, SIDE_W - 36)
	_ad_action.custom_minimum_size = Vector2(SIDE_W - 36, 52)
	UITheme.style_button(_ad_action, UITheme.CARD_2, true)
	_ad_action.add_theme_font_size_override("font_size", 19)
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
	var pend := RecessPass.pending()
	for t in _tab_buttons.keys():
		var on: bool = t == _tab
		var b: Button = _tab_buttons[t]
		UITheme.style_button(b, UITheme.ACCENT if on else UITheme.CARD, not on, 10)
		if not on:
			for st in ["normal", "hover"]:
				var sb := UITheme.card(UITheme.CARD, 10)
				sb.shadow_size = 0
				sb.content_margin_top = 8
				sb.content_margin_bottom = 8
				b.add_theme_stylebox_override(st, sb)
	_tab_buttons["passe"].text = "Passe  •  %d" % pend if pend > 0 else "Passe"
	for c in _content.get_children():
		c.queue_free()
	_fill_wallet()
	var show_preview := _tab in ["loja", "visual", "passe"]
	_side_panel.visible = show_preview
	_action.visible = false
	_info.text = ""
	_item_name.text = ""
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


## Moedas e diamantes no canto de cima (toque nos diamantes = loja de diamantes).
func _fill_wallet() -> void:
	for c in _wallet.get_children():
		c.queue_free()
	for k in ["coins", "diamonds"]:
		var p := Button.new()
		p.focus_mode = Control.FOCUS_NONE
		p.custom_minimum_size = Vector2(0, 52)
		var sb := UITheme.card(UITheme.CARD, 12)
		sb.shadow_size = 0
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		sb.content_margin_left = 12
		sb.content_margin_right = 14
		for st in ["normal", "hover", "pressed", "focus"]:
			p.add_theme_stylebox_override(st, sb)
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 6)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 12
		h.offset_right = -12
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		p.add_child(h)
		if k == "coins":
			var ci := CoinIcon.new()
			ci.radius = 13
			ci.custom_minimum_size = Vector2(28, 28)
			h.add_child(ci)
		else:
			var di := DiamondIcon.new()
			di.radius = 12
			h.add_child(di)
		var n := str(GameManager.coins()) if k == "coins" else str(GameManager.diamonds())
		var l := UITheme.title_label(n, 22, UITheme.INK)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l)
		var font: Font = UITheme.bold_font()
		p.custom_minimum_size.x = 70.0 + font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		if k == "diamonds":
			p.pressed.connect(func():
				_tab = "loja"
				_cat = "diamantes"
				_selected = ""
				_refresh())
		_wallet.add_child(p)


func _title(t: String) -> void:
	var l := UITheme.title_label(t, 32, UITheme.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_content.add_child(l)


func _build_items(shop: bool) -> void:
	if not shop:
		_title("Guarda-roupa")
		# menino ou menina
		var gh := HBoxContainer.new()
		gh.add_theme_constant_override("separation", 8)
		_content.add_child(gh)
		var cur_girl: bool = GameManager.player.visual.appearance.girl if GameManager.player else bool(SaveManager.section("player").get("appearance", {}).get("girl", false))
		for opt in [["Menino", false], ["Menina", true]]:
			var girl: bool = opt[1]
			gh.add_child(UITheme.chip(opt[0], girl == cur_girl, func():
				if GameManager.player:
					var a: CharacterAppearance = GameManager.player.visual.appearance
					a.set_girl(girl)
					GameManager.player.set_appearance(a)
				if NetworkManager.is_online():
					NetworkManager.send_look()
				_refresh(), 19))
	# grupos (poucas abas, numa fileira só)
	var cat_scroll := ScrollContainer.new()
	cat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cat_scroll.custom_minimum_size = Vector2(0, 54)
	cat_scroll.scroll_deadzone = 12
	_content.add_child(cat_scroll)
	var cats := HBoxContainer.new()
	cats.add_theme_constant_override("separation", 8)
	cat_scroll.add_child(cats)
	var groups := SHOP_GROUPS.filter(func(g): return shop or not (g[0] in ["destaques", "diamantes"]))
	if not groups.any(func(g): return g[0] == _cat):
		_cat = str(groups[0][0])
	for g in groups:
		var gid: String = g[0]
		cats.add_child(UITheme.chip(g[1], gid == _cat, func():
			_cat = gid
			_selected = ""
			_refresh(), 19))
	if shop and _cat == "destaques":
		_build_featured()
		return
	if shop and _cat == "diamantes":
		_build_money_store()
		return
	var subcats: Array = []
	for g in groups:
		if g[0] == _cat:
			subcats = g[2]
	var any := false
	for sc in subcats:
		var items := ShopCatalog.by_cat(str(sc)).filter(func(it): return shop or Progression.owns(it.id))
		if not shop:
			items = items.filter(func(it): return not (str(sc) in ["gude", "figurinha", "decoracao", "pacote"]))
		if items.is_empty():
			continue
		if subcats.size() > 1:
			var nm := ""
			for c in ShopCatalog.CATEGORIES:
				if c[0] == sc:
					nm = c[1]
			var sl := UITheme.title_label(nm, 22, UITheme.INK_2)
			sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_content.add_child(sl)
		var grid := GridContainer.new()
		grid.columns = _grid_cols()
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		_content.add_child(grid)
		for item in items:
			grid.add_child(_card(item, Progression.owns(item.id), shop))
			any = true
	if not any:
		_row("Nada aqui ainda", "Compre itens na Loja para usar no guarda-roupa.")


## Quantas colunas de cartões cabem (a vitrine fica ao lado).
func _grid_cols() -> int:
	var avail := get_viewport_rect().size.x - SIDE_W - 120.0
	return clampi(int(avail / 206.0), 2, 6)


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
	b.custom_minimum_size = Vector2(192, 214)
	b.focus_mode = Control.FOCUS_NONE
	var locked := GameManager.level() < int(item.lvl)
	var sel: bool = item.id == _selected
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := UITheme.card(UITheme.CARD if st != "hover" else Color("fafbff"), 14, UITheme.ACCENT if sel else UITheme.STROKE)
		sb.set_border_width_all(3 if sel else 1)
		sb.shadow_size = 0 if not sel else 10
		b.add_theme_stylebox_override(st, sb)
	# desenho do item (fundo da cor da raridade)
	var icon := ItemIcon.new(item)
	icon.position = Vector2(8, 8)
	icon.size = Vector2(176, 122)
	b.add_child(icon)
	if locked:
		var lk := ColorRect.new()
		lk.color = Color(1, 1, 1, 0.55)
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lk.position = icon.position
		lk.size = icon.size
		b.add_child(lk)
	var nm := _label(item.name, 18, UITheme.INK)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.position = Vector2(10, 134)
	nm.size = Vector2(172, 44)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(nm)
	# preço ou estado (uma coisa só, bem legível)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.position = Vector2(8, 178)
	foot.size = Vector2(176, 30)
	foot.add_theme_constant_override("separation", 6)
	b.add_child(foot)
	var off := ShopCatalog.discount_of(item.id)
	if progression.is_equipped(item.id):
		foot.add_child(_tag("USANDO", UITheme.GOOD))
	elif owned and not item.get("consumable", false):
		foot.add_child(_tag("É SEU", UITheme.ACCENT))
	elif item.get("pass", false):
		foot.add_child(_tag("PASSE", UITheme.PASS_A))
	elif locked:
		foot.add_child(_tag("NÍVEL %d" % item.lvl, Color("98a1b8")))
	elif ShopCatalog.diamonds_of(item) > 0:
		var di := DiamondIcon.new()
		di.radius = 12
		foot.add_child(di)
		foot.add_child(_label(str(ShopCatalog.diamonds_of(item)), 22, UITheme.INK))
	elif int(item.price) == 0:
		foot.add_child(_tag("GRÁTIS", UITheme.GOOD))
	else:
		var ci := CoinIcon.new()
		ci.radius = 11
		foot.add_child(ci)
		foot.add_child(_label(str(ShopCatalog.price_of(item)), 22, UITheme.INK))
		if off > 0:
			foot.add_child(_tag("-%d%%" % off, Color("ef4444")))
	b.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		# escolher = já mostra na vitrine do lado (sem abrir outra tela)
		_selected = item.id
		_refresh())
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
	var item := ShopCatalog.get_item(_selected) if _selected != "" else {}
	var is_kart := item.has("kart")
	_kart_stage.visible = is_kart
	_stage.visible = not is_kart
	if is_kart:
		_kart_stage.set_item(_selected)
	var extra := []
	if item.has("look"):
		extra.append(_selected)
	# trocou o que está vestindo: gira com brilhinho e aproxima no que mudou
	var key := ",".join(extra)
	var changed := key != _last_look
	_last_look = key
	_stage.set_appearance(Progression.appearance_with(extra), changed and key != "")
	if changed and _selected != "" and item.has("look"):
		var cat := str(item.get("cat", ""))
		_stage.focus("head" if cat in ["bone", "penteado", "acessorio"] else "body")
		if cat == "calcado":
			_stage.play("hop_two")
		elif cat in ["camiseta", "skin", "mochila"]:
			_stage.play("celebrate")
	if item.has("emote"):
		_stage.play(str(item.emote))
	if _selected == "" or not (_tab in ["loja", "visual", "passe"]):
		_item_name.text = "Seu personagem"
		_info.text = "Toque num prêmio para ver em você." if _tab == "passe" else "Toque num item para ver em você. Arraste para girar."
		_ad_action.visible = false
		return
	if _tab == "passe":
		# no passe: só mostra o prêmio (pega tocando no nível)
		_item_name.text = str(item.get("name", ""))
		_info.text = "%s · prêmio do passe" % str(ShopCatalog.RARITY[ShopCatalog.rarity_of(item)][0])
		_action.visible = false
		_ad_action.visible = false
		return
	var owned := Progression.owns(_selected)
	_item_name.text = str(item.name)
	var rar := ShopCatalog.rarity_of(item)
	var lines := [str(ShopCatalog.RARITY[rar][0])]
	if item.has("desc"):
		lines.append(str(item.desc))
	var need := ShopCatalog.ad_cost(_selected)
	_ad_action.visible = need > 0 and not owned and GameManager.level() >= int(item.lvl) and AdsManager.can_offer("item_video")
	if _ad_action.visible:
		_ad_action.disabled = false
		_ad_action.text = ("Ganhar com vídeo" if need == 1 else "Ganhar com vídeos (%d/%d)" % [AdsManager.item_views(_selected), need])
	_action.visible = true
	_action.disabled = false
	UITheme.style_button(_action, UITheme.ACCENT)
	if owned and not item.get("consumable", false):
		_action.text = "Usando" if progression.is_equipped(_selected) else "Usar"
		_action.disabled = progression.is_equipped(_selected) or not (item.has("look") or item.has("vehicle") or item.has("kart"))
		if item.cat == "decoracao":
			lines.append("Fica na sua carteira da sala.")
		if item.cat == "emote":
			_action.text = "Já é seu"
			_action.disabled = true
			lines.append("Use no botão de emoji (carinha) da tela.")
	elif item.get("pass", false):
		_action.text = "Ver no Passe"
		UITheme.style_button(_action, UITheme.PASS_A)
		lines.append("Exclusivo do Passe do Recreio.")
	else:
		var dia := ShopCatalog.diamonds_of(item)
		if dia > 0:
			_action.text = "Comprar por %d diamantes" % dia
			_action.disabled = GameManager.level() < int(item.lvl) or GameManager.diamonds() < dia
			if GameManager.diamonds() < dia:
				lines.append("Faltam %d diamantes" % (dia - GameManager.diamonds()))
		else:
			var price := ShopCatalog.price_of(item)
			var off := ShopCatalog.discount_of(item.id)
			_action.text = "Comprar por %d moedas" % price
			_action.disabled = GameManager.level() < int(item.lvl) or GameManager.coins() < price
			if off > 0:
				lines.append("De %d por %d (-%d%%)" % [item.price, price, off])
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
	if item.get("pass", false) and not Progression.owns(_selected):
		_tab = "passe"
		_selected = ""
		_refresh()
		return
	if Progression.owns(_selected) and not item.get("consumable", false):
		progression.equip(_selected)
	else:
		var err := progression.buy(_selected)
		if err != "":
			GameManager.show_toast(err)
		elif item.has("look") or item.has("kart"):
			progression.equip(_selected)
	_refresh()


func _row(text: String, sub: String, col := UITheme.CARD_2) -> void:
	var p := PanelContainer.new()
	var sb := UITheme.card(col if col != Color("fff8e7") else UITheme.CARD_2, 12)
	sb.shadow_size = 0
	p.add_theme_stylebox_override("panel", sb)
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

func _section(t: String, _col := Color.WHITE) -> void:
	var l := UITheme.title_label(t, 26, UITheme.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_content.add_child(l)


func _grid_of(ids: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = _grid_cols()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_content.add_child(grid)
	for id in ids:
		var it := ShopCatalog.get_item(id)
		if not it.is_empty():
			grid.add_child(_card(it, Progression.owns(id), true))


## Destaques: só o essencial (pacote de boas-vindas, passe, em alta e karts do passe).
func _build_featured() -> void:
	if not StoreOffers.starter_bought():
		_content.add_child(_starter_banner())
	var pb := LobbyPassCard.new()
	pb.custom_minimum_size = Vector2(0, 300)
	pb.pressed.connect(func():
		_tab = "passe"
		_refresh())
	_content.add_child(pb)
	_section("Em alta")
	_grid_of(["skin_princesa", "skin_tigre", "aura_dourada", "emo_backflip", "skin_rock", "emo_dance"])
	_section("Karts com design · só no Passe")
	_grid_of(["kart_turbo", "kart_foguete", "kart_campeao", "kart_neon"])


func _starter_banner() -> Control:
	var st: Dictionary = StoreOffers.STARTER
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 170)
	for k in ["normal", "hover", "pressed", "focus"]:
		var sb := UITheme.card(Color("fff7ed"), 16, Color("fdba74"))
		sb.shadow_size = 0
		b.add_theme_stylebox_override(k, sb)
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
	var t := _label("Pacote de boas-vindas · só 1 vez", 24, UITheme.INK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var d := _label("Skin lendária Cavaleiro Dourado + %d diamantes + %d moedas" % [int(st.diamonds), int(st.coins)], 19, UITheme.INK_2)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var pr := _label(Billing.price_of(str(st.id)), 32, Color("ea580c"))
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
	var t := UITheme.title_label("Passe do Recreio", 34, UITheme.INK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(t)
	var sub := _label("%s  ·  acaba em %d dia(s)  ·  nível %d de %d" % [RecessPass.season_name(), RecessPass.days_left(), RecessPass.tier(), RecessPass.TIERS], 19, UITheme.INK_2)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(sub)
	# barra de progresso do nível
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = RecessPass.tier_progress()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_stylebox_override("background", UITheme.box(Color("ede9fe"), 6))
	bar.add_theme_stylebox_override("fill", UITheme.box(UITheme.PASS_A, 6))
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
		UITheme.style_button(buy, UITheme.PASS_A)
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
			# mostra o prêmio na vitrine do lado (sem abrir outra tela)
			_selected = str(r.item)
			_update_preview()
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
