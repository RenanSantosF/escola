class_name WhatsNew
extends Control
## "O QUE HÁ DE NOVO": aparece uma vez depois que o jogo é atualizado.

const VERSION := "2026-11-kart"
const ITEMS := [
	["Corrida de Kart", "Uma pista que dá a volta na escola, com viaduto por cima do portão! Derrape nas curvas e use o turbo."],
	["Montanha-russa gigante", "42 metros de altura, looping e saca-rolha. Entre na fila e experimente a visão em 1ª pessoa!"],
	["Passe do Recreio", "Jogue, complete os desafios da semana e libere skins, emojis animados, karts e diamantes."],
	["Loja nova", "Diamantes, skins com estampa, efeitos especiais e pinturas de kart. Toque num item para ver bem grande."],
	["Aulas diferentes", "Cada dia a turma muda de sala e tem aulas na informática, nos laboratórios, na quadra e na sala de vídeo."],
	["Mais brincadeiras", "Soltar pipa no alto do Morro, balanço de verdade, esconde-esconde com agachar e xadrez com os amigos."],
]

signal closed


static func show_if_new(parent: Control) -> WhatsNew:
	var prog: Dictionary = SaveManager.section("progress")
	if str(prog.get("news_seen", "")) == VERSION:
		return null
	if int(prog.get("days_completed", 0)) == 0:
		prog["news_seen"] = VERSION  # quem está começando agora já vê tudo novo
		return null
	var w := WhatsNew.new()
	parent.add_child(w)
	return w


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()
	z_index = 45
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.18, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var panel := PanelContainer.new()
	var sb := UITheme.box(Color("fffaf0"), 28, Color("9b59ff"), 6, 10)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(760, 0)
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UITheme.title_label("Novidades no Recess Club!", 38, Color("7b3fe0")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for it in ITEMS:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(350, 0)
		var t := Label.new()
		t.text = it[0]
		t.add_theme_font_override("font", UITheme.bold_font())
		t.add_theme_font_size_override("font_size", 22)
		t.add_theme_color_override("font_color", Color("e67e22"))
		box.add_child(t)
		var d := Label.new()
		d.text = it[1]
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 16)
		d.add_theme_color_override("font_color", UITheme.DARK)
		box.add_child(d)
		grid.add_child(box)
	var btn := UITheme.make_button("Vamos brincar!", func():
		SaveManager.section("progress")["news_seen"] = VERSION
		SaveManager.save_game()
		closed.emit()
		queue_free(), 300)
	var bc := CenterContainer.new()
	bc.add_child(btn)
	v.add_child(bc)
