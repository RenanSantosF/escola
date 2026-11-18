class_name DailyGiftPanel
extends Control
## Janela do PRESENTE DO DIA (aparece ao entrar no recreio uma vez por dia).

signal closed


static func show_if_available(parent: Control) -> DailyGiftPanel:
	if DailyGift.available_day() == 0:
		return null
	var p := DailyGiftPanel.new()
	parent.add_child(p)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()
	z_index = 40
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.18, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var panel := PanelContainer.new()
	var sb := UITheme.box(Color("fffaf0"), 28, Color("ffcf3f"), 6, 10)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(UITheme.title_label("Presente do dia!", 42, Color("e67e22")))
	var day := DailyGift.available_day()
	var sub := Label.new()
	sub.text = "Entre todo dia para ganhar presentes cada vez melhores. Dia %d de 7!" % day
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", UITheme.DARK)
	v.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for i in DailyGift.REWARDS.size():
		var cell := PanelContainer.new()
		var past := i + 1 < day
		var now := i + 1 == day
		var col := Color("dfe6ee") if past else (Color("ffe08a") if now else Color("eef3fa"))
		cell.add_theme_stylebox_override("panel", UITheme.box(col, 14, Color("e67e22") if now else Color(0, 0, 0, 0), 4 if now else 0, 3))
		cell.custom_minimum_size = Vector2(108, 120)
		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(cv)
		var dl := Label.new()
		dl.text = "Dia %d" % (i + 1)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.add_theme_font_override("font", UITheme.bold_font())
		dl.add_theme_color_override("font_color", UITheme.DARK)
		cv.add_child(dl)
		var ic := CenterContainer.new()
		var r: Dictionary = DailyGift.REWARDS[i]
		if r.has("diamonds"):
			var di := DiamondIcon.new()
			di.radius = 20
			ic.add_child(di)
		elif r.has("packs"):
			var pk := _PackIcon.new()
			pk.custom_minimum_size = Vector2(44, 44)
			ic.add_child(pk)
		else:
			var co := CoinIcon.new()
			co.radius = 18
			ic.add_child(co)
		cv.add_child(ic)
		var rl := Label.new()
		rl.text = "PEGO" if past else DailyGift.reward_text(i)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.custom_minimum_size = Vector2(100, 0)
		rl.add_theme_font_size_override("font_size", 14)
		rl.add_theme_color_override("font_color", UITheme.DARK)
		cv.add_child(rl)
		row.add_child(cell)
	var btn := UITheme.make_button("Pegar presente!", func():
		var got := DailyGift.claim()
		if got != "":
			GameManager.show_toast("Presente do dia: %s!" % got)
			AudioManager.play_ui("celebrate", -4.0)
		closed.emit()
		queue_free(), 320)
	var bc := CenterContainer.new()
	bc.add_child(btn)
	v.add_child(bc)


## Pacotinho de figurinhas (duas cartinhas com estrela).
class _PackIcon extends Control:
	func _draw() -> void:
		if size.x < 4.0:
			return
		var w := size.x * 0.55
		var h := size.y * 0.75
		draw_rect(Rect2(size.x * 0.12, size.y * 0.18, w, h), Color("2f80ed"))
		draw_rect(Rect2(size.x * 0.32, size.y * 0.08, w, h), Color("ff6fae"))
		draw_rect(Rect2(size.x * 0.32, size.y * 0.08, w, h), Color.WHITE, false, 2.0)
		var c := Vector2(size.x * 0.32 + w * 0.5, size.y * 0.08 + h * 0.5)
		var pts := PackedVector2Array()
		for k in 10:
			var rr := w * (0.34 if k % 2 == 0 else 0.15)
			pts.append(c + Vector2.from_angle(-PI * 0.5 + k * TAU / 10.0) * rr)
		draw_colored_polygon(pts, Color("ffd23f"))
