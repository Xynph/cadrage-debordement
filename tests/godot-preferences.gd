extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
class SpeechSpy extends "res://guide/guide_speech.gd":
	var gains: Array[int] = []
	var stops := 0
	func _speak_system(_text: String, gain: int, _id: int) -> void: gains.append(gain)
	func _stop_system() -> void: stops += 1
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
	check(not app.waiting and app.bridge.last_response_ok,"Worker réel : "+id+" · "+str(app.last_error))
	app.timer.stop(); await settle()
func clear_required_press() -> void:
	if not app._press_required(): return
	var press: Dictionary = app.model.clubLife.press
	var conference: Dictionary = press.conference
	var answers: Array[Dictionary] = []
	for question: Dictionary in conference.questions:
		answers.append({"questionId":question.id,"answerId":question.answers[0].id})
	await command("press_conference", {"context":press.context,"invitationId":conference.invitationId,"answers":answers})
	check(not app._press_required(), "Conférence obligatoire réellement reçue avant le match de recette")

func bone_poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for index in skeleton.get_bone_count(): poses.append(skeleton.get_bone_pose(index))
	return poses

func prepare_real_match() -> void:
	for day in 40:
		await clear_required_press()
		var cadence: Dictionary = app.model.meta.get("calendarCadence", {})
		if cadence.is_empty() or cadence.get("matchReady", false): break
		if not cadence.get("canAdvance", false): break
		await command("advance_day", {"fromDate":app.model.meta.calendarToday})
	await clear_required_press()
	var cadence: Dictionary = app.model.meta.get("calendarCadence", {})
	check(cadence.is_empty() or cadence.get("matchReady", false), "Le calendrier natif atteint réellement le jour du match")
	check(app.model.get("next") is Dictionary, "Rencontre native annoncée avant la recette du rendu")
func run() -> void:
	if not ResourceLoader.exists("res://ui/user_preferences.gd") or not ResourceLoader.exists("res://ui/preferences_dialog.gd"):
		check(false,"Profil durable et dialogue de préférences absents")
		finish(); return
	profile_script = load("res://ui/user_preferences.gd")
	await profile_cases()
	volume_routing_cases()
	await dialog_cases()
	finish()
func volume_routing_cases() -> void:
	# Real shell callback and profiles; replace only the OS TTS boundary (no sound).
	var shell = load("res://main.gd").new()
	var guide = load("res://guide/coach_guide.gd").new()
	var speech = SpeechSpy.new(); guide.speech = speech; guide.add_child(speech)
	shell.coach = guide; shell.add_child(guide)
	var profile = profile_script.new(); shell.user_preferences = profile
	profile.changed.connect(shell._apply_user_preferences)
	var folder := directory.path_join("tts-routing")
	for item in [[0,0],[40,30],[100,75]]:
		write_profile_volume(folder,item[0])
		check(profile.load_profile(folder),"Chargement initial du gain TTS " + str(item[0]))
		speech.voice_id = "spy-fr"; speech.speak("Bulle système sans WAV")
		check(not speech.gains.is_empty() and speech.gains[-1] == item[1],"Le vrai callback main raccorde le TTS après chargement " + str(item[0]))
		var reloaded = profile_script.new(); shell.user_preferences = reloaded
		reloaded.changed.connect(shell._apply_user_preferences)
		check(reloaded.load_profile(folder),"Reprise du profil TTS " + str(item[0]))
		speech.speak("Bulle après reprise")
		check(speech.gains[-1] == item[1],"Gain système correct après reprise " + str(item[0]))
		shell.user_preferences = profile
	profile.set_value("volume",100); speech.speak("Phrase en cours"); speech._started(speech._active)
	var stops: int = speech.stops
	check(profile.set_value("volume",0) and speech.stops == stops + 1 and not speech.speaking,"Préférence zéro coupe le TTS déjà en cours via main")
	speech.speak("Phrase silencieuse suivante")
	check(speech.gains[-1] == 0,"Volume zéro réellement transmis au TTS après changement")
	speech.set_muted(true); var count: int = speech.gains.size()
	check(profile.set_value("volume",40),"Volume40 enregistré pendant mute Gabi")
	speech.speak("Ne doit pas parler")
	check(speech.muted and speech.gains.size() == count,"Mute propre à Gabi préservé par main")
	shell.free()
func write_profile_volume(folder: String, volume: int) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	write(folder.path_join("interface.json"),JSON.stringify({"version":1,"volume":volume,"reduced_motion":false,"quality":"balanced","camera":"tv"}))
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
	check(p.data == {"version":1,"volume":75,"reduced_motion":false,"quality":"balanced","camera":"tv","display_screen":-1,"stadium":"day","salary_period":"weekly","match_highlights":"dynamique"},"Valeurs par défaut sans carrière")
	check(not FileAccess.file_exists(folder.path_join("interface.json")),"Lire un profil absent ne crée pas de fichier")
	check(not p.load_profile("relative-folder") and not p.last_error.is_empty(),"Chemin relatif refusé visiblement")
	check(p.load_profile(folder),"Retour au dossier absolu")
	check(p.set_value("volume",42),"Volume enregistré")
	check(p.set_value("camera","action") and p.effective_camera() == "action","Caméra préférée effective")
	check(p.set_value("reduced_motion",true) and p.effective_camera() == "tactical" and p.data.camera == "action","Mode calme fixe tactique sans perdre le choix")
	check(p.set_value("reduced_motion",false) and p.effective_camera() == "action","Sortie du mode calme restaure caméra")
	check(p.set_value("quality","detail"),"Qualité enregistrée")
	check(p.set_value("display_screen",1),"Écran secondaire enregistré")
	check(p.set_value("stadium","evening") and p.data.display_screen == 1,"L’éclairage est enregistré sans modifier l’écran choisi")
	var raw := FileAccess.get_file_as_string(folder.path_join("interface.json"))
	var q = profile_script.new()
	check(q.load_profile(folder) and q.data.volume == 42 and q.data.quality == "detail" and q.data.camera == "action","Redémarrage relit les effets choisis")
	check(q.data.get("display_screen") == 1,"Redémarrage relit l’écran choisi")
	check(q.data.get("stadium") == "evening","Redémarrage relit l’éclairage choisi")
	for item in [["volume",-1],["volume",101],["volume",5.5],["volume",true],["quality","ultra"],["camera","orbit"],["reduced_motion",1],["secret","x"],["version",2],["display_screen",-2],["display_screen",1.5],["display_screen",true],["display_screen","1"],["display_screen",2147483648],["stadium","night"],["stadium",true]]:
		check(not p.set_value(item[0],item[1]) and not p.last_error.is_empty(),"Réglage invalide refusé : "+str(item))
		check(FileAccess.get_file_as_string(folder.path_join("interface.json")) == raw,"Refus conserve octets originaux")
	var legacy_folder := directory.path_join("legacy-display")
	write_profile_volume(legacy_folder,40)
	var legacy_path := legacy_folder.path_join("interface.json")
	var legacy_bytes := FileAccess.get_file_as_bytes(legacy_path)
	check(q.load_profile(legacy_folder) and q.data.display_screen == -1 and q.data.get("stadium") == "day" and q.data.volume == 40,"Ancien profil sans écran relu avec les réglages par défaut")
	check(FileAccess.get_file_as_bytes(legacy_path) == legacy_bytes,"La lecture de l’ancien profil conserve ses octets")
	var screen_only := {"version":1,"volume":40,"reduced_motion":false,"quality":"balanced","camera":"tv","display_screen":1}
	write(legacy_path,JSON.stringify(screen_only))
	legacy_bytes = FileAccess.get_file_as_bytes(legacy_path)
	check(q.load_profile(legacy_folder) and q.data.display_screen == 1 and q.data.get("stadium") == "day","Profil avec écran seul relu en mode jour")
	check(FileAccess.get_file_as_bytes(legacy_path) == legacy_bytes,"La reprise du profil avec écran seul conserve ses octets")
	screen_only["stadium"] = "night"
	write(legacy_path,JSON.stringify(screen_only))
	legacy_bytes = FileAccess.get_file_as_bytes(legacy_path)
	check(not q.load_profile(legacy_folder) and not q.last_error.is_empty(),"Profil avec éclairage invalide refusé visiblement")
	check(FileAccess.get_file_as_bytes(legacy_path) == legacy_bytes,"Le refus d’éclairage invalide conserve ses octets")
	AudioServer.set_bus_mute(0,true)
	p.apply_audio()
	check(is_equal_approx(AudioServer.get_bus_volume_linear(0),0.42) and AudioServer.is_bus_mute(0),"Volume Master appliqué sans supprimer le mute externe")
	check(p.set_value("volume",0) and AudioServer.get_bus_volume_linear(0) == 0.0 and AudioServer.is_bus_mute(0),"Zéro réellement silencieux, mute préservé")
	check(p.reset_defaults() and p.data.volume == 75 and p.data.camera == "tv" and p.data.quality == "balanced" and not p.data.reduced_motion and p.data.display_screen == -1 and p.data.get("stadium") == "day","Reset limité au profil UI, écran automatique et stade de jour")
	var bads := ["{",'{"version":2,"volume":75,"reduced_motion":false,"quality":"balanced","camera":"tv"}','{"version":1,"volume":75,"reduced_motion":false,"quality":"balanced","camera":"tv","rng":1}','{"version":1,"volume":75.25,"reduced_motion":false,"quality":"balanced","camera":"tv"}','{"version":1,"volume":75,"reduced_motion":false,"quality":"balanced"}','{"version":1,"volume":75,"reduced_motion":false,"quality":"balanced","camera":"tv","display_screen":1.5}'," ".repeat(16385)]
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
	check(app.coach.speech.global_volume == p.data.volume,"Démarrage réel raccorde aussi le volume TTS de Gabi")
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
	check(p.set_value("display_screen",1),"Écran de droite conservé dans le profil du vrai match")
	var local_path: String = str(app.model.meta.dataDir).path_join("interface.json")
	var local_bytes := FileAccess.get_file_as_bytes(local_path)
	await command("new_career",{"club":0,"mode":"common"})
	await ContextualFlow.settle_club_meetings(app, self, check)
	await command("export")
	var career_text: String = app.model.meta.exportText
	check(not career_text.contains("reduced_motion") and not career_text.contains('"quality"') and not career_text.contains('"volume"') and not career_text.contains('"display_screen"') and not career_text.contains('"salary_period"'),"Export carrière sans préférences locales")
	await command("new_career",{"club":1,"mode":"common"})
	await ContextualFlow.settle_club_meetings(app, self, check)
	await command("import",{"text":career_text})
	check(FileAccess.get_file_as_bytes(local_path) == local_bytes,"Créations et import de carrière conservent exactement le profil local")
	var restarted = profile_script.new()
	check(restarted.load_profile(str(app.model.meta.dataDir)) and restarted.data.volume == 39,"Reconstruction du profil après import garde le volume")
	var rebuilt: AcceptDialog = helper.open(app,restarted); await settle()
	var rebuilt_volume: SpinBox = rebuilt.find_child("PreferencesVolume",true,false)
	check(rebuilt_volume.value == 39,"Dialogue reconstruit affiche le réglage rechargé")
	rebuilt.hide(); rebuilt.queue_free(); await settle()
	await prepare_real_match()
	await command("begin_match")
	await ContextualFlow.skip_talk(app, self, "pre", check)
	app._navigate("Match"); await settle()
	var stage: Node3D = app.match_view
	check(is_instance_valid(stage) and stage._actors.size() == 30,"Vrai match natif avec trente joueurs")
	var engine_before := JSON.stringify(app.model.live)
	var day_energy: float = stage._sun.light_energy
	check(stage.get_node_or_null("StadiumEvening") == null,"Le match de jour ne construit pas les projecteurs")
	await capture_stadium("stade-jour-match")
	app.settings(); await settle()
	var display_dialog: AcceptDialog = app.find_child("PreferencesDialog",true,false)
	var display_tabs: TabContainer = display_dialog.find_child("PreferencesTabs",true,false)
	display_tabs.current_tab = 2; await settle()
	var stadium: OptionButton = display_dialog.find_child("PreferencesStadiumLighting",true,false)
	check(stadium != null and stadium.is_visible_in_tree() and stadium.get_item_text(0) == "Jour" and stadium.get_item_text(1) == "Soirée","Éclairage accessible dans Paramètres / Affichage")
	var display_screen: int = p.data.display_screen
	if stadium != null:
		stadium.grab_focus(); await key(KEY_SPACE); await key(KEY_DOWN); await key(KEY_ENTER)
		check(p.data.get("stadium") == "evening" and stadium.selected == 1 and p.data.display_screen == display_screen,"Soirée choisie au clavier sans changer le moniteur")
	await capture_stadium("stade-reglage")
	display_dialog.hide(); display_dialog.queue_free(); await settle()
	var evening_kit: Node3D = stage.get_node_or_null("StadiumEvening")
	check(evening_kit != null and evening_kit.visible and stage._sun.light_energy < day_energy and stage._actors.size() == 30,"Soirée appliquée au vrai match avec trente joueurs")
	await capture_stadium("stade-soiree-match")
	check(p.set_value("stadium","day") and evening_kit != null and not evening_kit.visible and is_equal_approx(stage._sun.light_energy,day_energy),"Retour au jour restaure l’éclairage d’origine")
	check(p.set_value("stadium","evening") and stage.get_node_or_null("StadiumEvening") == evening_kit,"Basculer de nouveau réutilise les projecteurs")
	check(p.set_value("quality","economy") and stage._quality == "economy" and not stage._sun.shadow_enabled,"Qualité économie applique réellement le budget d'ombres")
	check(p.set_value("camera","action") and stage._camera_mode == "action","Préférence action appliquée à la scène réelle")
	await settle()
	var camera_before: Transform3D = stage._camera.transform
	check(p.set_value("volume",39) and stage._camera.transform == camera_before,"Volume seul conserve la position de caméra sans réinitialisation")
	app.coach.portrait.set_speaking(true)
	check(p.set_value("reduced_motion",true) and stage._camera_mode == "tactical" and not stage._action_motion and app.coach.portrait.reduced_motion,"Mode calme raccordé à la scène et au vrai portrait")
	var fixed_camera: Transform3D = stage._camera.transform
	var portrait: TextureRect = app.coach.portrait
	if portrait.texture is ViewportTexture:
		var player := portrait.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var skeleton: Skeleton3D
		for node in portrait.find_children("*", "Skeleton3D", true, false):
			skeleton = node
			break
		check(player != null and skeleton != null and skeleton.get_bone_count() == 20, "Le vrai portrait 3D chargé conserve son rig de vingt os")
		if player != null and skeleton != null:
			var fixed_pose := bone_poses(skeleton)
			portrait.set_speaking(true)
			portrait._process(2.0)
			await create_timer(0.25).timeout
			check(stage._camera.transform == fixed_camera and bone_poses(skeleton) == fixed_pose and not player.is_playing() and not portrait.is_processing(), "Caméra et vingt os fixes en mode calme malgré une demande de parole")
			check(app.coach.speech.muted and app.coach.speech.player == null, "Le guide 3D de carrière reste silencieux, sans lecteur vocal")
	else:
		var fixed_pose: int = portrait.pose_index
		portrait._process(2.0)
		await settle()
		check(stage._camera.transform == fixed_camera and portrait.pose_index == fixed_pose and portrait.speaking,"Caméra/pose atlas fixes même en parole, sans désactiver l'état de parole")
	check(app.match_screen._camera_controls.all(func(button): return button.disabled) and stage._actors.size() == 30,"Caméras verrouillées en mode calme et joueurs conservés")
	check(JSON.stringify(app.model.live) == engine_before,"Confort ne change ni temps, ni positions moteur, ni RNG du vrai match")
	if OS.get_environment("CD_PREFERENCES_GRAPHICS") == "1":
		app.settings(); await settle(); await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join("preferences-match-calme.png"))
		var calm_dialog: AcceptDialog = app.find_child("PreferencesDialog",true,false)
		calm_dialog.hide(); calm_dialog.queue_free(); await settle()
	check(p.set_value("reduced_motion",false) and stage._camera_mode == "action" and stage._action_motion and not app.coach.portrait.reduced_motion,"Désactiver calme restaure caméra action et animation portrait")
	var stage_id := stage.get_instance_id()
	app._navigate("Bureau"); await settle(); app._navigate("Match"); await settle()
	check(app.route == "Match" and app.match_view.get_instance_id() == stage_id and app.match_view._camera_mode == "action" and app.match_view._quality == "economy" and not app.root_content.is_visible_in_tree(),"Navigation gestion refusée pendant le match conserve scène, caméra et qualité")
	var rebuilt_stadium: Node3D = app.match_view.get_node_or_null("StadiumEvening")
	check(rebuilt_stadium != null and rebuilt_stadium.visible,"Le retour dans Match conserve l’éclairage de soirée")
	check(p.set_value("reduced_motion",true),"Mode calme enregistré avant redémarrage")
	app.closing = true; app.bridge.stop(); app.queue_free(); await settle()
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	deadline = Time.get_ticks_msec()+30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop(); await settle()
	p = app.user_preferences
	app._navigate("Match"); await settle()
	check(p.data.volume == 39 and p.data.camera == "action" and p.data.quality == "economy" and p.data.reduced_motion,"Redémarrage complet du vrai shell recharge les préférences distinctes")
	check(app.coach.speech.global_volume == 39,"Redémarrage réel réapplique aussi le gain global TTS")
	check(app.match_view._camera_mode == "tactical" and app.match_view._quality == "economy" and app.coach.portrait.reduced_motion and is_equal_approx(AudioServer.get_bus_volume_linear(0),0.39),"Redémarrage réapplique scène, portrait et volume")
	var restarted_stadium: Node3D = app.match_view.get_node_or_null("StadiumEvening")
	check(p.data.get("stadium") == "evening" and p.data.display_screen == 1 and restarted_stadium != null and restarted_stadium.visible,"Redémarrage réapplique l’éclairage de soirée et conserve le moniteur")
	var confirmation := ConfirmationDialog.new(); app._prepare_dialog(confirmation,500); app.add_child(confirmation); confirmation.popup_centered(Vector2i(500,180)); await settle()
	check(helper.open(app,p) == null and confirmation.visible and not confirmation.is_queued_for_deletion(),"Paramètres laissent la priorité à une confirmation ouverte")
	confirmation.hide(); confirmation.queue_free(); await settle()
	var bad = profile_script.new(); bad.load_profile(directory.path_join("bad-0"))
	var error_dialog: AcceptDialog = helper.open(app,bad); await settle()
	var error: Label = error_dialog.find_child("PreferencesError",true,false)
	check(error != null and error.visible and not error.text.is_empty(),"Erreur du profil réellement visible dans Paramètres")
	error_dialog.hide(); error_dialog.queue_free(); await settle()

func capture_stadium(label: String) -> void:
	if OS.get_environment("CD_PREFERENCES_GRAPHICS") != "1":
		return
	var expected_x := OS.get_environment("CD_PREFERENCES_SCREEN_X")
	if expected_x.is_valid_int():
		var screen := DisplayServer.window_get_current_screen()
		check(DisplayServer.screen_get_position(screen).x == expected_x.to_int(),"Capture sur l’écran demandé " + label)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK,"Capture du match " + label)
