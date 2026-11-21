extends RefCounted
const Copy = preload("res://ui/management_copy.gd")
const Champs = preload("res://ui/immersive08/champs_charte.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/carnet_skin.gd")
const Visuel = preload("res://ui/strategy_visuals.gd")

## PROVISOIRE (revue visuelle du 21/11/2026, n° 2) : CD_VARIANTE_VISUELLE=A (cartes d'offre) ou B (règle, barres
## groupées, anneau) montre l'une des deux options à Léo ; sans variable, l'écran actuel. À retirer dès son choix.
static func _variante() -> String:
	return OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()

static func _send(app: Control, command: String, payload: Dictionary, confirmation: String = "") -> void:
	var values := payload.duplicate(true)
	values.context = app.model.clubLife.clubStrategy.context.duplicate(true)
	if confirmation.is_empty():
		app._command(command, values)
	else:
		values.confirmed = true
		app.confirm_decision(command, values, "Engager le club", confirmation, func(): app._command(command, values))

static func _amount(parent: Container, label: String, value: String, color: Color = G.INK, open: Callable = Callable()) -> void:
	var column := G.v(2)
	G.fill(column)
	parent.add_child(column)
	column.add_child(G.label(value, 29, color, true))
	column.add_child(G.label(label, 12, G.MUTED))
	if open.is_valid(): Visuel.zone_cliquable(column, open, label.capitalize())

## Options A et B : un chiffre ou une jauge mène à l'écran qui le détaille (règle de Léo : ce qui ressemble à une tuile
## ouvre quelque chose). Écran actuel : rien (Callable vide).
static func _go(app: Control, route: String) -> Callable:
	if _variante().is_empty(): return Callable()
	return func(): app._navigate(route)

## Titre de bloc. Options A et B (règle de Léo du 21/11/2026 : pas de phrase de mode d'emploi à l'écran) : la phrase
## d'explication passe dans l'infobulle d'un « i » à côté du titre ; l'écran actuel garde son sous-titre.
static func _section(title: String, subtitle: String = "") -> Control:
	if _variante().is_empty() or subtitle.is_empty(): return G.section(title, subtitle)
	var row := G.h(10)
	var heading := G.label(title, 27, G.INK, true)
	heading.add_theme_font_override("font", G.T.DISPLAY)
	row.add_child(heading)
	row.add_child(_info(subtitle))
	return row

## Pictogramme « i » : l'explication en infobulle au survol, rien d'autre (ni clic, ni fenêtre).
static func _info(text: String) -> Control:
	var icon := Visuel.picto("info", 26, Charte.IVOIRE_2)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.mouse_default_cursor_shape = Control.CURSOR_HELP
	icon.tooltip_text = text
	icon.accessibility_name = text
	return icon

## Pilule d'une décision du club : même nom, même commande et même confirmation en place quel que soit l'habillage.
static func _choice(app: Control, command: String, payload: Dictionary, blocked: bool, confirmation: String = "", text: String = "Choisir") -> Button:
	# Options A et B : pilule secondaire de la charte (contour, texte crème, grisée quand indisponible), au corps des
	# boutons de la coque ; l'écran actuel garde son « CHOISIR → ».
	var send := func(): _send(app, command, payload, confirmation)
	var button: Button = G.button(text, send) if _variante().is_empty() else Visuel.C.button(text, send)
	if not _variante().is_empty():
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.set_meta("style_charte", true)
	button.name = command + "_" + str(payload.get("key", payload.get("kind", payload.get("amount", "action"))))
	button.disabled = blocked
	return button

## Choix exclusif (cap du club, politique de prix). Options A et B : pilule de la charte, le choix courant en aplat
## crème avec une coche (forme + mot, pas seulement la couleur) ; l'écran actuel garde son bouton.
static func _toggle(text: String, callback: Callable, chosen: bool) -> Button:
	if _variante().is_empty(): return G.button(text, callback, chosen)
	var button := Visuel.C.button(text, callback)
	button.set_meta("style_charte", true)
	if chosen:
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, Visuel.C.box(Charte.IVOIRE, Color.TRANSPARENT, Charte.RAYON_PILULE, 18))
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			button.add_theme_color_override(key, Charte.PANNEAU)
		button.icon = Visuel.picto_texture("check", Charte.PANNEAU)
		button.add_theme_constant_override("icon_max_width", Visuel.C.px(24))
	return button
static func _action_row(app: Control, parent: Container, label: String, detail: String, command: String, payload: Dictionary, blocked: bool, confirmation: String = "", icon: String = "") -> void:
	var tile := G.card(parent)
	var row := G.h(14)
	tile.add_child(row)
	# Options A et B : pictogramme et fond teintés de la famille d'offre (palette commune des données).
	if not icon.is_empty() and not _variante().is_empty():
		Visuel.cadre_teinte(tile, Visuel.teinte(icon))
		var picto := Visuel.picto(icon, 34, Visuel.teinte(icon))
		picto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(picto)
	var text := G.v(3)
	G.fill(text)
	row.add_child(text)
	var heading := G.wrap(label, 20, G.INK)
	heading.add_theme_font_override("font", G.T.DISPLAY)
	text.add_child(heading)
	text.add_child(G.wrap(detail, 12))
	row.add_child(_choice(app, command, payload, blocked, confirmation, "CHOISIR →"))

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
	G.chapter(paper, "15", "Les moyens de tes ambitions", "Financer, donner un cap, fédérer la ville." if _variante().is_empty() else "", app.accent)
	var tabs := TabContainer.new()
	tabs.name = "StrategyTabs"
	tabs.custom_minimum_size.y = 280
	G.fill(tabs, true)
	paper.add_child(tabs)
	var finance := _tab(tabs, "Finances")
	var board := _tab(tabs, "Projet sportif")
	var fans := _tab(tabs, "Supporters")
	var locked: bool = not bool(data.available) or app.waiting
	Visuel.vers_finances = _go(app, "Finances")
	_finance(app, finance, data, locked)
	_board(app, board, data, locked)
	_fans(app, fans, data, locked)
	return page

static func _finance(app: Control, page: Container, data: Dictionary, locked: bool) -> void:
	var f: Dictionary = data.finance
	var variante := _variante()
	var card := G.panel(page)
	var amounts := G.h(20)
	card.add_child(amounts)
	_amount(amounts, "TRÉSORERIE DISPONIBLE", G.euros(f.cash), G.GOOD if f.cash >= 0 else G.ALERT, _go(app, "Finances"))
	_amount(amounts, "SALAIRES "+G.salary_period(true).to_upper(), G.salary_amount(f.weeklyWages), G.INK, _go(app, "Finances"))
	_amount(amounts, "PROJECTION DES ENGAGEMENTS", G.euros(f.baseForecast), G.GOLD, _go(app, "Finances"))
	if variante.is_empty():
		card.add_child(G.wrap("%d semaines restantes sur %d · %s" % [f.remainingWeeks, f.weeksPerSeason, Copy.notice("strategy", f.notice)], 12))
	else:
		_amount(amounts, "SEMAINES RESTANTES", "%d / %d" % [f.remainingWeeks, f.weeksPerSeason], G.INK, _go(app, "Calendrier"))
		var notice := _info(Copy.notice("strategy", f.notice))
		amounts.add_child(notice)
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
	academy.add_child(_section("Financer la relève", "L’engagement est prélevé à la séance ; il développe les Espoirs."))
	var trained: bool = app.model.meta.trained
	if variante == "A":
		var cards := G.h(12)
		academy.add_child(cards)
		for amount in [0, 4000, 12000]:
			var current: bool = f.academyInvestment == amount
			Visuel.carte_offre(cards, "school", "", G.euros(amount), "par semaine", _choice(app, "club_academy_investment", {"amount":amount}, locked or trained or current, "Engager %s à chaque séance de formation ?" % G.euros(amount)), "Actuel" if current else "")
		_amount(academy, "DÉJÀ INVESTI CETTE SAISON", G.euros(f.academySpent), G.INK, _go(app, "Formation"))
	elif variante == "B":
		var notches: Array = []
		var pills: Array = []
		for amount in [0, 4000, 12000]:
			var current: bool = f.academyInvestment == amount
			notches.append({"valeur":amount, "actuel":current})
			pills.append(_choice(app, "club_academy_investment", {"amount":amount}, locked or trained or current, "Engager %s à chaque séance de formation ?" % G.euros(amount), "%s / semaine" % G.euros(amount)))
		var ruler := Visuel.Regle.new(notches, pills)
		ruler.name = "StrategieRegleReleve"
		academy.add_child(ruler)
		_amount(academy, "DÉJÀ INVESTI CETTE SAISON", G.euros(f.academySpent), G.INK, _go(app, "Formation"))
	else:
		for amount in [0, 4000, 12000]:
			_action_row(app, academy, "%s par semaine%s" % [G.euros(amount), " · ACTUEL" if f.academyInvestment == amount else ""], "Déjà investi cette saison : " + G.euros(f.academySpent), "club_academy_investment", {"amount":amount}, locked or app.model.meta.trained or f.academyInvestment == amount, "Engager %s à chaque séance de formation ?" % G.euros(amount))
	if f.facility is Dictionary:
		var q: Dictionary = f.facility
		var facility := G.panel(investments)
		var facility_blocked: bool = locked or trained or q.used or not q.affordable
		var facility_confirm := "Investir %s pour passer les installations au niveau %d ?" % [G.euros(q.cost), q.nextLevel]
		if not variante.is_empty():
			Visuel.carte_couchee(facility, "settings", "Installations · niveau %d / 10" % q.level, G.euros(q.cost), "", _choice(app, "club_facility_upgrade", {"cost":q.cost,"level":q.level}, facility_blocked, facility_confirm), "Trésorerie insuffisante" if not q.affordable and not q.used else "", false, _info("Entretien du prochain niveau indiqué au devis. Une amélioration par saison."))
		else:
			_action_row(app, facility, "Installations · niveau %d / 10" % q.level, "%s · entretien du prochain niveau indiqué au devis. Une amélioration par saison." % G.euros(q.cost), "club_facility_upgrade", {"cost":q.cost,"level":q.level}, facility_blocked, facility_confirm)
	var sponsors := G.panel(partners)
	sponsors.add_child(_section("Choisir son partenaire", "Une signature par saison, avant la cinquième journée."))
	if variante == "A":
		var best := {"weekly":1.0, "signing":1.0, "win":1.0}
		for offer: Dictionary in data.sponsors:
			for key in best: best[key] = maxf(best[key], float(offer[key]))
		var cards := G.h(12)
		sponsors.add_child(cards)
		for offer: Dictionary in data.sponsors:
			var detail := "%s / semaine · avance %s · prime de victoire %s" % [G.euros(offer.weekly), G.euros(offer.signing), G.euros(offer.win)]
			var chart := Visuel.Histogramme.new([
				{"valeur":offer.weekly, "maximum":best.weekly, "montant":G.euros(offer.weekly), "critere":"semaine"},
				{"valeur":offer.signing, "maximum":best.signing, "montant":G.euros(offer.signing), "critere":"avance"},
				{"valeur":offer.win, "maximum":best.win, "montant":G.euros(offer.win), "critere":"victoire"}])
			Visuel.carte_offre(cards, "poignee", offer.label, G.euros(offer.weekly), "par semaine", _choice(app, "club_sponsor_sign", {"key":offer.id}, locked or not offer.available, "Signer « %s » ? %s." % [offer.label, detail]), "Signé" if offer.selected else "", true, chart)
	elif variante == "B":
		var groups: Array = []
		for criterion: Array in [["Par semaine", "weekly"], ["Avance à la signature", "signing"], ["Prime de victoire", "win"]]:
			var lines: Array = []
			for offer: Dictionary in data.sponsors:
				lines.append({"nom":offer.label + (" · SIGNÉ" if offer.selected else ""), "valeur":offer[criterion[1]], "montant":G.euros(offer[criterion[1]])})
			groups.append({"titre":criterion[0], "lignes":lines})
		var chart := Visuel.BarresGroupees.new(groups)
		var chart_pills: Array = []
		chart.name = "StrategieBarresPartenaires"
		sponsors.add_child(chart)
		var pills := HFlowContainer.new()
		pills.add_theme_constant_override("h_separation", 10)
		pills.add_theme_constant_override("v_separation", 8)
		sponsors.add_child(pills)
		for offer: Dictionary in data.sponsors:
			var detail := "%s / semaine · avance %s · prime de victoire %s" % [G.euros(offer.weekly), G.euros(offer.signing), G.euros(offer.win)]
			var pill := _choice(app, "club_sponsor_sign", {"key":offer.id}, locked or not offer.available, "Signer « %s » ? %s." % [offer.label, detail], "Choisir « %s »" % offer.label)
			pills.add_child(pill)
			chart_pills.append(pill)
		chart.actions = chart_pills
	else:
		for offer: Dictionary in data.sponsors:
			var detail := "%s / semaine · avance %s · prime de victoire %s" % [G.euros(offer.weekly), G.euros(offer.signing), G.euros(offer.win)]
			_action_row(app, sponsors, offer.label + (" · SIGNÉ" if offer.selected else ""), detail, "club_sponsor_sign", {"key":offer.id}, locked or not offer.available, "Signer « %s » ? %s." % [offer.label, detail])

static func _board(app: Control, page: Container, data: Dictionary, locked: bool) -> void:
	var b: Dictionary = data.board
	var variante := _variante()
	var card := G.panel(page)
	var cap := "Une priorité claire pour arbitrer les décisions."
	card.add_child(_section("Donner un cap", cap if variante.is_empty() else cap + "\n\n" + Copy.notice("strategy", b.notice)))
	var row := G.h(10)
	card.add_child(row)
	for key: String in ["performance", "stabilite", "finances", "effectif"]:
		var names := {"performance":"Résultats", "stabilite":"Stabilité", "finances":"Finances", "effectif":"Effectif"}
		var button := _toggle(names[key], func(): _send(app, "club_board_priority", {"key":key}), b.priority == key)
		button.name = "BoardPriority_" + key
		button.disabled = locked
		row.add_child(button)
	if variante.is_empty(): card.add_child(G.wrap(Copy.notice("strategy", b.notice), 12))
	var health := G.h(18)
	card.add_child(health)
	_amount(health, "JOUEURS DISPONIBLES", G.n(b.readiness.available), G.INK, _go(app, "Effectif"))
	_amount(health, "CONDITION SATISFAISANTE", "%d %%" % b.readiness.coverage, G.INK, _go(app, "Effectif"))
	_amount(health, "ORGANISATION", "%d / 100" % b.organizationScore, G.GOLD)
	G.gauge(card, "Disponibilité du groupe", float(b.readiness.coverage), 100, G.GOOD)
	if not variante.is_empty(): Visuel.zone_cliquable(card.get_child(card.get_child_count() - 1), _go(app, "Effectif"), "Ouvrir l'effectif")
	var projects := G.panel(page)
	projects.add_child(_section("Structurer le club", "Projets d’organisation, sans bonus de match automatique."))
	if variante == "A":
		var cards := G.h(12)
		projects.add_child(cards)
		for project: Dictionary in b.projectOptions:
			var short: bool = data.finance.cash < project.cost
			Visuel.carte_offre(cards, {"video":"video", "medical":"croix", "logistique":"camion"}.get(project.id, "settings"), project.label, G.euros(project.cost), "paiement unique", _choice(app, "club_board_project", {"kind":project.id}, locked or project.used or short, "Financer %s pour %s ?" % [project.label, G.euros(project.cost)]), "Engagé" if project.used else "Trésorerie insuffisante" if short else "", project.used)
	else:
		for project: Dictionary in b.projectOptions:
			_action_row(app, projects, project.label, G.euros(project.cost) + (" · ENGAGÉ" if project.used else " · paiement unique"), "club_board_project", {"kind":project.id}, locked or project.used or data.finance.cash < project.cost, "Financer %s pour %s ?" % [project.label, G.euros(project.cost)], {"video":"video", "medical":"croix", "logistique":"camion"}.get(project.id, "settings"))
	var objectives := G.panel(page)
	var council := "Objectifs suivis depuis les résultats de ta carrière."
	var empty := "Fixe un premier jalon. Les objectifs servent au suivi du projet ; la confiance du président dépend du bilan du club."
	objectives.add_child(_section("Les rendez-vous du conseil", council if variante.is_empty() or not b.objectives.is_empty() else council + "\n\n" + empty))
	for goal: Dictionary in b.objectives:
		objectives.add_child(G.wrap("%s · cible %s · semaine %d · %s" % [goal.type, G.n(goal.target), goal.deadline, {"pending":"À suivre","met":"Atteint","missed":"Manqué","unverified":"Non vérifiable"}.get(goal.status, goal.status)], 14))
	if b.objectives.is_empty() and variante.is_empty(): objectives.add_child(G.wrap(empty, 14))
	var goal_row := G.h(10)
	objectives.add_child(goal_row)
	var kind := OptionButton.new()
	for label in ["Victoires", "Points", "Place au classement", "Trésorerie"]: kind.add_item(label)
	Champs.liste(kind)
	goal_row.add_child(kind)
	var target := SpinBox.new()
	target.min_value = 0
	target.max_value = 1000000000
	target.value = 10
	target.custom_minimum_size.x = 140
	Champs.champ(target.get_line_edit())
	goal_row.add_child(target)
	var deadline := SpinBox.new()
	deadline.min_value = minf(float(data.context.week + 1), float(data.finance.weeksPerSeason))
	deadline.max_value = data.finance.weeksPerSeason
	deadline.value = data.finance.weeksPerSeason
	deadline.prefix = "Sem. "
	deadline.custom_minimum_size.x = 125
	Champs.champ(deadline.get_line_edit())
	goal_row.add_child(deadline)
	var add_send := func(): _send(app, "club_board_objective", {"type":["wins","points","rank","cash"][kind.selected],"target":target.value,"deadline":int(deadline.value)})
	var add: Button = G.button("FIXER LE JALON", add_send) if _variante().is_empty() else Visuel.C.button("FIXER LE JALON", add_send)
	if not _variante().is_empty(): add.set_meta("style_charte", true)
	add.name = "BoardObjectiveAdd"
	add.disabled = locked or data.context.week >= data.finance.weeksPerSeason
	goal_row.add_child(add)

static func _fans(app: Control, page: Container, data: Dictionary, locked: bool) -> void:
	var f: Dictionary = data.fans
	var variante := _variante()
	G.photo_note(page, app.model.club, "Le territoire", "Une ville derrière toi", "city", 140)
	var card := G.panel(page)
	var town := "L’accueil et l’ancrage local se construisent toute la saison."
	card.add_child(_section("Une ville derrière toi", town if variante.is_empty() else town + "\n\n" + Copy.notice("strategy", f.notice)))
	var metrics := G.h(18)
	card.add_child(metrics)
	if variante == "B":
		metrics.add_theme_constant_override("separation", 72)
		var mood := G.v(4)
		metrics.add_child(mood)
		var ring := Visuel.Anneau.new(float(f.sentiment), 100.0)
		ring.name = "StrategieAnneauSentiment"
		mood.add_child(ring)
		var caption := G.label("SENTIMENT", 12, G.MUTED)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mood.add_child(caption)
		Visuel.chiffre_picto(metrics, "people", G.n(f.expectedAttendance), "AFFLUENCE PRÉVUE")
		Visuel.chiffre_picto(metrics, "star", G.n(f.subscribers), "ABONNÉS")
	else:
		_amount(metrics, "SENTIMENT", "%d / 100" % f.sentiment, G.GOLD)
		_amount(metrics, "AFFLUENCE PRÉVUE", G.n(f.expectedAttendance))
		_amount(metrics, "ABONNÉS", G.n(f.subscribers))
	if variante.is_empty(): card.add_child(G.wrap(Copy.notice("strategy", f.notice), 12))
	var price_row := G.h(10)
	card.add_child(price_row)
	for price: Dictionary in f.prices:
		var button := _toggle("%s · %s" % [price.id.capitalize(), G.euros(price.price)], func(): _send(app, "club_fans_price", {"key":price.id}), f.policy == price.id)
		button.disabled = locked
		price_row.add_child(button)
	for category: Dictionary in [{"title":"Faire venir","key":"campaigns","command":"club_fans_campaign","icon":"people"},{"title":"Tisser des liens","key":"community","command":"club_fans_community","icon":"heart"},{"title":"Accueillir au stade","key":"services","command":"club_fans_service","icon":"home"}]:
		var actions := G.panel(page)
		actions.add_child(_section(category.title, "Dépenses prévues, sans nouvelle recette automatique."))
		if variante == "A":
			var cards := G.h(12)
			actions.add_child(cards)
			for option: Dictionary in f[category.key]:
				var short: bool = data.finance.cash < option.cost
				Visuel.carte_offre(cards, category.icon, option.label, G.euros(option.cost), "", _choice(app, category.command, {"key":option.id}, locked or option.used or short, "Engager « %s » pour %s ?" % [option.label, G.euros(option.cost)]), "Déjà engagé" if option.used else "Trésorerie insuffisante" if short else "", option.used)
			continue
		for option: Dictionary in f[category.key]:
			_action_row(app, actions, option.label, G.euros(option.cost) + (" · DÉJÀ ENGAGÉ" if option.used else ""), category.command, {"key":option.id}, locked or option.used or data.finance.cash < option.cost, "Engager « %s » pour %s ?" % [option.label, G.euros(option.cost)], category.icon)
