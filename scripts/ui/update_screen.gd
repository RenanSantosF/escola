class_name UpdateScreen
extends CanvasLayer
## Tela "Atualize o jogo!": aparece quando a versão do app é mais velha que a
## versão mínima do servidor (definida no painel). Cobre tudo e não fecha:
## o único caminho é atualizar pela Play Store.

const PACKAGE := "com.recreio.minhavidanaescola"

var store_url := ""


static func show_required(store: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root.has_node("UpdateScreen"):
		return
	var s := UpdateScreen.new()
	s.name = "UpdateScreen"
	s.store_url = store
	tree.root.add_child(s)


func _ready() -> void:
	layer = 120  # por cima de tudo (inclusive da abertura e do menu)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color("3d6fd8")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP  # segura todos os toques
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.box(Color("fffaf0"), 28, Color("ffd23f"), 6, 8))
	card.custom_minimum_size = Vector2(620, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	card.add_child(v)
	v.add_child(UITheme.title_label("Atualize o jogo!", 52, Color("e8543a")))
	var txt := Label.new()
	txt.text = "Saiu uma versão nova do Recess Club, cheia de novidades!\nAtualize na Play Store para continuar jogando com a turma."
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.add_theme_font_override("font", UITheme.bold_font())
	txt.add_theme_font_size_override("font_size", 26)
	txt.add_theme_color_override("font_color", UITheme.DARK)
	v.add_child(txt)
	var btn := UITheme.make_button("Atualizar agora", _open_store, 420)
	btn.custom_minimum_size = Vector2(420, 84)
	btn.add_theme_font_size_override("font_size", 34)
	btn.add_theme_font_override("font", UITheme.bold_font())
	btn.add_theme_stylebox_override("normal", UITheme.box(Color("22c55e"), 22, Color("15803d"), 0, 8))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(btn)
	# sem conexão com o jogo até atualizar (não fica tentando reconectar)
	NetworkManager.stop_for_update()


func _open_store() -> void:
	if OS.get_name() == "Android":
		OS.shell_open("market://details?id=" + PACKAGE)
	else:
		OS.shell_open(store_url if store_url != "" else "https://play.google.com/store/apps/details?id=" + PACKAGE)
