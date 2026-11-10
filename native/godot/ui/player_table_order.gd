extends RefCounted
const Words = preload("res://ui/management_state.gd")
## Pure reading order. Missing values stay last in either direction.
static func missing(value: Variant) -> bool:
	return value == null or (value is String and value.strip_edges() in ["", "—"]) or (value is float and not is_finite(value))

static func ordered(source: Array, key: String, descending: bool, value: Callable = Callable()) -> Array:
	var result := source.duplicate()
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		var left: Variant = value.call(a,key) if value.is_valid() else a.get(key)
		var right: Variant = value.call(b,key) if value.is_valid() else b.get(key)
		if missing(left) != missing(right): return not missing(left)
		var comparison := 0
		if not missing(left):
			if (left is int or left is float) and (right is int or right is float): comparison = -1 if left < right else 1 if left > right else 0
			else: comparison = Words.fold(str(left)).naturalnocasecmp_to(Words.fold(str(right)))
		if comparison == 0: return str(a.get("id","")) < str(b.get("id",""))
		return comparison > 0 if descending else comparison < 0)
	return result
