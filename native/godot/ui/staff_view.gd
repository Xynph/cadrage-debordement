extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const U = preload("res://ui/management_state.gd")
const ImmersiveUI = preload("res://ui/immersive08/club_ui.gd")
const Career = preload("res://ui/staff_career_view.gd")

static func reading(app: Control) -> Dictionary:
	if not app.management_ui.get("staff") is Dictionary: app.management_ui.staff = {}
	return app.management_ui.staff

static func person_by_id(model: Dictionary, staff_id: String) -> Dictionary:
	if staff_id.is_empty(): return {}
	for team: Dictionary in model.get("staff", {}).get("teams", []):
		for person: Dictionary in team.get("members", []):
			if str(person.get("id", "")) == staff_id: return person
	var career: Dictionary = model.get("clubLife", {}).get("staffCareer", {})
	for source: String in ["candidates", "retired"]:
		for person: Dictionary in career.get(source, []):
			if str(person.get("id", "")) == staff_id: return person
	return {}

static func open_target(app: Control, staff_id: String) -> bool:
	if not target_available(app, staff_id): return false
	reading(app).navigation_id = staff_id
	return true

static func target_available(app: Control, staff_id: String) -> bool:
	return not person_by_id(app.model, staff_id).is_empty()

static func name_link(app: Control, person: Dictionary, text_size: int = 24) -> Button:
	var staff_id := str(person.get("id", ""))
	var link := G.button(str(person.get("name", "")), func():
		app.navigation_controller.open_entity({"kind":"staff", "id":staff_id}))
	link.name = "StaffOpenName_" + staff_id.validate_node_name()
	link.accessibility_name = "Consulter le profil · " + str(person.get("name", ""))
	link.tooltip_text = link.accessibility_name
	link.set_meta("entity_kind", "staff")
	link.set_meta("entity_id", staff_id)
	link.alignment = HORIZONTAL_ALIGNMENT_LEFT
	link.add_theme_font_size_override("font_size", G.Base.reading_size(text_size))
	return link

static func portrait_link(app: Control, photo: Control, person: Dictionary) -> Button:
	var link := name_link(app, person)
	link.name = "StaffOpenPortrait_" + str(person.get("id", "")).validate_node_name()
	link.text = ""
	link.custom_minimum_size = photo.custom_minimum_size
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	link.add_child(photo)
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return link

static func _profile(app: Control, parent: Container, person: Dictionary) -> void:
	var list := G.scroll(parent)
	list.name = "StaffProfile"
	list.set_meta("staff_id", str(person.id))
	var heading := G.h(12)
	list.add_child(heading)
	var appearance := person.duplicate(true)
	appearance.portraitRole = "staff"
	heading.add_child(G.portrait(0, 82, appearance))
	var words := G.v(5)
	heading.add_child(words)
	var title := G.wrap(str(person.get("name", "")), 24, G.INK)
	title.name = "StaffProfileName"
	words.add_child(title)
	words.add_child(G.wrap(str(person.get("roleLabel", person.get("role", "Staff"))), 15, G.GOLD))
	if person.has("age"): words.add_child(G.wrap("%s ans" % G.n(person.age), 14))
	for team: Dictionary in app.model.get("staff", {}).get("teams", []):
		if team.get("members", []).any(func(member: Dictionary): return str(member.get("id", "")) == str(person.id)):
			words.add_child(G.wrap(str(team.get("name", "")), 14))
			break
	if person.get("contractEnd") != null: list.add_child(G.wrap("Contrat jusqu’à la saison %s" % G.n(person.contractEnd), 14))
	var employment := Career._employment_person(app, str(person.id))
	if employment.get("employed", false):
		list.add_child(G.wrap("Contrat rémunéré · %s · %s paies restantes" % [G.salary(employment.get("paidSalary", 0)), G.n(employment.get("remainingPayments", 0))], 14))
	var events: Array = app.model.get("clubLife", {}).get("staffCareer", {}).get("history", []).filter(func(event: Dictionary):
		return str(event.get("id", "")) == str(person.id))
	if not events.is_empty():
		list.add_child(G.section("Parcours dans votre carrière"))
		var labels := {"reference-already-retired":"Retraite", "player-conversion":"Reconversion dans le staff", "retirement":"Retraite", "voluntary-retirement":"Départ à la retraite", "contract-ended":"Fin de contrat", "ai-renewal":"Prolongation", "ai-hire":"Arrivée au club", "hire":"Arrivée au club", "renew":"Prolongation", "release":"Départ du club"}
		for event: Dictionary in events:
			list.add_child(G.wrap("Saison %s · %s" % [G.n(event.get("season", "—")), str(labels.get(event.get("kind", ""), "Évolution du parcours"))], 14))
	var back := G.button("Retour à l’annuaire", func():
		reading(app).navigation_id = ""
		app._render(false))
	back.name = "StaffProfileDirectory"
	list.add_child(back)

class Avatar extends Control:
	func _draw() -> void:
		draw_style_box(G.T.box(Color("ddd5c6"), 8), Rect2(Vector2.ZERO, size))
		draw_circle(Vector2(size.x * .5, size.y * .32), size.x * .16, Color("aaa396"))
		draw_style_box(G.T.box(Color("aaa396"), 20), Rect2(Vector2(size.x * .18, size.y * .53), Vector2(size.x * .64, size.y * .38)))

static func build(app: Control) -> Control:
	var page := G.h(16)
	page.name = "CarnetStaff"
	G.fill(page, true)
	var left := G.panel(page, .72)
	G.chapter(left, "09", "Autour de vous", "Les responsabilités restent vos choix.", app.accent)
	var duties := G.scroll(left)
	var decisions: Dictionary = app.model.get("decisions", {})
	var delegation: Dictionary = decisions.get("delegation", {})
	for entry in [["lineup", "L'adjoint", "Prépare les 23 après la séance, selon les postes et les joueurs disponibles."], ["training", "Le préparateur", "Choisit récupération sous 75 % de condition moyenne du XV ; charge normale sinon."]]:
		duties.add_child(G.section(entry[1]))
		duties.add_child(G.wrap(entry[2], 14))
		var toggle := CheckBox.new()
		toggle.name = "Delegate" + entry[0].capitalize()
		toggle.text = "Confier la sélection" if entry[0] == "lineup" else "Confier la charge collective"
		toggle.button_pressed = delegation.get(entry[0], false)
		toggle.disabled = not app._live().is_empty() or not decisions.has("delegation") or app.model.meta.get("phase") == "ended"
		toggle.toggled.connect(func(value: bool): app._command("set_delegation", {"key":entry[0], "enabled":value}))
		duties.add_child(toggle)
		duties.add_child(G.separator())
	var selection := G.button("DEMANDER UNE SÉLECTION", func(): app._command("auto_lineup"))
	selection.disabled = not app._live().is_empty() or app.model.meta.get("phase") == "ended"
	duties.add_child(selection)
	duties.add_child(G.wrap("Les identités du staff ne modifient ni ses capacités ni les résultats. Les signatures restent à confirmer par vous.", 12))
	duties.add_child(G.button("RECRUTEMENT →", func(): app._navigate("Recrutement")))
	var right := G.panel(page, 1.9)
	var target := person_by_id(app.model, str(reading(app).get("navigation_id", "")))
	if not target.is_empty():
		_profile(app, right, target)
		return page
	var career: Dictionary = app.model.get("clubLife", {}).get("staffCareer", {})
	if career.get("active", false):
		G.chapter(right, "10", "Les carrières du staff", "Contrats, candidats et reconversions dans votre partie.", app.accent)
		Career.build(app, right, career)
		return page
	G.chapter(right, "10", "Les visages du club", "Les membres de l’encadrement et leurs responsabilités.", app.accent)
	Career.enable(app, right, career)
	var teams: Array = app.model.get("staff", {}).get("teams", [])
	if teams.is_empty():
		right.add_child(G.wrap("Les collaborateurs de cette carrière sont conservés.", 17))
		return page
	if not teams.any(func(c: Dictionary): return int(c.id) == app.selected_staff_club): app.selected_staff_club = int(app.model.club.id)
	var chooser := OptionButton.new()
	chooser.name = "StaffClub"
	chooser.fit_to_longest_item = false
	chooser.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chooser.custom_minimum_size.y = 40
	for team: Dictionary in teams:
		chooser.add_item(str(team.name))
		chooser.set_item_metadata(chooser.item_count - 1, int(team.id))
		if int(team.id) == app.selected_staff_club: chooser.select(chooser.item_count - 1)
	chooser.item_selected.connect(func(index: int):
		app.selected_staff_club = int(chooser.get_item_metadata(index))
		app._render()
		ImmersiveUI.focus(app,"StaffClub"))
	right.add_child(chooser)
	var people: Array = []
	for team: Dictionary in teams:
		if int(team.id) == app.selected_staff_club: people = team.members
	var search := LineEdit.new()
	search.name = "StaffSearch"
	search.placeholder_text = "Rechercher un nom ou une fonction…"
	search.add_theme_color_override("font_placeholder_color", G.MUTED)
	search.custom_minimum_size.y = 38
	search.text = str(reading(app).get("search", ""))
	right.add_child(search)
	var count := G.label("", 12, G.MUTED)
	count.name = "StaffCount"
	right.add_child(count)
	var list := G.scroll(right)
	list.get_parent().name = "StaffList"
	list.get_parent().set_deferred("scroll_vertical", int(reading(app).get("scroll", 0)))
	list.get_parent().get_v_scroll_bar().value_changed.connect(func(value: float): reading(app).scroll = value)
	var redraw := func(query: String):
		for child in list.get_children(): list.remove_child(child); child.queue_free()
		var shown := 0
		var needle := U.fold(query).strip_edges()
		for person: Dictionary in people:
			if not needle.is_empty() and not U.fold(str(person.name) + " " + str(person.role)).contains(needle): continue
			shown += 1
			_person(app, list, person)
		count.text = "%d / %d membres" % [shown, people.size()]
		if shown == 0: list.add_child(G.wrap("Aucun membre ne correspond à cette recherche.", 15))
	search.text_changed.connect(func(query: String): reading(app).search = query; redraw.call(query))
	redraw.call(search.text)
	right.add_child(G.wrap("Retrouvez les fonctions de chaque membre de l’encadrement.", 12))
	return page

static func _person(app: Control, parent: VBoxContainer, person: Dictionary) -> void:
	var card := G.card(parent)
	var row := G.h(16)
	row.set_meta("staff_id", person.id)
	card.add_child(row)
	var appearance := person.duplicate(true)
	appearance.portraitRole = "staff"
	var photo := G.portrait(0, 82, appearance)
	photo.custom_minimum_size.y = 104
	row.add_child(portrait_link(app, photo, person))
	var text := G.v(5)
	G.fill(text)
	row.add_child(text)
	text.add_child(name_link(app, person))
	text.add_child(G.wrap(person.role, 15, G.GOLD))
	var season := str(person.get("sourceSeason")) if person.get("sourceSeason") != null else "Saison non précisée"
	var date := " · source du " + str(person.sourceDate) if person.get("sourceDate") != null else ""
	if person.get("historical", false):
		text.add_child(G.wrap("Ancien membre du staff · " + season, 11, G.MUTED))
	card.add_child(G.separator())
