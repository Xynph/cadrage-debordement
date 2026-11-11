extends Node
# Session-only reading history. This controller never calls the engine bridge.
const U = preload("res://ui/management_state.gd")
const G = preload("res://ui/carnet_skin.gd")
const C = preload("res://ui/immersive08/components.gd")
const HISTORY_LIMIT := 60
const RESULT_LIMIT := 12
var app: Control
var history: Array[Dictionary] = []
var cursor := -1
var _dialog: AcceptDialog
var _search: LineEdit
var _results: ItemList
var _count: Label
var _matches: Array[Dictionary] = []
var _back: Button
var _forward: Button
var _find: Button
var _restoring := false
var _palette_return_focus: WeakRef
var _dispatching := false
var _reading_revision := 0

func setup(owner_app: Control) -> void:
	app = owner_app
	name = "NavigationController"
	set_process_input(true)
	app.get_viewport().size_changed.connect(func(): call_deferred("_fit_palette"))

func reset() -> void:
	_reading_revision += 1
	history.clear()
	cursor = -1
	if is_instance_valid(_dialog): _dialog.hide()
	_refresh_controls()

func observe(route: String, player_id: String = "", staff_club: int = -1, roster_lookup: bool = false) -> void:
	if app == null or _restoring or not _allowed_route(route):
		_refresh_controls()
		return
	var entry := {"route":route, "player":player_id if route == "Effectif" else "", "staff":staff_club if route == "Staff" else -1, "market":""}
	entry.target = _current_target(route)
	entry.detail = _reading_location(route)
	if route == "Effectif": entry.full_player = app.get_meta("immersive08_full_player", false)
	if route == "Préparation": entry.preparation_tab = int(app.management_ui.get("preparation", {}).get("tab", 0))
	if route == "Recrutement": entry.market = str(app.management_ui.get("market", {}).get("navigation_id", ""))
	if cursor >= 0:
		var previous := history[cursor]
		var same_location := entry.keys().all(func(key: String): return previous.get(key) == entry[key])
		if same_location and (not roster_lookup or previous.roster == app.management_ui.roster):
			_refresh_controls()
			return
		if not roster_lookup and previous.route == route: _store_roster_reading(previous)
	history = history.slice(0, cursor + 1)
	_store_roster_reading(entry)
	entry.reading = U.reading_snapshot(app)
	history.append(entry)
	if history.size() > HISTORY_LIMIT: history.pop_front()
	cursor = history.size() - 1
	_refresh_controls()

func _current_target(route: String) -> Dictionary:
	var target: Dictionary = app.management_ui.get("navigation_target", {})
	if target.get("route") != route: return {}
	var kind := str(target.get("kind", ""))
	var id := str(target.get("id", ""))
	if route == "Effectif" and kind in ["player", "squad"] and app.selected_player != id: return {}
	if route == "Recrutement" and kind in ["player", "squad", "market"] and str(app.management_ui.get("market", {}).get("navigation_id", "")) != id: return {}
	if kind == "nation" and str(app.management_ui.get("international", {}).get("navigation_id", "")) != id: return {}
	if kind == "staff" and str(app.management_ui.get("staff", {}).get("navigation_id", "")) != id: return {}
	return target.duplicate(true)

func _reading_location(route: String) -> Dictionary:
	match route:
		"Sélections": return {"nation":app.management_ui.get("international", {}).get("navigation_id", ""), "section":app.management_ui.get("international_section", "")}
		"Staff": return {"person":app.management_ui.get("staff", {}).get("navigation_id", "")}
		"Classements": return {"division":app.table_division, "tab":app.management_ui.get("competition", {}).get("tab", "league")}
		"Calendrier": return {"date":app.management_ui.get("calendar_reading", {}).get("selected", "")}
		"Finances": return {"tab":app.management_ui.get("immersive08_finance_tab", "summary")}
	return {}

# Called before a route or entity changes. This snapshots only local reading state;
# no navigation path is permitted to ask the worker to project extra information.
func capture_current() -> void:
	if app == null or _restoring or _dispatching or cursor < 0: return
	if history[cursor].route != app.route: return
	U.remember(app)
	_store_roster_reading(history[cursor])
	history[cursor].reading = U.reading_snapshot(app)

func _store_roster_reading(entry: Dictionary) -> void:
	if entry.route != "Effectif": return
	entry.roster = app.management_ui.roster.duplicate(true)
	entry.profile_scroll = app.management_ui.profile_scroll

func controls(show_search: bool = true) -> Control:
	var row := G.h(5 if show_search else C.px(5))
	row.name = "NavigationControls"
	_back = _small_button("←", "Précédent · Alt + gauche", "NavigationBack", func(): _travel(-1), not show_search)
	_forward = _small_button("→", "Suivant · Alt + droite", "NavigationForward", func(): _travel(1), not show_search)
	row.add_child(_back)
	row.add_child(_forward)
	if show_search:
		_find = _small_button("Chercher", "Rechercher un menu ou un joueur · Ctrl + K", "NavigationOpen", open_palette)
		_find.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_find)
	else: _find = null
	_refresh_controls()
	return row

func _small_button(text: String, tooltip: String, id: String, action: Callable, immersive: bool = false) -> Button:
	var button := C.button(text, action) if immersive else G.button(text, action)
	button.name = id
	button.tooltip_text = tooltip
	button.accessibility_name = tooltip
	button.custom_minimum_size = Vector2(C.px(43), C.px(42)) if immersive else Vector2(29, 34)
	button.add_theme_font_size_override("font_size", maxi(12, C.px(21)) if immersive else 12)
	return button

func _input(event: InputEvent) -> void:
	if handle_shortcut(event): get_viewport().set_input_as_handled()

func handle_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo or app == null: return false
	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if is_instance_valid(_dialog) and _dialog.visible:
		if code == KEY_ESCAPE:
			_dialog.hide()
			_restore_palette_focus()
			return true
		if code in [KEY_UP, KEY_DOWN] and not event.alt_pressed:
			if _results.item_count > 0:
				var selected := _results.get_selected_items()
				var index: int = selected[0] if not selected.is_empty() else 0
				index = clampi(index + (1 if code == KEY_DOWN else -1), 0, _results.item_count - 1)
				_results.select(index); _results.ensure_current_is_visible()
			return true
		if code in [KEY_ENTER, KEY_KP_ENTER]:
			_activate_selected()
			return true
		if event.ctrl_pressed and code == KEY_K: return true
		return false
	var save_shortcut: bool = code==KEY_S and event.ctrl_pressed and not event.alt_pressed
	if _blocked(null,save_shortcut): return false
	if save_shortcut and app._has_career():
		app._command("save")
		return true
	if code==KEY_F1 and not event.ctrl_pressed and not event.alt_pressed:
		app._open_coach()
		return true
	if code == KEY_K and event.ctrl_pressed and not event.alt_pressed:
		open_palette()
		return true
	if event.alt_pressed and not event.ctrl_pressed and code in [KEY_LEFT, KEY_RIGHT]:
		var focus := app.get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit or focus is SpinBox or focus is OptionButton: return false
		if focus != null and focus.get_parent() is SpinBox: return false
		_travel(-1 if code == KEY_LEFT else 1)
		return true
	return false

func open_palette() -> void:
	if app == null or _blocked(): return
	var previous := app.get_viewport().gui_get_focus_owner()
	_palette_return_focus = weakref(previous) if previous != null else null
	if not is_instance_valid(_dialog) or _dialog.is_queued_for_deletion(): _build_palette()
	_search.clear()
	_refresh_results("")
	_dialog.popup_centered(_palette_size())
	call_deferred("_fit_palette")
	_search.grab_focus()

func _restore_palette_focus() -> void:
	var previous := _palette_return_focus.get_ref() as Control if _palette_return_focus != null else null
	_palette_return_focus = null
	if not is_instance_valid(previous): return
	# Closing the palette is a reading action. Restore the exact field/button,
	# without reviving a control removed by a render or a command in progress.
	call_deferred("_focus_after_palette", previous)

func _focus_after_palette(previous: Control) -> void:
	if not is_instance_valid(previous) or _blocked() or not previous.is_inside_tree() or not previous.is_visible_in_tree(): return
	if previous.focus_mode == Control.FOCUS_NONE: return
	if previous is BaseButton and previous.disabled: return
	previous.grab_focus()

func _fit_palette() -> void:
	if not is_instance_valid(_dialog) or not _dialog.visible: return
	# Wrapping labels can briefly report their height before the first layout.
	# AcceptDialog keeps that enlarged size even after their minimum has settled.
	_dialog.size = _palette_size()
	_dialog.position = (app.get_window().size - _dialog.size) / 2

func _palette_size() -> Vector2i:
	var viewport := app.get_viewport_rect().size
	var desktop := viewport.x>=1920
	return Vector2i(mini(840 if desktop else 680,int(viewport.x)-48),mini(566 if desktop else 520,int(viewport.y)-64))

func _build_palette() -> void:
	_dialog = AcceptDialog.new()
	_dialog.name = "NavigationPalette"
	app._prepare_dialog(_dialog,_palette_size().x)
	_dialog.title = "Votre carnet · accès rapide"
	_dialog.get_ok_button().text = "OUVRIR"
	var content := C.v(12)
	content.custom_minimum_size.x = _palette_size().x-60
	_dialog.add_child(content)
	var heading := C.h(11)
	content.add_child(heading)
	heading.add_child(C.icon("search",27,C.GOLD))
	heading.add_child(C.label("ACCÈS RAPIDE",26,C.GOLD,true,700))
	content.add_child(C.wrap("Menus, joueurs et clubs · ↑ ↓ choisir · Entrée ouvrir · Échap fermer",19,C.MUTED))
	_search = LineEdit.new()
	_search.name = "NavigationSearch"
	_search.placeholder_text = "Rechercher un menu, un nom ou un poste…"
	_search.accessibility_name = "Rechercher un menu, un joueur ou un club"
	_search.add_theme_color_override("font_placeholder_color",C.MUTED)
	_search.custom_minimum_size.y = maxi(38,C.px(46))
	content.add_child(_search)
	_results = ItemList.new()
	_results.name = "NavigationResults"
	_results.custom_minimum_size = Vector2(0, 310)
	_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results.add_theme_font_size_override("font_size",maxi(14,C.px(18)))
	_results.add_theme_constant_override("v_separation", 8)
	_results.add_theme_color_override("font_color",C.IVORY)
	_results.add_theme_stylebox_override("panel",C.box(C.BG,C.LINE,6,9))
	_results.add_theme_stylebox_override("selected",C.box(app.accent.darkened(.53),C.GOLD,4,6))
	_results.add_theme_stylebox_override("selected_focus",C.box(app.accent.darkened(.41),C.GOLD,4,6))
	_results.add_theme_color_override("font_selected_color",C.IVORY)
	content.add_child(_results)
	_count = C.label("",18,C.MUTED)
	_count.name = "NavigationCount"
	content.add_child(_count)
	app.add_child(_dialog)
	_search.text_changed.connect(_refresh_results)
	_search.gui_input.connect(func(event: InputEvent):
		if handle_shortcut(event): _search.accept_event())
	_results.gui_input.connect(func(event: InputEvent):
		if handle_shortcut(event): _results.accept_event())
	_results.item_activated.connect(func(_index: int): _activate_selected())
	_dialog.confirmed.connect(_activate_selected)
	_dialog.canceled.connect(_restore_palette_focus)
	_dialog.visibility_changed.connect(_refresh_controls)

func _refresh_results(query: String) -> void:
	_results.clear(); _matches.clear()
	var needle := U.fold(query).strip_edges()
	var candidates: Array[Dictionary] = []
	if not app._has_career():
		candidates.append({"kind":"menu", "route":"Accueil", "label":"Menu · Accueil"})
	else:
		for chapter: Dictionary in app.NAV_CHAPTERS:
			for route: String in chapter.routes:
				candidates.append({"kind":"menu", "route":route, "label":"Menu · " + route + " · " + str(chapter.label)})
		if app.model.get("international") is Dictionary:
			candidates.append({"kind":"menu", "route":"Sélections", "label":"Menu · Sélections internationales"})
		candidates.append({"kind":"training","route":"Préparation","label":"Menu · Entraînement · Équipe"})
		for team: Dictionary in app.model.get("staff", {}).get("teams", []):
			candidates.append({"kind":"club", "id":team.id, "route":"Classements", "label":"Club · %s · Détail du club" % G.club_name(team)})
			for person: Dictionary in team.get("members", []):
				var staff_id := str(person.get("id", ""))
				if staff_id.is_empty(): continue
				candidates.append({"kind":"staff", "id":staff_id, "route":"Staff", "label":"Staff · %s · %s [%s]" % [str(person.get("name", "")), str(person.get("roleLabel", person.get("role", ""))), staff_id]})
		for team: Dictionary in app.model.get("international", {}).get("teams", []):
			candidates.append({"kind":"nation", "id":str(team.get("id", "")), "route":"Sélections", "label":"Sélection · %s [%s]" % [str(team.get("name", "")), str(team.get("id", ""))]})
		for league: Dictionary in app.model.get("leagues", []):
			candidates.append({"kind":"competition", "id":str(league.get("id", "")), "route":"Classements", "label":"Compétition · %s [%s]" % [str(league.get("name", "")), str(league.get("id", ""))]})
		var seen := {}
		for source in ["squad", "market"]:
			var people: Variant = app.model.get(source, [])
			if not people is Array: continue
			for person: Variant in people:
				if not person is Dictionary: continue
				var id := str(person.get("id", ""))
				if id.is_empty() or seen.has(id): continue
				seen[id] = true
				var context := "Effectif" if source == "squad" else "Marché"
				var label := "%s · %s · %s · %s [%s]" % [context, str(person.get("name", "Sans nom")), str(person.get("pos", "Poste non renseigné")), "dossier" if source == "squad" else "piste de recrutement", id]
				candidates.append({"kind":source, "id":id, "route":"Effectif" if source == "squad" else "Recrutement", "label":label})
	var total := 0
	for candidate: Dictionary in candidates:
		if not entity_available(candidate): continue
		if not needle.is_empty() and not U.fold(candidate.label).contains(needle): continue
		total += 1
		if _matches.size() >= RESULT_LIMIT: continue
		_matches.append(candidate)
		_results.add_item(candidate.label)
		_results.set_item_tooltip(_results.item_count - 1, candidate.label)
	if _results.item_count > 0: _results.select(0)
	_count.text = "Aucun résultat · essayez un autre nom ou menu." if total == 0 else "%d résultat(s)%s" % [total, " · les 12 premiers, précisez votre recherche" if total > RESULT_LIMIT else ""]
	_dialog.get_ok_button().disabled = total == 0

func _activate_selected() -> void:
	if not is_instance_valid(_dialog) or _blocked(_dialog): return
	var selected := _results.get_selected_items()
	if selected.is_empty(): return
	var entry: Dictionary = _matches[selected[0]].duplicate(true)
	if entry.kind == "squad":
		entry.kind = "player"
		entry.section = "roster"
	if not entity_available(entry):
		_refresh_results(_search.text)
		return
	# The palette is a reading-only popup. Its exact origin is retained on cancel.
	_dialog.hide()
	if not open_entity(entry): _refresh_results(_search.text)

func open_watched_roster() -> void:
	_open_roster_preset(U.WATCH_FILTER)

func open_roster_group() -> void:
	if app.roster_filter == U.WATCH_FILTER:
		_open_roster_preset("Tous")
	else:
		app._navigate("Effectif")

func _open_roster_preset(family: String) -> void:
	if _blocked() or not _allowed_route("Effectif"): return
	capture_current()
	U.remember(app)
	if cursor >= 0: _store_roster_reading(history[cursor])
	var state := U.defaults()
	state.family = family
	app.management_ui.roster = state
	app.management_ui.profile_scroll = 0
	app.roster_filter = family
	app.roster_sort = state.sort
	app.selected_player = ""
	app._navigate("Effectif", false)
	observe(app.route, app.selected_player, app.selected_staff_club, true)

func _person(source: String, id: String) -> Dictionary:
	var people: Variant = app.model.get(source, [])
	if people is Array:
		for person: Variant in people:
			if person is Dictionary and str(person.get("id", "")) == id: return person
	return {}

func _allowed_route(route: String) -> bool:
	if route == "Accueil": return true
	if not app._has_career(): return false
	if not app.Immersive.Selections.navigation_allowed(app.model, route): return false
	if route == "Sélections": return app.model.get("international") is Dictionary
	for chapter: Dictionary in app.NAV_CHAPTERS:
		if route in chapter.routes: return true
	return false

func _staff_club_exists(id: int) -> bool:
	var teams: Array = app.model.get("staff", {}).get("teams", [])
	return teams.any(func(team: Dictionary): return int(team.get("id", -1)) == id)

func _valid_entry(entry: Dictionary) -> bool:
	if not _allowed_route(entry.route): return false
	var target: Dictionary = entry.get("target", {})
	if not target.is_empty() and not entity_available(target): return false
	if not entry.player.is_empty() and _person("squad", entry.player).is_empty(): return false
	if not entry.market.is_empty() and _person("market", entry.market).is_empty(): return false
	if int(entry.staff) >= 0 and not _staff_club_exists(int(entry.staff)): return false
	return true

func _destination(direction: int) -> int:
	var next := cursor + direction
	while next >= 0 and next < history.size():
		if _valid_entry(history[next]): return next
		next += direction
	return -1

func _travel(direction: int) -> void:
	if _blocked(): return
	var next := _destination(direction)
	if next < 0: return
	capture_current()
	var entry: Dictionary = history[next]
	_restoring = true
	cursor = next
	if entry.get("reading") is Dictionary: U.apply_reading(app, entry.reading)
	if entry.route == "Effectif":
		app.selected_player = entry.player
		app.set_meta("immersive08_full_player", entry.get("full_player", false))
		app.management_ui.roster = entry.roster.duplicate(true)
		app.management_ui.profile_scroll = entry.profile_scroll
		app.roster_filter = entry.roster.family
		app.roster_sort = entry.roster.sort
	if entry.route == "Préparation" and app.management_ui.get("preparation") is Dictionary:
		app.management_ui.preparation.tab = entry.get("preparation_tab", 0)
	if entry.route == "Staff": app.selected_staff_club = int(entry.staff)
	if entry.route == "Recrutement" and not entry.get("reading") is Dictionary:
		_set_market_target(entry.market, str(_person("market", entry.market).get("name", "")))
	app._navigate(entry.route, false, true)
	_reading_revision += 1
	_restore_reading_controls(entry.get("reading", {}), _reading_revision)
	_restoring = false
	_refresh_controls()

func _blocked(ignore: Window = null, save_shortcut: bool = false) -> bool:
	if app == null or app.waiting or app.closing or app.connection_error: return true
	if not save_shortcut and is_instance_valid(app.contextual_director) and (app.contextual_director.active_meeting() or app.contextual_director.match_immersed()): return true
	if not app.last_error.is_empty():
		var retry: bool = save_shortcut and app.last_command=="save" and app.model.get("meta",{}).get("saveError",false)
		if not retry: return true
	return _has_popup(app, ignore)

func _has_popup(node: Node, ignore: Window) -> bool:
	for child in node.get_children():
		if child is Window and child != ignore and child.visible and not child.is_queued_for_deletion(): return true
		if _has_popup(child, ignore): return true
	return false

func _refresh_controls() -> void:
	if app == null: return
	var blocked := _blocked()
	if is_instance_valid(_back): _back.disabled = blocked or _destination(-1) < 0
	if is_instance_valid(_forward): _forward.disabled = blocked or _destination(1) < 0
	if is_instance_valid(_find): _find.disabled = blocked

# Compatibility entry point used by the existing roster and scouting screens.
func open_market_player(id: String) -> bool:
	if id.is_empty(): return open_entity({"kind":"menu", "route":"Recrutement"})
	return open_entity({"kind":"market", "id":id})

func _set_market_target(id: String, display_name: String) -> void:
	app.management_ui.market = U.defaults()
	app.management_ui.market.navigation_id = id
	app.management_ui.market.search = display_name
	if not id.is_empty(): app.management_ui.market_tab = 0

# Public, typed reading contract. IDs are checked against the current projection,
# never against a name, a row number or an engine command. Unknown kinds fail closed.
func entity_available(target: Dictionary) -> bool:
	if app == null: return false
	var kind := str(target.get("kind", ""))
	var id := str(target.get("id", ""))
	match kind:
		"menu":
			var route := str(target.get("route", ""))
			return route != "Presse" and _allowed_route(route)
		"player", "squad":
			return not id.is_empty() and ((_allowed_route("Effectif") and not _person("squad", id).is_empty()) or (_allowed_route("Recrutement") and not _person("market", id).is_empty()))
		"market":
			return not id.is_empty() and _allowed_route("Recrutement") and not _person("market", id).is_empty()
		"report":
			return _allowed_route("Recrutement") and app.Immersive.Recruitment.has_method("target_available") and app.Immersive.Recruitment.target_available(app, target.get("id"))
		"nation":
			return _allowed_route("Sélections") and app.Immersive.Selections.has_method("target_available") and app.Immersive.Selections.target_available(app, id)
		"staff":
			return _allowed_route("Staff") and app.StaffViews.has_method("target_available") and app.StaffViews.target_available(app, id)
		"club", "fixture", "competition", "date":
			var route := "Calendrier" if kind == "date" else "Classements"
			return _allowed_route(route) and app.Immersive.Competition.has_method("target_available") and app.Immersive.Competition.target_available(app, kind, target.get("id"))
		"finance":
			return _allowed_route("Finances") and app.Immersive.FinanceCanvas.has_method("target_available") and app.Immersive.FinanceCanvas.target_available(app, target.get("id"))
		"training":
			return id in ["", "team"] and _allowed_route("Préparation")
	return false

func _reading_source(source: Window) -> bool:
	return is_instance_valid(source) and not source.is_queued_for_deletion() and app.is_ancestor_of(source) and source.get_meta("navigation_read_only", false)

func open_entity(target: Dictionary, source_window: Window = null) -> bool:
	var source: Window = source_window if _reading_source(source_window) else null
	if _blocked(source) or not entity_available(target): return false
	capture_current()
	_reading_revision += 1
	_dispatching = true
	var kind := str(target.get("kind", ""))
	var id := str(target.get("id", ""))
	if kind in ["player", "squad"] and _person("squad", id).is_empty(): kind = "market"
	var destination := ""
	var opened := true
	match kind:
		"menu": destination = str(target.route)
		"player", "squad":
			destination = "Effectif"
			app.management_ui.roster = U.defaults()
			app.management_ui.profile_scroll = 0
			app.roster_filter = "Tous"
			app.roster_sort = "Poste"
			app.selected_player = id
			app.set_meta("immersive08_full_player", target.get("section", "") != "roster")
			app.management_ui.player_section = str(target.get("section", ""))
			if target.get("section", "") == "contract": app.management_ui.immersive_player_tab = 3
		"market":
			destination = "Recrutement"
			_set_market_target(id, str(_person("market", id).get("name", "")))
		"report":
			opened = app.Immersive.Recruitment.open_target(app, target.get("id"))
		"nation":
			destination = "Sélections"
			opened = app.Immersive.Selections.open_target(app, id)
		"staff":
			destination = "Staff"
			opened = app.StaffViews.open_target(app, id)
		"club", "fixture", "competition", "date":
			opened = app.Immersive.Competition.open_target(app, kind, target.get("id"))
			if opened and kind in ["competition", "date"]: destination = app.route
		"finance":
			opened = app.Immersive.FinanceCanvas.open_target(app, target.get("id"))
			if opened: destination = "Finances"
		"training":
			destination = "Préparation"
			app.Immersive.open_training(app)
	if opened and not destination.is_empty():
		var location := target.duplicate(true)
		location.route = destination
		app.management_ui.navigation_target = location
		if kind == "menu":
			app._navigate(destination, false)
		elif kind not in ["competition", "date", "finance", "training"]:
			app._navigate(destination, false, true)
		observe(app.route, app.selected_player, app.selected_staff_club, kind in ["player", "squad"])
	_dispatching = false
	if opened and is_instance_valid(source) and not source.is_queued_for_deletion(): source.queue_free()
	return opened

func _restore_reading_controls(reading: Dictionary, revision: int) -> void:
	var page: Control = app.root_content
	await get_tree().process_frame
	await get_tree().process_frame
	if revision != _reading_revision or not is_instance_valid(page) or page != app.root_content: return
	U.restore_reading_controls(app, page, reading)
