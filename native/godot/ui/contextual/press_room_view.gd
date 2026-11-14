extends Control
## Conférence de presse rapide (consolidation du 14/11/2026, façon FM) : un journaliste au micro de son média, une
## question à la fois, cinq tons lisibles d'un coup d'œil avec leurs effets (moral, presse, confiance, relation),
## réponse en un clic (la question suivante s'affiche d'elle-même), publication quand tout est répondu. « Envoyer mon
## adjoint » confie une conférence ordinaire à Gabi (ton prudent, léger coût annoncé) ; les grands moments restent
## au manager. Le réglage « Conférences ordinaires : y aller / envoyer l'adjoint » est une préférence de carrière.
const S = preload("res://ui/contextual/skin.gd")
const SeasonLabel = preload("res://ui/season_label.gd")
const Press = preload("res://ui/press_view.gd")
const People = preload("res://ui/press_people_view.gd")
const Microphone = preload("res://ui/contextual/press_microphone.gd")
const CoachPortrait = preload("res://guide/coach_portrait.gd")
## Couleur de chaque ton (même ordre que la banque : affirmé, honnête, agressif, prudent, humour).
const TONE_COLORS := {"confident":Color("d39b3f"), "honest":Color("5fae7c"), "aggressive":Color("c9584b"), "cautious":Color("7f9bb3"), "humour":Color("a982c6")}
const POSITIVE := Color("86c98f")
const NEGATIVE := Color("e08a7c")
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
	var fingerprint := JSON.stringify([meeting, data.get("context"), data.get("conference"), data.get("lastOutcome"), data.get("history"), data.get("people"), data.get("policy")])
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
	var top := S.G.h(16)
	column.add_child(top)
	var heading := S.G.v(0)
	S.G.fill(heading)
	top.add_child(heading)
	S.heading(heading, model.get("club", {}), "La conférence de presse", "Saison %s · semaine %d" % [SeasonLabel.label(context.get("season", 0)), int(context.get("week", 0)) + 1])
	if _available(): _render_moment(top)
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
	var notice_text := "Vos réponses ont été communiquées à la presse." if meeting.get("completed", false) else "Un clic par question : la suivante s’affiche d’elle-même. Publiez quand tout est répondu."
	if meeting.get("completed", false) and _current_outcome().get("delegated", false): notice_text = "Gabi a répondu à votre place. La presse en a pris note."
	var notice := S.wrap(notice_text, 12, S.TEXT)
	notice_surface.add_child(notice)
	# The persisted meeting domain alone unlocks the exit. A local draft or
	# even an old conference receipt never completes a different meeting.
	if meeting.get("completed", false):
		var close := S.button("CONTINUER  →", director.close_room, true, true)
		close.name = "PressReturn"
		footer.add_child(close)
	_refresh_buttons()

## Bandeau d'enjeu : conférence ordinaire (courte) ou grand moment (plus de questions, en personne).
func _render_moment(parent: Control) -> void:
	var conference: Dictionary = data.get("conference", {})
	var moment: Variant = conference.get("moment")
	var major := moment is Dictionary
	var chip := PanelContainer.new()
	chip.name = "PressMoment"
	var accent := Color("c9584b") if major else Color("5fae7c")
	chip.add_theme_stylebox_override("panel", S.G.T.box(Color(accent, 0.22), 4, accent))
	var margin := S.G.margin(8)
	chip.add_child(margin)
	var words := S.G.v(0)
	margin.add_child(words)
	words.add_child(S.label(("GRAND MOMENT" if major else "CONFÉRENCE ORDINAIRE") + " · %d QUESTIONS" % _questions().size(), 13, S.TEXT))
	var situation: Variant = conference.get("situation")
	var tag := str(situation.get("label", "")) if situation is Dictionary else ""
	words.add_child(S.label((str(moment.get("label", "")) if major else "Courte : environ une minute") + ((" · " + tag + " : les tons pèsent autrement") if tag != "" and not (major and tag == "Derby") else ""), 12, S.GOLD if major else S.MUTED))
	parent.add_child(chip)

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
	# Le journaliste au micro : cube aux couleurs de son média, identité, relation, question en grand.
	var interview := S.panel(left, 16)
	interview.get_parent().custom_minimum_size.y = 220
	var speaker := S.G.h(18)
	S.G.fill(speaker, true)
	interview.add_child(speaker)
	var journalist: Dictionary = question.get("journalist", {})
	var mic: Control = Microphone.new()
	mic.name = "PressMicrophone"
	mic.custom_minimum_size = Vector2(92, 170)
	mic.setup(str(journalist.get("outlet", "")), str(journalist.get("outletId", "")))
	speaker.add_child(mic)
	var transcript := S.G.v(6)
	S.G.fill(transcript, true)
	speaker.add_child(transcript)
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
	var outlet := S.wrap(str(journalist.get("outlet", "")) + ("  ·  " + str(journalist.get("styleLabel")) if journalist.has("styleLabel") else ""), 13, S.TEXT)
	outlet.name = "PressJournalistSource"
	words.add_child(outlet)
	var relation: Dictionary = question.get("relation", {})
	if relation.has("label"):
		var encounters := int(relation.get("encounters", 0))
		var met := "première rencontre" if encounters == 0 else "%d échange%s avec vous" % [encounters, "s" if encounters > 1 else ""]
		var relation_label := S.wrap("Relation : " + str(relation.label) + " · " + met, 13, S.GOLD)
		relation_label.name = "PressJournalistRelation"
		words.add_child(relation_label)
	question_label = S.wrap(str(question.get("question", "")), 22, S.TEXT)
	question_label.name = "PressQuestion"
	transcript.add_child(question_label)
	if question.get("followUp") is Dictionary:
		var source := S.wrap(str(question.followUp.get("label", "")), 12, S.GOLD)
		source.name = "PressArchivedSource"
		transcript.add_child(source)
	var surface := S.panel(content, 14)
	surface.get_parent().custom_minimum_size.x = 600
	surface.get_parent().size_flags_horizontal = Control.SIZE_FILL
	var progress := S.G.h(10)
	progress.name = "PressProgress"
	surface.add_child(progress)
	progress.add_child(S.label("QUESTION %d / %d" % [question_index + 1, questions.size()], 14, S.GOLD))
	for index in questions.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(26, 6)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var answered := choices.has(str(questions[index].get("id", "")))
		dot.color = S.GOLD if index == question_index else (Color("5fae7c") if answered else Color("3b4a40"))
		progress.add_child(dot)
	var spacer := Control.new()
	S.G.fill(spacer)
	progress.add_child(spacer)
	progress.add_child(S.label("Votre ton", 14, S.MUTED))
	var list := S.G.scroll(surface)
	list.name = "PressAnswers"
	var group := ButtonGroup.new()
	for answer: Dictionary in question.get("answers", []):
		var button := _answer_button(question, answer, group)
		list.add_child(button)
		_answers.append(button)
	_draft_status = S.label("", 12, S.GOLD)
	surface.add_child(_draft_status)
	var navigation := S.G.h(8)
	surface.add_child(navigation)
	var previous := S.button("←", func(): _select_question(question_index - 1), question_index > 0)
	previous.name = "PressPrevious"
	previous.tooltip_text = "Question précédente"
	previous.custom_minimum_size.x = 48
	navigation.add_child(previous)
	var next := S.button("→", func(): _select_question(question_index + 1), question_index < questions.size() - 1)
	next.name = "PressNext"
	next.tooltip_text = "Question suivante"
	next.custom_minimum_size.x = 48
	navigation.add_child(next)
	publish_button = S.button("PUBLIER MES RÉPONSES", _publish, false, true)
	publish_button.name = "PressPublish"
	S.G.fill(publish_button)
	navigation.add_child(publish_button)
	_render_delegation(surface)
	_refresh_selection()

## Carte de réponse : le texte exact de la réponse (bouton), le ton en pastille de couleur au-dessus et les effets
## annoncés par le moteur en dessous (moral, presse, confiance, relation avec ce journaliste).
func _answer_button(question: Dictionary, answer: Dictionary, group: ButtonGroup) -> Button:
	var button := S.button(str(answer.get("text", "")), func(): _choose_answer(str(question.get("id", "")), str(answer.get("id", ""))))
	button.name = "PressAnswer_" + str(question.get("id", "")) + "_" + str(answer.get("id", ""))
	button.set_meta("answer_id", str(answer.get("id", "")))
	button.set_meta("question_id", str(question.get("id", "")))
	button.tooltip_text = str(answer.get("toneLabel", "")) + " · " + str(answer.get("consequence", ""))
	button.custom_minimum_size.y = 96
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 15)
	button.toggle_mode = true
	button.button_group = group
	var tone := str(answer.get("tone", ""))
	var accent: Color = TONE_COLORS.get(tone, S.GOLD)
	var base_styles := {}
	for state in ["normal", "hover", "pressed"]:
		var style: StyleBoxFlat = (button.get_theme_stylebox(state) as StyleBoxFlat).duplicate()
		style.content_margin_left = 14
		style.content_margin_top = 30
		style.content_margin_bottom = 28
		style.border_width_left = 4
		style.border_color = Color(accent, 0.9 if state != "normal" else 0.55)
		button.add_theme_stylebox_override(state, style)
		base_styles[state] = style
	button.set_meta("base_styles", base_styles)
	var chip := PanelContainer.new()
	chip.name = "PressTone"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", S.G.T.box(Color(accent, 0.30), 3, accent))
	var chip_text := S.label(str(answer.get("toneLabel", "")).to_upper(), 11, S.TEXT)
	chip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(chip_text)
	button.add_child(chip)
	chip.position = Vector2(14, 6)
	var effects := RichTextLabel.new()
	effects.name = "PressEffects"
	effects.bbcode_enabled = true
	effects.fit_content = true
	effects.scroll_active = false
	effects.autowrap_mode = TextServer.AUTOWRAP_OFF
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.add_theme_font_size_override("normal_font_size", 13)
	effects.text = _effects_bbcode(answer.get("effects", {}))
	effects.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	effects.offset_left = 14
	effects.offset_top = -25
	effects.offset_bottom = -5
	button.add_child(effects)
	return button

## Moral, presse (opinion des médias), confiance (de la direction : l'inverse de la pression) et relation.
static func _effects_bbcode(effects: Variant) -> String:
	if not effects is Dictionary: return ""
	var rows := [["Moral", effects.get("morale")], ["Presse", effects.get("media")], ["Confiance", -float(effects.get("pressure")) if effects.get("pressure") != null else null], ["Relation", effects.get("relation")]]
	var parts: Array[String] = []
	for row: Array in rows:
		if row[1] == null: continue
		var value := int(round(float(row[1])))
		var color := POSITIVE if value > 0 else NEGATIVE if value < 0 else S.MUTED
		parts.append("[color=#%s]%s %s[/color]" % [S.MUTED.to_html(false), row[0], "[color=#%s]%s[/color]" % [color.to_html(false), ("+%d" % value) if value > 0 else ("−%d" % absi(value)) if value < 0 else "="]])
	return "   ".join(parts)

## « Envoyer mon adjoint » et le réglage des conférences ordinaires.
func _render_delegation(surface: VBoxContainer) -> void:
	var conference: Dictionary = data.get("conference", {})
	var delegation: Dictionary = conference.get("delegation", {})
	if delegation.is_empty(): return
	var allowed: bool = delegation.get("allowed", false)
	var card := S.G.h(10)
	card.name = "PressDelegateCard"
	surface.add_child(card)
	var portrait: TextureRect = CoachPortrait.new()
	portrait.name = "PressGabiPortrait"
	portrait.custom_minimum_size = Vector2(54, 54)
	card.add_child(portrait)
	var words := S.G.v(2)
	S.G.fill(words)
	card.add_child(words)
	var send := S.button("ENVOYER MON ADJOINT (GABI)", _delegate, allowed)
	send.name = "PressDelegate"
	words.add_child(send)
	var reason := S.wrap(str(delegation.get("reason", "")), 11, S.MUTED if allowed else S.GOLD)
	reason.name = "PressDelegateReason"
	words.add_child(reason)
	var policy: Dictionary = data.get("policy", {})
	if policy.is_empty(): return
	var row := S.G.h(6)
	row.name = "PressPolicy"
	surface.add_child(row)
	var caption := S.label("Conférences ordinaires :", 12, S.MUTED)
	caption.tooltip_text = str(policy.get("notice", ""))
	row.add_child(caption)
	for option: Array in [["moi", "Y aller"], ["adjoint", "Envoyer l’adjoint"]]:
		var key: String = option[0]
		var current: bool = str(policy.get("ordinary", "moi")) == key
		var toggle := S.button(option[1], func(): _set_policy(key), not current)
		toggle.name = "PressPolicy_" + key
		toggle.tooltip_text = str(policy.get("notice", ""))
		toggle.custom_minimum_size.y = 30
		toggle.add_theme_font_size_override("font_size", 12)
		if current: S.selected(toggle, S.GOLD)
		row.add_child(toggle)

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
	var delegated: bool = outcome.get("delegated", false)
	list.add_child(S.label("Gabi a tenu la conférence" if delegated else "Conférence publiée", 25, S.GOLD))
	list.add_child(S.wrap("Ton prudent, la presse attendait le manager : médias −2 et relation −1 avec chaque journaliste." if delegated else "Vos réponses sont enregistrées. Voici ce qu’elles ont changé.", 15, S.TEXT))
	# Les trois conséquences qui comptent, en grand : moral, relation presse, confiance.
	var headline := S.G.h(10)
	headline.name = "PressOutcomeHeadline"
	list.add_child(headline)
	var before: Dictionary = outcome.get("before", {})
	var after: Dictionary = outcome.get("after", {})
	var delta: Dictionary = outcome.get("delta", {})
	for entry: Array in [["morale", "Moral du groupe"], ["mediaTrust", "Relation presse"], ["trust", "Confiance"]]:
		if not delta.has(entry[0]): continue
		var value := int(round(float(delta[entry[0]])))
		var card := PanelContainer.new()
		var tint := POSITIVE if value > 0 else NEGATIVE if value < 0 else S.MUTED
		card.add_theme_stylebox_override("panel", S.G.T.box(Color(tint, 0.14), 5, Color(tint, 0.7)))
		S.G.fill(card)
		headline.add_child(card)
		var margin := S.G.margin(10)
		card.add_child(margin)
		var words := S.G.v(2)
		margin.add_child(words)
		words.add_child(S.label(entry[1], 13, S.MUTED))
		words.add_child(S.label(("+%d" % value) if value > 0 else ("−%d" % absi(value)) if value < 0 else "=", 28, tint))
		words.add_child(S.label("%s → %s" % [S.G.n(before.get(entry[0], 0)), S.G.n(after.get(entry[0], 0))], 12, S.MUTED))
	var metrics := {"fanTrust":"Opinion des supporters", "boardPressure":"Pression du conseil"}
	for metric: String in metrics:
		if before.has(metric) and after.has(metric) and delta.has(metric):
			list.add_child(S.label("%s : %s → %s (%+.0f)" % [metrics[metric], S.G.n(before[metric]), S.G.n(after[metric]), float(delta[metric])], 14, S.GOLD))
	for exchange: Dictionary in outcome.get("exchanges", []):
		var name_label := "Identité indisponible"
		for person: Dictionary in data.get("people", []):
			if person.get("id") == exchange.get("journalistId"): name_label = str(person.get("name", "")); break
		list.add_child(S.wrap("%s · relation %+.0f → %+.0f (%+.0f)" % [name_label, float(exchange.get("before", 0)), float(exchange.get("after", 0)), float(exchange.get("delta", 0))], 13))
	for record: Dictionary in data.get("history", []):
		if _context_key(record) != _context: continue
		var reporter: Dictionary = record.get("journalist", {})
		list.add_child(S.label(str(reporter.get("name", "Identité indisponible")) + " · " + str(reporter.get("outlet", "")), 14, S.GOLD))
		var question: Variant = record.get("question", record.get("questionText"))
		var answer: Variant = record.get("answer", record.get("answerText"))
		if question is String: list.add_child(S.wrap(question, 14))
		if answer is String: list.add_child(S.wrap(("Gabi : " if record.get("delegated", false) else "") + answer, 15, S.TEXT))

## Un clic : la réponse est retenue et la prochaine question sans réponse s'affiche.
func _choose_answer(question_id: String, answer_id: String) -> void:
	if app.waiting or _request_in_flight or not _available(): return
	for question: Dictionary in _questions():
		if str(question.get("id", "")) != question_id: continue
		for answer: Dictionary in question.get("answers", []):
			if str(answer.get("id", "")) == answer_id:
				choices[question_id] = answer_id
				var next := _next_unanswered(question_index)
				if next >= 0 and next != question_index:
					question_index = next
					_render_ui()
				else:
					_refresh_selection()
					_refresh_buttons()
				return

func _next_unanswered(from: int) -> int:
	var questions := _questions()
	for step in range(1, questions.size() + 1):
		var index := (from + step) % questions.size()
		if not choices.has(str(questions[index].get("id", ""))): return index
	return -1

func _select_question(index: int) -> void:
	if app.waiting or _request_in_flight or not _available(): return
	if index < 0 or index >= _questions().size(): return
	question_index = index
	_render_ui()

func _refresh_selection() -> void:
	for button: Button in _answers:
		var selected: bool = choices.get(button.get_meta("question_id"), "") == button.get_meta("answer_id")
		button.set_pressed_no_signal(selected)
		if selected:
			for state in ["normal", "hover", "pressed"]:
				var style: StyleBoxFlat = (button.get_meta("base_styles")[state] as StyleBoxFlat).duplicate()
				style.bg_color = Color("283e2d")
				style.border_color = S.GOLD
				style.border_width_left = 6
				button.add_theme_stylebox_override(state, style)
			button.add_theme_color_override("font_color", S.GOLD)
		else:
			for state in ["normal", "hover", "pressed"]: button.add_theme_stylebox_override(state, button.get_meta("base_styles")[state])
			button.add_theme_color_override("font_color", S.TEXT)
	if is_instance_valid(_draft_status):
		var total := _questions().size()
		_draft_status.text = "Toutes les réponses sont prêtes : publiez." if choices.size() >= total else "%d / %d réponses · rien n’est publié" % [choices.size(), total]

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

## Gabi répond à votre place (conférence ordinaire seulement) : une commande, le moteur choisit le ton prudent.
func _delegate() -> void:
	if app.waiting or _request_in_flight or not _available(): return
	if not data.get("conference", {}).get("delegation", {}).get("allowed", false): return
	_request_in_flight = true
	var payload := {"context":data.get("context", {}).duplicate(true)}
	var invitation: Variant = data.get("conference", {}).get("invitationId")
	if invitation is String and not invitation.is_empty(): payload.invitationId = invitation
	director.command("press_delegate", payload)
	_refresh_buttons()

func _set_policy(key: String) -> void:
	if app.waiting or _request_in_flight: return
	director.command("press_policy", {"ordinary":key})

func _refresh_buttons() -> void:
	if not is_instance_valid(ui): return
	if is_instance_valid(publish_button):
		publish_button.set_meta("contextual_enabled", _complete())
		publish_button.text = "PUBLIER MES RÉPONSES" if _complete() else "PUBLIER (%d / %d)" % [choices.size(), _questions().size()]
	for button in ui.find_children("*", "BaseButton", true, false):
		if button.has_meta("contextual_enabled"):
			button.disabled = bool(app.waiting) or _request_in_flight or not bool(button.get_meta("contextual_enabled"))
	_was_waiting = bool(app.waiting)

func _process(_delta: float) -> void:
	if app != null and _was_waiting != bool(app.waiting): _refresh_buttons()
