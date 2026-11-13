extends Control
const S = preload("res://ui/contextual/skin.gd")
const SeasonLabel = preload("res://ui/season_label.gd")
const Press = preload("res://ui/press_view.gd")
const People = preload("res://ui/press_people_view.gd")
var director: Node
var app: Control
var model: Dictionary = {}
var data: Dictionary = {}
var meeting: Dictionary = {}
var choices: Dictionary = {}
var question_index := 0
var question_label: Label
var publish_button: Button
var room: Node3D
var ui: Control
var _draft_status: Label
var _answers: Array[Button] = []
var _context := ""
var _fingerprint := ""
var _request_in_flight := false
var _was_waiting := false

func _ready() -> void:
	name = "ContextualPress"
	app = director.app
	room = S.room(self, "press", app.model.get("club", {}))
	ui = Control.new()
	ui.name = "PressRoomInterface"
	S.full(ui)
	add_child(ui)

func update_frame(value: Dictionary, projection: Dictionary = {}) -> void:
	model = value
	data = projection if projection.get("conference") is Dictionary else value.get("clubLife", {}).get("press", {})
	meeting = projection if projection.has("meetingId") else {}
	if meeting.is_empty():
		var active: Variant = value.get("clubLife", {}).get("clubMeetings", {}).get("scene")
		if active is Dictionary and active.get("kind") == "press":
			meeting = {"meetingId":active.get("id"), "completed":active.get("completed", false), "ackAllowed":active.get("ackAllowed", false)}
	var context := _context_key(data.get("context", {}))
	if context != _context:
		_context = context
		question_index = 0
		_request_in_flight = false
		choices = {}
	if _available(): choices = Press._conference_draft(app, data)
	if not app.waiting: _request_in_flight = false
	question_index = clampi(question_index, 0, maxi(0, _questions().size() - 1))
	var fingerprint := JSON.stringify([meeting, data.get("context"), data.get("conference"), data.get("lastOutcome"), data.get("history"), data.get("people")])
	if fingerprint != _fingerprint:
		_fingerprint = fingerprint
		_render_ui()
	else: _refresh_buttons()

func _questions() -> Array:
	return data.get("conference", {}).get("questions", [])

func _available() -> bool:
	return not meeting.get("completed", false) and data.get("conference", {}).get("available", false) and _questions().size() >= 2 and _questions().size() <= 4

func _context_key(value: Dictionary) -> String:
	return "%d:%d:%d" % [int(value.get("season", -1)), int(value.get("week", -1)), int(value.get("club", -1))]

func _current_outcome() -> Dictionary:
	var outcome: Variant = data.get("lastOutcome")
	if outcome is Dictionary and _context_key(outcome.get("context", {})) == _context: return outcome
	return {}

func _render_ui() -> void:
	if not is_instance_valid(ui): return
	S.clear(ui)
	_answers.clear()
	publish_button = null
	question_label = null
	_draft_status = null
	var column := S.frame(ui, 20)
	var context: Dictionary = data.get("context", {})
	S.heading(column, model.get("club", {}), "La conférence de presse", "Saison %s · semaine %d" % [SeasonLabel.label(context.get("season", 0)), int(context.get("week", 0)) + 1])
	if _available(): _render_conference(column)
	elif not _current_outcome().is_empty(): _render_outcome(column, _current_outcome())
	else:
		var space := Control.new()
		S.G.fill(space, true)
		column.add_child(space)
		var note := S.panel(column, 16)
		note.add_child(S.wrap(str(data.get("conference", {}).get("reason", "Aucune conférence disponible dans ce contexte.")), 18, S.TEXT))
	var footer := S.G.h(16)
	column.add_child(footer)
	var notice_surface := S.panel(footer, 8)
	S.G.fill(notice_surface.get_parent().get_parent())
	var notice := S.wrap("Vos réponses ont été communiquées à la presse." if meeting.get("completed", false) else "Répondez à toutes les questions pour terminer la conférence.", 12, S.TEXT)
	notice_surface.add_child(notice)
	# The persisted meeting domain alone unlocks the exit. A local draft or
	# even an old conference receipt never completes a different meeting.
	if meeting.get("completed", false):
		var close := S.button("CONTINUER  →", director.close_room, true, true)
		close.name = "PressReturn"
		footer.add_child(close)
	_refresh_buttons()

func _render_conference(column: VBoxContainer) -> void:
	var questions := _questions()
	var question: Dictionary = questions[question_index]
	var content := S.G.h(20)
	S.G.fill(content, true)
	column.add_child(content)
	var left := S.G.v(8)
	S.G.fill(left, true)
	content.add_child(left)
	var room_space := Control.new()
	room_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(room_space, true)
	left.add_child(room_space)
	var interview := S.panel(left, 16)
	interview.get_parent().custom_minimum_size.y = 235
	var transcript := S.G.scroll(interview)
	var journalist: Dictionary = question.get("journalist", {})
	var identity := S.G.h(12)
	transcript.add_child(identity)
	var badge := People.badge(journalist)
	badge.name = "PressJournalistInitials"
	identity.add_child(badge)
	var words := S.G.v(3)
	S.G.fill(words)
	identity.add_child(words)
	var name_label := S.wrap(str(journalist.get("name", "Identité indisponible")), 22, S.GOLD)
	name_label.name = "PressJournalistName"
	words.add_child(name_label)
	var outlet := S.wrap(str(journalist.get("outlet", "")), 12, S.TEXT)
	outlet.name = "PressJournalistSource"
	words.add_child(outlet)
	var relation: Dictionary = question.get("relation", {})
	if relation.has("label"):
		transcript.add_child(S.wrap(str(relation.label) + " · %d échange(s) avec vous" % int(relation.get("encounters", 0)), 12, S.GOLD))
	question_label = S.wrap(str(question.get("question", "")), 18, S.TEXT)
	question_label.name = "PressQuestion"
	transcript.add_child(question_label)
	if question.get("followUp") is Dictionary:
		var source := S.wrap(str(question.followUp.get("label", "")), 12, S.GOLD)
		source.name = "PressArchivedSource"
		transcript.add_child(source)
	var surface := S.panel(content, 16)
	surface.get_parent().custom_minimum_size.x = 540
	surface.get_parent().size_flags_horizontal = Control.SIZE_FILL
	surface.add_child(S.label("QUESTION %d / %d" % [question_index + 1, questions.size()], 14, S.GOLD))
	surface.add_child(S.label("Votre réponse", 22))
	var list := S.G.scroll(surface)
	list.name = "PressAnswers"
	var group := ButtonGroup.new()
	for answer: Dictionary in question.get("answers", []):
		var button := S.button(str(answer.get("text", "")), func(): _choose_answer(str(question.get("id", "")), str(answer.get("id", ""))))
		button.name = "PressAnswer_" + str(question.get("id", "")) + "_" + str(answer.get("id", ""))
		button.set_meta("answer_id", str(answer.get("id", "")))
		button.set_meta("question_id", str(question.get("id", "")))
		button.tooltip_text = str(answer.get("toneLabel", "")) + " · " + str(answer.get("consequence", ""))
		button.custom_minimum_size.y = 64
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 15)
		button.toggle_mode = true
		button.button_group = group
		var base_styles := {}
		for state in ["normal", "hover", "pressed"]: base_styles[state] = button.get_theme_stylebox(state)
		button.set_meta("base_styles", base_styles)
		list.add_child(button)
		_answers.append(button)
	_draft_status = S.label("", 12, S.GOLD)
	surface.add_child(_draft_status)
	var navigation := S.G.h(8)
	surface.add_child(navigation)
	var previous := S.button("← PRÉCÉDENTE", func(): _select_question(question_index - 1), question_index > 0)
	previous.name = "PressPrevious"
	navigation.add_child(previous)
	var next := S.button("SUIVANTE →", func(): _select_question(question_index + 1), question_index < questions.size() - 1)
	next.name = "PressNext"
	S.G.fill(next)
	navigation.add_child(next)
	publish_button = S.button("PUBLIER MES RÉPONSES", _publish, false, true)
	publish_button.name = "PressPublish"
	surface.add_child(publish_button)
	_refresh_selection()

func _render_outcome(column: VBoxContainer, outcome: Dictionary) -> void:
	var content := S.G.h(20)
	S.G.fill(content, true)
	column.add_child(content)
	var air := Control.new()
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(air, true)
	content.add_child(air)
	var surface := S.panel(content, 18)
	surface.get_parent().custom_minimum_size.x = 610
	surface.get_parent().size_flags_horizontal = Control.SIZE_FILL
	var list := S.G.scroll(surface)
	list.add_child(S.label("Conférence publiée", 25, S.GOLD))
	list.add_child(S.wrap("Vos réponses sont enregistrées. Le bilan reprend les effets conservés par la carrière.", 15, S.TEXT))
	var metrics := {"morale":"Moral du groupe", "trust":"Confiance", "mediaTrust":"Opinion des médias", "fanTrust":"Opinion des supporters", "boardPressure":"Pression du conseil"}
	for metric: String in metrics:
		var before: Dictionary = outcome.get("before", {})
		var after: Dictionary = outcome.get("after", {})
		var delta: Dictionary = outcome.get("delta", {})
		if before.has(metric) and after.has(metric) and delta.has(metric):
			list.add_child(S.label("%s : %s → %s (%+.0f)" % [metrics[metric], S.G.n(before[metric]), S.G.n(after[metric]), float(delta[metric])], 15, S.GOLD))
	for record: Dictionary in data.get("history", []):
		if _context_key(record) != _context: continue
		var reporter: Dictionary = record.get("journalist", {})
		list.add_child(S.label(str(reporter.get("name", "Identité indisponible")) + " · " + str(reporter.get("outlet", "")), 14, S.GOLD))
		var question: Variant = record.get("question", record.get("questionText"))
		var answer: Variant = record.get("answer", record.get("answerText"))
		if question is String: list.add_child(S.wrap(question, 14))
		if answer is String: list.add_child(S.wrap(answer, 15, S.TEXT))
	for exchange: Dictionary in outcome.get("exchanges", []):
		var name_label := "Identité indisponible"
		for person: Dictionary in data.get("people", []):
			if person.get("id") == exchange.get("journalistId"): name_label = str(person.get("name", "")); break
		list.add_child(S.wrap("%s · relation %+.0f → %+.0f (%+.0f)" % [name_label, float(exchange.get("before", 0)), float(exchange.get("after", 0)), float(exchange.get("delta", 0))], 13))

func _choose_answer(question_id: String, answer_id: String) -> void:
	if app.waiting or _request_in_flight or not _available(): return
	for question: Dictionary in _questions():
		if str(question.get("id", "")) != question_id: continue
		for answer: Dictionary in question.get("answers", []):
			if str(answer.get("id", "")) == answer_id:
				choices[question_id] = answer_id
				_refresh_selection()
				_refresh_buttons()
				return

func _select_question(index: int) -> void:
	if app.waiting or _request_in_flight or not _available(): return
	if index < 0 or index >= _questions().size(): return
	question_index = index
	_render_ui()

func _refresh_selection() -> void:
	for button: Button in _answers:
		var selected: bool = choices.get(button.get_meta("question_id"), "") == button.get_meta("answer_id")
		button.set_pressed_no_signal(selected)
		if selected: S.selected(button, S.GOLD)
		else:
			for state in ["normal", "hover", "pressed"]: button.add_theme_stylebox_override(state, button.get_meta("base_styles")[state])
			button.add_theme_color_override("font_color", S.TEXT)
	if is_instance_valid(_draft_status): _draft_status.text = "%d / %d réponses en brouillon · rien n’est publié" % [choices.size(), _questions().size()]

func _complete() -> bool:
	if not _available(): return false
	for question: Dictionary in _questions():
		var selected: Variant = choices.get(str(question.get("id", "")))
		if not question.get("answers", []).any(func(answer: Dictionary): return answer.get("id") == selected): return false
	return true

func _publish() -> void:
	if app.waiting or _request_in_flight or not _complete(): return
	var answers: Array = []
	for question: Dictionary in _questions():
		answers.append({"questionId":question.id, "answerId":choices[str(question.id)]})
	_request_in_flight = true
	var payload := {"context":data.get("context", {}).duplicate(true), "answers":answers}
	var invitation: Variant = data.get("conference", {}).get("invitationId")
	if invitation is String and not invitation.is_empty(): payload.invitationId = invitation
	director.command("press_conference", payload)
	_refresh_buttons()

func _refresh_buttons() -> void:
	if not is_instance_valid(ui): return
	if is_instance_valid(publish_button): publish_button.set_meta("contextual_enabled", _complete())
	for button in ui.find_children("*", "BaseButton", true, false):
		if button.has_meta("contextual_enabled"):
			button.disabled = bool(app.waiting) or _request_in_flight or not bool(button.get_meta("contextual_enabled"))
	_was_waiting = bool(app.waiting)

func _process(_delta: float) -> void:
	if app != null and _was_waiting != bool(app.waiting): _refresh_buttons()
