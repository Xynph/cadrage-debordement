extends RefCounted
const G = preload("res://ui/carnet_skin.gd")

static func _send(app: Control, command: String, payload: Dictionary, confirmation: String = "") -> void:
	var values := payload.duplicate(true)
	values.context = app.model.clubLife.clubStrategy.context.duplicate(true)
	if confirmation.is_empty():
		app._command(command, values)
	else:
		values.confirmed = true
		app.confirm_decision(command, values, "Engager le club", confirmation, func(): app._command(command, values))

static func _amount(parent: Container, label: String, value: String, color: Color = G.INK) -> void:
	var column := G.v(2)
	G.fill(column)
	parent.add_child(column)
	column.add_child(G.label(value, 29, color, true))
	column.add_child(G.label(label, 11, G.MUTED))

static func _action_row(app: Control, parent: Container, label: String, detail: String, command: String, payload: Dictionary, blocked: bool, confirmation: String = "") -> void:
	var tile := G.card(parent)
	var row := G.h(14)
	tile.add_child(row)
	var text := G.v(3)
	G.fill(text)
	row.add_child(text)
	var heading := G.wrap(label, 20, G.INK)
	heading.add_theme_font_override("font", G.T.DISPLAY)
	text.add_child(heading)
	text.add_child(G.wrap(detail, 12))
	var button := G.button("CHOISIR →", func(): _send(app, command, payload, confirmation))
	button.name = command + "_" + str(payload.get("key", payload.get("kind", payload.get("amount", "action"))))
	button.disabled = blocked
	row.add_child(button)

static func _tab(tabs: TabContainer, name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_child(scroll)
	var page := G.v(17)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	return page

static func build(app: Control) -> Control:
	var page := G.v(14)
	page.name = "CarnetStrategie"
	G.fill(page, true)
	var paper := G.panel(page)
	G.fill(paper.get_parent(), true)
	G.fill(paper, true)
	var data: Dictionary = app.model.get("clubLife", {}).get("clubStrategy", {})
	if data.is_empty():
		page.add_child(G.wrap("Les décisions du club seront disponibles avec une carrière ouverte.", 17))
		return page
	G.chapter(paper, "15", "Les moyens de vos ambitions", "Financer, donner un cap, fédérer la ville.", app.accent)
	var tabs := TabContainer.new()
	tabs.name = "StrategyTabs"
	tabs.custom_minimum_size.y = 280
	G.fill(tabs, true)
	paper.add_child(tabs)
	var finance := _tab(tabs, "Finances")
	var board := _tab(tabs, "Projet sportif")
	var fans := _tab(tabs, "Supporters")
	var locked: bool = not bool(data.available) or app.waiting
	_finance(app, finance, data, locked)
	_board(app, board, data, locked)
	_fans(app, fans, data, locked)
	return page

static func _finance(app: Control, page: Container, data: Dictionary, locked: bool) -> void:
	var f: Dictionary = data.finance
	var card := G.panel(page)
	var amounts := G.h(20)
	card.add_child(amounts)
	_amount(amounts, "TRÉSORERIE DISPONIBLE", G.euros(f.cash), G.GOOD if f.cash >= 0 else G.ALERT)
	_amount(amounts, "SALAIRES "+G.salary_period(true).to_upper(), G.salary_amount(f.weeklyWages))
	_amount(amounts, "PROJECTION DES ENGAGEMENTS", G.euros(f.baseForecast), G.GOLD)
	card.add_child(G.wrap("%d semaines restantes sur %d · %s" % [f.remainingWeeks, f.weeksPerSeason, f.notice], 12))
	if not f.facility is Dictionary:
		var notice := G.wrap("Installations · Aucun devis disponible", 22, G.MUTED)
		notice.add_theme_font_size_override("font_size", 22)
		card.add_child(notice)
	var columns := G.h(16)
	page.add_child(columns)
	var investments := G.v(14)
	G.fill(investments)
	columns.add_child(investments)
	var partners := G.v(14)
	G.fill(partners)
	columns.add_child(partners)
	var academy := G.panel(investments)
	academy.add_child(G.section("Financer la relève", "L’engagement est prélevé à la séance ; il développe les Espoirs."))
	for amount in [0, 4000, 12000]:
		_action_row(app, academy, "%s par semaine%s" % [G.euros(amount), " · ACTUEL" if f.academyInvestment == amount else ""], "Déjà investi cette saison : " + G.euros(f.academySpent), "club_academy_investment", {"amount":amount}, locked or app.model.meta.trained or f.academyInvestment == amount, "Engager %s à chaque séance de formation ?" % G.euros(amount))
	if f.facility is Dictionary:
		var q: Dictionary = f.facility
		var facility := G.panel(investments)
		_action_row(app, facility, "Installations · niveau %d / 10" % q.level, "%s · entretien du prochain niveau indiqué au devis. Une amélioration par saison." % G.euros(q.cost), "club_facility_upgrade", {"cost":q.cost,"level":q.level}, locked or app.model.meta.trained or q.used or not q.affordable, "Investir %s pour passer les installations au niveau %d ?" % [G.euros(q.cost), q.nextLevel])
	var sponsors := G.panel(partners)
	sponsors.add_child(G.section("Choisir son partenaire", "Une signature par saison, avant la cinquième journée."))
	for offer: Dictionary in data.sponsors:
		var detail := "%s / semaine · avance %s · prime de victoire %s" % [G.euros(offer.weekly), G.euros(offer.signing), G.euros(offer.win)]
		_action_row(app, sponsors, offer.label + (" · SIGNÉ" if offer.selected else ""), detail, "club_sponsor_sign", {"key":offer.id}, locked or not offer.available, "Signer « %s » ? %s." % [offer.label, detail])

static func _board(app: Control, page: Container, data: Dictionary, locked: bool) -> void:
	var b: Dictionary = data.board
	var card := G.panel(page)
	card.add_child(G.section("Donner un cap", "Une priorité claire pour arbitrer les décisions."))
	var row := G.h(10)
	card.add_child(row)
	for key: String in ["performance", "stabilite", "finances", "effectif"]:
		var names := {"performance":"Résultats", "stabilite":"Stabilité", "finances":"Finances", "effectif":"Effectif"}
		var button := G.button(names[key], func(): _send(app, "club_board_priority", {"key":key}), b.priority == key)
		button.name = "BoardPriority_" + key
		button.disabled = locked
		row.add_child(button)
	card.add_child(G.wrap(b.notice, 12))
	var health := G.h(18)
	card.add_child(health)
	_amount(health, "JOUEURS DISPONIBLES", G.n(b.readiness.available))
	_amount(health, "CONDITION SATISFAISANTE", "%d %%" % b.readiness.coverage)
	_amount(health, "ORGANISATION", "%d / 100" % b.organizationScore, G.GOLD)
	G.gauge(card, "Disponibilité du groupe", float(b.readiness.coverage), 100, G.GOOD)
	var projects := G.panel(page)
	projects.add_child(G.section("Structurer le club", "Projets d’organisation, sans bonus de match automatique."))
	for project: Dictionary in b.projectOptions:
		_action_row(app, projects, project.label, G.euros(project.cost) + (" · ENGAGÉ" if project.used else " · paiement unique"), "club_board_project", {"kind":project.id}, locked or project.used or data.finance.cash < project.cost, "Financer %s pour %s ?" % [project.label, G.euros(project.cost)])
	var objectives := G.panel(page)
	objectives.add_child(G.section("Les rendez-vous du conseil", "Objectifs suivis depuis les résultats de votre carrière."))
	for goal: Dictionary in b.objectives:
		objectives.add_child(G.wrap("%s · cible %s · semaine %d · %s" % [goal.type, G.n(goal.target), goal.deadline, {"pending":"À suivre","met":"Atteint","missed":"Manqué","unverified":"Non vérifiable"}.get(goal.status, goal.status)], 14))
	if b.objectives.is_empty(): objectives.add_child(G.wrap("Fixez un premier jalon. Les objectifs servent au suivi du projet ; le bilan moteur reste seul responsable de la confiance présidentielle.", 14))
	var goal_row := G.h(10)
	objectives.add_child(goal_row)
	var kind := OptionButton.new()
	for label in ["Victoires", "Points", "Place au classement", "Trésorerie"]: kind.add_item(label)
	goal_row.add_child(kind)
	var target := SpinBox.new()
	target.min_value = 0
	target.max_value = 1000000000
	target.value = 10
	target.custom_minimum_size.x = 140
	goal_row.add_child(target)
	var deadline := SpinBox.new()
	deadline.min_value = minf(float(data.context.week + 1), float(data.finance.weeksPerSeason))
	deadline.max_value = data.finance.weeksPerSeason
	deadline.value = data.finance.weeksPerSeason
	deadline.prefix = "Sem. "
	deadline.custom_minimum_size.x = 125
	goal_row.add_child(deadline)
	var add := G.button("FIXER LE JALON", func(): _send(app, "club_board_objective", {"type":["wins","points","rank","cash"][kind.selected],"target":target.value,"deadline":int(deadline.value)}))
	add.name = "BoardObjectiveAdd"
	add.disabled = locked or data.context.week >= data.finance.weeksPerSeason
	goal_row.add_child(add)

static func _fans(app: Control, page: Container, data: Dictionary, locked: bool) -> void:
	var f: Dictionary = data.fans
	G.photo_note(page, app.model.club, "Le territoire", "Une ville derrière vous", "city", 140)
	var card := G.panel(page)
	card.add_child(G.section("Une ville derrière vous", "L’accueil et l’ancrage local se construisent toute la saison."))
	var metrics := G.h(18)
	card.add_child(metrics)
	_amount(metrics, "SENTIMENT", "%d / 100" % f.sentiment, G.GOLD)
	_amount(metrics, "AFFLUENCE PRÉVUE", G.n(f.expectedAttendance))
	_amount(metrics, "ABONNÉS", G.n(f.subscribers))
	card.add_child(G.wrap(f.notice, 12))
	var price_row := G.h(10)
	card.add_child(price_row)
	for price: Dictionary in f.prices:
		var button := G.button("%s · %s" % [price.id.capitalize(), G.euros(price.price)], func(): _send(app, "club_fans_price", {"key":price.id}), f.policy == price.id)
		button.disabled = locked
		price_row.add_child(button)
	for category: Dictionary in [{"title":"Faire venir","key":"campaigns","command":"club_fans_campaign"},{"title":"Tisser des liens","key":"community","command":"club_fans_community"},{"title":"Accueillir au stade","key":"services","command":"club_fans_service"}]:
		var actions := G.panel(page)
		actions.add_child(G.section(category.title, "Dépenses de simulation, sans nouvelle recette automatique."))
		for option: Dictionary in f[category.key]:
			_action_row(app, actions, option.label, G.euros(option.cost) + (" · DÉJÀ ENGAGÉ" if option.used else ""), category.command, {"key":option.id}, locked or option.used or data.finance.cash < option.cost, "Engager « %s » pour %s ?" % [option.label, G.euros(option.cost)])
