extends Control
## Socle de l'écran Compétitions : constantes, état de la page, cibles de lecture publiques (statiques) et petits outils partagés (rencontres,
## panneaux, écussons, pastilles de résultat, pagination). Chaîne de l'écran : socle ← classement ← calendrier ← colonne ← competition_canvas.gd (fichier public).
const FocusLater := preload("res://ui/focus_later.gd")
const C = preload("res://ui/immersive08/components.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const S = preload("res://ui/data_semantics.gd")
const Club = preload("res://ui/club_views.gd")
const Office = preload("res://ui/immersive08/office.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Decisions = preload("res://ui/decision_views.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const World = preload("res://ui/immersive08/world_archive.gd")
const Link = preload("res://ui/entity_link.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")
const EquipeType = preload("res://ui/equipe_type_view.gd")
const Zones = preload("res://ui/immersive08/standings_zones.gd")
const Charte = preload("res://ui/charte.gd")
const TenueClub = preload("res://ui/tenue_club.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")
const Reperes = preload("res://ui/immersive08/reperes.gd")
const WIDTH := 2248
const LEFT := 1500
const GAP := 24
const RIGHT := 724
const TOP := 150
const ROW := 32
const WARM := Charte.IVOIRE
const WIN := Charte.V
const DRAW := Charte.N
# Défaite en rouge (charte : perte), toujours avec sa lettre D (choix de Léo, 21/11/2026).
const LOSS := Charte.PERTE
const PRIMARY := Charte.PANNEAU_3
const LABELS := {"league": "Championnat", "pool":"Poules", "barrage": "Barrage", "elimination": "Match de barrage", "r16":"Huitième de finale", "quarter":"Quart de finale", "semi": "Demi-finale", "final": "Finale", "third-place": "Petite finale", "access": "Barrage d’accession", "cup": "Coupe", "ended":"Compétition terminée"}
const JAPAN_COMPETITIONS := ["jlo-d1", "jlo-d2", "jlo-d1-d2"]
const RESULT_TINTS := {"V": WIN, "N": DRAW, "D": LOSS}
const AFAR_HINT := "Championnat en consultation : scores, classement, blessures et évolution des joueurs, sans notes individuelles ni feuilles de match. À changer dans Paramètres › Championnats suivis, effet dès la semaine suivante."
## Colonnes du classement : [libellé, centre x, largeur, clé de tri]. Tout en-tête est un bouton de tri.
const TABLE_COLUMNS := [
	["#", 108, 60, "rank"], ["J", 650, 50, "played"], ["V", 706, 50, "won"],
	["N", 762, 50, "drawn"], ["D", 818, 50, "lost"], ["PF", 902, 70, "pf"],
	["PC", 982, 70, "pa"], ["DIFF.", 1066, 80, "difference"], ["BON.", 1150, 70, "bonus"],
	["PTS", 1232, 80, "points"]
]


var app: Control
var state: Dictionary
var league: Dictionary
var leagues: Array
var own: Dictionary
var mode := "league"
var identities := {}
var fixtures: Array
var next_fixture: Dictionary
var season_results: Array
var international := false

# Lookup only published view-model data. Missing or ambiguous identifiers never
# fall back to the currently managed club or the next match.
static func target_available(owner_app: Control, kind: String, id: Variant) -> bool:
	match kind:
		"club": return not _target_club(owner_app, str(id)).is_empty()
		"fixture": return not _target_fixture(owner_app, str(id)).is_empty()
		"competition": return owner_app.model.get("leagues", []).any(func(item: Dictionary): return str(item.get("id", "")) == str(id))
		"session": return not _target_session(owner_app, id).is_empty()
		"date": return preload("res://ui/immersive08/calendar_agenda.gd").valid_date(id)
	return false

static func _target_session(owner_app: Control, id: Variant) -> Dictionary:
	if not id is String or id.is_empty(): return {}
	var planning: Variant = owner_app.model.get("calendarPlanning", {})
	if not planning is Dictionary: return {}
	var source: Variant = planning.get("sessions", [])
	if not source is Array: return {}
	var selected: Dictionary = {}
	for item: Variant in source:
		if not item is Dictionary or item.get("id") != id: continue
		if not selected.is_empty(): return {}
		selected = item
	if selected.is_empty() or not preload("res://ui/immersive08/calendar_agenda.gd").valid_date(selected.get("date")): return {}
	return selected

## Une séance s'ouvre dans le programme du mois (Entraînement › Mois) : aucun contexte de lecture du Calendrier à
## retrouver (l'ancienne grille mensuelle est retirée depuis le 22/11/2026).
static func session_context_matches(_owner_app: Control, _id: Variant) -> bool:
	return false

static func _target_club(owner_app: Control, id: String) -> Dictionary:
	if id.is_empty(): return {}
	var own_value: Variant = owner_app.model.get("club")
	var own_club: Dictionary = own_value if own_value is Dictionary else {}
	for division: Dictionary in owner_app.model.get("leagues", []):
		for club: Dictionary in division.get("rows", []):
			if same_club_id(club.get("id"), id): return club
	if same_club_id(own_club.get("id"), id): return own_club
	for club: Dictionary in owner_app.catalogue:
		if same_club_id(club.get("id"), id): return club
	return {}

## Identifiant de club : « 12 » et « 12.0 » désignent le même club (entier du moteur, flottant JSON).
static func same_club_id(value: Variant, id: String) -> bool:
	if value == null: return false
	if str(value) == id: return true
	return (value is int or value is float) and id.is_valid_float() and float(value) == float(id)

static func _target_fixture(owner_app: Control, id: String) -> Dictionary:
	if id.is_empty(): return {}
	var candidates: Array[Dictionary] = []
	for source: Array in [owner_app.model.get("calendar", []), owner_app.model.get("calendarPlanning", {}).get("fixtures", [])]:
		for fixture: Dictionary in source:
			if str(fixture.get("id", "")) == id: candidates.append(fixture)
	var next: Variant = owner_app.model.get("next")
	if next is Dictionary and str(next.get("id", "")) == id: candidates.append(next)
	for result: Dictionary in owner_app.model.get("history", []):
		if str(result.get("fixtureId", "")) != id: continue
		var pair: Array = result.get("pair", [])
		if pair.size() != 2: continue
		var fixture := result.duplicate(true)
		fixture.id = result.fixtureId
		fixture.home = _target_club(owner_app, str(pair[0]))
		fixture.away = _target_club(owner_app, str(pair[1]))
		if fixture.home.is_empty() or fixture.away.is_empty(): continue
		fixture.played = true
		candidates.append(fixture)
	if candidates.is_empty(): return {}
	var selected: Dictionary = candidates[0]
	for fixture: Dictionary in candidates.slice(1):
		if fixture.get("home", {}).get("id") != selected.get("home", {}).get("id") or fixture.get("away", {}).get("id") != selected.get("away", {}).get("id"): return {}
		if fixture.has("date") and selected.has("date") and fixture.date != selected.date: return {}
		if fixture.get("played", false) and not selected.get("played", false): selected = fixture
	return selected

static func open_target(owner_app: Control, kind: String, id: Variant) -> bool:
	if not target_available(owner_app, kind, id): return false
	if kind == "competition":
		owner_app.table_division = str(id)
		if not owner_app.management_ui.get("competition") is Dictionary: owner_app.management_ui.competition = {}
		owner_app.management_ui.competition.tab = "league"
		owner_app.management_ui.competition.club_league = str(owner_app.model.get("meta", {}).get("leagueId", ""))
		owner_app._navigate("Classements", false)
		return true
	# Date ou séance : le programme du mois (Entraînement › Mois, qui remplace l'ancienne grille du Calendrier depuis le
	# 22/11/2026), au mois de ce jour, avec la petite fenêtre du jour.
	if kind in ["date", "session"]:
		if load("res://ui/international_view.gd").nation_only(owner_app.model):
			owner_app._navigate("Calendrier", false)
			return true
		var date := str(_target_session(owner_app, id).get("date", "")) if kind == "session" else str(id)
		load("res://ui/immersive08/training_mois.gd").ouvrir(owner_app, date, true)
		return true
	# Club : fiche du club (écran). Rencontre : sous-page de Classements, avec retour et historique (jamais une fenêtre).
	if kind == "club":
		if not is_instance_valid(owner_app.navigation_controller): return false
		return owner_app.navigation_controller.open_entity({"kind": "club", "id": str(id)})
	owner_app.management_ui.competition_page = {"kind": "fixture", "id": str(id)}
	owner_app._navigate("Classements", false, true)
	return true

## Archives des saisons : sous-page de Classements (remplace l'ancienne fenêtre).
static func open_archives(owner_app: Control) -> void:
	owner_app.management_ui.competition_page = {"kind": "archives"}
	owner_app._navigate("Classements", true, true)

var content_bottom := 1240.0
var _menu_list: Control
var _menu_button: Control
var left_bottom := 0.0
var right_bottom := 0.0

## Lien de la charte (texte ivoire, souligné au survol), placé aux coordonnées du gabarit.
func _lien(parent: Node, area: Rect2, caption: String, callback: Callable, id: String = "", size: int = 19, repos: bool = false, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Button:
	var button := Button.new()
	if not id.is_empty(): button.name = id
	button.text = caption
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("immersive_style_applied", true)
	C.style_bouton_lien(button, size, repos)
	button.alignment = align
	button.clip_text = true
	button.pressed.connect(callback)
	parent.add_child(button)
	D.place(button, area)
	return button

## Action de la page : pilule à contour (Continuer, dans la coque, garde l'unique aplat doré).
func _principal(parent: Node, area: Rect2, caption: String, callback: Callable, id: String) -> Button:
	var button := Button.new()
	button.name = id
	button.text = caption
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("immersive_style_applied", true)
	C.style_bouton_contour(button, 22)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(callback)
	parent.add_child(button)
	D.place(button, area)
	return button

func _onglet(area: Rect2, caption: String, selected: bool, callback: Callable, id: String) -> Button:
	var button := Button.new()
	button.name = id
	button.text = caption.to_upper()
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("immersive_style_applied", true)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for look in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		# Charte finale : onglet en pilule, actif = aplat crème (texte panneau).
		style.bg_color = Charte.IVOIRE if selected else (Charte.PANNEAU_2 if look == "hover" else Color(0, 0, 0, 0))
		style.set_corner_radius_all(Charte.RAYON_PILULE)
		style.anti_aliasing = true
		style.border_color = Charte.OR
		if look == "focus": style.set_border_width_all(2)
		style.content_margin_left = C.px(16)
		style.content_margin_right = C.px(16)
		button.add_theme_stylebox_override(look, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, Charte.PANNEAU if selected else Charte.IVOIRE_2)
	button.add_theme_color_override("font_hover_color", Charte.PANNEAU if selected else Charte.IVOIRE)
	button.add_theme_font_override("font", C.BOLD)
	button.add_theme_font_size_override("font_size", maxi(12, C.px(24)))
	button.pressed.connect(callback)
	add_child(button)
	D.place(button, area)
	load("res://ui/retour_tuile.gd").brancher(button, button, Charte.RAYON_PILULE)
	return button

func _switch(tab_id: String) -> void:
	app.management_ui.erase("competition_page")
	if tab_id == "calendar":
		app._navigate("Calendrier")
	else:
		state.tab = tab_id
		if app.route == "Classements": app._render(false)
		else: app._navigate("Classements")

# --- Sous-pages (rencontre, archives) : jamais de petite fenêtre ----------------------------------------------------

func _page_state(key: String) -> Dictionary:
	if not app.management_ui.get(key) is Dictionary: app.management_ui[key] = {"page": 0}
	return app.management_ui[key]

func _turn(key: String, direction: int, id: String) -> void:
	var page := _page_state(key)
	page.page = int(page.page) + direction
	var owner_app := app
	app._render(false)
	var target := owner_app.find_child(id + ("Previous" if direction < 0 else "Next"), true, false) as Button
	if target != null and target.disabled:
		target = owner_app.find_child(id + ("Next" if direction < 0 else "Previous"), true, false) as Button
	if target != null: FocusLater.grab(target)


func _fixture_statistics(content: VBoxContainer, fixture: Dictionary) -> void:
	var result := _history_for(fixture)
	var stats: Variant = fixture.get("stats", result.get("stats"))
	if not stats is Array or stats.size() != 2 or not stats[0] is Dictionary or not stats[1] is Dictionary: return
	content.add_child(C.rule())
	content.add_child(C.label("STATISTIQUES · DOMICILE / EXTÉRIEUR", 23, C.IVORY, true, 700))
	for item: Array in [["Pénalités concédées", "penalties"], ["Cartons jaunes", "yellows"]]:
		content.add_child(C.label("%s · %s / %s" % [item[0], S.count_text(stats[0].get(item[1])), S.count_text(stats[1].get(item[1]))], 22, C.IVORY))
	for item: Array in [["Mêlées conservées", "scrumsWon", "scrums"], ["Touches conservées", "lineoutsWon", "lineouts"], ["Tirs de pénalité", "goals", "goalAttempts"], ["Transformations", "conversions", "conversionAttempts"]]:
		# Essai de pénalité (penaltyTries) : 7 points sans tentative, retiré des transformations affichées.
		# Drops (drops, dropAttempts) : comptés avec les buts du moteur, retirés des tirs de pénalité affichés.
		var vals: Array = []
		for side: int in 2:
			var retire: Array = [0, 0]
			if item[1] == "conversions":
				var pt: int = int(stats[side].get("penaltyTries", 0))
				retire = [pt, pt]
			elif item[1] == "goals":
				retire = [int(stats[side].get("drops", 0)), int(stats[side].get("dropAttempts", 0))]
			var rang := 0
			for key: String in [item[1], item[2]]:
				var v: Variant = stats[side].get(key)
				var r: int = retire[rang]
				rang += 1
				vals.append(int(v) - r if r > 0 and (v is int or v is float) else v)
		content.add_child(C.wrap("%s · %s / %s — %s / %s" % [item[0], S.count_text(vals[0]), S.count_text(vals[1]), S.count_text(vals[2]), S.count_text(vals[3])], 22, C.MUTED))

func _date_provenance(content: VBoxContainer, fixture: Dictionary) -> void:
	var source: String = {
		"published": "Date publiée",
		"published-phase-day": "Jour de phase publié",
		"published-window": "Date retenue dans la fenêtre publiée",
		"published-provisional": "Date provisoire publiée",
		"rfu-card": "Date publiée par la RFU",
		"club-announced-stage-date": "Date de phase annoncée par le club",
	}.get(fixture.get("dateSource", ""), "")
	if not source.is_empty(): content.add_child(C.wrap(source, 20, C.MUTED))
	var window: Array = fixture.get("dateWindow", [])
	if window.size()==2:
		content.add_child(C.wrap("Fenêtre du %s au %s" % [Club._calendar_date(window[0]), Club._calendar_date(window[1])],20,C.MUTED))
	var timezone: Variant = fixture.get("timezone")
	if fixture.get("kickoffLocal") is String and timezone is String and not timezone.is_empty():
		content.add_child(C.wrap("Heure locale · " + timezone,20,C.MUTED))
		var kickoff_source: String = {
			"published": "Horaire publié",
			"rfu_fixture_card": "Horaire publié dans la fiche RFU",
			"rfu_match_centre": "Horaire publié dans le centre de match RFU",
		}.get(fixture.get("kickoffSource", ""), "")
		if not kickoff_source.is_empty(): content.add_child(C.wrap(kickoff_source, 20, C.MUTED))

func _fixture_outcome(fixture: Dictionary) -> String:
	if not fixture.get("played", false): return "—"
	var score: Variant = fixture.get("score")
	var index := _side(fixture, own.get("id"))
	if index < 0: return "—"
	var decisive := _knockout(fixture) and _competition_id(fixture) != "jlo-d1-d2"
	if decisive:
		var winner: Variant = _fixture_winner(fixture)
		if winner != null: return "V" if winner == own.id else "D"
	if not score is Array or score.size() != 2 or S.count_text(score[0]) == "—" or S.count_text(score[1]) == "—": return "—"
	if score[0] == score[1] and decisive: return "—"
	return "V" if score[index] > score[1 - index] else "D" if score[index] < score[1 - index] else "N"

func _fixture_winner(fixture: Dictionary) -> Variant:
	var winner: Variant = fixture.get("winner")
	if _side(fixture, winner) >= 0: return winner
	var recorded := _history_for(fixture)
	winner = recorded.get("winner")
	return winner if _side(fixture, winner) >= 0 else null

func _history_for(fixture: Dictionary) -> Dictionary:
	var pair := [fixture.get("home", {}).get("id"), fixture.get("away", {}).get("id")]
	for result: Dictionary in season_results:
		if result.has("fixtureId") and result.fixtureId == fixture.get("id"): return result
	var matches := season_results.filter(func(result: Dictionary): return result.get("phase") == fixture.get("phase") and result.get("pair") == pair and result.get("score") == fixture.get("score"))
	return matches[0] if matches.size() == 1 else {}

func _is_next(fixture: Dictionary) -> bool:
	return not next_fixture.is_empty() and not fixture.get("played",false) and fixture.get("week") == next_fixture.get("week") and fixture.get("home",{}).get("id") == next_fixture.get("home",{}).get("id") and fixture.get("away",{}).get("id") == next_fixture.get("away",{}).get("id") and (not international or fixture.get("date") == next_fixture.get("date"))

func _matchup(result: Dictionary) -> Array:
	var pair: Array = result.get("pair", [])
	if pair.size() != 2: return [{}, {}]
	return [identities.get(pair[0], {}), identities.get(pair[1], {})]

func _location(fixture: Dictionary, compact: bool = false) -> String:
	match _location_kind(fixture):
		"neutral": return "Neutre" if compact else "Terrain neutre"
		"home": return "Dom." if compact else "À domicile"
		"away": return "Ext." if compact else "À l’extérieur"
	return "—"

func _location_kind(fixture: Dictionary) -> String:
	return P.fixture_location_kind(fixture, own.get("id"))

static func _venue_name(fixture: Dictionary) -> String:
	var venue: Variant = fixture.get("venue")
	if venue is Dictionary: venue = venue.get("name")
	return venue if venue is String and venue.to_lower() not in ["home", "away", "neutral"] else ""

static func _side(fixture: Dictionary, id: Variant) -> int:
	if id == null: return -1
	if fixture.get("home", {}).get("id") == id: return 0
	if fixture.get("away", {}).get("id") == id: return 1
	return -1

static func _score(fixture: Dictionary, club_id: Variant = null) -> String:
	var value: Variant = fixture.get("score")
	if not value is Array or value.size() != 2 or S.count_text(value[0]) == "—" or S.count_text(value[1]) == "—": return "—"
	var away := _side(fixture, club_id) == 1
	return "%s – %s" % [G.n(value[1] if away else value[0]), G.n(value[0] if away else value[1])]

static func _league_short(division: Dictionary) -> String:
	var text := str(division.get("name", "Championnat"))
	return str(division.get("shortName", text.get_slice(" — ", 0)))

static func _date(fixture: Dictionary) -> String:
	return P.fixture_date(fixture)

static func _knockout(fixture: Dictionary) -> bool:
	return fixture.get("phase","league") not in ["league","pool"]

static func _competition_id(fixture: Dictionary, fallback: String = "") -> String:
	return str(fixture.get("competitionId",fixture.get("leagueId",fallback)))

func _competition_name(fixture: Dictionary) -> String:
	if not international: return _phase(fixture)
	var id := _competition_id(fixture)
	var caption := World.name_for(app.model, id)
	return caption

## Libellé du type de phase publié par le moteur (aucun nom de compétition figé : le nom vient des données).
static func _phase(fixture: Dictionary) -> String:
	var id := str(fixture.get("phase", "league"))
	if id == "promotion":
		var leg_value: Variant = fixture.get("leg")
		var leg := int(leg_value) if leg_value is int or leg_value is float else 0
		# L’historique conserve la manche dans un tour indexé à partir de zéro.
		var round_value: Variant = fixture.get("competitionRound")
		if leg == 0 and (round_value is int or round_value is float): leg = int(round_value) + 1
		return "Barrage aller-retour · Manche %d" % leg if leg in [1, 2] else "Barrage aller-retour"
	return str(LABELS.get(id, id.capitalize()))

static func _dated_phase(fixture: Dictionary) -> String:
	var phase := _phase(fixture)
	var round_value: Variant = fixture.get("competitionRound")
	if fixture.get("phase") in ["league","pool"] and (round_value is int or round_value is float):
		phase += " · J%d" % (int(round_value)+1)
	return phase

static func _fixture_label(fixture: Dictionary) -> String:
	var label := str(fixture.get("label", ""))
	var round_value: Variant = fixture.get("competitionRound")
	if label.is_empty() and round_value is String: label = round_value
	if label.is_empty() and S.count_text(round_value) not in ["—", "0"] and fixture.get("phase") == "league":
		label = "Journée " + G.n(round_value)
	if label.is_empty(): label = "Semaine " + G.n(int(fixture.get("week", 0)) + 1)
	return str(LABELS.get(label, label))

static func _crest(parent: Node, club: Dictionary, area: Rect2) -> void:
	if club.is_empty(): return
	var shield := G.crest(club, C.px(minf(area.size.x, area.size.y)))
	parent.add_child(shield)
	D.place(shield, area)
	# Mini-carte club au survol de l’écusson (choix de Léo, 21/11/2026).
	preload("res://ui/carte_club_survol.gd").lier(shield, club)

static func _icon(parent: Node, icon_id: String, area: Rect2, color: Color) -> void:
	var icon := C.icon(icon_id, int(area.size.x), color)
	parent.add_child(icon)
	D.place(icon, area)

static func _panel(parent: Node, area: Rect2, title: String, _icon_id: String, id: String) -> Panel:
	var panel := D.rect(parent, area, Charte.PANNEAU, Charte.RAYON_PANNEAU)
	panel.name = id
	var heading := D.text(panel, 24, 42, title.to_upper(), 32, C.IVORY, 800, area.size.x - 48)
	heading.add_theme_font_override("font", Charte.TITRE_GRAS)
	heading.name = "CardTitle"
	return panel

## Section posée sur un panneau : pas de second panneau, seulement un filet 1 px au-dessus du titre (les cartes de la section
## sont des cartes de rayon 12 : `_bande`, `_tuile`).
static func _section(parent: Node, area: Rect2, title: String, _icon_id: String, id: String) -> Control:
	var section := Control.new()
	section.name = id
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(section)
	D.place(section, area)
	D.line(section, Vector2(0, 0), Vector2(area.size.x, 0), Charte.FILET)
	var heading := D.text(section, 8, 42, title.to_upper(), 32, C.IVORY, 800, area.size.x - 48)
	heading.add_theme_font_override("font", Charte.TITRE_GRAS)
	heading.name = "CardTitle"
	return section

## Ligne de liste de la charte : carte `PANNEAU_2` de rayon 12 dans le panneau ; le survol vient du bouton posé dessus.
static func _bande(parent: Node, area: Rect2) -> Control:
	return D.rect(parent, area, Charte.PANNEAU_2, Charte.RAYON_CARTE)

## Chiffre clé : carte `PANNEAU_2` de rayon 12 dans le panneau.
static func _tuile(parent: Node, area: Rect2) -> Control:
	return D.rect(parent, area, Charte.PANNEAU_2, Charte.RAYON_CARTE)

static func _box_tag(parent: Node, area: Rect2, caption: String, color: Color) -> void:
	var box := D.rect(parent, area, Charte.PANNEAU_2, Charte.RAYON_PILULE)
	D.text(box, area.size.x / 2, area.size.y / 2 + 7, caption, 20, color, 700, area.size.x - 7, HORIZONTAL_ALIGNMENT_CENTER)

static func _result_badge(parent: Node, area: Rect2, code: String, caption: String = "", known: bool = true) -> void:
	var outcome: Dictionary = S.RESULTS.get(code, {}) if known else {}
	var color: Color = RESULT_TINTS.get(code, DRAW) if not outcome.is_empty() else DRAW
	var text := caption if not caption.is_empty() else code if not outcome.is_empty() else "—"
	var box := D.rect(parent, area, color, int(minf(area.size.x, area.size.y) / 2.0))
	box.name = "SemanticBadge"
	box.set_meta("semantic_role", outcome.get("role", "neutral"))
	box.set_meta("semantic_text", text)
	box.accessibility_name = str(outcome.get("label", "Résultat non renseigné")) + " · " + text
	D.text(box, area.size.x / 2, area.size.y / 2 + 7, text, 19, Charte.NUIT, 800, area.size.x - 4, HORIZONTAL_ALIGNMENT_CENTER)

static func _result_legend(parent: Node, x: float, y: float) -> void:
	for i in 3:
		var code: String = ["V", "N", "D"][i]
		_result_badge(parent, Rect2(x + i * 150, y, 26, 26), code)
		D.text(parent, x + 36 + i * 150, y + 21, S.RESULTS[code].label, 19, C.IVORY, 500, 110)

static func _recent_form(parent: Node, values: Variant, x: float, y: float) -> void:
	var group := Control.new()
	group.name = "RecentForm"
	# Ne capte jamais la souris : la ligne entière reste cliquable.
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(group)
	D.place(group, Rect2(x, y, 180, 26))
	var sequence: Array = values.slice(-6) if values is Array and values.size() > 6 else values if values is Array else []
	if sequence.is_empty(): sequence = ["—"]
	for i in sequence.size(): _result_badge(group, Rect2(i * 30, 0, 26, 26), str(sequence[i]))

func _pager(parent: Node, id: String, key: String, total: int, capacity: int, y: float, x: float) -> Vector2i:
	var paging := _page_state(key)
	var pages := maxi(1, ceili(float(total) / capacity))
	paging.page = clampi(int(paging.get("page", 0)), 0, pages - 1)
	if pages > 1:
		var band := Control.new()
		band.name = id
		parent.add_child(band)
		D.place(band, Rect2(x, y, 470, 36))
		var prev := _lien(band, Rect2(0, 0, 155, 36), "← Précédent", func(): _turn(key, -1, id), id + "Previous", 20)
		prev.disabled = int(paging.page) == 0
		D.text(band, 230, 26, "Page %d / %d" % [int(paging.page) + 1, pages], 19, C.MUTED, 600, 133, HORIZONTAL_ALIGNMENT_CENTER)
		var following := _lien(band, Rect2(301, 0, 156, 36), "Suivant →", func(): _turn(key, 1, id), id + "Next", 20)
		following.disabled = int(paging.page) >= pages - 1
	return Vector2i(int(paging.page) * capacity, mini(total, (int(paging.page) + 1) * capacity))

func _entity_area(parent: Node, area: Rect2, target: Dictionary, id: String, caption: String) -> Button:
	if not target_available(app, str(target.kind), target.id): return null
	var button := Button.new()
	button.name = id
	button.flat = true
	button.set_meta("immersive_style_applied", true)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(Charte.IVOIRE, .06)
	hover.border_color = Charte.IVOIRE
	hover.border_width_bottom = maxi(2, C.px(2))
	hover.set_corner_radius_all(0)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Charte.IVOIRE
	focus.set_border_width_all(maxi(2, C.px(2)))
	focus.set_corner_radius_all(Charte.RAYON_PETIT)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", focus)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Link.bind(button, app, target, caption)
	parent.add_child(button)
	D.place(button, area)
	return button
