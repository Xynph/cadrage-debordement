extends RefCounted
## Finances : tracés des courbes (mouvements du journal, solde sur 12 mois) et pictogramme d'état, dessinés à la main.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")

## Courbe des mouvements : série « nous » en trait du club ; sorties hachurées, entrées pleines (forme, pas couleur).
class LedgerPlot extends Control:
	var operations: Array = []
	var minimum := 0.0
	var maximum := 1.0
	var cumulative := PackedFloat64Array()
	var trait_club := Charte.CLUB_TRAIT
	var pas := 0.2

	func set_operations(visible_operations: Array) -> void:
		operations = visible_operations.duplicate()
		operations.reverse()
		var net := 0.0
		for entry: Dictionary in operations:
			var amount := float(entry.get("amount", 0))
			net += amount
			cumulative.append(net)
			minimum = minf(minimum, net)
			maximum = maxf(maximum, maxf(absf(amount),net))
		# Graduations rondes (1, 2 ou 5 × 10^n) avec le zéro sur une graduation : « 0 € » et non « −880 € ».
		var brut := (maximum - minimum) / 5.0
		var ordre := pow(10.0, floorf(log(brut) / log(10.0)))
		var rapport := brut / ordre
		pas = (1.0 if rapport <= 1.0 else 2.0 if rapport <= 2.0 else 5.0 if rapport <= 5.0 else 10.0) * ordre
		maximum = ceilf(maximum / pas - 1e-9) * pas
		minimum = floorf(minimum / pas + 1e-9) * pas
		queue_redraw()

	## Valeurs des graduations, de la plus haute à la plus basse.
	func graduations() -> Array:
		var valeurs := []
		var nombre := roundi((maximum - minimum) / pas)
		for i in nombre + 1: valeurs.append(maximum - i * pas)
		return valeurs

	func _height(value: float) -> float:
		return size.y * (maximum - value) / (maximum - minimum)

	func _draw() -> void:
		for valeur in graduations():
			var y := _height(valeur)
			draw_line(Vector2(0,y), Vector2(size.x,y), Color(Charte.FILET,.7))
		draw_line(Vector2.ZERO, Vector2(0,size.y), Charte.IVOIRE_3)
		if operations.is_empty(): return
		var zero := _height(0)
		draw_dashed_line(Vector2(0,zero), Vector2(size.x,zero), Charte.IVOIRE_2, maxf(1,C.px(2)), maxf(4,C.px(8)))
		var stride := size.x / maxi(12,operations.size())
		var points := PackedVector2Array()
		for i in operations.size():
			var value := float(operations[i].get("amount",0))
			var x := size.x - stride * (operations.size()-i-.5)
			var top := _height(absf(value))
			if value != 0:
				var bar := Rect2(x-stride*.19,top,stride*.38,zero-top)
				if value > 0:
					draw_rect(bar, Charte.IVOIRE_2)
				else:
					draw_rect(bar, Color(Charte.IVOIRE_2,.18))
					draw_rect(bar, Charte.IVOIRE_2, false, maxf(1,C.px(2)))
					var step := maxf(5.0,C.px(7))
					var offset := step
					while offset < bar.size.x + bar.size.y:
						var a := Vector2(bar.position.x + minf(offset,bar.size.x), bar.position.y + maxf(0.0,offset - bar.size.x))
						var b := Vector2(bar.position.x + maxf(0.0,offset - bar.size.y), bar.position.y + minf(offset,bar.size.y))
						draw_line(a, b, Charte.IVOIRE_2, 1.0)
						offset += step
			points.append(Vector2(x,_height(cumulative[i])))
		if points.size() > 1: draw_polyline(points,trait_club,maxf(2,C.px(3)),true)
		for point in points:
			draw_circle(point, C.px(7), Charte.FOND)
			draw_circle(point, C.px(5), trait_club)

## Solde sur 12 mois : trésorerie relevée chaque semaine (finance.cashHistory), les semaines disponibles étirées sur
## toute la largeur (52 au plus), la plus récente à droite.
## Haut : courbe du solde ; bas : barre de variation de la semaine (gain vert vers le haut, perte rouge vers le bas).
class SoldePlot extends Control:
	var semaines: Array = []
	var minimum := 0.0
	var maximum := 1.0
	var pas := 1.0
	var variation_max := 1.0
	const CASES := 52
	## Plafond de largeur d'une barre (unités du gabarit) : pas de barre énorme avec deux ou trois semaines.
	const BARRE_MAX := 34.0
	const PART_COURBE := .66

	func set_semaines(liste: Array) -> void:
		semaines = liste.duplicate()
		var bas := INF
		var haut := -INF
		variation_max = 1.0
		for semaine: Dictionary in semaines:
			bas = minf(bas, float(semaine.cash))
			haut = maxf(haut, float(semaine.cash))
			if semaine.get("variation") != null: variation_max = maxf(variation_max, absf(float(semaine.variation)))
		if semaines.is_empty():
			bas = 0.0
			haut = 1.0
		if bas < 0.0: haut = maxf(haut, 0.0)
		if haut - bas < 1.0:
			bas -= maxf(1000.0, absf(bas) * .1)
			haut += maxf(1000.0, absf(haut) * .1)
		var brut := (haut - bas) / 4.0
		var ordre := pow(10.0, floorf(log(brut) / log(10.0)))
		var rapport := brut / ordre
		pas = (1.0 if rapport <= 1.0 else 2.0 if rapport <= 2.0 else 5.0 if rapport <= 5.0 else 10.0) * ordre
		maximum = ceilf(haut / pas - 1e-9) * pas
		minimum = floorf(bas / pas + 1e-9) * pas
		if is_equal_approx(maximum, minimum): maximum += pas
		queue_redraw()

	func graduations() -> Array:
		var valeurs := []
		for i in roundi((maximum - minimum) / pas) + 1: valeurs.append(maximum - i * pas)
		return valeurs

	func largeur_case() -> float:
		return size.x / maxi(1, semaines.size())

	## Abscisse de la semaine i (0 = la plus ancienne).
	func x_de(i: int) -> float:
		return size.x - largeur_case() * (semaines.size() - i - .5)

	func y_de(valeur: float) -> float:
		return size.y * PART_COURBE * (maximum - valeur) / (maximum - minimum)

	func milieu_barres() -> float:
		return size.y * (PART_COURBE + (1.0 - PART_COURBE) * .55)

	func _draw() -> void:
		for valeur in graduations():
			draw_line(Vector2(0, y_de(valeur)), Vector2(size.x, y_de(valeur)), Color(Charte.FILET, .7))
		draw_line(Vector2.ZERO, Vector2(0, size.y), Charte.IVOIRE_3)
		if minimum < 0.0 and maximum > 0.0:
			draw_dashed_line(Vector2(0, y_de(0)), Vector2(size.x, y_de(0)), Charte.IVOIRE_2, maxf(1, C.px(2)), maxf(4, C.px(8)))
		var milieu := milieu_barres()
		var demi := size.y * (1.0 - PART_COURBE) * .42
		draw_line(Vector2(0, milieu), Vector2(size.x, milieu), Color(Charte.IVOIRE_3, .8), 1.0)
		if semaines.is_empty(): return
		var largeur := largeur_case()
		var points := PackedVector2Array()
		for i in semaines.size():
			var x := x_de(i)
			var variation: Variant = semaines[i].get("variation")
			if variation != null and absf(float(variation)) >= 1.0:
				var h := maxf(2.0, demi * absf(float(variation)) / variation_max)
				var epaisseur := minf(largeur * .6, C.px(BARRE_MAX))
				var barre := Rect2(x - epaisseur * .5, milieu - h if float(variation) > 0.0 else milieu, epaisseur, h)
				draw_rect(barre, Pieces.VERT if float(variation) > 0.0 else Pieces.ROUGE)
			points.append(Vector2(x, y_de(float(semaines[i].cash))))
		var courant: Dictionary = semaines.back()
		if courant.get("courant", false):
			var xc := points[points.size() - 1].x
			draw_dashed_line(Vector2(xc, 0), Vector2(xc, size.y), Charte.IVOIRE_2, 1.0, maxf(4, C.px(6)))
		if points.size() > 1: draw_polyline(points, Charte.IVOIRE, maxf(2, C.px(3)), true)
		for k in points.size():
			var negatif := float(semaines[k].cash) < 0.0
			var rayon := C.px(9) if k == points.size() - 1 else C.px(5)
			draw_circle(points[k], rayon + C.px(2), Charte.PANNEAU)
			draw_circle(points[k], rayon, Pieces.ROUGE if negatif else Charte.IVOIRE)

## Pictogramme dessiné d'un état (coche, point d'exclamation, croix) : toujours accompagné d'un mot.
class Symbole extends Control:
	var forme := "coche"
	var couleur := Charte.IVOIRE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var epaisseur := maxf(2.0, w * .09)
		draw_rect(Rect2(1, 1, w - 2, h - 2), couleur, false, maxf(1.5, w * .07))
		match forme:
			"coche": draw_polyline(PackedVector2Array([Vector2(w * .24, h * .54), Vector2(w * .43, h * .72), Vector2(w * .78, h * .28)]), couleur, epaisseur)
			"croix":
				draw_line(Vector2(w * .27, h * .27), Vector2(w * .73, h * .73), couleur, epaisseur)
				draw_line(Vector2(w * .73, h * .27), Vector2(w * .27, h * .73), couleur, epaisseur)
			_:
				draw_line(Vector2(w * .5, h * .2), Vector2(w * .5, h * .58), couleur, epaisseur)
				draw_rect(Rect2(w * .5 - epaisseur * .6, h * .7, epaisseur * 1.2, epaisseur * 1.2), couleur)
