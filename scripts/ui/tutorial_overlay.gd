class_name TutorialOverlay
extends Control
## Tutorial de primeira vez de uma brincadeira: título, passos numerados com
## o botão usado em cada um e "Entendi, vamos!". Aparece só uma vez por jogo
## (pode ser revisto na aba Brincadeiras da mochila).

signal done

const BUTTON_COLORS := {
	"Amarelo": Color("ffcf3f"), "Azul": Color("8fd3ff"), "Verde": Color("9be37a"),
	"Laranja": Color("ff9f6b"), "Joystick": Color("ffffff"),
}


## Versão das regras: quando a brincadeira muda, o tutorial aparece de novo.
const VERSION := {"gude": 2, "amarelinha": 2, "aviao": 2, "corrida": 2, "corda": 2, "pontaria": 2, "basquete": 2, "cabo": 2, "guerra": 2, "esconde": 2}


static func _key(gid: String) -> String:
	var v := int(VERSION.get(gid, 1))
	return gid if v <= 1 else "%s_v%d" % [gid, v]


static func seen(gid: String) -> bool:
	return bool(SaveManager.section("tutorials").get(_key(gid), false))


static func mark_seen(gid: String) -> void:
	SaveManager.section("tutorials")[_key(gid)] = true


## steps: [[botão, texto], ...] — botão: "Amarelo", "Azul", "Verde", "Laranja", "Joystick" ou "".
func setup(title: String, color: Color, steps: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.12, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var panel := PanelContainer.new()
	var sb := UITheme.box(Color("fff8e7"), 28, color, 6, 8)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 20
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(760, 0)
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := UITheme.title_label("Como jogar: " + title, 40, color.darkened(0.35))
	v.add_child(t)
	var i := 1
	for st in steps:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var num := PanelContainer.new()
		num.add_theme_stylebox_override("panel", UITheme.box(color, 24, UITheme.DARK, 3, 0))
		num.custom_minimum_size = Vector2(48, 48)
		var nl := UITheme.title_label(str(i), 26, UITheme.DARK)
		num.add_child(nl)
		row.add_child(num)
		var txt := Label.new()
		txt.text = str(st[1])
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_theme_font_size_override("font_size", 25)
		txt.add_theme_color_override("font_color", UITheme.DARK)
		row.add_child(txt)
		var btn_name: String = st[0]
		if btn_name != "":
			var chip := PanelContainer.new()
			var bc: Color = BUTTON_COLORS.get(btn_name, Color.WHITE)
			chip.add_theme_stylebox_override("panel", UITheme.box(bc, 22, UITheme.DARK, 3, 0))
			var cl := Label.new()
			cl.text = "  " + ("Analógico" if btn_name == "Joystick" else "Botão " + btn_name.to_lower()) + "  "
			cl.add_theme_font_override("font", UITheme.bold_font())
			cl.add_theme_font_size_override("font_size", 19)
			cl.add_theme_color_override("font_color", UITheme.DARK)
			chip.add_child(cl)
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(chip)
		v.add_child(row)
		i += 1
	var go := UITheme.make_button("Entendi, vamos!", func():
		AudioManager.play_ui("ui_confirm")
		done.emit()
		queue_free(), 340)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.add_theme_font_size_override("font_size", 30)
	v.add_child(go)
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = Vector2(380, 200)
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3)
