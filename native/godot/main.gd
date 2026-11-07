extends Control

const G = preload("res://ui/game_skin.gd")
const Entry = preload("res://ui/entry_screens.gd")
const ClubViews = preload("res://ui/club_views.gd")
const SquadViews = preload("res://ui/squad_views.gd")
const MatchUI = preload("res://ui/match_screen.gd")
const PackViews = preload("res://ui/pack_views.gd")
var model: Dictionary = {}
var catalogue: Array = []
var route := "Accueil"
var selected_club := 0
var selected_player := ""
var selected_slot := 0
var club_division := "elite"
var table_division := "elite"
var roster_filter := "Tous"
var roster_sort := "Poste"
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

func _ready() -> void:
	if OS.get_environment("CD_GODOT_SELF_TEST") == "1" and OS.get_environment("CD_GODOT_DATA_DIR").is_empty():
		printerr("La réception exige un profil temporaire explicite.")
		get_tree().quit(2)
		return
	theme = G.T.make()
	catalogue = JSON.parse_string(FileAccess.get_file_as_string("res://assets/clubs.json"))
	timer = Timer.new()
	timer.wait_time = 0.32
	timer.timeout.connect(_live_tick)
	add_child(timer)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.json ; Carrière Oval Legacy 27"])
	file_dialog.file_selected.connect(_file_selected)
	add_child(file_dialog)
	pack_manager = load("res://pack_manager.gd").new()
	pack_manager.app = self
	add_child(pack_manager)
	bridge = load("res://engine_bridge.gd").new()
	add_child(bridge)
	bridge.model_changed.connect(_receive_model)
	bridge.command_failed.connect(_failed)
	_render()
	bridge.start(_profile_path())
	timer.start()
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(request_quit)
	if OS.get_environment("CD_GODOT_SELF_TEST") == "1":
		var qa: Node = load("res://qa_runner.gd").new()
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
	model = value
	if model.get("meta", {}).get("catalogue") is Array:
		catalogue = model.meta.catalogue.duplicate(true)
	waiting = false
	connection_error = false
	if _has_career(): accent = Color(G.identity(model.club).get("color", "#d43e47"))
	if not export_path.is_empty() and not _write_export(): return
	if bridge.last_response_ok: last_error = ""
	if bridge.last_response_ok and not pending_route.is_empty():
		route = pending_route
		pending_route = ""
	if bridge.last_response_ok and last_command in ["new_career","next_season","import"] and _has_career():
		for league in model.get("leagues",[]):
			for club in league.get("rows",[]):
				if club.id == model.club.id: table_division=league.id
	if last_command == "tick" and route not in ["Accueil", "Création"]:
		_update_live_bar()
		if is_instance_valid(match_screen): match_screen.update_frame(model)
	else:
		if route == "Match" and is_instance_valid(match_screen):
			_update_live_bar()
			_update_header_date()
			match_screen.update_frame(model)
		else: _render()
	if bridge.last_response_ok:
		if is_instance_valid(status):
			status.text = "Sauvegarde automatique · Profil de carrière indépendant"
			status.add_theme_color_override("font_color",G.MUTED)
		if last_command in ["recruit","extend_contract"] and model.get("meta",{}).get("negotiation") is Dictionary:
			var offer: Dictionary = model.meta.negotiation
			notice("La réponse du joueur", str(offer.get("message","La négociation est enregistrée.")))
		if last_command=="promote_cover" and model.meta.get("coverage") is Dictionary:
			notice("Les renforts du centre",str(model.meta.coverage.get("message","La feuille a été complétée.")))
		if last_command=="recover_profile" and not str(model.meta.get("recoveryBackup","")).is_empty():
			notice("Le profil d'origine est conservé","Copie de sécurité :\n"+str(model.meta.recoveryBackup)+"\n\nVous pouvez maintenant créer ou importer une carrière.")
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
	bridge.send(command, payload)
	return waiting

func _refuse_action(message: String) -> void:
	# A local refusal must not complete or discard the actual in-flight action.
	last_error = message
	if is_instance_valid(status):
		status.text = "ACTION NON EFFECTUÉE · " + message
		status.add_theme_color_override("font_color", Color("f1b6a9"))
	notice("Votre décision n'a pas été appliquée", message)

func _failed(message: String) -> void:
	waiting = false
	queued_action.clear()
	pending_route = ""
	last_error = message
	connection_error = bridge.child_pid <= 0 or bridge._stopping
	if is_instance_valid(status):
		status.text = "ACTION NON EFFECTUÉE · " + message
		status.add_theme_color_override("font_color", Color("f1b6a9"))
	if last_command == "tick": timer.stop()
	_clear_dialogs()
	var d := AcceptDialog.new()
	_prepare_dialog(d, 590)
	d.title = "Votre décision n'a pas été appliquée"
	d.dialog_text = message
	add_child(d)
	d.popup_centered(Vector2i(590, 180))
	d.confirmed.connect(d.queue_free)
	if route == "Accueil" or not _has_career(): _render()

func _navigate(target: String) -> void:
	route = target
	_render()

func _render() -> void:
	if is_instance_valid(root_content):
		remove_child(root_content)
		root_content.queue_free()
	match_screen = null
	match_view = null
	match_page = null
	root_content = Control.new()
	root_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_content)
	move_child(root_content, 0)
	var bg := ColorRect.new()
	bg.color = G.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_content.add_child(bg)
	if route == "Accueil":
		root_content.add_child(Entry.home(self))
		return
	if route == "Création":
		var m := G.margin(30)
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root_content.add_child(m)
		m.add_child(Entry.creation(self))
		return
	if route == "Packs":
		var margin := G.margin(30)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root_content.add_child(margin)
		margin.add_child(PackViews.page(self))
		return
	if not _has_career():
		route = "Accueil"
		_render()
		return
	var shell := G.h(0)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_content.add_child(shell)
	_build_sidebar(shell)
	var inset := G.margin(22)
	G.fill(inset, true)
	shell.add_child(inset)
	var content := G.v(13)
	inset.add_child(content)
	var top := G.h(12)
	content.add_child(top)
	var titles := G.v(0)
	G.fill(titles)
	top.add_child(titles)
	header_date = G.label("", 11, G.MUTED)
	titles.add_child(header_date)
	_update_header_date()
	heading = G.label({"Bureau":"LE CLUB, DEMAIN.","Effectif":"LES HOMMES DU PROJET","Composition":"VOTRE FEUILLE À 23","Préparation":"PRÉPARER LA RENCONTRE","Calendrier":"LE FIL DE LA SAISON","Classements":"LA COURSE AUX SOMMETS","Recrutement":"CONSTRUIRE L'EFFECTIF","Finances":"LES MOYENS DU PROJET","Club":"UN CLUB. UN TERRITOIRE.","Match":"LE JOUR DE MATCH"}.get(route, route.to_upper()), 35, G.INK, true)
	titles.add_child(heading)
	top.add_child(G.button("SAUVEGARDER", func(): _command("save")))
	primary_button = G.button(primary_text(), primary_action, true)
	top.add_child(primary_button)
	minibar = G.label("", 12, G.GOLD)
	content.add_child(minibar)
	PackViews.missing_warning(self, content, "career")
	body = G.v(13)
	G.fill(body, true)
	content.add_child(body)
	status = G.label(last_error if not last_error.is_empty() else "Sauvegarde automatique · Profil de carrière indépendant", 10, G.MUTED)
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(status)
	match route:
		"Bureau": body.add_child(ClubViews.office(self))
		"Club": body.add_child(ClubViews.club(self))
		"Calendrier": body.add_child(ClubViews.calendar(self))
		"Classements": body.add_child(ClubViews.tables(self))
		"Finances": body.add_child(ClubViews.finance(self))
		"Effectif": body.add_child(SquadViews.squad(self))
		"Composition": body.add_child(SquadViews.lineup(self))
		"Préparation": body.add_child(SquadViews.preparation(self))
		"Recrutement": body.add_child(SquadViews.market(self))
		"Match":
			match_screen = MatchUI.new()
			match_screen.app = self
			body.add_child(match_screen)
			match_page = match_screen
			match_screen.update_frame(model)
	_update_live_bar()

func _update_header_date() -> void:
	if not is_instance_valid(header_date): return
	var meta: Dictionary = model.get("meta", {})
	header_date.text = ("SAISON %s  /  %s" % [G.n(meta.get("season", 1)),meta.get("roundLabel", "Journée " + G.n(int(meta.get("round", 0))+1))]).to_upper()

func _build_sidebar(parent: Node) -> void:
	var rail := PanelContainer.new()
	rail.custom_minimum_size.x = 192
	rail.add_theme_stylebox_override("panel", G.T.box(Color("111b22"), 0))
	parent.add_child(rail)
	var margin := G.margin(2)
	rail.add_child(margin)
	var left := G.v(5)
	margin.add_child(left)
	var logo := G.button("OVAL LEGACY 27\nRUGBY MANAGER", pause_menu)
	logo.add_theme_font_override("font", G.T.DISPLAY)
	logo.add_theme_font_size_override("font_size", 23)
	logo.custom_minimum_size.y = 70
	left.add_child(logo)
	left.add_child(G.separator())
	left.add_child(G.crest(model.club, 60))
	var name := G.label(G.club_name(model.club), 20, G.INK, true)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(name)
	left.add_child(G.separator())
	for group in [["LE CLUB",["Bureau","Effectif","Composition","Préparation","Recrutement","Finances","Club"]],["LA COMPÉTITION",["Calendrier","Classements","Match"]]]:
		left.add_child(G.label(group[0], 9, G.MUTED))
		for target in group[1]:
			var b := G.nav_button(target.to_upper(),func():_navigate(target),accent,route==target)
			left.add_child(b)
	left.add_child(G.spacer())
	left.add_child(G.label("PRÉALPHA 0.3  /  WINDOWS", 9, G.GOLD))
	left.add_child(G.button("MENU & SAUVEGARDES", pause_menu))

func _update_live_bar() -> void:
	if not is_instance_valid(minibar): return
	var live := _live()
	if not live.is_empty():
		var teams: Array = live.get("teams", [{},{}])
		var score: Array = live.get("score", [0,0])
		minibar.text = "%s  %s — %s  %s   ·   %s min%s" % [G.club_abbr(teams[0]),G.n(score[0]),G.n(score[1]),G.club_abbr(teams[1]),G.n(live.get("minute",0)),"  /  PAUSE" if live.get("paused",false) else ""]
	else: minibar.text = "ÉLITE & ACCESSION  /  30 CLUBS" if model.meta.get("mode") in ["france30", "common"] else "CARRIÈRE HISTORIQUE  /  14 CLUBS"
	if is_instance_valid(primary_button): primary_button.text = primary_text()

func primary_text() -> String:
	var live := _live()
	if not live.is_empty(): return "VALIDER LE RÉSULTAT  →" if live.get("finished",false) else "RETOUR AU DIRECT  →"
	if model.get("meta",{}).get("canAdvanceSeason",false): return "SAISON SUIVANTE  →"
	return "PRÉPARER LE MATCH  →" if model.get("next") != null else "AVANCER LA SEMAINE  →"

func primary_action() -> void:
	if not _live().is_empty():
		if _live().get("finished",false): _command("finish_round")
		else: _navigate("Match")
	elif model.meta.get("canAdvanceSeason",false): confirm("Une nouvelle saison", "Les contrats arrivés à échéance sont réglés et les mouvements de division sont appliqués. Commencer la saison suivante ?", func(): _command("next_season",{"confirmed":true}))
	elif model.get("next") == null: _command("finish_round")
	else: _navigate("Préparation")

func create_career(id: int) -> void:
	var action := func(): _command("new_career",{"club":id,"mode":"common"},"Bureau")
	if _has_career(): confirm("Une nouvelle histoire", "La carrière actuelle sera remplacée dans ce profil. Exportez-la depuis le menu pour la conserver séparément. Prendre les rênes de %s ?" % catalogue[id].name, action)
	else: action.call()

func confirm(title: String, text: String, callback: Callable) -> void:
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

func _prepare_dialog(dialog: AcceptDialog, width: int) -> void:
	# Configure wrapping before text/insertion can queue an oversized minimum.
	dialog.min_size = Vector2i(width, 0)
	dialog.dialog_autowrap = true

func pause_menu() -> void:
	_clear_dialogs()
	if not _live().is_empty() and not _live().get("paused",false) and not _live().get("finished",false):
		if not _command("pause",{"paused":true}): return
	var d := AcceptDialog.new()
	_prepare_dialog(d, 720)
	d.title = "Votre carrière"
	d.dialog_text = "Sauvegarde automatique dans un profil indépendant.\n" + _profile_path()
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
	d.popup_centered(Vector2i(720,190))

func settings() -> void:
	_clear_dialogs()
	var d := AcceptDialog.new()
	_prepare_dialog(d, 650)
	d.title = "Affichage"
	d.dialog_text = "Fenêtre redimensionnable · interface adaptée à votre écran."
	d.add_button("Fenêtré1440×900",false,"window")
	d.add_button("Plein écran",false,"full")
	d.add_button("Packs et identités",false,"packs")
	d.custom_action.connect(func(action: String):
		if action == "packs":
			d.hide(); d.queue_free()
			pack_manager.open("career" if _has_career() else "creation")
			return
		if action == "full": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1440,900))
		d.hide(); d.queue_free())
	add_child(d)
	d.popup_centered(Vector2i(650,180))

func open_file(importing: bool) -> void:
	import_mode = importing
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if importing else FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.current_file = "" if importing else "Oval-Legacy-27.json"
	file_dialog.popup_centered_ratio(0.7)

func _file_selected(path: String) -> void:
	if import_mode:
		var f := FileAccess.open(path,FileAccess.READ)
		if f == null: _refuse_action("Le fichier ne peut pas être lu : " + error_string(FileAccess.get_open_error())); return
		if f.get_length() > 5*1024*1024: f.close(); _refuse_action("Fichier trop volumineux :5 Mio maximum."); return
		var text := f.get_as_text()
		f.close()
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
	var temporary := destination + ".tmp-" + str(OS.get_process_id())
	var f := FileAccess.open(temporary,FileAccess.WRITE)
	if f == null: _failed("L'export ne peut pas être écrit."); return false
	f.store_string(text)
	f.flush()
	var error := f.get_error()
	f.close()
	if error == OK: error = DirAccess.rename_absolute(temporary,destination)
	if error != OK:
		DirAccess.remove_absolute(temporary)
		_failed("Écriture de l'export refusée : " + error_string(error))
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

func _close() -> void:
	if closing: return
	closing = true
	timer.stop()
	bridge.stop()
	var deadline := Time.get_ticks_msec()+2300
	while bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _has_career(): pause_menu()
		else: _navigate("Accueil")
