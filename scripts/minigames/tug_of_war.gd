extends Minigame
## Cabo de guerra no gramado do Parque do Morro: seu time (você + 3 colegas)
## contra outro time. TOQUE RÁPIDO no botão amarelo para puxar; acertar no
## "PUXA!" (quando a barra enche) vale o dobro. Puxe a fita até a sua marca!

const CENTER := Vector3(12, 0.05, -88)
const WIN_OFFSET := 2.2
const TIME := 35.0

var team_a: Array[NPC] = []  # do jogador
var team_b: Array[NPC] = []
var offset := 0.0  # negativo = puxando para o nosso lado
var _beat := 0.0
var _their := 0.0
var _rope: MeshInstance3D
var _flag: MeshInstance3D
var _root: Node3D


func begin() -> void:
	var cands: Array[NPC] = []
	for n in npcs.classmates + npcs.others:
		if n.active and n.role == "student" and n.activity != "minigame" and not n.talking_to_player:
			cands.append(n)
	for n in cands:
		if team_a.size() < 3:
			team_a.append(n)
		elif team_b.size() < 4:
			team_b.append(n)
	take_npcs(team_a + team_b)
	_root = Node3D.new()
	world.add_child(_root)
	# marcas no chão
	var md := MeshData.new()
	for sx: float in [-1.0, 1.0]:
		md.cur_color = Color("2f8be0") if sx < 0 else Color("e04a3a")
		md.add_box(Transform3D(Basis(), CENTER + Vector3(sx * WIN_OFFSET, 0.01, 0)), Vector3(0.12, 0.02, 2.2))
	md.cur_color = Color.WHITE
	md.add_box(Transform3D(Basis(), CENTER + Vector3(0, 0.01, 0)), Vector3(0.08, 0.02, 2.2))
	var marks := MeshInstance3D.new()
	marks.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	_root.add_child(marks)
	var rmd := MeshData.new()
	rmd.cur_color = Color("c9a77a")
	rmd.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), 0.035, 0.035, 9.0, 8)
	_rope = MeshInstance3D.new()
	_rope.mesh = rmd.build_mesh(SchoolMaterials.get_mat("plain"))
	_root.add_child(_rope)
	var fmd := MeshData.new()
	fmd.cur_color = Color("ffcf3f")
	fmd.add_box(Transform3D(Basis(), Vector3(0, -0.15, 0)), Vector3(0.05, 0.3, 0.25))
	_flag = MeshInstance3D.new()
	_flag.mesh = fmd.build_mesh(SchoolMaterials.get_mat("plain"))
	_root.add_child(_flag)
	player.force_stand()
	player.movement_locked = true
	time_left = TIME
	_place_people()
	if player.camera_rig:
		player.camera_rig.set_override(Transform3D(Basis(), CENTER + Vector3(0, 3.4, 7.5)).looking_at(CENTER + Vector3(0, 0.6, 0), Vector3.UP))
	countdown(3.0)
	super.begin()


func _place_people() -> void:
	var rope_y := 0.95
	var c := CENTER + Vector3(offset, 0, 0)
	_rope.global_position = c + Vector3(0, rope_y, 0)
	_flag.global_position = c + Vector3(0, rope_y, 0)
	player.global_position = c + Vector3(-1.4, 0, 0)
	player.yaw = PI * 0.5
	for i in team_a.size():
		team_a[i].global_position = c + Vector3(-2.2 - i * 0.8, 0, 0.12 * (1 - 2 * (i % 2)))
		team_a[i].yaw = PI * 0.5
	for i in team_b.size():
		team_b[i].global_position = c + Vector3(1.4 + i * 0.8, 0, 0.12 * (1 - 2 * (i % 2)))
		team_b[i].yaw = -PI * 0.5


func play_label() -> String:
	return "PUXA!"


func interact_label() -> String:
	return "Sair"


func on_interact() -> bool:
	_finish()
	return true


func on_play() -> bool:
	if _countdown > 0.0 or not running:
		return true
	# no "PUXA!" (barra quase cheia) vale o dobro
	var on_beat := fposmod(_beat, 1.0) > 0.78
	offset -= 0.09 if on_beat else 0.045
	player.visual.play("push")
	if on_beat:
		AudioManager.play_ui("ui_confirm", -10.0)
		for n in team_a:
			n.visual.play("push")
	return true


func tick(delta: float) -> void:
	if not running:
		return
	_place_people()
	if counting(delta):
		return
	time_left -= delta
	_beat += delta / 0.55
	hud.set_meter(fposmod(_beat, 1.0))
	# força do outro time: constante + arrancadas
	_their = 0.42 + 0.25 * maxf(sin(Time.get_ticks_msec() * 0.0021), 0.0)
	offset += _their * delta * 0.55
	# nosso time ajuda um pouco sozinho
	offset -= 0.12 * delta
	if randf() < delta * 1.5:
		for n in team_b:
			n.visual.play("push")
	hud.set_minigame_text("Cabo de guerra  ·  %s  ·  %d s  ·  toque RÁPIDO e no PUXA!" % ["Ganhando!" if offset < 0 else "Perdendo!", int(maxf(time_left, 0.0))])
	if offset <= -WIN_OFFSET or offset >= WIN_OFFSET or time_left <= 0.0:
		_finish()


func _finish() -> void:
	if not running:
		return
	var won := 1 if offset < -0.2 else (-1 if offset > 0.2 else 0)
	for n in (team_a if won > 0 else team_b):
		n.visual.play("celebrate")
	end_game(won, "Cabo de guerra: " + ("seu time venceu!" if won > 0 else ("empate!" if won == 0 else "o outro time venceu")), 6 if won > 0 else 3, 14 if won > 0 else 6)


func cleanup() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	super.cleanup()
