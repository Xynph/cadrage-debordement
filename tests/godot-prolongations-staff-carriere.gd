extends SceneTree
## Effectif > Contrats (profil préparé par tests/godot-prolongations-staff-carriere.cjs, vrai moteur) : case
## « Confier aussi les prolongations au staff » cochée par défaut, bilan des décisions du directeur sportif,
## décochée puis recochée par le vrai moteur. Capture 1920×1080 en affichage graphique.
var app: Control
var sortie := OS.get_environment("CD_PROLONGATIONS_OUTPUT")
var echecs: Array[String] = []
var controles := 0

func _initialize() -> void: call_deferred("executer")

func verifier(ok: bool, message: String) -> void:
	controles += 1
	if not ok:
		echecs.append(message)
		printerr("FAIL: ", message)

func poser(images := 6) -> void:
	for i in images: await process_frame

func attendre_moteur() -> void:
	var limite := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < limite: await process_frame
	verifier(not app.waiting and app.bridge.last_response_ok, "réponse du vrai moteur : " + str(app.last_error))
	await poser(10)

func onglet_contrats() -> void:
	app._navigate("Effectif"); await poser(12)
	var roster: Variant = app.management_ui.get("roster")
	verifier(roster is Dictionary, "état de l'Effectif")
	if roster is Dictionary:
		roster.immersive_tab = 2
		roster.sort = "Échéance"
		app._render(); await poser(20)

func delegation() -> Dictionary:
	var d: Variant = app.model.get("decisions", {}).get("delegation") if app.model.get("decisions") is Dictionary else null
	return d if d is Dictionary else {}

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	await onglet_contrats()
	var case_ds := app.find_child("ContractDelegationStaff", true, false) as CheckBox
	var detail := app.find_child("ContractDelegationDetail", true, false) as Label
	verifier(case_ds != null, "case des prolongations au staff dans l'onglet Contrats")
	verifier(detail != null, "texte sous la case")
	verifier(bool(delegation().get("contracts", false)), "cochée par défaut dans le modèle du moteur")
	var texte := detail.text if detail != null else ""
	if case_ds != null:
		verifier(case_ds.button_pressed and not case_ds.disabled, "case cochée et active")
		verifier(texte.contains("Cette saison :") and texte.contains("Consigne : équilibre."), "bilan des décisions et consigne : « %s »" % texte)
	await poser(14)
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join("prolongations-staff.png")) == OK, "capture")
	if case_ds != null:
		case_ds.button_pressed = false
		await attendre_moteur()
		verifier(delegation().get("contracts", true) == false, "décochée : enregistrée par le moteur")
		await onglet_contrats()
		case_ds = app.find_child("ContractDelegationStaff", true, false) as CheckBox
		verifier(case_ds != null and not case_ds.button_pressed, "décochée après rafraîchissement")
		detail = app.find_child("ContractDelegationDetail", true, false) as Label
		verifier(detail != null and detail.text.begins_with("Tu gères seul"), "texte décochée")
		if case_ds != null:
			case_ds.button_pressed = true
			await attendre_moteur()
			verifier(delegation().get("contracts", false) == true, "recochée : enregistrée par le moteur")
	print("PROLONGATIONS ", JSON.stringify({"controles": controles, "failures": echecs, "detail": texte}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
