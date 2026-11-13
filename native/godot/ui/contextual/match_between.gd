extends Control
## Écran intermédiaire du match en temps forts (mode de base ; repli CD_MATCH_TEMPS_FORTS=0).
##
## Entre deux temps forts, le match continue sur un terrain vu de dessus (`match_terrain_2d.gd`) :
## trente pastilles numérotées rejouent les faits du moteur pendant que l'horloge défile. Autour,
## un tableau de bord inspiré des écrans « match overview » des jeux de management de football,
## adapté au rugby : domination minute par minute, chiffres clés comparés, fil, Mon XV (note,
## énergie, alertes), regard de l'adjoint et accès direct à la tactique et aux remplacements.
## Une seule mise en page (choix de Léo, 12 novembre 2026, rendu 1) : un tableau de bord en
## tuiles façon FM, terrain 2D petit en haut au centre ; Mon XV en tableau complet est la tuile
## principale (à gauche, en relief) ; momentum et faits marquants au centre ; Gabi et douze stats
## comparées à droite. Il n'affiche que la projection `live.direct` du moteur et le modèle : aucun calcul sportif.
const S = preload("res://ui/contextual/skin.gd")
const T = preload("res://theme.gd")
const Terrain2D = preload("res://ui/contextual/match_terrain_2d.gd")
const W = preload("res://ui/contextual/match_tableau_widgets.gd")

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
## Score du dernier fait joué sur le terrain (le moteur a parfois une minute d'avance).
signal score_joue(score: Array)
## Caméra du direct 3D choisie dans le menu Plus (« tv », « tactical », « action »).
signal camera_demandee(mode: String)
## Bande de la vue du match (sous le score) qui porte la barre de commandes, la même en 3D et
## pendant l'entracte ; sans elle, la barre reste en haut de l'écran intermédiaire.
var hote_barre: Control

## Libellés courts des stats comparées (le libellé complet en infobulle) : rien de tronqué.
const LIBELLES_COURTS := {"metres": "Mètres gagnés", "franchissements": "Franchissements", "plaquages": "Plaquages",
	"plaquages_manques": "Plaq. manqués", "recuperations": "Récupérations", "melees": "Mêlées", "touches": "Touches",
	"penalites": "Pénalités", "en_avant": "En-avant", "pieds": "Jeu au pied"}
## Les douze stats comparées de la tuile Statistiques (le reste dans le tiroir, menu Plus).
const STATS := ["possession", "occupation", "metres", "franchissements", "plaquages", "plaquages_manques",
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
## Onglets de la tuile principale : Mon XV ou le XV adverse (`direct.adversaire`).
var onglet_adverse := false
var onglets: Array[Button] = []
var _xv_donnees: Array = []
var _equipes: Array = []
## Tuile principale (Mon XV) : l'œil commence par elle.
var tuile_principale: PanelContainer
## Alertes de Mon XV (fatigue, blessure, carton) : pour l'adjoint et les tests.
var alertes_xv: Array[Dictionary] = []

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
	domination.custom_minimum_size = Vector2(0, px(150))
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

## Carte de Gabi (portrait, une phrase, l'action proposée) dans un panneau en relief.
func _carte_gabi(parent: Control) -> void:
	var cadre := _panneau(parent, px(18), Color(RELIEF, 0.97))
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

## Tableau de bord en tuiles (rendu 1 retenu) : la barre de commandes, puis trois colonnes.
## Gauche : Mon XV (onglet : le XV adverse), tuile principale en relief. Centre : terrain
## 2D petit (dernier fait en bandeau au-dessus), momentum, faits marquants. Droite : Gabi, stats.
func _page() -> void:
	var page := S.G.v(px(18))
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
	# Gauche : Mon XV (tuile principale).
	var gauche := S.G.v(px(20))
	gauche.custom_minimum_size.x = px(860)
	grille.add_child(gauche)
	var cadre_xv := _panneau(gauche, px(22), Color(RELIEF, 0.98))
	tuile_principale = cadre_xv.get_parent().get_parent()
	tuile_principale.name = "MatchBetweenMain"
	S.G.fill(tuile_principale, true)
	var bord := tuile_principale.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	bord.border_width_left = maxi(2, px(5))
	bord.border_color = Color(OR, 0.85)
	tuile_principale.add_theme_stylebox_override("panel", bord)
	# Onglets « Mon XV | <adversaire> » : le même tableau, aux couleurs de l'équipe choisie.
	var tete := S.G.h(px(8))
	cadre_xv.add_child(tete)
	var groupe := ButtonGroup.new()
	onglets.clear()
	for n in 2:
		# Onglets « Mon XV | XV adverse » (choix de Léo).
		var onglet := _segment("Mon XV" if n == 0 else "XV adverse", groupe, (n == 1) == onglet_adverse)
		onglet.name = "MatchBetweenTabOwn" if n == 0 else "MatchBetweenTabOpponent"
		onglet.custom_minimum_size = Vector2(px(170), px(52))
		onglet.add_theme_font_size_override("font_size", px(30))
		var adverse := n == 1
		onglet.pressed.connect(func():
			onglet_adverse = adverse
			for k in onglets.size(): onglets[k].set_pressed_no_signal((k == 1) == adverse)
			if not _xv_donnees.is_empty(): _remplir_xv(_xv_donnees[0], _xv_donnees[1]))
		onglets.append(onglet)
		tete.add_child(onglet)
	var precision := _texte("note · énergie · plaquages · mètres", 22, FAIBLE)
	precision.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	S.G.fill(precision)
	tete.add_child(precision)
	var entete := S.G.h(px(8))
	for colonne: Array in COLONNES_XV:
		entete.add_child(_cellule(str(colonne[0]).to_upper(), int(colonne[1]), FAIBLE, 20, int(colonne[1]) > 0 and colonne[0] != "Poste" and colonne[0] != "Énergie"))
	cadre_xv.add_child(entete)
	cadre_xv.add_child(xv)
	S.G.fill(xv, true)
	# Centre : terrain petit, momentum, faits marquants.
	var centre := S.G.v(px(20))
	S.G.fill(centre, false, 1.0)
	grille.add_child(centre)
	var cadre_terrain := _panneau(centre, px(14))
	cadre_terrain.get_parent().get_parent().name = "MatchBetweenPitchTile"
	bandeau = PanelContainer.new()
	bandeau.name = "MatchBetweenBanner"
	var style := S.G.T.box(Color(FOND, 0.6), maxi(4, px(8)))
	style.border_width_left = maxi(2, px(5))
	style.border_color = OR
	style.content_margin_left = px(10)
	style.content_margin_right = px(10)
	style.content_margin_top = px(4)
	style.content_margin_bottom = px(4)
	bandeau.add_theme_stylebox_override("panel", style)
	bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre_terrain.add_child(bandeau)
	bandeau.add_child(fil)
	S.G.fill(fil)
	var scene := Control.new()
	scene.name = "MatchBetweenScene"
	scene.clip_contents = true
	scene.custom_minimum_size = Vector2(px(660), px(400))
	cadre_terrain.add_child(scene)
	S.full(terrain)
	scene.add_child(terrain)
	var cadre_frise := _panneau(centre, px(14))
	cadre_frise.add_child(_titre("Momentum", "points marqués et cartons"))
	cadre_frise.add_child(domination)
	domination.size_flags_vertical = Control.SIZE_FILL
	var cadre_faits := _panneau(centre, px(14))
	S.G.fill(cadre_faits.get_parent().get_parent(), true)
	cadre_faits.add_child(_titre("Faits marquants"))
	cadre_faits.add_child(faits)
	# Droite : Gabi, puis les douze stats comparées.
	var droite := S.G.v(px(20))
	droite.name = "MatchBetweenColumn"
	droite.custom_minimum_size.x = px(640)
	grille.add_child(droite)
	_carte_gabi(droite)
	var cadre_chiffres := _panneau(droite, px(16))
	S.G.fill(cadre_chiffres.get_parent().get_parent(), true)
	cadre_chiffres.add_child(_titre("Statistiques", "comparées"))
	cadre_chiffres.add_child(chiffres)
	S.G.fill(chiffres, true)

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
	var cle := JSON.stringify([direct.get("fil", []), direct.get("tableau", []), direct.get("chiffres", []), conseil, direct.get("notes", {}), direct.get("cartons", []),
		passe.lineup, direct.get("statsRows", []), live.get("paused", false), live.get("finished", false), terrain.couleurs])
	if cle == _cle: return
	_cle = cle
	_lignes = direct.get("fil", [])
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
	elif live.get("atBreak", false): etat.text = "Mi-temps"
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
		var nombre := 3 if _densite < 0.6 else 4
		var recents := visibles.slice(maxi(0, visibles.size() - nombre))
		recents.reverse()
		for n in recents.size(): faits.add_child(_ligne_fil(recents[n], n == 0, false))
		if recents.is_empty(): faits.add_child(_texte("Aucun fait marquant pour l’instant.", 24, FAIBLE))

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
	ligne.custom_minimum_size.y = px(40)
	S.G.fill(ligne, true)
	var titre := _texte(str(LIBELLES_COURTS.get(str(rang.get("cle", "")), rang.get("label", ""))), 26, DOUX)
	titre.tooltip_text = str(rang.get("label", ""))
	titre.mouse_filter = Control.MOUSE_FILTER_PASS
	titre.clip_text = true
	titre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titre.custom_minimum_size.x = px(120)
	S.G.fill(titre, false, 1.6)
	ligne.add_child(titre)
	var a := _texte(_valeur(rang, 0), 30, IVOIRE)
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
	var b := _texte(_valeur(rang, 1), 30, IVOIRE)
	b.add_theme_font_override("font", CHIFFRES_GRAS)
	b.custom_minimum_size.x = px(78)
	ligne.add_child(b)
	parent.add_child(ligne)

func _remplir_chiffres(direct: Dictionary, _live: Dictionary) -> void:
	S.clear(chiffres)
	var rangs: Array = direct.get("tableau", [])
	var par_cle := {}
	for rang: Dictionary in rangs: par_cle[str(rang.get("cle", ""))] = rang
	# Douze stats comparées, toujours dans le même ordre (« — » tant qu'une stat est vide).
	for cle: String in STATS:
		if par_cle.has(cle): _ligne_chiffre(chiffres, par_cle[cle])
	_rangs = rangs

## Mon XV : tableau complet, une ligne par joueur (numéro, nom, poste, note colorée, jauge
## d'énergie, plaquages, mètres, essais) ; alertes en infobulle ; un clic ouvre le banc sur lui.
func _remplir_xv(joueurs: Array, direct: Dictionary) -> void:
	_xv_donnees = [joueurs, direct]
	S.clear(xv)
	# Onglet adverse : les alertes de Mon XV restent calculées pour Gabi.
	if onglet_adverse:
		_alertes_seules(joueurs, direct)
		_remplir_xv_adverse(direct)
		return
	alertes_xv.clear()
	var notes: Dictionary = direct.get("notes", {}) if direct.get("notes") is Dictionary else {}
	var cartons: Dictionary = {}
	for carton: Variant in direct.get("cartons", []):
		if carton is Dictionary: cartons[str(carton.get("id", ""))] = carton
	if joueurs.is_empty():
		xv.add_child(_texte("Composition indisponible.", 26, DOUX, true))
		return
	var hauteur := px(48)
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
		var d := W.donnees_joueur(joueur, notes, cartons)
		var id: String = d.id
		var fiche: Dictionary = notes.get(id, {}) if notes.get(id) is Dictionary else {}
		var note: float = d.note
		var condition: float = d.energie
		ligne.add_child(_cellule(_nom_court(str(d.nom)), 0, IVOIRE, 28))
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
		var alerte := ""
		if d.blesse: alerte = "blessé"
		elif cartons.has(id): alerte = "carton jaune, retour %s′" % str(cartons[id].get("retour", "")) if cartons[id].get("retour") != null else "exclu"
		elif condition < EPUISE: alerte = "épuisé"
		elif condition < FATIGUE: alerte = "fatigué"
		if alerte == "blessé": pastille.marque = ALERTE
		elif alerte.begins_with("carton") or alerte == "exclu": pastille.marque = Color("e8c24a")
		var plaq := int(d.get("plaquages", 0))
		var detail := "%d · %s · %s\nÉnergie %d %%, note %.1f (%d action%s du match), %d plaquage%s" % [poste + 1, str(joueur.get("pos", "")), str(joueur.get("name", "")), roundi(condition), note, int(fiche.get("faits", 0)), "s" if int(fiche.get("faits", 0)) > 1 else "", plaq, "s" if plaq > 1 else ""]
		if not alerte.is_empty():
			alertes_xv.append({"poste": poste, "id": id, "nom": str(joueur.get("name", "")), "alerte": alerte, "condition": condition})
			detail += "\n" + alerte.capitalize()
		case.tooltip_text = detail + "\nCliquer : ouvrir le banc sur ce joueur."
		xv.add_child(case)

## XV adverse (`direct.adversaire`) : le même tableau, aux couleurs adverses ; la feuille actuelle
## (ses remplacements se voient tout de suite), notes bornées aux faits montrés.
func _remplir_xv_adverse(direct: Dictionary) -> void:
	var liste: Array = direct.get("adversaire", []) if direct.get("adversaire") is Array else []
	var camp := int(direct.get("camp", -1))
	if liste.is_empty():
		xv.add_child(_texte("Composition adverse pas encore vue.", 26, DOUX, true))
		return
	var hauteur := px(48)
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
		if not texte.begins_with("Aucun") and not texte.begins_with("Pas assez"):
			choisie = texte
			break
	var coupe := choisie.find(". ")
	return choisie.substr(0, coupe + 1) if coupe > 0 else choisie

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
	adjoint_cadre.visible = not live.get("finished", false)
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
	portrait.custom_minimum_size = Vector2(px(96), px(96))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var matte := ShaderMaterial.new()
	matte.shader = MATTE
	portrait.material = matte
	carte.add_child(portrait)
	var colonne := S.G.v(px(8))
	S.G.fill(colonne)
	carte.add_child(colonne)
	colonne.add_child(_texte("Gabi, votre adjoint", 22, FAIBLE))
	var graves := alertes_xv.filter(func(a: Dictionary): return a.alerte != "fatigué")
	var fatigues := alertes_xv.filter(func(a: Dictionary): return a.alerte == "fatigué")
	var phrases: Array = []
	var remplacer := -1
	for alerte: Dictionary in (graves + fatigues).slice(0, 1):
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
	var parlantes := raisons.filter(func(r: String): return not r.begins_with("Aucun") and not r.begins_with("Pas assez"))
	if phrases.is_empty() and parlantes.is_empty(): phrases.append([_lecture_generale(direct), IVOIRE])
	if phrases.is_empty() and not raisons.is_empty(): phrases.append([_phrase_forte(raisons), IVOIRE])
	for phrase: Array in phrases:
		var etiquette := _texte(str(phrase[0]), 32, phrase[1], true, true)
		etiquette.max_lines_visible = 3
		etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		etiquette.tooltip_text = "\n".join(raisons) if not raisons.is_empty() else str(phrase[0])
		etiquette.mouse_filter = Control.MOUSE_FILTER_PASS
		colonne.add_child(etiquette)
	var actions := S.G.h(px(10))
	colonne.add_child(actions)
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
	elif conseil is Dictionary and (conseil.get("attackChanged", false) or conseil.get("defenceChanged", false)):
		var possible: bool = conseil.get("canAct", false) and conseil.get("defenceAvailable", false)
		var bouton := _bouton("Appliquer", func(): appliquer.call(conseil), possible, true)
		bouton.name = "MatchBetweenApplyAdvice"
		bouton.custom_minimum_size.y = px(56)
		bouton.tooltip_text = "Appliquer les consignes proposées." if possible else "Mettez le match en pause pour modifier vos consignes."
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
	if not camp in [0, 1]: return "Le match se met en place : je vous signale le premier joueur en difficulté."
	var valeurs := {}
	for rang: Variant in direct.get("tableau", []):
		if rang is Dictionary and not rang.get("vide", false): valeurs[str(rang.get("cle", ""))] = rang.get("valeurs", [0, 0])
	var score: Array = direct.get("score", [0, 0]) if direct.get("score") is Array else [0, 0]
	var ecart := int(score[camp]) - int(score[1 - camp]) if score.size() == 2 else 0
	if valeurs.has("occupation"):
		var o := int(valeurs.occupation[camp])
		if o >= 58: return ("On joue dans leur moitié (%d %% d’occupation) : restez patients, les points viendront." % o) if ecart <= 0 else ("On mène et on occupe leur camp (%d %%) : gardez cette pression." % o)
		if o <= 42: return "On joue trop dans notre camp (%d %% d’occupation) : il faut en sortir au pied." % o
	if valeurs.has("possession"):
		var p := int(valeurs.possession[camp])
		if p >= 58: return "On a le ballon (%d %%) : il faut maintenant gagner la ligne d’avantage." % p
		if p <= 42: return "Ils ont le ballon (%d %%) : notre défense doit monter vite et rester groupée." % (100 - p)
	if ecart < 0: return "Menés de %d point%s, mais le match reste ouvert : pas de précipitation." % [-ecart, "s" if -ecart > 1 else ""]
	return "Début de match équilibré : j’observe leur organisation et je vous signale le premier joueur en difficulté."

## Une phrase tirée des chiffres du moteur : qui domine depuis cinq minutes, la discipline.
func _lecture(direct: Dictionary) -> String:
	var camp := int(direct.get("camp", -1))
	if not camp in [0, 1]: return ""
	var minutes: Array = direct.get("domination", {}).get("minutes", []) if direct.get("domination") is Dictionary else []
	if minutes.size() >= 5:
		var somme := 0.0
		for v: Variant in minutes.slice(minutes.size() - 5): somme += float(v)
		var nous := somme / 5.0 * (1.0 if camp == 0 else -1.0)
		if nous <= -35.0: return "L’adversaire nous fait reculer depuis cinq minutes : il faut sortir de notre camp."
		if nous >= 35.0: return "On domine depuis cinq minutes : il faut concrétiser cette pression."
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
	arret_texte.text = str(valeur.get("texte", "")) + "\nLe match est en pause : réorganisez votre équipe si besoin, puis reprenez."
	arret.show()
