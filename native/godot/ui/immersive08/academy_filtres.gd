extends "res://ui/immersive08/academy_socle.gd"
## Écran Formation (découpe de academy_canvas.gd, sans changement) : puces, recherche et listes de filtre, choix du tri.

func _filters(group: String) -> void:
	# Bandeau des filtres (demande de Léo du 21/11/2026) : sous les onglets, détouré, à la largeur du tableau.
	Bandeau.poser(self, Rect2(0, 196, WIDTH, 54))
	var recherche := LineEdit.new()
	recherche.name = "AcademySearch"
	recherche.placeholder_text = "Chercher un jeune…"
	recherche.text = str(state.get("search", ""))
	recherche.clear_button_enabled = true
	recherche.accessibility_name = "Chercher un jeune par nom ou poste"
	recherche.add_theme_font_override("font", Charte.TEXTE)
	recherche.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	recherche.add_theme_color_override("font_color", Charte.IVOIRE)
	recherche.add_theme_color_override("font_placeholder_color", Charte.IVOIRE_3)
	recherche.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU_3, Charte.IVOIRE_3, Charte.RAYON_PILULE, 10))
	var focus := C.box(Charte.PANNEAU_3, Charte.IVOIRE, Charte.RAYON_PILULE, 10)
	focus.set_border_width_all(2)
	recherche.add_theme_stylebox_override("focus", focus)
	add_child(recherche)
	D.place(recherche, Rect2(Bandeau.MARGE, 204, 330, 38))
	recherche.text_changed.connect(func(value: String):
		state.search = value
		state.search_focus = true
		state.table_scroll = 0
		app._render())
	if state.get("search_focus", false):
		state.erase("search_focus")
		recherche.grab_focus.call_deferred()
		recherche.set_deferred("caret_column", recherche.text.length())
	var base := _filtered(group, false)
	var puces := [["", "Tous", base.size()], ["decide", "À décider", _compter(base, "decide")], ["pepite", "Pépites", _compter(base, "pepite")], ["blesse", "Blessés", _compter(base, "blesse")]]
	var x := 346.0 + Bandeau.MARGE
	for puce: Array in puces:
		var choisie := str(state.get("status", "")) == str(puce[0])
		var libelle := "%s  %d" % [puce[1], puce[2]]
		var largeur := Kit.largeur(libelle, 18) + 34
		var bouton := Button.new()
		bouton.name = "AcademyChip_" + (str(puce[0]) if not str(puce[0]).is_empty() else "tous")
		bouton.text = libelle
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		bouton.toggle_mode = true
		bouton.set_pressed_no_signal(choisie)
		bouton.add_theme_font_override("font", Charte.TEXTE)
		bouton.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(etat, Charte.IVOIRE if choisie else Charte.IVOIRE_2)
		var fond := C.box(Charte.PANNEAU_3 if choisie else Charte.PANNEAU, Charte.IVOIRE if choisie else Charte.IVOIRE_3, Charte.RAYON_PILULE, 8)
		fond.set_border_width_all(1)
		bouton.add_theme_stylebox_override("normal", fond)
		bouton.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Charte.IVOIRE_2, Charte.RAYON_PILULE, 8))
		bouton.add_theme_stylebox_override("pressed", fond)
		var focus_puce := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE, 0)
		focus_puce.set_border_width_all(2)
		bouton.add_theme_stylebox_override("focus", focus_puce)
		var valeur: String = str(puce[0])
		bouton.pressed.connect(func(): _set_filter("status", valeur))
		add_child(bouton)
		D.place(bouton, Rect2(x, 204, largeur, 38))
		x += largeur + 8
	# Groupe (maquette : U21 / U18 / Tous en puces, pas en liste) puis menus déroulants à droite : poste, tri.
	var positions := {"": "Tous"}
	for p: Dictionary in (professionals if group == "professional" else roster):
		var poste := str(p.get("pos", ""))
		if not poste.is_empty(): positions[poste] = poste
	var droite := float(WIDTH) - Bandeau.MARGE
	droite -= 360
	_picker(Rect2(droite, 204, 360, 38), "AcademyImmersiveSort", "Tri", TRIS, str(state.get("table_sort", "decide")), func(value): _sort_choice(str(value)))
	droite -= 292
	_picker(Rect2(droite, 204, 280, 38), "AcademyImmersivePosition", "Poste", positions, state.get("position", ""), func(value): _set_filter("position", value))
	var puces_groupe: Array = []
	for cle: String in ["professional", "academy", "u18", "u21"]:
		var effectif: int = professionals.size() if cle == "professional" else roster.size() if cle == "academy" else roster.filter(func(p: Dictionary): return int(p.get("age", 0)) <= 18 if cle == "u18" else (int(p.get("age", 0)) > 18 and int(p.get("age", 0)) <= 21)).size()
		var court: String = {"u21":"U21", "u18":"U18", "academy":"Tous", "professional":"Jeunes pros"}[cle]
		puces_groupe.append([cle, "%s  %d" % [court, effectif]])
	droite -= 16
	for puce: Array in puces_groupe:
		var choisi := group == str(puce[0])
		var largeur_g := Kit.largeur(str(puce[1]), 18) + 34
		droite -= largeur_g
		var bouton_g := Button.new()
		bouton_g.name = "AcademyGroup_" + str(puce[0])
		bouton_g.text = str(puce[1])
		bouton_g.accessibility_name = "Groupe : " + str(GROUPES.get(str(puce[0]), ""))
		bouton_g.focus_mode = Control.FOCUS_ALL
		bouton_g.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		bouton_g.toggle_mode = true
		bouton_g.set_pressed_no_signal(choisi)
		bouton_g.add_theme_font_override("font", Charte.TEXTE)
		bouton_g.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: bouton_g.add_theme_color_override(etat, Charte.IVOIRE if choisi else Charte.IVOIRE_2)
		var fond_g := C.box(Charte.PANNEAU_3 if choisi else Charte.PANNEAU, Charte.IVOIRE if choisi else Charte.IVOIRE_3, Charte.RAYON_PILULE, 8)
		fond_g.set_border_width_all(1)
		bouton_g.add_theme_stylebox_override("normal", fond_g)
		bouton_g.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Charte.IVOIRE_2, Charte.RAYON_PILULE, 8))
		bouton_g.add_theme_stylebox_override("pressed", fond_g)
		var focus_g := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE, 0)
		focus_g.set_border_width_all(2)
		bouton_g.add_theme_stylebox_override("focus", focus_g)
		var cle_groupe: String = puce[0]
		bouton_g.pressed.connect(func(): _set_filter("group", cle_groupe))
		add_child(bouton_g)
		D.place(bouton_g, Rect2(droite, 204, largeur_g, 38))
		droite -= 8

func _picker(zone: Rect2, id: String, caption: String, choices: Dictionary, chosen: Variant, callback: Callable) -> void:
	var control := OptionButton.new()
	control.name = id
	control.accessibility_name = caption
	control.fit_to_longest_item = false
	control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for key: Variant in choices:
		control.add_item(caption + " : " + str(choices[key]))
		control.set_item_metadata(control.item_count - 1, key)
		if key == chosen: control.select(control.item_count - 1)
	control.item_selected.connect(func(index: int): callback.call(control.get_item_metadata(index)))
	add_child(control)
	D.place(control, zone)
	Kit.styler_liste(control)

func _set_filter(key: String, value: Variant) -> void:
	state[key] = value
	if key == "group":
		state.erase("position")
		state.erase("status")
	state.table_scroll = 0
	app._render()

func _sort_choice(key: String) -> void:
	state.table_sort = key
	state.table_descending = key in ["note", "potential"]
	state.table_scroll = 0
	app._render()

func _select_visible(people: Array) -> void:
	selected = {}
	if people.is_empty(): return
	for person: Dictionary in people:
		if person.id == state.get("player"):
			selected = person
			return
	selected = people[0]
	state.player = selected.id
