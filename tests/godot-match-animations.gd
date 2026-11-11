extends SceneTree
## Animations de déplacement adaptées (match_animations.gd), vérifiées en --headless.
## 1. Sans CD_MATCH_ANIMATIONS : rien n'est chargé, les joueurs gardent leurs clips d'origine.
## 2. Fichier introuvable : même résultat, avec un simple avertissement.
## 3. Avec une bibliothèque : chaque joueur la reçoit, le repos et les quatre paliers
##    (marche, trot, course, sprint) suivent la vitesse, les pistes animent bien le squelette.
## La bibliothèque d'essai est fabriquée ici à partir des clips d'origine du joueur :
## aucun fichier tiers n'est nécessaire ni présent dans le dépôt.

const View = preload("res://match_view.gd")
const Animations = preload("res://match_animations.gd")
const ATHLETE := "res://assets/match3d/quaternius-rugby-athlete.glb"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func fixture(offsets: Dictionary = {}) -> Dictionary:
	var players: Array[Dictionary] = []
	for side in 2:
		for slot in 15:
			var id := "%d-%d" % [side, slot]
			players.append({"id": id, "side": side, "slot": slot, "featured": false,
				"x": 20.0 + side * 40.0 + float(offsets.get(id, 0.0)), "y": 5.0 + slot * 4.0})
	return {"paused": false, "scene": {"kind": "carry", "possession": 0, "players": players, "ball": {"x": 51.0, "y": 35.0}},
		"teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}]}


func build() -> Array:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var view: NativeMatchView = View.new()
	viewport.add_child(view)
	view.set_process(false)
	view.apply_frame(fixture())
	view._process(1.0)
	return [viewport, view]


func release(pair: Array) -> void:
	root.remove_child(pair[0])
	pair[0].free()


func find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child: Node in node.get_children():
		var found := find_player(child)
		if found:
			return found
	return null


## Bibliothèque d'essai : le joueur d'origine, ses clips recopiés sous les noms attendus.
func write_library(path: String, names: Array) -> bool:
	var scene := (load(ATHLETE) as PackedScene).instantiate()
	var player := find_player(scene)
	var library := player.get_animation_library(player.get_animation_library_list()[0])
	var source := {}
	for clip: StringName in player.get_animation_list():
		for suffix in ["Man_Idle", "Man_Walk", "Man_Run"]:
			if str(clip).ends_with(suffix):
				source[suffix] = player.get_animation(clip)
	for name: String in names:
		var base: Animation = source["Man_Idle"] if name.contains("repos") else (source["Man_Walk"] if name == "mx_marche" else source["Man_Run"])
		library.add_animation(name, base.duplicate(true))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var ok := document.append_from_scene(scene, state) == OK and document.write_to_filesystem(state, path) == OK
	scene.free()
	return ok


func clips_seen(view: NativeMatchView, offsets: Dictionary, frames: int) -> Dictionary:
	var seen := {}
	view.apply_frame(fixture(offsets))
	for step in frames:
		view._process(1.0 / 30.0)
		for id: String in offsets:
			var animation: AnimationPlayer = view._actors[id].animation
			if not seen.has(id):
				seen[id] = {}
			seen[id][str(animation.current_animation)] = true
	return seen


func run() -> void:
	var original := OS.get_environment("CD_MATCH_ANIMATIONS")
	# 1. Sans variable : clips d'origine.
	OS.set_environment("CD_MATCH_ANIMATIONS", "")
	var pair := build()
	var view: NativeMatchView = pair[1]
	check(view._animations_adaptees == null, "sans variable : rien n'est chargé")
	for id: String in view._actors:
		var entry: Dictionary = view._actors[id]
		check(not entry.adapted and str(entry.idle).ends_with("Man_Idle") and not (entry.animation as AnimationPlayer).has_animation_library(&"mx"),
			"sans variable : joueur %s inchangé" % id)
	release(pair)
	# 2. Fichier introuvable : clips d'origine.
	OS.set_environment("CD_MATCH_ANIMATIONS", OS.get_user_data_dir().path_join("absent-%d.glb" % Time.get_ticks_usec()))
	pair = build()
	view = pair[1]
	check(view._animations_adaptees == null and not view._actors["0-0"].adapted, "fichier introuvable : clips d'origine")
	release(pair)
	# 3. Bibliothèque incomplète (pas de sprint) : refusée en bloc.
	var folder := OS.get_user_data_dir().path_join("essai-animations-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var partial := folder.path_join("incomplete.glb")
	check(write_library(partial, ["mx_repos_souffle", "mx_marche", "mx_trot", "mx_course"]), "écriture de la bibliothèque incomplète")
	OS.set_environment("CD_MATCH_ANIMATIONS", partial)
	pair = build()
	view = pair[1]
	check(view._animations_adaptees == null and not view._actors["0-0"].adapted, "bibliothèque incomplète : clips d'origine")
	release(pair)
	# 4. Bibliothèque complète.
	var full := folder.path_join("complete.glb")
	check(write_library(full, ["mx_repos_souffle", "mx_marche", "mx_trot", "mx_course", "mx_sprint", "mx_joie"]), "écriture de la bibliothèque complète")
	OS.set_environment("CD_MATCH_ANIMATIONS", full)
	pair = build()
	view = pair[1]
	check(view._animations_adaptees != null, "bibliothèque complète : chargée")
	var unresolved := 0
	if view._animations_adaptees != null:
		for id: String in view._actors:
			var entry: Dictionary = view._actors[id]
			var animation: AnimationPlayer = entry.animation
			check(entry.adapted and animation.has_animation_library(&"mx") and entry.idle == &"mx/mx_repos_souffle"
				and animation.current_animation == "mx/mx_repos_souffle", "joueur %s équipé et au repos" % id)
		var first: AnimationPlayer = view._actors["0-0"].animation
		var rig: Skeleton3D = view._actors["0-0"].rig
		for clip: StringName in first.get_animation_library(&"mx").get_animation_list():
			var animation := first.get_animation("mx/" + clip)
			for track in animation.get_track_count():
				var track_path := animation.track_get_path(track)
				if first.get_node(first.root_node).get_node_or_null(NodePath(str(track_path).get_slice(":", 0))) != rig \
						or rig.find_bone(track_path.get_subname(0)) < 0:
					unresolved += 1
		check(unresolved == 0, "toutes les pistes visent le squelette du joueur (%d en défaut)" % unresolved)
		# Déplacements : 0,55 s par image moteur, donc 1 m ≈ 1,8 m/s.
		var seen := clips_seen(view, {"0-0": 0.0, "0-1": 0.8, "0-2": 1.6, "0-3": 2.7, "0-4": 4.4}, 14)
		check(seen["0-0"].keys() == ["mx/mx_repos_souffle"], "joueur immobile : repos seulement (%s)" % [seen["0-0"].keys()])
		check(seen["0-1"].has("mx/mx_marche") and not seen["0-1"].has("mx/mx_course") and not seen["0-1"].has("mx/mx_sprint"), "joueur lent : marche (%s)" % [seen["0-1"].keys()])
		check(seen["0-2"].has("mx/mx_trot") and not seen["0-2"].has("mx/mx_sprint"), "joueur moyen : trot (%s)" % [seen["0-2"].keys()])
		check(seen["0-3"].has("mx/mx_course"), "joueur rapide : course (%s)" % [seen["0-3"].keys()])
		check(seen["0-4"].has("mx/mx_sprint"), "joueur très rapide : sprint (%s)" % [seen["0-4"].keys()])
		var thigh := rig.find_bone("UpperLeg.L")
		var moving_rig: Skeleton3D = view._actors["0-4"].rig
		check(not moving_rig.get_bone_pose_rotation(thigh).is_equal_approx(moving_rig.get_bone_rest(thigh).basis.get_rotation_quaternion()), "le squelette du sprinteur est animé")
		# Après l'arrêt, retour au repos.
		for step in 40:
			view._process(1.0 / 30.0)
		check((view._actors["0-4"].animation as AnimationPlayer).current_animation == "mx/mx_repos_souffle", "retour au repos après l'arrêt")
	release(pair)
	# 5. Paliers et hystérésis (calcul pur).
	var tool := Animations.new()
	check(tool.palier(0.5, -1) == 0 and tool.palier(3.0, -1) == 1 and tool.palier(5.0, -1) == 2 and tool.palier(8.0, -1) == 3, "paliers par vitesse")
	check(tool.palier(2.1, 1) == 1 and tool.palier(1.7, 1) == 0, "hystérésis trot → marche")
	check(tool.palier(5.7, 3) == 3 and tool.palier(5.4, 3) == 2, "hystérésis sprint → course")
	check(tool.palier(9.0, 0) == 3 and tool.palier(0.2, 3) == 0, "saut de plusieurs paliers")
	OS.set_environment("CD_MATCH_ANIMATIONS", original)
	for file in ["incomplete.glb", "complete.glb"]:
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	print("MATCH_ANIMATIONS_CHECKS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
