extends "res://ui/contextual/match_between_widgets.gd"
## Signaux et état de l'écran intermédiaire du match, widgets du tableau de bord (composition, barres miroir, cumul).

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

## Niveau tenu par la régie (préférence du joueur, reprise comprise) : coché dans Réglages.
var niveau_regie := ""

var _colonnes_multiplex := 0

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

var _defile_ev: ScrollContainer
var _defile_banc: ScrollContainer
var _colonne_gauche: Control
var _page_fm: Control

## D3 : les événements du match montrés (essais, pénalités, drops, cartons de `direct.reperes`), chaque camp de son côté
## autour de la minute : pictogramme cerclé à la couleur du club, auteur, score ; un clic ouvre le journal à ce fait.
var _evenements_cle := ""

## D : les temps forts déjà montrés (essais, pénalités, drops, cartons de `direct.reperes`) en pastilles aux couleurs
## du club, les plus récents ; un clic ouvre le journal du match à ce fait.
var _temps_forts_cle := ""

## Un seul ivoire plein à l'écran : ÉQUIPE d'ordinaire ; pendant un arrêt-décision, le bouton du panneau d'arrêt,
## ÉQUIPE passant au style lien.
var _equipe_pleine := true

## Texte imposé par la régie (liaison entre deux temps forts : l'arrêt de jeu en cours) ; vide : l'état du moteur.
var etat_force := ""

## Survol d'une pastille : la mini-fiche pour un de nos joueurs ; « n° · poste · nom » en infobulle pour un adversaire.
var _ancre_pastille: Control

## Légende des chiffres clés : notre club (carré plein) à gauche, l'adversaire (carré vide) à droite.
var _legende_cle := ""

## Banc (`live.reserves`) : numéro (16 et plus), nom (fiche, mini-fiche), poste ; la ligne ouvre la fenêtre
## Équipe. En tête, les changements encore possibles (`live.remplacementsRestants`).
var _banc_cle := ""

## Relevés successifs (taille du journal, composition, conseil de l'adjoint) : l'écran montre le
## dernier pris quand le journal s'arrêtait avant la borne du moteur (`direct.borne`).
var _releves: Array = []

## L'écran n'a pas de référence au jeu : ses signaux sont branchés par la régie
## (match_temps_forts.gd), qui ne relaie pas ce choix. On remonte donc les parents jusqu'au
## premier nœud qui porte l'application (`app` avec `_command`, la vue du match), ou jusqu'à
## l'application elle-même. Un test peut aussi poser `app_commandes` directement.
var app_commandes: Object = null

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
