extends RefCounted
const G = preload("res://ui/carnet_skin.gd")

static func _send(app: Control, data: Dictionary, command: String, payload: Dictionary, title: String = "", detail: String = "") -> void:
	var args: Dictionary = data.context.duplicate()
	args.merge(payload, true)
	if title.is_empty():
		app._command(command, args)
	else:
		args.confirmed = true
		app.confirm(title, detail, func(): app._command(command, args))

static func _action(parent: Node, app: Control, data: Dictionary, label: String, command: String, payload: Dictionary = {}, cost: int = -1, disabled: bool = false) -> Button:
	var title := label if cost >= 0 else ""
	var detail := "Confirmer cette décision ?" if cost == 0 else "Dépense de %s dans la simulation. Confirmer ?" % G.euros(cost)
	var b := G.button(label, func(): _send(app, data, command, payload, title, detail))
	b.name = command + "_" + str(payload.get("playerId", payload.get("centerId", "action"))).replace(":", "_")
	b.disabled = data.get("locked", false) or disabled
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(b)
	return b

static func _choice(parent: Node, caption: String, options: Array, callback: Callable) -> OptionButton:
	parent.add_child(G.wrap(caption, 13))
	var option := OptionButton.new()
	option.custom_minimum_size.y = 44
	for entry in options:
		option.add_item(str(entry[1]))
		option.set_item_metadata(option.item_count - 1, entry[0])
	option.item_selected.connect(func(index: int): callback.call(option.get_item_metadata(index)))
	parent.add_child(option)
	return option

static func _tab(tabs: TabContainer, label: String) -> VBoxContainer:
	var tab := G.v(12)
	tab.name = label
	tabs.add_child(tab)
	return G.scroll(tab)

static func build(app: Control, initial_tab: String = "") -> Control:
	var page := G.v(12)
	page.name = "CarnetAcademyPathways"
	G.fill(page, true)
	var data: Dictionary = app.model.get("clubLife", {}).get("academyPathways", {})
	var paper := G.panel(page)
	G.fill(paper.get_parent(), true)
	G.fill(paper, true)
	G.chapter(paper, "21", "Les parcours de formation", "Une place, un objectif, une génération.", app.accent)
	if not data.get("available", false):
		paper.add_child(G.wrap(data.get("reason", "Le centre est disponible dans une carrière active."), 18))
		return page
	paper.add_child(G.wrap(data.description, 13))
	if not data.get("active", false):
		paper.add_child(G.wrap("Les %d Espoirs actuels restent dans votre centre. Activer les parcours ajoute la détection, les mentorats et les compétitions juniors simulées à cette carrière." % data.players.size(), 18))
		_action(paper, app, data, "ACTIVER LES PARCOURS", "academy_activate", {}, 0)
		return page
	var summary := G.h(18)
	paper.add_child(summary)
	summary.add_child(G.metric(data.players.size(), "espoirs au centre"))
	summary.add_child(G.metric("%d / %d" % [data.juniorRound, data.totalRounds], "périodes juniors"))
	summary.add_child(G.metric(G.euros(data.recruitBudget), "enveloppe de détection junior"))
	var tabs := TabContainer.new()
	tabs.name = "AcademyTabs"
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tabs.add_theme_stylebox_override("tab_selected", G.T.box(G.PAPER, 2, G.LINE))
	tabs.add_theme_stylebox_override("tab_unselected", G.T.box(Color("e5dccb"), 2, G.LINE))
	tabs.add_theme_color_override("font_selected_color", G.INK)
	tabs.add_theme_color_override("font_unselected_color", G.MUTED)
	G.fill(tabs, true)
	paper.add_child(tabs)
	var builders := {
		"Centre": _center.bind(app, data),
		"Parcours": _players.bind(app, data),
		"Centres": _scouting.bind(app, data),
		"Filières": _network.bind(app, data),
		"Passerelle pro": _professionals.bind(app, data),
		"Générations": _history.bind(data),
	}
	var lists: Array[VBoxContainer] = []
	var selected := 0
	for title: String in builders:
		if title == initial_tab: selected = lists.size()
		lists.append(_tab(tabs, title))
	var mounted := {}
	var open_tab := func(index: int):
		if mounted.has(index): return
		mounted[index] = true
		var list := lists[index]
		var scroll := list.get_parent()
		# Construire hors de l’arbre avant d’ajouter le contenu et son thème.
		scroll.remove_child(list)
		var builder: Callable = builders[str(tabs.get_tab_control(index).name)]
		builder.call(list)
		scroll.add_child(list)
	tabs.current_tab = selected
	open_tab.call(selected)
	tabs.tab_changed.connect(open_tab)
	return page

static func _center(list: VBoxContainer, app: Control, data: Dictionary) -> void:
	var pulse := G.h(24)
	list.add_child(pulse)
	G.gauge(pulse, "Cohésion du centre", float(data.cohesion))
	G.gauge(pulse, "Réputation simulée", float(data.reputation), 100, G.GOLD)
	list.add_child(G.section("Préparer la prochaine génération", "Le calendrier junior suit ses propres périodes. Les semaines de repos seniors ne le bloquent pas."))
	_action(list, app, data, "DÉTECTION ANNUELLE · 35 000 €", "academy_scout", {}, 35000, data.nextScouted)
	list.add_child(G.wrap("Cette campagne augmente de 3 le potentiel, au maximum 99, des 15 nouveaux Espoirs de la prochaine saison. Une seule campagne par année.", 14))
	_choice(list, "Plan des rencontres juniors · " + str(data.mode), [["equilibre","Équilibré"],["performance","Performance"],["developpement","Développement"],["repos","Repos"]], func(value): _send(app, data, "academy_mode", {"mode":value})).disabled = data.locked
	if data.division == "elite":
		list.add_child(G.section("Le XV junior", "La sélection est distincte de la feuille professionnelle."))
		for slot in data.positions.size():
			var choices: Array = [["", "Choisir un Espoir"]]
			for player: Dictionary in data.players:
				if player.pos == data.positions[slot]: choices.append([player.id, player.name])
			_choice(list, "%d · %s" % [slot + 1, data.positions[slot]], choices, func(value):
				if value != "": _send(app, data, "academy_lineup", {"slot":slot, "playerId":value})).disabled = data.locked
	list.add_child(G.separator())
	list.add_child(G.section("Investir dans le centre", "Ces dépenses utilisent la trésorerie fictive du club."))
	for kind in ["facilities", "coaches"]:
		var level: int = int(data[kind])
		var fee: int = (level + 1) * (85000 if kind == "facilities" else 55000)
		_action(list, app, data, "%s %d/3 · niveau suivant %s" % ["Installations" if kind == "facilities" else "Éducateurs", level, G.euros(fee)], "academy_upgrade", {"kind":kind}, fee, level >= 3)
	_choice(list, "Objectif annuel · " + str(data.goal), [["formation","Deux objectifs individuels"],["promotions","Deux promotions professionnelles"],["prets","Un prêt à 200 minutes"]], func(value): _send(app, data, "academy_goal", {"goal":value})).disabled = data.locked
	_choice(list, "Identité de formation · " + str(data.identity), [["polyvalence","Polyvalence"],["mouvement","Mouvement"],["puissance","Puissance"],["defense","Défense"]], func(value): _send(app, data, "academy_identity", {"identity":value})).disabled = data.locked
	_action(list, app, data, "RÉUNION DE COHÉSION · 2 000 €", "academy_meeting", {}, 2000)
	list.add_child(G.wrap("Cohésion %d/100 · réputation %d/100. Trois réunions maximum par saison ; les effets annuels sont enregistrés une seule fois." % [data.cohesion, data.reputation], 14))
	for result: Dictionary in data.results:
		list.add_child(G.wrap("Période %d · %s  %d – %d  %s" % [int(result.round)+1, result.homeCenter, result.score[0], result.score[1], result.awayCenter], 15))

static func _players(list: VBoxContainer, app: Control, data: Dictionary) -> void:
	var filters: Array = [["all","Tous les Espoirs"],["young","20 ans et moins"],["minutes","Moins de 240 minutes"],["ready","20 ans et plus"]]
	var holder := G.v(12)
	var filter := _choice(list, "Filtrer le centre", filters, func(value):
		for child in holder.get_children(): holder.remove_child(child); child.queue_free()
		for p: Dictionary in data.players:
			if value == "young" and p.age > 20: continue
			if value == "minutes" and p.minutes >= 240: continue
			if value == "ready" and p.age < 20: continue
			_player(holder, app, data, p))
	filter.name = "AcademyFilter"
	list.add_child(holder)
	for p: Dictionary in data.players: _player(holder, app, data, p)

static func _player(parent: Node, app: Control, data: Dictionary, p: Dictionary) -> void:
	var card := G.card(parent, G.accent_ink(app.accent))
	card.set_meta("academy_player", p.id)
	G.person(card, p, p.name, "%s · %d ans · %d / %d · condition %d%%" % [p.pos, p.age, p.rating, p.potential, p.condition])
	if float(p.target) > 0: G.gauge(card, "Minutes juniors / objectif", float(p.minutes), float(p.target))
	card.add_child(G.wrap("%d minutes juniors · objectif %d · parcours %s" % [p.minutes, p.target, p.path], 15))
	var detail := VBoxContainer.new()
	detail.visible = false
	card.add_child(G.button("OUVRIR LE PARCOURS INDIVIDUEL", func(): detail.visible = not detail.visible))
	card.add_child(detail)
	_choice(detail, "Trajectoire choisie", [["equilibre","Équilibre"],["minutes","Donner des minutes"],["progression","Développer le potentiel"],["professionnel","Préparer le passage pro"]], func(value): _send(app, data, "academy_path", {"playerId":p.id,"strategy":value})).disabled = data.locked
	_choice(detail, "Objectif de minutes", [[480,"480 minutes"],[960,"960 minutes"],[1440,"1 440 minutes"]], func(value): _send(app, data, "academy_target", {"playerId":p.id,"minutes":value})).disabled = data.locked
	_choice(detail, "Objectif individuel · trois joueurs maximum", [["minutes","Temps de jeu"],["progression","Progression"],["regularite","Régularité"]], func(value): _send(app, data, "academy_plan", {"playerId":p.id,"target":value})).disabled = data.locked
	for focus in ["technique","mental","physique"]:
		_action(detail, app, data, "ACCOMPAGNEMENT %s · 8 000 €" % str(focus).to_upper(), "academy_mentor", {"playerId":p.id,"focus":focus}, 8000, data.weekMentored)
	var mentors: Array = [["", "Choisir un professionnel du même poste"]]
	for senior: Dictionary in data.seniors:
		if senior.pos == p.pos and senior.age >= 23: mentors.append([senior.id, senior.name])
	_choice(detail, "Mentorat de saison · trois binômes maximum", mentors, func(value):
		if value != "": _send(app, data, "academy_pair", {"playerId":p.id,"seniorId":value})).disabled = data.locked
	_choice(detail, "Spécialisation annuelle", [["puissance","Puissance"],["vitesse","Vitesse"],["endurance","Endurance"],["technique","Technique"]], func(value): _send(app, data, "academy_specialize", {"playerId":p.id,"kind":value})).disabled = data.locked
	_choice(detail, "Charge de travail", [["equilibree","Équilibrée"],["allegee","Allégée"],["intensive","Intensive"]], func(value): _send(app, data, "academy_load", {"playerId":p.id,"load":value})).disabled = data.locked
	_choice(detail, "Entretien · engagement évalué en fin de saison", [["minutes","Promettre des minutes"],["promouvoir","Préparer une promotion"],["preter","Préparer un prêt"],["refuser","Refuser la demande"]], func(value): _send(app, data, "academy_interview", {"playerId":p.id,"answer":value})).disabled = data.locked
	_choice(detail, "Ambition du joueur", [["accompagner","Accompagner"],["patienter","Patienter"],["professionnel","Passer professionnel"],["pret","Prêt"]], func(value): _send(app, data, "academy_ambition", {"playerId":p.id,"decision":value})).disabled = data.locked
	_action(detail, app, data, "STAGE U20 FICTIF", "academy_u20", {"playerId":p.id}, -1, p.age > 20 or p.injury > 0)
	for offer: Dictionary in data.offers:
		if offer.id != p.id or offer.clubs.is_empty(): continue
		_action(detail, app, data, "FIDÉLISER FACE À LA CONCURRENCE · %s" % G.euros(offer.fee), "academy_retain", {"playerId":p.id,"clubId":offer.clubs[0].clubId}, int(offer.fee), offer.retained)
	for year in [1,2,3]:
		_action(detail, app, data, "ENGAGEMENT ESPOIR %d AN(S) · %s" % [year, G.euros(p.contractFees[year-1])], "academy_contract", {"playerId":p.id,"years":year}, int(p.contractFees[year-1]))
		var salary: int = int(p.promotionSalary[year-1])
		var b := G.button("PREMIER CONTRAT PRO %d AN(S) · %s/SEM." % [year, G.euros(salary)], func(): _send(app, data, "academy_promote", {"playerId":p.id,"years":year}, "Premier contrat professionnel", "%s quittera le centre et ajoutera %s par semaine à la masse salariale pour %d saison(s). Confirmer ?" % [p.name,G.euros(salary),year]))
		b.disabled = data.locked or not data.promotionAvailable
		detail.add_child(b)
	card.add_child(G.separator())

static func _scouting(list: VBoxContainer, app: Control, data: Dictionary) -> void:
	list.add_child(G.section("Observer les autres centres", "Enveloppe junior distincte de la trésorerie senior. Le centre cédant conserve au moins 15 joueurs et ses postes."))
	for center: Dictionary in data.centers:
		if center.own: continue
		list.add_child(G.wrap("%s · %s · %d joueurs" % [center.name,center.division,center.count], 18, G.INK))
		_action(list, app, data, "OBSERVER · 1 200 €", "academy_center_scout", {"centerId":center.id}, 1200, center.scouted or center.count <= 15)
		for p: Dictionary in center.candidates:
			list.add_child(G.wrap("%s · %s · %d / %d" % [p.name,p.pos,p.rating,p.potential],15))
			_action(list, app, data, "PROPOSER %s" % G.euros(p.fee), "academy_recruit", {"playerId":p.id,"offer":p.fee}, int(p.fee))
		list.add_child(G.separator())

static func _network(list: VBoxContainer, app: Control, data: Dictionary) -> void:
	list.add_child(G.section("Les filières fictives", "Observations, essai et accord du joueur. Les autorisations internationales sont simulées ; elles n’attestent aucune conformité réelle."))
	for region in ["Atlantique","Bretagne","Centre","Sud-Ouest","Mediterranee","Alpes"]:
		_action(list, app, data, "DÉTECTER · %s · 3 000 €" % region, "academy_discover", {"region":region}, 3000)
	for feeder: Dictionary in data.feeders:
		_action(list, app, data, "PARTENARIAT · %s · 2 000 €" % feeder.name, "academy_partner", {"feederId":feeder.id}, 2000, data.partners.has(feeder.id))
	for p: Dictionary in data.prospects:
		list.add_child(G.separator())
		list.add_child(G.section(p.name, "%s · %s · %d ans" % [p.clubName,p.pos,p.age]))
		list.add_child(G.wrap("Observations %d/3 · essai %s · note estimée %s · potentiel %s" % [p.scouted,"réalisé" if p.trial else "à organiser",str(p.rating) if p.scouted > 0 else "?",str(p.potential) if p.scouted > 1 else "?"],14))
		_action(list, app, data, "OBSERVER · 500 €", "academy_watch", {"playerId":p.id}, 500, p.scouted >= 3)
		_action(list, app, data, "ESSAI · 1 000 €", "academy_trial", {"playerId":p.id}, 1000, p.trial or p.scouted == 0)
		if p.union != "FR": _action(list, app, data, "ENREGISTRER L’AUTORISATION SIMULÉE", "academy_clearance", {"playerId":p.id}, -1, p.age < 18 or not p.trial or p.get("clearanceRecorded",false))
		_action(list, app, data, "PROPOSER LE PROJET · 8 000 € SI ACCEPTÉ", "academy_feeder_recruit", {"playerId":p.id}, 8000, p.scouted < 2 or not p.trial or p.age < 16)

static func _professionals(list: VBoxContainer, app: Control, data: Dictionary) -> void:
	list.add_child(G.section("Prêter un jeune professionnel", "Un déplacement réel du joueur vers un autre effectif. Retour à l’intersaison ; le club d’origine doit conserver une place."))
	for p: Dictionary in data.seniors:
		if not p.loanEligible: continue
		var options: Array = [[-1,"Choisir le club d’accueil"]]
		for club: Dictionary in data.loanClubs: options.append([club.id,club.name])
		_choice(list, p.name, options, func(value):
			if int(value) >= 0: _send(app,data,"academy_loan",{"playerId":p.id,"to":value},"Confirmer le prêt",p.name + " sera transféré dans l’effectif choisi jusqu’à l’intersaison.")).disabled = data.locked
	for loan: Dictionary in data.loans: list.add_child(G.wrap("Prêt en cours · %s → club %d" % [loan.name,loan.to],15))
	if data.loans.is_empty(): list.add_child(G.wrap("Aucun prêt en cours. Les joueurs de la feuille de 23 doivent d’abord être retirés de la sélection.",15))

static func _history(list: VBoxContainer, data: Dictionary) -> void:
	list.add_child(G.section("La mémoire des générations", "Quinze saisons maximum, archivées une seule fois. Les données sont des résultats de votre simulation."))
	if data.generations.is_empty(): list.add_child(G.wrap("La première génération sera archivée à la fin de cette saison.",18))
	for generation: Dictionary in data.generations:
		list.add_child(G.section("Saison %d" % generation.season, "%d joueurs suivis · %d promotions · réputation %d" % [generation.players.size(),generation.graduates,generation.reputation]))
		for p: Dictionary in generation.players:
			list.add_child(G.wrap("%s · %s · %d/%d · %d minutes · %s" % [p.name,p.pos,p.rating,p.potential,p.minutes,p.strategy],14))
		list.add_child(G.separator())
