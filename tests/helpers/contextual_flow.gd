extends RefCounted

# Exercise the public continuation with the worker's actual scene identity.
static func skip_talk(app: Control, tree: SceneTree, expected_phase: String, check: Callable) -> void:
	var value: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
	var scene: Dictionary = value if value is Dictionary else {}
	check.call(scene.get("phase") == expected_phase and scene.get("options", []).size() == 6, "Causerie réelle à six choix : " + expected_phase)
	if scene.get("phase") != expected_phase: return
	check.call(app._command("match_talk_continue", {"key":scene.key, "phase":scene.phase, "skip":true}), "Passer explicitement la causerie : " + expected_phase)
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await tree.process_frame
	app.timer.stop()
	check.call(not app.waiting and app.bridge.last_response_ok, "Continuation contextuelle acceptée : " + expected_phase)
	check.call(app.model.get("clubLife", {}).get("matchTalks", {}).get("scene") == null, "Causerie traitée sans contourner sa garde")
