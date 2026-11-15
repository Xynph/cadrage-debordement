extends Control
## Fiche d'un club (demande de Léo, 14/11/2026) : vue d'ensemble, effectif, XV type (celui qui revient
## le plus), statistiques et actions. Ouverte par tout nom de club cliquable (entity_link.gd, cible
## {"kind":"club"}) et par la recherche Ctrl K ; le club du manager ouvre son écran « Club ».
## Données : commande moteur en lecture seule `club_sheet` (native/engine/club-sheet.cjs), mise en
## cache par club et par instant de carrière ; la connaissance des joueurs (niveau, potentiel) est
## déjà appliquée par le moteur. Coordonnées de référence 2248 × 1240 (gabarit immersif).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Club = preload("res://ui/club_views.gd")
const Link = preload("res://ui/entity_link.gd")
const Knowledge = preload("res://ui/player_knowledge_text.gd")
const EquipeType = preload("res://ui/equipe_type_view.gd")
const Notes = preload("res://ui/notes_match.gd")
const ROUTE := "Fiche club"
const WIDTH := 2248
const HEIGHT := 1240
const TABS := ["Vue d’ensemble", "Effectif", "XV type", "Statistiques"]
const TAB_ICONS := ["shield", "people", "tactic", "trophy"]
## Ordre des postes dans l'effectif (numéro du maillot de référence).
const POSITION_ORDER := {"Pilier gauche":1, "Talonneur":2, "Pilier droit":3, "Deuxième ligne":4, "Troisième ligne":6, "Numéro 8":8, "Demi de mêlée":9, "Demi d’ouverture":10, "Ailier":11, "Centre":12, "Arrière":15}
const WIN := Color("54de81")
const DRAW := Color("a9b2b0")
const LOSS := Color("ef8477")
const TINTS := {"V": WIN, "N": DRAW, "D": LOSS}
const COUNTRIES := {"FR":"France", "GB":"Royaume-Uni", "IE":"Irlande", "IT":"Italie", "ZA":"Afrique du Sud", "NZ":"Nouvelle-Zélande", "AU":"Australie", "JP":"Japon", "FJ":"Fidji", "GE":"Géorgie"}
const JERSEYS := ["Pilier gauche", "Talonneur", "Pilier droit", "Deuxième ligne", "Deuxième ligne", "Troisième ligne aile", "Troisième ligne aile", "Numéro 8", "Demi de mêlée", "Demi d’ouverture", "Ailier", "Centre", "Centre", "Ailier", "Arrière"]
## Colonnes de l'effectif : [titre, clé de tri, x, largeur, alignement].
const COLUMNS := [
	["Poste", "fam", 20, 190, 0], ["Joueur", "name", 220, 470, 0], ["Âge", "age", 700, 70, 2],
	["Niveau", "rating", 790, 130, 2], ["Potentiel", "potential", 940, 140, 2], ["Nationalité", "nationality", 1110, 240, 0],
	["Sél.", "seniorCaps", 1360, 80, 2], ["Contrat", "contractEnd", 1460, 130, 2], ["Tit.", "starts", 1610, 80, 2],
	["Matchs", "matches", 1700, 100, 2], ["Note", "average", 1820, 100, 2], ["État", "state", 1940, 260, 0]
]

var app: Control
var state: Dictionary
var data: Dictionary = {}
var club_id := -1
var active := 0
var workspace: Control

# ---- Ouverture -------------------------------------------------------------------------------

## Ouvre la fiche du club `id` (le club du manager ouvre son écran Club). Renvoie false si inconnu.
static func open(owner_app: Control, id: int) -> bool:
	return owner_app.navigation_controller.open_entity({"kind":"club", "id":str(id)})

## Nom du club affiché (fil d'Ariane).
static func caption(owner_app: Control) -> String:
	var wanted: Variant = owner_app.management_ui.get("club_sheet")
	var id := int(wanted.get("id", -1)) if wanted is Dictionary else -1
	for division: Dictionary in owner_app.model.get("leagues", []):
		for club: Dictionary in division.get("rows", []):
			if int(club.get("id", -1)) == id: return G.club_name(club)
	for club: Dictionary in owner_app.catalogue:
		if int(club.get("id", -1)) == id: return G.club_name(club)
	return "club"

static func build(owner_app: Control, canvas: Control) -> void:
	var page: Control = load("res://ui/immersive08/club_sheet_canvas.gd").new()
	page.app = owner_app
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, WIDTH, HEIGHT))
	page._build()

## Instant de carrière : une fiche en cache n'est plus servie après une journée ou un match.
static func stamp(owner_app: Control) -> String:
	var meta: Dictionary = owner_app.model.get("meta", {})
	return "%s|%s|%s|%d" % [meta.get("season", ""), meta.get("week", ""), meta.get("calendarToday", meta.get("date", "")), owner_app.model.get("history", []).size()]

static func cached(owner_app: Control, id: int) -> Dictionary:
	var fresh: Variant = owner_app.model.get("clubSheet")
	if fresh is Dictionary and int(fresh.get("id", -1)) == id:
		owner_app.set_meta("club_sheet_cache", {"id":id, "stamp":stamp(owner_app), "data":fresh.duplicate(true)})
	var cache: Variant = owner_app.get_meta("club_sheet_cache", {})
	if cache is Dictionary and int(cache.get("id", -1)) == id and cache.get("stamp") == stamp(owner_app): return cache.data
	return {}

static func request(owner_app: Control, id: int) -> void:
	var key := "%d|%s" % [id, stamp(owner_app)]
	if owner_app.get_meta("club_sheet_requested", "") == key or owner_app.waiting: return
	owner_app.set_meta("club_sheet_requested", key)
	# Jamais pendant la construction de la page : la réponse la reconstruit.
	owner_app.call_deferred("_command", "club_sheet", {"club":id})

func _build() -> void:
	name = "FicheClub"
	if not app.management_ui.get("club_sheet") is Dictionary: app.management_ui.club_sheet = {"id":-1, "tab":0, "sort":"fam", "descending":false}
	state = app.management_ui.club_sheet
	club_id = int(state.get("id", -1))
	active = clampi(int(state.get("tab", 0)), 0, TABS.size() - 1)
	data = cached(app, club_id)
	if data.is_empty():
		_hero_identity_only()
		var waiting := D.panel(self, Rect2(0, 396, WIDTH, 300), "Fiche du club", "shield", "", "ClubSheetLoading")
		var failed: bool = app.get_meta("club_sheet_requested", "") == "%d|%s" % [club_id, stamp(app)] and not app.waiting
		D.text(waiting, 40, 150, "La fiche n’a pas pu être préparée. Réessayez." if failed else "Préparation de la fiche du club…", 30, C.MUTED, 600, 1600)
		if failed: D.button(waiting, Rect2(40, 200, 300, 56), "Réessayer", func(): app.remove_meta("club_sheet_requested"); request(app, club_id), true, "arrow", false, app.accent, "ClubSheetRetry")
		else: request(app, club_id)
		return
	_hero()
	_tabs()
	workspace = Control.new()
	workspace.name = "ClubSheetWorkspace"
	add_child(workspace)
	D.place(workspace, Rect2(0, 396, WIDTH, 844))
	match active:
		0: _overview()
		1: _squad()
		2: _xv()
		3: _stats()

# ---- Identité ---------------------------------------------------------------------------------

func _identity(id: int) -> Dictionary:
	for division: Dictionary in app.model.get("leagues", []):
		for club: Dictionary in division.get("rows", []):
			if int(club.get("id", -1)) == id: return club
	for club: Dictionary in app.catalogue:
		if int(club.get("id", -1)) == id: return club
	var own: Variant = app.model.get("club")
	if own is Dictionary and int(own.get("id", -1)) == id: return own
	return {}

func _catalogue(id: int) -> Dictionary:
	for club: Dictionary in app.catalogue:
		if int(club.get("id", -1)) == id: return club
	return {}

func _country(id: int) -> String:
	var entry := _catalogue(id)
	var code := str(G.identity(_identity(id)).get("country", entry.get("country", "")))
	var league := str(entry.get("leagueId", entry.get("division", "")))
	if code == "GB" and league in ["prem", "champ"]: return "Angleterre"
	return str(COUNTRIES.get(code, code))

func _club_link(parent: Control, rectangle: Rect2, id: int, caption: String, font_size: int = 24, color: Color = C.IVORY, control_name: String = "") -> Control:
	return Link.name_link(app, parent, rectangle, "club", id, caption, font_size, color, control_name)

func _hero_identity_only() -> void:
	var identity := _identity(club_id)
	var hero := D.panel(self, Rect2(0, 0, WIDTH, 300), "", "", "", "ClubSheetHero")
	var crest := G.crest(identity, C.px(170))
	hero.add_child(crest)
	D.place(crest, Rect2(36, 50, 200, 200))
	D.text(hero, 270, 150, G.club_name(identity) if not identity.is_empty() else "Club", 72, C.IVORY, 800, 1600)

func _hero() -> void:
	var identity := _identity(club_id)
	var colour := Color(str(G.identity(identity).get("color", data.get("color", "#2d6a4f"))))
	var hero := D.panel(self, Rect2(0, 0, WIDTH, 300), "", "", "", "ClubSheetHero")
	hero.clip_contents = true
	var band := D.rect(hero, Rect2(0, 0, 14, 300), colour, 0)
	band.name = "ClubColour"
	D.rect(hero, Rect2(14, 0, 520, 300), Color(colour, .16), 0)
	var crest := G.crest(identity, C.px(190))
	crest.name = "ClubSheetCrest"
	hero.add_child(crest)
	D.place(crest, Rect2(60, 40, 220, 220))
	D.text(hero, 330, 58, "FICHE DU CLUB", 26, C.GOLD, 800, 220)
	var title := D.text(hero, 330, 150, str(data.get("name", G.club_name(identity))), 78, C.IVORY, 800, 1030)
	title.name = "ClubSheetName"
	var place := PackedStringArray()
	var city := str(_catalogue(club_id).get("city", ""))
	if not city.is_empty(): place.append(city)
	var country := _country(club_id)
	if not country.is_empty(): place.append(country)
	var league_id := str(data.get("leagueId", ""))
	var league_name := str(data.get("leagueName", "")) if data.get("leagueName") != null else ""
	if league_name.is_empty() and not league_id.is_empty(): league_name = Club.competition_name(league_id, app.model)
	D.text(hero, 332, 196, "  ·  ".join(place) if not place.is_empty() else "—", 30, C.MUTED, 600, 1030)
	if not league_name.is_empty():
		var competition := Link.name_link(app, hero, Rect2(556, 28, 560, 40), "competition", league_id, league_name.to_upper(), 26, C.MINT, "ClubSheetLeague")
		competition.tooltip_text = "Ouvrir le classement · " + league_name
	var stadium := str(data.get("stadium", "")) if data.get("stadium") != null else ""
	var capacity: Variant = data.get("capacity")
	D.text(hero, 332, 236, ("Stade : " + stadium if not stadium.is_empty() else "Stade non renseigné") + ("  ·  %s places" % _thousands(capacity) if capacity is float or capacity is int else ""), 28, C.MUTED, 500, 1030)
	if bool(data.get("followed", false)): D.chip(hero, Rect2(332, 254, 140, 34), "★ Club suivi", C.GOLD)
	# Tuiles clés : classement, forme, réputation, effectif.
	var table: Dictionary = data.get("table", {})
	var tiles := [
		["Classement", _rank_text(), "%s pts · %s J" % [G.n(table.get("points", 0)), G.n(table.get("played", 0))]],
		["Forme", "", ""],
		["Réputation", _reputation_text(), "Niveau du club / 100"],
		["Effectif", "%d joueurs" % int(data.get("squadSize", 0)), "Âge moyen %s ans" % _decimal(data.get("averageAge"))],
	]
	for i in tiles.size():
		var x := 1410 + (i % 2) * 412
		var y := 22 + (i / 2) * 136
		var tile := D.rect(hero, Rect2(x, y, 396, 122), Color("112621"), 7, Color("44634f"))
		tile.name = "ClubSheetTile%d" % i
		D.text(tile, 22, 38, str(tiles[i][0]).to_upper(), 22, C.MUTED, 700, 350)
		if i == 1: _form(tile, Vector2(22, 58), table.get("form", []), 46)
		else:
			D.text(tile, 22, 80, str(tiles[i][1]), 38, C.IVORY, 800, 360)
			D.text(tile, 22, 114, str(tiles[i][2]), 24, C.MUTED, 500, 360)

func _rank_text() -> String:
	var rank := int(_identity(club_id).get("rank", 0))
	if rank <= 0 or int(data.get("table", {}).get("played", 0)) == 0: return "—"
	return ("1er" if rank == 1 else "%de" % rank)

func _reputation_text() -> String:
	var value: Variant = data.get("reputation")
	if not (value is float or value is int): return "—"
	var label := "Prestigieux" if value >= 82 else "Ambitieux" if value >= 75 else "Solide" if value >= 68 else "Modeste"
	return "%d · %s" % [int(value), label]

static func _thousands(value: Variant) -> String:
	return G.euros(value).trim_suffix(" €")

static func _decimal(value: Variant) -> String:
	if not (value is float or value is int): return "—"
	return str(snappedf(float(value), 0.1)).trim_suffix(".0").replace(".", ",")

func _form(parent: Control, origin: Vector2, form: Variant, side: float) -> void:
	var list: Array = form if form is Array else []
	if list.is_empty():
		D.text(parent, origin.x, origin.y + side * .7, "Aucun match", 26, C.MUTED, 600, 300)
		return
	for i in list.size():
		var code := str(list[i])
		var chip := D.rect(parent, Rect2(origin.x + i * (side + 8), origin.y, side, side), Color(TINTS.get(code, DRAW), .22), 5, TINTS.get(code, DRAW))
		chip.name = "Forme%d" % i
		D.text(chip, side / 2, side * .72, code, 26, TINTS.get(code, DRAW), 800, side, HORIZONTAL_ALIGNMENT_CENTER)

# ---- Onglets et actions -----------------------------------------------------------------------

func _tabs() -> void:
	for i in TABS.size():
		var rect := Rect2(i * 300, 320, 288, 58)
		var tab := D.button(self, rect, TABS[i], _select.bind(i), i == active, TAB_ICONS[i], false, app.accent, "ClubSheetTab%d" % i)
		D.tab_state(tab, rect.size, i == active, TAB_ICONS[i])
		tab.toggle_mode = true
		tab.button_pressed = i == active
	var followed := bool(data.get("followed", false))
	var actions := [
		["Ne plus suivre" if followed else "Suivre le club", "ClubSheetFollow", "star" if not followed else "close", _follow.bind(not followed)],
		["Calendrier", "ClubSheetCalendar", "calendar", _calendar],
		["Comparer", "ClubSheetCompare", "tactic", _compare],
		["Recruter", "ClubSheetRecruit", "search", _recruit.bind("")],
	]
	var x := 1240
	for action: Array in actions:
		var width := 236 if action[1] != "ClubSheetFollow" else 262
		var button := D.button(self, Rect2(x, 320, width - 12, 58), action[0], action[3], false, action[2], true, app.accent, action[1])
		button.tooltip_text = {"ClubSheetFollow":"Les résultats d’un club suivi arrivent dans vos actualités.", "ClubSheetCalendar":"Calendrier de la saison de ce club : résultats et matchs à venir.", "ClubSheetCompare":"Comparer ce club au vôtre.", "ClubSheetRecruit":"Ouvrir le marché entre clubs sur cet effectif."}[action[1]]
		x += width

func _select(index: int) -> void:
	state.tab = index
	app._render(false)

func _follow(value: bool) -> void:
	# La fiche est relue après la décision (drapeau « suivi » à jour).
	app.remove_meta("club_sheet_cache")
	app.remove_meta("club_sheet_requested")
	app._command("club_follow", {"club":club_id, "follow":value})

## Calendrier du club (matchs joués et à venir de la saison), adversaires cliquables.
func _calendar() -> void:
	var dialog := AcceptDialog.new()
	dialog.name = "ClubCalendarDialog"
	dialog.title = "Calendrier · " + str(data.get("name", ""))
	dialog.set_meta("navigation_read_only", true)
	dialog.set_meta("entity_kind", "club-calendar")
	dialog.set_meta("entity_id", str(club_id))
	app._prepare_dialog(dialog, 900)
	dialog.get_ok_button().text = "FERMER"
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(C.px(1100), C.px(760))
	dialog.add_child(scroll)
	var list := C.v(6)
	C.fill(list)
	scroll.add_child(list)
	var fixtures: Array = data.get("fixtures", [])
	if fixtures.is_empty(): list.add_child(C.wrap("Aucun match programmé cette saison.", 22, C.MUTED))
	for index in fixtures.size():
		var f: Dictionary = fixtures[index]
		var row := C.h(14)
		row.name = "ClubCalendarRow%d" % index
		list.add_child(row)
		var date := C.label(_date(f.get("date")), 22, C.MUTED, false)
		date.custom_minimum_size.x = C.px(170)
		row.add_child(date)
		var where := C.label("dom." if f.get("home", false) else "ext.", 22, C.MUTED, false)
		where.custom_minimum_size.x = C.px(60)
		row.add_child(where)
		var opponent := int(f.get("opponent", -1))
		var name := G.club_name(_identity(opponent))
		var target := Link.target("club", opponent)
		var link: Control = Link.button(app, name, target, "ClubCalendarOpponent%d" % index, dialog) if Link.available(app, "club", opponent) else C.label(name, 24, C.IVORY)
		link.custom_minimum_size.x = C.px(420)
		if link is Button:
			(link as Button).clip_text = true
			(link as Button).pressed.connect(dialog.queue_free)
		row.add_child(link)
		var played: bool = f.get("played", false)
		var code := str(f.get("outcome", ""))
		var score := C.label("%s %d–%d" % [code, int(f.get("for", 0)), int(f.get("against", 0))] if played else "à jouer", 24, TINTS.get(code, C.GOLD) if played else C.GOLD)
		score.custom_minimum_size.x = C.px(150)
		row.add_child(score)
		row.add_child(C.label(Club.competition_name(str(f.get("competitionId", "")), app.model), 20, C.MUTED, false))
	app.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(C.px(1180), C.px(900)))

func _recruit(name_filter: String) -> void:
	var market: Variant = preload("res://ui/interclub_market_view.gd").open(app)
	if not is_instance_valid(market): return
	var term := name_filter if not name_filter.is_empty() else str(data.get("name", ""))
	market.search_field.text = term
	market.query = term
	market.page = 0
	market._redraw()

func _compare() -> void:
	var own: Dictionary = app.model.get("club", {})
	var dialog := AcceptDialog.new()
	dialog.name = "ClubSheetComparison"
	dialog.title = "%s · %s" % [G.club_name(own), str(data.get("name", ""))]
	app._prepare_dialog(dialog, 760)
	dialog.get_ok_button().text = "FERMER"
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", C.px(36))
	grid.add_theme_constant_override("v_separation", C.px(10))
	dialog.add_child(grid)
	var mine := _own_figures()
	var theirs := _figures(data)
	for header: String in ["", G.club_name(own), str(data.get("name", ""))]: grid.add_child(C.label(header, 24, C.GOLD, true, 700))
	for key: String in ["Classement", "Points", "Points pour / contre", "Réputation", "Effectif", "Âge moyen", "Masse salariale estimée"]:
		grid.add_child(C.label(key, 22, C.MUTED, false))
		grid.add_child(C.label(str(mine.get(key, "—")), 24, C.IVORY))
		grid.add_child(C.label(str(theirs.get(key, "—")), 24, C.IVORY))
	app.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(C.px(980), C.px(560)))

func _figures(sheet: Dictionary) -> Dictionary:
	var table: Dictionary = sheet.get("table", {})
	var identity := _identity(int(sheet.get("id", -1)))
	var rank := int(identity.get("rank", 0))
	return {"Classement": ("%d" % rank) if rank > 0 and int(table.get("played", 0)) > 0 else "—", "Points": G.n(table.get("points", 0)), "Points pour / contre": "%s / %s" % [G.n(table.get("pf", 0)), G.n(table.get("pa", 0))],
		"Réputation": str(sheet.get("reputation", "—")), "Effectif": str(sheet.get("squadSize", "—")), "Âge moyen": _decimal(sheet.get("averageAge")), "Masse salariale estimée": _wage_text(sheet.get("wageBill"))}

func _own_figures() -> Dictionary:
	var own: Dictionary = app.model.get("club", {})
	var squad: Array = app.model.get("squad", [])
	var wages := 0.0
	var ages := 0.0
	for p: Dictionary in squad:
		wages += float(p.get("salary", 0) if p.get("salary") != null else 0)
		ages += float(p.get("age", 0) if p.get("age") != null else 0)
	var rank := int(own.get("rank", 0))
	return {"Classement": str(rank) if rank > 0 else "—", "Points": G.n(own.get("points", 0)), "Points pour / contre": "%s / %s" % [G.n(own.get("pf", 0)), G.n(own.get("pa", 0))],
		"Réputation": str(G.identity(own).get("base", "—")), "Effectif": str(squad.size()), "Âge moyen": _decimal(ages / squad.size() if not squad.is_empty() else null), "Masse salariale estimée": _wage_text(wages)}

static func _wage_text(weekly: Variant) -> String:
	if not (weekly is float or weekly is int) or float(weekly) <= 0: return "—"
	# Estimation : arrondie à 5 % près, jamais le détail exact d'un autre club.
	var rounded := snappedf(float(weekly), maxf(100.0, float(weekly) * 0.05))
	return "≈ " + G.salary_amount(rounded) + " " + G.salary_period(true)

# ---- Vue d'ensemble ----------------------------------------------------------------------------

func _overview() -> void:
	var club := D.panel(workspace, Rect2(0, 0, 700, 844), "Le club", "shield", "", "ClubSheetIdentity")
	var rows := [
		["Entraîneur", data.get("coach")], ["Président", data.get("president")], ["Directeur sportif", data.get("director")],
		["Stade", data.get("stadium")], ["Capacité", ("%s places" % _thousands(data.capacity)) if data.get("capacity") is float or data.get("capacity") is int else null],
		["Réputation", _reputation_text()], ["Trésorerie estimée", ("≈ " + G.euros(snappedf(float(data.cash), 100000.0))) if data.get("cash") is float or data.get("cash") is int else null],
		["Masse salariale estimée", _wage_text(data.get("wageBill"))], ["Objectif", data.get("goal")], ["Stratégie", _strategy(data.get("strategy"))],
	]
	var y := 104
	for row: Array in rows:
		D.text(club, 24, y, str(row[0]), 24, C.MUTED, 500, 250)
		D.text(club, 280, y, str(row[1]) if row[1] != null and str(row[1]) != "" else "—", 26, C.IVORY, 600, 400)
		D.line(club, Vector2(24, y + 22), Vector2(676, y + 22), Color(C.LINE, .35))
		y += 72
	_season_panel()
	_rivalry_panel()

static func _strategy(value: Variant) -> String:
	if not value is String or str(value).is_empty(): return "—"
	# Libellés de native/engine/club-directions.cjs (STRATEGY_LABEL).
	return str({"vedettes":"Viser plus haut, joueurs confirmés", "formateur":"Faire confiance à sa formation", "rajeunissement":"Rajeunir le groupe", "reconstruction":"Reconstruire", "maintien":"Assurer le maintien", "vente":"Assainir ses comptes", "equilibre":"Compléter poste par poste"}.get(value, str(value).capitalize()))

func _season_panel() -> void:
	var panel := D.panel(workspace, Rect2(724, 0, 760, 844), "Saison en cours", "trophy", "", "ClubSheetSeason")
	var table: Dictionary = data.get("table", {})
	var cells := [["Rang", _rank_text()], ["Pts", table.get("points", 0)], ["J", table.get("played", 0)], ["V", table.get("won", 0)], ["N", table.get("drawn", 0)], ["D", table.get("lost", 0)], ["PF", table.get("pf", 0)], ["PC", table.get("pa", 0)], ["Bonus", table.get("bonus", 0)]]
	for i in cells.size():
		var x := 24 + i * 80
		D.text(panel, x + 34, 100, str(cells[i][0]), 20, C.MUTED, 700, 76, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(panel, x + 34, 140, G.n(cells[i][1]) if not cells[i][1] is String else cells[i][1], 32, C.IVORY, 800, 76, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(panel, 24, 200, "FORME · 5 DERNIERS", 22, C.GOLD, 700, 300)
	_form(panel, Vector2(300, 170), table.get("form", []), 40)
	D.line(panel, Vector2(24, 236), Vector2(736, 236), Color(C.LINE, .6))
	D.text(panel, 24, 278, "PROCHAIN MATCH", 22, C.GOLD, 700, 300)
	var next: Variant = data.get("next")
	if next is Dictionary:
		var opponent := int(next.get("opponent", -1))
		D.text(panel, 24, 322, ("Domicile" if next.get("home", false) else "Extérieur") + " · " + _date(next.get("date")) + " · " + Club.competition_name(str(next.get("competitionId", "")), app.model), 22, C.MUTED, 500, 712)
		D.text(panel, 24, 362, "contre", 24, C.MUTED, 500, 80)
		_club_link(panel, Rect2(100, 334, 620, 40), opponent, G.club_name(_identity(opponent)), 28, C.IVORY, "ClubSheetNextOpponent")
	else: D.text(panel, 24, 322, "Aucun match programmé.", 24, C.MUTED, 500, 700)
	D.line(panel, Vector2(24, 392), Vector2(736, 392), Color(C.LINE, .6))
	D.text(panel, 24, 434, "DERNIERS RÉSULTATS", 22, C.GOLD, 700, 400)
	var results: Array = data.get("results", [])
	if results.is_empty(): D.text(panel, 24, 478, "Pas encore de match joué cette saison.", 24, C.MUTED, 500, 700)
	for i in mini(results.size(), 6):
		_result_row(panel, Rect2(24, 452 + i * 64, 712, 58), results[i], "ClubSheetResult%d" % i)

func _result_row(parent: Control, rect: Rect2, result: Dictionary, control_name: String) -> void:
	var row := D.rect(parent, rect, Color("101a1b"), 5, Color(C.LINE, .4))
	row.name = control_name
	var code := str(result.get("outcome", "N"))
	var chip := D.rect(row, Rect2(8, 9, 40, 40), Color(TINTS.get(code, DRAW), .22), 5, TINTS.get(code, DRAW))
	D.text(chip, 20, 29, code, 22, TINTS.get(code, DRAW), 800, 40, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(row, 60, 36, "%d–%d" % [int(result.get("for", 0)), int(result.get("against", 0))], 28, C.IVORY, 800, 90)
	D.text(row, 152, 36, "dom." if result.get("home", false) else "ext.", 20, C.MUTED, 500, 50)
	var opponent := int(result.get("opponent", -1))
	_club_link(row, Rect2(204, 8, 330, 42), opponent, G.club_name(_identity(opponent)), 24, C.IVORY, control_name + "Opponent")
	D.text(row, rect.size.x - 12, 36, _date(result.get("date")), 20, C.MUTED, 500, 160, HORIZONTAL_ALIGNMENT_RIGHT)

static func _date(value: Variant) -> String:
	var text := str(value) if value != null else ""
	if text.length() < 10: return "date à fixer"
	var months := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
	return "%d %s %s" % [int(text.substr(8, 2)), months[clampi(int(text.substr(5, 2)) - 1, 0, 11)], text.substr(0, 4)]

## Panneau « Vos confrontations » sans match passé : le prochain match entre les deux clubs (date, lieu,
## compétition), sinon une phrase courte. Évite un cadre quasi vide.
func _upcoming_meeting(panel: Control, upcoming: Variant) -> void:
	D.text(panel, 24, 110, "Aucune confrontation enregistrée.", 24, C.MUTED, 500, 690)
	D.line(panel, Vector2(24, 140), Vector2(716, 140), Color(C.LINE, .6))
	if upcoming is Dictionary:
		D.text(panel, 24, 190, "PROCHAINE CONFRONTATION", 22, C.GOLD, 700, 500)
		var competition := Club.competition_name(str(upcoming.get("competitionId", "")), app.model)
		D.text(panel, 24, 246, _date(upcoming.get("date")), 38, C.IVORY, 800, 690)
		var venue := "À domicile" if upcoming.get("home", false) else "À l’extérieur"
		var stadium := str(upcoming.get("stadium", "")) if upcoming.get("stadium") != null else ""
		if not stadium.is_empty(): venue += " · " + stadium
		D.text(panel, 24, 298, venue, 24, C.IVORY, 600, 690)
		var detail := competition if competition != "" else "Compétition à préciser"
		D.text(panel, 24, 340, detail, 22, C.MUTED, 500, 690)
	else:
		_paragraph(panel, Rect2(24, 170, 690, 120), "Aucun match prévu entre ces deux clubs cette saison : le premier bilan s’écrira à leur première rencontre.", 24, "ClubSheetHeadToHeadEmpty")

func _rivalry_panel() -> void:
	var own: Dictionary = app.model.get("club", {})
	var panel := D.panel(workspace, Rect2(1508, 0, 740, 430), "Vos confrontations", "tactic", G.club_abbr(own), "ClubSheetHeadToHead")
	D.text(panel, 24, 400, "Bilan de %s face à ce club, toutes saisons conservées." % G.club_name(own), 22, C.MUTED, 500, 690)
	var h2h: Dictionary = data.get("headToHead", {})
	var played := int(h2h.get("played", 0))
	if played == 0:
		_upcoming_meeting(panel, h2h.get("upcoming"))
	else:
		var cells := [["Matchs", played, C.IVORY], ["Victoires", h2h.get("won", 0), WIN], ["Nuls", h2h.get("drawn", 0), DRAW], ["Défaites", h2h.get("lost", 0), LOSS]]
		for i in cells.size():
			D.text(panel, 24 + i * 176 + 80, 104, str(cells[i][0]), 20, C.MUTED, 700, 170, HORIZONTAL_ALIGNMENT_CENTER)
			D.text(panel, 24 + i * 176 + 80, 150, G.n(cells[i][1]), 40, cells[i][2], 800, 170, HORIZONTAL_ALIGNMENT_CENTER)
		var last: Array = h2h.get("last", [])
		for i in mini(last.size(), 3):
			var r: Dictionary = last[i]
			var code := str(r.get("outcome", "N"))
			D.text(panel, 24, 214 + i * 64, "%s  %d–%d  %s · %s" % [code, int(r.get("for", 0)), int(r.get("against", 0)), "à domicile" if r.get("home", false) else "à l’extérieur", _date(r.get("date"))], 24, TINTS.get(code, C.IVORY), 600, 690)
	# Joueurs clés : meilleures notes moyennes (3 matchs au moins), sinon les mieux connus.
	var keys := D.panel(workspace, Rect2(1508, 452, 740, 392), "Joueurs clés", "people", "", "ClubSheetKeyPlayers")
	var squad: Array = data.get("squad", []).filter(func(p: Dictionary): return int(p.get("matches", 0)) >= 3 and p.get("average") != null)
	squad.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.average) > float(b.average) or (float(a.average) == float(b.average) and str(a.id) < str(b.id)))
	if squad.is_empty(): D.text(keys, 24, 110, "Notes disponibles après trois matchs.", 24, C.MUTED, 500, 690)
	for i in mini(squad.size(), 4):
		var p: Dictionary = squad[i]
		var portrait := G.portrait(0, C.px(60), p)
		keys.add_child(portrait)
		D.place(portrait, Rect2(24, 76 + i * 76, 64, 64))
		_player_link(keys, Rect2(102, 78 + i * 76, 420, 36), p, 26, "ClubSheetKey%d" % i)
		D.text(keys, 104, 136 + i * 76, "%s · %d matchs · %d essai%s" % [str(p.get("pos", "")), int(p.matches), int(p.get("tries", 0)), "" if int(p.get("tries", 0)) <= 1 else "s"], 20, C.MUTED, 500, 440)
		Notes.pastille(keys, Rect2(640, 84 + i * 76, 76, 44), float(p.average), C.density * .8)

# ---- Joueurs ----------------------------------------------------------------------------------

## Clic sur un joueur : fiche complète s'il est à vous ou sur le marché ; sinon son dossier dans le
## marché entre clubs (recrutement existant), filtré sur son nom.
func player_target(p: Dictionary) -> Dictionary:
	var id := str(p.get("id", ""))
	for kind: String in ["player", "market"]:
		var target := {"kind":kind, "id":id}
		if app.navigation_controller.entity_available(target): return target
	return {}

func _player_link(parent: Control, rect: Rect2, p: Dictionary, font_size: int, control_name: String) -> Control:
	var target := player_target(p)
	if not target.is_empty(): return Link.name_link(app, parent, rect, str(target.kind), target.id, str(p.get("name", "")), font_size, C.IVORY, control_name)
	var button := Link.styled_button(parent, rect, str(p.get("name", "")), font_size, C.IVORY, control_name)
	button.tooltip_text = "Voir son dossier dans le marché entre clubs · " + str(p.get("name", ""))
	button.pressed.connect(_open_dossier.bind(p))
	button.set_meta("entity_kind", "player")
	button.set_meta("entity_id", str(p.get("id", "")))
	return button

func _open_dossier(p: Dictionary) -> void:
	_recruit(str(p.get("name", "")))
	var market := app.get_node_or_null("InterclubMarket") as Window
	var adapter := preload("res://ui/prospect_profile.gd")
	if market != null and adapter.target_available(app, "interclub", str(p.get("id", ""))):
		adapter.open_target(app, "interclub", str(p.get("id", "")), market)

# ---- Effectif -----------------------------------------------------------------------------------

func _squad() -> void:
	var panel := D.panel(workspace, Rect2(0, 0, WIDTH, 844), "Effectif · %d joueurs" % int(data.get("squadSize", 0)), "people", "Selon vos observations", "ClubSheetSquad")
	var sort_key := str(state.get("sort", "fam"))
	var descending := bool(state.get("descending", false))
	for column: Array in COLUMNS:
		var caption: String = column[0] + ("  ▼" if sort_key == column[1] and descending else "  ▲" if sort_key == column[1] else "")
		var header := Link.styled_button(panel, Rect2(column[2], 68, column[3], 40), caption, 22, C.GOLD if sort_key == column[1] else C.MUTED, "ClubSheetSort_" + str(column[1]))
		header.alignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][column[4]]
		header.tooltip_text = "Trier par " + str(column[0]).to_lower()
		header.pressed.connect(_sort.bind(str(column[1])))
	D.line(panel, Vector2(18, 112), Vector2(WIDTH - 18, 112), Color(C.LINE, .7))
	var scroll := ScrollContainer.new()
	scroll.name = "ClubSheetSquadScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	D.place(scroll, Rect2(0, 116, WIDTH, 716))
	var players: Array = data.get("squad", []).duplicate()
	players.sort_custom(_compare_players.bind(sort_key, descending))
	var body := Control.new()
	body.custom_minimum_size = Vector2(WIDTH, players.size() * 50 + 10) * C.density
	scroll.add_child(body)
	for i in players.size():
		_squad_row(body, i, players[i])

func _sort(key: String) -> void:
	if str(state.get("sort", "")) == key: state.descending = not bool(state.get("descending", false))
	else:
		state.sort = key
		state.descending = key in ["rating", "potential", "seniorCaps", "starts", "matches", "average"]
	app._render(false)

func _value(p: Dictionary, key: String) -> Variant:
	match key:
		"rating", "potential":
			var v: Variant = Knowledge.sort_value(p, key)
			return v if v != null else -1.0
		"name": return str(p.get("name", ""))
		"fam": return float(POSITION_ORDER.get(str(p.get("pos", "")), 20 + int(p.get("fam", 0))))
		"nationality": return str(p.get("nationality", "")) if p.get("nationality") != null else "~"
		"state": return (2 if int(p.get("injury", 0)) > 0 else 0) + (1 if p.get("onInternationalDuty", false) else 0)
		"average": return float(p.average) if p.get("average") != null else -1.0
	var value: Variant = p.get(key)
	return float(value) if value is int or value is float else -1.0

func _compare_players(a: Dictionary, b: Dictionary, key: String, descending: bool) -> bool:
	var left: Variant = _value(a, key)
	var right: Variant = _value(b, key)
	if left != right: return (left > right) if descending else (left < right)
	if key != "fam" and _value(a, "fam") != _value(b, "fam"): return _value(a, "fam") < _value(b, "fam")
	return str(a.get("id", "")) < str(b.get("id", ""))

func _squad_row(body: Control, index: int, p: Dictionary) -> void:
	var y := index * 50
	var row := D.rect(body, Rect2(12, y + 4, WIDTH - 24, 46), Color("121c1d") if index % 2 == 0 else Color("0f1718"), 4)
	row.name = "ClubSheetRow%d" % index
	var values := {
		"fam": str(p.get("pos", "")), "age": G.n(p.get("age", "—")), "rating": Knowledge.rating_text(p), "potential": Knowledge.potential_text(p),
		"nationality": str(p.get("nationality", "—")) if p.get("nationality") != null else "—", "seniorCaps": G.n(p.get("seniorCaps")) if p.get("seniorCaps") is float or p.get("seniorCaps") is int else "—",
		"contractEnd": G.contract_year(p.get("contractEnd")), "starts": G.n(p.get("starts", 0)), "matches": G.n(p.get("matches", 0)),
		"average": Notes.texte_note(p.get("average")) if p.get("average") != null else "—", "state": _player_state(p),
	}
	for column: Array in COLUMNS:
		var key := str(column[1])
		if key == "name":
			_player_link(body, Rect2(column[2], y + 6, column[3], 40), p, 24, "ClubSheetPlayer%d" % index)
			continue
		var align: HorizontalAlignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][column[4]]
		var x: float = column[2] + (column[3] if align == HORIZONTAL_ALIGNMENT_RIGHT else 0)
		var color := C.IVORY
		if key == "state": color = C.ALERT if int(p.get("injury", 0)) > 0 else C.BLUE if p.get("onInternationalDuty", false) else C.MUTED
		if key == "potential": color = Knowledge.POTENTIAL_COLOR
		D.text(body, x, y + 36, values[key], 24, color, 600 if key != "fam" else 500, column[3], align)

static func _player_state(p: Dictionary) -> String:
	var parts := PackedStringArray()
	if int(p.get("injury", 0)) > 0: parts.append("Blessé (%d sem.)" % int(p.injury))
	if int(p.get("suspension", 0)) > 0: parts.append("Suspendu")
	if p.get("onInternationalDuty", false): parts.append("En sélection")
	return " · ".join(parts) if not parts.is_empty() else "Disponible"

# ---- XV type -------------------------------------------------------------------------------------

func _players_by_id() -> Dictionary:
	var result := {}
	for p: Dictionary in data.get("squad", []): result[str(p.get("id", ""))] = p
	return result

func _xv() -> void:
	var xv: Dictionary = data.get("xv", {})
	var people := _players_by_id()
	var identity := _identity(club_id)
	# Terrain et cartes de l'équipe-type (equipe_type_view.gd), à l'échelle de l'onglet.
	var frame := D.rect(workspace, Rect2(0, 0, 1120, 844), Color("07100c"), 8, C.LINE)
	frame.name = "ClubSheetPitchFrame"
	frame.clip_contents = true
	var pitch_scene := Control.new()
	pitch_scene.name = "ClubSheetPitch"
	pitch_scene.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.add_child(pitch_scene)
	var k := 820.0 / EquipeType.TERRAIN.size.y * C.density
	pitch_scene.scale = Vector2(k, k)
	pitch_scene.position = Vector2((1120 * C.density - EquipeType.TERRAIN.size.x * k) / 2.0, 12 * C.density)
	var terrain := EquipeType.TerrainDessin.new()
	terrain.size = EquipeType.TERRAIN.size
	pitch_scene.add_child(terrain)
	var cards: Control = EquipeType.new()
	cards.mode = "saison"
	var total := int(xv.get("matches", 0))
	for slot: Dictionary in xv.get("slots", []):
		var jersey := int(slot.get("jersey", 0))
		var p: Dictionary = people.get(str(slot.get("id", "")), {})
		if p.is_empty() or not EquipeType.PLACES.has(jersey): continue
		var probable := str(slot.get("source", "")) == "probable"
		var starts := int(slot.get("starts", 0))
		var j := p.duplicate(true)
		j.merge({"numero":jersey, "club":identity, "poste":JERSEYS[jersey - 1], "matchs":starts, "noteMatch":p.get("average"),
			"legende":("XV probable" if probable and starts == 0 else "%d tit. / %d" % [starts, total])}, true)
		var card: Control = cards._carte(j, EquipeType.CARTE)
		card.name = "ClubSheetXV%d" % jersey
		var centre: Vector2 = Vector2(EquipeType.PLACES[jersey].x * EquipeType.TERRAIN.size.x, EquipeType.PLACES[jersey].y * EquipeType.TERRAIN.size.y)
		card.position = centre - EquipeType.CARTE * 0.5
		if probable: card.modulate = Color(1, 1, 1, .78)
		pitch_scene.add_child(card)
		var target := player_target(p)
		var hit := Button.new()
		hit.flat = true
		hit.name = "ClubSheetXVLink%d" % jersey
		hit.size = EquipeType.CARTE
		hit.position = card.position
		hit.tooltip_text = "%s · n° %d · %s" % [str(p.get("name", "")), jersey, str(j.legende)]
		hit.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 10, 0))
		hit.add_theme_stylebox_override("hover", C.box(Color(C.MINT, .08), C.MINT, 10, 0))
		if not target.is_empty(): Link.bind(hit, app, target, str(p.get("name", "")))
		else: hit.pressed.connect(_open_dossier.bind(p))
		pitch_scene.add_child(hit)
	cards.free()
	# Colonne de droite : explication, titularisations par maillot, remplaçants les plus utilisés.
	var side := D.panel(workspace, Rect2(1144, 0, 1104, 844), "XV type de la saison", "tactic", "", "ClubSheetXVList")
	var source := str(xv.get("source", "probable"))
	var explanation := ""
	if total == 0: explanation = "Saison pas encore commencée pour ce club (ou championnat en résultats rapides) : XV probable de la composition automatique."
	elif source == "feuilles": explanation = "Le XV qui revient le plus : pour chaque maillot, le joueur le plus souvent titulaire à ce poste sur %d feuille%s de match." % [total, "" if total == 1 else "s"]
	else: explanation = "XV le plus fréquent sur %d feuille%s ; %d maillot%s complété%s par le XV probable (joueur parti ou poste jamais tenu par un joueur encore au club)." % [total, "" if total == 1 else "s", int(xv.get("completed", 0)), "" if int(xv.get("completed", 0)) == 1 else "s", "" if int(xv.get("completed", 0)) == 1 else "s"]
	_paragraph(side, Rect2(24, 70, 1056, 96), explanation, 22, "ClubSheetXVSource")
	var slots: Array = xv.get("slots", [])
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var p: Dictionary = people.get(str(slot.get("id", "")), {})
		var column := i / 8
		var x := 24 + column * 540
		var y := 186 + (i % 8) * 54
		D.text(side, x, y + 30, "%d" % int(slot.get("jersey", 0)), 26, C.GOLD, 800, 40, HORIZONTAL_ALIGNMENT_RIGHT)
		if p.is_empty(): D.text(side, x + 56, y + 30, "Poste non pourvu", 24, C.MUTED, 500, 300)
		else: _player_link(side, Rect2(x + 56, y + 4, 300, 38), p, 24, "ClubSheetXVName%d" % int(slot.get("jersey", 0)))
		var count := int(slot.get("starts", 0))
		D.text(side, x + 470, y + 30, ("%d tit." % count) if total > 0 else "probable", 22, C.MINT if str(slot.get("source", "")) == "feuilles" else C.MUTED, 600, 110, HORIZONTAL_ALIGNMENT_RIGHT)
	D.line(side, Vector2(24, 628), Vector2(1080, 628), Color(C.LINE, .6))
	var bench: Array = xv.get("bench", [])
	var probable_bench: Array = xv.get("probableBench", [])
	D.text(side, 24, 668, "REMPLAÇANTS LES PLUS UTILISÉS" if not bench.is_empty() else "BANC PROBABLE", 22, C.GOLD, 700, 700)
	var entries: Array = bench if not bench.is_empty() else probable_bench.map(func(id: String): return {"id":id, "entries":0})
	if entries.is_empty(): D.text(side, 24, 712, "Aucune entrée en jeu enregistrée.", 22, C.MUTED, 500, 700)
	for i in mini(entries.size(), 8):
		var e: Dictionary = entries[i]
		var p: Dictionary = people.get(str(e.get("id", "")), {})
		if p.is_empty(): continue
		var x := 24 + (i % 2) * 540
		var y := 684 + (i / 2) * 40
		_player_link(side, Rect2(x, y, 360, 36), p, 22, "ClubSheetBench%d" % i)
		if int(e.get("entries", 0)) > 0: D.text(side, x + 500, y + 28, "%d entrée%s" % [int(e.entries), "" if int(e.entries) == 1 else "s"], 20, C.MUTED, 500, 140, HORIZONTAL_ALIGNMENT_RIGHT)

# ---- Statistiques --------------------------------------------------------------------------------

func _stats() -> void:
	var team: Dictionary = data.get("team", {})
	var matches := int(team.get("matches", 0))
	var tiles := [
		["Matchs", G.n(matches), "%d V · %d N · %d D" % [int(team.get("won", 0)), int(team.get("drawn", 0)), int(team.get("lost", 0))]],
		["Points pour", G.n(team.get("pointsFor", 0)), "%s par match" % _decimal(float(team.get("pointsFor", 0)) / matches if matches > 0 else null)],
		["Points contre", G.n(team.get("pointsAgainst", 0)), "%s par match" % _decimal(float(team.get("pointsAgainst", 0)) / matches if matches > 0 else null)],
		["Essais marqués", G.n(team.get("triesFor", 0)), "%s par match" % _decimal(float(team.get("triesFor", 0)) / matches if matches > 0 else null)],
		["Essais encaissés", G.n(team.get("triesAgainst", 0)), "%s par match" % _decimal(float(team.get("triesAgainst", 0)) / matches if matches > 0 else null)],
	]
	for i in tiles.size():
		var tile := D.rect(workspace, Rect2(i * 452, 0, 436, 150), Color("112621"), 7, Color("44634f"))
		tile.name = "ClubSheetTeamStat%d" % i
		D.text(tile, 24, 42, str(tiles[i][0]).to_upper(), 22, C.MUTED, 700, 390)
		D.text(tile, 24, 100, str(tiles[i][1]), 48, C.IVORY, 800, 390)
		D.text(tile, 24, 134, str(tiles[i][2]), 22, C.MUTED, 500, 390)
	var boards := [
		["Meilleurs marqueurs", "tries", "essai", 0],
		["Plaqueurs", "tackles", "plaquage", 0],
		["Mètres gagnés", "metres", "m", 0],
		["Notes moyennes", "average", "", 3],
		["Hommes du match", "playerOfMatch", "fois", 0],
	]
	for i in boards.size():
		_leaderboard(Rect2(i * 452, 174, 436, 670), boards[i], "ClubSheetBoard%d" % i)

func _leaderboard(rect: Rect2, board: Array, control_name: String) -> void:
	var panel := D.panel(workspace, rect, str(board[0]), "", "", control_name)
	var key := str(board[1])
	var minimum := int(board[3])
	var players: Array = data.get("squad", []).filter(func(p: Dictionary):
		var v: Variant = p.get(key)
		return v != null and float(v) > 0 and int(p.get("matches", 0)) >= minimum)
	players.sort_custom(func(a: Dictionary, b: Dictionary): return float(a[key]) > float(b[key]) or (float(a[key]) == float(b[key]) and str(a.id) < str(b.id)))
	if players.is_empty():
		_paragraph(panel, Rect2(20, 76, rect.size.x - 40, 80), "Aucune donnée pour l’instant." if minimum == 0 else "Trois matchs notés au moins.", 22, control_name + "Empty")
		return
	for i in mini(players.size(), 8):
		var p: Dictionary = players[i]
		var y := 76 + i * 72
		D.text(panel, 20, y + 34, "%d" % (i + 1), 24, C.GOLD, 800, 30)
		_player_link(panel, Rect2(56, y + 2, 260, 40), p, 24, "%sPlayer%d" % [control_name, i])
		D.text(panel, 58, y + 62, str(p.get("pos", "")), 18, C.MUTED, 500, 250)
		var value := Notes.texte_note(p[key]) if key == "average" else G.n(p[key])
		D.text(panel, rect.size.x - 20, y + 34, value + ("" if str(board[2]).is_empty() else (" " + str(board[2]) if str(board[2]) == "m" else "")), 28, C.IVORY, 800, 110, HORIZONTAL_ALIGNMENT_RIGHT)

## Paragraphe à largeur fixe (retour à la ligne dans le cadre donné, jamais au-delà).
func _paragraph(parent: Control, rect: Rect2, value: String, font_size: int, control_name: String) -> Label:
	var label := C.wrap(value, font_size, C.MUTED)
	label.name = control_name
	label.custom_minimum_size = Vector2(rect.size.x * C.density, 0)
	label.clip_text = true
	parent.add_child(label)
	D.place(label, rect)
	label.size = rect.size * C.density
	return label
