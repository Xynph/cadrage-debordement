extends SceneTree
## Bureau, direction artistique du 19/11/2026 (« Affiche et Gabi ») : tout ce qui a l'air cliquable ouvre quelque chose
## (un autre écran ou une fiche), aucune fenêtre ne s'ouvre sur un clic, l'or reste à Continuer, les couleurs viennent
## de la charte, le bandeau d'illustration reste voilé et mince, Gabi est un buste de 160 à 200 px.
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")
const Office = preload("res://ui/immersive08/office.gd")
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty(): quit(2); return
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)

func settle() -> void:
	for frame in 10: await process_frame

func wait_model(id: String) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	check(not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok, "Réponse du vrai moteur " + id)
	await settle()

func bureau() -> void:
	app._navigate("Bureau")
	await settle()
	if is_instance_valid(app.coach) and app.coach.has_method("close") and app.coach.expanded: app.coach.close()
	if is_instance_valid(app.coach): app.coach.fermer_bulle()
	await settle()

## Fenêtres ouvertes (hors la fenêtre racine) : AcceptDialog, ConfirmationDialog, PopupPanel, Window.
func fenetres() -> Array:
	return root.find_children("*", "Window", true, false).filter(func(w: Node): return (w as Window).visible)

func page() -> Control:
	return app.find_child("ImmersiveOffice", true, false) as Control

func ancre(nom: String) -> bool:
	return page() != null and page().find_child(nom, true, false) != null

## Boutons visibles et actifs du Bureau (la page seulement : la coque et Continuer sont ailleurs).
func boutons() -> Array[Button]:
	var liste: Array[Button] = []
	for b: Node in page().find_children("*", "Button", true, false):
		var bouton := b as Button
		if bouton.is_visible_in_tree() and not bouton.disabled: liste.append(bouton)
	return liste

func ouvre_quelque_chose() -> bool:
	return app.route != "Bureau" or app.management_ui.get("fiche_joueur") is Dictionary or app.get_meta("immersive08_full_player", false)

func cliquables() -> void:
	await bureau()
	var noms: Array[String] = []
	for bouton in boutons(): noms.append(str(bouton.name))
	check(noms.size() >= 12, "Le Bureau offre beaucoup d'éléments cliquables (%d)" % noms.size())
	var a_un_match: bool = app.model.get("next") is Dictionary and not app.model.next.is_empty()
	for attendu in (["OfficePreparationAction", "OfficeSelectionAction"] if a_un_match else []) + ["OfficeSquadAction", "OfficeStandingsAction", "OfficeInboxAction", "OfficeCalendarAction", "OfficeGroupAvailable", "OfficeGroupInjured", "OfficeMarketAction"]:
		check(noms.has(attendu), "Élément cliquable présent : " + attendu)
	check(noms.any(func(n: String): return n.begins_with("OfficeStandingRow_")), "Chaque club du classement court est cliquable")
	check(noms.any(func(n: String): return n.begins_with("OfficeTimelineTile")), "Chaque prochain match est cliquable")
	var messages: Array = app.model.get("messages", [])
	if not messages.is_empty(): check(noms.any(func(n: String): return n.begins_with("OfficeJournalMessage")), "Chaque message du courrier est cliquable")
	var fenetres_de_base := fenetres().size()
	for nom in noms:
		# Hors match à venir, « Continuer » du Bureau fait avancer le temps : c'est une commande, pas un écran.
		if nom == "OfficePreparationAction" and not a_un_match: continue
		# La carte « Premiers pas » est celle de Gabi (masquer, objectif suivant) : hors du périmètre des éléments du Bureau.
		if nom.begins_with("GabiPremiersPas"): continue
		await bureau()
		var bouton := page().find_child(nom, true, false) as Button
		if bouton == null or not bouton.is_visible_in_tree() or bouton.disabled: continue
		var avant := str(app.route)
		bouton.pressed.emit()
		await settle()
		check(fenetres().size() <= fenetres_de_base, "Aucune fenêtre ouverte par « %s »" % nom)
		var ouvert := ouvre_quelque_chose()
		# « Suivre le conseil » peut présélectionner sans quitter l'écran si Gabi n'a rien à proposer : alors le bouton n'existe pas.
		check(ouvert, "« %s » change d'écran ou ouvre une fiche (route %s → %s)" % [nom, avant, app.route])
		app.management_ui.erase("fiche_joueur")
		app.set_meta("immersive08_full_player", false)

func pas_d_or() -> void:
	await bureau()
	var trouves: Array[String] = []
	for noeud: Node in page().find_children("*", "Control", true, false):
		if noeud is Label:
			var encre: Color = noeud.get_theme_color("font_color")
			if encre.is_equal_approx(Charte.OR) or encre.is_equal_approx(Charte.OR_VIF): trouves.append(str(noeud.name))
		for style_nom in ["panel", "normal", "hover", "pressed", "focus"]:
			var style := noeud.get_theme_stylebox(style_nom) as StyleBoxFlat
			if style != null and (style.bg_color.is_equal_approx(Charte.OR) or style.bg_color.is_equal_approx(Charte.OR_VIF) or style.border_color.is_equal_approx(Charte.OR) or style.border_color.is_equal_approx(Charte.OR_VIF)): trouves.append(str(noeud.name))
	check(trouves.is_empty(), "Aucune couleur or hors Continuer : " + str(trouves))

func bandeau_et_gabi() -> void:
	await bureau()
	var affiche := app.find_child("OfficeFixture", true, false) as Control
	var photo := app.find_child("OfficeFixturePhoto", true, false) as Control
	if photo != null:
		check(affiche != null and photo.get_global_rect().size.y <= 160.0 * app.size.y / 1080.0, "Bandeau d'illustration de 160 px au plus (%d px)" % photo.get_global_rect().size.y)
		check(app.find_child("OfficeFixtureVeil", true, false) != null, "Bandeau d'illustration voilé")
	var figure := app.find_child("GabiBureauFigure", true, false) as Control
	if figure != null:
		var haut := figure.get_global_rect().size.y
		check(haut >= 150.0 * app.size.y / 1080.0 and haut <= 205.0 * app.size.y / 1080.0, "Buste de Gabi de 160 à 200 px (%d px)" % haut)
	var bulle := app.find_child("GabiBureauBulle", true, false) as Panel
	if bulle != null:
		var fond := bulle.get_theme_stylebox("panel") as StyleBoxFlat
		check(fond != null and fond.bg_color.is_equal_approx(Charte.PANNEAU_2), "Bulle de Gabi en panneau-2")
	if app.model.get("next") is Dictionary and not app.model.next.is_empty(): check(ancre("OfficeFaceAFace"), "Face-à-face chiffré des deux clubs présent")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	await wait_model("snapshot initial")
	var accepte: bool = app._command("new_career", {"club": 0, "mode": "world-champ"})
	check(accepte, "Commande publique new_career")
	await wait_model("new_career")
	var maximize := Callable(app, "_keep_filled_display")
	if root.size_changed.is_connected(maximize): root.size_changed.disconnect(maximize)
	if root.focus_entered.is_connected(maximize): root.focus_entered.disconnect(maximize)
	root.mode = Window.MODE_WINDOWED
	await ContextualFlow.settle_club_meetings(app, self, check)
	await bureau()
	check(page() != null, "Le Bureau de la DA est affiché")
	await cliquables()
	await pas_d_or()
	await bandeau_et_gabi()
	print("BUREAU DA : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.bridge.stop(); app.queue_free(); await settle()
	quit(0 if failures.is_empty() else 1)
