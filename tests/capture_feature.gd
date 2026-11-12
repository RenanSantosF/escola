extends Node
## Gráfico de recursos da Play Store (1024x500): cena do jogo + logo + crianças.
## Uso: ... --resolution 1024x500 res://tests/capture_feature.tscn -- --out=DIR --bg=IMG --kids=IMG

var out_dir := "user://"
var bg_path := ""
var kids_path := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--bg="):
			bg_path = a.substr(5)
		elif a.begins_with("--kids="):
			kids_path = a.substr(7)
	print("inicio")
	await get_tree().create_timer(2.5).timeout
	print("splash ok")
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(Image.load_from_file(bg_path))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	# faixa azul suave à esquerda para o nome aparecer bem
	var grad := Gradient.new()
	grad.set_color(0, Color(0.16, 0.38, 0.85, 0.92))
	grad.set_color(1, Color(0.16, 0.38, 0.85, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.4, 0)
	gt.fill_to = Vector2(0.72, 0)
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var logo := LobbyLogo.new()
	logo.title = "RECESS"
	logo.ribbon = "CLUB"
	logo.font_size = 120
	logo.position = Vector2(40, 90)
	logo.size = Vector2(640, 250)
	root.add_child(logo)
	var sub := Label.new()
	sub.text = "Clube do Recreio"
	sub.add_theme_font_override("font", UITheme.bold_font())
	sub.add_theme_font_size_override("font_size", 56)
	sub.add_theme_color_override("font_color", Color.WHITE)
	sub.add_theme_color_override("font_outline_color", Color("1b2d4f"))
	sub.add_theme_constant_override("outline_size", 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(40, 380)
	sub.size = Vector2(640, 70)
	root.add_child(sub)
	var tag := Label.new()
	tag.text = "Brinque online com a turma!"
	tag.add_theme_font_override("font", UITheme.bold_font())
	tag.add_theme_font_size_override("font_size", 34)
	tag.add_theme_color_override("font_color", Color("ffe27f"))
	tag.add_theme_color_override("font_outline_color", Color("1b2d4f"))
	tag.add_theme_constant_override("outline_size", 8)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.position = Vector2(40, 465)
	tag.size = Vector2(640, 50)
	root.add_child(tag)
	if kids_path != "":
		var kids := TextureRect.new()
		kids.texture = ImageTexture.create_from_image(Image.load_from_file(kids_path))
		kids.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		kids.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		kids.position = Vector2(820, 150)
		kids.size = Vector2(400, 420)
		root.add_child(kids)
	print("montado")
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("grafico_recursos_1024x500.png"))
	get_tree().quit()
