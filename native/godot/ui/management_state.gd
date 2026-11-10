extends RefCounted

const WATCH_FILTER := "Sous surveillance"

static func watch_reason(player: Dictionary) -> String:
	var reasons := PackedStringArray()
	var charge := float(player.get("physicalLoad", 0))
	var condition := float(player.get("condition", 100))
	if charge >= 70:
		reasons.append("Charge %d %%" % floori(charge))
	if condition < 80:
		var displayed := floorf(condition * 10) / 10
		var value := str(displayed).trim_suffix(".0").replace(".", ",")
		reasons.append("Condition " + value + " %")
	return " · ".join(reasons)

static func watch_caption(count: int) -> String:
	return "Voir %d joueur%s sous surveillance" % [count, "s" if count > 1 else ""]

# Reading state remains local. The shortlist mirrors the engine's saved watchlist.
static func defaults() -> Dictionary:
	return {"search":"","family":"Tous","position":"Tous","available":"Tous","contract":"Tous","sort":"Poste","descending":false,"scroll":0,"focus":"","caret":0,"selection_from":-1,"selection_to":-1,"followed":false,"navigation_id":""}

static func fold(text:Variant) -> String:
	var result:=str(text).to_lower()
	for pair in [["àáâäãå","a"],["èéêë","e"],["ìíîï","i"],["òóôöõ","o"],["ùúûü","u"],["ç","c"],["ñ","n"],["ÿý","y"]]:
		for letter in pair[0]:result=result.replace(letter,pair[1])
	var plain:=""
	for letter in result:
		var code:int=letter.unicode_at(0)
		if code<0x0300 or code>0x036f:plain+=letter
	return plain.replace("œ","oe").replace("æ","ae")

static func players(source:Array,state:Dictionary,season:int,market:bool=false,followed:Array=[],sort_result:bool=true) -> Array:
	var result:Array=[]
	var query:=fold(state.search).strip_edges()
	var target_id := str(state.get("navigation_id", "")) if market else ""
	for p:Dictionary in source:
		if not target_id.is_empty():
			if str(p.id) != target_id: continue
		elif not query.is_empty() and not fold(str(p.get("name",""))+" "+str(p.get("pos",""))).contains(query):continue
		if state.position!="Tous" and p.get("pos")!=state.position:continue
		if market:
			if state.get("followed",false) and str(p.id) not in followed:continue
			if state.available=="Disponibles" and not p.get("available",false):continue
		else:
			if state.family=="Avants" and float(p.get("fam",0))>3:continue
			if state.family=="Arrières" and float(p.get("fam",0))<=3:continue
			if state.family=="Blessés" and float(p.get("injury",0))<=0:continue
			if state.family==WATCH_FILTER and watch_reason(p).is_empty():continue
			if state.family=="Hors groupe" and p.get("shirtNumber")!=null:continue
			if state.available=="Disponibles" and float(p.get("injury",0))>0:continue
			if state.available=="Blessés" and float(p.get("injury",0))<=0:continue
			if state.contract=="Fin de saison" and (p.get("contractEnd")==null or int(p.contractEnd)>season):continue
			if state.contract=="Sans contrat" and p.get("contractEnd")!=null:continue
		result.append(p)
	if not sort_result: return result
	var key:String={"Poste":"pos","Nom":"name","Niveau":"rating","Condition":"condition","Âge":"age","Salaire":"salary","Échéance":"contractEnd"}.get(state.sort,"pos")
	result.sort_custom(func(a:Dictionary,b:Dictionary):
		var av:Variant=a.get(key,0);var bv:Variant=b.get(key,0)
		if av==null:av=0
		if bv==null:bv=0
		if key in ["name","pos"]:av=fold(av);bv=fold(bv)
		if av==bv:return str(a.id)<str(b.id)
		return av>bv if state.descending else av<bv)
	return result

static func sync(app:Control,reset:bool=false) -> void:
	var club:Dictionary=app.model.club if app.model.get("club") is Dictionary else {}
	var key:=str(app.model.get("meta",{}).get("mode",""))+":"+str(club.get("id",""))
	if reset or app.management_ui.get("career","")!=key:
		app.management_ui={"career":key,"roster":defaults(),"market":defaults(),"compare":[],"shortlist":[],"profile_scroll":0}
		app.roster_filter="Tous";app.roster_sort="Poste";app.selected_player=""
	var squad_ids:Array=app.model.get("squad",[]).map(func(p):return str(p.id))
	var market_ids:Array=app.model.get("market",[]).map(func(p):return str(p.id))
	app.management_ui.compare=app.management_ui.compare.filter(func(id):return id in squad_ids).slice(0,2)
	var career_data: Variant=app.model.get("clubLife",{}).get("managerCareer")
	if career_data is Dictionary and career_data.get("watch") is Array:
		app.management_ui.shortlist=career_data.watch.map(func(id):return str(id))
	else:
		app.management_ui.shortlist=app.management_ui.shortlist.filter(func(id):return id in market_ids)
	if app.selected_player not in squad_ids:app.selected_player=""
	for pair in [["roster","squad"],["market","market"]]:
		var positions:Array=app.model.get(pair[1],[]).map(func(p):return str(p.pos))
		if app.management_ui[pair[0]].position not in positions:app.management_ui[pair[0]].position="Tous"

static func remember(app:Control) -> void:
	if app.management_ui.is_empty() or not is_instance_valid(app.root_content):return
	var focus:Control=app.get_viewport().gui_get_focus_owner()
	for pair in [["roster","RosterSearch","SquadScroll"],["market","MarketSearch","MarketScroll"]]:
		var searches:Array=app.root_content.find_children(pair[1],"LineEdit",true,false)
		if searches.is_empty():continue
		var state:Dictionary=app.management_ui[pair[0]]
		var pages:Array=app.root_content.find_children("CarnetSquad" if pair[0]=="roster" else "CarnetMarket","Control",true,false)
		if focus!=null and not pages.is_empty() and pages[0].is_ancestor_of(focus):state.focus=str(focus.name)
		var search:LineEdit=searches[0]
		state.caret=search.caret_column
		state.selection_from=search.get_selection_from_column() if search.has_selection() else -1
		state.selection_to=search.get_selection_to_column() if search.has_selection() else -1
		var scrollers:Array=app.root_content.find_children(pair[2],"ScrollContainer",true,false)
		if not scrollers.is_empty():state.scroll=scrollers[0].scroll_vertical
	var profiles:Array=app.root_content.find_children("ProfileScroll","ScrollContainer",true,false)
	if not profiles.is_empty():app.management_ui.profile_scroll=profiles[0].scroll_vertical

static func restore(app:Control,page:Control,kind:String) -> void:
	var state:Dictionary=app.management_ui[kind]
	await app.get_tree().process_frame
	if not is_instance_valid(page) or not page.is_inside_tree():return
	if not str(state.focus).is_empty():
		var controls:=page.find_children(state.focus,"Control",true,false)
		if not controls.is_empty():
			controls[0].grab_focus()
			if controls[0] is LineEdit:
				controls[0].caret_column=int(state.caret)
				if int(state.selection_from)>=0:controls[0].select(int(state.selection_from),int(state.selection_to))
	await app.get_tree().process_frame
	if not is_instance_valid(page) or not page.is_inside_tree():return
	var list:=page.find_children("SquadScroll" if kind=="roster" else "MarketScroll","ScrollContainer",true,false)
	if not list.is_empty():list[0].scroll_vertical=int(state.scroll)
	var profiles:=page.find_children("ProfileScroll","ScrollContainer",true,false)
	if not profiles.is_empty():profiles[0].scroll_vertical=int(app.management_ui.profile_scroll)
