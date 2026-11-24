extends "res://ui/contract_review_socle.gd"
## Échéances des contrats : pastilles, tuiles, fenêtre de joueurs, adaptation de la mise en page (découpe sans changement).
## Chaîne d'héritage : socle ← aides ← corps ← ce fichier public (contract_review.gd).

## Délégation des prolongations au directeur sportif (mode Monde : la clé « contracts » n'existe qu'alors).
func _delegation_staff(delegation: Dictionary) -> void:
	var box := CheckBox.new()
	box.name = "ContractDelegationStaff"
	box.text = "Confier aussi les prolongations au staff"
	box.button_pressed = bool(delegation.get("contracts", true))
	box.tooltip_text = "Le directeur sportif tranche en mars les fins de contrat que tu n'as pas réglées, dans la masse salariale que le club s'autorise et sous le plafond de la ligue."
	box.custom_minimum_size.y = 36
	box.add_theme_font_size_override("font_size", maxi(16, C.px(20)))
	box.disabled = not app._live().is_empty()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	row.add_child(box)
	# Le paragraphe d'aide devient une pastille compacte (icône + « Staff · mars · consigne ») ; le texte complet
	# reste en infobulle derrière le « i ». Le libellé complet est gardé dans ce nœud masqué (lecture et tests).
	var detail := _label(delegation_detail(app.model, box.button_pressed), 16, C.MUTED)
	detail.name = "ContractDelegationDetail"
	detail.visible = false
	row.add_child(detail)
	var chip := _chip_button("ContractDelegationChip", "people", C.MUTED, delegation_chip(app.model, box.button_pressed), detail.text, func(): app._navigate("Staff"), true)
	var chip_text := chip.get_meta("label") as Label
	row.add_child(chip)
	box.toggled.connect(func(value: bool):
		# Même mécanisme que les autres réglages de délégation (staff_view.gd) : décision optimiste côté interface.
		if app._command("set_delegation", {"key":"contracts", "enabled":value}):
			detail.text = delegation_detail(app.model, value)
			chip_text.text = delegation_chip(app.model, value)
			chip.tooltip_text = detail.text
		else:
			box.set_pressed_no_signal(not value))

func _label(text: String, size: int = 18, color: Color = C.IVORY, width: float = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", C.BODY)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0:
		label.custom_minimum_size.x = width
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return label

## Une colonne du tableau : largeur minimale réduite, le reste partagé selon le poids (même règle en-tête et lignes).
## Tuile de chiffre (libellé + nombre), cliquable : ouvre le marché des transferts.
func _tile(caption: String, value: int, id: String, tip: String, color: Color, glyph: String) -> Button:
	var tile := Button.new()
	tile.name = id
	tile.custom_minimum_size = Vector2(0, 66)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.tooltip_text = tip
	tile.accessibility_name = "%s : %d" % [caption, value]
	tile.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU_3, Charte.FILET, Charte.RAYON_CARTE, 10))
	tile.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_2, C.FAINT, Charte.RAYON_CARTE, 10))
	tile.add_theme_stylebox_override("pressed", C.box(Charte.SELECTION, C.IVORY, Charte.RAYON_CARTE, 10))
	tile.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, C.GOLD, Charte.RAYON_CARTE, 10))
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 0)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tint := color if value > 0 else Charte.GRIS_VERT
	var top_line := HBoxContainer.new()
	top_line.alignment = BoxContainer.ALIGNMENT_CENTER
	top_line.add_theme_constant_override("separation", 8)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(top_line)
	top_line.add_child(C.icon(glyph, 24, tint))
	var number := _label(str(value), 28, tint)
	number.autowrap_mode = TextServer.AUTOWRAP_OFF
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(number)
	var name_label := _label(caption, 16, C.MUTED)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)
	tile.pressed.connect(func(): Pages.ouvrir(app, "offres"))
	return tile

## Contenu non cliquable lui-même : tous les enfants laissent passer la souris au bouton qui les porte.
func _ignore_mouse(node: Node) -> void:
	if node is Control: (node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): _ignore_mouse(child)

## Bouton à contenu libre (tuile, pastille, ligne de barre) : fond teinté, survol, focus en anneau, curseur main.
func _link_button(id: String, content: Control, fill: Color, tip: String, action: Callable, radius: int = Charte.RAYON_CARTE, margin: int = 10) -> Button:
	var link := Button.new()
	link.name = id
	link.tooltip_text = tip
	link.focus_mode = Control.FOCUS_ALL
	link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	link.add_theme_stylebox_override("normal", C.box(fill, Color.TRANSPARENT, radius, margin))
	link.add_theme_stylebox_override("hover", C.box(fill.lerp(Color.WHITE, 0.06), Color.TRANSPARENT, radius, margin))
	link.add_theme_stylebox_override("pressed", C.box(fill.lerp(Color.WHITE, 0.12), Color.TRANSPARENT, radius, margin))
	link.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, Charte.IVOIRE, radius, margin))
	_ignore_mouse(content)
	link.add_child(content)
	link.custom_minimum_size = content.get_combined_minimum_size() + Vector2(margin * 2, margin * 2)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, margin)
	link.pressed.connect(action)
	return link

## Pastille cliquable : icône teintée + texte (+ « i » facultatif). Le libellé est gardé en méta « label ».
func _chip_button(id: String, glyph: String, tint: Color, text: String, tip: String, action: Callable, info: bool = false) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(C.icon(glyph, 18, tint))
	var label := _label(text, 16, C.IVORY)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	if info: row.add_child(C.icon("info", 16, C.MUTED))
	var chip := _link_button(id, row, Charte.PANNEAU_3, tip, action, Charte.RAYON_PILULE, 6)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.set_meta("label", label)
	return chip

## Petite fenêtre visuelle : les joueurs concernés en tuiles (portrait, prénom, NOM, poste, salaire). Échap, ✕ et clic à côté la ferment.
func _ouvrir_fenetre(titre: String, filtres: Dictionary, teinte: Color, focus: String) -> void:
	_fermer_fenetre()
	var joueurs: Array = filtered(app.model.get("squad", []), filtres)
	state.focus = focus
	var calque := Control.new()
	calque.name = "ContractWindowLayer"
	calque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	calque.z_index = 50
	app.add_child(calque)
	_fenetre = calque
	PetiteFenetre.enregistrer(calque, _fermer_fenetre)
	var voile := ColorRect.new()
	voile.name = "ContractWindowVeil"
	voile.color = Color(Charte.NUIT, 0.6)
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	voile.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: _fermer_fenetre())
	calque.add_child(voile)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.add_child(centre)
	var panneau := PanelContainer.new()
	panneau.name = "ContractWindow"
	panneau.add_theme_stylebox_override("panel", C.box(Charte.PANNEAU, teinte, Charte.RAYON_CARTE, 18))
	centre.add_child(panneau)
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 14)
	panneau.add_child(boite)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 14)
	boite.add_child(tete)
	var titre_label := _label(titre, 30, teinte)
	titre_label.name = "ContractWindowTitle"
	titre_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tete.add_child(titre_label)
	var compte := _label(str(joueurs.size()), 30, C.IVORY)
	compte.autowrap_mode = TextServer.AUTOWRAP_OFF
	tete.add_child(compte)
	var espace := Control.new()
	espace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(espace)
	var fermer := Button.new()
	fermer.name = "ContractWindowClose"
	fermer.text = "✕"
	fermer.focus_mode = Control.FOCUS_ALL
	fermer.custom_minimum_size = Vector2(44, 44)
	fermer.accessibility_name = "Fermer"
	fermer.pressed.connect(_fermer_fenetre)
	tete.add_child(fermer)
	var defilement := ScrollContainer.new()
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defilement.custom_minimum_size = Vector2(4 * 236 + 3 * 12, minf(560.0, 88.0 * ceilf(maxf(1.0, joueurs.size()) / 4.0)))
	boite.add_child(defilement)
	var grille := GridContainer.new()
	grille.columns = 4
	grille.add_theme_constant_override("h_separation", 12)
	grille.add_theme_constant_override("v_separation", 12)
	defilement.add_child(grille)
	for joueur: Dictionary in joueurs: grille.add_child(_tuile_joueur(joueur, teinte))
	var premier := grille.get_child(0) if grille.get_child_count() > 0 else fermer
	(premier as Control).call_deferred("grab_focus")

func _tuile_joueur(joueur: Dictionary, teinte: Color) -> Button:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 10)
	var portrait: Control = G.portrait(int(joueur.get("portraitIndex", 0)), 60, joueur)
	portrait.custom_minimum_size = Vector2(60, 60)
	ligne.add_child(portrait)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 0)
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	ligne.add_child(colonne)
	var mots := str(joueur.get("name", "Joueur")).split(" ", false)
	var nom_famille: Array = []
	var prenom: Array = []
	for mot: String in mots:
		if mot == mot.to_upper() and mot.length() > 1: nom_famille.append(mot)
		else: prenom.append(mot)
	if nom_famille.is_empty() and not prenom.is_empty(): nom_famille.append(prenom.pop_back())
	var petit := _label(" ".join(prenom), 14, C.MUTED)
	petit.autowrap_mode = TextServer.AUTOWRAP_OFF
	colonne.add_child(petit)
	var gras := _label(" ".join(nom_famille), 20, C.IVORY)
	gras.autowrap_mode = TextServer.AUTOWRAP_OFF
	colonne.add_child(gras)
	var pastilles := HBoxContainer.new()
	pastilles.add_theme_constant_override("separation", 6)
	colonne.add_child(pastilles)
	var poste := _label(position_text(joueur), 14, teinte)
	poste.autowrap_mode = TextServer.AUTOWRAP_OFF
	pastilles.add_child(poste)
	var salaire := _label(G.salary_amount(joueur.get("salary")), 14, BLEU)
	salaire.autowrap_mode = TextServer.AUTOWRAP_OFF
	pastilles.add_child(salaire)
	var identifiant := str(joueur.get("id", ""))
	var tuile := _link_button(action_id("ContractWindowPlayer", identifiant), ligne, Charte.PANNEAU_3.lerp(teinte, 0.14), str(joueur.get("name", "Joueur")), func():
		_fermer_fenetre()
		call("_open_profile", identifiant, "", action_id("ContractWindowPlayer", identifiant)), Charte.RAYON_PETIT, 8)
	tuile.custom_minimum_size = Vector2(236, 76)
	tuile.size_flags_horizontal = Control.SIZE_FILL
	return tuile

func _fermer_fenetre() -> void:
	if _fenetre != null and is_instance_valid(_fenetre):
		_fenetre.remove_from_group(PetiteFenetre.GROUPE)
		_fenetre.queue_free()
	_fenetre = null
	call_deferred("_restore_focus")

## Filtre posé depuis une tuile ou une barre : les menus et le tableau suivent.
func _apply_filter(values: Dictionary, focus: String) -> void:
	state.merge(values, true)
	state.scroll = 0
	state.focus = focus
	_sync_choices()
	call("_refresh")
	call_deferred("_restore_focus")

func _sync_choices() -> void:
	for index in _season.item_count:
		if int(_season.get_item_metadata(index)) == int(state.season): _season.select(index)
	_select_text(_status_choice, str(state.status), "Contrats : tous")
	_select_text(_precision_choice, str(state.precision), "Échéance : toutes")
	_select_text(_position, str(state.position), "Tous les postes")

func _select_text(choice: OptionButton, value: String, first: String) -> void:
	if choice == null: return
	choice.select(0)
	for index in choice.item_count:
		if choice.get_item_text(index) == value: choice.select(index)

func _fit(control: Control, key: String) -> Control:
	for column: Array in COLS:
		if column[0] == key:
			control.custom_minimum_size.x = column[1]
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			control.size_flags_stretch_ratio = column[2]
	return control

func _adapt() -> void:
	if _columns == null or _columns.get_child_count() < 2: return
	var host := get_parent_control()
	var width := host.size.x if host != null and host.size.x > 0 else size.x
	var wide := width >= LARGEUR_DEUX_COLONNES
	_columns.vertical = not wide
	var main_box := _columns.get_child(0) as Control
	var sidebar_box := _columns.get_child(1) as Control
	sidebar_box.custom_minimum_size = Vector2(440, 0) if wide else Vector2(0, 360)
	main_box.size_flags_stretch_ratio = 3.6 if wide else 1.0
	main_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_box.size_flags_stretch_ratio = 1.0
	# Page étroite : le panneau passe sous le tableau ; la page s'allonge (et défile) pour qu'il reste lisible.
	if host != null:
		if not host.has_meta("hauteur_page"): host.set_meta("hauteur_page", host.custom_minimum_size.y)
		var base := float(host.get_meta("hauteur_page"))
		host.custom_minimum_size.y = base if wide else maxf(base, position.y + get_combined_minimum_size().y + 40.0)

func _button(text: String, id: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	button.custom_minimum_size.y = 34
	button.add_theme_font_override("font", C.BOLD)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", C.IVORY)
	# Charte : pilule à contour FILET, focus en anneau doré (jamais de rectangle à angles vifs).
	var anneau := C.box(Color.TRANSPARENT, C.GOLD, 999, 14)
	anneau.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, C.LINE, 999, 14))
	button.add_theme_stylebox_override("hover", C.box(C.RAISED, C.FAINT, 999, 14))
	button.add_theme_stylebox_override("focus", anneau)
	button.pressed.connect(action)
	return button

func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", C.box(C.PANEL, C.LINE, 4, 10))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	return body
