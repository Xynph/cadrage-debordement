extends "res://ui/immersive08/competition_socle.gd"
## Compétitions, partie Classements : tri, tableau, menu de compétition, légende des zones, plaque de club et carte de colonne.
## Hérite du socle (competition_socle.gd) ; l'écran se lit par competition_canvas.gd.

## Les clubs d'une compétition, ordre de lecture du tableau (tri choisi par le joueur, rang par défaut).
func _sort_state() -> Dictionary:
	var value: Variant = app.management_ui.get("standings_sort")
	if value is Dictionary and str(value.get("key", "")) != "": return value
	return {"key": "rank", "desc": false}

func _trier(key: String) -> void:
	var current := _sort_state()
	var desc := not bool(current.get("desc", false)) if current.key == key else key not in ["rank", "name", "lost", "pa"]
	if current.key == key and key == "rank" and bool(current.get("desc", false)): desc = false
	app.management_ui.standings_sort = {"key": key, "desc": desc}
	app._render(false)

func _sort_value(club: Dictionary, key: String) -> Variant:
	match key:
		"rank": return int(club.get("rank", 0)) if P.standings_open(club) else 9999
		"name": return G.club_name(club).to_lower()
		"difference": return float(club.get("pf", 0)) - float(club.get("pa", 0))
	return float(club.get(key, 0))

func _sorted(rows: Array) -> Array:
	var sort := _sort_state()
	var key: String = sort.key
	var desc: bool = sort.desc
	var result := rows.duplicate()
	if key == "rank" and not desc: return result
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left: Variant = _sort_value(a, key)
		var right: Variant = _sort_value(b, key)
		if left == right: return int(a.get("rank", 0)) < int(b.get("rank", 0))
		return left > right if desc else left < right)
	return result

func _ordinal(value: int) -> String:
	return "%der" % value if value == 1 else "%de" % value

func _couleur_club(club: Dictionary) -> Color:
	var colors: Array = TenueClub.couleurs(club)
	return colors[0] if not colors.is_empty() else Charte.CLUB

func _own_row() -> Dictionary:
	for division: Dictionary in leagues:
		if str(division.id) != str(state.get("club_league", league.id)): continue
		for club: Dictionary in division.get("rows", []):
			if club.id == own.get("id"): return club
	return {}

func _own_league_rows() -> Array:
	for division: Dictionary in leagues:
		if str(division.id) == str(state.get("club_league", league.id)): return division.get("rows", [])
	return []

func _pool_index(pools: Array) -> int:
	var key := "standings_pool_" + str(league.id)
	var own_pool := pools.find_custom(func(pool: Dictionary):
		return pool.get("rows", []).any(func(club: Dictionary): return club.id == own.id))
	return clampi(int(app.management_ui.get(key, maxi(0, own_pool))), 0, pools.size() - 1)

func _pool_widget(panel: Control, pools: Array, selected: int, x: float, y: float) -> void:
	var key := "standings_pool_" + str(league.id)
	D.text(panel, x, y + 28, "PHASE DE POULES", 19, C.MUTED, 700, 220)
	var choice := OptionButton.new()
	choice.name = "StandingsPoolChoice"
	choice.add_theme_font_override("font", C.BOLD)
	choice.add_theme_font_size_override("font_size", maxi(12, C.px(21)))
	for pool: Dictionary in pools: choice.add_item(str(pool.get("label", "Poule")))
	choice.select(selected)
	choice.item_selected.connect(func(index: int):
		app.management_ui[key] = index
		var owner_app := app
		owner_app._render(false)
		U.focus(owner_app, "StandingsPoolChoice"))
	panel.add_child(choice)
	D.place(choice, Rect2(x + 230, y, 280, 40))

## Classement : tableau à gauche (colonnes triables, zones en liseré, symbole et mot), choix de la compétition en menu déroulant.
func _classement() -> void:
	var rows: Array = league.get("rows", []).duplicate()
	var pools: Array = league.get("pools", []) if international and league.get("pools") is Array else []
	var page_key := "standings_" + str(league.id)
	var selected_pool := -1
	var header_y := 84
	if not pools.is_empty():
		selected_pool = _pool_index(pools)
		rows = pools[selected_pool].get("rows", []).duplicate()
		page_key += "_poule_" + G.n(pools[selected_pool].id)
		header_y += 52
	rows = _sorted(rows)
	# Tout le classement sur la page, qui défile (décision de Léo) : plus de pagination.
	var capacity := maxi(1, rows.size())
	var paged := false
	var shown := mini(rows.size(), capacity)
	var rows_y := header_y + 40
	var zones: Array = league.get("zones", []) if international and league.get("zones") is Array else []
	var zone_note := str(league.get("zoneNote", "")) if international and league.get("zoneNote") is String else ""
	var has_champion: bool = league.get("champion") is Dictionary
	var footer := int(not zones.is_empty() or not zone_note.is_empty()) * 44 + int(has_champion) * 30 + (44 if paged else 0)
	var panel_h := rows_y + shown * ROW + 18 + footer + 18
	var panel := _panel(self, Rect2(0, TOP, LEFT, panel_h), "CLASSEMENT", "", "StandingsTableFrame")
	left_bottom = TOP + panel_h
	# Bandeau des filtres (demande de Léo du 21/11/2026) : titre, division, poules et en-têtes dans un bandeau détouré.
	Bandeau.poser(panel, Rect2(8, 4, LEFT - 16, rows_y - 6), 40.0)
	_division_menu(panel, 250, 12, 540)
	_result_legend(panel, LEFT - 24 - 450, 20)
	if not pools.is_empty(): _pool_widget(panel, pools, selected_pool, 24, 76)
	D.line(panel, Vector2(24, rows_y - 3), Vector2(LEFT - 24, rows_y - 3), Charte.FILET)
	_entete_tri(panel, Rect2(150, header_y, 440, 36), "CLUB", "name", HORIZONTAL_ALIGNMENT_LEFT)
	for column: Array in TABLE_COLUMNS:
		_entete_tri(panel, Rect2(column[1] - column[2] / 2.0, header_y, column[2], 36), column[0], column[3], HORIZONTAL_ALIGNMENT_CENTER)
	D.text(panel, 1290, header_y + 25, "FORME", 15, C.MUTED, 700, 190)
	var body := Control.new()
	body.name = "StandingsRows"
	panel.add_child(body)
	D.place(body, Rect2(0, rows_y, LEFT, shown * ROW))
	var bounds := _pager(panel, "StandingsPagination", page_key, rows.size(), capacity, rows_y + shown * ROW + 8, 24)
	for i in range(bounds.x, bounds.y):
		_ligne_classement(body, rows[i], i - bounds.x, ROW)
	if rows.is_empty(): D.text(body, 24, 40, "Aucun classement", 22, C.MUTED, 500, LEFT - 50, HORIZONTAL_ALIGNMENT_LEFT, true)
	var y := rows_y + shown * ROW + 18 + (44 if paged else 0)
	if not zones.is_empty() or not zone_note.is_empty():
		_zone_legend(panel, zones, 24, y, body, zone_note)
		y += 44
	if has_champion:
		var name_text := "Champion : " + G.club_name(league.champion)
		if league.get("finalist") is Dictionary: name_text += "   ·   Finaliste : " + G.club_name(league.finalist)
		var champion := D.text(panel, 24, y + 20, name_text, 20, C.IVORY, 700, LEFT - 48)
		champion.name = "StandingsChampion"

func _entete_tri(parent: Control, area: Rect2, caption: String, key: String, align: HorizontalAlignment) -> void:
	var active: bool = str(_sort_state().key) == key
	var button := Button.new()
	button.name = "StandingsSort_" + key
	button.text = caption
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("immersive_style_applied", true)
	C.style_bouton_lien(button, 16, true)
	button.alignment = align
	button.tooltip_text = "Trier par " + caption
	button.accessibility_name = "Trier par " + caption
	var colour := Charte.IVOIRE if active else Charte.IVOIRE_2
	for item in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: button.add_theme_color_override(item, colour)
	button.pressed.connect(func(): _trier(key))
	parent.add_child(button)
	D.place(button, area)
	if active:
		var desc: bool = bool(_sort_state().desc)
		var arrow := Polygon2D.new()
		arrow.name = "StandingsSortArrow"
		arrow.color = Charte.IVOIRE
		var shape := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(5, 7)]) if desc else PackedVector2Array([Vector2(0, 7), Vector2(10, 7), Vector2(5, 0)])
		for i in shape.size(): shape[i] *= C.density
		arrow.polygon = shape
		var arrow_x := area.end.x - 12 if align == HORIZONTAL_ALIGNMENT_CENTER else area.position.x + 64
		arrow.position = Vector2(arrow_x, area.position.y + 14) * C.density
		parent.add_child(arrow)

## Choix de la compétition : menu déroulant dans la page (mes compétitions, puis les autres).
func _division_menu(parent: Control, x: float, y: float, w: float) -> void:
	var own_league := str(state.get("club_league", ""))
	var main := Button.new()
	main.name = "StandingsDivisionMenu"
	main.text = _league_short(league) + ("   ·   ma compétition" if str(league.id) == own_league else "")
	main.focus_mode = Control.FOCUS_ALL
	main.alignment = HORIZONTAL_ALIGNMENT_LEFT
	main.clip_text = true
	main.set_meta("immersive_style_applied", true)
	main.tooltip_text = "Changer de compétition"
	for look in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.PANNEAU_3 if look != "hover" else Charte.PANNEAU_2
		style.set_corner_radius_all(Charte.RAYON_PILULE)
		style.border_color = Charte.IVOIRE if look in ["hover", "focus"] else Charte.FILET
		style.set_border_width_all(1 if look != "focus" else 2)
		style.content_margin_left = C.px(14)
		style.content_margin_right = C.px(40)
		style.content_margin_top = C.px(4)
		style.content_margin_bottom = C.px(4)
		main.add_theme_stylebox_override(look, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: main.add_theme_color_override(key, Charte.IVOIRE)
	main.add_theme_font_override("font", C.BOLD)
	main.add_theme_font_size_override("font_size", maxi(12, C.px(22)))
	parent.add_child(main)
	D.place(main, Rect2(x, y, w, 42))
	var arrow := Polygon2D.new()
	arrow.color = Charte.IVOIRE_2
	var shape := PackedVector2Array([Vector2(0, 0), Vector2(14, 0), Vector2(7, 9)])
	for i in shape.size(): shape[i] *= C.density
	arrow.polygon = shape
	arrow.position = Vector2(w - 30, 17) * C.density
	main.add_child(arrow)
	var menu := PanelContainer.new()
	menu.name = "StandingsDivisionList"
	menu.visible = false
	menu.z_index = 60
	var frame := StyleBoxFlat.new()
	frame.bg_color = Charte.PANNEAU_3
	frame.border_color = Charte.FILET
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(Charte.RAYON_CARTE)
	frame.content_margin_left = C.px(8)
	frame.content_margin_right = C.px(8)
	frame.content_margin_top = C.px(8)
	frame.content_margin_bottom = C.px(8)
	menu.add_theme_stylebox_override("panel", frame)
	var column := C.v(2)
	menu.add_child(column)
	parent.add_child(menu)
	D.place(menu, Rect2(x, y + 46, w, 0))
	menu.custom_minimum_size.x = C.px(w)
	var first_item: Button = null
	var groups := [["MES COMPÉTITIONS", leagues.filter(func(division: Dictionary): return str(division.id) == own_league)],
		["AUTRES COMPÉTITIONS", leagues.filter(func(division: Dictionary): return str(division.id) != own_league)]]
	for group: Array in groups:
		if group[1].is_empty(): continue
		var heading := C.label(group[0], 15, C.FAINT, true, 700)
		column.add_child(heading)
		for division: Dictionary in group[1]:
			var item := _item_menu(division, own_league)
			column.add_child(item)
			if first_item == null: first_item = item
	_menu_list = menu
	_menu_button = main
	main.pressed.connect(func():
		menu.visible = not menu.visible
		if menu.visible and first_item != null: first_item.grab_focus())

func _item_menu(division: Dictionary, own_league: String) -> Button:
	var item := Button.new()
	item.name = "StandingsDivision_" + str(division.id)
	var short := _league_short(division)
	item.text = short
	item.tooltip_text = str(division.get("name", short))
	item.focus_mode = Control.FOCUS_ALL
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.clip_text = true
	item.set_meta("immersive_style_applied", true)
	var selected: bool = division.id == league.id
	for look in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.PANNEAU_2 if look == "hover" else (Charte.PANNEAU_3 if not selected else Charte.PANNEAU)
		style.set_corner_radius_all(Charte.RAYON_PETIT)
		style.border_color = Charte.IVOIRE
		style.border_width_left = maxi(2, C.px(4)) if selected or look == "focus" else 0
		style.content_margin_left = C.px(14)
		style.content_margin_right = C.px(150)
		style.content_margin_top = C.px(5)
		style.content_margin_bottom = C.px(5)
		item.add_theme_stylebox_override(look, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: item.add_theme_color_override(key, Charte.IVOIRE)
	item.add_theme_font_override("font", C.BOLD if selected else Charte.texte_moyen())
	item.add_theme_font_size_override("font_size", maxi(12, C.px(20)))
	var detail := "%d clubs" % division.get("rows", []).size()
	if str(division.id) == own_league:
		var mine := _own_row()
		if not mine.is_empty() and P.standings_open(mine): detail = "%s · %s pts" % [_ordinal(int(mine.get("rank", 0))), S.number_text(mine.get("points"))]
	var side := C.label(detail, 17, C.MUTED, false, 500)
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	side.offset_right = -C.px(12)
	side.offset_left = -C.px(150)
	side.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.add_child(side)
	item.pressed.connect(func():
		app.table_division = division.id
		app.management_ui.erase("competition_page")
		var owner_app := app
		owner_app._render(false)
		U.focus(owner_app, "StandingsDivision_" + str(division.id)))
	return item

func _ligne_classement(parent: Node, club: Dictionary, index: int, stride: int) -> void:
	var mine: bool = club.id == own.id
	var rank := int(club.get("rank", 0)) if P.standings_open(club) else 0
	var zone := Color.TRANSPARENT
	# Monde : zone publiée par le moteur pour ce rang (règlement de la compétition), seulement une fois le classement ouvert.
	var zone_info: Dictionary = club.zone if international and rank > 0 and club.get("zone") is Dictionary else {}
	# Les zones viennent seulement des données Monde du moteur (règlement de la compétition) : jamais de règle figée.
	if international: zone = Zones.TINTS.get(str(zone_info.get("kind", "")), Color.TRANSPARENT)
	var row := Button.new()
	row.name = "StandingsRow_" + str(club.id)
	row.set_meta("club_id", club.id)
	var standing := (" · " + S.count_text(club.get("rank")) + " au classement" if P.standings_open(club) else " · pas encore classé")
	if not zone_info.is_empty():
		standing += " · " + str(zone_info.get("label", ""))
		row.set_meta("zone_kind", str(zone_info.get("kind", "")))
		row.set_meta("zone_label", str(zone_info.get("label", "")))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Charte.PANNEAU_3 if mine else Charte.PANNEAU
	normal.set_corner_radius_all(Charte.RAYON_PETIT)
	# Survol : bande + liseré club ; à droite de la bande de zone (places 1 à 6) quand la ligne en a une.
	var decal := (5.0 + 3.0) * C.density if zone.a > 0 else 0.0
	load("res://ui/survol_ligne.gd").appliquer(row, false, normal.bg_color, app.accent, Charte.RAYON_PETIT, decal)
	row.set_meta("immersive_style_applied", true)
	Link.bind(row, app, {"kind":"club", "id":str(club.id)}, "Ouvrir le club · " + G.club_name(club))
	# Après le lien (qui pose « Ouvrir · … ») : la place et la zone restent annoncées.
	row.accessibility_name += standing
	parent.add_child(row)
	D.place(row, Rect2(0, index * stride, LEFT, stride))
	if zone.a > 0:
		var edge := D.rect(row, Rect2(0, 1, 5, stride - 2), zone)
		edge.name = "StandingsZoneEdge"
	if not zone_info.is_empty():
		var side := Zones.mark_side()
		Zones.mark(row, str(zone_info.get("kind", "")), Rect2(36, (stride - side) / 2.0, side, side), zone)
	if mine:
		var height := float(stride - 12)
		var slant := height * tan(deg_to_rad(Charte.INCLINAISON_DEGRES))
		var marker := Polygon2D.new()
		marker.name = "StandingsOwnMarker"
		marker.color = Charte.IVOIRE
		var shape := PackedVector2Array([Vector2(slant, 0), Vector2(slant + 8, 0), Vector2(8, height), Vector2(0, height)])
		for i in shape.size(): shape[i] *= C.density
		marker.polygon = shape
		marker.position = Vector2(14, 6) * C.density
		row.add_child(marker)
		var underline := D.rect(row, Rect2(0, stride - 3, LEFT, 3), Charte.VERT_CLAIR)
		underline.name = "StandingsOwnTrait"
	var emblem := mini(26, stride - 4)
	_crest(row, club, Rect2(152, (stride - emblem) / 2.0, emblem, emblem))
	var baseline := stride / 2.0 + 7
	D.text(row, 192, baseline, G.club_name(club), 21, C.IVORY, 800 if mine else 600, 430)
	for column: Array in TABLE_COLUMNS:
		var key: String = column[3]
		var value := _standing_text(club, key)
		var tint: Color = C.IVORY if value != "—" else C.MUTED
		var caption := D.text(row, column[1], baseline, value, 21 if key in ["rank", "points"] else 19, tint, 800 if mine or key in ["rank", "points"] else 500, column[2], HORIZONTAL_ALIGNMENT_CENTER)
		if key in ["won", "drawn", "lost"]:
			caption.name = "StandingCount_" + key
			caption.set_meta("outcome_code", column[0])
	_recent_form(row, club.get("form"), 1292, (stride - 26) / 2.0)

func _standing_text(club: Dictionary, key: String) -> String:
	if key == "difference":
		var difference := S.difference_text(club.get("pf"), club.get("pa"))
		return "+" + difference if difference != "—" and int(difference) > 0 else difference
	if key == "rank" and not P.standings_open(club): return "–"
	if key == "points": return S.number_text(club.get(key))
	return S.count_text(club.get(key))

## Légende des zones : une rangée de pastilles courtes sous le tableau (« 1–2 Demi » : liseré, symbole dessiné, rangs et mot).
## Un clic sur une pastille met le focus sur la première ligne de la zone. La note du règlement est derrière un « i » en bout de rangée.
## Le nom lu porte le symbole Unicode du moteur et le libellé complet (« ★ 1–2 Demi-finale directe »).
func _zone_legend(parent: Node, zones: Array, x: float, top: float, body: Control, note: String) -> Control:
	var group := Control.new()
	group.name = "StandingsZoneLegend"
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(group)
	D.place(group, Rect2(x, top, LEFT - 2 * x, 34))
	var spoken: Array[String] = []
	var cursor := 0.0
	var side := Zones.mark_side()
	for i in zones.size():
		var zone: Dictionary = zones[i]
		var kind := str(zone.get("kind", ""))
		var word := Zones.span_text(zone) + " " + Zones.short_label(zone)
		var full := str(zone.get("symbol", "")) + " " + Zones.span_text(zone) + " " + str(zone.get("label", ""))
		spoken.append(full)
		var text_width: float = C.font(600).get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(19))).x / C.density
		var width := 16.0 + side + 8.0 + text_width + 16.0
		var pill := Button.new()
		pill.name = "StandingsZonePill_%d" % i
		pill.flat = true
		pill.focus_mode = Control.FOCUS_ALL
		pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pill.set_meta("zone_kind", kind)
		var look := StyleBoxFlat.new()
		look.bg_color = Charte.PANNEAU_3
		look.set_corner_radius_all(Charte.RAYON_PILULE)
		var hover := look.duplicate()
		hover.bg_color = Charte.PANNEAU_3.lerp(Charte.IVOIRE, .12)
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color(0, 0, 0, 0)
		focus.border_color = Charte.IVOIRE
		focus.set_border_width_all(maxi(2, C.px(2)))
		focus.set_corner_radius_all(Charte.RAYON_PILULE)
		pill.add_theme_stylebox_override("normal", look)
		pill.add_theme_stylebox_override("hover", hover)
		pill.add_theme_stylebox_override("pressed", hover)
		pill.add_theme_stylebox_override("focus", focus)
		pill.tooltip_text = "%s %s" % [Zones.span_text(zone), zone.get("label", "")]
		pill.accessibility_name = full
		pill.pressed.connect(_focus_zone.bind(body, int(zone.get("from", 1))))
		group.add_child(pill)
		D.place(pill, Rect2(cursor, 0, width, 34))
		var edge := D.rect(pill, Rect2(10, 8, 4, 18), Zones.tint(kind), 2)
		edge.name = "StandingsZoneLegendEdge_%d" % i
		var mark := Zones.mark(pill, kind, Rect2(20, 17 - side / 2.0, side, side), Zones.tint(kind))
		mark.name = "StandingsZoneLegendMark_" + kind
		var label := D.text(pill, 20.0 + side + 8.0, 24, word, 19, C.IVORY, 600)
		label.name = "StandingsZoneLegendItem_%d" % i
		label.set_meta("zone_kind", kind)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cursor += width + 8.0
	if not note.is_empty():
		var info := Pieces.info(group, cursor + 4.0, 4.0, note, "ZoneNote")
		info.name = "StandingsZoneNote"
	group.set_meta("legend_text", " · ".join(spoken))
	group.accessibility_name = "Zones du classement : " + " · ".join(spoken)
	group.tooltip_text = group.accessibility_name
	return group

## Pastille de zone : la ligne du classement au premier rang de la zone prend le focus (le défilement la suit).
func _focus_zone(body: Control, first_rank: int) -> void:
	var rows := body.get_children().filter(func(row: Node) -> bool: return row is Button)
	if first_rank >= 1 and first_rank <= rows.size(): (rows[first_rank - 1] as Button).grab_focus()

## Plaque inclinée aux couleurs d'un club (10°, rayon 0) : écusson, nom ; un clic ouvre la fiche du club.
class Plaque extends Button:
	var couleur := Color.WHITE
	var droite := false

	func _draw() -> void:
		# Charte finale : tuile arrondie avec ombre ; camps en vert clair (nous) et doré (adversaire), jamais la couleur du club.
		var style := StyleBoxFlat.new()
		style.bg_color = couleur
		style.set_corner_radius_all(Charte.RAYON_CARTE)
		style.anti_aliasing = true
		Charte.ombrer(style, Charte.RAYON_CARTE)
		if has_focus() or is_hovered():
			style.border_color = Charte.OR
			style.set_border_width_all(2)
		draw_style_box(style, Rect2(Vector2.ZERO, size))

func _plaque(parent: Node, area: Rect2, club: Dictionary, id: String, right: bool) -> Button:
	var plaque := Plaque.new()
	plaque.name = id
	plaque.flat = true
	plaque.set_meta("immersive_style_applied", true)
	var nous := str(club.get("id", "")) == str(app.model.get("club", {}).get("id", "-"))
	plaque.couleur = Charte.VOILE_VERT if nous else Charte.VOILE_DORE
	plaque.droite = right
	for look in ["normal", "hover", "pressed", "disabled", "focus"]: plaque.add_theme_stylebox_override(look, StyleBoxEmpty.new())
	parent.add_child(plaque)
	D.place(plaque, area)
	var ink := Charte.VERT_CLAIR if nous else Charte.DORE
	_crest(plaque, club, Rect2(22 if not right else 20, 8, 48, 48))
	var short_name := str(G.identity(club).get("shortName", ""))
	var plate_name := short_name if C.dense() and not short_name.is_empty() else G.club_name(club)
	# Le nom reste dans la plaque : une ligne qui se resserre ; en 1280, deux lignes qui montent depuis le bas de la plaque.
	var two_lines := C.dense()
	D.fit_title(D.text(plaque, 80, area.size.y - 10 if two_lines else area.size.y / 2.0 + 8, plate_name.to_upper(), 24, ink, 800, area.size.x - 100), area.size.x - 100, area.size.y - 12, 2 if two_lines else 1, 12)
	var target := {"kind":"club", "id":str(club.get("id", ""))}
	if target_available(app, "club", club.get("id", "")): Link.bind(plaque, app, target, "Ouvrir le club · " + G.club_name(club))
	else:
		plaque.focus_mode = Control.FOCUS_NONE
		plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return plaque

func _carte(parent: Node, area: Rect2, title: String, id: String) -> Panel:
	return _panel(parent, area, title, "", id)
