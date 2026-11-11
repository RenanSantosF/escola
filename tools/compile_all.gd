extends Node
## Compila todos os scripts do jogo e lista os que têm erro (rodar em headless):
## godot --headless --path . res://tools/compile_all.tscn
func _ready() -> void:
	var bad := 0
	for dir in ["res://scripts", "res://autoloads"]:
		bad += _scan(dir)
	print("COMPILE_DONE bad=", bad)
	get_tree().quit()


func _scan(d: String) -> int:
	var bad := 0
	var da := DirAccess.open(d)
	for f in da.get_files():
		if f.ends_with(".gd"):
			var sc = load(d + "/" + f)
			if sc == null or not (sc as GDScript).can_instantiate():
				print("BAD ", d + "/" + f)
				bad += 1
	for sub in da.get_directories():
		bad += _scan(d + "/" + sub)
	return bad
