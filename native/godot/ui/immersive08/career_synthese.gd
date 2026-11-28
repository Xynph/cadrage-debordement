extends RefCounted
## Carrière › Synthèse « façon Effectif » (choix de Léo du 22/11/2026, option B) : bandeau photo gardé, cinq tuiles
## chiffres colorées, onglets à leur place, tableau des saisons, trois courtes listes à lignes côte à côte.
## Les onglets Plan et Mobilité restent dans career_canvas.gd. Noms des boutons repris de career_canvas.gd.
## Coordonnées en unités du gabarit (toile 2248 de large).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")
const Manager = preload("res://ui/manager_career_view.gd")
const KEY := "immersive08_career_tab"
const PLAN_KEY := "immersive08_career_plan_index"
const LARGEUR := 2248.0
const ENTETE := 62.0

## Couleur franche par donnée (palette commune), toujours avec un chiffre ou un mot.
const OCCUPEES := Charte.MORAL
const LIBRES := Charte.GAIN
const CANDIDATURES := Charte.CONFIANCE
const SUIVIS := Charte.REPOS
const CARNET := Charte.INTENSIF
const SEMAINES := Charte.MORAL

static func construire(app: Control, canvas: Control, data: Dictionary) -> void:
	_bandeau_photo(app, canvas, data)
	var tuiles := _metriques(data)
	tuiles.append(["Carnet", "PROFILS AU CARNET", str(data.get("recruitment", []).size()), "", CARNET, 0.0, "search"])
	var w := (LARGEUR - 16.0 * (tuiles.size() - 1)) / tuiles.size()
	for i in tuiles.size():
		_tuile(canvas, Rect2(i * (w + 16.0), 243, w, 112), tuiles[i], "CareerMetricLien" + str(i), _vers(app, "details", "CareerTab_details"), 56)
	load("res://ui/immersive08/career_canvas.gd")._tabs(app, canvas, "summary")
	# Les saisons : tableau pleine largeur.
	var plan := _panneau(canvas, Rect2(0, 441, LARGEUR, 452), "Plan sur trois saisons", "tactic", "CareerPlanSummary")
	_lien(plan, LARGEUR - 24, 13, "Couverture poste par poste →", _vers(app, "plan", "CareerTab_plan"), "CareerOpenPlan")
	_saisons(app, plan, data, Rect2(14, 66, LARGEUR - 28, 0), 106.0, [
		{"k": "saison", "t": "SAISON", "x": 24, "w": 300},
		{"k": "couverts", "t": "POSTES COUVERTS", "x": 380, "w": 600},
		{"k": "masse", "t": "MASSE SALARIALE", "x": 1060, "w": 280},
		{"k": "semaines", "t": "SEMAINES CONNUES", "x": 1400, "w": 260},
		{"k": "fragiles", "t": "POSTES FRAGILES", "x": 1720, "w": 480},
	])
	# Trois courtes listes côte à côte, à la hauteur de la plus longue.
	var moves: Array = data.get("history", [])
	var n_parcours := maxi(1, mini(4, moves.size()))
	var y0 := 909.0
	# Les trois listes prennent toute la hauteur restante de la toile (1244) ; lignes plus basses si le parcours est long.
	var rangs := maxi(2, n_parcours)
	var h := clampf(floorf((1244.0 - y0 - 82.0) / rangs) - 2.0, 56.0, 120.0)
	var hauteur := rangs * (h + 2.0)
	var largeurs := [720.0, 860.0, LARGEUR - 720.0 - 860.0 - 32.0]
	var x := 0.0
	var mandat := _panneau(canvas, Rect2(x, y0, largeurs[0], 70 + hauteur + 12), "Mandat et mobilité", "flag", "CareerMandate")
	_lien(mandat, largeurs[0] - 20, 13, "Dossiers →", _vers(app, "details", "CareerTab_details"), "CareerMobilityLien")
	var lm: float = largeurs[0] - 28
	var lignes_mandat := _liste(mandat, Rect2(14, 70, lm, hauteur), "CareerMandat")
	_ligne_club(app, lignes_mandat, data, Rect2(0, 0, lm, h), 0, [20, 380, lm - 16])
	_ligne_candidatures(app, lignes_mandat, data, Rect2(0, h + 2.0, lm, h), 1, [20, 240, lm - 16])
	x += largeurs[0] + 16.0
	var parcours := _panneau(canvas, Rect2(x, y0, largeurs[1], 70 + hauteur + 12), "Dernière prise de poste", "clock", "CareerHistorySummary")
	_lien(parcours, largeurs[1] - 20, 13, "Archives →", _vers(app, "details", "CareerTab_details"), "CareerOpenHistoryLien")
	var lp: float = largeurs[1] - 28
	var lignes_parcours := _liste(parcours, Rect2(14, 70, lp, hauteur), "CareerParcours")
	for i in n_parcours:
		_ligne_parcours(app, lignes_parcours, data, Rect2(0, i * (h + 2.0), lp, h), i, [20, 600], i)
	x += largeurs[1] + 16.0
	var carnet := _panneau(canvas, Rect2(x, y0, largeurs[2], 70 + hauteur + 12), "Carnet du recrutement", "search", "CareerRecruitmentSummary")
	_lien(carnet, largeurs[2] - 20, 13, "Carnet →", _vers(app, "details", "CareerTab_details"), "CareerOpenRecruitmentLien")
	var lc: float = largeurs[2] - 28
	var lignes_carnet := _liste(carnet, Rect2(14, 70, lc, hauteur), "CareerCarnet")
	for i in 2:
		_ligne_carnet(app, lignes_carnet, data, Rect2(0, i * (h + 2.0), lc, h), i, [20, 440], i)

## Bandeau photo de main sans doré (règle : doré réservé à Continuer) : filet et pastilles en couleurs de la charte.
static func _bandeau_photo(app: Control, canvas: Control, data: Dictionary) -> void:
	var hero := D.panel(canvas, Rect2(0, 0, LARGEUR, 227), "", "", "", "CareerHero")
	hero.clip_contents = true
	var picture := G.club_picture(app.model.club, "city", false)
	hero.add_child(picture)
	D.place(picture, Rect2(980, 1, 1267, 225))
	U.art_fade(hero, Rect2(980, 1, 1267, 225))
	var crest := G.crest(app.model.club, C.px(124))
	hero.add_child(crest)
	D.place(crest, Rect2(26, 46, 124, 135))
	D.line(hero, Vector2(180, 41), Vector2(180, 184), Charte.IVOIRE_3, 2)
	D.text(hero, 211, 118, "LE PARCOURS DU MANAGER", 70, Charte.IVOIRE, 700, 1248).add_theme_font_override("font", Charte.TITRE_FICHE)
	var club := R.pastille(hero, 211, 172, G.club_name(app.model.club) + "  ·  " + P.league_name(app.model), Charte.IVOIRE_2, "shield", "CareerSousTitre")
	var since: Variant = data.get("currentFrom", app.model.meta.get("season", 1))
	R.pastille(hero, 211 + club.size.x / C.density + 10, 172, "Mandat depuis " + G.season_label(since), SEMAINES, "calendar", "CareerMandatDepuis")
	if not picture.tooltip_text.is_empty():
		var credit := D.chip(hero, Rect2(2015, 17, 211, 31), "CRÉDIT PHOTO", Charte.IVOIRE_2)
		credit.mouse_filter = Control.MOUSE_FILTER_PASS
		credit.tooltip_text = picture.tooltip_text
		credit.accessibility_name = credit.tooltip_text.replace("\n", " · ")

# --- Pièces communes --------------------------------------------------------------------------------------------------

## Les quatre chiffres de l'en-tête : [nom, légende, valeur, suffixe, couleur, largeur, icône].
static func _metriques(data: Dictionary) -> Array:
	return [
		["Occupees", "PLACES OCCUPÉES", G.n(data.get("occupied", "—")), "/ " + G.n(data.get("capacity", "—")), OCCUPEES, 290.0, "people"],
		["Libres", "PLACES DISPONIBLES", G.n(data.get("places", "—")), "", LIBRES, 270.0, "shield"],
		["Candidatures", "CANDIDATURES", str(data.get("applications", []).size()), "", CANDIDATURES, 240.0, "mail"],
		["Suivis", "PROFILS SUIVIS", str(data.get("watch", []).size()), "", SUIVIS, 240.0, "search"],
	]

static func _vers(app: Control, onglet: String, id: String) -> Callable:
	return func(): U.select(app, KEY, onglet, id)

static func _plat(fond: Color, bord: Color = Color.TRANSPARENT, epaisseur: int = 0, rayon: int = Charte.RAYON_PETIT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.border_color = bord
	s.set_border_width_all(maxi(epaisseur, C.px(epaisseur)) if epaisseur > 0 else 0)
	s.set_corner_radius_all(999 if rayon >= Charte.RAYON_PILULE else maxi(2, C.px(rayon)))
	s.anti_aliasing = true
	return s

static func _chiffre(parent: Node, x: float, base: float, valeur: Variant, taille: int, couleur: Color, largeur: float = 0.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := D.text(parent, x, base, valeur, taille, couleur, 800, largeur, align)
	l.add_theme_font_override("font", Charte.TITRE_EXTRA)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _texte(parent: Node, x: float, base: float, valeur: Variant, taille: int, couleur: Color, largeur: float, graisse: int = 600, corps: bool = true) -> Label:
	var l := D.text(parent, x, base, valeur, taille, couleur, graisse, largeur, HORIZONTAL_ALIGNMENT_LEFT, corps)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _icone(parent: Node, zone: Rect2, id: String, couleur: Color) -> void:
	var i := C.icon(id, int(zone.size.x), couleur)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(i)
	D.place(i, zone)

## Tuile chiffre cliquable (gabarit des tuiles de l'Effectif) : légende et icône en haut, chiffre coloré dessous.
static func _tuile(parent: Control, zone: Rect2, t: Array, id: String, action: Callable, taille: int = 48) -> Button:
	var couleur: Color = t[4]
	var tuile := Button.new()
	tuile.name = id
	tuile.focus_mode = Control.FOCUS_ALL
	tuile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tuile.accessibility_name = "%s %s %s" % [t[1], t[2], t[3]]
	tuile.add_theme_stylebox_override("normal", _plat(Charte.PANNEAU.lerp(couleur, .08), Color.TRANSPARENT, 0, 16))
	tuile.add_theme_stylebox_override("hover", _plat(Charte.PANNEAU_2.lerp(couleur, .14), Color.TRANSPARENT, 0, 16))
	tuile.add_theme_stylebox_override("pressed", _plat(Charte.PANNEAU_3.lerp(couleur, .14), Color.TRANSPARENT, 0, 16))
	tuile.add_theme_stylebox_override("focus", _plat(Color.TRANSPARENT, Charte.IVOIRE, 2, 16))
	parent.add_child(tuile)
	D.place(tuile, zone)
	load("res://ui/retour_tuile.gd").brancher(tuile, tuile, C.px(16))
	_icone(tuile, Rect2(16, 12, 20, 20), str(t[6]), couleur)
	_texte(tuile, 44, 29, t[1], 17, Charte.IVOIRE_2, zone.size.x - 56, 700, false)
	var base := zone.size.y - 16.0
	var v := _chiffre(tuile, 16, base, t[2], taille, couleur, zone.size.x - 28)
	v.name = id + "Valeur"
	if not str(t[3]).is_empty():
		var l := C.font(800).get_string_size(str(t[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille))).x / C.density
		_texte(tuile, 16 + l + 12, base - 4, t[3], 20, Charte.IVOIRE_2, zone.size.x - l - 40, 500)
	tuile.pressed.connect(action)
	return tuile

## Panneau de l'Effectif : fond PANNEAU, pictogramme et titre Anton.
static func _panneau(parent: Control, zone: Rect2, titre: String, icone_id: String, id: String) -> Panel:
	var p := D.panel(parent, zone, "", "", "", id)
	_icone(p, Rect2(20, (ENTETE - 26) / 2.0, 26, 26), icone_id, Charte.IVOIRE_2)
	var t := D.text(p, 58, ENTETE / 2.0 + 12, titre.to_upper(), 30, Charte.IVOIRE, 700, zone.size.x - 200)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Lien « … → » en haut à droite d'un panneau (bord droit à `droite`).
static func _lien(parent: Control, droite: float, y: float, texte: String, action: Callable, id: String) -> void:
	var l := R.largeur(texte, 19, 600) + 36.0
	var b := Button.new()
	b.name = id
	b.text = texte
	b.flat = true
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	C.style_bouton_lien(b, 19)
	parent.add_child(b)
	D.place(b, C.reach_rect(Rect2(droite - l, y, l, 40)))
	b.pressed.connect(action)

static func _liste(parent: Control, zone: Rect2, id: String) -> Control:
	var liste := Control.new()
	liste.name = id
	liste.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(liste)
	D.place(liste, zone)
	return liste

## Titre de groupe (comme AVANTS / ARRIÈRES de l'Effectif) : barre de couleur, titre, compte. Renvoie le y suivant.
## Ligne de liste cliquable : survol commun (bande claire + liseré club), rayure une ligne sur deux, filet bas.
static func _ligne(app: Control, parent: Control, zone: Rect2, rang: int, action: Callable, id: String, aide: String = "") -> Button:
	var ligne := Button.new()
	ligne.name = id
	ligne.clip_contents = true
	ligne.focus_mode = Control.FOCUS_ALL
	ligne.tooltip_text = aide
	ligne.accessibility_name = aide
	var fond = load("res://ui/survol_ligne.gd").appliquer(ligne, false, Color.TRANSPARENT, app.accent)
	fond.rang_fixe = rang
	parent.add_child(ligne)
	D.place(ligne, zone)
	var filet := Panel.new()
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filet.add_theme_stylebox_override("panel", _plat(Charte.FILET, Color.TRANSPARENT, 0, 0))
	ligne.add_child(filet)
	filet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	filet.offset_top = -1.0
	if action.is_valid(): ligne.pressed.connect(action)
	return ligne

## Tableau des saisons : bande d'en-têtes puis une ligne par saison (mène à l'onglet Plan, sur cette saison).
static func _saisons(app: Control, panneau: Panel, data: Dictionary, zone: Rect2, h: float, colonnes: Array) -> void:
	var plans: Array = data.get("plan", [])
	var entete := _liste(panneau, Rect2(zone.position.x, zone.position.y, zone.size.x, 36), "CareerSaisonsEntete")
	for col: Dictionary in colonnes:
		_texte(entete, float(col.x), 26, str(col.t), 17, Charte.IVOIRE_3, float(col.w), 700, false)
	Bandeau.poser(entete, Rect2(0, 0, zone.size.x, 36), 36)
	var lignes := _liste(panneau, Rect2(zone.position.x, zone.position.y + 44, zone.size.x, h * 3 + 8), "CareerSaisons")
	if plans.is_empty():
		_chiffre(lignes, 24, 52, "0", 36, Charte.IVOIRE_3, 200)
		return
	var x: Dictionary = {}
	for col: Dictionary in colonnes: x[col.k] = col
	for i in mini(3, plans.size()):
		var entry: Dictionary = plans[i]
		var annee := G.n(entry.year)
		var covered := int(entry.get("covered", 0))
		var semaines := int(entry.get("payments", 0))
		var fragiles := int(entry.get("thin", 0))
		var couleur_couv: Color = Charte.GAIN if covered == 15 else Charte.INTENSIF
		var aide := "Salaires connus sur %d %s. Postes avec moins de deux candidats : %d." % [semaines, "semaine" if semaines <= 1 else "semaines", fragiles]
		var index := i
		var ligne := _ligne(app, lignes, Rect2(0, i * (h + 2.0), zone.size.x, h), i, func():
			app.management_ui[PLAN_KEY] = index
			U.select(app, KEY, "plan", "CareerTab_plan"), "CareerYear" + annee, aide)
		var base := h / 2.0 + 11.0
		var c: Dictionary = x.saison
		_chiffre(ligne, float(c.x), base + 1, G.season_label(entry.year), 30, Charte.IVOIRE, float(c.w))
		c = x.couverts
		var valeur := "%d / 15" % covered
		_chiffre(ligne, float(c.x), base + 2, valeur, 34, couleur_couv, 150)
		var bx := float(c.x) + 150.0
		var bw := float(c.w) - 150.0
		D.rect(ligne, Rect2(bx, h / 2.0 - 5, bw, 10), Charte.PANNEAU_3, Charte.RAYON_PILULE).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if covered > 0: D.rect(ligne, Rect2(bx, h / 2.0 - 5, maxf(10.0, bw * covered / 15.0), 10), couleur_couv, Charte.RAYON_PILULE).mouse_filter = Control.MOUSE_FILTER_IGNORE
		c = x.masse
		_chiffre(ligne, float(c.x), base + 1, U.amount(entry.get("payroll")), 30, Charte.IVOIRE, float(c.w))
		c = x.semaines
		R.pastille(ligne, float(c.x), base - 4, "%d sem." % semaines, SEMAINES, "calendar", "CareerWeeks" + annee)
		c = x.fragiles
		var texte := "%d %s < 2 candidats" % [fragiles, "poste" if fragiles <= 1 else "postes"] if fragiles > 0 else "Tous couverts"
		R.pastille(ligne, float(c.x), base - 4, texte, Charte.INTENSIF if fragiles > 0 else Charte.GAIN, "warning" if fragiles > 0 else "check", "CareerThin" + annee)

## Ligne « ton club » : blason, nom, pastille du mandat. Mène aux dossiers de mobilité (bouton de main).
static func _ligne_club(app: Control, parent: Control, data: Dictionary, zone: Rect2, rang: int, cols: Array) -> void:
	var ligne := _ligne(app, parent, zone, rang, _vers(app, "details", "CareerTab_details"), "CareerMobility", "Dossiers de mobilité")
	var crest := G.crest(app.model.club, C.px(40))
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(crest)
	D.place(crest, Rect2(float(cols[0]), (zone.size.y - 44) / 2.0, 40, 44))
	var base := zone.size.y / 2.0 + 10.0
	_texte(ligne, float(cols[0]) + 56, base, G.club_name(app.model.club), 28, Charte.IVOIRE, float(cols[1]) - float(cols[0]) - 70, 700, false)
	var since: Variant = data.get("currentFrom", app.model.meta.get("season", 1))
	R.pastille(ligne, float(cols[1]), base - 2, "Depuis " + G.season_label(since), SEMAINES, "calendar", "CareerMandatSaison")

## Ligne « candidatures » : état en pastille (+ « i »), bouton d'activation si besoin (même commande que main).
static func _ligne_candidatures(app: Control, parent: Control, data: Dictionary, zone: Rect2, rang: int, cols: Array) -> void:
	var active: bool = data.get("active", false)
	var pending: Variant = data.get("pending")
	var window: bool = data.get("window", false)
	var ligne := _ligne(app, parent, zone, rang, _vers(app, "details", "CareerTab_details"), "CareerCandidatures", "Candidatures")
	var base := zone.size.y / 2.0 + 10.0
	_texte(ligne, float(cols[0]), base, "Candidatures", 28, Charte.IVOIRE, float(cols[1]) - float(cols[0]) - 20, 700, false)
	var etat := ["À activer", Charte.INTENSIF, "warning"]
	if pending is Dictionary: etat = ["Prochaine saison · " + Manager._club(app, pending.toClub), Charte.GAIN, "flag"]
	elif window: etat = ["Ouvertes", Charte.GAIN, "check"]
	elif active: etat = ["En fin de saison", SEMAINES, "calendar"]
	var p := R.pastille(ligne, float(cols[1]), base - 2, str(etat[0]), etat[1], str(etat[2]), "CareerCandidaturesEtat")
	if not pending is Dictionary:
		Pieces.info(ligne, float(cols[1]) + p.size.x / C.density + 12, (zone.size.y - 26) / 2.0, "La prise de poste est effective au passage à la saison suivante.", "Mandat")
	if not active and cols.size() > 2:
		var l := R.largeur("Activer", 20, 700) + 56.0
		var bouton := D.button(ligne, Rect2(float(cols[2]) - l, (zone.size.y - 44) / 2.0, l, 44), "Activer", func(): app._command("manager_career_activate", {"context": data.get("context", {})}), false, "", true, U.GREEN, "ManagerCareerActivate")
		C.style_bouton_contour(bouton, 20)
		bouton.alignment = HORIZONTAL_ALIGNMENT_CENTER
		bouton.accessibility_name = "Activer les candidatures"
		bouton.disabled = app.waiting or not data.get("available", false)

## Ligne du parcours : club de départ → club d'arrivée et saison (ou premier mandat). Mène aux archives.
static func _ligne_parcours(app: Control, parent: Control, data: Dictionary, zone: Rect2, rang: int, cols: Array, i: int) -> void:
	var moves: Array = data.get("history", [])
	var id := "CareerOpenHistory" if i == 0 else "CareerHistory" + str(i)
	var ligne := _ligne(app, parent, zone, rang, _vers(app, "details", "CareerTab_details"), id, "Parcours et archives")
	var base := zone.size.y / 2.0 + 10.0
	var largeur := float(cols[1]) - float(cols[0]) - 20
	if moves.is_empty():
		_texte(ligne, float(cols[0]), base, "Premier mandat", 28, Charte.IVOIRE, largeur, 700, false)
		var since: Variant = data.get("currentFrom", app.model.meta.get("season", 1))
		R.pastille(ligne, float(cols[1]), base - 2, G.season_label(since), CANDIDATURES, "flag", "CareerParcoursSaison0")
		return
	var move: Dictionary = moves[i]
	_texte(ligne, float(cols[0]), base, Manager._club(app, move.get("fromClub")) + "  →  " + Manager._club(app, move.get("toClub")), 28, Charte.IVOIRE, largeur, 700, false)
	R.pastille(ligne, float(cols[1]), base - 2, "Saison " + G.season_label(move.get("arrivalSeason", "—")), CANDIDATURES, "flag", "CareerParcoursSaison" + str(i))

## Ligne du carnet : profils au carnet, rapports datés (chiffre coloré). Mène au carnet du recrutement.
static func _ligne_carnet(app: Control, parent: Control, data: Dictionary, zone: Rect2, rang: int, cols: Array, i: int) -> void:
	var profils: Array = data.get("recruitment", [])
	var rapports: Array = data.get("reports", [])
	var item: Array = [["Profils au carnet", profils.size(), CARNET, "CareerOpenRecruitment"], ["Rapports datés", rapports.size(), SEMAINES, "CareerRecruitmentReports"]][i]
	var ligne := _ligne(app, parent, zone, rang, _vers(app, "details", "CareerTab_details"), str(item[3]), "Carnet du recrutement")
	var base := zone.size.y / 2.0 + 10.0
	_texte(ligne, float(cols[0]), base, str(item[0]), 28, Charte.IVOIRE, float(cols[1]) - float(cols[0]) - 20, 700, false)
	_chiffre(ligne, float(cols[1]), base + 3, str(item[1]), 36, item[2] if int(item[1]) > 0 else Charte.IVOIRE_3, 200)
