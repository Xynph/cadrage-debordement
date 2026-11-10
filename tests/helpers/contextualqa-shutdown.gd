extends SceneTree
# Exercise delayed shutdown polling for a naturally exited and a busy worker.
# A forced Unix kill must release the child without querying its reaped PID.
const Bridge = preload("res://engine_bridge.gd")
var bridge: Node
var failures: Array[String] = []
var cancellation_messages: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message); printerr("SHUTDOWN FAIL: " + message)

func run() -> void:
	var directory := OS.get_environment("CD_GODOT_DATA_DIR")
	if directory.is_empty(): quit(1); return
	await run_case(directory.path_join("natural"), false)
	await run_case(directory.path_join("forced"), true)
	print("CONTEXTUAL_SHUTDOWN_CHECKS ", JSON.stringify({"failures":failures,"real_worker":true,"expired_deadline":true,"forced_kill":true,"cancellation_messages":cancellation_messages}))
	quit(0 if failures.is_empty() else 1)

func run_case(directory: String, forced: bool) -> void:
	bridge = Bridge.new()
	root.add_child(bridge)
	bridge.command_failed.connect(func(message: String):
		if forced and (message.contains("Réponse du moteur local illisible") or message.contains("Écriture impossible")):
			cancellation_messages.append(message)
		else: failures.append(message))
	bridge.start(directory)
	var deadline := Time.get_ticks_msec() + 20000
	while bridge.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(not bridge.model.is_empty() and bridge.last_response_ok, "Real production worker started")
	check(bridge.child_pid > 0, "Bridge owns actual worker child")
	# Simulate a delayed main-thread poll; both pipe threads still run normally.
	bridge.set_process(false)
	if forced:
		# Keep the genuine worker busy when the expired timeout forces cancellation.
		bridge.send("new_career", {"mode":"common","club":29})
		await create_timer(0.02).timeout
		check(OS.is_process_running(bridge.child_pid), "Real worker is alive before forced shutdown")
	bridge.stop()
	if forced:
		bridge._stop_deadline_ms = maxi(1, Time.get_ticks_msec() - 1)
		bridge._process(0.0)
		check(bridge.child_pid == -1 and bridge._thread == null and bridge._stderr_thread == null, "Forced kill immediately releases the owned child and pipe threads")
		for i in 3: await process_frame
		bridge.queue_free()
		await process_frame
		return
	deadline = Time.get_ticks_msec() + 5000
	while ((bridge._thread != null and bridge._thread.is_alive()) or (bridge._stderr_thread != null and bridge._stderr_thread.is_alive())) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(bridge._thread != null and not bridge._thread.is_alive(), "Shutdown response returned through real IO thread")
	check(bridge._stderr_thread != null and not bridge._stderr_thread.is_alive(), "Real child closed stderr at exit")
	await create_timer(0.05).timeout
	bridge._stop_deadline_ms = maxi(1, Time.get_ticks_msec() - 1)
	bridge._process(0.0)
	check(bridge.child_pid == -1 and bridge._thread == null and bridge._stderr_thread == null, "Expired shutdown poll reaps once and releases all owned resources")
	bridge.queue_free()
	await process_frame
