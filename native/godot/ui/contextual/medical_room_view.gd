extends Control

const S = preload("res://ui/contextual/skin.gd")
var director: Node
var app: Control
var model: Dictionary = {}
var selected_id := ""
var selected_protocol := ""
var ui: Control
var _entry_id := ""
var _fingerprint := ""
var meeting_data: Dictionary = {}

func _ready() -> void:
	name = "ContextualMedical"
	app = director.app
	S.room(self, "medical", app.model.get("club", {}))

func update_frame(value: Dictionary, data: Dictionary = {}) -> void:
	model = value
	var previous_meeting := str(meeting_data.get("meetingId", ""))
	meeting_data = data.duplicate(true)
	var entry := str(data.get("playerId", ""))
	if entry != _entry_id or str(data.get("meetingId", "")) != previous_meeting:
		_entry_id = entry
		selected_id = entry
		selected_protocol = ""
	if selected_id.is_empty():
		var followed: Array = _medical().get("players", [])
		if not followed.is_empty(): selected_id = str(followed[0].get("id", ""))
		elif not model.get("squad", []).is_empty(): selected_id = str(model.squad[0].get("id", ""))
	var fingerprint := JSON.stringify([data, selected_id, value.get("squad", []), value.get("staff", {}), value.get("clubLife", {}).get("clubSupport", {}), value.get("meta", {}), value.get("live")])
	if fingerprint == _fingerprint: return
	_fingerprint = fingerprint
	_draw()

func _support() -> Dictionary:
	return model.get("clubLife", {}).get("clubSupport", {})

func _medical() -> Dictionary:
	return _support().get("medical", {})

func _player() -> Dictionary:
	for player: Dictionary in model.get("squad", []):
		if str(player.get("id", "")) == selected_id: return player
	return {}

func _followup() -> Dictionary:
	for row: Dictionary in _medical().get("players", []):
		if str(row.get("id", "")) == selected_id: return row
	return {}

func _editable() -> bool:
	var meta: Dictionary = model.get("meta", {})
	var live: Variant = model.get("live")
	return not bool(meeting_data.get("completed", false)) and not _player().is_empty() and not (live is Dictionary and not live.is_empty()) and not bool(meta.get("trained", true)) and str(meta.get("phase", "ended")) != "ended"

func _protocol_allowed() -> bool:
	return _editable() and bool(_medical().get("available", false)) and int(_player().get("injury", 0)) > 0 and int(_followup().get("injury", 0)) > 0 and not _support().get("context", {}).is_empty()

func _doctor() -> Dictionary:
	for team: Dictionary in model.get("staff", {}).get("teams", []):
		if str(team.get("id", "")) != str(model.get("club", {}).get("id", "")): continue
		for member: Dictionary in team.get("members", []):
			var role := str(member.get("role", "")).to_lower()
			for token in ["medical", "médical", "médec", "medec", "kiné", "kine", "physio", "doctor", "osteop", "infirm"]:
				if token in role: return member
	return {}

func _draw() -> void:
	if not is_node_ready(): return
	if is_instance_valid(ui): remove_child(ui); ui.queue_free()
	ui = Control.new()
	S.full(ui)
	add_child(ui)
	var column := S.frame(ui, 22)
	S.heading(column, model.get("club", {}), "Faire le point à l’infirmerie", "Disponibilité · suivi enregistré et prochaine charge")
	var content := S.G.h(18)
	S.G.fill(content, true)
	column.add_child(content)
	var facts := S.panel(content, 16)
	facts.get_parent().custom_minimum_size.x = 360
	facts.get_parent().size_flags_horizontal = Control.SIZE_FILL
	var facts_scroll := S.G.scroll(facts)
	S.G.fill(facts_scroll.get_parent(), true)
	var picker := OptionButton.new()
	picker.name = "MedicalPlayerPicker"
	picker.custom_minimum_size.y = 38
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.fit_to_longest_item = false
	picker.clip_text = true
	picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for player: Dictionary in model.get("squad", []):
		picker.add_item(str(player.get("name", "")))
		picker.set_item_metadata(picker.item_count - 1, str(player.get("id", "")))
		if str(player.get("id", "")) == selected_id: picker.select(picker.item_count - 1)
	if _player().is_empty():
		picker.select(-1)
		picker.text = "Choisir un joueur"
	picker.disabled = picker.item_count == 0
	picker.set_meta("contextual_enabled", picker.item_count > 0 and not bool(meeting_data.get("completed", false)) and str(meeting_data.get("meetingId", "")).is_empty())
	picker.item_selected.connect(func(index: int):
		selected_id = str(picker.get_item_metadata(index)); selected_protocol = ""; _fingerprint = ""; _draw())
	facts_scroll.add_child(picker)
	var player := _player()
	if player.is_empty():
		facts_scroll.add_child(S.label("Joueur indisponible", 20, S.GOLD))
		facts_scroll.add_child(S.wrap("Ce joueur n’est plus présent dans l’effectif actuel. Choisissez un dossier disponible.", 15))
	else:
		var person := S.G.h(12)
		facts_scroll.add_child(person)
		var portrait := S.G.portrait(int(player.get("portraitIndex", 0)), 68, player)
		portrait.name = "MedicalPlayerPortrait"
		portrait.set_meta("person_id", selected_id)
		person.add_child(portrait)
		var words := S.G.v(4)
		S.G.fill(words)
		person.add_child(words)
		words.add_child(S.wrap(str(player.get("name", "")), 21, S.GOLD))
		words.add_child(S.label(str(player.get("pos", "")), 14))
		facts_scroll.add_child(S.label("Les repères actuels", 18, S.GOLD))
		facts_scroll.add_child(S.label("Condition : %s / 100" % str(player.get("condition", "—")), 16))
		var fatigue: Variant = player.get("physicalLoad", "—")
		if fatigue is Dictionary: fatigue = fatigue.get("fatigue", "—")
		facts_scroll.add_child(S.label("Charge cumulée : %s / 100" % str(fatigue), 16))
		var injury := int(player.get("injury", 0))
		facts_scroll.add_child(S.wrap("Indisponibilité enregistrée : %d semaine(s) de jeu." % injury if injury > 0 else "Aucune indisponibilité enregistrée.", 16, S.TEXT))
		var stage := str(_followup().get("stage", ""))
		if not stage.is_empty():
			facts_scroll.add_child(S.label("Suivi : " + str({"blesse":"indisponibilité", "reprise":"reprise à organiser", "progressif":"reprise progressive", "termine":"suivi terminé"}.get(stage, stage)), 14))
		var mode := str(player.get("loadPlan", "collective"))
		facts_scroll.add_child(S.wrap("Prochaine charge : " + str({"collective":"suivre le collectif", "repos":"récupération", "normal":"normale", "intense":"intensive"}.get(mode, "non renseignée")), 14))
	var doctor := _doctor()
	facts_scroll.add_child(S.G.separator())
	if doctor.is_empty():
		facts_scroll.add_child(S.label("Cellule médicale", 18, S.GOLD))
		facts_scroll.add_child(S.wrap("Aucun membre médical identifié dans le staff projeté.", 13))
	else:
		var staff_row := S.G.h(10)
		facts_scroll.add_child(staff_row)
		var staff_portrait := S.G.portrait(int(doctor.get("portraitIndex", 0)), 48, doctor)
		staff_portrait.name = "MedicalStaffPortrait"
		staff_portrait.set_meta("person_id", str(doctor.get("id", "")))
		staff_row.add_child(staff_portrait)
		var staff_words := S.G.v(3)
		S.G.fill(staff_words)
		staff_row.add_child(staff_words)
		staff_words.add_child(S.wrap(str(doctor.get("name", "")), 17, S.GOLD))
		staff_words.add_child(S.wrap(str(doctor.get("roleLabel", doctor.get("role", ""))), 13))
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(space, true)
	content.add_child(space)
	var actions := S.panel(content, 16)
	actions.get_parent().custom_minimum_size.x = 355
	actions.get_parent().size_flags_horizontal = Control.SIZE_FILL
	var list := S.G.scroll(actions)
	S.G.fill(list.get_parent(), true)
	list.add_child(S.label("Décider du suivi", 21, S.GOLD))
	if player.is_empty():
		list.add_child(S.wrap("Aucune décision disponible pour ce dossier.", 16))
	elif int(player.get("injury", 0)) > 0:
		list.add_child(S.wrap("Le suivi choisi agit lors de la prochaine séance. Ouvrir cette salle ne réduit pas l’indisponibilité.", 15, S.TEXT))
		var protocols: Array = _medical().get("protocols", [])
		for protocol: Dictionary in protocols:
			var key := str(protocol.get("key", ""))
			if selected_protocol.is_empty() and key == str(_followup().get("protocol", "")): selected_protocol = key
		for protocol: Dictionary in protocols:
			var key := str(protocol.get("key", ""))
			var option := S.button(str(protocol.get("label", "")), func(): selected_protocol = key; _draw(), _protocol_allowed())
			option.name = "MedicalProtocol_" + key
			option.set_meta("protocol_key", key)
			if key == selected_protocol: S.selected(option)
			list.add_child(option)
			if key == selected_protocol: list.add_child(S.wrap(str(protocol.get("description", "")), 14, S.TEXT))
		var confirm := S.button("CONFIRMER LE SUIVI", _confirm_protocol, _protocol_allowed() and not selected_protocol.is_empty(), true)
		confirm.name = "MedicalConfirmProtocol"
		list.add_child(confirm)
		list.add_child(S.wrap("Un joueur indisponible reste au repos pendant la séance.", 13))
	else:
		list.add_child(S.wrap("Adapter uniquement la charge prévue pour la prochaine séance. Aucun effet physique immédiat.", 15, S.TEXT))
		for pair in [["repos", "PRÉVOIR UNE RÉCUPÉRATION"], ["collective", "SUIVRE LE COLLECTIF"]]:
			var mode: String = pair[0]
			var button := S.button(pair[1], func(): _set_load(mode), _editable())
			button.name = "MedicalLoad_" + mode
			button.set_meta("load_mode", mode)
			list.add_child(button)
	if bool(meeting_data.get("completed", false)): list.add_child(S.wrap("Échange terminé. Décision enregistrée.", 14, S.GOLD))
	elif not _editable(): list.add_child(S.wrap("Lecture seule : séance effectuée, match en cours ou saison terminée.", 14, S.GOLD))
	elif int(player.get("injury", 0)) > 0 and not _protocol_allowed(): list.add_child(S.wrap("Le suivi médical n’est pas disponible dans le contexte actuel.", 14, S.GOLD))
	if bool(meeting_data.get("ackAllowed", false)) and not bool(meeting_data.get("completed", false)):
		var acknowledge := S.button("MAINTENIR LA REPRISE EN COURS" if str(_followup().get("stage", "")) == "reprise" else "J’AI PRIS CONNAISSANCE", _acknowledge, not str(meeting_data.get("meetingId", "")).is_empty(), true)
		acknowledge.name = "MedicalAcknowledge"
		list.add_child(acknowledge)
	list.add_child(S.G.separator())
	list.add_child(S.wrap("Suivi de la blessure et préparation de la reprise.", 13))
	var close := S.button("CONTINUER", _continue, bool(meeting_data.get("completed", false)), true)
	close.name = "MedicalClose"
	column.add_child(close)
	director._refresh_controls()

func _continue() -> void:
	if app.waiting or not bool(meeting_data.get("completed", false)): return
	director.close_room()

func _acknowledge() -> void:
	if app.waiting or bool(meeting_data.get("completed", false)) or not bool(meeting_data.get("ackAllowed", false)): return
	var meeting_id := str(meeting_data.get("meetingId", ""))
	if meeting_id.is_empty(): return
	director.command("club_meeting_ack", {"meetingId":meeting_id})

func _confirm_protocol() -> void:
	if app.waiting or not _protocol_allowed(): return
	if not str(meeting_data.get("meetingId", "")).is_empty() and selected_id != _entry_id: return
	var offered := false
	for protocol: Dictionary in _medical().get("protocols", []):
		if str(protocol.get("key", "")) == selected_protocol: offered = true
	if not offered: return
	director.command("medical_protocol", {"context":_support().context, "id":selected_id, "protocol":selected_protocol})

func _set_load(mode: String) -> void:
	if app.waiting or not _editable() or int(_player().get("injury", 0)) > 0 or mode not in ["repos", "collective"]: return
	if not str(meeting_data.get("meetingId", "")).is_empty() and selected_id != _entry_id: return
	director.command("set_player_load", {"playerId":selected_id, "mode":mode})
