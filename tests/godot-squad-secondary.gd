extends SceneTree
const Squad = preload("res://ui/immersive08/squad_canvas.gd")
const U = preload("res://ui/management_state.gd")
const C = preload("res://ui/immersive08/components.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_SQUAD_SECONDARY_OUTPUT")
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value:failures.append(message);printerr("FAIL: ",message)
func settle() -> void:
	for frame in 8:await process_frame
func pure() -> void:
	var player := {"secondaryPositions":[14,11,11,0,16,4.5,null,"12"]}
	var before := JSON.stringify(player)
	check(Squad.secondary_numbers(player)==[11,14],"Numéros publiés normalisés sans changer leur source")
	check(JSON.stringify(player)==before,"Aucune mutation de la liste fournie")
	check(Squad.secondary_caption(player)=="11·14","Deux postes distincts restent explicites")
	check(Squad.secondary_caption({"secondaryPositions":[11,14,15]})=="11·14·15","Aucun intervalle inventé entre des numéros disjoints")
	check(Squad.secondary_caption({"secondaryPositions":[11,12,13,14,15]})=="11–15","Intervalle limité à une séquence complète exacte")
	check(Squad.secondary_caption({})=="—" and Squad.secondary_caption({"secondaryPositions":[]})=="—","Valeur absente ou vide : tiret neutre")
	var labels := {"selection":{"slots":[{"slot":10,"label":"Ailier gauche"},{"slot":13,"label":"Ailier droit"}]}}
	var tip := Squad.secondary_tooltip({"secondaryPositions":[11,14]},labels)
	check(tip.contains("11 · Ailier gauche") and tip.contains("14 · Ailier droit"),"Noms repris des étiquettes de la feuille")
	check(not tip.to_lower().contains("estim"),"Aucune étiquette d’estimation dans les nouveaux textes")
	var source := [{"id":"b","name":"b","pos":"Centre","secondaryPositions":[11]},{"id":"u","name":"u","pos":"Centre","secondaryPositions":[]},{"id":"a","name":"a","pos":"Centre","secondaryPositions":[11]},{"id":"c","name":"c","pos":"Centre","secondaryPositions":[2,14]}]
	var state := U.defaults();state.sort="Autres postes"
	check(Squad.ordered_players(source,state,1).map(func(p:Dictionary):return p.id)==["c","a","b","u"],"Tri numérique : 2 avant 11, égalités ID, vide en dernier")
	state.descending=true
	check(Squad.ordered_players(source,state,1).map(func(p:Dictionary):return p.id)==["a","b","c","u"],"Sens inverse et vide toujours dernier")
func wait_engine() -> void:
	var deadline:=Time.get_ticks_msec()+60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<deadline:await process_frame
	check(not app.waiting and app.bridge.last_response_ok,"Vraie réponse du moteur : "+app.last_error)
	await settle()
func page() -> Control:return app.find_child("CarnetSquad",true,false)
func key(code: Key) -> void:
	for down: bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.pressed=down;Input.parse_input_event(event);await process_frame
	await settle()
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().get_size()==Vector2i(2560,1440),"Capture native 1440")
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"Capture "+name)
func run() -> void:
	pure()
	var worker:=OS.get_environment("CD_SQUAD_SECONDARY_WORKER")
	if not worker.is_empty():ProjectSettings.set_setting("native_engine/worker_path",worker)
	root.size=Vector2i(2560,1440)
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(root.size)
	app=load("res://main.tscn").instantiate();root.add_child(app);await wait_engine()
	app._command("new_career",{"mode":"common","club":29});await wait_engine();app.timer.stop()
	var original: Dictionary=app.model.duplicate(true)
	var source_count:=0
	for player:Dictionary in original.squad:
		if not Squad.secondary_numbers(player).is_empty():source_count+=1
	if OS.get_environment("CD_SQUAD_SECONDARY_REQUIRE_MODEL")=="1":check(source_count>0,"Le vrai modèle projette des autres postes")
	var file:=str(original.meta.dataDir).path_join("donnees.json")
	var hash:=FileAccess.get_sha256(file)
	var commands: int=app.bridge._next_id
	app._navigate("Effectif");await settle()
	var primary_header:=app.find_child("RosterColumn_POSTE",true,false) as Label
	var secondary_header:=app.find_child("RosterColumnSecondaryPositions",true,false) as Label
	check(primary_header!=null and primary_header.text.begins_with("POSTE PRINCIPAL"),"Poste principal explicite")
	check(secondary_header!=null and secondary_header.text.begins_with("AUTRES"),"Autres postes dans une colonne distincte")
	check(app.find_child("Sort_Poste",true,false)!=null and app.find_child("Sort_Autres postes",true,false)!=null,"Deux en-têtes triables, ancien identifiant conservé")
	var items: Array=page().rows.get_children().filter(func(node:Node):return node is Button and node.has_meta("player_id"))
	check(items.size()==original.squad.size(),"Toutes les lignes sont conservées sans pagination")
	for item:Control in items:
		var principal:=item.find_child("RosterPrimaryPosition",true,false) as Label
		var secondary:=item.find_child("RosterSecondaryPositions",true,false) as Label
		var id:=str(item.get_meta("player_id"))
		var person:Dictionary=original.squad.filter(func(player:Dictionary):return str(player.id)==id)[0]
		check(principal.text==person.pos,"Principal reste le texte publié : "+id)
		check(secondary.text==Squad.secondary_caption(person),"Autres reprennent seulement les numéros projetés : "+id)
		check(principal.get_rect().end.x<=secondary.get_rect().position.x and secondary.get_rect().end.x<=568*C.density,"Colonnes contenues avant l’âge : "+id)
		check(secondary.mouse_filter==Control.MOUSE_FILTER_PASS,"Survol et clic de ligne compatibles")
	await capture("effectif-postes-modele-reel-1440" if source_count>0 else "effectif-postes-ancienne-projection-1440")
	if source_count>0 and DisplayServer.get_name()!="headless":
		for item:Control in items:
			var other:=item.find_child("RosterSecondaryPositions",true,false) as Label
			if other.text=="—":continue
			var scroll:=app.find_child("SquadScroll",true,false) as ScrollContainer
			scroll.ensure_control_visible(item);await settle()
			var motion:=InputEventMouseMotion.new()
			motion.position=other.get_global_rect().get_center();motion.global_position=motion.position
			root.push_input(motion,true)
			await create_timer(0.85).timeout
			await capture("effectif-postes-survol-1440")
			break
	var sort:=app.find_child("Sort_Autres postes",true,false) as Button
	sort.grab_focus();await key(KEY_ENTER);var first_direction: bool=page().state.descending;await key(KEY_ENTER)
	check(page().state.sort=="Autres postes" and page().state.descending!=first_direction and sort.has_focus(),"Clavier inverse le tri et garde le focus")
	var controlled:=original.duplicate(true)
	var backs: Array=controlled.squad.filter(func(player:Dictionary):return float(player.get("fam",0))>=4)
	backs[0].secondaryPositions=[11,14]
	backs[1].secondaryPositions=[11,12,13,14,15]
	backs[2].secondaryPositions=[]
	app.model=controlled;app._navigate("Effectif");await settle()
	var id0:=str(backs[0].id)
	var sample:=page().rows.get_children().filter(func(node:Node):return str(node.get_meta("player_id",""))==id0)[0] as Control
	check(sample.find_child("RosterSecondaryPositions",true,false).text=="11·14","Cas UI contrôlé distinct, sans formule locale")
	var marker:=PanelContainer.new()
	marker.z_index=1000
	marker.position=Vector2(790,9)
	marker.add_theme_stylebox_override("panel",C.box(Color("412d19"),C.GOLD,4,7))
	marker.add_child(C.label("CAS UI DE RECETTE · DONNÉES CONTRÔLÉES",18,C.GOLD,true,700))
	root.add_child(marker)
	await capture("effectif-postes-cas-controle-1440")
	marker.queue_free();await settle()
	app.model=original
	check(app.bridge._next_id==commands and FileAccess.get_sha256(file)==hash,"Consultation et tri sans commande ni écriture sportive")
	var report:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"model_players_with_secondary":source_count,"worker":worker,"profile_unchanged":FileAccess.get_sha256(file)==hash},"  "));report.close()
	print("EFFECTIF AUTRES POSTES : %d contrôles ; %d échecs ; %d profils natifs avec autres postes" % [checks,failures.size(),source_count])
	await app._close(0 if failures.is_empty() else 1)
