extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const U = preload("res://ui/management_state.gd")
const ImmersiveUI = preload("res://ui/immersive08/club_ui.gd")
const Career = preload("res://ui/staff_career_view.gd")

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
	var career: Dictionary = app.model.get("clubLife", {}).get("staffCareer", {})
	if career.get("active", false):
		G.chapter(right, "10", "Les carrières du staff", "Contrats, candidats et reconversions dans votre partie.", app.accent)
		Career.build(app, right, career)
		return page
	G.chapter(right, "10", "Les visages du club", "Encadrement de référence · données datées, hors mouvements simulés.", app.accent)
	Career.enable(app, right, career)
	var teams: Array = app.model.get("staff", {}).get("teams", [])
	if teams.is_empty():
		right.add_child(G.wrap("Cette carrière historique conserve ses collaborateurs générés. Les identités des staffs sont disponibles avec la base commune à 30 clubs.", 17))
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
	right.add_child(search)
	var count := G.label("", 12, G.MUTED)
	count.name = "StaffCount"
	right.add_child(count)
	var list := G.scroll(right)
	list.get_parent().name = "StaffList"
	var redraw := func(query: String):
		for child in list.get_children(): list.remove_child(child); child.queue_free()
		var shown := 0
		var needle := U.fold(query).strip_edges()
		for person: Dictionary in people:
			if not needle.is_empty() and not U.fold(str(person.name) + " " + str(person.role)).contains(needle): continue
			shown += 1
			_person(list, person)
		count.text = "%d / %d membres documentés · noms anonymisés hors pack" % [shown, people.size()]
		if shown == 0: list.add_child(G.wrap("Aucun membre ne correspond à cette recherche.", 15))
	search.text_changed.connect(redraw)
	redraw.call("")
	right.add_child(G.wrap("Les pages officielles ne précisent pas toutes leur saison. Les références anciennes sont indiquées ; cet annuaire ne simule pas les mutations du staff.", 12))
	return page

static func _person(parent: VBoxContainer, person: Dictionary) -> void:
	var card := G.card(parent)
	var row := G.h(16)
	row.set_meta("staff_id", person.id)
	card.add_child(row)
	var appearance := person.duplicate(true)
	appearance.portraitRole = "staff"
	var photo := G.portrait(0, 82, appearance)
	photo.custom_minimum_size.y = 104
	row.add_child(photo)
	var text := G.v(5)
	G.fill(text)
	row.add_child(text)
	text.add_child(G.wrap(person.name, 24, G.INK))
	text.add_child(G.wrap(person.role, 15, G.GOLD))
	var season := str(person.get("sourceSeason")) if person.get("sourceSeason") != null else "Saison non précisée"
	var date := " · source du " + str(person.sourceDate) if person.get("sourceDate") != null else ""
	text.add_child(G.wrap(("ARCHIVE · " if person.get("historical", false) else "RÉFÉRENCE · ") + season + date, 11, G.ALERT if person.get("historical", false) else G.MUTED))
	text.add_child(G.wrap("Relevé le " + str(person.get("observedAt", "")) + " · " + ("photo officielle du pack" if person.get("portraitStatus") == "official" else "illustration IA du pack" if person.get("portraitStatus") == "synthetic" else "portrait fictif composé hors ligne"), 11))
	card.add_child(G.separator())
