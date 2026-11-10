extends RefCounted
## Dates publiées seulement : aucune séance ni absence n'est enregistrée ici.
const DAY_SECONDS := 86400
const FILTERS := ["all","matches","training","absences","travel"]

static func valid_date(value: Variant) -> bool:
	if not value is String or value.length() != 10: return false
	var parts: PackedStringArray = value.split("-")
	if parts.size() != 3 or parts[0].length() != 4 or parts[1].length() != 2 or parts[2].length() != 2: return false
	for part in parts:
		if not part.is_valid_int(): return false
	var year: int = parts[0].to_int()
	var month: int = parts[1].to_int()
	var day: int = parts[2].to_int()
	if year < 2 or year > 9998 or month < 1 or month > 12 or day < 1 or day > 31: return false
	var length := 29 if month == 2 and year%4 == 0 and (year%100 != 0 or year%400 == 0) else 28 if month == 2 else 30 if month in [4,6,9,11] else 31
	return day <= length

static func shift(date: String, amount: int) -> String:
	if not valid_date(date): return ""
	var value := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_datetime_string(date+"T00:00:00"))+amount*DAY_SECONDS)
	return value if valid_date(value) else ""

static func week(date: String) -> Array[String]:
	var result: Array[String] = []
	if not valid_date(date): return result
	var stamp := int(Time.get_unix_time_from_datetime_string(date+"T00:00:00"))
	var weekday := (int(Time.get_datetime_dict_from_unix_time(stamp).weekday)+6)%7
	for offset in 7:
		var day := shift(date,offset-weekday)
		if not day.is_empty(): result.append(day)
	return result

static func fixture_key(fixture: Dictionary) -> String:
	var id := str(fixture.get("id",""))
	if not id.is_empty(): return id+"/"+str(fixture.get("date",""))
	return "%s/%s/%s" % [fixture.get("date",""),fixture.get("home",{}).get("id",""),fixture.get("away",{}).get("id","")]

static func unique_fixtures(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	for value: Variant in source:
		if not value is Dictionary: continue
		var key := fixture_key(value)
		if seen.has(key): continue
		seen[key] = true
		result.append(value)
	return result

static func absence_events(model: Dictionary, date: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not valid_date(date): return result
	var international: Dictionary = model.get("international") if model.get("international") is Dictionary else {}
	var availability: Dictionary = international.get("availability") if international.get("availability") is Dictionary else {}
	if not availability.get("clubManaged",false): return result
	var sources: Array = availability.get("players",[]).duplicate()
	sources.append_array(availability.get("returned",[]))
	var seen := {}
	for player: Dictionary in sources:
		var from: Variant = player.get("from")
		var through: Variant = player.get("through")
		var return_date: Variant = player.get("returnDate")
		var id := str(player.get("id",""))
		if id.is_empty(): continue
		if valid_date(from) and valid_date(through) and date >= from and date <= through:
			if seen.has("absence/"+id): continue
			seen["absence/"+id] = true
			result.append({"kind":"absence","player":player,"id":"absence/"+id+"/"+date})
		elif valid_date(return_date) and date == return_date:
			if seen.has("return/"+id): continue
			seen["return/"+id] = true
			result.append({"kind":"return","player":player,"id":"return/"+id+"/"+date})
	result.sort_custom(func(a: Dictionary,b: Dictionary): return a.id < b.id)
	return result
