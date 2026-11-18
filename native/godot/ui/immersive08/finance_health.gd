extends RefCounted
## Santé financière d’un club (native/engine/club-finance-health.cjs) : étiquette, propriétaire et
## mini-courbe des trois dernières saisons. Aucun montant affiché : le détail reste au club concerné.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const COLORS := {"fragile": Color("ef8477"), "correcte": Color("d7ad59"), "saine": Color("82e3a3"), "riche": Color("54de81")}
const POSITIVE := Color("53cd75")
const NEGATIVE := Color("ee7970")

## Trois barres, une par saison close (la plus récente à droite), vertes au-dessus de l’équilibre, rouges en dessous.
## L’échelle est propre au club : la forme compte, pas le montant.
class Sparkline extends Control:
	var values: Array = []

	func _draw() -> void:
		var zero := size.y * .5
		draw_line(Vector2(0, zero), Vector2(size.x, zero), Color(C.LINE, .9), maxf(1.0, C.px(2)))
		if values.is_empty(): return
		var peak := 1.0
		for v in values: peak = maxf(peak, absf(float(v)))
		var slot := size.x / 3.0
		for i in values.size():
			var v := float(values[i])
			var height := maxf(C.px(3), (size.y * .46) * absf(v) / peak)
			var x := slot * (3 - values.size() + i) + slot * .22
			var bar := Rect2(x, zero - height if v >= 0.0 else zero, slot * .56, height)
			draw_rect(bar, POSITIVE if v >= 0.0 else NEGATIVE)

static func color(health: Variant) -> Color:
	if health is Dictionary: return COLORS.get(str(health.get("etiquette", "")), C.MUTED)
	return C.MUTED

static func label(health: Variant) -> String:
	return str(health.get("libelle", "")) if health is Dictionary and health.get("libelle") != null else "—"

static func owner(health: Variant) -> String:
	if health is Dictionary and health.get("proprietaire") is Dictionary: return str(health.proprietaire.get("libelle", "—"))
	return "—"

## Lecture des saisons pour une infobulle : « 2026-2027 : dans le vert · 2027-2028 : en perte ».
static func reading(health: Variant) -> String:
	if not health is Dictionary or not health.get("courbe") is Array or health.courbe.is_empty():
		return "Pas encore de saison close sous cette direction."
	var parts: Array[String] = []
	for point: Dictionary in health.courbe:
		var season := int(point.get("saison", 0))
		var result := float(point.get("resultat", 0))
		var verdict := "à l’équilibre" if absf(result) < 250000.0 else ("dans le vert" if result > 0.0 else "en perte")
		parts.append("%d-%d : %s" % [season, season + 1, verdict])
	return " · ".join(parts)

static func sparkline(parent: Control, rectangle: Rect2, health: Variant, id: String = "") -> Control:
	var plot := Sparkline.new()
	if not id.is_empty(): plot.name = id
	plot.mouse_filter = Control.MOUSE_FILTER_PASS
	plot.tooltip_text = "Résultats des trois dernières saisons\n" + reading(health)
	if health is Dictionary and health.get("courbe") is Array:
		for point: Dictionary in health.courbe: plot.values.append(float(point.get("resultat", 0)))
	parent.add_child(plot)
	D.place(plot, rectangle)
	return plot

## Pastille « Saine » sur fond teinté.
static func chip(parent: Control, x: float, y: float, health: Variant, width: float = 150, id: String = "", height: float = 40) -> Control:
	var tint := color(health)
	var box := D.rect(parent, Rect2(x, y, width, height), Color(tint, .16), int(height * .5), Color(tint, .8))
	if not id.is_empty(): box.name = id
	D.text(box, 0, height * .5 + 8, label(health), 22 if height >= 36 else 19, tint, 700, width, HORIZONTAL_ALIGNMENT_CENTER)
	return box
