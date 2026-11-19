extends SceneTree
## Ralenti de l'essai (19 novembre 2026), sans moteur ni carrière, sans bibliothèque d'animations :
##  1. réglages : ralenti à environ la moitié de la vitesse réelle, au plus REJEU_MAX s ajoutées,
##     seulement pour un temps fort avec un essai, jamais avec les animations réduites ;
##  2. angle du ralenti : caméra basse (au ras de la pelouse) sur le côté du ballon, jamais dans une
##     tribune ni collée à un montant, autre angle que la vue TV ;
##  3. mention « RALENTI » : discrète, en haut à droite, sous le score et les commandes, transparente
##     à la souris, cachée au départ ;
##  4. vue 3D : un essai couru puis plongé (0-11, 15 m) ; la vue enregistre, l'essai est repéré à
##     l'aplati, la célébration se joue, puis le ralenti rejoue la course et l'aplati à ~0,5 sous la
##     caméra basse, vue suspendue (célébration et arbitre figés) ; à la fin, l'état exact d'avant est
##     remis (poses, ballon, caméra), un seul ralenti par essai ; abrégé, il remet aussi l'état d'avant.
## Coordonnées de test (repère du moteur : x de 0 à 100, y de 0 à 70), jamais un vrai match.

const View = preload("res://match_view.gd")
const Gestes = preload("res://match_gestes.gd")
const Cadrage = preload("res://match_cadrage.gd")
const Arbitre = preload("res://match_arbitre.gd")
const Rejeu = preload("res://match_rejeu.gd")
const Regie = preload("res://ui/contextual/match_temps_forts.gd")
const STEP := 1.0 / 30.0

var failures: Array[String] = []
var checks := 0
var mesures := {}
var fins := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)


func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	reglages()
	angle()
	await mention()
	await ralenti_complet()
	await ralenti_abrege()
	await sans_enregistrement()
	print("MATCH_RALENTI_ESSAI ", JSON.stringify(mesures))
	print("MATCH_RALENTI_ESSAI_CHECKS %d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)


## 1. Vitesse, durée, déclenchement.
func reglages() -> void:
	check(Rejeu.VITESSE >= 0.4 and Rejeu.VITESSE <= 0.6, "Ralenti à environ la moitié de la vitesse réelle (%.2f)" % Rejeu.VITESSE)
	var ajoute := (Rejeu.AVANT + Rejeu.APRES) / Rejeu.VITESSE
	check(ajoute <= Regie.REJEU_MAX + 0.001 and ajoute >= 2.5, "Ralenti de %.1f s au plus (%.1f s ajoutées)" % [Regie.REJEU_MAX, ajoute])
	check(Rejeu.AVANT >= 1.2 and Rejeu.APRES > 0.0, "Il montre la fin de la course jusqu'à l'aplati (%.1f s avant, %.1f s après)" % [Rejeu.AVANT, Rejeu.APRES])
	var essai := [{"kind": "carry"}, {"kind": "try"}, {"kind": "transformation"}]
	check(Regie.rejeu_voulu(essai, false), "Temps fort avec un essai : la vue enregistre pour le ralenti")
	check(not Regie.rejeu_voulu([{"kind": "carry"}, {"kind": "penalty"}, {"kind": "goal"}], false), "Sans essai : aucun ralenti (pas pour chaque action)")
	check(not Regie.rejeu_voulu(essai, true), "Animations réduites : aucun ralenti")
	check(not Regie.rejeu_voulu([], false), "Temps fort vide : aucun ralenti")


## 2. Caméra du ralenti, pour des essais partout le long des deux lignes.
func angle() -> void:
	var cas := 0
	var hors := 0
	var hauts := 0
	var poteaux := 0
	var loins := 0
	for sens: float in [1.0, -1.0]:
		for z: float in [-34.0, -20.0, -2.8, 0.0, 2.8, 15.0, 27.0, 34.0]:
			for profondeur: float in [-3.0, 0.5, 4.0, 9.0]:
				var ballon := Vector3(sens * (50.0 + profondeur), 0.3, z)
				var cote := Cadrage.cote_rejeu(ballon)
				var plan: Dictionary = Cadrage.plan_rejeu(ballon, cote)
				var camera: Vector3 = plan.camera
				cas += 1
				if absf(camera.x) > Cadrage.REJEU_BORNE.x + 0.001 or absf(camera.z) > Cadrage.REJEU_BORNE.y + 0.001: hors += 1
				if camera.y > 2.0 or camera.y < 0.5: hauts += 1
				for pz: float in [-Cadrage.POTEAUX_Z, Cadrage.POTEAUX_Z]:
					if Vector2(camera.x - sens * 50.0, camera.z - pz).length() < Cadrage.REJEU_POTEAU - 0.001: poteaux += 1
				var ecart := Vector2(camera.x - ballon.x, camera.z - ballon.z).length()
				if ecart < 6.0 or ecart > 16.0: loins += 1
	check(hors == 0, "Caméra du ralenti jamais dans un panneau ni une tribune (%d cas sur %d)" % [hors, cas])
	check(hauts == 0, "Caméra du ralenti au ras de la pelouse, entre 0,5 et 2 m (%d cas hors)" % hauts)
	check(poteaux == 0, "Caméra du ralenti jamais collée à un montant (%d cas)" % poteaux)
	check(loins == 0, "Caméra du ralenti de 6 à 16 m du ballon (%d cas hors)" % loins)
	# Côté de la tribune principale, sauf ballon contre la touche proche.
	check(Cadrage.cote_rejeu(Vector3(50.0, 0.0, 0.0)).y > 0.0 and Cadrage.cote_rejeu(Vector3(50.0, 0.0, 33.0)).y < 0.0, "Côté de la tribune principale, contrechamp près de la touche proche")
	check(Cadrage.cote_rejeu(Vector3(51.0, 0.0, 0.0)).x > 0.0 and Cadrage.cote_rejeu(Vector3(-51.0, 0.0, 0.0)).x < 0.0, "Sens de l'en-but de l'essai")
	# Défenseurs alignés sur la ligne d'en-but entre la caméra par défaut et le marqueur (match filmé
	# du 19/11 : un dos plein écran à l'aplati) : l'angle par défaut est gêné, un autre retrait non.
	var aplati := Vector3(51.0, 0.3, 0.0)
	var ligne := PackedVector3Array()
	for k in 6: ligne.append(Vector3(50.0, 0.0, 2.0 + 1.6 * k))
	var cote_aplati := Cadrage.cote_rejeu(aplati)
	var gene_defaut := Cadrage.gene_rejeu(Cadrage.plan_rejeu(aplati, cote_aplati), ligne)
	var gene_autre := INF
	for retrait: float in Rejeu.RETRAITS:
		for lateral: float in [1.0, -1.0]:
			gene_autre = minf(gene_autre, Cadrage.gene_rejeu(Cadrage.plan_rejeu(aplati, Vector2(cote_aplati.x, lateral), retrait), ligne))
	check(gene_defaut > 1.0 and gene_autre < 0.2, "Ralenti : un angle sans défenseur entre caméra et marqueur existe (gêne %.2f → %.2f)" % [gene_defaut, gene_autre])
	check(Cadrage.gene_rejeu(Cadrage.plan_rejeu(aplati, cote_aplati), PackedVector3Array()) == 0.0, "Ralenti : gêne nulle sans personne autour")
	# Pied de poteau (19/11/2026) : essai au pied des poteaux, l'angle par défaut aligne un montant entre
	# la caméra et le marqueur ; l'angle retenu l'évite.
	var vide: Array = []
	for k in 20: vide.append(pose_test(k * 0.1, aplati, {}))
	var poteau_defaut := Cadrage.gene_poteaux(Cadrage.plan_rejeu(aplati, cote_aplati))
	var choix: Dictionary = Rejeu.meilleur_angle(vide, 0.0, cote_aplati)
	var poteau_choisi := Cadrage.gene_poteaux(Cadrage.plan_rejeu(aplati, choix.cote, choix.retrait))
	check(poteau_defaut > 0.3 and poteau_choisi < poteau_defaut * 0.5, "Ralenti : pas de montant au premier plan (gêne %.2f → %.2f)" % [poteau_defaut, poteau_choisi])
	# Défenseur au premier plan au DÉBUT du ralenti (puis parti) : toute la fenêtre rejouée compte, pas
	# seulement la fin (avant le 19/11, seule la dernière 0,8 s était jugée et l'angle par défaut restait).
	var loin_poteaux := Vector3(51.0, 0.3, -15.0)
	var cote_loin := Cadrage.cote_rejeu(loin_poteaux)
	var defaut_plan: Dictionary = Cadrage.plan_rejeu(loin_poteaux, cote_loin)
	var devant: Vector3 = (defaut_plan.camera as Vector3).lerp(loin_poteaux, 0.3)
	devant.y = 0.0
	var clip_test: Array = []
	for k in 20:
		var t := k * 0.1
		clip_test.append(pose_test(t, loin_poteaux, {"d": devant if t < 0.7 else Vector3(10.0, 0.0, 30.0)}))
	var choix_debut: Dictionary = Rejeu.meilleur_angle(clip_test, 1.6 - Rejeu.AVANT, cote_loin)
	check(not (choix_debut.cote == cote_loin and is_equal_approx(float(choix_debut.retrait), Cadrage.REJEU_RETRAIT)), "Ralenti : un défenseur au premier plan en début de ralenti écarte l'angle par défaut")


## Pose du tampon du ralenti (format de match_rejeu.gd) : ballon et joueurs visibles.
func pose_test(t: float, ballon: Vector3, joueurs: Dictionary) -> Dictionary:
	var e := {}
	for cle: String in joueurs: e[cle] = [Transform3D(Basis(), joueurs[cle]), null, true]
	return {"t": t, "e": e, "b": [Transform3D(Basis(), ballon), true]}


## 3. Mention « RALENTI » : discrète, en haut à droite de la zone libre.
func mention() -> void:
	var cadre: PanelContainer = Regie.construire_mention()
	root.add_child(cadre)
	check(cadre.mouse_filter == Control.MOUSE_FILTER_IGNORE and not cadre.visible, "Mention cachée au départ, transparente à la souris")
	var titre: Label = cadre.find_child("MatchRalentiTitre", true, false)
	check(titre != null and titre.text == "RALENTI", "Mention « RALENTI »")
	for hauteur: float in [720.0, 1080.0]:
		var k := hauteur / 720.0
		var largeur := 1280.0 * k
		if titre != null: titre.add_theme_font_size_override("font_size", Regie.taille_mention(hauteur))
		cadre.show()
		cadre.reset_size()
		await process_frame
		var taille := cadre.size
		var ecran := Vector2(largeur, hauteur)
		# Mesures de la vue en 720p (comme godot-match-grands-moments.gd) : score en haut à gauche,
		# zone libre sous le score et la bande de commandes.
		var score := Rect2(Vector2(18, 18) * k, Vector2(486, 65) * k)
		var haut_libre := 125.0 * k
		var rect := Rect2(Regie.place_mention(ecran, taille, haut_libre), taille)
		check(Rect2(Vector2.ZERO, ecran).encloses(rect), "%d p : mention entière dans l'image (%s)" % [int(hauteur), str(rect)])
		check(rect.position.x >= largeur * 0.75 and rect.end.y <= hauteur * 0.3, "%d p : mention dans le coin haut droit (%s)" % [int(hauteur), str(rect)])
		check(rect.position.y >= haut_libre and not rect.intersects(score), "%d p : sous le score et les commandes, sans les recouvrir (%s)" % [int(hauteur), str(rect)])
		check(taille.x <= largeur * 0.16 and taille.y <= hauteur * 0.08, "%d p : mention discrète (%s)" % [int(hauteur), str(taille)])
		check(Regie.taille_mention(hauteur) >= 16 and Regie.taille_mention(hauteur) < Regie.tailles_bandeau(hauteur).titre, "%d p : texte lisible, plus petit que le titre « ESSAI »" % int(hauteur))
	cadre.queue_free()
	await process_frame


## Trente joueurs : le camp 0 attaque vers x = 100 (mêmes places que godot-match-apres-essai.gd).
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


func scene(kind: String, key: String, liste: Array, ballon: Vector2, origine: Vector2) -> Dictionary:
	return {"kind": kind, "key": key, "possession": 0, "team": 0, "players": liste,
		"ball": {"x": ballon.x, "y": ballon.y}, "origin": {"x": origine.x, "y": origine.y}}


func image(valeur: Dictionary, en_pause: bool = false) -> Dictionary:
	return {"scene": valeur, "teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}], "events": [], "paused": en_pause}


func sol(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func compter_fin() -> void:
	fins += 1


## Une image de la boucle de jeu : la vue, puis l'arbitre s'il n'est pas figé (comme le moteur Godot).
func image_de_jeu(view, arbitre) -> void:
	view._process(STEP)
	if arbitre.can_process(): arbitre._process(STEP)


## Essai du 0-11 joué comme en temps forts : enregistrement demandé, essai repéré à l'aplati, moment
## d'essai (ralenti de présentation puis image tenue) de ESSAI_MOMENT s. Rend [vue, arbitre, aplati].
func preparer_essai(enregistrer: bool) -> Array:
	var view = View.new()
	root.add_child(view)
	view.set_process(false)
	view.set_gestes(true)
	view.set_live_cadence(1)
	view.set_camera("tv")
	view.rejeu_fini.connect(compter_fin)
	await process_frame
	var marqueur := "0-11"
	view.apply_frame(image(scene("carry", "[60,\"course\",\"carry\"]", joueurs(marqueur, Vector2(85, 40)), Vector2(85, 40), Vector2(80, 40)), true))
	for k in 5: view._process(STEP)
	var arbitre = Arbitre.new(view)
	view.add_child(arbitre)
	check(arbitre.preparer(), "Arbitre habillé")
	arbitre.set_process(false)
	arbitre.placer(arbitre.place_de_jeu(view._ball.global_position), view._ball.global_position)
	view.inscrire_rejeu(arbitre, arbitre.model, arbitre.rig)
	# Début du temps fort (régie, _demarrer) : enregistrement seulement pour un temps fort avec un essai.
	view.enregistrer_rejeu(enregistrer)
	view.apply_frame(image(scene("try", "[61,\"essai\",\"try\"]", joueurs(marqueur, Vector2(100, 40)), Vector2(100, 40), Vector2(85, 40))))
	var gestes: RefCounted = view._gestes
	var horloge := 0.0
	while not view.essai_aplati() and horloge < 10.0:
		image_de_jeu(view, arbitre)
		horloge += STEP
	check(view.essai_aplati(), "L'essai est aplati à l'écran (%.1f s de course)" % horloge)
	# Régie, _celebrer_essai : la fenêtre du ralenti se cale sur l'aplati.
	var repere: bool = view.reperer_rejeu()
	check(repere == enregistrer, "Essai repéré pour le ralenti seulement si la vue enregistre (%s)" % str(repere))
	var aplati: Vector3 = (view._actors[marqueur].node as Node3D).position
	# Moment d'essai : ralenti de présentation de la régie, puis image tenue.
	var reste: float = Regie.ESSAI_MOMENT
	while reste > 0.0:
		reste = maxf(0.0, reste - STEP)
		view.set_ralenti(Regie.ralenti_essai(reste))
		image_de_jeu(view, arbitre)
	view.set_ralenti(1.0)
	check(gestes.active() or float(gestes.time) > 0.0, "La célébration est en cours quand le moment d'essai finit")
	return [view, arbitre, aplati]


## 4. Ralenti joué jusqu'au bout.
func ralenti_complet() -> void:
	fins = 0
	var prepare: Array = await preparer_essai(true)
	var view = prepare[0]
	var arbitre = prepare[1]
	var aplati: Vector3 = prepare[2]
	var marqueur := "0-11"
	var gestes: RefCounted = view._gestes
	var camera: Camera3D = view._camera
	# État d'avant le ralenti : celui que la célébration et la transformation doivent retrouver.
	var avant: Dictionary = view._rejeu.capturer()
	var camera_avant := camera.global_transform
	var fov_avant := camera.fov
	var temps_gestes := float(gestes.time)
	var arbitre_avant: Vector3 = arbitre.position
	var regard_tv := -camera_avant.basis.z
	check(camera_avant.origin.y > 5.0, "Vue TV en hauteur avant le ralenti (%.1f m)" % camera_avant.origin.y)
	check(view.commencer_rejeu(Rejeu.VITESSE), "Le ralenti part à la fin du moment d'essai")
	check(view.rejeu_actif(), "Ralenti en cours")
	var etat: Dictionary = view.rejeu_etat()
	var source := float(etat.duree_source)
	check(source >= Rejeu.AVANT + Rejeu.APRES - 0.2 and source <= Rejeu.AVANT + Rejeu.APRES + 0.1, "Fenêtre rejouée : %.2f s de jeu autour de l'aplati" % source)
	# Autre angle : caméra basse, regard rasant, différente de la vue TV.
	var regard := -camera.global_transform.basis.z
	check(camera.global_position.y < 2.0, "Caméra du ralenti au ras de la pelouse (%.2f m)" % camera.global_position.y)
	check(regard.angle_to(regard_tv) > deg_to_rad(15.0) and absf(regard.y) < 0.2, "Autre angle que la vue TV (%.0f° d'écart, regard rasant)" % rad_to_deg(regard.angle_to(regard_tv)))
	# Première image : la course, avant l'aplati.
	var debut_marqueur: Vector3 = (view._actors[marqueur].node as Node3D).position
	check(sol(debut_marqueur, aplati) > 3.0, "Le ralenti part de la course du marqueur (%.1f m avant l'aplati)" % sol(debut_marqueur, aplati))
	var pas := 0
	var vu_ballon := 0
	var dans_le_plan := 0
	var plus_bas := 0.0
	var max_hauteur := 0.0
	var arbitre_fige := true
	var gestes_figes := true
	var lecture_mi := -1.0
	while view.rejeu_actif() and pas < 600:
		# Image de la boucle de jeu : la vue (parent) avant l'arbitre (enfant) ; l'image où le ralenti
		# finit, l'état remis est comparé avant que l'arbitre ne reprenne sa propre mise à jour.
		view._process(STEP)
		pas += 1
		if not view.rejeu_actif(): break
		if arbitre.can_process():
			arbitre_fige = false
			arbitre._process(STEP)
		if absf(float(gestes.time) - temps_gestes) > 0.0001: gestes_figes = false
		max_hauteur = maxf(max_hauteur, camera.global_position.y)
		if view._ball.visible:
			vu_ballon += 1
			if camera.is_position_in_frustum(view._ball.global_position): dans_le_plan += 1
		if pas == 30: lecture_mi = float(view.rejeu_etat().lecture)
		plus_bas = maxf(plus_bas, sol((view._actors[marqueur].node as Node3D).position, debut_marqueur))
	var duree := pas * STEP
	mesures["ralenti"] = {"duree_s": snappedf(duree, 0.01), "source_s": snappedf(source, 0.01), "camera_m": snappedf(max_hauteur, 0.01), "ballon_dans_le_plan": "%d/%d" % [dans_le_plan, vu_ballon]}
	check(not view.rejeu_actif() and fins == 1, "Le ralenti se termine de lui-même, une seule fin signalée (%d)" % fins)
	check(duree <= Regie.REJEU_MAX + 2.0 * STEP and duree >= source / Rejeu.VITESSE - 2.0 * STEP, "Durée ajoutée : %.2f s (%.1f s au plus)" % [duree, Regie.REJEU_MAX])
	check(lecture_mi > 0.0 and absf(lecture_mi / (30.0 * STEP) - Rejeu.VITESSE) < 0.02, "Lu à %.2f de la vitesse réelle" % (lecture_mi / (30.0 * STEP)))
	check(max_hauteur < 2.0, "Caméra basse pendant tout le ralenti (%.2f m au plus)" % max_hauteur)
	check(vu_ballon > 0 and dans_le_plan >= int(vu_ballon * 0.9), "La caméra suit le ballon (%d images sur %d)" % [dans_le_plan, vu_ballon])
	check(plus_bas > 3.0, "Les joueurs rejouent l'action (le marqueur repart vers la ligne, %.1f m)" % plus_bas)
	check(gestes_figes, "Célébration suspendue pendant le ralenti (temps du geste inchangé)")
	check(arbitre_fige, "Arbitre figé pendant le ralenti (sa propre mise à jour ne tourne pas)")
	# État final identique à celui d'avant le ralenti.
	var apres: Dictionary = view._rejeu.capturer()
	var ecart := Rejeu.ecart(avant, apres)
	check(ecart < 0.0001, "État d'après identique à celui d'avant : poses, ballon (écart %.6f)" % minf(ecart, 999.0))
	check(camera.global_transform.is_equal_approx(camera_avant) and is_equal_approx(camera.fov, fov_avant), "Caméra TV remise telle quelle")
	check(is_equal_approx(float(gestes.time), temps_gestes) and arbitre.position.is_equal_approx(arbitre_avant) and arbitre.can_process(), "Célébration et arbitre reprennent où ils en étaient")
	check(float(view.rejeu_etat().ecart_restitution) < 0.0001, "La vue mesure elle-même un état remis identique")
	# Un ralenti par essai.
	check(not view.commencer_rejeu(Rejeu.VITESSE), "Un seul ralenti par essai")
	# La célébration reprend son cours.
	for k in 10: image_de_jeu(view, arbitre)
	check(float(gestes.time) > temps_gestes + 0.2, "La célébration reprend après le ralenti (%.2f s de plus)" % (float(gestes.time) - temps_gestes))
	view.queue_free()
	await process_frame


## Abrégé (Échap, Entrée, Espace, clic : régie `passer`) : la vue normale reprend aussitôt, à l'identique.
func ralenti_abrege() -> void:
	fins = 0
	var prepare: Array = await preparer_essai(true)
	var view = prepare[0]
	var arbitre = prepare[1]
	var camera: Camera3D = view._camera
	var avant: Dictionary = view._rejeu.capturer()
	var camera_avant := camera.global_transform
	check(view.commencer_rejeu(Rejeu.VITESSE), "Second essai : le ralenti part")
	for k in 20: image_de_jeu(view, arbitre)
	check(view.rejeu_actif(), "Ralenti encore en cours avant d'être abrégé")
	view.finir_rejeu()
	check(not view.rejeu_actif() and fins == 1, "Ralenti abrégé, fin signalée une fois (%d)" % fins)
	check(Rejeu.ecart(avant, view._rejeu.capturer()) < 0.0001 and camera.global_transform.is_equal_approx(camera_avant), "Abrégé : état d'avant remis à l'identique")
	# Une nouvelle image de la régie pendant un ralenti le termine d'abord (aucun mélange d'états).
	view.queue_free()
	await process_frame
	fins = 0
	prepare = await preparer_essai(true)
	view = prepare[0]
	check(view.commencer_rejeu(Rejeu.VITESSE), "Troisième essai : le ralenti part")
	view.apply_frame(image(scene("goal", "[61,\"essai\",\"try\"]:transformation", joueurs("0-14", Vector2(100, 40)), Vector2(100, 40), Vector2(78, 40)), true))
	check(not view.rejeu_actif() and fins == 1, "Une nouvelle image termine le ralenti")
	view.queue_free()
	await process_frame


## Sans enregistrement (temps fort sans essai, animations réduites), en vue de dessus : pas de ralenti.
func sans_enregistrement() -> void:
	fins = 0
	var prepare: Array = await preparer_essai(false)
	var view = prepare[0]
	check(not view.commencer_rejeu(Rejeu.VITESSE) and not view.rejeu_actif(), "Sans enregistrement demandé : aucun ralenti")
	view.queue_free()
	await process_frame
	prepare = await preparer_essai(true)
	view = prepare[0]
	view.set_camera("tactical")
	check(not view.commencer_rejeu(Rejeu.VITESSE), "Vue de dessus : aucun ralenti")
	check(fins == 0, "Aucune fin signalée sans ralenti")
	view.queue_free()
	await process_frame
