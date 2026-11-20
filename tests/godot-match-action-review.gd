extends SceneTree
var app: Control
var failures: Array[String] = []
var checks := 0
var journal: Control
var proof := OS.get_environment("CD_ACTION_REVIEW_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("FAIL: "+message)
func settle() -> void:
	for i in 8: await process_frame
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id,payload)
	var deadline := Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok,"Commande "+id)
	await settle()
func key(control: Control) -> void:
	control.grab_focus()
	await settle()
	check(control.has_focus(),"Focus clavier "+str(control.name))
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode=KEY_ENTER
		event.pressed=down
		Input.parse_input_event(event)
		await process_frame
	await settle()
## Écran 13 (DA du 19/11/2026) : dans le direct, « Relire » ouvre une page du direct (« ← Retour au direct »),
## jamais une fenêtre. Ouvre la relecture au clavier et rend l'objet qui la pilote (faits, sélection, terrain).
var surface: Node
func page() -> Control:
	return surface.get("page") if surface != null else null
func ouvrir() -> Object:
	if not journal.is_visible_in_tree():
		surface._toggle_drawer("Journal")
		await settle()
	await key(journal.review)
	while app.waiting: await process_frame
	await settle()
	var contenu: Control = page().find_child("ActionReviewPage", true, false) if page() != null else null
	return contenu.get_meta("relecture") if contenu != null else null
func fermer() -> void:
	var retour: Control = page().find_child("MatchPageBack", true, false) if page() != null else null
	check(retour != null and retour.is_visible_in_tree() and str(retour.text).contains("Retour au direct"), "« ← Retour au direct » visible")
	if retour != null: await key(retour)
	while app.waiting: await process_frame
	await settle()
func run() -> void:
	app=load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec()+30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	app.timer.stop()
	await command("import",{"text":FileAccess.get_file_as_string(proof.path_join("live.json"))})
	app.timer.stop()
	app._navigate("Match")
	await settle()
	# Le direct est la vue contextuelle du match : le journal s'ouvre dans son tiroir.
	var director: Node = app.contextual_director
	surface = director.view if is_instance_valid(director) and director.active() and director.kind == "live" else null
	check(surface != null and surface.has_method("_toggle_drawer") and surface.has_method("ouvrir_relecture"), "Direct contextuel ouvert")
	if surface != null and surface.drawer_tab != "Journal":
		surface._toggle_drawer("Journal")
	await settle()
	journal=surface.journal if surface != null else null
	check(journal!=null,"Journal présent")
	var model_before := JSON.stringify(app.model)
	var disk_path := OS.get_environment("CD_GODOT_DATA_DIR").path_join("donnees.json")
	var disk_before := FileAccess.get_file_as_bytes(disk_path)
	var original: Dictionary = app.model.live.duplicate(true)
	check(journal.review!=null and not journal.review.disabled,"Entrée Relire raccordée")
	var dialog: Object = await ouvrir()
	check(dialog!=null and page().visible and app.find_children("*","Window",true,false).filter(func(w: Window): return w.visible).is_empty(),"Ouverture réelle par clavier, dans une page du direct (aucune fenêtre)")
	if dialog!=null:
		# La case « Moments clés uniquement » porte le style de la charte (carré ivoire dessiné), pas l'interrupteur du moteur.
		check(dialog.keys_only.has_theme_icon_override("unchecked") and dialog.keys_only.has_theme_icon_override("checked") and dialog.keys_only.has_theme_stylebox_override("normal"),"Case « Moments clés uniquement » : style de la charte")
		# #596 : le journal n'affiche que les faits déjà montrés (rien d'un temps fort à venir, le moteur a
		# une minute d'avance, cf. match_temps_forts.montre) : préfixe non vide, copié sans changement.
		check(dialog.events.size()>0 and dialog.events.size()<=original.events.size() and dialog.events==original.events.slice(0,dialog.events.size()),"Faits réels du worker copiés sans changement")
		check(dialog.selection.size()==dialog.events.size(),"Tous les événements consultables")
		var last: int = dialog.index
		if last>0:
			await key(dialog.previous)
			check(dialog.index==last-1,"Navigation arrière clavier")
			await key(dialog.next)
			check(dialog.index==last,"Navigation avant clavier")
		var frozen := JSON.stringify(dialog.events)
		journal.update_frame({"events":[],"teams":[]})
		check(JSON.stringify(dialog.events)==frozen,"Instantané figé quand le direct évolue")
		check(journal.review.disabled,"Entrée désactivée si journal vide")
		await key(dialog.keys_only)
		check(dialog.selection.all(func(i): return dialog.events[i] is Dictionary and dialog.events[i].get("scene",{}).get("kind","") in dialog.KEY_KINDS),"Moments clés issus des métadonnées")
		for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
			root.size=resolution
			DisplayServer.window_set_size(resolution)
			await settle()
			var zone: Rect2 = dialog.content_scroll.get_global_rect()
			check(zone.position.x>=0 and zone.end.x<=app.size.x+1 and zone.end.y<=app.size.y+1,"Page de relecture contenue "+str(resolution))
			check(page().find_child("MatchPageBack",true,false).is_visible_in_tree(),"Retour visible "+str(resolution))
			if OS.get_environment("CD_ACTION_REVIEW_GRAPHICS")=="1":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(proof.path_join("review-%dx%d.png" % [resolution.x,resolution.y]))
		await fermer()
		check(not is_instance_valid(dialog) and not page().visible,"Fermeture libère le lecteur et rend le direct")
	if not journal.is_visible_in_tree(): surface._toggle_drawer("Journal")
	await settle()
	journal.update_frame({"teams":[],"events":["Essai ancien non typé",{"min":12,"text":"Faux essai textuel","scene":{"kind":"message","from":{"x":-10,"y":30},"to":{"x":20,"y":30}}},{"min":15,"text":"Essai réel","scene":{"kind":"try","score":[5,0],"team":0,"from":{"x":95,"y":30},"to":{"x":100,"y":32}}}]})
	await settle()
	dialog = await ouvrir()
	check(dialog.pitch.from=={"x":95,"y":30} and dialog.pitch.to=={"x":100,"y":32},"Positions enregistrées exactes")
	await key(dialog.previous)
	check(dialog.pitch.from==null and dialog.coordinates.text=="Position non renseignée.","Coordonnée hors terrain non inventée")
	await key(dialog.previous)
	check(dialog.heading.text.contains("Minute non renseignée") and dialog.heading.text.contains("Type non renseigné"),"Faits anciens sans métadonnées explicites")
	await key(dialog.keys_only)
	check(dialog.selection.size()==1 and dialog.action.text=="Essai réel","Texte ancien non classé comme essai")
	check(JSON.stringify(app.model)==model_before,"Aucune mutation du modèle/horloge/RNG de carrière")
	check(FileAccess.get_file_as_bytes(disk_path)==disk_before,"Profil disque strictement inchangé")
	await fermer()
	surface._toggle_drawer("Journal")
	await settle()
	journal.update_frame({"teams":[],"events":["Essai ancien non typé"]})
	await settle()
	dialog = await ouvrir()
	await key(dialog.keys_only)
	check(dialog.selection.is_empty() and dialog.heading.text.contains("Aucun moment clé"),"Filtre vide explicite")
	check(dialog.previous.disabled and dialog.next.disabled,"Aucune navigation impossible")
	app.management_ui = {}
	journal.update_frame(original)
	await settle()
	check(not is_instance_valid(dialog) and not page().visible,"Changement de contexte ferme les faits de l’ancienne carrière")
	surface._toggle_drawer("Journal")
	await settle()
	journal.update_frame(original)
	await settle()
	dialog = await ouvrir()
	# Pendant le direct, le match garde la main (immersion) : la navigation est refusée et la
	# relecture reste celle du match en cours, jusqu'à sa fermeture.
	app._navigate("Bureau")
	await settle()
	check(app.route == "Match" and is_instance_valid(dialog) and dialog.events == original.events, "Navigation refusée pendant le direct, relecture du match conservée")
	if is_instance_valid(dialog): await fermer()
	check(not is_instance_valid(dialog),"Fermeture libère la relecture")
	FileAccess.open(proof.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("Action review: %d checks, %d failures" % [checks,failures.size()])
	app.bridge.stop()
	app.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)