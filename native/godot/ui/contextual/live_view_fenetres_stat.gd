extends "res://ui/contextual/live_view_fenetres_fait.gd"
## Écran 13 « Match en direct » (live_view.gd), morceau : petite fenêtre d'un chiffre : barres, courbes, frise des parts.

## Petite fenêtre d'un chiffre du match (ligne des chiffres en miroir) : les deux clubs, écusson, nom et valeur en
## grandes tuiles à leurs couleurs, la barre des parts, puis l'évolution par tranche de 10 minutes (`direct.periodes`
## du moteur) ; « Statistiques » ouvre le tiroir à cette ligne.
func ouvrir_fenetre_stat(rang: Dictionary) -> void:
	var live := _live()
	var teams: Array = live.get("teams", [])
	if teams.size() < 2: return
	var direct: Dictionary = live.get("direct", {}) if live.get("direct") is Dictionary else {}
	var camp := int(direct.get("camp", 0))
	var nous := camp if camp in [0, 1] else 0
	var cle := str(rang.get("cle", ""))
	var titre := str(rang.get("label", "")).get_slice(" (", 0)
	var tranches := tranches_stat(direct, cle)
	var L := 1480.0 if not tranches.is_empty() else 960.0
	var h_zone := 370.0 if cle in STATS_PARTS else 340.0
	var fond := _ouvrir_fenetre(FENETRE_STAT, titre.to_upper(), L, 352.0 + h_zone + 78.0 if not tranches.is_empty() else 400.0)
	fond.set_meta("stat", cle)
	var valeurs: Array = rang.get("valeurs", [0, 0]) if rang.get("valeurs") is Array else [0, 0]
	var vide := bool(rang.get("vide", false))
	var inverse := bool(rang.get("inverse", false)) or cle == "penalites"
	var pourcent := str(rang.get("unite", "")) == "%"
	var largeur := (L - 72.0 - 24.0) / 2.0
	var teintes := teintes_stat(teams, nous)
	for k in 2:
		var cote := nous if k == 0 else 1 - nous
		var club: Dictionary = _club_complet(teams[cote]) if teams[cote] is Dictionary else {}
		var x := 36.0 + k * (largeur + 24.0)
		var ecusson := ecusson_club(club, C.px(70))
		ecusson.name = "MatchFenetreStatEcusson%d" % k
		ecusson.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fond.add_child(ecusson)
		D.place(ecusson, Rect2(x, 84, 70, 70))
		var nom := D.text(fond, x + 86, 128, S.G.club_name(club).to_upper(), 24, Charte.IVOIRE, 800, largeur - 86)
		nom.name = "MatchFenetreStatNom%d" % k
		nom.add_theme_font_override("font", Charte.TITRE_FICHE)
		var a := float(valeurs[cote])
		var b := float(valeurs[1 - cote])
		var mieux: bool = not vide and (a < b if inverse else a > b)
		var valeur := "—" if vide else (("%d / %d" % [int(a), int((rang.sur as Array)[cote])]) if rang.get("sur") is Array else ("%d %%" % int(a) if pourcent else str(int(a))))
		Pieces.tuile(fond, Rect2(x, 170, largeur, 130), valeur, "en tête" if mieux else ("à égalité" if a == b and not vide else "derrière"), teintes[k] if mieux else Charte.IVOIRE, "MatchFenetreStatValeur%d" % k, 64, "", "star" if mieux else "", mieux)
	if not vide and float(valeurs[0]) + float(valeurs[1]) > 0.0:
		var part := float(valeurs[nous]) / (float(valeurs[0]) + float(valeurs[1]))
		var rail := D.rect(fond, Rect2(36, 318, L - 72, 14), Charte.PANNEAU_3, Charte.RAYON_PILULE)
		rail.name = "MatchFenetreStatBarre"
		var plein := D.rect(rail, Rect2(0, 0, maxf(14.0, (L - 72) * part), 14), teintes[0], Charte.RAYON_PILULE)
		plein.name = "MatchFenetreStatPart"
	var y_bas := 346.0
	if not tranches.is_empty():
		var zone := Rect2(36, 352, L - 72, h_zone)
		# Choix de Léo (22/11/2026) : taux de réussite en barres par tranche, comptes en courbes cumulées, parts entre
		# les deux clubs : possession en courbe du match, occupation en frise.
		var taux := (pourcent or rang.get("sur") is Array) and not cle in STATS_PARTS
		var nos_valeurs: Array = []
		for t: Dictionary in tranches:
			var v: Variant = (t.valeurs as Dictionary).get(cle)
			var part: Variant = (t.get("parts", {}) as Dictionary).get(cle) if t.get("parts") is Dictionary else null
			if taux and part is Array and (part as Array).size() == 2:
				var ratio := func(c: int) -> Variant: return roundi(100.0 * float(part[c][0]) / float(part[c][1])) if float(part[c][1]) > 0.0 else null
				var r0: Variant = ratio.call(nous)
				var r1: Variant = ratio.call(1 - nous)
				nos_valeurs.append([r0, r1] if r0 != null or r1 != null else null)
			else:
				nos_valeurs.append([v[nous], v[1 - nous]] if v is Array and (v as Array).size() == 2 and v[0] != null and v[1] != null else null)
		nous_stat = nous
		if cle in STATS_PARTS:
			var sigles: Array = []
			for k in 2:
				var c: Dictionary = _club_complet(teams[nous if k == 0 else 1 - nous]) if teams[nous if k == 0 else 1 - nous] is Dictionary else {}
				sigles.append(str(c.get("abbr", "")))
			var globale: Array = [null, null] if vide else [float(valeurs[nous]), float(valeurs[1 - nous])]
			var minutes: Variant = ((direct.get("periodes", {}) as Dictionary).get("minutes", {}) as Dictionary).get(cle) if direct.get("periodes") is Dictionary and direct.periodes.get("minutes") is Dictionary else null
			# Choix de Léo (22/11/2026) : possession en courbe minute par minute, occupation en frise des tranches.
			if cle == "possession" and minutes is Array: _courbe_parts(fond, zone, minutes, teintes, sigles, globale, nous)
			else: _frise_parts(fond, zone, tranches, nos_valeurs, teintes, sigles, globale)
		elif taux: _barres_periodes(fond, zone, tranches, nos_valeurs, teintes, true)
		else: _courbe_periodes(fond, zone, tranches, nos_valeurs, teintes, false)
		y_bas = 352.0 + h_zone + 16.0
	Pieces.pastille(fond, 36, y_bas, "Statistiques", "rating", "MatchFenetreStatTiroir", "", Charte.IVOIRE, Charte.PANNEAU_3, func():
		fermer_fenetre()
		if regie != null and regie.has_method("ouvrir_stats_a"): regie.ouvrir_stats_a(str(rang.get("stats", rang.get("label", "")))))

## Tranches de 10 minutes du direct (`direct.periodes`, moteur) qui portent le chiffre `cle` ; vide sans donnée
## (début de match, chiffre sans évolution) : la fenêtre reste sans évolution.
static func tranches_stat(direct: Dictionary, cle: String) -> Array:
	var periodes: Variant = direct.get("periodes")
	if not periodes is Dictionary or not (periodes as Dictionary).get("tranches") is Array: return []
	return (periodes.tranches as Array).filter(func(t: Variant) -> bool: return t is Dictionary and t.get("valeurs") is Dictionary and (t.valeurs as Dictionary).has(cle))

## Couleurs des deux clubs dans la fenêtre d'un chiffre (nous, eux) ; si elles se confondent, l'adversaire passe en ivoire.
func teintes_stat(teams: Array, nous: int) -> Array[Color]:
	var a := Charte.club_trait(_couleur_club(_club_complet(teams[nous]) if teams[nous] is Dictionary else {}, 0))
	var b := Charte.club_trait(_couleur_club(_club_complet(teams[1 - nous]) if teams[1 - nous] is Dictionary else {}, 1))
	var ecart := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
	return [a, b if ecart > 0.25 else Charte.IVOIRE_2]

## Taux de réussite : barres en miroir par tranche de 10 minutes (nous au-dessus de l'axe, eux en dessous), séparation de la
## mi-temps ; tranche en cours atténuée, tranches à venir en cases vides.
func _barres_periodes(fond: Control, zone: Rect2, tranches: Array, valeurs: Array, teintes: Array[Color], pourcent: bool) -> void:
	var cadre := D.rect(fond, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "MatchFenetreStatPeriodes"
	var n := 8
	var gauche := 20.0
	var pas := (zone.size.x - 2.0 * gauche) / n
	var axe := zone.size.y / 2.0 + 8.0
	var haut := axe - 84.0
	var maxi := 1.0
	for v: Variant in valeurs:
		if v is Array:
			for c: Variant in v:
				if c != null: maxi = maxf(maxi, float(c))
	if pourcent: maxi = 100.0
	D.rect(cadre, Rect2(gauche, axe - 1, zone.size.x - 2.0 * gauche, 2), Charte.PANNEAU_3)
	D.rect(cadre, Rect2(gauche + 4 * pas - 1, 40, 2, zone.size.y - 52), Color(Charte.IVOIRE_3, .5)).name = "MatchFenetreStatMiTemps"
	D.text(cadre, gauche + 2 * pas, 30, "1re MI-TEMPS", 15, Charte.IVOIRE_3, 700, 2 * pas, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatMT1"
	D.text(cadre, gauche + 6 * pas, 30, "2e MI-TEMPS", 15, Charte.IVOIRE_3, 700, 2 * pas, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatMT2"
	for k in n:
		var x := gauche + k * pas + pas * 0.2
		var l := pas * 0.6
		# Minute de fin de la tranche, sur l'axe entre les deux barres.
		var etiquette := D.text(cadre, gauche + k * pas + pas / 2.0, axe + 6, "%d′" % ((k + 1) * 10), 15, Charte.IVOIRE_3, 700, pas, HORIZONTAL_ALIGNMENT_CENTER)
		etiquette.name = "MatchFenetreStatMinute%d" % k
		if k >= valeurs.size():
			D.rect(cadre, Rect2(x, axe - 40, l, 28), Color.TRANSPARENT, Charte.RAYON_PETIT, Charte.PANNEAU_3).name = "MatchFenetreStatAVenir%d" % k
			D.rect(cadre, Rect2(x, axe + 12, l, 28), Color.TRANSPARENT, Charte.RAYON_PETIT, Charte.PANNEAU_3)
			continue
		var v: Variant = valeurs[k]
		var en_cours := bool((tranches[k] as Dictionary).get("enCours", false))
		for s in 2:
			# Taux sans tentative dans la tranche (un seul club a lancé) : « — » de ce côté seulement.
			var connu: bool = v is Array and v[s] != null
			var nombre := float(v[s]) if connu else 0.0
			var h := maxf(4.0, haut * nombre / maxi) if connu else 0.0
			if connu:
				var barre := D.rect(cadre, Rect2(x, axe - 12 - h if s == 0 else axe + 12, l, h), Color(teintes[s], .5 if en_cours else 1.0), Charte.RAYON_PETIT)
				barre.name = "MatchFenetreStatBarre%d_%d" % [k, s]
			var texte := ("%d%%" % int(nombre) if pourcent else str(int(nombre))) if connu else "—"
			var y := (axe - 12 - h - 8) if s == 0 else (axe + 12 + h + 24)
			D.text(cadre, x + l / 2.0, y, texte, 20, Charte.IVOIRE if connu else Charte.IVOIRE_3, 700, l + 30, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatChiffre%d_%d" % [k, s]

## Comptes : courbes cumulées des deux clubs sur 80 minutes (compte, ou part refaite depuis le coup d'envoi), un point
## à chaque fin de tranche (la tranche en cours à la minute montrée), le chiffre au bout de chaque courbe.
func _courbe_periodes(fond: Control, zone: Rect2, tranches: Array, valeurs: Array, teintes: Array[Color], pourcent: bool) -> void:
	var cadre := D.rect(fond, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "MatchFenetreStatPeriodes"
	var gauche := 70.0
	var droite := 100.0
	var haut := 56.0
	var bas := zone.size.y - 46.0
	var w := zone.size.x - gauche - droite
	var series: Array = [[], []]
	var cumul := [0.0, 0.0]
	var num := [0.0, 0.0]
	var den := [0.0, 0.0]
	var cle := str(fond.get_meta("stat", ""))
	for k in valeurs.size():
		var v: Variant = valeurs[k]
		var t: Dictionary = tranches[k]
		var fin := float(t.get("fin", t.get("a", (k + 1) * 10)))
		var part: Variant = (t.get("parts", {}) as Dictionary).get(cle) if t.get("parts") is Dictionary else null
		for s in 2:
			var cote := s if nous_stat == 0 else 1 - s
			if pourcent and part is Array and (part as Array).size() == 2:
				num[s] += float(part[cote][0])
				den[s] += float(part[cote][1])
				if den[s] <= 0.0: continue
				cumul[s] = 100.0 * num[s] / den[s]
			elif pourcent:
				if not v is Array: continue
				cumul[s] = float(v[s])
			else:
				if not v is Array: continue
				cumul[s] += float(v[s])
			series[s].append(Vector2(fin, cumul[s]))
	# Échelle : de 0 au plus haut pour un compte ; pour une part, la plage utile arrondie à la dizaine.
	var bas_valeur := 0.0
	var maxi := maxf(1.0, maxf(cumul[0], cumul[1]))
	if pourcent:
		var mini := 100.0
		maxi = 0.0
		for serie: Array in series:
			for m: Vector2 in serie:
				mini = minf(mini, m.y)
				maxi = maxf(maxi, m.y)
		bas_valeur = clampf(floorf((mini - 5.0) / 10.0) * 10.0, 0.0, 90.0)
		maxi = clampf(ceilf((maxi + 5.0) / 10.0) * 10.0, bas_valeur + 10.0, 100.0)
	var point := func(m: Vector2) -> Vector2: return Vector2(gauche + w * clampf(m.x, 0.0, 80.0) / 80.0, bas - (bas - haut) * (m.y - bas_valeur) / maxf(1.0, maxi - bas_valeur))
	if pourcent:
		D.text(cadre, gauche - 8, haut + 6, "%d%%" % int(maxi), 14, Charte.IVOIRE_3, 600, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		D.text(cadre, gauche - 8, bas + 6, "%d%%" % int(bas_valeur), 14, Charte.IVOIRE_3, 600, 60, HORIZONTAL_ALIGNMENT_RIGHT)
	D.rect(cadre, Rect2(gauche, bas, w, 2), Charte.PANNEAU_3)
	if pourcent and bas_valeur < 50.0 and maxi > 50.0: D.rect(cadre, Rect2(gauche, (point.call(Vector2(0, 50)) as Vector2).y, w, 1), Color(Charte.IVOIRE_3, .35))
	for k in 9:
		var x := gauche + w * k / 8.0
		if k == 4: D.rect(cadre, Rect2(x - 1, 40, 2, bas - 40), Color(Charte.IVOIRE_3, .5)).name = "MatchFenetreStatMiTemps"
		elif k > 0: D.rect(cadre, Rect2(x, haut, 1, bas - haut), Color(Charte.PANNEAU_3, .8))
		if k > 0: D.text(cadre, x, bas + 30, "%d′" % (k * 10), 15, Charte.IVOIRE_3, 700, 80, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(cadre, gauche + w * 0.25, 30, "1re MI-TEMPS", 15, Charte.IVOIRE_3, 700, 220, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatMT1"
	D.text(cadre, gauche + w * 0.75, 30, "2e MI-TEMPS", 15, Charte.IVOIRE_3, 700, 220, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatMT2"
	var fins: Array = []
	for s in 2:
		var pts: Array = series[s]
		if pts.is_empty(): continue
		var ligne := Line2D.new()
		ligne.name = "MatchFenetreStatCourbe%d" % s
		ligne.width = 5.0 * C.density
		ligne.default_color = teintes[s]
		ligne.antialiased = true
		ligne.joint_mode = Line2D.LINE_JOINT_ROUND
		ligne.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ligne.end_cap_mode = Line2D.LINE_CAP_ROUND
		var depart := Vector2(0.0, (pts[0] as Vector2).y if pourcent else 0.0)
		for m: Vector2 in ([] if pourcent else [depart]) + pts: ligne.add_point((point.call(m) as Vector2) * C.density)
		cadre.add_child(ligne)
		for m: Vector2 in pts:
			var p: Vector2 = point.call(m)
			D.rect(cadre, Rect2(p.x - 7, p.y - 7, 14, 14), teintes[s], 7)
		fins.append([s, point.call(pts[-1]), (pts[-1] as Vector2).y])
	# Chiffre au bout de chaque courbe, écartés s'ils se chevauchent.
	if fins.size() == 2 and absf((fins[0][1] as Vector2).y - (fins[1][1] as Vector2).y) < 28.0:
		var dessus := 0 if (fins[0][1] as Vector2).y <= (fins[1][1] as Vector2).y else 1
		fins[dessus][1] = (fins[dessus][1] as Vector2) + Vector2(0, -14)
		fins[1 - dessus][1] = (fins[1 - dessus][1] as Vector2) + Vector2(0, 14)
	for f: Array in fins:
		var p: Vector2 = f[1]
		var valeur := float(f[2])
		D.text(cadre, p.x + 14, p.y + 9, ("%d%%" % roundi(valeur)) if pourcent else str(roundi(valeur)), 24, teintes[int(f[0])], 800, 84).name = "MatchFenetreStatFin%d" % int(f[0])

## Parts : pastilles de légende (couleur et sigle des deux clubs), notre club toujours en premier.
func _legende_parts(cadre: Control, x: float, y: float, teintes: Array[Color], sigles: Array) -> void:
	for s in 2:
		var case := D.rect(cadre, Rect2(x, y - 16, 22, 22), teintes[s], Charte.RAYON_PETIT)
		case.name = "MatchFenetreStatLegende%d" % s
		D.text(cadre, x + 32, y + 2, str(sigles[s]), 20, Charte.IVOIRE, 800, 120)
		x += 150.0

## Frise du temps (occupation) : une frise 0'→80' de 8 cases jointives libellées « 0–10' »… ; chaque case partagée
## entre les deux clubs (nous en haut, eux en bas, à leur couleur), notre part seule en chiffre ; mi-temps marquée.
func _frise_parts(fond: Control, zone: Rect2, tranches: Array, valeurs: Array, teintes: Array[Color], sigles: Array, globale: Array) -> void:
	var cadre := D.rect(fond, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "MatchFenetreStatPeriodes"
	var gauche := 30.0
	var largeur := zone.size.x - 2.0 * gauche
	var coupure := 18.0
	var case := (largeur - coupure) / 8.0
	var haut := 116.0
	var hauteur := 190.0
	_legende_parts(cadre, gauche, 48, teintes, sigles)
	var total := ("%s  %d %%" % [str(sigles[0]), roundi(float(globale[0]))]) if globale.size() == 2 and globale[0] != null else ""
	D.text(cadre, zone.size.x - gauche, 54, total, 30, teintes[0], 800, 400, HORIZONTAL_ALIGNMENT_RIGHT).name = "MatchFenetreStatCentre"
	D.text(cadre, gauche + 2 * case, haut - 16, "1re MI-TEMPS", 15, Charte.IVOIRE_3, 700, 4 * case, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(cadre, gauche + coupure + 6 * case, haut - 16, "2e MI-TEMPS", 15, Charte.IVOIRE_3, 700, 4 * case, HORIZONTAL_ALIGNMENT_CENTER)
	for k in 8:
		var x := gauche + k * case + (coupure if k >= 4 else 0.0)
		D.text(cadre, x + case / 2.0, haut + hauteur + 30, "%d–%d′" % [k * 10, (k + 1) * 10], 18, Charte.IVOIRE_2, 700, case, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatTranche%d" % k
		var v: Variant = valeurs[k] if k < valeurs.size() else null
		if not v is Array:
			var vide := D.rect(cadre, Rect2(x, haut, case, hauteur), Color(Charte.PANNEAU_3, 0.35), 0)
			vide.name = "MatchFenetreStatAVenir%d" % k
			if k < valeurs.size(): D.text(cadre, x + case / 2.0, haut + hauteur / 2.0 + 10, "—", 26, Charte.IVOIRE_3, 700, case, HORIZONTAL_ALIGNMENT_CENTER)
			continue
		var en_cours := bool((tranches[k] as Dictionary).get("enCours", false))
		var h := hauteur * clampf(float(v[0]) / 100.0, 0.0, 1.0)
		var nous := D.rect(cadre, Rect2(x, haut, case, h), Color(teintes[0], .55 if en_cours else 1.0), 0)
		nous.name = "MatchFenetreStatPart%d_0" % k
		var eux := D.rect(cadre, Rect2(x, haut + h, case, hauteur - h), Color(teintes[1], .35 if en_cours else .55), 0)
		eux.name = "MatchFenetreStatPart%d_1" % k
		var encre: Color = Charte.ENCRE if teintes[0].get_luminance() > 0.55 and not en_cours else Charte.IVOIRE
		var y_chiffre := haut + h / 2.0 + 14.0 if h >= 50.0 else haut + h + 34.0
		D.text(cadre, x + case / 2.0, y_chiffre, "%d %%" % roundi(float(v[0])), 30, encre if h >= 50.0 else Charte.IVOIRE, 800, case, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatChiffre%d" % k
	# Séparations fines entre les cases (frise jointive) et ligne des 50 %.
	for k in range(1, 8):
		if k == 4: continue
		var x := gauche + k * case + (coupure if k > 4 else 0.0)
		D.rect(cadre, Rect2(x - 1, haut, 2, hauteur), Color(Charte.PANNEAU_2, 0.9))
	D.rect(cadre, Rect2(gauche, haut + hauteur / 2.0, largeur, 1), Color(Charte.NOIR_PANNEAU, 0.45)).name = "MatchFenetreStat50"

## Courbe du match (possession, idée de Léo, 22/11/2026) : part minute par minute, lissée sur 5 minutes, de part et
## d'autre de la ligne des 50 % : au-dessus quand nous avons le ballon (zone à notre couleur), en dessous pour l'adversaire.
## Axe 0′→80′, mi-temps marquée, minute actuelle repérée, futur vide ; survol : « 34′ · 62 % / 38 % ».
func _courbe_parts(fond: Control, zone: Rect2, minutes: Array, teintes: Array[Color], sigles: Array, globale: Array, nous: int) -> void:
	var cadre := D.rect(fond, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "MatchFenetreStatPeriodes"
	_legende_parts(cadre, 30, 48, teintes, sigles)
	var total := ("%s  %d %%" % [str(sigles[0]), roundi(float(globale[0]))]) if globale.size() == 2 and globale[0] != null else ""
	D.text(cadre, zone.size.x - 30, 54, total, 30, teintes[0], 800, 400, HORIZONTAL_ALIGNMENT_RIGHT).name = "MatchFenetreStatCentre"
	var gauche := 90.0
	var droite := 30.0
	var haut := 84.0
	var bas := zone.size.y - 50.0
	var courbe := CourbeParts.new()
	courbe.name = "MatchFenetreStatCourbe"
	courbe.mouse_filter = Control.MOUSE_FILTER_PASS
	courbe.tooltip_text = " "
	courbe.teintes = teintes
	for m: Variant in minutes:
		courbe.comptes.append([float(m[nous]), float(m[1 - nous])] if m is Array and (m as Array).size() == 2 else [0.0, 0.0])
	courbe.duree = maxf(80.0, float(minutes.size() - 1))
	cadre.add_child(courbe)
	D.place(courbe, Rect2(gauche, haut, zone.size.x - gauche - droite, bas - haut))
	var w := zone.size.x - gauche - droite
	for k in 9:
		var x := gauche + w * k * 10.0 / courbe.duree
		D.text(cadre, x, bas + 30, "%d′" % (k * 10), 16 if k != 4 else 18, Charte.IVOIRE_3 if k != 4 else Charte.IVOIRE, 700, 70, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(cadre, gauche + w * 20.0 / courbe.duree, haut - 10, "1re MI-TEMPS", 15, Charte.IVOIRE_3, 700, 300, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(cadre, gauche + w * 60.0 / courbe.duree, haut - 10, "2e MI-TEMPS", 15, Charte.IVOIRE_3, 700, 300, HORIZONTAL_ALIGNMENT_CENTER)
	# Minute actuelle repérée au-dessus de la courbe.
	if minutes.size() > 0:
		D.text(cadre, gauche + w * float(minutes.size() - 1) / courbe.duree, haut - 34, "%d′" % (minutes.size() - 1), 18, Charte.IVOIRE, 800, 70, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatMaintenant"
	# Qui est où : notre sigle au-dessus de la ligne des 50 %, l'adversaire en dessous.
	var milieu := haut + (bas - haut) / 2.0
	D.text(cadre, 24, milieu - 24, "▲ " + str(sigles[0]), 18, teintes[0], 800, 80).name = "MatchFenetreStatNous"
	D.text(cadre, 24, milieu + 40, "▼ " + str(sigles[1]), 18, teintes[1], 800, 80).name = "MatchFenetreStatEux"
