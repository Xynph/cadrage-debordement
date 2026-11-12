extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var failures: Array[String]=[]
var checks:=0
var started_ms:=0
var speech_requests:=0
var speech_starts:=0
func _initialize() -> void:
	started_ms=Time.get_ticks_msec()
	call_deferred("run")
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures.append(message);printerr("FAIL: "+message)
		trace("assertion.failed",{"message":message})
func named(node:Node,id:String) -> Node:
	if str(node.name)==id:return node
	for child in node.get_children():
		var found:=named(child,id)
		if found!=null:return found
	return null
func settle() -> void:
	for i in 6:await process_frame
func command(id:String,payload:Dictionary={}) -> void:
	trace("command.begin",{"command":id,"payload_keys":payload.keys()})
	var accepted:bool=app._command(id,payload)
	trace("command.sent",{"command":id,"accepted":accepted})
	var until:=Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<until:await process_frame
	check(not app.waiting and app.bridge.last_response_ok,"Commande réelle "+id)
	trace("command.response",{"command":id,"accepted":accepted,"ok":app.bridge.last_response_ok})
	await settle()
	trace("command.settled",{"command":id})
func finish() -> void:
	check(speech_requests==0 and speech_starts==0,"Silence : aucune demande ni démarrage de parole")
	trace("finish",{"failures":failures,"speech_requests":speech_requests,"speech_starts":speech_starts})
	print("GESTION CARNET : ",checks," contrôles ; ",failures.size()," échec(s)")
	if is_instance_valid(app) and app.bridge!=null:app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
func activate(control:Control) -> void:
	trace("activate.begin",{"control":str(control.name) if control!=null else "<missing>"})
	check(control!=null,"Commande présente")
	if control==null:return
	check(not (control is BaseButton and control.disabled),"Commande activable "+str(control.name))
	if control is BaseButton and control.disabled:return
	control.grab_focus()
	await settle()
	check(control.has_focus(),"Focus clavier "+str(control.name))
	await key(KEY_ENTER)
	trace("activate.end",{"control":str(control.name) if is_instance_valid(control) else "<replaced>"})
func texts(node:Node) -> String:
	var result:String=node.text+"\n" if node is Label else ""
	for child in node.get_children():result+=texts(child)
	return result
func capture(id:String) -> void:
	trace("capture",{"id":id})
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("CD_GESTION_CAPTURES")
	DirAccess.make_dir_recursive_absolute(folder)
	var image:=root.get_texture().get_image()
	check(image.save_png(folder.path_join(id+".png"))==OK,"Capture "+id)
	var metadata:=FileAccess.open(folder.path_join(id+".json"),FileAccess.WRITE)
	metadata.store_string(JSON.stringify({"imagePixels":[image.get_width(),image.get_height()],"windowPhysical":[root.size.x,root.size.y],"canvasLogical":[app.size.x,app.size.y],"route":app.route,"projection":id.contains("projection") or id.contains("nom-long")}))
	metadata.close()
func bounds(id:String) -> void:
	var page:Control=named(app,id)
	check(page!=null and page.get_global_rect().end.x<=app.size.x+1 and page.get_global_rect().end.y<=app.size.y+1,"Vue bornée dans le canvas logique "+id+" "+str(root.size)+" "+str(page.get_global_rect()))
func choose(id:String,text:String) -> void:
	trace("choose",{"control":id,"value":text})
	var choice:OptionButton=named(app,id)
	for i in choice.item_count:
		if choice.get_item_text(i)==text:
			choice.select(i);choice.item_selected.emit(i);await settle();return
	check(false,"Option absente "+text)
func state() -> Dictionary:
	await command("export")
	return JSON.parse_string(app.model.meta.exportText).state
func run() -> void:
	trace("startup.begin")
	app=load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach):
		app.coach.speech.set_muted(true)
		app.coach.speech.requested.connect(func(_text:String):speech_requests+=1)
		app.coach.speech.started.connect(func(_id:int):speech_starts+=1)
	trace("startup.wait-model")
	var startup_until:=Time.get_ticks_msec()+30000
	while app.model.is_empty() and Time.get_ticks_msec()<startup_until:await process_frame
	check(not app.model.is_empty(),"Projection initiale du vrai worker reçue dans la borne de préparation")
	trace("startup.model",{"received":not app.model.is_empty()})
	if app.model.is_empty():finish();return
	app.timer.stop()
	await command("new_career",{"club":0,"mode":"common"})
	trace("meetings.begin")
	await ContextualFlow.settle_club_meetings(app, self, check)
	trace("meetings.end")
	app._navigate("Effectif")
	await settle()
	check(named(app,"RosterSearch") is LineEdit,"Recherche effectif réellement accessible")
	if named(app,"RosterSearch")==null:finish();return
	var search:LineEdit=named(app,"RosterSearch")
	var placeholder:Color=search.get_theme_color("font_placeholder_color")
	var paper:Color=search.get_theme_stylebox("normal").bg_color
	var first:=placeholder.srgb_to_linear().get_luminance();var second:=paper.srgb_to_linear().get_luminance()
	check((maxf(first,second)+.05)/(minf(first,second)+.05)>=4.5,"Contraste de la recherche lisible sur papier")
	search.grab_focus()
	await key(KEY_E,233)
	check(search.has_focus() and search.text=="é" and search.caret_column==1,"Frappe accentuée sans perte du focus/caret")
	var same:=search
	await key(KEY_R,114)
	check(named(app,"RosterSearch")==same and search.text=="ér" and search.caret_column==2,"Recherche locale sans reconstruire la saisie")
	await key(KEY_LEFT)
	await key(KEY_X,120)
	check(search.text=="éxr" and search.caret_column==2 and search.has_focus(),"Insertion au milieu conserve le caret")
	await key(KEY_LEFT,0,true)
	app._navigate("Finances");await settle();app._navigate("Effectif");await settle()
	search=named(app,"RosterSearch")
	check(search.has_focus() and search.text=="éxr" and search.caret_column==1 and search.get_selection_from_column()==1 and search.get_selection_to_column()==2,"Retour menu conserve saisie, focus, caret et sélection de texte")
	await key(KEY_TAB)
	check(app.get_viewport().gui_get_focus_owner()==named(app,"RosterFamily"),"Tab passe réellement de la recherche aux filtres")
	trace("section.utilities")
	var U=load("res://ui/management_state.gd")
	var sample:Array=[{"id":"b","name":"Éric Test","pos":"Pilier","fam":0,"rating":70,"condition":80,"age":23,"injury":0,"contractEnd":1},{"id":"a","name":"Eric Autre","pos":"Pilier","fam":0,"rating":70,"condition":80,"age":24,"injury":2,"contractEnd":2},{"id":"c","name":"Zoé","pos":"Centre","fam":5,"rating":71,"condition":90,"age":22,"injury":0,"contractEnd":3}]
	var state:Dictionary=U.defaults()
	state.search="ERIC"
	check(U.players(sample,state,1).map(func(p):return p.id)==["a","b"],"Recherche sans casse/accents et égalités triées par ID")
	state.search="E\u0301RIC"
	check(U.players(sample,state,1).map(func(p):return p.id)==["a","b"],"Recherche accent Unicode décomposé")
	state.available="Disponibles"
	check(U.players(sample,state,1).map(func(p):return p.id)==["b"],"Filtre disponibles exclut les blessés")
	state.search="";state.available="Tous";state.contract="Fin de saison"
	check(U.players(sample,state,1).map(func(p):return p.id)==["b"],"Échéance de contrat sur saison courante")
	state.contract="Tous";state.position="Centre"
	check(U.players(sample,state,1).map(func(p):return p.id)==["c"],"Poste exact sans famille inventée")
	trace("section.archives.empty")
	app._navigate("Classements");await settle()
	check(named(app,"OpenArchives") is Button,"Archives accessibles depuis les classements")
	await activate(named(app,"OpenArchives"))
	check(texts(named(app,"SeasonArchives")).contains("Aucune saison archivée"),"Nouvelle carrière : état vide explicite")
	app._clear_dialogs();await settle()
	var before:Dictionary=await state()
	var filename:String=str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes:=FileAccess.get_file_as_bytes(filename)
	app._navigate("Effectif");await settle()
	await activate(named(app,"RosterReset"))
	trace("section.profile.continuity")
	var profile_before:ScrollContainer=named(app,"ProfileScroll")
	profile_before.scroll_vertical=110;await settle()
	var profile_offset:=profile_before.scroll_vertical
	search=named(app,"RosterSearch");search.grab_focus();await key(KEY_A,97)
	check(named(app,"ProfileScroll")==profile_before and profile_before.scroll_vertical==profile_offset,"La frappe ne reconstruit pas le dossier ni son scroll")
	await activate(named(app,"RosterReset"))
	trace("section.roster.family")
	await choose("RosterFamily","Arrières")
	for row:Button in app.body.find_children("SquadPlayer*","Button",true,false):
		check(app.model.squad.any(func(p):return str(p.id)==str(row.get_meta("player_id")) and float(p.fam)>3),"Filtre famille appliqué au vrai ID")
	await activate(named(app,"RosterReset"))
	trace("section.roster.sort")
	await choose("RosterSort","Niveau")
	var rows:Array=app.body.find_children("SquadPlayer*","Button",true,false)
	var previous:=101.0
	for row:Button in rows:
		var p:Dictionary=app.model.squad.filter(func(x):return str(x.id)==str(row.get_meta("player_id")))[0]
		check(float(p.rating)<=previous,"Tri réel décroissant du niveau")
		previous=float(p.rating)
	trace("section.roster.distant-row")
	rows=app.body.find_children("SquadPlayer*","Button",true,false)
	check(rows.size()==app.model.squad.size(),"La liste complète rend tous les vrais joueurs après le tri")
	var last:Button=rows[-1]
	var last_id:String=last.get_meta("player_id")
	var last_name:String=str(last.name)
	var scroll:ScrollContainer=named(app,"SquadScroll")
	check(not scroll.get_global_rect().intersects(last.get_global_rect()),"La ligne éloignée est initialement hors du viewport de liste")
	scroll.ensure_control_visible(last);await settle()
	await activate(last)
	var offset:=scroll.scroll_vertical
	check(app.selected_player==last_id and offset>0 and last.has_focus(),"Entrée ouvre la ligne éloignée après un vrai défilement et conserve son focus")
	app._navigate("Finances");await settle();app._navigate("Effectif");await settle()
	var restored_last:Button=named(app,last_name)
	check(app.selected_player==last_id and app.roster_sort=="Niveau" and named(app,"SquadScroll").scroll_vertical==offset and restored_last!=null and restored_last.has_focus(),"Retour menu : ID, tri, scroll non nul et focus de la ligne éloignée conservés")
	# UI-only projection of a timer response which updates the model without rendering.
	var before_tick_scroll:ScrollContainer=named(app,"SquadScroll")
	app.last_command="tick";app._receive_model(app.model.duplicate(true));await settle()
	scroll=named(app,"SquadScroll")
	check(scroll==before_tick_scroll and scroll.scroll_vertical==offset and app.selected_player==last_id and app.roster_sort=="Niveau","Un tick de projection conserve la liste, son scroll, le tri et le dossier sélectionné")
	# In a continuous list, a manual reading move replaces the old previous-page
	# action. Focusing the fixed sort field avoids asking follow_focus to reveal
	# the off-screen selected row; selection must remain unchanged while scrolling.
	var sort_focus:Control=named(app,"RosterSort")
	sort_focus.grab_focus()
	scroll.scroll_vertical=mini(90,int((scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page)/2))
	await settle()
	var after_tick_offset:=scroll.scroll_vertical
	check(after_tick_offset>0 and after_tick_offset!=offset and app.selected_player==last_id,"Après le tick, une autre position de lecture réelle ne remplace pas le dossier")
	app._navigate("Finances");await settle();app._navigate("Effectif");await settle()
	var returned_sort:Control=named(app,"RosterSort")
	check(app.selected_player==last_id and app.roster_sort=="Niveau" and named(app,"SquadScroll").scroll_vertical==after_tick_offset and returned_sort!=null and returned_sort.has_focus(),"Lecture postérieure au tick : ID, tri, scroll et focus conservés au prochain menu")
	trace("section.comparison")
	await activate(named(app,"CompareSelected"))
	rows=app.body.find_children("SquadPlayer*","Button",true,false)
	await activate(rows[0])
	var first_id:String=app.selected_player
	await activate(named(app,"CompareSelected"))
	check(app.management_ui.compare==[last_id,first_id],"Deux vrais IDs ajoutés depuis leurs dossiers")
	await activate(named(app,"OpenComparison"))
	check(named(app,"PlayerComparison")!=null,"Dialogue de comparaison ouvert par Entrée")
	check(named(app,"ComparisonPlayer0").get_item_metadata(named(app,"ComparisonPlayer0").selected)==last_id,"Premier dossier lié à son ID")
	check(named(app,"ComparisonPlayer1").get_item_metadata(named(app,"ComparisonPlayer1").selected)==first_id,"Second dossier lié à son ID")
	var selected:Dictionary=app.model.squad.filter(func(p):return str(p.id)==first_id)[0]
	var comparison_text:=texts(named(app,"PlayerComparison"))
	var displayed_salary:String=app.G.salary_amount(selected.salary)
	var salary_heading:String="Salaire "+app.G.salary_period()
	trace("comparison.presentation",{"player_id":first_id,"name_present":comparison_text.contains(str(selected.name)),"raw_weekly_amount":app.G.euros(selected.salary),"displayed_salary":displayed_salary,"salary_heading":salary_heading,"salary_present":comparison_text.contains(displayed_salary),"period_present":comparison_text.contains(salary_heading)})
	check(comparison_text.contains(str(selected.name)) and comparison_text.contains(displayed_salary) and comparison_text.contains(salary_heading),"Comparaison expose identité et salaire réels selon la période et l’arrondi affichés")
	app._clear_dialogs();await settle()
	trace("section.renewal")
	app.selected_player=str(app.model.squad.filter(func(p):return p.renewal.available)[0].id)
	app._render();await settle()
	var profile_tabs:TabContainer=named(app,"ProfileTabs")
	profile_tabs.current_tab=2;await settle()
	await activate(named(app,"OfferRenewal"))
	var offer:ConfirmationDialog=named(app,"ContractOffer")
	check(offer!=null,"Offre de prolongation par clavier")
	var old_summary:String=named(app,"OfferSummary").text
	var salary:SpinBox=named(app,"OfferSalary")
	salary.value+=1000
	await settle()
	check(named(app,"OfferSummary").text!=old_summary and named(app,"OfferSummary").text.contains("écart") and named(app,"OfferSummary").text.contains("IMMÉDIAT"),"Récapitulatif réactif immédiat / hebdomadaire / écart")
	await activate(offer.get_cancel_button())
	app._navigate("Recrutement");await settle()
	trace("section.market.capacity")
	check(int(app.model.decisions.recruitment.capacity)==67 and int(app.model.decisions.recruitment.places)==6,"Capacité commune : six admissions restent possibles pour61professionnels")
	var available_players:Array=app.model.market.filter(func(p:Dictionary):return p.available)
	check(not available_players.is_empty(),"Des pistes réellement admissibles restent proposées")
	var available_offer:Button
	if not available_players.is_empty():
		var target_search:LineEdit=named(app,"MarketSearch")
		target_search.text=str(available_players[0].name)
		target_search.text_changed.emit(target_search.text);await settle()
		for candidate:Button in app.body.find_children("*","Button",true,false):
			if str(candidate.get_meta("player_id",""))==str(available_players[0].id) and candidate.text=="PROPOSER UN CONTRAT":available_offer=candidate;break
	check(available_offer!=null and not available_offer.disabled,"Le bouton de recrutement respecte la capacité commune reçue du moteur")
	var market_search:LineEdit=named(app,"MarketSearch")
	market_search.clear();market_search.text_changed.emit("");await settle()
	market_search.grab_focus();await key(KEY_Z,122);await key(KEY_Z,122);await key(KEY_Z,122)
	check(named(app,"MarketSearch")==market_search and market_search.has_focus() and texts(app.body).contains("Aucune piste"),"Recherche marché : frappe conservée et vide clair")
	market_search.clear();market_search.text_changed.emit("");await settle()
	check(before==await state(),"Recherche/tri/fiches/comparaison/offres annulées : S et RNG identiques")
	check(bytes==FileAccess.get_file_as_bytes(filename),"Lectures de gestion sans écriture disque")
	trace("section.market.watch")
	var tracks:Array=app.body.find_children("Follow*","Button",true,false)
	check(not tracks.is_empty(),"Piste réelle à suivre")
	var tracked_id:String=tracks[0].get_meta("follow_id")
	await activate(tracks[0])
	var follow_deadline:int=Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<follow_deadline:await process_frame
	await settle()
	check(not app.waiting and app.bridge.last_response_ok,"Décision de suivi acceptée par le moteur")
	var followed_state:Dictionary=await state()
	check(followed_state.manager.watch==[tracked_id] and before.manager.watch.is_empty(),"Le vrai registre persistant contient le suivi choisi")
	check(bytes!=FileAccess.get_file_as_bytes(filename),"La décision explicite de suivi est écrite sur disque")
	before=followed_state
	bytes=FileAccess.get_file_as_bytes(filename)
	await activate(named(app,"MarketFollowed"))
	check(app.management_ui.shortlist==[tracked_id] and app.management_ui.market.followed and tracked_id in app.model.clubLife.managerCareer.watch,"Suivi persistant activé par Entrée et reçu du moteur")
	check(app.body.find_children("Follow*","Button",true,false).size()==1,"Filtre suivis réduit aux vrais IDs")
	for resolution in [Vector2i(1280,800),Vector2i(1440,900),Vector2i(1920,1080)]:
		trace("matrix.resolution",{"resolution":[resolution.x,resolution.y]})
		root.size=resolution
		if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(resolution)
		app._navigate("Effectif");await settle();bounds("CarnetSquad");await capture("effectif-"+str(resolution.x))
		await activate(named(app,"OpenComparison"));await capture("comparaison-"+str(resolution.x));app._clear_dialogs();await settle()
		app._navigate("Recrutement");await settle();bounds("CarnetMarket");await capture("recrutement-"+str(resolution.x))
	var after:Dictionary=await state()
	check(before==after,"Naviguer et filtrer après un suivi : S et RNG identiques")
	check(bytes==FileAccess.get_file_as_bytes(filename),"Lectures après suivi sans nouvelle écriture disque")
	trace("section.projection.begin")
	await projections()
	trace("section.market-archive.begin")
	await real_market_and_archives()
	finish()
func real_market_and_archives() -> void:
	trace("real-market.start")
	await command("new_career",{"club":29,"mode":"france"})
	trace("meetings.begin")
	await ContextualFlow.settle_club_meetings(app, self, check)
	trace("meetings.end")
	check(app.management_ui.compare.is_empty() and app.management_ui.shortlist.is_empty() and app.management_ui.roster.search.is_empty(),"Vraie nouvelle carrière efface les IDs et filtres de la précédente")
	app._navigate("Recrutement");await settle()
	var candidate:Dictionary=app.model.market.filter(func(p):return p.available)[0]
	var before:Dictionary=await state()
	for resolution in [Vector2i(1280,800),Vector2i(1440,900),Vector2i(1920,1080)]:
		trace("matrix.resolution",{"resolution":[resolution.x,resolution.y]})
		root.size=resolution
		if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(resolution)
		app._navigate("Recrutement");await settle()
		var target_search:LineEdit=named(app,"MarketSearch")
		target_search.text=str(candidate.name)
		target_search.text_changed.emit(target_search.text);await settle()
		await capture("recrutement-disponible-"+str(resolution.x))
		var player_id := str(candidate.id)
		var row := named(app,"MarketPlayer_"+player_id.replace(":","_")) as Button
		var offer: Button
		if row != null:
			await activate(row)
			offer = named(app,"OfferRecruitment") as Button
		else:
			var buttons: Array = app.body.find_children("*","Button",true,false).filter(func(b):return str(b.get_meta("player_id",""))==player_id)
			if not buttons.is_empty(): offer = buttons[0]
		check(offer!=null and str(offer.get_meta("player_id",""))==player_id,"Action d’offre liée à la piste choisie "+str(resolution.x))
		if offer==null:continue
		await activate(offer)
		var dialog:ConfirmationDialog=named(app,"ContractOffer")
		check(dialog!=null and dialog.size.x<=app.size.x and dialog.size.y<=app.size.y,"Vraie offre bornée "+str(resolution.x))
		if dialog==null:continue
		var summary := named(dialog,"OfferSummary") as Label
		check(dialog.title.ends_with(str(candidate.name)),"L’offre concerne le joueur sélectionné")
		check(summary!=null and summary.text.contains("acquisition") and summary.text.contains("ajout"),"Recrutement distingue acquisition et ajout hebdomadaire")
		await capture("offre-"+str(resolution.x))
		await activate(dialog.get_cancel_button())
	check(before==await state(),"Vraies offres annulées sans mutation")
	var file:=FileAccess.open(OS.get_environment("CD_ARCHIVE_FIXTURE"),FileAccess.READ)
	await command("import",{"text":file.get_as_text()});file.close()
	var archived:Dictionary=await state()
	app._navigate("Classements");await settle()
	await activate(named(app,"OpenArchives"))
	var names:String=texts(named(app,"SeasonArchives"))
	check(names.contains("SAISON 1") and names.contains("rang") and names.contains("Montée(s)"),"Archive réelle S2 : saison, rang et mouvements visibles")
	await capture("archives-reelles-s2")
	app._clear_dialogs();await settle()
	var original:Dictionary=app.model.duplicate(true)
	for league:Dictionary in app.model.leagues:
		for club:Dictionary in league.rows:
			if int(club.id)==12:club.presentation.name="Identité du pack actuel pour le champion"
	await activate(named(app,"OpenArchives"))
	check(texts(named(app,"SeasonArchives")).contains("Identité du pack actuel pour le champion"),"Archive résout le champion par ID dans le pack de carrière actuel")
	app._clear_dialogs();app.model=original;await settle()
	check(archived==await state(),"Archives et projection pack sans mutation")
func projections() -> void:
	trace("projections.start")
	var saved:Dictionary=app.model.duplicate(true)
	var ids:Array=app.management_ui.compare.duplicate()
	app.model.squad[0].name="Éric Nom de réception très long pour vérifier la lisibilité et le maintien de son identifiant"
	app.management_ui.roster.search="eric nom"
	app.roster_filter="Tous";app.management_ui.roster.position="Tous";app.management_ui.roster.available="Tous";app.management_ui.roster.contract="Tous"
	app._navigate("Effectif");await settle()
	check(app.body.find_children("SquadPlayer*","Button",true,false).size()==1,"Identité pack projetée retrouvée sans accent")
	check(app.management_ui.compare==ids,"Pack changé : comparaison conserve les mêmes IDs")
	await capture("projection-nom-long-pack")
	root.size=Vector2i(1280,800)
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(root.size)
	app.management_ui.compare=[str(app.model.squad[0].id),str(app.model.squad[1].id)]
	await activate(named(app,"OpenComparison"))
	var dialog:AcceptDialog=named(app,"PlayerComparison")
	check(dialog.size.x<=app.size.x and dialog.size.y<=app.size.y,"Comparaison nom long bornée à 1280 physique")
	await capture("comparaison-nom-long-1280")
	app._clear_dialogs();app.management_ui.compare=ids;await settle()
	var removed:String=ids[0]
	app.model.squad=app.model.squad.filter(func(p):return str(p.id)!=removed)
	app.selected_player=removed
	app._render();await settle()
	check(removed not in app.management_ui.compare and app.selected_player!=removed,"Joueur disparu nettoyé avant affichage")
	app.model.market=[];app._render();await settle()
	check(app.management_ui.shortlist==saved.clubLife.managerCareer.watch and app.body.find_children("Follow*","Button",true,false).is_empty(),"Piste indisponible : mémoire moteur conservée, aucune carte de marché inventée")
	app.model=saved
	app.SquadViews.U.sync(app,true)
	app._navigate("Effectif");await settle()
	check(app.management_ui.compare.is_empty() and app.management_ui.roster.search.is_empty(),"Changement de carrière : lecture remise à zéro")
func key(code:int,unicode:int=0,shift:bool=false) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new()
		event.keycode=code;event.unicode=unicode;event.pressed=down;event.shift_pressed=shift
		Input.parse_input_event(event)
		await process_frame
	await settle()

func trace(stage:String,detail:Dictionary={}) -> void:
	var row:=detail.duplicate(true)
	row.stage=stage
	row.milliseconds=Time.get_ticks_msec()-started_ms
	row.checks=checks
	if is_instance_valid(app):
		row.route=app.route
		row.waiting=app.waiting
		row.last_command=app.last_command
		row.last_error=app.last_error
	var line:=JSON.stringify(row)
	print("GESTION_PROGRESS ",line)
	var path:=OS.get_environment("CD_GESTION_PROGRESS")
	if path.is_empty():return
	var file:=FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file==null:
		checks+=1;failures.append("Écriture de la preuve progressive impossible")
		printerr("FAIL: Écriture de la preuve progressive impossible · ",FileAccess.get_open_error())
		return
	file.seek_end();file.store_line(line);file.flush();file.close()
