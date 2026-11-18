extends SceneTree
## Après l'essai et coups de pied placés (19 novembre 2026, match filmé : une quinzaine de secondes
## d'image presque figée après chaque essai, transformation mal cadrée). Sans moteur ni carrière,
## sans bibliothèque d'animations (repli procédural) :
##  1. scène d'après-essai : le marqueur se relève, au moins trois partenaires le rejoignent (à moins
##     de 4 m à la fin de la célébration), les défenseurs rentrent en marchant vers leur en-but, les
##     autres se replacent (plus d'immobilité totale) ;
##  2. l'arbitre accorde l'essai : il siffle, rejoint le point d'aplati (moins de 5 m) et tend le bras
##     vers lui ;
##  3. transformation (loi 8) : défenseurs derrière leur ligne de but, équipe du buteur derrière le
##     ballon, buteur quelques pas derrière le ballon dans l'axe des poteaux ;
##  4. tirs au but filmés dans l'axe : caméra derrière le buteur, un peu en hauteur ; buteur, ballon et
##     les deux poteaux dans le champ, hors du bandeau et de la légende ; pendant le vol, ballon et
##     poteaux restent à l'image, le ballon passe au-dessus de la barre.
## Coordonnées de test (repère du moteur : x de 0 à 100, y de 0 à 70), jamais un vrai match.

const View = preload("res://match_view.gd")
const Gestes = preload("res://match_gestes.gd")
const Cadrage = preload("res://match_cadrage.gd")
const Arbitre = preload("res://match_arbitre.gd")
const ApresEssai = preload("res://match_apres_essai.gd")
const STEP := 1.0 / 30.0
## Parts de l'image couvertes par le bandeau du score (haut) et la légende (bas), comme en temps forts.
const COUVERT_HAUT := 0.12
const COUVERT_BAS := 0.2

var failures: Array[String] = []
var checks := 0
var mesures := {}


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)


## Trente joueurs : le camp 0 attaque vers x = 100. Places du moteur pour l'essai en (100, 40).
func joueurs(marqueur: String, marqueur_a: Vector2) -> Array:
	var places := {
		"0-0": Vector2(70, 30), "0-1": Vector2(72, 38), "0-2": Vector2(71, 46), "0-3": Vector2(76, 26),
		"0-4": Vector2(77, 52), "0-5": Vector2(80, 33), "0-6": Vector2(83, 47), "0-7": Vector2(88, 52),
		"0-8": Vector2(86, 34), "0-9": Vector2(90, 44), "0-10": Vector2(66, 40), "0-11": Vector2(85, 40),
		"0-12": Vector2(74, 58), "0-13": Vector2(62, 22), "0-14": Vector2(55, 35),
		"1-0": Vector2(92, 30), "1-1": Vector2(93, 38), "1-2": Vector2(91, 48), "1-3": Vector2(89, 24),
		"1-4": Vector2(95, 56), "1-5": Vector2(87, 60), "1-6": Vector2(84, 16), "1-7": Vector2(80, 64),
		"1-8": Vector2(78, 12), "1-9": Vector2(97, 42), "1-10": Vector2(82, 8), "1-11": Vector2(96, 18),
		"1-12": Vector2(75, 40), "1-13": Vector2(94, 64), "1-14": Vector2(98, 34),
	}
	var liste: Array = []
	for camp in 2:
		for slot in 15:
			var id := "%d-%d" % [camp, slot]
			var at: Vector2 = marqueur_a if id == marqueur else places[id]
			liste.append({"id": id, "side": camp, "slot": slot, "featured": id == marqueur, "x": at.x, "y": at.y})
	return liste


func scene(kind: String, key: String, liste: Array, ballon: Vector2, origine: Vector2, camp: int = 0) -> Dictionary:
	return {"kind": kind, "key": key, "possession": camp, "team": camp, "players": liste,
		"ball": {"x": ballon.x, "y": ballon.y}, "origin": {"x": origine.x, "y": origine.y}}


func image(valeur: Dictionary, en_pause: bool = false) -> Dictionary:
	return {"scene": valeur, "teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}], "events": [], "paused": en_pause}


func nouvelle_vue():
	var view = View.new()
	root.add_child(view)
	view.set_process(false)
	view.set_gestes(true)
	view.set_live_cadence(1)
	return view


func sol(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Scène de transformation telle que le moteur la déduit (match-direct.cjs `transformation`) : le
## buteur à 22 m de la ligne dans l'axe du point d'essai, les autres où l'essai les a laissés.
func transformation_moteur(liste: Array, camp: int, essai_y: float, buteur: String, key: String) -> Dictionary:
	var marque := ApresEssai.marque(camp, essai_y)
	var copie: Array = []
	for joueur: Dictionary in liste:
		var place := joueur.duplicate()
		place.featured = str(joueur.id) == buteur
		if str(joueur.id) == buteur:
			place.x = marque.x
			place.y = marque.y
		copie.append(place)
	return scene("goal", key, copie, Vector2(ApresEssai.but_x(camp), 35.0), marque, camp)


func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	places_loi_8()
	vol_du_ballon()
	await apres_essai()
	# Tirs au but : conversion centrée et près de la touche (TV), camp 1 vers x = 0 (TV), pénalité
	# de 40 m (caméra au contact).
	await tir_dans_l_axe("transformation centrée", "tv", 0, 45.0, Vector2.INF)
	await tir_dans_l_axe("transformation près de la touche", "tv", 0, 3.0, Vector2.INF)
	await tir_dans_l_axe("transformation vers x = 0", "tv", 1, 30.0, Vector2.INF)
	await tir_dans_l_axe("pénalité à 40 m", "action", 0, 0.0, Vector2(60, 25))
	print("MATCH_APRES_ESSAI ", JSON.stringify(mesures))
	print("MATCH_APRES_ESSAI_CHECKS %d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)


## Places de la transformation (loi 8), fonctions pures.
func places_loi_8() -> void:
	for camp in 2:
		var liste := joueurs("0-11", Vector2(100, 40))
		if camp == 1:
			# Miroir : le camp 1 attaque vers x = 0.
			for joueur: Dictionary in liste:
				joueur.side = 1 - int(joueur.side)
				joueur.x = 100.0 - float(joueur.x)
				joueur.id = "%d-%d" % [int(joueur.side), int(joueur.slot)]
		var buteur := "%d-14" % camp
		var moteur := transformation_moteur(liste, camp, 40.0, buteur, "[40,\"t\",\"goal\"]")
		var avant := JSON.stringify(moteur)
		var loi := ApresEssai.transformation(moteur)
		var marque := Vector2(float(moteur.origin.x), float(moteur.origin.y))
		var sens := 1.0 if camp == 0 else -1.0
		var but := ApresEssai.but_x(camp)
		var defense_ok := 0
		var attaque_ok := 0
		var vus: Array[Vector2] = []
		var serres := 0
		for joueur: Dictionary in loi.players:
			var at := Vector2(float(joueur.x), float(joueur.y))
			for autre: Vector2 in vus:
				if autre.distance_to(at) < 1.0: serres += 1
			vus.append(at)
			if str(joueur.id) == buteur:
				check(at.distance_to(marque) < 0.01, "Camp %d : le buteur reste sur la marque" % camp)
				continue
			if int(joueur.side) != camp and (at.x - but) * sens > 0.5 and (at.x - but) * sens < ApresEssai.EN_BUT and at.y > 1.0 and at.y < 69.0: defense_ok += 1
			if int(joueur.side) == camp and (marque.x - at.x) * sens >= ApresEssai.SOUTIEN_RECUL - 0.01 and at.y > 1.0 and at.y < 69.0: attaque_ok += 1
		check(defense_ok == 15, "Camp %d : les quinze défenseurs sont derrière leur ligne de but, dans l'en-but (%d)" % [camp, defense_ok])
		check(attaque_ok == 14, "Camp %d : l'équipe du buteur est derrière le ballon (%d sur 14)" % [camp, attaque_ok])
		check(serres == 0, "Camp %d : personne n'est posé sur un autre joueur (%d)" % [camp, serres])
		# Élan : buteur ELAN m derrière le ballon, dans l'axe des poteaux ; ballon sur la marque.
		var elan := ApresEssai.elan(loi, ApresEssai.ELAN)
		var place := Vector2.INF
		for joueur: Dictionary in elan.players:
			if str(joueur.id) == buteur: place = Vector2(float(joueur.x), float(joueur.y))
		var axe := (marque - Vector2(but, 35.0)).normalized()
		check(absf(place.distance_to(marque) - ApresEssai.ELAN) < 0.01 and (place - marque).normalized().dot(axe) > 0.999, "Camp %d : buteur à %.1f m derrière le ballon, dans l'axe des poteaux" % [camp, ApresEssai.ELAN])
		check(Vector2(float(elan.ball.x), float(elan.ball.y)).distance_to(marque) < 0.01, "Camp %d : ballon posé sur la marque pendant l'élan" % camp)
		check(JSON.stringify(moteur) == avant, "Camp %d : la scène du moteur n'est pas modifiée" % camp)


## Vol d'un tir au but : au-dessus de la barre à la ligne de but, retombé dans l'en-but, assez court
## pour que la régie annonce le résultat après le passage du ballon.
func vol_du_ballon() -> void:
	for distance: float in [22.0, 35.0, 45.0]:
		var depart := Vector3(50.0 - distance, 0.23, 4.0)
		var cible := Vector3(50.0, 0.23, 0.0)
		var plus_haut := 0.0
		var a_la_ligne := -1.0
		var precedent := depart
		for k in 401:
			var p := ApresEssai.vol(depart, cible, k / 400.0)
			plus_haut = maxf(plus_haut, p.y)
			if precedent.x < 50.0 and p.x >= 50.0: a_la_ligne = p.y
			precedent = p
		var fin := ApresEssai.vol(depart, cible, 1.0)
		check(a_la_ligne > ApresEssai.BARRE + 0.5, "Tir de %d m : le ballon passe la ligne au-dessus de la barre (%.2f m)" % [int(distance), a_la_ligne])
		check(plus_haut < 20.0 and fin.x > 50.5 and fin.x < 56.0 and fin.y < 0.2, "Tir de %d m : trajectoire de botteur, ballon retombé dans l'en-but (%.1f m de haut, fin %s)" % [int(distance), plus_haut, str(fin)])
		var duree := ApresEssai.duree_vol(depart, cible)
		check(duree >= 0.6 and duree <= 1.2, "Tir de %d m : vol de %.2f s" % [int(distance), duree])


## Essai du 0-11 (course de 15 m), puis la scène d'après-essai jusqu'à la fin de la célébration.
func apres_essai() -> void:
	var view = nouvelle_vue()
	await process_frame
	var marqueur := "0-11"
	var liste := joueurs(marqueur, Vector2(85, 40))
	# Image posée (en pause) : joueurs en place, ballon dans les mains du marqueur, aucun plaquage.
	view.apply_frame(image(scene("carry", "[60,\"course\",\"carry\"]", liste, Vector2(85, 40), Vector2(80, 40)), true))
	for k in 5: view._process(STEP)
	var arbitre = Arbitre.new(view)
	view.add_child(arbitre)
	check(arbitre.preparer(), "Arbitre habillé")
	arbitre.set_process(false)
	arbitre.placer(arbitre.place_de_jeu(view._ball.global_position), view._ball.global_position)
	var essai := joueurs(marqueur, Vector2(100, 40))
	view.apply_frame(image(scene("try", "[61,\"essai\",\"try\"]", essai, Vector2(100, 40), Vector2(85, 40))))
	var gestes: RefCounted = view._gestes
	check(gestes.phase == "essai" and gestes.carrier == marqueur, "Le marqueur désigné court et plonge (%s)" % gestes.phase)
	var aplati := float(gestes.pass_at) + float(gestes.drive)
	var point: Vector3 = gestes.target
	var depart_apres: Dictionary = {}
	var allure_defense := 0.0
	var precedent: Dictionary = {}
	var siffle := false
	var bras := false
	var bras_a := -1.0
	var debout_au_done := -1.0
	var horloge := 0.0
	while gestes.active() and float(gestes.time) < aplati + Gestes.CELEBRATION and horloge < 30.0:
		view._process(STEP)
		arbitre._process(STEP)
		horloge += STEP
		var t := float(gestes.time) - aplati
		if t >= 0.5 and depart_apres.is_empty():
			for id: String in view._actors: depart_apres[id] = (view._actors[id].node as Node3D).position
		if t > 0.4:
			for id: String in view._actors:
				var at: Vector3 = (view._actors[id].node as Node3D).position
				if precedent.has(id) and int(view._actors[id].side) == 1:
					allure_defense = maxf(allure_defense, sol(at, precedent[id]) / STEP)
				precedent[id] = at
		if gestes.done and debout_au_done < 0.0:
			debout_au_done = (view._actors[marqueur].model as Node3D).rotation.x
		if t >= 0.0 and str(arbitre.signal_bras) == "sifflet": siffle = true
		var vers: Vector3 = point - arbitre.position
		vers.y = 0.0
		if str(arbitre.signal_bras) == "bras" and str(arbitre._signal_vu) == "bras" and float(arbitre._poids) >= 0.99 and sol(arbitre.position, point) < 5.0 \
			and Vector3(arbitre.direction_bras.x, 0.0, arbitre.direction_bras.z).normalized().dot(vers.normalized()) > 0.9:
			bras = true
			if bras_a < 0.0: bras_a = t
	check(float(gestes.time) >= aplati + Gestes.CELEBRATION, "La célébration se joue jusqu'au bout (%.1f s après l'aplati)" % (float(gestes.time) - aplati))
	# 1. Le marqueur, allongé quand la régie reprend la main, est debout à la fin.
	var scorer: Dictionary = view._actors[marqueur]
	var tangage := absf((scorer.model as Node3D).rotation.x)
	check(debout_au_done > 1.2, "Le marqueur est encore allongé à la fin du geste (%.2f rad)" % debout_au_done)
	check(tangage < 0.1, "Le marqueur s'est relevé (%.2f rad)" % tangage)
	var centre: Vector3 = (scorer.node as Node3D).position
	var proches := 0
	var felicite := 0
	for id: String in view._actors:
		if id == marqueur or int(view._actors[id].side) != 0: continue
		if sol((view._actors[id].node as Node3D).position, centre) < 4.0: proches += 1
		if gestes.cast.has(id) and str(gestes.cast[id].role) == "felicite": felicite += 1
	check(felicite >= Gestes.FELICITE_MIN and felicite <= Gestes.FELICITE_MAX, "%d partenaires courent féliciter le marqueur" % felicite)
	check(proches >= 3, "Au moins trois partenaires autour du marqueur, à moins de 4 m (%d)" % proches)
	# 2. Défenseurs : ils rentrent en marchant vers leur en-but (derrière leur ligne, x > 50).
	var rentrent := 0
	var vers_l_en_but := 0
	for id: String in view._actors:
		if int(view._actors[id].side) != 1: continue
		var member: Dictionary = gestes.cast.get(id, {})
		if str(member.get("role", "")) == "repli" and (member.mark as Vector3).x > 50.0: vers_l_en_but += 1
		var at: Vector3 = (view._actors[id].node as Node3D).position
		if member.has("mark") and depart_apres.has(id) and sol(at, member.mark) < sol(depart_apres[id], member.mark) - 1.0: rentrent += 1
	check(vers_l_en_but == 15, "Les quinze défenseurs rentrent vers leur en-but, derrière leur ligne de but (%d)" % vers_l_en_but)
	check(rentrent >= 13, "Ils se rapprochent vraiment de leur place (%d sur 15)" % rentrent)
	check(allure_defense > 0.5 and allure_defense <= 2.6, "Ils marchent, sans courir (pointe %.2f m/s)" % allure_defense)
	# 3. Plus d'immobilité totale : presque tout le monde bouge pendant la célébration.
	var bougent := 0
	for id: String in view._actors:
		if id != marqueur and depart_apres.has(id) and sol((view._actors[id].node as Node3D).position, depart_apres[id]) > 0.5: bougent += 1
	check(bougent >= 24, "Les joueurs se replacent, personne n'est figé (%d sur 29 ont bougé)" % bougent)
	# 4. Arbitre : sifflet, puis bras tendu vers le point d'aplati, à moins de 5 m.
	check(siffle, "L'arbitre siffle l'essai")
	check(bras, "L'arbitre accorde l'essai près du point d'aplati, bras tendu vers lui (à %.1f m)" % sol(arbitre.position, point))
	mesures["apres_essai"] = {"partenaires_4m": proches, "defenseurs_rentrent": rentrent, "pointe_defense_m_s": snappedf(allure_defense, 0.01),
		"bougent": bougent, "arbitre_bras_s": snappedf(bras_a, 0.01), "arbitre_m": snappedf(sol(arbitre.position, point), 0.01)}
	# 5. Coupe vers la transformation (comme la régie) : places de la loi 8, joueurs libérés.
	var moteur := transformation_moteur(essai, 0, 40.0, "0-14", "[61,\"essai\",\"try\"]:transformation")
	var loi := ApresEssai.transformation(moteur)
	var pret := ApresEssai.elan(loi, ApresEssai.ELAN)
	pret.key = str(loi.key) + ":pret"
	view.apply_frame(image(pret, true))
	view.apply_frame(image(pret))
	view._process(STEP)
	check(not gestes.active() and gestes.cast.is_empty(), "La transformation libère tous les joueurs")
	var derriere_ligne := 0
	var derriere_ballon := 0
	var marque: Vector3 = view._world(loi.origin)
	for id: String in view._actors:
		var at: Vector3 = (view._actors[id].node as Node3D).position
		if int(view._actors[id].side) == 1 and at.x > 50.0: derriere_ligne += 1
		if int(view._actors[id].side) == 0 and id != "0-14" and at.x < marque.x - 1.0: derriere_ballon += 1
	check(derriere_ligne == 15, "Transformation : défenseurs derrière leur ligne de but (%d)" % derriere_ligne)
	check(derriere_ballon == 14, "Transformation : l'équipe du buteur derrière le ballon (%d)" % derriere_ballon)
	arbitre.queue_free()
	view.queue_free()
	await process_frame


## Le point est dans l'image (en pixels), entre `haut` et `bas` (parts de la hauteur), devant la caméra.
func dans_le_champ(view, point: Vector3, haut: float = 0.0, bas: float = 1.0) -> bool:
	var camera: Camera3D = view._camera
	if not camera.is_position_in_frustum(point) or camera.is_position_behind(point):
		return false
	var ecran := Vector2(view.get_viewport().get_visible_rect().size)
	var p := camera.unproject_position(point)
	return p.x >= 0.0 and p.x <= ecran.x and p.y >= haut * ecran.y and p.y <= bas * ecran.y


## Tir au but filmé dans l'axe. `essai_y` : transformation d'un essai en ce point ; `penalite` : marque
## d'une pénalité tentée (repère du moteur), sinon Vector2.INF.
func tir_dans_l_axe(nom: String, mode: String, camp: int, essai_y: float, penalite: Vector2) -> void:
	var view = nouvelle_vue()
	await process_frame
	view.set_camera(mode)
	var cadrage = Cadrage.new(view)
	view.set_cadrage(cadrage)
	var buteur := "%d-14" % camp
	var liste := joueurs("", Vector2.ZERO)
	if camp == 1:
		for joueur: Dictionary in liste:
			joueur.side = 1 - int(joueur.side)
			joueur.x = 100.0 - float(joueur.x)
			joueur.id = "%d-%d" % [int(joueur.side), int(joueur.slot)]
	var tir: Dictionary
	if penalite.is_finite():
		tir = scene("goal", "[70,\"penalite\",\"goal\"]", liste, Vector2(ApresEssai.but_x(camp), 35.0), penalite, camp)
		for joueur: Dictionary in tir.players:
			joueur.featured = str(joueur.id) == buteur
			if str(joueur.id) == buteur:
				joueur.x = penalite.x
				joueur.y = penalite.y
	else:
		tir = ApresEssai.transformation(transformation_moteur(liste, camp, essai_y, buteur, "[70,\"transformation\",\"goal\"]"))
	cadrage.regler(true, "goal" if penalite.is_finite() else "transformation")
	cadrage.couvrir(COUVERT_HAUT, COUVERT_BAS)
	# Pose « prêt » (coupe), comme la régie : buteur posé derrière le ballon.
	var pret := ApresEssai.elan(tir, ApresEssai.ELAN)
	pret.key = str(tir.key) + ":pret"
	view.apply_frame(image(pret, true))
	view.apply_frame(image(pret))
	cadrage.couper()
	var marque: Vector3 = view._world(tir.origin)
	var poteaux_x := ApresEssai.poteaux_x(tir) - 50.0
	cadrage.viser_poteaux(marque, poteaux_x, buteur)
	for k in 20: view._process(STEP)
	check(cadrage.dans_l_axe(), "%s : caméra dans l'axe" % nom)
	var camera: Camera3D = view._camera
	var pied: Vector3 = (view._actors[buteur].node as Node3D).position
	var axe := Vector3(marque.x - poteaux_x, 0.0, marque.z).normalized()
	var recul := (camera.global_position - pied).dot(axe)
	check(recul > 1.0 and sol(camera.global_position, marque + axe * (camera.global_position - marque).dot(axe)) < 0.5, "%s : caméra derrière le buteur, dans l'axe des poteaux (%.1f m derrière)" % [nom, recul])
	check(camera.global_position.y > 1.5 and camera.global_position.y < 8.0, "%s : caméra un peu en hauteur (%.1f m)" % [nom, camera.global_position.y])
	check(absf(camera.global_position.x) <= Cadrage.TIR_BORNE.x + 0.01 and absf(camera.global_position.z) <= Cadrage.TIR_BORNE.y + 0.01, "%s : caméra hors des tribunes (%s)" % [nom, str(camera.global_position)])
	var visibles := {"buteur (pieds)": pied + Vector3.UP * 0.1, "buteur (tête)": pied + Vector3.UP * 1.8, "ballon": view._ball.global_position}
	for z: float in [-View.POTEAUX_Z, View.POTEAUX_Z]:
		visibles["pied du montant %+.1f" % z] = Vector3(poteaux_x, 0.3, z)
		visibles["barre %+.1f" % z] = Vector3(poteaux_x, View.BARRE_Y, z)
	for libelle: String in visibles:
		check(dans_le_champ(view, visibles[libelle], COUVERT_HAUT, 1.0 - COUVERT_BAS), "%s : %s à l'image, hors du bandeau et de la légende" % [nom, libelle])
	# Élan puis frappe : le buteur s'élance, le ballon vole vers les perches.
	var elan := ApresEssai.elan(tir, ApresEssai.FRAPPE)
	elan.key = pret.key
	for k in 18:
		if k == 0: view.apply_frame(image(elan))
		view._process(STEP)
	view.apply_frame(image(tir))
	var duree: float = view.duree_vol()
	check(duree >= 0.6 and duree <= 1.2, "%s : vol de %.2f s" % [nom, duree])
	var hors_champ := 0
	var poteaux_hors := 0
	var a_la_ligne := -1.0
	var precedent: Vector3 = view._ball.global_position
	var images := 0
	var t := 0.0
	while t < duree + 0.4:
		view._process(STEP)
		t += STEP
		images += 1
		if images == 1:
			check(cadrage.dans_l_axe(), "%s : caméra dans l'axe pendant le vol" % nom)
		var ballon: Vector3 = view._ball.global_position
		if not dans_le_champ(view, ballon): hors_champ += 1
		for z: float in [-View.POTEAUX_Z, View.POTEAUX_Z]:
			if not dans_le_champ(view, Vector3(poteaux_x, 0.3, z)): poteaux_hors += 1
		if (precedent.x - poteaux_x) * (ballon.x - poteaux_x) <= 0.0 and a_la_ligne < 0.0: a_la_ligne = ballon.y
		precedent = ballon
	check(hors_champ == 0, "%s : le ballon reste à l'image pendant tout le vol (%d images dehors sur %d)" % [nom, hors_champ, images])
	check(poteaux_hors == 0, "%s : les deux poteaux restent à l'image pendant le vol (%d)" % [nom, poteaux_hors])
	check(a_la_ligne > View.BARRE_Y, "%s : le ballon passe au-dessus de la barre (%.2f m)" % [nom, a_la_ligne])
	mesures[nom] = {"recul_m": snappedf(recul, 0.01), "camera": [snappedf(camera.global_position.x, 0.1), snappedf(camera.global_position.y, 0.1), snappedf(camera.global_position.z, 0.1)],
		"vol_s": snappedf(duree, 0.01), "ballon_ligne_m": snappedf(a_la_ligne, 0.01)}
	# Plan suivant : retour à la caméra de la tribune, d'une coupe.
	cadrage.regler(true, "kickoff")
	view._process(STEP)
	check(not cadrage.dans_l_axe(), "%s : le plan suivant quitte l'axe" % nom)
	view.queue_free()
	await process_frame
