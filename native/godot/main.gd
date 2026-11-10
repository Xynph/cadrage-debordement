extends Control

const G = preload("res://ui/game_skin.gd")
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
const SupportViews = preload("res://ui/support_view.gd")
const ManagerCareerViews = preload("res://ui/manager_career_view.gd")
const PlaybookViews = preload("res://ui/playbook_view.gd")
const NAV_CHAPTERS = [
	{"label":"Bureau", "routes":["Bureau","Réception"]},
	{"label":"Équipe", "routes":["Effectif","Composition","Préparation","Plan de jeu","Vestiaire","Match"]},
	{"label":"Développement", "routes":["Recrutement","Formation","Centre"]},
	{"label":"Club", "routes":["Club","Staff","Travail du club","Stratégie","Finances"]},
	{"label":"Compétitions", "routes":["Calendrier","Classements","Presse","Rivalités"]},
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
var preferences_loaded := false
var coach_reserved_height := 0.0
var workspace_inset: MarginContainer
var body_scroll: ScrollContainer
var entry_scroll: ScrollContainer
var interface_layout: Node
var _startup_trace := OS.get_environment("CD_GODOT_STARTUP_TRACE") == "1"
var _startup_model_seen := false

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
	file_dialog.filters = PackedStringArray(["*.json ; Carrière Oval Legacy 27"])
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
	if not (OS.has_feature("editor") and OS.get_environment("CD_GODOT_GUIDE_MODULE_TEST") == "1"):
		coach = load("res://ui/immersive08/coach_canvas.gd").new()
		add_child(coach)
		coach.reserved_height_changed.connect(_reserve_coach_space)
		coach.setup(self)
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
	if _startup_trace and not _startup_model_seen:
		_startup_model_seen = true
		_trace_startup("model.first")
	# A queued action can replace last_command below; keep this response's identity.
	var received_command := last_command
	var response_ok: bool = bridge.last_response_ok
	SquadViews.U.remember(self)
	model = value
	if decision_feedback != null: decision_feedback.complete(received_command, response_ok, model)
	if not preferences_loaded and not str(model.get("meta", {}).get("dataDir", "")).is_empty():
		preferences_loaded = true
		user_preferences.load_profile(str(model.meta.dataDir))
		if soundscape_ready: sound_profile_loaded = soundscape.load_profile(str(model.meta.dataDir))
		_apply_user_preferences()
	SquadViews.U.sync(self, bridge.last_response_ok and last_command in ["new_career","import","recover_profile"])
	if bridge.last_response_ok and last_command in ["new_career","import","recover_profile"]:
		if is_instance_valid(navigation_controller): navigation_controller.reset()
		for key in ["press_draft_context", "press_draft_choices"]:
			if has_meta(key): remove_meta(key)
	if model.get("meta", {}).get("catalogue") is Array:
		catalogue = model.meta.catalogue.duplicate(true)
	waiting = false
	if SeasonPreparation.is_advance(received_command): SeasonPreparation.show_pending(self, false)
	connection_error = false
	if _has_career(): accent = Color(G.identity(model.club).get("color", "#d43e47"))
	if not export_path.is_empty() and not _write_export():
		if is_instance_valid(soundscape): soundscape.observe_model(model,route,received_command,_match_visible(),response_ok)
		return
	if bridge.last_response_ok and received_command not in ["epcr_preview", "competition_editor_preview"]: last_error = ""
	if bridge.last_response_ok and not pending_route.is_empty():
		route = pending_route
		pending_route = ""
	if bridge.last_response_ok and last_command in ["new_career","next_season","import"] and _has_career():
		table_division = str(model.meta.get("leagueId", "elite"))
	if last_command == "tick" and route not in ["Accueil", "Création"]:
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
	if not queued_action.is_empty() and bridge.last_response_ok:
		var next := queued_action.duplicate(true)
		queued_action.clear()
		_command(next.command, next.payload, next.get("target_route", ""))

func _command(command: String, payload: Dictionary = {}, target_route: String = "") -> bool:
	if closing: return false
	if waiting:
		if command == "tick": return false
		if last_command == "tick" and queued_action.is_empty():
			queued_action = {"command":command,"payload":payload.duplicate(true),"target_route":target_route}
			if is_instance_valid(status): status.text = "Décision en attente de la réponse du moteur…"
			return true
		_refuse_action("Une décision est déjà en cours. Cette nouvelle action n'a pas été retenue ; réessayez après sa réponse.")
		return false
	waiting = true
	last_command = command
	pending_route = target_route
	if is_instance_valid(status): status.text = "Traitement de votre décision…"
	if SeasonPreparation.is_advance(command): SeasonPreparation.show_pending(self, true)
	if decision_feedback != null: decision_feedback.begin(command, payload, model)
	bridge.send(command, payload)
	return waiting

func _refuse_action(message: String) -> void:
	# A local refusal must not complete or discard the actual in-flight action.
	if is_instance_valid(soundscape): soundscape.notify_error()
	last_error = message
	if is_instance_valid(status):
		status.text = "ACTION NON EFFECTUÉE · " + message
		status.add_theme_color_override("font_color", Color("f1b6a9"))
	notice("Votre décision n'a pas été appliquée", message)

func _failed(message: String) -> void:
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

func _navigate(target: String, remember_ui: bool = true, keep_subview: bool = false) -> void:
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
	call_deferred("_refresh_coach")
	call_deferred("_observe_navigation")
	for chapter: Dictionary in NAV_CHAPTERS:
		if route in chapter.routes: chapter_routes[chapter.label] = route
	if remember_ui: SquadViews.U.remember(self)
	SquadViews.U.sync(self)
	if Immersive.render(self): return
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
	coach_dock.custom_minimum_size = Vector2(144,34)
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
	var date := str(meta.get("date",""))
	var planning: Variant = model.get("calendarPlanning")
	if meta.get("mode") == "world" and planning is Dictionary:
		# The world calendar already selects the match day while a fixture is live.
		var today: Variant = planning.get("today")
		if today is String and not today.is_empty(): date = today
	var parts := date.split("-")
	if parts.size()==3 and parts[1].is_valid_int() and int(parts[1]) in range(1,13):
		var months := ["JANV.","FÉVR.","MARS","AVR.","MAI","JUIN","JUIL.","AOÛT","SEPT.","OCT.","NOV.","DÉC."]
		header_date.text = "%s %s %s" % [parts[2],months[int(parts[1])-1],parts[0]]
		header_date.tooltip_text = round_label
	else:
		var short_round := round_label.get_slice(" · ",0) if round_label.begins_with("Semaine ") else round_label
		if round_label == "Saison terminée": short_round = "Terminée"
		header_date.text = ("SAISON %s  /  %s" % [G.n(meta.get("season", 1)),short_round]).to_upper()
		header_date.tooltip_text = round_label if short_round!=round_label else ""

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
	logo.tooltip_text = "Oval Legacy 27 — Menu et sauvegardes"
	var bitmap := TextureRect.new()
	bitmap.texture = load("res://branding/oval-legacy-27-logo.png")
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
		if office_status and not live.is_empty():
			primary_button.text = "Valider le résultat" if live.get("finished",false) else "Retour au direct"
		primary_button.tooltip_text = action
	if waiting and SeasonPreparation.is_advance(last_command): SeasonPreparation.show_pending(self, true)

func primary_text() -> String:
	var live := _live()
	if not live.is_empty():
		if live.get("finished",false): return "VALIDER LE RÉSULTAT  →"
		if route == "Préparation" and live.get("paused",false): return "RETOUR AU MATCH  →"
		return "RETOUR AU DIRECT  →"
	if model.get("meta",{}).get("canAdvanceSeason",false): return "SAISON SUIVANTE  →"
	if not SeasonPreparation.data(model.get("meta",{})).is_empty(): return "AVANCER LA PRÉPARATION  →"
	if model.get("next") == null: return "AVANCER LA SEMAINE  →"
	return "ALLER AU JOUR DE MATCH  →" if route == "Préparation" else "PRÉPARER LE MATCH  →"

func primary_action() -> void:
	if waiting and (last_command != "tick" or not queued_action.is_empty()): return
	if not _live().is_empty():
		if _live().get("finished",false): _command("finish_round")
		else: _navigate("Match")
	elif model.meta.get("canAdvanceSeason",false): confirm("Une nouvelle saison", "Les contrats arrivés à échéance sont réglés et les mouvements de division sont appliqués. Commencer la saison suivante ?", func(): _command("next_season",{"confirmed":true}))
	elif not SeasonPreparation.data(model.meta).is_empty(): _command(SeasonPreparation.command(model.meta),{"fromWeek":int(model.meta.get("week",0))})
	elif model.get("next") == null: _command("finish_round")
	else: _navigate("Match" if route == "Préparation" else "Préparation")

func create_career(id: int) -> void:
	var action := func(): _command("new_career",{"club":id,"mode":"common"},"Bureau")
	if _has_career(): confirm("Une nouvelle histoire", "La carrière actuelle sera remplacée dans ce profil. Exportez-la depuis le menu pour la conserver séparément. Prendre les rênes de %s ?" % catalogue[id].name, action)
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
	for pair in [["Accueil","home"],["Exporter","export"],["Importer","import"],["Paramètres","settings"],["Quitter","quit"]]: d.add_button(pair[0],false,pair[1])
	d.custom_action.connect(func(action: String):
		d.hide(); d.queue_free()
		match action:
			"home": _navigate("Accueil")
			"export": open_file(false)
			"import": open_file(true)
			"settings": settings()
			"quit": request_quit()
	)
	add_child(d)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	ImmersiveDialogs.show_centered(d,Vector2i(820,370))

func settings() -> void:
	preload("res://ui/preferences_dialog.gd").open(self, user_preferences)

func open_file(importing: bool) -> void:
	import_mode = importing
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if importing else FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = "Importer une carrière · 8 à 24 Mio selon l’édition" if importing else "Exporter une carrière"
	file_dialog.current_file = "" if importing else "Oval-Legacy-27.json"
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
		confirm("Reprendre cette carrière", "La carrière importée remplacera celle du profil. Le moteur la vérifiera avant de l'appliquer.",func(): _command("import",{"text":text},"Bureau"))
	else:
		if waiting: _refuse_action("Une décision est en cours. Réessayez après sa réponse."); return
		export_path = path
		_command("export")

func _write_export() -> bool:
	var destination := export_path
	export_path = ""
	var text := str(model.get("meta",{}).get("exportText",""))
	if text.is_empty(): _failed("Le moteur n'a pas fourni d'export."); return false
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
			child.hide()
			child.queue_free()

func recover_profile() -> void:
	confirm("Conserver et récupérer le profil", "Une copie du profil endommagé sera conservée avant sa récupération. Vous pourrez ensuite créer ou importer une carrière.",func(): _command("recover_profile",{"confirmed":true}))

func reconnect() -> void:
	if bridge.child_pid > 0: return
	connection_error = false
	bridge.start(_profile_path())

func _live_tick() -> void:
	if waiting or closing: return
	if _match_visible() and is_instance_valid(match_screen.stage) and match_screen.stage.is_presenting_extended_pass():
		return
	var live := _live()
	if not live.is_empty() and not live.get("paused",false) and not live.get("finished",false): _command("tick",{"steps":tick_steps})

func _update_match() -> void:
	if is_instance_valid(match_screen): match_screen.update_frame(model)

func _credits() -> void:
	_clear_dialogs()
	var d := AcceptDialog.new()
	_prepare_dialog(d, 760)
	d.title = "Oval Legacy 27 · Crédits"
	d.dialog_text = "Photographies de territoires : auteurs, sources, licences et modifications dans Licences.\nModèle Quaternius : CC0. DM Sans et Barlow Condensed : SIL OFL.\nGodot : MIT. Node : notices incluses.\n\nBase commune de joueurs aux identités anonymisées. Capacités et finances de simulation, non officielles.\nLes images et noms des packs personnalisés restent séparés du jeu de base.\nLes portraits IA sont signalés ; l'enceinte3D est générique."
	add_child(d)
	d.popup_centered(Vector2i(760,260))
	d.confirmed.connect(d.queue_free)

func request_quit() -> void:
	if not _live().is_empty() and not _live().get("finished",false): confirm("Quitter le jeu", "La dernière décision confirmée est sauvegardée. Quitter cette rencontre ?",_close)
	else: _close()

func _close(exit_code: int = 0) -> void:
	if closing: return
	closing = true
	if is_instance_valid(soundscape): soundscape.dispose()
	if is_instance_valid(coach): coach.destroy()
	timer.stop()
	bridge.stop()
	var deadline := Time.get_ticks_msec()+2300
	while bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	get_tree().quit(exit_code)

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(navigation_controller) and navigation_controller.handle_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _has_career(): pause_menu()
		else: _navigate("Accueil")
