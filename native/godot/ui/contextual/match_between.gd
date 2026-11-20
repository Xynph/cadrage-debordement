extends Control
## Écran intermédiaire du match en temps forts (mode de base ; repli CD_MATCH_TEMPS_FORTS=0).
##
## Entre deux temps forts, le match continue sur un terrain vu de dessus (`match_terrain_2d.gd`) :
## trente pastilles numérotées rejouent les faits du moteur pendant que l'horloge défile. Autour,
## un tableau de bord inspiré des écrans « match overview » des jeux de management de football,
## adapté au rugby : domination minute par minute, chiffres clés comparés, fil, Mon XV (note,
## énergie, alertes), regard de l'adjoint et accès direct à la fenêtre Équipe (composition, banc,
## consignes ; choix de Léo du 18/11/2026 : un seul bouton à la place de Tactique et Banc).
## Une seule mise en page (direction artistique, choix de Léo du 19/11/2026 : variante 1 « Terrain au
## centre », panneau d'arrêt de la variante 3, colonne Plaquages de la variante 2 ; design/ux/14-match-
## entracte.md) : Mon XV et le banc à gauche, le terrain 2D au centre, les chiffres clés à droite (la même
## colonne porte le panneau d'arrêt, les réglages, les autres matchs), la domination minute par minute en
## largeur, Gabi, le pied des raccourcis. Les noms ouvrent la fiche (survol : mini-fiche). Il n'affiche que
## la projection `live.direct` du moteur et le modèle : aucun calcul sportif, aucune écriture d'état.
const S = preload("res://ui/contextual/skin.gd")
const T = preload("res://theme.gd")
const Terrain2D = preload("res://ui/contextual/match_terrain_2d.gd")
const W = preload("res://ui/contextual/match_tableau_widgets.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const Pilotage = preload("res://ui/contextual/match_consignes.gd")
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const Meteo = preload("res://ui/contextual/meteo_texte.gd")

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
## Pause demandée depuis l'entracte (Espace, Échap) : commande `pause` du jeu, branchée par la régie.
signal pause_demandee
## Fiche joueur ouverte (vrai) ou refermée (faux) pendant le match : la régie met le match en pause le temps de la lire.
signal fiche_ouverte(ouverte: bool)
## Vrai quand une fenêtre de la vue (Équipe) couvre l'entracte : le clavier de l'entracte se tait. Posé par la régie.
var couvert: Callable = func() -> bool: return false
## Bande de la vue du match (sous le score) qui porte la barre de commandes, la même en 3D et
## pendant l'entracte ; sans elle, la barre reste en haut de l'écran intermédiaire.
var hote_barre: Control

## Libellés courts des stats comparées (le libellé complet en infobulle) : rien de tronqué.
const LIBELLES_COURTS := {"metres": "Mètres gagnés", "franchissements": "Franchis.", "plaquages": "Plaquages",
	"plaquages_manques": "Plaq. manqués", "recuperations": "Récupérations", "melees": "Mêlées gagnées", "touches": "Touches gagnées",
	"penalites": "Pénalités concédées", "en_avant": "En-avant", "pieds": "Jeu au pied", "possession": "Possession", "occupation": "Occupation",
	"zone22": "Entrées dans les 22 m", "plaquages_reussis": "Plaquages réussis"}
## Chiffres clés de l'entracte (maquette : possession, occupation, pénalités, entrées dans les 22, plaquages
## réussis, mêlées et touches gagnées) ; le reste est dans les statistiques complètes (lien, menu Plus).
const STATS := ["possession", "occupation", "penalites", "zone22", "plaquages_reussis", "melees", "touches"]
const FATIGUE := 55
const EPUISE := 40
## Charte unique (ui/charte.gd, humeur « direct ») : habillage opaque noir chaud, panneaux sans ombre ni
## dégradé, ivoire pour l'information. L'or est réservé à Continuer : l'accent de l'écran (OR, historique)
## est l'ivoire ; les couleurs des clubs habillent plaques, pastilles et barres.
const FOND := Charte.FOND
const PANNEAU := Charte.PANNEAU
const RELIEF := Charte.PANNEAU_2
const SURVOL := Charte.PANNEAU_3
const TRAIT := Charte.FILET
const IVOIRE := Charte.IVOIRE
const DOUX := Charte.IVOIRE_2
const FAIBLE := Charte.IVOIRE_3
const OR := Charte.IVOIRE
const ALERTE := Charte.D
const TITRES = preload("res://ui/immersive08/fonts/BarlowCondensed-Bold.ttf")
const TITRES_ITALIQUE = Charte.TITRE_EXTRA_ITALIQUE
const CHIFFRES_GRAS = preload("res://ui/immersive08/fonts/BarlowCondensed-ExtraBold.ttf")
var terrain: Terrain2D
## Ligne d'état du terrain : où est le ballon (« X a le ballon dans le camp adverse »), ou l'arrêt de jeu.
var etat: Label
## Phase du match dans la barre de commandes (« Mi-temps · le match défile en 2D, vitesse Normale »).
var phase: Label
## Sens du jeu, à droite de l'en-tête du terrain (« Alder Fen XV attaque → », texte atténué, pas un lien).
var sens_jeu: Label
var parametres: Button
## Réglages du match (vitesse de l'horloge, temps forts montrés) : panneau de la colonne de droite.
var panneau_parametres: Control
var groupe_horloge: ButtonGroup
var groupe_niveaux: ButtonGroup
var grille_niveaux: GridContainer
var bandeau: PanelContainer
var fil: VBoxContainer
var chiffres: VBoxContainer
var xv: GridContainer
## Banc (remplaçants `live.reserves`) sous les titulaires.
var banc: VBoxContainer
var precision_banc: Label
var titre_xv: Label
var lien_adverse: Button
var adjoint: VBoxContainer
## Bouton « ÉQUIPE » : fenêtre plein écran (composition, banc, cris, consignes), match en pause.
var equipe: Button
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
var _dernier_fait := -1
var _rangs: Array = []
var colonne_droite: VBoxContainer
## Panneau montré dans la colonne de droite : « chiffres », « reglages », « journee », « delegation ».
var vue_droite := "chiffres"
var panneau_chiffres: Control
var panneau_journee: Control
var panneau_delegation: Control
var legende_chiffres: HBoxContainer
var meteo_ligne: Label
var stats_lien: Button
var journee_vide: Label
var pied: HBoxContainer
var pied_reglages: Label
var _fin := {}
## Vue de la colonne Mon XV : « tableau » (Mon XV et le banc) ou « adverse » (le XV adverse, `direct.adversaire`).
var vue_xv := "tableau"
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
	var minutes: Array = []
	var mi_temps: Variant = null
	var reperes: Array = []
	var couleurs: Array[Color] = [Charte.CLUB, Charte.IVOIRE_2]
	var sigles: Array = ["", ""]
	## Noms montrés dans la légende de gauche (nous d'abord).
	var noms: Array = ["", ""]
	## Notre côté (0 ou 1) : il est dessiné au-dessus de l'axe ; -1 : l'équipe qui reçoit au-dessus.
	var camp := -1
	## Score après chaque repère (indice du journal → [a, b]), lu dans `direct.deroule`.
	var scores: Dictionary = {}
	var densite := 0.5

	func _haut() -> int:
		return camp if camp in [0, 1] else 0

	func _draw() -> void:
		var corps := maxi(12, roundi(22.0 * densite))
		var gauche := maxf(110.0, 200.0 * densite)
		var zone := Rect2(Vector2(gauche, corps * 1.6), size - Vector2(gauche + 8.0, corps * 3.2))
		if zone.size.x < 40.0 or zone.size.y < 20.0: return
		var milieu := zone.position.y + zone.size.y * 0.5
		var haut := _haut()
		# Légende de gauche : nous au-dessus (▲), eux dessous (▼), et le sens des barres.
		var nom_haut := str(noms[0]) if not str(noms[0]).is_empty() else str(sigles[haut])
		var nom_bas := str(noms[1]) if not str(noms[1]).is_empty() else str(sigles[1 - haut])
		var tri := corps * 0.55
		draw_colored_polygon(PackedVector2Array([Vector2(tri * 0.5, zone.position.y + corps - tri), Vector2(tri, zone.position.y + corps - tri * 0.1), Vector2(0, zone.position.y + corps - tri * 0.1)]), Charte.IVOIRE)
		draw_string(POLICE, Vector2(tri * 1.6, zone.position.y + corps), nom_haut, HORIZONTAL_ALIGNMENT_LEFT, gauche - 10.0 - tri * 1.6, corps, Charte.IVOIRE)
		draw_string(POLICE, Vector2(0, milieu + corps * 0.35), "+ domine / – subit", HORIZONTAL_ALIGNMENT_LEFT, gauche - 10.0, maxi(12, corps - 3), Charte.IVOIRE_2)
		draw_colored_polygon(PackedVector2Array([Vector2(0, zone.end.y - tri), Vector2(tri, zone.end.y - tri), Vector2(tri * 0.5, zone.end.y - tri * 0.1)]), Charte.IVOIRE)
		draw_string(POLICE, Vector2(tri * 1.6, zone.end.y), nom_bas, HORIZONTAL_ALIGNMENT_LEFT, gauche - 10.0 - tri * 1.6, corps, Charte.IVOIRE)
		# Échelle de 80 minutes (40 avant la mi-temps) : la place d'une minute ne change pas pendant le match.
		var fin := 40 if minutes.size() <= 40 else 80
		fin = maxi(fin, minutes.size())
		var pas := zone.size.x / float(fin)
		for repere in range(0, fin + 1, 10):
			var x := zone.position.x + float(repere) * pas
			draw_line(Vector2(x, zone.position.y), Vector2(x, zone.end.y), Color(Charte.FILET, 0.9), 1.0)
			draw_string(POLICE, Vector2(x + 3.0, zone.end.y + corps * 1.2), "%d′" % repere, HORIZONTAL_ALIGNMENT_LEFT, 60.0, maxi(12, corps - 2), Charte.IVOIRE_2)
		draw_line(Vector2(zone.position.x, milieu), Vector2(zone.end.x, milieu), Charte.IVOIRE_3, 1.0)
		var largeur := maxf(2.0, pas * 0.82)
		var epais := maxf(1.0, densite * 1.5)
		for n in minutes.size():
			var v := clampf(float(minutes[n]) / 100.0, -1.0, 1.0)
			if haut == 1: v = -v
			if absf(v) < 0.01: continue
			var h := absf(v) * zone.size.y * 0.46
			var x := zone.position.x + float(n) * pas + (pas - largeur) * 0.5
			if v > 0.0:
				draw_rect(Rect2(x, milieu - h, largeur, h), couleurs[haut])
			else:
				var vide := Rect2(x + epais * 0.5, milieu + epais * 0.5, largeur - epais, h - epais)
				draw_rect(vide, Charte.club_trait(couleurs[1 - haut]), false, epais)
		# Repères : essais (E), tirs réussis (P), cartons (C), écrits au-dessus pour nous, dessous pour eux.
		for repere: Dictionary in reperes:
			var m := float(repere.get("minute", 0))
			var cote := clampi(int(repere.get("equipe", 0)), 0, 1)
			var x := zone.position.x + clampf((m - 0.5) * pas, 0.0, zone.size.x)
			var kind := str(repere.get("kind", ""))
			var lettre := "E" if kind == "try" else ("C" if kind == "card" else "P")
			var texte := "%s · %s" % [lettre, str(repere.get("horloge", "%d′" % int(m)))]
			var marque: Variant = scores.get(int(repere.get("i", -1)))
			if marque is Array and (marque as Array).size() == 2: texte += "  %d-%d" % [int(marque[haut]), int(marque[1 - haut])]
			var dessus := cote == haut
			var y := zone.position.y - corps * 0.3 if dessus else zone.end.y + corps * 0.05
			var mesure := POLICE.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, corps - 2)).x
			draw_line(Vector2(x, milieu), Vector2(x, zone.position.y if dessus else zone.end.y), Color(Charte.IVOIRE_2, 0.6), 1.0)
			draw_string(POLICE, Vector2(clampf(x - mesure * 0.5, zone.position.x, size.x - mesure), y if dessus else y + corps * 0.0), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, corps - 2), Charte.IVOIRE)
		if mi_temps is int or mi_temps is float:
			var xm := zone.position.x + float(mi_temps) * pas
			draw_line(Vector2(xm, zone.position.y), Vector2(xm, zone.end.y), Charte.IVOIRE_2, maxf(1.0, densite * 2.0))
		if not minutes.is_empty():
			var xc := zone.position.x + minutes.size() * pas
			draw_line(Vector2(xc, zone.position.y), Vector2(xc, zone.end.y), Charte.IVOIRE, maxf(1.0, densite * 2.0))

## Pictogramme d'un fait (fil du match) : essai, tir au but, carton, mêlée, touche, jeu au pied, ballon
## perdu. Pastille sombre cerclée aux couleurs du club, signe ivoire au centre (couleurs de la charte).
class Picto:
	const Charte = preload("res://ui/charte.gd")
	static func dessiner(ci: CanvasItem, c: Vector2, r: float, kind: String, teinte: Color, rouge: bool = false) -> void:
		ci.draw_circle(c, r, Charte.PANNEAU)
		ci.draw_arc(c, r - 0.5, 0.0, TAU, 28, Charte.club_trait(teinte), maxf(1.0, r * 0.12), true)
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
				ci.draw_rect(Rect2(c - Vector2(r * 0.3, r * 0.45), Vector2(r * 0.6, r * 0.9)), Charte.D if rouge else Charte.ATTRIBUT_55)
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

## Barres face à face d'un chiffre clé : notre part pleine à gauche (couleur du club), l'adversaire en barre
## vide à droite (liseré à sa couleur) ; rayon 0, filet de 1 px.
class Barre extends Control:
	const Charte = preload("res://ui/charte.gd")
	## [nous, eux].
	var valeurs: Array = [0, 0]
	var couleurs: Array[Color] = [Charte.CLUB, Charte.IVOIRE_2]
	var densite := 0.5

	func _draw() -> void:
		var a := maxf(0.0, float(valeurs[0]))
		var b := maxf(0.0, float(valeurs[1]))
		var h := maxf(5.0, 12.0 * densite)
		var y := (size.y - h) * 0.5
		draw_rect(Rect2(0, y, size.x, h), Charte.PANNEAU_2)
		if a + b <= 0.0: return
		var part := a / (a + b)
		var jour := maxf(2.0, 4.0 * densite)
		if part > 0.0: draw_rect(Rect2(0, y, maxf(1.0, size.x * part - jour * 0.5), h), couleurs[0])
		if part < 1.0: draw_rect(Rect2(size.x * part + jour * 0.5, y + 0.5, maxf(1.0, size.x * (1.0 - part) - jour * 0.5 - 0.5), h - 1.0), Charte.club_trait(couleurs[1]), false, 1.0)

## Évolution d'un club au classement en direct (`delta` du moteur) : triangle vers le haut s'il gagne des
## places, vers le bas s'il en perd, tiret sinon (la forme porte le sens, la couleur le double).
class Fleche extends Control:
	const Charte = preload("res://ui/charte.gd")
	var delta := 0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.32
		if delta > 0: draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.7), c + Vector2(-r, r * 0.7)]), Charte.V)
		elif delta < 0: draw_colored_polygon(PackedVector2Array([c + Vector2(0, r), c + Vector2(r, -r * 0.7), c + Vector2(-r, -r * 0.7)]), Charte.D)
		else: draw_line(c - Vector2(r * 0.8, 0), c + Vector2(r * 0.8, 0), Charte.IVOIRE_3, maxf(1.0, r * 0.35))

## Pastille ronde aux couleurs d'un club (neutre si la couleur est inconnue).
class Pastille extends Control:
	const Charte = preload("res://ui/charte.gd")
	var teinte := Charte.IVOIRE_3

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, teinte)
		draw_arc(size * 0.5, r - 0.5, 0.0, TAU, 20, Charte.FILET, 1.0, true)

## Jauge d'énergie de Mon XV (maquette : barre fine, repère du seuil de fatigue) : ivoire au repos, orangée
## sous le seuil de fatigue, rouge d'alerte sous celui d'épuisement ; la valeur est écrite à côté.
class Jauge extends Control:
	const Charte = preload("res://ui/charte.gd")
	var valeur := 100.0
	var densite := 0.5

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	static func teinte_pour(v: float) -> Color:
		return Charte.D if v < 40.0 else (Charte.ATTRIBUT_40 if v < 55.0 else Charte.IVOIRE_2)

	func _draw() -> void:
		var h := maxf(3.0, 6.0 * densite)
		var y := (size.y - h) * 0.5
		draw_rect(Rect2(0, y, size.x, h), Charte.PANNEAU_3)
		draw_rect(Rect2(0, y, size.x * clampf(valeur / 100.0, 0.0, 1.0), h), teinte_pour(valeur))
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
func fpx(valeur: float) -> int:
	return maxi(12, px(valeur))

func _texte(texte: String, taille: float, couleur: Color, retour: bool = false, titre: bool = false) -> Label:
	var etiquette := S.wrap(texte, fpx(taille), couleur) if retour else S.label(texte, fpx(taille), couleur)
	etiquette.add_theme_font_size_override("font_size", fpx(taille))
	if titre: etiquette.add_theme_font_override("font", TITRES)
	return etiquette

## Titre de bloc de la charte : capitales grasses en italique (inclinaison 10° de la police), ivoire.
func _titre_bloc(texte: String, taille: float = 24) -> Label:
	var etiquette := _texte(texte.to_upper(), taille, IVOIRE, false, true)
	etiquette.add_theme_font_override("font", TITRES_ITALIQUE)
	return etiquette

## Bouton de l'écran : l'action principale en ivoire plein (un seul par écran), les autres encadrées d'un
## filet ivoire, rayon 0 (charte §7) ; jamais d'or (réservé à Continuer).
func _bouton(texte: String, action: Callable, actif: bool = true, principal: bool = false) -> Button:
	var bouton := S.button(texte, action, actif, principal)
	_habiller(bouton, principal)
	return bouton

func _habiller(bouton: Control, principal: bool = false) -> void:
	if principal:
		C.style_bouton_ivoire_plein(bouton as BaseButton)
	else:
		for etat_bouton in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := StyleBoxFlat.new()
			style.bg_color = RELIEF if etat_bouton in ["hover", "pressed"] else Color(0, 0, 0, 0)
			style.border_color = FAIBLE if etat_bouton == "disabled" else IVOIRE
			style.set_border_width_all(maxi(1, px(2)) if etat_bouton == "focus" else 1)
			style.set_corner_radius_all(0)
			style.content_margin_left = px(22)
			style.content_margin_right = px(22)
			style.content_margin_top = px(6)
			style.content_margin_bottom = px(6)
			bouton.add_theme_stylebox_override(etat_bouton, style)
		for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(couleur, IVOIRE)
		bouton.add_theme_color_override("font_disabled_color", FAIBLE)
		bouton.add_theme_font_override("font", TITRES)
	bouton.add_theme_font_size_override("font_size", fpx(22))
	bouton.custom_minimum_size.y = maxi(26, px(46))

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

## Touche de clavier dessinée (« Espace », « Échap », « T ») : petit cartouche ivoire atténué.
func _touche(texte: String) -> PanelContainer:
	var cadre := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = SURVOL
	style.set_corner_radius_all(0)
	style.content_margin_left = px(8)
	style.content_margin_right = px(8)
	style.content_margin_top = px(1)
	style.content_margin_bottom = px(1)
	cadre.add_theme_stylebox_override("panel", style)
	cadre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var etiquette := _texte(texte, 17, DOUX, false, true)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(etiquette)
	return cadre

## Panneau de la charte : à plat, opaque, sans bordure ni ombre (humeur « direct »).
func _panneau(parent: Node, marge: int, fond: Color = PANNEAU) -> VBoxContainer:
	var coque := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fond, 1.0)
	style.set_corner_radius_all(0)
	coque.add_theme_stylebox_override("panel", style)
	parent.add_child(coque)
	var bord := S.G.margin(marge)
	coque.add_child(bord)
	var colonne := S.G.v(px(10))
	bord.add_child(colonne)
	return colonne

## En-tête de bloc : titre en capitales italiques, précision atténuée à droite.
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
	_bonus_cle = ""
	terrain = ancien if ancien != null else Terrain2D.new()
	terrain.densite = _densite
	terrain.legende = false
	# Pastilles un peu plus petites qu'en plein écran, écartées à l'affichage (numéros lisibles au ruck).
	terrain.taille_pastilles = 0.8
	terrain.custom_minimum_size = Vector2(320, 180)
	_commandes()
	_composants()
	_page()
	_arret_decision()
	montrer_droite(vue_droite)
	if not _arret.is_empty(): montrer_arret(_arret)
	if not terrain.fait_joue.is_connected(_fait_joue): terrain.fait_joue.connect(_fait_joue)

## Barre de commandes : où en est le match (mi-temps, défilement, pause), Équipe (action principale, ivoire
## plein), Réglages (vitesse de l'horloge, temps forts montrés : panneau dans la colonne de droite) et Plus
## (menu déroulant : statistiques, journal, autres matchs, délégation, caméras).
func _commandes() -> void:
	phase = _texte("", 22, DOUX)
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
	equipe.tooltip_text = "Composition, banc, cris de la touche et consignes (le match se met en pause) · T"
	equipe.set_meta("contextual_enabled", true)
	equipe.add_theme_font_override("font", TITRES_ITALIQUE)
	equipe.add_theme_font_size_override("font_size", fpx(24))
	plus = MenuButton.new()
	plus.name = "MatchBetweenMore"
	plus.text = "Plus ▾"
	plus.flat = true
	plus.tooltip_text = "Statistiques complètes, journal du match, autres matchs et classement en direct, confier la fin à l’adjoint, caméras."
	plus.focus_mode = Control.FOCUS_ALL
	plus.set_meta("contextual_enabled", true)
	C.style_bouton_lien(plus)
	plus.add_theme_font_size_override("font_size", fpx(22))
	var menu := plus.get_popup()
	menu.add_theme_font_size_override("font_size", fpx(22))
	for libelle: String in ["Statistiques", "Journal du match", "Confier la fin à l’adjoint", "Autres matchs et classement en direct"]: menu.add_item(libelle)
	# Caméras du direct 3D (la barre du bas est masquée en temps forts).
	menu.add_separator("Caméra des temps forts")
	for paire: Array in [["Vue TV", "tv"], ["Vue de dessus", "tactical"], ["Vue contact", "action"]]:
		menu.add_item(str(paire[0]))
		menu.set_item_metadata(menu.item_count - 1, paire[1])
	menu.about_to_popup.connect(func(): menu.set_item_disabled(3, journee_vue == null))
	menu.id_pressed.connect(func(id: int):
		if id == 0: tiroir_demande.emit("Stats")
		elif id == 1: tiroir_demande.emit("Journal")
		elif id == 2: montrer_droite("delegation")
		elif id == 3: montrer_droite("journee")
		else:
			var index := menu.get_item_index(id)
			if index >= 0 and menu.get_item_metadata(index) is String: camera_demandee.emit(str(menu.get_item_metadata(index))))
	# Réglages : vitesse de l'horloge et temps forts montrés, dans la colonne de droite (jamais une fenêtre).
	parametres = _lien("Réglages", func(): _ouvrir_parametres(), "MatchBetweenSettings")
	parametres.tooltip_text = "Vitesse de l’horloge entre deux temps forts et temps forts montrés."
	parametres.add_theme_font_size_override("font_size", fpx(22))

## Choix unique (segment) : ivoire plein quand il est choisi, encadré sinon.
func _segment(texte: String, groupe: ButtonGroup, choisi: bool) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.toggle_mode = true
	bouton.button_group = groupe
	bouton.button_pressed = choisi
	bouton.custom_minimum_size = Vector2(px(130), maxi(26, px(44)))
	bouton.set_meta("contextual_enabled", true)
	_habiller(bouton)
	var choisi_style := StyleBoxFlat.new()
	choisi_style.bg_color = IVOIRE
	choisi_style.set_corner_radius_all(0)
	choisi_style.content_margin_left = px(22)
	choisi_style.content_margin_right = px(22)
	bouton.add_theme_stylebox_override("pressed", choisi_style)
	bouton.add_theme_color_override("font_pressed_color", Charte.NUIT)
	bouton.add_theme_color_override("font_hover_pressed_color", Charte.NUIT)
	bouton.add_theme_font_size_override("font_size", fpx(20))
	return bouton

func _ouvrir_parametres() -> void:
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
	domination.custom_minimum_size = Vector2(0, px(130))
	domination.tooltip_text = "Qui domine, minute par minute (occupation, possession, points, franchissements) : barres pleines pour nous, vides pour l’adversaire ; essais (E), pénalités (P) et cartons (C) à leur minute."
	domination.mouse_filter = Control.MOUSE_FILTER_PASS
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
	banc = S.G.v(0)
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
	var page := S.G.v(px(16))
	page.name = "MatchBetweenPage"
	S.full(page)
	# Marge basse : le pied des raccourcis ne touche jamais le bord de l'écran.
	page.offset_bottom = -px(8)
	add_child(page)
	var barre: Control
	if is_instance_valid(hote_barre):
		S.clear(hote_barre)
		barre = hote_barre
	else:
		barre = S.G.h(px(12))
		(barre as HBoxContainer).alignment = BoxContainer.ALIGNMENT_END
		page.add_child(barre)
	for noeud: Control in [phase, equipe, _touche("T"), parametres, plus]: barre.add_child(noeud)
	var grille := S.G.h(px(20))
	grille.name = "MatchBetweenTiles"
	S.G.fill(grille, true)
	page.add_child(grille)
	_colonne_xv(grille)
	_colonne_centre(grille)
	_colonne_droite(grille)
	# Domination minute par minute, en largeur.
	var cadre_frise := _panneau(page, px(16))
	cadre_frise.get_parent().get_parent().name = "MatchBetweenMomentumTile"
	titre_domination = _titre("Domination minute par minute", "")
	cadre_frise.add_child(titre_domination)
	cadre_frise.add_child(domination)
	# Gabi en largeur.
	var bas := S.G.h(px(20))
	bas.name = "MatchBetweenBottom"
	page.add_child(bas)
	_carte_gabi(bas)
	S.G.fill(adjoint_cadre)
	_pied(page)

## Pied : les raccourcis de l'écran et où trouver ce qui n'y est pas (vitesse, autres matchs).
func _pied(page: Control) -> void:
	pied = S.G.h(px(10))
	pied.name = "MatchBetweenKeys"
	page.add_child(pied)
	for paire: Array in [["Espace", "Reprendre ou mettre en pause"], ["Échap", "Pause et menu"], ["T", "Équipe"], ["↑ ↓", "Choisir un joueur · Entrée : remplacer"]]:
		pied.add_child(_touche(str(paire[0])))
		var aide := _texte(str(paire[1]), 18, DOUX)
		aide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pied.add_child(aide)
		var ecart := Control.new()
		ecart.custom_minimum_size.x = px(18)
		ecart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pied.add_child(ecart)
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
	tuile_principale.custom_minimum_size.x = px(640)
	cadre_xv.add_theme_constant_override("separation", px(4))
	var tete := S.G.h(px(10))
	cadre_xv.add_child(tete)
	titre_xv = _titre_bloc("Mon XV", 26)
	titre_xv.name = "MatchBetweenSquadTitle"
	S.G.fill(titre_xv)
	tete.add_child(titre_xv)
	lien_adverse = _lien("XV adverse →", func(): choisir_vue_xv("tableau" if vue_xv == "adverse" else "adverse"), "MatchBetweenTabOpponent")
	lien_adverse.tooltip_text = "Voir le XV adverse (notes, énergie, plaquages) ; revenir à Mon XV."
	tete.add_child(lien_adverse)
	var entete := S.G.h(px(8))
	entete.name = "MatchBetweenSquadHeader"
	for colonne: Array in COLONNES_XV:
		entete.add_child(_cellule(str(colonne[0]).to_upper(), int(colonne[1]), DOUX, 16, int(colonne[1]) > 0 and colonne[0] != "Énergie"))
	var defile := ScrollContainer.new()
	defile.name = "MatchBetweenSquadScroll"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	defile.mouse_filter = Control.MOUSE_FILTER_PASS
	S.G.fill(defile, true)
	tableau_xv = S.G.v(0)
	tableau_xv.name = "MatchBetweenTable"
	S.G.fill(tableau_xv)
	cadre_xv.add_child(entete)
	cadre_xv.add_child(defile)
	defile.add_child(tableau_xv)
	tableau_xv.add_child(xv)
	# Banc : numéro, nom, poste ; le nombre de changements restants en tête.
	var tete_banc := S.G.h(px(10))
	tete_banc.name = "MatchBetweenBenchHeader"
	var marge_banc := Control.new()
	marge_banc.custom_minimum_size.y = px(14)
	marge_banc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tableau_xv.add_child(marge_banc)
	var titre_banc := _titre_bloc("Banc", 22)
	S.G.fill(titre_banc)
	tete_banc.add_child(titre_banc)
	precision_banc = _texte("", 18, DOUX)
	precision_banc.name = "MatchBetweenBenchCount"
	tete_banc.add_child(precision_banc)
	tableau_xv.add_child(tete_banc)
	tableau_xv.add_child(banc)
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
	tete.add_child(_titre_bloc("Terrain", 24))
	tete.add_child(etat)
	sens_jeu = _texte("", 18, DOUX)
	sens_jeu.name = "MatchBetweenAttack"
	sens_jeu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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

## Colonne droite : un seul panneau à la fois, à la même place (jamais une fenêtre) — chiffres clés par
## défaut, réglages, autres matchs et classement, confirmation de la délégation, et le panneau d'arrêt.
func _colonne_droite(grille: Control) -> void:
	colonne_droite = S.G.v(px(16))
	colonne_droite.name = "MatchBetweenColumn"
	colonne_droite.custom_minimum_size.x = px(540)
	grille.add_child(colonne_droite)
	# Chiffres clés : duel face à face, lien vers les statistiques, météo, bonus.
	var cadre_chiffres := _panneau(colonne_droite, px(18))
	panneau_chiffres = cadre_chiffres.get_parent().get_parent()
	panneau_chiffres.name = "MatchBetweenDuel"
	S.G.fill(panneau_chiffres, true)
	cadre_chiffres.add_child(_titre_bloc("Chiffres clés", 24))
	# Le contenu défile s'il dépasse (1280×720 avec la tuile Bonus en fin de match) : la page tient toujours.
	var defile_chiffres := ScrollContainer.new()
	defile_chiffres.name = "MatchBetweenFiguresScroll"
	defile_chiffres.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile_chiffres.mouse_filter = Control.MOUSE_FILTER_PASS
	S.G.fill(defile_chiffres, true)
	cadre_chiffres.add_child(defile_chiffres)
	var contenu := S.G.v(px(10))
	contenu.name = "MatchBetweenFiguresContent"
	S.G.fill(contenu)
	defile_chiffres.add_child(contenu)
	cadre_chiffres = contenu
	legende_chiffres = S.G.h(px(8))
	legende_chiffres.name = "MatchBetweenFiguresLegend"
	cadre_chiffres.add_child(legende_chiffres)
	precision_chiffres = _texte("", 17, DOUX)
	precision_chiffres.name = "MatchBetweenFiguresSample"
	precision_chiffres.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cadre_chiffres.add_child(precision_chiffres)
	cadre_chiffres.add_child(chiffres)
	var stats := _lien("Voir les statistiques →", func(): tiroir_demande.emit("Stats"), "MatchBetweenStatsLink")
	stats.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cadre_chiffres.add_child(stats)
	# Météo : déjà sous le score (bandeau de la vue du match) ; ici seulement en infobulle du lien des statistiques.
	meteo_ligne = _texte("", 17, DOUX, true)
	meteo_ligne.name = "MatchBetweenWeather"
	meteo_ligne.visible = false
	cadre_chiffres.add_child(meteo_ligne)
	stats_lien = stats
	# Bonus : la règle du championnat et, en fin de match, le dilemme et ses deux consignes.
	bonus_tuile = PanelContainer.new()
	bonus_tuile.name = "MatchBetweenBonus"
	var style_bonus := StyleBoxFlat.new()
	style_bonus.bg_color = RELIEF
	style_bonus.set_corner_radius_all(0)
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
	cadre_reglages.add_child(_texte("Vitesse de l’horloge entre deux temps forts", 18, DOUX, true))
	var rangee_horloge := GridContainer.new()
	rangee_horloge.columns = 2
	rangee_horloge.add_theme_constant_override("h_separation", px(8))
	rangee_horloge.add_theme_constant_override("v_separation", px(8))
	cadre_reglages.add_child(rangee_horloge)
	groupe_horloge = ButtonGroup.new()
	for n in HORLOGES_IDS.size():
		var choix := _segment(HORLOGES_COURTS[n], groupe_horloge, HORLOGES_IDS[n] == horloge)
		choix.name = "MatchBetweenSpeed%d" % n
		choix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = HORLOGES_IDS[n]
		choix.pressed.connect(func():
			horloge = id
			horloge_choisie.emit(id)
			_poser_pied())
		rangee_horloge.add_child(choix)
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
	classement_lignes = S.G.v(px(2))
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
	multiplex_cartes.add_theme_constant_override("h_separation", px(10))
	multiplex_cartes.add_theme_constant_override("v_separation", px(8))
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
	var style_fondu := StyleBoxFlat.new()
	style_fondu.bg_color = PANNEAU
	style_fondu.set_corner_radius_all(0)
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
	var confirmer := _bouton("Confier la fin à l’adjoint", func():
		montrer_droite("chiffres")
		delegation_demandee.emit())
	confirmer.name = "MatchBetweenHandOverConfirm"
	confirmer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	confirmer.set_meta("contextual_enabled", true)
	cadre_delegation.add_child(confirmer)

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

## Panneau de la colonne de droite : « chiffres », « reglages », « journee », « delegation ». Le panneau
## d'arrêt passe devant tant que le match attend la décision du manager.
func montrer_droite(vue: String) -> void:
	vue_droite = vue if vue in ["chiffres", "reglages", "journee", "delegation"] else "chiffres"
	if not is_instance_valid(panneau_chiffres): return
	var arret_montre := is_instance_valid(arret) and not _arret.is_empty()
	panneau_chiffres.visible = not arret_montre and vue_droite == "chiffres"
	panneau_parametres.visible = not arret_montre and vue_droite == "reglages"
	panneau_journee.visible = not arret_montre and vue_droite == "journee"
	panneau_delegation.visible = not arret_montre and vue_droite == "delegation"
	if is_instance_valid(arret): arret.visible = arret_montre
	if vue_droite == "journee": _largeur_multiplex.call_deferred()

## Vues de la colonne Mon XV : « tableau » (Mon XV et le banc) ou « adverse » (le XV adverse).
func choisir_vue_xv(vue: String) -> void:
	vue_xv = "adverse" if vue == "adverse" else "tableau"
	_montrer_vue_xv()
	if not _xv_donnees.is_empty(): _remplir_xv(_xv_donnees[0], _xv_donnees[1])

func _montrer_vue_xv() -> void:
	if not is_instance_valid(titre_xv): return
	titre_xv.text = ("XV adverse" if vue_xv == "adverse" else "Mon XV").to_upper()
	lien_adverse.text = "← Mon XV" if vue_xv == "adverse" else "XV adverse →"
	for noeud: Node in tableau_xv.get_children():
		if noeud != xv: (noeud as Control).visible = vue_xv != "adverse"

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
	arret_reprendre.add_theme_font_override("font", TITRES_ITALIQUE)
	choix.add_child(arret_reprendre)
	choix.add_child(_touche("Entrée"))
	arret_aide = _texte("Équipe et Réglages reviennent après ce choix.", 17, DOUX, true)
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
	domination.queue_redraw()
	if is_instance_valid(titre_domination) and titre_domination.get_child_count() > 1:
		(titre_domination.get_child(1) as Label).text = "%s · barres pleines : %s · barres vides : %s" % ["1re mi-temps" if dom.get("minutes", []).size() <= 40 else "2e mi-temps", _nom_club(equipes, haut), _nom_club(equipes, 1 - haut)]
	_poser_phase(live)
	_poser_legende(equipes, int(direct.get("camp", -1)))
	meteo_ligne.text = Meteo.bandeau(live)
	if is_instance_valid(stats_lien): stats_lien.tooltip_text = "Toutes les statistiques du match." + ("\n" + meteo_ligne.text if not meteo_ligne.text.is_empty() else "")
	_remplir_banc(live)
	# Conseil de l'adjoint et composition tels qu'ils étaient avant la borne : rien d'un temps fort à venir.
	var passe := _passe(model, live, direct)
	var conseil: Variant = passe.conseil
	var cle := JSON.stringify([direct.get("fil", []), direct.get("tableau", []), direct.get("chiffres", []), conseil, direct.get("notes", {}), direct.get("cartons", []), direct.get("feuille", {}).get("joueurs", {}) if direct.get("feuille") is Dictionary else {},
		passe.lineup, direct.get("statsRows", []), live.get("paused", false), live.get("finished", false), terrain.couleurs, direct.get("pourquoi"), direct.get("hommeDuMatch"), direct.get("zone22"), direct.get("echantillon"), _pilotage.get("joueurs")])
	_suivre_choix(live)
	if cle == _cle: return
	_cle = cle
	_lignes = direct.get("fil", [])
	_fin = {"fini": live.get("finished", false), "score": live.get("score", []), "camp": int(direct.get("camp", -1)),
		"finale": str(model.get("next", {}).get("phase", "") if model.get("next") is Dictionary else "") == "final", "essais": live.get("tries", []),
		"bonus": direct.get("bonus") if direct.get("bonus") is Dictionary else null}
	_remplir_fil()
	_remplir_chiffres(direct, live)
	_remplir_xv(passe.lineup, direct)
	_remplir_adjoint(conseil, live, direct, appliquer)

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
		sens_jeu.text = ("%s attaque %s" % [S.G.club_name(equipes[montre_p]), "→" if montre_p == 0 else "←"]) if montre_p in [0, 1] and equipes.size() >= 2 and equipes[montre_p] is Dictionary else ""

## Minute du moteur écrite sans décimale (« 42 » et non « 42.0 »).
static func _minute(valeur: Variant) -> String:
	return str(roundi(float(valeur))) if valeur is float or valeur is int else str(valeur)

## Nom d'un club du match (vide s'il manque).
static func _nom_club(equipes: Array, cote: int) -> String:
	return S.G.club_name(equipes[cote]) if cote >= 0 and cote < equipes.size() and equipes[cote] is Dictionary else ""

## Phase du match, dans la barre de commandes : mi-temps, pause, défilement 2D et vitesse de l'horloge.
func _poser_phase(live: Dictionary) -> void:
	if not is_instance_valid(phase): return
	var vitesse: String = HORLOGES_COURTS[maxi(0, HORLOGES_IDS.find(horloge))]
	var titre := "Match terminé" if live.get("finished", false) else ("Mi-temps" if live.get("atBreak", false) else ("Arrêt de jeu" if not _arret.is_empty() else ("En pause" if live.get("paused", false) else "%s′" % str(live.get("minute", "")))))
	var suite := "ta décision avant la reprise" if not _arret.is_empty() else ("le match défile en 2D, vitesse %s" % vitesse if not live.get("paused", false) else "le match reprend avec Espace, vitesse %s" % vitesse)
	phase.text = "%s · %s" % [titre, suite]
	_poser_pied()

## Pied : la vitesse de l'horloge (dans Réglages) et où trouver les autres matchs (menu Plus).
func _poser_pied() -> void:
	if not is_instance_valid(pied_reglages): return
	pied_reglages.text = "Vitesse : %s (Réglages) · Autres matchs et classement en direct : Plus ▾" % HORLOGES_COURTS[maxi(0, HORLOGES_IDS.find(horloge))]

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
		var marque := ColorRect.new()
		marque.color = terrain.couleurs[cote] if cote == nous else Color(0, 0, 0, 0)
		marque.custom_minimum_size = Vector2(px(18), px(12))
		marque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		marque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if cote != nous:
			var cadre := Panel.new()
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Charte.club_trait(terrain.couleurs[cote])
			style.set_border_width_all(1)
			style.set_corner_radius_all(0)
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

## Ligne du fil : minute, pictogramme du fait aux couleurs du club, texte (une ligne, le reste en infobulle).
func _ligne_fil(entree: Dictionary, dernier: bool, en_bandeau: bool) -> Control:
	var kind := str(entree.get("kind", ""))
	var points := kind in ["try", "goal", "transformation"]
	var equipe := int(entree.get("equipe", -1)) if entree.get("equipe") != null else -1
	var teinte: Color = terrain.couleurs[equipe] if equipe in [0, 1] else FAIBLE
	var ligne := PanelContainer.new()
	ligne.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	ligne.set_meta("i", int(entree.get("i", -1)))
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	ligne.tooltip_text = str(entree.get("texte", ""))
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
	var texte := _texte(str(entree.get("texte", "")), 19, IVOIRE if points else DOUX, not en_bandeau)
	texte.max_lines_visible = 1
	texte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texte.clip_text = true
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(texte)
	rang.add_child(texte)
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
	var bloc := S.G.v(px(2))
	bloc.name = "MatchBetweenFigure_" + str(rang.get("cle", ""))
	bloc.mouse_filter = Control.MOUSE_FILTER_PASS
	bloc.tooltip_text = "%s : %s %s · %s %s" % [str(rang.get("label", "")), _nom_club(_equipes, nous), _valeur(rang, nous), _nom_club(_equipes, 1 - nous), _valeur(rang, 1 - nous)]
	var titre := _texte(str(LIBELLES_COURTS.get(str(rang.get("cle", "")), rang.get("label", ""))).to_upper(), 15, DOUX, false, true)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(titre)
	var ligne := S.G.h(px(12))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(ligne)
	var a := _texte(_valeur(rang, nous), 26, IVOIRE)
	a.add_theme_font_override("font", TITRES_ITALIQUE)
	a.custom_minimum_size.x = px(84)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(a)
	var barre := Barre.new()
	var valeurs: Array = rang.get("valeurs", [0, 0])
	barre.valeurs = [valeurs[nous], valeurs[1 - nous]] if not rang.get("vide", false) else [0, 0]
	var teintes: Array[Color] = [terrain.couleurs[nous], terrain.couleurs[1 - nous]]
	barre.densite = _densite
	barre.custom_minimum_size = Vector2(px(80), px(24))
	barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(barre)
	ligne.add_child(barre)
	var b := _texte(_valeur(rang, 1 - nous), 26, IVOIRE)
	b.add_theme_font_override("font", TITRES_ITALIQUE)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.custom_minimum_size.x = px(84)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(b)
	parent.add_child(bloc)

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
		precision_chiffres.text = ("Trop tôt pour conclure : lecture fiable dès la %de minute." % seuil_echantillon(direct)) if echantillon_court else ""
		precision_chiffres.visible = echantillon_court
	var camp := int(direct.get("camp", -1))
	var nous := camp if camp in [0, 1] else 0
	var rangs: Array = direct.get("tableau", [])
	var par_cle := {}
	for rang: Variant in rangs:
		if rang is Dictionary: par_cle[str(rang.get("cle", ""))] = rang
	var z: Variant = direct.get("zone22")
	if z is Dictionary and z.get("entrees") is Array and (z.entrees as Array).size() == 2:
		par_cle["zone22"] = {"cle": "zone22", "label": "Entrées dans les 22 mètres adverses", "valeurs": [int(z.entrees[0]), int(z.entrees[1])]}
	if par_cle.has("plaquages") and par_cle.has("plaquages_manques"):
		var reussis: Array = par_cle.plaquages.get("valeurs", [0, 0])
		var manques: Array = par_cle.plaquages_manques.get("valeurs", [0, 0])
		var parts: Array = []
		for cote in 2:
			var tentes := int(reussis[cote]) + int(manques[cote])
			parts.append(roundi(100.0 * int(reussis[cote]) / tentes) if tentes > 0 else 0)
		var vide := int(reussis[0]) + int(manques[0]) == 0 or int(reussis[1]) + int(manques[1]) == 0
		par_cle["plaquages_reussis"] = {"cle": "plaquages_reussis", "label": "Plaquages réussis (part des plaquages tentés)", "valeurs": parts, "unite": "%", "vide": vide}
	# Toujours le même ordre (« — » tant qu'un chiffre est vide).
	for cle: String in STATS:
		if par_cle.has(cle): _ligne_chiffre(chiffres, par_cle[cle], nous)
	_rangs = rangs

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
		# Consigne en place : marquée par le mot et le filet épais (jamais un second bouton ivoire plein).
		var bouton := _bouton(str(c.get("label", "")) + ("  · en place" if en_place else ""), func(): consigne_bonus.emit(c), not live.get("finished", false))
		bouton.name = "MatchBetweenBonusChoice_" + str(c.get("id", ""))
		if en_place:
			var marque := (bouton.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
			marque.set_border_width_all(maxi(2, px(3)))
			marque.bg_color = SURVOL
			bouton.add_theme_stylebox_override("normal", marque)
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
		return
	var teintes := _teintes_clubs(model, equipes)
	_remplir_classement(journee.get("classement", []) if journee.get("classement") is Array else [], teintes)
	_remplir_multiplex(journee, teintes)
	journee_vide.visible = not classement_tuile.visible and not multiplex.visible

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

func _remplir_classement(classement: Array, teintes: Dictionary) -> void:
	S.clear(classement_lignes)
	classement_tuile.visible = not classement.is_empty()
	if classement.is_empty(): return
	# Notre voisinage (± 3 places) ; en 1280×720, ± 2 places : la colonne de droite tient dans l'écran.
	for k: int in lignes_classement(classement, CLASSEMENT_LIGNES if _densite >= 0.6 else CLASSEMENT_ECRAN):
		if k < 0:
			var ellipse := _texte("…", 22, FAIBLE)
			ellipse.name = "MatchBetweenLiveTableGap"
			ellipse.custom_minimum_size.y = px(22)
			ellipse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			classement_lignes.add_child(ellipse)
			continue
		if classement[k] is Dictionary: classement_lignes.add_child(_ligne_classement(classement[k], teintes))

## Ligne du classement : rang, évolution, pastille du club, sigle et nom, badges de bonus, points.
## Notre club surligné (fond or, liseré or).
func _ligne_classement(r: Dictionary, teintes: Dictionary) -> Control:
	var nous := bool(r.get("nous", false))
	var ligne := PanelContainer.new()
	ligne.name = "MatchBetweenLiveRow%d" % int(r.get("rang", 0))
	ligne.set_meta("rang", int(r.get("rang", 0)))
	ligne.set_meta("nous", nous)
	var fond := S.G.T.box(Color(OR, 0.16) if nous else RELIEF if int(r.get("rang", 0)) % 2 == 1 else Color(0, 0, 0, 0), 0)
	fond.content_margin_left = px(8)
	fond.content_margin_right = px(10)
	fond.content_margin_top = 0
	fond.content_margin_bottom = 0
	if nous:
		fond.border_width_left = maxi(2, px(5))
		fond.border_color = OR
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
		var style := S.G.T.box(Color(VERT_SCORE, 0.18) if badge[1] == "BO" else Color(OR, 0.16), 0)
		style.content_margin_left = px(6)
		style.content_margin_right = px(6)
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		pastille_bonus.add_theme_stylebox_override("panel", style)
		pastille_bonus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pastille_bonus.tooltip_text = "%d %s%s" % [nombre, badge[2], "s" if nombre > 1 else ""]
		pastille_bonus.mouse_filter = Control.MOUSE_FILTER_PASS
		var texte := _texte(str(badge[1]), 20, VERT_SCORE.lightened(0.2) if badge[1] == "BO" else OR, false, true)
		texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille_bonus.add_child(texte)
		rang.add_child(pastille_bonus)
	var points := _cellule(str(int(r.get("points", 0))), 44, OR if nous else IVOIRE, 26, true)
	points.name = "Points"
	rang.add_child(points)
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
	multiplex_cartes.columns = maxi(1, matchs.size())
	for m: Variant in matchs:
		if not m is Dictionary: continue
		var id := str(m.get("id", ""))
		var change: bool = _scores_prec.has(id) and _scores_prec[id] != scores[id]
		var carte := _carte_match(m, change, teintes)
		carte.name = "MatchBetweenMultiplexMatch%d" % multiplex_cartes.get_child_count()
		multiplex_cartes.add_child(carte)
	_largeur_multiplex()
	_largeur_multiplex.call_deferred()

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
	var style := S.G.T.box(RELIEF, 0)
	style.content_margin_left = px(8)
	style.content_margin_right = px(8)
	style.content_margin_top = px(4)
	style.content_margin_bottom = px(4)
	if change:
		style.set_border_width_all(maxi(1, px(3)))
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
	S.clear(xv)
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
	for poste in joueurs.size():
		var joueur: Variant = joueurs[poste]
		var info: Dictionary = infos[poste]
		var case := _ligne_joueur("MatchBetweenPlayer%d" % (poste + 1), poste, func(): joueur_choisi.emit(poste))
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
		jauge.densite = _densite
		jauge.custom_minimum_size = Vector2(px(80), px(20))
		jauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		S.G.fill(jauge)
		energie.add_child(jauge)
		var critique := condition < EPUISE
		var valeur := _cellule(("! " if critique else "") + "%d %%" % roundi(condition), 74, Jauge.teinte_pour(condition) if condition < FATIGUE else IVOIRE, 19, true)
		energie.add_child(valeur)
		ligne.add_child(energie)
		ligne.add_child(_cellule(str(int(info.get("plaquages", 0))), int(COLONNES_XV[3][1]), IVOIRE, 19, true))
		ligne.add_child(_cellule(("%.1f" % float(info.note)).replace(".", ","), int(COLONNES_XV[4][1]), _teinte_note(float(info.note)), 19, true))
		if not alerte.is_empty(): alertes_xv.append({"poste": poste, "id": id, "nom": str(joueur.get("name", "")), "alerte": alerte, "condition": condition})
		if alerte in ["épuisé", "blessé"]: _marquer_ligne(case)
		case.tooltip_text = str(info.detail)
		xv.add_child(case)
	_ligne_equipe(direct.get("feuille", {}) if direct.get("feuille") is Dictionary else {}, int(direct.get("camp", -1)), joueurs.map(func(j: Variant) -> String: return str(j.get("id", "")) if j is Dictionary else ""))

## Ligne de tableau (24 px à 1920) : bouton plat zébré, focus ivoire ; son contenu est une rangée de cellules.
func _ligne_joueur(nom: String, rang: int, action: Callable) -> Button:
	var case := Button.new()
	case.name = nom
	case.flat = true
	case.focus_mode = Control.FOCUS_ALL
	case.set_meta("contextual_enabled", true)
	case.pressed.connect(action)
	var fond := StyleBoxFlat.new()
	fond.bg_color = RELIEF if rang % 2 == 1 else Color(0, 0, 0, 0)
	fond.set_corner_radius_all(0)
	var survol := StyleBoxFlat.new()
	survol.bg_color = SURVOL
	survol.set_corner_radius_all(0)
	var focus := StyleBoxFlat.new()
	focus.bg_color = SURVOL
	focus.border_color = IVOIRE
	focus.border_width_left = maxi(2, px(4))
	focus.set_corner_radius_all(0)
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

## Ligne signalée (épuisé, blessé) : marqueur ivoire incliné à gauche, comme sur la maquette.
func _marquer_ligne(case: Button) -> void:
	case.set_meta("signale", true)
	var style := (case.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.bg_color = SURVOL
	style.border_color = IVOIRE
	style.border_width_left = maxi(2, px(4))
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
	if app is Control and not id.is_empty(): MiniFiche.lier(app, lien, id, "squad")
	rangee.add_child(lien)
	if not alerte.is_empty():
		var mot := _texte(alerte, 18, ALERTE if alerte in ["épuisé", "blessé", "exclu"] or alerte.begins_with("carton") else Charte.ATTRIBUT_40)
		mot.name = "MatchBetweenPlayerAlert"
		mot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mot.clip_text = true
		rangee.add_child(mot)
	if not humeur.is_empty(): rangee.add_child(_etiquette_etat(humeur, fpx(17), false))
	return cadre

## Données de Notre XV, poste par poste : données du joueur (`W.donnees_joueur`), alerte, infobulle.
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
		info.merge({"alerte": alerte, "carton": cartons.has(id), "etat": humeur, "detail": detail + "\nLigne : ouvrir la fenêtre Équipe sur ce joueur · nom : sa fiche."}, true)
		infos.append(info)
	return infos

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
	var cle := JSON.stringify([reserves.map(func(j: Variant): return [j.get("id"), j.get("name"), j.get("pos")] if j is Dictionary else null), restants, _densite])
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
		var case := _ligne_joueur("MatchBetweenBench%d" % (16 + n), n, func(): tiroir_demande.emit("Équipe"))
		var ligne: HBoxContainer = case.get_child(0)
		ligne.add_child(_cellule(str(16 + n), int(COLONNES_XV[0][1]), DOUX, 19, true))
		ligne.add_child(_nom_joueur(str(joueur.get("name", "")), str(joueur.get("id", ""))))
		var poste := _cellule(str(joueur.get("pos", "")), 190, DOUX, 17)
		poste.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ligne.add_child(poste)
		case.tooltip_text = "%d · %s · %s\nLigne : ouvrir la fenêtre Équipe (remplacements) · nom : sa fiche." % [16 + n, str(joueur.get("pos", "")), str(joueur.get("name", ""))]
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
	ligne.custom_minimum_size.y = maxi(18, px(32))
	ligne.name = "MatchBetweenTeamTotal"
	ligne.tooltip_text = "Total de l'équipe, remplaçants sortis compris : %d plaquages, %d m, %d essai%s (%d plaquage%s, %d m, %d essai%s déjà aux joueurs remplacés)." % [total.plaquages, total.metres, total.essais, "s" if total.essais > 1 else "", sortis.plaquages, "s" if sortis.plaquages > 1 else "", sortis.metres, sortis.essais, "s" if sortis.essais > 1 else ""]
	ligne.mouse_filter = Control.MOUSE_FILTER_STOP
	var trait_haut := ColorRect.new()
	trait_haut.color = TRAIT
	trait_haut.custom_minimum_size = Vector2(0, 1)
	trait_haut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xv.add_child(trait_haut)
	ligne.add_child(_cellule("", int(COLONNES_XV[0][1]), DOUX, 17))
	ligne.add_child(_cellule("Équipe", 0, DOUX, 17, false))
	ligne.add_child(_cellule("%d m · %d essai%s" % [total.metres, total.essais, "s" if total.essais > 1 else ""], int(COLONNES_XV[2][1]), DOUX, 17))
	ligne.add_child(_cellule(str(total.plaquages), int(COLONNES_XV[3][1]), IVOIRE, 19, true))
	ligne.add_child(_cellule("", int(COLONNES_XV[4][1]), DOUX, 17))
	xv.add_child(ligne)

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
## match) : « ← Retour au match » (Échap) la referme, le match reste en pause le temps de la lire.
func ouvrir_fiche(id: String) -> void:
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
	var retour := _lien("← Retour au match", fermer_fiche, "MatchBetweenPlayerSheetBack")
	retour.tooltip_text = "Revenir à l’entracte · Échap"
	tete.add_child(retour)
	tete.add_child(_touche("Échap"))
	var precision := _texte("le match reste en pause pendant la lecture de la fiche", 18, DOUX)
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
			if bouton is Button: (bouton as Button).text = "← Retour au match"
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
static func _teinte_note(note: float) -> Color:
	if note >= 7.5: return Charte.ATTRIBUT_75
	if note >= 7.0: return Charte.V
	if note >= 6.5: return IVOIRE
	if note >= 6.0: return Charte.ATTRIBUT_55
	return ALERTE

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
	portrait.custom_minimum_size = Vector2(px(104), px(104))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var matte := ShaderMaterial.new()
	matte.shader = MATTE
	portrait.material = matte
	carte.add_child(portrait)
	# Trait incliné aux couleurs du club (charte §3 : 10°), entre le portrait et la parole de Gabi.
	var trait_club := Control.new()
	trait_club.name = "MatchBetweenAdviceStroke"
	trait_club.custom_minimum_size = Vector2(px(22), px(104))
	trait_club.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var teinte_club: Color = Charte.club_trait(terrain.couleurs[clampi(int(direct.get("camp", 0)), 0, 1)]) if terrain != null else IVOIRE
	trait_club.draw.connect(func():
		var h := trait_club.size.y
		trait_club.draw_line(Vector2(trait_club.size.x * 0.5 + Charte.decalage(h) * 0.5, 0), Vector2(trait_club.size.x * 0.5 - Charte.decalage(h) * 0.5, h), teinte_club, maxf(2.0, px(4))))
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
		phrases.append([texte, IVOIRE])
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
		etiquette.max_lines_visible = 2 if phrases.size() == 1 else 1
		etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		etiquette.tooltip_text = "\n".join(raisons) if not raisons.is_empty() else str(phrase[0])
		etiquette.mouse_filter = Control.MOUSE_FILTER_PASS
		colonne.add_child(etiquette)
		# Lignes réservées (un texte à la ligne tronqué n'en réserve qu'une) : la carte garde la hauteur
		# du portrait et la phrase n'est jamais coupée à mi-hauteur.
		etiquette.custom_minimum_size.y = hauteur_lignes(etiquette, etiquette.max_lines_visible)
	# Les actions à droite de la carte (Gabi en largeur, sous le tableau de bord).
	var actions := S.G.h(px(10))
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if fini: _remplir_pourquoi(colonne, direct, actions)
	carte.add_child(actions)
	# L'action qui va avec la phrase : remplacer le joueur signalé, ou appliquer les consignes
	# proposées (seulement si l'adjoint propose autre chose que les consignes en place).
	if remplacer >= 0:
		var poste := remplacer
		# Le remplaçant conseillé par le staff (`live.pilotage.conseilChangement`), s'il vise ce joueur.
		var entrant := _entrant_conseille(live, str(alertes_xv.filter(func(a: Dictionary): return int(a.poste) == poste)[0].id) if alertes_xv.any(func(a: Dictionary): return int(a.poste) == poste) else "")
		var libelle := "Remplacer le %d" % (poste + 1) + (" par %s" % _nom_court(entrant) if not entrant.is_empty() else "")
		var bouton_remplacer := _bouton(libelle, func(): joueur_choisi.emit(poste))
		bouton_remplacer.name = "MatchBetweenReplace"
		bouton_remplacer.tooltip_text = "Ouvrir la fenêtre Équipe sur ce joueur (le match se met en pause) · Entrée"
		bouton_remplacer.set_meta("contextual_enabled", true)
		actions.add_child(bouton_remplacer)
		actions.add_child(_touche("Entrée"))
	elif not fini and conseil is Dictionary and (conseil.get("attackChanged", false) or conseil.get("defenceChanged", false)):
		var possible: bool = conseil.get("canAct", false) and conseil.get("defenceAvailable", false)
		var bouton := _bouton("Appliquer ses consignes", func(): appliquer.call(conseil), possible)
		bouton.name = "MatchBetweenApplyAdvice"
		bouton.tooltip_text = "Appliquer les consignes proposées." if possible else "Mets le match en pause pour modifier tes consignes."
		actions.add_child(bouton)

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
		var bouton := _bouton(str(raison.get("action", "Voir")), func(): levier_choisi.emit(route), true)
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

## Une décision à la fois (fiche UX §6.3) : Équipe et Réglages attendent la fin du choix du staff.
func _poser_arret_commandes() -> void:
	var bloque := _choix_en_attente()
	for bouton: BaseButton in [equipe, parametres]:
		if not is_instance_valid(bouton): continue
		bouton.set_meta("contextual_enabled", not bloque)
		bouton.disabled = bloque
		bouton.tooltip_text = "Après le choix du staff." if bloque else ("Composition, banc, cris de la touche et consignes (le match se met en pause) · T" if bouton == equipe else "Vitesse de l’horloge entre deux temps forts et temps forts montrés.")

## Ligne d'option du panneau d'arrêt : texte ivoire à gauche, à plat ; survol et focus en filet ivoire.
func _style_option(bouton: Button, retenue: bool) -> void:
	for etat_bouton in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = SURVOL if retenue or etat_bouton in ["hover", "pressed"] else Color(0, 0, 0, 0)
		style.border_color = IVOIRE
		style.set_border_width_all(1 if retenue or etat_bouton == "focus" else 0)
		if retenue: style.border_width_left = maxi(2, px(5))
		style.set_corner_radius_all(0)
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
