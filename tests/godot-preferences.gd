extends SceneTree
var failures: Array[String] = []
var checks := 0
var directory := OS.get_environment("CD_PREFERENCES_TEST_DIR")
var profile_script: Script
var app: Control
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: " + message)
func write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text); file.close()
func settle() -> void:
	for i in 6: await process_frame
func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new(); event.keycode = code; event.pressed = down
		Input.parse_input_event(event); await process_frame
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id,payload)
	var deadline := Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok,"Worker réel : "+id)
	app.timer.stop(); await settle()
func run() -> void:
	if not ResourceLoader.exists("res://ui/user_preferences.gd") or not ResourceLoader.exists("res://ui/preferences_dialog.gd"):
		check(false,"Profil durable et dialogue de préférences absents")
		finish(); return
	profile_script = load("res://ui/user_preferences.gd")
	await profile_cases()
	await dialog_cases()
	finish()
func finish() -> void:
	write(directory.path_join("report.json"),JSON.stringify({"checks":checks,"failures":failures},"  "))
	if app != null: app.closing = true; app.bridge.stop()
	print("Préférences : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
func profile_cases() -> void:
	var p = profile_script.new()
	check(not p.set_value("volume",10) and not p.last_error.is_empty(),"Écriture sans chargement refusée visiblement")
	var folder := directory.path_join("valid")
	check(p.load_profile(folder),"Dossier absolu neuf accepté")
	check(p.data == {"version":1,"volume":75,"reduced_motion":false,"quality":"balanced","camera":"tv"},"Valeurs par défaut sans carrière")
	check(not FileAccess.file_exists(folder.path_join("interface.json")),"Lire un profil absent ne crée pas de fichier")
	check(not p.load_profile("relative-folder") and not p.last_error.is_empty(),"Chemin relatif refusé visiblement")
	check(p.load_profile(folder),"Retour au dossier absolu")
	check(p.set_value("volume",42),"Volume enregistré")
	check(p.set_value("camera","action") and p.effective_camera() == "action","Caméra préférée effective")
	check(p.set_value("reduced_motion",true) and p.effective_camera() == "tactical" and p.data.camera == "action","Mode calme fixe tactique sans perdre le choix")
	check(p.set_value("reduced_motion",false) and p.effective_camera() == "action","Sortie du mode calme restaure caméra")
	check(p.set_value("quality","detail"),"Qualité enregistrée")
	var raw := FileAccess.get_file_as_string(folder.path_join("interface.json"))
	var q = profile_script.new()
	check(q.load_profile(folder) and q.data.volume == 42 and q.data.quality == "detail" and q.data.camera == "action","Redémarrage relit les effets choisis")
	for item in [["volume",-1],["volume",101],["volume",5.5],["volume",true],["quality","ultra"],["camera","orbit"],["reduced_motion",1],["secret","x"],["version",2]]:
		check(not p.set_value(item[0],item[1]) and not p.last_error.is_empty(),"Réglage invalide refusé : "+str(item))
		check(FileAccess.get_file_as_string(folder.path_join("interface.json")) == raw,"Refus conserve octets originaux")
	AudioServer.set_bus_mute(0,true)
	p.apply_audio()
	check(is_equal_approx(AudioServer.get_bus_volume_linear(0),0.42) and AudioServer.is_bus_mute(0),"Volume Master appliqué sans supprimer le mute externe")
	check(p.set_value("volume",0) and AudioServer.get_bus_volume_linear(0) == 0.0 and AudioServer.is_bus_mute(0),"Zéro réellement silencieux, mute préservé")
	check(p.reset_defaults() and p.data.volume == 75 and p.data.camera == "tv" and p.data.quality == "balanced" and not p.data.reduced_motion,"Reset limité au profil UI")
	var bads := ["{",'{"version":2,"volume":75,"reduced_motion":false,"quality":"balanced","camera":"tv"}','{"version":1,"volume":75,"reduced_motion":false,"quality":"balanced","camera":"tv","rng":1}','{"version":1,"volume":75.25,"reduced_motion":false,"quality":"balanced","camera":"tv"}','{"version":1,"volume":75,"reduced_motion":false,"quality":"balanced"}'," ".repeat(16385)]
	for i in bads.size():
		var bad_dir := directory.path_join("bad-"+str(i)); DirAccess.make_dir_recursive_absolute(bad_dir)
		var path := bad_dir.path_join("interface.json"); write(path,bads[i])
		var bad = profile_script.new()
		check(not bad.load_profile(bad_dir) and not bad.last_error.is_empty(),"Profil invalide/trop gros refusé visiblement "+str(i))
		check(not bad.set_value("volume",1) and not bad.reset_defaults(),"Profil refusé protégé de toute réécriture "+str(i))
		check(FileAccess.get_file_as_string(path) == bads[i],"Original invalide intégralement préservé "+str(i))
	var stable := FileAccess.get_file_as_string(folder.path_join("interface.json"))
	DirAccess.make_dir_absolute(folder.path_join("interface.json.tmp"))
	var before: Dictionary = p.data.duplicate(true)
	check(not p.set_value("volume",33) and not p.last_error.is_empty() and p.data == before,"Écriture temporaire impossible laisse données précédentes")
	check(FileAccess.get_file_as_string(folder.path_join("interface.json")) == stable and is_equal_approx(AudioServer.get_bus_volume_linear(0),0.75),"Échec atomique conserve original et effet audio")
	DirAccess.remove_absolute(folder.path_join("interface.json.tmp"))
	write(folder.path_join("interface.json.tmp"),"interruption tronquée")
	check(q.load_profile(folder) and q.data.volume == 75,"Reprise ignore temporaire incomplet")
	check(q.set_value("volume",66) and not FileAccess.file_exists(folder.path_join("interface.json.tmp")),"Reprise remplace atomiquement puis enlève temporaire")
	if OS.has_feature("editor"):
		var runtime := OS.get_environment("CD_NODE_EXECUTABLE")
		var unavailable_before: Dictionary = q.data.duplicate(true)
		var unavailable_bytes := FileAccess.get_file_as_bytes(folder.path_join("interface.json"))
		OS.set_environment("CD_NODE_EXECUTABLE",directory.path_join("absent-node.exe"))
		check(not q.set_value("volume",18) and not q.last_error.is_empty() and q.data == unavailable_before,"Runtime atomique absent : refus visible sans effet publié")
		OS.set_environment("CD_NODE_EXECUTABLE",runtime)
		check(FileAccess.get_file_as_bytes(folder.path_join("interface.json")) == unavailable_bytes and not FileAccess.file_exists(folder.path_join("interface.json.tmp")),"Runtime absent : original conservé et temporaire nettoyé sans repli")
	var rename_folder := directory.path_join("rename-failure")
	var rename_profile = profile_script.new(); rename_profile.load_profile(rename_folder)
	DirAccess.make_dir_absolute(rename_folder.path_join("interface.json"))
	var notifications := [0]
	rename_profile.changed.connect(func(): notifications[0] += 1)
	check(not rename_profile.set_value("volume",10) and not rename_profile.last_error.is_empty() and rename_profile.data.volume == 75,"Renommage impossible : réglages précédents conservés")
	check(DirAccess.dir_exists_absolute(rename_folder.path_join("interface.json")) and not FileAccess.file_exists(rename_folder.path_join("interface.json.tmp")) and notifications[0] == 0,"Échec renommage : destination conservée, temporaire nettoyé, aucun effet publié")
	if OS.get_name() == "Windows":
		var readonly = profile_script.new()
		var readonly_path := directory.path_join("read-only/interface.json")
		var readonly_bytes := FileAccess.get_file_as_bytes(readonly_path)
		check(readonly.load_profile(directory.path_join("read-only")),"Profil Windows en lecture seule lisible")
		check(not readonly.set_value("volume",2) and not readonly.last_error.is_empty() and readonly.data.volume == 25,"Destination lecture seule : échec visible et état inchangé")
		check(FileAccess.get_file_as_bytes(readonly_path) == readonly_bytes and is_equal_approx(AudioServer.get_bus_volume_linear(0),0.25),"Destination lecture seule conserve octets et effet audio")
	write(directory.path_join("not-a-directory"),"fichier")
	var impossible = profile_script.new()
	var impossible_loaded: bool = impossible.load_profile(directory.path_join("not-a-directory"))
	check(not impossible_loaded and not impossible.set_value("volume",8),"Dossier impossible : refus sans repli")
	check(not FileAccess.file_exists(folder.path_join("donnees.json")),"Aucune sauvegarde de carrière créée par les préférences")
	var atomic = profile_script.new(); atomic.load_profile(directory.path_join("atomic")); atomic.set_value("volume",20)
	write(directory.path_join("monitor-start"),"start")
	var replacements := 0
	for i in 80:
		var previous: Dictionary = atomic.data.duplicate(true)
		if atomic.set_value("volume",80 if i % 2 == 0 else 20): replacements += 1
		else: check(not atomic.last_error.is_empty() and atomic.data == previous,"Refus Windows concurrent explicite sans effet publié "+str(i))
	check(replacements > 0,"Des remplacements ont réellement eu lieu sous lecture concurrente")
	write(directory.path_join("monitor-stop"),"stop")
	AudioServer.set_bus_mute(0,false)
func dialog_cases() -> void:
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	var deadline := Time.get_ticks_msec()+30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	check(not app.model.is_empty(),"Dialogue sur le vrai shell et son worker")
	var p = app.user_preferences
	check(app.preferences_loaded and p != null,"Le vrai shell charge une fois le dossier final du worker")
	var helper = load("res://ui/preferences_dialog.gd")
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		root.size = resolution; DisplayServer.window_set_size(resolution)
		app.settings(); await settle()
		var d: AcceptDialog = app.find_child("PreferencesDialog",true,false)
		check(d.visible and d.size.x <= resolution.x and d.size.y <= resolution.y,"Dialogue contenu à "+str(resolution))
		if OS.get_environment("CD_PREFERENCES_GRAPHICS") == "1":
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("preferences-%dx%d.png" % [resolution.x,resolution.y]))
		var volume: SpinBox = d.find_child("PreferencesVolume",true,false)
		var motion: CheckButton = d.find_child("PreferencesMotion",true,false)
		var camera: OptionButton = d.find_child("PreferencesCamera",true,false)
		var quality: OptionButton = d.find_child("PreferencesQuality",true,false)
		check(volume != null and motion != null and camera != null and quality != null,"Contrôles natifs identifiables")
		if volume != null and motion != null:
			volume.get_line_edit().grab_focus(); await settle(); await key(KEY_UP)
			check(p.data.volume == int(volume.value) and p.data.volume > 0,"Volume clavier enregistré et affiché")
			check(is_equal_approx(AudioServer.get_bus_volume_linear(0),float(p.data.volume)/100.0),"Valeur audio du volume affiché")
			motion.grab_focus(); await settle(); await key(KEY_SPACE)
			check(p.data.reduced_motion and camera.disabled and p.effective_camera() == "tactical","Clavier calme applique tactique et désactive choix différé")
			await key(KEY_SPACE)
			check(not p.data.reduced_motion and not camera.disabled,"Clavier réactive caméra choisie")
			camera.grab_focus(); await key(KEY_SPACE); await key(KEY_DOWN); await key(KEY_DOWN); await key(KEY_ENTER)
			check(p.data.camera == "action" and p.effective_camera() == "action","Caméra action choisie au clavier")
			quality.grab_focus(); await key(KEY_SPACE); await key(KEY_DOWN); await key(KEY_ENTER)
			check(p.data.quality == "detail","Qualité choisie au clavier")
			var reset: Button = d.find_child("PreferencesReset",true,false)
			var guide_path: String = str(app.model.meta.dataDir).path_join("guide.json")
			var guide_before := FileAccess.get_file_as_bytes(guide_path) if FileAccess.file_exists(guide_path) else PackedByteArray()
			reset.grab_focus(); await key(KEY_ENTER)
			check(p.data.volume == 75 and p.data.quality == "balanced" and int(volume.value) == 75,"Réinitialisation explicite synchronise effets et contrôles")
			check((FileAccess.get_file_as_bytes(guide_path) if FileAccess.file_exists(guide_path) else PackedByteArray()) == guide_before,"Réinitialisation UI conserve exactement les préférences Gabi")
			var volume_before: int = p.data.volume
			DirAccess.make_dir_absolute(str(app.model.meta.dataDir).path_join("interface.json.tmp"))
			volume.value = 12; await settle()
			var write_error: Label = d.find_child("PreferencesError",true,false)
			check(p.data.volume == volume_before and int(volume.value) == volume_before and write_error.visible and not write_error.text.is_empty(),"Échec depuis dialogue : valeur affichée restaurée et erreur visible")
			if OS.get_environment("CD_PREFERENCES_GRAPHICS") == "1" and resolution == Vector2i(1280,720):
				await process_frame; await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(directory.path_join("preferences-error-1280x720.png"))
			DirAccess.remove_absolute(str(app.model.meta.dataDir).path_join("interface.json.tmp"))
			check(p.set_value("volume",p.data.volume),"Une décision après correction du dossier efface l'erreur")
		d.hide(); d.queue_free(); await settle()
	check(p.set_value("volume",39),"Profil local réel préparé avant mutations carrière")
	var local_path: String = str(app.model.meta.dataDir).path_join("interface.json")
	var local_bytes := FileAccess.get_file_as_bytes(local_path)
	await command("new_career",{"club":0,"mode":"common"})
	await command("export")
	var career_text: String = app.model.meta.exportText
	check(not career_text.contains("reduced_motion") and not career_text.contains('"quality"') and not career_text.contains('"volume"'),"Export carrière sans préférences locales")
	await command("new_career",{"club":1,"mode":"common"})
	await command("import",{"text":career_text})
	check(FileAccess.get_file_as_bytes(local_path) == local_bytes,"Créations et import de carrière conservent exactement le profil local")
	var restarted = profile_script.new()
	check(restarted.load_profile(str(app.model.meta.dataDir)) and restarted.data.volume == 39,"Reconstruction du profil après import garde le volume")
	var rebuilt: AcceptDialog = helper.open(app,restarted); await settle()
	var rebuilt_volume: SpinBox = rebuilt.find_child("PreferencesVolume",true,false)
	check(rebuilt_volume.value == 39,"Dialogue reconstruit affiche le réglage rechargé")
	rebuilt.hide(); rebuilt.queue_free(); await settle()
	await command("begin_match")
	app._navigate("Match"); await settle()
	var stage: Node3D = app.match_view
	check(is_instance_valid(stage) and stage._actors.size() == 30,"Vrai match natif avec trente joueurs")
	var engine_before := JSON.stringify(app.model.live)
	check(p.set_value("quality","economy") and stage._quality == "economy" and not stage._sun.shadow_enabled,"Qualité économie applique réellement le budget d'ombres")
	check(p.set_value("camera","action") and stage._camera_mode == "action","Préférence action appliquée à la scène réelle")
	await settle()
	var camera_before: Transform3D = stage._camera.transform
	check(p.set_value("volume",39) and stage._camera.transform == camera_before,"Volume seul conserve la position de caméra sans réinitialisation")
	app.coach.portrait.set_speaking(true)
	check(p.set_value("reduced_motion",true) and stage._camera_mode == "tactical" and app.coach.portrait.reduced_motion,"Mode calme raccordé à la scène et au vrai portrait")
	var fixed_camera: Transform3D = stage._camera.transform
	var fixed_pose: int = app.coach.portrait.pose_index
	app.coach.portrait._process(2.0)
	await settle()
	check(stage._camera.transform == fixed_camera and app.coach.portrait.pose_index == fixed_pose and app.coach.portrait.speaking,"Caméra/pose fixes même en parole, sans désactiver l'état de parole")
	check(app.match_screen._camera_controls.all(func(button): return button.disabled) and stage._actors.size() == 30,"Caméras verrouillées en mode calme et joueurs conservés")
	check(JSON.stringify(app.model.live) == engine_before,"Confort ne change ni temps, ni positions moteur, ni RNG du vrai match")
	if OS.get_environment("CD_PREFERENCES_GRAPHICS") == "1":
		app.settings(); await settle(); await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join("preferences-match-calme.png"))
		var calm_dialog: AcceptDialog = app.find_child("PreferencesDialog",true,false)
		calm_dialog.hide(); calm_dialog.queue_free(); await settle()
	check(p.set_value("reduced_motion",false) and stage._camera_mode == "action" and not app.coach.portrait.reduced_motion,"Désactiver calme restaure caméra action et animation portrait")
	var stage_id := stage.get_instance_id()
	app._navigate("Bureau"); await settle(); app._navigate("Match"); await settle()
	check(app.match_view.get_instance_id() != stage_id and app.match_view._camera_mode == "action" and app.match_view._quality == "economy","Écran match reconstruit conserve caméra et qualité")
	check(p.set_value("reduced_motion",true),"Mode calme enregistré avant redémarrage")
	app.closing = true; app.bridge.stop(); app.queue_free(); await settle()
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	deadline = Time.get_ticks_msec()+30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop(); await settle()
	p = app.user_preferences
	app._navigate("Match"); await settle()
	check(p.data.volume == 39 and p.data.camera == "action" and p.data.quality == "economy" and p.data.reduced_motion,"Redémarrage complet du vrai shell recharge les préférences distinctes")
	check(app.match_view._camera_mode == "tactical" and app.match_view._quality == "economy" and app.coach.portrait.reduced_motion and is_equal_approx(AudioServer.get_bus_volume_linear(0),0.39),"Redémarrage réapplique scène, portrait et volume")
	var confirmation := ConfirmationDialog.new(); app._prepare_dialog(confirmation,500); app.add_child(confirmation); confirmation.popup_centered(Vector2i(500,180)); await settle()
	check(helper.open(app,p) == null and confirmation.visible and not confirmation.is_queued_for_deletion(),"Paramètres laissent la priorité à une confirmation ouverte")
	confirmation.hide(); confirmation.queue_free(); await settle()
	var bad = profile_script.new(); bad.load_profile(directory.path_join("bad-0"))
	var error_dialog: AcceptDialog = helper.open(app,bad); await settle()
	var error: Label = error_dialog.find_child("PreferencesError",true,false)
	check(error != null and error.visible and not error.text.is_empty(),"Erreur du profil réellement visible dans Paramètres")
	error_dialog.hide(); error_dialog.queue_free(); await settle()
