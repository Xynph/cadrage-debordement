extends SceneTree
const Finance = preload("res://ui/immersive08/finance_canvas.gd")
const ContextualFlow = preload("helpers/contextual_flow.gd")
class LedgerProjectionApp extends Control:
	var model: Dictionary
var app: Control
var checks := 0
var failures: Array[String] = []
var requested := 0
var started := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 8: await process_frame
func command(id: String, payload: Dictionary = {}) -> void:
	check(app._command(id,payload),"Commande publique de préparation · "+id)
	var until := Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	check(not app.waiting and app.bridge.last_response_ok,"Réponse worker réelle · "+id+" · "+app.last_error)
	await settle()
func key(code: Key) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.pressed=down
		Input.parse_input_event(event); await process_frame
	await settle()
func click(point: Vector2) -> void:
	var move := InputEventMouseMotion.new(); move.position=point; move.global_position=point
	Input.parse_input_event(move); await process_frame
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
		Input.parse_input_event(event); await process_frame
	await settle()
func found(id: String) -> Control: return app.find_child(id,true,false) as Control
func projection_cases() -> void:
	var owner := LedgerProjectionApp.new()
	var entries: Array = [{"title":"Même libellé","amount":-10},{"title":"Même libellé","amount":-10}]
	owner.model={"finance":{"ledger":entries}}
	var locator := Finance.ledger_locator(entries,1)
	check(locator!=Finance.ledger_locator(entries,0) and Finance.ledger_index(owner,locator)==1,"Occurrences identiques distinguées dans une même projection")
	var original := JSON.stringify(owner.model)
	check(Finance.ledger_index(owner,"ledger:missing:1")==-1 and Finance.ledger_locator(entries,-1).is_empty(),"Locator absent ou hors limites refusé")
	entries.push_front({"title":"Nouvelle écriture","amount":30})
	check(Finance.ledger_index(owner,locator)==-1,"Ancienne occurrence refusée après insertion réelle dans la projection")
	entries.pop_front()
	check(JSON.stringify(owner.model)==original,"Résolution sans mutation des entrées")
	entries[0].amount=-11
	check(Finance.ledger_index(owner,locator)==-1,"Correction d’une autre écriture invalide aussi l’ancien locator")
	owner.free()
func target_matches(index: int, entries: Array) -> void:
	var target := found("FinanceLedgerTarget") as Label
	check(app.route=="Finances" and app.management_ui[Finance.KEY]=="cash","Destination : vrai journal de trésorerie")
	check(int(app.management_ui.get(Finance.PAGE_KEY_PREFIX+"cash",-1))==floori(float(index)/8),"Page exacte de l’écriture n° "+str(index+1))
	check(target!=null,"Ligne ciblée réellement présente")
	if target==null: return
	check(target.get_meta("ledger_index",-1)==index and target.get_meta("ledger_entry",{})==entries[index],"Titre, montant et champs conservés correspondent à l’occurrence exacte")
	check(target.text==str(entries[index].title) and target.has_focus(),"Libellé original et focus clavier sur la ligne surlignée")
	check(found("FinanceLedgerSelection")!=null,"Sélection visible avec les couleurs existantes")
func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("CD_LEDGER_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	var image := root.get_texture().get_image()
	check(image.get_size()==Vector2i(2560,1440),"Capture réelle 1440p")
	check(image.save_png(output.path_join(id+".png"))==OK,"Capture "+id)
func run() -> void:
	projection_cases()
	root.size=Vector2i(2560,1440)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
	app=load("res://main.tscn").instantiate(); root.add_child(app)
	app.coach.speech.requested.connect(func(_text: String): requested+=1)
	app.coach.speech.started.connect(func(_id: int): started+=1)
	var until:=Time.get_ticks_msec()+30000
	while app.model.is_empty() and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	check(not app.model.is_empty(),"Projection initiale reçue")
	await command("import",{"text":FileAccess.get_file_as_string(OS.get_environment("CD_LEDGER_FIXTURE"))})
	await ContextualFlow.settle_club_meetings(app,self,check)
	var entries: Array=app.model.finance.ledger.duplicate(true)
	check(entries.size()>=12,"Douze vraies écritures conservées dans la carrière de recette S2")
	if entries.size()<12: finish(); return
	check(not entries[0].has("id") and not entries[0].has("date"),"Le journal source ne possède ni ID ni date : aucune valeur inventée")
	await command("export")
	var before: Dictionary=JSON.parse_string(app.model.meta.exportText).state
	var previous_command: String=app.last_command
	var save_path:=str(app.model.meta.dataDir).path_join("donnees.json")
	var saved:=FileAccess.get_file_as_bytes(save_path)
	var nav: Node=app.navigation_controller
	check(nav.open_entity({"kind":"finance","id":"summary"}),"Synthèse financière ouverte en lecture")
	await settle()
	var button:=found("FinanceChartOperation_9") as Button
	check(button!=null and button.get_meta("ledger_index",-1)==9,"Dixième point/barre possède sa destination exacte")
	if button==null: finish(); return
	button.grab_focus(); await settle(); await key(KEY_ENTER)
	target_matches(9,entries)
	await capture("finance-operation-page2-1440")
	nav._travel(-1); await settle()
	check(app.management_ui[Finance.KEY]=="summary" and found("FinanceChartOperation_9").has_focus(),"Retour restaure onglet et focus du point source")
	var graph: Variant=found("FinanceLedgerPlot")
	var stride: float=graph.size.x/12.0
	var zero: float=graph._height(0)
	var top: float=graph._height(absf(float(entries[0].amount)))
	await click(graph.global_position+Vector2(graph.size.x-stride*.5,clampf((zero+top)*.5,2,graph.size.y-2)))
	target_matches(0,entries)
	nav._travel(-1); await settle()
	graph=found("FinanceLedgerPlot")
	var cumulative: PackedFloat64Array=graph.cumulative
	var point_y: float=graph._height(cumulative[cumulative.size()-2])
	await click(graph.global_position+Vector2(graph.size.x-stride*1.5,clampf(point_y,2,graph.size.y-2)))
	target_matches(1,entries)
	check(app.last_command==previous_command and saved==FileAccess.get_file_as_bytes(save_path),"Clics, clavier et retour n’émettent aucune commande ni écriture sportive")
	await command("export")
	check(before==JSON.parse_string(app.model.meta.exportText).state,"État sportif et RNG inchangés après consultation")
	check(requested==0 and started==0 and int(app.coach.speech._id)==0,"Silence Gabi : zéro demande et zéro départ de parole")
	finish()
func finish() -> void:
	print("FINANCE LEDGER LINKS : ",checks," contrôles ; ",failures.size()," échec(s)")
	if app!=null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
