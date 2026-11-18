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

const TUILES := ["TuileForces", "TuileMeteo", "TuileFeuille", "TuileConfrontations", "TuileJoueurs", "TuileGabi"]
const AvantMatch = preload("res://ui/immersive08/match_avant.gd")

## Textes d'un nœud de l'écran Match (labels de toute la sous-arborescence).
func textes_de(noeud: Node) -> String:
	if noeud == null: return ""
	var lignes: Array = noeud.find_children("*", "Label", true, false).map(func(l: Label): return l.text)
	if noeud is Label: lignes.push_front(noeud.text)
	return " | ".join(lignes)

## Tableau de bord d'avant-match : six tuiles présentes et visibles, rien ne déborde, tout tient dans la page 1080p.
func controler_tableau(contexte: String) -> void:
	var ecran: Node = app.match_screen
	var tableau: Control = ecran.find_child("MatchOpening", true, false) if is_instance_valid(ecran) else null
	verifier(tableau != null and tableau.is_visible_in_tree(), contexte + " : tableau de bord d'avant-match visible")
	if tableau == null: return
	for id in TUILES:
		var tuile: Control = tableau.find_child(id, true, false)
		verifier(tuile != null and tuile.is_visible_in_tree() and tuile.size.x > 200 and tuile.size.y > 150, contexte + " : tuile " + id + (" %s" % tuile.size if tuile != null else " absente"))
	for id in ["MatchPoster", "MatchKickoff", "MatchOpenDelegation", "MatchFixtureVenue", "MatchFixtureWeather", "MatchOpenSheet", "MatchOpenPreparation", "MatchOpenPlaybook", "MatchOpenTalk"]:
		var noeud: Control = tableau.find_child(id, true, false)
		verifier(noeud != null and noeud.is_visible_in_tree(), contexte + " : " + id)
	for echec in tableau.overflows(): verifier(false, contexte + " : débordement " + str(echec))
	var page: Rect2 = app.body_scroll.get_global_rect()
	var rect := tableau.get_global_rect()
	verifier(rect.end.y <= page.end.y + 1 and rect.end.x <= page.end.x + 1, contexte + " : l'écran tient dans la page (%s dans %s)" % [rect, page])
	verifier(app.body_scroll.get_v_scroll_bar().max_value <= app.body_scroll.size.y + 1, contexte + " : aucune barre de défilement")
	for label: Label in tableau.find_children("*", "Label", true, false):
		if not label.is_visible_in_tree() or label.clip_text or label.autowrap_mode != TextServer.AUTOWRAP_OFF: continue
		var parent := label.get_parent() as Control
		while parent != null and not parent.get_meta("prematch_tile", false): parent = parent.get_parent() as Control
		if parent == null: continue
		var dedans := parent.get_global_rect().grow(1).encloses(label.get_global_rect())
		verifier(dedans, contexte + " : texte hors de sa tuile « %s » (%s)" % [label.text, parent.name])

## Écran Match le jour du match : tableau de bord (maquette « Retenue »), météo annoncée la veille (vraie annonce du
## moteur), données calculées par le moteur (clubLife.avantMatch), puis chaque ciel et sa photo, et le grand vent.
func avant_match() -> void:
	var annonce: Variant = app.model.get("next", {}).get("meteo")
	verifier(annonce is Dictionary, "prochain match : météo annoncée dans le modèle natif")
	verifier(app.model.get("clubLife", {}).get("avantMatch") is Dictionary, "données d'avant-match du moteur (clubLife.avantMatch)")
	var bulletins := (app.model.get("clubLife", {}).get("clubMail", {}).get("mails", []) as Array).filter(func(m): return m is Dictionary and m.get("type") == "meteo")
	verifier(not bulletins.is_empty() and str(bulletins[-1].get("ecran")) == "Composition", "courrier « Bulletin météo » avec un lien vers la composition")
	app._navigate("Match")
	await poser(10)
	controler_tableau("avant-match")
	var tableau: Node = app.match_screen.find_child("MatchOpening", true, false)
	var meteo: Node = tableau.find_child("TuileMeteo", true, false) if tableau != null else null
	var texte_meteo := textes_de(meteo)
	textes.ecran_match = texte_meteo
	verifier(texte_meteo.begins_with("LA MÉTÉO"), "tuile météo : « %s »" % texte_meteo)
	if annonce is Dictionary:
		var ciel := str(annonce.get("libelle", ""))
		verifier(texte_meteo.to_lower().contains(ciel.to_lower()), "tuile météo : ciel annoncé « %s »" % ciel)
	var donnees: Dictionary = app.model.get("clubLife", {}).get("avantMatch", {})
	var surveilles: Array = donnees.get("aSurveiller", {}).get("joueurs", [])
	var texte_joueurs := textes_de(tableau.find_child("TuileJoueurs", true, false) if tableau != null else null)
	# Avec un plan adverse, la tuile garde les deux premiers joueurs à surveiller (la place va au plan).
	if donnees.get("planAdverse") is Dictionary: surveilles = surveilles.slice(0, 2)
	for joueur: Dictionary in surveilles: verifier(texte_joueurs.contains(str(joueur.get("name", ""))), "joueur à surveiller affiché : " + str(joueur.get("name", "")))
	textes.joueurs = texte_joueurs
	# Plan de jeu probable de l'adversaire (avant-match.cjs planAdverse) : en tête de la tuile adversaire, dans les
	# clés de Gabi, avec l'action pour le contrer ; chaque style et chaque fiabilité tiennent dans la tuile.
	var plan: Variant = donnees.get("planAdverse")
	verifier(plan is Dictionary, "plan adverse calculé dès la veille (météo annoncée)")
	if plan is Dictionary:
		verifier(texte_joueurs.contains(str(plan.titre)) and texte_joueurs.begins_with("L’ADVERSAIRE"), "tuile adversaire : plan « %s »" % texte_joueurs)
		verifier(str(textes.get("gabi", textes_de(tableau.find_child("TuileGabi", true, false)))).contains(str(plan.titre)) or (donnees.get("gabi", {}).get("cles", []) as Array).any(func(c): return str(c.get("titre")) == str(plan.titre)), "clé de Gabi : plan adverse")
		verifier(tableau.find_child("MatchCounterPlan", true, false) != null, "action pour contrer le plan")
		textes.plan = plan
	var variantes := {"pres-sur": {"style": "conquete", "titre": "Ils vont jouer au près", "raison": "leur pack domine le nôtre", "confiance": "sure", "action": "composition", "libelle": "Ouvrir la composition", "conseil": "aligne ta meilleure première ligne et tes sauteurs", "lecteur": {"nom": "Benoît Lafargue-Montesquieu", "role": "analyste vidéo"}},
		"large-incertain": {"style": "large", "titre": "Ils vont jouer au large", "raison": "leurs trois-quarts prennent le dessus sur notre défense", "confiance": "incertaine", "action": "consignes", "libelle": "Régler les consignes", "conseil": "une défense glissée prudente protège les extérieurs", "lecteur": {"nom": null, "role": "staff"}},
		"pied-probable": {"style": "occupation", "titre": "Ils vont occuper au pied", "raison": "ils sortent d’une semaine européenne et ménagent leurs jambes", "confiance": "probable", "action": "composition", "libelle": "Ouvrir la composition", "conseil": "un arrière et des ailiers sûrs sous les ballons hauts", "lecteur": {"nom": "Ana Ruiz", "role": "adjoint"}}}
	for nom_p: String in variantes:
		var copie_p: Dictionary = app.model.duplicate(true)
		if not copie_p.get("clubLife", {}).get("avantMatch") is Dictionary: break
		copie_p.clubLife.avantMatch["planAdverse"] = variantes[nom_p]
		app.match_screen.update_frame(copie_p)
		await poser(6)
		controler_tableau("plan " + nom_p)
		var bloc_p: Node = app.match_screen.find_child("PlanAdverse", true, false)
		var puce: Node = bloc_p.find_child("PlanAdverseConfiance", true, false) if bloc_p != null else null
		verifier(puce != null and str(puce.get_meta("confiance", "")) == str(variantes[nom_p].confiance), "plan %s : fiabilité affichée" % nom_p)
		verifier(textes_de(bloc_p).contains(str(variantes[nom_p].titre)), "plan %s : titre" % nom_p)
		await capturer("avant-match-plan-" + nom_p, func(): app.match_screen.update_frame(copie_p))
	app.match_screen.update_frame(app.model)
	await poser(4)
	textes.gabi = textes_de(tableau.find_child("TuileGabi", true, false) if tableau != null else null)
	textes.forces = textes_de(tableau.find_child("TuileForces", true, false) if tableau != null else null)
	for cle: Dictionary in donnees.get("gabi", {}).get("cles", []): verifier(str(textes.gabi).contains(str(cle.get("titre", ""))), "clé de Gabi affichée : " + str(cle.get("titre", "")))
	await capturer("avant-match-ecran")
	# Chaque ciel : photo du tunnel et tuile météo (variantes absentes : photo d'origine).
	var ciels := {"sec": {"libelle": "temps sec", "pluie": 0, "vent": 0, "chaleur": 0, "terrain": "souple"},
		"pluie": {"libelle": "pluie", "pluie": 1, "vent": 0, "chaleur": 0, "terrain": "souple"},
		"forte-pluie": {"libelle": "forte pluie", "pluie": 2, "vent": 0, "chaleur": 0, "terrain": "lourd"},
		"vent": {"libelle": "grand vent", "pluie": 0, "vent": 2, "chaleur": 0, "terrain": "souple", "ventDos": [1, 0]},
		"chaleur": {"libelle": "forte chaleur", "pluie": 0, "vent": 0, "chaleur": 1, "terrain": "souple"},
		"neutre": {},
		"jour-sec": {"libelle": "sec", "pluie": 0, "vent": 0, "chaleur": 0, "terrain": "souple", "_heure": "15:00"},
		"jour-pluie": {"libelle": "pluie", "pluie": 1, "vent": 0, "chaleur": 0, "terrain": "souple", "_heure": "14:30"}}
	var photos := {}
	for nom: String in ciels:
		var copie: Dictionary = app.model.duplicate(true)
		if not copie.get("next") is Dictionary: break
		if ciels[nom].is_empty(): copie.next.erase("meteo")
		else:
			var m: Dictionary = ciels[nom].duplicate()
			copie.next.kickoffLocal = str(m.get("_heure", "21:05"))
			m.erase("_heure")
			m.date = str(app.model.meta.get("calendarToday", ""))
			m.conseil = "Le staff : conseil de test pour le ciel « %s », assez long pour tenir sur deux lignes dans la tuile météo de l'écran." % m.libelle
			if not m.has("ventDos"): m.ventDos = null
			copie.next.meteo = m
		app.match_screen.update_frame(copie)
		await poser(6)
		controler_tableau("ciel " + nom)
		var photo: Node = app.match_screen.find_child("MatchPosterPhoto", true, false)
		photos[nom] = str(photo.get_meta("photo_meteo", "")) if photo != null else ""
		verifier(photos[nom] == AvantMatch.photo_meteo(copie.next), "ciel %s : photo %s" % [nom, photos[nom]])
		if nom.begins_with("jour-"):
			verifier(photos[nom] == "stade-pelouse-%s-jour" % nom.substr(5), "coup d'envoi en journée : pelouse du jour (%s)" % photos[nom])
		elif not ciels[nom].is_empty():
			verifier(photos[nom].begins_with("match-tunnel"), "coup d'envoi le soir : tunnel (%s)" % photos[nom])
		if nom == "vent":
			var nous := 1 if app.model.next.get("away", {}).get("id") == app.model.club.get("id") else 0
			var bandeau := textes_de(app.match_screen.find_child("MatchPosterWeather", true, false))
			textes.ecran_match_bandeau = bandeau
			verifier(bandeau.contains("GRAND VENT") and bandeau.contains("en 1re période") and bandeau.contains("après la pause"), "affiche : vent des deux périodes « %s »" % bandeau)
			var p1 := textes_de(app.match_screen.find_child("MeteoPeriode1", true, false))
			var p2 := textes_de(app.match_screen.find_child("MeteoPeriode2", true, false))
			textes.ecran_match_vent = [p1, p2]
			verifier(p1.contains("Dans le dos" if nous == 1 else "De face") and p2.contains("De face" if nous == 1 else "Dans le dos"), "tuile météo : vent par rapport à notre attaque « %s / %s »" % [p1, p2])
		await capturer("meteo-ciel-" + nom, func(): app.match_screen.update_frame(copie))
	textes.photos = photos
	# Arbitre du match (clubLife.avantMatch.arbitre) dans la tuile des conditions : nom, profil d'une ligne et
	# quatre jauges de 1 à 5 ; rien ne déborde, avec ou sans météo annoncée ; sans arbitre, aucun bloc.
	var arbitre := {"nom": "Julien Castaing", "pays": "FR", "rucks": 4, "melee": 3, "horsJeu": 3, "cartons": 2, "resume": "Pointilleux sur les rucks, laisse vivre les cartons."}
	for variante: String in ["vent", "sans-annonce"]:
		var copie_a: Dictionary = app.model.duplicate(true)
		if not copie_a.get("next") is Dictionary or not copie_a.get("clubLife", {}).get("avantMatch") is Dictionary: break
		if variante == "vent":
			copie_a.next.kickoffLocal = "21:05"
			copie_a.next.meteo = {"libelle": "grand vent", "pluie": 0, "vent": 2, "chaleur": 0, "terrain": "souple", "ventDos": [1, 0], "date": str(app.model.meta.get("calendarToday", "")),
				"conseil": "Le staff : conseil de test pour le grand vent, assez long pour tenir sur deux lignes dans la tuile météo de l'écran."}
		else: copie_a.next.erase("meteo")
		copie_a.clubLife.avantMatch["arbitre"] = arbitre
		app.match_screen.update_frame(copie_a)
		await poser(6)
		controler_tableau("arbitre " + variante)
		var tuile_a: Node = app.match_screen.find_child("TuileMeteo", true, false)
		var bloc: Node = tuile_a.find_child("MatchArbitre", true, false) if tuile_a != null else null
		var nom: Label = bloc.find_child("MatchArbitreNom", true, false) if bloc != null else null
		verifier(nom != null and nom.text == "Arbitre : Julien Castaing" and nom.is_visible_in_tree(), "arbitre %s : nom dans la tuile des conditions" % variante)
		verifier(nom != null and nom.tooltip_text == str(arbitre.resume), "arbitre %s : profil en infobulle du nom" % variante)
		var niveaux: Array = []
		for libelle: String in ["Rucks", "Mêlée", "Hors-jeu", "Cartons"]:
			var jauge: Node = bloc.find_child("ArbitreJauge_" + libelle, true, false) if bloc != null else null
			niveaux.append(int(jauge.get_meta("niveau", -1)) if jauge != null else -1)
		verifier(niveaux == [4, 3, 3, 2], "arbitre %s : quatre jauges de sévérité %s" % [variante, str(niveaux)])
		textes["arbitre_" + variante] = textes_de(bloc)
		await capturer("avant-match-arbitre-" + variante, func(): app.match_screen.update_frame(copie_a))
	var sans_arbitre: Dictionary = app.model.duplicate(true)
	if sans_arbitre.get("clubLife", {}).get("avantMatch") is Dictionary:
		sans_arbitre.clubLife.avantMatch.erase("arbitre")
		app.match_screen.update_frame(sans_arbitre)
		await poser(4)
		verifier(app.match_screen.find_child("MatchArbitre", true, false) == null, "sans arbitre désigné : aucun bloc arbitre")
		controler_tableau("sans arbitre")
	verifier(not textes_de(app.match_screen.find_child("TuileMeteo", true, false)).is_empty(), "tuile météo sans annonce")
	app.match_screen.update_frame(app.model)
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
