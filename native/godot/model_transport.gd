extends RefCounted
## Used only by the pipe reader. UI receives a detached, complete dictionary.
var revision := 0
var current: Dictionary = {}

func accept(response: Dictionary) -> Dictionary:
	var envelope: Dictionary = response.get("transport", {})
	if envelope.is_empty():
		revision = 0
		current = {}
		return response
	if envelope.get("version") != 1 or not response.get("ok") is bool:
		return {}
	if envelope.get("full", false):
		if not response.get("model") is Dictionary: return {}
		current = response.model
	else:
		if envelope.get("base") != revision or not response.get("modelPatch") is Dictionary: return {}
		# Paths have at most two segments; changing a branch never edits an array.
		for path: Array in response.modelPatch.get("remove", []):
			if path.size() == 1: current.erase(str(path[0]))
			elif path.size() == 2 and current.get(str(path[0])) is Dictionary: current[str(path[0])].erase(str(path[1]))
			else: return {}
		for change: Dictionary in response.modelPatch.get("set", []):
			var path: Array = change.get("path", [])
			if path.size() == 1: current[str(path[0])] = change.value
			elif path.size() == 2:
				if not current.get(str(path[0])) is Dictionary: current[str(path[0])] = {}
				current[str(path[0])][str(path[1])] = change.value
			else: return {}
	revision = int(envelope.get("revision", 0))
	var result := response.duplicate(false)
	result.erase("modelPatch")
	result["model"] = current.duplicate(true)
	return result
