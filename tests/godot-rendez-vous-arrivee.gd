extends SceneTree
## Début de carrière Monde (world-champ) avec la conférence de presse d'arrivée en attente (recette native du 16/11/2026) :
## 1. une décision refusée nomme la conférence et n'allume pas « Stockage à vérifier » ;
## 2. les invitations du club disent qu'elles viennent après la conférence et y mènent, sans « OUVRIR » voué au refus ;
## 3. le bouton principal « Conf. de presse » ouvre la vraie salle de presse ;
## 4. un libellé long du bouton principal (« Décision attendue ») n'est jamais rogné.
var app: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func frames(n: int = 6) -> void:
	for i in n: await process_frame

func idle() -> void:
	var until := Time.get_ticks_msec() + 60000
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	await frames()

func texts(node: Node) -> Array:
	var out := []
	for child in node.find_children("*", "", true, false):
		if child is Label or child is Button or child is RichTextLabel: out.append(str(child.text))
	return out

func run() -> void:
	root.size = Vector2i(1600, 900)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 60000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app._command("new_career", {"mode": "world-champ", "club": 0, "start": "club"})
	await idle()
	if is_instance_valid(app.coach): app.coach.close()
	var meeting: Variant = app.model.get("clubLife", {}).get("clubMeetings", {}).get("scene")
	check(meeting is Dictionary and meeting.get("kind") == "press", "Conférence de presse d'arrivée en attente")

	# 1. Décision refusée : message explicite, aucun voyant de stockage.
	app._navigate("Tactique")
	await frames()
	var tactics: Dictionary = app.model.get("tactics", {})
	var attacks: Array = tactics.get("attacks", [])
	app._command("set_tactics", {"attack": attacks[1].id if attacks.size() > 1 else tactics.get("attack"), "defense": tactics.get("defense")})
	await idle()
	check(str(app.last_error).contains("conférence de presse"), "Le refus nomme la conférence de presse : " + str(app.last_error))
	check(app.has_method("_storage_has_error") and not app._storage_has_error(), "Une décision refusée n'est pas un problème de stockage")
	app._clear_dialogs()
	app._render()
	await frames()
	var dock_texts := texts(app)
	check(not dock_texts.has("Stockage à vérifier") and dock_texts.has("Sauvegarde automatique"), "Barre latérale : « Sauvegarde automatique », pas « Stockage à vérifier »")

	# 2. Invitations du club pendant la conférence.
	app._show_press_inbox()
	await frames(10)
	# Disposition façon FM (#813) : plus de bande d'invitations, la notice ouvre la liste des messages.
	var inbox := app.find_child("InboxMessageRows", true, false)
	var pending: Array = app.model.get("clubLife", {}).get("sceneInvitations", {}).get("invitations", []).filter(func(item: Dictionary): return item.get("status") == "pending" and item.get("available", false))
	if not pending.is_empty():
		check(inbox != null, "Liste des messages affichée en Réception")
		var blocked: Node = inbox.find_child("ContextualInvitationsBlocked", true, false) if inbox != null else null
		check(blocked != null and blocked.get_index() == 0, "En tête de la Réception : les invitations viennent après la conférence")
		if blocked != null:
			check(blocked.find_child("ContextualOpenPress", true, false) != null, "Accès direct à la conférence depuis la notice")
		var enabled := app.find_children("InboxOpenSceneInvitation", "Button", true, false).filter(func(b: Button): return not b.disabled)
		check(enabled.is_empty(), "Aucune invitation du club ouvrable pendant la conférence")

	# 3. Bouton principal « Conf. de presse » : la vraie salle de presse.
	check(str(app.primary_button.text) == "Conf. de presse", "Bouton principal « Conf. de presse » (" + str(app.primary_button.text) + ")")
	app.primary_action()
	await frames(10)
	check(app.contextual_director.active() and app.contextual_director.kind == "press", "« Conf. de presse » ouvre la salle de presse (route " + str(app.route) + ")")

	# 4. Libellé long du bouton principal entièrement lisible.
	var button: Button = app.primary_button
	if is_instance_valid(button):
		button.text = "Décision attendue"
		if app.has_method("fit_button_text"): app.fit_button_text(button)
		var style := button.get_theme_stylebox("normal")
		var room := button.size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
		if button.icon != null: room -= button.get_theme_constant("icon_max_width") + button.get_theme_constant("h_separation")
		var width := button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
		check(width <= room + 0.5, "« Décision attendue » tient dans le bouton (%.0f px pour %.0f px)" % [width, room])

	print("RENDEZ-VOUS ARRIVEE : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
