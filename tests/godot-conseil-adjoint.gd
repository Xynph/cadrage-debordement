extends SceneTree
## Conseils de Gabi en bulles (idée FM27 n° 35, choix de Léo du 23/11/2026) dans un vrai match Monde, à vitesse maximale :
## - les bulles vivent DANS la carte de l'adjoint, jamais sur le terrain 2D ;
## - aucune bulle quand l'adjoint n'a pas d'avis (pas de conseil bouche-trou), à chaque image relevée ;
## - un clic sur la bulle = conseil accepté (aucun bouton Confirmer), rangé dans la file du prochain arrêt de jeu
##   (auteur 'adjoint'), la bulle passe en attente, puis le moteur l'applique au premier arrêt ;
## - aucun effet chiffré dans les bulles.
## godot-conseil-adjoint.cjs prépare la carrière ; captures final-*.png dans CD_PLANCHE_DIRECT_2D.
const Bulles = preload("res://ui/contextual/match_bulles_adjoint.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var dossier := OS.get_environment("CD_PLANCHE_DIRECT_2D")
var incoherences := 0
var relevees := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("ECHEC : ", message)

func settle(frames: int = 8) -> void:
	for i in frames: await process_frame

func wait_command(limit_ms: int = 60000) -> void:
	var deadline := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle(3)

func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await wait_command()

func surface() -> Control:
	return app.contextual_director.view if app.contextual_director.active() and app.contextual_director.kind == "live" else null

func until(condition: Callable, limit_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + limit_ms
	while not condition.call() and Time.get_ticks_msec() < deadline: await process_frame
	return condition.call()

func capture(nom: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dossier.path_join(nom + ".png"))

func vue_2d(view: Variant) -> bool:
	return is_instance_valid(view) and view.regie != null and view.regie.etat == view.regie.INTER and is_instance_valid(view.regie.between) and view.regie.between.is_visible_in_tree()

func live() -> Dictionary:
	return app.model.get("live", {}) if app.model.get("live") is Dictionary else {}

func arrets() -> Dictionary:
	var p: Variant = live().get("pilotage")
	var a: Variant = p.get("arrets") if p is Dictionary else null
	return a if a is Dictionary else {}

func file_adjoint() -> Array:
	return (arrets().get("file", []) as Array).filter(func(e: Variant) -> bool: return e is Dictionary and str(e.get("auteur", "")) == "adjoint")

## Écran 2D du direct, relu à chaque fois (il peut être reconstruit pendant le match).
func ecran() -> Control:
	var v := surface()
	return v.regie.between if v != null and v.regie != null and is_instance_valid(v.regie.between) else null

func taille(t: Vector2i) -> void:
	root.size = t
	root.content_scale_size = t
	await settle(30)

func bulles_de(between: Variant) -> Array:
	if not is_instance_valid(between): return []
	var boite: Node = between.find_child(Bulles.BOITE, true, false)
	if boite == null or boite.is_queued_for_deletion(): return []
	return boite.get_children().filter(func(n: Node) -> bool: return n is Button and not n.is_queued_for_deletion())

func nouvelles(between: Variant) -> Array:
	return bulles_de(between).filter(func(b: Node) -> bool: return str(b.get_meta("sorte", "")) != "attente")

## Avis de l'adjoint dans le moteur (staff, plan de jeu, changement, conseils acceptés en attente).
func avis_moteur() -> bool:
	var p: Variant = live().get("pilotage")
	if not p is Dictionary: return false
	var staff: Variant = p.get("staff")
	return (staff is Dictionary and not (staff.get("propositions", []) as Array).is_empty()) or (p.get("planAvis") is Array and not (p.planAvis as Array).is_empty()) \
		or p.get("conseilChangement") is Dictionary or not file_adjoint().is_empty()

## Avis de l'adjoint pas encore accepté : sortes présentes dans le moteur.
func avis_nouveau() -> Array:
	var r: Array = []
	var p: Variant = live().get("pilotage")
	if not p is Dictionary: return r
	var staff: Variant = p.get("staff")
	if staff is Dictionary and not (staff.get("propositions", []) as Array).is_empty(): r.append("consigne")
	if p.get("planAvis") is Array and not (p.planAvis as Array).is_empty(): r.append("plan")
	if p.get("conseilChangement") is Dictionary: r.append("changement")
	return r

## Rien sans avis : une bulle n'existe que si le moteur a un avis de l'adjoint (relevé à chaque passage).
func relever(between: Variant) -> void:
	if not is_instance_valid(between) or not (between as Control).is_visible_in_tree() or live().get("finished", false): return
	relevees += 1
	if not bulles_de(between).is_empty() and not avis_moteur(): incoherences += 1

func run() -> void:
	root.size = Vector2i(2560, 1440)
	root.content_scale_size = root.size
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await command("import", {"text": FileAccess.get_file_as_string(dossier.path_join("monde.json"))})
	await command("begin_match")
	var limite := Time.get_ticks_msec() + 120000
	var dites := {}
	while Time.get_ticks_msec() < limite and (surface() == null or surface().regie == null):
		var scene: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if scene is Dictionary and not app.waiting:
			var cle_scene := "%s/%s" % [str(scene.key), str(scene.phase)]
			var options: Array = scene.get("options", []) if scene.get("options") is Array else []
			if not dites.has(cle_scene) and options.size() > 0 and options[0] is Dictionary:
				dites[cle_scene] = true
				await command("match_talk_decide", {"key": scene.key, "phase": scene.phase, "choiceId": str(options[0].get("id", "")), "audience": "group", "playerIds": []})
				await command("match_talk_continue", {"key": scene.key, "phase": scene.phase})
			else: await command("match_talk_continue", {"key": scene.key, "phase": scene.phase, "skip": true})
		await settle(2)
	var view := surface()
	check(view != null and view.regie != null, "Le direct en temps forts s'ouvre")
	if view == null or view.regie == null:
		finir()
		return
	if live().get("paused", false): await command("pause", {"paused": false})
	# Vitesse maximale (jamais en temps réel dans les tests), en petite taille, jusqu'à un avis de Gabi en 2e mi-temps.
	Engine.time_scale = 16.0
	await taille(Vector2i(960, 540))
	var depart := Time.get_ticks_msec()
	var trouve := false
	var palier := -1
	var essai_minute := -10
	while Time.get_ticks_msec() - depart < 720000 and not live().get("finished", false):
		view = surface()
		var scene: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if scene is Dictionary and not app.waiting: await command("match_talk_continue", {"key": scene.key, "phase": scene.phase, "skip": true})
		# Mi-temps (40e) : le direct laisse la place à la causerie et à l'entracte ; on les passe et on attend la reprise.
		if view == null:
			if not app.waiting and live().get("paused", false): await command("pause", {"paused": false})
			await settle(2)
			continue
		relever(ecran())
		var m := int(live().get("minute", 0))
		if floori(m / 5.0) != palier:
			palier = floori(m / 5.0)
			print("CONSEIL_ADJOINT %d′ : 2D %s, bulles %d, avis %s" % [m, str(vue_2d(view)), bulles_de(ecran()).size(), str(avis_nouveau())])
		# Un avis de Gabi en 2e mi-temps : pause, puis l'écran 2D avec ses bulles.
		if m >= 45 and m - essai_minute >= 3 and not avis_nouveau().is_empty():
			essai_minute = m
			print("CONSEIL_ADJOINT %d′ : pause sur un avis %s" % [m, str(avis_nouveau())])
			await command("pause", {"paused": true})
			Engine.time_scale = 1.0
			if await until(func(): return vue_2d(surface()) and not nouvelles(ecran()).is_empty(), 30000):
				trouve = true
				break
			Engine.time_scale = 16.0
			await command("pause", {"paused": false})
		await settle(2)
	print("CONSEIL_ADJOINT minute %d atteinte en %d s, %d relevés" % [int(live().get("minute", 0)), (Time.get_ticks_msec() - depart) / 1000, relevees])
	# Le nombre de relevés dépend de la vitesse du runner (49 en CI pour 58 minutes) : on exige un échantillon
	# suffisant sur les deux mi-temps, pas un compte fixe.
	check(relevees >= 20 and incoherences == 0, "aucune bulle sans avis de l'adjoint (%d incohérences sur %d relevés)" % [incoherences, relevees])
	check(trouve, "Gabi donne au moins un conseil en 2e mi-temps")
	if not trouve or surface() == null:
		finir()
		return
	view = surface()
	Engine.time_scale = 1.0
	await taille(Vector2i(1920, 1080))
	await until(func(): return vue_2d(surface()) and not nouvelles(ecran()).is_empty(), 30000)
	if nouvelles(ecran()).is_empty():
		finir()
		return
	await verifier_place(ecran(), "1920")
	await capture("final-1920")
	await taille(Vector2i(2560, 1440))
	await verifier_place(ecran(), "2560")
	await capture("final-2560")
	await taille(Vector2i(1920, 1080))
	# Un clic sur la bulle : accepté tout de suite (aucun Confirmer), en attente du prochain arrêt de jeu.
	var bulle: Button = nouvelles(ecran())[0]
	var sorte := str(bulle.get_meta("sorte", ""))
	var avant := nouvelles(ecran()).size()
	bulle.pressed.emit()
	await wait_command()
	await settle(10)
	check(not file_adjoint().is_empty(), "clic sur la bulle (%s) : conseil rangé dans la file du prochain arrêt, auteur adjoint" % sorte)
	check(bulles_de(ecran()).any(func(b: Node) -> bool: return str(b.get_meta("sorte", "")) == "attente"), "la bulle acceptée passe en attente (⧗)")
	check(nouvelles(ecran()).size() == avant - 1, "la bulle acceptée quitte les conseils")
	await capture("final-attente-1920")
	# ✕ sur un autre conseil : écarté.
	if not nouvelles(ecran()).is_empty():
		var reste := nouvelles(ecran()).size()
		var croix := nouvelles(ecran())[0].find_child("MatchBetweenAdviceBubbleClose_*", true, false) as Button
		check(croix != null, "✕ sur la bulle")
		if croix != null:
			croix.pressed.emit()
			await settle(6)
			check(nouvelles(ecran()).size() == reste - 1, "✕ : conseil écarté")
	# Le match reprend : le conseil part au prochain arrêt de jeu, puis la bulle d'attente disparaît.
	await command("pause", {"paused": false})
	Engine.time_scale = 8.0
	check(await until(func(): return file_adjoint().is_empty() or live().get("finished", false), 180000), "la file de Gabi part au prochain arrêt de jeu")
	Engine.time_scale = 1.0
	var appliques: Array = arrets().get("appliques", []) if arrets().get("appliques") is Array else []
	check(appliques.any(func(x: Variant) -> bool: return x is Dictionary and str(x.get("auteur", "")) == "adjoint"), "conseil de Gabi appliqué par le moteur à l'arrêt de jeu")
	await settle(20)
	check(not bulles_de(ecran()).any(func(b: Node) -> bool: return str(b.get_meta("sorte", "")) == "attente"), "plus de bulle d'attente une fois appliqué")
	finir()

## Bulles dans la carte de Gabi (jamais sur le terrain), dans l'écran, sans bouton Confirmer ni effet chiffré.
func verifier_place(_b: Variant, cadre: String) -> void:
	await settle(10)
	var between: Control = ecran()
	var carte: Control = between.get("adjoint_cadre")
	var boite := between.find_child(Bulles.BOITE, true, false) as Control
	check(boite != null and carte != null and carte.is_ancestor_of(boite), cadre + " : bulles dans la carte de Gabi")
	if boite == null: return
	check(not boite.get_global_rect().intersects(between.terrain.get_global_rect()), cadre + " : rien sur le terrain 2D")
	check(Rect2(Vector2.ZERO, Vector2(root.size)).grow(1.0).encloses(carte.get_global_rect()), cadre + " : carte de Gabi dans l'écran")
	for b: Node in bulles_de(between):
		check(carte.get_global_rect().grow(2.0).encloses((b as Control).get_global_rect()), cadre + " : bulle %s dans la carte" % b.name)
	check(between.find_children("*Confirmer*", "", true, false).is_empty() and between.find_children("*Valider*", "", true, false).is_empty(), cadre + " : aucun bouton Confirmer")
	var chiffres_effet: Array = []
	for l: Node in boite.find_children("*", "Label", true, false):
		var t := (l as Label).text
		if t.begins_with("+") or t.begins_with("−") or t.begins_with("-") or t.contains("pts"): chiffres_effet.append(t)
	check(chiffres_effet.is_empty(), cadre + " : aucun effet chiffré dans les bulles " + str(chiffres_effet))

func finir() -> void:
	print("CONSEIL_ADJOINT %d controles, %d echec" % [checks, failures.size()])
	for f in failures: print("  - ", f)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
