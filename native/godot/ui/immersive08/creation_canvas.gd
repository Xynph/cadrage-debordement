extends RefCounted
## Écran 02 · Création de carrière, étape « 1 Club » (DA du 19/11/2026, maquette « grille de cartes optimisée »).
## Plein écran hors coque : barre haute (logo, ← Accueil, fil « 1 Club › 2 Carrière », Identités et packs, Gabi),
## titre et recherche, pays puis championnats, panneau du club choisi à gauche (bandeau du stade, Niveau, Trésorerie,
## Joueurs, conseil, « Continuer avec … », mot du président, rivalités, Gabi), grille de cartes triables à droite.
## Toutes les valeurs viennent du catalogue de création (pack Rugby Réel compris) et de l'aperçu moteur du club
## (`club_preview` : président, rivalités) ; une donnée absente est omise, jamais inventée.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/carnet_skin.gd")
const GameSkin = preload("res://ui/game_skin.gd")
const Entry = preload("res://ui/entry_screens.gd")
const Club = preload("res://ui/club_views.gd")
const Packs = preload("res://ui/pack_views.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const Defis = preload("res://ui/creation_options/defis.gd")
const Kit = preload("res://ui/creation_options/kit.gd")
const President = preload("res://ui/creation_options/president_word.gd")
const PORTRAIT = preload("res://guide/coach_portrait.gd")
const TRI := "creation_tri"
const RECHERCHE := "creation_recherche"
const FORMAT := "creation_format_ouvert"
## Ambition du conseil, de la plus haute à la plus modeste (tri « Attente du conseil »).
const AMBITIONS := ["Jouer le titre", "Viser la montée", "Top 4", "Phases finales", "Top 6", "Top 8", "Maintien"]
const TRIS := [["niveau", "Niveau"], ["tresorerie", "Trésorerie"], ["conseil", "Attente du conseil"], ["saison", "Saison passée"]]
## Illustration du championnat (bandeau avant le choix d'un club).
const ART_DIVISION := {"nationale": "nationale-ground", "champ": "champ-ground", "prem": "champ-ground", "srp": "pacific-ground", "jlo-d1": "japan-ground", "jlo-d2": "japan-ground"}

## Barre inclinée de 10° (marqueur de sélection, soulignement d'onglet) : un Panel au StyleBoxFlat cisaillé.
static func _incline(color: Color, size: Vector2) -> Panel:
	var bar := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.skew = Vector2(tan(deg_to_rad(Charte.INCLINAISON_DEGRES)), 0)
	bar.add_theme_stylebox_override("panel", style)
	bar.custom_minimum_size = size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

## Fond de la charte §3 : `radius` 0 pour les bandeaux pleine largeur (barre haute, pied, fond d'écran) ;
## sinon Charte.RAYON_PANNEAU (panneau), RAYON_CARTE (carte), RAYON_PETIT (touche), RAYON_PILULE (bouton, champ).
static func _flat(color: Color = Color(0, 0, 0, 0), border: Color = Color(0, 0, 0, 0), padding: Vector2 = Vector2(8, 4), radius: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius if radius >= Charte.RAYON_PILULE else C.px(radius))
	style.anti_aliasing = true
	if border.a > 0:
		style.border_color = border
		style.set_border_width_all(1)
	style.content_margin_left = C.px(padding.x)
	style.content_margin_right = C.px(padding.x)
	style.content_margin_top = C.px(padding.y)
	style.content_margin_bottom = C.px(padding.y)
	return style

static func _surface(color: Color, padding: int = 0, radius: int = 0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_meta("immersive_style_applied", true)
	panel.add_theme_stylebox_override("panel", _flat(color, Color(0, 0, 0, 0), Vector2(padding, padding), radius))
	return panel

## Titre d'écran : Barlow Condensed ExtraBold italique, capitales (charte §7).
static func _titre(text: String, size: int) -> Label:
	var label := C.label(text.to_upper(), size, C.IVORY, true, 800)
	label.add_theme_font_override("font", Charte.TITRE_EXTRA)
	return label

## Étiquette en petites capitales (ivoire 2).
static func _etiquette(text: String, color: Color = C.MUTED) -> Label:
	return C.label(text.to_upper(), 16, color, true, 600)

## Texte courant DM Sans (13 px à 1920 = 17 unités).
static func _texte(text: String, color: Color = C.IVORY, size: int = 17) -> Label:
	return C.label(text, size, color, false)

static func _lien(text: String, callback: Callable, id: String, size: int = 17, souligne: bool = false) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	button.set_meta("immersive_style_applied", true)
	C.style_bouton_lien(button, size, souligne)
	button.add_theme_font_override("font", C.BODY)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	return button

static func _millions(value: float) -> String:
	return President.millions(value)

static func _niveau(club: Dictionary) -> float:
	var roster: Dictionary = club.get("startingRoster", {}) if club.get("startingRoster") is Dictionary else {}
	return float(roster.get("average", 0.0)) if roster.get("average") != null else 0.0

static func _joueurs(club: Dictionary) -> int:
	var roster: Dictionary = club.get("startingRoster", {}) if club.get("startingRoster") is Dictionary else {}
	return int(roster.get("forwards", 0)) + int(roster.get("backs", 0))

static func _ambition(club: Dictionary) -> int:
	var index := AMBITIONS.find(str(club.get("goal", "")))
	return index if index >= 0 else AMBITIONS.size()

## Saison passée (2025-2026) lue dans l'historique du club : {rang, texte} ou {} sans donnée.
static func _saison_passee(club: Dictionary) -> Dictionary:
	var history: Dictionary = club.get("history", {}) if club.get("history") is Dictionary else {}
	var best := {}
	for result: Variant in history.get("results", []):
		if not result is Dictionary or int(result.get("year", 0)) != 2026: continue
		var same := str(result.get("competition", "")) == str(club.get("division", ""))
		if int(result.get("titles", 0)) > 0 and same: return {"rang": 1, "texte": "champion l’an passé", "court": "champion"}
		var rank := int(result.get("rank", 0))
		if rank > 0 and same and (best.is_empty() or rank < int(best.rang)):
			best = {"rang": rank, "texte": "%s l’an passé" % _ordinal(rank), "court": _ordinal(rank)}
	return best

static func _ordinal(rank: int) -> String:
	return "1er" if rank == 1 else "%de" % rank

## Rang (1 = meilleur) d'un club dans sa division selon une mesure.
static func _rang(clubs: Array, club: Dictionary, measure: Callable) -> int:
	var own: float = measure.call(club)
	return 1 + clubs.filter(func(other: Dictionary): return float(measure.call(other)) > own).size()

static func _trier(clubs: Array, key: String) -> Array:
	var sorted := clubs.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		match key:
			"tresorerie":
				if float(a.get("cashMillions", 0)) != float(b.get("cashMillions", 0)): return float(a.get("cashMillions", 0)) > float(b.get("cashMillions", 0))
			"conseil":
				if _ambition(a) != _ambition(b): return _ambition(a) < _ambition(b)
				if _niveau(a) != _niveau(b): return _niveau(a) > _niveau(b)
			"saison":
				var left := int(_saison_passee(a).get("rang", 999))
				var right := int(_saison_passee(b).get("rang", 999))
				if left != right: return left < right
				if _niveau(a) != _niveau(b): return _niveau(a) > _niveau(b)
			_:
				if _niveau(a) != _niveau(b): return _niveau(a) > _niveau(b)
		return G.club_name(a) < G.club_name(b))
	return sorted

## Recherche insensible à la casse et aux accents.
static func normaliser(text: String) -> String:
	var plain := text.to_lower()
	for pair in [["àâä", "a"], ["éèêë", "e"], ["îï", "i"], ["ôö", "o"], ["ùûü", "u"], ["ç", "c"], ["’'-", " "]]:
		for letter in pair[0]: plain = plain.replace(letter, pair[1])
	return plain.strip_edges()

static func _competition_name(app: Control, division: String) -> String:
	return str(Entry._competition_identity(app, division).get("name", Club.competition_name(division)))

# ---------------------------------------------------------------------------------------------------------------
# Page

## Construit la page de l'étape Club ; `ctx` vient de entry_screens.creation (catalogue, pays, division, club choisi).
static func build(app: Control, ctx: Dictionary) -> Control:
	var screen: Vector2i = app.get_window().size
	C.configure(screen.y, screen.x)
	var page := C.v(0)
	page.name = "CarnetCreation"
	page.set_meta("creation_club_step", true)
	page.set_meta("creation_ctx", ctx)
	G.fill(page, true)
	page.theme = Legacy.theme(C.IVORY)
	Packs.missing_warning(app, page, "creation")
	var selected: Dictionary = ctx.selected
	var division: String = ctx.division
	var division_clubs: Array = ctx.division_clubs
	if not selected.is_empty(): Kit.request_preview(app, int(selected.id))
	# Titre, sous-titre et recherche.
	var head := C.h(16)
	page.add_child(head)
	var titles := C.h(14)
	titles.alignment = BoxContainer.ALIGNMENT_BEGIN
	head.add_child(C.fill(titles))
	var title := _titre("Choisir son club", 37)
	title.name = "CreationTitle"
	titles.add_child(title)
	var season := Entry.creation_season(app, division)
	var subtitle := _texte("%s · %d clubs" % [_competition_name(app, division), division_clubs.size()] + (" · saison " + season if not season.is_empty() else ""), C.MUTED)
	subtitle.name = "CreationSubtitle"
	subtitle.size_flags_vertical = Control.SIZE_SHRINK_END
	titles.add_child(subtitle)
	head.add_child(_recherche(app))
	var gap := Control.new()
	gap.custom_minimum_size.y = C.px(10)
	page.add_child(gap)
	_onglets_pays(app, page, ctx)
	page.add_child(C.rule())
	_onglets_championnats(app, page, ctx)
	page.add_child(C.rule())
	# Défis de départ (carrière Monde, rôle club) : une ligne de liens sous les championnats.
	if ctx.mode == "world-champ":
		var defis := C.margin(0)
		defis.add_theme_constant_override("margin_top", C.px(8))
		page.add_child(defis)
		Defis.build(app, defis, ctx.playable, true)
		if defis.get_child_count() == 0: defis.queue_free()
	var spacer := Control.new()
	spacer.custom_minimum_size.y = C.px(20)
	page.add_child(spacer)
	var row := C.h(32)
	row.name = "CreationMainRow"
	C.fill(row, true)
	page.add_child(row)
	_dossier(app, row, ctx, screen)
	_grille(app, row, ctx, screen)
	return page

static func _recherche(app: Control) -> Control:
	var frame := _surface(Charte.PANNEAU_3, 0, Charte.RAYON_PILULE)
	frame.name = "CreationSearchBox"
	(frame.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Charte.IVOIRE_3
	(frame.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(1)
	(frame.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = C.px(12)
	(frame.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = C.px(8)
	frame.custom_minimum_size = Vector2(C.px(453), C.px(43))
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var line := C.h(8)
	frame.add_child(line)
	var loupe := C.icon("search", 18, C.MUTED)
	loupe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(loupe)
	var field := LineEdit.new()
	field.name = "CreationSearch"
	field.placeholder_text = "Rechercher un club…"
	field.text = str(app.management_ui.get(RECHERCHE, ""))
	field.clear_button_enabled = true
	field.add_theme_font_override("font", C.BODY)
	field.add_theme_font_size_override("font_size", C.font_px(17))
	for state in ["normal", "focus", "read_only"]:
		field.add_theme_stylebox_override(state, _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), Vector2(2, 2)))
	field.add_theme_color_override("font_color", C.IVORY)
	field.add_theme_color_override("font_placeholder_color", C.MUTED)
	field.accessibility_name = "Rechercher un club (Ctrl F)"
	line.add_child(C.fill(field))
	var key := _touche("Ctrl F")
	line.add_child(key)
	# Ctrl F / Ctrl K donnent le focus à la recherche.
	var catcher := RaccourciRecherche.new()
	catcher.field = field
	line.add_child(catcher)
	field.text_changed.connect(func(text: String) -> void:
		app.management_ui[RECHERCHE] = text
		_filtrer(app))
	return frame

class RaccourciRecherche extends Control:
	var field: LineEdit
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2.ZERO
	func _shortcut_input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key == null or not key.pressed or key.echo or not key.is_command_or_control_pressed(): return
		if key.keycode in [KEY_F, KEY_K] and is_instance_valid(field) and field.is_visible_in_tree():
			field.grab_focus()
			field.select_all()
			get_viewport().set_input_as_handled()

static func _touche(text: String) -> PanelContainer:
	var chip := _surface(Charte.PANNEAU_2, 4, Charte.RAYON_PETIT)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(C.label(text, 16, C.MUTED, false))
	return chip

## Filtre en place la grille (le champ garde son focus) ; état vide avec « Effacer la recherche ».
static func _filtrer(app: Control) -> void:
	var grid := app.find_child("CreationClubGrid", true, false) as GridContainer
	if grid == null: return
	var query := normaliser(str(app.management_ui.get(RECHERCHE, "")))
	var shown := 0
	for card: Control in grid.get_children():
		var visible := query.is_empty() or normaliser(str(card.get_meta("recherche", ""))).contains(query)
		card.visible = visible
		if visible: shown += 1
	var empty := app.find_child("CreationSearchEmpty", true, false) as Control
	if empty != null: empty.visible = shown == 0

static func _onglet(caption: String, active: bool, callback: Callable, id: String, size: int, icon: Texture2D = null) -> VBoxContainer:
	var group := C.v(0)
	var tab := Button.new()
	tab.name = id
	tab.text = caption
	tab.icon = icon
	tab.set_meta("immersive_style_applied", true)
	tab.focus_mode = Control.FOCUS_ALL
	tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tab.add_theme_font_override("font", C.BODY)
	tab.add_theme_font_size_override("font_size", C.font_px(size))
	tab.add_theme_constant_override("h_separation", C.px(8))
	tab.add_theme_constant_override("icon_max_width", C.px(24))
	tab.toggle_mode = true
	tab.button_pressed = active
	tab.accessibility_description = "Sélectionné" if active else ""
	# Onglet de la charte §7.1 : pilule ; actif = aplat crème, texte `PANNEAU` ; survol `PANNEAU_2` ; focus = anneau crème (comme le reste de l'écran).
	for look in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		var fond: Color = C.IVORY if active else (Charte.PANNEAU_2 if look in ["hover", "hover_pressed"] else Color(0, 0, 0, 0))
		var style := _flat(fond, Color(0, 0, 0, 0), Vector2(14, 7), Charte.RAYON_PILULE)
		if look == "focus":
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = C.IVORY
			style.set_border_width_all(2)
			style.set_expand_margin_all(2)
		tab.add_theme_stylebox_override(look, style)
	var encre: Color = Charte.PANNEAU if active else C.MUTED
	for key in ["font_color", "font_focus_color", "font_disabled_color"]: tab.add_theme_color_override(key, encre)
	for key in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]: tab.add_theme_color_override(key, Charte.PANNEAU if active else C.IVORY)
	for key in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]: tab.add_theme_color_override(key, Color.WHITE)
	tab.pressed.connect(callback)
	group.add_child(tab)
	# Repère gardé pour l'accessibilité et les tests, invisible : l'aplat crème de la pilule dit l'onglet actif.
	var underline := _incline(Color(0, 0, 0, 0), Vector2(0, maxi(2, C.px(4))))
	underline.name = id + "Marker"
	group.add_child(underline)
	return group

static func _onglets_pays(app: Control, page: Control, ctx: Dictionary) -> void:
	var countries: Dictionary = ctx.countries
	if countries.size() <= 1: return
	var tabs := C.h(32)
	tabs.name = "CreationCountries"
	page.add_child(tabs)
	var groups := countries.keys()
	groups.sort()
	for group: String in groups:
		var members: Array = countries[group]
		var info: Array = Entry.CREATION_COUNTRIES.get(group, [group, null])
		var flag: Texture2D = info[1]
		if group == "international": flag = C.icon_texture("globe", C.IVORY)
		var active: bool = ctx.country == group
		var tab := _onglet(info[0], active, func():
			if ctx.country == group: return
			var first_division := str(members[0].division)
			Entry._division(app, first_division, members.filter(func(club: Dictionary): return club.division == first_division), ctx.mode), "CreationCountry_" + group, 19, flag)
		(tab.get_child(0) as Button).disabled = app.waiting and app.last_command == "new_career"
		tabs.add_child(tab)
		if active:
			var connector := Control.new()
			connector.name = "CreationCountryConnector"
			connector.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tab.add_child(connector)

static func _onglets_championnats(app: Control, page: Control, ctx: Dictionary) -> void:
	var leagues := HFlowContainer.new()
	leagues.name = "CreationDivisions"
	leagues.add_theme_constant_override("h_separation", C.px(32))
	page.add_child(leagues)
	for item: Array in ctx.divisions_data:
		var members: Array = (ctx.clubs as Array).filter(func(club: Dictionary): return club.division == item[0])
		if members.is_empty(): continue
		var identity := Entry._competition_identity(app, item[0])
		var name := str(identity.get("shortName", identity.get("name", item[1])))
		var icon: Texture2D = GameSkin._pack_texture(str(identity.get("logoPath", "")))
		var tab := _onglet("%s · %d" % [name, members.size()], app.club_division == item[0], func(): Entry._division(app, item[0], members, ctx.mode), "CreationDivision_" + item[0], 17, icon)
		(tab.get_child(0) as Button).disabled = app.waiting and app.last_command == "new_career"
		(tab.get_child(0) as Button).tooltip_text = str(identity.get("name", name))
		leagues.add_child(tab)

# ---------------------------------------------------------------------------------------------------------------
# Panneau de gauche : le championnat, puis le club choisi

static func _dossier(app: Control, row: HBoxContainer, ctx: Dictionary, screen: Vector2i) -> void:
	var frame := _surface(C.PANEL, 0, Charte.RAYON_PANNEAU)
	frame.name = "CreationDossierFrame"
	frame.custom_minimum_size.x = roundf(screen.x * .2375)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(frame)
	var column := C.v(0)
	column.name = "CreationDossier"
	frame.add_child(column)
	var selected: Dictionary = ctx.selected
	_bandeau(app, column, ctx, screen)
	var body := C.margin(0)
	for edge in ["left", "right"]: body.add_theme_constant_override("margin_" + edge, C.px(32))
	body.add_theme_constant_override("margin_top", C.px(18))
	body.add_theme_constant_override("margin_bottom", C.px(16))
	C.fill(body, true)
	column.add_child(body)
	var content := C.v(10)
	body.add_child(content)
	if selected.is_empty(): _resume_championnat(app, content, ctx)
	else: _chiffres_club(app, content, ctx)
	_bouton_suivant(app, content, ctx)
	# Bas du panneau défilant à petite taille (mot du président, rivalités, Gabi) : rien n'est jamais coupé.
	var lower := ScrollContainer.new()
	lower.name = "CreationDossierMore"
	lower.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lower.follow_focus = true
	C.fill(lower, true)
	content.add_child(lower)
	var more := C.v(12)
	C.fill(more, true)
	lower.add_child(more)
	if not selected.is_empty():
		if bool(app.management_ui.get(FORMAT, false)): _format(app, more, str(ctx.division), true)
		else: _president_et_rivaux(app, more, ctx)
		var spring := Control.new()
		spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		C.fill(spring, true)
		more.add_child(spring)
		if not Entry.creation_format(app, str(ctx.division)).is_empty():
			var open := bool(app.management_ui.get(FORMAT, false))
			var link := _lien("← Revenir au club" if open else "Format de la division et enjeux →", func():
				app.management_ui[FORMAT] = not bool(app.management_ui.get(FORMAT, false))
				app._render(), "CreationFormatLink", 17, true)
			link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			more.add_child(link)
	else:
		var spring := Control.new()
		spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		C.fill(spring, true)
		more.add_child(spring)
	more.add_child(C.rule())
	_gabi(app, more, ctx)

static func _bandeau(app: Control, column: VBoxContainer, ctx: Dictionary, screen: Vector2i) -> void:
	var selected: Dictionary = ctx.selected
	var banner := Control.new()
	banner.name = "CreationBanner"
	banner.clip_contents = true
	banner.custom_minimum_size.y = clampf(screen.y * .148, 96, 213)
	column.add_child(banner)
	var picture: Control
	if selected.is_empty():
		picture = C.photo(str(ART_DIVISION.get(str(ctx.division), "entry-ground")), Vector2.ZERO, true, .55)
	else:
		picture = G.club_picture(selected, "stadium", false)
		picture.name = "CreationStadium"
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Voile uni (charte : ni dégradé ni ombre) pour la lisibilité du nom.
	var veil := ColorRect.new()
	veil.color = Color(Charte.NUIT, .58)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := C.margin(0)
	inset.add_theme_constant_override("margin_left", C.px(32))
	inset.add_theme_constant_override("margin_right", C.px(24))
	inset.add_theme_constant_override("margin_bottom", C.px(22))
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(inset)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var line := C.h(20)
	line.alignment = BoxContainer.ALIGNMENT_BEGIN
	line.size_flags_vertical = Control.SIZE_SHRINK_END
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(line)
	var names := C.v(0)
	names.alignment = BoxContainer.ALIGNMENT_END
	if selected.is_empty():
		var identity := Entry._competition_identity(app, str(ctx.division))
		var logo := str(identity.get("logoPath", ""))
		if not logo.is_empty():
			var badge := G.crest({"logoPath": logo, "name": str(identity.get("name", ""))}, C.px(64))
			badge.size_flags_vertical = Control.SIZE_SHRINK_END
			line.add_child(badge)
		line.add_child(C.fill(names))
		var country := str(Entry.CREATION_COUNTRIES.get(ctx.country, [ctx.country, null])[0])
		names.add_child(_etiquette("Championnat · " + country, C.IVORY))
		var heading := _titre(_competition_name(app, str(ctx.division)), 46)
		heading.name = "CreationCompetitionSummary"
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		names.add_child(heading)
	else:
		var crest := Entry._creation_crest(selected, C.px(72), ctx.preferred == "base")
		crest.tooltip_text = ""
		crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crest.size_flags_vertical = Control.SIZE_SHRINK_END
		line.add_child(crest)
		line.add_child(C.fill(names))
		var venue := str(selected.get("stadium", "")).strip_edges()
		names.add_child(_etiquette("Ton choix" + (" · " + venue if not venue.is_empty() else ""), C.IVORY))
		var name := _titre(G.club_name(selected), 50)
		name.name = "CreationClubTitle"
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.max_lines_visible = 2
		names.add_child(name)

## Avant le choix : le championnat (clubs, saison, format et enjeux).
static func _resume_championnat(app: Control, content: VBoxContainer, ctx: Dictionary) -> void:
	var facts := C.h(0)
	content.add_child(facts)
	_chiffre(facts, "Clubs", str((ctx.division_clubs as Array).size()), "dans le championnat")
	var season := Entry.creation_season(app, str(ctx.division))
	# « 2026-2027 » s'écrit « 2026-27 » dans ce chiffre clé (maquette).
	if season.length() == 9 and season[4] == "-": season = season.substr(0, 5) + season.substr(7)
	if not season.is_empty(): _chiffre(facts, "Saison", season, "de départ")
	content.add_child(C.rule())
	_format(app, content, str(ctx.division), false)
	var hint := C.wrap("Choisis un club dans la grille pour découvrir son stade, ses moyens et ce que le conseil attend de toi.", 17, C.MUTED)
	content.add_child(hint)

static func _format(app: Control, parent: Container, division: String, heading: bool) -> void:
	var format: Array = Entry.creation_format(app, division)
	if format.is_empty(): return
	var block := C.v(4)
	block.name = "CreationFormat"
	parent.add_child(block)
	block.add_child(_etiquette("Format et enjeux" if not heading else "Format de la division et enjeux"))
	for detail: String in format: block.add_child(C.wrap(detail, 17, C.IVORY))

static func _chiffre(parent: HBoxContainer, caption: String, value: String, detail: String, id: String = "") -> VBoxContainer:
	var column := C.v(0)
	if not id.is_empty(): column.name = id
	parent.add_child(C.fill(column))
	column.add_child(_etiquette(caption))
	var figure := C.label(value, 37, C.IVORY, true, 800)
	figure.name = "Valeur"
	column.add_child(figure)
	if not detail.is_empty(): column.add_child(C.wrap(detail, 17, C.MUTED))
	return column

## Après le choix : Niveau, Trésorerie, Joueurs avec leur rang, puis conseil, saison passée et stade.
static func _chiffres_club(app: Control, content: VBoxContainer, ctx: Dictionary) -> void:
	var selected: Dictionary = ctx.selected
	var clubs: Array = ctx.division_clubs
	var total := clubs.size()
	var facts := C.h(0)
	content.add_child(facts)
	if _niveau(selected) > 0:
		var level := _chiffre(facts, "Niveau", Entry._rating(selected.get("startingRoster", {})), "%s sur %d" % [_ordinal(_rang(clubs, selected, _niveau)), total], "CreationRosterSummary")
		level.tooltip_text = "Note moyenne de l’effectif de départ · clic : trier la grille par niveau"
		_trier_au_clic(app, level, "niveau")
	if selected.has("cashMillions"):
		var cash := _chiffre(facts, "Trésorerie", _millions(float(selected.cashMillions)), "%s sur %d" % [_ordinal(_rang(clubs, selected, func(c: Dictionary): return float(c.get("cashMillions", 0)))), total], "CreationCash")
		cash.tooltip_text = "Trésorerie de départ · %s · clic : trier la grille par trésorerie" % G.euros(roundi(float(selected.cashMillions) * 1_000_000))
		_trier_au_clic(app, cash, "tresorerie")
	var roster: Dictionary = selected.get("startingRoster", {}) if selected.get("startingRoster") is Dictionary else {}
	if _joueurs(selected) > 0:
		_chiffre(facts, "Joueurs", str(_joueurs(selected)), "%d avants, %d arrières" % [int(roster.get("forwards", 0)), int(roster.get("backs", 0))], "CreationPlayers")
	content.add_child(C.rule())
	var table := GridContainer.new()
	table.name = "CreationClubFacts"
	table.columns = 2
	table.add_theme_constant_override("h_separation", C.px(18))
	table.add_theme_constant_override("v_separation", C.px(5))
	content.add_child(table)
	var defi := Defis.choix(app, int(selected.id))
	var goal := str(defi.objectif) if not defi.is_empty() else str(selected.get("goal", "")).strip_edges()
	if not goal.is_empty(): _ligne(table, "Conseil", goal + (" (défi)" if not defi.is_empty() else ""))
	var last := _saison_passee(selected)
	if not last.is_empty(): _ligne(table, "Saison passée", "%s · %s" % ["Champion" if last.court == "champion" else str(last.court),_competition_name(app, str(selected.get("division", "")))])
	var history: Dictionary = selected.get("history", {}) if selected.get("history") is Dictionary else {}
	if history.has("founded"): _ligne(table, "Fondé en", str(int(history.founded)))
	var city := Entry._territory(selected)
	if not city.is_empty(): _ligne(table, "Ville", city)

## Un chiffre du panneau trie la grille selon sa mesure (un chiffre ne reste jamais sans effet).
static func _trier_au_clic(app: Control, figure: Control, key: String) -> void:
	figure.mouse_filter = Control.MOUSE_FILTER_STOP
	figure.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	figure.set_meta("tri", key)
	figure.gui_input.connect(func(event: InputEvent) -> void:
		var mouse := event as InputEventMouseButton
		if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT: return
		figure.accept_event()
		app.management_ui[TRI] = key
		app._render())

static func _ligne(table: GridContainer, caption: String, value: String) -> void:
	var key := _etiquette(caption)
	key.custom_minimum_size.x = C.px(176)
	table.add_child(key)
	var text := C.wrap(value, 17, C.IVORY)
	C.fill(text)
	table.add_child(text)

## Action principale de l'étape : or (seule exception hors coque), bord droit incliné, raison écrite si inactive.
static func _bouton_suivant(app: Control, content: VBoxContainer, ctx: Dictionary) -> void:
	var selected: Dictionary = ctx.selected
	var can_start: bool = not selected.is_empty() and (ctx.role == "club" or not (ctx.nation as Dictionary).is_empty())
	var reason := ""
	if ctx.unavailable: reason = "Pack indisponible : choisis-le dans Identités et packs"
	elif selected.is_empty(): reason = "Choisis un club dans la grille"
	var caption := "Continuer avec " + G.club_name(selected) if reason.is_empty() else reason
	var start := Button.new()
	start.name = "CreationNext"
	start.text = caption.to_upper() if reason.is_empty() else caption
	start.set_meta("immersive_style_applied", true)
	start.focus_mode = Control.FOCUS_ALL
	start.alignment = HORIZONTAL_ALIGNMENT_LEFT
	start.clip_text = true
	start.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	start.tooltip_text = caption
	start.custom_minimum_size.y = C.px(59)
	var busy: bool = app.waiting and app.last_command not in ["club_preview", "start_challenges"]
	start.disabled = busy or ctx.unavailable or not can_start
	var skew := Vector2(-tan(deg_to_rad(Charte.INCLINAISON_DEGRES)), 0)
	# Raccourci « Entrée » écrit dans le bouton dès 1600 px de large (à 1280, le nom du club garde toute la place).
	var wide: bool = app.get_window().size.x >= 1600 and reason.is_empty()
	for look in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := _flat(C.OR if look != "hover" and look != "disabled" else (C.OR_VIF if look == "hover" else Charte.PANNEAU_3), Color(0, 0, 0, 0), Vector2(24, 6), Charte.RAYON_PILULE)
		style.content_margin_right = C.px(110 if wide else 24)
		if look != "disabled": style.skew = skew
		if look == "focus":
			style.border_color = C.IVORY
			style.set_border_width_all(2)
		start.add_theme_stylebox_override(look, style)
	start.add_theme_font_override("font", Charte.TITRE_EXTRA if reason.is_empty() else C.BODY)
	start.add_theme_font_size_override("font_size", C.font_px(23 if reason.is_empty() else 17))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: start.add_theme_color_override(key, Charte.NUIT)
	start.add_theme_color_override("font_disabled_color", C.MUTED)
	if wide and not start.disabled:
		var hint := C.label("Entrée", 16, Charte.NUIT, false)
		hint.name = "CreationNextKey"
		start.add_child(hint)
		hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE)
		hint.offset_left -= C.px(30)
		hint.offset_right -= C.px(30)
	start.pressed.connect(func(): suivant(app, ctx))
	content.add_child(start)

static func suivant(app: Control, ctx: Dictionary) -> void:
	var selected: Dictionary = ctx.selected
	if selected.is_empty() or ctx.unavailable: return
	if ctx.role != "club" and (ctx.nation as Dictionary).is_empty(): return
	app.management_ui[Entry.CREATION_STEP] = "carriere"
	app._render()

static func _president_et_rivaux(app: Control, more: VBoxContainer, ctx: Dictionary) -> void:
	var selected: Dictionary = ctx.selected
	var data := Kit.preview(app, int(selected.id))
	var state := Kit.preview_state(app, int(selected.id))
	var word := C.v(4)
	word.name = "CreationPresidentWordShort"
	more.add_child(word)
	var president: Variant = data.get("president")
	var who := str((president as Dictionary).get("name", "")).strip_edges() if president is Dictionary else ""
	word.add_child(_etiquette("Ton choix · le mot du président"))
	var quote := C.wrap("« %s »" % President.welcome_text(selected), 17, C.IVORY)
	quote.name = "CreationPresidentQuote"
	quote.max_lines_visible = 5
	word.add_child(quote)
	if not who.is_empty(): word.add_child(_texte(who + ", président du conseil", C.MUTED))
	var rivals: Array = data.get("rivals", []) if data.get("rivals") is Array else []
	var block := C.v(4)
	block.name = "CreationRivalsShort"
	more.add_child(block)
	block.add_child(_etiquette("Rivalités"))
	if rivals.is_empty():
		block.add_child(_texte("Recherche des rivalités…" if state == "pending" else "Aucune rivalité déclarée pour ce club.", C.MUTED))
		return
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", C.px(4))
	block.add_child(flow)
	for rival: Variant in rivals.slice(0, 4):
		if not rival is Dictionary: continue
		var id := int(rival.get("id", -1))
		var other := Kit.club_by_id(app, id)
		var name := Kit.club_name(app, id, str(rival.get("name", "")))
		var playable: bool = not other.is_empty() and other.get("playable", true)
		if playable:
			# Un rival se choisit d'un clic (sa division s'ouvre, il devient le club choisi).
			var link := _lien(name, func(): _choisir_ailleurs(app, other), "CreationRivalLink_%d" % id, 17, true)
			link.tooltip_text = "Choisir %s" % name
			flow.add_child(link)
		else:
			flow.add_child(_texte(name, C.MUTED))

## Choisit un club d'une autre division (rival, défi) : pays et championnat suivent.
static func _choisir_ailleurs(app: Control, club: Dictionary) -> void:
	app.club_division = str(club.get("division", app.club_division))
	app.management_ui[Entry.CREATION_SELECTION] = int(club.id)
	app.selected_club = int(club.id)
	app.management_ui.erase(FORMAT)
	app._render()

static func _gabi(app: Control, more: VBoxContainer, ctx: Dictionary) -> void:
	var row := C.h(16)
	row.name = "CreationGabiAdvice"
	more.add_child(row)
	var medal := Medaillon.new()
	medal.custom_minimum_size = Vector2(C.px(96), C.px(96))
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(medal)
	var face := PORTRAIT.new() as TextureRect
	medal.disc.add_child(face)
	face.set_context("territoire")
	var copy := C.v(2)
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(C.fill(copy))
	copy.add_child(_etiquette("Gabi · quel club choisir ?"))
	var advice := C.wrap("« %s »" % conseil_gabi(ctx), 17, C.IVORY)
	advice.name = "CreationGabiAdviceText"
	copy.add_child(advice)

## Conseil de Gabi tiré du rang réel du club choisi dans sa division (niveau et trésorerie).
static func conseil_gabi(ctx: Dictionary) -> String:
	var selected: Dictionary = ctx.selected
	var clubs: Array = ctx.division_clubs
	if selected.is_empty(): return "Prends un club du milieu : assez d’argent pour corriger tes erreurs, assez d’attente pour vibrer."
	var total := maxi(1, clubs.size())
	var level := _rang(clubs, selected, _niveau)
	var cash := _rang(clubs, selected, func(c: Dictionary): return float(c.get("cashMillions", 0)))
	if level <= ceili(total / 3.0) and cash <= ceili(total / 3.0): return "Un favori : les moyens sont là, le conseil attendra des résultats tout de suite."
	if level <= ceili(total / 3.0): return "Un bon effectif mais une caisse plus courte : chaque recrue devra compter."
	if level > total - ceili(total / 3.0) and cash > total - ceili(total / 3.0): return "Un petit poucet : chaque victoire comptera double, et le maintien sera déjà une fête."
	if cash <= ceili(total / 3.0): return "De l’argent pour bâtir : l’effectif est à faire grandir, le conseil te laisse le temps."
	return "Un club du milieu : assez d’argent pour corriger tes erreurs, assez d’attente pour vibrer."

## Portrait de Gabi dans un disque cerclé d'ivoire (sans ombre : charte §3).
class Medaillon extends Control:
	var disc := Control.new()
	func _init() -> void:
		disc.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.draw.connect(func() -> void: disc.draw_circle(disc.size / 2.0, minf(disc.size.x, disc.size.y) / 2.0, Color.WHITE))
		add_child(disc)
		resized.connect(_fit)
	func _fit() -> void:
		var gap := maxf(2.0, size.x * .05)
		disc.position = Vector2(gap, gap)
		disc.size = size - Vector2(gap, gap) * 2.0
		disc.queue_redraw()
		if disc.get_child_count() > 0:
			var face := disc.get_child(0) as Control
			var zoomed := disc.size * 1.45
			face.size = zoomed
			face.position = disc.size / 2.0 - Vector2(.52, .42) * zoomed
		queue_redraw()
	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0
		draw_circle(center, radius, Charte.PANNEAU_3)
		draw_arc(center, radius - 1.0, 0, TAU, 64, Charte.IVOIRE, 1.5, true)

# ---------------------------------------------------------------------------------------------------------------
# Grille de cartes

static func _grille(app: Control, row: HBoxContainer, ctx: Dictionary, screen: Vector2i) -> void:
	var column := C.v(10)
	C.fill(column, true)
	row.add_child(column)
	var selected: Dictionary = ctx.selected
	var info := C.h(8)
	info.name = "CreationGridHead"
	column.add_child(info)
	var count := C.h(0)
	count.add_child(_texte("%d clubs" % (ctx.division_clubs as Array).size(), C.MUTED))
	if not selected.is_empty():
		count.add_child(_texte(" · ", C.MUTED))
		var chosen := C.label(G.club_name(selected), 17, C.IVORY, false, 700)
		chosen.add_theme_font_override("font", Charte.texte_moyen())
		count.add_child(chosen)
		count.add_child(_texte(" choisi", C.MUTED))
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(C.fill(count))
	var sort_key := str(app.management_ui.get(TRI, "niveau"))
	var trier := _etiquette("Trier")
	trier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(trier)
	for item: Array in TRIS:
		var active: bool = sort_key == item[0]
		var button := Button.new()
		button.name = "CreationSort_" + item[0]
		button.text = item[1] + ("  ▾" if active else "")
		button.set_meta("immersive_style_applied", true)
		button.toggle_mode = true
		button.button_pressed = active
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = "Trier par %s (du plus fort au plus faible)" % item[1].to_lower()
		button.add_theme_font_override("font", C.BODY)
		button.add_theme_font_size_override("font_size", C.font_px(17))
		for look in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			var style := _flat(Charte.PANNEAU_3 if active or look in ["hover", "hover_pressed"] else Color(0, 0, 0, 0), C.IVORY if active or look == "focus" else Charte.IVOIRE_3, Vector2(12, 3), Charte.RAYON_PILULE)
			button.add_theme_stylebox_override(look, style)
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: button.add_theme_color_override(key, C.IVORY)
		button.pressed.connect(func():
			app.management_ui[TRI] = item[0]
			app._render())
		info.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.name = "CreationClubsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	C.fill(scroll, true)
	column.add_child(scroll)
	var holder := C.v(10)
	C.fill(holder)
	scroll.add_child(holder)
	var grid := GridContainer.new()
	grid.name = "CreationClubGrid"
	grid.columns = 4 if screen.x >= 1200 else 3
	grid.add_theme_constant_override("h_separation", C.px(21))
	grid.add_theme_constant_override("v_separation", C.px(16))
	C.fill(grid)
	holder.add_child(grid)
	var rivals := {}
	if not selected.is_empty():
		for rival: Variant in Kit.preview(app, int(selected.id)).get("rivals", []):
			if rival is Dictionary: rivals[int(rival.get("id", -1))] = true
	var ordered := _trier(ctx.division_clubs, sort_key)
	for index in ordered.size():
		grid.add_child(_carte(app, ordered[index], index + 1, ctx, rivals.has(int(ordered[index].id))))
	var empty := C.v(6)
	empty.name = "CreationSearchEmpty"
	empty.visible = false
	holder.add_child(empty)
	empty.add_child(_texte("Aucun club ne correspond.", C.MUTED))
	var clear := _lien("Effacer la recherche", func():
		app.management_ui.erase(RECHERCHE)
		var field := app.find_child("CreationSearch", true, false) as LineEdit
		if field != null: field.text = ""
		_filtrer(app), "CreationSearchClear", 17, true)
	clear.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	empty.add_child(clear)
	var rows := ceili(float(ordered.size()) / grid.columns)
	scroll.resized.connect(_ajuster.bind(scroll, grid, rows))
	if not str(app.management_ui.get(RECHERCHE, "")).is_empty(): _filtrer.call_deferred(app)

## Hauteur des cartes : toute la division tient dans la grille ; à petite taille, les lignes secondaires
## (conseil, puis rang de la saison passée, puis jauge) s'effacent avant que rien ne déborde.
static func _ajuster(scroll: ScrollContainer, grid: GridContainer, rows: int) -> void:
	if rows <= 0 or scroll.size.y <= 0: return
	var gaps := grid.get_theme_constant("v_separation") * (rows - 1)
	var height := clampf(floorf((scroll.size.y - gaps - 1) / rows), 0, C.px(330))
	for card: Button in grid.get_children():
		var inset := card.get_child(0) as Control
		var optional: Array = card.get_meta("optionnel", [])
		for node: Control in optional: node.visible = true
		for node: Control in optional:
			if inset.get_combined_minimum_size().y <= height: break
			node.visible = false
		# Ligne d'ordre effacée : « ✓ » et « Rival » passent devant le nom (la sélection ne repose jamais sur la couleur).
		var name := card.get_meta("nom", null) as Label
		if name != null: name.text = (str(card.get_meta("repere", "")) if not (card.get_meta("ligne") as Control).visible else "") + G.club_name(card.get_meta("club", {}))
		card.custom_minimum_size.y = maxf(height, inset.get_combined_minimum_size().y)

static func _carte(app: Control, club: Dictionary, order: int, ctx: Dictionary, rival: bool) -> Button:
	var selected: Dictionary = ctx.selected
	var chosen: bool = not selected.is_empty() and int(club.id) == int(selected.id)
	var card := Button.new()
	card.name = "CreationClub" + str(int(club.id))
	card.set_meta("immersive_style_applied", true)
	card.set_meta("recherche", "%s %s %s %s" % [G.club_name(club), str(club.get("abbr", "")), str(club.get("city", "")), str(club.get("stadium", ""))])
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.clip_contents = true
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.accessibility_name = G.club_name(club)
	card.accessibility_description = Entry._territory(club) + (" · club choisi" if chosen else "")
	card.tooltip_text = "%s\nClic : choisir · Double-clic ou Entrée : étape suivante" % G.club_name(club)
	for look in ["normal", "hover", "pressed", "focus", "disabled"]:
		var fill: Color = Charte.PANNEAU_3 if chosen else (Charte.PANNEAU_2 if look in ["hover", "pressed"] else C.PANEL)
		var style := _flat(fill, Color(0, 0, 0, 0), Vector2(0, 0), Charte.RAYON_CARTE)
		if look == "focus":
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = C.IVORY
			style.set_border_width_all(2)
		card.add_theme_stylebox_override(look, style)
	card.pressed.connect(func():
		if chosen and Input.is_action_pressed("ui_accept"):
			suivant(app, ctx)
			return
		Entry._select_club(app, int(club.id), true))
	card.gui_input.connect(func(event: InputEvent):
		var mouse := event as InputEventMouseButton
		if mouse != null and mouse.double_click and mouse.button_index == MOUSE_BUTTON_LEFT and chosen:
			card.accept_event()
			suivant(app, ctx))
	var inset := C.margin(0)
	for edge in ["left", "right"]: inset.add_theme_constant_override("margin_" + edge, C.px(24))
	inset.add_theme_constant_override("margin_top", C.px(14))
	inset.add_theme_constant_override("margin_bottom", C.px(10))
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inset)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := C.v(6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(stack)
	var optional: Array[Control] = []
	# Ligne 1 : ordre, saison passée, étiquettes « Rival » et « ✓ Choisi ».
	var top := C.h(8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(top)
	var last := _saison_passee(club)
	var rank := C.label("%d%s" % [order, " · " + str(last.texte) if not last.is_empty() else ""], 16, C.MUTED, false)
	rank.name = "CreationCardOrder"
	top.add_child(C.fill(rank))
	if rival:
		var tag := _surface(Color(0, 0, 0, 0), 0)
		var tag_style := tag.get_theme_stylebox("panel") as StyleBoxFlat
		tag_style.border_color = C.IVORY
		tag_style.border_width_bottom = 1
		tag_style.border_width_top = 1
		tag_style.content_margin_left = C.px(6)
		tag_style.content_margin_right = C.px(6)
		tag_style.skew = Vector2(tan(deg_to_rad(Charte.INCLINAISON_DEGRES)), 0)
		tag.name = "CreationCardRival"
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(C.label("RIVAL", 15, C.IVORY, true, 700))
		top.add_child(tag)
	if chosen:
		var mark := C.label("✓ CHOISI", 16, C.IVORY, true, 700)
		mark.name = "CreationCardChosen"
		top.add_child(mark)
	# Ligne 2 : marqueur de sélection incliné, écusson, nom, ville et stade.
	var identity := C.h(14)
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(identity)
	if chosen:
		var marker := _incline(C.IVORY, Vector2(maxi(3, C.px(5)), C.px(58)))
		marker.name = "CreationCardMarker"
		marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		identity.add_child(marker)
	var crest := Entry._creation_crest(club, C.px(56), ctx.preferred == "base")
	crest.tooltip_text = ""
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(crest)
	var names := C.v(0)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(C.fill(names))
	var name := C.label(G.club_name(club), 27, C.IVORY, true, 700)
	name.name = "CreationCardName"
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(name)
	var place := PackedStringArray()
	for part in [Entry._territory(club), str(club.get("stadium", ""))]:
		if not str(part).strip_edges().is_empty(): place.append(str(part).strip_edges())
	var where := C.label(" · ".join(place), 16, C.MUTED, false)
	where.clip_text = true
	where.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(where)
	var rule := C.rule()
	stack.add_child(rule)
	# Ligne 3 : Niveau et Trésorerie (chiffres en police droite), jauge du niveau.
	var figures := C.h(12)
	figures.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(figures)
	if _niveau(club) > 0: _chiffre_carte(figures, "Niveau", Entry._rating(club.get("startingRoster", {})))
	if club.has("cashMillions"): _chiffre_carte(figures, "Trésorerie", _millions(float(club.cashMillions)))
	var rail := Jauge.new()
	rail.value = _niveau(club)
	rail.custom_minimum_size.y = maxi(2, C.px(5))
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.accessibility_name = "Niveau %s sur 100" % Entry._rating(club.get("startingRoster", {}))
	stack.add_child(rail)
	var goal := str(club.get("goal", "")).strip_edges()
	if not goal.is_empty():
		var advice := C.label("Conseil : " + goal, 17, C.MUTED, false)
		advice.name = "CreationCardGoal"
		advice.clip_text = true
		advice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		stack.add_child(advice)
	# Ordre d'effacement à petite taille : filet, jauge, conseil, puis la ligne d'ordre (jamais le nom ni les chiffres).
	optional.append(rule)
	optional.append(rail)
	if not goal.is_empty(): optional.append(stack.get_child(stack.get_child_count() - 1))
	optional.append(top)
	card.set_meta("nom", name)
	card.set_meta("ligne", top)
	card.set_meta("club", club)
	card.set_meta("repere", ("✓ " if chosen else "") + ("Rival · " if rival else ""))
	card.set_meta("optionnel", optional)
	card.accessibility_description += " · Niveau %s · %d joueurs" % [Entry._rating(club.get("startingRoster", {})), _joueurs(club)]
	return card

static func _chiffre_carte(parent: HBoxContainer, caption: String, value: String) -> void:
	var column := C.v(0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(C.fill(column))
	column.add_child(_etiquette(caption))
	var figure := C.label(value, 37, C.IVORY, true, 800)
	figure.clip_text = true
	column.add_child(figure)

class Jauge extends Control:
	var value := 0.0
	func _ready() -> void:
		resized.connect(queue_redraw)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Charte.FILET)
		draw_rect(Rect2(0, 0, size.x * clampf(value / 100.0, 0.0, 1.0), size.y), Charte.IVOIRE_2)

# ---------------------------------------------------------------------------------------------------------------
# Cadre plein écran : barre haute, page, pied

static func workspace(app: Control, page: Control) -> Control:
	var screen: Vector2i = app.get_window().size
	C.configure(screen.y, screen.x)
	var ctx: Dictionary = page.get_meta("creation_ctx", {})
	var shell := _surface(C.BG)
	shell.name = "ImmersiveCreationWorkspace"
	var column := C.v(0)
	shell.add_child(column)
	column.add_child(_barre(app, ctx))
	var body := C.margin(0)
	for edge in ["left", "right"]: body.add_theme_constant_override("margin_" + edge, C.px(64 if screen.x >= 1600 else 32))
	body.add_theme_constant_override("margin_top", C.px(28))
	body.add_theme_constant_override("margin_bottom", C.px(16))
	C.fill(body, true)
	column.add_child(body)
	body.add_child(page)
	column.add_child(_pied(app))
	return shell

static func _barre(app: Control, ctx: Dictionary) -> Control:
	var bar := _surface(C.PANEL)
	bar.name = "CreationTopbar"
	var bar_style := bar.get_theme_stylebox("panel") as StyleBoxFlat
	bar_style.border_color = C.LINE
	bar_style.border_width_bottom = 1
	bar_style.content_margin_left = C.px(20)
	bar_style.content_margin_right = C.px(32)
	bar.custom_minimum_size.y = C.px(85)
	var row := C.h(26)
	bar.add_child(row)
	var logo := TextureRect.new()
	logo.name = "EntryWordmark"
	logo.texture = load("res://branding/rugby-legacy-27-logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(C.px(170), C.px(80))
	var composite := ShaderMaterial.new()
	composite.shader = load("res://branding/black_key.gdshader")
	logo.material = composite
	logo.tooltip_text = "Rugby Legacy 27"
	logo.accessibility_name = "Rugby Legacy 27"
	logo.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(logo)
	row.add_child(_filet_vertical())
	var back := C.h(6)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(back)
	var home := _lien("← Accueil", func(): app._navigate("Accueil"), "CreationBackHome", 17)
	home.tooltip_text = "Retour à l’accueil (Échap) · rien n’est enregistré"
	back.add_child(home)
	back.add_child(_touche("Échap"))
	row.add_child(_filet_vertical())
	# Fil des étapes : « 1 Club » actif ; « 2 Carrière » s'ouvre une fois un club choisi.
	var steps := C.h(14)
	steps.name = "CreationSteps"
	steps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(steps)
	var first := C.v(2)
	steps.add_child(first)
	var first_label := C.label("1  Club".to_upper(), 23, C.IVORY, true, 800)
	first_label.add_theme_font_override("font", Charte.TITRE_EXTRA)
	first.add_child(first_label)
	first.add_child(_incline(C.IVORY, Vector2(0, maxi(2, C.px(4)))))
	steps.add_child(C.label("›", 20, C.FAINT, false))
	var selected: Dictionary = ctx.get("selected", {})
	if selected.is_empty() or bool(ctx.get("unavailable", false)):
		var second := C.label("2  Carrière".to_upper(), 23, C.MUTED, true, 700)
		second.add_theme_font_override("font", Charte.TITRE_GRAS)
		second.name = "CreationStepCareer"
		second.tooltip_text = "Choisis d’abord un club"
		second.mouse_filter = Control.MOUSE_FILTER_PASS
		steps.add_child(second)
	else:
		var go := _lien("2  CARRIÈRE  →", func(): suivant(app, ctx), "CreationStepCareer", 23)
		go.add_theme_font_override("font", Charte.TITRE_GRAS)
		steps.add_child(go)
	row.add_child(C.fill(Control.new()))
	var teams: Array = ctx.get("teams", [])
	if not teams.is_empty():
		var roles := Entry.role_controls(app, teams, str(ctx.get("role", "club")))
		roles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(roles)
	var packs := _lien("Identités et packs", func(): app.pack_manager.open("creation"), "CreationManagePacks", 17, true)
	packs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	packs.tooltip_text = "Pack actif : " + str(ctx.get("pack_name", "Jeu de base"))
	row.add_child(packs)
	if str(ctx.get("preferred", "base")) != "base":
		var active := _texte(str(ctx.get("pack_name", "")), C.ALERT if bool(ctx.get("unavailable", false)) else C.MUTED)
		active.name = "CreationActivePack"
		active.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(active)
	# Gabi (« Gabi · ? » et « Visite ») se pose dans cet emplacement (coach_canvas).
	var slot := Control.new()
	slot.name = "CreationGabiSlot"
	slot.custom_minimum_size = Vector2(150, 34)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(slot)
	return bar

static func _filet_vertical() -> ColorRect:
	var line := ColorRect.new()
	line.color = C.LINE
	line.custom_minimum_size = Vector2(1, C.px(37))
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

static func _pied(app: Control) -> Control:
	var foot := _surface(C.PANEL)
	foot.name = "CreationFooter"
	var style := foot.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = C.LINE
	style.border_width_top = 1
	style.content_margin_left = C.px(32)
	style.content_margin_right = C.px(32)
	foot.custom_minimum_size.y = C.px(48)
	var row := C.h(16)
	foot.add_child(row)
	var database: Dictionary = app.pack_manager.database("creation")
	var count := "%d clubs jouables · %s joueurs" % [app.pack_manager.playable_club_count("creation"), G.n(database.get("startingPlayerCount", database.get("playerCount", 0)))]
	var left := C.label(count, 16, C.MUTED, false)
	left.name = "CreationWorldInfo"
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(C.fill(left))
	var right := C.label("Double-clic ou Entrée : étape suivante · Rien n’est enregistré avant « Prendre les rênes »", 16, C.MUTED, false)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.clip_text = true
	right.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(C.fill(right, false, 2.0))
	return foot
