extends Control
const S = preload("res://ui/contextual/skin.gd")
const Charte = preload("res://ui/charte.gd")
const SeasonLabel = preload("res://ui/season_label.gd")
const PRIORITIES = {"performance":"Résultats","stabilite":"Stabilité","finances":"Finances","effectif":"Effectif"}
const TYPES = {"wins":"Victoires","points":"Points","rank":"Place au classement","cash":"Trésorerie"}
var director: Node
var app: Control
var model: Dictionary = {}
var meeting_data: Dictionary = {}
var ui: Control
var room_host: Control
var draft_type := "wins"
var draft_target := 10.0
var draft_deadline := 1
var _context_key := ""
var _identity_key := ""
var _fingerprint := ""
var _local_notice := ""
var _was_waiting := false

func _ready() -> void:
	name="ContextualBoardRoom"
	app=director.app
	room_host=Control.new();S.full(room_host);room_host.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(room_host)
	_sync_room(app.model.get("club",{}))

func _sync_room(club: Dictionary) -> void:
	var identity_key := JSON.stringify(club)
	if identity_key==_identity_key:return
	_identity_key=identity_key
	S.clear(room_host)
	S.room(room_host,"board",club)

func update_frame(value: Dictionary, data: Dictionary = {}) -> void:
	model=value
	meeting_data=data.duplicate(true)
	if app==null:app=director.app
	if room_host!=null:_sync_room(model.get("club",{}))
	var strategy: Dictionary=model.get("clubLife",{}).get("clubStrategy",{})
	var context_key := JSON.stringify([model.get("club",{}).get("id"),strategy.get("context",{})])
	if context_key!=_context_key:
		_context_key=context_key;_local_notice="";draft_type="wins";draft_target=10.0
		draft_deadline=int(strategy.get("finance",{}).get("weeksPerSeason",int(strategy.get("context",{}).get("week",0))+1))
	var fingerprint := JSON.stringify([model.get("club",{}),model.get("meta",{}).get("trust"),model.get("meta",{}).get("phase"),model.get("live"),strategy,meeting_data,app.waiting,app.last_error,_local_notice])
	if fingerprint==_fingerprint:return
	_fingerprint=fingerprint;_was_waiting=app.waiting;_draw()

func _process(_delta: float) -> void:
	if app==null or _was_waiting==bool(app.waiting):return
	_was_waiting=app.waiting
	for field in ["BoardObjectiveTarget","BoardObjectiveDeadline"]:
		var control := find_child(field,true,false)
		if control is SpinBox:control.editable=not app.waiting and _can_act()

func _strategy() -> Dictionary:
	return model.get("clubLife",{}).get("clubStrategy",{})

func _current_strategy() -> Dictionary:
	if app==null or app.waiting or meeting_data.get("completed",false):return {}
	var current: Dictionary=app.model.get("clubLife",{}).get("clubStrategy",{})
	if current.get("context",{})!=_strategy().get("context",{}) or app.model.get("club",{}).get("id")!=model.get("club",{}).get("id"):return {}
	if app.model.get("live") is Dictionary or app.model.get("meta",{}).get("phase")=="ended" or not current.get("available",false):return {}
	return current

func _can_act() -> bool:return not _current_strategy().is_empty()

func _number(value: Variant) -> bool:return (value is int or value is float) and is_finite(float(value))

func _display(value: Variant, money: bool = false) -> String:
	if not _number(value):return "Non renseigné"
	return S.G.euros(value) if money else S.G.n(value)

func _metric(parent: Node, title: String, value: Variant, node_name: String, money: bool = false) -> void:
	var label := S.wrap(title+" : "+_display(value,money),16,S.TEXT);label.name=node_name;parent.add_child(label)

func _draw() -> void:
	if is_instance_valid(ui):remove_child(ui);ui.queue_free()
	ui=Control.new();S.full(ui);add_child(ui)
	var variante := OS.get_environment("CD_VARIANTE_VISUELLE")
	if variante in ["A","B"]:
		_draw_visuel(variante)
		director._refresh_controls()
		return
	var frame := S.frame(ui,22)
	S.heading(frame,model.get("club",{}),"Le point avec la direction","")
	var body := S.G.h(18);S.G.fill(body,true);frame.add_child(body)
	var facts := S.panel(body,16);facts.get_parent().custom_minimum_size.x=346;facts.get_parent().size_flags_horizontal=Control.SIZE_FILL
	var facts_scroll := S.G.scroll(facts);S.G.fill(facts_scroll.get_parent(),true)
	var strategy := _strategy();var board: Dictionary=strategy.get("board",{});var finance: Dictionary=strategy.get("finance",{})
	facts_scroll.add_child(S.label("La situation enregistrée",21,S.GOLD))
	_metric(facts_scroll,"Confiance de la direction",model.get("meta",{}).get("trust"),"BoardRoomTrust")
	_metric(facts_scroll,"Organisation du club",board.get("organizationScore"),"BoardRoomOrganization")
	var club_goal: String=str(model.get("club",{}).get("goal",""))
	if not club_goal.is_empty():facts_scroll.add_child(S.wrap("Cap du club : "+club_goal,14))
	var error := S.wrap(str(app.last_error),14,Charte.DORE);error.name="BoardRoomServerError";error.visible=not error.text.is_empty();facts_scroll.add_child(error)
	if not _local_notice.is_empty():facts_scroll.add_child(S.wrap(_local_notice,14,S.GOLD))
	facts_scroll.add_child(S.label("Les jalons suivis",18,S.GOLD))
	var goals: Array=board.get("objectives",[])
	if goals.is_empty():facts_scroll.add_child(S.wrap("Aucun jalon enregistré",14))
	for goal: Dictionary in goals:
		var type: String=str(goal.get("type",""));var metrics: Dictionary=board.get("metrics",{})
		var status: String={"pending":"À suivre","met":"Atteint","missed":"Manqué","unverified":"Non vérifiable"}.get(str(goal.get("status","")),"Non renseigné")
		var line := S.wrap("%s · %s\nMesure actuelle : %s · cible : %s\nÉchéance : semaine %s" % [TYPES.get(type,type),status,_display(metrics.get(type),type=="cash"),_display(goal.get("target"),type=="cash"),_display(goal.get("deadline"))],14,S.TEXT)
		line.name="BoardObjective_"+str(goal.get("id","")).validate_node_name();facts_scroll.add_child(line)
	facts_scroll.add_child(S.label("Les moyens connus",18,S.GOLD))
	for item in [["Trésorerie","cash"],["Salaires / semaine","weeklyWages"],["Revenus connus / semaine","weeklyIncome"],["Coûts connus / semaine","weeklyCosts"],["Projection de fin de saison","baseForecast"]]:
		_metric(facts_scroll,str(item[0]),finance.get(item[1]),"BoardFinance_"+str(item[1]),true)
	var notice := S.wrap(str(finance.get("notice","Aucune projection financière disponible.")).replace("Montants de jeu fictifs.", "").strip_edges(),12);notice.name="BoardRoomFinanceNotice";facts_scroll.add_child(notice)
	for warning: Variant in board.get("readiness",{}).get("warnings",[]):facts_scroll.add_child(S.wrap(str(warning),14,S.GOLD))
	var history: Array=board.get("history",[])
	if not history.is_empty():
		facts_scroll.add_child(S.label("Bilans archivés",18,S.GOLD))
		for report: Dictionary in history.slice(maxi(0,history.size()-3)):
			facts_scroll.add_child(S.wrap("Saison %s · organisation %s / 100"%[SeasonLabel.label(report.get("season")),_display(report.get("score"))],14))
	var air := Control.new();air.mouse_filter=Control.MOUSE_FILTER_IGNORE;S.G.fill(air,true);body.add_child(air)
	var actions := S.panel(body,16);actions.get_parent().custom_minimum_size.x=390;actions.get_parent().size_flags_horizontal=Control.SIZE_FILL
	var list := S.G.scroll(actions);list.get_parent().name="BoardRoomActionsScroll";S.G.fill(list.get_parent(),true)
	list.add_child(S.label("Arbitrer le projet du club",21,S.GOLD))
	if meeting_data.get("completed",false):
		list.add_child(S.wrap("✓ Décision enregistrée",15,S.GOLD))
	else:
		var acknowledge := S.button("CONFIRMER LES PRIORITÉS ACTUELLES",_acknowledge,_ack_available(),true);acknowledge.name="BoardMeetingAck";list.add_child(acknowledge)
	var priorities := GridContainer.new();priorities.columns=2;priorities.add_theme_constant_override("h_separation",8);priorities.add_theme_constant_override("v_separation",8);list.add_child(priorities)
	for key: String in PRIORITIES:
		var button := S.button(PRIORITIES[key],func():_set_priority(key),_can_act());button.name="BoardPriority_"+key
		if board.get("priority")==key:S.selected(button)
		priorities.add_child(button)
	list.add_child(S.label("Structurer l’organisation",18,S.GOLD))
	for project: Dictionary in board.get("projectOptions",[]):
		var known_cost := _number(project.get("cost"));var cash_known := _number(finance.get("cash"))
		var enabled: bool=_can_act() and not project.get("used",false) and known_cost and cash_known and float(finance.cash)>=float(project.cost)
		var button := S.button(str(project.get("label","Projet"))+" · "+_display(project.get("cost"),true)+( " · engagé" if project.get("used",false) else ""),func():_request_project(str(project.get("id",""))),enabled)
		button.name="BoardProject_"+str(project.get("id",""));list.add_child(button)
	_build_objective_form(list,strategy)
	var close := S.button("REVENIR À LA GESTION" if meeting_data.get("completed",false) else "CONFIRME TA DÉCISION POUR TERMINER",_close_meeting,bool(meeting_data.get("completed",false)) and not app.waiting);close.name="BoardRoomClose";frame.add_child(close)
	director._refresh_controls()

func _close_meeting() -> void:
	if not app.waiting and meeting_data.get("completed",false):director.close_room()

func _ack_available() -> bool:
	if app==null or app.waiting or meeting_data.get("completed",false) or not meeting_data.get("ackAllowed",false):return false
	var id: String=str(meeting_data.get("meetingId",""))
	var active: Variant=app.model.get("clubLife",{}).get("clubMeetings",{}).get("scene")
	return not id.is_empty() and active is Dictionary and active.get("id")==id and active.get("kind")=="board" and not active.get("completed",false) and active.get("ackAllowed",false)

func _acknowledge() -> void:
	if _ack_available():director.command("club_meeting_ack",{"meetingId":meeting_data.meetingId})

func _build_objective_form(parent: Node, strategy: Dictionary) -> void:
	parent.add_child(S.label("Définir un jalon",18,S.GOLD))
	var goals: Array=strategy.get("board",{}).get("objectives",[])
	var used_types: Array=goals.map(func(goal: Dictionary):return str(goal.get("type","")))
	var open_types: Array=TYPES.keys().filter(func(type: String):return not used_types.has(type))
	var week := int(strategy.get("context",{}).get("week",0));var end := int(strategy.get("finance",{}).get("weeksPerSeason",0))
	var enabled: bool=_can_act() and goals.size()<8 and not open_types.is_empty() and end>week
	if open_types.is_empty():parent.add_child(S.wrap("✓ Tous les jalons sont posés",13));return
	if not open_types.has(draft_type):draft_type=str(open_types[0])
	var kind := OptionButton.new();kind.name="BoardObjectiveType";kind.custom_minimum_size.y=38
	for type: String in open_types:kind.add_item(TYPES[type])
	kind.select(open_types.find(draft_type));kind.disabled=not enabled;kind.set_meta("contextual_enabled",enabled)
	kind.item_selected.connect(func(index: int):draft_type=str(open_types[index]));parent.add_child(kind)
	var fields := S.G.h(10);parent.add_child(fields)
	var target := SpinBox.new();target.name="BoardObjectiveTarget";target.min_value=0;target.max_value=1000000000;target.value=draft_target;target.custom_minimum_size=Vector2(145,38);target.editable=enabled
	target.value_changed.connect(func(value: float):draft_target=value);fields.add_child(target)
	var deadline := SpinBox.new();deadline.name="BoardObjectiveDeadline";deadline.min_value=week+1;deadline.max_value=maxi(end,week+1);deadline.prefix="Sem. ";draft_deadline=clampi(draft_deadline,week+1,maxi(end,week+1));deadline.value=draft_deadline;deadline.custom_minimum_size=Vector2(145,38);deadline.editable=enabled
	deadline.value_changed.connect(func(value: float):draft_deadline=int(value));fields.add_child(deadline)
	target.tooltip_text="Cible";deadline.tooltip_text="Échéance"
	var submit := S.button("ENREGISTRER LE JALON",_create_objective,enabled);submit.name="BoardObjectiveCreate";parent.add_child(submit)

func _set_priority(key: String) -> void:
	var current := _current_strategy()
	if current.is_empty() or not PRIORITIES.has(key):return
	director.command("club_board_priority",{"context":current.context.duplicate(true),"key":key})

func _find_project(strategy: Dictionary, id: String) -> Dictionary:
	for project: Dictionary in strategy.get("board",{}).get("projectOptions",[]):
		if str(project.get("id",""))==id:return project
	return {}

func _project_available(strategy: Dictionary, project: Dictionary) -> bool:
	if strategy.is_empty() or project.is_empty() or project.get("used",false):return false
	var cash: Variant=strategy.get("finance",{}).get("cash")
	return _number(cash) and _number(project.get("cost")) and float(cash)>=float(project.cost)

func _request_project(id: String) -> void:
	var current := _current_strategy();var project := _find_project(current,id)
	if not _project_available(current,project):return
	var context: Dictionary=current.context.duplicate(true);var cost: float=float(project.cost)
	var payload := {"context":context,"kind":id,"confirmed":true}
	app.confirm_decision("club_board_project",payload,"Engager le club","Financer %s pour %s ? Paiement unique, sans bonus de match."%[str(project.get("label",id)),S.G.euros(cost)],func():
		var fresh := _current_strategy();var quote := _find_project(fresh,id)
		if fresh.get("context",{})!=context or not _project_available(fresh,quote) or float(quote.get("cost",-1))!=cost:
			_local_notice="Le contexte ou le devis a changé. Vérifie les moyens disponibles avant de réessayer."
			update_frame(app.model,meeting_data);return
		director.command("club_board_project",payload))

func _create_objective() -> void:
	var current := _current_strategy()
	if current.is_empty() or not TYPES.has(draft_type) or not _number(draft_target) or draft_target<0 or draft_target>1000000000:return
	var goals: Array=current.get("board",{}).get("objectives",[])
	if goals.size()>=8 or goals.any(func(goal: Dictionary):return goal.get("type")==draft_type):return
	if draft_deadline<=int(current.context.week) or draft_deadline>int(current.get("finance",{}).get("weeksPerSeason",0)):return
	director.command("club_board_objective",{"context":current.context.duplicate(true),"type":draft_type,"target":draft_target,"deadline":draft_deadline})

# --- Variantes visuelles (planche A/B du 21/11/2026, CD_VARIANTE_VISUELLE=A|B) --------------------------------
const V = preload("res://ui/contextual/board_room_visuels.gd")
const P = preload("res://ui/immersive08/pastilles_club.gd")

func _board() -> Dictionary: return _strategy().get("board",{})
func _finance() -> Dictionary: return _strategy().get("finance",{})
func _week() -> int: return int(_strategy().get("context",{}).get("week",0))

func _fenetre_confiance() -> void:
	V.fenetre(ui,"Confiance de la direction","rating",Charte.CONFIANCE,V.contenu_confiance(model.get("meta",{}).get("trust"),_board(),PRIORITIES))
func _fenetre_organisation() -> void:
	V.fenetre(ui,"Organisation du club","settings",Charte.REPOS,V.contenu_organisation(_board(),func(season: Variant): return SeasonLabel.label(season)))
func _fenetre_moyens() -> void:
	V.fenetre(ui,"Les moyens","money",Charte.GAIN,V.contenu_moyens(_finance()),660.0)
func _fenetre_jalon(goal: Dictionary) -> void:
	var type := str(goal.get("type",""))
	V.fenetre(ui,TYPES.get(type,type),V.ICONES_JALON.get(type,"target"),V.statut(goal)[2],V.contenu_jalon(goal,_board().get("metrics",{}),_week()),640.0)

func _anneaux(diametre: float) -> HBoxContainer:
	var row := V.rangee(4)
	row.add_child(V.anneau(model.get("meta",{}).get("trust"),"Confiance",Charte.CONFIANCE,"BoardRoomTrust",_fenetre_confiance,diametre))
	row.add_child(V.anneau(_board().get("organizationScore"),"Organisation",Charte.REPOS,"BoardRoomOrganization",_fenetre_organisation,diametre))
	return row

## Cap du club, signaux de la direction, refus du serveur, avis local : pastilles.
func _signaux() -> HFlowContainer:
	var flow := HFlowContainer.new();flow.add_theme_constant_override("h_separation",8);flow.add_theme_constant_override("v_separation",8)
	var club_goal: String=str(model.get("club",{}).get("goal",""))
	if not club_goal.is_empty():flow.add_child(P.pastille(club_goal,Charte.MORAL,"target","Cap du club",16,"BoardRoomGoal"))
	for warning: Variant in _board().get("readiness",{}).get("warnings",[]):flow.add_child(P.pastille(str(warning),Charte.INTENSIF,"warning","",15))
	var error := S.wrap(str(app.last_error),14,Charte.PERTE);error.name="BoardRoomServerError";error.visible=not error.text.is_empty();flow.add_child(error)
	if not _local_notice.is_empty():flow.add_child(P.pastille(_local_notice,Charte.INTENSIF,"warning","",15))
	return flow

func _tuiles_moyens(columns: int) -> GridContainer:
	var finance := _finance()
	var grid := GridContainer.new();grid.columns=columns;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var cash: Variant=finance.get("cash")
	grid.add_child(V.tuile(V.euros(cash),"Trésorerie",Charte.PERTE if V.nombre(cash) and float(cash)<0 else Charte.IVOIRE,"money","BoardFinance_cash",_fenetre_moyens))
	grid.add_child(V.tuile(V.euros(finance.get("weeklyWages")),"Salaires / sem.",Charte.INTENSIF,"people","BoardFinance_weeklyWages",_fenetre_moyens))
	grid.add_child(V.tuile("▲ "+V.euros(finance.get("weeklyIncome")),"Revenus / sem.",Charte.GAIN,"","BoardFinance_weeklyIncome",_fenetre_moyens))
	grid.add_child(V.tuile("▼ "+V.euros(finance.get("weeklyCosts")),"Coûts / sem.",Charte.PERTE,"","BoardFinance_weeklyCosts",_fenetre_moyens))
	grid.add_child(V.tuile(V.euros(finance.get("baseForecast")),"Fin de saison",Charte.MORAL,"flag","BoardFinance_baseForecast",_fenetre_moyens))
	return grid

func _info_moyens() -> Button:
	var notice := str(_finance().get("notice","Aucune projection financière disponible.")).replace("Montants de jeu fictifs.","").strip_edges()
	var i := P.info(notice,"i","BoardRoomFinanceNotice");i.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	return i

func _cartes_jalons(parent: Container, compacte: bool) -> void:
	var goals: Array=_board().get("objectives",[])
	if goals.is_empty():parent.add_child(P.pastille("Aucun jalon",Charte.IVOIRE_2,"flag","",15))
	for goal: Dictionary in goals:
		parent.add_child(V.carte_jalon(goal,_board().get("metrics",{}),"BoardObjective_"+str(goal.get("id","")).validate_node_name(),func():_fenetre_jalon(goal),compacte))

func _bilans() -> HFlowContainer:
	var flow := HFlowContainer.new();flow.add_theme_constant_override("h_separation",8)
	var history: Array=_board().get("history",[])
	for report: Dictionary in history.slice(maxi(0,history.size()-3)):
		flow.add_child(P.pastille("%s · %s"%[SeasonLabel.label(report.get("season")),V.entier(report.get("score"))],Charte.REPOS,"settings","Bilan d'organisation",15,"",_fenetre_organisation))
	return flow

func _decisions(list: VBoxContainer, colonnes_projets: int) -> void:
	var board := _board();var finance := _finance()
	list.add_theme_constant_override("separation",12)
	list.add_child(V.titre("Priorité","target"))
	var priorities := GridContainer.new();priorities.columns=2;priorities.add_theme_constant_override("h_separation",10);priorities.add_theme_constant_override("v_separation",10);list.add_child(priorities)
	for key: String in PRIORITIES:
		priorities.add_child(V.carte_priorite(key,PRIORITIES[key],board.get("priority")==key,_can_act(),func():_set_priority(key)))
	if meeting_data.get("completed",false):
		list.add_child(P.pastille("Décision enregistrée",Charte.GAIN,"check","",16,"BoardMeetingDone"))
	else:
		list.add_child(V.pilule("CONFIRMER LES PRIORITÉS ACTUELLES","check",_acknowledge,_ack_available(),"BoardMeetingAck"))
	list.add_child(V.titre("Organisation","settings"))
	var projects := GridContainer.new();projects.columns=colonnes_projets;projects.add_theme_constant_override("h_separation",10);projects.add_theme_constant_override("v_separation",10);list.add_child(projects)
	for project: Dictionary in board.get("projectOptions",[]):
		var known_cost := _number(project.get("cost"));var cash_known := _number(finance.get("cash"))
		var enabled: bool=_can_act() and not project.get("used",false) and known_cost and cash_known and float(finance.cash)>=float(project.cost)
		projects.add_child(V.carte_projet(project,finance.get("cash"),enabled,func():_request_project(str(project.get("id","")))))
	_objectif_visuel(list)

## Nouveau jalon : type en puces à pictogramme, cible et échéance en champs chiffrés, ENREGISTRER.
func _objectif_visuel(parent: VBoxContainer) -> void:
	parent.add_child(V.titre("Nouveau jalon","flag"))
	var strategy := _strategy()
	var goals: Array=strategy.get("board",{}).get("objectives",[])
	var used_types: Array=goals.map(func(goal: Dictionary):return str(goal.get("type","")))
	var open_types: Array=TYPES.keys().filter(func(type: String):return not used_types.has(type))
	var week := _week();var end := int(strategy.get("finance",{}).get("weeksPerSeason",0))
	var enabled: bool=_can_act() and goals.size()<8 and not open_types.is_empty() and end>week
	if open_types.is_empty():parent.add_child(P.pastille("Tous les jalons sont posés",Charte.GAIN,"check","",15));return
	if not open_types.has(draft_type):draft_type=str(open_types[0])
	var chips := HFlowContainer.new();chips.name="BoardObjectiveType";chips.add_theme_constant_override("h_separation",8);chips.add_theme_constant_override("v_separation",8);parent.add_child(chips)
	for type: String in open_types:
		var chip := V.pilule(V.COURTS_JALON.get(type,type),V.ICONES_JALON.get(type,"target"),func():draft_type=type;_draw(),enabled,"BoardObjectiveType_"+type)
		if type==draft_type:
			for state in ["normal","hover","pressed","disabled"]:
				var style := Charte.style_pilule(Charte.PANNEAU_2.lerp(Charte.CONFIANCE,.2),Charte.CONFIANCE,16,6);style.set_border_width_all(2);chip.add_theme_stylebox_override(state,style)
		chips.add_child(chip)
	var fields := S.G.h(10);parent.add_child(fields)
	fields.add_child(V.TV.icone("target",22,Charte.IVOIRE_2))
	var target := SpinBox.new();target.name="BoardObjectiveTarget";target.min_value=0;target.max_value=1000000000;target.value=draft_target;target.custom_minimum_size=Vector2(130,38);target.editable=enabled;target.tooltip_text="Cible"
	target.value_changed.connect(func(value: float):draft_target=value);fields.add_child(target)
	fields.add_child(V.TV.icone("calendar",22,Charte.IVOIRE_2))
	var deadline := SpinBox.new();deadline.name="BoardObjectiveDeadline";deadline.min_value=week+1;deadline.max_value=maxi(end,week+1);deadline.prefix="S";draft_deadline=clampi(draft_deadline,week+1,maxi(end,week+1));deadline.value=draft_deadline;deadline.custom_minimum_size=Vector2(110,38);deadline.editable=enabled;deadline.tooltip_text="Échéance"
	deadline.value_changed.connect(func(value: float):draft_deadline=int(value));fields.add_child(deadline)
	var submit := V.pilule("ENREGISTRER","check",_create_objective,enabled,"BoardObjectiveCreate");S.G.fill(submit);fields.add_child(submit)

func _pied(frame: VBoxContainer) -> void:
	var row := S.G.h(12);frame.add_child(row)
	var done: bool=bool(meeting_data.get("completed",false))
	if not done:row.add_child(P.pastille("Décision à prendre",Charte.IVOIRE_2,"lock","",16,"BoardRoomPending"))
	var close := S.button("CONTINUER",_close_meeting,done and not app.waiting,true);close.name="BoardRoomClose";S.G.fill(close);row.add_child(close)

func _panneau(parent: Node, largeur: float, padding: int = 18) -> VBoxContainer:
	var column := S.panel(parent,padding);var shell: Control=column.get_parent().get_parent()
	shell.custom_minimum_size.x=largeur;shell.add_theme_stylebox_override("panel",Charte.ombrer(Charte.style_panneau(Charte.PANNEAU,Charte.RAYON_PANNEAU,0),Charte.RAYON_PANNEAU))
	return column

func _draw_visuel(variante: String) -> void:
	var frame := S.frame(ui,22)
	S.heading(frame,model.get("club",{}),"Le point avec la direction","")
	if variante=="A":
		# A : deux panneaux, la salle au centre. État à gauche (anneaux, tuiles, jalons en cartes), décisions en cartes à droite.
		var body := S.G.h(18);S.G.fill(body,true);frame.add_child(body)
		var left := _panneau(body,560)
		var facts := S.G.scroll(left);S.G.fill(facts.get_parent(),true);facts.add_theme_constant_override("separation",12)
		facts.add_child(_anneaux(150.0))
		facts.add_child(_signaux())
		var moyens_titre := V.rangee(8);moyens_titre.add_child(V.titre("Moyens","money"));moyens_titre.add_child(_info_moyens());facts.add_child(moyens_titre)
		facts.add_child(_tuiles_moyens(2))
		facts.add_child(V.titre("Jalons","flag"))
		_cartes_jalons(facts,false)
		if not _board().get("history",[]).is_empty():
			facts.add_child(V.titre("Bilans","settings"));facts.add_child(_bilans())
		var air := Control.new();air.mouse_filter=Control.MOUSE_FILTER_IGNORE;S.G.fill(air,true);body.add_child(air)
		var right := _panneau(body,560)
		var list := S.G.scroll(right);list.get_parent().name="BoardRoomActionsScroll";S.G.fill(list.get_parent(),true)
		_decisions(list,2)
	else:
		# B : bandeau d'état en haut (anneaux + tuiles en ligne), frise de la saison avec les jalons en bas à gauche,
		# décisions en cartes à droite ; la salle reste visible au centre gauche.
		var band := _panneau(frame,0,16)
		var top := V.rangee(16);band.add_child(top)
		top.add_child(_anneaux(118.0))
		var right_band := V.colonne(10);right_band.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right_band.size_flags_vertical=Control.SIZE_SHRINK_CENTER;top.add_child(right_band)
		var tiles_row := V.rangee(8);tiles_row.add_child(_tuiles_moyens(5));tiles_row.add_child(_info_moyens());right_band.add_child(tiles_row)
		var signals := _signaux();signals.add_child(_bilans());right_band.add_child(signals)
		var body := S.G.h(18);S.G.fill(body,true);frame.add_child(body)
		var left := V.colonne(14);S.G.fill(left,true);body.add_child(left)
		var air := Control.new();air.mouse_filter=Control.MOUSE_FILTER_IGNORE;S.G.fill(air,true);left.add_child(air)
		var season := _panneau(left,0,16)
		season.add_child(V.titre("Saison · jalons","calendar"))
		var jalons: Array=[]
		for goal: Dictionary in _board().get("objectives",[]):
			jalons.append({"goal":goal,"id":"BoardFriseGoal_"+str(goal.get("id","")).validate_node_name(),"action":func():_fenetre_jalon(goal)})
		season.add_child(V.frise(_week(),int(_finance().get("weeksPerSeason",_week()+1)),jalons))
		var cards := HFlowContainer.new();cards.add_theme_constant_override("h_separation",10);cards.add_theme_constant_override("v_separation",10);season.add_child(cards)
		_cartes_jalons(cards,true)
		for card in cards.get_children():card.custom_minimum_size.x=maxf(card.custom_minimum_size.x,320)
		var right := _panneau(body,600)
		var list := S.G.scroll(right);list.get_parent().name="BoardRoomActionsScroll";S.G.fill(list.get_parent(),true)
		_decisions(list,3)
	_pied(frame)
