extends Control
const S = preload("res://ui/contextual/skin.gd")
var director: Node
var app: Control
var model: Dictionary = {}
var invitation: Dictionary = {}
var selected_choice := ""
var ui: Control
var _fingerprint := ""

func _ready() -> void:
	name = "ContextualConversation"
	app = director.app
	var active: Dictionary = app.model.get("clubLife", {}).get("sceneInvitations", {}).get("active", {})
	S.room(self, "locker" if active.get("kind") == "team_meeting" else "office", app.model.get("club", {}))

func update_frame(value: Dictionary, data: Dictionary) -> void:
	model = value
	invitation = data
	var fingerprint := JSON.stringify([data, value.get("squad", []), value.get("staff", {})])
	if fingerprint == _fingerprint: return
	_fingerprint = fingerprint
	_draw()

func _draw() -> void:
	if is_instance_valid(ui): remove_child(ui); ui.queue_free()
	ui = Control.new()
	S.full(ui)
	add_child(ui)
	var column := S.frame(ui, 28)
	S.heading(column, model.get("club", {}), "Un moment au club", str(invitation.get("title", "Entretien")))
	var center := S.G.h(20)
	S.G.fill(center, true)
	column.add_child(center)
	var room_space := Control.new()
	room_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(room_space)
	center.add_child(room_space)
	var surface := S.panel(center, 20)
	surface.get_parent().custom_minimum_size.x = 470
	surface.get_parent().size_flags_horizontal = Control.SIZE_FILL
	var panel := S.G.scroll(surface)
	var person := S.person(model, invitation.get("participantId"))
	if person.is_empty() and invitation.has("participantSourceId"): person = S.person(model, invitation.participantSourceId)
	var row := S.G.h(12)
	panel.add_child(row)
	if not person.is_empty():
		row.add_child(S.G.portrait(int(person.get("portraitIndex", 0)), 56, person))
		var words := S.G.v(4)
		row.add_child(words)
		words.add_child(S.label(str(person.get("name", "")), 21, S.GOLD))
		words.add_child(S.label(str(person.get("roleLabel", person.get("role", person.get("position", "")))), 12))
	elif invitation.get("kind") == "team_meeting": row.add_child(S.label("Le groupe professionnel", 21, S.GOLD))
	else: row.add_child(S.label("Participant indisponible", 19, S.GOLD))
	panel.add_child(S.wrap(str(invitation.get("reason", "")), 17, S.TEXT))
	var decision: Variant = invitation.get("decision")
	if decision is Dictionary:
		panel.add_child(S.label("Compte rendu", 18, S.GOLD))
		panel.add_child(S.wrap(str(decision.get("summary", "Décision enregistrée.")), 17, S.TEXT))
		surface.add_child(S.button("RETOURNER AU COURRIER  →", _close, true, true))
	else:
		panel.add_child(S.label("Votre réponse", 17, S.GOLD))
		for option: Dictionary in invitation.get("options", []):
			var button := S.button(str(option.get("text", "")), func(): selected_choice = str(option.get("id", "")); _draw(), invitation.get("available", true))
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size.y = 60
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_font_size_override("font_size", 15)
			if selected_choice == str(option.get("id", "")): S.selected(button, S.GOLD)
			panel.add_child(button)
		surface.add_child(S.button("CONFIRMER LA RÉPONSE", _reply, not selected_choice.is_empty() and invitation.get("available", true), true))
		surface.add_child(S.button("REVENIR AU COURRIER", _close))
		surface.add_child(S.button("DÉCLINER L’INVITATION", func(): director.command("scene_invitation_close", {"id":invitation.id, "dismiss":true})))
	director._refresh_controls()

func _reply() -> void:
	if selected_choice.is_empty(): return
	director.command("scene_invitation_reply", {"id":invitation.id, "choiceId":selected_choice})

func _close() -> void:
	director.command("scene_invitation_close", {"id":invitation.id})
