extends RefCounted
## Gestes de rugby en présentation (match_gestes.gd) : constantes et état partagés.
## Socle de la chaîne match_gestes_etat → _corps → _placement → _essai → match_gestes.gd ;
## chaque étage ne s'appuie que sur les étages au-dessous. Les constantes se lisent de
## l'extérieur par le script principal (Gestes.PACE_MAX…).

const Presentation = preload("res://match_presentation.gd")
const Motion = preload("res://match_motion.gd")
const ApresEssai = preload("res://match_apres_essai.gd")

const FORM := 2.0          # instant du geste où l'alignement est en place ; la mise en place commence avant (temps négatif)
const FORM_MIN := 1.2      # durée minimale d'une course de mise en place
# Mise en place courte : chacun court à une allure crédible ; le direct attend le plus long trajet.
const PACE_FORWARD := 6.5  # allure de pointe d'un avant, en m/s
const PACE_BACK := 7.5     # allure de pointe des autres joueurs
const PACE_MAX := 8.0      # jamais plus vite à l'écran
const WALK_MIN := 0.55     # course la plus courte (durée d'une transition ordinaire de la vue)
const DRIVE_RAMP := 0.2    # part de la course passée à accélérer, puis à freiner
const PEAK := 1.0 / (1.0 - DRIVE_RAMP)  # pointe / allure moyenne du profil de course
# Temps mort avant une remise en jeu : coupe de réalisation plutôt qu'une longue course.
const CUT_BEYOND := 11.0   # au-delà de ce trajet (un joueur au moins), coupe sur la remise en jeu en place
const OUT_SHOT := 0.7      # plan de fin d'action quand le ballon sort en touche, en secondes
const SETTLE := 1.0        # après la coupe : temps de lecture, chacun fait ses derniers pas
const SETTLE_STEP := 1.2   # longueur de ces derniers pas, en mètres au plus
const RESTARTS := ["scrum", "kickoff", "drop22", "goalLine"]
const RELEASE := FORM + 0.55   # lancer
const CATCH := FORM + 1.1      # prise à deux mains au sommet
const DOWN := FORM + 1.4       # début de la redescente
const TOUCHE_END := FORM + 1.9
const LIFT := 1.05         # élévation du sauteur porté, en mètres
const MAUL_FORM := 0.7
const MAUL_START := 0.5
const MAUL_PACE := 2.0     # allure moyenne du ballon porté, en m/s
const MAUL_JOIN_PACE := 5.0  # allure de pointe des joueurs qui rejoignent le ballon porté (le groupe avance aussi)
# Ballon porté qui finit en essai (lot 8, 16/11/2026) : la poussée jusqu'à la ligne garde
# l'allure MAUL_PACE (pointe 1,25 fois plus) au lieu d'un sprint du paquet, en MAUL_TRY_DRIVE s au plus,
# pour que le geste entier (poussée, plongeon, joie) tienne sous TRY_HOLD_MAX. Si la ligne est trop
# loin pour cela, le ballon porté de la conquête avance d'autant plus (MAUL_TRY_LEAD m au plus au-delà
# du point du moteur : écart de placement accepté par Léo), en MAUL_PORTE_DRIVE s au plus.
const MAUL_TRY_DRIVE := 7.0
const MAUL_TRY_LEAD := 6.0
const MAUL_PORTE_DRIVE := 8.5
const STRIDE_CYCLE := 0.6  # ballon porté : un cycle de deux petits pas couvre 0,6 m
const STANCE := 0.65       # part du cycle où le pied pousse au sol
const CROUCH := 0.12       # abaissement du bassin des pousseurs, en mètres
const PUSH_PITCH := 0.38   # inclinaison des pousseurs
## Ballon porté (25/11/2026, « pas d'interpénétration franche ») : l'adversaire qui fait face au bloc
## de saut se lie MAUL_FACE.x m devant lui, décalé de MAUL_FACE.y m sur le côté (moitié de l'écart de
## 0,6 m du bloc) : têtes en alternance comme en mêlée, épaule contre épaule, au lieu de deux bustes
## penchés l'un dans l'autre (sonde des contacts : bustes et têtes confondus à 1,3 m face à face).
const MAUL_FACE := Vector2(1.3, 0.3)
const LEGS := ["UpperLeg.L", "LowerLeg.L", "Foot.L", "UpperLeg.R", "LowerLeg.R", "Foot.R"]
const DIVE_REACH := 1.95   # distance pieds -> ballon d'un plongeon bras tendus
const DIVE_SECONDS := 0.95
# Essai : le ballon est aplati dans l'en-but, à cette distance derrière la ligne (en-but de 5 m).
const IN_GOAL := 2.0
# Course du marqueur : allure de pointe (profil en sinus) ; une longue échappée dure ce qu'elle dure.
const TRY_PACE := 8.0
const TRY_RUN_MAX := 10.0
# Dernière passe avant l'essai quand le marqueur n'est pas le porteur : jamais vers l'avant (loi 11),
# reçue à SUPPORT_SIDE m sur le côté et SUPPORT_BACK m en retrait du porteur.
const SUPPORT_SIDE := 2.2
const SUPPORT_BACK := 1.0
const SUPPORT_START := 0.6  # le soutien arrive déjà lancé, à 60 % de l'allure où il prend la passe
const GIVER_PACE := 4.5     # allure de pointe du porteur qui fixe la défense en avançant
const GIVER_ADVANCE := 6.0  # il avance de six mètres au plus avant de donner
const PASS_FLIGHT := 0.32
const TRY_HOLD_MAX := 11.0  # le geste entier tient sous l'échéance de la régie (12 s par plan)
const OUTRO := 0.45
# Cadrage pendant un geste (caméras « tv » et « action » seulement).
const FRAME_IN := 1.5      # rapprochement, en secondes
const FRAME_OUT := 1.8     # retour au cadrage normal
const FRAME_SMOOTH := 0.6  # amortissement du centre et de la taille entre deux temps du geste
# Hauteur visible minimale, en mètres (TV : 11 m, puis 15 m le 12 novembre 2026, 26 m avec la caméra en
# perspective, 15 m le 19 novembre 2026 au soir avec la vue TV plus basse et plus serrée : égale au bas
# du cadrage de base, SUIVI de match_cadrage.gd, comme avant).
# Caméra au contact : 8 m depuis le 19 novembre 2026 (nuit), sous son cadrage de base resserré (10 à
# 12,5 m) ; à 14 m, le geste aurait élargi le plan au lieu de le rapprocher.
const FRAME_MIN := {"tv": 15.0, "action": 8.0}
const FRAME_MARGIN := 1.2
# Pendant le retour, si le suivi d'origine part en panoramique rapide (ballon
# renvoyé au centre après un essai : 100 m/s), le recadrage cède aussitôt la place
# à la caméra d'origine ; mêlé au retour, ce mouvement deviendrait un panoramique
# encore plus rapide à l'écran, en vue rapprochée. Seuil : 40 m/s, au-delà d'une
# course ou d'une passe.
const FRAME_LEAP := 40.0
# Caméra TV seulement : léger pivot autour du point visé pendant le geste, pour
# que les lignes de touche ne s'alignent plus sur l'axe de la caméra (le saut
# se lit alors au-dessus de la ligne). 0,25 rad, soit 14°, en 1,5 s (20° avant la caméra TV en
# perspective du 18 novembre 2026, où un pivot plus fort montre la tribune proche).
const FRAME_YAW := {"tv": 0.25, "action": 0.0}
const ARMS := ["UpperArm.L", "LowerArm.L", "Palm.L", "UpperArm.R", "LowerArm.R", "Palm.R"]
const LINE_Z := [-29.0, -23.2, -21.8, -20.4]
const CONTEST := 0.7        # élévation du bloc adverse, battu
# Clip « Man_Jump » du modèle : appel vers 0,33 s du clip, envol jusqu'à 0,63 s. Joué à ×0,4 depuis
# 0,19 s, l'appel tombe à FORM + 0,35 s, quand les porteurs commencent la levée.
const SAUT_DEBUT := 0.19
const SAUT_VITESSE := 0.4

var view
## Touche seule (direct sans gestes) : voir l'en-tête.
var touche_seule := false
var phase := ""
var time := 0.0
var done := true
var side := 0
var dir := 1.0
var cast: Dictionary = {}
var carrier := ""
var jumper := ""
var jumpers: Array[String] = ["", ""]
var awaiting := false
var line_x := 0.0
var throw_side := 0
var thrower := ""
var maul_wanted := false
# La conquête annonce un essai sur ballon porté (fait « porte » du moteur) : la poussée prend de l'avance.
var maul_try_follows := false
var target := Vector3.ZERO
var ball_from := Vector3.ZERO
var ball_from_basis := Basis.IDENTITY
var catch_point := Vector3.ZERO
var release_point := Vector3.ZERO
# Repère du regroupement : centre, axe de poussée, durée.
var center_from := Vector3.ZERO
var center_to := Vector3.ZERO
var axis_from := 0.0
var axis_to := 0.0
var drive := 1.0
var previous_carrier := ""
var peel := 0.0
var dive_from := Vector3.ZERO
var dive_to := Vector3.ZERO
var dive_axis := Vector3.RIGHT
var dive_set := false
var dive_seconds := DIVE_SECONDS
var turn_seconds := 0.6
var cheer: Array[String] = []
# Essai : porteur qui fait la dernière passe (vide si le marqueur portait déjà le ballon),
# instant de la passe et point de réception.
var giver := ""
var pass_at := 0.0
var receive_at := Vector3.ZERO
var giver_from := Vector3.ZERO
# Porteur de la scène précédente : celui qui a le ballon quand l'essai commence.
var _holder := ""
# Bibliothèque adaptée : lancer du clip en cours ; gestes de fin d'essai déjà lancés.
var _lancer_adapte := false
var _saut_lance := false
var _fin_essai := false
# Marqueur qui se relève (clip adapté) : sa pose de plongeon s'efface pendant le relevé.
var _releve := ""
var _celebre_a := 0.0
var _releve_duree := 0.45
const JOY_HOLD := 2.6       # avec les clips adaptés : le temps de voir la joie avant la transformation
# Après l'essai (19 novembre 2026, match filmé : marqueur couché seul, deux bras levés, 28 joueurs
# immobiles pendant une quinzaine de secondes). Jusqu'à la coupe vers la transformation, la scène
# vit : APRES_DEPART s après l'aplati, FELICITE_MAX partenaires (au moins FELICITE_MIN, choisis dans
# FELICITE_RAYON m) courent, bras levés, se regrouper autour du marqueur ; les défenseurs rentrent
# en marchant, buste penché (TETE_BASSE rad), vers leur en-but, sous leurs poteaux (places de la
# transformation, loi 8 : match_apres_essai.gd) ; les autres partenaires fêtent sur place puis
# regagnent tranquillement leur place derrière la marque du buteur. Allure de marche MARCHE m/s
# (± MARCHE_ECART selon le joueur), mise en marche en ELAN_MARCHE s, départ échelonné (MARCHE_DEPART,
# JOIE_SUR_PLACE pour ceux qui ont levé les bras). L'élan d'avant est gardé GLISSE s (GLISSE_MAX m/s
# au plus). Sans clip de relevé (bibliothèque absente), le marqueur reste allongé COUCHE s (fin du
# geste pour la régie), puis se relève en RELEVE s (genoux pliés de RELEVE_PLIE m à mi-chemin), lève
# les bras et se tourne vers ses partenaires. CELEBRATION : durée de la scène (repère des contrôles).
const APRES_DEPART := 0.3
const COUCHE := 1.6
const RELEVE := 0.9
const RELEVE_PLIE := 0.3
const FELICITE_MAX := 4
const FELICITE_MIN := 3
const FELICITE_RAYON := 25.0
const MARCHE := 1.7
const MARCHE_ECART := 0.25
const MARCHE_DEPART := [0.2, 1.4]
const JOIE_SUR_PLACE := [2.0, 3.2]
const ELAN_MARCHE := 0.5
const GLISSE := 0.4
const GLISSE_MAX := 4.0
const TETE_BASSE := 0.24
const CELEBRATION := 4.5
const APRES_ROLES := ["felicite", "repli", "replace"]
# Contournement du groupe du marqueur (19/11/2026, film : des défenseurs qui rentraient traversaient
# le groupe). Un défenseur qui rentre ne passe jamais à moins de GROUPE_DEGAGEMENT m des places autour
# du marqueur (ApresEssai.AUTOUR) : son chemin s'incurve (GROUPE_APPROCHE fois le rayon avant le
# groupe) et le contourne du côté où il passait déjà. Déjà trop près au départ, il s'écarte en
# GROUPE_ECART s (aucun saut).
const GROUPE_DEGAGEMENT := 1.5
const GROUPE_APPROCHE := 3.0
const GROUPE_ECART := 0.6
var _apres := false
var _saved: Dictionary = {}
var _outro: Dictionary = {}
var _dt := 1.0 / 60.0
# Mise en place : début (temps du geste, négatif si elle dure plus de FORM), durée, trajets raccourcis hors champ.
var form_start := 0.0
var form_seconds := 0.0
# Coupes de réalisation faites (compteur, pour les contrôles) et ballon déjà remis au lanceur.
var cuts := 0
var _ball_ready := false
var _velocity: Dictionary = {}
var _last_lineout: Dictionary = {}
# État du recadrage : rampe d'entrée/sortie et cible amortie.
var zoom := 0.0
var _zoom_mode := ""
var _zoom_center := Vector3.ZERO
var _zoom_center_speed := Vector3.ZERO
# Point visé amorti en deux étages : un saut du cadrage voulu (changement de temps du geste)
# ne fait varier ni la vitesse ni l'accélération du point visé d'une image à l'autre.
var _zoom_goal := Vector3.ZERO
var _zoom_goal_speed := Vector3.ZERO
var _zoom_size := 0.0
var _zoom_size_speed := 0.0
var _zoom_focus := Vector3.ZERO
