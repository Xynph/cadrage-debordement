extends RefCounted
## Effectif, Composition, Préparation, Recrutement (vues génériques) — socle (découpe de squad_views.gd, sans changement) : constantes, outils de liste, libellés de poste, fenêtres de contrat et de comparaison.
## Chaîne d'héritage : socle ← fiche joueur ← liste de l'Effectif ← Composition et Préparation ← Recrutement ← squad_views.gd (fichier public).
const FocusLater := preload("res://ui/focus_later.gd")
const P = preload("res://ui/immersive08/projection.gd")
const G = preload("res://ui/carnet_skin.gd")
const Board = preload("res://ui/lineup_board.gd")
const U = preload("res://ui/management_state.gd")
const TableOrder = preload("res://ui/player_table_order.gd")
const ClubUI = preload("res://ui/immersive08/club_ui.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const Decisions = preload("res://ui/decision_views.gd")
const Cover = preload("res://ui/lineup_cover.gd")
const Espoir = preload("res://ui/espoir_appel.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")
const Sales = preload("res://ui/player_sales_view.gd")
## Colonne Poste de la liste : libellés courts en compact (< 950 px), libellé complet en large.
const POS_COMPACT_WIDTH := 80
const POS_FULL_WIDTH := 132

static func _empty(parent:Node) -> void:
	for child in parent.get_children():parent.remove_child(child);child.queue_free()

static func _pagination(parent:Node,id:String,state:Dictionary) -> HBoxContainer:
	var row:=G.h(6)
	row.name=id
	parent.add_child(row)
	var previous:=G.reading_button(G.button("← Précédent",func():pass),88)
	previous.name=id+"Previous"
	row.add_child(previous)
	var info:=G.label("",12,G.MUTED)
	info.name=id+"Info"
	info.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	G.fill(info)
	row.add_child(info)
	var next:=G.reading_button(G.button("Suivant →",func():pass),88)
	next.name=id+"Next"
	row.add_child(next)
	if not state.has("page"):state.page=0
	return row

static func _bind_pagination(row:HBoxContainer,state:Dictionary,refresh:Callable) -> void:
	row.get_child(0).pressed.connect(func():
		state.page=maxi(0,int(state.page)-1);state.scroll=0;refresh.call()
		if not row.get_child(0).disabled:row.get_child(0).grab_focus()
		elif not row.get_child(2).disabled:row.get_child(2).grab_focus())
	row.get_child(2).pressed.connect(func():
		state.page=int(state.page)+1;state.scroll=0;refresh.call()
		if not row.get_child(2).disabled:row.get_child(2).grab_focus()
		elif not row.get_child(0).disabled:row.get_child(0).grab_focus())

static func _page_range(row:HBoxContainer,state:Dictionary,total:int,capacity:int) -> Vector2i:
	var pages:=maxi(1,ceili(float(total)/capacity))
	state.page=clampi(int(state.get("page",0)),0,pages-1)
	row.get_child(0).disabled=int(state.page)==0
	row.get_child(2).disabled=int(state.page)>=pages-1
	row.get_child(1).text="Page %d / %d"%[int(state.page)+1,pages]
	return Vector2i(int(state.page)*capacity,mini(total,(int(state.page)+1)*capacity))

static func _search(parent:Node,id:String,state:Dictionary) -> LineEdit:
	var search:=LineEdit.new()
	search.name=id
	search.placeholder_text="Rechercher un nom ou un poste…"
	search.clear_button_enabled=true
	search.text=state.search
	search.custom_minimum_size.y=38
	search.add_theme_color_override("font_placeholder_color",G.MUTED)
	search.accessibility_name="Rechercher un joueur par nom ou poste"
	parent.add_child(search)
	return search

static func _positions(source:Array) -> Array:
	var values:Array=[]
	for p:Dictionary in source:
		if p.pos not in values:values.append(str(p.pos))
	values.sort()
	return ["Tous"]+values

static func _choice(parent:Node,id:String,values:Array,selected:Variant,caption:String) -> OptionButton:
	var box:=G.v(2)
	G.fill(box)
	parent.add_child(box)
	box.add_child(G.label(caption,12,G.MUTED))
	var choice:=OptionButton.new()
	choice.name=id
	choice.custom_minimum_size.y=34
	G.reading_button(choice,64)
	choice.fit_to_longest_item=false
	choice.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	choice.tooltip_text=caption
	for text in values:choice.add_item(str(text))
	choice.select(maxi(0,values.find(selected)))
	box.add_child(choice)
	return choice

static func _reveal_roster_row(app: Control, list: Control, row: Control) -> void:
	if not is_instance_valid(list) or not list.is_inside_tree(): return
	await list.get_tree().process_frame
	if not is_instance_valid(row) or not row.is_inside_tree(): return
	var scroll := list.get_parent() as ScrollContainer
	if scroll == null: return
	scroll.ensure_control_visible(row)
	app.management_ui.roster.scroll=scroll.scroll_vertical
	list.set_meta("reveal_id","")

static func _roster_columns(width:float) -> Array:
	var columns:Array=[["name","JOUEUR",130],["pos","POSTE",POS_COMPACT_WIDTH],["age","ÂGE",26],["rating","NIV.",30],["condition","COND.",42]]
	if width>=700:columns.append_array([["salary","SALAIRE "+G.salary_period(true).to_upper(),78],["contractEnd","ÉCH.",38]])
	if width>=900:columns.append_array([["minutes","MIN.",42],["appearances","APP.",32],["physicalLoad","CHARGE",42]])
	if width>=950:
		columns[1][2]=POS_FULL_WIDTH
		columns.append_array([["potential","POT.",60],["status","SÉLECTION",76]])
	return columns

## Libellé officiel du poste dans le jeu : le numéro 8 est la « troisième ligne centre » (comme fiche, vestiaire et contrats).
static func position_label(pos:String,compact:bool=false) -> String:
	var full:String={"Numéro 8":"Troisième ligne centre","N° 8":"Troisième ligne centre","N°8":"Troisième ligne centre","Troisième ligne":"Troisième ligne aile"}.get(pos,pos)
	if not compact:return full
	return {"Pilier gauche":"Pilier g.","Pilier droit":"Pilier d.","Deuxième ligne":"2e ligne","Troisième ligne aile":"3e l. aile","Troisième ligne centre":"3e l. centre","Demi de mêlée":"Demi mêlée","Demi d’ouverture":"Demi d’ouv.","Talonneur remplaçant":"Talon. rempl.","Pilier remplaçant":"Pilier rempl."}.get(full,full)

static func _roster_value(p:Dictionary,key:String,compact:bool=false) -> String:
	if key=="pos":return position_label(str(p.get("pos","—")),compact)
	if key in ["rating","note"]:return G.rating_text(p,true)
	if key=="potential":return G.potential_text(p)
	if key=="salary":return G.salary_amount(p.get(key,0))
	if key=="condition":return G.n(p.get(key,0))+"%"
	if key=="watch":return U.watch_reason(p)
	if key=="contractEnd":return G.contract_year(p.get(key))
	if key in ["name","pos","status"]:return str(p.get(key,"—"))
	return "—" if p.get(key)==null else G.n(p[key])

static func player_load_unavailable_reason(app: Control) -> String:
	var meta: Dictionary = app.model.get("meta", {})
	var live: Dictionary = app._live()
	if not live.is_empty():
		return "Charge indisponible avant la validation de la journée." if live.get("finished", false) else "Charge indisponible pendant le match."
	if meta.get("phase") == "ended": return "Charge indisponible en fin de saison."
	if meta.get("trained", false): return "Séance effectuée. La charge se règle avant la prochaine séance."
	return ""

## Entrée unique du comparateur de joueurs (Effectif, fiche joueur) : même fenêtre que le Recrutement.
static func comparison(app:Control) -> void:
	var opener:=app.get_viewport().gui_get_focus_owner() as Button
	var return_focus:=str(opener.name) if opener!=null else ""
	U.remember(app)
	U.sync(app)
	load("res://ui/immersive08/comparateur_canvas.gd").ouvrir(app)

static func contract(app:Control,p:Dictionary,recruiting:bool) -> void:
	# Offre à une piste du marché : un écran du Recrutement (sous-page « Offre au joueur »), jamais une fenêtre.
	if recruiting and app.route == "Recrutement" and not app.get_children().any(func(c): return c is AcceptDialog and c.visible) and not str(p.get("id","")).is_empty() and app.model.get("market",[]).any(func(m): return m is Dictionary and str(m.get("id","")) == str(p.id)):
		load("res://ui/immersive08/recruitment_pages.gd").ouvrir(app,"negociation",{"player_id":str(p.id)})
		return
	preload("res://ui/contract_negotiation.gd").open(app,p,recruiting)

static func _context_text(parent:Node,text:String,id:String="") -> Label:
	var label:=G.wrap(text,12,G.INK)
	label.name="ProfileContextText"+id;label.max_lines_visible=2
	label.tooltip_text=text;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(label);return label

static func _profile_tile(parent:Node,id:String,caption:String,prefix:String="ProfileTile") -> VBoxContainer:
	var frame:=PanelContainer.new()
	frame.name=prefix+id
	G.fill(frame)
	frame.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	var style:=G.T.box(Color("fcfcf8"),3,G.LINE)
	style.shadow_color=Color(0,0,0,.07)
	style.shadow_size=2;style.shadow_offset=Vector2(0,1)
	style.content_margin_left=8;style.content_margin_right=8
	style.content_margin_top=3;style.content_margin_bottom=3
	frame.add_theme_stylebox_override("panel",style)
	parent.add_child(frame)
	var body:=G.v(2)
	frame.add_child(body)
	body.add_child(G.label(caption.to_upper(),11,G.MUTED))
	return body

static func _profile_fact(parent:Node,id:String,caption:String,value:String) -> void:
	var row:=G.h(5)
	parent.add_child(row)
	var label:=G.label(caption,11,G.MUTED)
	G.fill(label)
	row.add_child(label)
	var fact:=G.label(value,12,G.POTENTIAL_COLOR if id=="ProfilePotentialValue" else G.INK)
	fact.name=id
	row.add_child(fact)
