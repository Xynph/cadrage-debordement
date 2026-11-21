extends RefCounted
## Répartition en parts : barre empilée (option A) et anneau (option B). Composant PROVISOIRE d'une option visuelle
## (revue du 21/11/2026, n° 6) ; à unifier avec la jauge du lot Staff / Travail à l'intégration.
## Une part = {"n": int, "couleur": Color, "encre": Color, "motif": int, "mot": String}. Les chiffres et les mots
## doublent toujours la couleur ; les parts vides ne sont pas dessinées (leur chiffre reste dans la légende).
## Coordonnées en unités du gabarit (comme D.place) ; le dessin se fait en pixels réels.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")

const MOTIF_AUCUN := 0
const MOTIF_DIAGONALE := 1
const MOTIF_POINTS := 2

static func total(parts: Array) -> int:
	var somme := 0
	for part: Dictionary in parts: somme += int(part.n)
	return somme

## Barre empilée de `rectangle` (gabarit) dans `parent`.
static func barre(parent: Node, rectangle: Rect2, parts: Array, taille_chiffre: int = 34) -> Control:
	var dessin := Barre.new()
	dessin.parts = parts
	dessin.name = "RepartitionBarre"
	dessin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dessin)
	D.place(dessin, rectangle)
	var somme := total(parts)
	var x := rectangle.position.x
	for part: Dictionary in parts:
		if somme <= 0 or int(part.n) <= 0: continue
		var largeur := rectangle.size.x * float(part.n) / float(somme)
		if largeur >= 46:
			var etiquette := D.text(parent, x + largeur / 2.0, rectangle.position.y + rectangle.size.y / 2.0 + taille_chiffre * 0.34, str(part.n), taille_chiffre, part.encre, 800, largeur - 8, HORIZONTAL_ALIGNMENT_CENTER)
			etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		x += largeur
	return dessin

## Anneau de centre `centre` (gabarit), diamètre extérieur `diametre`, épaisseur `epaisseur`.
static func anneau(parent: Node, centre: Vector2, diametre: float, epaisseur: float, parts: Array, taille_chiffre: int = 30) -> Control:
	var dessin := Anneau.new()
	dessin.parts = parts
	dessin.epaisseur_relative = epaisseur / diametre
	dessin.name = "RepartitionAnneau"
	dessin.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

class Barre extends Control:
	var parts: Array = []

	func _draw() -> void:
		var somme := 0
		for part: Dictionary in parts: somme += int(part.n)
		var rayon := size.y / 2.0
		var rail := StyleBoxFlat.new()
		rail.bg_color = C.Charte.PANNEAU_3
		rail.set_corner_radius_all(int(rayon))
		draw_style_box(rail, Rect2(Vector2.ZERO, size))
		if somme <= 0: return
		var visibles: Array = parts.filter(func(p: Dictionary): return int(p.n) > 0)
		var ecart := float(maxi(2, C.px(3)))
		var x := 0.0
		for i in visibles.size():
			var part: Dictionary = visibles[i]
			var largeur: float = size.x * float(part.n) / float(somme)
			var zone := Rect2(x, 0, largeur - (ecart if i < visibles.size() - 1 else 0.0), size.y)
			var style := StyleBoxFlat.new()
			style.bg_color = part.couleur
			style.corner_radius_top_left = int(rayon) if i == 0 else 0
			style.corner_radius_bottom_left = int(rayon) if i == 0 else 0
			style.corner_radius_top_right = int(rayon) if i == visibles.size() - 1 else 0
			style.corner_radius_bottom_right = int(rayon) if i == visibles.size() - 1 else 0
			draw_style_box(style, zone)
			_motif(zone, int(part.motif), part.encre, i == 0, i == visibles.size() - 1, rayon)
			x += largeur

	func _motif(zone: Rect2, motif: int, encre: Color, premier: bool, dernier: bool, rayon: float) -> void:
		if motif == MOTIF_AUCUN: return
		var gauche := zone.position.x + (rayon * 0.7 if premier else 0.0)
		var droite := zone.end.x - (rayon * 0.7 if dernier else 0.0)
		if droite - gauche < 4: return
		var couleur_trait := Color(encre, 0.28)
		var pas := float(maxi(8, C.px(14)))
		if motif == MOTIF_DIAGONALE:
			var hauteur := zone.size.y
			var k := gauche - hauteur
			while k < droite:
				# Ligne montante de (k, bas) à (k + hauteur, haut), recoupée à [gauche, droite].
				var a := Vector2(k, zone.end.y)
				var b := Vector2(k + hauteur, zone.position.y)
				if a.x < gauche:
					var t := (gauche - a.x) / hauteur
					a = Vector2(gauche, zone.end.y - t * hauteur)
				if b.x > droite:
					var t := (b.x - droite) / hauteur
					b = Vector2(droite, zone.position.y + t * hauteur)
				if a.x < droite and b.x > gauche and a.x <= b.x: draw_line(a, b, couleur_trait, maxf(2.0, C.px(3)))
				k += pas
		elif motif == MOTIF_POINTS:
			var y := zone.position.y + pas * 0.5
			var ligne := 0
			while y < zone.end.y:
				var px := gauche + pas * 0.5 + (pas * 0.5 if ligne % 2 == 1 else 0.0)
				while px < droite - 2.0:
					draw_circle(Vector2(px, y), maxf(2.0, C.px(3)), couleur_trait)
					px += pas
				y += pas * 0.8
				ligne += 1

class Anneau extends Control:
	var parts: Array = []
	var epaisseur_relative := 0.16

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
