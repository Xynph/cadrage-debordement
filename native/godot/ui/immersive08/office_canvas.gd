extends "res://ui/immersive08/office_rangee_basse.gd"
## Bureau (design/ux/04-bureau.md, maquette « Affiche et Gabi » du 19/11/2026, choix de Léo) : à gauche l'affiche du
## prochain match (bandeau voilé ≤ 160 px, face-à-face chiffré des deux clubs), les trois priorités et l'état du
## groupe ; à droite la colonne de Gabi (sa semaine, les prochains matchs, son buste et sa bulle) ; dessous le
## classement court, le courrier et le profil à suivre. Tout élément ouvre quelque chose (priorité, club, message,
## joueur, match, groupe). Couleurs et polices : ui/charte.gd uniquement ; l'or est réservé à Continuer.
## Découpé sans changement : préloads, constantes et aides dans office_socle.gd, puis affiche, priorités et groupe, rangée du bas (chaîne d’héritage, voir le socle) ; ici `build` et le titre de bloc.
const Socle = preload("res://ui/immersive08/office_socle.gd")
const Affiche = preload("res://ui/immersive08/office_affiche.gd")
const Groupe = preload("res://ui/immersive08/office_priorites_groupe.gd")
const Bas = preload("res://ui/immersive08/office_rangee_basse.gd")

## Points d’entrée publics (office.gd, coach_bureau.gd, tests) : redéfinis ici, car `has_method` et l’appel dynamique d’un script ne voient pas les statiques hérités.
static func message_ids(messages: Array) -> Array[String]: return Bas.message_ids(messages)
static func open_message(app: Control, id: String) -> void: Bas.open_message(app, id)
static func noms_cliquables(app: Control, parent: Control, zone: Rect2, texte: String, taille: int, police: Font) -> void: Socle.noms_cliquables(app, parent, zone, texte, taille, police)
static func short_rows(rows: Array, own_id: Variant, nombre: int) -> Array: return Socle.short_rows(rows, own_id, nombre)
static func compte_a_rebours(app: Control, fixture: Dictionary) -> String: return Affiche.compte_a_rebours(app, fixture)
static func objective_status(model: Dictionary, rows: Array) -> Dictionary: return Groupe.objective_status(model, rows)
static func _fixture(card: Panel, app: Control, w: int = 1496) -> void: Affiche._fixture(card, app, w)
static func _group(card: Panel, app: Control, w: int = 580) -> void: Groupe._group(card, app, w)
static func _standings(card: Panel, app: Control, w: int = 1100) -> void: Bas._standings(card, app, w)
static func _timeline(card: Panel, app: Control, _recent: Variant, w: int = GABI_WIDTH) -> Callable: return Bas._timeline(card, app, _recent, w)

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
