extends RefCounted
const G = preload("res://ui/carnet_skin.gd")

static func dossier_summary(app: Control, parent: Container) -> void:
	var data: Variant = app.model.get("decisions", {}).get("preparation")
	if not data is Dictionary: return
	var card := G.panel(parent)
	var row := G.h(16)
	card.add_child(row)
	var title := G.section("Préparer " + str(data.opponent.name), "Projection du XV adverse · une aide, pas une feuille confirmée")
	G.fill(title)
	row.add_child(title)
	var open := G.button("LIRE LE DOSSIER →", func(): dossier(app))
	open.name = "OpenOppositionDossier"
	row.add_child(open)
	var metrics := G.h(18)
	card.add_child(metrics)
	for sector: Dictionary in data.get("domains", []):
		var c := G.v(1)
		G.fill(c)
		metrics.add_child(c)
		c.add_child(G.label("%s / %s" % [G.n(sector.own), G.n(sector.opponent)], 24, G.GOOD if sector.own >= sector.opponent else G.ALERT, true))
		c.add_child(G.wrap(sector.label, 11))
	card.add_child(G.wrap("Votre XV / projection adverse · notes de simulation sur100, ajustées à la condition.", 11))

static func dialog(app: Control, title: String, id: String, width: int = 880) -> Array:
	app._clear_dialogs()
	var d := AcceptDialog.new()
	d.name = id
	d.title = title
	app._prepare_dialog(d, width)
	d.get_ok_button().text = "FERMER"
	var content := G.v(10)
	content.custom_minimum_size = Vector2(width - 70, 450)
	d.add_child(content)
	var list := G.scroll(content)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	app.add_child(d)
	return [d, list]

static func dossier(app: Control) -> void:
	var data: Variant = app.model.get("decisions", {}).get("preparation")
	if not data is Dictionary: return
	var view := dialog(app, "Le dossier adverse", "OppositionDossier", 900)
	var d: AcceptDialog = view[0]
	var list: VBoxContainer = view[1]
	G.photo_note(list, data.opponent, "Dossier adverse", str(data.opponent.name), "stadium", 120)
	list.add_child(G.section(str(data.opponent.name), "Les faits et le conseil du staff"))
	list.add_child(G.wrap(data.get("notice", ""), 13))
	var advice: Dictionary = data.get("advice", {})
	list.add_child(G.section("Le plan proposé"))
	list.add_child(G.wrap(advice.get("attackReason", ""), 15, G.INK))
	list.add_child(G.wrap(advice.get("defenceReason", ""), 15, G.INK))
	var adopt := G.button("ADOPTER CE PLAN PRINCIPAL", func():
		d.queue_free()
		app._command("set_tactics", {"attack":advice.attack, "defense":advice.defence}))
	adopt.name = "AdoptDossierPlan"
	adopt.disabled = not app._live().is_empty()
	list.add_child(adopt)
	list.add_child(G.wrap("Les éventuelles consignes par zone gardent la priorité. Aucun changement automatique des 23.", 12))
	list.add_child(G.separator())
	list.add_child(G.section("Joueurs pressentis à surveiller"))
	for threat: Dictionary in data.get("threats", []):
		list.add_child(G.wrap("%s · %s · %s" % [threat.name, threat.pos, threat.role], 16, G.INK))
	list.add_child(G.separator())
	list.add_child(G.section("Les faits récents"))
	var recent: Array = data.get("recent", [])
	if recent.is_empty(): list.add_child(G.wrap("Pas encore de résultat cette saison. Le rapport repose sur l'effectif.", 14))
	for result: Dictionary in recent:
		var score: Array = result.get("score", [0, 0])
		list.add_child(G.wrap("%s — %s · %s" % [G.n(score[0]), G.n(score[1]), "Journée " + G.n(int(result.get("round", 0)) + 1) if result.get("phase") == "league" else str(result.get("phase", ""))], 14))
	for observation: Dictionary in data.get("signals", []):
		list.add_child(G.wrap(observation.title, 17, G.GOLD))
		list.add_child(G.wrap(observation.evidence + " " + observation.advice, 14))
	if data.get("signals", []).is_empty(): list.add_child(G.wrap("Aucun signal robuste : au moins trois matchs documentés et dix phases de conquête sont nécessaires. Les résultats seuls ne permettent pas d'inventer une faiblesse.", 12))
	d.popup_centered(Vector2i(900, 580))

static func training(app: Control, parent: Container) -> void:
	var data: Dictionary = app.model.get("decisions", {})
	var training: Dictionary = data.get("training", {})
	parent.add_child(G.wrap(training.get("advice", ""), 13, G.GOLD))
	var collective: Dictionary = training.get("collective", {})
	parent.add_child(G.separator())
	parent.add_child(G.label("PRÉPARATION SPÉCIFIQUE", 13, G.MUTED))
	var choice := OptionButton.new()
	choice.name = "CollectiveFocus"
	choice.custom_minimum_size.y = 38
	choice.disabled = not collective.get("available", false)
	for option: Dictionary in collective.get("options", []):
		choice.add_item(option.label)
		choice.set_item_metadata(choice.item_count - 1, option.id)
		if option.id == collective.get("selected"):
			choice.select(choice.item_count - 1)
			parent.add_child(G.wrap(option.description + " · " + option.cost + ". " + option.effect + ". Les effets sont réduits lorsque la charge est élevée.", 12))
	choice.item_selected.connect(func(index: int): app._command("set_collective_focus", {"focus":choice.get_item_metadata(index)}))
	parent.add_child(choice)
	var difficulty: Dictionary = data.get("difficulty", {})
	parent.add_child(G.label("COMPORTEMENT DES ENTRAÎNEURS ADVERSES", 13, G.MUTED))
	var level := OptionButton.new()
	level.name = "OpponentLevel"
	level.custom_minimum_size.y = 38
	level.disabled = not difficulty.get("available", false)
	for option: Dictionary in difficulty.get("options", []):
		level.add_item(option.label)
		level.set_item_metadata(level.item_count - 1, option.id)
		if option.id == difficulty.get("selected"):
			level.select(level.item_count - 1)
			parent.add_child(G.wrap(option.description, 12))
	level.item_selected.connect(func(index: int): app._command("set_opponent_level", {"level":level.get_item_metadata(index)}))
	parent.add_child(level)

static func recruitment_summary(app: Control, parent: Container) -> void:
	var data: Dictionary = app.model.get("decisions", {}).get("recruitment", {})
	var row := G.h(12)
	parent.add_child(row)
	var info := G.wrap("%d / %d professionnels · %d place(s) · %d échéance(s) cette saison" % [app.model.get("squad", []).size(), data.get("capacity", 42), data.get("places", 0), data.get("expiring", []).size()], 13)
	G.fill(info)
	row.add_child(info)
	var button := G.button("BESOINS & MISSIONS", func(): recruitment(app))
	button.name = "OpenRecruitmentNeeds"
	row.add_child(button)

static func recruitment(app: Control) -> void:
	var data: Dictionary = app.model.get("decisions", {}).get("recruitment", {})
	var view := dialog(app, "Construire l'effectif", "RecruitmentNeeds", 900)
	var d: AcceptDialog = view[0]
	var holder: VBoxContainer = view[1]
	var tabs := TabContainer.new()
	tabs.name = "ScoutTabs"
	tabs.custom_minimum_size.y = 365
	tabs.add_theme_font_size_override("font_size", 13)
	G.fill(tabs, true)
	holder.add_child(tabs)
	var needs := G.v(6)
	needs.name = "Besoins"
	tabs.add_child(needs)
	var missions := G.v(6)
	missions.name = "Missions"
	tabs.add_child(missions)
	var reports := G.v(6)
	reports.name = "Rapports"
	tabs.add_child(reports)
	var list: VBoxContainer = G.scroll(needs)
	list.add_child(G.label("Les postes à anticiper", 18, G.INK, true))
	list.add_child(G.wrap("Aptitude actuelle, contrats et relève. Vous gardez la décision.", 12))
	for need: Dictionary in data.get("needs", []):
		var row := G.h(10)
		list.add_child(row)
		var text := G.wrap("%s · %d apte(s) · %d durable(s)\n%s" % [need.pos, need.healthy, need.durable, ", ".join(need.reasons)], 12, G.ALERT if need.need else G.MUTED)
		G.fill(text)
		row.add_child(text)
		row.add_child(G.button("VOIR LES PISTES", func():
			d.queue_free(); app.management_ui.market.position = need.pos; app._navigate("Recrutement")))
		list.add_child(G.separator())
	list = G.scroll(missions)
	list.add_child(G.label("Confier une recherche", 18, G.INK, true))
	list.add_child(G.wrap("5 000 € · deux journées · une mission active, trois en attente.", 12))
	var fields := G.h(10)
	list.add_child(fields)
	var position := OptionButton.new()
	position.name = "ScoutFamily"
	for name in ["Piliers", "Talonneurs", "Deuxième ligne", "Troisième ligne", "Demi de mêlée", "Ouverture", "Ailiers", "Centres", "Arrières"]: position.add_item(name)
	fields.add_child(position)
	var age := spin(fields, "Âge max.", 18, 40, 28, 1)
	var fee := spin(fields, "Prime max.", 0, 10000000, 700000, 50000)
	var wage := spin(fields, "Salaire / sem.", 1000, 100000, 12000, 500)
	var mission := G.button("CONFIER LA MISSION · 5 000 €", func():
		var payload := {"family":position.selected, "maxAge":int(age.value), "budget":int(fee.value), "maxWage":int(wage.value), "confirmed":true}
		d.queue_free()
		app.confirm("Lancer une mission", "5 000 € seront payés immédiatement. Le rapport porte sur les agents libres de la simulation et arrive après deux journées de travail. Confirmer ?", func(): app._command("scout_mission", payload)))
	mission.name = "CreateScoutMission"
	mission.disabled = not data.get("missionAvailable", false)
	list.add_child(mission)
	for job: Dictionary in data.get("missions", []): list.add_child(G.wrap("Mission %s · %s" % [job.id, "en cours, %s journée(s)" % G.n(job.remaining) if job.status == "active" else "en attente" if job.status == "queued" else "terminée"], 13))
	var available_reports: Array = data.get("reports", [])
	if available_reports.is_empty():
		reports.add_child(G.wrap("Aucun rapport. Confiez une mission pour recevoir des profils datés.", 13))
	else:
		var picker := OptionButton.new()
		picker.name = "ScoutReportPicker"
		picker.custom_minimum_size.y = 34
		G.fill(picker)
		for report: Dictionary in available_reports:
			picker.add_item(str(report.get("name", "Joueur non identifié")) + " · " + str(report.get("pos", "Poste inconnu")))
			picker.set_item_tooltip(picker.item_count - 1, picker.get_item_text(picker.item_count - 1))
		reports.add_child(picker)
		var detail := G.scroll(reports)
		var redraw := func(index: int):
			for child in detail.get_children(): detail.remove_child(child); child.queue_free()
			scout_report(detail, available_reports[index])
		picker.item_selected.connect(redraw)
		redraw.call(0)
	d.popup_centered(Vector2i(900, 580))

static func scout_report(parent: Container, report: Dictionary) -> void:
	var card := G.card(parent)
	card.name = "ScoutReport_" + str(report.get("id", "archive"))
	card.add_theme_constant_override("separation", 6)
	card.add_child(G.wrap(str(report.get("name", "Joueur non identifié")), 18, G.INK))
	card.add_child(G.wrap(str(report.get("pos", "Poste non conservé")), 12))
	var assessment: Dictionary = report.get("assessment", {})
	var source := G.wrap(assessment.get("source", "Date du rapport non conservée"), 12, G.GOLD)
	source.name = "ScoutSource"
	card.add_child(source)
	var fit := G.wrap(assessment.get("fit", "Besoins actuels à vérifier avant de décider."), 12, G.INK)
	fit.name = "ScoutFit"
	card.add_child(fit)
	var evidence := TabContainer.new()
	evidence.name = "ScoutEvidenceTabs"
	evidence.add_theme_font_size_override("font_size", 12)
	card.add_child(evidence)
	for section: Array in [["ScoutObserved", "Faits relevés", "observed"], ["ScoutEstimates", "Avis", "estimates"], ["ScoutLimits", "À vérifier", "limits"]]:
		var block := G.v(3)
		block.name = section[1]
		evidence.add_child(block)
		var content := G.v(3)
		content.name = section[0]
		block.add_child(content)
		var lines: Array = assessment.get(section[2], [])
		if lines.is_empty(): content.add_child(G.wrap("Information non conservée.", 12))
		for line: String in lines: content.add_child(G.wrap(line, 12))
	card.add_child(G.separator())
	card.add_child(G.wrap(assessment.get("availability", "Disponibilité actuelle non vérifiée."), 13, G.GOLD if assessment.get("available", false) else G.ALERT))
	card.add_child(G.wrap(assessment.get("caution", "Avis daté ; aucune garantie de performance ou de signature."), 12))

static func spin(parent: Container, title: String, minimum: float, maximum: float, value: float, step: float) -> SpinBox:
	var box := G.v(3)
	G.fill(box)
	parent.add_child(box)
	box.add_child(G.label(title, 11))
	var control := SpinBox.new()
	control.min_value = minimum; control.max_value = maximum; control.value = value; control.step = step
	control.custom_minimum_size = Vector2(110, 38)
	box.add_child(control)
	return control

static func match_notes(app: Control, parent: Container, model: Dictionary) -> void:
	var data: Dictionary = model.get("decisions", {})
	var live: Dictionary = model.live if model.get("live") is Dictionary else {}
	var advice: Variant = data.get("liveAdvice")
	if not live.is_empty() and not live.get("finished", false) and advice is Dictionary:
		parent.add_child(G.section("Le regard de l'adjoint"))
		parent.add_child(G.wrap(advice.attackReason, 13))
		parent.add_child(G.wrap(advice.defenceReason, 13))
		var adopt := G.button("APPLIQUER CES CONSIGNES", func(): app._command("set_tactics", {"attack":advice.attack, "defense":advice.defence}))
		adopt.name = "ApplyLiveAdvice"
		adopt.disabled = not advice.get("canAct", false) or not advice.get("defenceAvailable", false)
		parent.add_child(adopt)
		parent.add_child(G.wrap("Conseil indicatif. Mise en pause requise ; les consignes locales gardent leur priorité.", 11))
	var report: Variant = data.get("report")
	if (live.is_empty() or live.get("finished", false)) and report is Dictionary:
		parent.add_child(G.section("Dernière rencontre · vos choix, les faits" if live.is_empty() else "Vos choix, les faits"))
		for note in report.get("notes", []): parent.add_child(G.wrap(note, 13))
		var plans: Variant = report.get("plans")
		if plans is Dictionary:
			for id in plans.get("attack", {}):
				var p: Dictionary = plans.attack[id]
				if p.get("phases", 0) > 0: parent.add_child(G.wrap("%s · %s phases · %s / %s progressions · %s m · %s erreurs" % [str(id).capitalize(), G.n(p.phases), G.n(p.advances), G.n(p.carries), G.n(p.metres), G.n(p.handErrors)], 12, G.GOLD))
		parent.add_child(G.wrap(report.get("notice", ""), 11))
