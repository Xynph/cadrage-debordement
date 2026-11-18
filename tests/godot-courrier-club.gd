extends SceneTree
## Courrier du club (native/engine/club-mail.cjs, ui/club_mail.gd), Godot réel + worker réel, carrière Monde
## (world-champ) partie de la veille de la saison :
## - un jour de calendrier plus tard, des mails du club sont en Réception ; l'un appelle une réponse ;
## - le clic sur une réponse l'affiche tout de suite (décision optimiste), le moteur la confirme (meta.clubMailReply)
##   et le mail n'offre plus de réponse ; le bouton « Ouvrir » mène à l'écran concerné ;
## - arrêts informatifs de « Continuer » : veille -> Composition, rapport médical -> Effectif filtré sur les
##   blessés, courrier -> le mail sélectionné en Réception.
## - Réception façon FM (demande de Léo 16/11) en 1920×1080 et 1280×720 : liste étroite à gauche sur toute la
##   hauteur, mail ouvert en grand (≥ 60 % de la largeur), plus de cartes de courriers liés en bas à droite,
##   réponses visibles en bas du mail, aucun chevauchement ni texte qui déborde ; ouverture, lu/non lu, ordre de
##   la liste identique à l'ordre d'affichage (raccourci Espace « prochain non lu »).
## - Réception v2 (corrections de Léo 16/11) : une seule rangée de filtres (Tous · Non lus · À faire + menu Sujet, qui contient Favoris et Archives),
##   plus de bande « Les invitations du club » (les invitations sont des messages de la liste, à faire), icône de service
##   à la place d'un même visage, pas de vide au-dessus des réponses du mail ouvert.
## - Direction A (maquette validée le 18/11) : liste groupée par jour, panneau « Concerné » affiché ou masqué, coupure de
##   presse, tableau de l'infirmerie, conséquences des réponses, ordre du raccourci Espace.
## Captures (rendu graphique) : CD_COURRIER_CAPTURES=<dossier>.
## Imprime une ligne COURRIER {checks, failures}.
const Flow = preload("helpers/contextual_flow.gd")
const ClubMail = preload("res://ui/club_mail.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var capture_dir := OS.get_environment("CD_COURRIER_CAPTURES")
const Reception = preload("res://ui/immersive08/reception_canvas.gd")
const C = preload("res://ui/immersive08/components.gd")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 4) -> void:
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
	check(app.bridge.last_response_ok, "Worker réel · " + id + " · " + app.last_error)
	return app.bridge.last_response_ok

func button(name: String) -> Button:
	return app.root_content.find_child(name, true, false) as Button if is_instance_valid(app.root_content) else null

func run() -> void:
	root.size = Vector2i(1600, 900)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"})
	await Flow.settle_club_meetings(app, self, check)
	check(app.model.get("club") is Dictionary, "Carrière Monde créée")
	await reply_and_open()
	await info_stops()
	print("COURRIER ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

## Un jour plus tard : un mail qui appelle une réponse, réponse au clic, puis écran concerné.
func reply_and_open() -> void:
	var mail: Dictionary = {}
	for day in 4:
		for item: Dictionary in ClubMail.mails(app.model):
			if ClubMail.awaiting(app.model, item) and (item.reponses as Array).any(func(r: Dictionary) -> bool: return r.disponible):
				mail = item
		if not mail.is_empty(): break
		await command("advance_day", {"fromDate": app.model.meta.calendarToday})
		await Flow.settle_club_meetings(app, self, check)
	check(not mail.is_empty(), "Un mail du club attend une réponse")
	if mail.is_empty(): return
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]: await reception_layout(mail, size)
	# Recette du 17/11 : le bilan de Gabi propose quatre réponses, coupées sur une seule rangée
	# (« Axer la semaine sur la conquêt »). Mêmes contrôles avec ses quatre libellés réels, au plus étroit.
	var original: Array = mail.reponses
	mail.reponses = [
		{"id":"conquete", "libelle":"Axer la semaine sur la conquête", "disponible":true, "effets":""},
		{"id":"defense", "libelle":"Axer sur la défense et la discipline", "disponible":true, "effets":""},
		{"id":"pied", "libelle":"Axer sur le jeu au pied", "disponible":true, "effets":""},
		{"id":"plan", "libelle":"Garder notre plan", "disponible":true, "effets":""},
	]
	await reception_layout(mail, Vector2i(1280, 720))
	mail.reponses = original
	await invitations_in_list(mail)
	await direction_a(mail)
	root.size = Vector2i(1600, 900)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app._reset_reception(str(mail.id))
	app._navigate("Réception", false)
	await settle()
	var row: Node = app.root_content.find_child("InboxClubMail_" + str(mail.id).replace("-", "_"), true, false)
	check(row != null, "Mail rangé dans la Réception · " + str(mail.sujet))
	var option: Dictionary = (mail.reponses as Array).filter(func(r: Dictionary) -> bool: return r.disponible)[0]
	var reply := button("InboxClubMailReply_" + str(option.id))
	check(reply != null and not reply.disabled, "Bouton de réponse « " + str(option.libelle) + " »")
	if reply == null: return
	check(not str(reply.tooltip_text).is_empty(), "Conséquences annoncées en info-bulle")
	reply.pressed.emit()
	await process_frame
	check(str(app.model.get("clubLife", {}).get("clubMail", {}).get("reponses", {}).get(str(mail.id), "")) == str(option.id), "Réponse affichée dès le clic")
	await wait_engine()
	var receipt: Variant = app.model.get("meta", {}).get("clubMailReply")
	check(receipt is Dictionary and receipt.get("choice") == option.id, "Réponse confirmée par le moteur")
	if app.route != "Réception":
		app._navigate("Réception", false)
		await settle()
	check(button("InboxClubMailReply_" + str(option.id)) == null, "Plus de réponse proposée une fois répondu")
	var open := button("InboxClubMailOpen")
	check(open != null and str(open.text).begins_with("Ouvrir"), "Bouton vers l’écran concerné")
	if open == null: return
	var expected := ClubMail.route_of(str(mail.ecran))
	open.pressed.emit()
	await settle()
	if str(mail.ecran) != "fiche": check(app.route == expected, "Écran concerné ouvert : " + expected + " (actuel : " + app.route + ")")

## Arrêts informatifs : écran utile préparé pour la réponse de « Continuer ».
func info_stops() -> void:
	check(ClubMail.stop_route(app, {"kind":"info", "type":"veille", "ecran":"Composition"}) == "Composition", "Veille de match : composition")
	check(ClubMail.stop_route(app, {"kind":"info", "type":"medical", "ecran":"infirmerie"}) == "Effectif", "Rapport médical : effectif")
	check(str(app.management_ui.get("roster", {}).get("available", "")) == "Blessés", "Rapport médical : filtre des blessés")
	check(ClubMail.stop_route(app, {"kind":"info", "type":"mi_saison", "ecran":"Classements"}) == "Classements", "Mi-saison : classement")
	check(ClubMail.stop_route(app, {"kind":"info", "type":"mercato", "ecran":"Recrutement"}) == "Recrutement", "Marché : recrutement")
	var mails := ClubMail.mails(app.model)
	if not mails.is_empty():
		check(ClubMail.stop_route(app, {"kind":"info", "type":"courrier", "ecran":"Réception", "mail":str(mails[0].id)}) == "Réception", "Courrier : Réception")
		check(str(app.management_ui.reception.selected) == str(mails[0].id), "Courrier : le mail est sélectionné")

func node(name: String) -> Control:
	return app.root_content.find_child(name, true, false) as Control if is_instance_valid(app.root_content) else null

## Texte lu dans le mail ouvert : corps du mail, ou colonnes de la coupure de presse.
func reading_text() -> String:
	var text := node("InboxMessageText") as Label
	if text != null: return text.text
	var clipping := node("InboxPressClipping")
	if clipping == null: return ""
	return " ".join(PackedStringArray(clipping.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)))

func rows() -> Array:
	var list := node("InboxMessageRows")
	return [] if list == null else list.get_children().filter(func(item: Node) -> bool: return item.has_meta("message_id"))

func expand_threads() -> void:
	for attempt in 24:
		var list := node("InboxMessageRows")
		if list == null: return
		var closed: Array = list.get_children().filter(func(item: Node) -> bool: return item.has_meta("thread_key") and item is Button and item.text.begins_with("▸"))
		if closed.is_empty(): return
		closed[0].pressed.emit()
		await settle()

## Disposition façon Football Manager, ouverture d'un mail, lu/non lu, ordre de la liste.
func reception_layout(mail: Dictionary, size: Vector2i) -> void:
	var tag := "%dx%d" % [size.x, size.y]
	root.size = size
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(size)
	app._reset_reception(str(mail.id))
	app._navigate("Réception", false)
	await settle(8)
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(capture_dir)
		check(root.get_texture().get_image().save_png(capture_dir.path_join("reception-" + tag + ".png")) == OK, "Capture " + tag)
	var screen := Rect2(Vector2.ZERO, Vector2(size))
	var list := node("InboxMessages")
	var detail := node("InboxDetail")
	check(list != null and detail != null, "Liste et mail ouvert présents · " + tag)
	if list == null or detail == null: return
	var l := list.get_global_rect()
	var d := detail.get_global_rect()
	check(screen.encloses(l.grow(-1)) and screen.encloses(d.grow(-1)), "Liste et mail dans la fenêtre · " + tag + " " + str(l) + " " + str(d))
	check(l.end.x <= d.position.x, "Liste à gauche du mail · " + tag)
	check(absf(l.position.y - d.position.y) < 2.0 and d.size.y <= l.size.y + 2.0, "Mail aligné en haut de la liste, sans la dépasser · " + tag)
	var useful := d.end.x - l.position.x
	check(d.size.x >= .6 * useful, "Mail ouvert ≥ 60 %% de la largeur utile · %s (%.0f / %.0f)" % [tag, d.size.x, useful])
	check(l.size.x <= .36 * useful, "Liste étroite · %s (%.0f / %.0f)" % [tag, l.size.x, useful])
	for gone in ["InboxContext", "InboxCategoryChart", "InboxFolders", "InboxActivityFilters", "ContextualInvitations", "InboxCategory0", "InboxFolder3", "InboxActivity_all", "InboxActivity_waiting", "InboxActivity_info"]:
		check(node(gone) == null, "Plus de bloc séparé « " + gone + " » · " + tag)
	check(app.root_content.find_children("InboxRelated_*", "", true, false).is_empty(), "Plus de cartes de courriers en bas à droite · " + tag)
	# Une seule rangée de filtres, en tête de liste : quatre boutons et le menu Sujet, à la même hauteur.
	var filter_row: Array[Control] = []
	for name in ["InboxFolder0", "InboxFolder1", "InboxActivity_todo", "InboxSubject"]:
		var filter := node(name)
		check(filter != null and l.encloses(filter.get_global_rect()), "Filtre en tête de liste · " + name + " · " + tag)
		if filter != null: filter_row.append(filter)
	for filter in filter_row: check(absf(filter.get_global_rect().position.y - filter_row[0].get_global_rect().position.y) < 2.0, "Filtres sur une seule rangée · " + str(filter.name) + " · " + tag)
	var filter_buttons: Array = list.find_children("Inbox*", "Button", true, false).filter(func(b: Button) -> bool: return str(b.name).begins_with("InboxFolder") or str(b.name).begins_with("InboxActivity_") or str(b.name).begins_with("InboxCategory"))
	check(filter_buttons.size() == 3, "Trois boutons de filtre (Tous · Non lus · À faire), pas davantage · " + tag + " (" + str(filter_buttons.size()) + ")")
	check(node("InboxSort") != null and l.encloses(node("InboxSort").get_global_rect()), "Tri en tête de liste · " + tag)
	var menu := node("InboxSubject") as OptionButton
	if menu != null:
		var labels: Array = []
		for index in menu.item_count: labels.append(menu.get_item_text(index))
		for wanted in ["Staff", "Médical", "Favoris", "Archives", "En attente", "Infos"]:
			check(labels.any(func(text: String) -> bool: return text.begins_with(wanted)), "Menu Sujet : « " + wanted + " » accessible · " + tag)
	# Le mail ouvert : texte lisible, réponses visibles en bas du mail, aucun chevauchement.
	var text := node("InboxMessageText") as Label
	check(reading_text().contains(str(mail.get("corps", "")).split("\n")[0].left(30)), "Le mail sélectionné est ouvert · " + tag)
	if text != null:
		check(text.get_theme_font_size("font_size") >= maxi(12, roundi(20 * C.density)), "Texte du mail lisible (%d px) · %s" % [text.get_theme_font_size("font_size"), tag])
		var scroll := text.get_parent() as ScrollContainer
		if scroll != null: check(not scroll.get_v_scroll_bar().visible, "Pas de défilement inutile du mail · " + tag)
	var actions: Array = detail.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.is_visible_in_tree())
	var replies: Array = actions.filter(func(b: Button) -> bool: return str(b.name).begins_with("InboxClubMailReply_"))
	check(not replies.is_empty(), "Réponses du courrier affichées · " + tag)
	for reply: Button in replies:
		check(d.encloses(reply.get_global_rect()), "Réponse dans le mail · " + str(reply.name) + " · " + tag)
		check(reply.size.x >= reply.get_theme_font("font").get_string_size(reply.text, HORIZONTAL_ALIGNMENT_LEFT, -1, reply.get_theme_font_size("font_size")).x * .98, "Libellé de réponse entier · " + reply.text + " · " + tag)
		check(reply.size.y >= 24.0, "Bouton de réponse lisible (%.0f px) · %s" % [reply.size.y, tag])
	# Pas de vide : les actions sont collées sous le contenu (texte, pièces liées) et le pied tient dans la carte.
	if not actions.is_empty():
		var first_top := 100000.0
		var last_bottom := 0.0
		for action: Button in actions:
			first_top = minf(first_top, action.get_global_rect().position.y)
			last_bottom = maxf(last_bottom, action.get_global_rect().end.y)
		var content_bottom := d.position.y
		for item: Control in detail.find_children("*", "Control", true, false):
			if not item.is_visible_in_tree() or item is Panel or item is TextureRect or item is Button or item.get_parent() is ScrollContainer: continue
			if item.get_global_rect().position.y < first_top - 1.0 and (item is Label or item is ScrollContainer): content_bottom = maxf(content_bottom, item.get_global_rect().end.y)
		for item: Button in detail.find_children("*", "Button", true, false):
			if item.is_visible_in_tree() and item.get_global_rect().end.y < first_top - 1.0: content_bottom = maxf(content_bottom, item.get_global_rect().end.y)
		var gap := first_top - content_bottom
		check(gap <= .25 * d.size.y, "Pas de vide entre le contenu du mail et ses actions · %s (%.0f px sur %.0f)" % [tag, gap, d.size.y])
		var below := d.end.y - last_bottom
		check(below <= .25 * d.size.y, "Pas de vide sous les actions · %s (%.0f px sur %.0f)" % [tag, below, d.size.y])
	for i in actions.size():
		check(d.encloses(actions[i].get_global_rect().grow(-1)), "Action dans le mail · " + str(actions[i].name) + " · " + tag)
		for j in range(i + 1, actions.size()):
			var a: Rect2 = actions[i].get_global_rect().grow(-1)
			var b: Rect2 = actions[j].get_global_rect().grow(-1)
			if a.intersects(b) and not actions[i].is_ancestor_of(actions[j]) and not actions[j].is_ancestor_of(actions[i]):
				check(false, "Chevauchement %s / %s · %s" % [actions[i].name, actions[j].name, tag])
	# Icône du service à la place d'un même visage : un portrait seulement pour une personne identifiée.
	var portraits := 0
	var icons := 0
	for row: Button in rows():
		var message: Array = Reception._messages(app).filter(func(item: Dictionary) -> bool: return str(item.id) == str(row.get_meta("message_id")))
		if message.is_empty(): continue
		if row.find_child("SenderIcon", true, false) != null: icons += 1
		else:
			portraits += 1
			check(not Reception._sender_player(app, message[0]).is_empty(), "Portrait réservé à une personne identifiée · " + str(row.name) + " · " + tag)
	check(icons > 0, "Les expéditeurs de service ont une icône · " + tag + " (" + str(icons) + " icônes, " + str(portraits) + " portraits)")
	# Ordre de la liste = ordre d'affichage (le raccourci Espace ouvre le premier non lu de cette liste).
	await expand_threads()
	var ids: Array = rows().map(func(row: Button) -> String: return str(row.get_meta("message_id")))
	check(ids == display_order() and not ids.is_empty(), "Liste dans l'ordre d'affichage · " + tag)
	# Ouvrir un autre mail : il passe lu ; « Marquer non lu » le remet en non lu.
	var others: Array = rows().filter(func(row: Button) -> bool: return str(row.get_meta("message_id")) != str(mail.id))
	if others.is_empty(): return
	var other: Button = others[0]
	var other_id := str(other.get_meta("message_id"))
	var state: Dictionary = app.management_ui.reception
	state.marks.erase(other_id)
	app._render(); await settle()
	other = node(Reception._row_id(Reception._messages(app).filter(func(item: Dictionary) -> bool: return str(item.id) == other_id)[0])) as Button
	check(other != null and other.find_child("UnreadDot", true, false) != null, "Non lu mis en évidence · " + tag)
	if other == null: return
	var other_text := str(other.get_meta("message_text"))
	other.pressed.emit()
	await settle()
	check(state.marks.get(other_id, {}).get("read", false), "Ouvert = lu · " + tag)
	check(reading_text() == other_text or reading_text().contains(str(Reception._messages(app).filter(func(item: Dictionary) -> bool: return str(item.id) == other_id)[0].get("club_mail", {}).get("corps", "")).split("\n")[0].left(30)), "Le mail cliqué s'ouvre en grand · " + tag)
	var toggle := node("InboxToggleRead") as Button
	check(toggle != null, "Marquer non lu proposé · " + tag)
	if toggle != null:
		toggle.pressed.emit(); await settle()
		check(not state.marks.get(other_id, {}).get("read", false), "Marqué non lu · " + tag)

## Ordre d'affichage de la boîte (dossier « Tous ») : priorités épinglées, puis jours (plus récents d'abord), fils
## regroupés. C'est aussi l'ordre de `next_unread` (raccourci Espace, #765).
func display_order() -> Array:
	return Reception.display_order(app).map(func(m: Dictionary) -> String: return str(m.id))

## Les invitations du club sont des messages de la liste (catégorie Club, à faire), sans bande ni bouton blanc au-dessus de la boîte.
## Fixture d'interface contrôlée : le produit lit la projection du moteur, ici on y ajoute une invitation en attente.
func invitations_in_list(mail: Dictionary) -> void:
	var original: Dictionary = app.model.duplicate(true)
	var scenes: Dictionary = app.model.get("clubLife", {}).get("sceneInvitations", {})
	var entries: Array = scenes.get("invitations", []).duplicate(true)
	entries.append({"id":"qa-invitation", "title":"Entretien avec le staff", "reason":"Le nouveau manager prend ses fonctions : faire connaissance.", "status":"pending", "available":true})
	if not app.model.has("clubLife"): app.model.clubLife = {}
	if not app.model.clubLife.has("sceneInvitations"): app.model.clubLife.sceneInvitations = {}
	app.model.clubLife.sceneInvitations.invitations = entries
	app._reset_reception(str(mail.id))
	app._navigate("Réception", false)
	await settle(8)
	check(node("ContextualInvitations") == null, "Aucune bande d'invitations au-dessus de la boîte")
	var found: Array = Reception._messages(app).filter(func(item: Dictionary) -> bool: return item.has("scene_invitation") and item.id == "invitation:qa-invitation")
	check(found.size() == 1 and found[0].category == "Club", "Invitation du club : message de catégorie Club")
	if found.size() == 1: check(Reception.Reading.status(found[0], app.model).key == "todo", "Invitation du club : à faire")
	await expand_threads()
	var row := node("InboxSceneInvitation_qa_invitation") as Button
	check(row != null and row.get_parent() == node("InboxMessageRows"), "Invitation rangée dans la liste")
	if row != null:
		row.pressed.emit()
		await settle()
		var open := node("InboxOpenSceneInvitation") as Button
		check(open != null and not open.disabled and str(open.text).begins_with("Ouvrir"), "Invitation ouverte : bouton pour y répondre")
		check(app.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "OUVRIR").is_empty(), "Aucun bouton « OUVRIR » hors palette")
	var ids: Array = rows().map(func(item: Button) -> String: return str(item.get_meta("message_id")))
	check(ids == display_order() and ids.has("invitation:qa-invitation"), "Invitations dans l'ordre d'affichage (Espace = prochain non lu)")
	var marks: Dictionary = app.management_ui.reception.marks
	for id: String in ids: marks[id] = {"read":true}
	marks.erase("invitation:qa-invitation")
	check(str(Reception.next_unread(app).get("id", "")) == "invitation:qa-invitation", "Espace ouvre l'invitation non lue")
	app.model = original
	app._reset_reception(str(mail.id))

## Direction A (maquette « Bureau du manager », 18/11/2026) : liste groupée par jour, panneau « Concerné » affiché ou
## masqué, coupure de presse, tableau de l'infirmerie construit des blessures réelles, ordre du raccourci Espace.
## Fixture d'interface contrôlée : deux mails du club ajoutés à la projection (presse aujourd'hui, médical hier).
func direction_a(mail: Dictionary) -> void:
	var original: Dictionary = app.model.duplicate(true)
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	var today := str(app.model.meta.calendarToday)
	var yesterday := Reception._shift(today, -1)
	var squad: Array = app.model.squad
	check(squad.size() >= 2, "Effectif réel pour la direction A")
	if squad.size() < 2: return
	var star: Dictionary = squad[0]
	var hurt: Dictionary = squad[1]
	hurt.injury = 3
	var press := {"id":"mail-990001", "type":"rumeur", "categorie":"presse", "date":today, "expediteur":"Le quotidien régional",
		"sujet":"Rumeur : " + str(star.name) + " courtisé", "status":"nouveau", "ecran":"Presse", "joueur":str(star.id), "arret":false,
		"corps":"Selon nos informations, deux clubs se renseignent sur le joueur.\n\nLe dossier pèse lourd dans un effectif qui peut difficilement se passer d'un titulaire.\n\nOn publie demain. Un démenti rassurera les tribunes.",
		"reponses":[{"id":"dementir", "libelle":"Démentir fermement", "effets":"Supporters +2 · Moral −1", "disponible":true, "raison":""},
			{"id":"laisser", "libelle":"Laisser dire", "effets":"Médias +1", "disponible":true, "raison":""}]}
	var medical := {"id":"mail-990002", "type":"kine_bilan", "categorie":"infirmerie", "date":yesterday, "expediteur":"Le kiné du club",
		"sujet":"Bilan de l'infirmerie", "status":"lu", "ecran":"infirmerie", "arret":false, "corps":"Point sur les soins de la semaine.", "reponses":[]}
	if not app.model.clubLife.has("clubMail") or not app.model.clubLife.clubMail is Dictionary: app.model.clubLife.clubMail = {"mails":[], "reponses":{}}
	var box: Dictionary = app.model.clubLife.clubMail
	box.mails = [press, medical] + (box.get("mails", []) as Array)
	app._reset_reception("mail-990001")
	app._navigate("Réception", false)
	await settle(8)
	# Groupement par jour : en-têtes « AUJOURD'HUI » puis « HIER », chaque mail sous son jour.
	var list := node("InboxMessageRows")
	var headings: Array = [] if list == null else list.get_children().filter(func(n: Node) -> bool: return str(n.name).begins_with("InboxDay_"))
	var titles: Array = headings.map(func(n: Node) -> String: return (n.find_child("InboxDayLabel", true, false) as Label).text)
	check(titles.has("AUJOURD'HUI") and titles.has("HIER"), "Mails groupés par jour : " + str(titles))
	if list != null and titles.has("AUJOURD'HUI") and titles.has("HIER"):
		var position := func(id: String) -> int:
			for child in list.get_children():
				if child.has_meta("message_id") and str(child.get_meta("message_id")) == id: return child.get_index()
			return -1
		var today_at: int = headings[titles.find("AUJOURD'HUI")].get_index()
		var yesterday_at: int = headings[titles.find("HIER")].get_index()
		check(today_at < position.call("mail-990001") and position.call("mail-990001") < yesterday_at, "Mail du jour sous « AUJOURD'HUI »")
		check(yesterday_at < position.call("mail-990002"), "Mail de la veille sous « HIER »")
	var press_row := node("InboxClubMail_mail_990001")
	check(press_row != null and press_row.find_child("InboxTodoTag", true, false) != null, "Étiquette « À FAIRE · échéance » sur un mail qui attend une réponse")
	# Gabarit presse : coupure de journal.
	check(node("InboxPressClipping") != null, "Mail de presse rendu en coupure de journal")
	var media := node("InboxPressMedia") as Label
	check(media != null and media.text == "Le quotidien régional", "Nom du média en tête de la coupure")
	check(node("InboxPressHeadline") != null and node("InboxPressLead") != null and node("InboxPressRubrique") != null, "Grand titre, chapeau et rubrique")
	var columns := node("InboxPressColumns")
	check(columns != null and columns.find_children("InboxPressColumn*", "Label", true, false).size() == 2, "Texte de presse sur deux colonnes")
	var photo := node("InboxPressPhoto") as TextureRect
	check(photo == null or photo.texture != null, "Pas de cadre photo vide")
	# Panneau Concerné affiché : joueur lié et échéance.
	var side := node("InboxConcerne")
	check(side != null, "Panneau « Concerné » affiché pour un mail lié à un joueur")
	var who := node("InboxConcernedName") as Label
	check(who != null and who.text == str(star.name), "Mini-fiche du joueur lié")
	check(node("InboxConcernedOpen") != null and node("InboxDeadline") != null, "Bouton « Ouvrir la fiche » et encadré « ÉCHÉANCE »")
	var with_side := node("InboxDetail").size.x if node("InboxDetail") != null else 0.0
	if side != null and node("InboxDetail") != null: check(node("InboxDetail").get_global_rect().end.x <= side.get_global_rect().position.x, "Panneau à droite du mail, sans chevauchement")
	# Réponses : cartes et conséquences tirées des effets réels.
	var reply := node("InboxClubMailReply_dementir")
	var effects: Array = [] if reply == null else reply.find_children("InboxReplyEffect*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(effects.has("▲ Supporters +2") and effects.has("▼ Moral −1"), "Conséquences de la réponse : " + str(effects))
	check(node("InboxReplyHeading") != null and node("InboxSpaceHint") != null, "« TA RÉPONSE » et rappel Espace")
	check(Reception.consequences("Pression +2")[0][0] == "▼" and Reception.consequences("Coût 1 000 €")[0][0] == "▼" and Reception.consequences("Charge individuelle : allégée")[0][0] == "=" and Reception.consequences("")[0][1] == "Sans effet chiffré", "Sens des conséquences (pression, coût, neutre)")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(capture_dir.path_join("reception-presse-1920x1080.png")) == OK, "Capture presse")
	# Gabarit médical : tableau de l'infirmerie, panneau masqué et mail élargi.
	app.management_ui.reception.selected = "mail-990002"
	app._render()
	await settle(8)
	check(node("InboxConcerne") == null, "Panneau « Concerné » masqué sans élément lié")
	check(node("InboxDetail") != null and node("InboxDetail").size.x > with_side + 10, "Le mail s'élargit sans le panneau")
	check(node("InboxInfirmary") != null, "Tableau de l'infirmerie dans le mail médical")
	var forfeit := false
	for row: Node in app.root_content.find_children("InboxInfirmaryRow_*", "", true, false):
		var status := row.find_child("InboxInfirmaryStatus", true, false) as Label
		if str(row.get_meta("player_id")) == str(hurt.id) and status != null and status.text == "Forfait" and status.get_theme_color("font_color") == C.ALERT: forfeit = true
	check(forfeit, "Joueur blessé : forfait en rouge, d'après les blessures réelles")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(capture_dir.path_join("reception-medical-1920x1080.png")) == OK, "Capture médical")
	# Espace : prochain non lu dans l'ordre de la liste affichée.
	var marks: Dictionary = app.management_ui.reception.marks
	for item: Dictionary in Reception._messages(app): marks[item.id] = {"read":true}
	marks.erase("mail-990001")
	marks.erase("mail-990002")
	app._render()
	await settle()
	await expand_threads()
	var shown: Array = rows().map(func(row: Button) -> String: return str(row.get_meta("message_id")))
	check(shown == display_order(), "Liste = ordre d'affichage (jours compris)")
	var first_unread := ""
	for id: String in shown:
		if not marks.get(id, {}).get("read", false):
			first_unread = id
			break
	check(first_unread == "mail-990001" and str(Reception.next_unread(app).get("id", "")) == first_unread, "Espace : premier non lu de la liste (" + first_unread + ")")
	check(Reception.open_next_unread(app) and str(app.management_ui.reception.selected) == "mail-990001", "Espace ouvre le mail du jour")
	await settle()
	check(str(Reception.next_unread(app).get("id", "")) == "mail-990002", "Espace suivant : le mail de la veille")
	app.model = original
	app._reset_reception(str(mail.id))
