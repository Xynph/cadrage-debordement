class_name NativeEngineBridge
extends Node
## Private JSON-lines worker. All blocking pipe operations run on _thread.
## Node already owns `ready`; model_changed is the authoritative engine-ready event.
signal model_changed(model: Dictionary)
signal command_failed(message: String)

const IMPORT_LIMIT_BYTES := 8 * 1024 * 1024
const WORLD_IMPORT_LIMIT_BYTES := 16 * 1024 * 1024
const REQUEST_LIMIT_BYTES := 17 * 1024 * 1024
const WORLD_REQUEST_LIMIT_BYTES := 34 * 1024 * 1024
const NATIONALE_IMPORT_LIMIT_BYTES := 20 * 1024 * 1024
const EXTENDED_IMPORT_LIMIT_BYTES := 24 * 1024 * 1024
const EXTENDED_REQUEST_LIMIT_BYTES := 50 * 1024 * 1024
const RESPONSE_BLOCK_BYTES := 64 * 1024
const LINE_FEED := 10
var model: Dictionary = {}
var last_response_ok := false
## Dernière mesure du pont (commande, moteur_ms, analyse_ms, file_ms, octets).
var last_timing: Dictionary = {}
var child_pid: int = -1
var _stdio: FileAccess
var _stderr: FileAccess
var _thread: Thread
var _stderr_thread: Thread
var _mutex := Mutex.new()
var _wake := Semaphore.new()
var _queue: Array[Dictionary] = []
var _next_id: int = 0
var _stopping: bool = false
var _stop_deadline_ms: int = 0
# Modèle de référence des réponses différentielles : propriété exclusive du fil d’E/S.
var _base_model: Dictionary = {}
var _base_revision: int = -1

static func import_preflight(text: String, byte_count: int) -> String:
	if byte_count <= IMPORT_LIMIT_BYTES: return ""
	if byte_count > EXTENDED_IMPORT_LIMIT_BYTES: return "Fichier trop volumineux (24 Mio UTF-8 maximum)."
	var parser := JSON.new()
	if parser.parse(text) == OK and parser.data is Dictionary:
		var state: Variant = parser.data.get("state")
		if state is Dictionary:
			var mode: Variant = state.get("worldMode")
			var database: Variant = state.get("commonDatabase")
			if mode is Dictionary and database is Dictionary and database.size() == 2 and not state.has("franceMode") and not state.has("lnrMode"):
				var id := str(database.get("id", ""))
				var versions := {"rugby-world-2026-11-08-v1": 1, "rugby-world-2026-11-09-pacific-v2": 2, "rugby-world-2026-11-09-japan-v3": 3, "rugby-world-2026-11-09-nationale-v4": 4, "rugby-world-2026-11-09-champ-v5": 5}
				if versions.has(id) and mode.get("catalogue") == id and mode.get("version") == versions[id] and database.get("version") == versions[id]:
					var version := int(versions[id])
					var cap := EXTENDED_IMPORT_LIMIT_BYTES if version == 5 else (NATIONALE_IMPORT_LIMIT_BYTES if version == 4 else WORLD_IMPORT_LIMIT_BYTES)
					return "" if byte_count <= cap else "Fichier trop volumineux (%d Mio UTF-8 maximum pour cette édition)." % int(float(cap) / 1048576.0)
	return "Fichier trop volumineux (8 Mio UTF-8 maximum pour cette édition)."

func start(data_dir: String) -> void:
	if child_pid > 0 or _thread != null:
		command_failed.emit("Le moteur est déjà démarré.")
		return
	var root := OS.get_executable_path().get_base_dir()
	var node_path := root.path_join("runtime/node.exe")
	var worker_path := root.path_join("engine/worker.cjs")
	if OS.has_feature("editor"):
		worker_path = ProjectSettings.globalize_path("res://../engine/worker.cjs")
		node_path = str(ProjectSettings.get_setting("native_engine/node_executable", node_path))
		worker_path = str(ProjectSettings.get_setting("native_engine/worker_path", worker_path))
		if OS.has_environment("CD_NODE_EXECUTABLE"):
			node_path = OS.get_environment("CD_NODE_EXECUTABLE")
	if not FileAccess.file_exists(node_path) or not FileAccess.file_exists(worker_path):
		command_failed.emit("Moteur embarqué introuvable : " + node_path + " · " + worker_path)
		return
	if not data_dir.is_absolute_path():
		command_failed.emit("Le dossier PrototypeGodot doit être absolu.")
		return
	# No command interpreter, network server, or browser process.
	var process := OS.execute_with_pipe(node_path, PackedStringArray([worker_path, "--data-dir", data_dir]), true)
	if process.is_empty():
		command_failed.emit("Impossible de démarrer le moteur local.")
		return
	_stdio = process.stdio
	_stderr = process.stderr
	child_pid = int(process.pid)
	_stopping = false
	_stop_deadline_ms = 0
	_wake = Semaphore.new()
	_base_model = {}
	_base_revision = -1
	_thread = Thread.new()
	var error := _thread.start(_io_loop)
	if error != OK:
		OS.kill(child_pid)
		_release()
		command_failed.emit("Impossible de démarrer le pont asynchrone.")
		return
	_stderr_thread = Thread.new()
	if _stderr_thread.start(_stderr_loop) != OK:
		OS.kill(child_pid)
		_release()
		command_failed.emit("Impossible de lire les erreurs du moteur local.")
		return
	set_process(true)
	send("snapshot")

func send(command: String, payload: Dictionary = {}) -> void:
	if _stopping or child_pid <= 0:
		command_failed.emit("Le moteur est fermé.")
		return
	_next_id += 1
	var request := {"id": _next_id, "command": command, "payload": payload.duplicate(true)}
	# The reader applies the edition-specific 8/16/20/24 MiB save limits. Only imports
	# can use the larger bounded envelope for escaped world save text.
	if command == "import":
		var text := str(payload.get("text", ""))
		var refusal := import_preflight(text,text.to_utf8_buffer().size())
		if not refusal.is_empty():
			command_failed.emit(refusal)
			return
	var envelope_limit := EXTENDED_REQUEST_LIMIT_BYTES if command == "import" else REQUEST_LIMIT_BYTES
	if JSON.stringify(request).to_utf8_buffer().size() > envelope_limit:
		command_failed.emit("Message trop volumineux après encodage JSON.")
		return
	_mutex.lock()
	_queue.append(request)
	_mutex.unlock()
	_wake.post()

func stop() -> void:
	if child_pid <= 0 or _stopping:
		return
	send("shutdown")
	_stopping = true
	_stop_deadline_ms = Time.get_ticks_msec() + 2000

func _io_loop() -> void:
	var pending := PackedByteArray()
	while true:
		_wake.wait()
		_mutex.lock()
		if _queue.is_empty():
			_mutex.unlock()
			return
		var request: Dictionary = _queue.pop_front()
		_mutex.unlock()
		var sent_us := Time.get_ticks_usec()
		# Annonce la révision détenue : le moteur ne renvoie alors que les parties modifiées.
		var envelope := request.duplicate()
		envelope["base"] = _base_revision
		_stdio.store_buffer((JSON.stringify(envelope) + "\n").to_utf8_buffer())
		if _stdio.get_error() != OK:
			call_deferred("_transport_error", "Écriture impossible vers le moteur local.")
			return
		# Keep bytes across reads and decode only a complete JSON line.
		var end := pending.find(LINE_FEED)
		while end < 0:
			var block := _stdio.get_buffer(RESPONSE_BLOCK_BYTES)
			# Godot can flag a short pipe read as an error even when it returned bytes.
			if block.is_empty():
				call_deferred("_transport_error", "Réponse du moteur local illisible ou processus arrêté.")
				return
			var start := pending.size()
			pending.append_array(block)
			end = pending.find(LINE_FEED, start)
		var remainder := pending.slice(end + 1)
		pending.resize(end)
		var line := pending.get_string_from_utf8()
		pending = remainder
		var received_us := Time.get_ticks_usec()
		var parser := JSON.new()
		var parse_error := parser.parse(line) if not line.is_empty() else ERR_PARSE_ERROR
		if line.is_empty() or parse_error != OK:
			call_deferred("_transport_error", "Réponse du moteur local illisible ou processus arrêté.")
			return
		var response: Variant = parser.data
		if not response is Dictionary:
			call_deferred("_transport_error", "Réponse du moteur local illisible ou processus arrêté.")
			return
		if response.get("id") != request.id and response.get("id") != null:
			call_deferred("_transport_error", "Réponse du moteur : identifiant inattendu.")
			return
		if response.get("id") == null:
			# Uncorrelated responses cannot complete a queued request safely.
			# Terminate our child rather than leaving a live worker with no reader.
			call_deferred("_transport_error", str(response.get("error", "Réponse sans identifiant : moteur fermé.")))
			return
		if response.get("patch") is Dictionary:
			var rebuilt := _apply_patch(response.patch)
			if rebuilt.is_empty() and not response.patch.get("keys", []).is_empty():
				call_deferred("_transport_error", "Réponse différentielle du moteur illisible.")
				return
			response.erase("patch")
			# Copie profonde : l’interface reçoit un modèle neuf, comme une réponse complète.
			response["model"] = rebuilt.duplicate(true)
		# Mesure du pont : moteur + transfert, puis analyse JSON (fil d’E/S).
		response["_pont"] = {"command": str(request.command), "moteur_ms": (received_us - sent_us) / 1000.0, "analyse_ms": (Time.get_ticks_usec() - received_us) / 1000.0, "octets": line.length(), "recu_us": Time.get_ticks_usec()}
		call_deferred("_accept", response)
		if request.command == "shutdown":
			return

## Reconstruit le modèle complet (mêmes clés, même ordre) à partir de la référence.
func _apply_patch(patch: Dictionary) -> Dictionary:
	var keys: Variant = patch.get("keys")
	var changed: Variant = patch.get("set")
	var nested: Variant = patch.get("sub")
	if not (keys is Array and changed is Dictionary and nested is Dictionary): return {}
	var full := bool(patch.get("full", true))
	var next: Dictionary = {}
	for key: Variant in keys:
		if nested.has(key):
			var part: Variant = nested[key]
			if not (part is Dictionary and part.get("keys") is Array and part.get("set") is Dictionary): return {}
			var previous: Variant = {} if full else _base_model.get(key)
			var before: Dictionary = previous if previous is Dictionary else {}
			var inner: Dictionary = {}
			for name: Variant in part.keys:
				if part.set.has(name): inner[name] = part.set[name]
				elif before.has(name): inner[name] = before[name]
				else: return {}
			next[key] = inner
		elif changed.has(key): next[key] = changed[key]
		elif not full and _base_model.has(key): next[key] = _base_model[key]
		else: return {}
	_base_model = next
	_base_revision = int(patch.get("rev", -1))
	return next

func _accept(response: Dictionary) -> void:
	last_timing = response.get("_pont", {})
	last_timing["file_ms"] = (Time.get_ticks_usec() - int(last_timing.get("recu_us", Time.get_ticks_usec()))) / 1000.0
	last_response_ok = bool(response.get("ok", false))
	if response.get("model") is Dictionary:
		model = response.model
		model_changed.emit(model)
	if not response.get("ok", false):
		command_failed.emit(str(response.get("error", "Commande refusée.")))

func _stderr_loop() -> void:
	while true:
		var line := _stderr.get_line()
		if not line.is_empty():
			call_deferred("_report_stderr", line)
		if _stderr.get_error() != OK:
			return

func _report_stderr(message: String) -> void:
	command_failed.emit("Moteur local : " + message)

func _transport_error(message: String) -> void:
	_stopping = true
	_mutex.lock()
	_queue.clear()
	_mutex.unlock()
	if child_pid > 0:
		if OS.is_process_running(child_pid):
			if OS.kill(child_pid) == OK: _release()
		else:
			_release()
	command_failed.emit(message)

func _process(_delta: float) -> void:
	if child_pid <= 0: return
	# Poll once. Successful OS.kill also reaps the child on Unix; release it
	# immediately rather than querying that PID again on the following frame.
	var running := OS.is_process_running(child_pid)
	if _stopping and _stop_deadline_ms > 0 and Time.get_ticks_msec() >= _stop_deadline_ms and running:
		if OS.kill(child_pid) == OK: _release()
		return
	if not running:
		if not _stopping:
			command_failed.emit("Le processus moteur s’est arrêté.")
		_release()

func _release() -> void:
	# Called only once the child is dead, so pipe reads cannot remain blocked.
	if _thread != null:
		_wake.post()
		if _thread.is_started():
			_thread.wait_to_finish()
		_thread = null
	if _stderr_thread != null:
		if _stderr_thread.is_started():
			_stderr_thread.wait_to_finish()
		_stderr_thread = null
	if _stdio != null:
		_stdio.close()
	if _stderr != null:
		_stderr.close()
	_stdio = null
	_stderr = null
	child_pid = -1
	_mutex.lock()
	_queue.clear()
	_mutex.unlock()
	set_process(false)

func _exit_tree() -> void:
	# Normal stop() completes asynchronously. Forced application close still
	# terminates the child; the next launch checks/reclaims a dead-PID lock.
	if child_pid > 0 and OS.is_process_running(child_pid):
		OS.kill(child_pid)
	_release()
