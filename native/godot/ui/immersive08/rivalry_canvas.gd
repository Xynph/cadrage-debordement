extends Control
## Le registre des confrontations reste indexé par les identifiants du monde.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const S = preload("res://ui/data_semantics.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const Decisions = preload("res://ui/decision_views.gd")
const World = preload("res://ui/immersive08/world_archive.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")
const WIDTH := 2248
const LEFT := 1410
const RIGHT := 822
const PRIMARY := Color("106d43")
const PHASES := {"league": "Championnat", "pool":"Poules", "barrage": "Barrage", "elimination": "Match de barrage", "r16":"Huitième de finale", "quarter":"Quart de finale", "semi": "Demi-finale", "final": "Finale", "access": "Barrage d’accession"}
const TABS := ["Confrontations", "Échos des clubs", "Palmarès", "Carnet complet"]
const TAB_ICONS := ["tactic", "mail", "trophy", "save"]

var app: Control
var data: Dictionary
var state: Dictionary
var identities := {}
var active := 0
var workspace: Control
var tabs: Array[Button] = []
var panel_title: Label
var own: Dictionary

static func build(owner_app: Control, canvas: Control) -> void:
	var page: Control = load("res://ui/immersive08/rivalry_canvas.gd").new()
	page.app = owner_app
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, WIDTH, 1240))
	page._build()

func _build() -> void:
	name = "CarnetMonde"
	data = app.model.get("clubLife", {}).get("clubWorld", {})
	if not app.management_ui.get("rivalry") is Dictionary: app.management_ui.rivalry = {}
	state = app.management_ui.rivalry
	active = clampi(int(state.get("tab", 0)), 0, TABS.size() - 1)
	own = app.model.get("club", {})
	for league: Dictionary in app.model.get("leagues", []):
		for club: Dictionary in league.get("rows", []): identities[club.get("id")] = club
	for club: Dictionary in app.model.get("meta", {}).get("catalogue", []):
		if not identities.has(club.get("id")): identities[club.get("id")] = club
	identities[own.get("id")] = own
	_hero()
	_navigation()
	workspace = Control.new()
	workspace.name = "RivalryWorkspace"
	add_child(workspace)
	D.place(workspace, Rect2(0, 396, WIDTH, 828))
	_display()

func _hero() -> void:
	var hero := D.panel(self, Rect2(0, 0, WIDTH, 312), "", "", "", "RivalryHero")
	hero.clip_contents = true
	var japan := SeasonPreparation.is_japan(app.model.meta)
	var champ := SeasonPreparation.is_champ(app.model.meta)
	var ground := P.fixture_ground(app.model.meta,"stadium")
	D.photo(hero, ground, Rect2(938, 0, 1310, 312),.48 if ground != "stadium" else 0.0)
	C.veil(hero)
	D.text(hero, 26, 49, "LES TERRITOIRES DU RUGBY", 32, C.GOLD, 800, 364)
	D.line(hero, Vector2(404, 37), Vector2(547, 37), C.GOLD, 2)
	D.text(hero, 22, 127, "La mémoire des duels.", 86, C.IVORY, 800, 1125)
	D.text(hero, 28, 168, G.club_name(own) + "  ·  Saison " + G.season_label(app.model.meta.get("season")), 31, C.IVORY, 600, 1046)
	D.text(hero, 28, 205, "Les confrontations et les réactions enregistrées au fil de votre carrière.", 26, C.MUTED, 500, 1088)
	var pairs: Array = data.get("pairs", [])
	var club_pairs := pairs.filter(func(pair: Dictionary): return own.get("id") in [pair.get("a"), pair.get("b")])
	for i in 3:
		var x := 28 + i * 337
		var tile := D.rect(hero, Rect2(x, 223, 321, 73), Color("112621"), 7, Color("44634f"))
		_icon(tile, ["tactic", "shield", "trophy"][i], Rect2(16, 19, 35, 35), C.GOLD)
		D.text(tile, 64, 29, ["Duels suivis", "Duels du club", "Saisons archivées"][i], 24, C.MUTED, 600, 169)
		var number: int = [pairs.size(), club_pairs.size(), data.get("archives", []).size()][i]
		D.text(tile, 290, 53, str(number) if not data.is_empty() else "—", 44, C.IVORY, 800, 76, HORIZONTAL_ALIGNMENT_RIGHT)
	var preparation := SeasonPreparation.data(app.model.meta)
	if not preparation.is_empty():
		var title := "Préparation · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "srp")))
		var section := "ChampPreparation" if champ else "JapanPreparation" if japan else "PacificPreparation"
		var card := D.panel(hero,Rect2(1484,28,735,256),title,"calendar","",section)
		D.text(card,24,110,World.preparation_note(preparation),33,C.IVORY,700,685)
		var daily: bool = app.model.meta.has("calendarCadence")
		var description := "Le calendrier avance jour par jour jusqu’à la rencontre." if daily else "La préparation avance jusqu’à la prochaine rencontre."
		D.text(card,24,155,description,22,C.MUTED,400,686,HORIZONTAL_ALIGNMENT_LEFT,true)
		var advance := D.button(card,Rect2(24,182,687,53),app.primary_text().trim_suffix("  →"),app.primary_action,true,"arrow",false,app.accent,section+"Advance")
		advance.disabled = app.waiting

func _navigation() -> void:
	for i in TABS.size():
		var control := D.button(self, Rect2(i * 289, 328, 275, 53), TABS[i], func():
			active = i
			state.tab = i
			_display(), i == active, TAB_ICONS[i], false, PRIMARY, "RivalryTab" + str(i))
		tabs.append(control)
	for entry: Array in [[1486, "Classements", "trophy"], [1691, "Calendrier", "calendar"], [1896, "Parcours du manager", "flag"]]:
		var destination: String = "Carrière" if entry[1] == "Parcours du manager" else entry[1]
		D.button(self, Rect2(entry[0], 333, 352 if destination == "Carrière" else 192, 43), entry[1], func(): app._navigate(destination), false, entry[2], true, PRIMARY, "Section_" + destination)

func _display() -> void:
	_clear(workspace)
	for i in tabs.size():
		D.tab_state(tabs[i],Vector2(275,53),i==active,TAB_ICONS[i])
	match active:
		0: _pairs()
		1: _echoes()
		2: _archives()
		3: _world()

func _pairs() -> void:
	var panel := D.panel(workspace, Rect2(0, 0, LEFT, 828), "Les confrontations suivies", "tactic", "", "RivalryPairs")
	var only_club: bool = state.get("only_club", false)
	for i in 2:
		D.button(panel, Rect2(17 + i * 237, 67, 223, 40), "Notre club" if i == 1 else "Tous les clubs", func():
			state.only_club = i == 1
			state.page = 0
			_display()
			var focus := workspace.find_child("RivalryFilter" + str(i), true, false) as Button
			if focus != null: focus.grab_focus.call_deferred(), (i == 1) == only_club, "shield" if i == 1 else "people", true, PRIMARY, "RivalryFilter" + str(i))
	var pairs: Array = data.get("pairs", [])
	if only_club: pairs = pairs.filter(func(pair: Dictionary): return own.get("id") in [pair.get("a"), pair.get("b")])
	var selected := str(state.get("selected_pair", ""))
	var pages := maxi(1, ceili(float(pairs.size()) / 10.0))
	state.page = clampi(int(state.get("page", 0)), 0, pages - 1)
	var visible := pairs.slice(int(state.page) * 10, (int(state.page) + 1) * 10)
	if not visible.is_empty() and not visible.any(func(pair: Dictionary): return _pair_key(pair) == selected): selected = _pair_key(visible[0])
	var header := D.rect(panel, Rect2(1, 120, LEFT - 2, 38), Color("1c2829"), 4)
	D.text(header, 23, 27, "FACE-À-FACE", 23, C.IVORY, 700, 320)
	D.text(header, 767, 27, "MATCHS", 23, C.MUTED, 600, 101, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(header, 956, 27, "V / N / V", 23, C.MUTED, 600, 180, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(header, 1219, 27, "TENSION DU DUEL", 23, C.MUTED, 600, 270, HORIZONTAL_ALIGNMENT_CENTER)
	var pair_selected: Dictionary = {}
	for i in visible.size():
		var pair: Dictionary = visible[i]
		if _pair_key(pair) == selected: pair_selected = pair
		_pair_row(panel, pair, i, _pair_key(pair) == selected)
	if visible.is_empty():
		var message := "Aucune confrontation du club enregistrée." if only_club else "Les premiers duels apparaîtront après les rencontres disputées."
		D.text(panel, 26, 225, message, 28, C.MUTED, 500, LEFT - 49)
	D.text(panel, 23, 804, "%d duel(s) · Intensité et réactions des bancs" % pairs.size(), 22, C.MUTED, 500, 690)
	_pager(panel, "page", pages, 957, 778)
	_duel(pair_selected)

func _pair_row(parent: Panel, pair: Dictionary, index: int, selected: bool) -> void:
	var a: Variant = pair.get("a")
	var b: Variant = pair.get("b")
	var key := _pair_key(pair)
	var id := "RivalryPair_" + key.replace(":", "_")
	var row := D.button(parent, Rect2(2, 158 + 60 * index, LEFT - 4, 60), "", func():
		state.selected_pair = key
		_display()
		var focus := workspace.find_child(id, true, false) as Button
		if focus != null: focus.grab_focus.call_deferred(), selected, "", false, PRIMARY, id)
	row.set_meta("pair_key", key)
	row.accessibility_name = _club(a) + " contre " + _club(b)
	row.add_theme_stylebox_override("normal", C.box(Color("17462f") if selected else Color("131d20") if index % 2 == 0 else Color("101819"), Color(C.LINE, .55), 3, 0))
	_crest(row, a, Rect2(18, 9, 43, 43))
	D.text(row, 73, 37, _club(a), 27, C.IVORY, 700, 284)
	D.text(row, 359, 37, "VS", 22, C.GOLD, 700, 41, HORIZONTAL_ALIGNMENT_CENTER)
	_crest(row, b, Rect2(392, 9, 43, 43))
	D.text(row, 445, 37, _club(b), 27, C.IVORY, 700, 272)
	D.text(row, 767, 37, S.count_text(pair.get("games")), 27, C.IVORY, 700, 80, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(row, 956, 37, "%s / %s / %s" % [S.count_text(pair.get("winsA")), S.count_text(pair.get("draws")), S.count_text(pair.get("winsB"))], 26, C.IVORY, 600, 185, HORIZONTAL_ALIGNMENT_CENTER)
	var tension := S.count_text(pair.get("tension"))
	if tension != "—": D.bar(row, Rect2(1098, 26, 184, 9), float(tension), C.AMBER)
	D.text(row, 1375, 37, tension, 29, C.AMBER, 700, 84, HORIZONTAL_ALIGNMENT_RIGHT)

func _duel(pair: Dictionary) -> void:
	var panel := D.panel(workspace, Rect2(LEFT + 16, 0, RIGHT, 828), "Le dossier du duel", "shield", "", "RivalryDuel")
	var image := D.photo(panel, "club-forest", Rect2(15, 68, RIGHT - 30, 161))
	image.tooltip_text = "Le territoire du club"
	if pair.is_empty():
		D.text(panel, 23, 292, "Aucun duel à consulter", 35, C.IVORY, 800, RIGHT - 46)
		_notice(panel, Rect2(23, 331, RIGHT - 46, 140), "La mémoire des confrontations s’étoffe à chaque journée de compétition.")
		_notice(panel, Rect2(23, 674, RIGHT - 46, 132), str(data.get("notice", "")))
		return
	var a: Variant = pair.get("a")
	var b: Variant = pair.get("b")
	_crest(panel, a, Rect2(117, 249, 91, 91))
	_crest(panel, b, Rect2(614, 249, 91, 91))
	D.text(panel, 411, 312, "VS", 54, C.GOLD, 800, 151, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(panel, 163, 367, _club(a), 28, C.IVORY, 700, 299, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(panel, 659, 367, _club(b), 28, C.IVORY, 700, 299, HORIZONTAL_ALIGNMENT_CENTER)
	D.line(panel, Vector2(22, 390), Vector2(RIGHT - 22, 390))
	var entries := [["Victoires", "winsA", C.MINT], ["Nuls", "draws", C.MUTED], ["Victoires", "winsB", C.MINT]]
	for i in entries.size():
		var x := 18 + i * 268
		var tile := D.rect(panel, Rect2(x, 410, 251, 110), Color("152522"), 7, C.LINE)
		D.text(tile, 125, 41, entries[i][0], 26, C.MUTED, 600, 223, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(tile, 125, 87, S.count_text(pair.get(entries[i][1])), 47, entries[i][2], 800, 225, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(panel, 23, 564, "%s rencontre(s) · Dernière saison %s" % [S.count_text(pair.get("games")), G.season_label(pair.get("lastSeason"))], 28, C.IVORY, 600, RIGHT - 45)
	if pair.get("lastWinner") != null:
		D.text(panel, 23, 604, "Dernier vainqueur · " + _club(pair.lastWinner), 28, C.MINT, 700, RIGHT - 45)
	D.text(panel, 23, 648, "Intensité du duel · " + S.count_text(pair.get("tension")) + " / 100", 27, C.GOLD, 700, RIGHT - 45)
	_notice(panel, Rect2(23, 682, RIGHT - 46, 120), str(data.get("notice", "")))

func _echoes() -> void:
	var panel := D.panel(workspace, Rect2(0, 0, LEFT, 828), "Les échos des clubs", "mail", "", "RivalryEchoes")
	var events: Array = data.get("events", [])
	var pages := maxi(1, ceili(float(events.size()) / 4.0))
	state.echo_page = clampi(int(state.get("echo_page", 0)), 0, pages - 1)
	var visible := events.slice(int(state.echo_page) * 4, (int(state.echo_page) + 1) * 4)
	if visible.is_empty(): D.text(panel, 25, 112, "Aucun résultat suivi pour le moment.", 31, C.MUTED, 500, LEFT - 47)
	for i in visible.size():
		var event: Dictionary = visible[i]
		var card := D.button(panel, Rect2(16, 65 + i * 171, LEFT - 32, 157), "", func(): _echo_detail(event), false, "", false, PRIMARY, "RivalryEcho_" + str(i))
		card.accessibility_name = "Lire l’écho du match " + _club(event.get("a")) + " – " + _club(event.get("b"))
		card.add_theme_stylebox_override("normal", C.box(Color("152221"), C.LINE, 7, 0))
		var week: Variant = event.get("week", event.get("round"))
		var timing := "Saison " + G.season_label(event.get("season"))
		if S.count_text(week) != "—": timing += " · Semaine " + G.n(int(week) + 1)
		if app.model.meta.get("mode") == "world" and event.has("leagueId"): timing += " · " + _division(event.leagueId)
		D.text(card, 19, 28, timing + "  ·  " + str(PHASES.get(event.get("phase"), "Compétition")), 24, C.GOLD, 600, LEFT - 70)
		D.text(card, 19, 66, "%s   %s – %s   %s" % [_club(event.get("a")), S.count_text(event.get("home")), S.count_text(event.get("away")), _club(event.get("b"))], 35, C.IVORY, 700, LEFT - 73)
		var reaction := "Réaction de " + _club(event.get("clubId")) + " · « " + str(event.get("reaction", "")) + " »"
		var excerpt := C.wrap(reaction, 21, C.MUTED)
		excerpt.max_lines_visible = 2
		excerpt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.add_child(excerpt)
		D.place(excerpt, Rect2(19, 80, LEFT - 97, 54))
		D.text(card, LEFT - 66, 142, "Lire l’écho  ›", 22, C.GOLD, 700, 126, HORIZONTAL_ALIGNMENT_RIGHT)
	_pager(panel, "echo_page", pages, 957, 778)
	var context := D.panel(workspace, Rect2(LEFT + 16, 0, RIGHT, 828), "La mémoire du terrain", "ball", "", "RivalryEchoContext")
	D.photo(context, "stadium", Rect2(17, 68, RIGHT - 34, 251))
	D.text(context, 24, 369, "%d résultat(s) suivi(s)" % events.size(), 38, C.IVORY, 800, RIGHT - 49)
	_notice(context, Rect2(24, 397, RIGHT - 49, 148), str(data.get("notice", "")))
	if not visible.is_empty() and visible[0].get("winner") != null and visible[0].get("home") == visible[0].get("away"):
		D.text(context, 24, 584, "Vainqueur après départage", 28, C.GOLD, 600, RIGHT - 48)
		D.text(context, 24, 619, _club(visible[0].winner), 31, C.IVORY, 700, RIGHT - 48)

func _echo_detail(event: Dictionary) -> void:
	var view := Decisions.dialog(app, "Les échos des clubs", "RivalryEchoDetail", 940)
	var list: VBoxContainer = view[1]
	list.add_child(C.wrap("%s  %s – %s  %s" % [_club(event.get("a")), S.count_text(event.get("home")), S.count_text(event.get("away")), _club(event.get("b"))], 35, C.IVORY, true, 700))
	if event.get("winner") != null and event.get("home") == event.get("away"):
		list.add_child(C.wrap("Vainqueur après départage : " + _club(event.winner), 25, C.GOLD, true))
	list.add_child(C.rule())
	list.add_child(C.label("RÉACTION DU BANC · " + _club(event.get("clubId")).to_upper(), 25, C.GOLD, true, 700))
	list.add_child(C.wrap("« " + str(event.get("reaction", "")) + " »", 23, C.IVORY))
	list.add_child(C.wrap("Pression %s / 100 · Tension du duel %s / 100" % [S.count_text(event.get("pressure")), S.count_text(event.get("tension"))], 22, C.MUTED, true))
	view[0].popup_centered(Vector2i(940, 520))

func _archives() -> void:
	var panel := D.panel(workspace, Rect2(0, 0, LEFT, 828), "Le palmarès conservé", "trophy", "", "RivalryArchives")
	var scroll := ScrollContainer.new()
	scroll.name = "RivalryArchiveScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	D.place(scroll, Rect2(19, 72, LEFT - 38, 734))
	var list := C.v(12)
	C.fill(list)
	scroll.add_child(list)
	var archives: Array = data.get("archives", [])
	var years: Array = data.get("years", [])
	if archives.is_empty() and years.is_empty(): list.add_child(C.wrap("Aucun palmarès enregistré dans cette carrière.", 29, C.MUTED, true))
	for archive: Dictionary in archives:
		var card := C.card("Saison " + G.season_label(archive.get("season")))
		list.add_child(card)
		var body := C.content(card)
		var titles := World.titles(archive)
		if not titles.is_empty():
			for champion: Dictionary in titles:
				if champion.get("clubId") != null:
					body.add_child(C.wrap(_division(champion.get("leagueId")) + " · " + _club(champion.get("clubId")), 29, C.IVORY, true, 700))
		elif archive.get("champion") != null:
			body.add_child(C.wrap(_club(archive.champion), 29, C.IVORY, true, 700))
	for year: Dictionary in years:
		list.add_child(C.wrap("Saison %s · %s rencontre(s) suivie(s) · %s rivalité(s) intense(s)" % [G.season_label(year.get("season")), S.count_text(year.get("matches")), S.count_text(year.get("rivalries"))], 26, C.MUTED, true))
	var context := D.panel(workspace, Rect2(LEFT + 16, 0, RIGHT, 828), "Les saisons de la carrière", "calendar", "", "RivalryArchiveContext")
	D.photo(context, "trophy", Rect2(17, 69, RIGHT - 34, 302))
	D.text(context, 24, 425, "%d saison(s) suivie(s)" % years.size(), 37, C.IVORY, 800, RIGHT - 49)
	_notice(context, Rect2(24, 453, RIGHT - 49, 132), str(data.get("notice", "")))
	D.button(context, Rect2(22, 744, RIGHT - 44, 60), "Ouvrir les archives des championnats", func(): app.ClubViews.season_archives(app), true, "arrow", false, PRIMARY, "RivalryOpenSeasonArchives")

func _world() -> void:
	var panel := D.panel(workspace, Rect2(0, 0, WIDTH, 828), "Carnet des territoires", "flag", "", "RivalryWorldNotebook")
	var content: Control = app.WorldViews.build(app)
	panel.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 19 * C.density
	content.offset_top = 68 * C.density
	content.offset_right = -19 * C.density
	content.offset_bottom = -18 * C.density
	Legacy.apply(content, PRIMARY)

func _pager(parent: Node, key: String, pages: int, x: float, y: float) -> void:
	if pages <= 1: return
	for i in 2:
		var direction := -1 if i == 0 else 1
		var id := "RivalryPrevious" if i == 0 else "RivalryNext"
		var button := D.button(parent, Rect2(x + i * 253, y, 170, 37), "← Précédent" if i == 0 else "Suivant →", func():
			state[key] = int(state[key]) + direction
			_display()
			var target := workspace.find_child(id, true, false) as Button
			if target != null and target.disabled: target = workspace.find_child("RivalryNext" if i == 0 else "RivalryPrevious", true, false) as Button
			if target != null: target.grab_focus.call_deferred(), false, "", true, PRIMARY, id)
		button.disabled = int(state[key]) + direction not in range(pages)
	D.text(parent, x + 211, y + 26, "%d / %d" % [int(state[key]) + 1, pages], 22, C.MUTED, 600, 71, HORIZONTAL_ALIGNMENT_CENTER)

func _club(id: Variant) -> String:
	var team: Dictionary = identities.get(id, {})
	return G.club_name(team) if not team.is_empty() else "Club " + G.n(id) if id != null else "Club non identifié"

func _division(id: Variant) -> String:
	return World.name_for(app.model,str(id)) if id != null else "Championnat"

func _crest(parent: Node, id: Variant, area: Rect2) -> void:
	var team: Dictionary = identities.get(id, {})
	if team.is_empty(): return
	var crest := G.crest(team, C.px(area.size.x))
	parent.add_child(crest)
	D.place(crest, area)

static func _pair_key(pair: Dictionary) -> String:
	return "%s:%s" % [G.n(pair.get("a")), G.n(pair.get("b"))]

static func _notice(parent: Node, area: Rect2, value: String) -> void:
	var text := C.wrap(value, 21, C.MUTED)
	parent.add_child(text)
	D.place(text, area)

static func _icon(parent: Node, key: String, area: Rect2, tint: Color) -> void:
	var icon := C.icon(key, int(area.size.x), tint)
	parent.add_child(icon)
	D.place(icon, area)

static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
