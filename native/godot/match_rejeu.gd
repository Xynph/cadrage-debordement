extends RefCounted
## Ralenti de l'essai (19 novembre 2026, idée validée par Léo) : comme à la télévision, quelques
## secondes après l'aplati, la vue rejoue au ralenti (VITESSE) la fin de l'action, AVANT s avant
## l'aplati et APRES s après, sous un autre angle (caméra latérale qui suit le ballon,
## match_cadrage.gd `plan_rejeu`, relevée à HAUTEUR m par `plan_ralenti`), puis revient à la vue
## normale. Présentation seule.
##
## Fiabilité : pendant un temps fort qui contient un essai (la régie le demande), la vue enregistre
## les poses réellement montrées, CADENCE par seconde de vue : place et cap de chaque joueur,
## transformée de son modèle, pose de chaque os de son squelette, ballon, figurants inscrits
## (l'arbitre). Pendant le ralenti, rien de la vue n'avance (sa mise à jour est suspendue, les
## figurants aussi) : seules les poses enregistrées sont reposées. À la fin, ou dès qu'il est abrégé,
## l'état exact d'avant le ralenti (poses, ballon, caméra) est remis : célébration et transformation
## reprennent exactement où elles en étaient.

const Cadrage = preload("res://match_cadrage.gd")
const Gestes = preload("res://match_gestes.gd")

## Intervalle d'enregistrement, en secondes de vue (ralenti de l'aplati compris).
const CADENCE := 1.0 / 30.0
## Fenêtre rejouée autour de l'aplati (secondes de vue) : AVANT + APRES = 1,9 s, soit 3,8 s à VITESSE.
const AVANT := 1.6
const APRES := 0.3
const VITESSE := 0.5
## Fenêtre trop courte (essai juste après une coupe) : pas de ralenti.
const SOURCE_MIN := 0.6
## Un joueur qui bouge de plus de SAUT m d'un enregistrement à l'autre a été replacé (coupe) : ce qui
## précède n'est pas rejoué.
const SAUT := 2.5
## Lissage de la caméra du ralenti (s) : place et point visé.
const CAMERA_LISSAGE := 0.35
const VISEE_LISSAGE := 0.12
## Au-delà de la durée prévue, plus cette marge (s réelles), le ralenti s'arrête de lui-même.
const MARGE := 1.0
## Angle du ralenti : retraits essayés (m en deçà du ballon), préférence pour l'angle par défaut (gêne
## ajoutée à l'autre côté ; un dixième par mètre de retrait en plus ou en moins). La gêne couvre toute
## la fenêtre rejouée (AVANT s avant l'aplati : porteur masqué et premier plan compris depuis le
## 19/11/2026) et pèse surtout l'aplati et l'image finale (voir
## `meilleur_angle`). Retrait négatif : caméra au-delà du ballon, dans l'en-but, qui regarde vers le
## terrain (essai au pied des poteaux : les montants restent derrière le marqueur). Retraits
## intermédiaires : un ballon à un mètre d'un montant est masqué sous presque tous les angles d'un
## même côté, chaque mètre de plus est une chance de passer à côté de la protection.
const RETRAITS := [4.0, 8.0, 12.0, 0.0, -6.0, 6.0, 2.0, 16.0, -3.0]
const PREFERENCE := 0.3
## Hauteur de la caméra du ralenti (m ; 19/11/2026, film mfin/film2 images 0163-0170 et 0310-0313).
## Au ras de la pelouse (Cadrage.REJEU_HAUTEUR, 1,1 m), les épaules d'un défenseur et un joueur tout
## près de l'objectif remplissaient l'image. À 2,8 m : la visée passe au-dessus d'un joueur debout
## dans les deux premiers cinquièmes du chemin vers le marqueur (`masque_ralenti`) et un joueur à
## moins de 2 m de l'objectif sort par le bas de l'image (`encombrement`). Le regard reste rasant
## (moins de 10° de plongée à 11 m). Une protection de poteau (1,6 m) collée au marqueur le cache à
## toute hauteur raisonnable (il faudrait plus de 30 m) : seuls le côté et le retrait l'évitent.
const HAUTEUR := 2.8

var view: Node3D
## Enregistrement demandé par la régie (temps fort avec un essai).
var enregistre := false
## Poses enregistrées : {"t": secondes de vue, "e": {clé: pose}, "b": [transformée, visible]}.
var tampon: Array[Dictionary] = []
## Temps de vue écoulé depuis le début de l'enregistrement.
var temps := 0.0
var _depuis := INF
## Instant de l'aplati (temps de vue), posé par la régie.
var _repere := 0.0
var _avec_repere := false
## Fenêtre découpée autour de l'aplati : ce qui sera rejoué.
var clip: Array[Dictionary] = []
## Figurants (arbitre) : {"noeud", "modele", "squelette"}.
var figurants: Array[Dictionary] = []
## Lecture en cours : position dans la fenêtre (s de vue), vitesse, durée de la fenêtre, secondes
## réelles écoulées.
var actif := false
var lecture := 0.0
var vitesse := VITESSE
var duree_source := 0.0
var ecoule := 0.0
## Contrôles (tests, suivi de la régie) : hauteur de la caméra du ralenti (HAUTEUR), plus grand écart entre
## l'état remis à la fin et l'état d'avant le ralenti (0 : identique).
var hauteur_camera := 0.0
var ecart_restitution := 0.0
var _avant: Dictionary = {}
var _camera_avant: Dictionary = {}
var _process_avant: Array = []
var _cibles: Dictionary = {}
var _cote := Vector2.ONE
var _retrait := Cadrage.REJEU_RETRAIT
## Gêne de l'angle retenu (`meilleur_angle` ; 8 ou plus : marqueur masqué à l'aplati ; contrôle des tests).
var gene_angle := 0.0
var _curseur := 0
var _ballon := Vector3.ZERO
var _cam := Vector3.ZERO
var _cam_v := Vector3.ZERO
var _vise := Vector3.ZERO
var _vise_v := Vector3.ZERO


func _init(owner: Node3D) -> void:
	view = owner


## Figurant à enregistrer et à figer pendant le ralenti (l'arbitre de la régie).
func inscrire(noeud: Node3D, modele: Node3D, squelette: Skeleton3D) -> void:
	if actif or not is_instance_valid(noeud):
		return
	for k in range(figurants.size() - 1, -1, -1):
		if not is_instance_valid(figurants[k].noeud):
			figurants.remove_at(k)
		elif figurants[k].noeud == noeud:
			return
	figurants.append({"noeud": noeud, "modele": modele, "squelette": squelette})


func activer(on: bool) -> void:
	enregistre = on
	vider()


func vider() -> void:
	tampon.clear()
	clip.clear()
	_avec_repere = false
	_depuis = INF
	temps = 0.0


## Essai aplati à l'écran : la fenêtre du ralenti se cale sur cet instant. Faux sans enregistrement.
func reperer() -> bool:
	if not enregistre or actif or tampon.is_empty():
		return false
	clip.clear()
	_avec_repere = true
	_repere = temps
	return true


## Fin d'une image de la vue (poses définitives) : `delta` en secondes de vue ; `coupe` : la vue
## vient de couper (joueurs replacés), rien d'avant n'est rejoué.
func enregistrer(delta: float, coupe: bool) -> void:
	if not enregistre or actif:
		return
	temps += maxf(delta, 0.0)
	if not clip.is_empty():
		return
	if coupe:
		_couper()
	_depuis += maxf(delta, 0.0)
	if _depuis < CADENCE and not tampon.is_empty():
		return
	_depuis = 0.0
	var pose := capturer()
	pose["t"] = temps
	if not tampon.is_empty() and _saut(tampon[-1], pose):
		_couper()
	tampon.append(pose)
	# Mémoire bornée : la fenêtre à venir, plus une pose avant elle (interpolation).
	var plus_ancien := _repere - AVANT if _avec_repere else temps - AVANT - APRES - 0.2
	while tampon.size() > 2 and float(tampon[1].t) <= plus_ancien:
		tampon.pop_front()
	if _avec_repere and temps >= _repere + APRES:
		_decouper()


func _couper() -> void:
	if _avec_repere and clip.is_empty():
		_decouper()
	tampon.clear()


func _decouper() -> void:
	clip.clear()
	for pose: Dictionary in tampon:
		if float(pose.t) >= _repere - AVANT - CADENCE and float(pose.t) <= _repere + APRES + CADENCE:
			clip.append(pose)
	tampon.clear()


func _saut(a: Dictionary, b: Dictionary) -> bool:
	var avant: Dictionary = a.e
	for cle: String in b.e:
		if avant.has(cle) and ((avant[cle][0] as Transform3D).origin - (b.e[cle][0] as Transform3D).origin).length() > SAUT:
			return true
	return false


## Ce que la vue montre à cet instant : chaque joueur, chaque figurant, le ballon.
func capturer() -> Dictionary:
	var entites := {}
	for id: String in view._actors:
		var entry: Dictionary = view._actors[id]
		entites[id] = _pose(entry.node, entry.model, entry.rig)
	for k in figurants.size():
		var f: Dictionary = figurants[k]
		if is_instance_valid(f.noeud):
			entites["#%d" % k] = _pose(f.noeud, f.modele, f.squelette)
	var ballon: Node3D = view._ball
	return {"e": entites, "b": [ballon.transform, ballon.visible]}


static func _pose(noeud: Node3D, modele: Variant, squelette: Variant) -> Array:
	var places := PackedVector3Array()
	var tours: Array[Quaternion] = []
	var echelles := PackedVector3Array()
	if is_instance_valid(squelette) and squelette is Skeleton3D:
		var rig: Skeleton3D = squelette
		var n := rig.get_bone_count()
		places.resize(n)
		tours.resize(n)
		echelles.resize(n)
		for i in n:
			places[i] = rig.get_bone_pose_position(i)
			tours[i] = rig.get_bone_pose_rotation(i)
			echelles[i] = rig.get_bone_pose_scale(i)
	var forme := Transform3D.IDENTITY
	# Place, rotation (angles tels que le code de la vue les a posés) et échelle : remis tels quels.
	var detail_modele: Array = []
	if is_instance_valid(modele) and modele is Node3D:
		var m: Node3D = modele
		forme = m.transform
		detail_modele = [m.position, m.rotation, m.scale]
	return [noeud.transform, forme, noeud.visible, places, tours, echelles, [noeud.position, noeud.rotation, noeud.scale], detail_modele]


## Ralenti : la fenêtre enregistrée autour de l'aplati, rejouée à `facteur` de la vitesse réelle.
## Faux sans fenêtre utilisable (rien d'enregistré, coupe juste avant l'essai).
func commencer(facteur: float) -> bool:
	if actif or not enregistre or not is_finite(facteur) or facteur <= 0.0:
		return false
	if clip.is_empty() and _avec_repere:
		_decouper()
	if clip.size() < 2:
		return false
	duree_source = float(clip[-1].t) - float(clip[0].t)
	if duree_source < SOURCE_MIN:
		return false
	vitesse = clampf(facteur, 0.05, 4.0)
	_cibles = {}
	for id: String in view._actors:
		var entry: Dictionary = view._actors[id]
		_cibles[id] = [entry.node, entry.model, entry.rig]
	for k in figurants.size():
		var f: Dictionary = figurants[k]
		if is_instance_valid(f.noeud):
			_cibles["#%d" % k] = [f.noeud, f.modele, f.squelette]
	_avant = capturer()
	var camera: Camera3D = view._camera
	_camera_avant = {"transform": camera.transform, "fov": camera.fov, "size": camera.size, "projection": camera.projection}
	# Figurants figés : leur propre mise à jour (arbitre) ne tourne pas pendant le ralenti.
	_process_avant = []
	for f: Dictionary in figurants:
		var figurant: Node = f.noeud if is_instance_valid(f.noeud) else null
		_process_avant.append(figurant.process_mode if figurant != null else Node.PROCESS_MODE_INHERIT)
		if figurant != null:
			figurant.process_mode = Node.PROCESS_MODE_DISABLED
	actif = true
	lecture = 0.0
	ecoule = 0.0
	_curseur = 0
	ecart_restitution = 0.0
	_ballon = _ballon_a(float(clip[0].t))
	_cote = Cadrage.cote_rejeu(_ballon_a(_repere if _avec_repere else float(clip[-1].t)))
	_choisir_angle()
	_montrer(0.0)
	_filmer(0.0)
	return true


## Une image réelle de ralenti (`delta` en secondes réelles). Faux quand il est fini (état remis).
func lire(delta: float) -> bool:
	if not actif:
		return false
	ecoule += maxf(delta, 0.0)
	lecture += maxf(delta, 0.0) * vitesse
	if lecture >= duree_source or ecoule > duree_source / vitesse + MARGE:
		finir()
		return false
	_montrer(lecture)
	_filmer(delta)
	return true


## Fin du ralenti (à son terme ou abrégé) : l'état exact d'avant est remis. Un ralenti par essai.
func finir() -> void:
	if not actif:
		return
	actif = false
	_appliquer(_avant)
	var camera: Camera3D = view._camera
	if is_instance_valid(camera) and not _camera_avant.is_empty():
		camera.projection = _camera_avant["projection"]
		camera.transform = _camera_avant["transform"]
		camera.fov = _camera_avant["fov"]
		camera.size = _camera_avant["size"]
	for k in mini(figurants.size(), _process_avant.size()):
		if is_instance_valid(figurants[k].noeud):
			var figurant: Node = figurants[k].noeud
			figurant.process_mode = _process_avant[k]
	ecart_restitution = ecart(_avant, capturer())
	_avant = {}
	_camera_avant = {}
	_cibles = {}
	clip.clear()
	_avec_repere = false


## Plus grand écart entre deux états capturés (composantes des transformées, des places, rotations et
## échelles des os) : 0 quand ils sont identiques, INF si un joueur, sa visibilité ou le ballon diffère.
static func ecart(a: Dictionary, b: Dictionary) -> float:
	var pire := 0.0
	if a.is_empty() or b.is_empty():
		return INF
	for cle: String in a.e:
		if not b.e.has(cle):
			return INF
		var x: Array = a.e[cle]
		var y: Array = b.e[cle]
		if bool(x[2]) != bool(y[2]):
			return INF
		pire = maxf(pire, maxf(_ecart_forme(x[0], y[0]), _ecart_forme(x[1], y[1])))
		var places_x: PackedVector3Array = x[3]
		var places_y: PackedVector3Array = y[3]
		var tours_x: Array = x[4]
		var tours_y: Array = y[4]
		var echelles_x: PackedVector3Array = x[5]
		var echelles_y: PackedVector3Array = y[5]
		if tours_x.size() != tours_y.size() or places_x.size() != places_y.size():
			return INF
		for i in tours_x.size():
			var qa: Quaternion = tours_x[i]
			var qb: Quaternion = tours_y[i]
			# Même rotation au signe près (q et -q).
			pire = maxf(pire, minf((qa - qb).length(), (qa + qb).length()))
			pire = maxf(pire, maxf((places_x[i] - places_y[i]).length(), (echelles_x[i] - echelles_y[i]).length()))
	if bool(a.b[1]) != bool(b.b[1]):
		return INF
	return maxf(pire, _ecart_forme(a.b[0], b.b[0]))


static func _ecart_forme(a: Transform3D, b: Transform3D) -> float:
	return maxf(maxf((a.origin - b.origin).length(), (a.basis.x - b.basis.x).length()), maxf((a.basis.y - b.basis.y).length(), (a.basis.z - b.basis.z).length()))


## Pose la fenêtre à `t` secondes de son début (interpolée entre deux enregistrements).
func _montrer(t: float) -> void:
	var absolu := float(clip[0].t) + t
	while _curseur < clip.size() - 2 and float(clip[_curseur + 1].t) <= absolu:
		_curseur += 1
	var a: Dictionary = clip[_curseur]
	var b: Dictionary = clip[mini(_curseur + 1, clip.size() - 1)]
	var ecart_t := float(b.t) - float(a.t)
	var w := clampf((absolu - float(a.t)) / ecart_t, 0.0, 1.0) if ecart_t > 0.0001 else 0.0
	for cle: String in _cibles:
		var cible: Array = _cibles[cle]
		if not is_instance_valid(cible[0]):
			continue
		if not a.e.has(cle):
			# Absent de l'action rejouée (arrivé après) : caché le temps du ralenti.
			var absent: Node3D = cible[0]
			absent.visible = false
			continue
		_poser(cible, a.e[cle], b.e.get(cle, a.e[cle]), w)
	var ballon: Node3D = view._ball
	var de: Transform3D = a.b[0]
	ballon.transform = de.interpolate_with(b.b[0], w) if w > 0.0 else de
	ballon.visible = bool(a.b[1])
	if ballon.visible:
		_ballon = ballon.position


## Pose exacte d'un état capturé (fin du ralenti).
func _appliquer(etat: Dictionary) -> void:
	if etat.is_empty():
		return
	for cle: String in _cibles:
		var cible: Array = _cibles[cle]
		if is_instance_valid(cible[0]) and etat.e.has(cle):
			_poser(cible, etat.e[cle], etat.e[cle], 0.0)
	view._ball.transform = etat.b[0]
	view._ball.visible = bool(etat.b[1])


static func _poser(cible: Array, a: Array, b: Array, w: float) -> void:
	var noeud: Node3D = cible[0]
	if w > 0.0:
		noeud.transform = (a[0] as Transform3D).interpolate_with(b[0], w)
	else:
		_remettre(noeud, a[0], a[6])
	noeud.visible = bool(a[2])
	if is_instance_valid(cible[1]) and cible[1] is Node3D:
		var modele: Node3D = cible[1]
		if w > 0.0:
			modele.transform = (a[1] as Transform3D).interpolate_with(b[1], w)
		else:
			_remettre(modele, a[1], a[7])
	if not (is_instance_valid(cible[2]) and cible[2] is Skeleton3D):
		return
	var rig: Skeleton3D = cible[2]
	var places_a: PackedVector3Array = a[3]
	var places_b: PackedVector3Array = b[3]
	var tours_a: Array = a[4]
	var tours_b: Array = b[4]
	var echelles_a: PackedVector3Array = a[5]
	var echelles_b: PackedVector3Array = b[5]
	var n := mini(rig.get_bone_count(), places_a.size())
	var melange := w > 0.0 and places_b.size() == places_a.size()
	for i in n:
		if melange:
			rig.set_bone_pose_position(i, places_a[i].lerp(places_b[i], w))
			rig.set_bone_pose_rotation(i, (tours_a[i] as Quaternion).normalized().slerp((tours_b[i] as Quaternion).normalized(), w))
			rig.set_bone_pose_scale(i, echelles_a[i].lerp(echelles_b[i], w))
		else:
			rig.set_bone_pose_position(i, places_a[i])
			rig.set_bone_pose_rotation(i, tours_a[i])
			rig.set_bone_pose_scale(i, echelles_a[i])


## Pose exacte d'un nœud : par sa place, ses angles et son échelle quand ils sont connus (les angles
## restent ceux que le code de la vue avait posés), sinon par sa transformée.
static func _remettre(noeud: Node3D, forme: Transform3D, detail: Array) -> void:
	if detail.size() == 3:
		noeud.rotation = detail[1]
		noeud.scale = detail[2]
		noeud.position = detail[0]
	else:
		noeud.transform = forme


## Place du ballon dans la fenêtre à l'instant de vue `t` (dernière place visible connue).
func _ballon_a(t: float) -> Vector3:
	var place: Vector3 = (clip[0].b[0] as Transform3D).origin
	for pose: Dictionary in clip:
		if bool(pose.b[1]):
			place = (pose.b[0] as Transform3D).origin
		if float(pose.t) >= t:
			break
	return place


## Angle du ralenti : côté et retrait de la caméra qui masquent le moins le marqueur, mesurés sur
## les poses de la fin de la fenêtre (l'aplati) ; à gêne égale, l'angle par défaut. Évite qu'un
## défenseur aligné sur la ligne d'en-but remplisse l'image au moment de l'aplati.
func _choisir_angle() -> void:
	var debut := (_repere if _avec_repere else float(clip[-1].t)) - AVANT
	var choix := meilleur_angle(clip, debut, _cote)
	_cote = choix.cote
	_retrait = choix.retrait
	gene_angle = choix.gene


## Meilleur angle pour les poses `poses` (format du tampon) à partir de `debut` (s de vue ; l'aplati
## est à `debut` + AVANT) : côté et retrait de moindre gêne ; à gêne égale, l'angle par défaut.
## Gêne d'un angle (19/11/2026, film après PR #962 : marqueur aplati derrière la protection d'un
## poteau, défenseur en gros plan sur l'image finale ; la moyenne sur 1,9 s diluait ces 0,3 s) :
##  - la plus forte de la moyenne sur la fenêtre et de FIN_POIDS fois la pire image des FIN dernières
##    secondes (joueurs et montants, Cadrage.gene_rejeu et gene_poteaux) ;
##  - VETO si le marqueur est masqué (Cadrage.masque_rejeu) à l'aplati ou sur l'image finale, plus
##    VETO fois la part des images masquées de CLE s avant l'aplati jusqu'à la fin ;
##  - PROCHE fois le pire premier plan (Cadrage.premier_plan_rejeu) de la dernière seconde ;
##  - le reste de l'action (du début de la fenêtre jusqu'à CLE s avant l'aplati, ou jusqu'à la dernière
##    seconde pour le premier plan) : ACTION_VETO fois la part des images où le marqueur est masqué,
##    plus ACTION_PROCHE fois le premier plan moyen, le tout plafonné à ACTION_PLAFOND ;
##  - les préférences (autre côté, retrait différent).
## 19 novembre 2026 : film mf3 (images 0041, 0152, 0198, 0320) : angle propre à l'aplati, mais au début
## et au milieu du ralenti, la protection d'un poteau ou un défenseur en gros plan au bord de l'image
## cachait le porteur ; ces images ne comptaient que dans la moyenne de gêne, trop faible face à la
## préférence pour l'angle par défaut. L'action entière compte désormais, mais moins que l'aplati :
## ACTION_PLAFOND reste sous VETO, un angle masqué à l'aplati perd toujours face à un angle propre à
## l'aplati gêné plus tôt (à gênes de fin comparables).
## 19 novembre 2026, second film (mfin, images 0142, 0146, 0338) : porteur encore caché en pleine course
## par la protection d'un poteau (0,42 m de côté, haute de 1,6 m : POTEAU_PROTECTION la modélise déjà).
## Deux causes : ACTION_VETO (4) trop faible (huit images masquées sur quarante coûtaient 0,8, autant
## que deux pas de retrait ; essai entre les poteaux : caméra dans l'en-but et montant devant le
## porteur) ; et la caméra réellement filmée, amortie (CAMERA_LISSAGE), traîne derrière son plan quand
## le porteur court vite : la ligne de visée passe à côté de celle mesurée. Désormais ACTION_VETO vaut
## 12 (une image masquée sur quarante coûte 0,3, la préférence d'angle), ACTION_PROCHE 3 (un joueur
## à 4 m tout du long : 2,5) ; le marqueur est jugé masqué, et le premier plan mesuré, sous la caméra
## du plan comme sous la caméra filmée (`cameras_filmees`) : on n'ajoute que des pénalités, les
## garanties à l'aplati restent. ACTION_PLAFOND (7) reste sous VETO.
## 19 novembre 2026, troisième film (mfin/film2, images 0163-0170 et 0310-0313) : marqueur aplati contre
## un poteau, caché par la protection et un défenseur ; un joueur tout près de l'objectif occupait le
## tiers de l'image pendant l'action (pesé seulement en moyenne, ACTION_PROCHE, dilué sur la fenêtre).
## Désormais la caméra est relevée (HAUTEUR) ; un joueur debout que la visée survole ne masque plus
## (`masque_ralenti` ; montants et protections restent jugés comme avant, Cadrage.masque_rejeu) ; et
## ENCOMBRE fois la pire part de l'image couverte par un joueur proche (`encombrement`, caméra du plan
## ou filmée, sur toute la fenêtre), plafonnée à ENCOMBRE_PLAFOND (sous VETO : un angle masqué à
## l'aplati perd toujours face à un angle propre encombré).
## 19 novembre 2026, quatrième film (mfin/film4) : aplati net, mais (images 0361-0363, 0405, 0472-0478)
## porteur caché par un montant, sa protection ou un défenseur dans la fin de course, quelques images
## seulement (diluées dans ACTION_VETO) ; gros plans encore présents (0365, 0408, 0582 : joueur ou
## protection de poteau à quelques mètres) ; caméra très reculée, porteur minuscule (0472, 0528).
## Désormais :
##  - fin de course (COURSE s avant l'aplati, jusqu'aux images clés) : la PIRE image masquée compte,
##    COURSE_VETO fois un poids qui croît de 0 (COURSE s avant) à 1 (à l'aplati) ; ajoutée à l'action,
##    toujours sous ACTION_PLAFOND (un angle masqué à l'aplati perd toujours) ;
##  - `encombrement` compte aussi les poteaux (protection et montant) et un corps occupant
##    ENCOMBRE_PLEINE de la hauteur de l'image compte pour toute sa largeur ;
##  - porteur trop petit : LOIN_POIDS par mètre de distance horizontale caméra-ballon au-delà de
##    LOIN_DEBUT (pire image de la fin de course), plafonné à LOIN_PLAFOND (retrait de 12 m : 0,8 ;
##    de 16 m : 1,9).
## Aucun angle propre : le moins gêné reste retenu.
const FIN := 0.6
const FIN_POIDS := 1.5
const CLE := 0.2
const VETO := 8.0
const PROCHE := 4.0
const PROCHE_FENETRE := 1.0
const ACTION_VETO := 12.0
const ACTION_PROCHE := 3.0
const ACTION_PLAFOND := 7.0
const ENCOMBRE := 25.0
const ENCOMBRE_PLAFOND := 4.0
const COURSE := 1.5
const COURSE_VETO := 6.0
const LOIN_DEBUT := 14.0
const LOIN_POIDS := 0.35
const LOIN_PLAFOND := 2.5
static func meilleur_angle(poses: Array, debut: float, cote_defaut: Vector2) -> Dictionary:
	var prepa := _preparer(poses, debut)
	var meilleur := {"cote": cote_defaut, "retrait": Cadrage.REJEU_RETRAIT, "gene": INF}
	for lateral: float in [cote_defaut.y, -cote_defaut.y]:
		for retrait: float in RETRAITS:
			var cote := Vector2(cote_defaut.x, lateral)
			var gene := _gene(prepa, cote_defaut, cote, retrait)
			if gene < float(meilleur.gene) - 0.001:
				meilleur = {"cote": cote, "retrait": retrait, "gene": gene}
	return meilleur


## Gêne (voir `meilleur_angle`) d'un angle donné (`cote`, `retrait`) ; contrôle des tests.
static func gene_de(poses: Array, debut: float, cote_defaut: Vector2, cote: Vector2, retrait: float) -> float:
	return _gene(_preparer(poses, debut), cote_defaut, cote, retrait)


## Poses retenues à partir de `debut` (places des personnes visibles, une fois pour tous les angles),
## image de l'aplati (la première à partir de `debut` + AVANT, la dernière si la fenêtre s'arrête
## avant) et instant de la dernière image.
static func _preparer(poses: Array, debut: float) -> Dictionary:
	var aplati := debut + AVANT
	var dernier := -INF
	for pose: Dictionary in poses:
		dernier = maxf(dernier, float(pose.t))
	var retenues: Array[Dictionary] = []
	for pose: Dictionary in poses:
		if float(pose.t) < debut: continue
		var places := PackedVector3Array()
		for cle: String in pose.e:
			if bool(pose.e[cle][2]): places.append((pose.e[cle][0] as Transform3D).origin)
		retenues.append({"t": float(pose.t), "ballon": (pose.b[0] as Transform3D).origin, "places": places})
	var i_aplati := retenues.size() - 1
	for i in retenues.size():
		if float(retenues[i].t) >= aplati - 0.001:
			i_aplati = i
			break
	return {"retenues": retenues, "i_aplati": i_aplati, "aplati": aplati, "dernier": dernier}


static func _gene(prepa: Dictionary, cote_defaut: Vector2, cote: Vector2, retrait: float) -> float:
	var retenues: Array[Dictionary] = prepa.retenues
	var i_aplati: int = prepa.i_aplati
	var aplati: float = prepa.aplati
	var dernier: float = prepa.dernier
	var gene := 0.0 if cote.y == cote_defaut.y else PREFERENCE
	gene += absf(retrait - Cadrage.REJEU_RETRAIT) * PREFERENCE * 0.1
	var somme := 0.0
	var pire_fin := 0.0
	var cles := 0
	var masques := 0
	var veto := 0.0
	var premier_plan := 0.0
	var pire_encombre := 0.0
	var pire_course := 0.0
	var pire_portee := 0.0
	# Reste de l'action (avant les images clés et avant la dernière seconde).
	var action_images := 0
	var action_masques := 0
	var action_plans := 0
	var action_premier_plan := 0.0
	var filmees := cameras_filmees(retenues, cote, retrait)
	for i in retenues.size():
		var r: Dictionary = retenues[i]
		var t := float(r.t)
		var places: PackedVector3Array = r.places
		var plan := plan_ralenti(r.ballon, cote, retrait)
		# Même plan, depuis la caméra amortie que le spectateur voit réellement.
		var filme := {"camera": filmees[i], "vise": plan.vise, "champ": plan.champ}
		var g := Cadrage.gene_rejeu(plan, places) + Cadrage.gene_poteaux(plan)
		somme += g
		if t >= dernier - FIN - 0.001:
			pire_fin = maxf(pire_fin, g)
		var avant_plan := maxf(Cadrage.premier_plan_rejeu(plan, places), Cadrage.premier_plan_rejeu(filme, places))
		if t >= dernier - PROCHE_FENETRE - 0.001:
			premier_plan = maxf(premier_plan, avant_plan)
		else:
			action_plans += 1
			action_premier_plan += avant_plan
		pire_encombre = maxf(pire_encombre, maxf(encombrement(plan, places), encombrement(filme, places)))
		var cache := masque_ralenti(plan, places) or masque_ralenti(filme, places)
		var ballon: Vector3 = r.ballon
		if t >= aplati - COURSE - 0.001:
			for camera: Vector3 in [plan.camera, filmees[i]]:
				pire_portee = maxf(pire_portee, Vector2(ballon.x - camera.x, ballon.z - camera.z).length())
		if t >= aplati - CLE - 0.001 or i == i_aplati:
			cles += 1
			if cache:
				masques += 1
				if i == i_aplati or i == retenues.size() - 1:
					veto += VETO
		else:
			action_images += 1
			if cache:
				action_masques += 1
				if t >= aplati - COURSE - 0.001:
					pire_course = maxf(pire_course, COURSE_VETO * clampf(1.0 - (aplati - t) / COURSE, 0.0, 1.0))
	gene += maxf(somme / maxf(1.0, float(retenues.size())), FIN_POIDS * pire_fin)
	gene += veto + VETO * float(masques) / maxf(1.0, float(cles)) + PROCHE * premier_plan
	var action := ACTION_VETO * float(action_masques) / maxf(1.0, float(action_images))
	action += ACTION_PROCHE * action_premier_plan / maxf(1.0, float(action_plans))
	gene += minf(action + pire_course, ACTION_PLAFOND)
	gene += minf(ENCOMBRE * pire_encombre, ENCOMBRE_PLAFOND)
	gene += minf(maxf(0.0, pire_portee - LOIN_DEBUT) * LOIN_POIDS, LOIN_PLAFOND)
	return gene


## Plan du ralenti (Cadrage.plan_rejeu : côté, retrait, bornes, montants), caméra relevée à HAUTEUR m.
static func plan_ralenti(ballon: Vector3, cote: Vector2, retrait: float = Cadrage.REJEU_RETRAIT) -> Dictionary:
	var vu: Dictionary = Cadrage.plan_rejeu(ballon, cote, retrait)
	var camera: Vector3 = vu.camera
	camera.y = HAUTEUR
	vu["camera"] = camera
	return vu


## Marqueur masqué (Cadrage.masque_rejeu) compte tenu de la hauteur de la caméra : un joueur debout
## (JOUEUR_HAUT m, tête comprise) sous la ligne qui va de l'objectif au haut du marqueur couché (CIBLE m)
## ne masque plus. Montants et protections : jugés comme avant (montant de 12 m, protection collée au
## marqueur : la hauteur n'y change rien).
const CIBLE := 0.35
const JOUEUR_HAUT := 1.8
static func masque_ralenti(vu: Dictionary, places: PackedVector3Array) -> bool:
	return Cadrage.masque_rejeu(vu, _sous_la_visee(vu, places))


## Personnes de `places` que la ligne de visée ne survole pas (toutes avec une caméra plus basse
## qu'un joueur).
static func _sous_la_visee(vu: Dictionary, places: PackedVector3Array) -> PackedVector3Array:
	var camera: Vector3 = vu.camera
	var vise: Vector3 = vu.vise
	var regard := Vector2(vise.x - camera.x, vise.z - camera.z)
	var portee := regard.length()
	if portee < 0.5 or camera.y <= JOUEUR_HAUT:
		return places
	regard /= portee
	var restent := PackedVector3Array()
	for p: Vector3 in places:
		var loin := Vector2(p.x - camera.x, p.z - camera.z).dot(regard)
		if lerpf(camera.y, CIBLE, clampf(loin / portee, 0.0, 1.0)) < JOUEUR_HAUT:
			restent.append(p)
	return restent


## Encombrement de l'image (0 : aucun gros plan) : pour chaque joueur à moins de ENCOMBRE_LOIN m de
## l'objectif (et à plus de 1,5 m en deçà du ballon : pas le marqueur ni son plaqueur), la part de
## l'image qu'il couvre : largeur de son corps (Cadrage.REJEU_CARRURE de demi-largeur) dans le champ,
## bord de l'image compris (un joueur à cheval sur le bord compte pour sa partie visible), fois la part
## de la hauteur de l'image qu'il occupe (corps de ENCOMBRE_TAILLE m, image qui plonge vers le point
## visé : un joueur tout près d'une caméra relevée sort par le bas) ; somme. Image 16/9 (ASPECT).
## 19/11/2026 (film2, image 0165) : un joueur à 2 ou 3 m d'une caméra à 1,1 m couvrait le tiers droit.
## 19/11/2026 (film4, images 0365, 0408, 0475, 0582) : un joueur à 4 ou 5 m, 12 à 15 % de la largeur
## sur la moitié de la hauteur, ou une protection de poteau au premier plan, pesaient trop peu. Un
## objet qui occupe ENCOMBRE_PLEINE de la hauteur de l'image compte désormais pour toute sa largeur ;
## les poteaux comptent aussi : protection (PROTECTION_DEMI m de demi-largeur vue en biais, haute de
## PROTECTION_HAUT m) et montant au-dessus (MONTANT_DEMI m, jusqu'à MONTANT_HAUT m).
const ENCOMBRE_LOIN := 6.5
const ENCOMBRE_TAILLE := 1.85
const ENCOMBRE_PLEINE := 0.4
const PROTECTION_DEMI := 0.3
const PROTECTION_HAUT := 1.6
const MONTANT_DEMI := 0.12
const MONTANT_HAUT := 12.0
const ASPECT := 16.0 / 9.0
static func encombrement(vu: Dictionary, places: PackedVector3Array) -> float:
	var camera: Vector3 = vu.camera
	var vise: Vector3 = vu.vise
	var regard := Vector2(vise.x - camera.x, vise.z - camera.z)
	var portee := regard.length()
	if portee < 0.5: return 0.0
	regard /= portee
	var demi_v := deg_to_rad(float(vu.get("champ", Cadrage.REJEU_CHAMP))) * 0.5
	var cadre := {"camera": camera, "regard": regard, "portee": portee, "demi_v": demi_v,
		"demi_h": atan(tan(demi_v) * ASPECT), "tangage": atan2(camera.y - vise.y, portee)}
	var somme := 0.0
	for p: Vector3 in places:
		somme += _part_image(cadre, p, Cadrage.REJEU_CARRURE, 0.0, ENCOMBRE_TAILLE)
	for x: float in [-50.0, 50.0]:
		for z: float in [-Cadrage.POTEAUX_Z, Cadrage.POTEAUX_Z]:
			var pied := Vector3(x, 0.0, z)
			somme += _part_image(cadre, pied, PROTECTION_DEMI, 0.0, PROTECTION_HAUT)
			somme += _part_image(cadre, pied, MONTANT_DEMI, PROTECTION_HAUT, MONTANT_HAUT)
	return somme


## Part de l'image couverte par un objet debout en `p` (pied), de `demi` m de demi-largeur, entre les
## hauteurs `dessous` et `dessus` (m) : largeur dans le champ fois hauteur visible rapportée à
## ENCOMBRE_PLEINE de l'image (au plus 1). 0 hors de ENCOMBRE_LOIN m ou à moins de 1,5 m du ballon.
static func _part_image(cadre: Dictionary, p: Vector3, demi: float, dessous: float, dessus: float) -> float:
	var camera: Vector3 = cadre.camera
	var regard: Vector2 = cadre.regard
	var portee: float = cadre.portee
	var demi_v: float = cadre.demi_v
	var demi_h: float = cadre.demi_h
	var tangage: float = cadre.tangage
	var rel := Vector2(p.x - camera.x, p.z - camera.z)
	var loin := rel.dot(regard)
	if loin <= 0.3 or loin >= minf(ENCOMBRE_LOIN, portee - 1.5): return 0.0
	var centre := atan2(rel.x * regard.y - rel.y * regard.x, loin)
	var demi_corps := atan2(demi, loin)
	var largeur := maxf(0.0, minf(centre + demi_corps, demi_h) - maxf(centre - demi_corps, -demi_h)) / (2.0 * demi_h)
	# Bas et haut de l'image à cette distance (regard qui plonge de `tangage`).
	var bas := camera.y - loin * tan(tangage + demi_v)
	var haut := camera.y - loin * tan(tangage - demi_v)
	var hauteur := maxf(0.0, minf(dessus, haut) - maxf(dessous, bas)) / maxf(haut - bas, 0.01)
	return largeur * clampf(hauteur / ENCOMBRE_PLEINE, 0.0, 1.0)


## Places de la caméra réellement filmée pour les poses `retenues` ({"t", "ballon"}) sous l'angle
## (`cote`, `retrait`) : posée sur le plan à la première, puis amortie comme dans `_filmer`
## (CAMERA_LISSAGE en secondes réelles, lecture à VITESSE). 19 novembre 2026 : un porteur qui court vite
## laisse la caméra un mètre ou plus derrière son plan, la protection masquait la vraie ligne de visée.
static func cameras_filmees(retenues: Array, cote: Vector2, retrait: float) -> PackedVector3Array:
	var places := PackedVector3Array()
	var camera := Vector3.ZERO
	var elan := Vector3.ZERO
	var precedent := 0.0
	for i in retenues.size():
		var r: Dictionary = retenues[i]
		var but: Vector3 = plan_ralenti(r.ballon, cote, retrait).camera
		if i == 0:
			camera = but
		else:
			var pas: Array = Gestes._damp3(camera, but, elan, maxf(float(r.t) - precedent, 0.0) / VITESSE, CAMERA_LISSAGE)
			camera = pas[0]
			elan = pas[1]
		precedent = float(r.t)
		places.append(camera)
	return places


## Caméra du ralenti : sur le côté, à HAUTEUR m, elle suit le ballon (amortie ; posée d'un coup au
## début).
func _filmer(delta: float) -> void:
	var camera: Camera3D = view._camera
	if not is_instance_valid(camera):
		return
	var plan: Dictionary = plan_ralenti(_ballon, _cote, _retrait)
	if delta <= 0.0:
		_cam = plan.camera
		_vise = plan.vise
		_cam_v = Vector3.ZERO
		_vise_v = Vector3.ZERO
	else:
		var pas_cam: Array = Gestes._damp3(_cam, plan.camera, _cam_v, delta, CAMERA_LISSAGE)
		_cam = pas_cam[0]
		_cam_v = pas_cam[1]
		var pas_vise: Array = Gestes._damp3(_vise, plan.vise, _vise_v, delta, VISEE_LISSAGE)
		_vise = pas_vise[0]
		_vise_v = pas_vise[1]
	var regard := _vise - _cam
	if regard.length() < 0.1:
		regard = Vector3(_cote.x, 0.0, -_cote.y)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = float(plan.champ)
	camera.transform = Transform3D(Basis.looking_at(regard.normalized(), Vector3.UP), _cam)
	hauteur_camera = _cam.y
