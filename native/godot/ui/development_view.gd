extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const PAGE_SIZE := 6

static func build(app: Control) -> Control:
	var page := G.h(16)
	page.name = "CarnetDevelopment"
	G.fill(page, true)
	var data: Dictionary = app.model.get("decisions", {}).get("development", {})
	if not app.management_ui.has("development"): app.management_ui.development = {"mode":"academy"}
	var state: Dictionary = app.management_ui.development
	var mode := str(state.mode)
	var notes := G.panel(page, .68)
	G.chapter(notes, "11", "La relève", "Faire une place aux générations suivantes.", app.accent)
	var text := G.scroll(notes)
	G.photo_note(text, app.model.club, "Le centre", "La prochaine génération", "stadium", 140)
	text.add_child(G.metric(G.n(data.get("academy", []).size()), "espoirs au centre"))
	var pathways: Dictionary = app.model.get("clubLife", {}).get("academyPathways", {})
	var follow_up := "Retrouvez les rencontres juniors, les trajectoires et les mentorats dans les parcours du centre." if pathways.get("available", false) else "Le suivi individuel des Espoirs reste disponible ici."
	text.add_child(G.wrap("Quinze nouveaux espoirs par saison. Au plus 75 joueurs restent au centre. " + follow_up, 14))
	text.add_child(G.button("PARCOURS DU CENTRE →", func(): app._navigate("Centre")))
	text.add_child(G.wrap("Objectifs des jeunes : suivre les changements observés, sans gain immédiat ajouté.",13))
	preload("res://ui/youth_development_view.gd").entry(app,text)
	text.add_child(G.separator())
	for option in [["academy", "LE CENTRE DE FORMATION"], ["professional", "LES JEUNES PROFESSIONNELS"]]:
		var id: String = "Development" + option[0].capitalize()
		var b := G.button(option[1], func():
			state.mode = option[0]
			app._render()
			preload("res://ui/immersive08/club_ui.gd").focus(app,id))
		b.name = id
		if mode == option[0]: G.selected(b, app.accent)
		text.add_child(b)
	text.add_child(G.wrap("Le potentiel reste une estimation. La promotion ne garantit ni le temps de jeu ni la progression. Le rythme d’évolution dépend du parcours de chaque joueur.", 13))
	text.add_child(G.button("CONSULTER L'EFFECTIF →", func(): app._navigate("Effectif")))
	var body := G.panel(page, 1.95)
	G.chapter(body, "12", "Ouvrir des perspectives", "Poste, travail et minutes réellement disputées.", app.accent)
	var people: Array = data.get("academy", []) if mode == "academy" else data.get("professionals", []).filter(func(p: Dictionary): return p.age <= 23)
	var list := G.scroll(body)
	list.get_parent().name = "DevelopmentList"
	if people.is_empty(): list.add_child(G.wrap("Aucun joueur dans cette catégorie.", 17))
	var bounds := Vector2i(0, people.size())
	if people.size() > PAGE_SIZE:
		bounds = app.ClubViews._paged(app, body, "DevelopmentPagination", people.size(), PAGE_SIZE, "development_" + mode)
	for person: Dictionary in people.slice(bounds.x, bounds.y):
		var card := G.card(list, G.accent_ink(app.accent))
		card.set_meta("development_id", person.id)
		var row := G.h(16)
		card.add_child(row)
		row.add_child(G.portrait(int(person.get("portraitIndex", people.find(person))), 48, person))
		var identity := G.v(3)
		G.fill(identity)
		row.add_child(identity)
		identity.add_child(G.wrap(person.name, 25, G.INK))
		identity.add_child(G.wrap("%s · %s ans · %s minutes · %s apparitions" % [person.pos, G.n(person.age), G.n(person.minutes), G.n(person.appearances)], 13))
		row.add_child(G.metric(G.n(person.note), "note au poste"))
		row.add_child(G.metric(G.n(person.potential), "potentiel estimé"))
		var development: Dictionary = person.get("development", {})
		var history: Array = development.get("history", [])
		var levels: Array = []
		for year: Dictionary in history:
			if year.get("end") is float or year.get("end") is int: levels.append(year.end)
		G.trend(card, levels, "Niveau en fin de saison · historique conservé", app.accent)
		if history.is_empty(): card.add_child(G.wrap("L'historique annuel apparaîtra à l'intersaison.", 12))
		for year: Dictionary in history.slice(maxi(0, history.size() - 3)):
			card.add_child(G.wrap("S%s · niveau %s → %s · %s minutes / %s apparitions" % [G.n(year.get("season", "—")), G.n(year.get("start", "—")), G.n(year.get("end", "—")), G.n(year.get("minutes", 0)), G.n(year.get("appearances", 0))], 13))
		var controls := G.h(12)
		card.add_child(controls)
		var focus := OptionButton.new()
		focus.custom_minimum_size = Vector2(200, 38)
		focus.name = "Focus" + str(person.id).replace(":", "_")
		for option: Dictionary in development.get("options", []):
			focus.add_item(option.label)
			focus.set_item_metadata(focus.item_count - 1, option.id)
			if option.id == development.get("focus"): focus.select(focus.item_count - 1)
		focus.disabled = not development.get("available", false)
		focus.tooltip_text = "Changer la spécialisation remet à zéro sa progression partielle non utilisée. Les qualités déjà gagnées sont conservées."
		focus.item_selected.connect(func(index: int): app._command("set_development_focus", {"playerId":person.id, "focus":focus.get_item_metadata(index)}))
		controls.add_child(focus)
		if mode == "academy":
			_promotion(controls,app,data,person)
		else:
			controls.add_child(G.button("OUVRIR LA FICHE", func(): app.selected_player = str(person.id); app._navigate("Effectif")))
		if not str(development.get("reason", "")).is_empty(): card.add_child(G.wrap(development.reason, 12))
		card.add_child(G.separator())
	return page

# Same action as the Formation cards, narrowed to the reviewed player.
static func _promotion(parent: Node, app: Control, data: Dictionary, person: Dictionary) -> Button:
	var promote := G.button("PREMIER CONTRAT PRO", func(): app.confirm("Promouvoir " + str(person.name), "%s rejoindra l'effectif professionnel et ajoutera %s de salaire par semaine de jeu. Son contrat court jusqu'à la fin de la saison%s. Confirmer ?" % [person.name, G.euros(person.salary), G.n(int(app.model.meta.season) + (2 if app.model.meta.phase == "ended" else 1))], func(): app._command("promote_academy", {"playerId":person.id, "confirmed":true})))
	promote.name = "PromoteAcademy" + str(person.id).replace(":","_")
	promote.set_meta("promote_id",person.id)
	promote.disabled = app.waiting or not data.get("promotionAvailable",false)
	parent.add_child(promote)
	return promote

static func open_player(app: Control, player_id: String) -> AcceptDialog:
	app._clear_dialogs()
	var dialog := AcceptDialog.new()
	dialog.name = "YouthPromotionPathway"
	dialog.title = "Examiner le premier contrat professionnel"
	dialog.get_ok_button().text = "FERMER"
	app._prepare_dialog(dialog,650)
	var body := G.v(12)
	dialog.add_child(body)
	var data: Dictionary = app.model.get("decisions",{}).get("development",{})
	var matches: Array = data.get("academy",[]).filter(func(person: Dictionary): return str(person.id)==player_id)
	if matches.is_empty(): body.add_child(G.wrap("Ce joueur n’est plus au centre. Revenez au suivi actualisé.",16))
	else:
		var person: Dictionary = matches[0]
		body.add_child(G.section(str(person.name),str(person.pos)+" · "+G.n(person.age)+" ans"))
		body.add_child(G.wrap("Salaire proposé : %s par semaine. La promotion utilise la décision existante du centre et ses contrôles de capacité ; elle ne garantit aucune minute ni progression." % G.euros(person.salary),15))
		_promotion(body,app,data,person).name = "YouthPathwayPromote"
		if not data.get("promotionAvailable",false): body.add_child(G.wrap("Premier contrat indisponible dans le contexte actuel. Vérifiez la capacité et la période avant de réessayer.",14,G.ALERT))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	preload("res://ui/immersive08/dialogs.gd").show_centered(dialog,Vector2i(650,280))
	return dialog
