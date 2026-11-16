extends SceneTree
# Raccourcis clavier de la carrière Monde : Espace = Continuer (Entrée ne fait rien), 1 à 9 = menus, Échap = fermer la fiche,
# Ctrl+F = accès rapide, et aucun raccourci dans un champ de saisie ou devant un dialogue.
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func settle(frames := 5) -> void:
	for frame in frames: await process_frame

func wait_idle(limit_ms := 240000) -> void:
	var until := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func key(code: int, ctrl := false, shift := false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = ctrl
		event.shift_pressed = shift
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()

func finish() -> void:
	print("RACCOURCIS : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	if app != null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach): app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	# Hors carrière : aucun gestionnaire, donc aucun raccourci (accueil, intro).
	check(app.get_node_or_null("RaccourcisClavier") == null, "Accueil : gestionnaire de raccourcis absent")
	app._command("new_career", {"mode": "world-champ", "club": 102, "start": "premiers-clubs"})
	await wait_idle()
	await Flow.settle_club_meetings(app, self, check)
	if is_instance_valid(app.coach): app.coach.close()
	app._navigate("Bureau")
	await settle()
	var gestionnaire := app.get_node_or_null("RaccourcisClavier")
	check(gestionnaire != null, "Carrière : gestionnaire de raccourcis installé")
	if gestionnaire == null: return finish()
	check(app.get_viewport().gui_get_focus_owner() == null or not (app.get_viewport().gui_get_focus_owner() is LineEdit), "Aucun champ de saisie au départ")

	# Menus 1 à 9 : dans l'ordre affiché (Réception, Bureau, Effectif, Tactique…).
	var menus: Array = app.root_content.find_children("Nav_*", "Button", true, false)
	check(menus.size() >= 9, "Au moins neuf menus à gauche (" + str(menus.size()) + ")")
	check(menus[2].tooltip_text.contains("(3)") and menus[0].tooltip_text.contains("(1)"), "Info-bulles « (1) », « (3) » sur les menus")
	await key(KEY_3)
	check(app.route == "Effectif", "Touche 3 : Effectif (" + app.route + ")")
	await key(KEY_KP_2)
	check(app.route == "Bureau", "Pavé numérique 2 : Bureau (" + app.route + ")")
	await key(KEY_4)
	check(app.route == "Composition", "Touche 4 : Tactique (" + app.route + ")")
	await key(KEY_2, true)
	check(app.route == "Composition", "Ctrl+2 : aucun raccourci de menu (" + app.route + ")")

	# Champ de saisie : aucun raccourci.
	var champ := LineEdit.new()
	app.add_child(champ)
	champ.grab_focus()
	await settle(2)
	await key(KEY_3)
	await key(KEY_SPACE)
	check(app.route == "Composition" and not app.continue_progress.running and not app.waiting, "Champ de saisie : ni menu ni Continuer")
	champ.queue_free()
	app.get_viewport().gui_release_focus()
	await settle(2)

	# Fiche joueur : Échap la referme sans ouvrir le menu de la carrière.
	app.selected_player = str(app.model.squad[0].id)
	app._navigate("Effectif")
	await settle()
	app.set_meta("immersive08_full_player", true)
	app._render()
	await settle()
	check(app.find_child("PlayerBackToSquad", true, false) != null, "Fiche joueur ouverte")
	await key(KEY_ESCAPE)
	check(not app.get_meta("immersive08_full_player", false) and app.route == "Effectif", "Échap referme la fiche joueur")
	check(app.find_child("ImmersivePauseMenu", true, false) == null, "Échap sur la fiche : pas de menu de pause")

	# Ctrl+F : l'accès rapide (seule recherche existante), refermé par Échap.
	await key(KEY_F, true)
	var palette := app.find_child("NavigationPalette", true, false) as Window
	check(palette != null and palette.visible, "Ctrl+F ouvre l'accès rapide")
	# Dialogue ouvert : les raccourcis du bureau restent muets.
	await key(KEY_5)
	check(app.route == "Effectif", "Dialogue ouvert : touche 5 ignorée (" + app.route + ")")
	await key(KEY_ESCAPE)
	check(palette != null and not palette.visible, "Échap referme l'accès rapide")

	# Rappels : une seule table pour le pied de page, les paramètres et l'aide F1.
	var Table = load("res://ui/raccourcis_clavier.gd")
	var ligne: String = Table.lignes_aide()[0]
	check(not ligne.contains("Entrée"), "Table : Entrée n'est plus un raccourci")
	# Le pied de page existe sur tous les écrans, Bureau compris.
	app._navigate("Effectif")
	await settle()
	var pied := app.find_child("ImmersiveShortcuts", true, false)
	check(pied != null and pied.text == Table.pied_de_page(), "Pied de page issu de la table")
	# Bureau : pied de page présent, sans recouvrir Continuer ni la zone de travail.
	app._navigate("Bureau")
	await settle()
	var pied_bureau := app.find_child("ImmersiveShortcuts", true, false) as Label
	check(pied_bureau != null and pied_bureau.text == Table.pied_de_page(), "Bureau : pied de page des raccourcis présent")
	var bouton := app.find_child("ImmersiveContinue", true, false) as Button
	var zone := app.find_child("CareerWorkspace", true, false) as Control
	check(bouton != null and zone != null, "Bureau : bouton Continuer et zone de travail trouvés")
	if pied_bureau != null and bouton != null and zone != null:
		if pied_bureau.visible:
			check(not pied_bureau.get_global_rect().intersects(bouton.get_global_rect()), "Bureau : le pied de page ne chevauche pas Continuer")
			check(not pied_bureau.get_global_rect().intersects(zone.get_global_rect()), "Bureau : le pied de page ne recouvre pas la zone de travail")
		check(pied_bureau.get_global_rect().position.y > bouton.get_global_rect().end.y, "Bureau : le pied de page est sous Continuer")
	app._navigate("Effectif")
	await settle()
	var options = load("res://ui/preferences_dialog.gd").open(app, app.user_preferences)
	await settle(4)
	var rappel := app.find_child("PreferencesShortcuts", true, false)
	check(options != null and rappel != null, "Paramètres : section « Raccourcis clavier »")
	if rappel != null:
		var texte := rappel.get_parent().get_child(1) as Label
		check(texte != null and texte.text.contains(ligne), "Paramètres : lignes issues de la table")
	app._clear_dialogs()
	await settle(2)
	app._open_coach()
	await settle(2)
	var aide: Array = app.coach._fragments_aide(app.coach.current_id)
	check(not aide.is_empty() and str(aide.back().text).contains(ligne), "Aide F1 : dernier conseil = raccourcis issus de la table")
	app.coach.close()
	await settle(2)

	# Espace : d'abord le prochain message non lu, puis seulement Continuer.
	var Reception = load("res://ui/immersive08/reception_canvas.gd")
	app._navigate("Bureau")
	await settle()
	var continuer := app.find_child("ImmersiveContinue", true, false) as Button
	check(continuer != null and not continuer.disabled, "Bouton Continuer actif")
	if continuer == null: return finish()
	var compteur := [0]
	continuer.pressed.connect(func(): compteur[0] += 1)
	var avant: int = Reception.unread(app)
	if avant == 0:
		# Rend un message non lu pour couvrir ce cas.
		var marques: Dictionary = app.management_ui.reception.marks
		var cible: Dictionary = Reception._messages(app)[0]
		marques[cible.id] = {"read": false}
		avant = Reception.unread(app)
	check(avant > 0, "Au moins un message non lu au départ (" + str(avant) + ")")
	var attendu: Dictionary = Reception.next_unread(app)
	continuer.mouse_entered.emit()
	check(continuer.tooltip_text.ends_with("Espace : prochain message"), "Info-bulle : prochain message (" + continuer.tooltip_text + ")")
	continuer.mouse_entered.emit()
	check(continuer.tooltip_text.count("Espace :") == 1, "Indication jamais doublée")
	await key(KEY_SPACE)
	check(compteur[0] == 0, "Non lus restants : Espace ne déclenche pas Continuer")
	check(app.route == "Réception", "Espace ouvre la Réception (" + app.route + ")")
	check(app.management_ui.reception.selected == attendu.get("id", "?"), "Le prochain message non lu est sélectionné")
	check(Reception.unread(app) == avant - 1, "Ce message est marqué lu (" + str(Reception.unread(app)) + " pour " + str(avant) + ")")
	# Tout lire : Espace = Continuer.
	var marques2: Dictionary = app.management_ui.reception.marks
	for message: Dictionary in Reception._messages(app): marques2[message.id] = {"read": true}
	check(Reception.unread(app) == 0 and Reception.next_unread(app).is_empty(), "Plus aucun non lu")
	app._navigate("Bureau")
	await settle()
	continuer = app.find_child("ImmersiveContinue", true, false) as Button
	if continuer == null: return finish()
	continuer.mouse_entered.emit()
	check(continuer.tooltip_text.ends_with("Espace : continuer"), "Info-bulle : continuer (" + continuer.tooltip_text + ")")
	compteur[0] = 0
	continuer.pressed.connect(func(): compteur[0] += 1)
	continuer.disabled = true
	await key(KEY_SPACE)
	check(compteur[0] == 0, "Continuer inactif : Espace ne fait rien")
	continuer.disabled = false
	await key(KEY_SPACE)
	check(compteur[0] == 1, "Zéro non lu : Espace = Continuer (" + str(compteur[0]) + ")")
	# Entrée ne déclenche plus Continuer.
	compteur[0] = 0
	await key(KEY_ENTER)
	check(compteur[0] == 0, "Entrée : pas de Continuer (" + str(compteur[0]) + ")")
	# Un autre bouton ciblé : Espace l'active, pas Continuer.
	var autre := Button.new()
	autre.name = "BoutonTestRaccourci"
	var presses := [0]
	autre.pressed.connect(func(): presses[0] += 1)
	app.add_child(autre)
	autre.grab_focus()
	await settle(2)
	await key(KEY_SPACE)
	check(presses[0] == 1 and compteur[0] == 0, "Bouton ciblé + Espace : le bouton est activé, pas Continuer (" + str(presses[0]) + "/" + str(compteur[0]) + ")")
	autre.queue_free()
	await wait_idle()
	finish()
