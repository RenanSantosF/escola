class_name CinemaScreen
extends Node3D
## Sessão de cinema (Sala de Vídeo e Auditório): a tela passa um "filme" de
## curiosidades em cenas, uma a cada poucos segundos, enquanto alguém está na
## sala. Quem ASSISTE SENTADO por 20 s ganha XP (uma vez por dia em cada sala).

const FILMS := [
	["O CICLO DA ÁGUA", ["O sol esquenta a água do mar...", "...ela vira vapor e sobe!", "Lá em cima, esfria e vira nuvem.", "A nuvem fica pesada: CHUVA!", "A água volta para os rios e o mar.", "E tudo começa de novo!"]],
	["O SISTEMA SOLAR", ["O Sol é uma estrela gigante.", "Mercúrio é o planeta mais perto dele.", "A Terra é o terceiro planeta.", "Júpiter é o maior de todos!", "Saturno tem anéis de gelo e pedra.", "Netuno é o mais longe e gelado."]],
	["A VIDA DAS ABELHAS", ["As abelhas vivem em colmeias.", "Elas levam o pólen de flor em flor.", "Isso ajuda a nascer frutas!", "A rainha bota os ovos.", "O mel é a comida delas no inverno.", "Sem abelhas, teríamos poucas frutas."]],
	["DINOSSAUROS", ["Eles viveram há milhões de anos.", "O T-Rex tinha dentes enormes.", "Alguns comiam só plantas.", "Os fósseis contam essa história.", "Os pássaros são parentes deles!", "Fim da sessão. Palmas!"]],
	["A HISTÓRIA DO BRASIL", ["Os povos indígenas já viviam aqui.", "Em 1500 chegaram os portugueses.", "O pau-brasil deu nome ao país.", "Em 1822: Independência!", "Em 1888 a Lei Áurea acabou com a escravidão.", "Em 1889 o Brasil virou República."]],
	["OS BIOMAS DO BRASIL", ["Amazônia: a maior floresta tropical.", "Cerrado: a savana brasileira.", "Caatinga: cactos e pouca chuva.", "Pantanal: campos que alagam.", "Mata Atlântica: no litoral.", "Pampa: campos do Sul."]],
	["COMO FUNCIONA O CORPO", ["O coração bombeia o sangue.", "Os pulmões trazem o oxigênio.", "O cérebro comanda tudo.", "Os ossos sustentam o corpo.", "Comer bem dá energia.", "Dormir bem faz crescer!"]],
]
## Matéria da aula -> filme que passa na sessão (aula na sala de vídeo).
const SUBJECT_FILM := {"História": 4, "Geografia": 5, "Ciências": 6, "Física": 1, "Química": 0}

var room_rect: Rect2
var floor_y := 0.0
var label: Label3D
var room_name := ""
var _film := 0
var _scene := 0
var _t := 0.0
var _sit_t := 0.0
var _check := 0.0


func _ready() -> void:
	_film = randi() % FILMS.size()
	_show()


func _process(delta: float) -> void:
	_check -= delta
	var p := GameManager.player as PlayerController
	if p == null:
		return
	var inside := room_rect.has_point(Vector2(p.global_position.x, p.global_position.z)) and absf(p.global_position.y - floor_y) < 2.0
	if not inside:
		_sit_t = 0.0
		return
	# aula nesta sala: passa o filme da matéria
	var sd := get_tree().get_first_node_in_group("school_day")
	if sd and sd.class_room == room_name and int(sd.phase) in [1, 4]:
		var subj: String = sd._subjects[sd._class_no] if sd._class_no < sd._subjects.size() else ""
		var want: int = SUBJECT_FILM.get(subj, _film)
		if want != _film:
			_film = want
			_scene = 0
			_show()
	_t += delta
	if _t > 4.0:
		_t = 0.0
		_scene += 1
		if _scene >= (FILMS[_film][1] as Array).size():
			_scene = 0
			_film = (_film + 1) % FILMS.size()
		_show()
	if p.mode == PlayerController.Mode.SITTING:
		_sit_t += delta
		if _sit_t >= 20.0:
			_sit_t = -999.0
			var st: Dictionary = SaveManager.section("stats")
			var done: Dictionary = st.get("atividades_dia", {})
			var today := int(SaveManager.section("progress").get("days_completed", 0))
			var k := "cinema_" + room_name
			if int(done.get(k, -1)) != today:
				done[k] = today
				st["atividades_dia"] = done
				GameManager.add_rewards(10, 0)
				GameManager.show_toast("Você assistiu à sessão '%s'! (+10 XP)" % FILMS[_film][0])
				AudioManager.play_ui("reward", -6.0)
	elif _sit_t > 0.0:
		_sit_t = 0.0


func _show() -> void:
	if label:
		label.text = "%s\n\n%s" % [FILMS[_film][0], FILMS[_film][1][_scene]]
