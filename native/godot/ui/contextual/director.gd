extends Node
const S = preload("res://ui/contextual/skin.gd")
const Locker = preload("res://ui/contextual/locker_view.gd")
const Live = preload("res://ui/contextual/live_view.gd")
const Conversation = preload("res://ui/contextual/conversation_view.gd")
const Training = preload("res://ui/contextual/training_view.gd")
var app: Control
var overlay: Control
var view: Control
var error_label: Label
var kind := ""
var scene_key := ""
var training_open := false
var _waiting := false
var _shell_visible := true
var _coach_visible := true

func setup(owner: Control) -> void:
	app = owner
	name = "ContextualDirector"
	set_process_input(true)
	set_process(true)

func active() -> bool:
	return is_instance_valid(overlay)

func match_immersed() -> bool:
	if app == null: return false
	return not _talk().is_empty() or not _live().is_empty()

func active_meeting() -> bool:
	return not _meeting().is_empty()

func _meeting() -> Dictionary:
	var club_life: Dictionary = app.model.get("clubLife", {})
	var value: Variant = club_life.get("clubMeetings", {}).get("scene")
	if not value is Dictionary: return {}
	if value.get("kind") != "press": return value
	# The appointment remains mandatory in the worker. Only its mail opens the room.
	var origin := str(app.get_meta("press_mail_origin", ""))
	if origin.is_empty(): return {}
	var press: Dictionary = club_life.get("press", {})
	if value.get("completed", false):
		var outcome: Variant = press.get("lastOutcome")
		return value if outcome is Dictionary and outcome.get("invitationId") == origin and outcome.get("context") == value.get("context") else {}
	return value if press.get("context") == value.get("context") and press.get("conference", {}).get("invitationId") == origin else {}

func _talk() -> Dictionary:
	var value: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
	return value if value is Dictionary else {}

func _live() -> Dictionary:
	var value: Variant = app.model.get("live")
	return value if value is Dictionary else {}

func sync(_received_command: String = "", _response_ok: bool = true) -> bool:
	if app == null: return false
	var next := ""
	var key := ""
	var data: Dictionary = {}
	var talk := _talk()
	var live := _live()
	var invitation: Variant = app.model.get("clubLife", {}).get("sceneInvitations", {}).get("active")
	if not talk.is_empty():
		next = "locker"
		data = talk
		key = str(talk.get("key", "")) + ":" + str(talk.get("phase", ""))
	elif not live.is_empty():
		next = "live"
		key = "live"
	elif invitation is Dictionary:
		next = "conversation"
		data = invitation
		key = str(invitation.get("id", ""))
	elif not _meeting().is_empty():
		var meeting := _meeting()
		next = str(meeting.get("kind", ""))
		data = meeting.duplicate(true)
		data["meetingId"] = meeting.get("id")
		key = next + ":" + str(meeting.get("id", ""))
	elif training_open and app.model.get("club") is Dictionary:
		next = "training"
		key = "training"
	if next.is_empty():
		_close()
		return false
	if next in ["press", "medical", "board", "conversation"]: training_open = false
	if next in ["locker", "live"]:
		training_open = false
		app.route = "Match"
	if next != kind or key != scene_key or not active(): _open(next, key, data)
	if is_instance_valid(app.root_content): app.root_content.hide()
	if is_instance_valid(app.coach): app.coach.hide()
	if next == "live":
		app.match_screen = view
		view.update_frame(app.model)
		if not live.get("paused", false) and not live.get("finished", false):
			if app.timer.is_stopped(): app.timer.start()
		else: app.timer.stop()
	else:
		app.timer.stop()
		view.update_frame(app.model, data)
	_refresh_controls()
	return true

func render_if_needed() -> bool:
	return sync()

func _open(value: String, key: String, data: Dictionary) -> void:
	if not active():
		_shell_visible = is_instance_valid(app.root_content) and app.root_content.visible
		_coach_visible = is_instance_valid(app.coach) and app.coach.visible
	_close(false)
	kind = value
	scene_key = key
	overlay = Control.new()
	overlay.name = "ContextualImmersion"
	overlay.z_index = 100
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	S.full(overlay)
	app.add_child(overlay)
	match kind:
		"locker": view = Locker.new()
		"live": view = Live.new()
		"conversation": view = Conversation.new()
		"training": view = Training.new()
		"press": view = load("res://ui/contextual/press_room_view.gd").new()
		"medical": view = load("res://ui/contextual/medical_room_view.gd").new()
		"board": view = load("res://ui/contextual/board_room_view.gd").new()
	view.director = self
	S.full(view)
	overlay.add_child(view)
	var error_panel := PanelContainer.new()
	error_panel.name = "ContextualActionError"
	error_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	error_panel.offset_left = -420
	error_panel.offset_right = 420
	error_panel.offset_top = 3
	error_panel.add_theme_stylebox_override("panel", S.G.T.box(Color("632e26"), 3, Color("e7ad92")))
	overlay.add_child(error_panel)
	error_label = S.wrap("", 14, S.TEXT)
	error_panel.add_child(error_label)
	if kind == "live": app.match_screen = view
	elif is_instance_valid(app.match_screen) and app.match_screen != view: app.match_screen = null
	_waiting = not bool(app.waiting)

func _close(restore: bool = true) -> void:
	var was_active := active()
	if is_instance_valid(view) and app.match_screen == view: app.match_screen = null
	if is_instance_valid(overlay):
		app.remove_child(overlay)
		overlay.queue_free()
	overlay = null
	view = null
	error_label = null
	kind = ""
	scene_key = ""
	if restore and was_active:
		if is_instance_valid(app.root_content): app.root_content.visible = _shell_visible
		if is_instance_valid(app.coach): app.coach.visible = _coach_visible

func command(command_name: String, payload: Dictionary = {}) -> void:
	if app.waiting: return
	app._command(command_name, payload)
	_refresh_controls()

func open_invitation(id: String) -> void:
	if not match_immersed(): command("scene_invitation_open", {"id":id})

func open_training() -> void:
	if active_meeting(): return
	if match_immersed() or not app.model.get("club") is Dictionary or app.model.get("meta", {}).get("phase") == "ended": return
	training_open = true
	sync()

func open_room(room_kind: String, _data: Dictionary = {}) -> void:
	# Only the current persisted appointment may open a mandatory room.
	if not app.waiting and str(_meeting().get("kind", "")) == room_kind: sync()

func close_room() -> void:
	var meeting := _meeting()
	if app.waiting or not meeting.get("completed", false): return
	command("club_meeting_continue", {"meetingId":meeting.get("id")})

func close_training() -> void:
	if app.waiting: return
	training_open = false
	_close()
	app._render(false)

func _process(_delta: float) -> void:
	if not active(): return
	# Coach refresh is deferred by the shell and must never cover these scenes.
	if is_instance_valid(app.coach): app.coach.hide()
	if is_instance_valid(app.root_content): app.root_content.hide()
	if _waiting != bool(app.waiting): _refresh_controls()
	if is_instance_valid(error_label):
		error_label.text = str(app.last_error)
		error_label.get_parent().visible = not error_label.text.is_empty()

func _refresh_controls() -> void:
	if not active(): return
	_waiting = bool(app.waiting)
	for control in overlay.find_children("*", "BaseButton", true, false):
		if control.has_meta("contextual_enabled"):
			control.disabled = _waiting or not bool(control.get_meta("contextual_enabled"))

func _input(event: InputEvent) -> void:
	if not active() or not event is InputEventKey or not event.pressed: return
	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if (event.ctrl_pressed and code == KEY_K) or (event.alt_pressed and code in [KEY_LEFT, KEY_RIGHT]) or code in [KEY_F1, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()

func install_entrypoints() -> void:
	if active() or not is_instance_valid(app.root_content): return
	if app.route == "Réception":
		var parent: Node = app.body
		if parent == null or parent.find_child("ContextualInvitations", true, false) != null: return
		var pending: Array = app.model.get("clubLife", {}).get("sceneInvitations", {}).get("invitations", []).filter(func(item: Dictionary): return item.get("status") == "pending" and item.get("available", false))
		if pending.is_empty(): return
		var list := S.G.v(8)
		list.name = "ContextualInvitations"
		parent.add_child(list)
		parent.move_child(list, 0)
		list.add_child(S.G.section("Les invitations du club"))
		for invitation: Dictionary in pending:
			var row := S.G.h(12)
			list.add_child(row)
			var words := S.G.wrap(str(invitation.get("title", "Invitation")) + "\n" + str(invitation.get("reason", "")), 14)
			S.G.fill(words)
			row.add_child(words)
			row.add_child(S.G.button("OUVRIR", func(): open_invitation(str(invitation.id))))
	elif app.route == "Préparation":
		var parent: Node = app.root_content.find_child("PreparationEntrainement", true, false)
		if parent == null and app.management_ui.get("preparation", {}).get("tab", 0) == 2:
			parent = app.body
		if parent != null and parent.find_child("ContextualObserveTraining", true, false) == null:
			_add_training_entry(parent)
	elif app.route == "Travail du club":
		if is_instance_valid(app.body) and app.body.find_child("ContextualObserveTraining", true, false) == null: _add_training_entry(app.body)

func _add_training_entry(parent: Node) -> void:
	var button := S.G.button("OBSERVER LA PRÉPARATION", open_training)
	button.name = "ContextualObserveTraining"
	button.disabled = not _live().is_empty() or app.model.get("meta", {}).get("phase") == "ended"
	parent.add_child(button)
	parent.move_child(button, 0)
