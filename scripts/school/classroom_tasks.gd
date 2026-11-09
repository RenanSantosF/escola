class_name ClassroomTasks
extends RefCounted
## Gerador de tarefas rápidas da aula (lógica pura, testável).
## Tipos: math, word, quiz, order, match, find.
## Cada tarefa: {type, subject, prompt, ...}
##  - choice (math/word/quiz): options[], answer (índice)
##  - order: items[] (embaralhados), answer_order[] (índices na ordem certa)
##  - match: left[], right[] (embaralhado), pairs {i_left: i_right}
##  - find: item (tipo de objeto), item_name

const WORDS := [
	"ESCOLA", "RECREIO", "CADERNO", "LÁPIS", "BORRACHA", "MOCHILA", "LANCHE", "AMIGO", "QUADRA",
	"PROFESSORA", "CANTINA", "FIGURINHA", "BOLA", "LOUSA", "LIVRO", "ESTOJO", "RÉGUA", "SINAL",
	"PÁTIO", "CARTEIRA", "APAGADOR", "UNIFORME", "MERENDA", "COLEGA", "BRINCADEIRA",
]
const QUIZ := [
	["Qual é a capital do Brasil?", ["Brasília", "São Paulo", "Rio de Janeiro", "Salvador"]],
	["Quantas patas tem uma aranha?", ["8", "6", "4", "10"]],
	["Qual planeta é conhecido como planeta vermelho?", ["Marte", "Júpiter", "Vênus", "Saturno"]],
	["Que animal é o maior do mundo?", ["Baleia-azul", "Elefante", "Girafa", "Tubarão"]],
	["Quantos dias tem uma semana?", ["7", "5", "10", "6"]],
	["Qual é a cor do céu num dia limpo?", ["Azul", "Verde", "Roxo", "Laranja"]],
	["A água ferve a quantos graus Celsius?", ["100", "50", "0", "200"]],
	["Qual o maior rio do Brasil?", ["Amazonas", "São Francisco", "Paraná", "Tietê"]],
	["Quantos meses tem um ano?", ["12", "10", "11", "13"]],
	["Qual destes é um mamífero?", ["Golfinho", "Tubarão", "Sapo", "Galinha"]],
	["O que as plantas precisam para fazer fotossíntese?", ["Luz do sol", "Areia", "Música", "Sal"]],
	["Quantas cores tem o arco-íris?", ["7", "5", "3", "9"]],
	["Em que continente fica o Brasil?", ["América do Sul", "Europa", "África", "Ásia"]],
	["Quem escreveu o Sítio do Picapau Amarelo?", ["Monteiro Lobato", "Machado de Assis", "Cecília Meireles", "Ziraldo"]],
	["Qual é o oposto de 'quente'?", ["Frio", "Morno", "Grande", "Alto"]],
	["Qual a forma que tem 3 lados?", ["Triângulo", "Quadrado", "Círculo", "Retângulo"]],
]
const SENTENCES := [
	["O", "sinal", "já", "tocou"], ["Eu", "adoro", "o", "recreio"], ["A", "bola", "é", "redonda"],
	["Meu", "amigo", "joga", "futebol"], ["Hoje", "tem", "pão", "de", "queijo"], ["A", "professora", "é", "legal"],
]
const MATCH_SETS := [
	{"title": "Ligue o animal à sua casa", "pairs": [["Abelha", "Colmeia"], ["Pássaro", "Ninho"], ["Cachorro", "Casinha"], ["Peixe", "Aquário"]]},
	{"title": "Ligue o número ao seu nome", "pairs": [["3", "Três"], ["7", "Sete"], ["10", "Dez"], ["15", "Quinze"]]},
	{"title": "Ligue o objeto à matéria", "pairs": [["Globo", "Geografia"], ["Régua", "Matemática"], ["Microscópio", "Ciências"], ["Dicionário", "Português"]]},
	{"title": "Ligue o filhote ao animal", "pairs": [["Pintinho", "Galinha"], ["Bezerro", "Vaca"], ["Girino", "Sapo"], ["Potro", "Cavalo"]]},
	{"title": "Ligue a cor à fruta", "pairs": [["Amarela", "Banana"], ["Vermelho", "Morango"], ["Roxa", "Uva"], ["Verde", "Limão"]]},
]
const FIND_ITEMS := [
	{"item": "apagador", "name": "o apagador"}, {"item": "livro", "name": "o livro de histórias"},
	{"item": "giz", "name": "a caixa de giz"}, {"item": "caderno", "name": "o caderno de chamada"},
]

var rng := RandomNumberGenerator.new()
var day := 1


func _init(seed_value := 0, day_number := 1) -> void:
	rng.seed = seed_value if seed_value != 0 else randi()
	day = day_number


## Sequência variada de tarefas para uma aula (sem repetir tipo seguido).
func make_lesson(count: int, allow_find := true) -> Array:
	var types := ["math", "word", "quiz", "order", "match"]
	if allow_find:
		types.append("find")
	types.shuffle()
	var out := []
	var last := ""
	var i := 0
	while out.size() < count:
		var t: String = types[i % types.size()]
		i += 1
		if t == last:
			continue
		# no máximo uma tarefa de "achar objeto" por aula
		if t == "find" and out.any(func(x): return x.type == "find"):
			continue
		out.append(make(t))
		last = t
	return out


func make(type: String) -> Dictionary:
	match type:
		"math": return _math()
		"word": return _word()
		"quiz": return _quiz()
		"order": return _order()
		"match": return _match()
		"find": return _find()
	return _math()


func _shuffle_options(correct: String, wrong: Array) -> Dictionary:
	var opts := [correct]
	for w in wrong:
		if not w in opts and opts.size() < 4:
			opts.append(w)
	var guard := 0
	while opts.size() < 4 and guard < 50:
		guard += 1
		var extra := str(rng.randi_range(0, 30))
		if not extra in opts:
			opts.append(extra)
	opts.shuffle()
	return {"options": opts, "answer": opts.find(correct)}


func _math() -> Dictionary:
	var level := mini(day, 6)
	var ops := ["+", "-"]
	if level >= 2:
		ops.append("x")
	var op: String = ops[rng.randi() % ops.size()]
	var a: int
	var b: int
	var res: int
	match op:
		"+":
			a = rng.randi_range(1, 5 + level * 4)
			b = rng.randi_range(1, 5 + level * 4)
			res = a + b
		"-":
			a = rng.randi_range(5, 10 + level * 4)
			b = rng.randi_range(1, a)
			res = a - b
		_:
			a = rng.randi_range(2, 3 + level)
			b = rng.randi_range(2, 5 + level)
			res = a * b
	var wrong := [str(res + 1), str(maxi(res - 1, 0)), str(res + rng.randi_range(2, 5)), str(maxi(res - rng.randi_range(2, 4), 0))]
	var t := _shuffle_options(str(res), wrong)
	t.merge({"type": "math", "subject": "Matemática", "prompt": "Quanto é %d %s %d?" % [a, "×" if op == "x" else op, b]})
	return t


func _word() -> Dictionary:
	var w: String = WORDS[rng.randi() % WORDS.size()]
	var idx := rng.randi_range(1, w.length() - 2)
	var letter := w[idx]
	var masked := w.substr(0, idx) + "_" + w.substr(idx + 1)
	var letters := "ABCDEFGILMNOPRSTUV"
	var wrong := []
	while wrong.size() < 3:
		var l := letters[rng.randi() % letters.length()]
		if l != letter and not l in wrong:
			wrong.append(l)
	var t := _shuffle_options(letter, wrong)
	t.merge({"type": "word", "subject": "Português", "prompt": "Complete a palavra:\n%s" % masked, "word": w})
	return t


func _quiz() -> Dictionary:
	var q: Array = QUIZ[rng.randi() % QUIZ.size()]
	var opts: Array = q[1]
	var t := _shuffle_options(opts[0], opts.slice(1))
	t.merge({"type": "quiz", "subject": "Conhecimentos gerais", "prompt": q[0]})
	return t


func _order() -> Dictionary:
	if rng.randf() < 0.5:
		var nums := []
		while nums.size() < 4:
			var n := rng.randi_range(1, 20 + day * 10)
			if not n in nums:
				nums.append(n)
		var items := nums.map(func(x): return str(x))
		items.shuffle()
		var sorted_nums := nums.duplicate()
		sorted_nums.sort()
		var order := sorted_nums.map(func(x): return items.find(str(x)))
		return {"type": "order", "subject": "Matemática", "prompt": "Toque nos números do MENOR para o MAIOR", "items": items, "answer_order": order}
	var sentence: Array = SENTENCES[rng.randi() % SENTENCES.size()]
	var items2 := sentence.duplicate()
	items2.shuffle()
	var order2 := []
	var used := {}
	for word in sentence:
		for i in items2.size():
			if items2[i] == word and not used.has(i):
				used[i] = true
				order2.append(i)
				break
	return {"type": "order", "subject": "Português", "prompt": "Toque nas palavras para formar a frase", "items": items2, "answer_order": order2}


func _match() -> Dictionary:
	var mset: Dictionary = MATCH_SETS[rng.randi() % MATCH_SETS.size()]
	var pairs: Array = mset.pairs.duplicate()
	pairs.shuffle()
	pairs = pairs.slice(0, 3)
	var left := pairs.map(func(p): return p[0])
	var right := pairs.map(func(p): return p[1])
	right.shuffle()
	var mapping := {}
	for i in pairs.size():
		mapping[i] = right.find(pairs[i][1])
	return {"type": "match", "subject": "Associação", "prompt": mset.title, "left": left, "right": right, "pairs": mapping}


func _find() -> Dictionary:
	var f: Dictionary = FIND_ITEMS[rng.randi() % FIND_ITEMS.size()]
	return {"type": "find", "subject": "Ajude a professora", "prompt": "Você pode me trazer %s?\nEstá em algum lugar da sala." % f.name, "item": f.item, "item_name": f.name}


## Avaliação genérica usada pela UI e pelos testes.
static func check_choice(task: Dictionary, chosen: int) -> bool:
	return chosen == int(task.answer)


static func check_order(task: Dictionary, sequence: Array) -> bool:
	if sequence.size() != task.answer_order.size():
		return false
	# aceita itens repetidos iguais (ex.: duas palavras iguais)
	for i in sequence.size():
		if task.items[sequence[i]] != task.items[task.answer_order[i]]:
			return false
	return true


static func check_match(task: Dictionary, left_i: int, right_i: int) -> bool:
	return int(task.pairs.get(left_i, -1)) == right_i
