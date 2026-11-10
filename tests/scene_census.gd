extends Node
## Conta os objetos desenháveis da cena por tipo/origem (diagnóstico de desempenho).


func _ready() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null:
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	var counts := {}
	var shadows := {}
	_walk(main, counts, shadows)
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	for k in keys.slice(0, 30):
		print("%5d  sombra:%4d  %s" % [counts[k], shadows.get(k, 0), k])
	get_tree().quit()


func _walk(n: Node, counts: Dictionary, shadows: Dictionary) -> void:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		var owner_name := _origin(n)
		var key := "%s / %s" % [n.get_class(), owner_name]
		counts[key] = counts.get(key, 0) + 1
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadows[key] = shadows.get(key, 0) + 1
	for c in n.get_children():
		_walk(c, counts, shadows)


func _origin(n: Node) -> String:
	var p := n.get_parent()
	var path := []
	while p and path.size() < 6:
		path.append(p.name)
		p = p.get_parent()
	path.reverse()
	# guarda os 2 primeiros níveis abaixo do mundo
	var s := "/".join(path)
	s = s.replace("root/SceneCensus/Main/", "")
	var parts := s.split("/")
	return "/".join(parts.slice(0, 2)) if parts.size() > 1 else s
