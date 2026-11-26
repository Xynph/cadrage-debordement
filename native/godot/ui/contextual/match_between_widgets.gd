extends "res://ui/contextual/match_between_constantes.gd"
## Widgets dessinés de l'écran intermédiaire du match (domination, météo, pictos, barres, momentum, jauge).

## Domination minute par minute (`direct.domination`, −100 à +100 pour l'équipe qui reçoit) : une barre par
## minute, notre équipe au-dessus de l'axe en barres pleines, l'adversaire dessous en barres vides (la forme
## porte le camp, pas seulement la couleur). Les points marqués et cartons (`direct.reperes`) sont écrits à
## leur minute (« E · 12′ 7-0 »), la mi-temps et la minute en cours sont marquées.
class Domination extends Control:
	const Charte = preload("res://ui/charte.gd")
	const POLICE = preload("res://ui/immersive08/fonts/BarlowCondensed-Bold.ttf")
	## Un repère cliqué (essai, pénalité, carton) : l'indice du fait dans le journal du match.
	signal repere_choisi(i: int)
	var minutes: Array = []
	var mi_temps: Variant = null
	var reperes: Array = []
	var couleurs: Array[Color] = [Charte.CLUB, Charte.IVOIRE_2]
	var sigles: Array = ["", ""]
	## Noms montrés dans la légende de gauche (nous d'abord).
	var noms: Array = ["", ""]
	## Notre côté (0 ou 1) : il est dessiné au-dessus de l'axe ; -1 : l'équipe qui reçoit au-dessus.
	var camp := -1
	## Score après chaque fait (indice du journal → [a, b]) quand le repère ne le porte pas lui-même.
	var scores: Dictionary = {}
	var densite := 0.5
	## [nous, eux] aux couleurs des clubs ; vide : vert clair / doré de la charte.
	var teintes: Array = []
	## D2 : le score cumulé de chaque club en escalier par-dessus les barres.
	var escalier_visible := false
	## Planche A (revue FM27) : légende réduite aux sigles, frise logée sous le terrain.
	var legende_etroite := false
	## Étiquettes des repères dessinées à la dernière image : [Rect2, indice du fait, texte].
	var _etiquettes: Array = []
	var _zone := Rect2()
	var _pas := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _haut() -> int:
		return camp if camp in [0, 1] else 0

	## Texte d'un repère : type (E essai, P pénalité ou drop, C carton), auteur s'il est connu, minute, score vu de nous.
	func texte_repere(repere: Dictionary) -> String:
		var kind := str(repere.get("kind", ""))
		var lettre := "E" if kind == "try" else ("C" if kind == "card" else "P")
		var qui := str(repere.get("nom", "")).strip_edges()
		# Essai de pénalité (loi 8) : ni marqueur ni botteur, la frise le nomme.
		if qui.is_empty() and str(repere.get("loi", "")) == "essai-penalite": qui = "Essai de pénalité"
		var morceaux :=["%s · %s" % [lettre, qui if not qui.is_empty() else str(repere.get("horloge", ""))]]
		if not qui.is_empty(): morceaux.append(str(repere.get("horloge", "")))
		var marque: Variant = repere.get("score") if repere.get("score") is Array else scores.get(int(repere.get("i", -1)))
		if kind != "card" and marque is Array and (marque as Array).size() == 2:
			var haut := _haut()
			morceaux.append("%d-%d" % [int(marque[haut]), int(marque[1 - haut])])
		return " ".join(morceaux)

	## Échelle de la frise : la plus petite graduation (25, 50, 75, 100) qui contient la minute la plus nette.
	## Échelle adaptée aux valeurs réelles : la graduation qui contient neuf minutes sur dix (une minute isolée plus
	## forte dépasse et touche le bord), jamais moins de 10.
	func echelle_frise() -> int:
		var valeurs: Array = minutes.map(func(v: Variant) -> float: return absf(float(v)))
		valeurs.sort()
		var repere: float = float(valeurs[mini(valeurs.size() - 1, int(floor(valeurs.size() * 0.9)))]) if not valeurs.is_empty() else 0.0
		for palier in [10, 20, 30, 40, 50, 60, 80, 100]:
			if repere <= palier: return palier
		return 100

	## Score cumulé vu de nous ([[minute, nous, eux], …]) d'après les repères qui portent un score.
	func escalier() -> Array:
		var points: Array = [[0.0, 0, 0]]
		var haut := _haut()
		var tries := reperes.duplicate()
		tries.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("minute", 0)) < float(b.get("minute", 0)))
		for repere: Dictionary in tries:
			var marque: Variant = repere.get("score") if repere.get("score") is Array else scores.get(int(repere.get("i", -1)))
			if str(repere.get("kind", "")) == "card" or not marque is Array or (marque as Array).size() != 2: continue
			points.append([float(repere.get("minute", 0)), int(marque[haut]), int(marque[1 - haut])])
		return points

	func _draw() -> void:
		_etiquettes.clear()
		var corps := maxi(13, roundi(20.0 * densite))
		var petit := maxi(13, roundi(18.0 * densite))
		var ligne_texte := corps * 1.3
		var gauche := maxf(150.0, 250.0 * densite) if not legende_etroite else maxf(48.0, 70.0 * densite)
		var droite := maxf(28.0, 48.0 * densite)
		# Rangées des pastilles des repères : les nôtres au-dessus des barres, les leurs sous l'échelle des minutes.
		var zone := Rect2(Vector2(gauche, ligne_texte * 1.15), size - Vector2(gauche + droite, ligne_texte * 1.15 + ligne_texte * 2.25))
		if zone.size.x < 40.0 or zone.size.y < 20.0: return
		_zone = zone
		var milieu := zone.position.y + zone.size.y * 0.5
		var haut := _haut()
		var nous := Charte.V
		var eux := Charte.D
		if teintes.size() == 2:
			nous = teintes[0]
			eux = teintes[1]
		# Légende : la couleur et le nom de chaque club, du côté de ses barres (au-dessus : nous).
		var nom_haut := str(noms[0]) if not str(noms[0]).is_empty() and not legende_etroite else str(sigles[haut])
		var nom_bas := str(noms[1]) if not str(noms[1]).is_empty() and not legende_etroite else str(sigles[1 - haut])
		var case := float(corps) * 0.8
		for k in 2:
			# Les deux noms jamais l'un sur l'autre, même sur une frise basse.
			var y := milieu + (-1.0 if k == 0 else 1.0) * maxf(zone.size.y * 0.25, corps * 0.75)
			draw_rect(Rect2(0, y - case * 0.5, case, case), nous if k == 0 else eux)
			var nom := nom_haut if k == 0 else nom_bas
			var taille_nom := corps
			while taille_nom > 12 and POLICE.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_nom).x > gauche - case - 18.0: taille_nom -= 1
			draw_string(POLICE, Vector2(case + 8.0, y + taille_nom * 0.36), nom, HORIZONTAL_ALIGNMENT_LEFT, gauche - case - 14.0, taille_nom, Charte.IVOIRE)
		# Échelle de 80 minutes (40 avant la mi-temps) : la place d'une minute ne change pas pendant le match.
		var fin := 40 if minutes.size() <= 40 else 80
		fin = maxi(fin, minutes.size())
		var pas := zone.size.x / float(fin)
		_pas = pas
		# Graduations : ± l'échelle (tirets) et l'axe ; valeur écrite à droite de la frise.
		var palier := echelle_frise()
		var demi := zone.size.y * 0.5
		for signe in [-1.0, 1.0]:
			var y_palier: float = milieu + signe * demi
			draw_dashed_line(Vector2(zone.position.x, y_palier), Vector2(zone.end.x, y_palier), Color(Charte.FILET, 0.9), 1.0, 6.0)
			draw_dashed_line(Vector2(zone.position.x, milieu + signe * demi * 0.5), Vector2(zone.end.x, milieu + signe * demi * 0.5), Color(Charte.FILET, 0.5), 1.0, 4.0)
			draw_string(POLICE, Vector2(zone.end.x + 6.0, y_palier + petit * 0.36), str(palier), HORIZONTAL_ALIGNMENT_LEFT, droite, petit, Charte.IVOIRE_2)
		draw_string(POLICE, Vector2(zone.end.x + 6.0, milieu + petit * 0.36), "0", HORIZONTAL_ALIGNMENT_LEFT, droite, petit, Charte.IVOIRE_2)
		for repere in range(0, fin + 1, 10):
			var x := zone.position.x + float(repere) * pas
			draw_line(Vector2(x, zone.position.y), Vector2(x, zone.end.y), Color(Charte.FILET, 0.7), 1.0)
			var etiquette := "%d′" % repere
			var largeur_e := POLICE.get_string_size(etiquette, HORIZONTAL_ALIGNMENT_LEFT, -1, petit).x
			draw_string(POLICE, Vector2(clampf(x - largeur_e * 0.5, zone.position.x, size.x - largeur_e), zone.end.y + ligne_texte * 0.95), etiquette, HORIZONTAL_ALIGNMENT_LEFT, -1, petit, Charte.IVOIRE_2)
		# Barres pleines aux couleurs des deux clubs, de part et d'autre de l'axe (au-dessus : nous).
		var largeur := maxf(2.0, pas * 0.78)
		var voile := 0.55 if escalier_visible else 1.0
		for n in minutes.size():
			var v := clampf(float(minutes[n]) / float(palier), -1.0, 1.0)
			if haut == 1: v = -v
			if absf(v) < 0.01: continue
			var h := maxf(1.5, absf(v) * demi)
			var x := zone.position.x + float(n) * pas + (pas - largeur) * 0.5
			if v > 0.0: draw_rect(Rect2(x, milieu - h, largeur, h), Color(nous, voile))
			else: draw_rect(Rect2(x, milieu, largeur, h), Color(eux, voile))
		draw_line(Vector2(zone.position.x, milieu), Vector2(zone.end.x, milieu), Charte.IVOIRE_2, maxf(1.0, densite * 2.0))
		var xc := zone.position.x + minutes.size() * pas
		if mi_temps is int or mi_temps is float:
			var xm := zone.position.x + float(mi_temps) * pas
			draw_line(Vector2(xm, zone.position.y), Vector2(xm, zone.end.y), Charte.IVOIRE_2, maxf(1.0, densite * 2.0))
		# D2 : le score cumulé en escalier par-dessus (points de chaque club, échelle des points sur la hauteur).
		if escalier_visible:
			var marches := escalier()
			var maxi_points := 10
			for m: Array in marches: maxi_points = maxi(maxi_points, maxi(int(m[1]), int(m[2])))
			var fin_x := xc if not minutes.is_empty() else zone.position.x
			for k in 2:
				var teinte: Color = (nous if k == 0 else eux).lightened(0.25)
				var trace := PackedVector2Array()
				var y_prec := zone.end.y
				for m: Array in marches:
					var xm := zone.position.x + clampf(float(m[0]) * pas, 0.0, zone.size.x)
					var y_m := zone.end.y - float(m[1 + k]) / float(maxi_points) * zone.size.y * 0.95
					trace.append(Vector2(xm, y_prec))
					trace.append(Vector2(xm, y_m))
					y_prec = y_m
				trace.append(Vector2(maxf(fin_x, trace[-1].x), y_prec))
				draw_polyline(trace, Color(Charte.FOND, 0.9), maxf(4.0, 7.0 * densite), true)
				draw_polyline(trace, teinte, maxf(2.0, 4.0 * densite), true)
				var total := str(int(marches[-1][1 + k]))
				draw_string(POLICE, Vector2(trace[-1].x + 6.0, y_prec + corps * 0.36), total, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, teinte)
		# Minute courante : trait ivoire épais et sa minute écrite en pastille au-dessus de la frise.
		if not minutes.is_empty():
			draw_line(Vector2(xc, zone.position.y - 4.0), Vector2(xc, zone.end.y + 4.0), Charte.IVOIRE, maxf(2.0, densite * 3.0))
			var minute_txt := "%d′" % minutes.size()
			var mesure_m := POLICE.get_string_size(minute_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, petit)
			var boite := Rect2(Vector2(clampf(xc - mesure_m.x * 0.5 - 8.0, 0.0, size.x - mesure_m.x - 16.0), zone.end.y + 4.0), Vector2(mesure_m.x + 16.0, petit * 1.35))
			draw_style_box(_pilule(Charte.IVOIRE), boite)
			draw_string(POLICE, Vector2(boite.position.x + 8.0, boite.position.y + petit * 1.02), minute_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, petit, Charte.ENCRE)
		# Repères : pastille du club (lettre E, P ou C) à la minute, et le texte (auteur, minute, score) à côté ;
		# une ou deux rangées par camp, sans chevauchement entre étiquettes ni avec la minute courante.
		var taille := petit
		var rond := float(taille) * 0.62
		var occupe := {"haut0": [], "haut1": [], "bas0": [], "bas1": []}
		for repere: Dictionary in reperes:
			var m := float(repere.get("minute", 0))
			var cote := clampi(int(repere.get("equipe", 0)), 0, 1)
			var x := zone.position.x + clampf((m - 0.5) * pas, 0.0, zone.size.x)
			var texte := texte_repere(repere)
			var mesure := POLICE.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x + rond * 2.0 + 6.0
			var dessus := cote == haut
			var debut := clampf(x - rond, 0.0, size.x - mesure - 2.0)
			# Première rangée libre ; sinon, décalée à droite de l'étiquette qui la gêne (jamais de chevauchement).
			var rang := ""
			var premiere_rangee := "%s0" % ("haut" if dessus else "bas")
			var seconde_libre := not (dessus == false and zone.end.y + ligne_texte * 3.05 > size.y)
			for essai in (["0", "1"] if seconde_libre else ["0"]):
				var cle: String = ("haut" if dessus else "bas") + essai
				if not (occupe[cle] as Array).any(func(r: Vector2) -> bool: return debut < r.y + 8.0 and debut + mesure > r.x - 8.0):
					rang = cle
					break
			if rang.is_empty():
				for _tour in 4:
					var gene: Array = (occupe[premiere_rangee] as Array).filter(func(r: Vector2) -> bool: return debut < r.y + 8.0 and debut + mesure > r.x - 8.0)
					if gene.is_empty():
						rang = premiere_rangee
						break
					debut = (gene[-1] as Vector2).y + 12.0
				if debut + mesure > size.x - 2.0: rang = ""
			if rang.is_empty(): continue
			(occupe[rang] as Array).append(Vector2(debut, debut + mesure))
			var base_y: float
			if dessus: base_y = zone.position.y - 4.0 - (ligne_texte if rang.ends_with("1") else 0.0)
			else: base_y = zone.end.y + ligne_texte * (2.05 if rang.ends_with("0") else 3.05)
			if dessus and rang.ends_with("1") and base_y - taille < 0.0: continue
			if not dessus and base_y > size.y: continue
			var centre_rond := Vector2(debut + rond, base_y - taille * 0.36)
			draw_line(Vector2(x, milieu), Vector2(x, zone.position.y if dessus else zone.end.y), Color(Charte.IVOIRE_2, 0.5), 1.0)
			var fond: Color = nous if cote == haut else eux
			var kind := str(repere.get("kind", ""))
			if kind == "card": fond = Charte.D if bool(repere.get("rouge", false)) else Charte.ATTRIBUT_55
			draw_circle(centre_rond, rond, fond)
			draw_arc(centre_rond, rond, 0.0, TAU, 24, Charte.FOND, 1.5, true)
			var lettre := "E" if kind == "try" else ("C" if kind == "card" else "P")
			var lmesure := POLICE.get_string_size(lettre, HORIZONTAL_ALIGNMENT_LEFT, -1, taille - 2).x
			draw_string(POLICE, centre_rond + Vector2(-lmesure * 0.5, (taille - 2) * 0.36), lettre, HORIZONTAL_ALIGNMENT_LEFT, -1, taille - 2, Charte.ENCRE if fond.get_luminance() > 0.55 else Charte.IVOIRE)
			var texte_x := debut + rond * 2.0 + 6.0
			draw_string(POLICE, Vector2(texte_x, base_y), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Charte.IVOIRE)
			# Souligné discret : c'est un lien (clic = le journal à ce fait).
			var largeur_t := POLICE.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
			draw_line(Vector2(texte_x, base_y + 2.0), Vector2(texte_x + largeur_t, base_y + 2.0), Color(Charte.IVOIRE, 0.35), 1.0)
			_etiquettes.append([Rect2(debut, base_y - taille, mesure, taille + 3.0), int(repere.get("i", -1)), texte])

	func _pilule(couleur: Color) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = couleur
		style.set_corner_radius_all(Charte.RAYON_PILULE)
		style.anti_aliasing = true
		return style

	func _etiquette_sous(point: Vector2) -> Array:
		for e: Array in _etiquettes:
			if (e[0] as Rect2).grow(3.0).has_point(point): return e
		return []

	func _gui_input(event: InputEvent) -> void:
		var mouvement := event as InputEventMouseMotion
		if mouvement != null:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _etiquette_sous(mouvement.position).is_empty() else Control.CURSOR_ARROW
			return
		var clic := event as InputEventMouseButton
		if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
			var e := _etiquette_sous(clic.position)
			if not e.is_empty() and int(e[1]) >= 0:
				repere_choisi.emit(int(e[1]))
				accept_event()

	## Infobulle à la minute survolée (« 13′ : Alder Fen XV domine, +42 ») ou du repère (« → journal »).
	func _get_tooltip(at_position: Vector2) -> String:
		var e := _etiquette_sous(at_position)
		if not e.is_empty(): return "%s\nClic : le journal du match à ce fait." % str(e[2])
		if _zone.has_point(at_position) and _pas > 0.0:
			var n := int((at_position.x - _zone.position.x) / _pas)
			if n >= 0 and n < minutes.size():
				var v := float(minutes[n]) * (1.0 if _haut() == 0 else -1.0)
				var qui := str(noms[0]) if v >= 0.0 else str(noms[1])
				return "%d′ : %s domine (%s%d)" % [n + 1, qui, "+" if v >= 0.0 else "−", absi(roundi(v))] if absf(v) >= 1.0 else "%d′ : équilibre" % (n + 1)
		return tooltip_text

## Météo du match posée dans un coin du terrain 2D (à la place de la phrase sous le score, retouche de Léo du
## 21/11/2026) : vent (icône, flèche vers le camp où il souffle, force en barres), pluie (gouttes), chaleur (soleil).
## Rien sans météo particulière ; l'infobulle donne la phrase complète (qui a le vent dans le dos, quelle période).
class PastilleMeteo extends Control:
	const Charte = preload("res://ui/charte.gd")
	var vent := 0
	var pluie := 0
	var chaleur := 0
	## +1 : le vent souffle vers la droite du terrain ; -1 : vers la gauche ; 0 : sans sens connu.
	var sens := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	## Largeur voulue pour une hauteur `h`.
	func largeur(h: float) -> float:
		var w := h * 0.35
		if vent > 0: w += h * (1.0 + (0.95 if sens != 0 else 0.0) + 0.75) + h * 0.25
		if pluie > 0: w += h * 0.45 * pluie + h * 0.25
		if chaleur > 0: w += h * 0.8 + h * 0.25
		return w

	func _draw() -> void:
		var h := size.y
		var fond := StyleBoxFlat.new()
		fond.bg_color = Color(Charte.FOND, 0.88)
		fond.set_corner_radius_all(Charte.RAYON_PILULE)
		fond.anti_aliasing = true
		fond.border_color = Color(1, 1, 1, 0.22)
		fond.set_border_width_all(1)
		draw_style_box(fond, Rect2(Vector2.ZERO, size))
		var x := h * 0.3
		var c := h * 0.5
		var epais := maxf(1.5, h * 0.07)
		var ivoire := Charte.IVOIRE
		if vent > 0:
			# Icône de vent : trois traits dont deux finissent en volute.
			for k in 3:
				var y := c + (k - 1) * h * 0.2
				var long := h * (0.75 if k != 1 else 0.6)
				draw_line(Vector2(x, y), Vector2(x + long, y), ivoire, epais, true)
				if k != 1: draw_arc(Vector2(x + long, y - h * 0.08 * (1 if k == 0 else -1)), h * 0.08, -PI / 2.0 if k == 0 else PI / 2.0, PI / 2.0 if k == 0 else PI * 1.5, 8, ivoire, epais, true)
			x += h * 1.0
			if sens != 0:
				# Flèche : vers le camp où souffle le vent.
				var a := Vector2(x + (0.0 if sens > 0 else h * 0.75), c)
				var b := Vector2(x + (h * 0.75 if sens > 0 else 0.0), c)
				draw_line(a, b - Vector2(sens * h * 0.15, 0), Charte.MORAL, epais * 1.4, true)
				draw_colored_polygon(PackedVector2Array([b, b + Vector2(-sens * h * 0.25, -h * 0.18), b + Vector2(-sens * h * 0.25, h * 0.18)]), Charte.MORAL)
				x += h * 0.95
			# Force : trois barres montantes, pleines selon la force (vent 1 : deux, grand vent : trois).
			var pleines := clampi(vent + 1, 1, 3)
			for k in 3:
				var hb := h * (0.25 + 0.15 * k)
				draw_rect(Rect2(x + k * h * 0.25, c + h * 0.28 - hb, h * 0.16, hb), ivoire if k < pleines else Color(ivoire, 0.25))
			x += h * 1.0
		if pluie > 0:
			for k in pluie:
				var g := Vector2(x + h * 0.2 + k * h * 0.45, c + h * 0.05)
				draw_circle(g, h * 0.14, Charte.MORAL)
				draw_colored_polygon(PackedVector2Array([g + Vector2(-h * 0.13, -h * 0.05), g + Vector2(0, -h * 0.32), g + Vector2(h * 0.13, -h * 0.05)]), Charte.MORAL)
			x += h * 0.45 * pluie + h * 0.25
		if chaleur > 0:
			var soleil := Vector2(x + h * 0.4, c)
			draw_circle(soleil, h * 0.16, Charte.INTENSIF)
			for k in 8:
				var ang := k * TAU / 8.0
				draw_line(soleil + Vector2.from_angle(ang) * h * 0.24, soleil + Vector2.from_angle(ang) * h * 0.34, Charte.INTENSIF, epais, true)

## Pictogramme d'un fait (fil du match) : essai, tir au but, carton, mêlée, touche, jeu au pied, ballon
## perdu. Pastille sombre cerclée à la couleur du camp (nous vert clair, eux doré), signe crème au centre.
class Picto:
	const Charte = preload("res://ui/charte.gd")
	static func dessiner(ci: CanvasItem, c: Vector2, r: float, kind: String, teinte: Color, rouge: bool = false) -> void:
		ci.draw_circle(c, r, Charte.PANNEAU)
		ci.draw_arc(c, r - 0.5, 0.0, TAU, 28, teinte, maxf(1.0, r * 0.12), true)
		var epais := maxf(1.2, r * 0.14)
		var blanc := Charte.IVOIRE
		match kind:
			"try":
				ci.draw_set_transform(c, -0.6, Vector2(1.4, 0.85))
				ci.draw_circle(Vector2.ZERO, r * 0.42, blanc)
				ci.draw_set_transform(Vector2.ZERO, 0.0)
			"goal", "miss", "penalty", "transformation":
				ci.draw_line(c + Vector2(-r * 0.35, -r * 0.5), c + Vector2(-r * 0.35, r * 0.5), blanc, epais, true)
				ci.draw_line(c + Vector2(r * 0.35, -r * 0.5), c + Vector2(r * 0.35, r * 0.5), blanc, epais, true)
				ci.draw_line(c + Vector2(-r * 0.35, r * 0.1), c + Vector2(r * 0.35, r * 0.1), blanc, epais, true)
			"card":
				# Couleur du carton (jaune ou rouge) : c'est l'objet lui-même, et le texte le nomme.
				ci.draw_rect(Rect2(c - Vector2(r * 0.3, r * 0.45), Vector2(r * 0.6, r * 0.9)), Charte.ROUGE if rouge else Charte.ATTRIBUT_55)
			"scrum", "setpiece-win", "setpiece-loss":
				for dx in [-0.3, 0.3]:
					for dy in [-0.22, 0.22]: ci.draw_circle(c + Vector2(dx, dy) * r, r * 0.17, blanc)
			"lineout":
				ci.draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, r * 0.5), blanc, epais, true)
				ci.draw_circle(c + Vector2(0, -r * 0.5), r * 0.16, blanc)
			"turnover", "hand-fault":
				ci.draw_line(c - Vector2(r * 0.35, r * 0.35), c + Vector2(r * 0.35, r * 0.35), blanc, epais, true)
				ci.draw_line(c + Vector2(-r * 0.35, r * 0.35), c + Vector2(r * 0.35, -r * 0.35), blanc, epais, true)
			"kick", "kickoff", "drop22", "goalLine", "touch":
				ci.draw_arc(c + Vector2(0, r * 0.35), r * 0.5, PI * 1.1, PI * 1.9, 12, blanc, epais, true)
				ci.draw_circle(c + Vector2(r * 0.4, -r * 0.05), r * 0.14, blanc)
			"carry":
				ci.draw_line(c + Vector2(-r * 0.4, 0), c + Vector2(r * 0.3, 0), blanc, epais, true)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.5, 0), c + Vector2(r * 0.18, -r * 0.24), c + Vector2(r * 0.18, r * 0.24)]), blanc)
			_:
				ci.draw_circle(c, r * 0.18, blanc)

class Icone extends Control:
	var kind := ""
	var teinte := Color.WHITE
	var rouge := false

	func _draw() -> void:
		Picto.dessiner(self, size * 0.5, minf(size.x, size.y) * 0.5, kind, teinte, rouge)

## Barres face à face d'un chiffre clé (jauge de comparaison de la charte) : notre part pleine à gauche en vert
## clair, l'adversaire en pilule vide au trait doré à droite ; rail `PANNEAU_2` en pilule.
class Barre extends Control:
	const Charte = preload("res://ui/charte.gd")
	## [nous, eux].
	var valeurs: Array = [0, 0]
	var couleurs: Array[Color] = [Charte.V, Charte.D]
	var densite := 0.5

	func _pilule(r: Rect2, couleur: Color, plein: bool) -> void:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(Charte.RAYON_PILULE)
		style.anti_aliasing = true
		style.bg_color = couleur if plein else Color(0, 0, 0, 0)
		if not plein:
			style.border_color = couleur
			style.set_border_width_all(1)
		draw_style_box(style, r)

	func _draw() -> void:
		var a := maxf(0.0, float(valeurs[0]))
		var b := maxf(0.0, float(valeurs[1]))
		var h := maxf(5.0, 12.0 * densite)
		var y := (size.y - h) * 0.5
		_pilule(Rect2(0, y, size.x, h), Charte.PANNEAU_2, true)
		if a + b <= 0.0: return
		var part := a / (a + b)
		var jour := maxf(2.0, 4.0 * densite)
		if part > 0.0: _pilule(Rect2(0, y, maxf(h, size.x * part - jour * 0.5), h), couleurs[0], true)
		if part < 1.0:
			var r := Rect2(size.x * part + jour * 0.5, y, maxf(h, size.x * (1.0 - part) - jour * 0.5), h)
			# Variantes C et D : leur part teintée à demi sous le contour (plus de couleur, toujours « vide » à côté du plein).
			if couleurs[0] != Charte.V: _pilule(r, Color(couleurs[1], 0.45), true)
			_pilule(r, couleurs[1], false)

## Évolution d'un club au classement en direct (`delta` du moteur) : triangle vers le haut s'il gagne des
## places, vers le bas s'il en perd, tiret sinon (la forme porte le sens, la couleur le double).
class Fleche extends Control:
	const Charte = preload("res://ui/charte.gd")
	var delta := 0
	## Encre imposée (flèche posée sur un aplat de couleur) ; transparente : vert, rouge ou gris de la charte.
	var encre := Color(0, 0, 0, 0)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.32
		var propre := encre.a > 0.0
		if delta > 0: draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.7), c + Vector2(-r, r * 0.7)]), encre if propre else Charte.V)
		elif delta < 0: draw_colored_polygon(PackedVector2Array([c + Vector2(0, r), c + Vector2(r, -r * 0.7), c + Vector2(-r, -r * 0.7)]), encre if propre else Charte.D)
		else: draw_line(c - Vector2(r * 0.8, 0), c + Vector2(r * 0.8, 0), encre if propre else Charte.IVOIRE_3, maxf(1.0, r * 0.35))

## Pastille ronde aux couleurs d'un club (neutre si la couleur est inconnue).
class Pastille extends Control:
	const Charte = preload("res://ui/charte.gd")
	var teinte := Charte.IVOIRE_3

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, teinte)
		draw_arc(size * 0.5, r - 0.5, 0.0, TAU, 20, Charte.FILET, 1.0, true)

## Variantes C et D : momentum des cinq dernières minutes (moyenne de `direct.domination`), une barre aux couleurs des
## deux clubs dont la frontière glisse vers le camp qui recule ; sigle et part écrits de chaque côté, chevrons animés
## du côté qui pousse (immobiles si les animations sont réduites).
class Momentum extends Control:
	const Charte = preload("res://ui/charte.gd")
	const POLICE = preload("res://ui/immersive08/fonts/BarlowCondensed-ExtraBold.ttf")
	var part := 0.5
	var cible := 0.5
	var teintes: Array = [Charte.V, Charte.D]
	var sigles: Array = ["", ""]
	var densite := 0.5
	var reduit := false
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func viser(valeur: float) -> void:
		cible = clampf(valeur, 0.1, 0.9)
		if reduit: part = cible
		queue_redraw()

	func _process(delta: float) -> void:
		if reduit or not is_visible_in_tree(): return
		_t += delta
		part = lerpf(part, cible, minf(1.0, delta * 2.5))
		queue_redraw()

	static func encre_sur(fond: Color) -> Color:
		return Charte.ENCRE if fond.get_luminance() > 0.55 else Charte.IVOIRE

	func _pilule(r: Rect2, couleur: Color) -> void:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(Charte.RAYON_PILULE)
		style.anti_aliasing = true
		style.bg_color = couleur
		draw_style_box(style, r)

	func _draw() -> void:
		var h := size.y
		if size.x < h * 4.0: return
		var a: Color = teintes[0]
		var b: Color = teintes[1]
		_pilule(Rect2(Vector2.ZERO, size), b)
		var x := size.x * part
		_pilule(Rect2(0, 0, maxf(h, x), h), a)
		draw_line(Vector2(x, -2.0), Vector2(x, h + 2.0), Charte.IVOIRE, maxf(2.0, 3.0 * densite))
		# Chevrons du côté qui pousse (part > 0,5 : nous), défilant vers l'adversaire.
		var pousse := part - 0.5
		if absf(pousse) > 0.03:
			var sens := 1.0 if pousse > 0.0 else -1.0
			var fond := a if pousse > 0.0 else b
			var pas := h * 0.75
			var decal := fmod(_t * h * 1.2, pas) if not reduit else 0.0
			for k in 3:
				var cx := x - sens * (h * 0.6 + k * pas + (pas - decal))
				var alpha := 0.35 + 0.2 * k
				var c := Color(encre_sur(fond), alpha)
				var dy := h * 0.28
				draw_polyline(PackedVector2Array([Vector2(cx - sens * h * 0.18, h * 0.5 - dy), Vector2(cx + sens * h * 0.18, h * 0.5), Vector2(cx - sens * h * 0.18, h * 0.5 + dy)]), c, maxf(2.0, h * 0.1), true)
		var taille := maxi(12, roundi(h * 0.62))
		var gauche := "%s %d %%" % [str(sigles[0]), roundi(part * 100.0)]
		var droite := "%d %% %s" % [roundi((1.0 - part) * 100.0), str(sigles[1])]
		var base := h * 0.5 + taille * 0.36
		draw_string(POLICE, Vector2(h * 0.5, base), gauche, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, encre_sur(a))
		var largeur := POLICE.get_string_size(droite, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		draw_string(POLICE, Vector2(size.x - h * 0.5 - largeur, base), droite, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, encre_sur(b))

## Variantes C et D : symbole de zone du classement (mêmes formes que l'écran Classements, standings_zones.gd) :
## ★ exempté, ● qualifié, ▲ barrage de montée, ◆ barrage de maintien, ▼ relégation, ○ repêchage.
class MarqueZone extends Control:
	const Charte = preload("res://ui/charte.gd")
	var kind := ""
	var teinte := Charte.IVOIRE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if kind.is_empty(): return
		var s := minf(size.x, size.y)
		var o := (size - Vector2(s, s)) * 0.5
		var points := PackedVector2Array()
		match kind:
			"bye":
				for k in 10:
					var rayon := 0.52 if k % 2 == 0 else 0.25
					var angle := -PI / 2 + k * PI / 5
					points.append(Vector2(0.5 + rayon * cos(angle), 0.53 + rayon * sin(angle)))
			"promotion-playoff": points = PackedVector2Array([Vector2(0.5, 0.06), Vector2(0.96, 0.9), Vector2(0.04, 0.9)])
			"relegation-playoff": points = PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)])
			"relegation": points = PackedVector2Array([Vector2(0.04, 0.1), Vector2(0.96, 0.1), Vector2(0.5, 0.94)])
			_:
				for k in 20: points.append(Vector2(0.5 + 0.44 * cos(k * TAU / 20), 0.5 + 0.44 * sin(k * TAU / 20)))
		for k in points.size(): points[k] = o + points[k] * s
		if kind == "repechage":
			points.append(points[0])
			draw_polyline(points, teinte, maxf(1.5, s * 0.16), true)
		else: draw_colored_polygon(points, teinte)

## Jauge d'énergie de Mon XV (jauge de la charte : rail et remplissage en pilule, repère du seuil de fatigue) :
## vert clair en forme (80 et plus), gris-vert au repos, doré sous le seuil de fatigue ; la valeur et le mot
## (« fatigué », « épuisé ») sont écrits à côté.
class Jauge extends Control:
	const Charte = preload("res://ui/charte.gd")
	var valeur := 100.0
	var densite := 0.5
	## Variantes C et D : couleurs franches de la palette des données (forme verte, entame orange, alerte rouge).
	var vive := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	static func teinte_pour(v: float) -> Color:
		return Charte.D if v < 55.0 else (Charte.V if v >= 80.0 else Charte.IVOIRE_2)

	static func teinte_vive(v: float) -> Color:
		return Charte.PERTE if v < 55.0 else (Charte.CONDITION if v >= 75.0 else Charte.INTENSIF)

	func _draw() -> void:
		var h := maxf(3.0, 6.0 * densite)
		var y := (size.y - h) * 0.5
		var rail := StyleBoxFlat.new()
		rail.set_corner_radius_all(Charte.RAYON_PILULE)
		rail.anti_aliasing = true
		rail.bg_color = Charte.PANNEAU_3
		draw_style_box(rail, Rect2(0, y, size.x, h))
		var part := clampf(valeur / 100.0, 0.0, 1.0)
		if part > 0.0:
			var plein: StyleBoxFlat = rail.duplicate()
			plein.bg_color = teinte_vive(valeur) if vive else teinte_pour(valeur)
			draw_style_box(plein, Rect2(0, y, maxf(h, size.x * part), h))
		# Repère du seuil de fatigue (55 %), comme sur la maquette.
		var xs := size.x * 0.55
		draw_line(Vector2(xs, y - h * 0.6), Vector2(xs, y + h * 1.6), Charte.IVOIRE_3, 1.0)

## Encre lisible sur un aplat de club.
static func encre_sur(fond: Color) -> Color:
	return Charte.ENCRE if fond.get_luminance() > 0.55 else Charte.IVOIRE
