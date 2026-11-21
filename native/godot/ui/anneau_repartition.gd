extends RefCounted
## Anneau de répartition en parts (revue du 21/11/2026, n° 6, option B choisie par Léo).
## Une part = {"n": int, "couleur": Color, "encre": Color, "mot": String}. Les chiffres et les mots
## doublent toujours la couleur ; les parts vides ne sont pas dessinées (leur chiffre reste dans la légende).
## Coordonnées en unités du gabarit (comme D.place) ; le dessin se fait en pixels réels.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")

## Couleurs des parts : jetons de charte.gd (REPOS, NORMAL, INTENSIF…), communs avec Club › Staff.

static func total(parts: Array) -> int:
	var somme := 0
	for part: Dictionary in parts: somme += int(part.n)
	return somme

## Anneau de centre `centre` (gabarit), diamètre extérieur `diametre`, épaisseur `epaisseur`.
static func anneau(parent: Node, centre: Vector2, diametre: float, epaisseur: float, parts: Array, taille_chiffre: int = 30, au_clic: Callable = Callable()) -> Control:
	var dessin := Anneau.new()
	dessin.parts = parts
	dessin.au_clic = au_clic
	dessin.epaisseur_relative = epaisseur / diametre
	dessin.name = "RepartitionAnneau"
	dessin.mouse_filter = Control.MOUSE_FILTER_STOP if au_clic.is_valid() else Control.MOUSE_FILTER_IGNORE
	parent.add_child(dessin)
	D.place(dessin, Rect2(centre - Vector2(diametre, diametre) / 2.0, Vector2(diametre, diametre)))
	var somme := total(parts)
	if somme <= 0: return dessin
	var rayon_moyen := (diametre - epaisseur) / 2.0
	var depart := 0.0
	for part: Dictionary in parts:
		var fraction := float(part.n) / float(somme)
		if int(part.n) > 0 and fraction >= 0.09:
			var angle := -PI / 2.0 + (depart + fraction / 2.0) * TAU
			var point := centre + Vector2(cos(angle), sin(angle)) * rayon_moyen
			var etiquette := D.text(parent, point.x, point.y + taille_chiffre * 0.34, str(part.n), taille_chiffre, part.encre, 800, 60, HORIZONTAL_ALIGNMENT_CENTER)
			etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		depart += fraction
	return dessin

class Anneau extends Control:
	var parts: Array = []
	var epaisseur_relative := 0.16
	## Appelé avec l'indice de la part cliquée ; une part vide n'est jamais cliquable (apparence neutre).
	var au_clic := Callable()

	func part_en(position: Vector2) -> int:
		var decalage := position - size / 2.0
		var exterieur := size.x / 2.0
		if decalage.length() > exterieur or decalage.length() < exterieur * (1.0 - 2.0 * epaisseur_relative): return -1
		var somme := 0
		for part: Dictionary in parts: somme += int(part.n)
		if somme <= 0: return -1
		var fraction := fposmod(atan2(decalage.y, decalage.x) + PI / 2.0, TAU) / TAU
		var depart := 0.0
		for i in parts.size():
			var etendue := float(parts[i].n) / float(somme)
			if int(parts[i].n) > 0 and fraction >= depart and fraction < depart + etendue: return i
			depart += etendue
		return -1

	func _get_tooltip(at_position: Vector2) -> String:
		var i := part_en(at_position)
		return str(parts[i].get("infobulle", "")) if i >= 0 else ""

	func _get_cursor_shape(at_position: Vector2 = Vector2.ZERO) -> Control.CursorShape:
		return Control.CURSOR_POINTING_HAND if part_en(at_position) >= 0 else Control.CURSOR_ARROW

	func _gui_input(event: InputEvent) -> void:
		var clic := event as InputEventMouseButton
		if clic == null or not clic.pressed or clic.button_index != MOUSE_BUTTON_LEFT or not au_clic.is_valid(): return
		var i := part_en(clic.position)
		if i >= 0: au_clic.call(i)

	func _draw() -> void:
		var somme := 0
		for part: Dictionary in parts: somme += int(part.n)
		var epaisseur := size.x * epaisseur_relative
		var centre := size / 2.0
		var rayon := size.x / 2.0 - epaisseur / 2.0
		draw_arc(centre, rayon, 0.0, TAU, 96, C.Charte.PANNEAU_3, epaisseur, true)
		if somme <= 0: return
		var visibles: Array = parts.filter(func(p: Dictionary): return int(p.n) > 0)
		var angle := -PI / 2.0
		# Un seul groupe : anneau plein, sans coupure.
		var coupure := 0.0 if visibles.size() <= 1 else 0.045
		for part: Dictionary in visibles:
			var etendue := float(part.n) / float(somme) * TAU
			draw_arc(centre, rayon, angle + coupure / 2.0, angle + etendue - coupure / 2.0, maxi(8, int(etendue * 24.0)), part.couleur, epaisseur, true)
			angle += etendue
