extends Control
## Écran intermédiaire du match en temps forts (mode de base ; repli CD_MATCH_TEMPS_FORTS=0).
##
## Entre deux temps forts, le match continue sur un terrain vu de dessus (`match_terrain_2d.gd`) :
## trente pastilles numérotées rejouent les faits du moteur pendant que l'horloge défile. Autour,
## un tableau de bord inspiré des écrans « match overview » des jeux de management de football,
## adapté au rugby : domination minute par minute, chiffres clés comparés, fil, Mon XV (note,
## énergie, alertes), regard de l'adjoint et accès direct à la tactique et aux remplacements.
## Trois mises en page au choix (Banc du staff, Vue mixte, Retransmission) partagent ces
## composants. Il n'affiche que la projection `live.direct` du moteur et le modèle : aucun calcul sportif.
const S = preload("res://ui/contextual/skin.gd")
const T = preload("res://theme.gd")
const Terrain2D = preload("res://ui/contextual/match_terrain_2d.gd")

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

## Chiffres clés (le reste dans le tiroir Statistiques).
const CLES := ["possession", "occupation", "plaquages"]
## Chiffres qui prennent la place d'un chiffre clé encore vide.
const RELAIS := ["franchissements", "metres", "penalites", "melees", "touches"]
const FATIGUE := 55
const EPUISE := 40
## Trois mises en page au choix du joueur (demande de Léo, 12 novembre 2026), sur les mêmes
## composants : « staff » (B, par défaut), « mix » (C) et « tele » (A, retransmission).
const DISPOSITIONS := ["staff", "mix", "tele"]
const LIBELLES_DISPOSITION := {"staff": "Banc du staff", "mix": "Vue mixte", "tele": "Retransmission"}

## Mise en page choisie : elle vaut pour les matchs suivants (réglage `match_entracte`).
signal disposition_choisie(id: String)

var disposition := "staff"
var terrain: Terrain2D
var etat: Label
var niveau: OptionButton
var fil: VBoxContainer
var chiffres: VBoxContainer
var xv: GridContainer
var adjoint: VBoxContainer
var vitesse: OptionButton
var tactique: Button
var banc: Button
var plus: MenuButton
var mise_en_page: OptionButton
## Horloge de l'entracte choisie (reprise de la régie à l'ouverture).
var horloge := "normale"
const HORLOGES_IDS := ["lente", "normale", "rapide", "eclair"]
var adjoint_cadre: Control
var domination: Domination
var arret: PanelContainer
var arret_titre: Label
var arret_texte: Label
## Vue mixte : colonne de droite repliée ; Retransmission : tiroir Mon XV ouvert.
var colonne_repliee := false
var tiroir_xv: PanelContainer
var tiroir_xv_ouvert := false
var _niveaux: Array = []
var _cle := ""
var _densite := 0.5
var _arret: Dictionary = {}
var entracte: Label
var passer: Button
var _entracte := ["", false]
var _dernier: Array = []
var _lignes: Array = []
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
		var epais := maxf(3.0, 7.0 * densite)
		var r := minf(size.x, size.y) * 0.5 - epais * 0.5 - 1.0
		draw_arc(c, r, 0.0, TAU, 48, Color("232f2e"), epais, true)
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

func _choix(nom: String, libelles: Array, largeur: float, infobulle: String) -> OptionButton:
	var choix := OptionButton.new()
	choix.name = nom
	choix.custom_minimum_size = Vector2(px(largeur), px(64))
	choix.add_theme_font_size_override("font_size", px(26))
	choix.add_theme_font_override("font", TITRES)
	choix.get_popup().add_theme_font_size_override("font_size", px(26))
	choix.tooltip_text = infobulle
	choix.set_meta("contextual_enabled", true)
	choix.clip_text = true
	for libelle: String in libelles: choix.add_item(libelle)
	_habiller(choix)
	return choix

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
	coque.add_theme_stylebox_override("panel", style)
	parent.add_child(coque)
	var bord := S.G.margin(marge)
	coque.add_child(bord)
	var colonne := S.G.v(px(10))
	bord.add_child(colonne)
	return colonne

## Titre de panneau : une ligne en ivoire, et à droite une précision atténuée.
func _titre(texte: String, precision: String = "") -> Control:
	var ligne := S.G.h(px(10))
	var etiquette := _texte(texte, 28, IVOIRE, false, true)
	S.G.fill(etiquette)
	ligne.add_child(etiquette)
	if not precision.is_empty(): ligne.add_child(_texte(precision, 24, FAIBLE))
	return ligne

func _ready() -> void:
	name = "MatchBetween"
	mouse_filter = Control.MOUSE_FILTER_PASS
	S.full(self)
	_densite = densite_pour(get_viewport_rect().size)
	var preferences: Variant = _preferences()
	if preferences != null and str(preferences.data.get("match_entracte", "")) in DISPOSITIONS: disposition = str(preferences.data.match_entracte)
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

func _preferences() -> Variant:
	var noeud: Node = get_parent()
	while noeud != null:
		var preferences: Variant = noeud.get("user_preferences")
		if preferences != null and preferences.get("data") is Dictionary: return preferences
		noeud = noeud.get_parent()
	return null

func _animations_reduites() -> bool:
	var preferences: Variant = _preferences()
	return preferences != null and bool(preferences.data.get("reduced_motion", false))

## La fenêtre a changé de taille : tout l'écran est reconstruit à la nouvelle échelle.
func _a_l_echelle() -> void:
	var densite := densite_pour(get_viewport_rect().size)
	if is_equal_approx(densite, _densite): return
	_densite = densite
	_reconstruire()

func _reconstruire() -> void:
	_construire()
	if not _dernier.is_empty(): update_frame.callv(_dernier)

## Mise en page choisie par le joueur (Banc du staff, Mix, Retransmission) : enregistrée dans
## ses réglages, elle vaut pour les matchs suivants.
func choisir_disposition(id: String) -> void:
	if not id in DISPOSITIONS or id == disposition: return
	disposition = id
	var preferences: Variant = _preferences()
	if preferences != null and preferences.data.get("match_entracte") != id and preferences.has_method("set_value"): preferences.set_value("match_entracte", id)
	disposition_choisie.emit(id)
	_reconstruire()

func _construire() -> void:
	# Le terrain garde sa lecture (places, file des faits) d'une échelle et d'une mise en page à l'autre.
	var ancien := terrain
	if ancien != null and ancien.get_parent() != null: ancien.get_parent().remove_child(ancien)
	for enfant in get_children():
		remove_child(enfant)
		enfant.queue_free()
	_cle = ""
	terrain = ancien if ancien != null else Terrain2D.new()
	terrain.densite = _densite
	terrain.legende = false
	terrain.custom_minimum_size = Vector2(320, 180)
	_commandes()
	_composants()
	match disposition:
		"tele": _page_tele()
		"mix": _page_mix()
		_: _page_staff()
	_arret_decision()
	if not _arret.is_empty(): montrer_arret(_arret)
	if not terrain.fait_joue.is_connected(_fait_joue): terrain.fait_joue.connect(_fait_joue)

## Commandes de l'écran, les mêmes dans les trois mises en page : où est le ballon, l'entracte
## et « Passer », Tactique, Banc, vitesse de l'horloge, niveau des temps forts, mise en page et
## le reste (statistiques, journal, délégation) dans un menu.
func _commandes() -> void:
	etat = _texte("", 34, IVOIRE, false, true)
	etat.name = "MatchBetweenState"
	etat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etat.clip_text = true
	etat.custom_minimum_size.x = px(120)
	S.G.fill(etat)
	entracte = _texte("", 26, DOUX)
	entracte.name = "MatchBetweenInterval"
	passer = _bouton("PASSER  ›", func(): passer_demande.emit(), true, true)
	passer.name = "MatchBetweenSkip"
	passer.custom_minimum_size.x = px(180)
	passer.tooltip_text = "Aller tout de suite au prochain temps fort."
	passer.set_meta("contextual_enabled", true)
	montrer_entracte(_entracte[0], _entracte[1], true)
	vitesse = _choix("MatchBetweenSpeed", ["Horloge posée", "Horloge normale", "Horloge rapide", "Horloge éclair"], 250, "Vitesse de l’horloge entre deux temps forts. Un temps fort se joue toujours à vitesse réelle.")
	vitesse.select(maxi(0, HORLOGES_IDS.find(horloge)))
	vitesse.item_selected.connect(func(index: int):
		horloge = HORLOGES_IDS[index]
		horloge_choisie.emit(horloge))
	tactique = _bouton("TACTIQUE", func(): tiroir_demande.emit("Tactique"))
	tactique.name = "MatchBetweenTactics"
	tactique.tooltip_text = "Consignes d’attaque et de défense (le match se met en pause)."
	tactique.set_meta("contextual_enabled", true)
	banc = _bouton("BANC", func(): tiroir_demande.emit("Banc"))
	banc.name = "MatchBetweenBench"
	banc.tooltip_text = "Ouvrir le banc et faire un remplacement (le match se met en pause)."
	banc.set_meta("contextual_enabled", true)
	niveau = _choix("MatchHighlightLevel", [], 300, "Temps forts montrés : des plus choisis au match complet.")
	niveau.item_selected.connect(func(index: int): if index >= 0 and index < _niveaux.size(): niveau_choisi.emit(str(_niveaux[index].get("id", ""))))
	for item: Dictionary in _niveaux: niveau.add_item(str(item.get("label", "")))
	mise_en_page = _choix("MatchBetweenLayout", DISPOSITIONS.map(func(id: String): return str(LIBELLES_DISPOSITION[id])), 250, "Mise en page de l’écran entre deux temps forts (enregistrée pour les matchs suivants).")
	mise_en_page.select(DISPOSITIONS.find(disposition))
	mise_en_page.item_selected.connect(func(index: int): choisir_disposition.call_deferred(DISPOSITIONS[index]))
	plus = MenuButton.new()
	plus.name = "MatchBetweenMore"
	plus.text = "PLUS  ▾"
	plus.flat = false
	plus.custom_minimum_size = Vector2(px(130), px(64))
	plus.add_theme_font_size_override("font_size", px(28))
	plus.add_theme_font_override("font", TITRES)
	plus.get_popup().add_theme_font_size_override("font_size", px(26))
	for libelle: String in ["Statistiques", "Journal du match", "Confier la fin à l’adjoint"]: plus.get_popup().add_item(libelle)
	plus.get_popup().id_pressed.connect(func(id: int):
		if id == 0: tiroir_demande.emit("Stats")
		elif id == 1: tiroir_demande.emit("Journal")
		else: delegation_demandee.emit())
	plus.set_meta("contextual_enabled", true)
	_habiller(plus)

## Composants communs : frise du match, chiffres clés, fil, Mon XV, carte de Gabi.
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
	xv.columns = 5
	xv.add_theme_constant_override("h_separation", px(4))
	xv.add_theme_constant_override("v_separation", px(4))
	S.G.fill(xv)
	adjoint = S.G.v(px(10))
	adjoint.name = "MatchBetweenAdvice"

## Fil défilant (Banc du staff) : les derniers faits, le plus récent en haut.
func _fil_defilant(parent: Control) -> void:
	var defilant := ScrollContainer.new()
	defilant.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	S.G.fill(defilant, true)
	parent.add_child(defilant)
	S.G.fill(fil)
	defilant.add_child(fil)

## Barre de commandes sur une ligne.
func _barre(parent: Control, avec_etat: bool) -> HBoxContainer:
	var barre := S.G.h(px(12))
	barre.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(barre)
	if avec_etat: barre.add_child(etat)
	for noeud: Control in [entracte, passer, tactique, banc, vitesse, niveau, mise_en_page, plus]: barre.add_child(noeud)
	return barre

## Carte de Gabi (portrait, une phrase, l'action proposée) dans un panneau en relief.
func _carte_gabi(parent: Control) -> void:
	var cadre := _panneau(parent, px(18), Color(RELIEF, 0.96))
	adjoint_cadre = cadre.get_parent().get_parent()
	cadre.add_child(adjoint)

## B « Banc du staff » : le terrain et, dessous, la frise du match et le fil ; à droite les
## chiffres clés, Mon XV en anneaux d'énergie et Gabi.
func _page_staff() -> void:
	var page := S.G.v(px(16))
	S.full(page)
	add_child(page)
	_barre(page, true)
	var corps := S.G.h(px(20))
	S.G.fill(corps, true)
	page.add_child(corps)
	var gauche := S.G.v(px(16))
	S.G.fill(gauche, true, 2.3)
	corps.add_child(gauche)
	var cadre_terrain := _panneau(gauche, px(8))
	S.G.fill(cadre_terrain.get_parent().get_parent(), true, 1.0)
	S.G.fill(terrain, true)
	cadre_terrain.add_child(terrain)
	var bas := S.G.h(px(16))
	bas.custom_minimum_size.y = px(280)
	gauche.add_child(bas)
	var cadre_frise := _panneau(bas, px(14))
	S.G.fill(cadre_frise.get_parent().get_parent(), true, 1.6)
	cadre_frise.add_child(domination)
	var cadre_fil := _panneau(bas, px(14))
	S.G.fill(cadre_fil.get_parent().get_parent(), true, 1.0)
	_fil_defilant(cadre_fil)
	var droite := S.G.v(px(14))
	droite.custom_minimum_size.x = px(700)
	S.G.fill(droite, true, 1.0)
	corps.add_child(droite)
	var cadre_chiffres := _panneau(droite, px(18))
	cadre_chiffres.add_child(chiffres)
	var cadre_xv := _panneau(droite, px(18))
	cadre_xv.add_child(_titre("Mon XV", "énergie · note"))
	cadre_xv.add_child(xv)
	_carte_gabi(droite)
	S.G.fill(adjoint_cadre, true)

## Terrain avec surimpressions (Mix, Retransmission) : le dernier fait en bandeau en haut à
## gauche, comme un habillage de retransmission.
func _scene(parent: Control) -> Control:
	var scene := Control.new()
	scene.name = "MatchBetweenScene"
	scene.clip_contents = true
	S.G.fill(scene, true)
	parent.add_child(scene)
	S.full(terrain)
	scene.add_child(terrain)
	var bandeau := PanelContainer.new()
	bandeau.name = "MatchBetweenBanner"
	var style := S.G.T.box(Color(FOND, 0.84), maxi(4, px(8)))
	style.content_margin_left = px(16)
	style.content_margin_right = px(16)
	style.content_margin_top = px(8)
	style.content_margin_bottom = px(8)
	bandeau.add_theme_stylebox_override("panel", style)
	bandeau.position = Vector2(px(20), px(18))
	bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(bandeau)
	bandeau.add_child(fil)
	scene.resized.connect(func(): bandeau.custom_minimum_size.x = 0; bandeau.size = Vector2.ZERO; fil.custom_minimum_size.x = minf(px(1100), scene.size.x * 0.62))
	return scene

## C « Mix » : terrain quasi plein écran avec habillage, frise du match dessous, colonne étroite
## repliable à droite (commandes, Mon XV, chiffres clés, Gabi).
func _page_mix() -> void:
	var page := S.G.h(px(16))
	S.full(page)
	add_child(page)
	var gauche := S.G.v(px(12))
	S.G.fill(gauche, true, 1.0)
	page.add_child(gauche)
	_barre(gauche, true)
	var scene := _scene(gauche)
	scene.custom_minimum_size.y = px(400)
	var cadre_frise := _panneau(gauche, px(12))
	cadre_frise.add_child(domination)
	domination.custom_minimum_size.y = px(170)
	domination.size_flags_vertical = Control.SIZE_FILL
	# Languette : replie ou déplie la colonne de droite (le terrain prend la place).
	var languette := Button.new()
	languette.name = "MatchBetweenFold"
	languette.text = "›" if not colonne_repliee else "‹"
	languette.custom_minimum_size = Vector2(px(44), px(120))
	languette.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	languette.add_theme_font_size_override("font_size", px(34))
	languette.tooltip_text = "Replier ou déplier la colonne Mon XV et Gabi."
	languette.set_meta("contextual_enabled", true)
	_habiller(languette)
	page.add_child(languette)
	var droite := S.G.v(px(14))
	droite.name = "MatchBetweenColumn"
	droite.custom_minimum_size.x = px(560)
	droite.visible = not colonne_repliee
	page.add_child(droite)
	languette.pressed.connect(func():
		colonne_repliee = not colonne_repliee
		languette.text = "‹" if colonne_repliee else "›"
		droite.visible = not colonne_repliee)
	var cadre_xv := _panneau(droite, px(16))
	cadre_xv.add_child(_titre("Mon XV", "énergie"))
	cadre_xv.add_child(xv)
	var cadre_chiffres := _panneau(droite, px(16))
	cadre_chiffres.add_child(chiffres)
	_carte_gabi(droite)
	S.G.fill(adjoint_cadre, true)

## A « Retransmission » : le terrain occupe l'écran ; en bas, un tiers translucide porte la
## frise du match, les chiffres clés et Gabi ; Mon XV s'ouvre en tiroir par-dessus le terrain.
func _page_tele() -> void:
	var page := S.G.v(px(12))
	S.full(page)
	add_child(page)
	var barre := _barre(page, true)
	var bouton_xv := _bouton("MON XV", func(): _basculer_tiroir_xv())
	bouton_xv.name = "MatchBetweenSquadToggle"
	bouton_xv.tooltip_text = "Énergie et notes de vos quinze joueurs."
	bouton_xv.set_meta("contextual_enabled", true)
	barre.add_child(bouton_xv)
	barre.move_child(bouton_xv, banc.get_index() + 1)
	var scene := _scene(page)
	scene.custom_minimum_size.y = px(420)
	# Tiers bas, sous le terrain : frise, chiffres clés, Gabi.
	var bas := S.G.h(px(18))
	bas.name = "MatchBetweenLowerThird"
	bas.custom_minimum_size.y = px(270)
	page.add_child(bas)
	var cadre_frise := _panneau(bas, px(12))
	S.G.fill(cadre_frise.get_parent().get_parent(), true, 1.3)
	cadre_frise.add_child(domination)
	var cadre_chiffres := _panneau(bas, px(16))
	S.G.fill(cadre_chiffres.get_parent().get_parent(), true, 1.15)
	cadre_chiffres.add_child(chiffres)
	_carte_gabi(bas)
	S.G.fill(adjoint_cadre, true, 1.2)
	# Tiroir Mon XV, ancré à droite du terrain.
	tiroir_xv = PanelContainer.new()
	tiroir_xv.name = "MatchBetweenSquadDrawer"
	tiroir_xv.add_theme_stylebox_override("panel", S.G.T.box(Color(PANNEAU, 0.95), maxi(6, px(14))))
	tiroir_xv.visible = tiroir_xv_ouvert
	scene.add_child(tiroir_xv)
	var marge := S.G.margin(px(18))
	tiroir_xv.add_child(marge)
	var colonne := S.G.v(px(10))
	marge.add_child(colonne)
	colonne.add_child(_titre("Mon XV", "énergie · note"))
	colonne.add_child(xv)
	scene.resized.connect(func():
		tiroir_xv.size = Vector2(px(600), 0)
		tiroir_xv.position = Vector2(scene.size.x - tiroir_xv.get_combined_minimum_size().x - px(20), px(18)))

func _basculer_tiroir_xv() -> void:
	tiroir_xv_ouvert = not tiroir_xv_ouvert
	if is_instance_valid(tiroir_xv): tiroir_xv.visible = tiroir_xv_ouvert

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
	terrain.direct = direct
	terrain.camp = int(direct.get("camp", -1))
	terrain.regler_equipes(equipes)
	# Le terrain rejoue les faits que le joueur peut voir : rien au-delà du journal montré.
	terrain.alimenter(direct.get("deroule", []), mini(live.get("events", []).size(), int(direct.get("borne", live.get("events", []).size()))))
	terrain.queue_redraw()
	_etat(live, direct, equipes)
	_niveaux = direct.get("niveaux", [])
	if niveau.item_count != _niveaux.size():
		niveau.clear()
		for item: Dictionary in _niveaux: niveau.add_item(str(item.get("label", "")))
	for index in _niveaux.size():
		if _niveaux[index].get("id") == direct.get("niveau") and niveau.selected != index: niveau.select(index)
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
		passe.lineup, direct.get("statsRows", []), live.get("paused", false), live.get("finished", false), terrain.couleurs, disposition])
	if cle == _cle: return
	_cle = cle
	_lignes = direct.get("fil", [])
	_remplir_fil()
	_remplir_chiffres(direct, live)
	_remplir_xv(passe.lineup, direct)
	_remplir_adjoint(conseil, live, direct, appliquer)

func _etat(live: Dictionary, direct: Dictionary, equipes: Array) -> void:
	var possession: Variant = direct.get("possession")
	if live.get("finished", false): etat.text = "Match terminé"
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

## Fil : une ligne n'y entre qu'une fois son fait joué sur le terrain. Banc du staff : les
## derniers faits, le plus récent en haut ; Mix et Retransmission : le dernier, en bandeau.
func _remplir_fil() -> void:
	if not is_instance_valid(fil): return
	S.clear(fil)
	var visibles: Array = []
	var prochain := terrain.prochain_i()
	for entree: Dictionary in _lignes:
		var i := int(entree.get("i", -1))
		if prochain >= 0 and i >= prochain: continue
		visibles.append(entree)
	var bandeau := disposition != "staff"
	var nombre := 1 if bandeau else 12
	for index in range(visibles.size() - 1, maxi(-1, visibles.size() - 1 - nombre), -1):
		fil.add_child(_ligne_fil(visibles[index], index == visibles.size() - 1, bandeau))
	if visibles.is_empty(): fil.add_child(_texte("Le coup d’envoi approche.", 26, DOUX, not bandeau))

func _ligne_fil(entree: Dictionary, dernier: bool, bandeau: bool) -> Control:
	var kind := str(entree.get("kind", ""))
	var essai := kind == "try"
	var points := kind in ["try", "goal", "transformation"]
	var equipe := int(entree.get("equipe", -1)) if entree.get("equipe") != null else -1
	var teinte: Color = terrain.couleurs[equipe] if equipe in [0, 1] else FAIBLE
	# Minute en or, pictogramme du fait aux couleurs du club, texte ; les essais en ivoire gras.
	var ligne := PanelContainer.new()
	var fond := S.G.T.box(Color(OR, 0.12) if essai and not bandeau else Color(0, 0, 0, 0), maxi(4, px(10)))
	fond.content_margin_left = px(6)
	fond.content_margin_right = px(6)
	fond.content_margin_top = px(4)
	fond.content_margin_bottom = px(4)
	ligne.add_theme_stylebox_override("panel", fond)
	ligne.set_meta("i", int(entree.get("i", -1)))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE if bandeau else Control.MOUSE_FILTER_PASS
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
	var texte := _texte(str(entree.get("texte", "")), 28 if bandeau or essai else 26, IVOIRE if dernier or points else DOUX, not bandeau, essai)
	texte.max_lines_visible = 1 if bandeau else (3 if dernier or essai else 2)
	texte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if bandeau: texte.clip_text = true
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
	ligne.custom_minimum_size.y = px(58)
	var titre := _texte(str(rang.get("label", "")), 26, DOUX)
	titre.clip_text = true
	titre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titre.custom_minimum_size.x = px(150)
	S.G.fill(titre, false, 1.1)
	ligne.add_child(titre)
	var a := _texte(_valeur(rang, 0), 44, IVOIRE)
	a.add_theme_font_override("font", CHIFFRES_GRAS)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	a.custom_minimum_size.x = px(104)
	ligne.add_child(a)
	var barre := Barre.new()
	barre.valeurs = rang.get("valeurs", [0, 0]) if not rang.get("vide", false) else [0, 0]
	barre.couleurs = terrain.couleurs.duplicate()
	barre.densite = _densite
	barre.custom_minimum_size = Vector2(px(80), px(30))
	S.G.fill(barre, false, 1.0)
	ligne.add_child(barre)
	var b := _texte(_valeur(rang, 1), 44, IVOIRE)
	b.add_theme_font_override("font", CHIFFRES_GRAS)
	b.custom_minimum_size.x = px(104)
	ligne.add_child(b)
	parent.add_child(ligne)

func _remplir_chiffres(direct: Dictionary, _live: Dictionary) -> void:
	S.clear(chiffres)
	var rangs: Array = direct.get("tableau", [])
	# Trois chiffres clés : d'abord ceux qui disent déjà quelque chose (une stat encore vide en
	# début de match cède sa place), sinon les libellés sans valeur (« — »). Les autres sont dans
	# le tiroir Statistiques (menu Plus).
	var par_cle := {}
	for rang: Dictionary in rangs: par_cle[str(rang.get("cle", ""))] = rang
	var choisis: Array = []
	for cle: String in CLES + RELAIS:
		if par_cle.has(cle) and not par_cle[cle].get("vide", false) and choisis.size() < CLES.size(): choisis.append(par_cle[cle])
	for cle: String in CLES:
		if par_cle.has(cle) and par_cle[cle].get("vide", false) and choisis.size() < CLES.size(): choisis.append(par_cle[cle])
	for rang: Dictionary in choisis: _ligne_chiffre(chiffres, rang)

## Mon XV : quinze anneaux d'énergie autour des numéros, la note du match dessous ; nom, poste
## et alertes en infobulle ; un clic ouvre le banc sur le joueur.
func _remplir_xv(joueurs: Array, direct: Dictionary) -> void:
	S.clear(xv)
	alertes_xv.clear()
	var notes: Dictionary = direct.get("notes", {}) if direct.get("notes") is Dictionary else {}
	var cartons: Dictionary = {}
	for carton: Variant in direct.get("cartons", []):
		if carton is Dictionary: cartons[str(carton.get("id", ""))] = carton
	if joueurs.is_empty():
		xv.add_child(_texte("Composition indisponible.", 26, DOUX, true))
		return
	var anneau := px(96 if disposition == "staff" else 84)
	for poste in joueurs.size():
		var joueur: Variant = joueurs[poste]
		var case := Button.new()
		case.name = "MatchBetweenPlayer%d" % (poste + 1)
		case.flat = true
		case.focus_mode = Control.FOCUS_ALL
		case.set_meta("contextual_enabled", true)
		case.pressed.connect(func(): joueur_choisi.emit(poste))
		case.add_theme_stylebox_override("hover", S.G.T.box(SURVOL, maxi(4, px(10))))
		case.add_theme_stylebox_override("focus", S.G.T.box(Color.TRANSPARENT, maxi(4, px(10)), OR))
		S.G.fill(case)
		var colonne := S.G.v(px(2))
		colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		colonne.alignment = BoxContainer.ALIGNMENT_CENTER
		S.full(colonne)
		case.add_child(colonne)
		var energie := Energie.new()
		energie.numero = str(poste + 1)
		energie.densite = _densite
		energie.custom_minimum_size = Vector2(anneau, anneau)
		energie.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		energie.mouse_filter = Control.MOUSE_FILTER_IGNORE
		colonne.add_child(energie)
		if not joueur is Dictionary:
			energie.valeur = 0.0
			case.tooltip_text = "%d · poste vacant" % (poste + 1)
			case.custom_minimum_size.y = anneau + px(40)
			xv.add_child(case)
			continue
		var id := str(joueur.get("id", ""))
		var fiche: Dictionary = notes.get(id, {}) if notes.get(id) is Dictionary else {}
		var note := float(fiche.get("note", 6.0))
		var condition := float(joueur.get("condition", 100))
		energie.valeur = condition
		var etiquette_note := _texte("%.1f" % note, 24, Color("9fd5a6") if note >= 7.0 else (ALERTE if note < 5.5 else DOUX), false, true)
		etiquette_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etiquette_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		colonne.add_child(etiquette_note)
		# Nom gardé pour les lecteurs d'écran et les tests, montré en infobulle.
		var nom := _texte(str(joueur.get("name", "")), 20, FAIBLE)
		nom.visible = false
		colonne.add_child(nom)
		var alerte := ""
		if int(joueur.get("injury", 0)) > 0: alerte = "blessé"
		elif cartons.has(id): alerte = "carton jaune, retour %s′" % str(cartons[id].get("retour", "")) if cartons[id].get("retour") != null else "exclu"
		elif condition < EPUISE: alerte = "épuisé"
		elif condition < FATIGUE: alerte = "fatigué"
		if alerte == "blessé": energie.marque = ALERTE
		elif alerte.begins_with("carton") or alerte == "exclu": energie.marque = Color("e8c24a")
		var detail := "%d · %s · %s\nÉnergie %d %%, note %.1f (%d action%s du match)" % [poste + 1, str(joueur.get("pos", "")), str(joueur.get("name", "")), roundi(condition), note, int(fiche.get("faits", 0)), "s" if int(fiche.get("faits", 0)) > 1 else ""]
		if not alerte.is_empty():
			alertes_xv.append({"poste": poste, "id": id, "nom": str(joueur.get("name", "")), "alerte": alerte, "condition": condition})
			detail += "\n" + alerte.capitalize()
		case.tooltip_text = detail + "\nCliquer : ouvrir le banc sur ce joueur."
		case.custom_minimum_size.y = anneau + px(40)
		xv.add_child(case)

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
	portrait.custom_minimum_size = Vector2(px(112), px(112))
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

## Entracte : texte (« Prochaine action dans 6 s ») et bouton « Passer ».
func montrer_entracte(texte: String, bouton: bool, force: bool = false) -> void:
	if not force and _entracte[0] == texte and _entracte[1] == bouton: return
	_entracte = [texte, bouton]
	if not is_instance_valid(entracte): return
	entracte.text = texte
	entracte.visible = not texte.is_empty()
	passer.visible = bouton

func montrer_arret(valeur: Dictionary) -> void:
	_arret = valeur
	if valeur.is_empty():
		arret.hide()
		return
	var titre := "CARTON ROUGE" if valeur.get("rouge", false) else "CARTON JAUNE"
	arret_titre.text = "%s · %s" % [titre, str(valeur.get("horloge", ""))]
	arret_texte.text = str(valeur.get("texte", "")) + "\nLe match est en pause : réorganisez votre équipe si besoin, puis reprenez."
	arret.show()
