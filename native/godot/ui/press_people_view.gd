extends RefCounted
# A notebook of simulated personalities, with neutral initials rather than invented press photos.
const G = preload("res://ui/carnet_skin.gd")

static func badge(person: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(58, 58)
	frame.add_theme_stylebox_override("panel", G.T.box(G.LINE, 29, G.MUTED))
	frame.tooltip_text = "Repère graphique par initiales · aucune photographie"
	var initials := ""
	for word: String in str(person.get("name", "?")).split(" ", false):
		if initials.length() < 2: initials += word.left(1)
	var text := G.label(initials.to_upper(), 21, G.INK, true)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(text)
	return frame

static func build(app: Control, data: Dictionary = {}) -> Control:
	var model: Dictionary = data if not data.is_empty() else app.model.get("clubLife", {}).get("press", {})
	var page := G.v(10)
	page.name = "Relations"
	G.fill(page, true)
	page.add_child(G.wrap("Vos relations avec les journalistes vous suivent au fil de votre carrière.", 12))
	var people: Array = model.get("people", [])
	if people.is_empty():
		page.add_child(G.wrap("Aucun journaliste disponible.", 16))
		return page
	var chooser := OptionButton.new()
	chooser.name = "PressPersonPicker"
	chooser.custom_minimum_size.y = 44
	chooser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for person: Dictionary in people:
		chooser.add_item("%s · %s · %d échange(s)" % [person.name, person.outlet, person.encounters])
	page.add_child(chooser)
	var detail := G.scroll(page)
	detail.name = "PressPeopleMemory"
	var redraw := func(index: int):
		for child in detail.get_children(): detail.remove_child(child); child.queue_free()
		var person: Dictionary = people[index]
		var header := G.h(12)
		detail.add_child(header)
		header.add_child(badge(person))
		var identity := G.section(str(person.name), str(person.outlet))
		G.fill(identity)
		header.add_child(identity)
		detail.add_child(G.wrap("Style d’entretien : %s · %s" % [person.styleLabel, person.personality], 13, G.INK))
		var specialties: Array[String] = []
		for topic: String in person.specialties:
			if not specialties.has(topic.replace("_", " ")): specialties.append(topic.replace("_", " "))
		detail.add_child(G.wrap("Spécialités : " + ", ".join(specialties), 13))
		if person.has("source"):
			var source := LinkButton.new()
			source.text = "Source publique de l’identité référencée"
			source.uri = str(person.source)
			source.add_theme_color_override("font_color", G.GOLD)
			source.add_theme_color_override("font_focus_color", G.INK)
			detail.add_child(source)
		detail.add_child(G.separator())
		detail.add_child(G.wrap("%s · relation %+.0f / 100 · %d échange(s)" % [person.relationLabel, person.score, person.encounters], 13, G.INK))
		detail.add_child(G.wrap("De −100 à +100. L’accueil dépend du style du journaliste, du ton et du sujet.", 12))
		if person.memory.is_empty():
			detail.add_child(G.wrap("Aucun échange individuel conservé. Les anciennes conférences sans identité ne créent pas de souvenir.", 13))
		else:
			detail.add_child(G.section("Les trois derniers échanges"))
			var memory: Array = person.memory.duplicate()
			memory.reverse()
			for exchange: Dictionary in memory:
				var club_name := "Club non identifié dans le monde actuel"
				for league: Dictionary in app.model.get("leagues", []):
					for club: Dictionary in league.get("rows", []):
						if int(club.id) == int(exchange.club): club_name = str(club.name)
				detail.add_child(G.wrap("Saison %d · semaine %d · %s\n%s · relation %+.0f" % [exchange.season, int(exchange.week) + 1, club_name, exchange.toneLabel, exchange.delta], 12, G.GOLD))
				detail.add_child(G.wrap(str(exchange.question) if exchange.question != null else "Question d’origine non conservée.", 13, G.INK))
				detail.add_child(G.wrap(str(exchange.answer) if exchange.answer != null else "Réponse d’origine non conservée · choix " + str(exchange.answerId), 12))
				detail.add_child(G.separator())
	chooser.item_selected.connect(redraw)
	var first := 0
	for index in people.size():
		if int(people[index].encounters) > 0: first = index; break
	chooser.select(first)
	redraw.call(first)
	return page
