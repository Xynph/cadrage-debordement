extends "windows-resume.gd"
# A short startup/graphics probe of the real exported EXE. No career is created.
# Inherits actual window capture, runtime observation and silent shutdown helpers.
func run() -> void:
	report.mode = "graphics-smoke"
	report.scope = "graphics-smoke-only"
	check(OS.get_environment("CD_GODOT_SELF_TEST") == "0", "Long self-test disabled for the short graphical preflight")
	check(OS.get_name() == "Windows" and not OS.has_feature("editor") and DisplayServer.get_name() == "Windows", "Actual exported Windows graphics required")
	if not failures.is_empty(): await finish(); return
	DirAccess.make_dir_recursive_absolute(output)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	check(is_instance_valid(app.coach) and is_instance_valid(app.coach.speech), "Real Gabi is present")
	if is_instance_valid(app.coach) and is_instance_valid(app.coach.speech):
		app.coach.speech.started.connect(func(_id: int): events.starts += 1)
		app.coach.speech.ended.connect(func(_id: int): events.ends += 1)
		check(app.coach.speech.player == null and app.coach.speech.voices.is_empty(), "No Gabi audio player or voice is allocated")
	if not await wait_ready(): await finish(); return
	engine_pid = app.bridge.child_pid
	check(not app._has_career(), "Graphics probe leaves a fresh profile without a career")
	await resize_native()
	await capture("01-exported-exe-1440p")
	await runtime_information()
	report.runtime_info.api_version = RenderingServer.get_video_adapter_api_version()
	report.runtime_info.argv = OS.get_cmdline_args()
	report.exported = not OS.has_feature("editor")
	report.graphics.passed = failures.is_empty()
	await finish()
