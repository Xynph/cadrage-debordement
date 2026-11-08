extends RefCounted
const G = preload("res://ui/carnet_skin.gd")

static func build(app: Control) -> Control:
	var page := G.h(16)
	page.name = "CarnetDevelopment"
	G.fill(page, true)
	var data: Dictionary = app.model.get("decisions", {}).get("development", {})
	if not app.management_ui.has("development"): app.management_ui.development = {"mode":"academy"}
	var state: Dictionary = app.management_ui.development
	var notes := G.panel(page, .68)
	G.chapter(notes, "11", "La relève", "Faire une place aux générations suivantes.", app.accent)
	var text := G.scroll(notes)
	text.add_child(G.metric(G.n(data.get("academy", []).size()), "espoirs au centre"))
	text.add_child(G.wrap("Quinze nouveaux espoirs par saison. Au plus75 joueurs restent au centre ; il ne simule pas encore de championnat Espoirs dans cette version native.", 14))
	text.add_child(G.separator())
	for option in [["academy", "LE CENTRE DE FORMATION"], ["professional", "LES JEUNES PROFESSIONNELS"]]:
		var b := G.button(option[1], func(): state.mode = option[0]; app._render())
		b.name = "Development" + option[0].capitalize()
		if state.mode == option[0]: G.selected(b, app.accent)
		text.add_child(b)
	text.add_child(G.wrap("Le potentiel est une estimation de simulation. La promotion ne garantit ni le temps de jeu ni la progression. Les courbes annuelles des profils communs et les gains graduels des joueurs générés sont distingués.", 13))
	text.add_child(G.button("CONSULTER L'EFFECTIF →", func(): app._navigate("Effectif")))
	var body := G.panel(page, 1.95)
	G.chapter(body, "12", "Ouvrir des perspectives", "Poste, travail et minutes réellement disputées.", app.accent)
	var people: Array = data.get("academy", []) if state.mode == "academy" else data.get("professionals", []).filter(func(p: Dictionary): return p.age <= 23)
	var list := G.scroll(body)
	list.get_parent().name = "DevelopmentList"
	if people.is_empty(): list.add_child(G.wrap("Aucun joueur dans cette catégorie.", 17))
	for person: Dictionary in people:
		var card := G.v(10)
		card.set_meta("development_id", person.id)
		list.add_child(card)
		var row := G.h(16)
		card.add_child(row)
		var identity := G.v(3)
		G.fill(identity)
		row.add_child(identity)
		identity.add_child(G.wrap(person.name, 25, G.INK))
		identity.add_child(G.wrap("%s · %s ans · %s minutes · %s apparitions" % [person.pos, G.n(person.age), G.n(person.minutes), G.n(person.appearances)], 13))
		row.add_child(G.metric(G.n(person.note), "note au poste"))
		row.add_child(G.metric(G.n(person.potential), "potentiel estimé"))
		var development: Dictionary = person.get("development", {})
		var history: Array = development.get("history", [])
		if history.is_empty(): card.add_child(G.wrap("L'historique annuel apparaîtra à l'intersaison ; aucune courbe passée n'est inventée.", 12))
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
		focus.tooltip_text = "Changer la spécialisation remet à zéro son XP partiel non dépensé. Les qualités déjà gagnées sont conservées."
		focus.item_selected.connect(func(index: int): app._command("set_development_focus", {"playerId":person.id, "focus":focus.get_item_metadata(index)}))
		controls.add_child(focus)
		if state.mode == "academy":
			var promote := G.button("PREMIER CONTRAT PRO", func(): app.confirm("Promouvoir " + str(person.name), "%s rejoindra l'effectif professionnel et ajoutera %s de salaire par semaine de jeu. Son contrat court jusqu'à la fin de la saison%s. Confirmer ?" % [person.name, G.euros(person.salary), G.n(int(app.model.meta.season) + (2 if app.model.meta.phase == "ended" else 1))], func(): app._command("promote_academy", {"playerId":person.id, "confirmed":true})))
			promote.set_meta("promote_id", person.id)
			promote.disabled = not data.get("promotionAvailable", false)
			controls.add_child(promote)
		else:
			controls.add_child(G.button("OUVRIR LA FICHE", func(): app.selected_player = str(person.id); app._navigate("Effectif")))
		if not str(development.get("reason", "")).is_empty(): card.add_child(G.wrap(development.reason, 12))
		card.add_child(G.separator())
	return page
