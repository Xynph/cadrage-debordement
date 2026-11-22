extends SceneTree
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const ContextualFlow = preload("helpers/contextual_flow.gd")
# Run against the staged native project and an empty CD_GODOT_DATA_DIR. Every
# career/match transition below goes through main._command and the real worker.
const G = preload("res://ui/game_skin.gd")
## Contour du bouton « Voir l'entraînement » (director.gd, _add_training_entry).
const OBSERVE_BORDER = preload("res://ui/immersive08/components.gd").GOLD
var app: Control
var director: Node
var failures: Array[String] = []
var checks := 0
var directory := OS.get_environment("CD_CONTEXTUAL_ARTIFACTS")

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("CONTEXTUAL FAIL: " + message)

func settle() -> void:
	for i in 10: await process_frame

func wait_command(command: String, refusal: bool = false) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting, "Worker answered " + command)
	check(bool(app.bridge.last_response_ok) != refusal, "Real worker response " + command)
	app.timer.stop()
	await settle()
	app.timer.stop()

func ask(command: String, payload: Dictionary = {}, refusal: bool = false) -> void:
	app._command(command, payload)
	await wait_command(command, refusal)

# Same public daily progression as the guide/preferences receptions, with the
# actual mandatory rooms completed at each accepted progression boundary.
func prepare_match_day() -> bool:
	for day in 40:
		if not await ContextualFlow.settle_club_meetings(app, self, check): return false
		var cadence: Dictionary = app.model.meta.get("calendarCadence", {})
		if cadence.is_empty() or cadence.get("matchReady", false):
			check(app.model.get("next") is Dictionary, "Actual fixture exists on the permitted kickoff day")
			return app.model.get("next") is Dictionary
		check(cadence.get("canAdvance", false), "Actual calendar permits the next preparation day")
		if not cadence.get("canAdvance", false): return false
		await ask("advance_day", {"fromDate":app.model.meta.calendarToday})
		if not app.bridge.last_response_ok: return false
	check(false, "Actual calendar reaches kickoff within forty preparation days")
	return false

func talk() -> Dictionary:
	var value: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
	return value if value is Dictionary else {}

func viewport_check(container_name: String) -> void:
	var container: SubViewportContainer = director.view.find_child(container_name, true, false)
	check(container != null, container_name + " is a rendered SubViewportContainer")
	if container == null: return
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	check(container.get_global_rect().position.distance_to(screen.position) < 1.0 and container.size.distance_to(screen.size) < 1.0, container_name + " covers application at " + str(root.size))
	check(container.stretch, "Native viewport follows resolution")
	check(container.get_child_count() > 0 and container.get_child(0) is SubViewport, "Actual native viewport exists")
	if container.get_child_count() > 0 and container.get_child(0) is SubViewport:
		var viewport: SubViewport = container.get_child(0)
		check(viewport.size == root.size, "Native viewport pixels follow application")

func immersive_check(kind: String) -> void:
	check(director.active() and director.kind == kind, "Contextual director displays " + kind)
	check(not app.root_content.is_visible_in_tree(), "Career management shell hidden during " + kind)
	check(not app.coach.is_visible_in_tree(), "Career coach hidden during " + kind)
	check(director.overlay.get_global_rect().size.distance_to(Vector2(root.size)) < 1.0, "Immersion covers full application")
	for dialog in app.find_children("*", "AcceptDialog", true, false):
		check(not dialog.visible, "No global modal obscures contextual " + kind)

func locker_check(phase: String) -> void:
	check(talk().get("phase") == phase, "Real career phase " + phase)
	immersive_check("locker")
	viewport_check("ContextualRoomViewport")
	var grid: GridContainer = director.view.find_child("TalkDeclarations", true, false)
	check(grid != null and grid.get_child_count() == 6, phase + " has exactly six declaration buttons")
	if grid != null:
		var offered: Array = talk().get("options", []).map(func(option: Dictionary): return str(option.id))
		for button in grid.get_children():
			check(button is Button and str(button.get_meta("choice_id", "")) in offered, "Button is a permitted original declaration")
			check(button.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(button.get_global_rect()), "Declaration is visible at " + str(root.size))
	var cards: Array[Node] = []
	for button in director.view.find_children("*", "Button", true, false):
		if button.has_meta("participant_id"): cards.append(button)
	var ids: Array = talk().get("participants", []).map(func(player: Dictionary): return str(player.id))
	check(cards.size() == 23 and ids.size() == 23, "All actual 15 starters and 8 substitutes are represented")
	var found: Array[String] = []
	for card in cards:
		var id := str(card.get_meta("participant_id"))
		check(id in ids and not id in found, "Card belongs to one actual match participant")
		found.append(id)
		var player: Dictionary = {}
		for candidate: Dictionary in app.model.get("squad", []):
			if str(candidate.id) == id: player = candidate
		check(not player.is_empty(), "Participant resolves current squad identity")
		var number := 0
		for participant: Dictionary in talk().get("participants", []):
			if str(participant.id) == id: number = int(participant.number)
		var expected_position := str(player.get("pos", ""))
		if number >= 1 and number <= 15:
			for slot: Dictionary in app.model.get("selection", {}).get("slots", []):
				if int(slot.slot) == number - 1: expected_position = str(slot.label)
			if number in [6, 7] and expected_position == "Troisième ligne": expected_position = "Troisième ligne aile"
		if expected_position in ["Numéro 8", "N° 8", "N°8"]: expected_position = "Troisième ligne centre"
		var position_label: Label = card.find_child("ParticipantPosition", true, false)
		check(position_label != null and str(position_label.get_meta("position", "")) == expected_position and not expected_position.is_empty(), "Jersey role for starter or actual primary position for substitute " + id)
		if position_label != null:
			check(position_label.is_visible_in_tree() and card.get_global_rect().encloses(position_label.get_global_rect()), "Position is visibly contained in the actual player card")
			var name_label: Label = card.find_child("ParticipantName", true, false)
			check(str(card.get_meta("player_name", "")) == str(player.get("name", "")) and name_label != null and not name_label.text.is_empty(), "Card names the actual player")
			check(name_label != null and position_label.get_global_rect().position.x > name_label.get_global_rect().position.x, "Actual position is displayed next to the player name, in his row")
		var portrait: TextureRect = card.find_child("ParticipantPortrait", true, false)
		check(portrait != null and portrait.texture != null, "Actual participant has a visible portrait")
		if portrait != null and not player.is_empty():
			var expected := G.portrait(int(player.get("portraitIndex", 0)), 40, player)
			check(portrait.texture == expected.texture or portrait.texture.get_image().get_data() == expected.texture.get_image().get_data(), "Portrait is resolved using the same actual player ID")
			expected.free()
		check(card.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(card.get_global_rect()), "Participant remains on screen at " + str(root.size))
	# Tone is supplied by the selected declaration, never a second control.
	for control in director.view.find_children("*", "OptionButton", true, false):
		check(false, "No independent tone selector in the talk: " + str(control.name))

## Échap réel (pression puis relâchement) envoyé à la fenêtre, comme au clavier.
func press_escape() -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.physical_keycode = KEY_ESCAPE
		key.pressed = pressed
		root.push_input(key)
	await settle()
	while app.waiting: await process_frame
	await settle()

func pause_menu_open() -> bool:
	var menu: Node = root.find_child("ImmersivePauseMenu", true, false)
	return menu != null and menu is Window and (menu as Window).visible

func close_pause_menu() -> void:
	var menu: Node = root.find_child("ImmersivePauseMenu", true, false)
	if menu != null:
		menu.hide()
		menu.queue_free()
	await settle()

func capture(name: String) -> void:
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(directory.path_join(name + ".png")) == OK, "Saved actual rendered career screenshot " + name)

func actor_positions(stage: Node3D) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var players := stage.get_node_or_null("Players")
	if players != null:
		for player in players.get_children():
			if player is Node3D: positions.append(player.position)
	return positions

func reach(phase: String) -> void:
	for batch in 40:
		await ask("tick", {"steps":120})
		if not talk().is_empty():
			check(talk().get("phase") == phase, "Batched real match stops at " + phase)
			return
	check(false, "Real match did not reach " + phase)

func resolutions(historical: Array) -> Array:
	var requested := OS.get_environment("QA_RESOLUTION")
	if requested.is_empty(): return historical
	var dimensions := requested.to_lower().replace("×", "x").split("x")
	if dimensions.size() == 2 and dimensions[0].is_valid_int() and dimensions[1].is_valid_int() and int(dimensions[0]) > 0 and int(dimensions[1]) > 0:
		return [Vector2i(int(dimensions[0]), int(dimensions[1]))]
	check(false, "QA_RESOLUTION must specify widthxheight")
	return historical

func run() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty():
		printerr("Contextual QA requires an explicit disposable CD_GODOT_DATA_DIR")
		quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	if not directory.is_empty(): DirAccess.make_dir_recursive_absolute(directory)
	var initial_resolution: Vector2i = resolutions([Vector2i(1280,720)])[0]
	root.size = initial_resolution
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 30000
	while (app.model.is_empty() or app.waiting) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty(), "Real main scene connected to owned worker")
	app.timer.stop()
	# Production intentionally maximizes normal desktop windows. Detach that
	# presentation callback in this QA host so requested resolution tests measure
	# the actual client area rather than a silently re-maximized desktop.
	var maximize := Callable(app, "_keep_filled_display")
	if root.size_changed.is_connected(maximize): root.size_changed.disconnect(maximize)
	if root.focus_entered.is_connected(maximize): root.focus_entered.disconnect(maximize)
	root.mode = Window.MODE_WINDOWED
	root.size = initial_resolution
	await settle()
	check(root.size == initial_resolution, "Actual initial client area is exactly " + str(initial_resolution))
	await ask("new_career", {"mode":"common", "club":29})
	await ContextualFlow.settle_club_meetings(app, self, check)
	director = app.find_child("ContextualDirector", true, false)
	check(director != null, "Production contextual director installed")
	if director == null:
		await finish()
		return
	# Échap et petites fenêtres (mécanisme commun ui/petite_fenetre.gd) : la fenêtre d'abord, le menu de la carrière ensuite.
	if not director.active():
		var shell_window := Control.new()
		shell_window.name = "TestPetiteFenetreCoque"
		app.add_child(shell_window)
		PetiteFenetre.enregistrer(shell_window)
		await press_escape()
		check(not is_instance_valid(shell_window) or shell_window.is_queued_for_deletion(), "Escape closes an open small window first (shell)")
		check(not pause_menu_open(), "Escape that closed a small window does not open the career menu")
		await press_escape()
		check(pause_menu_open(), "Escape without a small window opens the career menu")
		await close_pause_menu()
	else: check(false, "Shell reachable for the Escape check")
	# The office is entered from an actual invitation, and a read cannot create it.
	var entries: Array = app.model.clubLife.sceneInvitations.invitations
	check(not entries.is_empty(), "New career has a contextual invitation")
	if not entries.is_empty():
		app._navigate("Réception")
		await settle()
		check(app.root_content.find_child("ContextualInvitations", true, false) == null, "Plus de bande d'invitations au-dessus de la Réception")
		var rows: Array = app.root_content.find_children("InboxSceneInvitation_*", "Button", true, false)
		check(rows.size() == entries.size(), "Chaque invitation du club est un message de la liste")
		var opener := app.root_content.find_child("InboxOpenSceneInvitation", true, false) as Button
		if opener == null and not rows.is_empty():
			rows[0].pressed.emit()
			await settle()
			opener = app.root_content.find_child("InboxOpenSceneInvitation", true, false) as Button
		check(opener != null, "L'invitation ouverte propose de l'ouvrir")
		if opener != null: opener.pressed.emit()
		else: director.open_invitation(str(entries[0].id))
		await wait_command("scene_invitation_open")
		immersive_check("conversation")
		await capture("office-real-career")
		await ask("scene_invitation_close", {"id":entries[0].id, "dismiss":true})
	# Visiting training is pure: it uses actual condition/load and does not train.
	await ask("export")
	var prior: String = app.model.meta.exportText
	for resolution in resolutions([Vector2i(1280,720), Vector2i(1920,1080)]):
		root.size = resolution
		app.Immersive.open_training(app)
		await settle()
		check(root.size == resolution, "Actual training client area matches requested " + str(resolution))
		var observe: Button = app.root_content.find_child("ContextualObserveTraining", true, false)
		check(observe != null and observe.is_visible_in_tree(), "Actual training route exposes Observe at " + str(resolution))
		if observe != null:
			var fond := observe.get_theme_stylebox("normal") as StyleBoxFlat
			# Charte : pilule à contour (fond transparent) ou fond sombre, jamais l'aplat blanc pleine largeur du thème Godot.
			var fond_sombre := fond != null and (fond.bg_color.a < .05 or fond.bg_color.get_luminance() < .3)
			var contour := fond != null and fond.border_width_top > 0 and fond.border_color.is_equal_approx(OBSERVE_BORDER)
			check(fond_sombre and contour and observe.size_flags_horizontal != Control.SIZE_EXPAND_FILL and observe.has_theme_stylebox_override("normal"), "Observe : style de bouton du jeu, plus le bouton blanc pleine largeur")
			observe.pressed.emit()
		else: director.open_training()
		await settle()
		immersive_check("training")
		await capture("training-before-session-" + str(resolution.x))
		director.close_training()
	root.size = initial_resolution
	await ask("export")
	check(app.model.meta.exportText == prior, "Observing preparation gives no training or morale gain")
	if not await prepare_match_day(): await finish(); return
	await ask("train")
	if not await ContextualFlow.settle_club_meetings(app, self, check): await finish(); return
	await ask("auto_lineup")
	await ask("begin_match")
	for resolution in resolutions([Vector2i(1280,720),Vector2i(1600,900)]):
		root.size = resolution
		await settle()
		check(root.size == resolution, "Actual locker client area matches requested " + str(resolution))
		locker_check("pre")
		await capture("pre-" + str(resolution.x))
	# Toute tuile agit : un joueur cliqué (onglet Groupe) ouvre sa petite fenêtre, puis sa fiche complète, puis le retour.
	var first_card: Button = director.view.find_child("Participant_1", true, false)
	check(first_card != null, "Player tile 1 exists")
	if first_card != null:
		first_card.pressed.emit()
		await settle()
		var popup: Node = director.view.find_child("TalkPlayerPopup", true, false)
		check(popup != null and popup.is_visible_in_tree(), "Clicking a player tile opens his window")
		await capture("pre-window")
		var full_sheet: Button = director.view.find_child("TalkPlayerFullSheet", true, false)
		check(full_sheet != null, "Player window offers the full sheet")
		if full_sheet != null:
			full_sheet.pressed.emit()
			await settle()
			check(director.view.find_child("TalkPlayerSheetCanvas", true, false) != null, "Full sheet opens over the locker")
			await capture("pre-sheet")
			var back: Button = director.view.find_child("TalkPlayerSheetBack", true, false)
			if back != null: back.pressed.emit()
			await settle()
			check(director.view.find_child("TalkPlayerSheet", true, false) == null, "Back closes the full sheet")
		# Échap : la fenêtre du joueur se ferme, le vestiaire reste (ni menu, ni sortie) ; la fiche complète aussi.
		first_card = director.view.find_child("Participant_1", true, false)
		first_card.pressed.emit()
		await settle()
		check(director.view.find_child("TalkPlayerPopup", true, false) != null, "Player window reopens")
		await press_escape()
		check(director.view.find_child("TalkPlayerPopup", true, false) == null, "Escape closes the player window")
		check(director.active() and director.kind == "locker" and talk().get("phase") == "pre" and not pause_menu_open(), "Escape on the player window leaves the locker and opens no menu")
		director.view.open_full_sheet(talk().participants[0].id)
		await settle()
		await press_escape()
		check(director.view.find_child("TalkPlayerSheet", true, false) == null and director.active(), "Escape closes the full sheet back to the locker")
	root.size = initial_resolution
	await settle()
	# A rejected public command remains visible inside the immersive surface.
	await ask("pause", {"paused":false}, true)
	immersive_check("locker")
	check(director.error_label.is_visible_in_tree() and not director.error_label.text.is_empty(), "Worker refusal is visible in contextual scene")
	check(talk().get("phase") == "pre", "Refusal leaves original talk active")
	await ask("snapshot")
	var option: Dictionary = talk().options[0]
	director.view._toggle_player(talk().participants[0].id)
	var choice_button: Button = null
	var declarations: GridContainer = director.view.find_child("TalkDeclarations", true, false)
	if declarations != null:
		for button in declarations.get_children():
			if str(button.get_meta("choice_id", "")) == str(option.id): choice_button = button
	check(choice_button != null and not choice_button.disabled, "A real selected recipient enables the declarations")
	if choice_button != null: choice_button.pressed.emit()
	check(app.waiting and app.last_command == "match_talk_decide", "Clicking a declaration pronounces it at once (public command bookkeeping)")
	var disabled_while_waiting := true
	for button in director.overlay.find_children("*", "BaseButton", true, false):
		if not button.disabled: disabled_while_waiting = false
	check(disabled_while_waiting, "Contextual decisions disabled while real worker is pending")
	await wait_command("match_talk_decide")
	check(talk().decision.choiceId == option.id and talk().decision.playerIds.size() == 1, "Real decision records offered choice and actual selected player")
	# Ton cliqué : la ligne du joueur visé prend la couleur franche de sa réaction, le mot reste dans la pastille.
	await process_frame
	var reaction: Dictionary = director.view.reaction_of(talk().decision, talk().participants[0].id)
	var ligne: Button = director.view.find_child("Participant_%d" % int(talk().participants[0].number), true, false)
	var fond_ligne: StyleBoxFlat = ligne.get_theme_stylebox("normal") as StyleBoxFlat if ligne != null else null
	var mot: Label = ligne.find_child("ParticipantReaction", true, false) if ligne != null else null
	check(not reaction.is_empty() and fond_ligne != null and fond_ligne.bg_color.is_equal_approx(preload("res://ui/charte.gd").PANNEAU.lerp(director.view.couleur_reaction(reaction), .38)), "The addressed player's whole row takes his reaction colour")
	check(mot != null and mot.text.contains(str(reaction.get("label", "?")).to_upper()), "The reaction word stays in the row's pill")
	await capture("pre-decision")
	director.view._continue()
	await wait_command("match_talk_continue")
	immersive_check("live")
	viewport_check("LiveMatchViewport")
	var stage: Node3D = director.view.stage
	check(stage != null and stage.get_script().resource_path == "res://match_view.gd", "Live match uses the production moving NativeMatchView")
	if stage != null:
		check(stage._club_crest != null and club_crest_matches(stage._club_crest, app.model.club), "Production stadium resolves the actual active club crest (pack, official, else recoloured club crest)")
		var branding: MultiMeshInstance3D = stage.get_node_or_null("ManagedClubCrests")
		check(branding != null and branding.visible, "Stadium fascia always carries the club crest")
		if branding != null: check(branding.material_override.albedo_texture == stage._club_crest, "Stadium fascia uses the active club identity")
		# Panneaux du pourtour : enfants directs du stade (les numéros des marqueurs tactiques des joueurs sont aussi des Label3D).
		var advertisements := stage.find_children("*", "Label3D", false, false)
		check(advertisements.size() == 16, "All sixteen Rugby Legacy advertising boards remain present")
		for label in advertisements:
			check(str(label.text) == "RUGBY LEGACY 27", "Advertising boards retain Rugby Legacy 27")
	var original_scene := JSON.stringify(app.model.live.scene)
	var original_positions: Array[Vector3] = actor_positions(stage) if stage != null else []
	await ask("tick", {"steps":6})
	check(JSON.stringify(app.model.live.scene) != original_scene, "Actual match presentation advances through worker ticks")
	if stage != null: check(stage.get_node_or_null("Players") != null and stage.get_node("Players").get_child_count() >= 30, "Production pitch has actual moving athlete actors")
	await create_timer(0.7).timeout
	app.timer.stop()
	if stage != null: check(actor_positions(stage) != original_positions, "Production athlete positions move after actual worker events")
	await capture("match-live")
	# En match : une petite fenêtre se ferme avant le menu du match ; puis Échap ouvre le menu, et le referme.
	var live_window := Control.new()
	live_window.name = "TestPetiteFenetreMatch"
	app.add_child(live_window)
	PetiteFenetre.enregistrer(live_window)
	await press_escape()
	var match_menu: Variant = director.view.get("menu")
	check(not is_instance_valid(live_window) or live_window.is_queued_for_deletion(), "Escape closes an open small window first (match)")
	check(not (match_menu is Control and is_instance_valid(match_menu) and match_menu.visible), "Escape that closed a small window does not open the match menu")
	await press_escape()
	match_menu = director.view.get("menu")
	check(match_menu is Control and is_instance_valid(match_menu) and match_menu.visible, "Escape without a small window opens the match menu")
	await press_escape()
	check(not (match_menu is Control and is_instance_valid(match_menu) and match_menu.visible), "Escape closes the match menu again")
	app.timer.stop()
	await reach("half")
	locker_check("half")
	check(app.model.live.atBreak, "Talk opens on real atBreak boundary")
	await capture("half")
	director.view._continue(true)
	await wait_command("match_talk_continue")
	await reach("post")
	locker_check("post")
	check(app.model.live.finished, "Debrief precedes validation of actual finished match")
	await ask("finish_round", {}, true)
	immersive_check("locker")
	check(director.error_label.is_visible_in_tree(), "Cannot bypass debrief with global finish")
	await capture("post")
	var match_day: String = app.model.meta.calendarToday
	var match_week: int = app.model.meta.week
	director.view._continue(true)
	await wait_command("match_talk_continue")
	check(app.model.live == null and not director.active(), "Post-match continue confirms the result and leaves immersion")
	check(app.model.meta.calendarToday == match_day and int(app.model.meta.week) == match_week and app.model.meta.calendarCadence.get("resultConfirmed", false), "Debrief confirms the actual result without skipping remaining days")
	check(app.root_content.is_visible_in_tree(), "Management returns after final match validation")
	for day in 7:
		if int(app.model.meta.week) != match_week: break
		await ask("advance_day", {"fromDate":app.model.meta.calendarToday})
		if not await ContextualFlow.settle_club_meetings(app, self, check): await finish(); return
	check(int(app.model.meta.week) == match_week + 1 and app.model.live == null, "The actual remaining days close exactly one match week")
	check(not director.active() and app.root_content.is_visible_in_tree(), "Management remains accessible after real weekly closure and meetings")
	await finish()

func finish() -> void:
	app.closing = true
	app.timer.stop()
	if is_instance_valid(app.coach): app.coach.destroy()
	if is_instance_valid(app.soundscape): app.soundscape.dispose()
	app.bridge.stop()
	var deadline := Time.get_ticks_msec() + 3000
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
	check(app.bridge.child_pid <= 0, "Owned worker closes")
	var report := {"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"real_worker":true,"sporting_rules_changed":false}
	if not directory.is_empty():
		var file := FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"  ")); file.close()
	print("CONTEXTUAL_FLOW ", JSON.stringify(report))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

## Blason attendu sur une surface 3D : celui du pack ou l'écusson officiel s'il existe, sinon l'écusson recoloré du
## club rendu depuis le contrôle de l'interface (ses initiales, sa couleur), jamais le bouclier gris de la banque.
func club_crest_matches(texture: Texture2D, club: Dictionary) -> bool:
	var Skin = load("res://ui/game_skin.gd")
	var real: Texture2D = Skin.crest_texture(club)
	if real != null: return texture == real
	var shown: Control = Skin.crest_render_control(texture)
	if shown == null or shown.name != "ClubCrestRecolored" or not shown.material is ShaderMaterial: return false
	var identity: Dictionary = club.get("presentation", club) if club.get("presentation") is Dictionary else club
	var initials := false
	for label in shown.find_children("*", "Label", true, false):
		if label.text == str(identity.get("abbr", "XV")): initials = true
	var primary: Color = load("res://ui/contextual/rooms/room_identity.gd").primary(identity)
	var material := shown.material as ShaderMaterial
	var tinted: bool = (material.get_shader_parameter("couleur_base") as Color).is_equal_approx(primary) or (material.get_shader_parameter("couleur_motif") as Color).is_equal_approx(primary)
	return initials and tinted
