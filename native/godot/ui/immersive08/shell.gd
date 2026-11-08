extends RefCounted
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Office = preload("res://ui/immersive08/office.gd")
const OfficeCanvas = preload("res://ui/immersive08/office_canvas.gd")
const SquadCanvas = preload("res://ui/immersive08/squad_canvas.gd")
const TacticsCanvas = preload("res://ui/immersive08/tactics_canvas.gd")
const PlayerCanvas = preload("res://ui/immersive08/player_canvas.gd")
const Reception = preload("res://ui/immersive08/reception_canvas.gd")
const G = preload("res://ui/game_skin.gd")
const D = preload("res://ui/immersive08/primitives.gd")

const GROUPS = [
	["Bureau", "Bureau", ["Bureau"]],
	["Effectif", "Effectif", ["Effectif", "Vestiaire"]],
	["Tactique", "Composition", ["Composition", "Préparation", "Plan de jeu", "Match"]],
	["Recrutement", "Recrutement", ["Recrutement"]],
	["Club", "Club", ["Club", "Staff", "Travail du club", "Stratégie"]],
	["Finances", "Finances", ["Finances"]],
	["Compétitions", "Classements", ["Classements", "Calendrier", "Presse", "Rivalités"]],
	["Formation", "Formation", ["Formation", "Centre"]],
	["Carrière", "Carrière", ["Carrière"]]
]
const TITLES = {"Bureau":"Votre semaine commence ici.", "Effectif":"Les hommes du projet.", "Composition":"Le XV de départ.", "Préparation":"La semaine se gagne ici.", "Plan de jeu":"Votre identité de jeu.", "Vestiaire":"Un groupe, une ambition.", "Recrutement":"Le prochain renfort.", "Club":"Un club. Un territoire.", "Finances":"Garder une longueur d’avance.", "Classements":"Chaque point compte.", "Calendrier":"Le fil de votre saison.", "Formation":"Le futur porte nos couleurs.", "Centre":"Les chemins de la progression.", "Staff":"Le collectif derrière le collectif.", "Travail du club":"Des décisions qui engagent.", "Stratégie":"Construire dans la durée.", "Presse":"La voix du club.", "Rivalités":"Votre place dans le rugby.", "Carrière":"Une carrière à écrire.", "Match":"Le jour de match."}

static func render(app: Control) -> bool:
	if not app.model.get("club") is Dictionary or app.route in ["Accueil", "Création", "Packs"]: return false
	var window := app.get_window()
	var physical := window.size
	# Une scène se construit aux pixels de la fenêtre. Les changements de taille
	# suivants ajustent son emprise sans détruire les contrôles ni les brouillons.
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if physical.x >= 1280 and physical.y >= 720:
		window.content_scale_size = physical
	C.configure(minf(physical.y,1440),minf(physical.x,2560))
	if app.selected_player.is_empty():app.set_meta("immersive08_full_player",false)
	if is_instance_valid(app.root_content):
		app.remove_child(app.root_content)
		app.root_content.queue_free()
	app.match_screen = null
	app.match_page = null
	app.match_view = null
	app.entry_scroll = null
	app.root_content = Control.new()
	app.root_content.name = "ImmersiveShell"
	app.root_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_child(app.root_content)
	app.move_child(app.root_content, 0)
	var background := ColorRect.new()
	background.color = C.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.root_content.add_child(background)
	var layout := Control.new()
	layout.name = "ImmersiveLayout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.root_content.add_child(layout)
	var reference := Vector2(2560,1440)*C.density
	_fit_layout(app.root_content,layout,reference)
	app.root_content.resized.connect(_fit_layout.bind(app.root_content,layout,reference))
	var shell := C.h(0)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_child(shell)
	_sidebar(shell, app)
	var workspace := C.v(0)
	C.fill(workspace, true)
	shell.add_child(workspace)
	_topbar(workspace, app)
	var inset := C.margin(32)
	app.workspace_inset = inset
	inset.add_theme_constant_override("margin_top", C.px(22))
	inset.item_rect_changed.connect(app._layout_coach)
	C.fill(inset, true)
	workspace.add_child(inset)
	var content := C.v(16)
	content.name = "CareerContent"
	inset.add_child(content)
	if app.route=="Effectif" and app.get_meta("immersive08_full_player",false):
		app.minibar=C.label("",17,C.GOLD);app.minibar.visible=false;content.add_child(app.minibar)
	else:_heading(content, app)
	app.PackViews.missing_warning(app,content,"career")
	_subnavigation(content, app)
	app.body_scroll = ScrollContainer.new()
	app.body_scroll.name = "CareerWorkspace"
	app.body_scroll.follow_focus = true
	app.body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	C.fill(app.body_scroll, true)
	content.add_child(app.body_scroll)
	app.body = C.v(16)
	C.fill(app.body, true)
	app.body_scroll.add_child(app.body)
	if app.route == "Bureau": app.body.add_child(OfficeCanvas.build(app) if physical.x >= 1600 else Office.build(app))
	else: _existing_page(app)
	_footer(content, app)
	app._update_live_bar()
	app.call_deferred("_refresh_coach")
	app.call_deferred("_observe_navigation")
	return true

static func _fit_layout(root: Control, layout: Control, reference: Vector2) -> void:
	if root.size.x<=0 or root.size.y<=0: return
	var factor := minf(root.size.x/reference.x, root.size.y/reference.y)
	layout.scale = Vector2.ONE*factor
	layout.size = root.size/factor

static func _sidebar(parent: Node, app: Control) -> void:
	var rail:=Control.new();rail.name="ImmersiveSidebar";rail.custom_minimum_size.x=C.px(248);rail.size_flags_vertical=Control.SIZE_EXPAND_FILL
	parent.add_child(rail)
	var height:float=app.get_window().size.y/C.density
	var background:=D.rect(rail,Rect2(0,0,248,height),Color("081b16"))
	background.add_theme_stylebox_override("panel",D.surface(248,height,Color("081b16"),Color("071d18"),Color.TRANSPARENT,0,false))
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var border:=D.line(rail,Vector2(247,0),Vector2(247,height))
	border.set_anchor(SIDE_BOTTOM,1,false)
	border.offset_bottom=0
	var logo:=D.button(rail,Rect2(17,20,214,93),"",app.pause_menu,false,"",false,app.accent,"ImmersiveMainMenu")
	logo.tooltip_text="Menu, sauvegardes et paramètres"
	logo.add_theme_stylebox_override("normal",C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,0))
	var bitmap:=C.photo("brand",Vector2.ZERO,false);logo.add_child(bitmap);D.place(bitmap,Rect2(0,0,214,93))
	D.line(rail,Vector2(24,128),Vector2(224,128),Color(C.GOLD,.55))
	var crest:=G.crest(app.model.club,C.px(126));rail.add_child(crest);D.place(crest,Rect2(61,151,126,147))
	D.text(rail,124,331,G.club_name(app.model.club).to_upper(),23,C.IVORY,700,222,HORIZONTAL_ALIGNMENT_CENTER)
	D.text(rail,124,354,"SAISON "+G.n(app.model.meta.get("season",1)),16,C.GOLD,500,215,HORIZONTAL_ALIGNMENT_CENTER)
	var names:Array=[["home","Bureau","Bureau"],["mail","Réception","Réception"],["people","Effectif","Effectif"],["tactic","Tactique","Composition"],["train","Entraînement","Préparation"],["search","Recrutement","Recrutement"],["shield","Club","Club"],["money","Finances","Finances"],["trophy","Compétitions","Classements"],["school","Formation","Formation"]]
	for i in names.size():
		var entry:Array=names[i]
		var destination:String=entry[2]
		var selected:bool=app.route==destination
		if i==3:selected=app.route in ["Composition","Plan de jeu"]
		if i==6:selected=app.route in ["Club","Staff","Travail du club","Stratégie"]
		if i==8:selected=app.route in ["Classements","Calendrier","Presse","Rivalités"]
		if i==9:selected=app.route in ["Formation","Centre"]
		var y:=394+i*57
		var action:=D.button(rail,Rect2(7,y,234,49),entry[1],func():
			if destination=="Préparation":
				if not app.management_ui.get("preparation") is Dictionary:app.management_ui.preparation={"tab":2,"outer":[0,0,0],"attack":0,"defense":0,"focus":["","",""]}
				else:app.management_ui.preparation.tab=2
			app._navigate(destination),selected,"",false,app.accent,"Nav_"+entry[1])
		action.add_theme_font_override("font",C.DISPLAY);action.add_theme_font_size_override("font_size",maxi(12,C.px(26)))
		var style:StyleBox=action.get_theme_stylebox("normal").duplicate() if selected else C.box(Color.TRANSPARENT,Color.TRANSPARENT,4,0)
		style.content_margin_left=C.px(58);action.add_theme_stylebox_override("normal",style)
		for state in ["hover","pressed","disabled"]:
			var alternate:StyleBox=action.get_theme_stylebox(state).duplicate();alternate.content_margin_left=C.px(58);action.add_theme_stylebox_override(state,alternate)
		if selected:D.rect(rail,Rect2(7,y,4,49),C.MINT)
		var symbol:=C.icon(entry[0],25,C.IVORY if selected else Color("c8d0c6"));rail.add_child(symbol);D.place(symbol,Rect2(23,y+12,25,25))
		var unread: int = Reception.unread(app) if i==1 else 0
		if unread>0:
			D.rect(rail,Rect2(207,y+13,24,24),C.GOLD,4)
			D.text(rail,219,y+31,unread,18,Color("101511"),700,24,HORIZONTAL_ALIGNMENT_CENTER)
	var dock:=Control.new()
	dock.mouse_filter=Control.MOUSE_FILTER_IGNORE
	rail.add_child(dock)
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top=-C.px(295)
	D.photo(dock,"forest",Rect2(0,109,247,158))
	D.rect(dock,Rect2(0,45,247,94),Color("0c1717"))
	D.line(dock,Vector2(22,45),Vector2(226,45))
	for i in 3:
		var caption:String=["Carrière","Réglages","Sauvegarder"][i]
		var y:float=[0,58,100][i]
		var action:=D.button(dock,Rect2(12,y,224,38),caption,func():
			if i==0:app._navigate("Carrière")
			elif i==1:app.settings()
			else:app._command("save"),false,"",false,app.accent,"ImmersiveSidebarAction"+str(i))
		var style:=C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,0);style.content_margin_left=C.px(53);action.add_theme_stylebox_override("normal",style)
		action.add_theme_font_override("font",C.DISPLAY);action.add_theme_font_size_override("font_size",maxi(12,C.px(23)));action.add_theme_color_override("font_color",C.MUTED)
		var symbol:=C.icon(["flag","settings","save"][i],24,C.MUTED);dock.add_child(symbol);D.place(symbol,Rect2(23,y+10,24,24))
	D.rect(dock,Rect2(0,220,247,75),Color("0b1614"))
	D.rect(dock,Rect2(21,245,8,8),C.ALERT if app._status_has_error() else C.MINT,4)
	D.text(dock,39,255,"Stockage à vérifier" if app._status_has_error() else "Sauvegarde automatique",17,C.MUTED,500,198)
	D.text(dock,24,281,G.club_abbr(app.model.club)+" · Carrière principale",17,C.FAINT,500,210)

static func _topbar(parent: Node, app: Control) -> void:
	var panel := Control.new()
	panel.name = "ImmersiveTopbar"
	panel.custom_minimum_size.y = C.px(78)
	C.fill(panel)
	parent.add_child(panel)
	D.rect(panel,Rect2(0,0,2312,78),Color("0e1618"))
	D.line(panel,Vector2(0,77),Vector2(2312,77))
	var home := C.icon("home",25,C.IVORY)
	panel.add_child(home)
	D.place(home,Rect2(34,24,25,25))
	D.text(panel,77,48,"›",26,C.MUTED)
	D.text(panel,103,48,G.club_name(app.model.club),24,C.MUTED,500,170)
	D.text(panel,278,48,"›",26,C.MUTED)
	var route_caption:String="Tactique" if app.route=="Composition" else app.route
	if app.route=="Effectif" and app.get_meta("immersive08_full_player",false):route_caption="Fiche joueur : "+str(P.player(app.model,app.selected_player).get("name",""))
	D.text(panel,307,48,route_caption,25,C.IVORY,700,660)
	var search := D.button(panel,Rect2(1264,19,475,42),"Rechercher un joueur, un club…",func():app.navigation_controller.open_palette(),false,"",true,app.accent,"ImmersiveSearch")
	search.add_theme_font_override("font",C.BODY)
	search.add_theme_font_size_override("font_size",maxi(12,C.px(18)))
	search.add_theme_color_override("font_color",C.MUTED)
	var search_style := search.get_theme_stylebox("normal").duplicate()
	search_style.content_margin_left=C.px(48)
	search_style.content_margin_right=C.px(70)
	search.add_theme_stylebox_override("normal",search_style)
	var magnifier := C.icon("search",21,C.MUTED)
	panel.add_child(magnifier)
	D.place(magnifier,Rect2(1278,30,21,21))
	D.chip(panel,Rect2(1677,29,48,23),"Ctrl K",C.MUTED)
	var calendar := C.icon("calendar",25,C.IVORY)
	panel.add_child(calendar)
	D.place(calendar,Rect2(1773,25,25,25))
	app.header_date = D.text(panel,1814,48,"",24,C.IVORY,600,240)
	app._update_header_date()
	app.primary_button = D.button(panel,Rect2(2067,17,211,45),"Continuer",app.primary_action,true,"arrow",false,app.accent,"ImmersiveContinue")
	app.primary_button.tooltip_text = app.primary_text()

static func _heading(parent: Node, app: Control) -> void:
	var row := Control.new()
	row.custom_minimum_size.y = C.px(91 if app.route=="Effectif" else 88 if app.route=="Composition" else 104)
	C.fill(row)
	parent.add_child(row)
	if app.route=="Réception":
		app.heading=Reception.heading(row,app)
		app.minibar=C.label("",17,C.GOLD)
		app.minibar.visible=false
		parent.add_child(app.minibar)
		return
	D.text(row,1,19,{"Bureau":"LE BUREAU","Effectif":"LE GROUPE PROFESSIONNEL","Composition":"LE PLAN DE JEU"}.get(app.route,app.route.to_upper()),19,C.GOLD,600,1040)
	app.heading = D.text(row,-1,76,TITLES.get(app.route,app.route),53,C.IVORY,700,1190)
	var values := P.group(app.model)
	var rank := G.n(app.model.club.get("rank", "—"))
	var metrics: Array = [[rank+("er" if rank=="1" else "e")+" · "+G.n(app.model.club.get("points",0))+" pts","trophy",C.GOLD],[str(values.available)+" disponibles","people",C.MINT],[str(values.injured)+" blessés","heart",C.ALERT],["3 décisions","calendar",C.AMBER]]
	if app.route=="Effectif": metrics=[[str(values.total)+" joueurs","people",C.GOLD],metrics[1],metrics[2],["Niveau moyen "+str(values.rating),"star",C.GOLD]]
	if app.route=="Composition":
		var selected:int=app.model.get("selection",{}).get("slots",[]).filter(func(slot:Dictionary):return slot.get("playerId")!=null).size()
		D.chip(row,Rect2(1140,21,288,48),str(selected)+" joueurs sélectionnés",C.MINT)
		D.chip(row,Rect2(1444,21,241,48),"Composition valide" if app.model.get("selection",{}).get("valid",false) else "À compléter",C.MINT if app.model.get("selection",{}).get("valid",false) else C.AMBER)
		D.button(row,Rect2(1703,21,248,48),"Enregistrer le plan",func():app._command("save"),false,"save",true,app.accent,"TacticsSave")
		D.button(row,Rect2(1967,21,281,48),"Valider les 23",func():TacticsCanvas.validate(app),true,"arrow",false,app.accent,"TacticsValidate")
		metrics=[]
	if app.get_window().size.x >= 1600:
		for i in metrics.size():
			var item: Array = metrics[i]
			if app.route=="Effectif":
				D.chip(row,Rect2(1242+i*253,19,241,51),item[0],C.IVORY if i==0 else item[2])
				continue
			var x := 1236+i*255
			D.rect(row,Rect2(x,13,243,63),Color("13201d"),7,Color(item[2],.7))
			var symbol := C.icon(item[1],25,item[2])
			row.add_child(symbol)
			D.place(symbol,Rect2(x+16,32,25,25))
			D.text(row,x+53,54,item[0],25,item[2],600,179)
	app.minibar = C.label("", 17, C.GOLD)
	app.minibar.visible = false
	parent.add_child(app.minibar)

static func _subnavigation(parent: Node, app: Control) -> void:
	if app.route in ["Effectif","Composition"]: return
	for group: Array in GROUPS:
		if app.route not in group[2] or group[2].size() < 2: continue
		var row := C.h(8)
		row.name = "ChapterSubnavigation"
		parent.add_child(row)
		for destination: String in group[2]:
			var action := C.button(destination.to_upper(), func(): app._navigate(destination), app.route == destination, app.accent)
			action.name = "Section_" + destination
			action.custom_minimum_size.y = C.px(38)
			C.fill(action)
			row.add_child(action)
		return

static func _footer(parent: Node, app: Control) -> void:
	var row := Control.new()
	row.custom_minimum_size.y = C.px(44)
	C.fill(row)
	parent.add_child(row)
	D.line(row,Vector2.ZERO,Vector2(2248,0),Color(C.LINE,.7))
	app.status = D.text(row,2,36,app._settled_status_text(),17,C.ALERT if app._status_has_error() else C.MUTED,500,900)
	if app.get_window().size.x>=1900: D.text(row,782,36,"Ctrl S  Sauvegarder     ·     Ctrl K  Rechercher     ·     F1  Aide",17,C.FAINT,400,800,HORIZONTAL_ALIGNMENT_LEFT,true)
	if app.decision_feedback != null:
		var feedback: Control = app.decision_feedback.control()
		row.add_child(feedback)
		D.place(feedback,Rect2(1900,9,180,34))
	var dock := Control.new()
	dock.name = "CoachCompactDock"
	dock.custom_minimum_size = Vector2(C.px(144), C.px(34))
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.visible = is_instance_valid(app.coach)
	row.add_child(dock)
	D.place(dock,Rect2(2104,9,144,34))

static func _existing_page(app: Control) -> void:
	match app.route:
		"Réception": app.body.add_child(Reception.build(app))
		"Club": app.body.add_child(app.ClubViews.club(app))
		"Calendrier": app.body.add_child(app.ClubViews.calendar(app))
		"Classements": app.body.add_child(app.ClubViews.tables(app))
		"Finances": app.body.add_child(app.ClubViews.finance(app))
		"Effectif":
			var player:=P.player(app.model,app.selected_player)
			if app.get_meta("immersive08_full_player",false) and not player.is_empty():app.body.add_child(PlayerCanvas.build(app,player))
			else:app.body.add_child(SquadCanvas.build(app) if app.get_window().size.x>=1600 else app.SquadViews.squad(app))
		"Composition": app.body.add_child(TacticsCanvas.build(app) if app.get_window().size.x>=1600 else app.SquadViews.lineup(app))
		"Préparation": app.body.add_child(app.SquadViews.preparation(app))
		"Plan de jeu": app.body.add_child(app.PlaybookViews.build(app))
		"Recrutement": app.body.add_child(app.SquadViews.market(app))
		"Staff": app.body.add_child(app.StaffViews.build(app))
		"Formation": app.body.add_child(app.DevelopmentViews.build(app))
		"Presse": app.body.add_child(app.PressViews.build(app))
		"Vestiaire": app.body.add_child(app.RelationshipsViews.build(app))
		"Rivalités": app.body.add_child(app.WorldViews.build(app))
		"Stratégie": app.body.add_child(app.StrategyViews.build(app))
		"Centre": app.body.add_child(app.AcademyViews.build(app))
		"Travail du club": app.body.add_child(app.SupportViews.build(app))
		"Carrière": app.body.add_child(app.ManagerCareerViews.build(app))
		"Match":
			app.match_screen = app.MatchUI.new()
			app.match_screen.app = app
			app.body.add_child(app.match_screen)
			app.match_page = app.match_screen
			app.match_screen.update_frame(app.model)
