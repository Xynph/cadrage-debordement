extends RefCounted
## Fichiers privés posés à côté du jeu, hors dépôt public : animations adaptées depuis Mixamo, dont la
## licence permet l'usage dans le jeu mais interdit de redistribuer les fichiers. Ils viennent du
## dépôt privé rugby-reel-donnees (dossier animations/). Voir docs/gabi-mixamo-20261111.md.
##
## Ordre de recherche :
## 1. la variable d'environnement (chemin absolu), pour le développement et les captures ;
## 2. le dossier « animations » à côté de l'exécutable du jeu, s'il contient le fichier.
## Sinon : chaîne vide, et chaque appelant garde son contenu d'origine.

const DOSSIER := "animations"


static func chemin(variable: String, fichier: String, dossier_jeu := "") -> String:
	var choisi := OS.get_environment(variable).strip_edges()
	if not choisi.is_empty():
		return choisi
	var base := dossier_jeu if not dossier_jeu.is_empty() else OS.get_executable_path().get_base_dir()
	var defaut := base.path_join(DOSSIER).path_join(fichier)
	return defaut if FileAccess.file_exists(defaut) else ""
