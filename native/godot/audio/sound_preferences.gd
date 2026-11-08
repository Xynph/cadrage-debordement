extends RefCounted
## Réglages sonores locaux, indépendants de l'interface v1 et des carrières.
signal changed
signal error_changed(message: String)
const Atomic = preload("res://atomic_file.gd")
const DEFAULTS := {"version": 1, "interface_volume": 35, "stadium_volume": 25}
const MAX_BYTES := 4096
var data: Dictionary = DEFAULTS.duplicate(true)
var last_error := ""
var _directory := ""
var _available := false

func _fail(message: String) -> bool:
	last_error = message
	error_changed.emit(message)
	return false

func _validated(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary or candidate.size() != DEFAULTS.size():
		_fail("Réglages sonores refusés : champs absents ou inconnus. Original conservé.")
		return {}
	for key in DEFAULTS:
		if not candidate.has(key):
			_fail("Réglages sonores refusés : champ absent « %s ». Original conservé." % key)
			return {}
		var value: Variant = candidate[key]
		if not typeof(value) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) != floor(float(value)):
			_fail("Réglage sonore refusé : un entier est attendu pour « %s »." % key)
			return {}
		if (key == "version" and value != 1) or (key != "version" and (value < 0 or value > 100)):
			_fail("Version sonore inconnue ou volume hors de 0 à 100. Original conservé.")
			return {}
	return {"version": 1, "interface_volume": int(candidate.interface_volume), "stadium_volume": int(candidate.stadium_volume)}

func load_profile(directory: String) -> bool:
	_available = false
	if not directory.is_absolute_path() or directory.begins_with("res://") or directory.begins_with("user://"):
		return _fail("Réglages sonores indisponibles : dossier absolu requis ; aucun repli.")
	_directory = directory.simplify_path()
	if not DirAccess.dir_exists_absolute(_directory) and DirAccess.make_dir_recursive_absolute(_directory) != OK:
		return _fail("Dossier des réglages sonores inaccessible. Aucun autre dossier utilisé.")
	var path := _directory.path_join("sound.json")
	var candidate := DEFAULTS.duplicate(true)
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return _fail("Lecture des réglages sonores refusée. Original conservé.")
		if file.get_length() > MAX_BYTES:
			file.close()
			return _fail("Réglages sonores trop volumineux : 4 Kio maximum. Original conservé.")
		var content := file.get_as_text()
		var error := file.get_error()
		file.close()
		if error not in [OK, ERR_FILE_EOF]:
			return _fail("Lecture des réglages sonores interrompue. Original conservé.")
		var parser := JSON.new()
		if parser.parse(content) != OK:
			return _fail("Réglages sonores JSON illisibles. Original conservé.")
		candidate = _validated(parser.data)
		if candidate.is_empty():
			return false
	data = candidate
	_available = true
	last_error = ""
	error_changed.emit("")
	changed.emit()
	return true

func get_value(key: String) -> int:
	return int(data.get(key, 0))

func set_value(key: String, value: Variant) -> bool:
	if not _available:
		return _fail(last_error if not last_error.is_empty() else "Réglages sonores non chargés : aucun dossier de repli.")
	if key not in ["interface_volume", "stadium_volume"]:
		return _fail("Réglage sonore inconnu : « %s »." % key)
	var next := data.duplicate(true)
	next[key] = value
	var candidate := _validated(next)
	if candidate.is_empty():
		return false
	var destination := _directory.path_join("sound.json")
	var temporary := destination + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail("Écriture temporaire des réglages sonores refusée. Réglages précédents conservés.")
	file.store_string(JSON.stringify(candidate, "  ") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return _fail("Écriture des réglages sonores interrompue. Réglages précédents conservés.")
	var error := Atomic.replace_staged(temporary, destination)
	if not error.is_empty():
		DirAccess.remove_absolute(temporary)
		return _fail("Enregistrement sonore impossible : " + error + " Original et réglages précédents conservés.")
	data = candidate
	last_error = ""
	error_changed.emit("")
	changed.emit()
	return true
