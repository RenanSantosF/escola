class_name Learning
extends RefCounted
## Perfil de aprendizagem: a idade real define o ano escolar inicial e o
## desempenho ajusta automaticamente (+/- 2 anos) — se acertar muito, as
## perguntas ficam mais desafiadoras; se errar muito, ficam mais fáceis.

const MIN_AGE := 5
const MAX_AGE := 15


static func data() -> Dictionary:
	return SaveManager.section("learning")


static func has_age() -> bool:
	return int(data().get("age", 0)) > 0


static func age() -> int:
	return int(data().get("age", 9))


static func set_age(a: int) -> void:
	data()["age"] = clampi(a, MIN_AGE, MAX_AGE)
	data()["offset"] = 0
	data()["recent"] = []


static func level() -> int:
	return clampi(ClassroomTasks.level_for_age(age()) + int(data().get("offset", 0)), 1, 9)


static func grade_name() -> String:
	return "%dº ano" % level()


## Registra um resultado; a cada 6 respostas reavalia a dificuldade.
static func record(ok: bool) -> void:
	var d := data()
	var recent: Array = d.get("recent", [])
	recent.append(1 if ok else 0)
	if recent.size() >= 6:
		var rate := float(recent.count(1)) / recent.size()
		var off := int(d.get("offset", 0))
		if rate >= 0.84 and off < 2:
			d["offset"] = off + 1
			GameManager.show_toast("Você está mandando bem! As atividades vão ficar mais desafiadoras.")
		elif rate <= 0.34 and off > -2:
			d["offset"] = off - 1
			GameManager.show_toast("As próximas atividades vão ficar um pouco mais fáceis.")
		recent = []
	d["recent"] = recent


## Online: matérias IGUAIS para a turma toda (dependem só do dia da escola e
## da turma), para todo mundo ir para a mesma sala. A Turma B tem outra ordem
## (as duas turmas não lotam o mesmo laboratório).
static func subjects_shared(day_key: int, turma: int) -> Array:
	var s := ClassroomTasks.SUBJECTS
	var a: String = s[(day_key * 2 + turma * 3) % s.size()]
	var b: String = s[(day_key * 2 + 1 + turma * 3) % s.size()]
	return [a, b]


## Conteúdo das perguntas: Física e Química só a partir do nível 5 (antes vira Ciências).
static func content_subject(subj: String) -> String:
	if subj in ["Física", "Química"] and level() < 5:
		return "Ciências"
	return subj


## Matérias do dia (duas aulas), em rodízio.
static func subjects_for_day(day: int) -> Array:
	var s := ClassroomTasks.SUBJECTS
	var lv := level()
	var pool := s.filter(func(x): return not (x in ["Física", "Química"]) or lv >= 5)
	var a: String = pool[(day * 2) % pool.size()]
	var b: String = pool[(day * 2 + 1) % pool.size()]
	return [a, b]
