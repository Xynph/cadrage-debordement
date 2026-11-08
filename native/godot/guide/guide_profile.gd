extends RefCounted
const Content = preload("res://guide/guide_content.gd")
const AtomicFileStore = preload("res://atomic_file.gd")
const LIMIT := 65536
var data: Dictionary = {"version":1,"enabled":true,"muted":false,"voice":"","rate":1.0,"step":"bienvenue","completed":[],"seen":[],"events":[]}
const EVENT_LIMIT := 128
var last_error := ""
var directory := ""
var _blocked := false

func load_profile(path: String) -> void:
	directory = path
	if not path.is_absolute_path(): _fail("Le dossier du guide doit être absolu."); return
	var filename := path.path_join("guide.json")
	if not FileAccess.file_exists(filename): return
	var file := FileAccess.open(filename, FileAccess.READ)
	if file == null: _fail("Lecture du guide impossible : " + error_string(FileAccess.get_open_error())); return
	if file.get_length() > LIMIT: file.close(); _fail("Le fichier guide.json dépasse 64 Kio ; original conservé."); return
	var text := file.get_as_text()
	var error := file.get_error(); file.close()
	if error != OK and error != ERR_FILE_EOF: _fail("Lecture de guide.json interrompue ; original conservé."); return
	var parser := JSON.new()
	if parser.parse(text) != OK: _fail("guide.json est illisible ; original conservé. Le guide fonctionne sans enregistrer sa progression."); return
	var parsed: Variant = parser.data
	if not _valid(parsed): _fail("guide.json est invalide ; original conservé. Le guide fonctionne sans enregistrer sa progression."); return
	data = parsed.duplicate(true)
	if not data.has("seen"): data.seen = []
	if not data.has("events"): data.events = []

func _valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.get("version") != 1 or not value.get("enabled") is bool or not value.get("muted") is bool: return false
	if not value.get("voice") is String or value.voice.length() > 512: return false
	if not (value.get("rate") is float or value.get("rate") is int): return false
	if not is_finite(float(value.rate)) or value.rate < 0.5 or value.rate > 2.0: return false
	if not value.get("step") is String or value.step not in Content.TOUR: return false
	if not value.get("completed") is Array or value.completed.size() > Content.TOUR.size(): return false
	var seen := {}
	for id in value.completed:
		if not id is String or id not in Content.TOUR or seen.has(id): return false
		seen[id] = true
	if not value.get("seen", []) is Array or value.get("seen", []).size() > Content.CONTEXT_PAGES.size(): return false
	seen.clear()
	for id in value.get("seen", []):
		if not id is String or id not in Content.CONTEXT_PAGES or seen.has(id): return false
		seen[id] = true
	if not value.get("events", []) is Array or value.get("events", []).size() > EVENT_LIMIT: return false
	seen.clear()
	var pattern := RegEx.new()
	pattern.compile("^(cash|signed|season):[0-9]{1,4}:[0-9]{1,6}:[0-9]{1,4}:[a-f0-9]{0,16}$")
	for id in value.get("events", []):
		if not id is String or id.length() > 64 or pattern.search(id) == null or seen.has(id): return false
		seen[id] = true
	return true

func _fail(message: String) -> void:
	last_error = message
	_blocked = true

func save_profile(value: Dictionary) -> bool:
	if _blocked: return false
	if not _valid(value): last_error = "Préférences du guide invalides ; écriture refusée."; return false
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK: last_error = "Dossier du guide inaccessible : " + error_string(error); return false
	var filename := directory.path_join("guide.json")
	var temporary := filename + ".tmp-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: last_error = "Écriture du guide refusée : " + error_string(FileAccess.get_open_error()); return false
	file.store_string(JSON.stringify(value)); file.flush()
	error = file.get_error(); file.close()
	var replace_error := error_string(error) if error != OK else AtomicFileStore.replace_staged(temporary, filename)
	if not replace_error.is_empty():
		DirAccess.remove_absolute(temporary)
		last_error = "Écriture atomique du guide refusée : " + replace_error
		return false
	data = value.duplicate(true)
	last_error = ""
	return true
