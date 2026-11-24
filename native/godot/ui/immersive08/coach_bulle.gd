extends "res://ui/immersive08/coach_socle.gd"
## Gabi adjoint, la bulle qui descend du bandeau : construction (coulisse, bulle, voile), affichage, fermeture, « Suivre le conseil »
## et file des commandes du conseil suivi. Hérite du socle (coach_socle.gd) ; l'écran se lit par coach_canvas.gd.

func _build() -> void:
	theme=Legacy.theme(ACCENT)
	super._build()
	_title.add_theme_font_override("font",C.BOLD)
	_title.add_theme_font_size_override("font_size",17)
	_title.add_theme_color_override("font_color",C.GOLD)
	_title.add_theme_stylebox_override("normal",_surface(C.BG,C.GOLD))
	_settings_panel.add_theme_stylebox_override("panel",_surface(C.PANEL,C.LINE))
	_error_panel.add_theme_stylebox_override("panel",_surface(Color("282020"),C.ALERT))
	_build_adjoint()

func _build_adjoint() -> void:
	_coulisse = Control.new()
	_coulisse.name = "GabiCoulisse"
	_coulisse.top_level = true
	_coulisse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coulisse.position = Vector2(-8192, -8192)
	_coulisse.size = Vector2(4, 4)
	add_child(_coulisse)
	_bulle = Bulle.new()
	_bulle.name = "GabiBulle"
	_bulle.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Charte.PANNEAU_3
	style.set_corner_radius_all(Charte.RAYON_CARTE)
	style.shadow_color = Color(0, 0, 0, .45)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	for side in [SIDE_LEFT, SIDE_RIGHT]: style.set_content_margin(side, 18)
	style.set_content_margin(SIDE_TOP, 12)
	style.set_content_margin(SIDE_BOTTOM, 14)
	_bulle.add_theme_stylebox_override("panel", Charte.ombrer(style))
	add_child(_bulle)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bulle.add_child(column)
	var head := HBoxContainer.new(); head.mouse_filter = Control.MOUSE_FILTER_IGNORE; column.add_child(head)
	_bulle_titre = Label.new(); _bulle_titre.name = "GabiBulleTitre"
	_bulle_titre.add_theme_font_override("font", C.BOLD)
	_bulle_titre.add_theme_color_override("font_color", C.GOLD)
	_bulle_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bulle_titre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_bulle_titre)
	var fermer := Button.new(); fermer.name = "GabiBulleFermer"; fermer.text = "×"; fermer.flat = true
	fermer.tooltip_text = "Fermer la bulle"
	fermer.focus_mode = Control.FOCUS_NONE
	fermer.add_theme_color_override("font_color", C.MUTED)
	fermer.add_theme_color_override("font_hover_color", C.IVORY)
	fermer.pressed.connect(fermer_bulle)
	head.add_child(fermer)
	_bulle_texte = Label.new(); _bulle_texte.name = "GabiBulleTexte"
	_bulle_texte.add_theme_font_override("font", C.BODY)
	_bulle_texte.add_theme_color_override("font_color", C.IVORY)
	_bulle_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_bulle_texte)
	# Détail dépliable (noms, remplaçants…) : la bulle reste courte, le coach déplie s'il veut.
	_bulle_detail = Label.new(); _bulle_detail.name = "GabiBulleDetail"
	_bulle_detail.add_theme_font_override("font", C.BODY)
	_bulle_detail.add_theme_color_override("font_color", C.MUTED)
	_bulle_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bulle_detail.hide()
	column.add_child(_bulle_detail)
	_bulle_actions = HBoxContainer.new(); _bulle_actions.name = "GabiBulleActions"
	_bulle_actions.add_theme_constant_override("separation", 8)
	_bulle_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_bulle_actions)
	var trait_ := ColorRect.new(); trait_.name = "GabiBulleTrait"; trait_.color = Color(C.GOLD, .22)
	trait_.custom_minimum_size.y = 1; trait_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(trait_)
	_bulle_menu = HBoxContainer.new(); _bulle_menu.name = "GabiBulleMenu"
	_bulle_menu.add_theme_constant_override("separation", 8)
	_bulle_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_bulle_menu)
	_bulle.hide()
	_voile = ColorRect.new()
	_voile.name = "GabiVoile"
	_voile.color = Color(0.02, 0.05, 0.04, 0.55)
	# Le voile assombrit seulement : il laisse passer le clic. Un clic hors de Gabi ferme le grand mode (_input) ET
	# atteint ce qu'il visait (recette native du 16/11/2026 : « Nouvelle carrière » demandait deux clics).
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile.hide()

func _montrer(contenu: Dictionary) -> void:
	_contenu = contenu.duplicate(true)
	_contenu.route = str(app.route)
	_bulle_titre.text = str(contenu.get("titre", "GABI"))
	_bulle_texte.text = str(contenu.get("texte", ""))
	var plus := str(contenu.get("plus", ""))
	_bulle_detail.text = plus
	_bulle_detail.hide()
	# Survol : le détail complet en info-bulle, même replié.
	_bulle_texte.mouse_filter = Control.MOUSE_FILTER_PASS if not plus.is_empty() else Control.MOUSE_FILTER_IGNORE
	_bulle_texte.tooltip_text = plus
	for row in [_bulle_actions, _bulle_menu]:
		for child in row.get_children():
			row.remove_child(child); child.queue_free()
	_bulle_suivre = null
	var action: Dictionary = contenu.get("action", {}) if contenu.get("action") is Dictionary else {}
	var actions: Array = contenu.get("actions", []) if contenu.get("actions") is Array else []
	# Deux premières semaines : actions directes de l'écran, puis « Compris ».
	if contenu.get("genre") == "accueil":
		for index in actions.size():
			var une: Dictionary = actions[index]
			var bouton := _button(_bulle_actions, str(une.get("libelle", "Allons-y")), "GabiAccueilAction%d" % index, suivre_conseil.bind(une))
			_primary(bouton, index == 0)
			bouton.disabled = app.waiting
			if index == 0: _bulle_suivre = bouton
		var compris := _button(_bulle_actions, "Compris", "GabiAccueilCompris", fermer_bulle)
		_primary(compris, actions.is_empty())
	elif not action.is_empty():
		_bulle_suivre = _button(_bulle_actions, str(action.get("libelle", "Suivre le conseil")), "GabiSuivreConseil", suivre_conseil)
		_primary(_bulle_suivre, true)
		_bulle_suivre.disabled = app.waiting or not app._live().is_empty()
		_bulle_suivre.tooltip_text = "Applique la proposition de Gabi (tu peux toujours la défaire)"
		_button(_bulle_actions, "Je garde mon idée", "GabiIgnorer", func(): _ecarter(); fermer_bulle())
	if not plus.is_empty():
		var deplier := _button(_bulle_actions, "Détail ▾", "GabiBulleDeplier", func(): pass)
		deplier.tooltip_text = "Noms et remplaçants proposés"
		deplier.pressed.connect(func():
			_bulle_detail.visible = not _bulle_detail.visible
			deplier.text = "Détail ▴" if _bulle_detail.visible else "Détail ▾"
			_bulle_reste += 12.0 if _bulle_detail.visible else 0.0
			_layout_bulle()
			call_deferred("_layout_bulle"))
	_bulle_actions.visible = _bulle_actions.get_child_count() > 0
	if contenu.get("genre") == "accueil":
		_button(_bulle_menu, "Aide de l'écran", "GabiMenuAide", func(): fermer_bulle(); open_help())
	elif contenu.get("genre") != "fait":
		# « Ton avis, Gabi ? » sur chaque écran : sans avis propre à l'écran, Gabi répond par sa visite guidée.
		if contenu.get("genre") != "avis":
			_button(_bulle_menu, "Ton avis, Gabi ?", "GabiMenuAvis", demander_avis)
		_button(_bulle_menu, "Aide de l'écran", "GabiMenuAide", func(): fermer_bulle(); open_help())
		_button(_bulle_menu, "Visite guidée", "GabiMenuVisite", func(): fermer_bulle(); open_tour())
	_bulle_menu.visible = _bulle_menu.get_child_count() > 0
	_bulle_menu.get_parent().get_node("GabiBulleTrait").visible = _bulle_menu.visible and _bulle_actions.visible
	var was_open := _bulle.visible
	_bulle.show()
	_bulle_reste = (BULLE_DUREE + _bulle_texte.text.length() * BULLE_PAR_CARACTERE) * (BULLE_ACTION if not action.is_empty() or not actions.is_empty() else 1.0)
	_layout_bulle()
	call_deferred("_layout_bulle")
	if not was_open: _descendre()
	_moment_portraits({"id": "adjoint:" + str(hash(_bulle_texte.text)), "categorie": str(contenu.get("categorie", "consigne")), "ton": str(contenu.get("ton", Avis.NEUTRE))})
	if portrait.has_method("mime"): portrait.mime(_bulle_texte.text)
	_maj_indice()

## Geste de Gabi (catégorie et ton du moment) dans le bandeau et, s'il est affiché, au Bureau.
func _moment_portraits(moment: Dictionary) -> void:
	if portrait.has_method("set_moment"): portrait.set_moment(moment)
	if is_instance_valid(_pied) and _pied.has_method("set_moment"): _pied.set_moment(moment)

## La bulle descend du bandeau (sans animation si le mouvement est réduit).
func _descendre() -> void:
	if _bulle_tween != null: _bulle_tween.kill()
	_layout_bulle()
	var reduced: bool = is_instance_valid(app.user_preferences) and bool(app.user_preferences.data.get("reduced_motion", false))
	if reduced:
		_bulle.modulate.a = 1.0
		return
	var target := _bulle.position
	_bulle.position.y = target.y - 14.0
	_bulle.modulate.a = 0.0
	_bulle_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bulle_tween.tween_property(_bulle, "position:y", target.y, 0.18)
	_bulle_tween.tween_property(_bulle, "modulate:a", 1.0, 0.14)

func fermer_bulle() -> void:
	if is_instance_valid(_bulle): _bulle.hide()
	_contenu.clear()
	if is_instance_valid(_visage): _maj_indice()

## Un clic ailleurs ferme la bulle (le clic continue vers ce qu'il visait) ; Échap aussi.
func _input(event: InputEvent) -> void:
	# Grand mode (aide, visite, moment clé) sous voile : un clic hors du cadre de Gabi le referme, sans consommer le clic.
	if expanded and visible and is_instance_valid(_voile) and _voile.visible and event is InputEventMouseButton and event.pressed:
		if not get_global_rect().grow(4).has_point(event.position): close()
		return
	if not is_instance_valid(_bulle) or not _bulle.visible: return
	if event is InputEventMouseButton and event.pressed:
		var at: Vector2 = event.position
		if _bulle.get_global_rect().grow(4).has_point(at): return
		if is_instance_valid(_bandeau) and _bandeau.get_global_rect().has_point(at): return
		if is_instance_valid(_bureau_figure) and _bureau_figure.is_visible_in_tree() and _bureau_figure.get_global_rect().has_point(at): return
		fermer_bulle()
	elif event.is_action_pressed("ui_cancel"):
		fermer_bulle()
		get_viewport().set_input_as_handled()

func _ecarter() -> void:
	var cle := _cle_conseil(str(app.route))
	if not cle.is_empty(): _ecartes[cle] = true
	_attente.clear(); _maj_indice()

func _cle_conseil(route: String) -> String:
	return Avis.ecran(route, app.model) + ":" + _career_context(app.model)

func suivre_conseil(action_: Dictionary = {}) -> void:
	var action: Dictionary = action_ if not action_.is_empty() else (_contenu.get("action", {}) if _contenu.get("action") is Dictionary else {})
	if action.is_empty() or app.waiting or not app._live().is_empty(): return
	_file.clear()
	match str(action.get("type", "")):
		"courrier":
			fermer_bulle()
			if str(app.route) != "Réception": app._navigate("Réception")
			if not load("res://ui/immersive08/reception_canvas.gd").open_next_unread(app):
				_montrer({"genre": "fait", "titre": "GABI", "texte": "Plus rien à lire. Continue, le temps avance.", "categorie": "approbation", "ton": Avis.POSITIF})
			else: app._render()
			return
		"commande":
			_file.append({"command": str(action.get("command", "")), "payload": (action.get("payload", {}) as Dictionary).duplicate(true) if action.get("payload") is Dictionary else {}})
			_file_message = str(action.get("message", "C'est fait."))
			fermer_bulle()
			_suite_file()
			return
		"ecran":
			fermer_bulle()
			var route := str(action.get("route", ""))
			if route == "Entraînement": app.Immersive.open_training(app)
			elif not route.is_empty(): app._navigate(route)
			return
		"composition":
			for change: Dictionary in action.get("changements", []):
				_file.append({"command": "set_lineup", "payload": {"playerId": str(change.playerId), "slot": int(change.slot)}})
			_file_message = "C'est fait. Si tu n'es pas d'accord, remets-le : c'est toi qui signes la feuille."
		"recrutement":
			var id := str(action.get("playerId", ""))
			var context: Variant = app.model.get("clubLife", {}).get("managerCareer", {}).get("context")
			var watched: bool = id in app.management_ui.get("shortlist", [])
			var verdict := str(action.get("verdict", ""))
			if context is Dictionary and ((verdict in ["fonce", "a_suivre"] and not watched) or (verdict == "passe" and watched)):
				_file.append({"command": "manager_recruitment_watch", "payload": {"context": context.duplicate(true), "playerId": id}})
			_file_message = {"fonce": "Je l'ai mis en tête de ta liste. Approche-le maintenant, sans surenchérir.", "a_suivre": "Il est dans ta liste. On le regarde jouer avant de parler argent.", "passe": "Rayé de la liste. Le bon, on le trouvera."}.get(verdict, "C'est noté.")
			if verdict == "fonce": _file.append({"ouvrir_contrat": id})
	_ecarter()
	_suite_file()

func _suite_file() -> void:
	if app.waiting: return
	if _file.is_empty():
		if not _file_message.is_empty():
			var message := _file_message
			_file_message = ""
			_montrer({"genre": "fait", "titre": "GABI", "texte": message, "categorie": "approbation", "ton": Avis.POSITIF})
		return
	var next: Dictionary = _file.pop_front()
	if next.has("ouvrir_contrat"):
		var player := Avis.marche(app.model, str(next.ouvrir_contrat))
		if not player.is_empty():
			fermer_bulle()
			app.SquadViews.contract(app, player, true)
		_suite_file()
		return
	if not app._command(str(next.command), next.payload):
		_file.clear(); _file_message = ""

## « Ton avis, Gabi ? » : avis contextuel de l'écran affiché.
func demander_avis() -> void:
	if _blocked_adjoint(): return
	var avis := Avis.avis(str(app.route), app.model, _focus_recrutement())
	if not _attente.is_empty() and _attente.get("genre") == "avis" and _attente.get("route") == str(app.route): _attente.clear()
	if avis.is_empty():
		_montrer({"genre": "menu", "titre": "TON AVIS, GABI ?", "texte": "Ici, je te laisse faire, coach. Si tu veux, je te montre comment marche cet écran, ou toute la maison.", "categorie": "question", "ton": Avis.NEUTRE})
		return
	_montrer(avis.merged({"genre": "avis", "titre": "TON AVIS, GABI ?"}))
