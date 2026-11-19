extends SceneTree
## Retouches de caméra du match 3D (18 novembre 2026, soir) :
## 1. inclinaison plafonnée près de la touche proche (TV et contact : joueurs vus de 3/4) ;
## 2. pivot des gestes borné et point visé dans l'aire de jeu sur un essai en coin ;
## 3. caméra au contact : aucun poteau entre elle et l'action ;
## 4. hors temps fort, la hauteur visible s'élargit quand les joueurs concernés s'écartent, sans à-coup ;
## 5. (nuit) essai près de chaque touche en TV, gestes compris : axe et bas de l'image plafonnés ;
## 6. (nuit) caméra au contact, essai dans les quatre coins : visée dans l'aire de jeu, regard vers l'intérieur.

const View = preload("res://match_view.gd")
const Cadrage = preload("res://match_cadrage.gd")
const Gestes = preload("res://match_gestes.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []
var checks := 0
var report := {}


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)


## Scène du moteur (x 0..100, y 0..70) à partir de positions au sol de la vue (x -50..50, z -35..35).
## `places` : id -> Vector2(x, z) ; le joueur « 0-0 » porte le ballon, posé sur `ballon`.
func scene(ballon: Vector2, places: Dictionary) -> Dictionary:
	var players: Array = []
	for side in 2:
		for slot in 15:
			var id := "%d-%d" % [side, slot]
			var place: Vector2 = places.get(id, Vector2(-40.0 + slot * 5.5 + side * 2.0, -32.0 + side * 2.0))
			if id == "0-0":
				place = ballon
			players.append({"id": id, "side": side, "slot": slot, "x": place.x + 50.0, "y": place.y + 35.0, "featured": id == "0-0"})
	return {"scene": {"kind": "carry", "possession": 0, "players": players, "ball": {"x": ballon.x + 50.0, "y": ballon.y + 35.0}},
		"teams": [{"color": "#a12f41"}, {"color": "#6f9ac9"}]}


func settle(view, frame: Dictionary, seconds: float) -> void:
	view.apply_frame(frame)
	for i in int(seconds / STEP):
		view._process(STEP)


func make_view(mode: String):
	var view = View.new()
	root.add_child(view)
	view.set_process(false)
	view.set_live_cadence(1)
	await process_frame
	view.set_camera(mode)
	return view


func elevation(direction: Vector3) -> float:
	return rad_to_deg(atan2(direction.y, Vector2(direction.x, direction.z).length()))


## Part de l'image (grille de 32 x 18 rayons) qui montre le terrain et ses abords immédiats (3 m).
func part_terrain(view) -> float:
	var camera: Camera3D = view._camera
	var taille: Vector2 = view.get_viewport().get_visible_rect().size
	var dedans := 0
	for i in 32:
		for j in 18:
			var pixel := Vector2((i + 0.5) / 32.0 * taille.x, (j + 0.5) / 18.0 * taille.y)
			var origine := camera.project_ray_origin(pixel)
			var normale := camera.project_ray_normal(pixel)
			if normale.y < -0.001:
				var sol := origine + normale * (-origine.y / normale.y)
				if absf(sol.x) <= 58.0 and absf(sol.z) <= 38.0:
					dedans += 1
	return dedans / 576.0


## Lacet (rad) de `offset` autour de la verticale, mesuré depuis `reference`.
func yaw(reference: Vector3, offset: Vector3) -> float:
	return wrapf(atan2(offset.x, offset.z) - atan2(reference.x, reference.z), -PI, PI)


func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)

	# 1. Inclinaison plafonnée, du milieu du terrain jusqu'à la touche proche.
	var view = await make_view("tv")
	var plus_raide := {"tv": 0.0, "action": 0.0}
	for z in range(-35, 36):
		plus_raide.tv = maxf(plus_raide.tv, elevation(view.offset_suivi(View.TV_OFFSET, float(z))))
		plus_raide.action = maxf(plus_raide.action, elevation(view.offset_suivi(View.ACTION_OFFSET, float(z))))
	report["inclinaison_max"] = plus_raide
	for mode in ["tv", "action"]:
		check(float(plus_raide[mode]) <= View.INCLINAISON_MAX + 0.01, "Caméra %s : inclinaison plafonnée près de la touche proche (%.1f°)" % [mode, plus_raide[mode]])
	check(elevation(view.offset_suivi(View.TV_OFFSET, 34.0)) >= elevation(View.TV_OFFSET) - 0.01, "La grue ne descend jamais sous l'angle de base")
	for mode in ["tv", "action"]:
		view.set_camera(mode)
		settle(view, scene(Vector2(0.0, 34.0), {}), 2.0)
		var vue := elevation(view._camera.global_basis.z)
		report["inclinaison_touche_" + mode] = snappedf(vue, 0.1)
		check(vue <= View.INCLINAISON_MAX + 0.5, "Caméra %s, porteur sur la touche proche : vue de 3/4, pas du dessus (%.1f°)" % [mode, vue])
		check(view._camera.global_position.y > 0.0 and view._camera.global_position.z > 34.0, "Caméra %s : toujours devant l'action, côté tribune principale" % mode)
	view.queue_free()
	await process_frame

	# 2. Essai dans un coin : pivot des gestes borné, point visé dans l'aire de jeu.
	view = await make_view("tv")
	var pivot: float = Gestes.FRAME_YAW.tv
	for coin in [Vector3(-52.0, 0.0, 32.0), Vector3(-52.0, 0.0, -32.0), Vector3(52.0, 0.0, 32.0), Vector3(52.0, 0.0, -32.0)]:
		var suivi: Vector3 = view.offset_suivi(View.TV_OFFSET, coin.z)
		for sens in [1.0, -1.0]:
			var tourne: Vector3 = view.borner_pivot(coin, suivi.rotated(Vector3.UP, pivot * sens), suivi)
			var angle := yaw(suivi, tourne)
			check(absf(angle) <= View.PIVOT_MAX + 0.0001, "Essai en coin %s : lacet limité (%.3f rad)" % [coin, angle])
			# La caméra regarde vers -offset : vers le bout du terrain le plus proche, le pivot s'efface.
			if -tourne.x * coin.x > 0.001:
				check(absf(angle) < 0.01, "Essai en coin %s : pas de pivot vers la tribune du bout du terrain (%.3f rad)" % [coin, angle])
			check(is_equal_approx(tourne.length(), suivi.length()) and is_equal_approx(elevation(tourne), elevation(suivi)), "Le pivot borné garde la distance et l'inclinaison")
		var vise: Vector3 = view.borner_visee(coin)
		check(absf(vise.x) <= 50.0 and absf(vise.z) <= 30.0, "Essai en coin %s : point visé dans l'aire de jeu %s" % [coin, vise])
	var milieu_suivi: Vector3 = view.offset_suivi(View.TV_OFFSET, 0.0)
	check(absf(yaw(milieu_suivi, view.borner_pivot(Vector3.ZERO, milieu_suivi.rotated(Vector3.UP, pivot), milieu_suivi)) - minf(pivot, View.PIVOT_MAX)) < 0.001, "Au milieu du terrain le pivot reste (limité à PIVOT_MAX)")
	check(view.borner_pivot(Vector3.ZERO, milieu_suivi, milieu_suivi) == milieu_suivi, "Sans pivot, la direction de suivi est rendue à l'identique")
	view.queue_free()
	await process_frame

	# 3. Caméra au contact : un poteau entre la caméra et l'action fait pivoter la caméra.
	view = await make_view("action")
	view.apply_frame({"scene": {}})
	view._process(STEP)
	var masque := Vector3(48.8, 0.0, -1.4)
	var base: Vector3 = view.offset_suivi(View.ACTION_OFFSET, masque.z)
	check(view.poteau_masque(masque, View.ACTION_TAILLE, base), "Cas témoin : sans contournement, le poteau masque l'action")
	var angle: float = view.contournement_poteaux(masque, View.ACTION_TAILLE, base)
	report["contournement_temoin"] = snappedf(angle, 0.001)
	check(absf(angle) > 0.0 and absf(angle) <= View.CONTOURNEMENT_MAX, "Le contournement choisit un pivot borné (%.3f rad)" % angle)
	check(not view.poteau_masque(masque, View.ACTION_TAILLE, base.rotated(Vector3.UP, angle)), "Après contournement, aucun poteau entre la caméra et l'action")
	check(is_zero_approx(view.contournement_poteaux(Vector3(0.0, 0.0, -1.4), View.ACTION_TAILLE, base)), "Loin des poteaux : aucun pivot")
	# Bout en bout : porteur derrière les poteaux, vu par la caméra au contact.
	var masques := 0
	var degages := 0
	for place in [Vector2(48.8, -1.4), Vector2(47.0, -4.0), Vector2(49.0, -8.0), Vector2(46.0, -14.0), Vector2(44.0, -18.0), Vector2(-48.0, -1.0)]:
		settle(view, scene(place, {}), 3.0)
		var camera: Vector3 = view._camera.global_position
		var look: Vector3 = view._camera_look
		var ballon: Vector3 = view._ball.global_position
		if view.poteau_masque(look, view._camera.size, view.offset_suivi(View.ACTION_OFFSET, view._camera_focus.z), 0.2):
			masques += 1
		var libre: bool = not view.poteau_entre(camera, ballon, 0.2) and not view.poteau_entre(camera, Vector3(look.x, 1.0, look.z), 0.2)
		if libre:
			degages += 1
		check(libre, "Caméra au contact, porteur en %s : aucun poteau entre la caméra et l'action (pivot %.3f rad)" % [place, view._contournement])
		check(absf(view._camera.global_basis.x.y) < 0.001, "Le pivot de contournement n'incline jamais l'horizon")
	report["contact_poteaux"] = {"masques_sans_contournement": masques, "degages": degages}
	print("MATCH_CAMERA_RETOUCHES_POTEAUX ", masques, " ", degages)
	view.queue_free()
	await process_frame

	# 4. Hors temps fort : la hauteur visible englobe les joueurs concernés et s'élargit quand ils s'écartent.
	view = await make_view("tv")
	var cadrage = Cadrage.new(view)
	view.set_cadrage(cadrage)
	cadrage.regler(false)
	var groupe := ["0-1", "0-2", "1-1", "1-2"]
	var serre := {}
	var ecarte := {}
	var cotes := [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]
	for i in groupe.size():
		serre[groupe[i]] = Vector2(cotes[i].x * 2.0, cotes[i].y * 1.5)
		ecarte[groupe[i]] = Vector2(cotes[i].x * 22.0, cotes[i].y * 1.0)
	cadrage.couper()
	settle(view, scene(Vector2.ZERO, serre), 3.0)
	var taille_serree: float = view._camera.size
	var plus_grand_pas := 0.0
	var precedente := taille_serree
	view.apply_frame(scene(Vector2.ZERO, ecarte))
	for i in int(6.0 / STEP):
		view._process(STEP)
		plus_grand_pas = maxf(plus_grand_pas, absf(view._camera.size - precedente))
		precedente = view._camera.size
	var taille_ecartee: float = view._camera.size
	report["suivi_tv"] = {"serre": snappedf(taille_serree, 0.1), "ecarte": snappedf(taille_ecartee, 0.1), "plus_grand_pas": snappedf(plus_grand_pas, 0.001)}
	check(taille_serree >= Cadrage.SUIVI.tv[0] - 0.01 and taille_serree <= 30.0, "Joueurs groupés : cadrage resserré (%.1f m)" % taille_serree)
	check(taille_ecartee > taille_serree + 6.0, "Joueurs écartés : la hauteur visible s'élargit (%.1f -> %.1f m)" % [taille_serree, taille_ecartee])
	check(taille_ecartee <= Cadrage.SUIVI.tv[1] + 0.01, "Le cadrage adaptatif reste borné (%.1f m)" % taille_ecartee)
	check(plus_grand_pas < 0.5, "Cadrage adaptatif lissé : pas d'à-coup (%.3f m par image au plus)" % plus_grand_pas)
	# Les joueurs écartés restent à l'image.
	for id: String in groupe:
		var spot: Vector3 = (view._actors[id].node as Node3D).position + Vector3.UP
		var point: Vector2 = view._camera.unproject_position(spot) / view.get_viewport().get_visible_rect().size
		check(not view._camera.is_position_behind(spot) and point.x >= 0.0 and point.x <= 1.0 and point.y >= 0.0 and point.y <= 1.0, "Joueur concerné %s à l'image (%s)" % [id, point])
	# Le temps fort part du cadrage adaptatif, puis le cadrage revient vers lui à la sortie.
	cadrage.regler(true, "carry")
	for i in int(2.0 / STEP):
		view._process(STEP)
	cadrage.regler(false)
	for i in int(3.0 / STEP):
		view._process(STEP)
	check(cadrage.poids == 0.0 and absf(view._camera.size - taille_ecartee) < 1.0, "Après le temps fort, retour au cadrage adaptatif (%.1f m)" % view._camera.size)
	view.set_cadrage(null)
	view.queue_free()
	await process_frame

	# 5. Vue TV, essai près de chaque touche (gauche/droite, deux sens de jeu), gestes compris : l'axe reste
	# sous INCLINAISON_MAX et le bas de l'image sous PLONGEE_MAX (pas d'angle grand ouvert sous le toit).
	view = await make_view("tv")
	var pire := {"axe": 0.0, "plongee": 0.0}
	for mode in ["tv", "action"]:
		view.set_camera(mode)
		var base_offset: Vector3 = View.TV_OFFSET if mode == "tv" else View.ACTION_OFFSET
		var tailles := [float(Gestes.FRAME_MIN[mode]) * 0.5, float(Gestes.FRAME_MIN[mode]), View.TV_TAILLE if mode == "tv" else View.ACTION_TAILLE, float(Cadrage.LARGE[mode])]
		for z in range(-35, 36):
			for x in [-52.0, -30.0, 0.0, 30.0, 52.0]:
				var vise: Vector3 = view.borner_visee(Vector3(x, 0.0, float(z)))
				var suivi: Vector3 = view.offset_suivi(base_offset, float(z), x)
				for w in [0.0, 0.5, 1.0]:
					var offset: Vector3 = view.borner_pivot(vise, suivi.rotated(Vector3.UP, float(Gestes.FRAME_YAW[mode]) * w), suivi)
					for taille: float in tailles:
						var pose: Array = view.pose_camera(vise, taille, offset)
						var axe := elevation(offset)
						var plongee := axe + float(pose[1]) * 0.5
						pire.axe = maxf(pire.axe, axe)
						pire.plongee = maxf(pire.plongee, plongee)
						if axe > View.INCLINAISON_MAX + 0.01 or plongee > View.PLONGEE_MAX + 0.01:
							check(false, "Caméra %s, point visé %s, taille %.1f, geste %.1f : axe %.1f°, bas de l'image %.1f°" % [mode, vise, taille, w, axe, plongee])
	check(pire.axe <= View.INCLINAISON_MAX + 0.01 and pire.plongee <= View.PLONGEE_MAX + 0.01, "Inclinaison et plongée plafonnées partout, gestes compris (%.1f°, %.1f°)" % [pire.axe, pire.plongee])
	report["plafond_gestes"] = {"axe": snappedf(pire.axe, 0.1), "plongee": snappedf(pire.plongee, 0.1)}
	view.set_camera("tv")
	var cadrage_essai = Cadrage.new(view)
	view.set_cadrage(cadrage_essai)
	var essais := {}
	for touche in [34.0, -34.0]:
		for bout in [44.0, -44.0]:
			for possession in [0, 1]:
				cadrage_essai.regler(true, "carry")
				cadrage_essai.couper()
				var frame := scene(Vector2(bout, touche), {})
				frame["scene"]["possession"] = possession
				settle(view, frame, 2.5)
				var axe := elevation(view._camera.global_basis.z)
				var plongee := axe + float(view._camera.fov) * 0.5
				essais["%d_%d_%d" % [int(bout), int(touche), possession]] = [snappedf(axe, 0.1), snappedf(plongee, 0.1)]
				check(axe <= View.INCLINAISON_MAX + 0.5, "TV, essai en (%d, %d), sens %d : vue de 3/4 (%.1f°)" % [bout, touche, possession, axe])
				check(plongee <= View.PLONGEE_MAX + 0.5, "TV, essai en (%d, %d), sens %d : bas de l'image pas vu du dessus (%.1f°)" % [bout, touche, possession, plongee])
	report["essais_tv"] = essais
	view.set_cadrage(null)
	view.queue_free()
	await process_frame

	# 6. Caméra au contact, essai dans les quatre coins : point visé dans l'aire de jeu, regard vers
	# l'intérieur du terrain (jamais vers la tribune du bout), terrain qui remplit l'essentiel de l'image.
	view = await make_view("action")
	var coins := {}
	for coin in [Vector2(-49.0, 32.0), Vector2(-49.0, -32.0), Vector2(49.0, 32.0), Vector2(49.0, -32.0)]:
		for possession in [0, 1]:
			var frame := scene(coin, {})
			frame["scene"]["possession"] = possession
			settle(view, frame, 3.0)
			var vise: Vector3 = view._camera_look
			var regard: Vector3 = -view._camera.global_basis.z
			var part := part_terrain(view)
			coins["%d_%d_%d" % [int(coin.x), int(coin.y), possession]] = {"vise": [snappedf(vise.x, 0.1), snappedf(vise.z, 0.1)], "regard_x": snappedf(regard.x, 0.01), "terrain": snappedf(part, 0.01)}
			check(absf(vise.x) <= 50.0 and absf(vise.z) <= 30.0, "Contact, essai en coin %s : point visé dans l'aire de jeu %s" % [coin, vise])
			check(regard.x * signf(coin.x) <= 0.02, "Contact, essai en coin %s : regard vers l'intérieur du terrain (%.2f)" % [coin, regard.x])
			check(part >= 0.5, "Contact, essai en coin %s : tribune limitée, le terrain remplit l'image (%.2f)" % [coin, part])
	report["coins_contact"] = coins
	# Bascule de la caméra de biais près de l'en-but gauche : continue (pas d'à-coup de direction).
	var precedent: Vector3 = view.offset_suivi(View.ACTION_OFFSET, 0.0, 0.0)
	var plus_grand_ecart := 0.0
	for i in range(1, 601):
		var courant: Vector3 = view.offset_suivi(View.ACTION_OFFSET, 0.0, -0.1 * i)
		plus_grand_ecart = maxf(plus_grand_ecart, courant.angle_to(precedent))
		precedent = courant
	check(plus_grand_ecart < 0.01, "Caméra au contact : bascule de biais progressive (%.4f rad par 10 cm)" % plus_grand_ecart)
	check(is_equal_approx(view.offset_suivi(View.ACTION_OFFSET, 0.0, -50.0).x, -View.ACTION_OFFSET.x), "Au bout gauche, la caméra au contact est symétrique (derrière l'en-but)")
	check(view.offset_suivi(View.ACTION_OFFSET, 0.0, 50.0).is_equal_approx(View.ACTION_OFFSET), "Au bout droit, la caméra au contact garde son biais")
	view.queue_free()
	await process_frame

	print("MATCH_CAMERA_RETOUCHES ", JSON.stringify(report))
	print("MATCH_CAMERA_RETOUCHES_CHECKS %d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
