extends RefCounted
## Plaquage, ruck et joie d'essai montrés avec les clips du modèle de joueur (chute,
## applaudissements), dans le direct et les temps forts, sans bibliothèque d'animations.
## Présentation seulement : le moteur dit où la course s'arrête, pas qui plaque ni qui entre
## dans le ruck. La vue choisit le défenseur le plus proche du point d'arrêt (il rejoint le
## porteur à son allure plafonnée, Motion.ALLURE_MAX), puis les soutiens les plus proches.
##
## Déroulé d'une progression balle en main (fait « carry ») :
##   « course »  : le plaqueur va attendre le porteur juste devant le point d'arrêt ;
##   « contact » : porteur arrivé et plaqueur à moins de CONTACT_MAX -> le porteur joue la chute,
##                 puis 2 à 4 joueurs par camp se regroupent penchés sur le ballon (ruck) ;
##   fait suivant : le ruck se défait, le porteur se relève (chute jouée à l'envers).
## Essai : les coéquipiers proches du marqueur applaudissent une fois arrivés à leur place.

const Motion = preload("res://match_motion.gd")

const CLIP_CHUTE := "Man_Death"
const CLIP_APPLAUDIR := "Man_Clapping"
## Défenseur le plus proche du point d'arrêt, au plus à cette distance (m).
const PLAQUEUR_PORTEE := 20.0
## Le plaqueur attend le porteur à cette distance devant le point d'arrêt (m).
const PLAQUEUR_ECART := 0.75
## Le contact a lieu quand porteur et plaqueur sont à moins de cette distance (m).
const CONTACT_MAX := 1.5
## Porteur arrivé : à moins de cette distance du point d'arrêt (m).
const ARRIVEE := 0.6
## Plaqueur pas au contact ce délai après l'arrivée du porteur : pas de plaquage (s).
const ATTENTE_CONTACT := 1.2
## Instant du clip de chute où la lecture commence (s), et durée jouée à l'envers pour se relever.
const CHUTE_DEBUT := 0.2
const RELEVE_VITESSE := -2.6
const RELEVE_FIN := 0.15
## Au sol au plus ce temps après la fin du clip si aucun fait ne suit (s).
const AU_SOL_MAX := 3.0
## Ruck : délai après le contact, rayon de recrutement (m), soutiens par camp (le plaqueur compte
## pour la défense), places (le long de l'axe d'attaque, en travers) autour du ballon.
const RUCK_DELAI := 0.3
const RUCK_RAYON := 18.0
const RUCK_ATTAQUE := 3
const RUCK_DEFENSE := 2
## Le porteur tombe vers l'avant (clip de chute) : le ballon et le centre du ruck sont à
## RUCK_CENTRE m devant son point d'arrêt ; le plaqueur se dégage à RUCK_PLAQUEUR m au-delà.
const RUCK_CENTRE := 1.2
const RUCK_PLAQUEUR := 0.95
const RUCK_PLACES_ATTAQUE := [[-0.55, -0.75], [-0.55, 0.75], [-1.35, 0.85]]
const RUCK_PLACES_DEFENSE := [[0.8, -0.8], [0.8, 0.8]]
## Hauteur minimale du ballon posé au sol (m) : demi-épaisseur du ballon couché.
const BALLON_AU_SOL := 0.13
## Buste penché (rad) et abaissement (m) d'un joueur au ruck ; vitesse d'entrée et de sortie.
const RUCK_PENCHE := [0.62, -0.1]
const RUCK_POSE_VITESSE := 3.0
## Pose prise une fois le joueur à moins de cette distance de sa place (m).
const RUCK_EN_PLACE := 0.35
## La régie attend le plaquage et le ruck au plus ce temps après le contact (s, cadence ×1).
const TENUE := 2.4
## Joie d'essai : coéquipiers à moins de APPLAUDIR_RAYON m du ballon, au plus APPLAUDIR_MAX,
## pendant APPLAUDIR_SECONDES.
const APPLAUDIR_RAYON := 30.0
const APPLAUDIR_MAX := 6
const APPLAUDIR_SECONDES := 3.3
const NOMS := ["chute", "releve", "applaudir"]

var view
var phase := ""
var porteur := ""
var plaqueur := ""
## Point d'arrêt de la course (monde) et axe d'attaque (+x pour le camp 0).
var arret := Vector3.ZERO
var axe := Vector3.RIGHT
## Centre du ruck : où le ballon finit au sol.
var centre := Vector3.ZERO
var attente := 0.0
var depuis := 0.0
var au_sol := ""
## id -> {"place": Vector3, "poids": float, "base": Transform3D, "lache": bool}
var ruck: Dictionary = {}
## Coéquipiers du marqueur qui applaudiront une fois arrivés.
var joie: Array[String] = []
## Compteurs de contrôle (tests).
var plaquages := 0
var distance_contact := -1.0


func _init(owner) -> void:
	view = owner


## Fait reçu par la vue. Rend la scène à projeter : le plaqueur et les joueurs du ruck y sont
## placés à leur place de contact, pour que les images suivantes du même fait ne les renvoient
## pas ailleurs. `actif` : mouvement d'action à la cadence ×1, hors pause et hors pistes.
func observer(scene: Dictionary, new_action: bool, actif: bool) -> Dictionary:
	if new_action:
		_relacher()
		joie.clear()
		if actif:
			_preparer(scene)
	if phase.is_empty():
		return scene
	if not actif:
		_relacher()
		return scene
	return _reecrire(scene)


## Vrai pendant le plaquage et la formation du ruck : la régie attend avant le fait suivant.
func tient() -> bool:
	return phase == "contact" and depuis < TENUE


## Le joueur joue un geste de contact (chute, relevé, applaudissements) : il n'a pas de
## déplacement en retard, la régie ne l'attend pas.
func occupe(id: String) -> bool:
	if not view._actors.has(id):
		return false
	var geste: Dictionary = view._actors[id].get("geste", {})
	return not geste.is_empty() and str(geste.get("nom", "")) in NOMS


func annuler() -> void:
	for id: String in ruck:
		if view._actors.has(id):
			(view._actors[id].model as Node3D).transform = ruck[id].base
	ruck.clear()
	joie.clear()
	phase = ""
	porteur = ""
	plaqueur = ""
	au_sol = ""


func avancer(delta: float) -> void:
	_poser_ruck(delta)
	_applaudir()
	_tenir_au_sol()
	if phase == "course":
		if not view._actors.has(porteur) or not view._actors.has(plaqueur):
			phase = ""
			return
		var a: Vector3 = view._actors[porteur].node.position
		if Vector2(a.x - arret.x, a.z - arret.z).length() > ARRIVEE:
			return
		attente += delta
		var b: Vector3 = view._actors[plaqueur].node.position
		var ecart := Vector2(a.x - b.x, a.z - b.z).length()
		if ecart < CONTACT_MAX and not view._is_pass_player(porteur):
			_plaquer(ecart)
		elif attente > ATTENTE_CONTACT:
			# Personne au contact : pas de plaquage inventé, le porteur ne tombe pas seul.
			phase = ""
	elif phase == "contact":
		depuis += delta
		# La chute remplace la pose de contact debout (bustes en appui).
		view._contact_plan.clear()
		if depuis >= RUCK_DELAI and ruck.size() <= 1:
			_former_ruck()


func _preparer(scene: Dictionary) -> void:
	var kind := str(scene.get("kind", ""))
	var possession := int(scene.get("possession", -1))
	if possession not in [0, 1]:
		return
	var vedette := ""
	for player: Dictionary in scene.get("players", []):
		if player.get("featured", false) and int(player.get("side", -1)) == possession:
			if not vedette.is_empty():
				return
			vedette = str(player.get("id", ""))
	if vedette.is_empty() or not view._actors.has(vedette):
		return
	var ball: Dictionary = scene.get("ball", {})
	if not ball.has("x") or not ball.has("y"):
		return
	var point: Vector3 = view._world(ball)
	if kind == "try":
		_preparer_joie(scene, vedette, possession, point)
		return
	if kind != "carry" or float(ball.x) <= 0.5 or float(ball.x) >= 99.5:
		return
	if view.mise_en_scene().stages(vedette):
		return
	var proche := PLAQUEUR_PORTEE
	var choisi := ""
	for player: Dictionary in scene.get("players", []):
		var id := str(player.get("id", ""))
		if int(player.get("side", -1)) != 1 - possession or not view._actors.has(id):
			continue
		var distance := Vector2(float(player.get("x", 0.0)) - 50.0 - point.x, float(player.get("y", 0.0)) - 35.0 - point.z).length()
		if distance < proche or (is_equal_approx(distance, proche) and id < choisi):
			proche = distance
			choisi = id
	if choisi.is_empty():
		return
	phase = "course"
	porteur = vedette
	plaqueur = choisi
	arret = Vector3(point.x, 0.0, point.z)
	axe = Vector3.RIGHT if possession == 0 else Vector3.LEFT
	attente = 0.0
	depuis = 0.0


func _preparer_joie(scene: Dictionary, marqueur: String, camp: int, point: Vector3) -> void:
	var proches: Array = []
	for player: Dictionary in scene.get("players", []):
		var id := str(player.get("id", ""))
		if id == marqueur or int(player.get("side", -1)) != camp or not view._actors.has(id):
			continue
		var distance := Vector2(float(player.get("x", 0.0)) - 50.0 - point.x, float(player.get("y", 0.0)) - 35.0 - point.z).length()
		if distance <= APPLAUDIR_RAYON:
			proches.append([distance, id])
	proches.sort()
	for paire: Array in proches.slice(0, APPLAUDIR_MAX):
		joie.append(str(paire[1]))


func _reecrire(scene: Dictionary) -> Dictionary:
	var places: Dictionary = {}
	if view._actors.has(plaqueur) and not ruck.has(plaqueur):
		places[plaqueur] = arret + axe * PLAQUEUR_ECART
	for id: String in ruck:
		if not ruck[id].lache:
			places[id] = ruck[id].place
	if places.is_empty():
		return scene
	var copie := scene.duplicate()
	var joueurs: Array = []
	for player: Dictionary in scene.get("players", []):
		var id := str(player.get("id", ""))
		if places.has(id):
			var place := player.duplicate()
			var at: Vector3 = places[id]
			place.x = at.x + 50.0
			place.y = at.z + 35.0
			joueurs.append(place)
		else:
			joueurs.append(player)
	copie.players = joueurs
	return copie


func _plaquer(ecart: float) -> void:
	phase = "contact"
	depuis = 0.0
	plaquages += 1
	distance_contact = ecart
	var entry: Dictionary = view._actors[porteur]
	# Un geste adapté déjà lancé (bibliothèque d'animations) garde la main.
	if entry.get("geste", {}).is_empty():
		var clip := _clip(entry, CLIP_CHUTE)
		if not clip.is_empty():
			entry.geste = {"nom": "chute", "clip": clip, "t": CHUTE_DEBUT, "fin": INF, "ancre": true, "suite": [], "lance": false}
			au_sol = porteur
	# Le porteur tombe vers l'avant : le ballon finit au sol devant lui, centre du ruck.
	var cap: float = (entry.node as Node3D).rotation.y
	axe = Vector3(sin(cap), 0.0, cos(cap))
	centre = arret + axe * RUCK_CENTRE
	# Le plaqueur, pris sous la chute, se dégage côté défense et reste penché sur le ballon.
	var place := centre + axe * RUCK_PLAQUEUR
	var tackler: Dictionary = view._actors[plaqueur]
	# Chute physique (match_chute_physique.gd) : le haut du corps du porteur part vers l'avant, loin du plaqueur.
	if view.get("_chute_physique") != null:
		var oppose: Vector3 = (entry.node as Node3D).position - (tackler.node as Node3D).position
		oppose.y = 0.0
		view._chute_physique.declencher(porteur, axe + oppose.normalized() * 0.5, plaqueur)
	_rejoindre(tackler, place)
	ruck[plaqueur] = {"place": place, "poids": 0.0, "base": (tackler.model as Node3D).transform, "lache": false}


func _former_ruck() -> void:
	var attaque := int(view._actors[porteur].side)
	var lateral := Vector3(-axe.z, 0.0, axe.x)
	for camp in [attaque, 1 - attaque]:
		var places: Array = RUCK_PLACES_ATTAQUE if camp == attaque else RUCK_PLACES_DEFENSE
		var candidats: Array = []
		for id: String in view._actors:
			var entry: Dictionary = view._actors[id]
			if id == porteur or ruck.has(id) or int(entry.side) != camp or occupe(id):
				continue
			if view._is_pass_player(id) or view.mise_en_scene().stages(id):
				continue
			var distance := (entry.node as Node3D).position.distance_to(arret)
			if distance <= RUCK_RAYON:
				candidats.append([distance, id])
		candidats.sort()
		for i in mini(places.size(), candidats.size()):
			var id := str(candidats[i][1])
			var place: Vector3 = centre + axe * float(places[i][0]) + lateral * float(places[i][1])
			var entry: Dictionary = view._actors[id]
			_rejoindre(entry, place)
			ruck[id] = {"place": place, "poids": 0.0, "base": (entry.model as Node3D).transform, "lache": false}


## Trajet vers une place de contact, à l'allure plafonnée de la vue.
func _rejoindre(entry: Dictionary, place: Vector3) -> void:
	var at: Vector3 = (entry.node as Node3D).position
	entry.from = at
	entry.target = place
	entry.duree = Motion.duree(at, place)
	entry.tangent = Motion.tangent(entry.velocity, place - at, entry.duree)
	entry.elapsed = 0.0


## Après la pose des bras : le ballon du porteur au sol reste posé sur la pelouse, pas dessous.
func poser_ballon() -> void:
	if au_sol.is_empty() or view._carrier_id != au_sol or not view._ball.visible:
		return
	var ball: Node3D = view._ball
	if ball.global_position.y < BALLON_AU_SOL:
		ball.global_position.y = BALLON_AU_SOL


func _poser_ruck(delta: float) -> void:
	for id: String in ruck.keys():
		var tenu: Dictionary = ruck[id]
		if not view._actors.has(id):
			ruck.erase(id)
			continue
		var entry: Dictionary = view._actors[id]
		var actor: Node3D = entry.node
		var model: Node3D = entry.model
		var en_place: bool = not tenu.lache and Vector2(actor.position.x - tenu.place.x, actor.position.z - tenu.place.z).length() < RUCK_EN_PLACE
		if en_place:
			# Face au ballon, à vitesse bornée.
			var vers := centre - actor.position
			if Vector2(vers.x, vers.z).length() > 0.05:
				var change := angle_difference(actor.rotation.y, atan2(vers.x, vers.z))
				actor.rotation.y += clampf(change, -6.0 * delta, 6.0 * delta)
		tenu.poids = move_toward(float(tenu.poids), 1.0 if en_place else 0.0, delta * RUCK_POSE_VITESSE)
		model.transform = tenu.base
		var w := smoothstep(0.0, 1.0, float(tenu.poids))
		model.rotation.x = float(RUCK_PENCHE[0]) * w
		model.position.y += float(RUCK_PENCHE[1]) * w
		if tenu.lache and float(tenu.poids) <= 0.0:
			model.transform = tenu.base
			ruck.erase(id)


## Nombre de joueurs de chaque camp penchés au ruck (poids de pose au moins `seuil`).
func penches(camp: int, seuil: float = 0.9) -> int:
	var n := 0
	for id: String in ruck:
		if view._actors.has(id) and int(view._actors[id].side) == camp and float(ruck[id].poids) >= seuil:
			n += 1
	return n


func _applaudir() -> void:
	for id: String in joie.duplicate():
		if not view._actors.has(id):
			joie.erase(id)
			continue
		var entry: Dictionary = view._actors[id]
		if view.mise_en_scene().stages(id) or id in view.mise_en_scene().cheer:
			joie.erase(id)
			continue
		if not entry.get("geste", {}).is_empty() or float(entry.elapsed) < float(entry.duree):
			continue
		var clip := _clip(entry, CLIP_APPLAUDIR)
		joie.erase(id)
		if clip.is_empty():
			continue
		(entry.animation as AnimationPlayer).get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		# Décalage par joueur : les mains ne frappent pas toutes ensemble.
		var debut := float(absi(id.hash()) % 10) * 0.15
		entry.geste = {"nom": "applaudir", "clip": clip, "t": debut, "fin": debut + APPLAUDIR_SECONDES, "ancre": true, "suite": [], "lance": false}


func _tenir_au_sol() -> void:
	if au_sol.is_empty() or not view._actors.has(au_sol):
		au_sol = ""
		return
	var geste: Dictionary = view._actors[au_sol].get("geste", {})
	if geste.is_empty() or str(geste.get("nom", "")) != "chute":
		au_sol = ""
		return
	var animation: AnimationPlayer = view._actors[au_sol].animation
	if float(geste.t) > animation.get_animation(geste.clip).length + AU_SOL_MAX:
		_relever()


## Fait suivant : le ruck se défait (bustes relevés en 1/RUCK_POSE_VITESSE s), le porteur se relève.
func _relacher() -> void:
	for id: String in ruck:
		ruck[id].lache = true
	if not au_sol.is_empty():
		_relever()
	phase = ""
	porteur = ""
	plaqueur = ""


func _relever() -> void:
	if view._actors.has(au_sol):
		var entry: Dictionary = view._actors[au_sol]
		var geste: Dictionary = entry.get("geste", {})
		if not geste.is_empty() and str(geste.get("nom", "")) == "chute":
			var longueur: float = (entry.animation as AnimationPlayer).get_animation(geste.clip).length
			entry.geste = {"nom": "releve", "clip": geste.clip, "t": minf(float(geste.t), longueur), "fin": RELEVE_FIN,
				"ancre": true, "suite": [], "lance": geste.lance, "vitesse": RELEVE_VITESSE}
	au_sol = ""


func _clip(entry: Dictionary, nom: String) -> StringName:
	var animation: AnimationPlayer = entry.get("animation")
	if animation == null:
		return StringName()
	for clip: StringName in animation.get_animation_list():
		if str(clip).ends_with(nom):
			return clip
	return StringName()
