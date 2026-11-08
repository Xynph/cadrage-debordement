extends RefCounted
const G = preload("res://ui/carnet_skin.gd")

static func build(app: Control) -> Control:
	var page := G.v(12)
	page.name = "CarnetSupport"
	G.fill(page, true)
	var data: Dictionary = app.model.get("clubLife", {}).get("clubSupport", {})
	if data.is_empty():
		page.add_child(G.wrap("Créez une carrière pour réunir votre staff.", 18))
		return page
	var paper := G.panel(page)
	G.fill(paper.get_parent(), true)
	G.fill(paper, true)
	G.chapter(paper, "21", "Le travail de la semaine", "Staff · préparation · cellule médicale · mandats", app.accent)
	paper.add_child(G.wrap(data.notice, 12))
	var tabs := TabContainer.new()
	tabs.name = "SupportTabs"
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tabs.add_theme_color_override("font_selected_color", G.INK)
	tabs.add_theme_color_override("font_unselected_color", G.MUTED)
	tabs.add_theme_stylebox_override("tab_selected", G.T.box(G.PAPER, 2, G.LINE))
	tabs.add_theme_stylebox_override("tab_unselected", G.T.box(Color("e5dccb"), 2, G.LINE))
	G.fill(tabs, true)
	paper.add_child(tabs)
	_staff(tabs, app, data)
	_medical(tabs, app, data)
	_agents(tabs, app, data)
	return page

static func _name(app: Control, id: Variant) -> String:
	for p: Dictionary in app.model.get("squad", []):
		if p.id == id: return str(p.name)
	return str(id)

static func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var tab := G.v(12)
	tab.name = title
	tabs.add_child(tab)
	return G.scroll(tab)

static func _action(parent: Node, label: String, name: String, enabled: bool, callback: Callable) -> Button:
	var button := G.button(label, callback)
	button.name = name.replace(":", "_")
	button.disabled = not enabled
	parent.add_child(button)
	return button

static func _staff(tabs: TabContainer, app: Control, data: Dictionary) -> void:
	var list := _tab(tabs, "Staff")
	var d: Dictionary = data.diagnostic
	list.add_child(G.section("Le diagnostic", str(d.reason)))
	var health := G.h(18)
	list.add_child(health)
	G.gauge(health, "Condition moyenne", float(d.mean))
	G.gauge(health, "Moral du groupe", float(d.morale))
	G.gauge(health, "Confiance", float(d.trust), 100, G.GOLD)
	list.add_child(G.wrap("Condition moyenne %d / 100 · %d joueurs sous 65 · moral %d · confiance %d" % [d.mean, d.fatigue, d.morale, d.trust], 16))
	if data.meeting.receipt is Dictionary:
		list.add_child(G.wrap(str(data.meeting.receipt.title) + " — " + str(data.meeting.receipt.body), 16, G.GOOD))
	elif data.meeting.get("lastDecision") is Dictionary and not data.meeting.available:
		list.add_child(G.wrap("Dernière réunion conservée : " + str(data.meeting.lastDecision.plan) + ". Une seule réunion est possible par semaine et par club.", 14, G.GOOD))
	for option: Dictionary in data.meeting.options:
		var meeting := G.card(list, G.accent_ink(app.accent))
		meeting.add_child(G.section(option.label, option.detail))
		meeting.add_child(G.wrap("Prévision : %d joueurs concernés · moral %d · confiance %d" % [option.preview.affected, option.preview.morale, option.preview.trust], 14))
		_action(meeting, "RÉUNIR LE STAFF · " + str(option.label), "SupportMeeting_" + str(option.key), data.meeting.available, func(): app._command("staff_meeting", {"context":data.context,"plan":option.key}))
	list.add_child(G.separator())
	list.add_child(G.section("Répartir les charges", "Configurer un plan ne lance pas la séance. Les plans individuels restent visibles dans l’effectif."))
	for plan: Dictionary in data.training.plans:
		list.add_child(G.wrap(str(plan.label) + " — " + str(plan.detail), 17, G.INK))
		list.add_child(G.wrap("%d repos · %d séance normale · %d intensif · condition totale prévue %+.0f" % [plan.counts.repos, int(plan.counts.normal) + int(plan.counts.collective), plan.counts.intense, plan.conditionGain], 14))
		_action(list, "APPLIQUER · " + str(plan.label), "SupportTraining_" + str(plan.key), data.training.available, func(): app._command("training_plan", {"context":data.context,"plan":plan.key}))
	list.add_child(G.separator())
	list.add_child(G.section("Le briefing ciblé", "Ajustements fictifs du moteur, figés au coup d’envoi ; aucun résultat garanti."))
	var b: Dictionary = data.briefing
	if b.evidence is Dictionary:
		list.add_child(G.wrap("Écart avants %+.0f · passe/vitesse %+.0f · danger adverse %+.0f" % [b.evidence.pack, b.evidence.backs, b.evidence.danger], 16))
	for plan: Dictionary in b.plans:
		list.add_child(G.wrap(plan.desc, 14))
		var button := _action(list, str(plan.label), "SupportBriefing_" + str(plan.key), b.available, func(): app._command("strategic_briefing", {"context":data.context,"fixture":b.fixture,"plan":plan.key}))
		if plan.key == b.selected: G.selected(button, app.accent)

static func _medical(tabs: TabContainer, app: Control, data: Dictionary) -> void:
	var list := _tab(tabs, "Médical")
	list.add_child(G.section("Disponibilité et retour", "Suivi générique de jeu : les protocoles agissent à la prochaine séance. Aucune accélération de commotion ou de HIA n’est modélisée."))
	if data.medical.players.is_empty(): list.add_child(G.wrap("Aucun joueur à suivre actuellement.", 18))
	for p: Dictionary in data.medical.players:
		var identity: Dictionary = p
		for candidate: Dictionary in app.model.squad:
			if candidate.id == p.id: identity = candidate; break
		G.person(list, identity, _name(app, p.id), "Suivi médical · données de simulation", 48)
		list.add_child(G.section(_name(app, p.id), "%d semaine(s) d’indisponibilité · condition %.0f · charge %.0f" % [p.injury, p.condition, p.fatigue]))
		if p.injury > 0:
			var picker := OptionButton.new()
			picker.name = "MedicalProtocol_" + str(p.id).replace(":", "_")
			picker.custom_minimum_size.y = 44
			picker.disabled = not data.medical.available
			for protocol: Dictionary in data.medical.protocols:
				picker.add_item(protocol.label)
				picker.set_item_metadata(picker.item_count - 1, protocol.key)
				if protocol.key == p.protocol: picker.select(picker.item_count - 1)
			list.add_child(picker)
			var explanation := G.wrap(str(data.medical.protocols[picker.selected].description), 14)
			list.add_child(explanation)
			picker.item_selected.connect(func(index: int): explanation.text = str(data.medical.protocols[index].description))
			_action(list, "CONFIRMER LE SUIVI", "MedicalChoose_" + str(p.id), data.medical.available, func(): app._command("medical_protocol", {"context":data.context,"id":p.id,"protocol":picker.get_item_metadata(picker.selected)}))
		else:
			list.add_child(G.wrap("Reprise progressive : repos, condition +8, charge −12. Retour complet : condition −7, charge +12 et risque fictif de rechute.", 14))
			_action(list, "REPRISE PROGRESSIVE", "MedicalReturnProgressive_" + str(p.id), data.medical.available, func(): app._command("medical_return", {"context":data.context,"id":p.id,"choice":"progressif"}))
			_action(list, "RETOUR COMPLET À RISQUE", "MedicalReturnFull_" + str(p.id), data.medical.available, func(): app._command("medical_return", {"context":data.context,"id":p.id,"choice":"complet"}))
		list.add_child(G.separator())

static func _agents(tabs: TabContainer, app: Control, data: Dictionary) -> void:
	var list := _tab(tabs, "Agents")
	list.add_child(G.section("Préparer une prolongation", "Les représentants sont des archétypes fictifs. Trois propositions par semaine ; aucune prime débitée avant confirmation de signature."))
	if not data.agents.players.is_empty():
		var player := OptionButton.new()
		player.name = "AgentPlayer"
		player.custom_minimum_size.y = 44
		for p: Dictionary in data.agents.players: player.add_item(_name(app, p.id))
		list.add_child(player)
		var choices := G.v(12)
		list.add_child(choices)
		var redraw := func(index: int):
			for child in choices.get_children(): choices.remove_child(child); child.queue_free()
			var p: Dictionary = data.agents.players[index]
			for q: Dictionary in p.quotes:
				var policy: Dictionary = data.agents.policies.filter(func(item: Dictionary): return item.key == q.policy)[0]
				var quote := G.card(choices, G.GOLD)
				quote.add_child(G.section(str(policy.label) + " · " + str(int(q.years)) + " saison(s)", policy.detail))
				var amounts := G.h(16)
				quote.add_child(amounts)
				amounts.add_child(G.metric(G.euros(q.wage), "par semaine"))
				amounts.add_child(G.metric(G.euros(q.fee), "prime à la signature"))
				quote.add_child(G.wrap("Engagement théorique %s sur %d semaines × %d saison(s)" % [G.euros(q.totalCommitment), q.paidWeeks, q.years], 15))
				quote.add_child(G.wrap(str(q.likely) + " · " + str(int(q.attempts)) + "/3 tentative(s)", 13))
				_action(quote, "ENVOYER LA PROPOSITION", "AgentPropose_" + str(int(q.years)) + "_" + str(q.policy), q.affordable and q.attempts < 3 and app._live().is_empty(), func(): app._command("agent_negotiate", {"context":data.context,"id":q.id,"years":q.years,"policy":q.policy}))
		player.item_selected.connect(redraw)
		redraw.call(0)
	else: list.add_child(G.wrap("Aucune prolongation possible actuellement.", 16))
	list.add_child(G.separator())
	list.add_child(G.section("Accords à confirmer"))
	for talk: Dictionary in data.agents.talks:
		list.add_child(G.wrap(_name(app, talk.id) + " — " + str(talk.message), 16))
		if talk.status in ["ready", "counter"]:
			_action(list, "EXAMINER LA SIGNATURE", "AgentConfirm_" + str(talk.id), app._live().is_empty(), func(): _confirm(app, data, talk))
	list.add_child(G.separator())
	list.add_child(G.section("Les derniers mandats", "Historique persistant limité à 24 entrées."))
	for h: Dictionary in data.agents.history:
		var status: String = {"ready":"accord de principe", "counter":"contre-offre", "withdrawn":"retrait", "signed":"signé"}.get(str(h.status), str(h.status))
		list.add_child(G.wrap("S%d · semaine %d · %s · %s / sem. · %s" % [h.season, int(h.week) + 1, _name(app, h.id), G.euros(h.wage), status], 14))

static func _confirm(app: Control, data: Dictionary, talk: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name = "AgentSignatureDialog"
	dialog.title = "Confirmer la prolongation"
	dialog.get_ok_button().text = "Signer la prolongation"
	dialog.get_cancel_button().text = "Annuler"
	var paid_weeks: int = 34 if int(app.model.meta.get("clubCount", 0)) == 30 else 29
	for p: Dictionary in data.agents.players:
		if p.id == talk.id and not p.quotes.is_empty(): paid_weeks = int(p.quotes[0].paidWeeks)
	dialog.dialog_text = "%s\nPrime immédiate : %s\nSalaire : %s / semaine · %d saison(s)\nEngagement théorique : %s (%d semaines payées par saison).\nTrésorerie fictive du jeu." % [_name(app, talk.id), G.euros(talk.fee), G.euros(talk.acceptedSalary), talk.years, G.euros(talk.acceptedSalary * paid_weeks * talk.years + talk.fee), paid_weeks]
	dialog.confirmed.connect(func(): app._command("agent_confirm", {"context":data.context,"key":talk.key,"confirmed":true,"wage":talk.acceptedSalary,"years":talk.years,"fee":talk.fee}); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	app.add_child(dialog)
	dialog.popup_centered(Vector2i(580, 260))
