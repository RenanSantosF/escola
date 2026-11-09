class_name NPCRoster
extends RefCounted
## Elenco fixo da escola: alunos com personalidade, adultos e falas.

## Personalidades: futebol, competitivo, engracado, timido, colecionador,
## comilao, estudioso, agitado, comum
const STUDENTS := [
	{"id": "lucas", "name": "Lucas", "personality": "futebol", "seed": 101,
		"look": {"hair_style": "curto", "shirt_trim": "2f6fd0", "cap": true, "cap_color": "e04a3a"}},
	{"id": "bia", "name": "Bia", "personality": "competitivo", "seed": 202,
		"look": {"hair_style": "rabo", "hair_color": "1d1612", "backpack_color": "8e5bd1"}},
	{"id": "pedro", "name": "Pedro", "personality": "engracado", "seed": 303,
		"look": {"hair_style": "espetado", "hair_color": "d9b25f", "glasses": false}},
	{"id": "ana", "name": "Ana", "personality": "timido", "seed": 404,
		"look": {"hair_style": "longo", "hair_color": "6b3e1f", "glasses": true}},
	{"id": "julia", "name": "Júlia", "personality": "colecionador", "seed": 505,
		"look": {"hair_style": "cacheado", "hair_color": "1d1612", "backpack_color": "ff7eb6"}},
	{"id": "gui", "name": "Gui", "personality": "comilao", "seed": 606,
		"look": {"hair_style": "raspado", "build": 1.18}},
	{"id": "rafa", "name": "Rafa", "personality": "agitado", "seed": 707,
		"look": {"hair_style": "black_power", "hair_color": "1d1612"}},
	{"id": "mari", "name": "Mari", "personality": "estudioso", "seed": 808,
		"look": {"hair_style": "franja", "hair_color": "a32e1d", "glasses": true}},
]

const GENERIC_NAMES := ["Davi", "Sofia", "Miguel", "Alice", "Arthur", "Helena", "Heitor", "Laura", "Theo", "Valentina",
	"Gabriel", "Manuela", "Bernardo", "Isabela", "Enzo", "Lívia", "Samuel", "Clara", "Matheus", "Cecília",
	"Joaquim", "Eloá", "Caio", "Lara", "Benício", "Yasmin", "Nicolas", "Beatriz", "Murilo", "Giovanna",
	"Vitor", "Lorena", "Daniel", "Mariana", "Felipe", "Luana", "Kauã", "Maitê", "Breno", "Ester"]
const GENERIC_PERSONALITIES := ["comum", "comum", "comum", "futebol", "engracado", "timido", "colecionador", "comilao", "agitado", "estudioso"]

const ADULTS := {
	"teacher": {"id": "prof_marcia", "name": "Professora Márcia", "role": "teacher", "seed": 900,
		"look": {"hair_style": "longo", "hair_color": "3b2417", "shirt_color": "c0392b", "shirt_trim": "a93226",
			"shirt_logo": false, "long_pants": true, "pants_color": "2c3e50", "backpack": false, "glasses": true,
			"height_scale": 1.2, "build": 1.05}},
	"director": {"id": "diretor", "name": "Diretor Valdir", "role": "director", "seed": 901,
		"look": {"hair_style": "raspado", "hair_color": "5d5d5d", "shirt_color": "ecf0f1", "shirt_trim": "34495e",
			"shirt_logo": false, "long_pants": true, "pants_color": "34495e", "backpack": false, "glasses": true,
			"height_scale": 1.24, "build": 1.15, "shoe_color": "1f1f1f"}},
	"inspector": {"id": "inspetora", "name": "Dona Cida", "role": "inspector", "seed": 902,
		"look": {"hair_style": "cacheado", "hair_color": "8a8a8a", "shirt_color": "27ae60", "shirt_trim": "1e8449",
			"shirt_logo": false, "long_pants": true, "pants_color": "1c2833", "backpack": false,
			"height_scale": 1.17, "build": 1.12}},
	"cook": {"id": "cantineira", "name": "Tia Rosa", "role": "cook", "seed": 903,
		"look": {"hair_style": "rabo", "hair_color": "1d1612", "shirt_color": "f4f4f0", "shirt_trim": "e74c3c",
			"shirt_logo": false, "long_pants": true, "pants_color": "e8e8e8", "backpack": false, "cap": true,
			"cap_color": "e74c3c", "height_scale": 1.18, "build": 1.1}},
}

## Falas curtas (balões) por personalidade e momento.
const AMBIENT := {
	"futebol": ["Bora jogar bola!", "Passa, passa!", "Golaço!", "Hoje eu jogo no gol!", "Quem tem bola?"],
	"competitivo": ["Aposto que corro mais rápido!", "Ganhei de novo!", "Quero revanche!", "Eu fui o primeiro!"],
	"engracado": ["Hahaha!", "Sabe aquela da galinha?", "Olha a careta!", "Pegadinha!", "Kkkkkk"],
	"timido": ["...oi.", "Hum...", "Gosto de ler aqui.", "Tá bom..."],
	"colecionador": ["Troca figurinha?", "Me falta só uma!", "Essa é rara!", "Tenho repetida!"],
	"comilao": ["Que fome!", "Hoje tem coxinha?", "Tô na fila!", "Esse lanche tá bom demais!"],
	"agitado": ["Pega-pega!", "Tá com você!", "Corre!", "Ninguém me pega!"],
	"estudioso": ["Já fiz a tarefa.", "Amanhã tem prova!", "Li um livro legal.", "Você entendeu a lição?"],
	"comum": ["Oi!", "E aí?", "Que calor!", "Já tocou o sinal?", "Bora lá!", "Que legal!"],
	"teacher": ["Silêncio, turma!", "Muito bem!", "Prestem atenção!"],
	"director": ["Sem correria no corredor!", "Bom dia, alunos.", "Tudo em ordem por aqui?"],
	"inspector": ["Devagar, crianças!", "Cuidado aí!", "Joga o lixo no lixo!"],
	"cook": ["Saindo pastel quentinho!", "Quem é o próximo?", "Olha a coxinha!"],
}

## Conversas ao interagir (tocar em "Conversar").
const TALK := {
	"futebol": [["Ei! No recreio vai ter futebol na quadra.", "Chega lá que eu te passo a bola!"],
		["Meu sonho é jogar na seleção.", "Treino todo recreio!"]],
	"competitivo": [["Tirei dez em todas as tarefas ontem.", "Duvido você me alcançar!"],
		["Aposto uma corrida até a quadra!", "...Mas não agora, tô ocupada."]],
	"engracado": [["Por que o livro de matemática ficou triste?", "Porque tinha muitos problemas! Hahaha!"],
		["Já viu o diretor tropeçar no corredor?", "Eu não vi... mas imaginei!"]],
	"timido": [["Ah... oi.", "Você... quer sentar aqui comigo um pouco?"], ["Eu gosto da biblioteca.", "Lá é calminho."]],
	"colecionador": [["Tô completando o álbum!", "Se achar figurinha, me avisa!"], ["Essa aqui é brilhante, olha!", "Não troco por nada!"]],
	"comilao": [["A Tia Rosa faz a melhor coxinha do mundo.", "Sério, experimenta!"], ["Já tá chegando a hora do lanche?", "Minha barriga tá roncando..."]],
	"agitado": [["Pega-pega no pátio!", "Quem perder é o pegador!"], ["Eu consigo subir no trepa-trepa de olho fechado!", "...Quase."]],
	"estudioso": [["Hoje a professora vai passar contas.", "É só prestar atenção que é fácil."], ["Sabia que a biblioteca tem um globo?", "Adoro geografia."]],
	"comum": [["Oi! Tudo bem?", "Bora pro recreio daqui a pouco!"], ["Você é novo aqui?", "Seja bem-vindo!"], ["Que calor hoje, né?", "Bom dia pra tomar água no bebedouro."]],
	"teacher": [["Bom dia! Hoje vamos fazer umas atividades rapidinhas.", "Quem terminar bem, aproveita o recreio!"]],
	"director": [["Bom dia, mocinho.", "Lembre-se: nada de correria no corredor, combinado?"]],
	"inspector": [["Comportado hoje, hein?", "Qualquer coisa, é só me chamar."]],
	"cook": [["Oi, querido! Hoje tem pão de queijo quentinho.", "Volta no recreio!"]],
}


static func appearance_for(entry: Dictionary) -> CharacterAppearance:
	var a := CharacterAppearance.random(int(entry.get("seed", 1)), entry.get("role", "student") == "student")
	var look: Dictionary = entry.get("look", {})
	var d := a.to_dict()
	for k in look.keys():
		d[k] = look[k]
	var res := CharacterAppearance.from_dict(d)
	# adultos podem ser mais altos que alunos
	if look.has("height_scale"):
		res.height_scale = float(look.height_scale)
	return res


static func generic_student(index: int) -> Dictionary:
	return {
		"id": "aluno_%d" % index,
		"name": GENERIC_NAMES[index % GENERIC_NAMES.size()],
		"personality": GENERIC_PERSONALITIES[(index * 7 + 3) % GENERIC_PERSONALITIES.size()],
		"seed": 1000 + index * 37,
		"role": "student",
	}


static func ambient_line(personality: String) -> String:
	var lines: Array = AMBIENT.get(personality, AMBIENT.comum)
	return lines.pick_random()


static func talk_lines(personality: String) -> Array:
	var sets: Array = TALK.get(personality, TALK.comum)
	return sets.pick_random()
