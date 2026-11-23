extends SceneTree
## Effectif > Contrats (profil préparé par tests/godot-prolongations-staff-carriere.cjs, vrai moteur) : case
## « Confier aussi les prolongations au staff » cochée par défaut, bilan des décisions du directeur sportif,
## décochée puis recochée par le vrai moteur. Capture 1920×1080 en affichage graphique.
## Contrats en un coup d'œil (idée FM 12, option A) sur le vrai moteur : compteurs d'échéance justes et filtrants, rôle
## promis et conseil du staff envoyés par le moteur sur chaque ligne, clics vers Finances, la fiche et la prolongation.
const Review = preload("res://ui/contract_review.gd")
const Role = preload("res://ui/role_contrat.gd")
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

func lignes() -> Array:
	var rows := app.find_child("ContractReviewRows", true, false)
	return [] if rows == null else rows.get_children().map(func(r): return str(r.get_meta("player_id", "")))

func coup_oeil() -> void:
	var squad: Array = app.model.get("squad", [])
	var ctx: Dictionary = Review.contexte(app.model)
	var attendus := {}
	for p: Dictionary in squad:
		var t := Review.tranche(Review.mois_restants(p, str(ctx.today)))
		attendus[t] = int(attendus.get(t, 0)) + 1
	for t: Array in Review.TRANCHES:
		var id := str(t[0]).replace("+", "p")
		var chiffre := app.find_child("ContractTrancheNombre_" + id, true, false) as Label
		verifier(chiffre != null and chiffre.text == str(int(attendus.get(str(t[0]), 0))), "compteur %s = %d" % [t[1], int(attendus.get(str(t[0]), 0))])
	var avec_role := 0
	var avec_conseil := 0
	for p: Dictionary in squad:
		var ligne := app.find_child(Review.action_id("ContractRow", str(p.id)), true, false)
		verifier(ligne != null, "ligne de " + str(p.get("name", "")))
		if ligne == null: continue
		var role := Role.role(p)
		if not role.is_empty():
			avec_role += 1
			verifier(ligne.find_child("RoleContrat_" + role, true, false) != null, "pastille du rôle %s : %s" % [role, str(p.get("name", ""))])
		var conseil := ligne.find_child(Review.action_id("ContractConseil", str(p.id)), true, false) as Button
		if p.get("conseilStaff") is Dictionary: avec_conseil += 1
		verifier(conseil != null and str(conseil.get_meta("conseil")) == Review.conseil(p), "conseil du moteur affiché : " + str(p.get("name", "")))
	verifier(avec_role >= squad.size() - 4 and avec_conseil >= squad.size() - 4, "rôle et conseil du moteur pour l'effectif sous contrat (%d / %d / %d)" % [avec_role, avec_conseil, squad.size()])
	# Compteur cliqué : le tableau ne garde que la tranche ; second clic : tout revient.
	for t: Array in Review.TRANCHES:
		var n := int(attendus.get(str(t[0]), 0))
		if n == 0: continue
		var bouton := app.find_child("ContractTranche_" + str(t[0]).replace("+", "p"), true, false) as Button
		bouton.pressed.emit(); await poser(12)
		verifier(lignes().size() == n, "filtre %s : %d lignes (%d)" % [t[1], n, lignes().size()])
		bouton = app.find_child("ContractTranche_" + str(t[0]).replace("+", "p"), true, false) as Button
		bouton.pressed.emit(); await poser(12)
		verifier(lignes().size() == squad.size(), "filtre %s retiré" % t[1])
		break
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join("contrats-coup-oeil.png")) == OK, "capture coup d'œil")
	# Part de la masse : Finances.
	var premier: Dictionary = squad[0]
	var part := app.find_child(Review.action_id("ContractShare", str(premier.id)), true, false) as Button
	verifier(part != null, "part de la masse cliquable")
	if part != null:
		part.pressed.emit(); await poser(12)
		verifier(str(app.route) == "Finances", "part de la masse : Finances (" + str(app.route) + ")")
		await onglet_contrats()
	# Conseil « garder » ou « laisser partir » : onglet Contrat de la fiche.
	for p: Dictionary in squad:
		if not Review.conseil(p) in ["garder", "partir"]: continue
		(app.find_child(Review.action_id("ContractConseil", str(p.id)), true, false) as Button).pressed.emit(); await poser(12)
		verifier(app.selected_player == str(p.id) and app.get_meta("immersive08_full_player", false), "conseil : fiche du joueur")
		await onglet_contrats()
		break
	# Prolonger : la proposition s'ouvre sur le bon joueur, rien n'est signé.
	for p: Dictionary in squad:
		if not bool(p.get("renewal", {}).get("available", false)): continue
		(app.find_child(Review.action_id("ContractRenew", str(p.id)), true, false) as Button).pressed.emit(); await poser(12)
		var offre := app.get_node_or_null("ContractOffer") as ConfirmationDialog
		verifier(offre != null and offre.title.contains(str(p.name)), "Prolonger ouvre la proposition du bon joueur")
		if offre != null:
			offre.canceled.emit(); offre.hide(); await poser(8)
		break
	await onglet_contrats()

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
	await coup_oeil()
	case_ds = app.find_child("ContractDelegationStaff", true, false) as CheckBox
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
