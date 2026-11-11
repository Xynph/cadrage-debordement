extends SceneTree
const Order = preload("res://ui/player_table_order.gd")
const Finance = preload("res://ui/immersive08/finance_canvas.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_PLAYER_TABLE_OUTPUT")

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 12: await process_frame
func wait_worker() -> void:
	var deadline := Time.get_ticks_msec()+30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	await settle()
	check(not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok,"Vrai moteur disponible")
func activate(id: String) -> void:
	var button := app.find_child(id,true,false) as Button
	check(button != null and not button.disabled,"En-tête disponible : "+id)
	if button == null: return
	button.grab_focus()
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode=KEY_ENTER; event.pressed=pressed
		Input.parse_input_event(event); await process_frame
	await settle()
func wheel(scroll: ScrollContainer, header: Control, last: Control) -> void:
	check(scroll != null and header != null and last != null,"Liste et cadre présents")
	if scroll == null or header == null or last == null: return
	app.body_scroll.ensure_control_visible(scroll); await settle()
	var origin := header.get_global_rect()
	var point := scroll.get_global_rect().get_center()
	for index in 80:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_WHEEL_DOWN; event.pressed=true
		event.position=point; event.global_position=point; root.push_input(event,true)
		await process_frame
	await settle()
	check(header.get_global_rect().is_equal_approx(origin),"Molette interne : en-tête immobile")
	check(scroll.get_global_rect().intersects(last.get_global_rect()),"Dernier joueur atteignable sans changement de page")
	if scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page:
		check(scroll.scroll_vertical > 0,"La molette déplace réellement la liste")
func run() -> void:
	var sample := [{"id":"u","salary":null},{"id":"z","salary":80},{"id":"b","salary":9},{"id":"a","salary":80},{"id":"c","salary":100}]
	var unchanged := JSON.stringify(sample)
	check(Order.ordered(sample,"salary",false).map(func(p):return p.id)==["b","a","z","c","u"],"Tri numérique 9/80/100 croissant, inconnus à la fin et identifiants stables")
	check(Order.ordered(sample,"salary",true).map(func(p):return p.id)==["c","a","z","b","u"],"Tri décroissant conserve inconnus à la fin et égalités stables")
	check(Finance.wage_rows(sample,"salary",false).map(func(p):return p.id)==["b","a","z","c","u"],"Finance : comparateur numérique croissant")
	check(Finance.wage_rows(sample,"salary",true).map(func(p):return p.id)==["c","a","z","b","u"],"Finance : comparateur décroissant et inconnus derniers")
	check(Order.ordered([{ "id":"a","x":1 },{ "id":"A","x":1 }],"x",true).map(func(p):return p.id)==["A","a"],"Identifiants distincts par casse restent déterministes")
	check(JSON.stringify(sample)==unchanged,"Les tris ne mutent pas la source")
	root.size=Vector2i(2560,1440)
	app=load("res://main.tscn").instantiate(); root.add_child(app)
	await wait_worker(); app.timer.stop()
	app._command("new_career",{"mode":"common","club":0}); await wait_worker()
	var file := str(app.model.meta.dataDir).path_join("donnees.json")
	var before := FileAccess.get_sha256(file)
	var sequence: int=app.bridge._next_id
	app._navigate("Formation"); await settle()
	for key in ["source","name","age","pos","note","potential","change","minutes","status"]:
		await activate("AcademySort_"+key)
		var first: bool=app.management_ui.immersive_academy.table_descending
		await activate("AcademySort_"+key)
		check(first != app.management_ui.immersive_academy.table_descending,"Académie : deux sens pour "+key)
	var academy_rows := app.find_child("AcademyImmersiveRows",true,false)
	var academy: Array=academy_rows.get_children().filter(func(node):return node is Button and node.has_meta("development_id"))
	check(app.find_child("AcademyImmersiveNext",true,false)==null,"Académie sans pagination")
	if not academy.is_empty(): await wheel(app.find_child("AcademyPlayerScroll",true,false),app.find_child("AcademySort_name",true,false),academy[-1])
	app._navigate("Effectif"); await settle()
	for child in app.body.get_children(): app.body.remove_child(child); child.queue_free()
	var legacy: Control = app.SquadViews.squad(app); app.body.add_child(legacy); await settle()
	var header := legacy.find_child("RosterHeader",true,false)
	var columns: Array=header.get_children().map(func(node):return str(node.name))
	for id: String in columns:
		await activate(id); var first: bool=app.management_ui.roster.descending
		await activate(id); check(first != app.management_ui.roster.descending,"Effectif générique : deux sens pour "+id)
	var roster_scroll := legacy.find_child("SquadScroll",true,false) as ScrollContainer
	var roster_list := roster_scroll.get_child(0)
	var roster: Array=roster_list.get_children().filter(func(node):return node is Button and node.has_meta("player_id"))
	check(roster.size()==app.model.squad.size(),"Tous les joueurs présents dans la liste générique")
	check(legacy.find_child("RosterPagination",true,false)==null,"Effectif générique sans pagination")
	if not roster.is_empty(): await wheel(roster_scroll,legacy.find_child("RosterHeader",true,false),roster[-1])
	app._navigate("Composition"); await settle()
	for key in ["slot","name","pos","condition"]:
		await activate("BenchSort_"+key); var first: bool=app.management_ui.bench_reading.descending
		await activate("BenchSort_"+key); check(first!=app.management_ui.bench_reading.descending,"Banc : deux sens pour "+key)
	var bench := app.find_child("BenchPlayerRows",true,false)
	check(bench.get_child_count()==8,"Les huit places du banc restent présentes")
	var target: Button=bench.get_child(0)
	var expected_slot := str(target.name).trim_prefix("LineupSlot").to_int()-1
	target.pressed.emit(); await settle()
	check(app.selected_slot==expected_slot,"Après tri, le bouton ouvre son vrai poste sans réaffecter le joueur")
	app._clear_dialogs(); await settle()
	app._navigate("Finances"); await settle()
	await activate("FinanceTab_wages")
	for key in ["name","pos","contractEnd","salary"]:
		await activate("FinanceSort_"+key); var first: bool=app.management_ui.finance_wage_sort.descending
		await activate("FinanceSort_"+key); check(first!=app.management_ui.finance_wage_sort.descending,"Salaires : deux sens pour "+key)
	var wages := app.find_child("FinanceWageRows",true,false)
	var wage_buttons: Array=wages.get_children().filter(func(node):return node is Button and str(node.name).begins_with("FinancePlayer_"))
	check(wage_buttons.size()==app.model.squad.size(),"Tous les salaires présents sans pagination")
	if not wage_buttons.is_empty(): await wheel(app.find_child("FinanceWageScroll",true,false),app.find_child("FinanceSort_name",true,false),wage_buttons[-1])
	check(app.bridge._next_id==sequence,"Tri, défilement et choix du poste : aucune commande sportive")
	check(FileAccess.get_sha256(file)==before,"Profil sportif inchangé après les quatre parcours")
	var report := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));report.close()
	print("TRIS ET LISTES : %d contrôles ; %d échecs" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
