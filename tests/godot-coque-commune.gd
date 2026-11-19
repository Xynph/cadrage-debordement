extends SceneTree
# Coque commune (charte §7.1, design/ux/coque-commune.md), carrière Monde réelle :
#   - rail : ordre exact des entrées, aucun numéro, chaque entrée et chaque action du pied ouvre son écran ;
#   - barre haute : chaque morceau du fil d'Ariane est cliquable, Menu, date, Précédent / Suivant ;
#   - jamais de petite fenêtre : Ctrl+K met le focus dans le champ (aucune Window), Entrée ouvre l'écran Recherche,
#     Réglages et Sauvegarder n'ouvrent aucune Window (le menu Échap reste une fenêtre, exception de Léo) ;
#   - un seul aplat or dans la coque (Continuer) ; recomposition sans chevauchement à 1280, 1920 et 2560.
const Flow = preload("helpers/contextual_flow.gd")
const Charte = preload("res://ui/charte.gd")
const ORDRE := ["Bureau", "Réception", "Effectif", "Tactique", "Recrutement", "Club", "Finances", "Compétitions", "Formation"]
const DESTINATIONS := {"Bureau":"Bureau", "Réception":"Réception", "Effectif":"Effectif", "Tactique":"Composition", "Recrutement":"Recrutement",
	"Club":"Club", "Finances":"Finances", "Compétitions":"Classements", "Formation":"Formation", "Presse":"Presse", "Sélections":"Sélections"}
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

func settle(frames := 6) -> void:
	for frame in frames: await process_frame
	var until := Time.get_ticks_msec() + 60000
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	for frame in 3: await process_frame

func wait_idle(limit_ms := 240000) -> void:
	var until := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func key(code: int, ctrl := false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = ctrl
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()

func named(id: String) -> Node:
	return app.root_content.find_child(id, true, false) if is_instance_valid(app.root_content) else null

func press(id: String) -> bool:
	var button := named(id) as BaseButton
	check(button != null and button.is_visible_in_tree() and not button.disabled, "Bouton « %s » visible et actif" % id)
	if button == null or button.disabled: return false
	button.pressed.emit()
	await settle()
	return true

func visible_windows() -> Array:
	return app.find_children("*", "Window", true, false).filter(func(w: Window): return w.visible and not w.is_queued_for_deletion())

func close_gabi() -> void:
	var coach: Variant = app.get("coach")
	if not is_instance_valid(coach): return
	if coach.has_method("fermer_bulle"): coach.fermer_bulle()
	if coach.get("expanded") == true and coach.has_method("close"): coach.close()

func finish() -> void:
	print("COQUE COMMUNE : ", checks, " contrôles ; ", failures.size(), " échec(s)")
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
	app._command("new_career", {"mode": "world-champ", "club": 102, "start": "premiers-clubs"})
	await wait_idle()
	await Flow.settle_club_meetings(app, self, check)
	close_gabi()
	app._navigate("Bureau")
	await settle()
	await rail()
	await footer()
	await breadcrumb()
	await search()
	await top_actions()
	await gold_once()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		await layout(size)
	finish()

func rail() -> void:
	var entries: Array = app.root_content.find_children("Nav_*", "Button", true, false)
	var captions: Array = entries.map(func(b: Button): return b.text)
	var expected: Array = ORDRE + ["Presse"] + (["Sélections"] if app.model.get("international") is Dictionary else [])
	check(captions == expected, "Rail dans l'ordre exact : " + ", ".join(captions))
	var rail_node: Control = named("ImmersiveSidebar")
	for button: Button in rail_node.find_children("*", "Button", true, false):
		var text := button.text.strip_edges()
		check(text.is_empty() or not text.substr(0, 1).is_valid_int(), "Aucun numéro devant « %s »" % text)
	check(entries.size() >= 9 and entries[2].tooltip_text.contains("touche 3"), "La touche 3 est dite dans l'infobulle d'Effectif")
	check(named("Nav_Entraînement") == null, "Entraînement est rangé sous Tactique (plus d'entrée dans le rail)")
	for caption: String in expected:
		var destination: String = DESTINATIONS[caption]
		if app.route == destination: app._navigate("Finances" if destination != "Finances" else "Bureau"); await settle()
		close_gabi()
		if not await press("Nav_" + caption): continue
		check(app.route == destination, "Rail « %s » ouvre %s (%s)" % [caption, destination, app.route])
		var active := named("Nav_" + caption) as Button
		check(active != null and active.has_meta("rail_actif") and active.find_child("RailActiveMarker", true, false) != null, "Entrée « %s » marquée active (fond et filet incliné)" % caption)
	check(app.route == "Presse" or app.route == "Sélections", "Presse s'ouvre depuis le rail, hors conférence")
	app._navigate("Composition"); await settle()
	check(await press("TacticsTab4") and app.route == "Préparation" and app.Immersive._is_training(app), "Tactique → onglet Entraînement")
	check((named("Nav_Tactique") as Button).has_meta("rail_actif"), "Entraînement garde Tactique active dans le rail")
	app._navigate("Bureau"); await settle()
	check(await press("ImmersiveClubHeader") and app.route == "Club", "En-tête du club : fiche du club (%s)" % app.route)
	var context := named("ImmersiveClubContext") as Label
	check(context != null and context.text == app.Immersive.club_context(app.model) and not context.text.is_empty(), "« Division · rang » lu dans les données du club (%s)" % (context.text if context != null else "?"))

func footer() -> void:
	app._navigate("Bureau"); await settle()
	check(await press("ImmersiveSidebarAction0") and app.route == "Carrière", "Pied : Carrière")
	check(await press("ImmersiveSidebarAction1") and app.route == "Réglages", "Pied : Réglages ouvre l'écran Réglages")
	check(visible_windows().is_empty(), "Réglages : aucune fenêtre")
	check(named("PreferencesPage") != null and named("PreferencesTabs") != null, "Écran Réglages : onglets des paramètres dans la coque")
	var renders: int = app.screen_renders
	var line := named("ImmersiveSaveLine") as Button
	check(line != null and (line.text.begins_with("Sauvegardé") or line.text.begins_with("Pas encore")), "Ligne de sauvegarde au pied du rail (%s)" % (line.text if line != null else "?"))
	var save := named("ImmersiveSidebarAction2") as Button
	check(save != null and save.find_child("Touche_CtrlS", true, false) != null, "Sauvegarder montre « Ctrl S »")
	save.pressed.emit()
	check(app.last_command == "save", "Sauvegarder envoie la sauvegarde directement")
	check(visible_windows().is_empty(), "Sauvegarder : aucune fenêtre")
	await settle()
	line = named("ImmersiveSaveLine") as Button
	check(line != null and line.text.begins_with("Sauvegardé"), "Après la sauvegarde : « Sauvegardé <date> » (%s)" % (line.text if line != null else "?"))
	check(app.route == "Réglages" and app.screen_renders >= renders, "La sauvegarde ne quitte pas l'écran")

func breadcrumb() -> void:
	app._navigate("Calendrier"); await settle()
	var crumbs: Array = []
	for i in 3:
		var crumb := named("ImmersiveCrumb%d" % i) as Button
		if crumb != null: crumbs.append(crumb.text)
	check(crumbs.size() == 3 and crumbs[1] == "Compétitions" and crumbs[2] == "Calendrier", "Fil d'Ariane « Club / Compétitions / Calendrier » (%s)" % " / ".join(crumbs))
	check(await press("ImmersiveCrumb0") and app.route == "Club", "Fil : le club ouvre sa fiche (%s)" % app.route)
	app._navigate("Calendrier"); await settle()
	check(await press("ImmersiveCrumb1") and app.route == "Classements", "Fil : la section ouvre sa page racine (%s)" % app.route)
	app._navigate("Calendrier"); await settle()
	var renders: int = app.screen_renders
	check(await press("ImmersiveCrumb2") and app.route == "Calendrier" and app.screen_renders > renders, "Fil : la sous-page se rouvre")
	app._navigate("Effectif"); await settle()
	var player: Dictionary = app.model.squad[0]
	app.navigation_controller.open_entity({"kind":"player", "id":str(player.id)}); await settle()
	check((named("ImmersiveCrumb2") as Button).text.begins_with("Fiche joueur"), "Fil sur la fiche joueur")
	check(await press("ImmersiveCrumb1") and app.route == "Effectif" and not app.get_meta("immersive08_full_player", false), "Fil : « Effectif » quitte la fiche joueur")

func search() -> void:
	app._navigate("Bureau"); await settle()
	await key(KEY_K, true)
	var field := named("ImmersiveSearch") as LineEdit
	check(field != null and app.get_viewport().gui_get_focus_owner() == field, "Ctrl+K : focus dans le champ de la barre haute")
	check(visible_windows().is_empty() and app.get_node_or_null("NavigationPalette") == null, "Ctrl+K : aucune fenêtre")
	await key(KEY_ESCAPE)
	check(app.get_viewport().gui_get_focus_owner() != field and visible_windows().is_empty(), "Échap dans le champ vide : rend le focus, sans ouvrir le menu")
	await key(KEY_F, true)
	check(app.get_viewport().gui_get_focus_owner() == named("ImmersiveSearch") and visible_windows().is_empty(), "Ctrl+F : même champ, aucune fenêtre")
	var player: Dictionary = app.model.squad[0]
	var query := str(player.name).split(" ")[-1]
	field = named("ImmersiveSearch") as LineEdit
	field.text = query
	field.text_submitted.emit(query)
	await settle()
	check(app.route == "Recherche" and visible_windows().is_empty(), "Entrée : écran Recherche dans la coque (%s)" % app.route)
	var result := named("SearchResult0") as Button
	check(result != null, "Recherche « %s » : au moins un résultat" % query)
	var target := ""
	for button: Button in app.root_content.find_children("SearchResult*", "Button", true, false):
		if str(button.get_meta("search_candidate", {}).get("id", "")) == str(player.id): result = button
	if result != null:
		target = str(result.get_meta("search_candidate", {}).get("route", ""))
		result.pressed.emit(); await settle()
		check(app.route == target and app.route != "Recherche", "Résultat cliquable : %s (%s)" % [target, app.route])
	check(await press("NavigationBack") and app.route == "Recherche", "Précédent revient aux résultats (%s)" % app.route)
	check((named("ImmersiveSearch") as LineEdit).text == query, "Le champ garde la recherche")
	check(await press("NavigationForward") and app.route == target, "Suivant rouvre le résultat (%s)" % app.route)
	app._navigate("Bureau"); await settle()

func top_actions() -> void:
	app._navigate("Effectif"); await settle()
	check(await press("ImmersiveCalendarDate") and app.route == "Calendrier", "Date : Calendrier")
	var date := named("ImmersiveDateText") as Label
	check(date != null and not date.text.is_empty() and not date.text.contains("JANV.") and date.text == date.text.to_lower(), "Date en minuscules, format « mar. 17 nov. » (%s)" % (date.text if date != null else "?"))
	var back := named("NavigationBack") as Button
	check(back != null and back.tooltip_text == "Page précédente · Alt+←", "Infobulle « Page précédente · Alt+← »")
	check(await press("ImmersiveMenu"), "Menu de la barre haute")
	var pause := app.get_node_or_null("ImmersivePauseMenu") as Window
	check(pause != null and pause.visible, "Menu : le menu pause (fenêtre, exception de Léo)")
	if pause != null: pause.hide(); pause.queue_free()
	await settle()
	var continuer := named("ImmersiveContinue") as Button
	var hint := continuer.get_node_or_null("ContinueHint") as Label if continuer != null else null
	check(hint != null and not hint.text.is_empty(), "Continuer écrit « Espace » ou ce qui l'arrête (%s)" % (hint.text if hint != null else "?"))
	var next_day := named("ImmersiveNextDay") as Button
	if next_day != null: check(next_day.get_theme_color("font_color").is_equal_approx(app.Immersive.C.MUTED), "« +1 j » en texte discret, jamais en or")
	check(named("GabiF1") != null and named("GabiBandeau") != null, "Médaillon de Gabi et touche F1 dans la barre")

## Aplat or : Incline, ColorRect, fond de StyleBoxFlat et texte couleur or dans le rail et la barre haute.
func gold_once() -> void:
	app._navigate("Effectif"); await process_frame
	var found: Array[String] = []
	for zone_name in ["ImmersiveSidebar", "ImmersiveTopbar"]:
		var zone := named(zone_name) as Control
		for node: Node in [zone] + zone.find_children("*", "Control", true, false):
			if not (node as Control).is_visible_in_tree(): continue
			var colors: Array[Color] = []
			if node.has_method("_draw") and node.get("couleur") is Color: colors.append(node.get("couleur"))
			if node is ColorRect: colors.append((node as ColorRect).color)
			if node is Label: colors.append((node as Label).get_theme_color("font_color"))
			if node is Button:
				colors.append((node as Button).get_theme_color("font_color"))
				var style := (node as Button).get_theme_stylebox("normal") as StyleBoxFlat
				if style != null and style.draw_center: colors.append(style.bg_color)
			if node is Panel:
				var box := (node as Panel).get_theme_stylebox("panel") as StyleBoxFlat
				if box != null and box.draw_center: colors.append(box.bg_color)
			for color: Color in colors:
				if color.a > .5 and (color.is_equal_approx(Charte.OR) or color.is_equal_approx(Charte.OR_VIF)): found.append(str(node.name))
	check(found == ["ContinuePlate"], "Un seul aplat or dans la coque : Continuer (%s)" % ", ".join(found))

func layout(size: Vector2i) -> void:
	root.size = size
	app._render(false)
	await settle()
	var label := "%dx%d" % [size.x, size.y]
	var topbar := named("ImmersiveTopbar") as Control
	var rail_node := named("ImmersiveSidebar") as Control
	check(topbar != null and rail_node != null, label + " : coque construite")
	if topbar == null or rail_node == null: return
	# 232 × 48 px à 1920 × 1080 (309 × 64 en référence 2560), à l'échelle du gabarit (densité × facteur de _fit_layout).
	var scale: float = app.Immersive.C.density * (named("ImmersiveLayout") as Control).scale.y
	check(absf(topbar.get_global_rect().size.y - 64.0 * scale) <= 1.5, "%s : barre haute de %.1f px (%.1f attendus)" % [label, topbar.get_global_rect().size.y, 64.0 * scale])
	check(absf(rail_node.get_global_rect().size.x - 309.0 * scale) <= 1.5, "%s : rail de %.1f px (%.1f attendus)" % [label, rail_node.get_global_rect().size.x, 309.0 * scale])
	if size == Vector2i(1920, 1080): check(absf(rail_node.get_global_rect().size.x - 232.0) <= 1.5 and absf(topbar.get_global_rect().size.y - 48.0) <= 1.5, "1920x1080 : rail 232 px, barre 48 px")
	# Éléments de la barre : aucun chevauchement, tous dans la fenêtre.
	var rects: Array = []
	for child: Node in topbar.get_children():
		if not child is Control or not (child as Control).is_visible_in_tree() or child is ColorRect: continue
		if child is Label and (child as Label).text == "/": continue
		var r := (child as Control).get_global_rect()
		if r.size.x < 2.0: continue
		check(r.end.x <= size.x + 1.0 and r.position.x >= rail_node.get_global_rect().end.x - 1.0, "%s : %s dans la barre" % [label, child.name])
		for other: Array in rects:
			check(not r.grow(-1.0).intersects((other[1] as Rect2).grow(-1.0)), "%s : %s ne chevauche pas %s" % [label, child.name, other[0]])
		rects.append([child.name, r])
	# Rail : les entrées ne passent pas sous le pied ; aucun texte sous 12 px réels.
	var dock := named("ImmersiveSidebarDock") as Control
	var sections := named("ImmersiveSidebarSections") as Control
	check(sections.get_global_rect().end.y <= dock.get_global_rect().position.y + 1.0, "%s : les entrées ne passent pas sous le pied du rail" % label)
	check(dock.get_global_rect().end.y <= size.y + 1.0, "%s : pied du rail dans la fenêtre" % label)
	for zone: Control in [rail_node, topbar]:
		for node: Control in zone.find_children("*", "Control", true, false):
			if not node.is_visible_in_tree() or not (node is Label or node is Button or node is LineEdit): continue
			var text: String = node.get("text") if node.get("text") is String else ""
			if text.is_empty() and not node is LineEdit: continue
			var pixels := float(node.get_theme_font_size("font_size")) * node.get_global_transform().get_scale().y
			check(pixels >= 11.9, "%s : « %s » à %.1f px réels (plancher 12)" % [label, text, pixels])
	var name_label := named("ImmersiveClubName") as Label
	check(name_label != null and name_label.get_line_count() <= 2 and name_label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "%s : nom du club entier (%d ligne(s))" % [label, name_label.get_line_count() if name_label != null else -1])
