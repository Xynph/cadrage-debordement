extends RefCounted
## Écran « Recherche » de la coque (règle « jamais de petite fenêtre ») : Entrée dans le champ « Rechercher » de la
## barre haute ouvre cet écran, dans l'historique Précédent / Suivant. Les résultats viennent du contrôleur de
## navigation (navigation_controller.gd, search_results) : écrans, joueurs, clubs, staff, compétitions, sélections.
## Un clic ouvre la fiche joueur, la fiche du club ou l'écran.
const C = preload("res://ui/immersive08/components.gd")
const LIMITE := 60
const FAMILLES := [
	["Écrans", ["menu", "training"]],
	["Joueurs", ["squad", "market"]],
	["Clubs", ["club"]],
	["Staff", ["staff"]],
	["Compétitions", ["competition"]],
	["Sélections", ["nation"]],
]

static func build(app: Control) -> Control:
	var page := C.v(10)
	page.name = "SearchPage"
	C.fill(page, true)
	var query := str(app.management_ui.get("search_query", "")).strip_edges()
	var found: Dictionary = app.navigation_controller.search_results(query, LIMITE) if is_instance_valid(app.navigation_controller) else {"matches":[], "total":0}
	var total := int(found.total)
	var summary := ""
	if query.is_empty(): summary = "Un joueur, un club, un écran… Tape un nom dans « Rechercher » (Ctrl K), puis Entrée."
	elif total == 0: summary = "Aucun résultat pour « %s »." % query
	else: summary = "%d résultat%s pour « %s »%s" % [total, "s" if total > 1 else "", query, " · les %d premiers, précise ta recherche" % LIMITE if total > LIMITE else ""]
	var caption := C.wrap(summary, 20, C.MUTED)
	caption.name = "SearchSummary"
	page.add_child(caption)
	if total == 0:
		var back := _row(app, "Revenir au Bureau", func(): app._navigate("Bureau"))
		back.name = "SearchBackToOffice"
		page.add_child(back)
		return page
	var first: Button = null
	var index := 0
	for family: Array in FAMILLES:
		var rows: Array = (found.matches as Array).filter(func(candidate: Dictionary): return str(candidate.get("kind", "")) in family[1])
		if rows.is_empty(): continue
		var heading := C.label(str(family[0]).to_upper(), 18, C.MUTED, true, 600)
		heading.name = "SearchFamily_" + str(family[0])
		page.add_child(heading)
		page.add_child(C.rule())
		for candidate: Dictionary in rows:
			var entry := candidate.duplicate(true)
			var button := _row(app, _caption(str(entry.label)), func(): app.navigation_controller.open_search_result(entry))
			button.name = "SearchResult%d" % index
			button.tooltip_text = str(entry.label)
			button.set_meta("search_candidate", entry)
			page.add_child(button)
			if first == null: first = button
			index += 1
	# Fiche UX (coque-commune §7.2) : à l'ouverture, le premier résultat a le focus.
	if first != null: first.call_deferred("grab_focus")
	return page

## « Effectif · Kyle Fairclough · Pilier gauche · dossier [id] » → sans l'identifiant technique.
static func _caption(label: String) -> String:
	var bracket := label.rfind(" [")
	return label.substr(0, bracket) if bracket > 0 and label.ends_with("]") else label

static func _row(app: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size.y = maxf(C.px(43), C.TARGET_MIN)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("immersive_style_applied", true)
	button.add_theme_font_override("font", C.BODY)
	button.add_theme_font_size_override("font_size", C.font_px(20))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: button.add_theme_color_override(state, C.IVORY)
	var styles := {"normal":C.PANEL, "hover":C.RAISED, "pressed":C.SELECTED, "disabled":C.PANEL}
	for state: String in styles:
		var style := C.box(styles[state], Color.TRANSPARENT, 0, 0)
		style.set_corner_radius_all(0)
		style.content_margin_left = C.px(16)
		style.content_margin_right = C.px(16)
		button.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = C.IVORY
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	return button
