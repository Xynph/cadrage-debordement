extends RefCounted
## Tenues originales de présentation, jamais un équipement réel de club.

static func resolve(colors: Array[Color]) -> Array[Dictionary]:
	var away := colors[1]
	var a := Vector3(colors[0].r, colors[0].g, colors[0].b)
	var b := Vector3(away.r, away.g, away.b)
	var hue_gap := absf(colors[0].h - away.h)
	hue_gap = minf(hue_gap, 1.0 - hue_gap)
	var close_hue := hue_gap < 0.09 and absf(colors[0].s - away.s) < 0.35 and absf(colors[0].v - away.v) < 0.35
	if a.distance_to(b) < 0.38 or close_hue:
		var ivory := Color("f0ecdf")
		var anthracite := Color("202b35")
		away = ivory if _contrast(colors[0], ivory) > _contrast(colors[0], anthracite) else anthracite
	return [{"shirt": colors[0], "detail": colors[0].lightened(0.4), "shorts": Color("202b35"), "marker": colors[0]},
		{"shirt": away, "detail": colors[1] if away != colors[1] else away.lightened(0.4), "shorts": Color("e5dfd1"), "marker": away}]

static func _contrast(a: Color, b: Color) -> float:
	var first := a.srgb_to_linear().get_luminance()
	var second := b.srgb_to_linear().get_luminance()
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)
