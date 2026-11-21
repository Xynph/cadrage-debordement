extends SceneTree
const BoardView = preload("res://ui/contextual/board_room_view.gd")
const BoardRoom = preload("res://ui/contextual/rooms/board_room.gd")
const Identity = preload("res://ui/contextual/rooms/room_identity.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const Charte = preload("res://ui/charte.gd")

class Host extends Control:
	var model: Dictionary = {}
	var waiting := false
	var last_error := ""
	var confirmations: Array = []
	func confirm_decision(command: String, payload: Dictionary, title: String, question: String, callback: Callable) -> void:
		confirmations.append({"command":command,"payload":payload.duplicate(true),"title":title,"question":question,"callback":callback})

class TestDirector extends Node:
	var app: Host
	var sent: Array = []
	var closed := false
	func command(command_name: String, payload: Dictionary = {}) -> void:
		if not app.waiting: sent.append([command_name,payload.duplicate(true)])
	func close_room() -> void: closed = true
	func _refresh_controls() -> void: pass

var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL ",message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for i in 5: await process_frame
func fixture() -> Dictionary:
	return {"club":{"id":7,"name":"Club direction","color":"#1d6389","goal":"Projet du club"},"live":null,"meta":{"phase":"league","trust":72},"clubLife":{"clubStrategy":{"context":{"season":2,"week":8,"club":7},"available":true,"finance":{"cash":45000,"weeklyWages":12000,"weeklyIncome":160000,"weeklyCosts":13000,"baseForecast":70000,"remainingWeeks":21,"weeksPerSeason":29,"notice":"Montants de jeu fictifs. Projection hors primes futures.","boardHistory":[]},"board":{"priority":"stabilite","organizationScore":55,"readiness":{"warnings":["Signal enregistré"],"available":25,"coverage":80},"objectives":[{"id":"goal:points","type":"points","target":40,"deadline":20,"status":"pending"}],"metrics":{"points":22,"wins":4,"rank":9,"cash":45000},"projectOptions":[{"id":"video","label":"Analyse vidéo","cost":12000,"used":false},{"id":"medical","label":"Organisation médicale","cost":18000,"used":true}],"history":[{"season":1,"score":48}],"notice":"Organisation distincte de la confiance. Aucun bonus de match."}}}}

func window_has(view: Control, inside: String) -> bool:
	var window := view.find_child("BoardRoomWindow",true,false)
	return window!=null and window.is_visible_in_tree() and window.find_child(inside,true,false)!=null

## Chaque anneau, tuile, bilan, jalon (frise et carte) ouvre sa petite fenêtre ; Échap, ✕ et clic à côté la ferment.
func clicks(view: Control, director: TestDirector, host: Host) -> void:
	var targets := {"BoardRoomTrust":"BoardWindowTrust","BoardRoomOrganization":"BoardWindowOrganization","BoardHistory_0":"BoardWindowOrganization",
		"BoardFriseGoal_goal_points":"BoardWindowGoalNow","BoardObjective_goal_points":"BoardWindowGoalNow"}
	for key in ["cash","weeklyWages","weeklyIncome","weeklyCosts","baseForecast"]:targets["BoardFinance_"+key]="BoardWindowCash"
	var closers := ["escape","cross","veil"]
	var i := 0
	for target: String in targets:
		var button: BaseButton = view.find_child(target,true,false)
		check(button!=null and button.is_visible_in_tree() and not button.disabled and button.mouse_default_cursor_shape==Control.CURSOR_POINTING_HAND,"clickable "+target)
		if button==null:continue
		button.pressed.emit();await settle()
		check(window_has(view,targets[target]),target+" opens its window ("+targets[target]+")")
		check(PetiteFenetre.ouverte(self)!=null,target+" window is registered for Escape")
		var how: String=closers[i%closers.size()];i+=1
		match how:
			"escape":check(PetiteFenetre.fermer_derniere(self),"Escape closes "+target)
			"cross":(view.find_child("BoardRoomWindowClose",true,false) as BaseButton).pressed.emit()
			"veil":(view.find_child("BoardRoomWindowVeil",true,false) as BaseButton).pressed.emit()
		await settle()
		check(view.find_child("BoardRoomWindow",true,false)==null and PetiteFenetre.ouverte(self)==null,how+" closes the window of "+target)
	check(not PetiteFenetre.fermer_derniere(self),"Escape without window is left to the pause menu")
	check(director.sent.is_empty() and host.confirmations.is_empty(),"opening windows sends nothing")
	# Cartes de décision : priorités, projets, confirmation, nouveau jalon.
	for key in ["performance","finances","effectif","stabilite"]:
		director.sent.clear()
		(view.find_child("BoardPriority_"+key,true,false) as BaseButton).pressed.emit()
		check(director.sent.size()==1 and director.sent[0][0]=="club_board_priority" and director.sent[0][1].key==key,"priority card "+key+" sends its command")
	director.sent.clear()
	(view.find_child("BoardProject_video",true,false) as BaseButton).pressed.emit()
	check(director.sent.is_empty() and host.confirmations.size()==1 and host.confirmations[0].payload.kind=="video","project card asks the confirmation first")
	host.confirmations.clear()
	var medical: BaseButton = view.find_child("BoardProject_medical",true,false)
	check(medical!=null and medical.disabled,"engaged project card is shown but locked")
	(view.find_child("BoardMeetingAck",true,false) as BaseButton).pressed.emit()
	check(not director.sent.is_empty() and director.sent.back()==["club_meeting_ack",{"meetingId":"board:test"}],"confirm card acknowledges the meeting")
	director.sent.clear()
	(view.find_child("BoardObjectiveType_wins",true,false) as BaseButton).pressed.emit();await settle()
	check(view.draft_type=="wins","objective type chip selects its type")
	(view.find_child("BoardObjectiveCreate",true,false) as BaseButton).pressed.emit()
	check(director.sent.size()==1 and director.sent[0][0]=="club_board_objective" and director.sent[0][1].type=="wins","save chip sends the new milestone")
	director.sent.clear()

func run() -> void:
	var host := Host.new()
	host.model = fixture()
	host.model.calendar=[{"id":"f1","season":2,"week":3,"home":{"id":7},"away":{"id":3},"score":[20,10]},{"id":"f2","season":2,"week":12,"home":{"id":4},"away":{"id":7}},{"id":"f3","season":2,"week":5,"home":{"id":4},"away":{"id":9}},{"id":"f0","season":1,"week":9,"home":{"id":7},"away":{"id":9}}]
	host.model.clubLife.clubMeetings={"scene":{"id":"board:test","kind":"board","completed":false,"ackAllowed":true}}
	var meeting_data := {"meetingId":"board:test","completed":false,"ackAllowed":true}
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var director := TestDirector.new(); director.app = host; host.add_child(director)
	var view := BoardView.new(); view.director = director
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); host.add_child(view)
	view.update_frame(host.model,meeting_data)
	await settle()
	var before := JSON.stringify(host.model)
	check(view.find_child("BoardRoomTrust",true,false).tooltip_text.contains("72"),"true confidence is shown")
	check(view.find_child("BoardRoomOrganization",true,false).tooltip_text.contains("55"),"organization stays distinct")
	check(view.find_child("BoardObjective_goal_points",true,false).tooltip_text.contains("22"),"objective uses actual measured points")
	check(view.find_child("BoardRoomFinanceNotice",true,false).tooltip_text.contains("Projection") and not view.find_child("BoardRoomFinanceNotice",true,false).tooltip_text.contains("fictifs"),"useful forecast context without fiction warning")
	var title: Label = view.find_child("BoardRoomTitle",true,false)
	check(title!=null and title.get_theme_font("font")==Charte.TITRE_FICHE and title.get_theme_color("font_color")==Charte.IVOIRE,"page title in Anton, ivory (gold kept for Continue)")
	var frise: Control = view.find_child("BoardSeasonFrise",true,false)
	check(frise!=null and frise.fin==29 and frise.semaine==8 and frise.matchs.map(func(m: Dictionary):return m.semaine)==[3,12],"season frieze: actual weeks and only the club's own fixtures of this season")
	check(frise!=null and frise.get_global_rect().size.y<=130.0,"frieze height follows the stacked milestones, no empty band")
	await clicks(view,director,host)
	check(JSON.stringify(host.model)==before and director.sent.is_empty(),"visits and projections are pure")
	view._acknowledge();check(director.sent.back()==["club_meeting_ack",{"meetingId":"board:test"}],"confirming existing priorities uses only the active server meeting ID")
	director.sent.clear()
	view._set_priority("finances")
	check(director.sent.back()==["club_board_priority",{"context":{"season":2,"week":8,"club":7},"key":"finances"}],"priority uses real context")
	director.sent.clear()
	view._request_project("video")
	check(director.sent.is_empty() and host.confirmations.size()==1,"investment requires confirmation")
	var quote: Dictionary = host.confirmations.back()
	check(quote.command=="club_board_project" and quote.payload.kind=="video" and quote.payload.confirmed and quote.question.contains("12"),"confirmation carries exact offered project cost")
	quote.callback.call()
	check(director.sent.size()==1 and director.sent[0][1].kind=="video","confirmed project uses existing command once")
	view._request_project("medical");view._request_project("forged")
	check(host.confirmations.size()==1,"used and unoffered projects cannot be financed")
	view._request_project("video");var stale: Dictionary = host.confirmations.back()
	host.model.clubLife.clubStrategy.finance.cash=100
	stale.callback.call()
	check(director.sent.size()==1,"funds rechecked at confirmation")
	host.model.clubLife.clubStrategy.finance.cash=45000
	view.draft_target=123;view.draft_deadline=17;view.draft_type="cash"
	host.last_error="Décision refusée par le serveur."
	view.update_frame(host.model,meeting_data);await settle()
	check(view.draft_target==123 and view.draft_deadline==17 and view.draft_type=="cash","refusal preserves the local objective draft")
	check(view.find_child("BoardRoomServerError",true,false).text==host.last_error,"server refusal remains visible")
	host.waiting=true;view.update_frame(host.model,meeting_data);await settle()
	var sent_count := director.sent.size();view._set_priority("effectif");view._create_objective();view._request_project("video");view._acknowledge()
	check(director.sent.size()==sent_count,"waiting blocks commands and confirmations")
	check(not view.find_child("BoardObjectiveTarget",true,false).editable,"waiting locks numeric draft")
	host.waiting=false;host.last_error=""
	host.model.clubLife.clubStrategy.context.week=9;view.update_frame(host.model,meeting_data);await settle()
	check(view.draft_target!=123 and view.draft_deadline>9,"new context resets prior draft")
	host.model.clubLife.clubStrategy.board.metrics.erase("points");view.update_frame(host.model,meeting_data);await settle()
	check(view.find_child("BoardObjective_goal_points",true,false).tooltip_text.contains("— /") and not view.find_child("BoardObjective_goal_points",true,false).tooltip_text.contains(" 0 /"),"missing metric is never fabricated as zero")
	for size in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		root.content_scale_size=size;root.size=size;await settle()
		var screen := Rect2(Vector2.ZERO,Vector2(size)).grow(.5)
		var close: Button = view.find_child("BoardRoomClose",true,false)
		check(screen.encloses(close.get_global_rect()),"close stays reachable at "+str(size))
		var scroll: ScrollContainer = view.find_child("BoardRoomActionsScroll",true,false)
		check(scroll.get_global_rect().size.y>250 and scroll.get_global_rect().end.x<=size.x,"actions scroll stays inside at "+str(size))
		for button: BaseButton in view.find_children("*","BaseButton",true,false):
			if not button.is_visible_in_tree():continue
			var r := button.get_global_rect()
			check(r.size.x>=24.0 and r.size.y>=24.0,"target %s is at least 24 px at %s"%[button.name,size])
			if not scroll.is_ancestor_of(button):check(screen.encloses(r),"%s stays on screen at %s"%[button.name,size])
		for label: Label in view.find_children("*","Label",true,false):
			if label.is_visible_in_tree() and not scroll.is_ancestor_of(label) and not label.text.is_empty():
				check(screen.encloses(label.get_global_rect()),"label %s not cut at %s"%[label.text,size])
	view.find_child("BoardRoomClose",true,false).pressed.emit();check(not director.closed,"required meeting cannot be left before server completion")
	host.model.clubLife.clubMeetings.scene.completed=true
	view.update_frame(host.model,{"meetingId":"board:test","completed":true,"ackAllowed":false});await settle()
	var done_count := director.sent.size();view._set_priority("performance");view._create_objective();view._request_project("video");view._acknowledge()
	check(director.sent.size()==done_count,"completed meetings disable further decisions")
	view.find_child("BoardRoomClose",true,false).pressed.emit();check(director.closed,"server-completed meeting can return to management")
	var room := BoardRoom.new();room.configure({"name":"Actual club","color":"#b14c61"},null)
	var viewport := SubViewport.new();viewport.own_world_3d=true;root.add_child(viewport);viewport.add_child(room);await settle()
	check(room.get_meta("primary_color")==Color("b14c61") and room.crest_texture==null,"actual identity and no fabricated missing crest")
	check(room.find_children("*","Camera3D",true,false).size()==1,"room has one camera")
	check(room.find_children("*","Control",true,false).is_empty(),"room contains geometry only")
	room.free();viewport.free()
	var neutral := BoardRoom.new();neutral.configure({},null);check(neutral.get_meta("primary_color")==Identity.NEUTRAL_PRIMARY,"missing color is neutral");neutral.free()
	host.queue_free();await settle()
	print("BOARD_ROOM_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures==0 else 1)
