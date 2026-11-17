extends SceneTree
## Club > Infrastructures et Finances (profil préparé par tests/godot-investissements-excedents.cjs, vrai moteur) :
## bloc « Excédents réinvestis » (travaux, accueil, staff) et lignes « Investissements : … » du grand livre.
## Captures 1920×1080 en affichage graphique.
var app: Control
var sortie := OS.get_environment("CD_INVEST_OUTPUT")
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

func textes(noeud: Node) -> String:
	var t := ""
	for n in noeud.find_children("*", "Label", true, false): t += (n as Label).text + "\n"
	return t

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	var inv: Variant = app.model.get("clubLife", {}).get("clubStrategy", {}).get("finance", {}).get("investissements")
	verifier(inv is Dictionary and float(inv.get("montant", 0)) > 0.0, "état des chantiers dans le modèle : " + str(inv))
	app.management_ui["immersive08_club_tab"] = "infrastructure"
	app.management_ui.club_tab = 0
	app._navigate("Club"); await poser(20)
	var bloc := app.find_child("ClubPresidentProjects", true, false)
	verifier(bloc != null, "bloc « Excédents réinvestis » dans Club > Infrastructures")
	var lu := textes(bloc) if bloc != null else ""
	verifier(lu.contains("Excédents réinvestis") and lu.contains("Accueil du stade") and lu.contains("Staff"), "textes du bloc : « %s »" % lu)
	verifier(lu.contains("Travaux du niveau") or lu.contains("Installations au maximum"), "état des travaux")
	await capturer("investissements-infrastructures.png")
	app._navigate("Finances"); await poser(20)
	# Flux récents : huit écritures par page, les plus récentes d'abord ; on tourne les pages comme le manager.
	var page := 0
	var ledger := app.find_child("FinanceLedger", true, false)
	while ledger != null and not textes(ledger).contains("Investissements") and page < 12:
		var suivant := app.find_child("FinanceNext_summary", true, false) as Button
		if suivant == null or suivant.disabled: break
		suivant.emit_signal("pressed"); await poser(12); page += 1
		ledger = app.find_child("FinanceLedger", true, false)
	var lignes := textes(ledger) if ledger != null else ""
	verifier(lignes.contains("Investissements : installations") and lignes.contains("Investissements : staff"), "lignes « Investissements » dans Flux récents (page %d) : « %s »" % [page + 1, lignes.left(600)])
	await capturer("investissements-finances.png")
	print("INVESTISSEMENTS ", JSON.stringify({"controles": controles, "failures": echecs, "bloc": lu}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
