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
func windows(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child is Window and child.visible and not child.is_queued_for_deletion(): found.append(child)
		found.append_array(windows(child))
	return found
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
	# Le tableau de recrutement et son comparateur appartiennent à la scène dédiée, construite dès 1280x720
	# (ui/immersive08/shell.gd, RICH_FROM_720P) ; le test couvre la plus petite fenêtre et les deux grandes.
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
	app.management_ui.market.immersive_tab = 1  # « Besoins du club » arrive filtré sur le poste prioritaire : on cherche dans tout le marché.
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
		check(button != null and not button.disabled, "Bouton Comparer du Recrutement")
		app.management_ui.compare = []
		button.pressed.emit(); await settle()
		check(app.route == "Comparateur" and app.find_child("ImmersiveComparateur",true,false) != null, "Écran Comparateur ouvert " + str(dimensions))
		check(windows(app).is_empty(), "Le comparateur n'est pas une fenêtre " + str(dimensions))
		var left: OptionButton = app.find_child("ComparateurJoueur0",true,false)
		check(left != null and app.management_ui.compare.size() == 1 and str(left.get_item_metadata(left.selected)) == str(app.management_ui.compare[0]), "Joueur A : la piste ouverte depuis le Recrutement")
		check(app.find_child("ComparateurVide1",true,false) != null, "Emplacement « Choisir un joueur » pour B")
		var right: OptionButton = app.find_child("ComparateurJoueur1",true,false)
		check(right != null and right.item_count > 3, "Sélecteur du joueur B")
		var chosen_a := str(app.management_ui.compare[0])
		right.item_selected.emit(2); await settle()
		check(app.management_ui.compare.size() == 2 and str(app.management_ui.compare[0]) == chosen_a and str(app.management_ui.compare[1]) != chosen_a, "Deux vrais candidats distincts")
		right = app.find_child("ComparateurJoueur1",true,false)
		check(right != null and str(right.get_item_metadata(right.selected)) == str(app.management_ui.compare[1]), "Joueur B lié à son identifiant")
		var rating: Label = app.find_child("RadarSynthese0_Niveau",true,false)
		check(rating != null and rating.get_theme_font_size("font_size") >= 12, "Synthèse lisible (≥ 12 px) " + str(dimensions))
		if dimensions == Vector2i(2560,1440):
			check(right.get_theme_font_size("font_size") == 19, "Sélecteur dense de 19 px en 1440p")
			check(rating.get_theme_font_size("font_size") == 26, "Données de 26 px en 1440p")
		var dessin := app.find_child("RadarDessin",true,false) as Control
		check(dessin != null and dessin.get_global_rect().end.y <= root.size.y, "Radar entier dans l'écran " + str(dimensions))
		check(app.find_children("RadarAxe?","Button",true,false).size() == 8, "Huit axes du radar")
		var axe := app.find_child("RadarAxe7",true,false) as Button
		if axe != null: axe.pressed.emit(); await settle()
		check(app.find_children("RadarFenetreLigne_*_1","Label",true,false).size() == 6, "Conquête : six qualités en barres miroir (%d)" % app.find_children("RadarFenetreLigne_*_1","Label",true,false).size())
		var croix := app.find_child("RadarAxeFenetreFermer",true,false) as Button
		if croix != null: croix.pressed.emit(); await settle()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("comparateur-%d.png" % dimensions.x)) == OK, "Capture comparateur")
		var event := InputEventKey.new(); event.keycode=KEY_ESCAPE; event.pressed=true; root.push_input(event,true)
		event = InputEventKey.new(); event.keycode=KEY_ESCAPE; event.pressed=false; root.push_input(event,true)
		await settle()
		check(app.route == "Recrutement", "Échap ramène au Recrutement " + str(dimensions))
	check(FileAccess.get_sha256(filename) == initial, "Aucune écriture de carrière ou négociation")
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name()},"  ")); file.close()
	print("COMPARAISON RECRUTEMENT : %d contrôles ; %d échecs" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
