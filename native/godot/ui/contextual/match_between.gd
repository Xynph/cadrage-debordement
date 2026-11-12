extends Control
## Écran intermédiaire du match en temps forts (mode de base ; repli CD_MATCH_TEMPS_FORTS=0).
##
## Entre deux temps forts, le match continue sur un terrain vu de dessus (`match_terrain_2d.gd`) :
## trente pastilles numérotées rejouent les faits du moteur pendant que l'horloge défile. Autour,
## un tableau de bord inspiré des écrans « match overview » des jeux de management de football,
## adapté au rugby : domination minute par minute, chiffres clés comparés, fil, Mon XV (note,
## énergie, alertes), regard de l'adjoint et accès direct à la tactique et aux remplacements.
## Il n'affiche que la projection `live.direct` du moteur et le modèle : aucun calcul sportif.
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

## Chiffres clés sous le terrain (le reste dans l'onglet « Chiffres »).
const CLES := ["possession", "occupation", "plaquages"]
## Chiffres qui prennent la place d'un chiffre clé encore vide.
const RELAIS := ["franchissements", "metres", "penalites", "melees", "touches"]
const ONGLETS := ["Le fil", "Mon XV", "Chiffres"]
const FATIGUE := 55
const EPUISE := 40

var terrain: Terrain2D
var etat: Label
var niveau: OptionButton
var fil: VBoxContainer
var chiffres: VBoxContainer
var tableau: VBoxContainer
var xv: VBoxContainer
var adjoint: VBoxContainer
var vitesse: OptionButton
## Horloge de l'entracte choisie (reprise de la régie à l'ouverture).
var horloge := "normale"
const HORLOGES_IDS := ["lente", "normale", "rapide", "eclair"]
var adjoint_cadre: Control
var alertes: VBoxContainer
var domination: Domination
var arret: PanelContainer
var arret_titre: Label
var arret_texte: Label
var onglet := "Le fil"
var _onglets: Dictionary = {}
var _pages: Dictionary = {}
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
		# Points marqués : un jalon à la minute, du côté de l'équipe qui marque.
		for repere: Dictionary in reperes:
			if str(repere.get("kind", "")) == "card": continue
			var m := float(repere.get("minute", 0))
			var cote := int(repere.get("equipe", 0))
			var ou := Vector2(zone.position.x + (m - 0.5) * pas, zone.position.y + 4.0 * densite if cote == 0 else zone.end.y - 4.0 * densite)
			draw_circle(ou, maxf(3.0, 8.0 * densite), couleurs[cote])
			draw_arc(ou, maxf(3.0, 8.0 * densite), 0.0, TAU, 12, S.TEXT, 1.0, true)
		if not minutes.is_empty():
			var x := zone.position.x + minutes.size() * pas
			draw_line(Vector2(x, zone.position.y), Vector2(x, zone.end.y), S.GOLD, maxf(1.5, 3.0 * densite))

## Pictogramme d'un fait du fil : essai, pénalité, carton, mêlée, touche, plaquage, jeu au pied.
class Icone extends Control:
	const S = preload("res://ui/contextual/skin.gd")
	var kind := ""
	var teinte := Color.WHITE
	var rouge := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color(teinte, 0.22))
		draw_arc(c, r - 0.5, 0.0, TAU, 24, Color(teinte, 0.7), maxf(1.0, r * 0.1), true)
		var epais := maxf(1.2, r * 0.14)
		var blanc := Color("f1f0df")
		match kind:
			"try":
				draw_set_transform(c, -0.6, Vector2(1.4, 0.85))
				draw_circle(Vector2.ZERO, r * 0.42, S.GOLD)
				draw_set_transform(Vector2.ZERO, 0.0)
				draw_line(c + Vector2(-r * 0.22, r * 0.12), c + Vector2(r * 0.22, -r * 0.12), Color("3a2a1a"), epais * 0.7, true)
			"goal", "miss", "penalty", "transformation":
				draw_line(c + Vector2(-r * 0.35, -r * 0.5), c + Vector2(-r * 0.35, r * 0.5), blanc, epais, true)
				draw_line(c + Vector2(r * 0.35, -r * 0.5), c + Vector2(r * 0.35, r * 0.5), blanc, epais, true)
				draw_line(c + Vector2(-r * 0.35, r * 0.1), c + Vector2(r * 0.35, r * 0.1), blanc, epais, true)
			"card":
				draw_rect(Rect2(c - Vector2(r * 0.28, r * 0.42), Vector2(r * 0.56, r * 0.84)), Color("d43e47") if rouge else Color("e8c24a"))
			"scrum", "setpiece-win", "setpiece-loss":
				for dx in [-0.3, 0.3]:
					for dy in [-0.22, 0.22]: draw_circle(c + Vector2(dx, dy) * r, r * 0.17, blanc)
			"lineout":
				draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, r * 0.5), blanc, epais, true)
				draw_circle(c + Vector2(0, -r * 0.5), r * 0.16, blanc)
			"turnover", "hand-fault":
				draw_line(c - Vector2(r * 0.35, r * 0.35), c + Vector2(r * 0.35, r * 0.35), blanc, epais, true)
				draw_line(c + Vector2(-r * 0.35, r * 0.35), c + Vector2(r * 0.35, -r * 0.35), blanc, epais, true)
			"kick", "kickoff", "drop22", "goalLine", "touch":
				draw_arc(c + Vector2(0, r * 0.35), r * 0.5, PI * 1.1, PI * 1.9, 12, blanc, epais, true)
				draw_circle(c + Vector2(r * 0.4, -r * 0.05), r * 0.14, blanc)
			"carry":
				draw_line(c + Vector2(-r * 0.4, 0), c + Vector2(r * 0.3, 0), blanc, epais, true)
				draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.5, 0), c + Vector2(r * 0.18, -r * 0.24), c + Vector2(r * 0.18, r * 0.24)]), blanc)
			_:
				draw_circle(c, r * 0.18, blanc)

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

## Énergie d'un joueur (condition du moteur, 0 à 100).
class Energie extends Control:
	const S = preload("res://ui/contextual/skin.gd")
	var valeur := 100.0
	var densite := 0.5

	func _draw() -> void:
		var h := maxf(5.0, 12.0 * densite)
		var y := (size.y - h) * 0.5
		draw_rect(Rect2(0, y, size.x, h), Color(1, 1, 1, 0.1))
		var teinte := Color("7fbf86") if valeur >= 70.0 else (S.GOLD if valeur >= 55.0 else Color("e0703f"))
		draw_rect(Rect2(0, y, size.x * clampf(valeur / 100.0, 0.0, 1.0), h), teinte)

## Échelle de l'interface, comme les autres écrans du jeu (immersive08/components.gd) :
## les tailles sont écrites pour 2560×1440 et réduites jusqu'à la moitié en 1280×720.
static func densite_pour(taille: Vector2) -> float:
	return clampf(minf(taille.y / 1440.0, taille.x / 2560.0), 0.5, 1.0)

func px(valeur: float) -> int:
	return roundi(valeur * _densite)

func _texte(texte: String, taille: float, couleur: Color, retour: bool = false, titre: bool = false) -> Label:
	var etiquette := S.wrap(texte, px(taille), couleur) if retour else S.label(texte, px(taille), couleur)
	etiquette.add_theme_font_size_override("font_size", px(taille))
	if titre: etiquette.add_theme_font_override("font", T.DISPLAY)
	return etiquette

func _bouton(texte: String, action: Callable, actif: bool = true, principal: bool = false) -> Button:
	var bouton := S.button(texte, action, actif, principal)
	bouton.custom_minimum_size.y = px(68)
	bouton.add_theme_font_size_override("font_size", px(26))
	return bouton

## Charte de l'écran (cinq teintes) : fond vert profond, vert de jeu, doré, texte clair, texte
## atténué. Les panneaux se fondent dans le fond (voile vert, filet doré très léger).
const FOND_PANNEAU := Color(0.07, 0.15, 0.12, 0.86)
const FILET := Color(0.85, 0.76, 0.51, 0.13)

func _panneau(parent: Node, marge: int) -> VBoxContainer:
	var coque := PanelContainer.new()
	var style := S.G.T.box(FOND_PANNEAU, maxi(6, px(14)), FILET)
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = maxi(2, px(10))
	style.shadow_offset = Vector2(0, maxf(1.0, px(3)))
	coque.add_theme_stylebox_override("panel", style)
	parent.add_child(coque)
	var bord := S.G.margin(marge)
	coque.add_child(bord)
	var colonne := S.G.v(px(10))
	bord.add_child(colonne)
	return colonne

## Titre de panneau discret : petites capitales atténuées, le contenu prime.
func _titre(texte: String) -> Label:
	var etiquette := _texte(texte, 21, Color(S.MUTED, 0.72), false, true)
	etiquette.uppercase = true
	return etiquette

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

func _construire() -> void:
	# Le terrain garde sa lecture (places, file des faits) d'une échelle à l'autre.
	var ancien := terrain
	if ancien != null and ancien.get_parent() != null: ancien.get_parent().remove_child(ancien)
	for enfant in get_children():
		remove_child(enfant)
		enfant.queue_free()
	_cle = ""
	var page := S.G.v(px(16))
	S.full(page)
	add_child(page)
	# En-tête : où est le ballon, l'entracte et de quoi l'abréger, le niveau des temps forts.
	var entete := S.G.h(px(20))
	page.add_child(entete)
	etat = _texte("", 34, S.GOLD, false, true)
	etat.name = "MatchBetweenState"
	etat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etat.clip_text = true
	S.G.fill(etat)
	entete.add_child(etat)
	# Barre de commandes unique de l'écran : entracte, Passer, vitesse, Tactique, Banc, niveau,
	# et le reste (statistiques, journal, délégation) dans un menu.
	entracte = _texte("", 26, S.TEXT)
	entracte.name = "MatchBetweenInterval"
	entete.add_child(entracte)
	passer = _bouton("PASSER  ›", func(): passer_demande.emit(), true, true)
	passer.name = "MatchBetweenSkip"
	passer.custom_minimum_size = Vector2(px(200), px(64))
	passer.tooltip_text = "Aller tout de suite au prochain temps fort."
	passer.set_meta("contextual_enabled", true)
	entete.add_child(passer)
	montrer_entracte(_entracte[0], _entracte[1], true)
	vitesse = OptionButton.new()
	vitesse.name = "MatchBetweenSpeed"
	vitesse.custom_minimum_size = Vector2(px(250), px(64))
	vitesse.add_theme_font_size_override("font_size", px(26))
	vitesse.get_popup().add_theme_font_size_override("font_size", px(26))
	vitesse.tooltip_text = "Vitesse de l’horloge entre deux temps forts. Un temps fort se joue toujours à vitesse réelle."
	vitesse.set_meta("contextual_enabled", true)
	for libelle: String in ["Horloge posée", "Horloge normale", "Horloge rapide", "Horloge éclair"]: vitesse.add_item(libelle)
	vitesse.select(maxi(0, HORLOGES_IDS.find(horloge)))
	vitesse.item_selected.connect(func(index: int):
		horloge = HORLOGES_IDS[index]
		horloge_choisie.emit(horloge))
	entete.add_child(vitesse)
	var tactique := _bouton("TACTIQUE", func(): tiroir_demande.emit("Tactique"))
	tactique.name = "MatchBetweenTactics"
	tactique.tooltip_text = "Consignes d’attaque et de défense (le match se met en pause)."
	tactique.set_meta("contextual_enabled", true)
	entete.add_child(tactique)
	var banc := _bouton("BANC", func(): tiroir_demande.emit("Banc"))
	banc.name = "MatchBetweenBench"
	banc.tooltip_text = "Ouvrir le banc et faire un remplacement (le match se met en pause)."
	banc.set_meta("contextual_enabled", true)
	entete.add_child(banc)
	niveau = OptionButton.new()
	niveau.name = "MatchHighlightLevel"
	niveau.custom_minimum_size = Vector2(px(330), px(64))
	niveau.add_theme_font_size_override("font_size", px(26))
	niveau.get_popup().add_theme_font_size_override("font_size", px(26))
	niveau.tooltip_text = "Temps forts montrés : des plus choisis au match complet."
	niveau.set_meta("contextual_enabled", true)
	niveau.item_selected.connect(func(index: int): if index >= 0 and index < _niveaux.size(): niveau_choisi.emit(str(_niveaux[index].get("id", ""))))
	entete.add_child(niveau)
	var plus := MenuButton.new()
	plus.name = "MatchBetweenMore"
	plus.text = "PLUS  ▾"
	plus.flat = false
	plus.custom_minimum_size = Vector2(px(150), px(64))
	plus.add_theme_font_size_override("font_size", px(26))
	plus.get_popup().add_theme_font_size_override("font_size", px(26))
	for libelle: String in ["Statistiques", "Journal du match", "Confier la fin à l’adjoint"]: plus.get_popup().add_item(libelle)
	plus.get_popup().id_pressed.connect(func(id: int):
		if id == 0: tiroir_demande.emit("Stats")
		elif id == 1: tiroir_demande.emit("Journal")
		else: delegation_demandee.emit())
	plus.set_meta("contextual_enabled", true)
	for etat_bouton in ["normal", "hover", "pressed"]: plus.add_theme_stylebox_override(etat_bouton, S.G.T.box(S.PANEL, 4, Color("66745e")))
	entete.add_child(plus)
	var corps := S.G.h(px(20))
	S.G.fill(corps, true)
	page.add_child(corps)
	# Colonne principale : le terrain, puis la domination et les chiffres clés.
	var gauche := S.G.v(px(16))
	S.G.fill(gauche, true, 2.3)
	corps.add_child(gauche)
	var cadre_terrain := _panneau(gauche, px(8))
	S.G.fill(cadre_terrain.get_parent().get_parent(), true, 1.0)
	terrain = ancien if ancien != null else Terrain2D.new()
	terrain.densite = _densite
	terrain.custom_minimum_size = Vector2(320, 180)
	S.G.fill(terrain, true)
	cadre_terrain.add_child(terrain)
	# Sous le terrain, pleine largeur : la domination façon FM, aux couleurs des deux clubs.
	var cadre_domination := _panneau(gauche, px(12))
	domination = Domination.new()
	domination.name = "MatchBetweenMomentum"
	domination.densite = _densite
	domination.custom_minimum_size = Vector2(0, px(120))
	domination.tooltip_text = "Qui domine, minute par minute : occupation, possession, points et franchissements."
	domination.mouse_filter = Control.MOUSE_FILTER_PASS
	S.G.fill(domination, true)
	cadre_domination.add_child(domination)
	# Colonne de droite : chiffres clés en grand, onglets (fil, Mon XV, chiffres), l'adjoint.
	var droite := S.G.v(px(14))
	droite.custom_minimum_size.x = px(600)
	S.G.fill(droite, true, 1.0)
	corps.add_child(droite)
	var cadre_chiffres := _panneau(droite, px(14))
	chiffres = S.G.v(px(2))
	chiffres.name = "MatchBetweenFigures"
	cadre_chiffres.add_child(chiffres)
	var cadre_onglets := _panneau(droite, px(18))
	S.G.fill(cadre_onglets.get_parent().get_parent(), true, 1.0)
	var barre_onglets := S.G.h(px(8))
	cadre_onglets.add_child(barre_onglets)
	_onglets.clear()
	_pages.clear()
	for titre: String in ONGLETS:
		var bouton := _bouton(titre.to_upper(), func(): choisir_onglet(titre))
		bouton.name = "MatchBetweenTab" + titre.replace(" ", "")
		bouton.custom_minimum_size.y = px(58)
		bouton.set_meta("contextual_enabled", true)
		S.G.fill(bouton)
		barre_onglets.add_child(bouton)
		_onglets[titre] = bouton
	fil = S.G.scroll(cadre_onglets)
	fil.name = "MatchBetweenFeed"
	fil.add_theme_constant_override("separation", px(10))
	_pages["Le fil"] = fil.get_parent()
	xv = S.G.scroll(cadre_onglets)
	xv.name = "MatchBetweenSquad"
	xv.add_theme_constant_override("separation", px(4))
	_pages["Mon XV"] = xv.get_parent()
	tableau = S.G.scroll(cadre_onglets)
	tableau.name = "MatchBetweenTable"
	tableau.add_theme_constant_override("separation", px(4))
	_pages["Chiffres"] = tableau.get_parent()
	for defilant: ScrollContainer in _pages.values():
		defilant.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		S.G.fill(defilant, true)
	choisir_onglet(onglet)
	adjoint = _panneau(droite, px(18))
	adjoint.name = "MatchBetweenAdvice"
	adjoint_cadre = adjoint.get_parent().get_parent()
	# Arrêt-décision : le match attend le manager.
	arret = PanelContainer.new()
	arret.name = "MatchBetweenStop"
	arret.add_theme_stylebox_override("panel", S.G.T.box(S.PANEL, 5, S.GOLD))
	arret.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	arret.custom_minimum_size = Vector2(px(920), 0)
	arret.grow_horizontal = Control.GROW_DIRECTION_BOTH
	arret.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(arret)
	var marge := S.G.margin(px(32))
	arret.add_child(marge)
	var colonne := S.G.v(px(20))
	marge.add_child(colonne)
	arret_titre = _texte("", 44, S.GOLD, false, true)
	colonne.add_child(arret_titre)
	arret_texte = _texte("", 30, S.TEXT, true)
	arret_texte.custom_minimum_size.x = px(840)
	colonne.add_child(arret_texte)
	var choix := S.G.h(px(16))
	colonne.add_child(choix)
	choix.add_child(_bouton("BANC", func(): tiroir_demande.emit("Banc")))
	choix.add_child(_bouton("TACTIQUE", func(): tiroir_demande.emit("Tactique")))
	choix.add_child(S.G.spacer())
	choix.add_child(_bouton("REPRENDRE LE MATCH", func(): reprise_demandee.emit(), true, true))
	arret.hide()
	if not _arret.is_empty(): montrer_arret(_arret)
	if not terrain.fait_joue.is_connected(_fait_joue): terrain.fait_joue.connect(_fait_joue)

func choisir_onglet(titre: String) -> void:
	if not titre in ONGLETS: return
	onglet = titre
	for nom: String in _pages: (_pages[nom] as Control).visible = nom == titre
	for nom: String in _onglets:
		var bouton: Button = _onglets[nom]
		if nom == titre:
			for etat_bouton in ["normal", "hover", "pressed"]:
				var choisi := S.G.T.box(Color(S.GOLD, 0.14), maxi(4, px(10)), Color(S.GOLD, 0.55))
				choisi.set_border_width_all(0)
				choisi.border_width_bottom = maxi(2, px(4))
				bouton.add_theme_stylebox_override(etat_bouton, choisi)
			bouton.add_theme_color_override("font_color", S.GOLD)
		else:
			for etat_bouton in ["normal", "hover", "pressed"]: bouton.add_theme_stylebox_override(etat_bouton, S.G.T.box(Color(0, 0, 0, 0.12), maxi(4, px(10)), FILET))
			bouton.add_theme_color_override("font_color", S.MUTED)
			bouton.add_theme_color_override("font_color", S.TEXT)

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
		passe.lineup, direct.get("statsRows", []), live.get("paused", false), live.get("finished", false), terrain.couleurs])
	if cle == _cle: return
	_cle = cle
	_lignes = direct.get("fil", [])
	_remplir_fil()
	_remplir_chiffres(direct, live)
	_remplir_xv(passe.lineup, direct)
	_remplir_adjoint(conseil, live, direct, appliquer)

func _etat(live: Dictionary, direct: Dictionary, equipes: Array) -> void:
	var possession: Variant = direct.get("possession")
	if live.get("finished", false): etat.text = "MATCH TERMINÉ"
	elif live.get("atBreak", false): etat.text = "MI-TEMPS"
	elif (possession is float or possession is int) and equipes.size() >= 2:
		var cote := clampi(int(possession), 0, 1)
		etat.text = "%s · ballon %s" % [S.G.club_name(equipes[cote]).to_upper(), _zone(float(direct.get("zone", {}).get("x", 50.0)), cote)]
	else: etat.text = "LE MATCH"

## Un fait vient d'être joué sur le terrain : le fil le montre, le score le suit.
func _fait_joue(item: Dictionary) -> void:
	_remplir_fil()
	var marque: Variant = item.get("score")
	if marque is Array and (marque as Array).size() == 2: score_joue.emit(marque)

## Score à montrer tant que le terrain rejoue des faits en retard sur le moteur, sinon vide.
## Minute à afficher tant que le terrain rejoue des faits en retard sur le moteur (« 1′ »), sinon vide :
## l'horloge du bandeau suit ce que montre le terrain, comme le score.
func horloge_differee() -> String:
	if terrain == null or not terrain.en_retard(): return ""
	return terrain.horloge_montree()

func score_differe() -> Array:
	if terrain == null or not terrain.en_retard() or terrain.joue.is_empty(): return []
	var marque: Variant = terrain.joue.get("score")
	return marque if marque is Array and (marque as Array).size() == 2 else []

func _remplir_fil() -> void:
	if not is_instance_valid(fil): return
	S.clear(fil)
	# Une ligne n'entre au fil qu'une fois son fait joué sur le terrain.
	var visibles: Array = []
	for entree: Dictionary in _lignes:
		var i := int(entree.get("i", -1))
		var prochain := terrain.prochain_i()
		if prochain >= 0 and i >= prochain: continue
		visibles.append(entree)
	for index in range(visibles.size() - 1, -1, -1):
		var entree: Dictionary = visibles[index]
		var dernier := index == visibles.size() - 1
		var kind := str(entree.get("kind", ""))
		var essai := kind == "try"
		var points := kind in ["try", "goal", "transformation"]
		var equipe := int(entree.get("equipe", -1)) if entree.get("equipe") != null else -1
		var teinte: Color = terrain.couleurs[equipe] if equipe in [0, 1] else S.MUTED
		# Ligne du fil : minute en pastille, pictogramme du fait aux couleurs du club, texte ;
		# les points marqués sont mis en valeur (fond doré, texte clair).
		var ligne := PanelContainer.new()
		var fond := S.G.T.box(Color(S.GOLD, 0.16) if essai else (Color(S.GOLD, 0.07) if points else Color(0, 0, 0, 0)), maxi(4, px(10)), Color(S.GOLD, 0.45) if essai else Color.TRANSPARENT)
		fond.content_margin_left = px(8)
		fond.content_margin_right = px(8)
		fond.content_margin_top = px(6)
		fond.content_margin_bottom = px(6)
		ligne.add_theme_stylebox_override("panel", fond)
		ligne.set_meta("i", int(entree.get("i", -1)))
		var rang := S.G.h(px(14))
		ligne.add_child(rang)
		var pastille := PanelContainer.new()
		var style_minute := S.G.T.box(Color(teinte, 0.85) if dernier or points else Color(1, 1, 1, 0.08), maxi(6, px(22)))
		style_minute.content_margin_left = px(10)
		style_minute.content_margin_right = px(10)
		style_minute.content_margin_top = px(2)
		style_minute.content_margin_bottom = px(2)
		pastille.add_theme_stylebox_override("panel", style_minute)
		pastille.custom_minimum_size.x = px(76)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var heure := _texte(str(entree.get("horloge", "")), 26, (Color("152019") if teinte.get_luminance() > 0.55 else Color.WHITE) if dernier or points else S.MUTED, false, true)
		heure.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pastille.add_child(heure)
		rang.add_child(pastille)
		var icone := Icone.new()
		icone.kind = kind
		icone.teinte = teinte
		icone.rouge = str(entree.get("texte", "")).to_lower().contains("rouge")
		icone.custom_minimum_size = Vector2(px(40), px(40))
		icone.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		rang.add_child(icone)
		var texte := _texte(str(entree.get("texte", "")), 30 if essai else (28 if dernier else 26), S.TEXT if dernier or points else Color(S.TEXT, 0.78), true, essai)
		texte.max_lines_visible = 3 if dernier or essai else 2
		texte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		S.G.fill(texte)
		rang.add_child(texte)
		fil.add_child(ligne)
	if visibles.is_empty(): fil.add_child(_texte("Le coup d’envoi approche.", 26, S.MUTED, true))

func _valeur(rang: Dictionary, cote: int) -> String:
	var valeurs: Array = rang.get("valeurs", [0, 0])
	if rang.get("vide", false): return "—"
	var texte := str(int(valeurs[cote])) + str(rang.get("unite", ""))
	if rang.get("sur") is Array: texte += "/%d" % int(rang.sur[cote])
	return texte

func _ligne_chiffre(parent: Control, rang: Dictionary) -> void:
	# Chiffres clés (sous les onglets) : valeurs en grand, aux couleurs des clubs.
	var grand := parent == chiffres
	var ligne := S.G.h(px(12))
	ligne.custom_minimum_size.y = px(62 if grand else 40)
	var titre := _texte(str(rang.get("label", "")), 26, S.MUTED)
	titre.clip_text = true
	titre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titre.custom_minimum_size.x = px(150)
	S.G.fill(titre, false, 1.2)
	ligne.add_child(titre)
	var a := _texte(_valeur(rang, 0), 46 if grand else 28, terrain.couleurs[0].lightened(0.35) if grand else S.TEXT, false, true)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	a.custom_minimum_size.x = px(110 if grand else 78)
	ligne.add_child(a)
	var barre := Barre.new()
	barre.valeurs = rang.get("valeurs", [0, 0]) if not rang.get("vide", false) else [0, 0]
	barre.couleurs = terrain.couleurs.duplicate()
	barre.densite = _densite
	barre.custom_minimum_size = Vector2(px(90), px(30))
	S.G.fill(barre, false, 1.0)
	ligne.add_child(barre)
	var b := _texte(_valeur(rang, 1), 46 if grand else 28, terrain.couleurs[1].lightened(0.35) if grand else S.TEXT, false, true)
	b.custom_minimum_size.x = px(110 if grand else 78)
	ligne.add_child(b)
	parent.add_child(ligne)

func _remplir_chiffres(direct: Dictionary, live: Dictionary) -> void:
	S.clear(chiffres)
	S.clear(tableau)
	var rangs: Array = direct.get("tableau", [])
	# Cinq chiffres clés : d'abord ceux qui disent déjà quelque chose (une stat encore vide en
	# début de match cède sa place), sinon les libellés sans valeur (« — »).
	var par_cle := {}
	for rang: Dictionary in rangs: par_cle[str(rang.get("cle", ""))] = rang
	var choisis: Array = []
	for cle: String in CLES + RELAIS:
		if par_cle.has(cle) and not par_cle[cle].get("vide", false) and choisis.size() < CLES.size(): choisis.append(par_cle[cle])
	for cle: String in CLES:
		if par_cle.has(cle) and par_cle[cle].get("vide", false) and choisis.size() < CLES.size(): choisis.append(par_cle[cle])
	for rang: Dictionary in choisis: _ligne_chiffre(chiffres, rang)
	var equipes: Array = live.get("teams", [])
	var entete := S.G.h(px(12))
	for cote in 2:
		var nom := _texte(S.G.club_abbr(equipes[cote]) if equipes.size() > cote and equipes[cote] is Dictionary else "", 26, terrain.couleurs[cote].lightened(0.2), false, true)
		nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if cote == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		S.G.fill(nom)
		entete.add_child(nom)
	tableau.add_child(entete)
	for rang: Dictionary in rangs: _ligne_chiffre(tableau, rang)
	# Chiffres du moteur qui ne se comparent pas en barre (tirs, cartons).
	for rang: Dictionary in direct.get("statsRows", []):
		if not str(rang.get("label", "")) in ["Cartons jaunes", "Tirs de pénalité", "Transformations", "Dont non disputées"]: continue
		var ligne := S.G.h(px(12))
		var titre := _texte(str(rang.get("label", "")), 26, S.MUTED)
		S.G.fill(titre)
		ligne.add_child(titre)
		ligne.add_child(_texte("%s  —  %s" % [str(rang.get("home", "")), str(rang.get("away", ""))], 28, S.TEXT, false, true))
		tableau.add_child(ligne)

## Mon XV : numéro, nom, note du match, énergie et alertes (fatigue, blessure, carton).
func _remplir_xv(joueurs: Array, direct: Dictionary) -> void:
	S.clear(xv)
	alertes_xv.clear()
	var notes: Dictionary = direct.get("notes", {}) if direct.get("notes") is Dictionary else {}
	var cartons: Dictionary = {}
	for carton: Variant in direct.get("cartons", []):
		if carton is Dictionary: cartons[str(carton.get("id", ""))] = carton
	if joueurs.is_empty():
		xv.add_child(_texte("Composition indisponible.", 26, S.MUTED, true))
		return
	var entete := S.G.h(px(10))
	for colonne in [["N°", 50], ["Joueur", 0], ["Note", 80], ["Énergie", 170]]:
		var titre := _texte(str(colonne[0]), 22, S.MUTED)
		if int(colonne[1]) > 0: titre.custom_minimum_size.x = px(colonne[1])
		else: S.G.fill(titre)
		entete.add_child(titre)
	xv.add_child(entete)
	for poste in joueurs.size():
		var joueur: Variant = joueurs[poste]
		var ligne := Button.new()
		ligne.name = "MatchBetweenPlayer%d" % (poste + 1)
		ligne.flat = true
		ligne.custom_minimum_size.y = px(52)
		ligne.focus_mode = Control.FOCUS_ALL
		ligne.set_meta("contextual_enabled", true)
		ligne.pressed.connect(func(): joueur_choisi.emit(poste))
		var rangee := S.G.h(px(10))
		rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
		S.full(rangee)
		ligne.add_child(rangee)
		var numero := _texte(str(poste + 1), 28, S.GOLD, false, true)
		numero.custom_minimum_size.x = px(50)
		rangee.add_child(numero)
		if not joueur is Dictionary:
			rangee.add_child(_texte("Poste vacant", 26, S.MUTED))
			xv.add_child(ligne)
			continue
		var id := str(joueur.get("id", ""))
		var nom := _texte(str(joueur.get("name", "")), 26, S.TEXT)
		nom.clip_text = true
		nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		S.G.fill(nom)
		rangee.add_child(nom)
		var fiche: Dictionary = notes.get(id, {}) if notes.get(id) is Dictionary else {}
		var note := float(fiche.get("note", 6.0))
		var etiquette_note := _texte("%.1f" % note, 28, Color("9fd5a6") if note >= 7.0 else (Color("e88d6a") if note < 5.5 else S.TEXT), false, true)
		etiquette_note.custom_minimum_size.x = px(80)
		etiquette_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rangee.add_child(etiquette_note)
		var condition := float(joueur.get("condition", 100))
		var energie := Energie.new()
		energie.valeur = condition
		energie.densite = _densite
		energie.custom_minimum_size = Vector2(px(100), px(30))
		energie.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rangee.add_child(energie)
		var pourcent := _texte("%d %%" % roundi(condition), 22, S.MUTED)
		pourcent.custom_minimum_size.x = px(62)
		rangee.add_child(pourcent)
		var alerte := ""
		if int(joueur.get("injury", 0)) > 0: alerte = "blessé"
		elif cartons.has(id): alerte = "carton jaune, retour %s′" % str(cartons[id].get("retour", "")) if cartons[id].get("retour") != null else "exclu"
		elif condition < EPUISE: alerte = "épuisé"
		elif condition < FATIGUE: alerte = "fatigué"
		var detail := "%d · %s · %s\nNote %.1f (%d action%s du match)" % [poste + 1, str(joueur.get("pos", "")), str(joueur.get("name", "")), note, int(fiche.get("faits", 0)), "s" if int(fiche.get("faits", 0)) > 1 else ""]
		if not alerte.is_empty():
			alertes_xv.append({"poste": poste, "id": id, "nom": str(joueur.get("name", "")), "alerte": alerte, "condition": condition})
			var marque := _texte(alerte.to_upper(), 20, Color("f0a070") if alerte != "fatigué" else S.GOLD, false, true)
			rangee.add_child(marque)
			detail += "\n" + alerte.capitalize()
		ligne.tooltip_text = detail + "\nCliquer : ouvrir le banc sur ce joueur."
		xv.add_child(ligne)

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

## L'adjoint : alertes de Mon XV d'abord, puis son regard sur les consignes, et les accès directs.
func _remplir_adjoint(conseil: Variant, live: Dictionary, direct: Dictionary, appliquer: Callable) -> void:
	S.clear(adjoint)
	adjoint_cadre.visible = not live.get("finished", false)
	# Carte de l'adjoint : son portrait et une seule phrase forte (l'alerte la plus grave, sinon
	# sa lecture du match, sinon sa première raison) ; le reste en infobulle.
	var carte := S.G.h(px(16))
	adjoint.add_child(carte)
	var portrait := TextureRect.new()
	var image := AtlasTexture.new()
	image.atlas = PORTRAIT
	image.region = Rect2(0, 0, 313.5, 313.5)
	image.filter_clip = true
	portrait.texture = image
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(px(120), px(120))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var matte := ShaderMaterial.new()
	matte.shader = MATTE
	portrait.material = matte
	carte.add_child(portrait)
	var colonne := S.G.v(px(6))
	S.G.fill(colonne)
	carte.add_child(colonne)
	colonne.add_child(_titre("Gabi · l’adjoint"))
	var graves := alertes_xv.filter(func(a: Dictionary): return a.alerte != "fatigué")
	var fatigues := alertes_xv.filter(func(a: Dictionary): return a.alerte == "fatigué")
	var phrases: Array = []
	for alerte: Dictionary in (graves + fatigues).slice(0, 1):
		var texte := "N° %d %s : %s." % [int(alerte.poste) + 1, str(alerte.nom), str(alerte.alerte)]
		if str(alerte.alerte) in ["épuisé", "fatigué"]: texte = "N° %d %s : %d %% d’énergie, à surveiller." % [int(alerte.poste) + 1, str(alerte.nom), roundi(float(alerte.condition))]
		if str(alerte.alerte) == "épuisé": texte = "N° %d %s est à bout (%d %%) : un remplacement s’impose." % [int(alerte.poste) + 1, str(alerte.nom), roundi(float(alerte.condition))]
		phrases.append([texte, Color("f0b080")])
	var raisons: Array = []
	if conseil is Dictionary:
		for raison in [conseil.get("attackReason", ""), conseil.get("defenceReason", "")]:
			if not str(raison).is_empty(): raisons.append(str(raison))
	var lecture := _lecture(direct)
	if not lecture.is_empty(): raisons.push_front(lecture)
	raisons = _sans_redites(raisons)
	if phrases.is_empty() and not raisons.is_empty(): phrases.append([_phrase_forte(raisons), S.TEXT])
	for phrase: Array in phrases:
		var etiquette := _texte(str(phrase[0]), 30, phrase[1], true, true)
		etiquette.max_lines_visible = 3
		etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		etiquette.tooltip_text = "\n".join(raisons) if not raisons.is_empty() else str(phrase[0])
		etiquette.mouse_filter = Control.MOUSE_FILTER_PASS
		colonne.add_child(etiquette)
	var actions := S.G.h(px(12))
	colonne.add_child(actions)
	# Le bouton n'apparaît que si l'adjoint propose autre chose que les consignes en place.
	if conseil is Dictionary and (conseil.get("attackChanged", false) or conseil.get("defenceChanged", false)):
		var possible: bool = conseil.get("canAct", false) and conseil.get("defenceAvailable", false)
		var bouton := _bouton("APPLIQUER", func(): appliquer.call(conseil), possible, true)
		bouton.name = "MatchBetweenApplyAdvice"
		bouton.tooltip_text = "Appliquer les consignes proposées." if possible else "Mettez le match en pause pour modifier vos consignes."
		S.G.fill(bouton)
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
