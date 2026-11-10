extends Control
const S = preload("res://ui/contextual/skin.gd")
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
	var frame := S.frame(ui,22)
	S.heading(frame,model.get("club",{}),"Le point avec la direction","Objectifs, moyens et organisation du club")
	var body := S.G.h(18);S.G.fill(body,true);frame.add_child(body)
	var facts := S.panel(body,16);facts.get_parent().custom_minimum_size.x=346;facts.get_parent().size_flags_horizontal=Control.SIZE_FILL
	var facts_scroll := S.G.scroll(facts);S.G.fill(facts_scroll.get_parent(),true)
	var strategy := _strategy();var board: Dictionary=strategy.get("board",{});var finance: Dictionary=strategy.get("finance",{})
	facts_scroll.add_child(S.label("La situation enregistrée",21,S.GOLD))
	_metric(facts_scroll,"Confiance de la direction",model.get("meta",{}).get("trust"),"BoardRoomTrust")
	_metric(facts_scroll,"Organisation du club",board.get("organizationScore"),"BoardRoomOrganization")
	var club_goal: String=str(model.get("club",{}).get("goal",""))
	if not club_goal.is_empty():facts_scroll.add_child(S.wrap("Cap du club : "+club_goal,14))
	var error := S.wrap(str(app.last_error),14,Color("ffc0a3"));error.name="BoardRoomServerError";error.visible=not error.text.is_empty();facts_scroll.add_child(error)
	if not _local_notice.is_empty():facts_scroll.add_child(S.wrap(_local_notice,14,S.GOLD))
	facts_scroll.add_child(S.label("Les jalons suivis",18,S.GOLD))
	var goals: Array=board.get("objectives",[])
	if goals.is_empty():facts_scroll.add_child(S.wrap("Aucun jalon enregistré. Vous pouvez en définir un pour suivre votre projet.",14))
	for goal: Dictionary in goals:
		var type: String=str(goal.get("type",""));var metrics: Dictionary=board.get("metrics",{})
		var status: String={"pending":"À suivre","met":"Atteint","missed":"Manqué","unverified":"Non vérifiable"}.get(str(goal.get("status","")),"Non renseigné")
		var line := S.wrap("%s · %s\nMesure actuelle : %s · cible : %s\nÉchéance : semaine %s" % [TYPES.get(type,type),status,_display(metrics.get(type),type=="cash"),_display(goal.get("target"),type=="cash"),_display(goal.get("deadline"))],14,S.TEXT)
		line.name="BoardObjective_"+str(goal.get("id","")).validate_node_name();facts_scroll.add_child(line)
	facts_scroll.add_child(S.label("Les moyens connus",18,S.GOLD))
	for item in [["Trésorerie","cash"],["Salaires / semaine","weeklyWages"],["Revenus connus / semaine","weeklyIncome"],["Coûts connus / semaine","weeklyCosts"],["Projection de fin de saison","baseForecast"]]:
		_metric(facts_scroll,str(item[0]),finance.get(item[1]),"BoardFinance_"+str(item[1]),true)
	var notice := S.wrap(str(finance.get("notice","Montants de jeu fictifs. Aucune projection financière disponible.")),12);notice.name="BoardRoomFinanceNotice";facts_scroll.add_child(notice)
	for warning: Variant in board.get("readiness",{}).get("warnings",[]):facts_scroll.add_child(S.wrap(str(warning),14,S.GOLD))
	var history: Array=board.get("history",[])
	if not history.is_empty():
		facts_scroll.add_child(S.label("Bilans archivés",18,S.GOLD))
		for report: Dictionary in history.slice(maxi(0,history.size()-3)):
			facts_scroll.add_child(S.wrap("Saison %s · organisation %s / 100"%[_display(report.get("season")),_display(report.get("score"))],14))
	var air := Control.new();air.mouse_filter=Control.MOUSE_FILTER_IGNORE;S.G.fill(air,true);body.add_child(air)
	var actions := S.panel(body,16);actions.get_parent().custom_minimum_size.x=390;actions.get_parent().size_flags_horizontal=Control.SIZE_FILL
	var list := S.G.scroll(actions);list.get_parent().name="BoardRoomActionsScroll";S.G.fill(list.get_parent(),true)
	list.add_child(S.label("Arbitrer le projet du club",21,S.GOLD))
	if meeting_data.get("completed",false):
		list.add_child(S.wrap("Votre décision est enregistrée. Vous pouvez terminer l’échange.",15,S.GOLD))
	else:
		list.add_child(S.wrap("Après avoir examiné ce bilan, vous pouvez confirmer les priorités actuelles ou choisir un arbitrage autorisé.",14))
		var acknowledge := S.button("CONFIRMER LES PRIORITÉS ACTUELLES",_acknowledge,_ack_available(),true);acknowledge.name="BoardMeetingAck";list.add_child(acknowledge)
	list.add_child(S.wrap("Ces projets améliorent l’organisation du club. La confiance de la direction se mesure dans les bilans.",13))
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
	var close := S.button("REVENIR À LA GESTION" if meeting_data.get("completed",false) else "CONFIRMEZ VOTRE DÉCISION POUR TERMINER",_close_meeting,bool(meeting_data.get("completed",false)) and not app.waiting);close.name="BoardRoomClose";frame.add_child(close)
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
	if open_types.is_empty():parent.add_child(S.wrap("Les quatre types de jalons sont déjà enregistrés.",13));return
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
	parent.add_child(S.wrap("Cible à gauche, échéance à droite. Le jalon n’est enregistré qu’à la validation.",12))
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
			_local_notice="Le contexte ou le devis a changé. Vérifiez les moyens disponibles avant de réessayer."
			update_frame(app.model,meeting_data);return
		director.command("club_board_project",payload))

func _create_objective() -> void:
	var current := _current_strategy()
	if current.is_empty() or not TYPES.has(draft_type) or not _number(draft_target) or draft_target<0 or draft_target>1000000000:return
	var goals: Array=current.get("board",{}).get("objectives",[])
	if goals.size()>=8 or goals.any(func(goal: Dictionary):return goal.get("type")==draft_type):return
	if draft_deadline<=int(current.context.week) or draft_deadline>int(current.get("finance",{}).get("weeksPerSeason",0)):return
	director.command("club_board_objective",{"context":current.context.duplicate(true),"type":draft_type,"target":draft_target,"deadline":draft_deadline})
