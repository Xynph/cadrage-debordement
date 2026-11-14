extends SceneTree
## Écran Club (carrière Monde, premier jour) : classement absent avant la 1re journée, abonnés de départ,
## Académie sans « Niveau indisponible » trompeur, Gabi (bandeau du haut) qui ne masque pas le texte de la page.
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
		check(overlap >= 0.0, "Recouvrement mesuré (scène assombrie) : " + route)
		var all := texts(app.root_content, [])
		check(not all.any(func(t): return str(t).contains("1er · 0 pts") or str(t) == "1er / 14"), "Aucun « 1er » sans match joué : " + route)
		if route == "Club":
			check(all.has("Pas encore de classement"), "Club : « Pas encore de classement »")
			check(not all.has("Classement actuel"), "Club : pas de classement actuel")
			var digits := str(int(fans.subscribers))
			check(all.any(func(t): return str(t).strip_edges().length() > 0 and not RegEx.create_from_string("[^0-9\\s\u00a0\u202f]").search(str(t)) and RegEx.create_from_string("[^0-9]").sub(str(t), "", true) == digits), "Club : abonnés affichés (" + digits + ")")
			var suivi: Dictionary = app.model.clubLife.academyFollowUp
			check(not all.has("Non ouverte") and not all.any(func(t): return str(t).contains("à venir en carrière Monde")), "Club : jamais « Non ouverte » : le centre existe en Monde")
			var attendu := "%d Crabos · %d Espoirs" % [int(suivi.crabos.count), int(suivi.espoirs.count)]
			check(all.has(attendu), "Club : Académie « " + attendu + " » (même état que la page Formation)")
			check(all.has("%d / %d" % [int(suivi.total), int(suivi.capacity)]), "Club : Académie « " + str(suivi.total) + " / " + str(suivi.capacity) + " » places")
			check(not all.has("Niveau indisponible") or app.model.clubLife.academyPathways.get("available", true), "Club : pas de « Niveau indisponible » trompeur")
			check(is_instance_valid(app.root_content.find_child("ClubFacilityDetails", true, false)), "Club : bloc Infrastructures présent")
		# Gabi adjoint (13/11/2026) : la visite guidée est une courte scène, écran assombri (voile). Ce qui ne
		# doit jamais masquer la page, c'est Gabi au quotidien : depuis le 14/11/2026 il vit dans le bandeau du
		# haut (le médaillon du coin bas droit est retiré), une fois la scène refermée.
		check(coach._voile.visible, "Visite guidée : écran assombri derrière Gabi : " + route)
		coach.close(); await settle()
		check(not coach._voile.visible, "Visite refermée : plus de voile : " + route)
		var zone: Control = app.root_content.find_child("GabiBandeau", true, false)
		check(zone != null and zone.is_visible_in_tree(), "Gabi dans le bandeau : " + route)
		if zone != null:
			var band := zone.get_global_rect()
			var topbar: Control = app.root_content.find_child("ImmersiveTopbar", true, false)
			check(topbar != null and topbar.get_global_rect().grow(1).encloses(band), "Gabi dans le bandeau du haut, pas sur la page : " + route)
			check(band.end.y <= app.body_scroll.get_global_rect().position.y + 1, "Gabi au-dessus de l'espace de travail : " + route)
			var covered := 0
			for item: Rect2 in coach._content_rects():
				if band.intersects(item) and not band.grow(1).encloses(item): covered += 1
			check(covered == 0, "Gabi : aucun texte ni bouton de la page recouvert (" + str(covered) + ") : " + route)
		for face: Node in app.find_children("GabiMedaillon", "", true, false):
			check(zone != null and zone.is_ancestor_of(face), "Plus de médaillon dans le coin : le visage de Gabi est dans le bandeau : " + route)
		await capture("gabi-" + route.to_lower())
	print("CLUB_CHECKS ", checks, " echecs=", failures.size())
	quit(1 if failures.size() > 0 else 0)
