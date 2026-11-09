extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const U = preload("res://ui/management_state.gd")
const Dialogs = preload("res://ui/decision_views.gd")
const PAGE_SIZE := 20

static func enable(app: Control, parent: Container, data: Dictionary) -> void:
	if not data.get("canEnable", false): return
	var button := G.button("ACTIVER LES CARRIÈRES DU STAFF", func():
		var payload := {"confirmed":true,"context":data.context.duplicate(true)}
		app.confirm("Activer les carrières du staff", "Cette sauvegarde utilisera désormais des âges de carrière, des contrats et des remplacements simulés. Les âges sans source sont estimés. Confirmer ?", func(): app._command("staff_career_enable", payload)))
	button.name = "EnableStaffCareer"
	parent.add_child(button)

static func build(app: Control, parent: Container, data: Dictionary) -> void:
	var overview := G.v(8)
	overview.name = "StaffCareerOverview"
	parent.add_child(overview)
	overview.add_child(G.wrap(data.get("notice", ""), 13))
	var teams: Array = app.model.get("staff", {}).get("teams", data.get("teams", []))
	var chooser := OptionButton.new()
	chooser.name = "StaffClub"
	chooser.custom_minimum_size.y = 38
	if not teams.any(func(t: Dictionary): return int(t.id) == app.selected_staff_club): app.selected_staff_club = int(app.model.club.id)
	for team: Dictionary in teams:
		chooser.add_item(str(team.name)); chooser.set_item_metadata(chooser.item_count - 1, int(team.id))
		if int(team.id) == app.selected_staff_club: chooser.select(chooser.item_count - 1)
	chooser.item_selected.connect(func(index: int):
		app.selected_staff_club = int(chooser.get_item_metadata(index)); app._render())
	overview.add_child(chooser)
	var tabs := OptionButton.new()
	tabs.name = "StaffCareerTab"
	for title in ["Équipe du club", "Candidats disponibles", "Retraites et archives"]: tabs.add_item(title)
	overview.add_child(tabs)
	var search := LineEdit.new()
	search.name = "StaffSearch"
	search.placeholder_text = "Rechercher un nom ou un rôle…"
	search.custom_minimum_size.y = 38
	overview.add_child(search)
	var count := G.label("", 12, G.MUTED)
	count.name = "StaffCount"
	overview.add_child(count)
	var list := G.scroll(parent)
	list.get_parent().name = "StaffList"
	var paging := G.h(8)
	parent.add_child(paging)
	var local := {"page":0}
	var previous := G.button("← PRÉCÉDENT", func(): pass)
	var next := G.button("SUIVANT →", func(): pass)
	var page_label := G.label("", 12, G.MUTED)
	paging.add_child(previous); paging.add_child(page_label); paging.add_child(next)
	var redraw := func():
		for child in list.get_children(): list.remove_child(child); child.queue_free()
		var people: Array = []
		if tabs.selected == 0:
			for team: Dictionary in teams:
				if int(team.id) == app.selected_staff_club: people = team.members
		elif tabs.selected == 1: people = data.get("candidates", [])
		else: people = data.get("retired", [])
		var query := U.fold(search.text).strip_edges()
		var filtered := people.filter(func(p: Dictionary): return query.is_empty() or U.fold(str(p.name) + " " + str(p.get("roleLabel", p.role))).contains(query))
		local.page = clampi(int(local.page), 0, maxi(0, ceili(float(filtered.size()) / PAGE_SIZE) - 1))
		var start: int = int(local.page) * PAGE_SIZE
		for person: Dictionary in filtered.slice(start, start + PAGE_SIZE): _person(app, list, person, data, tabs.selected == 0 and app.selected_staff_club == int(app.model.club.id))
		count.text = "%d / %d membres · %s" % [filtered.size(), people.size(), ["staff en poste", "candidats recrutables", "archives conservées"][tabs.selected]]
		if filtered.is_empty(): list.add_child(G.wrap("Aucun profil dans cette sélection.", 15))
		previous.disabled = int(local.page) == 0
		next.disabled = start + PAGE_SIZE >= filtered.size()
		page_label.text = "Page %d / %d" % [int(local.page) + 1, maxi(1, ceili(float(filtered.size()) / PAGE_SIZE))]
	previous.pressed.connect(func(): local.page -= 1; redraw.call())
	next.pressed.connect(func(): local.page += 1; redraw.call())
	tabs.item_selected.connect(func(_i: int): local.page = 0; redraw.call())
	search.text_changed.connect(func(_q: String): local.page = 0; redraw.call())
	redraw.call()
	parent.add_child(G.wrap("Les âges et contrats sont ceux de la carrière simulée. Les identités n’accordent aucun bonus de match. Salaires et primes de staff : 0 € dans cette version.", 12))

static func _person(app: Control, parent: Container, person: Dictionary, data: Dictionary, own: bool) -> void:
	var card := G.card(parent)
	var row := G.h(12)
	row.set_meta("staff_id", person.id)
	card.add_child(row)
	var appearance := person.duplicate(true)
	appearance.portraitRole = "staff"
	row.add_child(G.portrait(0, 68, appearance))
	var text := G.v(4)
	G.fill(text); row.add_child(text)
	text.add_child(G.wrap(person.name, 21, G.INK))
	text.add_child(G.wrap(person.get("roleLabel", data.get("roles", {}).get(person.get("role", ""), person.get("role", "Staff"))), 14, G.GOLD))
	var estimated := str(person.get("ageBasis", "")).contains("estimated") or str(person.get("ageBasis", "")).contains("simulated")
	text.add_child(G.wrap("%s ans · %s" % [G.n(person.get("age", 0)), "âge de carrière estimé" if estimated else "âge de carrière"], 12))
	if person.get("contractEnd") != null: text.add_child(G.wrap("Contrat jusqu’à la saison %s" % G.n(person.contractEnd), 12))
	if person.get("sourcePlayerId") != null: text.add_child(G.wrap("Ancien joueur · reconversion dans l’encadrement", 12, G.GOOD))
	var actions := G.h(6)
	card.add_child(actions)
	if person.get("canHire", false):
		var hire := G.button("RECRUTER →", func(): _contract(app, person, data, false))
		hire.name = "StaffHire"
		hire.set_meta("staff_id", person.id)
		actions.add_child(hire)
	if own and person.get("canRenew", false):
		var renew := G.button("PROLONGER", func(): _contract(app, person, data, true))
		renew.name = "StaffRenew"
		renew.set_meta("staff_id", person.id)
		actions.add_child(renew)
	if own and person.get("canRelease", false): _departure(app, actions, person, data, "staff_release", "LIBÉRER", "Le membre du staff redeviendra disponible au recrutement.")
	if own and person.get("canRetire", false): _departure(app, actions, person, data, "staff_retire", "RETRAITE", "Cette personne quittera définitivement le marché du staff.")

static func _contract(app: Control, person: Dictionary, data: Dictionary, renew: bool) -> void:
	var view := Dialogs.dialog(app, "Prolonger le staff" if renew else "Recruter le staff", "StaffContract", 700)
	var dialog: AcceptDialog = view[0]
	var list: VBoxContainer = view[1]
	list.add_child(G.section(person.name, person.get("roleLabel", person.get("role", "Staff"))))
	list.add_child(G.wrap("Salaires et prime : 0 € dans cette version. Le contrat fixe la durée de présence dans le club.", 14))
	var years := OptionButton.new()
	years.name = "StaffContractYears"
	for n in range(int(person.get("minYears", 1)), int(person.get("maxYears", data.get("maxYears", 3))) + 1):
		years.add_item("%d saison%s" % [n, "s" if n > 1 else ""]); years.set_item_metadata(years.item_count - 1, n)
	list.add_child(years)
	var sign := G.button("CONFIRMER LE CONTRAT", func():
		var payload := {"confirmed":true,"context":data.context.duplicate(true),"years":int(years.get_item_metadata(years.selected))}
		payload["staffId" if renew else "candidateId"] = str(person.id)
		dialog.queue_free(); app._command("staff_renew" if renew else "staff_hire", payload), true)
	sign.name = "StaffContractConfirm"
	sign.disabled = years.item_count == 0
	list.add_child(sign)
	dialog.popup_centered()

static func _departure(app: Control, parent: Container, person: Dictionary, data: Dictionary, command: String, title: String, detail: String) -> void:
	var button := G.button(title, func():
		var payload := {"confirmed":true,"context":data.context.duplicate(true),"staffId":str(person.id)}
		app.confirm(title + " · " + str(person.name), detail, func(): app._command(command, payload)))
	button.name = "StaffRelease" if command == "staff_release" else "StaffRetire"
	button.set_meta("staff_id", person.id)
	parent.add_child(button)
