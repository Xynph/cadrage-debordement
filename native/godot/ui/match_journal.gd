extends VBoxContainer
# Read-only journal. Categories use captureMatchAction().kind, never prose.
const U = preload("res://ui/management_state.gd")
const G = preload("res://ui/carnet_skin.gd")
const CATEGORIES = ["Tous", "Scores", "Discipline", "Changements", "Conquête"]
const KINDS = {
	"message":"Jeu courant", "carry":"Progression", "turnover":"Récupération",
	"scrum":"Mêlée", "lineout":"Touche", "setpiece-win":"Ballon conservé",
	"setpiece-loss":"Ballon récupéré", "kick":"Jeu au pied", "kickoff":"Renvoi au centre",
	"drop22":"Renvoi aux 22", "goalLine":"Renvoi sur la ligne", "reception":"Réception",
	"touch":"Sortie en touche", "hand-fault":"Faute de main", "try":"Essai",
	"goal":"Pénalité réussie", "miss":"Tir manqué", "penalty":"Pénalité",
	"advantage":"Avantage", "card":"Discipline", "sub":"Remplacement",
	"tactic":"Consigne", "break":"Mi-temps", "end":"Fin du match", "ingoal":"En-but"
}
var app: Control
var category: OptionButton
var search: LineEdit
var count: Label
var new_events: Label
var latest: Button
var scroll: ScrollContainer
var rows: VBoxContainer
var empty: Label
var visible_events: Array = []
var _live: Dictionary = {}
var _events: Array = []
var _signature := ""
var _seen := 0
var _unread := 0
var _following := true
var _updating := false
var _revision := 0
var _started := false
var _ui_state: Dictionary = {}

func setup(owner_app: Control) -> void:
	app = owner_app
	_ui_state = app.management_ui
	name = "MatchJournal"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	var fields := G.h(6)
	add_child(fields)
	category = OptionButton.new()
	category.name = "MatchJournalCategory"
	category.tooltip_text = "Filtrer les faits structurés du moteur"
	category.custom_minimum_size = Vector2(112, 34)
	category.fit_to_longest_item = false
	for state in ["normal", "hover", "pressed", "disabled"]:
		category.add_theme_stylebox_override(state, G.T.box(Color("ddd1bc") if state in ["hover", "pressed"] else Color("e8dfce"), 3, G.LINE))
	var category_focus := G.T.box(Color.TRANSPARENT, 3, G.GOLD)
	category_focus.set_border_width_all(2)
	category.add_theme_stylebox_override("focus", category_focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		category.add_theme_color_override(state, G.INK)
	for text in CATEGORIES: category.add_item(text)
	category.select(clampi(int(app.management_ui.get("match_journal_category", 0)), 0, CATEGORIES.size() - 1))
	fields.add_child(category)
	_compact_control(category)
	search = LineEdit.new()
	search.name = "MatchJournalSearch"
	search.placeholder_text = "Rechercher dans le texte…"
	search.tooltip_text = "Recherche dans le texte exact, sans distinction d’accents ni de casse"
	search.custom_minimum_size = Vector2(100, 34)
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.add_theme_color_override("font_color", G.INK)
	search.add_theme_color_override("font_placeholder_color", G.MUTED)
	search.add_theme_color_override("font_selected_color", G.WHITE)
	search.add_theme_color_override("selection_color", G.INK)
	search.add_theme_color_override("caret_color", G.INK)
	search.add_theme_stylebox_override("normal", G.T.box(Color("faf6ed"), 3, G.LINE))
	var search_focus := G.T.box(Color.TRANSPARENT, 3, G.GOLD)
	search_focus.set_border_width_all(2)
	search.add_theme_stylebox_override("focus", search_focus)
	search.text = str(app.management_ui.get("match_journal_search", ""))
	search.caret_column = int(app.management_ui.get("match_journal_caret", search.text.length()))
	fields.add_child(search)
	_compact_control(search)
	var navigation := G.h(6)
	add_child(navigation)
	var status := G.v(0)
	G.fill(status)
	navigation.add_child(status)
	count = G.label("", 12, G.MUTED)
	status.add_child(count)
	new_events = G.wrap("", 12, G.GOLD)
	status.add_child(new_events)
	latest = G.button("DERNIER ÉVÉNEMENT ↓", _latest)
	latest.custom_minimum_size.y = 32
	latest.add_theme_font_size_override("font_size", 12)
	latest.name = "MatchJournalLatest"
	latest.tooltip_text = "Rejoindre le dernier fait correspondant aux filtres et suivre les prochains"
	navigation.add_child(latest)
	_compact_control(latest)
	scroll = ScrollContainer.new()
	scroll.name = "MatchJournalScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Search and filters keep keyboard focus without pulling the history to them.
	scroll.follow_focus = false
	scroll.focus_mode = Control.FOCUS_ALL
	add_child(scroll)
	rows = G.v(7)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	empty = G.wrap("", 14, G.MUTED)
	add_child(empty)
	_following = bool(app.management_ui.get("match_journal_follow", true))
	category.item_selected.connect(func(_index: int): _filter_changed())
	search.text_changed.connect(func(_text: String): _filter_changed())
	scroll.get_v_scroll_bar().value_changed.connect(_scrolled)

func _exit_tree() -> void:
	_store()

func _store() -> void:
	if not is_instance_valid(app) or search == null or not is_same(_ui_state, app.management_ui): return
	app.management_ui["match_journal_category"] = category.selected
	app.management_ui["match_journal_search"] = search.text
	app.management_ui["match_journal_caret"] = search.caret_column
	app.management_ui["match_journal_scroll"] = scroll.scroll_vertical
	app.management_ui["match_journal_follow"] = _following

static func _compact_control(control: Control) -> void:
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		if not control.has_theme_stylebox(key): continue
		var style: StyleBox = control.get_theme_stylebox(key).duplicate()
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		style.content_margin_left = 8
		style.content_margin_right = 8
		control.add_theme_stylebox_override(key, style)

func _bind_current_context() -> void:
	_ui_state = app.management_ui
	_revision += 1
	_started = false
	_signature = ""
	_seen = 0
	_unread = 0
	_events = []
	category.select(int(_ui_state.get("match_journal_category", 0)))
	search.text = str(_ui_state.get("match_journal_search", ""))
	search.caret_column = int(_ui_state.get("match_journal_caret", 0))
	_following = bool(_ui_state.get("match_journal_follow", true))

func _scrolled(_value: float) -> void:
	if _updating or not is_visible_in_tree(): return
	_following = _at_bottom()
	if _following: _unread = 0
	_notice()
	_store()

func _at_bottom() -> bool:
	var bar := scroll.get_v_scroll_bar()
	return float(scroll.scroll_vertical) >= bar.max_value - bar.page - 2

func update_frame(live: Dictionary) -> void:
	if not is_same(_ui_state, app.management_ui): _bind_current_context()
	_live = live
	var value: Array = live.get("events", []) if live.get("events") is Array else []
	var signature := JSON.stringify([value, live.get("teams", [])])
	if signature == _signature and _started: return
	var extends_history := _started and value.size() >= _seen
	if extends_history:
		for index in _seen:
			if value[index] != _events[index]:
				extends_history = false
				break
	var added := value.size() - _seen if extends_history else 0
	if not extends_history: _unread = 0
	_seen = value.size()
	_events = value
	_signature = signature
	if not _following: _unread += added
	var old_scroll: int = scroll.scroll_vertical if _started else int(app.management_ui.get("match_journal_scroll", 0))
	_started = true
	_render(old_scroll, _following)

func _filter_changed() -> void:
	# Explicit filter changes start their result list at the top.
	_following = false
	_render(0, false)
	_store()

static func _fold(value: String) -> String:
	return U.fold(value)

static func _number(value: Variant) -> String:
	if (value is int or value is float) and float(value) == floorf(float(value)): return str(int(value))
	return str(value)

static func _kind(event: Variant) -> String:
	if event is Dictionary and event.get("scene") is Dictionary:
		return str(event.scene.get("kind", ""))
	return ""

func _matches(event: Variant) -> bool:
	var kind := _kind(event)
	match category.selected:
		1:
			if kind not in ["try", "goal"]: return false
		2:
			if kind not in ["card", "penalty", "advantage", "hand-fault"]: return false
		3:
			if kind != "sub": return false
		4:
			if kind not in ["scrum", "lineout", "setpiece-win", "setpiece-loss"]: return false
	var text := str(event.get("text", "Texte non renseigné")) if event is Dictionary else str(event)
	var query := _fold(search.text.strip_edges())
	return query.is_empty() or _fold(text).contains(query)

func _render(position: int, follow: bool) -> void:
	_updating = true
	_revision += 1
	var revision := _revision
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	visible_events = []
	for event in _events:
		if not _matches(event): continue
		visible_events.append(event)
		var entry := G.v(3)
		entry.name = "JournalEvent%d" % (visible_events.size() - 1)
		rows.add_child(entry)
		var kind := _kind(event)
		var minute := "Minute non renseignée"
		if event is Dictionary and (event.get("min") is int or event.get("min") is float): minute = _number(event.min) + " min"
		var caption: String = KINDS.get(kind, "Type non renseigné" if kind.is_empty() else "Type inconnu (« %s »)" % kind)
		entry.add_child(G.wrap(minute + " · " + caption, 13, G.GOLD))
		entry.add_child(G.wrap(str(event.get("text", "Texte non renseigné")) if event is Dictionary else str(event), 14, G.INK))
		if event is Dictionary and event.get("scene") is Dictionary:
			var scene: Dictionary = event.scene
			var facts: Array[String] = []
			if scene.has("period"): facts.append("Période " + _number(scene.period))
			var team: Variant = scene.get("team")
			var teams: Array = _live.get("teams", [])
			if (team is int or team is float) and float(team) in [0.0, 1.0] and int(team) < teams.size():
				facts.append(G.club_name(teams[int(team)]))
			else: facts.append("Équipe non renseignée")
			if scene.get("score") is Array and scene.score.size() == 2:
				facts.append("Score %s — %s" % [_number(scene.score[0]), _number(scene.score[1])])
			if not facts.is_empty(): entry.add_child(G.wrap(" · ".join(facts), 12, G.MUTED))
		entry.add_child(G.separator())
	count.text = "%d / %d faits" % [visible_events.size(), _events.size()]
	empty.visible = visible_events.is_empty()
	empty.text = "Aucun événement pour ces filtres." if not _events.is_empty() else "Le journal se remplira après le coup d’envoi."
	latest.disabled = visible_events.is_empty()
	_notice()
	_restore.call_deferred(position, follow, revision)

func _restore(position: int, follow: bool, revision: int) -> void:
	# Containers lay out after deferred calls; wait for their real scrollbar range.
	await get_tree().process_frame
	await get_tree().process_frame
	if revision != _revision: return
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value) if follow else position
	_following = follow
	_updating = false
	_store()

func _notice() -> void:
	new_events.visible = _unread > 0
	count.visible = _unread == 0
	new_events.text = "%d nouveau%s fait%s" % [_unread, "" if _unread == 1 else "x", "" if _unread == 1 else "s"]
	new_events.tooltip_text = "Dernier événement rejoint les faits filtrés et reprend leur suivi."

func _latest() -> void:
	_unread = 0
	_following = true
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	_notice()
	_store()
