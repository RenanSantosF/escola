extends Node
## Corrida de kart de ponta a ponta: o "jogador" é pilotado por uma IA simples
## (segue o traçado) e o probe tira fotos. Uso: --out=DIR [--shots]
var out_dir := ""
var kart_id := ""
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		if a.begins_with("--kart="):
			kart_id = a.substr(7)
	NPCManager.STUDENT_BOTS = false
	MinigameManager.FREE_PLAY = true
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null:
		await get_tree().process_frame
	for i in 5:
		await get_tree().process_frame
	main._start_game()
	for i in 5:
		await get_tree().process_frame
	while not GameManager.is_playing():
		await get_tree().process_frame
	if kart_id != "":
		main.progression.grant(kart_id)
		main.progression.equip(kart_id)
	var sd: SchoolDay = main.school_day
	sd._start_recess()
	await get_tree().process_frame
	var mm: MinigameManager = main.minigames
	var ok := mm.start_local("kart", {})
	print("KART start=", ok, " total=", KartTrack.length())
	var kr = mm.active
	Engine.time_scale = 2.0
	var t := 0.0
	var shots := [2.0, 8.0, 18.0, 30.0, 44.0, 70.0, 110.0]
	var si := 0
	var maxv := 0.0
	var walls := 0
	var lastw := 0.0
	while mm.active == kr and t < 270.0:
		await get_tree().process_frame
		if mm.active != kr or not is_instance_valid(kr):
			break
		var dt := get_process_delta_time()
		t += dt * Engine.time_scale
		# piloto automático: segura o verde nas curvas fortes
		var c := KartTrack.curve_at(kr.me.s + 6.0)
		if absf(c) > 0.04 and not kr._drift and kr._countdown <= 0.0:
			kr.on_interact()
		elif absf(c) < 0.015 and kr._drift:
			kr.on_interact_release()
		if str(kr.me.item) != "" and kr._countdown <= 0.0 and absf(c) < 0.01:
			kr.on_play()
		maxv = maxf(maxv, kr.me.v)
		if kr.me.wall_cd > lastw + 0.2:
			walls += 1
		lastw = kr.me.wall_cd
		if out_dir != "" and si < shots.size() and t >= shots[si]:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("kart_%d.png" % si))
			var cam3 := get_viewport().get_camera_3d()
			print("CAM ", cam3.global_position, " kart=", (kr.me.kart as Node3D).global_position, " player=", GameManager.player.global_position, " cam=", cam3.name)
			si += 1
		if mm.active != kr:
			break
		if int(t * 10) % 50 == 0 and t > 100.0:
			for r in kr.racers:
				print("  racer ", r.name, " lap=", r.lap, " s=", int(r.s), " v=", snappedf(r.v, 0.1), " done=", r.done, " spins=", r.n_spin, " walls=", r.n_wall, " item=", r.item)
		if int(t * 10) % 50 == 0:
			print("t=%.1f lap=%d s=%.0f d=%.1f v=%.1f place=%d" % [t, kr.me.lap, kr.me.s, kr.me.d, kr.me.v, kr._place_of(kr.me)])
	for r in (kr.racers if is_instance_valid(kr) else []):
		print("racer ", r.name, " lap=", r.lap, " s=", int(r.s), " done=", r.done, " time=", r.time, " spins=", r.n_spin, " walls=", r.n_wall)
	print("KART_END t=%.1f maxv=%.1f walls=%d active=%s" % [t, maxv, walls, mm.active])
	get_tree().quit()
