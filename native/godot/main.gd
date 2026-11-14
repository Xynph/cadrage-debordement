extends Control

const G = preload("res://ui/game_skin.gd")
const SeasonLabel = preload("res://ui/season_label.gd")
const CommandWaitOverlay = preload("res://ui/command_wait_overlay.gd")
const CareerProgression = preload("res://ui/career_progression.gd")
## Seuil unique : le panneau d’attente n’apparaît qu’au-delà de 0,5 s (sinon simple flash).
const COMMAND_WAIT_REVEAL_SECONDS := 0.5
const COMMAND_WAIT_MESSAGES := {
	"new_career": "Création de la carrière…",
	"import": "Importation de la carrière…",
	"export": "Préparation de l’export…",
	"save": "Sauvegarde de la carrière…",
	"recover_profile": "Préservation et récupération du profil…",
	"restore_checkpoint": "Reprise de la copie de sécurité…",
	"remove_checkpoint": "Suppression de la copie de sécurité…",
	"pack_inspect": "Analyse du pack d’identités…",
	"pack_install": "Installation du pack d’identités…",
	"pack_select": "Application du pack d’identités…",
	"begin_match": "Préparation du coup d’envoi…",
	"delegate": "Simulation de la rencontre…",
	"finish_round": "Mise à jour de la journée…",
	"advance_day": "Passage au jour suivant…",
	"preseason_advance": "Avance de l’avant-saison…",
	"next_season": "Préparation de la nouvelle saison…",
	"advance_pacific_preparation": "Avance de la préparation…",
	"advance_japan_preparation": "Avance de la préparation…",
	"advance_champ_preparation": "Avance de la préparation…",
	"population_enable": "Mise à jour de la base de joueurs…",
	"academy_groups_enable": "Mise à jour des centres de formation…",
	"promote_cover": "Enregistrement des renforts…",
	"national_play_match": "Simulation de la rencontre internationale…",
	"league_benchmark": "Mesure de votre machine…",
	"club_sheet": "Préparation de la fiche du club…",
	"league_detail_set": "Enregistrement des championnats simulés…"
}
## Commandes de lecture pure (aucun changement d'état de carrière).
const READ_ONLY_COMMANDS := ["club_sheet"]
## Titre du panneau d’attente par commande (les autres : « En coulisses »).
const COMMAND_WAIT_KICKERS := {
	"advance_day": "Passage au jour suivant",
	"finish_round": "Fin de journée",
	"delegate": "Le match se joue",
	"begin_match": "Avant le coup d’envoi",
	"next_season": "Intersaison",
	"new_career": "Nouvelle carrière",
	"import": "Reprise de carrière",
	"restore_checkpoint": "Reprise de carrière",
	"save": "Sauvegarde",
	"national_play_match": "Sélection nationale"
}
## Conseils de Gabi affichés pendant une attente (fonctions réelles du jeu).
const GABI_TIPS := [
	"Avant un match, passez par la Préparation : les consignes d’attaque et de défense se règlent en un clic.",
	"Un joueur lourdement chargé peut souffler : passez sa charge en « repos » depuis le suivi de fatigue.",
	"La composition automatique propose un XV cohérent ; vous gardez la main poste par poste ensuite.",
	"Une observation ciblée affine la fourchette de niveau d’un joueur avant de lui faire une offre.",
	"Le centre de formation récompense la patience : suivez la progression des jeunes semaine après semaine.",
	"En conférence de presse, vos réponses pèsent sur le moral du vestiaire et sur la confiance de la direction.",
	"Le calendrier signale les jours de match : avancez jour par jour pour ne rien manquer du courrier.",
	"Les contrats qui arrivent à échéance apparaissent au Bureau : anticipez les prolongations."
]
const Immersive = preload("res://ui/immersive08/shell.gd")
const ImmersiveEntry = preload("res://ui/immersive08/entry_canvas.gd")
const ImmersiveDialogs = preload("res://ui/immersive08/dialogs.gd")
const ImmersiveStyle = preload("res://ui/immersive08/legacy_style.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")
const Entry = preload("res://ui/entry_screens.gd")
const ClubViews = preload("res://ui/club_views.gd")
const SquadViews = preload("res://ui/squad_views.gd")
const MatchUI = preload("res://ui/match_screen.gd")
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
var last_command := "snapshot"
var tick_steps := 1
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
	_trace_startup("main.ready")
	var qa_script := ""
	var immersive_qa := OS.get_environment("CD_GODOT_IMMERSIVE_SELF_TEST") == "1"
	if immersive_qa: qa_script = "res://ui/immersive08/acceptance.gd"
	elif OS.get_environment("CD_GODOT_SELF_TEST") == "1": qa_script = "res://qa_runner.gd"
	var qa_data := OS.get_environment("CD_GODOT_DATA_DIR")
	if not qa_script.is_empty() and qa_data.is_empty():
		printerr("La réception exige un profil temporaire explicite.")
		get_tree().quit(2)
		return
	if immersive_qa:
		var directory := DirAccess.open(qa_data)
		if directory != null: directory.include_hidden = true
		if not qa_data.is_absolute_path() or (directory != null and (not directory.get_files().is_empty() or not directory.get_directories().is_empty())):
			printerr("La réception immersive exige un dossier absolu et vide.")
			get_tree().quit(2)
			return
	theme = G.T.make()
	_trace_startup("theme.ready")
	interface_layout = load("res://ui/interface_layout.gd").new()
	add_child(interface_layout)
	interface_layout.setup(self)
	catalogue = JSON.parse_string(FileAccess.get_file_as_string("res://assets/clubs.json"))
	timer = Timer.new()
	timer.wait_time = 0.32
	timer.timeout.connect(_live_tick)
	add_child(timer)
	file_dialog = FileDialog.new()
	file_dialog.theme=ImmersiveStyle.theme(accent)
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.json ; Carrière Rugby Legacy 27"])
	file_dialog.file_selected.connect(_file_selected)
	add_child(file_dialog)
	ImmersiveDialogs.watch_file_picker(file_dialog)
	_trace_startup("file_dialog.ready")
	pack_manager = load("res://pack_manager.gd").new()
	pack_manager.app = self
	add_child(pack_manager)
	pack_manager.picker.theme=ImmersiveStyle.theme(accent)
	ImmersiveDialogs.watch_file_picker(pack_manager.picker)
	_trace_startup("pack_manager.ready")
	bridge = load("res://engine_bridge.gd").new()
	add_child(bridge)
	bridge.model_changed.connect(_receive_model)
	bridge.command_failed.connect(_failed)
	_trace_startup("bridge.created")
	navigation_controller = load("res://ui/navigation_controller.gd").new()
	add_child(navigation_controller)
	navigation_controller.setup(self)
	user_preferences = load("res://ui/user_preferences.gd").new()
	user_preferences.changed.connect(_apply_user_preferences)
	decision_feedback = load("res://ui/decision_feedback.gd").new()
	decision_feedback.setup(self)
	_trace_startup("guide.setup.begin")
	if OS.get_environment("CD_GODOT_GUIDE_MODULE_TEST") != "1":
		coach = load("res://ui/immersive08/coach_canvas.gd").new()
		add_child(coach)
		coach.reserved_height_changed.connect(_reserve_coach_space)
		coach.setup(self, false)
	_trace_startup("guide.setup.end")
	soundscape = preload("res://audio/soundscape.gd").new()
	add_child(soundscape)
	soundscape.error_changed.connect(_sound_error)
	soundscape_ready = soundscape.setup(self)
	if is_instance_valid(coach) and is_instance_valid(coach.speech):
		coach.speech.speaking_changed.connect(soundscape.set_voice_active)
		soundscape.set_voice_active(coach.speech.speaking)
	resized.connect(func(): call_deferred("_layout_coach"))
	if qa_script.is_empty() and DisplayServer.get_name() != "headless":
		get_window().size_changed.connect(_keep_filled_display, CONNECT_DEFERRED)
		get_window().focus_entered.connect(_keep_filled_display, CONNECT_DEFERRED)
		_keep_filled_display.call_deferred()
	contextual_director = load("res://ui/contextual/director.gd").new()
	contextual_director.name = "ContextualDirector"
	add_child(contextual_director)
	contextual_director.setup(self)
	command_wait_overlay = CommandWaitOverlay.new()
	command_wait_overlay.name = "CommandWaitOverlay"
	add_child(command_wait_overlay)
	waiting = true
	_trace_startup("render.begin")
	_render()
	_trace_startup("render.end")
	_trace_startup("bridge.start.begin")
	bridge.start(_profile_path())
	_trace_startup("bridge.start.end")
	timer.start()
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(request_quit)
	if not qa_script.is_empty():
		var qa: Node = load(qa_script).new()
		qa.app = self
		add_child(qa)

func _profile_path() -> String:
	var explicit := OS.get_environment("CD_GODOT_DATA_DIR")
	return explicit if not explicit.is_empty() else OS.get_user_data_dir()

func _has_career() -> bool:
	return model.get("club") is Dictionary

func _live() -> Dictionary:
	return model.live if model.get("live") is Dictionary else {}

func _receive_model(value: Dictionary) -> void:
	var receive_us := Time.get_ticks_usec()
	# Une lecture moteur sans changement d'état (fiche club) ne périme pas les lecteurs suspendus.
	if is_instance_valid(navigation_controller) and not (bridge.last_response_ok and last_command in READ_ONLY_COMMANDS): navigation_controller.invalidate_readers()
	if _startup_trace and not _startup_model_seen:
		_startup_model_seen = true
		_trace_startup("model.first")
	# A queued action can replace last_command below; keep this response's identity.
	var received_command := last_command
	var response_ok: bool = bridge.last_response_ok
	var reception_id := ""
	if response_ok and (received_command in ["advance_day", "preseason_advance", "finish_round", "next_season", "national_play_match"] or SeasonPreparation.is_advance(received_command)):
		reception_id = Immersive.Reception.new_priority(model, value)
	# Keep one uninterrupted wait when the player's action follows an automatic tick
	# or a light decision: the queued command keeps the same panel.
	if not response_ok or queued_action.is_empty() or not (received_command == "tick" or shows_wait_panel(str(queued_action.get("command", "")))):
		command_wait_overlay.dismiss()
	SquadViews.U.remember(self)
	model = value
	if model.get("meta", {}).has("seasonStartYear"): SeasonLabel.start_year = int(model.meta.seasonStartYear)
	if decision_feedback != null: decision_feedback.complete(received_command, response_ok, model)
	if not preferences_loaded and not str(model.get("meta", {}).get("dataDir", "")).is_empty():
		preferences_loaded = true
		user_preferences.load_profile(str(model.meta.dataDir))
		if soundscape_ready: sound_profile_loaded = soundscape.load_profile(str(model.meta.dataDir))
		_apply_user_preferences()
	SquadViews.U.sync(self, bridge.last_response_ok and last_command in ["new_career","import","recover_profile","restore_checkpoint"])
	if bridge.last_response_ok and last_command in ["new_career","import","recover_profile","restore_checkpoint"]:
		if is_instance_valid(navigation_controller): navigation_controller.reset()
		for key in ["press_draft_context", "press_draft_choices", "press_mail_origin"]:
			if has_meta(key): remove_meta(key)
	if model.get("meta", {}).get("catalogue") is Array:
		catalogue = model.meta.catalogue.duplicate(true)
	waiting = false
	if SeasonPreparation.is_advance(received_command): SeasonPreparation.show_pending(self, false)
	connection_error = false
	if _has_career():
		accent = Color("106d43") if Immersive.Selections.nation_only(model) else Color(G.identity(model.club).get("color", "#d43e47"))
	if not export_path.is_empty() and not _write_export():
		if is_instance_valid(soundscape): soundscape.observe_model(model,route,received_command,_match_visible(),response_ok)
		return
	if bridge.last_response_ok and received_command not in ["epcr_preview", "competition_editor_preview"]: last_error = ""
	if response_ok:
		if not pending_route.is_empty(): route = pending_route
		pending_route = ""
		if _has_career() and (received_command in ["new_career", "next_season", "finish_round", "restore_checkpoint"] or not reception_id.is_empty()):
			_reset_reception(reception_id)
			if has_meta("press_mail_origin"): remove_meta("press_mail_origin")
			route = "Réception"
	if bridge.last_response_ok and last_command in ["new_career","next_season","import","restore_checkpoint"] and _has_career():
		table_division = str(model.meta.get("leagueId", "elite"))
	if response_ok and received_command == "match_talk_continue" and _live().is_empty():
		route = "Réception"
	var contextual_handled: bool = is_instance_valid(contextual_director) and contextual_director.sync(received_command, response_ok)
	if contextual_handled:
		pass
	elif last_command == "tick" and route not in ["Accueil", "Création"]:
		_update_live_bar()
		if route == "Bureau": Immersive.Office.update_live_card(self)
		if is_instance_valid(match_screen): match_screen.update_frame(model)
	else:
		if route == "Match" and is_instance_valid(match_screen):
			_update_live_bar()
			_update_header_date()
			match_screen.update_frame(model)
		else: _render(false)
	if bridge.last_response_ok:
		if is_instance_valid(status):
			status.text = _settled_status_text()
			status.add_theme_color_override("font_color",Color("f1b6a9") if _status_has_error() else G.MUTED)
		if is_instance_valid(root_content) and decision_feedback != null:
			var feedback_button: Button = root_content.find_child("DecisionFeedbackButton", true, false)
			if feedback_button != null: feedback_button.disabled = decision_feedback.receipts().is_empty()
		if last_command in ["recruit","extend_contract"] and model.get("meta",{}).get("negotiation") is Dictionary:
			var offer: Dictionary = model.meta.negotiation
			notice("La réponse du joueur", str(offer.get("message","La négociation est enregistrée.")))
		if last_command=="promote_cover" and model.meta.get("coverage") is Dictionary:
			notice("Renforts signés",str(model.meta.coverage.get("message","La feuille a été complétée.")))
		if last_command=="recover_profile" and not str(model.meta.get("recoveryBackup","")).is_empty():
			notice("Le profil d'origine est conservé","Copie de sécurité :\n"+str(model.meta.recoveryBackup)+"\n\nVous pouvez maintenant créer ou importer une carrière.")
	call_deferred("_refresh_coach")
	if is_instance_valid(soundscape): soundscape.observe_model(model,route,received_command,_match_visible(),response_ok)
	_record_timing(received_command, receive_us)
	if not queued_action.is_empty() and bridge.last_response_ok:
		var next := queued_action.duplicate(true)
		queued_action.clear()
		_command(next.command, next.payload, next.get("target_route", ""))

func _record_timing(command: String, receive_us: int) -> void:
	if not _timing_trace: return
	var now := Time.get_ticks_usec()
	var bridge_timing: Dictionary = bridge.last_timing
	var entry := {"command": command, "rendu_ms": (now - receive_us) / 1000.0, "moteur_ms": bridge_timing.get("moteur_ms", 0.0), "analyse_ms": bridge_timing.get("analyse_ms", 0.0), "file_ms": bridge_timing.get("file_ms", 0.0), "octets": bridge_timing.get("octets", 0), "total_ms": (now - _command_sent_us) / 1000.0 if _command_sent_us > 0 else 0.0, "route": route}
	_command_sent_us = 0
	timing_log.append(entry)
	print("CD_TIMING ", JSON.stringify(entry))

## Commandes légères : jamais de panneau, l’interface reste disponible et une
## décision supplémentaire attend son tour au lieu d’être refusée.
static func shows_wait_panel(command: String) -> bool:
	return COMMAND_WAIT_MESSAGES.has(command) or SeasonPreparation.is_advance(command)

func _command(command: String, payload: Dictionary = {}, target_route: String = "") -> bool:
	if closing: return false
	if waiting:
		if command == "tick": return false
		# Après un tick ou une décision légère, la décision suivante attend son tour.
		# La même décision répétée n’attend pas : sa charge utile a été lue sur le
		# modèle d’avant la réponse en cours et écraserait celle-ci (ex. set_tactics).
		if (last_command == "tick" or (not shows_wait_panel(last_command) and command != last_command)) and last_command != "snapshot" and queued_action.is_empty():
			queued_action = {"command":command,"payload":payload.duplicate(true),"target_route":target_route}
			_present_command_wait(command)
			return true
		if last_command == "snapshot": return false
		var active_command := str(queued_action.get("command", last_command))
		if not command_wait_overlay.visible or command != active_command:
			_refuse_action("Une décision est déjà en cours. Cette nouvelle action n'a pas été retenue ; réessayez après sa réponse.")
		return false
	# La fiche d'un club est une lecture moteur sans changement d'état : les lecteurs suspendus
	# (rencontre ouverte avant la fiche, etc.) restent valides et le retour arrière les restitue.
	if is_instance_valid(navigation_controller) and command not in READ_ONLY_COMMANDS: navigation_controller.invalidate_readers()
	waiting = true
	last_command = command
	if _timing_trace: _command_sent_us = Time.get_ticks_usec()
	pending_route = target_route
	if SeasonPreparation.is_advance(command): SeasonPreparation.show_pending(self, true)
	if decision_feedback != null: decision_feedback.begin(command, payload, model)
	_present_command_wait(command)
	bridge.send(command, payload)
	return waiting

func _present_command_wait(command: String) -> void:
	var message: String = COMMAND_WAIT_MESSAGES.get(command, "")
	if message.is_empty() and SeasonPreparation.is_advance(command): message = "Avance de la préparation…"
	if not message.is_empty():
		command_wait_overlay.set_context(_command_wait_context(command))
		command_wait_overlay.present(message, not user_preferences.data.reduced_motion, COMMAND_WAIT_REVEAL_SECONDS)

## Contexte du panneau d’attente : date du jour, club et faits réels du modèle.
func _command_wait_context(command: String) -> Dictionary:
	var meta: Dictionary = model.get("meta", {}) if model.get("meta") is Dictionary else {}
	var club: Dictionary = model.get("club", {}) if model.get("club") is Dictionary else {}
	var tips: Array = []
	for tip: String in GABI_TIPS: tips.append({"kind":"tip", "title":"Le conseil de Gabi", "text":tip})
	var facts: Array = []
	if not club.is_empty():
		var rank := int(club.get("rank", 0))
		var points := int(club.get("points", 0))
		if rank > 0 and not str(meta.get("roundLabel", "")).is_empty():
			facts.append("%s pointe à la %s place avec %d point%s · %s." % [str(club.get("name", "")), ("1re" if rank == 1 else str(rank) + "e"), points, "" if points <= 1 else "s", str(meta.roundLabel)])
		var next: Variant = model.get("next")
		if next is Dictionary and next.get("home") is Dictionary and next.get("away") is Dictionary:
			facts.append("Prochaine rencontre : %s – %s." % [str(next.home.get("name", "")), str(next.away.get("name", ""))])
		if meta.get("morale") is float or meta.get("morale") is int:
			facts.append("Moral du groupe : %d / 100." % int(meta.morale))
		if not str(club.get("goal", "")).is_empty():
			facts.append("Objectif fixé par la direction : %s." % str(club.goal).to_lower())
	# Les faits du club alternent avec les conseils de Gabi.
	var notes: Array = []
	for index in maxi(tips.size(), facts.size()):
		if index < facts.size(): notes.append({"kind":"fact", "title":"Au club", "text":facts[index]})
		if index < tips.size(): notes.append(tips[index])
	return {
		"kicker": COMMAND_WAIT_KICKERS.get(command, "En coulisses"),
		"date": str(meta.get("calendarToday", "")),
		"flip": command == "advance_day",
		"accent": accent if _has_career() else Color("d43e47"),
		"club": str(club.get("abbr", "")),
		"notes": notes,
		"note_seed": Time.get_ticks_msec() / 4600
	}

func _refuse_action(message: String) -> void:
	# A local refusal must not complete or discard the actual in-flight action.
	if is_instance_valid(soundscape): soundscape.notify_error()
	last_error = message
	if is_instance_valid(status):
		status.text = "ACTION NON EFFECTUÉE · " + message
		status.add_theme_color_override("font_color", Color("f1b6a9"))
	if not (is_instance_valid(contextual_director) and contextual_director.active()):
		notice("Votre décision n'a pas été appliquée", message)

func _failed(message: String) -> void:
	command_wait_overlay.dismiss()
	if is_instance_valid(soundscape): soundscape.notify_error()
	if decision_feedback != null: decision_feedback.complete(last_command, false, model)
	waiting = false
	if SeasonPreparation.is_advance(last_command): SeasonPreparation.show_pending(self, false)
	queued_action.clear()
	pending_route = ""
	connection_error = bridge.child_pid <= 0 or bridge._stopping
	var epcr_dialog := get_node_or_null("EpcrPreparationDialog") if last_command == "epcr_preview" else null
	var editor_dialog := get_node_or_null("CompetitionEditorDialog") if last_command == "competition_editor_preview" else null
	var market_dialog := get_node_or_null("InterclubMarket") if last_command in ["interclub_negotiate", "interclub_auction"] else null
	# A consultation refusal belongs to its report, never to the career decision
	# status. Preserve an existing business error and the unsaved list.
	if last_command in ["epcr_preview", "competition_editor_preview"] and not connection_error:
		if is_instance_valid(status):
			status.text = _settled_status_text()
			status.add_theme_color_override("font_color",Color("f1b6a9") if _status_has_error() else G.MUTED)
		return
	last_error = message
	if is_instance_valid(status):
		status.text = "ACTION NON EFFECTUÉE · " + message
		status.add_theme_color_override("font_color", Color("f1b6a9"))
	if last_command == "tick": timer.stop()
	# The immersive scene owns its visible error panel; a second modal would
	# survive a successful retry and obscure the resumed match.
	if is_instance_valid(contextual_director) and contextual_director.active() and not connection_error: return
	# Transport failures remain globally visible, but keep this local draft too.
	if epcr_dialog != null or editor_dialog != null or market_dialog != null: return
	# A failed annotation must leave its editor and unsaved draft alive. The
	# notebook listens to the same failure signal and presents the local refusal.
	if last_command in ["coach_note_save","coach_note_remove"] and get_node_or_null("CoachNotebook") != null: return
	_clear_dialogs()
	var d := AcceptDialog.new()
	_prepare_dialog(d, 590)
	d.title = "Votre décision n'a pas été appliquée"
	d.dialog_text = message
	add_child(d)
	d.popup_centered(Vector2i(590, 180))
	d.confirmed.connect(d.queue_free)
	if route == "Accueil" or not _has_career(): _render()

func _reset_reception(selected: String = "") -> void:
	var inbox: Dictionary = Immersive.Reception._state(self)
	inbox.merge({"folder":0, "category":"Tous", "selected":selected, "oldest_first":false, "scroll":0, "press_opened":"", "activity_filter":"all", "expanded_threads":{}, "return_focus":false}, true)

func _show_press_inbox() -> void:
	_reset_reception()
	_navigate("Réception", false)

func _open_press_invitation(id: String) -> void:
	var inbox: Dictionary = management_ui.get("reception", {})
	if route != "Réception" or waiting or inbox.get("press_opened") != id: return
	var press: Dictionary = model.get("clubLife", {}).get("press", {})
	var conference: Dictionary = press.get("conference", {})
	var outcome: Variant = press.get("lastOutcome")
	var active: bool = conference.get("available", false) and conference.get("invitationId") == id
	if not active and not (outcome is Dictionary and outcome.get("invitationId") == id): return
	set_meta("press_mail_origin", id)
	management_ui.press_tab = 1
	_navigate("Presse", false)

func _navigate(target: String, remember_ui: bool = true, keep_subview: bool = false) -> void:
	if is_instance_valid(contextual_director) and contextual_director.active_meeting():
		contextual_director.render_if_needed()
		return
	if is_instance_valid(contextual_director) and contextual_director.match_immersed() and target != "Match":
		contextual_director.render_if_needed()
		return
	if target == "Presse" and not has_meta("press_mail_origin"): return
	if target == "Sélections" and not model.get("international") is Dictionary: return
	if not Immersive.Selections.navigation_allowed(model, target): return
	if is_instance_valid(navigation_controller): navigation_controller.capture_current()
	if target != "Presse" and has_meta("press_mail_origin"): remove_meta("press_mail_origin")
	if not keep_subview:
		if target == "Effectif": set_meta("immersive08_full_player",false)
		if target == "Préparation" and management_ui.get("preparation", {}).get("tab", 0) == 2:
			management_ui.preparation.tab = 0
	route = target
	for chapter: Dictionary in NAV_CHAPTERS:
		if target in chapter.routes: chapter_routes[chapter.label] = target
	_render(remember_ui)
	if is_instance_valid(soundscape): soundscape.refresh_visibility(route,_match_visible())

func _match_visible() -> bool:
	return route == "Match" and is_instance_valid(match_screen) and match_screen.is_visible_in_tree()

func _sound_error(message: String) -> void:
	# Local audio availability never marks a career decision as failed.
	if is_instance_valid(status):
		status.text = _settled_status_text()
		status.add_theme_color_override("font_color",Color("f1b6a9") if _status_has_error() else G.MUTED)
	if not message.is_empty(): call_deferred("_show_sound_error",message)

func _show_sound_error(message: String) -> void:
	if not is_instance_valid(soundscape) or soundscape.last_error != message: return
	var options := get_node_or_null("PreferencesDialog")
	if options != null and not options.is_queued_for_deletion(): return # The options show their own reason.
	notice("Réglages sonores indisponibles",message)

func _build_subnavigation(parent: Container) -> void:
	for chapter: Dictionary in NAV_CHAPTERS:
		if route not in chapter.routes or chapter.routes.size() < 2: continue
		var band:=PanelContainer.new()
		band.name="ChapterNavigationBand"
		var band_style:=G.T.box(Color("1c262b"),3,Color("354249"))
		band_style.content_margin_left=4;band_style.content_margin_right=4
		band_style.content_margin_top=3;band_style.content_margin_bottom=3
		band.add_theme_stylebox_override("panel",band_style)
		parent.add_child(band)
		var row := G.h(7)
		row.name = "ChapterSubnavigation"
		band.add_child(row)
		for target: String in chapter.routes:
			var button := G.nav_button(target.to_upper(), func(): _navigate(target), accent, route == target)
			button.name = "Section_" + target
			button.custom_minimum_size.y = 28
			button.add_theme_font_size_override("font_size", 12)
			G.fill(button)
			row.add_child(button)
		return

func _render(remember_ui: bool = true) -> void:
	if route == "Presse" and not has_meta("press_mail_origin"): route = "Réception"
	if not Immersive.Selections.navigation_allowed(model, route): route = "Réception"
	call_deferred("_refresh_coach")
	call_deferred("_observe_navigation")
	for chapter: Dictionary in NAV_CHAPTERS:
		if route in chapter.routes: chapter_routes[chapter.label] = route
	if remember_ui: SquadViews.U.remember(self)
	SquadViews.U.sync(self)
	if is_instance_valid(contextual_director) and contextual_director.render_if_needed(): return
	if Immersive.render(self):
		if is_instance_valid(contextual_director): contextual_director.call_deferred("install_entrypoints")
		return
	if is_instance_valid(root_content):
		remove_child(root_content)
		root_content.queue_free()
	match_screen = null
	match_view = null
	match_page = null
	workspace_inset = null
	body_scroll = null
	entry_scroll = null
	root_content = Control.new()
	root_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_content)
	move_child(root_content, 0)
	var bg := ColorRect.new()
	bg.color = G.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_content.add_child(bg)
	if route == "Accueil":
		_entry_workspace(ImmersiveEntry.home(self))
		return
	if route == "Création":
		_entry_workspace(ImmersiveEntry.workspace(self,Entry.creation(self),true))
		return
	if route == "Packs":
		_entry_workspace(ImmersiveEntry.workspace(self,PackViews.page(self),false))
		return
	if not _has_career():
		route = "Accueil"
		_render()
		return
	var shell := G.h(0)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_content.add_child(shell)
	_build_sidebar(shell)
	var inset := G.margin(8)
	workspace_inset = inset
	# Container sorting can happen after the deferred coach refresh. Reposition
	# on its actual geometry, including the sidebar width, after every rebuild.
	inset.item_rect_changed.connect(_layout_coach)
	G.fill(inset, true)
	shell.add_child(inset)
	var content := G.v(6 if size.y <= 760 else 8)
	content.name = "CareerContent"
	inset.add_child(content)
	var header:=PanelContainer.new()
	header.name="CareerHeader"
	var header_style:=G.T.box(Color("202a2e"),3,Color("3b494e"))
	header_style.set_border_width_all(0)
	header_style.border_width_top=3
	header_style.border_color=accent
	header_style.content_margin_left=10;header_style.content_margin_right=10
	header_style.content_margin_top=5;header_style.content_margin_bottom=5
	header.add_theme_stylebox_override("panel",header_style)
	content.add_child(header)
	var top := G.h(8)
	header.add_child(top)
	var chapter_label:="Bureau"
	var chapter_number:=1
	for i in NAV_CHAPTERS.size():
		if route in NAV_CHAPTERS[i].routes:
			chapter_label=NAV_CHAPTERS[i].label
			chapter_number=i+1
	var chapter_mark:=G.v(0)
	chapter_mark.custom_minimum_size.x=30
	top.add_child(chapter_mark)
	chapter_mark.add_child(G.label("%02d"%chapter_number,27,G.INK,true))
	chapter_mark.add_child(G.Art.glyph(chapter_label,G.MUTED,16))
	var titles := G.v(0)
	G.fill(titles)
	top.add_child(titles)
	var overline:=G.h(8)
	titles.add_child(overline)
	overline.add_child(G.label(chapter_label.to_upper(),11,G.INK))
	header_date = G.label("", 11, G.MUTED)
	overline.add_child(header_date)
	_update_header_date()
	heading = G.label({"Bureau":"Le club, cette semaine.","Effectif":"Les hommes du projet.","Composition":"Votre feuille à 23.","Préparation":"Préparer la rencontre.","Calendrier":"Le fil de la saison.","Classements":"La course aux sommets.","Recrutement":"Construire l’effectif.","Finances":"Les moyens du projet.","Club":"Un club. Un territoire.","Match":"Le jour de match."}.get(route, route.to_upper()), 35, G.INK, true)
	heading.add_theme_font_override("font", G.T.BODY)
	heading.add_theme_font_size_override("font_size", 20)
	titles.add_child(heading)
	var save_action:=G.button("SAUVEGARDER", func(): _command("save"))
	save_action.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	top.add_child(save_action)
	primary_button = G.button(primary_text(), primary_action, true)
	primary_button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	top.add_child(primary_button)
	minibar = G.label("", 12, G.GOLD)
	content.add_child(minibar)
	PackViews.missing_warning(self, content, "career")
	_build_subnavigation(content)
	body = G.v(6)
	G.fill(body, true)
	body_scroll = ScrollContainer.new()
	body_scroll.name = "CareerWorkspace"
	body_scroll.follow_focus = true
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	G.fill(body_scroll, true)
	content.add_child(body_scroll)
	body_scroll.add_child(body)
	var footer := G.h(8)
	content.add_child(footer)
	status = G.label(_settled_status_text(), 11, Color("f1b6a9") if _status_has_error() else G.MUTED)
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	G.fill(status)
	footer.add_child(status)
	if decision_feedback != null: footer.add_child(decision_feedback.control())
	var coach_dock := Control.new()
	coach_dock.name = "CoachCompactDock"
	coach_dock.custom_minimum_size = Vector2(330,34)
	coach_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coach_dock.visible = is_instance_valid(coach)
	footer.add_child(coach_dock)
	match route:
		"Bureau": body.add_child(ClubViews.office(self))
		"Club": body.add_child(ClubViews.club(self))
		"Calendrier": body.add_child(ClubViews.calendar(self))
		"Classements": body.add_child(ClubViews.tables(self))
		"Finances": body.add_child(ClubViews.finance(self))
		"Effectif": body.add_child(SquadViews.squad(self))
		"Composition": body.add_child(SquadViews.lineup(self))
		"Préparation": body.add_child(SquadViews.preparation(self))
		"Plan de jeu": body.add_child(PlaybookViews.build(self))
		"Recrutement": body.add_child(SquadViews.market(self))
		"Staff": body.add_child(StaffViews.build(self))
		"Formation": body.add_child(DevelopmentViews.build(self))
		"Presse": body.add_child(PressViews.build(self))
		"Vestiaire": body.add_child(RelationshipsViews.build(self))
		"Rivalités": body.add_child(WorldViews.build(self))
		"Stratégie": body.add_child(StrategyViews.build(self))
		"Centre": body.add_child(AcademyViews.build(self))
		"Suivi des jeunes": body.add_child(AcademyFollowUpViews.build(self))
		"Travail du club": body.add_child(SupportViews.build(self))
		"Carrière": body.add_child(ManagerCareerViews.build(self))
		"Match":
			match_screen = MatchUI.new()
			match_screen.app = self
			body.add_child(match_screen)
			match_page = match_screen
			match_screen.update_frame(model)
	_update_live_bar()

func _entry_workspace(page: Control) -> void:
	entry_scroll = ScrollContainer.new()
	entry_scroll.name = "EntryWorkspace"
	entry_scroll.follow_focus = true
	entry_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	entry_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_content.add_child(entry_scroll)
	page.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	page.custom_minimum_size.y = 720
	G.fill(page, true)
	entry_scroll.add_child(page)

func _reserve_coach_space(_height: float) -> void:
	coach_reserved_height = 0.0
	_layout_coach()

func _refresh_coach() -> void:
	if is_instance_valid(contextual_director) and contextual_director.active():
		if is_instance_valid(coach): coach.hide()
		return
	if is_instance_valid(coach):
		coach.refresh()
		coach.consider_context(route, model, last_command, bridge.last_response_ok)
	_layout_coach()

func _observe_navigation() -> void:
	if is_instance_valid(navigation_controller): navigation_controller.observe(route, selected_player, selected_staff_club)

func _settled_status_text() -> String:
	if not last_error.is_empty(): return "ACTION NON EFFECTUÉE · " + last_error
	if model.get("meta",{}).get("saveError",false): return "DERNIÈRE SAUVEGARDE IMPOSSIBLE · Vérifiez le stockage avant de poursuivre."
	if user_preferences != null and not user_preferences.last_error.is_empty(): return "RÉGLAGES LOCAUX · " + user_preferences.last_error
	if is_instance_valid(soundscape) and not soundscape.last_error.is_empty(): return "RÉGLAGES SONORES · " + soundscape.last_error
	if decision_feedback != null and not decision_feedback.status_text().is_empty(): return decision_feedback.status_text()
	return "Sauvegarde automatique · Profil de carrière indépendant"

func _status_has_error() -> bool:
	return not last_error.is_empty() or model.get("meta",{}).get("saveError",false) or (user_preferences != null and not user_preferences.last_error.is_empty()) or (is_instance_valid(soundscape) and not soundscape.last_error.is_empty())

func _apply_user_preferences() -> void:
	if user_preferences == null: return
	user_preferences.apply_audio()
	if is_instance_valid(coach) and is_instance_valid(coach.speech):
		coach.speech.set_global_volume(int(user_preferences.data.volume))
	if is_instance_valid(coach) and is_instance_valid(coach.portrait):
		coach.portrait.set_reduced_motion(bool(user_preferences.data.reduced_motion))
	if is_instance_valid(match_screen) and match_screen.has_method("apply_preferences"):
		match_screen.apply_preferences()

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
	if not is_instance_valid(root_content) or not is_instance_valid(coach): return
	root_content.offset_bottom = 0.0
	if is_instance_valid(workspace_inset):
		workspace_inset.add_theme_constant_override("margin_bottom", 8)

func _open_coach() -> void:
	if is_instance_valid(coach): coach.open_help()

func _update_header_date() -> void:
	if not is_instance_valid(header_date): return
	var meta: Dictionary = model.get("meta", {})
	var round_label := str(meta.get("roundLabel", "Journée " + G.n(int(meta.get("round", 0))+1)))
	var planning: Dictionary = model.get("calendarPlanning", {})
	var today: Variant = planning.get("today", meta.get("date", ""))
	var date: String = today if today is String else ""
	var parts := date.split("-")
	if parts.size()==3 and parts[1].is_valid_int() and int(parts[1]) in range(1,13):
		var months := ["JANV.","FÉVR.","MARS","AVR.","MAI","JUIN","JUIL.","AOÛT","SEPT.","OCT.","NOV.","DÉC."]
		header_date.text = "%s %s %s" % [parts[2],months[int(parts[1])-1],parts[0]]
		header_date.tooltip_text = round_label
	else:
		var short_round := round_label.get_slice(" · ",0) if round_label.begins_with("Semaine ") else round_label
		if round_label == "Saison terminée": short_round = "Terminée"
		header_date.text = ("SAISON %s  /  %s" % [G.season_label(meta.get("season", 1)),short_round]).to_upper()
		header_date.tooltip_text = round_label if short_round!=round_label else ""
	var calendar := header_date.get_parent() as Button
	if calendar != null:
		calendar.accessibility_description = header_date.text
		if not header_date.tooltip_text.is_empty():
			calendar.accessibility_description += " · " + header_date.tooltip_text
		calendar.tooltip_text = "Ouvrir le calendrier · " + calendar.accessibility_description

func _build_sidebar(parent: Node) -> void:
	var rail := PanelContainer.new()
	rail.name="CareerRail"
	rail.custom_minimum_size.x = 176
	var rail_style:=G.T.box(Color("10181c"),0,Color("3b494e"))
	rail_style.set_border_width_all(0)
	rail_style.border_width_right=1
	rail_style.content_margin_left=0;rail_style.content_margin_right=0
	rail_style.content_margin_top=0;rail_style.content_margin_bottom=0
	rail.add_theme_stylebox_override("panel",rail_style)
	parent.add_child(rail)
	var margin := G.margin(6)
	rail.add_child(margin)
	var left := G.v(4)
	margin.add_child(left)
	var logo := G.button("", pause_menu)
	logo.tooltip_text = "Rugby Legacy 27 — Menu et sauvegardes"
	var bitmap := TextureRect.new()
	bitmap.texture = load("res://branding/rugby-legacy-27-logo.png")
	bitmap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bitmap.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bitmap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bitmap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var composite := ShaderMaterial.new()
	composite.shader = load("res://branding/black_key.gdshader")
	bitmap.material = composite
	logo.add_child(bitmap)
	logo.add_theme_font_override("font", G.T.DISPLAY)
	logo.add_theme_font_size_override("font_size", 18)
	logo.custom_minimum_size.y = 48
	logo.add_theme_stylebox_override("normal",G.T.box(Color("1d2a30"),3,Color("445259")))
	left.add_child(logo)
	left.add_child(G.separator())
	var club_frame:=PanelContainer.new()
	club_frame.name="SidebarClubIdentity"
	var club_style:=G.T.box(Color("202a2e").lerp(Color(accent,1),.12),3,Color("445259"))
	club_style.set_border_width_all(0)
	club_style.border_width_top=3;club_style.border_color=accent
	club_style.content_margin_top=5;club_style.content_margin_bottom=6
	club_frame.add_theme_stylebox_override("panel",club_style)
	left.add_child(club_frame)
	var club_identity:=G.v(2)
	club_frame.add_child(club_identity)
	var club_marks:=G.h(6)
	club_identity.add_child(club_marks)
	club_marks.add_child(G.crest(model.club,40))
	var club_context:=G.v(0)
	G.fill(club_context)
	club_marks.add_child(club_context)
	club_context.add_child(G.label(G.club_abbr(model.club),23,G.INK,true))
	club_context.add_child(G.label("VOTRE CLUB",9,G.MUTED))
	var name := G.label(G.club_name(model.club), 16, G.INK, true)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.max_lines_visible=2
	name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	name.tooltip_text=G.club_name(model.club)
	club_identity.add_child(name)
	if is_instance_valid(navigation_controller): left.add_child(navigation_controller.controls())
	left.add_child(G.separator())
	var navigation := G.scroll(left)
	navigation.get_parent().name = "CareerNavigation"
	navigation.add_child(G.label("CARNET DE L'ENTRAÎNEUR", 10, G.MUTED))
	for chapter: Dictionary in NAV_CHAPTERS:
		var active: bool = route in chapter.routes
		var destination: String = str(route if active else chapter_routes.get(chapter.label, chapter.routes[0]))
		var b := G.nav_button(str(chapter.label).to_upper(), func(): _navigate(destination), accent, active,str(chapter.label))
		b.name = "Chapter_" + str(chapter.label)
		b.custom_minimum_size.y = 28
		navigation.add_child(b)
	left.add_child(G.label("PRÉALPHA %s  /  WINDOWS" % ProjectSettings.get_setting("application/config/version"), 9, G.GOLD))
	left.add_child(G.button("MENU & SAUVEGARDES", pause_menu))

func _update_live_bar() -> void:
	if not is_instance_valid(minibar): return
	var live := _live()
	var office_status := minibar.name == "ImmersiveOfficeMatchStatus"
	if office_status: minibar.visible = not live.is_empty()
	if not live.is_empty():
		var teams: Array = live.get("teams", [{},{}])
		var score: Array = live.get("score", [0,0])
		var score_line := "%s  %s — %s  %s" % [G.club_abbr(teams[0]),G.n(score[0]),G.n(score[1]),G.club_abbr(teams[1])]
		var minute := G.n(live.get("minute",0)) + " min"
		if office_status:
			var state := "MATCH TERMINÉ" if live.get("finished",false) else ("PAUSE" if live.get("paused",false) else "EN DIRECT")
			minibar.text = score_line + "\n" + minute + "  ·  " + state
			minibar.tooltip_text = minibar.text
		else:
			minibar.text = score_line + "   ·   " + minute + ("  /  PAUSE" if live.get("paused",false) else "")
	else:
		var meta: Dictionary = model.get("meta", {})
		var club_count := int(meta.get("database", {}).get("clubCount", 0))
		match meta.get("mode"):
			"world": minibar.text = "CARRIÈRE MONDIALE  /  %s CLUBS" % G.n(club_count)
			"france30", "common": minibar.text = "ÉLITE & ACCESSION  /  %s CLUBS" % G.n(club_count)
			_: minibar.text = "CARRIÈRE HISTORIQUE  /  14 CLUBS"
	if is_instance_valid(primary_button):
		var action := primary_text()
		primary_button.text = "Continuer" if primary_button.name == "ImmersiveContinue" else action
		primary_button.disabled = false
		if live.is_empty():
			if _press_required():
				if primary_button.name == "ImmersiveContinue": primary_button.text = "Conf. de presse"
			elif not Immersive.Selections.current_fixture(model).is_empty():
				if primary_button.name == "ImmersiveContinue": primary_button.text = "Courrier match"
			elif not model.meta.get("canAdvanceSeason", false):
				var daily := _daily_progression()
				if primary_button.name == "ImmersiveContinue": primary_button.text = daily.get("short", "Continuer")
				primary_button.disabled = bool(daily.get("disabled", false))
		if office_status and not live.is_empty():
			primary_button.text = "Valider le résultat" if live.get("finished",false) else "Retour au direct"
		primary_button.tooltip_text = action
	if waiting and SeasonPreparation.is_advance(last_command): SeasonPreparation.show_pending(self, true)

func _press_required() -> bool:
	return not Immersive.Selections.nation_only(model) and CareerProgression.press_required(model)

func _daily_progression() -> Dictionary:
	var fixture: Variant = null if Immersive.Selections.nation_only(model) else model.get("next")
	return CareerProgression.daily(model.get("meta", {}), fixture, route)

func primary_text() -> String:
	var live := _live()
	if not live.is_empty():
		if live.get("finished",false): return "VALIDER LE RÉSULTAT  →"
		if route == "Préparation" and live.get("paused",false): return "RETOUR AU MATCH  →"
		return "RETOUR AU DIRECT  →"
	if _press_required(): return "OUVRIR LA RÉCEPTION  →"
	if not Immersive.Selections.current_fixture(model).is_empty(): return "OUVRIR LE COURRIER DE MATCH  →"
	if model.get("meta",{}).get("canAdvanceSeason",false): return "SAISON SUIVANTE  →"
	var daily := _daily_progression()
	if not daily.is_empty(): return daily.label
	if not SeasonPreparation.data(model.get("meta",{})).is_empty(): return "AVANCER LA PRÉPARATION  →"
	if model.get("next") == null: return "AVANCER LA SEMAINE  →"
	return "ALLER AU JOUR DE MATCH  →" if route == "Préparation" else "PRÉPARER LE MATCH  →"

func primary_action() -> void:
	if waiting and (last_command != "tick" or not queued_action.is_empty()): return
	if not _live().is_empty():
		if _live().get("finished",false): _command("finish_round")
		else: _navigate("Match")
		return
	if _press_required():
		_show_press_inbox()
		return
	var international_fixture := Immersive.Selections.current_fixture(model)
	if not international_fixture.is_empty():
		_reset_reception("international:match-day/" + str(international_fixture.id))
		_navigate("Réception", false)
		return
	if model.meta.get("canAdvanceSeason",false):
		confirm("Une nouvelle saison", "Les contrats arrivés à échéance sont réglés et les mouvements de division sont appliqués. Commencer la saison suivante ?", func(): _command("next_season",{"confirmed":true}))
		return
	var daily := _daily_progression()
	if not daily.is_empty():
		if daily.has("route"): _navigate(daily.route)
		elif daily.has("command"): _command(daily.command, daily.payload)
		return
	if not SeasonPreparation.data(model.meta).is_empty(): _command(SeasonPreparation.command(model.meta),{"fromWeek":int(model.meta.get("week",0))})
	elif model.get("next") == null: _command("finish_round")
	else: _navigate("Match" if route == "Préparation" else "Préparation")

# Recettes Godot seulement (ancien mode France 30, moteur lancé avec CD_MODES_HERITES=1).
func create_career(id: int) -> void:
	var action := func(): _command("new_career",{"club":id,"mode":"common"})
	if _has_career(): confirm("Une nouvelle histoire", "La carrière actuelle sera conservée dans Copies de sécurité avant son remplacement. Si cette copie ne peut pas être écrite, le remplacement sera refusé. Prendre les rênes de %s ?" % catalogue[id].name, action)
	else: action.call()

func confirm_decision(command: String, payload: Dictionary, title: String, text: String, callback: Callable) -> void:
	var preview := preload("res://ui/decision_preview.gd")
	var detail: Dictionary = preview.describe(command,payload,model)
	if detail.is_empty(): confirm(title,text,callback)
	else: preview.open(self,title,text,detail,callback)

func confirm(title: String, text: String, callback: Callable, focus_cancel := false) -> void:
	_clear_dialogs()
	var d := ConfirmationDialog.new()
	_prepare_dialog(d, 650)
	d.title = title
	d.dialog_text = text
	d.get_ok_button().text = "CONFIRMER"
	d.get_cancel_button().text = "ANNULER"
	add_child(d)
	d.confirmed.connect(func(): callback.call(); d.queue_free())
	d.canceled.connect(d.queue_free)
	d.popup_centered(Vector2i(650,180))
	if focus_cancel: d.get_cancel_button().grab_focus()

func _prepare_dialog(dialog: AcceptDialog, width: int) -> void:
	# Configure wrapping before text/insertion can queue an oversized minimum.
	ImmersiveDialogs.prepare(dialog,width,accent)
	dialog.visibility_changed.connect(func():
		if not dialog.visible: call_deferred("_refresh_coach"))

func pause_menu() -> void:
	_clear_dialogs()
	if not _live().is_empty() and not _live().get("paused",false) and not _live().get("finished",false):
		if not _command("pause",{"paused":true}): return
	var d := AcceptDialog.new()
	d.name = "ImmersivePauseMenu"
	_prepare_dialog(d, 820)
	d.title = "Votre carrière"
	ImmersiveDialogs.pause_content(d,self)
	for pair in [["Accueil","home"],["Exporter","export"],["Importer","import"],["Copies de sécurité","profile_safety"],["Paramètres","settings"],["Quitter","quit"]]:
		var button := d.add_button(pair[0],false,pair[1])
		if pair[1] == "profile_safety": button.name = "ProfileSafetyOpen"
	d.custom_action.connect(func(action: String):
		d.hide(); d.queue_free()
		match action:
			"home": _navigate("Accueil")
			"export": open_file(false)
			"import": open_file(true)
			"profile_safety": open_profile_safety()
			"settings": settings()
			"quit": request_quit()
	)
	add_child(d)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	ImmersiveDialogs.show_centered(d,Vector2i(820,370))

func settings() -> void:
	preload("res://ui/preferences_dialog.gd").open(self, user_preferences)

func open_profile_safety() -> void:
	preload("res://ui/profile_safety_view.gd").open(self)

func open_file(importing: bool) -> void:
	import_mode = importing
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if importing else FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = "Importer une carrière · 8 à 24 Mio selon l’édition" if importing else "Exporter une carrière"
	file_dialog.current_file = "" if importing else "Rugby-Legacy-27.json"
	file_dialog.popup_centered_ratio(0.7)

func _file_selected(path: String) -> void:
	file_dialog.hide()
	if import_mode:
		var f := FileAccess.open(path,FileAccess.READ)
		if f == null: _refuse_action("Le fichier ne peut pas être lu : " + error_string(FileAccess.get_open_error())); return
		var byte_count := f.get_length()
		if byte_count > NativeEngineBridge.EXTENDED_IMPORT_LIMIT_BYTES:
			f.close()
			_refuse_action("Fichier trop volumineux (24 Mio UTF-8 maximum).")
			return
		var buffer := f.get_buffer(byte_count)
		f.close()
		# Le décodeur UTF-8 s'arrête au premier octet NUL.
		var has_nul := buffer.has(0)
		var text := "" if has_nul else buffer.get_string_from_utf8()
		var control_characters := RegEx.create_from_string("[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f]")
		if has_nul or control_characters.search(text) != null:
			_refuse_action("Le fichier JSON contient un caractère de contrôle non échappé.")
			return
		var refusal := NativeEngineBridge.import_preflight(text, byte_count)
		if not refusal.is_empty():
			_refuse_action(refusal)
			return
		confirm("Reprendre cette carrière", "Cette carrière sera vérifiée avant sa reprise. La carrière actuelle sera conservée dans Copies de sécurité avant son remplacement ; si cette copie ne peut pas être écrite, l'importation sera refusée.", func(): _command("import", {"text":text}, "Réception"), _has_career())
	else:
		if waiting: _refuse_action("Une décision est en cours. Réessayez après sa réponse."); return
		export_path = path
		_command("export")

func _write_export() -> bool:
	var destination := export_path
	export_path = ""
	var text := str(model.get("meta",{}).get("exportText",""))
	if text.is_empty(): _failed("Aucun export de carrière n’a été reçu."); return false
	var temporary := destination + ".tmp-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
	var f := FileAccess.open(temporary,FileAccess.WRITE)
	if f == null: _failed("L'export ne peut pas être écrit."); return false
	f.store_string(text)
	f.flush()
	var error := f.get_error()
	f.close()
	var replacement_error := error_string(error) if error != OK else preload("res://atomic_file.gd").replace_staged(temporary, destination)
	if not replacement_error.is_empty():
		DirAccess.remove_absolute(temporary)
		_failed("Écriture de l'export refusée : " + replacement_error)
		return false
	return true

func notice(title:String,text:String) -> void:
	_clear_dialogs()
	var d:=AcceptDialog.new()
	_prepare_dialog(d, 620)
	d.title=title
	d.dialog_text=text
	add_child(d)
	d.confirmed.connect(d.queue_free)
	d.popup_centered(Vector2i(620,190))

func _clear_dialogs() -> void:
	for child in get_children():
		if child is AcceptDialog and child!=file_dialog:
			if is_instance_valid(navigation_controller) and navigation_controller.is_suspended_reader(child): continue
			child.hide()
			child.queue_free()

func recover_profile() -> void:
	confirm("Conserver et récupérer le profil", "Une copie du profil endommagé sera conservée avant sa récupération. Vous pourrez ensuite créer ou importer une carrière.",func(): _command("recover_profile",{"confirmed":true}))

func reconnect() -> void:
	if waiting or bridge.child_pid > 0: return
	connection_error = false
	waiting = true
	last_command = "snapshot"
	bridge.start(_profile_path())

func _live_tick() -> void:
	if waiting or closing: return
	if _match_visible() and is_instance_valid(match_screen.stage) and match_screen.stage.is_presenting_extended_pass():
		return
	# Match en temps forts (mode de base ; repli CD_MATCH_TEMPS_FORTS=0) : la régie de la vue demande elle-même chaque minute.
	if is_instance_valid(match_screen) and match_screen.has_method("temps_forts_actifs") and match_screen.temps_forts_actifs(): return
	var live := _live()
	if not live.is_empty() and not live.get("paused",false) and not live.get("finished",false): _command("tick",{"steps":tick_steps})

func _update_match() -> void:
	if is_instance_valid(match_screen): match_screen.update_frame(model)

func _credits() -> void:
	_clear_dialogs()
	var d := AcceptDialog.new()
	_prepare_dialog(d, 760)
	d.title = "Rugby Legacy 27 · Crédits"
	d.dialog_text = "Photographies de territoires : auteurs, sources, licences et modifications dans Licences.\nModèle Quaternius : CC0. DM Sans et Barlow Condensed : SIL OFL.\nGodot : MIT. Node : notices incluses.\n\nBase commune de joueurs aux identités anonymisées. Capacités et finances de simulation, non officielles.\nLes images et noms des packs personnalisés restent séparés du jeu de base.\nCertains portraits sont des illustrations IA ; leur provenance figure dans les crédits et les métadonnées. L'enceinte3D est générique."
	add_child(d)
	d.popup_centered(Vector2i(760,260))
	d.confirmed.connect(d.queue_free)

func request_quit() -> void:
	if not _live().is_empty() and not _live().get("finished",false): confirm("Quitter le jeu", "La dernière décision confirmée est sauvegardée. Quitter cette rencontre ?",_close)
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
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(navigation_controller) and navigation_controller.handle_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _has_career(): pause_menu()
		else: _navigate("Accueil")
