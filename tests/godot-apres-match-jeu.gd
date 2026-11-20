extends SceneTree
## Après-match dans le vrai jeu (Godot réel + worker réel, carrière Monde) : 1er match joué (fin confiée à l'adjoint,
## causeries passées), l'après-match s'affiche sur la vue du direct avec le classement complet et les autres matchs
## de la journée ; un clic sur un club ouvre sa fiche (scène du match fermée, résultat pas validé), « Continuer » de
## la coque (« Après-match ») ramène à l'après-match, « Valider le résultat » valide la journée.
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func settle(frames := 5) -> void:
	for frame in frames: await process_frame

func apres() -> Control:
	var director: Node = app.contextual_director
	if not director.active() or director.kind != "live": return null
	var vue: Variant = director.view.get("apres_match")
	return vue if vue is Control and is_instance_valid(vue) and (vue as Control).is_visible_in_tree() else null

## Attend l'après-match en passant les causeries comme un joueur (au plus `limite_ms`).
func attendre_apres(limite_ms := 240000) -> Control:
	var limite := Time.get_ticks_msec() + limite_ms
	while Time.get_ticks_msec() < limite:
		if apres() != null: return apres()
		var causerie: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if not app.waiting and causerie is Dictionary:
			app._command("match_talk_continue", {"key": causerie.key, "phase": causerie.phase, "skip": true})
		await settle(10)
	return null

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach): app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	check(await Flow.command_wait(app, self, check, "new_career", {"mode": "world-champ", "club": 102, "start": "premiers-clubs"}), "Carrière Monde créée")
	if is_instance_valid(app.coach): app.coach.close()
	if not await Flow.prepare_match_day(app, self, check): return finish()
	if not await Flow.command_wait(app, self, check, "auto_lineup"): return finish()
	if not await Flow.command_wait(app, self, check, "begin_match"): return finish()
	await Flow._skip_scene_talk(app, self, check)
	app._command("delegate", {})
	var ecran := await attendre_apres()
	check(ecran != null, "L'après-match s'affiche après le match")
	if ecran == null: return finish()
	var live: Dictionary = app.model.get("live", {})
	check(bool(live.get("finished", false)), "Match fini, résultat pas encore validé")
	var journee: Dictionary = live.get("direct", {}).get("journee", {}) if live.get("direct", {}).get("journee") is Dictionary else {}
	var classement: Array = journee.get("classement", [])
	check(classement.size() >= 10, "Classement complet du moteur : %d clubs" % classement.size())
	for r: Variant in classement: check(ecran.find_child("ApresMatchLigne%d" % int(r.get("rang", 0)), true, false) != null, "Ligne du classement n° %d" % int(r.get("rang", 0)))
	check(classement.all(func(r: Dictionary): return r.has("gagnes") and r.has("forme")), "V / N / D et forme projetés par le moteur")
	for k in (journee.get("matchs", []) as Array).size(): check(ecran.find_child("ApresMatchAutreMatch%d" % k, true, false) != null, "Autre match de la journée n° %d" % k)
	check(ecran.find_child("ApresMatchVerdict", true, false) != null and ecran.find_child("ApresMatchValider", true, false) != null, "Verdict et Valider le résultat")
	# Un club du classement : sa fiche s'ouvre, le match reste à valider.
	var adverse := {}
	for r: Variant in classement:
		if r is Dictionary and not bool(r.get("nous", false)): adverse = r
	var lien := ecran.find_child("ApresMatchClubLigne%d" % int(adverse.get("rang", 0)), true, false) as Button
	check(lien != null, "Lien du club au classement")
	if lien == null: return finish()
	lien.pressed.emit()
	await settle(10)
	check(not app.contextual_director.active(), "La scène du match se ferme pendant la consultation")
	check(app.route == app.Immersive.ClubSheet.ROUTE, "Fiche du club ouverte : " + app.route)
	check(app.model.get("live") is Dictionary, "Résultat toujours à valider")
	check(app.primary_text().begins_with("RETOUR À L’APRÈS-MATCH"), "Continuer ramène à l'après-match : " + app.primary_text())
	# Levier « Composition » ouvert depuis la fiche ? non : retour par Continuer.
	# La fiche du club se lit par une commande du moteur (« club_sheet ») : tant qu'elle attend sa réponse, Continuer
	# est ignoré par le jeu (primary_action). On attend la fin de cette lecture, comme un joueur.
	var limite_lecture := Time.get_ticks_msec() + 60000
	while app.waiting and Time.get_ticks_msec() < limite_lecture: await process_frame
	await settle(5)
	check(not app.waiting, "Lecture de la fiche du club terminée")
	app.primary_action()
	# Attente de l'état, pas d'un nombre d'images : la vue du direct est reconstruite (scène 3D, régie).
	var limite_retour := Time.get_ticks_msec() + 30000
	while apres() == null and Time.get_ticks_msec() < limite_retour: await process_frame
	check(apres() != null, "Continuer ramène à l'après-match")
	# Sans délai : l'après-match déjà montré revient dès la reconstruction, sans attendre la régie.
	check(Time.get_ticks_msec() < limite_retour - 25000, "L'après-match revient aussitôt (%d ms)" % (30000 - (limite_retour - Time.get_ticks_msec())))
	# Valider le résultat.
	var valider := apres().find_child("ApresMatchValider", true, false) as Button if apres() != null else null
	check(valider != null and not valider.disabled, "Valider le résultat actif")
	if valider != null:
		valider.pressed.emit()
		var limite := Time.get_ticks_msec() + 120000
		while (app.waiting or app.model.get("live") is Dictionary) and Time.get_ticks_msec() < limite: await process_frame
		await settle(10)
		check(not app.model.get("live") is Dictionary, "Journée validée : le direct est clos")
	finish()

func finish() -> void:
	if failures.is_empty(): print("Après-match jeu Godot · %d contrôles réussis" % checks)
	else: printerr("Après-match jeu Godot · %d échec(s) sur %d" % [failures.size(), checks])
	app.closing = true
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
