extends RefCounted
const G = preload("res://ui/carnet_skin.gd")

static func _choose(app: Control, key: String, value: String, zone: String = "", staff: bool = false) -> void:
	var payload := {"context":app.model.clubLife.playbook.context.duplicate(true), "key":key, "value":value}
	if not zone.is_empty(): payload.zone = zone
	app._command("playbook_staff_zone" if staff else "playbook_set", payload)

static func _tab(parent: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var content := G.v(14)
	G.fill(content)
	scroll.add_child(content)
	return content

static func _selector(app: Control, parent: Container, title: String, key: String, options: Array, selected: String, available: bool, zone: String = "") -> void:
	parent.add_child(G.label(title, 12, G.MUTED))
	var select := OptionButton.new()
	select.name = "Playbook_" + zone + "_" + key
	select.custom_minimum_size.y = 42
	select.fit_to_longest_item = false
	select.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for option: Dictionary in options:
		select.add_item(str(option.label))
		select.set_item_metadata(select.item_count - 1, str(option.id))
		if option.id == selected: select.select(select.item_count - 1)
	select.disabled = not available
	select.item_selected.connect(func(index: int): _choose(app, key, str(select.get_item_metadata(index)), zone))
	parent.add_child(select)
	for option: Dictionary in options:
		if option.id == selected: parent.add_child(G.wrap(str(option.description), 12))

static func build(app: Control) -> Control:
	var page := G.v(14)
	page.name = "CarnetPlansDeJeu"
	G.fill(page, true)
	var data: Dictionary = app.model.get("clubLife", {}).get("playbook", {})
	var paper := G.panel(page)
	G.fill(paper.get_parent(), true)
	G.fill(paper, true)
	G.chapter(paper, "05", "Un plan pour chaque terrain.", "Quatre zones et des phases arrêtées préparées.", app.accent)
	if data.get("zones", []).is_empty():
		paper.add_child(G.wrap(str(data.get("reason", "Ce carnet sera disponible après création d’une carrière.")), 16))
		return page
	paper.add_child(G.wrap(str(data.notice), 13))
	var plans := G.h(20)
	paper.add_child(plans)
	plans.add_child(G.metric(str(data.general.attackLabel), "ATTAQUE PRINCIPALE"))
	plans.add_child(G.metric(str(data.general.defenceLabel), "DÉFENSE PRINCIPALE"))
	var available: bool = data.available and not app.waiting
	if not available: paper.add_child(G.wrap(str(data.reason), 13, G.ALERT))
	var tabs := TabContainer.new()
	tabs.name = "PlaybookTabs"
	tabs.custom_minimum_size.y = 340
	G.fill(tabs, true)
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tabs.add_theme_stylebox_override("tab_selected", G.T.box(G.PAPER, 2, G.LINE))
	tabs.add_theme_stylebox_override("tab_unselected", G.T.box(Color("e5dccb"), 2, G.LINE))
	tabs.add_theme_color_override("font_selected_color", G.INK)
	tabs.add_theme_color_override("font_unselected_color", G.MUTED)
	paper.add_child(tabs)
	var zones := _tab(tabs, "Les quatre zones")
	var phases := _tab(tabs, "Phases arrêtées")
	var advice := _tab(tabs, "Lecture du match")
	_zones(app, zones, data, available)
	_phases(app, phases, data, available)
	_advice(app, advice, data, available)
	tabs.current_tab = clampi(int(app.management_ui.get("playbook_tab", 0)), 0, 2)
	tabs.tab_changed.connect(func(index: int): app.management_ui.playbook_tab = index)
	return page

static func _zones(app: Control, parent: Container, data: Dictionary, available: bool) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	parent.add_child(grid)
	for zone: Dictionary in data.zones:
		var card := G.panel(grid)
		card.add_child(G.section(str(zone.label), "ZONE ACTUELLE" if data.currentZone == zone.id else "La priorité locale s’applique ici."))
		_selector(app, card, "ATTAQUE", "attack", data.attackOptions, str(zone.attack), available, str(zone.id))
		_selector(app, card, "DÉFENSE", "defence", data.defenceOptions, str(zone.defence), available, str(zone.id))
		card.add_child(G.wrap("Suit le plan principal." if zone.attack == "inherit" and zone.defence == "inherit" else "Une consigne locale remplace le plan principal dans cette zone.", 12, G.GOLD))

static func _phases(app: Control, parent: Container, data: Dictionary, available: bool) -> void:
	for phase: Dictionary in data.setPieces:
		var card := G.panel(parent)
		card.add_child(G.section(str(phase.label), "Un compromis entre conservation, territoire et prise de risque."))
		_selector(app, card, "VOTRE CHOIX", str(phase.key), phase.options, str(phase.selected), available)

static func _advice(app: Control, parent: Container, data: Dictionary, available: bool) -> void:
	if not data.inMatch or not data.staffAdvice is Dictionary:
		parent.add_child(G.wrap("La lecture du rapport de force apparaîtra pendant le match. Préparez d’abord vos zones et vos phases arrêtées ; vous pourrez les ajuster en pause.", 17))
		return
	var advice: Dictionary = data.staffAdvice
	var card := G.panel(parent)
	card.add_child(G.section("Ce que voit l’adjoint", "Un conseil de situation, jamais un changement automatique."))
	for field: String in ["scoreNote", "clockNote"]:
		if not str(advice.get(field, "")).is_empty(): card.add_child(G.wrap(str(advice[field]), 15))
	var suggestions: Array = []
	var seen: Dictionary = {}
	for suggestion: Dictionary in advice.get("suggestions", []) + advice.get("zoneSuggestions", []):
		var key := str(suggestion.kind) + ":" + str(suggestion.value)
		if seen.has(key): continue
		seen[key] = true
		suggestions.append(suggestion)
	for suggestion: Dictionary in suggestions.slice(0, 3):
		var options: Array = data.attackOptions if suggestion.kind == "attack" else data.defenceOptions
		var label := str(suggestion.value)
		for option: Dictionary in options:
			if option.id == suggestion.value: label = str(option.label)
		card.add_child(G.label(("Attaque : " if suggestion.kind == "attack" else "Défense : ") + label, 19, G.INK, true))
		for zone: Dictionary in data.zones:
			if zone[suggestion.kind] == "inherit" or zone[suggestion.kind] == suggestion.value: continue
			var button := G.button("ADAPTER « %s » → %s" % [zone.label, label], func(): _choose(app, str(suggestion.kind), str(suggestion.value), str(zone.id), true))
			button.disabled = not available
			card.add_child(button)
	if suggestions.is_empty(): card.add_child(G.wrap("Aucune consigne supplémentaire recommandée pour l’instant. Gardez votre lecture du terrain.", 15))
