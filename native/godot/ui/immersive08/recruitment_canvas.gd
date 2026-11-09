extends Control
## Tableau des pistes, dossiers datés et décisions de recrutement de la carrière.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const G = preload("res://ui/game_skin.gd")
const U = preload("res://ui/management_state.gd")
const Decisions = preload("res://ui/decision_views.gd")
const CAPACITY := 10
const WIDTH := 2248
const LEFT := 1402
const RIGHT := 830
const WARM := Color("f0c568")
const GREEN := Color("6bed92")
const PRIMARY := Color("106d43")
const TABS := ["Besoins du club", "Recherche", "Joueurs suivis", "Rapports"]
const COLUMNS := [
	["JOUEUR", 128, 193, "Nom"], ["POSTE", 325, 155, "Poste"], ["ÂGE", 486, 55, "Âge"],
	["NIVEAU", 550, 74, "Niveau"], ["POTENTIEL", 636, 95, ""], ["PRIME", 741, 107, ""],
	["SALAIRE", 864, 165, "Salaire"], ["RAPPORT", 1043, 124, ""], ["AVIS", 1180, 207, ""]
]

var app: Control
var state: Dictionary
var data: Dictionary
var tab := 0
var report_by_player := {}
var max_salary := 0.0
var table_rows: Control
var dossier: Control
var count: Label
var page_label: Label
var prev: Button
var next: Button
var direction: Button

static func build(owner_app: Control, canvas: Control) -> void:
	var page: Control = load("res://ui/immersive08/recruitment_canvas.gd").new()
	page.app = owner_app
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, WIDTH, 1240))
	page._build()

func _build() -> void:
	name = "CarnetMarket"
	state = app.management_ui.market
	data = app.model.get("decisions", {}).get("recruitment", {})
	tab = clampi(int(state.get("immersive_tab", 2 if state.get("followed", false) else 0)), 0, TABS.size() - 1)
	if not str(state.get("navigation_id", "")).is_empty():
		tab = 1
		state.immersive_tab = 1
		state.followed = false
	for report: Dictionary in data.get("reports", []):
		var key := str(report.get("playerId", ""))
		if key.is_empty(): continue
		var previous: Dictionary = report_by_player.get(key, {})
		if int(report.get("week", -1)) >= int(previous.get("week", -1)):
			report_by_player[key] = report
	for player: Dictionary in app.model.get("market", []):
		max_salary = maxf(max_salary, float(player.get("salary", 0)))
	_header()
	_filters()
	_table()
	dossier = Control.new()
	dossier.name = "RecruitmentProfile"
	add_child(dossier)
	D.place(dossier, Rect2(LEFT + 16, 262, RIGHT, 823))
	_needs()
	_refresh()
	U.restore(app, self, "market")

func _header() -> void:
	D.text(self, 24, 43, "CONSTRUIRE L’EFFECTIF DE DEMAIN", 31, WARM, 700, 470)
	D.line(self, Vector2(490, 31), Vector2(568, 31), WARM)
	D.text(self, 20, 108, "Le prochain renfort.", 74, C.IVORY, 800, 900)
	var needs: Array = data.get("needs", [])
	var first: Dictionary = needs[0] if not needs.is_empty() else {}
	var metrics := [
		[798, 316, "people", "%d profils suivis" % app.management_ui.shortlist.size(), "", GREEN],
		[1130, 320, "save", "%d rapports conservés" % data.get("reports", []).size(), "", WARM],
		[1466, 366, "money", "Trésorerie du club", _money(app.model.get("finance", {}).get("cash")), WARM],
		[1848, 400, "star", "Priorité de recrutement" if first.get("need", false) else "Poste à surveiller", str(first.get("pos", "—")), WARM]
	]
	for item: Array in metrics:
		var x: int = item[0]
		var w: int = item[1]
		var card := D.rect(self, Rect2(x, 40, w, 73), Color("102820") if x < 1848 else Color("302719"), 9, Color("206848") if x < 1848 else Color("8c6b2e"))
		_icon(card, item[2], Rect2(24, 19, 37, 37), item[5])
		D.text(card, 77, 46 if item[4] == "" else 27, item[3], 30 if item[4] == "" else 22, C.IVORY, 600, w - 86)
		if item[4] != "": D.text(card, 77, 59, item[4], 31, C.IVORY, 700, w - 86)
	D.photo(self, "scouting", Rect2(0, 130, 634, 156))
	for i in TABS.size():
		_tab(Rect2(624 + 206 * i, 190, 216, 65), TABS[i], i)
	D.button(self, Rect2(1510, 181, 230, 61), "Comparer", _compare, false, "people", false, app.accent, "CompareMarket")
	D.button(self, Rect2(1758, 175, 490, 69), "Lancer une mission", func(): _staff(1), true, "arrow", false, PRIMARY, "OpenScoutMission")

func _tab(area: Rect2, caption: String, index: int) -> void:
	var id := "MarketFollowed" if index == 2 else "MarketTab" + str(index)
	var button := D.button(self, area, caption, func():
		state.immersive_tab = index
		state.navigation_id = ""
		state.followed = index == 2
		state.page = 0
		state.focus = "MarketSearch" if index == 1 else id
		app._render(false), tab == index, "", false, PRIMARY, id)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var selected := tab == index
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="432" height="130" viewBox="0 0 216 65"><defs><linearGradient id="g" x1="0" x2="0" y1="0" y2="1"><stop stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient></defs><path d="M1 64L14 10Q17 1 25 1H201Q212 1 213 10L202 64Z" fill="url(#g)" stroke="%s"/></svg>' % [
		"#155e3d" if selected else "#1a2627", "#0b3525" if selected else "#101819", "#6bbf8a" if selected else "#52605f"]
	var img := Image.new()
	img.load_svg_from_string(svg)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(img)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_font_size_override("font_size", maxi(12, C.px(27)))

func _filters() -> void:
	var panel := D.panel(self, Rect2(0, 286, LEFT, 62), "", "", "", "MarketFilters")
	_icon(panel, "search", Rect2(20, 19, 26, 26), WARM)
	D.text(panel, 58, 41, "FILTRES DE RECHERCHE", 26, C.IVORY, 700, 225)
	var search := LineEdit.new()
	search.name = "MarketSearch"
	search.placeholder_text = "Nom ou poste…"
	search.text = str(state.get("search", ""))
	search.clear_button_enabled = true
	search.accessibility_name = "Rechercher une piste par nom ou poste"
	search.add_theme_font_override("font", C.DISPLAY)
	search.add_theme_font_size_override("font_size", maxi(12, C.px(22)))
	search.add_theme_color_override("font_color", C.IVORY)
	search.add_theme_color_override("font_placeholder_color", C.MUTED)
	search.add_theme_stylebox_override("normal", C.box(Color("0d1617"), C.LINE, 5, 8))
	panel.add_child(search)
	D.place(search, Rect2(287, 11, 255, 40))
	search.text_changed.connect(func(value: String):
		state.search = value
		state.navigation_id = ""
		_filter_changed())
	var positions: Array = app.SquadViews._positions(app.model.get("market", []))
	_choice(panel, Rect2(552, 11, 229, 40), "MarketPosition", "Poste", positions, state.position, func(value: String): state.position = value; _filter_changed())
	_choice(panel, Rect2(791, 11, 146, 40), "MarketAge", "Âge", ["Tous", "≤ 22 ans", "23–28 ans", "≥ 29 ans"], state.get("age_filter", "Tous"), func(value: String): state.age_filter = value; _filter_changed())
	_choice(panel, Rect2(947, 11, 157, 40), "MarketAvailability", "Offres", ["Tous", "Disponibles"], state.available, func(value: String): state.available = value; _filter_changed())
	_choice(panel, Rect2(1114, 11, 147, 40), "MarketBudget", "Prime", ["Toutes", "≤ 100 k€", "≤ 400 k€", "≤ 1 M€"], state.get("budget_filter", "Toutes"), func(value: String): state.budget_filter = value; _filter_changed())
	var reset := D.button(panel, Rect2(1271, 11, 113, 40), "Réinitialiser", func():
		app.management_ui.market = U.defaults()
		app.management_ui.market.immersive_tab = tab
		app.management_ui.market.followed = tab == 2
		app._render(false), false, "", true, app.accent, "MarketReset")
	reset.tooltip_text = "Réinitialiser les filtres et le tri"
	reset.add_theme_font_size_override("font_size", maxi(12, C.px(19)))
	for variant in ["normal", "hover", "pressed", "focus"]:
		var style := reset.get_theme_stylebox(variant).duplicate() as StyleBox
		style.content_margin_left = C.px(6)
		style.content_margin_right = C.px(6)
		reset.add_theme_stylebox_override(variant, style)
	panel.visible = tab != 3
	var reports := D.panel(self, Rect2(0, 286, LEFT, 62), "", "", "", "RecruitmentReportsBar")
	_icon(reports, "save", Rect2(20, 16, 28, 28), WARM)
	D.text(reports, 61, 40, "RAPPORTS D’OBSERVATION CONSERVÉS", 27, C.IVORY, 700, 600)
	D.button(reports, Rect2(1110, 10, 274, 42), "Missions et échéances", func(): _staff(1), false, "calendar", true, app.accent, "OpenRecruitmentMissions")
	reports.visible = tab == 3

func _choice(parent: Node, area: Rect2, id: String, caption: String, values: Array, current: Variant, change: Callable) -> void:
	var field := OptionButton.new()
	field.name = id
	field.fit_to_longest_item = false
	field.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	field.accessibility_name = caption
	field.add_theme_font_override("font", C.DISPLAY)
	field.add_theme_font_size_override("font_size", maxi(12, C.px(21)))
	field.add_theme_color_override("font_color", C.IVORY)
	field.add_theme_stylebox_override("normal", C.box(Color("111b1c"), C.LINE, 5, 8))
	field.add_theme_stylebox_override("hover", C.box(Color("20372c"), C.MINT, 5, 8))
	field.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, WARM, 5, 8))
	for value in values: field.add_item(caption + " · " + str(value))
	field.select(maxi(0, values.find(current)))
	field.item_selected.connect(func(index: int): change.call(str(values[index])))
	parent.add_child(field)
	D.place(field, area)

func _table() -> void:
	var panel := D.panel(self, Rect2(0, 362, LEFT, 648), "", "", "", "ImmersiveMarketTable")
	var header := D.rect(panel, Rect2(1, 1, LEFT - 2, 44), Color("1a2627"), 6)
	var columns: Array = COLUMNS if tab != 3 else [["JOUEUR OBSERVÉ", 128, 370, ""], ["POSTE", 506, 252, ""], ["RAPPORT", 774, 333, ""], ["AVIS DATÉ", 1130, 245, ""]]
	for col: Array in columns:
		if col[3] == "":
			D.text(header, col[1], 28, col[0], 22, C.IVORY, 600, col[2])
			continue
		var sort := Button.new()
		sort.name = "MarketSort_" + str(col[3])
		sort.text = col[0] + " ↕"
		sort.flat = true
		sort.alignment = HORIZONTAL_ALIGNMENT_LEFT
		sort.clip_text = true
		sort.add_theme_font_override("font", C.DISPLAY)
		sort.add_theme_font_size_override("font_size", maxi(12, C.px(22)))
		sort.tooltip_text = "Trier par " + str(col[3]).to_lower()
		sort.pressed.connect(func():
			state.descending = not state.descending if state.sort == col[3] else col[3] == "Niveau"
			state.sort = col[3]
			_filter_changed())
		header.add_child(sort)
		D.place(sort, Rect2(col[1] - 4, 2, col[2], 40))
	table_rows = Control.new()
	table_rows.name = "ImmersiveMarketRows"
	panel.add_child(table_rows)
	D.place(table_rows, Rect2(1, 45, LEFT - 2, CAPACITY * 55))
	D.line(panel, Vector2(16, 595), Vector2(LEFT - 16, 595))
	count = D.text(panel, 17, 628, "", 21, C.MUTED, 500, 430)
	count.name = "MarketCount"
	direction = D.button(panel, Rect2(445, 603, 185, 36), "Tri", func():
		state.descending = not state.descending
		_filter_changed(), false, "", true, app.accent, "MarketDirection")
	direction.visible = tab != 3
	var pagination := Control.new()
	pagination.name = "MarketPagination"
	panel.add_child(pagination)
	D.place(pagination, Rect2(879, 603, 505, 36))
	prev = D.button(pagination, Rect2(0, 0, 160, 36), "← Précédent", func():
		state.page = int(state.page) - 1
		_refresh(), false, "", true, app.accent, "MarketPaginationPrevious")
	page_label = D.text(pagination, 240, 25, "", 22, C.MUTED, 600, 146, HORIZONTAL_ALIGNMENT_CENTER)
	page_label.name = "MarketPaginationInfo"
	next = D.button(pagination, Rect2(327, 0, 178, 36), "Suivant →", func():
		state.page = int(state.page) + 1
		_refresh(), false, "", true, app.accent, "MarketPaginationNext")

func _filter_changed() -> void:
	state.page = 0
	_refresh()

func _filtered() -> Array:
	if tab == 3:
		var archive: Array = data.get("reports", []).duplicate()
		archive.reverse()
		return archive
	var players := U.players(app.model.get("market", []), state, int(app.model.meta.get("season", 1)), true, app.management_ui.shortlist)
	var fee := float({"≤ 100 k€": 100000, "≤ 400 k€": 400000, "≤ 1 M€": 1000000}.get(state.get("budget_filter"), INF))
	var ages: Vector2 = {"≤ 22 ans": Vector2(0, 22), "23–28 ans": Vector2(23, 28), "≥ 29 ans": Vector2(29, INF)}.get(state.get("age_filter"), Vector2(0, INF))
	return players.filter(func(p: Dictionary):
		var age := float(p.get("age", -1))
		return age >= ages.x and age <= ages.y and float(p.get("fee", INF)) <= fee)

func _refresh() -> void:
	_clear(table_rows)
	var results := _filtered()
	var pages := maxi(1, ceili(float(results.size()) / CAPACITY))
	state.page = clampi(int(state.get("page", 0)), 0, pages - 1)
	var visible := results.slice(int(state.page) * CAPACITY, (int(state.page) + 1) * CAPACITY)
	var current := str(state.get("report_id" if tab == 3 else "player_id", ""))
	if not visible.is_empty() and not visible.any(func(p: Dictionary): return str(p.id) == current):
		current = str(visible[0].id)
	count.text = "%d rapports conservés" % results.size() if tab == 3 else "%d / %d pistes · %d suivies" % [results.size(), app.model.get("market", []).size(), app.management_ui.shortlist.size()]
	direction.text = "↓ Décroissant" if state.get("descending", false) else "↑ Croissant"
	page_label.text = "Page %d / %d" % [int(state.page) + 1, pages]
	prev.disabled = int(state.page) == 0
	next.disabled = int(state.page) >= pages - 1
	var selection: Dictionary = {}
	for i in visible.size():
		var item: Dictionary = visible[i]
		_row(item, i, str(item.id) == current)
		if str(item.id) == current: selection = item
	if results.is_empty():
		var caption := "Aucun rapport conservé. Confiez une mission pour observer des pistes." if tab == 3 else "Aucune piste ne correspond aux filtres actuels."
		D.text(table_rows, 24, 58, caption, 27, C.MUTED, 500, LEFT - 50)
	if tab == 3:
		_profile(_market_player(str(selection.get("playerId", ""))), selection)
	else:
		_profile(selection, report_by_player.get(str(selection.get("id", "")), {}))

func _row(item: Dictionary, index: int, selected: bool) -> void:
	var player := item if tab != 3 else _market_player(str(item.get("playerId", "")))
	var report: Dictionary = item if tab == 3 else report_by_player.get(str(item.id), {})
	var player_id := str(item.get("playerId", item.id))
	var row := Button.new()
	row.name = "MarketReport_" + str(item.id) if tab == 3 else "MarketPlayer_" + player_id.replace(":", "_")
	row.set_meta("player_id", player_id)
	row.accessibility_name = "%s, %s" % [item.get("name", "Joueur inconnu"), item.get("pos", "Poste inconnu")]
	row.add_theme_stylebox_override("normal", D.surface(LEFT - 2, 55, Color("155a39"), Color("10412d"), Color("258653"), 3, false) if selected else C.box(Color("121c1d") if index % 2 == 0 else Color("0d1517"), Color.TRANSPARENT, 0, 0))
	row.add_theme_stylebox_override("hover", C.box(Color("244638"), C.MINT, 3, 0))
	row.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, WARM, 3, 0))
	table_rows.add_child(row)
	D.place(row, Rect2(0, index * 55, LEFT - 2, 55))
	D.line(row, Vector2(0, 54), Vector2(LEFT - 2, 54), Color(C.LINE, .65))
	D.text(row, 25, 36, str(int(state.page) * CAPACITY + index + 1), 27, C.IVORY, 700, 38, HORIZONTAL_ALIGNMENT_CENTER)
	_portrait(row, Rect2(58, 4, 49, 47), player, player_id)
	D.text(row, 128, 24, item.get("name", "—"), 24, C.IVORY, 700, 190 if tab != 3 else 359)
	D.text(row, 128, 46, "★ Suivi" if player_id in app.management_ui.shortlist else "Marché des joueurs" if tab != 3 else "Dossier d’observation", 18, WARM if player_id in app.management_ui.shortlist else C.MUTED, 500, 190)
	var assessment: Dictionary = report.get("assessment", {})
	if tab == 3:
		D.text(row, 506, 35, item.get("pos", "—"), 24, C.IVORY, 500, 250)
		D.text(row, 774, 35, assessment.get("source", "Date non conservée"), 23, C.MUTED, 500, 345)
		_badge(row, Rect2(1130, 11, 242, 34), _report_label(report), _report_color(report))
	else:
		D.text(row, 325, 35, item.get("pos", "—"), 22, C.IVORY, 500, 155)
		D.text(row, 510, 36, G.n(item.get("age", "—")), 25, C.IVORY, 600, 52, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(row, 582, 37, G.n(item.get("rating", "—")), 32, GREEN, 700, 65, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(row, 675, 37, G.n(report.get("potential", "—")), 30, GREEN if report.has("potential") else C.FAINT, 700, 80, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(row, 742, 36, _money(item.get("fee")), 24, C.IVORY, 600, 111)
		D.text(row, 864, 29, _money(item.get("salary")) + "/sem.", 23, C.IVORY, 500, 174)
		if max_salary > 0 and (item.get("salary") is float or item.get("salary") is int):
			D.bar(row, Rect2(864, 36, 163, 10), 100.0 * float(item.salary) / max_salary, GREEN)
		D.text(row, 1043, 35, "Ancien" if assessment.get("stale", false) else "Daté" if not report.is_empty() else "—", 23, C.MUTED, 500, 112)
		var status := _report_label(report) if item.get("available", false) else "Offre indisponible"
		_badge(row, Rect2(1179, 11, 205, 34), status, _report_color(report) if item.get("available", false) else C.ALERT)
	row.pressed.connect(func():
		state["report_id" if tab == 3 else "player_id"] = str(item.id)
		var target := str(row.name)
		_refresh()
		var focused := table_rows.get_node_or_null(target) as Button
		if focused != null: focused.grab_focus.call_deferred())

func _profile(player: Dictionary, report: Dictionary) -> void:
	_clear(dossier)
	var panel := D.panel(dossier, Rect2(0, 0, RIGHT, 823), "", "", "", "RecruitmentProfilePanel")
	var info: Dictionary = report.get("assessment", {})
	var person := player if tab != 3 else report
	var player_id := str(player.get("id", ""))
	dossier.set_meta("player_id", str(person.get("playerId", player_id)))
	if person.is_empty():
		D.photo(panel, "recruit-profile", Rect2(16, 18, 333, 260))
		D.text(panel, 378, 68, "DOSSIER DE RECRUTEMENT", 37, C.IVORY, 800, 435)
		D.text(panel, 378, 110, "Aucune piste sélectionnée", 29, C.MUTED, 500, 435)
		D.button(panel, Rect2(376, 134, 434, 58), "Besoins, missions et rapports", func(): _staff(0), true, "arrow", false, PRIMARY, "OpenEmptyRecruitmentNeeds")
		_section(panel, Rect2(16, 306, 798, 240), "TRAVAIL DU STAFF", "people")
		D.text(panel, 40, 390, "%d / %d professionnels · %d place(s)" % [data.get("occupied", app.model.get("squad", []).size()), data.get("capacity", 0), data.get("places", 0)], 27, C.IVORY, 600, 740)
		D.text(panel, 40, 429, "%d contrat(s) à échéance cette saison" % data.get("expiring", []).size(), 25, C.MUTED, 500, 740)
		D.text(panel, 40, 467, "%d rapport(s) conservé(s) · %d mission(s)" % [data.get("reports", []).size(), data.get("missions", []).size()], 25, C.MUTED, 500, 740)
		return
	_portrait(panel, Rect2(16, 12, 345, 240), player, str(person.get("playerId", player_id)), true)
	D.text(panel, 370, 57, str(person.get("name", "—")).to_upper(), 46, C.IVORY, 800, 440)
	D.text(panel, 374, 89, person.get("pos", "—"), 27, C.IVORY, 600, 430)
	D.rect(panel, Rect2(374, 104, 211, 84), Color("0d4e31"), 9)
	D.text(panel, 479, 172, G.n(person.get("note" if tab == 3 else "rating", "—")), 75, C.IVORY, 800, 197, HORIZONTAL_ALIGNMENT_CENTER)
	D.line(panel, Vector2(599, 111), Vector2(599, 186), C.LINE)
	D.text(panel, 707, 149, G.n(report.get("potential", "—")), 53, C.IVORY, 800, 198, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(panel, 707, 177, "Potentiel estimé", 25, C.MUTED, 600, 198, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(panel, 375, 222, G.n(person.get("age", "—")) + " ans" + (" lors du rapport" if tab == 3 else ""), 28, C.IVORY, 600, 174)
	var can_track: bool = not player.is_empty() and not app.waiting and app._live().is_empty() and app.model.meta.get("phase", "") != "ended"
	var context: Variant = app.model.get("clubLife", {}).get("managerCareer", {}).get("context")
	var track := D.button(panel, Rect2(555, 195, 253, 41), "Retirer du suivi" if player_id in app.management_ui.shortlist else "Suivre cette piste", func():
		app._command("manager_recruitment_watch", {"context": context.duplicate(true), "playerId": player_id}), false, "star", true, app.accent, "Follow" + player_id.replace(":", "_"))
	track.set_meta("follow_id", player_id)
	track.disabled = not can_track or not context is Dictionary
	var source := D.rect(panel, Rect2(16, 255, 490, 43), Color("152224"), 7, C.LINE)
	_icon(source, "people", Rect2(16, 10, 23, 23), C.IVORY)
	D.text(source, 52, 29, info.get("source", "Aucune observation enregistrée"), 24, C.IVORY, 600, 426)
	var scouting := D.rect(panel, Rect2(520, 255, 294, 43), Color("152224"), 7, C.LINE)
	_icon(scouting, "search", Rect2(15, 10, 23, 23), C.IVORY)
	D.text(scouting, 51, 29, "Agent libre" if report.is_empty() else _report_label(report), 24, C.IVORY, 600, 230)
	_observation(panel, player, report)
	_deal(panel, player, report)
	D.button(panel, Rect2(16, 763, 407, 45), "Demander une observation" if report.is_empty() else "Lire le rapport complet", func():
		if report.is_empty(): _staff(1, str(player.get("pos", "")))
		else: _report_dialog(report), false, "save", true, app.accent, "OpenScoutReport")
	var offer := D.button(panel, Rect2(437, 763, 377, 45), "Approcher le joueur", func(): app.SquadViews.contract(app, player, true), true, "arrow", false, PRIMARY, "OfferRecruitment")
	offer.set_meta("player_id", player_id)
	offer.disabled = player.is_empty() or app.waiting or not player.get("available", false) or not app._live().is_empty()
	offer.tooltip_text = str(player.get("reason", "")) if not player.is_empty() else "Le dossier est conservé dans les archives."

func _observation(parent: Panel, player: Dictionary, report: Dictionary) -> void:
	var info: Dictionary = report.get("assessment", {})
	var observed := _section(parent, Rect2(16, 305, 286, 137), "FAITS RELEVÉS", "check")
	var facts: Array = info.get("observed", [])
	if facts.is_empty():
		facts = ["Âge : " + G.n(player.get("age", "—")) + " ans", "Niveau du marché : " + G.n(player.get("rating", "—")), "Sans rapport daté"]
	for i in mini(facts.size(), 3):
		D.text(observed, 15, 65 + 27 * i, facts[i], 22, C.IVORY, 500, 255)
	var vigilance := _section(parent, Rect2(310, 305, 291, 137), "VIGILANCE", "warning")
	var warning := str(player.get("reason", ""))
	if warning.is_empty(): warning = str(info.get("caution", "Les qualités techniques restent à observer."))
	var warning_lines := D.words(warning, 29, 3)
	for i in warning_lines.size():
		D.text(vigilance, 16, 65 + 25 * i, warning_lines[i], 22, C.IVORY, 500, 259)
	var trust := _section(parent, Rect2(610, 305, 204, 137), "APPRÉCIATION", "star")
	D.text(trust, 102, 107, report.get("grade", "—"), 65, _report_color(report), 800, 179, HORIZONTAL_ALIGNMENT_CENTER)
	var compare := _section(parent, Rect2(16, 452, 798, 162), "COMPARAISON AU MÊME POSTE", "people")
	var role := str(player.get("pos", report.get("pos", "")))
	var squad: Array = app.model.get("squad", []).filter(func(p: Dictionary): return str(p.get("pos", "")) == role)
	var average := 0.0
	for teammate: Dictionary in squad: average += float(teammate.get("rating", 0))
	var values: Array = [player.get("rating"), roundi(average / squad.size()) if not squad.is_empty() else null, report.get("potential")]
	for i in values.size():
		var y := 59 + i * 36
		D.text(compare, 25, y + 12, ["Niveau de la piste", "Moyenne de l’effectif", "Potentiel observé"][i], 24, C.IVORY, 500, 272)
		D.bar(compare, Rect2(312, y - 2, 400, 12), float(values[i]) if values[i] is float or values[i] is int else 0.0, GREEN if i != 1 else C.MUTED)
		D.text(compare, 771, y + 12, G.n(values[i]) if values[i] != null else "—", 27, GREEN if i != 1 else C.MUTED, 700, 54, HORIZONTAL_ALIGNMENT_RIGHT)

func _deal(parent: Panel, player: Dictionary, report: Dictionary) -> void:
	var section := _section(parent, Rect2(16, 624, 798, 125), "SYNTHÈSE DU CONTRAT", "money")
	var quote := player if not player.is_empty() else report
	var max_years := int(player.get("maxYears", 0))
	var values := [_money(quote.get("fee", quote.get("price"))), _money(quote.get("salary")) + "/sem.", "%s à %s ans" % [G.n(player.get("minYears", 1)), G.n(max_years)] if max_years > 1 else "1 an" if max_years == 1 else "—"]
	for i in values.size():
		var x := 14 + i * 260
		if i > 0: D.line(section, Vector2(x, 55), Vector2(x, 112), C.LINE)
		_icon(section, ["money", "calendar", "save"][i], Rect2(x + 16, 69, 34, 34), WARM)
		D.text(section, x + 66, 70, ["Prime d’acquisition", "Salaire demandé", "Durée proposée"][i], 22, C.MUTED, 500, 184)
		D.text(section, x + 66, 103, values[i], 31, C.IVORY, 700, 186)

func _needs() -> void:
	var title := _section(self, Rect2(0, 1025, LEFT, 50), "BESOINS DE RECRUTEMENT · PLAN DE RELÈVE", "flag")
	var open := D.button(title, Rect2(1120, 7, 268, 35), "Besoins et missions", func(): _staff(0), false, "arrow", true, app.accent, "OpenRecruitmentNeeds")
	open.tooltip_text = "Effectif professionnel, postes à anticiper, missions et rapports"
	var needs: Array = []
	var seen: Array = []
	for need: Dictionary in data.get("needs", []):
		var position: Variant = need.get("pos")
		if position in seen: continue
		seen.append(position)
		needs.append(need)
		if needs.size() == 3: break
	if needs.is_empty():
		D.text(self, 23, 1151, "Les besoins de l’effectif ne sont pas renseignés.", 28, C.MUTED, 500, WIDTH - 46)
		return
	for i in mini(3, needs.size()):
		var need: Dictionary = needs[i]
		var role := str(need.get("pos", "Poste inconnu"))
		var tint: Color = [C.ALERT, WARM, GREEN][i]
		var card := D.button(self, Rect2(i * 755, 1095, 738, 126), "", func():
			Decisions.open_market_position(app, role), false, "", false, app.accent, "MarketNeed_" + str(i))
		card.add_theme_stylebox_override("normal", D.surface(738, 126, Color("372326") if i == 0 else Color("2e281c") if i == 1 else Color("112c22"), Color("141a1b"), tint, 10, false))
		_icon(card, ["people", "shield", "flag"][i], Rect2(26, 27, 55, 55), tint)
		D.text(card, 109, 40, role.to_upper(), 36, C.IVORY, 800, 430)
		var reasons: Array = need.get("reasons", [])
		D.text(card, 109, 77, str(reasons[0]) if not reasons.is_empty() else "Couverture du poste à examiner", 24, C.MUTED, 500, 595)
		_badge(card, Rect2(570, 15, 144, 38), ("Priorité %d" if need.get("need", false) else "Veille %d") % (i + 1), tint)
		var tracked: int = app.model.get("market", []).filter(func(p: Dictionary): return p.get("pos") == role and str(p.id) in app.management_ui.shortlist).size()
		D.text(card, 715, 109, "%d profil(s) suivi(s)  ›" % tracked, 24, C.IVORY, 600, 296, HORIZONTAL_ALIGNMENT_RIGHT)

func _staff(index: int, role: String = "") -> void:
	Decisions.recruitment(app)
	var dialog := app.get_child(app.get_child_count() - 1) as AcceptDialog
	if dialog == null: return
	dialog.set_meta("immersive_dialog_size", Vector2i(900, 580))
	var tabs := dialog.find_child("ScoutTabs", true, false) as TabContainer
	if tabs == null: return
	tabs.current_tab = index
	var families := [["Pilier"], ["Talonneur"], ["Deuxième"], ["Troisième", "Flanker", "Numéro 8"], ["Demi de mêlée"], ["Ouvreur", "Ouverture", "Demi d’ouverture"], ["Ailier"], ["Centre"], ["Arrière"]]
	var field := dialog.find_child("ScoutFamily", true, false) as OptionButton
	if field == null or role.is_empty(): return
	for i in families.size():
		for prefix: String in families[i]:
			if role.begins_with(prefix): field.select(i); return

func _report_dialog(report: Dictionary) -> void:
	var view := Decisions.dialog(app, "Rapport d’observation", "RecruitmentReport", 920)
	Decisions.scout_report(view[1], report)
	Dialogs.show_centered(view[0], Vector2i(920, 565))

func _compare() -> void:
	var players: Array = app.model.get("market", [])
	var view := Decisions.dialog(app, "Comparer deux pistes", "MarketComparison", 1020)
	var content: VBoxContainer = view[1]
	content.add_child(C.wrap("Valeurs du marché au jour de la consultation. Le potentiel provient d’un rapport daté lorsqu’il existe.", 20, C.MUTED))
	var choices := C.h(14)
	content.add_child(choices)
	var picks: Array[OptionButton] = []
	var chosen := str(dossier.get_meta("player_id", ""))
	for slot in 2:
		var picker := OptionButton.new()
		picker.name = "MarketComparisonPlayer" + str(slot)
		picker.fit_to_longest_item = false
		picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		C.fill(picker)
		choices.add_child(picker)
		picker.add_item("Choisir une piste")
		for player: Dictionary in players:
			picker.add_item(str(player.name) + " · " + str(player.pos))
			if slot == 0 and str(player.id) == chosen: picker.select(picker.item_count - 1)
		picks.append(picker)
	var facts := C.v(9)
	content.add_child(facts)
	var update := func(_index: int): _comparison_rows(facts, picks, players)
	for picker in picks: picker.item_selected.connect(update)
	update.call(0)
	Dialogs.show_centered(view[0], Vector2i(1020, 620))

func _comparison_rows(parent: VBoxContainer, picks: Array[OptionButton], players: Array) -> void:
	_clear(parent)
	if picks[0].selected > 0 and picks[0].selected == picks[1].selected:
		parent.add_child(C.wrap("Sélectionnez deux pistes distinctes.", 23, C.ALERT))
		return
	var columns := GridContainer.new()
	columns.columns = 3
	columns.add_theme_constant_override("h_separation", C.px(30))
	columns.add_theme_constant_override("v_separation", C.px(9))
	parent.add_child(columns)
	for pair: Array in [["Joueur", "name"], ["Poste", "pos"], ["Âge", "age"], ["Niveau de jeu / 100", "rating"], ["Potentiel estimé / 100", "potential"], ["Source du potentiel", "source"], ["Prime", "fee"], ["Salaire / semaine", "salary"]]:
		columns.add_child(C.label(pair[0], 22, C.MUTED))
		for picker in picks:
			var player: Dictionary = players[picker.selected - 1] if picker.selected > 0 else {}
			var report: Dictionary = report_by_player.get(str(player.get("id", "")), {})
			var value: Variant = player.get(pair[1], "—")
			match pair[1]:
				"potential": value = report.get("potential", "—")
				"source": value = report.get("assessment", {}).get("source", "—")
				"fee", "salary": value = _money(player.get(pair[1]))
			var label := C.wrap(value, 22, C.IVORY, true)
			label.custom_minimum_size.x = C.px(240)
			columns.add_child(label)

func _market_player(player_id: String) -> Dictionary:
	for person: Dictionary in app.model.get("market", []):
		if str(person.id) == player_id: return person
	return {}

static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

static func _icon(parent: Node, id: String, area: Rect2, tint: Color) -> void:
	var icon := C.icon(id, int(area.size.x), tint)
	parent.add_child(icon)
	D.place(icon, area)

static func _section(parent: Node, area: Rect2, title: String, icon_id: String) -> Panel:
	var frame := D.panel(parent, area)
	_icon(frame, icon_id, Rect2(15, 11, 23, 23), WARM)
	D.text(frame, 49, 32, title, 25, C.IVORY, 700, area.size.x - 59)
	D.line(frame, Vector2(12, 42), Vector2(area.size.x - 12, 42), Color(C.LINE, .65))
	return frame

static func _badge(parent: Node, area: Rect2, caption: String, tint: Color) -> void:
	var filled := tint in [GREEN, C.ALERT]
	var frame := D.rect(parent, area, tint if filled else tint.darkened(.76), 6, tint)
	D.text(frame, area.size.x / 2, area.size.y / 2 + 7, caption, 22, Color("091a11") if filled else tint, 700, area.size.x - 10, HORIZONTAL_ALIGNMENT_CENTER)

static func _portrait(parent: Node, area: Rect2, player: Dictionary, player_id: String, full: bool = false) -> void:
	if str(player.get("portraitPath", "")).is_empty():
		D.photo(parent, "recruit-profile" if full else "player-%02d" % posmod(player_id.hash(), 16), area)
		return
	var photo := G.portrait(0, C.px(minf(area.size.x, area.size.y)), player)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(photo)
	D.place(photo, area)

static func _report_label(report: Dictionary) -> String:
	return "Rapport ancien" if report.get("assessment", {}).get("stale", false) else "Avis " + str(report.grade) if report.has("grade") else "À observer"

static func _report_color(report: Dictionary) -> Color:
	if report.get("assessment", {}).get("stale", false): return WARM
	return {"A": GREEN, "B": C.BLUE, "C": WARM}.get(report.get("grade", ""), C.BLUE)

static func _money(value: Variant) -> String:
	return G.euros(value) if value is int or value is float else "—"
