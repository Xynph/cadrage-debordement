extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Office = preload("res://ui/immersive08/office.gd")
const P = preload("res://ui/immersive08/projection.gd")
const C = preload("res://ui/immersive08/components.gd")
const Legacy = preload("res://ui/office_view.gd")
var app: Control
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty(): quit(2); return
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 8: await process_frame
func wait_model(id: String) -> void:
	var deadline := Time.get_ticks_msec()+30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	app.timer.stop()
	check(not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok,"Réponse du vrai moteur " + id + " · " + app.last_error)
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	print("SDK_COMMAND ",Time.get_ticks_msec()," godot-office-ui ",id)
	var accepted: bool=app._command(id,payload)
	check(accepted,"Commande publique " + id)
	if not accepted:return
	await wait_model(id)
func named(id: String) -> Node: return app.find_child(id,true,false)
func texts(node: Node) -> String:
	if node == null: return ""
	var result: String = str(node.text)+"\n" if node is Label or node is Button else ""
	for child in node.get_children(): result += texts(child)
	return result
func render() -> void:
	app._navigate("Bureau"); await settle()
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("CD_OFFICE_CAPTURES").path_join(label+".png"))==OK,"Capture "+label)
func press(id: String, route: String) -> void:
	var control := named(id) as Button
	check(control!=null and not control.disabled and control.is_visible_in_tree(),"Action réelle disponible : "+id)
	if control==null or control.disabled: return
	control.grab_focus(); await settle()
	check(control.has_focus(),"Focus clavier : "+id)
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=down;Input.parse_input_event(event);await process_frame
	await settle()
	check(app.route==route,"Navigation réelle "+id+" → "+route)
func export_state() -> String:
	await command("export"); return app.model.meta.exportText
func sections() -> void:
	check(named("ImmersiveOffice")!=null,"Le Bureau utilise le canevas de carrière actuel")
	for id in ["OfficeFixture","OfficeDecisions","OfficeGroup","OfficeStandings","OfficeJournal","OfficeRecruitment","OfficeTimeline"]:
		check(named(id)!=null,"Section réelle disponible : "+id)
	var tasks:=Office.priorities(app.model)
	for index in tasks.size():
		var action:=named(tasks[index].id) as Button
		check(action!=null and action.get_meta("priority_number",0)==index+1,"Priorité issue du modèle et numérotée")
		if action!=null: check(action.tooltip_text.contains(Office.priority_description(tasks[index])),"Conditions utiles conservées dans la priorité")
	var standings: Array=P.standings(app.model)
	check(not standings.is_empty() and standings.any(func(row: Dictionary):return row.id==app.model.club.id),"Le classement visible inclut le vrai club")
	var market: Dictionary=Office.recruitment_spotlight(app.model).player
	if not market.is_empty(): check(texts(named("OfficeRecruitment")).contains(str(market.name).to_upper()),"Le profil à suivre est issu du marché publié")
	var next: Variant=app.model.get("next")
	if next is Dictionary:
		check(texts(named("OfficeFixture")).contains(str(next.home.presentation.name).to_upper()) and texts(named("OfficeFixture")).contains(str(next.away.presentation.name).to_upper()),"Les deux vrais clubs figurent dans la rencontre")
		var venue:=named("OfficeFixtureVenue") as Label
		var expected:=P.fixture_venue(next,false)
		check((venue==null if expected.is_empty() else venue!=null and venue.text==expected),"Lieu issu de la rencontre, sans enceinte inventée")
func ranking_edges() -> void:
	# The retained classic projection is pure and still covered independently.
	var base: Dictionary=app.model.duplicate(true)
	var rows: Array=[]
	for league: Dictionary in base.leagues:
		if league.id==base.meta.leagueId: rows=league.rows
	for index in [0,rows.size()/2,rows.size()-1]:
		var model:=base.duplicate(true);model.club=rows[int(index)].duplicate(true)
		var window:=Legacy.standings_window(model)
		check(window.size()==mini(8,rows.size()) and window.any(func(row):return row.id==model.club.id),"Projection classique : club premier, milieu et dernier conservé")
		var start:=rows.find(window[0]);check(window==rows.slice(start,start+window.size()),"Projection classique : ordre du classement conservé")
func bounds() -> void:
	var page:=named("ImmersiveOffice") as Control
	var workspace:=named("CareerWorkspace") as ScrollContainer
	check(page!=null and workspace!=null,"Canevas et défilement réels raccordés")
	if page==null or workspace==null:return
	check(workspace.get_global_rect().end.x<=app.size.x+1 and workspace.get_global_rect().end.y<=app.size.y+1,"Viewport du Bureau contenu dans la fenêtre")
	check(page.get_global_rect().end.x<=workspace.get_global_rect().end.x+1,"Bureau sans débordement horizontal")
	for control: Button in page.find_children("*","Button",true,false):
		if not control.is_visible_in_tree() or control.disabled:continue
		# The immersive surface scales desktop targets through C.density. Keep
		# the original 25px contract in that coordinate system and also require
		# enough clickable height for every displayed glyph, including row labels.
		var text_height := control.get_theme_font("font").get_height(control.get_theme_font_size("font_size")) if not control.text.is_empty() else 0.0
		for label: Label in control.find_children("*","Label",true,false):
			if label.is_visible_in_tree() and not label.text.is_empty(): text_height=maxf(text_height,label.get_theme_font("font").get_height(label.get_theme_font_size("font_size")))
		var minimum := maxf(C.px(25),text_height)
		check(control.focus_mode==Control.FOCUS_ALL and control.size.x>0 and control.size.y+1>=minimum,"Cible clavier et souris lisible : "+str(control.name)+" · rectangle="+str(control.get_global_rect())+" · hauteur requise="+str(minimum)+" · densité="+str(C.density))
		control.grab_focus(); workspace.ensure_control_visible(control); await settle()
		check(control.has_focus() and workspace.get_global_rect().grow(2).encloses(control.get_global_rect()),"Défilement révèle la commande entière : "+str(control.name))
func navigation() -> void:
	var before:=await export_state()
	var filename:=str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes:=FileAccess.get_file_as_bytes(filename)
	for pair in [["OfficeCalendarAction","Calendrier"],["OfficeSquadAction","Effectif"],["OfficeStandingsAction","Classements"],["OfficePreparationAction","Préparation"],["OfficeInboxAction","Réception"],["OfficeMarketAction","Recrutement"]]:
		await render();await press(pair[0],pair[1])
	for route in ["Bureau","Effectif","Composition","Préparation","Calendrier","Classements","Finances"]:
		app._navigate(route);await settle()
	check(await export_state()==before and FileAccess.get_file_as_bytes(filename)==bytes,"Liens, navigation, fiches et défilement préservent état, RNG et profil")
	await render()
	var spotlight: Dictionary=Office.recruitment_spotlight(app.model).player
	if not spotlight.is_empty():
		await press("OfficeMarketAction","Recrutement")
		check(app.management_ui.market.navigation_id==str(spotlight.id),"Le lien de recrutement ouvre le bon identifiant")
func projections() -> void:
	var base: Dictionary=app.model.duplicate(true)
	var projected:=base.duplicate(true)
	projected.messages=["Message long de réception. ".repeat(35)]
	projected.next.neutral=true;projected.next.phase="final";projected.next.erase("venue")
	projected.packs={"missing":["Pack de carrière absent : réception"]}
	app.model=projected;await render()
	check(texts(named("OfficeFixture")).contains("NEUTRE"),"Terrain neutre présenté explicitement")
	check(named("OfficeFixtureVenue")==null,"Aucune enceinte du club hôte substituée au terrain neutre inconnu")
	check(texts(app.root_content).contains("Pack de carrière absent"),"Avertissement du vrai pack manquant conservé")
	await capture("bureau-projection-neutre-pack")
	projected=base.duplicate(true);projected.next=null;projected.calendar=[];projected.messages=[];projected.meta.canAdvanceSeason=true
	app.model=projected;await render()
	check(texts(named("OfficeFixture")).contains("La saison se termine"),"Intersaison sans rencontre inventée")
	check(texts(named("OfficeTimeline")).contains("Aucune rencontre"),"Chronologie vide honnête")
	check(texts(named("OfficeJournal")).contains("journal s’ouvrira"),"Journal vide honnête")
	projected.meta.canAdvanceSeason=false;app.model=projected;await render()
	check(texts(named("OfficeFixture")).contains("Le travail continue"),"Semaine sans rencontre distincte de l’intersaison")
	app.model=base;await render()
func palette() -> void:
	var original: Color=app.accent
	for color in [Color("cad0d3"),Color("ffdf00"),Color("050505")]:
		app.accent=color;await render()
		var card:=named("OfficeStandings")
		for label: Label in card.find_children("*","Label",true,false):
			if label.text.is_empty():continue
			var ink:=label.get_theme_color("font_color")
			var a:=ink.srgb_to_linear().get_luminance();var b:=Color("151b1e").srgb_to_linear().get_luminance()
			check((maxf(a,b)+.05)/(minf(a,b)+.05)>=4.5,"Classement lisible avec la couleur identitaire "+color.to_html())
		await capture("bureau-palette-"+color.to_html())
	app.accent=original;await render()
func live_round() -> void:
	await command("new_career",{"club":29,"mode":"france"})
	await ContextualFlow.settle_club_meetings(app,self,check)
	if not await ContextualFlow.prepare_match_day(app,self,check): return
	var previous_week: int=app.model.meta.week
	await command("auto_lineup");await command("begin_match")
	await ContextualFlow.skip_talk(app,self,"pre",check)
	await command("pause",{"paused":true})
	var before:=await export_state()
	await render()
	check(app.route=="Match" and app.contextual_director.kind=="live" and not app.root_content.is_visible_in_tree(),"Le vrai direct conserve la priorité sur le Bureau")
	check(await export_state()==before,"Tenter le Bureau ne modifie ni état, ni RNG du direct")
	check(Office.live_match(app.model).heading=="MATCH EN COURS","Projection du Bureau identifie le vrai match en cours")
	await command("delegate")
	check(Office.live_match(app.model).finished and Office.live_match(app.model).heading=="MATCH TERMINÉ","Projection du Bureau distingue résultat à valider")
	await command("finish_round");await ContextualFlow.finish_match_week(app,self,check,previous_week)
	await render()
	check(not app.contextual_director.active() and app.route=="Bureau","Le Bureau revient après validation et rendez-vous")
	check(named("OfficeRecentResults")!=null,"Le résultat réellement joué apparaît dans le Bureau")
	await capture("bureau-resultat-reel")
func run() -> void:
	root.size=Vector2i(1920,1080)
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await wait_model("snapshot initial");await command("new_career",{"club":0,"mode":"common"})
	# QA controls the actual client area; production normally maximizes it.
	var maximize:=Callable(app,"_keep_filled_display")
	if root.size_changed.is_connected(maximize):root.size_changed.disconnect(maximize)
	if root.focus_entered.is_connected(maximize):root.focus_entered.disconnect(maximize)
	root.mode=Window.MODE_WINDOWED

	await ContextualFlow.settle_club_meetings(app,self,check);await render()
	sections();ranking_edges();await navigation()
	for resolution in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=resolution
		if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(resolution)
		await render();await bounds();await capture("bureau-"+str(resolution.x))
	await projections()
	for setup in [[29,"common"],[0,"france"],[0,"fiction"]]:
		await command("new_career",{"club":setup[0],"mode":setup[1]})
		await ContextualFlow.settle_club_meetings(app,self,check);await render()
		check(int(app.model.club.id)==setup[0] and app.model.leagues.size()==(1 if setup[1]=="fiction" else 2),"Vraie carrière et divisions : "+setup[1])
		sections();ranking_edges();await capture("bureau-"+setup[1]+"-"+str(setup[0]))
		if setup[0]==29: await palette()
	await live_round()
	print("BUREAU GREEN : ",checks," contrôles ; ",failures.size()," échec(s)")
	app.bridge.stop();app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
