extends Node
# Session-only reading history. This controller never calls the engine bridge.
const U = preload("res://ui/management_state.gd")
const G = preload("res://ui/carnet_skin.gd")
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

func setup(owner_app: Control) -> void:
	app = owner_app
	name = "NavigationController"
	set_process_input(true)
	app.get_viewport().size_changed.connect(func(): call_deferred("_fit_palette"))

func reset() -> void:
	history.clear()
	cursor = -1
	if is_instance_valid(_dialog): _dialog.hide()
	_refresh_controls()

func observe(route: String, player_id: String = "", staff_club: int = -1) -> void:
	if app == null or _restoring or not _allowed_route(route):
		_refresh_controls()
		return
	var entry := {"route":route, "player":player_id if route == "Effectif" else "", "staff":staff_club if route == "Staff" else -1, "market":""}
	if route == "Recrutement": entry.market = str(app.management_ui.get("market", {}).get("navigation_id", ""))
	if cursor >= 0 and history[cursor] == entry:
		_refresh_controls()
		return
	history = history.slice(0, cursor + 1)
	history.append(entry)
	if history.size() > HISTORY_LIMIT: history.pop_front()
	cursor = history.size() - 1
	_refresh_controls()

func controls() -> Control:
	var row := G.h(5)
	row.name = "NavigationControls"
	_back = _small_button("←", "Précédent · Alt + gauche", "NavigationBack", func(): _travel(-1))
	_forward = _small_button("→", "Suivant · Alt + droite", "NavigationForward", func(): _travel(1))
	_find = _small_button("Chercher", "Rechercher un menu ou un joueur · Ctrl + K", "NavigationOpen", open_palette)
	_find.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_back); row.add_child(_forward); row.add_child(_find)
	_refresh_controls()
	return row

func _small_button(text: String, tooltip: String, id: String, action: Callable) -> Button:
	var button := G.button(text, action)
	button.name = id
	button.tooltip_text = tooltip
	button.accessibility_name = tooltip
	button.custom_minimum_size = Vector2(29, 34)
	button.add_theme_font_size_override("font_size", 12)
	return button

func _input(event: InputEvent) -> void:
	if handle_shortcut(event): get_viewport().set_input_as_handled()

func handle_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo or app == null: return false
	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if is_instance_valid(_dialog) and _dialog.visible:
		if code == KEY_ESCAPE:
			_dialog.hide()
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
	if _blocked(): return false
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
	if not is_instance_valid(_dialog) or _dialog.is_queued_for_deletion(): _build_palette()
	_search.clear()
	_refresh_results("")
	var viewport := app.get_viewport_rect().size
	_dialog.popup_centered(Vector2i(mini(680, int(viewport.x) - 48), mini(520, int(viewport.y) - 64)))
	call_deferred("_fit_palette")
	_search.grab_focus()

func _fit_palette() -> void:
	if not is_instance_valid(_dialog) or not _dialog.visible: return
	# Wrapping labels can briefly report their height before the first layout.
	# AcceptDialog keeps that enlarged size even after their minimum has settled.
	var viewport := app.get_viewport_rect().size
	_dialog.size = Vector2i(mini(680, int(viewport.x) - 48), mini(520, int(viewport.y) - 64))
	_dialog.position = (app.get_window().size - _dialog.size) / 2

func _build_palette() -> void:
	_dialog = AcceptDialog.new()
	_dialog.name = "NavigationPalette"
	app._prepare_dialog(_dialog, mini(680, int(app.get_viewport_rect().size.x) - 48))
	_dialog.title = "Votre carnet · accès rapide"
	_dialog.get_ok_button().text = "OUVRIR"
	var content := G.v(10)
	content.custom_minimum_size.x = 620
	_dialog.add_child(content)
	content.add_child(G.wrap("Menus et joueurs · ↑ ↓ choisir · Entrée ouvrir · Échap fermer", 13))
	_search = LineEdit.new()
	_search.name = "NavigationSearch"
	_search.placeholder_text = "Rechercher un menu, un nom ou un poste…"
	_search.accessibility_name = "Rechercher un menu ou un joueur"
	_search.add_theme_color_override("font_placeholder_color", G.MUTED)
	_search.custom_minimum_size.y = 38
	content.add_child(_search)
	_results = ItemList.new()
	_results.name = "NavigationResults"
	_results.custom_minimum_size = Vector2(0, 310)
	_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results.add_theme_font_size_override("font_size", 14)
	_results.add_theme_constant_override("v_separation", 8)
	_results.add_theme_color_override("font_color", G.INK)
	_results.add_theme_stylebox_override("panel", G.T.box(G.PAPER, 3, G.LINE))
	_results.add_theme_stylebox_override("selected", G.T.box(Color("dcd0bb"), 3, G.GOLD))
	_results.add_theme_stylebox_override("selected_focus", G.T.box(Color("dcd0bb"), 3, G.GOLD))
	_results.add_theme_color_override("font_selected_color", G.INK)
	content.add_child(_results)
	_count = G.label("", 12, G.MUTED)
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
	var entry: Dictionary = _matches[selected[0]]
	if not _allowed_route(entry.route): return
	if entry.kind == "squad":
		if _person("squad", entry.id).is_empty():
			_refresh_results(_search.text); return
		app.management_ui.roster = U.defaults()
		app.roster_filter = "Tous"; app.roster_sort = "Poste"
		app.selected_player = entry.id
	elif entry.kind == "market":
		var person := _person("market", entry.id)
		if person.is_empty():
			_refresh_results(_search.text); return
		app.management_ui.market = U.defaults()
		app.management_ui.market.navigation_id = entry.id
		app.management_ui.market.search = str(person.get("name", ""))
	_dialog.hide()
	app._navigate(entry.route)
	observe(app.route, app.selected_player, app.selected_staff_club)

func _person(source: String, id: String) -> Dictionary:
	var people: Variant = app.model.get(source, [])
	if people is Array:
		for person: Variant in people:
			if person is Dictionary and str(person.get("id", "")) == id: return person
	return {}

func _allowed_route(route: String) -> bool:
	if route == "Accueil": return true
	if not app._has_career(): return false
	for chapter: Dictionary in app.NAV_CHAPTERS:
		if route in chapter.routes: return true
	return false

func _valid_entry(entry: Dictionary) -> bool:
	if not _allowed_route(entry.route): return false
	if not entry.player.is_empty() and _person("squad", entry.player).is_empty(): return false
	if not entry.market.is_empty() and _person("market", entry.market).is_empty(): return false
	if int(entry.staff) >= 0:
		var teams: Array = app.model.get("staff", {}).get("teams", [])
		if not teams.any(func(team: Dictionary): return int(team.get("id", -1)) == int(entry.staff)): return false
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
	var entry: Dictionary = history[next]
	_restoring = true
	cursor = next
	if entry.route == "Effectif":
		app.selected_player = entry.player
		app.management_ui.roster = U.defaults()
		app.roster_filter = "Tous"; app.roster_sort = "Poste"
	if entry.route == "Staff": app.selected_staff_club = int(entry.staff)
	if entry.route == "Recrutement":
		app.management_ui.market = U.defaults()
		app.management_ui.market.navigation_id = entry.market
		if not entry.market.is_empty(): app.management_ui.market.search = str(_person("market", entry.market).get("name", ""))
	app._navigate(entry.route)
	_restoring = false
	_refresh_controls()

func _blocked(ignore: Window = null) -> bool:
	if app == null or app.waiting or app.closing or app.connection_error or not app.last_error.is_empty(): return true
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
