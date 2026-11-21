extends SceneTree
## Carrière Monde, club 102 (au-delà de l'ancienne borne de 55 clubs) : Carrière › Mobilité et recrutement ›
## « Activer les candidatures » réussit et l'onglet montre les candidatures activées.
## Capture 1920 si CD_CANDIDATURES_CAPTURES est posé (fenêtre réelle). Imprime CANDIDATURES_MONDE {checks, failures}.
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var captures := OS.get_environment("CD_CANDIDATURES_CAPTURES")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 8) -> void:
	if DisplayServer.get_name() != "headless": await create_timer(.3).timeout
	for frame in frames: await process_frame

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func capture(nom: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	await settle(10)
	DirAccess.make_dir_recursive_absolute(captures)
	root.get_texture().get_image().save_png(captures.path_join(nom + ".png"))

func visible_node(nom: String) -> Control:
	var n := app.root_content.find_child(nom, true, false) as Control
	return n if n != null and n.is_visible_in_tree() else null

func ouvrir_mobilite() -> void:
	app.management_ui["immersive08_career_tab"] = "details"
	app._navigate("Carrière")
	await settle(12)

func run() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	check(app._command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"}), "Carrière créée")
	await wait_engine()
	await Flow.settle_club_meetings(app, self, check)
	check(int(app.model.get("clubLife", {}).get("managerCareer", {}).get("clubId", -1)) == 102, "Club 102 dirigé")
	await ouvrir_mobilite()
	var bouton := visible_node("ManagerCareerActivate") as Button
	check(bouton != null and not bouton.disabled, "Mobilité : bouton « Activer les candidatures » actif")
	if bouton != null:
		bouton.pressed.emit()
		await wait_engine()
	check(app.bridge.last_response_ok, "Activation acceptée par le moteur : " + str(app.last_error))
	check(not str(app.last_error).contains("incohérentes"), "Aucune erreur « données incohérentes »")
	var data: Dictionary = app.model.get("clubLife", {}).get("managerCareer", {})
	check(data.get("active", false), "Candidatures activées dans la carrière")
	check(int(data.get("originClub", -1)) == 102, "Club d'origine 102")
	await ouvrir_mobilite()
	check(visible_node("ManagerCareerActivate") == null, "Mobilité : bouton d'activation retiré")
	check(visible_node("ManagerCareerDepuis") != null, "Mobilité : mandat affiché")
	check(visible_node("ManagerCareerFermees") != null or visible_node("ManagerCareerOuvertes") != null, "Mobilité : état des candidatures affiché")
	await capture("carriere-mobilite-activee")
	print("CANDIDATURES_MONDE ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
