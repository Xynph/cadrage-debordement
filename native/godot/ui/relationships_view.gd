extends RefCounted
const Copy = preload("res://ui/management_copy.gd")
const G = preload("res://ui/carnet_skin.gd")
const EntityLink = preload("res://ui/entity_link.gd")

static func _number(value: Variant) -> String:
	return str(int(value)) if value is float or value is int else "—"

static func _name(app: Control, id: Variant) -> String:
	for p: Dictionary in app.model.get("squad", []):
		if p.id == id: return str(p.name)
	return "Joueur parti du club" if id != null else "Aucun relais disponible"

static func _player_target(app: Control, id: Variant) -> Dictionary:
	# The history is not a name index. A departed player never resolves to a
	# namesake, nor to an unprojected biography outside the current squad.
	if not id is String or id.is_empty(): return {}
	var present := false
	for person: Dictionary in app.model.get("squad", []):
		if person.get("id") == id: present = true; break
	if not present: return {}
	for field: Dictionary in app.get_property_list():
		if field.name != "navigation_controller": continue
		var navigation: Variant = app.get("navigation_controller")
		var target := {"kind":"player", "id":id}
		if is_instance_valid(navigation) and navigation.has_method("entity_available") and navigation.entity_available(target): return target
	return {}

static func _person_link(app: Control, parent: Node, id: Variant, name: String) -> void:
	var target := _player_target(app, id)
	if target.is_empty():
		parent.add_child(G.wrap(_name(app, id), 14))
		return
	var button := G.button(_name(app, id), func(): pass)
	button.name = name
	button.custom_minimum_size.y = 40
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	EntityLink.bind(button, app, target, _name(app, id))
	parent.add_child(button)

static func _identity(app: Control, parent: Node, identity: Dictionary, id: String, detail: String) -> void:
	var target := _player_target(app, id)
	if target.is_empty():
		G.person(parent, identity, _name(app, id), detail)
		return
	var row := G.h(12)
	parent.add_child(row)
	var picture := G.button("", func(): pass)
	picture.name = "RelationshipPortraitLink"
	picture.custom_minimum_size = Vector2(66,66)
	EntityLink.bind(picture, app, target, _name(app, id))
	row.add_child(picture)
	var portrait := G.portrait(int(identity.get("portraitIndex", posmod(id.hash(),32))),58,identity)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.add_child(portrait)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left=4; portrait.offset_top=4; portrait.offset_right=-4; portrait.offset_bottom=-4
	var text := G.v(3)
	G.fill(text)
	row.add_child(text)
	_person_link(app,text,id,"RelationshipPlayerLink")
	text.add_child(G.wrap(detail,13))

static func build(app: Control) -> Control:
	var page := G.h(18)
	page.name = "CarnetRelations"
	G.fill(page, true)
	var data: Dictionary = app.model.get("clubLife", {}).get("relationships", {})
	var context: Dictionary = data.get("context", {})
	if not app.management_ui.has("relationships"): app.management_ui["relationships"] = {}
	var selection: Dictionary = app.management_ui.relationships
	var left := G.panel(page, 1.0)
	G.chapter(left, "11", "Le vestiaire", "Des décisions et leurs suites, semaine après semaine.", app.accent)
	var follow := G.scroll(left)
	if not data.get("active", false):
		follow.add_child(G.wrap("Ancienne carrière : activer volontairement les entretiens et le suivi des promesses.", 15))
		var activate := G.button("ACTIVER LE SUIVI DU VESTIAIRE", func(): app._command("relationship_activate", {"context":context}))
		activate.name = "ActivateRelationships"
		activate.disabled = not data.get("available", false)
		follow.add_child(activate)
	for item in [["Moral du groupe", data.get("morale")], ["Confiance de la direction", data.get("trust")]]:
		if item[1] != null: G.gauge(follow, item[0], float(item[1]))
	var event: Variant = data.get("event")
	if event is Dictionary:
		follow.add_child(G.section(str(event.title)))
		_person_link(app,follow,event.playerId,"RelationshipEventPlayerLink")
		follow.add_child(G.wrap(event.context, 15))
		follow.add_child(G.wrap("Personnalité : %s · leadership %s / 100" % [event.trait, int(event.leadership)], 13))
		for choice: Dictionary in event.get("choices", []):
			var button := G.button(choice.label, func(): app._command("locker_room_decision", {"context":context, "eventKey":event.key, "choice":choice.id}))
			button.name = "LockerDecision_" + str(choice.id)
			button.disabled = not event.get("available", false)
			follow.add_child(button)
			follow.add_child(G.wrap(choice.detail, 13))
	else:
		follow.add_child(G.wrap("La décision hebdomadaire est traitée, ou aucun entretien n’est disponible dans cette phase.", 15))
	follow.add_child(G.separator())
	follow.add_child(G.section("Les engagements"))
	var commitments: Array = data.get("commitments", [])
	if commitments.is_empty(): follow.add_child(G.wrap("Aucun engagement de vestiaire en cours.", 14))
	for c: Dictionary in commitments.slice(-8):
		var status: String = str({"open":"À suivre", "honored":"Honoré", "broken":"Non tenu", "expired":"Clos sans pénalité"}.get(c.status, c.status))
		_person_link(app,follow,c.playerId,"RelationshipCommitmentPlayerLink")
		follow.add_child(G.wrap("%s · %s\nObjectif %s minutes · échéance semaine de carrière %s" % [_name(app, c.playerId), status, int(c.target), int(c.dueWeek) + 1], 14))
	for e: Dictionary in data.get("history", []).slice(0, 6):
		_person_link(app,follow,e.playerId,"RelationshipHistoryPlayerLink")
		follow.add_child(G.wrap("S%s · semaine %s — %s\n%s · %s" % [int(e.season), int(e.week) + 1, _name(app, e.playerId), e.title, {"ecouter":"Écouter", "cadrer":"Rappeler les exigences", "responsabiliser":"Confier un rôle"}.get(e.choice, e.choice)], 13))
	var right := G.panel(page, 1.3)
	G.chapter(right, "12", "Les personnes et les liens", "Un entretien par personne ; une intervention de groupe par semaine.", app.accent)
	var list := G.scroll(right)
	var players: Array = data.get("players", [])
	if players.is_empty():
		list.add_child(G.wrap("Aucun joueur suivi dans cette carrière.", 16))
		return page
	list.add_child(G.label("Relais pressenti : " + _name(app, data.get("leaderId")), 17))
	if not _player_target(app,data.get("leaderId")).is_empty(): _person_link(app,list,data.leaderId,"RelationshipLeaderPlayerLink")
	var chooser := OptionButton.new()
	chooser.name = "RelationshipPlayer"
	chooser.custom_minimum_size.y = 44
	chooser.fit_to_longest_item = false
	var selected := 0
	for p: Dictionary in players:
		chooser.add_item(_name(app, p.id) + " · " + str(p.pos))
		if p.id == selection.get("playerId"): selected = chooser.item_count - 1
	chooser.select(selected)
	list.add_child(chooser)
	var details := G.v(10)
	list.add_child(details)
	var draw := func(index: int):
		selection["playerId"] = players[index].id
		for child in details.get_children(): details.remove_child(child); child.queue_free()
		_player(app, details, data, players[index], context)
	chooser.item_selected.connect(draw)
	draw.call(selected)
	list.add_child(G.separator())
	list.add_child(G.section("Travailler un duo"))
	list.add_child(G.wrap("Deux partenaires disponibles. Le mentorat exige le relais pressenti en joueur A ; la médiation cible un lien inférieur à 8.", 13))
	var a := OptionButton.new()
	a.name = "DuoPlayerA"
	var b := OptionButton.new()
	b.name = "DuoPlayerB"
	for p: Dictionary in players:
		a.add_item(_name(app, p.id)); b.add_item(_name(app, p.id))
		if p.id == data.get("leaderId"): a.select(a.item_count - 1)
	a.custom_minimum_size.y = 44; b.custom_minimum_size.y = 44
	a.fit_to_longest_item = false; b.fit_to_longest_item = false
	if players.size() > 1: b.select(1 if a.selected == 0 else 0)
	list.add_child(a); list.add_child(b)
	for action: Dictionary in data.get("duoActions", []):
		var button := G.button(action.label, func(): app._command("relationship_duo", {"context":context, "mode":action.id, "a":players[a.selected].id, "b":players[b.selected].id}))
		button.name = "DuoAction_" + str(action.id)
		button.disabled = not data.get("duoAvailable", false)
		list.add_child(button); list.add_child(G.wrap(action.detail, 13))
	for pair: Dictionary in data.get("pairs", []):
		list.add_child(G.wrap("%s / %s · lien %s" % [_name(app, pair.a), _name(app, pair.b), int(pair.score)], 14))
		var people := G.h(6)
		list.add_child(people)
		_person_link(app,people,pair.a,"RelationshipDuoPlayerALink")
		_person_link(app,people,pair.b,"RelationshipDuoPlayerBLink")
	list.add_child(G.wrap(Copy.notice("relationships", data.get("notice", "")), 12))
	return page

static func _player(app: Control, parent: VBoxContainer, data: Dictionary, p: Dictionary, context: Dictionary) -> void:
	var identity: Dictionary = p
	for candidate: Dictionary in app.model.get("squad", []):
		if candidate.id == p.id: identity = candidate; break
	_identity(app, parent, identity, str(p.id), "Entretien individuel · " + str(p.get("pos", "")))
	var personality: Variant = p.get("personality")
	if personality is Dictionary and not str(personality.get("trait", "")).is_empty():
		var character := G.wrap("Personnalité : %s · leadership %s / 100" % [personality.trait, _number(personality.get("leadership"))], 13)
		character.name = "RelationshipPersonality"
		parent.add_child(character)
	if p.get("score") != null: G.gauge(parent, "Satisfaction", float(p.score))
	parent.add_child(G.wrap("Satisfaction %s / 100 · condition %s %% · %s minute(s)" % [_number(p.get("score")), int(p.condition), _number(p.get("minutes"))], 15))
	if int(p.injury) > 0: parent.add_child(G.wrap("Blessure : %s semaine(s). Promesse suspendue si aucune minute jouée." % p.injury, 14, G.ALERT))
	for c: Dictionary in data.get("conversations", []):
		var button := G.button(c.label + " · " + c.detail, func(): app._command("relationship_conversation", {"context":context, "playerId":p.id, "choice":c.id}))
		button.disabled = not p.get("conversationAvailable", false)
		button.name = "Conversation_" + str(c.id)
		parent.add_child(button)
	for history: Dictionary in data.get("conversationHistory", []).filter(func(h): return h.playerId == p.id).slice(0, 3):
		var choice := str({"ecouter":"Écouter", "rassurer":"Rassurer", "clarifier":"Clarifier"}.get(history.get("choice", ""), "Entretien individuel"))
		var memory := G.wrap("S%s J%s · %s\nSatisfaction %s → %s" % [int(history.season), int(history.round) + 1, choice, _number(history.get("before")), _number(history.get("after"))], 13)
		memory.name = "RelationshipConversationMemory"
		parent.add_child(memory)
	var personal_events: Array = data.get("history", []).filter(func(h): return h.get("playerId") == p.id).slice(0, 3)
	if not personal_events.is_empty(): parent.add_child(G.section("Nos derniers échanges"))
	for history: Dictionary in personal_events:
		var choice := str({"ecouter":"Écouter", "cadrer":"Rappeler les exigences", "responsabiliser":"Confier un rôle"}.get(history.get("choice", ""), "Décision prise"))
		var memory := G.wrap("S%s · semaine %s — %s\n%s" % [int(history.season), int(history.week) + 1, str(history.get("title", "")), choice], 13)
		memory.name = "RelationshipEventMemory"
		parent.add_child(memory)
	var promise: Variant = p.get("promise")
	if promise is Dictionary:
		parent.add_child(G.wrap("Promesse %s · %s minute(s) / %s rencontres sur 3" % [promise.target, int(promise.minutes), int(promise.completed)], 15))
	else:
		parent.add_child(G.wrap("Promettre du temps de jeu sur trois rencontres : respect +8 satisfaction ; non-respect −10. Dernière ouverture : journée 24.", 13))
		for option: Dictionary in data.get("promiseOptions", []):
			var button := G.button("PROMETTRE %s MINUTES" % int(option.minutes), func(): app._command("relationship_promise", {"context":context, "playerId":p.id, "target":option.id}))
			button.disabled = not p.get("promiseAvailable", false)
			button.name = "Promise_" + str(option.id)
			parent.add_child(button)
	for h: Dictionary in p.get("promiseHistory", []).slice(-3):
		parent.add_child(G.wrap("S%s J%s · %s · %s min" % [int(h.season), int(h.round) + 1, {"promise":"Engagement pris", "kept":"Promesse tenue", "broken":"Promesse rompue"}.get(h.status, h.status), int(h.minutes)], 13))
