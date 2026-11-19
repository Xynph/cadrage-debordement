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

## Contraste WCAG entre deux couleurs opaques.
func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func luminance(c: Color) -> float:
	var channels := [c.r, c.g, c.b].map(func(v: float): return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]

## Lisibilité de la zone « Les invitations du club » : cartes compactes, texte au moins aussi grand que les courriers,
## bouton « Ouvrir » dans la même carte que son texte, à sa droite, et contraste du texte secondaire >= 4,5:1.
func check_readable_invitations(invitations: Node, expected: int) -> void:
	var cards := invitations.find_children("ContextualInvitation_*", "PanelContainer", true, false)
	check(cards.size() == expected, "Une carte par invitation (%d pour %d)" % [cards.size(), expected])
	var mail_sizes: Array = []
	var rows := app.find_child("InboxMessageRows", true, false)
	if rows != null and rows.get_child_count() > 0:
		for label: Label in rows.get_child(0).find_children("*", "Label", true, false): mail_sizes.append(label.get_theme_font_size("font_size"))
	check(not mail_sizes.is_empty(), "Courriers de la Réception mesurables")
	var mail_title: int = mail_sizes.max() if not mail_sizes.is_empty() else 0
	var mail_detail: int = mail_sizes.min() if not mail_sizes.is_empty() else 0
	for card: PanelContainer in cards:
		var title := card.find_child("ContextualInvitationTitle", true, false) as Label
		var reason := card.find_child("ContextualInvitationReason", true, false) as Label
		var open := card.find_child("ContextualInvitationOpen", true, false) as Button
		check(title != null and reason != null and open != null, "La carte " + str(card.name) + " contient titre, raison et bouton")
		if title == null or reason == null or open == null: continue
		check(title.get_theme_font_size("font_size") >= mail_title, "Titre d'invitation au moins aussi grand que le titre d'un courrier (%d pour %d)" % [title.get_theme_font_size("font_size"), mail_title])
		check(reason.get_theme_font_size("font_size") >= mail_detail and reason.get_theme_font_size("font_size") >= 12, "Raison au moins aussi grande que le détail d'un courrier (%d pour %d)" % [reason.get_theme_font_size("font_size"), mail_detail])
		var card_rect := card.get_global_rect()
		check(card_rect.grow(1.0).encloses(open.get_global_rect()), "Le bouton « Ouvrir » reste dans sa carte")
		check(open.get_global_rect().position.x >= reason.get_global_rect().position.x + minf(reason.get_minimum_size().x, 40.0), "Le bouton « Ouvrir » est à droite du texte de sa carte")
		check(card_rect.size.x <= root.size.x * 0.75 and card_rect.size.y <= root.size.y * 0.2, "Carte compacte : " + str(card_rect.size))
		var panel := card.get_theme_stylebox("panel") as StyleBoxFlat
		check(panel != null and contrast(reason.get_theme_color("font_color"), panel.bg_color) >= 4.5, "Contraste de la raison >= 4,5:1")
		check(panel != null and contrast(title.get_theme_color("font_color"), panel.bg_color) >= 4.5, "Contraste du titre >= 4,5:1")
	var banner := invitations.find_child("ContextualInvitationsBlocked", true, false) as Control
	var press := invitations.find_child("ContextualOpenPress", true, false) as Control
	if banner != null and press != null: check(banner.get_global_rect().grow(1.0).encloses(press.get_global_rect()), "Le bouton de la conférence est dans le bandeau d'information")
	check(invitations.get_global_rect().end.y <= root.size.y * 0.35, "La zone des invitations ne pousse pas les courriers hors de l'écran")

func run() -> void:
	root.size = Vector2i(1600, 900)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 60000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	# Presse façon FM (18/11/2026) : la conférence d'arrivée est celle de la rentrée, la semaine du 1er match ; le départ
	# « veille de la 1re journée » l'ouvre dès la création.
	app._command("new_career", {"mode": "world-champ", "club": 0, "start": "veille"})
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
	check(not dock_texts.has("Stockage à vérifier") and dock_texts.has("Sauvegarde auto"), "Barre latérale : « Sauvegarde auto », pas « Stockage à vérifier »")

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
