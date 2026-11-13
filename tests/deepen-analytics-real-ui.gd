extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var failures: Array[String] = []
var checks := 0
var model_revisions := 0
var proof := OS.get_environment("CD_ANALYTICS_APP_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func settle() -> void:
	for i in 8: await process_frame
func response() -> void:
	var deadline := Time.get_ticks_msec()+45000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	app.timer.stop()
	check(not app.waiting and app.bridge.last_response_ok,"Réponse du véritable worker · "+str(app.last_error))
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id,payload)
	await response()
func reveal(control: Control) -> void:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await settle()
func key(control: Control) -> void:
	await reveal(control)
	control.grab_focus()
	await settle()
	check(control.has_focus(),"Focus clavier "+str(control.name))
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=KEY_ENTER
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()
func text(node: Node) -> String:
	var value: String = str(node.text)+"\n" if node is Label or node is Button else ""
	for child in node.get_children(): value += text(child)
	return value
func history() -> void:
	app._navigate("Club")
	await settle()
	var tab: Control = app.body.find_child("ClubTab_history",true,false)
	if tab != null: await key(tab)
	else:
		var tabs: TabContainer = app.body.find_child("ClubTabs",true,false)
		if tabs != null: tabs.current_tab=1
		await settle()
	check(app.body.find_child("PerformanceAnalysis",true,false)!=null,"Analyses accessibles depuis Club / Histoire")
func confirmation() -> ConfirmationDialog:
	for child in app.get_children():
		if child is ConfirmationDialog and child.visible: return child
	return null
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://main.tscn").instantiate()
	root.add_child(app)
	app.bridge.model_changed.connect(func(_model: Dictionary): model_revisions+=1)
	await response()
	await command("new_career",{"mode":"fiction","club":0})
	# Une carrière neuve ouvre d'abord son rendez-vous de direction : le moteur refuse l'activation tant qu'il n'est pas traité.
	await ContextualFlow.settle_club_meetings(app,self,check)
	await history()
	var enable: Button = app.body.find_child("PlayerMatchHistoryEnable",true,false)
	check(enable!=null,"Activation dans le véritable écran Histoire")
	if enable==null: finish();return
	var disk: String = str(app.model.meta.dataDir).path_join("donnees.json")
	check(not disk.begins_with(ProjectSettings.globalize_path("res://")),"Profil temporaire hors application")
	var bytes := FileAccess.get_file_as_bytes(disk)
	await key(enable)
	var dialog := confirmation()
	check(dialog!=null,"Vraie confirmation affichée")
	if dialog==null: finish();return
	await key(dialog.get_cancel_button())
	check(not app.model.clubLife.playerMatchHistory.enabled,"Annulation sans activation")
	check(FileAccess.get_file_as_bytes(disk)==bytes,"Annulation sans écriture de profil")
	enable=app.body.find_child("PlayerMatchHistoryEnable",true,false)
	await key(enable)
	dialog=confirmation()
	await key(dialog.get_ok_button())
	await response()
	check(app.model.clubLife.playerMatchHistory.enabled,"Activation confirmée reçue du worker")
	# Calendrier quotidien : coup d'envoi le jour du match seulement, causerie d'avant-match, puis clôture de la semaine.
	if not await ContextualFlow.prepare_match_day(app,self,check): finish();return
	var previous_week: int=int(app.model.meta.week)
	await command("begin_match")
	await ContextualFlow.skip_talk(app,self,"pre",check)
	check(not app.model.get("live",{}).is_empty(),"Vraie rencontre commencée")
	await command("delegate")
	await command("finish_round")
	await ContextualFlow.finish_match_week(app,self,check,previous_week)
	check(app.model.clubLife.playerMatchHistory.recordedMatches==1,"Une rencontre réellement capturée")
	await history()
	var picker: OptionButton = app.body.find_child("PerformancePlayerChoice",true,false)
	check(picker!=null,"Choix du joueur dans la véritable application")
	if picker==null: finish();return
	var details: Control = app.body.find_child("PerformancePlayerDetail",true,false)
	# Le sélecteur de la vue n'est pas dans l'ordre de la liste du modèle et le premier joueur peut n'avoir aucune
	# feuille (« Aucune feuille conservée »). Le contrôle porte sur un joueur réellement mesuré, lu dans le sélecteur.
	var roster: Array = app.model.clubLife.playerMatchHistory.players
	var measured_index := 0
	for index in picker.item_count:
		if not picker.get_item_text(index).ends_with(" · 0 feuille(s)"): measured_index=index; break
	# La fiche affichée à l'ouverture est celle du joueur sélectionné par la vue (« Alexandre Colin », sans feuille en CI),
	# qui n'est pas forcément l'entrée 0 du sélecteur : on sélectionne toujours explicitement le joueur mesuré.
	picker.select(measured_index)
	picker.item_selected.emit(measured_index)
	await settle()
	check(text(details).contains("minutes connues") and text(details).contains("par 80 min"),"Minutes et ratios réels affichés · "+text(details).left(300).replace("\n"," | ")+" · index="+str(measured_index)+" items="+str(picker.item_count)+" feuilles modèle="+str(roster.filter(func(p: Dictionary): return p.get("matches",[]).size()>0).size())+" · "+str(picker.get_item_text(0))+" ; "+str(picker.get_item_text(mini(1,picker.item_count-1))))
	var measured_name: String = picker.get_item_text(measured_index).split(" · ")[0]
	var actual: Dictionary = {}
	for candidate: Dictionary in roster:
		if str(candidate.name) == measured_name: actual = candidate; break
	check(not actual.is_empty(),"Joueur mesuré retrouvé dans le modèle : "+measured_name)
	if actual.is_empty(): finish();return
	check(text(details).contains(str(actual.name)),"Identité du joueur issue du vrai worker")
	check(actual.measuredMatches>0 and actual.minutes!=null,"Minutes réellement mesurées")
	check(text(details).contains(str(int(actual.minutes))+" minutes connues"),"Dénominateur réel affiché")
	await reveal(picker)
	picker.grab_focus()
	await settle()
	for code in [KEY_ENTER,KEY_DOWN,KEY_ENTER]:
		for pressed in [true,false]:
			var event := InputEventKey.new()
			event.keycode=code
			event.pressed=pressed
			Input.parse_input_event(event)
			await process_frame
	await settle()
	var next_index := mini(measured_index+1,picker.item_count-1)
	check(picker.selected==next_index,"Changement du joueur par le vrai clavier")
	check(text(details).contains(picker.get_item_text(next_index).split(" · ")[0]),"Dossier du second joueur affiché")
	bytes=FileAccess.get_file_as_bytes(disk)
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size
		DisplayServer.window_set_size(size)
		await settle()
		picker=app.body.find_child("PerformancePlayerChoice",true,false)
		await reveal(picker)
		check(picker.is_visible_in_tree(),"Sélecteur visible "+str(size))
		check(Rect2(Vector2.ZERO,Vector2(size)).encloses(picker.get_global_rect()),"Sélecteur dans la fenêtre "+str(size))
		check(app.body.find_child("PerformancePlayerDetail",true,false).get_global_rect().size.x<=size.x,"Dossier sans débordement horizontal "+str(size))
	check(FileAccess.get_file_as_bytes(disk)==bytes,"Navigation et redimensionnement sans écriture")
	await command("export")
	var saved: String = str(app.model.meta.exportText)
	var measured := JSON.stringify(app.model.clubLife.playerMatchHistory)
	app.bridge.stop()
	var deadline := Time.get_ticks_msec()+10000
	while app.bridge.child_pid>0 and Time.get_ticks_msec()<deadline: await process_frame
	check(app.bridge.child_pid<=0,"Vrai processus arrêté")
	var prior_revision := model_revisions
	app.reconnect()
	deadline=Time.get_ticks_msec()+45000
	while (app.bridge.child_pid<=0 or model_revisions<=prior_revision) and Time.get_ticks_msec()<deadline: await process_frame
	app.timer.stop()
	await settle()
	check(app.bridge.child_pid>0 and app.bridge.last_response_ok,"Vraie reconnexion au profil")
	await command("export")
	check(str(app.model.meta.exportText)==saved,"État et RNG conservés à la reprise")
	check(JSON.stringify(app.model.clubLife.playerMatchHistory)==measured,"Historique et ratios conservés à la reprise")
	await history()
	check(app.body.find_child("PerformancePlayerChoice",true,false)!=null,"Historique encore accessible après reprise")
	finish()
func finish() -> void:
	FileAccess.open(proof.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("Analyses vraie application : ",checks," contrôles, ",failures.size()," échecs.")
	app.bridge.stop()
	app.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
