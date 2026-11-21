extends SceneTree
# Reprise choisie (reprise.cjs) : départ de la partie à la création, puis décision de reprise
# dans la Préparation, avec le vrai moteur Monde (world-champ).
const Entry = preload("res://ui/entry_screens.gd")
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_REPRISE_UI_OUTPUT")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 12: await process_frame
func response() -> void:
	var deadline := Time.get_ticks_msec()+120000
	while app.waiting and Time.get_ticks_msec()<deadline: await process_frame
	await settle()
	check(not app.waiting and app.bridge.last_response_ok,"Réponse du vrai moteur : "+app.last_error)
func press(button: BaseButton) -> void:
	button.grab_focus(); await settle()
	button.pressed.emit(); await settle()
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"Capture "+name)
## Attend la fin des lectures moteur de l'écran Options (mesure de la machine, aperçu du club).
func idle() -> void:
	var deadline := Time.get_ticks_msec()+120000
	var calm := 0
	while calm<30 and Time.get_ticks_msec()<deadline:
		calm = 0 if app.waiting else calm+1
		await process_frame
	await settle()
## Taille de fenêtre (CD_REPRISE_UI_SIZE, ex. « 1600x900 ») : 1920×1080 par défaut.
func window_size() -> Vector2i:
	var parts := OS.get_environment("CD_REPRISE_UI_SIZE").split("x")
	if parts.size()==2 and parts[0].is_valid_int() and parts[1].is_valid_int(): return Vector2i(int(parts[0]),int(parts[1]))
	return Vector2i(1920,1080)
## Écran Options : six blocs, logos des championnats, aucun chevauchement, aucun défilement dès 1600×900.
func check_options_layout() -> void:
	var blocks := ["CreationOptionsClub","CreationSeasonTimeline","CreationGabiNote","CreationPresidentWord","CreationRivals","CreationLeagueDetail","CreationSquadFaces","CreationAppointments","CreationOptionsActions"]
	var rects: Array[Rect2] = []
	var names: Array[String] = []
	for id in blocks:
		var block := app.find_child(id,true,false) as Control
		check(block!=null and block.is_visible_in_tree(),"Bloc présent : "+id)
		if block==null: continue
		rects.append(block.get_global_rect()); names.append(id)
		for label: Label in block.find_children("*","Label",true,false):
			if not label.is_visible_in_tree() or label.text.is_empty(): continue
			check(block.get_global_rect().grow(1).encloses(label.get_global_rect()),"Texte « %s » contenu dans %s" % [label.text.left(40),id])
	for a in rects.size():
		for b in range(a+1,rects.size()):
			check(not rects[a].grow(-1).intersects(rects[b].grow(-1)),"Pas de chevauchement : %s / %s" % [names[a],names[b]])
	var state := str((app.find_child("CreationCareerOptions",true,false) as Control).get_meta("preview_state",""))
	check(state in ["ready","fallback"],"Aperçu du club reçu ou repli : "+state)
	print("APERÇU DU CLUB : ",state)
	var cards := app.find_children("CreationLeagueCard_*","Button",true,false)
	check(cards.size()>=2,"Championnats suivis affichés (%d)" % cards.size())
	for card: Button in cards:
		var id := str(card.name).trim_prefix("CreationLeagueCard_")
		var logo := card.find_child("CreationLeagueLogo_"+id,true,false) as TextureRect
		check(logo!=null and logo.texture!=null and logo.is_visible_in_tree(),"Logo ou trophée du championnat "+id)
	check(app.find_child("CreationLeagueCard_elite",true,false)!=null and app.find_child("CreationLeagueCountry_FR",true,false).find_child("CreationLeagueFlag_fr",true,false)!=null,"Championnats regroupés par pays, drapeau compris")
	if root.size.y>=900:
		var visible := root.get_visible_rect().grow(1)
		for rect in rects: check(visible.encloses(rect),"Bloc dans la fenêtre à %dx%d" % [root.size.x,root.size.y])
		for scroll: ScrollContainer in app.find_child("CarnetCreation",true,false).find_children("*","ScrollContainer",true,false):
			check(not scroll.get_v_scroll_bar().visible,"Aucun défilement vertical (%s) à %dx%d" % [scroll.name,root.size.x,root.size.y])
func run() -> void:
	root.size=window_size()
	app=load("res://main.tscn").instantiate(); root.add_child(app)
	var deadline := Time.get_ticks_msec()+90000
	while app.model.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.model.is_empty(),"Application et catalogue réels prêts")
	app.timer.stop()
	check(app.model.get("meta",{}).get("repriseCreation",{}).get("elite",{}).get("0","")=="2026-07-27","Dates de reprise de l’Élite exposées à la création")
	Entry.begin_creation(app); await settle()
	# Options de carrière jamais sans club choisi, même si l'étape est demandée.
	app.management_ui[Entry.CREATION_STEP]="carriere"; app._render(); await settle()
	check(app.find_child("CreationCareerOptions",true,false)==null and app.find_child("CreationClubGrid",true,false)!=null,"Écran Options inaccessible sans club choisi")
	app.management_ui.erase(Entry.CREATION_STEP); app._render(); await settle()
	var clubs := app.find_child("CreationClubGrid",true,false) as GridContainer
	check(clubs!=null and clubs.get_child_count()>0,"Vrais clubs disponibles")
	await press(clubs.get_child(0) as Button)
	await capture("creation-1-club")
	# Écran du club allégé : les options de carrière ont leur écran (étape 03), ouvert par « Options de carrière ».
	check(app.find_child("CreationStartChoice",true,false)==null and app.find_child("CreationStart",true,false)==null,"Écran du club sans options de carrière")
	var next := app.find_child("CreationNext",true,false) as Button
	check(next!=null and not next.disabled,"Options de carrière accessibles après le choix du club")
	await press(next)
	await idle()
	check(app.find_child("CreationCareerOptions",true,false)!=null and app.find_child("CreationClubGrid",true,false)==null,"Écran dédié aux options de carrière")
	check_options_layout()
	check(app.find_child("CreationLeagueDetail",true,false)!=null and app.find_child("CreationVaryCurrent",true,false)!=null,"Championnats suivis et niveau de départ sur l’écran des options")
	var suivis := app.find_child("CreationLeagueDetailCount",true,false) as Label
	check(suivis!=null and suivis.text.contains("en détail complet sur"),"Championnats suivis : compte affiché")
	check(app.find_child("CreationLeagueDetailNames",true,false)==null and app.find_child("CreationLeagueDetailOpen",true,false)==null,"Anciens nœuds de la liste de noms retirés")
	var pays := 0
	for code in ["FR","GB","URC","SRP","JP"]:
		if app.find_child("CreationLeagueCountry_"+code,true,false)!=null: pays += 1
	check(pays>=3,"Au moins 3 blocs pays (%d)" % pays)
	var mine := app.find_child("CreationLeagueCard_elite",true,false) as Button
	var mine_state := mine.find_child("CreationLeagueCardState",true,false) as Label if mine!=null else null
	check(mine_state!=null and mine_state.text.contains("Ton championnat"),"Vignette du championnat du club : « Ton championnat »")
	var count_before := suivis.text if suivis!=null else ""
	var other := app.find_child("CreationLeagueCard_prem",true,false) as Button
	var other_state := other.find_child("CreationLeagueCardState",true,false) as Label if other!=null else null
	var state_before := other_state.text if other_state!=null else ""
	check(other!=null and not other.disabled and state_before!="","Vignette d’un autre championnat disponible")
	if other != null:
		await press(other)
		var count_after := app.find_child("CreationLeagueDetailCount",true,false) as Label
		var other_after := app.find_child("CreationLeagueCard_prem",true,false) as Button
		var state_after := (other_after.find_child("CreationLeagueCardState",true,false) as Label).text if other_after!=null else ""
		check(count_after!=null and count_after.text!=count_before,"Un clic sur une vignette change le compte : "+count_before+" → "+(count_after.text if count_after else ""))
		check(state_after!=state_before,"Un clic sur une vignette change son état : "+state_before+" → "+state_after)
		if other_after != null:
			await press(other_after)
		var count_back := app.find_child("CreationLeagueDetailCount",true,false) as Label
		var other_back := app.find_child("CreationLeagueCard_prem",true,false) as Button
		var state_back := (other_back.find_child("CreationLeagueCardState",true,false) as Label).text if other_back!=null else ""
		check(count_back!=null and count_back.text==count_before and state_back==state_before,"Un second clic remet le championnat comme avant")
	await capture("creation-2-options-carriere")
	var choice := app.find_child("CreationStartChoice",true,false) as OptionButton
	check(choice!=null and choice.item_count==3,"Trois départs proposés")
	check(choice.selected==0 and choice.get_item_text(0).contains("13 juillet"),"Départ par défaut : reprise des premiers clubs")
	check(app.find_child("CreationStartSentence",true,false)==null,"Plus de phrase sous le choix du départ")
	check(choice.tooltip_text.contains("13 juillet 2026"),"Conséquences du départ claires, en infobulle")
	var arrival := app.find_child("CreationSeasonArrival",true,false) as Control
	check(arrival!=null and app.find_child("CreationSeasonStep_first",true,false).is_ancestor_of(arrival),"Frise : arrivée avec les premiers clubs")
	choice.select(1); choice.item_selected.emit(1); await settle()
	check(choice.tooltip_text.contains("reprise de ton club"),"L’infobulle suit le choix")
	arrival = app.find_child("CreationSeasonArrival",true,false) as Control
	check(arrival!=null and app.find_child("CreationSeasonStep_club",true,false).is_ancestor_of(arrival),"La frise suit le départ : arrivée à la reprise du club")
	var gabi := app.find_child("CreationGabiSpeech",true,false) as Label
	check(gabi!=null and gabi.text.contains("jour de la reprise") and gabi.text.length()<=181,"La bulle de Gabi suit le départ (≤ 181 caractères)")
	choice.select(2); choice.item_selected.emit(2); await settle()
	check(app.find_child("CreationSeasonStep_eve",true,false)!=null,"Départ veille : étape de la veille dans la frise")
	choice.select(0); choice.item_selected.emit(0); await settle()
	await capture("reprise-creation")
	if root.size != Vector2i(1920,1080):
		# Autres tailles (1600×900, 1280×720) : l'écran Options seulement ; la suite (Préparation) est calée sur 1920×1080.
		await finish()
		return
	var start := app.find_child("CreationStart",true,false) as Button
	check(start!=null and not start.disabled,"Création disponible")
	await press(start); await response()
	check(app.model.get("clubLife",{}).get("reprise",{}).get("start","")=="premiers-clubs","Départ transmis au moteur")
	check(str(app.model.meta.get("calendarToday",""))=="2026-07-13","La carrière commence le 13 juillet 2026")
	check(await ContextualFlow.settle_club_meetings(app, self, check),"Rendez-vous d’accueil traités")
	app._navigate("Préparation"); await settle()
	var open_button := app.find_child("PreparationReprise",true,false) as Button
	check(open_button!=null,"Accès à la reprise depuis la Préparation")
	if open_button != null: await press(open_button)
	var panel := app.find_child("RepriseDecision",true,false)
	check(panel!=null,"Décision de reprise dans la Préparation")
	check(app.find_child("RepriseGabi",true,false)!=null,"Conseil de Gabi")
	check(app.find_child("RepriseInternationals",true,false)!=null,"Internationaux en congés visibles")
	var option := app.find_child("RepriseOption_2026-07-20",true,false) as Button
	check(option!=null,"Lundi 20 juillet proposé")
	if option != null:
		await press(option); await response()
		check(str(app.model.clubLife.reprise.club.date)=="2026-07-20","Choix de reprise appliqué par le moteur")
	await settle()
	check(app.find_child("RepriseDialog",true,false)!=null,"La sous-page de reprise reste ouverte après le choix")
	await capture("reprise-decision")
	# Décisions de la préparation (16/11/2026) : « Continuer » s'arrête le jour de la reprise et ouvre la fenêtre.
	var amicaux := app.find_child("RepriseDecision_amicaux",true,false)
	check(amicaux!=null and app.find_child("RepriseDecision_stage",true,false)!=null,"Programme des amicaux et stage proposés")
	var title := app.find_child("RepriseDecisionTitle_amicaux",true,false) as Label
	check(title!=null and title.text.contains("À DÉCIDER AVANT LE LUNDI 20 JUILLET"),"Échéance du programme affichée : "+(title.text if title else ""))
	check(app.find_child("RepriseDecisionGabi_amicaux",true,false)!=null,"Conseil de Gabi pour les amicaux")
	if app.find_child("RepriseDialog",true,false) != null:
		app.management_ui.preparation.sub = ""
		app._render()
	await settle()
	var stopped := false
	for attempt in 8:
		check(await ContextualFlow.settle_club_meetings(app, self, check),"Rendez-vous réglés avant Continuer")
		app._command("advance_until_event", {"fromDate": str(app.model.meta.calendarToday), "stops": {"messages": "aucun"}})
		var wait := Time.get_ticks_msec()+180000
		while app.waiting and Time.get_ticks_msec()<wait: await process_frame
		await settle()
		var stop: Dictionary = app.model.get("meta",{}).get("advanceUntilEvent",{}).get("stop",{})
		if str(stop.get("kind",""))=="decision": stopped = true; break
	check(stopped,"Continuer s’arrête sur la décision des amicaux")
	check(str(app.model.meta.get("calendarToday",""))=="2026-07-20","Arrêt le jour de la reprise")
	await settle()
	check(app.find_child("RepriseDialog",true,false)!=null,"La reprise s’ouvre d’elle-même sur la décision")
	var rodage := app.find_child("RepriseDecisionOption_amicaux_rodage",true,false) as Button
	check(rodage!=null and not rodage.disabled,"Option rodage à domicile disponible")
	if rodage != null:
		await press(rodage); await response()
	var chosen: Array = app.model.clubLife.reprise.decisions.filter(func(d): return d.key=="amicaux")
	check(not chosen.is_empty() and str(chosen[0].selected)=="rodage","Programme retenu par le moteur")
	var staff := app.find_child("RepriseDecisionStaff_stage",true,false) as Button
	check(staff!=null,"Stage : confier à Gabi")
	if staff != null:
		await press(staff); await response()
	var camp: Array = app.model.clubLife.reprise.decisions.filter(func(d): return d.key=="stage")
	check(not camp.is_empty() and str(camp[0].selected)=="equilibre" and bool(camp[0].staff),"Stage confié à Gabi (choix prudent)")
	await settle()
	var block := app.find_child("RepriseDecision_amicaux",true,false) as Control
	var scroll := app.find_child("RepriseScroll",true,false) as ScrollContainer
	if scroll != null and block != null: scroll.ensure_control_visible(block)
	await settle()
	await capture("reprise-decisions-preparation")
	await finish()
func finish() -> void:
	var result := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	result.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"size":[root.size.x,root.size.y]},"  ")); result.close()
	print("REPRISE UI : %d contrôles ; %d échecs" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
