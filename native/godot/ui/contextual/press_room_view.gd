extends Control
## Salle de presse. Conférence à répondre : écran « Conférence de presse » (immersive08/conference_presse.gd, idée FM27
## n° 27, choix A de Léo du 23/11/2026) : une question à la fois sur un vrai joueur de l'effectif, cinq tons rangés en
## familles, aucun effet montré avant de répondre ; un clic dit la réponse (la suivante s'affiche), la réaction se
## découvre ensuite en flèches, et la dernière réponse publie. « Laisser Gabi répondre » confie une conférence ordinaire
## à l'adjoint ; les grands moments restent au manager. Promesses publiques (15/11/2026) : en début de saison, la presse
## demande un objectif, annoncé avec la dernière réponse. Après publication : bilan en flèches (jamais de chiffres).
const S = preload("res://ui/contextual/skin.gd")
const Charte = preload("res://ui/charte.gd")
const SeasonLabel = preload("res://ui/season_label.gd")
const Press = preload("res://ui/press_view.gd")
const Fm = preload("res://ui/immersive08/conference_presse.gd")
var director: Node
var app: Control
var model: Dictionary = {}
var data: Dictionary = {}
var meeting: Dictionary = {}
var choices: Dictionary = {}
var question_index := 0
var room: Node3D
var ui: Control
var _context := ""
var _fingerprint := ""
var _request_in_flight := false
var _was_waiting := false
var promise_choice := ""

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
	meeting = projection if projection.has("meetingId") or projection.has("postmatch") else {}
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
		promise_choice = ""
	if _available(): choices = Press._conference_draft(app, data)
	if not app.waiting: _request_in_flight = false
	question_index = clampi(question_index, 0, maxi(0, _questions().size() - 1))
	var fingerprint := JSON.stringify([meeting, data.get("context"), data.get("conference"), data.get("lastOutcome"), data.get("history"), data.get("people"), data.get("policy"), _promises()])
	if fingerprint != _fingerprint:
		_fingerprint = fingerprint
		_render_ui()
	else: _refresh_buttons()

func _questions() -> Array:
	return data.get("conference", {}).get("questions", [])

func _available() -> bool:
	return not meeting.get("completed", false) and data.get("conference", {}).get("available", false) and _questions().size() >= 2 and _questions().size() <= 4

func _context_key(value: Dictionary) -> String:
	return "%d:%d:%d:%s" % [int(value.get("season", -1)), int(value.get("week", -1)), int(value.get("club", -1)), str(value.get("slot", ""))]

func _current_outcome() -> Dictionary:
	var outcome: Variant = data.get("lastOutcome")
	if outcome is Dictionary and _context_key(outcome.get("context", {})) == _context: return outcome
	return {}

func _render_ui() -> void:
	if not is_instance_valid(ui): return
	S.clear(ui)
	if _available():
		Fm.construire(self)
		return
	var column := S.frame(ui, 20)
	var context: Dictionary = data.get("context", {})
	var top := S.G.h(16)
	column.add_child(top)
	var heading := S.G.v(0)
	S.G.fill(heading)
	top.add_child(heading)
	var title := "Conférence d’après-match" if meeting.get("postmatch", false) else "La conférence de presse"
	S.heading(heading, model.get("club", {}), title, "Saison %s · semaine %d" % [SeasonLabel.label(context.get("season", 0)), int(context.get("week", 0)) + 1])
	_render_promise_banner(column)
	if not _current_outcome().is_empty(): _render_outcome(column, _current_outcome())
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
	var notice_text := "Tes réponses ont été communiquées à la presse." if meeting.get("completed", false) else ""
	if meeting.get("completed", false) and _current_outcome().get("delegated", false): notice_text = "Gabi a répondu à ta place. La presse en a pris note."
	var notice := S.wrap(notice_text, 12, S.TEXT)
	notice_surface.add_child(notice)
	# The persisted meeting domain alone unlocks the exit. A local draft or
	# even an old conference receipt never completes a different meeting.
	if meeting.get("completed", false):
		var close := S.button("CONTINUER  →", director.close_room, true, true)
		close.name = "PressReturn"
		footer.add_child(close)
	_refresh_buttons()

## Bilan après publication : une flèche par domaine (vert favorable, rouge défavorable, = sans effet), jamais de
## chiffres ; moral de chaque joueur visé, relation avec chaque journaliste, puis les déclarations.
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
	var delta: Dictionary = outcome.get("delta", {})
	var headline := S.G.h(10)
	headline.name = "PressOutcomeHeadline"
	list.add_child(headline)
	for entry: Array in [["morale", "Groupe", true], ["mediaTrust", "Médias", true], ["fanTrust", "Supporters", true], ["boardPressure", "Pression", false], ["trust", "Direction", true]]:
		if not delta.has(entry[0]): continue
		var card := PanelContainer.new()
		card.name = "PressOutcome_" + str(entry[0])
		card.add_theme_stylebox_override("panel", Charte.ombrer(Charte.style_panneau(Charte.PANNEAU_2, Charte.RAYON_CARTE, 0), Charte.RAYON_CARTE))
		S.G.fill(card)
		headline.add_child(card)
		var margin := S.G.margin(10)
		card.add_child(margin)
		var words := S.G.v(6)
		margin.add_child(words)
		words.add_child(S.label(str(entry[1]).to_upper(), 13, S.MUTED))
		words.add_child(Fm.fleche(float(delta[entry[0]]), entry[2], 26))
	for player: Dictionary in outcome.get("players", []):
		_outcome_line(list, "PressOutcomePlayer_" + str(player.get("id", "")).validate_node_name(), str(player.get("name", "")), "Moral", float(player.get("delta", 0)))
	for promise: Dictionary in _promises().get("active", []):
		if _context_key(promise) != _context: continue
		var announce: Dictionary = promise.get("announce", {})
		var row := S.G.h(10)
		row.name = "PressPromiseAnnounced"
		list.add_child(row)
		row.add_child(S.label("« %s »" % str(promise.get("label", "")), 15, S.GOLD))
		for key: Array in [["fanTrust", "Supporters", true], ["mediaTrust", "Médias", true], ["trust", "Direction", true], ["boardPressure", "Pression", false]]:
			row.add_child(S.label(str(key[1]), 13, S.MUTED))
			row.add_child(Fm.fleche(float(announce.get(key[0], 0)), key[2], 16))
	for exchange: Dictionary in outcome.get("exchanges", []):
		var name_label := "Identité indisponible"
		for person: Dictionary in data.get("people", []):
			if person.get("id") == exchange.get("journalistId"): name_label = str(person.get("name", "")); break
		_outcome_line(list, "PressOutcomeRelation_" + str(exchange.get("journalistId", "")).validate_node_name(), name_label, "Relation", float(exchange.get("delta", 0)))
	for record: Dictionary in data.get("history", []):
		if _context_key(record) != _context: continue
		var reporter: Dictionary = record.get("journalist", {})
		list.add_child(S.label(str(reporter.get("name", "Identité indisponible")) + " · " + str(reporter.get("outlet", "")), 14, S.GOLD))
		var question: Variant = record.get("question", record.get("questionText"))
		var answer: Variant = record.get("answer", record.get("answerText"))
		if question is String: list.add_child(S.wrap(question, 14))
		if answer is String: list.add_child(S.wrap(("Gabi : " if record.get("delegated", false) else "") + answer, 15, S.TEXT))

func _outcome_line(list: Control, id: String, who: String, what: String, value: float) -> void:
	var row := S.G.h(10)
	row.name = id
	list.add_child(row)
	row.add_child(S.label(who, 15, S.TEXT))
	row.add_child(S.label(what, 13, S.MUTED))
	row.add_child(Fm.fleche(value, true, 16))

func _promises() -> Dictionary:
	var value: Variant = model.get("clubLife", {}).get("pressPromises")
	return value if value is Dictionary else {}

func _promise_offer() -> Dictionary:
	var offer: Variant = data.get("conference", {}).get("promise")
	return offer if offer is Dictionary else {}

func _promise_option(id: String) -> Variant:
	var offer := _promise_offer()
	if offer.is_empty(): return null
	if id == "refuse": return offer.get("refuse")
	for option: Dictionary in offer.get("options", []):
		if str(option.get("id", "")) == id: return option
	return null

## Rappel permanent des promesses en cours : ce que la presse vous ressortira.
func _render_promise_banner(column: VBoxContainer) -> void:
	var active: Array = _promises().get("active", [])
	if active.is_empty(): return
	var row := HFlowContainer.new()
	row.name = "PressPromiseBanner"
	row.add_theme_constant_override("h_separation", 10)
	column.add_child(row)
	row.add_child(S.label("TES PROMESSES PUBLIQUES", 12, S.GOLD))
	for promise: Dictionary in active:
		var progress: Dictionary = promise.get("progress", {})
		var track: Variant = progress.get("onTrack")
		var tint: Color = S.MUTED if track == null else (Charte.VERT_CLAIR if track else Charte.DORE)
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", Charte.style_pilule(Charte.VOILE_VERT if tint == Charte.VERT_CLAIR else Charte.VOILE_DORE if tint == Charte.DORE else Charte.PANNEAU_3, tint, 12, 4))
		chip.add_child(S.label("%s · %s" % [str(promise.get("label", "")), str(progress.get("label", ""))], 12, S.TEXT))
		chip.tooltip_text = "Annoncée saison %s, semaine %d · %s" % [str(promise.get("seasonLabel", "")), int(promise.get("week", 0)) + 1, str(promise.get("realismLabel", ""))]
		row.add_child(chip)

## Un second clic sur l'objectif retenu l'annule (aucune promesse ni refus publiés).
func _choose_promise(id: String) -> void:
	if app.waiting or _request_in_flight or not _available(): return
	promise_choice = "" if promise_choice == id else id
	_render_ui()

## Un clic dit la réponse tout de suite (aucun bouton Confirmer) : une réponse dite ne se reprend pas. La question
## suivante sans réponse s'affiche ; la dernière réponse publie la conférence.
func _choose_answer(question_id: String, answer_id: String) -> void:
	if app.waiting or _request_in_flight or not _available() or choices.has(question_id): return
	for question: Dictionary in _questions():
		if str(question.get("id", "")) != question_id: continue
		if not question.get("answers", []).any(func(answer: Dictionary): return str(answer.get("id", "")) == answer_id): return
		choices[question_id] = answer_id
		if _complete():
			_publish()
			return
		var next := _next_unanswered(question_index)
		if next >= 0: question_index = next
		_render_ui()
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
	if not promise_choice.is_empty() and _promise_option(promise_choice) != null: payload.promise = promise_choice
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
	for button in ui.find_children("*", "BaseButton", true, false):
		if button.has_meta("contextual_enabled"):
			button.disabled = bool(app.waiting) or _request_in_flight or not bool(button.get_meta("contextual_enabled"))
	_was_waiting = bool(app.waiting)

func _process(_delta: float) -> void:
	if app != null and _was_waiting != bool(app.waiting): _refresh_buttons()
