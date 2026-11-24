extends SceneTree
## Création de carrière, étape « 1 Club », direction artistique « grille de cartes optimisée » (choix de Léo du 19/11/2026),
## Godot réel + worker réel, carrière Monde :
## - barre haute (← Accueil, fil 1 Club › 2 Carrière, Identités et packs, emplacement de Gabi), titre, pays, championnats ;
## - grille de cartes (Niveau, Trésorerie, conseil) triable et filtrable, panneau du club choisi (rangs, conseil, président) ;
## - l'or n'est porté que par l'action principale « Continuer avec … » (seule exception hors coque) ;
## - tout ce qui a l'air cliquable agit (sélection, tri, onglet, lien, écran suivant) ; aucune petite fenêtre ;
## - 1280 × 720 : toute la division reste visible, l'action reste dans la fenêtre, la page ne défile pas.
## - niveau du club en palier écrit (notation façon FM), jamais la note moyenne chiffrée ;
## - option « Qualités des joueurs » : Précises par défaut, un clic choisit « En fourchette », sauvegardée dans la carrière
##   créée (qualités de nos joueurs en fourchette sur la fiche).
## Imprime une ligne CREATION_DA {checks, failures}. Captures (rendu graphique) : CD_CREATION_DA_CAPTURES=<dossier>.
const Charte = preload("res://ui/charte.gd")
const Entry = preload("res://ui/entry_screens.gd")
const Notation = preload("res://ui/notation_staff.gd")
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var capture_dir := OS.get_environment("CD_CREATION_DA_CAPTURES")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 8) -> void:
	if DisplayServer.get_name() != "headless": await create_timer(.3).timeout
	for frame in frames: await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	var calm := 0
	while calm < 20 and Time.get_ticks_msec() < until:
		calm = 0 if app.waiting or not app.queued_action.is_empty() else calm + 1
		await process_frame
	app.timer.stop()
	await settle()

func node(name: String) -> Control:
	return app.root_content.find_child(name, true, false) as Control if is_instance_valid(app.root_content) else null

func press(name: String) -> void:
	var button := node(name) as BaseButton
	check(button != null and button.is_visible_in_tree() and not button.disabled, "Commande utilisable · " + name)
	if button == null or button.disabled: return
	button.pressed.emit()
	await settle()
	await wait_engine()

func shot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await settle()
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Capture " + name)

func windows() -> Array:
	return app.find_children("*", "Window", true, false).filter(func(w: Node) -> bool: return (w as Window).visible and not w is PopupMenu)

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

func cards() -> Array:
	var grid := node("CreationClubGrid") as GridContainer
	return grid.get_children() if grid != null else []

func cash(card: Node) -> float:
	var club: Dictionary = {}
	var id := int(str(card.name).trim_prefix("CreationClub"))
	for candidate: Dictionary in app.pack_manager.creation_catalogue():
		if int(candidate.id) == id: club = candidate
	return float(club.get("cashMillions", 0))

func division_fits(context: String) -> void:
	var scroll := node("CreationClubsScroll") as ScrollContainer
	check(scroll != null and scroll.size.y >= 200, "Grille de clubs à hauteur utile · " + context)
	if scroll == null: return
	for card: Control in cards():
		check(scroll.get_global_rect().grow(1).encloses(card.get_global_rect()), "Carte %s visible sans défilement · %s" % [card.name, context])
	var start := node("CreationNext")
	check(start != null and root.get_visible_rect().grow(1).encloses(start.get_global_rect()), "Action principale dans la fenêtre · " + context)
	check(app.entry_scroll == null or not (app.entry_scroll as ScrollContainer).get_v_scroll_bar().visible, "La page ne défile pas · " + context)

func run() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	check(not app.model.is_empty(), "Application et catalogue réels prêts")
	Entry.begin_creation(app)
	await settle()
	await wait_engine()
	# --- Cadre : barre haute, titre, pays, championnats ---
	for id in ["CreationTopbar", "CreationBackHome", "CreationSteps", "CreationManagePacks", "CreationGabiSlot", "CreationTitle", "CreationSearch", "CreationCountries", "CreationDivisions", "CreationClubGrid", "CreationDossier", "CreationNext", "CreationFooter"]:
		check(node(id) != null, "Élément présent · " + id)
	check(node("CreationTitle") != null and (node("CreationTitle") as Label).text == "CHOISIR SON CLUB", "Titre « Choisir son club » en capitales")
	check(node("CreationBaseIdentity") == null and node("CreationImportReality") == null, "La réalité de jeu se choisit dans Identités et packs, pas dans la barre")
	check(node("CreationCompetitionSummary") != null and node("CreationClubTitle") == null, "Le championnat est présenté avant le choix d’un club")
	var start := node("CreationNext") as Button
	check(start != null and start.disabled and "Choisis un club" in start.text, "L’action principale dit pourquoi elle est inactive")
	check(node("CreationDefis") != null, "Défis de départ sur une ligne de liens")
	var grid := node("CreationClubGrid") as GridContainer
	check(grid != null and grid.columns == 4 and grid.get_child_count() >= 8, "Grille de cartes sur quatre colonnes")
	check(node("CreationPagination") == null, "Toute la division dans une seule grille")
	division_fits("1920×1080, sans club")
	await shot("02-creation-1920-championnat")
	# --- Tri : Trésorerie ---
	await press("CreationSort_tresorerie")
	var ordered := cards()
	var sorted_ok := ordered.size() >= 2
	for index in range(1, ordered.size()):
		if cash(ordered[index - 1]) < cash(ordered[index]): sorted_ok = false
	check(sorted_ok, "Le tri Trésorerie range les cartes de la plus riche à la plus modeste")
	check((node("CreationSort_tresorerie") as Button).button_pressed and "▾" in (node("CreationSort_tresorerie") as Button).text, "Le tri actif est marqué par un état et un symbole")
	await press("CreationSort_niveau")
	# --- Recherche (filtre en place) ---
	var first: Button = cards()[0]
	var name_text := str(first.accessibility_name)
	var search := node("CreationSearch") as LineEdit
	search.text = name_text.substr(0, 5)
	search.text_changed.emit(search.text)
	await settle()
	var query := name_text.substr(0, 5).to_lower()
	check(first.visible and cards().all(func(card: Control) -> bool: return not card.visible or str(card.get_meta("recherche", "")).to_lower().contains(query)), "La recherche ne garde que les clubs qui correspondent")
	search.text = "zzzzqx"
	search.text_changed.emit(search.text)
	await settle()
	check(node("CreationSearchEmpty").visible and cards().all(func(card: Control) -> bool: return not card.visible), "Recherche vide : « Aucun club ne correspond »")
	await press("CreationSearchClear")
	check(cards().all(func(card: Control) -> bool: return card.visible) and (node("CreationSearch") as LineEdit).text.is_empty(), "« Effacer la recherche » rend toute la division")
	# --- Choix d'un club ---
	var chosen_id := int(str((cards()[1] as Node).name).trim_prefix("CreationClub"))
	await press("CreationClub%d" % chosen_id)
	check(int(app.management_ui.get(Entry.CREATION_SELECTION, -1)) == chosen_id, "Un clic sur une carte choisit le club")
	check(node("CreationClubTitle") != null and node("CreationRosterSummary") != null and node("CreationStadium") != null, "Le panneau présente le club choisi (bandeau du stade, niveau et rang)")
	var summary := node("CreationRosterSummary")
	check(summary != null and summary.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return " sur " in l.text), "Le niveau porte son rang dans la division")
	# Notation façon FM : le niveau du club est un palier écrit, jamais une note moyenne chiffrée.
	var valeur_niveau := summary.find_child("Valeur", true, false) as Label if summary != null else null
	check(valeur_niveau != null and (valeur_niveau.text in Notation.PALIERS or valeur_niveau.text.begins_with("Entre ")) and not valeur_niveau.text.replace(",", ".").is_valid_float(), "Niveau du club en palier écrit : " + (valeur_niveau.text if valeur_niveau != null else "absent"))
	check(not app.root_content.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text.to_lower() == "note moyenne"), "Plus de « note moyenne » à la création")
	var chosen_card := node("CreationClub%d" % chosen_id)
	check(chosen_card != null and chosen_card.find_child("CreationCardChosen", true, false) != null and chosen_card.find_child("CreationCardMarker", true, false) != null, "La carte choisie porte « ✓ Choisi » et un marqueur incliné (pas la couleur seule)")
	start = node("CreationNext") as Button
	check(start != null and not start.disabled and start.text.begins_with("CONTINUER AVEC"), "« Continuer avec … » s’active")
	# Un chiffre du panneau agit : Trésorerie trie la grille.
	var cash_figure := node("CreationCash")
	if cash_figure != null:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		cash_figure.gui_input.emit(click)
		await settle()
		check(str(app.management_ui.get("creation_tri", "")) == "tresorerie" and (node("CreationSort_tresorerie") as Button).button_pressed, "Le chiffre Trésorerie du panneau trie la grille")
		await press("CreationSort_niveau")
	start = node("CreationNext") as Button
	# --- L'or n'est porté que par l'action principale ---
	var golden: Array[String] = []
	for control: Control in app.root_content.find_children("*", "Control", true, false):
		if control.name != "CreationNext" and gold_on(control): golden.append(str(control.name))
	check(golden.is_empty(), "Aucun or hors de l’action principale : " + ", ".join(golden))
	check(gold_on(start), "L’action principale est en or (seule exception hors coque)")
	# --- Liens du panneau : format, rivalités ---
	var format := node("CreationFormatLink") as Button
	if format != null:
		await press("CreationFormatLink")
		check(node("CreationFormat") != null and node("CreationPresidentQuote") == null, "« Format de la division et enjeux » s’ouvre en place")
		await press("CreationFormatLink")
		check(node("CreationPresidentQuote") != null, "Le lien de retour rend le mot du président")
	await wait_engine()
	var rival: Array = app.root_content.find_children("CreationRivalLink_*", "Button", true, false)
	if not rival.is_empty():
		var rival_id := int(str(rival[0].name).trim_prefix("CreationRivalLink_"))
		await press(str(rival[0].name))
		check(int(app.management_ui.get(Entry.CREATION_SELECTION, -1)) == rival_id and node("CreationClub%d" % rival_id) != null, "Un rival se choisit d’un clic (sa division s’ouvre)")
		if node("CreationClub%d" % chosen_id) != null: await press("CreationClub%d" % chosen_id)
	check(windows().is_empty(), "Aucune petite fenêtre ouverte par la page")
	await shot("02-creation-1920")
	# --- Pays et championnats ---
	var countries: Array = app.root_content.find_children("CreationCountry_*", "Button", true, false)
	for country: Button in countries:
		if country.button_pressed: continue
		var id := str(country.name)
		await press(id)
		check((node(id) as Button).button_pressed and node("CreationCompetitionSummary") != null, "L’onglet pays ouvre son premier championnat · " + id)
		break
	var leagues: Array = app.root_content.find_children("CreationDivision_*", "Button", true, false)
	for league: Button in leagues:
		if league.button_pressed: continue
		var id := str(league.name)
		await press(id)
		check((node(id) as Button).button_pressed and cards().size() > 0, "L’onglet championnat change la grille · " + id)
		break
	if node("CreationCountry_FR") != null and not (node("CreationCountry_FR") as Button).button_pressed: await press("CreationCountry_FR")
	# --- Rôle : menus déroulants, pas de fenêtre ---
	var role := node("CreationCareerRole") as OptionButton
	if role != null:
		check(not role.get_parent() is Window, "Le rôle se choisit dans un menu déroulant de la page")
	# --- Défis de départ : un lien choisit club et défi ---
	var defi: Array = app.root_content.find_children("CreationDefi_*", "Button", true, false)
	if not defi.is_empty():
		await press(str(defi[0].name))
		check(int(app.management_ui.get(Entry.CREATION_SELECTION, -1)) >= 0 and not (node("CreationNext") as Button).disabled, "Un défi de départ choisit son club")
	# --- 1280 × 720 ---
	root.size = Vector2i(1280, 720)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await create_timer(.3).timeout
	await settle(12)
	division_fits("1280×720")
	for card: Control in cards():
		for label: Label in card.find_children("*", "Label", true, false):
			if label.is_visible_in_tree():
				check(card.get_global_rect().grow(1).encloses(label.get_global_rect()), "Le texte « %s » tient dans sa carte à 1280×720" % label.text.left(30))
				check(label.get_theme_font_size("font_size") >= 12, "Corps ≥ 12 px à 1280×720 · " + label.text.left(30))
	await shot("02-creation-1280")
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await create_timer(.3).timeout
	await settle(12)
	# --- Barre haute : Identités et packs, étape suivante, Accueil ---
	await press("CreationManagePacks")
	check(app.route == "Packs", "« Identités et packs » ouvre l’atelier")
	app.pack_manager.back()
	await settle()
	check(app.route == "Création", "Retour de l’atelier vers la création")
	if node("CreationNext") != null and not (node("CreationNext") as Button).disabled:
		await press("CreationStepCareer")
		check(app.find_child("CreationCareerOptions", true, false) != null, "« 2 Carrière » ouvre les options de carrière")
		await wait_engine()
		var rail_texts: Array = app.root_content.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
		check(rail_texts.has("1  Club") and rail_texts.has("2  Carrière") and not rail_texts.has("01  Réalité"), "Le fil de la création devient « 1 Club › 2 Carrière »")
		app.management_ui.erase(Entry.CREATION_STEP)
		app._render()
		await settle()
	await press("CreationBackHome")
	check(app.route == "Accueil", "« ← Accueil » revient à l’accueil")
	check(windows().is_empty(), "Aucune petite fenêtre en fin de parcours")
	await qualites_en_fourchette()
	print("CREATION_DA ", JSON.stringify({"checks": checks, "failures": failures}))
	app.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)

## Option de nouvelle carrière « Qualités des joueurs » (notation façon FM, 24/11) : deux pilules sur l'écran des options,
## « Précises » par défaut ; un clic sur « En fourchette tant que pas observé » choisit et valide (aucun bouton Confirmer) ;
## la carrière créée garde l'option : nos joueurs, pas encore suivis, montrent leurs qualités en fourchette sur la fiche.
func qualites_en_fourchette() -> void:
	Entry.begin_creation(app)
	await settle()
	await wait_engine()
	var premiere := cards()[0] as Button if not cards().is_empty() else null
	check(premiere != null, "Une carte de club pour la création")
	if premiere == null: return
	await press(str(premiere.name))
	await press("CreationNext")
	check(node("CreationQualitesSection") != null and node("CreationQualites_precises") != null and node("CreationQualites_fourchette") != null, "Option « Qualités des joueurs » : deux pilules")
	check(str(app.management_ui.get("creation_qualites", "precises")) == "precises", "« Précises » par défaut")
	await press("CreationQualites_fourchette")
	check(str(app.management_ui.get("creation_qualites", "")) == "fourchette", "Un clic choisit « En fourchette tant que pas observé »")
	check(node("CreationQualites_fourchette") != null and node("CreationStart") != null, "L’option reste à l’écran, sans bouton Confirmer")
	await shot("creation-qualites-fourchette")
	await press("CreationStart")
	await wait_engine()
	var squad: Array = app.model.get("squad", [])
	check(not squad.is_empty() and squad.all(func(p: Dictionary) -> bool: return p.get("attributesV2Range") is Dictionary and (p.attributesV2Range as Dictionary).size() == 36), "Carrière créée en fourchette : qualités de nos joueurs en fourchette (%d joueurs)" % squad.size())
	if squad.is_empty(): return
	await Flow.settle_club_meetings(app, self, check)
	var joueur: Dictionary = squad[0]
	app.selected_player = str(joueur.id)
	app.set_meta("immersive08_full_player", true)
	app._navigate("Effectif")
	await settle()
	app.selected_player = str(joueur.id)
	app.set_meta("immersive08_full_player", true)
	app._render()
	await settle(12)
	var cellules: Array = app.find_children("PlayerDetailedAttribute_*", "Label", true, false)
	var en_plage := cellules.filter(func(l: Label) -> bool: return bool(l.get_meta("fourchette", false)) and l.text.count("-") == 1)
	check(cellules.size() == 36 and en_plage.size() == 36, "Fiche : les 36 qualités en fourchette (%d / %d)" % [en_plage.size(), cellules.size()])
	var qualites_role: Array = app.find_children("PlayerRoleQuality_*", "Label", true, false)
	check(not qualites_role.is_empty() and qualites_role.all(func(l: Label) -> bool: return l.text.count("-") == 1 and not l.text.is_valid_float()), "Fiche : qualités du rôle en fourchette aussi (%d)" % qualites_role.size())
	var forts: Array = app.find_children("PlayerStrength_*", "Label", true, false)
	check(not forts.is_empty() and forts.all(func(l: Label) -> bool: return l.text.count("-") == 1), "Fiche : points forts en fourchette")
	await shot("fiche-qualites-fourchette")
	# Tout ce qui est calculé à partir des qualités part de la fourchette (vérificateur, 24/11) : qualités reçues = milieu
	# de chaque fourchette (radar, entraînement, Niveau au rôle), notes au poste et au rôle en lettre DOUBLE (staff pas sûr),
	# ni relevé ni flèches de progression (vraies valeurs au dixième).
	var plages: Dictionary = joueur.get("attributesV2Range", {})
	var valeurs: Dictionary = joueur.get("attributesV2", {})
	check(not plages.is_empty() and plages.keys().all(func(k: String) -> bool: return is_equal_approx(float(valeurs.get(k, -1)), (float(plages[k].min) + float(plages[k].max)) / 2.0)), "Qualités reçues par l’écran = milieu des fourchettes, jamais la vraie valeur")
	var notes_role: Array = app.find_children("PlayerRoleNote_*", "", true, false)
	check(not notes_role.is_empty() and notes_role.all(func(n: Node) -> bool: return str(n.get_meta("lettre", "")).contains("/")), "Fiche : Niveau au rôle en lettre double, incertaine (%s)" % str(notes_role.map(func(n: Node): return n.get_meta("lettre", ""))))
	check(app.find_children("Fleche_*", "", true, false).is_empty() and joueur.get("fleches") == null, "Fiche : aucune flèche de progression tant que les qualités sont en fourchette")
	var Notation = preload("res://ui/notation_staff.gd")
	var principal: int = int((joueur.get("primaryPositions", [0]) as Array)[0]) if joueur.get("primaryPositions") is Array and not (joueur.primaryPositions as Array).is_empty() else 0
	if principal > 0: check(Notation.texte_note(Notation.lettre_poste(app.model, joueur, principal, true)).contains("/"), "Note au poste principal : lettre double tant que les qualités sont en fourchette")
	# Développement › Progression et radar du comparateur : qualités en fourchette, jamais le milieu écrit comme un chiffre
	# sûr (2e revue du vérificateur, 25/11).
	app.management_ui.immersive_player_tab = 4
	app._render()
	await settle(12)
	var notes_prog: Array = app.find_children("ProgressionNote_*", "Label", true, false)
	check(notes_prog.size() == 36 and notes_prog.all(func(l: Label) -> bool: return bool(l.get_meta("fourchette", false)) and l.text.count("-") == 1), "Progression : les 36 qualités en fourchette (%d)" % notes_prog.size())
	await shot("progression-fourchette")
	app.management_ui.immersive_player_tab = 0
	if squad.size() >= 2:
		app.management_ui.compare = [str(squad[0].id), str(squad[1].id)]
		app._navigate("Effectif")
		await settle()
		load("res://ui/immersive08/comparateur_canvas.gd").ouvrir(app)
		await settle(12)
		var axes_r: Array = app.find_children("RadarAxe*Valeur*", "Label", true, false)
		check(not axes_r.is_empty() and axes_r.all(func(l: Label) -> bool: return bool(l.get_meta("fourchette", false)) and l.text.contains("-")), "Radar du comparateur : axes en fourchette (%s)" % str(axes_r.map(func(l: Label) -> String: return l.text)))
		await shot("radar-fourchette")
		var axe0 := app.find_child("RadarAxe0", true, false) as BaseButton
		check(axe0 != null, "Radar : axe cliquable")
		if axe0 != null:
			axe0.pressed.emit()
			await settle(8)
			var lignes_f: Array = app.find_children("RadarFenetreLigne_*_0", "Label", true, false)
			check(not lignes_f.is_empty() and lignes_f.all(func(l: Label) -> bool: return l.text.count("-") == 1), "Radar, fenêtre d'un axe : qualités en fourchette (%s)" % str(lignes_f.map(func(l: Label) -> String: return l.text)))
