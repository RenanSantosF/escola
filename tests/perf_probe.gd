extends Node
## Mede custo de CPU por quadro (process + physics) em diferentes fases.
## Uso: godot --headless --path . res://tests/perf_probe.tscn

func _ready() -> void:
	var q := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			q = int(a.substr(10))
	Settings.set_value("quality", q, false)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null or main.school_day == null:
		await get_tree().process_frame
	main._start_game()
	await _measure("chegada", 60)
	await _measure("chegada2", 180)
	main.school_day._start_recess()
	await _measure("recreio", 300)
	print("NPCs ativos: %d / %d" % [main.npcs.npcs.filter(func(n): return n.active).size(), main.npcs.npcs.size()])
	get_tree().quit()


func _measure(label: String, frames: int) -> void:
	var proc := 0.0
	var phys := 0.0
	for i in frames:
		await get_tree().process_frame
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	print("%-10s process=%.2f ms  physics=%.2f ms (média por quadro)" % [label, proc / frames * 1000.0, phys / frames * 1000.0])
