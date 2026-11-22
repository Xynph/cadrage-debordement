extends SceneTree
## Rapport du recruteur (option A choisie par Léo le 22/11/2026), Godot réel + worker réel, carrière Monde :
## - lien « Rapport du recruteur → » de la piste choisie → sous-page « recruteur » (retour + Échap) ;
## - lettre de l'avis : « ? » tant que la note au poste est inconnue ; note connue → lettre du barème, rang dans notre effectif ;
## - clic sur la lettre → petite fenêtre visuelle du barème, fermée par ✕ ou Échap ;
## - clic sur une ligne de la liste comparée → fiche (la piste ou notre joueur) ;
## - tuiles : indemnité et salaire → offre au joueur, note et potentiel → fiche de la piste ;
## - pastilles : transfert (offre au joueur), prêt possible / non (lu dans le moteur, clic = fiche).
## Imprime une ligne RAPPORT_RECRUTEUR {checks, failures}. Captures : CD_RAPPORT_RECRUTEUR_CAPTURES=<dossier>.
const Flow = preload("helpers/contextual_flow.gd")
const Pages = preload("res://ui/immersive08/recruitment_pages.gd")
const Rapport = preload("res://ui/immersive08/rapport_recruteur.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var capture_dir := OS.get_environment("CD_RAPPORT_RECRUTEUR_CAPTURES")
var piste_id := ""

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 6) -> void:
	if DisplayServer.get_name() != "headless": await create_timer(.3).timeout
	for frame in frames: await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func command(id: String, payload: Dictionary = {}) -> bool:
	check(app._command(id, payload), "Commande acceptée · " + id)
	await wait_engine()
	return app.bridge.last_response_ok

func node(name: String) -> Control:
	return app.root_content.find_child(name, true, false) as Control if is_instance_valid(app.root_content) else null

func shot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Capture " + name)

func page_kind() -> String:
	var etat: Variant = app.management_ui.get("recrutement_page")
	return str(etat.get("kind", "")) if etat is Dictionary else ""

func press(name: String) -> bool:
	var bouton := node(name) as Button
	if bouton == null or bouton.disabled: return false
	bouton.pressed.emit()
	await settle(10)
	return true

func ouvrir_rapport() -> void:
	Pages.ouvrir(app, "recruteur", {"player_id": piste_id})
	await settle(10)

func piste() -> Dictionary:
	for p: Variant in app.model.get("market", []):
		if p is Dictionary and str(p.get("id", "")) == piste_id: return p
	return {}

func run() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"})
	await Flow.settle_club_meetings(app, self, check)
	await moteur_pret()
	await lien_depuis_la_liste()
	await lettre_inconnue()
	await lettre_connue()
	await bareme()
	await lignes()
	await tuiles_et_pastilles()
	await ouvrir_rapport()
	shot("rapport-recruteur-1920x1080")
	finish()

func finish() -> void:
	print("RAPPORT_RECRUTEUR ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

## Chaque piste du marché porte son prêt (moteur) : {possible, reason}.
func moteur_pret() -> void:
	var marche: Array = app.model.get("market", [])
	check(not marche.is_empty(), "Marché non vide")
	for p: Variant in marche:
		var pret: Variant = p.get("loan")
		check(pret is Dictionary and pret.get("possible") is bool and str(pret.get("reason", "")) in ["jeune", "hors-23", "cadre"], "Prêt lu dans le moteur · " + str(p.get("id", "")))
		if pret is Dictionary and int(p.get("age", 99)) <= 23: check(bool(pret.possible), "Prêt possible pour un jeune · " + str(p.get("id", "")))

## Le lien de la piste choisie ouvre la sous-page ; Échap / retour ramènent à la liste.
func lien_depuis_la_liste() -> void:
	app._navigate("Recrutement", false)
	await settle(10)
	if node("OpenRecruiterReport") == null and node("MarketShowAll") != null: await press("MarketShowAll")
	var lien := node("OpenRecruiterReport") as Button
	check(lien != null, "Lien « Rapport du recruteur » sur la piste choisie")
	if lien == null: return
	piste_id = str(app.management_ui.market.get("player_id", ""))
	lien.pressed.emit()
	await settle(10)
	check(page_kind() == "recruteur" and node("RecrutementSubpage_recruteur") != null, "Lien → sous-page Rapport du recruteur")
	check(node("RapportRecruteurNom") != null and str((node("RapportRecruteurNom") as Button).text) == str(piste().get("name", "")), "Le rapport suit la piste choisie")
	check(await press("RecrutementRetour") and page_kind().is_empty(), "Retour : la liste du recrutement")

## Note au poste inconnue (piste jamais observée) : lettre « ? », pas d'étoiles pour la piste.
func lettre_inconnue() -> void:
	if piste_id.is_empty(): return
	var p := piste()
	if str(p.get("knowledge", {}).get("stage", "")) != "unobserved": return
	await ouvrir_rapport()
	var meta: Dictionary = node("RecrutementSubpage_recruteur").get_meta("rapport", {})
	check(str(meta.get("lettre", "")) == "?", "Piste non observée : lettre « ? » (%s)" % meta.get("lettre", ""))
	check(node("RapportRecruteurConnaissance") != null, "Pastille de connaissance")

## Note connue (piste rendue « bien connue » dans la projection de l'écran) : la meilleure note du poste donne A+ et le rang 1.
func lettre_connue() -> void:
	var p := piste()
	if p.is_empty(): return
	var numero := Rapport._poste(p)
	p.knowledge = {"stage": "deep", "owned": false, "version": 1}
	p.positionRatings = {str(numero): 99}
	await ouvrir_rapport()
	var meta: Dictionary = node("RecrutementSubpage_recruteur").get_meta("rapport", {})
	check(str(meta.get("lettre", "")) == "A+" and int(meta.get("rang", 0)) == 1, "Note connue la meilleure : A+ et rang 1 (%s)" % meta)
	check(node("RapportRecruteurLignePiste") != null, "La piste est insérée dans la liste comparée")
	check(node("RapportRecruteurEtoiles_0") != null, "Étoiles de capacité au poste dans la liste")
	var pour: Array = app.root_content.find_children("RapportRecruteurPour_*", "Button", true, false)
	check(not pour.is_empty(), "Au moins un « Pour »")
	# Barème validé par Léo : écart avec notre n° 1.
	for cas: Array in [[5.0, "A+"], [0.0, "A"], [-3.0, "B+"], [-8.0, "B"], [-12.0, "C+"], [-16.0, "C"], [-17.0, "D"]]:
		check(str(Rapport.lettre(cas[0])[0]) == cas[1], "Barème : écart %s → %s" % cas)

func bareme() -> void:
	check(await press("RapportRecruteurLettre"), "Lettre cliquable")
	check(node("RapportRecruteurBareme") != null and node("Bareme_Aplus") != null, "Lettre → petite fenêtre du barème")
	check(await press("RapportRecruteurBaremeFermer"), "✕ de la petite fenêtre")
	await settle(4)
	check(node("RapportRecruteurBareme") == null, "✕ ferme le barème")
	await press("RapportRecruteurLettre")
	check(PetiteFenetre.fermer_derniere(self), "Échap ferme le barème")
	await settle(4)
	check(node("RapportRecruteurBareme") == null and page_kind() == "recruteur", "Après Échap : toujours sur le rapport")

func lignes() -> void:
	check(await press("RapportRecruteurLignePiste"), "Ligne de la piste cliquable")
	check(app.management_ui.get("fiche_joueur") is Dictionary, "Ligne de la piste → fiche")
	await ouvrir_rapport()
	var ligne := node("RapportRecruteurLigne_1") as Button
	if ligne == null: ligne = node("RapportRecruteurLigne_0") as Button
	check(ligne != null, "Une ligne de notre effectif")
	if ligne == null: return
	ligne.pressed.emit()
	await settle(10)
	check(app.route == "Effectif" and not str(app.selected_player).is_empty(), "Ligne de notre joueur → sa fiche dans l'Effectif (%s)" % app.route)

func tuiles_et_pastilles() -> void:
	for tuile in ["RapportRecruteurIndemniteLien", "RapportRecruteurSalaireLien"]:
		await ouvrir_rapport()
		var ok := await press(tuile)
		check(ok and page_kind() == "negociation", "Tuile %s → offre au joueur (%s)" % [tuile, page_kind()])
	for tuile in ["RapportRecruteurNoteLien", "RapportRecruteurPotentielLien", "RapportRecruteurPretLien", "RapportRecruteurConnaissanceLien"]:
		await ouvrir_rapport()
		var ok := await press(tuile)
		check(ok and app.management_ui.get("fiche_joueur") is Dictionary, "%s → fiche de la piste" % tuile)
	await ouvrir_rapport()
	var pret := node("RapportRecruteurPretTexte") as Label
	var attendu := "Prêt possible" if bool(piste().get("loan", {}).get("possible", false)) else "Prêt non"
	check(pret != null and pret.text == attendu, "Pastille du prêt : « %s »" % attendu)
	check(await press("RapportRecruteurTransfertLien") and page_kind() == "negociation", "Pastille transfert → offre au joueur")
