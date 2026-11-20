extends SceneTree
## Captures « reception-medicale » : vraie carrière Monde (world-champ), parties jouées par le vrai moteur jusqu'à l'arrivée
## d'un vrai courrier médical (blessure produite par le moteur, rien d'injecté), ouvert dans la Réception ; mail avec le tableau
## de l'infirmerie et panneau « Concerné » en 1920×1080 puis 1280×720. Vérifie aussi qu'aucun nom de blessure n'est coupé.
## Sortie : CD_RECEPTION_MEDICALE_OUTPUT=<dossier>. Imprime une ligne RECEPTION_MEDICALE {checks, failures, mail}.
const Flow = preload("helpers/contextual_flow.gd")
const ClubMail = preload("res://ui/club_mail.gd")
const MAX_CYCLES := 16
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_RECEPTION_MEDICALE_OUTPUT")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 8) -> void:
	if DisplayServer.get_name() != "headless": await create_timer(.3).timeout
	for frame in frames: await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func command(id: String, payload: Dictionary = {}) -> bool:
	check(app._command(id, payload), "Commande acceptée · " + id)
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle(4)
	check(app.bridge.last_response_ok, "Moteur réel · " + id + " · " + app.last_error)
	return app.bridge.last_response_ok

## Courrier médical réel le plus récent : bulletin du médecin sur une blessure (type « blessure »).
func medical_mail() -> Dictionary:
	for mail: Dictionary in ClubMail.mails(app.model):
		if str(mail.get("type", "")) == "blessure" and not str(mail.get("joueur", "")).is_empty(): return mail
	return {}

func play_cycle() -> bool:
	if not await Flow.settle_club_meetings(app, self, check): return false
	if not await Flow.prepare_match_day(app, self, check): return false
	await command("auto_lineup")
	await command("begin_match")
	await Flow.skip_talk(app, self, "pre", check)
	await command("delegate")
	if app.model.get("clubLife", {}).get("matchTalks", {}).get("scene") is Dictionary: await Flow.skip_talk(app, self, "post", check)
	elif app.model.get("live") is Dictionary: await command("finish_round")
	if not await Flow.settle_club_meetings(app, self, check): return false
	return await Flow.finish_match_week(app, self, check, int(app.model.meta.week))

func node(name: String) -> Control:
	return app.root_content.find_child(name, true, false) as Control if is_instance_valid(app.root_content) else null

func shot(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Capture " + name)

func crop(control: Control, name: String) -> void:
	if control == null or output.is_empty() or DisplayServer.get_name() == "headless": return
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer: (parent as ScrollContainer).ensure_control_visible(control)
		parent = parent.get_parent()
	await settle(4)
	var image := root.get_texture().get_image()
	var area := Rect2i(control.get_global_rect().grow(8)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if area.size.x > 8 and area.size.y > 8: check(image.get_region(area).save_png(output.path_join(name + ".png")) == OK, "Capture " + name)

func run() -> void:
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	if not await command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"}): return finish({})
	var mail := medical_mail()
	var cycles := 0
	while mail.is_empty() and cycles < MAX_CYCLES:
		if not await play_cycle(): break
		cycles += 1
		mail = medical_mail()
	check(not mail.is_empty(), "Un vrai courrier médical (blessure du moteur) est arrivé en %d rencontre(s)" % cycles)
	if mail.is_empty(): return finish({})
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = size
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(size)
		app._reset_reception(str(mail.id))
		app._navigate("Réception", false)
		await settle(10)
		app._render()
		await settle(8)
		var tag := "%dx%d" % [size.x, size.y]
		var table := node("InboxInfirmary")
		check(table != null and node("InboxConcernedName") != null, "Tableau de l'infirmerie et rangée « Concerné » affichés · " + tag)
		var injured: Dictionary = {}
		for player: Dictionary in app.model.squad:
			if str(player.id) == str(mail.joueur): injured = player
		var label := ClubMail.injury_label(app.model, injured)
		var cells: Array = []
		if table != null: cells = table.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text.begins_with(label))
		var availability := node("InboxConcernedAvailability") as Label
		if availability != null: cells.append(availability)
		check(cells.size() >= 2, "Blessure « " + label + " » dans le tableau et dans « Concerné » · " + tag)
		for cell: Label in cells:
			check(not cell.clip_text and cell.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and cell.get_minimum_size().y <= cell.size.y + 1.0, "Blessure entièrement visible : " + cell.text + " · " + tag)
		# Le tableau est sous le texte : la zone de lecture défile jusqu'à lui pour la capture.
		var reading := node("InboxReadingScroll") as ScrollContainer
		if reading != null and table != null:
			reading.scroll_vertical = maxi(0, int(table.get_global_rect().position.y - reading.get_global_rect().position.y) + reading.scroll_vertical - 40)
			await settle(4)
		check(node("InboxInfirmaryRow_0") != null, "Au moins une ligne dans le tableau de l'infirmerie · " + tag)
		for reply: Node in app.root_content.find_children("InboxClubMailReply_*", "Button", true, false):
			for part: Node in reply.find_children("*", "Label", true, false):
				check(not (part as Label).clip_text and (part as Label).text_overrun_behavior != TextServer.OVERRUN_TRIM_ELLIPSIS, "Carte de réponse sans ellipse : " + (part as Label).text + " · " + tag)
		shot("reception-medicale-" + tag)
		await crop(table, "reception-medicale-infirmerie-" + tag)
		await crop(node("InboxConcernedName"),"reception-medicale-concerne-" + tag)
	finish(mail)

func finish(mail: Dictionary) -> void:
	print("RECEPTION_MEDICALE ", JSON.stringify({"checks": checks, "failures": failures, "mail": str(mail.get("sujet", ""))}))
	quit(0 if failures.is_empty() else 1)
