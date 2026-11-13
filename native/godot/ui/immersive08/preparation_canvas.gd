extends Control
## Dossier adverse et intentions de jeu. Le troisième onglet ouvre le planning.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")
const World = preload("res://ui/immersive08/world_archive.gd")
const Decisions = preload("res://ui/decision_views.gd")
const MatchContext = preload("res://ui/preparation_match_context.gd")
const Briefing = preload("res://ui/preparation_briefing.gd")
const PersonName = preload("res://ui/person_name.gd")
const TABS = ["Dossier", "Consignes", "Entrainement"]
const GREEN = Color("63e994")
const GOLD = Color("ffcd69")
const CHAMP_DOSSIER_PENDING = "Le dossier adverse sera disponible la semaine du match."

var app: Control
var state: Dictionary
var active_tab := 0
var focus_ready := false
var reports: Dictionary
var fixture: Dictionary
var match_context := MatchContext.new()

static func build(application: Control, canvas: Control) -> void:
	var page := new()
	page.name = "ImmersivePreparation"
	page.app = application
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, 2248, 1230))
	page._build()

static func compact(app: Control) -> Control:
	var dossier: Control = app.SquadViews.preparation(app)
	var next: Variant = app.model.get("next")
	if not SeasonPreparation.is_japan(app.model.meta):
		var context: Control
		if next is Dictionary and not next.is_empty():
			context = _compact_fixture(app,next)
		else:
			var upcoming := _upcoming_preparation_note(app.model.meta)
			if not upcoming.is_empty():
				context = C.wrap(upcoming,26,C.GOLD,true,700)
				if SeasonPreparation.is_champ(app.model.meta):
					var summary := C.v(4)
					summary.add_child(context)
					summary.add_child(C.wrap(CHAMP_DOSSIER_PENDING,20,C.MUTED))
					context = summary
		if context != null:
			dossier.add_child(context)
			dossier.move_child(context,0)
		return dossier
	var preparation := SeasonPreparation.data(app.model.meta)
	if preparation.is_empty() and not next is Dictionary: return dossier
	var page := C.v(10)
	C.fill(page,true)
	var card := C.card()
	page.add_child(card)
	var row := C.h(20)
	C.content(card).add_child(row)
	var summary := C.v(4)
	C.fill(summary)
	row.add_child(summary)
	summary.add_child(C.wrap(("PRÉPARATION · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "jlo-d1")))).to_upper(),30,C.GOLD,true,700))
	if not preparation.is_empty():
		summary.add_child(C.wrap(World.preparation_note(preparation),29,C.IVORY))
		var advance := C.button(app.primary_text(),app.primary_action,true,app.accent)
		advance.name = "JapanPreparationDossierAdvance"
		advance.disabled = app.waiting
		row.add_child(advance)
	else:
		summary.add_child(_compact_fixture(app,next,true))
	page.add_child(dossier)
	return page

static func _upcoming_preparation_note(meta: Dictionary) -> String:
	if meta.get("leagueId") not in ["srp", "champ"]: return ""
	var preparation := SeasonPreparation.data(meta)
	return "" if preparation.is_empty() else World.preparation_note(preparation)

static func _fixture_position(app: Control, next: Dictionary, show_date: bool) -> String:
	var position := P.fixture_position(next,app.model.club.get("id"))
	var date := P.fixture_date(next,true) if show_date else ""
	return position if date.is_empty() else position+"  ·  "+date

static func _compact_fixture(app: Control, next: Dictionary, show_date: bool = false) -> HBoxContainer:
	var row := C.h(16)
	var position := C.label(_fixture_position(app,next,show_date),26,C.GOLD,true,700)
	position.name = "PreparationFixturePosition"
	row.add_child(position)
	var venue_name := P.fixture_venue(next,false)
	if not venue_name.is_empty():
		var venue := C.wrap(venue_name,26,C.IVORY,true,600)
		venue.name = "PreparationFixtureVenue"
		C.fill(venue)
		row.add_child(venue)
	return row

func _build() -> void:
	if not app.management_ui.get("preparation") is Dictionary:
		app.management_ui.preparation = {"tab":0,"outer":[0,0,0],"attack":0,"defense":0,"focus":["","",""]}
	state = app.management_ui.preparation
	active_tab = clampi(int(state.tab), 0, 1)
	reports = app.model.get("decisions", {}).get("preparation") if app.model.get("decisions", {}).get("preparation") is Dictionary else {}
	fixture = app.model.get("next") if app.model.get("next") is Dictionary else {}
	_heading()
	if active_tab == 0: _dossier()
	else: _consignes()
	add_child(match_context)
	match_context.bind(app)
	app.bridge.model_changed.connect(_refresh_briefing)
	_observe(self)
	if app.body_scroll != null:
		app.body_scroll.get_v_scroll_bar().value_changed.connect(func(value: float):
			if focus_ready: state.outer[active_tab] = int(value))
	_restore.call_deferred()

func _refresh_briefing(model: Dictionary) -> void:
	# Ticks update the live-state wording without rebuilding the focused page.
	var button := find_child("PreparationBriefing_live", true, false) as Button
	if button == null: return
	for check: Dictionary in Briefing.project(model).checks:
		if check.id != "live": continue
		button.text = check.title + "  →"
		button.tooltip_text = check.detail + "\n" + check.caption
		button.accessibility_name = check.title + " · " + check.detail

func _heading() -> void:
	var hero := D.panel(self, Rect2(0, 0, 2248, 167), "", "", "", "PreparationHero")
	hero.clip_contents = true
	var japan := SeasonPreparation.is_japan(app.model.meta)
	var preparation := SeasonPreparation.data(app.model.meta) if japan else {}
	D.photo(hero, "japan-ground" if japan else "tactics-briefing", Rect2(1095, 1, 1151, 165), .5 if japan else 0.0)
	var shadow := Control.new()
	D.place(shadow, Rect2(1013, 0, 635, 167))
	hero.add_child(shadow)
	C.veil(shadow)
	var overline := D.text(hero, 28, 36, ("PRÉPARATION · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "jlo-d1")))).to_upper() if japan else "PRÉPARATION DE MATCH", 27, GOLD, 700, 1065 if active_tab == 1 else 680)
	if active_tab == 1:
		overline.name = "PreparationLiveContext"
		match_context.live_context = overline
	var heading := ("Préparer la saison · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "jlo-d1")))) if not preparation.is_empty() else "Préparer la prochaine rencontre."
	app.heading = D.text(hero, 26, 103, heading, 66, C.IVORY, 800, 1355)
	if active_tab == 1:
		app.heading.name = "PreparationContextHeading"
		match_context.live_heading = app.heading
	var context := _upcoming_preparation_note(app.model.meta) if fixture.is_empty() else ""
	if context.is_empty(): context = "Aucune rencontre annoncée"
	if not fixture.is_empty():
		context = "%s – %s  ·  %s" % [G.club_name(fixture.get("home", {})), G.club_name(fixture.get("away", {})), fixture.get("label", "")]
	if not preparation.is_empty():
		context = World.preparation_note(preparation)
		var advance := _button(hero, Rect2(1564, 83, 640, 53), app.primary_text().trim_suffix("  →"), app.primary_action, true, "arrow", "JapanPreparationDossierAdvance")
		advance.disabled = app.waiting
	elif not fixture.is_empty():
		var location := D.panel(hero,Rect2(1392,76,812,77),"","","","PreparationFixtureLocation")
		var venue_name := P.fixture_venue(fixture,false)
		D.text(location,16,49 if venue_name.is_empty() else 29,_fixture_position(app,fixture,true),20,C.GOLD,700,780).name = "PreparationFixturePosition"
		if not venue_name.is_empty():
			D.text(location,16,61,venue_name,24,C.IVORY,600,780).name = "PreparationFixtureVenue"
	D.text(hero, 29, 143, context, 25, C.IVORY, 500, 1220)
	var tabbar := Control.new()
	tabbar.name = "PreparationTabs"
	tabbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tabbar)
	D.place(tabbar, Rect2(0, 182, 2248, 57))
	for i in TABS.size():
		var caption: String = ["Dossier adverse", "Consignes", "Entraînement"][i]
		var button := _button(tabbar, Rect2(i * 274 + 2, 0, 263, 53), caption, func(): _choose(i), i == active_tab, "", "PreparationTab" + TABS[i])
		if i == 1: match_context.focus_fallback = button
		button.toggle_mode = true
		button.set_pressed_no_signal(i == active_tab)
		button.gui_input.connect(func(event: InputEvent):
			if event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT, KEY_RIGHT]:
				button.accept_event()
				_choose(posmod(i + (1 if event.keycode == KEY_RIGHT else -1), TABS.size())))
	var show_match := MatchContext.match_available(app.model)
	_button(tabbar, Rect2(830, 0, 300, 53), "Préparer la suite", func(): load("res://ui/manager_planning.gd").open(app), false, "calendar", "PreparationManagerPlanning")
	var match_space := 385 if show_match else 0
	# Reprise (reprise.cjs) : date de reprise, groupe et jeunes, tant que la décision est ouverte.
	if not show_match and preload("res://ui/reprise_view.gd").relevant(app.model):
		_button(tabbar, Rect2(1140, 0, 378, 53), "La reprise", func(): load("res://ui/reprise_dialog.gd").open(app), false, "calendar", "PreparationReprise")
	_button(tabbar, Rect2(1528 - match_space, 0, 337, 53), "Revoir la composition", func(): app._navigate("Composition"), false, "people", "PreparationComposition")
	_button(tabbar, Rect2(1883 - match_space, 0, 365, 53), "Carnet de jeu", func(): app._navigate("Plan de jeu"), not show_match, "arrow", "PreparationOpenPlaybook")
	if show_match:
		match_context.match_button = _button(tabbar, Rect2(1883, 0, 365, 53), "", match_context.open_match, true, "arrow", "PreparationGoMatch")
	D.line(self, Vector2(0, 241), Vector2(2248, 241), Color(C.LINE, .85))

func _choose(index: int) -> void:
	if index == active_tab:
		var current := find_child("PreparationTab" + TABS[index], true, false) as Button
		current.set_pressed_no_signal(true)
		return
	if app.body_scroll != null: state.outer[active_tab] = app.body_scroll.scroll_vertical
	state.tab = index
	state.focus[index] = "PreparationTab" + TABS[index]
	var owner := app
	owner._render()
	if index == 2:
		var next := owner.find_child("TrainingTab0", true, false) as Button
		if next != null: next.grab_focus.call_deferred()

func _observe(node: Node) -> void:
	if node is BaseButton and node.focus_mode != Control.FOCUS_NONE and node != match_context.pause_button:
		node.focus_entered.connect(func():
			if focus_ready: state.focus[active_tab] = str(node.name))
	for child in node.get_children(): _observe(child)

func _restore() -> void:
	if not is_inside_tree(): return
	var tree := get_tree()
	await tree.process_frame
	if not is_inside_tree(): return
	await tree.process_frame
	if not is_inside_tree(): return
	for pair: Array in [["PreparationAttackScroll", "attack"], ["PreparationDefenseScroll", "defense"]]:
		var scroll := find_child(pair[0], true, false) as ScrollContainer
		if scroll != null: scroll.scroll_vertical = int(state.get(pair[1], 0))
	if app.body_scroll != null: app.body_scroll.scroll_vertical = int(state.outer[active_tab])
	focus_ready = true
	var focus_id := str(state.focus[active_tab])
	if focus_id.is_empty(): return
	var previous := find_child(focus_id, true, false) as BaseButton
	if previous != null and previous.is_visible_in_tree():
		if previous.disabled: previous = find_child("PreparationTab" + TABS[active_tab], true, false) as BaseButton
		previous.grab_focus()

func _dossier() -> void:
	var section := _section("PreparationDossier")
	if reports.is_empty():
		var empty := D.panel(section, Rect2(0, 0, 1344, 596), "Dossier adverse", "search", "", "PreparationUnknownOpponent")
		var champ_preparing := fixture.is_empty() and SeasonPreparation.is_champ(app.model.meta) and not SeasonPreparation.data(app.model.meta).is_empty()
		var opponent := _opponent()
		if not opponent.is_empty():
			_crest(empty, opponent, Rect2(30, 86, 92, 94))
			D.text(empty, 150, 127, G.club_name(opponent), 42, C.IVORY, 700, 1130).name = "PreparationKnownOpponent"
			D.text(empty, 150, 169, "ADVERSAIRE ANNONCÉ AU CALENDRIER", 24, GOLD, 600, 1130)
		var lines := D.words(CHAMP_DOSSIER_PENDING if champ_preparing else "Aucun dossier disponible pour cette rencontre.", 86, 3)
		for line in lines.size(): D.text(empty, 29, 242 + line * 35, lines[line], 28, C.IVORY, 600, 1270)
		D.text(empty, 29, 371, "Les résultats récents, les notes et les joueurs adverses", 25, C.MUTED, 500, 1270)
		D.text(empty, 29, 406, "seront affichés lorsque ces informations seront publiées.", 25, C.MUTED, 500, 1270)
		_button(empty, Rect2(28, 488, 520, 58), "Voir le calendrier", func(): app._navigate("Calendrier"), false, "calendar", "PreparationOpenCalendar")
		_recommended(section)
		_recent(section)
		_threats(section)
		return
	var comparison := D.panel(section, Rect2(0, 0, 1344, 596), "Rapport de force", "tactic", "", "PreparationComparison")
	var opponent := _opponent()
	var ours: Dictionary = app.model.club
	_crest(comparison, ours, Rect2(26, 72, 70, 73))
	_crest(comparison, opponent, Rect2(1245, 72, 70, 73))
	D.text(comparison, 117, 108, G.club_name(ours), 28, C.IVORY, 700, 488)
	D.text(comparison, 117, 138, "VOTRE XV SÉLECTIONNÉ", 17, GREEN, 700, 475)
	D.text(comparison, 1226, 108, G.club_name(opponent), 28, C.IVORY, 700, 477, HORIZONTAL_ALIGNMENT_RIGHT)
	D.text(comparison, 1226, 138, "XV ADVERSE PROJETÉ", 17, GOLD, 700, 469, HORIZONTAL_ALIGNMENT_RIGHT)
	D.text(comparison, 672, 117, "VS", 30, C.MUTED, 600, 70, HORIZONTAL_ALIGNMENT_CENTER)
	D.line(comparison, Vector2(22, 163), Vector2(1322, 163))
	var domains: Array = reports.get("domains", [])
	if domains.is_empty():
		D.text(comparison, 28, 266, "La comparaison par secteur n’est pas disponible.", 29, C.MUTED, 500, 1270)
	var row_height := minf(75.0, 369.0 / maxi(1, domains.size()))
	for i in domains.size():
		var domain: Dictionary = domains[i]
		var y := 176.0 + row_height * i
		D.rect(comparison, Rect2(20, y, 1304, row_height - 3), Color("14201f") if i % 2 else Color("10191a"), 3)
		D.text(comparison, 81, y + 30, G.n(domain.get("own", "—")), 21, GREEN, 700, 60, HORIZONTAL_ALIGNMENT_CENTER)
		if domain.get("own") is float or domain.get("own") is int:
			D.bar(comparison, Rect2(129, y + 19, 375, 12), float(domain.own), GREEN)
		D.text(comparison, 674, y + 29, domain.get("label", "Secteur"), 19, C.IVORY, 600, 315, HORIZONTAL_ALIGNMENT_CENTER)
		if domain.get("opponent") is float or domain.get("opponent") is int:
			D.bar(comparison, Rect2(844, y + 19, 375, 12), float(domain.opponent), GOLD)
		D.text(comparison, 1264, y + 30, G.n(domain.get("opponent", "—")), 21, GOLD, 700, 65, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(comparison, 23, 576, "Comparaison chiffrée indisponible" if domains.is_empty() else "Évaluations sur 100 ajustées à la condition", 17, C.MUTED, 500, 1297)
	_recommended(section)
	_recent(section)
	_threats(section)

func _recommended(section: Control) -> void:
	var panel := D.panel(section, Rect2(1361, 0, 887, 596), "Avant le coup d’envoi", "flag", "", "PreparationRecommendation")
	var briefing := Briefing.project(app.model)
	var checks: Array = briefing.checks
	var indicators := [["FEUILLE", "Valide" if app.model.get("selection", {}).get("valid", false) else "À vérifier", GREEN if app.model.get("selection", {}).get("valid", false) else GOLD], ["CONDITION DU XV", P.lineup_condition(app.model), GREEN], ["DOSSIER ADVERSE", "%d secteurs" % int(briefing.domains) if briefing.reportAvailable else "Non publié", GOLD]]
	for index in indicators.size():
		var x := 23 + index * 283
		D.rect(panel, Rect2(x, 69, 272, 50), Color("172724"), 4)
		D.text(panel, x+9, 87, indicators[index][0], 15, C.MUTED, 600, 253)
		D.text(panel, x+9, 109, indicators[index][1], 21, indicators[index][2], 700, 253)
	for index in mini(5, checks.size()):
		var check: Dictionary = checks[index]
		var y := 129 + index * 61
		D.rect(panel, Rect2(18, y, 850, 56), Color(Briefing.color(check), .045), 4, Color(Briefing.color(check), .25))
		var icon := C.icon({"press":"mail","selection":"people","day":"calendar","international":"flag","injuries":"heart","tactics":"tactic","sheet":"check","calendar":"calendar","live":"ball","ended":"trophy"}.get(check.id,"flag"),21,Briefing.color(check))
		panel.add_child(icon); D.place(icon,Rect2(28,y+9,21,21))
		var action := _button(panel, Rect2(57, y + 3, 795, 25), check.title + "  →", Briefing.open_action.bind(app, check.action, _choose.bind(1)), false, "", "PreparationBriefing_" + str(check.id))
		action.add_theme_font_size_override("font_size", C.px(20))
		action.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,2))
		_dense_button(action,20,27)
		action.tooltip_text = check.detail + "\n" + check.caption
		action.accessibility_name = check.title + " · " + check.detail
		D.text(panel, 61, y + 46, check.detail, 17, C.MUTED, 500, 784, HORIZONTAL_ALIGNMENT_LEFT, true)
	if checks.size() < 5:
		var image_top := 129 + checks.size()*61
		var club := _opponent()
		if club.is_empty(): club = app.model.club
		var picture := G.club_picture(club)
		picture.custom_minimum_size = Vector2.ZERO
		panel.add_child(picture)
		D.place(picture,Rect2(20,image_top,847,432-image_top))
		var caption := "Photo d’archive" if picture.get_meta("photo_kind") == "archive" else "Photo du pack" if picture.get_meta("photo_kind") == "pack" else "Illustration IA · ambiance du club"
		D.text(panel,30,424,caption,16,C.MUTED,500,827)
	var tactics: Dictionary = app.model.get("tactics", {})
	D.text(panel,23,455,"AVEC BALLON · " + _tactic_label(tactics.get("attacks", []), tactics.get("attack")),18,GREEN,600,414)
	D.text(panel,451,455,"SANS BALLON · " + _tactic_label(tactics.get("defenses", []), tactics.get("defense")),18,GOLD,600,414)
	var all := _button(panel, Rect2(22, 477, 411, 44), "Tous les repères (%d)" % checks.size(), Briefing.open_all.bind(app, _choose.bind(1)), false, "search", "PreparationBriefingAll")
	all.add_theme_font_size_override("font_size", C.px(19))
	_button(panel, Rect2(451, 477, 413, 44), "Conseils détaillés", _open_dossier, false, "arrow", "OpenOppositionDossier").disabled = reports.is_empty()
	var advice: Dictionary = reports.get("advice", {})
	var adopt := _button(panel, Rect2(22, 536, 842, 44), "Adopter le plan proposé par le staff", func(): app._command("set_tactics", {"attack":advice.attack, "defense":advice.defence}), true, "arrow", "PreparationAdoptPlan")
	adopt.disabled = advice.is_empty() or not app._live().is_empty() or app.model.meta.get("phase") == "ended"

func _summary_line(panel: Panel, y: int, label: String, title: String, detail: String, tone: Color) -> void:
	D.text(panel, 24, y + 17, label, 20, tone, 700, 304)
	D.text(panel, 24, y + 49, title, 29, C.IVORY, 700, 831)
	var lines := D.words(detail, 94, 2)
	for i in lines.size(): D.text(panel, 24, y + 79 + i * 23, lines[i], 22, C.MUTED, 500, 831)

func _open_dossier() -> void:
	Decisions.dossier(app)
	var dialog := app.get_node_or_null("OppositionDossier") as AcceptDialog
	if dialog == null: return
	dialog.set_meta("immersive_dialog_size", Vector2i(900, 580))

func _recent(section: Control) -> void:
	var panel := D.panel(section, Rect2(0, 614, 900, 352), "Les faits récents", "calendar", "", "PreparationRecent")
	var recent: Array = reports.get("recent", [])
	var opponent := _opponent()
	if recent.is_empty():
		D.text(panel, 24, 93, "Résultats adverses non publiés dans ce dossier." if reports.is_empty() else "Aucun résultat adverse enregistré cette saison.", 19, C.MUTED, 500, 850)
		var club := _opponent()
		if not club.is_empty():
			var picture := G.club_picture(club)
			panel.add_child(picture); D.place(picture,Rect2(22,110,856,145))
			D.text(panel,32,243,"Photo d’archive" if picture.get_meta("photo_kind") == "archive" else "Photo du pack" if picture.get_meta("photo_kind") == "pack" else "Illustration IA · ambiance du club",16,C.MUTED,500,820)
	for i in mini(5, recent.size()):
		var result: Dictionary = recent[i]
		var y := 70 + i * 40
		var score: Array = result.get("score", [])
		var home: bool = int(result.get("side", 0)) == 0
		var other := _club(result.get("opponentId"))
		var round_label := "Journée " + G.n(int(result.get("round", 0)) + 1) if result.get("phase") == "league" else str(result.get("phase", ""))
		D.rect(panel, Rect2(20, y, 860, 36), Color("162321") if i % 2 == 0 else Color("111a1c"), 3)
		D.text(panel, 30, y + 25, round_label, 16, C.MUTED, 500, 120)
		D.text(panel, 160, y + 25, G.club_name(opponent if home else other), 18, C.IVORY, 600, 280)
		D.text(panel, 485, y + 25, "%s – %s" % [G.n(score[0]), G.n(score[1])] if score.size() == 2 else "—", 21, GOLD, 700, 80, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(panel, 550, y + 25, G.club_name(other if home else opponent), 18, C.IVORY, 600, 320)
	D.line(panel,Vector2(23,277),Vector2(876,277),Color(C.LINE,.7))
	var today := P.fixture_date({"date":app.model.get("meta",{}).get("calendarToday", "")})
	var stages := [["1 · JOURNÉE",today if not today.is_empty() else "Date non publiée"],["2 · FEUILLE","Projetée valide" if app.model.get("selection",{}).get("valid",false) else "À compléter"],["3 · RENCONTRE",P.fixture_date(fixture) if not fixture.is_empty() else "Non annoncée"]]
	for index in stages.size():
		D.text(panel,25+index*288,302,stages[index][0],17,GOLD,700,270)
		D.text(panel,25+index*288,329,stages[index][1],16,C.MUTED,500,270)
	_sheet_map(section)

func _sheet_map(section: Control) -> void:
	var panel := D.panel(section,Rect2(917,614,427,352),"Votre XV projeté","people","","PreparationSheetMap")
	D.rect(panel,Rect2(15,65,397,263),Color("153b2c"),3,Color("4b7f64"))
	for y in [130,196,263]: D.line(panel,Vector2(18,y),Vector2(409,y),Color("6e9e81",.3))
	D.line(panel,Vector2(213,68),Vector2(213,326),Color("6e9e81",.3))
	var positions := [Vector2(.22,.06),Vector2(.5,.06),Vector2(.78,.06),Vector2(.36,.23),Vector2(.64,.23),Vector2(.18,.40),Vector2(.5,.40),Vector2(.82,.40),Vector2(.34,.56),Vector2(.66,.56),Vector2(.12,.74),Vector2(.38,.74),Vector2(.62,.74),Vector2(.88,.74),Vector2(.5,.91)]
	var lineup: Array = app.model.get("lineup", [])
	for index in 15:
		var id: Variant = lineup[index] if index < lineup.size() else null
		var player := P.player(app.model,str(id)) if id != null else {}
		var point: Vector2 = Vector2(15,77)+positions[index]*Vector2(397,239)
		var button := _button(panel,Rect2(point.x-15,point.y-14,30,28),str(index+1),_open_sheet_player.bind(str(id)),false,"","PreparationXIPlayer_"+str(index+1))
		button.disabled = player.is_empty()
		button.add_theme_font_size_override("font_size",C.px(17))
		button.add_theme_stylebox_override("normal",C.box(Color("e7c46a") if not player.is_empty() else Color("4b5a50"),Color("eee5cd"),14,0))
		button.add_theme_color_override("font_color",Color("11251c"))
		_dense_button(button,17,28)
		button.size.x = C.px(30)
		button.tooltip_text = str(player.get("name","Poste non affecté")) + " · " + str(player.get("pos",""))
		button.set_meta("player_id",id)
		var surname := PersonName.surname(str(player.get("name","—")))
		D.text(panel,point.x,point.y+26,surname,13,C.IVORY,500,72,HORIZONTAL_ALIGNMENT_CENTER)
	D.text(panel,18,345,"Schéma indicatif · cliquer pour la fiche",14,C.MUTED,500,390)

func _open_sheet_player(id: String) -> void:
	app.selected_player = id
	app._navigate("Effectif")

func _dense_button(button: Button, font_size: int, height: int) -> void:
	button.custom_minimum_size = Vector2.ZERO
	button.add_theme_font_size_override("font_size",C.px(font_size))
	for kind in ["normal","hover","pressed","disabled","focus"]:
		var style := button.get_theme_stylebox(kind).duplicate() as StyleBox
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		style.content_margin_left = C.px(3)
		style.content_margin_right = C.px(3)
		button.add_theme_stylebox_override(kind,style)
	button.size.y = C.px(height)

func _threats(section: Control) -> void:
	var panel := D.panel(section, Rect2(1361, 614, 887, 352), "Joueurs à surveiller", "people", "", "PreparationThreats")
	var threats: Array = reports.get("threats", [])
	if threats.is_empty(): D.text(panel, 23, 106, "Liste adverse non publiée dans le dossier." if reports.is_empty() else "Aucun joueur projeté à surveiller.", 25, C.MUTED, 500, 822)
	for i in mini(3, threats.size()):
		var p: Dictionary = threats[i]
		var y := 69 + i * 77
		if not str(p.get("id","")).is_empty():
			var portrait := G.portrait(0,0,p)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(portrait);D.place(portrait,Rect2(20,y+3,72,64))
		else:
			var neutral := C.icon("people",48,C.MUTED)
			panel.add_child(neutral); D.place(neutral,Rect2(31,y+12,48,48))
		D.text(panel, 111, y + 29, p.get("name", "Joueur"), 22, C.IVORY, 700, 740)
		D.text(panel, 111, y + 56, "%s  ·  %s" % [p.get("pos", ""), p.get("role", "")], 17, C.MUTED, 500, 740)
		D.line(panel, Vector2(20, y + 73), Vector2(863, y + 73), Color(C.LINE, .67))
	var signals: Array = reports.get("signals", [])
	D.text(panel, 23, 331, "%d signal(aux) documenté(s) · détails dans le dossier" % signals.size() if not signals.is_empty() else "Observations adverses indisponibles." if reports.is_empty() else "Pas de signal robuste dans les observations disponibles.", 24, GOLD, 500, 842)

func _consignes() -> void:
	var section := _section("PreparationConsignes")
	match_context.consignes = section
	var tactics: Dictionary = app.model.get("tactics", {})
	for i in 2:
		var pair: Array = [["attack", "attacks", "Avec le ballon", "Attack", "ball", GREEN], ["defense", "defenses", "Sans le ballon", "Defense", "shield", GOLD]][i]
		var card := D.panel(section, Rect2(i * 1132, 0, 1116, 853), pair[2], pair[4], "", "Preparation" + str(pair[3]))
		D.text(card, 22, 94, "Votre intention de jeu pour la rencontre", 26, C.IVORY, 500, 1065)
		if i == 0:
			match_context.status = D.text(card, 22, 131, "", 23, C.IVORY, 500, 745)
			match_context.status.name = "PreparationMatchState"
			match_context.pause_button = _button(card, Rect2(771, 100, 323, 45), "Mettre en pause", match_context.pause_match, true, "", "PreparationPauseMatch")
		else:
			D.text(card, 22, 131, MatchContext.PRE_MATCH_HINT, 23, C.MUTED, 500, 1065)
		var scroll := ScrollContainer.new()
		scroll.name = "Preparation" + str(pair[3]) + "Scroll"
		scroll.follow_focus = true
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		card.add_child(scroll)
		D.place(scroll, Rect2(17, 152, 1081, 679))
		var options := C.v(13)
		C.fill(options)
		scroll.add_child(options)
		scroll.get_v_scroll_bar().value_changed.connect(func(value: float):
			if focus_ready: state[pair[0]] = int(value))
		for option: Dictionary in tactics.get(pair[1], []):
			var tile := D.panel(options, Rect2(0, 0, 1063, 150))
			tile.custom_minimum_size.y = C.px(150)
			var selected: bool = option.id == tactics.get(pair[0])
			var select := _button(tile, Rect2(10, 10, 1040, 53), str(option.label).to_upper(), func():
				if not match_context.can_edit_tactics(): return
				var current: Dictionary = app.model.get("tactics", {})
				var payload := {"attack":current.get("attack", "equilibre"), "defense":current.get("defense", "equilibre")}
				payload[pair[0]] = option.id
				app._command("set_tactics", payload), selected, "check" if selected else "", "Preparation" + str(pair[3]) + "_" + str(option.id))
			select.set_meta("tactic_id", str(option.id))
			match_context.tactics.append(select)
			var lines := D.words(str(option.get("description", "")), 106, 2)
			for line in lines.size(): D.text(tile, 23, 97 + line * 27, lines[line], 23, C.IVORY, 500, 1015)
		if tactics.get(pair[1], []).is_empty(): options.add_child(C.wrap("Aucune consigne disponible.", 24, C.MUTED, true))
	var foot := D.panel(section, Rect2(0, 871, 2248, 95), "", "", "", "PreparationPlaybookNote")
	D.text(foot, 23, 40, "Adapter le plan aux zones du terrain", 30, C.IVORY, 700, 1220)
	D.text(foot, 23, 72, "Les consignes locales et les phases arrêtées se règlent dans le carnet de jeu.", 23, C.MUTED, 500, 1578)
	_button(foot, Rect2(1702, 20, 523, 55), "Consignes par zone et phases arrêtées", func(): app._navigate("Plan de jeu"), true, "arrow", "PreparationOpenZones")

func _section(id: String) -> Control:
	var section := Control.new()
	section.name = id
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(section)
	D.place(section, Rect2(0, 257, 2248, 966))
	return section

func _tactic_label(options: Array, id: Variant) -> String:
	for entry: Dictionary in options:
		if entry.get("id") == id: return str(entry.get("label", "—"))
	return "—"

func _opponent() -> Dictionary:
	var opponent: Dictionary = reports.get("opponent", {})
	if opponent.is_empty():
		for key in ["home", "away"]:
			var club: Dictionary = fixture.get(key, {})
			if not club.is_empty() and club.get("id") != app.model.club.get("id"): return club
		return {}
	for key in ["home", "away"]:
		var club: Dictionary = fixture.get(key, {})
		if club.get("id") == opponent.get("id"): return club
	return _club(opponent.get("id"))

func _club(id: Variant) -> Dictionary:
	for club: Dictionary in app.model.get("league", []):
		if club.get("id") == id: return club
	for club: Dictionary in app.model.get("meta", {}).get("catalogue", []):
		if club.get("id") == id: return club
	return {"name":reports.get("opponent", {}).get("name", "Club"), "abbr":"XV"}

func _crest(parent: Node, data: Dictionary, rectangle: Rect2) -> void:
	var crest := G.crest(data, C.px(rectangle.size.x))
	parent.add_child(crest)
	D.place(crest, rectangle)

func _button(parent: Node, rectangle: Rect2, caption: String, action: Callable, primary: bool, icon: String, id: String) -> Button:
	return D.button(parent, rectangle, caption, action, primary, icon, false, Color("09673e"), id)
