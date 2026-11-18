extends RefCounted
## Tenues originales de présentation, jamais un équipement réel de club.

const IVORY := Color("f0ecdf")
const ANTHRACITE := Color("202b35")
# Teintes des deux bandes de pelouse mesurées dans la vue tactique de jour.
const GRASS_DARK := Color("2a542e")
const GRASS_LIGHT := Color("305c33")
# Carnations des joueurs (match_athlete.gd) : en vue TV, un maillot trop proche d'une
# carnation fait paraître les joueurs torse nu (constat du 18 novembre 2026, tenue
# brun orangé de Meadowbridge). Proche = moins de SKIN_NEAR en RVB et teinte voisine.
const Athlete = preload("res://match_athlete.gd")
const SKIN_NEAR := 0.22
const SKIN_HUE := 0.07
# Écart minimal visé après correction : la teinte du club est gardée, seules la
# saturation et la clarté bougent (orange brûlé, ambre, rouge profond ou ivoire).
const SKIN_SAFE_GAP := 0.25

static func resolve(colors: Array[Color]) -> Array[Dictionary]:
	var home := skin_safe(colors[0])
	var away_club := skin_safe(colors[1])
	var away := away_club
	var a := Vector3(home.r, home.g, home.b)
	var b := Vector3(away.r, away.g, away.b)
	var distance := a.distance_to(b)
	var hue_gap := absf(home.h - away.h)
	hue_gap = minf(hue_gap, 1.0 - hue_gap)
	var close_hue := hue_gap < 0.09 and absf(home.s - away.s) < 0.35 and absf(home.v - away.v) < 0.35
	var close_value := hue_gap < 0.22 and distance < 0.55 and _contrast(home, away) < 1.18
	if distance < 0.38 or close_hue or close_value:
		away = _away_fallback(home)
	return [{"shirt": home, "detail": _trim(home, home.lightened(0.4)), "shorts": ANTHRACITE, "marker": home},
		{"shirt": away, "detail": _trim(away, away_club if away != away_club else away.lightened(0.4)), "shorts": Color("e5dfd1"),
			"marker": away, "outlined_marker": away == ANTHRACITE and away != colors[1]}]

## Écart RVB entre une couleur et la carnation la plus proche des joueurs.
static func skin_gap(color: Color) -> float:
	var gap := INF
	for tone in Athlete.SKINS:
		var skin := Color(str(tone))
		gap = minf(gap, Vector3(color.r, color.g, color.b).distance_to(Vector3(skin.r, skin.g, skin.b)))
	return gap

## Vrai quand la couleur se confond avec une carnation : proche en RVB et de teinte voisine.
static func skin_like(color: Color) -> bool:
	for tone in Athlete.SKINS:
		var skin := Color(str(tone))
		var hue_gap := absf(color.h - skin.h)
		hue_gap = minf(hue_gap, 1.0 - hue_gap)
		if Vector3(color.r, color.g, color.b).distance_to(Vector3(skin.r, skin.g, skin.b)) < SKIN_NEAR and hue_gap < SKIN_HUE:
			return true
	return false

## Couleur de club gardée si elle se distingue de la peau ; sinon même teinte, saturée,
## éclaircie ou assombrie jusqu'à l'écart SKIN_SAFE_GAP (un tissu pâle part vers l'ivoire).
static func skin_safe(color: Color) -> Color:
	if not skin_like(color):
		return color
	if color.s < 0.35:
		var pale := Color.from_hsv(color.h, color.s * 0.35, minf(1.0, color.v + 0.1))
		if skin_gap(pale) >= SKIN_SAFE_GAP:
			return pale
	for saturation: float in [0.92, 1.0]:
		for shift: float in [0.0, 0.1, -0.1, 0.2, -0.2, 0.3, -0.3]:
			var candidate := Color.from_hsv(color.h, saturation, clampf(color.v + shift, 0.1, 1.0))
			if skin_gap(candidate) >= SKIN_SAFE_GAP:
				return candidate
	return ANTHRACITE

## Bords de manches, accent du col et revers des chaussettes : jamais couleur chair,
## sinon ivoire ou anthracite selon ce qui tranche le mieux sur le maillot.
static func _trim(shirt: Color, detail: Color) -> Color:
	if not skin_like(detail):
		return detail
	return IVORY if _contrast(shirt, IVORY) > _contrast(shirt, ANTHRACITE) else ANTHRACITE

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
