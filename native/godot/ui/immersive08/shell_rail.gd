extends RefCounted
## Coque commune : rail de gauche (en-tête du club, entrées, pied de page du rail : Carrière, Réglages, sauvegarde).
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Reception = preload("res://ui/immersive08/reception_canvas.gd")
const Selections = preload("res://ui/international_view.gd")
const G = preload("res://ui/game_skin.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Barre = preload("res://ui/immersive08/shell_barre.gd")
const Outils = preload("res://ui/immersive08/shell_outils.gd")
const Shell = preload("res://ui/immersive08/shell.gd")

## Section du rail qui contient la route (fil d'Ariane, entrée active).
static func rail_section(route: String) -> Array:
	for entry: Array in Shell.RAIL_SECTIONS + [["Presse", "Presse", ["Presse"]], ["Sélections", "Sélections", ["Sélections"]], ["Carrière", "Carrière", ["Carrière"]], ["Réglages", "Réglages", ["Réglages"]], ["Recherche", "Recherche", ["Recherche"]]]:
		if route in entry[2]: return entry
	return [route, route, [route]]

## « Division · rang » sous le nom du club, lus dans les données du club en cours (jeu de base ou pack Rugby Réel).
static func club_context(model: Dictionary) -> String:
	var division := P.league_name(model)
	var club: Dictionary = model.get("club", {}) if model.get("club") is Dictionary else {}
	var rank := P.rank_ordinal(club)
	return division if rank == "—" else division + " · " + rank

## « Division · rang » ajusté à `room` (unités de référence) : [texte, taille, lignes]. Une ligne en 16 (12 px à
## 1920), sinon deux lignes, puis la taille descend jusqu'au plancher de 12 px réels ; si cela ne suffit toujours pas,
## la division est raccourcie avec « … » mais « · rang » reste entier.
static func fit_context(context: String, rank: String, room: float) -> Array:
	if Outils._rw(C.BODY, context, 16) <= room: return [context, 16.0, 1]
	var size := 16.0
	while true:
		if D.title_lines(C.BODY, context, Outils._fpx(size), room * C.density) <= 2: return [context, size, 2]
		if Outils._fpx(size) <= Outils._coque_floor or size <= 1.0: break
		size -= 1.0
	# Au plancher de 12 px : trois lignes plutôt qu'une division coupée.
	if D.title_lines(C.BODY, context, Outils._fpx(size), room * C.density) <= 3: return [context, size, 3]
	var suffix := " · " + rank if not rank.is_empty() and context.ends_with(" · " + rank) else ""
	var division := context.trim_suffix(suffix)
	while division.length() > 1:
		division = division.substr(0, division.length() - 1).strip_edges()
		var candidate := division + "…" + suffix
		if D.title_lines(C.BODY, candidate, Outils._fpx(size), room * C.density) <= 2: return [candidate, size, 2]
	return [context, size, 2]
static func _rail_entries(app: Control) -> Array:
	return Shell.RAIL_NATION if Selections.nation_only(app.model) else Shell.RAIL_SECTIONS

static func _sidebar(parent: Node, app: Control) -> void:
	var rail := Control.new()
	rail.name = "ImmersiveSidebar"
	rail.custom_minimum_size.x = C.px(Shell.RAIL_WIDTH)
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(rail)
	var background := ColorRect.new()
	background.name = "ImmersiveSidebarBackground"
	background.color = C.PANEL
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var national := Selections.nation_only(app.model)
	var rail_top := _rail_header(rail, app, national) + (Shell.RAIL_TOP - Shell.RAIL_HEADER)
	var sections: Array = _rail_entries(app)
	var secondary: Array = []
	if not national:
		secondary.append(["Presse", "Presse", ["Presse"]])
		if app.model.get("international") is Dictionary: secondary.append(["Sélections", "Sélections", ["Sélections"]])
	# Lignes de 59 (44 px à 1920, pilule de 40 px) compressibles jusqu'à 55 ; au-delà, le groupe central défile, le pied
	# reste fixe.
	var height: float = app.get_window().size.y / C.density
	var available := maxf(Shell.RAIL_ROW_MIN, height - rail_top - Shell.RAIL_DOCK - 8.0)
	var gap := Shell.RAIL_GAP if not secondary.is_empty() else 0.0
	var weight := sections.size() + secondary.size() * Shell.RAIL_ROW_SMALL / Shell.RAIL_ROW
	var row := clampf(floorf((available - gap) / weight), Shell.RAIL_ROW_MIN, Shell.RAIL_ROW)
	var small := roundf(row * Shell.RAIL_ROW_SMALL / Shell.RAIL_ROW)
	var total := sections.size() * row + gap + secondary.size() * small
	var scroll := ScrollContainer.new()
	scroll.name = "ImmersiveSidebarSections"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if total > available else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	rail.add_child(scroll)
	D.place(scroll, Rect2(0, rail_top, Shell.RAIL_WIDTH, minf(total, available)))
	var column := Control.new()
	column.name = "ImmersiveSidebarColumn"
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.custom_minimum_size = Vector2(Shell.RAIL_WIDTH, total) * C.density
	scroll.add_child(column)
	var y := 0.0
	for i in sections.size():
		_rail_entry(column, app, sections[i], y, row, i)
		y += row
	if not secondary.is_empty():
		D.line(column, Vector2(27, y + 11), Vector2(Shell.RAIL_WIDTH - 27, y + 11), C.LINE)
		y += gap
		for entry: Array in secondary:
			_rail_entry(column, app, entry, y, small, -1)
			y += small
	_rail_dock(rail, app, national)

## En-tête : écusson, nom du club (Barlow Condensed ExtraBold Italic, capitales), « division · rang », liseré club-trait
## incliné. Un clic ouvre la fiche du club (pour son propre club : l'écran Club, décision de Léo du 14/11/2026).
## Retourne la hauteur réelle de l'en-tête (unités de référence) : elle grandit quand le texte, au plancher de 12 px,
## ne tient plus dans les 152 de base ; les entrées du rail descendent d'autant.
static func _rail_header(rail: Control, app: Control, national: bool) -> float:
	var header := Outils._shell_button("ImmersiveClubHeader")
	header.tooltip_text = "Fiche du club"
	if app.route == "Club" and not national: header.add_theme_stylebox_override("normal", Outils._style(C.SELECTED))
	(header.get_theme_stylebox("focus") as StyleBoxFlat).set_expand_margin_all(0)
	rail.add_child(header)
	D.place(header, Rect2(0, 0, Shell.RAIL_WIDTH, Shell.RAIL_HEADER))
	var club: Dictionary = app.model.get("club", {}) if app.model.get("club") is Dictionary else {}
	header.pressed.connect(func():
		if national: app._navigate("Sélections")
		elif not club.has("id") or not app.navigation_controller.open_entity({"kind":"club", "id":str(int(club.get("id", -1)))}): app._navigate("Club"))
	var nation := Selections.managed_team(app.model)
	var identity := str(nation.get("name", "Sélection")) if national else G.club_name(club)
	var crest: Control = Selections.nation_badge(nation, C.px(53)) if national else G.crest(club, C.px(53))
	crest.name = "ImmersiveClubCrest"
	header.add_child(crest)
	D.place(crest, Rect2(27, 36, 53, 67))
	for node in [crest] + crest.find_children("*", "Control", true, false): (node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Nom : une ligne en 27 (20 px à 1920), sinon deux lignes (jusqu'à 21) ; jamais de « … », infobulle complète.
	var room := Shell.RAIL_WIDTH - 96.0 - 21.0
	var font: Font = Charte.TITRE_EXTRA_ITALIQUE
	var caption := identity.to_upper()
	var chosen := 27.0
	var lines := 1
	if Outils._rw(font, caption, 27) > room:
		lines = 2
		chosen = 21.0
		for candidate in [24.0, 23.0, 22.0, 21.0]:
			if _lines_ref(font, caption, candidate, room) <= 2:
				chosen = candidate
				break
	var line_height := font.get_height(Outils._fpx(chosen)) / C.density
	var top := 40.0 if lines == 1 else 30.0
	var name_label := Outils._label(header, Rect2(96, top, room, line_height * lines), caption, chosen, C.IVORY, font)
	name_label.name = "ImmersiveClubName"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if lines == 2 else TextServer.AUTOWRAP_OFF
	name_label.max_lines_visible = 2
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# La taille minimale mise en cache (texte sur une ligne) bornerait la largeur : on la recalcule avant de placer.
	name_label.update_minimum_size()
	D.place(name_label, Rect2(96, top, room, line_height * lines))
	header.tooltip_text = identity + " · fiche du club" if not national else identity
	var context := "Sélection nationale" if national else club_context(app.model)
	# « Division · rang » : même calcul sur tous les écrans (fit_context) : une ligne, puis deux lignes, puis 12 px,
	# puis la division se raccourcit — le rang n'est jamais perdu ; texte complet en infobulle.
	var rank := "" if national or P.rank_ordinal(app.model.get("club", {}) if app.model.get("club") is Dictionary else {}) == "—" else P.rank_ordinal(app.model.club)
	var fitted := fit_context(context, rank, room)
	var sub_line := C.BODY.get_height(Outils._fpx(float(fitted[1]))) / C.density
	var sub_height := maxf(21.0, sub_line) * int(fitted[2])
	var sub_top := top + line_height * lines + 2
	var header_height := maxf(Shell.RAIL_HEADER, sub_top + sub_height + 30.0)
	D.place(header, Rect2(0, 0, Shell.RAIL_WIDTH, header_height))
	var sub := Outils._label(header, Rect2(96, sub_top, room, sub_height), str(fitted[0]), float(fitted[1]), C.MUTED, C.BODY)
	sub.name = "ImmersiveClubContext"
	sub.tooltip_text = context
	sub.set_meta("context_complet", context)
	sub.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	if int(fitted[2]) >= 2:
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.max_lines_visible = int(fitted[2])
		sub.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	sub.update_minimum_size()
	D.place(sub, Rect2(96, sub_top, room, sub_height))
	header.tooltip_text = (identity + " · " + context + " · fiche du club") if not national else identity
	var stripe := Outils._aplat(header, Rect2(27, header_height - 17, Shell.RAIL_WIDTH - 48, 4), Charte.club_trait(app.accent))
	stripe.name = "ImmersiveClubStripe"
	return header_height

## Nombre de lignes d'un texte coupé aux mots (largeur en unités de référence).
static func _lines_ref(font: Font, text: String, size_ref: float, width_ref: float) -> int:
	return D.title_lines(font, text, Outils._fpx(size_ref), width_ref * C.density)

## Entrée du menu latéral (charte §7.1) : pilule de 40 px en Barlow Condensed SemiBold ; au repos texte et icône
## gris-vert, survol panneau-2 ; active = aplat crème, icône et texte PANNEAU (meta « rail_actif »).
static func _rail_pill(button: Button, selected: bool) -> void:
	button.add_theme_font_override("font", C.DISPLAY)
	button.add_theme_font_size_override("font_size", Outils._fpx(24))
	if selected:
		for state in ["normal", "hover", "pressed", "hover_pressed"]: button.add_theme_stylebox_override(state, Outils._style(C.IVORY, Charte.RAYON_PILULE))
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: button.add_theme_color_override(key, Charte.PANNEAU)
		button.set_meta("rail_actif", true)
	else:
		for key in ["font_color", "font_focus_color"]: button.add_theme_color_override(key, C.MUTED)

## Rectangle de la pilule centrée dans une ligne du rail (unités de référence).
static func _rail_pill_rect(y: float, height: float) -> Rect2:
	var pill := minf(Shell.RAIL_PILL, height - 2.0)
	return Rect2(Shell.RAIL_INSET, y + (height - pill) / 2.0, Shell.RAIL_WIDTH - 2.0 * Shell.RAIL_INSET, pill)

static func _rail_entry(column: Control, app: Control, entry: Array, y: float, height: float, index: int) -> Button:
	var caption: String = entry[0]
	var destination: String = entry[1]
	var selected: bool = app.route in entry[2]
	var button := Outils._shell_button("Nav_" + caption, false, Charte.RAYON_PILULE)
	button.text = caption
	_rail_pill(button, selected)
	button.tooltip_text = caption + (" · touche %d" % (index + 1) if index >= 0 and index < 9 else "")
	button.accessibility_name = caption
	column.add_child(button)
	var rect := _rail_pill_rect(y, height)
	D.place(button, rect)
	Outils._button_margins(button, Shell.RAIL_LABEL, 70 if destination == "Réception" else 12)
	button.pressed.connect(func(): app._navigate(destination))
	var icon_id := str(Shell.RAIL_ICONS.get(caption, ""))
	if not icon_id.is_empty():
		var icon := TextureRect.new()
		icon.name = "RailIcon"
		icon.texture = C.icon_texture(icon_id, Charte.PANNEAU if selected else C.MUTED)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		D.place(icon, Rect2(Shell.RAIL_PAD, (rect.size.y - Shell.RAIL_ICON) / 2.0, Shell.RAIL_ICON, Shell.RAIL_ICON))
	if destination == "Réception":
		var unread: int = Reception.unread(app)
		if unread > 0:
			# Compteur : pastille rayon 6, crème au repos ; sur l'entrée active (aplat crème) elle passe en PANNEAU.
			var text := "99+" if unread > 99 else str(unread)
			var width := maxf(37.0, Outils._rw(C.BODY, text, 21) + 20.0)
			var chip_height := minf(32.0, rect.size.y - 12.0)
			var badge := Panel.new()
			badge.name = "RailUnreadBadge"
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.add_theme_stylebox_override("panel", Outils._style(Charte.PANNEAU if selected else C.IVORY, Shell.RAYON_PETIT_REF))
			button.add_child(badge)
			D.place(badge, Rect2(rect.size.x - 14 - width, (rect.size.y - chip_height) / 2.0, width, chip_height))
			Outils._label(badge, Rect2(0, 0, width, chip_height), text, 21, C.IVORY if selected else Charte.PANNEAU, C.BOLD, HORIZONTAL_ALIGNMENT_CENTER).name = "RailUnreadCount"
			button.accessibility_name = "Réception, %d message%s non lu%s" % [unread, "s" if unread > 1 else "", "s" if unread > 1 else ""]
	return button

## Pied du rail : Carrière, Réglages, Sauvegarder (« Ctrl S »), puis la ligne « ✓ Sauvegardé <date du jeu> ».
static func _rail_dock(rail: Control, app: Control, national: bool) -> void:
	var dock := Control.new()
	dock.name = "ImmersiveSidebarDock"
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(dock)
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -C.px(Shell.RAIL_DOCK)
	D.line(dock, Vector2(27, 0), Vector2(Shell.RAIL_WIDTH - 27, 0), C.LINE)
	var actions := [["Carrière", "carriere", "Carrière"], ["Réglages", "reglages", "Réglages"], ["Sauvegarder", "sauver", ""]]
	var y := 11.0
	for i in actions.size():
		if i == 0 and national: continue
		var item: Array = actions[i]
		var route: String = item[2]
		var selected: bool = not route.is_empty() and app.route == route
		var button := Outils._shell_button("ImmersiveSidebarAction" + str(i), false, Charte.RAYON_PILULE)
		button.text = item[0]
		_rail_pill(button, selected)
		dock.add_child(button)
		var rect := _rail_pill_rect(y, Shell.RAIL_ROW_SMALL)
		D.place(button, rect)
		var left_margin := Shell.RAIL_LABEL
		var right_margin := 12.0
		var key_inset := 12.0
		if i == 2:
			# Texte et touche « Ctrl S » côte à côte : la marge gauche rentre (jusqu'au picto) si la place manque.
			right_margin = Outils._key_width("Ctrl S") + key_inset + 6.0
			var room := rect.size.x - right_margin - Outils._rw(C.DISPLAY, str(item[0]), 24) - 2.0
			if room < Shell.RAIL_LABEL:
				# Rail étroit (plancher de 12 px) : la touche se serre contre le bord, le texte vient jusqu'au picto.
				key_inset = 6.0
				right_margin = Outils._key_width("Ctrl S") + key_inset + 4.0
				room = rect.size.x - right_margin - Outils._rw(C.DISPLAY, str(item[0]), 24) - 4.0
			left_margin = clampf(room, Shell.RAIL_PAD + Shell.RAIL_ICON + 4.0, Shell.RAIL_LABEL)
		Outils._button_margins(button, left_margin, right_margin)
		Outils._picto(button, Rect2(Shell.RAIL_PAD, (rect.size.y - Shell.RAIL_ICON) / 2.0, Shell.RAIL_ICON, Shell.RAIL_ICON), item[1], Charte.PANNEAU if selected else C.MUTED)
		match i:
			0: button.pressed.connect(func(): app._navigate("Carrière"))
			1: button.pressed.connect(func(): app._navigate("Réglages"))
			2:
				button.pressed.connect(func(): Barre.save_now(app))
				button.tooltip_text = "Sauvegarder la carrière maintenant · Ctrl S"
				var key_width := Outils._key_width("Ctrl S")
				Outils._key(button, rect.size.x - key_inset - key_width, (rect.size.y - 27) / 2.0, "Ctrl S")
		if i == 0: button.tooltip_text = "Ta carrière de manager"
		if i == 1: button.tooltip_text = "Réglages : confort, son, affichage, raccourcis"
		y += Shell.RAIL_ROW_SMALL
	var line := Outils._shell_button("ImmersiveSaveLine", false, Charte.RAYON_PILULE)
	line.add_theme_font_size_override("font_size", Outils._fpx(19))
	dock.add_child(line)
	D.place(line, Rect2(Shell.RAIL_INSET, y + 6, Shell.RAIL_WIDTH - 2.0 * Shell.RAIL_INSET, 40))
	Outils._button_margins(line, Shell.RAIL_LABEL, 8)
	Outils._picto(line, Rect2(Shell.RAIL_PAD + 3, 10, 20, 20), "coche", Charte.V).name = "SaveLinePicto"
	line.pressed.connect(func(): Barre.save_now(app))
	Barre.refresh_save_line(app, line)
