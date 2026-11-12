extends SceneTree
## Gestes adaptés (bibliothèque CD_MATCH_ANIMATIONS) dans le match 3D, en --headless.
## 1. Sans bibliothèque : aucun geste adapté, les poses procédurales restent (repli).
## 2. Avec une bibliothèque complète : lancer en touche calé sur le lâcher, ballon porté
##    où la défense se lie (cinq adversaires), essai suivi du relevé et de la joie du
##    marqueur, joie des partenaires, déception des adversaires ; pénalité frappée,
##    réception d'un jeu au pied ; geste au sol qui garde sa place puis enchaîne le relevé.
## 3. Les clips qui se déplacent (élan, chute) sont ramenés sur place au chargement.
## La bibliothèque d'essai est fabriquée ici à partir des clips d'origine du joueur
## (aucun fichier tiers) ; seul l'enchaînement est vérifié, pas l'allure des clips.

const View = preload("res://match_view.gd")
const Animations = preload("res://match_animations.gd")
const Presentation = preload("res://match_presentation.gd")
const Gestes = preload("res://match_gestes.gd")
const ATHLETE := "res://assets/match3d/quaternius-rugby-athlete.glb"
const STEP := 1.0 / 30.0

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)


func find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child: Node in node.get_children():
		var found := find_player(child)
		if found:
			return found
	return null


## Bibliothèque d'essai : tous les clips attendus, recopiés des clips d'origine. Le lancer
## reçoit un élan artificiel (le bassin avance de 3 m et monte de 10 cm) pour vérifier que
## le déplacement horizontal est retiré au chargement et la verticale gardée.
func write_library(path: String) -> bool:
	var scene := (load(ATHLETE) as PackedScene).instantiate()
	var player := find_player(scene)
	var source := {}
	var body_path := NodePath()
	for clip: StringName in player.get_animation_list():
		for suffix in ["Man_Idle", "Man_Walk", "Man_Run"]:
			if str(clip).ends_with(suffix):
				source[suffix] = player.get_animation(clip)
	var reference: Animation = source["Man_Idle"]
	var prefix := str(reference.track_get_path(0)).get_slice(":", 0)
	body_path = NodePath(prefix + ":Body")
	var library := AnimationLibrary.new()
	var names := ["mx_repos_souffle", "mx_repos", "mx_marche", "mx_trot", "mx_course", "mx_sprint"]
	for entry: Dictionary in Animations.GESTES.values():
		names.append(entry.clip)
	for name: String in names:
		var base: Animation = source["Man_Idle"] if name.contains("repos") or not name in ["mx_marche", "mx_trot", "mx_course", "mx_sprint"] else (source["Man_Walk"] if name == "mx_marche" else source["Man_Run"])
		var copy: Animation = base.duplicate(true)
		copy.length = maxf(copy.length, 3.0 if not name.begins_with("mx_repos") and not name in ["mx_marche", "mx_trot", "mx_course", "mx_sprint"] else copy.length)
		if name == "mx_lancer_touche":
			var track := copy.find_track(body_path, Animation.TYPE_POSITION_3D)
			if track < 0:
				track = copy.add_track(Animation.TYPE_POSITION_3D)
				copy.track_set_path(track, body_path)
			while copy.track_get_key_count(track) > 0:
				copy.track_remove_key(track, 0)
			var rig := scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var rest := rig.get_bone_rest(rig.find_bone("Body")).origin
			# Élan exprimé dans l'espace du parent du bassin : on prend son axe « avant » et sa verticale.
			for step in 31:
				var t := copy.length * step / 30.0
				copy.position_track_insert_key(track, t, rest + Vector3(0.0, 0.0, 3.0 * t / copy.length) + Vector3(0.0, 0.1 * sin(PI * t / copy.length), 0.0))
		library.add_animation(name, copy)
	scene.free()
	return ResourceSaver.save(library, path) == OK


func make_view():
	var view = View.new()
	root.add_child(view)
	view.set_process(false)
	view.set_gestes(true)
	view.set_live_cadence(1)
	return view


func players(places: Dictionary, featured: String, possession: int) -> Array:
	var list: Array = []
	for side in 2:
		for slot in 15:
			var id := "%d-%d" % [side, slot]
			var spot: Vector2 = places.get(id, Vector2(40.0 + side * 25.0 + slot % 3 * 3.0, 4.0 + slot * 4.3))
			list.append({"id": id, "side": side, "slot": slot, "featured": id == featured and side == possession, "x": spot.x, "y": spot.y})
	return list


func scene(kind: String, key: String, places: Dictionary, featured: String, ball: Vector2, origin: Vector2, possession: int = 0) -> Dictionary:
	return {"kind": kind, "key": key, "possession": possession, "team": possession, "players": players(places, featured, possession),
		"ball": {"x": ball.x, "y": ball.y}, "origin": {"x": origin.x, "y": origin.y}}


func frame(value: Dictionary, events: Array = []) -> Dictionary:
	return {"scene": value, "teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}], "events": events, "paused": false}


## Rejoue la séquence du moteur (touche, ballon porté, essai, renvoi) et relève les gestes adaptés vus.
func play_sequence(view) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../../tests/fixtures/match-gestes-sequence.json")))
	var frames: Array = parsed.frames
	var gestes: RefCounted = view._gestes
	var out := {"seen": {}, "thrower_clip": false, "caught": false, "opp_pack": 0, "scorer": "", "scorer_clips": [], "mates": 0, "sad": 0}
	for index in frames.size() - 1:
		var events: Array = []
		for earlier in index + 1:
			events.append_array(frames[earlier].events)
		view.apply_frame({"scene": frames[index].scene, "teams": frames[index].teams, "events": events, "paused": false})
		var clock := 0.0
		while (clock < 0.32 or view.is_presenting_extended_pass()) and clock < 30.0:
			view._process(STEP)
			clock += STEP
			out.seen[str(gestes.phase)] = true
			if gestes.phase == "touche" and not gestes.thrower.is_empty() and view.geste_adapte(gestes.thrower, "lancer"):
				out.thrower_clip = true
			if gestes.phase == "touche" and not gestes.awaiting and absf(gestes.time - (Gestes.CATCH + 0.1)) < STEP * 0.6:
				var rig: Skeleton3D = view._actors[gestes.jumper].rig
				var worst := 0.0
				for hand in ["Palm.L", "Palm.R"]:
					worst = maxf(worst, rig.to_global(rig.get_bone_global_pose(rig.find_bone(hand)).origin).distance_to(view._ball.global_position))
				out.caught = worst < 0.3
			if gestes.phase == "maul":
				var n := 0
				for id: String in gestes.cast:
					if gestes.cast[id].role == "opp_pack": n += 1
				out.opp_pack = maxi(out.opp_pack, n)
			if gestes.phase == "essai_maul":
				out.scorer = gestes.carrier
				var current: Dictionary = view._actors[gestes.carrier].geste
				if not current.is_empty() and not out.scorer_clips.has(current.nom): out.scorer_clips.append(current.nom)
				var mates := 0
				var sad := 0
				for id: String in view._actors:
					var playing: Dictionary = view._actors[id].geste
					if playing.is_empty() or id == gestes.carrier: continue
					if playing.nom in ["joie", "joie_poing"] and int(view._actors[id].side) == gestes.side: mates += 1
					if playing.nom == "deception" and int(view._actors[id].side) != gestes.side: sad += 1
				out.mates = maxi(out.mates, mates)
				out.sad = maxi(out.sad, sad)
	# Le relevé enchaîne sur la joie après la fin du geste : on laisse filer.
	for i in 120:
		view._process(STEP)
		if not out.scorer.is_empty():
			var current: Dictionary = view._actors[out.scorer].geste
			if not current.is_empty() and not out.scorer_clips.has(current.nom): out.scorer_clips.append(current.nom)
	return out


func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var original := OS.get_environment("CD_MATCH_ANIMATIONS")

	# 1. Sans bibliothèque : rien d'adapté, la séquence garde ses poses procédurales.
	OS.set_environment("CD_MATCH_ANIMATIONS", "")
	var plain = make_view()
	await process_frame
	plain.apply_frame(frame(scene("carry", "[1,\"a\",\"carry\"]", {}, "0-9", Vector2(40, 30), Vector2(35, 30))))
	plain._process(0.5)
	check(not plain.jouer_geste("0-9", "plaque_cote"), "Sans bibliothèque : aucun geste adapté")
	var bare: Dictionary = await play_sequence(plain)
	check(not bare.thrower_clip and bare.caught, "Sans bibliothèque : lancer procédural, ballon pris au sommet")
	check(bare.scorer_clips.is_empty() and bare.mates == 0 and bare.sad == 0, "Sans bibliothèque : bras levés procéduraux, aucun clip")
	check(bare.opp_pack >= 4, "Ballon porté : la défense engage ses avants (%d liés)" % bare.opp_pack)
	plain.queue_free()
	await process_frame

	# 2. Bibliothèque complète.
	var folder := OS.get_user_data_dir().path_join("essai-gestes-adaptes-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("gestes.res")
	check(write_library(path), "Écriture de la bibliothèque d'essai")
	OS.set_environment("CD_MATCH_ANIMATIONS", path)
	var view = make_view()
	await process_frame
	check(view._animations_adaptees != null, "Bibliothèque chargée")
	if view._animations_adaptees != null:
		view.apply_frame(frame(scene("carry", "[1,\"a\",\"carry\"]", {}, "0-9", Vector2(40, 30), Vector2(35, 30))))
		view._process(0.5)
		# 3. Élan retiré au chargement, verticale gardée.
		var player: AnimationPlayer = view._actors["0-0"].animation
		var throw: Animation = player.get_animation("mx/mx_lancer_touche")
		var rig: Skeleton3D = view._actors["0-0"].rig
		var body_track := -1
		for track in throw.get_track_count():
			if throw.track_get_type(track) == Animation.TYPE_POSITION_3D and str(throw.track_get_path(track).get_subname(0)) == "Body":
				body_track = track
		check(body_track >= 0, "Le lancer d'essai a une piste de position du bassin")
		if body_track >= 0:
			var start: Vector3 = throw.position_track_interpolate(body_track, 0.0)
			var finish: Vector3 = throw.position_track_interpolate(body_track, throw.length)
			var middle: Vector3 = throw.position_track_interpolate(body_track, throw.length * 0.5)
			var up := (rig.get_bone_global_rest(rig.get_bone_parent(rig.find_bone("Body"))).basis.inverse() * Vector3.UP).normalized()
			var drift := (finish - start) - up * (finish - start).dot(up)
			check(drift.length() < 0.01, "Élan du clip retiré : %.3f" % drift.length())
			check(absf((middle - start).length()) > 0.02, "La verticale du clip est gardée : %.3f" % (middle - start).length())
		# Geste au sol : le joueur garde sa place pendant la chute, puis se relève.
		var before: Vector3 = view._actors["0-9"].node.position
		check(view.jouer_geste("0-9", "plaque_cote", 1.0, -1.0, true, [["se_relever", 0.0, 1.9]]), "Plaqué : geste lancé")
		view.apply_frame(frame(scene("carry", "[2,\"b\",\"carry\"]", {"0-9": Vector2(55, 30)}, "0-10", Vector2(55, 40), Vector2(45, 40))))
		var chain := []
		for i in 45:
			view._process(STEP)
			var playing: Dictionary = view._actors["0-9"].geste
			if not playing.is_empty() and not chain.has(playing.nom): chain.append(playing.nom)
		check((view._actors["0-9"].node.position as Vector3).distance_to(before) < 0.05, "Au sol, le joueur garde sa place")
		check(str(view._actors["0-9"].animation.current_animation) == "mx/mx_plaque_cote" or chain.has("se_relever"), "Le clip de chute est joué")
		for i in 90:
			view._process(STEP)
			var playing: Dictionary = view._actors["0-9"].geste
			if not playing.is_empty() and not chain.has(playing.nom): chain.append(playing.nom)
		check(chain == ["plaque_cote", "se_relever"], "Chute puis relevé : %s" % [chain])
		for i in 60:
			view._process(STEP)
		check(view._actors["0-9"].geste.is_empty() and (view._actors["0-9"].node.position as Vector3).distance_to(view._world({"x": 55, "y": 30})) < 0.3, "Relevé, il rejoint sa place de la scène")
		# Pénalité frappée et réception d'un jeu au pied.
		view.apply_frame(frame(scene("goal", "[3,\"c\",\"goal\"]", {"0-14": Vector2(70, 30)}, "0-14", Vector2(100, 35), Vector2(70, 30))))
		view._process(STEP)
		view._process(STEP)
		check(view.geste_adapte("0-14", "coup_de_pied"), "Pénalité : le buteur frappe (clip adapté)")
		view.apply_frame(frame(scene("kick", "[4,\"d\",\"kick\"]", {"1-14": Vector2(20, 30)}, "1-14", Vector2(60, 30), Vector2(20, 30), 1)))
		view._process(STEP)
		view.apply_frame(frame(scene("reception", "[4,\"e\",\"reception\"]", {"0-13": Vector2(60, 30)}, "0-13", Vector2(60, 30), Vector2(20, 30))))
		view._process(STEP)
		view._process(STEP)
		check(view.geste_adapte("0-13", "reception_haute"), "Ballon haut : réception bras tendus (clip adapté)")
		view.apply_frame(frame(scene("goal", "[5,\"f\",\"goal\"]", {"0-14": Vector2(70, 30)}, "0-14", Vector2(100, 35), Vector2(70, 30)), []).merged({"paused": true}, true))
		check(not view.jouer_geste("0-14", "coup_de_pied"), "En pause : aucun geste adapté")
		view.queue_free()
		await process_frame
		# Séquence du moteur avec la bibliothèque.
		var adapted = make_view()
		await process_frame
		var seen: Dictionary = await play_sequence(adapted)
		check(seen.thrower_clip, "Touche : le lanceur joue le lancer adapté")
		check(seen.caught, "Touche : le ballon lancé arrive dans les mains du sauteur")
		check(seen.opp_pack >= 4, "Ballon porté : la défense se lie (%d)" % seen.opp_pack)
		check(seen.seen.has("essai_maul"), "L'essai sort du ballon porté")
		check(seen.scorer_clips.has("se_relever") and seen.scorer_clips.has("joie_poing"), "Le marqueur se relève puis lève le poing : %s" % [seen.scorer_clips])
		check(seen.mates >= 2, "Les partenaires exultent : %d" % seen.mates)
		check(seen.sad >= 2, "Les adversaires les plus proches baissent la tête : %d" % seen.sad)
		adapted.queue_free()
		await process_frame
	OS.set_environment("CD_MATCH_ANIMATIONS", original)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)
	print("MATCH_GESTES_ADAPTES_CHECKS %d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
