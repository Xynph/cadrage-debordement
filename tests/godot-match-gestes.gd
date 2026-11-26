extends SceneTree
## Gestes de rugby : touche portée, ballon porté, essai aplati, sur la séquence
## extraite du moteur (tests/fixtures/match-gestes-sequence.json).

const View = preload("res://match_view.gd")
const Presentation = preload("res://match_presentation.gd")
const Gestes = preload("res://match_gestes.gd")
const Regie = preload("res://ui/contextual/match_temps_forts.gd")
const STEP := 1.0 / 30.0
const TV_OFFSET := View.TV_OFFSET  # caméra TV de la vue (plus haute depuis le 12 novembre 2026)
const ACTION_OFFSET := View.ACTION_OFFSET
const TICK := 0.32
## Allure de pointe crédible d'un ballon porté qui avance, en m/s (valeur choisie : un ballon porté
## d'élite avance à 1,5 à 2,5 m/s ; le paquet ne sprinte pas).
const MAUL_PEAK_MAX := 2.8
## Bustes et têtes (capsules de la sonde des contacts du match filmé) : pénétration franche au-delà de
## BUST_OVERLAP_MAX m ; au ballon porté, au plus BUSTS_MERGED_MAX couples-images franches sur tout le
## geste (arrivées en course d'une ou deux images ; avant le 25/11/2026 : 1 239, bloc de saut et
## adversaires face à face, bustes confondus pendant toute la poussée).
const BUSTES := [["Hips", "Abdomen", 0.13], ["Abdomen", "Torso", 0.14], ["Torso", "Neck", 0.14], ["Head", 0.22, 0.1]]
const BUST_OVERLAP_MAX := 0.08
const BUSTS_MERGED_MAX := 20

var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func live(frames: Array, index: int, paused: bool = false) -> Dictionary:
	var events: Array = []
	for earlier in index + 1:
		events.append_array(frames[earlier].events)
	return {"scene": frames[index].scene, "teams": frames[index].teams, "events": events, "paused": paused}

func featured(scene: Dictionary) -> String:
	for player: Dictionary in scene.players:
		if player.featured:
			return player.id
	return ""

func lift(view, id: String, bases: Dictionary) -> float:
	return (view._actors[id].model as Node3D).position.y - float(bases[id])

func hands(view, id: String) -> float:
	var rig: Skeleton3D = view._actors[id].rig
	var worst := 0.0
	for hand in ["Palm.L", "Palm.R"]:
		worst = maxf(worst, rig.to_global(rig.get_bone_global_pose(rig.find_bone(hand)).origin).distance_to(view._ball.global_position))
	return worst

static func _busts(rig: Skeleton3D) -> Array:
	var g := rig.global_transform
	var out: Array = []
	for v: Array in BUSTES:
		var a := g * rig.get_bone_global_pose(rig.find_bone(v[0]))
		var b: Vector3 = (g * rig.get_bone_global_pose(rig.find_bone(v[1]))).origin if v[1] is String else a.origin + a.basis.y.normalized() * float(v[1])
		out.append([a.origin, b, float(v[2])])
	return out

## Plus forte pénétration (m) entre les bustes et têtes de deux joueurs.
func busts_overlap(view, a: String, b: String) -> float:
	if (view._actors[a].node as Node3D).global_position.distance_to((view._actors[b].node as Node3D).global_position) > 2.6:
		return 0.0
	var worst := -INF
	for s1: Array in _busts(view._actors[a].rig):
		for s2: Array in _busts(view._actors[b].rig):
			var r := Geometry3D.get_closest_points_between_segments(s1[0], s1[1], s2[0], s2[1])
			worst = maxf(worst, float(s1[2]) + float(s2[2]) - (r[0] as Vector3).distance_to(r[1]))
	return worst

## La caméra suivie applique exactement la formule d'origine : point suivi + décalage fixe, taille fixe.
func camera_plain(view, offset: Vector3, size: float) -> bool:
	var camera: Camera3D = view._camera
	# Caméra-grue : direction relevée près de la touche proche (offset_suivi).
	offset = view.offset_suivi(offset, view._camera_focus.z)
	# Caméras en perspective (18 novembre 2026) : position déduite du point visé final, de la hauteur visible et de la direction.
	return camera.position.is_equal_approx(view.pose_camera(view._camera_look, size, offset)[0]) and is_equal_approx(camera.size, size) and camera.global_basis.is_equal_approx(Basis.looking_at(-offset, Vector3.UP))

func make_view(gestes: bool):
	var view = View.new()
	root.add_child(view)
	view.set_process(false)
	view.set_gestes(gestes)
	view.set_live_cadence(1)
	return view

## Essai de pénalité (26/11/2026) : accordé entre les poteaux, la même image pour une faute loin ou près de la ligne :
## ballon sous les poteaux, équipe qui marque autour d'eux, plan centré sur les poteaux et l'arbitre.
func essai_penalite() -> void:
	var lecture: Script = load("res://ui/contextual/match_temps_forts_lecture.gd")
	var attaques: Array = []
	for faute: float in [72.0, 97.0]:
		var joueurs: Array = []
		for side in 2:
			for slot in 15:
				joueurs.append({"id": "%d-%d" % [side, slot], "side": side, "slot": slot, "x": faute - 6.0 + slot, "y": 10.0 + slot * 3.0})
		var s: Dictionary = lecture.scene_essai_penalite({"kind": "message", "team": 0, "possession": 1, "ball": {"x": faute, "y": 20.0}, "players": joueurs})
		check(absf(float(s.ball.x) - 100.0) < 1.0 and absf(float(s.ball.y) - 35.0) < 0.5, "Essai de pénalité : ballon sous les poteaux (faute à %d m de la ligne)" % int(100.0 - faute))
		var points: Array = lecture.points_essai_penalite(50.0, 1.0)
		points.append(Vector3(46.5, 0.0, -1.5)) # arbitre sous les poteaux, bras levé
		points.append(Vector3(float(s.ball.x) - 50.0, 0.0, float(s.ball.y) - 35.0))
		var centre := Vector3.ZERO
		for p: Vector3 in points: centre += Vector3(p.x, 0.0, p.z)
		centre /= float(points.size())
		check(absf(centre.x - 50.0) < 8.0 and absf(centre.z) < 2.0, "Essai de pénalité : plan centré sur les poteaux et l'arbitre " + str(centre))
		var attaque: Array = []
		for p: Dictionary in s.players:
			if int(p.side) == 0: attaque.append([float(p.x), float(p.y)])
		check(attaque.size() == 15 and attaque.all(func(a: Array) -> bool: return a[0] >= 78.0 and a[0] < 100.0 and absf(a[1] - 35.0) <= 14.0), "Essai de pénalité : l'équipe qui marque autour des poteaux")
		attaques.append(attaque)
	check(attaques.size() == 2 and attaques[0] == attaques[1], "Essai de pénalité : même image pour une faute loin ou près")

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../../tests/fixtures/match-gestes-sequence.json")))
	check(parsed is Dictionary and parsed.get("frames") is Array, "Séquence du moteur lisible")
	essai_penalite()
	if not failures.is_empty():
		quit(1)
		return
	var frames: Array = parsed.frames
	var before := frames.duplicate(true)
	var kinds: Array = frames.map(func(frame: Dictionary) -> String: return frame.scene.kind)
	var at_lineout := kinds.find("lineout")
	var at_try := kinds.find("try")
	check(at_lineout >= 0 and at_try == at_lineout + 2 and kinds[at_lineout + 1] == "setpiece-win", "La séquence contient alignement, touche conservée puis essai")
	check(at_try + 1 < frames.size(), "Une scène suit l'essai")

	# Sans le drapeau : aucun geste complet ; seule la touche reste jouée (18/11/2026 : lancer du
	# talonneur et saut porté, la mise en scène de match_gestes.gd réduite à la touche). Le direct
	# n'attend que cette touche, la caméra garde sa formule d'origine.
	var plain = make_view(false)
	await process_frame
	check(plain._gestes == null, "Sans CD_MATCH_GESTES la vue n'a pas de gestes complets")
	var directe: RefCounted = plain._touche_directe
	check(directe != null and directe.touche_seule and plain.mise_en_scene() == directe, "Sans gestes complets, la touche du direct est mise en scène")
	var plain_camera := true
	var plain_bases := {}
	var direct_thrower_overhead := false
	var direct_thrower := ""
	var direct_jumper := ""
	var direct_peak := 0.0
	var direct_ball_top := 0.0
	var direct_caught := false
	var direct_jump_clip := false
	var direct_waited := 0.0
	for index in frames.size():
		plain.apply_frame(live(frames, index))
		if index == 0:
			plain._process(1.0)
			for id: String in plain._actors:
				plain_bases[id] = (plain._actors[id].model as Node3D).position.y
		var steps := 0
		while steps < 12 or (plain.is_presenting_extended_pass() and steps < 400):
			plain._process(STEP)
			steps += 1
			plain_camera = plain_camera and camera_plain(plain, TV_OFFSET, View.TV_TAILLE)
			if plain.is_presenting_extended_pass():
				direct_waited += STEP
			if directe.phase != "touche":
				continue
			if directe.awaiting and directe.done and plain._actors.has(directe.thrower):
				direct_thrower = directe.thrower
				direct_thrower_overhead = direct_thrower_overhead or (hands(plain, directe.thrower) < 0.3 and plain._ball.global_position.y > 1.9)
			if not directe.awaiting and not str(directe.jumper).is_empty() and plain_bases.has(directe.jumper):
				direct_jumper = directe.jumper
				direct_peak = maxf(direct_peak, lift(plain, directe.jumper, plain_bases))
				direct_ball_top = maxf(direct_ball_top, plain._ball.global_position.y)
				var clip: String = str((plain._actors[directe.jumper].animation as AnimationPlayer).current_animation)
				direct_jump_clip = direct_jump_clip or clip.ends_with("Man_Jump") or plain.geste_adapte(directe.jumper)
				if absf(directe.time - (Gestes.CATCH + 0.1)) < STEP * 0.6:
					direct_caught = hands(plain, directe.jumper) < 0.3 and plain._ball.global_position.y > 2.8
		if kinds[index] not in ["lineout", "setpiece-win"]:
			check(not plain.is_presenting_extended_pass(), "Sans gestes complets le match n'attend que la touche : " + str(kinds[index]))
			check(not directe.active(), "Hors touche, rien n'est mis en scène sans gestes complets : " + str(kinds[index]))
	check(plain_camera, "Sans gestes la caméra TV garde sa formule d'origine à chaque image")
	var thrower_slot := -1
	for player: Dictionary in frames[at_lineout].scene.players:
		if str(player.id) == direct_thrower:
			thrower_slot = int(player.slot)
	check(thrower_slot == 1, "Direct : le talonneur (n° 2) lance : " + direct_thrower)
	check(direct_thrower_overhead, "Direct : le talonneur tient le ballon au-dessus de la tête avant le lancer")
	check(not direct_jumper.is_empty() and direct_jumper != direct_thrower, "Direct : un sauteur saute pour capter")
	check(direct_peak > 0.95, "Direct : le sauteur est porté à plus de 95 cm : " + str(direct_peak))
	check(direct_jump_clip, "Direct : le sauteur joue le saut du modèle (ou le geste adapté)")
	check(direct_ball_top > 2.8, "Direct : le ballon lancé monte au sauteur : " + str(direct_ball_top))
	check(direct_caught, "Direct : prise à deux mains au sommet")
	check(direct_waited < 12.0, "Direct : la touche ne retient pas le match plus de 12 s : " + str(direct_waited))
	print("MATCH_GESTES_DIRECT ", JSON.stringify({"lanceur": direct_thrower, "sauteur": direct_jumper, "levee_m": snappedf(direct_peak, 0.01), "ballon_haut_m": snappedf(direct_ball_top, 0.01), "attente_s": snappedf(direct_waited, 0.01)}))
	for frame in 30:
		plain._process(STEP)
	for id: String in plain._actors:
		check(is_zero_approx((plain._actors[id].model as Node3D).rotation.x), "Sans gestes aucun corps ne reste incliné")
	plain.queue_free()

	var view = make_view(true)
	await process_frame
	var gestes: RefCounted = view._gestes
	check(gestes != null and not gestes.active(), "Les gestes s'activent explicitement et restent au repos")
	view.apply_frame(live(frames, 0))
	view._process(1.0)
	var bases := {}
	for id: String in view._actors:
		bases[id] = (view._actors[id].model as Node3D).position.y
	var index := 0
	var since := 0.0
	var clock := 0.0
	var peak := 0.0
	var rival_peak := 0.0
	var caught := false
	var waited := 0.0
	var maul_checked := false
	var try_checked := false
	var aligned := false
	var winner_jumper := ""
	var maul_carrier := ""
	var maul_opponents := 0
	var maul_spread := 0.0
	var maul_pitch := 0.0
	var maul_ball := 99.0
	var maul_arrival := 99.0
	var grounded := Vector3.INF
	var scorer_pitch := 0.0
	var scorer_hands := 99.0
	var cheering := 0
	# Ballon porté jusqu'à l'essai (lot 8, 16/11/2026) : allure du regroupement, attente de la régie
	# par plan (échéance ECHEANCE_GESTE), instant où le ballon est aplati dans l'en-but, légende.
	var drive_peak := {"maul": 0.0, "essai_maul": 0.0}
	var drive_path := {"maul": 0.0, "essai_maul": 0.0}
	var last_center := Vector3.INF
	var last_drive_phase := ""
	var hold_by_kind := {}
	var try_grounded_at := -1.0
	var maul_drive := 0.0
	var maul_busts_merged := 0
	var maul_busts_worst := 0.0
	var maul_try_follows_seen := false
	var maul_lead := 0.0
	var aplati_too_early := false
	var aplati_at_ground := false
	# Caméra TV par défaut : recadrage pendant le geste, retour ensuite.
	var camera: Camera3D = view._camera
	check(camera_plain(view, TV_OFFSET, View.TV_TAILLE), "Avant le geste la caméra TV est celle d'origine")
	var zoom_before_geste := false
	var zoom_started_at := -1.0
	var geste_started_at := -1.0
	var smallest := View.TV_TAILLE
	var smallest_in := {"touche": View.TV_TAILLE, "maul": View.TV_TAILLE, "essai_maul": View.TV_TAILLE}
	var size_step := 0.0
	var yaw_step := 0.0
	var aim_step := 0.0
	var last_size := camera.size
	var last_basis := camera.global_basis
	var last_motion := Vector3.ZERO
	var last_base_motion := Vector3.ZERO
	var last_aim := Vector3(view._camera_focus.x, 0.0, view._camera_focus.z)
	var last_base := last_aim
	var last_zoom := 0.0
	var cuts: Array = []
	var ball_outside := 0
	var ball_frames := 0
	# Allure de chaque joueur à l'écran, image par image, pendant les gestes (mise en place comprise).
	var last_spots := {}
	var visible_peak := {}
	var hidden_jumps := 0
	var pace_by_phase := {}
	var screen := Rect2(Vector2.ZERO, Vector2(view.get_viewport().get_visible_rect().size))
	# Coupes de réalisation : l'image d'après n'est pas un mouvement (ni des joueurs, ni de la caméra).
	var last_cuts := 0
	var cut_frames: Array = []
	var after_cut := 0
	while index < frames.size() - 1 or gestes.active() or gestes.zoom > 0.0:
		since += STEP
		if index < frames.size() - 1 and since >= TICK and not view.is_presenting_extended_pass():
			index += 1
			since = 0.0
			view.apply_frame(live(frames, index))
		view._process(STEP)
		clock += STEP
		if clock > 60.0:
			break
		if gestes.cuts != last_cuts:
			last_cuts = gestes.cuts
			cut_frames.append([snappedf(clock, 0.01), kinds[index]])
			after_cut = 2
			last_spots.clear()
		else:
			after_cut = maxi(0, after_cut - 1)
		if gestes.active() and gestes.phase != "approche" and geste_started_at < 0.0:
			geste_started_at = clock
		if gestes.active():
			for id: String in view._actors:
				var spot: Vector3 = view._actors[id].node.position
				if last_spots.has(id):
					var pace: float = Vector2(spot.x - last_spots[id].x, spot.z - last_spots[id].z).length() / STEP
					var seen: bool = screen.has_point(camera.unproject_position(spot)) or screen.has_point(camera.unproject_position(last_spots[id]))
					if seen:
						if pace > float(visible_peak.get(id, 0.0)) and pace > Gestes.PACE_MAX:
							print("MATCH_GESTES_FAST ", id, " ", gestes.phase, " t=", snappedf(gestes.time, 0.01), " ", snappedf(pace, 0.01))
						visible_peak[id] = maxf(float(visible_peak.get(id, 0.0)), pace)
						pace_by_phase[gestes.phase] = snappedf(maxf(float(pace_by_phase.get(gestes.phase, 0.0)), pace), 0.01)
					elif pace > Gestes.PACE_MAX + 0.3:
						hidden_jumps += 1
				last_spots[id] = spot
		else:
			last_spots.clear()
		if gestes.zoom > 0.0 and zoom_started_at < 0.0:
			zoom_started_at = clock
		if gestes.zoom > 0.0 and not gestes.active() and geste_started_at < 0.0:
			zoom_before_geste = true
		smallest = minf(smallest, camera.size)
		if smallest_in.has(gestes.phase):
			smallest_in[gestes.phase] = minf(smallest_in[gestes.phase], camera.size)
		if gestes.zoom > 0.0:
			if after_cut == 0:
				size_step = maxf(size_step, absf(log(camera.size / last_size)))
				yaw_step = maxf(yaw_step, last_basis.z.angle_to(camera.global_basis.z))
		elif last_zoom > 0.0:
			cuts.append([snappedf(clock, 0.01), kinds[index], last_zoom])
		last_zoom = gestes.zoom
		var ahead := -camera.global_basis.z
		var aim := camera.position + ahead * (-camera.position.y / ahead.y)
		# À-coup ajouté par le recadrage : variation de vitesse du point visé, comparée à celle
		# du suivi d'origine du ballon au même instant (ce dernier n'est pas jugé ici).
		var base := Vector3(view._camera_focus.x, 0.0, view._camera_focus.z)
		var motion := Vector3(aim.x, 0.0, aim.z) - last_aim
		var base_motion := base - last_base
		if gestes.zoom > 0.0 and clock > STEP * 2.0 and after_cut == 0:
			aim_step = maxf(aim_step, motion.distance_to(last_motion) - base_motion.distance_to(last_base_motion))
		last_motion = motion
		last_base_motion = base_motion
		last_aim = Vector3(aim.x, 0.0, aim.z)
		last_base = base
		last_size = camera.size
		last_basis = camera.global_basis
		if gestes.active() and gestes.zoom >= 1.0 and view._ball.visible:
			ball_frames += 1
			var seen := camera.unproject_position(view._ball.global_position)
			if not Rect2(Vector2.ZERO, Vector2(view.get_viewport().get_visible_rect().size)).has_point(seen):
				ball_outside += 1
		if view.is_presenting_extended_pass():
			waited += STEP
			hold_by_kind[kinds[index]] = float(hold_by_kind.get(kinds[index], 0.0)) + STEP
		if gestes.phase in ["maul", "essai_maul"]:
			# Liés mais pas fondus (Léo, 25/11/2026) : entre deux joueurs du ballon porté, bras et
			# épaules au contact permis, jamais un buste ou une tête dans un autre.
			var staged: Array = gestes.cast.keys().filter(func(id: String) -> bool: return view._actors.has(id) and str(gestes.cast[id].get("role", "")) != "walk")
			for i in staged.size():
				for j in range(i + 1, staged.size()):
					var fondu := busts_overlap(view, staged[i], staged[j])
					if fondu > BUST_OVERLAP_MAX:
						maul_busts_merged += 1
						maul_busts_worst = maxf(maul_busts_worst, fondu)
			var center: Vector3 = gestes._frame().center
			if last_drive_phase == gestes.phase and last_center.is_finite():
				var moved: float = Vector2(center.x - last_center.x, center.z - last_center.z).length()
				drive_path[gestes.phase] += moved
				drive_peak[gestes.phase] = maxf(drive_peak[gestes.phase], moved / STEP)
			last_center = center
			last_drive_phase = gestes.phase
		else:
			last_drive_phase = ""
		if gestes.phase == "essai_maul":
			var ball_now: Vector3 = view._ball.global_position
			# Aplati : ballon au sol dans l'en-but, à son point d'aplatissement (point d'essai du moteur
			# reporté de Gestes.IN_GOAL m dans l'en-but).
			var line_now := float(frames[at_try].scene.ball.x) - 50.0
			var spot_now := Vector3(line_now + signf(line_now) * Gestes.IN_GOAL, 0.0, float(frames[at_try].scene.ball.y) - 35.0)
			var in_goal: bool = absf(ball_now.x) > 50.0 and ball_now.y < 0.2 and Vector3(ball_now.x, 0.0, ball_now.z).distance_to(spot_now) < 0.01
			if in_goal and try_grounded_at < 0.0:
				try_grounded_at = gestes.time
				aplati_at_ground = view.has_method("essai_aplati") and view.essai_aplati()
			if not in_goal and view.has_method("essai_aplati") and view.essai_aplati():
				aplati_too_early = true
		var kind: String = kinds[index]
		if kind == "lineout" and gestes.phase == "touche" and gestes.awaiting and gestes.done and not aligned:
			aligned = true
			var thrower: Node3D = view._actors[gestes.thrower].node
			check(thrower.position.z <= -34.99 and absf(thrower.position.x - (float(frames[index].scene.origin.x) - 50.0)) < 0.01, "Le lanceur est sur la ligne de touche, sur la ligne de remise en jeu")
			check(hands(view, gestes.thrower) < 0.3 and view._ball.global_position.y > 1.9, "Le lanceur tient le ballon au-dessus de la tête")
			check(not view.is_presenting_extended_pass(), "Alignement prêt : le match reprend la main")
			var lines: Array[float] = [0.0, 0.0]
			for id: String in gestes.cast:
				if gestes.cast[id].role in ["jumper", "lift_front", "lift_back"]:
					lines[gestes.cast[id].team] += view._actors[id].node.position.x / 3.0
			check(absf(absf(lines[0] - lines[1]) - 1.0) < 0.01 and lines[0] < lines[1], "Deux lignes séparées par le couloir d'un mètre de la loi 18, chacune de son côté")
			# Chacun est à une place que la scène du moteur donne à son équipe (loi 18) ; les
			# rôles sans équivalent moteur (sauteur, porteurs) prennent des places de la rangée.
			var placed := 0
			var taken := {}
			for id: String in gestes.cast:
				var at: Vector3 = view._actors[id].node.position
				for player: Dictionary in frames[index].scene.players:
					var place := Vector3(float(player.x) - 50.0, 0.0, float(player.y) - 35.0)
					var key := str(player.side) + "/" + str(player.slot)
					if int(player.side) == int(gestes.cast[id].team) and Vector2(at.x - place.x, at.z - place.z).length() < 0.01 and not taken.has(key):
						taken[key] = id
						placed += 1
						break
			check(placed == gestes.cast.size() and placed == frames[index].scene.players.size(), "Chaque joueur est à une place de la scène de touche : %d / %d" % [placed, gestes.cast.size()])
			var pace := 0.0
			var farthest := 0.0
			var over := 0
			for id: String in gestes.cast:
				var member: Dictionary = gestes.cast[id]
				var run := Vector2(member.mark.x - member.from.x, member.mark.z - member.from.z).length()
				farthest = maxf(farthest, run + float(member.get("shortened", 0.0)))
				# Profil de course à allure tenue : pointe à 1,25 fois l'allure moyenne.
				var peak_pace: float = Gestes.PEAK * run / float(member.form)
				pace = maxf(pace, peak_pace)
				if peak_pace > float(member.peak) + 0.01:
					over += 1
			# Ici la sortie en touche laisse des avants à plus de CUT_BEYOND : coupe sur l'alignement formé,
			# puis une seconde de derniers pas (SETTLE_STEP au plus), lanceur ballon en main.
			check(gestes.cuts == 1 and is_equal_approx(gestes.form_seconds, Gestes.SETTLE) and pace <= Gestes.PEAK * Gestes.SETTLE_STEP / Gestes.SETTLE + 0.01, "Coupe sur l'alignement formé, derniers pas seulement : %d coupe, %.2f s, pointe %.2f m/s" % [gestes.cuts, gestes.form_seconds, pace])
			print("MATCH_GESTES_FORM ", JSON.stringify({"cut": gestes.cuts == 1, "seconds_after_cut": gestes.form_seconds, "planned_peak_m_s": pace, "staged": gestes.cast.size()}))
		if gestes.phase == "touche" and not gestes.awaiting:
			winner_jumper = gestes.jumper
			peak = maxf(peak, lift(view, gestes.jumper, bases))
			var rival: String = gestes.jumpers[1 - gestes.side]
			if not rival.is_empty():
				rival_peak = maxf(rival_peak, lift(view, rival, bases))
			if absf(gestes.time - (Gestes.CATCH + 0.1)) < STEP * 0.6:
				caught = hands(view, gestes.jumper) < 0.3 and view._ball.global_position.y > 2.8
		if gestes.phase == "maul" and gestes.done and not maul_checked:
			maul_checked = true
			maul_drive = float(gestes.drive)
			maul_try_follows_seen = bool(gestes.get("maul_try_follows"))
			maul_carrier = gestes.carrier
			var holder: Dictionary = view._actors[gestes.carrier]
			maul_ball = Presentation.ball_anchor(holder.node, holder.rig).distance_to(view._ball.global_position)
			var engine_ball := Vector3(float(frames[index].scene.ball.x) - 50.0, 0.0, float(frames[index].scene.ball.y) - 35.0)
			# Essai à suivre (fait « porte ») : le ballon porté peut pousser jusqu'à Gestes.MAUL_TRY_LEAD m
			# au-delà du point du moteur, vers la ligne ; l'écart compté est celui qui reste au-delà.
			var arrived := Vector3(view._ball.global_position.x, 0.0, view._ball.global_position.z)
			var pushed: float = (arrived.x - engine_ball.x) * gestes.dir
			maul_lead = pushed
			arrived.x -= gestes.dir * clampf(pushed, 0.0, Gestes.MAUL_TRY_LEAD if gestes.maul_try_follows else 0.0)
			maul_arrival = arrived.distance_to(engine_ball)
			for id: String in gestes.cast:
				var member: Dictionary = gestes.cast[id]
				if member.role == "opp_pack": maul_opponents += 1
				if member.role in ["pack", "tail", "opp_pack"]:
					maul_spread = maxf(maul_spread, (view._actors[id].node as Node3D).position.distance_to(holder.node.position))
				if member.role == "pack":
					maul_pitch = maxf(maul_pitch, (view._actors[id].model as Node3D).rotation.x)
		if gestes.phase == "essai_maul" and gestes.done and not try_checked:
			try_checked = true
			grounded = view._ball.global_position
			scorer_pitch = (view._actors[gestes.carrier].model as Node3D).rotation.x
			scorer_hands = hands(view, gestes.carrier)
			check(gestes.carrier == featured(frames[at_try].scene), "Le marqueur est celui que le moteur désigne")
			for id: String in gestes.cast:
				if id != gestes.carrier and gestes.cast[id].team == gestes.side:
					var rig: Skeleton3D = view._actors[id].rig
					if rig.to_global(rig.get_bone_global_pose(rig.find_bone("Palm.L")).origin).y > 1.9: cheering += 1
	check(aligned, "La scène d'alignement met les deux équipes en place avant le lancer")
	var fastest := 0.0
	var fastest_id := ""
	for id: String in visible_peak:
		if visible_peak[id] > fastest:
			fastest = visible_peak[id]
			fastest_id = id
	check(cut_frames.size() == 2 and cut_frames[0][1] == "lineout" and cut_frames[1][1] == "kickoff", "Deux coupes de réalisation : sur la touche formée puis sur le renvoi : " + str(cut_frames))
	check(fastest <= Gestes.PACE_MAX + 0.3, "Personne ne court plus vite que %.1f m/s à l'écran pendant les gestes : %.2f m/s (%s), %d pas rapides hors champ" % [Gestes.PACE_MAX, fastest, fastest_id, hidden_jumps])
	var peaks := {}
	for id: String in visible_peak:
		peaks[id] = snappedf(visible_peak[id], 0.01)
	print("MATCH_GESTES_PACE ", JSON.stringify({"visible_peak_m_s": snappedf(fastest, 0.01), "by_phase": pace_by_phase, "fast_steps_off_screen": hidden_jumps, "cuts": cut_frames, "per_player": peaks}))
	check(winner_jumper == gestes.jumpers[0] or winner_jumper == gestes.jumpers[1], "Le sauteur appartient à un bloc de saut")
	check(peak > 0.95, "Le sauteur est porté à plus de 95 cm : " + str(peak))
	check(rival_peak > 0.4 and rival_peak < peak - 0.2, "Le bloc adverse conteste, moins haut : " + str(rival_peak))
	check(caught, "Prise à deux mains au sommet, ballon à plus de 2,8 m")
	check(maul_checked, "La touche conservée « ballon porté » forme un regroupement")
	check(maul_carrier == featured(frames[at_lineout + 1].scene), "Le porteur du ballon porté est l'acteur désigné par le moteur")
	check(maul_ball < 0.05, "Le ballon est dans les bras du porteur : " + str(maul_ball))
	check(maul_arrival < 0.6, "Le ballon porté arrive au point de ballon du moteur (avance permise si l'essai suit) : " + str(maul_arrival))
	check(maul_opponents >= 1, "Au moins un adversaire est lié : c'est bien un maul")
	check(maul_spread < 3.8, "Le regroupement reste compact : " + str(maul_spread))
	check(maul_pitch > 0.2, "Les liés poussent buste engagé : " + str(maul_pitch))
	print("MATCH_GESTES_MAUL_BUSTES ", JSON.stringify({"couples_images": maul_busts_merged, "pire_m": snappedf(maul_busts_worst, 0.001)}))
	check(maul_busts_merged <= BUSTS_MERGED_MAX, "Ballon porté : aucun buste ni aucune tête dans un autre (%d couples-images au-delà de %.2f m, pire %.2f m)" % [maul_busts_merged, BUST_OVERLAP_MAX, maul_busts_worst])
	check(try_checked, "L'essai prolonge le ballon porté")
	# Lot 8 : le ballon porté avance à allure de ballon porté (pas de sprint du paquet), le porteur
	# aplatit dans l'en-but avant la fin du plan (la régie n'attend un geste que ECHEANCE_GESTE s par
	# plan), et l'essai n'est légendé qu'une fois aplati, dès qu'il l'est.
	var drive_pace := {"maul": drive_path.maul / maxf(0.01, maul_drive), "essai_maul": drive_path.essai_maul / maxf(0.01, float(gestes.drive))}
	print("MATCH_GESTES_MAUL ", JSON.stringify({"pointe_m_s": drive_peak, "moyenne_m_s": drive_pace, "chemin_m": drive_path, "attente_s": hold_by_kind, "aplati_s": snappedf(try_grounded_at, 0.01), "avance_m": snappedf(maul_lead, 0.01)}))
	check(drive_peak.maul <= MAUL_PEAK_MAX + 0.05 and drive_peak.essai_maul <= MAUL_PEAK_MAX + 0.05, "Le ballon porté avance à allure de ballon porté (pointe %.1f m/s au plus) : %s" % [MAUL_PEAK_MAX, str(drive_peak)])
	check(try_grounded_at > 0.0 and aplati_at_ground and not aplati_too_early, "Le porteur aplatit dans l'en-but ; l'essai est dit aplati à cet instant, jamais avant : %.2f s" % try_grounded_at)
	check(maul_try_follows_seen, "La conquête annonce l'essai sur ballon porté (fait « porte » du moteur) : la poussée prend de l'avance")
	for kind: String in hold_by_kind:
		check(float(hold_by_kind[kind]) < Regie.ECHEANCE_GESTE - 0.5, "Le geste tient dans le plan « %s » (échéance de la régie %.0f s) : %.2f s" % [kind, Regie.ECHEANCE_GESTE, hold_by_kind[kind]])
	# Point d'essai du moteur (sur la ligne), reporté de Gestes.IN_GOAL mètres dans l'en-but : on voit l'essai.
	var line_x := float(frames[at_try].scene.ball.x) - 50.0
	var try_point := Vector3(line_x + signf(line_x) * Gestes.IN_GOAL, 0.0, float(frames[at_try].scene.ball.y) - 35.0)
	check(grounded.is_finite() and Vector3(grounded.x, 0.0, grounded.z).distance_to(try_point) < 0.01 and grounded.y < 0.2 and absf(grounded.x) > 50.5 and absf(grounded.x) < 55.0, "Ballon aplati dans l'en-but, dans l'axe du point d'essai du moteur : " + str(grounded))
	check(scorer_pitch > 1.2 and scorer_hands < 0.3, "Le marqueur est allongé, mains sur le ballon : %s / %s" % [scorer_pitch, scorer_hands])
	check(cheering >= 3, "Les partenaires lèvent les bras : " + str(cheering))
	check(waited > 6.0, "Le match attend la fin des gestes : " + str(waited))
	check(kinds[index] == kinds[frames.size() - 1] and not gestes.active() and gestes.cast.is_empty(), "La scène suivante libère tous les joueurs")
	check(not zoom_before_geste and geste_started_at > 0.0 and is_equal_approx(zoom_started_at, geste_started_at), "Le recadrage commence avec le geste : %s / %s" % [zoom_started_at, geste_started_at])
	# Seuils relatifs à la hauteur visible de base (42, 27 et 34 m pour 30 m jusqu'au 19 novembre 2026 au soir).
	check(smallest_in.touche < View.TV_TAILLE * 1.4 and smallest_in.maul < View.TV_TAILLE * 0.9 and smallest_in.essai_maul < View.TV_TAILLE * 1.13, "La caméra TV se rapproche pendant chaque geste : " + str(smallest_in))
	check(smallest >= Gestes.FRAME_MIN.tv - 0.001, "Jamais plus près que le minimum prévu : " + str(smallest))
	check(size_step < 0.06, "Rapprochement progressif, sans coupe : %.4f par image" % size_step)
	check(yaw_step < 0.02, "Pivot lent, sans rotation rapide : %.4f rad par image" % yaw_step)
	check(aim_step < 0.05, "Le recadrage n'ajoute aucun à-coup au suivi : %.3f m par image" % aim_step)
	check(ball_frames > 100 and ball_outside == 0, "Le ballon reste à l'écran pendant le recadrage : %d / %d" % [ball_outside, ball_frames])
	print("MATCH_GESTES_CAMERA ", JSON.stringify({"tv_min_size": smallest_in, "size_log_step": size_step, "yaw_step_rad": yaw_step, "aim_step_m": aim_step}))
	# Le renvoi au centre est à 50 m : la caméra d'origine y coupe, le recadrage aussi (pas de panoramique rapide).
	check(cuts.size() == 1 and cuts[0][1] == "kickoff", "Une seule coupe, au renvoi lointain, comme la caméra d'origine : " + str(cuts))
	check(gestes.zoom == 0.0 and camera_plain(view, TV_OFFSET, View.TV_TAILLE), "Le recadrage finit avec le geste : caméra TV rendue à l'identique")
	for frame in 40: view._process(STEP)
	for id: String in view._actors:
		var model: Node3D = view._actors[id].model
		check(is_zero_approx(model.rotation.x) and is_equal_approx(model.position.y, float(bases[id])), "Corps rendu à l'animation source : " + id)
	check(frames == before, "Les scènes du moteur ne sont jamais modifiées")

	# Mise en place courte (joueurs déjà près de leur place) : pas de coupe, course à allure crédible.
	var cuts_before: int = gestes.cuts
	gestes.cancel()
	for player: Dictionary in frames[at_lineout].scene.players:
		if view._actors.has(str(player.id)):
			view._actors[str(player.id)].node.position = Vector3(float(player.x) - 50.0 + 2.0, 0.0, float(player.y) - 35.0 + 1.5)
	gestes._align(frames[at_lineout].scene, int(frames[at_lineout].events[0].scene.team))
	check(gestes.phase == "touche" and gestes.cuts == cuts_before and gestes.form_seconds >= Gestes.FORM and gestes.form_seconds < 3.0, "Alignement proche : pas de coupe, mise en place courte : %.2f s" % gestes.form_seconds)
	gestes.cancel()

	# Pause, cadence rapide et mode calme : pas de geste.
	view.apply_frame(live(frames, at_lineout - 1))
	for frame in 30: view._process(STEP)
	view.apply_frame(live(frames, at_lineout))
	check(gestes.active(), "L'alignement reprend sur une nouvelle scène de touche")
	for frame in 30: view._process(STEP)
	check(gestes.zoom > 0.0 and camera.size < View.TV_TAILLE, "Le recadrage accompagne le nouvel alignement")
	view.apply_frame(live(frames, at_lineout, true))
	check(not gestes.active(), "La pause annule le geste en cours")
	for frame in 15: view._process(STEP)
	check(gestes.zoom > 0.0 and gestes.zoom < 1.0 and camera.size < View.TV_TAILLE, "Sur place, le retour au cadrage normal est progressif : " + str(gestes.zoom))
	for frame in int(ceil(Gestes.FRAME_OUT / STEP)) + 1: view._process(STEP)
	check(gestes.zoom == 0.0 and camera_plain(view, TV_OFFSET, View.TV_TAILLE), "Pause : la caméra revient à l'identique")
	view.set_live_cadence(4)
	view.apply_frame(live(frames, at_lineout - 1))
	view.apply_frame(live(frames, at_lineout))
	check(not gestes.active(), "Cadence accélérée : pas de geste")
	for frame in 20: view._process(STEP)
	check(gestes.zoom == 0.0 and camera_plain(view, TV_OFFSET, View.TV_TAILLE), "Cadence accélérée : pas de recadrage")
	view.set_live_cadence(1)
	view.set_action_motion(false)
	view.apply_frame(live(frames, at_lineout - 1))
	view.apply_frame(live(frames, at_lineout))
	check(not gestes.active(), "Mode calme : pas de geste")
	for frame in 20: view._process(STEP)
	check(gestes.zoom == 0.0 and camera_plain(view, TV_OFFSET, View.TV_TAILLE), "Mode calme : pas de recadrage")
	view.set_action_motion(true)

	# Caméra « action » : même recadrage, sans pivot ; vue tactique : aucun recadrage.
	view.set_camera("action")
	view.apply_frame(live(frames, at_lineout - 1))
	for frame in 30: view._process(STEP)
	check(camera_plain(view, ACTION_OFFSET, View.ACTION_TAILLE), "Caméra action d'origine hors geste")
	view.apply_frame(live(frames, at_lineout))
	for frame in int(ceil(Gestes.FRAME_IN / STEP)) + 2: view._process(STEP)
	# 19 novembre 2026 (nuit) : cadrage de base du contact resserré à 12 m ; l'alignement (14,5 m de
	# profondeur) peut le remplir : le geste ne l'élargit jamais (au plus la taille de base).
	check(gestes.zoom == 1.0 and camera.size <= View.ACTION_TAILLE + 0.01 and camera.global_basis.is_equal_approx(Basis.looking_at(-view.offset_suivi(ACTION_OFFSET, view._camera_focus.z), Vector3.UP)), "Caméra action : rapprochée, angle inchangé : " + str(camera.size))
	print("MATCH_GESTES_ACTION_TOUCHE_SIZE ", camera.size)
	view.set_camera("tactical")
	check(gestes.zoom == 0.0, "Vue tactique : aucun recadrage")
	view.set_camera("action")
	view.apply_frame(live(frames, at_lineout - 1))
	for frame in int(ceil(Gestes.FRAME_OUT / STEP)) + 1: view._process(STEP)
	check(gestes.phase in ["", "approche"] and camera_plain(view, ACTION_OFFSET, View.ACTION_TAILLE), "Caméra action rendue à l'identique")
	view.set_camera("tv")

	# Essai hors ballon porté : le marqueur désigné plonge seul.
	view.apply_frame(live(frames, 0))
	for frame in 30: view._process(STEP)
	view.apply_frame(live(frames, at_try))
	check(gestes.phase == "essai" and gestes.carrier == featured(frames[at_try].scene), "Essai isolé : plongeon du marqueur désigné")
	clock = 0.0
	while not gestes.done and clock < 30.0:
		view._process(STEP)
		clock += STEP
	check(Vector3(view._ball.global_position.x, 0.0, view._ball.global_position.z).distance_to(try_point) < 0.01 and view._ball.global_position.y < 0.2, "Essai isolé : ballon aplati au point du moteur")
	check(hands(view, gestes.carrier) < 0.3, "Essai isolé : mains sur le ballon")
	view.apply_frame({})
	check(not gestes.active(), "Scène vide : gestes libérés")

	print("MATCH_GESTES_CHECKS ", checks, " failures=", failures.size())
	quit(1 if not failures.is_empty() else 0)
