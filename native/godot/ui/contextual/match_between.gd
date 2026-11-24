extends Control
## Écran intermédiaire du match en temps forts (mode de base ; repli CD_MATCH_TEMPS_FORTS=0).
##
## Entre deux temps forts, le match continue sur un terrain vu de dessus (`match_terrain_2d.gd`) :
## trente pastilles numérotées rejouent les faits du moteur pendant que l'horloge défile. Autour,
## un tableau de bord inspiré des écrans « match overview » des jeux de management de football,
## adapté au rugby : domination minute par minute, chiffres clés comparés, fil, Mon XV (note,
## énergie, alertes), regard de l'adjoint et accès direct à la fenêtre Équipe (composition, banc,
## consignes ; choix de Léo du 18/11/2026 : un seul bouton à la place de Tactique et Banc).
## Une seule mise en page, « Bord de terrain » (choix de Léo du 21/11/2026) en tableau de bord (option A de la revue
## FM27, 22/11/2026) : à gauche Gabi, les 3 derniers événements, le bonus et le banc ; au centre le terrain entre les
## deux compositions notées, la domination sous le terrain, la phrase de jeu, les chiffres en barres miroir et la courbe
## cumulée ; à droite le classement complet et le multiplex ; en bas Mon XV, une carte par joueur (visage cerclé de son
## énergie, note, moral en direct). Plein écran obligatoire : chaque clic ouvre une petite fenêtre
## par-dessus le match (joueur, club, fait, chiffre, match du multiplex). Il n'affiche que la projection `live.direct`
## du moteur et le modèle : aucun calcul sportif, aucune écriture d'état.
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
const BullesAdjoint = preload("res://ui/contextual/match_bulles_adjoint.gd")
const Commune = preload("res://ui/immersive08/fiche_commune.gd")

signal niveau_choisi(id: String)
signal reprise_demandee
signal tiroir_demande(titre: String)
## Entracte entre deux temps forts : le manager l'abrège.
signal passer_demande
## Vitesse de l'horloge entre deux temps forts (« lente », « normale », « rapide », « eclair »).
signal horloge_choisie(valeur: String)
## « Confier la fin à l'adjoint », depuis le menu de la barre.
signal delegation_demandee
## Un joueur de Mon XV choisi : la fenêtre Équipe s'ouvre sur lui.
signal joueur_choisi(poste: int)
## « Pourquoi » d'après-match : l'action d'une raison ouvre l'écran de son levier (route du jeu).
signal levier_choisi(route: String)
## Score du dernier fait joué sur le terrain (le moteur a parfois une minute d'avance).
signal score_joue(score: Array)
## Caméra du direct 3D choisie dans le menu Plus (« tv », « tactical », « action »).
signal camera_demandee(mode: String)
## Consigne de fin de match choisie dans la tuile Bonus ({attack, defense, penalty}, commandes existantes).
signal consigne_bonus(consigne: Dictionary)
## « Consignes » (idée FM27 n° 33) ouvre la petite fenêtre des consignes, le match continue.
signal consignes_demandees
## Pause demandée depuis l'entracte (Espace, Échap) : commande `pause` du jeu, branchée par la régie.
signal pause_demandee
## Fiche joueur ouverte (vrai) ou refermée (faux) pendant le match : la régie met le match en pause le temps de la lire.
signal fiche_ouverte(ouverte: bool)
## Le journal du match ouvert à un fait (repère de la domination, dernier fait) : indice du fait dans `live.events`.
signal journal_demande(i: int)
## Les statistiques complètes ouvertes à une ligne (chiffre clé cliqué) : libellé du moteur de cette ligne.
signal stats_demandees(libelle: String)
## Fiche d'un club demandée (ligne du classement en direct, enjeu) : identifiant du club.
signal club_demande(id: int)
## Un chiffre du match cliqué : sa petite fenêtre (les deux clubs) ; la ligne du moteur ({cle, label, valeurs…}).
signal stat_demandee(rang: Dictionary)
## Une carte du multiplex cliquée : la petite fenêtre de ce match (clubs, score, essais, minute).
signal match_demande(rencontre: Dictionary)
## « Confier la fin à l'adjoint » choisi pendant un temps fort 3D (entracte caché) : confirmation dans le menu du match.
signal confier_fin_demande
## Vrai quand une fenêtre de la vue (Équipe) couvre l'entracte : le clavier de l'entracte se tait. Posé par la régie.
var couvert: Callable = func() -> bool: return false
## Bande de la vue du match (sous le score) qui porte la barre de commandes, la même en 3D et
## pendant l'entracte ; sans elle, la barre reste en haut de l'écran intermédiaire.
var hote_barre: Control

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
var terrain: Terrain2D
## Ligne d'état du terrain : où est le ballon (« X a le ballon dans le camp adverse »), ou l'arrêt de jeu.
var etat: Label
## Phase du match dans la barre de commandes (« Mi-temps · le match défile en 2D, vitesse Normale »).
var phase: Label
## Sens du jeu, à droite de l'en-tête du terrain (« Alder Fen XV attaque vers la droite », texte, pas un lien).
var sens_jeu: Label
var parametres: Button
## Réglages en menu déroulant pendant un temps fort 3D (le panneau de droite n'est visible qu'à l'entracte).
var menu_reglages: PopupMenu
## Réglages du match (vitesse de l'horloge, temps forts montrés) : panneau de la colonne de droite.
var panneau_parametres: Control
var groupe_horloge: ButtonGroup
var groupe_niveaux: ButtonGroup
var grille_niveaux: GridContainer
var bandeau: PanelContainer
var fil: VBoxContainer
var chiffres: Container
var xv: GridContainer
## Pied fixe de Mon XV (ligne « Équipe »), hors de la zone de défilement : toujours entier sous la dernière ligne.
var pied_xv: VBoxContainer
var defile_xv: ScrollContainer
## Banc (remplaçants `live.reserves`) sous les titulaires.
var banc: GridContainer
var zone_banc: VBoxContainer
var legende_notes: HBoxContainer
var precision_banc: Label
var titre_xv: Label
var lien_adverse: Button
var adjoint: VBoxContainer
## Bouton « ÉQUIPE » : fenêtre plein écran (composition, banc, cris, consignes), match en pause.
var equipe: Button
## Lien « Consignes » de la barre (idée FM27 n° 33) : petite fenêtre des consignes, sans pause.
var lien_consignes: Button
var plus: MenuButton
## Horloge de l'entracte choisie (reprise de la régie à l'ouverture).
var horloge := "normale"
const HORLOGES_IDS := ["lente", "normale", "rapide", "eclair"]
const HORLOGES_COURTS := ["Posée", "Normale", "Rapide", "Éclair"]
var adjoint_cadre: Control
var domination: Domination
var titre_domination: Control
var arret: PanelContainer
var arret_titre: Label
var arret_texte: Label
var arret_sous_titre: Label
var arret_aide: Label
var arret_options: VBoxContainer
var arret_reprendre: Button
## Choix du manager déjà envoyé pour l'arrêt montré : {cle, id, nom} (vide sinon).
var _choix_fait: Dictionary = {}
var _niveaux: Array = []
var _cle := ""
var _densite := 0.5
var _arret: Dictionary = {}
var _entracte := ["", false]
var _dernier: Array = []
var _lignes: Array = []
var _acteurs: Dictionary = {}
var _dernier_fait := -1
var _rangs: Array = []
var colonne_droite: VBoxContainer
## Panneau montré dans la colonne de droite : « chiffres », « reglages », « journee », « delegation ».
var vue_droite := "chiffres"
var panneau_chiffres: Control
var panneau_journee: Control
## Panneaux de la journée en direct (classement complet, multiplex), toujours à l'écran.
var panneaux_direct: Array[Control] = []
## D1 : l'enjeu « si ça finit ainsi » (rang officiel → rang en direct) dans l'en-tête du classement.
var enjeu_pastille: PanelContainer
var panneau_delegation: Control
var legende_chiffres: HBoxContainer
var meteo_ligne: Label
var meteo_pastille: Control
var stats_lien: Button
var journee_vide: Label
var pied: HBoxContainer
var pied_reglages: Label
var _fin := {}
## Vue de la colonne Mon XV : « tableau » (Mon XV et le banc) ou « adverse » (le XV adverse, `direct.adversaire`).
var vue_xv := "tableau"
## Tri de Mon XV par l'en-tête : vide (ordre des postes), « joueur », « energie », « plaquages », « note ».
var tri_xv := ""
var tri_inverse := false
## Boutons de l'en-tête de Mon XV (un par colonne, métadonnées « tri » et « libelle »).
var entetes_tri: Array[Button] = []
var tableau_xv: VBoxContainer
## Joueur du XV le plus en difficulté (poste, -1 si rien d'urgent) : Gabi propose de le remplacer.
var changement_poste := -1
var _xv_donnees: Array = []
var _equipes: Array = []
## Tuile principale (Mon XV) : l'œil commence par elle.
var tuile_principale: PanelContainer
## Alertes de Mon XV (fatigue, blessure, carton) : pour l'adjoint et les tests.
var alertes_xv: Array[Dictionary] = []
## Précision des chiffres clés : vide, ou l'avertissement d'échantillon court.
var precision_chiffres: Label
## Échantillon trop court (`direct.echantillon`, lot 5) : chiffres atténués, adjoint sans lecture.
var echantillon_court := false
## Opacité des chiffres pendant l'échantillon court : lisibles, mais en retrait du score et des alertes.
const ATTENUE := 0.5
## Journée en direct (`direct.journee`, moteur match-multiplex.cjs) : classement « si ça finit ainsi » et
## multiplex des autres matchs, dans le panneau « Autres matchs » (menu Plus). Masqués sans la donnée.
var classement_tuile: PanelContainer
var classement_lignes: VBoxContainer
var multiplex: PanelContainer
## Tuile Bonus (`direct.bonus`, moteur match-bonus.cjs) : règle du championnat, état du bonus offensif et défensif,
## et à partir de la 65e minute le dilemme de fin de match avec ses deux consignes. Masquée sans bonus en jeu.
var bonus_tuile: PanelContainer
var bonus_regle: Label
var bonus_etat: HBoxContainer
var bonus_situation: Label
var bonus_choix: VBoxContainer
var _bonus_cle := ""
var multiplex_cartes: GridContainer
## Une seule rangée de cartes ; au-delà de la largeur, défilement horizontal (molette ou glisser).
var multiplex_defile: ScrollContainer
## Indicateur « › » au bord droit : la suite du multiplex est hors de vue (masqué quand tout tient ou en fin de rangée).
var multiplex_fondu: Control
## Pilotage reçu du moteur (`live.pilotage`) : états des joueurs (Galvanisé, Vexé…) et conseil de changement.
var _pilotage: Dictionary = {}
var multiplex_precision: Label
## Dernière journée montrée (null sans multiplex) et sa clé (rien n'est reconstruit sans changement).
var journee_vue: Variant = null
var _journee_cle := ""
## Scores des autres matchs à la minute montrée et à la précédente : liseré sur ceux qui ont changé (état
## gardé par l'écran, aucun calcul sportif).
var _journee_minute := -1
var _scores_cour: Dictionary = {}
var _scores_prec: Dictionary = {}
## Fiche joueur ouverte pendant le match (sous-page posée sur l'entracte, retour par Échap), ou null.
var fiche_match: Control
## Dans le vrai direct (match_temps_forts.gd) : le nom d'un joueur ouvre sa petite fenêtre par-dessus le match
## (live_view.gd, plein écran obligatoire) au lieu de la sous-page ; vide hors du direct (tests de l'entracte seul).
var fiche_vers: Callable = Callable()
## Carte de Mon XV : la fenêtre du joueur en match (idée 32, match_menu_joueur.gd), sinon sa fiche.
var menu_vers: Callable = Callable()
## Dernier remplacement du prochain arrêt de jeu déjà montré en carte sortant / entrant (numéro de la file).
var _changement_vu := -1
## Vrai dès qu'un rendu a vu le match sans aucun remplacement fait : le premier à venir est donc un vrai changement du direct, jamais un ancien.
var _changement_amorce := false
var _fiche_id := ""
## Lignes du classement en direct : notre voisinage (± 3 places) et le haut du tableau.
const CLASSEMENT_LIGNES := 9
## Lignes montrées : notre voisinage (± 3 places) ; ± 2 en 1280×720.
const CLASSEMENT_ECRAN := 7
const CLASSEMENT_ECRAN_720 := 5
const VERT_SCORE := Charte.V
const MONTEE := Charte.V
const DESCENTE := Charte.D

## Domination minute par minute (`direct.domination`, −100 à +100 pour l'équipe qui reçoit) : une barre par
## minute, notre équipe au-dessus de l'axe en barres pleines, l'adversaire dessous en barres vides (la forme
## porte le camp, pas seulement la couleur). Les points marqués et cartons (`direct.reperes`) sont écrits à
## leur minute (« E · 12′ 7-0 »), la mi-temps et la minute en cours sont marquées.
class Domination extends Control:
	const Charte = preload("res://ui/charte.gd")
	const POLICE = preload("res://ui/immersive08/fonts/BarlowCondensed-Bold.ttf")
	## Un repère cliqué (essai, pénalité, carton) : l'indice du fait dans le journal du match.
	signal repere_choisi(i: int)
	var minutes: Array = []
	var mi_temps: Variant = null
	var reperes: Array = []
	var couleurs: Array[Color] = [Charte.CLUB, Charte.IVOIRE_2]
	var sigles: Array = ["", ""]
	## Noms montrés dans la légende de gauche (nous d'abord).
	var noms: Array = ["", ""]
	## Notre côté (0 ou 1) : il est dessiné au-dessus de l'axe ; -1 : l'équipe qui reçoit au-dessus.
	var camp := -1
	## Score après chaque fait (indice du journal → [a, b]) quand le repère ne le porte pas lui-même.
	var scores: Dictionary = {}
	var densite := 0.5
	## [nous, eux] aux couleurs des clubs ; vide : vert clair / doré de la charte.
	var teintes: Array = []
	## D2 : le score cumulé de chaque club en escalier par-dessus les barres.
	var escalier_visible := false
	## Planche A (revue FM27) : légende réduite aux sigles, frise logée sous le terrain.
	var legende_etroite := false
	## Étiquettes des repères dessinées à la dernière image : [Rect2, indice du fait, texte].
	var _etiquettes: Array = []
	var _zone := Rect2()
	var _pas := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _haut() -> int:
		return camp if camp in [0, 1] else 0

	## Texte d'un repère : type (E essai, P pénalité ou drop, C carton), auteur s'il est connu, minute, score vu de nous.
	func texte_repere(repere: Dictionary) -> String:
		var kind := str(repere.get("kind", ""))
		var lettre := "E" if kind == "try" else ("C" if kind == "card" else "P")
		var qui := str(repere.get("nom", "")).strip_edges()
		var morceaux := ["%s · %s" % [lettre, qui if not qui.is_empty() else str(repere.get("horloge", ""))]]
		if not qui.is_empty(): morceaux.append(str(repere.get("horloge", "")))
		var marque: Variant = repere.get("score") if repere.get("score") is Array else scores.get(int(repere.get("i", -1)))
		if kind != "card" and marque is Array and (marque as Array).size() == 2:
			var haut := _haut()
			morceaux.append("%d-%d" % [int(marque[haut]), int(marque[1 - haut])])
		return " ".join(morceaux)

	## Échelle de la frise : la plus petite graduation (25, 50, 75, 100) qui contient la minute la plus nette.
	## Échelle adaptée aux valeurs réelles : la graduation qui contient neuf minutes sur dix (une minute isolée plus
	## forte dépasse et touche le bord), jamais moins de 10.
	func echelle_frise() -> int:
		var valeurs: Array = minutes.map(func(v: Variant) -> float: return absf(float(v)))
		valeurs.sort()
		var repere: float = float(valeurs[mini(valeurs.size() - 1, int(floor(valeurs.size() * 0.9)))]) if not valeurs.is_empty() else 0.0
		for palier in [10, 20, 30, 40, 50, 60, 80, 100]:
			if repere <= palier: return palier
		return 100

	## Score cumulé vu de nous ([[minute, nous, eux], …]) d'après les repères qui portent un score.
	func escalier() -> Array:
		var points: Array = [[0.0, 0, 0]]
		var haut := _haut()
		var tries := reperes.duplicate()
		tries.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("minute", 0)) < float(b.get("minute", 0)))
		for repere: Dictionary in tries:
			var marque: Variant = repere.get("score") if repere.get("score") is Array else scores.get(int(repere.get("i", -1)))
			if str(repere.get("kind", "")) == "card" or not marque is Array or (marque as Array).size() != 2: continue
			points.append([float(repere.get("minute", 0)), int(marque[haut]), int(marque[1 - haut])])
		return points

	func _draw() -> void:
		_etiquettes.clear()
		var corps := maxi(13, roundi(20.0 * densite))
		var petit := maxi(13, roundi(18.0 * densite))
		var ligne_texte := corps * 1.3
		var gauche := maxf(150.0, 250.0 * densite) if not legende_etroite else maxf(48.0, 70.0 * densite)
		var droite := maxf(28.0, 48.0 * densite)
		# Rangées des pastilles des repères : les nôtres au-dessus des barres, les leurs sous l'échelle des minutes.
		var zone := Rect2(Vector2(gauche, ligne_texte * 1.15), size - Vector2(gauche + droite, ligne_texte * 1.15 + ligne_texte * 2.25))
		if zone.size.x < 40.0 or zone.size.y < 20.0: return
		_zone = zone
		var milieu := zone.position.y + zone.size.y * 0.5
		var haut := _haut()
		var nous := Charte.V
		var eux := Charte.D
		if teintes.size() == 2:
			nous = teintes[0]
			eux = teintes[1]
		# Légende : la couleur et le nom de chaque club, du côté de ses barres (au-dessus : nous).
		var nom_haut := str(noms[0]) if not str(noms[0]).is_empty() and not legende_etroite else str(sigles[haut])
		var nom_bas := str(noms[1]) if not str(noms[1]).is_empty() and not legende_etroite else str(sigles[1 - haut])
		var case := float(corps) * 0.8
		for k in 2:
			# Les deux noms jamais l'un sur l'autre, même sur une frise basse.
			var y := milieu + (-1.0 if k == 0 else 1.0) * maxf(zone.size.y * 0.25, corps * 0.75)
			draw_rect(Rect2(0, y - case * 0.5, case, case), nous if k == 0 else eux)
			var nom := nom_haut if k == 0 else nom_bas
			var taille_nom := corps
			while taille_nom > 12 and POLICE.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_nom).x > gauche - case - 18.0: taille_nom -= 1
			draw_string(POLICE, Vector2(case + 8.0, y + taille_nom * 0.36), nom, HORIZONTAL_ALIGNMENT_LEFT, gauche - case - 14.0, taille_nom, Charte.IVOIRE)
		# Échelle de 80 minutes (40 avant la mi-temps) : la place d'une minute ne change pas pendant le match.
		var fin := 40 if minutes.size() <= 40 else 80
		fin = maxi(fin, minutes.size())
		var pas := zone.size.x / float(fin)
		_pas = pas
		# Graduations : ± l'échelle (tirets) et l'axe ; valeur écrite à droite de la frise.
		var palier := echelle_frise()
		var demi := zone.size.y * 0.5
		for signe in [-1.0, 1.0]:
			var y_palier: float = milieu + signe * demi
			draw_dashed_line(Vector2(zone.position.x, y_palier), Vector2(zone.end.x, y_palier), Color(Charte.FILET, 0.9), 1.0, 6.0)
			draw_dashed_line(Vector2(zone.position.x, milieu + signe * demi * 0.5), Vector2(zone.end.x, milieu + signe * demi * 0.5), Color(Charte.FILET, 0.5), 1.0, 4.0)
			draw_string(POLICE, Vector2(zone.end.x + 6.0, y_palier + petit * 0.36), str(palier), HORIZONTAL_ALIGNMENT_LEFT, droite, petit, Charte.IVOIRE_2)
		draw_string(POLICE, Vector2(zone.end.x + 6.0, milieu + petit * 0.36), "0", HORIZONTAL_ALIGNMENT_LEFT, droite, petit, Charte.IVOIRE_2)
		for repere in range(0, fin + 1, 10):
			var x := zone.position.x + float(repere) * pas
			draw_line(Vector2(x, zone.position.y), Vector2(x, zone.end.y), Color(Charte.FILET, 0.7), 1.0)
			var etiquette := "%d′" % repere
			var largeur_e := POLICE.get_string_size(etiquette, HORIZONTAL_ALIGNMENT_LEFT, -1, petit).x
			draw_string(POLICE, Vector2(clampf(x - largeur_e * 0.5, zone.position.x, size.x - largeur_e), zone.end.y + ligne_texte * 0.95), etiquette, HORIZONTAL_ALIGNMENT_LEFT, -1, petit, Charte.IVOIRE_2)
		# Barres pleines aux couleurs des deux clubs, de part et d'autre de l'axe (au-dessus : nous).
		var largeur := maxf(2.0, pas * 0.78)
		var voile := 0.55 if escalier_visible else 1.0
		for n in minutes.size():
			var v := clampf(float(minutes[n]) / float(palier), -1.0, 1.0)
			if haut == 1: v = -v
			if absf(v) < 0.01: continue
			var h := maxf(1.5, absf(v) * demi)
			var x := zone.position.x + float(n) * pas + (pas - largeur) * 0.5
			if v > 0.0: draw_rect(Rect2(x, milieu - h, largeur, h), Color(nous, voile))
			else: draw_rect(Rect2(x, milieu, largeur, h), Color(eux, voile))
		draw_line(Vector2(zone.position.x, milieu), Vector2(zone.end.x, milieu), Charte.IVOIRE_2, maxf(1.0, densite * 2.0))
		var xc := zone.position.x + minutes.size() * pas
		if mi_temps is int or mi_temps is float:
			var xm := zone.position.x + float(mi_temps) * pas
			draw_line(Vector2(xm, zone.position.y), Vector2(xm, zone.end.y), Charte.IVOIRE_2, maxf(1.0, densite * 2.0))
		# D2 : le score cumulé en escalier par-dessus (points de chaque club, échelle des points sur la hauteur).
		if escalier_visible:
			var marches := escalier()
			var maxi_points := 10
			for m: Array in marches: maxi_points = maxi(maxi_points, maxi(int(m[1]), int(m[2])))
			var fin_x := xc if not minutes.is_empty() else zone.position.x
			for k in 2:
				var teinte: Color = (nous if k == 0 else eux).lightened(0.25)
				var trace := PackedVector2Array()
				var y_prec := zone.end.y
				for m: Array in marches:
					var xm := zone.position.x + clampf(float(m[0]) * pas, 0.0, zone.size.x)
					var y_m := zone.end.y - float(m[1 + k]) / float(maxi_points) * zone.size.y * 0.95
					trace.append(Vector2(xm, y_prec))
					trace.append(Vector2(xm, y_m))
					y_prec = y_m
				trace.append(Vector2(maxf(fin_x, trace[-1].x), y_prec))
				draw_polyline(trace, Color(Charte.FOND, 0.9), maxf(4.0, 7.0 * densite), true)
				draw_polyline(trace, teinte, maxf(2.0, 4.0 * densite), true)
				var total := str(int(marches[-1][1 + k]))
				draw_string(POLICE, Vector2(trace[-1].x + 6.0, y_prec + corps * 0.36), total, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, teinte)
		# Minute courante : trait ivoire épais et sa minute écrite en pastille au-dessus de la frise.
		if not minutes.is_empty():
			draw_line(Vector2(xc, zone.position.y - 4.0), Vector2(xc, zone.end.y + 4.0), Charte.IVOIRE, maxf(2.0, densite * 3.0))
			var minute_txt := "%d′" % minutes.size()
			var mesure_m := POLICE.get_string_size(minute_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, petit)
			var boite := Rect2(Vector2(clampf(xc - mesure_m.x * 0.5 - 8.0, 0.0, size.x - mesure_m.x - 16.0), zone.end.y + 4.0), Vector2(mesure_m.x + 16.0, petit * 1.35))
			draw_style_box(_pilule(Charte.IVOIRE), boite)
			draw_string(POLICE, Vector2(boite.position.x + 8.0, boite.position.y + petit * 1.02), minute_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, petit, Charte.ENCRE)
		# Repères : pastille du club (lettre E, P ou C) à la minute, et le texte (auteur, minute, score) à côté ;
		# une ou deux rangées par camp, sans chevauchement entre étiquettes ni avec la minute courante.
		var taille := petit
		var rond := float(taille) * 0.62
		var occupe := {"haut0": [], "haut1": [], "bas0": [], "bas1": []}
		for repere: Dictionary in reperes:
			var m := float(repere.get("minute", 0))
			var cote := clampi(int(repere.get("equipe", 0)), 0, 1)
			var x := zone.position.x + clampf((m - 0.5) * pas, 0.0, zone.size.x)
			var texte := texte_repere(repere)
			var mesure := POLICE.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x + rond * 2.0 + 6.0
			var dessus := cote == haut
			var debut := clampf(x - rond, 0.0, size.x - mesure - 2.0)
			# Première rangée libre ; sinon, décalée à droite de l'étiquette qui la gêne (jamais de chevauchement).
			var rang := ""
			var premiere_rangee := "%s0" % ("haut" if dessus else "bas")
			var seconde_libre := not (dessus == false and zone.end.y + ligne_texte * 3.05 > size.y)
			for essai in (["0", "1"] if seconde_libre else ["0"]):
				var cle: String = ("haut" if dessus else "bas") + essai
				if not (occupe[cle] as Array).any(func(r: Vector2) -> bool: return debut < r.y + 8.0 and debut + mesure > r.x - 8.0):
					rang = cle
					break
			if rang.is_empty():
				for _tour in 4:
					var gene: Array = (occupe[premiere_rangee] as Array).filter(func(r: Vector2) -> bool: return debut < r.y + 8.0 and debut + mesure > r.x - 8.0)
					if gene.is_empty():
						rang = premiere_rangee
						break
					debut = (gene[-1] as Vector2).y + 12.0
				if debut + mesure > size.x - 2.0: rang = ""
			if rang.is_empty(): continue
			(occupe[rang] as Array).append(Vector2(debut, debut + mesure))
			var base_y: float
			if dessus: base_y = zone.position.y - 4.0 - (ligne_texte if rang.ends_with("1") else 0.0)
			else: base_y = zone.end.y + ligne_texte * (2.05 if rang.ends_with("0") else 3.05)
			if dessus and rang.ends_with("1") and base_y - taille < 0.0: continue
			if not dessus and base_y > size.y: continue
			var centre_rond := Vector2(debut + rond, base_y - taille * 0.36)
			draw_line(Vector2(x, milieu), Vector2(x, zone.position.y if dessus else zone.end.y), Color(Charte.IVOIRE_2, 0.5), 1.0)
			var fond: Color = nous if cote == haut else eux
			var kind := str(repere.get("kind", ""))
			if kind == "card": fond = Charte.D if bool(repere.get("rouge", false)) else Charte.ATTRIBUT_55
			draw_circle(centre_rond, rond, fond)
			draw_arc(centre_rond, rond, 0.0, TAU, 24, Charte.FOND, 1.5, true)
			var lettre := "E" if kind == "try" else ("C" if kind == "card" else "P")
			var lmesure := POLICE.get_string_size(lettre, HORIZONTAL_ALIGNMENT_LEFT, -1, taille - 2).x
			draw_string(POLICE, centre_rond + Vector2(-lmesure * 0.5, (taille - 2) * 0.36), lettre, HORIZONTAL_ALIGNMENT_LEFT, -1, taille - 2, Charte.ENCRE if fond.get_luminance() > 0.55 else Charte.IVOIRE)
			var texte_x := debut + rond * 2.0 + 6.0
			draw_string(POLICE, Vector2(texte_x, base_y), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Charte.IVOIRE)
			# Souligné discret : c'est un lien (clic = le journal à ce fait).
			var largeur_t := POLICE.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
			draw_line(Vector2(texte_x, base_y + 2.0), Vector2(texte_x + largeur_t, base_y + 2.0), Color(Charte.IVOIRE, 0.35), 1.0)
			_etiquettes.append([Rect2(debut, base_y - taille, mesure, taille + 3.0), int(repere.get("i", -1)), texte])

	func _pilule(couleur: Color) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = couleur
		style.set_corner_radius_all(Charte.RAYON_PILULE)
		style.anti_aliasing = true
		return style

	func _etiquette_sous(point: Vector2) -> Array:
		for e: Array in _etiquettes:
			if (e[0] as Rect2).grow(3.0).has_point(point): return e
		return []

	func _gui_input(event: InputEvent) -> void:
		var mouvement := event as InputEventMouseMotion
		if mouvement != null:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _etiquette_sous(mouvement.position).is_empty() else Control.CURSOR_ARROW
			return
		var clic := event as InputEventMouseButton
		if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
			var e := _etiquette_sous(clic.position)
			if not e.is_empty() and int(e[1]) >= 0:
				repere_choisi.emit(int(e[1]))
				accept_event()

	## Infobulle à la minute survolée (« 13′ : Alder Fen XV domine, +42 ») ou du repère (« → journal »).
	func _get_tooltip(at_position: Vector2) -> String:
		var e := _etiquette_sous(at_position)
		if not e.is_empty(): return "%s\nClic : le journal du match à ce fait." % str(e[2])
		if _zone.has_point(at_position) and _pas > 0.0:
			var n := int((at_position.x - _zone.position.x) / _pas)
			if n >= 0 and n < minutes.size():
				var v := float(minutes[n]) * (1.0 if _haut() == 0 else -1.0)
				var qui := str(noms[0]) if v >= 0.0 else str(noms[1])
				return "%d′ : %s domine (%s%d)" % [n + 1, qui, "+" if v >= 0.0 else "−", absi(roundi(v))] if absf(v) >= 1.0 else "%d′ : équilibre" % (n + 1)
		return tooltip_text

## Météo du match posée dans un coin du terrain 2D (à la place de la phrase sous le score, retouche de Léo du
## 21/11/2026) : vent (icône, flèche vers le camp où il souffle, force en barres), pluie (gouttes), chaleur (soleil).
## Rien sans météo particulière ; l'infobulle donne la phrase complète (qui a le vent dans le dos, quelle période).
class PastilleMeteo extends Control:
	const Charte = preload("res://ui/charte.gd")
	var vent := 0
	var pluie := 0
	var chaleur := 0
	## +1 : le vent souffle vers la droite du terrain ; -1 : vers la gauche ; 0 : sans sens connu.
	var sens := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	## Largeur voulue pour une hauteur `h`.
	func largeur(h: float) -> float:
		var w := h * 0.35
		if vent > 0: w += h * (1.0 + (0.95 if sens != 0 else 0.0) + 0.75) + h * 0.25
		if pluie > 0: w += h * 0.45 * pluie + h * 0.25
		if chaleur > 0: w += h * 0.8 + h * 0.25
		return w

	func _draw() -> void:
		var h := size.y
		var fond := StyleBoxFlat.new()
		fond.bg_color = Color(Charte.FOND, 0.88)
		fond.set_corner_radius_all(Charte.RAYON_PILULE)
		fond.anti_aliasing = true
		fond.border_color = Color(1, 1, 1, 0.22)
		fond.set_border_width_all(1)
		draw_style_box(fond, Rect2(Vector2.ZERO, size))
		var x := h * 0.3
		var c := h * 0.5
		var epais := maxf(1.5, h * 0.07)
		var ivoire := Charte.IVOIRE
		if vent > 0:
			# Icône de vent : trois traits dont deux finissent en volute.
			for k in 3:
				var y := c + (k - 1) * h * 0.2
				var long := h * (0.75 if k != 1 else 0.6)
				draw_line(Vector2(x, y), Vector2(x + long, y), ivoire, epais, true)
				if k != 1: draw_arc(Vector2(x + long, y - h * 0.08 * (1 if k == 0 else -1)), h * 0.08, -PI / 2.0 if k == 0 else PI / 2.0, PI / 2.0 if k == 0 else PI * 1.5, 8, ivoire, epais, true)
			x += h * 1.0
			if sens != 0:
				# Flèche : vers le camp où souffle le vent.
				var a := Vector2(x + (0.0 if sens > 0 else h * 0.75), c)
				var b := Vector2(x + (h * 0.75 if sens > 0 else 0.0), c)
				draw_line(a, b - Vector2(sens * h * 0.15, 0), Charte.MORAL, epais * 1.4, true)
				draw_colored_polygon(PackedVector2Array([b, b + Vector2(-sens * h * 0.25, -h * 0.18), b + Vector2(-sens * h * 0.25, h * 0.18)]), Charte.MORAL)
				x += h * 0.95
			# Force : trois barres montantes, pleines selon la force (vent 1 : deux, grand vent : trois).
			var pleines := clampi(vent + 1, 1, 3)
			for k in 3:
				var hb := h * (0.25 + 0.15 * k)
				draw_rect(Rect2(x + k * h * 0.25, c + h * 0.28 - hb, h * 0.16, hb), ivoire if k < pleines else Color(ivoire, 0.25))
			x += h * 1.0
		if pluie > 0:
			for k in pluie:
				var g := Vector2(x + h * 0.2 + k * h * 0.45, c + h * 0.05)
				draw_circle(g, h * 0.14, Charte.MORAL)
				draw_colored_polygon(PackedVector2Array([g + Vector2(-h * 0.13, -h * 0.05), g + Vector2(0, -h * 0.32), g + Vector2(h * 0.13, -h * 0.05)]), Charte.MORAL)
			x += h * 0.45 * pluie + h * 0.25
		if chaleur > 0:
			var soleil := Vector2(x + h * 0.4, c)
			draw_circle(soleil, h * 0.16, Charte.INTENSIF)
			for k in 8:
				var ang := k * TAU / 8.0
				draw_line(soleil + Vector2.from_angle(ang) * h * 0.24, soleil + Vector2.from_angle(ang) * h * 0.34, Charte.INTENSIF, epais, true)

## Pictogramme d'un fait (fil du match) : essai, tir au but, carton, mêlée, touche, jeu au pied, ballon
## perdu. Pastille sombre cerclée à la couleur du camp (nous vert clair, eux doré), signe crème au centre.
class Picto:
	const Charte = preload("res://ui/charte.gd")
	static func dessiner(ci: CanvasItem, c: Vector2, r: float, kind: String, teinte: Color, rouge: bool = false) -> void:
		ci.draw_circle(c, r, Charte.PANNEAU)
		ci.draw_arc(c, r - 0.5, 0.0, TAU, 28, teinte, maxf(1.0, r * 0.12), true)
		var epais := maxf(1.2, r * 0.14)
		var blanc := Charte.IVOIRE
		match kind:
			"try":
				ci.draw_set_transform(c, -0.6, Vector2(1.4, 0.85))
				ci.draw_circle(Vector2.ZERO, r * 0.42, blanc)
				ci.draw_set_transform(Vector2.ZERO, 0.0)
			"goal", "miss", "penalty", "transformation":
				ci.draw_line(c + Vector2(-r * 0.35, -r * 0.5), c + Vector2(-r * 0.35, r * 0.5), blanc, epais, true)
				ci.draw_line(c + Vector2(r * 0.35, -r * 0.5), c + Vector2(r * 0.35, r * 0.5), blanc, epais, true)
				ci.draw_line(c + Vector2(-r * 0.35, r * 0.1), c + Vector2(r * 0.35, r * 0.1), blanc, epais, true)
			"card":
				# Couleur du carton (jaune ou rouge) : c'est l'objet lui-même, et le texte le nomme.
				ci.draw_rect(Rect2(c - Vector2(r * 0.3, r * 0.45), Vector2(r * 0.6, r * 0.9)), Charte.ROUGE if rouge else Charte.ATTRIBUT_55)
			"scrum", "setpiece-win", "setpiece-loss":
				for dx in [-0.3, 0.3]:
					for dy in [-0.22, 0.22]: ci.draw_circle(c + Vector2(dx, dy) * r, r * 0.17, blanc)
			"lineout":
				ci.draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, r * 0.5), blanc, epais, true)
				ci.draw_circle(c + Vector2(0, -r * 0.5), r * 0.16, blanc)
			"turnover", "hand-fault":
				ci.draw_line(c - Vector2(r * 0.35, r * 0.35), c + Vector2(r * 0.35, r * 0.35), blanc, epais, true)
				ci.draw_line(c + Vector2(-r * 0.35, r * 0.35), c + Vector2(r * 0.35, -r * 0.35), blanc, epais, true)
			"kick", "kickoff", "drop22", "goalLine", "touch":
				ci.draw_arc(c + Vector2(0, r * 0.35), r * 0.5, PI * 1.1, PI * 1.9, 12, blanc, epais, true)
				ci.draw_circle(c + Vector2(r * 0.4, -r * 0.05), r * 0.14, blanc)
			"carry":
				ci.draw_line(c + Vector2(-r * 0.4, 0), c + Vector2(r * 0.3, 0), blanc, epais, true)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.5, 0), c + Vector2(r * 0.18, -r * 0.24), c + Vector2(r * 0.18, r * 0.24)]), blanc)
			_:
				ci.draw_circle(c, r * 0.18, blanc)

class Icone extends Control:
	var kind := ""
	var teinte := Color.WHITE
	var rouge := false

	func _draw() -> void:
		Picto.dessiner(self, size * 0.5, minf(size.x, size.y) * 0.5, kind, teinte, rouge)

## Barres face à face d'un chiffre clé (jauge de comparaison de la charte) : notre part pleine à gauche en vert
## clair, l'adversaire en pilule vide au trait doré à droite ; rail `PANNEAU_2` en pilule.
class Barre extends Control:
	const Charte = preload("res://ui/charte.gd")
	## [nous, eux].
	var valeurs: Array = [0, 0]
	var couleurs: Array[Color] = [Charte.V, Charte.D]
	var densite := 0.5

	func _pilule(r: Rect2, couleur: Color, plein: bool) -> void:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(Charte.RAYON_PILULE)
		style.anti_aliasing = true
		style.bg_color = couleur if plein else Color(0, 0, 0, 0)
		if not plein:
			style.border_color = couleur
			style.set_border_width_all(1)
		draw_style_box(style, r)

	func _draw() -> void:
		var a := maxf(0.0, float(valeurs[0]))
		var b := maxf(0.0, float(valeurs[1]))
		var h := maxf(5.0, 12.0 * densite)
		var y := (size.y - h) * 0.5
		_pilule(Rect2(0, y, size.x, h), Charte.PANNEAU_2, true)
		if a + b <= 0.0: return
		var part := a / (a + b)
		var jour := maxf(2.0, 4.0 * densite)
		if part > 0.0: _pilule(Rect2(0, y, maxf(h, size.x * part - jour * 0.5), h), couleurs[0], true)
		if part < 1.0:
			var r := Rect2(size.x * part + jour * 0.5, y, maxf(h, size.x * (1.0 - part) - jour * 0.5), h)
			# Variantes C et D : leur part teintée à demi sous le contour (plus de couleur, toujours « vide » à côté du plein).
			if couleurs[0] != Charte.V: _pilule(r, Color(couleurs[1], 0.45), true)
			_pilule(r, couleurs[1], false)

## Évolution d'un club au classement en direct (`delta` du moteur) : triangle vers le haut s'il gagne des
## places, vers le bas s'il en perd, tiret sinon (la forme porte le sens, la couleur le double).
class Fleche extends Control:
	const Charte = preload("res://ui/charte.gd")
	var delta := 0
	## Encre imposée (flèche posée sur un aplat de couleur) ; transparente : vert, rouge ou gris de la charte.
	var encre := Color(0, 0, 0, 0)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.32
		var propre := encre.a > 0.0
		if delta > 0: draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.7), c + Vector2(-r, r * 0.7)]), encre if propre else Charte.V)
		elif delta < 0: draw_colored_polygon(PackedVector2Array([c + Vector2(0, r), c + Vector2(r, -r * 0.7), c + Vector2(-r, -r * 0.7)]), encre if propre else Charte.D)
		else: draw_line(c - Vector2(r * 0.8, 0), c + Vector2(r * 0.8, 0), encre if propre else Charte.IVOIRE_3, maxf(1.0, r * 0.35))

## Pastille ronde aux couleurs d'un club (neutre si la couleur est inconnue).
class Pastille extends Control:
	const Charte = preload("res://ui/charte.gd")
	var teinte := Charte.IVOIRE_3

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, teinte)
		draw_arc(size * 0.5, r - 0.5, 0.0, TAU, 20, Charte.FILET, 1.0, true)

## Variantes C et D : momentum des cinq dernières minutes (moyenne de `direct.domination`), une barre aux couleurs des
## deux clubs dont la frontière glisse vers le camp qui recule ; sigle et part écrits de chaque côté, chevrons animés
## du côté qui pousse (immobiles si les animations sont réduites).
class Momentum extends Control:
	const Charte = preload("res://ui/charte.gd")
	const POLICE = preload("res://ui/immersive08/fonts/BarlowCondensed-ExtraBold.ttf")
	var part := 0.5
	var cible := 0.5
	var teintes: Array = [Charte.V, Charte.D]
	var sigles: Array = ["", ""]
	var densite := 0.5
	var reduit := false
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func viser(valeur: float) -> void:
		cible = clampf(valeur, 0.1, 0.9)
		if reduit: part = cible
		queue_redraw()

	func _process(delta: float) -> void:
		if reduit or not is_visible_in_tree(): return
		_t += delta
		part = lerpf(part, cible, minf(1.0, delta * 2.5))
		queue_redraw()

	static func encre_sur(fond: Color) -> Color:
		return Charte.ENCRE if fond.get_luminance() > 0.55 else Charte.IVOIRE

	func _pilule(r: Rect2, couleur: Color) -> void:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(Charte.RAYON_PILULE)
		style.anti_aliasing = true
		style.bg_color = couleur
		draw_style_box(style, r)

	func _draw() -> void:
		var h := size.y
		if size.x < h * 4.0: return
		var a: Color = teintes[0]
		var b: Color = teintes[1]
		_pilule(Rect2(Vector2.ZERO, size), b)
		var x := size.x * part
		_pilule(Rect2(0, 0, maxf(h, x), h), a)
		draw_line(Vector2(x, -2.0), Vector2(x, h + 2.0), Charte.IVOIRE, maxf(2.0, 3.0 * densite))
		# Chevrons du côté qui pousse (part > 0,5 : nous), défilant vers l'adversaire.
		var pousse := part - 0.5
		if absf(pousse) > 0.03:
			var sens := 1.0 if pousse > 0.0 else -1.0
			var fond := a if pousse > 0.0 else b
			var pas := h * 0.75
			var decal := fmod(_t * h * 1.2, pas) if not reduit else 0.0
			for k in 3:
				var cx := x - sens * (h * 0.6 + k * pas + (pas - decal))
				var alpha := 0.35 + 0.2 * k
				var c := Color(encre_sur(fond), alpha)
				var dy := h * 0.28
				draw_polyline(PackedVector2Array([Vector2(cx - sens * h * 0.18, h * 0.5 - dy), Vector2(cx + sens * h * 0.18, h * 0.5), Vector2(cx - sens * h * 0.18, h * 0.5 + dy)]), c, maxf(2.0, h * 0.1), true)
		var taille := maxi(12, roundi(h * 0.62))
		var gauche := "%s %d %%" % [str(sigles[0]), roundi(part * 100.0)]
		var droite := "%d %% %s" % [roundi((1.0 - part) * 100.0), str(sigles[1])]
		var base := h * 0.5 + taille * 0.36
		draw_string(POLICE, Vector2(h * 0.5, base), gauche, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, encre_sur(a))
		var largeur := POLICE.get_string_size(droite, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		draw_string(POLICE, Vector2(size.x - h * 0.5 - largeur, base), droite, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, encre_sur(b))

## Variantes C et D : symbole de zone du classement (mêmes formes que l'écran Classements, standings_zones.gd) :
## ★ exempté, ● qualifié, ▲ barrage de montée, ◆ barrage de maintien, ▼ relégation, ○ repêchage.
class MarqueZone extends Control:
	const Charte = preload("res://ui/charte.gd")
	var kind := ""
	var teinte := Charte.IVOIRE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if kind.is_empty(): return
		var s := minf(size.x, size.y)
		var o := (size - Vector2(s, s)) * 0.5
		var points := PackedVector2Array()
		match kind:
			"bye":
				for k in 10:
					var rayon := 0.52 if k % 2 == 0 else 0.25
					var angle := -PI / 2 + k * PI / 5
					points.append(Vector2(0.5 + rayon * cos(angle), 0.53 + rayon * sin(angle)))
			"promotion-playoff": points = PackedVector2Array([Vector2(0.5, 0.06), Vector2(0.96, 0.9), Vector2(0.04, 0.9)])
			"relegation-playoff": points = PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)])
			"relegation": points = PackedVector2Array([Vector2(0.04, 0.1), Vector2(0.96, 0.1), Vector2(0.5, 0.94)])
			_:
				for k in 20: points.append(Vector2(0.5 + 0.44 * cos(k * TAU / 20), 0.5 + 0.44 * sin(k * TAU / 20)))
		for k in points.size(): points[k] = o + points[k] * s
		if kind == "repechage":
			points.append(points[0])
			draw_polyline(points, teinte, maxf(1.5, s * 0.16), true)
		else: draw_colored_polygon(points, teinte)

## Jauge d'énergie de Mon XV (jauge de la charte : rail et remplissage en pilule, repère du seuil de fatigue) :
## vert clair en forme (80 et plus), gris-vert au repos, doré sous le seuil de fatigue ; la valeur et le mot
## (« fatigué », « épuisé ») sont écrits à côté.
class Jauge extends Control:
	const Charte = preload("res://ui/charte.gd")
	var valeur := 100.0
	var densite := 0.5
	## Variantes C et D : couleurs franches de la palette des données (forme verte, entame orange, alerte rouge).
	var vive := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	static func teinte_pour(v: float) -> Color:
		return Charte.D if v < 55.0 else (Charte.V if v >= 80.0 else Charte.IVOIRE_2)

	static func teinte_vive(v: float) -> Color:
		return Charte.PERTE if v < 55.0 else (Charte.CONDITION if v >= 75.0 else Charte.INTENSIF)

	func _draw() -> void:
		var h := maxf(3.0, 6.0 * densite)
		var y := (size.y - h) * 0.5
		var rail := StyleBoxFlat.new()
		rail.set_corner_radius_all(Charte.RAYON_PILULE)
		rail.anti_aliasing = true
		rail.bg_color = Charte.PANNEAU_3
		draw_style_box(rail, Rect2(0, y, size.x, h))
		var part := clampf(valeur / 100.0, 0.0, 1.0)
		if part > 0.0:
			var plein: StyleBoxFlat = rail.duplicate()
			plein.bg_color = teinte_vive(valeur) if vive else teinte_pour(valeur)
			draw_style_box(plein, Rect2(0, y, maxf(h, size.x * part), h))
		# Repère du seuil de fatigue (55 %), comme sur la maquette.
		var xs := size.x * 0.55
		draw_line(Vector2(xs, y - h * 0.6), Vector2(xs, y + h * 1.6), Charte.IVOIRE_3, 1.0)

## Échelle de l'interface, comme les autres écrans du jeu (immersive08/components.gd) :
## les tailles sont écrites pour 2560×1440 et réduites jusqu'à la moitié en 1280×720.
static func densite_pour(taille: Vector2) -> float:
	return clampf(minf(taille.y / 1440.0, taille.x / 2560.0), 0.5, 1.0)

func px(valeur: float) -> int:
	return roundi(valeur * _densite)

## Taille de police à l'échelle, jamais sous le plancher de 12 px de la charte.
## Textes de l'écran 2D d'un à deux points sous la taille écrite (retouche de Léo du 21/11/2026 : écran plus aéré).
## Vide entre les grands blocs de l'écran (unités 2560) : chaque bloc est une tuile séparée, fond de page visible
## autour (retouche de Léo du 21/11/2026).
const GOUTTIERE := 24

## Boîte horizontale ou verticale dont l'écart est appliqué tel quel (S.G.h / S.G.v le plafonnent à 8 px).
func _boite(horizontale: bool, ecart: int) -> BoxContainer:
	var boite: BoxContainer = HBoxContainer.new() if horizontale else VBoxContainer.new()
	boite.add_theme_constant_override("separation", px(ecart))
	return boite

func fpx(valeur: float) -> int:
	return maxi(12, px(valeur - (2.0 if valeur >= 20.0 else 1.0)))

func _texte(texte: String, taille: float, couleur: Color, retour: bool = false, titre: bool = false) -> Label:
	var etiquette := S.wrap(texte, fpx(taille), couleur) if retour else S.label(texte, fpx(taille), couleur)
	etiquette.add_theme_font_size_override("font_size", fpx(taille))
	if titre: etiquette.add_theme_font_override("font", TITRES)
	return etiquette

## Titre de bloc de la charte : capitales Barlow Condensed ExtraBold, droites, crème.
func _titre_bloc(texte: String, taille: float = 24) -> Label:
	var etiquette := _texte(texte.to_upper(), taille, IVOIRE, false, true)
	etiquette.add_theme_font_override("font", Charte.TITRE_FICHE)
	return etiquette

## Bouton de l'écran : l'action principale en pilule dorée (un seul aplat doré par écran), les autres en lien
## de la charte (texte crème, souligné au survol).
func _bouton(texte: String, action: Callable, actif: bool = true, principal: bool = false) -> Button:
	var bouton := S.button(texte, action, actif, principal)
	_habiller(bouton, principal)
	return bouton

func _habiller(bouton: Control, principal: bool = false) -> void:
	if principal:
		# Pilule dorée ; éteint : pilule à contour `FILET` (bouton secondaire de la charte), sans aplat doré.
		C.style_bouton_ivoire_plein(bouton as BaseButton)
		bouton.add_theme_font_size_override("font_size", fpx(22))
		bouton.custom_minimum_size.y = maxi(26, px(46))
		return
	# Action secondaire : le lien commun de la charte (texte ivoire, flèche, souligné au survol), jamais un cadre.
	C.style_bouton_lien(bouton as BaseButton)
	bouton.add_theme_font_size_override("font_size", fpx(22))
	bouton.custom_minimum_size.y = maxi(26, px(40))

## Choix d'un groupe (segment : vitesse, temps forts, consigne de fin de match) : case rayon 6 sur `PANNEAU_2`,
## le choix courant sur `SELECTION` avec une coche (la couleur ne porte pas seule le choix) ; focus : anneau doré.
func _style_segment(bouton: Button) -> void:
	for etat_bouton in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var choisi: bool = etat_bouton in ["pressed", "hover_pressed"]
		var style := _case(Charte.SELECTION if choisi else (SURVOL if etat_bouton == "hover" else RELIEF))
		if etat_bouton == "focus": _anneau(style)
		style.content_margin_left = px(16)
		style.content_margin_right = px(16)
		style.content_margin_top = px(6)
		style.content_margin_bottom = px(6)
		bouton.add_theme_stylebox_override(etat_bouton, style)
	for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(couleur, IVOIRE)
	bouton.add_theme_color_override("font_disabled_color", FAIBLE)
	bouton.add_theme_font_override("font", TITRES)
	bouton.add_theme_font_size_override("font_size", fpx(20))
	bouton.add_theme_constant_override("icon_max_width", fpx(18))
	bouton.custom_minimum_size.y = maxi(26, px(44))

## Case de la charte (rayon 6 par défaut), sans bordure.
func _case(fond: Color, rayon: int = Charte.RAYON_PETIT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.set_corner_radius_all(rayon)
	style.anti_aliasing = true
	return Charte.ombrer(style, rayon)

## Anneau de focus clavier de la charte : doré, 2 px, décalé de 2 px (seul contour complet permis avec le
## bouton secondaire).
func _anneau(style: StyleBoxFlat) -> void:
	style.border_color = Charte.OR
	style.set_border_width_all(2)
	style.set_expand_margin_all(2)

## Coche du choix courant d'un segment (icône de la charte, la couleur ne porte pas seule le choix).
func _cocher(bouton: Button, choisi: bool) -> void:
	bouton.icon = C.icon_texture("check", IVOIRE) if choisi else null
	bouton.set_meta("coche", choisi)
## Lien de la charte : texte ivoire (+ flèche), souligné au survol et au focus, sans cadre.
func _lien(texte: String, action: Callable, nom: String = "") -> Button:
	var bouton := Button.new()
	bouton.text = texte
	if not nom.is_empty(): bouton.name = nom
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.pressed.connect(action)
	C.style_bouton_lien(bouton)
	bouton.add_theme_font_size_override("font_size", fpx(20))
	bouton.set_meta("contextual_enabled", true)
	return bouton

## Touche de clavier dessinée (« Espace », « Échap », « T ») : petite pilule `PANNEAU_3`, texte gris-vert.
func _touche(texte: String, agrandi: float = 1.0) -> PanelContainer:
	var cadre := PanelContainer.new()
	var style := _case(SURVOL, Charte.RAYON_PILULE)
	style.content_margin_left = px(8)
	style.content_margin_right = px(8)
	style.content_margin_top = px(1)
	style.content_margin_bottom = px(1)
	cadre.add_theme_stylebox_override("panel", style)
	cadre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var etiquette := _texte(texte, 17 * agrandi, DOUX, false, true)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(etiquette)
	return cadre

## Fin trait blanc autour des grandes tuiles de l'écran 2D (choix de Léo du 21/11/2026, il prime ici sur la règle
## « panneaux sans bordure ») : 1 px, blanc à 22 %, qui suit le rayon des coins ; jamais sur les cartes intérieures.
const LISERE := Color(1, 1, 1, 0.22)

static func liserer(style: StyleBoxFlat) -> StyleBoxFlat:
	style.border_color = LISERE
	style.set_border_width_all(1)
	return style

## Panneau de la charte : opaque, rayon 18, ombre portée de la charte, liseré fin de l'écran 2D.
func _panneau(parent: Node, marge: int, fond: Color = PANNEAU) -> VBoxContainer:
	var coque := PanelContainer.new()
	var style := liserer(_case(Color(fond, 1.0), Charte.RAYON_PANNEAU))
	coque.add_theme_stylebox_override("panel", style)
	parent.add_child(coque)
	var bord := S.G.margin(marge)
	coque.add_child(bord)
	var colonne := S.G.v(px(10))
	bord.add_child(colonne)
	return colonne

## En-tête de bloc : titre en capitales droites, précision atténuée à droite.
func _titre(texte: String, precision: String = "", principal: bool = false) -> Control:
	var ligne := S.G.h(px(10))
	var etiquette := _titre_bloc(texte, 26 if principal else 22)
	S.G.fill(etiquette)
	ligne.add_child(etiquette)
	if not precision.is_empty():
		var droite := _texte(precision, 18, DOUX)
		droite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ligne.add_child(droite)
	return ligne

func _ready() -> void:
	name = "MatchBetween"
	mouse_filter = Control.MOUSE_FILTER_PASS
	S.full(self)
	_densite = densite_pour(get_viewport_rect().size)
	_construire()
	resized.connect(_a_l_echelle)
	resized.connect(_largeur_multiplex)
	visibility_changed.connect(_apparaitre)

## Apparition en fondu (0,25 s), sauf si le joueur a demandé de réduire les animations.
func _apparaitre() -> void:
	if not visible:
		fermer_fiche()
		return
	if _animations_reduites():
		modulate.a = 1.0
		return
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _animations_reduites() -> bool:
	var noeud: Node = get_parent()
	while noeud != null:
		var preferences: Variant = noeud.get("user_preferences")
		if preferences != null and preferences.get("data") is Dictionary: return bool(preferences.data.get("reduced_motion", false))
		noeud = noeud.get_parent()
	return false

## La fenêtre a changé de taille : tout l'écran est reconstruit à la nouvelle échelle.
func _a_l_echelle() -> void:
	var densite := densite_pour(get_viewport_rect().size)
	if is_equal_approx(densite, _densite): return
	_densite = densite
	_construire()
	if not _dernier.is_empty(): update_frame.callv(_dernier)

## Une seule mise en page (choix de Léo du 19/11/2026, variante 1 « Terrain au centre ») : la barre de
## commandes, puis Mon XV à gauche (titulaires, banc), le terrain 2D au centre, les chiffres clés à droite
## (la même colonne accueille le panneau d'arrêt, les réglages, les autres matchs) ; dessous la domination
## minute par minute en largeur, Gabi, et le pied des raccourcis.
func _construire() -> void:
	# Le terrain garde sa lecture (places, file des faits) d'une échelle à l'autre.
	var ancien := terrain
	if ancien != null and ancien.get_parent() != null: ancien.get_parent().remove_child(ancien)
	if is_instance_valid(fiche_match): fermer_fiche()
	for enfant in get_children():
		remove_child(enfant)
		enfant.queue_free()
	_cle = ""
	_journee_cle = ""
	_temps_forts_cle = ""
	_evenements_cle = ""
	_bonus_cle = ""
	terrain = ancien if ancien != null else Terrain2D.new()
	terrain.densite = _densite
	terrain.legende = false
	# Pastilles à l'échelle du terrain (demande de Léo du 21/11/2026 : « ça fait pâté ») : petits ronds nets, numéros
	# écrits quand ils tiennent (masqués en dessous, infobulle au survol), ballon cerclé d'un halo.
	terrain.plancher_pastilles = 0.0
	terrain.pelouse = true
	terrain.taille_pastilles = 1.15
	terrain.remplir = true
	terrain.custom_minimum_size = Vector2(320, 180)
	if not terrain.pastille_survolee.is_connected(_survol_pastille): terrain.pastille_survolee.connect(_survol_pastille)
	if not terrain.pastille_choisie.is_connected(_choix_pastille): terrain.pastille_choisie.connect(_choix_pastille)
	_commandes()
	_composants()
	_page()
	# Conseils de Gabi en bulles dans sa carte et phrase de jeu en aplat coloré (idée FM27 n° 35).
	BullesAdjoint.poser(self)
	_arret_decision()
	montrer_droite(vue_droite)
	if not _arret.is_empty(): montrer_arret(_arret)
	if not terrain.fait_joue.is_connected(_fait_joue): terrain.fait_joue.connect(_fait_joue)

## Barre de commandes : où en est le match (mi-temps, défilement, pause), Équipe (action principale, ivoire
## plein), Réglages (vitesse de l'horloge, temps forts montrés : panneau dans la colonne de droite) et Plus
## (menu déroulant : statistiques, journal, autres matchs, délégation, caméras).
## Barre du haut agrandie d'environ 28 % (retouche de Léo du 21/11/2026), comme le bandeau du score.
const BARRE_HAUT := 1.28
## Identifiants des vitesses de l'horloge dans le menu « Plus ».
const ID_VITESSE := 200

func _commandes() -> void:
	phase = _texte("", 22 * BARRE_HAUT, DOUX)
	phase.name = "MatchBetweenPhase"
	phase.clip_text = true
	phase.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	phase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	S.G.fill(phase)
	etat = _texte("", 22, IVOIRE)
	etat.name = "MatchBetweenState"
	etat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etat.clip_text = true
	etat.custom_minimum_size.x = px(120)
	S.G.fill(etat)
	# Pas de bouton « Passer » ni de compte à rebours (choix de Léo) : le match défile en 2D à la vitesse
	# de l'horloge choisie dans les réglages.
	equipe = _bouton("ÉQUIPE", func(): tiroir_demande.emit("Équipe"), true, true)
	equipe.name = "MatchBetweenTeam"
	_equipe_pleine = true
	equipe.tooltip_text = "Composition, banc, cris de la touche et consignes (le match se met en pause) · T"
	equipe.set_meta("contextual_enabled", true)
	equipe.add_theme_font_override("font", TITRES_EXTRA)
	equipe.add_theme_font_size_override("font_size", fpx(24 * BARRE_HAUT))
	equipe.custom_minimum_size.y = maxi(26, px(46 * BARRE_HAUT))
	plus = MenuButton.new()
	plus.name = "MatchBetweenMore"
	plus.text = "Plus ▾"
	plus.flat = true
	plus.tooltip_text = "Statistiques complètes, journal du match, autres matchs et classement en direct, confier la fin à l’adjoint, caméras."
	plus.focus_mode = Control.FOCUS_ALL
	plus.set_meta("contextual_enabled", true)
	C.style_bouton_lien(plus)
	plus.add_theme_font_size_override("font_size", fpx(22 * BARRE_HAUT))
	var menu := plus.get_popup()
	menu.add_theme_font_size_override("font_size", fpx(22))
	_habiller_menu(menu)
	for libelle: String in ["Statistiques", "Journal du match", "Confier la fin à l’adjoint", "Autres matchs et classement en direct"]: menu.add_item(libelle)
	# Caméras du direct 3D (la barre du bas est masquée en temps forts).
	menu.add_separator("Caméra des temps forts")
	for paire: Array in [["Vue TV", "tv"], ["Vue de dessus", "tactical"], ["Vue contact", "action"]]:
		menu.add_item(str(paire[0]))
		menu.set_item_metadata(menu.item_count - 1, paire[1])
	# Vitesse de l'horloge entre deux temps forts : seulement ici (retouche de Léo du 21/11/2026), la courante cochée.
	menu.add_separator("Vitesse de l’horloge")
	for n in HORLOGES_IDS.size(): menu.add_radio_check_item(HORLOGES_COURTS[n], ID_VITESSE + n)
	# Caméras : la caméra courante cochée ; pendant l'entracte 2D, elles n'ont pas d'effet visible : grisées et
	# dites « en 3D seulement » (la raison est écrite, jamais un choix muet).
	var cameras := {"tv": "Vue TV", "tactical": "Vue de dessus", "action": "Vue contact"}
	menu.about_to_popup.connect(func():
		var en_2d := is_visible_in_tree()
		# Autres matchs : panneau de l'entracte ; pendant un temps fort 3D, grisé et dit (jamais un choix muet).
		menu.set_item_disabled(3, journee_vue == null or not en_2d)
		menu.set_item_text(3, "Autres matchs et classement en direct" + (" · aucun autre match" if journee_vue == null else ("" if en_2d else " · à l’entracte")))
		for n in HORLOGES_IDS.size(): menu.set_item_checked(menu.get_item_index(ID_VITESSE + n), HORLOGES_IDS[n] == horloge)
		var actuelle := camera_actuelle()
		for k in menu.item_count:
			var cle: Variant = menu.get_item_metadata(k)
			if not cle is String or not cameras.has(cle): continue
			menu.set_item_as_radio_checkable(k, true)
			menu.set_item_checked(k, cle == actuelle)
			menu.set_item_disabled(k, en_2d)
			menu.set_item_text(k, str(cameras[cle]) + (" · en 3D seulement" if en_2d else "")))
	menu.id_pressed.connect(func(id: int):
		if id >= ID_VITESSE and id < ID_VITESSE + HORLOGES_IDS.size():
			horloge = HORLOGES_IDS[id - ID_VITESSE]
			horloge_choisie.emit(horloge)
			_poser_phase(_dernier[1] if _dernier.size() > 1 and _dernier[1] is Dictionary else {})
			return
		if id == 0: tiroir_demande.emit("Stats")
		elif id == 1: tiroir_demande.emit("Journal")
		elif id == 2:
			if is_visible_in_tree(): montrer_droite("delegation")
			else: confier_fin_demande.emit()
		elif id == 3: montrer_droite("journee")
		else:
			var index := menu.get_item_index(id)
			if index >= 0 and menu.get_item_metadata(index) is String: camera_demandee.emit(str(menu.get_item_metadata(index))))
	# Réglages : vitesse de l'horloge et temps forts montrés, dans la colonne de droite (jamais une fenêtre).
	parametres = _lien("Réglages", func(): _ouvrir_parametres(), "MatchBetweenSettings")
	parametres.tooltip_text = "Temps forts montrés."
	parametres.add_theme_font_size_override("font_size", fpx(22 * BARRE_HAUT))
	# Pendant un temps fort 3D (entracte caché), les mêmes réglages en menu déroulant sous le lien (exception de Léo).
	menu_reglages = PopupMenu.new()
	menu_reglages.name = "MatchBetweenSettingsMenu"
	menu_reglages.add_theme_font_size_override("font_size", fpx(22))
	_habiller_menu(menu_reglages)
	menu_reglages.id_pressed.connect(_choix_menu_reglages)
	parametres.add_child(menu_reglages)

## Menu déroulant à la charte : carte `PANNEAU` opaque rayon 12, sans ombre ni cadre ; survol en case
## `PANNEAU_3` rayon 6 ; texte crème (grisé pour un choix indisponible).
func _habiller_menu(menu: PopupMenu) -> void:
	# Ardoise claire (teinte D) des petites fenêtres du direct (Léo, 23/11) ; survol en case plus claire.
	menu.add_theme_stylebox_override("panel", MenuJoueur.style_ardoise(px(8), false))
	menu.add_theme_stylebox_override("hover", _case(MenuJoueur.PAL.case))
	var filet := StyleBoxLine.new()
	filet.color = MenuJoueur.PAL.filet
	filet.thickness = 1
	for cle in ["separator", "labeled_separator_left", "labeled_separator_right"]: menu.add_theme_stylebox_override(cle, filet)
	for cle in ["font_color", "font_hover_color", "font_accelerator_color"]: menu.add_theme_color_override(cle, IVOIRE)
	menu.add_theme_color_override("font_disabled_color", MenuJoueur.PAL.encre3)
	menu.add_theme_color_override("font_separator_color", MenuJoueur.PAL.encre2)
	menu.add_theme_constant_override("v_separation", px(10))
	menu.transparent_bg = true

## Réglages en menu déroulant (temps fort 3D) : vitesse de l'horloge (0 à 3) et temps forts montrés (100 et plus),
## le choix courant coché.
func _remplir_menu_reglages() -> void:
	menu_reglages.clear()
	# La vitesse de l'horloge se règle seulement dans « Plus » (retouche de Léo du 21/11/2026).
	if _niveaux.is_empty(): return
	menu_reglages.add_separator("Temps forts montrés")
	var choisi := niveau_libelle()
	for n in _niveaux.size():
		var libelle := str(_niveaux[n].get("label", ""))
		menu_reglages.add_radio_check_item(libelle, 100 + n)
		menu_reglages.set_item_checked(menu_reglages.get_item_index(100 + n), libelle == choisi)

func _choix_menu_reglages(id: int) -> void:
	if id >= 0 and id < HORLOGES_IDS.size():
		var bouton := find_child("MatchBetweenSpeed%d" % id, true, false) as Button
		if bouton != null: bouton.button_pressed = true
		horloge = HORLOGES_IDS[id]
		horloge_choisie.emit(horloge)
		_poser_pied()
	elif id >= 100 and id - 100 < _niveaux.size():
		var niveau := str(_niveaux[id - 100].get("id", ""))
		_remplir_niveaux(niveau)
		niveau_choisi.emit(niveau)

## Choix unique (segment) : filet épais et coche quand il est choisi, filet fin sinon.
func _segment(texte: String, groupe: ButtonGroup, choisi: bool) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.toggle_mode = true
	bouton.button_group = groupe
	bouton.button_pressed = choisi
	bouton.custom_minimum_size.x = px(130)
	bouton.set_meta("contextual_enabled", true)
	_style_segment(bouton)
	_cocher(bouton, choisi)
	bouton.toggled.connect(func(actif: bool): _cocher(bouton, actif))
	return bouton
## Caméra du direct 3D retenue dans les préférences du joueur (« tv », « tactical », « action »), vide sinon.
func camera_actuelle() -> String:
	var app: Object = _app()
	var preferences: Variant = app.get("user_preferences") if app != null else null
	if preferences is Object and preferences.has_method("effective_camera"): return str(preferences.effective_camera())
	return ""

func _ouvrir_parametres() -> void:
	if not is_visible_in_tree() and is_instance_valid(menu_reglages):
		_remplir_menu_reglages()
		var ancre := parametres.get_global_rect()
		menu_reglages.popup(Rect2i(Vector2i(ancre.position + Vector2(0, ancre.size.y)), Vector2i.ZERO))
		return
	montrer_droite("chiffres" if vue_droite == "reglages" else "reglages")

func _remplir_niveaux(choisi: String = "") -> void:
	if not is_instance_valid(grille_niveaux): return
	S.clear(grille_niveaux)
	groupe_niveaux = ButtonGroup.new()
	for n in _niveaux.size():
		var id := str(_niveaux[n].get("id", ""))
		var choix := _segment(str(_niveaux[n].get("label", "")), groupe_niveaux, id == choisi)
		choix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choix.pressed.connect(func(): niveau_choisi.emit(id))
		grille_niveaux.add_child(choix)

func _libelle_niveau(id: Variant) -> String:
	for item: Dictionary in _niveaux:
		if item.get("id") == id: return str(item.get("label", ""))
	return ""

## Niveau tenu par la régie (préférence du joueur, reprise comprise) : coché dans Réglages.
var niveau_regie := ""
func montrer_niveau(id: String) -> void:
	niveau_regie = id
	if not _niveaux.is_empty() and niveau_libelle() != _libelle_niveau(id): _remplir_niveaux(id)

## Libellé du niveau de temps forts choisi dans les réglages (vide s'il n'y en a pas).
func niveau_libelle() -> String:
	if groupe_niveaux == null: return ""
	var choisi := groupe_niveaux.get_pressed_button()
	return choisi.text if choisi != null else ""

## Composants : frise de domination, chiffres clés, fil, Mon XV, banc, carte de Gabi.
func _composants() -> void:
	domination = Domination.new()
	domination.name = "MatchBetweenMomentum"
	domination.densite = _densite
	domination.custom_minimum_size = Vector2(0, px(170))
	domination.tooltip_text = "Qui domine, minute par minute (occupation, possession, points, franchissements) : chaque club à sa couleur, nous au-dessus de l’axe ; essais (E), pénalités (P) et cartons (C) à leur minute."
	domination.mouse_filter = Control.MOUSE_FILTER_STOP
	domination.repere_choisi.connect(func(i: int): journal_demande.emit(i))
	S.G.fill(domination, true)
	chiffres = S.G.v(px(6))
	chiffres.name = "MatchBetweenFigures"
	fil = S.G.v(px(4))
	fil.name = "MatchBetweenFeed"
	xv = GridContainer.new()
	xv.name = "MatchBetweenSquad"
	xv.columns = 1
	xv.add_theme_constant_override("v_separation", 0)
	S.G.fill(xv)
	banc = GridContainer.new()
	banc.columns = 2
	banc.add_theme_constant_override("h_separation", px(12))
	banc.add_theme_constant_override("v_separation", 0)
	banc.name = "MatchBetweenBenchList"
	adjoint = S.G.v(px(10))
	adjoint.name = "MatchBetweenAdvice"

## Carte de Gabi (portrait, une phrase, l'action proposée) en largeur, sous la domination.
func _carte_gabi(parent: Control) -> void:
	var cadre := _panneau(parent, px(14))
	adjoint_cadre = cadre.get_parent().get_parent()
	adjoint_cadre.name = "MatchBetweenAdviceCard"
	cadre.add_child(adjoint)

## Colonnes de Mon XV (unités 2560) : numéro, joueur, énergie (jauge et valeur), plaquages, note.
const COLONNES_XV := [["N°", 44], ["Joueur", 0], ["Énergie", 170], ["Plaq.", 64], ["Note", 64]]
## Clé de tri de chaque colonne de Mon XV (même ordre que COLONNES_XV).
const TRIS_XV := ["numero", "joueur", "energie", "plaquages", "note"]
## Poste en deux signes, comme sur une feuille de match.
const POSTES_COURTS := {"pilier gauche": "PG", "talonneur": "TA", "pilier droit": "PD", "deuxième ligne": "2L", "troisième ligne": "3L",
	"numéro 8": "N8", "demi de mêlée": "DM", "demi d’ouverture": "DO", "demi d'ouverture": "DO", "ailier": "AI", "centre": "CE", "arrière": "AR"}

static func poste_court(poste: String) -> String:
	var cle := poste.strip_edges().to_lower()
	if cle.begins_with("numéro"): return "N8" if cle.ends_with("8") else "3L"
	for nom: String in POSTES_COURTS:
		if cle.begins_with(nom): return POSTES_COURTS[nom]
	return poste.substr(0, 3).to_upper()

func _cellule(texte: String, largeur: int, couleur: Color, taille: float = 19, chiffre: bool = false) -> Label:
	var etiquette := _texte(texte, taille, couleur, false, false)
	if chiffre: etiquette.add_theme_font_override("font", CHIFFRES_GRAS)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiquette.clip_text = true
	etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etiquette.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if largeur > 0:
		etiquette.custom_minimum_size.x = px(largeur)
		etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if chiffre else HORIZONTAL_ALIGNMENT_LEFT
	else: S.G.fill(etiquette)
	return etiquette

## Mise en page (maquette 14-match-entracte-1, choix de Léo du 19/11/2026).
func _page() -> void:
	var page := _boite(false, GOUTTIERE)
	page.name = "MatchBetweenPage"
	S.full(page)
	# Marge basse : le pied des raccourcis ne touche jamais le bord de l'écran.
	page.offset_bottom = -px(8)
	# Le même vide visible au-dessus de la page que entre ses blocs (sous la ligne du vent).
	page.offset_top = px(GOUTTIERE - 12)
	add_child(page)
	var barre: Control
	if is_instance_valid(hote_barre):
		S.clear(hote_barre)
		barre = hote_barre
	else:
		barre = S.G.h(px(12))
		(barre as HBoxContainer).alignment = BoxContainer.ALIGNMENT_END
		page.add_child(barre)
	var noeuds_barre: Array[Control] = [phase, equipe, _touche("T", BARRE_HAUT), parametres, plus]
	lien_consignes = _lien("Consignes", func(): consignes_demandees.emit(), "MatchBetweenConsignes")
	lien_consignes.add_theme_font_size_override("font_size", fpx(22 * BARRE_HAUT))
	noeuds_barre.insert(3, lien_consignes)
	for noeud: Control in noeuds_barre: barre.add_child(noeud)
	# Bouton « Banc » (idée FM27 n° 34, menu déroulant comme dans FM) : cris d'équipe, à un joueur, ajustements, ailes.
	load("res://ui/contextual/match_banc_fm.gd").poser(self, barre, page)
	_page_d3(page)

## Pied : les raccourcis de l'écran et où trouver ce qui n'y est pas (vitesse, autres matchs).
func _pied(page: Control) -> void:
	pied = S.G.h(px(10))
	pied.name = "MatchBetweenKeys"
	page.add_child(pied)
	# Raccourcis derrière un « ? » (règle du 21/11/2026 : plus de mode d'emploi à l'écran).
	var aide := PanelContainer.new()
	aide.name = "MatchBetweenKeysHelp"
	aide.tooltip_text = "Espace : reprendre ou mettre en pause · Échap : pause et menu · T : équipe · ↑ ↓ : choisir un joueur · Entrée : remplacer"
	aide.accessibility_name = aide.tooltip_text
	aide.mouse_filter = Control.MOUSE_FILTER_STOP
	aide.mouse_default_cursor_shape = Control.CURSOR_HELP
	aide.custom_minimum_size = Vector2(px(28), px(28))
	aide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fond := StyleBoxFlat.new()
	fond.bg_color = Charte.PANNEAU_3
	fond.set_corner_radius_all(Charte.RAYON_PILULE)
	aide.add_theme_stylebox_override("panel", fond)
	var signe := _texte("?", maxi(12, px(15)), DOUX)
	signe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	signe.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	signe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aide.add_child(signe)
	pied.add_child(aide)
	pied_reglages = _texte("", 18, DOUX)
	pied_reglages.name = "MatchBetweenKeysSettings"
	pied_reglages.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pied_reglages.clip_text = true
	pied_reglages.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pied_reglages.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	S.G.fill(pied_reglages)
	pied.add_child(pied_reglages)

## Colonne gauche : Mon XV (numéro, nom, énergie, plaquages, note), puis le banc ; un lien bascule sur le XV
## adverse. Une ligne choisie (clic, ↑ ↓ puis Entrée) ouvre la fenêtre Équipe sur ce joueur ; le nom ouvre sa
## fiche, son survol la mini-fiche.
func _colonne_xv(grille: Control) -> void:
	var cadre_xv := _panneau(grille, px(18))
	tuile_principale = cadre_xv.get_parent().get_parent()
	tuile_principale.name = "MatchBetweenMain"
	# Assez large pour que le nom le plus long du banc (« Matthew BOOTHROYD ») se lise en entier, banc sur deux colonnes.
	tuile_principale.custom_minimum_size.x = px(780)
	# Séparation serrée (1 px à 1080p) : les quinze lignes et le pied « Équipe » tiennent sans défilement.
	cadre_xv.add_theme_constant_override("separation", px(1))
	var tete := S.G.h(px(10))
	cadre_xv.add_child(tete)
	titre_xv = _titre_bloc("Mon XV", 26)
	titre_xv.name = "MatchBetweenSquadTitle"
	S.G.fill(titre_xv)
	tete.add_child(titre_xv)
	lien_adverse = _lien("XV adverse →", func(): choisir_vue_xv("tableau" if vue_xv == "adverse" else "adverse"), "MatchBetweenTabOpponent")
	lien_adverse.tooltip_text = "Voir le XV adverse (notes, énergie, plaquages) ; revenir à Mon XV."
	tete.add_child(lien_adverse)
	var entete := S.G.h(px(6))
	entete.name = "MatchBetweenSquadHeader"
	# En-têtes triables (comme les tableaux de Football Manager) : un clic trie, un second retourne le sens.
	entetes_tri.clear()
	for k in COLONNES_XV.size():
		var colonne: Array = COLONNES_XV[k]
		var libelle := str(colonne[0]).to_upper()
		var cle: String = TRIS_XV[k]
		var tete_col := Button.new()
		tete_col.name = "MatchBetweenSort_" + cle
		tete_col.flat = false
		tete_col.focus_mode = Control.FOCUS_ALL
		tete_col.set_meta("tri", cle)
		tete_col.set_meta("libelle", libelle)
		tete_col.set_meta("contextual_enabled", true)
		tete_col.text = libelle
		# Jamais rogné (« LAQ. ») : la colonne s'élargit de la flèche s'il le faut.
		tete_col.clip_text = false
		tete_col.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tete_col.tooltip_text = "Trier Mon XV par %s (un second clic retourne le sens)." % str(colonne[0]).to_lower() if cle != "numero" else "Revenir à l’ordre des postes (un second clic retourne le sens)."
		# Tri en pastilles (les tuiles n'ont pas de colonnes) : la pastille du tri courant sur la sélection de la charte.
		for etat_bouton in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			var pilule := StyleBoxFlat.new()
			pilule.bg_color = SURVOL if etat_bouton in ["hover", "hover_pressed"] else RELIEF
			pilule.set_corner_radius_all(Charte.RAYON_PILULE)
			pilule.anti_aliasing = true
			pilule.content_margin_left = px(14)
			pilule.content_margin_right = px(14)
			pilule.content_margin_top = px(3)
			pilule.content_margin_bottom = px(3)
			if etat_bouton == "focus": _anneau(pilule)
			tete_col.add_theme_stylebox_override(etat_bouton, pilule)
		tete_col.add_theme_font_override("font", TITRES)
		for couleur in ["font_color", "font_focus_color"]: tete_col.add_theme_color_override(couleur, DOUX)
		for couleur in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]: tete_col.add_theme_color_override(couleur, IVOIRE)
		tete_col.add_theme_color_override("font_disabled_color", FAIBLE)
		tete_col.add_theme_font_size_override("font_size", fpx(16))
		tete_col.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tete_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tete_col.pressed.connect(trier_xv.bind(cle))
		entetes_tri.append(tete_col)
		entete.add_child(tete_col)
	_poser_entete_tri()
	var defile := ScrollContainer.new()
	defile.name = "MatchBetweenSquadScroll"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# D : les tuiles des joueurs tiennent toutes (jamais d'ascenseur).
	defile.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.mouse_filter = Control.MOUSE_FILTER_PASS
	S.G.fill(defile, true)
	tableau_xv = S.G.v(0)
	tableau_xv.name = "MatchBetweenTable"
	S.G.fill(tableau_xv)
	cadre_xv.add_child(entete)
	cadre_xv.add_child(defile)
	defile_xv = defile
	defile.add_child(tableau_xv)
	tableau_xv.add_child(xv)
	# Total de l'équipe : pied fixe sous la zone de défilement (jamais coupé), aligné sur les colonnes des lignes.
	pied_xv = S.G.v(0)
	pied_xv.name = "MatchBetweenSquadFoot"
	cadre_xv.add_child(pied_xv)
	defile.resized.connect(_aligner_pied_xv)
	defile.get_v_scroll_bar().visibility_changed.connect(_aligner_pied_xv)
	# Banc : zone fixe sous les titulaires, toujours visible (le remplacement est l'action de l'entracte) ; deux
	# colonnes de numéro, nom et poste ; le nombre de changements restants en tête.
	zone_banc = S.G.v(px(2))
	zone_banc.name = "MatchBetweenBenchZone"
	cadre_xv.add_child(zone_banc)
	var filet := ColorRect.new()
	filet.color = TRAIT
	filet.custom_minimum_size.y = 1
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_banc.add_child(filet)
	var tete_banc := S.G.h(px(10))
	tete_banc.name = "MatchBetweenBenchHeader"
	var titre_banc := _titre_bloc("Banc", 22)
	S.G.fill(titre_banc)
	tete_banc.add_child(titre_banc)
	precision_banc = _texte("", 18, DOUX)
	precision_banc.name = "MatchBetweenBenchCount"
	tete_banc.add_child(precision_banc)
	zone_banc.add_child(tete_banc)
	zone_banc.add_child(banc)
	_montrer_vue_xv()
## Colonne centrale : le terrain 2D (où est le ballon, qui attaque), le dernier fait joué en une ligne.
func _colonne_centre(grille: Control) -> void:
	var cadre_terrain := _panneau(grille, px(14))
	var tuile: Control = cadre_terrain.get_parent().get_parent()
	tuile.name = "MatchBetweenPitchTile"
	S.G.fill(tuile, true, 1.0)
	cadre_terrain.add_theme_constant_override("separation", px(6))
	var tete := S.G.h(px(14))
	tete.name = "MatchBetweenPitchHeader"
	cadre_terrain.add_child(tete)
	var titre_terrain := _titre_bloc("Terrain", 24)
	titre_terrain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(titre_terrain)
	# L'état du jeu en entier (jamais « … ») : il prend la largeur et sa taille baisse s'il le faut.
	tete.add_child(etat)
	S.G.fill(etat)
	etat.clip_text = true
	etat.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	etat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	etat.set_meta("taille_base", etat.get_theme_font_size("font_size"))
	etat.resized.connect(_ajuster_taille.bind(etat))
	# Le sens du jeu est dessiné sur le terrain (flèche sous le ballon) : écrit en infobulle de l'état.
	sens_jeu = _texte("", 18, DOUX)
	sens_jeu.name = "MatchBetweenAttack"
	sens_jeu.visible = false
	tete.add_child(sens_jeu)
	# Le dernier fait joué, en une ligne sous l'en-tête (le journal complet est dans Plus).
	bandeau = PanelContainer.new()
	bandeau.name = "MatchBetweenBanner"
	bandeau.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(bandeau)
	cadre_terrain.add_child(bandeau)
	bandeau.add_child(fil)
	S.G.fill(fil)
	var scene := Control.new()
	scene.name = "MatchBetweenScene"
	scene.clip_contents = true
	scene.custom_minimum_size = Vector2(px(560), px(300))
	S.G.fill(scene, true)
	cadre_terrain.add_child(scene)
	S.full(terrain)
	scene.add_child(terrain)
	meteo_pastille = PastilleMeteo.new()
	meteo_pastille.name = "MatchBetweenWeather2D"
	meteo_pastille.visible = false
	scene.add_child(meteo_pastille)
	# Terrain, puis le momentum et les temps forts en pastilles dessous.
	# Hauteur du terrain tenue (vérificateur du 24/11 : 63 % de sa tuile en 2560, pastilles de 3,4 px en 1920) : en 1920 il
	# faut ≈ 208 px pour des pastilles de 4 px et un terrain qui remplit 80 % de sa tuile.
	scene.custom_minimum_size = Vector2(px(420), maxi(150, px(277)))
	cadre_terrain.add_child(_bande_momentum())
	temps_forts = S.G.h(px(8))
	temps_forts.name = "MatchBetweenHighlights"
	temps_forts.custom_minimum_size.y = px(36)
	cadre_terrain.add_child(temps_forts)

## Colonne droite : un seul panneau à la fois, à la même place (jamais une fenêtre) — chiffres clés par
## défaut, réglages, autres matchs et classement, confirmation de la délégation, et le panneau d'arrêt.
func _colonne_droite(grille: Control) -> void:
	colonne_droite = _boite(false, GOUTTIERE)
	colonne_droite.name = "MatchBetweenColumn"
	colonne_droite.custom_minimum_size.x = px(540)
	grille.add_child(colonne_droite)
	# Chiffres clés : duel face à face, lien vers les statistiques, météo, bonus.
	var cadre_chiffres := _panneau(colonne_droite, px(18))
	panneau_chiffres = cadre_chiffres.get_parent().get_parent()
	panneau_chiffres.name = "MatchBetweenDuel"
	S.G.fill(panneau_chiffres, true)
	var tete_chiffres := S.G.h(px(10))
	cadre_chiffres.add_child(tete_chiffres)
	var titre_chiffres := _titre_bloc("Chiffres clés", 24)
	S.G.fill(titre_chiffres)
	tete_chiffres.add_child(titre_chiffres)
	# Seul accès aux statistiques détaillées : fixe, à droite du titre, jamais sous le pli.
	var stats := _lien("Voir les statistiques →", func(): tiroir_demande.emit("Stats"), "MatchBetweenStatsLink")
	tete_chiffres.add_child(stats)
	# Le contenu défile s'il dépasse (1280×720 avec la tuile Bonus en fin de match) : la page tient toujours.
	var defile_chiffres := ScrollContainer.new()
	defile_chiffres.name = "MatchBetweenFiguresScroll"
	defile_chiffres.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile_chiffres.mouse_filter = Control.MOUSE_FILTER_PASS
	S.G.fill(defile_chiffres, true)
	cadre_chiffres.add_child(defile_chiffres)
	var marge_defile := MarginContainer.new()
	# Marge à droite : la barre de défilement ne rogne jamais les valeurs de l'adversaire.
	marge_defile.add_theme_constant_override("margin_right", px(18))
	S.G.fill(marge_defile)
	defile_chiffres.add_child(marge_defile)
	var contenu := S.G.v(px(10))
	contenu.name = "MatchBetweenFiguresContent"
	S.G.fill(contenu, true)
	marge_defile.add_child(contenu)
	cadre_chiffres = contenu
	legende_chiffres = S.G.h(px(8))
	legende_chiffres.name = "MatchBetweenFiguresLegend"
	cadre_chiffres.add_child(legende_chiffres)
	precision_chiffres = _texte("", 17, DOUX)
	precision_chiffres.name = "MatchBetweenFiguresSample"
	precision_chiffres.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cadre_chiffres.add_child(precision_chiffres)
	cadre_chiffres.add_child(chiffres)
	# Les lignes se répartissent la hauteur du panneau (aucun vide sous le bonus).
	S.G.fill(chiffres, true)
	# (lien des statistiques : fixe, dans l'en-tête du panneau)
	# Météo : déjà sous le score (bandeau de la vue du match) ; ici seulement en infobulle du lien des statistiques.
	meteo_ligne = _texte("", 17, DOUX, true)
	meteo_ligne.name = "MatchBetweenWeather"
	meteo_ligne.visible = false
	cadre_chiffres.add_child(meteo_ligne)
	stats_lien = stats
	# Bonus : la règle du championnat et, en fin de match, le dilemme et ses deux consignes.
	bonus_tuile = PanelContainer.new()
	bonus_tuile.name = "MatchBetweenBonus"
	var style_bonus := _case(RELIEF, Charte.RAYON_CARTE)
	style_bonus.set_content_margin_all(px(12))
	bonus_tuile.add_theme_stylebox_override("panel", style_bonus)
	cadre_chiffres.add_child(bonus_tuile)
	var cadre_bonus := S.G.v(px(6))
	bonus_tuile.add_child(cadre_bonus)
	var tete_bonus := _titre("Bonus")
	bonus_regle = _texte("", 17, DOUX, true)
	bonus_regle.name = "MatchBetweenBonusRule"
	cadre_bonus.add_child(tete_bonus)
	cadre_bonus.add_child(bonus_regle)
	bonus_etat = S.G.h(px(16))
	bonus_etat.name = "MatchBetweenBonusState"
	cadre_bonus.add_child(bonus_etat)
	bonus_situation = _texte("", 20, IVOIRE, true)
	bonus_situation.name = "MatchBetweenBonusDilemma"
	bonus_situation.max_lines_visible = 3
	bonus_situation.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bonus_situation.mouse_filter = Control.MOUSE_FILTER_PASS
	cadre_bonus.add_child(bonus_situation)
	bonus_choix = S.G.v(px(8))
	bonus_choix.name = "MatchBetweenBonusChoices"
	cadre_bonus.add_child(bonus_choix)
	bonus_tuile.visible = false
	# Réglages : vitesse de l'horloge et temps forts montrés (avant : petite fenêtre de l'engrenage).
	var cadre_reglages := _panneau(colonne_droite, px(18))
	panneau_parametres = cadre_reglages.get_parent().get_parent()
	panneau_parametres.name = "MatchBetweenSettingsPanel"
	S.G.fill(panneau_parametres, true)
	cadre_reglages.add_theme_constant_override("separation", px(12))
	cadre_reglages.add_child(_retour_droite("Réglages du match"))
	groupe_horloge = ButtonGroup.new()
	cadre_reglages.add_child(_texte("Temps forts montrés (gardé pour les prochains matchs)", 18, DOUX, true))
	grille_niveaux = GridContainer.new()
	grille_niveaux.name = "MatchHighlightLevel"
	grille_niveaux.columns = 2
	grille_niveaux.add_theme_constant_override("h_separation", px(8))
	grille_niveaux.add_theme_constant_override("v_separation", px(8))
	cadre_reglages.add_child(grille_niveaux)
	_remplir_niveaux(niveau_regie)
	# Autres matchs de la journée et classement « si ça finit ainsi » (menu Plus).
	var cadre_journee := _panneau(colonne_droite, px(18))
	panneau_journee = cadre_journee.get_parent().get_parent()
	panneau_journee.name = "MatchBetweenDayPanel"
	S.G.fill(panneau_journee, true)
	cadre_journee.add_child(_retour_droite("Autres matchs"))
	classement_tuile = PanelContainer.new()
	classement_tuile.name = "MatchBetweenLiveTable"
	classement_tuile.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	cadre_journee.add_child(classement_tuile)
	var cadre_classement := S.G.v(px(4))
	classement_tuile.add_child(cadre_classement)
	cadre_classement.add_child(_titre("Classement en direct", "si ça finit ainsi"))
	classement_lignes = S.G.v(px(3))
	classement_lignes.name = "MatchBetweenLiveTableRows"
	cadre_classement.add_child(classement_lignes)
	classement_tuile.visible = false
	multiplex = PanelContainer.new()
	multiplex.name = "MatchBetweenMultiplex"
	multiplex.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	cadre_journee.add_child(multiplex)
	var colonne_multiplex := S.G.v(px(6))
	multiplex.add_child(colonne_multiplex)
	var tete_multiplex := S.G.h(px(10))
	colonne_multiplex.add_child(tete_multiplex)
	var titre_multiplex := _titre_bloc("Multiplex", 22)
	S.G.fill(titre_multiplex)
	tete_multiplex.add_child(titre_multiplex)
	multiplex_precision = _texte("", 18, DOUX)
	multiplex_precision.name = "MatchBetweenMultiplexMinute"
	tete_multiplex.add_child(multiplex_precision)
	multiplex_cartes = GridContainer.new()
	multiplex_cartes.name = "MatchBetweenMultiplexCards"
	multiplex_cartes.add_theme_constant_override("h_separation", px(14))
	multiplex_cartes.add_theme_constant_override("v_separation", px(10))
	multiplex_defile = ScrollContainer.new()
	multiplex_defile.name = "MatchBetweenMultiplexScroll"
	multiplex_defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	multiplex_defile.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	multiplex_defile.mouse_filter = Control.MOUSE_FILTER_PASS
	multiplex_defile.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	multiplex_defile.tooltip_text = "Les autres matchs de la journée : molette ou glisser pour voir la suite."
	S.G.fill(multiplex_defile)
	# Le défilement et son indicateur de suite « › » (sans dégradé : charte §3).
	var pile_multiplex := MarginContainer.new()
	pile_multiplex.name = "MatchBetweenMultiplexStack"
	for cote in ["left", "right", "top", "bottom"]: pile_multiplex.add_theme_constant_override("margin_" + cote, 0)
	pile_multiplex.mouse_filter = Control.MOUSE_FILTER_PASS
	S.G.fill(pile_multiplex)
	colonne_multiplex.add_child(pile_multiplex)
	pile_multiplex.add_child(multiplex_defile)
	multiplex_defile.add_child(multiplex_cartes)
	multiplex_fondu = PanelContainer.new()
	multiplex_fondu.name = "MatchBetweenMultiplexFade"
	# Fondu de la couleur du panneau (invisible sur lui) : masque le bord droit des cartes qui défilent.
	var style_fondu := StyleBoxFlat.new()
	style_fondu.bg_color = PANNEAU
	multiplex_fondu.add_theme_stylebox_override("panel", style_fondu)
	multiplex_fondu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	multiplex_fondu.custom_minimum_size.x = px(40)
	multiplex_fondu.size_flags_horizontal = Control.SIZE_SHRINK_END
	multiplex_fondu.size_flags_vertical = Control.SIZE_FILL
	var suite := _texte("›", 34, IVOIRE, false, true)
	suite.name = "MatchBetweenMultiplexMore"
	suite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	suite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	suite.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	multiplex_fondu.add_child(suite)
	multiplex_fondu.visible = false
	pile_multiplex.add_child(multiplex_fondu)
	multiplex_defile.resized.connect(_fondu_multiplex)
	multiplex_cartes.resized.connect(_fondu_multiplex)
	multiplex_defile.get_h_scroll_bar().value_changed.connect(func(_v: float): _fondu_multiplex())
	multiplex.visible = false
	journee_vide = _texte("Aucun autre match de la journée en cours.", 18, DOUX, true)
	journee_vide.name = "MatchBetweenDayEmpty"
	cadre_journee.add_child(journee_vide)
	# Confier la fin à l'adjoint : confirmation en place (avant : petite fenêtre de confirmation).
	var cadre_delegation := _panneau(colonne_droite, px(18))
	panneau_delegation = cadre_delegation.get_parent().get_parent()
	panneau_delegation.name = "MatchBetweenHandOver"
	S.G.fill(panneau_delegation, true)
	cadre_delegation.add_theme_constant_override("separation", px(14))
	cadre_delegation.add_child(_retour_droite("Confier la fin du match"))
	cadre_delegation.add_child(_texte("Gabi prend en charge la fin de cette rencontre : il fait ses choix (changements, consignes) et le match se termine sans toi. Le résultat compte comme si tu l’avais joué.", 19, IVOIRE, true))
	var confirmer := _bouton("Confier la fin à l’adjoint →", func():
		montrer_droite("chiffres")
		delegation_demandee.emit())
	confirmer.name = "MatchBetweenHandOverConfirm"
	confirmer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	confirmer.set_meta("contextual_enabled", true)
	cadre_delegation.add_child(confirmer)

var _colonnes_multiplex := 0

static func _rang_texte(rang: int) -> String:
	return "1er" if rang == 1 else "%de" % rang

## Variantes : panneaux de la journée en direct montrés quand ils ont du contenu (A : avec les chiffres clés).
func _montrer_journee_direct() -> void:
	if panneaux_direct.is_empty(): return
	panneaux_direct[0].visible = classement_tuile.visible
	panneaux_direct[1].visible = multiplex.visible
	if panneaux_direct.size() > 2: panneaux_direct[2].visible = classement_tuile.visible
	if multiplex.visible: _largeur_multiplex.call_deferred()

# --- Variantes C et D (deuxième planche du 21/11/2026 : plus de couleur, classement complet) --------------------------

var momentum: Momentum
var temps_forts: HBoxContainer
var classement_legende: HFlowContainer
## Club de chaque identifiant (tableaux des ligues, équipes du match) et zones de la poule, pour les écussons et pastilles.
var _clubs_journee: Dictionary = {}
var _zones_journee: Array = []

## D3 : la liste des événements du match, le cadre du banc.
var evenements: VBoxContainer
var banc_cadre: Control

## « Bord de terrain » (D3, choix de Léo du 21/11/2026) devenu « tableau de bord » (option A de la revue FM27, choix de
## Léo du 22/11/2026). Plein écran obligatoire : chaque clic ouvre une petite fenêtre par-dessus le match.
## À gauche Gabi, les 3 derniers événements du match, le bonus et le banc ; au centre le terrain entre les deux
## compositions notées (petits terrains), la domination sous le terrain, la phrase de jeu en grand, puis les chiffres
## en barres miroir et la courbe cumulée points / entrées dans les 22 m ; à droite le classement complet et le
## multiplex ; en bas, la barre de Mon XV (visage, énergie, note, plaquages, moral en direct).
func _page_d3(page: Control) -> void:
	compos_fm.clear()
	_compos_cle = ""
	_barres_cle = ""
	var grille := _boite(true, GOUTTIERE)
	grille.name = "MatchBetweenTiles"
	S.G.fill(grille, true, 1.0)
	page.add_child(grille)
	var gauche := _boite(false, GOUTTIERE)
	gauche.name = "MatchBetweenEventsColumn"
	gauche.custom_minimum_size.x = px(540)
	grille.add_child(gauche)
	_carte_gabi(gauche)
	_colonne_droite(gauche)
	# Le panneau des événements se réduit à son contenu (rien de vide en début de match) : le banc prend la place.
	colonne_droite.size_flags_vertical = Control.SIZE_FILL
	colonne_droite.custom_minimum_size.x = 0
	# Le panneau des chiffres clés devient celui des événements (les chiffres passent en miroir autour du terrain).
	for etiquette: Node in panneau_chiffres.find_children("*", "Label", true, false):
		if (etiquette as Label).text == "CHIFFRES CLÉS":
			(etiquette as Label).text = "ÉVÉNEMENTS DU MATCH"
			break
	legende_chiffres.visible = false
	chiffres.visible = false
	evenements = S.G.v(px(6))
	evenements.name = "MatchBetweenEvents"
	S.G.fill(evenements)
	chiffres.get_parent().add_child(evenements)
	chiffres.get_parent().move_child(evenements, chiffres.get_index() + 1)
	# L'enjeu au classement, en carte, sous les événements (rempli par le classement en direct).
	# L'enjeu et le bonus : chacun sa tuile (panneau de la charte) sous celle des événements.
	enjeu_pastille = PanelContainer.new()
	enjeu_pastille.name = "MatchBetweenLiveStake"
	var style_enjeu := liserer(_case(PANNEAU, Charte.RAYON_PANNEAU))
	style_enjeu.set_content_margin_all(px(16))
	enjeu_pastille.add_theme_stylebox_override("panel", style_enjeu)
	enjeu_pastille.visible = false
	enjeu_pastille.mouse_filter = Control.MOUSE_FILTER_PASS
	gauche.add_child(enjeu_pastille)
	bonus_tuile.get_parent().remove_child(bonus_tuile)
	var style_bonus_tuile := liserer(_case(PANNEAU, Charte.RAYON_PANNEAU))
	style_bonus_tuile.set_content_margin_all(px(16))
	bonus_tuile.add_theme_stylebox_override("panel", style_bonus_tuile)
	gauche.add_child(bonus_tuile)
	# Le contenu du panneau ne s'étire plus (sinon le vide revient sous le bonus).
	(chiffres.get_parent() as Control).size_flags_vertical = Control.SIZE_FILL
	panneau_chiffres.size_flags_vertical = Control.SIZE_FILL
	var defile_ev := panneau_chiffres.find_child("MatchBetweenFiguresScroll", true, false) as ScrollContainer
	if defile_ev != null:
		defile_ev.size_flags_vertical = Control.SIZE_FILL
		# Les événements cèdent leur hauteur quand Gabi grandit (bulles) : ils défilent, le banc garde ses 8 lignes
		# (vérificateur du 24/11 : la tuile Banc était écrasée). Hauteur tenue par _tenir_gauche.
		defile_ev.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		_defile_ev = defile_ev
	_colonne_gauche = gauche
	_page_fm = page
	if not page.resized.is_connected(_tenir_gauche): page.resized.connect(_tenir_gauche)
	var centre := _boite(false, GOUTTIERE)
	centre.name = "MatchBetweenCentre"
	S.G.fill(centre, true, 1.0)
	grille.add_child(centre)
	var rangee := _boite(true, GOUTTIERE)
	rangee.name = "MatchBetweenPitchRow"
	S.G.fill(rangee, true, 1.0)
	centre.add_child(rangee)
	for cote in 2:
		if cote == 1: _colonne_centre(rangee)
		_poser_compo_fm(rangee, cote)
	_poser_phrase_fm(centre)
	# Les temps forts en pastilles sont déjà dans les événements et la phrase de jeu : la ligne laisse la place.
	temps_forts.visible = false
	var rang_bas := _boite(true, GOUTTIERE)
	rang_bas.name = "MatchBetweenDashboardRow"
	# Le terrain d'abord (vérificateur du 24/11) : la rangée du bas garde sa hauteur utile, le reste va au terrain.
	S.G.fill(rang_bas, true, 0.3)
	centre.add_child(rang_bas)
	_poser_bas_fm(rang_bas)
	# La domination prend la place du momentum, sous le terrain (sigles en légende, frise basse).
	var barre_m := find_child("MatchBetweenMomentumBar", true, false) as Control
	var cadre_t: Control = barre_m.get_parent()
	barre_m.visible = false
	titre_domination = _titre("Domination", "1re mi-temps")
	titre_domination.name = "MatchBetweenMomentumTile"
	cadre_t.add_child(titre_domination)
	domination.legende_etroite = true
	domination.custom_minimum_size.y = px(120)
	cadre_t.add_child(domination)
	S.G.fill(domination, true, 0.45)
	var droite := _boite(false, GOUTTIERE)
	droite.name = "MatchBetweenStandingsColumn"
	droite.custom_minimum_size.x = px(560)
	grille.add_child(droite)
	_poser_journee_v2(droite, droite, 2)
	panneaux_direct[1].size_flags_vertical = Control.SIZE_FILL
	# Barre basse : Mon XV, une carte par joueur ; le tri, le total de l'équipe et le XV adverse dans son en-tête.
	var barre_xv := _boite(true, GOUTTIERE)
	barre_xv.name = "MatchBetweenSquadBar"
	page.add_child(barre_xv)
	_colonne_xv(barre_xv)
	S.G.fill(tuile_principale)
	tuile_principale.custom_minimum_size.x = 0
	var tete := titre_xv.get_parent()
	var entete := tuile_principale.find_child("MatchBetweenSquadHeader", true, false) as Control
	entete.get_parent().remove_child(entete)
	tete.add_child(entete)
	tete.move_child(entete, 1)
	titre_xv.size_flags_horizontal = Control.SIZE_FILL
	var vide := Control.new()
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(vide)
	tete.add_child(vide)
	tete.move_child(vide, 2)
	pied_xv.get_parent().remove_child(pied_xv)
	tete.add_child(pied_xv)
	tete.move_child(pied_xv, 3)
	pied_xv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Le banc quitte Mon XV pour son cadre, sous les événements.
	var cadre_banc := _panneau(gauche, px(16))
	banc_cadre = cadre_banc.get_parent().get_parent()
	banc_cadre.name = "MatchBetweenBenchTile"
	S.G.fill(banc_cadre, true)
	S.G.fill(cadre_banc, true)
	S.G.fill(zone_banc, true)
	S.G.fill(banc, true)
	zone_banc.get_parent().remove_child(zone_banc)
	# Le banc cède sa hauteur quand la colonne de gauche se remplit (2e mi-temps, bonus en fin de match) : il défile
	# au lieu de pousser la barre de Mon XV hors de l'écran.
	var defile_banc := ScrollContainer.new()
	_defile_banc = defile_banc
	defile_banc.name = "MatchBetweenBenchScroll"
	defile_banc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile_banc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	S.G.fill(defile_banc, true)
	cadre_banc.add_child(defile_banc)
	defile_banc.add_child(zone_banc)
	(zone_banc.get_child(0) as Control).visible = false
	banc.columns = 1
	# Le pied (« ? » des raccourcis, vitesse) rejoint l'en-tête de Mon XV : l'écran garde toute sa hauteur.
	_pied(page)
	page.remove_child(pied)
	tete.add_child(pied)
	pied.size_flags_horizontal = Control.SIZE_SHRINK_END
	pied_reglages.size_flags_horizontal = Control.SIZE_SHRINK_END
	pied_reglages.clip_text = false
	pied_reglages.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

var _defile_ev: ScrollContainer
var _defile_banc: ScrollContainer
var _colonne_gauche: Control
var _page_fm: Control

## Colonne de gauche (Gabi, événements, enjeu, bonus, banc) : le banc garde toujours la hauteur de ses 8 lignes ; quand
## la colonne n'a plus la place (bulles de Gabi, bonus de fin de match), les événements cèdent leur hauteur et défilent.
func _tenir_gauche() -> void:
	if not is_instance_valid(_colonne_gauche) or not is_instance_valid(_page_fm) or not is_instance_valid(_defile_ev): return
	if is_instance_valid(_defile_banc) and is_instance_valid(zone_banc):
		var h_banc := ceilf(zone_banc.get_combined_minimum_size().y)
		if not is_equal_approx(_defile_banc.custom_minimum_size.y, h_banc): _defile_banc.custom_minimum_size.y = h_banc
	if _defile_ev.get_child_count() == 0 or _page_fm.size.y <= 0.0: return
	var h_contenu := (_defile_ev.get_child(0) as Control).get_combined_minimum_size().y
	var grille := _colonne_gauche.get_parent() as Control
	var ecart := float(_page_fm.get_theme_constant("separation"))
	var autres := 0.0
	var rangs := 0
	for e: Node in _page_fm.get_children():
		var c := e as Control
		if c == null or not c.visible or c.top_level: continue
		rangs += 1
		if c != grille: autres += c.get_combined_minimum_size().y
	var dispo_grille := _page_fm.size.y - autres - ecart * maxf(0.0, rangs - 1)
	var sans_ev := _colonne_gauche.get_combined_minimum_size().y - _defile_ev.get_combined_minimum_size().y
	var hauteur := floorf(clampf(h_contenu, 0.0, maxf(0.0, dispo_grille - sans_ev)))
	if not is_equal_approx(_defile_ev.custom_minimum_size.y, hauteur): _defile_ev.custom_minimum_size.y = hauteur

## D3 : les événements du match montrés (essais, pénalités, drops, cartons de `direct.reperes`), chaque camp de son côté
## autour de la minute : pictogramme cerclé à la couleur du club, auteur, score ; un clic ouvre le journal à ce fait.
var _evenements_cle := ""
func _remplir_evenements(reperes: Array, equipes: Array) -> void:
	if not is_instance_valid(evenements): return
	var cle := JSON.stringify([reperes, terrain.couleurs])
	if cle == _evenements_cle: return
	_evenements_cle = cle
	S.clear(evenements)
	var haut := domination._haut()
	var teintes := _teintes_duel()
	var tete := S.G.h(px(8))
	evenements.add_child(tete)
	for k in 2:
		var cote := haut if k == 0 else 1 - haut
		var club: Dictionary = equipes[cote] if cote < equipes.size() and equipes[cote] is Dictionary else {}
		var sigle := _texte(S.G.club_abbr(club) if not club.is_empty() else "", 24, IVOIRE, false, true)
		sigle.add_theme_font_override("font", Charte.TITRE_FICHE)
		sigle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if k == 0 else HORIZONTAL_ALIGNMENT_LEFT
		S.G.fill(sigle)
		if k == 1:
			var milieu := _texte("", 20, DOUX)
			milieu.custom_minimum_size.x = px(70)
			tete.add_child(milieu)
		tete.add_child(sigle)
	var trait_ligne := ColorRect.new()
	trait_ligne.color = TRAIT
	trait_ligne.custom_minimum_size.y = 1
	evenements.add_child(trait_ligne)
	if reperes.is_empty():
		var vide := _texte("—", 24, FAIBLE, false, true)
		vide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		evenements.add_child(vide)
		return
	for repere: Variant in reperes.slice(maxi(0, reperes.size() - 3)):
		if not repere is Dictionary: continue
		var cote := clampi(int(repere.get("equipe", 0)), 0, 1)
		var a_gauche := cote == haut
		var ligne := PanelContainer.new()
		ligne.name = "MatchBetweenEvent%d" % int(repere.get("i", -1))
		ligne.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		ligne.custom_minimum_size.y = px(38)
		var rangee := S.G.h(px(8))
		rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(rangee)
		var kind := str(repere.get("kind", ""))
		var mot := "Essai" if kind == "try" else ("Carton" if kind == "card" else "Pénalité")
		var qui := str(repere.get("nom", "")).strip_edges()
		var marque: Variant = repere.get("score") if repere.get("score") is Array else domination.scores.get(int(repere.get("i", -1)))
		var score := ("%d-%d" % [int(marque[haut]), int(marque[1 - haut])]) if kind != "card" and marque is Array and (marque as Array).size() == 2 else ""
		var cote_bloc := S.G.h(px(8))
		cote_bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cote_bloc.alignment = BoxContainer.ALIGNMENT_END if a_gauche else BoxContainer.ALIGNMENT_BEGIN
		S.G.fill(cote_bloc)
		var icone := Icone.new()
		icone.kind = "try" if kind == "try" else ("card" if kind == "card" else "goal")
		icone.rouge = bool(repere.get("rouge", false))
		icone.teinte = teintes[0 if a_gauche else 1]
		icone.custom_minimum_size = Vector2(px(30), px(30))
		icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nom := _texte(qui if not qui.is_empty() else mot, 21, IVOIRE, false, true)
		nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var points := _texte(score, 19, DOUX, false, true)
		points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		points.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for piece: Control in ([points, nom, icone] if a_gauche else [icone, nom, points]): cote_bloc.add_child(piece)
		var minute := _texte(str(repere.get("horloge", "")), 21, IVOIRE, false, true)
		minute.add_theme_font_override("font", TITRES_EXTRA)
		minute.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		minute.custom_minimum_size.x = px(70)
		minute.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		minute.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var autre := Control.new()
		autre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		S.G.fill(autre)
		for piece: Control in ([cote_bloc, minute, autre] if a_gauche else [autre, minute, cote_bloc]): rangee.add_child(piece)
		ligne.tooltip_text = "%s · %s · %s" % [mot, str(repere.get("horloge", "")), _nom_club(equipes, cote)] + ("\n" + qui if not qui.is_empty() else "")
		var i := int(repere.get("i", -1))
		if i >= 0:
			ligne.mouse_filter = Control.MOUSE_FILTER_STOP
			ligne.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			ligne.gui_input.connect(func(e: InputEvent):
				var clic := e as InputEventMouseButton
				if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
					ligne.accept_event()
					journal_demande.emit(i))
		evenements.add_child(ligne)

## D3 : carte haute d'un joueur (barre basse de Mon XV) : visage et numéro, nom, énergie (jauge et valeur ou alerte),
## note du match en pastille et plaquages.
func _remplir_carte_haute(case: Button, poste: int, joueur: Dictionary, info: Dictionary) -> Control:
	var condition := float(info.energie)
	var alerte := str(info.alerte)
	var grave := alerte in ["épuisé", "blessé"]
	var colonne := S.G.v(px(3))
	colonne.name = "MatchBetweenCardBody"
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	S.full(colonne)
	colonne.offset_left = px(8)
	colonne.offset_right = -px(8)
	colonne.offset_top = px(6)
	colonne.offset_bottom = -px(6)
	case.add_child(colonne)
	var haut := S.G.h(0)
	haut.alignment = BoxContainer.ALIGNMENT_CENTER
	haut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(haut)
	# Anneau d'énergie autour du visage (couleur de la jauge : vert en forme, orange, rouge).
	haut.add_child(_visage(joueur, px(56), _numero(str(info.id), poste + 1), condition))
	var nom := _nom_joueur(abreger_prenom(str(joueur.get("name", ""))), str(info.id), "", {})
	nom.set_meta("nom_carte", str(joueur.get("name", "")) + "|" + str(info.id))
	nom.custom_minimum_size.y = px(28)
	# Prénom en initiale sur la carte ; le nom complet reste celui du joueur (infobulle, fenêtre, tests).
	for lien_nom: Node in nom.find_children("MatchBetweenPlayerName_*", "Button", true, false): lien_nom.set_meta("nom_complet", str(joueur.get("name", "")))
	colonne.add_child(nom)
	var energie := S.G.h(px(6))
	energie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energie.custom_minimum_size.y = px(22)
	colonne.add_child(energie)
	if not alerte.is_empty():
		var mot := _texte(alerte.get_slice(",", 0), 17, Charte.PERTE if grave or alerte.begins_with("carton") or alerte == "exclu" else Charte.INTENSIF, false, true)
		mot.name = "MatchBetweenPlayerAlert"
		mot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		S.G.fill(mot)
		energie.add_child(mot)
	else:
		var jauge := Jauge.new()
		jauge.valeur = condition
		jauge.vive = true
		jauge.densite = _densite
		jauge.custom_minimum_size = Vector2(px(40), px(16))
		jauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		S.G.fill(jauge)
		energie.add_child(jauge)
	var valeur := _texte(("! " if condition < EPUISE else "") + "%d %%" % roundi(condition), 18, Jauge.teinte_vive(condition), false, true)
	valeur.add_theme_font_override("font", TITRES_EXTRA)
	valeur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	valeur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energie.add_child(valeur)
	var bas := S.G.h(px(6))
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(bas)
	var mot_plaq := _texte("PLAQ.", 17, DOUX, false, true)
	mot_plaq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mot_plaq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bas.add_child(mot_plaq)
	var plaq := _texte(str(int(info.get("plaquages", 0))), 18, IVOIRE, false, true)
	plaq.add_theme_font_override("font", TITRES_EXTRA)
	plaq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plaq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(plaq)
	bas.add_child(plaq)
	bas.add_child(_pastille_note(float(info.note)))
	# Moral du joueur en direct (moteur : départ = réaction à la causerie, puis les faits du match) : pastille + mot,
	# flèche quand il bouge nettement depuis 5 minutes.
	var moral := moral_joueur(_pilotage, str(info.id))
	var ligne_moral := S.G.h(px(5))
	ligne_moral.name = "MatchBetweenPlayerMorale"
	ligne_moral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne_moral.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_child(ligne_moral)
	var teinte_moral := teinte_moral(str(moral.get("cle", "")))
	var rond := PanelContainer.new()
	rond.add_theme_stylebox_override("panel", _case(teinte_moral, Charte.RAYON_PILULE))
	rond.custom_minimum_size = Vector2(px(12), px(12))
	rond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne_moral.add_child(rond)
	var tendance := int(moral.get("tendance", 0))
	var mot_moral := _texte(str(moral.get("label", "")) + (" ▲" if tendance > 0 else (" ▼" if tendance < 0 else "")), 16, teinte_moral, false, true)
	mot_moral.name = "MatchBetweenPlayerMoraleWord"
	mot_moral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne_moral.add_child(mot_moral)
	ligne_moral.visible = not moral.is_empty()
	case.custom_minimum_size = Vector2(px(130), px(172))
	return colonne

## Panneaux de la journée en direct : le classement complet dans `parent_classement` (en D1 avec l'enjeu dans son
## en-tête), le multiplex (`colonnes` bandeaux par rangée) dans `parent_multiplex`.
func _poser_journee_v2(parent_classement: Control, parent_multiplex: Control, colonnes: int) -> void:
	panneaux_direct.clear()
	_colonnes_multiplex = colonnes
	var cadre_c := _panneau(parent_classement, px(16))
	var panneau_c: Control = cadre_c.get_parent().get_parent()
	panneau_c.name = "MatchBetweenLiveDay0"
	S.G.fill(panneau_c, true, 1.0)
	panneaux_direct.append(panneau_c)
	classement_tuile.get_parent().remove_child(classement_tuile)
	cadre_c.add_child(classement_tuile)
	S.G.fill(classement_tuile, true)
	var cadre_classement := classement_tuile.get_child(0) as Control
	S.G.fill(cadre_classement, true)
	S.G.fill(classement_lignes, true)
	classement_legende = HFlowContainer.new()
	classement_legende.name = "MatchBetweenLiveTableZones"
	classement_legende.add_theme_constant_override("h_separation", px(8))
	classement_legende.add_theme_constant_override("v_separation", px(6))
	cadre_classement.add_child(classement_legende)
	var cadre_m := _panneau(parent_multiplex, px(16))
	var panneau_m: Control = cadre_m.get_parent().get_parent()
	panneau_m.name = "MatchBetweenLiveDay1"
	panneaux_direct.append(panneau_m)
	multiplex.get_parent().remove_child(multiplex)
	cadre_m.add_child(multiplex)
	S.G.fill(multiplex, true)
	S.G.fill(multiplex_cartes)
	for panneau: Control in panneaux_direct: panneau.visible = false

## D1 : notre rang officiel → notre rang si le score en restait là, pastille aux couleurs du gain ou de la perte.
func _poser_enjeu(classement: Array) -> void:
	if not is_instance_valid(enjeu_pastille): return
	var nous: Dictionary = {}
	for r: Variant in classement:
		if r is Dictionary and bool(r.get("nous", false)): nous = r
	# Planche A/B : « si ça finit ainsi » reste dans l'en-tête du classement (notre ligne y est marquée) ; la tuile laisse la place.
	enjeu_pastille.visible = false
	if nous.is_empty(): return
	var rang := int(nous.get("rang", 0))
	var officiel: int = int(nous.rangOfficiel) if nous.get("rangOfficiel") != null else rang
	var teinte: Color = Charte.GAIN if rang < officiel else (Charte.PERTE if rang > officiel else IVOIRE)
	S.clear(enjeu_pastille)
	var rangee := S.G.h(px(10))
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enjeu_pastille.add_child(rangee)
	var titre := _texte("SI ÇA FINIT AINSI", 18, DOUX, false, true)
	titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(titre)
	rangee.add_child(titre)
	var fleche := Fleche.new()
	fleche.delta = officiel - rang
	fleche.custom_minimum_size = Vector2(px(30), px(30))
	fleche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(fleche)
	fleche.visible = officiel != rang
	var texte := _texte("%s → %s" % [_rang_texte(officiel), _rang_texte(rang)] if officiel != rang else _rang_texte(rang), 34, teinte, false, true)
	texte.add_theme_font_override("font", Charte.TITRE_FICHE)
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_child(texte)
	var points := _texte("%d pts" % int(nous.get("points", 0)), 24, IVOIRE, false, true)
	points.add_theme_font_override("font", TITRES_EXTRA)
	points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	points.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_child(points)
	enjeu_pastille.tooltip_text = "Classement si le score en restait là : %s, %d pts" % [_rang_texte(rang), int(nous.get("points", 0))]
	# Clic : la petite fenêtre de notre club (rang, points, forme).
	if nous.get("clubId") != null and not enjeu_pastille.has_meta("club_id"): _cliquable_club(enjeu_pastille, nous.get("clubId"), _fond_survol())

## Teintes des deux clubs du match lisibles sur un panneau : [nous, eux] ; deux couleurs trop proches : l'adversaire
## passe au gris-vert (la forme pleine / vide distingue toujours les camps).
func _teintes_duel() -> Array[Color]:
	var nous := terrain.camp if terrain != null and terrain.camp in [0, 1] else 0
	var couleurs: Array = [Charte.V, Charte.D]
	if terrain != null and terrain.couleurs.size() == 2: couleurs = [terrain.couleurs[0], terrain.couleurs[1]]
	var a := Charte.club_trait(couleurs[nous])
	var b := Charte.club_trait(couleurs[1 - nous])
	if Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.25: b = Charte.IVOIRE_2
	return [a, b]

## Encre lisible sur un aplat de club.
static func encre_sur(fond: Color) -> Color:
	return Charte.ENCRE if fond.get_luminance() > 0.55 else Charte.IVOIRE

## Momentum sous le terrain : titre, barre animée, durée lue (5′).
func _bande_momentum() -> Control:
	var rangee := S.G.h(px(12))
	rangee.name = "MatchBetweenMomentumBar"
	var titre := _titre_bloc("Momentum", 18)
	titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(titre)
	momentum = Momentum.new()
	momentum.name = "MatchBetweenMomentumGauge"
	momentum.densite = _densite
	momentum.reduit = _animations_reduites()
	momentum.custom_minimum_size = Vector2(px(200), px(30))
	momentum.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	momentum.tooltip_text = "Qui pousse sur les cinq dernières minutes (domination du moteur)."
	S.G.fill(momentum)
	rangee.add_child(momentum)
	var duree := _texte("5′", 18, DOUX, false, true)
	duree.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(duree)
	return rangee

func _poser_momentum(minutes: Array, equipes: Array, haut: int) -> void:
	if not is_instance_valid(momentum): return
	momentum.teintes = _teintes_duel()
	momentum.sigles = [S.G.club_abbr(equipes[haut]) if equipes.size() == 2 and equipes[haut] is Dictionary else "", S.G.club_abbr(equipes[1 - haut]) if equipes.size() == 2 and equipes[1 - haut] is Dictionary else ""]
	var recent := minutes.slice(maxi(0, minutes.size() - 5))
	var somme := 0.0
	for v: Variant in recent: somme += float(v)
	var moyenne := somme / maxf(1.0, recent.size())
	if haut == 1: moyenne = -moyenne
	momentum.viser(0.5 + clampf(moyenne, -100.0, 100.0) / 200.0)

## D : les temps forts déjà montrés (essais, pénalités, drops, cartons de `direct.reperes`) en pastilles aux couleurs
## du club, les plus récents ; un clic ouvre le journal du match à ce fait.
var _temps_forts_cle := ""
func _poser_temps_forts(reperes: Array, equipes: Array) -> void:
	if not is_instance_valid(temps_forts): return
	var cle := JSON.stringify([reperes, terrain.couleurs])
	if cle == _temps_forts_cle: return
	_temps_forts_cle = cle
	S.clear(temps_forts)
	var titre := _titre_bloc("Temps forts", 18)
	titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	temps_forts.add_child(titre)
	if reperes.is_empty():
		var vide := _texte("—", 20, FAIBLE, false, true)
		vide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		temps_forts.add_child(vide)
		return
	for repere: Variant in reperes.slice(maxi(0, reperes.size() - 4)):
		if not repere is Dictionary: continue
		var cote := clampi(int(repere.get("equipe", 0)), 0, 1)
		var fond: Color = terrain.couleurs[cote] if terrain.couleurs.size() == 2 else RELIEF
		var encre := encre_sur(fond)
		var pastille := PanelContainer.new()
		pastille.name = "MatchBetweenHighlight%d" % int(repere.get("i", -1))
		var style := _case(fond, Charte.RAYON_PILULE)
		style.content_margin_left = px(6)
		style.content_margin_right = px(12)
		style.content_margin_top = px(2)
		style.content_margin_bottom = px(2)
		pastille.add_theme_stylebox_override("panel", style)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var rangee := S.G.h(px(6))
		rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille.add_child(rangee)
		var kind := str(repere.get("kind", ""))
		var icone := Icone.new()
		icone.kind = "try" if kind == "try" else ("card" if kind == "card" else "goal")
		icone.rouge = bool(repere.get("rouge", false))
		icone.teinte = encre
		icone.custom_minimum_size = Vector2(px(26), px(26))
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rangee.add_child(icone)
		var mot := "Essai" if kind == "try" else ("Carton" if kind == "card" else "Pén.")
		var qui := str(repere.get("nom", "")).strip_edges()
		var texte := _texte("%s %s" % [str(repere.get("horloge", "")), qui if not qui.is_empty() else mot], 18, encre, false, true)
		texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texte.clip_text = true
		texte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var largeur_texte := texte.get_theme_font("font").get_string_size(texte.text, HORIZONTAL_ALIGNMENT_LEFT, -1, texte.get_theme_font_size("font_size")).x
		texte.custom_minimum_size.x = minf(px(170), ceilf(largeur_texte) + 2.0)
		texte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rangee.add_child(texte)
		pastille.tooltip_text = "%s · %s · %s" % [mot, str(repere.get("horloge", "")), _nom_club(equipes, cote)] + ("\n" + qui if not qui.is_empty() else "")
		var i := int(repere.get("i", -1))
		if i >= 0:
			pastille.mouse_filter = Control.MOUSE_FILTER_STOP
			pastille.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			pastille.gui_input.connect(func(e: InputEvent):
				var clic := e as InputEventMouseButton
				if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
					pastille.accept_event()
					journal_demande.emit(i))
		temps_forts.add_child(pastille)

## Clubs connus (pour les écussons) et zones de la poule du classement en direct.
func _clubs_et_zones(model: Dictionary, equipes: Array, classement: Array) -> void:
	_clubs_journee = {}
	var ids := {}
	for r: Variant in classement:
		if r is Dictionary: ids[_cle_club(r.get("clubId"))] = true
	_zones_journee = []
	for division: Variant in model.get("leagues", []):
		if not division is Dictionary: continue
		var dedans := 0
		for club: Variant in division.get("rows", []):
			if club is Dictionary and club.get("id") != null:
				_clubs_journee[_cle_club(club.id)] = club
				if ids.has(_cle_club(club.id)): dedans += 1
		if _zones_journee.is_empty() and dedans > 0 and dedans == ids.size() and division.get("zones") is Array: _zones_journee = division.zones
	for club: Variant in equipes + [model.get("club")]:
		if club is Dictionary and club.get("id") != null and not _clubs_journee.has(_cle_club(club.id)): _clubs_journee[_cle_club(club.id)] = club

func _zone_rang(rang: int) -> Dictionary:
	for z: Variant in _zones_journee:
		if z is Dictionary and rang >= int(z.get("from", 0)) and rang <= int(z.get("to", -1)): return z
	return {}

## Écusson du club (logo d'un pack, sinon l'écusson dessiné à ses couleurs), dans une case de `largeur` px.
func _ecusson(club: Dictionary, largeur: int) -> Control:
	var logo: Texture2D = S.G.Base._pack_texture(str(S.G.identity(club).get("logoPath", club.get("logoPath", ""))))
	if logo != null:
		var image := TextureRect.new()
		image.texture = logo
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2.ONE * largeur
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return image
	var case := Control.new()
	case.custom_minimum_size = Vector2.ONE * largeur
	case.mouse_filter = Control.MOUSE_FILTER_IGNORE
	case.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var taille := roundi(largeur * 1.5)
	var dessin: Control = load("res://ui/tenue_club.gd").ecusson(club, taille) if not club.is_empty() else null
	if dessin == null:
		var pastille := Pastille.new()
		pastille.teinte = FAIBLE
		pastille.custom_minimum_size = Vector2.ONE * largeur
		S.full(pastille)
		case.add_child(pastille)
		return case
	dessin.custom_minimum_size = Vector2.ONE * taille
	dessin.size = Vector2.ONE * taille
	dessin.position = Vector2.ONE * float(largeur - taille) / 2.0
	case.add_child(dessin)
	# Initiales de l'écusson dessiné : masquées (le nom est écrit à côté), jamais sous le plancher de 12 px.
	for initiales in dessin.find_children("*", "Label", true, false):
		(initiales as Label).visible = false
		(initiales as Label).add_theme_font_size_override("font_size", maxi(12, (initiales as Label).get_theme_font_size("font_size")))
	return case

## Ligne du classement complet (C et D) : symbole de zone, rang, mouvement ▲▼ chiffré, écusson, sigle et nom, forme
## (C) ou différence (D), bonus de la journée, points. Notre ligne sur un aplat à la couleur du club, liseré épais.
func _ligne_classement_v2(r: Dictionary, teintes: Dictionary) -> Control:
	var nous := bool(r.get("nous", false))
	var rang_n := int(r.get("rang", 0))
	var zone := _zone_rang(rang_n)
	var kind := str(zone.get("kind", ""))
	var club_cle := _cle_club(r.get("clubId"))
	var club: Dictionary = _clubs_journee.get(club_cle, {})
	var teinte: Color = teintes.get(club_cle, FAIBLE)
	var ligne := PanelContainer.new()
	ligne.name = "MatchBetweenLiveRow%d" % rang_n
	ligne.set_meta("rang", rang_n)
	ligne.set_meta("nous", nous)
	ligne.set_meta("zone", kind)
	var fond := StyleBoxFlat.new()
	fond.anti_aliasing = true
	fond.set_corner_radius_all(Charte.RAYON_PETIT)
	fond.content_margin_left = px(8)
	fond.content_margin_right = px(10)
	if nous:
		fond.bg_color = teinte.lerp(PANNEAU, 0.35)
		fond.border_width_left = maxi(3, px(8))
		fond.border_color = Charte.club_trait(teinte)
	else:
		fond.bg_color = Color(0, 0, 0, 0)
		if not kind.is_empty():
			fond.border_width_left = maxi(2, px(5))
			fond.border_color = _teinte_zone(kind)
	ligne.add_theme_stylebox_override("panel", fond)
	ligne.custom_minimum_size.y = px(26)
	ligne.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	var encre := encre_sur(fond.bg_color) if nous else IVOIRE
	var delta := int(r.get("delta", 0))
	var nom := str(r.get("nom", ""))
	ligne.tooltip_text = "%d. %s · %d pts · %d joués · %d-%d-%d · différence %+d%s%s" % [rang_n, nom if not nom.is_empty() else str(r.get("abbr", "")), int(r.get("points", 0)), int(r.get("joues", 0)), int(r.get("gagnes", 0)), int(r.get("nuls", 0)), int(r.get("perdus", 0)), int(r.get("diff", 0)),
		("" if r.get("rangOfficiel") == null else " · %s au classement officiel" % _rang_texte(int(r.rangOfficiel))), ("\n" + str(zone.get("label", ""))) if not zone.is_empty() else ""]
	var rangee := S.G.h(px(8))
	rangee.add_theme_constant_override("separation", px(10))
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(rangee)
	var marque := MarqueZone.new()
	marque.name = "Zone"
	marque.kind = kind
	marque.teinte = _teinte_zone(kind) if not nous else encre
	marque.custom_minimum_size = Vector2(px(16), px(16))
	marque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(marque)
	var numero := _cellule(str(rang_n), 34, encre, 23, true)
	numero.name = "Rang"
	numero.add_theme_font_override("font", TITRES_EXTRA)
	rangee.add_child(numero)
	# Mouvement en direct : flèche (forme) et nombre de places, vert si on monte, rouge si on descend.
	var mouvement := S.G.h(px(2))
	mouvement.name = "Mouvement"
	mouvement.custom_minimum_size.x = px(48)
	mouvement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fleche := Fleche.new()
	fleche.name = "Evolution"
	fleche.delta = delta
	fleche.custom_minimum_size = Vector2(px(22), px(22))
	fleche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fleche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouvement.add_child(fleche)
	if delta != 0:
		var places := _texte(str(absi(delta)), 22, Charte.GAIN if delta > 0 else Charte.PERTE, false, true)
		places.add_theme_font_override("font", TITRES_EXTRA)
		places.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		places.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouvement.add_child(places)
	rangee.add_child(mouvement)
	var ecusson := _ecusson(club, px(26))
	ecusson.name = "Ecusson"
	rangee.add_child(ecusson)
	# Le nom du club en entier (jamais « … ») : l'écusson porte l'identité, le nom prend la place du sigle et sa taille
	# baisse s'il le faut (au-delà : deux lignes).
	var nom_long := _cellule(nom if not nom.is_empty() else str(r.get("abbr", "")), 0, encre, 21)
	nom_long.name = "Nom"
	nom_long.add_theme_font_override("font", TITRES)
	nom_long.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	nom_long.set_meta("taille_base", nom_long.get_theme_font_size("font_size"))
	nom_long.set_meta("sigle", str(r.get("abbr", "")))
	nom_long.resized.connect(_ajuster_taille.bind(nom_long))
	rangee.add_child(nom_long)
	var diff := int(r.get("diff", 0))
	var ecart := _cellule("%+d" % diff, 52, encre if nous else (Charte.GAIN if diff > 0 else (Charte.PERTE if diff < 0 else DOUX)), 19, true)
	ecart.name = "Diff"
	rangee.add_child(ecart)
	for badge: Array in [["bonusOff", "BO", "bonus offensif"], ["bonusDef", "BD", "bonus défensif"]]:
		var nombre := int(r.get(badge[0], 0)) if r.get(badge[0]) != null else 0
		if nombre <= 0: continue
		var pastille_bonus := PanelContainer.new()
		pastille_bonus.name = "Badge" + str(badge[1])
		var style_b := _case(Charte.GAIN if badge[1] == "BO" else Charte.MORAL)
		style_b.content_margin_left = px(6)
		style_b.content_margin_right = px(6)
		style_b.content_margin_top = 0
		style_b.content_margin_bottom = 0
		pastille_bonus.add_theme_stylebox_override("panel", style_b)
		pastille_bonus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pastille_bonus.tooltip_text = "%d %s%s" % [nombre, badge[2], "s" if nombre > 1 else ""]
		pastille_bonus.mouse_filter = Control.MOUSE_FILTER_PASS
		var texte_b := _texte(str(badge[1]), 16, Charte.ENCRE, false, true)
		texte_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille_bonus.add_child(texte_b)
		rangee.add_child(pastille_bonus)
	var points := _cellule(str(int(r.get("points", 0))), 46, encre, 24, true)
	points.name = "Points"
	points.add_theme_font_override("font", TITRES_EXTRA)
	rangee.add_child(points)
	# Rayure une ligne sur deux et survol de ligne communs (ui/survol_ligne.gd, comme l'Effectif) ; la bande de zone à
	# gauche reste visible (le liseré du club commence après elle), notre ligne garde son aplat.
	var fond_ligne = SurvolLigne.poser(ligne, false, Color.TRANSPARENT, float(Charte.RAYON_PETIT), float(fond.border_width_left))
	fond_ligne.rang_fixe = rang_n - 1
	fond_ligne.sans_rayure = nous
	_cliquable_club(ligne, r.get("clubId"))
	return ligne

## Légende des zones présentes : pastille symbole, rangs et mot court (« ● 1–6 Phase finale »).
func _poser_legende_zones(classement: Array) -> void:
	if not is_instance_valid(classement_legende): return
	S.clear(classement_legende)
	for z: Variant in _zones_journee:
		if not z is Dictionary or int(z.get("from", 0)) > classement.size(): continue
		var pastille := PanelContainer.new()
		pastille.name = "MatchBetweenZone_" + str(z.get("kind", ""))
		var style := _case(RELIEF, Charte.RAYON_PILULE)
		style.content_margin_left = px(10)
		style.content_margin_right = px(12)
		style.content_margin_top = px(2)
		style.content_margin_bottom = px(2)
		pastille.add_theme_stylebox_override("panel", style)
		pastille.tooltip_text = "%s · %s" % [Zones.span_text(z), str(z.get("label", ""))]
		pastille.mouse_filter = Control.MOUSE_FILTER_PASS
		var rangee := S.G.h(px(6))
		rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille.add_child(rangee)
		var marque := MarqueZone.new()
		marque.kind = str(z.get("kind", ""))
		marque.teinte = _teinte_zone(marque.kind)
		marque.custom_minimum_size = Vector2(px(14), px(14))
		marque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rangee.add_child(marque)
		var texte := _texte("%s  %s" % [Zones.span_text(z), Zones.short_label(z)], 17, IVOIRE, false, true)
		texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rangee.add_child(texte)
		classement_legende.add_child(pastille)

## Carte du multiplex des variantes C et D : un bandeau par club à sa couleur (écusson, sigle, essais, score) ; le
## score qui vient de bouger s'allume en vert, avec ce qu'il a rapporté (« +5 »), et clignote.
func _carte_match_v2(m: Dictionary, avant: Array, teintes: Dictionary) -> Control:
	var carte := PanelContainer.new()
	carte.name = "MatchBetweenMultiplexMatch"
	carte.set_meta("id", str(m.get("id", "")))
	var style := _case(RELIEF, Charte.RAYON_CARTE)
	style.set_content_margin_all(px(6))
	carte.add_theme_stylebox_override("panel", style)
	carte.custom_minimum_size.x = px(190)
	carte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fini := bool(m.get("fini", false))
	var cotes: Array = [m.get("home", {}), m.get("away", {})]
	var change := false
	carte.tooltip_text = "%s %d – %d %s · %s" % [str(cotes[0].get("nom", "")), int(cotes[0].get("score", 0)), int(cotes[1].get("score", 0)), str(cotes[1].get("nom", "")), "terminé" if fini else "%d′" % int(m.get("minute", 0))]
	var colonne := S.G.v(px(4))
	colonne.add_theme_constant_override("separation", px(4))
	carte.add_child(colonne)
	var gains: Array = []
	for cote in 2:
		var club: Dictionary = cotes[cote] if cotes[cote] is Dictionary else {}
		var gain := int(club.get("score", 0)) - (int(avant[cote]) if avant.size() == 2 else int(club.get("score", 0)))
		gains.append(gain)
		if gain > 0: change = true
	carte.set_meta("change", change)
	# Toute la carte ouvre la petite fenêtre du match (clubs, score, essais, minute).
	carte.mouse_filter = Control.MOUSE_FILTER_STOP
	carte.focus_mode = Control.FOCUS_ALL
	carte.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rencontre := m.duplicate(true)
	carte.gui_input.connect(func(e: InputEvent):
		var clic := e as InputEventMouseButton
		var touche := e as InputEventKey
		if (clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT) or (touche != null and touche.pressed and touche.keycode in [KEY_ENTER, KEY_KP_ENTER]):
			carte.accept_event()
			match_demande.emit(rencontre))
	for cote in 2:
		var club: Dictionary = cotes[cote] if cotes[cote] is Dictionary else {}
		var cle := _cle_club(club.get("id"))
		var fond: Color = teintes.get(cle, RELIEF)
		var encre := encre_sur(fond)
		var bande := PanelContainer.new()
		bande.name = "Domicile" if cote == 0 else "Exterieur"
		var style_bande := _case(fond)
		style_bande.content_margin_left = px(6)
		style_bande.content_margin_right = px(4)
		style_bande.content_margin_top = px(2)
		style_bande.content_margin_bottom = px(2)
		bande.add_theme_stylebox_override("panel", style_bande)
		bande.mouse_filter = Control.MOUSE_FILTER_PASS
		colonne.add_child(bande)
		var rangee := S.G.h(px(6))
		rangee.add_theme_constant_override("separation", px(6))
		rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bande.add_child(rangee)
		rangee.add_child(_ecusson(_clubs_journee.get(cle, club), px(26)))
		var sigle := _cellule(str(club.get("abbr", club.get("nom", ""))), 0, encre, 24)
		sigle.name = "Club"
		sigle.add_theme_font_override("font", TITRES_EXTRA)
		rangee.add_child(sigle)
		var essais := int(club.get("essais", 0))
		if essais > 0:
			var petit := _texte("%d E" % essais, 16, encre, false, true)
			petit.name = "Essais"
			petit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			petit.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rangee.add_child(petit)
		# Match fini : « FIN » sur le premier bandeau ; score qui vient de bouger : ce qu'il a rapporté (« +5 »), écrit.
		var mot := "FIN" if fini and cote == 0 else ("+%d" % gains[cote] if gains[cote] > 0 else "")
		if not mot.is_empty():
			var pastille := PanelContainer.new()
			pastille.name = "Fin" if mot == "FIN" else "Gain"
			var style_p := _case(PANNEAU if mot == "FIN" else Charte.GAIN, Charte.RAYON_PILULE)
			style_p.content_margin_left = px(8)
			style_p.content_margin_right = px(8)
			style_p.content_margin_top = 0
			style_p.content_margin_bottom = 0
			pastille.add_theme_stylebox_override("panel", style_p)
			pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var texte_p := _texte(mot, 16, DOUX if mot == "FIN" else Charte.ENCRE, false, true)
			texte_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pastille.add_child(texte_p)
			rangee.add_child(pastille)
		var boite := PanelContainer.new()
		boite.name = "ScoreCase"
		var marque_style := _case(Charte.GAIN if gains[cote] > 0 else PANNEAU)
		marque_style.content_margin_left = px(6)
		marque_style.content_margin_right = px(6)
		marque_style.content_margin_top = 0
		marque_style.content_margin_bottom = 0
		boite.add_theme_stylebox_override("panel", marque_style)
		boite.custom_minimum_size.x = px(48)
		boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var score := _texte(str(int(club.get("score", 0))), 24, Charte.ENCRE if gains[cote] > 0 else IVOIRE, false, true)
		score.name = "Score"
		score.add_theme_font_override("font", TITRES_EXTRA)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boite.add_child(score)
		rangee.add_child(boite)
		if gains[cote] > 0:
			if not _animations_reduites():
				var clignote := boite.create_tween().set_loops(4)
				clignote.tween_property(boite, "modulate:a", 0.35, 0.3)
				clignote.tween_property(boite, "modulate:a", 1.0, 0.3)
		bande.mouse_filter = Control.MOUSE_FILTER_PASS
		bande.tooltip_text = "%s · %d" % [str(club.get("nom", club.get("abbr", ""))), int(club.get("score", 0))]
	return carte

## La zone des tuiles de Mon XV garde la hauteur de ses tuiles (elle ne défile pas) : jamais écrasée par la page.
func _tenir_xv() -> void:
	if is_instance_valid(defile_xv) and is_instance_valid(xv): defile_xv.custom_minimum_size.y = xv.get_combined_minimum_size().y

## Tuile d'un joueur de Mon XV (carte rayon 12) : son visage découpé en rond (D2 : cerclé de l'anneau de son énergie)
## avec son numéro en médaillon ; son nom ; l'énergie (jauge et valeur, ou l'alerte écrite) ; plaquages et note du match
## en pastille. La tuile ouvre l'écran Équipe sur lui, son nom sa petite fenêtre.
func _tuile_joueur(poste: int, joueur: Dictionary, info: Dictionary) -> Button:
	var case := Button.new()
	case.name = "MatchBetweenPlayer%d" % (poste + 1)
	case.flat = false
	case.focus_mode = Control.FOCUS_ALL
	case.set_meta("contextual_enabled", true)
	var id_joueur := str(info.id)
	case.pressed.connect(func(): menu_vers.call(id_joueur, case) if menu_vers.is_valid() else ouvrir_fiche(id_joueur))
	var condition := float(info.energie)
	var alerte := str(info.alerte)
	var grave := alerte in ["épuisé", "blessé"]
	var fond := _case(Charte.VOILE_DORE if grave else RELIEF, Charte.RAYON_CARTE)
	var survol := _case(SURVOL, Charte.RAYON_CARTE)
	var focus := _case(SURVOL, Charte.RAYON_CARTE)
	_anneau(focus)
	for style: StyleBox in [fond, survol, focus]: style.set_content_margin_all(0)
	case.add_theme_stylebox_override("normal", fond)
	case.add_theme_stylebox_override("hover", survol)
	case.add_theme_stylebox_override("pressed", survol)
	case.add_theme_stylebox_override("focus", focus)
	case.add_theme_stylebox_override("disabled", fond)
	case.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	S.G.fill(case)
	case.set_meta("player_id", str(info.id))
	if grave: case.set_meta("signale", true)
	case.tooltip_text = str(info.detail)
	var app_carte: Object = _app()
	if app_carte is Control: CarteSurvol.lier(app_carte, case, str(info.id), "squad", func(): return _direct_carte(str(info.id)))
	_remplir_carte_haute(case, poste, joueur, info)
	# Changement en attente du prochain arrêt de jeu (rôle, consignes, sortie) : pastille dorée discrète.
	var badge: Array = MenuJoueur.texte_badge(_live_courant(), id_joueur)
	# Carte réutilisée tant que le joueur du poste ne change pas (_maj_tuiles_xv).
	case.set_meta("tuile_xv", true)
	case.set_meta("badge", str(badge[0]))
	case.set_meta("cle_carte", JSON.stringify([joueur.get("name", ""), info, _numero(id_joueur, poste + 1), badge, moral_joueur(_pilotage, id_joueur), _densite]))
	if not str(badge[0]).is_empty(): MenuJoueur.badge_attente(case, str(badge[0]), str(badge[1]))
	return case

## Direct de la dernière image (`live`), {} avant la première.
func _live_courant() -> Dictionary:
	return _dernier[1] if _dernier.size() > 1 and _dernier[1] is Dictionary else {}

## Vrai numéro de feuille d'un joueur (1 à 23, `live.numeros`) : un remplaçant entré garde le sien (16 à 23).
func _numero(id: String, repli: int) -> int:
	return MenuJoueur.numero_feuille(_live_courant(), id, repli)

## Remplacement du prochain arrêt de jeu tout juste fait : carte sortant (rouge) / entrant (vert) sur la phrase de jeu,
## jamais sur le terrain 2D, quand le direct montré (`montre` : composition d'avant la borne) l'a rejoint.
func _montrer_changement(live: Dictionary, direct: Dictionary, montre: Array) -> void:
	var faits: Array = MenuJoueur.arrets(live).get("appliques", []) if MenuJoueur.arrets(live).get("appliques") is Array else []
	var dernier: Dictionary = {}
	for f: Variant in faits:
		if f is Dictionary and str(f.get("type", "")) == "remplacement" and bool(f.get("ok", false)): dernier = f
	if dernier.is_empty():
		_changement_amorce = true
		return
	var n := int(dernier.get("n", -1))
	if _changement_vu < 0 and not _changement_amorce and n >= 0 and int(live.get("minute", 0)) - int(dernier.get("minute", 0)) > 2:
		_changement_vu = n
		return
	if n <= _changement_vu: return
	var slot := int(dernier.get("slot", -1))
	var entre: Variant = montre[slot] if slot >= 0 and slot < montre.size() else null
	if not (entre is Dictionary and str(entre.get("id", "")) == str(dernier.get("inId", ""))): return
	_changement_vu = n
	# Sur la bande de la phrase de jeu (même cachée pendant un temps fort 3D : la carte y reste quelques secondes).
	if not is_instance_valid(phrase_fm): return
	var zone: Control = phrase_fm
	var notes: Dictionary = direct.get("notes", {}) if direct.get("notes") is Dictionary else {}
	var sortant := {"numero": _numero(str(dernier.get("outId", "")), int(dernier.get("slot", 0)) + 1), "nom": "", "note": -1.0, "energie": 100.0}
	var entrant := {"numero": _numero(str(dernier.get("inId", "")), 0), "nom": "", "note_poste": -1.0, "energie": 100.0}
	for j: Variant in (live.get("lineup", []) if live.get("lineup") is Array else []) + (live.get("reserves", []) if live.get("reserves") is Array else []):
		if not j is Dictionary: continue
		if str(j.get("id", "")) == str(dernier.get("outId", "")):
			sortant.nom = str(j.get("name", ""))
			sortant.energie = float(j.get("condition", 100))
			sortant.note = float(W.donnees_joueur(j, notes, {}, {}).note) if notes.has(str(j.id)) else -1.0
		if str(j.get("id", "")) == str(dernier.get("inId", "")):
			entrant.nom = str(j.get("name", ""))
			entrant.energie = float(j.get("condition", 100))
			var complet: Dictionary = Commune.trouver(_app(), str(j.id), "squad").get("joueur", {}) if _app() is Control else {}
			entrant.note_poste = MenuJoueur.note_poste(complet, int(dernier.get("slot", 0)) + 1)
	MenuJoueur.carte_changement(zone, sortant, entrant)

## Note du match en pastille à la couleur de son palier, chiffre écrit (jamais la couleur seule).
func _pastille_note(note: float) -> PanelContainer:
	var teinte := _teinte_note(note)
	var cadre := PanelContainer.new()
	cadre.name = "MatchBetweenPlayerNote"
	var style := _case(teinte, Charte.RAYON_PETIT)
	style.content_margin_left = px(8)
	style.content_margin_right = px(8)
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	cadre.add_theme_stylebox_override("panel", style)
	cadre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texte := _texte(("%.1f" % note).replace(".", ","), 19, Charte.encre_note(note), false, true)
	texte.add_theme_font_override("font", TITRES_EXTRA)
	texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texte.custom_minimum_size.x = px(34)
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(texte)
	return cadre

## Visage d'un joueur découpé en rond (photo du pack recadrée sur le visage, sinon visage généré), avec son numéro en
## médaillon en bas à gauche ; `energie` >= 0 : cerclé de l'anneau de son énergie (comme Observer la préparation).
func _visage(joueur: Dictionary, cote: int, numero: int, energie: float = -1.0) -> Control:
	var boite := Control.new()
	boite.name = "MatchBetweenFace"
	boite.custom_minimum_size = Vector2(cote, cote)
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Même visage que la petite fenêtre du joueur (chargé en différé, photo du pack ou visage généré).
	var anneau_ep := clampf(cote * 0.08, 2.5, float(px(7))) if energie >= 0.0 else 0.0
	var marge := anneau_ep + maxf(1.5, cote * 0.03) if energie >= 0.0 else 0.0
	var diametre := float(cote) - 2.0 * marge
	var disque := Panel.new()
	disque.name = "PortraitDisque"
	var forme := StyleBoxFlat.new()
	forme.bg_color = Charte.PANNEAU_3
	forme.set_corner_radius_all(int(ceilf(diametre / 2.0)))
	forme.anti_aliasing = true
	disque.add_theme_stylebox_override("panel", forme)
	disque.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	disque.position = Vector2(marge, marge)
	disque.size = Vector2(diametre, diametre)
	disque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boite.add_child(disque)
	var agrandi := diametre * 1.18
	var image: TextureRect = S.G.portrait_lazy(int(joueur.get("portraitIndex", 0)), int(agrandi), joueur)
	image.tooltip_text = ""
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.custom_minimum_size = Vector2.ZERO
	image.position = Vector2((diametre - agrandi) / 2.0, (diametre - agrandi) / 2.0 + diametre * 0.08)
	image.size = Vector2(agrandi, agrandi)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disque.add_child(image)
	if energie >= 0.0:
		var anneau := Visuels.Anneau.new()
		anneau.valeur = energie
		anneau.couleur = Jauge.teinte_vive(energie)
		anneau.epaisseur = anneau_ep
		anneau.size = Vector2(cote, cote)
		anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boite.add_child(anneau)
	if numero > 0:
		var medaille := PanelContainer.new()
		medaille.name = "MatchBetweenFaceNumber"
		var d := maxi(16, roundi(cote * 0.4))
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.FOND
		style.set_corner_radius_all(Charte.RAYON_PILULE)
		style.anti_aliasing = true
		style.set_content_margin_all(0)
		medaille.add_theme_stylebox_override("panel", style)
		medaille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		medaille.position = Vector2(-px(4), cote - d + px(2))
		medaille.size = Vector2(d, d)
		var chiffre := _texte(str(numero), 15, IVOIRE, false, true)
		chiffre.add_theme_font_override("font", TITRES_EXTRA)
		chiffre.add_theme_font_size_override("font_size", maxi(12, roundi(d * 0.6)))
		chiffre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chiffre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		medaille.add_child(chiffre)
		boite.add_child(medaille)
	return boite

## Zone du classement aux couleurs franches des données (la forme du symbole et le mot de la légende la portent aussi).
static func _teinte_zone(kind: String) -> Color:
	match kind:
		"bye": return Charte.GAIN
		"playoff": return Charte.REPOS
		"promotion-playoff": return Charte.MORAL
		"relegation-playoff", "repechage": return Charte.INTENSIF
		"relegation": return Charte.PERTE
	return Charte.IVOIRE_3

## En-tête d'un panneau de la colonne de droite : titre et « ← Retour aux chiffres » (Échap).
func _retour_droite(titre: String) -> Control:
	var ligne := S.G.h(px(10))
	var etiquette := _titre_bloc(titre, 24)
	S.G.fill(etiquette)
	ligne.add_child(etiquette)
	var retour := _lien("← Chiffres clés", func(): montrer_droite("chiffres"))
	retour.tooltip_text = "Revenir aux chiffres clés · Échap"
	ligne.add_child(retour)
	return ligne

## Pastille météo du terrain 2D (données du moteur `live.meteo`) : vent, sens et force, pluie, chaleur ; infobulle complète.
func _poser_meteo(live: Dictionary) -> void:
	if not is_instance_valid(meteo_pastille): return
	var m := Meteo.meteo(live)
	var p := meteo_pastille as PastilleMeteo
	p.vent = int(m.get("vent", 0)) if m.get("vent") != null else 0
	p.pluie = int(m.get("pluie", 0)) if m.get("pluie") != null else 0
	p.chaleur = int(m.get("chaleur", 0)) if m.get("chaleur") != null else 0
	var periode := 2 if live.get("atBreak", false) else int(live.get("period", 1))
	var dos := Meteo.camp_vent(live, periode)
	# Le camp 0 attaque vers la droite du terrain : le vent dans son dos souffle vers la droite.
	p.sens = (1 if dos == 0 else -1) if dos in [0, 1] else 0
	p.visible = not live.get("finished", false) and (p.vent > 0 or p.pluie > 0 or p.chaleur > 0)
	var h := float(maxi(22, px(36)))
	p.size = Vector2(p.largeur(h), h)
	p.position = Vector2(px(10), px(8))
	p.tooltip_text = Meteo.bandeau(live) + ("\n" + Meteo.conseil(live) if not Meteo.conseil(live).is_empty() else "")
	p.queue_redraw()

## Panneau de la colonne de droite : « chiffres », « reglages », « journee », « delegation ». Le panneau
## d'arrêt passe devant tant que le match attend la décision du manager.
func montrer_droite(vue: String) -> void:
	vue_droite = vue if vue in ["chiffres", "reglages", "journee", "delegation"] else "chiffres"
	# Variantes : la journée en direct est déjà à l'écran, « Autres matchs » revient aux chiffres clés.
	if not panneaux_direct.is_empty() and vue_droite == "journee": vue_droite = "chiffres"
	if not is_instance_valid(panneau_chiffres): return
	var arret_montre := is_instance_valid(arret) and not _arret.is_empty()
	panneau_chiffres.visible = not arret_montre and vue_droite == "chiffres"
	panneau_parametres.visible = not arret_montre and vue_droite == "reglages"
	panneau_journee.visible = not arret_montre and vue_droite == "journee"
	panneau_delegation.visible = not arret_montre and vue_droite == "delegation"
	if is_instance_valid(arret): arret.visible = arret_montre
	if vue_droite == "journee": _largeur_multiplex.call_deferred()
	_montrer_journee_direct()
	_poser_principal(arret_montre)

## Un seul ivoire plein à l'écran : ÉQUIPE d'ordinaire ; pendant un arrêt-décision, le bouton du panneau d'arrêt,
## ÉQUIPE passant au style lien.
var _equipe_pleine := true
func _poser_principal(arret_montre: bool) -> void:
	if not is_instance_valid(equipe) or _equipe_pleine == not arret_montre: return
	_equipe_pleine = not arret_montre
	_habiller(equipe, _equipe_pleine)
	equipe.add_theme_font_override("font", TITRES_EXTRA)
	equipe.add_theme_font_size_override("font_size", fpx(24 * BARRE_HAUT))
	equipe.custom_minimum_size.y = maxi(26, px(46 * BARRE_HAUT))

## Vues de la colonne Mon XV : « tableau » (Mon XV et le banc) ou « adverse » (le XV adverse).
func choisir_vue_xv(vue: String) -> void:
	vue_xv = "adverse" if vue == "adverse" else "tableau"
	_montrer_vue_xv()
	if not _xv_donnees.is_empty(): _remplir_xv(_xv_donnees[0], _xv_donnees[1])
	_appliquer_blocage()

func _montrer_vue_xv() -> void:
	if not is_instance_valid(titre_xv): return
	titre_xv.text = ("XV adverse" if vue_xv == "adverse" else "Mon XV").to_upper()
	lien_adverse.text = "← Mon XV" if vue_xv == "adverse" else "XV adverse →"
	# Le tri ne range que Mon XV : grisé (et dit) sur le XV adverse.
	for bouton: Button in entetes_tri:
		bouton.disabled = vue_xv == "adverse"
		if not bouton.has_meta("aide"): bouton.set_meta("aide", bouton.tooltip_text)
		bouton.tooltip_text = "Le tri range Mon XV." if vue_xv == "adverse" else str(bouton.get_meta("aide"))
	if is_instance_valid(zone_banc): zone_banc.visible = vue_xv != "adverse"
	if is_instance_valid(legende_notes): legende_notes.visible = vue_xv != "adverse"

## Arrêt-décision (maquette 14-match-entracte-3) : dans la colonne de droite, le motif et la minute, ce
## qui se passe, les choix proposés par le staff (le conseillé en tête), puis « Valider le choix » ; le
## match reste arrêté jusqu'à la décision.
func _arret_decision() -> void:
	var colonne := _panneau(colonne_droite, px(20))
	arret = colonne.get_parent().get_parent()
	arret.name = "MatchBetweenStop"
	S.G.fill(arret, true)
	colonne.add_theme_constant_override("separation", px(12))
	var tete := S.G.h(px(10))
	colonne.add_child(tete)
	arret_titre = _titre_bloc("", 30)
	S.G.fill(arret_titre)
	tete.add_child(arret_titre)
	var reste := _texte("le match reste arrêté", 17, DOUX)
	reste.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(reste)
	arret_texte = _texte("", 20, IVOIRE, true)
	colonne.add_child(arret_texte)
	arret_sous_titre = _texte("CHOIX PROPOSÉS PAR LE STAFF", 16, DOUX, false, true)
	colonne.add_child(arret_sous_titre)
	# Remplacement forcé : une ligne par joueur possible, le choix du staff en tête.
	arret_options = S.G.v(px(4))
	arret_options.name = "MatchBetweenStopOptions"
	arret_options.hide()
	colonne.add_child(arret_options)
	var choix := S.G.h(px(16))
	colonne.add_child(choix)
	arret_reprendre = _bouton("REPRENDRE LE MATCH", _valider_arret, true, true)
	arret_reprendre.name = "MatchBetweenStopResume"
	arret_reprendre.add_theme_font_override("font", TITRES_EXTRA)
	choix.add_child(arret_reprendre)
	choix.add_child(_touche("Entrée"))
	arret_aide = _texte("Équipe, Réglages, Mon XV et le banc reviennent après ce choix.", 17, DOUX, true)
	arret_aide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	S.G.fill(arret_aide)
	choix.add_child(arret_aide)
	var vers_equipe := _lien("Ouvrir l’équipe →", func(): tiroir_demande.emit("Équipe"), "MatchBetweenStopTeam")
	vers_equipe.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	colonne.add_child(vers_equipe)
	arret.hide()

## Bouton du panneau d'arrêt : tant que le choix est à faire, il valide l'option qui a le focus (celle du
## staff sinon) ; une fois le choix enregistré (ou sans choix à faire), il reprend le match.
func _valider_arret() -> void:
	if _choix_en_attente():
		var cible: Button = null
		var focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
		for bouton: Node in arret_options.get_children():
			if bouton is Button and (bouton == focus or (cible == null and bouton.has_meta("retenue"))): cible = bouton
		if cible == null and arret_options.get_child_count() > 0: cible = arret_options.get_child(0) as Button
		if cible != null and not cible.disabled: cible.pressed.emit()
		return
	reprise_demandee.emit()

## Vrai quand le panneau d'arrêt attend encore le choix du manager (options actives, rien d'envoyé).
func _choix_en_attente() -> bool:
	if _arret.is_empty() or not _choix_fait.is_empty() or not is_instance_valid(arret_options) or not arret_options.visible: return false
	return arret_options.get_children().any(func(b: Node) -> bool: return b is Button and not (b as Button).disabled)

static func _zone(x: float, possession: int) -> String:
	# Vu de l'équipe en possession : distance jusqu'à la ligne d'essai adverse.
	var reste := 100.0 - x if possession == 0 else x
	if reste <= 22.0: return "dans les 22 mètres adverses"
	if reste <= 50.0: return "dans le camp adverse"
	if reste <= 78.0: return "dans son camp"
	return "dans ses 22 mètres"

## Libellés d'arrêt de jeu de la ligne d'état (fait montré, avec l'équipe qu'il concerne).
const ETATS_ARRET := {"try": "Essai — %s", "transformation": "Transformation — %s", "goal": "Tir au but — %s", "miss": "Tir au but — %s",
	"lineout": "Touche pour %s", "scrum": "Mêlée pour %s"}

## Ligne d'état du haut pour un fait montré : arrêt de jeu (« Essai — X », « Touche pour X »,
## « Mêlée pour X ») ou possession et territoire (« X a le ballon dans son camp »).
## `camp` : équipe concernée (0/1) ; `x` : position du ballon (NAN : inconnue). Règle commune à la
## 3D (plan affiché, match_temps_forts.gd) et au terrain 2D de l'écran intermédiaire.
static func etat_du_fait(kind: String, camp: int, x: float, equipes: Array) -> String:
	var club := ""
	if camp in [0, 1] and camp < equipes.size() and equipes[camp] is Dictionary: club = S.G.club_name(equipes[camp])
	if ETATS_ARRET.has(kind):
		var modele := str(ETATS_ARRET[kind])
		return modele % club if not club.is_empty() else modele.replace(" — %s", "").replace(" pour %s", "")
	if club.is_empty(): return "Le match"
	var texte := "%s a le ballon" % club
	if not is_nan(x): texte += " " + _zone(x, camp)
	return texte

## Ligne d'état d'un fait du terrain 2D (élément de direct.deroule), « » si inexploitable.
static func etat_du_deroule(item: Dictionary, equipes: Array) -> String:
	var scene: Variant = item.get("scene")
	if not scene is Dictionary: return ""
	var camp: Variant = scene.get("possession", item.get("equipe", -1))
	if not (camp is int or camp is float): camp = item.get("equipe", -1)
	var b: Variant = scene.get("ballon")
	var x: float = float(b[0]) if b is Array and (b as Array).size() >= 1 and (b[0] is float or b[0] is int) else NAN
	return etat_du_fait(str(item.get("kind", scene.get("kind", ""))), int(camp) if (camp is int or camp is float) else -1, x, equipes)

func update_frame(model: Dictionary, live: Dictionary, direct: Dictionary, appliquer: Callable) -> void:
	if not is_node_ready(): return
	_dernier = [model, live, direct, appliquer]
	_tenir_gauche.call_deferred()
	var densite := densite_pour(get_viewport_rect().size)
	if not is_equal_approx(densite, _densite):
		_densite = densite
		_construire()
	var equipes: Array = live.get("teams", [])
	_equipes = equipes
	terrain.direct = direct
	terrain.camp = int(direct.get("camp", -1))
	terrain.regler_equipes(equipes)
	# Le terrain rejoue les faits que le joueur peut voir : rien au-delà du journal montré.
	terrain.alimenter(direct.get("deroule", []), mini(live.get("events", []).size(), int(direct.get("borne", live.get("events", []).size()))))
	terrain.queue_redraw()
	_etat(live, direct, equipes)
	_pilotage = Pilotage.pilotage(live)
	var bulles := get_node_or_null(BullesAdjoint.NOM)
	if bulles != null: bulles.rafraichir()
	var banc_fm := get_node_or_null("MatchFmBanc")
	if banc_fm != null: banc_fm.rafraichir()
	_remplir_journee(model, direct, equipes)
	_remplir_bonus(model, live, direct)
	_niveaux = direct.get("niveaux", [])
	var voulu := niveau_regie if not niveau_regie.is_empty() else str(direct.get("niveau", ""))
	if niveau_libelle() != _libelle_niveau(voulu) or grille_niveaux.get_child_count() != _niveaux.size(): _remplir_niveaux(voulu)
	var dom: Dictionary = direct.get("domination", {}) if direct.get("domination") is Dictionary else {}
	domination.minutes = dom.get("minutes", [])
	domination.mi_temps = dom.get("miTemps")
	domination.reperes = direct.get("reperes", [])
	domination.couleurs = terrain.couleurs.duplicate()
	domination.sigles = [S.G.club_abbr(equipes[0]) if equipes.size() > 0 and equipes[0] is Dictionary else "", S.G.club_abbr(equipes[1]) if equipes.size() > 1 and equipes[1] is Dictionary else ""]
	domination.camp = int(direct.get("camp", -1))
	var haut := domination._haut()
	domination.noms = [_nom_club(equipes, haut), _nom_club(equipes, 1 - haut)]
	var scores := {}
	for item: Variant in direct.get("deroule", []):
		if item is Dictionary and item.get("score") is Array: scores[int(item.get("i", -1))] = item.score
	domination.scores = scores
	domination.teintes = _teintes_duel()
	_poser_momentum(dom.get("minutes", []) if dom.get("minutes") is Array else [], equipes, haut)
	_poser_temps_forts(direct.get("reperes", []) if direct.get("reperes") is Array else [], equipes)
	_remplir_evenements(direct.get("reperes", []) if direct.get("reperes") is Array else [], equipes)
	domination.queue_redraw()
	_remplir_cumul_fm(direct)
	if is_instance_valid(titre_domination) and titre_domination.get_child_count() > 1:
		(titre_domination.get_child(1) as Label).text = "1re mi-temps" if dom.get("minutes", []).size() <= 40 else "2e mi-temps"
	_poser_phase(live)
	_poser_legende(equipes, int(direct.get("camp", -1)))
	meteo_ligne.text = Meteo.bandeau(live)
	_poser_meteo(live)
	if is_instance_valid(stats_lien): stats_lien.tooltip_text = "Toutes les statistiques du match." + ("\n" + meteo_ligne.text if not meteo_ligne.text.is_empty() else "")
	_remplir_banc(live)
	_appliquer_blocage()
	# Conseil de l'adjoint et composition tels qu'ils étaient avant la borne : rien d'un temps fort à venir.
	var passe := _passe(model, live, direct)
	var conseil: Variant = passe.conseil
	var cle := JSON.stringify([direct.get("fil", []), direct.get("tableau", []), direct.get("chiffres", []), conseil, direct.get("notes", {}), direct.get("cartons", []), direct.get("feuille", {}).get("joueurs", {}) if direct.get("feuille") is Dictionary else {},
		passe.lineup, direct.get("statsRows", []), live.get("paused", false), live.get("finished", false), terrain.couleurs, direct.get("pourquoi"), direct.get("hommeDuMatch"), direct.get("zone22"), direct.get("echantillon"), _pilotage.get("joueurs"),
		MenuJoueur.arrets(live).get("file"), live.get("numeros")])
	_suivre_choix(live)
	_montrer_changement(live, direct, passe.lineup)
	if cle == _cle: return
	_cle = cle
	_lignes = direct.get("fil", [])
	# Acteur de chaque fait du fil quand c'est un de nos joueurs (titulaire ou banc) : son nom y mène.
	_acteurs = {}
	var nos_ids := {}
	for j: Variant in (live.get("lineup", []) if live.get("lineup") is Array else []) + (live.get("reserves", []) if live.get("reserves") is Array else []):
		if j is Dictionary: nos_ids[str(j.get("id", ""))] = true
	var evenements: Array = live.get("events", []) if live.get("events") is Array else []
	for entree: Variant in _lignes:
		var i := int(entree.get("i", -1)) if entree is Dictionary else -1
		if i < 0 or i >= evenements.size() or not evenements[i] is Dictionary or not evenements[i].get("scene") is Dictionary: continue
		var acteur: Variant = evenements[i].scene.get("actor")
		if acteur != null and nos_ids.has(str(acteur)): _acteurs[i] = str(acteur)
	_fin = {"fini": live.get("finished", false), "score": live.get("score", []), "camp": int(direct.get("camp", -1)),
		"finale": str(model.get("next", {}).get("phase", "") if model.get("next") is Dictionary else "") == "final", "essais": live.get("tries", []),
		"bonus": direct.get("bonus") if direct.get("bonus") is Dictionary else null}
	_remplir_fil()
	_remplir_chiffres(direct, live)
	_remplir_xv(passe.lineup, direct)
	_remplir_compos_fm(passe.lineup, direct)
	_remplir_adjoint(conseil, live, direct, appliquer)
	if bulles != null: bulles.apres_adjoint()
	_appliquer_blocage()

## Texte imposé par la régie (liaison entre deux temps forts : l'arrêt de jeu en cours) ; vide : l'état du moteur.
var etat_force := ""

func forcer_etat(texte: String) -> void:
	if texte == etat_force: return
	etat_force = texte
	if not texte.is_empty() and is_instance_valid(etat): etat.text = texte
	elif not _dernier.is_empty() and is_instance_valid(etat): _etat(_dernier[1], _dernier[2], _equipes)

func _etat(live: Dictionary, direct: Dictionary, equipes: Array) -> void:
	var possession: Variant = direct.get("possession")
	if not etat_force.is_empty(): etat.text = etat_force
	elif live.get("finished", false): etat.text = "Match terminé"
	elif live.get("atBreak", false): etat.text = "Mi-temps · on change de camp" if live.get("meteo") is Dictionary and live.meteo.get("ventDos") is Array else "Mi-temps"
	elif terrain != null and terrain.en_retard():
		# Le terrain rejoue des faits en retard sur la borne : la ligne suit le dernier fait joué
		# (celui du bandeau du fil), pas le dernier fait de la borne.
		var montre := etat_du_deroule(terrain.joue, equipes)
		etat.text = montre if not montre.is_empty() else "Le match"
	elif (possession is float or possession is int) and equipes.size() >= 2:
		var cote := clampi(int(possession), 0, 1)
		etat.text = "%s a le ballon %s" % [S.G.club_name(equipes[cote]), _zone(float(direct.get("zone", {}).get("x", 50.0)), cote)]
	else: etat.text = "Le match"
	# Sens du jeu : l'équipe en possession et la direction de son attaque sur le terrain (gauche ou droite).
	if is_instance_valid(sens_jeu):
		var p: Variant = direct.get("possession")
		var montre_p: int = terrain.possession if terrain != null and terrain.possession in [0, 1] else (int(p) if (p is int or p is float) else -1)
		sens_jeu.text = ("%s attaque %s" % [S.G.club_name(equipes[montre_p]), "vers la droite" if montre_p == 0 else "vers la gauche"]) if montre_p in [0, 1] and equipes.size() >= 2 and equipes[montre_p] is Dictionary else ""
		etat.tooltip_text = sens_jeu.text
		if is_instance_valid(phrase_trait_fm):
			var c_possession: Variant = (terrain.couleurs[montre_p] if montre_p in [0, 1] and terrain.couleurs.size() == 2 else Color(0, 0, 0, 0))
			phrase_trait_fm.color = Charte.club_trait(c_possession) if montre_p in [0, 1] else Color(0, 0, 0, 0)
	_ajuster_taille(etat)

## Joueur d'une pastille du terrain (« camp:poste ») : {nous, poste, id, nom, poste_nom} ; {} s'il est inconnu.
func joueur_de_pastille(cle: String) -> Dictionary:
	if cle.is_empty(): return {}
	var cote := int(cle.get_slice(":", 0))
	var poste := int(cle.get_slice(":", 1))
	var camp := int(_dernier[2].get("camp", -1)) if _dernier.size() > 2 and _dernier[2] is Dictionary else -1
	var nous := cote == (camp if camp in [0, 1] else 0)
	if nous:
		var lineup: Array = _xv_donnees[0] if not _xv_donnees.is_empty() else []
		if poste < lineup.size() and lineup[poste] is Dictionary:
			return {"nous": true, "poste": poste, "id": str(lineup[poste].get("id", "")), "nom": str(lineup[poste].get("name", "")), "poste_nom": str(lineup[poste].get("pos", ""))}
	else:
		var adverse: Array = _dernier[2].get("adversaire", []) if _dernier.size() > 2 and _dernier[2].get("adversaire") is Array else []
		if poste < adverse.size() and adverse[poste] is Dictionary:
			return {"nous": false, "poste": poste, "id": "", "nom": str(adverse[poste].get("nom", "")), "poste_nom": str(adverse[poste].get("poste", ""))}
	return {}

## Survol d'une pastille : la mini-fiche pour un de nos joueurs ; « n° · poste · nom » en infobulle pour un adversaire.
var _ancre_pastille: Control
func _survol_pastille(cle: String) -> void:
	var app: Object = _app()
	if is_instance_valid(_ancre_pastille) and app is Control: MiniFiche.cacher(app, _ancre_pastille)
	var j := joueur_de_pastille(cle)
	terrain.tooltip_text = "" if j.is_empty() or j.nous else "%d · %s · %s" % [int(j.poste) + 1, str(j.poste_nom), str(j.nom)]
	if j.is_empty() or not j.nous or not app is Control or not terrain.centres_dessin.has(cle): return
	if not is_instance_valid(_ancre_pastille):
		_ancre_pastille = Control.new()
		_ancre_pastille.name = "MatchBetweenPitchAnchor"
		_ancre_pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		terrain.add_child(_ancre_pastille)
	var r := terrain.rayon_dessin
	_ancre_pastille.position = (terrain.centres_dessin[cle] as Vector2) - Vector2(r, r)
	_ancre_pastille.size = Vector2(r, r) * 2.0
	MiniFiche.montrer(app, str(j.id), "squad", _ancre_pastille)

## Clic sur une pastille d'un de nos joueurs : sa fiche complète (règle de Léo sur les noms ; « ← Retour au direct »
## la referme), sa ligne de Mon XV gardant le focus derrière (Entrée ouvre Équipe sur lui). Pour un adversaire (pas
## de fiche), le tableau passe au XV adverse.
func _choix_pastille(cle: String) -> void:
	var j := joueur_de_pastille(cle)
	if j.is_empty(): return
	if not j.nous:
		if vue_xv != "adverse": choisir_vue_xv("adverse")
		return
	if vue_xv != "tableau": choisir_vue_xv("tableau")
	selectionner_joueur(int(j.poste))
	ouvrir_fiche(str(j.id))

## Met le focus sur la ligne du poste dans Mon XV et la fait défiler dans la vue.
func selectionner_joueur(poste: int) -> void:
	var ligne := xv.find_child("MatchBetweenPlayer%d" % (poste + 1), false, false) as Control
	if ligne == null: return
	ligne.grab_focus()
	var defile := find_child("MatchBetweenSquadScroll", true, false) as ScrollContainer
	if defile != null: defile.ensure_control_visible(ligne)

## Minute du moteur écrite sans décimale (« 42 » et non « 42.0 »).
static func _minute(valeur: Variant) -> String:
	return str(roundi(float(valeur))) if valeur is float or valeur is int else str(valeur)

## Texte d'une ligne jamais coupé : sa taille de police baisse (jusqu'aux deux tiers, plancher de 12 px) pour tenir
## dans sa largeur ; au-delà, il passe à la ligne (deux lignes au plus).
func _ajuster_taille(etiquette: Label) -> void:
	if not is_instance_valid(etiquette) or etiquette.size.x <= 1.0: return
	var base := int(etiquette.get_meta("taille_base", etiquette.get_theme_font_size("font_size")))
	var police: Font = etiquette.get_theme_font("font")
	var taille := base
	var plancher := maxi(12, roundi(base * 0.66))
	while taille > plancher and police.get_string_size(etiquette.text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > etiquette.size.x: taille -= 1
	if etiquette.get_theme_font_size("font_size") != taille: etiquette.add_theme_font_size_override("font_size", taille)
	var trop := police.get_string_size(etiquette.text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > etiquette.size.x
	var voulu := TextServer.AUTOWRAP_WORD_SMART if trop else TextServer.AUTOWRAP_OFF
	if etiquette.autowrap_mode != voulu:
		etiquette.autowrap_mode = voulu
		etiquette.max_lines_visible = 2 if trop else -1

## Nom d'un club du match (vide s'il manque).
static func _nom_club(equipes: Array, cote: int) -> String:
	return S.G.club_name(equipes[cote]) if cote >= 0 and cote < equipes.size() and equipes[cote] is Dictionary else ""

## Phase du match, dans la barre de commandes : mi-temps, pause, défilement 2D et vitesse de l'horloge.
func _poser_phase(live: Dictionary) -> void:
	if not is_instance_valid(phase): return
	var vitesse: String = HORLOGES_COURTS[maxi(0, HORLOGES_IDS.find(horloge))]
	var titre := "Match terminé" if live.get("finished", false) else ("Mi-temps" if live.get("atBreak", false) else ("Arrêt de jeu" if not _arret.is_empty() else ("En pause" if live.get("paused", false) else "%d′" % roundi(float(live.get("minute", 0))))))
	# Juste l'état du jeu : la vitesse se règle dans « Plus » et n'a pas sa place ici (retouche de Léo du 21/11/2026).
	phase.text = ("%s · décision attendue" % titre) if not _arret.is_empty() else titre
	phase.tooltip_text = "Vitesse de l’horloge : %s (menu Plus)" % vitesse
	_poser_pied()
	_ajuster_phase()

## L'état du jeu tient dans sa place de la bande des commandes (bouton « Banc » ajouté le 24/11) : la police baisse un
## peu plutôt que de couper le mot (« En paus »).
func _ajuster_phase() -> void:
	if not is_instance_valid(phase) or phase.size.x <= 1.0: return
	if not phase.has_meta("taille_base"): phase.set_meta("taille_base", phase.get_theme_font_size("font_size"))
	if not phase.resized.is_connected(_ajuster_phase): phase.resized.connect(_ajuster_phase)
	var base := int(phase.get_meta("taille_base"))
	var cadre: StyleBox = phase.get_theme_stylebox("normal")
	var place := phase.size.x - (cadre.get_margin(SIDE_LEFT) + cadre.get_margin(SIDE_RIGHT) if cadre != null else 0.0)
	var police: Font = phase.get_theme_font("font")
	var taille := base
	while taille > maxi(12, roundi(base * 0.6)) and police.get_string_size(phase.text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > place: taille -= 1
	if phase.get_theme_font_size("font_size") != taille: phase.add_theme_font_size_override("font_size", taille)

## Pied : la vitesse de l'horloge (dans Réglages) et où trouver les autres matchs (menu Plus).
func _poser_pied() -> void:
	if not is_instance_valid(pied_reglages): return
	# Plus de « Vitesse · … » sur l'écran (réglée dans « Plus ») : le pied garde le « ? » des raccourcis.
	pied_reglages.visible = false
	pied_reglages.text = "Vitesse · %s" % HORLOGES_COURTS[maxi(0, HORLOGES_IDS.find(horloge))]

## Légende des chiffres clés : notre club (carré plein) à gauche, l'adversaire (carré vide) à droite.
var _legende_cle := ""
func _poser_legende(equipes: Array, camp: int) -> void:
	if not is_instance_valid(legende_chiffres): return
	var cle := JSON.stringify([_nom_club(equipes, 0), _nom_club(equipes, 1), camp, terrain.couleurs, legende_chiffres.get_instance_id()])
	if cle == _legende_cle: return
	_legende_cle = cle
	S.clear(legende_chiffres)
	var nous := camp if camp in [0, 1] else 0
	for cote: int in [nous, 1 - nous]:
		# Nous : case pleine vert clair ; eux : filet bas doré (le camp, pas le club ; le nom est écrit à côté).
		var marque := ColorRect.new()
		marque.color = _teintes_duel()[0] if cote == nous else Color(0, 0, 0, 0)
		marque.custom_minimum_size = Vector2(px(18), px(12))
		marque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		marque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if cote != nous:
			var cadre := Panel.new()
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = _teintes_duel()[1]
			# Marque « vide » de l'adversaire : un filet bas épais.
			style.set_border_width_all(0)
			style.border_width_bottom = maxi(2, px(3))
			cadre.add_theme_stylebox_override("panel", style)
			cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
			S.full(cadre)
			marque.add_child(cadre)
		var nom := _texte(_nom_club(equipes, cote), 18, DOUX)
		if cote == nous:
			legende_chiffres.add_child(marque)
			legende_chiffres.add_child(nom)
			var milieu := Control.new()
			milieu.mouse_filter = Control.MOUSE_FILTER_IGNORE
			S.G.fill(milieu)
			legende_chiffres.add_child(milieu)
		else:
			legende_chiffres.add_child(nom)
			legende_chiffres.add_child(marque)

## Un fait vient d'être joué sur le terrain : le fil le montre, le score le suit.
func _fait_joue(item: Dictionary) -> void:
	_remplir_fil()
	# La ligne d'état suit le fait joué (même instant que le bandeau du fil).
	if not _dernier.is_empty() and is_instance_valid(etat): _etat(_dernier[1], _dernier[2], _equipes)
	var marque: Variant = item.get("score")
	if marque is Array and (marque as Array).size() == 2: score_joue.emit(marque)

## Minute à afficher tant que le terrain rejoue des faits en retard sur le moteur (« 1′ »), sinon vide :
## l'horloge du bandeau suit ce que montre le terrain, comme le score.
func horloge_differee() -> String:
	if terrain == null or not terrain.en_retard(): return ""
	return terrain.horloge_montree()

## Score à montrer tant que le terrain rejoue des faits en retard sur le moteur, sinon vide.
func score_differe() -> Array:
	if terrain == null or not terrain.en_retard() or terrain.joue.is_empty(): return []
	var marque: Variant = terrain.joue.get("score")
	return marque if marque is Array and (marque as Array).size() == 2 else []

## Fil : une ligne n'y entre qu'une fois son fait joué sur le terrain ; le dernier, sous l'en-tête du terrain
## (le journal complet est dans le menu Plus).
func _remplir_fil() -> void:
	if not is_instance_valid(fil): return
	S.clear(fil)
	var visibles: Array = []
	var prochain := terrain.prochain_i()
	for entree: Dictionary in _lignes:
		var i := int(entree.get("i", -1))
		if prochain >= 0 and i >= prochain: continue
		visibles.append(entree)
	# Le dernier fait joué ; il apparaît en fondu (sauf animations réduites).
	if not visibles.is_empty():
		var ligne := _ligne_fil(visibles[-1], true, true)
		fil.add_child(ligne)
		var i := int(visibles[-1].get("i", -1))
		if i != _dernier_fait and not _animations_reduites() and is_inside_tree():
			ligne.modulate.a = 0.0
			create_tween().tween_property(ligne, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
		_dernier_fait = i
	else: fil.add_child(_texte("Le coup d’envoi approche.", 19, DOUX))

## Hauteur d'une étiquette pour montrer `lignes` lignes entières (police, interligne et style compris).
static func hauteur_lignes(etiquette: Label, lignes: int) -> float:
	var police: Font = etiquette.get_theme_font("font")
	var taille := etiquette.get_theme_font_size("font_size")
	var interligne := float(etiquette.get_theme_constant("line_spacing"))
	var style: StyleBox = etiquette.get_theme_stylebox("normal")
	var marges := style.get_minimum_size().y if style != null else 0.0
	return ceilf(police.get_height(taille) * lignes + interligne * maxi(0, lignes - 1) + marges + 1.0)

## Occasion de la photo de fin de match : finale, victoire bonifiée selon la règle du championnat (`fin.bonus`,
## calculé par le moteur : 3 essais d'écart en Top 14, 4 essais marqués en Premiership et URC…), sinon championnat.
## Sans bonus en jeu (élimination directe, amical), jamais de victoire bonifiée.
static func occasion_fin(fin: Dictionary, resultat: String) -> String:
	if fin.get("finale", false) and resultat != "nul": return "finale"
	var bonus: Variant = fin.get("bonus")
	if resultat == "victoire" and bonus is Dictionary and bonus.get("offensif") is Dictionary and bool(bonus.offensif.get("acquis", false)): return "bonus"
	return "championnat"

## Image de la banque pour un fait du moteur ("" : fait sans photo).
static func photo_du_fait(kind: String, texte: String) -> String:
	match kind:
		"try": return "action-essai"
		"transformation": return "action-transformation"
		"goal", "penalty", "miss": return "action-coup-de-pied-but"
		"card": return "action-carton-rouge" if texte.to_lower().contains("rouge") else "action-carton-jaune"
		"scrum": return "action-melee"
		"lineout": return "action-touche"
		"turnover", "hand-fault": return "action-ballon-perdu"
		"carry": return "action-franchissement"
	var t := texte.to_lower()
	if t.contains("vidéo") or t.contains("tmo"): return "action-arbitrage-video"
	if t.contains("bless") or t.contains("soign"): return "action-blessure-soins"
	if t.contains("remplac") or t.contains("entre en jeu"): return "action-remplacement"
	return ""

## Ligne du fil : minute, pictogramme du fait cerclé au camp (nous vert clair, eux doré), texte (une ligne, le reste en infobulle).
func _ligne_fil(entree: Dictionary, dernier: bool, en_bandeau: bool) -> Control:
	var kind := str(entree.get("kind", ""))
	var points := kind in ["try", "goal", "transformation"]
	var equipe := int(entree.get("equipe", -1)) if entree.get("equipe") != null else -1
	var notre_camp := int(_dernier[2].get("camp", 0)) if _dernier.size() > 2 and _dernier[2] is Dictionary else 0
	var teinte: Color = (Charte.V if equipe == notre_camp else Charte.D) if equipe in [0, 1] else FAIBLE
	var ligne := PanelContainer.new()
	ligne.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	ligne.set_meta("i", int(entree.get("i", -1)))
	ligne.name = "MatchBetweenFeedLine"
	# Le dernier fait mène au journal, à ce fait (clic) ; son acteur, s'il est des nôtres, à sa mini-fiche (survol).
	ligne.mouse_filter = Control.MOUSE_FILTER_STOP
	ligne.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ligne.tooltip_text = str(entree.get("texte", "")) + "\nClic : le journal du match à ce fait."
	var i_fait := int(entree.get("i", -1))
	ligne.gui_input.connect(func(evenement: InputEvent):
		var clic := evenement as InputEventMouseButton
		if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT and i_fait >= 0: journal_demande.emit(i_fait))
	var rang := S.G.h(px(10))
	ligne.add_child(rang)
	var heure := _texte(str(entree.get("horloge", "")), 19, IVOIRE if dernier or points else DOUX, false, true)
	heure.custom_minimum_size.x = px(44)
	rang.add_child(heure)
	var icone := Icone.new()
	icone.kind = kind
	icone.teinte = teinte
	icone.rouge = str(entree.get("texte", "")).to_lower().contains("rouge")
	icone.custom_minimum_size = Vector2(px(26), px(26))
	icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rang.add_child(icone)
	var texte := _texte(str(entree.get("texte", "")), 19, IVOIRE if points else DOUX, true)
	texte.max_lines_visible = 2 if en_bandeau else 1
	texte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texte.clip_text = true
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(texte)
	rang.add_child(texte)
	var app_fil: Object = _app()
	if _acteurs.has(i_fait) and app_fil is Control:
		texte.mouse_filter = Control.MOUSE_FILTER_PASS
		texte.set_meta("player_id", _acteurs[i_fait])
		MiniFiche.lier(app_fil, texte, str(_acteurs[i_fait]), "squad")
	return ligne

## Valeur affichée d'un chiffre clé pour un côté (0 ou 1 du moteur) ; « — » tant que la donnée est vide.
func _valeur(rang: Dictionary, cote: int) -> String:
	var valeurs: Array = rang.get("valeurs", [0, 0])
	if rang.get("vide", false): return "—"
	var texte := str(int(valeurs[cote])) + (" " + str(rang.unite) if str(rang.get("unite", "")) == "%" else str(rang.get("unite", "")))
	if rang.get("sur") is Array: texte = "%d / %d" % [int(valeurs[cote]), int(rang.sur[cote])]
	return texte

## Chiffre clé face à face (maquette) : libellé centré au-dessus ; notre valeur à gauche, la barre (notre
## part pleine, la leur vide), leur valeur à droite.
func _ligne_chiffre(parent: Control, rang: Dictionary, nous: int) -> void:
	# La ligne entière ouvre les statistiques complètes à ce chiffre (survol : fond plus clair, main).
	var lien := Button.new()
	lien.name = "MatchBetweenFigure_" + str(rang.get("cle", ""))
	lien.flat = true
	lien.focus_mode = Control.FOCUS_ALL
	lien.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	lien.set_meta("contextual_enabled", true)
	for etat_bouton in ["normal", "hover", "pressed", "focus"]:
		var style := _case(RELIEF if etat_bouton in ["hover", "pressed", "focus"] else Color(0, 0, 0, 0))
		if etat_bouton == "focus": _anneau(style)
		lien.add_theme_stylebox_override(etat_bouton, style)
	var libelle := str(rang.get("stats", rang.get("label", "")))
	var rang_clic := rang.duplicate()
	lien.pressed.connect(func(): stat_demandee.emit(rang_clic))
	lien.set_meta("stat", libelle)
	lien.tooltip_text = "%s : %s %s · %s %s\nClic : les statistiques complètes à cette ligne." % [str(rang.get("label", "")), _nom_club(_equipes, nous), _valeur(rang, nous), _nom_club(_equipes, 1 - nous), _valeur(rang, 1 - nous)]
	var bloc := S.G.v(px(2))
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(bloc)
	lien.add_child(bloc)
	bloc.alignment = BoxContainer.ALIGNMENT_CENTER
	lien.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bloc.minimum_size_changed.connect(func(): lien.custom_minimum_size.y = bloc.get_combined_minimum_size().y)
	var titre := _texte(str(LIBELLES_COURTS.get(str(rang.get("cle", "")), rang.get("label", ""))).to_upper(), 18, DOUX, false, true)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(titre)
	var ligne := S.G.h(px(12))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(ligne)
	var a := _texte(_valeur(rang, nous), 26, IVOIRE)
	a.add_theme_font_override("font", TITRES_EXTRA)
	a.custom_minimum_size.x = px(84)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(a)
	var barre := Barre.new()
	var valeurs: Array = rang.get("valeurs", [0, 0])
	barre.valeurs = [valeurs[nous], valeurs[1 - nous]] if not rang.get("vide", false) else [0, 0]
	# Variantes C et D : les deux clubs à leurs couleurs (la part pleine / vide garde le camp lisible sans la couleur).
	barre.couleurs = _teintes_duel()
	lien.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barre.densite = _densite
	barre.custom_minimum_size = Vector2(px(80), px(24))
	barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(barre)
	ligne.add_child(barre)
	var b := _texte(_valeur(rang, 1 - nous), 26, IVOIRE)
	b.add_theme_font_override("font", TITRES_EXTRA)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.custom_minimum_size.x = px(84)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(b)
	parent.add_child(lien)
	lien.custom_minimum_size.y = bloc.get_combined_minimum_size().y

## Chiffres clés du moteur (`direct.tableau`, `direct.zone22`), vus de notre camp. Deux chiffres sont dérivés
## de données réelles : les entrées dans les 22 (`zone22.entrees`) et la part de plaquages réussis (plaquages
## réussis sur plaquages tentés, manqués compris). Une donnée absente : la ligne est omise.
func _remplir_chiffres(direct: Dictionary, _live: Dictionary) -> void:
	S.clear(chiffres)
	chiffres.add_theme_constant_override("separation", px(10))
	# Premières minutes : un « 100 % / 0 % » ne dit rien. Les parts restent masquées (« — ») et les
	# compteurs atténués jusqu'au seuil du moteur ; la précision dit quand la lecture deviendra fiable.
	echantillon_court = est_court(direct)
	chiffres.modulate = Color(1, 1, 1, ATTENUE) if echantillon_court else Color.WHITE
	if is_instance_valid(precision_chiffres):
		precision_chiffres.text = ("Fiable dès la %de min" % seuil_echantillon(direct)) if echantillon_court else ""
		precision_chiffres.visible = echantillon_court
	var camp := int(direct.get("camp", -1))
	var nous := camp if camp in [0, 1] else 0
	var rangs: Array = direct.get("tableau", [])
	var par_cle := {}
	for rang: Variant in rangs:
		if rang is Dictionary: par_cle[str(rang.get("cle", ""))] = rang
	var z: Variant = direct.get("zone22")
	if z is Dictionary and z.get("entrees") is Array and (z.entrees as Array).size() == 2:
		par_cle["zone22"] = {"cle": "zone22", "label": "Entrées dans les 22 mètres adverses", "stats": "22", "valeurs": [int(z.entrees[0]), int(z.entrees[1])]}
	if par_cle.has("plaquages") and par_cle.has("plaquages_manques"):
		var reussis: Array = par_cle.plaquages.get("valeurs", [0, 0])
		var manques: Array = par_cle.plaquages_manques.get("valeurs", [0, 0])
		var parts: Array = []
		for cote in 2:
			var tentes := int(reussis[cote]) + int(manques[cote])
			parts.append(roundi(100.0 * int(reussis[cote]) / tentes) if tentes > 0 else 0)
		var vide := int(reussis[0]) + int(manques[0]) == 0 or int(reussis[1]) + int(manques[1]) == 0
		par_cle["plaquages_reussis"] = {"cle": "plaquages_reussis", "label": "Plaquages réussis (part des plaquages tentés)", "stats": "Plaquages", "valeurs": parts, "unite": "%", "vide": vide}
	# Toujours le même ordre (« — » tant qu'un chiffre est vide).
	for cle: String in STATS + (STATS_PLUS if _densite >= 0.7 else []):
		if par_cle.has(cle): _ligne_chiffre(chiffres, par_cle[cle], nous)
	_rangs = rangs
	_remplir_barres_fm(par_cle, nous)

## Tuile Bonus : la règle du championnat, l'état vu de notre camp et, en fin de match, le dilemme et ses deux
## consignes (la consigne en place est en or). Rien n'est calculé ici : tout vient de `direct.bonus`.
func _remplir_bonus(model: Dictionary, live: Dictionary, direct: Dictionary) -> void:
	if not is_instance_valid(bonus_tuile): return
	var bonus: Variant = direct.get("bonus")
	var tactiques: Dictionary = model.get("tactics", {}) if model.get("tactics") is Dictionary else {}
	var cle := JSON.stringify([bonus, tactiques.get("attack"), tactiques.get("defense"), tactiques.get("penalty"), live.get("finished", false)])
	if cle == _bonus_cle: return
	_bonus_cle = cle
	bonus_tuile.visible = bonus is Dictionary
	_largeur_multiplex.call_deferred()
	if not bonus is Dictionary: return
	bonus_regle.text = str(bonus.get("regle", ""))
	bonus_regle.tooltip_text = "Règle du championnat : " + str(bonus.get("regle", ""))
	S.clear(bonus_etat)
	for cote: String in ["offensif", "defensif"]:
		var item: Variant = bonus.get(cote)
		if not item is Dictionary or str(item.get("texte", "")).is_empty(): continue
		var teinte := DOUX
		if bool(item.get("acquis", false)) or str(item.get("statut", "")) == "tenu": teinte = MONTEE
		elif bool(item.get("horsDePortee", false)): teinte = FAIBLE
		elif str(item.get("statut", "")) == "perdu" or int(item.get("manque", 0) if item.get("manque") != null else 0) > 0: teinte = OR
		var etiquette := _texte(str(item.texte), 19, teinte, true, true)
		S.G.fill(etiquette)
		etiquette.name = "MatchBetweenBonus_" + cote
		bonus_etat.add_child(etiquette)
	S.clear(bonus_choix)
	var situation: Variant = bonus.get("situation")
	bonus_situation.visible = situation is Dictionary
	bonus_choix.visible = situation is Dictionary
	if not situation is Dictionary: return
	bonus_situation.text = str(situation.get("texte", ""))
	bonus_situation.tooltip_text = bonus_situation.text
	for consigne: Variant in situation.get("consignes", []):
		if not consigne is Dictionary: continue
		var c: Dictionary = consigne
		var en_place := str(tactiques.get("attack", "")) == str(c.get("attack", "")) and str(tactiques.get("defense", "")) == str(c.get("defense", "")) and str(tactiques.get("penalty", "auto")) == str(c.get("penalty", ""))
		# Choix entre deux consignes : la consigne en place est marquée par le mot, le filet épais et la coche.
		var bouton := _bouton(str(c.get("label", "")) + ("  · en place" if en_place else ""), func(): consigne_bonus.emit(c), not live.get("finished", false))
		bouton.name = "MatchBetweenBonusChoice_" + str(c.get("id", ""))
		_style_segment(bouton)
		if en_place:
			bouton.add_theme_stylebox_override("normal", bouton.get_theme_stylebox("pressed"))
			_cocher(bouton, true)
		bouton.custom_minimum_size.y = maxi(px(52), 36)
		bouton.add_theme_font_size_override("font_size", fpx(20))
		bouton.clip_text = true
		bouton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		bouton.tooltip_text = str(c.get("aide", "")) + ("\nConsigne en place." if en_place else "\nLe match se met en pause le temps de la donner.")
		bouton.set_meta("contextual_enabled", true)
		S.G.fill(bouton)
		bonus_choix.add_child(bouton)

## Journée en direct (`direct.journee`) : classement en direct et multiplex, masqués sans elle.
func _remplir_journee(model: Dictionary, direct: Dictionary, equipes: Array) -> void:
	if not is_instance_valid(classement_tuile) or not is_instance_valid(multiplex): return
	var journee: Variant = direct.get("journee")
	if not journee is Dictionary: journee = null
	var cle := JSON.stringify(journee)
	if cle == _journee_cle: return
	_journee_cle = cle
	journee_vue = journee
	if journee == null:
		classement_tuile.visible = false
		multiplex.visible = false
		journee_vide.visible = true
		_journee_minute = -1
		_scores_cour = {}
		_scores_prec = {}
		if vue_droite == "journee": montrer_droite("chiffres")
		_montrer_journee_direct()
		return
	var teintes := _teintes_clubs(model, equipes)
	_clubs_et_zones(model, equipes, journee.get("classement", []) if journee.get("classement") is Array else [])
	_remplir_classement(journee.get("classement", []) if journee.get("classement") is Array else [], teintes)
	_poser_enjeu(journee.get("classement", []) if journee.get("classement") is Array else [])
	_remplir_multiplex(journee, teintes)
	journee_vide.visible = not classement_tuile.visible and not multiplex.visible
	_montrer_journee_direct()

func _journee_montree() -> bool:
	return is_instance_valid(classement_tuile) and classement_tuile.visible

## Couleur de chaque club connu du modèle (tableaux des ligues, notre club, les deux équipes du
## match), par identifiant ; un club sans couleur reste neutre.
static func _teintes_clubs(model: Dictionary, equipes: Array) -> Dictionary:
	var clubs: Array = []
	for division: Variant in model.get("leagues", []):
		if division is Dictionary: clubs.append_array(division.get("rows", []))
	clubs.append(model.get("club"))
	clubs.append_array(equipes)
	var teintes := {}
	for club: Variant in clubs:
		if not club is Dictionary or club.get("id") == null: continue
		var c := str(S.G.identity(club).get("color", club.get("color", "")))
		if c.begins_with("#") and (c.length() == 7 or c.length() == 9): teintes[_cle_club(club.get("id"))] = Color(c)
	return teintes

static func _cle_club(id: Variant) -> String:
	return str(int(id)) if id is float or id is int else str(id)

## Lignes montrées du classement (indices ; -1 pour « … ») : tout le tableau s'il tient, sinon le
## haut du tableau et notre voisinage (trois places de part et d'autre), sans défilement.
static func lignes_classement(classement: Array, capacite: int = CLASSEMENT_LIGNES) -> Array:
	var n := classement.size()
	if n <= capacite: return range(n)
	var nous := -1
	for k in n:
		if classement[k] is Dictionary and bool(classement[k].get("nous", false)): nous = k
	if nous < 0: return range(capacite)
	var fenetre := mini(7, capacite)
	# Notre club au milieu de la fenêtre (± 3 places sur sept, ± 2 sur cinq).
	var debut := clampi(nous - floori(fenetre / 2.0), 0, n - fenetre)
	var fin := debut + fenetre
	var restants := capacite - fenetre
	if debut <= restants: return range(maxi(capacite, fin))
	if restants < 2: return range(debut, fin)
	var lignes: Array = range(restants - 1)
	lignes.append(-1)
	lignes.append_array(range(debut, fin))
	return lignes

## Zone qui ouvre la fiche d'un club (ligne du classement, club d'une carte du multiplex) : main au survol, fond
## de survol, clic gauche ou Entrée = `club_demande`. Sans identifiant, la zone reste du texte (rien ne l'invite).
func _cliquable_club(zone: Control, id: Variant, fond_survol: StyleBox = null) -> void:
	if id == null or not (id is int or id is float or (id is String and (id as String).is_valid_int())): return
	var club := int(id) if not id is String else (id as String).to_int()
	zone.set_meta("club_id", club)
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.focus_mode = Control.FOCUS_ALL
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zone.tooltip_text = (zone.tooltip_text + "\n" if not zone.tooltip_text.is_empty() else "") + "Clic : la fiche du club (le match se met en pause)."
	var survol := func(dedans: bool):
		if fond_survol == null or not zone is PanelContainer: return
		if not zone.has_meta("fond_repos"): zone.set_meta("fond_repos", zone.get_theme_stylebox("panel"))
		zone.add_theme_stylebox_override("panel", fond_survol if dedans else zone.get_meta("fond_repos"))
	zone.mouse_entered.connect(survol.bind(true))
	zone.mouse_exited.connect(survol.bind(false))
	zone.focus_entered.connect(survol.bind(true))
	zone.focus_exited.connect(survol.bind(false))
	zone.gui_input.connect(func(event: InputEvent):
		var clic := event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		var entree := event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER]
		if clic or entree:
			zone.accept_event()
			club_demande.emit(club))

## Fond de survol d'une zone cliquable (ligne, carte) : case `PANNEAU_3` rayon 6 (survol de la charte).
func _fond_survol() -> StyleBoxFlat:
	var style := _case(SURVOL)
	style.content_margin_left = px(8)
	style.content_margin_right = px(10)
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _remplir_classement(classement: Array, teintes: Dictionary) -> void:
	S.clear(classement_lignes)
	classement_tuile.visible = not classement.is_empty()
	if classement.is_empty(): return
	if true:
		# Le classement complet de la poule, sans défilement.
		for r: Variant in classement:
			if r is Dictionary: classement_lignes.add_child(_ligne_classement_v2(r, teintes))
		_poser_legende_zones(classement)
		return
	# Notre voisinage (± 3 places) ; en 1280×720, ± 2 places : la colonne de droite tient dans l'écran.
	for k: int in lignes_classement(classement, CLASSEMENT_ECRAN_720 if not panneaux_direct.is_empty() else CLASSEMENT_LIGNES if _densite >= 0.6 else CLASSEMENT_ECRAN):
		if k < 0:
			var ellipse := _texte("…", 22, FAIBLE)
			ellipse.name = "MatchBetweenLiveTableGap"
			ellipse.custom_minimum_size.y = px(22)
			ellipse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			classement_lignes.add_child(ellipse)
			continue
		if classement[k] is Dictionary: classement_lignes.add_child(_ligne_classement(classement[k], teintes))

## Ligne du classement : rang, évolution, pastille du club, sigle et nom, badges de bonus, points.
## Notre club sur la ligne choisie de la charte (`SELECTION`, rayon 6) ; filet entre les lignes, sans bandes.
func _ligne_classement(r: Dictionary, teintes: Dictionary) -> Control:
	var nous := bool(r.get("nous", false))
	var ligne := PanelContainer.new()
	ligne.name = "MatchBetweenLiveRow%d" % int(r.get("rang", 0))
	ligne.set_meta("rang", int(r.get("rang", 0)))
	ligne.set_meta("nous", nous)
	var fond := _case(Charte.SELECTION if nous else Color(0, 0, 0, 0), Charte.RAYON_PETIT if nous else 0)
	fond.content_margin_left = px(8)
	fond.content_margin_right = px(10)
	fond.content_margin_top = 0
	fond.content_margin_bottom = 0
	if not nous:
		fond.border_width_bottom = 1
		fond.border_color = TRAIT
	ligne.add_theme_stylebox_override("panel", fond)
	ligne.custom_minimum_size.y = px(32)
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	var delta := int(r.get("delta", 0))
	var nom := str(r.get("nom", ""))
	ligne.tooltip_text = "%d. %s · %d pts · %d joués · différence %+d%s" % [int(r.get("rang", 0)), nom if not nom.is_empty() else str(r.get("abbr", "")), int(r.get("points", 0)), int(r.get("joues", 0)), int(r.get("diff", 0)),
		("" if r.get("rangOfficiel") == null else " · %s au classement officiel" % ("%de" % int(r.rangOfficiel) if int(r.rangOfficiel) > 1 else "1er"))]
	var rang := S.G.h(px(8))
	rang.add_theme_constant_override("separation", px(8))
	ligne.add_child(rang)
	var numero := _cellule(str(int(r.get("rang", 0))), 36, OR if nous else DOUX, 26, true)
	numero.name = "Rang"
	rang.add_child(numero)
	var fleche := Fleche.new()
	fleche.name = "Evolution"
	fleche.delta = delta
	fleche.custom_minimum_size = Vector2(px(22), px(22))
	fleche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fleche.tooltip_text = "Gagne %d place%s" % [delta, "s" if delta > 1 else ""] if delta > 0 else ("Perd %d place%s" % [-delta, "s" if delta < -1 else ""] if delta < 0 else "Même place")
	rang.add_child(fleche)
	var pastille := Pastille.new()
	pastille.name = "Couleur"
	pastille.teinte = teintes.get(_cle_club(r.get("clubId")), FAIBLE)
	pastille.custom_minimum_size = Vector2(px(18), px(18))
	pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rang.add_child(pastille)
	var sigle := str(r.get("abbr", ""))
	var club := _cellule(sigle if not sigle.is_empty() else nom, 0, IVOIRE, 26)
	club.name = "Club"
	rang.add_child(club)
	for badge: Array in [["bonusOff", "BO", "bonus offensif"], ["bonusDef", "BD", "bonus défensif"]]:
		var nombre := int(r.get(badge[0], 0)) if r.get(badge[0]) != null else 0
		if nombre <= 0: continue
		var pastille_bonus := PanelContainer.new()
		pastille_bonus.name = "Badge" + str(badge[1])
		var style := _case(Charte.VOILE_VERT if badge[1] == "BO" else RELIEF)
		style.content_margin_left = px(6)
		style.content_margin_right = px(6)
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		pastille_bonus.add_theme_stylebox_override("panel", style)
		pastille_bonus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pastille_bonus.tooltip_text = "%d %s%s" % [nombre, badge[2], "s" if nombre > 1 else ""]
		pastille_bonus.mouse_filter = Control.MOUSE_FILTER_PASS
		var texte := _texte(str(badge[1]), 20, VERT_SCORE if badge[1] == "BO" else DOUX, false, true)
		texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille_bonus.add_child(texte)
		rang.add_child(pastille_bonus)
	var points := _cellule(str(int(r.get("points", 0))), 44, OR if nous else IVOIRE, 26, true)
	points.name = "Points"
	rang.add_child(points)
	fleche.mouse_filter = Control.MOUSE_FILTER_PASS
	_cliquable_club(ligne, r.get("clubId"), _fond_survol())
	return ligne

## Multiplex : une carte par autre match (deux lignes club et score, essais en petit, minute ou
## « Terminé ») ; liseré vert sur un score qui a changé depuis la minute montrée précédente.
func _remplir_multiplex(journee: Dictionary, teintes: Dictionary) -> void:
	var matchs: Array = journee.get("matchs", []) if journee.get("matchs") is Array else []
	var minute := int(journee.get("minute", 0))
	var scores := {}
	for m: Variant in matchs:
		if m is Dictionary: scores[str(m.get("id", ""))] = [int(m.get("home", {}).get("score", 0)), int(m.get("away", {}).get("score", 0))]
	if minute != _journee_minute:
		if _journee_minute >= 0: _scores_prec = _scores_cour
		_journee_minute = minute
	_scores_cour = scores
	S.clear(multiplex_cartes)
	multiplex.visible = not matchs.is_empty()
	if matchs.is_empty(): return
	multiplex_precision.text = "%d′" % minute if not matchs.all(func(m: Variant): return m is Dictionary and bool(m.get("fini", false))) else "terminé"
	# Une seule rangée, quel que soit le nombre de matchs : ce qui dépasse la largeur défile.
	# Variantes : trois cartes par rangée, tout le multiplex à l'écran sans défiler.
	multiplex_cartes.columns = colonnes_multiplex(matchs.size(), _colonnes_multiplex)
	for m: Variant in matchs:
		if not m is Dictionary: continue
		var id := str(m.get("id", ""))
		var change: bool = _scores_prec.has(id) and _scores_prec[id] != scores[id]
		var carte := _carte_match_v2(m, _scores_prec.get(id, scores[id]) if change else scores[id], teintes)
		carte.name = "MatchBetweenMultiplexMatch%d" % multiplex_cartes.get_child_count()
		multiplex_cartes.add_child(carte)
	_largeur_multiplex()
	_largeur_multiplex.call_deferred()

## Colonnes du multiplex : `voulues` par rangée, trois rangées au plus (au-delà, la rangée s'allonge et défile en largeur).
static func colonnes_multiplex(matchs: int, voulues: int) -> int:
	return maxi(1, maxi(mini(voulues, matchs), ceili(matchs / 3.0)))

## Largeur du multiplex : la colonne de droite (le défilement prend la largeur du panneau) ; au-delà, les
## cartes défilent et « › » le signale.
func _largeur_multiplex() -> void:
	if not is_instance_valid(multiplex_defile) or not is_instance_valid(multiplex_cartes): return
	if not is_zero_approx(multiplex_defile.custom_minimum_size.x): multiplex_defile.custom_minimum_size.x = 0
	multiplex_defile.custom_minimum_size.y = multiplex_cartes.get_combined_minimum_size().y
	_fondu_multiplex()
## Fondu du bord droit du multiplex et « › » : seulement quand la rangée dépasse et qu'il reste des cartes
## à droite (rien quand tout tient, rien une fois au bout de la rangée).
func _fondu_multiplex() -> void:
	if not is_instance_valid(multiplex_fondu) or not is_instance_valid(multiplex_defile) or not is_instance_valid(multiplex_cartes): return
	multiplex_fondu.visible = multiplex_deborde() and float(multiplex_defile.scroll_horizontal) + multiplex_defile.size.x < multiplex_cartes.size.x - 1.0

## Vrai quand la rangée de cartes du multiplex est plus large que sa zone de défilement.
func multiplex_deborde() -> bool:
	return is_instance_valid(multiplex_defile) and is_instance_valid(multiplex_cartes) and multiplex_cartes.size.x > multiplex_defile.size.x + 1.0

func _carte_match(m: Dictionary, change: bool, teintes: Dictionary) -> Control:
	var carte := PanelContainer.new()
	carte.name = "MatchBetweenMultiplexMatch"
	carte.set_meta("id", str(m.get("id", "")))
	carte.set_meta("change", change)
	var style := _case(RELIEF, Charte.RAYON_CARTE)
	style.content_margin_left = px(8)
	style.content_margin_right = px(8)
	style.content_margin_top = px(4)
	style.content_margin_bottom = px(4)
	if change:
		# Score qui vient de changer : filet gauche épais (jamais un cadre complet), le mot est dans l'infobulle.
		style.border_width_left = maxi(2, px(5))
		style.border_color = VERT_SCORE
	carte.add_theme_stylebox_override("panel", style)
	carte.custom_minimum_size.x = px(160)
	var fini := bool(m.get("fini", false))
	var cotes: Array = [m.get("home", {}), m.get("away", {})]
	carte.tooltip_text = "%s %d – %d %s · %s" % [str(cotes[0].get("nom", "")), int(cotes[0].get("score", 0)), int(cotes[1].get("score", 0)), str(cotes[1].get("nom", "")), "terminé" if fini else "%d′" % int(m.get("minute", 0))]
	var rang := S.G.h(px(8))
	rang.add_theme_constant_override("separation", px(8))
	carte.add_child(rang)
	var lignes := S.G.v(0)
	lignes.add_theme_constant_override("separation", 0)
	S.G.fill(lignes)
	rang.add_child(lignes)
	var meneur := -1
	if int(cotes[0].get("score", 0)) != int(cotes[1].get("score", 0)): meneur = 0 if int(cotes[0].get("score", 0)) > int(cotes[1].get("score", 0)) else 1
	for cote in 2:
		var club: Dictionary = cotes[cote] if cotes[cote] is Dictionary else {}
		var ligne := S.G.h(px(6))
		ligne.add_theme_constant_override("separation", px(6))
		ligne.name = "Domicile" if cote == 0 else "Exterieur"
		lignes.add_child(ligne)
		var pastille := Pastille.new()
		pastille.teinte = teintes.get(_cle_club(club.get("id")), FAIBLE)
		pastille.custom_minimum_size = Vector2(px(14), px(14))
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(pastille)
		var sigle := str(club.get("abbr", ""))
		var nom_club := _cellule(sigle if not sigle.is_empty() else str(club.get("nom", "")), 0, IVOIRE if meneur == cote or meneur < 0 else DOUX, 26)
		nom_club.name = "Club"
		nom_club.custom_minimum_size.x = px(60)
		ligne.add_child(nom_club)
		var essais := int(club.get("essais", 0))
		var petit := _cellule("(%d)" % essais if essais > 0 else "", 32, FAIBLE, 20, true)
		petit.name = "Essais"
		petit.tooltip_text = "%d essai%s" % [essais, "s" if essais > 1 else ""]
		ligne.add_child(petit)
		var score := _cellule(str(int(club.get("score", 0))), 32, IVOIRE if meneur == cote or meneur < 0 else DOUX, 26, true)
		score.name = "Score"
		ligne.add_child(score)
		petit.mouse_filter = Control.MOUSE_FILTER_PASS
		# Chaque club de la carte mène à sa fiche ; son sigle s'éclaire et se fléche au survol.
		_cliquable_club(ligne, club.get("id"))
		if ligne.has_meta("club_id"):
			ligne.tooltip_text = "%s · clic : sa fiche (le match se met en pause)." % str(club.get("nom", sigle))
			var repos := nom_club.get_theme_color("font_color")
			var texte_club := nom_club.text
			var eclairer := func(dedans: bool):
				nom_club.add_theme_color_override("font_color", IVOIRE if dedans else repos)
				nom_club.text = texte_club + (" →" if dedans else "")
			ligne.mouse_entered.connect(eclairer.bind(true))
			ligne.mouse_exited.connect(eclairer.bind(false))
			ligne.focus_entered.connect(eclairer.bind(true))
			ligne.focus_exited.connect(eclairer.bind(false))
	var heure := _texte("Terminé" if fini else "%d′" % int(m.get("minute", 0)), 22, FAIBLE if fini else OR, false, true)
	heure.name = "Minute"
	heure.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heure.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heure.custom_minimum_size.x = px(40)
	rang.add_child(heure)
	return carte

## Échantillon du moteur (`direct.echantillon`) : court tant que le jeu montré n'atteint pas le
## seuil (dix minutes). Sans l'information (ancienne projection), l'échantillon est jugé suffisant.
static func est_court(direct: Dictionary) -> bool:
	var echantillon: Variant = direct.get("echantillon")
	return echantillon is Dictionary and not bool(echantillon.get("suffisant", true))

static func seuil_echantillon(direct: Dictionary) -> int:
	var echantillon: Variant = direct.get("echantillon")
	return int(echantillon.get("seuil", 10)) if echantillon is Dictionary else 10

## Mon XV (maquette, colonne Plaquages empruntée à la variante 2) : numéro, nom, énergie (jauge et valeur),
## plaquages réussis, note du match ; une ligne sur deux zébrée. La ligne (clic, ou ↑ ↓ puis Entrée) ouvre la
## fenêtre Équipe sur ce joueur ; le nom ouvre sa fiche (survol : mini-fiche). Alertes écrites (« épuisé »).
func _remplir_xv(joueurs: Array, direct: Dictionary) -> void:
	_xv_donnees = [joueurs, direct]
	_montrer_journee_direct()
	# Cartes de Mon XV mises à jour EN PLACE (vérificateur du 24/11 : recréées à chaque minute, survol perdu).
	if vue_xv != "adverse" and not joueurs.is_empty() and _maj_tuiles_xv(joueurs, direct): return
	S.clear(xv)
	# D : Mon XV en tuiles, trois par rangée ; le XV adverse reste un tableau.
	xv.columns = 5 if vue_xv == "adverse" else 15
	xv.add_theme_constant_override("h_separation", 0 if vue_xv == "adverse" else px(14))
	xv.add_theme_constant_override("v_separation", 0 if vue_xv == "adverse" else px(14))
	if is_instance_valid(pied_xv): S.clear(pied_xv)
	var infos := _infos_xv(joueurs, direct)
	_remplir_changement(infos)
	# Vue adverse : les alertes de Mon XV restent calculées pour Gabi.
	if vue_xv == "adverse":
		_alertes_seules(joueurs, direct)
		_remplir_xv_adverse(direct)
		return
	alertes_xv.clear()
	if joueurs.is_empty():
		xv.add_child(_texte("Composition indisponible.", 19, DOUX, true))
		return
	var ordre := ordre_xv(joueurs, infos, tri_xv, tri_inverse)
	for rang_ligne in ordre.size():
		var poste: int = ordre[rang_ligne]
		var joueur: Variant = joueurs[poste]
		var info: Dictionary = infos[poste]
		if joueur is Dictionary:
			var tuile := _tuile_joueur(poste, joueur, info)
			if not str(info.alerte).is_empty(): alertes_xv.append({"poste": poste, "id": str(info.id), "nom": str(joueur.get("name", "")), "alerte": str(info.alerte), "condition": float(info.energie)})
			xv.add_child(tuile)
			continue
		var case := _ligne_joueur("MatchBetweenPlayer%d" % (poste + 1), rang_ligne, func(): joueur_choisi.emit(poste))
		var ligne: HBoxContainer = case.get_child(0)
		ligne.add_child(_cellule(str(poste + 1), int(COLONNES_XV[0][1]), DOUX, 19, true))
		if not joueur is Dictionary:
			ligne.add_child(_cellule("Poste vacant", 0, FAIBLE))
			case.tooltip_text = "%d · poste vacant" % (poste + 1)
			xv.add_child(case)
			continue
		var id := str(info.id)
		var condition: float = info.energie
		var alerte: String = info.alerte
		ligne.add_child(_nom_joueur(str(joueur.get("name", "")), id, alerte, Pilotage.etat_joueur(_pilotage, id)))
		var energie := S.G.h(px(6))
		energie.custom_minimum_size.x = px(int(COLONNES_XV[2][1]))
		energie.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var jauge := Jauge.new()
		jauge.valeur = condition
		jauge.vive = true
		jauge.densite = _densite
		jauge.custom_minimum_size = Vector2(px(80), px(20))
		jauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		S.G.fill(jauge)
		energie.add_child(jauge)
		var critique := condition < EPUISE
		var teinte_valeur: Color = Jauge.teinte_vive(condition)
		var valeur := _cellule(("! " if critique else "") + "%d %%" % roundi(condition), 74, teinte_valeur, 19, true)
		energie.add_child(valeur)
		ligne.add_child(energie)
		ligne.add_child(_cellule(str(int(info.get("plaquages", 0))), int(COLONNES_XV[3][1]), IVOIRE, 19, true))
		ligne.add_child(_cellule(("%.1f" % float(info.note)).replace(".", ","), int(COLONNES_XV[4][1]), _teinte_note(float(info.note)), 19, true))
		if not alerte.is_empty(): alertes_xv.append({"poste": poste, "id": id, "nom": str(joueur.get("name", "")), "alerte": alerte, "condition": condition})
		if alerte in ["épuisé", "blessé"]: _marquer_ligne(case)
		case.set_meta("player_id", id)
		case.tooltip_text = str(info.detail)
		xv.add_child(case)
	_ligne_equipe(direct.get("feuille", {}) if direct.get("feuille") is Dictionary else {}, int(direct.get("camp", -1)), joueurs.map(func(j: Variant) -> String: return str(j.get("id", "")) if j is Dictionary else ""))
	# Les tuiles gardent toujours leur hauteur (la zone ne défile pas) : jamais écrasées par le reste de la page.
	_tenir_xv.call_deferred()

## Mon XV en tuiles déjà posées pour les mêmes joueurs : chaque carte garde son nœud (survol, focus), seul son contenu
## change, et seulement quand ses chiffres changent ; le nom (lien survolable) reste tant qu'il ne change pas. Renvoie
## false s'il faut tout reposer (changement de joueur, poste vacant, autre vue).
func _maj_tuiles_xv(joueurs: Array, direct: Dictionary) -> bool:
	if xv.columns != 15 or xv.get_child_count() != joueurs.size(): return false
	var infos := _infos_xv(joueurs, direct)
	var cases := {}
	for poste in joueurs.size():
		var joueur: Variant = joueurs[poste]
		var case := xv.get_node_or_null("MatchBetweenPlayer%d" % (poste + 1)) as Button
		if not joueur is Dictionary or case == null or case.is_queued_for_deletion() or not case.has_meta("tuile_xv") or str(case.get_meta("player_id", "")) != str(infos[poste].id): return false
		cases[poste] = case
	if is_instance_valid(pied_xv): S.clear(pied_xv)
	_remplir_changement(infos)
	alertes_xv.clear()
	var ordre := ordre_xv(joueurs, infos, tri_xv, tri_inverse)
	for rang_ligne in ordre.size():
		var poste: int = ordre[rang_ligne]
		var joueur: Dictionary = joueurs[poste]
		var info: Dictionary = infos[poste]
		var case: Button = cases[poste]
		if not str(info.alerte).is_empty(): alertes_xv.append({"poste": poste, "id": str(info.id), "nom": str(joueur.get("name", "")), "alerte": str(info.alerte), "condition": float(info.energie)})
		xv.move_child(case, rang_ligne)
		var badge: Array = MenuJoueur.texte_badge(_live_courant(), str(info.id))
		var cle := JSON.stringify([joueur.get("name", ""), info, _numero(str(info.id), poste + 1), badge, moral_joueur(_pilotage, str(info.id)), _densite])
		if str(case.get_meta("cle_carte", "")) == cle: continue
		case.set_meta("cle_carte", cle)
		var grave := str(info.alerte) in ["épuisé", "blessé"]
		var fond := _case(Charte.VOILE_DORE if grave else RELIEF, Charte.RAYON_CARTE)
		fond.set_content_margin_all(0)
		case.add_theme_stylebox_override("normal", fond)
		case.add_theme_stylebox_override("disabled", fond)
		if grave: case.set_meta("signale", true)
		elif case.has_meta("signale"): case.remove_meta("signale")
		var ancien := case.get_node_or_null("MatchBetweenCardBody") as Control
		if ancien != null: ancien.name = "MatchBetweenCardBodyOld"
		var neuf := _remplir_carte_haute(case, poste, joueur, info)
		if ancien != null:
			# Le contenu neuf prend la place de l'ancien, morceau par morceau ; le nom (lien survolable) reste s'il est le même.
			var k := 0
			while neuf.get_child_count() > 0:
				var morceau := neuf.get_child(0)
				var vieux := ancien.get_child(k) if k < ancien.get_child_count() else null
				neuf.remove_child(morceau)
				if vieux != null and k == 1 and str(vieux.get_meta("nom_carte", "")) == str(morceau.get_meta("nom_carte", "-")):
					morceau.queue_free()
				else:
					if vieux != null:
						ancien.remove_child(vieux)
						vieux.queue_free()
					ancien.add_child(morceau)
					ancien.move_child(morceau, k)
				k += 1
			case.remove_child(neuf)
			neuf.queue_free()
			ancien.name = "MatchBetweenCardBody"
		var vieux_badge := case.find_child("MatchMenuJoueurAttenteBadge", false, false)
		if vieux_badge != null and str(case.get_meta("badge", "")) != str(badge[0]):
			case.remove_child(vieux_badge)
			vieux_badge.queue_free()
		case.set_meta("badge", str(badge[0]))
		if not str(badge[0]).is_empty(): MenuJoueur.badge_attente(case, str(badge[0]), str(badge[1]))
	_ligne_equipe(direct.get("feuille", {}) if direct.get("feuille") is Dictionary else {}, int(direct.get("camp", -1)), joueurs.map(func(j: Variant) -> String: return str(j.get("id", "")) if j is Dictionary else ""))
	_tenir_xv.call_deferred()
	return true

## Ligne de tableau (24 px à 1920) : bouton plat, filet entre les lignes (pas de bandes), survol `PANNEAU_2`,
## focus `PANNEAU_3` rayon 6 avec l'anneau doré ; son contenu est une rangée de cellules.
func _ligne_joueur(nom: String, _rang: int, action: Callable) -> Button:
	var case := Button.new()
	case.name = nom
	case.flat = true
	case.focus_mode = Control.FOCUS_ALL
	case.set_meta("contextual_enabled", true)
	case.pressed.connect(action)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0, 0, 0, 0)
	fond.border_color = TRAIT
	fond.border_width_bottom = 1
	var survol := _case(RELIEF)
	var focus := _case(SURVOL)
	_anneau(focus)
	for style: StyleBox in [fond, survol, focus]: style.set_content_margin_all(0)
	case.add_theme_stylebox_override("normal", fond)
	case.add_theme_stylebox_override("pressed", survol)
	case.add_theme_stylebox_override("hover", survol)
	case.add_theme_stylebox_override("focus", focus)
	case.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	S.G.fill(case)
	case.custom_minimum_size.y = maxi(18, px(32))
	var ligne := S.G.h(px(8))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(ligne)
	ligne.offset_left = px(6)
	ligne.offset_right = -px(6)
	case.add_child(ligne)
	return case

## Ligne signalée (épuisé, blessé) : attention de la charte, voile doré en case rayon 6 ; le mot (« épuisé »)
## et le chiffre sont écrits dans la ligne (la couleur ne porte jamais seule l'alerte).
func _marquer_ligne(case: Button) -> void:
	case.set_meta("signale", true)
	var style := _case(Charte.VOILE_DORE)
	style.set_content_margin_all(0)
	case.add_theme_stylebox_override("normal", style)

## Nom du joueur : lien vers sa fiche (clic), mini-fiche au survol ; l'alerte écrite à côté (« épuisé »).
func _nom_joueur(nom: String, id: String, alerte: String = "", humeur: Dictionary = {}) -> Control:
	# Cadre sans taille minimale : la colonne Joueur garde sa largeur, quelle que soit la longueur du nom (un nom trop
	# long s'arrête au bord de la colonne, il reste entier dans la mini-fiche et la fiche).
	var cadre := Control.new()
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.clip_contents = true
	S.G.fill(cadre, true)
	var rangee := S.G.h(px(6))
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(rangee)
	cadre.add_child(rangee)
	var lien := Button.new()
	lien.name = "MatchBetweenPlayerName_" + id.validate_node_name()
	lien.text = nom
	lien.flat = true
	lien.focus_mode = Control.FOCUS_NONE
	C.style_bouton_lien(lien)
	lien.add_theme_font_override("font", Charte.texte_moyen())
	lien.add_theme_font_size_override("font_size", fpx(19))
	for etat_bouton in ["normal", "hover", "pressed", "focus"]:
		var style := lien.get_theme_stylebox(etat_bouton) as StyleBoxFlat
		if style != null:
			style.content_margin_left = 0
			style.content_margin_top = 0
			style.content_margin_bottom = 0
	lien.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lien.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lien.set_meta("player_id", id)
	lien.pressed.connect(func(): ouvrir_fiche(id))
	var app: Object = _app()
	if app is Control and not id.is_empty(): CarteSurvol.lier(app, lien, id, "squad", func(): return _direct_carte(id))
	rangee.add_child(lien)
	if not alerte.is_empty():
		var mot := _texte(alerte, 18, ALERTE if alerte in ["épuisé", "blessé", "exclu"] or alerte.begins_with("carton") else Charte.ATTRIBUT_40)
		mot.name = "MatchBetweenPlayerAlert"
		mot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rangee.add_child(mot)
	if not humeur.is_empty(): rangee.add_child(_etiquette_etat(humeur, fpx(17), false))
	# Nom trop long pour sa colonne : coupé avec « … » (entier dans l'infobulle accessible, la mini-fiche et la fiche).
	cadre.resized.connect(func(): _ajuster_nom(lien, nom, cadre, rangee))
	return cadre

## « Darren DOWNES » → « D. DOWNES » : les mots qui ne sont pas tout en capitales (prénoms) deviennent des initiales.
static func abreger_prenom(nom: String) -> String:
	var mots := nom.strip_edges().split(" ", false)
	if mots.size() < 2: return nom
	var famille_debut := mots.size() - 1
	for k in mots.size():
		if mots[k] == mots[k].to_upper() and mots[k].to_lower() != mots[k]:
			famille_debut = k
			break
	if famille_debut == 0: return nom
	var sortie: Array[String] = []
	for k in mots.size(): sortie.append(mots[k].substr(0, 1) + "." if k < famille_debut else mots[k])
	return " ".join(PackedStringArray(sortie))

## Raccourcit le nom affiché avec « … » pour qu'il tienne dans son cadre, à côté des mots qui le suivent.
func _ajuster_nom(lien: Button, nom: String, cadre: Control, rangee: HBoxContainer) -> void:
	if not is_instance_valid(lien) or cadre.size.x <= 1.0: return
	var separation := float(rangee.get_theme_constant("separation"))
	var alerte := rangee.find_child("MatchBetweenPlayerAlert", false, false) as Label
	var autres := 0.0
	for enfant: Node in rangee.get_children():
		if enfant != lien and enfant != alerte and enfant is Control and (enfant as Control).visible: autres += (enfant as Control).get_combined_minimum_size().x + separation
	var police: Font = lien.get_theme_font("font")
	if not lien.has_meta("taille_base"): lien.set_meta("taille_base", lien.get_theme_font_size("font_size"))
	var taille := int(lien.get_meta("taille_base"))
	if lien.get_theme_font_size("font_size") != taille: lien.add_theme_font_size_override("font_size", taille)
	var style := lien.get_theme_stylebox("normal")
	var marges := style.get_minimum_size().x if style != null else 0.0
	var largeur_alerte := 0.0
	if alerte != null:
		if not alerte.has_meta("texte_complet"): alerte.set_meta("texte_complet", alerte.text)
		largeur_alerte = alerte.get_theme_font("font").get_string_size(str(alerte.get_meta("texte_complet")), HORIZONTAL_ALIGNMENT_LEFT, -1, alerte.get_theme_font_size("font_size")).x + separation
	var dispo := cadre.size.x - autres - largeur_alerte - marges - 1.0
	var texte := nom
	var place_alerte := -1.0
	if police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > dispo:
		if alerte != null:
			# Alerte à côté : le prénom passe en initiale (« D. DOWNES », décision de Léo du 20/11). Le nom de famille n'est
			# jamais coupé : si même abrégé il ne tient pas avec l'alerte, c'est l'alerte qui est raccourcie.
			texte = abreger_prenom(nom)
			var largeur_nom := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
			if largeur_nom > dispo: place_alerte = maxf(0.0, cadre.size.x - autres - largeur_nom - marges - separation - 1.0)
		else:
			# Sans alerte : la police baisse jusqu'aux trois quarts pour que le nom tienne en entier.
			var base := taille
			var reduite := base
			while reduite > maxi(12, roundi(base * 0.75)) and police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, reduite).x > dispo: reduite -= 1
			if reduite != taille: lien.add_theme_font_size_override("font_size", reduite)
			if police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, reduite).x > dispo:
				texte = abreger_prenom(nom)
				while texte.length() > 1 and police.get_string_size(texte + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, reduite).x > dispo: texte = texte.substr(0, texte.length() - 1)
				if texte != abreger_prenom(nom): texte = texte.strip_edges() + "…"
	if alerte != null:
		alerte.clip_text = place_alerte >= 0.0
		alerte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if place_alerte >= 0.0 else TextServer.OVERRUN_NO_TRIMMING
		alerte.custom_minimum_size.x = maxf(0.0, place_alerte)
	if lien.text != texte: lien.text = texte
	lien.set_meta("nom_entier", str(lien.get_meta("nom_complet", nom)))

## Données de Notre XV, poste par poste : données du joueur (`W.donnees_joueur`), alerte, infobulle.
## Ordre d'affichage de Mon XV (indices de poste) : par numéro (tri vide), ou par la colonne choisie (« joueur »,
## « energie », « plaquages », « note ») ; sens naturel : nom A→Z, énergie la plus basse d'abord (qui remplacer),
## plaquages et note les plus hauts d'abord ; `inverse` retourne le sens. Égalité : le numéro. Postes vacants en fin.
static func ordre_xv(joueurs: Array, infos: Array, tri: String, inverse: bool) -> Array:
	var ordre: Array = range(joueurs.size())
	if tri.is_empty() or tri == "numero":
		if inverse: ordre.reverse()
		return ordre
	var valeur := func(poste: int) -> Variant:
		var info: Dictionary = infos[poste] if poste < infos.size() and infos[poste] is Dictionary else {}
		match tri:
			"joueur": return str(joueurs[poste].get("name", "")).to_lower() if joueurs[poste] is Dictionary else ""
			"energie": return float(info.get("energie", 0.0))
			"plaquages": return -float(info.get("plaquages", 0))
			"note": return -float(info.get("note", 0.0))
		return poste
	ordre.sort_custom(func(a: int, b: int) -> bool:
		var vacant_a := not joueurs[a] is Dictionary
		var vacant_b := not joueurs[b] is Dictionary
		if vacant_a != vacant_b: return vacant_b
		var va: Variant = valeur.call(a)
		var vb: Variant = valeur.call(b)
		if va == vb: return a < b
		return (va > vb) if inverse else (va < vb))
	return ordre

## Tri de Mon XV choisi par l'en-tête : la même colonne deux fois retourne le sens ; « N° » revient à l'ordre des postes.
func trier_xv(cle: String) -> void:
	if cle == "numero" and tri_xv.is_empty():
		tri_inverse = not tri_inverse
	elif cle == tri_xv: tri_inverse = not tri_inverse
	else:
		tri_xv = "" if cle == "numero" else cle
		tri_inverse = false
	_poser_entete_tri()
	if not _xv_donnees.is_empty(): _remplir_xv(_xv_donnees[0], _xv_donnees[1])
	_appliquer_blocage()

## Flèche du tri courant dans l'en-tête (▲ sens naturel, ▼ inversé) ; la colonne triée en ivoire.
func _poser_entete_tri() -> void:
	var courant := "numero" if tri_xv.is_empty() else tri_xv
	for bouton: Button in entetes_tri:
		var cle := str(bouton.get_meta("tri"))
		# Flèche sur la colonne triée ; l'ordre des postes par défaut n'en porte pas (« N° » tient dans sa colonne).
		var actif := cle == courant and not (cle == "numero" and not tri_inverse)
		bouton.text = str(bouton.get_meta("libelle")) + ((" ▼" if tri_inverse else " ▲") if actif else "")
		for couleur in ["font_color", "font_focus_color"]: bouton.add_theme_color_override(couleur, IVOIRE if actif else DOUX)
		var courant_style := bouton.get_theme_stylebox("normal") as StyleBoxFlat
		if courant_style != null:
			courant_style = courant_style.duplicate()
			courant_style.bg_color = Charte.SELECTION if cle == courant else RELIEF
			bouton.add_theme_stylebox_override("normal", courant_style)

func _infos_xv(joueurs: Array, direct: Dictionary) -> Array:
	var notes: Dictionary = direct.get("notes", {}) if direct.get("notes") is Dictionary else {}
	var feuille: Dictionary = direct.get("feuille", {}) if direct.get("feuille") is Dictionary else {}
	var cartons: Dictionary = {}
	for carton: Variant in direct.get("cartons", []):
		if carton is Dictionary: cartons[str(carton.get("id", ""))] = carton
	var infos: Array = []
	for poste in joueurs.size():
		var joueur: Variant = joueurs[poste]
		if not joueur is Dictionary:
			infos.append({"vacant": true, "alerte": "", "detail": "%d · poste vacant" % (poste + 1)})
			continue
		var d := W.donnees_joueur(joueur, notes, cartons, feuille)
		var id: String = d.id
		var fiche: Dictionary = notes.get(id, {}) if notes.get(id) is Dictionary else {}
		var condition: float = d.energie
		var alerte := ""
		if d.blesse: alerte = "blessé"
		elif cartons.has(id): alerte = "carton jaune, retour %s′" % _minute(cartons[id].get("retour")) if cartons[id].get("retour") != null else "exclu"
		elif condition < EPUISE: alerte = "épuisé"
		elif condition < FATIGUE: alerte = "fatigué"
		var plaq := int(d.get("plaquages", 0))
		var detail := "%d · %s · %s\nÉnergie %d %%, note %.1f (%d action%s du match), %d plaquage%s" % [poste + 1, str(joueur.get("pos", "")), str(joueur.get("name", "")), roundi(condition), float(d.note), int(fiche.get("faits", 0)), "s" if int(fiche.get("faits", 0)) > 1 else "", plaq, "s" if plaq > 1 else ""]
		if not feuille.is_empty(): detail += " (%d manqué%s), %d course%s, %d passe%s" % [int(d.plaquages_manques), "s" if int(d.plaquages_manques) > 1 else "", int(d.courses), "s" if int(d.courses) > 1 else "", int(d.passes), "s" if int(d.passes) > 1 else ""]
		if not alerte.is_empty(): detail += "\n" + alerte.capitalize()
		var humeur := Pilotage.etat_joueur(_pilotage, id)
		if not humeur.is_empty(): detail += "\nAprès la causerie : " + str(humeur.label).to_lower()
		var info := d.duplicate()
		info.merge({"alerte": alerte, "carton": cartons.has(id), "etat": humeur, "detail": detail + "\nClic : l'écran Équipe sur ce joueur ; son nom : sa fiche."}, true)
		infos.append(info)
	return infos

## Carte joueur au survol : l'état du joueur dans ce match (note, énergie, plaquages…), lu à son apparition.
func _direct_carte(id: String) -> Dictionary:
	if _xv_donnees.size() < 2: return {}
	for info: Variant in _infos_xv(_xv_donnees[0], _xv_donnees[1]):
		if info is Dictionary and str(info.get("id", "")) == id: return info
	return {}

## État d'un joueur après la causerie (« Motivé », « Vexé »…) : vert s'il porte, rouge de l'alerte s'il
## pèse, neutre sinon.
func _etiquette_etat(humeur: Dictionary, taille: int, centre: bool) -> Label:
	var etiquette := S.label(str(humeur.get("label", "")), taille, Pilotage.teinte(Pilotage.sens_etat(str(humeur.get("etat", ""))), DOUX))
	etiquette.name = "MatchBetweenPlayerState"
	etiquette.add_theme_font_size_override("font_size", taille)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiquette.clip_text = true
	etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if centre: etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else: etiquette.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return etiquette

## Joueur du XV le plus en difficulté (blessé, sinon l'énergie la plus basse, les joueurs sanctionnés mis à
## part) s'il est blessé ou sous le seuil de fatigue : Gabi propose de le remplacer.
func _remplir_changement(infos: Array) -> void:
	var choisi := -1
	for poste in infos.size():
		var info: Dictionary = infos[poste]
		if info.get("vacant", false) or info.get("carton", false): continue
		if choisi < 0: choisi = poste
		else:
			var actuel: Dictionary = infos[choisi]
			if bool(info.blesse) != bool(actuel.blesse):
				if info.blesse: choisi = poste
			elif float(info.energie) < float(actuel.energie): choisi = poste
	var urgent := choisi >= 0 and (bool(infos[choisi].blesse) or float(infos[choisi].energie) < FATIGUE)
	changement_poste = choisi if urgent else -1

## Banc (`live.reserves`) : numéro (16 et plus), nom (fiche, mini-fiche), poste ; la ligne ouvre la fenêtre
## Équipe. En tête, les changements encore possibles (`live.remplacementsRestants`).
var _banc_cle := ""
func _remplir_banc(live: Dictionary) -> void:
	if not is_instance_valid(banc): return
	var reserves: Array = live.get("reserves", []) if live.get("reserves") is Array else []
	var restants: Variant = live.get("remplacementsRestants", live.get("substitutionsLeft"))
	var cle := JSON.stringify([reserves.map(func(j: Variant): return [j.get("id"), j.get("name"), j.get("pos")] if j is Dictionary else null), restants, _densite, live.get("numeros")])
	if cle == _banc_cle: return
	_banc_cle = cle
	S.clear(banc)
	var nombre := "%d joueur%s" % [reserves.size(), "s" if reserves.size() > 1 else ""]
	precision_banc.text = nombre + ((" · %d changement%s possible%s" % [int(restants), "s" if int(restants) > 1 else "", "s" if int(restants) > 1 else ""]) if restants is int or restants is float else "")
	if reserves.is_empty():
		banc.add_child(_texte("Aucun remplaçant sur la feuille.", 18, DOUX, true))
		return
	for n in reserves.size():
		var joueur: Variant = reserves[n]
		if not joueur is Dictionary: continue
		var id_banc := str(joueur.get("id", ""))
		var case := _ligne_joueur("MatchBetweenBench%d" % (16 + n), floori(n / 2.0), func(): ouvrir_fiche(id_banc))
		case.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var ligne: HBoxContainer = case.get_child(0)
		case.custom_minimum_size.y = maxi(20, px(22))
		var numero := _numero(id_banc, 16 + n)
		ligne.add_child(_cellule(str(numero), 30, DOUX, 19, true))
		var visage := _visage(joueur, px(32), 0, clampf(float(joueur.get("condition", 100)), 0.0, 100.0))
		visage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(visage)
		ligne.add_child(_nom_joueur(str(joueur.get("name", "")), str(joueur.get("id", ""))))
		var poste := _cellule(poste_court(str(joueur.get("pos", ""))), 40, DOUX, 17)
		poste.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ligne.add_child(poste)
		case.tooltip_text = "%d · %s · %s\nClic : l'écran Équipe, pour le faire entrer." % [numero, str(joueur.get("pos", "")), str(joueur.get("name", ""))]
		case.set_meta("player_id", str(joueur.get("id", "")))
		banc.add_child(case)

## Ligne « Équipe » sous un XV : plaquages de toute l'équipe (feuille de statistiques), remplaçants sortis
## compris ; l'écart avec la somme des quinze lignes est le travail des joueurs déjà remplacés (infobulle).
func _ligne_equipe(feuille: Dictionary, camp: int, visibles: Array) -> void:
	var joueurs: Dictionary = feuille.get("joueurs", {}) if feuille.get("joueurs") is Dictionary else {}
	if joueurs.is_empty() or not camp in [0, 1]: return
	var total := {"plaquages": 0, "metres": 0, "essais": 0}
	var sortis := {"plaquages": 0, "metres": 0, "essais": 0}
	for id: String in joueurs:
		var f: Dictionary = joueurs[id]
		if int(f.get("camp", -1)) != camp: continue
		for cle: String in total:
			total[cle] += int(f.get(cle, 0))
			if not visibles.has(id): sortis[cle] += int(f.get(cle, 0))
	var ligne := S.G.h(px(8))
	ligne.custom_minimum_size.y = maxi(16, px(30))
	ligne.name = "MatchBetweenTeamTotal"
	ligne.tooltip_text = "Total de l'équipe, remplaçants sortis compris : %d plaquages, %d m, %d essai%s (%d plaquage%s, %d m, %d essai%s déjà aux joueurs remplacés)." % [total.plaquages, total.metres, total.essais, "s" if total.essais > 1 else "", sortis.plaquages, "s" if sortis.plaquages > 1 else "", sortis.metres, sortis.essais, "s" if sortis.essais > 1 else ""]
	ligne.mouse_filter = Control.MOUSE_FILTER_STOP
	# Total de l'équipe en pastilles chiffre + mot, sous les tuiles.
	var titre := _texte("ÉQUIPE", 16, DOUX, false, true)
	titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(titre)
	for morceau: Array in [[str(total.metres), "m"], [str(total.essais), "essai" + ("s" if total.essais > 1 else "")], [str(total.plaquages), "plaq."]]:
		var pastille := PanelContainer.new()
		var style := _case(RELIEF, Charte.RAYON_PILULE)
		style.content_margin_left = px(12)
		style.content_margin_right = px(12)
		style.content_margin_top = px(1)
		style.content_margin_bottom = px(1)
		pastille.add_theme_stylebox_override("panel", style)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dedans := S.G.h(px(5))
		dedans.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille.add_child(dedans)
		var chiffre := _texte(str(morceau[0]), 18, IVOIRE, false, true)
		chiffre.add_theme_font_override("font", TITRES_EXTRA)
		chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dedans.add_child(chiffre)
		var mot := _texte(str(morceau[1]), 16, DOUX, false, true)
		mot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dedans.add_child(mot)
		ligne.add_child(pastille)
	var marge := MarginContainer.new()
	marge.name = "MatchBetweenTeamTotalMargin"
	marge.mouse_filter = Control.MOUSE_FILTER_PASS
	marge.add_theme_constant_override("margin_left", px(6))
	marge.add_theme_constant_override("margin_right", px(6))
	marge.add_child(ligne)
	pied_xv.add_child(marge)
	_aligner_pied_xv.call_deferred()

## Le pied suit les marges des lignes (6 px) et la place de l'ascenseur quand il est visible : mêmes colonnes.
func _aligner_pied_xv() -> void:
	if not is_instance_valid(pied_xv) or not is_instance_valid(defile_xv): return
	var barre := defile_xv.get_v_scroll_bar()
	var droite := px(6) + (int(barre.size.x) if barre.visible else 0)
	for enfant: Node in pied_xv.get_children():
		if enfant is MarginContainer: (enfant as MarginContainer).add_theme_constant_override("margin_right", droite)

## XV adverse (`direct.adversaire`) : le même tableau ; notes bornées aux faits montrés. Les joueurs adverses
## ne sont pas à nous : leurs noms ne sont pas des liens (aucune fiche du club pour eux).
func _remplir_xv_adverse(direct: Dictionary) -> void:
	var liste: Array = direct.get("adversaire", []) if direct.get("adversaire") is Array else []
	var camp := int(direct.get("camp", -1))
	if liste.is_empty():
		xv.add_child(_texte("Composition adverse pas encore vue.", 19, DOUX, true))
		return
	for poste in liste.size():
		var j: Variant = liste[poste]
		var ligne := S.G.h(px(8))
		ligne.name = "MatchBetweenOpponent%d" % (poste + 1)
		ligne.custom_minimum_size.y = maxi(18, px(32))
		ligne.mouse_filter = Control.MOUSE_FILTER_PASS
		ligne.add_child(_cellule(str(poste + 1), int(COLONNES_XV[0][1]), DOUX, 19, true))
		if not j is Dictionary:
			ligne.add_child(_cellule("Poste vacant", 0, FAIBLE))
			xv.add_child(ligne)
			continue
		var note := float(j.get("note", NOTE_DEPART))
		ligne.add_child(_cellule(str(j.get("nom", "")), 0, DOUX, 19))
		if j.get("energie") != null:
			var energie := S.G.h(px(6))
			energie.custom_minimum_size.x = px(int(COLONNES_XV[2][1]))
			energie.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var jauge := Jauge.new()
			jauge.valeur = float(j.energie)
			jauge.densite = _densite
			jauge.custom_minimum_size = Vector2(px(80), px(20))
			jauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			S.G.fill(jauge)
			energie.add_child(jauge)
			energie.add_child(_cellule("%d %%" % roundi(float(j.energie)), 74, IVOIRE, 19, true))
			ligne.add_child(energie)
		else: ligne.add_child(_cellule("—", int(COLONNES_XV[2][1]), FAIBLE, 19, true))
		ligne.add_child(_cellule(str(int(j.get("plaquages", 0))), int(COLONNES_XV[3][1]), IVOIRE, 19, true))
		ligne.add_child(_cellule(("%.1f" % note).replace(".", ","), int(COLONNES_XV[4][1]), _teinte_note(note), 19, true))
		ligne.tooltip_text = "%d · %s · %s\nNote %.1f (%d action%s montrée%s), %d m, %d essai%s" % [poste + 1, str(j.get("poste", "")), str(j.get("nom", "")), note, int(j.get("faits", 0)), "s" if int(j.get("faits", 0)) > 1 else "", "s" if int(j.get("faits", 0)) > 1 else "", int(j.get("metres", 0)), int(j.get("essais", 0)), "s" if int(j.get("essais", 0)) > 1 else ""]
		xv.add_child(ligne)
	var feuille: Dictionary = direct.get("feuille", {}) if direct.get("feuille") is Dictionary else {}
	_ligne_equipe(feuille, 1 - camp, liste.map(func(j: Variant) -> String: return str(j.get("joueur", "")) if j is Dictionary else ""))

# --- Fiche joueur pendant le match ---------------------------------------------

## Fiche complète d'un de nos joueurs, posée sur l'entracte (la navigation du jeu est fermée pendant un
## match) : « ← Retour au direct » (Échap) la referme, le match reste en pause le temps de la lire.
func ouvrir_fiche(id: String) -> void:
	if fiche_vers.is_valid() and not id.is_empty():
		fiche_vers.call(id)
		return
	var app: Object = _app()
	if not app is Control or id.is_empty(): return
	var trouve: Dictionary = load("res://ui/immersive08/fiche_commune.gd").trouver(app, id, "squad")
	if trouve.is_empty(): return
	MiniFiche.cacher(app)
	var deja := is_instance_valid(fiche_match)
	if deja:
		remove_child(fiche_match)
		fiche_match.queue_free()
	_fiche_id = id
	fiche_match = Control.new()
	fiche_match.name = "MatchBetweenPlayerSheet"
	fiche_match.mouse_filter = Control.MOUSE_FILTER_STOP
	S.full(fiche_match)
	add_child(fiche_match)
	var fond := ColorRect.new()
	fond.color = FOND
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	S.full(fond)
	fiche_match.add_child(fond)
	var colonne := S.G.v(px(12))
	S.full(colonne)
	colonne.offset_left = px(28)
	colonne.offset_right = -px(28)
	colonne.offset_top = px(8)
	colonne.offset_bottom = -px(8)
	fiche_match.add_child(colonne)
	var tete := S.G.h(px(12))
	colonne.add_child(tete)
	var retour := _lien("← Retour au direct", fermer_fiche, "MatchBetweenPlayerSheetBack")
	retour.tooltip_text = "Revenir à l’entracte · Échap"
	tete.add_child(retour)
	tete.add_child(_touche("Échap"))
	var precision := _texte("Le match reste en pause. Pendant un match, la fiche se lit seulement : contrat, note et comparaison reviennent après le coup de sifflet final.", 18, DOUX)
	precision.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(precision)
	var defile := ScrollContainer.new()
	defile.name = "MatchBetweenPlayerSheetScroll"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	S.G.fill(defile, true)
	colonne.add_child(defile)
	var page: Control = load("res://ui/immersive08/player_canvas.gd").build(app, trouve.joueur, "squad")
	defile.add_child(page)
	_brancher_fiche(page, app)
	if not deja: fiche_ouverte.emit(true)
	retour.call_deferred("grab_focus")

## La fiche est faite pour l'écran Effectif : en plein match, son retour revient à l'entracte, ses onglets et
## le joueur précédent / suivant restent dans la fiche ; ce qui mène à un autre écran attend la fin du match.
func _brancher_fiche(page: Control, app: Object) -> void:
	var ids: Array = load("res://ui/immersive08/fiche_commune.gd").liste(app, "squad")
	var rang := ids.find(_fiche_id)
	for noeud: Node in page.find_children("*", "BaseButton", true, false):
		var bouton := noeud as BaseButton
		var nom := str(bouton.name)
		if nom == "PlayerBackToSquad":
			_rebrancher(bouton, fermer_fiche)
			bouton.tooltip_text = "Revenir à l’entracte · Échap"
			if bouton is Button: (bouton as Button).text = "← Retour au direct"
		elif nom.begins_with("FullPlayerTab"):
			var cible := _fiche_id
			bouton.pressed.connect(func(): ouvrir_fiche.call_deferred(cible))
		elif nom in ["FichePrecedent", "FicheSuivant"]:
			var voisin := rang + (-1 if nom == "FichePrecedent" else 1)
			if rang >= 0 and voisin >= 0 and voisin < ids.size():
				var id_voisin := str(ids[voisin])
				_rebrancher(bouton, func(): ouvrir_fiche(id_voisin))
			else: bouton.disabled = true
		elif not bouton.disabled:
			bouton.disabled = true
			bouton.tooltip_text = "Disponible après le match."

static func _rebrancher(bouton: BaseButton, action: Callable) -> void:
	for lien: Dictionary in bouton.pressed.get_connections(): bouton.pressed.disconnect(lien.callable)
	bouton.pressed.connect(action)

func fermer_fiche() -> void:
	if not is_instance_valid(fiche_match): return
	var app: Object = _app()
	if app is Control: MiniFiche.cacher(app)
	remove_child(fiche_match)
	fiche_match.queue_free()
	fiche_match = null
	_fiche_id = ""
	fiche_ouverte.emit(false)

# --- Clavier de l'entracte -------------------------------------------------------

## Espace : reprendre ou mettre en pause ; T : Équipe ; Échap : referme la fiche ou le panneau ouvert à droite,
## sinon laisse la vue du match ouvrir son menu de pause (exception de Léo ; jamais de sortie) ; Entrée : l'action de Gabi ou du panneau d'arrêt. ↑ ↓ et
## Entrée parcourent Mon XV (focus des lignes). Muet quand une fenêtre de la vue (Équipe) couvre l'entracte.
func _input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo or not is_visible_in_tree() or couvert.call(): return
	if touche.ctrl_pressed or touche.alt_pressed or touche.meta_pressed: return
	if is_instance_valid(fiche_match):
		if touche.keycode == KEY_ESCAPE:
			fermer_fiche()
			get_viewport().set_input_as_handled()
		return
	var live: Dictionary = _dernier[1] if _dernier.size() > 1 and _dernier[1] is Dictionary else {}
	var arrete: bool = bool(live.get("paused", false)) or bool(live.get("atBreak", false))
	match touche.keycode:
		KEY_SPACE:
			if bool(live.get("finished", false)): return
			if arrete: reprise_demandee.emit()
			else: pause_demandee.emit()
		KEY_T:
			if is_instance_valid(equipe) and not equipe.disabled: tiroir_demande.emit("Équipe")
		KEY_I:
			# Ligne de Mon XV ou du banc choisie au clavier : I montre ou cache la mini-fiche du joueur.
			var ligne := get_viewport().gui_get_focus_owner()
			if ligne == null or not is_ancestor_of(ligne) or not ligne.has_meta("player_id"): return
			var noms_ligne := ligne.find_children("MatchBetweenPlayerName_*", "Button", true, false)
			var app_i: Object = _app()
			if noms_ligne.is_empty() or not app_i is Control: return
			var ancre: Control = noms_ligne[0]
			if MiniFiche.visible_pour(app_i, ancre): MiniFiche.cacher(app_i, ancre)
			else: MiniFiche.montrer(app_i, str(ligne.get_meta("player_id")), "squad", ancre)
		KEY_ESCAPE:
			# Sans panneau ouvert, Échap revient à la vue du match : son menu (pause et réglages, exception de Léo).
			if vue_droite == "chiffres": return
			montrer_droite("chiffres")
		KEY_ENTER, KEY_KP_ENTER:
			var focus := get_viewport().gui_get_focus_owner()
			if focus is BaseButton and is_ancestor_of(focus): return
			if not _arret.is_empty() and is_instance_valid(arret_reprendre) and not arret_reprendre.disabled: arret_reprendre.pressed.emit()
			else:
				var action := find_child("MatchBetweenReplace", true, false) as Button
				if action != null and not action.disabled: action.pressed.emit()
				else: return
		_: return
	get_viewport().set_input_as_handled()

## Alertes de Mon XV sans le tableau (onglet adverse ouvert) : Gabi les garde.
func _alertes_seules(joueurs: Array, direct: Dictionary) -> void:
	alertes_xv.clear()
	var cartons := {}
	for carton: Variant in direct.get("cartons", []):
		if carton is Dictionary: cartons[str(carton.get("id", ""))] = carton
	for poste in joueurs.size():
		var joueur: Variant = joueurs[poste]
		if not joueur is Dictionary: continue
		var id := str(joueur.get("id", ""))
		var condition := float(joueur.get("condition", 100))
		var alerte := ""
		if int(joueur.get("injury", 0)) > 0: alerte = "blessé"
		elif cartons.has(id): alerte = "carton jaune, retour %s′" % _minute(cartons[id].get("retour")) if cartons[id].get("retour") != null else "exclu"
		elif condition < EPUISE: alerte = "épuisé"
		elif condition < FATIGUE: alerte = "fatigué"
		if not alerte.is_empty(): alertes_xv.append({"poste": poste, "id": id, "nom": str(joueur.get("name", "")), "alerte": alerte, "condition": condition})

## Note de départ du moteur (match-direct.cjs, NOTE_DEPART) : titulaire au coup d'envoi, remplaçant à son entrée.
const NOTE_DEPART := 6.5
## Couleur de la note du match : vert au-dessus de 7, ivoire autour de 6,5, jaune sous 6,5,
## alerte sous 6 (6,5 au coup d'envoi).
## Couleur d'une note de match : le barème unique de la charte (`Charte.couleur_note`).
static func _teinte_note(note: float) -> Color:
	return Charte.couleur_note(note)

## Nom de famille lisible : sans le prénom, tronqué proprement au-delà de 9 lettres.
static func _nom_court(nom: String) -> String:
	var morceaux := nom.strip_edges().split(" ", false)
	if morceaux.is_empty(): return ""
	var famille := " ".join(morceaux.slice(1)) if morceaux.size() > 1 else morceaux[0]
	return famille if famille.length() <= 9 else famille.substr(0, 8) + "."

const PORTRAIT = preload("res://guide/assets/coach-poses.png")
const MATTE = preload("res://guide/coach_matte.gdshader")

## La phrase la plus parlante : la lecture du match si elle existe, sinon la première raison qui
## propose quelque chose (pas « Aucun signal… »), réduite à sa première phrase.
static func _phrase_forte(raisons: Array) -> String:
	var choisie := str(raisons[0])
	for raison: Variant in raisons:
		var texte := str(raison)
		if not muette(texte):
			choisie = texte
			break
	var coupe := choisie.find(". ")
	return choisie.substr(0, coupe + 1) if coupe > 0 else choisie

## Raison du conseiller qui ne propose rien (« Aucun signal… », « Pas assez d’observations… »,
## « Les indicateurs ne justifient pas… ») : Gabi lit alors le match montré, plutôt que de la répéter.
static func muette(raison: String) -> bool:
	return raison.begins_with("Aucun") or raison.begins_with("Pas assez") or raison.begins_with("Les indicateurs ne justifient")

## Une phrase répétée d'une raison à l'autre (« Conservez la consigne en place. ») n'est dite
## qu'une fois, à la dernière raison qui la contient.
static func _sans_redites(raisons: Array) -> Array:
	var dites := {}
	var sortie: Array = []
	for n in range(raisons.size() - 1, -1, -1):
		var gardees: PackedStringArray = []
		for phrase: String in str(raisons[n]).split(". ", false):
			var cle := phrase.strip_edges().trim_suffix(".")
			if cle.is_empty() or dites.has(cle): continue
			dites[cle] = true
			gardees.append(cle)
		if not gardees.is_empty(): sortie.push_front(". ".join(gardees) + ".")
	return sortie

## Gabi : son portrait et une seule phrase forte (l'alerte la plus grave, sinon sa lecture du
## match, sinon sa première raison), le reste en infobulle, et l'action qui va avec.
func _remplir_adjoint(conseil: Variant, live: Dictionary, direct: Dictionary, appliquer: Callable) -> void:
	S.clear(adjoint)
	# Coup de sifflet final : Gabi annonce l'homme du match (note enregistrée, match-notes.cjs).
	var fini: bool = live.get("finished", false)
	var homme: Variant = direct.get("hommeDuMatch")
	var pourquoi: Variant = direct.get("pourquoi")
	adjoint_cadre.visible = not fini or homme is Dictionary or (pourquoi is Dictionary and not (pourquoi.get("raisons", []) as Array).is_empty())
	var carte := S.G.h(px(18))
	adjoint.add_child(carte)
	var portrait := TextureRect.new()
	var image := AtlasTexture.new()
	image.atlas = PORTRAIT
	image.region = Rect2(0, 0, 313.5, 313.5)
	image.filter_clip = true
	portrait.texture = image
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Carte de hauteur bornée (celle du portrait) ; la phrase sur deux lignes au plus (le reste en infobulle).
	portrait.custom_minimum_size = Vector2(px(84), px(84))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var matte := ShaderMaterial.new()
	matte.shader = MATTE
	portrait.material = matte
	carte.add_child(portrait)
	# Liseré droit à la couleur de notre club (liseré permis par la charte), entre le portrait et la parole de Gabi.
	var trait_club := Control.new()
	trait_club.name = "MatchBetweenAdviceStroke"
	trait_club.custom_minimum_size = Vector2(px(22), px(84))
	trait_club.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var teinte_club: Color = Charte.club_trait(terrain.couleurs[clampi(int(direct.get("camp", 0)), 0, 1)]) if terrain != null else IVOIRE
	trait_club.draw.connect(func():
		var h := trait_club.size.y
		trait_club.draw_line(Vector2(trait_club.size.x * 0.5, 0), Vector2(trait_club.size.x * 0.5, h), teinte_club, maxf(2.0, px(4))))
	carte.add_child(trait_club)
	var colonne := S.G.v(px(6))
	S.G.fill(colonne)
	colonne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	carte.add_child(colonne)
	var signature := _texte("GABI, TON ADJOINT", 16, DOUX, false, true)
	signature.name = "MatchBetweenAdviceName"
	colonne.add_child(signature)
	var graves := alertes_xv.filter(func(a: Dictionary): return a.alerte != "fatigué")
	var fatigues := alertes_xv.filter(func(a: Dictionary): return a.alerte == "fatigué")
	var phrases: Array = []
	var remplacer := -1
	if fini and homme is Dictionary:
		var equipes: Array = live.get("teams", [])
		var club := S.G.club_name(equipes[int(homme.get("camp", 0))]) if equipes.size() >= 2 else ""
		var detail := "Homme du match : %s%s, %s." % [str(homme.get("nom", "")), (" (" + club + ")") if not club.is_empty() else "", ("%.1f" % float(homme.get("note", 6.5) if homme.get("note") is float or homme.get("note") is int else 6.5)).replace(".", ",")]
		phrases.append([detail, OR])
		var chiffres: Array = []
		if int(homme.get("essais", 0)) > 0: chiffres.append("%d essai%s" % [int(homme.essais), "s" if int(homme.essais) > 1 else ""])
		if int(homme.get("plaquages", 0)) > 0: chiffres.append("%d plaquages" % int(homme.plaquages))
		if int(homme.get("metres", 0)) > 0: chiffres.append("%d m gagnés" % int(homme.metres))
		if not chiffres.is_empty(): phrases.append([" · ".join(chiffres), IVOIRE])
	for alerte: Dictionary in ([] if fini else (graves + fatigues).slice(0, 1)):
		var texte := "N° %d %s : %s." % [int(alerte.poste) + 1, str(alerte.nom), str(alerte.alerte)]
		if str(alerte.alerte) in ["épuisé", "fatigué"]: texte = "N° %d %s : %d %% d’énergie, à surveiller." % [int(alerte.poste) + 1, str(alerte.nom), roundi(float(alerte.condition))]
		if str(alerte.alerte) == "épuisé": texte = "N° %d %s est à bout (%d %%) : un remplacement s’impose." % [int(alerte.poste) + 1, str(alerte.nom), roundi(float(alerte.condition))]
		if str(alerte.alerte) in ["épuisé", "fatigué", "blessé"]: remplacer = int(alerte.poste)
		phrases.append([texte, IVOIRE, str(alerte.id)])
	var raisons: Array = []
	if conseil is Dictionary:
		for raison in [conseil.get("attackReason", ""), conseil.get("defenceReason", "")]:
			if not str(raison).is_empty(): raisons.append(str(raison))
	var lecture := _lecture(direct)
	if not lecture.is_empty(): raisons.push_front(lecture)
	raisons = _sans_redites(raisons)
	var parlantes := raisons.filter(func(r: String): return not muette(r))
	# Lecture générale sans alerte : ton posé et en retrait (ivoire atténué), l'alerte garde la couleur.
	if phrases.is_empty() and parlantes.is_empty(): phrases.append([_lecture_generale(direct), DOUX])
	if phrases.is_empty() and not raisons.is_empty(): phrases.append([_phrase_forte(raisons), IVOIRE])
	for phrase: Array in phrases:
		var etiquette := _texte("« %s »" % str(phrase[0]), 22, phrase[1], true)
		etiquette.add_theme_font_override("font", Charte.texte_moyen())
		etiquette.max_lines_visible = 4 if phrases.size() == 1 else 2
		etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		etiquette.tooltip_text = "\n".join(raisons) if not raisons.is_empty() else str(phrase[0])
		etiquette.mouse_filter = Control.MOUSE_FILTER_PASS
		# La phrase nomme un de nos joueurs : son nom mène à lui (survol : mini-fiche ; clic : sa fiche).
		if phrase.size() > 2 and not str(phrase[2]).is_empty():
			var id_phrase := str(phrase[2])
			var app_phrase: Object = _app()
			etiquette.name = "MatchBetweenAdvicePlayer"
			etiquette.mouse_filter = Control.MOUSE_FILTER_STOP
			etiquette.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			etiquette.set_meta("player_id", id_phrase)
			etiquette.gui_input.connect(func(evenement: InputEvent):
				var clic := evenement as InputEventMouseButton
				if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT: ouvrir_fiche(id_phrase))
			if app_phrase is Control: MiniFiche.lier(app_phrase, etiquette, id_phrase, "squad")
		colonne.add_child(etiquette)
		# Lignes réservées (un texte à la ligne tronqué n'en réserve qu'une) : la carte garde la hauteur
		# du portrait et la phrase n'est jamais coupée à mi-hauteur.
		etiquette.custom_minimum_size.y = hauteur_lignes(etiquette, etiquette.max_lines_visible)
	# Les actions à droite de la carte (Gabi en largeur, sous le tableau de bord).
	var actions := S.G.h(px(10))
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if fini: _remplir_pourquoi(colonne, direct, actions)
	# D3 : Gabi dans la colonne de gauche, ses actions sous sa phrase.
	adjoint.add_child(actions)
	# L'action qui va avec la phrase : remplacer le joueur signalé, ou appliquer les consignes
	# proposées (seulement si l'adjoint propose autre chose que les consignes en place).
	if remplacer >= 0:
		var poste := remplacer
		# Le remplaçant conseillé par le staff (`live.pilotage.conseilChangement`), s'il vise ce joueur.
		# Avec la file du prochain arrêt, le remplaçant conseillé est dans la bulle de Gabi (pas en double ici).
		var entrant := "" if not MenuJoueur.arrets(live).is_empty() else _entrant_conseille(live, str(alertes_xv.filter(func(a: Dictionary): return int(a.poste) == poste)[0].id) if alertes_xv.any(func(a: Dictionary): return int(a.poste) == poste) else "")
		var libelle := "Remplacer le %d" % (poste + 1) + (" par %s" % _nom_court(entrant) if not entrant.is_empty() else "") + " →"
		var bouton_remplacer := _bouton(libelle, func(): joueur_choisi.emit(poste))
		bouton_remplacer.name = "MatchBetweenReplace"
		bouton_remplacer.tooltip_text = "L'écran Équipe sur ce joueur (le match se met en pause) · Entrée"
		bouton_remplacer.set_meta("contextual_enabled", true)
		actions.add_child(bouton_remplacer)
		actions.add_child(_touche("Entrée"))
	# Match avec file du prochain arrêt de jeu : le plan de jeu conseillé passe par les bulles de Gabi (un clic).
	elif not fini and conseil is Dictionary and (conseil.get("attackChanged", false) or conseil.get("defenceChanged", false)) and MenuJoueur.arrets(live).is_empty():
		var possible: bool = conseil.get("canAct", false) and conseil.get("defenceAvailable", false)
		var bouton := _bouton("Appliquer ses consignes →", func(): appliquer.call(conseil), possible)
		bouton.name = "MatchBetweenApplyAdvice"
		bouton.tooltip_text = "Appliquer les consignes proposées." if possible else "Mets le match en pause pour modifier tes consignes."
		actions.add_child(bouton)
		if not possible:
			# Bloqué : la touche de la pause dessinée (plus de phrase de mode d'emploi, règle du 21/11/2026).
			var raison := _touche("Espace")
			raison.name = "MatchBetweenApplyAdviceReason"
			raison.tooltip_text = "Pause (Espace) pour changer de consignes."
			raison.mouse_filter = Control.MOUSE_FILTER_PASS
			actions.add_child(raison)

## Nom du remplaçant que le staff conseille pour le joueur `sortant` (vide sans conseil ou s'il n'est plus sur le banc).
func _entrant_conseille(live: Dictionary, sortant: String) -> String:
	var conseil: Variant = _pilotage.get("conseilChangement")
	if not conseil is Dictionary or sortant.is_empty() or str(conseil.get("outId", "")) != sortant: return ""
	for joueur: Variant in live.get("reserves", []) if live.get("reserves") is Array else []:
		if joueur is Dictionary and str(joueur.get("id", "")) == str(conseil.get("inId", "")): return str(joueur.get("name", ""))
	return ""

const LEVIER_TEINTES := {"composition": Charte.IVOIRE, "condition": Charte.V, "tactique": Charte.ATTRIBUT_55, "discipline": Charte.ATTRIBUT_40, "preparation": Charte.IVOIRE_2}

## « Pourquoi » au coup de sifflet final (moteur : native/engine/match-pourquoi.cjs, `direct.pourquoi`) :
## trois raisons au plus, classées, chacune avec son levier ; une action par écran concerné.
func _remplir_pourquoi(colonne: VBoxContainer, direct: Dictionary, actions: HBoxContainer) -> void:
	var bloc: Variant = direct.get("pourquoi")
	if not bloc is Dictionary or not bloc.get("raisons") is Array or bloc.raisons.is_empty(): return
	var titre: String = {"victoire": "Pourquoi on a gagné", "defaite": "Pourquoi on a perdu", "nul": "Pourquoi ce nul"}.get(str(bloc.get("issue", "")), "Pourquoi ce résultat")
	var entete := _texte(titre, 22, OR)
	entete.name = "MatchWhyTitle"
	colonne.add_child(entete)
	var routes := {}
	for raison: Variant in bloc.raisons:
		if not raison is Dictionary: continue
		var ligne := S.G.h(px(10))
		ligne.name = "MatchWhy%d" % int(raison.get("rang", 0))
		colonne.add_child(ligne)
		var levier := _texte(str(raison.get("levierLabel", "")).to_upper(), 18, LEVIER_TEINTES.get(str(raison.get("levier", "")), FAIBLE))
		levier.custom_minimum_size.x = px(150)
		levier.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ligne.add_child(levier)
		var texte := _texte(str(raison.get("texte", "")), 22, IVOIRE if raison.get("sens") == "negatif" else Charte.V, true)
		texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texte.max_lines_visible = 2
		texte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		texte.tooltip_text = str(raison.get("texte", ""))
		texte.mouse_filter = Control.MOUSE_FILTER_PASS
		ligne.add_child(texte)
		var route := str(raison.get("route", ""))
		if route.is_empty() or routes.has(route): continue
		routes[route] = true
		var bouton := _bouton(str(raison.get("action", "Voir")) + " →", func(): levier_choisi.emit(route), true)
		bouton.name = "MatchWhyAction_" + str(raison.get("levier", ""))
		bouton.custom_minimum_size.y = px(48)
		bouton.tooltip_text = "Ouvrir l’écran " + route + " (le résultat reste à valider)."
		actions.add_child(bouton)

## Relevés successifs (taille du journal, composition, conseil de l'adjoint) : l'écran montre le
## dernier pris quand le journal s'arrêtait avant la borne du moteur (`direct.borne`).
var _releves: Array = []
func _passe(model: Dictionary, live: Dictionary, direct: Dictionary) -> Dictionary:
	var n: int = live.get("events", []).size()
	var actuel := {"n": n, "lineup": live.get("lineup", []), "conseil": model.get("decisions", {}).get("liveAdvice")}
	if _releves.is_empty() or int(_releves[-1].n) < n: _releves.append(actuel)
	elif int(_releves[-1].n) == n: _releves[-1] = actuel
	else: _releves = [actuel]
	while _releves.size() > 60: _releves.remove_at(0)
	var borne := int(direct.get("borne", n))
	var choisi: Dictionary = {}
	for releve: Dictionary in _releves:
		if int(releve.n) <= borne: choisi = releve
	# Aucun relevé assez ancien : la composition sans alerte nouvelle, pas de conseil.
	if choisi.is_empty(): return {"lineup": _releves[0].lineup, "conseil": null}
	return choisi

## Lecture utile dès la première minute (quand le conseil du moteur n'a encore rien à dire) :
## occupation, possession et score de ce qui a été montré.
func _lecture_generale(direct: Dictionary) -> String:
	var camp := int(direct.get("camp", -1))
	if not camp in [0, 1] or est_court(direct): return "Le match se met en place : je te signale le premier joueur en difficulté."
	var valeurs := {}
	for rang: Variant in direct.get("tableau", []):
		if rang is Dictionary and not rang.get("vide", false): valeurs[str(rang.get("cle", ""))] = rang.get("valeurs", [0, 0])
	var score: Array = direct.get("score", [0, 0]) if direct.get("score") is Array else [0, 0]
	var ecart := int(score[camp]) - int(score[1 - camp]) if score.size() == 2 else 0
	if valeurs.has("occupation"):
		var o := int(valeurs.occupation[camp])
		if o >= SEUIL_LECTURE: return ("On joue dans leur moitié (%d %% d’occupation) : reste patients, les points viendront." % o) if ecart <= 0 else ("On mène et on occupe leur camp (%d %%) : garde cette pression." % o)
		if o <= 100 - SEUIL_LECTURE: return "On joue beaucoup dans notre moitié (%d %% d’occupation) : un dégagement au pied nous ferait du bien." % o
	if valeurs.has("possession"):
		var p := int(valeurs.possession[camp])
		if p >= SEUIL_LECTURE: return "On a le ballon (%d %%) : cherchons maintenant à gagner la ligne d’avantage." % p
		if p <= 100 - SEUIL_LECTURE: return "Ils ont davantage le ballon (%d %%) : une défense qui monte groupée les gênera." % (100 - p)
	if ecart < 0: return "Menés de %d point%s, mais le match reste ouvert : pas de précipitation." % [-ecart, "s" if -ecart > 1 else ""]
	return "Début de match équilibré : j’observe leur organisation et je te signale le premier joueur en difficulté."

## Part (possession, occupation) à partir de laquelle l'adjoint en parle : un écart net, pas 58/42.
const SEUIL_LECTURE := 62

## Une phrase tirée des chiffres du moteur : qui domine depuis cinq minutes, la discipline.
## Rien tant que l'échantillon est court (premières minutes) : l'adjoint ne s'alarme pas d'un départ.
func _lecture(direct: Dictionary) -> String:
	var camp := int(direct.get("camp", -1))
	if not camp in [0, 1] or est_court(direct): return ""
	var minutes: Array = direct.get("domination", {}).get("minutes", []) if direct.get("domination") is Dictionary else []
	if minutes.size() >= 5:
		var somme := 0.0
		for v: Variant in minutes.slice(minutes.size() - 5): somme += float(v)
		var nous := somme / 5.0 * (1.0 if camp == 0 else -1.0)
		if nous <= -35.0: return "Ils nous font reculer depuis cinq minutes : cherchons à sortir de notre camp."
		if nous >= 35.0: return "On domine depuis cinq minutes : à nous de concrétiser cette pression."
	for rang: Variant in direct.get("tableau", []):
		if rang is Dictionary and str(rang.get("cle", "")) == "penalites":
			var v: Array = rang.get("valeurs", [0, 0])
			if int(v[camp]) >= int(v[1 - camp]) + 3: return "Déjà %d pénalités concédées : attention à la discipline." % int(v[camp])
	return ""

## Entracte : la régie annonce encore son compte à rebours ; l'écran ne l'affiche plus.
func montrer_entracte(texte: String, bouton: bool, _force: bool = false) -> void:
	_entracte = [texte, bouton]

func montrer_arret(valeur: Dictionary) -> void:
	_arret = valeur
	_poser_arret_commandes()
	if valeur.is_empty():
		montrer_droite(vue_droite)
		return
	var cle := str(valeur.get("cle", ""))
	if str(_choix_fait.get("cle", "")) != cle: _choix_fait = {}
	arret_titre.text = "%s · %s" % [titre_arret(valeur), str(valeur.get("horloge", ""))]
	var choix: Variant = valeur.get("choix")
	var options: Array = choix.get("options", []) if choix is Dictionary and choix.get("options") is Array else []
	for enfant in arret_options.get_children():
		arret_options.remove_child(enfant)
		enfant.queue_free()
	arret_options.visible = options.size() > 1
	arret_sous_titre.visible = options.size() > 1
	if options.size() <= 1:
		arret_texte.text = str(valeur.get("texte", "")) + "\nLe match est en pause : réorganise ton équipe si besoin, puis reprends."
		_poser_arret_bouton()
		montrer_droite(vue_droite)
		return
	var entrant := str(choix.get("type", "entrant")) != "sortant"
	var staff: Dictionary = options[0]
	for option: Variant in options:
		if option is Dictionary and option.get("actuel", false): staff = option
	var retenu: Variant = _choix_fait.get("id") if not _choix_fait.is_empty() else null
	var focus: Button = null
	for option: Variant in options:
		if not option is Dictionary: continue
		var id: Variant = option.get("id")
		var bouton := Button.new()
		bouton.text = libelle_option(option)
		bouton.name = "MatchBetweenStopOption%d" % arret_options.get_child_count()
		bouton.disabled = retenu != null
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bouton.pressed.connect(_choisir_option.bind(cle, id, str(option.get("nom", "")), entrant))
		bouton.set_meta("contextual_enabled", retenu == null)
		bouton.set_meta("option_id", id)
		_style_option(bouton, false)
		if option == staff: bouton.tooltip_text = "Proposé par le staff."
		# Le nom du joueur proposé : sa mini-fiche au survol (il faut savoir qui entre ou sort).
		var app_arret: Object = _app()
		if app_arret is Control and id != null and not str(id).is_empty():
			MiniFiche.lier(app_arret, bouton, str(id), "squad")
			# « i » à droite de la ligne : la fiche complète (le clic sur la ligne reste le choix).
			var info := _lien("i", ouvrir_fiche.bind(str(id)), "MatchBetweenStopInfo")
			info.tooltip_text = "Sa fiche complète (le choix attend) · survol de la ligne : sa mini-fiche"
			info.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
			info.offset_left = -px(44)
			info.offset_right = -px(8)
			info.offset_top = -px(18)
			info.offset_bottom = px(18)
			info.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			info.set_meta("player_id", str(id))
			bouton.add_child(info)
		var marque := (str(id) == str(retenu)) if retenu != null else bool(option.get("actuel", false))
		if marque: _marquer_option(bouton)
		if option == staff: focus = bouton
		arret_options.add_child(bouton)
	if retenu != null:
		arret_texte.text = str(valeur.get("texte", "")) + "\n" + _phrase_choix(str(_choix_fait.get("nom", "")), entrant)
		focus = arret_reprendre
	else:
		arret_texte.text = str(valeur.get("texte", "")) + "\nLe staff propose %s. Choisis qui %s :" % [_nom_initiale(str(staff.get("nom", ""))), "entre" if entrant else "sort"]
	_poser_arret_bouton()
	montrer_droite(vue_droite)
	# Clavier et manette : le choix du staff a le focus (Entrée le confirme), puis Reprendre.
	if focus != null: focus.call_deferred("grab_focus")

## Bouton du panneau d'arrêt : « Valider le choix » tant que le choix est à faire, puis « Reprendre le match ».
func _poser_arret_bouton() -> void:
	var attente := _choix_en_attente()
	arret_reprendre.text = "VALIDER LE CHOIX" if attente else "REPRENDRE LE MATCH"
	arret_aide.visible = attente
	_poser_arret_commandes()
	var equipe_lien := find_child("MatchBetweenStopTeam", true, false) as Button
	if equipe_lien != null:
		equipe_lien.disabled = attente
		equipe_lien.set_meta("contextual_enabled", not attente)

## Lignes de Mon XV et du banc, « Remplacer le N » : elles ouvrent Équipe, donc attendent elles aussi le choix du
## staff (une décision à la fois), et ne font plus rien une fois le match fini. Bloquées, elles le montrent :
## atténuées, curseur ordinaire, et la raison est écrite (panneau d'arrêt, barre de commandes).
func _appliquer_blocage() -> void:
	var fini := _dernier.size() > 1 and _dernier[1] is Dictionary and bool(_dernier[1].get("finished", false))
	var bloque := _choix_en_attente() or fini
	var lignes: Array = []
	if is_instance_valid(xv): lignes.append_array(xv.get_children().filter(func(n: Node): return n is Button))
	if is_instance_valid(banc): lignes.append_array(banc.get_children().filter(func(n: Node): return n is Button))
	var remplacer := find_child("MatchBetweenReplace", true, false) as Button
	if remplacer != null: lignes.append(remplacer)
	for bouton: Button in lignes:
		bouton.disabled = bloque
		bouton.set_meta("contextual_enabled", not bloque)
		bouton.modulate.a = 0.55 if bloque else 1.0
		bouton.mouse_default_cursor_shape = Control.CURSOR_ARROW if bloque else Control.CURSOR_POINTING_HAND
		if bouton.get_theme_stylebox("disabled") != bouton.get_theme_stylebox("normal") and bouton.name.begins_with("MatchBetween") and bouton != remplacer:
			bouton.add_theme_stylebox_override("disabled", bouton.get_theme_stylebox("normal"))

## Une décision à la fois (fiche UX §6.3) : Équipe et Réglages attendent la fin du choix du staff.
func _poser_arret_commandes() -> void:
	_appliquer_blocage()
	var bloque := _choix_en_attente()
	for bouton: BaseButton in [equipe, parametres]:
		if not is_instance_valid(bouton): continue
		bouton.set_meta("contextual_enabled", not bloque)
		bouton.disabled = bloque
		bouton.tooltip_text = "Après le choix du staff." if bloque else ("Composition, banc, cris de la touche et consignes (le match se met en pause) · T" if bouton == equipe else "Temps forts montrés.")

## Ligne d'option du panneau d'arrêt : texte crème à gauche, case rayon 6 ; survol `PANNEAU_2`, l'option
## retenue sur `SELECTION` (avec sa coche), focus : anneau doré.
func _style_option(bouton: Button, retenue: bool) -> void:
	for etat_bouton in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := _case(Charte.SELECTION if retenue else (RELIEF if etat_bouton in ["hover", "pressed"] else Color(0, 0, 0, 0)))
		if etat_bouton == "focus": _anneau(style)
		style.content_margin_left = px(16)
		style.content_margin_right = px(16)
		style.content_margin_top = px(6)
		style.content_margin_bottom = px(6)
		bouton.add_theme_stylebox_override(etat_bouton, style)
	for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(couleur, IVOIRE)
	bouton.add_theme_color_override("font_disabled_color", IVOIRE if retenue else FAIBLE)
	bouton.add_theme_font_override("font", Charte.texte_moyen())
	bouton.add_theme_font_size_override("font_size", fpx(20))
	bouton.custom_minimum_size.y = maxi(26, px(46))
## Titre du panneau d'arrêt selon le motif projeté par le moteur (`live.direct.arret.raison`).
static func titre_arret(valeur: Dictionary) -> String:
	match str(valeur.get("raison", "carton")):
		"blessure": return "BLESSURE"
		"saignement": return "SAIGNEMENT"
		"hia", "commotion": return "CHOC À LA TÊTE"
		"premiere-ligne": return "PREMIÈRE LIGNE"
	return "CARTON ROUGE" if valeur.get("rouge", false) else "CARTON JAUNE"

## « J. Dupont · Talonneur · 82 % » : nom, poste et énergie du joueur proposé.
static func libelle_option(option: Dictionary) -> String:
	var morceaux: Array[String] = [_nom_initiale(str(option.get("nom", "")))]
	var poste := str(option.get("poste", "")).strip_edges()
	if not poste.is_empty(): morceaux.append(poste.substr(0, 1).to_upper() + poste.substr(1))
	morceaux.append("%d %%" % int(option.get("energie", 0)))
	return " · ".join(morceaux)

static func _nom_initiale(nom: String) -> String:
	var morceaux := nom.strip_edges().split(" ", false)
	if morceaux.size() < 2: return nom.strip_edges()
	return "%s. %s" % [morceaux[0].substr(0, 1), " ".join(morceaux.slice(1))]

static func _phrase_choix(nom: String, entrant: bool) -> String:
	return "Choix enregistré : %s %s." % [_nom_initiale(nom), "entre" if entrant else "sort"]

## Option retenue (choix du staff, puis choix du manager) : filet ivoire et marqueur à gauche.
func _marquer_option(bouton: Button) -> void:
	bouton.set_meta("retenue", true)
	_style_option(bouton, true)
	_cocher(bouton, true)
## L'écran n'a pas de référence au jeu : ses signaux sont branchés par la régie
## (match_temps_forts.gd), qui ne relaie pas ce choix. On remonte donc les parents jusqu'au
## premier nœud qui porte l'application (`app` avec `_command`, la vue du match), ou jusqu'à
## l'application elle-même. Un test peut aussi poser `app_commandes` directement.
var app_commandes: Object = null

func _app() -> Object:
	if app_commandes != null and is_instance_valid(app_commandes): return app_commandes
	var noeud := get_parent()
	while noeud != null:
		var candidat: Variant = noeud.get("app")
		if candidat is Object and is_instance_valid(candidat) and candidat.has_method("_command"): return candidat
		if noeud.has_method("_command"): return noeud
		noeud = noeud.get_parent()
	return null

func _choisir_option(cle: String, id: Variant, nom: String, entrant: bool) -> void:
	if not _choix_fait.is_empty() or cle != str(_arret.get("cle", "")): return
	var app: Object = _app()
	if app == null or not app._command("match_incident_choice", {"cle": cle, "id": id}):
		arret_texte.text = str(_arret.get("texte", "")) + "\nUne décision est déjà en cours : réessaie dans un instant."
		return
	_choix_fait = {"cle": cle, "id": id, "nom": nom}
	montrer_arret(_arret)
	if not _dernier.is_empty(): _poser_phase(_dernier[1])

## Choix devenu impossible côté moteur (`live.incidentChoix` vide sans réponse du manager) :
## le staff garde sa décision, les options se figent.
func _suivre_choix(live: Dictionary) -> void:
	if _arret.is_empty() or not _choix_fait.is_empty() or not _arret.get("choix") is Dictionary: return
	if not live.has("incidentChoix") or live.incidentChoix != null: return
	var cle := str(_arret.get("cle", ""))
	if arret_options.get_child_count() == 0 or (arret_options.get_child(0) as Button).disabled: return
	for bouton: Button in arret_options.get_children(): bouton.disabled = true
	arret_texte.text = str(_arret.get("texte", "")) + "\nLe staff garde sa décision. Reprends quand tu veux."
	_poser_arret_bouton()
	_poser_arret_commandes()
	if cle != "" and arret.visible: arret_reprendre.call_deferred("grab_focus")

# --- Direct en tableau de bord (revue FM27 de Léo, option A choisie le 22/11/2026) --------------------------------
# Les deux XV notés sur deux petits terrains de part et d'autre du direct, chiffres en barres miroir sous le terrain,
# courbe cumulée points / entrées dans les 22 m, phrase de jeu en grand, moral en direct sur Mon XV.

var compos_fm: Array = []
var cumul_fm: Cumul
var barres_fm: VBoxContainer
var phrase_fm: PanelContainer
var phrase_trait_fm: ColorRect
var _compos_cle := ""
var _barres_cle := ""
var _par_cle_fm := {}
const STATS_FM := ["possession", "occupation", "metres", "zone22", "plaquages_reussis", "melees", "touches", "penalites"]
const LIBELLES_FM := {"possession": "Possession", "occupation": "Occupation", "metres": "Mètres", "zone22": "Entrées 22 m",
	"plaquages_reussis": "Plaquages réussis", "melees": "Mêlées gagnées", "touches": "Touches gagnées", "penalites": "Pénalités"}

## Moral en direct d'un de nos joueurs (`live.pilotage.moral[id]` : valeur, départ, cle, label, tendance), {} sinon.
static func moral_joueur(p: Dictionary, id: String) -> Dictionary:
	var tous: Variant = p.get("moral")
	if not tous is Dictionary: return {}
	var m: Variant = (tous as Dictionary).get(id)
	return m if m is Dictionary and not str(m.get("label", "")).is_empty() else {}

## Couleur d'un palier de moral (jetons de la charte : vert gain, bleu moral, orange, rouge perte).
static func teinte_moral(cle: String) -> Color:
	match cle:
		"gonfle": return Charte.NOTE_EXCELLENTE
		"confiant": return Charte.CONDITION
		"inquiet": return Charte.INTENSIF
		"abattu": return Charte.PERTE
	return Charte.MORAL

## Composition d'un club, côté `k` (0 nous, 1 eux), à la place d'une colonne de chiffres miroir.
func _poser_compo_fm(parent: Control, k: int) -> void:
	var cadre := _panneau(parent, px(14))
	var panneau: Control = cadre.get_parent().get_parent()
	panneau.name = "MatchBetweenLineup%d" % k
	panneau.custom_minimum_size.x = px(320)
	S.G.fill(panneau, true, 0.62)
	S.G.fill(cadre, true)
	var tete := S.G.h(px(10))
	tete.name = "MatchBetweenLineupHead%d" % k
	tete.custom_minimum_size.y = px(40)
	cadre.add_child(tete)
	var trait_club := ColorRect.new()
	trait_club.name = "MatchBetweenLineupStripe%d" % k
	trait_club.custom_minimum_size.y = maxi(2, px(4))
	trait_club.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(trait_club)
	var terrain_compo := Compo.new()
	terrain_compo.name = "MatchBetweenLineupPitch%d" % k
	S.G.fill(terrain_compo, true)
	terrain_compo.choisi.connect(_choix_pastille)
	cadre.add_child(terrain_compo)
	compos_fm.append(terrain_compo)

## Phrase de jeu en grand (l'état du jeu quitte l'en-tête du terrain), liseré à la couleur du club en possession.
func _poser_phrase_fm(parent: Control) -> void:
	phrase_fm = PanelContainer.new()
	phrase_fm.name = "MatchBetweenPlayLine"
	var style := liserer(_case(PANNEAU, Charte.RAYON_PANNEAU))
	style.content_margin_left = px(18)
	style.content_margin_right = px(18)
	style.content_margin_top = px(8)
	style.content_margin_bottom = px(8)
	phrase_fm.add_theme_stylebox_override("panel", style)
	parent.add_child(phrase_fm)
	var ligne := S.G.h(px(16))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phrase_fm.add_child(ligne)
	phrase_trait_fm = ColorRect.new()
	phrase_trait_fm.custom_minimum_size = Vector2(px(8), px(44))
	phrase_trait_fm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(phrase_trait_fm)
	etat.get_parent().remove_child(etat)
	ligne.add_child(etat)
	etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etat.add_theme_font_override("font", Charte.TITRE_FICHE)
	etat.add_theme_font_size_override("font_size", fpx(36))
	etat.set_meta("taille_base", fpx(36))
	var droite := Control.new()
	droite.custom_minimum_size.x = px(8)
	droite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(droite)

## Rangée du bas du centre : barres miroir des chiffres et courbe cumulée.
func _poser_bas_fm(rang_bas: Control) -> void:
	var cadre := _panneau(rang_bas, px(14))
	var tuile: Control = cadre.get_parent().get_parent()
	tuile.name = "MatchBetweenMirrorBars"
	S.G.fill(tuile, true)
	S.G.fill(cadre, true)
	cadre.add_child(_titre("Chiffres du match"))
	barres_fm = S.G.v(px(2))
	barres_fm.name = "MatchBetweenMirrorBarsRows"
	S.G.fill(barres_fm, true)
	cadre.add_child(barres_fm)
	var cadre_c := _panneau(rang_bas, px(14))
	var tuile_c: Control = cadre_c.get_parent().get_parent()
	tuile_c.name = "MatchBetweenCumulTile"
	S.G.fill(tuile_c, true)
	S.G.fill(cadre_c, true)
	cadre_c.add_child(_titre("Points et occasions", "cumulés"))
	cumul_fm = Cumul.new()
	cumul_fm.name = "MatchBetweenCumul"
	S.G.fill(cumul_fm, true)
	cumul_fm.choisi.connect(func(): if _par_cle_fm.has("zone22"): stat_demandee.emit((_par_cle_fm["zone22"] as Dictionary).duplicate()))
	cadre_c.add_child(cumul_fm)

## Barres miroir (comme le bilan de mi-temps de la référence) : notre valeur et notre barre à gauche, le libellé au
## milieu, la leur à droite ; la barre du club qui mène ce chiffre est pleine. Une ligne ouvre ce chiffre.
func _remplir_barres_fm(par_cle: Dictionary, nous: int) -> void:
	_par_cle_fm = par_cle
	if not is_instance_valid(barres_fm): return
	var cle_barres := JSON.stringify([par_cle, nous, _teintes_duel(), _densite])
	if cle_barres == _barres_cle: return
	_barres_cle = cle_barres
	S.clear(barres_fm)
	for cle: String in STATS_FM:
		if not par_cle.has(cle): continue
		var rang: Dictionary = par_cle[cle]
		var ligne := Button.new()
		ligne.name = "MatchBetweenMirrorBar_%s" % cle
		ligne.flat = true
		ligne.focus_mode = Control.FOCUS_ALL
		ligne.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for etat_bouton in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = RELIEF if etat_bouton != "normal" else Color(0, 0, 0, 0)
			style.set_corner_radius_all(Charte.RAYON_PETIT)
			if etat_bouton == "focus": _anneau(style)
			ligne.add_theme_stylebox_override(etat_bouton, style)
		var rang_clic := rang.duplicate()
		ligne.pressed.connect(func(): stat_demandee.emit(rang_clic))
		ligne.tooltip_text = str(rang.get("label", ""))
		ligne.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ligne.custom_minimum_size.y = px(22)
		var barre := BarreMiroir.new()
		S.full(barre)
		barre.densite = _densite
		var valeurs: Array = rang.get("valeurs", [0, 0])
		barre.valeurs = [float(valeurs[nous]), float(valeurs[1 - nous])]
		barre.textes = [_valeur(rang, nous), _valeur(rang, 1 - nous)]
		barre.libelle = str(LIBELLES_FM.get(cle, rang.get("label", "")))
		barre.inverse = cle == "penalites"
		barre.vide = bool(rang.get("vide", false))
		barre.teintes = _teintes_duel()
		ligne.add_child(barre)
		barres_fm.add_child(ligne)

## Compositions notées (petits terrains), à chaque image utile.
func _remplir_compos_fm(lineup: Array, direct: Dictionary) -> void:
	if compos_fm.size() != 2: return
	var camp := int(direct.get("camp", -1))
	var nous := camp if camp in [0, 1] else 0
	var infos := _infos_xv(lineup, direct)
	var adverse: Array = direct.get("adversaire", []) if direct.get("adversaire") is Array else []
	var teintes := _teintes_duel()
	var donnees: Array = [[], []]
	for poste in 15:
		var a: Dictionary = infos[poste] if poste < infos.size() and infos[poste] is Dictionary else {"vacant": true}
		donnees[0].append({} if a.get("vacant", false) else {"nom": str(a.get("nom", "")), "note": float(a.get("note", NOTE_DEPART)), "energie": float(a.get("energie", 100)), "id": str(a.get("id", "")), "alerte": str(a.get("alerte", "")), "num": _numero(str(a.get("id", "")), poste + 1)})
		var o: Variant = adverse[poste] if poste < adverse.size() else null
		donnees[1].append({} if not o is Dictionary else {"nom": str(o.get("nom", "")), "note": float(o.get("note", NOTE_DEPART)), "energie": float(o.get("energie")) if o.get("energie") != null else -1.0, "id": "", "alerte": ""})
	for k in 2:
		var cote_club := nous if k == 0 else 1 - nous
		var club: Dictionary = _equipes[cote_club] if cote_club < _equipes.size() and _equipes[cote_club] is Dictionary else {}
		var tete := find_child("MatchBetweenLineupHead%d" % k, true, false) as HBoxContainer
		var trait_club := find_child("MatchBetweenLineupStripe%d" % k, true, false) as ColorRect
		if trait_club != null: trait_club.color = teintes[k]
		if tete == null: continue
		if tete.get_child_count() == 0 and not club.is_empty():
			tete.add_child(_ecusson(club, px(34)))
			var nom := _texte(S.G.club_name(club).to_upper(), 22, IVOIRE, false, true)
			nom.add_theme_font_override("font", Charte.TITRE_FICHE)
			nom.clip_text = true
			nom.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			nom.set_meta("taille_base", nom.get_theme_font_size("font_size"))
			nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			S.G.fill(nom)
			nom.resized.connect(_ajuster_taille.bind(nom))
			tete.add_child(nom)
			var moyenne := PanelContainer.new()
			moyenne.name = "MatchBetweenLineupAverage%d" % k
			moyenne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			moyenne.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tete.add_child(moyenne)
		var somme := 0.0
		var n := 0
		for d: Dictionary in donnees[k]:
			if d.is_empty(): continue
			somme += float(d.note)
			n += 1
		var moy := tete.find_child("MatchBetweenLineupAverage%d" % k, false, false) as PanelContainer
		if moy != null and n > 0:
			S.clear(moy)
			var p := _pastille_note(somme / n)
			moy.add_child(p)
			moy.tooltip_text = "Note moyenne du XV"
	var cle := JSON.stringify([donnees.map(func(c: Array): return c.map(func(d: Dictionary): return [d.get("nom"), d.get("note"), roundi(float(d.get("energie", 0))), d.get("alerte"), d.get("num")])), teintes, _densite, nous])
	if cle == _compos_cle: return
	_compos_cle = cle
	for k in 2:
		var cote := nous if k == 0 else 1 - nous
		var c: Compo = compos_fm[k]
		c.joueurs = donnees[k]
		c.cote = cote
		c.plein = k == 0
		c.teinte = teintes[k]
		c.densite = _densite
		c.queue_redraw()

## Courbe cumulée : points de chaque club en escalier, entrées dans les 22 m en tirets (tranches de 10 min).
func _remplir_cumul_fm(direct: Dictionary) -> void:
	if not is_instance_valid(cumul_fm): return
	cumul_fm.reperes = domination.reperes
	cumul_fm.scores = domination.scores
	cumul_fm.camp = domination.camp
	cumul_fm.teintes = _teintes_duel()
	cumul_fm.densite = _densite
	cumul_fm.minute = domination.minutes.size()
	var periodes: Variant = direct.get("periodes")
	cumul_fm.tranches = (periodes.get("tranches", []) as Array) if periodes is Dictionary and periodes.get("tranches") is Array else []
	cumul_fm.queue_redraw()

## Petit terrain vertical d'une composition : un rond par poste à la couleur du club (plein pour nous, anneau pour
## eux, comme le terrain du direct), numéro dedans, arc d'énergie autour, note au barème à côté, nom dessous.
class Compo extends Control:
	const Charte = preload("res://ui/charte.gd")
	const POLICE = preload("res://ui/immersive08/fonts/BarlowCondensed-Bold.ttf")
	const CHIFFRES = preload("res://ui/immersive08/fonts/BarlowCondensed-ExtraBold.ttf")
	const PLACES := [Vector2(0.24, 0.06), Vector2(0.5, 0.06), Vector2(0.76, 0.06), Vector2(0.36, 0.2), Vector2(0.64, 0.2),
		Vector2(0.12, 0.34), Vector2(0.88, 0.34), Vector2(0.5, 0.36), Vector2(0.3, 0.5), Vector2(0.7, 0.56),
		Vector2(0.1, 0.8), Vector2(0.36, 0.68), Vector2(0.64, 0.74), Vector2(0.9, 0.8), Vector2(0.5, 0.92)]
	signal choisi(cle: String)
	var joueurs: Array = []
	var cote := 0
	var plein := true
	var teinte := Charte.V
	var densite := 0.5
	var _centres: Array = []
	var _rayon := 10.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func _sous(p: Vector2) -> int:
		for n in _centres.size():
			if (_centres[n] as Vector2).distance_to(p) <= _rayon * 1.5: return n
		return -1

	func _gui_input(event: InputEvent) -> void:
		var m := event as InputEventMouseMotion
		if m != null:
			var n := _sous(m.position)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if n >= 0 else Control.CURSOR_ARROW
			tooltip_text = ("%d · %s" % [n + 1, str(joueurs[n].get("nom", ""))]) if n >= 0 and n < joueurs.size() and not (joueurs[n] as Dictionary).is_empty() else ""
			return
		var clic := event as InputEventMouseButton
		if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
			var n := _sous(clic.position)
			if n >= 0:
				choisi.emit("%d:%d" % [cote, n])
				accept_event()

	static func _rect(couleur: Color, rayon: int = 10) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = couleur
		s.set_corner_radius_all(rayon)
		return s

	static func _court(nom: String) -> String:
		var morceaux := nom.strip_edges().split(" ", false)
		return (morceaux[morceaux.size() - 1] if morceaux.size() > 0 else nom).to_upper()

	func _draw() -> void:
		_centres.clear()
		if size.x < 40.0 or size.y < 60.0: return
		# Pelouse du direct, lignes des 22 m, 10 m, médiane et en-but.
		var fond := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		draw_style_box(_rect(Color("2f6b3a"), 10), fond)
		for y in [0.03, 0.27, 0.5, 0.97]:
			draw_line(Vector2(fond.position.x, fond.position.y + fond.size.y * y), Vector2(fond.end.x, fond.position.y + fond.size.y * y), Color(1, 1, 1, 0.3), 1.0)
		var r := clampf(minf(size.x / 16.0, size.y / 31.0), 9.0, 22.0)
		_rayon = r
		var nom_corps := maxi(12, roundi(r * 0.8))
		for n in mini(15, joueurs.size()):
			var place: Vector2 = PLACES[n]
			var c := Vector2(fond.position.x + fond.size.x * (0.1 + 0.8 * place.x), fond.position.y + fond.size.y * (0.04 + 0.84 * place.y) + r)
			_centres.append(c)
			var d: Dictionary = joueurs[n]
			draw_circle(c, r + 2.0, Color(0.04, 0.07, 0.06, 0.8))
			if plein:
				draw_circle(c, r, teinte)
			else:
				draw_circle(c, r, Charte.FOND)
				draw_arc(c, r - 1.5, 0.0, TAU, 28, teinte, maxf(2.0, r * 0.2), true)
			var energie := float(d.get("energie", -1.0)) if not d.is_empty() else -1.0
			if energie >= 0.0:
				var t: Color = Charte.CONDITION if energie >= 75.0 else (Charte.INTENSIF if energie >= 55.0 else Charte.PERTE)
				draw_arc(c, r + 4.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(energie / 100.0, 0.0, 1.0), 32, t, maxf(2.0, r * 0.18), true)
			# Vrai numéro de feuille (un remplaçant entré garde le sien), sinon celui du poste.
			var num := str(int(d.get("num", n + 1))) if not d.is_empty() else str(n + 1)
			var corps := roundi(r * 1.1)
			var encre: Color = (Charte.ENCRE if teinte.get_luminance() > 0.55 else Charte.IVOIRE) if plein else Charte.IVOIRE
			draw_string(CHIFFRES, c + Vector2(-CHIFFRES.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x * 0.5, corps * 0.36), num, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, encre)
			if d.is_empty(): continue
			# Note en pastille au barème, à droite du rond (à gauche contre le bord droit) ; nom dessous.
			var note := float(d.get("note", 6.5))
			var texte := ("%.1f" % note).replace(".", ",")
			var corps_n := maxi(12, roundi(r * 0.9))
			var l := CHIFFRES.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, corps_n).x
			var boite := Rect2(c + Vector2(r + 5.0, -corps_n * 0.55), Vector2(l + 10.0, corps_n * 1.1))
			if boite.end.x > fond.end.x - 2.0: boite.position.x = c.x - r - 5.0 - boite.size.x
			draw_style_box(_rect(Charte.couleur_note(note), 4), boite)
			draw_string(CHIFFRES, Vector2(boite.position.x + 5.0, boite.position.y + corps_n * 0.9), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, corps_n, Charte.encre_note(note))
			var nom := _court(str(d.get("nom", "")))
			var taille := nom_corps
			while taille > 11 and POLICE.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > fond.size.x * 0.3: taille -= 1
			var ln := POLICE.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
			var x := clampf(c.x - ln * 0.5, fond.position.x + 3.0, fond.end.x - ln - 3.0)
			var y := c.y + r + 4.0 + taille * 0.95
			draw_string(POLICE, Vector2(x + 1, y + 1), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(0, 0, 0, 0.7))
			draw_string(POLICE, Vector2(x, y), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Charte.IVOIRE)

## Barre miroir d'un chiffre : valeur et barre de chaque club de part et d'autre du libellé central.
class BarreMiroir extends Control:
	const Charte = preload("res://ui/charte.gd")
	const POLICE = preload("res://ui/immersive08/fonts/BarlowCondensed-Bold.ttf")
	const CHIFFRES = preload("res://ui/immersive08/fonts/BarlowCondensed-ExtraBold.ttf")
	var valeurs: Array = [0.0, 0.0]
	var textes: Array = ["", ""]
	var libelle := ""
	var inverse := false
	var vide := false
	var teintes: Array = [Charte.V, Charte.D]
	var densite := 0.5

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var corps := maxi(13, roundi(24.0 * densite))
		var petit := maxi(12, roundi(19.0 * densite))
		var valeur_l := clampf(size.x * 0.13, 48.0, maxf(56.0, 92.0 * densite))
		var milieu_l := clampf(size.x * 0.3, 100.0, maxf(110.0, 190.0 * densite))
		var barre_l := maxf(10.0, (size.x - 2.0 * valeur_l - milieu_l) * 0.5)
		var h := maxf(6.0, 14.0 * densite)
		var y := size.y * 0.5
		var a := float(valeurs[0])
		var b := float(valeurs[1])
		var total := maxf(0.001, a + b)
		var mene := -1 if vide or is_equal_approx(a, b) else (0 if ((a < b) if inverse else (a > b)) else 1)
		for k in 2:
			var part := 0.0 if vide else clampf((a if k == 0 else b) / total, 0.0, 1.0)
			var fond := Rect2(Vector2(valeur_l if k == 0 else valeur_l + barre_l + milieu_l, y - h * 0.5), Vector2(barre_l, h))
			draw_rect(fond, Color(1, 1, 1, 0.07))
			var plein := Rect2(Vector2(fond.end.x - barre_l * part, fond.position.y) if k == 0 else fond.position, Vector2(barre_l * part, h))
			var t: Color = teintes[k]
			draw_rect(plein, t if mene == k or mene < 0 else Color(t, 0.4))
			var texte := str(textes[k])
			var l := CHIFFRES.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x
			var x := (valeur_l - 8.0 - l) if k == 0 else (size.x - valeur_l + 8.0)
			draw_string(CHIFFRES, Vector2(x, y + corps * 0.36), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, Charte.IVOIRE if mene == k else Charte.IVOIRE_2)
		var taille := petit
		while taille > 11 and POLICE.get_string_size(libelle, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > milieu_l - 8.0: taille -= 1
		var lm := POLICE.get_string_size(libelle, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		draw_string(POLICE, Vector2(valeur_l + barre_l + (milieu_l - lm) * 0.5, y + taille * 0.36), libelle, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Charte.IVOIRE_2)

## Courbe cumulée : score de chaque club en escalier (trait plein), entrées dans les 22 m adverses cumulées par
## tranche de 10 min (tirets et points) ; mi-temps et minute courante ; un clic ouvre les entrées dans les 22 m.
class Cumul extends Control:
	const Charte = preload("res://ui/charte.gd")
	const POLICE = preload("res://ui/immersive08/fonts/BarlowCondensed-Bold.ttf")
	const CHIFFRES = preload("res://ui/immersive08/fonts/BarlowCondensed-ExtraBold.ttf")
	signal choisi
	var reperes: Array = []
	var scores: Dictionary = {}
	var tranches: Array = []
	var camp := -1
	var teintes: Array = [Charte.V, Charte.D]
	var densite := 0.5
	var minute := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = "Entrées dans les 22 m"

	func _gui_input(event: InputEvent) -> void:
		var clic := event as InputEventMouseButton
		if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
			choisi.emit()
			accept_event()

	func _draw() -> void:
		var corps := maxi(13, roundi(24.0 * densite))
		var petit := maxi(12, roundi(17.0 * densite))
		var nous := camp if camp in [0, 1] else 0
		var legende_h := petit * 1.6
		var gauche := maxf(28.0, 40.0 * densite)
		var droite := maxf(36.0, 56.0 * densite)
		var zone := Rect2(Vector2(gauche, legende_h + 8.0), size - Vector2(gauche + droite, legende_h + 8.0 + petit * 1.7))
		if zone.size.x < 40.0 or zone.size.y < 20.0: return
		# Légende : trait plein = points, tirets = entrées dans les 22 m.
		var x0 := zone.position.x
		var ym := legende_h * 0.5
		draw_line(Vector2(x0, ym), Vector2(x0 + 26.0, ym), Charte.IVOIRE, 3.0)
		draw_string(POLICE, Vector2(x0 + 32.0, ym + petit * 0.36), "Points", HORIZONTAL_ALIGNMENT_LEFT, -1, petit, Charte.IVOIRE_2)
		var x1 := x0 + 50.0 + POLICE.get_string_size("Points", HORIZONTAL_ALIGNMENT_LEFT, -1, petit).x
		draw_dashed_line(Vector2(x1, ym), Vector2(x1 + 26.0, ym), Charte.IVOIRE, 2.0, 5.0)
		draw_circle(Vector2(x1 + 13.0, ym), 3.5, Charte.IVOIRE)
		draw_string(POLICE, Vector2(x1 + 32.0, ym + petit * 0.36), "Entrées 22 m", HORIZONTAL_ALIGNMENT_LEFT, -1, petit, Charte.IVOIRE_2)
		var marches: Array = [[0.0, 0, 0]]
		var tries := reperes.duplicate()
		tries.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("minute", 0)) < float(b.get("minute", 0)))
		for repere: Dictionary in tries:
			var marque: Variant = repere.get("score") if repere.get("score") is Array else scores.get(int(repere.get("i", -1)))
			if str(repere.get("kind", "")) == "card" or not marque is Array or (marque as Array).size() != 2: continue
			marches.append([float(repere.get("minute", 0)), int(marque[nous]), int(marque[1 - nous])])
		var entrees: Array = [[Vector2.ZERO], [Vector2.ZERO]]
		var cumul := [0.0, 0.0]
		for t: Variant in tranches:
			if not t is Dictionary or not (t as Dictionary).get("valeurs") is Dictionary: continue
			var v: Variant = (t.valeurs as Dictionary).get("zone22")
			if not v is Array or (v as Array).size() != 2: continue
			for k in 2:
				cumul[k] += float(v[nous if k == 0 else 1 - nous])
				entrees[k].append(Vector2(float(t.get("fin", t.get("a", 0))), cumul[k]))
		var maxi := 10.0
		for m: Array in marches: maxi = maxf(maxi, maxf(float(m[1]), float(m[2])))
		maxi = ceilf(maxf(maxi, maxf(cumul[0], cumul[1])) / 5.0) * 5.0
		var fin := 80.0
		var point := func(m: float, v: float) -> Vector2: return Vector2(zone.position.x + zone.size.x * clampf(m / fin, 0.0, 1.0), zone.end.y - zone.size.y * clampf(v / maxi, 0.0, 1.0))
		for k in 9:
			var x := zone.position.x + zone.size.x * k / 8.0
			draw_line(Vector2(x, zone.position.y), Vector2(x, zone.end.y), Color(Charte.FILET, 1.0 if k == 4 else 0.5), 2.0 if k == 4 else 1.0)
			if k % 2 == 0:
				var e := "%d′" % (k * 10)
				var le := POLICE.get_string_size(e, HORIZONTAL_ALIGNMENT_LEFT, -1, petit).x
				draw_string(POLICE, Vector2(clampf(x - le * 0.5, 0.0, size.x - le), zone.end.y + petit * 1.35), e, HORIZONTAL_ALIGNMENT_LEFT, -1, petit, Charte.IVOIRE_3)
		draw_line(Vector2(zone.position.x, zone.end.y), Vector2(zone.end.x, zone.end.y), Charte.IVOIRE_2, 1.0)
		for v in [maxi * 0.5, maxi]:
			var y: float = (point.call(0.0, v) as Vector2).y
			draw_dashed_line(Vector2(zone.position.x, y), Vector2(zone.end.x, y), Color(Charte.FILET, 0.6), 1.0, 5.0)
			var tv := str(int(v))
			draw_string(POLICE, Vector2(zone.position.x - 6.0 - POLICE.get_string_size(tv, HORIZONTAL_ALIGNMENT_LEFT, -1, petit).x, y + petit * 0.36), tv, HORIZONTAL_ALIGNMENT_LEFT, -1, petit, Charte.IVOIRE_3)
		var maintenant := clampf(float(minute), 0.0, fin)
		var etiquettes: Array = []
		for k in 2:
			var t: Color = teintes[k]
			var serie: Array = entrees[k]
			for n in range(1, serie.size()):
				draw_dashed_line(point.call(serie[n - 1].x, serie[n - 1].y), point.call(serie[n].x, serie[n].y), Color(t, 0.85), maxf(2.0, 3.0 * densite), 7.0)
			for n in range(1, serie.size()): draw_circle(point.call(serie[n].x, serie[n].y), maxf(3.0, 5.0 * densite), t)
			var trace := PackedVector2Array()
			var y_prec: float = (point.call(0.0, 0.0) as Vector2).y
			for m: Array in marches:
				var p: Vector2 = point.call(float(m[0]), float(m[1 + k]))
				trace.append(Vector2(p.x, y_prec))
				trace.append(p)
				y_prec = p.y
			trace.append(Vector2(maxf((point.call(maintenant, 0.0) as Vector2).x, trace[-1].x), y_prec))
			draw_polyline(trace, Color(Charte.FOND, 0.9), maxf(5.0, 8.0 * densite), true)
			draw_polyline(trace, t, maxf(3.0, 5.0 * densite), true)
			etiquettes.append([trace[-1], str(int(marches[-1][1 + k])), t])
		if absf((etiquettes[0][0] as Vector2).y - (etiquettes[1][0] as Vector2).y) < corps:
			var bas := 0 if (etiquettes[0][0] as Vector2).y >= (etiquettes[1][0] as Vector2).y else 1
			etiquettes[bas][0] = (etiquettes[bas][0] as Vector2) + Vector2(0, corps * 0.55)
			etiquettes[1 - bas][0] = (etiquettes[1 - bas][0] as Vector2) - Vector2(0, corps * 0.55)
		for e: Array in etiquettes:
			draw_string(CHIFFRES, (e[0] as Vector2) + Vector2(8.0, corps * 0.36), str(e[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, corps, e[2])
		if minute > 0:
			var xm: float = (point.call(maintenant, 0.0) as Vector2).x
			draw_line(Vector2(xm, zone.position.y), Vector2(xm, zone.end.y), Color(Charte.IVOIRE, 0.7), 2.0)
