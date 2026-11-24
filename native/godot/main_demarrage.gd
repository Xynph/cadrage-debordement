extends RefCounted
## Coque du jeu (main.gd) : démarrage (_ready : thème, services, pont moteur, Gabi, son, panneaux, intro, QA),
## préférences appliquées et placement de Gabi.
## Fonctions statiques ; `m` est la coque (main.gd), qui garde l’état et les noms appelés de l’extérieur.
const G = preload("res://ui/game_skin.gd")
const CommandWaitOverlay = preload("res://ui/command_wait_overlay.gd")
const ContinueProgress = preload("res://ui/continue_progress.gd")
const SaveIndicator = preload("res://ui/save_indicator.gd")
const ImmersiveDialogs = preload("res://ui/immersive08/dialogs.gd")
const ImmersiveStyle = preload("res://ui/immersive08/legacy_style.gd")
const Rythme = preload("res://match_rythme.gd")
const IntroSequence = preload("res://intro/intro_sequence.gd")

static func ready(m: Control) -> void:
	m._trace_startup("main.ready")
	var qa_script := ""
	var immersive_qa := OS.get_environment("CD_GODOT_IMMERSIVE_SELF_TEST") == "1"
	if immersive_qa: qa_script = "res://ui/immersive08/acceptance.gd"
	elif OS.get_environment("CD_GODOT_SELF_TEST") == "1": qa_script = "res://qa_runner.gd"
	var qa_data := OS.get_environment("CD_GODOT_DATA_DIR")
	if not qa_script.is_empty() and qa_data.is_empty():
		printerr("La réception exige un profil temporaire explicite.")
		m.get_tree().quit(2)
		return
	if immersive_qa:
		var directory := DirAccess.open(qa_data)
		if directory != null: directory.include_hidden = true
		if not qa_data.is_absolute_path() or (directory != null and (not directory.get_files().is_empty() or not directory.get_directories().is_empty())):
			printerr("La réception immersive exige un dossier absolu et vide.")
			m.get_tree().quit(2)
			return
	m.theme = G.T.make()
	# Retour visuel commun des tuiles et pastilles (survol, appui) : branché au premier survol de chaque bouton.
	load("res://ui/retour_tuile.gd").installer(m)
	m._trace_startup("theme.ready")
	var interface_layout: Node = load("res://ui/interface_layout.gd").new()
	m.interface_layout = interface_layout
	m.add_child(interface_layout)
	interface_layout.setup(m)
	m.catalogue = JSON.parse_string(FileAccess.get_file_as_string("res://assets/clubs.json"))
	var timer := Timer.new()
	m.timer = timer
	# Horloge du direct d'origine : elle surveille le rythme (match_rythme.gd), chaque fait reste à l'écran le temps d'être joué.
	timer.wait_time = Rythme.SCRUTATION
	timer.timeout.connect(Callable(m, "_live_tick"))
	m.add_child(timer)
	var file_dialog := FileDialog.new()
	m.file_dialog = file_dialog
	file_dialog.theme=ImmersiveStyle.theme(m.accent)
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.json ; Carrière Rugby Legacy 27"])
	file_dialog.file_selected.connect(Callable(m, "_file_selected"))
	m.add_child(file_dialog)
	ImmersiveDialogs.watch_file_picker(file_dialog)
	m._trace_startup("file_dialog.ready")
	var pack_manager: Node = load("res://pack_manager.gd").new()
	m.pack_manager = pack_manager
	pack_manager.app = m
	m.add_child(pack_manager)
	pack_manager.picker.theme=ImmersiveStyle.theme(m.accent)
	ImmersiveDialogs.watch_file_picker(pack_manager.picker)
	m._trace_startup("pack_manager.ready")
	var bridge: Node = load("res://engine_bridge.gd").new()
	m.bridge = bridge
	m.add_child(bridge)
	bridge.model_changed.connect(Callable(m, "_receive_model"))
	bridge.command_failed.connect(Callable(m, "_failed"))
	bridge.progressed.connect(Callable(m, "_continue_progressed"))
	bridge.persist_changed.connect(Callable(m, "_persist_changed"))
	m._trace_startup("bridge.created")
	var navigation_controller: Node = load("res://ui/navigation_controller.gd").new()
	m.navigation_controller = navigation_controller
	m.add_child(navigation_controller)
	navigation_controller.setup(m)
	var user_preferences: RefCounted = load("res://ui/user_preferences.gd").new()
	m.user_preferences = user_preferences
	user_preferences.changed.connect(Callable(m, "_apply_user_preferences"))
	var decision_feedback: RefCounted = load("res://ui/decision_feedback.gd").new()
	m.decision_feedback = decision_feedback
	decision_feedback.setup(m)
	m._trace_startup("guide.setup.begin")
	if OS.get_environment("CD_GODOT_GUIDE_MODULE_TEST") != "1":
		var coach: Control = load("res://ui/immersive08/coach_canvas.gd").new()
		m.coach = coach
		m.add_child(coach)
		coach.reserved_height_changed.connect(Callable(m, "_reserve_coach_space"))
		coach.setup(m, false)
	m._trace_startup("guide.setup.end")
	var soundscape: Node = preload("res://audio/soundscape.gd").new()
	m.soundscape = soundscape
	m.add_child(soundscape)
	soundscape.error_changed.connect(Callable(m, "_sound_error"))
	m.soundscape_ready = soundscape.setup(m)
	if is_instance_valid(m.coach) and is_instance_valid(m.coach.speech):
		m.coach.speech.speaking_changed.connect(Callable(soundscape, "set_voice_active"))
		soundscape.set_voice_active(m.coach.speech.speaking)
	m.resized.connect(func(): m.call_deferred("_layout_coach"))
	if qa_script.is_empty() and DisplayServer.get_name() != "headless":
		m.get_window().size_changed.connect(Callable(m, "_keep_filled_display"), Object.CONNECT_DEFERRED)
		m.get_window().focus_entered.connect(Callable(m, "_keep_filled_display"), Object.CONNECT_DEFERRED)
		m.call_deferred("_keep_filled_display")
	var contextual_director: Node = load("res://ui/contextual/director.gd").new()
	m.contextual_director = contextual_director
	contextual_director.name = "ContextualDirector"
	m.add_child(contextual_director)
	contextual_director.setup(m)
	var command_wait_overlay := CommandWaitOverlay.new()
	m.command_wait_overlay = command_wait_overlay
	command_wait_overlay.name = "CommandWaitOverlay"
	m.add_child(command_wait_overlay)
	var continue_progress := ContinueProgress.new()
	m.continue_progress = continue_progress
	m.add_child(continue_progress)
	var save_indicator := SaveIndicator.new()
	m.save_indicator = save_indicator
	m.add_child(save_indicator)
	m.waiting = true
	m._present_startup_wait()
	m._trace_startup("render.begin")
	m._render()
	m._trace_startup("render.end")
	m._trace_startup("bridge.start.begin")
	bridge.start(m._profile_path())
	m._trace_startup("bridge.start.end")
	# Ouverture du jeu (intro/) : cartes d'introduction pendant le démarrage du moteur, jamais en QA ni en test.
	if qa_script.is_empty() and IntroSequence.enabled():
		var intro: CanvasLayer = IntroSequence.new()
		m.add_child(intro)
		intro.setup(m, m._profile_path())
		# Gabi n'ouvre rien sous l'intro (coach_guide.gd) : son accueil attend l'écran révélé.
		intro.finished.connect(func(): m.call_deferred("_refresh_coach"))
	timer.start()
	m.get_tree().auto_accept_quit = false
	m.get_tree().root.close_requested.connect(Callable(m, "request_quit"))
	if not qa_script.is_empty():
		var qa: Node = load(qa_script).new()
		qa.app = m
		m.add_child(qa)

static func apply_user_preferences(m: Control) -> void:
	if m.user_preferences == null: return
	m.user_preferences.apply_audio()
	if is_instance_valid(m.coach) and is_instance_valid(m.coach.speech):
		m.coach.speech.set_global_volume(int(m.user_preferences.data.volume))
	if is_instance_valid(m.coach) and is_instance_valid(m.coach.portrait):
		m.coach.portrait.set_reduced_motion(bool(m.user_preferences.data.reduced_motion))
	if is_instance_valid(m.match_screen) and m.match_screen.has_method("apply_preferences"):
		m.match_screen.apply_preferences()

static func refresh_coach(m: Control) -> void:
	if is_instance_valid(m.contextual_director) and m.contextual_director.active():
		if is_instance_valid(m.coach): m.coach.hide()
		return
	if is_instance_valid(m.coach):
		m.coach.refresh()
		m.coach.consider_context(m.route, m.model, m.last_command, m.bridge.last_response_ok)
		if m.coach.has_method("observer_premiers_pas"): m.coach.observer_premiers_pas(m.route, m.model, m.last_command, m.bridge.last_response_ok)
	m._layout_coach()

static func layout_coach(m: Control) -> void:
	if not is_instance_valid(m.root_content) or not is_instance_valid(m.coach): return
	m.root_content.offset_bottom = 0.0
	if is_instance_valid(m.workspace_inset):
		m.workspace_inset.add_theme_constant_override("margin_bottom", 8)
