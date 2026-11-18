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

## Après-match façon FM (18/11/2026) : la conférence courte d'après-match (créneau « apres ») n'est pas un rendez-vous
## du club, mais elle se tient dans la même salle de presse, ouverte depuis son courrier ou juste après le résultat.
## Vide sinon. `completed` : réponses publiées (par le manager ou Gabi), la salle attend « Continuer ».
func postmatch_press() -> Dictionary:
	var origin := str(app.get_meta("press_mail_origin", ""))
	if origin.is_empty(): return {}
	var press: Dictionary = app.model.get("clubLife", {}).get("press", {})
	var context: Variant = press.get("context")
	var conference: Dictionary = press.get("conference", {})
	if conference.get("available", false) and conference.get("invitationId") == origin and context is Dictionary and context.get("slot") == "apres":
		return {"postmatch":true, "completed":false, "invitationId":origin}
	var outcome: Variant = press.get("lastOutcome")
	if kind == "press" and outcome is Dictionary and outcome.get("invitationId") == origin and outcome.get("context", {}).get("slot") == "apres":
		return {"postmatch":true, "completed":true, "invitationId":origin}
	return {}

## Rendez-vous du club obligatoire qui bloque les autres actions (en cours ou premier de la file), vide sinon.
func blocking_meeting() -> Dictionary:
	var meetings: Dictionary = app.model.get("clubLife", {}).get("clubMeetings", {})
	var scene: Variant = meetings.get("scene")
	if scene is Dictionary: return scene
	var queue: Array = meetings.get("queue", [])
	return queue[0] if not queue.is_empty() and queue[0] is Dictionary else {}

## Nom d'un rendez-vous du club pour le joueur : « la conférence de presse », « le point médical »…
static func meeting_label(meeting: Dictionary) -> String:
	match str(meeting.get("kind", "")):
		"press": return "la conférence de presse"
		"medical": return "le point médical"
		"board": return "le rendez-vous avec la direction"
	return "le rendez-vous du club"

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
	# Match en temps forts : le dernier temps fort de la période se regarde avant la
	# causerie ou le débrief. La régie rappelle `sync` quand il est fini.
	if not talk.is_empty() and kind == "live" and active() and not live.is_empty() and view.has_method("retient_la_causerie") and view.retient_la_causerie(live):
		talk = {}
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
	elif not postmatch_press().is_empty():
		next = "press"
		data = postmatch_press()
		key = "press:apres:" + str(data.get("invitationId", ""))
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
	var postmatch := postmatch_press() if _meeting().is_empty() else {}
	if not postmatch.is_empty():
		if app.waiting or not postmatch.get("completed", false): return
		app.remove_meta("press_mail_origin")
		_close()
		app.route = "Réception"
		app._render(false)
		return
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

const Components = preload("res://ui/immersive08/components.gd")
const INVITATION_PANEL := Color("172321")
const INVITATION_TITLE := Color("f2ecdc")
const INVITATION_REASON := Color("abb7b1")
const INVITATION_GOLD := Color("d8c183")
const INVITATION_GAP := 12

# Mêmes corps que les lignes du courrier (reception_canvas.gd : 20 pour le titre, 17 pour le détail), mis à l'échelle
# de la fenêtre : la carte reste lisible à toutes les résolutions, au lieu des 12 px plafonnés de reading_size().
func _invitation_title_size() -> int: return maxi(13, Components.px(20))
func _invitation_reason_size() -> int: return maxi(12, Components.px(17))
func _invitation_card_width() -> int: return maxi(300, Components.px(620))

# Carte sombre de la charte (panneau #172321, filet d'accent à gauche) : le texte à gauche, l'action à droite.
func _invitation_card(card_name: String, edge: Color) -> Dictionary:
	var card := PanelContainer.new()
	card.name = card_name
	var style := StyleBoxFlat.new()
	style.bg_color = INVITATION_PANEL
	style.border_color = edge.darkened(.55)
	style.set_border_width_all(1)
	style.set_border_width(SIDE_LEFT, 4)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	return {"card": card, "row": row}
func _invitation_text(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if bold: label.add_theme_font_override("font", Components.BOLD)
	return label

func _invitation_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(Components.px(150), maxi(32, Components.px(46)))
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", _invitation_reason_size())
	button.add_theme_font_override("font", Components.BOLD)
	var states := {"normal": Color("2f5a52"), "hover": Color("3a6d63"), "pressed": Color("244a43"), "disabled": Color("26302f")}
	for key: String in states:
		var box := StyleBoxFlat.new()
		box.bg_color = states[key]
		box.border_color = Color("5f8f84") if key != "disabled" else Color("3a4744")
		box.set_border_width_all(1)
		box.set_corner_radius_all(4)
		box.content_margin_left = 14
		box.content_margin_right = 14
		button.add_theme_stylebox_override(key, box)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = INVITATION_TITLE
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	button.add_theme_stylebox_override("focus", focus)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, INVITATION_TITLE)
	button.add_theme_color_override("font_disabled_color", Color("9aa7a1"))
	button.pressed.connect(callback)
	return button

func install_entrypoints() -> void:
	if active() or not is_instance_valid(app.root_content): return
	if app.route == "Préparation":
		var parent: Node = app.root_content.find_child("PreparationEntrainement", true, false)
		if parent == null and app.management_ui.get("preparation", {}).get("tab", 0) == 2:
			parent = app.body
		if parent != null and parent.find_child("ContextualObserveTraining", true, false) == null:
			_add_training_entry(parent)
	elif app.route == "Travail du club":
		if is_instance_valid(app.body) and app.body.find_child("ContextualObserveTraining", true, false) == null: _add_training_entry(app.body)

func _add_training_entry(parent: Node) -> void:
	var button := S.G.button("VOIR L’ENTRAÎNEMENT", open_training)
	button.name = "ContextualObserveTraining"
	button.disabled = not _live().is_empty() or app.model.get("meta", {}).get("phase") == "ended"
	parent.add_child(button)
	parent.move_child(button, 0)
	_contain_entry_content(parent, button)

func _contain_entry_content(parent: Node, entry: Control) -> void:
	if parent != app.body: return
	for inner: ScrollContainer in parent.find_children("*", "ScrollContainer", true, false):
		inner.mouse_force_pass_scroll_events = false
		inner.mouse_filter = Control.MOUSE_FILTER_STOP
	# Full-height career pages were sized before these entrypoints were added.
	# Give the page the remaining space while keeping the new actions visible.
	var scroll := ScrollContainer.new()
	scroll.name = "ContextualPageWorkspace"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	S.G.fill(scroll, true)
	var content := S.G.v(0)
	S.G.fill(content, true)
	for child in parent.get_children():
		if child == entry: continue
		parent.remove_child(child)
		content.add_child(child)
	parent.add_child(scroll)
	scroll.add_child(content)
