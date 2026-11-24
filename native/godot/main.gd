extends Control
## Coque du jeu (scène principale) : état partagé de la carrière affichée et noms appelés de l'extérieur (ui/**,
## guide, intro, audio, qa_runner, tests). Le travail est rangé par responsabilité dans des modules statiques
## (`m` = cette coque) : main_demarrage.gd (démarrage, préférences, Gabi), main_moteur.gd (commandes et réponses
## du moteur, Continuer, direct d'origine), main_etat.gd (panneau d'attente, ligne d'état), main_rendu.gd (rendu
## d'un écran, rail, en-tête, bandeau du direct), main_navigation.gd (routes, presse, bouton principal) et
## main_dialogues.gd (confirmations, avis, menu de la carrière, import et export).

const G = preload("res://ui/game_skin.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const SeasonLabel = preload("res://ui/season_label.gd")
const CommandWaitOverlay = preload("res://ui/command_wait_overlay.gd")
const CareerProgression = preload("res://ui/career_progression.gd")
const ContinueProgress = preload("res://ui/continue_progress.gd")
const SaveIndicator = preload("res://ui/save_indicator.gd")
const Optimistic = preload("res://ui/optimistic_decisions.gd")
const ClubMail = preload("res://ui/club_mail.gd")
const ScreenRefresh = preload("res://ui/screen_refresh.gd")
const PortraitWarmup = preload("res://ui/portrait_warmup.gd")
const MainDemarrage = preload("res://main_demarrage.gd")
const MainMoteur = preload("res://main_moteur.gd")
const MainEtat = preload("res://main_etat.gd")
const MainRendu = preload("res://main_rendu.gd")
const MainNavigation = preload("res://main_navigation.gd")
const MainDialogues = preload("res://main_dialogues.gd")
## Constantes rangées dans les modules, gardées ici sous leur nom (Main.X, app.X).
const CONTINUE_SLICE_MS = MainMoteur.CONTINUE_SLICE_MS
const COMMAND_WAIT_REVEAL_SECONDS = MainEtat.COMMAND_WAIT_REVEAL_SECONDS
const COMMAND_WAIT_MESSAGES = MainEtat.COMMAND_WAIT_MESSAGES
const STARTUP_WAIT_MESSAGE = MainEtat.STARTUP_WAIT_MESSAGE
const LIVE_VIEW_WAIT_MESSAGE = MainEtat.LIVE_VIEW_WAIT_MESSAGE
const AUTOSAVE_ADVANCES = MainEtat.AUTOSAVE_ADVANCES
const READ_ONLY_COMMANDS = MainMoteur.READ_ONLY_COMMANDS
const COMMAND_WAIT_KICKERS = MainEtat.COMMAND_WAIT_KICKERS
const GABI_TIPS = MainEtat.GABI_TIPS
const Immersive = preload("res://ui/immersive08/shell.gd")
const ImmersiveEntry = preload("res://ui/immersive08/entry_canvas.gd")
const ImmersiveDialogs = preload("res://ui/immersive08/dialogs.gd")
const ImmersiveStyle = preload("res://ui/immersive08/legacy_style.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")
const Entry = preload("res://ui/entry_screens.gd")
const ClubViews = preload("res://ui/club_views.gd")
const SquadViews = preload("res://ui/squad_views.gd")
const MatchUI = preload("res://ui/match_screen.gd")
const Rythme = preload("res://match_rythme.gd")
const PackViews = preload("res://ui/pack_views.gd")
const StaffViews = preload("res://ui/staff_view.gd")
const DevelopmentViews = preload("res://ui/development_view.gd")
const PressViews = preload("res://ui/press_view.gd")
const RelationshipsViews = preload("res://ui/relationships_view.gd")
const WorldViews = preload("res://ui/world_view.gd")
const StrategyViews = preload("res://ui/strategy_view.gd")
const AcademyViews = preload("res://ui/academy_pathways_view.gd")
const AcademyFollowUpViews = preload("res://ui/academy_follow_up_view.gd")
const SupportViews = preload("res://ui/support_view.gd")
const ManagerCareerViews = preload("res://ui/manager_career_view.gd")
const PlaybookViews = preload("res://ui/playbook_view.gd")
const IntroSequence = preload("res://intro/intro_sequence.gd")
const NAV_CHAPTERS = [
	{"label":"Bureau", "routes":["Réception","Bureau"]},
	{"label":"Équipe", "routes":["Effectif","Composition","Préparation","Plan de jeu","Vestiaire","Match"]},
	{"label":"Développement", "routes":["Recrutement","Formation","Centre","Suivi des jeunes"]},
	{"label":"Club", "routes":["Club","Staff","Travail du club","Stratégie","Finances"]},
	{"label":"Compétitions", "routes":["Calendrier","Classements","Rivalités"]},
	{"label":"Carrière", "routes":["Carrière"]}
]
var model: Dictionary = {}
var catalogue: Array = []
var route := "Accueil"
var chapter_routes: Dictionary = {}
var selected_club := 0
var selected_player := ""
var selected_slot := 0
var selected_staff_club := -1
var club_division := "elite"
var table_division := "elite"
var roster_filter := "Tous"
var roster_sort := "Poste"
var management_ui: Dictionary = {}
var accent := Color("d43e47")
var bridge: Node
var command_wait_overlay: CommandWaitOverlay
var continue_progress: ContinueProgress
var save_indicator: SaveIndicator
var timer: Timer
var body: VBoxContainer
var heading: Label
var header_date: Label
var status: Label
var minibar: Label
var waiting := false
var connection_error := false
var last_error := ""
var pending_route := ""
var queued_action: Dictionary = {}
## Retouches affichées avant la réponse du moteur pour la décision en cours (optimistic_decisions.gd).
var optimistic_edits: Array = []
## Rafraîchissement par écran (ui/screen_refresh.gd) : après une réponse, l'écran n'est redessiné que s'il lit une
## section changée. Faux : rendu complet à chaque réponse (mesure témoin des tests).
var refresh_by_screen := true
## État de l'écran affiché au moment de son dernier rendu complet (ScreenRefresh.stamp).
var _screen_stamp: Dictionary = {}
## Dernier choix après une réponse (ScreenRefresh.FULL ou NONE) et nombre de rendus complets de l'écran (mesures).
var last_refresh := ""
var screen_renders := 0
var last_command := "snapshot"
var tick_steps := 1
## Direct d'origine : fait montré (clé), secondes déjà passées à l'écran, attente des déplacements.
var _rythme_cle := ""
var _rythme_ecoule := 0.0
var _rythme_place := 0.0
var closing := false
var file_dialog: FileDialog
var import_mode := false
var export_path := ""
var root_content: Control
var match_screen: Control
var match_page: Control
var match_view: Node3D
var match_clock: Label
var pause_button: Button
var match_finish: Button
var primary_button: Button
var pack_manager: Node
var coach: Control
var soundscape: Node
var soundscape_ready := false
var sound_profile_loaded := false
var navigation_controller: Node
var user_preferences: RefCounted
var decision_feedback: RefCounted
var contextual_director: Node
var preferences_loaded := false
var coach_reserved_height := 0.0
var workspace_inset: MarginContainer
var body_scroll: ScrollContainer
var entry_scroll: ScrollContainer
var interface_layout: Node
var _startup_trace := OS.get_environment("CD_GODOT_STARTUP_TRACE") == "1"
var _startup_model_seen := false
## Mesure des allers-retours UI→moteur (CD_GODOT_TIMING=1) : imprime une ligne CD_TIMING par réponse.
var _timing_trace := OS.get_environment("CD_GODOT_TIMING") == "1"
var _command_sent_us := 0
var timing_log: Array[Dictionary] = []

func _init() -> void:
	_trace_startup("main.init")

func _trace_startup(stage: String) -> void:
	if _startup_trace:
		print("CD_STARTUP ",JSON.stringify({"stage":stage,"pid":OS.get_process_id(),"engine_ms":Time.get_ticks_msec(),"unix_ms":int(Time.get_unix_time_from_system()*1000)}))

func _ready() -> void:
	MainDemarrage.ready(self)

func _profile_path() -> String:
	var explicit := OS.get_environment("CD_GODOT_DATA_DIR")
	return explicit if not explicit.is_empty() else OS.get_user_data_dir()

func _has_career() -> bool:
	return model.get("club") is Dictionary

func _live() -> Dictionary:
	return model.live if model.get("live") is Dictionary else {}

func _receive_model(value: Dictionary) -> void:
	# Coup d’envoi : la scène 3D se construit d’un bloc sur le fil principal. Le panneau d’attente est posé et
	# dessiné d’abord (deux images), puis la réponse est traitée : jamais d’écran figé sans message.
	var live_opening: bool = bridge.last_response_ok and last_command != "tick" and _opens_live_view(value) and is_instance_valid(command_wait_overlay)
	if live_opening:
		if not command_wait_overlay.panel_visible(): command_wait_overlay.set_context(_command_wait_context(last_command))
		command_wait_overlay.reveal_now(LIVE_VIEW_WAIT_MESSAGE)
		await get_tree().process_frame
		await get_tree().process_frame
		if closing: return
	MainMoteur.receive(self, value, live_opening)

func _record_timing(command: String, receive_us: int) -> void:
	MainMoteur.record_timing(self, command, receive_us)

## Commandes légères : jamais de panneau, l’interface reste disponible et une
## décision supplémentaire attend son tour au lieu d’être refusée.
static func shows_wait_panel(command: String) -> bool:
	return MainEtat.shows_wait_panel(command)

func _decision_due(value: Dictionary, ok: bool) -> bool:
	return MainMoteur.decision_due(value, ok)

func _stop_kind(value: Dictionary) -> String:
	var advance: Variant = value.get("meta", {}).get("advanceUntilEvent")
	return str(advance.stop.get("kind", "")) if advance is Dictionary and advance.get("stop") is Dictionary else ""

func _open_reprise_decision() -> void:
	if has_node("RepriseDialog"): return
	load("res://ui/reprise_dialog.gd").open(self)

func _command(command: String, payload: Dictionary = {}, target_route: String = "") -> bool:
	return MainMoteur.send_command(self, command, payload, target_route)

func _render_optimistic(edits: Array = []) -> void:
	MainMoteur.render_optimistic(self, edits)

func _screen_current() -> bool:
	return MainMoteur.screen_current(self)

func _screen_state() -> Dictionary:
	return MainMoteur.screen_state(self)

func _refresh_after_response(response_ok: bool, force_full: bool) -> void:
	MainMoteur.refresh_after_response(self, response_ok, force_full)

func _continue_payload(from_date: String) -> Dictionary:
	return MainMoteur.continue_payload(self, from_date)

func _continue_context() -> Dictionary:
	return MainMoteur.continue_context(self)

## Sauvegarde en arrière-plan du moteur : disquette discrète en bas de l'écran, sans jamais bloquer le joueur.
func _persist_changed(state: String, _message: String) -> void:
	if is_instance_valid(save_indicator): save_indicator.apply_state(state, user_preferences == null or not user_preferences.data.reduced_motion)

func _continue_progressed(progress: Dictionary) -> void:
	MainMoteur.continue_progressed(self, progress)

## « Jour suivant » (petit bouton du bandeau, Ctrl+J) : un seul jour, mêmes priorités que « Continuer ».
func next_day_available() -> bool:
	return MainNavigation.next_day_available(self)

func next_day_action() -> void:
	MainNavigation.next_day_action(self)

func _present_command_wait(command: String) -> void:
	MainEtat.present_command_wait(self, command)

func _opens_live_view(value: Dictionary) -> bool:
	return MainMoteur.opens_live_view(self, value)

func _present_startup_wait() -> void:
	MainEtat.present_startup_wait(self)

func autosave_expected(command: String) -> bool:
	return MainEtat.autosave_expected(self, command)

func _command_wait_context(command: String) -> Dictionary:
	return MainEtat.command_wait_context(self, command)

func _wait_division() -> String:
	return MainEtat.wait_division(self)

func _refuse_action(message: String) -> void:
	MainMoteur.refuse_action(self, message)

func _failed(message: String) -> void:
	MainMoteur.failed(self, message)

func _reset_reception(selected: String = "") -> void:
	MainNavigation.reset_reception(self, selected)

func _show_press_inbox() -> void:
	_reset_reception()
	_navigate("Réception", false)

func _open_press_conference() -> void:
	MainNavigation.open_press_conference(self)

func _open_postmatch_press() -> void:
	MainNavigation.open_postmatch_press(self)

## Identifiant du courrier de la conférence de presse ouverte cette semaine, vide s'il n'y en a pas.
func _pending_press_invitation() -> String:
	var conference: Dictionary = model.get("clubLife", {}).get("press", {}).get("conference", {})
	if not conference.get("available", false): return ""
	return str(conference.get("invitationId", "")) if conference.get("invitationId") != null else ""

func _open_press_invitation(id: String) -> void:
	MainNavigation.open_press_invitation(self, id)

func _navigate(target: String, remember_ui: bool = true, keep_subview: bool = false) -> void:
	MainNavigation.navigate(self, target, remember_ui, keep_subview)

func _match_visible() -> bool:
	return route == "Match" and is_instance_valid(match_screen) and match_screen.is_visible_in_tree()

func _sound_error(message: String) -> void:
	MainEtat.sound_error(self, message)

func _show_sound_error(message: String) -> void:
	MainEtat.show_sound_error(self, message)

func _build_subnavigation(parent: Container) -> void:
	MainRendu.build_subnavigation(self, parent)

## Rendu complet de l'écran ; note son état (ScreenRefresh.stamp) quand un nouvel arbre a été construit.
func _render(remember_ui: bool = true) -> void:
	MainRendu.render(self, remember_ui)

func _render_screen(remember_ui: bool) -> void:
	MainRendu.render_screen(self, remember_ui)

func _entry_workspace(page: Control) -> void:
	MainRendu.entry_workspace(self, page)

func _reserve_coach_space(_height: float) -> void:
	coach_reserved_height = 0.0
	_layout_coach()

func _refresh_coach() -> void:
	MainDemarrage.refresh_coach(self)

func _observe_navigation() -> void:
	if is_instance_valid(navigation_controller): navigation_controller.observe(route, selected_player, selected_staff_club)

## Le pied de page immersif ajuste la ligne d'état à la place libre (shell.gd, _fit_status) après chaque changement de texte.
func _refit_status() -> void:
	if is_instance_valid(status) and status.has_meta("refit"): (status.get_meta("refit") as Callable).call()

func _settled_status_text() -> String:
	return MainEtat.settled_status_text(self)

func _status_line_text() -> String:
	return MainEtat.status_line_text(self)

func _autosave_status() -> String:
	return MainEtat.autosave_status(self)

func _autosave_alert() -> bool:
	var info: Variant = model.get("meta",{}).get("autosave")
	return info is Dictionary and info.get("notice") is Dictionary and bool(info.notice.get("alert",false))

## Voyant « Stockage à vérifier » : seulement un vrai problème d'écriture (sauvegarde, sauvegarde automatique,
## préférences), jamais une décision refusée par les règles du jeu (recette native du 16/11/2026).
func _storage_has_error() -> bool:
	return model.get("meta",{}).get("saveError",false) or _autosave_alert() or (user_preferences != null and not user_preferences.last_error.is_empty())

func _status_has_error() -> bool:
	return not last_error.is_empty() or model.get("meta",{}).get("saveError",false) or _autosave_alert() or (user_preferences != null and not user_preferences.last_error.is_empty()) or (is_instance_valid(soundscape) and not soundscape.last_error.is_empty())

func _apply_user_preferences() -> void:
	MainDemarrage.apply_user_preferences(self)

func _set_display_mode(mode: Window.Mode) -> void:
	if DisplayServer.get_name() == "headless": return
	var window := get_window()
	var screen := window.current_screen
	window.mode = mode
	if screen >= 0 and screen < DisplayServer.get_screen_count() and window.current_screen != screen:
		window.current_screen = screen

func _keep_filled_display() -> void:
	# La restauration depuis la barre de titre ou un raccourci système reste maximisée.
	if not closing and get_window().mode == Window.MODE_WINDOWED:
		_set_display_mode(Window.MODE_MAXIMIZED)

func _layout_coach() -> void:
	MainDemarrage.layout_coach(self)

func _open_coach() -> void:
	if is_instance_valid(coach): coach.open_help()

func _update_header_date() -> void:
	MainRendu.update_header_date(self)

func _build_sidebar(parent: Node) -> void:
	MainRendu.build_sidebar(self, parent)

func _update_live_bar() -> void:
	MainRendu.update_live_bar(self)

static func fit_button_text(button: Button) -> void:
	MainRendu.fit_button_text(button)

func _press_required() -> bool:
	return not Immersive.Selections.nation_only(model) and CareerProgression.press_required(model)

func _daily_progression() -> Dictionary:
	return MainNavigation.daily_progression(self)

func primary_tooltip() -> String:
	return MainNavigation.primary_tooltip(self)

func continue_block() -> String:
	return MainNavigation.continue_block(self)

func primary_text() -> String:
	return MainNavigation.primary_text(self)

func primary_action() -> void:
	MainNavigation.primary_action(self)

func create_career(id: int) -> void:
	MainDialogues.create_career(self, id)

func confirm_decision(command: String, payload: Dictionary, title: String, text: String, callback: Callable) -> void:
	MainDialogues.confirm_decision(self, command, payload, title, text, callback)

func _confirmation_club(title: String, lignes: Array, libelle_ok: String, callback: Callable) -> bool:
	return MainDialogues.confirmation_club(self, title, lignes, libelle_ok, callback)

func _lignes_decision(detail: Dictionary) -> String:
	return MainDialogues.lignes_decision(detail)

func confirm(title: String, text: String, callback: Callable, focus_cancel := false) -> void:
	MainDialogues.confirm(self, title, text, callback, focus_cancel)

func _prepare_dialog(dialog: AcceptDialog, width: int) -> void:
	MainDialogues.prepare_dialog(self, dialog, width)

func pause_menu() -> void:
	MainDialogues.pause_menu(self)

## Réglages : en carrière, l'écran « Réglages » de la coque (règle « jamais de petite fenêtre ») ; hors carrière
## (accueil, création, packs), la fenêtre des paramètres.
func settings() -> void:
	if _has_career() and route not in ["Accueil", "Création", "Packs"]: _navigate("Réglages")
	else: preferences_window()

## Fenêtre des paramètres (hors carrière). Même contenu que l'écran Réglages (preferences_dialog.gd, _fill) :
## les recettes l'ouvrent directement pour vérifier ce contenu partagé.
func preferences_window() -> AcceptDialog:
	return preload("res://ui/preferences_dialog.gd").open(self, user_preferences)

func open_career_slots() -> void:
	preload("res://ui/career_slots_view.gd").open(self)

## Nouvelle carrière sans perdre la carrière en cours : elle est rangée dans « Mes carrières », puis le choix du club s'ouvre.
func new_career_slot() -> void:
	preload("res://ui/career_slots_view.gd").open(self, true)

func open_profile_safety() -> void:
	preload("res://ui/profile_safety_view.gd").open(self)

func open_file(importing: bool) -> void:
	MainDialogues.open_file(self, importing)

func _file_selected(path: String) -> void:
	MainDialogues.file_selected(self, path)

func _write_export() -> bool:
	return MainDialogues.write_export(self)

func notice(title:String,text:String) -> void:
	MainDialogues.notice(self, title, text)

func _clear_dialogs() -> void:
	MainDialogues.clear_dialogs(self)

func recover_profile() -> void:
	confirm("Conserver et récupérer le profil", "Une copie du profil endommagé sera conservée avant sa récupération. Tu pourras ensuite créer ou importer une carrière.",func(): _command("recover_profile",{"confirmed":true}))

func reconnect() -> void:
	MainMoteur.reconnect(self)

func _live_tick() -> void:
	MainMoteur.live_tick(self)

func _update_match() -> void:
	if is_instance_valid(match_screen): match_screen.update_frame(model)

func _credits() -> void:
	_clear_dialogs()
	var d := AcceptDialog.new()
	_prepare_dialog(d, 760)
	preload("res://ui/credits_view.gd").fill(d)
	add_child(d)
	ImmersiveDialogs.show_centered(d, Vector2i(900,640))
	d.confirmed.connect(d.queue_free)

## Reprise avant le match (décision de Léo, 16/11/2026) : une carrière n'est jamais enregistrée en plein match. Du coup
## d'envoi à la validation du résultat (direct, entracte, causeries), quitter fait reprendre la carrière avant le coup
## d'envoi : le manager le confirme d'abord. Une fermeture imposée par le système n'est jamais bloquée (le moteur
## reprend alors de lui-même avant le match).
const QUIT_DURING_MATCH_TEXT := "Le match est en cours. Si tu quittes maintenant, tu reprendras avant le coup d’envoi et ce match sera à rejouer."

func match_in_progress() -> bool:
	if _live().is_empty(): return false
	var cadence: Variant = model.get("meta",{}).get("calendarCadence")
	return not (cadence is Dictionary and bool(cadence.get("resultConfirmed",false)))

func request_quit() -> void:
	if match_in_progress(): confirm("Quitter pendant le match", QUIT_DURING_MATCH_TEXT, _close, true)
	else: _close()

func _close(exit_code: int = 0) -> void:
	if closing: return
	closing = true
	if is_instance_valid(navigation_controller): navigation_controller.invalidate_readers()
	command_wait_overlay.dismiss()
	if is_instance_valid(soundscape): soundscape.dispose()
	if is_instance_valid(coach): coach.destroy()
	timer.stop()
	bridge.stop()
	# Le moteur écrit d'abord une éventuelle décision en attente : attendre sa sortie (le pont le tue au-delà).
	var deadline := Time.get_ticks_msec()+NativeEngineBridge.STOP_GRACE_MS+300
	while bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	get_tree().quit(exit_code)

func _input(event: InputEvent) -> void:
	# Prevent the focused control and shortcuts from bypassing the pointer veil.
	# The fade-out after a response no longer holds input (like the pointer).
	if is_instance_valid(command_wait_overlay) and command_wait_overlay.blocks_input() and (event is InputEventKey or event is InputEventJoypadButton):
		command_wait_overlay.handle_key(event)
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(navigation_controller) and navigation_controller.handle_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	# Échap ferme d'abord une petite fenêtre ouverte (ui/petite_fenetre.gd), sans ouvrir le menu de la carrière.
	if event.is_action_pressed("ui_cancel") and PetiteFenetre.fermer_derniere(get_tree()):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and is_instance_valid(continue_progress) and continue_progress.running:
		continue_progress.request_stop()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _has_career(): pause_menu()
		else: _navigate("Accueil")
