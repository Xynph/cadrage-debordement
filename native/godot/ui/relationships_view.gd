extends RefCounted
const Copy = preload("res://ui/management_copy.gd")
const G = preload("res://ui/carnet_skin.gd")
const EntityLink = preload("res://ui/entity_link.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const Charte = preload("res://ui/charte.gd")
const Components = preload("res://ui/immersive08/components.gd")
const GameSkin = preload("res://ui/game_skin.gd")
const V = preload("res://ui/relationships_visuals.gd")
const CHOIX_GROUPE := {"ecouter":"Écouter", "cadrer":"Rappeler les exigences", "responsabiliser":"Confier un rôle"}
const CHOIX_ENTRETIEN := {"ecouter":"Écouter", "rassurer":"Rassurer", "clarifier":"Clarifier"}
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

static func _identity(app: Control, parent: Node, identity: Dictionary, id: String, detail: String, lien: String = "RelationshipPlayerLink") -> void:
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
	var heading := _person_link(app,text,id,lien)
	heading.add_theme_font_size_override("font_size",G.Base.reading_size(25))
	heading.add_theme_font_override("font",G.T.DISPLAY)
	if not detail.is_empty(): text.add_child(G.wrap(detail,13))

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
	# Moral et confiance du conseil en anneaux colorés (choix de Léo du 21/11/2026, revue n° 4, option B).
	var anneaux := G.h(24)
	anneaux.alignment = BoxContainer.ALIGNMENT_CENTER
	anneaux.name = "RelationshipRings"
	if data.get("morale") != null: anneaux.add_child(V.anneau(float(data.morale), "Moral", "heart", Charte.MORAL, 120, "RelationshipRingMorale", func(): app._navigate("Effectif")))
	if data.get("trust") != null: anneaux.add_child(V.anneau(float(data.trust), "Conseil", "shield", Charte.CONFIANCE, 120, "RelationshipRingTrust", func(): app._navigate("Club")))
	if anneaux.get_child_count() > 0: follow.add_child(anneaux)
	var event: Variant = data.get("event")
	if event is Dictionary:
		follow.add_child(G.section(str(event.title)))
		_identity(app, follow, _identite(app, event.playerId), str(event.playerId), "", "RelationshipEventPlayerLink")
		var etats := V.personnalite(str(event.get("trait", "")), event.get("leadership"), _ouvrir(app, event.playerId), "RelationshipEventTrait")
		etats.add_child(contexte(app, event))
		etats.move_child(etats.get_child(etats.get_child_count() - 1), 0)
		follow.add_child(etats)
		for choice: Dictionary in event.get("choices", []):
			follow.add_child(V.ligne_action(str(choice.id), str(choice.label), str(choice.detail), func(): app._command("locker_room_decision", {"context":context, "eventKey":event.key, "choice":choice.id}), "LockerDecision_" + str(choice.id), event.get("available", false)))
	else:
		follow.add_child(Pastilles.pastille("Aucune décision en attente", Charte.IVOIRE_2, "check", "La décision hebdomadaire est traitée, ou aucun entretien n’est disponible dans cette phase.", 18, "RelationshipNoEvent"))
	follow.add_child(G.separator())
	follow.add_child(G.section("Les engagements"))
	var commitments: Array = data.get("commitments", [])
	if commitments.is_empty(): follow.add_child(Components.label("Aucun engagement", 22, Charte.IVOIRE_2, true, 600))
	for c: Dictionary in commitments.slice(-8):
		var statut: Array = {"open":["À suivre", Pastilles.ORANGE, "clock"], "honored":["Honoré", Pastilles.VERT, "check"], "broken":["Non tenu", Pastilles.ROUGE, "warning"], "expired":["Clos", Charte.IVOIRE_2, "check"]}.get(c.status, [str(c.status), Charte.IVOIRE_2, "info"])
		var ligne := V.ligne_lien()
		_person_link(app, ligne, c.playerId, "RelationshipCommitmentPlayerLink")
		ligne.add_child(Pastilles.pastille(statut[0], statut[1], statut[2], "Engagement : " + str(statut[0]), 15))
		ligne.add_child(Pastilles.pastille("%d min" % int(c.target), Pastilles.TURQUOISE, "clock", "Objectif de minutes", 15))
		ligne.add_child(Pastilles.pastille("S%d" % (int(c.dueWeek) + 1), Pastilles.BLEU, "calendar", "Échéance : semaine de carrière %d" % (int(c.dueWeek) + 1), 15))
		follow.add_child(ligne)
	for e: Dictionary in data.get("history", []).slice(0, 6):
		var ligne := V.ligne_lien()
		_person_link(app, ligne, e.playerId, "RelationshipHistoryPlayerLink")
		ligne.add_child(V.pastille_choix(str(e.choice), str(CHOIX_GROUPE.get(e.choice, e.choice)), str(e.get("title", ""))))
		ligne.add_child(Pastilles.pastille("%s · S%d" % [G.season_label(e.season), int(e.week) + 1], Charte.IVOIRE_2, "calendar", "%s · semaine %d" % [G.season_label(e.season), int(e.week) + 1], 15))
		follow.add_child(ligne)
	var right := G.panel(page, 1.3)
	G.chapter(right, "12", "Les personnes et les liens", "", app.accent, "Un entretien par personne ; une intervention de groupe par semaine.")
	var list := G.scroll(right)
	list.get_parent().name = "RelationshipPeopleScroll"
	var players: Array = data.get("players", [])
	if players.is_empty():
		list.add_child(Pastilles.pastille("Aucun joueur suivi", Charte.IVOIRE_2, "people", "Aucun joueur suivi dans cette carrière.", 18, "RelationshipNoPlayer"))
		return page
	var selected := 0
	for i in players.size():
		if players[i].id == selection.get("playerId"): selected = i
	# Le groupe en portraits (relais étoilé, puis les moins satisfaits) ; « +N » ouvre la petite fenêtre de tout le groupe.
	if not _player_target(app, data.get("leaderId")).is_empty():
		var relais := Components.h(8)
		relais.name = "RelationshipLeader"
		var etoile := Components.icon("star", 22, Charte.OR)
		etoile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		relais.add_child(etoile)
		var lien := _person_link(app, relais, data.leaderId, "RelationshipLeaderPlayerLink")
		lien.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		lien.custom_minimum_size.x = 220
		list.add_child(relais)
	list.add_child(_portraits(app, players, data, selection, players[selected]))
	var details := G.v(10)
	list.add_child(details)
	_player(app, details, data, players[selected], context)
	_duos(app, list, data, players, context)
	return page

static func _duos(app: Control, list: VBoxContainer, data: Dictionary, players: Array, context: Dictionary) -> void:
	list.add_child(G.separator())
	var titre_duo := G.h(8)
	var section_duo := G.section("Travailler un duo")
	G.fill(section_duo)
	titre_duo.add_child(section_duo)
	var regle := "Deux partenaires disponibles. Le mentorat exige le relais pressenti en joueur A ; la médiation cible un lien inférieur à 8."
	var note := Copy.notice("relationships", data.get("notice", ""))
	var info_duo := Pastilles.info(regle + ("\n" + note if not note.is_empty() else ""), "i", "DuoInfo")
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
	var paire := G.h(10)
	G.fill(a); G.fill(b)
	paire.add_child(a)
	var lien_duo := Components.icon("people", 24, Pastilles.TURQUOISE)
	lien_duo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	paire.add_child(lien_duo)
	paire.add_child(b)
	list.add_child(paire)
	for action: Dictionary in data.get("duoActions", []):
		list.add_child(V.ligne_action(str(action.id), str(action.label), str(action.detail), func(): app._command("relationship_duo", {"context":context, "mode":action.id, "a":players[a.selected].id, "b":players[b.selected].id}), "DuoAction_" + str(action.id), data.get("duoAvailable", false)))
	for pair: Dictionary in data.get("pairs", []):
		var ligne := V.ligne_lien()
		ligne.name = "RelationshipPair"
		_person_link(app, ligne, pair.a, "RelationshipDuoPlayerALink")
		var lien := Components.icon("people", 20, Pastilles.TURQUOISE)
		lien.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(lien)
		_person_link(app, ligne, pair.b, "RelationshipDuoPlayerBLink")
		ligne.add_child(Pastilles.pastille("Lien %d" % int(pair.score), V.teinte(pair.score), "heart", "Lien %d / 100" % int(pair.score), 15))
		list.add_child(ligne)

static func _player(app: Control, parent: VBoxContainer, data: Dictionary, p: Dictionary, context: Dictionary) -> void:
	var fiche := _ouvrir(app, p.get("id"))
	# La personne choisie : anneau de satisfaction, nom, pastilles d'état, tuiles condition et minutes.
	var scene := G.h(18)
	scene.name = "RelationshipScene"
	scene.add_child(V.anneau(float(p.score) if p.get("score") != null else 0.0, "Satisf.", "heart", V.teinte(p.get("score")), 132, "RelationshipRingSatisfaction", fiche))
	var cote := G.v(8)
	G.fill(cote)
	scene.add_child(cote)
	var nom := _person_link(app, cote, p.id, "RelationshipPlayerLink")
	nom.add_theme_font_size_override("font_size", G.Base.reading_size(25))
	nom.add_theme_font_override("font", G.T.DISPLAY)
	var personnalite: Variant = p.get("personality")
	var etats := V.personnalite(str(personnalite.get("trait", "")) if personnalite is Dictionary else "", personnalite.get("leadership") if personnalite is Dictionary else null, fiche)
	if not str(p.get("pos", "")).is_empty(): etats.add_child(Pastilles.pastille(str(p.get("pos", "")), Charte.IVOIRE_2, "people", "Poste", 16, "RelationshipPos", fiche))
	if int(p.get("injury", 0)) > 0:
		etats.add_child(Pastilles.pastille("%d sem." % int(p.injury), Pastilles.ROUGE, "warning", "Blessure : %s semaine(s)." % p.injury, 16, "RelationshipInjuryWeeks", fiche))
		etats.add_child(Pastilles.pastille("Promesse", Pastilles.ORANGE, "clock", "Promesse suspendue si aucune minute jouée.", 16, "RelationshipInjuryPromise", fiche))
	cote.add_child(etats)
	var chiffres := Components.h(8)
	chiffres.name = "RelationshipFigures"
	chiffres.add_child(Pastilles.tuile("%d %%" % int(p.get("condition", 0)), "condition", Pastilles.VERT if int(p.get("condition", 0)) >= 80 else (Pastilles.ORANGE if int(p.get("condition", 0)) >= 50 else Pastilles.ROUGE), Charte.PANNEAU_2, 28, "RelationshipTileCondition", false, fiche))
	chiffres.add_child(Pastilles.tuile(_number(p.get("minutes")), "min", Pastilles.TURQUOISE, Charte.PANNEAU_2, 28, "RelationshipTileMinutes", false, fiche))
	cote.add_child(chiffres)
	parent.add_child(scene)
	for c: Dictionary in data.get("conversations", []):
		parent.add_child(V.ligne_action(str(c.id), str(c.label), str(c.detail), func(): app._command("relationship_conversation", {"context":context, "playerId":p.id, "choice":c.id}), "Conversation_" + str(c.id), p.get("conversationAvailable", false)))
	_promesses(app, parent, data, p, context)
	# Nos derniers échanges : une ligne visuelle par souvenir (réponse en pastille, date, satisfaction avant → après).
	var entretiens: Array = data.get("conversationHistory", []).filter(func(h): return h.playerId == p.id).slice(0, 3)
	var evenements: Array = data.get("history", []).filter(func(h): return h.get("playerId") == p.id).slice(0, 3)
	if entretiens.is_empty() and evenements.is_empty(): return
	parent.add_child(G.section("Nos derniers échanges"))
	for history: Dictionary in entretiens:
		var choix := str(history.get("choice", ""))
		var souvenir := V.souvenir(choix, str(CHOIX_ENTRETIEN.get(choix, "Entretien")), "", "%s J%d" % [G.season_label(history.season), int(history.round) + 1], history.get("before"), history.get("after"))
		souvenir.name = "RelationshipConversationMemory"
		parent.add_child(souvenir)
	for history: Dictionary in evenements:
		var choix := str(history.get("choice", ""))
		var souvenir := V.souvenir(choix, str(CHOIX_GROUPE.get(choix, "Décision prise")), str(history.get("title", "")), "%s S%d" % [G.season_label(history.season), int(history.week) + 1], null, null)
		souvenir.name = "RelationshipEventMemory"
		parent.add_child(souvenir)

static func _identite(app: Control, id: Variant) -> Dictionary:
	for candidate: Dictionary in app.model.get("squad", []):
		if candidate.get("id") == id: return candidate
	return {"id": id}

## Promesse de temps de jeu en tuiles chrono ; promesse en cours en tuiles chiffrées, historique en pastilles.
static func _promesses(app: Control, parent: VBoxContainer, data: Dictionary, p: Dictionary, context: Dictionary) -> void:
	var promise: Variant = p.get("promise")
	var titre := Components.h(8)
	titre.name = "RelationshipPromiseRule"
	titre.add_child(Components.label("Temps de jeu promis", 20, Charte.IVOIRE, true, 600))
	titre.add_child(Pastilles.pastille("J24", Pastilles.BLEU, "calendar", "Dernière ouverture : journée 24.", 16))
	parent.add_child(titre)
	if promise is Dictionary:
		var suivi := Components.h(8)
		suivi.name = "RelationshipPromise"
		suivi.add_child(Pastilles.tuile(str(promise.target), "objectif", Pastilles.TURQUOISE, Charte.PANNEAU_2, 28))
		suivi.add_child(Pastilles.tuile("%d" % int(promise.minutes), "min jouées", Pastilles.BLEU, Charte.PANNEAU_2, 28))
		suivi.add_child(Pastilles.tuile("%d / 3" % int(promise.completed), "rencontres", Pastilles.VIOLET, Charte.PANNEAU_2, 28))
		parent.add_child(suivi)
	else:
		var cartes: Array = []
		for option: Dictionary in data.get("promiseOptions", []):
			cartes.append(V.tuile_promesse(int(option.minutes), func(): app._command("relationship_promise", {"context":context, "playerId":p.id, "target":option.id}), "Promise_" + str(option.id), p.get("promiseAvailable", false)))
		if not cartes.is_empty(): parent.add_child(V.rangee(cartes))
	var passees: Array = p.get("promiseHistory", []).slice(-3)
	if passees.is_empty(): return
	var flux := HFlowContainer.new()
	flux.name = "RelationshipPromiseHistory"
	for h: Dictionary in passees:
		var etat: Array = {"promise":["Engagée", Pastilles.ORANGE, "clock"], "kept":["Tenue", Pastilles.VERT, "check"], "broken":["Rompue", Pastilles.ROUGE, "warning"]}.get(h.status, [str(h.status), Charte.IVOIRE_2, "info"])
		flux.add_child(Pastilles.pastille("%s · %d min" % [etat[0], int(h.minutes)], etat[1], etat[2], "%s J%d" % [G.season_label(h.season), int(h.round) + 1], 15))
	parent.add_child(flux)

## Le groupe en portraits : relais, joueur choisi, puis les moins satisfaits ; « +N » ouvre tout le groupe en petite fenêtre.
static func _portraits(app: Control, players: Array, data: Dictionary, selection: Dictionary, courant: Dictionary) -> Control:
	var identites := {}
	for p: Dictionary in players: identites[str(p.id)] = _identite(app, p.id)
	var relais := str(data.get("leaderId", ""))
	var rangs := players.duplicate()
	rangs.sort_custom(func(x, y): return float(x.get("score") if x.get("score") != null else 100) < float(y.get("score") if y.get("score") != null else 100))
	var montres: Array = []
	for p: Dictionary in players:
		if str(p.id) == relais: montres.append(p)
	if not (courant in montres): montres.append(courant)
	for p: Dictionary in rangs:
		if montres.size() >= 7: break
		if not (p in montres): montres.append(p)
	var rangee := Components.h(8)
	rangee.name = "RelationshipPortraits"
	var choisir := func(id: String):
		selection["playerId"] = id
		if app.has_method("_render"): app._render()
	for p: Dictionary in montres:
		var id := str(p.id)
		rangee.add_child(V.vignette(p, identites[id], id == str(courant.id), id == relais, choisir.bind(id)))
	var reste := players.size() - montres.size()
	if reste > 0:
		var tous := Components.v(4)
		var plus := Components.label("+%d" % reste, 30, Charte.IVOIRE, true, 800)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tous.add_child(plus)
		var groupe := Components.icon("people", 26, Charte.IVOIRE_2)
		groupe.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tous.add_child(groupe)
		var carte_tous := V.carte(tous, func(): V.fenetre_portraits(app, players, identites, str(courant.id), relais, choisir), "RelationshipAllPortraits", "Tout le groupe", Charte.FILET)
		carte_tous.custom_minimum_size.x = Components.px(90)
		rangee.add_child(carte_tous)
	return rangee
