extends "res://ui/contextual/live_view_widgets.gd"
## Écran 13 « Match en direct » (live_view.gd), morceau : variables de la vue (signaux, nœuds, état du menu, des pages et des fenêtres).

## Après-match (verdict, pourquoi, classement complet, « Valider le résultat ») : posé sur toute la vue une fois
## le match fini et entièrement montré (bouton de validation du direct visible).
var apres_match: Control
var _viewport: SubViewport
var director: Node
## Régie du match en temps forts (mode de base ; absente avec CD_MATCH_TEMPS_FORTS=0).
var regie: Node
var _cadence: OptionButton
var _niveau: OptionButton
var _niveaux: Array = []
var _reglages_temps_forts := false
var app: Control
var stage: Node3D
var model: Dictionary = {}
var clock: Label
## Période sous l'horloge (« 1re MT », « 2e MT ») ; vide quand l'horloge dit déjà « MI-TEMPS » ou « TERMINÉ ».
var phase: Label
var score: Label
## Météo et vent sous le score (même bandeau en 3D et pendant l'entracte 2D).
var meteo_ligne: Label
var home: Label
var away: Label
var play: Button
var finish: Button
## Dernier fait écrit : texte tenu par la vue (repli) ou par la régie (légende du temps fort). Il n'est pas
## affiché lui-même : le journal (deux lignes, minute et noms de nos joueurs liés) le reprend.
var events: Label
var drawer: PanelContainer
var drawer_body: VBoxContainer
var journal: VBoxContainer
var _journal_shell: PanelContainer
## Tiroir des statistiques et du journal (menu Plus) ; composition et consignes sont dans la fenêtre Équipe.
var drawer_tab := ""
## Fenêtre « Équipe » (match_equipe.gd) : composition, banc, cris, consignes ; elle met le match en pause.
var equipe: Control
## Consignes en direct envoyées et pas encore confirmées par le moteur (axe → cran).
var _envois_consignes: Dictionary = {}
var _drawer_key := ""
var _camera_controls: Array[Button] = []
var _applied_camera := ""
var _applied_quality := ""
## Plaques des deux clubs dans le bandeau (fond à la couleur du club, sigle, nom) : clic = fiche du club.
var plaques: Array[PanelContainer] = []
var _plaques_cle := ""
## Barre de commandes du bas : repli sans régie et fin de match (« Valider la journée »).
var barre_commandes: Control
## Bande de commandes des temps forts (Équipe, Réglages, Plus), remplie par l'écran intermédiaire
## (match_between.gd) : la même pendant les temps forts 3D et l'entracte 2D, à droite du score.
var bande_temps_forts: HBoxContainer

var echelle := 1.0
var _legende: Control
## Bandeau du score (BandeauAngle) : horloge, plaques, score.
var _coque_score: Control
var _meteo_boite: Control
var _sigles: Array[Label] = []
## Pendant l'action 3D : la ligne météo et le rappel « Échap » se retirent (le bandeau reste entier).
var compact := false
## Images à attendre avant de redonner au cadrage la part d'image cachée (mise en page différée).
var _recouvrir := 0
## Rappel « Échap · Pause et menu » sous les commandes (cliquable : ouvre le menu du match).
var indice_menu: Button
## Qui a le ballon, sous le bandeau (maquette 13-1) : en 3D, la phrase de l'état du jeu (écran 14,
## `MatchBetweenState`) sur panneau 85 % avec le liseré du club qui a le ballon ; à l'entracte, la phrase
## reste dans la bande des commandes (maquette 14).
var ligne_possession: PanelContainer
var _possession_trait: Control
var _possession_texte: Label
var _rangee_haut: Control
## Journal affiché : deux faits au plus, le plus récent en premier ({minute, texte}).
var _journal: Array = []
var _journal_texte := ""
var _journal_lignes: Array = []
## Menu du match (Échap) et page du direct (fiche club, réglages).
var menu: Control
var _menu_voile: ColorRect
var _menu_panneau: PanelContainer
var _menu_mode := ""
var _menu_quitter_arme := false
var _menu_cle := ""
var page: Control
var _page_sorte := ""
var _page_cle := ""
## Petite fenêtre du direct (club ou joueur) : calque plein écran (voile + toile au gabarit), ou null.
var fenetre_hote: Control
var _relecture: Array = []  ## [faits filtrés, équipes, fait de départ] de la page « Relire les actions »
## Le match jouait quand le menu ou la page s'est ouvert : « Reprendre » / « Retour au direct » le relance.
var _reprendre_apres := false
## Pause demandée pendant une réponse du moteur : envoyée dès qu'il est libre.
var _pause_voulue := 0
## La demande mémorisée vient d'un clic (ou d'Espace) du manager : un 2e clic l'annule. Une demande de Relire ou d'une
## fenêtre n'est jamais annulée par un clic : la pause reste.
var _pause_clic := false

## Redessine le fond de la bande quand ce qu'elle montre change (texte de la phrase, commandes visibles, taille).
var _cle_bande := ""

## Met le match en pause s'il joue (une seule fois) ; retient qu'il faudra le relancer.
## Instant de la dernière reprise demandée par la fermeture d'une fenêtre (ms).
var _reprise_ms := -100000

## Axe montré et l'envoi de la régie (`set_consignes` : file du prochain arrêt de jeu).
var consignes_axe := ""
var _consignes_envoyer: Callable

## Notre camp (0 : recevant) pour l'évolution d'un chiffre : les parts du moteur sont rangées recevant, visiteur.
var nous_stat := 0
