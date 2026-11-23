extends RefCounted
## Club › Direction (« Les moyens de tes ambitions »), choix de Léo du 21/11/2026 sur la revue visuelle n° 2 :
## Finances = règle à trois crans pour la relève + tuiles des partenaires avec mini-histogramme semaine / avance /
## victoire ; Projet sportif = plan des dirigeants sur 5 saisons en tableau + tuiles d'offre des projets ; Supporters =
## les tribunes (anneau de l'humeur unique des supporters, une ligne par groupe ; supporters_camembert.gd, option B de
## Léo du 23/11/2026), billetterie (affluence prévue, abonnés, effet de l'humeur sur le public, prix) puis tuiles des
## actions, appliquées au clic. Explications derrière un « i » ; chaque chiffre ou jauge ouvre son écran ou une petite
## fenêtre visuelle ; chaque tuile agit comme sa pilule ; l'argent se confirme en place (confirmation_en_place.gd).
const Copy = preload("res://ui/management_copy.gd")
const Champs = preload("res://ui/immersive08/champs_charte.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/carnet_skin.gd")
const C = preload("res://ui/immersive08/components.gd")
const Tuile = preload("res://ui/tuile_choix.gd")
const LienZone = preload("res://ui/lien_zone.gd")
const Visuel = preload("res://ui/strategy_visuals.gd")
const JaugeAnneau = preload("res://ui/jauge_anneau.gd")
const Supporters = preload("res://ui/supporters_camembert.gd")
const Billetterie = preload("res://ui/billetterie_vue.gd")

const PRIX := {"accessible":"Accessible", "equilibree":"Équilibrée", "premium":"Premium"}
const STATUTS := {"pending":["À suivre", "clock", Charte.GRIS_VERT], "met":["Atteint", "check", Charte.V], "missed":["Manqué", "warning", Charte.D], "unverified":["Non vérifiable", "info", Charte.GRIS_VERT]}

static func _send(app: Control, command: String, payload: Dictionary, confirmation: String = "") -> void:
	var values := payload.duplicate(true)
	values.context = app.model.clubLife.clubStrategy.context.duplicate(true)
	if confirmation.is_empty():
		app._command(command, values)
	else:
		values.confirmed = true
		app.confirm_decision(command, values, "Engager le club", confirmation, func(): app._command(command, values))

## Chiffre clé (gros chiffre, légende) ; `open` : ce qu'ouvre un clic (écran ou petite fenêtre), sinon apparence neutre.
static func _amount(parent: Container, label: String, value: String, color: Color = G.INK, name: String = "", destination: String = "", open: Callable = Callable()) -> VBoxContainer:
	var column := G.v(2)
	G.fill(column)
	parent.add_child(column)
	column.add_child(G.label(value, 29, color, true))
	column.add_child(G.label(label, 12, G.MUTED))
	if open.is_valid(): LienZone.relier(column, name, destination, open)
	return column

static func _go(app: Control, route: String) -> Callable:
	return func(): app._navigate(route)

## Pilule d'une décision du club (charte : contour, texte crème). Grisée : la raison connue passe en info-bulle.
static func _choice(app: Control, command: String, payload: Dictionary, blocked: bool, confirmation: String = "", text: String = "Choisir", reason: String = "") -> Button:
	var name := command + "_" + str(payload.get("key", payload.get("kind", payload.get("amount", "action"))))
	return Tuile.pilule(text, name, not blocked, reason, func(): _send(app, command, payload, confirmation))

## Pastille « Trésorerie insuffisante » : ouvre l'écran Finances.
static func _short(app: Control, name: String) -> Control:
	return LienZone.relier(Tuile.pastille("Trésorerie insuffisante", Visuel.ORANGE, "warning"), name, "Finances", _go(app, "Finances"))

## Choix exclusif (cap du club, politique de prix) : pilule de la charte, le choix courant en aplat crème avec une coche.
static func _toggle(text: String, callback: Callable, chosen: bool) -> Button:
	var button := C.button(text, callback)
	button.set_meta("style_charte", true)
	if chosen:
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, C.box(Charte.IVOIRE, Color.TRANSPARENT, Charte.RAYON_PILULE, 18))
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			button.add_theme_color_override(key, Charte.PANNEAU)
		button.icon = Visuel.picto_texture("check", Charte.PANNEAU)
		button.add_theme_constant_override("icon_max_width", C.px(24))
	return button

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
	G.chapter(paper, "15", "Les moyens de tes ambitions", "", app.accent)
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
	_amount(amounts, "TRÉSORERIE DISPONIBLE", G.euros(f.cash), G.GOOD if f.cash >= 0 else G.ALERT, "DirectionLien_Tresorerie", "Finances", _go(app, "Finances"))
	_amount(amounts, "SALAIRES "+G.salary_period(true).to_upper(), G.salary_amount(f.weeklyWages), G.INK, "DirectionLien_Salaires", "Finances", _go(app, "Finances"))
	_amount(amounts, "PROJECTION DES ENGAGEMENTS", G.euros(f.baseForecast), G.GOLD, "DirectionLien_Projection", "Finances", _go(app, "Finances"))
	_amount(amounts, "SEMAINES RESTANTES", "%d / %d" % [f.remainingWeeks, f.weeksPerSeason], G.INK, "DirectionLien_Semaines", "Calendrier", _go(app, "Calendrier"))
	amounts.add_child(Tuile.info(Copy.notice("strategy", f.notice)))
	if not f.facility is Dictionary:
		card.add_child(Tuile.pastille("Installations · aucun devis", Charte.GRIS_VERT, "settings"))
	var columns := G.h(16)
	page.add_child(columns)
	var investments := G.v(14)
	G.fill(investments)
	columns.add_child(investments)
	var partners := G.v(14)
	G.fill(partners)
	columns.add_child(partners)
	var trained: bool = app.model.meta.trained
	var academy := G.panel(investments)
	academy.add_child(Tuile.titre_bloc("Financer la relève", "L’engagement est prélevé à la séance ; il développe les Espoirs."))
	var notches: Array = []
	var pills: Array = []
	for amount in [0, 4000, 12000]:
		var current: bool = f.academyInvestment == amount
		notches.append({"valeur":amount, "actuel":current})
		pills.append(_choice(app, "club_academy_investment", {"amount":amount}, locked or trained or current, "Engager %s à chaque séance de formation ?" % G.euros(amount), "%s / semaine" % G.euros(amount), "Montant actuel" if current else ""))
	var ruler := Visuel.Regle.new(notches, pills)
	ruler.name = "StrategieRegleReleve"
	academy.add_child(ruler)
	_amount(academy, "DÉJÀ INVESTI CETTE SAISON", G.euros(f.academySpent), G.INK, "DirectionLien_Releve", "Formation", _go(app, "Formation"))
	if f.facility is Dictionary:
		var q: Dictionary = f.facility
		var facility := G.panel(investments)
		var blocked: bool = locked or trained or q.used or not q.affordable
		var reason := "Une amélioration par saison" if q.used else "Trésorerie insuffisante" if not q.affordable else ""
		var row := G.h(12)
		facility.add_child(row)
		var tile := Visuel.tuile_offre(row, "settings", "Installations", G.euros(q.cost), "niveau %d / 10" % q.level, _choice(app, "club_facility_upgrade", {"cost":q.cost,"level":q.level}, blocked, "Investir %s pour passer les installations au niveau %d ?" % [G.euros(q.cost), q.nextLevel], "Choisir", reason), _short(app, "DirectionLien_InstallationsTresorerie") if not q.affordable and not q.used else null, null, "Entretien du prochain niveau indiqué au devis. Une amélioration par saison.")
		# Grille de trois places comme les partenaires (colonnes de même largeur) : la tuile prend la place du milieu,
		# même largeur que les tuiles d'en face, jamais étirée seule sur toute la colonne.
		for side in [0, 2]:
			var slot := Control.new()
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(slot)
			row.move_child(slot, side)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sponsors := G.panel(partners)
	sponsors.add_child(Tuile.titre_bloc("Choisir son partenaire", "Une signature par saison, avant la cinquième journée."))
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
		Visuel.tuile_offre(cards, "poignee", offer.label, G.euros(offer.weekly), "par semaine", _choice(app, "club_sponsor_sign", {"key":offer.id}, locked or not offer.available, "Signer « %s » ? %s." % [offer.label, detail], "Choisir", "Partenaire signé" if offer.selected else ""), Tuile.pastille("Signé", Charte.V, "check") if offer.selected else null, chart)

static func _goal_label(goal: Dictionary) -> String:
	var target := G.n(goal.target)
	match str(goal.type):
		"wins": target = "Victoires ≥ " + target
		"points": target = "Points ≥ " + target
		"rank": target = "Classement ≤ " + target
		"cash": target = "Trésorerie ≥ " + G.euros(goal.target)
		_: target = str(goal.type) + " · " + target
	return "%s · S%d" % [target, int(goal.deadline)]

static func _board(app: Control, page: Container, data: Dictionary, locked: bool) -> void:
	var b: Dictionary = data.board
	var card := G.panel(page)
	card.add_child(Tuile.titre_bloc("Donner un cap", "Une priorité claire pour arbitrer les décisions.\n\n" + Copy.notice("strategy", b.notice)))
	var row := G.h(10)
	card.add_child(row)
	for key: String in ["performance", "stabilite", "finances", "effectif"]:
		var names := {"performance":"Résultats", "stabilite":"Stabilité", "finances":"Finances", "effectif":"Effectif"}
		var button := _toggle(names[key], func(): _send(app, "club_board_priority", {"key":key}), b.priority == key)
		button.name = "BoardPriority_" + key
		button.disabled = locked
		row.add_child(button)
	var health := G.h(18)
	card.add_child(health)
	_amount(health, "JOUEURS DISPONIBLES", G.n(b.readiness.available), G.INK, "DirectionLien_Disponibles", "Effectif", _go(app, "Effectif"))
	_amount(health, "CONDITION SATISFAISANTE", "%d %%" % b.readiness.coverage, G.INK, "DirectionLien_Condition", "Effectif", _go(app, "Effectif"))
	_amount(health, "ORGANISATION", "%d / 100" % b.organizationScore, G.GOLD, "DirectionLien_Organisation", "Organisation du club", func(): _organisation(app, b))
	G.gauge(card, "Disponibilité du groupe", float(b.readiness.coverage), 100, G.GOOD)
	LienZone.relier(card.get_child(card.get_child_count() - 1), "DirectionLien_Jauge", "Effectif", _go(app, "Effectif"))
	var projects := G.panel(page)
	projects.add_child(Tuile.titre_bloc("Structurer le club", "Projets d’organisation, sans bonus de match automatique."))
	var cards := G.h(12)
	projects.add_child(cards)
	for project: Dictionary in b.projectOptions:
		var short: bool = data.finance.cash < project.cost
		var state: Control = Tuile.pastille("Engagé", Charte.V, "check") if project.used else _short(app, "DirectionLien_Projet_" + str(project.id)) if short else null
		Visuel.tuile_offre(cards, {"video":"video", "medical":"croix", "logistique":"camion"}.get(project.id, "settings"), project.label, G.euros(project.cost), "paiement unique", _choice(app, "club_board_project", {"kind":project.id}, locked or project.used or short, "Financer %s pour %s ?" % [project.label, G.euros(project.cost)], "Choisir", "Déjà engagé" if project.used else "Trésorerie insuffisante" if short else ""), state)
	var objectives := G.panel(page)
	var empty := "Fixe un premier jalon. Les objectifs servent au suivi du projet ; la confiance du président dépend du bilan du club."
	var plan: Array = b.get("plan", [])
	if plan.is_empty(): objectives.add_child(Tuile.titre_bloc("Les rendez-vous du conseil", "Objectifs suivis depuis les résultats de ta carrière." + ("\n\n" + empty if b.objectives.is_empty() else "")))
	else:
		objectives.add_child(Tuile.titre_bloc("Plan sur 5 ans", "Saison en cours : jalons du conseil. Saisons suivantes : projection vers l’objectif du club."))
		Supporters.plan_cinq_ans(app, objectives, plan)
		# Plan des dirigeants en tête de l'onglet (planche FM27 n° 15).
		var racine: Node = objectives
		while racine.get_parent() != page: racine = racine.get_parent()
		page.move_child(racine, 0)
	for goal: Dictionary in ([] if not plan.is_empty() else b.objectives):
		var line := G.h(12)
		objectives.add_child(line)
		var text := C.label(_goal_label(goal), 22, Charte.IVOIRE, true, 600)
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(text)
		var status: Array = STATUTS.get(str(goal.status), [str(goal.status), "info", Charte.GRIS_VERT])
		line.add_child(Tuile.pastille(status[0], status[2], status[1]))
		Tuile.proteger(line)
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
	var season_over: bool = data.context.week >= data.finance.weeksPerSeason
	var add := Tuile.pilule("Fixer le jalon", "BoardObjectiveAdd", not (locked or season_over), "Saison terminée" if season_over else "", func(): _send(app, "club_board_objective", {"type":["wins","points","rank","cash"][kind.selected],"target":target.value,"deadline":int(deadline.value)}))
	goal_row.add_child(add)

static func _fans(app: Control, page: Container, data: Dictionary, locked: bool) -> void:
	var f: Dictionary = data.fans
	var profil: Dictionary = f.get("supporters", {})
	if not profil.is_empty(): Supporters.tribunes(app, page, profil, func(): _public(app, f))
	G.photo_note(page, app.model.club, "Le territoire", "Une ville derrière toi", "city", 140)
	var card := G.panel(page)
	card.name = "SupportersBilletterie"
	var open := func(): _public(app, f)
	# Billetterie réelle (choix de Léo du 23/11/2026) : stade rempli, trois prix au curseur, responsable de la billetterie
	# (billetterie_vue.gd) ; estimations ≈ seulement. Sans budget de saison : l'ancienne politique de prix.
	if f.has("ticketing"):
		card.add_child(Tuile.titre_bloc("Billetterie"))
		Billetterie.construire(card, f, locked, func(commande: String, donnees: Dictionary): _send(app, commande, donnees), open)
	else:
		card.add_child(Tuile.titre_bloc("Billetterie", "L’humeur des supporters fait varier le public de chaque match à domicile.

" + Copy.notice("strategy", f.notice)))
		# Trois cellules de même largeur sur toute la carte, contenu centré : espacement régulier, milieux alignés.
		var metrics := G.h(0)
		card.add_child(metrics)
		var cell := func() -> CenterContainer:
			var box := CenterContainer.new()
			box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.size_flags_stretch_ratio = 1.0
			metrics.add_child(box)
			Tuile.proteger(box)
			return box
		LienZone.relier(Visuel.chiffre_picto(cell.call(), "people", G.n(f.expectedAttendance), "AFFLUENCE PRÉVUE"), "DirectionLien_Affluence", "Le public", open)
		LienZone.relier(Visuel.chiffre_picto(cell.call(), "heart", _pourcent(int(f.get("humeurPublic", 0))), "PUBLIC · HUMEUR"), "DirectionLien_Humeur", "Le public", open)
		LienZone.relier(Visuel.chiffre_picto(cell.call(), "star", G.n(f.subscribers), "ABONNÉS"), "DirectionLien_Abonnes", "Le public", open)
		var price_row := G.h(10)
		card.add_child(price_row)
		for price: Dictionary in f.prices:
			var button := _toggle("%s · %s" % [PRIX.get(price.id, str(price.id).capitalize()), G.euros(price.price)], func(): _send(app, "club_fans_price", {"key":price.id}), f.policy == price.id)
			button.name = "FansPrice_" + str(price.id)
			button.disabled = locked
			price_row.add_child(button)
	for category: Dictionary in [{"title":"Faire venir","key":"campaigns","command":"club_fans_campaign","icon":"people"},{"title":"Tisser des liens","key":"community","command":"club_fans_community","icon":"heart"},{"title":"Accueillir au stade","key":"services","command":"club_fans_service","icon":"home"}]:
		var actions := G.panel(page)
		actions.add_child(Tuile.titre_bloc(category.title, "Dépenses prévues, sans nouvelle recette automatique."))
		var cards := G.h(12)
		actions.add_child(cards)
		for option: Dictionary in f[category.key]:
			var short: bool = data.finance.cash < option.cost
			var state: Control = Tuile.pastille("Déjà engagé", Charte.V, "check") if option.used else _short(app, "DirectionLien_%s_%s" % [category.key, option.id]) if short else null
			# Clic = appliqué (règle de Léo du 23/11/2026) : ni confirmation ni bouton Valider.
			Visuel.tuile_offre(cards, category.icon, option.label, G.euros(option.cost), "", _choice(app, category.command, {"key":option.id, "confirmed":true}, locked or option.used or short, "", "Choisir", "Déjà engagé" if option.used else "Trésorerie insuffisante" if short else ""), state)

## Saison lisible d'une entrée d'historique (saison, sinon semaine).
static func _when(entry: Dictionary) -> String:
	if entry.has("season"): return G.season_label(entry.season)
	return "S%d" % int(entry.get("week", 0))

## Effet en pour cent, signé (« +6 % », « −4 % », « = »).
static func _pourcent(valeur: int) -> String:
	if valeur > 0: return "+%d %%" % valeur
	if valeur < 0: return "−%d %%" % absi(valeur)
	return "="

## Petite fenêtre « Le public » : humeur des supporters (la seule, celle des tribunes) et son effet sur le public,
## affluence et capacité, demande, billet, recette prévue, abonnés, et l'évolution des saisons passées.
static func _public(app: Control, f: Dictionary) -> void:
	var humeur: Variant = f.get("humeur")
	var ton: Array = Supporters.reaction(humeur)
	var ring := JaugeAnneau.new(float(humeur) if humeur != null else 0.0, "Humeur", ton[1], 100.0, "heart")
	ring.name = "PublicHumeur"
	var capacity: Variant = f.get("capacity")
	var estime := f.has("ticketing")
	var first: Array = [ring, Visuel.tuile_chiffre("heart", _pourcent(int(f.get("humeurPublic", 0))), "Public · humeur"), Visuel.tuile_chiffre("people", ("≈ " if estime else "") + G.n(f.expectedAttendance) + ("" if capacity == null else " / " + G.n(capacity)), ("Affluence estimée" if estime else "Affluence prévue") + ("" if capacity == null else " / places"))]
	if f.has("demand"): first.append(Visuel.tuile_chiffre("target", "%d %%" % int(f.demand), "Demande"))
	var second: Array = []
	if estime:
		var t: Dictionary = f.ticketing
		second.append(Visuel.tuile_chiffre("money", G.euros(f.price), "Grosse affiche" if t.get("bigMatch", false) else "Billet"))
		second.append(Visuel.tuile_chiffre("money", "≈ " + G.euros(f.expectedTicketRevenue), "Recette estimée · prochain match"))
		second.append(Visuel.tuile_chiffre("star", "≈ " + G.n(t.get("expectedSubscribers", f.subscribers)), "Abonnés"))
	else:
		if f.has("price"): second.append(Visuel.tuile_chiffre("money", G.euros(f.price), "Billet · " + str(PRIX.get(f.policy, f.policy))))
		if f.has("expectedTicketRevenue"): second.append(Visuel.tuile_chiffre("money", G.euros(f.expectedTicketRevenue), "Recette prévue par match"))
		second.append(Visuel.tuile_chiffre("star", G.n(f.subscribers), "Abonnés"))
	var blocks: Array = [Visuel.rangee(first), Visuel.rangee(second)]
	var history: Array = f.get("history", [])
	if not history.is_empty():
		var moods: Array = []
		var subs: Array = []
		var top := 1.0
		for entry: Dictionary in history: top = maxf(top, float(entry.get("subscribers", 0)))
		for i in range(history.size() - 1, -1, -1):
			var entry: Dictionary = history[i]
			var h: Variant = entry.get("humeur", entry.get("sentiment", 0))
			moods.append({"valeur":h, "maximum":100, "montant":str(int(h)), "critere":_when(entry), "couleur":Supporters.reaction(h)[1]})
			subs.append({"valeur":entry.get("subscribers", 0), "maximum":top, "montant":G.n(entry.get("subscribers", 0)), "critere":_when(entry), "couleur":Visuel.VIOLET})
		blocks.append(Tuile.titre_bloc("Humeur des saisons passées"))
		blocks.append(Visuel.Histogramme.new(moods, 140))
		blocks.append(Tuile.titre_bloc("Abonnés des saisons passées"))
		blocks.append(Visuel.Histogramme.new(subs, 140))
	Visuel.petite_fenetre(app, "DirectionFenetrePublic", "Le public", blocks)

## Petite fenêtre « Organisation du club » : score, projets, missions et risques suivis, bilans passés s'il y en a.
static func _organisation(app: Control, b: Dictionary) -> void:
	var ring := JaugeAnneau.new(float(b.organizationScore), "Organisation", Charte.REPOS, 100.0, "target")
	var blocks: Array = [Visuel.rangee([ring,
		Visuel.tuile_chiffre("target", G.n((b.get("projects", []) as Array).size()), "Projets engagés"),
		Visuel.tuile_chiffre("check", G.n((b.get("missions", []) as Array).size()), "Missions"),
		Visuel.tuile_chiffre("warning", G.n((b.get("risks", []) as Array).size()), "Risques suivis")])]
	var history: Array = b.get("history", [])
	if not history.is_empty():
		var bars: Array = []
		for entry: Dictionary in history:
			var value := float(entry.get("score", entry.get("trust", entry.get("confidence", 0))))
			bars.append({"valeur":value, "maximum":100, "montant":str(int(value)), "critere":_when(entry), "couleur":Charte.REPOS})
		blocks.append(Tuile.titre_bloc("Bilans passés"))
		blocks.append(Visuel.Histogramme.new(bars, 140))
	Visuel.petite_fenetre(app, "DirectionFenetreOrganisation", "Organisation du club", blocks)
