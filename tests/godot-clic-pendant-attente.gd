extends SceneTree
## Clic sur une carte de club (Carrière › Mobilité) pendant qu'une requête du moteur tourne : la fiche du club
## cliqué s'ouvre dès la réponse (navigation_controller.reprendre_differee), au lieu d'un clic perdu sans signe
## (constat du 28/11/2026). Godot réel + worker réel, carrière Monde. Imprime une ligne CLIC_ATTENTE {checks, failures}.
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var destinations: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 8) -> void:
	for frame in frames: await process_frame

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	check(app._command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"}), "Carrière créée")
	await wait_engine()
	await Flow.settle_club_meetings(app, self, check)
	await scenario()
	print("CLIC_ATTENTE ", JSON.stringify({"checks": checks, "failures": failures, "destinations": destinations}))
	quit(0 if failures.is_empty() else 1)

func cartes() -> Array:
	return app.root_content.find_children("VitrineClub_*", "Button", true, false)

func scenario() -> void:
	app.management_ui["immersive08_career_tab"] = "details"
	app._navigate("Carrière")
	await settle(12)
	await wait_engine()
	var liste := cartes()
	check(liste.size() >= 2, "Mobilité : au moins deux cartes de club (%d)" % liste.size())
	if liste.size() < 2: return
	var premiere := int(str(liste[0].name).trim_prefix("VitrineClub_"))
	var visee := int(str(liste[1].name).trim_prefix("VitrineClub_"))
	# Requête réelle en cours : fiche d'un premier club ouverte puis retour immédiat à la Carrière (la fiche
	# lance sa lecture du monde), comme un manager qui revient vite et clique une autre carte.
	app.navigation_controller.open_entity({"kind": "club", "id": str(premiere)})
	await settle(2)
	app.management_ui["immersive08_career_tab"] = "details"
	app._navigate("Carrière")
	var provoquee := false
	for essai in 30:
		if app.waiting: provoquee = true; break
		await process_frame
	var carte := app.root_content.find_child("VitrineClub_%d" % visee, true, false) as Button
	destinations.append("attente provoquée : %s, carte : %s" % [provoquee, carte != null])
	check(provoquee, "Une requête du moteur tourne au moment du clic (sinon le scénario ne teste rien)")
	check(carte != null, "Carte du club %d visible pendant l'attente" % visee)
	if carte == null: return
	carte.pressed.emit()
	check(app.route == "Carrière", "Pendant l'attente : la page ne change pas encore (%s)" % app.route)
	await wait_engine()
	await settle(12)
	var fiche: Variant = app.management_ui.get("club_sheet")
	destinations.append("après la réponse : %s" % app.route)
	check(app.route == app.Immersive.ClubSheet.ROUTE and fiche is Dictionary and int(fiche.get("id", -1)) == visee, "Clic gardé : fiche du club %d ouverte à la réponse (%s)" % [visee, app.route])
