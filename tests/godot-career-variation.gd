extends SceneTree
const Entry = preload("res://ui/entry_screens.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_VARIATION_UI_OUTPUT")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 12: await process_frame
func response() -> void:
	var deadline := Time.get_ticks_msec()+90000
	while app.waiting and Time.get_ticks_msec()<deadline: await process_frame
	await settle()
	check(not app.waiting and app.bridge.last_response_ok,"Réponse du vrai moteur : "+app.last_error)
func key(button: BaseButton, code: Key=KEY_SPACE) -> void:
	button.grab_focus(); await settle()
	var event := InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=true
	Input.parse_input_event(event); await process_frame
	event=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=false
	Input.parse_input_event(event); await settle()
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"Capture "+name)
func run() -> void:
	root.size=Vector2i(2560,1440)
	app=load("res://main.tscn").instantiate(); root.add_child(app)
	var deadline := Time.get_ticks_msec()+90000
	while app.model.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.model.is_empty(),"Application et catalogue réels prêts")
	app.timer.stop()
	var serial: int=app.bridge._next_id
	Entry.begin_creation(app); await settle()
	var option := app.find_child("CreationVaryCurrent",true,false) as CheckBox
	check(option!=null and option.button_pressed,"Niveau variable coché par défaut")
	check(option.text=="Faire légèrement varier le niveau actuel","Libellé explicite")
	await key(option)
	check(not option.button_pressed and app.management_ui.creation_vary_current==false,"Espace décoche réellement la case")
	var clubs := app.find_child("CreationClubGrid",true,false) as GridContainer
	check(clubs!=null and clubs.get_child_count()>0,"Vrais clubs disponibles")
	var first := clubs.get_child(0) as Button
	await key(first)
	option=app.find_child("CreationVaryCurrent",true,false)
	check(not option.button_pressed,"Choisir le club conserve l’option décochée")
	check(app.bridge._next_id==serial,"Case et choix de club ne commandent ni sauvegarde ni génération")
	check(app.find_child("CreationVaryPotential",true,false)==null,"Aucun interrupteur du potentiel")
	var start := app.find_child("CreationStart",true,false) as Button
	check(start!=null and not start.disabled,"Création explicite disponible après sélection")
	await capture("creation-variation-niveau-desactive-1440")
	await key(start); await response()
	check(app.model.meta.careerVariation.version==1 and app.model.meta.careerVariation.varyCurrent==false,"Commande de création conserve réellement l’option et le manifeste")
	check(app.bridge._next_id==serial+1,"Une seule commande explicite crée la carrière")
	var profile := str(app.model.meta.dataDir).path_join("donnees.json")
	var before := FileAccess.get_sha256(profile)
	serial=app.bridge._next_id
	Entry.begin_creation(app); await settle()
	option=app.find_child("CreationVaryCurrent",true,false)
	check(option.button_pressed,"Une nouvelle ouverture remet le défaut coché")
	check(FileAccess.get_sha256(profile)==before and app.bridge._next_id==serial,"Ouvrir l’écran suivant préserve la carrière existante")
	await capture("creation-variation-active-par-defaut-1440")
	# The legacy creation presentation uses the same control and payload contract.
	app.pack_manager.creation_mode="common"; app._render(); await settle()
	option=app.find_child("CreationVaryCurrent",true,false)
	check(option!=null and option.button_pressed,"Présentation classique conserve le défaut")
	var editor := preload("res://ui/competition_editor_view.gd").open(app)
	editor._playable_template(); await response()
	check(editor.preview.get("launch",{}).get("playable",false),"Vrai calendrier fictif jouable validé")
	editor._launch(); await settle()
	var confirmation := editor.find_child("CustomCompetitionConfirmation",true,false) as ConfirmationDialog
	var custom_option := confirmation.find_child("CustomCreationVaryCurrent",true,false) as CheckBox
	check(custom_option!=null and custom_option.button_pressed,"Atelier : niveau variable coché par défaut")
	before=FileAccess.get_sha256(profile); serial=app.bridge._next_id
	await key(custom_option)
	check(not custom_option.button_pressed,"Atelier : Espace décoche la case")
	check(FileAccess.get_sha256(profile)==before and app.bridge._next_id==serial,"Atelier : choisir l’option ne modifie pas la carrière")
	await capture("creation-fictive-variation-1440")
	confirmation.canceled.emit(); await settle()
	editor._launch(); await settle()
	confirmation=editor.find_child("CustomCompetitionConfirmation",true,false)
	custom_option=confirmation.find_child("CustomCreationVaryCurrent",true,false)
	check(custom_option.button_pressed,"Atelier : nouvelle confirmation remet le défaut coché")
	await key(custom_option)
	await key(confirmation.get_ok_button()); await response()
	check(app.model.meta.careerVariation.varyCurrent==false,"Atelier : vraie création conserve le choix décoché")
	check(app.bridge._next_id==serial+1,"Atelier : une seule commande explicite crée la carrière fictive")
	var result := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	result.store_string(JSON.stringify({"checks":checks,"failures":failures,"resolution":[2560,1440],"display":DisplayServer.get_name()},"  ")); result.close()
	print("VARIATION CRÉATION : %d contrôles ; %d échecs" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
