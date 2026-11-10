extends SceneTree
const Sort = preload("res://ui/recruitment_sort.gd")
const U = preload("res://ui/management_state.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_RECRUITMENT_SORT_OUTPUT")

func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 8: await process_frame
func ids(rows: Array) -> Array: return rows.map(func(row: Dictionary): return row.id)
func units() -> void:
	var source := [{"id":"z","name":"Zulu","pos":"Centre","age":100,"rating":70,"fee":100,"salary":9,"available":true},{"id":"a","name":"Álpha","pos":"Arrière","age":20,"rating":10,"fee":9,"salary":100,"available":true},{"id":"b","name":"Bravo","pos":"Ailier","age":9,"rating":40,"fee":20,"salary":20,"available":false},{"id":"u","available":true}]
	var reports := {"z":{"id":"z","name":"Zulu","pos":"Centre","week":11,"season":1,"grade":"A","potential":90,"assessment":{"stale":false}},"a":{"id":"a","name":"Álpha","pos":"Arrière","week":2,"season":1,"grade":"C","potential":50,"assessment":{"stale":true}},"b":{"id":"b","name":"Bravo","pos":"Ailier","week":9,"season":1,"grade":"B","potential":70,"assessment":{"stale":false}}}
	var expected := {"Nom":[["a","b","z","u"],["z","b","a","u"]],"Poste":[["b","a","z","u"],["z","a","b","u"]],"Âge":[["b","a","z","u"],["z","a","b","u"]],"Niveau":[["a","b","z","u"],["z","b","a","u"]],"Potentiel":[["a","b","z","u"],["z","b","a","u"]],"Prime":[["a","b","z","u"],["z","b","a","u"]],"Salaire":[["z","b","a","u"],["a","b","z","u"]],"Rapport":[["a","b","z","u"],["b","z","a","u"]],"Avis":[["z","b","a","u"],["a","b","z","u"]]}
	var before := JSON.stringify([source,reports])
	for column: String in expected:
		for descending: bool in [false,true]:
			check(ids(Sort.sorted(source,column,descending,reports)) == expected[column][1 if descending else 0], "Comparaison réelle et inconnus derniers : " + column + str(descending))
	var archive: Array = [reports.z,reports.a,reports.b,{"id":"u"}]
	check(ids(Sort.sorted(archive,"Date du rapport",false,{},true)) == ["a","b","z","u"], "Dates triées chronologiquement, pas comme des textes formatés")
	check(ids(Sort.sorted(archive,"Date du rapport",true,{},true)) == ["z","b","a","u"], "Chronologie inverse avec date inconnue en dernier")
	check(Sort.value({"week":14},"Date du rapport",{},true) == null, "Date incomplète non inventée")
	check(Sort.value({"week":14.5,"season":2},"Date du rapport",{},true) == null, "Date invalide non triée comme une date connue")
	check(Sort.report_status({"potential":70}) == "Non daté" and Sort.value({"id":"u"},"Rapport",{"u":{"potential":70}}) == null,"Un rapport sans date reste inconnu, pas faussement daté")
	for descending: bool in [false,true]:
		check(ids(Sort.sorted([{"id":"b","fee":20},{"id":"a","fee":20},{"id":"u","fee":INF}],"Prime",descending,{})) == ["a","b","u"], "Égalités stables par ID, infini inconnu")
	check(JSON.stringify([source,reports]) == before, "Tri sans mutation des joueurs ou rapports")
	var state := U.defaults()
	check(ids(U.players(source,state,1,true,[],false)) == ids(source), "Helper filtrant seul conserve la source avant le tri final")

func worker() -> bool:
	var until := Time.get_ticks_msec()+45000
	while (app.waiting or app.model.is_empty()) and app.last_error.is_empty() and Time.get_ticks_msec()<until: await process_frame
	await settle()
	return not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok
func enter(button: Button) -> void:
	check(button != null and button.is_visible_in_tree(),"En-tête/action affiché")
	if button == null: return
	button.grab_focus()
	await settle()
	for down: bool in [true,false]:
		var key := InputEventKey.new(); key.keycode=KEY_ENTER; key.pressed=down
		Input.parse_input_event(key); await process_frame
	await settle()
	check(button.has_focus() if is_instance_valid(button) else true,"Le tri conserve le focus clavier")
func fixture(original: Dictionary) -> Dictionary:
	var model := original.duplicate(true)
	var source: Dictionary = model.market[0]
	var rows: Array = []
	var reports: Array = []
	for index in 40:
		var player := source.duplicate(true)
		player.merge({"id":"qa:sort:%02d" % index,"name":"Piste %02d" % index,"pos":"Centre" if index%2 == 0 else "Ailier","age":18+index%19,"rating":40+index,"salary":100+index*100,"fee":index*10000,"available":index%3!=0},true)
		rows.append(player)
		reports.append({"id":"qa-report-%02d" % index,"playerId":player.id,"name":player.name,"pos":player.pos,"age":player.age,"note":player.rating,"potential":50+index,"price":player.fee,"salary":player.salary,"season":1,"week":index,"grade":["A","B","C"][index%3],"assessment":{"stale":index%2==0,"source":"Saison 1 · semaine de suivi " + str(index)}})
	model.market = rows
	model.decisions.recruitment.reports = reports
	return model
func view() -> Control: return app.find_child("CarnetMarket",true,false)
func show(model: Dictionary, archive: bool = false) -> void:
	app.model = model.duplicate(true)
	app.management_ui.market = U.defaults()
	app.management_ui.market.immersive_tab = 3 if archive else 1
	app._navigate("Recrutement")
	await settle()
func screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"Capture " + name)
func run() -> void:
	units()
	root.size = Vector2i(2560,1440)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	check(await worker(),"Moteur réel démarré")
	app.timer.stop()
	app._command("new_career",{"mode":"common","club":29})
	check(await worker(),"Carrière réelle créée")
	if app.model.get("market",[]).is_empty():
		check(false,"Marché réel requis pour les fixtures")
		await app._close(1); return
	if DisplayServer.get_name() != "headless":
		if root.size_changed.is_connected(app._keep_filled_display): root.size_changed.disconnect(app._keep_filled_display)
		if root.focus_entered.is_connected(app._keep_filled_display): root.focus_entered.disconnect(app._keep_filled_display)
		root.mode = Window.MODE_WINDOWED; root.size = Vector2i(2560,1440)
		await settle()
	var model := fixture(app.model)
	var filename: String = app.model.meta.dataDir.path_join("donnees.json")
	var before := FileAccess.get_sha256(filename)
	var commands: int = app.bridge._next_id
	for archive: bool in [false,true]:
		await show(model,archive)
		var page := view()
		var columns: Array = ["Nom","Poste","Date du rapport","Avis"] if archive else ["Nom","Poste","Âge","Niveau","Potentiel","Prime","Salaire","Rapport","Avis"]
		check(page.table_rows.get_child_count() == 40,"Toutes les lignes présentes sans pagination")
		check(app.find_child("MarketPagination",true,false) == null,"Pagination retirée")
		for column: String in columns:
			var button := app.find_child("MarketSort_"+column,true,false) as Button
			for attempt in 2:
				await enter(button)
				check(page._sort_column() == column and button.text.ends_with("↓" if page._sort_descending() else "↑"),"Flèche et champ actifs " + column)
				var expected: Array = page._filtered()
				var actual: Array = page.table_rows.get_children().map(func(row: Control): return str(row.get_meta("player_id")))
				check(actual == expected.map(func(item: Dictionary): return str(item.get("playerId",item.id))),"Ordre rendu correct " + column)
		var scroll: ScrollContainer = page.table_scroll
		var header: Button = app.find_child("MarketSort_Nom",true,false)
		var fixed := header.get_global_rect()
		var dossier: Control = app.find_child("RecruitmentProfile",true,false)
		var fixed_dossier := dossier.get_global_rect()
		var point := scroll.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; root.push_input(motion,true)
		for turn in 12:
			var wheel := InputEventMouseButton.new(); wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel.position=point; wheel.global_position=point; wheel.pressed=true
			root.push_input(wheel,true); await process_frame
		await settle()
		check(scroll.scroll_vertical > 0,"La molette fait défiler la liste interne")
		check(header.get_global_rect() == fixed and dossier.get_global_rect() == fixed_dossier,"En-tête et fiche restent fixes au défilement")
		var last := page.table_rows.get_child(39) as Button
		last.grab_focus(); await settle()
		check(scroll.get_global_rect().intersects(last.get_global_rect()),"Dernière ligne accessible sans page suivante")
		for turn in 8:
			var wheel := InputEventMouseButton.new(); wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel.position=point; wheel.global_position=point; wheel.pressed=true
			root.push_input(wheel,true); await process_frame
		await settle()
		check(header.get_global_rect() == fixed and dossier.get_global_rect() == fixed_dossier,"La molette en bout de liste ne déplace pas les panneaux")
		var identity: String = last.get_meta("player_id")
		await enter(last)
		check(str(dossier.get_meta("player_id")) == identity,"Identité correcte après tri et défilement")
		await screenshot("recrutement-tri-scroll-" + ("rapports" if archive else "joueurs"))
	await show(model)
	view().state.budget_filter = "≤ 100 k€"
	view().state.age_filter = "≤ 22 ans"
	view().state.search = "piste"
	view().state.sort = "Salaire"
	view().state.descending = true
	view()._filter_changed(); await settle()
	var filtered: Array = view()._filtered()
	check(not filtered.is_empty() and filtered.all(func(player: Dictionary): return player.age<=22 and player.fee<=100000),"Filtres appliqués avant le tri numérique")
	check(app.bridge._next_id == commands and FileAccess.get_sha256(filename) == before,"Lecture, tri et molette sans commande ni écriture sportive")
	print("TRIS RECRUTEMENT : %d contrôles ; %d échecs" % [checks,failures.size()])
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"fixtures":"real career then 40 explicit UI rows/reports"},"  "));file.close()
	await app._close(0 if failures.is_empty() else 1)
