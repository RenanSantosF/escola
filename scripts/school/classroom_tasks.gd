class_name ClassroomTasks
extends RefCounted
## Gerador de tarefas da aula (lógica pura, testável).
## Nível 1–9 = ano escolar (definido pela idade real + ajuste automático
## pelo desempenho). 10 matérias; cada aula tem uma matéria principal.
## Tipos: math, word, quiz, order, match, find.

const SUBJECTS := ["Matemática", "Português", "Ciências", "Geografia", "História", "Inglês", "Artes", "Física", "Química", "Música"]

## [nível mín, nível máx, pergunta, certa, errada1, errada2, errada3]
const BANK := {
	"Português": [
		[1, 3, "Qual palavra começa com a mesma letra de BOLA?", "Bota", "Casa", "Dado", "Pato"],
		[1, 3, "Quantas sílabas tem a palavra BORBOLETA?", "4", "3", "5", "2"],
		[2, 4, "Qual é o plural de PÃO?", "Pães", "Pãos", "Pãoes", "Pãns"],
		[2, 5, "Qual é o contrário de ALEGRE?", "Triste", "Feliz", "Contente", "Animado"],
		[3, 6, "Qual palavra é um sinônimo de BONITO?", "Belo", "Feio", "Grande", "Rápido"],
		[3, 6, "Complete: Ontem eu ___ ao parque.", "fui", "vou", "irei", "ia ir"],
		[4, 7, "Na frase 'O cachorro correu', qual palavra é o verbo?", "correu", "cachorro", "O", "Nenhuma"],
		[4, 8, "Qual está escrita corretamente?", "Exceção", "Excessão", "Esseção", "Ecessão"],
		[5, 8, "Em 'menino esperto', ESPERTO é um...", "Adjetivo", "Verbo", "Substantivo", "Advérbio"],
		[5, 9, "Qual palavra é proparoxítona?", "Lâmpada", "Café", "Mesa", "Cantor"],
		[6, 9, "'Ele correu como um raio' é um exemplo de...", "Comparação", "Rima", "Onomatopeia", "Plural"],
		[7, 9, "Qual é o sujeito de 'Os alunos fizeram a prova'?", "Os alunos", "a prova", "fizeram", "Não há sujeito"],
		[7, 9, "Qual frase usa a crase corretamente?", "Vou à escola.", "Vou à pé.", "Vou à jogar.", "Vou à ele."],
	],
	"Ciências": [
		[1, 3, "Qual destes animais vive na água?", "Peixe", "Cachorro", "Galinha", "Gato"],
		[1, 3, "O que as plantas precisam para crescer?", "Água e luz", "Chocolate", "Areia só", "Escuridão"],
		[2, 4, "Quantas patas tem um inseto?", "6", "8", "4", "10"],
		[2, 5, "Qual órgão bombeia o sangue?", "Coração", "Pulmão", "Estômago", "Cérebro"],
		[3, 5, "A água vira gelo quando...", "Esfria muito", "Esquenta", "Fica no sol", "Mexe"],
		[3, 6, "Qual é o planeta mais perto do Sol?", "Mercúrio", "Terra", "Marte", "Júpiter"],
		[4, 7, "As plantas fazem fotossíntese usando...", "Luz do sol", "Luz da lua", "Barulho", "Vento"],
		[4, 7, "Qual animal é um mamífero?", "Baleia", "Tubarão", "Sapo", "Pinguim"],
		[5, 8, "Em uma cadeia alimentar, a planta é...", "Produtora", "Consumidora", "Decompositora", "Predadora"],
		[5, 8, "Qual gás nós expiramos?", "Gás carbônico", "Oxigênio", "Hélio", "Nitrogênio puro"],
		[6, 9, "A menor unidade dos seres vivos é a...", "Célula", "Folha", "Gota", "Pele"],
		[7, 9, "Onde ocorre a digestão da maior parte dos alimentos?", "Intestino delgado", "Boca", "Pulmão", "Fígado"],
		[7, 9, "Os fungos, como o cogumelo, são...", "Decompositores", "Produtores", "Animais", "Minerais"],
	],
	"Geografia": [
		[1, 3, "Onde o sol nasce?", "Leste", "Oeste", "Norte", "Sul"],
		[2, 4, "O Brasil fica em qual continente?", "América do Sul", "Europa", "Ásia", "África"],
		[3, 5, "Qual é a capital do Brasil?", "Brasília", "Rio de Janeiro", "São Paulo", "Salvador"],
		[3, 6, "Quantas regiões tem o Brasil?", "5", "4", "6", "7"],
		[4, 7, "Qual é o maior oceano do mundo?", "Pacífico", "Atlântico", "Índico", "Ártico"],
		[4, 7, "A capital da Bahia é...", "Salvador", "Recife", "Fortaleza", "Natal"],
		[5, 8, "Qual bioma tem a maior floresta tropical do mundo?", "Amazônia", "Caatinga", "Pampa", "Cerrado"],
		[5, 8, "A Caatinga fica principalmente na região...", "Nordeste", "Sul", "Norte", "Sudeste"],
		[6, 9, "A linha imaginária que divide a Terra em norte e sul é...", "Equador", "Greenwich", "Trópico", "Meridiano"],
		[6, 9, "Qual estado brasileiro é o maior em área?", "Amazonas", "Pará", "Mato Grosso", "Minas Gerais"],
		[7, 9, "Qual rio passa por São Paulo e é famoso pela poluição?", "Tietê", "Amazonas", "São Francisco", "Paraná"],
	],
	"História": [
		[2, 4, "Quem eram os primeiros habitantes do Brasil?", "Os povos indígenas", "Os portugueses", "Os romanos", "Os vikings"],
		[3, 6, "Em que ano os portugueses chegaram ao Brasil?", "1500", "1822", "1889", "1950"],
		[4, 7, "A Independência do Brasil foi em...", "1822", "1500", "1888", "1964"],
		[4, 7, "Quem declarou a Independência do Brasil?", "Dom Pedro I", "Tiradentes", "Cabral", "Getúlio Vargas"],
		[5, 8, "A Lei Áurea, de 1888, acabou com a...", "Escravidão", "Monarquia", "Guerra", "Escola"],
		[5, 8, "Tiradentes participou de qual movimento?", "Inconfidência Mineira", "Farroupilha", "Cabanagem", "Diretas Já"],
		[6, 9, "A República foi proclamada no Brasil em...", "1889", "1822", "1930", "1500"],
		[6, 9, "As pirâmides famosas do Egito eram...", "Túmulos de faraós", "Escolas", "Mercados", "Castelos"],
		[7, 9, "A capital do Brasil passou para Brasília em...", "1960", "1889", "1822", "2000"],
	],
	"Inglês": [
		[1, 4, "Como se diz AZUL em inglês?", "Blue", "Red", "Green", "Yellow"],
		[1, 4, "DOG em português é...", "Cachorro", "Gato", "Pato", "Peixe"],
		[2, 5, "Como se diz 'Bom dia' em inglês?", "Good morning", "Good night", "Goodbye", "Thank you"],
		[2, 5, "Qual é o número FIVE?", "5", "4", "9", "15"],
		[3, 6, "SCHOOL em português é...", "Escola", "Casa", "Rua", "Parque"],
		[4, 7, "Complete: I ___ a student.", "am", "is", "are", "be"],
		[5, 8, "Qual é o passado de GO?", "Went", "Goed", "Gone", "Going"],
		[5, 9, "'She is taller than me' significa...", "Ela é mais alta que eu", "Ela é baixa", "Eu sou mais alto", "Ela é alta como eu"],
		[6, 9, "Complete: They ___ playing soccer now.", "are", "is", "am", "be"],
	],
	"Artes": [
		[1, 3, "Misturando azul e amarelo, temos...", "Verde", "Roxo", "Laranja", "Rosa"],
		[1, 4, "Vermelho + amarelo dá...", "Laranja", "Verde", "Marrom", "Azul"],
		[2, 5, "Quais são as cores primárias?", "Azul, vermelho e amarelo", "Verde, roxo e laranja", "Preto e branco", "Rosa e cinza"],
		[4, 7, "Quem pintou o quadro 'Abaporu'?", "Tarsila do Amaral", "Portinari", "Van Gogh", "Picasso"],
		[5, 8, "O desenho do próprio artista se chama...", "Autorretrato", "Paisagem", "Natureza-morta", "Mosaico"],
		[6, 9, "Escultura é uma arte...", "Tridimensional", "Só no papel", "Só com som", "Digital"],
	],
	"Música": [
		[1, 4, "Qual destes é um instrumento de corda?", "Violão", "Tambor", "Flauta", "Pandeiro"],
		[2, 5, "Quantas são as notas musicais (dó, ré, mi...)?", "7", "5", "10", "12"],
		[3, 6, "O pandeiro é um instrumento de...", "Percussão", "Sopro", "Corda", "Teclas"],
		[5, 8, "O samba é um ritmo de origem...", "Brasileira", "Japonesa", "Russa", "Australiana"],
		[6, 9, "Qual nota vem depois de SOL?", "Lá", "Fá", "Si", "Dó"],
	],
	"Física": [
		[1, 4, "O que faz as coisas caírem no chão?", "Gravidade", "Vento", "Luz", "Música"],
		[3, 6, "Um ímã atrai objetos de...", "Ferro", "Madeira", "Plástico", "Papel"],
		[4, 7, "O que viaja mais rápido?", "A luz", "O som", "Um carro", "Uma bicicleta"],
		[5, 8, "Um carro anda 60 km em 1 hora. Sua velocidade é...", "60 km/h", "30 km/h", "120 km/h", "1 km/h"],
		[5, 8, "Qual destas é uma fonte de energia renovável?", "Solar", "Petróleo", "Carvão", "Gás"],
		[6, 9, "Se você corre 100 m em 20 s, sua velocidade é...", "5 m/s", "20 m/s", "2 m/s", "120 m/s"],
		[7, 9, "A unidade de força no Sistema Internacional é o...", "Newton", "Metro", "Litro", "Grama"],
		[7, 9, "Um objeto parado tende a ficar parado. Isso é a lei da...", "Inércia", "Gravidade", "Energia", "Ação"],
	],
	"Química": [
		[2, 5, "A água pode ser sólida, líquida e...", "Gasosa", "Elástica", "Magnética", "Colorida"],
		[4, 7, "A fórmula da água é...", "H2O", "CO2", "O2", "NaCl"],
		[5, 8, "Água com óleo forma uma mistura...", "Heterogênea", "Homogênea", "Invisível", "Sólida"],
		[5, 8, "O limão é...", "Ácido", "Básico", "Neutro", "Metal"],
		[6, 9, "O símbolo químico do ferro é...", "Fe", "F", "Fr", "Ir"],
		[6, 9, "O sal de cozinha é o...", "Cloreto de sódio", "Gás carbônico", "Oxigênio", "Ferro"],
		[7, 9, "O que é uma reação química?", "Transformação de substâncias", "Mudança de lugar", "Barulho", "Pintar algo"],
		[7, 9, "O símbolo do oxigênio é...", "O", "Ox", "Og", "Oi"],
	],
}

## Pares para "ligar" por matéria.
const MATCH_SETS := {
	"Ciências": [["Abelha", "Colmeia"], ["Pássaro", "Ninho"], ["Coração", "Bombeia sangue"], ["Pulmão", "Respiração"], ["Girino", "Sapo"]],
	"Geografia": [["Bahia", "Salvador"], ["Ceará", "Fortaleza"], ["Paraná", "Curitiba"], ["Amazonas", "Manaus"], ["Pernambuco", "Recife"]],
	"Inglês": [["Cat", "Gato"], ["House", "Casa"], ["Book", "Livro"], ["Water", "Água"], ["Friend", "Amigo"]],
	"Química": [["H2O", "Água"], ["O", "Oxigênio"], ["Fe", "Ferro"], ["Na", "Sódio"], ["CO2", "Gás carbônico"]],
	"História": [["1500", "Chegada dos portugueses"], ["1822", "Independência"], ["1888", "Lei Áurea"], ["1889", "República"]],
	"Artes": [["Azul + amarelo", "Verde"], ["Vermelho + amarelo", "Laranja"], ["Azul + vermelho", "Roxo"], ["Preto + branco", "Cinza"]],
	"Física": [["Ímã", "Atrai ferro"], ["Sol", "Energia solar"], ["Termômetro", "Temperatura"], ["Régua", "Comprimento"]],
	"Música": [["Violão", "Corda"], ["Flauta", "Sopro"], ["Tambor", "Percussão"], ["Piano", "Teclas"]],
	"Português": [["Alegre", "Feliz"], ["Grande", "Enorme"], ["Rápido", "Veloz"], ["Bonito", "Belo"]],
	"Matemática": [["3 x 4", "12"], ["10 + 5", "15"], ["20 - 7", "13"], ["9 x 2", "18"]],
}
const WORDS := [
	"ESCOLA", "RECREIO", "CADERNO", "LÁPIS", "BORRACHA", "MOCHILA", "LANCHE", "AMIGO", "QUADRA",
	"PROFESSORA", "CANTINA", "FIGURINHA", "BOLA", "LOUSA", "LIVRO", "ESTOJO", "RÉGUA", "BIBLIOTECA",
	"FOTOSSÍNTESE", "GEOGRAFIA", "LABORATÓRIO", "INDEPENDÊNCIA", "MICROSCÓPIO", "ASTRONAUTA",
]
const SENTENCES := [
	["O", "sinal", "já", "tocou"], ["Eu", "adoro", "o", "recreio"], ["A", "bola", "é", "redonda"],
	["A", "Terra", "gira", "em", "volta", "do", "Sol"], ["As", "plantas", "precisam", "de", "luz"],
	["O", "Brasil", "fica", "na", "América", "do", "Sul"],
]
const FIND_ITEMS := [
	{"item": "apagador", "name": "o apagador"}, {"item": "livro", "name": "o livro de histórias"},
	{"item": "giz", "name": "a caixa de giz"}, {"item": "caderno", "name": "o caderno de chamada"},
]
const NAMES := ["Bia", "Lucas", "Ana", "Gui", "Júlia", "Pedro"]

var rng := RandomNumberGenerator.new()
## Nível = ano escolar (1–9).
var level := 3


func _init(seed_value := 0, level_value := 3) -> void:
	rng.seed = seed_value if seed_value != 0 else randi()
	level = clampi(level_value, 1, 9)


## Idade real -> ano escolar (6 anos = 1º ano ... 14+ = 9º ano).
static func level_for_age(age: int) -> int:
	return clampi(age - 5, 1, 9)


## Aula com matéria principal e tipos variados (sem repetir tipo seguido).
func make_lesson(count: int, allow_find := true, subject := "") -> Array:
	if subject == "":
		subject = SUBJECTS[rng.randi() % SUBJECTS.size()]
	var plan := ["quiz", "quiz", "match", "order", "quiz"]
	if subject == "Matemática":
		plan = ["math", "math", "match", "order", "problem", "math"]
	elif subject == "Português":
		plan = ["word", "quiz", "order", "match", "word", "quiz"]
	elif subject in ["Física", "Química"]:
		plan = ["quiz", "quiz", "match", "problem", "quiz"]
	if allow_find:
		plan.append("find")
	plan.shuffle()
	var out := []
	var prompts := {}
	var last := ""
	var i := 0
	while out.size() < count and i < 120:
		var t: String = plan[i % plan.size()]
		i += 1
		if t == last or (t == "find" and out.any(func(x): return x.type == "find")):
			continue
		var task := make(t, subject)
		var key := str(task.get("prompt", "")) + str(task.get("left", ""))
		# evita pergunta repetida na mesma aula (se ainda houver opções)
		if prompts.has(key) and i < 90:
			continue
		prompts[key] = true
		out.append(task)
		last = t
	return out


func make(type: String, subject := "") -> Dictionary:
	match type:
		"math": return _math()
		"word": return _word()
		"quiz": return _quiz(subject)
		"order": return _order(subject)
		"match": return _match(subject)
		"find": return _find()
		"problem": return _problem()
	return _math()


func _shuffle_options(correct: String, wrong: Array) -> Dictionary:
	var opts := [correct]
	for w in wrong:
		if not str(w) in opts and opts.size() < 4:
			opts.append(str(w))
	var guard := 0
	while opts.size() < 4 and guard < 50:
		guard += 1
		var extra := str(rng.randi_range(0, 30))
		if not extra in opts:
			opts.append(extra)
	opts.shuffle()
	return {"options": opts, "answer": opts.find(correct)}


func _math() -> Dictionary:
	var lv := level
	var a: int
	var b: int
	var res: int
	var prompt := ""
	var explain := ""
	var kind := rng.randi() % 4
	var who: String = NAMES[rng.randi() % NAMES.size()]
	if lv <= 2:
		a = rng.randi_range(1, 9 + lv * 3)
		b = rng.randi_range(1, 9)
		if kind % 2 == 0:
			res = a + b
			prompt = "%s tem %d figurinhas e ganhou %d. Quantas tem agora?" % [who, a, b] if kind == 0 else "Quanto é %d + %d?" % [a, b]
			explain = "Ganhar é somar: %d + %d = %d. Dica: comece do %d e conte mais %d nos dedos." % [a, b, res, a, b]
		else:
			a += b
			res = a - b
			prompt = "Havia %d bolinhas de gude. %s perdeu %d. Quantas sobraram?" % [a, who, b] if kind == 1 else "Quanto é %d - %d?" % [a, b]
			explain = "Perder é tirar: %d - %d = %d. Dica: conte para trás %d vezes a partir do %d." % [a, b, res, b, a]
	elif lv <= 4:
		if kind == 0:
			a = rng.randi_range(12, 60)
			b = rng.randi_range(5, 39)
			res = a + b
			prompt = "Quanto é %d + %d?" % [a, b]
			explain = "Some as dezenas e depois as unidades: %d + %d = %d." % [a, b, res]
		elif kind == 1:
			a = rng.randi_range(2, 6)
			b = rng.randi_range(2, 9)
			res = a * b
			prompt = "%s comprou %d coxinhas a R$ %d cada. Quanto gastou?" % [who, a, b]
			explain = "São %d vezes R$ %d: %d × %d = %d reais." % [a, b, a, b, res]
		elif kind == 2:
			a = rng.randi_range(2, 9)
			b = rng.randi_range(2, 9)
			res = a * b
			prompt = "Quanto é %d × %d?" % [a, b]
			explain = "%d × %d é somar o %d, %d vezes. Resultado: %d." % [a, b, b, a, res]
		else:
			res = rng.randi_range(3, 15)
			a = res * 2
			prompt = "Qual é a metade de %d?" % a
			explain = "Metade é dividir por 2: %d ÷ 2 = %d (porque %d + %d = %d)." % [a, res, res, res, a]
	elif lv <= 6:
		if kind == 0:
			b = rng.randi_range(2, 9)
			res = rng.randi_range(2, 12)
			a = b * res
			prompt = "%d alunos em %d times iguais. Quantos em cada time?" % [a, b]
			explain = "Dividir em times iguais: %d ÷ %d = %d, porque %d × %d = %d." % [a, b, res, b, res, a]
		elif kind == 1:
			a = rng.randi_range(11, 25)
			b = rng.randi_range(3, 9)
			res = a * b
			prompt = "Quanto é %d × %d?" % [a, b]
			explain = "Separe: %d × %d = %d e %d × %d = %d. Some: %d." % [(a / 10) * 10, b, (a / 10) * 10 * b, a % 10, b, (a % 10) * b, res]
		elif kind == 2:
			a = rng.randi_range(2, 10) * 10
			res = a / 10 * 3
			prompt = "Quanto é 30%% de %d?" % a
			explain = "10%% de %d é %d (divida por 10). 30%% é 3 vezes isso: %d." % [a, a / 10, res]
		else:
			a = rng.randi_range(3, 9)
			res = a * a
			prompt = "Quanto é %d ao quadrado (%d²)?" % [a, a]
			explain = "Ao quadrado é o número vezes ele mesmo: %d × %d = %d." % [a, a, res]
	else:
		if kind == 0:
			res = rng.randi_range(2, 15)
			b = rng.randi_range(2, 20)
			prompt = "Se x + %d = %d, quanto vale x?" % [b, res + b]
			explain = "Passe o %d para o outro lado subtraindo: x = %d - %d = %d." % [b, res + b, b, res]
		elif kind == 1:
			res = rng.randi_range(2, 9)
			b = rng.randi_range(2, 6)
			prompt = "Se %dx = %d, quanto vale x?" % [b, b * res]
			explain = "%dx quer dizer %d vezes x. Divida: x = %d ÷ %d = %d." % [b, b, b * res, b, res]
		elif kind == 2:
			a = rng.randi_range(-9, -1)
			b = rng.randi_range(2, 12)
			res = a + b
			prompt = "Quanto é (%d) + %d?" % [a, b]
			explain = "Na reta numérica, saia do %d e ande %d casas para a direita: chega em %d." % [a, b, res]
		else:
			a = rng.randi_range(2, 12)
			b = rng.randi_range(2, 5)
			res = a * a - b
			prompt = "Quanto é %d² - %d?" % [a, b]
			explain = "Primeiro a potência: %d² = %d. Depois tire %d: %d." % [a, a * a, b, res]
	var wrong := [str(res + 1), str(res - 1), str(res + rng.randi_range(2, 6)), str(res - rng.randi_range(2, 5)), str(res * 2)]
	var t := _shuffle_options(str(res), wrong)
	t.merge({"type": "math", "subject": "Matemática", "prompt": prompt, "explain": explain})
	return t


## Problema mais longo, em duas etapas (desafio da aula).
func _problem() -> Dictionary:
	var who: String = NAMES[rng.randi() % NAMES.size()]
	var prompt := ""
	var explain := ""
	var res := 0
	var kind := rng.randi() % 3
	if level <= 3:
		var a := rng.randi_range(5, 15)
		var b := rng.randi_range(2, 9)
		var c := rng.randi_range(1, mini(a + b - 1, 8))
		res = a + b - c
		prompt = "%s tinha %d figurinhas. Ganhou %d do primo e depois deu %d para a Bia.\nCom quantas ficou?" % [who, a, b, c]
		explain = "Etapa 1: %d + %d = %d. Etapa 2: %d - %d = %d." % [a, b, a + b, a + b, c, res]
	elif level <= 6 or kind == 0:
		var n := rng.randi_range(3, 6)
		var price := rng.randi_range(3, 8)
		var paid := (n * price / 10 + 1) * 10
		res = paid - n * price
		prompt = "%s comprou %d pastéis de R$ %d na cantina e pagou com R$ %d.\nQuanto recebeu de troco?" % [who, n, price, paid]
		explain = "Etapa 1: %d × %d = %d reais gastos. Etapa 2: %d - %d = %d de troco." % [n, price, n * price, paid, n * price, res]
	elif kind == 1:
		var v := rng.randi_range(3, 8)
		var tm := rng.randi_range(4, 12)
		var extra := rng.randi_range(5, 30)
		res = v * tm + extra
		prompt = "Uma bicicleta anda %d metros por segundo durante %d segundos e depois mais %d metros.\nQuantos metros andou ao todo?" % [v, tm, extra]
		explain = "Etapa 1: distância = velocidade × tempo = %d × %d = %d m. Etapa 2: %d + %d = %d m." % [v, tm, v * tm, v * tm, extra, res]
	else:
		var total := rng.randi_range(4, 9) * 6
		res = total / 3 - total / 6
		prompt = "A turma tem %d alunos. 1/3 joga futebol e 1/6 joga queimada.\nQuantos alunos a mais jogam futebol?" % total
		explain = "1/3 de %d = %d. 1/6 de %d = %d. Diferença: %d - %d = %d." % [total, total / 3, total, total / 6, total / 3, total / 6, res]
	var wrong := [str(res + 1), str(res - 1), str(res + rng.randi_range(2, 6)), str(res + 10), str(maxi(res - rng.randi_range(2, 5), 0))]
	var t := _shuffle_options(str(res), wrong)
	t.merge({"type": "math", "subject": "Matemática", "prompt": prompt, "explain": explain, "long": true})
	return t


func _word() -> Dictionary:
	var pool := WORDS.filter(func(w): return (w.length() <= 7) == (level <= 3) or level > 5)
	var w: String = pool[rng.randi() % pool.size()]
	var idx := rng.randi_range(1, w.length() - 2)
	var letter := w[idx]
	var masked := w.substr(0, idx) + "_" + w.substr(idx + 1)
	var letters := "ABCDEFGILMNOPRSTUVÇ"
	var wrong := []
	while wrong.size() < 3:
		var l := letters[rng.randi() % letters.length()]
		if l != letter and not l in wrong:
			wrong.append(l)
	var t := _shuffle_options(letter, wrong)
	t.merge({"type": "word", "subject": "Português", "prompt": "Complete a palavra:\n%s" % masked, "word": w, "explain": "A palavra completa é %s (a letra que faltava era %s)." % [w, letter]})
	return t


func _bank_for(subject: String) -> Array:
	var list: Array = (BANK.get(subject, []) as Array) + (QuestionBank.EXTRA.get(subject, []) as Array)
	var fit := list.filter(func(q): return level >= int(q[0]) and level <= int(q[1]))
	if fit.is_empty():
		# sem pergunta da faixa: usa a mais próxima
		fit = list.duplicate()
		fit.sort_custom(func(x, y): return absi(int(x[0]) - level) < absi(int(y[0]) - level))
		fit = fit.slice(0, 3)
	return fit


func _quiz(subject: String) -> Dictionary:
	if subject == "" or subject == "Matemática" or not BANK.has(subject):
		subject = BANK.keys()[rng.randi() % BANK.size()]
	var fit := _bank_for(subject)
	var q: Array = _pick_fresh(fit)
	var wrong: Array = q.slice(4, 7)
	var t := _shuffle_options(q[3], wrong)
	var explain: String = str(q[7]) if q.size() > 7 else Explanations.for_quiz(q[2], q[3])
	t.merge({"type": "quiz", "subject": subject, "prompt": q[2], "explain": explain})
	return t


## Memória das perguntas já feitas (as últimas 120): escolhe uma que não
## apareceu há pouco; se todas apareceram, a mais antiga.
static func _recent() -> Array:
	var sec: Dictionary = SaveManager.section("learning")
	if not sec.has("recent_q"):
		sec["recent_q"] = []
	return sec["recent_q"]


func _pick_fresh(fit: Array) -> Array:
	var recent := _recent()
	var fresh := fit.filter(func(q): return not (str(q[2]) in recent))
	var q: Array
	if not fresh.is_empty():
		q = fresh[rng.randi() % fresh.size()]
	else:
		var best := 1 << 30
		q = fit[0]
		for c in fit:
			var i := recent.find(str(c[2]))
			if i < best:
				best = i
				q = c
	recent.erase(str(q[2]))
	recent.append(str(q[2]))
	while recent.size() > 120:
		recent.pop_front()
	return q


func _order(subject: String) -> Dictionary:
	if subject == "Matemática" or rng.randf() < 0.4:
		var nums := []
		var top := 20 + level * 15
		while nums.size() < 4:
			var n := rng.randi_range(-10 if level >= 7 else 1, top)
			if not n in nums:
				nums.append(n)
		var items := nums.map(func(x): return str(x))
		items.shuffle()
		var sorted_nums := nums.duplicate()
		sorted_nums.sort()
		var order := sorted_nums.map(func(x): return items.find(str(x)))
		return {"type": "order", "subject": "Matemática", "prompt": "Toque nos números do MENOR para o MAIOR", "items": items, "answer_order": order,
			"explain": "Do menor para o maior: %s.%s" % [", ".join(sorted_nums.map(func(x): return str(x))), " Lembre: números negativos são menores que zero!" if sorted_nums[0] < 0 else ""]}
	var pool := SENTENCES.filter(func(s): return (s.size() <= 4) == (level <= 3) or level > 3)
	var sentence: Array = pool[rng.randi() % pool.size()]
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
	return {"type": "order", "subject": "Português", "prompt": "Toque nas palavras para formar a frase", "items": items2, "answer_order": order2,
		"explain": "A frase certa é: \"%s.\" Dica: a frase começa com a palavra de letra maiúscula." % " ".join(sentence)}


func _match(subject: String) -> Dictionary:
	if not MATCH_SETS.has(subject):
		subject = MATCH_SETS.keys()[rng.randi() % MATCH_SETS.size()]
	var pairs: Array = MATCH_SETS[subject].duplicate()
	pairs.shuffle()
	pairs = pairs.slice(0, 3 if level <= 4 else 4)
	var left := pairs.map(func(p): return p[0])
	var right := pairs.map(func(p): return p[1])
	right.shuffle()
	var mapping := {}
	for i in pairs.size():
		mapping[i] = right.find(pairs[i][1])
	return {"type": "match", "subject": subject, "prompt": "Ligue os pares (%s)" % subject, "left": left, "right": right, "pairs": mapping}


func _find() -> Dictionary:
	var f: Dictionary = FIND_ITEMS[rng.randi() % FIND_ITEMS.size()]
	return {"type": "find", "subject": "Ajude a professora", "prompt": "Você pode me trazer %s?\nEstá em algum lugar da sala." % f.name, "item": f.item, "item_name": f.name}


static func check_choice(task: Dictionary, chosen: int) -> bool:
	return chosen == int(task.answer)


static func check_order(task: Dictionary, sequence: Array) -> bool:
	if sequence.size() != task.answer_order.size():
		return false
	for i in sequence.size():
		if task.items[sequence[i]] != task.items[task.answer_order[i]]:
			return false
	return true


static func check_match(task: Dictionary, left_i: int, right_i: int) -> bool:
	return int(task.pairs.get(left_i, -1)) == right_i
