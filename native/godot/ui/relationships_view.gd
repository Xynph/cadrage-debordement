extends RefCounted
const Copy = preload("res://ui/management_copy.gd")
const G = preload("res://ui/carnet_skin.gd")
const EntityLink = preload("res://ui/entity_link.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const Charte = preload("res://ui/charte.gd")
const Components = preload("res://ui/immersive08/components.gd")
const GameSkin = preload("res://ui/game_skin.gd")
const V = preload("res://ui/relationships_visuals.gd")
const LIBELLES_EFFET := {"satisfaction": "satisf.", "moral collectif": "moral", "moral": "moral", "confiance de direction": "conf.", "confiance": "conf.", "respect": "satisf."}
const CONTEXTES := {
	"tension": ["Satisfaction basse", "warning"], "fatigue": ["Fatigue", "heart"], "revelation": ["Minutes à suivre", "clock"],
	"contrat": ["Fin de contrat", "calendar"], "leadership": ["Leader", "star"], "ambition": ["Projet à aligner", "flag"]}

## Effets d'une réponse (« Satisfaction −3 ; confiance de direction +2 ; moral −1 ») en mini-pastilles ▲ / ▼ ;
## un effet sans chiffre (« engagement de temps de jeu à suivre ») devient une pastille horloge. Le texte complet reste en infobulle.
static func effets(detail: String) -> HBoxContainer:
	var rangee := Components.h(6)
	var expression := RegEx.create_from_string("^(.*?)\\s*([+\\-−])(\\d+)\\s*$")
	for morceau: String in detail.strip_edges().rstrip(".").split(";", false):
		var partie := morceau.strip_edges()
		var complet := partie.substr(0, 1).to_upper() + partie.substr(1)
		var apres := partie.get_slice(":", 1).strip_edges() if ":" in partie else partie
		var trouve := expression.search(apres)
		if trouve == null:
			rangee.add_child(Pastilles.pastille("", Pastilles.ORANGE, "clock", complet, 18))
			continue
		var positif := trouve.get_string(2) == "+"
		var libelle := trouve.get_string(1).strip_edges().to_lower()
		var court: String = LIBELLES_EFFET.get(libelle, libelle)
		var signe := "+" if positif else "−"
		rangee.add_child(Pastilles.pastille("%s %s%s %s" % ["▲" if positif else "▼", signe, trouve.get_string(3), court], Pastilles.VERT if positif else Pastilles.ROUGE, "", complet, 18))
	return rangee

## Cause de la décision de la semaine, en une pastille (la phrase du moteur reste en infobulle).
static func contexte(app: Control, event: Dictionary) -> Control:
	var entree: Array = CONTEXTES.get(str(event.get("kind", "")), ["À traiter", "warning"])
	var texte: String = entree[0]
	if str(event.get("kind", "")) == "contrat":
		for p: Dictionary in app.model.get("squad", []):
			if p.get("id") == event.get("playerId") and (p.get("contractEnd") is int or p.get("contractEnd") is float):
				texte = "Fin %s" % GameSkin.contract_year(p.contractEnd)
	return Pastilles.pastille(texte, Pastilles.ORANGE, str(entree[1]), str(event.get("context", "")), 18, "RelationshipEventContext", _ouvrir(app, event.get("playerId")))

## Action « ouvrir la fiche du joueur » (écran, jamais fenêtre) ; sans fiche disponible : pas d'action, la tuile reste neutre.
static func _ouvrir(app: Control, id: Variant) -> Callable:
	var cible := _player_target(app, id)
	if cible.is_empty(): return Callable()
	return func(): app.navigation_controller.open_entity(cible)

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

static func _person_link(app: Control, parent: Node, id: Variant, name: String) -> Control:
	var target := _player_target(app, id)
	if target.is_empty():
		var label := G.wrap(_name(app, id), 14)
		parent.add_child(label)
		return label
	var button := G.button(_name(app, id), func(): pass)
	button.name = name
	button.custom_minimum_size.y = 40
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	G.fill(button)
	EntityLink.bind(button, app, target, _name(app, id))
	parent.add_child(button)
	return button

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
	var heading := _person_link(app,text,id,"RelationshipPlayerLink")
	heading.add_theme_font_size_override("font_size",G.Base.reading_size(25))
	heading.add_theme_font_override("font",G.T.DISPLAY)
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
	G.chapter(left, "11", "Le vestiaire", "", app.accent)
	var follow := G.scroll(left)
	follow.get_parent().name = "RelationshipFollowScroll"
	if not data.get("active", false):
		var activate := G.button("ACTIVER LE SUIVI DU VESTIAIRE", func(): app._command("relationship_activate", {"context":context}))
		activate.tooltip_text = "Ancienne carrière : activer volontairement les entretiens et le suivi des promesses."
		activate.name = "ActivateRelationships"
		activate.disabled = not data.get("available", false)
		follow.add_child(activate)
	if V.variante() == "B":
		var anneaux := G.h(24)
		anneaux.alignment = BoxContainer.ALIGNMENT_CENTER
		anneaux.name = "RelationshipRings"
		if data.get("morale") != null: anneaux.add_child(V.anneau(float(data.morale), "Moral", "heart", Charte.MORAL, 120, "RelationshipRingMorale", func(): app._navigate("Effectif")))
		if data.get("trust") != null: anneaux.add_child(V.anneau(float(data.trust), "Conseil", "shield", Charte.CONFIANCE, 120, "RelationshipRingTrust", func(): app._navigate("Club")))
		follow.add_child(anneaux)
	else:
		for item in [["Moral du groupe", data.get("morale")], ["Confiance de la direction", data.get("trust")]]:
			if item[1] != null: G.gauge(follow, item[0], float(item[1]))
	var event: Variant = data.get("event")
	if event is Dictionary:
		follow.add_child(G.section(str(event.title)))
		if V.active():
			_identity(app, follow, _identite(app, event.playerId), str(event.playerId), "")
			var etats := V.personnalite(str(event.get("trait", "")), event.get("leadership"), _ouvrir(app, event.playerId))
			etats.add_child(contexte(app, event))
			etats.move_child(etats.get_child(etats.get_child_count() - 1), 0)
			follow.add_child(etats)
			var cartes: Array = []
			for choice: Dictionary in event.get("choices", []):
				var agir := func(): app._command("locker_room_decision", {"context":context, "eventKey":event.key, "choice":choice.id})
				if V.variante() == "A": cartes.append(V.tuile_action(str(choice.id), str(choice.label), str(choice.detail), agir, "LockerDecision_" + str(choice.id), event.get("available", false), 150))
				else: follow.add_child(V.ligne_action(str(choice.id), str(choice.label), str(choice.detail), agir, "LockerDecision_" + str(choice.id), event.get("available", false)))
			if not cartes.is_empty(): follow.add_child(V.rangee(cartes))
		else:
			_person_link(app,follow,event.playerId,"RelationshipEventPlayerLink")
			follow.add_child(contexte(app, event))
			follow.add_child(G.wrap("Personnalité : %s · leadership %s / 100" % [event.trait, int(event.leadership)], 13))
		for choice: Dictionary in ([] if V.active() else event.get("choices", [])):
			var button := G.button(choice.label, func(): app._command("locker_room_decision", {"context":context, "eventKey":event.key, "choice":choice.id}))
			button.name = "LockerDecision_" + str(choice.id)
			button.disabled = not event.get("available", false)
			follow.add_child(button)
			follow.add_child(effets(str(choice.detail)))
	else:
		follow.add_child(Pastilles.pastille("Aucune décision en attente", Charte.IVOIRE_2, "check", "La décision hebdomadaire est traitée, ou aucun entretien n’est disponible dans cette phase.", 18, "RelationshipNoEvent"))
	follow.add_child(G.separator())
	follow.add_child(G.section("Les engagements"))
	var commitments: Array = data.get("commitments", [])
	if commitments.is_empty(): follow.add_child(Components.label("Aucun engagement", 22, Charte.IVOIRE_2, true, 600))
	for c: Dictionary in commitments.slice(-8):
		var status: String = str({"open":"À suivre", "honored":"Honoré", "broken":"Non tenu", "expired":"Clos sans pénalité"}.get(c.status, c.status))
		_person_link(app,follow,c.playerId,"RelationshipCommitmentPlayerLink")
		follow.add_child(G.wrap("%s · %s\nObjectif %s minutes · échéance semaine de carrière %s" % [_name(app, c.playerId), status, int(c.target), int(c.dueWeek) + 1], 14))
	for e: Dictionary in data.get("history", []).slice(0, 6):
		_person_link(app,follow,e.playerId,"RelationshipHistoryPlayerLink")
		follow.add_child(G.wrap("%s · semaine %s — %s\n%s · %s" % [G.season_label(e.season), int(e.week) + 1, _name(app, e.playerId), e.title, {"ecouter":"Écouter", "cadrer":"Rappeler les exigences", "responsabiliser":"Confier un rôle"}.get(e.choice, e.choice)], 13))
	var right := G.panel(page, 1.3)
	G.chapter(right, "12", "Les personnes et les liens", "", app.accent, "Un entretien par personne ; une intervention de groupe par semaine.")
	var list := G.scroll(right)
	list.get_parent().name = "RelationshipPeopleScroll"
	var players: Array = data.get("players", [])
	if players.is_empty():
		list.add_child(G.wrap("Aucun joueur suivi dans cette carrière.", 16))
		return page
	var selected := 0
	for i in players.size():
		if players[i].id == selection.get("playerId"): selected = i
	if V.variante() == "B":
		var details_b := G.v(10)
		list.add_child(_portraits(app, players, data, selection, players[selected], details_b, context))
		list.add_child(details_b)
		_player(app, details_b, data, players[selected], context)
		_duos(app, list, data, players, context)
		return page
	if V.variante() == "A":
		list.add_child(Pastilles.pastille("Relais · " + _name(app, data.get("leaderId")), Pastilles.VIOLET, "star", "Relais pressenti", 18, "RelationshipLeaderPill", _ouvrir(app, data.get("leaderId"))))
	else:
		list.add_child(G.label("Relais pressenti : " + _name(app, data.get("leaderId")), 17))
		if not _player_target(app,data.get("leaderId")).is_empty(): _person_link(app,list,data.leaderId,"RelationshipLeaderPlayerLink")
	var chooser := OptionButton.new()
	chooser.name = "RelationshipPlayer"
	chooser.custom_minimum_size.y = 44
	chooser.fit_to_longest_item = false
	for p: Dictionary in players:
		chooser.add_item(_name(app, p.id) + " · " + str(p.pos))
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
	_duos(app, list, data, players, context)
	return page

static func _duos(app: Control, list: VBoxContainer, data: Dictionary, players: Array, context: Dictionary) -> void:
	list.add_child(G.separator())
	var titre_duo := G.h(8)
	titre_duo.add_child(G.section("Travailler un duo"))
	var info_duo := Pastilles.info("Deux partenaires disponibles. Le mentorat exige le relais pressenti en joueur A ; la médiation cible un lien inférieur à 8.", "i", "DuoInfo")
	info_duo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titre_duo.add_child(info_duo)
	list.add_child(titre_duo)
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
	var cartes_duo: Array = []
	for action: Dictionary in data.get("duoActions", []):
		if V.active():
			var agir := func(): app._command("relationship_duo", {"context":context, "mode":action.id, "a":players[a.selected].id, "b":players[b.selected].id})
			if V.variante() == "A": cartes_duo.append(V.tuile_action(str(action.id), str(action.label), str(action.detail), agir, "DuoAction_" + str(action.id), data.get("duoAvailable", false), 120))
			else: list.add_child(V.ligne_action(str(action.id), str(action.label), str(action.detail), agir, "DuoAction_" + str(action.id), data.get("duoAvailable", false)))
			continue
		var button := G.button(action.label, func(): app._command("relationship_duo", {"context":context, "mode":action.id, "a":players[a.selected].id, "b":players[b.selected].id}))
		button.name = "DuoAction_" + str(action.id)
		button.disabled = not data.get("duoAvailable", false)
		list.add_child(button); list.add_child(G.wrap(action.detail, 13))
	if not cartes_duo.is_empty(): list.add_child(V.rangee(cartes_duo))
	for pair: Dictionary in data.get("pairs", []):
		list.add_child(G.wrap("%s / %s · lien %s" % [_name(app, pair.a), _name(app, pair.b), int(pair.score)], 14))
		var people := G.h(6)
		list.add_child(people)
		_person_link(app,people,pair.a,"RelationshipDuoPlayerALink")
		_person_link(app,people,pair.b,"RelationshipDuoPlayerBLink")
	list.add_child(G.wrap(Copy.notice("relationships", data.get("notice", "")), 12))

static func _player(app: Control, parent: VBoxContainer, data: Dictionary, p: Dictionary, context: Dictionary) -> void:
	var identity: Dictionary = p
	for candidate: Dictionary in app.model.get("squad", []):
		if candidate.id == p.id: identity = candidate; break
	var fiche := _ouvrir(app, p.get("id"))
	if V.variante() == "B":
		var scene := G.h(18)
		scene.name = "RelationshipScene"
		scene.add_child(V.anneau(float(p.score) if p.get("score") != null else 0.0, "Satisf.", "heart", V.teinte(p.get("score")), 132, "RelationshipRingSatisfaction", fiche))
		var cote := G.v(8)
		G.fill(cote)
		scene.add_child(cote)
		var nom := _person_link(app, cote, p.id, "RelationshipPlayerLink")
		nom.add_theme_font_size_override("font_size", G.Base.reading_size(25))
		nom.add_theme_font_override("font", G.T.DISPLAY)
		var pers_b: Variant = p.get("personality")
		var etats_b := V.personnalite(str(pers_b.get("trait", "")) if pers_b is Dictionary else "", pers_b.get("leadership") if pers_b is Dictionary else null, fiche)
		etats_b.add_child(Pastilles.pastille(str(p.get("pos", "")), Charte.IVOIRE_2, "people", "Poste", 16, "RelationshipPos", fiche))
		if int(p.injury) > 0:
			etats_b.add_child(Pastilles.pastille("%d sem." % int(p.injury), Pastilles.ROUGE, "warning", "Blessure : %s semaine(s)." % p.injury, 16, "RelationshipInjuryWeeks", fiche))
		cote.add_child(etats_b)
		var tuiles_b := Components.h(8)
		tuiles_b.add_child(Pastilles.tuile("%d %%" % int(p.condition), "condition", Pastilles.VERT if int(p.condition) >= 80 else (Pastilles.ORANGE if int(p.condition) >= 50 else Pastilles.ROUGE), Charte.PANNEAU_2, 28, "RelationshipTileCondition", false, fiche))
		tuiles_b.add_child(Pastilles.tuile(_number(p.get("minutes")), "min", Pastilles.TURQUOISE, Charte.PANNEAU_2, 28, "RelationshipTileMinutes", false, fiche))
		cote.add_child(tuiles_b)
		parent.add_child(scene)
		for c: Dictionary in data.get("conversations", []):
			parent.add_child(V.ligne_action(str(c.id), str(c.label), str(c.detail), func(): app._command("relationship_conversation", {"context":context, "playerId":p.id, "choice":c.id}), "Conversation_" + str(c.id), p.get("conversationAvailable", false)))
		_promesses(app, parent, data, p, context)
		return
	_identity(app, parent, identity, str(p.id), "" if V.active() else "Entretien individuel · " + str(p.get("pos", "")))
	var personality: Variant = p.get("personality")
	if V.active():
		var pers: Variant = p.get("personality")
		var etats := V.personnalite(str(pers.get("trait", "")) if pers is Dictionary else "", pers.get("leadership") if pers is Dictionary else null, fiche)
		etats.add_child(Pastilles.pastille(str(p.get("pos", "")), Charte.IVOIRE_2, "people", "Poste", 16, "RelationshipPos", fiche))
		parent.add_child(etats)
	elif personality is Dictionary and not str(personality.get("trait", "")).is_empty():
		var character := G.wrap("Personnalité : %s · leadership %s / 100" % [personality.trait, _number(personality.get("leadership"))], 13)
		character.name = "RelationshipPersonality"
		parent.add_child(character)
	if p.get("score") != null: G.gauge(parent, "Satisfaction", float(p.score))
	var chiffres := Components.h(8)
	chiffres.name = "RelationshipFigures"
	chiffres.add_child(Pastilles.tuile(_number(p.get("score")), "satisf.", Pastilles.BLEU, Charte.PANNEAU_2, 30, "RelationshipTileSatisfaction", false, fiche))
	chiffres.add_child(Pastilles.tuile("%d %%" % int(p.condition), "condition", Pastilles.VERT if int(p.condition) >= 80 else (Pastilles.ORANGE if int(p.condition) >= 50 else Pastilles.ROUGE), Charte.PANNEAU_2, 30, "RelationshipTileCondition", false, fiche))
	chiffres.add_child(Pastilles.tuile(_number(p.get("minutes")), "min", Pastilles.TURQUOISE, Charte.PANNEAU_2, 30, "RelationshipTileMinutes", false, fiche))
	parent.add_child(chiffres)
	if int(p.injury) > 0:
		var blessure := Components.h(8)
		blessure.name = "RelationshipInjury"
		blessure.add_child(Pastilles.pastille("%d sem." % int(p.injury), Pastilles.ROUGE, "warning", "Blessure : %s semaine(s)." % p.injury, 18, "RelationshipInjuryWeeks", fiche))
		blessure.add_child(Pastilles.pastille("Promesse", Pastilles.ORANGE, "clock", "Promesse suspendue si aucune minute jouée.", 18, "RelationshipInjuryPromise", fiche))
		parent.add_child(blessure)
	if V.variante() == "A":
		var cartes: Array = []
		for c: Dictionary in data.get("conversations", []):
			cartes.append(V.tuile_action(str(c.id), str(c.label), str(c.detail), func(): app._command("relationship_conversation", {"context":context, "playerId":p.id, "choice":c.id}), "Conversation_" + str(c.id), p.get("conversationAvailable", false), 110))
		parent.add_child(V.rangee(cartes))
		_promesses(app, parent, data, p, context)
		return
	for c: Dictionary in data.get("conversations", []):
		var button := G.button(c.label + " · " + c.detail, func(): app._command("relationship_conversation", {"context":context, "playerId":p.id, "choice":c.id}))
		button.disabled = not p.get("conversationAvailable", false)
		button.name = "Conversation_" + str(c.id)
		parent.add_child(button)
	for history: Dictionary in data.get("conversationHistory", []).filter(func(h): return h.playerId == p.id).slice(0, 3):
		var choice := str({"ecouter":"Écouter", "rassurer":"Rassurer", "clarifier":"Clarifier"}.get(history.get("choice", ""), "Entretien individuel"))
		var memory := G.wrap("%s J%s · %s\nSatisfaction %s → %s" % [G.season_label(history.season), int(history.round) + 1, choice, _number(history.get("before")), _number(history.get("after"))], 13)
		memory.name = "RelationshipConversationMemory"
		parent.add_child(memory)
	var personal_events: Array = data.get("history", []).filter(func(h): return h.get("playerId") == p.id).slice(0, 3)
	if not personal_events.is_empty(): parent.add_child(G.section("Nos derniers échanges"))
	for history: Dictionary in personal_events:
		var choice := str({"ecouter":"Écouter", "cadrer":"Rappeler les exigences", "responsabiliser":"Confier un rôle"}.get(history.get("choice", ""), "Décision prise"))
		var memory := G.wrap("%s · semaine %s — %s\n%s" % [G.season_label(history.season), int(history.week) + 1, str(history.get("title", "")), choice], 13)
		memory.name = "RelationshipEventMemory"
		parent.add_child(memory)
	var promise: Variant = p.get("promise")
	if promise is Dictionary:
		parent.add_child(G.wrap("Promesse %s · %s minute(s) / %s rencontres sur 3" % [promise.target, int(promise.minutes), int(promise.completed)], 15))
	else:
		var regle := Components.h(8)
		regle.name = "RelationshipPromiseRule"
		var titre_promesse := Components.label("Promettre du temps de jeu", 20, Charte.IVOIRE, true, 600)
		titre_promesse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		regle.add_child(titre_promesse)
		regle.add_child(Pastilles.pastille("▲ +8", Pastilles.VERT, "", "Respect : +8 satisfaction.", 18))
		regle.add_child(Pastilles.pastille("▼ −10", Pastilles.ROUGE, "", "Non-respect : −10 satisfaction.", 18))
		regle.add_child(Pastilles.pastille("J24", Pastilles.BLEU, "calendar", "Dernière ouverture : journée 24.", 18))
		var info_promesse := Pastilles.info("Promettre du temps de jeu sur trois rencontres : respect +8 satisfaction ; non-respect −10. Dernière ouverture : journée 24.", "i", "PromiseInfo")
		info_promesse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		regle.add_child(info_promesse)
		parent.add_child(regle)
		for option: Dictionary in data.get("promiseOptions", []):
			var button := G.button("PROMETTRE %s MINUTES" % int(option.minutes), func(): app._command("relationship_promise", {"context":context, "playerId":p.id, "target":option.id}))
			button.disabled = not p.get("promiseAvailable", false)
			button.name = "Promise_" + str(option.id)
			parent.add_child(button)
	for h: Dictionary in p.get("promiseHistory", []).slice(-3):
		parent.add_child(G.wrap("%s J%s · %s · %s min" % [G.season_label(h.season), int(h.round) + 1, {"promise":"Engagement pris", "kept":"Promesse tenue", "broken":"Promesse rompue"}.get(h.status, h.status), int(h.minutes)], 13))

## ---- PROVISOIRE (revue visuelle du 21/11/2026, n° 4) : aides des options A / B ----

static func _identite(app: Control, id: Variant) -> Dictionary:
	for candidate: Dictionary in app.model.get("squad", []):
		if candidate.get("id") == id: return candidate
	return {"id": id}

## Promesse de temps de jeu en tuiles chrono ; promesse en cours en pastilles.
static func _promesses(app: Control, parent: VBoxContainer, data: Dictionary, p: Dictionary, context: Dictionary) -> void:
	var promise: Variant = p.get("promise")
	var titre := Components.h(8)
	titre.add_child(Components.label("Temps de jeu promis", 20, Charte.IVOIRE, true, 600))
	titre.add_child(Pastilles.pastille("J24", Pastilles.BLEU, "calendar", "Dernière ouverture : journée 24.", 16))
	parent.add_child(titre)
	if promise is Dictionary:
		var suivi := Components.h(8)
		suivi.add_child(Pastilles.tuile("%s" % str(promise.target), "objectif", Pastilles.TURQUOISE, Charte.PANNEAU_2, 28))
		suivi.add_child(Pastilles.tuile("%d" % int(promise.minutes), "min jouées", Pastilles.BLEU, Charte.PANNEAU_2, 28))
		suivi.add_child(Pastilles.tuile("%d / 3" % int(promise.completed), "rencontres", Pastilles.VIOLET, Charte.PANNEAU_2, 28))
		parent.add_child(suivi)
		return
	var cartes: Array = []
	for option: Dictionary in data.get("promiseOptions", []):
		cartes.append(V.tuile_promesse(int(option.minutes), func(): app._command("relationship_promise", {"context":context, "playerId":p.id, "target":option.id}), "Promise_" + str(option.id), p.get("promiseAvailable", false)))
	if not cartes.is_empty(): parent.add_child(V.rangee(cartes))

## Option B : rangée de portraits (relais, joueur choisi, puis les moins satisfaits) et « Tous » en petite fenêtre.
static func _portraits(app: Control, players: Array, data: Dictionary, selection: Dictionary, courant: Dictionary, details: VBoxContainer, context: Dictionary) -> Control:
	var identites := {}
	for p: Dictionary in players: identites[str(p.id)] = _identite(app, p.id)
	var relais := str(data.get("leaderId", ""))
	var rangs := players.duplicate()
	rangs.sort_custom(func(x, y): return float(x.get("score", 100) if x.get("score") != null else 100) < float(y.get("score", 100) if y.get("score") != null else 100))
	var montres: Array = []
	for p: Dictionary in players:
		if str(p.id) == relais: montres.append(p)
	if not courant in montres: montres.append(courant)
	for p: Dictionary in rangs:
		if montres.size() >= 7: break
		if not p in montres: montres.append(p)
	var rangee := Components.h(8)
	rangee.name = "RelationshipPortraits"
	var choisir := func(id: String):
		selection["playerId"] = id
		app._render()
	for p: Dictionary in montres:
		var id := str(p.id)
		rangee.add_child(V.vignette(app, p, identites[id], id == str(courant.id), id == relais, choisir.bind(id)))
	var tous := Components.v(4)
	var plus := Components.label("+%d" % maxi(0, players.size() - montres.size()), 30, Charte.IVOIRE, true, 800)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tous.add_child(plus)
	tous.add_child(Components.icon("people", 26, Charte.IVOIRE_2))
	var carte_tous := V.carte(tous, func(): V.fenetre_portraits(app, players, identites, str(courant.id), relais, choisir), "RelationshipAllPortraits", "Tout le groupe", Charte.FILET)
	carte_tous.custom_minimum_size = Vector2(C_px(90), 0)
	rangee.add_child(carte_tous)
	return rangee

static func C_px(v: float) -> int: return Components.px(v)
