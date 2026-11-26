extends Node
## Régie du match en temps forts : le mode de base du match (repli sur le direct
## d'origine avec CD_MATCH_TEMPS_FORTS=0).
##
## Trois états : écran intermédiaire (l'horloge file, une minute simulée par requête),
## temps fort (la vue 3D rejoue localement une liste de plans déjà simulés) et attente
## (le temps fort est fini, la minute suivante dira s'il continue). La régie ne décide
## rien de sportif : fenêtres, plans et arrêts viennent de `live.direct`, projeté par
## le moteur. Elle pilote la vue 3D par sa seule interface publique (`apply_frame`,
## `is_presenting_extended_pass`) : les gestes et les coupes vers les remises en jeu
## de la vue font partie de ce mode (repli : CD_MATCH_GESTES=0).
##
## Un temps fort se joue toujours à vitesse réelle ; seule l'horloge de l'écran
## intermédiaire se règle. CD_MATCH_TEMPS_FORTS_VITESSE ne sert qu'aux tests.
const S = preload("res://ui/contextual/skin.gd")
const Between = preload("res://ui/contextual/match_between.gd")
const Cadrage = preload("res://match_cadrage.gd")
const Liaison = preload("res://match_liaison.gd")
const Arbitre = preload("res://match_arbitre.gd")
const Pilotage = preload("res://ui/contextual/match_consignes.gd")
const Meteo = preload("res://ui/contextual/meteo_texte.gd")
const Charte = preload("res://ui/charte.gd")
const C08 = preload("res://ui/immersive08/components.gd")

## SORTIE : mi-temps ou fin de match, plan large puis joueurs qui rentrent au tunnel (grands moments).
enum { INTER, JEU, ATTENTE, SORTIE }
const NIVEAUX := ["aucun", "resume", "cles", "etendus", "dynamique", "integral"]
## Secondes réelles par minute de match sur l'écran intermédiaire.
const HORLOGES := {"lente": 3.0, "normale": 1.5, "rapide": 0.6, "eclair": 0.25}
## Pose « prêt » après une coupe : tireur face aux poteaux, équipes en place au renvoi.
const PRET := {"goal": 1.2, "miss": 1.2, "transformation": 1.2, "kickoff": 0.8, "drop22": 0.8, "goalLine": 0.8}
const DEPART_BALLON := ["goal", "miss", "transformation", "kickoff", "drop22", "goalLine"]
## Tirs au but (19 novembre 2026) : toujours une coupe sur la pose « prêt », gestes ou non ; buteur
## posé quelques pas derrière le ballon (élan), places de la loi 8 pour la transformation, caméra dans
## l'axe (match_cadrage.gd) ; il s'élance PRET_ELAN s avant la frappe (match_apres_essai.gd).
const ApresEssai = preload("res://match_apres_essai.gd")
const TIRS_AU_BUT := ["goal", "miss", "transformation"]
const PRET_ELAN := 0.6
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
## Pistes du chorégraphe (CD_MATCH_CHOREGRAPHE=1) : marge au-delà de leur durée avant de
## reprendre la main (la vue ne les lit plus, par exemple).
const ECHEANCE_CHOREGRAPHIE := 5.0
## Entre deux temps forts (décision de Léo, 12 novembre 2026, après le déclenchement par
## l'importance) : plus de pause minimale ni de retenue, plus de « Passer ». Le match défile en 2D
## à l'horloge choisie (secondes qui roulent) ; dès que le moteur déclenche un temps fort, il part
## au début de l'action, même juste après le précédent. Le manager règle en pause, ou en ouvrant
## Tactique ou Banc (pause posée le temps des changements). Le match complet reste continu.
const ENTRACTE := 0.0
## Liaison entre deux temps forts contigus (match_liaison.gd) : toujours à vitesse réelle ;
## marge au-delà de sa durée avant de reprendre la main.
const ECHEANCE_LIAISON := 3.0
## Fin d'un plan : l'action suivante attend que les joueurs proches du ballon aient fini leur
## déplacement à l'écran (allure plafonnée de la vue), au plus ECHEANCE_PLACE secondes de plus.
const ECHEANCE_PLACE := 1.5
## Grands moments (18 novembre 2026). Essai : à l'instant où il est aplati à l'écran, bandeau
## « ESSAI » (marqueur, équipe) sous le score, ralenti de la vue 3D puis image tenue : la
## transformation attend ESSAI_MOMENT secondes. Le ralenti part à ESSAI_RALENTI de la vitesse
## réelle et la retrouve avant la fin du moment (aucun ralenti si le joueur a réduit les animations).
const ESSAI_MOMENT := 2.2
const ESSAI_RALENTI := 0.35
## Bandeau « ESSAI » : lisible ESSAI_BANDEAU s (18/11/2026 soir : vu ~2 s au film), il déborde sur la
## pose de la transformation et n'est plus effacé par un retour à l'écran intermédiaire (_vers_inter).
const ESSAI_BANDEAU := 3.6
## Mi-temps et fin de match : plan large du terrain (SORTIE_LARGE s, joueurs encore à leur place),
## puis coupe sur un plan serré qui suit les joueurs rentrant au tunnel, partis plus près de lui
## (SORTIE_MARCHE s, match_view.gd sortir_du_terrain), avant la causerie ou l'écran de fin.
## Échap, Entrée, Espace ou un clic abrègent la séquence. Repli : CD_MATCH_SORTIE=0.
const SORTIE_LARGE := 1.5
const SORTIE_MARCHE := 6.0
## Bandeau des grands moments, façon retransmission (19/11/2026, film : le cadre « ESSAI » au centre
## masquait la célébration). Entrée en BANDEAU_ENTREE s (glissé depuis la gauche pour « ESSAI », depuis
## le bas pour « MI-TEMPS » et « FIN DU MATCH », de BANDEAU_GLISSE de la hauteur), sortie en
## BANDEAU_FONDU s (fondu, léger glissé vers le bas). Animations réduites : ni glissé ni fondu.
## Charte §7 (20/11/2026) : 600 ms d'animation au total (entrée + sortie), aucun flash.
const BANDEAU_ENTREE := 0.3
const BANDEAU_FONDU := 0.3
const BANDEAU_GLISSE := 0.04
## « ESSAI » en tiers inférieur : calé à gauche sur la légende, BANDEAU_MARGE de la hauteur au-dessus
## d'elle (sans légende connue : bas à BANDEAU_BAS_REPLI de la hauteur du bas de l'image).
const BANDEAU_MARGE := 0.015
const BANDEAU_BAS_REPLI := 0.11
## Ralenti de l'essai (19 novembre 2026, idée validée par Léo) : à la fin du moment d'essai (célébration
## de ESSAI_MOMENT s), la vue rejoue au ralenti (Rejeu.VITESSE) la fin de l'action jusqu'à l'aplati,
## sous un autre angle (caméra latérale basse), avec la mention « RALENTI » en haut à droite, puis
## revient à la vue normale : la célébration et la transformation reprennent où elles en étaient
## (match_rejeu.gd). Seulement pour un essai, au plus REJEU_MAX s ajoutées ; abrégé comme la sortie
## (Échap, Entrée, Espace, clic, « Passer ») ; jamais si le joueur a réduit les animations.
const Rejeu = preload("res://match_rejeu.gd")
const REJEU_MAX := 4.0
## Mention « RALENTI » : coin haut droit de la zone libre (sous le score et les commandes), à
## MENTION_MARGE de la hauteur des bords ; taille du texte en part de la hauteur de l'image.
const MENTION_MARGE := 0.015
const MENTION_TAILLE := 0.026

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
var _actif := false
var _resultat_sonne := false
## Essai (lot 5) : légende et clameur attendent que le ballon soit aplati à l'écran, jamais au
## départ de l'action (ballon porté, course).
var _essai_montre := false
## Plaquage de fin de course déjà joué pour le plan en cours (animations adaptées seulement).
var _plaque := false
## Tir au but en pose « prêt » : le buteur s'est-il déjà élancé ? L'arbitre est-il placé pour le tir ?
var _elan := true
var _arbitre_au_tir := false
## Nombre d'actions du journal déjà connues du joueur quand le temps fort a commencé.
var _vus := 0
## Pistes du chorégraphe en cours : le fait du plan courant est-il déjà à l'écran (jalon passé) ?
## Les pistes couvrent les plans `premier` à `dernier` ; chaque plan a son jalon (instant
## où son fait est montré : ballon gagné, porteur plaqué, réception, essai aplati).
var _jalon_montre := false
var _jalons_lus := 0
## Entracte : durée voulue, secondes écoulées depuis la fin du dernier temps fort (négatif :
## pas d'entracte en cours), temps fort retenu jusqu'à sa fin et actions connues à sa réception.
var entracte := ENTRACTE
var _entracte := -1.0
var _retenu: Dictionary = {}
var _retenu_vus := 0
var _retenu_depuis := 0.0
var _retenu_reste := 1.0
var _retenu_part := 0.0
var _passer := false
## Tiroir Tactique ou Banc ouvert pendant l'écran intermédiaire, et pause posée pour lui.
var _tiroir := false
var _pause_tiroir := false
## Consigne de fin de match choisie dans la tuile Bonus (`direct.bonus`) : le moteur n'accepte les consignes
## qu'en pause, la régie enchaîne pause, set_tactics, set_penalty_policy puis reprise (étape en cours, reprise due).
var _consigne_bonus: Dictionary = {}
## Horloge qui défile : dernière horloge du moteur montrée, secondes réelles depuis, et
## dernier modèle montrable (rien du temps fort retenu : score, fil).
var _horloge_inter := ""
## Minute du dernier fait montré par l'entracte (direct.horlogeMontree).
var _horloge_montree := ""
var _minute_inter := -1
var _roule := 0.0
## Horloge la plus avancée déjà montrée dans la période ([minute écrite, « 40+2 » compris ; secondes ; total
## en secondes]) : l'horloge de l'écran intermédiaire ne recule jamais (vérificateur de #1305 : 20:28 → 20:10
## → 21:59 → 21:12). Vidée à la mi-temps, à la fin et au changement de rencontre.
var _horloge_vue: Array = []
var _live_inter: Dictionary = {}
## Liaison en cours (plans, programme de l'arbitre, légende), plan joué et temps écoulé dans ce plan.
var liaison: Dictionary = {}
var _liaison_plan := 0
var _liaison_t := 0.0
var _liaison_total := 0.0
var _detail_precedent := ""
## Premier plan joué après une liaison : pas de coupe d'entrée (la liaison y a amené les joueurs).
var _sans_coupe := false
## Arbitre des temps forts (présentation) et vitesse mesurée des joueurs (départ d'une liaison).
var arbitre: Node3D
var _vitesses: Dictionary = {}
var _places: Dictionary = {}
var _saut_max := 0.0
## Secondes déjà attendues, à la fin du plan courant, pour que les joueurs finissent leur déplacement.
var _attente_place := 0.0
## Grands moments : secondes restantes du moment d'essai (ralenti puis image tenue), secondes
## écoulées dans la sortie, bandeau (« ESSAI », « MI-TEMPS », « FIN DU MATCH ») et sa durée restante.
var _moment_essai := 0.0
var _sortie_t := 0.0
var _sortie_depuis_inter := false
var _espace: Control
var bandeau: PanelContainer
var _bandeau_duree := 0.0
var _bandeau_reste := 0.0
var _bandeau_titre := ""
## Dernière place connue de la légende (repère de la vue) : le bandeau « ESSAI » se pose au-dessus.
var _legende_rect := Rect2()
## Plus petit ralenti posé pendant le dernier moment d'essai (contrôle des tests).
var ralenti_min := 1.0
## Ralenti de l'essai : mention « RALENTI », ralenti dû à la fin du moment d'essai (essai repéré par
## la vue), ralenti abrégé par le joueur.
var mention: PanelContainer
var _rejeu_du := false
var _rejeu_passe := false
## Diagnostic texte / image : début à l'écran de la phase courante (ms, index du journal) et
## dernière légende tracée au suivi.
var _image_ms := 0
var _image_journal := -1
var _legende_tracee := ""
