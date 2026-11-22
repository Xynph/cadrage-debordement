extends RefCounted
const Copy = preload("res://ui/management_copy.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/carnet_skin.gd")
const C = preload("res://ui/immersive08/components.gd")

## Prix indexés envoyés par le moteur (carrière Monde) ; prix historiques sinon.
static func cost(data: Dictionary, key: String, fallback: int, level: int = -1) -> int:
	var value: Variant = data.get("costs", {}).get(key, null)
	if level >= 0: value = value[level] if value is Array and level < value.size() else null
	return int(value) if value is int or value is float else fallback

static func _send(app: Control, data: Dictionary, command: String, payload: Dictionary, title: String = "", detail: String = "") -> void:
	var args: Dictionary = data.context.duplicate()
	args.merge(payload, true)
	if title.is_empty():
		app._command(command, args)
	else:
		args.confirmed = true
		preload("res://ui/immersive08/formation_pages.gd").confirmer(app, title, detail, func(): app._command(command, args))

static func _action(parent: Node, app: Control, data: Dictionary, label: String, command: String, payload: Dictionary = {}, cost: int = -1, disabled: bool = false) -> Button:
	var title := label if cost >= 0 else ""
	var detail := "Confirmer cette décision ?" if cost == 0 else "Dépense de %s pour le centre. Confirmer ?" % G.euros(cost)
	var b := G.button(label, func(): _send(app, data, command, payload, title, detail))
	b.name = command + "_" + str(payload.get("playerId", payload.get("centerId", "action"))).replace(":", "_")
	b.disabled = data.get("locked", false) or disabled
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(b)
	return b

## `current` : valeur active envoyée par le moteur, affichée au lieu de la première option.
static func _choice(parent: Node, caption: String, options: Array, callback: Callable, current: Variant = null) -> OptionButton:
	parent.add_child(G.wrap(caption, 13))
	var option := OptionButton.new()
	option.custom_minimum_size.y = 44
	for entry in options:
		option.add_item(str(entry[1]))
		option.set_item_metadata(option.item_count - 1, entry[0])
		if current != null and str(entry[0]) == str(current): option.select(option.item_count - 1)
	option.item_selected.connect(func(index: int): callback.call(option.get_item_metadata(index)))
	parent.add_child(option)
	return option

static func build(app: Control, initial_tab: String = "") -> Control:
	var data: Dictionary = app.model.get("clubLife", {}).get("academyPathways", {})
	# Parcours actifs : mêmes pages que la grande vue façon Effectif, en conteneurs (centre_compact.gd).
	# Chargé à l'appel : la grande vue précharge déjà ce fichier.
	if data.get("available", false) and data.get("active", false):
		return load("res://ui/immersive08/centre_compact.gd").build(app, initial_tab)
	var page := G.v(12)
	page.name = "CarnetAcademyPathways"
	G.fill(page, true)
	var paper := G.panel(page)
	G.fill(paper.get_parent(), true)
	G.fill(paper, true)
	G.chapter(paper, "21", "Les parcours de formation", "", app.accent)
	if not data.get("available", false):
		paper.add_child(G.wrap(data.get("reason", "Le centre est disponible dans une carrière active."), 18))
		_preview(paper, app, data, false)
		return page
	var world: bool = data.get("world", false)
	if not str(data.get("description", "")).is_empty(): paper.add_child(G.wrap(Copy.notice("academy", data.description), 13))
	if not data.get("active", false):
		if not world: paper.add_child(G.wrap("Les %d Espoirs actuels restent dans ton centre. Activer les parcours ajoute la détection, les mentorats et les compétitions juniors à cette carrière." % data.players.size(), 18))
		_action(paper, app, data, "ACTIVER LES PARCOURS", "academy_activate", {}, 0)
		_preview(paper, app, data, true)
		return page
	return page

## Centre sans parcours actifs (lisible dès 1280 × 720) : les chiffres du centre, les trois parcours
## illustrés et le chemin vers Formation, plutôt qu'une page vide. Lecture seule, aucune commande.
static func _preview(paper: VBoxContainer, app: Control, data: Dictionary, open: bool) -> void:
	var players: int = data.get("players", []).size()
	var figures := G.h(18)
	figures.name = "AcademyPreviewFigures"
	paper.add_child(figures)
	figures.add_child(G.metric(G.n(players), "Espoirs suivis au centre", G.GOOD))
	for fact: Array in [["places", "places professionnelles disponibles", G.GOLD], ["cohesion", "cohésion du centre", G.INK], ["reputation", "réputation du centre", G.INK]]:
		if data.get(fact[0]) is int or data.get(fact[0]) is float: figures.add_child(G.metric(G.n(data.get(fact[0])), fact[1], fact[2]))
	var offers := G.h(14)
	offers.name = "AcademyPreviewPathways"
	G.fill(offers, true)
	paper.add_child(offers)
	for offer: Array in [
		["Detection", "Détection", "scouting", "Mener la campagne de détection du centre pour préparer la prochaine génération."],
		["Mentoring", "Mentorat", "analysis-room", "Associer un Espoir à un joueur senior du même poste et suivre son accompagnement."],
		["Junior", "Compétition junior", "lineout-analysis", "Préparer les rencontres juniors et suivre leur calendrier, distinct du championnat professionnel."],
	]:
		var card := G.card(offers, G.accent_ink(app.accent))
		var frame := card.get_parent() as Control
		frame.name = "AcademyPreview" + str(offer[0])
		G.fill(frame, true)
		var picture := C.photo(str(offer[2]), Vector2(0, 150), true, .4)
		picture.tooltip_text = str(offer[1])
		G.fill(picture, true)
		card.add_child(picture)
		if not open: card.add_child(G.label("AU CALENDRIER DES ESPOIRS", 12, G.GOLD))
		card.add_child(G.label(offer[1], 20, G.INK, true))
		card.add_child(G.wrap(offer[3], 13))
	var follow := G.card(paper, G.accent_ink(app.accent))
	follow.get_parent().name = "AcademyPreviewFollow"
	var row := G.h(16)
	follow.add_child(row)
	var words := G.v(2)
	G.fill(words)
	row.add_child(words)
	words.add_child(G.label("Tes %s Espoirs restent au centre." % G.n(players), 20, G.INK, true))
	words.add_child(G.wrap("Leur progression, leurs promotions et leurs spécialisations se suivent dans Formation.", 13))
	var go := G.button("CONSULTER LES ESPOIRS  →", func(): app._navigate("Formation"), true)
	go.name = "AcademyPreviewFormation"
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(go)

static func _professionals(list: VBoxContainer, app: Control, data: Dictionary, player_id: String = "") -> void:
	var world: bool = data.get("world", false)
	list.add_child(G.section("Prêter un jeune professionnel", "" if world else "Un déplacement réel du joueur vers un autre effectif. Retour à l’intersaison ; le club d’origine doit conserver une place."))
	for p: Dictionary in data.seniors:
		if not p.loanEligible or (not player_id.is_empty() and str(p.id)!=player_id): continue
		var options: Array = [[-1,"Choisir le club d’accueil"]]
		for club: Dictionary in data.loanClubs: options.append([club.id,club.name])
		var choice := _choice(list, p.name, options, func(value):
			if int(value) >= 0: _send(app,data,"academy_loan",{"playerId":p.id,"to":value},"Confirmer le prêt",p.name + " sera transféré dans l’effectif choisi jusqu’à l’intersaison."))
		choice.name = "YouthPathwayLoanClub"
		choice.set_meta("player_id",p.id)
		choice.disabled = data.locked or app.waiting
	for loan: Dictionary in data.loans:
		var host := "club %d" % int(loan.to)
		for c: Dictionary in data.get("centers", []):
			if c.get("clubId") == loan.to: host = str(c.name)
		list.add_child(G.wrap("Prêt en cours · %s → %s" % [loan.name, host],15))
	if data.loans.is_empty():
		if world: list.add_child(G.metric(0, "prêts en cours"))
		else: list.add_child(G.wrap("Aucun prêt en cours. Les joueurs de la feuille de 23 doivent d’abord être retirés de la sélection.",15))

static func open_professional(app: Control, player_id: String) -> AcceptDialog:
	app._clear_dialogs()
	var dialog := AcceptDialog.new()
	dialog.name = "YouthLoanPathway"
	dialog.title = "Examiner le prêt du jeune professionnel"
	dialog.get_ok_button().text = "FERMER"
	app._prepare_dialog(dialog,760)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	dialog.add_child(scroll)
	var list := G.v(12)
	G.fill(list,true)
	scroll.add_child(list)
	var data: Dictionary = app.model.get("clubLife",{}).get("academyPathways",{})
	if not data.get("available",false): list.add_child(G.wrap(str(data.get("reason","Parcours indisponible dans cette édition.")),16))
	elif not data.get("active",false):
		list.add_child(G.wrap("Le prêt nécessite les parcours du centre. Leur activation est une décision distincte ; reviens ensuite à ce joueur pour choisir son club d’accueil.",16))
		_action(list,app,data,"ACTIVER LES PARCOURS","academy_activate",{},0)
	else:
		var eligible: Array = data.get("seniors",[]).filter(func(p: Dictionary): return str(p.id)==player_id and p.get("loanEligible",false))
		if eligible.is_empty(): list.add_child(G.wrap("Ce joueur n’est plus éligible au prêt dans le contexte actuel. Vérifie notamment sa présence sur la feuille de 23 et son contrat.",16))
		else: _professionals(list,app,data,player_id)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	preload("res://ui/immersive08/dialogs.gd").show_centered(dialog,Vector2i(760,400))
	return dialog
