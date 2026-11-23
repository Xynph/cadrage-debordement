extends SceneTree
## Stratégie > Supporters, billetterie de la saison (profil préparé par tests/godot-billetterie.cjs, vrai moteur) : trois prix
## (billet, abonnement, grosse affiche) en − / prix / + avec le conseil du responsable de la billetterie, « Confier à … »,
## affluence estimée. Un clic sur « + » change le prix (clic = appliqué) ; « Confier » applique les conseils.
var app: Control
var sortie := OS.get_environment("CD_BILLETTERIE_OUTPUT")
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

func trouver(nom: String) -> Control:
	return app.body.find_child(nom, true, false) as Control

func onglet_supporters() -> void:
	app._navigate("Stratégie")
	await poser(12)
	var onglets: Array = app.body.find_children("*", "TabContainer", true, false)
	verifier(not onglets.is_empty(), "onglets de la Stratégie")
	if onglets.is_empty(): return
	(onglets[0] as TabContainer).current_tab = 2
	await poser(12)

func capturer(nom: String, taille: Vector2i) -> void:
	if DisplayServer.get_name() == "headless" or sortie.is_empty(): return
	root.size = taille
	DisplayServer.window_set_size(taille)
	await onglet_supporters()
	var bas := trouver("BilletterieConfier")
	# Chaque défilement qui contient la billetterie descend jusqu'à « Confier à … » (lignes de prix visibles).
	var parent: Node = bas.get_parent() if bas != null else null
	while parent != null:
		if parent is ScrollContainer:
			(parent as ScrollContainer).ensure_control_visible(bas)
			await poser(4)
			(parent as ScrollContainer).scroll_vertical += 60
		parent = parent.get_parent()
	await poser(20)
	verifier(root.get_texture().get_image().save_png(sortie.path_join(nom)) == OK, "capture " + nom)

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	var fans: Dictionary = app.model.clubLife.clubStrategy.fans
	var t: Dictionary = fans.get("ticketing", {})
	verifier(not t.is_empty(), "billetterie de la saison dans le modèle")
	await onglet_supporters()
	for kind in ["base", "abonnement", "affiche"]:
		verifier(trouver("Billetterie_" + kind) != null and trouver("BilletPlus_" + kind) != null and trouver("BilletMoins_" + kind) != null, "ligne " + kind)
		verifier(trouver("BilletPiste_" + kind) != null and int(trouver("BilletPiste_" + kind).get("conseil")) > 0, "piste et repère du conseil : " + kind)
		var prix_l := trouver("BilletPrix_" + kind) as Label
		verifier(prix_l != null and prix_l.get_theme_font_size("font_size") >= 18, "prix en gros : " + kind)
	verifier(trouver("BilletterieConfier") is Button and trouver("BilletterieResponsable") != null, "carte du responsable et bascule « Billetterie confiée »")
	verifier(trouver("BilletterieStade") != null, "stade rempli en tête")
	verifier(trouver("FansPrice_equilibree") == null, "plus de préréglages à la place des trois prix")
	var lien := trouver("DirectionLien_Affluence")
	var textes := ""
	if lien != null:
		for l in lien.find_children("*", "Label", true, false): textes += (l as Label).text + " "
	verifier(textes.contains("≈") and textes.contains("ESTIM"), "affluence estimée, jamais exacte : " + textes)
	# Un clic sur « + » : le billet monte d'un euro, appliqué tout de suite.
	var avant := int(t.get("prices", {}).get("base", 0))
	(trouver("BilletPlus_base") as Button).pressed.emit()
	await poser(4); await attendre_moteur()
	var apres := int(app.model.clubLife.clubStrategy.fans.get("ticketing", {}).get("prices", {}).get("base", 0))
	verifier(apres == avant + 1, "billet %d → %d" % [avant, apres])
	await onglet_supporters()
	var prix := trouver("BilletPrix_base") as Label
	verifier(prix != null and prix.text.contains(str(apres)), "prix affiché : " + (prix.text if prix != null else "absent"))
	# Un clic sur le repère du conseil (piste de l'abonnement) : le conseil devient le prix.
	var conseil_abo := int(app.model.clubLife.clubStrategy.fans.ticketing.advice.abonnement)
	(trouver("BilletPiste_abonnement")).call("cliquer_conseil")
	await poser(4); await attendre_moteur()
	verifier(int(app.model.clubLife.clubStrategy.fans.ticketing.prices.abonnement) == conseil_abo, "repère du conseil appliqué : %d" % conseil_abo)
	await onglet_supporters()
	# Confier au staff : les trois prix deviennent ses conseils.
	(trouver("BilletterieConfier") as Button).pressed.emit()
	await poser(4); await attendre_moteur()
	var confie: Dictionary = app.model.clubLife.clubStrategy.fans.get("ticketing", {})
	verifier(bool(confie.get("delegated", false)) and confie.get("prices") == confie.get("advice"), "délégation : prix = conseils " + str(confie.get("prices")) + " / " + str(confie.get("advice")))
	await capturer("final-billetterie-1920.png", Vector2i(1920, 1080))
	await capturer("final-billetterie-2560.png", Vector2i(2560, 1440))
	print("BILLETTERIE ", JSON.stringify({"controles": controles, "failures": echecs, "avant": avant, "apres": apres, "confie": confie.get("prices")}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
