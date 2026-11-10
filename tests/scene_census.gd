extends Node
## Conta os objetos desenháveis da cena por tipo/origem (diagnóstico de desempenho).


func _ready() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null:
		await get_tree().process_frame
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			Settings.set_value("quality", int(a.substr(10)), false)
	main._start_game()
	GameManager.player.global_position = Vector3(0, 0.05, -2)
	for i in 60:
		await get_tree().process_frame
	var counts := {}
	var shadows := {}
	_walk(main, counts, shadows)
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	for k in keys.slice(0, 30):
		print("%5d  sombra:%4d  %s" % [counts[k], shadows.get(k, 0), k])
	print("--- triângulos por objeto")
	var tris := []
	_tris(main, tris)
	tris.sort_custom(func(a, b): return a[0] > b[0])
	var total := 0
	for t in tris:
		total += t[0]
	print("TOTAL ", total)
	for t in tris.slice(0, 22):
		print("%7d  %s" % [t[0], t[1]])
	get_tree().quit()


func _tris(n: Node, out: Array) -> void:
	var cnt := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var m: Mesh = (n as MeshInstance3D).mesh
		for si in m.get_surface_count():
			var arr := m.surface_get_arrays(si)
			if arr[Mesh.ARRAY_INDEX] != null:
				cnt += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		var m2: Mesh = mm.mesh
		var per := 0
		for si in m2.get_surface_count():
			var arr2 := m2.surface_get_arrays(si)
			if arr2[Mesh.ARRAY_INDEX] != null:
				per += (arr2[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		cnt = per * mm.instance_count
	if cnt > 0:
		out.append([cnt, str(n.get_path()).replace("/root/SceneCensus/Main/", "")])
	for c in n.get_children():
		_tris(c, out)


func _walk(n: Node, counts: Dictionary, shadows: Dictionary) -> void:
	if n is GeometryInstance3D and (n as Node3D).is_visible_in_tree():
		var gi := n as GeometryInstance3D
		var cam := get_viewport().get_camera_3d()
		if gi.visibility_range_end > 0.0 and cam and cam.global_position.distance_to(gi.global_position) > gi.visibility_range_end + 5.0:
			return
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
