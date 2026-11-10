class_name SlideSpot
extends Interactable
## Topo do escorregador do Parque do Morro: "Escorregar!" leva o jogador
## pela curva do escorregador até o gramado.

var points: PackedVector3Array = []
var _busy := false


func _ready() -> void:
	super._ready()
	prompt = "Escorregar!"
	interact_radius = 1.8


func can_interact(_player: Node) -> bool:
	return not _busy and points.size() > 1


func interact(player: Node) -> void:
	if _busy:
		return
	var p := player as PlayerController
	if p == null or p.mode != PlayerController.Mode.FREE or p.riding:
		return
	_busy = true
	p.input_enabled = false
	p.movement_locked = true
	p.velocity = Vector3.ZERO
	p.visual.play("sit_down")
	AudioManager.play_3d("whoosh", global_position, -2.0)
	var total := 0.0
	for k in points.size() - 1:
		total += points[k].distance_to(points[k + 1])
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var d := t * total
		var acc := 0.0
		for k in points.size() - 1:
			var seg := points[k].distance_to(points[k + 1])
			if acc + seg >= d or k == points.size() - 2:
				var f := clampf((d - acc) / maxf(seg, 0.001), 0.0, 1.0)
				var pos := points[k].lerp(points[k + 1], f)
				p.global_position = pos + Vector3(0, 0.08, 0)
				var dir := points[k + 1] - points[k]
				p.yaw = atan2(dir.x, dir.z)
				p.visual.rotation.y = p.yaw
				break
			acc += seg, 0.0, 1.0, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		p.visual.stop_action()
		p.visual.play("celebrate")
		Effects.burst(p.global_position + Vector3(0, 1.0, 0), "dust")
		p.input_enabled = true
		p.movement_locked = false
		GameManager.add_stat("escorregadas")
		if int(SaveManager.section("stats").get("escorregadas", 0)) >= 10:
			GameManager.unlock_achievement("escorrega_10")
		_busy = false)
