extends "res://ui/immersive08/club_histoire.gd"
## Écran Club (choix de Léo du 19/11/2026 : maquette « 1 · Deux colonnes, le conseil à gauche », avec le tableau
## « ce qui a fait bouger la confiance » de la maquette 2). Vue d'ensemble : titre et onglets, bandeau du club, à gauche
## le conseil (note en lettre et domaines du bilan, objectif, bilans : conseil_lettre.gd, revue FM27 n° 8) et les
## installations, à droite « À décider » et le vestiaire.
## Tout ce qui ressemble à un lien, une ligne ou un chiffre ouvre un écran ; aucune petite fenêtre (confirmations en place,
## actions longues du staff en sous-pages : club_pages.gd). Coordonnées en unités du gabarit (2248 de large), jetons de la charte.

static func build(app: Control, canvas: Control) -> void:
	canvas.name = "ImmersiveClub"
	var tab: String = str(app.management_ui.get(KEY, "history" if app.management_ui.get("club_tab", 0) == 1 else "overview"))
	match app.route:
		"Stratégie": tab = "direction"
		"Staff", "Travail du club": tab = "staff"
	_header(app, canvas, tab)
	if app.route == "Staff" and not Pages.actuelle(app).is_empty():
		Pages.build(app, canvas)
	else:
		var corps := Control.new()
		corps.name = "ClubBody"
		corps.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(corps)
		# Les onglets autres que la vue d'ensemble sont dessinés depuis y = 214 : le corps les remonte sous les onglets.
		corps.position = Vector2(0, (TOP - 214.0) * C.density)
		corps.size = Vector2(W, HAUT) * C.density
		match app.route:
			"Stratégie": _direction(app, corps)
			"Staff", "Travail du club": _staff_detail(app, corps)
			_:
				match tab:
					"infrastructure": _infrastructure_detail(app, corps)
					"history": _history(app, corps)
					"territory": _territory(app, corps)
					"jeu": ConseilJeu.build(app, corps)
					"organigramme": Organigramme.build(app, corps)
					_: _overview(app, canvas)
	# Confirmations d'argent EN PLACE (main.gd les route ici) : bloc posé en haut de la page, jamais une fenêtre.
	var hote := VBoxContainer.new()
	hote.name = "ClubConfirmHote"
	hote.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.add_child(hote)
	D.place(hote, Rect2(0, TOP + 8, W - 40, 10))

static func _header(app: Control, canvas: Control, tab: String) -> void:
	var titre := Kit.titre_page(canvas, 0, 46, "Club", 40, 150)
	titre.name = "ClubTitle"
	var sous := Kit.texte(canvas, 150, 46, _sous_titre(app), Charte.IVOIRE_2, 1900, 19)
	sous.name = "ClubSubtitle"
	var x := 0.0
	var onglets: Array = TABS
	for i in onglets.size():
		var key: String = onglets[i][0]
		var libelle: String = str(onglets[i][1])
		var choisi := key == tab or (key == "overview" and tab == "territory")
		var id := "ClubTab_" + key
		var largeur := C.DISPLAY.get_string_size(libelle, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(22))).x / C.density + 44
		var bouton := Button.new()
		bouton.name = id
		bouton.text = libelle
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# Charte §7.1 : onglet en pilule, bas de casse, comme les onglets de la coque ; actif = aplat crème, texte PANNEAU.
		bouton.add_theme_font_override("font", C.DISPLAY)
		bouton.add_theme_font_size_override("font_size", maxi(12, C.px(22)))
		D.tab_state(bouton, Vector2(largeur, 46), choisi, "")
		bouton.icon = null
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE, 18)
		focus.set_border_width_all(2)
		focus.set_expand_margin_all(2)
		bouton.add_theme_stylebox_override("focus", focus)
		bouton.toggle_mode = true
		bouton.button_pressed = choisi
		bouton.pressed.connect(func(): _tab(app, key, id))
		bouton.gui_input.connect(func(evenement: InputEvent):
			if evenement is InputEventKey and evenement.pressed and not evenement.echo and evenement.keycode in [KEY_LEFT, KEY_RIGHT]:
				var cible := clampi(i + (1 if evenement.keycode == KEY_RIGHT else -1), 0, onglets.size() - 1)
				if cible != i: _tab(app, onglets[cible][0], "ClubTab_" + str(onglets[cible][0]))
				bouton.accept_event())
		canvas.add_child(bouton)
		D.place(bouton, Rect2(x, 70, largeur, 46))
		x += largeur + 6
	D.line(canvas, Vector2(0, 117), Vector2(W, 117), Charte.FILET)
	# Raccourci ← → : en info-bulle des onglets, plus en mode d'emploi écrit (règle de Léo du 21/11/2026).
	for onglet: Node in canvas.get_children():
		if onglet is Button and str(onglet.name).begins_with("ClubTab_"): (onglet as Button).tooltip_text = "← → pour changer d’onglet"

static func _overview(app: Control, canvas: Control) -> void:
	var strategie := U.strategy(app.model)
	var finance: Dictionary = strategie.get("finance", {})
	var board: Dictionary = strategie.get("board", {})
	var page := Control.new()
	page.name = "ClubOverview"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	D.place(page, Rect2(0, TOP, W, HAUT - TOP))
	_hero(app, page, strategie.get("fans", {}))
	var haut := 126.0
	var gauche := 1404.0
	var droite_x := gauche + 22.0
	var droite_l := W - droite_x
	_conseil(_panneau(page, Rect2(0, haut, gauche, 650), "Le conseil", "ClubCouncil"), app, finance, board)
	_installations(_panneau(page, Rect2(0, haut + 666, gauche, 302), "Installations", "ClubFacilities"), app, finance, strategie)
	var decider := _panneau(page, Rect2(droite_x, haut, droite_l, 436), "À décider", "ClubDecide")
	_decider(decider, app, finance, board, strategie)
	_vestiaire(_panneau(page, Rect2(droite_x, haut + 452, droite_l, 516), "Vestiaire", "ClubLocker"), app)
