extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var guide: Control
var failures: Array[String] = []
var checks := 0
var spoken: Array[String] = []
func _initialize() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty(): quit(2); return
	call_deferred("run")
func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures.append(text); printerr("FAIL: ", text)
func wait_model() -> void:
	var until := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Réponse native terminée")
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await wait_model()
	check(app.bridge.last_response_ok, "Commande native " + id + " · " + str(app.last_error))
func named(node: Node, id: String) -> Node:
	if str(node.name) == id: return node
	for child in node.get_children():
		var result := named(child, id)
		if result != null: return result
	return null
func press(id: String) -> void:
	var button: Button = named(guide, id)
	check(button != null and not button.disabled and button.is_visible_in_tree(), "Contrôle accessible : " + id)
	if button != null and not button.disabled: button.pressed.emit()
	await process_frame
func key_press(code: Key) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new(); event.keycode = code; event.pressed = false
	Input.parse_input_event(event)
	await process_frame
func state_export() -> Dictionary:
	await command("export")
	return JSON.parse_string(app.model.meta.exportText).state
func attach() -> void:
	guide = load("res://guide/coach_guide.gd").new()
	app.add_child(guide)
	guide.reserved_height_changed.connect(func(height: float):
		if is_instance_valid(app.root_content): app.root_content.offset_bottom = -height
	)
	guide.setup(app)
	guide.speech.requested.connect(func(text: String): spoken.append(text))
func profile_cases() -> void:
	var Store = load("res://guide/guide_profile.gd")
	var path: String = app._profile_path().path_join("validation-profile")
	DirAccess.make_dir_recursive_absolute(path)
	var store = Store.new()
	store.load_profile(path)
	var value: Dictionary = store.data.duplicate(true)
	value.step = "composition"; value.muted = true; value.rate = 1.25
	check(store.save_profile(value), "Préférences écrites atomiquement")
	value.step = "tactique"; check(store.save_profile(value), "Remplacement atomique d'un fichier existant")
	var reload = Store.new(); reload.load_profile(path)
	check(reload.data.step == "tactique" and reload.data.muted and reload.data.rate == 1.25, "Progression et préférences relues")
	for invalid in [{"rate":3.0},{"enabled":"true"},{"step":"etape-supprimee"},{"completed":["club","club"]}]:
		var bad: Dictionary = value.duplicate(true); bad.merge(invalid, true)
		check(not store.save_profile(bad), "Préférences mal formées refusées : " + str(invalid.keys()[0]))
	check(reload.data.step == "tactique", "Validation refusée conserve les préférences précédentes")
	var file := FileAccess.open(path.path_join("guide.json"), FileAccess.WRITE)
	file.store_string("{fichier interrompu"); file.close()
	var damaged := FileAccess.get_file_as_bytes(path.path_join("guide.json"))
	var corrupt = Store.new(); corrupt.load_profile(path)
	check(not corrupt.last_error.is_empty() and not corrupt.save_profile(value), "Corruption visible et écriture bloquée")
	check(damaged == FileAccess.get_file_as_bytes(path.path_join("guide.json")), "Fichier corrompu conservé octet pour octet")
	file = FileAccess.open(path.path_join("guide.json"), FileAccess.WRITE)
	file.store_string("x".repeat(65537)); file.close()
	var oversized = Store.new(); oversized.load_profile(path)
	check(not oversized.last_error.is_empty(), "Lecture bornée à 64 Kio")
	var denied = Store.new(); denied.load_profile(path.path_join("guide.json"))
	check(not denied.save_profile(value) and not denied.last_error.is_empty(), "Écriture impossible rapportée sans repli")
func layout_and_capture(id: String) -> void:
	for i in 5: await process_frame
	var rect: Rect2 = guide.get_global_rect()
	if guide.expanded:
		var balloon: Control = guide.find_child("GuideSpeechBalloon", true, false)
		check(balloon != null, "Vraie bulle BD distincte du panneau du coach : " + id)
		if balloon != null:
			check(balloon.is_ancestor_of(guide.bubble), "Texte prononcé contenu dans la bulle : " + id)
			check(balloon.get_tail_points().size() == 3, "Pointe de dialogue vers le portrait : " + id)
			check(balloon.get_global_rect().intersection(rect).size == balloon.size, "Bulle entièrement visible : " + id)
			check(guide.bubble.get_theme_color("font_color").get_luminance() < 0.2, "Encre sombre lisible sur bulle ivoire : " + id)
	print("LAYOUT ", id, " rect=", rect, " min=", guide.get_combined_minimum_size(), " app=", app.size)
	check(rect.position.x >= 0 and rect.end.x <= app.size.x + 1 and rect.end.y <= app.size.y + 1, "Guide dans la fenêtre : " + id)
	for key in (["GuideNext", "GuideClose", "GuideStop", "GuideReplay", "GuideOptions"] if guide.expanded else ["GuideTour", "GuideHelp"]):
		var control: Control = named(guide, key)
		if control.is_visible_in_tree(): # Tolérance de 0,05 px : la mise à l'échelle à 1920 x 1080 laisse 34,0 contre 33,99994 (arrondi flottant), pas un bouton coupé.
			var gap: Vector2 = (control.get_global_rect().intersection(rect).size - control.size).abs()
			check(gap.x <= 0.05 and gap.y <= 0.05, "Bouton non coupé : " + key + " / " + id)
	check(app.root_content.offset_bottom == 0, "Bulle flottante sans espace réservé : " + id)
	check(guide.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Contour du coach traversable à la souris : " + id)
	check(rect.size.x <= 500, "Coach discret de largeur bornée : " + id)
	if guide.expanded and not guide._settings_open:
		check(rect.size.y <= 220, "Coach et bulle sous 220 pixels : " + id)
		var balloon: Control = named(guide, "GuideSpeechBalloon")
		check(balloon.size.x <= 360 and balloon.size.y <= 140, "Petite bulle de lecture : " + id)
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("CD_GUIDE_CAPTURES").path_join(id + ".png")) == OK, "Capture " + id)
func local_voice_cases() -> void:
	check(guide.speech.has_method("load_manifest"), "Lecture locale exacte disponible")
	if not guide.speech.has_method("load_manifest"): return
	var folder: String = app._profile_path().path_join("voice-fixture")
	DirAccess.make_dir_recursive_absolute(folder)
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = 24000
	var pcm := PackedByteArray(); pcm.resize(4800); wav.data = pcm
	check(wav.save_to_wav(folder.path_join("essai.wav")) == OK, "WAV de réception locale créé")
	var exact := "Une bulle, une voix."
	var file := FileAccess.open(folder.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"clips":[{"id":"essai","text":exact,"text_sha256":exact.sha256_text(),"file":"essai.wav"}]})); file.close()
	guide.speech.load_manifest(folder.path_join("manifest.json"))
	check(guide.speech.has_recording(exact) and not guide.speech.has_recording(exact + " suite"), "Clip local lié au texte exact, aucune coupure de fragment")
	var starts: Array[int] = []; var ends: Array[int] = []
	guide.speech.started.connect(func(id: int): starts.append(id))
	guide.speech.ended.connect(func(id: int): ends.append(id))
	guide.speech.speak(exact)
	var deadline := Time.get_ticks_msec() + 3000
	while ends.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(starts.size() == 1 and ends == starts and not guide.portrait.speaking, "Lecture WAV réelle et signaux début/fin identiques")
	guide.speech.speak(exact); guide.speech.stop()
	check(not guide.speech.speaking and not guide.speech.player.playing, "Arrêter coupe le lecteur local")
	guide.speech.set_muted(true); var count := spoken.size(); guide.speech.speak(exact)
	check(not guide.speech.player.playing and spoken.size() == count, "Muet empêche aussi les clips enregistrés")
	guide.speech.set_muted(false); guide.speech.load_manifest()

func tts_real() -> void:
	if guide.speech.voices.is_empty():
		if guide.speech.clips.is_empty():
			check(guide.speech.status_text.begins_with("Mode texte"), "Absence de voix enregistrée et système explicitement annoncée")
		else:
			check(guide.speech.status_text.contains("Gabi") and not guide.speech.status_text.begins_with("Mode texte"), "Les WAV restent disponibles même sans voix système française")
		print("TTS RÉEL NON EXÉCUTÉ : aucune voix française sur ", DisplayServer.get_name())
		return
	var starts: Array[int] = []; var ends: Array[int] = []
	guide.speech.started.connect(func(id: int): starts.append(id))
	guide.speech.ended.connect(func(id: int): ends.append(id))
	var saved_text: String = guide.bubble.text
	guide.bubble.text = "Bonjour."
	await press("GuideReplay")
	var until := Time.get_ticks_msec() + 12000
	while ends.is_empty() and Time.get_ticks_msec() < until: await process_frame
	check(starts.size() == 1 and ends.size() == 1 and starts[0] == ends[0], "Signaux TTS système réels : début puis fin du même identifiant")
	check(not guide.portrait.speaking, "Animation arrêtée après la vraie fin TTS")
	check(spoken.back() == "Bonjour.", "Réécouter lit exactement la bulle")
	print("TTS RÉEL : ", starts.size(), " début ; ", ends.size(), " fin ; voix ", guide.speech.voice_id)
	guide.bubble.text = "Cette phrase de réception doit être interrompue immédiatement par votre commande. ".repeat(4)
	await press("GuideReplay")
	until = Time.get_ticks_msec() + 5000
	while not guide.speech.speaking and Time.get_ticks_msec() < until: await process_frame
	check(guide.speech.speaking and guide.portrait.speaking, "Vrai début vocal anime le portrait")
	await press("GuideStop")
	check(not guide.speech.speaking and not guide.portrait.speaking, "Arrêter coupe parole et animation")
	guide.bubble.text = saved_text
func error_label(node: Node) -> Label:
	if node is Label and node.is_visible_in_tree() and not guide.profile.last_error.is_empty() and node.text.contains(guide.profile.last_error): return node
	for child in node.get_children():
		var found := error_label(child)
		if found != null: return found
	return null
func visible_error(context: String, capture_id: String = "") -> void:
	for i in 3: await process_frame
	var error := error_label(guide)
	check(error != null, "Erreur de disque visible : " + context)
	if error != null:
		check(guide.get_global_rect().intersection(error.get_global_rect()).size == error.size, "Erreur entièrement contenue : " + context)
		check(error.size.y >= error.get_line_height() * error.get_line_count(), "Toutes les lignes d'erreur lisibles : " + context)
	if not capture_id.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OS.get_environment("CD_GUIDE_CAPTURES").path_join(capture_id + ".png")) == OK, "Capture erreur " + capture_id)
func write_error_cases() -> void:
	await command("new_career", {"club":0,"mode":"common"})
	await ContextualFlow.settle_club_meetings(app, self, check)
	root.content_scale_size = Vector2i(1280,800); root.size = Vector2i(1280,800)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(Vector2i(1280,800))
	app._navigate("Bureau"); attach(); guide.open_help(); guide.close()
	var saved_guide: String = guide.profile.directory.path_join("guide.json")
	var guide_bytes := FileAccess.get_file_as_bytes(saved_guide)
	var before: Dictionary = await state_export()
	var career_path: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var career_bytes := FileAccess.get_file_as_bytes(career_path)
	var blocker: String = app._profile_path().path_join("profil-guide-bloque")
	var file := FileAccess.open(blocker, FileAccess.WRITE); file.store_string("Fichier ordinaire : aucun sous-dossier possible."); file.close()
	guide.profile.directory = blocker
	guide.open_help()
	check(not guide.profile.last_error.is_empty() and guide.expanded, "Échec disque réel lors de l'ouverture")
	await visible_error("développé avec Options fermées", "coach-erreur-etendu-1280")
	guide.close(); await visible_error("compact", "coach-erreur-compact-1280")
	guide.open_help(); await press("GuideOptions"); await visible_error("Options ouvertes", "coach-erreur-options-1280")
	await press("GuideDisable")
	check(not guide.profile.data.enabled and not guide.expanded and not guide.speech.speaking, "Désactivation effective pour cette session malgré le refus d'écriture")
	await visible_error("désactivation non persistée", "coach-erreur-desactivation-1280")
	var error := error_label(guide)
	check(error != null and error.text.contains("session") and error.text.contains("prochain démarrage"), "Désactivation non enregistrée expliquée explicitement")
	for i in 10: guide.refresh(); await process_frame
	await visible_error("après dix snapshots sans nouvelle modale")
	check(app.get_children().filter(func(child):return child is AcceptDialog and child.visible).is_empty(), "Aucune modale répétée pour l'erreur")
	guide.open_help(); check(guide.expanded, "Guide toujours utilisable après l'erreur")
	check(guide_bytes == FileAccess.get_file_as_bytes(saved_guide), "Dernier guide enregistré conservé sans repli")
	check(FileAccess.get_file_as_string(blocker) == "Fichier ordinaire : aucun sous-dossier possible.", "Obstacle disque conservé")
	var after: Dictionary = await state_export()
	check(before == after and career_bytes == FileAccess.get_file_as_bytes(career_path), "Erreur et désactivation ne modifient ni carrière ni RNG ni octets")
	guide.destroy(); await process_frame
	# A corrupted file blocks only persistence: the player can still open and silence the guide.
	file = FileAccess.open(saved_guide, FileAccess.WRITE); file.store_string("{guide corrompu"); file.close()
	var corrupt_bytes := FileAccess.get_file_as_bytes(saved_guide)
	attach(); await visible_error("profil corrompu au démarrage compact")
	guide.open_help(); await visible_error("profil corrompu développé")
	check(guide.expanded, "Corruption : utilisation locale possible")
	await press("GuideOptions"); await press("GuideDisable")
	await visible_error("corruption et désactivation pour la session")
	check(not guide.profile.data.enabled and corrupt_bytes == FileAccess.get_file_as_bytes(saved_guide), "Corruption jamais écrasée, désactivation locale possible")
	guide.destroy(); await process_frame
	app.bridge.stop()
	var until := Time.get_ticks_msec() + 4000
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < until: await process_frame
	app.queue_free(); for i in 6: await process_frame
	print("COACH WRITE ERROR : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	check(ResourceLoader.exists("res://guide/coach_guide.gd"), "Contrôleur de guide disponible")
	if not failures.is_empty(): print("COACH RED : contrôleur absent"); quit(1); return
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await wait_model(); app.timer.stop()
	if OS.get_environment("CD_GUIDE_CASE") == "write-error": await write_error_cases(); return
	attach()
	check(not guide.expanded and named(guide, "GuideTour") != null, "Invitation compacte sans ouverture ni parole automatiques")
	await press("GuideTour")
	check(guide.expanded and app.route == "Accueil", "Visite ouverte sans navigation automatique")
	await press("GuideNext")
	check(app.route == "Accueil" and guide.current_id == "bienvenue" and guide.fragment_index == 1, "Suivant parcourt les petites bulles avant la page")
	await press("GuidePrevious")
	check(guide.profile.data.step == "bienvenue", "Précédent revient à l'étape stable")
	await press("GuideOptions"); await press("GuideSkip"); await press("GuideOptions")
	check(guide.profile.data.step == "club", "Passer avance seulement le carnet")
	await press("GuideNavigate")
	check(app.route == "Création", "Navigation seulement après action explicite")
	await command("new_career", {"club":0,"mode":"common"})
	await ContextualFlow.settle_club_meetings(app, self, check)
	app._navigate("Bureau"); guide.refresh()
	var before: Dictionary = await state_export()
	var save_path: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(save_path)
	for route in ["Bureau", "Effectif", "Composition", "Préparation", "Calendrier", "Classements", "Finances", "Recrutement", "Club", "Match", "Packs"]:
		var previous_requests := spoken.size()
		app._navigate(route); guide.refresh(); guide.open_help()
		for i in 3: await process_frame
		check(not guide.bubble.text.is_empty(), "Aide de la vraie route : " + route)
		var count := spoken.size()
		for i in 10: guide.refresh()
		check(spoken.size() == count, "Pas de répétition sur les snapshots : " + route)
		if spoken.size() > previous_requests:
			check(spoken.back() == guide.bubble.text, "Bulle identique à la nouvelle chaîne TTS : " + route)
		else:
			check(guide.speech.voice_id.is_empty() and not guide.speech.has_recording(guide.bubble.text), "Bulle sans enregistrement : aucune ancienne prise réutilisée : " + route)
	var after: Dictionary = await state_export()
	check(before == after, "Guide et navigation préservent intégralement export et RNG moteur")
	check(bytes == FileAccess.get_file_as_bytes(save_path), "Guide : aucun octet de carrière modifié")
	check(not FileAccess.get_file_as_string(save_path).contains("guide.json"), "Progression hors sauvegarde de carrière")
	profile_cases()
	app._navigate("Préparation"); guide.refresh(); guide.open_help()
	app.primary_button.grab_focus()
	var old_focus := root.gui_get_focus_owner()
	guide.close(); guide.open_help()
	check(root.gui_get_focus_owner() == old_focus, "Ouverture explicite conserve le focus de la page")
	await press("GuideOptions")
	var speed: OptionButton = named(guide, "GuideSpeed")
	speed.grab_focus()
	await key_press(KEY_SPACE)
	check(speed.get_popup().visible and guide.expanded, "Menu débit ouvert au clavier sans fermer le guide")
	await key_press(KEY_DOWN); await key_press(KEY_ENTER)
	check(not speed.get_popup().visible and guide.expanded, "Choix du débit au clavier conserve l'aide")
	check(guide.speech.rate == 1.25 and guide.profile.data.rate == 1.25, "Choix de débit appliqué et enregistré")
	var voice: OptionButton = named(guide, "GuideVoice")
	check(voice.visible != guide.speech.has_complete_recordings(), "La voix système de secours n'est proposée que si les prises locales sont incomplètes")
	if voice.visible and not voice.disabled:
		var previous_voice := voice.selected
		var expected_voice := (previous_voice + 1) % voice.item_count
		voice.grab_focus(); await key_press(KEY_SPACE)
		check(voice.get_popup().visible and guide.expanded, "Menu voix ouvert au clavier sans fermer le guide")
		await key_press(KEY_DOWN); await key_press(KEY_ENTER)
		check(voice.selected == expected_voice and guide.speech.voice_id == str(guide.speech.voices[expected_voice].id) and guide.profile.data.voice == guide.speech.voice_id, "Voix choisie au clavier appliquée et enregistrée")
		voice.grab_focus(); await key_press(KEY_SPACE); await key_press(KEY_UP); await key_press(KEY_ENTER)
		check(voice.selected == previous_voice, "Retour à la voix française initiale par le clavier")
	await press("GuideMute"); check(guide.profile.data.muted and not guide.speech.speaking, "Muet arrête immédiatement")
	await press("GuideMute")
	await press("GuideOptions")
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://guide/assets/coach-poses.png"))
	check(image.get_size() == Vector2i(1254,1254) and guide.portrait.frame_texture.region.size == Vector2(313.5,313.5) and guide.portrait.material is ShaderMaterial, "Atlas original seize poses, cellules exactes et détourage matériel")
	guide.speech.stop()
	guide.portrait.set_articulation(-1.0) # Explicit cosmetic fallback, not a silent PCM clip.
	guide.portrait.set_speaking(true)
	var first: Rect2 = guide.portrait.frame_texture.region
	var portrait_position: Vector2 = guide.portrait.position
	await create_timer(0.21).timeout
	check(first != guide.portrait.frame_texture.region, "Cadence de secours : changement réel de frame atlas")
	check(guide.portrait.position == portrait_position, "Portrait stable sans flottement")
	guide.portrait.set_speaking(false)
	check(guide.portrait.pose_index == guide.portrait._rest, "Fin de parole : pose repos")
	app.waiting = true; guide.refresh()
	check(not guide.expanded and not guide.speech.speaking, "Commande en attente : aide réduite et parole arrêtée")
	app.waiting = false
	guide.open_help()
	var dialog := ConfirmationDialog.new(); app.add_child(dialog); dialog.popup_centered(Vector2i(400,160))
	await process_frame
	var dialog_focus := dialog.gui_get_focus_owner()
	guide.refresh()
	check(not guide.expanded and not guide.speech.speaking, "Dialogue : aucune parole ou focus pris par le guide")
	check(dialog_focus != null and dialog.gui_get_focus_owner() == dialog_focus, "Focus de confirmation conservé")
	dialog.hide(); dialog.queue_free(); await process_frame
	# Calendrier quotidien : le coup d'envoi n'est ouvert que le jour du match, après les rendez-vous du club.
	if not await ContextualFlow.prepare_match_day(app, self, check): quit(1); return
	var previous_week: int = int(app.model.get("meta", {}).get("week", -1))
	app._navigate("Match")
	app.coach = guide
	await command("begin_match")
	await process_frame
	check(app.contextual_director.kind == "locker" and not guide.is_visible_in_tree() and not app.root_content.is_visible_in_tree(), "Avant-match : causerie immersive, guide et gestion masqués")
	await ContextualFlow.skip_talk(app, self, "pre", check)
	guide.refresh(); guide.open_help()
	await process_frame
	check(not guide.expanded and not guide.is_visible_in_tree(), "Direct : ouverture du guide refusée et guide masqué")
	await command("pause", {"paused":true})
	await process_frame
	check(app.contextual_director.kind == "live" and not guide.is_visible_in_tree() and not app.root_content.is_visible_in_tree(), "Match en pause : immersion conservée sans guide ni menus de gestion")
	await command("delegate")
	await process_frame
	check(app.model.live.finished and not guide.is_visible_in_tree() and not app.root_content.is_visible_in_tree(), "Résultat délégué : immersion conservée jusqu’à validation")
	await command("finish_round")
	await ContextualFlow.finish_match_week(app, self, check, previous_week)
	await ContextualFlow.settle_club_meetings(app, self, check)
	app.coach = null
	app._navigate("Bureau"); guide.refresh(); guide.open_help()
	await local_voice_cases()
	await tts_real()
	for resolution in [Vector2i(1280,800),Vector2i(1440,900),Vector2i(1920,1080)]:
		root.content_scale_size = resolution
		root.size = resolution
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution)
		guide.open_help()
		if resolution.x == 1440: await layout_and_capture("coach-1440-texte-normal")
		guide.bubble.text = guide.bubble.text.repeat(8)
		await layout_and_capture("coach-" + str(resolution.x) + "-etendu-long")
		if resolution.x == 1280:
			await press("GuideOptions")
			await layout_and_capture("coach-1280-options")
			for key in ["GuideVoice", "GuideSpeed", "GuideMute", "GuideDisable"]:
				var control: Control = named(guide, key)
				check(guide.get_global_rect().intersection(control.get_global_rect()).size == control.size, "Option non coupée à 1280 : " + key)
			await press("GuideOptions")
		await press("GuideClose")
		await layout_and_capture("coach-" + str(resolution.x) + "-compact")
	guide.open_tour(); await press("GuideNext")
	var resume_step: String = guide.profile.data.step
	guide.destroy(); await process_frame
	attach()
	check(guide.profile.data.step == resume_step and not guide.expanded, "Redémarrage reprend l'étape stable sans parler")
	guide.open_tour()
	while guide.expanded: await press("GuideNext")
	check(guide.profile.data.completed.size() == 15, "Visite complète de quinze étapes, terminée sans naviguer")
	guide.open_help(); await press("GuideOptions"); await press("GuideDisable")
	check(not guide.visible and guide.profile.data.enabled == false, "Guide désactivable")
	guide.toggle(); check(guide.visible and guide.expanded, "Réactivation explicite possible")
	guide.destroy(); await process_frame
	check(not DisplayServer.tts_is_speaking(), "Nettoyage : aucune parole orpheline")
	print("COACH GREEN : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.bridge.stop()
	var until := Time.get_ticks_msec() + 4000
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < until: await process_frame
	app.queue_free()
	for i in 6: await process_frame
	quit(0 if failures.is_empty() else 1)
