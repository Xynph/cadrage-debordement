extends RefCounted
## Tactique › Entraînement : deux variantes « moins de tuiles, façon Effectif » (Léo, 22/11/2026), lues dans
## CD_VARIANTE_VISUELLE (A ou B). Le terrain « Forme du XV » à gauche ne change pas ; seule la colonne de droite change.
##  - A : rangée compacte de tuiles-chiffres (Le groupe), bande compacte des 7 jours, liste à lignes « À surveiller ».
##  - B : bandeau de tuiles-chiffres colorées, puis la semaine en agenda vertical à gauche de la liste à lignes.
## Mêmes données et mêmes destinations de clic que l'écran actuel ; ligne joueur : survol = carte joueur (nom, « i »),
## clic = fiche joueur.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Vertical = preload("res://ui/immersive08/tactics_vertical.gd")
const Listes = preload("res://ui/immersive08/listes_joueurs.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")
const Watch = preload("res://ui/management_state.gd")

const HAUT := 196.0
const BAS := 1298.0
const FIN := 2248.0
const TRI := "tactique_entrainement_tri"
const FILTRE := "tactique_entrainement_filtre"

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

## `tuiles` : [valeur, légende, couleur, icône, action] (mêmes que l'écran actuel).
static func construire(app: Control, page: Control, v: String, tuiles: Array, surveilles: Array) -> void:
	if v == "A": _variante_a(app, page, tuiles, surveilles)
	else: _variante_b(app, page, tuiles, surveilles)

# --- A : version Effectif ----------------------------------------------------------------------------------------

static func _variante_a(app: Control, page: Control, tuiles: Array, surveilles: Array) -> void:
	var gauche := Vertical.DROITE
	var largeur := FIN - gauche
	var tw := (largeur - 3 * 12) / 4.0
	for i in tuiles.size():
		_tuile_compacte(page, Rect2(gauche + i * (tw + 12), HAUT, tw, 70), tuiles[i], "TacticsTabTuile%d" % i)
	var y := HAUT + 92
	_titre(page, gauche, y, "La semaine", Charte.REPOS)
	_bande_semaine(app, page, Rect2(gauche, y + 46, largeur, 78))
	y += 150
	var colonnes := [
		{"k": "nom", "t": "JOUEUR", "x": 16.0, "w": 400.0, "tri": true, "desc": false},
		{"k": "poste", "t": "POSTE", "x": 430.0, "w": 210.0, "tri": true, "desc": false},
		{"k": "cond", "t": "CONDITION", "x": 660.0, "w": 300.0, "tri": true, "desc": false},
		{"k": "charge", "t": "CHARGE", "x": 990.0, "w": 240.0, "tri": true},
		{"k": "etat", "t": "STATUT", "x": 1256.0, "w": 170.0, "tri": true, "desc": false},
	]
	_liste(app, page, Rect2(gauche, y, largeur, BAS - y), colonnes, surveilles, 46.0)

# --- B : mixte ---------------------------------------------------------------------------------------------------

static func _variante_b(app: Control, page: Control, tuiles: Array, surveilles: Array) -> void:
	var gauche := Vertical.DROITE
	var largeur := FIN - gauche
	var tw := (largeur - 3 * 16) / 4.0
	for i in tuiles.size():
		var t: Array = tuiles[i]
		Pieces.tuile(page, Rect2(gauche + i * (tw + 16), HAUT, tw, 108), t[0], t[1], t[2], "TacticsTabTuile%d" % i, 52, "", t[3], true, t[4])
	var y := HAUT + 132
	var lg := 420.0
	_titre(page, gauche, y, "La semaine", Charte.REPOS)
	_agenda(app, page, Rect2(gauche, y + 46, lg, BAS - y - 46))
	var colonnes := [
		{"k": "nom", "t": "JOUEUR", "x": 16.0, "w": 330.0, "tri": true, "desc": false},
		{"k": "poste", "t": "POSTE", "x": 356.0, "w": 190.0, "tri": true, "desc": false},
		{"k": "cond", "t": "CONDITION", "x": 560.0, "w": 230.0, "tri": true, "desc": false},
		{"k": "charge", "t": "CHARGE", "x": 816.0, "w": 170.0, "tri": true},
	]
	_liste(app, page, Rect2(gauche + lg + 24, y, largeur - lg - 24, BAS - y), colonnes, surveilles, 48.0)

# --- Pièces --------------------------------------------------------------------------------------------------------

static func _titre(page: Control, x: float, y: float, texte: String, couleur: Color) -> void:
	Kit.marqueur(page, Rect2(x, y + 4, 5, 30), couleur)
	var t := Kit.titre(page, x + 16, y + 30, texte, 28, 600)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.name = "TacticsBloc_" + texte.validate_node_name()

## Tuile-chiffre compacte de l'en-tête de l'Effectif : gros chiffre coloré, légende en capitales à sa droite, icône.
static func _tuile_compacte(page: Control, zone: Rect2, t: Array, id: String) -> void:
	var couleur: Color = t[2]
	var carte := D.rect(page, zone, Charte.PANNEAU_2.lerp(couleur, .12), Charte.RAYON_CARTE)
	carte.name = id
	carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var valeur := str(t[0])
	var chiffre := D.text(carte, 18, zone.size.y / 2.0 + 15, valeur, 42, couleur, 800, zone.size.x - 60)
	chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA)
	chiffre.name = id + "Valeur"
	chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lv := Charte.TITRE_EXTRA.get_string_size(valeur, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(42))).x / C.density
	var legende := D.text(carte, 18 + lv + 12, zone.size.y / 2.0 + 7, str(t[1]).to_upper(), 17, Charte.IVOIRE_2, 700, zone.size.x - lv - 80)
	legende.name = id + "Legende"
	legende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icone := C.icon(str(t[3]), 24, couleur)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carte.add_child(icone)
	D.place(icone, Rect2(zone.size.x - 42, (zone.size.y - 24) / 2.0, 24, 24))
	var action: Callable = t[4]
	if action.is_valid(): Pieces.rendre_cliquable(carte, zone.size, action, id + "Lien", "%s %s" % [valeur, str(t[1])], "", Charte.RAYON_CARTE)

static func _panneaux():
	return load("res://ui/immersive08/panneaux_effectif.gd")

static func _date_courte(j: Dictionary) -> String:
	var d := str(j.get("date", "")).split("-")
	return "%s/%s" % [d[2], d[1]] if d.size() == 3 else str(j.get("date", ""))

static func _ouvrir(app: Control) -> void:
	load("res://ui/immersive08/tactics_onglets.gd")._ouvrir_entrainement(app, 0)

## A : bande compacte des 7 jours (comme le panneau Semaine de l'Effectif, en une rangée) : lettre, jour, icône.
static func _bande_semaine(app: Control, page: Control, zone: Rect2) -> void:
	var P = _panneaux()
	var jours: Array = P._jours_programme(app)
	if jours.is_empty(): return
	var gap := 8.0
	var w := (zone.size.x - 6 * gap) / 7.0
	for i in jours.size():
		var j: Dictionary = jours[i]
		var kind := str(j.get("kind", "repos"))
		var couleur: Color = P._couleur_jour(j)
		var vif: Color = couleur if kind != "repos" else Charte.IVOIRE_2
		var rect := Rect2(zone.position.x + i * (w + gap), zone.position.y, w, zone.size.y)
		var aujourdhui := bool(j.get("today", false))
		var case_ := D.rect(page, rect, Charte.PANNEAU_2.lerp(couleur, .24) if kind != "repos" else Charte.PANNEAU_2, Charte.RAYON_CARTE, Charte.IVOIRE if aujourdhui else Color.TRANSPARENT)
		case_.name = "TacticsTabJour%d" % i
		if aujourdhui: (case_.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(3)))
		if bool(j.get("past", false)): case_.modulate = Color(1, 1, 1, .55)
		D.rect(case_, Rect2(0, 0, 6, zone.size.y), couleur, Charte.RAYON_PETIT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lettre := D.text(case_, 18, zone.size.y / 2.0 + 16, str(j.get("lettre", "")), 40, vif, 500, 40)
		lettre.add_theme_font_override("font", Charte.TITRE_FICHE)
		var mot: String = P.JOURS.get(kind, ["", kind])[1]
		var titre := D.text(case_, 54, 34, mot.to_upper(), 20, Charte.IVOIRE if kind != "repos" else Charte.IVOIRE_2, 500, w - 62)
		titre.add_theme_font_override("font", Charte.TITRE_FICHE)
		var second := _date_courte(j)
		var c2 := Charte.IVOIRE_2
		if kind == "seance":
			var ch := str(j.get("charge", "normal"))
			second = str(P.CHARGES.get(ch, ""))
			c2 = {"repos": Charte.REPOS, "intense": Charte.INTENSIF}.get(ch, Charte.NORMAL)
		D.text(case_, 54, 62, second, 17, c2, 700, w - 96, HORIZONTAL_ALIGNMENT_LEFT, true)
		var icone_id: String = P.JOURS.get(kind, ["", ""])[0]
		if bool(j.get("done", false)) or (kind == "match" and bool(j.get("played", false))): icone_id = "check"
		if not icone_id.is_empty():
			var icone := C.icon(icone_id, 24, vif)
			icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
			case_.add_child(icone)
			D.place(icone, Rect2(w - 36, zone.size.y - 34, 24, 24))
		Pieces.rendre_cliquable(case_, rect.size, func(): _ouvrir(app), "TacticsTabJourLien%d" % i, "%s · %s" % [str(j.get("date", "")), mot], "", Charte.RAYON_CARTE)

## B : la semaine en agenda vertical, une ligne par jour (rayures, survol), puis la charge de la semaine en pastilles.
static func _agenda(app: Control, page: Control, zone: Rect2) -> void:
	var P = _panneaux()
	var jours: Array = P._jours_programme(app)
	if jours.is_empty(): return
	var cadre := Control.new()
	cadre.name = "TacticsTabAgenda"
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(cadre)
	var h := 84.0
	D.place(cadre, Rect2(zone.position, Vector2(zone.size.x, 7 * (h + 4))))
	for i in jours.size():
		var j: Dictionary = jours[i]
		var kind := str(j.get("kind", "repos"))
		var couleur: Color = P._couleur_jour(j)
		var vif: Color = couleur if kind != "repos" else Charte.IVOIRE_2
		var aujourdhui := bool(j.get("today", false))
		var ligne := Button.new()
		ligne.name = "TacticsTabJour%d" % i
		ligne.focus_mode = Control.FOCUS_ALL
		cadre.add_child(ligne)
		D.place(ligne, Rect2(0, i * (h + 4), zone.size.x, h))
		load("res://ui/survol_ligne.gd").appliquer(ligne, false, Color.TRANSPARENT, app.accent)
		var mot: String = P.JOURS.get(kind, ["", kind])[1]
		ligne.accessibility_name = "%s · %s" % [str(j.get("date", "")), mot]
		ligne.pressed.connect(func(): _ouvrir(app))
		if bool(j.get("past", false)): ligne.modulate = Color(1, 1, 1, .55)
		var carre := D.rect(ligne, Rect2(10, 8, h - 16, h - 16), Charte.PANNEAU_2.lerp(couleur, .5) if kind != "repos" else Charte.PANNEAU_3, Charte.RAYON_PETIT, Charte.IVOIRE if aujourdhui else Color.TRANSPARENT)
		carre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if aujourdhui: (carre.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(3)))
		var lettre := D.text(carre, (h - 16) / 2.0, (h - 16) / 2.0 + 14, str(j.get("lettre", "")), 38, Charte.IVOIRE if kind != "repos" else Charte.IVOIRE_2, 500, h - 16, HORIZONTAL_ALIGNMENT_CENTER)
		lettre.add_theme_font_override("font", Charte.TITRE_FICHE)
		lettre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var titre := D.text(ligne, h + 10, h / 2.0 + 10, mot.to_upper(), 26, vif if kind != "repos" else Charte.IVOIRE_2, 500, 200)
		titre.add_theme_font_override("font", Charte.TITRE_FICHE)
		titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icone_id: String = P.JOURS.get(kind, ["", ""])[0]
		if bool(j.get("done", false)) or (kind == "match" and bool(j.get("played", false))): icone_id = "check"
		var x := h + 10 + Charte.TITRE_FICHE.get_string_size(mot.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(26))).x / C.density + 12
		if not icone_id.is_empty() and kind != "seance":
			var icone := C.icon(icone_id, 22, vif)
			icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ligne.add_child(icone)
			D.place(icone, Rect2(x, (h - 22) / 2.0, 22, 22))
		if kind == "seance":
			var ch := str(j.get("charge", "normal"))
			var c: Color = {"repos": Charte.REPOS, "intense": Charte.INTENSIF}.get(ch, Charte.NORMAL)
			Pieces.pastille(ligne, x, (h - 34) / 2.0, str(P.CHARGES.get(ch, "")), "train", "TacticsTabCharge%d" % i, "", c)
		var date := D.text(ligne, zone.size.x - 14, h / 2.0 + 7, _date_courte(j), 18, Charte.IVOIRE_2, 700, 80, HORIZONTAL_ALIGNMENT_RIGHT, true)
		date.mouse_filter = Control.MOUSE_FILTER_IGNORE

# --- Liste à lignes « À surveiller » -------------------------------------------------------------------------------

static func _statut(p: Dictionary) -> Array:
	if not Watch.indisponibilite(p).is_empty(): return ["Indisponible", Charte.PERTE, "warning", 0]
	var n: Variant = p.get("shirtNumber")
	if (n is int or n is float) and int(n) >= 1 and int(n) <= 15: return ["Titulaire", Charte.MORAL, "people", 1]
	if (n is int or n is float) and int(n) > 15: return ["Remplaçant", Charte.IVOIRE_2, "people", 2]
	return ["Hors groupe", Charte.IVOIRE_3, "", 3]

static func _couleur_cond(v: float) -> Color:
	return Charte.CONDITION if v >= 80 else (Pieces.ORANGE if v >= 70 else Charte.PERTE)

static func _cle(p: Dictionary, k: String) -> Variant:
	match k:
		"nom": return Kit.casse(str(p.get("name", "")))
		"poste": return str(p.get("pos", ""))
		"cond": return float(p.get("condition", 100))
		"charge": return float(p.get("physicalLoad", 0))
		"etat": return int(_statut(p)[3])
	return null

static func _liste(app: Control, page: Control, zone: Rect2, colonnes: Array, joueurs: Array, h: float) -> void:
	for col: Dictionary in colonnes:
		var al: int = col.get("a", HORIZONTAL_ALIGNMENT_LEFT)
		col.ax = float(col.x) + (float(col.w) if al == HORIZONTAL_ALIGNMENT_RIGHT else 0.0)
	var ui: Dictionary = app.management_ui
	var tri: Variant = ui.get(TRI)
	if not tri is Array or (tri as Array).size() < 2: tri = ["cond", false]
	var filtre := str(ui.get(FILTRE, ""))
	var table := Control.new()
	table.name = "TacticsTabSurveilles"
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(table)
	D.place(table, zone)
	# Bandeau : titre + nombre, filtres en pastilles, puis en-têtes triables.
	var haut := 58.0
	Kit.marqueur(table, Rect2(16, 14, 5, 30), Charte.PERTE)
	var titre := D.text(table, 32, 41, "À SURVEILLER", 28, Charte.IVOIRE, 500, 300)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "TacticsBloc_A_surveiller"
	var lt := Charte.TITRE_FICHE.get_string_size("À SURVEILLER", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(28))).x / C.density
	var compte := D.text(table, 32 + lt + 12, 41, str(joueurs.size()), 28, Charte.PERTE if not joueurs.is_empty() else Charte.IVOIRE_2, 800, 80)
	compte.add_theme_font_override("font", Charte.TITRE_EXTRA)
	var n_cond := joueurs.filter(func(p: Dictionary): return float(p.get("condition", 100)) < 80).size()
	var n_charge := joueurs.filter(func(p: Dictionary): return float(p.get("physicalLoad", 0)) >= 70).size()
	var x := 32 + lt + 12 + 60
	for d: Array in [["", "Tous", Charte.IVOIRE, joueurs.size()], ["cond", "Condition", Charte.PERTE, n_cond], ["charge", "Charge", Charte.INTENSIF, n_charge]]:
		x += _pilule(app, table, x, 11, str(d[1]), d[2], filtre == str(d[0]), str(d[0]), str(d[3])) + 8
	var entete := Control.new()
	entete.name = "TacticsTabSurveillesEntete"
	entete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.add_child(entete)
	D.place(entete, Rect2(0, haut, zone.size.x, 36))
	for col: Dictionary in colonnes:
		var k := str(col.k)
		var a: HorizontalAlignment = col.get("a", HORIZONTAL_ALIGNMENT_LEFT)
		var legende := D.text(entete, col.ax, 26, str(col.t), 17, Charte.IVOIRE_3, 700, col.w, a)
		legende.name = "TacticsTabColonne_" + k
		if not col.get("tri", false): continue
		var b := Button.new()
		b.name = "TacticsTabTri_" + k
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		entete.add_child(b)
		var lb := C.font(700).get_string_size(str(col.t) + " ▼", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(17))).x / C.density + 26.0
		D.place(b, C.reach_rect(Rect2(float(col.x) - 13.0, 1, lb, 34)))
		entete.move_child(b, legende.get_index())
		var actif: bool = str(tri[0]) == k
		Listes.styler_entete(b, legende, actif, actif and bool(tri[1]), str(col.t))
		b.pressed.connect(func():
			var desc: bool = (not bool(tri[1])) if actif else bool(col.get("desc", true))
			app.management_ui[TRI] = [k, desc]
			app._render())
	Bandeau.poser(table, Rect2(0, 0, zone.size.x, haut + 36), 36)
	# Lignes.
	var montres := joueurs.filter(func(p: Dictionary) -> bool:
		if filtre == "cond": return float(p.get("condition", 100)) < 80
		if filtre == "charge": return float(p.get("physicalLoad", 0)) >= 70
		return true)
	var k_tri := str(tri[0])
	var desc_tri := bool(tri[1])
	montres.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var va: Variant = _cle(a, k_tri)
		var vb: Variant = _cle(b, k_tri)
		if va == vb: return float(a.get("condition", 100)) < float(b.get("condition", 100))
		return (va > vb) if desc_tri else (va < vb))
	var lignes := Control.new()
	lignes.name = "TacticsTabSurveillesLignes"
	lignes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lignes.clip_contents = true
	table.add_child(lignes)
	var y0 := haut + 36 + Bandeau.ECART_LIGNES
	D.place(lignes, Rect2(0, y0, zone.size.x, zone.size.y - y0))
	var pas := h + 2.0
	var max_lignes := floori((zone.size.y - y0 + 2) / pas)
	for n in mini(montres.size(), max_lignes):
		_ligne(app, lignes, Rect2(0, n * pas, zone.size.x, h), colonnes, montres[n], n)

static func _pilule(app: Control, parent: Control, x: float, y: float, libelle: String, couleur: Color, choisie: bool, valeur: String, nombre: String) -> float:
	var CV = load("res://ui/immersive08/centre_visuel.gd")
	return CV.pilule(parent, x, y, libelle, couleur, choisie, func():
		app.management_ui[FILTRE] = valeur
		app._render(), "TacticsTabFiltre_" + (valeur if not valeur.is_empty() else "tous"), nombre, true, 36.0, 18)

static func _ligne(app: Control, parent: Control, rect: Rect2, colonnes: Array, p: Dictionary, n: int) -> void:
	var ligne := Button.new()
	ligne.name = "TacticsTabSurveille%d" % n
	ligne.focus_mode = Control.FOCUS_ALL
	ligne.clip_contents = true
	parent.add_child(ligne)
	D.place(ligne, rect)
	load("res://ui/survol_ligne.gd").appliquer(ligne, false, Color.TRANSPARENT, app.accent)
	var filet := D.rect(ligne, Rect2(0, rect.size.y - 1, rect.size.x, 1), Charte.FILET)
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pid := str(p.get("id", ""))
	var nom := Kit.casse(str(p.get("name", "")))
	ligne.accessibility_name = nom + " · fiche joueur"
	ligne.pressed.connect(func(): app.navigation_controller.open_entity({"kind": "player", "id": pid}))
	var h := rect.size.y
	var base := h / 2.0 + 7.0
	var cond := float(p.get("condition", 100))
	var charge := float(p.get("physicalLoad", 0))
	for col: Dictionary in colonnes:
		var x: float = col.ax
		var w: float = col.w
		match str(col.k):
			"nom":
				var portrait := Vertical._portrait(p, h - 10)
				portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ligne.add_child(portrait)
				D.place(portrait, Rect2(x, 5, h - 10, h - 10))
				var lw := minf(w - h - 50, Kit.largeur(nom, 20) + 6)
				Kit.nom(app, ligne, Rect2(x + h + 2, (h - 32) / 2.0, lw, 32), nom, pid, "TacticsTabSurveilleNom%d" % n, Charte.IVOIRE, 20)
				var ti := maxf(20.0, ceilf(16.0 / C.density))
				load("res://ui/carte_joueur_survol.gd").icone(app, ligne, Rect2(x + h + 2 + lw + 8, (h - ti) / 2.0, ti, ti), pid)
			"poste":
				D.text(ligne, x, base, str(p.get("pos", "")), 19, Charte.IVOIRE_2, 500, w, HORIZONTAL_ALIGNMENT_LEFT, true).mouse_filter = Control.MOUSE_FILTER_IGNORE
			"cond": _barre(ligne, Rect2(x, 0, w, h), cond / 100.0, _couleur_cond(cond), "%d %%" % roundi(cond), "TacticsTabSurveilleCond%d" % n)
			"charge": _barre(ligne, Rect2(x, 0, w, h), charge / 100.0, Charte.INTENSIF if charge >= 70 else Charte.IVOIRE_2, "%d" % roundi(charge), "TacticsTabSurveilleCharge%d" % n)
			"etat":
				var s := _statut(p)
				Pieces.pastille(ligne, x, (h - 34) / 2.0, str(s[0]), str(s[2]), "TacticsTabSurveilleStatut%d" % n, "", s[1])

## Rail fin + chiffre coloré à droite (comme la colonne Condition de l'Effectif).
static func _barre(parent: Control, zone: Rect2, part: float, couleur: Color, valeur: String, id: String) -> void:
	var rail := Rect2(zone.position.x, zone.position.y + zone.size.y / 2.0 - 4, zone.size.x - 86, 8)
	D.rect(parent, rail, Charte.PANNEAU_3, Charte.RAYON_PILULE).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if part > 0.0: D.rect(parent, Rect2(rail.position, Vector2(maxf(8.0, rail.size.x * clampf(part, 0, 1)), 8)), couleur, Charte.RAYON_PILULE).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := D.text(parent, zone.end.x, zone.position.y + zone.size.y / 2.0 + 8, valeur, 22, couleur, 800, 80, HORIZONTAL_ALIGNMENT_RIGHT)
	t.add_theme_font_override("font", Charte.TITRE_EXTRA)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.name = id
