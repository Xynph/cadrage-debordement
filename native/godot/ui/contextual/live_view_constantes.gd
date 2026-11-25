extends Control
## Écran 13 « Match en direct » (live_view.gd), morceau : préchargements et constantes.

const S = preload("res://ui/contextual/skin.gd")
const Charte = preload("res://ui/charte.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const C = preload("res://ui/immersive08/components.gd")
const TempsForts = preload("res://ui/contextual/match_temps_forts.gd")
const Meteo = preload("res://ui/contextual/meteo_texte.gd")
const Pilotage = preload("res://ui/contextual/match_consignes.gd")
const FenetreEquipe = preload("res://ui/contextual/match_equipe.gd")
const ApresMatch = preload("res://ui/contextual/apres_match.gd")

## Tailles écrites pour 1080p (maquette 13-match-direct-1), agrandies avec la hauteur de l'écran (×1,33
## en 1440p), jamais réduites en dessous : horloge 32, période 16, noms 22, score 40 (charte §7), sigle 15,
## commandes 16, journal 16, météo 13.
const BANDEAU_TAILLES := {"horloge": 32, "phase": 16, "equipe": 22, "score": 40, "sigle": 15, "pause": 16, "legende": 16, "meteo": 13}
## Hauteur du bandeau du score et largeur du journal (maquette 1080p : 56 et 744 px), marge d'écran 24 px.
const BANDEAU_HAUTEUR := 56
## Barre du haut (bandeau du score, ligne du vent, commandes) agrandie d'environ 28 % (retouche de Léo du 21/11/2026).
const BARRE_HAUT := 1.28
## Liseré fin des grandes tuiles du direct (choix de Léo du 21/11/2026) : 1 px, blanc à 22 %.
const LISERE := Color(1, 1, 1, 0.22)
const LEGENDE_LARGEUR := 744
const MARGE := 24

## Fond de l'écusson d'une plaque : la vraie couleur du club, assombrie (même teinte) jusqu'à ce que l'ivoire y soit lu à
## 5:1 au moins, contraste mesuré comme la charte (Charte.contraste) ; un club jaune ou or passe au bordeaux
## de la charte (l'or reste à Continuer).
const CONTRASTE_PLAQUE := 5.0

## Vitesse du match : l'horloge de l'entracte en temps forts (posée → éclair), la cadence en repli.
const VITESSES := ["lente", "normale", "rapide", "eclair"]
const VITESSES_LIBELLES := {"lente": "Posée", "normale": "Normale", "rapide": "Rapide", "eclair": "Éclair"}

## Plein écran obligatoire (règle de Léo du 21/11/2026) : on ne quitte jamais le direct avant la fin. La plaque d'un club
## et le nom d'un de nos joueurs ouvrent une petite fenêtre visuelle par-dessus le match (cadre commun
## fenetre_visuelle.gd : voile, panneau rayon 18, titre, ✕) ; Échap, ✕ et clic à côté la ferment. Comme les anciennes
## pages du direct, le match se met en pause à l'ouverture et repart à la fermeture s'il jouait.
const FenetreVisuelle = preload("res://ui/immersive08/fenetre_visuelle.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Tableau = preload("res://ui/contextual/match_tableau_widgets.gd")
const FENETRE_CLUB := "MatchFenetreClub"
const FENETRE_JOUEUR := "MatchFenetreJoueur"
## Résultats récents : couleur et lettre (la couleur ne porte jamais seule le résultat).
const FORME_TEINTES := {"V": Charte.GAIN, "N": Charte.IVOIRE_2, "D": Charte.PERTE}

const ConsignesFenetre = preload("res://ui/contextual/match_consignes_fenetre.gd")
const JoueurFenetre = preload("res://ui/contextual/match_menu_joueur.gd")

const FENETRE_FAIT := "MatchFenetreFait"
const FENETRE_STAT := "MatchFenetreStat"

const FENETRE_MATCH := "MatchFenetreMatch"
const TYPES_FAITS := {"try": "Essai", "goal": "Tir au but réussi", "miss": "Tir au but manqué", "penalty": "Pénalité", "drop": "Drop",
	"transformation": "Transformation", "card": "Carton", "scrum": "Mêlée", "lineout": "Touche", "turnover": "Ballon récupéré",
	"hand-fault": "En-avant", "kick": "Jeu au pied", "carry": "Temps de jeu"}

## Parts entre les deux clubs (somme 100 %) : possession en courbe du match, occupation en frise (choix de Léo, 22/11/2026).
const STATS_PARTS := ["possession", "occupation"]

## Actions qui restent sur place dans une fiche ouverte pendant un match (onglets, tri, suivi du club) ; tout le reste
## mène à un autre écran ou ouvre une fenêtre : grisé, « Disponible après le match » (vestiaire, locker_view.gd).
const ACTIONS_SUR_PLACE := ["ClubSheetTab", "ClubSheetFollow", "ClubSheetSort_", "ClubSheetRetry", "FullPlayerTab"]
