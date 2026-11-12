extends Control
## Tableau des pistes, dossiers datés et décisions de recrutement de la carrière.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const G = preload("res://ui/game_skin.gd")
const U = preload("res://ui/management_state.gd")
const Decisions = preload("res://ui/decision_views.gd")
const Link = preload("res://ui/entity_link.gd")
const Sort = preload("res://ui/recruitment_sort.gd")
const ROW_HEIGHT := 38
const WIDTH := 2248
const LEFT := 1402
const RIGHT := 830
const WARM := Color("f0c568")
const GREEN := Color("6bed92")
const PRIMARY := Color("106d43")
const TABS := ["Besoins du club", "Recherche", "Joueurs suivis", "Rapports"]
const COLUMNS := [
	["JOUEUR", 128, 193, "Nom"], ["POSTE", 325, 155, "Poste"], ["ÂGE", 486, 55, "Âge"],
	["NIVEAU", 550, 74, "Niveau"], ["POTENTIEL", 636, 95, "Potentiel"], ["PRIME", 741, 107, "Prime"],
	["SALAIRE", 864, 165, "Salaire"], ["RAPPORT", 1043, 124, "Rapport"], ["OBSERVATION", 1180, 207, "Avis"]
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
var table_scroll: ScrollContainer
var direction: Button
var position_filter: OptionButton
var sort_headers: Dictionary = {}

static func _target_report(owner_app: Control, id: Variant) -> Dictionary:
	if str(id).is_empty(): return {}
	var found: Dictionary = {}
	for report: Dictionary in owner_app.model.get("decisions", {}).get("recruitment", {}).get("reports", []):
		if str(report.get("id", "")) != str(id): continue
		if not found.is_empty(): return {}
		found = report
	return found

static func target_available(owner_app: Control, id: Variant) -> bool:
	return not _target_report(owner_app, id).is_empty()

static func open_target(owner_app: Control, id: Variant) -> bool:
	var report := _target_report(owner_app, id)
	if report.is_empty(): return false
	var existing := owner_app.find_child("RecruitmentReport", false, false) as Window
	if existing != null and not existing.is_queued_for_deletion() and existing.visible: return false
	var view := Decisions.dialog(owner_app, "Rapport d’observation", "RecruitmentReport", 920)
	view[0].set_meta("navigation_read_only", true)
	view[0].set_meta("entity_kind", "report")
	view[0].set_meta("entity_id", str(report.id))
	# This archived report remains readable even when the player has left the
	# current market. Link to a current dossier only if that projection exists.
	var player_id := str(report.get("playerId", ""))
	var current: Array = owner_app.model.get("market", []).filter(func(player: Dictionary): return str(player.get("id", "")) == player_id)
	if not player_id.is_empty() and current.size() == 1:
		var link := Link.button(owner_app, "Dossier actuel · " + str(current[0].get("name", "")), {"kind":"market", "id":player_id}, "ReportCurrentPlayer", view[0])
		link.clip_text = true
		view[1].add_child(link)
	Decisions.scout_report(view[1], report)
	Dialogs.show_centered(view[0], Vector2i(920, 565))
	return true

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
	var positions: Array = app.SquadViews._positions(app.model.get("market", []))
	_header(positions)
	_filters(positions)
	_table()
	dossier = Control.new()
	dossier.name = "RecruitmentProfile"
	add_child(dossier)
	D.place(dossier, Rect2(LEFT + 16, 262, RIGHT, 823))
	_needs()
	_refresh()
	U.restore(app, self, "market")

func _header(positions: Array) -> void:
	D.text(self, 24, 43, "CONSTRUIRE L’EFFECTIF DE DEMAIN", 31, WARM, 700, 470)
	D.line(self, Vector2(490, 31), Vector2(568, 31), WARM)
	D.text(self, 20, 108, "Le prochain renfort.", 74, C.IVORY, 800, 900)
	var metrics := [
		[798, 316, "people", "%d profils suivis" % app.management_ui.shortlist.size(), "", GREEN],
		[1130, 320, "save", "%d rapports conservés" % data.get("reports", []).size(), "", WARM],
		[1466, 366, "money", "Trésorerie du club", _money(app.model.get("finance", {}).get("cash")), WARM],
	]
	for item: Array in metrics:
		var x: int = item[0]
		var w: int = item[1]
		var card := D.rect(self, Rect2(x, 40, w, 73), Color("102820"), 9, Color("206848"))
		_icon(card, item[2], Rect2(24, 19, 37, 37), item[5])
		D.text(card, 77, 46 if item[4] == "" else 27, item[3], 30 if item[4] == "" else 22, C.IVORY, 600, w - 86)
		if item[4] != "": D.text(card, 77, 59, item[4], 31, C.IVORY, 700, w - 86)
	_watch(positions)
	D.photo(self, "scouting", Rect2(0, 130, 634, 156))
	var fade := Control.new()
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	D.place(fade, Rect2(506, 130, 128, 156))
	C.veil(fade).flip_h = true
	D.button(self, Rect2(24, 223, 270, 48), "Repérer la relève →", func(): preload("res://ui/regen_scouting_view.gd").open(app), false, "", false, PRIMARY, "OpenRegenScouting")
	D.button(self, Rect2(310, 223, 272, 48), "Marché entre clubs →", func(): preload("res://ui/interclub_market_view.gd").open(app), false, "", false, PRIMARY, "OpenInterclubMarket")
	for i in TABS.size():
		_tab(Rect2(624 + 206 * i, 190, 216, 65), TABS[i], i)
	var compare := D.button(self, Rect2(1510, 181, 230, 61), "Comparer", _compare, false, "people", false, app.accent, "CompareMarket")
	compare.tooltip_text = "Comparer deux pistes de recrutement"
	compare.accessibility_name = compare.tooltip_text
	D.button(self, Rect2(1758, 175, 490, 69), "Lancer une mission", func(): _staff(1), true, "arrow", false, PRIMARY, "OpenScoutMission")

func _watch(positions: Array) -> void:
	var watch := Decisions.market_watch(app)
	if watch.is_empty(): return
	var index := positions.find(watch.position)
	var can_filter := index > 0 and tab != 3
	var area := Rect2(1848, 40, 400, 121 if can_filter else 98)
	var panel: Control
	if can_filter:
		var action := D.button(self, area, "", func(): Decisions.select_market_position(position_filter, index), false, "", false, app.accent, "MarketPriorityFilter")
		action.add_theme_stylebox_override("normal", D.surface(400, 121, Color("302719"), Color("211b15"), Color("8c6b2e")))
		action.accessibility_name = "Filtrer sur ce poste · " + watch.position
		panel = action
	else:
		panel = D.rect(self, area, Color("302719"), 9, Color("8c6b2e"))
	_icon(panel, "star", Rect2(24, 19, 37, 37), WARM)
	D.text(panel, 77, 26, watch.heading, 21, C.IVORY, 600, 309)
	D.text(panel, 77, 53, watch.position, 29, C.IVORY, 700, 309)
	D.text(panel, 77, 80, watch.caption, 20, C.MUTED, 600, 309).name = "MarketPriorityStock"
	if can_filter:
		D.text(panel, 77, 107, "Filtrer sur ce poste  →", 21, WARM, 700, 309)

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

func _filters(positions: Array) -> void:
	var panel := D.panel(self, Rect2(0, 286, LEFT, 62), "", "", "", "MarketFilters")
	_icon(panel, "search", Rect2(20, 19, 26, 26), WARM)
	D.text(panel, 58, 41, "FILTRES DE RECHERCHE", 26, C.IVORY, 700, 225)
	var search := LineEdit.new()
	search.name = "MarketSearch"
	search.placeholder_text = "Nom, poste, mots-clés…"
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
	position_filter = _choice(panel, Rect2(552, 11, 229, 40), "MarketPosition", "Poste", positions, state.position, func(value: String): state.position = value; _filter_changed())
	_choice(panel, Rect2(791, 11, 146, 40), "MarketAge", "Âge", ["Tous", "≤ 22 ans", "23–28 ans", "≥ 29 ans"], state.get("age_filter", "Tous"), func(value: String): state.age_filter = value; _filter_changed())
	_choice(panel, Rect2(947, 11, 157, 40), "MarketAvailability", "Offres", ["Tous", "Disponibles", "Indisponibles"], state.available, func(value: String): state.available = value; _filter_changed())
	_choice(panel, Rect2(1114, 11, 147, 40), "MarketBudget", "Prime", ["Toutes", "≤ 100 k€", "≤ 400 k€", "≤ 1 M€"], state.get("budget_filter", "Toutes"), func(value: String): state.budget_filter = value; _filter_changed())
	var reset := D.button(panel, Rect2(1271, 11, 113, 40), "Réinitialiser", func():
		app.management_ui.market = U.defaults()
		app.management_ui.market.immersive_tab = tab
		app.management_ui.market.followed = tab == 2
		app.management_ui.market.focus = "MarketReset"
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

func _choice(parent: Node, area: Rect2, id: String, caption: String, values: Array, current: Variant, change: Callable) -> OptionButton:
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
	return field

func _table() -> void:
	var panel := D.panel(self, Rect2(0, 362, LEFT, 648), "", "", "", "ImmersiveMarketTable")
	var header := D.rect(panel, Rect2(1, 1, LEFT - 2, 44), Color("1a2627"), 6)
	var columns: Array = COLUMNS if tab != 3 else [["JOUEUR OBSERVÉ", 128, 370, "Nom"], ["POSTE", 506, 252, "Poste"], ["RAPPORT", 774, 333, "Date du rapport"], ["OBSERVATION", 1130, 245, "Avis"]]
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
		sort.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,0))
		sort.add_theme_stylebox_override("hover", C.box(C.RAISED,C.MINT,4,0))
		sort.add_theme_stylebox_override("pressed", C.box(C.PANEL,C.MINT,4,0))
		sort.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT,WARM,4,0))
		sort.tooltip_text = "Trier par " + ("observation" if col[3]=="Avis" else str(col[3]).to_lower())
		sort.set_meta("sort_caption",str(col[0]))
		sort_headers[str(col[3])] = sort
		sort.pressed.connect(func():
			var same: bool = _sort_column() == col[3]
			state["report_descending" if tab == 3 else "descending"] = not _sort_descending() if same else col[3] in ["Niveau","Potentiel","Date du rapport"]
			state["report_sort" if tab == 3 else "sort"] = col[3]
			_filter_changed())
		header.add_child(sort)
		D.place(sort, Rect2(col[1] - 4, 2, col[2], 40))
	table_scroll = ScrollContainer.new()
	table_scroll.name = "MarketScroll"
	table_scroll.follow_focus = true
	table_scroll.mouse_force_pass_scroll_events = false
	table_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(table_scroll)
	D.place(table_scroll,Rect2(1,45,LEFT-2,550))
	table_scroll.get_v_scroll_bar().value_changed.connect(func(value: float): state.scroll = int(value))
	table_rows = Control.new()
	table_rows.name = "ImmersiveMarketRows"
	table_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_scroll.add_child(table_rows)
	D.line(panel, Vector2(16, 595), Vector2(LEFT - 16, 595))
	count = D.text(panel, 17, 628, "", 21, C.MUTED, 500, 430)
	count.name = "MarketCount"
	direction = D.button(panel, Rect2(445, 603, 185, 36), "Tri", func():
		state["report_descending" if tab == 3 else "descending"] = not _sort_descending()
		_filter_changed(), false, "", true, app.accent, "MarketDirection")
	D.text(panel,878,628,"Liste complète · défilement à la molette",18,C.MUTED,500,505).name = "MarketScrollHint"

func _filter_changed() -> void:
	state.page = 0
	state.scroll = 0
	if table_scroll != null: table_scroll.scroll_vertical = 0
	_refresh()

func _filtered() -> Array:
	if tab == 3:
		var archive: Array = data.get("reports", []).duplicate()
		return Sort.sorted(archive,_sort_column(),_sort_descending(),report_by_player,true)
	var query_state := state.duplicate()
	query_state.search = ""
	var players := U.players(app.model.get("market", []), query_state, int(app.model.meta.get("season", 1)), true, app.management_ui.shortlist, false)
	var terms: PackedStringArray = []
	if str(state.get("navigation_id", "")).is_empty():
		terms = U.fold(str(state.get("search", ""))).split(" ", false)
	var fee := float({"≤ 100 k€": 100000, "≤ 400 k€": 400000, "≤ 1 M€": 1000000}.get(state.get("budget_filter"), INF))
	var ages: Vector2 = {"≤ 22 ans": Vector2(0, 22), "23–28 ans": Vector2(23, 28), "≥ 29 ans": Vector2(29, INF)}.get(state.get("age_filter"), Vector2(0, INF))
	var filtered := players.filter(func(p: Dictionary):
		var raw_age: Variant = p.get("age")
		var age_known: bool = (raw_age is int or raw_age is float) and is_finite(float(raw_age))
		var raw_fee: Variant = p.get("fee")
		var fee_known: bool = (raw_fee is int or raw_fee is float) and is_finite(float(raw_fee))
		var searchable := U.fold(str(p.get("name", "")) + " " + str(p.get("pos", "")))
		for term in terms:
			if not searchable.contains(term): return false
		if state.available == "Indisponibles" and p.get("available", false): return false
		if state.get("age_filter","Tous") != "Tous" and (not age_known or float(raw_age) < ages.x or float(raw_age) > ages.y): return false
		if state.get("budget_filter","Toutes") != "Toutes" and (not fee_known or float(raw_fee) > fee): return false
		return true)
	return Sort.sorted(filtered,_sort_column(),_sort_descending(),report_by_player)

func _sort_column() -> String:
	return str(state.get("report_sort","Date du rapport")) if tab == 3 else str(state.get("sort","Poste"))

func _sort_descending() -> bool:
	return bool(state.get("report_descending",true)) if tab == 3 else bool(state.get("descending",false))

func _sort_arrows() -> void:
	for column: String in sort_headers:
		var button: Button = sort_headers[column]
		var active := column == _sort_column()
		button.text = str(button.get_meta("sort_caption")) + (" ↓" if _sort_descending() else " ↑") if active else str(button.get_meta("sort_caption")) + " ↕"
		button.tooltip_text = "Trier par %s · %s · valeurs inconnues en dernier" % [column.to_lower(),"croissant au prochain clic" if active and _sort_descending() else "décroissant au prochain clic" if active else "activer le tri"]
		button.accessibility_name = button.text + " · " + button.tooltip_text
		var pixels := C.px(18)
		while pixels > C.px(13) and C.DISPLAY.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x > button.size.x-C.px(4): pixels -= 1
		button.add_theme_font_size_override("font_size",pixels)

func _refresh() -> void:
	var scroll := table_scroll.scroll_vertical
	_clear(table_rows)
	var results := _filtered()
	state.page = 0
	var visible := results
	table_rows.custom_minimum_size = Vector2(0,C.px(maxi(80,results.size()*ROW_HEIGHT)))
	var current := str(state.get("report_id" if tab == 3 else "player_id", ""))
	if not visible.is_empty() and not visible.any(func(p: Dictionary): return str(p.id) == current):
		current = str(visible[0].id)
	count.text = "%d rapports conservés" % results.size() if tab == 3 else "%d / %d pistes · %d suivies" % [results.size(), app.model.get("market", []).size(), app.management_ui.shortlist.size()]
	direction.text = "↓ Décroissant" if _sort_descending() else "↑ Croissant"
	_sort_arrows()
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
	table_scroll.set_deferred("scroll_vertical",scroll)

func _row(item: Dictionary, index: int, selected: bool) -> void:
	var player := item if tab != 3 else _market_player(str(item.get("playerId", "")))
	var report: Dictionary = item if tab == 3 else report_by_player.get(str(item.id), {})
	var player_id := str(item.get("playerId", item.id))
	var row := Button.new()
	row.name = "MarketReport_" + str(item.id) if tab == 3 else "MarketPlayer_" + player_id.replace(":", "_")
	row.set_meta("player_id", player_id)
	row.accessibility_name = "%s, %s" % [item.get("name", "Joueur inconnu"), item.get("pos", "Poste inconnu")]
	row.add_theme_stylebox_override("normal", D.surface(LEFT - 2, ROW_HEIGHT, Color("155a39"), Color("10412d"), Color("258653"), 3, false) if selected else C.box(Color("121c1d") if index % 2 == 0 else Color("0d1517"), Color.TRANSPARENT, 0, 0))
	row.add_theme_stylebox_override("hover", C.box(Color("244638"), C.MINT, 3, 0))
	row.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, WARM, 3, 0))
	table_rows.add_child(row)
	D.place(row, Rect2(0, index * ROW_HEIGHT, LEFT - 2, ROW_HEIGHT))
	D.line(row, Vector2(0, ROW_HEIGHT-1), Vector2(LEFT - 2, ROW_HEIGHT-1), Color(C.LINE, .65))
	D.text(row, 25, 25, str(index + 1), 17, C.IVORY, 700, 38, HORIZONTAL_ALIGNMENT_CENTER)
	_portrait(row, Rect2(65, 2, 35, 34), player, player_id)
	D.text(row, 128, 18, item.get("name", "—"), 18, C.IVORY, 700, 190 if tab != 3 else 359)
	D.text(row, 128, 33, "★ Suivi" if player_id in app.management_ui.shortlist else "Marché des joueurs" if tab != 3 else "Dossier d’observation", 13, WARM if player_id in app.management_ui.shortlist else C.MUTED, 500, 190)
	var assessment: Dictionary = report.get("assessment", {})
	if tab == 3:
		D.text(row, 506, 25, item.get("pos", "—"), 18, C.IVORY, 500, 250)
		D.text(row, 774, 25, assessment.get("source", "Date non conservée"), 17, C.MUTED, 500, 345)
		_badge(row, Rect2(1130, 5, 242, 27), _report_label(report), _report_color(report),17)
	else:
		D.text(row, 325, 25, item.get("pos", "—"), 17, C.IVORY, 500, 155)
		D.text(row, 510, 25, G.n(item.get("age", "—")), 18, C.IVORY, 600, 52, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(row, 582, 26, G.rating_text(item), 21, GREEN, 700, 65, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(row, 675, 26, G.potential_text(item if not item.is_empty() else report), 18, G.POTENTIAL_COLOR, 700, 80, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(row, 742, 25, _money(item.get("fee")), 17, C.IVORY, 600, 111)
		D.text(row, 864, 22, G.salary(item.get("salary")), 17, C.IVORY, 500, 174)
		if max_salary > 0 and (item.get("salary") is float or item.get("salary") is int):
			D.bar(row, Rect2(864, 28, 163, 5), 100.0 * float(item.salary) / max_salary, GREEN)
		D.text(row, 1043, 25, Sort.report_status(report), 17, C.MUTED, 500, 112)
		var status := _report_label(item)
		_badge(row, Rect2(1179, 5, 205, 27), status, _report_color(item),17)
	if tab != 3 and not report.is_empty():
		_reading_area(row,Rect2(1039,0,128,ROW_HEIGHT),{"kind":"report","id":str(report.get("id",""))},"MarketReportLink_"+str(report.get("id","")).validate_node_name(),"Rapport d’observation · " + str(item.get("name","")))
	var entity_target := {"kind":"report", "id":str(item.id)} if tab == 3 else {"kind":"market", "id":player_id}
	_reading_area(row,Rect2(60,0,426 if tab == 3 else 257,ROW_HEIGHT),entity_target,"MarketEntity_"+str(item.id).validate_node_name(),str(item.get("name","Dossier")))
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
	var entity_target := {"kind":"report", "id":str(report.get("id",""))} if tab == 3 else {"kind":"market", "id":player_id}
	_reading_area(panel,Rect2(16,12,345,240),entity_target,"RecruitmentPortraitLink",str(person.get("name","Dossier")))
	_reading_area(panel,Rect2(370,12,440,54),entity_target,"RecruitmentNameLink",str(person.get("name","Dossier")))
	D.rect(panel, Rect2(374, 104, 211, 84), Color("0d4e31"), 9)
	D.text(panel, 479, 172, G.rating_text(person), 43, C.IVORY, 800, 197, HORIZONTAL_ALIGNMENT_CENTER)
	D.line(panel, Vector2(599, 111), Vector2(599, 186), C.LINE)
	D.text(panel, 707, 149, G.potential_text(person), 34, G.POTENTIAL_COLOR, 800, 198, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(panel, 707, 177, "Potentiel", 25, C.MUTED, 600, 198, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(panel, 375, 222, G.n(person.get("age", "—")) + " ans", 24, C.IVORY, 600, 174)
	var can_track: bool = not player.is_empty() and not app.waiting and app._live().is_empty() and app.model.meta.get("phase", "") != "ended"
	var context: Variant = app.model.get("clubLife", {}).get("managerCareer", {}).get("context")
	var track := D.button(panel, Rect2(555, 195, 253, 41), "Retirer du suivi" if player_id in app.management_ui.shortlist else "Suivre cette piste", func():
		app._command("manager_recruitment_watch", {"context": context.duplicate(true), "playerId": player_id}), false, "star", true, app.accent, "Follow" + player_id.replace(":", "_"))
	track.set_meta("follow_id", player_id)
	track.disabled = not can_track or not context is Dictionary
	var source := D.rect(panel, Rect2(16, 255, 490, 43), Color("152224"), 7, C.LINE)
	_icon(source, "people", Rect2(16, 10, 23, 23), C.IVORY)
	D.text(source, 52, 29, info.get("source", "Aucune observation enregistrée"), 24, C.IVORY, 600, 426)
	if not report.is_empty():
		_reading_area(source,Rect2(0,0,490,43),{"kind":"report","id":str(report.get("id",""))},"RecruitmentSourceReport","Rapport d’observation daté")
	if person.get("scouting") is Dictionary:
		var observer := D.button(panel,Rect2(520,255,294,43),"",func(): pass,false,"search",true,app.accent,"ObserveRecruitment")
		preload("res://ui/player_observation.gd").configure(observer,app,person)
	else:
		var scouting := D.rect(panel, Rect2(520, 255, 294, 43), Color("152224"), 7, C.LINE)
		_icon(scouting, "search", Rect2(15, 10, 23, 23), C.IVORY)
		D.text(scouting, 51, 29, "Agent libre" if report.is_empty() else _report_label(report), 24, C.IVORY, 600, 230)
	_observation(panel, player, report)
	_deal(panel, player, report)
	D.button(panel, Rect2(16, 763, 407, 45), "Missions du recruteur" if report.is_empty() else "Lire le rapport complet", func():
		if report.is_empty(): _staff(1, str(player.get("pos", "")))
		else: _report_dialog(report), false, "save", true, app.accent, "OpenScoutReport")
	var consultation_only: bool = player.get("negotiation",{}).get("status","") == "withdrawn"
	var offer := D.button(panel, Rect2(437, 763, 377, 45), "Consulter la discussion" if consultation_only else "Approcher le joueur", func(): app.SquadViews.contract(app, player, true), true, "arrow", false, PRIMARY, "OfferRecruitment")
	offer.set_meta("player_id", player_id)
	offer.disabled = player.is_empty() or app.waiting or (not player.get("available", false) and not consultation_only) or not app._live().is_empty()
	offer.tooltip_text = str(player.get("reason", "")) if not player.is_empty() else "Le dossier est conservé dans les archives."

func _observation(parent: Panel, player: Dictionary, report: Dictionary) -> void:
	var info: Dictionary = report.get("assessment", {})
	var observed := _section(parent, Rect2(16, 305, 286, 137), "FAITS RELEVÉS", "check")
	var facts: Array = []
	for fact: String in info.get("observed", []):
		if fact not in facts: facts.append(fact)
	if facts.is_empty():
		facts = ["Âge : " + G.n(player.get("age", "—")) + " ans", "Niveau du marché : " + G.rating_text(player), "Sans rapport daté"]
	for i in mini(facts.size(), 3):
		D.text(observed, 15, 65 + 27 * i, facts[i], 22, C.IVORY, 500, 255)
	var vigilance := _section(parent, Rect2(310, 305, 291, 137), "VIGILANCE", "warning")
	var warning := str(player.get("reason", ""))
	if warning.is_empty(): warning = str(info.get("caution", "Les qualités techniques restent à observer."))
	var warning_lines := D.words(warning, 29, 3)
	for i in warning_lines.size():
		D.text(vigilance, 16, 65 + 25 * i, warning_lines[i], 22, C.IVORY, 500, 259)
	var knowledge_record := report if tab == 3 else player
	var trust := _section(parent, Rect2(610, 305, 204, 137), "OBSERVATION", "search")
	D.text(trust, 102, 107, _report_label(knowledge_record), 25, _report_color(knowledge_record), 800, 179, HORIZONTAL_ALIGNMENT_CENTER)
	var compare := _section(parent, Rect2(16, 452, 798, 162), "COMPARAISON AU MÊME POSTE", "people")
	var role := str(player.get("pos", report.get("pos", "")))
	var squad: Array = app.model.get("squad", []).filter(func(p: Dictionary): return str(p.get("pos", "")) == role)
	var average := 0.0
	for teammate: Dictionary in squad: average += float(teammate.get("rating", 0))
	var evaluation := report if tab == 3 else player
	var values: Array = [G.knowledge_sort_value(evaluation,"rating"), roundi(average / squad.size()) if not squad.is_empty() else null, G.knowledge_sort_value(evaluation,"potential")]
	var captions: Array = [G.rating_text(evaluation),G.n(values[1]) if values[1] != null else "—",G.potential_text(evaluation)]
	for i in values.size():
		var y := 59 + i * 36
		D.text(compare, 25, y + 12, ["Niveau de la piste", "Moyenne de l’effectif", "Potentiel observé"][i], 24, C.IVORY, 500, 272)
		if values[i] != null:
			var tone: Color = G.POTENTIAL_COLOR if i == 2 else GREEN if i == 0 else C.MUTED
			D.bar(compare, Rect2(312, y - 2, 340, 12), float(values[i]), tone)
			if i != 1:
				var interval: Dictionary = G.knowledge_bounds(evaluation,"potential" if i == 2 else "rating")
				if not interval.is_empty() and interval.max > interval.min:
					var rail := D.rect(compare,Rect2(312+340*float(interval.min)/100,y-2,340*float(interval.max-interval.min)/100,12),Color(tone,.35),0,tone)
					rail.name = "CandidatePotentialRange" if i == 2 else "CandidateRatingRange"
		D.text(compare, 771, y + 12, str(captions[i]), 22, G.POTENTIAL_COLOR if i == 2 else GREEN if i == 0 else C.MUTED, 700, 110, HORIZONTAL_ALIGNMENT_RIGHT)

func _deal(parent: Panel, player: Dictionary, report: Dictionary) -> void:
	var section := _section(parent, Rect2(16, 624, 798, 125), "SYNTHÈSE DU CONTRAT", "money")
	var quote := player if not player.is_empty() else report
	var max_years := int(player.get("maxYears", 0))
	var values := [_money(quote.get("fee", quote.get("price"))), G.salary(quote.get("salary")), "%s à %s ans" % [G.n(player.get("minYears", 1)), G.n(max_years)] if max_years > 1 else "1 an" if max_years == 1 else "—"]
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

func _reading_area(parent: Node, area: Rect2, target: Dictionary, id: String, caption: String) -> void:
	if not app.navigation_controller.entity_available(target): return
	var link := Button.new()
	link.name = id
	link.flat = true
	link.add_theme_stylebox_override("normal",C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,0))
	link.add_theme_stylebox_override("hover",C.box(Color(C.MINT,.06),Color(C.MINT,.55),3,0))
	link.add_theme_stylebox_override("focus",C.box(Color.TRANSPARENT,WARM,3,0))
	Link.bind(link,app,target,caption)
	parent.add_child(link)
	D.place(link,area)

func _report_dialog(report: Dictionary) -> void:
	app.navigation_controller.open_entity({"kind":"report", "id":str(report.get("id", ""))})

func _compare() -> void:
	load("res://ui/immersive08/recruitment_comparison.gd").open(app, str(dossier.get_meta("player_id", "")), report_by_player)

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

static func _badge(parent: Node, area: Rect2, caption: String, tint: Color, font_size: int = 22) -> void:
	var filled := tint in [GREEN, C.ALERT]
	var frame := D.rect(parent, area, tint if filled else tint.darkened(.76), 6, tint)
	D.text(frame, area.size.x / 2, area.size.y / 2 + font_size*.32, caption, font_size, Color("091a11") if filled else tint, 700, area.size.x - 10, HORIZONTAL_ALIGNMENT_CENTER)

static func _portrait(parent: Node, area: Rect2, player: Dictionary, player_id: String, full: bool = false) -> void:
	if str(player.get("id", "")).is_empty():
		D.photo(parent, "recruit-profile" if full else "player-%02d" % posmod(player_id.hash(), 16), area)
		return
	var photo := G.portrait(0, C.px(minf(area.size.x, area.size.y)), player)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(photo)
	D.place(photo, area)

static func _report_label(report: Dictionary) -> String:
	return Sort.report_label(report)

static func _report_color(report: Dictionary) -> Color:
	return {"deep": GREEN, "observed": C.BLUE}.get(report.get("knowledge",{}).get("stage",""),C.FAINT)

static func _money(value: Variant) -> String:
	return G.euros(value) if value is int or value is float else "—"
