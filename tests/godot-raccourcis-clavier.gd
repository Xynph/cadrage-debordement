extends SceneTree
# Raccourcis clavier de la carrière Monde : Espace = Continuer (Entrée ne fait rien), 1 à 9 = menus, Échap = fermer la fiche,
# Ctrl+F = accès rapide, et aucun raccourci dans un champ de saisie ou devant un dialogue.
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")
	# Garde-fou : une erreur de script dans run() laisserait la scène tourner sans fin (le test n'avait alors que le
	# délai de 240 s du processus) ; on échoue vite, avec un message.
	create_timer(150.0).timeout.connect(func():
		printerr("FAIL: délai de 150 s dépassé (suite interrompue)")
		quit(1))

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

# Appuie sur Espace avec le bouton Continuer actif ou rendu inactif, et rend le nombre d'activations. Le bureau peut se
# redessiner pendant la touche (réponse tardive du worker sur un poste lent) : le bouton tenu en main est alors libéré,
# donc on le retrouve à chaque essai au lieu d'écrire sur un nœud libéré, et on recommence sur le nouveau bouton.
func espace_sur_continuer(inactif: bool) -> int:
	for _essai in 4:
		var cible := app.find_child("ImmersiveContinue", true, false) as Button
		if cible == null: return -1
		var compte := [0]
		cible.pressed.connect(func(): compte[0] += 1)
		cible.disabled = inactif
		await key(KEY_SPACE)
		if is_instance_valid(cible) and cible.is_inside_tree():
			cible.disabled = false
			return compte[0]
	return -2

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

	# Menus 1 à 9 : dans l'ordre affiché (Bureau, Réception, Effectif, Tactique…), sans numéro écrit devant.
	var menus: Array = app.root_content.find_children("Nav_*", "Button", true, false)
	check(menus.size() >= 9, "Au moins neuf menus à gauche (" + str(menus.size()) + ")")
	check(menus[2].tooltip_text.contains("touche 3") and menus[0].tooltip_text.contains("touche 1") and not menus[0].text.substr(0, 1).is_valid_int(), "Info-bulles « touche 1 », « touche 3 » sur les menus, sans numéro affiché")
	await key(KEY_3)
	check(app.route == "Effectif", "Touche 3 : Effectif (" + app.route + ")")
	await key(KEY_KP_2)
	check(app.route == "Réception", "Pavé numérique 2 : Réception (" + app.route + ")")
	await key(KEY_1)
	check(app.route == "Bureau", "Touche 1 : Bureau (" + app.route + ")")
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

	# Ctrl+F (comme Ctrl+K) : focus dans le champ « Rechercher » de la barre haute, aucune fenêtre ; Échap le rend.
	await key(KEY_F, true)
	var recherche := app.root_content.find_child("ImmersiveSearch", true, false) as LineEdit
	check(recherche != null and recherche.has_focus() and app.find_child("NavigationPalette", true, false) == null, "Ctrl+F met le focus dans la recherche, sans fenêtre")
	# Champ ciblé : les raccourcis du bureau restent muets.
	await key(KEY_5)
	check(app.route == "Effectif", "Recherche ciblée : touche 5 ignorée (" + app.route + ")")
	await key(KEY_ESCAPE)
	check(recherche != null and not recherche.has_focus() and app.find_child("ImmersivePauseMenu", true, false) == null, "Échap rend le focus sans ouvrir le menu")
	# Dialogue ouvert : les raccourcis du bureau restent muets.
	app.notice("Essai", "Fenêtre ouverte")
	await settle()
	await key(KEY_5)
	check(app.route == "Effectif", "Dialogue ouvert : touche 5 ignorée (" + app.route + ")")
	app._clear_dialogs()
	await settle()

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
		check(texte != null and texte.text == "\n".join(Table.lignes_aide()), "Paramètres : lignes issues de la table")
		var onglets := options.find_child("PreferencesTabs", true, false) as TabContainer
		var noms: Array[String] = []
		for index in onglets.get_tab_count(): noms.append(onglets.get_tab_title(index))
		check(noms == ["Confort", "Son", "Affichage", "Raccourcis clavier"], "Paramètres : onglets dans l'ordre " + str(noms))
		# Chaque onglet est une zone défilante (la rangée d'onglets reste fixe) : le rappel est dans sa colonne.
		check(onglets.get_tab_control(3).is_ancestor_of(rappel), "Paramètres : le rappel est dans le dernier onglet")
		check(onglets.find_children("PreferencesShortcuts", "", true, false).size() == 1, "Paramètres : un seul onglet de raccourcis")
		check(onglets.get_tab_control(1).find_child("PreferencesMatchSounds", true, false) != null and onglets.get_tab_control(1).find_child("PreferencesMusic*", true, false) == null, "Paramètres : onglet Son sans musique")
	app._clear_dialogs()
	await settle(2)
	check(app.get_signal_connection_list("child_entered_tree").filter(func(c: Dictionary): return c.callable.get_object() == gestionnaire).is_empty(), "Plus d'injection externe des paramètres")
	app._open_coach()
	await settle(2)
	var aide: Array = app.coach._fragments_aide(app.coach.current_id)
	check(not aide.is_empty() and str(aide.back().text).contains(ligne), "Aide F1 : dernier conseil = raccourcis issus de la table")
	app.coach.close()
	await settle(2)

	# Espace = Continuer et rien d'autre (coque commune : un raccourci garde un seul sens) ; même avec des non-lus,
	# Espace n'ouvre jamais le courrier (le bouton « Courrier suivant non lu » de la Réception reste là pour ça).
	var Reception = load("res://ui/immersive08/reception_canvas.gd")
	app._navigate("Bureau")
	await settle()
	var continuer := app.find_child("ImmersiveContinue", true, false) as Button
	check(continuer != null and not continuer.disabled, "Bouton Continuer actif")
	if continuer == null: return finish()
	var avant: int = Reception.unread(app)
	if avant == 0:
		# Rend un message non lu pour couvrir ce cas.
		var marques: Dictionary = app.management_ui.reception.marks
		var cible: Dictionary = Reception._messages(app)[0]
		marques[cible.id] = {"read": false}
		avant = Reception.unread(app)
	check(avant > 0, "Au moins un message non lu au départ (" + str(avant) + ")")
	continuer.mouse_entered.emit()
	check(continuer.tooltip_text.ends_with("Espace : continuer"), "Info-bulle avec non-lus : continuer (" + continuer.tooltip_text + ")")
	continuer.mouse_entered.emit()
	check(continuer.tooltip_text.count("Espace :") == 1, "Indication jamais doublée")
	# Bouton rendu inactif le temps de la vérification : Espace ne doit ni avancer ni ouvrir le courrier.
	var inactif_1 := await espace_sur_continuer(true)
	check(inactif_1 == 0 and app.route == "Bureau", "Non lus restants : Espace n'ouvre pas la Réception (" + app.route + ")")
	check(Reception.unread(app) == avant, "Aucun message marqué lu par Espace (" + str(Reception.unread(app)) + " pour " + str(avant) + ")")
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
	var inactif_2 := await espace_sur_continuer(true)
	check(inactif_2 == 0, "Continuer inactif : Espace ne fait rien")
	var actif := await espace_sur_continuer(false)
	check(actif == 1, "Zéro non lu : Espace = Continuer (" + str(actif) + ")")
	# Entrée ne déclenche plus Continuer.
	var compteur := [0]
	var courant := app.find_child("ImmersiveContinue", true, false) as Button
	if courant != null: courant.pressed.connect(func(): compteur[0] += 1)
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
