extends RefCounted
const Copy = preload("res://ui/management_copy.gd")
const G = preload("res://ui/carnet_skin.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const Charte = preload("res://ui/charte.gd")

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
	paper.add_child(G.wrap(Copy.notice("playbook", data.notice), 13))
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
		_selector(app, card, "TON CHOIX", str(phase.key), phase.options, str(phase.selected), available)

static func _advice(app: Control, parent: Container, data: Dictionary, available: bool) -> void:
	if not data.inMatch or not data.staffAdvice is Dictionary:
		# Avant le match : la lecture arrive au coup d'envoi ; d'ici là, zones et phases arrêtées se préparent (un clic y mène).
		var attente := _rangee(parent)
		attente.name = "PlaybookAdviceAttente"
		attente.add_child(Pastilles.pastille("Pendant le match", Pastilles.BLEU, "clock", "La lecture du rapport de force apparaîtra pendant le match ; ajustable en pause.", 20, "PlaybookAdvicePendant"))
		attente.add_child(Pastilles.pastille("Zones", Pastilles.VERT, "flag", "Préparer les quatre zones", 20, "PlaybookAdviceZones", func(): _onglet(app, 0)))
		attente.add_child(Pastilles.pastille("Phases arrêtées", Pastilles.VERT, "ball", "Préparer les phases arrêtées", 20, "PlaybookAdvicePhases", func(): _onglet(app, 1)))
		# Ce qui est prêt pour le coup d'envoi : une tuile par zone (attaque appliquée) et par phase arrêtée.
		var zones := _rangee(parent)
		zones.name = "PlaybookAdvicePretZones"
		for zone: Dictionary in data.get("zones", []):
			zones.add_child(Pastilles.tuile(_libelle(data.get("attackOptions", []), str(zone.get("effectiveAttack", ""))), str(zone.get("label", "")), Pastilles.VERT if zone.get("attack") != "inherit" else Charte.IVOIRE, Charte.PANNEAU_2, 24, "PlaybookAdvicePret_" + str(zone.get("id", "")), false, func(): _onglet(app, 0)))
		var phases := _rangee(parent)
		phases.name = "PlaybookAdvicePretPhases"
		for phase: Dictionary in data.get("setPieces", []):
			phases.add_child(Pastilles.tuile(_libelle(phase.get("options", []), str(phase.get("selected", ""))), str(phase.get("label", "")), Charte.IVOIRE, Charte.PANNEAU_2, 24, "PlaybookAdvicePret_" + str(phase.get("key", "")), false, func(): _onglet(app, 1)))
		return
	var advice: Dictionary = data.staffAdvice
	var card := G.panel(parent)
	var tete := _rangee(card)
	tete.add_child(G.label("Ce que voit l’adjoint", 19, G.INK, true))
	tete.add_child(Pastilles.info("Un conseil de situation, jamais un changement automatique.", "i", "PlaybookAdviceInfo"))
	# Rapport de force : tuiles chiffrées et pastilles (score, météo, exclusions).
	var terrain := _rangee(card)
	terrain.name = "PlaybookAdviceTerrain"
	if advice.has("ours") and advice.has("theirs"):
		var ecart := int(advice.ours) - int(advice.theirs)
		terrain.add_child(Pastilles.tuile("%d / %d" % [int(advice.ours), int(advice.theirs)], "joueurs sur le terrain", Pastilles.VERT if ecart > 0 else Pastilles.ROUGE if ecart < 0 else Charte.IVOIRE, Charte.PANNEAU_2, 30, "PlaybookAdviceJoueurs"))
	if advice.has("remaining"): terrain.add_child(Pastilles.tuile(str(int(advice.remaining)), "min restantes", Pastilles.TURQUOISE, Charte.PANNEAU_2, 30, "PlaybookAdviceMinutes"))
	var etats := _rangee(card)
	var score := str(advice.get("scoreNote", ""))
	if not score.is_empty(): etats.add_child(Pastilles.pastille(score.left(1).to_upper() + score.substr(1), Pastilles.BLEU, "trophy", "", 18, "PlaybookAdviceScore"))
	if not str(advice.get("weather", "")).is_empty(): etats.add_child(Pastilles.pastille(str(advice.weather), Charte.IVOIRE_2, "cloud", "", 18, "PlaybookAdviceMeteo"))
	if not str(advice.get("clockNote", "")).is_empty(): etats.add_child(Pastilles.pastille(_exclusion(str(advice.clockNote)), Pastilles.ORANGE, "clock", str(advice.clockNote), 18, "PlaybookAdviceExclusion"))
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
		var conseil := _rangee(card)
		var attaque: bool = suggestion.kind == "attack"
		conseil.add_child(Pastilles.pastille(("Attaque · " if attaque else "Défense · ") + label, Pastilles.VERT if attaque else Pastilles.BLEU, "tactic" if attaque else "shield", str(suggestion.get("reason", "")), 19, "PlaybookAdviceConseil_" + str(suggestion.kind)))
		for zone: Dictionary in data.zones:
			if zone[suggestion.kind] == "inherit" or zone[suggestion.kind] == suggestion.value: continue
			var button := G.button("ADAPTER « %s » → %s" % [zone.label, label], func(): _choose(app, str(suggestion.kind), str(suggestion.value), str(zone.id), true))
			button.disabled = not available
			card.add_child(button)
	if suggestions.is_empty(): card.add_child(Pastilles.pastille("Plan conforme", Pastilles.VERT, "check", "Aucune consigne supplémentaire recommandée pour l’instant.", 19, "PlaybookAdviceConforme"))

## « Carton jaune : fin d'exclusion dans 4 minute(s)… » → « Jaune · 4 min » ; la phrase complète reste en infobulle.
static func _exclusion(note: String) -> String:
	var minutes := RegEx.create_from_string("(\\d+) minute").search(note)
	var duree := (" · %s min" % minutes.get_string(1)) if minutes != null else ""
	if note.begins_with("Carton jaune"): return "Jaune" + duree
	if note.begins_with("Rouge remplaçable"): return "Rouge remplaçable" + duree
	if note.begins_with("Rouge définitif"): return "Rouge définitif"
	return note

static func _libelle(options: Array, id: String) -> String:
	for option: Dictionary in options:
		if str(option.get("id", "")) == id: return str(option.get("label", id))
	return "—"

static func _onglet(app: Control, index: int) -> void:
	app.management_ui.playbook_tab = index
	var onglets := app.find_child("PlaybookTabs", true, false) as TabContainer
	if onglets != null: onglets.current_tab = index

static func _rangee(parent: Node) -> HFlowContainer:
	var rangee := HFlowContainer.new()
	rangee.add_theme_constant_override("h_separation", 10)
	rangee.add_theme_constant_override("v_separation", 8)
	parent.add_child(rangee)
	return rangee
