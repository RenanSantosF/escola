class_name AgePicker
extends CenterContainer
## Pergunta a idade real da criança (primeiro acesso ou Configurações).
## Ela define o nível inicial das atividades da aula.

signal confirmed(age: int)

var _age := 9
var _label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	_age = Learning.age() if Learning.has_age() else 9
	var panel := PanelContainer.new()
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(UITheme.title_label("Quantos anos você tem?", 38))
	var info := Label.new()
	info.text = "Informe sua idade de verdade: assim as atividades da aula\nficam na medida certa — nem fáceis, nem difíceis demais.\nO jogo também se ajusta sozinho conforme você joga."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 22)
	v.add_child(info)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 20)
	v.add_child(h)
	var minus := UITheme.make_button("−", func(): _change(-1), 90)
	var plus := UITheme.make_button("+", func(): _change(1), 90)
	_label = UITheme.title_label("", 54, UITheme.BLUE)
	_label.custom_minimum_size = Vector2(260, 0)
	h.add_child(minus)
	h.add_child(_label)
	h.add_child(plus)
	_change(0)
	v.add_child(UITheme.make_button("Confirmar", func():
		Learning.set_age(_age)
		SaveManager.save_game()
		confirmed.emit(_age), 320))


func _change(d: int) -> void:
	_age = clampi(_age + d, Learning.MIN_AGE, Learning.MAX_AGE)
	_label.text = "%d anos" % _age + ("+" if _age == Learning.MAX_AGE else "")
