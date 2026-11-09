extends RefCounted
## Les seuils de la carrière partagent la DA des menus et les actions existantes.
const C = preload("res://ui/immersive08/components.gd")
const Club = preload("res://ui/club_views.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const GREEN = Color("176e49")

static func _configure(app: Control) -> void:
	var window := app.get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	C.configure(window.size.y,window.size.x)

static func home(app: Control) -> Control:
	_configure(app)
	var page := Control.new()
	page.name = "CarnetHome"
	var photo := C.photo("entry-ground")
	page.add_child(photo)
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shading := Gradient.new()
	shading.set_color(0,Color(C.BG,.98))
	shading.add_point(.29,Color(C.BG,.86))
	shading.add_point(.62,Color(C.BG,.15))
	shading.set_color(shading.get_point_count()-1,Color(C.BG,.46))
	var ramp := GradientTexture2D.new()
	ramp.gradient = shading
	ramp.fill_to = Vector2.RIGHT
	var veil := TextureRect.new()
	veil.texture = ramp
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := Control.new()
	content.name = "ImmersiveWelcome"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(content)
	var reference := Vector2(2560,1440)*C.density
	page.resized.connect(_fit.bind(page,content,reference))
	_fit(page,content,reference)
	var masthead := D.rect(content,Rect2(0,0,2560,166),Color(C.BG,.82))
	D.photo(masthead,"brand",Rect2(83,22,274,120))
	D.line(masthead,Vector2(400,48),Vector2(400,114),Color(C.GOLD,.68))
	D.text(masthead,430,76,"CARRIÈRE DE MANAGER",22,C.GOLD,700,520)
	D.text(masthead,430,111,"Rugby à XV  /  Édition Windows",25,C.IVORY,500,840)
	D.line(masthead,Vector2(0,165),Vector2(2560,165),Color(C.LINE,.75))
	D.button(masthead,Rect2(2196,57,278,52),"Crédits",app._credits,false,"info",true,GREEN,"EntryCredits")
	D.line(content,Vector2(108,490),Vector2(198,490),C.GOLD,3)
	D.text(content,110,535,"OVAL LEGACY 27",29,C.GOLD,700,1370)
	D.text(content,104,664,"Un club. Un territoire.",108,C.IVORY,800,1460)
	D.text(content,106,775,"Une saison à écrire.",103,C.IVORY,700,1458)
	D.text(content,112,851,"Prenez les rênes. Préparez le XV, faites grandir le club et vivez la saison.",29,C.IVORY,400,1400,HORIZONTAL_ALIGNMENT_LEFT,true)
	var meta: Dictionary = app.model.get("meta",{})
	var database: Dictionary = meta.get("database",{})
	var france: Array = meta.get("legacyCatalogue", app.catalogue)
	var world: Array = meta.get("worldCatalogue", [])
	var pacific: Array = meta.get("pacificCatalogue", [])
	var next_chip := 112
	if not france.is_empty():
		var count := france.filter(func(item: Dictionary): return item.get("playable", true)).size()
		D.chip(content,Rect2(next_chip,895,249,52),"France · %d clubs" % count,C.GOLD).name="EntryFranceCount"
		next_chip+=263
	if not world.is_empty():
		var count := world.filter(func(item: Dictionary): return item.get("playable", true)).size()
		D.chip(content,Rect2(next_chip,895,249,52),"Monde · %d clubs" % count,C.BLUE).name="EntryWorldCount"
		next_chip+=263
	if not pacific.is_empty():
		var count := pacific.filter(func(item: Dictionary): return item.get("playable", true)).size()
		D.chip(content,Rect2(next_chip,895,249,52),"Pacifique · %d clubs" % count,C.MINT).name="EntryPacificCount"
		next_chip+=263
	if int(database.get("playerCount",0))>0:
		D.chip(content,Rect2(next_chip,895,305,52),G.n(database.playerCount)+" joueurs · base active",C.MINT)
	var club: Dictionary = app.model.get("club") if app.model.get("club") is Dictionary else {}
	var accent: Color = GREEN if club.is_empty() else app.accent
	_choices(D.panel(content,Rect2(1642,248,827,1008),"","","","EntryCareerCard"),app,club,meta,accent)
	D.rect(content,Rect2(0,1332,2560,108),Color(C.BG,.87))
	D.line(content,Vector2(84,1332),Vector2(2475,1332),Color(C.LINE,.64))
	D.text(content,88,1399,"APPLICATION WINDOWS NATIVE  ·  CARRIÈRE LOCALE",23,C.IVORY,600,1180)
	D.text(content,2468,1399,"OVAL LEGACY 27",23,C.GOLD,700,340,HORIZONTAL_ALIGNMENT_RIGHT)
	return page

static func _fit(page: Control, content: Control, reference: Vector2) -> void:
	if page.size.x<=0 or page.size.y<=0: return
	var scale := minf(page.size.x/reference.x,page.size.y/reference.y)
	content.size = reference
	content.scale = Vector2.ONE*scale
	content.position = (page.size-reference*scale)/2.0

static func _choices(card: Panel, app: Control, club: Dictionary, meta: Dictionary, accent: Color) -> void:
	D.text(card,43,58,"OUVRIR LE CARNET",25,C.GOLD,700,737)
	D.text(card,41,120,"Votre prochain chapitre",48,C.IVORY,700,739)
	D.line(card,Vector2(42,144),Vector2(785,144),Color(C.LINE,.75))
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	D.place(scroll,Rect2(42,171,743,793))
	var choices := C.v(15)
	C.fill(choices)
	scroll.add_child(choices)
	if not club.is_empty():
		var identity := C.card("",Vector2(0,137))
		choices.add_child(identity)
		var row := C.h(24)
		C.content(identity).add_child(row)
		row.add_child(G.crest(club,C.px(82)))
		var name := C.v(4)
		C.fill(name)
		row.add_child(name)
		name.add_child(C.label("CARRIÈRE EN COURS",21,C.GOLD,true,700))
		name.add_child(C.wrap(G.club_name(club),34,C.IVORY,true,700))
		name.add_child(C.wrap("Saison %s · %s" % [G.n(meta.get("season",1)),str(meta.get("roundLabel","Début de saison"))],20,C.MUTED))
		_action(choices,"Reprendre la carrière",func():app._navigate("Bureau"),"EntryResume",accent,true)
	var locked: bool = app.model.is_empty() or meta.get("recoveryRequired",false)
	var create := _action(choices,"Nouvelle carrière",func():app._navigate("Création"),"EntryNewCareer",accent,club.is_empty())
	create.disabled = locked or app.catalogue.is_empty()
	var importing := _action(choices,"Importer une carrière",func():app.open_file(true),"EntryImportCareer",accent)
	importing.disabled = locked
	var missing: Array = app.model.get("packs",{}).get("missing",[])
	var creation_missing := missing.any(func(warning: String): return warning.begins_with("Pack de création absent"))
	var career_missing := missing.any(func(warning: String): return warning.begins_with("Pack de carrière absent"))
	var pack_scope := "creation" if club.is_empty() or (creation_missing and not career_missing) else "career"
	var packs := _action(choices,"Identités et packs",func():app.pack_manager.open(pack_scope),"EntryPacks",accent)
	packs.disabled = app.model.is_empty()
	var row := C.h(16)
	choices.add_child(row)
	C.fill(_action(row,"Paramètres",app.settings,"EntrySettings",accent))
	C.fill(_action(row,"Quitter",app.request_quit,"EntryQuit",accent))
	for warning: String in missing:
		choices.add_child(C.wrap(warning+" · Réimportez le pack dans Identités et packs.",19,C.ALERT))
	if meta.get("recoveryRequired",false):
		choices.add_child(C.wrap("Le profil ne peut pas être chargé. Sa copie sera conservée avant récupération.",21,C.ALERT))
		_action(choices,"Récupérer le profil",app.recover_profile,"EntryRecover",accent)
	elif app.connection_error:
		choices.add_child(C.wrap(app.last_error,21,C.ALERT))
		_action(choices,"Réessayer la connexion",app.reconnect,"EntryReconnect",accent)
	elif not app.last_error.is_empty(): choices.add_child(C.wrap(app.last_error,21,C.ALERT))
	elif app.model.is_empty(): choices.add_child(C.wrap("Ouverture du profil…",21,C.MUTED))

static func _action(parent: Container, caption: String, callback: Callable, id: String, accent: Color, primary: bool = false) -> Button:
	var action := C.button(caption,callback,primary,accent)
	action.name = id
	action.custom_minimum_size.y = C.px(61)
	action.alignment = HORIZONTAL_ALIGNMENT_LEFT
	action.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action.icon = C.icon_texture("arrow",C.IVORY if primary else C.MUTED)
	action.expand_icon = true
	action.add_theme_constant_override("icon_max_width",C.px(24))
	parent.add_child(action)
	return action

static func workspace(app: Control, page: Control, creation: bool) -> Control:
	_configure(app)
	var size := app.get_window().size
	var compact := size.y < 850
	var column := C.v(8 if compact else 14)
	column.name = "ImmersiveCreationWorkspace" if creation else "ImmersiveIdentityWorkspace"
	var banner := Control.new()
	var height := 104 if compact else 186
	banner.custom_minimum_size.y = C.px(height)
	column.add_child(banner)
	D.rect(banner,Rect2(0,0,2560,height),C.PANEL)
	var pacific: bool = app.pack_manager.mode("creation" if creation else "") == "world-pacific"
	var art := "pacific-ground" if pacific else "entry-ground" if creation else "club-forest"
	D.photo(banner,art,Rect2(1250,0,1310,height),.47 if pacific else 0.0)
	var fade := Control.new()
	banner.add_child(fade)
	D.place(fade,Rect2(0,0,1870,height))
	C.veil(fade)
	var divider := 236 if compact else 327
	D.photo(banner,"brand",Rect2(41,16,162,71) if compact else Rect2(41,34,252,110))
	D.line(banner,Vector2(divider,19 if compact else 35),Vector2(divider,height-(19 if compact else 39)),Color(C.GOLD,.75))
	D.text(banner,divider+38,34 if compact else 67,"VOTRE PREMIÈRE SAISON" if creation else "L’ATELIER DES IDENTITÉS",22 if compact else 24,C.GOLD,700,1040)
	D.text(banner,divider+36,80 if compact else 131,"Prendre les rênes" if creation else "Habiller votre rugby",44 if compact else 57,C.IVORY,700,1050)
	D.line(banner,Vector2(0,height-1),Vector2(2560,height-1),C.LINE)
	var inset := C.margin(38)
	inset.add_theme_constant_override("margin_top",C.px(6 if compact else 14))
	if compact: inset.add_theme_constant_override("margin_bottom",C.px(18))
	C.fill(inset,true)
	column.add_child(inset)
	inset.add_child(page)
	Legacy.apply(page,GREEN if not app.model.get("club") is Dictionary else app.accent)
	if size.x >= 2240 and size.y >= 1250:
		if creation: _career_context(app, page)
		else: _pack_guide(app, page)
	return column

static func _career_context(app: Control, page: Control) -> void:
	var choices := page.find_child("CreationClubsScroll", true, false) as ScrollContainer
	if choices == null: return
	var meta: Dictionary = app.model.get("meta", {})
	var mode: String = app.pack_manager.mode("creation")
	var catalogue_key: String = {"world": "worldCatalogue", "world-pacific": "pacificCatalogue"}.get(mode, "legacyCatalogue")
	var catalogue: Array = meta.get(catalogue_key, app.catalogue)
	var selected := {}
	for club: Dictionary in catalogue:
		if int(club.id) == app.selected_club:
			selected = club
			break
	if selected.is_empty(): return
	var context := C.v(8)
	context.name = "EntryCareerContext"
	var heading := C.wrap("VOTRE CARNET · " + G.club_name(selected), 24, C.GOLD, true, 700)
	heading.name = "EntrySelectedClub"
	context.add_child(heading)
	var tiles := C.h(12)
	context.add_child(tiles)
	var division := str(selected.get("division", ""))
	var rivals := catalogue.filter(func(club: Dictionary): return club.get("playable", true) and str(club.get("division", "")) == division).size()
	var ground := str(selected.get("stadium", ""))
	var objective := str(selected.get("goal", ""))
	_tile(tiles, "01  ·  PROJET SPORTIF", "Votre feuille de route", objective if not objective.is_empty() else "Consultez les objectifs du club dans le Bureau après la prise de poste.", "training-session", C.MINT)
	_tile(tiles, "02  ·  TERRAIN", "Jouer à domicile", ground if not ground.is_empty() else "Retrouvez les installations du club dans le carnet de carrière.", "entry-ground", C.GOLD)
	_tile(tiles, "03  ·  COMPÉTITION", Club.competition_name(division), "%s clubs jouables dans cette division" % G.n(rivals), "trophy", C.BLUE)
	var column := choices.get_parent()
	column.add_child(context)
	column.move_child(context, choices.get_index() + 1)

static func _pack_guide(app: Control, page: Control) -> void:
	if not app.pack_manager.installed().is_empty() or not app.pack_manager.preview().is_empty(): return
	for node in page.find_children("*", "Button", true, false):
		var importer := node as Button
		if not importer.pressed.is_connected(app.pack_manager.choose_file): continue
		var content := importer.get_parent().get_parent()
		for child in content.get_children():
			if child is ScrollContainer:
				var guide := C.v(10)
				guide.name = "EntryPackGuide"
				child.get_child(0).add_child(guide)
				guide.add_child(C.label("LE PARCOURS D’IMPORT", 24, C.GOLD, true, 700))
				var tiles := C.h(14)
				guide.add_child(tiles)
				_tile(tiles, "01  ·  FICHIER", "Ouvrir le ZIP", "Choisissez le fichier du pack sur votre ordinateur.", "scouting", C.BLUE)
				_tile(tiles, "02  ·  APERÇU", "Vérifier les identités", "Vérifiez les noms, blasons et portraits recensés dans l’aperçu.", "approved-club-crest", C.GOLD, false)
				_tile(tiles, "03  ·  SÉLECTION", "Habiller votre carrière", "Installez le pack, puis sélectionnez-le dans l’édition affichée.", "player-hero", C.MINT, true, .12)
				guide.add_child(C.wrap("Blason et portrait d’exemple · illustrations fictives", 17, C.MUTED))
				return

static func _tile(parent: HBoxContainer, label: String, title: String, copy: String, art: String, tint: Color, cover: bool = true, focus: float = .29) -> void:
	var frame := C.card()
	C.fill(frame)
	parent.add_child(frame)
	var content := C.content(frame)
	content.add_child(C.photo(art, Vector2(0, 133), cover, focus))
	content.add_child(C.label(label, 18, tint, true, 700))
	content.add_child(C.wrap(title, 26, C.IVORY, true, 700))
	content.add_child(C.wrap(copy, 17, C.MUTED))
