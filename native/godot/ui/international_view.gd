extends RefCounted

const G = preload("res://ui/game_skin.gd")

static func build(app: Control) -> Control:
	var page := G.v(8)
	page.name = "InternationalSelections"
	var international: Dictionary = app.model.get("international", {})
	var names := {}
	for team: Dictionary in international.get("teams", []):
		names[team.id] = team.name
	var nation := str(international.get("nation", ""))
	var role: String = international.get("role", "club")
	if role in ["dual", "nation"]:
		var status := "Club et sélection" if role == "dual" else "Sélection uniquement"
		page.add_child(G.section("%s · %s" % [status, names.get(nation, nation)]))
	else:
		page.add_child(G.section("Votre carrière en club", "Suivez les convocations et les postes disponibles."))
	var tabs := TabContainer.new()
	tabs.name = "InternationalTabs"
	page.add_child(tabs)
	tabs.add_child(_callups(international, names))
	tabs.add_child(_editions(international))
	tabs.add_child(_offers(app, international, role))
	tabs.current_tab = 2 if app.management_ui.get("international_section") == "offers" else 0
	tabs.tab_changed.connect(func(index: int):
		app.management_ui.international_section = ["callups", "editions", "offers"][index])
	if app.management_ui.get("international_section") == "editions": tabs.current_tab = 1
	return page

static func _callups(international: Dictionary, names: Dictionary) -> Control:
	var view := G.v()
	view.name = "Convocations"
	for callup: Dictionary in international.get("callups", []):
		var list := G.panel(view)
		list.add_child(G.section(str(names.get(callup.nation, callup.nation)),
			"%s au %s" % [callup.from, callup.through]))
		for player: Dictionary in callup.get("players", []):
			list.add_child(G.wrap("%s · %s · %s ans" % [player.name, player.pos, player.age], 15, G.INK))
	if view.get_child_count() == 0: view.add_child(G.wrap("Aucune convocation enregistrée."))
	return view

static func _editions(international: Dictionary) -> Control:
	var view := G.v()
	view.name = "Compétitions"
	for edition: Dictionary in international.get("editions", []):
		var list := G.panel(view)
		list.add_child(G.section(str(edition.get("name", ""))))
		var fixtures: Variant = edition.get("fixtures")
		if fixtures is Array: list.add_child(G.wrap("%d rencontres au programme" % fixtures.size()))
	if view.get_child_count() == 0: view.add_child(G.wrap("Aucune édition internationale disponible."))
	return view

static func _offers(app: Control, international: Dictionary, role: String) -> Control:
	var view := G.v()
	view.name = "Offres"
	var jobs: Array = international.get("jobs", []).duplicate()
	var requested: String = app.management_ui.get("international_nation", "")
	for index in jobs.size():
		if jobs[index].nation == requested:
			jobs.push_front(jobs.pop_at(index))
			break
	for job: Dictionary in jobs:
		var card := G.panel(view)
		var nation: String = job.nation
		var name: String = job.get("name", nation)
		card.add_child(G.section(name))
		if role != "nation":
			var dual := G.button("Conserver le club et prendre la sélection", _take.bind(app, nation, name, "dual"))
			dual.name = "NationalJobDual_" + nation
			card.add_child(dual)
		var only := G.button("Prendre la sélection seule", _take.bind(app, nation, name, "nation"))
		only.name = "NationalJobOnly_" + nation
		card.add_child(only)
	if view.get_child_count() == 0: view.add_child(G.wrap("Aucun poste de sélectionneur disponible."))
	if role == "dual":
		view.add_child(G.button("Quitter la sélection", func():
			app.confirm("Quitter la sélection", "Votre carrière en club continue.",
				func(): app._command("national_leave_job", {"confirmed":true}))))
	return view

static func _take(app: Control, nation: String, name: String, role: String) -> void:
	var detail := "Vous continuerez à diriger votre club et prendrez en charge cette sélection." if role == "dual" else "Votre carrière se poursuivra à la tête de cette sélection."
	app.confirm("Prendre en charge " + name, detail,
		func(): app._command("national_take_job", {"nation":nation, "role":role, "confirmed":true}))
