extends RefCounted
## Zones de classement Monde (world-standings-zones.json projeté par world-model.cjs), partagées par l'écran
## Classements (competition_canvas.gd) et le classement court du Bureau (office_canvas.gd, office.gd) :
## liseré, forme dessinée et mot, jamais la couleur seule.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const WIN := Color("54de81")
const WARM := Color("efc665")
const LOSS := Color("ef8477")
const TINTS := {"bye": WIN, "playoff": WIN, "promotion-playoff": WARM, "relegation-playoff": WARM, "repechage": WARM, "relegation": LOSS}

## Zone d'une ligne du classement, seulement une fois le classement ouvert ({} sinon).
static func of(club: Dictionary) -> Dictionary:
	return club.zone if club.get("zone") is Dictionary and P.standings_open(club) else {}

static func tint(kind: String) -> Color:
	return TINTS.get(kind, C.IVORY)

## Zones présentes dans un extrait du classement, dans l'ordre des lignes, chacune une fois.
static func visible(rows: Array) -> Array:
	var seen := {}
	var result: Array = []
	for club in rows:
		if not club is Dictionary: continue
		var zone := of(club)
		var kind := str(zone.get("kind", ""))
		if kind.is_empty() or seen.has(kind): continue
		seen[kind] = true
		result.append(zone)
	return result

## Côté d'un symbole de zone (unités du gabarit) : 9 px réels au moins, sans empiéter sur le rang.
## Au Bureau : environ 11 px réels (BUREAU_MARK_PX), l'écran Classements garde 8 px.
const BUREAU_MARK_PX := 11.0
static func mark_side(real_px: float = 8.0) -> float:
	if real_px > 8.0: return clampf(real_px / C.density, 15.0, 22.0)
	return clampf(8.0 / C.density, 14.0, 16.0)

## Symbole de zone dessiné : ★ exempté du 1er tour, ● qualifié, ▲ barrage de montée, ◆ barrage de maintien,
## ▼ relégation, ○ repêchage possible. Formes distinctes : la zone se lit aussi en niveaux de gris.
## Dessiné car aucune fonte du jeu n'a ★●▲◆▼○ ; le texte lu porte le symbole Unicode du moteur.
static func mark(parent: Node, kind: String, area: Rect2, color: Color) -> Control:
	var holder := Control.new()
	holder.name = "StandingsZoneMark"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_meta("zone_kind", kind)
	parent.add_child(holder)
	D.place(holder, area)
	var side := maxf(4.0, area.size.x * C.density)
	var points := PackedVector2Array()
	match kind:
		"bye":
			for k in 10:
				var radius := 0.52 if k % 2 == 0 else 0.25
				var angle := -PI / 2 + k * PI / 5
				points.append(Vector2(0.5 + radius * cos(angle), 0.53 + radius * sin(angle)))
		"promotion-playoff": points = PackedVector2Array([Vector2(0.5, 0.06), Vector2(0.96, 0.9), Vector2(0.04, 0.9)])
		"relegation-playoff": points = PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)])
		"relegation": points = PackedVector2Array([Vector2(0.04, 0.1), Vector2(0.96, 0.1), Vector2(0.5, 0.94)])
		_:
			for k in 20: points.append(Vector2(0.5 + 0.44 * cos(k * TAU / 20), 0.5 + 0.44 * sin(k * TAU / 20)))
	for k in points.size(): points[k] *= side
	if kind == "repechage":
		var ring := Line2D.new()
		ring.points = points
		ring.closed = true
		ring.width = maxf(1.5, side * 0.16)
		ring.default_color = color
		holder.add_child(ring)
	else:
		var shape := Polygon2D.new()
		shape.polygon = points
		shape.color = color
		holder.add_child(shape)
	return holder

## Case de symbole pour une rangée de conteneur (Bureau compact) : centrée verticalement, de largeur fixe.
static func mark_slot(kind: String, real_px: float = 8.0) -> Control:
	var side := mark_side(real_px)
	var slot := Control.new()
	slot.name = "StandingsZoneMarkSlot"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = Vector2(side, side) * C.density
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not kind.is_empty(): mark(slot, kind, Rect2(0, 0, side, side), tint(kind))
	return slot

## Note du Bureau : la note courte de la ligue du club, sinon la note complète (l'appelant l'écrit seulement si elle tient), sinon vide.
static func bureau_note(model: Dictionary) -> String:
	for league in model.get("leagues", []):
		if league is Dictionary and league.get("id") == model.get("meta", {}).get("leagueId"):
			if league.get("zoneShortNote") is String and not str(league.zoneShortNote).is_empty(): return str(league.zoneShortNote)
			if league.get("zoneNote") is String: return str(league.zoneNote)
	return ""

## Texte lu d'une légende courte : « ★ Demi-finale directe · ▼ Relégation ».
static func legend_text(zones: Array) -> String:
	var spoken: Array[String] = []
	for zone: Dictionary in zones: spoken.append((str(zone.get("symbol", "")) + " " + str(zone.get("label", ""))).strip_edges())
	return " · ".join(spoken)
