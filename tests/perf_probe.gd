extends Node
## Mede o custo por quadro em vários lugares da escola (qualidade Baixa):
## tempo de script (process/physics), chamadas de desenho, objetos e o pior
## quadro (travadinha). Uso: xvfb + --rendering-driver opengl3.

const SPOTS := [
	["patio", Vector3(0, 0.05, -2), 180.0],
	["sala5", Vector3(-11.2, 3.95, 29.0), -90.0],
	["corredor", Vector3(-30, 0.05, 36), -90.0],
	["quadra", Vector3(36, 0.05, -40), 180.0],
	["parque", Vector3(0, 0.05, -80), 180.0],
	["montanha", Vector3(47, 0.05, -78), 180.0],
	["entrada", Vector3(0, 0.05, 66), 180.0],
]


func _ready() -> void:
	var q := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			q = int(a.substr(10))
	Settings.set_value("quality", q, false)
	Settings.set_value("fps_limit_30", false, false)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null or main.school_day == null:
		await get_tree().process_frame
	for i in 5:
		await get_tree().process_frame
	main._start_game()
	for i in 60:
		await get_tree().process_frame
	var player: PlayerController = GameManager.player
	Engine.max_fps = 0
	var total_worst := 0.0
	for s in SPOTS:
		player.global_position = s[1]
		player.yaw = deg_to_rad(s[2])
		if player.camera_rig:
			player.camera_rig.yaw = player.yaw + PI
			player.camera_rig.snap_to_target()
		for i in 30:
			await get_tree().process_frame
		var proc := 0.0
		var phys := 0.0
		var worst := 0.0
		var dc := 0.0
		var obj := 0.0
		var n := 120
		var t_prev := Time.get_ticks_usec()
		for i in n:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			worst = maxf(worst, (now - t_prev) / 1000.0)
			t_prev = now
			proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			obj += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		total_worst = maxf(total_worst, worst)
		print("PERF %-9s process=%.2fms physics=%.2fms draw=%d obj=%d worst=%.1fms fps=%d" % [s[0], proc / n, phys / n, int(dc / n), int(obj / n), worst, Engine.get_frames_per_second()])
	print("PERF nodes=%d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	player.global_position = SPOTS[0][1]
	for sc in [1.0, 0.5]:
		get_viewport().scaling_3d_scale = sc
		for i in 30:
			await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		for i in 60:
			await get_tree().process_frame
		print("SCALE %.2f frame=%.1fms" % [sc, (Time.get_ticks_usec() - t0) / 60000.0])
	var counts := {}
	var stack: Array = [main.world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var c := n.get_class()
		if n is Label3D:
			c = "Label3D" + ("_semfim" if (n as Label3D).visibility_range_end <= 0.0 else "")
		elif n is MeshInstance3D:
			c = "Mesh" + ("_semfim" if (n as MeshInstance3D).visibility_range_end <= 0.0 else "")
		counts[c] = int(counts.get(c, 0)) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	for k in keys.slice(0, 14):
		print("NODES %s %d" % [k, counts[k]])
	get_tree().quit()
