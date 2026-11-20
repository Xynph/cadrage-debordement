extends SceneTree
## Réception, direction artistique « Liste et lettre » (choix de Léo du 19/11/2026), Godot réel + worker réel, carrière Monde :
## - la lettre ouverte est le seul document « papier » de l'écran, la liste reste sombre ;
## - aucune couleur or hors Continuer dans la liste et la lettre ; un symbole accompagne chaque sujet ;
## - noms de joueurs et de clubs cités = liens (mini-fiche au survol d'un joueur) ; aucun lien mort ;
## - le filtre « Sujet » est un menu déroulant ; plus de panneau fixe « Concerné » ;
## - un clic sur une réponse la choisit, « Envoyer la réponse » la confirme, « Annuler » la retire ;
## - rien de ce qui est cliquable n'ouvre une petite fenêtre (Window, AcceptDialog, PopupPanel…).
## Imprime une ligne RECEPTION_DA {checks, failures}. Captures (rendu graphique) : CD_RECEPTION_DA_CAPTURES=<dossier>.
const Flow = preload("helpers/contextual_flow.gd")
const ClubMail = preload("res://ui/club_mail.gd")
const Reception = preload("res://ui/immersive08/reception_canvas.gd")
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var capture_dir := OS.get_environment("CD_RECEPTION_DA_CAPTURES")

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

## Fenêtres ouvertes en plus de la racine (petites fenêtres interdites hors exceptions).
func windows() -> Array:
	return app.find_children("*", "Window", true, false).filter(func(w: Node) -> bool: return (w as Window).visible)

func close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < .01 and absf(a.g - b.g) < .01 and absf(a.b - b.b) < .01

## Couleurs or posées sur un contrôle (police, fonds, bordures) : aucune hors Continuer.
func gold_on(control: Control) -> bool:
	var gold: Array[Color] = [Charte.OR, Charte.OR_VIF]
	var tones: Array[Color] = []
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		if control.has_theme_color_override(key): tones.append(control.get_theme_color(key))
	for key in ["normal", "hover", "pressed", "focus", "disabled", "panel"]:
		if control.has_theme_stylebox_override(key):
			var box := control.get_theme_stylebox(key) as StyleBoxFlat
			if box != null: tones.append_array([box.bg_color, box.border_color])
	for tone in tones:
		for reference in gold:
			if close(tone, reference) and tone.a > .05: return true
	return false

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
	entities_are_links()
	var mail: Dictionary = {}
	for day in 4:
		for item: Dictionary in ClubMail.mails(app.model):
			if ClubMail.awaiting(app.model, item) and (item.reponses as Array).any(func(r: Dictionary) -> bool: return r.disponible): mail = item
		if not mail.is_empty(): break
		await command("advance_day", {"fromDate": app.model.meta.calendarToday})
		await Flow.settle_club_meetings(app, self, check)
	check(not mail.is_empty(), "Un courrier attend une réponse")
	if mail.is_empty(): return finish()
	app._reset_reception(str(mail.id))
	app._navigate("Réception", false)
	await settle(10)
	await paper_and_colors()
	await reply_flow(mail)
	await links_open_screens()
	shot("reception-1920x1080")
	finish()

func finish() -> void:
	print("RECEPTION_DA ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

## Noms de joueurs et de clubs du texte : liens bien formés, aucun chevauchement, texte brut conservé.
func entities_are_links() -> void:
	var squad: Array = app.model.get("squad", [])
	check(not squad.is_empty(), "Effectif disponible")
	if squad.is_empty(): return
	var player: Dictionary = squad[0]
	var text := "Coach, %s revient ; on parle de %s [sic]." % [player.name, player.name]
	var found := Reception.entities(app, text)
	var players := found.filter(func(e: Dictionary) -> bool: return e.kind == "player" and str(e.id) == str(player.id))
	check(players.size() >= 2, "Le nom d'un joueur de l'effectif devient un lien à chaque citation (%d)" % players.size())
	var linked := Reception.linked_text(text, found)
	check(linked.contains("[url=player:" + str(player.id) + "]") and linked.contains("[lb]sic]"), "Texte lié en BBCode, crochets protégés")
	var spans: Array = found.map(func(e: Dictionary) -> Array: return [int(e.start), int(e.end)])
	var overlap := false
	for i in spans.size():
		for j in range(i + 1, spans.size()):
			if spans[i][0] < spans[j][1] and spans[j][0] < spans[i][1]: overlap = true
	check(not overlap, "Aucun chevauchement entre deux liens")
	check(Reception.entities(app, "Aucun nom connu ici.").is_empty(), "Un texte sans nom n'a aucun lien")

func paper_and_colors() -> void:
	var letters: Array = app.root_content.find_children("InboxLetter", "", true, false) + app.root_content.find_children("InboxPressClipping", "", true, false)
	check(letters.size() == 1, "Une seule lettre papier à l'écran (%d)" % letters.size())
	var letter := letters[0] as PanelContainer if not letters.is_empty() else null
	if letter != null: check(close((letter.get_theme_stylebox("panel") as StyleBoxFlat).bg_color, Charte.PAPIER), "La lettre est sur papier")
	var list := node("InboxMessages")
	var dark := true
	for panel: Node in list.find_children("*", "Panel", true, false):
		var box := (panel as Control).get_theme_stylebox("panel") as StyleBoxFlat
		if box != null and close(box.bg_color, Charte.PAPIER) and box.bg_color.a > .9 and (panel as Control).size.x > 80.0: dark = false
	check(dark, "La liste reste sombre (aucun fond papier)")
	var title := node("InboxTitle") as Label
	var body := node("InboxMessageText")
	if node("InboxLetter") != null:
		check(title != null and close(title.get_theme_color("font_color"), Charte.ENCRE), "Titre de la lettre à l'encre")
		check(body is RichTextLabel and close(body.get_theme_color("default_color"), Charte.ENCRE), "Texte de la lettre à l'encre")
	var golds: Array[String] = []
	for zone in ["InboxMessages", "InboxDetail"]:
		var root_zone := node(zone)
		for item: Node in root_zone.find_children("*", "Control", true, false):
			if gold_on(item as Control): golds.append(str(item.name))
	check(golds.is_empty(), "Aucune couleur or hors Continuer : " + str(golds))
	var rows := node("InboxMessageRows").get_children().filter(func(n: Node) -> bool: return n.has_meta("message_id"))
	var with_symbol := rows.filter(func(r: Node) -> bool: return r.find_child("SenderIcon", true, false) != null)
	check(not rows.is_empty() and with_symbol.size() == rows.size(), "Chaque sujet a son symbole à côté du mot (%d/%d)" % [with_symbol.size(), rows.size()])
	check(node("InboxSubject") is OptionButton, "Le filtre « Sujet » est un menu déroulant")
	check(node("InboxConcerne") == null, "Plus de panneau fixe « Concerné » à droite")
	check(windows().is_empty(), "Aucune petite fenêtre ouverte sur l'écran")

## Choisir, confirmer, annuler.
func reply_flow(mail: Dictionary) -> void:
	var option: Dictionary = (mail.reponses as Array).filter(func(r: Dictionary) -> bool: return r.disponible)[0]
	var send := node("InboxClubMailSend") as Button
	check(send != null and send.disabled, "« Envoyer » attend un choix")
	var card := node("InboxClubMailReply_" + str(option.id)) as Button
	check(card != null, "Carte de réponse présente")
	if card == null: return
	card.pressed.emit()
	await settle()
	send = node("InboxClubMailSend") as Button
	check(send != null and not send.disabled and send.text.begins_with("Envoyer la réponse"), "Le choix active « Envoyer la réponse X »")
	check(not close((send.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Charte.OR), "L'action principale est ivoire, pas or")
	check(node("InboxClubMailCancel") != null, "« Annuler » proposé")
	node("InboxClubMailCancel").pressed.emit()
	await settle()
	send = node("InboxClubMailSend") as Button
	check(send != null and send.disabled, "« Annuler » retire le choix")
	check(str(app.model.get("clubLife", {}).get("clubMail", {}).get("reponses", {}).get(str(mail.id), "")).is_empty(), "Rien n'est parti sans confirmation")
	check(windows().is_empty(), "Aucune petite fenêtre après le choix d'une réponse")

## Le nom du joueur lié ouvre sa fiche (écran), jamais une fenêtre.
func links_open_screens() -> void:
	# Déterministe : un courrier de recette (donnée d'interface, le moteur n'est pas touché) lié à un joueur réel de l'effectif,
	# quel que soit l'ordre ou le contenu des courriers de la carrière.
	var squad: Array = app.model.get("squad", [])
	var box: Dictionary = app.model.clubLife.clubMail
	var source: Dictionary = (box.mails[0] as Dictionary).duplicate(true)
	if squad.is_empty() or source.is_empty(): check(false, "Courrier de recette impossible : effectif ou courriers absents"); return
	var star: Dictionary = squad[0]
	source.id = "qa-joueur-lie"
	source.categorie = "moments" # jamais une coupure de presse : on veut une lettre
	source.erase("reponses")
	source.joueur = str(star.id)
	source.erase("club")
	source.corps = "Coach, %s a besoin de te parler." % star.name
	(box.mails as Array).append(source)
	var holder: Dictionary = source
	app._reset_reception(str(holder.id))
	app._navigate("Réception", false)
	await settle(10)
	var link := node("InboxConcernedName") as Button
	check(link != null and link.has_meta("mini_fiche_joueur"), "Joueur lié : nom en lien avec mini-fiche (%s, mail %s, route %s)" % [str(node("InboxConcernedName")), str(holder.get("id")), app.route])
	if link == null: return
	check(link.text == str(star.name), "Le lien porte le nom du joueur lié")
	var body := node("InboxMessageText") as RichTextLabel
	check(body != null, "Lettre ouverte (texte riche)")
	if body != null and body.get_parsed_text().contains(str(star.name)): check(body.text.contains("[url=player:" + str(star.id) + "]"), "Le nom cité dans la lettre est aussi un lien")
	link.pressed.emit()
	await settle(10)
	check(app.route == "Effectif" and windows().is_empty(), "Le nom du joueur ouvre sa fiche, sans petite fenêtre (route : %s)" % app.route)
