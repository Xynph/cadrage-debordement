extends SceneTree
var failures: Array[String] = []
var checks := 0
var memory: Script
var app: MemoryHost

class MemoryHost extends Control:
	var model: Dictionary = {}
	var management_ui: Dictionary = {}
	var accent := Color("b23b44")
	var view: Control
	var memory: Script
	func _render() -> void:
		if is_instance_valid(view):
			remove_child(view)
			view.queue_free()
		view = memory.build(self)
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(view)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for i in 5: await process_frame
func keyboard(control: Node, keycode: Key) -> void:
	control.grab_focus()
	await settle()
	check(control.has_focus(), "Focus clavier " + str(control.name))
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.pressed = pressed
		key.physical_keycode = keycode
		root.push_input(key, true)
		await process_frame
	await settle()
func all_text(node: Node) -> String:
	var output := str(node.text) + "\n" if node is Label else ""
	for child in node.get_children(): output += all_text(child)
	return output
func capture(label: String) -> void:
	if OS.get_environment("CD_CLUB_MEMORY_GRAPHICS") != "1": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("CD_CLUB_MEMORY_ARTIFACTS").path_join(label + ".png")) == OK, "Capture " + label)
func run() -> void:
	root.gui_embed_subwindows = true
	memory = load("res://ui/club_memory_view.gd")
	var real: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_CLUB_MEMORY_MODEL")))
	var before := JSON.stringify(real)
	var projected: Dictionary = memory.project(real, int(real.club.id))
	check(projected.seasons.size() == 1, "Une saison réelle conservée")
	check(projected.seasons[0].league_id == "accession" and projected.seasons[0].rank == 15, "Rang 15 en Accession du checkpoint réel S2")
	check(JSON.stringify(real) == before, "Projection pure sur la vraie fixture")
	var multi: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_CLUB_MEMORY_MULTI")))
	var multi_before := JSON.stringify(multi)
	var multi_projected: Dictionary = memory.project(multi, int(multi.club.id))
	check(multi_projected.seasons.size() == 5, "Cinq saisons réelles du worker S6")
	for year: Dictionary in multi_projected.seasons:
		for archive: Dictionary in multi.archives.seasons:
			if int(archive.season) != int(year.season): continue
			var ranks: Array = archive.standings[year.league_id]
			check(int(ranks[int(year.rank)-1]) == int(multi.club.id), "Rang exact de la vraie saison " + str(year.season))
	check(JSON.stringify(multi) == multi_before, "Projection multisaions pure")
	var sample := real.duplicate(true)
	# Projection limite synthétique explicite : identités homonymes, deux divisions, mobilité.
	sample.club = {"id":29,"name":"Nom périmé"}
	sample.meta.catalogue = [{"id":29,"name":"Identité du pack"},{"id":10,"name":"Identité du pack"},{"id":28,"name":"Ancien club du pack"}]
	sample.leagues = [{"id":"elite","rows":[{"id":29,"presentation":{"name":"Identité du pack"}}]}]
	sample.archives.seasons = [{"season":1,"standings":{"accession":[29,10]},"champions":[{"leagueId":"accession","clubId":29}],"movement":{"promoted":[29],"relegated":[]}},{"season":2,"standings":{"elite":[10,29]},"champions":[{"leagueId":"elite","clubId":10}],"movement":{"promoted":[],"relegated":[29]}}]
	sample.clubLife.managerCareer = {"history":[{"fromClub":28,"toClub":29,"departureSeason":1,"arrivalSeason":2}],"currentFrom":2}
	sample.clubLife.clubWorld.events = [{"id":"ours","a":29,"b":10,"home":24,"away":18,"winner":29,"season":2,"round":3,"phase":"league","type":"surprise","clubId":10,"reaction":"Fiction du banc","pressure":99,"tension":80},{"id":"unrelated","a":28,"b":10,"home":3,"away":0,"season":1,"round":0,"phase":"league"}]
	before = JSON.stringify(sample)
	projected = memory.project(sample,29)
	check(projected.club_name == "Identité du pack", "Identité du pack actif par ID")
	check(projected.seasons.size() == 2 and projected.seasons[0].season == 2, "Chronologie décroissante stable")
	check(projected.seasons[1].rank == 1 and projected.seasons[1].league_id == "accession" and projected.seasons[1].promoted and projected.seasons[1].titles == ["accession"], "Titre et montée distincts du rang")
	check(projected.seasons[0].rank == 2 and projected.seasons[0].relegated, "Descente conservée par ID")
	check(projected.events.size() == 1 and projected.events[0].reaction == "Fiction du banc", "Rencontres du club seulement, réaction distincte")
	check(projected.manager_history.size() == 1 and projected.manager_history[0].from_name == "Ancien club du pack", "Parcours du coach distinct et noms résolus")
	check(JSON.stringify(sample) == before, "Projection limite sans mutation")
	var renamed := sample.duplicate(true)
	renamed.leagues[0].rows[0].presentation.name = "Pack modifié"
	check(memory.project(renamed,29).club_name == "Pack modifié", "Changement de pack pris en compte")
	check(memory.project(sample,10).events.size() == 2, "Homonymes distincts par ID")
	app = MemoryHost.new()
	app.memory = memory
	app.model = sample
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		root.size = resolution
		app.model = multi
		app.management_ui.clear()
		app._render()
		await settle()
		check(app.view.find_child("ClubMemoryComparison",true,false).get_child_count() == 2, "Deux saisons réelles côte à côte")
		check(all_text(app.view.find_child("ClubMemoryComparison",true,false)).contains("Saison 2030-2031") and all_text(app.view.find_child("ClubMemoryComparison",true,false)).contains("Saison 2029-2030"), "Deux années réelles sélectionnées par défaut")
		await capture("histoire-reelle-%d" % resolution.x)
		app.model = sample
		app.management_ui.clear()
		app._render()
		await settle()
		check(root.size == resolution and app.view.size.is_equal_approx(app.get_viewport_rect().size), "Lecture à " + str(resolution))
		check(app.view.get_combined_minimum_size().x <= app.get_viewport_rect().size.x, "Largeur sans débordement " + str(resolution))
		var select: OptionButton = app.view.find_child("ClubMemorySeasonA",true,false)
		check(select != null and select.item_count == 2, "Deux saisons sélectionnables")
		await keyboard(select,KEY_SPACE)
		check(select.get_popup().visible, "Sélecteur ouvert au clavier")
		await keyboard(select.get_popup(),KEY_DOWN)
		await keyboard(select.get_popup(),KEY_ENTER)
		await settle()
		check(int(app.management_ui.get("club_memory_season_a",-1)) == 1, "Choix saison A conservé")
		app._render()
		await settle()
		check(app.view.find_child("ClubMemorySeasonA",true,false).get_selected_id() == 1, "Choix stable au rebuild")
		var second: OptionButton = app.view.find_child("ClubMemorySeasonB",true,false)
		await keyboard(second,KEY_SPACE)
		await keyboard(second.get_popup(),KEY_UP)
		await keyboard(second.get_popup(),KEY_ENTER)
		check(int(app.management_ui.get("club_memory_season_b",-1)) == 2, "Deuxième saison changée au clavier")
		check(app.view.find_child("ClubMemoryComparison",true,false).get_child_count() == 2, "Comparatif restitué après choix des deux saisons")
		var text := all_text(app.view)
		check(text.contains("Dans sa division") and text.contains("Fiction du banc") and text.contains("Réaction du banc"), "Réaction conservée et limites de division affichées")
		await capture("histoire-projection-limite-%d" % resolution.x)
		app.management_ui.clear()
	check(JSON.stringify(sample) == before, "Construction et clavier sans mutation de modèle")
	check(JSON.stringify(multi) == multi_before, "Construction multisaions sans mutation de modèle")
	app.model = real
	app._render()
	await settle()
	check(all_text(app.view).contains("deux saisons"), "Une seule saison : comparaison indisponible")
	app.model = {"club":{"id":29,"name":"Club sans archive"},"meta":{"engine":"native-rugby"}}
	app._render()
	await settle()
	check(all_text(app.view).contains("Aucune saison") and app.view.find_child("ClubMemoryComparison",true,false) == null, "Archives absentes : état vide sans comparaison inventée")
	app.model = {"club":{"id":0},"meta":{"engine":"historical"}}
	app._render()
	await settle()
	check(all_text(app.view).contains("historique à 14") and all_text(app.view).contains("Aucune saison"), "Ancien format et archives absentes explicites")
	var file := FileAccess.open(OS.get_environment("CD_CLUB_MEMORY_ARTIFACTS").path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	file.close()
	print("HISTOIRE DU CLUB : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
