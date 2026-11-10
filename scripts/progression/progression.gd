class_name Progression
extends Node
## Economia e progressão: inventário/guarda-roupa, compras, decoração da
## carteira, missões diárias (3 por dia, progresso automático) e conquistas.

signal inventory_changed
signal daily_changed

const ACHIEVEMENTS := {
	"primeiro_dia": ["Primeiro dia", "Termine seu primeiro dia de aula."],
	"dia_10": ["Veterano", "Complete 10 dias de aula."],
	"nivel_5": ["Subindo de nível", "Alcance o nível 5."],
	"rico": ["Cofrinho cheio", "Junte 500 moedas."],
	"estilo": ["Estiloso", "Tenha 10 itens no guarda-roupa."],
	"amigo_do_peito": ["Amigo do peito", "Tenha um melhor amigo."],
	"campeao_torneio": ["Campeão do torneio", "Vença 3 partidas do torneio de futebol."],
	"gude_rara": ["Galáxia na mão", "Ganhe a bolinha de gude Galáxia."],
	"piloto": ["Piloto de papel", "Faça 120 pontos num lançamento de aviãozinho."],
	"velocista": ["Velocista", "Vença uma corrida."],
	"corda_30": ["Pula-pula", "Faça 30 pulos de corda seguidos."],
	"mira_certeira": ["Mira certeira", "Faça 200 pontos na pontaria."],
	"album_completo": ["Álbum completo", "Complete o álbum de figurinhas."],
	"bolo_de_chocolate": ["Formiguinha", "Coma o bolo de chocolate especial."],
	"primeira_ocorrencia": ["Visita ilustre", "Conheça a diretoria... do jeito mais difícil."],
	"aluno_exemplar": ["Aluno exemplar", "Passe 5 dias seguidos sem levar bronca."],
	"tarefas_50": ["Cdf", "Acerte 50 tarefas de aula."],
	"escorrega_10": ["Rei do escorregador", "Desça o escorregador do morro 10 vezes."],
	"cestinha": ["Cestinha", "Faça 10 cestas numa partida de basquete."],
	"detetive": ["Detetive", "Ache todos no esconde-esconde em menos de 1 minuto."],
}

const DAILY_POOL := [
	{"key": "acertos", "target": 4, "desc": "Acerte %d tarefas na aula", "coins": 15},
	{"key": "conversas", "target": 3, "desc": "Converse com %d colegas", "coins": 12},
	{"key": "mg_futebol", "target": 1, "desc": "Jogue %d partida de futebol", "coins": 15},
	{"key": "mg_queimada", "target": 1, "desc": "Jogue %d partida de queimada", "coins": 15},
	{"key": "mg_gude", "target": 1, "desc": "Jogue bolinha de gude %d vez", "coins": 12},
	{"key": "mg_aviao", "target": 1, "desc": "Lance aviõezinhos %d vez", "coins": 12},
	{"key": "mg_corda", "target": 1, "desc": "Pule corda %d vez", "coins": 10},
	{"key": "mg_basquete", "target": 1, "desc": "Jogue basquete %d vez", "coins": 12},
	{"key": "mg_esconde", "target": 1, "desc": "Brinque de esconde-esconde %d vez", "coins": 15},
	{"key": "escorregadas", "target": 2, "desc": "Desça o escorregador do morro %d vezes", "coins": 10},
	{"key": "kicks", "target": 10, "desc": "Chute a bola %d vezes", "coins": 10},
	{"key": "sits", "target": 3, "desc": "Sente-se em %d lugares", "coins": 8},
	{"key": "lanches", "target": 1, "desc": "Compre %d lanche na cantina", "coins": 10},
	{"key": "missoes", "target": 1, "desc": "Ajude %d colega (missão)", "coins": 20},
	{"key": "vitorias", "target": 2, "desc": "Vença %d minijogos", "coins": 20},
]

var player: PlayerController
var world: SchoolWorld
var npcs: NPCManager
var _decor_root: Node3D
var _check_t := 1.0


func setup(p: PlayerController, w: SchoolWorld, m: NPCManager, day: SchoolDay, mg: MinigameManager) -> void:
	player = p
	world = w
	npcs = m
	var inv := inventory()
	if not inv.has("owned") or inv.owned.is_empty():
		inv["owned"] = ShopCatalog.DEFAULT_OWNED.duplicate()
	if not inv.has("equipped") or inv.equipped.is_empty():
		inv["equipped"] = {"camiseta": "cam_uniforme", "calca": "cal_bermuda", "calcado": "ten_branco", "mochila": "moc_vermelha",
			"bone": "bon_nenhum", "penteado": "pen_curto", "tinta": "tin_castanho", "acessorio": "ace_sem_oculos"}
	if not inv.has("decor"):
		inv["decor"] = []
	if not "skin_nenhuma" in inv.owned:
		inv.owned.append("skin_nenhuma")
	day.phase_changed.connect(func(ph):
		if ph == SchoolDay.Phase.ARRIVAL:
			ensure_daily(day.day))
	day.day_finished.connect(_on_day_finished)
	mg.game_finished.connect(func(r):
		if int(r.get("won", 0)) > 0:
			GameManager.add_stat("vitorias"))
	GameManager.friendship_changed.connect(func(_id, _p, reason):
		if reason == "conversa":
			GameManager.add_stat("conversas"))
	GameManager.achievement_unlocked.connect(func(aid):
		var a: Array = ACHIEVEMENTS.get(aid, [aid, ""])
		GameManager.show_toast("Conquista desbloqueada: %s!" % a[0])
		AudioManager.play_ui("celebrate", -6.0))
	apply_wardrobe()
	_build_decor()
	var veh: String = inventory().get("equipped", {}).get("veiculo", "")
	if veh != "":
		player.set_vehicle(ShopCatalog.get_item(veh).get("vehicle", ""))


static func inventory() -> Dictionary:
	return SaveManager.section("inventory")


static func owns(id: String) -> bool:
	return id in inventory().get("owned", [])


## Compra um item. Retorna "" se deu certo ou o motivo do erro.
func buy(id: String) -> String:
	var item := ShopCatalog.get_item(id)
	if item.is_empty():
		return "Item inexistente."
	if GameManager.level() < int(item.lvl):
		return "Disponível no nível %d." % item.lvl
	if not item.get("consumable", false) and owns(id):
		return "Você já tem este item."
	var price := ShopCatalog.price_of(item)
	if not GameManager.spend_coins(price):
		return "Moedas insuficientes."
	Telemetry.track("purchase", {"item": id, "name": str(item.get("name", id)), "price": price, "category": str(item.cat),
		"discount": ShopCatalog.discount_of(id)})
	if item.has("bundle") or item.has("bundle_packs"):
		_grant_bundle(item)
		AudioManager.play_ui("celebrate", -4.0)
		inventory_changed.emit()
		SaveManager.save_game()
		return ""
	if item.get("consumable", false):
		match item.cat:
			"figurinha":
				Stickers.open_pack()
			"gude":
				var col: Dictionary = SaveManager.section("collections")
				var gude: Dictionary = col.get("gude", {})
				for k in 3:
					var t: Dictionary = preload("res://scripts/minigames/marbles.gd").TYPES.pick_random()
					gude[t.id] = int(gude.get(t.id, 0)) + 1
				col["gude"] = gude
				GameManager.show_toast("+3 bolinhas de gude na coleção!")
	else:
		inventory().owned.append(id)
		if item.has("vehicle"):
			equip(id)
			GameManager.show_toast("Toque no botão de %s para montar!" % item.name.to_lower())
		if item.cat == "decoracao":
			inventory().decor.append(item.decor)
			_build_decor()
		if inventory().owned.size() >= 10:
			GameManager.unlock_achievement("estilo")
	AudioManager.play_ui("ui_confirm")
	inventory_changed.emit()
	SaveManager.save_game()
	return ""


func _grant_bundle(item: Dictionary) -> void:
	var inv := inventory()
	for bid in item.get("bundle", []):
		if not bid in inv.owned:
			inv.owned.append(bid)
			var it := ShopCatalog.get_item(bid)
			if it.cat == "decoracao":
				inv.decor.append(it.decor)
	if not item.get("consumable", false) and not item.id in inv.owned:
		inv.owned.append(item.id)
	var packs: Dictionary = item.get("bundle_packs", {})
	for i in int(packs.get("figurinha", 0)):
		Stickers.open_pack()
	if int(packs.get("gude", 0)) > 0:
		var col: Dictionary = SaveManager.section("collections")
		var gude: Dictionary = col.get("gude", {})
		for k in 3 * int(packs.gude):
			var t: Dictionary = preload("res://scripts/minigames/marbles.gd").TYPES.pick_random()
			gude[t.id] = int(gude.get(t.id, 0)) + 1
		col["gude"] = gude
	# veste o que tem visual
	for bid in item.get("bundle", []):
		if ShopCatalog.get_item(bid).has("look"):
			equip(bid)
	_build_decor()
	GameManager.show_toast("Pacote aberto: %s!" % item.name)


func equip(id: String) -> void:
	var item := ShopCatalog.get_item(id)
	if item.has("vehicle") and owns(id):
		inventory().equipped["veiculo"] = id
		player.set_vehicle(item.vehicle)
		inventory_changed.emit()
		return
	if item.is_empty() or not owns(id) or not item.has("look"):
		return
	var slot: String = item.cat
	if id.begins_with("tin_"):
		slot = "tinta"
	inventory().equipped[slot] = id
	# trocar uma peça de roupa tira a skin; equipar skin vale por cima de tudo
	if slot != "skin" and slot in ["camiseta", "calca", "calcado", "mochila", "bone"]:
		inventory().equipped["skin"] = "skin_nenhuma"
	apply_wardrobe()
	inventory_changed.emit()


func is_equipped(id: String) -> bool:
	return id in inventory().get("equipped", {}).values()


## Aparência resultante dos itens equipados (+ itens extras para prévia).
static func appearance_with(extra_ids: Array = []) -> CharacterAppearance:
	var base := CharacterAppearance.new()
	var saved: Dictionary = SaveManager.section("player").get("appearance", {})
	var d := base.to_dict()
	if not saved.is_empty():
		d.merge(saved, true)
	var eq: Dictionary = inventory().get("equipped", {})
	for slot in eq.keys():
		if slot != "skin":
			d.merge(ShopCatalog.get_item(eq[slot]).get("look", {}), true)
	var skin_look: Dictionary = ShopCatalog.get_item(str(eq.get("skin", ""))).get("look", {})
	var preview_clothes := extra_ids.any(func(x): return ShopCatalog.get_item(x).cat in ["camiseta", "calca", "calcado", "mochila", "bone"])
	if not preview_clothes:
		d.merge(skin_look, true)
	for id in extra_ids:
		d.merge(ShopCatalog.get_item(id).get("look", {}), true)
	return CharacterAppearance.from_dict(d)


func apply_wardrobe() -> void:
	var a := appearance_with()
	player.set_appearance(a)


# ------------------------------------------------------------- decoração

func _build_decor() -> void:
	if _decor_root:
		_decor_root.get_parent().remove_child(_decor_root)
		_decor_root.queue_free()
	_decor_root = Node3D.new()
	_decor_root.name = "DeskDecor"
	world.add_child(_decor_root)
	var desk: Seat = npcs.player_desk
	if desk == null:
		return
	var fwd := desk.global_basis.z
	var right := desk.global_basis.x
	var top := desk.global_position + fwd * 0.46 + Vector3(0, 0.745, 0)
	var md := MeshData.new()
	var slots := [-0.2, 0.2, 0.0, -0.08, 0.1]
	var i := 0
	for d in inventory().get("decor", []):
		var p: Vector3 = top + right * slots[i % slots.size()] + fwd * (0.1 if i >= 2 else -0.05)
		match d:
			"estojo":
				md.cur_color = Color("e84393")
				md.add_box(Transform3D(Basis(Vector3.UP, desk.global_rotation.y + 0.2), p + Vector3(0, 0.025, 0)), Vector3(0.18, 0.05, 0.07))
			"planta":
				md.cur_color = Color("c0392b")
				md.add_cylinder(Transform3D(Basis(), p + Vector3(0, 0.04, 0)), 0.04, 0.03, 0.08, 8)
				md.cur_color = Color("3f8a3a")
				md.add_sphere(Transform3D(Basis(), p + Vector3(0, 0.12, 0)), 0.06, 8, 6)
			"caneca":
				md.cur_color = Color("2f6fd0")
				md.add_cylinder(Transform3D(Basis(), p + Vector3(0, 0.05, 0)), 0.035, 0.035, 0.1, 8)
				md.cur_color = Color("f1c40f")
				md.add_cylinder(Transform3D(Basis(), p + Vector3(0.01, 0.13, 0)), 0.004, 0.004, 0.08, 4)
			"globo":
				md.cur_color = Color("3b8ed0")
				md.add_sphere(Transform3D(Basis(), p + Vector3(0, 0.1, 0)), 0.06, 10, 8)
				md.cur_color = Color("6d4c41")
				md.add_cylinder(Transform3D(Basis(), p + Vector3(0, 0.02, 0)), 0.03, 0.04, 0.04, 8)
			"trofeu":
				md.cur_color = Color("e8b923")
				md.add_cylinder(Transform3D(Basis(), p + Vector3(0, 0.1, 0)), 0.05, 0.02, 0.1, 10)
				md.add_box(Transform3D(Basis(), p + Vector3(0, 0.02, 0)), Vector3(0.07, 0.04, 0.07))
		i += 1
	if md.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	_decor_root.add_child(mi)


# ------------------------------------------------------------- missões diárias

static func daily() -> Dictionary:
	return SaveManager.section("missions")


func ensure_daily(day_n: int) -> void:
	var m := daily()
	if int(m.get("day", -1)) == day_n and m.has("list"):
		return
	var r := RandomNumberGenerator.new()
	r.seed = day_n * 7907 + 13
	var pool := DAILY_POOL.duplicate()
	var list := []
	for i in 3:
		var idx := r.randi() % pool.size()
		var e: Dictionary = pool[idx].duplicate()
		pool.remove_at(idx)
		e["base"] = _stat(e.key)
		e["done"] = false
		list.append(e)
	m["day"] = day_n
	m["list"] = list
	daily_changed.emit()


func _stat(key: String) -> int:
	var stats: Dictionary = SaveManager.section("stats")
	if key.begins_with("mg_"):
		return int(stats.get(key, {}).get("played", 0)) if stats.get(key) is Dictionary else 0
	return int(stats.get(key, 0))


static func mission_progress(e: Dictionary, current: int) -> int:
	return clampi(current - int(e.get("base", 0)), 0, int(e.target))


func daily_list() -> Array:
	return daily().get("list", [])


func progress_of(e: Dictionary) -> int:
	return mission_progress(e, _stat(e.key))


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 1.0
	for e in daily_list():
		if not e.done and progress_of(e) >= int(e.target):
			e.done = true
			GameManager.add_rewards(10, int(e.coins))
			GameManager.show_toast("Missão diária completa: %s (+%d moedas)" % [str(e.desc) % e.target, e.coins])
			AudioManager.play_ui("ui_confirm")
			daily_changed.emit()
	_check_achievements()


func _check_achievements() -> void:
	var lv := GameManager.level()
	if lv >= 5:
		GameManager.unlock_achievement("nivel_5")
	if GameManager.coins() >= 500:
		GameManager.unlock_achievement("rico")
	for s in NPCRoster.STUDENTS:
		if Friendship.level(s.id) >= 5:
			GameManager.unlock_achievement("amigo_do_peito")
			break
	var acts: Dictionary = SaveManager.section("progress").get("activities", {})
	if int(acts.get("tarefas_certas", 0)) >= 50:
		GameManager.unlock_achievement("tarefas_50")


func _on_day_finished(s: Dictionary) -> void:
	GameManager.unlock_achievement("primeiro_dia")
	if int(s.day) >= 10:
		GameManager.unlock_achievement("dia_10")
