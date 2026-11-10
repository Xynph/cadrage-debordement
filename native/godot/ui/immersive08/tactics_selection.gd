extends RefCounted
## Notes et affectations de la Tactique : projections moteur exclusivement.
const C = preload("res://ui/immersive08/components.gd")

class PlayerButton extends Button:
	var drag_player := ""
	var source_slot := -1
	var target_slot := -1
	var drag_caption := ""
	var make_payload: Callable
	var accepts_payload: Callable
	var apply_payload: Callable
	func _input(event: InputEvent) -> void:
		var viewport:=get_viewport()
		if event.is_action_pressed("ui_cancel") and viewport.gui_is_dragging():
			viewport.gui_cancel_drag()
			viewport.set_input_as_handled()
	func _get_drag_data(_at: Vector2) -> Variant:
		if drag_player.is_empty() or not make_payload.is_valid(): return null
		var data: Variant = make_payload.call(drag_player,source_slot)
		if data == null: return null
		var preview := PanelContainer.new()
		preview.add_theme_stylebox_override("panel",C.box(C.RAISED,C.MINT,5,12))
		preview.add_child(C.label(drag_caption,20,C.IVORY))
		preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
		set_drag_preview(preview)
		return data
	func _can_drop_data(_at: Vector2,data: Variant) -> bool:
		return target_slot>=0 and accepts_payload.is_valid() and accepts_payload.call(data,target_slot)
	func _drop_data(_at: Vector2,data: Variant) -> void:
		if _can_drop_data(_at,data) and apply_payload.is_valid():apply_payload.call(data,target_slot)

static func state(app: Control) -> Dictionary:
	if not app.management_ui.get("tactics_reading") is Dictionary:
		app.management_ui.tactics_reading={"mode":"bench","player_id":"","scroll":0,"focus":""}
	return app.management_ui.tactics_reading

static func slot(model: Dictionary,index: int) -> Dictionary:
	for assignment: Dictionary in model.get("selection",{}).get("slots",[]):
		if assignment.get("slot")==index:return assignment
	return {}

static func player(model: Dictionary,id: String) -> Dictionary:
	for person: Dictionary in model.get("squad",[]):
		if str(person.get("id",""))==id:return person
	return {}

static func source(model: Dictionary,id: String) -> int:
	for assignment: Dictionary in model.get("selection",{}).get("slots",[]):
		if assignment.get("playerId")==id:return int(assignment.slot)
	return -1

static func number(model: Dictionary,index: int) -> int:
	var projected: Variant=slot(model,index).get("positionNumber")
	if (projected is int or projected is float) and projected>=1 and projected<=15 and projected==int(projected):return int(projected)
	return index+1 if index>=0 and index<15 else 0

static func rating(model: Dictionary,person: Dictionary,index: int) -> Variant:
	var position:=number(model,index)
	var ratings: Variant=person.get("positionRatings")
	if position==0 or not ratings is Dictionary:return null
	var value: Variant=ratings.get(str(position))
	if not (value is int or value is float) or not is_finite(float(value)) or value<0 or value>100:return null
	return value

static func rating_text(model: Dictionary,person: Dictionary,index: int) -> String:
	var value: Variant=rating(model,person,index)
	return "—" if value==null else str(roundi(value))

static func positions(person: Dictionary) -> String:
	var result: PackedStringArray=[]
	var primary: Variant=person.get("primaryPosition")
	if primary is int or primary is float:result.append(str(int(primary)))
	for secondary: Variant in person.get("secondaryPositions",[]):
		if secondary is int or secondary is float:result.append(str(int(secondary)))
	return " · ".join(result) if not result.is_empty() else str(person.get("pos","—"))

static func editable(app: Control) -> bool:
	return not app.waiting and app._live().is_empty() and app.model.get("meta",{}).get("phase")!="ended"

static func eligible(app: Control,id: String,index: int) -> bool:
	return editable(app) and not player(app.model,id).is_empty() and id in slot(app.model,index).get("eligibleIds",[])

static func payload(app: Control,id: String,from: int) -> Variant:
	if not editable(app) or player(app.model,id).is_empty() or source(app.model,id)!=from:return null
	return {"kind":"tactics_player","player_id":id,"source_slot":from,"club_id":app.model.get("club",{}).get("id")}

static func can_drop(app: Control,data: Variant,target: int) -> bool:
	if not data is Dictionary or data.get("kind")!="tactics_player":return false
	if not data.get("player_id") is String or not data.get("source_slot") is int:return false
	var club_id:Variant=app.model.get("club",{}).get("id")
	if typeof(data.get("club_id"))!=typeof(club_id) or data.get("club_id")!=club_id:return false
	var id: String=data.player_id
	if source(app.model,id)!=data.source_slot or slot(app.model,target).get("playerId")==id:return false
	return eligible(app,id,target)

static func apply(app: Control,data: Variant,target: int) -> bool:
	if not can_drop(app,data,target):return false
	app.selected_slot=target
	var reading:=state(app)
	reading.player_id="";reading.focus="LineupSlot%02d" % (target+1)
	app._command("set_lineup",{"playerId":data.player_id,"slot":target})
	return true

static func wire(button: PlayerButton,app: Control,id: String,index: int,target: int,caption: String) -> void:
	button.drag_player=id;button.source_slot=index;button.target_slot=target;button.drag_caption=caption
	button.make_payload=func(player_id: String,from: int):return payload(app,player_id,from)
	button.accepts_payload=func(data: Variant,to: int):return can_drop(app,data,to)
	button.apply_payload=func(data: Variant,to: int):return apply(app,data,to)
