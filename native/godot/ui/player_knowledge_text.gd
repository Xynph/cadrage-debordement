extends RefCounted
## Lecture des seules informations publiées. Aucune fourchette n'est construite ici.
const POTENTIAL_COLOR := Color("ffb454")

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _metadata(person: Dictionary) -> Dictionary:
	return person.knowledge if person.get("knowledge") is Dictionary else {}

static func owned(person: Dictionary, own_context: bool = false) -> bool:
	var knowledge: Variant = person.get("knowledge")
	if knowledge is Dictionary and knowledge.get("owned") is bool: return knowledge.owned
	return own_context

static func _unobserved(person: Dictionary, own_context: bool) -> bool:
	return not owned(person,own_context) and _metadata(person).get("stage","") == "unobserved"

static func bounds(person: Dictionary, field: String, own_context: bool = false) -> Dictionary:
	if field in ["rating","note","roleNote"] and owned(person,own_context):
		var exact: Variant = person.get(field)
		if number(exact): return {"min":exact,"max":exact}
	if _unobserved(person,own_context): return {}
	var value: Variant = person.get("potentialRange" if field == "potential" else "ratingRange")
	if not value is Dictionary: return {}
	var minimum: Variant = value.get("min")
	var maximum: Variant = value.get("max")
	if not number(minimum) or not number(maximum) or float(minimum) < 0 or float(maximum) > 100 or float(minimum) >= float(maximum): return {}
	return {"min":minimum,"max":maximum}

static func _n(value: Variant) -> String:
	return str(value).trim_suffix(".0").replace(".",",")

static func text(person: Dictionary, field: String, own_context: bool = false) -> String:
	var value := bounds(person,field,own_context)
	if value.is_empty(): return "—"
	if value.min == value.max: return _n(value.min)
	return _n(value.min)+"–"+_n(value.max)

static func rating_text(person: Dictionary, own_context: bool = false) -> String:
	return text(person,"rating",own_context)

static func potential_text(person: Dictionary) -> String:
	return text(person,"potential")

static func sort_value(person: Dictionary, field: String, own_context: bool = false) -> Variant:
	var value := bounds(person,field,own_context)
	return value.min if not value.is_empty() else null

static func attributes_known(person: Dictionary, own_context: bool = false) -> bool:
	return owned(person,own_context) or _metadata(person).get("stage","") == "deep"

static func range_delta(left: Dictionary, right: Dictionary, field: String, own_context: bool = false) -> String:
	var first := bounds(left,field,own_context)
	var second := bounds(right,field,own_context)
	if first.is_empty() or second.is_empty(): return "Non comparable"
	var minimum: float = float(second.min)-float(first.max)
	var maximum: float = float(second.max)-float(first.min)
	var low := ("+" if minimum > 0 else "")+_n(minimum)
	var high := ("+" if maximum > 0 else "")+_n(maximum)
	return low if minimum == maximum else low+" à "+high
