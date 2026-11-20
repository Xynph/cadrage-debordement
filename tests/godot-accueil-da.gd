extends SceneTree
## Accueil, direction artistique « Affiche et carnet » (choix de Léo du 19/11/2026), Godot réel + worker réel, carrière Monde :
## - première fois : « Nouvelle carrière » en pilule dorée pleine (seul aplat doré), chiffres du monde lus du pack ;
## - carrière en cours : « Reprendre la carrière » en or (seule exception hors coque), nom du club, classement et prochain
##   match lus du modèle ; classement et prochain match ouvrent leur page ;
## - tout ce qui a l'air cliquable agit ; Paramètres, Crédits et Mes carrières sont des écrans (aucune Window ouverte) ;
##   « ← Accueil » et Échap reviennent ; Nouvelle carrière ouvre le choix du club.
## Imprime une ligne ACCUEIL_DA {checks, failures}. Captures (rendu graphique) : CD_ACCUEIL_DA_CAPTURES=<dossier>, CD_ACCUEIL_DA_SIZE=LxH.
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/game_skin.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var capture_dir := OS.get_environment("CD_ACCUEIL_DA_CAPTURES")

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

func windows() -> Array:
	return app.find_children("*", "Window", true, false).filter(func(w: Node) -> bool: return (w as Window).visible)

func close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < .01 and absf(a.g - b.g) < .01 and absf(a.b - b.b) < .01

func gold_on(control: Control) -> bool:
	var tones: Array[Color] = []
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		if control.has_theme_color_override(key): tones.append(control.get_theme_color(key))
	for key in ["normal", "hover", "pressed", "focus", "disabled", "panel"]:
		if control.has_theme_stylebox_override(key):
			var box := control.get_theme_stylebox(key) as StyleBoxFlat
			if box != null: tones.append_array([box.bg_color, box.border_color])
	for tone in tones:
		for reference: Color in [Charte.OR, Charte.OR_VIF]:
			if close(tone, reference) and tone.a > .05: return true
	return false

## Contrôles dont un fond (normal, survol, pression, focus, désactivé) est un aplat doré : un bouton = une entrée.
func aplats_or() -> Array[String]:
	var found: Array[String] = []
	for control: Node in app.root_content.find_children("*", "Control", true, false):
		var ctrl := control as Control
		if ctrl == null or not ctrl.is_visible_in_tree(): continue
		for key in ["normal", "hover", "pressed", "focus", "disabled", "panel"]:
			var box := ctrl.get_theme_stylebox(key) as StyleBoxFlat if ctrl.has_theme_stylebox_override(key) else null
			if box != null and box.bg_color.a > .05 and (close(box.bg_color, Charte.OR) or close(box.bg_color, Charte.OR_VIF)):
				found.append(str(ctrl.name))
				break
	return found

## Noms des contrôles en or dans l'accueil.
func golds() -> Array[String]:
	var found: Array[String] = []
	for control: Node in app.root_content.find_children("*", "Control", true, false):
		if control is Control and gold_on(control) and (control as Control).is_visible_in_tree(): found.append(str(control.name))
	return found

func press(name: String) -> bool:
	var button := node(name) as Button
	if button == null or button.disabled or not button.is_visible_in_tree(): return false
	button.pressed.emit()
	return true

func home() -> void:
	app._navigate("Accueil")
	await settle(8)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	await settle()

func sub_pages() -> void:
	for pair in [["EntryCredits", "AccueilSousPage_credits", "Crédits"], ["EntrySettings", "AccueilSousPage_parametres", "Paramètres"], ["EntryCareerSlots", "AccueilSousPage_carrieres", "Mes carrières"]]:
		await home()
		check(press(pair[0]), "%s : le lien agit" % pair[2])
		await settle(8)
		await wait_engine()
		check(node(pair[1]) != null and app.route == "Accueil", "%s : un écran, pas une fenêtre" % pair[2])
		check(windows().is_empty(), "%s : aucune Window ouverte" % pair[2])
		check(node("AccueilRetour") != null, "%s : « ← Accueil » présent" % pair[2])
		if pair[0] == "EntryCredits":
			var text := node("CreditsText") as RichTextLabel
			check(text != null and not text.get_parsed_text().strip_edges().is_empty(), "Crédits : le texte est lu des données")
			shot("accueil-credits")
		if pair[0] == "EntrySettings": check(node("PreferencesPage") != null, "Paramètres : les réglages sont dans la page")
		if pair[0] == "EntryCareerSlots": check(node("CareerSlotsNew") != null, "Mes carrières : nouvelle carrière proposée dans la page")
		check(press("AccueilRetour"), "%s : retour" % pair[2])
		await settle(8)
		check(node("AccueilSousPage_" + str(pair[1]).trim_prefix("AccueilSousPage_")) == null and node("EntryCareerCard") != null, "%s : retour au menu" % pair[2])
		# Échap revient aussi.
		var rouvert := press(pair[0])
		await settle(8)
		await wait_engine()
		await key(KEY_ESCAPE)
		await settle(8)
		check(rouvert and node("EntryCareerCard") != null, "%s : Échap revient au menu (rouvert %s, meta %s, attente %s, voile %s)" % [pair[2], str(rouvert), str(app.get_meta("accueil_sub", "")), str(app.waiting), str(app.command_wait_overlay.blocks_input())])

func first_time() -> void:
	check(app.route == "Accueil", "Le jeu s'ouvre sur l'Accueil")
	check(node("ImmersiveWelcome") != null and node("EntryTagline") != null, "Affiche : accroche présente")
	check(node("EntryResume") == null, "Aucune reprise sans carrière")
	var principal := node("EntryNewCareer") as Button
	check(principal != null, "« Nouvelle carrière » présent")
	if principal != null:
		var style := principal.get_theme_stylebox("normal") as StyleBoxFlat
		check(style != null and close(style.bg_color, Charte.OR), "Première fois : bouton principal en aplat doré")
		check(style != null and style.corner_radius_top_left >= 999, "Bouton principal : pilule (rayon 999)")
	check(aplats_or() == ["EntryNewCareer"], "Première fois : un seul aplat doré, « Nouvelle carrière » (%s)" % ", ".join(aplats_or()))
	var catalogue: Array = app.pack_manager.creation_catalogue()
	if not catalogue.is_empty():
		var monde := node("EntryWorldCount") as Label
		check(monde != null and monde.text == "Monde · %d clubs jouables" % app.pack_manager.playable_club_count("creation"), "Chiffre du monde lu du pack chargé")
	check(windows().is_empty(), "Accueil : aucune Window ouverte")
	shot("accueil-premiere-fois")
	await sub_pages()

func resume() -> void:
	await home()
	var club: Dictionary = app.model.club
	var reprise := node("EntryResume") as Button
	check(reprise != null and not reprise.disabled, "« Reprendre la carrière » présent")
	check(golds() == ["EntryResume"], "Or : uniquement la reprise (%s)" % ", ".join(golds()))
	var nom := node("EntryClubName") as Label
	check(nom != null and nom.text == G.club_name(club), "Nom du club lu du modèle (%s)" % (nom.text if nom != null else "absent"))
	var rang := int(club.get("rank", 0))
	var classement := node("EntryRank") as Button
	if rang > 0:
		check(classement != null and classement.text.begins_with("1er" if rang == 1 else "%de" % rang), "Classement lu du modèle")
	check(node("EntrySaveLine") != null, "Ligne de sauvegarde présente")
	check(node("EntrySeasonLine") != null and (node("EntrySeasonLine") as Label).text.begins_with("Saison "), "Saison · division · journée présents")
	if app.model.get("next") is Dictionary: check(node("EntryNextMatch") != null, "Prochain match lu du modèle")
	check(windows().is_empty(), "Carrière en cours : aucune Window ouverte")
	shot("accueil-reprise")
	if classement != null:
		check(press("EntryRank"), "Le classement agit")
		await settle(10)
		check(app.route == "Classements", "Le classement ouvre sa page (%s)" % app.route)
		await home()
	if node("EntryNextMatch") != null:
		check(press("EntryNextMatch"), "Le prochain match agit")
		await settle(10)
		check(app.route == "Calendrier", "Le prochain match ouvre le calendrier (%s)" % app.route)
		await home()
	await sub_pages()
	await home()
	check(press("EntryResume"), "Reprendre agit")
	await settle(10)
	check(app.route != "Accueil", "Reprendre ouvre la carrière (%s)" % app.route)
	await home()
	check(press("EntryNewCareer"), "Nouvelle carrière agit")
	await wait_engine()
	check(app.route == "Création" and windows().is_empty(), "Nouvelle carrière ouvre le choix du club, sans fenêtre (%s)" % app.route)

func run() -> void:
	var size := OS.get_environment("CD_ACCUEIL_DA_SIZE")
	var parts := size.split("x") if not size.is_empty() else PackedStringArray(["1920", "1080"])
	root.size = Vector2i(int(parts[0]), int(parts[1]))
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle(10)
	await first_time()
	await command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"})
	await resume()
	print("ACCUEIL_DA ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
