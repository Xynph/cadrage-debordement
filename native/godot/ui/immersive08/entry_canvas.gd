extends RefCounted
## Les seuils de la carrière partagent la DA des menus et les actions existantes.
const C = preload("res://ui/immersive08/components.gd")
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
	if not app.catalogue.is_empty():
		D.chip(content,Rect2(112,895,249,52),"%d clubs jouables" % app.catalogue.size(),C.GOLD)
	if int(database.get("playerCount",0))>0:
		D.chip(content,Rect2(375,895,288,52),G.n(database.playerCount)+" joueurs de base",C.MINT)
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
	var column := C.v(14)
	column.name = "ImmersiveCreationWorkspace" if creation else "ImmersiveIdentityWorkspace"
	var banner := Control.new()
	banner.custom_minimum_size.y = C.px(186)
	column.add_child(banner)
	D.rect(banner,Rect2(0,0,2560,186),C.PANEL)
	D.photo(banner,"entry-ground" if creation else "club-forest",Rect2(1250,0,1310,186))
	var fade := Control.new()
	banner.add_child(fade)
	D.place(fade,Rect2(0,0,1870,186))
	C.veil(fade)
	D.photo(banner,"brand",Rect2(41,34,252,110))
	D.line(banner,Vector2(327,35),Vector2(327,147),Color(C.GOLD,.75))
	D.text(banner,365,67,"VOTRE PREMIÈRE SAISON" if creation else "L’ATELIER DES IDENTITÉS",24,C.GOLD,700,1040)
	D.text(banner,363,131,"Prendre les rênes" if creation else "Habiller votre rugby",57,C.IVORY,700,1050)
	D.line(banner,Vector2(0,185),Vector2(2560,185),C.LINE)
	var inset := C.margin(38)
	inset.add_theme_constant_override("margin_top",C.px(14))
	C.fill(inset,true)
	column.add_child(inset)
	inset.add_child(page)
	Legacy.apply(page,GREEN if not app.model.get("club") is Dictionary else app.accent)
	return column
