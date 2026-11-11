class_name InteriorDecorator
extends RefCounted
## Mobília e decoração interna de cada tipo de ambiente.

const T := 0.25
const FY := 0.025

const BOARD_TEXTS := [
	"Bom dia, turma!\nHoje: Matemática", "Ditado:\ncasa - bola - escola", "2 + 3 = 5\n4 x 2 = 8",
	"Tarefa: pág. 42\nNão esqueçam!", "Feliz aniversário,\nJúlia!", "Prova na sexta-feira!\nEstudem :)",
	"Ciências:\nO ciclo da água", "Leitura em dupla\napós o recreio", "Geografia:\nRegiões do Brasil",
	"História:\nO descobrimento", "Português:\nsubstantivos", "Inglês:\nHello, friends!",
]


static func decorate(sb: SchoolBuilder, b: WorldBatcher, room: Dictionary, _def: Dictionary) -> void:
	var r: Rect2 = room.rect
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(room.name)
	var first_label := sb.labels.size()
	_decorate_kind(sb, b, room, r, rng)
	# rótulos internos acompanham a visibilidade do interior
	for i in range(first_label, sb.labels.size()):
		if not sb.labels[i].has("parent"):
			sb.labels[i]["parent"] = b.name


static func _decorate_kind(sb: SchoolBuilder, b: WorldBatcher, room: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	match room.get("kind", ""):
		"classroom":
			_classroom(sb, b, room, r, rng)
		"library":
			_library(sb, b, r, rng)
		"teachers":
			_teachers(sb, b, r, rng)
		"director":
			_director(sb, b, r, rng)
		"office":
			_office(sb, b, r, rng)
		"hall":
			_hall(sb, b, r, rng)
		"computer":
			_computer(sb, b, r)
		"art":
			_art(sb, b, r, rng)
		"bathroom_f", "bathroom_m":
			_bathroom(sb, b, r, room.kind == "bathroom_f")
		"storage":
			_storage(sb, b, r, rng)
		"corridor":
			_corridor(sb, b, room, r, rng)
		"lab":
			_lab(sb, b, r, rng)
		"music":
			_music(sb, b, r, rng)
		"cantina":
			_cantina(sb, b, r, rng)
		"nurse":
			_nurse(sb, b, room, r)
		"refectory":
			_refectory(sb, b, room, r)
		"auditorium":
			_auditorium(sb, b, room, r)
		"toys":
			_toys(sb, b, room, r, rng)
		"games":
			_games(sb, b, room, r, rng)
		"dance":
			_dance(sb, b, room, r)
		"mezzanine":
			_mezzanine(sb, b, r)


## Posição na face interna de uma parede. Retorna [pos, rot_y].
static func wp(r: Rect2, side: String, along: float, y: float, depth := 0.03) -> Array:
	match side:
		"n": return [Vector3(along, y, r.position.y + T * 0.5 + depth), 0.0]
		"s": return [Vector3(along, y, r.end.y - T * 0.5 - depth), PI]
		"w": return [Vector3(r.position.x + T * 0.5 + depth, y, along), PI * 0.5]
		_: return [Vector3(r.end.x - T * 0.5 - depth, y, along), -PI * 0.5]


static func wall_rect(b: WorldBatcher, r: Rect2, side: String, along: float, y: float, w: float, h: float, col: Color, mat := "plain", depth := 0.03) -> Vector3:
	var p: Array = wp(r, side, along, y, depth)
	b.box(mat, p[0], Vector3(w, h, 0.02), col, p[1], false)
	return p[0]


static func _door_side(room: Dictionary) -> String:
	var doors: Array = room.get("doors", [])
	return doors[0][0] if not doors.is_empty() else "s"


static func _poster(sb: SchoolBuilder, b: WorldBatcher, r: Rect2, side: String, along: float, y: float, title: String, col: Color) -> void:
	var p := wall_rect(b, r, side, along, y, 1.0, 0.75, Color("fbf7ee"))
	wall_rect(b, r, side, along, y + 0.02, 0.86, 0.55, col, "plain", 0.04)
	var rot: float = wp(r, side, along, y)[1]
	var n := Vector3(0, 0, 1).rotated(Vector3.UP, rot)
	sb.add_label(title, p + n * 0.035 + Vector3(0, -0.3, 0), rot, 28, Color("333333"), Color(0, 0, 0, 0), 0.005, 18.0)


static func _paper_ball(sb: SchoolBuilder, pos: Vector3) -> void:
	sb.pickups.append({"kind": "paper_ball", "pos": pos})


# --------------------------------------------------------------- sala de aula

static func _classroom(sb: SchoolBuilder, b: WorldBatcher, room: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var board_side := "n" if _door_side(room) in ["w", "e"] else "w"
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	var grade: int = room.get("grade", 0)
	var desk_yaw := -PI * 0.5 if board_side == "w" else PI
	var frame_cols := [Color("2f5fa8"), Color("c0392b"), Color("27ae60"), Color("8e44ad")]
	var frame: Color = frame_cols[grade % frame_cols.size()]
	# Lousa e mesa do professor
	var bp: Array = wp(r, board_side, (z0 + z1) * 0.5 if board_side == "w" else (x0 + x1) * 0.5, FY, 0.04)
	var board_xf := Props.chalkboard(b, bp[0], bp[1], 4.2)
	var n := Vector3(0, 0, 1).rotated(Vector3.UP, bp[1])
	sb.add_label(BOARD_TEXTS[grade % BOARD_TEXTS.size()], board_xf.origin + n * 0.03 + Vector3(0, 0.05, 0), bp[1], 56, Color(0.97, 0.97, 0.95), Color(0, 0, 0, 0), 0.0055, 22.0)
	sb.add_label("A B C D E F G H I J K L M N O P Q R S T U V W X Y Z", board_xf.origin + n * 0.02 + Vector3(0, 1.0, 0), bp[1], 36, Color("c0392b"), Color(1, 1, 1, 0.9), 0.006, 20.0)
	Props.teacher_desk(b, bp[0] + n * 1.9, bp[1])
	if sb.classrooms.has(room.name):
		var info: Dictionary = sb.classrooms[room.name]
		info["board"] = board_xf.origin
		info["board_yaw"] = bp[1]
		info["teacher"] = bp[0] + n * 1.1 + Vector3(0, 0.05, 0) + Vector3(0, 0, 1).rotated(Vector3.UP, bp[1] + PI * 0.5) * 1.3
		info["teacher_desk"] = bp[0] + n * 1.9
		info["board_label"] = sb.labels.size() - 2  # texto da lousa (antes do alfabeto)
		sb.labels[-2]["width"] = 680.0
		info["item_spots"] = [bp[0] + n * 0.5 + Vector3(0, 0.95, 0) + Vector3(0, 0, 1).rotated(Vector3.UP, bp[1] + PI * 0.5) * 2.4]
	# relógio acima da lousa (lado oposto)
	var opp := {"w": "e", "n": "s", "e": "w", "s": "n"}[board_side] as String
	# 12 carteiras (uma turma): 3 fileiras de 4, com corredores bem largos
	# entre as fileiras e entre as colunas (e a área da porta sempre livre)
	for i in 3:
		for j in 4:
			var pos: Vector3
			if board_side == "w":
				var door_n := _door_side(room) == "n"
				var z_start := 2.4 if door_n else 1.6
				pos = Vector3(x0 + 3.2 + i * 2.25, FY, z0 + z_start + j * (r.size.y - 4.0) / 3.0)
			else:
				pos = Vector3(x0 + 1.9 + j * (r.size.x - 3.8) / 3.0, FY, z0 + 3.5 + i * 2.25)
			Props.student_desk(b, pos, desk_yaw, frame)
			if rng.randf() < 0.12:
				var dn := Vector3(0, 0, 1).rotated(Vector3.UP, desk_yaw)
				b.box("plain", pos + dn * 0.52 + Vector3(0, 0.83, 0), Vector3(0.2, 0.015, 0.28), [Color("e74c3c"), Color("3498db"), Color("f1c40f")][rng.randi() % 3], desk_yaw, false)
			if sb.classrooms.has(room.name) and (i + j) % 6 == 2:
				sb.classrooms[room.name]["item_spots"].append(pos + Vector3(0, 0.8, 0) + Vector3(0, 0, 1).rotated(Vector3.UP, desk_yaw) * 0.45)
	# Mural, cartazes e armário na parede do fundo
	var along_c := (z0 + z1) * 0.5 if opp in ["e", "w"] else (x0 + x1) * 0.5
	var cork := wall_rect(b, r, opp, along_c, 1.65, 3.2, 1.2, Color("c49a6c"))
	for k in 6:
		var off := -1.2 + k * 0.48
		var pc: Color = [Color("fff59d"), Color("f8bbd0"), Color("b3e5fc"), Color("c8e6c9")][k % 4]
		var pp: Array = wp(r, opp, along_c + off, 1.65 + (0.25 if k % 2 == 0 else -0.2), 0.045)
		b.box("plain", pp[0], Vector3(0.36, 0.42, 0.01), pc, pp[1] + rng.randf_range(-0.12, 0.12), false)
	sb.add_label("NOSSOS TRABALHOS", cork + Vector3(0, 0.75, 0) + Vector3(0, 0, 1).rotated(Vector3.UP, wp(r, opp, along_c, 0)[1]) * 0.03, wp(r, opp, along_c, 0)[1], 36, Color("6d4c41"), Color(1, 1, 1, 0.8), 0.006, 20.0)
	var clock: Array = wp(r, opp, along_c, 3.0, 0.05)
	var cxf := Transform3D(Basis(Vector3.UP, clock[1]) * Basis(Vector3.RIGHT, PI * 0.5), clock[0])
	b.cylinder_xf("plain", cxf, 0.24, 0.24, 0.05, Color("f5f5f5"), 16)
	b.box("plain", clock[0] + Vector3(0, 0.07, 0) + Vector3(0, 0, 1).rotated(Vector3.UP, clock[1]) * 0.03, Vector3(0.02, 0.15, 0.01), Color("222222"), clock[1], false)
	# armário
	var corner_along := (z1 - 1.0) if opp in ["e", "w"] else (x1 - 1.2)
	var ap: Array = wp(r, opp, corner_along, FY + 0.9, 0.3)
	b.box("metal", ap[0], Vector3(1.0, 1.8, 0.5), Color("95a5a6"), ap[1])
	b.box("metal", ap[0] + Vector3(0, 0, 0), Vector3(0.02, 1.7, 0.52), Color("7f8c8d"), ap[1])
	b.collider(ap[0], Vector3(1.0, 1.8, 0.5), ap[1])
	# lixeira
	var tp: Array = wp(r, board_side, (z1 - 0.6) if board_side == "w" else (x1 - 0.6), FY + 0.25, 0.3)
	b.cylinder("plain", tp[0], 0.18, 0.15, 0.5, Color("3498db"), 10)
	# cartazes laterais
	# cartazes na parede da porta (a parede das janelas fica livre)
	var side_wall := _door_side(room)
	var titles := ["TABUADA", "ALFABETO", "MAPA DO BRASIL", "SISTEMA SOLAR", "VOGAIS", "NÚMEROS"]
	var cols := [Color("f6b93b"), Color("78e08f"), Color("4a69bd"), Color("e55039"), Color("60a3bc"), Color("b71540")]
	for k in 2:
		var along := ((x0 + 3.0 + k * 3.5) if side_wall in ["n", "s"] else (z0 + 3.0 + k * 3.5))
		_poster(sb, b, r, side_wall, along, 1.75, titles[(grade + k) % titles.size()], cols[(grade + k) % cols.size()])
	_classroom_theme(sb, b, room, r, grade, opp, rng)
	_door_sign(sb, b, room, r, room.name.to_upper())


## Cada sala com sua cara: pequenos (tapete e cantinho de brinquedos),
## médios (mapa-múndi e plantinhas), maiores (estante e tabela periódica).
static func _classroom_theme(sb: SchoolBuilder, b: WorldBatcher, room: Dictionary, r: Rect2, grade: int, back: String, rng: RandomNumberGenerator) -> void:
	var accent: Color = room.get("inner", [Color("6fae7f")])[0]
	# faixa de bandeirinhas no alto da parede do fundo, na cor da sala
	var along_b := r.get_center().y if back in ["e", "w"] else r.get_center().x
	for k in 9:
		if k == 4:
			continue  # relógio
		var pf: Array = wp(r, back, along_b - 3.2 + k * 0.8, 3.05, 0.05)
		b.box("plain", pf[0], Vector3(0.36, 0.3, 0.01), accent.lightened(0.25 * (k % 2)), pf[1] + PI * 0.25 * 0.0, false)
	match grade % 3:
		0:
			# tapete de leitura colorido e caixa de brinquedos no fundo
			var rp: Array = wp(r, back, along_b, FY + 0.012, 1.4)
			b.slab("plain", rp[0], Vector3(3.0, 0.02, 1.8), accent.lightened(0.35))
			b.slab("plain", rp[0] + Vector3(0, 0.004, 0), Vector3(2.4, 0.02, 1.2), Color("fff3c4"))
			var tb: Array = wp(r, back, along_b + 2.6, FY + 0.3, 0.35)
			b.box("plain", tb[0], Vector3(0.9, 0.6, 0.5), Color("ff8a65"), tb[1])
			for t in 3:
				b.sphere("plain", tb[0] + Vector3(-0.25 + t * 0.25, 0.38, 0), 0.12, [Color("ffd54f"), Color("4fc3f7"), Color("81c784")][t], Vector3.ONE, 8, 5, false)
		1:
			# mapa-múndi grande e vasinhos na janela
			var mp := wall_rect(b, r, back, along_b - 2.6, 1.7, 1.6, 1.0, Color("4fa3d9"))
			b.box("plain", mp + Vector3(0, 0.05, 0), Vector3(0.5, 0.35, 0.03), Color("7cc576"), wp(r, back, along_b, 0)[1], false)
			for k in 3:
				var ws: String = room.get("auto_windows", ["n"])[0]
				var vp: Array = wp(r, ws, (r.position.x + 2.0 + k * 3.0) if ws in ["n", "s"] else (r.position.y + 2.0 + k * 3.0), FY + 1.05, 0.25)
				b.cylinder("plain", vp[0], 0.12, 0.1, 0.2, Color("c0392b").darkened(0.2), 8)
				b.sphere("foliage", vp[0] + Vector3(0, 0.22, 0), 0.18, Color("3f8a3a"), Vector3.ONE, 7, 5, false)
		_:
			# estante de livros e tabela periódica
			var sp: Array = wp(r, back, along_b - 2.4, FY + 1.0, 0.3)
			Props.bookshelf(b, Vector3(sp[0].x, FY, sp[0].z), sp[1], rng, 1.6, 1.9)
			var tp := wall_rect(b, r, back, along_b + 2.6, 2.0, 1.5, 0.9, Color("f5f5f5"))
			for i in 6:
				for j in 3:
					wall_rect(b, r, back, along_b + 2.6 - 0.6 + i * 0.24, 2.2 - j * 0.24, 0.2, 0.2, [Color("ef9a9a"), Color("90caf9"), Color("a5d6a7"), Color("ffe082")][(i + j) % 4], "plain", 0.045)


## Placa acima da porta, do lado de fora da sala.
static func _door_sign(sb: SchoolBuilder, b: WorldBatcher, room: Dictionary, r: Rect2, text: String) -> void:
	var doors: Array = room.get("doors", [])
	if doors.is_empty():
		return
	var d: Array = doors[0]
	var side: String = d[0]
	var pos: Vector3
	var rot: float
	match side:
		"n":
			pos = Vector3(d[1], 2.62, r.position.y - T * 0.5 - 0.04)
			rot = PI
		"s":
			pos = Vector3(d[1], 2.62, r.end.y + T * 0.5 + 0.04)
			rot = 0.0
		"w":
			pos = Vector3(r.position.x - T * 0.5 - 0.04, 2.62, d[1])
			rot = -PI * 0.5
		_:
			pos = Vector3(r.end.x + T * 0.5 + 0.04, 2.62, d[1])
			rot = PI * 0.5
	var sname := "signs" + sb.floor_tag
	var outer := sb.chunk(sname, 45.0)
	outer.box("plain", pos, Vector3(1.5, 0.34, 0.03), Color("2f5fa8"), rot, false)
	sb.add_label(text, pos + Vector3(0, 0, 1).rotated(Vector3.UP, rot) * 0.02, rot, 40, Color.WHITE, Color(0, 0, 0, 0), 0.0055, 30.0)
	sb.labels[-1]["parent"] = sname


# --------------------------------------------------------------- biblioteca

static func _library(sb: SchoolBuilder, b: WorldBatcher, r: Rect2, rng: RandomNumberGenerator) -> void:
	for k in 4:
		var p: Array = wp(r, "w", r.position.y + 1.5 + k * 2.3, FY, 0.22)
		Props.bookshelf(b, p[0], p[1], rng, 2.0, 2.2)
	for k in 7:
		var x := r.position.x + 1.6 + k * 2.3
		if x > r.end.x - 4.0:
			break
		var p2: Array = wp(r, "n", x, FY, 0.22)
		Props.bookshelf(b, p2[0], p2[1], rng, 2.0, 2.2)
	for k in 2:
		var p3: Array = wp(r, "e", r.position.y + 2.0 + k * 2.4, FY, 0.22)
		Props.bookshelf(b, p3[0], p3[1], rng, 2.0, 2.2)
	# tapete de leitura e pufes
	var rug := Vector3(r.position.x + 5.0, FY + 0.006, r.end.y - 3.0)
	b.cylinder("plain", rug, 2.0, 2.0, 0.012, Color("f39c12"), 20, false)
	b.cylinder("plain", rug + Vector3(0, 0.004, 0), 1.4, 1.4, 0.012, Color("e74c3c"), 20, false)
	for k in 5:
		var a := k * TAU / 5.0
		b.sphere("plain", rug + Vector3(cos(a) * 1.4, 0.25, sin(a) * 1.4), 0.38, [Color("3498db"), Color("9b59b6"), Color("2ecc71"), Color("f1c40f"), Color("e84393")][k], Vector3(1, 0.65, 1))
		Props.add_seat(rug + Vector3(cos(a) * 1.4, -FY, sin(a) * 1.4), atan2(-cos(a), -sin(a)), Vector3.ZERO, FY + 0.4, "Sentar no pufe")
	# mesas de leitura
	for i in 2:
		for j in 2:
			Props.table_with_chairs(b, Vector3(r.position.x + 10.5 + i * 3.6, FY, r.position.y + 3.5 + j * 3.2), 0.0)
	# balcão da bibliotecária
	var desk := Vector3(r.end.x - 2.2, FY, r.position.y + 2.2)
	b.box("wood", desk + Vector3(0, 0.55, 0), Vector3(2.0, 1.1, 0.7), Color("8a5a32"))
	b.collider(desk + Vector3(0, 0.55, 0), Vector3(2.0, 1.1, 0.7))
	b.box("plain", desk + Vector3(0.5, 1.2, 0), Vector3(0.3, 0.2, 0.2), Color("27ae60"))
	var sp: Array = wp(r, "e", r.end.y - 2.0, 2.2, 0.04)
	b.box("plain", sp[0], Vector3(1.6, 0.45, 0.03), Color("c0392b"), sp[1])
	sb.add_label("SILÊNCIO, POR FAVOR", sp[0] + Vector3(0, 0, 1).rotated(Vector3.UP, sp[1]) * 0.02, sp[1], 32, Color.WHITE, Color(0, 0, 0, 0), 0.006, 18.0)
	_globe(b, Vector3(r.end.x - 1.0, FY, r.end.y - 1.0))
	_door_sign(sb, b, {"doors": [["n", -42.0, 1.6]]}, r, "BIBLIOTECA")


static func _globe(b: WorldBatcher, o: Vector3) -> void:
	b.cylinder("wood", o + Vector3(0, 0.4, 0), 0.05, 0.08, 0.8, Color("6d4c41"), 8)
	b.sphere("plain", o + Vector3(0, 1.05, 0), 0.25, Color("3b8ed0"), Vector3.ONE, 12, 8)
	b.sphere("plain", o + Vector3(0.08, 1.12, 0.12), 0.15, Color("6ab04c"), Vector3(1, 0.6, 0.6), 8, 5)


# --------------------------------------------------------------- professores

static func _teachers(sb: SchoolBuilder, b: WorldBatcher, r: Rect2, rng: RandomNumberGenerator) -> void:
	var c := Vector3(r.get_center().x, FY, r.get_center().y + 0.5)
	Props.table_with_chairs(b, c + Vector3(0, 0, -0.9), 0.0, Color("8a5a32"))
	Props.table_with_chairs(b, c + Vector3(0, 0, 0.9), 0.0, Color("8a5a32"))
	var cp: Array = wp(r, "e", r.position.y + 2.0, FY + 0.45, 0.3)
	b.box("wood", cp[0], Vector3(1.8, 0.9, 0.55), Color("6d4c41"), cp[1])
	b.collider(cp[0], Vector3(1.8, 0.9, 0.55), cp[1])
	b.box("metal", cp[0] + Vector3(0, 0.6, 0), Vector3(0.3, 0.35, 0.25), Color("2c3e50"), cp[1])
	b.cylinder("plain", cp[0] + Vector3(0.3, 0.52, 0), 0.05, 0.05, 0.12, Color("ecf0f1"), 8)
	var sh: Array = wp(r, "w", r.get_center().y, FY, 0.22)
	Props.bookshelf(b, sh[0], sh[1], rng, 2.4, 2.0)
	# sofá
	var so: Array = wp(r, "s", r.position.x + 2.6, FY, 0.5)
	b.box("plain", so[0] + Vector3(0, 0.25, 0), Vector3(2.2, 0.5, 0.8), Color("2d6a8f"), so[1])
	b.box("plain", so[0] + Vector3(0, 0.6, 0) + Vector3(0, 0, -0.3).rotated(Vector3.UP, so[1]), Vector3(2.2, 0.6, 0.2), Color("245a7a"), so[1])
	b.collider(so[0] + Vector3(0, 0.4, 0), Vector3(2.2, 0.8, 0.8), so[1])
	for k in 3:
		Props.add_seat(so[0] + Vector3(-0.7 + k * 0.7, 0, 0).rotated(Vector3.UP, so[1]) + Vector3(0, -FY, 0), so[1], Vector3.ZERO, FY + 0.5, "Sentar no sofá")
	_door_sign(sb, b, {"doors": [["n", -32.0, 1.1]]}, r, "PROFESSORES")


# --------------------------------------------------------------- diretoria

static func _director(sb: SchoolBuilder, b: WorldBatcher, r: Rect2, rng: RandomNumberGenerator) -> void:
	var desk_pos := Vector3(r.get_center().x, FY, r.end.y - 2.6)
	Props.teacher_desk(b, desk_pos, PI)
	# cadeiras de visitante (onde o aluno senta para "conversar" com o diretor)
	for sx: float in [-0.6, 0.6]:
		var co := desk_pos + Vector3(sx, 0, -1.3)
		b.box("plain", co + Vector3(0, 0.45, 0), Vector3(0.48, 0.08, 0.48), Color("7b241c"))
		b.box("plain", co + Vector3(0, 0.8, -0.24), Vector3(0.48, 0.6, 0.08), Color("7b241c"))
		for lx: float in [-0.2, 0.2]:
			for lz: float in [-0.2, 0.2]:
				b.box("wood", co + Vector3(lx, 0.21, lz), Vector3(0.04, 0.42, 0.04), Color("4e342e"))
		Props.add_seat(co, 0.0, Vector3.ZERO, FY + 0.49, "Sentar")
	var sh: Array = wp(r, "e", r.get_center().y, FY, 0.22)
	Props.bookshelf(b, sh[0], sh[1], rng, 2.2, 2.2)
	# bandeira e quadros
	var fp := Vector3(r.position.x + 1.0, FY, r.end.y - 0.8)
	b.cylinder("metal", fp + Vector3(0, 1.1, 0), 0.025, 0.025, 2.2, Color("d4af37"), 6)
	b.box("plain", fp + Vector3(0.45, 1.75, 0), Vector3(0.9, 0.62, 0.01), Color("009b3a"))
	b.box("plain", fp + Vector3(0.45, 1.75, 0.006), Vector3(0.5, 0.5, 0.005), Color("fedf00"), PI * 0.25)
	var discp := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), fp + Vector3(0.45, 1.75, 0.012))
	b.cylinder_xf("plain", discp, 0.15, 0.15, 0.005, Color("002776"), 14)
	for k in 3:
		wall_rect(b, r, "w", r.position.y + 2.5 + k * 1.6, 1.8, 0.9, 0.7, Color("6d4c41"))
		wall_rect(b, r, "w", r.position.y + 2.5 + k * 1.6, 1.8, 0.75, 0.55, [Color("aed6f1"), Color("f9e79f"), Color("a9dfbf")][k], "plain", 0.045)
	var plant := Vector3(r.end.x - 0.8, FY, r.end.y - 0.8)
	b.cylinder("plain", plant + Vector3(0, 0.25, 0), 0.25, 0.2, 0.5, Color("a04000"), 10)
	b.sphere("foliage", plant + Vector3(0, 0.95, 0), 0.5, Color("3f8a3a"), Vector3(1, 1.3, 1), 8, 6)
	var rug := Vector3(r.get_center().x, FY + 0.005, r.get_center().y)
	b.box("plain", rug, Vector3(4.0, 0.01, 3.0), Color("7b241c"), 0.0, false)
	b.box("plain", rug + Vector3(0, 0.003, 0), Vector3(3.6, 0.01, 2.6), Color("a93226"), 0.0, false)
	_door_sign(sb, b, {"doors": [["n", -22.0, 1.1]]}, r, "DIRETORIA")


# --------------------------------------------------------------- secretaria

static func _office(sb: SchoolBuilder, b: WorldBatcher, r: Rect2, rng: RandomNumberGenerator) -> void:
	for k in 2:
		Props.teacher_desk(b, Vector3(r.position.x + 2.5 + k * 4.5, FY, r.end.y - 2.6), PI)
	for k in 4:
		var p: Array = wp(r, "w", r.position.y + 1.5 + k * 0.8, FY + 0.7, 0.3)
		b.box("metal", p[0], Vector3(0.6, 1.4, 0.55), Color("7f8c8d"), p[1])
		for d in 3:
			b.box("metal", p[0] + Vector3(0, -0.4 + d * 0.45, 0) + Vector3(0, 0, 0.28).rotated(Vector3.UP, p[1]), Vector3(0.5, 0.35, 0.02), Color("95a5a6"), p[1])
		b.collider(p[0], Vector3(0.6, 1.4, 0.55), p[1])
	var sh: Array = wp(r, "e", r.get_center().y, FY, 0.22)
	Props.bookshelf(b, sh[0], sh[1], rng, 2.0, 2.0)
	_door_sign(sb, b, {"doors": [["n", -12.0, 1.1]]}, r, "SECRETARIA")


# --------------------------------------------------------------- hall

static func _hall(sb: SchoolBuilder, b: WorldBatcher, r: Rect2, rng: RandomNumberGenerator) -> void:
	# troféus
	for sx: float in [-1.0, 1.0]:
		var tc := Vector3(sx * 7.6, FY, 44.5)
		b.box("wood", tc + Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 0.6), Color("6d4c41"))
		b.box("glass", tc + Vector3(0, 1.45, 0), Vector3(2.3, 1.1, 0.5), Color("bcd9e8"))
		b.collider(tc + Vector3(0, 1.0, 0), Vector3(2.4, 2.0, 0.6))
		for k in 4:
			var tp := tc + Vector3(-0.8 + k * 0.53, 1.1, 0)
			b.cylinder("metal", tp, 0.08, 0.1, 0.25, Color("d4af37"), 8)
			b.sphere("metal", tp + Vector3(0, 0.22, 0), 0.1, Color("f1c40f"), Vector3.ONE, 8, 6)
		Props.bench(b, Vector3(sx * 8.0, FY, 30.5), PI * 0.5 * -sx)
	# quadro de avisos
	var bp: Array = wp(r, "w", 28.5, 1.7, 0.03)
	b.box("plain", bp[0], Vector3(3.0, 1.3, 0.04), Color("c49a6c"), bp[1])
	for k in 5:
		var pp: Array = wp(r, "w", 27.4 + k * 0.55, 1.7 + (0.2 if k % 2 else -0.15), 0.06)
		b.box("plain", pp[0], Vector3(0.4, 0.5, 0.01), [Color("fff59d"), Color("b3e5fc"), Color("f8bbd0")][k % 3], pp[1] + rng.randf_range(-0.1, 0.1), false)
	sb.add_label("QUADRO DE AVISOS", bp[0] + Vector3(0, 0.82, 0) + Vector3(0.03, 0, 0), bp[1], 40, Color("2f5fa8"), Color(1, 1, 1, 0.9), 0.006, 25.0)
	var wp2: Array = wp(r, "e", 28.5, 2.3, 0.03)
	b.box("plain", wp2[0], Vector3(4.0, 0.9, 0.03), Color("2f5fa8"), wp2[1])
	sb.add_label("SEJAM BEM-VINDOS!", wp2[0] + Vector3(-0.025, 0, 0), wp2[1], 64, Color.WHITE, Color(0, 0, 0, 0), 0.006, 30.0)
	# vasos de plantas
	for p: Vector3 in [Vector3(-8.8, FY, 47), Vector3(8.8, FY, 47), Vector3(-8.8, FY, 25.2), Vector3(8.8, FY, 25.2)]:
		b.cylinder("plain", p + Vector3(0, 0.3, 0), 0.3, 0.25, 0.6, Color("c0392b").darkened(0.3), 10)
		b.sphere("foliage", p + Vector3(0, 1.05, 0), 0.5, Color("3f8a3a"), Vector3(1, 1.4, 1), 8, 6)
		b.collider_cyl(p + Vector3(0, 0.5, 0), 0.32, 1.0)
	# campainha (sinal da escola)
	var bell: Array = wp(r, "e", 40.0, 3.0, 0.08)
	b.cylinder_xf("metal", Transform3D(Basis(Vector3.UP, bell[1]) * Basis(Vector3.RIGHT, PI * 0.5), bell[0]), 0.18, 0.18, 0.12, Color("c0392b"), 12)


# --------------------------------------------------------------- informática

static func _computer(sb: SchoolBuilder, b: WorldBatcher, r: Rect2) -> void:
	for side: String in ["w", "e", "s"]:
		var length := r.size.y if side in ["w", "e"] else r.size.x
		var start := r.position.y if side in ["w", "e"] else r.position.x
		var count := int((length - 1.6) / 1.4)
		for k in count:
			var along := start + 1.0 + k * 1.4 + 0.5
			var p: Array = wp(r, side, along, FY, 0.45)
			var o: Vector3 = p[0]
			var rot: float = p[1]
			b.box("plain", o + Vector3(0, 0.74, 0), Vector3(1.3, 0.04, 0.7), Color("ecf0f1"), rot)
			b.box("metal", o + Vector3(0, 0.37, 0), Vector3(1.2, 0.72, 0.04), Color("95a5a6"), rot)
			var back := Vector3(0, 0, -0.18).rotated(Vector3.UP, rot)
			b.box("plain", o + back + Vector3(0, 1.0, 0), Vector3(0.5, 0.36, 0.05), Color("2c3e50"), rot)
			b.box("plain", o + back + Vector3(0, 1.0, 0) + Vector3(0, 0, 0.03).rotated(Vector3.UP, rot), Vector3(0.44, 0.3, 0.01), Color("5dade2"), rot, false)
			b.box("plain", o + back + Vector3(0, 0.8, 0), Vector3(0.08, 0.1, 0.06), Color("2c3e50"), rot)
			b.box("plain", o + Vector3(0, 0.77, 0.12).rotated(Vector3.UP, 0) + Vector3(0, 0, 0.1).rotated(Vector3.UP, rot), Vector3(0.42, 0.02, 0.14), Color("34495e"), rot, false)
			b.collider(o + Vector3(0, 0.38, 0), Vector3(1.3, 0.76, 0.7), rot)
			var chair := o + Vector3(0, 0, 0.75).rotated(Vector3.UP, rot)
			b.cylinder("plain", chair + Vector3(0, 0.45, 0), 0.22, 0.22, 0.06, Color("1f3a5f"), 10)
			b.cylinder("metal", chair + Vector3(0, 0.22, 0), 0.03, 0.03, 0.44, Color("7f8c8d"), 6)
			Props.add_seat(chair + Vector3(0, -FY, 0), rot + PI, Vector3.ZERO, FY + 0.48, "Sentar")
	_door_sign(sb, b, {"doors": [["n", 20.0, 1.1]]}, r, "INFORMÁTICA")


# --------------------------------------------------------------- artes

static func _art(sb: SchoolBuilder, b: WorldBatcher, r: Rect2, rng: RandomNumberGenerator) -> void:
	for i in 2:
		for j in 2:
			Props.table_with_chairs(b, Vector3(r.position.x + 3.5 + i * 4.6, FY, r.position.y + 3.3 + j * 3.4), 0.0, Color("f5e6c8"))
	var cols := [Color("e74c3c"), Color("f1c40f"), Color("3498db"), Color("2ecc71"), Color("9b59b6"), Color("e67e22")]
	for k in 6:
		wall_rect(b, r, "w", r.position.y + 1.5 + k * 1.4, 1.7, 1.0, 0.8, Color("fdfefe"))
		var p2: Array = wp(r, "w", r.position.y + 1.5 + k * 1.4, 1.7, 0.045)
		b.sphere("plain", p2[0], 0.22, cols[k], Vector3(0.05, 1, 1), 10, 6, false)
	# cavaletes
	for k in 3:
		var e := Vector3(r.end.x - 1.5, FY, r.position.y + 2.0 + k * 2.5)
		b.box("wood", e + Vector3(0, 0.8, 0), Vector3(0.05, 1.6, 0.6), Color("8a5a32"), 0.3)
		b.box("plain", e + Vector3(-0.1, 1.2, 0), Vector3(0.02, 0.7, 0.55), cols[(k + 2) % 6].lightened(0.4), 0.3)
		b.collider(e + Vector3(0, 0.8, 0), Vector3(0.4, 1.6, 0.6))
	# potes de tinta
	for k in 6:
		b.cylinder("plain", Vector3(r.position.x + 3.0 + k * 0.25, FY + 0.81, r.position.y + 3.3), 0.06, 0.06, 0.12, cols[k], 8)
	_door_sign(sb, b, {"doors": [["n", 32.0, 1.1]]}, r, "ARTES")


# --------------------------------------------------------------- banheiros

static func _bathroom(sb: SchoolBuilder, b: WorldBatcher, r: Rect2, female: bool) -> void:
	var stall_col := Color("e84393") if female else Color("2e86de")
	# cabines ao longo da parede leste
	var x_wall := r.end.x - T * 0.5
	for k in 4:
		var z0 := r.position.y + 1.0 + k * 1.6
		b.box("plain", Vector3(x_wall - 0.75, 1.0, z0), Vector3(1.5, 1.8, 0.05), stall_col)
		b.collider(Vector3(x_wall - 0.75, 1.0, z0), Vector3(1.5, 1.8, 0.08))
		var zc := z0 + 0.8
		b.box("plain", Vector3(x_wall - 1.5, 1.0, zc - 0.55), Vector3(0.05, 1.8, 0.4), stall_col)
		b.box("plain", Vector3(x_wall - 1.2, 1.0, zc + 0.5), Vector3(0.6, 1.8, 0.04), stall_col.lightened(0.15), 0.6)
		# vaso sanitário
		b.box("plain", Vector3(x_wall - 0.35, 0.22, zc), Vector3(0.45, 0.42, 0.38), Color("fdfefe"))
		b.cylinder("plain", Vector3(x_wall - 0.55, 0.44, zc), 0.2, 0.18, 0.06, Color("f4f6f7"), 10)
		b.box("plain", Vector3(x_wall - 0.18, 0.7, zc), Vector3(0.18, 0.5, 0.4), Color("fdfefe"))
	b.box("plain", Vector3(x_wall - 0.75, 1.0, r.position.y + 1.0 + 4 * 1.6), Vector3(1.5, 1.8, 0.05), stall_col)
	# pias e espelhos na parede oeste
	for k in 3:
		var z := r.position.y + 2.0 + k * 1.8
		var p: Array = wp(r, "w", z, 0.85, 0.25)
		b.box("plain", p[0], Vector3(0.6, 0.15, 0.45), Color("fdfefe"), p[1])
		b.box("plain", p[0] + Vector3(0, -0.45, 0), Vector3(0.12, 0.75, 0.12), Color("ecf0f1"), p[1])
		var m: Array = wp(r, "w", z, 1.65, 0.02)
		b.box("glass", m[0], Vector3(0.55, 0.7, 0.02), Color("d6eaf8"), m[1])
		b.collider(p[0], Vector3(0.6, 0.2, 0.45), p[1])
	_door_sign(sb, b, {"doors": [["n", (40.5 if female else 48.5), 1.2]]}, r, "MENINAS" if female else "MENINOS")


# --------------------------------------------------------------- depósito

static func _storage(sb: SchoolBuilder, b: WorldBatcher, r: Rect2, rng: RandomNumberGenerator) -> void:
	for k in 3:
		var p: Array = wp(r, "e", r.position.y + 2.0 + k * 2.5, FY, 0.3)
		var o: Vector3 = p[0]
		for s in 4:
			b.box("metal", o + Vector3(0, 0.05 + s * 0.6, 0), Vector3(2.0, 0.04, 0.55), Color("7f8c8d"), p[1])
			if s < 3:
				for q in 4:
					var bc: Color = [Color("ecf0f1"), Color("e67e22"), Color("c0392b"), Color("f1c40f")][rng.randi() % 4]
					b.sphere("plain", o + Vector3(-0.7 + q * 0.47, 0.22 + s * 0.6, 0).rotated(Vector3.UP, 0), 0.13, bc)
		b.collider(o + Vector3(0, 1.0, 0), Vector3(2.0, 2.0, 0.55), p[1])
	# cones e colchonetes
	for k in 6:
		b.cylinder("plain", Vector3(r.position.x + 1.0 + k * 0.4, FY + 0.15, r.end.y - 1.0), 0.0, 0.12, 0.3, Color("e67e22"), 8)
	for k in 3:
		b.box("plain", Vector3(r.get_center().x, FY + 0.06 + k * 0.1, r.get_center().y), Vector3(1.8, 0.1, 1.0), [Color("2e86de"), Color("27ae60"), Color("e74c3c")][k])
	b.collider(Vector3(r.get_center().x, FY + 0.15, r.get_center().y), Vector3(1.8, 0.3, 1.0))
	sb.balls.append({"kind": "football", "pos": Vector3(r.position.x + 2.0, 0.4, r.get_center().y)})
	_door_sign(sb, b, {"doors": [["n", 52.0, 1.4]]}, r, "ED. FÍSICA")


# --------------------------------------------------------------- corredor

static func _corridor(sb: SchoolBuilder, b: WorldBatcher, room: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	if r.size.x > r.size.y:
		# corredor do Bloco A: murais e bancos na parede sul entre portas
		var x := r.position.x + 4.0
		var k := 0
		while x < r.end.x - 2.0:
			var blocked := false
			for door_x: float in room.get("door_xs", [-42.0, -32.0, -22.0, -12.0, 20.0, 32.0, 40.5, 48.5, 52.0, -16.5]):
				if absf(door_x - x) < 1.8:
					blocked = true
			if not blocked:
				if k % 2 == 0:
					wall_rect(b, r, "s", x, 1.7, 1.8, 1.0, Color("c49a6c"))
					for q in 3:
						var pp: Array = wp(r, "s", x - 0.5 + q * 0.5, 1.7 + (0.15 if q % 2 else -0.1), 0.045)
						b.box("plain", pp[0], Vector3(0.38, 0.45, 0.01), [Color("fff59d"), Color("b3e5fc"), Color("f8bbd0")][q], pp[1] + rng.randf_range(-0.12, 0.12), false)
				else:
					var bp: Array = wp(r, "s", x, FY, 0.3)
					Props.bench(b, bp[0], bp[1], 1.6, false)
				k += 1
			x += 4.0
		# bebedouro no corredor (longe das portas das salas)
		var fx := -55.0 if r.position.x < 0 else 15.0
		var fp: Array = wp(r, "n", fx, FY, 0.25)
		Props.water_fountain(b, fp[0], fp[1])
	else:
		# varanda do Bloco B: bancos entre pilares
		for k in 5:
			var z := r.position.y + 6.0 + k * 9.0
			Props.bench(b, Vector3(r.position.x + 0.5, FY, z), PI * 0.5, 1.6, false)


# --------------------------------------------------------------- laboratório

static func _lab(sb: SchoolBuilder, b: WorldBatcher, r: Rect2, rng: RandomNumberGenerator) -> void:
	for i in 2:
		for j in 2:
			var c := Vector3(r.position.x + 3.8 + i * 4.6, FY, r.position.y + 3.0 + j * 4.2)
			b.box("plain", c + Vector3(0, 0.88, 0), Vector3(3.0, 0.06, 1.2), Color("f4f6f7"))
			b.box("wood", c + Vector3(0, 0.43, 0), Vector3(2.9, 0.86, 1.1), Color("5d6d7e"))
			b.collider(c + Vector3(0, 0.45, 0), Vector3(3.0, 0.9, 1.2))
			b.cylinder("metal", c + Vector3(0, 1.1, 0), 0.02, 0.02, 0.4, Color("95a5a6"), 6)
			for k in 4:
				var fc: Color = [Color("e74c3c"), Color("2ecc71"), Color("3498db"), Color("f1c40f")][k]
				b.cylinder("glass", c + Vector3(-1.1 + k * 0.3, 0.98, 0.3), 0.04, 0.06, 0.14, fc, 8)
			for sz: float in [-1.0, 1.0]:
				for sx: float in [-0.9, 0.0, 0.9]:
					var st := c + Vector3(sx, 0, sz * 0.95)
					b.cylinder("plain", st + Vector3(0, 0.62, 0), 0.18, 0.18, 0.05, Color("34495e"), 10)
					b.cylinder("metal", st + Vector3(0, 0.3, 0), 0.03, 0.05, 0.6, Color("7f8c8d"), 6)
					Props.add_seat(st + Vector3(0, -FY, 0), PI if sz > 0 else 0.0, Vector3.ZERO, FY + 0.65, "Sentar")
	# esqueleto didático (simpático)
	var sk := Vector3(r.end.x - 1.2, FY, r.position.y + 1.2)
	b.cylinder("metal", sk + Vector3(0, 0.9, 0), 0.02, 0.02, 1.8, Color("7f8c8d"), 6)
	b.sphere("plain", sk + Vector3(0, 1.65, 0), 0.13, Color("f5f0e1"))
	b.box("plain", sk + Vector3(0, 1.25, 0), Vector3(0.3, 0.4, 0.12), Color("f5f0e1"))
	b.box("plain", sk + Vector3(0, 0.75, 0), Vector3(0.05, 0.6, 0.05), Color("f5f0e1"))
	b.cylinder("plain", sk + Vector3(0, 0.05, 0), 0.25, 0.25, 0.05, Color("566573"), 10)
	var sh: Array = wp(r, "e", r.get_center().y + 3.0, FY, 0.22)
	Props.bookshelf(b, sh[0], sh[1], rng, 2.0, 2.0)
	_poster(sb, b, r, "n", r.get_center().x, 1.8, "TABELA PERIÓDICA", Color("48c9b0"))
	_door_sign(sb, b, {"doors": [["w", -18.0, 1.2]]}, r, "LABORATÓRIO")


# --------------------------------------------------------------- música

static func _music(sb: SchoolBuilder, b: WorldBatcher, r: Rect2, rng: RandomNumberGenerator) -> void:
	var c := Vector3(r.get_center().x + 1.0, FY, r.get_center().y)
	for k in 7:
		var a := PI * 0.5 + (k - 3) * 0.32
		var p := c + Vector3(-cos(a), 0, sin(a)) * 3.0
		p = c + Vector3(-3.0 * sin(a), 0, 3.0 * cos(a))
		var yaw := atan2(c.x - p.x, c.z - p.z)
		b.box("plain", p + Vector3(0, 0.45, 0), Vector3(0.42, 0.05, 0.42), Color("8e44ad"), yaw)
		b.box("plain", p + Vector3(0, 0.75, 0) - Vector3(sin(yaw), 0, cos(yaw)) * 0.2, Vector3(0.42, 0.5, 0.04), Color("7d3c98"), yaw)
		Props.add_seat(p + Vector3(0, -FY, 0), yaw, Vector3.ZERO, FY + 0.47, "Sentar")
	# piano
	var pi := Vector3(r.end.x - 1.5, FY, r.position.y + 2.0)
	b.box("wood", pi + Vector3(0, 0.65, 0), Vector3(1.6, 1.3, 0.6), Color("1c1c1c"), -PI * 0.5)
	b.box("plain", pi + Vector3(-0.35, 0.75, 0), Vector3(0.2, 0.04, 1.5), Color("fdfefe"), 0.0)
	b.collider(pi + Vector3(0, 0.65, 0), Vector3(0.6, 1.3, 1.6))
	# bateria e violões
	var dr := Vector3(r.end.x - 2.0, FY, r.end.y - 2.0)
	b.cylinder("plain", dr + Vector3(0, 0.35, 0), 0.35, 0.35, 0.5, Color("c0392b"), 12)
	b.cylinder("plain", dr + Vector3(0.6, 0.55, 0.2), 0.2, 0.2, 0.2, Color("c0392b"), 10)
	b.cylinder("metal", dr + Vector3(-0.5, 0.9, 0), 0.25, 0.25, 0.02, Color("d4ac0d"), 12)
	for k in 2:
		var g := Vector3(r.position.x + 1.0, FY, r.position.y + 2.0 + k * 0.8)
		b.sphere("wood", g + Vector3(0, 0.35, 0), 0.22, Color("ca6f1e"), Vector3(1, 1.2, 0.4))
		b.box("wood", g + Vector3(0, 0.85, 0), Vector3(0.06, 0.6, 0.04), Color("6e2c00"))
	_poster(sb, b, r, "s", r.get_center().x, 1.8, "NOTAS MUSICAIS", Color("bb8fce"))
	_door_sign(sb, b, {"doors": [["w", 18.0, 1.2]]}, r, "MÚSICA")


# --------------------------------------------------------------- cantina

static func _cantina(sb: SchoolBuilder, b: WorldBatcher, r: Rect2, rng: RandomNumberGenerator) -> void:
	# balcão interno sob a janela de atendimento
	var cx := r.end.x - 0.9
	b.box("tile", Vector3(cx, 0.5, 12.0), Vector3(1.0, 1.0, 6.4), Color("ecf0f1"))
	b.collider(Vector3(cx, 0.5, 12.0), Vector3(1.0, 1.0, 6.4))
	# vitrine de salgados
	b.box("glass", Vector3(cx, 1.25, 11.0), Vector3(0.7, 0.45, 2.4), Color("d6eaf8"))
	var foods := [Color("e59866"), Color("f5cba7"), Color("dc7633"), Color("f8c471")]
	for k in 8:
		b.sphere("plain", Vector3(cx + rng.randf_range(-0.2, 0.2), 1.1, 10.0 + k * 0.27), 0.07, foods[k % 4], Vector3(1, 0.8, 1.2), 8, 5)
	# fogão, geladeira, prateleiras
	var st := Vector3(r.position.x + 0.8, FY, 7.0)
	b.box("metal", st + Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 1.6), Color("bdc3c7"))
	b.box("metal", st + Vector3(0, 0.92, 0), Vector3(0.8, 0.04, 1.6), Color("2c3e50"))
	b.cylinder("metal", st + Vector3(0, 1.05, -0.4), 0.2, 0.2, 0.25, Color("95a5a6"), 10)
	b.collider(st + Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 1.6))
	var fr := Vector3(r.position.x + 0.8, FY, 10.0)
	b.box("metal", fr + Vector3(0, 0.95, 0), Vector3(0.75, 1.9, 0.8), Color("f4f6f7"))
	b.box("metal", fr + Vector3(0.38, 1.2, 0.2), Vector3(0.03, 0.4, 0.04), Color("95a5a6"))
	b.collider(fr + Vector3(0, 0.95, 0), Vector3(0.75, 1.9, 0.8))
	var sh: Array = wp(r, "n", r.get_center().x, FY, 0.22)
	Props.bookshelf(b, sh[0], sh[1], rng, 3.0, 1.8)
	b.box("plain", Vector3(r.get_center().x, 0.45, 15.0), Vector3(3.0, 0.9, 1.0), Color("ecf0f1"))
	b.collider(Vector3(r.get_center().x, 0.45, 15.0), Vector3(3.0, 0.9, 1.0))
	# cardápio e letreiro do lado de fora (voltados para o pátio coberto)
	var outer := sb.chunk("cantina_outer", 60.0)
	var mx := r.end.x + T * 0.5 + 0.04
	outer.box("plain", Vector3(mx, 2.85, 12.0), Vector3(0.04, 0.6, 5.0), Color("c0392b"))
	sb.add_label("CANTINA", Vector3(mx + 0.03, 2.85, 12.0), PI * 0.5, 96, Color.WHITE, Color(0, 0, 0, 0), 0.006, 60.0)
	sb.labels[-1]["parent"] = "cantina_outer"
	outer.box("plain", Vector3(mx, 1.7, 16.5), Vector3(0.04, 1.6, 2.0), Color("2d3436"))
	sb.add_label("CARDÁPIO\nCoxinha ...... R$ 4\nPão de queijo .. R$ 3\nPastel ...... R$ 5\nSuco ........ R$ 3\nBolo ........ R$ 3", Vector3(mx + 0.03, 1.7, 16.5), PI * 0.5, 32, Color("fdfefe"), Color(0, 0, 0, 0), 0.0055, 25.0)
	sb.labels[-1]["parent"] = "cantina_outer"
	sb.add_zone("Fila da Cantina", SchoolBuilder.R(-22, 8, -19, 16), false, "", 9, Color(0.9, 0.7, 0.3))



# --------------------------------------------------------------- salas novas do Bloco A

static func _enfeite_titulo(sb: SchoolBuilder, b: WorldBatcher, r: Rect2, side: String, text: String, col: Color) -> void:
	var along := r.get_center().x if side in ["n", "s"] else r.get_center().y
	var p := wall_rect(b, r, side, along, 2.55, minf(r.size.x - 2.0, 5.0), 0.6, col, "plain", 0.03)
	var rot: float = wp(r, side, along, 0)[1]
	sb.add_label(text, p + Vector3(0, 0, 1).rotated(Vector3.UP, rot) * 0.02, rot, 52, Color.WHITE, Color(0, 0, 0, 0), 0.006, 25.0)


static func _nurse(sb: SchoolBuilder, b: WorldBatcher, room: Dictionary, r: Rect2) -> void:
	# duas macas, biombo, armário de remédios com cruz, balança e pia
	for k in 2:
		var o := Vector3(r.position.x + 2.2 + k * 3.6, FY, r.position.y + 1.6)
		b.box("metal", o + Vector3(0, 0.35, 0.8), Vector3(0.9, 0.7, 1.9), Color("bdc3c7"))
		b.box("plain", o + Vector3(0, 0.75, 0.8), Vector3(0.88, 0.12, 1.86), Color("ffffff"))
		b.box("plain", o + Vector3(0, 0.86, 0.15), Vector3(0.6, 0.12, 0.35), Color("dff3f2"))
		b.collider(o + Vector3(0, 0.4, 0.8), Vector3(0.9, 0.8, 1.9))
		Props.add_seat(o + Vector3(0, 0, 1.2), PI * 0.5, Vector3.ZERO, FY + 0.8, "Deitar um pouco")
		# biombo
		b.box("plain", o + Vector3(1.6, 0.9, 0.9), Vector3(0.04, 1.6, 2.0), Color("d6f0ee"))
	var cab: Array = wp(r, "e", r.get_center().y, FY + 1.0, 0.25)
	b.box("wood", cab[0], Vector3(1.4, 2.0, 0.45), Color("ffffff"), cab[1])
	b.collider(cab[0], Vector3(1.4, 2.0, 0.45), cab[1])
	var cross: Array = wp(r, "e", r.get_center().y, FY + 1.5, 0.49)
	b.box("plain", cross[0], Vector3(0.5, 0.14, 0.02), Color("e74c3c"), cross[1], false)
	b.box("plain", cross[0], Vector3(0.14, 0.5, 0.02), Color("e74c3c"), cross[1], false)
	_poster(sb, b, r, "w", r.get_center().y, 1.7, "LAVE AS MÃOS", Color("3498db"))
	_enfeite_titulo(sb, b, r, "n", "ENFERMARIA", Color("16a085"))
	_door_sign(sb, b, room, r, "ENFERMARIA")


static func _refectory(sb: SchoolBuilder, b: WorldBatcher, room: Dictionary, r: Rect2) -> void:
	var cols := [Color("f6d365"), Color("a8e6cf"), Color("ffb3a7")]
	var k := 0
	var x := r.position.x + 3.0
	while x < r.end.x - 2.5:
		Props.cafeteria_table(b, Vector3(x, FY, r.position.y + 3.0), PI * 0.5, 3.2, cols[k % 3])
		Props.cafeteria_table(b, Vector3(x, FY, r.end.y - 3.4), PI * 0.5, 3.2, cols[(k + 1) % 3])
		x += 4.0
		k += 1
	# balcão de frutas e bebedouro
	var fr: Array = wp(r, "w", r.get_center().y, FY + 0.45, 0.45)
	b.box("wood", fr[0], Vector3(3.0, 0.9, 0.7), Color("8d6e63"), fr[1])
	b.collider(fr[0], Vector3(3.0, 0.9, 0.7), fr[1])
	for i in 6:
		b.sphere("plain", fr[0] + Vector3(0, 0.55, -1.1 + i * 0.44).rotated(Vector3.UP, 0.0), 0.11, [Color("e74c3c"), Color("f39c12"), Color("f1c40f")][i % 3], Vector3.ONE, 8, 5)
	_poster(sb, b, r, "n", r.position.x + 3.0, 1.8, "COMA FRUTAS!", Color("27ae60"))
	_poster(sb, b, r, "n", r.end.x - 3.0, 1.8, "PRATO COLORIDO", Color("e67e22"))
	_enfeite_titulo(sb, b, r, "e", "REFEITÓRIO", Color("e67e22"))
	_door_sign(sb, b, room, r, "REFEITÓRIO")


static func _auditorium(sb: SchoolBuilder, b: WorldBatcher, room: Dictionary, r: Rect2) -> void:
	# palco/tela no lado oeste, fileiras de cadeiras estofadas viradas para ele
	var sx := r.position.x + 1.6
	b.box("wood", Vector3(sx, FY + 0.25, r.get_center().y), Vector3(2.6, 0.5, r.size.y - 0.6), Color("8b5a2b"))
	b.collider(Vector3(sx, FY + 0.25, r.get_center().y), Vector3(2.6, 0.5, r.size.y - 0.6))
	var scr: Array = wp(r, "w", r.get_center().y, 2.0, 0.04)
	b.box("plain", scr[0], Vector3(minf(r.size.y - 2.0, 6.0), 2.2, 0.03), Color("f8f8f8"), scr[1], false)
	sb.add_label(str(room.get("screen", "SESSÃO DE CINEMA\nHoje: O ciclo da água")), scr[0] + Vector3(0.03, 0, 0), scr[1], 48, Color("2c3e50"), Color(0, 0, 0, 0), 0.006, 22.0)
	# cortinas
	for zz: float in [r.position.y + 0.6, r.end.y - 0.6]:
		b.box("plain", Vector3(sx, 2.0, zz), Vector3(0.2, 3.2, 1.0), Color("8e1b2b"))
	var x := sx + 2.6
	var row := 0
	while x < r.end.x - 1.0:
		var z := r.position.y + 1.2
		while z < r.end.y - 1.0:
			if absf(z - r.get_center().y) > 0.7:
				var o := Vector3(x, FY, z)
				b.box("plain", o + Vector3(0, 0.42, 0), Vector3(0.5, 0.12, 0.5), Color("a93226"))
				b.box("plain", o + Vector3(0.22, 0.75, 0), Vector3(0.1, 0.6, 0.5), Color("a93226"))
				b.box("metal", o + Vector3(0, 0.18, 0), Vector3(0.08, 0.36, 0.4), Color("2c3e50"))
				Props.add_seat(o, -PI * 0.5, Vector3.ZERO, FY + 0.48, "Sentar")
			z += 0.75
		b.collider(Vector3(x + 0.05, 0.5, r.get_center().y), Vector3(0.55, 1.0, r.size.y - 2.4))
		x += 1.5
		row += 1
	_door_sign(sb, b, room, r, room.name.to_upper())


static func _toys(sb: SchoolBuilder, b: WorldBatcher, room: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var c := r.get_center()
	# tapete de EVA colorido em quadrados
	var cols := [Color("ff6b6b"), Color("ffd93d"), Color("6bcB77"), Color("4d96ff"), Color("c77dff")]
	for i in 6:
		for j in 4:
			b.slab("plain", Vector3(c.x - 3.75 + i * 1.5, FY + 0.012, c.y - 2.25 + j * 1.5), Vector3(1.48, 0.02, 1.48), cols[(i + j) % cols.size()])
	# piscina de bolinhas
	var pit := Vector3(r.end.x - 2.6, FY, r.position.y + 2.4)
	b.box("plain", pit + Vector3(0, 0.3, 0), Vector3(3.0, 0.6, 3.0), Color("4d96ff"))
	b.collider(pit + Vector3(0, 0.3, 0), Vector3(3.0, 0.6, 3.0))
	for i in 40:
		b.sphere("plain", pit + Vector3(rng.randf_range(-1.3, 1.3), 0.62, rng.randf_range(-1.3, 1.3)), 0.12, cols[i % cols.size()], Vector3.ONE, 6, 4, false)
	# prateleiras baixas com brinquedos
	for k in 3:
		var sp: Array = wp(r, "e", r.position.y + 5.0 + k * 1.6, FY + 0.45, 0.3)
		b.box("wood", sp[0], Vector3(1.4, 0.9, 0.45), Color("f4d35e"), sp[1])
		b.collider(sp[0], Vector3(1.4, 0.9, 0.45), sp[1])
		for t in 3:
			b.box("plain", sp[0] + Vector3(0, 0.55, -0.45 + t * 0.45).rotated(Vector3.UP, 0.0), Vector3(0.25, 0.25, 0.25), cols[(k + t) % cols.size()])
	# casinha de bonecas e pufes
	var hp := Vector3(r.position.x + 2.2, FY, r.position.y + 2.2)
	b.box("wood", hp + Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 1.2), Color("ffb4c6"))
	b.box_xf("roof", Transform3D(Basis(Vector3.FORWARD, 0.0), hp + Vector3(0, 1.35, 0)), Vector3(1.8, 0.3, 1.4), Color("c0392b"))
	b.collider(hp + Vector3(0, 0.7, 0), Vector3(1.6, 1.4, 1.2))
	for k in 4:
		var bp := Vector3(c.x - 3.0 + k * 2.0, FY, r.end.y - 1.4)
		b.sphere("plain", bp + Vector3(0, 0.28, 0), 0.42, cols[k], Vector3(1, 0.7, 1), 10, 6)
		Props.add_seat(bp, PI, Vector3.ZERO, FY + 0.45, "Sentar no pufe")
	_enfeite_titulo(sb, b, r, "w", "BRINQUEDOTECA", Color("ff6b9a"))
	_door_sign(sb, b, room, r, "BRINQUEDOTECA")


static func _games(sb: SchoolBuilder, b: WorldBatcher, room: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var c := r.get_center()
	# mesa de pingue-pongue (se couber) e mesas de xadrez/dama
	if r.size.x >= 14.0 and room.name != "Sala de Xadrez":
		var tp := Vector3(c.x, FY, c.y)
		b.box("plain", tp + Vector3(0, 0.74, 0), Vector3(2.74, 0.05, 1.52), Color("1e5aa8"))
		b.box("plain", tp + Vector3(0, 0.77, 0), Vector3(0.02, 0.01, 1.52), Color.WHITE, 0.0, false)
		b.box("plain", tp + Vector3(0, 0.85, 0), Vector3(0.02, 0.15, 1.6), Color("ecf0f1"), 0.0, false)
		for lx: float in [-1.1, 1.1]:
			b.box("metal", tp + Vector3(lx, 0.36, 0), Vector3(0.08, 0.72, 1.2), Color("2c3e50"))
		b.collider(tp + Vector3(0, 0.4, 0), Vector3(2.74, 0.8, 1.52))
	var x := r.position.x + 2.0
	while x < r.end.x - 1.5:
		for z: float in [r.position.y + 2.0, r.end.y - 2.2]:
			if r.size.x >= 14.0 and room.name != "Sala de Xadrez" and absf(x - c.x) < 2.4:
				continue
			var o := Vector3(x, FY, z)
			b.box("wood", o + Vector3(0, 0.7, 0), Vector3(0.8, 0.04, 0.8), Color("d7b98e"))
			b.box("metal", o + Vector3(0, 0.35, 0), Vector3(0.08, 0.7, 0.08), Color("2c3e50"))
			# tabuleiro quadriculado
			for i in 4:
				for j in 4:
					if (i + j) % 2 == 0:
						b.box("plain", o + Vector3(-0.21 + i * 0.14, 0.725, -0.21 + j * 0.14), Vector3(0.14, 0.006, 0.14), Color("2c2c2c"), 0.0, false)
			b.collider(o + Vector3(0, 0.37, 0), Vector3(0.8, 0.74, 0.8))
			for sd: float in [-1.0, 1.0]:
				var so := o + Vector3(sd * 0.75, 0, 0)
				b.box("wood", so + Vector3(0, 0.42, 0), Vector3(0.38, 0.05, 0.38), Color("8e5b3a"))
				Props.add_seat(so, -PI * 0.5 * sd, Vector3.ZERO, FY + 0.45)
		x += 3.0
	_enfeite_titulo(sb, b, r, "n" if _door_side(room) == "s" else "s", room.name.to_upper(), Color("2e8b57"))
	_door_sign(sb, b, room, r, room.name.to_upper())


static func _dance(sb: SchoolBuilder, b: WorldBatcher, room: Dictionary, r: Rect2) -> void:
	# parede de espelhos com barra e caixa de som
	var mp: Array = wp(r, "w", r.get_center().y, 1.4, 0.04)
	b.box("glass", mp[0], Vector3(r.size.y - 1.6, 2.2, 0.03), Color("dfeff7"), mp[1], false)
	var bar: Array = wp(r, "w", r.get_center().y, 1.0, 0.3)
	b.box("wood", bar[0], Vector3(r.size.y - 1.6, 0.06, 0.06), Color("c49a6c"), bar[1])
	b.collider(bar[0], Vector3(r.size.y - 1.6, 1.0, 0.1), bar[1])
	for zz: float in [r.position.y + 1.0, r.end.y - 1.0]:
		var sp := Vector3(r.end.x - 0.8, FY + 0.5, zz)
		b.box("plain", sp, Vector3(0.6, 1.0, 0.6), Color("222222"))
		b.cylinder_xf("plain", Transform3D(Basis(Vector3.FORWARD, PI * 0.5), sp + Vector3(-0.31, 0.15, 0)), 0.2, 0.2, 0.02, Color("555555"), 12)
		b.collider(sp, Vector3(0.6, 1.0, 0.6))
	_enfeite_titulo(sb, b, r, "e", "DANÇA", Color("9b59b6"))
	_door_sign(sb, b, room, r, "SALA DE DANÇA")


static func _mezzanine(sb: SchoolBuilder, b: WorldBatcher, r: Rect2) -> void:
	# bancos e vasos em volta do vão da escada, mural de boas-vindas
	for sx: float in [-1.0, 1.0]:
		Props.bench(b, Vector3(sx * 8.6, FY, 30.0), -PI * 0.5 * sx, 1.8, true)
		b.cylinder("plain", Vector3(sx * 8.8, FY + 0.3, 25.2), 0.3, 0.25, 0.6, Color("c0392b").darkened(0.3), 10)
		b.sphere("foliage", Vector3(sx * 8.8, FY + 1.05, 25.2), 0.5, Color("3f8a3a"), Vector3(1, 1.4, 1), 8, 6)
		b.collider_cyl(Vector3(sx * 8.8, FY + 0.5, 25.2), 0.32, 1.0)
	var wp2: Array = wp(r, "n", 0.0, 2.2, 0.03)
	b.box("plain", wp2[0], Vector3(5.0, 0.9, 0.03), Color("3aa45b"), wp2[1])
	sb.add_label("1º ANDAR · SALAS DE AULA", wp2[0] + Vector3(0, 0, 0.025), wp2[1], 56, Color.WHITE, Color(0, 0, 0, 0), 0.006, 30.0)
	for side: String in ["w", "e"]:
		var sp: Array = wp(r, side, 36.0, 3.1, 0.03)
		b.box("plain", sp[0], Vector3(3.0, 0.42, 0.03), Color("2f5fa8"), sp[1])
		sb.add_label("SALAS 1 A 5 · 13 · 14" if side == "w" else "SALAS 6 A 10", sp[0] + Vector3(0, 0, 1).rotated(Vector3.UP, sp[1]) * 0.02, sp[1], 40, Color.WHITE, Color(0, 0, 0, 0), 0.006, 25.0)
