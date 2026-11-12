class_name ChessRules
extends RefCounted
## Regras de xadrez (completas: xeque, xeque-mate, afogamento, roque, en passant
## e promoção a dama) e um adversário simples (busca de 1 ou 2 lances).
## Tabuleiro: Array de 64 Strings ("" = vazio; maiúscula = brancas, minúscula =
## pretas). Índice = linha * 8 + coluna; a linha 0 é a do lado das pretas.

const VALUE := {"p": 100, "n": 300, "b": 320, "r": 500, "q": 900, "k": 0}
const KNIGHT := [[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]]
const KING := [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]]
const DIAG := [[-1, -1], [-1, 1], [1, -1], [1, 1]]
const ORTHO := [[-1, 0], [1, 0], [0, -1], [0, 1]]


static func new_game() -> Dictionary:
	var b: Array = []
	b.resize(64)
	b.fill("")
	var back := ["r", "n", "b", "q", "k", "b", "n", "r"]
	for c in 8:
		b[c] = back[c]
		b[8 + c] = "p"
		b[48 + c] = "P"
		b[56 + c] = back[c].to_upper()
	return {"b": b, "turn": "w", "castle": "KQkq", "ep": -1}


static func is_white(p: String) -> bool:
	return p != "" and p == p.to_upper()


static func side_of(p: String) -> String:
	return "" if p == "" else ("w" if is_white(p) else "b")


static func _on(r: int, c: int) -> bool:
	return r >= 0 and r < 8 and c >= 0 and c < 8


## A casa `sq` é atacada por alguma peça do lado `by` ("w"/"b")?
static func attacked(b: Array, sq: int, by: String) -> bool:
	var r := sq / 8
	var c := sq % 8
	var white := by == "w"
	# peões
	var pr := r + (1 if white else -1)
	for dc in [-1, 1]:
		if _on(pr, c + dc) and b[pr * 8 + c + dc] == ("P" if white else "p"):
			return true
	for d in KNIGHT:
		if _on(r + d[0], c + d[1]) and b[(r + d[0]) * 8 + c + d[1]] == ("N" if white else "n"):
			return true
	for d in KING:
		if _on(r + d[0], c + d[1]) and b[(r + d[0]) * 8 + c + d[1]] == ("K" if white else "k"):
			return true
	for dirs in [DIAG, ORTHO]:
		for d in dirs:
			var rr: int = r + d[0]
			var cc: int = c + d[1]
			while _on(rr, cc):
				var p: String = b[rr * 8 + cc]
				if p != "":
					if is_white(p) == white:
						var t := p.to_lower()
						if t == "q" or (t == "b" and dirs == DIAG) or (t == "r" and dirs == ORTHO):
							return true
					break
				rr += d[0]
				cc += d[1]
	return false


static func king_sq(b: Array, side: String) -> int:
	var k := "K" if side == "w" else "k"
	return b.find(k)


static func in_check(st: Dictionary, side: String) -> bool:
	var k := king_sq(st.b, side)
	return k >= 0 and attacked(st.b, k, "b" if side == "w" else "w")


## Lances sem checar se deixam o próprio rei em xeque. Lance = [de, para].
static func pseudo_moves(st: Dictionary) -> Array:
	var b: Array = st.b
	var side: String = st.turn
	var white := side == "w"
	var out: Array = []
	for sq in 64:
		var p: String = b[sq]
		if p == "" or is_white(p) != white:
			continue
		var r := sq / 8
		var c := sq % 8
		match p.to_lower():
			"p":
				var dir := -1 if white else 1
				var r1 := r + dir
				if _on(r1, c) and b[r1 * 8 + c] == "":
					out.append([sq, r1 * 8 + c])
					var start := 6 if white else 1
					var r2 := r + dir * 2
					if r == start and b[r2 * 8 + c] == "":
						out.append([sq, r2 * 8 + c])
				for dc in [-1, 1]:
					if not _on(r1, c + dc):
						continue
					var t: int = r1 * 8 + c + dc
					var q: String = b[t]
					if (q != "" and is_white(q) != white) or t == int(st.ep):
						out.append([sq, t])
			"n":
				for d in KNIGHT:
					_step(b, white, r + d[0], c + d[1], sq, out)
			"k":
				for d in KING:
					_step(b, white, r + d[0], c + d[1], sq, out)
				_castles(st, sq, out)
			"b":
				_slide(b, white, r, c, sq, DIAG, out)
			"r":
				_slide(b, white, r, c, sq, ORTHO, out)
			"q":
				_slide(b, white, r, c, sq, DIAG, out)
				_slide(b, white, r, c, sq, ORTHO, out)
	return out


static func _step(b: Array, white: bool, r: int, c: int, from: int, out: Array) -> void:
	if not _on(r, c):
		return
	var q: String = b[r * 8 + c]
	if q == "" or is_white(q) != white:
		out.append([from, r * 8 + c])


static func _slide(b: Array, white: bool, r: int, c: int, from: int, dirs: Array, out: Array) -> void:
	for d in dirs:
		var rr: int = r + d[0]
		var cc: int = c + d[1]
		while _on(rr, cc):
			var q: String = b[rr * 8 + cc]
			if q == "":
				out.append([from, rr * 8 + cc])
			else:
				if is_white(q) != white:
					out.append([from, rr * 8 + cc])
				break
			rr += d[0]
			cc += d[1]


static func _castles(st: Dictionary, sq: int, out: Array) -> void:
	var b: Array = st.b
	var white: bool = st.turn == "w"
	var home := 60 if white else 4
	if sq != home:
		return
	var enemy := "b" if white else "w"
	var rights: String = st.castle
	if attacked(b, home, enemy):
		return
	# pequeno (lado do rei)
	if (("K" if white else "k") in rights) and b[home + 1] == "" and b[home + 2] == "" and b[home + 3] == ("R" if white else "r"):
		if not attacked(b, home + 1, enemy) and not attacked(b, home + 2, enemy):
			out.append([home, home + 2])
	# grande (lado da dama)
	if (("Q" if white else "q") in rights) and b[home - 1] == "" and b[home - 2] == "" and b[home - 3] == "" and b[home - 4] == ("R" if white else "r"):
		if not attacked(b, home - 1, enemy) and not attacked(b, home - 2, enemy):
			out.append([home, home - 2])


## Faz o lance e devolve o novo estado (o original não muda).
static func apply(st: Dictionary, m: Array) -> Dictionary:
	var b: Array = (st.b as Array).duplicate()
	var from: int = m[0]
	var to: int = m[1]
	var p: String = b[from]
	var white := is_white(p)
	var t := p.to_lower()
	var ep := -1
	# en passant: tira o peão que passou
	if t == "p" and to == int(st.ep) and b[to] == "":
		b[to + (8 if white else -8)] = ""
	if t == "p" and absi(to - from) == 16:
		ep = (from + to) / 2
	# roque: a torre pula
	if t == "k" and absi(to - from) == 2:
		if to > from:
			b[to - 1] = b[to + 1]
			b[to + 1] = ""
		else:
			b[to + 1] = b[to - 2]
			b[to - 2] = ""
	b[to] = p
	b[from] = ""
	# promoção: vira dama
	if t == "p" and (to / 8 == 0 or to / 8 == 7):
		b[to] = "Q" if white else "q"
	var rights: String = st.castle
	if t == "k":
		rights = rights.replace("K", "").replace("Q", "") if white else rights.replace("k", "").replace("q", "")
	for pair in [[63, "K"], [56, "Q"], [7, "k"], [0, "q"]]:
		if from == pair[0] or to == pair[0]:
			rights = rights.replace(pair[1], "")
	return {"b": b, "turn": "b" if white else "w", "castle": rights, "ep": ep}


static func legal_moves(st: Dictionary) -> Array:
	var out: Array = []
	var side: String = st.turn
	for m in pseudo_moves(st):
		if not in_check(apply(st, m), side):
			out.append(m)
	return out


## "" (segue o jogo), "mate" (quem joga perdeu) ou "empate" (afogado/só reis).
static func status(st: Dictionary) -> String:
	if legal_moves(st).is_empty():
		return "mate" if in_check(st, st.turn) else "empate"
	var pieces := 0
	for p in st.b:
		if p != "" and p.to_lower() != "k":
			pieces += 1
	return "empate" if pieces == 0 else ""


## Pontos do ponto de vista das brancas (material + centro + avanço dos peões).
static func evaluate(st: Dictionary) -> int:
	var s := 0
	var b: Array = st.b
	for sq in 64:
		var p: String = b[sq]
		if p == "":
			continue
		var t := p.to_lower()
		var v: int = VALUE[t]
		var r := sq / 8
		var c := sq % 8
		var center := 3 - int(maxf(absf(3.5 - r), absf(3.5 - c)))
		if t == "n" or t == "b":
			v += center * 8
		elif t == "p":
			v += ((6 - r) if is_white(p) else (r - 1)) * 6 + (center * 3 if c in [3, 4] else 0)
		s += v if is_white(p) else -v
	return s


static func _negamax(st: Dictionary, depth: int, alpha: int, beta: int) -> int:
	var sign := 1 if st.turn == "w" else -1
	if depth == 0:
		return evaluate(st) * sign
	var moves := legal_moves(st)
	if moves.is_empty():
		return -100000 if in_check(st, st.turn) else 0
	var best := -1000000
	for m in moves:
		var v := -_negamax(apply(st, m), depth - 1, -beta, -alpha)
		if v > best:
			best = v
		alpha = maxi(alpha, v)
		if alpha >= beta:
			break
	return best


## Lance do computador. level 0 = fácil (às vezes erra), 1 = normal.
static func pick_move(st: Dictionary, level: int) -> Array:
	var moves := legal_moves(st)
	if moves.is_empty():
		return []
	moves.shuffle()
	if level == 0 and randf() < 0.3:
		return moves[0]
	var depth := 1 if level == 0 else 2
	# capturas primeiro: a poda corta mais
	moves.sort_custom(func(a, b2): return st.b[a[1]] != "" and st.b[b2[1]] == "")
	var best: Array = moves[0]
	var best_v := -1000000
	for m in moves:
		var v := -_negamax(apply(st, m), depth - 1, -1000000, 1000000)
		if v > best_v:
			best_v = v
			best = m
	return best
