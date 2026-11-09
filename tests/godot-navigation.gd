extends SceneTree
var app: Control
var nav: Node
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func settle() -> void:
	for i in 6: await process_frame

func named(node: Node, id: String) -> Node:
	if str(node.name) == id: return node
	for child in node.get_children():
		var found := named(child, id)
		if found != null: return found
	return null

func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok, "Worker réel : " + id)
	await settle()

func key(code: int, ctrl: bool = false, alt: bool = false, unicode: int = 0) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code; event.ctrl_pressed = ctrl; event.alt_pressed = alt
		event.unicode = unicode; event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()

func visit(route: String, id: String = "") -> void:
	app.selected_player = id
	app._navigate(route)
	await settle()

func palette() -> Window:
	return named(app, "NavigationPalette")

func palette_visible() -> bool:
	return palette() != null and palette().visible

func results() -> ItemList:
	return named(app, "NavigationResults")

func search(text: String) -> void:
	var field: LineEdit = named(app, "NavigationSearch")
	field.text = text
	field.text_changed.emit(text)
	await settle()

func squad_row(id: String) -> Button:
	for button: Button in app.body.find_children("SquadPlayer*", "Button", true, false):
		if str(button.get_meta("player_id", "")) == id: return button
	return null

func find_squad_row(id: String) -> Button:
	# The real roster is paginated. Reach the requested row through its actual
	# keyboard controls instead of assuming every player is in the current page.
	for step in 32:
		var previous: Button = named(app, "RosterPaginationPrevious")
		if previous.disabled: break
		previous.grab_focus(); await key(KEY_ENTER)
	for step in 32:
		var row := squad_row(id)
		if row != null: return row
		var next: Button = named(app, "RosterPaginationNext")
		if next.disabled: break
		next.grab_focus(); await key(KEY_ENTER)
	return null

func palette_fits(label: String) -> void:
	var dialog := palette()
	var bounds := Rect2i(Vector2i.ZERO,root.size)
	check(bounds.encloses(Rect2i(dialog.position,dialog.size)),"Palette entièrement dans la fenêtre : " + label)
	var ok: Button = dialog.get_ok_button()
	var local := ok.get_global_rect()
	check(Rect2(Vector2.ZERO,Vector2(dialog.size)).encloses(local) and bounds.encloses(Rect2i(Vector2i(local.position)+dialog.position,Vector2i(local.size))),"OUVRIR entièrement visible : " + label)
	check(Rect2(Vector2.ZERO,Vector2(dialog.size)).encloses(results().get_global_rect()),"Liste sans découpe hors dialogue : " + label)

func state() -> Dictionary:
	await command("export")
	return JSON.parse_string(app.model.meta.exportText).state

func finish() -> void:
	print("NAVIGATION : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	if app != null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	root.size = Vector2i(1440,900)
	if not ResourceLoader.exists("res://ui/navigation_controller.gd"):
		check(false, "Ctrl+K, historique et palette natifs absents")
		finish(); return
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 30000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty(), "Projection initiale du vrai worker")
	app.timer.stop()
	nav = named(app, "NavigationController")
	check(nav != null, "Contrôleur raccordé dans le vrai main")
	if nav == null:
		finish(); return
	await key(KEY_K, true)
	check(palette() != null and palette().visible, "Ctrl+K ouvre une palette native")
	check(results().item_count == 1 and results().get_item_text(0).contains("Accueil"), "Sans carrière : aucune route exigeant un modèle")
	await key(KEY_ESCAPE)
	check(not palette().visible and app.route == "Accueil", "Échap ferme la palette sans pause ni navigation")
	await command("new_career", {"club":0, "mode":"common"})
	# Reproduce a first opening with the populated career, without a pre-sized palette.
	palette().queue_free(); await settle()
	nav.reset()
	await visit("Bureau")
	var before: Dictionary = await state()
	var file := str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(file)
	var first_id := str(app.model.squad[0].id)
	var other_id := str(app.model.squad[1].id)
	await visit("Effectif", first_id)
	await visit("Finances")
	app.get_viewport().gui_release_focus()
	await key(KEY_LEFT, false, true)
	check(app.route == "Effectif" and app.selected_player == first_id, "Alt gauche restaure le dossier par son vrai ID")
	app.get_viewport().gui_release_focus()
	await key(KEY_RIGHT, false, true)
	check(app.route == "Finances", "Alt droite restaure la route suivante")
	await key(KEY_K, true)
	palette_fits("première ouverture avec carrière à1440x900")
	var palette_search: LineEdit = named(app, "NavigationSearch")
	await key(KEY_E, false, false, 233); await key(KEY_R, false, false, 114)
	check(named(app, "NavigationSearch") == palette_search and palette_search.has_focus() and palette_search.text == "ér", "Vraie frappe accentuée de la palette conserve saisie et focus")
	await search("FORMATION")
	check(results().item_count == 1 and results().get_item_text(0).contains("Formation"), "Recherche de menu sans casse")
	await key(KEY_ENTER)
	check(app.route == "Formation" and not palette().visible, "Entrée ouvre un autre chapitre")
	await visit("Effectif", other_id)
	var roster_search: LineEdit = named(app, "RosterSearch")
	roster_search.text = "___aucun_joueur___"; roster_search.text_changed.emit(roster_search.text)
	roster_search.grab_focus()
	roster_search.caret_column = 4
	await key(KEY_X, false, false, 120)
	var query := roster_search.text
	var caret := roster_search.caret_column
	check(query == "___axucun_joueur___" and caret == 5, "La vraie frappe prépare un filtre exclusif et un curseur intérieur")
	await key(KEY_K, true); await search(str(app.model.squad[0].name)); await key(KEY_ENTER)
	check(app.selected_player == first_id and app.body.find_children("SquadPlayer*", "Button", true, false).any(func(button): return str(button.get_meta("player_id", "")) == first_id), "Palette depuis un effectif filtré : cible ID réellement visible")
	var back: Button = named(app, "NavigationBack")
	back.grab_focus(); await key(KEY_ENTER)
	roster_search = named(app, "RosterSearch")
	check(app.route == "Effectif" and app.selected_player == other_id and roster_search.text == query and roster_search.caret_column == caret and roster_search.has_focus(), "Précédent restaure le joueur, le filtre, le curseur et le focus")
	var forward: Button = named(app, "NavigationForward")
	forward.grab_focus(); await key(KEY_ENTER)
	check(app.route == "Effectif" and app.selected_player == first_id, "Suivant rouvre la cible de la palette")
	var ordered: Array = load("res://ui/management_state.gd").players(app.model.squad, app.management_ui.roster, int(app.model.meta.season))
	var last_id := str(ordered.back().id)
	await key(KEY_K, true); await search("[" + last_id + "]"); await key(KEY_ENTER)
	check(app.selected_player == last_id and app.body.find_children("SquadPlayer*", "Button", true, false).any(func(button): return str(button.get_meta("player_id", "")) == last_id), "Une cible au-delà de la première page devient réellement visible depuis la palette")
	var target_page := int(app.management_ui.roster.page)
	check(target_page > 0, "La cible finale exige réellement une page ultérieure du vrai effectif")
	var previous_page: Button = named(app, "RosterPaginationPrevious")
	previous_page.grab_focus(); await key(KEY_ENTER)
	var manual_page := int(app.management_ui.roster.page)
	check(manual_page == target_page - 1 and app.selected_player == last_id, "La pagination volontaire reste possible sans changer le dossier ouvert")
	app._render(); await settle()
	check(int(app.management_ui.roster.page) == manual_page, "Une reconstruction du menu conserve la page volontaire au lieu de forcer le dossier sélectionné")
	var original: Dictionary = app.model.duplicate(true)
	app.model.squad[0].name = "Éric Même"
	app.model.squad[1].name = "Éric Même"
	app.model.squad[0].pos = "Pilier"
	app.model.squad[1].pos = "Centre"
	app.model.market.append(app.model.squad[0].duplicate(true))
	for resolution in [Vector2i(1280,720), Vector2i(1440,900), Vector2i(1600,900), Vector2i(1920,1080)]:
		root.size = resolution
		palette().queue_free(); await settle()
		await settle(); await key(KEY_K, true)
		palette_fits("résultats initiaux " + str(resolution))
		await search("Formation"); palette_fits("un seul résultat " + str(resolution))
		root.size = Vector2i(1280,720); await settle(); palette_fits("redimensionnement ouvert depuis " + str(resolution))
		root.size = resolution; await settle(); palette_fits("retour taille ouverte " + str(resolution))
		await search("E\u0301RIC MEME")
		check(results().item_count == 2, "Homonymes distincts et ID squad/market dédoublonné " + str(resolution))
		check(results().get_item_text(0) != results().get_item_text(1), "Postes et ID distinguent les homonymes " + str(resolution))
		check(palette().size.x <= root.size.x and palette().size.y <= root.size.y, "Palette bornée au viewport " + str(resolution))
		var field: LineEdit = named(app, "NavigationSearch")
		check(field.has_focus(), "Focus de recherche prêt au clavier " + str(resolution))
		await key(KEY_DOWN)
		await key(KEY_ENTER)
		check(app.route == "Effectif" and app.selected_player == other_id, "Flèche puis Entrée ouvre le second ID " + str(resolution))
		await key(KEY_K, true); await search("Formation")
		var ok: Button = palette().get_ok_button()
		var center := ok.get_global_rect().get_center() + Vector2(palette().position)
		var motion := InputEventMouseMotion.new(); motion.position = center; motion.global_position = center
		root.push_input(motion,true); await process_frame
		for pressed in [true,false]:
			var click := InputEventMouseButton.new(); click.position = center; click.global_position = center; click.button_index = MOUSE_BUTTON_LEFT; click.pressed = pressed
			root.push_input(click,true); await process_frame
		await settle()
		check(app.route == "Formation" and not palette_visible(),"OUVRIR activé à la souris " + str(resolution))
		await visit("Bureau")
	app.model = original
	var market_id := str(app.model.market[1].id)
	app.model.market[0].name = "Zoé Marché Homonyme"; app.model.market[1].name = "Zoé Marché Homonyme"
	await key(KEY_K, true); await search("zoe marche homonyme"); await key(KEY_DOWN); await key(KEY_ENTER)
	check(app.route == "Recrutement" and app.management_ui.market.navigation_id == market_id, "Piste marché ouverte sur le second identifiant")
	var market_buttons: Array = app.body.find_children("*", "Button", true, false).filter(func(button): return button.has_meta("player_id"))
	check(not market_buttons.is_empty() and market_buttons.all(func(button): return str(button.get_meta("player_id")) == market_id), "Le filtre strict ID du marché ne présente pas son homonyme")
	app.model.market[1].name = "Identité de pack renommée"
	await visit("Finances")
	app.get_viewport().gui_release_focus(); await key(KEY_LEFT, false, true)
	check(app.route == "Recrutement" and app.management_ui.market.navigation_id == market_id and app.body.find_children("*", "Button", true, false).any(func(button): return str(button.get_meta("player_id", "")) == market_id), "Historique marché restaure le même ID après renommage du pack")
	app.model = original.duplicate(true)
	var projected: Dictionary = app.model
	app.model = {"club":{"id":0}, "meta":{}}
	await key(KEY_K, true); await search("eric")
	check(results().item_count == 0, "Ancienne projection sans squad/market : aucun joueur inventé")
	await key(KEY_ESCAPE); app.model = projected
	await key(KEY_K, true); await search("___introuvable___")
	check(results().item_count == 0 and named(app, "NavigationCount").text.contains("Aucun"), "Résultat vide explicite")
	await key(KEY_ESCAPE)
	await visit("Effectif", first_id)
	var field: LineEdit = named(app, "RosterSearch")
	field.grab_focus(); await key(KEY_LEFT, false, true)
	check(app.route == "Effectif", "Alt flèche ne vole pas la saisie")
	var spin := SpinBox.new(); app.add_child(spin); spin.get_line_edit().grab_focus()
	await key(KEY_LEFT, false, true)
	check(app.route == "Effectif", "Alt flèche respecte SpinBox")
	spin.queue_free(); await settle()
	var option := OptionButton.new(); option.add_item("Choix"); app.add_child(option); option.grab_focus()
	await key(KEY_LEFT, false, true)
	check(app.route == "Effectif", "Alt flèche respecte OptionButton")
	option.queue_free(); await settle()
	app.notice("Autre dialogue", "Ne doit pas être remplacé")
	await key(KEY_K, true)
	check(not palette_visible(), "Dialogue visible : aucune palette superposée")
	app._clear_dialogs(); await settle()
	app.waiting = true; await key(KEY_K, true)
	check(not palette_visible(), "Attente commande : palette refusée")
	app.waiting = false; app.last_error = "Échec de commande"; await key(KEY_K, true)
	check(not palette_visible(), "Erreur active : palette refusée")
	app.last_error = ""; app.closing = true; await key(KEY_K, true)
	check(not palette_visible(), "Fermeture : palette refusée")
	app.closing = false
	app._command("__navigation_unknown__")
	var failed_deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < failed_deadline: await process_frame
	await settle(); await key(KEY_K, true)
	check(not app.bridge.last_response_ok and not app.last_error.is_empty() and not palette_visible(), "Échec réel d'une commande worker : palette bloquée sans effacer l'erreur")
	app.last_error = ""; app._clear_dialogs(); await settle()
	nav.reset(); await visit("Bureau"); await visit("Effectif", first_id); await visit("Finances")
	app.model.squad = app.model.squad.filter(func(p): return str(p.id) != first_id)
	app.get_viewport().gui_release_focus(); await key(KEY_LEFT, false, true)
	check(app.route == "Bureau" and app.selected_player != first_id, "Dossier disparu ignoré, aucun homonyme substitué")
	app.model = original
	nav.reset(); await visit("Bureau"); await visit("Finances"); await visit("Club")
	app.get_viewport().gui_release_focus(); await key(KEY_LEFT, false, true)
	await visit("Formation")
	app.get_viewport().gui_release_focus(); await key(KEY_RIGHT, false, true)
	check(app.route == "Formation", "Nouveau parcours après précédent : ancienne branche suivante supprimée")
	await visit("Effectif", first_id); await visit("Effectif", other_id)
	app.get_viewport().gui_release_focus(); await key(KEY_LEFT, false, true)
	check(app.selected_player == first_id, "Deux fiches d'un même écran restent deux entrées par ID")
	var second_row: Button = await find_squad_row(other_id)
	check(second_row != null, "Deuxième dossier proposé dans le vrai effectif avec sa pagination clavier")
	check(app.selected_player == first_id, "Parcourir les pages ne remplace pas le dossier avant sélection explicite")
	if second_row != null:
		second_row.grab_focus(); await key(KEY_ENTER)
		check(app.selected_player == other_id and nav.history[nav.cursor].player == other_id, "Ouverture clavier d'une fiche sans reconstruction : historique observé")
		app.get_viewport().gui_release_focus(); await key(KEY_LEFT, false, true)
		check(app.selected_player == first_id, "Précédent restaure la fiche après sélection clavier locale")
	var teams: Array = app.model.get("staff", {}).get("teams", [])
	check(teams.size() >= 2, "Le vrai modèle expose les clubs de staff")
	if teams.size() >= 2:
		app.selected_staff_club = int(teams[1].id); await visit("Staff"); await visit("Finances")
		app.get_viewport().gui_release_focus(); await key(KEY_LEFT, false, true)
		check(app.route == "Staff" and app.selected_staff_club == int(teams[1].id), "Historique restaure le club du staff par ID")
	nav.reset(); await visit("Bureau")
	for i in 65: nav.observe("Finances" if i % 2 == 0 else "Club")
	check(nav.history.size() == 60, "Historique borné à soixante entrées")
	var size_before: int = nav.history.size()
	nav.observe("Finances"); nav.observe("Finances")
	check(nav.history.size() == size_before, "Route et IDs identiques non dupliqués")
	nav.reset()
	check(nav.history.is_empty(), "Nouvelle carrière/import : historique local remis à zéro")
	await visit("Bureau")
	var controls: Control = nav.controls()
	app.root_content.add_child(controls)
	await settle()
	check(controls.get_combined_minimum_size().x <= 192, "Précédent/suivant/recherche tiennent dans la barre latérale")
	check(named(app, "NavigationBack").disabled and named(app, "NavigationForward").disabled, "Boutons bornés après reset")
	await visit("Finances")
	controls = nav.controls(); app.root_content.add_child(controls); await settle()
	check(not named(app, "NavigationBack").disabled, "Les nouveaux contrôles reflètent l'historique après remplacement du rendu")
	named(app, "NavigationBack").grab_focus(); await key(KEY_ENTER)
	check(app.route == "Bureau", "Bouton précédent utilisable au clavier après reconstruction")
	check(before == await state(), "Navigation/palette/historique : état et RNG du vrai worker inchangés")
	check(bytes == FileAccess.get_file_as_bytes(file), "Aucune écriture carrière après consultations")
	var exported: String = app.model.meta.exportText
	await visit("Finances"); await visit("Effectif", first_id)
	await command("import", {"text":exported})
	check(nav.history.size() <= 1 and nav.cursor <= 0, "Import réel réussi : aucun ancien parcours conservé")
	await visit("Finances"); await visit("Club")
	await command("new_career", {"club":1, "mode":"common"})
	check(nav.history.size() <= 1 and nav.cursor <= 0, "Nouvelle carrière réelle : ancien parcours effacé")
	finish()
