extends VBoxContainer
## Read-only horizons from the current squad projection. No invented deadlines.
const C = preload("res://ui/immersive08/components.gd")
const U = preload("res://ui/management_state.gd")
const G = preload("res://ui/game_skin.gd")
const STATUS_OPTIONS := ["Tous","Prolongation accessible","Discussion en cours","Échanges clos","Sans contrat renseigné"]
var app: Control
var state: Dictionary
var _rows: VBoxContainer
var _coverage: VBoxContainer
var _count: Label
var _scroll: ScrollContainer
var _season: OptionButton
var _position: OptionButton
var _headers: Dictionary = {}
const SORT_KEYS := ["name","pos","rating","potential","age","contractEnd","salary","minutes","status","renewal"]

static func build(owner_app: Control) -> Control:
	var view: Control = load("res://ui/contract_review.gd").new()
	view.app = owner_app
	view._build()
	return view

static func action_id(prefix: String, player_id: String) -> String:
	return prefix + "_" + player_id.sha256_text().substr(0, 16)

static func projected_mark(player: Dictionary, key: String) -> String:
	var value: Variant = player.get(key)
	return G.n(value) if (value is int or value is float) and is_finite(float(value)) else "—"

static func horizon(player: Dictionary) -> int:
	var value: Variant = player.get("contractEnd")
	return int(value) if (value is int or value is float) and float(value) == floorf(float(value)) and int(value) >= 0 else -1

static func filtered(players: Array, filters: Dictionary) -> Array:
	var result: Array = []
	for player: Dictionary in players:
		var ending := horizon(player)
		if int(filters.get("season", 0)) > 0 and ending != int(filters.season): continue
		var status := str(filters.get("status", "Tous"))
		var quote: Dictionary = player.get("renewal", {})
		var discussion: String = str(quote.get("negotiation", {}).get("status", ""))
		if status == "Prolongation accessible" and not bool(quote.get("available", false)): continue
		if status == "Discussion en cours" and not discussion in ["counter", "ready"]: continue
		if status == "Échanges clos" and discussion != "withdrawn": continue
		if str(filters.get("status", "Tous")) == "Sans contrat renseigné" and ending >= 0: continue
		if str(filters.get("precision", "Toutes")) == "Échéance connue" and ending < 0: continue
		if str(filters.get("precision", "Toutes")) == "Non renseignée" and ending >= 0: continue
		if str(filters.get("position", "Tous")) != "Tous" and str(player.get("pos", "")) != str(filters.position): continue
		var query := U.fold(str(filters.get("search", "")).strip_edges())
		if not query.is_empty() and not U.fold(str(player.get("name", "")) + " " + str(player.get("pos", ""))).contains(query): continue
		result.append(player)
	var sort_key := str(filters.get("sort", "contractEnd"))
	if not sort_key in SORT_KEYS: sort_key = "contractEnd"
	var descending := bool(filters.get("descending", false))
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		var first: Variant = sort_value(a, sort_key, bool(filters.get("live", false)))
		var second: Variant = sort_value(b, sort_key, bool(filters.get("live", false)))
		if first == null and second != null: return false
		if first != null and second == null: return true
		var comparison := 0
		if first != null:
			if first is String: comparison = U.fold(first).naturalnocasecmp_to(U.fold(str(second)))
			else: comparison = -1 if float(first) < float(second) else 1 if float(first) > float(second) else 0
		if comparison == 0: return str(a.id) < str(b.id)
		return comparison > 0 if descending else comparison < 0)
	return result

static func sort_value(player: Dictionary, key: String, live: bool = false) -> Variant:
	if key == "contractEnd": return horizon(player) if horizon(player) >= 0 else null
	if key == "renewal": return renewal_reason(player, live) if player.get("renewal") is Dictionary and not player.renewal.is_empty() else null
	var value: Variant = player.get(key)
	if key in ["rating","potential","age","salary","minutes"]:
		return value if (value is int or value is float) and is_finite(float(value)) else null
	return str(value) if value != null and not str(value).strip_edges().is_empty() else null

static func coverage(players: Array, season: int) -> Array:
	var groups: Dictionary = {}
	for player: Dictionary in players:
		var position := str(player.get("pos", "Poste non renseigné"))
		if not groups.has(position): groups[position] = {"position":position,"total":0,"ending":0,"remaining":0,"unknown":0}
		groups[position].total += 1
		var ending := horizon(player)
		if ending < 0: groups[position].unknown += 1
		elif ending <= season: groups[position].ending += 1
		else: groups[position].remaining += 1
	var result: Array = groups.values()
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		if a.ending != b.ending: return a.ending > b.ending
		return str(a.position).naturalnocasecmp_to(str(b.position)) < 0)
	return result

static func renewal_reason(player: Dictionary, live: bool) -> String:
	if live: return "Match en cours : prolongation indisponible"
	var quote: Dictionary = player.get("renewal", {})
	if not str(quote.get("reason", "")).is_empty(): return str(quote.reason)
	if quote.get("negotiation", {}).get("status") == "withdrawn": return "Échanges clos pour cette journée"
	return "Prolongation accessible" if bool(quote.get("available", false)) else "Prolongation indisponible actuellement"

func _label(text: String, size: int = 18, color: Color = C.IVORY, width: float = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", C.BODY)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0:
		label.custom_minimum_size.x = width
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return label

func _button(text: String, id: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	button.custom_minimum_size.y = 34
	button.add_theme_font_override("font", C.BOLD)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", C.IVORY)
	button.add_theme_stylebox_override("normal", C.box(C.PANEL, C.LINE, 4, 5))
	button.add_theme_stylebox_override("hover", C.box(C.RAISED, C.MINT, 4, 5))
	button.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, C.GOLD, 4, 5))
	button.pressed.connect(action)
	return button

func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", C.box(C.PANEL, C.LINE, 4, 10))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	return body

func _build() -> void:
	name = "ContractReview"
	add_theme_constant_override("separation", 10)
	if not app.management_ui.roster.has("contract_review"):
		app.management_ui.roster.contract_review = {"season":0,"status":"Tous","precision":"Toutes","position":"Tous","search":"","scroll":0,"focus":""}
	state = app.management_ui.roster.contract_review
	if not state.has("sort"): state.sort = "contractEnd"
	if not state.has("descending"): state.descending = false
	add_child(_label("Les échéances de votre effectif", 26))
	add_child(_label("Échéances classées par année de fin, sans présumer une urgence. Aucune date précise d’expiration n’est fournie.", 17, C.MUTED))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	var squad: Array = app.model.get("squad", [])
	var current := int(app.model.get("meta", {}).get("season", 1))
	var ending := squad.filter(func(player): return horizon(player) >= 0 and horizon(player) <= current).size()
	var renewals := squad.filter(func(player): return player.get("renewal", {}).get("available", false) and app._live().is_empty()).size()
	var known_wage := 0.0
	var unknown_wage := 0
	for player: Dictionary in squad:
		var wage: Variant = player.get("salary")
		if wage is int or wage is float: known_wage += float(wage)
		else: unknown_wage += 1
	for metric in [["Échéances en %s ou avant" % G.contract_year(current), "%d / %d joueurs" % [ending, squad.size()]], ["Prolongations accessibles", "%d joueurs" % renewals], ["Salaires actuels projetés · " + G.salary_period(), G.salary_amount(known_wage) + (" · %d non fourni(s)" % unknown_wage if unknown_wage > 0 else "")]]:
		var card := _panel(top)
		card.add_child(_label(metric[0], 16, C.MUTED))
		var value := _label(metric[1], 22, C.IVORY)
		if str(metric[0]).begins_with("Salaires"): value.name = "ContractReviewWage"
		card.add_child(value)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	add_child(filters)
	var search := LineEdit.new()
	search.name = "ContractReviewSearch"
	search.placeholder_text = "Nom ou poste…"
	search.text = str(state.search)
	search.custom_minimum_size = Vector2(340, 36)
	search.add_theme_font_size_override("font_size", 18)
	filters.add_child(search)
	search.text_changed.connect(func(value): state.search = value; state.scroll = 0; _refresh())
	_season = _choice(filters, "ContractReviewSeason", "Toutes les années", func(index): state.season = int(_season.get_item_metadata(index)); state.scroll = 0; _refresh())
	_season.set_item_metadata(0, 0)
	var years: Array[int] = []
	for player: Dictionary in squad:
		var end := horizon(player)
		if end >= 0 and not end in years: years.append(end)
	years.sort()
	for year in years:
		_season.add_item("Fin " + G.contract_year(year))
		_season.set_item_metadata(_season.item_count - 1, year)
		if year == int(state.season): _season.select(_season.item_count - 1)
	var status := _choice(filters, "ContractReviewStatus", "Contrats : tous", func(index): state.status = STATUS_OPTIONS[index]; state.scroll = 0; _refresh())
	_fill_choice(status, STATUS_OPTIONS.slice(1), str(state.status))
	var precision := _choice(filters, "ContractReviewPrecision", "Échéance : toutes", func(index): state.precision = ["Toutes","Échéance connue","Non renseignée"][index]; state.scroll = 0; _refresh())
	_fill_choice(precision, ["Échéance connue", "Non renseignée"], str(state.precision))
	_position = _choice(filters, "ContractReviewPosition", "Tous les postes", func(index): state.position = "Tous" if index == 0 else _position.get_item_text(index); state.scroll = 0; _refresh())
	var positions: Array = []
	for player: Dictionary in squad:
		if not str(player.pos) in positions: positions.append(str(player.pos))
	positions.sort()
	_fill_choice(_position, positions, str(state.position))
	filters.add_child(_button("Réinitialiser", "ContractReviewReset", _reset))
	_count = _label("", 16, C.MUTED)
	_count.name = "ContractReviewCount"
	add_child(_count)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(columns)
	var main := _panel(columns)
	main.get_parent().size_flags_stretch_ratio = 3.6
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var inset := Control.new()
	inset.custom_minimum_size.x = 8
	header.add_child(inset)
	for column in [["JOUEUR",300,"name"],["POSTE",160,"pos"],["NIVEAU",72,"rating"],["POTENTIEL",84,"potential"],["ÂGE",60,"age"],["FIN DE CONTRAT",145,"contractEnd"],["SALAIRE " + G.salary_period(true).to_upper(),145,"salary"],["MIN.",95,"minutes"],["STATUT",110,"status"],["PROLONGATION",190,"renewal"],["CONSULTER",276,""]]:
		if str(column[2]).is_empty():
			header.add_child(_cell(column[0], column[1], C.MUTED, 16))
			continue
		var key := str(column[2])
		var sort := _button(str(column[0]), "ContractSort_" + key, func(): _sort(key))
		sort.custom_minimum_size = Vector2(column[1], 30)
		sort.add_theme_font_size_override("font_size", 16)
		sort.clip_text = true
		sort.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		for mode in ["normal","hover","pressed"]:
			sort.add_theme_stylebox_override(mode, C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		sort.set_meta("caption", str(column[0]))
		header.add_child(sort)
		_headers[key] = sort
	main.add_child(header)
	_scroll = ScrollContainer.new()
	_scroll.name = "ContractReviewScroll"
	_scroll.follow_focus = true
	_scroll.mouse_force_pass_scroll_events = false
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = 400
	main.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.name = "ContractReviewRows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 2)
	_scroll.add_child(_rows)
	_scroll.get_v_scroll_bar().value_changed.connect(func(value): state.scroll = value)
	var sidebar := _panel(columns)
	sidebar.get_parent().size_flags_stretch_ratio = 1.0
	sidebar.get_parent().custom_minimum_size.x = 440
	sidebar.add_child(_label("Échéances et postes à anticiper", 24))
	sidebar.add_child(_label("Postes principaux · aucun départ annoncé. Cliquez un poste pour filtrer.", 16, C.MUTED))
	var side_scroll := ScrollContainer.new()
	side_scroll.follow_focus = true
	_scroll.mouse_force_pass_scroll_events = false
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(side_scroll)
	_coverage = VBoxContainer.new()
	_coverage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coverage.add_theme_constant_override("separation", 8)
	side_scroll.add_child(_coverage)
	_refresh()
	call_deferred("_restore_focus")

func _choice(parent: Node, id: String, first: String, changed: Callable) -> OptionButton:
	var choice := OptionButton.new()
	choice.name = id
	choice.custom_minimum_size = Vector2(230, 36)
	choice.add_theme_font_override("font", C.BODY)
	choice.add_theme_font_size_override("font_size", 18)
	choice.fit_to_longest_item = false
	choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	choice.add_item(first)
	choice.item_selected.connect(changed)
	parent.add_child(choice)
	return choice

func _fill_choice(choice: OptionButton, values: Array, selected: String) -> void:
	for value in values:
		choice.add_item(str(value))
		if str(value) == selected: choice.select(choice.item_count - 1)

func _reset() -> void:
	state.merge({"season":0,"status":"Tous","precision":"Toutes","position":"Tous","search":"","scroll":0,"focus":"ContractReviewReset","sort":"contractEnd","descending":false}, true)
	app._render(false)

func _sort(key: String) -> void:
	state.descending = not bool(state.descending) if str(state.sort) == key else false
	state.sort = key
	state.scroll = 0
	state.focus = "ContractSort_" + key
	_refresh()
	_restore_focus()

func _refresh() -> void:
	for node in _rows.get_children(): _rows.remove_child(node); node.queue_free()
	for node in _coverage.get_children(): _coverage.remove_child(node); node.queue_free()
	var filters := state.duplicate(true)
	filters.live = not app._live().is_empty()
	var players := filtered(app.model.get("squad", []), filters)
	_count.text = "%d / %d joueurs · cliquez un titre pour trier · consultation sans signature" % [players.size(), app.model.get("squad", []).size()]
	for key: String in _headers:
		var sort: Button = _headers[key]
		var selected := str(state.sort) == key
		sort.text = str(sort.get_meta("caption")) + (" ▼" if state.descending else " ▲") if selected else str(sort.get_meta("caption")) + " ↕"
		sort.tooltip_text = "Trier par " + str(sort.get_meta("caption")) + (" · ordre décroissant" if selected and state.descending else " · ordre croissant" if selected else "")
		sort.accessibility_name = sort.tooltip_text
	if players.is_empty(): _rows.add_child(_label("Aucun joueur ne correspond. Modifiez les filtres ou réinitialisez la recherche.", 18, C.MUTED))
	for player: Dictionary in players: _row(player)
	var year := int(state.season) if int(state.season) > 0 else int(app.model.get("meta", {}).get("season", 1))
	_coverage.add_child(_label("Échéances par année", 19))
	var horizons: Dictionary = {}
	for player: Dictionary in app.model.get("squad", []):
		var end := horizon(player)
		horizons[end] = int(horizons.get(end, 0)) + 1
	var seasons: Array = horizons.keys()
	seasons.sort()
	for end in seasons:
		_bar(_coverage, "Non renseignée" if int(end) < 0 else "Fin " + G.contract_year(end), int(horizons[end]), app.model.get("squad", []).size(), C.MUTED if int(end) < 0 else C.GOLD if int(end) <= year else C.MINT)
	_coverage.add_child(_label("Couverture · horizon " + G.contract_year(year), 19, C.GOLD))
	for group: Dictionary in coverage(app.model.get("squad", []), year):
		var button := _button("%s · %d / %d" % [group.position, group.ending, group.total], "ContractReviewCoverage_" + str(group.position).sha256_text().substr(0,16), func():
			state.position = str(group.position)
			state.focus = "ContractReviewCoverage_" + str(group.position).sha256_text().substr(0,16)
			for index in _position.item_count:
				if _position.get_item_text(index) == state.position: _position.select(index)
			_refresh()
			call_deferred("_restore_focus"))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_coverage.add_child(button)
		var progress := ProgressBar.new()
		progress.custom_minimum_size.y = 5
		progress.max_value = maxf(1, group.total)
		progress.value = group.ending
		progress.show_percentage = false
		progress.add_theme_stylebox_override("fill", C.box(C.GOLD, Color.TRANSPARENT, 0, 0))
		_coverage.add_child(progress)
		_coverage.add_child(_label("%d sous contrat au-delà%s" % [group.remaining, " · %d échéance(s) inconnue(s)" % group.unknown if group.unknown > 0 else ""], 16, C.MUTED))
	_scroll.set_deferred("scroll_vertical", int(state.scroll))

func _cell(text: String, width: float, color: Color = C.IVORY, font_size: int = 18) -> Label:
	var label := _label(text, font_size, color, width)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = text
	return label

func _bar(parent: Node, caption: String, value: int, total: int, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	row.add_child(_cell(caption, 142, C.MUTED, 16))
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(140, 12)
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.max_value = maxi(total, 1)
	progress.value = value
	progress.show_percentage = false
	progress.add_theme_stylebox_override("fill", C.box(color, Color.TRANSPARENT, 2, 0))
	row.add_child(progress)
	row.add_child(_cell(str(value), 40, color, 18))

func _row(player: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = action_id("ContractRow", str(player.id))
	panel.set_meta("player_id", str(player.id))
	panel.custom_minimum_size.y = 34
	var background := Color("18242a") if _rows.get_child_count() % 2 == 0 else Color("111b20")
	var style := C.box(background, Color.TRANSPARENT, 0, 0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	panel.add_theme_stylebox_override("panel", style)
	_rows.add_child(panel)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	panel.add_child(line)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 6)
	identity.custom_minimum_size.x = 300
	line.add_child(identity)
	var portrait: Control = G.portrait(int(player.get("portraitIndex", 0)), 30, player)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(portrait)
	identity.add_child(_cell(str(player.get("name", "Joueur")), 264, C.IVORY, 18))
	var ending := horizon(player)
	var year := int(app.model.get("meta", {}).get("season", 1))
	line.add_child(_cell(str(player.get("pos", "—")), 160, C.MUTED))
	var level := _cell(projected_mark(player, "rating"), 72, C.MINT, 18)
	level.name = action_id("ContractLevel", str(player.id))
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.tooltip_text = "Niveau global projeté / 100, identique à la fiche du joueur."
	line.add_child(level)
	var potential := _cell(projected_mark(player, "potential"), 84, Color("ffb454"), 18)
	potential.name = action_id("ContractPotential", str(player.id))
	potential.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	potential.tooltip_text = "Potentiel projeté au poste / 100, identique à la fiche. Ce plafond n’est pas garanti."
	line.add_child(potential)
	line.add_child(_cell(G.n(player.age) if player.get("age") != null else "—", 60, C.MUTED))
	line.add_child(_cell(G.contract_year(ending) if ending >= 0 else "Non renseignée", 145, C.GOLD if ending >= 0 and ending <= year else C.MINT if ending > year else C.MUTED))
	var salary: Variant = player.get("salary")
	var salary_cell := _cell(G.salary_amount(salary) if salary is int or salary is float else "Non fourni", 145)
	salary_cell.name = action_id("ContractSalary",str(player.id))
	line.add_child(salary_cell)
	line.add_child(_cell(G.n(player.minutes) if player.get("minutes") != null else "—", 95, C.MUTED))
	line.add_child(_cell(str(player.get("status", "—")), 110, C.MUTED, 16))
	line.add_child(_cell(renewal_reason(player, not app._live().is_empty()), 190, C.MUTED, 16))
	var actions := HBoxContainer.new()
	actions.custom_minimum_size.x = 276
	actions.add_theme_constant_override("separation", 8)
	line.add_child(actions)
	var id := str(player.id)
	var profile := _button("Fiche", action_id("ContractProfile", id), func(): _open_profile(id))
	profile.set_meta("player_id", id)
	profile.custom_minimum_size.x = 100
	actions.add_child(profile)
	var discussion: Dictionary = player.get("renewal", {}).get("negotiation", {})
	var quote := _button("Discussion" if not discussion.is_empty() else "Prolonger", action_id("ContractRenew", id), func(): _open_quote(id))
	quote.set_meta("player_id", id)
	quote.custom_minimum_size.x = 160
	quote.disabled = not app._live().is_empty() or (not bool(player.get("renewal", {}).get("available", false)) and discussion.is_empty())
	quote.tooltip_text = renewal_reason(player, not app._live().is_empty())
	actions.add_child(quote)

func _find(id: String) -> Dictionary:
	for player: Dictionary in app.model.get("squad", []):
		if str(player.id) == id: return player
	return {}

func _remember(id: String) -> void:
	state.focus = id
	state.scroll = _scroll.scroll_vertical

func _open_profile(id: String) -> void:
	if _find(id).is_empty(): return
	_remember(action_id("ContractProfile", id))
	app.selected_player = id
	app.management_ui.profile_scroll = 0
	app.set_meta("immersive08_full_player", true)
	app._render()

func _open_quote(id: String) -> void:
	var player := _find(id)
	if player.is_empty() or not app._live().is_empty(): return
	_remember(action_id("ContractRenew", id))
	app.selected_player = id
	app.SquadViews.contract(app, player, false)
	var dialog := app.get_node_or_null("ContractOffer")
	if dialog != null: dialog.tree_exited.connect(func(): call_deferred("_restore_focus"), CONNECT_ONE_SHOT)

func _restore_focus() -> void:
	if not is_inside_tree(): return
	if str(state.get("focus", "")).is_empty(): return
	var control := find_child(str(state.get("focus", "")), true, false) as Control
	if control != null and control.is_visible_in_tree(): control.grab_focus()
