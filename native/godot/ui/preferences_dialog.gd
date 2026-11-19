extends RefCounted
const FocusLater := preload("res://ui/focus_later.gd")
const G = preload("res://ui/carnet_skin.gd")
const C = preload("res://ui/immersive08/components.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const Raccourcis = preload("res://ui/raccourcis_clavier.gd")

static func open(app: Control, profile: RefCounted) -> AcceptDialog:
	for child in app.get_children():
		if child is ConfirmationDialog and child.visible: return null
	app._clear_dialogs()
	var dialog := AcceptDialog.new()
	dialog.name = "PreferencesDialog"
	var width := 880 if app.get_window().size.x>=1920 else 740
	app._prepare_dialog(dialog,width)
	dialog.title = "Paramètres"
	dialog.get_ok_button().text = "FERMER"
	# Les onglets restent fixes en haut : seul le contenu de chaque onglet défile (jamais la rangée d'onglets).
	var content := C.v(10)
	content.custom_minimum_size = Vector2(width-62,400)
	C.fill(content,true)
	dialog.add_child(content)
	Dialogs.dress_title(dialog)
	var parts := _fill(app, profile, content, func(): dialog.hide(); dialog.queue_free())
	# Pied de fenêtre : filet puis bouton principal aligné à droite (plus de bouton flottant au milieu).
	content.add_child(C.rule())
	var footer := dialog.get_ok_button().get_parent()
	if footer is BoxContainer: (footer as BoxContainer).alignment = BoxContainer.ALIGNMENT_END
	dialog.get_ok_button().custom_minimum_size = Vector2(maxi(150,C.px(240)),maxi(36,C.px(52)))
	# Dans le pied, à côté de FERMER : la réinitialisation vaut pour tous les onglets et reste visible quand
	# l'onglet Confort s'allonge en carrière (vitesse du monde, conférences ordinaires).
	var reset := dialog.add_button("Réinitialiser ces préférences")
	reset.name = "PreferencesReset"
	reset.custom_minimum_size.y = dialog.get_ok_button().custom_minimum_size.y
	reset.pressed.connect(parts.reset)
	var initial_salary_period := str(profile.data.salary_period)
	var close := func():
		if initial_salary_period != str(profile.data.salary_period): app.call_deferred("_render",false)
		dialog.queue_free()
	dialog.confirmed.connect(close)
	dialog.canceled.connect(close)
	app.add_child(dialog)
	parts.refresh.call()
	# Grands écrans : le dialogue gagne en hauteur pour que l'onglet Affichage tienne entier dans sa zone défilante.
	Dialogs.show_centered(dialog,Vector2i(width,680 if app.get_window().size.y>=1080 else 600))
	FocusLater.grab(parts.focus)
	return dialog

## Écran « Réglages » de la coque (règle « jamais de petite fenêtre ») : mêmes onglets et mêmes réglages que la
## fenêtre des paramètres (encore ouverte hors carrière), montés dans la zone de contenu. Les réglages s'appliquent
## aussitôt ; « Réinitialiser » est au pied de l'écran.
static func page(app: Control, profile: RefCounted) -> Control:
	var content := C.v(10)
	content.name = "PreferencesPage"
	C.fill(content,true)
	if profile == null:
		content.add_child(C.wrap("Les réglages locaux sont indisponibles : le profil n'a pas pu être lu.",20,C.ALERT))
		return content
	var parts := _fill(app, profile, content, Callable(), true)
	content.add_child(C.rule())
	var footer := C.h(12)
	footer.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(footer)
	var reset := G.button("Réinitialiser ces préférences", parts.reset)
	reset.name = "PreferencesReset"
	reset.custom_minimum_size.y = maxi(36,C.px(52))
	footer.add_child(reset)
	parts.refresh.call()
	return content

## Contenu commun à la fenêtre et à l'écran Réglages. `quitter` referme la fenêtre avant d'ouvrir un autre écran
## (sans effet sur l'écran Réglages) ; `en_page` redessine la coque quand l'unité des salaires change.
static func _fill(app: Control, profile: RefCounted, content: VBoxContainer, quitter: Callable, en_page: bool = false) -> Dictionary:
	var leave := func():
		if quitter.is_valid(): quitter.call()
	var introduction := C.card("")
	content.add_child(introduction)
	var masthead := C.h(16)
	C.content(introduction).add_child(masthead)
	var description := C.v(5)
	C.fill(description)
	masthead.add_child(description)
	description.add_child(C.label("TON POSTE DE MANAGER",18,C.GOLD,true,700))
	description.add_child(C.label("Confort de jeu",32,C.IVORY,true,700))
	description.add_child(C.wrap("Les préférences locales suivent ton profil.",18,C.MUTED))
	masthead.add_child(C.photo("club-forest",Vector2(190,78)))
	var tabs := TabContainer.new()
	tabs.name = "PreferencesTabs"
	G.fill(tabs,true)
	content.add_child(tabs)
	tabs.custom_minimum_size.y = 280
	var comfort := _page(tabs,"Confort")
	var sound := _page(tabs,"Son")
	var display := _page(tabs,"Affichage")
	var shortcuts := _page(tabs,"Raccourcis clavier")
	# Section « Son » en tête de Confort (le volume global n'est plus rangé sous la caméra) ; les canaux détaillés sont dans l'onglet Son.
	comfort.add_child(C.label("SON",20,C.GOLD,true,700))
	var volume := _volume(comfort,"Volume global","PreferencesVolume")
	comfort.add_child(C.label("CAMÉRA ET ACCESSIBILITÉ",20,C.GOLD,true,700))
	# Même ligne « libellé à gauche, réglage à droite » que les autres réglages (police et taille identiques).
	var motion_row := G.h(12); comfort.add_child(motion_row)
	var motion_label := G.label("Mouvement réduit · mode calme",14); G.fill(motion_label); motion_row.add_child(motion_label)
	var motion := CheckButton.new()
	motion.name = "PreferencesMotion"; motion.custom_minimum_size.y = 36
	motion.accessibility_name = "Mouvement réduit · mode calme"
	motion_row.add_child(motion)
	comfort.add_child(C.wrap("Le mode calme garde une caméra tactique fixe. Les joueurs, les sons et les bulles restent disponibles.",17,C.MUTED))
	var camera := _choice(comfort,"Caméra préférée",["TV","Vue de dessus","Action"],"PreferencesCamera")
	var quality := _choice(comfort,"Qualité de la scène",["Économie","Équilibrée","Détaillée"],"PreferencesQuality")
	# Carrière Monde : championnats en détail complet ou en consultation, modifiables en cours
	# de partie (effet dès la semaine suivante, comme le niveau de détail de FM).
	var leagues: Variant = app.model.get("clubLife", {}).get("leagueDetail", {})
	if leagues is Dictionary and bool(leagues.get("available", false)):
		comfort.add_child(C.label("VITESSE DU MONDE",20,C.GOLD,true,700))
		var detail_view := preload("res://ui/league_detail_view.gd")
		var detailed: Array = []
		for league: Dictionary in leagues.get("leagues", []):
			if bool(league.get("next", league.get("detailed", true))): detailed.append(str(league.get("id", "")))
		comfort.add_child(C.wrap("%d championnat%s en détail complet, les autres en consultation." % [detailed.size(), "s" if detailed.size() > 1 else ""],17,C.MUTED))
		detail_view.request_benchmark(app)
		var gauge_box := G.v(4)
		gauge_box.name = "PreferencesLeagueSpeed"
		comfort.add_child(gauge_box)
		detail_view.gauge(gauge_box, app, detailed)
		var choose := G.button("Championnats suivis…", func():
			leave.call()
			preload("res://ui/league_detail_view.gd").open_career(app))
		choose.name = "PreferencesLeagueDetail"
		comfort.add_child(choose)
	comfort.add_child(C.label("SAUVEGARDE",20,C.GOLD,true,700))
	var autosave := _choice(comfort,"Sauvegarde automatique",["Chaque jour","Chaque semaine","Chaque mois"],"PreferencesAutosave")
	autosave.tooltip_text = "Sauvegarde complète à la fin d’une avance du calendrier. Chaque décision est notée aussitôt ; la fermeture et « Sauvegarder » enregistrent toujours tout."
	# Carrière : le réglage « Conférences ordinaires » (commande press_policy) n'existait que dans la salle de presse.
	var press_policy := _press_policy(app, comfort)
	var sound_profile: RefCounted = app.soundscape.preferences if is_instance_valid(app.soundscape) else null
	sound.add_child(C.label("MIXAGE DE L’INTERFACE ET DU STADE",20,C.GOLD,true,700))
	sound.add_child(C.wrap("Les sons d’interface et l’ambiance du stade ont chacun leur volume.",18,C.IVORY))
	var interface_volume := _volume(sound,"Sons d’interface","PreferencesInterfaceVolume")
	var stadium_volume := _volume(sound,"Ambiance du stade","PreferencesStadiumVolume")
	var match_sounds := _flag(sound,"Sons de match (public, sifflets, ambiance du stade)","PreferencesMatchSounds")
	sound.add_child(C.wrap("0 coupe le canal. L’ambiance accompagne le direct visible. Le volume global garde son réglage.",17,C.MUTED))
	display.add_child(C.label("AFFICHAGE ET UNITÉS",20,C.GOLD,true,700))
	var screen_count := 0 if DisplayServer.get_name() == "headless" else DisplayServer.get_screen_count()
	var screen_labels := ["Automatique"]
	if screen_count > 0:
		var primary := DisplayServer.get_primary_screen()
		for index in range(screen_count):
			var size := DisplayServer.screen_get_size(index)
			var suffix := " (principal)" if index == primary else ""
			screen_labels.append("Écran %d%s · %d × %d" % [index+1,suffix,size.x,size.y])
	var screen := _choice(display,"Écran de jeu",screen_labels,"PreferencesDisplayScreen")
	screen.disabled = screen_count == 0
	screen.tooltip_text = "Automatique conserve l’écran choisi au lancement. Un écran sélectionné est mémorisé."
	var salary_period := _choice(display,"Affichage des salaires",["Hebdomadaire","Mensuel","Annuel"],"PreferencesSalaryPeriod")
	display.add_child(C.wrap(preload("res://ui/salary_display.gd").CONVENTION,17,C.MUTED))
	var stadium := _choice(display,"Éclairage du stade",["Jour","Soirée"],"PreferencesStadiumLighting")
	# « Continuer » s'arrête toujours sur un match, un rendez-vous ou une décision obligatoire ; en plus :
	# Les deux arrêts de « Continuer » partagent une ligne : l'onglet tient sans défilement dans le dialogue
	# (recette Windows : boutons de mode de fenêtre entièrement visibles en 2560 × 1440).
	var continue_row := G.h(12); display.add_child(continue_row)
	var continue_label := G.label("Continuer s’arrête sur",14); G.fill(continue_label); continue_row.add_child(continue_label)
	var continue_messages := _option(continue_row,["Messages importants","Tous les messages","Aucun message"],"PreferencesContinueMessages")
	continue_messages.tooltip_text = "Les matchs, rendez-vous et décisions obligatoires arrêtent toujours « Continuer », comme les moments à savoir (veille et lendemain de match, rapport médical, fin de phase, mi-saison, marché, recruteur), parfois plusieurs fois le même jour."
	var continue_injuries := _option(continue_row,["Blessures : titulaires","Blessures : tout l’effectif"],"PreferencesContinueInjuries")
	continue_injuries.tooltip_text = continue_messages.tooltip_text
	stadium.tooltip_text = "Le réglage s’applique au stade 3D et est conservé pour les prochains matchs."
	# Même table que le pied de page et l'aide F1 (ui/raccourcis_clavier.gd).
	var shortcuts_title := C.label("RACCOURCIS CLAVIER",20,C.GOLD,true,700)
	shortcuts_title.name = "PreferencesShortcuts"
	shortcuts.add_child(shortcuts_title)
	shortcuts.add_child(C.wrap("\n".join(Raccourcis.lignes_aide()),17,C.IVORY))
	var error := C.wrap("",18,C.ALERT)
	error.name = "PreferencesError"
	error.max_lines_visible = 3
	error.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(error)
	var refresh := func():
		volume.set_value_no_signal(profile.data.volume)
		motion.set_pressed_no_signal(profile.data.reduced_motion)
		camera.select(["tv","tactical","action"].find(profile.data.camera))
		camera.disabled = profile.data.reduced_motion
		camera.tooltip_text = "Choix différé : le mode calme utilise une caméra tactique fixe." if profile.data.reduced_motion else "Caméra appliquée à la scène du match."
		quality.select(["economy","balanced","detail"].find(profile.data.quality))
		salary_period.select(["weekly","monthly","annual"].find(profile.data.salary_period))
		stadium.select(1 if profile.data.stadium == "evening" else 0)
		continue_messages.select(maxi(0,["importants","tous","aucun"].find(str(profile.data.get("continue_messages","importants")))))
		continue_injuries.select(1 if profile.data.get("continue_injuries") == "effectif" else 0)
		autosave.select(maxi(0,profile.AUTOSAVE.find(str(profile.data.get("autosave","semaine")))))
		if screen.item_count > screen_labels.size(): screen.remove_item(screen.item_count-1)
		var saved_screen: int = profile.data.display_screen
		if saved_screen >= screen_count:
			screen.add_item("Écran %d · indisponible" % (saved_screen+1))
			screen.select(screen.item_count-1)
			screen.set_item_disabled(screen.selected,true)
		else:
			screen.select(saved_screen+1)
		interface_volume.editable = sound_profile != null
		stadium_volume.editable = sound_profile != null
		match_sounds.disabled = sound_profile == null
		if sound_profile != null:
			interface_volume.set_value_no_signal(sound_profile.get_value("interface_volume"))
			stadium_volume.set_value_no_signal(sound_profile.get_value("stadium_volume"))
			match_sounds.set_pressed_no_signal(sound_profile.get_flag("match_sounds"))
		if press_policy.is_valid(): press_policy.call()
		var reasons: Array[String] = []
		if not profile.last_error.is_empty(): reasons.append(profile.last_error)
		if sound_profile != null and not sound_profile.last_error.is_empty(): reasons.append(sound_profile.last_error)
		if is_instance_valid(app.soundscape) and not app.soundscape.last_error.is_empty() and not app.soundscape.last_error in reasons: reasons.append(app.soundscape.last_error)
		error.text = "\n".join(reasons)
		error.tooltip_text = error.text
		error.visible = not error.text.is_empty()
	volume.value_changed.connect(func(value: float): profile.set_value("volume",int(value)); refresh.call())
	motion.toggled.connect(func(value: bool): profile.set_value("reduced_motion",value); refresh.call())
	camera.item_selected.connect(func(index: int): profile.set_value("camera",["tv","tactical","action"][index]); refresh.call())
	salary_period.item_selected.connect(func(index: int):
		profile.set_value("salary_period",["weekly","monthly","annual"][index])
		refresh.call()
		if en_page: app.call_deferred("_render",false))
	quality.item_selected.connect(func(index: int): profile.set_value("quality",["economy","balanced","detail"][index]); refresh.call())
	screen.item_selected.connect(func(index: int): profile.set_value("display_screen",index-1); refresh.call())
	stadium.item_selected.connect(func(index: int): profile.set_value("stadium",["day","evening"][index]); refresh.call())
	continue_messages.item_selected.connect(func(index: int): profile.set_value("continue_messages",["importants","tous","aucun"][index]); refresh.call())
	continue_injuries.item_selected.connect(func(index: int): profile.set_value("continue_injuries",["titulaires","effectif"][index]); refresh.call())
	autosave.item_selected.connect(func(index: int): profile.set_value("autosave",profile.AUTOSAVE[index]); refresh.call())
	interface_volume.value_changed.connect(func(value: float):
		if sound_profile != null: sound_profile.set_value("interface_volume",int(value))
		refresh.call())
	stadium_volume.value_changed.connect(func(value: float):
		if sound_profile != null: sound_profile.set_value("stadium_volume",int(value))
		refresh.call())
	match_sounds.toggled.connect(func(value: bool):
		if sound_profile != null: sound_profile.set_value("match_sounds",value)
		refresh.call())
	display.add_child(C.wrap("Le mode de fenêtre s’applique à cette session.",18,C.IVORY))
	var display_row := G.h(8); display.add_child(display_row)
	var fullscreen := G.button("Plein écran",app._set_display_mode.bind(Window.MODE_FULLSCREEN),true)
	fullscreen.name = "PreferencesFullscreen"
	fullscreen.tooltip_text = "Mode par défaut à chaque lancement du jeu."
	display_row.add_child(fullscreen)
	var windowed := G.button("Fenêtré maximisé",app._set_display_mode.bind(Window.MODE_MAXIMIZED))
	windowed.name = "PreferencesWindowed"
	windowed.tooltip_text = "Occupe tout l’espace disponible sur l’écran choisi, avec la barre des tâches accessible."
	display_row.add_child(windowed)
	var links := G.h(8); display.add_child(links)
	links.add_child(G.button("Importe un pack personnalisé",func():
		leave.call()
		app.pack_manager.open("career" if app._has_career() else "creation")))
	links.add_child(G.button("Aide du coach",func():
		leave.call()
		app.call_deferred("_open_coach")))
	links.get_child(0).name = "PreferencesPack"; links.get_child(1).name = "PreferencesCoachHelp"
	for button in display_row.get_children() + links.get_children(): G.fill(button)
	return {"refresh":refresh, "focus":volume.get_line_edit(), "reset":func(): profile.reset_defaults(); refresh.call()}

## Page d'onglet : zone défilante propre à l'onglet (la rangée d'onglets ne défile jamais). Retourne la colonne de contenu.
static func _page(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_child(scroll)
	var column := G.v(10)
	column.name = "Contenu"
	C.fill(column)
	scroll.add_child(column)
	return column

static func _volume(parent: Node, caption: String, id: String) -> SpinBox:
	var row := G.h(12); parent.add_child(row)
	var label := G.label(caption + " (%)",14); G.fill(label); row.add_child(label)
	var volume := SpinBox.new()
	volume.name = id; volume.min_value = 0; volume.max_value = 100; volume.step = 1
	# SpinBox commits typed text on Enter/focus exit; arrows are discrete commits.
	volume.update_on_text_changed = false
	volume.suffix = "%"; volume.custom_minimum_size = Vector2(150,36); row.add_child(volume)
	return volume

static func _flag(parent: Node, caption: String, id: String) -> CheckBox:
	var box := CheckBox.new()
	box.name = id; box.text = caption; parent.add_child(box)
	return box

static func _choice(parent: Node, caption: String, values: Array, id: String) -> OptionButton:
	var row := G.h(12); parent.add_child(row)
	var label := G.label(caption,14); G.fill(label); row.add_child(label)
	return _option(row,values,id)

static func _option(row: Node, values: Array, id: String) -> OptionButton:
	var option := OptionButton.new(); option.name = id; option.custom_minimum_size = Vector2(220,36)
	for value in values: option.add_item(value)
	row.add_child(option)
	return option

## Rubrique « Carrière et club » de l'onglet Confort : « Conférences ordinaires : y aller / envoyer l'adjoint ».
## Même commande moteur que la salle de presse (press_policy) ; préférence de carrière, permise pendant un rendez-vous.
## Retourne la fonction qui relit le modèle (vide hors carrière de club).
static func _press_policy(app: Control, parent: Node) -> Callable:
	var policy: Variant = app.model.get("clubLife", {}).get("press", {}).get("policy", {})
	if not policy is Dictionary or policy.is_empty() or app.model.get("international", {}).get("role") == "nation": return Callable()
	var section := G.v(6)
	section.name = "PreferencesPressSection"
	parent.add_child(section)
	section.add_child(C.label("CARRIÈRE ET CLUB",20,C.GOLD,true,700))
	var row := G.h(12)
	section.add_child(row)
	var caption := G.label("Conférences ordinaires",14)
	G.fill(caption)
	row.add_child(caption)
	var choices := G.h(8)
	choices.name = "PreferencesPressPolicy"
	row.add_child(choices)
	var explanation := C.wrap("",17,C.MUTED)
	explanation.name = "PreferencesPressNotice"
	section.add_child(explanation)
	var refresh := _press_refresh.bind(app, choices, explanation)
	refresh.call()
	return refresh

## Les boutons sont reconstruits à chaque lecture du modèle ; aucune fermeture ne se référence elle-même.
static func _press_refresh(app: Control, choices: HBoxContainer, explanation: Label) -> void:
	var now := _press_current(app)
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	for option: Array in [["moi", "Y aller"], ["adjoint", "Envoyer l’adjoint"]]:
		var key: String = option[0]
		var button := G.button(option[1], func(): _press_choose(app, key, choices, explanation), key == now)
		button.name = "PreferencesPressPolicy_" + key
		button.custom_minimum_size = Vector2(190,36)
		button.tooltip_text = "Réglage actuel." if key == now else "Choisir ce réglage."
		choices.add_child(button)
	explanation.text = "Gabi répond à la presse lors des conférences ordinaires ; tu restes convoqué aux grands rendez-vous (arrivée, phase finale, bilan de saison, derby, crise). Gabi s’exprime sur un ton prudent : ni moral ni confiance gagnés, un léger coût auprès des médias." if now == "adjoint" else "Tu réponds toi-même à chaque conférence : « Continuer » s’arrête sur la conférence de la semaine. Choisis l’adjoint pour que Gabi tienne les conférences ordinaires ; tu restes convoqué aux grands rendez-vous."

static func _press_current(app: Control) -> String:
	return "adjoint" if str(app.model.get("clubLife", {}).get("press", {}).get("policy", {}).get("ordinary", "moi")) == "adjoint" else "moi"

static func _press_choose(app: Control, key: String, choices: HBoxContainer, explanation: Label) -> void:
	if _press_current(app) == key: return
	app._command("press_policy", {"ordinary":key})
	_press_refresh(app, choices, explanation)
	# Un refus du moteur ramène le modèle à l'ancien réglage : relire un instant plus tard (le minuteur meurt avec la boîte).
	var later := Timer.new()
	later.one_shot = true
	later.wait_time = 0.8
	explanation.add_child(later)
	later.timeout.connect(_press_refresh.bind(app, choices, explanation))
	later.start()
