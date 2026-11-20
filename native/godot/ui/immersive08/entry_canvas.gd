extends RefCounted
## Les seuils de la carrière partagent la DA des menus et les actions existantes.
const C = preload("res://ui/immersive08/components.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const Club = preload("res://ui/club_views.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Entry = preload("res://ui/entry_screens.gd")
const G = preload("res://ui/game_skin.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const CreationCanvas = preload("res://ui/immersive08/creation_canvas.gd")
const GREEN = Color("176e49")

static func _configure(app: Control) -> void:
	var window := app.get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	C.configure(window.size.y,window.size.x)

const Accueil = preload("res://ui/immersive08/accueil_canvas.gd")

## Nom affiché sur l'affiche (le lettrage du logo) ; sert aussi de nom accessible.
const NOM_JEU := "RUGBY LEGACY 27"

static func home(app: Control) -> Control:
	return Accueil.home(app, NOM_JEU)

static func workspace(app: Control, page: Control, creation: bool) -> Control:
	_configure(app)
	var size := app.get_window().size
	# Étape « 1 Club » : cadre plein écran propre à l'écran 02 (barre haute, page, pied).
	if creation and page.has_meta("creation_club_step"):
		var frame: Control = CreationCanvas.workspace(app, page)
		_observe_entry_size(app, frame, size, creation)
		return frame
	if not creation or app.pack_manager.creation_mode == "auto":
		return _editorial_workspace(app, page, creation, size)
	var compact := size.y < 850
	var column := C.v(8 if compact else 14)
	column.name = "ImmersiveCreationWorkspace" if creation else "ImmersiveIdentityWorkspace"
	var banner := Control.new()
	var height := 104 if compact else 186
	banner.custom_minimum_size.y = C.px(height)
	column.add_child(banner)
	D.rect(banner,Rect2(0,0,2560,height),C.PANEL)
	var mode: String = app.pack_manager.mode("creation" if creation else "")
	var art := str({"world-pacific":"pacific-ground","world-japan":"japan-ground","world-nationale":"nationale-ground","world-champ":"champ-ground"}.get(mode,"entry-ground" if creation else "club-forest"))
	var crop := .52 if mode in ["world-nationale","world-champ"] else .47 if mode in ["world-pacific","world-japan"] else 0.0
	D.photo(banner,art,Rect2(1250,0,1310,height),crop)
	var fade := Control.new()
	banner.add_child(fade)
	D.place(fade,Rect2(0,0,1870,height))
	C.veil(fade)
	var divider := 236 if compact else 327
	D.photo(banner,"brand",Rect2(41,16,162,71) if compact else Rect2(41,34,252,110))
	D.line(banner,Vector2(divider,19 if compact else 35),Vector2(divider,height-(19 if compact else 39)),Color(C.GOLD,.75))
	D.text(banner,divider+38,34 if compact else 67,"TA PREMIÈRE SAISON" if creation else "L’ATELIER DES IDENTITÉS",22 if compact else 24,C.GOLD,700,1040)
	D.text(banner,divider+36,80 if compact else 131,"Prendre les rênes" if creation else "Habiller ton rugby",44 if compact else 57,C.IVORY,700,1050)
	D.line(banner,Vector2(0,height-1),Vector2(2560,height-1),C.LINE)
	var inset := C.margin(38)
	inset.add_theme_constant_override("margin_top",C.px(6 if compact else 14))
	if compact: inset.add_theme_constant_override("margin_bottom",C.px(18))
	C.fill(inset,true)
	column.add_child(inset)
	inset.add_child(page)
	if creation:
		# Le bandeau de création encadre les modes entre les boutons Accueil et Packs.
		var actions := page.get_child(0).find_children("*","Button",false,false)
		if actions.size() >= 2:
			actions.front().name = "CreationBackHome"
			actions.back().name = "CreationManagePacks"
		if app.pack_manager.creation_mode != "auto": _illustrate_preview(page)
	Legacy.apply(page,GREEN if not app.model.get("club") is Dictionary else app.accent)
	if creation:
		if app.pack_manager.creation_mode != "auto":
			_fit_pagination(page)
			if compact and app.pack_manager.mode("creation") == "world-japan": _fit_japan_clubs(page)
		if not compact:
			_fit_club_cards(page)
	if size.x >= 2240 and size.y >= 1250:
		_career_context(app, page)
	_observe_entry_size(app, column, size, creation)
	return column

static func _editorial_workspace(app: Control, page: Control, creation: bool, size: Vector2i) -> Control:
	var shell := PanelContainer.new()
	shell.name = "ImmersiveCreationWorkspace" if creation else "ImmersiveIdentityWorkspace"
	Editorial.surface(shell, Editorial.INK, Color.TRANSPARENT, 0)
	if creation:
		var ink := C.photo("maquette-onglets-ink", Vector2.ZERO, false)
		ink.stretch_mode = TextureRect.STRETCH_SCALE
		ink.modulate.a = .32
		shell.add_child(ink)
	var column := C.v(0)
	shell.add_child(column)
	var masthead := PanelContainer.new()
	Editorial.surface(masthead, Color("0f1719"), Color.TRANSPARENT, 0)
	column.add_child(masthead)
	var rail := C.h(24)
	masthead.add_child(rail)
	var inset := C.margin(13)
	rail.add_child(inset)
	# Lettrage de marque : « RUGBY LEGACY 27 » (remplace les anciennes images de maquette à l ancien nom).
	var wordmark := C.h(8)
	wordmark.name = "EntryWordmark"
	wordmark.custom_minimum_size = Vector2(C.px(300 if creation else 250), C.px(48))
	var wordmark_name := C.label("RUGBY LEGACY", 36 if creation else 30, C.IVORY, true, 800)
	wordmark_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wordmark.add_child(wordmark_name)
	var wordmark_year := C.label("27", 36 if creation else 30, C.GOLD, true, 800)
	wordmark_year.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wordmark.add_child(wordmark_year)
	inset.add_child(wordmark)
	Editorial.divider(rail)
	var nation_creation := creation and page.find_child("CreationNationalDossier", true, false) != null
	# Fil de la création : « 1 Club › 2 Carrière » (la réalité de jeu se choisit dans Identités et packs).
	var step_names := (["1  Sélection" if nation_creation else "1  Club", "2  Carrière"]) if creation else ["01  Réalité", "02  Club", "03  Carrière"]
	var options_step := creation and page.find_child("CreationCareerOptions", true, false) != null
	for index in step_names.size():
		var active := index == ((1 if options_step else 0) if creation else 0)
		var step := C.v(5)
		step.alignment = BoxContainer.ALIGNMENT_CENTER
		rail.add_child(step)
		step.add_child(C.label(step_names[index], 29 if creation else 25, Editorial.RAIL_GOLD if creation and active else C.IVORY, creation, 700 if active else 600))
		var underline := ColorRect.new()
		underline.color = Editorial.BRASS if active else Color.TRANSPARENT
		underline.custom_minimum_size.y = 2
		step.add_child(underline)
	var banner := Control.new()
	# Options de carrière : bandeau resserré, la page tient sans défilement en 1920×1080.
	banner.custom_minimum_size.y = clampf(size.y * .07, 52, 120) if options_step else clampf(size.y * (.128 if creation else .15), 88, 215)
	column.add_child(banner)
	var photo := C.photo(("titre-nouvelle-carriere" if BanqueImages.existe("titre-nouvelle-carriere") else "maquette-onglets-banner") if creation else "maquette-reality-banner", Vector2.ZERO, true, .5)
	banner.add_child(photo)
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo.anchor_left = 0.0 if creation else .31
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(Editorial.INK, .72), Color(Editorial.INK, .44), Color(Editorial.INK, 0.0)]) if creation else PackedColorArray([Editorial.INK, Editorial.INK, Color(Editorial.INK, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, .16 if creation else .32, .43 if creation else .56])
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	var shade := TextureRect.new()
	shade.texture = shade_texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var padding := C.margin(57 if creation else 48)
	padding.add_theme_constant_override("margin_top", C.px(12 if options_step else 30))
	padding.add_theme_constant_override("margin_bottom", C.px(12 if options_step else 30))
	banner.add_child(padding)
	padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var header := C.h(29)
	padding.add_child(header)
	if not creation:
		var marker := ColorRect.new()
		marker.color = Editorial.BRASS
		marker.custom_minimum_size.x = maxi(2, C.px(4))
		header.add_child(marker)
	var heading := C.v(0)
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	C.fill(heading)
	header.add_child(heading)
	if creation:
		heading.add_child(C.label("Options de carrière" if options_step else "Choisir sa sélection" if nation_creation else "Choisir son club", 58 if options_step else 74, C.IVORY, true, 700))
		var underline := ColorRect.new()
		underline.color = Editorial.RAIL_GOLD
		underline.custom_minimum_size = Vector2(C.px(100), C.px(4 if options_step else 5))
		underline.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		heading.add_child(underline)
	else:
		heading.add_child(C.label("Choisir sa réalité", 74, C.IVORY, true, 700))
		heading.add_child(C.wrap("Sélectionne la réalité de jeu pour ta prochaine carrière.", 25, C.IVORY))
	column.add_child(C.rule())
	var body := C.margin(21 if creation else 27)
	C.fill(body, true)
	column.add_child(body)
	body.add_child(page)
	if creation:
		var tools := page.get_child(0) as HBoxContainer
		var buttons := tools.find_children("*", "Button", false, false)
		if buttons.size() >= 2:
			buttons.front().name = "CreationBackHome"
			buttons.back().name = "CreationManagePacks"
		var wide := size.x >= 1480
		if wide: page.remove_child(tools)
		rail.add_child(C.fill(Control.new()))
		# Gabi (« Gabi · ? » et « Visite ») vit dans le bandeau du haut, jamais sur la barre des championnats.
		var slot := Control.new()
		slot.name = "CreationGabiSlot"
		slot.custom_minimum_size = Vector2(150, 34)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rail.add_child(slot)
		if wide:
			tools.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			rail.add_child(tools)
		var edge := Control.new()
		edge.custom_minimum_size.x = C.px(15)
		rail.add_child(edge)
	Legacy.apply(page, Editorial.BRASS)
	_observe_entry_size(app, shell, size, creation)
	return shell

static func _observe_entry_size(app: Control, workspace: Control, built_size: Vector2i, creation: bool) -> void:
	var window := app.get_window()
	var picker: FileDialog = null if creation else app.pack_manager.picker
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = .08
	workspace.add_child(timer)
	var resized := func():
		if workspace.is_inside_tree() and window.size != built_size: timer.start()
	window.size_changed.connect(resized)
	if picker != null: picker.visibility_changed.connect(resized)
	workspace.tree_exiting.connect(func():
		window.size_changed.disconnect(resized)
		if is_instance_valid(picker): picker.visibility_changed.disconnect(resized), CONNECT_ONE_SHOT)
	timer.timeout.connect(func():
		if window.size == built_size or window.size.x < 1280 or window.size.y < 720 or app.waiting: return
		if picker != null and picker.visible: return
		_refresh_entry_size(app, workspace, creation))

static func _refresh_entry_size(app: Control, workspace: Control, creation: bool) -> void:
	if app.route != ("Création" if creation else "Packs") or not app.root_content.is_ancestor_of(workspace): return
	var focus := app.get_viewport().gui_get_focus_owner()
	var focus_id := str(focus.name) if focus != null and workspace.is_ancestor_of(focus) else ""
	# Les commandes de l’atelier sont anonymes. Leur ordre est stable à toutes les tailles.
	var pack_focus := workspace.find_children("*", "Button", true, false).find(focus) if not creation else -1
	var pack_scrolls: Array[int] = []
	if not creation:
		for panel: ScrollContainer in workspace.find_children("*", "ScrollContainer", true, false):
			pack_scrolls.append(panel.scroll_vertical)
	var list := workspace.find_child("CreationClubsScroll", true, false) as ScrollContainer
	var list_scroll := list.scroll_vertical if list != null else 0
	var page_scroll: int = app.entry_scroll.scroll_vertical
	app._render()
	var new_scroll: ScrollContainer = app.entry_scroll
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	if not is_instance_valid(new_scroll) or app.entry_scroll != new_scroll: return
	new_scroll.scroll_vertical = page_scroll
	list = new_scroll.find_child("CreationClubsScroll", true, false) as ScrollContainer
	if list != null: list.scroll_vertical = list_scroll
	if not pack_scrolls.is_empty():
		var panels := new_scroll.find_children("*", "ScrollContainer", true, false)
		for i in mini(pack_scrolls.size(), panels.size()):
			panels[i].scroll_vertical = pack_scrolls[i]
	var target := new_scroll.find_child(focus_id, true, false) as Control if not focus_id.is_empty() else null
	if pack_focus >= 0:
		var buttons := new_scroll.find_children("*", "Button", true, false)
		if pack_focus < buttons.size(): target = buttons[pack_focus]
	if target != null and target.is_visible_in_tree(): target.grab_focus()

static func _illustrate_preview(page: Control) -> void:
	var title := page.find_child("CreationClubTitle", true, false) as Label
	if title == null: return
	var content := title.get_parent() as VBoxContainer
	var overlay := content.get_parent() as MarginContainer
	var cover := overlay.get_parent() as ColorRect
	if cover == null or cover.get_meta("content", null) != content: return
	var photo := C.photo("entry-preview", Vector2.ZERO, true, .43)
	if photo.texture == null:
		photo.free()
		return
	cover.clip_contents = true
	cover.add_child(photo)
	cover.move_child(photo, overlay.get_index())
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(C.BG, .45))
	gradient.add_point(.42, Color(C.BG, .05))
	gradient.set_color(gradient.get_point_count()-1, Color(C.BG, .89))
	var shade := GradientTexture2D.new()
	shade.gradient = gradient
	shade.fill_to = Vector2.DOWN
	var veil := TextureRect.new()
	veil.texture = shade
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(veil)
	cover.move_child(veil, overlay.get_index())
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var credit := C.label("ILLUSTRATION D’AMBIANCE", 17, C.GOLD, true, 700)
	credit.name = "EntryPreviewCredit"
	credit.set_meta("immersive_style_applied", true)
	credit.tooltip_text = "Aperçu du club"
	content.add_child(credit)

static func _fit_japan_clubs(page: Control) -> void:
	var choices := page.find_child("CreationClubsScroll", true, false)
	if choices == null: return
	var grids := choices.find_children("*", "GridContainer", true, false)
	if not grids.is_empty() and grids[0].get_child_count() > 8:
		grids[0].columns = 3

static func _fit_club_cards(page: Control) -> void:
	for card: Button in page.find_children("CreationClub*", "Button", true, false):
		for inset in card.get_children():
			if inset is MarginContainer:
				card.ready.connect(func():
					if is_instance_valid(card):
						card.custom_minimum_size.y = maxf(card.custom_minimum_size.y, inset.get_combined_minimum_size().y), CONNECT_ONE_SHOT | CONNECT_DEFERRED)

static func _fit_pagination(page: Control) -> void:
	var pagination := page.find_child("CreationPagination", true, false)
	if pagination == null: return
	for action in pagination.get_children():
		if not action is Button: continue
		var font: Font = action.get_theme_font("font")
		var pixels: int = action.get_theme_font_size("font_size")
		var caption := font.get_string_size(action.text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels)
		var style: StyleBox = action.get_theme_stylebox("normal")
		action.custom_minimum_size.x = maxf(action.custom_minimum_size.x,ceilf(caption.x+style.get_minimum_size().x)+2.0)

static func _career_context(app: Control, page: Control) -> void:
	var choices := page.find_child("CreationClubsScroll", true, false) as ScrollContainer
	if choices == null: return
	var catalogue: Array = app.pack_manager.creation_catalogue()
	var selected := {}
	for club: Dictionary in catalogue:
		if int(club.id) == app.selected_club:
			selected = club
			break
	if selected.is_empty(): return
	var context := C.v(8)
	context.name = "EntryCareerContext"
	var heading := C.wrap("TON CARNET · " + G.club_name(selected), 24, C.GOLD, true, 700)
	heading.name = "EntrySelectedClub"
	context.add_child(heading)
	var tiles := C.h(12)
	context.add_child(tiles)
	var division := str(selected.get("division", ""))
	var rivals := catalogue.filter(func(club: Dictionary): return club.get("playable", true) and str(club.get("division", "")) == division).size()
	var ground := str(selected.get("stadium", ""))
	var objective := str(selected.get("goal", ""))
	_tile(tiles, "01  ·  PROJET SPORTIF", "Ta feuille de route", objective if not objective.is_empty() else "Consulte les objectifs du club dans le Bureau après la prise de poste.", "training-session", C.MINT)
	_tile(tiles, "02  ·  TERRAIN", "Jouer à domicile", ground if not ground.is_empty() else "Retrouve les installations du club dans le carnet de carrière.", str({"nationale":"nationale-ground","champ":"champ-ground"}.get(division,"entry-ground")), C.GOLD, true, .52 if division in ["nationale","champ"] else .29)
	_tile(tiles, "03  ·  COMPÉTITION", Club.competition_name(division), "%s clubs jouables dans cette division" % G.n(rivals), "trophy", C.BLUE)
	var column := choices.get_parent()
	column.add_child(context)
	column.move_child(context, choices.get_index() + 1)

static func _tile(parent: HBoxContainer, label: String, title: String, copy: String, art: String, tint: Color, cover: bool = true, focus: float = .29) -> void:
	var frame := C.card()
	C.fill(frame)
	parent.add_child(frame)
	var content := C.content(frame)
	content.add_child(C.photo(art, Vector2(0, 133), cover, focus))
	content.add_child(C.label(label, 18, tint, true, 700))
	content.add_child(C.wrap(title, 26, C.IVORY, true, 700))
	content.add_child(C.wrap(copy, 17, C.MUTED))
