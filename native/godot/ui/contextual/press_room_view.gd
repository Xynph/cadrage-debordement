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
const C = preload("res://ui/immersive08/components.gd")
const CompteRendu = preload("res://ui/immersive08/compte_rendu_presse.gd")
var director: Node
var app: Control
var model: Dictionary = {}
var data: Dictionary = {}
var meeting: Dictionary = {}
var choices: Dictionary = {}
var question_index := 0
var photo: TextureRect
var ui: Control
var _context := ""
var _fingerprint := ""
var _request_in_flight := false
var _was_waiting := false
## Envoi fiable (Léo, 24/11/2026) : une conférence entièrement répondue part toujours. Un envoi refusé ou perdu
## (disque, moteur occupé, projection périmée) est relancé seul, avec les mêmes réponses relues sur le modèle confirmé,
## sans bouton ni phrase ; il n'est relancé que si le modèle confirmé montre la conférence encore à publier.
const RELANCE_MIN := 0.5
const RELANCE_MAX := 5.0
var _relance_dans := -1.0
var _relance_pas := RELANCE_MIN
var promise_choice := ""

func _ready() -> void:
	name = "ContextualPress"
	app = director.app
	# Décor : la photo de la salle de presse (art/immersive08/press-room, celle de la page Presse), questions comme
	# compte-rendu (Léo, 25/11/2026 : plus de salle 3D).
	photo = C.photo("press-room")
	photo.name = "PressRoomPhoto"
	S.full(photo)
	add_child(photo)
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
	if not _available():
		_relance_dans = -1.0
		_relance_pas = RELANCE_MIN
	if not app.waiting and not (_available() and _complete()): _request_in_flight = false
	question_index = clampi(question_index, 0, maxi(0, _questions().size() - 1))
	var fingerprint := JSON.stringify([meeting, data.get("context"), data.get("conference"), data.get("lastOutcome"), data.get("history"), data.get("people"), data.get("policy"), _promises()])
	if fingerprint != _fingerprint:
		_fingerprint = fingerprint
		_render_ui()
	else: _refresh_buttons()
	# Réponses toutes dites mais pas encore parties (salle rouverte, envoi perdu) : on les envoie.
	if _available() and _complete() and not _request_in_flight and not app.waiting: _publish()

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
		_refresh_buttons()
		return
	# Compte-rendu sur la même photo, sous le même voile que les questions.
	Fm.voile(self)
	if not _current_outcome().is_empty():
		CompteRendu.construire(self, _current_outcome())
		_refresh_buttons()
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

func _promises() -> Dictionary:
	var value: Variant = model.get("clubLife", {}).get("pressPromises")
	return value if value is Dictionary else {}

func _promise_offer(source: Dictionary = {}) -> Dictionary:
	var offer: Variant = (data if source.is_empty() else source).get("conference", {}).get("promise")
	return offer if offer is Dictionary else {}

func _promise_option(id: String, source: Dictionary = {}) -> Variant:
	var offer := _promise_offer(source)
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
	_relance_dans = -1.0
	# Contexte, invitation et objectif relus sur la projection confirmée la plus récente : une vue restée sur une
	# ancienne projection n'envoie jamais un contexte périmé.
	var source := _projection_confirmee()
	var payload := {"context":source.get("context", {}).duplicate(true), "answers":answers}
	var invitation: Variant = source.get("conference", {}).get("invitationId")
	if invitation is String and not invitation.is_empty(): payload.invitationId = invitation
	if not promise_choice.is_empty() and _promise_option(promise_choice, source) != null: payload.promise = promise_choice
	director.command("press_conference", payload)
	_refresh_buttons()

## Presse du modèle confirmé si elle porte la même conférence (mêmes questions), sinon la projection affichée.
func _projection_confirmee() -> Dictionary:
	var fresh: Variant = app.model.get("clubLife", {}).get("press") if app.model.get("clubLife") is Dictionary else null
	if fresh is Dictionary and fresh.get("conference") is Dictionary and _context_key(fresh.get("context", {})) == _context:
		var ids := func(q: Dictionary): return str(q.get("id", ""))
		if fresh.conference.get("questions", []).map(ids) == _questions().map(ids): return fresh
	return data

## La conférence affichée est-elle encore à publier selon le modèle confirmé ?
func _encore_a_publier() -> bool:
	var fresh := _projection_confirmee()
	if not fresh.get("conference", {}).get("available", false): return false
	var outcome: Variant = fresh.get("lastOutcome")
	return not (outcome is Dictionary and _context_key(outcome.get("context", {})) == _context)

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

func envoi_en_cours() -> bool:
	return _request_in_flight

func _refresh_buttons() -> void:
	if not is_instance_valid(ui): return
	for button in ui.find_children("*", "BaseButton", true, false):
		if button.has_meta("contextual_enabled"):
			button.disabled = bool(app.waiting) or _request_in_flight or not bool(button.get_meta("contextual_enabled"))
	_was_waiting = bool(app.waiting)

func _process(delta: float) -> void:
	if app == null: return
	if _was_waiting != bool(app.waiting): _refresh_buttons()
	if app.waiting or not _request_in_flight: return
	# Envoi sans réponse en attente (refusé, perdu) : relance après un court délai croissant, si rien n'est publié.
	if _relance_dans < 0.0: _relance_dans = _relance_pas
	_relance_dans -= delta
	if _relance_dans > 0.0: return
	_relance_dans = -1.0
	if not _complete() or not _encore_a_publier():
		# Rien à relancer (publiée, ou délégation refusée) : la salle redevient utilisable.
		_request_in_flight = false
		_relance_pas = RELANCE_MIN
		_refresh_buttons()
		if director.has_method("_refresh_controls"): director._refresh_controls()
		return
	_relance_pas = minf(_relance_pas * 2.0, RELANCE_MAX)
	_request_in_flight = false
	# L'envoi précédent n'a rien publié : son refus ne reste pas affiché pendant la relance.
	if "last_error" in app: app.last_error = ""
	_publish()
