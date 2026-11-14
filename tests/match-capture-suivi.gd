extends RefCounted
## Garde les tableaux de suivi eux-mêmes, sans conserver d'instances de scène.
## Le suivi est alimenté par append et survit ainsi à queue_free de la régie.
var traces: Dictionary = {}

func observe(regie: Node) -> void:
	if is_instance_valid(regie):
		traces[regie.get_instance_id()] = regie.suivi

func collect() -> Array:
	var result: Array = []
	for trace: Array in traces.values():
		result.append_array(trace)
	return result.duplicate(true)
