extends RefCounted
## Onglet Staff (écran Club, charte finale du 20/11/2026) : tableau dense de l'encadrement, délégations et accès, ou
## fiche d'un membre (clic sur son nom ou sa ligne ; jamais de fiche à droite). Liens gris-vert + flèche, boutons en
## pilule, aucun aplat doré. Les tableaux, liens et boutons viennent de staff_career_view.gd (Career.texte, .lien…).
const G = preload("res://ui/carnet_skin.gd")
const U = preload("res://ui/management_state.gd")
const ImmersiveUI = preload("res://ui/immersive08/club_ui.gd")
const Career = preload("res://ui/staff_career_view.gd")
const C = preload("res://ui/immersive08/components.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Charte = preload("res://ui/charte.gd")

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

## Nom d'un membre : DM Sans gras crème (charte : noms des tableaux), clic = sa fiche.
static func name_link(app: Control, person: Dictionary, text_size: int = 18) -> Button:
	var staff_id := str(person.get("id", ""))
	var link := Career.lien(str(person.get("name", "")), func():
		app.navigation_controller.open_entity({"kind":"staff", "id":staff_id}), "StaffOpenName_" + staff_id.validate_node_name(), text_size, Charte.IVOIRE)
	link.add_theme_font_override("font", Kit.texte_gras())
	link.accessibility_name = "Consulter le profil · " + str(person.get("name", ""))
	link.set_meta("entity_kind", "staff")
	link.set_meta("entity_id", staff_id)
	link.alignment = HORIZONTAL_ALIGNMENT_LEFT
	link.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	link.clip_text = true
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

## Une ligne « intitulé · valeur » de la fiche (rangée dense, filet dessous).
static func _fait(parent: Container, intitule: String, valeur: String) -> void:
	var row := Career.rangee()
	row.custom_minimum_size.y = C.px(Career.LIGNE)
	parent.add_child(row)
	row.add_child(Career.texte(intitule, 18, Charte.IVOIRE_2, 300))
	row.add_child(Career.texte(valeur, 18, Charte.IVOIRE))
	Career.filet(parent)

## Fiche d'un membre du staff : identité, contrat, parcours, puis Prolonger (bouton plein vert franc) et Libérer à part.
static func _profile(app: Control, parent: Container, person: Dictionary) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "StaffProfileScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "StaffProfile"
	list.add_theme_constant_override("separation", C.px(6))
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.set_meta("staff_id", str(person.id))
	scroll.add_child(list)
	var back := Career.lien("← Retour à l’annuaire", func():
		reading(app).navigation_id = ""
		app._render(false), "StaffProfileDirectory", 18)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	list.add_child(back)
	var heading := Career.rangee(20)
	list.add_child(heading)
	var appearance := person.duplicate(true)
	appearance.portraitRole = "staff"
	var photo := G.portrait(0, C.px(96), appearance)
	photo.custom_minimum_size = Vector2(C.px(96), C.px(110))
	heading.add_child(photo)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", C.px(4))
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_child(words)
	var role := str(person.get("roleLabel", person.get("role", "Staff")))
	words.add_child(Career.surtitre(role))
	var title := C.label(str(person.get("name", "")), 40, Charte.IVOIRE, true, 700)
	title.add_theme_font_override("font", Charte.TITRE_EXTRA)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.custom_minimum_size.x = C.px(400)
	title.name = "StaffProfileName"
	words.add_child(title)
	var equipe := ""
	for team: Dictionary in app.model.get("staff", {}).get("teams", []):
		if team.get("members", []).any(func(member: Dictionary): return str(member.get("id", "")) == str(person.id)):
			equipe = str(team.get("name", ""))
			break
	var resume: Array[String] = []
	if person.has("age"): resume.append("%s ans" % G.n(person.age))
	if not equipe.is_empty(): resume.append(equipe)
	if not resume.is_empty(): words.add_child(Career.texte(" · ".join(resume), 19, Charte.IVOIRE_2))
	Career.filet(list)
	_fait(list, "Rôle", role)
	if person.get("level") != null: _fait(list, "Niveau", G.n(person.level))
	if person.get("contractEnd") != null: _fait(list, "Contrat", "jusqu’à la saison %s" % G.season_label(person.contractEnd))
	var employment := Career._employment_person(app, str(person.id))
	if employment.get("employed", false):
		_fait(list, "Salaire", "%s · %s paies restantes" % [G.salary(employment.get("paidSalary", 0)), G.n(employment.get("remainingPayments", 0))])
		if employment.get("severance") != null: _fait(list, "Indemnité de rupture", "%s €" % G.n(employment.severance))
	if person.get("sourcePlayerId") != null: _fait(list, "Parcours", "Ancien joueur · reconversion dans l’encadrement")
	var events: Array = app.model.get("clubLife", {}).get("staffCareer", {}).get("history", []).filter(func(event: Dictionary):
		return str(event.get("id", "")) == str(person.id))
	if not events.is_empty():
		var section := Career.etiquette("Parcours dans ta carrière")
		section.custom_minimum_size.y = C.px(40)
		list.add_child(section)
		var labels := {"reference-already-retired":"Retraite", "player-conversion":"Reconversion dans le staff", "retirement":"Retraite", "voluntary-retirement":"Départ à la retraite", "contract-ended":"Fin de contrat", "ai-renewal":"Prolongation", "ai-hire":"Arrivée au club", "hire":"Arrivée au club", "renew":"Prolongation", "release":"Départ du club"}
		for event: Dictionary in events:
			_fait(list, "Saison %s" % G.season_label(event.get("season", "—")), str(labels.get(event.get("kind", ""), "Évolution du parcours")))
	# Actions sur un membre de TON club (carrières du staff actives) : Prolonger en action principale, Libérer à part.
	var own := false
	for team: Dictionary in app.model.get("staff", {}).get("teams", []):
		if int(team.get("id", -1)) == int(app.model.club.id) and team.get("members", []).any(func(member: Dictionary): return str(member.get("id", "")) == str(person.id)): own = true
	var career: Dictionary = app.model.get("clubLife", {}).get("staffCareer", {})
	if own and career.get("active", false) and (person.get("canRenew", false) or person.get("canRelease", false) or person.get("canRetire", false)):
		var espace := Control.new()
		espace.custom_minimum_size.y = C.px(14)
		list.add_child(espace)
		var actions := Career.rangee(24)
		actions.name = "StaffProfileActions"
		list.add_child(actions)
		if person.get("canRenew", false):
			var renew := Career.bouton_principal(actions, "Prolonger " + Kit.casse(str(person.name)), func(): Career._contract(app, person, career, true), "StaffRenew", 420.0)
			renew.set_meta("staff_id", person.id)
		if person.get("canRelease", false):
			Career._departure(app, actions, person, career, "staff_release", "Libérer", "Le membre du staff redeviendra disponible au recrutement.", "Libérer " + Kit.casse(str(person.name)))
		if person.get("canRetire", false):
			Career._departure(app, actions, person, career, "staff_retire", "Retraite", "Cette personne quittera définitivement le marché du staff.")
		var cout := "Libérer : une confirmation s’ouvre ici, avec le coût écrit."
		if employment.get("employed", false): cout = "Libérer : indemnité de rupture de %s €, au plus deux paies ; confirmation ici même." % G.n(employment.get("severance", 0))
		list.add_child(Career.texte(cout, 17, Charte.IVOIRE_2))

## Délégations du staff (adjoint, préparateur) et accès rapides, sous le tableau.
static func _delegations(app: Control, page: Container) -> void:
	Career.filet(page)
	var bloc := Career.rangee(20)
	bloc.name = "StaffDuties"
	page.add_child(bloc)
	bloc.add_child(Career.etiquette("Délégations", 150))
	var decisions: Dictionary = app.model.get("decisions", {})
	var delegation: Dictionary = decisions.get("delegation", {})
	for entry in [["lineup", "L’adjoint prépare les 23", "Prépare les 23 après la séance, selon les postes et les joueurs disponibles."], ["training", "Le préparateur dose la charge", "Choisit récupération sous 75 % de condition moyenne du XV ; charge normale sinon."]]:
		var toggle := CheckBox.new()
		toggle.name = "Delegate" + entry[0].capitalize()
		toggle.text = entry[1]
		toggle.accessibility_name = "%s · %s" % [entry[1], entry[2]]
		toggle.button_pressed = delegation.get(entry[0], false)
		toggle.disabled = not app._live().is_empty() or not decisions.has("delegation") or app.model.meta.get("phase") == "ended"
		toggle.toggled.connect(func(value: bool): app._command("set_delegation", {"key":entry[0], "enabled":value}))
		Kit.styler_case(toggle)
		bloc.add_child(toggle)
	var espace := Control.new()
	espace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	espace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(espace)
	var selection := Career.lien("Demander une sélection →", func(): app._command("auto_lineup"), "StaffAutoLineup", 18)
	selection.disabled = not app._live().is_empty() or app.model.meta.get("phase") == "ended"
	bloc.add_child(selection)
	bloc.add_child(Career.lien("Recrutement →", func(): app._navigate("Recrutement"), "StaffRecruitment", 18))

static func build(app: Control) -> Control:
	var page := VBoxContainer.new()
	page.name = "CarnetStaff"
	page.add_theme_constant_override("separation", C.px(8))
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var target := person_by_id(app.model, str(reading(app).get("navigation_id", "")))
	if not target.is_empty():
		_profile(app, page, target)
		return page
	var career: Dictionary = app.model.get("clubLife", {}).get("staffCareer", {})
	if career.get("active", false):
		Career.build(app, page, career)
		_delegations(app, page)
		return page
	_annuaire(app, page, career)
	_delegations(app, page)
	return page

## Annuaire quand les carrières du staff ne sont pas actives : même tableau, sans actions de contrat.
static func _annuaire(app: Control, page: Container, career: Dictionary) -> void:
	var outils := Career.rangee(12)
	outils.name = "StaffToolbar"
	page.add_child(outils)
	outils.add_child(Career.titre("Encadrement"))
	var teams: Array = app.model.get("staff", {}).get("teams", [])
	if teams.is_empty():
		page.add_child(Career.texte("Les collaborateurs de cette carrière sont conservés.", 19, Charte.IVOIRE_2))
		var acces := Career.rangee(18)
		page.add_child(acces)
		Career.enable(app, acces, career)
		return
	if not teams.any(func(c: Dictionary): return int(c.id) == app.selected_staff_club): app.selected_staff_club = int(app.model.club.id)
	var chooser := OptionButton.new()
	chooser.name = "StaffClub"
	for team: Dictionary in teams:
		chooser.add_item(str(team.name))
		chooser.set_item_metadata(chooser.item_count - 1, int(team.id))
		if int(team.id) == app.selected_staff_club: chooser.select(chooser.item_count - 1)
	chooser.item_selected.connect(func(index: int):
		app.selected_staff_club = int(chooser.get_item_metadata(index))
		app._render()
		ImmersiveUI.focus(app,"StaffClub"))
	Career.styler_liste(chooser, 300)
	outils.add_child(chooser)
	var people: Array = []
	for team: Dictionary in teams:
		if int(team.id) == app.selected_staff_club: people = team.members
	var search := LineEdit.new()
	search.name = "StaffSearch"
	search.placeholder_text = "Nom ou fonction…"
	search.text = str(reading(app).get("search", ""))
	Career.styler_champ(search)
	search.custom_minimum_size.x = C.px(340)
	outils.add_child(search)
	var count := Career.texte("", 17, Charte.IVOIRE_2, 0.0, true)
	count.name = "StaffCount"
	outils.add_child(count)
	var acces := Career.rangee(18)
	acces.name = "StaffAccess"
	page.add_child(acces)
	acces.add_child(Career.texte("Les membres de l’encadrement et leurs fonctions.", 17, Charte.IVOIRE_2))
	Career.enable(app, acces, career)
	Career.entete(page, false)
	var scroll := ScrollContainer.new()
	scroll.name = "StaffList"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	scroll.set_deferred("scroll_vertical", int(reading(app).get("scroll", 0)))
	scroll.get_v_scroll_bar().value_changed.connect(func(value: float): reading(app).scroll = value)
	var redraw := func(query: String):
		for child in list.get_children(): list.remove_child(child); child.queue_free()
		var shown := 0
		var needle := U.fold(query).strip_edges()
		for person: Dictionary in people:
			if not needle.is_empty() and not U.fold(str(person.name) + " " + str(person.role)).contains(needle): continue
			shown += 1
			_person(app, list, person)
		count.text = "%d / %d membres" % [shown, people.size()]
		if shown == 0: list.add_child(Career.texte("Aucun membre ne correspond à cette recherche.", 18, Charte.IVOIRE_2))
	search.text_changed.connect(func(query: String): reading(app).search = query; redraw.call(query))
	redraw.call(search.text)

static func _person(app: Control, parent: VBoxContainer, person: Dictionary) -> void:
	Career._person(app, parent, person, {"role_publie": true}, false)
