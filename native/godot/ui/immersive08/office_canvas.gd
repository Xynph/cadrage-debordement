extends RefCounted
## Bureau (design/ux/04-bureau.md, maquette « Affiche et Gabi » du 19/11/2026, choix de Léo) : à gauche l'affiche du
## prochain match (bandeau voilé ≤ 160 px, face-à-face chiffré des deux clubs), les trois priorités et l'état du
## groupe ; à droite la colonne de Gabi (sa semaine, les prochains matchs, son buste et sa bulle) ; dessous le
## classement court, le courrier et le profil à suivre. Tout élément ouvre quelque chose (priorité, club, message,
## joueur, match, groupe). Couleurs et polices : ui/charte.gd uniquement ; l'or est réservé à Continuer.
const Copy = preload("res://ui/management_copy.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/management_state.gd")
const G = preload("res://ui/game_skin.gd")
const Avis = preload("res://guide/gabi_avis.gd")
const Office = preload("res://ui/immersive08/office.gd")
const World = preload("res://ui/immersive08/world_archive.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")
const Zones = preload("res://ui/immersive08/standings_zones.gd")
const Charte = preload("res://ui/charte.gd")
const Link = preload("res://ui/entity_link.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const EquipeType = preload("res://ui/equipe_type_view.gd")
const NotesMatch = preload("res://ui/notes_match.gd")

const PAGE_WIDTH := 2248
const GABI_WIDTH := 736
const GAP := 16
## Haut de page : le titre est dans l'en-tête de la coque (shell._entete_bureau) ; les blocs commencent à TOP.
const TOP := 0
## Bandeau d'illustration voilé de l'affiche (≤ 160 px réels : 170 unités ≈ 124 px à 1920).
const BAND := 118
const FIXTURE_H := 430
const ROW2_H := 430
const ROW3_H := 295
## Lignes du classement court (notre club et ses voisines).
const STANDINGS_ROWS := 4
const TIMELINE_H := 190
const JOURS := ["DIMANCHE", "LUNDI", "MARDI", "MERCREDI", "JEUDI", "VENDREDI", "SAMEDI"]

# ---------------------------------------------------------------------------------------------------------
# Éléments communs
# ---------------------------------------------------------------------------------------------------------

static func _box(color: Color, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(0)
	return style

## Panneau de page (charte §3, comme D.panel) : jeton `panneau`, rayon 18 px (24 en référence 2560), sans bordure, avec
## l'ombre portée de la charte, posé aux coordonnées de la page.
static func _plate(parent: Node, rectangle: Rect2, id: String) -> Panel:
	var panel := Panel.new()
	panel.name = id
	panel.add_theme_stylebox_override("panel", Charte.style_panneau(Charte.PANNEAU, maxi(3, C.px(24)), 0))
	parent.add_child(panel)
	D.place(panel, rectangle)
	return panel

static func _titre(card: Control, titre: String, badge: String = "") -> Label:
	var largeur := card.size.x / C.density
	var label := _ex(D.text(card, 24, 40, titre, 26, Charte.IVOIRE, 800, largeur * .6))
	label.name = "CardTitle"
	if not badge.is_empty(): D.text(card, largeur - 24, 38, badge, 17, Charte.IVOIRE_2, 700, largeur * .4, HORIZONTAL_ALIGNMENT_RIGHT)
	D.line(card, Vector2(20, 56), Vector2(largeur - 20, 56), Color(Charte.FILET, .9))
	return label

## Titre en Barlow Condensed ExtraBold Italic (vraie italique de la charte, 10°).
static func _ex(label: Label) -> Label:
	label.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	return label

static func _largeur(texte: String, taille: int, police: Font = null) -> float:
	var font: Font = police if police != null else Charte.texte_moyen()
	return font.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille))).x / C.density

## Lien texte avec flèche (« Réception → ») : bouton plat DM Sans, focus visible ; `droite` : bord droit à x.
static func _lien(parent: Control, x: float, y: float, texte: String, action: Callable, id: String, taille: int = 20, droite: bool = false) -> Button:
	var largeur := _largeur(texte, taille) + 16
	var bouton := Link.styled_button(parent, Rect2(x - largeur if droite else x, y, largeur, maxf(32, C.reach(32))), texte, taille, Charte.IVOIRE, id)
	bouton.add_theme_font_override("font", Charte.texte_moyen())
	bouton.pressed.connect(action)
	bouton.tooltip_text = texte
	return bouton

## Action principale de la page : pilule à contour, texte crème, Barlow italique (l'aplat doré reste à Continuer).
static func _principal(parent: Control, rectangle: Rect2, caption: String, action: Callable, id: String, accent: Color) -> Button:
	var bouton := D.button(parent, rectangle, caption, action, true, "arrow", false, accent, id)
	bouton.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	bouton.add_theme_font_size_override("font_size", maxi(12, C.px(25)))
	# Continuer (coque) porte l'unique aplat doré de l'écran : ce bouton est une pilule à contour `LINE`, texte crème.
	var pilule := Charte.RAYON_PILULE
	var etats := {"normal": C.box(Color.TRANSPARENT, C.LINE, pilule, 18), "hover": C.box(C.RAISED, C.FAINT, pilule, 18),
		"pressed": C.box(Charte.SELECTION, Charte.IVOIRE, pilule, 18), "disabled": C.box(Color.TRANSPARENT, C.LINE, pilule, 18)}
	for mode: String in etats:
		var style := etats[mode] as StyleBoxFlat
		style.content_margin_left = C.px(18)
		style.content_margin_right = C.px(18)
		bouton.add_theme_stylebox_override(mode, style)
	var focus := C.box(Color.TRANSPARENT, Charte.OR, pilule, 18)
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(C.px(3))
	bouton.add_theme_stylebox_override("focus", focus)
	for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(couleur, Charte.IVOIRE)
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	bouton.icon = C.icon_texture("arrow", Charte.IVOIRE)
	return bouton

## Bouton transparent qui couvre une zone entière (ligne, compteur) : texte en haut à gauche si `marge_bas` > 0.
static func _zone(parent: Control, rectangle: Rect2, caption: String, action: Callable, id: String, taille: int = 21, marge_gauche: float = 0.0, marge_bas: float = 0.0) -> Button:
	var bouton := Link.styled_button(parent, rectangle, caption, taille, Charte.IVOIRE, id)
	bouton.add_theme_font_override("font", C.font(700))
	for etat in ["normal", "hover", "pressed"]:
		var style := bouton.get_theme_stylebox(etat) as StyleBoxFlat
		style.content_margin_left = C.px(marge_gauche + 4)
		style.content_margin_bottom = C.px(marge_bas)
		style.set_corner_radius_all(0)
		if etat != "normal": style.bg_color = Color(Charte.IVOIRE, .06)
	var focus := bouton.get_theme_stylebox("focus") as StyleBoxFlat
	focus.set_corner_radius_all(0)
	bouton.pressed.connect(action)
	# Survol et appui : retour commun des tuiles cliquables (ui/retour_tuile.gd) ; les priorités gardent leur barre
	# d'urgence à gauche (pas de liseré du club par-dessus) et se lisent comme des lignes (jamais d'ombre).
	load("res://ui/retour_tuile.gd").brancher(bouton, bouton, 0.0, true, marge_gauche <= 0.0, marge_gauche <= 0.0)
	return bouton

static func _crest(parent: Node, club: Dictionary, rectangle: Rect2) -> void:
	var image := G.crest(club, C.px(rectangle.size.x))
	parent.add_child(image)
	D.place(image, rectangle)

static func _label_reading(app: Control, parent: Node, label: Label, target: Dictionary, id: String, caption: String) -> Button:
	return Office.reading_overlay(app, parent, Rect2(label.position / C.density, label.size / C.density), target, id, caption)

static func _scheduled_reading(app: Control, parent: Node, fixture: Dictionary, opponent: Label, timing: Label) -> void:
	var club := Office.fixture_opponent(app.model, fixture)
	_label_reading(app, parent, opponent, Office.club_reading_target(app, club), "OfficeScheduledOpponent", opponent.text)
	_label_reading(app, parent, timing, Office.date_reading_target(app, fixture), "OfficeScheduledDate", timing.text)

## Pastille ovale V / N / D : la lettre dit le sens, la couleur le confirme (défaite en rouge, comme au classement).
static func _pastille(parent: Control, x: float, y: float, lettre: String, largeur: float = 30, hauteur: float = 24) -> void:
	var couleur: Color = Charte.PERTE if lettre == "D" else Charte.N if lettre == "N" else Charte.V
	var ovale := D.rect(parent, Rect2(x, y, largeur, hauteur), Color(couleur, .16), 0)
	var style := _box(Color(couleur, .16), couleur, 1)
	style.set_corner_radius_all(C.px(hauteur / 2.0))
	ovale.add_theme_stylebox_override("panel", style)
	D.text(ovale, largeur / 2.0, hauteur / 2.0 + 7, lettre, 17, couleur, 700, largeur, HORIZONTAL_ALIGNMENT_CENTER)

static func _forme(parent: Control, x: float, y: float, forme: Array, droite: bool = false) -> void:
	var nombre := mini(5, forme.size())
	var depart := x - nombre * 34.0 + 4.0 if droite else x
	for i in nombre: _pastille(parent, depart + i * 34.0, y, str(forme[i]))

static func _ligne_club(model: Dictionary, club_id: Variant) -> Dictionary:
	for league: Dictionary in model.get("leagues", []):
		if league.get("id") != model.get("meta", {}).get("leagueId"): continue
		for row: Dictionary in league.get("rows", []):
			if row.get("id") == club_id: return row
	for row: Dictionary in model.get("league", []):
		if row.get("id") == club_id: return row
	return {}

# ---------------------------------------------------------------------------------------------------------
# Page
# ---------------------------------------------------------------------------------------------------------

static func build(app: Control) -> Control:
	var page := Control.new()
	page.name = "ImmersiveOffice"
	C.fill(page, true)
	var gabi: bool = is_instance_valid(app.get("coach")) and app.coach.has_method("bureau_disponible") and app.coach.bureau_disponible()
	var main_w := PAGE_WIDTH - GABI_WIDTH - GAP
	var y := TOP
	var fixture := _plate(page, Rect2(0, y, main_w, FIXTURE_H), "OfficeFixture")
	_fixture(fixture, app, main_w)
	y += FIXTURE_H + GAP
	var priorities_w := 900
	_priorities(_titree(page, Rect2(0, y, priorities_w, ROW2_H), "TES TROIS PRIORITÉS", "OfficeDecisions"), app, priorities_w)
	_group(_titree(page, Rect2(priorities_w + GAP, y, main_w - priorities_w - GAP, ROW2_H), "ÉTAT DU GROUPE", "OfficeGroup"), app, main_w - priorities_w - GAP)
	var column := Rect2(main_w + GAP, TOP, GABI_WIDTH, FIXTURE_H + GAP + ROW2_H)
	y += ROW2_H + GAP
	var left_w := 1100
	_standings(_titree(page, Rect2(0, y, left_w, ROW3_H), "CLASSEMENT · " + P.league_name(app.model), "OfficeStandings"), app, left_w)
	_journal(_titree(page, Rect2(left_w + GAP, y, PAGE_WIDTH - left_w - GAP, ROW3_H), "COURRIER", "OfficeJournal"), app, PAGE_WIDTH - left_w - GAP)
	y += ROW3_H + GAP
	# « Profil à suivre » (Recrutement) et « Résultats » (Calendrier) ne sont pas au Bureau : la page tient sans défiler.
	if gabi:
		var zone := D.panel(page, column, "", "", "", "GabiBureau")
		zone.add_theme_stylebox_override("panel", Charte.style_panneau(Charte.PANNEAU, maxi(3, C.px(24)), 0))
		zone.clip_contents = true
		# Le carnet de Gabi (fond plein) suit les coins arrondis du panneau.
		zone.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		Charte.ombre_derriere(zone)
		var extra := func(parent: Control, haut: float, largeur: float) -> float:
			var matches := _plate(parent, Rect2(0, haut, largeur, TIMELINE_H), "OfficeTimeline")
			# Section de la colonne de Gabi (même fond, dans son panneau) : pas une tuile à part, pas d'ombre.
			Charte.sans_ombre(matches.get_theme_stylebox("panel") as StyleBoxFlat)
			_timeline(matches, app, null, int(largeur))
			return float(TIMELINE_H)
		app.coach.installer_bureau(zone, extra)
		# Premiers pas de Gabi : carte sous le courrier, hors de la colonne de Gabi.
		if app.coach.has_method("carte_premiers_pas"):
			var haut: float = app.coach.carte_premiers_pas(page, Rect2(0, y, main_w, 128))
			if haut > 0.0: y += haut + GAP
	else:
		var matches := _plate(page, column, "OfficeTimeline")
		_timeline(matches, app, null, GABI_WIDTH)
	page.custom_minimum_size = Vector2(PAGE_WIDTH, y) * C.density
	return page

## Bloc à titre (Panel plat + titre italique + filet) aux coordonnées de la page.
static func _titree(page: Control, rectangle: Rect2, titre: String, id: String) -> Panel:
	var card := _plate(page, rectangle, id)
	_titre(card, titre)
	return card

## « SAMEDI, DANS 4 JOURS » depuis la date du jour du moteur et celle du match ; vide si l'une manque.
static func compte_a_rebours(app: Control, fixture: Dictionary) -> String:
	var today := str(app.model.get("meta", {}).get("calendarToday", ""))
	var date: Variant = fixture.get("date")
	if today.is_empty() or not date is String or date.is_empty(): return ""
	var depart := Time.get_unix_time_from_datetime_string(today)
	var arrivee := Time.get_unix_time_from_datetime_string(date)
	if depart <= 0 or arrivee <= 0: return ""
	var jours := int(roundf((arrivee - depart) / 86400.0))
	var nom: String = JOURS[int(Time.get_datetime_dict_from_datetime_string(date, false).get("weekday", 0))]
	if jours < 0: return ""
	if jours == 0: return "AUJOURD’HUI"
	if jours == 1: return "DEMAIN"
	return "%s, DANS %d JOURS" % [nom, jours]

# ---------------------------------------------------------------------------------------------------------
# Affiche du prochain match
# ---------------------------------------------------------------------------------------------------------

static func _fixture(card: Panel, app: Control, w: int = 1496) -> void:
	card.clip_contents = true
	# Photo et liseré de club suivent les coins arrondis du panneau.
	card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	Charte.ombre_derriere(card)
	var photo := D.photo(card, P.fixture_ground(app.model.meta, "office-hero"), Rect2(0, 0, w, BAND), .53)
	photo.name = "OfficeFixturePhoto"
	D.rect(card, Rect2(0, 0, w, BAND), Color(Charte.FOND, .74)).name = "OfficeFixtureVeil"
	var territory := Office.territory_art(app.model.club, true)
	if territory != null:
		card.add_child(territory)
		D.place(territory, Rect2(w - 700, 10, 684, BAND - 20))
		# Les vignettes du club ouvrent l'écran Club (jamais une tuile légendée qui ne fait rien).
		var ouvrir := _zone(card, Rect2(w - 700, 10, 684, BAND - 20), "", func(): app._navigate("Club"), "OfficeTerritoryOpen", 20)
		ouvrir.tooltip_text = "Ouvrir l'écran Club"
		ouvrir.accessibility_name = "Ouvrir l'écran Club"
	var signature: Color = Charte.club_trait(app.accent)
	D.rect(card, Rect2(0, 0, 5, FIXTURE_H), signature)
	var body := Control.new()
	body.name = "OfficeFixtureBody"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(body)
	D.place(body, Rect2(0, BAND, w, FIXTURE_H - BAND))
	var match_info := Office.live_match(app.model)
	if not match_info.is_empty():
		_live_content(body, app, match_info)
		return
	var next: Dictionary = app.model.next if app.model.get("next") is Dictionary else {}
	if next.is_empty():
		_sans_prochain(card, body, app)
		return
	_prochain(card, app, next, w)

## Rencontre à venir : bandeau (caption + compte à rebours), clubs, date, lieu, feuille, face-à-face, actions.
static func _prochain(card: Panel, app: Control, next: Dictionary, w: int) -> void:
	var match_label := str(next.get("label", P.league_name(app.model)))
	var competition := Office.fixture_stage(app.model, next, match_label)
	var location := "NEUTRE" if next.get("neutral", false) else "DOMICILE" if next.get("home", {}).get("id") == app.model.club.id else "EXTÉRIEUR"
	var caption := D.text(card, 28, 62, "PROCHAIN MATCH · %s · %s" % [competition.to_upper(), location], 20, Charte.IVOIRE, 700, w - 780)
	caption.name = "OfficeFixtureCaption"
	Office.describe_fixture(caption, match_label + " · " + location)
	var reste := compte_a_rebours(app, next)
	if not reste.is_empty(): _ex(D.text(card, 28, 104, reste, 34, Charte.IVOIRE, 800, w - 780)).name = "OfficeFixtureCountdown"
	if P.is_derby(app.model): D.derby_chip(card, Rect2(minf(28 + _largeur(caption.text, 20, C.font(700)) + 18, w - 900), 38, 98, 29))
	var home: Dictionary = next.get("home", {})
	var away: Dictionary = next.get("away", {})
	var demi := w / 2.0
	var y0 := BAND + 16
	for cote in 2:
		var club: Dictionary = home if cote == 0 else away
		var x0 := 28.0 if cote == 0 else demi + 40.0
		var base := y0 + 52
		_crest(card, club, Rect2(x0, y0, 64, 64))
		Office.reading_overlay(app, card, Rect2(x0, y0, 64, 64), Office.club_reading_target(app, club), "OfficeNext%sClubCrest" % ["Home" if cote == 0 else "Away"], G.club_name(club))
		var nom := _ex(D.text(card, x0 + 84, base, G.club_name(club).to_upper(), 44, Charte.IVOIRE, 800, demi - 160))
		_label_reading(app, card, nom, Office.club_reading_target(app, club), "OfficeNext%sClubName" % ["Home" if cote == 0 else "Away"], nom.text)
		if club.has("rank") and club.has("points"):
			var rang := G.n(club.rank)
			var texte := "%s%s · %s pts" % [rang, "er" if rang == "1" else "e", G.n(club.points)] if P.standings_open(club) else "Pas encore classé · %s pts" % G.n(club.points)
			D.text(card, x0 + 84, base + 28, texte, 20, Charte.club_texte(app.accent) if club.get("id") == app.model.club.id else Charte.IVOIRE_2, 600, demi - 160)
	D.text(card, demi, y0 + 46, "CONTRE", 20, Charte.IVOIRE_2, 700, 120, HORIZONTAL_ALIGNMENT_CENTER)
	# Colonne de gauche : quand, où, feuille, actions.
	var y := y0 + 90
	var calendrier := C.icon("calendar", 25, Charte.IVOIRE_2)
	card.add_child(calendrier)
	D.place(calendrier, Rect2(28, y + 4, 25, 25))
	var date := P.fixture_date(next, true)
	if date.is_empty(): date = "SEMAINE %d" % [int(next.get("week", 0)) + 1]
	var quand := D.text(card, 66, y + 26, date + " · " + Office.fixture_competition(app.model, next), 21, Charte.IVOIRE, 600, 740, HORIZONTAL_ALIGNMENT_LEFT, true)
	quand.name = "OfficeFixtureDate"
	_label_reading(app, card, quand, Office.date_reading_target(app, next), "OfficeNextDate", quand.text)
	var terrain := P.fixture_venue(next, false)
	if not terrain.is_empty():
		var maison := C.icon("home", 23, Charte.IVOIRE_2)
		card.add_child(maison)
		D.place(maison, Rect2(29, y + 40, 23, 23))
		D.text(card, 66, y + 60, terrain, 21, Charte.IVOIRE_2, 500, 640, HORIZONTAL_ALIGNMENT_LEFT, true).name = "OfficeFixtureVenue"
	var valide: bool = app.model.get("selection", {}).get("valid", false)
	D.text(card, 28, y + 98, "Feuille complète" if valide else "Feuille à préparer", 21, Charte.V if valide else Charte.IVOIRE, 700, 330)
	_principal(card, Rect2(28, y + 118, 340, 54), "PRÉPARER LE MATCH", func(): app._navigate("Préparation"), "OfficePreparationAction", app.accent)
	_lien(card, 392, y + 129, "Vérifier les 23 →", func(): app._navigate("Composition"), "OfficeSelectionAction", 21)
	_face_a_face(card, app, home, away, Rect2(demi + 40, y - 8, demi - 68, 190))

## Face-à-face chiffré (emprunt à la variante 3) : une ligne par donnée connue des deux clubs, jamais inventée.
static func _face_a_face(card: Control, app: Control, home: Dictionary, away: Dictionary, zone: Rect2) -> void:
	var lignes: Array = []
	var rows: Array[Dictionary] = [_ligne_club(app.model, home.get("id")), _ligne_club(app.model, away.get("id"))]
	var equipes: Array[Dictionary] = [home, away]
	var rang: Array[String] = ["", ""]
	for i in 2:
		var equipe: Dictionary = equipes[i]
		var ligne: Dictionary = rows[i]
		var source: Dictionary = equipe if equipe.has("rank") and equipe.has("points") else ligne
		if source.has("rank") and source.has("points"):
			var r := G.n(source.rank)
			rang[i] = "%s%s · %s pts" % [r, "er" if r == "1" else "e", G.n(source.points)] if P.standings_open(source) else "Pas encore classé"
	if not rang[0].is_empty() and not rang[1].is_empty(): lignes.append(["Classement", rang[0], rang[1]])
	if rows.all(func(r: Dictionary): return r.get("form") is Array and not r.form.is_empty()): lignes.append(["5 derniers", rows[0].form, rows[1].form])
	if rows.all(func(r: Dictionary): return r.has("won") and r.has("drawn") and r.has("lost") and int(r.get("played", 0)) > 0):
		lignes.append(["Bilan", "%sV · %sN · %sD" % [G.n(rows[0].won), G.n(rows[0].drawn), G.n(rows[0].lost)], "%sV · %sN · %sD" % [G.n(rows[1].won), G.n(rows[1].drawn), G.n(rows[1].lost)]])
	if rows.all(func(r: Dictionary): return r.has("pf") and r.has("pa") and int(r.get("played", 0)) > 0):
		lignes.append(["Différence de points", "%+d" % (int(rows[0].pf) - int(rows[0].pa)), "%+d" % (int(rows[1].pf) - int(rows[1].pa))])
	var panneau := D.rect(card, zone, Color(Charte.PANNEAU_2, .0))
	panneau.name = "OfficeFaceAFace"
	var l := zone.size.x
	var tete_g := D.text(card, zone.position.x, zone.position.y + 16, G.club_name(home).to_upper(), 17, Charte.IVOIRE_2, 700, l * .36)
	Office.reading_overlay(app, card, Rect2(tete_g.position.x / C.density, tete_g.position.y / C.density - 6, tete_g.size.x / C.density, 32), Office.club_reading_target(app, home), "OfficeFaceHomeClub", tete_g.text)
	D.text(card, zone.position.x + l / 2.0, zone.position.y + 16, "FACE À FACE", 17, Charte.IVOIRE, 700, l * .28, HORIZONTAL_ALIGNMENT_CENTER)
	var tete_d := D.text(card, zone.position.x + l, zone.position.y + 16, G.club_name(away).to_upper(), 17, Charte.IVOIRE_2, 700, l * .36, HORIZONTAL_ALIGNMENT_RIGHT)
	Office.reading_overlay(app, card, Rect2(tete_d.position.x / C.density, tete_d.position.y / C.density - 6, tete_d.size.x / C.density, 32), Office.club_reading_target(app, away), "OfficeFaceAwayClub", tete_d.text)
	if lignes.is_empty():
		D.text(card, zone.position.x + l / 2.0, zone.position.y + 70, "Début de saison : aucun match joué.", 20, Charte.IVOIRE_2, 500, l, HORIZONTAL_ALIGNMENT_CENTER, true)
		return
	for i in lignes.size():
		var ligne: Array = lignes[i]
		var y := zone.position.y + 28 + i * 38
		if i > 0: D.line(card, Vector2(zone.position.x - 8, y), Vector2(zone.position.x + l + 8, y), Charte.FILET)
		# La ligne « Classement » ouvre le classement complet ; les autres lignes sont des chiffres lus.
		if str(ligne[0]) == "Classement":
			var vers := _zone(card, Rect2(zone.position.x - 8, y, l + 16, 36), "", func(): Office.open_current_standings(app), "OfficeFaceClassement", 20)
			vers.tooltip_text = "Ouvrir le classement complet"
			vers.accessibility_name = "Ouvrir le classement complet"
		D.text(card, zone.position.x + l / 2.0, y + 25, str(ligne[0]), 18, Charte.IVOIRE_2, 500, l * .34, HORIZONTAL_ALIGNMENT_CENTER, true)
		for cote in 2:
			var valeur: Variant = ligne[1 + cote]
			var gauche: bool = cote == 0
			if valeur is Array:
				_forme(card, zone.position.x if gauche else zone.position.x + l, y + 6, valeur, not gauche)
			else:
				D.text(card, zone.position.x if gauche else zone.position.x + l, y + 25, str(valeur), 21, Charte.IVOIRE, 600, l * .34, HORIZONTAL_ALIGNMENT_LEFT if gauche else HORIZONTAL_ALIGNMENT_RIGHT, true)

## États sans « prochain match » (semaine exempte, préparation, intersaison) : texte sous le bandeau.
static func _sans_prochain(card: Panel, body: Control, app: Control) -> void:
	var japan := SeasonPreparation.is_japan(app.model.meta)
	var preparation := SeasonPreparation.data(app.model.meta)
	var upcoming := P.next_nationale_fixture(app.model)
	var scheduled := P.next_scheduled_fixture(app.model)
	if not upcoming.is_empty():
		D.chip(body, Rect2(24, 22, 281, 29), "SEMAINE EXEMPTE", Charte.IVOIRE)
		var opponent := D.text(body, 27, 121, Office.scheduled_opponent(app, upcoming), 51, Charte.IVOIRE, 800, 645)
		opponent.name = "UpcomingOpponent"
		var timing := D.text(body, 27, 183, "Prochain match · " + Office.scheduled_when(app, upcoming), 27, Charte.IVOIRE, 600, 645)
		timing.name = "UpcomingWhen"
		_scheduled_reading(app, body, upcoming, opponent, timing)
		var venue := Office.scheduled_venue(app, upcoming)
		if not venue.is_empty(): D.text(body, 27, 223, "Lieu · " + venue, 21, Charte.IVOIRE_2, 400, 645, HORIZONTAL_ALIGNMENT_LEFT, true)
	elif preparation.is_empty() and not scheduled.is_empty():
		D.text(body, 27, 45, "PROCHAINE RENCONTRE", 22, Charte.IVOIRE, 700, 640)
		var opponent := D.text(body, 27, 115, Office.scheduled_opponent(app, scheduled), 48, Charte.IVOIRE, 800, 645)
		var timing := D.text(body, 27, 169, Office.scheduled_when(app, scheduled), 27, Charte.IVOIRE, 600, 645)
		_scheduled_reading(app, body, scheduled, opponent, timing)
		D.text(body, 27, 210, P.fixture_venue(scheduled), 22, Charte.IVOIRE_2, 400, 645, HORIZONTAL_ALIGNMENT_LEFT, true)
	elif preparation.is_empty():
		D.text(body, 27, 100, "La saison se termine." if app.model.meta.get("canAdvanceSeason", false) else "Le travail continue.", 42, Charte.IVOIRE, 700, 740)
		D.text(body, 27, 156, "Retrouve les résultats et prépare la suite du projet.", 21, Charte.IVOIRE_2, 400, 740, HORIZONTAL_ALIGNMENT_LEFT, true)
	elif SeasonPreparation.is_champ(app.model.meta):
		var fixture := P.next_scheduled_fixture(app.model)
		D.chip(body, Rect2(24, 22, 210, 29), "PRÉPARATION", Charte.IVOIRE)
		if fixture.is_empty():
			D.text(body, 27, 121, "Préparation · " + World.name_for(app.model, "champ"), 58, Charte.IVOIRE, 800, 920)
			D.text(body, 27, 183, World.preparation_note(preparation), 30, Charte.IVOIRE, 600, 720)
		else:
			var opponent := D.text(body, 27, 121, Office.scheduled_opponent(app, fixture), 51, Charte.IVOIRE, 800, 645)
			opponent.name = "UpcomingOpponent"
			var timing := D.text(body, 27, 183, Office.scheduled_when(app, fixture), 27, Charte.IVOIRE, 600, 645)
			timing.name = "UpcomingWhen"
			_scheduled_reading(app, body, fixture, opponent, timing)
			var venue := Office.scheduled_venue(app, fixture)
			if not venue.is_empty(): D.text(body, 27, 223, "Lieu · " + venue, 21, Charte.IVOIRE_2, 400, 645, HORIZONTAL_ALIGNMENT_LEFT, true)
	else:
		D.chip(body, Rect2(24, 22, 322 if japan else 281, 29), World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))).to_upper(), Charte.IVOIRE)
		D.text(body, 27, 121, "Préparation · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))), 58, Charte.IVOIRE, 800, 920)
		D.text(body, 27, 183, World.preparation_note(preparation), 30, Charte.IVOIRE, 600, 720)
		D.text(body, 27, 223, "Avance de quatre semaines au plus, jusqu’à la prochaine rencontre.", 21, Charte.IVOIRE_2, 400, 735, HORIZONTAL_ALIGNMENT_LEFT, true)
	_principal(body, Rect2(27, 244, 420, 54), app.primary_text().trim_suffix("  →"), app.primary_action, "OfficePreparationAction", app.accent)

static func _live_content(body: Control, app: Control, match_info: Dictionary) -> void:
	D.text(body, 27, 28, match_info.heading, 22, Charte.IVOIRE, 700, 400).name = "OfficeLiveHeading"
	if not match_info.location.is_empty():
		D.chip(body, Rect2(300, 8, 176, 29), match_info.location, Charte.IVOIRE_2)
	var teams: Array = match_info.teams
	for i in teams.size():
		var team: Dictionary = teams[i]
		var y := 40 + 64 * i
		_crest(body, team, Rect2(27, y, 54, 54))
		D.text(body, 99, y + 38, G.club_name(team), 36, Charte.IVOIRE, 800, 548)
	D.text(body, 27, 200, match_info.score, 40, Charte.IVOIRE, 800, 158).name = "OfficeLiveScore"
	D.text(body, 188, 198, match_info.state, 24, Charte.IVOIRE, 650, 490).name = "OfficeLiveState"
	if not match_info.detail.is_empty():
		D.text(body, 27, 232, match_info.detail, 21, Charte.IVOIRE_2, 400, 638, HORIZONTAL_ALIGNMENT_LEFT, true).name = "OfficeLiveFixtureDetail"
	_principal(body, Rect2(27, 244, 358, 54), app.primary_text().trim_suffix("  →"), app.primary_action, "OfficePreparationAction", app.accent)
	var review := _lien(body, 410, 255, "Revoir le match →", func(): app._navigate("Match"), "OfficeMatchReviewAction", 21)
	review.visible = match_info.finished

# ---------------------------------------------------------------------------------------------------------
# Priorités
# ---------------------------------------------------------------------------------------------------------

static func _priorities(card: Panel, app: Control, w: int = 900) -> void:
	_objectif(card, app, w)
	var tasks := Office.priorities(app.model)
	if tasks.is_empty(): D.text(card, 26, 130, "Reprends une carrière pour retrouver les décisions du club.", 21, Charte.IVOIRE_2, 400, w - 56, HORIZONTAL_ALIGNMENT_LEFT, true)
	for i in tasks.size():
		var y := 100.0 + i * 90.0
		var item: Dictionary = tasks[i]
		# Rouge si urgent, orange si c'est pour aujourd'hui, bleu sinon (le seul doré de l'écran reste Continuer).
		var tint: Color = R.ROUGE if item.level == "urgent" else R.ORANGE if str(item.deadline) in ["Aujourd’hui", "Maintenant", "Résultat en attente"] else R.BLEU
		D.line(card, Vector2(20, y), Vector2(w - 20, y), Color(Charte.FILET, .7))
		D.rect(card, Rect2(20, y + 10, 4, 66), tint).name = "OfficePriority" + str(i + 1)
		_ex(D.text(card, 44, y + 60, str(i + 1), 46, Charte.IVOIRE, 800, 44))
		var echeance_w := _largeur(str(item.deadline), 19, C.font(600)) + 70
		var action := _zone(card, Rect2(20, y + 2, w - 40, 84), str(item.title), Office.open_priority.bind(app, item), str(item.id), 22, 66, 40)
		action.set_meta("priority_number", i + 1)
		action.set_meta("inline_number", false)
		action.tooltip_text = item.title + "\n" + Office.priority_description(item)
		action.accessibility_name = action.tooltip_text.replace("\n", " · ")
		# Échéance : pastille (icône + mot) au bord droit ; plus de phrase d'explication sous le titre (21/11) :
		# le motif reste dans l'infobulle de la ligne, un compte devient une tuile (chiffre + légende courte).
		var pastille := R.pastille(card, 0, y + 30, str(item.deadline), tint, "calendar", "OfficePriorityDeadline" + str(i + 1), 21)
		pastille.position.x = C.px(w - 40) - pastille.size.x
		var compte: Variant = item.get("count")
		var tuile_seule: bool = bool(item.get("tile_only", false)) and compte != null
		if tuile_seule:
			action.text = ""
			R.tuile(card, Rect2(92, y + 14, minf(w - 150 - echeance_w, R.largeur(G.n(compte), 40, 800) + R.largeur(str(item.get("unit", "")).to_upper(), 17) + 56), 62), G.n(compte), str(item.get("unit", "")), R.ORANGE, "OfficePriorityTile" + str(i + 1), 40, true)
		elif compte != null:
			R.tuile(card, Rect2(92, y + 44, minf(w - 150 - echeance_w, R.largeur(G.n(compte), 26, 800) + R.largeur(str(item.get("unit", "")).to_upper(), 17) + 56), 38), G.n(compte), str(item.get("unit", "")), R.ROUGE if item.id == "OfficeMedicalPriorityAction" else R.ORANGE, "OfficePriorityTile" + str(i + 1), 26, true)
		else:
			for etat in ["normal", "hover", "pressed", "focus"]:
				var style := action.get_theme_stylebox(etat) as StyleBoxFlat
				if style != null: style.content_margin_bottom = 0
		# Noms de joueurs du titre : fiche au clic, mini-fiche au survol.
		if not tuile_seule: noms_cliquables(app, card, Rect2(90, y + (10 if compte != null else 28), w - 260, 30), str(item.title), 22, C.font(700))
	var y_pied := 100.0 + 3 * 90.0 + 14.0
	# « Mon carnet personnel » (une fenêtre) n'est plus au Bureau : décision de Léo, plus de petite fenêtre ; le carnet
	# de la semaine est celui de Gabi, à droite.
	if not tasks.any(func(item: Dictionary): return item.id == "OfficeTrainingAction") and not app.model.meta.get("canAdvanceSeason", false) and app.model.meta.get("phase", "") != "ended":
		_lien(card, 24, y_pied, "Entraînement →", func(): app.Immersive.open_training(app), "OfficeTrainingAction", 20)

## « Objectif du conseil : … » sous le titre ; sans objectif : « Aucun objectif fixé ».
static func _objectif(card: Panel, app: Control, w: int) -> void:
	var statut := objective_status(app.model, P.standings(app.model))
	var texte := "Aucun objectif fixé"
	if not statut.is_empty():
		var place := "" if statut.rank == null else " · %s%s" % [G.n(statut.rank), "er" if int(statut.rank) == 1 else "e"]
		texte = "%s%s · %s" % [str(statut.label), place, statut.trend]
	var libelle := D.text(card, 24, 84, "OBJECTIF DU CONSEIL", 16, Charte.IVOIRE_2, 700, 220)
	var objectif := D.text(card, 24 + _largeur("OBJECTIF DU CONSEIL", 16, C.font(700)) + 16, 84, texte, 20, Charte.IVOIRE, 600, w - 330, HORIZONTAL_ALIGNMENT_LEFT, true)
	objectif.name = "OfficeBoardObjective"
	libelle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not statut.is_empty(): objectif.tooltip_text = "Objectif du conseil : %s (place visée : %d)" % [str(statut.label), int(statut.target)]

# ---------------------------------------------------------------------------------------------------------
# État du groupe
# ---------------------------------------------------------------------------------------------------------

static func _group(card: Panel, app: Control, w: int = 580) -> void:
	var group := P.group(app.model)
	var right := w - 24
	var disponibles := _zone(card, Rect2(16, 66, 220, 70), "", app.navigation_controller.open_roster_group, "OfficeGroupAvailable", 20)
	disponibles.tooltip_text = "Voir les %s joueurs disponibles" % G.n(group.available)
	D.text(card, 24, 118, group.available, 52, Charte.V, 800, 90)
	D.text(card, 24 + _largeur(G.n(group.available), 52, C.font(800)) + 14, 116, "disponibles", 21, Charte.IVOIRE, 600, 130)
	var vers_blesses := func():
		if app.navigation_controller.has_method("open_roster_injured"): app.navigation_controller.open_roster_injured()
		else: app.navigation_controller.open_roster_group()
	var blesses := _zone(card, Rect2(250, 66, 220, 70), "", vers_blesses, "OfficeGroupInjured", 20)
	blesses.tooltip_text = "Voir les %s joueurs blessés" % G.n(group.injured)
	D.text(card, 258, 118, "! " + G.n(group.injured) if int(group.injured) > 0 else G.n(group.injured), 52, R.ROUGE if int(group.injured) > 0 else Charte.IVOIRE_2, 800, 100)
	D.text(card, 258 + _largeur("! " + G.n(group.injured), 52, C.font(800)) + 14, 116, "blessés", 21, Charte.IVOIRE, 600, 110)
	var fatigue := Avis.fatigue_resume(app.model)
	var titulaires := int(fatigue.count)
	var jauges: Array = [
		["CONDITION PHYSIQUE", float(group.condition), "%d %%" % int(group.condition), Charte.V, float(fatigue.seuil)],
		["MORAL DU VESTIAIRE", float(app.model.meta.get("morale", 0)), "%d / 100" % int(float(app.model.meta.get("morale", 0))), Charte.IVOIRE_2, -1.0],
		["CONFIANCE DU CONSEIL", float(app.model.meta.get("trust", 0)), "%d / 100" % int(float(app.model.meta.get("trust", 0))), Charte.IVOIRE_2, -1.0],
	]
	for i in jauges.size():
		var jauge: Array = jauges[i]
		var y := 150.0 + i * 46.0
		D.text(card, 24, y, jauge[0], 16, Charte.IVOIRE_2, 700, 260)
		if float(jauge[4]) >= 0.0: D.text(card, right - 100, y, "SEUIL %d" % int(jauge[4]), 16, Charte.IVOIRE_2, 700, 130, HORIZONTAL_ALIGNMENT_RIGHT)
		D.text(card, right, y + 4, str(jauge[2]), 21, Charte.IVOIRE, 600, 110, HORIZONTAL_ALIGNMENT_RIGHT)
		D.bar(card, Rect2(24, y + 12, right - 24 - 130, 8), float(jauge[1]), jauge[3])
		if float(jauge[4]) >= 0.0: D.rect(card, Rect2(24 + (right - 24 - 130) * float(jauge[4]) / 100.0, y + 8, 2, 16), Charte.IVOIRE)
		# Condition → groupe, moral → vestiaire ; mini-courbe au survol (relevé hebdomadaire du moteur).
		if i < 2:
			var vers: Callable = app.navigation_controller.open_roster_group if i == 0 else func(): app._navigate("Vestiaire")
			var zone := _zone(card, Rect2(16, y - 14, right - 8, 36), "", vers, ["OfficeGroupCondition", "OfficeGroupMorale"][i], 16)
			zone.accessibility_name = "%s · %s" % [str(jauge[0]).capitalize(), str(jauge[2])]
			preload("res://ui/mini_courbe_survol.gd").lier(app, zone, ["condition", "morale"][i], ["Condition du groupe", "Moral du vestiaire"][i])
	# Alertes en pastilles cliquables (21/11) : « ⚠ 8 < 70 % » (titulaires fatigués → composition) et « ⚑ 15 »
	# (joueurs sous surveillance → effectif filtré) ; la phrase reste dans l'infobulle.
	var y_alerte := 296.0
	var x_pastille := 24.0
	if titulaires > 0:
		var texte_fatigue := "%d titulaire%s du prochain match sous %d %%" % [titulaires, "s" if titulaires > 1 else "", int(fatigue.seuil)]
		x_pastille += _pastille_action(card, x_pastille, 290, "%d < %d %%" % [titulaires, int(fatigue.seuil)], R.ORANGE, "warning", func(): app._navigate("Composition"), "OfficeFatigueAction", texte_fatigue + " · ouvrir la composition") + 12
		y_alerte = 336.0
	if group.watched > 0:
		_pastille_action(card, x_pastille, 290, G.n(group.watched), R.ORANGE, "flag", app.navigation_controller.open_watched_roster, "OfficeWatchedAction", U.watch_caption(group.watched))
		y_alerte = 336.0
	var avec_blesses := _blesses(card, app, y_alerte, w)
	if group.watched > 0 and not avec_blesses:
		for player: Dictionary in app.model.get("squad", []):
			var reason := U.watch_reason(player)
			if reason.is_empty(): continue
			var exemple := D.text(card, 25, 350, str(player.name) + " · " + reason, 19, Charte.IVOIRE_2, 500, w - 52)
			exemple.tooltip_text = exemple.text
			var lien_exemple := _label_reading(app, card, exemple, {"kind": "player", "id": str(player.id)}, "OfficeWatchedPlayer_" + str(player.id).validate_node_name(), str(player.name))
			if lien_exemple != null: MiniFiche.lier(app, lien_exemple, str(player.id), "squad")
			break
	elif titulaires <= 0 and int(group.injured) <= 0:
		D.text(card, 25, 330, "Aucune alerte physique", 21, Charte.V, 600, w - 52).name = "OfficeNoAlert"
	_lien(card, 20, ROW2_H - 44, "Consulter le groupe →", app.navigation_controller.open_roster_group, "OfficeSquadAction", 21)

## Blessés : « ! Blessés : nom, nom » ; chaque nom ouvre la fiche (mini-fiche au survol). Rien sans blessé.
static func _blesses(card: Panel, app: Control, baseline: float, w: int) -> bool:
	var noms: Array[Dictionary] = []
	for player: Dictionary in app.model.get("squad", []):
		if float(player.get("injury", 0)) > 0 and not str(player.get("id", "")).is_empty(): noms.append(player)
	if noms.is_empty(): return false
	var x := 25.0
	var entete := D.text(card, x, baseline, "! Blessés :", 20, R.ROUGE, 700, 130)
	entete.name = "OfficeInjuredHeading"
	x += 112
	for player: Dictionary in noms.slice(0, 2):
		var nom := str(player.get("name", ""))
		var largeur := _largeur(nom, 20) + 14
		if x + largeur > w - 24: break
		var lien := Link.styled_button(card, Rect2(x, baseline - 24, largeur, maxf(30, C.reach(30))), nom, 20, Charte.IVOIRE, "OfficeInjured_" + str(player.id).validate_node_name())
		lien.add_theme_font_override("font", Charte.texte_moyen())
		var cible := {"kind": "player", "id": str(player.id)}
		if app.navigation_controller.entity_available(cible):
			lien.pressed.connect(func(): app.navigation_controller.open_entity(cible))
			MiniFiche.lier(app, lien, str(player.id), "squad")
		x += largeur + 8
	if noms.size() > 2:
		var reste := "+%d blessé%s →" % [noms.size() - 2, "s" if noms.size() > 3 else ""]
		var plus := _lien(card, x, baseline - 24, reste, func():
			if app.navigation_controller.has_method("open_roster_injured"): app.navigation_controller.open_roster_injured()
			else: app.navigation_controller.open_roster_group(), "OfficeInjuredMore", 20)
		plus.tooltip_text = "Voir tous les joueurs blessés"
	return true

## Pastille d'alerte cliquable (contour fin = cliquable) ; renvoie sa largeur (gabarit).
static func _pastille_action(card: Panel, x: float, baseline: float, texte: String, couleur: Color, icone: String, action: Callable, id: String, aide: String) -> float:
	var fond := R.pastille(card, x, baseline, texte, couleur, icone, id + "Texte", 20)
	var style := (fond.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.border_color = Color(couleur, .55)
	style.set_border_width_all(1)
	fond.add_theme_stylebox_override("panel", style)
	var zone := Rect2(fond.position / C.density, fond.size / C.density)
	var bouton := _zone(card, zone, "", action, id, 20)
	bouton.tooltip_text = aide
	bouton.accessibility_name = aide
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return zone.size.x

# ---------------------------------------------------------------------------------------------------------
# Classement court
# ---------------------------------------------------------------------------------------------------------

static func _standings(card: Panel, app: Control, w: int = 1100) -> void:
	var large := w >= 900
	var rows := short_rows(P.standings(app.model), app.model.club.get("id"), STANDINGS_ROWS if large else 6)
	var zones := Zones.visible(rows)
	var stride := 34
	var rank_x := 72 if not zones.is_empty() else 44
	var name_x := rank_x + 46
	var forme_w := 190 if large else 0
	var pts_x := w - 28 - forme_w - (20 if large else 0)
	var diff_x := pts_x - 90
	var vnd_x := diff_x - 140
	var played_x := vnd_x - 100 if large else diff_x - 110
	_lien(card, w - 20, 14, "Classement complet →", func(): app._navigate("Classements"), "OfficeStandingsAction", 20, true)
	var entetes: Array = [["RG", rank_x, HORIZONTAL_ALIGNMENT_CENTER], ["CLUB", name_x, HORIZONTAL_ALIGNMENT_LEFT], ["J", played_x, HORIZONTAL_ALIGNMENT_CENTER], ["DIFF.", diff_x, HORIZONTAL_ALIGNMENT_RIGHT], ["PTS", pts_x, HORIZONTAL_ALIGNMENT_RIGHT]]
	if large:
		entetes.append(["V-N-D", vnd_x, HORIZONTAL_ALIGNMENT_CENTER])
		entetes.append(["FORME", w - 28 - forme_w, HORIZONTAL_ALIGNMENT_LEFT])
	for entete: Array in entetes: D.text(card, entete[1], 90, entete[0], 16, Charte.IVOIRE_2, 700, 90, entete[2])
	for i in rows.size():
		var club: Dictionary = rows[i]
		var y := 100 + i * stride
		var own: bool = club.get("id") == app.model.club.id
		var box := Rect2(16, y, w - 32, stride)
		if i > 0 and not own and not (i > 0 and rows[i - 1].get("id") == app.model.club.id): D.line(card, Vector2(16, y), Vector2(w - 16, y), Charte.FILET)
		if own: D.rect(card, box, Charte.SELECTION, 8)  # 8 en référence 2560 = 6 px à 1920
		var hit := Office.standing_action(app, club)
		card.add_child(hit)
		D.place(hit, box)
		var zone := Zones.of(club)
		if not zone.is_empty():
			var kind := str(zone.get("kind", ""))
			var edge := D.rect(hit, Rect2(0, 3, 4, stride - 6), Zones.tint(kind))
			edge.name = "StandingsZoneEdge"
			var side := Zones.mark_side(Zones.BUREAU_MARK_PX)
			Zones.mark(hit, kind, Rect2(10, (stride - side) / 2.0, side, side), Zones.tint(kind))
		elif own:
			D.rect(hit, Rect2(0, 3, 4, stride - 6), Charte.club_trait(app.accent))
		var base := y + stride - 10
		var ouvert := P.standings_open(club)
		D.text(card, rank_x, base, G.n(club.get("rank", "—")) if ouvert else "–", 21, Charte.IVOIRE, 700, 40, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(card, name_x, base, G.club_name(club), 21, Charte.club_texte(app.accent) if own else Charte.IVOIRE, 700 if own else 600, played_x - name_x - 40)
		D.text(card, played_x, base, G.n(club.get("played", 0)), 21, Charte.IVOIRE_2, 500, 40, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(card, diff_x, base, "%+d" % (int(club.get("pf", 0)) - int(club.get("pa", 0))), 21, Charte.IVOIRE_2, 500, 80, HORIZONTAL_ALIGNMENT_RIGHT)
		D.text(card, pts_x, base, G.n(club.get("points", 0)), 22, Charte.IVOIRE, 700, 70, HORIZONTAL_ALIGNMENT_RIGHT)
		if large:
			if club.has("won"): D.text(card, vnd_x, base, "%s-%s-%s" % [G.n(club.get("won", 0)), G.n(club.get("drawn", 0)), G.n(club.get("lost", 0))], 21, Charte.IVOIRE_2, 500, 110, HORIZONTAL_ALIGNMENT_CENTER)
			var forme: Variant = club.get("form", [])
			if forme is Array: _forme(card, w - 28 - forme_w, y + 5, forme)
	var bas := 100 + rows.size() * stride
	if not zones.is_empty(): _zone_legend(card, zones, _zone_note(app.model), 26, bas + 22, w - 52)
	if rows.is_empty() or not P.standings_open(rows[0]) and rows.all(func(r: Dictionary): return not P.standings_open(r)):
		D.text(card, 26, bas + 30, "Début de saison : aucun match joué.", 20, Charte.IVOIRE_2, 500, w - 52, HORIZONTAL_ALIGNMENT_LEFT, true)

## Note du règlement de la ligue du club (« Pas de relégation cette saison. »), vide sinon.
static func _zone_note(model: Dictionary) -> String: return Zones.bureau_note(model)  # note courte, sinon complète si elle tient

## Légende courte, limitée aux zones de l'extrait : « ★ Demi-finale directe · ▼ Relégation » (symboles dessinés),
## puis la note du règlement seulement si elle tient sur la même ligne.
static func _zone_legend(card: Panel, zones: Array, note: String, x: float, baseline: float, width: float) -> Control:
	var group := Control.new()
	group.name = "StandingsZoneLegend"
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(group)
	D.place(group, Rect2(x, baseline - 18, width, 24))
	var cursor := 0.0
	var side := Zones.mark_side(Zones.BUREAU_MARK_PX)
	for i in zones.size():
		var kind := str(zones[i].get("kind", ""))
		if i > 0:
			D.text(group, cursor + 10, 18, "·", 18, Charte.IVOIRE_2, 600, 20, HORIZONTAL_ALIGNMENT_CENTER)
			cursor += 20
		var mark := Zones.mark(group, kind, Rect2(cursor, 19 - side, side, side), Zones.tint(kind))
		mark.name = "StandingsZoneLegendMark_" + kind
		var label := D.text(group, cursor + side + 5, 18, Zones.short_label(zones[i]), 18, Charte.IVOIRE, 600)
		label.name = "StandingsZoneLegendItem_%d" % i
		label.set_meta("zone_kind", kind)
		cursor += side + 5 + label.size.x / C.density
	var spoken := Zones.legend_text(zones)
	if not note.is_empty():
		var room := width - cursor - 20
		if C.font(500).get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(18))).x / C.density <= room:
			var written := D.text(group, cursor + 20, 18, note, 18, Charte.IVOIRE_2, 500)
			written.name = "StandingsZoneNote"
			spoken += ". " + note
	group.set_meta("legend_text", spoken)
	group.accessibility_name = "Zones du classement : " + spoken
	group.tooltip_text = group.accessibility_name
	return group

## Objectif du conseil : place visée, place actuelle et tendance.
## Jalon « place au classement » de la direction s'il existe, sinon l'objectif sportif du club (« Top 6 », « Maintien »…).
static func objective_status(model: Dictionary, rows: Array) -> Dictionary:
	var club: Dictionary = model.get("club", {})
	var size := rows.size()
	for league in model.get("leagues", []):
		if league is Dictionary and league.get("id") == model.get("meta", {}).get("leagueId"): size = maxi(size, league.get("rows", []).size())
	var target := 0
	var label := ""
	var strategy: Variant = model.get("clubLife", {}).get("clubStrategy", {})
	var board: Dictionary = strategy.get("board", {}) if strategy is Dictionary and strategy.get("board") is Dictionary else {}
	for goal in board.get("objectives", []):
		if goal is Dictionary and str(goal.get("type", "")) == "rank" and str(goal.get("status", "pending")) == "pending" and goal.get("target") != null:
			target = int(goal.get("target"))
			label = "Top %d" % target if target > 1 else "Titre"
			break
	if target <= 0:
		var text := str(club.get("goal", "")).strip_edges()
		var lower := text.to_lower()
		if lower.begins_with("top "): target = int(text.substr(4))
		elif lower.contains("titre"): target = 2
		elif lower.contains("maintien") and size > 2: target = size - 2
		label = "Titre" if lower.contains("titre") else text
	if target <= 0 or size == 0: return {}
	var rank: Variant = null
	for row: Dictionary in rows:
		if row.get("id") == club.get("id") and P.standings_open(row): rank = row.get("rank")
	if rank == null: return {"label": label, "target": target, "rank": null, "trend": "à lancer", "tone": "muted"}
	var delta := target - int(rank)
	var trend := "en avance" if delta >= 2 else "dans l’objectif" if delta >= 0 else "à portée" if delta >= -2 else "en retard"
	return {"label": label, "target": target, "rank": int(rank), "trend": trend, "tone": "good" if delta >= 0 else "warn" if delta >= -2 else "bad"}

# ---------------------------------------------------------------------------------------------------------
# Courrier
# ---------------------------------------------------------------------------------------------------------

## Identifiant du message dans la Réception (même calcul que reception_canvas : empreinte + numéro d'occurrence,
## les exemplaires identiques comptés du plus ancien au plus récent).
static func message_ids(messages: Array) -> Array[String]:
	var ids: Array[String] = []
	ids.resize(messages.size())
	var occurrences := {}
	for index in range(messages.size() - 1, -1, -1):
		var texte := str(messages[index])
		occurrences[texte] = int(occurrences.get(texte, 0)) + 1
		ids[index] = texte.sha256_text() + "-" + str(occurrences[texte])
	return ids

static func open_message(app: Control, id: String) -> void:
	if not app.management_ui.has("reception"):
		app.management_ui.reception = {"folder": 0, "category": "Tous", "selected": "", "oldest_first": false, "marks": {}, "scroll": 0}
	app.management_ui.reception.selected = id
	app._navigate("Réception")

static func _journal(card: Panel, app: Control, w: int = 1132) -> void:
	_lien(card, w - 20, 14, "Réception →", func(): app._navigate("Réception"), "OfficeInboxAction", 20, true)
	var messages: Array = app.model.get("messages", [])
	if messages.is_empty():
		D.text(card, 26, 110, "Le journal s’ouvrira avec ta carrière.", 21, Charte.IVOIRE_2, 400, w - 52, HORIZONTAL_ALIGNMENT_LEFT, true)
		return
	var ids := message_ids(messages)
	# « n non lus » : même lecture que la Réception (marques « lu » de l'état de la boîte).
	var marques: Dictionary = app.management_ui.get("reception", {}).get("marks", {}) if app.management_ui.get("reception") is Dictionary else {}
	var non_lus := 0
	for id in ids:
		if not marques.get(id, {}).get("read", false): non_lus += 1
	var etiquette := D.text(card, 24 + _largeur("COURRIER", 26, C.font(800)) + 22, 38, "%d non lu%s" % [non_lus, "s" if non_lus > 1 else ""], 20, Charte.IVOIRE_2, 500, 200, HORIZONTAL_ALIGNMENT_LEFT, true)
	etiquette.name = "OfficeJournalUnread"
	var reception: Script = load("res://ui/immersive08/reception_canvas.gd")
	var avec_categorie: bool = reception != null and reception.has_method("_category")
	if avec_categorie: D.text(card, 26, 84, "SUJET", 16, Charte.IVOIRE_2, 700, 160)
	var x_titre := 230.0 if avec_categorie else 26.0
	D.text(card, x_titre, 84, "TITRE", 16, Charte.IVOIRE_2, 700, 160)
	for i in mini(4, messages.size()):
		var y := 94 + i * 46
		var message := Copy.news(str(messages[i])).replace("l’onglet Contrats", "les fiches joueurs")
		var titre := message.get_slice("\n", 0).get_slice(". ", 0).strip_edges()
		if titre.length() > 92: titre = titre.left(89).strip_edges() + "…"
		if i > 0: D.line(card, Vector2(16, y), Vector2(w - 16, y), Charte.FILET)
		var ligne := _zone(card, Rect2(16, y, w - 32, 44), "", open_message.bind(app, ids[i]), "OfficeJournalMessage" + str(i + 1), 21)
		ligne.tooltip_text = "Ouvrir la lettre · " + titre
		ligne.accessibility_name = ligne.tooltip_text
		# Les lettres « XV de la journée / de la saison » portent la vignette du XV : un clic ouvre l'écran XV type.
		var vignette := _vignette_xv(app, str(messages[i]), Rect2(w - 92, y + 2, 52, 40))
		var reserve := 60 if vignette == null else 108
		if vignette != null: card.add_child(vignette)
		if avec_categorie:
			# Catégorie du courrier : celle que la Réception attribue à la lettre (même fonction, pas de mots-clés ici).
			var categorie := str(reception._category(U.fold(message)))
			D.text(card, 26, y + 29, categorie, 20, Charte.IVOIRE_2, 500, 190, HORIZONTAL_ALIGNMENT_LEFT, true)
		# Blessure : le nom puis une pastille « ✚ 2 sem. » (la phrase complète reste dans l'infobulle de la ligne).
		var blessure := RegEx.create_from_string("^(.+?) (?:s’est blessée?|est blessée?|se blesse) .*?(\\d+) semaine").search(message.get_slice(char(10), 0))
		if blessure != null:
			var nom := blessure.get_string(1)
			D.text(card, x_titre, y + 29, nom, 21, Charte.IVOIRE, 600, w - x_titre - 200, HORIZONTAL_ALIGNMENT_LEFT, true).name = "OfficeJournalTitre" + str(i + 1)
			var marque := R.pastille(card, x_titre + minf(_largeur(nom, 21, C.BODY), w - x_titre - 200) + 16, y + 29, "✚ %s sem." % blessure.get_string(2), R.ROUGE, "", "OfficeJournalBlessure" + str(i + 1))
			var blesses := names_in(app.model, nom)
			if not blesses.is_empty() and blesses[0] is Dictionary and blesses[0].has("id"):
				var cible := {"kind": "player", "id": str(blesses[0].id)}
				if app.navigation_controller.entity_available(cible):
					R.cliquable(marque, func(): app.navigation_controller.open_entity(cible), "OfficeJournalBlessureOuvrir" + str(i + 1), "Fiche de " + nom)
			noms_cliquables(app, card, Rect2(x_titre, y + 8, w - x_titre - 200, 30), nom, 21, C.BODY)
			continue
		D.text(card, x_titre, y + 29, titre, 21, Charte.IVOIRE, 600, w - x_titre - reserve, HORIZONTAL_ALIGNMENT_LEFT, true).name = "OfficeJournalTitre" + str(i + 1)
		noms_cliquables(app, card, Rect2(x_titre, y + 8, w - x_titre - reserve, 30), titre, 21, C.BODY)

## Vignette cliquable du XV (équipe-type de la journée ou de la saison) d'une lettre du courrier ; null si la lettre n'en est pas une.
static func _vignette_xv(app: Control, message: String, zone: Rect2) -> Button:
	if not message.begins_with("XV de ") or not EquipeType.disponible(app.model): return null
	var saison := message.begins_with("XV de la saison")
	var ligues: Array = NotesMatch.bilan(app.model).get("equipeType", {}).get("ligues", [])
	var cible: Dictionary = ligues[0] if not ligues.is_empty() else {}
	var equipe: Variant = cible.get("saison" if saison else "journee")
	if not equipe is Dictionary: return null
	var vignette: Button = EquipeType.vignette(equipe, Rect2(0, 0, zone.size.x, zone.size.y), func(): EquipeType.ouvrir(app, str(cible.get("id", "")), "saison" if saison else "journee"))
	D.place(vignette, zone)
	return vignette

# ---------------------------------------------------------------------------------------------------------
# Noms de joueurs et classement court
# ---------------------------------------------------------------------------------------------------------

## Lignes du classement court : `nombre` lignes consécutives qui gardent notre club (au centre quand c'est possible).
static func short_rows(rows: Array, own_id: Variant, nombre: int) -> Array:
	if rows.size() <= nombre: return rows
	var own := 0
	for i in rows.size():
		if rows[i].get("id") == own_id: own = i
	var debut := clampi(own - (nombre - 1) / 2, 0, rows.size() - nombre)
	return rows.slice(debut, debut + nombre)

## Joueurs de l'effectif cités dans `texte` : nom complet, sinon nom de famille isolé (≥ 4 lettres, unique dans l'effectif).
## Renvoie [{id, start, end}] triés, sans chevauchement.
static func names_in(model: Dictionary, texte: String) -> Array:
	var trouves: Array = []
	var familles := {}
	var squad: Array = model.get("squad", [])
	for player: Dictionary in squad:
		var parts := str(player.get("name", "")).split(" ", false)
		if not parts.is_empty(): familles[parts[parts.size() - 1].to_lower()] = int(familles.get(parts[parts.size() - 1].to_lower(), 0)) + 1
	for player: Dictionary in squad:
		var nom := str(player.get("name", "")).strip_edges()
		if nom.is_empty() or str(player.get("id", "")).is_empty(): continue
		var debut := texte.find(nom)
		var fin := debut + nom.length()
		if debut < 0:
			var parts := nom.split(" ", false)
			var famille := parts[parts.size() - 1]
			if famille.length() < 4 or int(familles.get(famille.to_lower(), 0)) != 1: continue
			debut = -1
			var depart := 0
			while true:
				var at := texte.findn(famille, depart)
				if at < 0: break
				var avant := texte[at - 1] if at > 0 else " "
				var apres := texte[at + famille.length()] if at + famille.length() < texte.length() else " "
				if not _lettre(avant) and not _lettre(apres):
					debut = at
					break
				depart = at + 1
			if debut < 0: continue
			fin = debut + famille.length()
		trouves.append({"id": str(player.id), "start": debut, "end": fin})
	trouves.sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	var net: Array = []
	var limite := -1
	for trouve: Dictionary in trouves:
		if trouve.start >= limite:
			net.append(trouve)
			limite = trouve.end
	return net

static func _lettre(c: String) -> bool:
	return c.to_lower() != c.to_upper() or c.is_valid_int()

## Pose, sur chaque nom de joueur du texte écrit dans `zone` (unités de la page), un bouton transparent : clic = fiche
## du joueur, survol = mini-fiche. `zone` est le rectangle du texte (largeur de retour à la ligne comprise).
static func noms_cliquables(app: Control, parent: Control, zone: Rect2, texte: String, taille: int, police: Font) -> void:
	if app.get("navigation_controller") == null or not is_instance_valid(app.get("navigation_controller")): return
	var trouves := names_in(app.model, texte)
	if trouves.is_empty(): return
	var px := maxi(12, C.px(taille))
	var paragraphe := TextParagraph.new()
	paragraphe.add_string(texte, police, px)
	paragraphe.width = C.px(zone.size.x)
	paragraphe.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	for trouve: Dictionary in trouves:
		var cible := {"kind": "player", "id": str(trouve.id)}
		if not app.navigation_controller.entity_available(cible): continue
		for ligne in paragraphe.get_line_count():
			var plage := paragraphe.get_line_range(ligne)
			if int(trouve.start) < plage.x or int(trouve.end) > plage.y: continue
			var avant := police.get_string_size(texte.substr(plage.x, int(trouve.start) - plage.x), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x / C.density
			var large := police.get_string_size(texte.substr(int(trouve.start), int(trouve.end) - int(trouve.start)), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x / C.density
			var haut := paragraphe.get_line_size(ligne).y / C.density
			var hauteur := maxf(haut, C.reach(haut))
			var lien := Link.styled_button(parent, Rect2(zone.position.x + avant - 2, zone.position.y + ligne * haut, large + 4, hauteur), "", taille, Charte.IVOIRE, "OfficeNom_%s_%d" % [str(trouve.id).validate_node_name(), int(trouve.start)])
			lien.accessibility_name = "Ouvrir la fiche · " + texte.substr(int(trouve.start), int(trouve.end) - int(trouve.start))
			lien.pressed.connect(func(): app.navigation_controller.open_entity(cible))
			MiniFiche.lier(app, lien, str(trouve.id), "squad")
			break
# ---------------------------------------------------------------------------------------------------------
# Prochains matchs (colonne de Gabi ; la colonne reste la même sans Gabi)
# ---------------------------------------------------------------------------------------------------------

## Trois prochains matchs : date, adversaire (blason et nom ouvrent le club), terrain, journée ; la ligne
## ouvre l'avant-match (le prochain) ou le calendrier du jour. `recent` : gardé pour la signature historique.
static func _timeline(card: Panel, app: Control, _recent: Variant, w: int = GABI_WIDTH) -> Callable:
	_titre(card, "PROCHAINS MATCHS")
	_lien(card, w - 20, 12, "Tout le calendrier →", func(): app._navigate("Calendrier"), "OfficeCalendarAction", 20, true)
	var fixtures := Office.upcoming_matches(app.model).slice(0, 3)
	if fixtures.is_empty():
		D.text(card, 25, 100, "Aucune rencontre programmée pour le moment.", 21, Charte.IVOIRE_2, 500, w - 50, HORIZONTAL_ALIGNMENT_LEFT, true)
	for i in fixtures.size():
		var fixture: Dictionary = fixtures[i]
		var y := 62 + i * 42
		var chez_nous: bool = fixture.get("home", {}).get("id") == app.model.club.id
		var adversaire: Dictionary = fixture.get("away", {}) if chez_nous else fixture.get("home", {})
		var lieu := P.fixture_location_kind(fixture, app.model.club.id)
		var mot: String = {"neutral": "Neutre", "home": "Domicile", "away": "Extérieur"}.get(lieu, "Terrain à confirmer")
		var cle := str(fixture.get("id", fixture.get("date", ""))).validate_node_name()
		if i > 0: D.line(card, Vector2(12, y), Vector2(w - 12, y), Charte.FILET)
		var cible := {"kind": "date", "id": fixture.get("date")}
		var ligne: Callable = func():
			if i == 0 and app.model.get("next") is Dictionary and not app.model.next.is_empty(): app._navigate("Préparation")
			elif Office.reading_available(app, cible): app.navigation_controller.open_entity(cible)
			else: app._navigate("Calendrier")
		var tuile := _zone(card, Rect2(12, y, w - 24, 40), "", ligne, "OfficeTimelineTile" + str(i), 20)
		tuile.tooltip_text = ("Préparer le match · " if i == 0 else "Ouvrir le calendrier · ") + Office.timeline_period(fixture)
		tuile.accessibility_name = tuile.tooltip_text
		var date := D.text(card, 26, y + 29, Office.timeline_period(fixture), 19, Charte.IVOIRE, 600, 220)
		date.name = "OfficeTimelineDate%d" % i
		var local := P.fixture_date(fixture, true)
		if not local.is_empty(): Office.describe_fixture(date, local)
		_label_reading(app, card, date, Office.date_reading_target(app, fixture), "OfficeTimelineDateLink_" + cle, date.text)
		var ecusson := Office.opponent_crest(adversaire, 28)
		ecusson.name += str(i)
		card.add_child(ecusson)
		D.place(ecusson, Rect2(262, y + 8, 28, 28))
		Office.reading_overlay(app, card, Rect2(262, y + 8, 28, 28), Office.club_reading_target(app, adversaire), "OfficeTimelineClubCrest_" + cle, G.club_name(adversaire))
		var nom := D.text(card, 300, y + 29, G.club_name(adversaire), 20, Charte.IVOIRE, 600, w - 300 - 190)
		Office.describe_fixture(nom, nom.text + " · " + mot)
		_label_reading(app, card, nom, Office.club_reading_target(app, adversaire), "OfficeTimelineClubName_" + cle, nom.text)
		var marque := C.icon(C.fixture_location_icon(lieu, true), 22, Charte.IVOIRE_2)
		marque.name = "OfficeVenueIcon%d" % i
		card.add_child(marque)
		D.place(marque, Rect2(w - 176, y + 11, 22, 22))
		D.text(card, w - 146, y + 29, mot, 18, Charte.IVOIRE_2, 500, 90, HORIZONTAL_ALIGNMENT_LEFT, true)
		var etape := Office.short_fixture_label(app.model, fixture).get_slice(" · ", 1)
		if etape.is_empty(): etape = Office.short_fixture_label(app.model, fixture)
		D.text(card, w - 24, y + 29, etape.left(8), 18, Charte.IVOIRE_2, 500, 60, HORIZONTAL_ALIGNMENT_RIGHT, true)
	return Callable()
