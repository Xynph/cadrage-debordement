extends Control
## Écran intermédiaire du match en temps forts (mode de base ; repli CD_MATCH_TEMPS_FORTS=0).
##
## Entre deux temps forts, le match continue sur un terrain vu de dessus (`match_terrain_2d.gd`) :
## trente pastilles numérotées rejouent les faits du moteur pendant que l'horloge défile. Autour,
## un tableau de bord inspiré des écrans « match overview » des jeux de management de football,
## adapté au rugby : domination minute par minute, chiffres clés comparés, fil, Mon XV (note,
## énergie, alertes), regard de l'adjoint et accès direct à la tactique et aux remplacements.
## Une seule mise en page (maquette validée par Léo, 16 novembre 2026) : Notre XV à gauche (tuile
## principale ; vue Terrain par défaut, Tableau, XV adverse ; carte Changement dessous), le terrain
## 2D en grand au centre avec momentum, anneaux possession et occupation et tuile « Dans les 22 »,
## le duel (chiffres comparés) et les faits marquants à droite, Gabi en largeur en bas. Il n'affiche
## que la projection `live.direct` du moteur et le modèle : aucun calcul sportif.
const S = preload("res://ui/contextual/skin.gd")
const T = preload("res://theme.gd")
const Terrain2D = preload("res://ui/contextual/match_terrain_2d.gd")
const W = preload("res://ui/contextual/match_tableau_widgets.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const Pilotage = preload("res://ui/contextual/match_consignes.gd")

signal niveau_choisi(id: String)
signal reprise_demandee
signal tiroir_demande(titre: String)
## Entracte entre deux temps forts : le manager l'abrège.
signal passer_demande
## Vitesse de l'horloge entre deux temps forts (« lente », « normale », « rapide », « eclair »).
signal horloge_choisie(valeur: String)
## « Confier la fin à l'adjoint », depuis le menu de la barre.
signal delegation_demandee
## Un joueur de Mon XV choisi : le banc s'ouvre sur lui.
signal joueur_choisi(poste: int)
## « Pourquoi » d'après-match : l'action d'une raison ouvre l'écran de son levier (route du jeu).
signal levier_choisi(route: String)
## Score du dernier fait joué sur le terrain (le moteur a parfois une minute d'avance).
signal score_joue(score: Array)
## Caméra du direct 3D choisie dans le menu Plus (« tv », « tactical », « action »).
signal camera_demandee(mode: String)
## Bande de la vue du match (sous le score) qui porte la barre de commandes, la même en 3D et
## pendant l'entracte ; sans elle, la barre reste en haut de l'écran intermédiaire.
var hote_barre: Control

## Libellés courts des stats comparées (le libellé complet en infobulle) : rien de tronqué.
const LIBELLES_COURTS := {"metres": "Mètres gagnés", "franchissements": "Franchis.", "plaquages": "Plaquages",
	"plaquages_manques": "Plaq. manqués", "recuperations": "Récupérations", "melees": "Mêlées", "touches": "Touches",
	"penalites": "Pénalités", "en_avant": "En-avant", "pieds": "Jeu au pied"}
## Les dix stats comparées du duel (possession et occupation dans leurs anneaux, le reste dans le
## tiroir, menu Plus).
const STATS := ["metres", "franchissements", "plaquages", "plaquages_manques",
	"recuperations", "melees", "touches", "penalites", "en_avant", "pieds"]
const FATIGUE := 55
const EPUISE := 40
var terrain: Terrain2D
var etat: Label
var parametres: Button
var panneau_parametres: PopupPanel
var groupe_horloge: ButtonGroup
var groupe_niveaux: ButtonGroup
var grille_niveaux: GridContainer
var bandeau: PanelContainer
var fil: VBoxContainer
var chiffres: VBoxContainer
var xv: GridContainer
var adjoint: VBoxContainer
var tactique: Button
var banc: Button
var plus: MenuButton
## Horloge de l'entracte choisie (reprise de la régie à l'ouverture).
var horloge := "normale"
const HORLOGES_IDS := ["lente", "normale", "rapide", "eclair"]
const HORLOGES_COURTS := ["Posée", "Normale", "Rapide", "Éclair"]
var adjoint_cadre: Control
var domination: Domination
var arret: PanelContainer
var arret_titre: Label
var arret_texte: Label
var _niveaux: Array = []
var _cle := ""
var _densite := 0.5
var _arret: Dictionary = {}
var _entracte := ["", false]
var _dernier: Array = []
var _lignes: Array = []
var _dernier_fait := -1
var _rangs: Array = []
## Faits marquants (les derniers faits joués).
var faits: VBoxContainer
## Photo d'ambiance des faits marquants (banque d'images) : le dernier grand fait joué, puis le résultat.
var photo_faits: TextureRect
var _fin := {}
## Vue de la tuile principale : « terrain » (par défaut, les quinze à leur poste), « tableau »
## (Mon XV en tableau complet) ou « adverse » (le XV adverse, `direct.adversaire`).
var vue_xv := "terrain"
var onglets: Array[Button] = []
## Vue Terrain de Notre XV et conteneur du tableau (entête et lignes).
var formation: Formation
var tableau_xv: VBoxContainer
var precision_xv: Label
## Carte Changement : le joueur du XV le plus en difficulté (poste, -1 si rien d'urgent).
var carte_changement: PanelContainer
var changement: HBoxContainer
var changement_poste := -1
## Anneaux possession et occupation (`direct.tableau`).
var anneau_possession: Anneau
var anneau_occupation: Anneau
## Tuile « Dans les 22 » (`direct.zone22`), masquée sans la donnée.
var zone22: PanelContainer
var zone22_contenu: VBoxContainer
var _xv_donnees: Array = []
var _equipes: Array = []
## Tuile principale (Mon XV) : l'œil commence par elle.
var tuile_principale: PanelContainer
## Alertes de Mon XV (fatigue, blessure, carton) : pour l'adjoint et les tests.
var alertes_xv: Array[Dictionary] = []
## Précision du titre des statistiques : « comparées », ou l'avertissement d'échantillon court.
var precision_chiffres: Label
## Échantillon trop court (`direct.echantillon`, lot 5) : chiffres atténués, adjoint sans lecture.
var echantillon_court := false
## Opacité des chiffres pendant l'échantillon court : lisibles, mais en retrait du score et des alertes.
const ATTENUE := 0.5
## Journée en direct (`direct.journee`, moteur match-multiplex.cjs) : classement « si ça finit
## ainsi » sous le duel et multiplex des autres matchs à côté de Gabi. Masqués sans la donnée.
var classement_tuile: PanelContainer
var classement_lignes: VBoxContainer
## Marges des trois tuiles de droite (duel, classement, faits), resserrées avec le classement.
var _tuiles_droite: Array = []
var multiplex: PanelContainer
var multiplex_cartes: GridContainer
## Pilotage reçu du moteur (`live.pilotage`) : sert aux états des joueurs (Galvanisé, Vexé…) de Mon XV.
## Les consignes en direct ne sont pas sur cet écran (tiroir Tactique de la vue du match).
var _pilotage: Dictionary = {}
var multiplex_precision: Label
## Dernière journée montrée (null sans multiplex) et sa clé (rien n'est reconstruit sans changement).
var journee_vue: Variant = null
var _journee_cle := ""
## Scores des autres matchs à la minute montrée et à la précédente : liseré vert sur ceux qui ont
## changé (état gardé par l'écran, aucun calcul sportif).
var _journee_minute := -1
var _scores_cour: Dictionary = {}
var _scores_prec: Dictionary = {}
## Lignes du classement en direct : notre voisinage (± 3 places) et le haut du tableau.
const CLASSEMENT_LIGNES := 9
const VERT_SCORE := Color("65b081")
const MONTEE := Color("65b081")
const DESCENTE := Color("e2876f")

## Domination minute par minute (`direct.domination`) : barres au-dessus de l'axe pour l'équipe
## qui reçoit, au-dessous pour l'autre, mi-temps et points marqués en repère.
class Domination extends Control:
	const S = preload("res://ui/contextual/skin.gd")
	const T = preload("res://theme.gd")
	var minutes: Array = []
	var mi_temps: Variant = null
	var reperes: Array = []
	var couleurs: Array[Color] = [Color("b8343c"), Color("e9e6d6")]
	var sigles: Array = ["", ""]
	var densite := 0.5

	func _draw() -> void:
		var police: Font = T.DISPLAY
		var corps := roundi(maxf(12.0, 24.0 * densite))
		var marge := Vector2(maxf(24.0, 64.0 * densite), corps * 0.6)
		var zone := Rect2(Vector2(marge.x, marge.y), size - Vector2(marge.x + 6.0 * densite, marge.y * 2.0))
		if zone.size.x < 40.0 or zone.size.y < 20.0: return
		var milieu := zone.position.y + zone.size.y * 0.5
		# Échelle qui s'élargit avec le match (20, 40, 60 puis 80 minutes) : la courbe se lit dès
		# les premières minutes au lieu d'occuper un coin d'un axe de 80 minutes.
		var fin := clampi(int(ceil(float(minutes.size() + 2) / 20.0)) * 20, 20, 80)
		fin = maxi(fin, minutes.size())
		var pas := zone.size.x / float(fin)
		draw_rect(zone, Color(1, 1, 1, 0.025))
		var graduation := 5 if fin <= 20 else 10 if fin <= 40 else 20
		for repere in range(graduation, fin, graduation):
			var x := zone.position.x + float(repere) * pas
			draw_dashed_line(Vector2(x, zone.position.y), Vector2(x, zone.end.y), Color(S.MUTED, 0.5 if repere == 40 else 0.25), 1.0, 4.0)
			draw_string(police, Vector2(x - 20.0, zone.end.y + corps * 0.55), "%d'" % repere, HORIZONTAL_ALIGNMENT_CENTER, 40.0, maxi(9, roundi(corps * 0.55)), Color(S.MUTED, 0.7))
		for cote in 2:
			draw_string(police, Vector2(0, milieu + (-zone.size.y * 0.22 if cote == 0 else zone.size.y * 0.22 + corps * 0.7)), str(sigles[cote]), HORIZONTAL_ALIGNMENT_LEFT, marge.x - 4.0, corps, couleurs[cote].lightened(0.15))
		# Aire de domination : au-dessus de la ligne médiane pour l'équipe qui reçoit, au-dessous
		# pour l'autre, en fondu vers la médiane, et le trait de la courbe par-dessus.
		if not minutes.is_empty():
			var points: Array[Vector2] = [Vector2(zone.position.x, milieu)]
			for n in minutes.size():
				var v := clampf(float(minutes[n]) / 100.0, -1.0, 1.0)
				points.append(Vector2(zone.position.x + (n + 0.5) * pas, milieu - v * zone.size.y * 0.46))
			points.append(Vector2(zone.position.x + minutes.size() * pas, points[-1].y))
			for n in range(1, points.size()):
				var a := points[n - 1]
				var b := points[n]
				# Segment coupé à la médiane : chaque morceau prend la couleur de son côté.
				var morceaux: Array = [[a, b]]
				if (a.y - milieu) * (b.y - milieu) < 0.0:
					var k := (milieu - a.y) / (b.y - a.y)
					var m := a.lerp(b, k)
					morceaux = [[a, m], [m, b]]
				for morceau: Array in morceaux:
					var p0: Vector2 = morceau[0]
					var p1: Vector2 = morceau[1]
					var dessus := (p0.y + p1.y) * 0.5 <= milieu
					var teinte: Color = couleurs[0 if dessus else 1]
					# Polygone sans sommet en double (la triangulation refuse les formes dégénérées).
					var poly := PackedVector2Array()
					var fondu := PackedColorArray()
					for sommet: Array in [[p0, 0.55], [p1, 0.55], [Vector2(p1.x, milieu), 0.06], [Vector2(p0.x, milieu), 0.06]]:
						var q: Vector2 = sommet[0]
						if poly.is_empty() or (poly[poly.size() - 1].distance_to(q) > 0.05 and poly[0].distance_to(q) > 0.05):
							poly.append(q)
							fondu.append(Color(teinte, float(sommet[1])))
					var aire := absf((p1.x - p0.x) * ((p0.y - milieu) + (p1.y - milieu)) * 0.5)
					if poly.size() >= 3 and aire > 0.5: draw_polygon(poly, fondu)
					draw_line(p0, p1, teinte.lightened(0.15), maxf(1.5, 3.0 * densite), true)
		draw_line(Vector2(zone.position.x, milieu), Vector2(zone.end.x, milieu), Color(S.TEXT, 0.35), maxf(1.0, 1.5 * densite))
		# Frise du match : chaque essai, tir réussi ou carton déjà montré devient un pictogramme
		# à sa minute, au-dessus de l'axe pour l'équipe qui reçoit, au-dessous pour l'autre, relié
		# à l'axe par une tige aux couleurs du club.
		var rayon := maxf(7.0, 17.0 * densite)
		for repere: Dictionary in reperes:
			var m := float(repere.get("minute", 0))
			var cote := clampi(int(repere.get("equipe", 0)), 0, 1)
			var x := zone.position.x + clampf((m - 0.5) * pas, 0.0, zone.size.x)
			var ou := Vector2(x, zone.position.y + rayon if cote == 0 else zone.end.y - rayon)
			draw_line(Vector2(x, milieu), ou, Color(couleurs[cote].lightened(0.2), 0.8), maxf(1.0, 2.0 * densite), true)
			Picto.dessiner(self, ou, rayon, str(repere.get("kind", "")), couleurs[cote], bool(repere.get("rouge", false)))
		if not minutes.is_empty():
			var x := zone.position.x + minutes.size() * pas
			draw_line(Vector2(x, zone.position.y), Vector2(x, zone.end.y), S.GOLD, maxf(1.5, 3.0 * densite))

## Pictogramme d'un fait (fil, frise du match) : essai, tir au but, carton, mêlée, touche, jeu au
## pied, ballon perdu. Pastille sombre cerclée aux couleurs du club, signe clair au centre.
class Picto:
	static func dessiner(ci: CanvasItem, c: Vector2, r: float, kind: String, teinte: Color, rouge: bool = false) -> void:
		ci.draw_circle(c, r, Color("121a1c"))
		ci.draw_circle(c, r, Color(teinte, 0.28))
		ci.draw_arc(c, r - 0.5, 0.0, TAU, 28, teinte.lightened(0.15), maxf(1.0, r * 0.12), true)
		var epais := maxf(1.2, r * 0.14)
		var blanc := Color("f2ecdc")
		match kind:
			"try":
				ci.draw_set_transform(c, -0.6, Vector2(1.4, 0.85))
				ci.draw_circle(Vector2.ZERO, r * 0.42, Color("e0b35a"))
				ci.draw_set_transform(Vector2.ZERO, 0.0)
				ci.draw_line(c + Vector2(-r * 0.22, r * 0.12), c + Vector2(r * 0.22, -r * 0.12), Color("3a2a1a"), epais * 0.7, true)
			"goal", "miss", "penalty", "transformation":
				ci.draw_line(c + Vector2(-r * 0.35, -r * 0.5), c + Vector2(-r * 0.35, r * 0.5), blanc, epais, true)
				ci.draw_line(c + Vector2(r * 0.35, -r * 0.5), c + Vector2(r * 0.35, r * 0.5), blanc, epais, true)
				ci.draw_line(c + Vector2(-r * 0.35, r * 0.1), c + Vector2(r * 0.35, r * 0.1), blanc, epais, true)
			"card":
				ci.draw_rect(Rect2(c - Vector2(r * 0.3, r * 0.45), Vector2(r * 0.6, r * 0.9)), Color("d43e47") if rouge else Color("e8c24a"))
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

## Barre comparée d'un chiffre : valeurs des deux équipes et parts de la barre.
class Barre extends Control:
	const S = preload("res://ui/contextual/skin.gd")
	var valeurs: Array = [0, 0]
	var couleurs: Array[Color] = [Color("b8343c"), Color("e9e6d6")]
	var densite := 0.5

	func _draw() -> void:
		var a := maxf(0.0, float(valeurs[0]))
		var b := maxf(0.0, float(valeurs[1]))
		# Barre fine aux bouts arrondis, séparée au milieu par un jour de 2 px.
		var h := maxf(3.0, 7.0 * densite)
		var y := (size.y - h) * 0.5
		_barre(Rect2(0, y, size.x, h), Color(1, 1, 1, 0.07))
		if a + b <= 0.0: return
		var part := a / (a + b)
		if part > 0.0: _barre(Rect2(0, y, maxf(h, size.x * part - 1.0), h), couleurs[0])
		if part < 1.0: _barre(Rect2(size.x * part + 1.0, y, maxf(h, size.x * (1.0 - part) - 1.0), h), couleurs[1])

	func _barre(r: Rect2, teinte: Color) -> void:
		var rayon := r.size.y * 0.5
		draw_rect(Rect2(r.position + Vector2(rayon, 0), Vector2(maxf(0.0, r.size.x - rayon * 2.0), r.size.y)), teinte)
		draw_circle(r.position + Vector2(rayon, rayon), rayon, teinte)
		draw_circle(Vector2(r.end.x - rayon, r.position.y + rayon), rayon, teinte)

## Engrenage du bouton Paramètres.
class Engrenage extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var teinte := Color("f2ecdc")
		for n in 8:
			var a := TAU * n / 8.0
			draw_line(c + Vector2.from_angle(a) * r * 0.55, c + Vector2.from_angle(a) * r * 0.95, teinte, maxf(2.0, r * 0.28))
		draw_circle(c, r * 0.62, teinte)
		draw_circle(c, r * 0.28, Color("18231f"))

## Énergie d'un joueur (condition du moteur, 0 à 100) : anneau autour du numéro, vert, jaune à
## surveiller (moins de 70), couleur d'alerte sous le seuil de fatigue de l'adjoint (55).
class Energie extends Control:
	const CHIFFRES = preload("res://ui/immersive08/fonts/BarlowCondensed-ExtraBold.ttf")
	var valeur := 100.0
	var numero := ""
	var densite := 0.5
	var marque := Color.TRANSPARENT

	static func teinte_pour(v: float) -> Color:
		return Color("65b081") if v >= 70.0 else (Color("c9c46a") if v >= 55.0 else Color("e2876f"))

	func _draw() -> void:
		var c := size * 0.5
		var epais := maxf(4.0, 9.0 * densite)
		var r := minf(size.x, size.y) * 0.5 - epais * 0.5 - 1.0
		draw_circle(c, r, Color("0b1012"))
		draw_arc(c, r, 0.0, TAU, 48, Color("2c3a37"), epais, true)
		var part := clampf(valeur / 100.0, 0.0, 1.0)
		if part > 0.0: draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * part, maxi(6, roundi(48 * part)), teinte_pour(valeur), epais, true)
		if not numero.is_empty():
			var corps := roundi(maxf(13.0, r * 0.95))
			var largeur := CHIFFRES.get_string_size(numero, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x
			draw_string(CHIFFRES, c + Vector2(-largeur * 0.5, corps * 0.36), numero, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, Color("f2ecdc"))
		# Blessure ou carton : pastille en haut à droite de l'anneau.
		if marque.a > 0.0: draw_circle(c + Vector2(r, -r) * 0.72, maxf(3.0, 7.0 * densite), marque)

## Anneau d'une part comparée (possession, occupation) : l'arc de chaque équipe à ses couleurs,
## en partant du haut pour l'équipe qui reçoit ; au centre, la part de notre équipe. « — » tant que
## la part est vide ou l'échantillon court (comme les chiffres comparés).
class Anneau extends Control:
	const CHIFFRES = preload("res://ui/immersive08/fonts/BarlowCondensed-ExtraBold.ttf")
	var valeurs: Array = [0, 0]
	var vide := true
	## Part montrée au centre : celle de notre équipe (l'équipe qui reçoit si le camp est inconnu).
	var camp := 0
	var couleurs: Array[Color] = [Color("b8343c"), Color("e9e6d6")]
	var densite := 0.5

	func texte_centre() -> String:
		return "—" if vide else "%d%%" % roundi(float(valeurs[clampi(camp, 0, 1)]))

	func _draw() -> void:
		var c := size * 0.5
		var epais := maxf(5.0, 14.0 * densite)
		var r := minf(size.x, size.y) * 0.5 - epais * 0.5 - 1.0
		if r < 6.0: return
		draw_circle(c, r, Color("0b1012"))
		var a := maxf(0.0, float(valeurs[0]))
		var b := maxf(0.0, float(valeurs[1]))
		if vide or a + b <= 0.0: draw_arc(c, r, 0.0, TAU, 64, Color("2c3a37"), epais, true)
		else:
			var part := a / (a + b)
			var depart := -PI * 0.5
			if part > 0.0: draw_arc(c, r, depart, depart + TAU * part, maxi(6, roundi(64 * part)), couleurs[0], epais, true)
			if part < 1.0: draw_arc(c, r, depart + TAU * part, depart + TAU, maxi(6, roundi(64 * (1.0 - part))), couleurs[1], epais, true)
		var texte := texte_centre()
		var corps := roundi(maxf(13.0, r * 0.62))
		var largeur := CHIFFRES.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x
		draw_string(CHIFFRES, c + Vector2(-largeur * 0.5, corps * 0.36), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, Color("f2ecdc") if not vide else Color("7b8a84"))

## Évolution d'un club au classement en direct (`delta` du moteur) : triangle vert vers le haut s'il
## gagne des places, rouge vers le bas s'il en perd, tiret sinon.
class Fleche extends Control:
	var delta := 0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.32
		if delta > 0: draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.7), c + Vector2(-r, r * 0.7)]), Color("65b081"))
		elif delta < 0: draw_colored_polygon(PackedVector2Array([c + Vector2(0, r), c + Vector2(r, -r * 0.7), c + Vector2(-r, -r * 0.7)]), Color("e2876f"))
		else: draw_line(c - Vector2(r * 0.8, 0), c + Vector2(r * 0.8, 0), Color("7b8a84"), maxf(1.0, r * 0.35))

## Pastille ronde aux couleurs d'un club (neutre si la couleur est inconnue).
class Pastille extends Control:
	var teinte := Color("7b8a84")

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, teinte)
		draw_arc(size * 0.5, r - 0.5, 0.0, TAU, 20, Color(1, 1, 1, 0.25), 1.0, true)

## Entrée dans les 22 adverses : un carré aux couleurs du club.
class Carre extends Control:
	var teinte := Color.WHITE

	func _draw() -> void:
		var cote := minf(size.x, size.y)
		draw_rect(Rect2((size - Vector2(cote, cote)) * 0.5, Vector2(cote, cote)), teinte)

## Vue Terrain de Notre XV : mini-terrain vertical rayé, avants en haut ; chaque joueur est un
## bouton placé à son poste (anneau d'énergie, nom court et note dessous).
class Formation extends Control:
	## Poste 1 à 15 : [abscisse de 0 à 1, rang de 0 (première ligne) à 5 (arrière)].
	const PLACES := [[0.25, 0], [0.5, 0], [0.75, 0], [0.38, 1], [0.62, 1], [0.16, 2], [0.84, 2], [0.5, 2],
		[0.36, 3], [0.64, 3], [0.11, 4], [0.37, 4], [0.63, 4], [0.89, 4], [0.5, 5]]
	const RANGS := 6
	var densite := 0.5
	## Boutons des joueurs, dans l'ordre des postes, et leur anneau d'énergie.
	var cases: Array[Button] = []
	var anneaux: Array[Control] = []
	## Une ligne d'état sous le nom (causeries, `live.pilotage.joueurs`) : l'anneau lui laisse la place.
	var avec_etats := false

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: placer()

	func _zone() -> Rect2:
		var marge := maxf(4.0, 12.0 * densite)
		return Rect2(Vector2(marge, marge), size - Vector2(marge, marge) * 2.0)

	## Une case par joueur : largeur d'un quart de terrain, hauteur d'un rang ; l'anneau prend la
	## hauteur qui reste au-dessus du nom.
	func placer() -> void:
		var zone := _zone()
		if zone.size.x <= 0.0 or zone.size.y <= 0.0: return
		var hauteur := zone.size.y / float(RANGS)
		var largeur := minf(zone.size.x / 4.0, hauteur * 2.6)
		var texte := maxf(16.0, 34.0 * densite) + (maxf(20.0, 36.0 * densite) if avec_etats else 0.0)
		var diametre := clampf(hauteur - texte - maxf(2.0, 6.0 * densite), maxf(18.0, 36.0 * densite), 92.0 * densite)
		for n in mini(cases.size(), PLACES.size()):
			var place: Array = PLACES[n]
			var centre := zone.position + Vector2(float(place[0]) * zone.size.x, (float(place[1]) + 0.5) * hauteur)
			var case := cases[n]
			case.size = Vector2(largeur, hauteur)
			case.position = Vector2(clampf(centre.x - largeur * 0.5, zone.position.x, zone.end.x - largeur), centre.y - hauteur * 0.5)
			if n < anneaux.size(): anneaux[n].custom_minimum_size = Vector2(diametre, diametre)

	func _draw() -> void:
		var zone := _zone()
		if zone.size.x <= 0.0 or zone.size.y <= 0.0: return
		draw_rect(Rect2(Vector2.ZERO, size), Color("16281e"))
		var bandes := 10
		for bande in bandes:
			var y0 := zone.position.y + zone.size.y * bande / float(bandes)
			draw_rect(Rect2(zone.position.x, y0, zone.size.x, zone.size.y / float(bandes)), Color("31603c") if bande % 2 == 0 else Color("285132"))
		var ligne := Color(1, 1, 1, 0.35)
		var epais := maxf(1.0, 2.0 * densite)
		draw_rect(zone, ligne, false, epais)
		for part: float in [0.04, 0.96, 0.27, 0.73, 0.5]:
			var y := zone.position.y + zone.size.y * part
			draw_line(Vector2(zone.position.x, y), Vector2(zone.end.x, y), Color(1, 1, 1, 0.5 if part == 0.5 else 0.3), epais)
		for part: float in [0.42, 0.58]:
			var y := zone.position.y + zone.size.y * part
			draw_dashed_line(Vector2(zone.position.x, y), Vector2(zone.end.x, y), Color(1, 1, 1, 0.2), epais, maxf(4.0, 10.0 * densite))

## Échelle de l'interface, comme les autres écrans du jeu (immersive08/components.gd) :
## les tailles sont écrites pour 2560×1440 et réduites jusqu'à la moitié en 1280×720.
static func densite_pour(taille: Vector2) -> float:
	return clampf(minf(taille.y / 1440.0, taille.x / 2560.0), 0.5, 1.0)

func px(valeur: float) -> int:
	return roundi(valeur * _densite)

func _texte(texte: String, taille: float, couleur: Color, retour: bool = false, titre: bool = false) -> Label:
	var etiquette := S.wrap(texte, px(taille), couleur) if retour else S.label(texte, px(taille), couleur)
	etiquette.add_theme_font_size_override("font_size", px(taille))
	if titre: etiquette.add_theme_font_override("font", TITRES)
	return etiquette

## Bouton de l'écran : à plat sur le panneau (charte : pas de bordure), le bouton principal en or.
func _bouton(texte: String, action: Callable, actif: bool = true, principal: bool = false) -> Button:
	var bouton := S.button(texte, action, actif, principal)
	bouton.custom_minimum_size.y = px(64)
	bouton.add_theme_font_size_override("font_size", px(28))
	bouton.add_theme_font_override("font", TITRES)
	_habiller(bouton, principal)
	return bouton

func _habiller(bouton: Control, principal: bool = false) -> void:
	var fonds := [OR, OR.lightened(0.12), OR.darkened(0.1)] if principal else [RELIEF, SURVOL, SURVOL.lightened(0.05)]
	var etats := ["normal", "hover", "pressed"]
	for n in etats.size():
		var style := S.G.T.box(fonds[n], maxi(4, px(10)))
		style.content_margin_left = px(22)
		style.content_margin_right = px(22)
		bouton.add_theme_stylebox_override(etats[n], style)
	var focus := S.G.T.box(Color.TRANSPARENT, maxi(4, px(10)), OR)
	focus.set_border_width_all(maxi(1, px(3)))
	bouton.add_theme_stylebox_override("focus", focus)
	for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		bouton.add_theme_color_override(couleur, FOND if principal else (IVOIRE if couleur == "font_color" else OR))

## Charte de l'écran (rugby-legacy-27-couleurs.ase) : fond sapin presque noir, panneaux à peine
## plus clairs et sans bordure, ivoire pour l'information, or rare, vert favorable.
const FOND := Color("0b1012")
const PANNEAU := Color("121a1c")
const RELIEF := Color("18231f")
const SURVOL := Color("1f2e2b")
const TRAIT := Color("232f2e")
const IVOIRE := Color("f2ecdc")
const DOUX := Color("aeb9b3")
const FAIBLE := Color("7b8a84")
const OR := Color("e0b35a")
const ALERTE := Color("e2876f")
const TITRES = preload("res://ui/immersive08/fonts/BarlowCondensed-Bold.ttf")
const CHIFFRES_GRAS = preload("res://ui/immersive08/fonts/BarlowCondensed-ExtraBold.ttf")

func _panneau(parent: Node, marge: int, fond: Color = Color(PANNEAU, 0.94)) -> VBoxContainer:
	var coque := PanelContainer.new()
	var style := S.G.T.box(fond, maxi(6, px(14)))
	style.set_border_width_all(0)
	# Profondeur : ombre douce sous chaque panneau, posé sur le fond sapin.
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = maxi(3, px(18))
	style.shadow_offset = Vector2(0, maxf(1.0, px(5)))
	coque.add_theme_stylebox_override("panel", style)
	parent.add_child(coque)
	var bord := S.G.margin(marge)
	coque.add_child(bord)
	var colonne := S.G.v(px(10))
	bord.add_child(colonne)
	return colonne

## Titre de tuile discret (petites capitales atténuées) ; la tuile principale a un vrai titre.
func _titre(texte: String, precision: String = "", principal: bool = false) -> Control:
	var ligne := S.G.h(px(10))
	var etiquette := _texte(texte if principal else texte.to_upper(), 34 if principal else 22, IVOIRE if principal else FAIBLE, false, true)
	S.G.fill(etiquette)
	ligne.add_child(etiquette)
	if not precision.is_empty(): ligne.add_child(_texte(precision, 24, FAIBLE))
	return ligne

func _ready() -> void:
	name = "MatchBetween"
	mouse_filter = Control.MOUSE_FILTER_PASS
	S.full(self)
	_densite = densite_pour(get_viewport_rect().size)
	_construire()
	resized.connect(_a_l_echelle)
	visibility_changed.connect(_apparaitre)

## Apparition en fondu (0,25 s), sauf si le joueur a demandé de réduire les animations.
func _apparaitre() -> void:
	if not visible: return
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

## Une seule mise en page (choix de Léo, 12 novembre 2026) : grand terrain habillé comme une
## retransmission (dernier fait en bandeau), frise du match dessous, colonne étroite repliable
## à droite (Mon XV avec les noms, chiffres clés et stats par thème, Gabi).
func _construire() -> void:
	# Le terrain garde sa lecture (places, file des faits) d'une échelle à l'autre.
	var ancien := terrain
	if ancien != null and ancien.get_parent() != null: ancien.get_parent().remove_child(ancien)
	for enfant in get_children():
		remove_child(enfant)
		enfant.queue_free()
	_cle = ""
	_journee_cle = ""
	terrain = ancien if ancien != null else Terrain2D.new()
	terrain.densite = _densite
	terrain.legende = false
	# Petit terrain : pastilles plus petites, écartées à l'affichage (numéros lisibles au ruck).
	terrain.taille_pastilles = 0.8
	terrain.custom_minimum_size = Vector2(320, 180)
	_commandes()
	_composants()
	_page()
	_arret_decision()
	if not _arret.is_empty(): montrer_arret(_arret)
	if not terrain.fait_joue.is_connected(_fait_joue): terrain.fait_joue.connect(_fait_joue)

## Commandes : où est le ballon, Tactique, Banc, Paramètres (vitesse
## de l'horloge, temps forts montrés) et Plus (statistiques, journal, délégation).
func _commandes() -> void:
	etat = _texte("", 34, IVOIRE, false, true)
	etat.name = "MatchBetweenState"
	etat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etat.clip_text = true
	etat.custom_minimum_size.x = px(120)
	S.G.fill(etat)
	# Pas de bouton « Passer » ni de compte à rebours (choix de Léo) : le match défile en 2D à
	# la vitesse de l'horloge choisie dans les paramètres.
	tactique = _bouton("TACTIQUE", func(): tiroir_demande.emit("Tactique"))
	tactique.name = "MatchBetweenTactics"
	tactique.tooltip_text = "Consignes d’attaque et de défense (le match se met en pause)."
	tactique.set_meta("contextual_enabled", true)
	banc = _bouton("BANC", func(): tiroir_demande.emit("Banc"))
	banc.name = "MatchBetweenBench"
	banc.tooltip_text = "Ouvrir le banc et faire un remplacement (le match se met en pause)."
	banc.set_meta("contextual_enabled", true)
	plus = MenuButton.new()
	plus.name = "MatchBetweenMore"
	plus.text = "PLUS  ▾"
	plus.flat = false
	plus.custom_minimum_size = Vector2(px(130), px(64))
	plus.add_theme_font_size_override("font_size", px(28))
	plus.add_theme_font_override("font", TITRES)
	plus.tooltip_text = "Statistiques complètes, journal du match, confier la fin à l’adjoint."
	plus.focus_mode = Control.FOCUS_ALL
	plus.set_meta("contextual_enabled", true)
	_habiller(plus)
	var menu := plus.get_popup()
	menu.add_theme_font_size_override("font_size", px(26))
	for libelle: String in ["Statistiques", "Journal du match", "Confier la fin à l’adjoint"]: menu.add_item(libelle)
	# Caméras du direct 3D (la barre du bas est masquée en temps forts).
	menu.add_separator("Caméra des temps forts")
	for paire: Array in [["Vue TV", "tv"], ["Vue de dessus", "tactical"], ["Vue contact", "action"]]:
		menu.add_item(str(paire[0]))
		menu.set_item_metadata(menu.item_count - 1, paire[1])
	menu.id_pressed.connect(func(id: int):
		if id == 0: tiroir_demande.emit("Stats")
		elif id == 1: tiroir_demande.emit("Journal")
		elif id == 2: delegation_demandee.emit()
		else:
			var index := menu.get_item_index(id)
			if index >= 0 and menu.get_item_metadata(index) is String: camera_demandee.emit(str(menu.get_item_metadata(index))))
	# Paramètres (engrenage) : vitesse de l'horloge et temps forts montrés, dans un petit panneau.
	parametres = _bouton("PARAMÈTRES", func(): _ouvrir_parametres())
	parametres.name = "MatchBetweenSettings"
	parametres.tooltip_text = "Vitesse de l’horloge entre deux temps forts et temps forts montrés."
	parametres.set_meta("contextual_enabled", true)
	var engrenage := Engrenage.new()
	engrenage.custom_minimum_size = Vector2(px(30), px(30))
	engrenage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parametres.add_child(engrenage)
	parametres.add_theme_constant_override("h_separation", 0)
	(parametres.get_theme_stylebox("normal") as StyleBox).content_margin_left = px(58)
	for etat_bouton in ["hover", "pressed", "focus"]:
		var style: StyleBox = parametres.get_theme_stylebox(etat_bouton)
		if style != null: style.content_margin_left = px(58)
	parametres.resized.connect(func(): engrenage.position = Vector2(px(20), (parametres.size.y - engrenage.size.y) * 0.5))
	panneau_parametres = PopupPanel.new()
	panneau_parametres.name = "MatchBetweenSettingsPanel"
	panneau_parametres.add_theme_stylebox_override("panel", S.G.T.box(PANNEAU, maxi(6, px(14)), Color(OR, 0.4)))
	parametres.add_child(panneau_parametres)
	var marge := S.G.margin(px(22))
	panneau_parametres.add_child(marge)
	var colonne := S.G.v(px(14))
	marge.add_child(colonne)
	colonne.add_child(_texte("Vitesse de l’horloge", 26, FAIBLE))
	var rangee_horloge := S.G.h(px(8))
	colonne.add_child(rangee_horloge)
	groupe_horloge = ButtonGroup.new()
	for n in HORLOGES_IDS.size():
		var choix := _segment(HORLOGES_COURTS[n], groupe_horloge, HORLOGES_IDS[n] == horloge)
		choix.name = "MatchBetweenSpeed%d" % n
		var id: String = HORLOGES_IDS[n]
		choix.pressed.connect(func():
			horloge = id
			horloge_choisie.emit(id))
		rangee_horloge.add_child(choix)
	colonne.add_child(_texte("Temps forts montrés", 26, FAIBLE))
	grille_niveaux = GridContainer.new()
	grille_niveaux.name = "MatchHighlightLevel"
	grille_niveaux.columns = 3
	grille_niveaux.add_theme_constant_override("h_separation", px(8))
	grille_niveaux.add_theme_constant_override("v_separation", px(8))
	colonne.add_child(grille_niveaux)
	_remplir_niveaux()

## Bouton d'un choix unique (segment) : or quand il est choisi.
func _segment(texte: String, groupe: ButtonGroup, choisi: bool) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.toggle_mode = true
	bouton.button_group = groupe
	bouton.button_pressed = choisi
	bouton.custom_minimum_size = Vector2(px(170), px(56))
	bouton.add_theme_font_size_override("font_size", px(26))
	bouton.add_theme_font_override("font", TITRES)
	bouton.set_meta("contextual_enabled", true)
	_habiller(bouton)
	var choisi_style := S.G.T.box(Color(OR, 0.18), maxi(4, px(10)), OR)
	choisi_style.set_border_width_all(maxi(1, px(2)))
	bouton.add_theme_stylebox_override("pressed", choisi_style)
	bouton.add_theme_color_override("font_pressed_color", OR)
	return bouton

func _ouvrir_parametres() -> void:
	var cadre := parametres.get_global_rect()
	panneau_parametres.reset_size()
	var taille := panneau_parametres.get_contents_minimum_size()
	panneau_parametres.popup(Rect2i(Vector2i(int(cadre.end.x - taille.x), int(cadre.end.y + px(8))), Vector2i(taille)))

func _remplir_niveaux(choisi: String = "") -> void:
	if not is_instance_valid(grille_niveaux): return
	S.clear(grille_niveaux)
	groupe_niveaux = ButtonGroup.new()
	for n in _niveaux.size():
		var id := str(_niveaux[n].get("id", ""))
		var choix := _segment(str(_niveaux[n].get("label", "")), groupe_niveaux, id == choisi)
		choix.custom_minimum_size.x = px(260)
		choix.pressed.connect(func(): niveau_choisi.emit(id))
		grille_niveaux.add_child(choix)

func _libelle_niveau(id: Variant) -> String:
	for item: Dictionary in _niveaux:
		if item.get("id") == id: return str(item.get("label", ""))
	return ""

## Niveau tenu par la régie (préférence du joueur, reprise comprise) : coché dans Paramètres.
var niveau_regie := ""
func montrer_niveau(id: String) -> void:
	niveau_regie = id
	if not _niveaux.is_empty() and niveau_libelle() != _libelle_niveau(id): _remplir_niveaux(id)

## Libellé du niveau de temps forts choisi dans les paramètres (vide s'il n'y en a pas).
func niveau_libelle() -> String:
	if groupe_niveaux == null: return ""
	var choisi := groupe_niveaux.get_pressed_button()
	return choisi.text if choisi != null else ""

## Composants : frise du match, chiffres clés, fil, Mon XV, carte de Gabi.
func _composants() -> void:
	domination = Domination.new()
	domination.name = "MatchBetweenMomentum"
	domination.densite = _densite
	domination.custom_minimum_size = Vector2(0, px(180))
	domination.tooltip_text = "Qui domine, minute par minute (occupation, possession, points, franchissements), et les essais, tirs réussis et cartons déjà vus."
	domination.mouse_filter = Control.MOUSE_FILTER_PASS
	S.G.fill(domination, true)
	chiffres = S.G.v(px(6))
	chiffres.name = "MatchBetweenFigures"
	fil = S.G.v(px(8))
	fil.name = "MatchBetweenFeed"
	xv = GridContainer.new()
	xv.name = "MatchBetweenSquad"
	xv.columns = 1
	xv.add_theme_constant_override("v_separation", px(2))
	S.G.fill(xv)
	faits = S.G.v(px(4))
	faits.name = "MatchBetweenHighlights"
	adjoint = S.G.v(px(10))
	adjoint.name = "MatchBetweenAdvice"
	formation = Formation.new()
	formation.name = "MatchBetweenFormation"
	formation.densite = _densite
	formation.custom_minimum_size = Vector2(px(300), px(260))
	changement = S.G.h(px(16))
	changement.name = "MatchBetweenSwap"
	anneau_possession = Anneau.new()
	anneau_possession.name = "MatchBetweenPossession"
	anneau_occupation = Anneau.new()
	anneau_occupation.name = "MatchBetweenOccupation"
	for anneau: Anneau in [anneau_possession, anneau_occupation]:
		anneau.densite = _densite
		anneau.custom_minimum_size = Vector2(px(124), px(124))
		anneau.mouse_filter = Control.MOUSE_FILTER_PASS
	zone22_contenu = S.G.v(px(6))
	zone22_contenu.name = "MatchBetweenZone22Rows"

## Carte de Gabi (portrait, une phrase, l'action proposée) dans un panneau en relief.
func _carte_gabi(parent: Control) -> void:
	var cadre := _panneau(parent, px(14 if _densite >= 0.6 else 10), Color(RELIEF, 0.97))
	adjoint_cadre = cadre.get_parent().get_parent()
	cadre.add_child(adjoint)

## Colonnes de Mon XV (largeurs à l'échelle 2560) : numéro, nom, poste, note, énergie,
## plaquages, mètres, essais.
const COLONNES_XV := [["", 52], ["Joueur", 0], ["Poste", 56], ["Note", 74], ["Énergie", 190], ["Plaq.", 64], ["Mètres", 80], ["Essais", 64]]
## Poste en deux signes, comme sur une feuille de match.
const POSTES_COURTS := {"pilier gauche": "PG", "talonneur": "TA", "pilier droit": "PD", "deuxième ligne": "2L", "troisième ligne": "3L",
	"numéro 8": "N8", "demi de mêlée": "DM", "demi d’ouverture": "DO", "demi d'ouverture": "DO", "ailier": "AI", "centre": "CE", "arrière": "AR"}

static func poste_court(poste: String) -> String:
	var cle := poste.strip_edges().to_lower()
	if cle.begins_with("numéro"): return "N8" if cle.ends_with("8") else "3L"
	for nom: String in POSTES_COURTS:
		if cle.begins_with(nom): return POSTES_COURTS[nom]
	return poste.substr(0, 3).to_upper()

func _cellule(texte: String, largeur: int, couleur: Color, taille: float = 26, chiffre: bool = false) -> Label:
	var etiquette := _texte(texte, taille, couleur, false, not chiffre)
	if chiffre: etiquette.add_theme_font_override("font", CHIFFRES_GRAS)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiquette.clip_text = true
	etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if largeur > 0:
		etiquette.custom_minimum_size.x = px(largeur)
		etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if chiffre else HORIZONTAL_ALIGNMENT_LEFT
	else: S.G.fill(etiquette)
	return etiquette

## Tableau de bord (maquette validée par Léo, 16 novembre 2026) : la barre de commandes, trois
## colonnes, puis Gabi en largeur. Gauche : Notre XV (onglets Terrain, Tableau, XV adverse), tuile
## principale au liseré or, et la carte Changement dessous. Centre : le terrain 2D en grand (dernier
## fait en bandeau par-dessus), puis momentum, anneaux possession et occupation, tuile « Dans les
## 22 ». Droite : le duel (chiffres comparés), puis les faits marquants.
func _page() -> void:
	var page := S.G.v(px(14))
	S.full(page)
	add_child(page)
	var barre: Control
	if is_instance_valid(hote_barre):
		S.clear(hote_barre)
		barre = hote_barre
	else:
		barre = S.G.h(px(12))
		(barre as HBoxContainer).alignment = BoxContainer.ALIGNMENT_END
		page.add_child(barre)
	for noeud: Control in [etat, tactique, banc, parametres, plus]: barre.add_child(noeud)
	var grille := S.G.h(px(20))
	grille.name = "MatchBetweenTiles"
	S.G.fill(grille, true)
	page.add_child(grille)
	_colonne_xv(grille)
	_colonne_centre(grille)
	# Droite : le duel (chiffres comparés), puis les faits marquants.
	var droite := S.G.v(px(20))
	droite.name = "MatchBetweenColumn"
	droite.custom_minimum_size.x = px(560)
	grille.add_child(droite)
	var cadre_chiffres := _panneau(droite, px(16))
	cadre_chiffres.get_parent().get_parent().name = "MatchBetweenDuel"
	S.G.fill(cadre_chiffres.get_parent().get_parent(), true)
	var titre_chiffres := _titre("Le duel", "comparées")
	precision_chiffres = titre_chiffres.get_child(1) as Label
	precision_chiffres.name = "MatchBetweenFiguresSample"
	cadre_chiffres.add_child(titre_chiffres)
	cadre_chiffres.add_child(chiffres)
	S.G.fill(chiffres, true)
	# Classement en direct (« si ça finit ainsi »), sous le duel ; masqué sans la journée.
	var cadre_classement := _panneau(droite, px(14))
	classement_tuile = cadre_classement.get_parent().get_parent()
	classement_tuile.name = "MatchBetweenLiveTable"
	cadre_classement.add_theme_constant_override("separation", px(6))
	cadre_classement.add_child(_titre("Classement en direct", "si ça finit ainsi"))
	classement_lignes = S.G.v(px(2))
	classement_lignes.name = "MatchBetweenLiveTableRows"
	classement_lignes.add_theme_constant_override("separation", px(2))
	cadre_classement.add_child(classement_lignes)
	classement_tuile.visible = false
	var cadre_faits := _panneau(droite, px(14))
	photo_faits = TextureRect.new()
	photo_faits.name = "MatchBetweenHighlightsPhoto"
	photo_faits.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo_faits.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo_faits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_faits.modulate = Color(1, 1, 1, 0.3)
	var tuile_faits: Control = cadre_faits.get_parent().get_parent()
	tuile_faits.clip_contents = true
	tuile_faits.add_child(photo_faits)
	tuile_faits.move_child(photo_faits, 0)
	cadre_faits.add_child(_titre("Faits marquants"))
	cadre_faits.add_child(faits)
	_tuiles_droite = [cadre_chiffres.get_parent(), cadre_classement.get_parent(), cadre_faits.get_parent()]
	# Bas : la carte de Gabi en largeur, le multiplex des autres matchs à côté.
	var bas := S.G.h(px(20))
	bas.name = "MatchBetweenBottom"
	bas.add_theme_constant_override("separation", px(20))
	page.add_child(bas)
	_carte_gabi(bas)
	S.G.fill(adjoint_cadre)
	# Multiplex : titre et minute à gauche, une rangée de cartes (la bande garde la hauteur de Gabi).
	var cadre_multiplex := _panneau(bas, px(14 if _densite >= 0.6 else 10))
	multiplex = cadre_multiplex.get_parent().get_parent()
	multiplex.name = "MatchBetweenMultiplex"
	var rangee_multiplex := S.G.h(px(14))
	rangee_multiplex.add_theme_constant_override("separation", px(14))
	S.G.fill(rangee_multiplex, true)
	cadre_multiplex.add_child(rangee_multiplex)
	var tete_multiplex := S.G.v(px(2))
	tete_multiplex.alignment = BoxContainer.ALIGNMENT_CENTER
	rangee_multiplex.add_child(tete_multiplex)
	tete_multiplex.add_child(_texte("MULTIPLEX", 22, FAIBLE, false, true))
	multiplex_precision = _texte("", 26, OR, false, true)
	multiplex_precision.name = "MatchBetweenMultiplexMinute"
	tete_multiplex.add_child(multiplex_precision)
	multiplex_cartes = GridContainer.new()
	multiplex_cartes.name = "MatchBetweenMultiplexCards"
	multiplex_cartes.add_theme_constant_override("h_separation", px(10))
	multiplex_cartes.add_theme_constant_override("v_separation", px(8))
	multiplex_cartes.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee_multiplex.add_child(multiplex_cartes)
	multiplex.visible = false

## Colonne gauche : Notre XV, onglets Terrain (par défaut), Tableau et XV adverse ; la carte
## Changement dessous.
func _colonne_xv(grille: Control) -> void:
	var gauche := S.G.v(px(20 if _densite >= 0.6 else 14))
	gauche.name = "MatchBetweenSquadColumn"
	gauche.custom_minimum_size.x = px(840)
	grille.add_child(gauche)
	var cadre_xv := _panneau(gauche, px(18), Color(RELIEF, 0.98))
	tuile_principale = cadre_xv.get_parent().get_parent()
	tuile_principale.name = "MatchBetweenMain"
	S.G.fill(tuile_principale, true)
	var bord := tuile_principale.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	bord.border_width_left = maxi(2, px(5))
	bord.border_color = Color(OR, 0.85)
	tuile_principale.add_theme_stylebox_override("panel", bord)
	var tete := S.G.h(px(8))
	cadre_xv.add_child(tete)
	var groupe := ButtonGroup.new()
	onglets.clear()
	for n in VUES_XV.size():
		var vue: String = VUES_XV[n][0]
		var onglet := _segment(str(VUES_XV[n][1]), groupe, vue == vue_xv)
		onglet.name = str(VUES_XV[n][2])
		onglet.custom_minimum_size = Vector2(px(150), px(48))
		onglet.add_theme_font_size_override("font_size", px(30))
		onglet.pressed.connect(func(): choisir_vue_xv(vue))
		onglets.append(onglet)
		tete.add_child(onglet)
	precision_xv = _texte("", 22, FAIBLE)
	precision_xv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	precision_xv.clip_text = true
	precision_xv.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	S.G.fill(precision_xv)
	tete.add_child(precision_xv)
	# Vue Terrain : les quinze joueurs à leur poste sur un mini-terrain.
	cadre_xv.add_child(formation)
	S.G.fill(formation, true)
	# Vue Tableau (et XV adverse) : le tableau complet.
	tableau_xv = S.G.v(px(2))
	tableau_xv.name = "MatchBetweenTable"
	S.G.fill(tableau_xv, true)
	cadre_xv.add_child(tableau_xv)
	var entete := S.G.h(px(8))
	for colonne: Array in COLONNES_XV:
		entete.add_child(_cellule(str(colonne[0]).to_upper(), int(colonne[1]), FAIBLE, 20, int(colonne[1]) > 0 and colonne[0] != "Poste" and colonne[0] != "Énergie"))
	tableau_xv.add_child(entete)
	tableau_xv.add_child(xv)
	S.G.fill(xv, true)
	# Carte Changement : le joueur le plus en difficulté, ou rien d'urgent.
	var cadre_changement := _panneau(gauche, px(12))
	carte_changement = cadre_changement.get_parent().get_parent()
	carte_changement.name = "MatchBetweenSwapCard"
	cadre_changement.add_child(changement)
	_montrer_vue_xv()

## Colonne centrale : le terrain 2D en grand, le dernier fait en bandeau par-dessus ; dessous,
## momentum, anneaux possession et occupation, tuile « Dans les 22 ».
func _colonne_centre(grille: Control) -> void:
	var centre := S.G.v(px(20))
	S.G.fill(centre, false, 1.0)
	grille.add_child(centre)
	var cadre_terrain := _panneau(centre, px(14))
	cadre_terrain.get_parent().get_parent().name = "MatchBetweenPitchTile"
	S.G.fill(cadre_terrain.get_parent().get_parent(), true)
	var scene := Control.new()
	scene.name = "MatchBetweenScene"
	scene.clip_contents = true
	scene.custom_minimum_size = Vector2(px(560), px(300))
	S.G.fill(scene, true)
	cadre_terrain.add_child(scene)
	S.full(terrain)
	scene.add_child(terrain)
	bandeau = PanelContainer.new()
	bandeau.name = "MatchBetweenBanner"
	var style := S.G.T.box(Color(FOND, 0.72), maxi(4, px(8)))
	style.border_width_left = maxi(2, px(5))
	style.border_color = OR
	style.content_margin_left = px(10)
	style.content_margin_right = px(10)
	style.content_margin_top = px(4)
	style.content_margin_bottom = px(4)
	bandeau.add_theme_stylebox_override("panel", style)
	bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bandeau.anchor_right = 1.0
	bandeau.offset_left = px(12)
	bandeau.offset_right = -px(12)
	bandeau.offset_top = px(10)
	bandeau.offset_bottom = px(10)
	scene.add_child(bandeau)
	bandeau.add_child(fil)
	S.G.fill(fil)
	var rangee := S.G.h(px(20))
	rangee.name = "MatchBetweenGauges"
	centre.add_child(rangee)
	var cadre_frise := _panneau(rangee, px(14))
	S.G.fill(cadre_frise.get_parent().get_parent())
	cadre_frise.add_child(_titre("Momentum"))
	cadre_frise.add_child(domination)
	domination.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cadre_anneaux := _panneau(rangee, px(14))
	cadre_anneaux.get_parent().get_parent().name = "MatchBetweenRings"
	var anneaux := S.G.h(px(14))
	cadre_anneaux.add_child(anneaux)
	S.G.fill(anneaux, true)
	for paire: Array in [[anneau_possession, "Possession"], [anneau_occupation, "Occupation"]]:
		var bloc := S.G.v(px(4))
		S.G.fill(bloc, true)
		anneaux.add_child(bloc)
		var anneau: Anneau = paire[0]
		# Anneau carré au centre de son bloc, qui prend la hauteur disponible.
		S.G.fill(anneau, true)
		anneau.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bloc.add_child(anneau)
		var nom := _texte(str(paire[1]).to_upper(), 26, FAIBLE, false, true)
		nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bloc.add_child(nom)
	var cadre_22 := _panneau(rangee, px(14))
	zone22 = cadre_22.get_parent().get_parent()
	zone22.name = "MatchBetweenZone22"
	zone22.custom_minimum_size.x = px(380)
	cadre_22.add_child(_titre("Dans les 22", "entrées · points · temps"))
	cadre_22.add_child(zone22_contenu)
	zone22.visible = false

## Vues de la tuile principale : identifiant, libellé de l'onglet, nom du nœud de l'onglet.
const VUES_XV := [["terrain", "Terrain", "MatchBetweenTabPitch"], ["tableau", "Tableau", "MatchBetweenTabOwn"], ["adverse", "XV adverse", "MatchBetweenTabOpponent"]]

## Onglet de la tuile principale choisi : la vue change, les données restent celles du dernier relevé.
func choisir_vue_xv(vue: String) -> void:
	vue_xv = vue
	for k in onglets.size(): onglets[k].set_pressed_no_signal(VUES_XV[k][0] == vue)
	_montrer_vue_xv()
	if not _xv_donnees.is_empty(): _remplir_xv(_xv_donnees[0], _xv_donnees[1])

func _montrer_vue_xv() -> void:
	if not is_instance_valid(formation): return
	formation.visible = vue_xv == "terrain"
	tableau_xv.visible = vue_xv != "terrain"
	precision_xv.text = "énergie · note du match" if vue_xv == "terrain" else "note · énergie · plaquages · mètres"

## Arrêt-décision : le match attend le manager.
func _arret_decision() -> void:
	arret = PanelContainer.new()
	arret.name = "MatchBetweenStop"
	var style := S.G.T.box(PANNEAU, maxi(6, px(14)), OR)
	style.set_border_width_all(maxi(1, px(3)))
	arret.add_theme_stylebox_override("panel", style)
	arret.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	arret.custom_minimum_size = Vector2(px(920), 0)
	arret.grow_horizontal = Control.GROW_DIRECTION_BOTH
	arret.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(arret)
	var marge := S.G.margin(px(32))
	arret.add_child(marge)
	var colonne := S.G.v(px(20))
	marge.add_child(colonne)
	arret_titre = _texte("", 44, OR, false, true)
	colonne.add_child(arret_titre)
	arret_texte = _texte("", 30, IVOIRE, true)
	arret_texte.custom_minimum_size.x = px(840)
	colonne.add_child(arret_texte)
	var choix := S.G.h(px(16))
	colonne.add_child(choix)
	choix.add_child(_bouton("BANC", func(): tiroir_demande.emit("Banc")))
	choix.add_child(_bouton("TACTIQUE", func(): tiroir_demande.emit("Tactique")))
	choix.add_child(S.G.spacer())
	choix.add_child(_bouton("REPRENDRE LE MATCH", func(): reprise_demandee.emit(), true, true))
	arret.hide()

static func _zone(x: float, possession: int) -> String:
	# Vu de l'équipe en possession : distance jusqu'à la ligne d'essai adverse.
	var reste := 100.0 - x if possession == 0 else x
	if reste <= 22.0: return "dans les 22 mètres adverses"
	if reste <= 50.0: return "dans le camp adverse"
	if reste <= 78.0: return "dans son camp"
	return "dans ses 22 mètres"

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
	_niveaux = direct.get("niveaux", [])
	var voulu := niveau_regie if not niveau_regie.is_empty() else str(direct.get("niveau", ""))
	if niveau_libelle() != _libelle_niveau(voulu) or grille_niveaux.get_child_count() != _niveaux.size(): _remplir_niveaux(voulu)
	var dom: Dictionary = direct.get("domination", {}) if direct.get("domination") is Dictionary else {}
	domination.minutes = dom.get("minutes", [])
	domination.mi_temps = dom.get("miTemps")
	domination.reperes = direct.get("reperes", [])
	domination.couleurs = terrain.couleurs.duplicate()
	domination.sigles = [S.G.club_abbr(equipes[0]) if equipes.size() > 0 and equipes[0] is Dictionary else "", S.G.club_abbr(equipes[1]) if equipes.size() > 1 and equipes[1] is Dictionary else ""]
	domination.queue_redraw()
	# Conseil de l'adjoint et composition tels qu'ils étaient avant la borne : rien d'un temps fort à venir.
	var passe := _passe(model, live, direct)
	var conseil: Variant = passe.conseil
	var cle := JSON.stringify([direct.get("fil", []), direct.get("tableau", []), direct.get("chiffres", []), conseil, direct.get("notes", {}), direct.get("cartons", []), direct.get("feuille", {}).get("joueurs", {}) if direct.get("feuille") is Dictionary else {},
		passe.lineup, direct.get("statsRows", []), live.get("paused", false), live.get("finished", false), terrain.couleurs, direct.get("pourquoi"), direct.get("hommeDuMatch"), direct.get("zone22"), direct.get("echantillon"), _pilotage.get("joueurs")])
	if cle == _cle: return
	_cle = cle
	_lignes = direct.get("fil", [])
	_fin = {"fini": live.get("finished", false), "score": live.get("score", []), "camp": int(direct.get("camp", -1)),
		"finale": str(model.get("next", {}).get("phase", "") if model.get("next") is Dictionary else "") == "final", "essais": live.get("tries", [])}
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
	elif (possession is float or possession is int) and equipes.size() >= 2:
		var cote := clampi(int(possession), 0, 1)
		etat.text = "%s a le ballon %s" % [S.G.club_name(equipes[cote]), _zone(float(direct.get("zone", {}).get("x", 50.0)), cote)]
	else: etat.text = "Le match"

## Un fait vient d'être joué sur le terrain : le fil le montre, le score le suit.
func _fait_joue(item: Dictionary) -> void:
	_remplir_fil()
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

## Fil : une ligne n'y entre qu'une fois son fait joué sur le terrain ; le dernier, en bandeau.
func _remplir_fil() -> void:
	if not is_instance_valid(fil): return
	S.clear(fil)
	var visibles: Array = []
	var prochain := terrain.prochain_i()
	for entree: Dictionary in _lignes:
		var i := int(entree.get("i", -1))
		if prochain >= 0 and i >= prochain: continue
		visibles.append(entree)
	# Le dernier fait joué, en bandeau ; il apparaît en fondu (sauf animations réduites).
	if not visibles.is_empty():
		var ligne := _ligne_fil(visibles[-1], true, true)
		fil.add_child(ligne)
		var i := int(visibles[-1].get("i", -1))
		if i != _dernier_fait and not _animations_reduites() and is_inside_tree():
			ligne.modulate.a = 0.0
			create_tween().tween_property(ligne, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
		_dernier_fait = i
	else: fil.add_child(_texte("Le coup d’envoi approche.", 26, DOUX))
	# Faits marquants : les derniers faits joués, le plus récent en haut.
	if is_instance_valid(faits):
		S.clear(faits)
		# 1280×720 : deux faits (le premier sur deux lignes, le suivant sur une) pour que la colonne de droite
		# tienne avec Gabi en bas sans rien couper.
		var petit := _densite < 0.6
		var nombre := 2 if petit else 4
		# Classement en direct sous le duel : les faits marquants se resserrent (le dernier fait
		# reste en bandeau sur le terrain ; en 1280×720, une ligne par fait, le texte en infobulle).
		var serre := _journee_montree()
		if serre: nombre = 1 if _densite < 0.6 else 2
		var recents := visibles.slice(maxi(0, visibles.size() - nombre))
		recents.reverse()
		for n in recents.size():
			var ligne_fait := _ligne_fil(recents[n], n == 0, false)
			if serre or petit:
				for etiquette: Label in ligne_fait.find_children("*", "Label", true, false):
					etiquette.max_lines_visible = 1 if serre or n > 0 else 2
					etiquette.tooltip_text = etiquette.text
			if serre:
				for icone: Control in ligne_fait.find_children("*", "Control", true, false):
					if icone is Icone: icone.custom_minimum_size = Vector2(px(30), px(30))
			faits.add_child(ligne_fait)
		if recents.is_empty(): faits.add_child(_texte("Aucun fait marquant pour l’instant.", 24, FAIBLE))
	_photo_faits(visibles)

## Occasion de la photo de fin de match : finale, victoire bonifiée (3 essais de plus), sinon championnat.
static func occasion_fin(fin: Dictionary, resultat: String) -> String:
	if fin.get("finale", false) and resultat != "nul": return "finale"
	var essais: Variant = fin.get("essais")
	var camp := int(fin.get("camp", -1))
	if resultat == "victoire" and essais is Array and essais.size() == 2 and camp in [0, 1] and int(essais[camp]) - int(essais[1 - camp]) >= 3: return "bonus"
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

## Fond de la tuile : résultat vu de notre camp au coup de sifflet final, sinon le dernier fait avec photo
## (seulement des faits déjà joués : rien n'annonce un temps fort à venir).
func _photo_faits(visibles: Array) -> void:
	if not is_instance_valid(photo_faits): return
	var id := ""
	# Équipe au premier plan de la photo : celle du fait (ou la nôtre pour le résultat), recolorée à ses couleurs.
	var equipe := int(_fin.get("camp", -1))
	if _fin.get("fini", false):
		var r := BanqueImages.resultat(_fin.get("score"), int(_fin.get("camp", -1)))
		if not r.is_empty(): id = BanqueImages.choisir("apres-match", {"resultat": r, "occasion": occasion_fin(_fin, r)})
	else:
		for n in range(visibles.size() - 1, maxi(-1, visibles.size() - 6), -1):
			id = photo_du_fait(str(visibles[n].get("kind", "")), str(visibles[n].get("texte", "")))
			if not id.is_empty():
				if visibles[n].get("equipe") != null and int(visibles[n].get("equipe")) in [0, 1]: equipe = int(visibles[n].get("equipe"))
				break
	photo_faits.texture = BanqueImages.texture(id) if not id.is_empty() else null
	photo_faits.material = null
	if not id.is_empty() and equipe in [0, 1] and terrain.couleurs.size() == 2:
		BanqueImages.recolorer(photo_faits, id, terrain.couleurs[equipe], terrain.couleurs[1 - equipe])
	photo_faits.set_meta("photo", id)

func _ligne_fil(entree: Dictionary, dernier: bool, en_bandeau: bool) -> Control:
	var kind := str(entree.get("kind", ""))
	var essai := kind == "try"
	var points := kind in ["try", "goal", "transformation"]
	var equipe := int(entree.get("equipe", -1)) if entree.get("equipe") != null else -1
	var teinte: Color = terrain.couleurs[equipe] if equipe in [0, 1] else FAIBLE
	# Minute en or, pictogramme du fait aux couleurs du club, texte ; les essais en ivoire gras.
	var ligne := PanelContainer.new()
	var fond := S.G.T.box(Color(OR, 0.12) if essai and not en_bandeau else Color(0, 0, 0, 0), maxi(4, px(10)))
	fond.content_margin_left = px(6)
	fond.content_margin_right = px(6)
	fond.content_margin_top = px(4)
	fond.content_margin_bottom = px(4)
	ligne.add_theme_stylebox_override("panel", fond)
	ligne.set_meta("i", int(entree.get("i", -1)))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE if en_bandeau else Control.MOUSE_FILTER_PASS
	var rang := S.G.h(px(14))
	ligne.add_child(rang)
	var heure := _texte(str(entree.get("horloge", "")), 30, OR if dernier or points else FAIBLE, false, true)
	heure.custom_minimum_size.x = px(56)
	heure.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rang.add_child(heure)
	var icone := Icone.new()
	icone.kind = kind
	icone.teinte = teinte
	icone.rouge = str(entree.get("texte", "")).to_lower().contains("rouge")
	icone.custom_minimum_size = Vector2(px(38), px(38))
	icone.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rang.add_child(icone)
	var texte := _texte(str(entree.get("texte", "")), 28 if en_bandeau or essai else 26, IVOIRE if dernier or points else DOUX, not en_bandeau, essai)
	texte.max_lines_visible = 1 if en_bandeau else (3 if dernier or essai else 2)
	texte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if en_bandeau: texte.clip_text = true
	S.G.fill(texte)
	rang.add_child(texte)
	return ligne

func _valeur(rang: Dictionary, cote: int) -> String:
	var valeurs: Array = rang.get("valeurs", [0, 0])
	if rang.get("vide", false): return "—"
	var texte := str(int(valeurs[cote])) + str(rang.get("unite", ""))
	if rang.get("sur") is Array: texte += "/%d" % int(rang.sur[cote])
	return texte

## Chiffre clé : libellé, valeur de l'équipe qui reçoit, barre comparée, valeur de l'autre.
func _ligne_chiffre(parent: Control, rang: Dictionary) -> void:
	var ligne := S.G.h(px(12))
	ligne.custom_minimum_size.y = px(30 if _journee_montree() else 40)
	S.G.fill(ligne, true)
	var titre := _texte(str(LIBELLES_COURTS.get(str(rang.get("cle", "")), rang.get("label", ""))), 26, DOUX)
	titre.tooltip_text = str(rang.get("label", ""))
	titre.mouse_filter = Control.MOUSE_FILTER_PASS
	titre.clip_text = true
	titre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titre.custom_minimum_size.x = px(120)
	S.G.fill(titre, false, 2.2)
	ligne.add_child(titre)
	var a := _texte(_valeur(rang, 0), 26 if _journee_montree() else 30, IVOIRE)
	a.add_theme_font_override("font", CHIFFRES_GRAS)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	a.custom_minimum_size.x = px(78)
	ligne.add_child(a)
	var barre := Barre.new()
	barre.valeurs = rang.get("valeurs", [0, 0]) if not rang.get("vide", false) else [0, 0]
	barre.couleurs = terrain.couleurs.duplicate()
	barre.densite = _densite
	barre.custom_minimum_size = Vector2(px(80), px(24))
	S.G.fill(barre, false, 1.2)
	ligne.add_child(barre)
	var b := _texte(_valeur(rang, 1), 26 if _journee_montree() else 30, IVOIRE)
	b.add_theme_font_override("font", CHIFFRES_GRAS)
	b.custom_minimum_size.x = px(78)
	ligne.add_child(b)
	parent.add_child(ligne)

func _remplir_chiffres(direct: Dictionary, _live: Dictionary) -> void:
	S.clear(chiffres)
	chiffres.add_theme_constant_override("separation", mini(8, px(2 if _journee_montree() else 6)))
	# Premières minutes : un « 100 % / 0 % » ne dit rien. Les parts restent masquées (« — ») et les
	# compteurs atténués jusqu'au seuil du moteur ; le titre dit quand la lecture deviendra fiable.
	echantillon_court = est_court(direct)
	chiffres.modulate = Color(1, 1, 1, ATTENUE) if echantillon_court else Color.WHITE
	if is_instance_valid(precision_chiffres):
		precision_chiffres.text = ("trop tôt pour conclure · %d′" % seuil_echantillon(direct)) if echantillon_court else "comparées"
	var rangs: Array = direct.get("tableau", [])
	var par_cle := {}
	for rang: Dictionary in rangs: par_cle[str(rang.get("cle", ""))] = rang
	# Dix stats comparées, toujours dans le même ordre (« — » tant qu'une stat est vide).
	for cle: String in STATS:
		if par_cle.has(cle): _ligne_chiffre(chiffres, par_cle[cle])
	_rangs = rangs
	_remplir_anneaux(direct)
	_remplir_zone22(direct)

## Journée en direct (`direct.journee`) : classement en direct et multiplex, masqués sans elle.
func _remplir_journee(model: Dictionary, direct: Dictionary, equipes: Array) -> void:
	if not is_instance_valid(classement_tuile) or not is_instance_valid(multiplex): return
	var journee: Variant = direct.get("journee")
	if not journee is Dictionary: journee = null
	var cle := JSON.stringify(journee)
	if cle == _journee_cle: return
	_journee_cle = cle
	journee_vue = journee
	var avant := classement_tuile.visible
	if journee == null:
		classement_tuile.visible = false
		multiplex.visible = false
		_journee_minute = -1
		_scores_cour = {}
		_scores_prec = {}
		if avant: _resserrer(direct)
		return
	var teintes := _teintes_clubs(model, equipes)
	_remplir_classement(journee.get("classement", []) if journee.get("classement") is Array else [], teintes)
	_remplir_multiplex(journee, teintes)
	if avant != classement_tuile.visible: _resserrer(direct)

## Le classement en direct prend place sous le duel : duel resserré, faits marquants réduits.
func _resserrer(direct: Dictionary) -> void:
	var serre := _journee_montree()
	for n in _tuiles_droite.size():
		var marge: MarginContainer = _tuiles_droite[n]
		for bord in ["left", "top", "right", "bottom"]: marge.add_theme_constant_override("margin_" + bord, px(10 if serre else [16, 14, 14][n]))
		(marge.get_child(0) as VBoxContainer).add_theme_constant_override("separation", mini(8, px(6 if serre else 10)))
	_remplir_chiffres(direct, {})
	_remplir_fil()

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
	var debut := clampi(nous - 3, 0, n - fenetre)
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
	# En 1280×720, notre voisinage seul (± 3 places) ; plus grand, le haut du tableau en plus.
	for k: int in lignes_classement(classement, CLASSEMENT_LIGNES if _densite >= 0.6 else 7):
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
	var fond := S.G.T.box(Color(OR, 0.16) if nous else Color(1, 1, 1, 0.025 if int(r.get("rang", 0)) % 2 == 1 else 0.0), maxi(3, px(8)))
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
		var style := S.G.T.box(Color(VERT_SCORE, 0.18) if badge[1] == "BO" else Color(OR, 0.16), maxi(3, px(6)))
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
	# Une seule rangée jusqu'à huit matchs (championnat de seize clubs), deux au-delà.
	multiplex_cartes.columns = matchs.size() if matchs.size() <= 8 else ceili(matchs.size() / 2.0)
	for m: Variant in matchs:
		if not m is Dictionary: continue
		var id := str(m.get("id", ""))
		var change: bool = _scores_prec.has(id) and _scores_prec[id] != scores[id]
		var carte := _carte_match(m, change, teintes)
		carte.name = "MatchBetweenMultiplexMatch%d" % multiplex_cartes.get_child_count()
		multiplex_cartes.add_child(carte)

func _carte_match(m: Dictionary, change: bool, teintes: Dictionary) -> Control:
	var carte := PanelContainer.new()
	carte.name = "MatchBetweenMultiplexMatch"
	carte.set_meta("id", str(m.get("id", "")))
	carte.set_meta("change", change)
	var style := S.G.T.box(Color(RELIEF, 0.97), maxi(4, px(10)))
	style.content_margin_left = px(10)
	style.content_margin_right = px(10)
	style.content_margin_top = px(4)
	style.content_margin_bottom = px(4)
	if change:
		style.set_border_width_all(maxi(1, px(3)))
		style.border_color = VERT_SCORE
	carte.add_theme_stylebox_override("panel", style)
	carte.custom_minimum_size.x = px(180)
	var fini := bool(m.get("fini", false))
	var cotes: Array = [m.get("home", {}), m.get("away", {})]
	carte.tooltip_text = "%s %d – %d %s · %s" % [str(cotes[0].get("nom", "")), int(cotes[0].get("score", 0)), int(cotes[1].get("score", 0)), str(cotes[1].get("nom", "")), "terminé" if fini else "%d′" % int(m.get("minute", 0))]
	var rang := S.G.h(px(10))
	rang.add_theme_constant_override("separation", px(10))
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
		nom_club.custom_minimum_size.x = px(56)
		ligne.add_child(nom_club)
		var essais := int(club.get("essais", 0))
		var petit := _cellule("(%d)" % essais if essais > 0 else "", 24, FAIBLE, 20, true)
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

## Mon XV : tableau complet, une ligne par joueur (numéro, nom, poste, note colorée, jauge
## d'énergie, plaquages, mètres, essais) ; alertes en infobulle ; un clic ouvre le banc sur lui.
func _remplir_xv(joueurs: Array, direct: Dictionary) -> void:
	_xv_donnees = [joueurs, direct]
	S.clear(xv)
	# Vue Terrain et carte Changement : toujours tenues à jour (mêmes données que le tableau).
	var infos := _infos_xv(joueurs, direct)
	_remplir_formation(infos)
	_remplir_changement(infos)
	# Onglet adverse : les alertes de Mon XV restent calculées pour Gabi.
	if vue_xv == "adverse":
		_alertes_seules(joueurs, direct)
		_remplir_xv_adverse(direct)
		return
	alertes_xv.clear()
	var notes: Dictionary = direct.get("notes", {}) if direct.get("notes") is Dictionary else {}
	var feuille: Dictionary = direct.get("feuille", {}) if direct.get("feuille") is Dictionary else {}
	var cartons: Dictionary = {}
	for carton: Variant in direct.get("cartons", []):
		if carton is Dictionary: cartons[str(carton.get("id", ""))] = carton
	if joueurs.is_empty():
		xv.add_child(_texte("Composition indisponible.", 26, DOUX, true))
		return
	var hauteur := px(38 if _densite >= 0.6 else 33)
	for poste in joueurs.size():
		var joueur: Variant = joueurs[poste]
		var case := Button.new()
		case.name = "MatchBetweenPlayer%d" % (poste + 1)
		case.flat = true
		case.focus_mode = Control.FOCUS_ALL
		case.set_meta("contextual_enabled", true)
		case.pressed.connect(func(): joueur_choisi.emit(poste))
		# Une ligne sur deux très légèrement teintée : l'œil suit la ligne d'un bout à l'autre.
		var vide := S.G.T.box(Color(1, 1, 1, 0.03 if poste % 2 == 0 else 0.0), maxi(3, px(8)))
		case.add_theme_stylebox_override("normal", vide)
		case.add_theme_stylebox_override("pressed", vide)
		var survol := S.G.T.box(SURVOL, maxi(3, px(8)))
		var focus := S.G.T.box(Color.TRANSPARENT, maxi(3, px(8)), OR)
		for style: StyleBox in [vide, survol, focus]: style.set_content_margin_all(0)
		case.add_theme_stylebox_override("hover", survol)
		case.add_theme_stylebox_override("focus", focus)
		S.G.fill(case, true)
		case.custom_minimum_size.y = hauteur
		var ligne := S.G.h(px(8))
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		S.full(ligne)
		case.add_child(ligne)
		var pastille := W.Numero.new()
		pastille.numero = str(poste + 1)
		pastille.densite = _densite
		pastille.teinte = terrain.couleurs[terrain.camp] if terrain.camp in [0, 1] else W.VERT
		pastille.custom_minimum_size = Vector2(px(int(COLONNES_XV[0][1])), hauteur)
		ligne.add_child(pastille)
		if not joueur is Dictionary:
			ligne.add_child(_cellule("Poste vacant", 0, FAIBLE))
			case.tooltip_text = "%d · poste vacant" % (poste + 1)
			xv.add_child(case)
			continue
		var d := W.donnees_joueur(joueur, notes, cartons, feuille)
		var id: String = d.id
		var note: float = d.note
		var condition: float = d.energie
		ligne.add_child(_cellule(_nom_court(str(d.nom)), 0, IVOIRE, 28))
		var humeur := Pilotage.etat_joueur(_pilotage, id)
		if not humeur.is_empty():
			var cellule_etat := _etiquette_etat(humeur, px(22), false)
			S.G.fill(cellule_etat, false, 0.8)
			ligne.add_child(cellule_etat)
		ligne.add_child(_cellule(poste_court(str(d.poste)), int(COLONNES_XV[2][1]), FAIBLE, 22))
		# Note dans une pastille teintée, énergie en jauge, puis les chiffres du joueur.
		var cadre_note := PanelContainer.new()
		cadre_note.add_theme_stylebox_override("panel", S.G.T.box(Color(_teinte_note(note), 0.16), maxi(3, px(8))))
		cadre_note.custom_minimum_size = Vector2(px(int(COLONNES_XV[3][1])), 0)
		cadre_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cadre_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var etiquette_note := _cellule("%.1f" % note, 0, _teinte_note(note), 28, true)
		etiquette_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cadre_note.add_child(etiquette_note)
		ligne.add_child(cadre_note)
		var jauge := W.Jauge.new()
		jauge.valeur = condition
		jauge.densite = _densite
		jauge.custom_minimum_size = Vector2(px(int(COLONNES_XV[4][1])), hauteur)
		ligne.add_child(jauge)
		ligne.add_child(_cellule(str(d.get("plaquages", 0)), int(COLONNES_XV[5][1]), IVOIRE, 28, true))
		ligne.add_child(_cellule(str(d.metres), int(COLONNES_XV[6][1]), IVOIRE, 28, true))
		ligne.add_child(_cellule(str(d.essais) if int(d.essais) > 0 else "–", int(COLONNES_XV[7][1]), OR if int(d.essais) > 0 else FAIBLE, 28, true))
		# Nom complet gardé pour les lecteurs d'écran et les tests, montré en infobulle.
		var nom := _texte(str(joueur.get("name", "")), 20, FAIBLE)
		nom.visible = false
		ligne.add_child(nom)
		var info: Dictionary = infos[poste]
		var alerte: String = info.alerte
		pastille.marque = info.marque
		if not alerte.is_empty(): alertes_xv.append({"poste": poste, "id": id, "nom": str(joueur.get("name", "")), "alerte": alerte, "condition": condition})
		case.tooltip_text = str(info.detail)
		xv.add_child(case)
	_ligne_equipe(feuille, int(direct.get("camp", -1)), joueurs.map(func(j: Variant) -> String: return str(j.get("id", "")) if j is Dictionary else ""))

## Données de Notre XV, poste par poste, partagées par le tableau, la vue Terrain et la carte
## Changement : données du joueur (`W.donnees_joueur`), alerte, marque de l'anneau, infobulle.
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
			infos.append({"vacant": true, "alerte": "", "marque": Color.TRANSPARENT, "detail": "%d · poste vacant" % (poste + 1)})
			continue
		var d := W.donnees_joueur(joueur, notes, cartons, feuille)
		var id: String = d.id
		var fiche: Dictionary = notes.get(id, {}) if notes.get(id) is Dictionary else {}
		var condition: float = d.energie
		var alerte := ""
		if d.blesse: alerte = "blessé"
		elif cartons.has(id): alerte = "carton jaune, retour %s′" % str(cartons[id].get("retour", "")) if cartons[id].get("retour") != null else "exclu"
		elif condition < EPUISE: alerte = "épuisé"
		elif condition < FATIGUE: alerte = "fatigué"
		var marque := Color.TRANSPARENT
		if alerte == "blessé": marque = ALERTE
		elif alerte.begins_with("carton") or alerte == "exclu": marque = Color("e8c24a")
		var plaq := int(d.get("plaquages", 0))
		var detail := "%d · %s · %s\nÉnergie %d %%, note %.1f (%d action%s du match), %d plaquage%s" % [poste + 1, str(joueur.get("pos", "")), str(joueur.get("name", "")), roundi(condition), float(d.note), int(fiche.get("faits", 0)), "s" if int(fiche.get("faits", 0)) > 1 else "", plaq, "s" if plaq > 1 else ""]
		if not feuille.is_empty(): detail += " (%d manqué%s), %d course%s, %d passe%s" % [int(d.plaquages_manques), "s" if int(d.plaquages_manques) > 1 else "", int(d.courses), "s" if int(d.courses) > 1 else "", int(d.passes), "s" if int(d.passes) > 1 else ""]
		if not alerte.is_empty(): detail += "\n" + alerte.capitalize()
		var humeur := Pilotage.etat_joueur(_pilotage, id)
		if not humeur.is_empty(): detail += "\nAprès la causerie : " + str(humeur.label).to_lower()
		var info := d.duplicate()
		info.merge({"alerte": alerte, "marque": marque, "carton": cartons.has(id), "etat": humeur, "detail": detail + "\nCliquer : ouvrir le banc sur ce joueur."}, true)
		infos.append(info)
	return infos

## Vue Terrain : un bouton par joueur à son poste (anneau d'énergie, numéro, nom court, note) ;
## un clic ouvre le banc sur lui, l'infobulle est celle de sa ligne du tableau.
func _remplir_formation(infos: Array) -> void:
	if not is_instance_valid(formation): return
	for enfant in formation.get_children():
		formation.remove_child(enfant)
		enfant.queue_free()
	formation.cases.clear()
	formation.anneaux.clear()
	formation.avec_etats = infos.any(func(i: Dictionary) -> bool: return i.get("etat") is Dictionary and not (i.etat as Dictionary).is_empty())
	for poste in mini(infos.size(), Formation.PLACES.size()):
		var info: Dictionary = infos[poste]
		var case := Button.new()
		case.name = "MatchBetweenFormationPlayer%d" % (poste + 1)
		case.flat = true
		case.focus_mode = Control.FOCUS_ALL
		case.set_meta("contextual_enabled", true)
		case.tooltip_text = str(info.detail)
		case.pressed.connect(func(): joueur_choisi.emit(poste))
		var vide := StyleBoxEmpty.new()
		var survol := S.G.T.box(Color(1, 1, 1, 0.08), maxi(3, px(10)))
		var focus := S.G.T.box(Color.TRANSPARENT, maxi(3, px(10)), OR)
		focus.set_border_width_all(maxi(1, px(2)))
		for style: StyleBox in [survol, focus]: style.set_content_margin_all(0)
		case.add_theme_stylebox_override("normal", vide)
		case.add_theme_stylebox_override("pressed", vide)
		case.add_theme_stylebox_override("hover", survol)
		case.add_theme_stylebox_override("focus", focus)
		var pile := S.G.v(px(4))
		pile.alignment = BoxContainer.ALIGNMENT_CENTER
		pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		S.full(pile)
		case.add_child(pile)
		var anneau := Energie.new()
		anneau.valeur = float(info.get("energie", 100.0))
		anneau.numero = str(poste + 1)
		anneau.densite = _densite
		anneau.marque = info.marque
		anneau.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pile.add_child(anneau)
		# Nom court et note sur une pastille sombre : lisibles sur le vert.
		var etiquette := PanelContainer.new()
		var fond := S.G.T.box(Color(FOND, 0.78), maxi(3, px(8)))
		fond.content_margin_left = px(8)
		fond.content_margin_right = px(8)
		fond.content_margin_top = 0
		fond.content_margin_bottom = 0
		etiquette.add_theme_stylebox_override("panel", fond)
		etiquette.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pile.add_child(etiquette)
		var ligne := S.G.h(px(6))
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		etiquette.add_child(ligne)
		var vacant: bool = info.get("vacant", false)
		var nom := _texte("Vacant" if vacant else _nom_court(str(info.nom)), 26, FAIBLE if vacant else IVOIRE, false, true)
		nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(nom)
		if not vacant:
			var note := _texte("%.1f" % float(info.note), 26, _teinte_note(float(info.note)))
			note.add_theme_font_override("font", CHIFFRES_GRAS)
			note.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ligne.add_child(note)
		var humeur: Dictionary = info.get("etat") if info.get("etat") is Dictionary else {}
		if not humeur.is_empty(): pile.add_child(_etiquette_etat(humeur, maxi(13, px(22)), true))
		formation.add_child(case)
		formation.cases.append(case)
		formation.anneaux.append(anneau)
	formation.placer()
	formation.queue_redraw()

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

## Carte Changement : le joueur du XV le plus en difficulté (blessé, sinon l'énergie la plus basse,
## les joueurs sanctionnés mis à part) s'il est blessé ou sous le seuil de fatigue ; le bouton ouvre
## le banc sur lui. Le remplaçant reste le choix du manager.
func _remplir_changement(infos: Array) -> void:
	if not is_instance_valid(changement): return
	S.clear(changement)
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
	var colonne := S.G.v(px(2))
	colonne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	S.G.fill(colonne)
	colonne.add_child(_texte("CHANGEMENT", 26, FAIBLE, false, true))
	if urgent:
		var info: Dictionary = infos[choisi]
		var anneau := Energie.new()
		anneau.name = "MatchBetweenSwapEnergy"
		anneau.valeur = float(info.energie)
		anneau.numero = str(choisi + 1)
		anneau.densite = _densite
		anneau.marque = info.marque
		anneau.custom_minimum_size = Vector2(px(76), px(76))
		anneau.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		anneau.tooltip_text = str(info.detail)
		anneau.mouse_filter = Control.MOUSE_FILTER_PASS
		changement.add_child(anneau)
		var nom := _texte("%s · %s" % [_nom_court(str(info.nom)), poste_court(str(info.poste))], 30, IVOIRE, false, true)
		nom.clip_text = true
		nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		colonne.add_child(nom)
		var etat_joueur := "Énergie %d %%" % roundi(float(info.energie)) + (" · blessé" if info.blesse else "")
		var ligne_energie := _texte(etat_joueur, 26, ALERTE if info.blesse or float(info.energie) < EPUISE else Energie.teinte_pour(float(info.energie)))
		ligne_energie.name = "MatchBetweenSwapEnergyText"
		colonne.add_child(ligne_energie)
	else:
		var calme := _texte("Aucun changement urgent", 28, DOUX)
		calme.clip_text = true
		calme.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		colonne.add_child(calme)
	changement.add_child(colonne)
	var poste := choisi
	var bouton := _bouton("Préparer le changement", func(): joueur_choisi.emit(poste), true, true) if urgent else _bouton("Ouvrir le banc", func(): tiroir_demande.emit("Banc"))
	bouton.name = "MatchBetweenSwapAction"
	bouton.custom_minimum_size.y = px(56)
	bouton.add_theme_font_size_override("font_size", px(26))
	bouton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bouton.tooltip_text = "Ouvrir le banc sur ce joueur (le match se met en pause)." if urgent else "Ouvrir le banc (le match se met en pause)."
	bouton.set_meta("contextual_enabled", true)
	changement.add_child(bouton)

## Anneaux possession et occupation : les parts du moteur (`direct.tableau`), « — » tant que la
## part est vide ou l'échantillon court.
func _remplir_anneaux(direct: Dictionary) -> void:
	var court := est_court(direct)
	var camp := int(direct.get("camp", -1))
	var sigles: Array = domination.sigles if is_instance_valid(domination) else ["", ""]
	for paire: Array in [[anneau_possession, "possession", "Possession"], [anneau_occupation, "occupation", "Occupation"]]:
		var anneau: Anneau = paire[0]
		if not is_instance_valid(anneau): continue
		var rang: Dictionary = {}
		for r: Variant in direct.get("tableau", []):
			if r is Dictionary and str(r.get("cle", "")) == paire[1]: rang = r
		anneau.couleurs = terrain.couleurs.duplicate()
		anneau.camp = camp if camp in [0, 1] else 0
		anneau.valeurs = rang.get("valeurs", [0, 0]) if not rang.is_empty() else [0, 0]
		anneau.vide = rang.is_empty() or bool(rang.get("vide", false)) or court
		anneau.tooltip_text = "%s : trop tôt pour conclure." % paire[2] if anneau.vide else "%s : %s %d %% · %s %d %%" % [paire[2], str(sigles[0]), roundi(float(anneau.valeurs[0])), str(sigles[1]), roundi(float(anneau.valeurs[1]))]
		anneau.queue_redraw()

## Tuile « Dans les 22 » (`direct.zone22` : entrées, points et secondes par équipe) : un carré par
## entrée aux couleurs du club, les points, les points par entrée, le temps passé. Sans la donnée,
## la tuile reste masquée.
func _remplir_zone22(direct: Dictionary) -> void:
	if not is_instance_valid(zone22): return
	var z: Variant = direct.get("zone22")
	var valide := z is Dictionary and z.get("entrees") is Array and (z.entrees as Array).size() == 2
	zone22.visible = valide
	S.clear(zone22_contenu)
	if not valide: return
	var points: Array = z.get("points", [0, 0]) if z.get("points") is Array and (z.points as Array).size() == 2 else [0, 0]
	var secondes: Array = z.get("secondes", [0, 0]) if z.get("secondes") is Array and (z.secondes as Array).size() == 2 else [0, 0]
	for cote in 2:
		var entrees := int(z.entrees[cote])
		var marques := int(points[cote])
		var duree := int(secondes[cote])
		var bloc := S.G.v(px(2))
		bloc.name = "MatchBetweenZone22Team%d" % cote
		zone22_contenu.add_child(bloc)
		var ligne := S.G.h(px(10))
		bloc.add_child(ligne)
		var sigle := _texte(str(domination.sigles[cote]) if is_instance_valid(domination) else "", 28, terrain.couleurs[cote].lightened(0.15), false, true)
		sigle.custom_minimum_size.x = px(70)
		ligne.add_child(sigle)
		var carres := S.G.h(px(5))
		carres.name = "MatchBetweenZone22Entries%d" % cote
		S.G.fill(carres)
		ligne.add_child(carres)
		for k in mini(entrees, 10):
			var carre := Carre.new()
			carre.teinte = terrain.couleurs[cote]
			carre.custom_minimum_size = Vector2(px(22), px(22))
			carre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			carre.mouse_filter = Control.MOUSE_FILTER_IGNORE
			carres.add_child(carre)
		if entrees > 10: carres.add_child(_texte("+%d" % (entrees - 10), 26, DOUX))
		if entrees == 0: carres.add_child(_texte("aucune entrée", 26, FAIBLE))
		var total := _texte("%d pt%s" % [marques, "s" if marques > 1 else ""], 30, IVOIRE)
		total.add_theme_font_override("font", CHIFFRES_GRAS)
		ligne.add_child(total)
		var ratio := ("%.1f" % (float(marques) / float(entrees))).replace(".", ",") if entrees > 0 else "—"
		var detail := _texte("%d entrée%s · %s pt/entrée · %d:%02d" % [entrees, "s" if entrees > 1 else "", ratio, floori(duree / 60.0), duree % 60], 26, DOUX)
		detail.clip_text = true
		detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		bloc.add_child(detail)
	zone22.tooltip_text = "Entrées dans les 22 mètres adverses, points marqués et temps passé dans la zone."

## Ligne « Équipe » sous un XV : plaquages, mètres et essais de toute l'équipe (feuille de statistiques),
## remplaçants sortis compris. Le total est la somme des joueurs de la feuille ; l'écart avec la somme
## des quinze lignes au-dessus est le travail des joueurs déjà remplacés, dit dans l'infobulle.
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
	ligne.custom_minimum_size.y = px(40)
	ligne.name = "MatchBetweenTeamTotal"
	ligne.tooltip_text = "Total de l'équipe, remplaçants sortis compris (%d plaquage%s, %d m, %d essai%s déjà aux joueurs remplacés)." % [sortis.plaquages, "s" if sortis.plaquages > 1 else "", sortis.metres, sortis.essais, "s" if sortis.essais > 1 else ""]
	ligne.mouse_filter = Control.MOUSE_FILTER_STOP
	var trait_haut := ColorRect.new()
	trait_haut.color = Color(OR, 0.35)
	trait_haut.custom_minimum_size = Vector2(0, maxi(1, px(2)))
	trait_haut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xv.add_child(trait_haut)
	var vide := Control.new()
	vide.custom_minimum_size = Vector2(px(int(COLONNES_XV[0][1])), 0)
	ligne.add_child(vide)
	ligne.add_child(_cellule("ÉQUIPE", 0, OR, 24))
	ligne.add_child(_cellule("", int(COLONNES_XV[2][1]), FAIBLE, 22))
	ligne.add_child(_cellule("", int(COLONNES_XV[3][1]), FAIBLE, 22))
	ligne.add_child(_cellule("", int(COLONNES_XV[4][1]), FAIBLE, 22))
	ligne.add_child(_cellule(str(total.plaquages), int(COLONNES_XV[5][1]), OR, 28, true))
	ligne.add_child(_cellule(str(total.metres), int(COLONNES_XV[6][1]), OR, 28, true))
	ligne.add_child(_cellule(str(total.essais) if total.essais > 0 else "–", int(COLONNES_XV[7][1]), OR, 28, true))
	xv.add_child(ligne)

## XV adverse (`direct.adversaire`) : le même tableau, aux couleurs adverses ; la feuille actuelle
## (ses remplacements se voient tout de suite), notes bornées aux faits montrés.
func _remplir_xv_adverse(direct: Dictionary) -> void:
	var liste: Array = direct.get("adversaire", []) if direct.get("adversaire") is Array else []
	var camp := int(direct.get("camp", -1))
	if liste.is_empty():
		xv.add_child(_texte("Composition adverse pas encore vue.", 26, DOUX, true))
		return
	var hauteur := px(38 if _densite >= 0.6 else 33)
	for poste in liste.size():
		var j: Variant = liste[poste]
		var case := Button.new()
		case.name = "MatchBetweenOpponent%d" % (poste + 1)
		case.flat = true
		case.focus_mode = Control.FOCUS_NONE
		case.mouse_filter = Control.MOUSE_FILTER_PASS
		var fond := S.G.T.box(Color(1, 1, 1, 0.03 if poste % 2 == 0 else 0.0), maxi(3, px(8)))
		fond.set_content_margin_all(0)
		for etat_bouton in ["normal", "hover", "pressed", "focus"]: case.add_theme_stylebox_override(etat_bouton, fond)
		S.G.fill(case, true)
		case.custom_minimum_size.y = hauteur
		var ligne := S.G.h(px(8))
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		S.full(ligne)
		case.add_child(ligne)
		var pastille := W.Numero.new()
		pastille.numero = str(poste + 1)
		pastille.densite = _densite
		pastille.teinte = terrain.couleurs[1 - camp] if camp in [0, 1] else ALERTE
		pastille.custom_minimum_size = Vector2(px(int(COLONNES_XV[0][1])), hauteur)
		ligne.add_child(pastille)
		if not j is Dictionary:
			ligne.add_child(_cellule("Poste vacant", 0, FAIBLE))
			xv.add_child(case)
			continue
		var note := float(j.get("note", NOTE_DEPART))
		ligne.add_child(_cellule(_nom_court(str(j.get("nom", ""))), 0, IVOIRE, 28))
		ligne.add_child(_cellule(poste_court(str(j.get("poste", ""))), int(COLONNES_XV[2][1]), FAIBLE, 22))
		var cadre_note := PanelContainer.new()
		cadre_note.add_theme_stylebox_override("panel", S.G.T.box(Color(_teinte_note(note), 0.16), maxi(3, px(8))))
		cadre_note.custom_minimum_size = Vector2(px(int(COLONNES_XV[3][1])), 0)
		cadre_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cadre_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var etiquette_note := _cellule("%.1f" % note, 0, _teinte_note(note), 28, true)
		etiquette_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cadre_note.add_child(etiquette_note)
		ligne.add_child(cadre_note)
		if j.get("energie") != null:
			var jauge := W.Jauge.new()
			jauge.valeur = float(j.energie)
			jauge.densite = _densite
			jauge.custom_minimum_size = Vector2(px(int(COLONNES_XV[4][1])), hauteur)
			ligne.add_child(jauge)
		else: ligne.add_child(_cellule("—", int(COLONNES_XV[4][1]), FAIBLE, 26, true))
		ligne.add_child(_cellule(str(int(j.get("plaquages", 0))), int(COLONNES_XV[5][1]), IVOIRE, 28, true))
		ligne.add_child(_cellule(str(int(j.get("metres", 0))), int(COLONNES_XV[6][1]), IVOIRE, 28, true))
		var essais := int(j.get("essais", 0))
		ligne.add_child(_cellule(str(essais) if essais > 0 else "–", int(COLONNES_XV[7][1]), OR if essais > 0 else FAIBLE, 28, true))
		var nom := _texte(str(j.get("nom", "")), 20, FAIBLE)
		nom.visible = false
		ligne.add_child(nom)
		case.tooltip_text = "%d · %s · %s\nNote %.1f (%d action%s montrée%s)" % [poste + 1, str(j.get("poste", "")), str(j.get("nom", "")), note, int(j.get("faits", 0)), "s" if int(j.get("faits", 0)) > 1 else "", "s" if int(j.get("faits", 0)) > 1 else ""]
		xv.add_child(case)
	var feuille: Dictionary = direct.get("feuille", {}) if direct.get("feuille") is Dictionary else {}
	_ligne_equipe(feuille, 1 - camp, liste.map(func(j: Variant) -> String: return str(j.get("joueur", "")) if j is Dictionary else ""))

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
		elif cartons.has(id): alerte = "carton jaune, retour %s′" % str(cartons[id].get("retour", "")) if cartons[id].get("retour") != null else "exclu"
		elif condition < EPUISE: alerte = "épuisé"
		elif condition < FATIGUE: alerte = "fatigué"
		if not alerte.is_empty(): alertes_xv.append({"poste": poste, "id": id, "nom": str(joueur.get("name", "")), "alerte": alerte, "condition": condition})

## Note de départ du moteur (match-direct.cjs, NOTE_DEPART) : titulaire au coup d'envoi, remplaçant à son entrée.
const NOTE_DEPART := 6.5
## Couleur de la note du match : vert au-dessus de 7, ivoire autour de 6,5, jaune sous 6,5,
## alerte sous 6 (6,5 au coup d'envoi).
static func _teinte_note(note: float) -> Color:
	if note >= 7.5: return Color("82e3a3")
	if note >= 7.0: return Color("65b081")
	if note >= 6.5: return IVOIRE
	if note >= 6.0: return Color("c9c46a")
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
	portrait.custom_minimum_size = Vector2(px(80), px(80))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var matte := ShaderMaterial.new()
	matte.shader = MATTE
	portrait.material = matte
	carte.add_child(portrait)
	var colonne := S.G.v(px(8))
	S.G.fill(colonne)
	carte.add_child(colonne)
	colonne.add_child(_texte("Gabi, ton adjoint", 22, FAIBLE))
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
		phrases.append([texte, Color("f0b080")])
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
		var etiquette := _texte(str(phrase[0]), 28 if phrase[1] == DOUX else 32, phrase[1], true, true)
		etiquette.max_lines_visible = 3
		etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		etiquette.tooltip_text = "\n".join(raisons) if not raisons.is_empty() else str(phrase[0])
		etiquette.mouse_filter = Control.MOUSE_FILTER_PASS
		colonne.add_child(etiquette)
	# Les actions à droite de la carte (Gabi en largeur, sous le tableau de bord).
	var actions := S.G.h(px(10))
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if fini: _remplir_pourquoi(colonne, direct, actions)
	carte.add_child(actions)
	# L'action qui va avec la phrase : remplacer le joueur signalé, ou appliquer les consignes
	# proposées (seulement si l'adjoint propose autre chose que les consignes en place).
	if remplacer >= 0:
		var poste := remplacer
		var bouton_remplacer := _bouton("Remplacer le %d" % (poste + 1), func(): joueur_choisi.emit(poste), true, true)
		bouton_remplacer.name = "MatchBetweenReplace"
		bouton_remplacer.custom_minimum_size.y = px(56)
		bouton_remplacer.tooltip_text = "Ouvrir le banc sur ce joueur."
		bouton_remplacer.set_meta("contextual_enabled", true)
		actions.add_child(bouton_remplacer)
	elif not fini and conseil is Dictionary and (conseil.get("attackChanged", false) or conseil.get("defenceChanged", false)):
		var possible: bool = conseil.get("canAct", false) and conseil.get("defenceAvailable", false)
		var bouton := _bouton("Appliquer", func(): appliquer.call(conseil), possible, true)
		bouton.name = "MatchBetweenApplyAdvice"
		bouton.custom_minimum_size.y = px(56)
		bouton.tooltip_text = "Appliquer les consignes proposées." if possible else "Mets le match en pause pour modifier tes consignes."
		actions.add_child(bouton)

const LEVIER_TEINTES := {"composition": Color("8fb3e0"), "condition": Color("9fd39a"), "tactique": Color("e0b35a"), "discipline": Color("f0b080"), "preparation": Color("c9a4e8")}

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
		var texte := _texte(str(raison.get("texte", "")), 22, IVOIRE if raison.get("sens") == "negatif" else Color("cfe8c8"), true)
		texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texte.max_lines_visible = 2
		texte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		texte.tooltip_text = str(raison.get("texte", ""))
		texte.mouse_filter = Control.MOUSE_FILTER_PASS
		ligne.add_child(texte)
		var route := str(raison.get("route", ""))
		if route.is_empty() or routes.has(route): continue
		routes[route] = true
		var bouton := _bouton(str(raison.get("action", "Voir")), func(): levier_choisi.emit(route), true, routes.size() == 1)
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
	if valeur.is_empty():
		arret.hide()
		return
	var titre := "CARTON ROUGE" if valeur.get("rouge", false) else "CARTON JAUNE"
	arret_titre.text = "%s · %s" % [titre, str(valeur.get("horloge", ""))]
	arret_texte.text = str(valeur.get("texte", "")) + "\nLe match est en pause : réorganise ton équipe si besoin, puis reprends."
	arret.show()
