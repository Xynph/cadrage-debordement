extends RefCounted
## Dossier de lecture des seuls candidats publiés par la fenêtre appelante.
const G = preload("res://ui/carnet_skin.gd")
const Copy = preload("res://ui/management_copy.gd")
const Sort = preload("res://ui/recruitment_sort.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")

static func projected_person(app: Control, source: String, id: String) -> Dictionary:
	if id.is_empty(): return {}
	var life: Dictionary = app.model.get("clubLife", {})
	var people: Array
	match source:
		"regen-candidates": people = life.get("regenScouting", {}).get("candidates", [])
		"regen-shortlist": people = life.get("regenScouting", {}).get("shortlist", [])
		"interclub": people = life.get("interclubMarket", {}).get("candidates", [])
		_: return {}
	var found: Array = people.filter(func(person: Dictionary):
		return str(person.get("playerId", person.get("id", ""))) == id)
	if found.size() != 1 or not found[0].get("name") is String or str(found[0].name).is_empty(): return {}
	return found[0].duplicate(true)

static func target_available(app: Control, source: String, id: String) -> bool:
	return not projected_person(app, source, id).is_empty()

static func inspection_button(app: Control, owner: Window, source: String, id: String, caption: String, control_name: String, portrait: Control = null) -> Button:
	var target := {"kind":"prospect", "source":source, "id":id}
	var link := G.button(caption if portrait == null else "", func():
		app.navigation_controller.inspect_entity(target, owner))
	link.name = control_name
	link.alignment = HORIZONTAL_ALIGNMENT_LEFT
	link.add_theme_font_size_override("font_size", G.Base.reading_size(20))
	link.set_meta("entity_kind", "prospect")
	link.set_meta("entity_id", id)
	link.set_meta("entity_source", source)
	link.accessibility_name = "Consulter le dossier · " + caption
	link.tooltip_text = link.accessibility_name
	link.disabled = not target_available(app, source, id)
	if portrait != null:
		link.custom_minimum_size = portrait.get_combined_minimum_size()
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		link.add_child(portrait)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return link

static func has_child_window(owner: Node) -> bool:
	for child: Node in owner.get_children():
		if child is Window and child.visible and not child.is_queued_for_deletion(): return true
		if has_child_window(child): return true
	return false

static func open_target(app: Control, source: String, id: String, owner: Window) -> bool:
	var person := projected_person(app, source, id)
	if person.is_empty() or not is_instance_valid(owner) or owner.is_queued_for_deletion(): return false
	if has_child_window(owner): return false
	var prior := owner.gui_get_focus_owner()
	var return_focus: WeakRef = weakref(prior) if prior != null else null
	var dialog := AcceptDialog.new()
	dialog.name = "ProspectProfile"
	dialog.title = "Dossier · " + str(person.name)
	dialog.transient = true
	dialog.exclusive = true
	dialog.set_meta("navigation_read_only", true)
	dialog.set_meta("entity_kind", "prospect")
	dialog.set_meta("entity_id", id)
	dialog.set_meta("entity_source", source)
	var preferred := Vector2i(mini(880, maxi(360, owner.size.x - 40)), mini(640, maxi(360, owner.size.y - 60)))
	app._prepare_dialog(dialog, preferred.x)
	dialog.get_ok_button().text = "RETOUR AU CATALOGUE"
	dialog.get_ok_button().name = "ProspectProfileClose"
	var content := G.v(8)
	content.custom_minimum_size = Vector2(preferred.x - 64, preferred.y - 100)
	dialog.add_child(content)
	var heading := G.h(12)
	content.add_child(heading)
	heading.add_child(G.portrait(0, 72, person))
	var identity := G.v(4)
	G.fill(identity)
	heading.add_child(identity)
	var name_label := G.wrap(str(person.name), 24, G.INK)
	name_label.name = "ProspectProfileName"
	identity.add_child(name_label)
	identity.add_child(G.wrap("%s · %s ans" % [person.get("pos", "—"), G.n(person.get("age", "—"))], 15, G.INK))
	var tabs := TabContainer.new()
	tabs.name = "ProspectProfileTabs"
	G.fill(tabs, true)
	content.add_child(tabs)
	var profile := G.scroll(tabs)
	profile.get_parent().name = "Profil"
	_profile(profile, person, source)
	var observation := G.scroll(tabs)
	observation.get_parent().name = "Observation"
	_observation(observation, person)
	var terms := G.scroll(tabs)
	terms.get_parent().name = "Contrat"
	_contract(terms, person, source)
	var squad := G.scroll(tabs)
	squad.get_parent().name = "Votre effectif"
	_squad(squad, app.model.get("squad", []), person)
	var close := func():
		dialog.queue_free()
		_restore_focus.call_deferred(owner, return_focus)
	dialog.confirmed.connect(close)
	dialog.canceled.connect(close)
	owner.add_child(dialog)
	Dialogs.show_centered(dialog, preferred)
	dialog.get_ok_button().grab_focus.call_deferred()
	return true

static func _restore_focus(owner: Window, reference: WeakRef) -> void:
	if not is_instance_valid(owner) or not owner.visible or reference == null: return
	await owner.get_tree().process_frame
	if not is_instance_valid(owner) or not owner.visible: return
	var target := reference.get_ref() as Control
	if is_instance_valid(target) and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()

static func _profile(parent: Container, person: Dictionary, source: String) -> void:
	if source == "interclub":
		parent.add_child(G.section("Club actuel", str(person.get("club", "—"))))
	else:
		var origin: Dictionary = person.get("origin", {})
		parent.add_child(G.section("Parcours", Copy.notice("scouting", origin.get("label", "Origine non précisée"))))
		if origin.get("season") != null: parent.add_child(G.wrap("Origine en saison %s · disponible depuis la saison %s" % [G.n(origin.season), G.n(origin.get("availableSince", "—"))], 14))
		if person.has("matchingSlots"): parent.add_child(G.wrap("%d besoin(s) du club compatible(s) avec ce profil." % person.matchingSlots.size(), 14))
	var reason := str(person.get("reason", ""))
	if not reason.is_empty(): parent.add_child(G.wrap(Copy.notice("interclub" if source == "interclub" else "scouting", reason), 14, G.ALERT))
	parent.add_child(G.wrap("Consultez les observations, les conditions connues et les joueurs de votre effectif au même poste avant de revenir au catalogue.", 14))

static func _observation(parent: Container, person: Dictionary) -> void:
	parent.add_child(G.section("Observation", Sort.report_label(person)))
	parent.add_child(G.wrap("Niveau : %s · potentiel : %s" % [G.rating_text(person), G.potential_text(person)], 16, G.INK))
	parent.add_child(G.wrap("Le potentiel est une fourchette évolutive, sans garantie de l’atteindre.", 13))
	var observed: Variant = person.get("knowledge", {}).get("observedAt")
	if observed is Dictionary and observed.get("season") != null:
		parent.add_child(G.wrap("Dernière observation · saison %s · semaine %s" % [G.n(observed.season), G.n(observed.get("week", "—"))], 14))
	var evidence: Dictionary = person.get("evidence", {})
	if evidence.get("stale", false): parent.add_child(G.wrap("Rapport ancien : les qualités actuelles restent à vérifier.", 14, G.GOLD))
	var assessment: Dictionary = person.get("assessment", {})
	for section: Array in [["observed", "Faits relevés"], ["estimates", "Appréciations du recruteur"]]:
		var entries: Array = assessment.get(section[0], [])
		if entries.is_empty(): continue
		parent.add_child(G.section(section[1]))
		for entry: String in entries: parent.add_child(G.wrap(entry, 14, G.INK))

static func _money(value: Variant) -> String:
	return G.euros(value) if value is int or value is float else "Non communiqué"

static func _salary(value: Variant) -> String:
	return G.salary(value) if value is int or value is float else "Non communiqué"

static func _contract(parent: Container, person: Dictionary, source: String) -> void:
	parent.add_child(G.section("Conditions connues"))
	parent.add_child(G.wrap(("Indemnité au club : " if source == "interclub" else "Prime à la signature : ") + _money(person.get("fee")), 15, G.INK))
	parent.add_child(G.wrap(("Salaire proposé : " if source == "interclub" else "Salaire demandé : ") + _salary(person.get("salary")), 15, G.INK))
	if source == "interclub":
		parent.add_child(G.wrap("Échéance conservée : saison %s" % G.n(person.get("contractEnd", "—")), 15, G.INK))
	else:
		for term: Dictionary in person.get("terms", []):
			parent.add_child(G.section("%s saison(s) · %s échéances" % [G.n(term.get("years", "—")), G.n(term.get("payments", "—"))]))
			parent.add_child(G.wrap("Engagement connu : %s · prime %s et salaire %s" % [_money(term.get("knownCommitment")), _money(term.get("fee")), _salary(term.get("salary"))], 14, G.INK))
	parent.add_child(G.wrap("Ces conditions ne réservent pas le joueur. La consultation ne soumet aucune proposition.", 13))

static func _squad(parent: Container, squad: Array, person: Dictionary) -> void:
	parent.add_child(G.section("Vos joueurs au même poste"))
	var peers: Array = squad.filter(func(member: Dictionary): return str(member.get("pos", "")) == str(person.get("pos", "")))
	if peers.is_empty(): parent.add_child(G.wrap("Aucun joueur de votre effectif n’occupe ce poste principal.", 14))
	for member: Dictionary in peers:
		parent.add_child(G.section(str(member.get("name", "")), "%s ans · niveau %s" % [G.n(member.get("age", "—")), G.rating_text(member, true)]))
		parent.add_child(G.wrap("Contrat jusqu’à la saison %s · %s" % [G.n(member.get("contractEnd", "—")), _salary(member.get("salary"))], 14))
