extends RefCounted
## Animations de déplacement adaptées au squelette du joueur (11 novembre 2026).
##
## Absent sans CD_MATCH_ANIMATIONS ni animations/mixamo-match.res à côté de
## l'exécutable : le match garde alors ses trois clips d'origine (repos, marche,
## course) et rien ne change.
##
## CD_MATCH_ANIMATIONS = chemin absolu de la bibliothèque : de préférence une
## ressource .res (AnimationLibrary) produite par
## scripts/animations/convertir-bibliotheque.gd, sinon le .glb produit par
## scripts/animations/adapter-animations.py (squelette du joueur seul, une
## animation par clip, noms « mx_* »). La bibliothèque n'est pas dans le dépôt :
## les animations d'origine viennent de Mixamo, dont la licence interdit de
## redistribuer les fichiers. Voir docs/match-animations-adaptees-20261111.md.
##
## Déplacements : repos, marche, trot, course, sprint selon la vitesse au sol.
## Gestes (11 novembre 2026, suite) : lancer en touche, réception, plaqué et
## relevé, plaquage, coup de pied et drop, joie et déception, joués une fois par
## la vue (NativeMatchView.jouer_geste) sur les faits du moteur ; sans le clip,
## la pose procédurale de match_gestes.gd reste le repli.

const DonneesPrivees = preload("res://donnees_privees.gd")
const FICHIER := "mixamo-match.res"
const PREFIXE := &"mx"
## Paliers de déplacement : clip, vitesse au sol du clip (m/s, joueur de 1,90 m)
## et vitesse à partir de laquelle on monte au palier suivant.
const PALIERS := [
	{"clip": "mx_marche", "allure": 1.75, "monte": 2.3},
	{"clip": "mx_trot", "allure": 2.7, "monte": 3.7},
	{"clip": "mx_course", "allure": 4.65, "monte": 6.0},
	{"clip": "mx_sprint", "allure": 6.5, "monte": INF},
]
## Marge sous le seuil avant de redescendre d'un palier (évite l'alternance).
const HYSTERESIS := 0.45
const REPOS := "mx_repos_souffle"
## Gestes joués une fois : nom du geste -> clip, et instant clé du clip (secondes) :
## lâcher du ballon, prise, impact au sol, contact du pied, bras levés.
const GESTES := {
	"lancer": {"clip": "mx_lancer_touche", "cle": 1.55},
	"reception": {"clip": "mx_reception", "cle": 1.45},
	"reception_haute": {"clip": "mx_reception_haute", "cle": 1.5},
	"plaque_cote": {"clip": "mx_plaque_cote", "cle": 1.45},
	"plaque_jambes": {"clip": "mx_plaque_jambes", "cle": 1.0},
	"plaquage": {"clip": "mx_plaquage", "cle": 1.1},
	"se_relever": {"clip": "mx_se_relever", "cle": 1.6},
	"coup_de_pied": {"clip": "mx_coup_de_pied", "cle": 0.75},
	"drop": {"clip": "mx_drop", "cle": 2.05},
	"joie": {"clip": "mx_joie", "cle": 0.8},
	"joie_poing": {"clip": "mx_joie_poing", "cle": 0.8},
	"deception": {"clip": "mx_deception", "cle": 0.8},
}
## Ces clips d'origine se déplacent (élan, chute, pas de course) : le joueur du match
## garde sa place, décidée par la scène. Leur déplacement horizontal est retiré au
## chargement ; seuls le corps et les appuis bougent sur place.
const SUR_PLACE := ["mx_lancer_touche", "mx_coup_de_pied", "mx_drop", "mx_plaque_cote", "mx_plaque_jambes",
	"mx_plaquage", "mx_reception", "mx_reception_haute", "mx_se_relever", "mx_joie_poing", "mx_deception", "mx_joie"]

var _bibliotheque: AnimationLibrary
var _chemin_squelette := ""


## Sans variable : animations/mixamo-match.res à côté de l'exécutable, s'il y est (donnees_privees.gd).
static func chemin() -> String:
	return DonneesPrivees.chemin("CD_MATCH_ANIMATIONS", FICHIER)


static func demande() -> bool:
	return not chemin().is_empty()


func charger() -> bool:
	var fichier := chemin()
	if not FileAccess.file_exists(fichier):
		push_warning("CD_MATCH_ANIMATIONS : fichier introuvable, animations d'origine conservées (%s)" % fichier)
		return false
	_bibliotheque = AnimationLibrary.new()
	if fichier.get_extension().to_lower() in ["res", "tres"]:
		# Forme conseillée : ressource Godot préparée hors jeu
		# (scripts/animations/convertir-bibliotheque.gd). Lecture directe, sans
		# reconstruire de scène.
		var lue := ResourceLoader.load(fichier, "AnimationLibrary", ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
		if lue == null:
			push_warning("CD_MATCH_ANIMATIONS : lecture impossible (%s)" % fichier)
			_bibliotheque = null
			return false
		for nom: StringName in lue.get_animation_list():
			_bibliotheque.add_animation(nom, lue.get_animation(nom).duplicate(true))
	else:
		var source := lire_gltf(fichier)
		if source.is_empty():
			push_warning("CD_MATCH_ANIMATIONS : aucune animation lisible dans %s" % fichier)
			_bibliotheque = null
			return false
		for nom: String in source:
			_bibliotheque.add_animation(nom, source[nom])
	for palier: Dictionary in PALIERS:
		if not _bibliotheque.has_animation(palier.clip):
			push_warning("CD_MATCH_ANIMATIONS : clip %s absent, animations d'origine conservées" % palier.clip)
			_bibliotheque = null
			return false
	return _bibliotheque.has_animation(REPOS)


## Branche la bibliothèque sur le lecteur d'un joueur. Les pistes sont ramenées
## une fois sur le chemin réel du squelette du joueur, lu dans un clip d'origine.
func equiper(lecteur: AnimationPlayer) -> bool:
	if _bibliotheque == null or lecteur == null:
		return false
	if _chemin_squelette.is_empty():
		var origine := lecteur.get_animation_list()
		if origine.is_empty():
			return false
		var reference := lecteur.get_animation(origine[0])
		if reference.get_track_count() == 0:
			return false
		_chemin_squelette = str(reference.track_get_path(0)).get_slice(":", 0)
		# Selon l'outil d'export, « Foot.L » peut arriver écrit « Foot_L » : on
		# retrouve le vrai nom d'os dans le squelette du joueur.
		var squelette := lecteur.get_node(lecteur.root_node).get_node_or_null(NodePath(_chemin_squelette)) as Skeleton3D
		var noms := {}
		if squelette:
			for os in squelette.get_bone_count():
				noms[squelette.get_bone_name(os).replace(".", "_")] = squelette.get_bone_name(os)
		for nom: StringName in _bibliotheque.get_animation_list():
			var animation := _bibliotheque.get_animation(nom)
			for piste in animation.get_track_count():
				var chemin_piste := animation.track_get_path(piste)
				if chemin_piste.get_subname_count() > 0:
					var nom_os := str(chemin_piste.get_subname(0))
					if squelette and squelette.find_bone(nom_os) < 0:
						nom_os = str(noms.get(nom_os.replace(".", "_"), nom_os))
					animation.track_set_path(piste, NodePath("%s:%s" % [_chemin_squelette, nom_os]))
		for palier: Dictionary in PALIERS:
			_bibliotheque.get_animation(palier.clip).loop_mode = Animation.LOOP_LINEAR
		_bibliotheque.get_animation(REPOS).loop_mode = Animation.LOOP_LINEAR
		if squelette:
			_retirer_deplacement(squelette, lecteur)
	if not lecteur.has_animation_library(PREFIXE):
		lecteur.add_animation_library(PREFIXE, _bibliotheque)
	return true


## Retire le déplacement horizontal du bassin (os « Body ») des clips SUR_PLACE ; les
## autres pistes de position (pieds libres de ce modèle, sous la même racine) suivent le
## même décalage. La verticale (saut, chute) est gardée.
func _retirer_deplacement(squelette: Skeleton3D, lecteur: AnimationPlayer) -> void:
	var corps := squelette.find_bone("Body")
	if corps < 0:
		return
	var parent := squelette.get_bone_parent(corps)
	# Verticale du terrain exprimée dans l'espace de l'os parent du bassin.
	var chaine := Transform3D.IDENTITY
	var noeud: Node = squelette
	var racine := lecteur.get_node_or_null(lecteur.root_node)
	while noeud != null and noeud != racine and noeud is Node3D:
		chaine = (noeud as Node3D).transform * chaine
		noeud = noeud.get_parent()
	var haut := chaine.basis.inverse() * Vector3.UP
	if parent >= 0:
		haut = squelette.get_bone_global_rest(parent).basis.inverse() * haut
	haut = haut.normalized()
	for nom: String in SUR_PLACE:
		if not _bibliotheque.has_animation(nom):
			continue
		var animation := _bibliotheque.get_animation(nom)
		var piste_corps := -1
		var positions: Array[int] = []
		for piste in animation.get_track_count():
			if animation.track_get_type(piste) != Animation.TYPE_POSITION_3D:
				continue
			var chemin := animation.track_get_path(piste)
			if chemin.get_subname_count() == 0:
				continue
			var os := squelette.find_bone(str(chemin.get_subname(0)))
			if os < 0 or squelette.get_bone_parent(os) != parent:
				continue
			positions.append(piste)
			if os == corps:
				piste_corps = piste
		if piste_corps < 0 or animation.track_get_key_count(piste_corps) == 0:
			continue
		var depart: Vector3 = animation.position_track_interpolate(piste_corps, 0.0)
		var decalages: Dictionary = {}
		for piste: int in positions:
			for cle in animation.track_get_key_count(piste):
				var instant := animation.track_get_key_time(piste, cle)
				if not decalages.has(instant):
					var ecart: Vector3 = animation.position_track_interpolate(piste_corps, instant) - depart
					decalages[instant] = ecart - haut * ecart.dot(haut)
		for piste: int in positions:
			for cle in animation.track_get_key_count(piste):
				var valeur: Vector3 = animation.track_get_key_value(piste, cle)
				animation.track_set_key_value(piste, cle, valeur - decalages[animation.track_get_key_time(piste, cle)])


## Clip d'un geste joué une fois (nom de GESTES), vide s'il manque à la bibliothèque.
func geste(nom: String) -> StringName:
	if _bibliotheque == null or not GESTES.has(nom) or not _bibliotheque.has_animation(GESTES[nom].clip):
		return StringName()
	return StringName("%s/%s" % [PREFIXE, GESTES[nom].clip])


## Instant clé d'un geste dans son clip (lâcher, prise, impact, contact du pied).
func instant_cle(nom: String) -> float:
	return float(GESTES[nom].cle) if GESTES.has(nom) else 0.0


func duree(nom: String) -> float:
	if geste(nom).is_empty():
		return 0.0
	return _bibliotheque.get_animation(GESTES[nom].clip).length


func repos() -> StringName:
	return StringName("%s/%s" % [PREFIXE, REPOS])


## Palier de déplacement pour une vitesse au sol, avec hystérésis sur le palier
## précédent (index dans PALIERS, -1 au premier appel).
func palier(vitesse: float, precedent: int) -> int:
	var index := clampi(precedent, 0, PALIERS.size() - 1)
	while index < PALIERS.size() - 1 and vitesse > float(PALIERS[index].monte):
		index += 1
	while index > 0 and vitesse < float(PALIERS[index - 1].monte) - HYSTERESIS:
		index -= 1
	return index


func clip(index: int) -> StringName:
	return StringName("%s/%s" % [PREFIXE, PALIERS[index].clip])


## Vitesse au sol du clip : sert à avancer l'animation à la distance parcourue.
func allure(index: int) -> float:
	return float(PALIERS[index].allure)


## Animations d'un .glb (nom court -> Animation copiée). Sert à l'outil de
## conversion et, à défaut de ressource préparée, au chargement en jeu.
static func lire_gltf(fichier: String) -> Dictionary:
	var resultat := {}
	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	if document.append_from_file(fichier, etat) != OK:
		return resultat
	var scene := document.generate_scene(etat)
	if scene == null:
		return resultat
	var lecteur := _trouver_lecteur(scene)
	if lecteur:
		for nom: StringName in lecteur.get_animation_list():
			resultat[str(nom).get_file()] = lecteur.get_animation(nom).duplicate(true)
	scene.free()
	return resultat


static func _trouver_lecteur(noeud: Node) -> AnimationPlayer:
	if noeud is AnimationPlayer:
		return noeud
	for enfant: Node in noeud.get_children():
		var trouve := _trouver_lecteur(enfant)
		if trouve:
			return trouve
	return null
