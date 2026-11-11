extends RefCounted
## Animations de déplacement adaptées au squelette du joueur (11 novembre 2026).
##
## Absent sans CD_MATCH_ANIMATIONS : le match garde alors ses trois clips
## d'origine (repos, marche, course) et rien ne change.
##
## CD_MATCH_ANIMATIONS = chemin absolu d'une bibliothèque .glb produite par
## scripts/animations/adapter-animations.py (squelette du joueur seul, une
## animation par clip, noms « mx_* »). La bibliothèque n'est pas dans le dépôt :
## les animations d'origine viennent de Mixamo, dont la licence interdit de
## redistribuer les fichiers. Voir docs/match-animations-adaptees-20261111.md.
##
## Première étape : seuls les déplacements changent (repos, marche, trot,
## course, sprint). Les gestes (touche, passe, plaquage) restent ceux de
## match_gestes.gd ; les autres clips de la bibliothèque sont chargés mais pas
## encore joués.

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

var _bibliotheque: AnimationLibrary
var _source: Node
var _chemin_squelette := ""


static func chemin() -> String:
	return OS.get_environment("CD_MATCH_ANIMATIONS").strip_edges()


static func demande() -> bool:
	return not chemin().is_empty()


func charger() -> bool:
	var fichier := chemin()
	if not FileAccess.file_exists(fichier):
		push_warning("CD_MATCH_ANIMATIONS : fichier introuvable, animations d'origine conservées (%s)" % fichier)
		return false
	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	if document.append_from_file(fichier, etat) != OK:
		push_warning("CD_MATCH_ANIMATIONS : lecture impossible (%s)" % fichier)
		return false
	_source = document.generate_scene(etat)
	if _source == null:
		return false
	var lecteur := _trouver_lecteur(_source)
	if lecteur == null or lecteur.get_animation_list().is_empty():
		push_warning("CD_MATCH_ANIMATIONS : aucune animation dans %s" % fichier)
		_source.free()
		_source = null
		return false
	_bibliotheque = AnimationLibrary.new()
	for nom: StringName in lecteur.get_animation_list():
		var animation := lecteur.get_animation(nom).duplicate(true) as Animation
		_bibliotheque.add_animation(str(nom).get_file(), animation)
	_source.free()
	_source = null
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
	if not lecteur.has_animation_library(PREFIXE):
		lecteur.add_animation_library(PREFIXE, _bibliotheque)
	return true


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


func _trouver_lecteur(noeud: Node) -> AnimationPlayer:
	if noeud is AnimationPlayer:
		return noeud
	for enfant: Node in noeud.get_children():
		var trouve := _trouver_lecteur(enfant)
		if trouve:
			return trouve
	return null
