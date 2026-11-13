extends SceneTree
## Écran Club (carrière Monde, premier jour) : classement absent avant la 1re journée, abonnés de départ,
## Académie sans « Niveau indisponible » trompeur, bulle de Gabi qui ne masque pas le texte de la page.
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)
func wait_model() -> void:
	var until := Time.get_ticks_msec() + 90000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Moteur réel disponible")
func settle() -> void:
	await create_timer(.3).timeout
	for i in 10: await process_frame
func capture(id: String) -> void:
	var directory := OS.get_environment("CD_CLUB_CAPTURES")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(id + ".png"))
func texts(node: Node, found: Array) -> Array:
	for child in node.get_children():
		if child is Label and child.is_visible_in_tree(): found.append(child.text)
		texts(child, found)
	return found
func run() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await wait_model(); app.timer.stop()
	app._command("new_career", {"club": 0, "mode": "world-champ"}); await wait_model()
	await ContextualFlow.settle_club_meetings(app, self, check)
	check(str(app.model.meta.get("mode")) == "world", "Carrière Monde")
	var fans: Dictionary = app.model.clubLife.clubStrategy.fans
	check(int(fans.subscribers) > 0, "Abonnés initiaux non nuls : " + str(fans.subscribers))
	check(not bool(app.model.club.get("standingsOpen", true)), "Aucun match joué : classement fermé")
	var coach: Control = app.coach
	for route in ["Club", "Bureau", "Effectif"]:
		coach.close(); app._navigate(route); await settle()
		coach.profile.data.step = "territoire"
		var started := Time.get_ticks_msec(); coach.open_tour(); await settle(); await settle()
		print("GABI_MS ", route, " ", Time.get_ticks_msec() - started)
		check(coach.expanded, "Gabi ouverte : " + route)
		var painted: Array[Rect2] = coach._painted_offsets()
		var overlap: float = coach._content_overlap(painted, coach.global_position, coach._content_rects())
		print("GABI ", route, " position=", coach.global_position, " recouvrement_px2=", overlap)
		var rect: Rect2 = coach.get_global_rect()
		check(Rect2(Vector2.ZERO, app.size).grow(1).encloses(rect), "Gabi entière dans l'application : " + route)
		var all := texts(app.root_content, [])
		check(not all.any(func(t): return str(t).contains("1er · 0 pts") or str(t) == "1er / 14"), "Aucun « 1er » sans match joué : " + route)
		if route == "Club":
			check(all.has("Pas encore de classement"), "Club : « Pas encore de classement »")
			check(not all.has("Classement actuel"), "Club : pas de classement actuel")
			var digits := str(int(fans.subscribers))
			check(all.any(func(t): return str(t).strip_edges().length() > 0 and not RegEx.create_from_string("[^0-9\\s\u00a0\u202f]").search(str(t)) and RegEx.create_from_string("[^0-9]").sub(str(t), "", true) == digits), "Club : abonnés affichés (" + digits + ")")
			check(all.has("Non ouverte"), "Club : Académie « Non ouverte » (Espoirs hors Monde)")
			check(not all.has("Niveau indisponible") or app.model.clubLife.academyPathways.get("available", true), "Club : pas de « Niveau indisponible » trompeur")
			var facilities: Control = app.root_content.find_child("ClubFacilityDetails", true, false)
			check(is_instance_valid(facilities), "Club : bloc Infrastructures présent")
			if is_instance_valid(facilities):
				var card: Rect2 = (facilities.get_parent() as Control).get_global_rect()
				var hidden := 0
				for item: Rect2 in coach._content_rects():
					# La 1re ligne (centre d'entraînement) touche seulement la bande de commandes de Gabi : on vérifie le reste.
					if not card.intersects(item) or item.position.y < card.position.y + 85.0: continue
					for offset: Rect2 in painted:
						if Rect2(offset.position + coach.global_position, offset.size).intersects(item): hidden += 1; break
				check(hidden == 0, "Club : Gabi ne masque ni Cellule médicale, ni Académie, ni le bouton des projets (" + str(hidden) + ")")
			check(overlap < 10000.0, "Club : recouvrement de la page inférieur à 0,5 % de l'écran : " + str(overlap))
		await capture("gabi-" + route.to_lower())
	print("CLUB_CHECKS ", checks, " echecs=", failures.size())
	quit(1 if failures.size() > 0 else 0)
