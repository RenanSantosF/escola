extends Minigame
## Cabo de guerra no gramado do Parque do Morro: seu time (você + 3 colegas)
## contra outro time. TOQUE RÁPIDO no botão amarelo para puxar; acertar no
## "PUXA!" (quando a barra enche) vale o dobro. Puxe a fita até a sua marca!
## Online: cada jogador fica numa vaga do seu time (bots completam até 4);
## o anfitrião soma os puxões de todos e manda a posição da fita.

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
var net_role := ""
var my_team := "a"
var _slot := 0  # minha vaga no time
var _humans := {"a": 0, "b": 0}
var _pulls := {"a": 0.0, "b": 0.0}  # anfitrião: puxões recebidos
var _net_t := 0.0
var _state: Dictionary = {}
var _state_age := 0.0


func begin() -> void:
	var bots_a := 3
	var bots_b := 4
	if is_net():
		var teams: Dictionary = net.get("teams", {})
		my_team = str(teams.get(net.get("me", ""), "a"))
		net_role = "host" if str(net.get("host", "")) == str(net.get("me", "")) else "client"
		for id in net.get("players", []):
			var t := str(teams.get(id, "a"))
			if str(id) == str(net.get("me", "")):
				_slot = _humans[t]
			_humans[t] += 1
		var fill: bool = (net.get("opts", {}) as Dictionary).get("bots", true)
		bots_a = maxi(4 - _humans.a, 0) if fill else 0
		bots_b = maxi(4 - _humans.b, 0) if fill else (0 if _humans.b > 0 else 2)
		NetworkManager.mg_relay.connect(_on_relay)
	var cands: Array[NPC] = students(bots_a + bots_b, CENTER + Vector3(0, 0, 4))
	for n in cands:
		if team_a.size() < bots_a:
			team_a.append(n)
		elif team_b.size() < bots_b:
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
	# vagas: os jogadores de verdade primeiro, os bots depois
	var side := -1.0 if my_team == "a" else 1.0
	player.global_position = c + Vector3(side * (1.4 + _slot * 0.8), 0, 0.12 * (1 - 2 * (_slot % 2)))
	player.yaw = -side * PI * 0.5
	var na: int = _humans.a if is_net() else 1
	var nb: int = _humans.b if is_net() else 0
	for i in team_a.size():
		var k := na + i
		team_a[i].global_position = c + Vector3(-1.4 - k * 0.8, 0, 0.12 * (1 - 2 * (k % 2)))
		team_a[i].yaw = PI * 0.5
	for i in team_b.size():
		var k := nb + i
		team_b[i].global_position = c + Vector3(1.4 + k * 0.8, 0, 0.12 * (1 - 2 * (k % 2)))
		team_b[i].yaw = -PI * 0.5


func play_label() -> String:
	return "PUXA!"


func interact_label() -> String:
	return "Sair"


func on_interact() -> bool:
	if net_role != "" and mgr and mgr.online_play:
		mgr.online_play.leave()
		return true
	_finish()
	return true


## O anfitrião saiu e eu assumo (o servidor deixa o meu time como "a").
func on_net_event(ev: Dictionary) -> void:
	if str(ev.get("kind", "")) == "joined":
		(net.teams as Dictionary)[str(ev.get("id", ""))] = str(ev.get("team", "b"))
		return
	if str(ev.get("kind", "")) != "host":
		return
	var teams: Dictionary = ev.get("teams", {})
	net["teams"] = teams
	net["host"] = str(ev.get("id", ""))
	var new_team := str(teams.get(net.get("me", ""), my_team))
	if new_team != my_team:
		offset = -offset
		my_team = new_team
	if str(ev.get("id", "")) == str(net.get("me", "")):
		net_role = "host"


func on_play() -> bool:
	if _countdown > 0.0 or not running:
		return true
	# no "PUXA!" (barra quase cheia) vale o dobro
	var on_beat := fposmod(_beat, 1.0) > 0.78
	if net_role == "client":
		NetworkManager.mg_send_relay(str(net.gid), {"k": "pull", "beat": on_beat})
	elif net_role == "host":
		_pulls[my_team] += 0.09 if on_beat else 0.045
	else:
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
	if net_role == "client":
		_client_tick(delta)
		return
	if counting(delta):
		if net_role == "host":
			_send(delta, true)
		return
	if net_role == "host":
		_host_tick(delta)
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
	if net_role != "":
		_finish_net()
		return
	var won := 1 if offset < -0.2 else (-1 if offset > 0.2 else 0)
	for n in (team_a if won > 0 else team_b):
		n.visual.play("celebrate")
	end_game(won, "Cabo de guerra: " + ("seu time venceu!" if won > 0 else ("empate!" if won == 0 else "o outro time venceu")), 6 if won > 0 else 3, 14 if won > 0 else 6)


func cleanup() -> void:
	if NetworkManager.mg_relay.is_connected(_on_relay):
		NetworkManager.mg_relay.disconnect(_on_relay)
	if is_instance_valid(_root):
		_root.queue_free()
	super.cleanup()



# ---------------------------------------------------------------- online

func _on_relay(gid: String, from: String, d: Variant) -> void:
	if gid != str(net.get("gid", "")) or not (d is Dictionary):
		return
	if net_role == "host" and str(d.get("k", "")) == "pull" and running and _countdown <= 0.0:
		var t := str((net.get("teams", {}) as Dictionary).get(from, "b"))
		_pulls[t] += 0.09 if bool(d.get("beat", false)) else 0.045
	elif net_role == "client" and from == str(net.get("host", "")):
		_state = d
		_state_age = 0.0


## Anfitrião: soma os puxões dos dois times + a força dos bots.
func _host_tick(delta: float) -> void:
	time_left -= delta
	_beat += delta / 0.55
	hud.set_meter(fposmod(_beat, 1.0))
	var bots_force := (team_b.size() - team_a.size()) * 0.06
	offset += bots_force * delta + 0.12 * maxf(sin(Time.get_ticks_msec() * 0.0021), 0.0) * delta * signf(bots_force)
	offset += _pulls.b - _pulls.a
	_pulls = {"a": 0.0, "b": 0.0}
	_net_hud()
	_send(delta, false)
	if offset <= -WIN_OFFSET or offset >= WIN_OFFSET or time_left <= 0.0:
		_finish()


func _send(delta: float, counting_now: bool) -> void:
	_net_t -= delta
	if _net_t > 0.0:
		return
	_net_t = 0.1
	NetworkManager.mg_send_relay(str(net.gid), {"off": snappedf(offset, 0.001), "t": snappedf(maxf(time_left, 0.0), 0.1), "c": 1 if counting_now else 0})


func _client_tick(delta: float) -> void:
	_state_age += delta
	_beat += delta / 0.55
	hud.set_meter(fposmod(_beat, 1.0))
	if _state.is_empty():
		hud.set_minigame_text("Cabo de guerra · esperando o anfitrião...")
		if _state_age > 20.0:
			end_game(0, "O anfitrião não respondeu", 2, 4)
		return
	offset = lerpf(offset, float(_state.get("off", offset)), 1.0 - exp(-12.0 * delta))
	time_left = float(_state.get("t", time_left))
	_net_hud()
	if _state.has("end"):
		var w := str(_state.get("end", "draw"))
		var won := 0 if w == "draw" else (1 if w == my_team else -1)
		end_game(won, "Cabo de guerra: " + ("seu time venceu!" if won > 0 else ("empate!" if won == 0 else "o outro time venceu")), 6 if won > 0 else 3, 14 if won > 0 else 6)


func _net_hud() -> void:
	var winning := offset < 0.0 if my_team == "a" else offset > 0.0
	hud.set_minigame_text("Cabo de guerra com a turma  ·  %s  ·  %d s  ·  toque RÁPIDO e no PUXA!" % ["Ganhando!" if winning else "Perdendo!", int(maxf(time_left, 0.0))])


func _finish_net() -> void:
	if net_role == "client":
		return  # quem decide é o anfitrião
	var w := "a" if offset < -0.2 else ("b" if offset > 0.2 else "draw")
	NetworkManager.mg_send_relay(str(net.gid), {"off": offset, "t": 0.0, "c": 0, "end": w})
	NetworkManager.mg_team_result(str(net.gid), 1 if w == "a" else 0, 1 if w == "b" else 0)
	var won := 0 if w == "draw" else (1 if w == my_team else -1)
	end_game(won, "Cabo de guerra: " + ("seu time venceu!" if won > 0 else ("empate!" if won == 0 else "o outro time venceu")), 6 if won > 0 else 3, 14 if won > 0 else 6)
