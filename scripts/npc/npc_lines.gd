class_name NPCLines
## Falas dos alunos e adultos. Sorteio por "saco embaralhado": nenhuma
## frase repete até todas da lista terem saído (evita ouvir a mesma
## coisa toda hora). Mistura falas da personalidade, do momento do dia e
## curiosidades.

const AMBIENT := {
	"futebol": ["Bora jogar bola na quadra!", "Passa, passa, tô livre!", "Que golaço foi aquele ontem!", "Hoje eu quero jogar no gol.",
		"Quem trouxe bola hoje?", "Vamos tirar time no par ou ímpar?", "Chuta com o lado do pé que vai mais certo!", "Eu treinei embaixadinha a semana toda!",
		"Fiz 23 embaixadinhas ontem, recorde!", "No intervalo o time azul vai ganhar!", "Ô juiz, foi falta!", "Quem perder sai, quem ganhar fica!"],
	"competitivo": ["Aposto que chego primeiro na quadra!", "Ganhei de novo, hehe!", "Quero revanche na corrida!", "Eu fui o primeiro da fila!",
		"Tirei a maior nota da turma!", "Duvido você acertar a lixeira de longe!", "Quem fizer mais pontos na amarelinha ganha!", "Treino todo dia pra ser o mais rápido."],
	"engracado": ["Hahaha, olha a careta que eu sei fazer!", "Sabe por que a vaca foi pro espaço? Pra ver a Via Láctea!", "Pegadinha do malandro!",
		"Kkkkk, eu escorreguei no pátio!", "O que o pato falou pra pata? Vem quá!", "Qual é o doce preferido do átomo? Pé-de-moléculas!",
		"Por que a plantinha não foi atendida no hospital? Porque só tinha médico de plantão!", "Ri tanto que doeu a barriga!", "Imita uma galinha comigo? Có có có!"],
	"timido": ["...oi.", "Hum... tá bom.", "Gosto de ler aqui no cantinho.", "Você quer brincar? ...Se quiser.", "Eu desenho dragões no caderno.",
		"A biblioteca é o meu lugar preferido.", "Fiz um amigo novo ontem.", "Eu tô aprendendo a tocar violão."],
	"colecionador": ["Troca figurinha comigo?", "Só me falta uma pra completar a página!", "Essa aqui é rara, brilha no sol!", "Tenho um monte de repetida!",
		"Já tenho 112 figurinhas!", "Bolinha de gude olho-de-gato vale por três!", "Alguém tem a figurinha do mascote?", "Guardo tudo numa caixinha organizada."],
	"comilao": ["Que fome, minha barriga tá roncando!", "Hoje tem coxinha na cantina?", "Tô guardando lugar na fila!", "Esse pão de queijo tá demais!",
		"A Tia Rosa faz o melhor bolo do mundo!", "Fruta também é gostoso, sabia?", "Trouxe uva na lancheira!", "Bebeu água hoje? Tem que beber!"],
	"agitado": ["Pega-pega no pátio, quem topa?", "Tá com você!", "Corre que ele tá vindo!", "Ninguém me pega, ninguém!", "Bora pular corda?",
		"Eu subo no trepa-trepa rapidinho!", "Esconde-esconde depois da aula!", "Vamos apostar corrida até a árvore?"],
	"estudioso": ["Já terminei a tarefa de casa.", "Amanhã tem prova de ciências!", "Li um livro sobre dinossauros, muito legal.", "Você entendeu a lição de frações?",
		"Quero ser cientista quando crescer.", "Sabia que o Sol é uma estrela?", "Fiz um experimento com vinagre e bicarbonato!", "Vou na biblioteca pegar outro livro."],
	"comum": ["Oi, tudo bem?", "E aí, beleza?", "Que calor hoje!", "Já tocou o sinal?", "Bora lá!", "Que legal!", "Hoje o dia tá lindo!",
		"Vamos sentar no banco da sombra?", "Meu irmão estuda aqui também.", "Gostei do seu tênis!", "Você vai na festa junina?", "Adoro o recreio!"],
	"teacher": ["Silêncio, turma, vamos começar!", "Muito bem, continuem assim!", "Prestem atenção no quadro.", "Quem terminar pode me mostrar.",
		"Errar faz parte de aprender!", "Levanta a mão quem quiser responder."],
	"director": ["Sem correria perto da escada!", "Bom dia, alunos.", "Tudo em ordem por aqui?", "Cuidem da nossa escola!", "Quero ver todo mundo na aula no horário."],
	"inspector": ["Devagar, crianças!", "Cuidado aí!", "Lixo é no lixo, viu?", "Não pode subir no muro!", "Quem deixou essa mochila aqui?"],
	"cook": ["Saindo pastel quentinho!", "Quem é o próximo da fila?", "Olha a coxinha!", "Hoje tem suco de laranja natural!", "Lavou as mãos antes de comer?"],
	"gardener": ["As mudinhas estão crescendo!", "Não pisa no canteiro, tá?", "Água de manhã é melhor pras plantas.", "Olha essa joaninha!"],
	"librarian": ["Shhh... biblioteca é lugar de silêncio.", "Chegaram livros novos!", "Ler é viajar sem sair do lugar."],
}

## Falas extras conforme o momento do dia (todos os alunos).
const PHASE := {
	"arrival": ["Bom dia! Dormiu bem?", "Ainda tô com sono...", "Fez a tarefa de casa?", "Hoje tem educação física?", "Corre que o sinal vai tocar!"],
	"recess": ["Finalmente o recreio!", "Bora brincar!", "Vamos na cantina?", "Quem vai pular corda?", "Que recreio bom!", "Bora fazer uma missão?"],
	"return": ["Ah, já acabou o recreio?", "Passou rápido demais!", "Bora pra sala.", "Tô suado de tanto correr!"],
	"class": ["Psiu, a professora tá olhando!", "Me empresta a borracha?", "Qual a resposta da 3?", "Tô quase terminando."],
	"day_end": ["Até amanhã!", "Tchau, bom descanso!", "Amanhã tem mais!", "Minha mãe chegou!"],
}

## Curiosidades que os alunos contam (mistura nas conversas).
const FACTS := [
	"Sabia que o polvo tem três corações?", "Sabia que a Lua não tem luz própria? Ela reflete a luz do Sol.",
	"Sabia que as abelhas se comunicam dançando?", "Sabia que o coração bate umas cem mil vezes por dia?",
	"Sabia que a Amazônia produz chuva para o Brasil inteiro?", "Sabia que o beija-flor bate as asas mais de 50 vezes por segundo?",
	"Sabia que a girafa dorme só umas duas horas por dia?", "Sabia que a água cobre quase três quartos da Terra?",
	"Sabia que o som não se espalha no espaço?", "Sabia que o tubarão existe desde antes dos dinossauros?",
	"Sabia que a gente tem 206 ossos quando é adulto?", "Sabia que a formiga aguenta muitas vezes o próprio peso?",
	"Sabia que o arco-íris tem sete cores?", "Sabia que a capivara é o maior roedor do mundo e vive no Brasil?",
	"Sabia que os dinossauros tinham penas? Pelo menos alguns!", "Sabia que plantar uma árvore ajuda a refrescar a rua?",
	"Sabia que o Brasil tem mais de 200 milhões de pessoas?", "Sabia que o vulcão do laboratório é feito com bicarbonato e vinagre?",
	"Sabia que a luz do Sol leva uns 8 minutos pra chegar aqui?", "Sabia que o pinguim é uma ave que não voa, mas nada super bem?",
]

## Conversas completas ao tocar em "Conversar" (2 a 4 falas).
const TALK := {
	"futebol": [["Ei! No recreio vai ter futebol na quadra.", "Chega lá que eu te passo a bola!", "Mas tem que voltar pra defender, hein!"],
		["Meu sonho é jogar na seleção.", "Treino todo recreio e todo fim de semana.", "Você torce pra qual time?"],
		["Sabia que dá pra fazer gol de bicicleta?", "Eu tentei uma vez e caí sentado. Hahaha!"],
		["O segredo do pênalti é olhar pra um lado e chutar no outro.", "Mas não conta pra ninguém!"]],
	"competitivo": [["Tirei dez em todas as tarefas ontem.", "Duvido você me alcançar!", "...Tá bom, se você estudar, talvez."],
		["Aposto uma corrida até a quadra!", "...Mas não agora, tô ocupada.", "Depois do lanche, combinado?"],
		["Meu recorde na pontaria é 8 acertos.", "Se você bater, eu te dou uma figurinha!"]],
	"engracado": [["Por que o livro de matemática ficou triste?", "Porque tinha muitos problemas!", "Hahaha, essa é clássica!"],
		["Já viu o diretor tropeçar no corredor?", "Eu não vi... mas imaginei!"],
		["O que o zero disse pro oito?", "Que cinto bonito!", "Kkkkk, entendeu? O oito parece um zero de cinto!"],
		["Qual é o animal mais antigo do mundo?", "A zebra, porque ela ainda é em preto e branco!"]],
	"timido": [["Ah... oi.", "Você... quer sentar aqui comigo um pouco?"], ["Eu gosto da biblioteca.", "Lá é calminho e tem livro de dragão."],
		["Obrigado por falar comigo.", "Às vezes eu fico com vergonha de chamar alguém pra brincar."],
		["Eu desenhei você no meu caderno!", "...Ficou meio torto, mas foi de coração."]],
	"colecionador": [["Tô completando o álbum!", "Se achar figurinha, me avisa!", "Se tiver repetida, a gente troca."],
		["Essa aqui é brilhante, olha!", "Não troco por nada!", "...Bom, talvez por duas raras."],
		["Sabia que no cantinho da gude tem bolinha de todo tipo?", "A olho-de-gato é a mais bonita!"]],
	"comilao": [["A Tia Rosa faz a melhor coxinha do mundo.", "Sério, experimenta!", "Mas lava a mão antes, hein!"],
		["Já tá chegando a hora do lanche?", "Minha barriga tá roncando..."],
		["Sabia que na horta da escola tem alface e tomate?", "O Seu Zé deixa a gente ajudar a plantar!"]],
	"agitado": [["Pega-pega no pátio!", "Quem perder é o pegador!", "Valendo... JÁ!"],
		["Eu consigo subir no trepa-trepa de olho fechado!", "...Quase."],
		["Já pulou corda com duas cordas ao mesmo tempo?", "É o desafio máximo!"]],
	"estudioso": [["Hoje a professora vai passar contas.", "É só prestar atenção que é fácil.", "Se travar, desenha a conta com bolinhas!"],
		["Sabia que a biblioteca tem um globo?", "Adoro geografia.", "Já achei o Brasil em três segundos!"],
		["No laboratório tem um microscópio!", "Dá pra ver uma gota d'água cheia de coisinhas."],
		["Quando erro uma pergunta, leio a explicação.", "Aí na próxima eu acerto!"]],
	"comum": [["Oi! Tudo bem?", "Bora pro recreio daqui a pouco!"], ["Você é novo aqui?", "Seja bem-vindo! Aqui todo mundo é legal."],
		["Que calor hoje, né?", "Bom dia pra tomar água no bebedouro."],
		["Já conhece o Bloco C?", "Tem escada e um mirante lá em cima!", "Dá pra ver a escola inteira!"],
		["Já jogou uma moeda na fonte da entrada?", "Dizem que dá sorte!"],
		["O Seu Zé sempre tem uma missão na horta.", "Vai lá falar com ele!"]],
	"teacher": [["Bom dia! Hoje vamos fazer umas atividades rapidinhas.", "Quem terminar bem, aproveita o recreio!"],
		["Se errar, tudo bem!", "Leia a explicação com calma que você aprende."]],
	"director": [["Bom dia, mocinho.", "Lembre-se: nada de correria perto da escada, combinado?"],
		["Nossa escola ficou mais bonita com as árvores que vocês plantaram.", "Continuem cuidando dela!"]],
	"inspector": [["Comportado hoje, hein?", "Qualquer coisa, é só me chamar."], ["Viu alguém jogando lixo no chão?", "Ajuda a gente a manter tudo limpinho!"]],
	"cook": [["Oi, querido! Hoje tem pão de queijo quentinho.", "Volta no recreio!"], ["Sabia que a alface da salada veio da horta de vocês?", "Que orgulho!"]],
}

static var _bags := {}


## Tira um item do saco embaralhado `key` (repõe quando esvazia).
static func draw(key: String, source: Array) -> Variant:
	if source.is_empty():
		return null
	var bag: Array = _bags.get(key, [])
	if bag.is_empty():
		bag = source.duplicate()
		bag.shuffle()
	var v: Variant = bag.pop_back()
	_bags[key] = bag
	return v


static func ambient(personality: String, phase := "") -> String:
	var own: Array = AMBIENT.get(personality, AMBIENT.comum)
	# 30%: fala do momento do dia; 10%: curiosidade
	var r := randf()
	if phase != "" and PHASE.has(phase) and r < 0.3:
		return str(draw("phase_" + phase, PHASE[phase]))
	if r < 0.4 and personality in ["estudioso", "comum", "timido", "colecionador"]:
		return str(draw("facts", FACTS))
	return str(draw("amb_" + personality, own))


static func talk(personality: String) -> Array:
	var sets: Array = TALK.get(personality, TALK.comum)
	var lines: Array = (draw("talk_" + personality, sets) as Array).duplicate()
	if randf() < 0.35 and personality not in ["teacher", "director", "inspector", "cook"]:
		lines.append(str(draw("facts", FACTS)))
	return lines
