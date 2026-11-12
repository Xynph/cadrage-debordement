extends SceneTree
const Priorities = preload("res://ui/immersive08/office_priorities.gd")
const Office = preload("res://ui/immersive08/office.gd")
const Rooms = preload("res://qa_runner.gd")
var checks := 0
var failures: Array[String] = []
var app: Control

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func base() -> Dictionary:
	return {"club":{"id":29},"meta":{"season":3,"week":8,"phase":"league"},"selection":{"valid":true},"squad":[],"clubLife":{"youthDevelopment":{"enabled":true,"players":[person("young-b",4)]}}}
func person(id: String, due: int) -> Dictionary:
	return {"id":id,"name":"Martin","tracked":true,"plan":"integration","review":{"status":"review","shortTermObjective":{"expired":due<=8,"coverage":"observed","label":"Construire des minutes professionnelles","from":{"season":3,"week":2},"due":{"season":3,"week":due},"value":40,"target":80,"unit":"minutes"}}}
func reminders(model: Dictionary) -> Array:
	return Priorities.select(model).filter(func(item: Dictionary): return item.action=="youth_review")
func projections() -> void:
	var model := base()
	var before := JSON.stringify(model)
	var choices := reminders(model)
	check(choices.size()==1,"Une échéance observée remonte au Bureau")
	if choices.size()==1:
		check(choices[0].player=="young-b" and choices[0].detail.contains("40") and choices[0].detail.contains("80"),"Rappel du joueur et des minutes réellement publiées")
	check(JSON.stringify(model)==before,"Projection sans mutation")
	model.clubLife.youthDevelopment.players.append(person("young-a",4))
	check(reminders(model).size()<=1,"Au plus un rappel parmi les trois priorités")
	choices=reminders(model)
	if choices.size()==1: check(choices[0].player=="young-a","Échéance égale départagée par identifiant stable")
	model.clubLife.youthDevelopment.players.append(person("young-z",3))
	choices=reminders(model)
	if choices.size()==1: check(choices[0].player=="young-z","Échéance la plus ancienne en premier")
	for scenario in ["future","unavailable","context","untracked","disabled","live","ended"]:
		model=base()
		match scenario:
			"future": model.clubLife.youthDevelopment.players=[person("young-b",9)]
			"unavailable": model.clubLife.youthDevelopment.players[0].review.shortTermObjective.coverage="unavailable"
			"context": model.clubLife.youthDevelopment.players[0].review.status="context"
			"untracked": model.clubLife.youthDevelopment.players[0].tracked=false
			"disabled": model.clubLife.youthDevelopment.enabled=false
			"live": model.live={"finished":false}
			"ended": model.meta.phase="ended"
		check(reminders(model).is_empty(),"Pas de rappel infondé ou hors contexte : "+scenario)
	model=base()
	model.live={"finished":false}
	model.clubLife.press={"conference":{"required":true}}
	model.finance={"cash":-1}
	check(Priorities.select(model).map(func(item: Dictionary):return item.action)==["match","press","finance"],"Urgences conservées avant le suivi")
	model=base();model.next={"date":"2026-11-12"};model.selection.valid=false
	check(Priorities.select(model)[0].action=="selection","Une feuille invalide reste prioritaire")
	model=base();model.clubLife.youthDevelopment.players[0].review.shortTermObjective.value=null
	choices=reminders(model)
	if choices.size()==1: check(not choices[0].detail.contains("0 /"),"Une mesure inconnue ne devient pas zéro")

func settle() -> void:
	for frame in 8: await process_frame
func capture(name: String) -> void:
	var output:=OS.get_environment("CD_OFFICE_REVIEW_CAPTURE_DIR")
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"Capture "+name)
func wait_engine() -> void:
	var deadline:=Time.get_ticks_msec()+60000
	while app.waiting and Time.get_ticks_msec()<deadline: await process_frame
	app.timer.stop()
	check(not app.waiting and app.bridge.last_response_ok,"Réponse du vrai moteur : "+app.last_error)
	await settle()

func run() -> void:
	root.size=Vector2i(1280,720)
	projections()
	# Fail before the expensive app flow if the projection is not implemented.
	if not failures.is_empty(): print("Bureau suivi : %d contrôles, %d échecs" % [checks,failures.size()]);quit(1);return
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await wait_engine()
	app._command("new_career",{"mode":"common","club":29})
	await wait_engine()
	if not await Rooms.settle_club_meetings(app,self,check):await app._close(1);return
	var players: Array=app.model.clubLife.youthDevelopment.players
	check(players.size()>=2,"Au moins deux jeunes réellement publiés")
	if players.size()<2: await app._close(1);return
	# Controlled read-only projection: reproduce homonyms and stale UI filters.
	# No worker state is patched or persisted to create the overdue scenario.
	var target: Dictionary=players[1]
	target.name=players[0].name
	target.tracked=true;target.plan="integration"
	target.review=person(str(target.id),4).review
	app.model.clubLife.youthDevelopment.enabled=true
	app.model.clubLife.youthDevelopment.players=[players[0],target]
	app.management_ui.youth_development={"page":99,"query":"inexistant","stage":2,"review":true}
	app.model.live=null;app.model.selection.valid=true;app.model.next={}
	app.model.finance.cash=1
	for p: Dictionary in app.model.squad: p.injury=0;p.contractEnd=999
	app.model.clubLife.press.conference.required=false
	app._navigate("Bureau");await settle()
	await capture("01-bureau-reexamen-1280")
	var card: Button=app.find_child("OfficeYouthReviewAction",true,false) as Button
	check(card!=null,"Le rappel est réellement affiché au Bureau")
	var profile:=str(app.model.meta.dataDir).path_join("donnees.json")
	var profile_before:=FileAccess.get_sha256(profile)
	var model_before:=JSON.stringify(app.model)
	var commands: int=app.bridge._next_id
	if card!=null: card.pressed.emit();await settle()
	await capture("02-suivi-cible-1280")
	var view: AcceptDialog=app.find_child("YouthDevelopment",true,false) as AcceptDialog
	check(view!=null and view.visible,"Le clic ouvre le vrai dialogue de suivi")
	if view!=null:
		var rows:=view.find_child("YouthDevelopmentRows",true,false)
		var visible_ids: Array=[]
		for child in rows.find_children("*","VBoxContainer",true,false):
			if child.has_meta("player_id"): visible_ids.append(str(child.get_meta("player_id")))
		check(visible_ids==[str(target.id)],"Bon identifiant malgré homonyme, page et filtres précédents · attendu %s, reçu %s, cible %s, filtres %s" % [str(target.id),str(visible_ids),str(view.focused_player_id),str(view.state)])
		var reset: Button=view.find_child("YouthDevelopmentShowAll",true,false) as Button
		check(reset!=null,"Accès à la liste complète depuis le dossier ciblé")
		if reset!=null:
			reset.pressed.emit();await settle()
			check(view.find_child("YouthDevelopmentCount",true,false).text.begins_with("2 jeunes"),"Retour aux deux joueurs du suivi")
	check(app.bridge._next_id==commands,"Consulter le rappel n'envoie aucune commande moteur")
	check(JSON.stringify(app.model)==model_before,"Consulter ne modifie pas la projection")
	check(FileAccess.get_sha256(profile)==profile_before,"Consulter ne réécrit pas la sauvegarde")
	print("Bureau suivi : %d contrôles, %d échecs" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
