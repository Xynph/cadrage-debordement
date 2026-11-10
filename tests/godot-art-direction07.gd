extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
## Catches unreadable light controls, clipped navigation and presentation writes.
var app: Control
var checks := 0
var failures: Array[String] = []
var proof := OS.get_environment("CD_ART07_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: " + message)
func settle() -> void:
	await create_timer(.12).timeout
	for i in 8: await process_frame
func worker() -> void:
	var limit := Time.get_ticks_msec()+30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<limit: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Worker répond")
	app.timer.stop(); await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id,payload); await worker()
	check(app.bridge.last_response_ok,"Worker réel " + id+" "+app.last_error)
func contrast(a: Color,b: Color) -> float:
	var first := a.srgb_to_linear().get_luminance()
	var second := b.srgb_to_linear().get_luminance()
	return (maxf(first,second)+.05)/(minf(first,second)+.05)
func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size()==root.size,"Capture physique "+id)
	check(image.save_png(proof.path_join(id+".png"))==OK,"Capture enregistrée "+id)
func run() -> void:
	root.size=Vector2i(2560,1440);DisplayServer.window_set_size(root.size)
	app=load("res://main.tscn").instantiate();root.add_child(app);await worker()
	await command("import",{"text":FileAccess.get_file_as_string(proof.path_join("career.json"))})
	await ContextualFlow.settle_club_meetings(app, self, check)
	await command("export")
	var before: String=app.model.meta.exportText
	var disk := OS.get_environment("CD_GODOT_DATA_DIR").path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(disk)
	var paper:Theme=load("res://theme.gd").paper()
	for kind in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed"]:
			var style:StyleBoxFlat=paper.get_stylebox(state,kind)
			var ink:Color=paper.get_color("font_color" if state=="normal" else "font_"+state+"_color",kind)
			check(contrast(ink,style.bg_color)>=4.5,"Contraste de lecture "+kind+" "+state)
		check(paper.get_stylebox("normal",kind).bg_color.get_luminance()>.75,"Commande claire distincte de l'ancien bloc gris "+kind)
		var focus:StyleBoxFlat=paper.get_stylebox("focus",kind)
		check(focus.border_width_left>=2 and contrast(focus.border_color,paper.get_stylebox("normal",kind).bg_color)>=3,"Focus visible "+kind)
	for primary in [false,true]:
		var action:Button=load("res://ui/carnet_skin.gd").button("Action",func():pass,primary)
		var focus:StyleBoxFlat=action.get_theme_stylebox("focus")
		check(contrast(focus.border_color,action.get_theme_stylebox("normal").bg_color)>=3,"Focus action carnet "+str(primary))
		action.free()
	var sizes := [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(1600,900),Vector2i(1280,720)]
	if OS.get_environment("CD_ART07_SPIKE")=="1": sizes=[Vector2i(2560,1440)]
	for resolution in sizes:
		root.size=resolution;DisplayServer.window_set_size(resolution);await settle()
		for page in ["Bureau","Effectif","Composition","Préparation","Plan de jeu","Club","Finances","Classements","Calendrier","Carrière"]:
			app._navigate(page);await settle();app.coach.close();await settle()
			check(root.content_scale_size==resolution and app.size==Vector2(resolution),"Canvas natif "+page+" "+str(resolution))
			check(app.heading.get_theme_font_size("font_size")<=20,"Titre dense "+page)
			if page=="Effectif":
				var choice:OptionButton=app.find_child("RosterFamily",true,false)
				var choice_style:StyleBoxFlat=choice.get_theme_stylebox("normal")
				check(choice_style.bg_color.get_luminance()>.75 and contrast(choice.get_theme_color("font_color"),choice_style.bg_color)>=4.5,"Sélecteur réel habillé avant son insertion dans le carnet")
			var rail:Control=app.find_child("CareerRail",true,false)
			check(rail!=null and rail.size.x<=196,"Rail compact "+page)
			for chapter:Dictionary in app.NAV_CHAPTERS:
				var button:Button=app.find_child("Chapter_"+str(chapter.label),true,false)
				check(button!=null and button.size.y<=30 and button.get_global_rect().end.x<=200,"Navigation compacte "+str(chapter.label))
				if button!=null:
					check(button.has_meta("art_icon"),"Pictogramme de chapitre "+str(chapter.label))
					var style:StyleBoxFlat=button.get_theme_stylebox("normal")
					if page in chapter.routes: check(style.border_width_left>=3,"Sélection géométrique persistante "+page)
			var header:Control=app.find_child("CareerHeader",true,false)
			check(header!=null and header.size.y<=80,"Bandeau éditorial compact "+page)
			await capture(page.to_lower().replace("é","e").replace("è","e").replace(" ","-")+"-"+str(resolution.x))
	await command("export")
	check(app.model.meta.exportText==before,"Navigation et habillage conservent export/RNG/horloge")
	check(FileAccess.get_file_as_bytes(disk)==bytes,"Navigation et habillage conservent profil disque")
	# A second real club exercises the coloured identity after the grey club.
	await command("new_career",{"club":0,"mode":"common"})
	await ContextualFlow.settle_club_meetings(app, self, check)
	root.size=Vector2i(2560,1440);DisplayServer.window_set_size(root.size);await settle()
	for page in ["Bureau","Effectif","Finances"]:
		app._navigate(page);await settle();app.coach.close();await settle()
		await capture("toulouse-"+page.to_lower()+"-2560")
	if OS.get_environment("CD_ART07_MATCHES")=="1":
		# Visual review of a trend from actual results, never invented chart data.
		for week in 2:
			for action in ["begin_match","delegate","finish_round"]:await command(action)
			await ContextualFlow.settle_club_meetings(app, self, check)
		app._navigate("Bureau");await settle();app.coach.close();await settle()
		await capture("toulouse-bureau-deux-matchs-2560")
	var report:Dictionary={"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"proof":proof}
	FileAccess.open(proof.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ART_DIRECTION07 ",JSON.stringify(report))
	app.closing=true;app.bridge.stop();app.queue_free();await create_timer(.2).timeout
	quit(0 if failures.is_empty() else 1)
