extends SceneTree
## Panneau d’attente : aucun affichage pour une attente courte, panneau centré
## (≈ 40 % de la largeur) au passage de jour, décisions légères non bloquantes,
## réponses différentielles du moteur reconstruites à l’identique.
const Overlay = preload("res://ui/command_wait_overlay.gd")
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func overlay_cases() -> void:
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var overlay: Control = Overlay.new()
	host.add_child(overlay)
	overlay.set_context({"kicker": "Passage au jour suivant", "date": "2026-09-07", "flip": true, "club": "TCX", "notes": [{"kind": "tip", "title": "Le conseil de Gabi", "text": "Conseil."}]})
	# Attente courte : rien ne s’affiche, jamais de flash.
	overlay.present("Passage au jour suivant…", true, 0.25)
	await wait(0.12)
	check(overlay.visible and not overlay.panel_visible(), "Délai : le panneau n’apparaît pas avant 250 ms")
	overlay.dismiss()
	await wait(0.3)
	check(not overlay.visible and not overlay.panel_visible(), "Réponse < 250 ms : aucun panneau, aucun voile")
	# Attente longue : panneau centré, ≈ 40 % de la largeur, voile léger.
	overlay.present("Passage au jour suivant…", true, 0.25)
	await wait(0.5)
	check(overlay.panel_visible(), "Attente > 250 ms : le panneau apparaît")
	var frame: Control = overlay.get_node("CommandWaitFrame")
	var ratio: float = frame.size.x / overlay.size.x
	check(ratio > 0.36 and ratio < 0.44, "Panneau ≈ 40 %% de la largeur (%.2f)" % ratio)
	check(absf(frame.position.x + frame.size.x * 0.5 - overlay.size.x * 0.5) < 2.0 and absf(frame.position.y + frame.size.y * 0.5 - overlay.size.y * 0.5) < 2.0, "Panneau centré sur l’écran en cours")
	check(overlay.SCRIM.a < 0.5, "L’écran derrière n’est que légèrement assombri")
	check(str(overlay.get_node("CommandWaitFrame/CommandWaitStatus").text) == "Passage au jour suivant…", "Message lisible et annoncé")
	overlay.dismiss()
	check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Fondu de sortie sans retenir les clics")
	await wait(0.3)
	check(not overlay.visible, "Panneau retiré après le fondu")
	# Mouvements réduits : image fixe.
	overlay.present("Sauvegarde…", false, 0.0)
	await wait(0.2)
	check(overlay.panel_visible() and overlay._elapsed == 0.0, "Mouvements réduits : aucune animation")
	overlay.dismiss()
	await wait(0.2)
	# Dates : calendrier qui tourne au lendemain, changement de mois.
	check(Overlay._shift_date("2026-09-30", 1) == "2026-10-01" and Overlay._date_parts("2026-10-01").month == "OCT.", "Lendemain et mois du calendrier")
	check(Overlay._date_parts("2026-09-07").weekday == "LUNDI", "Jour de la semaine exact")
	check(Overlay._date_parts("n/a").is_empty(), "Date absente : calendrier neutre")
	host.queue_free()

func command(id: String, payload: Dictionary = {}) -> Dictionary:
	var started := Time.get_ticks_msec()
	var seen_panel := false
	var seen_blocking := false
	check(app._command(id, payload), "Commande acceptée · " + id)
	var until := Time.get_ticks_msec() + 60000
	while app.waiting and Time.get_ticks_msec() < until:
		seen_panel = seen_panel or app.command_wait_overlay.panel_visible()
		seen_blocking = seen_blocking or app.command_wait_overlay.visible
		check(not is_instance_valid(app.status) or not str(app.status.text).contains("Traitement de votre décision"), "Plus de texte « Traitement de votre décision »")
		await process_frame
	app.timer.stop()
	var elapsed := Time.get_ticks_msec() - started
	check(app.bridge.last_response_ok, "Worker réel · " + id + " · " + app.last_error)
	for frame in 4: await process_frame
	return {"elapsed": elapsed, "panel": seen_panel, "blocking": seen_blocking}

func run() -> void:
	root.size = Vector2i(1600, 900)
	await overlay_cases()
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach): app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 30000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await command("new_career", {"mode": "common", "club": 0})
	await Flow.settle_club_meetings(app, self, check)
	if is_instance_valid(app.coach): app.coach.close()
	app._navigate("Préparation")
	# Décision légère : ni panneau ni voile, quelle que soit la durée.
	var tactics: Dictionary = app.model.tactics
	var light := await command("set_tactics", {"attack": tactics.attacks[1].id, "defense": tactics.defense})
	check(not light.panel and not light.blocking, "Décision légère : aucun panneau ni blocage (%d ms)" % light.elapsed)
	# Deux décisions rapprochées : la seconde attend son tour au lieu d’être refusée.
	var dialogs_before := app.find_children("*", "AcceptDialog", true, false).size()
	check(app._command("set_tactics", {"attack": tactics.attacks[2].id, "defense": tactics.defense}), "Première décision envoyée")
	check(app._command("auto_lineup"), "Seconde décision mise en file, pas refusée")
	until = Time.get_ticks_msec() + 60000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	check(app.bridge.last_response_ok and app.model.tactics.attack == tactics.attacks[2].id, "Les deux décisions sont appliquées dans l’ordre")
	check(app.find_children("*", "AcceptDialog", true, false).size() == dialogs_before, "Aucune fenêtre de refus")
	# Réponses différentielles : le modèle reconstruit est identique à une réponse complète.
	var reconstructed := JSON.stringify(app.model)
	app.bridge._base_revision = -999
	await command("snapshot")
	check(JSON.stringify(app.model) == reconstructed, "Modèle différentiel identique au modèle complet")
	# Passage de jour : le panneau apparaît si l’attente dépasse le délai.
	var cadence: Dictionary = app.model.meta.get("calendarCadence", {})
	check(cadence.get("canAdvance", false), "Journée réelle disponible")
	var day := await command("advance_day", {"fromDate": app.model.meta.calendarToday})
	if day.elapsed >= 400:
		check(day.panel, "Passage de jour (%d ms) : panneau affiché" % day.elapsed)
	elif day.elapsed < 230:
		check(not day.panel, "Passage de jour très court : aucun panneau")
	check(day.blocking, "Passage de jour : l’écran est protégé pendant le traitement")
	print("CHARGEMENT durées : décision légère %d ms (panneau %s), passage de jour %d ms (panneau %s)" % [light.elapsed, light.panel, day.elapsed, day.panel])
	print("CHARGEMENT : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
