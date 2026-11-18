extends SceneTree
func _init() -> void:
	var pts := KartTrack.points()
	var t := KartTrack.length()
	var mx := 0.0
	var at := 0.0
	var minx := INF
	var maxx := -INF
	var minz := INF
	var maxz := -INF
	var s := 0.0
	var tight := 0
	while s < t:
		var c := absf(KartTrack.curve_at(s))
		if c > mx:
			mx = c
			at = s
		if c > 1.0 / 9.0:
			tight += 1
		var p := KartTrack.pos_at(s)
		minx = minf(minx, p.x); maxx = maxf(maxx, p.x); minz = minf(minz, p.z); maxz = maxf(maxz, p.z)
		s += 1.0
	var curvy := 0
	s = 0.0
	while s < t:
		if absf(KartTrack.curve_at(s)) > 0.02:
			curvy += 1
		s += 1.0
	print("len=", t, " max_curve=", mx, " (r=", 1.0 / mx, ") at ", KartTrack.pos_at(at), " tight_m=", tight, " curvy%=", 100.0 * curvy / t)
	print("x ", minx, "..", maxx, " z ", minz, "..", maxz)
	# distância até os muros (oeste/leste: x=±90 e ±116; fundos z=-151)
	var bad := 0
	s = 0.0
	while s < t:
		var p2 := KartTrack.pos_at(s)
		if p2.y < 5.0 and (absf(p2.x) > 110.5 or (absf(p2.x) < 95.5 and p2.z < 60 and p2.z > -125) or p2.z < -145.5):
			bad += 1
		s += 1.0
	print("fora_da_faixa_m=", bad)
	quit()
