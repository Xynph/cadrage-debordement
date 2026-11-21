extends SceneTree
## Club › Histoire (revue du 21/11/2026, n° 8, option B) : Godot réel + worker réel, carrière Monde, un match joué.
## La frise des saisons, le bilan, les barres de statistiques, le score et l'adversaire mènent chacun à leur écran
## (archives, Classements, rencontre, fiche du club) ; aucune fenêtre ; aucun texte tronqué dans la frise.
const Flow = preload("helpers/contextual_flow.gd")
const Club = preload("res://ui/immersive08/club_canvas.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var destinations: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 10: await process_frame
func command(id: String, payload: Dictionary = {}) -> bool:
	var accepted: bool=app._command(id,payload)
	var until:=Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	var ok: bool=accepted and not app.waiting and app.bridge.last_response_ok
	check(ok,"Préparation · "+id+" · "+str(app.last_error))
	await settle(); return ok
func found(id: String) -> Control: return app.root_content.find_child(id,true,false) as Control
func history_page() -> void:
	app.management_ui.erase("competition_page")
	app.management_ui[Club.KEY]="history"
	app._navigate("Club"); await settle()
func windows() -> Array:
	return app.find_children("*","Window",true,false).filter(func(w: Node) -> bool: return (w as Window).visible)
## Bouton d'un élément cliquable : le conteneur porte son bouton dans la méta « bouton ».
func bouton(control: Control) -> BaseButton:
	if control is BaseButton: return control
	return control.get_meta("bouton") as BaseButton if control!=null and control.has_meta("bouton") else null
func press(nom: String, attendu: Callable, label: String) -> void:
	await history_page()
	var b:=bouton(found(nom))
	check(b!=null and b.is_visible_in_tree() and not b.disabled,"Cliquable · "+label)
	if b==null: return
	b.pressed.emit(); await settle()
	var while_until:=Time.get_ticks_msec()+20000
	while app.waiting and Time.get_ticks_msec()<while_until: await process_frame
	await settle()
	check(bool(attendu.call()),"%s -> destination attendue (route %s)" % [label,app.route])
	check(windows().is_empty(),"%s : aucune fenêtre" % label)
	destinations.append("%s -> %s" % [label,app.route])
func prepare() -> bool:
	if not await command("new_career",{"mode":"world-champ","club":29}): return false
	if not await Flow.settle_club_meetings(app,self,check): return false
	if not await Flow.prepare_match_day(app,self,check): return false
	await command("auto_lineup")
	await command("begin_match")
	await Flow.skip_talk(app,self,"pre",check)
	await command("delegate")
	if app.model.get("clubLife",{}).get("matchTalks",{}).get("scene") is Dictionary:
		await Flow.skip_talk(app,self,"post",check)
	elif app.model.get("live") is Dictionary: await command("finish_round")
	if not await Flow.settle_club_meetings(app,self,check): return false
	return await Flow.finish_match_week(app,self,check,int(app.model.meta.week))
func run() -> void:
	root.size=Vector2i(1920,1080)
	app=load("res://main.tscn").instantiate(); root.add_child(app)
	app.coach.speech.set_muted(true)
	var until:=Time.get_ticks_msec()+30000
	while app.model.is_empty() and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	if not await prepare(): finish(); return
	app.coach.close()
	await history_page()
	check(found("ClubHistoryVisual")!=null and found("PerformanceAnalysis")!=null,"Frise et barres affichées dans Club › Histoire")
	# Frise : chaque étape ; le présent -> Classements, le passé -> archives des saisons.
	var etapes: Array=app.root_content.find_children("ClubHistoryStep_*","Control",true,false)
	check(etapes.size()>=1,"Frise : au moins la saison en cours (%d étape(s))" % etapes.size())
	var tronques:=0
	for l: Label in found("ClubHistoryVisual").find_children("*","Label",true,false):
		var police:=l.get_theme_font("font")
		if police!=null and l.is_visible_in_tree() and police.get_string_size(l.text,HORIZONTAL_ALIGNMENT_LEFT,-1,l.get_theme_font_size("font_size")).x>l.size.x+1.0: tronques+=1
	check(tronques==0,"Aucun texte tronqué dans la frise et les barres (%d)" % tronques)
	var noms: Array[String]=[]
	for e: Node in etapes: noms.append(str(e.name))
	for i in noms.size():
		var present:=i==noms.size()-1
		await press(noms[i],func() -> bool: return app.route=="Classements" and (present or found("CompetitionPageBack")!=null),"Étape "+noms[i])
	# Bilan et barres -> Classements (statistiques pour les barres).
	await press("ClubHistoryBilanB",func() -> bool: return app.route=="Classements","Bilan")
	await press("ClubHistoryBars",func() -> bool: return app.route=="Classements" and str(app.management_ui.get("competition",{}).get("tab",""))=="stats","Barres de statistiques")
	# Dernier match : score -> page de la rencontre, adversaire -> fiche du club.
	await history_page()
	var scores: Array=app.root_content.find_children("PerformanceMatchScore_*","Button",true,false)
	check(not scores.is_empty(),"Score du match joué rendu comme lien")
	if not scores.is_empty():
		await press(str(scores[0].name),func() -> bool: return found("CompetitionFixtureDetails")!=null,"Score")
	await history_page()
	var adversaires: Array=app.root_content.find_children("PerformanceOpponent_*","Button",true,false)
	check(not adversaires.is_empty(),"Adversaire rendu comme lien")
	if not adversaires.is_empty():
		await press(str(adversaires[0].name),func() -> bool: return app.route=="Fiche club","Adversaire")
	finish()
func finish() -> void:
	print("CLUB HISTORY CLICKS ",JSON.stringify({"checks":checks,"failures":failures,"destinations":destinations}))
	if app!=null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
