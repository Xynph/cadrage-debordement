extends Control
## Classements, phases finales, calendrier et résultats de la carrière native.
const FocusLater := preload("res://ui/focus_later.gd")
const C = preload("res://ui/immersive08/components.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const S = preload("res://ui/data_semantics.gd")
const Club = preload("res://ui/club_views.gd")
const Office = preload("res://ui/immersive08/office.gd")
const Decisions = preload("res://ui/decision_views.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const World = preload("res://ui/immersive08/world_archive.gd")
const Link = preload("res://ui/entity_link.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")
const EquipeType = preload("res://ui/equipe_type_view.gd")
const Zones = preload("res://ui/immersive08/standings_zones.gd")
const Charte = preload("res://ui/charte.gd")
const TenueClub = preload("res://ui/tenue_club.gd")
const WIDTH := 2248
const LEFT := 1500
const GAP := 24
const RIGHT := 724
const TOP := 150
const ROW := 32
const WARM := Charte.IVOIRE
const WIN := Charte.V
const DRAW := Charte.N
const LOSS := Charte.D
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

static func session_focus_name(id: String) -> String:
	return "CalendarSessionDetail_" + id.sha256_text()

static func session_context_matches(owner_app: Control, id: Variant) -> bool:
	var session := _target_session(owner_app, id)
	if session.is_empty() or owner_app.route != "Calendrier" or owner_app.get_meta("calendar_table", false): return false
	var reading: Dictionary = owner_app.management_ui.get("calendar_reading", {})
	if reading.get("selected_session", "") != id or reading.get("selected", "") != session.date or reading.get("filter", "all") not in ["all", "training"]: return false
	var program := owner_app.find_child("CarnetCalendar", true, false) as Control
	if program == null or not program.is_visible_in_tree(): return false
	var focus := program.find_child(session_focus_name(id), true, false) as Button
	return focus != null and focus.is_visible_in_tree() and focus.get_meta("entity_kind", "") == "session" and focus.get_meta("entity_id", "") == id

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
	if kind in ["date", "session"]:
		var reading: Dictionary = owner_app.management_ui.get("calendar_reading", {}).duplicate(true)
		reading.erase("selected_session")
		if kind == "session":
			var session := _target_session(owner_app, id)
			reading.selected = session.date
			reading.filter = "all"
			reading.selected_session = id
			owner_app.set_meta("calendar_table", false)
		else: reading.selected = str(id)
		reading.today = str(owner_app.model.get("calendarPlanning", {}).get("today", owner_app.model.get("meta", {}).get("date", "")))
		reading.focus = session_focus_name(id) if kind == "session" else "MonthDay_" + str(id)
		owner_app.management_ui.calendar_reading = reading
		owner_app._navigate("Calendrier", false)
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

static func build(owner_app: Control, canvas: Control) -> void:
	var page: Control = load("res://ui/immersive08/competition_canvas.gd").new()
	page.app = owner_app
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, WIDTH, 1240))
	page._build()
	var bottom: float = maxf(1240.0, page.content_bottom + 10.0)
	page.size.y = C.px(bottom)
	canvas.custom_minimum_size.y = maxf(canvas.custom_minimum_size.y, C.px(bottom))

func _context(reading_only: bool = false) -> void:
	var own_value: Variant = app.model.get("club")
	own = own_value if own_value is Dictionary else {}
	international = app.model.meta.get("mode") == "world"
	if not app.management_ui.get("competition") is Dictionary: app.management_ui.competition = {}
	state = app.management_ui.competition
	var club_league := str(app.model.meta.get("leagueId", ""))
	if not reading_only and state.get("club_league") != club_league:
		state.club_league = club_league
		if not club_league.is_empty(): app.table_division = club_league
	var selected_league: String = club_league if app.route == "Calendrier" else app.table_division
	leagues = app.model.get("leagues", [])
	if leagues.is_empty(): leagues = [{"id": "elite", "name": "Championnat historique", "rows": app.model.get("league", [])}]
	league = leagues[0]
	for division: Dictionary in leagues:
		if division.id == selected_league: league = division
		for club: Dictionary in division.get("rows", []): identities[club.id] = club
	for club: Dictionary in app.catalogue:
		if not identities.has(club.id): identities[club.id] = club
	if own.has("id"): identities[own.id] = own
	var next_value: Variant = app.model.get("next")
	next_fixture = next_value if next_value is Dictionary else {}
	fixtures = app.model.get("calendar", []).duplicate()
	if not international:
		fixtures.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("week", 0)) < int(b.get("week", 0)))
	season_results = app.model.get("history", []).duplicate()
	season_results.reverse()

func _build() -> void:
	name = "CarnetCalendar" if app.route == "Calendrier" else "CarnetStandings"
	_context()
	mode = "calendar" if app.route == "Calendrier" else str(state.get("tab", "league"))
	if _sous_page(): return
	_header()
	left_bottom = TOP + 760.0
	match mode:
		"calendar": _calendar()
		"playoffs": _playoffs()
		"stats": _stats()
		_: _classement()
	_bas_gauche()
	_colonne_droite()
	content_bottom = maxf(left_bottom, right_bottom)

# --- Outils de composition (jetons de la charte, aucune couleur codée en dur) -----------------------------------

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
	return button

func _header() -> void:
	var title := D.text(self, 0, 50, "COMPÉTITIONS", 50, C.IVORY, 800, 440)
	title.add_theme_font_override("font", Charte.TITRE_GRAS)
	title.name = "CompetitionTitle"
	var round_label := str(app.model.meta.get("roundLabel", "")) if league.id == state.club_league else "Phase régulière" if league.get("phase", "league") == "league" else _phase(league)
	var short_round := round_label.trim_prefix(str(league.get("name","")) + " · ")
	var subhead := "%s  ·  saison %s  ·  %s" % [_league_short(league), G.season_label(app.model.meta.get("season", "—")), short_round]
	var sub := D.text(self, 450, 46, subhead, 22, C.MUTED, 500, 1100, HORIZONTAL_ALIGNMENT_LEFT, true)
	sub.name = "CompetitionSubhead"
	if _followed_from_afar():
		var afar := D.text(self, 1580, 44, "CONSULTATION", 20, C.MUTED, 700, 200)
		afar.name = "CompetitionFollowedFromAfar"
		afar.mouse_filter = Control.MOUSE_FILTER_STOP
		afar.tooltip_text = AFAR_HINT
	var emblem := G._pack_texture(str(league.get("logoPath", "")))
	if emblem != null:
		var logo := TextureRect.new()
		logo.name = "CompetitionOfficialLogo"
		logo.texture = emblem
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo.accessibility_name = str(league.get("name", "Championnat"))
		add_child(logo)
		D.place(logo, Rect2(WIDTH - 150, 0, 150, 60))
	var x := 0
	for spec: Array in [[250, "Classements", "league", "Section_Classements"], [270, "Phases finales", "playoffs", "CompetitionPlayoffs"],
		[240, "Calendrier", "calendar", "Section_Calendrier"], [250, "Statistiques", "stats", "CompetitionStats"]]:
		_onglet(Rect2(x, 78, spec[0], 52), spec[1], mode == spec[2], func(): _switch(str(spec[2])), spec[3])
		x += int(spec[0]) + 4
	_onglet(Rect2(x, 78, 230, 52), "Rivalités", false, func(): app._navigate("Rivalités"), "Section_Rivalités")
	var archives := _lien(self, Rect2(WIDTH - 340, 86, 340, 40), "Archives des saisons →", func(): Club.season_archives(app), "OpenArchives", 20, false, HORIZONTAL_ALIGNMENT_RIGHT)
	archives.tooltip_text = "Les saisons passées : champions, montées, descentes"
	if EquipeType.disponible(app.model):
		_lien(self, Rect2(WIDTH - 540, 86, 190, 40), "XV type →", func(): EquipeType.ouvrir(app, league.id if league.get("id") else "", "journee"), "CompetitionEquipeType", 20, false, HORIZONTAL_ALIGNMENT_RIGHT)
	D.line(self, Vector2(0, 132), Vector2(WIDTH, 132), Charte.FILET)

## Championnat suivi de loin (Réglages › Championnats suivis, carrière Monde configurée).
func _followed_from_afar() -> bool:
	var detail: Variant = app.model.get("clubLife", {}).get("leagueDetail", {})
	if not detail is Dictionary or not bool(detail.get("configured", false)) or league.has("pools"): return false
	for item: Variant in detail.get("leagues", []):
		if item is Dictionary and str(item.get("id", "")) == str(league.get("id", "")): return not bool(item.get("detailed", true))
	return false

func _switch(tab_id: String) -> void:
	app.management_ui.erase("competition_page")
	if tab_id == "calendar":
		app._navigate("Calendrier")
	else:
		state.tab = tab_id
		if app.route == "Classements": app._render(false)
		else: app._navigate("Classements")

# --- Sous-pages (rencontre, archives) : jamais de petite fenêtre ----------------------------------------------------

## Menu de compétition : se ferme au clic ailleurs et à Échap (avant le retour d'historique).
func _input(event: InputEvent) -> void:
	if _menu_list == null or not is_instance_valid(_menu_list) or not _menu_list.visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_menu_list.visible = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var point := get_viewport().get_mouse_position()
		if not _menu_list.get_global_rect().has_point(point) and not _menu_button.get_global_rect().has_point(point): _menu_list.visible = false

func _fermer_page() -> void:
	app.management_ui.erase("competition_page")
	app._navigate("Classements", true, true)

func _sous_page() -> bool:
	var request: Variant = app.management_ui.get("competition_page")
	if not request is Dictionary: return false
	var kind := str(request.get("kind", ""))
	var fixture: Dictionary = {}
	if kind == "fixture":
		fixture = _target_fixture(app, str(request.get("id", "")))
		if fixture.is_empty():
			app.management_ui.erase("competition_page")
			return false
	elif kind != "archives":
		app.management_ui.erase("competition_page")
		return false
	var back := _lien(self, Rect2(0, 8, 460, 40), "← Retour au classement", _fermer_page, "CompetitionPageBack", 21)
	back.tooltip_text = "Retour · Échap"
	D.line(self, Vector2(0, 62), Vector2(WIDTH, 62), Charte.FILET)
	if kind == "archives":
		_page_archives()
	else:
		_page_rencontre(fixture)
	return true

func _titre_page(texte: String) -> void:
	var title := D.text(self, 0, 116, texte.to_upper(), 46, C.IVORY, 800, WIDTH)
	title.add_theme_font_override("font", Charte.TITRE_GRAS)
	title.name = "CompetitionPageTitle"

func _page_archives() -> void:
	_titre_page("Le carnet des saisons")
	var panel := D.rect(self, Rect2(0, 140, LEFT, 1000), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	panel.name = "CompetitionArchivesPage"
	var content := C.v(10)
	content.name = "SeasonArchives"
	panel.add_child(content)
	D.place(content, Rect2(32, 24, LEFT - 64, 940))
	var seasons: Array = app.model.get("archives", {}).get("seasons", []).duplicate()
	seasons.reverse()
	var world: GDScript = World
	if seasons.is_empty():
		content.add_child(C.wrap("Aucune saison archivée", 22, C.MUTED))
	var lines := 1
	for year: Dictionary in seasons:
		var heading := C.label("SAISON " + G.season_label(year.season), 30, C.IVORY, true, 800)
		heading.add_theme_font_override("font", Charte.TITRE_GRAS)
		heading.name = "SeasonArchiveHeading_" + G.n(year.season)
		content.add_child(heading)
		for winner: Dictionary in Club.archive_titles(year):
			_ligne_archive(content, "Champion %s : %s" % [Club.competition_name(winner.leagueId, app.model), Club._archive_club(app, winner.clubId)], winner.clubId, 22, C.IVORY)
		var standings: Dictionary = year.get("standings", {})
		for league_id: Variant in standings.keys():
			var ranks: Array = standings.get(league_id, [])
			var position := ranks.find(own.get("id"))
			if position >= 0: _ligne_archive(content, "Ton club · %s · %s sur %d en phase régulière" % [Club.competition_name(str(league_id), app.model), _ordinal(position + 1), ranks.size()], null, 20, C.IVORY)
		for pair: Array in [["promoted", "Montées" if year.get("movement", {}).get("promoted", []).size() > 1 else "Montée"], ["relegated", "Descentes" if year.get("movement", {}).get("relegated", []).size() > 1 else "Descente"]]:
			var moved: Array = year.get("movement", {}).get(pair[0], [])
			if moved.is_empty(): continue
			var names := PackedStringArray()
			for id: Variant in moved: names.append(Club._archive_club(app, id))
			_ligne_archive(content, pair[1] + " · " + ", ".join(names), moved[0] if moved.size() == 1 else null, 20, C.MUTED)
		for barrage: Dictionary in world.japan_barrages(year):
			for line: String in world.japan_lines(app, barrage): _ligne_archive(content, line, null, 20, C.MUTED)
		content.add_child(C.rule())
	# Hauteur du panneau : estimée ligne par ligne (titre de saison, ligne, filet), sans grand vide sous une page courte.
	var estimate := 48.0
	for child: Node in content.get_children():
		estimate += 14.0 if child is HSeparator else 52.0 if str(child.name).begins_with("SeasonArchiveHeading_") else 38.0
	lines = int(estimate)
	var height := maxf(180.0, float(lines))
	panel.size.y = C.px(height)
	content.size.y = C.px(height - 60)
	content_bottom = 160.0 + height

## Une ligne du carnet ; quand elle cite un seul club connu, toute la ligne ouvre sa fiche (flèche et soulignement au survol).
func _ligne_archive(parent: Control, text: String, club_id: Variant, size: int, tint: Color) -> void:
	var linked := club_id != null and target_available(app, "club", str(club_id))
	var label := C.wrap(text + ("  →" if linked else ""), size, tint)
	parent.add_child(label)
	if not linked: return
	var area := Button.new()
	# Identifiant entier (le JSON livre « 12.0 », et le point est interdit dans un nom de nœud).
	area.name = "SeasonArchiveClub_" + (str(int(club_id)) if club_id is float or club_id is int else str(club_id).validate_node_name())
	area.flat = true
	area.set_meta("immersive_style_applied", true)
	for look in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.PANNEAU_3 if look == "hover" else Color(0, 0, 0, 0)
		style.set_corner_radius_all(Charte.RAYON_PETIT)
		if look == "focus":
			style.border_color = Charte.IVOIRE
			style.border_width_bottom = maxi(2, C.px(2))
		area.add_theme_stylebox_override(look, style)
	area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	label.add_child(area)
	area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.show_behind_parent = true
	Link.bind(area, app, {"kind":"club", "id":str(club_id)}, "Ouvrir le club · " + Club._archive_club(app, club_id))

## Habille les textes d'une vue historique aux jetons de la charte (texte ivoire sur surface sombre).
func _recolorer(racine: Node) -> void:
	for node: Node in racine.find_children("*", "Label", true, false):
		var label := node as Label
		label.add_theme_color_override("font_color", C.IVORY)
		label.add_theme_font_override("font", Charte.TEXTE)
		label.add_theme_font_size_override("font_size", maxi(C.px(19), label.get_theme_font_size("font_size")))
	for node: Node in racine.find_children("*", "OptionButton", true, false):
		var choice := node as OptionButton
		choice.add_theme_color_override("font_color", C.IVORY)

func _page_rencontre(fixture: Dictionary) -> void:
	var competition_id := _competition_id(fixture)
	var heading := _fixture_label(fixture)
	if international:
		var stage := _dated_phase(fixture)
		heading = _competition_name(fixture) + " · " + stage
		if competition_id == "access-nationale": heading = _competition_name(fixture)
	_titre_page(heading)
	# Gabarit du « Prochain rendez-vous » : plaques inclinées aux couleurs des clubs, score entre les deux.
	var panel := D.rect(self, Rect2(0, 140, LEFT, 800), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	panel.name = "CompetitionFixtureDetails"
	panel.set_meta("entity_kind", "fixture")
	panel.set_meta("entity_id", str(fixture.get("id", "")))
	var home_club: Dictionary = fixture.get("home", {})
	var away_club: Dictionary = fixture.get("away", {})
	var home_plate := _plaque(panel, Rect2(32, 28, 560, 88), home_club, "FixtureClub_home", false)
	var away_plate := _plaque(panel, Rect2(LEFT - 592, 28, 560, 88), away_club, "FixtureClub_away", true)
	for plate: Button in [home_plate, away_plate]:
		if plate.tooltip_text.is_empty(): plate.tooltip_text = plate.accessibility_name
	var middle := _score(fixture) if fixture.get("played", false) else "CONTRE"
	var middle_label := D.text(panel, 592, 86, middle, 52 if fixture.get("played", false) else 22, C.IVORY if fixture.get("played", false) else C.MUTED, 800, LEFT - 1184, HORIZONTAL_ALIGNMENT_CENTER)
	middle_label.add_theme_font_override("font", Charte.TITRE_GRAS)
	middle_label.name = "CompetitionFixtureScore"
	# Centré entre les deux plaques une fois la police de titre posée (sa largeur change avec la police).
	var middle_w := middle_label.get_theme_font("font").get_string_size(middle, HORIZONTAL_ALIGNMENT_LEFT, -1, middle_label.get_theme_font_size("font_size")).x
	middle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	middle_label.size.x = middle_w + 4
	middle_label.position.x = LEFT / 2.0 * C.density - middle_w / 2.0
	var content := C.v(14)
	panel.add_child(content)
	D.place(content, Rect2(32, 140, LEFT - 64, 640))
	var place := _location(fixture)
	var venue := _venue_name(fixture)
	if not venue.is_empty(): place += "  ·  " + venue
	var date := P.fixture_date(fixture, true)
	if not date.is_empty():
		var raw_date: Variant = fixture.get("date")
		if target_available(app, "date", raw_date):
			content.add_child(_nav_lien(date + " · voir dans le calendrier →", {"kind":"date", "id":raw_date}, "FixtureCalendarDate", 22))
		else: content.add_child(C.label(date, 26, C.IVORY, true, 700))
	if target_available(app, "competition", competition_id):
		content.add_child(_nav_lien(_competition_name(fixture) + " · voir le classement →", {"kind":"competition", "id":competition_id}, "FixtureCompetition", 22))
	content.add_child(C.label(_phase(fixture) + "  ·  " + place, 24, C.MUTED))
	if fixture.get("played", false):
		var code := _fixture_outcome(fixture)
		var verdict := str(S.RESULTS.get(code, {}).get("label", "Issue non renseignée"))
		var result := C.label((code + "  ·  " + verdict if code in RESULT_TINTS else verdict).to_upper(), 34, RESULT_TINTS.get(code, C.IVORY), true, 800)
		result.add_theme_font_override("font", Charte.TITRE_GRAS)
		result.name = "CompetitionFixtureResult"
		content.add_child(result)
		_fixture_statistics(content, fixture)
		var winner: Variant = _fixture_winner(fixture)
		if winner != null and identities.has(winner):
			content.add_child(C.label("Vainqueur : " + G.club_name(identities[winner]), 26, C.IVORY))
	else:
		content.add_child(C.label("Match à jouer", 30, C.IVORY, true, 700))
		if _is_next(fixture):
			var live: bool = not app._live().is_empty()
			var prepare := Button.new()
			prepare.name = "CompetitionFixturePrepare"
			prepare.text = ("Rejoindre le match" if live else "Préparer le match").to_upper() + "  →"
			prepare.set_meta("immersive_style_applied", true)
			C.style_bouton_contour(prepare, 22)
			prepare.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			prepare.pressed.connect(func(): app._navigate("Match" if live else "Préparation"))
			content.add_child(prepare)
	content_bottom = 960.0

## Lien de la charte vers une entité (club, date, compétition) : un clic change d'écran.
func _nav_lien(caption: String, target: Dictionary, id: String, size: int = 20) -> Button:
	var button := Button.new()
	button.name = id
	button.text = caption
	button.set_meta("immersive_style_applied", true)
	C.style_bouton_lien(button, size, true)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	Link.bind(button, app, target, caption)
	return button

## Les clubs d'une compétition, ordre de lecture du tableau (tri choisi par le joueur, rang par défaut).
func _sort_state() -> Dictionary:
	var value: Variant = app.management_ui.get("standings_sort")
	if value is Dictionary and str(value.get("key", "")) != "": return value
	return {"key": "rank", "desc": false}

func _trier(key: String) -> void:
	var current := _sort_state()
	var desc := not bool(current.get("desc", false)) if current.key == key else key not in ["rank", "name", "lost", "pa"]
	if current.key == key and key == "rank" and bool(current.get("desc", false)): desc = false
	app.management_ui.standings_sort = {"key": key, "desc": desc}
	app._render(false)

func _sort_value(club: Dictionary, key: String) -> Variant:
	match key:
		"rank": return int(club.get("rank", 0)) if P.standings_open(club) else 9999
		"name": return G.club_name(club).to_lower()
		"difference": return float(club.get("pf", 0)) - float(club.get("pa", 0))
	return float(club.get(key, 0))

func _sorted(rows: Array) -> Array:
	var sort := _sort_state()
	var key: String = sort.key
	var desc: bool = sort.desc
	var result := rows.duplicate()
	if key == "rank" and not desc: return result
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left: Variant = _sort_value(a, key)
		var right: Variant = _sort_value(b, key)
		if left == right: return int(a.get("rank", 0)) < int(b.get("rank", 0))
		return left > right if desc else left < right)
	return result

func _ordinal(value: int) -> String:
	return "%der" % value if value == 1 else "%de" % value

func _couleur_club(club: Dictionary) -> Color:
	var colors: Array = TenueClub.couleurs(club)
	return colors[0] if not colors.is_empty() else Charte.CLUB

func _own_row() -> Dictionary:
	for division: Dictionary in leagues:
		if str(division.id) != str(state.get("club_league", league.id)): continue
		for club: Dictionary in division.get("rows", []):
			if club.id == own.get("id"): return club
	return {}

func _own_league_rows() -> Array:
	for division: Dictionary in leagues:
		if str(division.id) == str(state.get("club_league", league.id)): return division.get("rows", [])
	return []

func _pool_index(pools: Array) -> int:
	var key := "standings_pool_" + str(league.id)
	var own_pool := pools.find_custom(func(pool: Dictionary):
		return pool.get("rows", []).any(func(club: Dictionary): return club.id == own.id))
	return clampi(int(app.management_ui.get(key, maxi(0, own_pool))), 0, pools.size() - 1)

func _pool_widget(panel: Control, pools: Array, selected: int, x: float, y: float) -> void:
	var key := "standings_pool_" + str(league.id)
	D.text(panel, x, y + 28, "PHASE DE POULES", 19, C.MUTED, 700, 220)
	var choice := OptionButton.new()
	choice.name = "StandingsPoolChoice"
	choice.add_theme_font_override("font", C.BOLD)
	choice.add_theme_font_size_override("font_size", maxi(12, C.px(21)))
	for pool: Dictionary in pools: choice.add_item(str(pool.get("label", "Poule")))
	choice.select(selected)
	choice.item_selected.connect(func(index: int):
		app.management_ui[key] = index
		var owner_app := app
		owner_app._render(false)
		U.focus(owner_app, "StandingsPoolChoice"))
	panel.add_child(choice)
	D.place(choice, Rect2(x + 230, y, 280, 40))

## Classement : tableau à gauche (colonnes triables, zones en liseré, symbole et mot), choix de la compétition en menu déroulant.
func _classement() -> void:
	var rows: Array = league.get("rows", []).duplicate()
	var pools: Array = league.get("pools", []) if international and league.get("pools") is Array else []
	var page_key := "standings_" + str(league.id)
	var selected_pool := -1
	var header_y := 84
	if not pools.is_empty():
		selected_pool = _pool_index(pools)
		rows = pools[selected_pool].get("rows", []).duplicate()
		page_key += "_poule_" + G.n(pools[selected_pool].id)
		header_y += 52
	rows = _sorted(rows)
	# Tout le classement sur la page, qui défile (décision de Léo) : plus de pagination.
	var capacity := maxi(1, rows.size())
	var paged := false
	var shown := mini(rows.size(), capacity)
	var rows_y := header_y + 40
	var zones: Array = league.get("zones", []) if international and league.get("zones") is Array else []
	var zone_note := str(league.get("zoneNote", "")) if international and league.get("zoneNote") is String else ""
	var has_champion: bool = league.get("champion") is Dictionary
	var footer := zones.size() * 30 + int(not zone_note.is_empty()) * 30 + int(has_champion) * 30 + (44 if paged else 0)
	var panel_h := rows_y + shown * ROW + 18 + footer + 18
	var panel := _panel(self, Rect2(0, TOP, LEFT, panel_h), "CLASSEMENT", "", "StandingsTableFrame")
	left_bottom = TOP + panel_h
	_division_menu(panel, 250, 12, 540)
	_result_legend(panel, LEFT - 24 - 450, 20)
	if not pools.is_empty(): _pool_widget(panel, pools, selected_pool, 24, 76)
	D.line(panel, Vector2(24, rows_y - 3), Vector2(LEFT - 24, rows_y - 3), Charte.FILET)
	_entete_tri(panel, Rect2(150, header_y, 440, 36), "CLUB", "name", HORIZONTAL_ALIGNMENT_LEFT)
	for column: Array in TABLE_COLUMNS:
		_entete_tri(panel, Rect2(column[1] - column[2] / 2.0, header_y, column[2], 36), column[0], column[3], HORIZONTAL_ALIGNMENT_CENTER)
	D.text(panel, 1290, header_y + 25, "FORME", 15, C.MUTED, 700, 190)
	var body := Control.new()
	body.name = "StandingsRows"
	panel.add_child(body)
	D.place(body, Rect2(0, rows_y, LEFT, shown * ROW))
	var bounds := _pager(panel, "StandingsPagination", page_key, rows.size(), capacity, rows_y + shown * ROW + 8, 24)
	for i in range(bounds.x, bounds.y):
		_ligne_classement(body, rows[i], i - bounds.x, ROW)
	if rows.is_empty(): D.text(body, 24, 40, "Aucun classement", 22, C.MUTED, 500, LEFT - 50, HORIZONTAL_ALIGNMENT_LEFT, true)
	var y := rows_y + shown * ROW + 18 + (44 if paged else 0)
	if not zones.is_empty():
		_zone_legend(panel, zones, 24, y)
		y += zones.size() * 30
	if not zone_note.is_empty():
		var note := D.text(panel, 24, y + 20, zone_note, 18, C.MUTED, 500, LEFT - 48, HORIZONTAL_ALIGNMENT_LEFT, true)
		note.name = "StandingsZoneNote"
		y += 30
	if has_champion:
		var name_text := "Champion : " + G.club_name(league.champion)
		if league.get("finalist") is Dictionary: name_text += "   ·   Finaliste : " + G.club_name(league.finalist)
		var champion := D.text(panel, 24, y + 20, name_text, 20, C.IVORY, 700, LEFT - 48)
		champion.name = "StandingsChampion"

func _entete_tri(parent: Control, area: Rect2, caption: String, key: String, align: HorizontalAlignment) -> void:
	var active: bool = str(_sort_state().key) == key
	var button := Button.new()
	button.name = "StandingsSort_" + key
	button.text = caption
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("immersive_style_applied", true)
	C.style_bouton_lien(button, 16, true)
	button.alignment = align
	button.tooltip_text = "Trier par " + caption
	button.accessibility_name = "Trier par " + caption
	var colour := Charte.IVOIRE if active else Charte.IVOIRE_2
	for item in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: button.add_theme_color_override(item, colour)
	button.pressed.connect(func(): _trier(key))
	parent.add_child(button)
	D.place(button, area)
	if active:
		var desc: bool = bool(_sort_state().desc)
		var arrow := Polygon2D.new()
		arrow.name = "StandingsSortArrow"
		arrow.color = Charte.IVOIRE
		var shape := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(5, 7)]) if desc else PackedVector2Array([Vector2(0, 7), Vector2(10, 7), Vector2(5, 0)])
		for i in shape.size(): shape[i] *= C.density
		arrow.polygon = shape
		var arrow_x := area.end.x - 12 if align == HORIZONTAL_ALIGNMENT_CENTER else area.position.x + 64
		arrow.position = Vector2(arrow_x, area.position.y + 14) * C.density
		parent.add_child(arrow)

## Choix de la compétition : menu déroulant dans la page (mes compétitions, puis les autres).
func _division_menu(parent: Control, x: float, y: float, w: float) -> void:
	var own_league := str(state.get("club_league", ""))
	var main := Button.new()
	main.name = "StandingsDivisionMenu"
	main.text = _league_short(league) + ("   ·   ma compétition" if str(league.id) == own_league else "")
	main.focus_mode = Control.FOCUS_ALL
	main.alignment = HORIZONTAL_ALIGNMENT_LEFT
	main.clip_text = true
	main.set_meta("immersive_style_applied", true)
	main.tooltip_text = "Changer de compétition"
	for look in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.PANNEAU_3 if look != "hover" else Charte.PANNEAU_2
		style.set_corner_radius_all(Charte.RAYON_PILULE)
		style.border_color = Charte.IVOIRE if look in ["hover", "focus"] else Charte.FILET
		style.set_border_width_all(1 if look != "focus" else 2)
		style.content_margin_left = C.px(14)
		style.content_margin_right = C.px(40)
		style.content_margin_top = C.px(4)
		style.content_margin_bottom = C.px(4)
		main.add_theme_stylebox_override(look, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: main.add_theme_color_override(key, Charte.IVOIRE)
	main.add_theme_font_override("font", C.BOLD)
	main.add_theme_font_size_override("font_size", maxi(12, C.px(22)))
	parent.add_child(main)
	D.place(main, Rect2(x, y, w, 42))
	var arrow := Polygon2D.new()
	arrow.color = Charte.IVOIRE_2
	var shape := PackedVector2Array([Vector2(0, 0), Vector2(14, 0), Vector2(7, 9)])
	for i in shape.size(): shape[i] *= C.density
	arrow.polygon = shape
	arrow.position = Vector2(w - 30, 17) * C.density
	main.add_child(arrow)
	var menu := PanelContainer.new()
	menu.name = "StandingsDivisionList"
	menu.visible = false
	menu.z_index = 60
	var frame := StyleBoxFlat.new()
	frame.bg_color = Charte.PANNEAU_3
	frame.border_color = Charte.FILET
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(Charte.RAYON_CARTE)
	frame.content_margin_left = C.px(8)
	frame.content_margin_right = C.px(8)
	frame.content_margin_top = C.px(8)
	frame.content_margin_bottom = C.px(8)
	menu.add_theme_stylebox_override("panel", frame)
	var column := C.v(2)
	menu.add_child(column)
	parent.add_child(menu)
	D.place(menu, Rect2(x, y + 46, w, 0))
	menu.custom_minimum_size.x = C.px(w)
	var first_item: Button = null
	var groups := [["MES COMPÉTITIONS", leagues.filter(func(division: Dictionary): return str(division.id) == own_league)],
		["AUTRES COMPÉTITIONS", leagues.filter(func(division: Dictionary): return str(division.id) != own_league)]]
	for group: Array in groups:
		if group[1].is_empty(): continue
		var heading := C.label(group[0], 15, C.FAINT, true, 700)
		column.add_child(heading)
		for division: Dictionary in group[1]:
			var item := _item_menu(division, own_league)
			column.add_child(item)
			if first_item == null: first_item = item
	_menu_list = menu
	_menu_button = main
	main.pressed.connect(func():
		menu.visible = not menu.visible
		if menu.visible and first_item != null: first_item.grab_focus())

func _item_menu(division: Dictionary, own_league: String) -> Button:
	var item := Button.new()
	item.name = "StandingsDivision_" + str(division.id)
	var short := _league_short(division)
	item.text = short
	item.tooltip_text = str(division.get("name", short))
	item.focus_mode = Control.FOCUS_ALL
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.clip_text = true
	item.set_meta("immersive_style_applied", true)
	var selected: bool = division.id == league.id
	for look in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.PANNEAU_2 if look == "hover" else (Charte.PANNEAU_3 if not selected else Charte.PANNEAU)
		style.set_corner_radius_all(Charte.RAYON_PETIT)
		style.border_color = Charte.IVOIRE
		style.border_width_left = maxi(2, C.px(4)) if selected or look == "focus" else 0
		style.content_margin_left = C.px(14)
		style.content_margin_right = C.px(150)
		style.content_margin_top = C.px(5)
		style.content_margin_bottom = C.px(5)
		item.add_theme_stylebox_override(look, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: item.add_theme_color_override(key, Charte.IVOIRE)
	item.add_theme_font_override("font", C.BOLD if selected else Charte.texte_moyen())
	item.add_theme_font_size_override("font_size", maxi(12, C.px(20)))
	var detail := "%d clubs" % division.get("rows", []).size()
	if str(division.id) == own_league:
		var mine := _own_row()
		if not mine.is_empty() and P.standings_open(mine): detail = "%s · %s pts" % [_ordinal(int(mine.get("rank", 0))), S.number_text(mine.get("points"))]
	var side := C.label(detail, 17, C.MUTED, false, 500)
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	side.offset_right = -C.px(12)
	side.offset_left = -C.px(150)
	side.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.add_child(side)
	item.pressed.connect(func():
		app.table_division = division.id
		app.management_ui.erase("competition_page")
		var owner_app := app
		owner_app._render(false)
		U.focus(owner_app, "StandingsDivision_" + str(division.id)))
	return item

func _ligne_classement(parent: Node, club: Dictionary, index: int, stride: int) -> void:
	var mine: bool = club.id == own.id
	var rank := int(club.get("rank", 0)) if P.standings_open(club) else 0
	var zone := Color.TRANSPARENT
	# Monde : zone publiée par le moteur pour ce rang (règlement de la compétition), seulement une fois le classement ouvert.
	var zone_info: Dictionary = club.zone if international and rank > 0 and club.get("zone") is Dictionary else {}
	# Les zones viennent seulement des données Monde du moteur (règlement de la compétition) : jamais de règle figée.
	if international: zone = Zones.TINTS.get(str(zone_info.get("kind", "")), Color.TRANSPARENT)
	var row := Button.new()
	row.name = "StandingsRow_" + str(club.id)
	row.set_meta("club_id", club.id)
	var standing := (" · " + S.count_text(club.get("rank")) + " au classement" if P.standings_open(club) else " · pas encore classé")
	if not zone_info.is_empty():
		standing += " · " + str(zone_info.get("label", ""))
		row.set_meta("zone_kind", str(zone_info.get("kind", "")))
		row.set_meta("zone_label", str(zone_info.get("label", "")))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Charte.PANNEAU_3 if mine else (Charte.PANNEAU_2 if index % 2 == 1 else Charte.PANNEAU)
	normal.set_corner_radius_all(Charte.RAYON_PETIT)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Charte.PANNEAU_3
	hover.set_corner_radius_all(Charte.RAYON_PETIT)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Charte.IVOIRE
	focus.set_border_width_all(maxi(2, C.px(2)))
	focus.set_corner_radius_all(Charte.RAYON_PETIT)
	row.add_theme_stylebox_override("normal", normal)
	row.add_theme_stylebox_override("hover", hover)
	row.add_theme_stylebox_override("pressed", hover)
	row.add_theme_stylebox_override("focus", focus)
	row.set_meta("immersive_style_applied", true)
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Link.bind(row, app, {"kind":"club", "id":str(club.id)}, "Ouvrir le club · " + G.club_name(club))
	# Après le lien (qui pose « Ouvrir · … ») : la place et la zone restent annoncées.
	row.accessibility_name += standing
	parent.add_child(row)
	D.place(row, Rect2(0, index * stride, LEFT, stride))
	if zone.a > 0:
		var edge := D.rect(row, Rect2(0, 1, 5, stride - 2), zone)
		edge.name = "StandingsZoneEdge"
	if not zone_info.is_empty():
		var side := Zones.mark_side()
		Zones.mark(row, str(zone_info.get("kind", "")), Rect2(36, (stride - side) / 2.0, side, side), zone)
	if mine:
		var height := float(stride - 12)
		var slant := height * tan(deg_to_rad(Charte.INCLINAISON_DEGRES))
		var marker := Polygon2D.new()
		marker.name = "StandingsOwnMarker"
		marker.color = Charte.IVOIRE
		var shape := PackedVector2Array([Vector2(slant, 0), Vector2(slant + 8, 0), Vector2(8, height), Vector2(0, height)])
		for i in shape.size(): shape[i] *= C.density
		marker.polygon = shape
		marker.position = Vector2(14, 6) * C.density
		row.add_child(marker)
		var underline := D.rect(row, Rect2(0, stride - 3, LEFT, 3), Charte.VERT_CLAIR)
		underline.name = "StandingsOwnTrait"
	var emblem := mini(26, stride - 4)
	_crest(row, club, Rect2(152, (stride - emblem) / 2.0, emblem, emblem))
	var baseline := stride / 2.0 + 7
	D.text(row, 192, baseline, G.club_name(club), 21, C.IVORY, 800 if mine else 600, 430)
	for column: Array in TABLE_COLUMNS:
		var key: String = column[3]
		var value := _standing_text(club, key)
		var tint: Color = C.IVORY if value != "—" else C.MUTED
		var caption := D.text(row, column[1], baseline, value, 21 if key in ["rank", "points"] else 19, tint, 800 if mine or key in ["rank", "points"] else 500, column[2], HORIZONTAL_ALIGNMENT_CENTER)
		if key in ["won", "drawn", "lost"]:
			caption.name = "StandingCount_" + key
			caption.set_meta("outcome_code", column[0])
	_recent_form(row, club.get("form"), 1292, (stride - 26) / 2.0)

func _standing_text(club: Dictionary, key: String) -> String:
	if key == "difference":
		var difference := S.difference_text(club.get("pf"), club.get("pa"))
		return "+" + difference if difference != "—" and int(difference) > 0 else difference
	if key == "rank" and not P.standings_open(club): return "–"
	if key == "points": return S.number_text(club.get(key))
	return S.count_text(club.get(key))

## Légende des zones : une ligne par zone (liseré, symbole dessiné, rang et mot), toujours visible sous le tableau.
## Le texte lu porte le symbole Unicode du moteur (« ★ 1–2 Demi-finale directe »).
func _zone_legend(parent: Node, zones: Array, x: float, top: float) -> Control:
	var group := Control.new()
	group.name = "StandingsZoneLegend"
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(group)
	D.place(group, Rect2(x, top, LEFT - 2 * x, zones.size() * 30))
	var spoken: Array[String] = []
	for i in zones.size():
		var zone: Dictionary = zones[i]
		var kind := str(zone.get("kind", ""))
		var from := int(zone.get("from", 0))
		var to := int(zone.get("to", 0))
		var span := str(from) if from == to else "%d–%d" % [from, to]
		var spoken_span := _ordinal(from) if from == to else "%s à %s" % [_ordinal(from), _ordinal(to)]
		spoken.append(str(zone.get("symbol", "")) + " " + span + " " + str(zone.get("label", "")))
		var line := i * 30
		var edge := D.rect(group, Rect2(0, line + 3, 4, 24), Zones.tint(kind))
		edge.name = "StandingsZoneLegendEdge_%d" % i
		var side := Zones.mark_side()
		var mark := Zones.mark(group, kind, Rect2(16, line + 15 - side / 2.0, side, side), Zones.tint(kind))
		mark.name = "StandingsZoneLegendMark_" + kind
		var label := D.text(group, 44, line + 21, spoken_span + "  ·  " + str(zone.get("label", "")), 19, C.IVORY, 600)
		label.name = "StandingsZoneLegendItem_%d" % i
		label.set_meta("zone_kind", kind)
	group.set_meta("legend_text", " · ".join(spoken))
	group.accessibility_name = "Zones du classement : " + " · ".join(spoken)
	group.tooltip_text = group.accessibility_name
	return group

## Plaque inclinée aux couleurs d'un club (10°, rayon 0) : écusson, nom ; un clic ouvre la fiche du club.
class Plaque extends Button:
	var couleur := Color.WHITE
	var droite := false

	func _draw() -> void:
		# Charte finale : tuile arrondie avec ombre ; camps en vert clair (nous) et doré (adversaire), jamais la couleur du club.
		var style := StyleBoxFlat.new()
		style.bg_color = couleur
		style.set_corner_radius_all(Charte.RAYON_CARTE)
		style.anti_aliasing = true
		Charte.ombrer(style, Charte.RAYON_CARTE)
		if has_focus() or is_hovered():
			style.border_color = Charte.OR
			style.set_border_width_all(2)
		draw_style_box(style, Rect2(Vector2.ZERO, size))

func _plaque(parent: Node, area: Rect2, club: Dictionary, id: String, right: bool) -> Button:
	var plaque := Plaque.new()
	plaque.name = id
	plaque.flat = true
	plaque.set_meta("immersive_style_applied", true)
	var nous := str(club.get("id", "")) == str(app.model.get("club", {}).get("id", "-"))
	plaque.couleur = Charte.VOILE_VERT if nous else Charte.VOILE_DORE
	plaque.droite = right
	for look in ["normal", "hover", "pressed", "disabled", "focus"]: plaque.add_theme_stylebox_override(look, StyleBoxEmpty.new())
	parent.add_child(plaque)
	D.place(plaque, area)
	var ink := Charte.VERT_CLAIR if nous else Charte.DORE
	_crest(plaque, club, Rect2(22 if not right else 20, 8, 48, 48))
	var short_name := str(G.identity(club).get("shortName", ""))
	var plate_name := short_name if C.dense() and not short_name.is_empty() else G.club_name(club)
	# Le nom reste dans la plaque : une ligne qui se resserre ; en 1280, deux lignes qui montent depuis le bas de la plaque.
	var two_lines := C.dense()
	D.fit_title(D.text(plaque, 80, area.size.y - 10 if two_lines else area.size.y / 2.0 + 8, plate_name.to_upper(), 24, ink, 800, area.size.x - 100), area.size.x - 100, area.size.y - 12, 2 if two_lines else 1, 12)
	var target := {"kind":"club", "id":str(club.get("id", ""))}
	if target_available(app, "club", club.get("id", "")): Link.bind(plaque, app, target, "Ouvrir le club · " + G.club_name(club))
	else:
		plaque.focus_mode = Control.FOCUS_NONE
		plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return plaque

func _carte(parent: Node, area: Rect2, title: String, id: String) -> Panel:
	return _panel(parent, area, title, "", id)

func _colonne_droite() -> void:
	var y := float(TOP)
	y = _ta_place(y) + GAP
	y = _prochain(y) + GAP
	y = _calendrier_club(y)
	right_bottom = y

## Ta place : rang, points, zone, et les trois écarts (sur le premier, sur le club devant, sur le club derrière).
func _ta_place(y: float) -> float:
	var card := _carte(self, Rect2(LEFT + GAP, y, RIGHT, 300), "TA PLACE", "CompetitionPlace")
	var row := _own_row()
	if row.is_empty() or not P.standings_open(row):
		D.text(card, 24, 100, "Pas encore de classement.", 24, C.MUTED, 600, RIGHT - 48)
		return y + 300
	var rank := int(row.get("rank", 0))
	var rank_label := D.text(card, 24, 116, _ordinal(rank), 68, C.IVORY, 800, 0)
	rank_label.add_theme_font_override("font", Charte.TITRE_EXTRA)
	rank_label.name = "CompetitionPlaceRank"
	var rank_w := rank_label.size.x / C.density
	var points := D.text(card, 24 + rank_w + 18, 114, "%s pts" % S.number_text(row.get("points")), 44, C.IVORY, 800, 0)
	points.add_theme_font_override("font", Charte.TITRE_GRAS)
	D.text(card, 24, 148, "%s V  ·  %s N  ·  %s D  ·  diff. %s" % [S.count_text(row.get("won")), S.count_text(row.get("drawn")), S.count_text(row.get("lost")), _standing_text(row, "difference")], 19, C.MUTED, 500, RIGHT - 48)
	var zone: Dictionary = Zones.of(row)
	if not zone.is_empty():
		var kind := str(zone.get("kind", ""))
		D.rect(card, Rect2(24, 162, 4, 26), Zones.tint(kind)).name = "CompetitionPlaceZoneEdge"
		var side := Zones.mark_side()
		Zones.mark(card, kind, Rect2(40, 175 - side / 2.0, side, side), Zones.tint(kind))
		var zone_text := D.text(card, 64, 182, "Dans la zone : " + str(zone.get("label", "")), 20, C.IVORY, 600, RIGHT - 88)
		zone_text.name = "CompetitionPlaceZone"
	# Les trois écarts : premier, club juste devant, club juste derrière.
	var ranked: Array = _own_league_rows().filter(func(club: Dictionary): return P.standings_open(club))
	ranked.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("rank", 0)) < int(b.get("rank", 0)))
	var gaps: Array = []
	var seen := {}
	var picks: Array = []
	if not ranked.is_empty(): picks.append(ranked[0])
	for club: Dictionary in ranked:
		if int(club.get("rank", 0)) == rank - 1: picks.append(club)
		if int(club.get("rank", 0)) == rank + 1: picks.append(club)
	for club: Dictionary in picks:
		if club.id == own.id or seen.has(club.id): continue
		seen[club.id] = true
		gaps.append(club)
	var tile_w := (RIGHT - 48 - 2 * 12) / 3.0
	for i in mini(gaps.size(), 3):
		var club: Dictionary = gaps[i]
		var delta := int(float(row.get("points", 0)) - float(club.get("points", 0)))
		var tile_x := 24 + i * (tile_w + 12)
		var tile := D.rect(card, Rect2(tile_x, 206, tile_w, 84), Charte.PANNEAU_2, Charte.RAYON_CARTE)
		tile.name = "CompetitionGap_%d" % i
		var signed := "+%d" % delta if delta > 0 else str(delta)
		var value := D.text(tile, 14, 40, signed, 40, C.IVORY, 800, tile_w - 20)
		value.add_theme_font_override("font", Charte.TITRE_GRAS)
		D.text(tile, 14, 58, "sur le %s" % _ordinal(int(club.get("rank", 0))), 16, C.MUTED, 600, tile_w - 20)
		D.fit_title(D.text(tile, 14, 78, G.club_name(club), 16, C.MUTED, 500, tile_w - 20), tile_w - 20, 30, 2, 13)
		D.text(tile, tile_w - 14, 40, "→", 24, C.MUTED, 700, 30, HORIZONTAL_ALIGNMENT_RIGHT)
		var link := _entity_area(tile, Rect2(0, 0, tile_w, 84), {"kind":"club", "id":str(club.id)}, "CompetitionGapLink_%d" % i, "Ouvrir le club · " + G.club_name(club))
		if link != null: link.tooltip_text = "Ouvrir le club · " + G.club_name(club)
	return y + 300

## Libellés du rendez-vous quand aucune rencontre du championnat n'est à venir (exempt, préparation, saison terminée).
func _rendez_vous_sans_match() -> Dictionary:
	var upcoming := P.next_nationale_fixture(app.model)
	if not upcoming.is_empty():
		return {"chip": "SEMAINE EXEMPTE", "title": Office.scheduled_opponent(app, upcoming), "when": Office.scheduled_when(app, upcoming), "venue": Office.scheduled_venue(app, upcoming), "button": app.primary_text().trim_suffix("  →"), "action": app.primary_action, "id": "CompetitionAdvanceWeek", "title_name": "UpcomingOpponent"}
	var japan := SeasonPreparation.is_japan(app.model.meta)
	var preparation := SeasonPreparation.data(app.model.meta)
	if not preparation.is_empty():
		if SeasonPreparation.is_champ(app.model.meta):
			var fixture := P.next_scheduled_fixture(app.model)
			if fixture.is_empty():
				return {"chip": "", "title": "Préparation · " + World.name_for(app.model, "champ"), "when": World.preparation_note(preparation), "venue": "", "button": app.primary_text().trim_suffix("  →"), "action": app.primary_action, "id": "CompetitionChampAdvance", "title_name": "UpcomingOpponent"}
			return {"chip": "PRÉPARATION", "title": Office.scheduled_opponent(app, fixture), "when": Office.scheduled_when(app, fixture), "venue": Office.scheduled_venue(app, fixture), "button": app.primary_text().trim_suffix("  →"), "action": app.primary_action, "id": "CompetitionChampAdvance", "title_name": "UpcomingOpponent"}
		return {"chip": "", "title": "Préparation · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))), "when": World.preparation_note(preparation), "venue": "", "button": "Ouvrir le dossier de préparation", "action": func(): app.Immersive.open_preparation(app, 0), "id": "CompetitionJapanLink" if japan else "CompetitionPacificLink", "title_name": "UpcomingOpponent"}
	var scheduled := P.next_fixture(app.model)
	if not scheduled.is_empty():
		return {"chip": "PROCHAINE RENCONTRE", "title": Office.scheduled_opponent(app, scheduled), "when": Office.scheduled_when(app, scheduled), "venue": Office.scheduled_venue(app, scheduled), "button": app.primary_text().trim_suffix("  →"), "action": app.primary_action, "id": "CompetitionScheduledAdvance", "title_name": "UpcomingOpponent"}
	return {"chip": "", "title": "Aucune rencontre programmée", "when": str(app.model.meta.get("roundLabel", "")), "venue": "", "button": "Voir le calendrier du club", "action": func(): _switch("calendar"), "id": "CompetitionCalendarLink", "title_name": ""}

func _prochain(y: float) -> float:
	var card := _carte(self, Rect2(LEFT + GAP, y, RIGHT, 330 if next_fixture.is_empty() else 430), "PROCHAIN RENDEZ-VOUS", "CompetitionNextFixture")
	if next_fixture.is_empty():
		var info := _rendez_vous_sans_match()
		if not str(info.chip).is_empty(): D.text(card, 24, 92, str(info.chip), 17, C.MUTED, 700, RIGHT - 48)
		var title := D.text(card, 24, 140, str(info.title), 36, C.IVORY, 800, RIGHT - 48)
		title.add_theme_font_override("font", Charte.TITRE_GRAS)
		if not str(info.title_name).is_empty(): title.name = str(info.title_name)
		var moment := D.text(card, 24, 184, str(info["when"]), 24, C.IVORY, 600, RIGHT - 48)
		if info.title_name == "UpcomingOpponent": moment.name = "UpcomingWhen"
		if not str(info.venue).is_empty(): D.text(card, 24, 222, "Lieu · " + str(info.venue), 20, C.MUTED, 500, RIGHT - 48, HORIZONTAL_ALIGNMENT_LEFT, true)
		_principal(card, Rect2(24, 262, RIGHT - 48, 52), str(info.button).to_upper() + "  →", info.action, str(info.id))
		return y + 330
	var home: Dictionary = next_fixture.get("home", {})
	var away: Dictionary = next_fixture.get("away", {})
	var caption := str(next_fixture.get("label", _phase(next_fixture)))
	var date := _date(next_fixture)
	D.text(card, 24, 86, caption.to_upper(), 17, C.MUTED, 700, RIGHT - 48)
	if date.is_empty():
		D.text(card, 24, 116, _location(next_fixture), 26, C.IVORY, 700, RIGHT - 48)
	else:
		var date_label := D.text(card, 24, 118, date, 27, C.IVORY, 700, RIGHT - 48)
		date_label.name = "CompetitionNextDate"
		D.line(card, Vector2(24, 124), Vector2(24 + date_label.get_theme_font("font").get_string_size(date, HORIZONTAL_ALIGNMENT_LEFT, -1, date_label.get_theme_font_size("font_size")).x / C.density, 124), Charte.IVOIRE_3)
		var date_link := _entity_area(card, Rect2(20, 92, RIGHT - 40, 34), {"kind":"date", "id":str(next_fixture.get("date", ""))}, "CompetitionNextDateLink", "Voir la date dans le calendrier · " + date)
		if date_link != null: date_link.size.y = maxf(C.px(34), maxf(date_link.size.y, ceilf(date_label.size.y)))
	var home_plate := _plaque(card, Rect2(24, 138, 290, 64), home, "CompetitionNextHome", false)
	D.text(card, 362, 176, "CONTRE", 18, C.MUTED, 700, 100, HORIZONTAL_ALIGNMENT_CENTER)
	var away_plate := _plaque(card, Rect2(410, 138, 290, 64), away, "CompetitionNextAway", true)
	home_plate.tooltip_text = home_plate.tooltip_text if not home_plate.tooltip_text.is_empty() else G.club_name(home)
	away_plate.tooltip_text = away_plate.tooltip_text if not away_plate.tooltip_text.is_empty() else G.club_name(away)
	var location := D.text(card, 24, 234, _location(next_fixture), 21, C.IVORY, 700, 0)
	var venue := _venue_name(next_fixture)
	if not venue.is_empty():
		var venue_label := D.text(card, 24 + location.size.x / C.density + 16, 234, venue, 21, C.MUTED, 500, RIGHT - 80 - location.size.x / C.density)
		venue_label.name = "CompetitionNextVenue"
	var opponent := away if home.get("id") == own.get("id") else home
	var mine := _own_row()
	var theirs: Dictionary = {}
	for club: Dictionary in _own_league_rows():
		if club.id == opponent.get("id"): theirs = club
	if not mine.is_empty() and not theirs.is_empty() and P.standings_open(mine) and P.standings_open(theirs):
		var gap := absi(int(float(mine.get("points", 0)) - float(theirs.get("points", 0))))
		D.text(card, 24, 268, "%s contre %s  ·  %d pt%s d’écart" % [_ordinal(int(mine.get("rank", 0))), _ordinal(int(theirs.get("rank", 0))), gap, "s" if gap > 1 else ""], 20, C.IVORY, 500, RIGHT - 48)
	if not mine.is_empty() and not theirs.is_empty():
		D.text(card, 24, 304, "FORME", 15, C.MUTED, 700, 70)
		_recent_form(card, mine.get("form"), 90, 284)
		D.text(card, 276, 304, "nous", 17, C.MUTED, 500, 50)
		_recent_form(card, theirs.get("form"), 340, 284)
		D.text(card, 526, 304, "eux", 17, C.MUTED, 500, 50)
	var previous := _previous_meeting(home, away)
	if not previous.is_empty():
		var recorded_id := str(previous.get("fixtureId", ""))
		var text := "Déjà joué cette saison : %s" % _meeting_text(previous)
		if target_available(app, "fixture", recorded_id):
			var meeting := _lien(card, Rect2(18, 322, RIGHT - 36, 36), text, func(): open_target(app, "fixture", recorded_id), "CompetitionLastMeeting", 19, true)
			meeting.tooltip_text = "Voir la rencontre"
		else: D.text(card, 24, 346, text, 19, C.MUTED, 500, RIGHT - 48, HORIZONTAL_ALIGNMENT_LEFT, true)
	var live: bool = not app._live().is_empty()
	var action := _principal(card, Rect2(24, 368, 330, 52), ("Rejoindre le match" if live else "Préparer le match").to_upper() + "  →", func(): app._navigate("Match" if live else "Préparation"), "CompetitionPrepareMatch")
	action.tooltip_text = "Préparer le match"
	if target_available(app, "club", opponent.get("id", "")):
		_lien(card, Rect2(380, 374, 320, 40), "Dossier adverse →", func(): open_target(app, "club", str(opponent.id)), "CompetitionOpponentFile", 20)
	return y + 430

func _previous_meeting(home: Dictionary, away: Dictionary) -> Dictionary:
	for result: Dictionary in season_results:
		var pair: Array = result.get("pair", [])
		if pair.size() == 2 and result.get("score") is Array and ((pair[0] == home.get("id") and pair[1] == away.get("id")) or (pair[0] == away.get("id") and pair[1] == home.get("id"))): return result
	return {}

func _meeting_text(result: Dictionary) -> String:
	var clubs := _matchup(result)
	var outcome := ""
	var pair: Array = result.get("pair", [])
	var score: Array = result.get("score", [])
	if score.size() == 2 and pair.size() == 2:
		var mine_index := 0 if pair[0] == own.get("id") else 1
		if score[mine_index] > score[1 - mine_index]: outcome = "victoire "
		elif score[mine_index] < score[1 - mine_index]: outcome = "défaite "
		else: outcome = "nul "
	return outcome + "%s %s %s" % [G.club_name(clubs[0]), _score(result), G.club_name(clubs[1])]

## Les six prochains rendez-vous du club : chaque ligne ouvre la rencontre, le club ou la date.
func _calendrier_club(y: float) -> float:
	var card := _carte(self, Rect2(LEFT + GAP, y, RIGHT, 340), "CALENDRIER DU CLUB", "CompetitionCalendarPreview")
	D.text(card, RIGHT - 24, 40, "6 prochains", 17, C.MUTED, 500, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	_lien(card, Rect2(RIGHT - 264, 296, 250, 36), "Toute la saison →", func(): _switch("calendar"), "OpenFullCalendar", 20, false, HORIZONTAL_ALIGNMENT_RIGHT)
	if fixtures.is_empty():
		D.text(card, 24, 112, "Aucun rendez-vous programmé.", 22, C.MUTED, 500, RIGHT - 48, HORIZONTAL_ALIGNMENT_LEFT, true)
		return y + 340
	for entry: Array in [[14, "J."], [74, "DATE"], [206, "ADVERSAIRE"], [444, "LIEU"], [546, "RANG"]]:
		D.text(card, entry[0], 78, entry[1], 14, C.MUTED, 700, 150)
	var anchor := fixtures.find_custom(func(fixture: Dictionary): return not fixture.get("played", false))
	var from := clampi(anchor - 1 if anchor >= 0 else fixtures.size() - 6, 0, maxi(0, fixtures.size() - 6))
	for i in mini(fixtures.size() - from, 6):
		_calendar_row(card, fixtures[from + i], 88 + i * 34, RIGHT, true)
	return y + 340

## Sous les tableaux : derniers résultats de la compétition, puis meilleure attaque et meilleure défense.
func _bas_gauche() -> void:
	var y := left_bottom + GAP
	var started: bool = league.get("rows", []).any(func(club: Dictionary): return float(club.get("played", 0)) > 0)
	if not started:
		_opening_strip(y)
		left_bottom = y + 211
		return
	var results: Array = season_results.filter(func(result: Dictionary): return _competition_id(result, league.id) == league.id and result.get("pair") is Array and result.get("score") is Array).slice(0, 5)
	var height := 70 + maxi(1, results.size()) * 34 + 12
	var recent := _panel(self, Rect2(0, y, LEFT, height), "DERNIERS RÉSULTATS", "", "CompetitionRecentResults")
	for i in results.size():
		var result: Dictionary = results[i]
		var clubs := _matchup(result)
		var top := 58 + i * 34
		var fixture_id := str(result.get("fixtureId", ""))
		var line := Button.new()
		line.name = "RecentResult_%d" % i
		line.set_meta("immersive_style_applied", true)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Charte.PANNEAU_2 if i % 2 == 1 else Charte.PANNEAU
		normal.set_corner_radius_all(Charte.RAYON_PETIT)
		var hover: StyleBoxFlat = normal.duplicate()
		hover.bg_color = Charte.PANNEAU_3
		line.add_theme_stylebox_override("normal", normal)
		line.add_theme_stylebox_override("hover", hover)
		line.add_theme_stylebox_override("pressed", hover)
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color(0, 0, 0, 0)
		focus.border_color = Charte.IVOIRE
		focus.set_border_width_all(2)
		focus.set_corner_radius_all(Charte.RAYON_PETIT)
		line.add_theme_stylebox_override("focus", focus)
		if target_available(app, "fixture", fixture_id):
			Link.bind(line, app, {"kind":"fixture", "id":fixture_id}, "Ouvrir la rencontre · %s %s %s" % [G.club_name(clubs[0]), _score(result), G.club_name(clubs[1])])
		else:
			line.focus_mode = Control.FOCUS_NONE
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		recent.add_child(line)
		D.place(line, Rect2(8, top, LEFT - 16, 32))
		D.text(line, 16, 23, _phase(result), 17, C.MUTED, 500, 220)
		D.text(line, 700, 23, G.club_name(clubs[0]), 21, C.IVORY, 700, 400, HORIZONTAL_ALIGNMENT_RIGHT)
		_crest(line, clubs[0], Rect2(716, 3, 26, 26))
		D.text(line, 800, 23, _score(result), 22, C.IVORY, 800, 120, HORIZONTAL_ALIGNMENT_CENTER)
		_crest(line, clubs[1], Rect2(868, 3, 26, 26))
		D.text(line, 904, 23, G.club_name(clubs[1]), 21, C.IVORY, 700, 420)
		_entity_area(line, Rect2(300, 0, 440, 32), {"kind":"club", "id":str(clubs[0].get("id", ""))}, "RecentHome_%d" % i, "Ouvrir le club · " + G.club_name(clubs[0]))
		_entity_area(line, Rect2(864, 0, 460, 32), {"kind":"club", "id":str(clubs[1].get("id", ""))}, "RecentAway_%d" % i, "Ouvrir le club · " + G.club_name(clubs[1]))
	if results.is_empty(): D.text(recent, 24, 100, "Aucun résultat enregistré pour cette division.", 22, C.MUTED, 500, LEFT - 48, HORIZONTAL_ALIGNMENT_LEFT, true)
	y += height + GAP
	var half := (LEFT - GAP) / 2.0
	_leader(Rect2(0, y, half, 130), "MEILLEURE ATTAQUE", "pf", "Points marqués", true)
	_leader(Rect2(half + GAP, y, half, 130), "MEILLEURE DÉFENSE", "pa", "Points encaissés", false)
	left_bottom = y + 130

## Avant la première journée : le coup d’envoi et le format de la saison remplacent les classements vides.
func _opening_strip(y: float) -> void:
	var panel := _panel(self, Rect2(0, y, LEFT, 211), "L’OUVERTURE DE LA SAISON", "", "CompetitionOpeningStrip")
	var first := fixtures.filter(func(fixture: Dictionary): return not fixture.get("played", false))
	var rounds := 0
	for fixture: Dictionary in fixtures:
		if _competition_id(fixture, league.id) == league.id and own.get("id") in [fixture.get("home", {}).get("id"), fixture.get("away", {}).get("id")]: rounds += 1
	var facts: Array = [["COUP D’ENVOI", "" if first.is_empty() else _date(first[0]), ""],
		["LE CHAMPIONNAT", "%s clubs" % G.n(league.get("rows", []).size()), "%s journées à jouer" % G.n(rounds) if rounds > 0 else ""],
		["À SUIVRE", "Attaque · défense", ""]]
	var tile_w := (LEFT - 48 - 2 * 14) / 3.0
	for i in facts.size():
		var tile := D.rect(panel, Rect2(24 + i * (tile_w + 14), 62, tile_w, 134), Charte.PANNEAU_2, Charte.RAYON_CARTE)
		D.text(tile, 18, 32, facts[i][0], 16, C.MUTED, 700, tile_w - 30)
		D.text(tile, 18, 76, facts[i][1] if not str(facts[i][1]).is_empty() else "À venir", 34, C.IVORY, 800, tile_w - 30)
		D.text(tile, 18, 112, facts[i][2], 17, C.MUTED, 500, tile_w - 30, HORIZONTAL_ALIGNMENT_LEFT, true)

func _leader(area: Rect2, title: String, metric: String, caption: String, high: bool) -> void:
	var panel := _panel(self, area, title, "", "CompetitionLeader_" + metric)
	var best: Dictionary = {}
	var tied := 0
	for club: Dictionary in league.get("rows", []):
		if float(club.get("played", 0)) <= 0 or S.count_text(club.get(metric)) == "—": continue
		if best.is_empty() or (float(club[metric]) > float(best[metric]) if high else float(club[metric]) < float(best[metric])):
			best = club
			tied = 1
		elif club[metric] == best[metric]:
			tied += 1
	if not best.is_empty(): _crest(panel, best, Rect2(24, 56, 64, 64))
	var club_name := D.text(panel, 106, 82, "Donnée à venir" if best.is_empty() else G.club_name(best), 26, C.IVORY, 700, area.size.x - 330)
	D.text(panel, 106, 110, caption + (" · %d ex æquo" % tied if tied > 1 else ""), 18, C.MUTED, 500, area.size.x - 330, HORIZONTAL_ALIGNMENT_LEFT, true)
	var value := D.text(panel, area.size.x - 24, 108, S.count_text(best.get(metric)), 56, C.IVORY, 800, 180, HORIZONTAL_ALIGNMENT_RIGHT)
	value.add_theme_font_override("font", Charte.TITRE_EXTRA)
	if not best.is_empty():
		var link := _entity_area(panel, Rect2(16, 50, area.size.x - 220, 76), {"kind":"club", "id":str(best.id)}, "CompetitionLeaderLink_" + metric, "Ouvrir le club · " + G.club_name(best))
		if link != null: club_name.tooltip_text = G.club_name(best)

func _filtre(parent: Node, area: Rect2, caption: String, selected: bool, callback: Callable, id: String) -> Button:
	var button := _lien(parent, area, caption, callback, id, 21, selected)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, Charte.IVOIRE if selected else Charte.IVOIRE_2)
	button.add_theme_color_override("font_hover_color", Charte.IVOIRE)
	button.set_meta("selected", selected)
	return button

func _calendar() -> void:
	var panel := _panel(self, Rect2(0, TOP, LEFT, 760), "TOUTE LA SAISON · CALENDRIER DU CLUB", "", "CalendarScroll")
	left_bottom = TOP + 760
	var selected := str(state.get("calendar_filter", "all"))
	var x := 24
	for spec: Array in [[170, "Tous les matchs", "all"], [120, "À jouer", "upcoming"], [120, "Résultats", "played"]]:
		_filtre(panel, Rect2(x, 62, spec[0], 40), spec[1], selected == spec[2], func():
			state.calendar_filter = spec[2]
			_page_state("CalendarPagination").page = 0
			app._render(false), "CalendarFilter_" + str(spec[2]))
		x += int(spec[0]) + 12
	var visible := fixtures.filter(func(fixture: Dictionary): return selected == "all" or bool(fixture.get("played", false)) == (selected == "played"))
	D.text(panel, LEFT - 24, 88, P.plural(visible.size(), "rencontre", "rencontres"), 20, C.MUTED, 500, 240, HORIZONTAL_ALIGNMENT_RIGHT)
	var period := "DATE / PHASE" if international else "JOURNÉE / PHASE"
	for spec: Array in [[19, period, 230], [296, "ADVERSAIRE", 430], [720, "LIEU", 228], [954, "COMPÉTITION", 185], [LEFT - 157, "RÉSULTAT", 140]]:
		D.text(panel, spec[0], 134, spec[1], 15, C.MUTED, 700, spec[2])
	D.line(panel, Vector2(9, 142), Vector2(LEFT - 9, 142), Charte.FILET)
	# Toute la saison sur une page qui défile (décision de Léo) : plus de pagination.
	var panel_h := 210 + 48 * maxi(1, visible.size()) + 40
	panel.size.y = C.px(panel_h)
	left_bottom = TOP + panel_h
	for i in visible.size():
		_calendar_row(panel, visible[i], 148 + 48 * i, LEFT, false)
	if visible.is_empty(): D.text(panel, 23, 219, "Aucune rencontre", 24, C.MUTED, 500, LEFT - 47, HORIZONTAL_ALIGNMENT_LEFT, true)
	_result_legend(panel, 24, panel_h - 48)

## Date courte « 21/11 » d'une rencontre (vide sans date ISO).
func _short_date(fixture: Dictionary) -> String:
	var raw := str(fixture.get("date", ""))
	if raw.length() >= 10 and raw[4] == "-" and raw[7] == "-": return "%s/%s" % [raw.substr(8, 2), raw.substr(5, 2)]
	return ""

## Code court de la journée ou de la phase (« J9 », « DF », « F »).
func _round_code(fixture: Dictionary) -> String:
	var phase := str(fixture.get("phase", "league"))
	if phase in ["league", "pool"]:
		var label := _fixture_label(fixture)
		if label.begins_with("Journée "): return "J" + label.trim_prefix("Journée ")
		var round_value: Variant = fixture.get("competitionRound")
		if round_value is int or round_value is float: return "J%d" % (int(round_value) + 1)
		return "J" + str(int(fixture.get("week", 0)) + 1)
	return {"semi": "DF", "final": "F", "quarter": "QF", "r16": "8e", "barrage": "Bar.", "elimination": "Bar.", "access": "Acc.", "cup": "Cpe", "third-place": "3e"}.get(phase, _phase(fixture).left(4))

func _calendar_row(parent: Node, fixture: Dictionary, y: float, width: float, compact: bool) -> void:
	var home: Dictionary = fixture.get("home", {})
	var away: Dictionary = fixture.get("away", {})
	var is_home: bool = home.get("id") == own.id
	var opponent := away if is_home else home
	var played: bool = fixture.get("played", false)
	var current := _is_next(fixture)
	var line_height := 34 if compact else 48
	var date := _date(fixture)
	var venue := _venue_name(fixture)
	var competition := _competition_name(fixture)
	var period := _fixture_label(fixture) if date.is_empty() else date
	var row := Button.new()
	row.name = "CalendarFixture_" + str(fixture.get("id", y))
	row.set_meta("fixture_id", str(fixture.get("id", "")))
	row.set_meta("immersive_style_applied", true)
	var competition_id := _competition_id(fixture)
	var dated_competition := competition_id in JAPAN_COMPETITIONS or competition_id in ["nationale","access-nationale","champ"]
	var timing := P.fixture_date(fixture, true) + " · " + _dated_phase(fixture) if not date.is_empty() and dated_competition else period
	row.accessibility_name = "%s · %s · %s · %s" % [timing,G.club_name(opponent),_location(fixture),competition]
	if not venue.is_empty() and venue != _location(fixture):
		row.accessibility_name += " · " + venue
	row.tooltip_text = row.accessibility_name
	var normal := StyleBoxFlat.new()
	normal.bg_color = Charte.PANNEAU_3 if current else Charte.PANNEAU
	normal.set_corner_radius_all(Charte.RAYON_PETIT)
	if current:
		normal.border_color = Charte.IVOIRE
		normal.border_width_left = maxi(3, C.px(4))
	var hover := StyleBoxFlat.new()
	hover.bg_color = Charte.PANNEAU_3
	hover.set_corner_radius_all(Charte.RAYON_PETIT)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Charte.IVOIRE
	focus.set_border_width_all(maxi(2, C.px(2)))
	focus.set_corner_radius_all(Charte.RAYON_PETIT)
	row.add_theme_stylebox_override("normal", normal)
	row.add_theme_stylebox_override("hover", hover)
	row.add_theme_stylebox_override("pressed", hover)
	row.add_theme_stylebox_override("focus", focus)
	if target_available(app, "fixture", fixture.get("id", "")):
		Link.bind(row, app, {"kind":"fixture", "id":str(fixture.get("id", ""))}, "Ouvrir la rencontre · " + row.accessibility_name)
	else:
		row.focus_mode = Control.FOCUS_NONE
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	D.place(row, Rect2(2, y, width - 4, line_height))
	D.line(row, Vector2(9, line_height - 1), Vector2(width - 15, line_height - 1), Color(C.LINE, .75))
	var middle := line_height / 2.0 + 7
	var fid := str(fixture.get("id", y)).validate_node_name()
	if compact:
		D.text(row, 12, middle, _round_code(fixture), 19, C.MUTED, 700, 66)
		var short_label := D.text(row, 72, middle, _short_date(fixture) if not _short_date(fixture).is_empty() else _fixture_label(fixture), 19, C.IVORY, 600, 0)
		if not date.is_empty(): D.line(row, Vector2(72, middle + 4), Vector2(72 + short_label.size.x / C.density, middle + 4), Charte.IVOIRE_3)
		_crest(row, opponent, Rect2(170, (line_height - 26) / 2.0, 26, 26))
		D.text(row, 204, middle, G.club_name(opponent), 20, C.IVORY, 700, 236)
		D.text(row, 444, middle, _location(fixture, true), 19, C.MUTED, 500, 96)
		var theirs := 0
		for club: Dictionary in _own_league_rows():
			if club.id == opponent.get("id") and P.standings_open(club): theirs = int(club.get("rank", 0))
		if theirs > 0: D.text(row, 546, middle, _ordinal(theirs), 19, C.MUTED, 500, 46)
		var code := _fixture_outcome(fixture)
		var score := _score(fixture, own.id)
		if played: _result_badge(row, Rect2(width - 124, (line_height - 28) / 2.0, 108, 28), code, code + " " + score if code != "—" else score)
		else:
			var tag := D.text(row, width - 16, middle, "À jouer →" if current else "—", 19, C.IVORY if current else C.MUTED, 700, 110, HORIZONTAL_ALIGNMENT_RIGHT)
			tag.name = "CalendarToPlay_" + fid
			if current:
				# La flèche promet l'action : « À jouer → » ouvre la Préparation (ou le direct).
				var go := Button.new()
				go.name = "CalendarPrepare_" + fid
				go.flat = true
				go.set_meta("immersive_style_applied", true)
				go.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
				go.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				go.tooltip_text = "Préparer le match"
				go.pressed.connect(func(): app._navigate("Match" if not app._live().is_empty() else "Préparation"))
				row.add_child(go)
				D.place(go, Rect2(width - 140, 0, 136, line_height))
		_entity_area(row, Rect2(166, 0, 278, line_height), {"kind":"club", "id":str(opponent.get("id", ""))}, "CalendarOpponent_" + fid, "Ouvrir le club · " + G.club_name(opponent))
		if not date.is_empty():
			_entity_area(row, Rect2(8, 0, 156, line_height), {"kind":"date", "id":str(fixture.get("date", ""))}, "CalendarDate_" + fid, "Voir la date dans le calendrier · " + date)
		return
	if date.is_empty():
		D.text(row, 16, middle, period, 23, C.IVORY, 500, 232)
	else:
		var date_label := D.text(row, 16, middle - 7, date, 21, C.IVORY, 600, 232)
		date_label.name = "CalendarFixtureDate"
		D.text(row, 16, middle + 11, _dated_phase(fixture), 16, C.MUTED, 500, 232)
	var emblem_x := 250
	_crest(row, opponent, Rect2(emblem_x, (line_height - 34) / 2.0, 34, 34))
	D.text(row, emblem_x + 45, middle, G.club_name(opponent), 24, C.IVORY, 600, 400)
	_entity_area(row, Rect2(emblem_x, 0, 445, line_height), {"kind":"club", "id":str(opponent.get("id", ""))}, "CalendarOpponent_" + fid, "Ouvrir le club · " + G.club_name(opponent))
	if not date.is_empty():
		_entity_area(row, Rect2(12, 0, 232, line_height), {"kind":"date", "id":str(fixture.get("date", ""))}, "CalendarDate_" + fid, "Voir la date dans le calendrier · " + date)
	var place_x := 720
	var location_kind := _location_kind(fixture)
	_icon(row, C.fixture_location_icon(location_kind), Rect2(place_x, (line_height - 18) / 2.0, 18, 18), C.MUTED)
	var venue_parts := venue.split(" · ",false,1)
	if venue_parts.size() == 2:
		D.text(row,place_x+25,middle-7,venue_parts[0],21,C.IVORY,600,204)
		D.text(row,place_x+25,middle+11,venue_parts[1],16,C.MUTED,500,204)
	else:
		D.text(row,place_x+25,middle,venue if not venue.is_empty() else _location(fixture),21,C.IVORY,500,204)
	D.text(row,954,middle,World.short_name(_competition_id(fixture),competition,app.model),21,C.MUTED,500,185)
	_entity_area(row, Rect2(954,0,185,line_height), {"kind":"competition", "id":competition_id}, "CalendarCompetition_" + fid, "Voir le classement · " + competition)
	var result_x := width - 157
	var code := _fixture_outcome(fixture)
	var score := _score(fixture, own.id)
	if played:
		_result_badge(row, Rect2(result_x, (line_height - 32) / 2.0, width - result_x - 14, 32), code, code + " " + score if code != "—" else score)
	else:
		_box_tag(row, Rect2(result_x, (line_height - 32) / 2.0, width - result_x - 14, 32), "À jouer", Charte.IVOIRE if current else Charte.IVOIRE_2)

func _playoffs() -> void:
	var panel := _panel(self, Rect2(0, TOP, LEFT, 760), "PHASES FINALES – " + _league_short(league).to_upper(), "trophy", "CompetitionPlayoffsPanel")
	_division_menu(panel, 24, 66, 540)
	var japanese: bool = league.id in ["jlo-d1", "jlo-d2"]
	var phases: Array = season_results.filter(func(result: Dictionary):
		var competition := _competition_id(result, league.id)
		return _knockout(result) and (competition == league.id
			or (japanese and competition == "jlo-d1-d2")
			or (result.get("phase") == "access" and competition != "access-nationale" and league.id in ["elite", "accession"])
			or (competition == "access-nationale" and league.id in ["nationale", "accession"])))
	var panel_h := 270 + 54 * maxi(1, phases.size())
	panel.size.y = C.px(panel_h)
	left_bottom = TOP + panel_h
	if league.get("champion") is Dictionary:
		_icon(panel, "trophy", Rect2(22, 121, 51, 51), WARM)
		D.text(panel, 89, 156, "CHAMPION · " + G.club_name(league.champion).to_upper(), 36, WARM, 800, 1180)
		if league.get("finalist") is Dictionary:
			D.text(panel, 89, 188, "Finaliste · " + G.club_name(league.finalist), 25, C.IVORY, 500, 1160, HORIZONTAL_ALIGNMENT_LEFT, true)
	else:
		D.text(panel, 21, 154, "Les affiches se précisent au fil de la saison.", 30, C.IVORY, 700, 1250)
		# Les phases citées sont celles que le moteur a déjà publiées pour cette compétition (jamais de règlement figé).
		var stages: Array[String] = []
		for result: Dictionary in phases:
			var stage_name := _phase(result).get_slice(" · ", 0)
			if stage_name not in stages: stages.append(stage_name)
		if not stages.is_empty(): D.text(panel, 22, 185, " · ".join(stages), 23, C.MUTED, 500, 1250, HORIZONTAL_ALIGNMENT_LEFT, true)
	if phases.is_empty(): D.text(panel, 23, 244, "Aucun résultat de phase finale conservé cette saison.", 27, C.MUTED, 500, 1230, HORIZONTAL_ALIGNMENT_LEFT, true)
	for i in phases.size():
		var result: Dictionary = phases[i]
		var card := _bande(panel, Rect2(16, 218 + i * 54, LEFT - 32, 47))
		var competition := _competition_id(result)
		var nationale := competition in ["nationale", "access-nationale"]
		var stage_width := 304 if japanese or competition == "access-nationale" else 210
		var stage := Club.competition_name(competition, app.model) if competition == "access-nationale" else _phase(result)
		var show_details := nationale or competition in ["champ", "champions", "challenge"]
		var timing := _date(result) if show_details else ""
		if show_details and result.get("neutral", false):
			timing = timing + " · Neutre" if not timing.is_empty() else "Terrain neutre"
		D.text(card, 14, 31 if timing.is_empty() else 22, stage, 24, WARM, 600, stage_width)
		if not timing.is_empty(): D.text(card, 14, 41, timing, 18, C.MUTED, 600, stage_width)
		var matchup := _matchup(result)
		var score: Variant = result.get("score")
		var winner: Variant = result.get("winner")
		var tiebreak: bool = show_details and score is Array and score.size() == 2 and score[0] == score[1] and identities.has(winner)
		D.text(card, stage_width + 18, 22 if tiebreak else 31, G.club_name(matchup[0]) + "  –  " + G.club_name(matchup[1]), 25, C.IVORY, 600, 1054 - stage_width)
		if tiebreak:
			D.text(card, stage_width + 18, 41, "%s après départage" % G.club_name(identities[winner]), 18, C.MUTED, 600, 1054 - stage_width)
		D.text(card, LEFT - 57, 31, _score(result), 27, C.IVORY, 700, 142, HORIZONTAL_ALIGNMENT_RIGHT)
		_entity_area(card, Rect2(0, 0, LEFT - 32, 47), {"kind":"fixture", "id":str(result.get("fixtureId", ""))}, "PlayoffFixture_%d" % i, "Ouvrir la rencontre")

func _stats() -> void:
	var panel := _panel(self, Rect2(0, TOP, LEFT, 760), "STATISTIQUES – " + _league_short(league).to_upper(), "flag", "CompetitionStatsPanel")
	_division_menu(panel, 24, 66, 540)
	var rows: Array = league.get("rows", [])
	var own_row: Dictionary = {}
	for row: Dictionary in rows:
		if row.get("id") == own.id:
			own_row = row
			break
	var summary := _section(panel, Rect2(16, 124, LEFT - 32, 269), "NOTRE CLUB · BILAN DES POULES" if league.has("pools") else "NOTRE CLUB · BILAN DU CHAMPIONNAT", "shield", "StandingsContext")
	_crest(summary, own, Rect2(18, 67, 93, 93))
	var club_label := D.text(summary, 132, 104, G.club_name(own), 37, C.IVORY, 800, 1100)
	club_label.name = "StandingsContextClubName"
	D.text(summary, 135, 142, ("Rang " + S.count_text(own_row.get("rank")) if P.standings_open(own_row) else "Pas encore de classement") + "  ·  " + S.number_text(own_row.get("points")) + " pts  ·  " + S.count_text(own_row.get("played")) + " matchs", 26, C.MUTED, 500, 1080)
	for i in 3:
		var code: String = ["V", "N", "D"][i]
		var quantity := S.count_text(own_row.get(["won", "drawn", "lost"][i]))
		_result_badge(summary, Rect2(135 + 166 * i, 161, 148, 43), code, quantity + " " + str(S.RESULTS[code].plural).to_lower(), quantity != "—")
	_recent_form(summary, own_row.get("form"), 132, 219)
	var rows_played := rows.filter(func(row: Dictionary): return float(row.get("played", 0)) > 0)
	var aggregate := _section(panel, Rect2(16, 411, LEFT - 32, 294), "CHIFFRES DE LA PHASE DE POULES" if league.has("pools") else "CHIFFRES DE LA PHASE RÉGULIÈRE", "trophy", "CompetitionLeagueStats")
	var games := 0
	var points := 0
	var draw_count := 0
	for club: Dictionary in rows_played:
		games += int(club.get("played", 0))
		points += int(club.get("pf", 0))
		draw_count += int(club.get("drawn", 0))
	var game_count := games / 2.0
	var values: Array = [G.n(game_count), G.n(points), G.n(draw_count / 2.0), "%.1f" % (points / game_count) if game_count > 0 else "—"]
	for i in 4:
		var x := 26 + i * 309
		_tuile(aggregate, Rect2(x, 70, 288, 127))
		D.text(aggregate, x + 22, 112, ["Matchs joués", "Points marqués", "Matchs nuls", "Points / match"][i], 26, C.MUTED, 500, 254)
		D.text(aggregate, x + 22, 170, values[i], 61, C.IVORY, 800, 253)


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
		content.add_child(C.wrap("%s · %s / %s — %s / %s" % [item[0], S.count_text(stats[0].get(item[1])), S.count_text(stats[0].get(item[2])), S.count_text(stats[1].get(item[1])), S.count_text(stats[1].get(item[2]))], 22, C.MUTED))

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
