extends RefCounted
const G = preload("res://ui/carnet_skin.gd")

static func open(app: Control, profile: RefCounted) -> AcceptDialog:
	# Une décision de carrière déjà affichée garde la priorité.
	for child in app.get_children():
		if child is ConfirmationDialog and child.visible: return null
	app._clear_dialogs()
	var dialog := AcceptDialog.new()
	dialog.name = "PreferencesDialog"
	app._prepare_dialog(dialog,680)
	dialog.title = "Paramètres de confort"
	dialog.get_ok_button().text = "FERMER"
	var scroll := ScrollContainer.new()
	scroll.name = "PreferencesScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(640,480)
	dialog.add_child(scroll)
	var content := G.v(10)
	content.custom_minimum_size.x = 620
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(G.wrap("Volume, caméra, qualité et mode calme conservés entre les carrières. Aucun changement des règles ni du rythme du match.",14,G.INK))
	var volume_row := G.h(12); content.add_child(volume_row)
	var volume_label := G.label("Volume global (%)",15); G.fill(volume_label); volume_row.add_child(volume_label)
	var volume := SpinBox.new(); volume.name = "PreferencesVolume"; volume.min_value = 0; volume.max_value = 100; volume.step = 1
	volume.suffix = "%"; volume.custom_minimum_size = Vector2(150,38); volume_row.add_child(volume)
	var motion := CheckButton.new(); motion.name = "PreferencesMotion"; motion.text = "Mouvement réduit · mode calme"; motion.custom_minimum_size.y = 40; content.add_child(motion)
	content.add_child(G.wrap("Mode calme : caméra tactique fixe et animations décoratives de Gabi figées. Les joueurs, l’audio et les bulles restent disponibles. Votre caméra préférée revient en quittant ce mode.",13))
	var camera := _choice(content,"Caméra préférée",["TV","Tactique","Action"],"PreferencesCamera")
	var quality := _choice(content,"Qualité de la scène",["Économie","Équilibrée","Détaillée"],"PreferencesQuality")
	var error := G.wrap("",13,G.ALERT); error.name = "PreferencesError"; content.add_child(error)
	var refresh := func():
		volume.set_value_no_signal(profile.data.volume)
		motion.set_pressed_no_signal(profile.data.reduced_motion)
		camera.select(["tv","tactical","action"].find(profile.data.camera))
		camera.disabled = profile.data.reduced_motion
		camera.tooltip_text = "Choix différé : le mode calme utilise une caméra tactique fixe." if profile.data.reduced_motion else "Caméra appliquée à la scène du match."
		quality.select(["economy","balanced","detail"].find(profile.data.quality))
		error.text = profile.last_error
		error.visible = not error.text.is_empty()
	volume.value_changed.connect(func(value: float): profile.set_value("volume",int(value)); refresh.call())
	motion.toggled.connect(func(value: bool): profile.set_value("reduced_motion",value); refresh.call())
	camera.item_selected.connect(func(index: int): profile.set_value("camera",["tv","tactical","action"][index]); refresh.call())
	quality.item_selected.connect(func(index: int): profile.set_value("quality",["economy","balanced","detail"][index]); refresh.call())
	var reset := G.button("Réinitialiser ces préférences",func(): profile.reset_defaults(); refresh.call())
	reset.name = "PreferencesReset"; content.add_child(reset)
	var display_row := G.h(8); content.add_child(display_row)
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
	var links := G.h(8); content.add_child(links)
	links.add_child(G.button("Importez un pack personnalisé",func():
		dialog.hide(); dialog.queue_free()
		app.pack_manager.open("career" if app._has_career() else "creation")))
	links.add_child(G.button("Aide du coach",func():
		dialog.hide(); dialog.queue_free()
		app.call_deferred("_open_coach")))
	for row in [display_row,links]:
		for button in row.get_children(): G.fill(button)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	refresh.call()
	dialog.popup_centered(Vector2i(680,570))
	volume.get_line_edit().call_deferred("grab_focus")
	return dialog

static func _choice(parent: Node, caption: String, values: Array, id: String) -> OptionButton:
	var row := G.h(12); parent.add_child(row)
	var label := G.label(caption,15); G.fill(label); row.add_child(label)
	var option := OptionButton.new(); option.name = id; option.custom_minimum_size = Vector2(220,38)
	for value in values: option.add_item(value)
	row.add_child(option)
	return option
