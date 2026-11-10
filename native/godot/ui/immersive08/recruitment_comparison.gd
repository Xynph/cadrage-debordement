extends RefCounted
## Consultation seulement : les valeurs proviennent de la projection courante.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/decision_views.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const U = preload("res://ui/management_state.gd")
const A = preload("res://ui/player_attributes.gd")
const G = preload("res://ui/game_skin.gd")

static func numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func delta(left: Variant, right: Variant, unit: String = "") -> String:
	if not numeric(left) or not numeric(right): return "Non comparable"
	var difference := float(right) - float(left)
	return ("+" if difference > 0 else "") + A.caption(snappedf(difference, 0.1)) + unit

static func value(player: Dictionary, key: String, reports: Dictionary) -> Variant:
	if key == "potential": return reports.get(str(player.get("id", "")), {}).get("potential")
	if key.begins_with("attribute:"): return A.detail(player).get(key.trim_prefix("attribute:"))
	return player.get(key)

static func initial_ids(players: Array, chosen: String, saved: Array) -> Array[String]:
	var ids: Array[String] = []
	for player: Dictionary in players: ids.append(str(player.id))
	var left := chosen if chosen in ids else str(saved[0]) if saved.size() > 0 and str(saved[0]) in ids else ids[0] if not ids.is_empty() else ""
	var right := str(saved[1]) if saved.size() > 1 and str(saved[1]) in ids and str(saved[1]) != left else ""
	var position := ""
	for player: Dictionary in players:
		if str(player.id) == left: position = str(player.get("pos", ""))
	if right.is_empty():
		for player: Dictionary in players:
			if str(player.id) != left and str(player.get("pos", "")) == position:
				right = str(player.id)
				break
	if right.is_empty():
		for id in ids:
			if id != left: right = id; break
	return [left, right]

static func candidates(players: Array, query: String, position: String, chosen: Array) -> Array:
	var term := U.fold(query).strip_edges()
	return players.filter(func(player: Dictionary):
		if str(player.id) in chosen: return true
		return (position.is_empty() or player.get("pos") == position) and (term.is_empty() or U.fold(str(player.get("name", "")) + " " + str(player.get("pos", ""))).contains(term)))

static func open(app: Control, chosen: String, reports: Dictionary) -> void:
	var players: Array = app.model.get("market", [])
	var width := mini(1120, maxi(620, int(app.get_viewport_rect().size.x) - 48))
	var view := D.dialog(app, "Comparer deux pistes", "MarketComparison", width)
	var dialog: AcceptDialog = view[0]
	var content: VBoxContainer = view[1]
	var state: Dictionary = app.management_ui.market
	var selected := initial_ids(players, chosen, state.get("comparison_ids", []))
	state.comparison_ids = selected.duplicate()
	content.add_child(C.wrap("Comparer avant de décider. Écart B − A : positif signifie une valeur plus élevée pour B, sans jugement automatique sur l’âge ou le coût.", 21, C.IVORY))
	var filters := C.h(12)
	content.add_child(filters)
	var search := LineEdit.new()
	search.name = "MarketComparisonSearch"
	search.placeholder_text = "Chercher un nom ou un poste…"
	search.accessibility_name = "Chercher les candidats à comparer"
	search.clear_button_enabled = true
	C.fill(search)
	filters.add_child(search)
	var same_position := CheckButton.new()
	same_position.name = "MarketComparisonSamePosition"
	same_position.text = "Même poste que A"
	same_position.accessibility_name = same_position.text
	filters.add_child(same_position)
	var choices := C.h(12)
	content.add_child(choices)
	var picks: Array[OptionButton] = []
	for slot in 2:
		var column := C.v(5)
		C.fill(column)
		choices.add_child(column)
		column.add_child(C.label("PISTE " + ["A", "B"][slot], 23, C.GOLD))
		var picker := OptionButton.new()
		picker.name = "MarketComparisonPlayer" + str(slot)
		picker.accessibility_name = "Choisir la piste " + ["A", "B"][slot]
		picker.fit_to_longest_item = false
		picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		C.fill(picker)
		column.add_child(picker)
		picks.append(picker)
	var count := C.wrap("", 18)
	count.name = "MarketComparisonCount"
	content.add_child(count)
	var detail := C.v(10)
	detail.name = "MarketComparisonDetails"
	content.add_child(detail)
	var redraw := func():
		_clear(detail)
		state.comparison_ids = selected.duplicate()
		var pair: Array[Dictionary] = [{}, {}]
		for slot in 2:
			for player: Dictionary in players:
				if str(player.id) == selected[slot]: pair[slot] = player; break
		if pair[0].is_empty() or pair[1].is_empty():
			detail.add_child(C.wrap("Choisissez deux pistes pour consulter leurs différences. Les profils indisponibles restent consultables.", 22))
			return
		if selected[0] == selected[1]:
			detail.add_child(C.wrap("Sélectionnez deux pistes distinctes.", 23, C.ALERT))
			return
		_cards(detail, pair, reports)
		var tabs := TabContainer.new()
		tabs.name = "MarketComparisonTabs"
		detail.add_child(tabs)
		var overview := C.v(7)
		overview.name = "Vue d’ensemble"
		tabs.add_child(overview)
		_header(overview)
		for field in [["Poste", "pos", ""], ["Âge", "age", " ans"], ["Niveau / 100", "rating", ""], ["Potentiel observé / 100", "potential", ""], ["Condition", "condition", " %"], ["Prime à la signature", "fee", " €"], ["Salaire demandé / semaine", "salary", " €"]]:
			_row(overview, str(field[0]), str(field[1]), pair, reports, str(field[2]))
		overview.add_child(C.wrap("Prime et salaire hebdomadaire sont des demandes distinctes. Aucun contrat n’est signé depuis cette comparaison. Le potentiel provient des rapports datés ; une donnée absente n’est pas remplacée par une estimation.", 18))
		var attributes := C.v(7)
		attributes.name = "36 attributs"
		tabs.add_child(attributes)
		attributes.add_child(C.wrap("Notes de simulation sur 100. Le même attribut peut avoir une importance différente selon le poste.", 19))
		for group in A.GROUPS:
			attributes.add_child(C.label(str(group[0]).to_upper(), 23, C.GOLD))
			_header(attributes)
			for field in group[1]: _row(attributes, str(field[1]), "attribute:" + str(field[0]), pair, reports)
	var refresh_pickers := func():
		var position := ""
		if same_position.button_pressed:
			for player: Dictionary in players:
				if str(player.id) == selected[0]: position = str(player.get("pos", ""))
		var filtered := candidates(players, search.text, position, selected)
		count.text = "%d pistes proposées · les deux choix restent visibles · indisponibles consultables" % filtered.size()
		for slot in 2:
			picks[slot].clear()
			picks[slot].add_item("Choisir une piste")
			picks[slot].set_item_metadata(0, "")
			for player: Dictionary in filtered:
				picks[slot].add_item(str(player.name) + " · " + str(player.pos) + (" · indisponible" if not player.get("available", false) else ""))
				var index := picks[slot].item_count - 1
				picks[slot].set_item_metadata(index, str(player.id))
				picks[slot].set_item_tooltip(index, picks[slot].get_item_text(index))
				if str(player.id) == selected[slot]: picks[slot].select(index)
	for slot in 2:
		picks[slot].item_selected.connect(func(index: int):
			selected[slot] = str(picks[slot].get_item_metadata(index))
			refresh_pickers.call()
			redraw.call())
	search.text_changed.connect(func(_text: String): refresh_pickers.call())
	same_position.toggled.connect(func(_pressed: bool): refresh_pickers.call())
	refresh_pickers.call()
	redraw.call()
	dialog.canceled.connect(func(): _restore_focus(app))
	dialog.confirmed.connect(func(): _restore_focus(app))
	Dialogs.show_centered(dialog, Vector2i(width, mini(760, int(app.get_viewport_rect().size.y) - 78)))
	picks[1].grab_focus.call_deferred()

static func _restore_focus(app: Control) -> void:
	var button := app.find_child("CompareMarket", true, false) as Button
	if button != null: button.grab_focus.call_deferred()

static func _cards(parent: Node, pair: Array[Dictionary], reports: Dictionary) -> void:
	var cards := C.h(12)
	parent.add_child(cards)
	for slot in 2:
		var panel := PanelContainer.new()
		panel.name = "MarketComparisonCard" + str(slot)
		panel.add_theme_stylebox_override("panel", C.box(C.RAISED, C.MINT if slot == 0 else C.GOLD, 8, 12))
		C.fill(panel)
		cards.add_child(panel)
		var body := C.v(6)
		panel.add_child(body)
		var player: Dictionary = pair[slot]
		body.add_child(C.wrap(["A · ", "B · "][slot] + str(player.get("name", "—")), 25, C.IVORY, true, 700))
		var available := bool(player.get("available", false))
		var status := C.wrap("Offre possible" if available else "Offre indisponible · " + str(player.get("reason", "Motif non communiqué")), 19, C.MINT if available else C.ALERT)
		status.name = "MarketComparisonAvailability" + str(slot)
		body.add_child(status)
		var report: Dictionary = reports.get(str(player.get("id", "")), {})
		body.add_child(C.wrap(str(report.get("assessment", {}).get("source", "Aucun rapport daté")), 18, C.GOLD))

static func _header(parent: Node) -> void:
	var row := C.h(12)
	parent.add_child(row)
	for title in ["REPÈRE", "A", "B", "ÉCART B − A"]:
		var label := C.label(title, 19, C.GOLD)
		C.fill(label)
		row.add_child(label)

static func _row(parent: Node, title: String, key: String, pair: Array[Dictionary], reports: Dictionary, unit: String = "") -> void:
	var row := C.h(12)
	row.name = "MarketComparisonRow_" + key.replace(":", "_")
	parent.add_child(row)
	var label := C.wrap(title, 20)
	C.fill(label)
	row.add_child(label)
	var values: Array = []
	for player: Dictionary in pair:
		var datum: Variant = value(player, key, reports)
		values.append(datum)
		var caption := "Non communiqué" if datum == null else G.euros(datum) if key in ["fee", "salary"] and numeric(datum) else A.caption(datum) + unit if numeric(datum) else str(datum)
		var text := C.wrap(caption, 20, C.IVORY, true)
		C.fill(text)
		row.add_child(text)
	var difference := C.wrap(delta(values[0], values[1], unit) if key != "pos" else "Même poste" if values[0] == values[1] else "Postes différents", 20, C.GOLD, true)
	difference.name = "MarketComparisonDelta_" + key.replace(":", "_")
	C.fill(difference)
	row.add_child(difference)

static func _clear(node: Node) -> void:
	for child in node.get_children(): node.remove_child(child); child.queue_free()
