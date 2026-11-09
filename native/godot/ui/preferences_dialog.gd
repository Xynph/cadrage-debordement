extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const C = preload("res://ui/immersive08/components.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")

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
	var content := C.v(12)
	content.custom_minimum_size = Vector2(width-62,436)
	C.fill(content,true)
	var viewport := ScrollContainer.new()
	viewport.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	viewport.follow_focus=true
	viewport.custom_minimum_size=Vector2(width-62,436)
	dialog.add_child(viewport)
	viewport.add_child(content)
	var introduction := C.card("")
	content.add_child(introduction)
	var masthead := C.h(16)
	C.content(introduction).add_child(masthead)
	var description := C.v(5)
	C.fill(description)
	masthead.add_child(description)
	description.add_child(C.label("VOTRE POSTE DE MANAGER",18,C.GOLD,true,700))
	description.add_child(C.label("Confort de jeu",38,C.IVORY,true,700))
	description.add_child(C.wrap("Les préférences locales suivent votre profil.",18,C.MUTED))
	masthead.add_child(C.photo("club-forest",Vector2(230,95)))
	var tabs := TabContainer.new()
	tabs.name = "PreferencesTabs"
	G.fill(tabs,true)
	content.add_child(tabs)
	var comfort := G.v(9); comfort.name = "Confort"; tabs.add_child(comfort)
	var sound := G.v(10); sound.name = "Son"; tabs.add_child(sound)
	var display := G.v(10); display.name = "Affichage"; tabs.add_child(display)
	comfort.add_child(C.label("CAMÉRA ET ACCESSIBILITÉ",20,C.GOLD,true,700))
	var volume := _volume(comfort,"Volume global","PreferencesVolume")
	var motion := CheckButton.new()
	motion.name = "PreferencesMotion"; motion.text = "Mouvement réduit · mode calme"; motion.custom_minimum_size.y = 36
	comfort.add_child(motion)
	comfort.add_child(C.wrap("Le mode calme garde une caméra tactique fixe. Les joueurs, les sons et les bulles restent disponibles.",17,C.MUTED))
	var camera := _choice(comfort,"Caméra préférée",["TV","Tactique","Action"],"PreferencesCamera")
	var quality := _choice(comfort,"Qualité de la scène",["Économie","Équilibrée","Détaillée"],"PreferencesQuality")
	var sound_profile: RefCounted = app.soundscape.preferences if is_instance_valid(app.soundscape) else null
	sound.add_child(C.label("MIXAGE DE L’INTERFACE ET DU STADE",20,C.GOLD,true,700))
	sound.add_child(C.wrap("Les sons d’interface et l’ambiance du stade ont chacun leur volume.",18,C.IVORY))
	var interface_volume := _volume(sound,"Sons d’interface","PreferencesInterfaceVolume")
	var stadium_volume := _volume(sound,"Ambiance du stade","PreferencesStadiumVolume")
	sound.add_child(C.wrap("0 coupe le canal. L’ambiance accompagne le direct visible. Le volume global et la voix de Gabi gardent leurs réglages.",17,C.MUTED))
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
		interface_volume.editable = sound_profile != null
		stadium_volume.editable = sound_profile != null
		if sound_profile != null:
			interface_volume.set_value_no_signal(sound_profile.get_value("interface_volume"))
			stadium_volume.set_value_no_signal(sound_profile.get_value("stadium_volume"))
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
	quality.item_selected.connect(func(index: int): profile.set_value("quality",["economy","balanced","detail"][index]); refresh.call())
	interface_volume.value_changed.connect(func(value: float):
		if sound_profile != null: sound_profile.set_value("interface_volume",int(value))
		refresh.call())
	stadium_volume.value_changed.connect(func(value: float):
		if sound_profile != null: sound_profile.set_value("stadium_volume",int(value))
		refresh.call())
	var reset := G.button("Réinitialiser ces préférences",func(): profile.reset_defaults(); refresh.call())
	reset.name = "PreferencesReset"; comfort.add_child(reset)
	display.add_child(C.label("TAILLE DE LA FENÊTRE",20,C.GOLD,true,700))
	display.add_child(C.wrap("Le mode d’affichage s’applique à cette session.",18,C.IVORY))
	var display_row := G.h(8); display.add_child(display_row)
	var fullscreen := G.button("Plein écran",func(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN),true)
	fullscreen.name = "PreferencesFullscreen"
	fullscreen.tooltip_text = "Mode par défaut à chaque lancement du jeu."
	display_row.add_child(fullscreen)
	var windowed := G.button("Fenêtré 1440×900",func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1440,900)))
	windowed.name = "PreferencesWindowed"
	windowed.tooltip_text = "Option pour cette session : une fenêtre plus petite de 1440×900."
	display_row.add_child(windowed)
	var links := G.v(8); display.add_child(links)
	links.add_child(G.button("Importez un pack personnalisé",func():
		dialog.hide(); dialog.queue_free()
		app.pack_manager.open("career" if app._has_career() else "creation")))
	links.add_child(G.button("Aide du coach",func():
		dialog.hide(); dialog.queue_free()
		app.call_deferred("_open_coach")))
	for button in display_row.get_children(): G.fill(button)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	refresh.call()
	Dialogs.show_centered(dialog,Vector2i(width,600))
	volume.get_line_edit().call_deferred("grab_focus")
	return dialog

static func _volume(parent: Node, caption: String, id: String) -> SpinBox:
	var row := G.h(12); parent.add_child(row)
	var label := G.label(caption + " (%)",14); G.fill(label); row.add_child(label)
	var volume := SpinBox.new()
	volume.name = id; volume.min_value = 0; volume.max_value = 100; volume.step = 1
	# SpinBox commits typed text on Enter/focus exit; arrows are discrete commits.
	volume.update_on_text_changed = false
	volume.suffix = "%"; volume.custom_minimum_size = Vector2(150,36); row.add_child(volume)
	return volume

static func _choice(parent: Node, caption: String, values: Array, id: String) -> OptionButton:
	var row := G.h(12); parent.add_child(row)
	var label := G.label(caption,14); G.fill(label); row.add_child(label)
	var option := OptionButton.new(); option.name = id; option.custom_minimum_size = Vector2(220,36)
	for value in values: option.add_item(value)
	row.add_child(option)
	return option
