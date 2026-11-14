class_name WindowsHardwareReceipt
extends "windows-resume.gd"

const CareerQa = preload("res://qa_runner.gd")
const GabiPortrait = preload("res://guide/coach_portrait_3d.gd")
const Highlights = preload("res://ui/contextual/match_temps_forts.gd")
var phase := OS.get_environment("CD_WINDOWS_HARDWARE_PHASE")
var helper: Node

func driver_mode() -> String:
	return "hardware"

func run() -> void:
	report.phase = phase
	report.match = {}
	check(OS.get_name() == "Windows" and DisplayServer.get_name() == "Windows" and not OS.has_feature("editor"), "Actual exported Windows graphics required")
	check(phase in ["play", "resume"], "Explicit hardware receipt phase")
	var renderer := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	var adapter := RenderingServer.get_video_adapter_name()
	report.runtime_info = {"renderer":renderer, "driver":driver, "adapter":adapter,
		"vendor":RenderingServer.get_video_adapter_vendor(), "api_version":RenderingServer.get_video_adapter_api_version()}
	check(renderer == OS.get_environment("CD_WINDOWS_HARDWARE_METHOD"), "Requested rendering method initialized")
	check(driver == OS.get_environment("CD_WINDOWS_HARDWARE_DRIVER"), "Requested native rendering driver initialized")
	check("geforce rtx 4080 super" in adapter.to_lower(), "NVIDIA GeForce RTX 4080 SUPER initialized")
	if not failures.is_empty():
		await finish()
		return
	var save_path := profile.path_join("donnees.json")
	check(FileAccess.file_exists(save_path) == (phase == "resume"), "Receipt uses the expected fresh or saved profile")
	if not failures.is_empty():
		await finish()
		return
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	if not await wait_ready():
		await finish()
		return
	engine_pid = app.bridge.child_pid
	await resize_native()
	if phase == "play":
		await play_career(save_path)
	else:
		await resume_career(save_path)
	report.graphics.passed = failures.is_empty()
	await finish()

func play_career(save_path: String) -> void:
	check(not app._has_career() and app.route == "Accueil", "Fresh profile opens the real start menu")
	if not failures.is_empty(): return
	await capture("01-accueil")
	helper = CareerQa.new()
	helper.app = app
	helper.auto_start = false
	app.add_child(helper)
	if not await create_career():
		check(false, "Career creation through the native picker failed")
		return
	app.coach.open_help()
	var portrait: TextureRect = app.coach.portrait
	var gabi_ok: bool = portrait is GabiPortrait and portrait.is_visible_in_tree() and portrait._profile == "mixamo"
	check(gabi_ok, "Private Mixamo Gabi is displayed")
	if not gabi_ok: return
	var animation: AnimationPlayer = portrait._animations
	check(animation != null and animation.has_animation("salut") and animation.is_playing(), "Private Gabi gesture is playing")
	report.gabi_mixamo = gabi_ok
	await capture("02-gabi")
	app.coach.close()
	if not await helper._reach_world_match_day():
		check(false, "The first fixture must be reachable from the new career")
		return
	if not app.model.selection.valid:
		if not await helper._ask("auto_lineup"):
			check(false, "Select the first fixture lineup")
			return
	if not await helper._ask("begin_match") or not await CareerQa.continue_match_phase(app, self, check, "pre"):
		check(false, "Kickoff and the pre-match talk succeed")
		return
	app._navigate("Match")
	if not await play_highlights(): return
	if not await ask("save", {}, true): return
	check(FileAccess.file_exists(save_path), "Match career was saved to the disposable profile")

func create_career() -> bool:
	# Mode unique Monde (13/11/2026) : la recette crée la carrière comme le joueur, dans le Monde complet.
	app.pack_manager.creation_mode = "auto"
	app._navigate("Création")
	await helper._settle()
	if not helper._press_named("CreationDivision_accession"): return false
	await helper._settle()
	if not helper._press_named("CreationClub29"): return false
	await helper._settle()
	if not helper._press_named("CreationStart") or not await wait_ready(): return false
	return app._has_career() and int(app.model.get("club", {}).get("id", -1)) == 29 and app.model.get("meta", {}).get("edition") == "world-champ"

func active_highlights() -> Node:
	var director: Node = app.contextual_director
	if not director.active() or not is_instance_valid(director.view): return null
	return director.view.get_node_or_null("MatchTempsForts")

func play_highlights() -> bool:
	var deadline := Time.get_ticks_msec() + 660000
	var seen: Dictionary = {}
	var adapted_players := 0
	var captured := false
	var finished: Dictionary = {}
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if app.waiting: continue
		var live: Variant = app.model.get("live")
		if not live is Dictionary: continue
		var regie := active_highlights()
		if regie != null:
			for event: Dictionary in regie.suivi:
				if event.get("evenement") == "temps_fort":
					seen[str(event.cle)] = true
			if regie.etat == Highlights.JEU and not captured:
				for actor: Dictionary in regie.stage._actors.values():
					var player: AnimationPlayer = actor.animation
					if actor.adapted and is_instance_valid(player) and str(player.current_animation).begins_with("mx/"):
						adapted_players += 1
				if adapted_players > 0:
					await capture("03-match-temps-forts")
					captured = true
		var talk: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if is_instance_valid(regie) and regie.retient(live): continue
		if live.get("finished", false):
			finished = live.duplicate(true)
			break
		if talk is Dictionary and talk.get("phase") == "half":
			if not await CareerQa.continue_match_phase(app, self, check, "half"): return false
			app._navigate("Match")
		elif live.get("paused", false):
			if not await ask("pause", {"paused":false}, true): return false
	check(not finished.is_empty(), "Match finished through the actual highlights director")
	check(captured and not seen.is_empty() and adapted_players > 0, "At least one live highlight rendered with playing Mixamo animations")
	report.match = {"finished":not finished.is_empty(), "highlights_seen":seen.size(),
		"adapted_players":adapted_players, "score":finished.get("score", [])}
	if not failures.is_empty(): return false
	await capture("04-resultat")
	var post: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
	if post is Dictionary and post.get("phase") == "post":
		return await CareerQa.continue_match_phase(app, self, check, "post")
	return true

func resume_career(save_path: String) -> void:
	var expected := OS.get_environment("CD_WINDOWS_HARDWARE_SAVE_SHA")
	check(not expected.is_empty() and FileAccess.get_sha256(save_path) == expected, "Relaunch opened the exact saved profile")
	check(app._has_career(), "Relaunch loaded an existing career")
	if not failures.is_empty(): return
	var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(stored is Dictionary and stored.get("store", {}).get("bdt-v1") is String, "Saved career document is readable")
	if not failures.is_empty() or not await ask("export",{"proof":true}): return
	var exported: Variant = JSON.parse_string(app.model.get("meta", {}).get("exportText", ""))
	var resumed := JSON.parse_string(stored.store["bdt-v1"]) as Dictionary
	var proof := str(app.model.get("meta", {}).get("exportRoundTripSha256", ""))
	var reduced: bool = exported is Dictionary and int(exported.get("exportVersion", 1)) != 1
	var exact: bool = exported is Dictionary and not proof.is_empty() and proof == str(stored.store["bdt-v1"]).sha256_text() and (reduced or exported.get("state") == resumed)
	check(exact and FileAccess.get_sha256(save_path) == expected, "Relaunch reproduces the saved state without changing its bytes")
	report.before = {"state_matches":exact, "save_sha256":expected}
	app._navigate("Réception")
	await capture("05-reprise")
