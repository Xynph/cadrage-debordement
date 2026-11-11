extends RefCounted
## Tenues originales de présentation, jamais un équipement réel de club.

const IVORY := Color("f0ecdf")
const ANTHRACITE := Color("202b35")
# Teintes des deux bandes de pelouse mesurées dans la vue tactique de jour.
const GRASS_DARK := Color("2a542e")
const GRASS_LIGHT := Color("305c33")

static func resolve(colors: Array[Color]) -> Array[Dictionary]:
	var home := colors[0]
	var away := colors[1]
	var a := Vector3(home.r, home.g, home.b)
	var b := Vector3(away.r, away.g, away.b)
	var distance := a.distance_to(b)
	var hue_gap := absf(home.h - away.h)
	hue_gap = minf(hue_gap, 1.0 - hue_gap)
	var close_hue := hue_gap < 0.09 and absf(home.s - away.s) < 0.35 and absf(home.v - away.v) < 0.35
	var close_value := hue_gap < 0.22 and distance < 0.55 and _contrast(home, away) < 1.18
	if distance < 0.38 or close_hue or close_value:
		away = _away_fallback(home)
	return [{"shirt": home, "detail": home.lightened(0.4), "shorts": ANTHRACITE, "marker": home},
		{"shirt": away, "detail": colors[1] if away != colors[1] else away.lightened(0.4), "shorts": Color("e5dfd1"),
			"marker": away, "outlined_marker": away == ANTHRACITE and away != colors[1]}]

static func _away_fallback(home: Color) -> Color:
	var ivory_team := _contrast(home, IVORY)
	var dark_team := _contrast(home, ANTHRACITE)
	# Une tenue doit d’abord se séparer du domicile, notamment face aux tons clairs.
	if minf(ivory_team, dark_team) < 2.0:
		return IVORY if ivory_team > dark_team else ANTHRACITE
	var ivory_score := minf(ivory_team, _grass_contrast(IVORY))
	var dark_score := minf(dark_team, _grass_contrast(ANTHRACITE))
	return IVORY if ivory_score > dark_score else ANTHRACITE

static func _grass_contrast(color: Color) -> float:
	return minf(_contrast(color, GRASS_DARK), _contrast(color, GRASS_LIGHT))

static func _contrast(a: Color, b: Color) -> float:
	var first := a.srgb_to_linear().get_luminance()
	var second := b.srgb_to_linear().get_luminance()
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)
