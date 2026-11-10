extends RefCounted
## Préférences d'interface locales. Aucun état de carrière ni moteur sportif.
signal changed
const Atomic = preload("res://atomic_file.gd")
const AUTOMATIC_SCREEN := -1
const MAX_SCREEN_INDEX := 2147483647
const DEFAULTS := {"version":1,"volume":75,"reduced_motion":false,"quality":"balanced","camera":"tv","display_screen":AUTOMATIC_SCREEN,"stadium":"day","salary_period":"weekly"}
const OPTIONAL_KEYS := ["display_screen","stadium","salary_period"]
const MAX_BYTES := 16 * 1024
var data: Dictionary = DEFAULTS.duplicate(true)
var last_error := ""
var _directory := ""
var _available := false

func _fail(message: String) -> bool:
	last_error = message
	return false

func _validated(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		_fail("Préférences refusées : champs absents ou inconnus. Le fichier original est conservé.")
		return {}
	for key in candidate:
		if not DEFAULTS.has(key):
			_fail("Préférences refusées : champ inconnu « %s ». Le fichier original est conservé." % key)
			return {}
	for key in DEFAULTS:
		if key not in OPTIONAL_KEYS and not candidate.has(key):
			_fail("Préférences refusées : champ absent « %s ». Le fichier original est conservé." % key)
			return {}
	var version: Variant = candidate.version
	if not (typeof(version) in [TYPE_INT,TYPE_FLOAT]) or version != 1:
		_fail("Version des préférences non prise en charge. Le fichier original est conservé.")
		return {}
	var volume: Variant = candidate.volume
	if not (typeof(volume) in [TYPE_INT,TYPE_FLOAT]) or not is_finite(float(volume)) or volume < 0 or volume > 100 or float(volume) != floor(float(volume)):
		_fail("Volume refusé : un entier entre 0 et 100 est attendu.")
		return {}
	if not candidate.reduced_motion is bool or not candidate.quality is String or not candidate.camera is String or not candidate.quality in ["economy","balanced","detail"] or not candidate.camera in ["tv","tactical","action"]:
		_fail("Préférences refusées : type ou choix invalide. Le fichier original est conservé.")
		return {}
	var screen: Variant = candidate.get("display_screen",AUTOMATIC_SCREEN)
	if not (typeof(screen) in [TYPE_INT,TYPE_FLOAT]) or not is_finite(float(screen)) or screen < AUTOMATIC_SCREEN or screen > MAX_SCREEN_INDEX or float(screen) != floor(float(screen)):
		_fail("Écran refusé : choisissez Automatique ou un numéro d’écran valide.")
		return {}
	var stadium: Variant = candidate.get("stadium", DEFAULTS.stadium)
	if not stadium is String or stadium not in ["day","evening"]:
		_fail("Éclairage du stade refusé : choisissez Jour ou Soirée.")
		return {}
	var salary_period: Variant = candidate.get("salary_period",DEFAULTS.salary_period)
	if not salary_period is String or salary_period not in ["weekly","monthly","annual"]:
		_fail("Affichage des salaires refusé : choisissez Hebdomadaire, Mensuel ou Annuel.")
		return {}
	return {"version":1,"volume":int(volume),"reduced_motion":candidate.reduced_motion,"quality":candidate.quality,"camera":candidate.camera,"display_screen":int(screen),"stadium":stadium,"salary_period":salary_period}

func load_profile(directory: String) -> bool:
	_available = false
	if not directory.is_absolute_path() or directory.begins_with("user://") or directory.begins_with("res://"):
		return _fail("Préférences indisponibles : un dossier absolu est requis. Aucun autre dossier ne sera utilisé.")
	_directory = directory.simplify_path()
	if not DirAccess.dir_exists_absolute(_directory):
		var made := DirAccess.make_dir_recursive_absolute(_directory)
		if made != OK: return _fail("Dossier des préférences inaccessible. Vérifiez son emplacement et les droits d’accès.")
	if not DirAccess.dir_exists_absolute(_directory): return _fail("Dossier des préférences inaccessible : ce chemin ne désigne pas un dossier.")
	var path := _directory.path_join("interface.json")
	var candidate: Dictionary = DEFAULTS.duplicate(true)
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null: return _fail("Lecture des préférences impossible. Vérifiez les droits d’accès ; le fichier original est conservé.")
		if file.get_length() > MAX_BYTES:
			file.close()
			return _fail("Préférences trop volumineuses : 16 Kio maximum. Le fichier original est conservé.")
		var content := file.get_as_text()
		var read_error := file.get_error(); file.close()
		if read_error != OK and read_error != ERR_FILE_EOF: return _fail("Lecture des préférences interrompue. Le fichier original est conservé.")
		var parser := JSON.new()
		if parser.parse(content) != OK: return _fail("Préférences JSON illisibles. Le fichier original est conservé.")
		candidate = _validated(parser.data)
		if candidate.is_empty(): return false
	data = candidate
	preload("res://ui/salary_display.gd").configure(str(data.salary_period))
	_available = true
	last_error = ""
	apply_audio()
	_apply_screen()
	changed.emit()
	return true

func _save(candidate: Dictionary) -> bool:
	if not _available:
		if last_error.is_empty(): last_error = "Préférences non chargées : aucun dossier de repli ne sera utilisé."
		return false
	var path := _directory.path_join("interface.json")
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return _fail("Écriture du fichier temporaire refusée. Vérifiez le dossier et les droits d’accès. Les réglages précédents sont conservés.")
	file.store_string(JSON.stringify(candidate,"  ") + "\n")
	file.flush()
	var written := file.get_error(); file.close()
	if written != OK:
		DirAccess.remove_absolute(temporary)
		return _fail("Écriture des préférences interrompue. Vérifiez le stockage et l’espace disponible. Les réglages précédents sont conservés.")
	# Même dossier / même volume : ne jamais supprimer l'original avant rename.
	var replacement_error := Atomic.replace_staged(temporary,path)
	if not replacement_error.is_empty():
		DirAccess.remove_absolute(temporary)
		return _fail("Enregistrement des préférences impossible : " + replacement_error + " Les réglages précédents et le fichier original sont conservés.")
	var screen_changed: bool = data.display_screen != candidate.display_screen
	data = candidate
	preload("res://ui/salary_display.gd").configure(str(data.salary_period))
	last_error = ""
	apply_audio()
	if screen_changed: _apply_screen()
	changed.emit()
	return true

func set_value(key: String, value: Variant) -> bool:
	if not _available:
		return _fail(last_error if not last_error.is_empty() else "Préférences non chargées : aucun dossier de repli ne sera utilisé.")
	if key == "version" or not DEFAULTS.has(key): return _fail("Préférence inconnue : « %s »." % key)
	var candidate := data.duplicate(true)
	candidate[key] = value
	var normalized := _validated(candidate)
	if normalized.is_empty(): return false
	return _save(normalized)

func reset_defaults() -> bool:
	return _save(DEFAULTS.duplicate(true))

func effective_camera() -> String:
	return "tactical" if data.reduced_motion else str(data.camera)

func apply_audio() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		# Respecter le mute de réception/de l'application ; ne jamais toucher à Gabi.
		AudioServer.set_bus_volume_linear(master,float(data.volume)/100.0)

func _apply_screen() -> void:
	var screen: int = data.display_screen
	# Automatique et écran débranché conservent l'écran choisi au lancement.
	if screen >= 0 and DisplayServer.get_name() != "headless" and screen < DisplayServer.get_screen_count():
		DisplayServer.window_set_current_screen(screen)
