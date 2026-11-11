extends SceneTree
const Comparison = preload("res://ui/immersive08/recruitment_comparison.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_COMPARISON_OUTPUT")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for i in 8: await process_frame
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(not app.waiting and app.bridge.last_response_ok, "Vraie commande : " + id)
func run() -> void:
	check(Comparison.delta(61, 74) == "+13", "Écart B moins A positif")
	check(Comparison.delta(74, 61) == "-13", "Écart B moins A négatif")
	check(Comparison.delta(0, 0) == "0", "Zéro connu n'est pas une absence")
	check(Comparison.delta(null, 61) == "Non comparable", "Valeur absente non remplacée par zéro")
	check(Comparison.delta(NAN, 61) == "Non comparable", "Nombre invalide refusé")
	var candidates: Array = [{"id":"a", "name":"Émile Dupont", "pos":"Pilier"}, {"id":"b", "name":"Autre", "pos":"Centre"}, {"id":"c", "name":"Relève", "pos":"Pilier"}]
	check(Comparison.initial_ids(candidates, "a", []) == ["a", "c"], "Second choix même poste avant autres postes")
	check(Comparison.initial_ids(candidates, "a", ["a", "b"]) == ["a", "b"], "Comparaison choisie conservée par identifiant")
	check(Comparison.candidates(candidates, "emile", "", []).size() == 1, "Recherche accentuée insensible aux accents")
	check(Comparison.candidates(candidates, "introuvable", "", ["a", "c"]).size() == 2, "Filtres ne perdent pas les pistes choisies")
	check(Comparison.value({"id":"a", "potential":99}, "potential", {}) == null, "Potentiel absent du rapport non inventé")
	var resolutions: Array[Vector2i] = [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]
	var requested := OS.get_environment("QA_RESOLUTION")
	if not requested.is_empty():
		var dimension := requested.split("x")
		if dimension.size() == 2:
			resolutions = [Vector2i(int(dimension[0]),int(dimension[1]))]
	root.size = resolutions[0]
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	var deadline := Time.get_ticks_msec()+30000
	while app.model.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.model.is_empty(), "Moteur prêt")
	app.timer.stop()
	await command("new_career", {"mode":"common", "club":29})
	app._navigate("Recrutement"); await settle()
	var filename := str(app.model.meta.dataDir).path_join("donnees.json")
	var initial := FileAccess.get_sha256(filename)
	var page: Control = app.find_child("CarnetMarket",true,false)
	check(page != null, "Vraie page Recrutement")
	if page == null: await app._close(1); return
	var source: Array = app.model.market
	check(source.size() > 1, "Vrai marché à plusieurs pistes")
	var available := source.filter(func(p): return p.get("available",false)).size()
	page.state.available = "Indisponibles"
	check(page._filtered().size() == source.size()-available, "Filtre indisponibles lit uniquement le moteur")
	page.state.available = "Tous"
	var target: Dictionary = source[0]
	page.state.search = str(target.pos) + " " + str(target.name).split(" ")[0]
	check(page._filtered().any(func(p): return p.id == target.id), "Recherche combine nom et poste dans un ordre libre")
	page.state.navigation_id = str(target.id)
	page.state.search = "aucun-resultat-possible"
	check(page._filtered().any(func(p): return p.id == target.id), "Navigation vers identifiant prioritaire conserve son ancien contrat")
	page.state.search = ""
	page.state.navigation_id = ""
	for dimensions in resolutions:
		root.size = dimensions
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(dimensions)
		await settle()
		app._render(false); await settle()
		var button: Button = app.find_child("CompareMarket",true,false)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("recherche-%d.png" % dimensions.x)) == OK, "Capture recherche")
		button.pressed.emit(); await settle()
		var dialog: AcceptDialog = app.find_child("MarketComparison",true,false)
		check(dialog != null and dialog.visible, "Comparateur ouvert " + str(dimensions))
		if dimensions == Vector2i(2560,1440):
			check(dialog.size.x >= 1850 and dialog.size.y >= 1150, "Surface de lecture confortable en 1440p")
			var hero: Label = dialog.find_child("MarketComparisonHeading",true,false)
			check(hero.get_theme_font_size("font_size") == 28, "Titre dense de 28 px en 1440p")
		var left: OptionButton = dialog.find_child("MarketComparisonPlayer0",true,false)
		var right: OptionButton = dialog.find_child("MarketComparisonPlayer1",true,false)
		check(left.selected > 0 and right.selected > 0 and left.get_item_metadata(left.selected) != right.get_item_metadata(right.selected), "Deux vrais candidats distincts préselectionnés")
		check(right.has_focus(), "Focus initial sur choix B")
		if dimensions == Vector2i(2560,1440):
			check(right.get_theme_font_size("font_size") == 20, "Sélecteur dense de 20 px en 1440p")
			var rating_row: HBoxContainer = dialog.find_child("MarketComparisonRow_rating",true,false)
			check(rating_row.get_child(1).get_theme_font_size("font_size") == 20, "Données denses de 20 px en 1440p")
		var tabs: TabContainer = dialog.find_child("MarketComparisonTabs",true,false)
		check(tabs != null and tabs.get_tab_count() == 2, "Synthèse et attributs séparés")
		check(dialog.find_children("MarketComparisonRow_attribute_*", "HBoxContainer", true,false).size() == 36, "Les 36 attributs restent consultables par familles")
		var search: LineEdit = dialog.find_child("MarketComparisonSearch",true,false)
		var selected_left: Variant = left.get_item_metadata(left.selected)
		var selected_right: Variant = right.get_item_metadata(right.selected)
		search.text = "aucun-resultat-possible"; search.text_changed.emit(search.text); await settle()
		check(left.item_count == 3 and right.item_count == 3, "Recherche conserve exactement les deux choix")
		check(left.get_item_metadata(left.selected) == selected_left and right.get_item_metadata(right.selected) == selected_right, "Choix stables après recherche")
		search.text = ""; search.text_changed.emit(""); await settle()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("comparaison-%d.png" % dimensions.x)) == OK, "Capture comparaison")
		tabs.current_tab = 1; await settle()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("attributs-%d.png" % dimensions.x)) == OK, "Capture attributs")
		var last_group := dialog.find_child("MarketComparisonGroupJump3",true,false) as Button
		check(last_group != null, "Accès direct aux quatre familles")
		last_group.pressed.emit(); await settle()
		var group_heading: Control = dialog.find_child("ComparisonAttributeGroup3",true,false)
		check(group_heading.has_focus(), "Raccourci famille restitue le focus dans la section")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("conquete-%d.png" % dimensions.x)) == OK, "Capture dernière famille")
		var event := InputEventKey.new(); event.keycode=KEY_ESCAPE; event.pressed=true; root.push_input(event,true)
		await settle()
		check(not is_instance_valid(dialog) or not dialog.visible, "Échap ferme la consultation")
		check(button.has_focus(), "Retour du focus au bouton Comparer")
	check(FileAccess.get_sha256(filename) == initial, "Aucune écriture de carrière ou négociation")
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name()},"  ")); file.close()
	print("COMPARAISON RECRUTEMENT : %d contrôles ; %d échecs" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
