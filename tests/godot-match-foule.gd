extends SceneTree
## Foule qui réagit et clameur qui monte (19/11/2026) : intensité d'ambiance qui enfle dans les 22 m
## et culmine à l'essai, part du public debout qui augmente sur un essai (surtout côté du club qui
## marque), coût borné (quatre lots de spectateurs, aucun nœud ajouté par l'animation), trace du son
## pour le match filmé (etat_foule).

const Foule = preload("res://match_foule.gd")
const View = preload("res://match_view.gd")

var failures: Array[String] = []
var checks := 0
var proof := OS.get_environment("CD_FOULE_PROOF")


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)


func scene(kind: String, possession: int, x: float, key: String, extra: Dictionary = {}) -> Dictionary:
	var s := {"kind": kind, "possession": possession, "ball": {"x": x, "y": 35.0}, "key": key}
	s.merge(extra, true)
	return s


func live(s: Dictionary, players: Array = []) -> Dictionary:
	var l := {"paused": false, "finished": false, "atBreak": false, "scene": s.duplicate(true), "teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}]}
	if not players.is_empty():
		l.scene["players"] = players
	return l


func step(foule: Foule, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		foule.avancer(0.05)
		t += 0.05


func check_model() -> void:
	var foule := Foule.new()
	var essais: Array[int] = []
	var arrets: Array[String] = []
	foule.essai.connect(func(camp: int): essais.append(camp))
	foule.arret.connect(func(kind: String): arrets.append(kind))
	# Milieu de terrain : rumeur du repos.
	foule.observer(live(scene("carry", 0, 50.0, "a")))
	step(foule, 3.0)
	var repos := foule.intensite
	check(absf(repos - Foule.CALME) < 0.01, "Milieu de terrain : rumeur du repos (%.3f)" % repos)
	check(foule.part_debout() < 0.05, "Au repos, presque tout le public est assis")
	# Domicile (attaque vers x = 100) dans les 22 m adverses : la clameur enfle.
	foule.observer(live(scene("carry", 0, 80.0, "b")))
	check(foule.camp_offensif == 0, "Entrée dans les 22 m du domicile reconnue")
	step(foule, 2.0)
	var dans_22 := foule.intensite
	check(dans_22 >= Foule.ENTREE_22 - 0.01 and dans_22 > repos + 0.2, "Dans les 22 m : intensité qui monte (%.3f)" % dans_22)
	# Extérieur à x = 80 : dans son propre camp, pas dans les 22 adverses.
	var autre := Foule.new()
	autre.observer(live(scene("carry", 1, 80.0, "x")))
	check(autre.camp_offensif == -1 and is_equal_approx(autre.cible, Foule.CALME), "Extérieur à x = 80 : loin de l'en-but adverse")
	autre.observer(live(scene("carry", 1, 15.0, "y")))
	check(autre.camp_offensif == 1, "Extérieur à x = 15 : dans les 22 m adverses")
	# Près de la ligne : plus fort encore.
	foule.observer(live(scene("ruck", 0, 97.0, "c")))
	step(foule, 1.5)
	var ligne := foule.intensite
	check(ligne > dans_22 + 0.1 and ligne <= Foule.LIGNE + 0.001, "À la ligne : intensité plus haute (%.3f)" % ligne)
	var debout_avant := foule.part_debout()
	var supporters_avant := foule.debout[0]
	check(supporters_avant > foule.debout[1], "Dans les 22 m, les supporters de l'attaque se lèvent les premiers")
	# Essai du domicile : pic, signal unique, lever massif côté domicile.
	foule.observer(live(scene("try", 0, 101.0, "d", {"team": 0})))
	foule.observer(live(scene("try", 0, 101.0, "d", {"team": 0})))
	check(essais == [0], "Un seul essai signalé pour la même image (%s)" % str(essais))
	step(foule, 1.0)
	var pic := foule.intensite
	check(pic >= Foule.ESSAI - 0.001 and pic > ligne, "Essai : intensité au sommet (%.3f)" % pic)
	step(foule, 1.5)
	var debout_essai := foule.part_debout()
	check(debout_essai > debout_avant + 0.3, "Essai : la part debout augmente (%.2f -> %.2f)" % [debout_avant, debout_essai])
	check(foule.debout[0] >= 0.85 and foule.debout[1] <= 0.1, "Essai du domicile : ses supporters debout, ceux d'en face assis")
	check(foule.bras[0] > 0.5, "Essai : bras et écharpes levés côté domicile")
	# Retombée après l'essai (remise en jeu au centre).
	foule.observer(live(scene("kickoff", 1, 50.0, "e")))
	step(foule, 8.0)
	check(foule.intensite < pic - 0.4 and foule.intensite > Foule.CALME - 0.001, "Après l'essai, la clameur retombe (%.3f)" % foule.intensite)
	step(foule, 6.0)
	check(foule.part_debout() < 0.1, "Le public se rassoit")
	# Essai de l'extérieur : ses supporters se lèvent.
	foule.observer(live(scene("try", 1, -1.0, "f", {"team": 1})))
	step(foule, 2.5)
	check(essais == [0, 1] and foule.debout[1] >= 0.85 and foule.debout[0] <= 0.1, "Essai de l'extérieur : bloc visiteur debout, domicile assis")
	# Arrêts de jeu : un sifflet par arrêt, pas à chaque image d'une même phase arrêtée.
	arrets.clear()
	step(foule, 3.0)
	foule.observer(live(scene("carry", 0, 50.0, "g")))
	foule.observer(live(scene("penalty", 0, 50.0, "h")))
	foule.observer(live(scene("penalty", 0, 50.0, "h")))
	check(arrets == ["penalty"], "Pénalité : un arrêt signalé (%s)" % str(arrets))
	step(foule, 2.0)
	foule.observer(live(scene("carry", 1, 50.0, "i")))
	foule.observer(live(scene("scrum", 1, 50.0, "j")))
	check(arrets == ["penalty", "scrum"], "Mêlée : nouvel arrêt signalé (%s)" % str(arrets))
	# Plan d'essai reçu avant la course (film du 19/11 : public debout 7 s avant l'aplati, rassis
	# au moment de l'essai) : il monte comme près de la ligne, puis explose à l'aplati montré.
	var attente := Foule.new()
	attente.repartition = [0.62, 0.1, 0.28]
	step(attente, 3.0)
	attente.essai_suspendu = true
	attente.observer(live(scene("try", 0, 101.0, "k", {"team": 0})))
	step(attente, 6.0)
	check(attente.essai_restant >= Foule.TENUE_ESSAI - 0.001, "Course vers l'en-but : la fête de l'essai n'est pas entamée (%.2f s)" % attente.essai_restant)
	check(attente.intensite <= Foule.LIGNE + 0.001 and attente.debout[0] <= Foule.DEBOUT_22 + 0.001, "Course vers l'en-but : le public monte sans exploser (%.2f, %.2f debout)" % [attente.intensite, attente.debout[0]])
	attente.essai_suspendu = false
	step(attente, 2.0)
	check(attente.debout[0] >= 0.85 and attente.intensite >= Foule.ESSAI - 0.001, "Aplati montré : le public se lève (%.2f)" % attente.debout[0])
	var bornee := Foule.new()
	bornee.essai_suspendu = true
	bornee.observer(live(scene("try", 1, -1.0, "l", {"team": 1})))
	step(bornee, Foule.SUSPENSION_MAX + 2.5)
	check(bornee.debout[1] >= 0.85, "Attente de l'aplati bornée : l'essai finit par être fêté (%.2f)" % bornee.debout[1])


func fixture_players() -> Array:
	var players: Array = []
	for side in 2:
		for slot in 15:
			players.append({"id": "%d-%d" % [side, slot], "side": side, "slot": slot, "x": 34.0 + side * 21.0 + (slot % 3) * 2.5, "y": 7.0 + slot * 4.0})
	return players


func spectators(view: Node) -> Array[MultiMeshInstance3D]:
	var lots: Array[MultiMeshInstance3D] = []
	for child in view.get_children():
		if child is MultiMeshInstance3D and str(child.name).begins_with("Spectators"):
			lots.append(child)
	return lots


func check_view() -> void:
	var view: NativeMatchView = View.new()
	root.add_child(view)
	view.set_process(false)
	var lots := spectators(view)
	# Coût : quatre lots (torse, tête, jambes, bras) au lieu de trois, rien par spectateur.
	check(lots.size() == 4, "Quatre lots de spectateurs (%d)" % lots.size())
	var compte: Dictionary = view.foule_compte
	var total: int = int(compte.total)
	check(total > 1500, "Tribunes garnies (%d spectateurs)" % total)
	for lot in lots:
		check(lot.multimesh.instance_count == total and lot.multimesh.use_custom_data, lot.name + " : un spectateur par instance, données d'animation")
		check(lot.material_override is ShaderMaterial and (lot.material_override as ShaderMaterial).shader.resource_path == View.FOULE_SHADER, lot.name + " : matière animée")
		check(lot.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, lot.name + " : sans ombre")
	if not lots.is_empty():
		# Le pilote factice (--headless) peut ne pas analyser les shaders : la liste n'est vérifiée que si elle existe.
		var uniformes: Array = (lots[0].material_override as ShaderMaterial).shader.get_shader_uniform_list().map(func(u: Dictionary) -> String: return str(u.name))
		check(uniformes.is_empty() or ("debout" in uniformes and "bras" in uniformes and "couleur_domicile" in uniformes), "Shader du public lisible (%s)" % str(uniformes))
	var tenues: int = int(compte.tenues)
	var domicile: int = int(compte.domicile)
	var visiteurs: int = int(compte.visiteurs)
	check(domicile + visiteurs + int(compte.neutres) == total, "Chaque spectateur a sa tribu")
	check(tenues > total * 0.2 and tenues < total * 0.6, "Maillots et écharpes aux couleurs des clubs dans la masse (%d / %d)" % [tenues, total])
	check(domicile > total * 0.45 and visiteurs > total * 0.03 and domicile > visiteurs * 3, "Surtout le club qui reçoit (%d domicile, %d visiteurs)" % [domicile, visiteurs])
	var players := fixture_players()
	view.apply_frame(live(scene("carry", 0, 50.0, "v1"), players))
	for k in 40: view._process(0.05)
	var repos: float = view.foule.part_debout()
	view.apply_frame(live(scene("carry", 0, 85.0, "v2"), players))
	for k in 40: view._process(0.05)
	var dans_22: float = view.foule.intensite
	check(dans_22 > Foule.ENTREE_22 - 0.01, "Vue : la foule s'anime dans les 22 m (%.3f)" % dans_22)
	view.apply_frame(live(scene("try", 0, 101.0, "v3", {"team": 0}), players))
	for k in 50: view._process(0.05)
	var debout: float = view.foule.part_debout()
	check(debout > repos + 0.3, "Vue : la part debout augmente sur l'essai (%.2f -> %.2f)" % [repos, debout])
	var matiere: ShaderMaterial = null
	if not lots.is_empty():
		matiere = lots[0].material_override as ShaderMaterial
	var vu: Variant = matiere.get_shader_parameter("debout") if matiere != null else null
	check(vu is Vector3 and is_equal_approx((vu as Vector3).x, view.foule.debout[0]), "Vue : le shader reçoit la part debout du domicile")
	check(matiere != null and matiere.get_shader_parameter("couleur_domicile") == Color("#a12f41"), "Vue : couleurs du club qui reçoit dans la tribune")
	# Coût : l'animation du public ne crée aucun nœud (un réglage de quatre matières par image).
	var enfants := view.get_child_count()
	for k in 200: view._animer_foule(1.0 / 60.0)
	check(view.get_child_count() == enfants and spectators(view).size() == 4, "Animation sans nœud ajouté (%d -> %d)" % [enfants, view.get_child_count()])
	view.queue_free()


func check_sound() -> void:
	if proof.is_empty():
		check(false, "CD_FOULE_PROOF absent")
		return
	var directory := proof.path_join("profil")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("sound.json"), FileAccess.WRITE)
	file.store_string('{"version":1,"interface_volume":35,"stadium_volume":25,"match_sounds":true}')
	file.close()
	var app := Control.new()
	root.add_child(app)
	var audio = load("res://audio/soundscape.gd").new()
	app.add_child(audio)
	audio.set_process(false)
	check(audio.setup(app) and audio.load_profile(directory), "Gestionnaire sonore prêt")
	audio.refresh_visibility("Match", true)
	audio.set_presenting(true)
	var foule := Foule.new()
	audio.suivre_foule(foule)
	check(audio.foule_active() == foule, "La clameur suit la foule de la vue")
	foule.observer(live(scene("carry", 0, 50.0, "s1")))
	for k in 40:
		foule.avancer(0.05)
		audio._process(0.05)
	var gain_repos: float = audio._clameur_gain
	foule.observer(live(scene("carry", 0, 90.0, "s2")))
	for k in 40:
		foule.avancer(0.05)
		audio._process(0.05)
	var gain_22: float = audio._clameur_gain
	foule.observer(live(scene("try", 0, 101.0, "s3", {"team": 0})))
	audio.play_shown("try", 0)
	for k in 30:
		foule.avancer(0.05)
		audio._process(0.05)
	var gain_essai: float = audio._clameur_gain
	check(gain_repos < 0.05 and gain_22 > gain_repos + 0.1 and gain_essai > gain_22, "Clameur : repos %.2f < 22 m %.2f < essai %.2f" % [gain_repos, gain_22, gain_essai])
	check(is_equal_approx(db_to_linear(audio._bed.volume_db), 1.0), "Ambiance d'origine inchangée")
	var etat: Dictionary = audio.etat_foule()
	check(float(etat.intensite) >= 0.99 and float(etat.debout) > 30.0, "Trace : intensité et part debout (%s)" % str(etat))
	check("stadium-try" in etat.sons, "Trace : réaction d'essai notée (%s)" % str(etat.sons))
	check((audio.etat_foule().sons as Array).is_empty(), "Trace vidée après lecture")
	foule.observer(live(scene("carry", 1, 50.0, "s4")))
	for k in 40: foule.avancer(0.05)
	foule.observer(live(scene("penalty", 1, 50.0, "s5")))
	var attendu := "sifflet-arbitre" if audio._streams.has("referee-whistle") else "arret-sans-sifflet"
	check(attendu in audio.etat_foule().sons, "Arrêt de jeu noté : " + attendu)
	# Foule oubliée hors match : retour à celle du direct d'origine.
	audio.observe_model({"club": {"id": 0}, "meta": {"dataDir": directory}}, "Bureau")
	check(audio.foule_active() != foule, "Hors match, la foule de la vue n'est plus suivie")
	var pending: Array[WeakRef] = []
	for player in [audio._ui, audio._bed, audio._reaction, audio._clameur, audio._sifflet]:
		if player.playing:
			pending.append(weakref(player.get_stream_playback()))
	audio.dispose()
	app.queue_free()
	await process_frame
	var deadline := Time.get_ticks_msec() + 500
	for playback in pending:
		while playback.get_ref() != null and Time.get_ticks_msec() < deadline:
			await process_frame


func run() -> void:
	check_model()
	check_view()
	await check_sound()
	await process_frame
	print("MATCH_FOULE ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
