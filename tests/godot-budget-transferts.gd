extends SceneTree
## Budget de transferts dans le vrai jeu (profil préparé par tests/godot-budget-transferts.cjs, vrai moteur) :
## en-têtes Recrutement et Finances (« Disponible pour les transferts » = finance.transferBudget.disponible),
## puis une offre hors budget : bouton d'envoi grisé et raison écrite visible. Captures 1920×1080 en affichage graphique.
const G = preload("res://ui/game_skin.gd")
const LIBELLE := "Disponible pour les transferts"
var app: Control
var sortie := OS.get_environment("CD_BUDGET_OUTPUT")
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

func capturer(nom: String) -> void:
	await poser(14)
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join(nom)) == OK, "capture " + nom)

func texte(nom: String) -> String:
	var noeud := app.find_child(nom, true, false)
	if noeud is Label: return (noeud as Label).text
	if noeud is Button: return (noeud as Button).text
	return ""

func visible_a_l_ecran(nom: String) -> bool:
	var noeud := app.find_child(nom, true, false) as CanvasItem
	return noeud != null and noeud.is_visible_in_tree()

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	var budget: Variant = app.model.get("finance", {}).get("transferBudget")
	verifier(budget is Dictionary and bool(budget.get("actif", false)), "budget de transferts actif dans le modèle : " + str(budget))
	if not budget is Dictionary: budget = {}
	var reste := G.euros(budget.get("disponible", 0))
	var enveloppe := G.euros(budget.get("enveloppe", 0))
	# 1. Recrutement : bandeau en tête, à côté de la priorité du poste.
	app._navigate("Recrutement"); await poser(20)
	verifier(app.find_child("CarnetMarket", true, false) != null, "écran Recrutement ouvert")
	verifier(texte("RecruitmentTransferBudgetLabel") == LIBELLE, "libellé Recrutement : « %s »" % texte("RecruitmentTransferBudgetLabel"))
	verifier(texte("RecruitmentTransferBudgetAmount") == reste, "montant Recrutement « %s » = disponible « %s »" % [texte("RecruitmentTransferBudgetAmount"), reste])
	verifier(texte("RecruitmentTransferBudgetAllocated").contains(enveloppe), "enveloppe allouée au Recrutement : " + texte("RecruitmentTransferBudgetAllocated"))
	verifier(visible_a_l_ecran("RecruitmentTransferBudget"), "bandeau du budget visible")
	var bandeau := app.find_child("RecruitmentTransferBudget", true, false) as Control
	if bandeau != null:
		verifier(bandeau.tooltip_text.contains("Trésorerie du club") and bandeau.tooltip_text.contains("Dépensé") and bandeau.tooltip_text.contains("Reconstitué"), "infobulle trésorerie / dépensé / reconstitué : " + bandeau.tooltip_text)
		var montant := app.find_child("RecruitmentTransferBudgetAmount", true, false) as Label
		if montant != null:
			var police := montant.get_theme_font("font")
			var largeur := police.get_string_size(montant.text, HORIZONTAL_ALIGNMENT_LEFT, -1, montant.get_theme_font_size("font_size")).x
			verifier(largeur <= montant.size.x + 1.0, "montant Recrutement non tronqué (%.0f ≤ %.0f)" % [largeur, montant.size.x])
		var priorite := app.find_child("MarketPriorityFilter", true, false) as Control
		if priorite != null: verifier(not bandeau.get_global_rect().intersects(priorite.get_global_rect()), "bandeau sans chevauchement avec la priorité du poste")
		var comparer := app.find_child("CompareMarket", true, false) as Control
		if comparer != null: verifier(not bandeau.get_global_rect().intersects(comparer.get_global_rect()), "bandeau sans chevauchement avec « Comparer »")
	await capturer("budget-recrutement.png")
	# 2. Finances : tuile à côté de la trésorerie.
	app.management_ui["immersive08_finance_tab"] = "summary"
	app._navigate("Finances"); await poser(20)
	var tuile := app.find_child("FinanceMetric1", true, false)
	var titre: Label = null
	if tuile != null: titre = tuile.find_child("CardTitle", true, false) as Label
	verifier(titre != null and titre.text == LIBELLE.to_upper(), "libellé Finances : « %s »" % (titre.text if titre != null else ""))
	verifier(texte("FinanceTransferBudgetAmount") == reste, "montant Finances « %s » = disponible « %s »" % [texte("FinanceTransferBudgetAmount"), reste])
	verifier(texte("FinanceTransferBudgetAllocated").contains(enveloppe), "enveloppe allouée aux Finances : " + texte("FinanceTransferBudgetAllocated"))
	verifier(app.find_child("FinanceMetric0", true, false) != null, "tuile Trésorerie conservée")
	await capturer("budget-finances.png")
	# 3. Offre hors budget : un joueur dont la prime dépasse le disponible ; le moteur rend le devis indisponible.
	var hors_budget: Dictionary = {}
	for joueur: Dictionary in app.model.get("market", []):
		var prime: Variant = joueur.get("fee")
		if (prime is int or prime is float) and float(prime) > float(budget.get("disponible", 0)) and str(joueur.get("reason", "")).to_lower().contains("budget"):
			hors_budget = joueur
			break
	verifier(not hors_budget.is_empty(), "au moins une piste refusée pour le budget de transferts (prime > disponible)")
	if not hors_budget.is_empty():
		verifier(not bool(hors_budget.get("available", true)), "devis indisponible pour " + str(hors_budget.get("name", "")))
		app.SquadViews.contract(app, hors_budget, true); await poser(12)
		var dialogue := app.find_child("ContractOffer", true, false) as ConfirmationDialog
		verifier(dialogue != null, "fenêtre d'offre ouverte")
		if dialogue != null:
			verifier(dialogue.get_ok_button().disabled, "bouton d'envoi grisé hors budget")
			verifier(texte("ContractBlockedReason") == str(hors_budget.get("reason", "")), "raison écrite : « %s »" % texte("ContractBlockedReason"))
			verifier(visible_a_l_ecran("ContractBlockedReason"), "raison visible dans la fenêtre")
			verifier(texte("ContractTransferBudget").contains(reste), "part du budget restant sous le formulaire : " + texte("ContractTransferBudget"))
			await capturer("budget-offre-refusee.png")
			dialogue.queue_free()
	print("BUDGET ", JSON.stringify({"controles": controles, "failures": echecs, "disponible": budget.get("disponible"), "joueur": str(hors_budget.get("name", ""))}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
