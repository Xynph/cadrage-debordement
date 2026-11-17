extends SceneTree
## Météo et vent montrés au manager (profil Monde préparé par tests/godot-meteo-vent.cjs, jour de match) :
## écran Match avant le coup d'envoi (météo annoncée la veille, courrier « Bulletin météo »), vestiaire d'avant-match (météo, camp favorisé en 1re période, conseil du staff), bandeau du direct
## (camp favorisé par période) et mi-temps (changement de camp). La météo tirée par le moteur est remplacée,
## à l'écran seulement, par un grand vent orienté : le moteur est vérifié par tests/meteo-affichage-modele.cjs.
var app: Control
var director: Node
var sortie := OS.get_environment("CD_METEO_OUTPUT")
var echecs: Array[String] = []
var controles := 0
var textes := {}

func _initialize() -> void: call_deferred("executer")

func verifier(ok: bool, message: String) -> void:
	controles += 1
	if not ok:
		echecs.append(message)
		printerr("FAIL: ", message)

func poser(images := 8) -> void:
	for i in images: await process_frame

func attendre(commande: String) -> void:
	var limite := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < limite: await process_frame
	verifier(not app.waiting and app.bridge.last_response_ok, commande + " : réponse du vrai moteur " + str(app.last_error))
	if app.timer: app.timer.stop()
	await poser(12)

func demander(commande: String, payload := {}) -> void:
	app._command(commande, payload)
	await attendre(commande)

## `reposer` réapplique l'état montré juste avant la capture : le direct continue et renvoie le vrai modèle.
func capturer(nom: String, reposer := Callable()) -> void:
	await poser(10)
	if reposer.is_valid():
		reposer.call()
		await poser(2)
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join(nom + ".png")) == OK, "capture " + nom)

## Modèle reçu, avec à l'écran un grand vent dans le dos de l'équipe à domicile en 1re période.
func avec_vent(pause := false) -> Dictionary:
	var m: Dictionary = app.model.duplicate(true)
	m.live.meteo = {"libelle": "grand vent", "conseil": "Grand vent : le staff prévient que les tirs au but et le jeu au pied long deviennent aléatoires ; prenez les points faciles et jouez la touche.", "pluie": 0, "vent": 2, "chaleur": 0, "terrain": "souple", "ventDos": [0, 1]}
	if pause: m.live.atBreak = true
	return m

func talk() -> Dictionary:
	var v: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
	return v if v is Dictionary else {}

## Lignes du bloc météo de l'écran Match avant le coup d'envoi (section « LA MÉTÉO… » et ce qui la suit).
func lignes_meteo() -> Array:
	var ecran: Node = app.match_screen
	if not is_instance_valid(ecran): return []
	var section: Node = ecran.find_child("MeteoAvantMatch", true, false)
	if section == null: return []
	var lignes: Array = section.find_children("*", "Label", true, false).map(func(l: Label): return l.text)
	var parent := section.get_parent()
	for i in range(section.get_index() + 1, parent.get_child_count()):
		var suivant := parent.get_child(i)
		if suivant is Label: lignes.append(suivant.text)
		else: break
	return lignes

## Écran Match « AVANT-MATCH » le jour du match : météo annoncée la veille (vraie annonce du moteur), puis la
## même annonce en grand vent pour le camp favorisé en 1re période ; courrier « Bulletin météo » reçu la veille.
func avant_match() -> void:
	var annonce: Variant = app.model.get("next", {}).get("meteo")
	verifier(annonce is Dictionary, "prochain match : météo annoncée dans le modèle natif")
	var bulletin := (app.model.get("clubLife", {}).get("clubMail", {}).get("mails", []) as Array).filter(func(m): return m is Dictionary and m.get("type") == "meteo")
	verifier(bulletin.size() == 1 and str(bulletin[0].get("ecran")) == "Composition", "un courrier « Bulletin météo » avec un lien vers la composition")
	app._navigate("Match")
	await poser(6)
	if app.match_screen.tab == "Journal": app.match_screen._select_tab("Direct")
	await poser(4)
	var lignes := lignes_meteo()
	textes.ecran_match = lignes
	verifier(not lignes.is_empty() and str(lignes[0]).begins_with("LA MÉTÉO"), "écran Match : bloc météo « %s »" % str(lignes))
	if annonce is Dictionary:
		var ciel := str(annonce.get("libelle", ""))
		verifier(" ".join(lignes).to_lower().contains(ciel.to_lower()), "écran Match : ciel annoncé « %s »" % ciel)
	await capturer("meteo-ecran-match")
	var vent: Dictionary = app.model.duplicate(true)
	if vent.get("next") is Dictionary:
		vent.next.meteo = {"libelle": "grand vent", "conseil": "Grand vent : le staff prévient que les tirs au but et le jeu au pied long deviennent aléatoires ; prenez les points faciles et jouez la touche.", "pluie": 0, "vent": 2, "chaleur": 0, "terrain": "souple", "ventDos": [1, 0], "date": str(app.model.meta.get("calendarToday", ""))}
		app.match_screen.update_frame(vent)
		await poser(4)
		lignes = lignes_meteo()
		textes.ecran_match_vent = lignes
		var tout := " ".join(lignes)
		verifier(tout.contains("LA MÉTÉO DU MATCH") and tout.contains("Grand vent") and tout.contains("dans le dos de") and tout.contains("première période") and tout.contains("staff"), "écran Match : vent dans le dos en 1re période « %s »" % tout)
		await capturer("meteo-ecran-match-vent", func(): app.match_screen.update_frame(vent))
	app._navigate("Réception")
	await poser(6)

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	await attendre("ouverture")
	director = app.find_child("ContextualDirector", true, false)
	await avant_match()
	await demander("begin_match")
	verifier(app.model.get("live") is Dictionary and app.model.live.get("meteo") is Dictionary, "météo du direct dans le modèle natif")
	if director != null and director.view != null and director.view.has_method("_meteo") and not talk().is_empty():
		director.view.update_frame(avec_vent(), talk())
		await poser(6)
		var cadre: Node = director.view.find_child("TalkWeather", true, false)
		verifier(cadre != null, "vestiaire d'avant-match : cadre météo")
		if cadre != null:
			var lignes: Array = cadre.find_children("*", "Label", true, false).map(func(l: Label): return l.text)
			textes.avant = lignes
			verifier(" ".join(lignes).contains("GRAND VENT"), "avant-match : ciel nommé")
			verifier(" ".join(lignes).contains("dans le dos de") and " ".join(lignes).contains("première période"), "avant-match : camp favorisé en 1re période")
			verifier(" ".join(lignes).contains("staff"), "avant-match : conseil du staff")
		await capturer("meteo-avant-match")
		director.view._continue(true)
		await attendre("match_talk_continue")
	else: verifier(false, "causerie d'avant-match ouverte")
	var vue: Node = director.view if director != null else null
	verifier(vue != null and vue.has_method("update_frame") and "meteo_ligne" in vue, "direct ouvert")
	if vue != null and "meteo_ligne" in vue:
		vue.update_frame(avec_vent())
		await poser(4)
		textes.direct = vue.meteo_ligne.text
		verifier(vue.meteo_ligne.visible and vue.meteo_ligne.text.begins_with("Grand vent · dans le dos de") and vue.meteo_ligne.text.ends_with("en 1re période"), "bandeau : vent de la 1re période « %s »" % vue.meteo_ligne.text)
		verifier(not vue.meteo_ligne.tooltip_text.is_empty(), "bandeau : conseil du staff en infobulle")
		await capturer("meteo-bandeau-direct", func(): vue.update_frame(avec_vent()))
		vue.update_frame(avec_vent(true))
		await poser(4)
		textes.mi_temps = vue.meteo_ligne.text
		verifier(vue.meteo_ligne.text.begins_with("Mi-temps · changement de camp : le vent passe dans le dos de"), "bandeau : changement de camp « %s »" % vue.meteo_ligne.text)
		await capturer("meteo-bandeau-mi-temps", func(): vue.update_frame(avec_vent(true)))
	print("METEO ", JSON.stringify({"controles": controles, "failures": echecs, "textes": textes}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
