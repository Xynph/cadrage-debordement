extends SceneTree
const Analysis = preload("res://ui/performance_analysis_view.gd")
const Club = preload("res://ui/immersive08/club_canvas.gd")
const Flow = preload("helpers/contextual_flow.gd")
class PlainHost extends Control:
	var model: Dictionary = {}
	var catalogue: Array = []
class LocatorHost extends PlainHost:
	var navigation_controller: Node
class FixtureNavigation extends Node:
	func entity_available(target: Dictionary) -> bool:
		return target.get("kind")=="fixture" and target.get("id")=="fixture-test"
var app: Control
var checks := 0
var failures: Array[String] = []
var speech_requests := 0
var speech_starts := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 8: await process_frame
func command(id: String, payload: Dictionary = {}) -> void:
	check(app._command(id,payload),"Commande de préparation explicite · "+id)
	var until:=Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	check(not app.waiting and app.bridge.last_response_ok,"Worker réel · "+id)
	await settle()
func found(id: String) -> Node: return app.find_child(id,true,false)
func key(code: Key) -> void:
	for down: bool in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.pressed=down
		root.push_input(event,true); await process_frame
	await settle()
func activate(link: Control, pointer: bool = false) -> void:
	check(link!=null,"Lien réellement créé")
	if link==null: return
	if not pointer:
		link.grab_focus(); await settle(); check(link.has_focus(),"Focus visible sur le lien")
		await key(KEY_ENTER); return
	var point:=link.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await process_frame
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
		root.push_input(event,true); await process_frame
	await settle()
func projection_cases() -> void:
	# Isolated renderer/lookup fixtures, never inserted into the sporting worker.
	var plain:=PlainHost.new()
	plain.model={"club":{"id":1,"cash":1000},"clubLife":{"performanceAnalysis":{"available":true,"summary":{"played":0}},"playerMatchHistory":{"available":true,"enabled":false,"canEnable":true}},"staff":{"teams":[{"id":1,"members":[{"id":"coach-test","name":"Coach de composant","role":"Adjoint"}]}]}}
	var before:=JSON.stringify(plain.model)
	var view:=Analysis.build(plain)
	check(view.find_child("PlayerMatchHistoryEnable",true,false)!=null and view.find_child("PerformancePlayerLink",true,false)==null,"Sans contrôleur : registre désactivé conserve son geste explicite et aucun lien joueur")
	check(Analysis._navigation(plain)==null and not Analysis._available(plain,{"kind":"club","id":1}),"Faux hôte sans propriété de navigation accepté sans route parallèle")
	view.free()
	var card:=Panel.new()
	Club._staff(card,plain)
	check(card.find_children("ClubStaffName_*","Button",true,false).is_empty(),"Staff rendu sans contrôleur : noms restent du texte")
	card.free(); card=Panel.new()
	Club._footer(card,plain,{}, {})
	check(card.find_child("ClubCashLink",true,false)==null and card.find_child("ClubWagesLink",true,false)==null,"Valeurs financières statiques si navigation indisponible")
	check(JSON.stringify(plain.model)==before,"Rendre les faux hôtes ne modifie pas leur modèle ni le registre")
	card.free(); plain.free()
	var owner:=LocatorHost.new(); var navigation:=FixtureNavigation.new(); owner.navigation_controller=navigation
	owner.model={"club":{"id":1},"meta":{"season":2},"calendar":[{"id":"fixture-test","season":2,"home":{"id":1},"away":{"id":2},"score":[18,16],"played":true,"phase":"league"}],"history":[]}
	var result: Dictionary={"fixtureId":"fixture-test","season":2,"home":true,"opponent":2,"pointsFor":18,"pointsAgainst":16,"phase":"league"}
	var stable:=JSON.stringify(owner.model)
	check(Analysis._match_target(owner,result,1)=={"kind":"fixture","id":"fixture-test"},"Saison, côtés, score et phase concordants rendent la cible disponible")
	for patch: Dictionary in [{"fixtureId":null},{"season":1},{"opponent":3},{"home":false},{"pointsFor":19},{"phase":"final"}]:
		var altered:=result.duplicate(true); altered.merge(patch,true)
		check(Analysis._match_target(owner,altered,1).is_empty(),"Résultat incomplet ou contradictoire laissé en texte · "+str(patch))
	check(Analysis._match_target(owner,result,3).is_empty(),"Ancien club du manager ne vise pas une nouvelle rencontre")
	check(JSON.stringify(owner.model)==stable,"Vérification du contexte de match sans mutation")
	navigation.free(); owner.free()
func run() -> void:
	projection_cases()
	root.size=Vector2i(2560,1440)
	app=load("res://main.tscn").instantiate(); root.add_child(app)
	app.coach.speech.set_muted(true)
	app.coach.speech.requested.connect(func(_text: String): speech_requests+=1)
	app.coach.speech.started.connect(func(_id: int): speech_starts+=1)
	var until:=Time.get_ticks_msec()+30000
	while app.model.is_empty() and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	await command("new_career",{"mode":"world","club":0})
	await Flow.settle_club_meetings(app,self,check)
	app.coach.close()
	app.management_ui[Club.KEY]="history"; app._navigate("Club"); await settle()
	check(found("PlayerMatchHistoryEnable")!=null,"Registre réel initialement désactivé : activation reste explicite")
	var requests:=int(app.bridge._next_id)
	check(found("PerformancePlayerLink")==null and app.bridge._next_id==requests,"Afficher le registre désactivé ne crée pas de lien joueur ni de commande")
	# Explicit setup boundary, not an identity-link callback.
	var register: Dictionary=app.model.clubLife.playerMatchHistory
	await command("player_match_history_enable",{"context":register.context.duplicate(true),"confirmed":true})
	await command("export")
	var sporting: Dictionary=JSON.parse_string(app.model.meta.exportText).state
	var file:=str(app.model.meta.dataDir).path_join("donnees.json")
	var saved:=FileAccess.get_file_as_bytes(file)
	requests=int(app.bridge._next_id)
	app.management_ui[Club.KEY]="overview"; app._navigate("Club"); await settle()
	var staff:=app.find_children("ClubStaffName_*","Button",true,false)
	check(not staff.is_empty(),"Staff réel présent dans le tableau de bord Club")
	if not staff.is_empty():
		var staff_id:=str(staff[0].get_meta("entity_id"))
		await activate(staff[0]); check(app.route=="Staff" and app.StaffViews.reading(app).navigation_id==staff_id,"Nom staff ouvre le profil exact")
		app.navigation_controller._travel(-1); await settle()
		await activate(found("ClubStaffPortrait_"+staff_id.validate_node_name()) as Control,true)
		check(app.route=="Staff" and app.StaffViews.reading(app).navigation_id==staff_id,"Portrait staff ouvre le même profil exact")
		app.navigation_controller._travel(-1); await settle()
	for item: Array in [["ClubCashLink","cash"],["ClubWagesLink","wages"]]:
		await activate(found(item[0]) as Control)
		check(app.route=="Finances" and app.management_ui.immersive08_finance_tab==item[1],"Valeur financière ouvre l’onglet exact · "+str(item[1]))
		app.navigation_controller._travel(-1); await settle()
	app.management_ui[Club.KEY]="history"; app._navigate("Club"); await settle()
	var choice:=found("PerformancePlayerChoice") as OptionButton
	check(choice!=null and choice.item_count>1,"Sélecteur de joueur préservé dans le registre actif")
	if choice!=null and choice.item_count>1:
		choice.select(1); choice.item_selected.emit(1); await settle()
		var link:=found("PerformancePlayerLink") as Control
		var player_id:=str(app.model.clubLife.playerMatchHistory.players[1].id)
		check(link!=null and str(link.get_meta("entity_id"))==player_id,"Le sélecteur choisit le joueur sans le confondre avec une activation de lien")
		await activate(link)
		check(app.route=="Effectif" and app.selected_player==player_id and app.get_meta("immersive08_full_player",false),"Nom dans les performances ouvre la fiche complète connue")
		app.navigation_controller._travel(-1); await settle()
		var restored:=found("PerformancePlayerChoice") as OptionButton
		var restored_link:=found("PerformancePlayerLink") as Control
		check(restored!=null and restored.selected==1 and restored_link!=null and str(restored_link.get_meta("entity_id"))==player_id,"Retour conserve le joueur sélectionné par ID, sans détourner le sélecteur")
	check(int(app.bridge._next_id)==requests and saved==FileAccess.get_file_as_bytes(file),"Consultation sans commande ni écriture sportive")
	await command("export")
	check(sporting==JSON.parse_string(app.model.meta.exportText).state,"État, activation du registre et RNG inchangés après consultation")
	check(speech_requests==0 and speech_starts==0 and int(app.coach.speech._id)==0,"Gabi silencieuse : compteurs à zéro")
	print("ANALYSIS CLUB LINKS : ",checks," contrôles ; ",failures.size()," échec(s)")
	app.bridge.stop(); quit(0 if failures.is_empty() else 1)
