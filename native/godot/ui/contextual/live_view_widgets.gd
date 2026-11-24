extends "res://ui/contextual/live_view_constantes.gd"
## Écran 13 « Match en direct » (live_view.gd), morceau : petits nœuds dessinés (bandeau incliné, marqueur, courbe des parts).

## Bandeau du score (charte finale §7) : un seul panneau `PANNEAU` à 90 %, rayon 18, sans bordure ; un filet
## sépare l'horloge des plaques. La couleur des clubs ne vit que sur l'écusson (puce du sigle) de chaque plaque.
class BandeauAngle extends HBoxContainer:
	const FOND := Color(Charte.PANNEAU, 0.9)
	func _ready() -> void:
		add_theme_constant_override("separation", 0)
		sort_children.connect(queue_redraw)
	func _draw() -> void:
		var fond_bandeau: StyleBoxFlat = Charte.style_panneau(FOND, Charte.RAYON_PANNEAU, 0)
		# Fin trait blanc des grandes tuiles du direct (choix de Léo du 21/11/2026), comme les blocs de l'écran 2D.
		if fond_bandeau != null:
			fond_bandeau = fond_bandeau.duplicate()
			fond_bandeau.border_color = Color(1, 1, 1, 0.22)
			fond_bandeau.set_border_width_all(1)
			fond_bandeau.anti_aliasing = true
		draw_style_box(fond_bandeau, Rect2(Vector2.ZERO, size))
		var horloge: Control = get_node_or_null("MatchClockBlock")
		if horloge != null and horloge.visible:
			draw_rect(Rect2(horloge.position.x + horloge.size.x, size.y * 0.2, 1.0, size.y * 0.6), Charte.FILET)

## Marqueur de l'option choisie (ou liseré du club qui a le ballon) : trait droit de 3 px aux bouts arrondis
## (charte finale §3 : droit partout).
class Marqueur extends Control:
	var couleur := Charte.IVOIRE
	func _draw() -> void:
		var l := maxf(2.0, size.x * 0.5)
		draw_style_box(Charte.style_pilule(couleur, Color.TRANSPARENT, 0, 0), Rect2(0, 0, l, size.y))

## Courbe de part minute par minute : `comptes[m]` = faits [nous, eux] de la minute m ; part lissée sur ±2 minutes.
class CourbeParts extends Control:
	const LISSAGE := 2
	var comptes: Array = []
	var teintes: Array[Color] = [Charte.IVOIRE, Charte.IVOIRE_2]
	var duree := 80.0
	func part(m: int) -> float:
		var a := 0.0
		var b := 0.0
		for j in range(maxi(0, m - LISSAGE), mini(comptes.size() - 1, m + LISSAGE) + 1):
			a += float(comptes[j][0])
			b += float(comptes[j][1])
		return a / (a + b) if a + b > 0.0 else 0.5
	func _x(m: float) -> float: return size.x * m / duree
	func _y(p: float) -> float: return size.y * (1.0 - p)
	func _get_tooltip(at_position: Vector2) -> String:
		var m := roundi(at_position.x / size.x * duree)
		if m < 0 or m >= comptes.size(): return ""
		var p := part(m)
		return "%d′ · %d %% / %d %%" % [m, roundi(p * 100.0), 100 - roundi(p * 100.0)]
	func _draw() -> void:
		var milieu := size.y / 2.0
		# Repères : minutes de 10 en 10, mi-temps, ligne des 50 %.
		for k in range(1, int(duree / 10.0) + 1):
			draw_line(Vector2(_x(k * 10.0), 0), Vector2(_x(k * 10.0), size.y), Color(Charte.PANNEAU_3, 0.8 if k != 4 else 0.0), 1.0)
		draw_line(Vector2(_x(40.0), -14), Vector2(_x(40.0), size.y), Color(Charte.IVOIRE_3, 0.6), 2.0)
		if comptes.size() >= 2:
			var points: Array[Vector2] = []
			for m in comptes.size(): points.append(Vector2(_x(m), _y(part(m))))
			# Zones : au-dessus de la médiane à notre couleur, en dessous à la sienne (coupées au croisement).
			for i in points.size() - 1:
				var p0 := points[i]
				var p1 := points[i + 1]
				var d0 := p0.y - milieu
				var d1 := p1.y - milieu
				if d0 * d1 < 0.0:
					var t := d0 / (d0 - d1)
					var c := Vector2(lerpf(p0.x, p1.x, t), milieu)
					_zone(p0, c, d0)
					_zone(c, p1, d1)
				else: _zone(p0, p1, d0 if absf(d0) > 0.0 else d1)
			draw_polyline(PackedVector2Array(points), Charte.IVOIRE, maxf(2.0, size.y * 0.008), true)
			# Minute actuelle.
			var maintenant := points[-1].x
			draw_line(Vector2(maintenant, -6), Vector2(maintenant, size.y + 6), Charte.IVOIRE, 2.0)
			draw_circle(points[-1], maxf(4.0, size.y * 0.02), Charte.IVOIRE)
		draw_line(Vector2(0, milieu), Vector2(size.x, milieu), Color(Charte.IVOIRE_2, 0.7), 2.0)
	func _zone(a: Vector2, b: Vector2, signe: float) -> void:
		var milieu := size.y / 2.0
		if absf(b.x - a.x) < 0.5 or (absf(a.y - milieu) < 0.5 and absf(b.y - milieu) < 0.5): return
		var couleur: Color = Color(teintes[0], 0.85) if signe < 0.0 else Color(teintes[1], 0.6)
		draw_colored_polygon(PackedVector2Array([a, b, Vector2(b.x, milieu), Vector2(a.x, milieu)]), couleur)
