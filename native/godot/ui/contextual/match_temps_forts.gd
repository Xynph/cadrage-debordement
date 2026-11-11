extends Node
## Régie du direct en temps forts. Elle n'existe qu'avec CD_MATCH_TEMPS_FORTS=1.
##
## Trois états : écran intermédiaire (l'horloge file, une minute simulée par requête),
## temps fort (la vue 3D rejoue localement une liste de plans déjà simulés) et attente
## (le temps fort est fini, la minute suivante dira s'il continue). La régie ne décide
## rien de sportif : fenêtres, plans et arrêts viennent de `live.direct`, projeté par
## le moteur. Elle pilote la vue 3D par sa seule interface publique (`apply_frame`,
## `is_presenting_extended_pass`) : les gestes et les coupes vers les remises en jeu
## de la vue s'y greffent sans rien changer ici.
const S = preload("res://ui/contextual/skin.gd")
const Between = preload("res://ui/contextual/match_between.gd")
const Cadrage = preload("res://match_cadrage.gd")

enum { INTER, JEU, ATTENTE }
const NIVEAUX := ["aucun", "resume", "cles", "etendus", "dynamique", "integral"]
## Secondes réelles par minute de match sur l'écran intermédiaire.
const HORLOGES := {"lente": 3.0, "normale": 1.5, "rapide": 0.6, "eclair": 0.25}
## Pose « prêt » après une coupe : tireur face aux poteaux, équipes en place au renvoi.
const PRET := {"goal": 1.2, "miss": 1.2, "transformation": 1.2, "kickoff": 0.8, "drop22": 0.8, "goalLine": 0.8}
const DEPART_BALLON := ["goal", "miss", "transformation", "kickoff", "drop22", "goalLine"]
## Intervalle des positions intermédiaires d'une course balle en main.
const PAS := 0.2
## Délai entre la frappe d'un tir au but et l'affichage de son résultat.
const RESULTAT := 1.0
const FONDU := 0.5
## Aucune attente sans échéance : un geste de la vue 3D tient l'image au plus
## ECHEANCE_GESTE secondes par plan ; une minute demandée sans réponse ni requête en
## cours est redemandée après ECHEANCE_DEMANDE ; après une erreur du moteur, nouvel essai
## toutes les ECHEANCE_ERREUR secondes.
const ECHEANCE_GESTE := 12.0
const ECHEANCE_DEMANDE := 3.0
const ECHEANCE_ERREUR := 5.0

var view: Control
var app: Control
var stage: Node3D
var viewport: SubViewport
var between: Control
var voile: ColorRect
var cadrage: RefCounted
var etat := INTER
var niveau := "dynamique"
var horloge := "normale"
var vitesse := 1.0
var gel := false
var tf: Dictionary = {}
var index := -1
var phase := "jeu"
var temps := 0.0
var sous_image := 0.0
var attente := 0.0
var arret: Dictionary = {}
## Journal de régie, pour les tests et la capture : ce qui a réellement été joué.
var suivi: Array[Dictionary] = []
var _depuis: Dictionary = {}
var _derniers: Dictionary = {}
var _teams: Array = []
var _events: Array = []
var _live: Dictionary = {}
var _score: Array = [0, 0]
var _arret_attendu: Dictionary = {}
var _pause_envoyee := false
var _pause_au_depart := false
var _demande := false
var _fondu: Tween
var _debut_ms := 0
var _tenu := 0.0
var _sans_reponse := 0.0
var _apres_erreur := 0.0

static func enabled() -> bool:
	return OS.get_environment("CD_MATCH_TEMPS_FORTS") == "1"

func setup(owner_view: Control, container: Control, target: SubViewport, space: Control) -> void:
	name = "MatchTempsForts"
	# Avant la vue 3D dans la même image : un plan posé par la régie est cadré tout de suite,
	# sans une image où le ballon a déjà changé de place et pas encore la caméra.
	process_priority = -10
	view = owner_view
	app = view.app
	stage = view.stage
	viewport = target
	var choisi := str(app.management_ui.get("match_temps_forts_niveau", OS.get_environment("CD_MATCH_TEMPS_FORTS_NIVEAU")))
	niveau = choisi if choisi in NIVEAUX else "dynamique"
	var cadence := str(app.management_ui.get("match_temps_forts_horloge", OS.get_environment("CD_MATCH_TEMPS_FORTS_HORLOGE")))
	horloge = cadence if HORLOGES.has(cadence) else "normale"
	var allure := OS.get_environment("CD_MATCH_TEMPS_FORTS_VITESSE")
	vitesse = clampf(float(allure), 0.5, 4.0) if allure.is_valid_float() else 1.0
	if stage.has_method("set_cadrage"):
		cadrage = Cadrage.new(stage)
		stage.set_cadrage(cadrage)
	voile = ColorRect.new()
	voile.name = "MatchBetweenVeil"
	voile.color = Color(S.PANEL, 1.0)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(voile)
	view.add_child(voile)
	view.move_child(voile, container.get_index() + 1)
	between = Between.new()
	space.add_child(between)
	between.niveau_choisi.connect(_choisir_niveau)
	between.reprise_demandee.connect(func(): app._command("pause", {"paused": false}))
	between.tiroir_demande.connect(func(titre: String): view._toggle_drawer(titre))

func choisir_horloge(valeur: String) -> void:
	if not HORLOGES.has(valeur): return
	horloge = valeur
	app.management_ui["match_temps_forts_horloge"] = valeur

func _choisir_niveau(id: String) -> void:
	if id not in NIVEAUX: return
	niveau = id
	app.management_ui["match_temps_forts_niveau"] = id

## Appelée par la vue à chaque modèle reçu, après la mise à jour du bandeau.
func receive(model: Dictionary, live: Dictionary) -> void:
	var direct: Variant = live.get("direct")
	if not direct is Dictionary:
		# Moteur lancé sans la variable : le direct d'origine reprend la main.
		voile.hide()
		between.hide()
		stage.set_live_cadence(app.tick_steps)
		stage.apply_frame(live)
		return
	_live = live
	_teams = live.get("teams", [])
	_events = live.get("events", [])
	_demande = false
	if live.get("paused", false): _pause_envoyee = false
	between.update_frame(model, live, direct, func(conseil: Dictionary): app._command("set_tactics", {"attack": conseil.get("attack"), "defense": conseil.get("defence")}))
	# Ce qui a déjà été joué est retenu par rencontre : la vue peut être recréée
	# (causerie de mi-temps) sans rejouer un temps fort, et un nouveau match repart de zéro.
	var rencontre := str(direct.get("rencontre", "")) + "|"
	var candidat: Variant = direct.get("tempsFort")
	var nouveau: bool = candidat is Dictionary and rencontre + str(candidat.get("cle", "")) != str(app.management_ui.get("match_temps_forts_cle", ""))
	var signale: Variant = direct.get("arret")
	if signale is Dictionary and rencontre + str(signale.get("cle", "")) != str(app.management_ui.get("match_temps_forts_arret", "")):
		app.management_ui["match_temps_forts_arret"] = rencontre + str(signale.get("cle", ""))
		_arret_attendu = signale
	if not arret.is_empty() and not live.get("paused", false) and not _pause_envoyee:
		arret = {}
		between.montrer_arret({})
	if not live.get("paused", false): _pause_au_depart = false
	if nouveau:
		app.management_ui["match_temps_forts_cle"] = rencontre + str(candidat.get("cle", ""))
		gel = false
		# Un match déjà en pause (reprise d'une sauvegarde) joue tout de même son temps fort.
		_pause_au_depart = live.get("paused", false)
		_demarrer(candidat)
		# Le modèle arrive après la mise à jour de la vue 3D : on la rejoue sans faire avancer
		# le temps, pour que la première image du temps fort soit déjà placée et cadrée.
		stage._process(0.0)
	elif etat == JEU:
		# Même temps fort, nouveau modèle : seule une pause demandée par le manager le fige.
		var fige: bool = live.get("paused", false) and not _pause_au_depart and not live.get("atBreak", false) and not live.get("finished", false)
		if fige != gel:
			gel = fige
			if index >= 0 and index < tf.plans.size(): stage.apply_frame(_image(tf.plans[index].scene, gel, int(tf.plans[index].index)))
	elif etat == ATTENTE:
		_vers_inter()
	if etat != JEU:
		attente = 0.0
		_apres_lecture()
	_habiller()

func _process(delta: float) -> void:
	if view == null or not is_instance_valid(stage): return
	if etat == JEU:
		_lire(delta * vitesse, delta)
		return
	if _live.is_empty() or app.waiting:
		_sans_reponse = 0.0
		return
	if _demande:
		# La requête est partie mais plus rien n'est en cours : on ne reste pas suspendu à elle.
		_sans_reponse += delta
		if _sans_reponse < ECHEANCE_DEMANDE: return
		_demande = false
		suivi.append({"evenement": "echeance", "cause": "demande", "debut_ms": Time.get_ticks_msec()})
	_sans_reponse = 0.0
	if not str(app.last_error).is_empty():
		_apres_erreur += delta
		if _apres_erreur < ECHEANCE_ERREUR: return
	_apres_erreur = 0.0
	if _live.get("paused", false) or _live.get("finished", false) or not arret.is_empty(): return
	attente += delta
	if etat == ATTENTE or attente >= float(HORLOGES[horloge]):
		attente = 0.0
		_demande = app._command("tick", {"minute": true, "temps_forts": niveau})

# --- Lecture d'un temps fort -------------------------------------------------

func _image(scene: Dictionary, fige: bool, jusque: int) -> Dictionary:
	# Le journal est tronqué à l'action montrée : les gestes de la vue le lisent.
	var journal: Array = _events.slice(0, jusque + 1) if jusque >= 0 and jusque < _events.size() else _events
	return {"scene": scene, "teams": _teams, "events": journal, "paused": fige, "finished": false, "atBreak": false}

static func _positions(scene: Dictionary) -> Dictionary:
	var places: Dictionary = {}
	for joueur: Variant in scene.get("players", []):
		if joueur is Dictionary: places[str(joueur.get("id", ""))] = Vector2(float(joueur.get("x", 50.0)), float(joueur.get("y", 35.0)))
	return places

func _interpole(scene: Dictionary, avance: float) -> Dictionary:
	# Positions intermédiaires d'une progression : le porteur part du point de départ
	# de l'action, les autres de leur place précédente. Le point d'arrivée reste celui du moteur.
	var copie := scene.duplicate()
	var origine: Variant = scene.get("origin")
	var joueurs: Array = []
	for joueur: Dictionary in scene.get("players", []):
		var place := joueur.duplicate()
		var id := str(place.get("id", ""))
		var porteur: bool = place.get("featured", false) and int(place.get("side", -1)) == int(scene.get("possession", -2))
		if porteur and origine is Dictionary and origine.has("x") and origine.has("y"):
			place.x = lerpf(float(origine.x), float(joueur.x), avance)
			place.y = lerpf(float(origine.y), float(joueur.y), avance)
		elif _depuis.has(id):
			place.x = lerpf(_depuis[id].x, float(joueur.x), avance)
			place.y = lerpf(_depuis[id].y, float(joueur.y), avance)
		joueurs.append(place)
	copie.players = joueurs
	return copie

func _gestes_actifs() -> bool:
	# La vue 3D sait couper elle-même vers une remise en jeu quand ses gestes sont actifs.
	return stage.get("_gestes") != null

func _demarrer(candidat: Dictionary) -> void:
	tf = candidat
	index = 0
	etat = JEU
	_debut_ms = Time.get_ticks_msec()
	_score = tf.get("scoreAvant", _live.get("score", [0, 0]))
	_montrer_jeu(true)
	stage.set_live_cadence(1)
	# Entrée dans un temps fort : le cadrage rapproché est posé d'emblée (la 3D sort du fondu).
	if cadrage != null and not tf.get("suite", false): cadrage.couper()
	var depart: Variant = tf.get("depart")
	if not tf.get("suite", false) and depart is Dictionary:
		# Coupe d'entrée : l'action reprend d'où elle se trouvait une minute plus tôt.
		stage.apply_frame(_image(depart, true, int(tf.get("debut", 0)) - 1))
		stage.apply_frame(_image(depart, false, int(tf.get("debut", 0)) - 1))
		_derniers = _positions(depart)
	suivi.append({"evenement": "temps_fort", "cle": str(tf.get("cle", "")), "type": str(tf.get("type", "")), "suite": bool(tf.get("suite", false)),
		"horloge": str(tf.get("horlogeDebut", "")), "plans": tf.plans.size(), "duree_prevue": float(tf.get("duree", 0.0)), "debut_ms": _debut_ms})
	_commencer_plan()

func _commencer_plan() -> void:
	var plan: Dictionary = tf.plans[index]
	var scene: Dictionary = plan.scene
	temps = 0.0
	sous_image = 0.0
	_tenu = 0.0
	phase = "jeu"
	if cadrage != null:
		cadrage.regler(true, str(plan.get("kind", "")), float(plan.get("mouvement", 0.0)) >= 2.5)
		# Bandeau du score en haut, légende et commandes en bas : l'action est cadrée entre les deux.
		var hauteur := maxf(1.0, view.size.y)
		var legende: Control = view.events.get_parent().get_parent().get_parent()
		cadrage.couvrir(view.clock.get_global_rect().end.y / hauteur + 0.03, (hauteur - legende.get_global_rect().position.y) / hauteur + 0.02)
		if plan.get("coupe", false): cadrage.couper()
	if plan.get("coupe", false) and not _gestes_actifs():
		# Coupe franche : la phase est montrée déjà en place.
		var pret := scene.duplicate()
		pret.key = str(scene.get("key", "")) + ":pret"
		if str(plan.get("kind", "")) in DEPART_BALLON and scene.get("origin") is Dictionary: pret.ball = scene.origin
		stage.apply_frame(_image(pret, true, int(plan.index) - 1))
		stage.apply_frame(_image(pret, false, int(plan.index) - 1))
		_derniers = _positions(pret)
		if float(PRET.get(str(plan.get("kind", "")), 0.0)) > 0.0:
			phase = "pret"
			_habiller()
			return
	_jouer(plan)

func _jouer(plan: Dictionary) -> void:
	var scene: Dictionary = plan.scene
	phase = "jeu"
	temps = 0.0
	if float(plan.get("mouvement", 0.0)) > 0.0:
		_depuis = _derniers.duplicate()
		stage.apply_frame(_image(_interpole(scene, clampf(PAS / float(plan.mouvement), 0.0, 1.0)), false, int(plan.index)))
	else:
		stage.apply_frame(_image(scene, false, int(plan.index)))
	_derniers = _positions(scene)
	_habiller()

func _lire(delta: float, reel: float) -> void:
	if gel or index < 0 or index >= tf.plans.size(): return
	# Une passe longue ou un geste de la vue tient l'image : la lecture l'attend, avec une échéance.
	if stage.is_presenting_extended_pass() and _tenu < ECHEANCE_GESTE:
		_tenu += reel
		if _tenu >= ECHEANCE_GESTE: suivi.append({"evenement": "echeance", "cause": "geste", "plan": str(tf.plans[index].get("kind", "")), "debut_ms": Time.get_ticks_msec()})
		return
	var plan: Dictionary = tf.plans[index]
	temps += delta
	if phase == "pret":
		if temps >= float(PRET.get(str(plan.get("kind", "")), 0.0)): _jouer(plan)
		return
	# Le résultat d'un tir s'affiche après la frappe, pas avant.
	if plan.has("annonce") and temps >= RESULTAT and temps - delta < RESULTAT: _habiller()
	var mouvement := float(plan.get("mouvement", 0.0))
	if mouvement > 0.0 and temps < mouvement + PAS:
		sous_image += delta
		if sous_image >= PAS:
			sous_image = 0.0
			stage.apply_frame(_image(_interpole(plan.scene, clampf(temps / mouvement, 0.0, 1.0)), false, int(plan.index)))
	if temps < float(plan.get("duree", 1.0)): return
	_score = plan.get("score", _score)
	index += 1
	if index < tf.plans.size():
		_commencer_plan()
		return
	suivi[-1]["duree_reelle"] = (Time.get_ticks_msec() - _debut_ms) / 1000.0
	index = -1
	if _live.get("paused", false) or _live.get("finished", false) or not _arret_attendu.is_empty():
		_vers_inter()
		_apres_lecture()
	else:
		# La minute suivante dira si l'action continue : la 3D reste à l'écran.
		etat = ATTENTE
	_habiller()

func _vers_inter() -> void:
	etat = INTER
	attente = 0.0
	if cadrage != null: cadrage.regler(false)
	_montrer_jeu(false)
	suivi.append({"evenement": "intermediaire", "horloge": str(_live.get("direct", {}).get("horloge", "")), "debut_ms": Time.get_ticks_msec()})

func _apres_lecture() -> void:
	# Arrêt-décision : jamais au milieu d'un temps fort, toujours après.
	if _arret_attendu.is_empty(): return
	arret = _arret_attendu
	_arret_attendu = {}
	between.montrer_arret(arret)
	suivi.append({"evenement": "arret", "cle": str(arret.get("cle", "")), "horloge": str(arret.get("horloge", "")), "debut_ms": Time.get_ticks_msec()})
	if not _live.get("paused", false) and not _live.get("finished", false):
		_pause_envoyee = app._command("pause", {"paused": true})

# --- Affichage ---------------------------------------------------------------

func _montrer_jeu(visible_3d: bool) -> void:
	if _fondu != null and _fondu.is_valid(): _fondu.kill()
	if visible_3d:
		between.hide()
		if not voile.visible: return
		_fondu = create_tween()
		_fondu.tween_property(voile, "modulate:a", 0.0, FONDU)
		_fondu.tween_callback(voile.hide)
	else:
		voile.show()
		between.show()
		between.modulate.a = 0.0
		_fondu = create_tween().set_parallel(true)
		_fondu.tween_property(voile, "modulate:a", 1.0, FONDU)
		_fondu.tween_property(between, "modulate:a", 1.0, FONDU)
		# La 3D continue d'être rendue sous le voile : arrêter puis relancer la sous-vue
		# n'apportait qu'une économie et ajoutait un état de plus au moment des coupes.

func _habiller() -> void:
	# Pendant un temps fort, le bandeau montre l'instant rejoué, pas l'état du moteur.
	var legende: Control = view.events.get_parent().get_parent().get_parent()
	if etat == INTER:
		legende.hide()
		# Retour à l'état du moteur, avec la même écriture de l'horloge que pendant un
		# temps fort (40+2′ en arrêts de jeu).
		var marque: Array = _live.get("score", [0, 0])
		if marque.size() >= 2: view.score.text = "%d — %d" % [int(marque[0]), int(marque[1])]
		var heure := str(_live.get("direct", {}).get("horloge", ""))
		if _live.get("finished", false): view.clock.text = "TERMINÉ"
		elif _live.get("atBreak", false): view.clock.text = "MI-TEMPS"
		elif not heure.is_empty(): view.clock.text = heure
		if not voile.visible:
			voile.modulate.a = 1.0
			voile.show()
			between.modulate.a = 1.0
			between.show()
		return
	if index < 0 or index >= tf.get("plans", []).size(): return
	var plan: Dictionary = tf.plans[index]
	view.clock.text = str(plan.get("horloge", ""))
	if _score.size() >= 2: view.score.text = "%d — %d" % [int(_score[0]), int(_score[1])]
	var attend_resultat: bool = plan.has("annonce") and (phase == "pret" or temps < RESULTAT)
	view.events.text = str(plan.get("annonce" if attend_resultat else "texte", ""))
	view.events.get_parent().get_parent().visible = not view.events.text.is_empty()
	legende.visible = not view.events.text.is_empty()
