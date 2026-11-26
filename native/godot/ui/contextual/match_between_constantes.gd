extends Control
## Préchargements et constantes de l'écran intermédiaire du match (couleurs de la charte, libellés, seuils).

const S = preload("res://ui/contextual/skin.gd")
const T = preload("res://theme.gd")
const Terrain2D = preload("res://ui/contextual/match_terrain_2d.gd")
const W = preload("res://ui/contextual/match_tableau_widgets.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const Pilotage = preload("res://ui/contextual/match_consignes.gd")
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")
const Meteo = preload("res://ui/contextual/meteo_texte.gd")
const Zones = preload("res://ui/immersive08/standings_zones.gd")
const Visuels = preload("res://ui/contextual/training_visuels.gd")
const MenuJoueur = preload("res://ui/contextual/match_menu_joueur.gd")
const Notation = preload("res://ui/notation_staff.gd")
const BullesAdjoint = preload("res://ui/contextual/match_bulles_adjoint.gd")
const Commune = preload("res://ui/immersive08/fiche_commune.gd")

## Libellés courts des stats comparées (le libellé complet en infobulle) : rien de tronqué.
const LIBELLES_COURTS := {"metres": "Mètres gagnés", "franchissements": "Franchissements", "plaquages": "Plaquages",
	"plaquages_manques": "Plaq. manqués", "recuperations": "Récupérations", "melees": "Mêlées gagnées", "touches": "Touches gagnées",
	"penalites": "Pénalités concédées", "en_avant": "En-avant", "pieds": "Jeu au pied", "possession": "Possession", "occupation": "Occupation",
	"zone22": "Entrées dans les 22 m", "plaquages_reussis": "Plaquages réussis"}
## Chiffres clés de l'entracte (maquette : possession, occupation, pénalités, entrées dans les 22, plaquages
## réussis, mêlées et touches gagnées) ; le reste est dans les statistiques complètes (lien, menu Plus).
const STATS := ["possession", "occupation", "penalites", "zone22", "plaquages_reussis", "melees", "touches"]
## Chiffres réels du moteur ajoutés quand la place le permet (1920 et au-delà) : le panneau est plein, jamais vide.
const STATS_PLUS := ["metres", "franchissements"]
const FATIGUE := 55
const EPUISE := 40
## Charte finale (ui/charte.gd, 20/11/2026) : panneaux arrondis (18) sans bordure, ombre portée de 4 px, crème pour
## l'information ; un seul aplat doré (le bouton principal). L'accent de l'écran (OR, nom historique) est la
## crème ; dans les comparaisons, nous en vert clair, l'adversaire en doré ; les couleurs des clubs ne
## vont qu'aux pastilles de club, maillots (terrain) et liserés.
const FOND := Charte.FOND
const PANNEAU := Charte.PANNEAU
const RELIEF := Charte.PANNEAU_2
const SurvolLigne = preload("res://ui/survol_ligne.gd")
const SURVOL := Charte.PANNEAU_3
const TRAIT := Charte.FILET
const IVOIRE := Charte.IVOIRE
const DOUX := Charte.IVOIRE_2
const FAIBLE := Charte.IVOIRE_3
const OR := Charte.IVOIRE
const ALERTE := Charte.D
const TITRES = preload("res://ui/immersive08/fonts/BarlowCondensed-Bold.ttf")
const TITRES_EXTRA = Charte.TITRE_EXTRA
const CHIFFRES_GRAS = preload("res://ui/immersive08/fonts/BarlowCondensed-ExtraBold.ttf")

const HORLOGES_IDS := ["lente", "normale", "rapide", "eclair"]
const HORLOGES_COURTS := ["Posée", "Normale", "Rapide", "Éclair"]

## Opacité des chiffres pendant l'échantillon court : lisibles, mais en retrait du score et des alertes.
const ATTENUE := 0.5

## Lignes du classement en direct : notre voisinage (± 3 places) et le haut du tableau.
const CLASSEMENT_LIGNES := 9
## Lignes montrées : notre voisinage (± 3 places) ; ± 2 en 1280×720.
const CLASSEMENT_ECRAN := 7
const CLASSEMENT_ECRAN_720 := 5
const VERT_SCORE := Charte.V
const MONTEE := Charte.V
const DESCENTE := Charte.D

## Taille de police à l'échelle, jamais sous le plancher de 12 px de la charte.
## Textes de l'écran 2D d'un à deux points sous la taille écrite (retouche de Léo du 21/11/2026 : écran plus aéré).
## Vide entre les grands blocs de l'écran (unités 2560) : chaque bloc est une tuile séparée, fond de page visible
## autour (retouche de Léo du 21/11/2026).
const GOUTTIERE := 24

## Fin trait blanc autour des grandes tuiles de l'écran 2D (choix de Léo du 21/11/2026, il prime ici sur la règle
## « panneaux sans bordure ») : 1 px, blanc à 22 %, qui suit le rayon des coins ; jamais sur les cartes intérieures.
const LISERE := Color(1, 1, 1, 0.22)

## Barre de commandes : où en est le match (mi-temps, défilement, pause), Équipe (action principale, ivoire
## plein), Réglages (vitesse de l'horloge, temps forts montrés : panneau dans la colonne de droite) et Plus
## (menu déroulant : statistiques, journal, autres matchs, délégation, caméras).
## Barre du haut agrandie d'environ 28 % (retouche de Léo du 21/11/2026), comme le bandeau du score.
const BARRE_HAUT := 1.28
## Identifiants des vitesses de l'horloge dans le menu « Plus ».
const ID_VITESSE := 200

## Colonnes de Mon XV (unités 2560) : numéro, joueur, énergie (jauge et valeur), plaquages, note.
const COLONNES_XV := [["N°", 44], ["Joueur", 0], ["Énergie", 170], ["Plaq.", 64], ["Note", 64]]
## Clé de tri de chaque colonne de Mon XV (même ordre que COLONNES_XV).
const TRIS_XV := ["numero", "joueur", "energie", "plaquages", "note"]
## Poste en deux signes, comme sur une feuille de match.
const POSTES_COURTS := {"pilier gauche": "PG", "talonneur": "TA", "pilier droit": "PD", "deuxième ligne": "2L", "troisième ligne": "3L",
	"numéro 8": "N8", "demi de mêlée": "DM", "demi d’ouverture": "DO", "demi d'ouverture": "DO", "ailier": "AI", "centre": "CE", "arrière": "AR"}

## Libellés d'arrêt de jeu de la ligne d'état (fait montré, avec l'équipe qu'il concerne).
const ETATS_ARRET := {"try": "Essai — %s", "transformation": "Transformation — %s", "goal": "Tir au but — %s", "miss": "Tir au but — %s",
	"lineout": "Touche pour %s", "scrum": "Mêlée pour %s",
	# Match filmé du 25/11 : pendant l'en-avant ou la pénalité, le bandeau disait encore « X a le ballon… ».
	# En-avant : l'équipe fautive (scene.team du moteur), comme le bandeau de la liaison (« En-avant — X ») ;
	# jamais la possession (vérificateur de #1319 : « En-avant » sans équipe pendant l'arrêt).
	"penalty": "Pénalité pour %s", "hand-fault": "En-avant — %s"}

## Note de départ du moteur (match-direct.cjs, NOTE_DEPART) : titulaire au coup d'envoi, remplaçant à son entrée.
const NOTE_DEPART := 6.5

const PORTRAIT = preload("res://guide/assets/coach-poses.png")
const MATTE = preload("res://guide/coach_matte.gdshader")

const LEVIER_TEINTES := {"composition": Charte.IVOIRE, "condition": Charte.V, "tactique": Charte.ATTRIBUT_55, "discipline": Charte.ATTRIBUT_40, "preparation": Charte.IVOIRE_2}

## Part (possession, occupation) à partir de laquelle l'adjoint en parle : un écart net, pas 58/42.
const SEUIL_LECTURE := 62

const STATS_FM := ["possession", "occupation", "metres", "zone22", "plaquages_reussis", "melees", "touches", "penalites"]
const LIBELLES_FM := {"possession": "Possession", "occupation": "Occupation", "metres": "Mètres", "zone22": "Entrées 22 m",
	"plaquages_reussis": "Plaquages réussis", "melees": "Mêlées gagnées", "touches": "Touches gagnées", "penalites": "Pénalités"}
