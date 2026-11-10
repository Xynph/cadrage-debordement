extends RefCounted
## Read-only planning: confirmed call-ups and announced windows remain distinct.
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")

static func data(model: Dictionary) -> Dictionary:
	return model.get("international", {}).get("availability", {})

static func _date(value: Variant) -> String:
	return P.fixture_date({"date":value}) if value is String and not value.is_empty() else "—"

static func open(app: Control) -> void:
	app.management_ui.international_section = "availability"
	app._navigate("Sélections")

static func _player(app: Control, id: String) -> void:
	app.selected_player = id
	app._navigate("Effectif")

static func calendar_summary(app: Control) -> Control:
	var state := data(app.model)
	var card := C.card()
	card.name = "InternationalAvailabilitySummary"
	var content := C.content(card)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", C.px(18))
	flow.add_theme_constant_override("v_separation", C.px(8))
	content.add_child(flow)
	var count := int(state.get("absentCount", 0))
	var title := "%d joueur%s en sélection" % [count, "s" if count != 1 else ""]
	if count == 0: title = "Anticiper les fenêtres internationales"
	flow.add_child(C.label(title, 25, C.GOLD, true, 700))
	var detail := "Convocations confirmées · retour prévu à partir du " + _date(state.get("nextReturn")) if count > 0 else "Aucun absent confirmé aujourd’hui. Les prochaines fenêtres sont consultables."
	flow.add_child(C.wrap(detail, 18, C.MUTED))
	var action := C.button("Préparer les absences →", open.bind(app))
	action.name = "InternationalAvailabilityOpen"
	flow.add_child(action)
	return card

static func _metric(parent: Node, title: String, value: String, color: Color) -> void:
	var card := C.card()
	card.custom_minimum_size.x = C.px(205)
	parent.add_child(card)
	var content := C.content(card)
	content.add_child(C.label(title, 17, C.MUTED, false))
	content.add_child(C.label(value, 32, color, true, 700))

static func _person(app: Control, parent: Node, player: Dictionary, returned: bool = false) -> void:
	var card := C.card()
	card.name = "InternationalAbsence_" + str(player.id).replace(":", "_")
	parent.add_child(card)
	var content := C.content(card)
	var heading := C.h(12)
	content.add_child(heading)
	var identity := C.v(4)
	C.fill(identity)
	heading.add_child(identity)
	identity.add_child(C.wrap(player.name, 25, C.IVORY, true, 700))
	identity.add_child(C.wrap("%s · %s" % [player.pos, player.nationName], 18, C.MUTED))
	var button := C.button("Voir la fiche", _player.bind(app, str(player.id)))
	button.name = "InternationalAbsencePlayer_" + str(player.id).replace(":", "_")
	heading.add_child(button)
	content.add_child(C.wrap(player.competitionName, 19, C.GOLD))
	if returned:
		content.add_child(C.wrap("De retour au club depuis le " + _date(player.returnDate), 20, C.MINT))
		content.add_child(C.wrap("Consultez la fiche pour vérifier sa condition et ses éventuelles blessures.", 17, C.MUTED))
	else:
		content.add_child(C.wrap("Absent du %s au %s inclus" % [_date(player.from), _date(player.through)], 20, C.IVORY))
		content.add_child(C.wrap("Retour au club prévu le " + _date(player.returnDate), 20, C.MINT))

static func build(app: Control) -> Control:
	var view := C.v(14)
	view.name = "Disponibilités"
	var state := data(app.model)
	if state.is_empty():
		view.add_child(C.wrap("Le suivi des disponibilités sera affiché à la prochaine actualisation de la carrière.", 22))
		return view
	view.add_child(C.label("ANTICIPER LES ABSENCES", 25, C.GOLD, true, 700))
	view.add_child(C.wrap("Les convocations sont confirmées. Les fenêtres à venir ne préjugent pas des joueurs qui seront retenus.", 20, C.MUTED))
	var metrics := HFlowContainer.new()
	metrics.add_theme_constant_override("h_separation", C.px(12))
	metrics.add_theme_constant_override("v_separation", C.px(8))
	view.add_child(metrics)
	if state.get("clubManaged", false):
		_metric(metrics, "Joueurs du club en sélection", str(int(state.get("absentCount", 0))), C.GOLD)
		_metric(metrics, "Prochain retour au club", _date(state.get("nextReturn")), C.MINT)
		_metric(metrics, "Postes principaux concernés", str(state.get("positions", []).size()), C.IVORY)
		if int(state.get("absentCount", 0)) == 0:
			view.add_child(C.wrap("Aucun joueur de votre club n’est actuellement convoqué.", 22, C.MINT))
		else:
			view.add_child(C.label("Vos joueurs convoqués", 25, C.IVORY, true, 700))
			for player: Dictionary in state.get("players", []): _person(app, view, player)
			view.add_child(C.wrap("Les retours restent prévisionnels : le parcours dans une compétition peut prolonger une convocation.", 18, C.MUTED))
			var coverage := C.card("POSTES À PRÉPARER")
			coverage.name = "InternationalPositionCoverage"
			view.add_child(coverage)
			var list := C.content(coverage)
			for position: Dictionary in state.get("positions", []):
				var color := C.GOLD if int(position.available) == 0 else C.MINT
				list.add_child(C.wrap("%s · %d au club non blessé(s) / %d · %d en sélection" % [position.position, position.available, position.total, position.called], 21, color))
				var bar := ProgressBar.new()
				bar.max_value = maxi(1, int(position.total))
				bar.value = int(position.available)
				bar.show_percentage = false
				bar.custom_minimum_size.y = C.px(8)
				list.add_child(bar)
			list.add_child(C.wrap("Repère par poste principal : blessures et suspensions écartées. Les polyvalences et la validité de la feuille se vérifient en composition.", 17, C.MUTED))
			var prepare := C.button("Adapter ma composition →", func(): app._navigate("Composition"), true)
			prepare.name = "InternationalAvailabilityLineup"
			list.add_child(prepare)
		if not state.get("returned", []).is_empty():
			view.add_child(C.label("Retours des sept derniers jours", 25, C.IVORY, true, 700))
			for player: Dictionary in state.returned: _person(app, view, player, true)
	else:
		view.add_child(C.wrap("Votre mandat porte sur la sélection seule. Le suivi de l’effectif d’un club ne s’applique pas.", 21, C.MUTED))
	view.add_child(C.label("Prochaines fenêtres · 90 jours", 25, C.IVORY, true, 700))
	if state.get("windows", []).is_empty():
		view.add_child(C.wrap("Aucune nouvelle fenêtre annoncée d’ici le " + _date(state.get("horizonDate")) + ".", 21, C.MUTED))
	for window: Dictionary in state.get("windows", []):
		var card := C.card()
		view.add_child(card)
		var content := C.content(card)
		content.add_child(C.wrap(window.competitionName, 23, C.GOLD, true, 700))
		content.add_child(C.wrap("Du %s au %s" % [_date(window.from), _date(window.through)], 21, C.IVORY))
		var nations := PackedStringArray()
		for nation: Dictionary in window.nations: nations.append(nation.name)
		content.add_child(C.wrap(" · ".join(nations), 18, C.MUTED))
		content.add_child(C.wrap("Convocations non encore connues : préparez vos solutions de remplacement.", 18, C.MINT))
	return view
