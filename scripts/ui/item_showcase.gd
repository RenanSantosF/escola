class_name ItemShowcase
extends Control
## Vitrine em TELA CHEIA de um item (loja, guarda-roupa e passe):
## o personagem GRANDE usando o item (gira sozinho, aproxima no que mudou),
## botão ANTES / DEPOIS para comparar, emojis animados tocando sem parar e
## efeitos (auras) ligados. Do lado: raridade, nome, descrição, preço e
## comprar / equipar.

signal done

var item_id := ""
var menu: Node  # ProfileMenu
var _stage: CharacterStage
var _icon: ItemIcon
var _before := false
var _cmp_btn: Button
var _act_btn: Button
var _info: VBoxContainer
var _emote_t := 0.0


static func open(parent: Control, m: Node, id: String) -> ItemShowcase:
	var s := ItemShowcase.new()
	s.menu = m
	s.item_id = id
	parent.add_child(s)
	return s


func _item() -> Dictionary:
	return ShopCatalog.get_item(item_id)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()
	z_index = 30
	var it := _item()
	var rar := ShopCatalog.rarity_of(it)
	var rcol: Color = ShopCatalog.RARITY[rar][1]
	var bg := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color("0f1640"))
	g.set_color(1, rcol.darkened(0.45))
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.3, 0.5)
	gt.fill_to = Vector2(1.1, 1.1)
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_right = -20
	root.offset_top = 16
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 20)
	add_child(root)
	# palco grande (ou o ícone gigante para o que não se veste)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.4
	root.add_child(left)
	if it.has("look") or it.cat == "emote":
		_stage = CharacterStage.new()
		_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_stage.auto_emotes = false
		_stage.podium_color = rcol
		_stage.base_dist = 3.9
		_stage.zoom_max = 5.0
		left.add_child(_stage)
		_stage._dist = 3.9
		_stage._target_dist = 3.9
		var hint := Label.new()
		hint.text = "Arraste para girar · pinça para aproximar"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 16)
		hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		left.add_child(hint)
	elif it.has("kart"):
		var ks := KartStage.new()
		ks.item_id = item_id
		ks.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left.add_child(ks)
	else:
		_icon = ItemIcon.new(it)
		_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left.add_child(_icon)
	# informações
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	var sb := UITheme.box(Color(1, 1, 1, 0.96), 26, rcol, 5, 8)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	right.add_theme_stylebox_override("panel", sb)
	root.add_child(right)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 12)
	right.add_child(_info)
	_build_info()
	if _stage:
		_show(false, true)


func _build_info() -> void:
	for c in _info.get_children():
		c.queue_free()
	var it := _item()
	var rar := ShopCatalog.rarity_of(it)
	var rcol: Color = ShopCatalog.RARITY[rar][1]
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", UITheme.box(rcol, 14, Color(0, 0, 0, 0), 0, 0))
	var bl := UITheme.title_label(ShopCatalog.RARITY[rar][0].to_upper() + ("  ·  EXCLUSIVO DO PASSE" if it.get("pass", false) else ""), 20, Color.WHITE)
	band.add_child(bl)
	_info.add_child(band)
	var nm := UITheme.title_label(str(it.get("name", "")), 40, UITheme.DARK)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_child(nm)
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 6)
	var cat_name := ""
	for c in ShopCatalog.CATEGORIES:
		if c[0] == it.cat:
			cat_name = c[1]
	tags.add_child(_tag(cat_name, Color("5b6b8c")))
	if it.get("animated", false):
		tags.add_child(_tag("ANIMADO", Color("ff4d6d")))
	if it.cat == "aura" or (it.get("look", {}) as Dictionary).has("aura"):
		tags.add_child(_tag("COM EFEITO", Color("9b59ff")))
	_info.add_child(tags)
	var d := Label.new()
	d.text = str(it.get("desc", "")) if it.has("desc") else _auto_desc(it)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 22)
	d.add_theme_color_override("font_color", Color("3b4256"))
	_info.add_child(d)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.add_child(spacer)
	# antes/depois (só para o que se veste)
	if _stage and it.has("look"):
		_cmp_btn = UITheme.make_button("Ver ANTES", func():
			_before = not _before
			_cmp_btn.text = "Ver DEPOIS" if _before else "Ver ANTES"
			_show(_before, false), 330)
		_info.add_child(_cmp_btn)
	# preço e ação
	var owned := Progression.owns(item_id)
	var status := Label.new()
	status.add_theme_font_override("font", UITheme.bold_font())
	status.add_theme_font_size_override("font_size", 24)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_child(status)
	_act_btn = UITheme.make_button("", _on_act, 330)
	_info.add_child(_act_btn)
	if owned and not it.get("consumable", false):
		var eq: bool = menu.progression.is_equipped(item_id) if menu and menu.progression else false
		status.text = "Este item é seu!"
		status.add_theme_color_override("font_color", UITheme.GREEN)
		var usable: bool = it.has("look") or it.has("vehicle") or it.has("kart")
		_act_btn.text = ("Usando" if eq else ("Usar" if usable else "Já é seu"))
		_act_btn.disabled = eq or not usable
	elif it.get("pass", false):
		var t := _pass_tier(item_id)
		status.text = "Ganhe no PASSE DO RECREIO" + (" (nível %d)" % t if t > 0 else "")
		status.add_theme_color_override("font_color", Color("9b59ff"))
		_act_btn.text = "Ver o Passe"
	elif ShopCatalog.diamonds_of(it) > 0:
		var dia := ShopCatalog.diamonds_of(it)
		status.text = "%d diamantes" % dia
		status.add_theme_color_override("font_color", Color("1f6fb0"))
		if GameManager.diamonds() >= dia:
			_act_btn.text = "Comprar com diamantes"
		else:
			status.text += "  (você tem %d)" % GameManager.diamonds()
			_act_btn.text = "Conseguir diamantes"
	else:
		var price := ShopCatalog.price_of(it)
		var lvl_ok := GameManager.level() >= int(it.get("lvl", 1))
		status.text = ("%d moedas" % price) if lvl_ok else "Libera no nível %d" % int(it.lvl)
		if lvl_ok and GameManager.coins() < price:
			status.text += "  (faltam %d)" % (price - GameManager.coins())
		status.add_theme_color_override("font_color", UITheme.DARK)
		_act_btn.text = "Comprar"
		_act_btn.disabled = not lvl_ok or GameManager.coins() < price
		if it.get("animated", false) and RecessPass.premium_items().has(item_id):
			var hint := Label.new()
			hint.text = "Dica: no Passe do Recreio este emoji sai bem mais barato!"
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.add_theme_font_size_override("font_size", 17)
			hint.add_theme_color_override("font_color", Color("9b59ff"))
			_info.add_child(hint)
	var close := UITheme.make_button("Voltar", func():
		done.emit()
		queue_free(), 330)
	close.add_theme_stylebox_override("normal", UITheme.box(Color("e05a4a"), 18, Color("a33a2c"), 0, 6))
	_info.add_child(close)


func _auto_desc(it: Dictionary) -> String:
	match str(it.cat):
		"camiseta": return "Camiseta para usar na escola e no recreio."
		"calca": return "Calça ou bermuda nova."
		"calcado": return "Tênis novinho para correr no recreio."
		"mochila": return "Mochila para carregar seu material (e estilo)."
		"bone": return "Boné que todo mundo vai ver."
		"penteado": return "Mude o visual do cabelo."
		"decoracao": return "Enfeite para a sua carteira da sala."
		"veiculo": return "Ande pelo pátio bem mais rápido!"
		"kart": return "Pintura do seu kart na Corrida de Kart (os colegas online também veem)."
	return ""


static func _pass_tier(id: String) -> int:
	for t in RecessPass.PREMIUM.keys():
		if str((RecessPass.PREMIUM[t] as Dictionary).get("item", "")) == id:
			return t
	return 0


func _tag(t: String, c: Color) -> Control:
	var p := PanelContainer.new()
	var sb := UITheme.box(c, 10, Color(0, 0, 0, 0), 0, 0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", UITheme.bold_font())
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color.WHITE)
	p.add_child(l)
	return p


func _show(before: bool, first: bool) -> void:
	var it := _item()
	var extra := [] if before or not it.has("look") else [item_id]
	_stage.set_appearance(Progression.appearance_with(extra), not before)
	var cat := str(it.cat)
	if cat in ["bone", "penteado", "acessorio"]:
		_stage.focus("head")
	else:
		_stage._target_dist = 3.9 if cat != "emote" else 4.6
		_stage._target_look_y = 1.05 if cat != "emote" else 1.3
	if first:
		if cat == "calcado":
			_stage.play("hop_two")
		elif cat in ["skin", "camiseta", "aura"]:
			_stage.play("celebrate")
		_emote_t = 0.6


func _process(delta: float) -> void:
	var it := _item()
	if _stage and it.cat == "emote":
		# o emoji fica tocando sem parar na vitrine
		_emote_t -= delta
		if _emote_t <= 0.0 and _stage.character:
			_emote_t = 3.0
			var e := str(it.get("emote", "wave"))
			_stage.play(e)
			EmoteFX.spawn(_stage.character, e)


func _on_act() -> void:
	var it := _item()
	if it.get("pass", false) and not Progression.owns(item_id):
		done.emit()
		queue_free()
		if menu:
			menu.open_tab("passe")
		return
	if ShopCatalog.diamonds_of(it) > 0 and not Progression.owns(item_id) and GameManager.diamonds() < ShopCatalog.diamonds_of(it):
		done.emit()
		queue_free()
		if menu:
			menu.open_tab("loja")
			menu._cat = "diamantes"
			menu._refresh()
		return
	if menu:
		menu._selected = item_id
		menu._on_action()
	_build_info()
	if _stage:
		_show(false, false)
