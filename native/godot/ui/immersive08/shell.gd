extends RefCounted
const CLUB_CHROME := Color("11191e")
const C = preload("res://ui/immersive08/components.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Office = preload("res://ui/immersive08/office.gd")
const OfficeCanvas = preload("res://ui/immersive08/office_canvas.gd")
const SquadCanvas = preload("res://ui/immersive08/squad_canvas.gd")
const TacticsCanvas = preload("res://ui/immersive08/tactics_canvas.gd")
const PlayerCanvas = preload("res://ui/immersive08/player_canvas.gd")
const Reception = preload("res://ui/immersive08/reception_canvas.gd")
const Training = preload("res://ui/immersive08/training_canvas.gd")
const Academy = preload("res://ui/immersive08/academy_canvas.gd")
const Recruitment = preload("res://ui/immersive08/recruitment_canvas.gd")
const Competition = preload("res://ui/immersive08/competition_canvas.gd")
const MonthCalendar = preload("res://ui/immersive08/month_calendar.gd")
const ClubCanvas = preload("res://ui/immersive08/club_canvas.gd")
const FinanceCanvas = preload("res://ui/immersive08/finance_canvas.gd")
const Preparation = preload("res://ui/immersive08/preparation_canvas.gd")
const Playbook = preload("res://ui/immersive08/playbook_canvas.gd")
const Centre = preload("res://ui/immersive08/centre_canvas.gd")
const Press = preload("res://ui/immersive08/press_canvas.gd")
const Rivalry = preload("res://ui/immersive08/rivalry_canvas.gd")
const Locker = preload("res://ui/immersive08/locker_canvas.gd")
const Career = preload("res://ui/immersive08/career_canvas.gd")
const Selections = preload("res://ui/international_view.gd")
const MatchCanvas = preload("res://ui/immersive08/match_canvas.gd")
const MatchCompact = preload("res://ui/immersive08/match_compact.gd")
const G = preload("res://ui/game_skin.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const TACTICS_CANVAS_MIN_WIDTH := 1600

const FOOTER_RISE := 14
const TOPBAR_ACTION_LEFT := 2067
const TOPBAR_MATCH_ACTION_LEFT := 2008

const GROUPS = [
	["Bureau", "Bureau", ["Bureau"]],
	["Effectif", "Effectif", ["Effectif", "Vestiaire"]],
	["Tactique", "Composition", ["Composition", "Préparation", "Plan de jeu", "Match"]],
	["Recrutement", "Recrutement", ["Recrutement"]],
	["Club", "Club", ["Club", "Staff", "Travail du club", "Stratégie"]],
	["Finances", "Finances", ["Finances"]],
	["Compétitions", "Classements", ["Classements", "Calendrier", "Rivalités"]],
	["Formation", "Formation", ["Formation", "Centre"]],
	["Carrière", "Carrière", ["Carrière"]]
]
const TITLES = {"Bureau":"Votre semaine commence ici.", "Effectif":"Les hommes du projet.", "Composition":"Le XV de départ.", "Préparation":"La semaine se gagne ici.", "Plan de jeu":"Votre identité de jeu.", "Vestiaire":"Un groupe, une ambition.", "Recrutement":"Le prochain renfort.", "Club":"Un club. Un territoire.", "Finances":"Garder une longueur d’avance.", "Classements":"Chaque point compte.", "Calendrier":"Le fil de votre saison.", "Formation":"Le futur porte nos couleurs.", "Centre":"Les chemins de la progression.", "Staff":"Le collectif derrière le collectif.", "Travail du club":"Des décisions qui engagent.", "Stratégie":"Construire dans la durée.", "Presse":"La voix du club.", "Rivalités":"Votre place dans le rugby.", "Carrière":"Une carrière à écrire.", "Match":"Le jour de match."}
const COMPACT_ART = {
	"Finances":"finance-hospitality", "Calendrier":"stadium", "Formation":"academy-training",
	"Plan de jeu":"lineout-analysis", "Centre":"academy-training", "Préparation":"analysis-room",
	"Recrutement":"scouting", "Classements":"trophy", "Club":"club-forest", "Staff":"mail-staff",
	"Travail du club":"analysis-room", "Stratégie":"club-forest", "Presse":"press-room",
	"Rivalités":"trophy", "Vestiaire":"lockerroom", "Carrière":"entry-ground",
}

const COMPACT_SCENARIO_ART := {
	"Club": "treadmill", "Presse": "camera", "Vestiaire": "sneaker", "Formation": "chair",
}

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
	_topbar(workspace, app, layout)
	var inset := C.margin(32)
	app.workspace_inset = inset
	inset.add_theme_constant_override("margin_top", C.px(22))
	inset.item_rect_changed.connect(app._layout_coach)
	C.fill(inset, true)
	workspace.add_child(inset)
	var content := C.v(16)
	content.name = "CareerContent"
	inset.add_child(content)
	var canvas_script := _dedicated_page(app,physical)
	var immersive_match: bool = app.route=="Match" and physical.x>=1920 and physical.y>=1080
	var monthly_calendar: bool = app.route=="Calendrier" and not app.get_meta("calendar_table",false)
	if canvas_script!=null or immersive_match or monthly_calendar or (app.route=="Effectif" and app.get_meta("immersive08_full_player",false)):
		app.heading=null
		app.minibar=C.label("",17,C.GOLD);app.minibar.visible=false;content.add_child(app.minibar)
	else: _heading(content, app)
	if app.route=="Bureau":
		layout.set_meta("immersive_office_match_status",app.minibar)
		_position_office_match_status(app.minibar,layout.scale.y)
	_pack_warning(app,content,layout)
	if canvas_script==null and not immersive_match: _subnavigation(content, app)
	app.body_scroll = ScrollContainer.new()
	app.body_scroll.name = "CareerWorkspace"
	app.body_scroll.follow_focus = true
	app.body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	C.fill(app.body_scroll, true)
	content.add_child(app.body_scroll)
	app.body = C.v(16)
	C.fill(app.body, true)
	app.body_scroll.add_child(app.body)
	if canvas_script!=null:
		var canvas := Control.new()
		canvas.custom_minimum_size=Vector2(2248,1244)*C.density
		C.fill(canvas,true)
		app.body.add_child(canvas)
		canvas_script.build(app,canvas)
		if app.route == "Calendrier":
			D.button(canvas,Rect2(1830,147,395,40),"Vue mensuelle",_calendar_table.bind(app,false),false,"calendar",true,app.accent,"CalendarShowMonth")
	elif app.route == "Bureau": app.body.add_child(OfficeCanvas.build(app) if physical.x >= 1600 else Office.build(app))
	else: _existing_page(app,immersive_match)
	_footer(content, app, layout)
	app._update_live_bar()
	app.call_deferred("_refresh_coach")
	app.call_deferred("_observe_navigation")
	return true

static func _fit_layout(root: Control, layout: Control, reference: Vector2) -> void:
	if root.size.x<=0 or root.size.y<=0: return
	var factor := minf(root.size.x/reference.x, root.size.y/reference.y)
	var base_footer := C.px(44)
	if base_footer*factor<38.0 and root.size.y>38.0:
		factor=minf(factor,(root.size.y-38.0)/(reference.y-base_footer))
	layout.scale = Vector2.ONE*factor
	layout.size = root.size/factor
	if layout.has_meta("immersive_footer"):
		var footer: Control = layout.get_meta("immersive_footer")
		footer.custom_minimum_size.y=maxf(base_footer,38.0/factor)
		_position_footer(footer)
	if layout.has_meta("immersive_topbar"):
		_position_topbar(layout)
	if layout.has_meta("immersive_office_match_status"):
		var match_status: Label = layout.get_meta("immersive_office_match_status")
		_position_office_match_status(match_status,factor)
		_sync_office_props(match_status)
	if layout.has_meta("immersive_pack_warning"):
		_fit_pack_warning(layout.get_meta("immersive_pack_warning"),factor)

static func _pack_warning(app: Control, parent: Container, layout: Control) -> void:
	var row := C.h(16)
	app.PackViews.missing_warning(app,row,"career")
	if row.get_child_count()==0:
		row.free()
		return
	var banner := PanelContainer.new()
	banner.name = "ImmersivePackWarning"
	banner.add_theme_stylebox_override("panel",C.box(C.RAISED,C.ALERT,5,8))
	parent.add_child(banner)
	banner.add_child(row)
	Legacy.apply(row,app.accent)
	for child in row.get_children():
		if child is Control: child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if child is Label:
			C.fill(child)
			child.add_theme_color_override("font_color",C.ALERT)
	layout.set_meta("immersive_pack_warning",row)
	_fit_pack_warning(row,layout.scale.y)

static func _fit_pack_warning(row: HBoxContainer, factor: float) -> void:
	var minimum_font := ceili(14.0/factor)
	for child in row.get_children():
		if child is Label:
			child.add_theme_font_size_override("font_size",maxi(C.px(20),minimum_font))
		elif child is Button:
			child.add_theme_font_size_override("font_size",maxi(C.px(22),minimum_font))
			child.custom_minimum_size.y = maxf(C.px(44),36.0/factor)
			var focus := child.get_theme_stylebox("focus") as StyleBoxFlat
			if focus!=null: focus.set_border_width_all(maxi(2,ceili(2.0/factor)))

static func _is_training(app: Control) -> bool:
	return app.route=="Préparation" and app.management_ui.get("preparation",{}).get("tab",0)==2

static func open_training(app: Control) -> void:
	open_preparation(app,2)

static func open_preparation(app: Control, tab: int) -> void:
	if not app.management_ui.get("preparation") is Dictionary:
		app.management_ui.preparation={"tab":tab,"outer":[0,0,0],"attack":0,"defense":0,"focus":["","",""]}
	else: app.management_ui.preparation.tab=tab
	app._navigate("Préparation",true,true)

static func _dedicated_page(app: Control, size: Vector2i) -> Script:
	if app.route == "Calendrier" and not app.get_meta("calendar_table",false): return null
	if app.route=="Calendrier" and size.x>=1280 and size.y>=720 and app.model.meta.get("leagueId") in ["nationale","champ"]: return Competition
	if size.x<1920 or size.y<1080:
		return Rivalry if app.route=="Rivalités" and size.x>=1280 and size.y>=720 else null
	if _is_training(app): return Training
	match app.route:
		"Préparation": return Preparation
		"Plan de jeu": return Playbook
		"Formation": return Academy
		"Centre": return Centre
		"Recrutement": return Recruitment
		"Classements", "Calendrier": return Competition
		"Presse": return Press
		"Rivalités": return Rivalry
		"Club", "Staff", "Travail du club", "Stratégie": return ClubCanvas
		"Finances": return FinanceCanvas
		"Vestiaire": return Locker
		"Carrière": return Career
	return null

static func _sidebar(parent: Node, app: Control) -> void:
	var rail:=Control.new();rail.name="ImmersiveSidebar";rail.custom_minimum_size.x=C.px(248);rail.size_flags_vertical=Control.SIZE_EXPAND_FILL
	parent.add_child(rail)
	var height:float=app.get_window().size.y/C.density
	var club_accent: Color = app.accent
	var club_edge := club_accent.lightened(.38)
	var background:=D.rect(rail,Rect2(0,0,248,height),CLUB_CHROME)
	background.add_theme_stylebox_override("panel",D.surface(248,height,CLUB_CHROME.lerp(club_accent,.40),CLUB_CHROME,Color.TRANSPARENT,0,false))
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var border:=D.line(rail,Vector2(247,0),Vector2(247,height))
	border.set_anchor(SIDE_BOTTOM,1,false)
	border.offset_bottom=0
	var logo:=D.button(rail,Rect2(17,20,214,93),"",app.pause_menu,false,"",false,app.accent,"ImmersiveMainMenu")
	logo.tooltip_text="Menu, sauvegardes et paramètres"
	logo.add_theme_stylebox_override("normal",C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,0))
	var bitmap:=C.photo("brand",Vector2.ZERO,false);logo.add_child(bitmap);D.place(bitmap,Rect2(0,0,214,93))
	D.line(rail,Vector2(24,128),Vector2(224,128),Color(C.GOLD,.55))
	D.rect(rail,Rect2(18,143,212,224),CLUB_CHROME.lerp(club_accent,.24),12,Color(club_edge,.46))
	D.line(rail,Vector2(75,367),Vector2(173,367),club_edge,3)
	var crest:=G.crest(app.model.club,C.px(126));rail.add_child(crest);D.place(crest,Rect2(61,151,126,147))
	D.text(rail,124,331,G.club_name(app.model.club).to_upper(),23,C.IVORY,700,222,HORIZONTAL_ALIGNMENT_CENTER)
	D.text(rail,124,354,"SAISON "+G.n(app.model.meta.get("season",1)),16,C.GOLD,500,215,HORIZONTAL_ALIGNMENT_CENTER)
	var names:Array=[["mail","Réception","Réception"],["home","Bureau","Bureau"],["people","Effectif","Effectif"],["tactic","Tactique","Composition"],["train","Entraînement","Préparation"],["search","Recrutement","Recrutement"],["shield","Club","Club"],["money","Finances","Finances"],["trophy","Compétitions","Classements"],["school","Formation","Formation"]]
	if app.model.get("international") is Dictionary: names.append(["flag","Sélections","Sélections"])
	for i in names.size():
		var entry:Array=names[i]
		var destination:String=entry[2]
		var selected:bool=app.route==destination
		if i==2:selected=app.route in ["Effectif","Vestiaire"]
		if i==3:selected=app.route in ["Composition","Plan de jeu","Match"] or (app.route=="Préparation" and not _is_training(app))
		if i==4:selected=_is_training(app)
		if i==6:selected=app.route in ["Club","Staff","Travail du club","Stratégie"]
		if i==8:selected=app.route in ["Classements","Calendrier","Rivalités"]
		if i==9:selected=app.route in ["Formation","Centre"]
		var y:=394+i*57
		var action:=D.button(rail,Rect2(7,y,234,49),entry[1],func():
			if destination=="Préparation": open_training(app)
			else: app._navigate(destination),selected,"",false,app.accent,"Nav_"+entry[1])
		if selected: _club_button(action,CLUB_CHROME.lerp(club_accent,.46),club_edge)
		action.add_theme_font_override("font",C.DISPLAY);action.add_theme_font_size_override("font_size",maxi(12,C.px(26)))
		var style:StyleBox=action.get_theme_stylebox("normal").duplicate() if selected else C.box(Color.TRANSPARENT,Color.TRANSPARENT,4,0)
		style.content_margin_left=C.px(58);action.add_theme_stylebox_override("normal",style)
		for state in ["hover","pressed","disabled"]:
			var alternate:StyleBox=action.get_theme_stylebox(state).duplicate();alternate.content_margin_left=C.px(58);action.add_theme_stylebox_override(state,alternate)
		var focus := action.get_theme_stylebox("focus") as StyleBoxFlat
		focus.set_expand_margin_all(2)
		if selected:D.rect(rail,Rect2(7,y,4,49),club_edge)
		var symbol:=C.icon(entry[0],25,C.IVORY if selected else Color("c8d0c6"));rail.add_child(symbol);D.place(symbol,Rect2(23,y+12,25,25))
		var unread: int = Reception.unread(app) if destination=="Réception" else 0
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

static func _topbar(parent: Node, app: Control, layout: Control) -> void:
	var panel := Control.new()
	panel.name = "ImmersiveTopbar"
	panel.custom_minimum_size.y = C.px(78)
	C.fill(panel)
	parent.add_child(panel)
	D.rect(panel,Rect2(0,0,2312,78),Color("0e1618"))
	D.line(panel,Vector2(0,77),Vector2(2312,77))
	var club_edge: Color = app.accent.lightened(.38)
	D.line(panel,Vector2(33,76),Vector2(430,76),Color(club_edge,.83),2)
	var home := C.icon("home",25,C.IVORY)
	panel.add_child(home)
	D.place(home,Rect2(34,24,25,25))
	D.text(panel,77,48,"›",26,C.MUTED)
	var club_name := G.club_name(app.model.club)
	var name_width := clampf(C.MEDIUM.get_string_size(club_name,HORIZONTAL_ALIGNMENT_LEFT,-1,C.px(24)).x/C.density+8,170,320)
	D.text(panel,103,48,club_name,24,C.MUTED,500,name_width)
	D.text(panel,108+name_width,48,"›",26,C.MUTED)
	var route_caption:String="Tactique" if app.route=="Composition" else app.route
	if _is_training(app): route_caption="Entraînement"
	if app.route=="Effectif" and app.get_meta("immersive08_full_player",false):route_caption="Fiche joueur : "+str(P.player(app.model,app.selected_player).get("name",""))
	D.text(panel,137+name_width,48,route_caption,25,C.IVORY,700,660)
	var history: Control = app.navigation_controller.controls(false)
	panel.add_child(history)
	D.place(history,Rect2(1155,19,91,42))
	var office_live: bool = app.route=="Bureau" and not app._live().is_empty()
	var search_caption := "Rechercher un joueur, un menu…" if app.model.get("staff",{}).get("teams",[]).is_empty() else "Rechercher un joueur, un club…"
	var search := D.button(panel,Rect2(1264,19,380 if office_live else 475,42),"Rechercher…" if office_live else search_caption,func():app.navigation_controller.open_palette(),false,"",true,app.accent,"ImmersiveSearch")
	if office_live: search.tooltip_text = search_caption
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
	var shortcut := D.chip(panel,Rect2(1582 if office_live else 1677,29,48,23),"Ctrl K",C.MUTED)
	var calendar := C.button("", _open_current_calendar.bind(app))
	calendar.name = "ImmersiveCalendarDate"
	calendar.accessibility_name = "Ouvrir le calendrier"
	calendar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_child(calendar)
	var calendar_icon := C.icon("calendar",25,C.IVORY)
	calendar.add_child(calendar_icon)
	app.header_date = D.text(calendar,0,48,"",24,C.IVORY,600,240)
	app._update_header_date()
	var action_left := TOPBAR_MATCH_ACTION_LEFT if office_live else TOPBAR_ACTION_LEFT
	app.primary_button = D.button(panel,Rect2(action_left,17,2278-action_left,45),"Continuer",app.primary_action,true,"arrow",false,app.accent,"ImmersiveContinue")
	_club_button(app.primary_button,CLUB_CHROME.lerp(app.accent,.69),club_edge)
	app.primary_button.tooltip_text = app.primary_text()
	layout.set_meta("immersive_topbar",[app.header_date,app.primary_button,shortcut,calendar,action_left,calendar_icon])
	_position_topbar(layout)

static func _club_button(button: Button, fill: Color, edge: Color) -> void:
	for state in ["normal","hover","pressed"]:
		var previous := button.get_theme_stylebox(state)
		var color := fill.lightened(.07) if state == "hover" else fill.darkened(.1) if state == "pressed" else fill
		var style := C.box(C.readable_primary_fill(color),edge,5,0)
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
			style.set_content_margin(side,previous.get_content_margin(side))
		button.add_theme_stylebox_override(state,style)

static func _position_topbar(layout: Control) -> void:
	var factor := layout.scale.y
	if factor<=0: return
	var elements: Array = layout.get_meta("immersive_topbar")
	var date: Label = elements[0]
	var action: Button = elements[1]
	var compact := C.px(24)*factor<14.0
	# En petit format, les raccourcis sont regroupés dans le pied.
	elements[2].visible=not compact
	var calendar: Button = elements[3]
	var calendar_icon: TextureRect = elements[5]
	var date_px := maxi(C.px(24),ceili(14.0/factor))
	var date_font := date.get_theme_font("font")
	var action_left: int = elements[4]
	var office_live := action_left == TOPBAR_MATCH_ACTION_LEFT
	var icon_left := (1658 if compact else 1680) if office_live else (1753 if compact else 1773)
	var calendar_left := icon_left - 7
	var calendar_right := action_left - 13
	var height := maxf(45.0*C.density,26.0/factor)
	calendar.position = Vector2(C.px(calendar_left),(79.0*C.density-height)/2.0)
	calendar.size = Vector2(C.px(calendar_right-calendar_left),height)
	calendar_icon.position = Vector2(C.px(7),(height-calendar_icon.size.y)/2.0)
	var date_left := C.px(40)
	var text_height := date_font.get_height(date_px)
	date.add_theme_font_size_override("font_size",date_px)
	date.position = Vector2(date_left,(height-text_height)/2.0)
	date.set_deferred("size",Vector2(calendar.size.x-date_left-C.px(7),text_height))
	action.add_theme_font_size_override("font_size",maxi(C.px(25),ceili(14.0/factor)))
	action.position.y=(79.0*C.density-height)/2.0
	action.size.y=height

static func _position_office_match_status(status: Label, factor: float) -> void:
	if factor<=0: return
	status.add_theme_font_size_override("font_size",maxi(C.px(25),ceili(14.0/factor)))

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
	D.text(row,1,19,{"Bureau":"LE BUREAU","Effectif":"LE GROUPE PROFESSIONNEL","Composition":"LE PLAN DE JEU"}.get(app.route,app.route.to_upper()),19,app.accent.lightened(.48),600,1040)
	app.heading = D.text(row,-1,76,TITLES.get(app.route,app.route),53,C.IVORY,700,1190)
	if COMPACT_ART.has(app.route):
		var image := D.panel(row,Rect2(1438,6,810,89),"","","","CompactRouteArt")
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if app.route == "Finances":
			FinanceCanvas.hospitality(image, Rect2(2,2,806,85))
		else:
			D.photo(image,COMPACT_ART[app.route],Rect2(2,2,806,85),.16)
		if COMPACT_SCENARIO_ART.has(app.route):
			D.scenario_photo(image, COMPACT_SCENARIO_ART[app.route], Rect2(613, 3, 190, 83))
	var values := P.group(app.model)
	var rank := G.n(app.model.club.get("rank", "—"))
	var injury_count: int = values.injured
	var injury_caption := "%d blessé%s" % [injury_count, "s" if injury_count > 1 else ""]
	var metrics: Array = [[rank+("er" if rank=="1" else "e")+" · "+G.n(app.model.club.get("points",0))+" pts","trophy",C.GOLD],[str(values.available)+" disponibles","people",C.MINT],[injury_caption,"heart",C.ALERT if injury_count > 0 else C.MUTED]]
	if app.route=="Effectif": metrics=[[str(values.total)+" joueurs","people",C.GOLD],metrics[1],metrics[2],["Niveau moyen "+str(values.rating),"star",C.GOLD]]
	elif app.route not in ["Bureau","Composition"]: metrics=[]
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
			var x := 1512+i*250
			D.rect(row,Rect2(x,15,236,58),Color("16201f"),7,Color("415451"))
			var symbol := C.icon(item[1],25,item[2])
			row.add_child(symbol)
			D.place(symbol,Rect2(x+16,32,25,25))
			D.text(row,x+53,54,item[0],25,item[2],600,179)
	if app.route=="Bureau":
		var match_status := D.text(row,590,49,"",25,C.GOLD,700,630)
		match_status.name = "ImmersiveOfficeMatchStatus"
		match_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		D.place(match_status,Rect2(590,3,630,91))
		match_status.visible = not app._live().is_empty()
		match_status.visibility_changed.connect(_sync_office_props.bind(match_status))
		_sync_office_props(match_status)
		app.minibar = match_status
	else:
		app.minibar = C.label("",17,C.GOLD)
		parent.add_child(app.minibar)
		app.minibar.hide()

static func _sync_office_props(match_status: Label) -> void:
	if not match_status.is_inside_tree(): return
	var row := match_status.get_parent()
	var props := row.get_node_or_null("OfficeProps") as TextureRect
	if match_status.get_window().size.x < 1600 or match_status.visible:
		if props != null:
			row.remove_child(props)
			props.queue_free()
	elif props == null:
		var scene := load("res://art/office_props/office_props.tscn") as PackedScene
		props = scene.instantiate() as TextureRect
		row.add_child(props)
		D.place(props,Rect2(1080,5,260,78))

static func _subnavigation(parent: Node, app: Control) -> void:
	if (app.route=="Composition" and app.get_window().size.x>=TACTICS_CANVAS_MIN_WIDTH) or (app.route=="Effectif" and app.get_window().size.x>=1600): return
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

static func _footer(parent: Node, app: Control, layout: Control) -> void:
	var row := Control.new()
	row.name = "ImmersiveFooter"
	row.custom_minimum_size.y = maxf(C.px(44),38.0/layout.scale.y)
	C.fill(row)
	parent.add_child(row)
	layout.set_meta("immersive_footer",row)
	D.line(row,Vector2(0,-FOOTER_RISE),Vector2(2248,-FOOTER_RISE),Color(C.LINE,.7))
	app.status = D.text(row,2,36,app._settled_status_text(),17,C.ALERT if app._status_has_error() else C.MUTED,500,900)
	app.status.name = "ImmersiveSaveStatus"
	if app.route != "Bureau":
		var shortcuts := D.text(row,782,36-FOOTER_RISE,"Ctrl S  Sauvegarder     ·     Ctrl K  Rechercher     ·     F1  Aide",17,C.FAINT,400,800,HORIZONTAL_ALIGNMENT_LEFT,true)
		shortcuts.name = "ImmersiveShortcuts"
	if app.decision_feedback != null:
		var feedback: Button = app.decision_feedback.control()
		feedback.add_theme_font_override("font",C.DISPLAY)
		row.add_child(feedback)
	var dock := Control.new()
	dock.name = "CoachCompactDock"
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.visible = is_instance_valid(app.coach)
	row.add_child(dock)
	row.resized.connect(_position_footer.bind(row))
	_position_footer(row)

static func _position_footer(row: Control) -> void:
	var factor := row.get_global_transform().get_scale().x
	if factor<=0 or row.size.x<=0: return
	var dock: Control = row.get_node_or_null("CoachCompactDock")
	if dock==null: return
	dock.size=Vector2(144,34)/factor
	dock.position=Vector2(row.size.x-dock.size.x,row.size.y-dock.size.y-1.0/factor)
	var feedback: Button = row.get_node_or_null("DecisionFeedbackButton")
	if feedback!=null:
		feedback.size=Vector2(maxf(C.px(180),146.0/factor),maxf(C.px(34),30.0/factor))
		feedback.position=Vector2(dock.position.x-feedback.size.x-maxf(C.px(24),12.0/factor),row.size.y-feedback.size.y-1.0/factor)
		feedback.add_theme_font_size_override("font_size",maxi(C.px(17),roundi(13.0/factor)))
	var status: Label = row.get_node_or_null("ImmersiveSaveStatus")
	if status==null: return
	var gap := maxf(C.px(16),8.0/factor)
	var right := (feedback.position.x if feedback!=null else dock.position.x)-gap
	var shortcuts: Label = row.get_node_or_null("ImmersiveShortcuts")
	var compact := C.px(24)*factor<14.0
	var side_by_side := shortcuts != null and not compact and row.size.x*factor>=1650
	var shortcuts_x := maxf(C.px(782),630.0/factor)
	if side_by_side: right = minf(right,shortcuts_x-gap)
	var pixels := maxi(C.px(17),ceili(14.0/factor))
	var font := status.get_theme_font("font")
	status.add_theme_font_size_override("font_size",pixels)
	status.position.y = row.size.y-C.px(8+FOOTER_RISE)-font.get_ascent(pixels)
	status.size = Vector2(maxf(0.0,right-status.position.x),font.get_height(pixels))
	if shortcuts==null: return
	shortcuts.visible=compact or side_by_side
	var shortcut_font := C.MEDIUM if compact else C.BODY
	var shortcut_px := pixels if compact else maxi(12,C.px(17))
	var shortcut_height := shortcut_font.get_height(shortcut_px)
	shortcuts.add_theme_font_override("font",shortcut_font)
	shortcuts.add_theme_font_size_override("font_size",shortcut_px)
	shortcuts.add_theme_color_override("font_color",C.MUTED if compact else C.FAINT)
	if compact:
		shortcuts.position=Vector2(status.position.x,status.position.y-shortcut_height-1.0/factor)
		shortcuts.size=Vector2(status.size.x,shortcut_height)
	else:
		shortcuts.position=Vector2(shortcuts_x,C.px(36-FOOTER_RISE)-shortcut_font.get_ascent(shortcut_px))
		shortcuts.size=Vector2(C.px(800),shortcut_height)

static func _open_current_calendar(app: Control) -> void:
	app.set_meta("calendar_table",false)
	app._navigate("Calendrier")
	var calendar: Control = app.body.find_child("CarnetCalendar",true,false)
	if calendar != null and not calendar.today.is_empty():
		calendar._jump_to_today()

static func _calendar_table(app: Control, show_table: bool) -> void:
	app.set_meta("calendar_table",show_table)
	app._render(false)

static func _existing_page(app: Control, immersive_match: bool) -> void:
	match app.route:
		"Réception": app.body.add_child(Reception.build(app))
		"Sélections":
			var page := Selections.build(app)
			app.body.add_child(page)
			Legacy.apply(page, app.accent)
		"Club": app.body.add_child(app.ClubViews.club(app))
		"Calendrier":
			if app.get_meta("calendar_table",false):
				D.button(app.heading.get_parent(),Rect2(1050,16,340,52),"Vue mensuelle",_calendar_table.bind(app,false),false,"calendar",true,app.accent,"CalendarShowMonth")
				app.body.add_child(app.ClubViews.calendar(app))
			else:
				app.body.add_child(MonthCalendar.build(app,_calendar_table.bind(app,true)))
		"Classements": app.body.add_child(app.ClubViews.tables(app))
		"Finances": app.body.add_child(app.ClubViews.finance(app))
		"Effectif":
			var player:=P.player(app.model,app.selected_player)
			if app.get_meta("immersive08_full_player",false) and not player.is_empty():app.body.add_child(PlayerCanvas.build(app,player))
			elif app.get_window().size.x>=1600:app.body.add_child(SquadCanvas.build(app))
			else:
				var roster: Control = app.SquadViews.squad(app)
				app.body.add_child(roster)
				Legacy.apply(roster, app.accent)
		"Composition":
			if app.get_window().size.x>=TACTICS_CANVAS_MIN_WIDTH:
				app.body.add_child(TacticsCanvas.build(app))
			else:
				var lineup: Control = app.SquadViews.lineup(app)
				var remove := lineup.find_child("LineupRemove",true,false) as Button
				var candidates := lineup.find_child("LineupCandidatesScroll",true,false) as ScrollContainer
				# La libération reste au-dessus de la liste, à l’écart du dock de Gabi.
				remove.get_parent().move_child(remove,candidates.get_index())
				var selected := lineup.find_child("LineupSlot%02d" % (app.selected_slot+1),true,false) as Button
				if selected != null: selected.set_meta("carnet_selected",true)
				app.body.add_child(lineup)
				Legacy.apply(lineup,app.accent)
		"Préparation": app.body.add_child(Preparation.compact(app))
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
			app.match_screen = MatchCanvas.new() if immersive_match else MatchCompact.new()
			app.match_screen.app = app
			app.body.add_child(app.match_screen)
			app.match_page = app.match_screen
			app.match_screen.update_frame(app.model)
	if app.route == "Staff": ClubCanvas.style_staff(app.body.get_child(0), app.accent)
	elif COMPACT_ART.has(app.route): Legacy.apply(app.body.get_child(0), app.accent)
