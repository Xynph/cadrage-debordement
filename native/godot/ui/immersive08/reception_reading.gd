extends RefCounted
## Session-only reading model. An informative message is never promoted to a
## decision solely because its wording sounds urgent.
const LABELS := {"all":"Tous les états", "todo":"À faire", "waiting":"En attente", "info":"Informations"}

static func status(message: Dictionary, model: Dictionary) -> Dictionary:
	var invitation: Dictionary = message.get("press_invitation", {})
	if invitation.get("status") == "pending":
		var conference: Dictionary = model.get("clubLife", {}).get("press", {}).get("conference", {})
		if conference.get("invitationId") == invitation.get("id"):
			if conference.get("available", false):
				return {"key":"todo", "label":"À faire", "urgent":bool(conference.get("required", false)), "reason":"Vos réponses sont attendues."}
			if conference.has("available") and conference.available == false and not str(conference.get("reason", "")).is_empty():
				return {"key":"waiting", "label":"En attente", "urgent":false, "reason":str(conference.reason)}
	var notice: Dictionary = message.get("calendar_notice", {})
	if notice.get("status") == "pending":
		return {"key":"todo", "label":"À décider", "urgent":false, "reason":"Choisir de recaler ou de conserver votre préparation."}
	var event: Dictionary = message.get("international_event", {})
	var fixture: Variant = model.get("international", {}).get("currentManagedFixture")
	if fixture is Dictionary and event.get("id", "") == "match-day/" + str(fixture.get("id", "")):
		return {"key":"todo", "label":"Jour de match", "urgent":true, "reason":"La rencontre de votre sélection attend votre décision."}
	return {"key":"info", "label":"Information", "urgent":false, "reason":"À consulter ; aucune décision en attente n'est indiquée par ce courrier."}

static func thread_key(message: Dictionary) -> String:
	var notice: Dictionary = message.get("calendar_notice", {})
	if not str(notice.get("fixtureId", "")).is_empty(): return "fixture/" + str(notice.fixtureId)
	var event: Dictionary = message.get("international_event", {})
	var id := str(event.get("id", ""))
	if event.get("kind") == "international_host":
		for prefix in ["host/", "host-guide/"]:
			if id.begins_with(prefix): return "host/" + id.trim_prefix(prefix)
	var invitation: Dictionary = message.get("press_invitation", {})
	var context: Dictionary = invitation.get("context", {})
	if context.has_all(["club", "season", "week"]):
		return "press/%s/%s/%s" % [context.club, context.season, context.week]
	return "message/" + str(message.get("id", ""))

static func groups(messages: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var positions := {}
	for message: Dictionary in messages:
		var key := thread_key(message)
		if not positions.has(key):
			positions[key] = result.size()
			result.append({"key":key, "messages":[]})
		result[int(positions[key])].messages.append(message)
	return result

static func counts(messages: Array, model: Dictionary) -> Dictionary:
	var result := {"all":messages.size(), "todo":0, "waiting":0, "info":0, "urgent":0}
	for message: Dictionary in messages:
		var reading := status(message, model)
		result[reading.key] += 1
		if reading.urgent: result.urgent += 1
	return result
