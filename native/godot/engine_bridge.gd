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
var model: Dictionary = {}
var last_response_ok := false
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
	while true:
		_wake.wait()
		_mutex.lock()
		if _queue.is_empty():
			_mutex.unlock()
			return
		var request: Dictionary = _queue.pop_front()
		_mutex.unlock()
		_stdio.store_buffer((JSON.stringify(request) + "\n").to_utf8_buffer())
		if _stdio.get_error() != OK:
			call_deferred("_transport_error", "Écriture impossible vers le moteur local.")
			return
		# get_line and large writes may block this worker thread, never the UI.
		var line := _stdio.get_line()
		var parser := JSON.new()
		if line.is_empty() or parser.parse(line) != OK:
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
		call_deferred("_accept", response)
		if request.command == "shutdown":
			return

func _accept(response: Dictionary) -> void:
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
	if child_pid > 0 and OS.is_process_running(child_pid):
		OS.kill(child_pid)
	command_failed.emit(message)

func _process(_delta: float) -> void:
	if _stopping and _stop_deadline_ms > 0 and Time.get_ticks_msec() >= _stop_deadline_ms and child_pid > 0 and OS.is_process_running(child_pid):
		OS.kill(child_pid)
	if child_pid > 0 and not OS.is_process_running(child_pid):
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
