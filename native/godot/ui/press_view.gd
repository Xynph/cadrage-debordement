extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const People = preload("res://ui/press_people_view.gd")

static func build(app: Control) -> Control:
	var page := G.v(12)
	page.name = "CarnetPresse"
	G.fill(page, true)
	var data: Dictionary = app.model.get("clubLife", {}).get("press", {})
	if data.is_empty():
		page.add_child(G.wrap("Le journal sera disponible après création d’une carrière.", 18))
		return page
	var paper := G.panel(page)
	G.fill(paper.get_parent(), true)
	G.fill(paper, true)
	G.chapter(paper, "18", "Troisième Mi-Temps", "Journal et conférences · saison %d · semaine %d" % [data.context.season, int(data.context.week) + 1], app.accent)
	paper.add_child(G.wrap(data.notice, 12))
	var metrics: Dictionary = data.metrics
	var indicators := G.h(20)
	paper.add_child(indicators)
	for item in [["Moral", metrics.morale], ["Direction", metrics.trust], ["Médias", metrics.mediaTrust], ["Supporters", metrics.fanTrust], ["Pression", metrics.boardPressure]]:
		G.gauge(indicators, item[0], float(item[1]), 100, G.GOLD if item[0] == "Pression" else G.GOOD)
	var tabs := TabContainer.new()
	tabs.name = "PressTabs"
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tabs.add_theme_stylebox_override("tab_selected", G.T.box(G.PAPER, 2, G.LINE))
	tabs.add_theme_stylebox_override("tab_unselected", G.T.box(Color("e5dccb"), 2, G.LINE))
	tabs.add_theme_color_override("font_selected_color", G.INK)
	tabs.add_theme_color_override("font_unselected_color", G.MUTED)
	G.fill(tabs, true)
	paper.add_child(tabs)
	_journal(tabs, app, data)
	_conference(tabs, app, data)
	_history(tabs, app, data)
	tabs.add_child(People.build(app, data))
	return page

static func _club(app: Control, id: Variant) -> String:
	for division: Dictionary in app.model.get("leagues", []):
		for row: Dictionary in division.get("rows", []):
			if int(row.id) == int(id): return str(row.get("name", "Club %s" % id))
	return "Club %s" % id

static func _journal(tabs: TabContainer, app: Control, data: Dictionary) -> void:
	var tab := G.v(12)
	tab.name = "Journal"
	tabs.add_child(tab)
	var divisions: Array = data.journal.divisions
	var chooser := OptionButton.new()
	chooser.name = "PressDivision"
	chooser.custom_minimum_size.y = 44
	for division: Dictionary in divisions: chooser.add_item(division.label)
	tab.add_child(chooser)
	var list := G.scroll(tab)
	var redraw := func(index: int):
		for child in list.get_children(): list.remove_child(child); child.queue_free()
		if divisions.is_empty(): list.add_child(G.wrap("Aucun fait sportif enregistré.", 13)); return
		var division: Dictionary = divisions[index]
		var columns := G.h(20)
		list.add_child(columns)
		var news := G.v(14)
		G.fill(news)
		columns.add_child(news)
		var ranking := G.v(10)
		G.fill(ranking)
		columns.add_child(ranking)
		G.photo_note(news, app.model.club, "Le journal de votre carrière", "Les faits du terrain", "stadium", 170)
		news.add_child(G.section("Les résultats conservés"))
		if division.results.is_empty(): news.add_child(G.wrap("Aucun résultat enregistré dans cette division. Le premier coup d’envoi ouvrira le journal.", 12))
		for result: Dictionary in division.results:
			news.add_child(G.wrap("%s   %d – %d   %s" % [_club(app, result.clubIds[0]), result.score[0], result.score[1], _club(app, result.clubIds[1])], 15, G.INK))
			var phase: String = {"league":"championnat", "barrage":"barrage", "semi":"demi-finale", "final":"finale", "access":"barrage d’accession"}.get(str(result.phase), "compétition")
			news.add_child(G.label("Saison %d · semaine %d · %s" % [result.season, int(result.week) + 1, phase], 12, G.MUTED))
			news.add_child(G.separator())
		ranking.add_child(G.section("Le classement actuel"))
		for standing: Dictionary in division.standings:
			var row := G.h(14)
			ranking.add_child(row)
			row.add_child(G.cell("%02d" % standing.rank, 38, G.GOLD))
			row.add_child(G.cell(_club(app, standing.clubId), 130, G.INK, true))
			row.add_child(G.cell("%d J" % standing.played, 35, G.MUTED))
			row.add_child(G.cell("%d pts" % standing.points, 48, G.INK))
			ranking.add_child(G.separator())
		if not division.injuries.is_empty():
			list.add_child(G.separator())
			list.add_child(G.section("Indisponibilités enregistrées"))
		for injury: Dictionary in division.injuries:
			var identity := str(injury.get("playerName", injury.playerId))
			for player: Dictionary in app.model.get("squad", []):
				if player.id == injury.playerId: identity = player.name
			list.add_child(G.wrap("%s · %s · %d semaine(s)" % [identity, _club(app, injury.clubId), injury.weeks], 12))
	chooser.item_selected.connect(redraw)
	redraw.call(0)
	for index in divisions.size():
		if divisions[index].id == app.model.meta.get("leagueId", "historical"): chooser.select(index); redraw.call(index); break

static func _conference(tabs: TabContainer, app: Control, data: Dictionary) -> void:
	var tab := G.v(12)
	tab.name = "Conférence"
	tabs.add_child(tab)
	var list := G.scroll(tab)
	var outcome: Variant = data.get("lastOutcome")
	if outcome is Dictionary:
		list.add_child(G.section("Retour de la dernière conférence"))
		var delta: Dictionary = outcome.delta
		list.add_child(G.wrap("Moral %+.0f · confiance %+.0f · opinion médias %+.0f · supporters %+.0f · pression %+.0f" % [delta.morale, delta.trust, delta.mediaTrust, delta.fanTrust, delta.boardPressure], 13, G.GOOD))
		list.add_child(G.label("Saison %d · semaine %d" % [outcome.context.season, int(outcome.context.week) + 1], 12))
		var exchanges: Array = outcome.get("exchanges", [])
		if not exchanges.is_empty():
			var feedback := G.v(4)
			feedback.name = "PressRelationshipOutcome"
			list.add_child(feedback)
			for exchange: Dictionary in exchanges:
				var identity := str(exchange.journalistId)
				for person: Dictionary in data.get("people", []):
					if person.id == exchange.journalistId: identity = person.name; break
				feedback.add_child(G.wrap("%s · relation %+.0f → %+.0f (%+.0f)" % [identity, exchange.before, exchange.after, exchange.delta], 12, G.GOOD if float(exchange.delta) >= 0 else G.ALERT))
		list.add_child(G.separator())
	var conference: Dictionary = data.conference
	if not conference.available:
		list.add_child(G.wrap(conference.reason, 13, G.INK))
		return
	list.add_child(G.wrap("Cinq tons. Tabulation pour parcourir les choix, Espace pour sélectionner. Publier valide toutes vos réponses.", 12, G.INK))
	var memory_notice := G.wrap(conference.get("memoryNotice", ""), 12)
	memory_notice.name = "PressMemoryNotice"
	list.add_child(memory_notice)
	var draft_key := "%d:%d:%d" % [data.context.season, data.context.week, data.context.club]
	if app.get_meta("press_draft_context", "") != draft_key:
		app.set_meta("press_draft_context", draft_key)
		app.set_meta("press_draft_choices", {})
	# This reversible draft belongs only to the UI, never to the saved career.
	var choices: Dictionary = app.get_meta("press_draft_choices", {})
	var current_ids: Array = []
	for question: Dictionary in conference.questions: current_ids.append(question.id)
	for id: Variant in choices.keys():
		if not current_ids.has(id): choices.erase(id)
	for question: Dictionary in conference.questions:
		var valid := false
		for answer: Dictionary in question.answers:
			if choices.get(question.id, "") == answer.id: valid = true
		if not valid: choices.erase(question.id)
	var submit := G.button("PUBLIER MES RÉPONSES", func():
		var answers: Array = []
		for question: Dictionary in conference.questions: answers.append({"questionId":question.id, "answerId":choices[question.id]})
		app._command("press_conference", {"context":data.context, "answers":answers}), true)
	submit.name = "PressSubmit"
	submit.disabled = choices.size() != conference.questions.size()
	for question: Dictionary in conference.questions:
		var interview := G.card(list, G.accent_ink(app.accent))
		interview.add_child(G.label("QUESTION %02d" % (conference.questions.find(question) + 1), 12, G.GOLD))
		var heading := G.h(12)
		interview.add_child(heading)
		heading.add_child(People.badge(question.journalist))
		var identity := G.v(3)
		G.fill(identity)
		heading.add_child(identity)
		identity.add_child(G.wrap(str(question.journalist.name), 18, G.INK))
		var provenance := G.wrap(str(question.journalist.outlet) + " · " + str(question.journalist.identityLabel), 12)
		provenance.name = "PressIdentity_" + str(question.id)
		identity.add_child(provenance)
		interview.add_child(G.wrap("Style d’entretien : %s · %s" % [question.journalist.styleLabel, question.journalist.personality], 12))
		var relation := G.wrap("%s · relation %+.0f / 100 · %d échange(s) avec vous" % [question.relation.label, question.relation.score, question.relation.encounters], 12, G.GOLD)
		relation.name = "PressRelation_" + str(question.id)
		interview.add_child(relation)
		if question.get("followUp") is Dictionary:
			var source := G.wrap(str(question.followUp.get("label", "Déclaration archivée dans cette carrière")), 12, G.GOLD)
			source.name = "PressFollowUp_" + str(question.id)
			interview.add_child(source)
		interview.add_child(G.wrap(question.question, 13, G.INK))
		var group := ButtonGroup.new()
		for answer: Dictionary in question.answers:
			var caption := "%s · %s\n%s" % [str(answer.toneLabel).to_upper(), answer.text, answer.consequence]
			var option := G.button(caption, func():
				choices[question.id] = answer.id
				submit.disabled = choices.size() != conference.questions.size())
			option.name = "PressAnswer_" + str(question.id) + "_" + str(answer.id)
			option.add_theme_font_size_override("font_size", 12)
			option.toggle_mode = true
			option.button_group = group
			option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			option.alignment = HORIZONTAL_ALIGNMENT_LEFT
			option.custom_minimum_size.y = 60
			option.tooltip_text = answer.consequence
			option.button_pressed = choices.get(question.id, "") == answer.id
			interview.add_child(option)
	list.add_child(submit)

static func _history(tabs: TabContainer, app: Control, data: Dictionary) -> void:
	var tab := G.v(12)
	tab.name = "Historique"
	tabs.add_child(tab)
	var list := G.scroll(tab)
	if data.history.is_empty(): list.add_child(G.wrap("Vous n’avez encore publié aucune conférence.", 13))
	var rows: Array = data.history.duplicate()
	rows.reverse()
	for row: Dictionary in rows:
		list.add_child(G.label("Saison %d · semaine %d%s" % [row.season, int(row.week) + 1, " · " + _club(app, row.club) if row.has("club") else ""], 12, G.GOLD))
		if row.has("journalist"):
			list.add_child(G.wrap("%s · %s" % [row.journalist.name, row.journalist.outlet], 12, G.GOLD))
		else:
			list.add_child(G.wrap("Identité du journaliste non conservée dans cette ancienne conférence.", 12))
		list.add_child(G.wrap(row.question if row.question != null else "Question d’origine non conservée dans cette ancienne conférence.", 13, G.INK))
		list.add_child(G.wrap(row.answer if row.answer != null else "Texte de la réponse non conservé · choix enregistré : " + str(row.answerId), 12))
		list.add_child(G.separator())
