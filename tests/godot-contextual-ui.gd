extends SceneTree
# Structural contract fixtures only. End-to-end worker coverage is contextual-flow.
const Director = preload("res://ui/contextual/director.gd")
const Charte = preload("res://ui/charte.gd")
class Host extends Control:
	var model: Dictionary = {}
	var root_content: Control
	var coach: Control
	var timer: Timer
	var match_screen: Control
	var match_view: Node3D
	var pause_button: Button
	var match_finish: Button
	var match_clock: Label
	var waiting := false
	var last_error := ""
	var route := "Réception"
	var tick_steps := 1
	var user_preferences: Variant = null
	var body: Control
	var sent: Array = []
	func _command(command: String, payload: Dictionary = {}) -> bool:
		sent.append([command, payload.duplicate(true)])
		return true
	func _render(_remember: bool = false) -> void: pass
	func confirm(_title: String, _body: String, _callback: Callable) -> void: pass
	func notice(_title: String, _body: String) -> void: pass
var checks := 0
## Noms réalistes, dont de longs patronymes : aucun ne doit être coupé sur les tuiles.
const NOMS := ["Simon BRUNEAU", "Eliott CAZAUX", "Jaba BAKRADZE", "Léo HAMIDI", "Ropati SALANOA", "Thibaut VILLARD", "Gauthier SALAUN", "Loïc BERGER", "Taniela RAVOUVOU", "Melvin CABROL", "Tristan FREMONT", "Sébastien SCHNEIDER", "Geoffrey CHATELAIN", "Nathan LANDRY", "Simon ARNAUD", "Idrissa SANOGO-DIALLO", "Firmin BRASSEUR", "Ronan MURIEL", "Pierre-Alexandre LE GUELLEC", "Lucas OGOUNDELE", "Corentin GUILLEMOTEAU", "Emmanuel DESCHAMPS", "Mahé BOSC"]
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL ", message)
func settle() -> void:
	for i in 4: await process_frame
## Captures du vestiaire (CD_VESTIAIRE_OUTPUT : dossier ; rendu fenêtré seulement) : la fenêtre prend la taille voulue.
func taille(resolution: Vector2i) -> void:
	root.size = resolution
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution)
	await settle()
func photographier(nom: String) -> void:
	var sortie := OS.get_environment("CD_VESTIAIRE_OUTPUT")
	if DisplayServer.get_name() == "headless" or sortie.is_empty(): return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and image.save_png(sortie.path_join("vestiaire-" + nom + ".png")) == OK, "capture vestiaire-" + nom)
## Tuile du joueur qui contient ce nœud (bouton porteur de participant_id), quelle que soit la profondeur de la mise en page.
func card_of(node: Node) -> Control:
	while node != null and not node.has_meta("participant_id"): node = node.get_parent()
	return node as Control
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host := Host.new()
	root.size = Vector2i(1280, 720)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	host.root_content = Control.new(); host.add_child(host.root_content)
	host.coach = Control.new(); host.add_child(host.coach)
	host.timer = Timer.new(); host.add_child(host.timer)
	host.body = VBoxContainer.new(); host.root_content.add_child(host.body)
	var participants: Array = []
	var squad: Array = []
	for number in 23:
		var id := "test:ui:%d" % number
		participants.append({"id":id,"number":number + 1,"group":"forwards" if number < 8 or number in [15,16,17,18,19] else "backs"})
		squad.append({"id":id,"name":NOMS[number],"portraitIndex":number,"condition":85,"physicalLoad":{"fatigue":10}})
	# Deliberately mismatch primary positions and match jerseys. Bench numbers
	# must never be interpreted as a fixed role (16 is an actual fullback here).
	squad[0].pos = "Centre"
	squad[5].pos = "Talonneur"
	squad[15].pos = "Arrière"
	squad[22].pos = "Pilier droit"
	var options: Array = []
	# Six tons, un par déclaration (match-pilotage.js) : calme, exigeant, encourageant, furieux, rassurant, affirmé.
	var tones := [["calm","Calme"],["demanding","Exigeant"],["warm","Encourageant"],["furious","Furieux"],["protective","Rassurant"],["assertive","Affirmé"]]
	for i in 6: options.append({"id":"test:choice:%d" % i,"text":"Une déclaration courte %d." % i,"tone":tones[i][0],"toneLabel":tones[i][1],"intent":"focus"})
	var scene := {"key":"test:fixture","phase":"pre","context":{"score":[0,0]},"participants":participants,"options":options,"decision":null}
	host.model = {"club":{"id":0,"name":"Club de test","color":"#234e53"},"squad":squad,"meta":{"trained":false},"clubLife":{"matchTalks":{"scene":scene},"sceneInvitations":{"active":null}}}
	var director := Director.new(); host.add_child(director); director.setup(host)
	check(director.sync(), "talk opens")
	await settle()
	check(not host.root_content.visible and not host.coach.visible, "shell and coach hidden")
	check(director.view.options_grid.columns in [2, 6] and director.view.options_grid.get_child_count() == 6, "six declarations in a readable grid")
	# Le ton d'abord (en or, en capitales), la phrase dessous ; le ton furieux est un choix comme les autres.
	var tone_texts: Array = director.view.options_grid.find_children("TalkChoiceTone", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(tone_texts == ["CALME","EXIGEANT","ENCOURAGEANT","FURIEUX","RASSURANT","AFFIRMÉ"], "tone label first on each declaration " + str(tone_texts))
	var furious: Button = director.view.options_grid.find_child("TalkChoice_furious", true, false)
	check(furious != null and furious.get_meta("choice_id") == "test:choice:3" and str(furious.get_meta("text")) == "Une déclaration courte 3.", "furious declaration keeps its sentence under the tone")
	check(director.view.tone_label({"tone":"furious"}) == "Furieux" and director.view.tone_label({"tone":"warm","toneLabel":"Encourageant"}) == "Encourageant", "tone label falls back on the six French tones")
	# Captures : causerie avant la décision (six cartes de ton), en 1080p puis en 720p.
	await taille(Vector2i(1920,1080)); await photographier("avant-1920x1080")
	await taille(Vector2i(1280,720)); await photographier("avant-1280x720")
	check(director.overlay.get_global_rect().size == host.size, "overlay covers full viewport")
	var photos := director.view.find_children("ParticipantPortrait", "TextureRect", true, false)
	check(photos.size() == 23, "all 23 actual projected participants have portraits")
	var viewport := director.view.find_child("ContextualRoomViewport", true, false)
	check(viewport is SubViewportContainer and viewport.stretch and viewport.get_child(0).own_world_3d, "native full viewport room")
	var roles: Array = director.view.find_children("ParticipantPosition", "Label", true, false)
	check(roles.size() == 23, "each actual participant has a position under his name")
	for role: Label in roles:
		var card: Node = card_of(role)
		var id: String = str(card.get_meta("participant_id"))
		if id == participants[0].id: check(role.get_meta("position") == "Pilier gauche", "starter jersey 1 overrides primary centre")
		if id == participants[5].id: check(role.get_meta("position") == "Troisième ligne aile", "starter jersey 6 is flanker despite primary hooker")
		if id == participants[15].id: check(role.get_meta("position") == "Arrière", "bench jersey 16 shows actual primary fullback")
		if id == participants[22].id: check(role.get_meta("position") == "Pilier droit", "bench jersey 23 shows actual primary tighthead")
	check(director.view._position_label({"number":18}, {"rosterProfile":{"position":{"primary":"Centre"}}}) == "Centre", "missing bench pos uses authoritative profile primary")
	check(director.view._position_label({"number":16}, {}) == "Poste non renseigné", "missing bench position remains explicitly unknown")
	check(director.view._position_label({"number":20}, {"pos":"Numéro 8"}) == "Troisième ligne centre", "bench primary number eight uses third-row centre terminology")
	host.model.selection = {"slots":[{"slot":7,"label":"N° 8"}]}
	check(director.view._position_label({"number":8}, {"pos":"Arrière"}) == "Troisième ligne centre", "starter jersey 8 uses third-row centre terminology")
	for resolution in [Vector2i(1280,720),Vector2i(2560,1440)]:
		root.size = resolution
		await settle()
		for role: Label in director.view.find_children("ParticipantPosition", "Label", true, false):
			check(Rect2(Vector2.ZERO, host.size).encloses(role.get_global_rect()), "position label stays visible at " + str(resolution))
	# Toute tuile agit. Onglet Groupe : un clic sur chaque joueur ouvre sa petite fenêtre (numéro, tuiles d'état, fiche).
	var windows := 0
	for number in range(1, 24):
		var tile: Button = director.view.find_child("Participant_%d" % number, true, false)
		if tile == null: continue
		tile.pressed.emit()
		await process_frame
		var popup: Node = director.view.find_child("TalkPlayerPopup", true, false)
		if popup != null and str(popup.get_meta("player_id")) == str(tile.get_meta("participant_id")) \
			and popup.find_child("TalkPlayerPopupNumber", true, false).text == str(number) \
			and popup.find_child("TalkPlayerPopupTiles", true, false).get_child_count() >= 2 \
			and popup.find_child("TalkPlayerFullSheet", true, false) != null: windows += 1
		director.view.close_player_window()
		await process_frame
	check(windows == 23, "each player tile opens his own window (%d/23)" % windows)
	check(host.sent.is_empty(), "a player window sends no command")
	# Onglet Joueurs : un clic vise, un second clic retire.
	director.view._set_audience("players")
	for number in range(1, 24):
		var tile: Button = director.view.find_child("Participant_%d" % number, true, false)
		if tile != null: tile.pressed.emit()
	check(director.view.selected_ids.size() == 23 and director.view.find_children("ParticipantTargeted", "", true, false).size() == 23, "each player tile is targeted with a check in the Joueurs tab")
	for number in range(1, 24):
		var tile: Button = director.view.find_child("Participant_%d" % number, true, false)
		if tile != null: tile.pressed.emit()
	check(director.view.selected_ids.is_empty() and director.view.find_child("TalkPlayerPopup", true, false) == null, "a second click removes the target without opening a window")
	director.view._set_audience("group")
	var original := JSON.stringify(host.model)
	director.view._set_audience("players")
	var locked := true
	for card in director.view.options_grid.get_children():
		if not card.disabled: locked = false
	check(locked, "players audience without a chosen player keeps the declarations locked")
	director.view._select_choice(options[1])
	check(host.sent.is_empty(), "a declaration cannot be pronounced to nobody")
	director.view._toggle_player(participants[0].id)
	check(host.sent.is_empty() and JSON.stringify(host.model) == original, "recipient selection remains local")
	director.view._select_choice(options[1])
	check(host.sent.size() == 1 and host.sent[0][0] == "match_talk_decide", "clicking a declaration pronounces it without confirmation")
	check(director.view.find_child("TalkPronounce", true, false) == null, "no separate Prononcer confirmation button")
	check(host.sent[0][1].playerIds == [participants[0].id] and not host.sent[0][1].has("tone"), "real selected id and no caller-supplied tone")
	# Chaque tuile de ton prononce sa propre phrase.
	for i in 6:
		var tone_tile: Button = director.view.find_child("TalkChoice_" + str(options[i].tone), true, false)
		if tone_tile != null: tone_tile.pressed.emit()
	var spoken: Array = host.sent.slice(1).map(func(row: Array) -> String: return str(row[1].get("choiceId", "")))
	check(spoken == options.map(func(o: Dictionary) -> String: return str(o.id)), "each tone tile pronounces its own declaration " + str(spoken))
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = resolution
		await settle()
		for card in director.view.options_grid.get_children():
			check(Rect2(Vector2.ZERO, host.size).encloses(card.get_global_rect()), "choice fits " + str(resolution))
	host.waiting = true; director._refresh_controls()
	check(director.view.options_grid.get_child(0).disabled, "pending response disables duplicate command")
	host.waiting = false
	root.size = Vector2i(1280,720)
	# Réactions visibles (match-talks.cjs) : libellé de l'état, couleur selon le sens (delta).
	var states := [["galvanise","Galvanisé",1,2.1],["indifferent","Indifférent",0,0.1],["vexe","Vexé",-1,-1.8]]
	var reactions: Array = []
	for k in participants.size():
		var state: Array = states[k % 3]
		reactions.append({"id":participants[k].id,"score":state[3],"etat":state[0],"label":state[1],"delta":state[2]})
	scene.decision = {"choiceId":"test:choice:3","text":"Message prononcé","tone":"furious","toneLabel":"Furieux","intent":"focus","audience":"group","playerIds":participants.map(func(p: Dictionary): return p.id),"reactions":reactions,"moraleBefore":60,"moraleAfter":61,"moraleDelta":1,"par":"manager"}
	director.sync(); await settle()
	await photographier("apres-1280x720")
	await taille(Vector2i(1920,1080)); await photographier("apres-1920x1080")
	await taille(Vector2i(1280,720))
	# Après la parole : chaque ligne garde le mot de sa réaction dans une pastille et prend, ligne entière, la couleur
	# franche de cette réaction (Galvanisé, Indifférent et Vexé : trois teintes distinctes).
	var reaction_cards := 0
	var teintes := {}
	for card: Node in director.view.find_children("*", "Button", true, false):
		if not card.has_meta("participant_id"): continue
		var index: int = participants.map(func(p: Dictionary): return p.id).find(card.get_meta("participant_id"))
		var shown: Label = card.find_child("ParticipantReaction", true, false)
		var reaction: Dictionary = reactions[index] if index >= 0 else {}
		var attendu: Color = Charte.PANNEAU.lerp(director.view.couleur_reaction(reaction), .38)
		var fond: StyleBoxFlat = (card as Button).get_theme_stylebox("normal") as StyleBoxFlat
		if index >= 0 and shown != null and shown.text.contains(str(states[index % 3][1]).to_upper()) and fond != null and fond.bg_color.is_equal_approx(attendu):
			reaction_cards += 1
			teintes[states[index % 3][0]] = fond.bg_color
	check(reaction_cards == 23, "each player row shows his reaction word and is tinted with its colour (%d/23)" % reaction_cards)
	check(teintes.size() == 3 and not teintes.galvanise.is_equal_approx(teintes.vexe) and not teintes.galvanise.is_equal_approx(teintes.indifferent), "three reactions, three row colours")
	var go_on: Button = director.view.find_child("TalkContinue", true, false)
	check(go_on != null and go_on.custom_minimum_size.y >= 70 and go_on.get_theme_font_size("font_size") >= 24, "Continuer is a large primary button after the talk")
	if go_on != null: check(Rect2(Vector2.ZERO, host.size).encloses(go_on.get_global_rect()), "Continuer stays on screen at 720p")
	var decision_title: Label = director.view.find_child("TalkDecisionTone", true, false)
	check(decision_title != null and decision_title.text.contains("Furieux"), "decision recalls the tone")
	var morale_label: Label = director.view.find_child("TalkDecisionMorale", true, false)
	check(morale_label != null and morale_label.text == "Moral du groupe +1", "decision shows the group morale change")
	var summary: Node = director.view.find_child("TalkDecisionReactions", true, false)
	check(summary != null and summary.get_child_count() == 3, "decision sums up the visible reactions")
	for role: Label in director.view.find_children("ParticipantPosition", "Label", true, false):
		var card: Control = card_of(role)
		check(Rect2(Vector2.ZERO, host.size).encloses(card.get_global_rect()), "reaction player card stays on screen at 720p")
		for detail: Control in role.get_parent().get_children():
			check(card.get_global_rect().encloses(detail.get_global_rect()), "name, position and reaction fit the same player card at 720p " + str(detail.name) + " " + str(detail.get_global_rect()) + " in " + str(card.get_global_rect()))
	host.model.clubLife.matchTalks.scene = null
	check(not director.sync(), "empty context closes")
	check(host.root_content.visible and host.coach.visible, "shell restored")
	director.open_training(); await settle()
	check(director.kind == "training", "training observer is local")
	for mode in ["repos", "intense"]:
		host.model.meta.training = mode
		director.sync()
		director.view.maintained = true
		director.view._perform_training()
		check(host.sent.back()[0] == "train" and host.sent.back()[1].mode == mode, "Maintaining preserves actual training mode " + mode)
	host.model.meta.trained = true
	director.sync(); await settle()
	# Les cases et filtres du groupe (petite fenêtre, filtre local) ne décident rien : seules les actions comptent.
	var train_buttons := director.view.find_children("*", "Button", true, false).filter(func(b: Node) -> bool:
		var parent := str(b.get_parent().name)
		return not parent.begins_with("TrainingPlayerCell_") and not parent.begins_with("TrainingRoomFilter_"))
	check(train_buttons.size() == 1, "completed training is read only with only return action")
	var command_count := host.sent.size()
	director.view._perform_training()
	check(host.sent.size() == command_count, "completed training emits no second command")
	director.close_training()
	check(not director.active(), "training closes")
	host.coach.hide()
	director.open_training(); director.close_training()
	check(not host.coach.visible, "closing restores prior hidden coach preference")
	root.size = Vector2i(1280,720)
	host.model.clubLife.sceneInvitations.active = {"id":"test:invitation", "kind":"private_player", "participantId":participants[0].id, "available":true, "title":"Un entretien", "reason":"Une invitation réelle projetée par le domaine.", "options":options}
	director.sync(); await settle()
	check(director.kind == "conversation", "typed invitation opens office")
	var buttons := director.view.find_children("*", "Button", true, false)
	check(buttons.size() == 9, "server invitation choices and three explicit actions")
	for button in buttons:
		if button.text == "CONFIRMER LA RÉPONSE" or button.text == "REVENIR AU COURRIER":
			check(Rect2(Vector2.ZERO,host.size).encloses(button.get_global_rect()), "office action visible at 720p")
	host.last_error = "Refus explicite du moteur"
	await settle()
	check(director.error_label.visible and director.error_label.get_parent().visible and director.error_label.text == host.last_error, "server errors remain visible in immersion")
	host.free()
	await settle()
	print("CONTEXTUAL_UI_CHECKS checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
