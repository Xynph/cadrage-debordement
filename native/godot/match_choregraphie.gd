extends RefCounted
## Lecture des pistes du chorégraphe de temps forts (CD_MATCH_CHOREGRAPHE=1).
##
## Le moteur Node (native/engine/match-choregraphe.cjs) envoie avec le temps fort des
## pistes continues : position, cap, vitesse et état d'animation de chaque joueur,
## position et porteur du ballon, au pas de 0,2 s. Cette classe les suit dans la vue 3D
## (interpolation de Catmull-Rom entre deux échantillons). Elle ne décide rien : ni
## trajectoire, ni résultat. Les déplacements gardent les animations par palier de
## vitesse de la vue ; les états (plaquage, chute, relevé, aplati, joie) jouent les
## gestes de la bibliothèque adaptée quand CD_MATCH_ANIMATIONS est défini, sinon une
## pose procédurale simple (buste incliné, joueur au sol, mêlée liée, sauteur levé en touche).
## Les pistes peuvent couvrir tout le temps fort (remise en jeu formée, temps de jeu, jeu au
## pied) : `coupe` vrai, la première image est posée d'emblée (coupe de réalisation), sans raccord.
##
## Sans pistes valides, `charger` rend faux et la vue garde son interpolation habituelle.
## Conception : docs/match-choregraphe-20261112.md.

const VERSION := 2
## Les premières images rejoignent les pistes depuis la place réelle de chaque joueur
## (la scène précédente a pu être mise en scène autrement) : fondu de position.
const RACCORD := 0.6
## Pose procédurale (sans bibliothèque) : inclinaison du buste et abaissement.
const POSES := {
	"plaquage": [1.15, 0.05], "plaquage_rate": [1.25, 0.08], "plaque": [1.0, 0.0], "au_sol": [1.45, 0.12],
	"aplati": [1.35, 0.1], "ruck": [0.55, -0.12], "ramassage": [0.7, -0.1], "se_relever": [0.6, 0.0],
	"melee": [1.1, -0.3], "soutien_saut": [0.3, -0.08], "saut": [0.0, 1.0],
}
## Sauteur de touche : levé et redescendu vite (les leveurs le portent), le reste à vitesse bornée.
const LEVEE := 3.0
const SOL := ["plaquage", "plaquage_rate", "plaque", "au_sol", "aplati"]

var view: Node3D
var actif := false
var fige := false
## Facteur de lecture (la régie peut accélérer les temps forts pour les tests).
var vitesse := 1.0
var temps := 0.0
var duree := 0.0
var pas := 0.2
var marqueur := ""
var aplati_a := -1.0
var _pistes: Dictionary = {}
var _ballon: Dictionary = {}
var _porteurs: Array = []
var _raccord: Dictionary = {}
var _etat_vu: Dictionary = {}
var _chute: Dictionary = {}
var _modeles: Dictionary = {}
## Pose procédurale affichée par joueur (inclinaison, abaissement, instant) : elle change en douceur.
var _poses: Dictionary = {}
var _ballon_depart := Vector3.ZERO
## Raccord du ballon entre deux sources (mains d'un porteur, trajectoire des pistes).
var source_ballon := ""
var source_depuis := 0.0
var source_de := Vector3.ZERO
var coupe_ballon := false


func _init(owner: Node3D) -> void:
	view = owner


## Valide et charge les pistes ; rend faux (et ne change rien) si elles sont inutilisables.
func charger(donnees: Dictionary) -> bool:
	arreter()
	if int(donnees.get("version", 0)) != VERSION or not donnees.get("joueurs") is Array or not donnees.get("ballon") is Dictionary:
		return false
	var coupe := bool(donnees.get("coupe", false))
	var p := float(donnees.get("pas", 0.0))
	var d := float(donnees.get("duree", 0.0))
	if p <= 0.0 or d <= 0.0:
		return false
	var n := int(round(d / p)) + 1
	var pistes: Dictionary = {}
	for joueur: Variant in donnees.joueurs:
		if not joueur is Dictionary:
			return false
		var id := str(joueur.get("id", ""))
		var piste := {}
		for cle in ["x", "y", "v", "cap"]:
			var valeurs: Variant = joueur.get(cle)
			if not valeurs is Array or valeurs.size() != n:
				return false
			piste[cle] = PackedFloat32Array(valeurs)
		piste["etats"] = joueur.get("etats", []) if joueur.get("etats") is Array else []
		piste["side"] = int(joueur.get("side", 0))
		pistes[id] = piste
	var b: Dictionary = donnees.ballon
	for cle in ["x", "y", "h"]:
		if not b.get(cle) is Array or b[cle].size() != n:
			return false
	pistes.make_read_only()
	_pistes = pistes
	_ballon = {"x": PackedFloat32Array(b.x), "y": PackedFloat32Array(b.y), "h": PackedFloat32Array(b.h)}
	_porteurs = b.get("porteurs", []) if b.get("porteurs") is Array else []
	pas = p
	duree = d
	temps = 0.0
	fige = false
	marqueur = str(donnees.get("marqueur", ""))
	aplati_a = -1.0
	for e: Variant in donnees.get("evenements", []):
		if e is Dictionary and str(e.get("type", "")) == "aplati":
			aplati_a = float(e.get("t", -1.0))
	# Écart entre la place réelle de chaque joueur et le début de sa piste (aucun sur une coupe).
	for id: String in _pistes:
		if view._actors.has(id) and not coupe:
			var depart := _point(id, 0.0)
			var actor: Node3D = view._actors[id].node
			_raccord[id] = Vector3(actor.position.x - depart.x, 0.0, actor.position.z - depart.z)
	_ballon_depart = view._ball.global_position if view._ball.visible and not coupe else Vector3.ZERO
	source_ballon = ""
	source_depuis = 0.0
	source_de = _ballon_depart
	# Coupe : le ballon est posé d'emblée à sa place des pistes (pas de raccord depuis l'image d'avant).
	coupe_ballon = coupe
	actif = true
	return true


func arreter() -> void:
	if actif:
		for id: String in _modeles:
			if view._actors.has(id):
				(view._actors[id].model as Node3D).transform = _modeles[id]
	actif = false
	_pistes = {}
	_raccord.clear()
	_etat_vu.clear()
	_chute.clear()
	_modeles.clear()
	_poses.clear()


func stages(id: String) -> bool:
	return actif and _pistes.has(id)


func finie() -> bool:
	return actif and temps >= duree


func avancer(delta: float) -> void:
	if actif and not fige:
		temps = minf(duree, temps + delta * vitesse)


## Valeur d'une piste à l'instant `t` (Catmull-Rom entre les échantillons voisins).
func _valeur(valeurs: PackedFloat32Array, t: float) -> float:
	var n := valeurs.size()
	var u := clampf(t / pas, 0.0, float(n - 1))
	var i := mini(int(floor(u)), n - 2)
	var f := u - float(i)
	var p0 := valeurs[maxi(i - 1, 0)]
	var p1 := valeurs[i]
	var p2 := valeurs[i + 1]
	var p3 := valeurs[mini(i + 2, n - 1)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f)


func _angle(valeurs: PackedFloat32Array, t: float) -> float:
	var n := valeurs.size()
	var u := clampf(t / pas, 0.0, float(n - 1))
	var i := mini(int(floor(u)), n - 2)
	return lerp_angle(valeurs[i], valeurs[i + 1], u - float(i))


## Position au sol (repère de la vue : x - 50, z = y - 35).
func _point(id: String, t: float) -> Vector3:
	var piste: Dictionary = _pistes[id]
	return Vector3(_valeur(piste.x, t) - 50.0, 0.0, _valeur(piste.y, t) - 35.0)


func etat(id: String, t: float = -1.0) -> String:
	var instant := temps if t < 0.0 else t
	var courant := "course"
	for paire: Variant in _pistes[id].etats:
		if paire is Array and paire.size() >= 2 and float(paire[0]) <= instant + 0.0001:
			courant = str(paire[1])
	return courant


func porteur(t: float = -1.0) -> String:
	var instant := temps if t < 0.0 else t
	var courant := ""
	for paire: Variant in _porteurs:
		if paire is Array and paire.size() >= 2 and float(paire[0]) <= instant + 0.0001:
			courant = "" if paire[1] == null else str(paire[1])
	return courant


## Position du ballon d'après sa piste (hauteur comprise).
func ballon_piste(t: float = -1.0) -> Vector3:
	var instant := temps if t < 0.0 else t
	var p := Vector3(_valeur(_ballon.x, instant) - 50.0, maxf(0.1, _valeur(_ballon.h, instant)), _valeur(_ballon.y, instant) - 35.0)
	# Raccord : le ballon part d'où il était à l'écran.
	if _ballon_depart != Vector3.ZERO and instant < RACCORD:
		p = _ballon_depart.lerp(p, smoothstep(0.0, RACCORD, instant))
	return p


## Place et cap d'un joueur suivi ; appelé par la vue à la place de sa trajectoire.
func place(id: String, actor: Node3D) -> void:
	var p := _point(id, temps)
	if _raccord.has(id):
		p += (_raccord[id] as Vector3) * (1.0 - smoothstep(0.0, RACCORD, temps))
	actor.position = p
	var cap := _angle(_pistes[id].cap, temps)
	# Cap du moteur (angle sur le terrain, depuis l'axe des x) vers le lacet de la vue.
	actor.rotation.y = atan2(cos(cap), sin(cap))
	_gestes_de_l_etat(id)


## Geste adapté au changement d'état (bibliothèque CD_MATCH_ANIMATIONS) ; sans lui, la
## pose procédurale de `pose` s'applique.
func _gestes_de_l_etat(id: String) -> void:
	var nom := etat(id)
	var avant := str(_etat_vu.get(id, "course"))
	if nom == avant:
		# Au sol : la fin du clip de chute est tenue tant que la piste dit « au sol ».
		if nom == "au_sol" and _chute.has(id) and view.has_method("geste_adapte") and not view.geste_adapte(id):
			var clip := str(_chute[id])
			var fin: float = view._animations_adaptees.duree(clip) if view._animations_adaptees != null else 0.0
			if fin > 0.0:
				view.jouer_geste(id, clip, maxf(0.0, fin - 0.12), fin)
		return
	_etat_vu[id] = nom
	if not view.has_method("jouer_geste"):
		return
	match nom:
		"plaquage", "plaquage_rate":
			if view.jouer_geste(id, "plaquage", maxf(0.0, view.instant_geste("plaquage") - 0.3)):
				_chute[id] = "plaquage"
		"plaque", "aplati":
			var clip := "plaque_jambes" if nom == "aplati" or id.hash() % 2 == 1 else "plaque_cote"
			if view.jouer_geste(id, clip, maxf(0.0, view.instant_geste(clip) - 0.35)):
				_chute[id] = clip
		"se_relever":
			_chute.erase(id)
			view.jouer_geste(id, "se_relever", 0.2)
		"reception":
			view.jouer_geste(id, "reception", maxf(0.0, view.instant_geste("reception") - 0.3), view.instant_geste("reception") + 0.25)
		"saut":
			view.jouer_geste(id, "reception_haute", maxf(0.0, view.instant_geste("reception_haute") - 0.8), view.instant_geste("reception_haute") + 0.4)
		"lancer":
			view.jouer_geste(id, "lancer", maxf(0.0, view.instant_geste("lancer") - 0.6), view.instant_geste("lancer") + 0.3)
		"jeu_au_pied":
			view.jouer_geste(id, "coup_de_pied", maxf(0.0, view.instant_geste("coup_de_pied") - 0.45), view.instant_geste("coup_de_pied") + 0.35)
		"joie":
			view.jouer_geste(id, "joie_poing" if id == marqueur else "joie", 0.35, 2.4)
		"deception":
			view.jouer_geste(id, "deception", 0.3, 2.6)
		"course":
			_chute.erase(id)


## Pose procédurale des états sans geste adapté ; appelée après l'animation source.
func pose() -> void:
	if not actif:
		return
	for id: String in _pistes:
		if not view._actors.has(id):
			continue
		var entry: Dictionary = view._actors[id]
		var modele: Node3D = entry.model
		if not _modeles.has(id):
			_modeles[id] = modele.transform
		modele.transform = _modeles[id]
		var nom := etat(id)
		var voulu: Array = [0.0, 0.0]
		if POSES.has(nom) and not (view.has_method("geste_adapte") and view.geste_adapte(id)):
			voulu = POSES[nom]
			if nom == "se_relever":
				voulu = [0.0, 0.0]
		# Le sauteur est levé même quand un geste de prise joue ses bras.
		if nom == "saut":
			voulu = [0.0, POSES.saut[1]]
		# La pose rejoint la pose voulue à vitesse bornée : ni bascule ni redressement d'un coup.
		var vu: Array = _poses.get(id, [0.0, 0.0, temps])
		var dt := clampf(temps - float(vu[2]), 0.0, 0.1)
		var pitch := move_toward(float(vu[0]), float(voulu[0]), 5.0 * dt)
		var lift := move_toward(float(vu[1]), float(voulu[1]), (LEVEE if nom == "saut" or float(vu[1]) > 0.2 else 0.6) * dt)
		if nom == "se_relever":
			pitch = move_toward(float(vu[0]), 0.0, 1.6 * dt)
		_poses[id] = [pitch, lift, temps]
		modele.rotation.x = pitch
		modele.position.y += lift
