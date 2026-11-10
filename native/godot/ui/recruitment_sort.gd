extends RefCounted
## Sort projected values, never formatted money/date strings or career objects.
const U = preload("res://ui/management_state.gd")
const Knowledge = preload("res://ui/player_knowledge_text.gd")
const NUMERIC := {"Âge":"age","Niveau":"rating","Salaire":"salary","Prime":"fee"}

static func report_label(report: Dictionary) -> String:
	return {"observed":"Observé","deep":"Approfondie"}.get(report.get("knowledge",{}).get("stage",""),"À observer")

static func _number(value: Variant) -> Variant:
	return value if (value is int or value is float) and is_finite(float(value)) else null

static func _date_week(report: Dictionary) -> Variant:
	var week: Variant = _number(report.get("week"))
	var season: Variant = _number(report.get("season"))
	return week if week != null and season != null and float(week) == floorf(float(week)) and float(season) == floorf(float(season)) else null

static func report_status(report: Dictionary) -> String:
	if report.get("assessment", {}).get("stale", false): return "Ancien"
	return "—" if report.is_empty() else "Daté" if _date_week(report) != null else "Non daté"

static func value(item: Dictionary, column: String, reports: Dictionary, archive: bool = false) -> Variant:
	var report: Dictionary = item if archive else reports.get(str(item.get("id", "")), {})
	if column == "Nom" or column == "Poste":
		var text: Variant = item.get("name" if column == "Nom" else "pos")
		return U.fold(text).strip_edges() if text is String and not text.strip_edges().is_empty() else null
	if column == "Niveau": return Knowledge.sort_value(item,"rating")
	if NUMERIC.has(column): return _number(item.get(NUMERIC[column]))
	if column == "Potentiel": return Knowledge.sort_value(item,"potential")
	if column == "Date du rapport": return _date_week(report)
	if column == "Rapport":
		var status := report_status(report)
		return U.fold(status) if status in ["Ancien","Daté"] else null
	if column == "Avis":
		return U.fold(report_label(item)) if item.get("knowledge",{}).get("stage","") in ["observed","deep"] else null
	return null

static func sorted(source: Array, column: String, descending: bool, reports: Dictionary, archive: bool = false) -> Array:
	var rows: Array[Dictionary] = []
	for index in source.size():
		var item: Dictionary = source[index]
		rows.append({"item":item,"key":value(item,column,reports,archive),"id":str(item.get("id","")),"index":index})
	rows.sort_custom(func(a: Dictionary,b: Dictionary):
		if a.key == null and b.key != null: return false
		if a.key != null and b.key == null: return true
		if a.key != b.key: return a.key > b.key if descending else a.key < b.key
		if a.id != b.id: return a.id < b.id
		return a.index < b.index)
	return rows.map(func(row: Dictionary): return row.item)
