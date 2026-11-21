extends RefCounted
## Carte joueur au survol (demande de Léo du 21/11/2026) : survol d'un nom ou d'un visage de joueur, la carte apparaît
## après un court délai à côté de lui ; la souris part, elle disparaît ; Échap la ferme ; un clic garde son effet
## habituel (petite fenêtre du joueur) et range la carte. Elle ne met jamais le match en pause.
## Deux options à départager (CD_VARIANTE_VISUELLE, « A » ou « B », éventuellement après la variante de l'écran :
## « D3-B ») : A « Fiche complète » (en-tête, grille des 36 attributs, rapport du staff, état, polyvalence) ;
## B « Carte compacte » (en-tête, postes en étoiles, six attributs clés du poste en jauges, rapport du staff).
## Dans le direct, l'état du joueur dans le match (note, énergie, plaquages…) passe en tête.
## Étoiles d'adaptabilité au poste (sur 5, demi-étoiles) : note au poste du moteur rapportée à son meilleur poste,
## voir `etoiles_poste` ; la note du joueur reste son niveau de base.
## Exemple : `CarteJoueurSurvol.lier(app, bouton_du_nom, str(player.id), "squad", func(): return infos_du_match)`.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")
const Knowledge = preload("res://ui/player_knowledge_text.gd")
const Identity = preload("res://ui/player_identity.gd")
const NotesMatch = preload("res://ui/notes_match.gd")
const NOM := "CarteJoueurSurvol"
const GUETTEUR := "CarteJoueurSurvolGuetteur"
## Délai avant l'apparition (secondes) : un passage rapide de la souris n'ouvre rien.
const DELAI := 0.35
const MARGE := 8.0
const POSTES := ["Pilier gauche", "Talonneur", "Pilier droit", "2e ligne", "2e ligne", "3e ligne aile", "3e ligne aile",
	"Numéro 8", "Demi de mêlée", "Demi d’ouverture", "Ailier", "Centre", "Centre", "Ailier", "Arrière"]
## Barème des étoiles d'adaptabilité : [part minimale de la note au meilleur poste, étoiles].
const BAREME_ETOILES := [[0.97, 5.0], [0.92, 4.5], [0.87, 4.0], [0.80, 3.5], [0.72, 3.0], [0.64, 2.5], [0.56, 2.0],
	[0.48, 1.5], [0.40, 1.0], [0.30, 0.5]]
## Six attributs clés par poste (option B), clés attributesV2.
const CLES_POSTE := {
	1: ["scrumTechnique", "strength", "maul", "tackling", "ruckClearout", "endurance"],
	2: ["hooking", "lineoutThrow", "scrumTechnique", "strength", "tackling", "maul"],
	4: ["lineoutJump", "lineoutLift", "maul", "strength", "ruckClearout", "tackling"],
	6: ["tackling", "jackal", "workRate", "ruckClearout", "ballCarry", "endurance"],
	8: ["ballCarry", "tackling", "strength", "workRate", "decisions", "lineoutJump"],
	9: ["passing", "decisions", "kickAccuracy", "acceleration", "vision", "workRate"],
	10: ["kickDistance", "kickAccuracy", "goalAccuracy", "passing", "vision", "decisions"],
	11: ["topSpeed", "acceleration", "evasion", "aerialAbility", "kickChase", "ballHandling"],
	12: ["ballCarry", "tackling", "passing", "evasion", "strength", "decisions"],
	15: ["aerialAbility", "kickDistance", "topSpeed", "positioning", "evasion", "receiving"],
}
const FAMILLE_CLES := {3: 1, 5: 4, 7: 6, 13: 12, 14: 11}

static func _commune() -> Script:
	return load("res://ui/immersive08/fiche_commune.gd")

## « A » (fiche complète) ou « B » (carte compacte), lue dans CD_VARIANTE_VISUELLE (« B », « D3-B »…).
static func variante() -> String:
	for morceau: String in OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper().replace(",", "-").split("-", false):
		if morceau == "B": return "B"
	return "A"

# --- Étoiles d'adaptabilité ------------------------------------------------------------------------------------------

## Étoiles (0 à 5, par demi) du joueur au poste `numero` (1-15) : note au poste du moteur (positionRatings) divisée par
## sa meilleure note au poste, puis BAREME_ETOILES. -1 si le staff ne connaît pas ses notes au poste ; 0 au premier
## rang non qualifié (note 0).
static func etoiles_poste(player: Dictionary, numero: int) -> float:
	var notes: Variant = player.get("positionRatings")
	if not notes is Dictionary or (notes as Dictionary).is_empty(): return -1.0
	var meilleure := 0.0
	for valeur: Variant in (notes as Dictionary).values():
		if Knowledge.number(valeur): meilleure = maxf(meilleure, float(valeur))
	var note: Variant = notes.get(str(numero))
	if meilleure <= 0.0 or not Knowledge.number(note): return -1.0
	return etoiles_part(float(note) / meilleure)

static func etoiles_part(part: float) -> float:
	for palier: Array in BAREME_ETOILES:
		if part >= float(palier[0]) - 0.0001: return float(palier[1])
	return 0.0

## Étoiles d'un niveau sur 100 (rapport du staff) : 85 et plus = 5, puis une demi-étoile tous les 5 points.
static func etoiles_niveau(valeur: float) -> float:
	return clampf(floorf((valeur - 35.0) / 5.0) * 0.5, 0.0, 5.0)

## Couleur des étoiles : barème des attributs (5 = vert d'eau, 3 = citron, 1 = rouge).
static func couleur_etoiles(etoiles: float) -> Color:
	return Charte.couleur_attribut(etoiles * 20.0 - 1.0 if etoiles >= 5.0 else etoiles * 20.0)

## Postes du joueur triés par étoiles, regroupés par rôle (« 11 · 14 Ailier ») : [{numeros, poste, etoiles, note}].
static func postes_tries(player: Dictionary) -> Array:
	var groupes := {}
	for numero in range(1, 16):
		var etoiles := etoiles_poste(player, numero)
		if etoiles < 0.0: return []
		var cle := "%s|%s" % [POSTES[numero - 1], etoiles]
		if not groupes.has(cle):
			var note: Variant = player.get("positionRatings", {}).get(str(numero))
			groupes[cle] = {"numeros": [], "poste": POSTES[numero - 1], "etoiles": etoiles, "note": float(note) if Knowledge.number(note) else 0.0}
		groupes[cle].numeros.append(numero)
	var liste: Array = groupes.values()
	liste.sort_custom(func(a: Dictionary, b: Dictionary): return a.etoiles > b.etoiles or (a.etoiles == b.etoiles and (a.note > b.note or (a.note == b.note and a.numeros[0] < b.numeros[0]))))
	return liste

# --- Branchement et guetteur -----------------------------------------------------------------------------------------

## Branche la carte sur un contrôle (nom, visage, tuile). `direct` (facultatif) renvoie l'état du joueur dans le match
## ({energie, note, plaquages, plaquages_manques, courses, passes, etat, alerte}), lu à chaque apparition.
## L'info-bulle système (une fenêtre) est retirée : la carte la remplace.
static func lier(app: Control, controle: Control, player_id: String, source: String = "squad", direct: Callable = Callable()) -> void:
	if player_id.is_empty() or not is_instance_valid(app): return
	controle.tooltip_text = ""
	controle.set_meta("carte_joueur", player_id)
	controle.set_meta("carte_source", source)
	if direct.is_valid(): controle.set_meta("carte_direct", direct)
	if controle.mouse_filter == Control.MOUSE_FILTER_IGNORE: controle.mouse_filter = Control.MOUSE_FILTER_PASS
	guetteur(app).retenir(controle)

## Le guetteur vit à la racine de l'arbre (dernier enfant quand la carte s'ouvre) : il reçoit Échap avant l'écran
## en cours (menu du match).
static func guetteur(app: Control) -> Guetteur:
	var existant: Variant = app.get_meta("carte_guetteur") if app.has_meta("carte_guetteur") else null
	if is_instance_valid(existant) and existant is Guetteur: return existant
	var g := Guetteur.new()
	g.name = GUETTEUR
	g.app = app
	app.set_meta("carte_guetteur", g)
	app.tree_exiting.connect(func(): if is_instance_valid(g): g.queue_free())
	if app.is_inside_tree(): app.get_tree().root.add_child.call_deferred(g)
	else: app.add_child(g)
	return g

## Carte affichée (ou null).
static func actuelle(app: Control) -> Control:
	var carte := app.get_node_or_null(NOM) as Control if is_instance_valid(app) else null
	return carte if carte != null and not carte.is_queued_for_deletion() else null

static func cacher(app: Control) -> void:
	var carte := actuelle(app)
	if carte == null: return
	carte.hide()
	carte.name = NOM + "Fermee"
	carte.queue_free()

## Montre la carte du joueur à côté de `ancre` (sans délai : utilisé par le guetteur et les suites).
static func montrer(app: Control, player_id: String, source: String, ancre: Control, direct: Dictionary = {}) -> Control:
	cacher(app)
	if not is_instance_valid(ancre) or not ancre.is_inside_tree(): return null
	var trouve: Dictionary = _commune().trouver(app, player_id, source)
	if trouve.is_empty(): return null
	# Densité du gabarit (2560 × 1440 = 1) lue sur l'écran au moment de l'apparition, puis rendue telle quelle.
	var avant := C.density
	var ecran := app.get_viewport_rect().size
	C.configure(ecran.y, ecran.x)
	var carte := construire(app, trouve.joueur, trouve.source, direct)
	C.density = avant
	carte.set_meta("player_id", player_id)
	carte.set_meta("ancre", ancre)
	app.add_child(carte)
	placer(carte, ancre, app.get_viewport_rect().size)
	var g := guetteur(app)
	if g.is_inside_tree() and g.get_parent() != null: g.get_parent().move_child(g, -1)
	return carte

## À droite de l'ancre (à gauche s'il manque la place), le haut aligné sur elle ; toujours entière dans l'écran.
static func placer(carte: Control, ancre: Control, ecran: Vector2) -> void:
	var t := ancre.get_global_transform_with_canvas()
	var zone := Rect2(t.origin, ancre.size * t.get_scale())
	var taille := carte.size
	var ecart := maxf(8.0, C.px(14))
	var x := zone.end.x + ecart
	if x + taille.x > ecran.x - MARGE: x = zone.position.x - taille.x - ecart
	var y := zone.position.y - C.px(24)
	carte.position = Vector2(clampf(x, MARGE, maxf(MARGE, ecran.x - taille.x - MARGE)), clampf(y, MARGE, maxf(MARGE, ecran.y - taille.y - MARGE)))

## Suit le contrôle survolé (gui_get_hovered_control) : un nom et sa tuile désignent le même joueur, la carte reste.
class Guetteur extends Node:
	var Carte = load("res://ui/carte_joueur_survol.gd")
	var app: Control
	var joueur := ""
	var ancre: Control
	## Début du survol (horloge réelle, en ms) : le délai ne dépend ni de la cadence d'images ni de la vitesse du jeu.
	var depuis := 0
	## Joueur dont la carte a été fermée (Échap, clic) : rien ne se rouvre tant que la souris reste sur lui.
	var masque := ""
	## Contrôles liés (pour retrouver le joueur sous la souris quand l'écran du direct se redessine sous elle).
	var lies: Array = []
	var souris := Vector2(-1, -1)

	func retenir(controle: Control) -> void:
		if lies.size() > 256: _purger()
		lies.append(controle)

	func _purger() -> void:
		var vivants: Array = []
		for c: Variant in lies:
			if is_instance_valid(c): vivants.append(c)
		lies = vivants

	## Joueur lié sous la souris quand le contrôle survolé a disparu (Mon XV redessiné à chaque action du direct) :
	## la carte reste ouverte au lieu de clignoter.
	func _sous_souris() -> Control:
		if souris.x < 0: return null
		_purger()
		for c: Variant in lies:
			if (c as Control).is_inside_tree() and c.is_visible_in_tree() and c.get_global_rect().has_point(souris): return _lie(c)
		return null

	func _process(_delta: float) -> void:
		if not is_instance_valid(app): return
		var survole := get_viewport().gui_get_hovered_control()
		var lie := _lie(survole) if survole != null else _sous_souris()
		var id := str(lie.get_meta("carte_joueur")) if lie != null else ""
		if id != joueur:
			joueur = id
			ancre = lie
			depuis = Time.get_ticks_msec()
			if masque != id: masque = ""
			Carte.cacher(app)
		# Mon XV redessiné sous la souris : même joueur, nouveau contrôle (l'ancien est libéré).
		if lie != null: ancre = lie
		if id.is_empty() or id == masque: return
		if Carte.actuelle(app) != null: return
		if Time.get_ticks_msec() - depuis < int(Carte.DELAI * 1000.0) or not is_instance_valid(ancre): return
		var direct: Dictionary = {}
		var lecture: Variant = ancre.get_meta("carte_direct") if ancre.has_meta("carte_direct") else null
		if lecture is Callable and (lecture as Callable).is_valid():
			var lu: Variant = (lecture as Callable).call()
			if lu is Dictionary: direct = lu
		Carte.montrer(app, id, str(ancre.get_meta("carte_source", "squad")), ancre, direct)

	## Contrôle lié le plus haut (la tuile plutôt que le nom qu'elle contient) pour le joueur survolé.
	func _lie(controle: Control) -> Control:
		var trouve: Control = null
		var id := ""
		var n: Node = controle
		while n != null and n != app:
			if n is Control and n.has_meta("carte_joueur"):
				if trouve == null: id = str(n.get_meta("carte_joueur"))
				if str(n.get_meta("carte_joueur")) == id: trouve = n
			n = n.get_parent()
		return trouve

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion: souris = (event as InputEventMouseMotion).position
		if not is_instance_valid(app) or Carte.actuelle(app) == null: return
		var touche := event as InputEventKey
		if touche != null and touche.pressed and not touche.echo and touche.keycode == KEY_ESCAPE:
			masque = joueur
			Carte.cacher(app)
			get_viewport().set_input_as_handled()
			return
		var clic := event as InputEventMouseButton
		if clic != null and clic.pressed:
			masque = joueur
			Carte.cacher(app)

# --- Dessins : étoiles, mini-terrain, jauge -------------------------------------------------------------------------

## Cinq étoiles (pleines, demi, vides) ; la valeur est aussi portée par le nombre d'étoiles pleines (forme).
class Etoiles extends Control:
	var valeur := 0.0
	var couleur := Color.WHITE
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := minf(size.y / 2.0, size.x / 10.4)
		var pas := size.x / 5.0
		for i in 5:
			var centre := Vector2(pas * i + pas / 2.0, size.y / 2.0)
			var etoile := _forme(centre, r)
			draw_colored_polygon(etoile, Color(0.95, 0.93, 0.86, 0.16))
			var part := clampf(valeur - i, 0.0, 1.0)
			if part >= 0.99: draw_colored_polygon(etoile, couleur)
			elif part >= 0.49:
				var moitie := PackedVector2Array([centre + Vector2(-r - 1, -r - 1), centre + Vector2(0, -r - 1), centre + Vector2(0, r + 1), centre + Vector2(-r - 1, r + 1)])
				for morceau: PackedVector2Array in Geometry2D.intersect_polygons(etoile, moitie): draw_colored_polygon(morceau, couleur)
	static func _forme(centre: Vector2, r: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		for k in 10:
			var angle := -PI / 2.0 + k * PI / 5.0
			points.append(centre + Vector2(cos(angle), sin(angle)) * (r if k % 2 == 0 else r * 0.45))
		return points

## Mini-terrain des 15 postes : pastille numérotée à la couleur des étoiles, cerclée de crème au poste principal.
class MiniTerrain extends Control:
	const Charte = preload("res://ui/charte.gd")
	const C = preload("res://ui/immersive08/components.gd")
	const PLACES := [Vector2(.24, .11), Vector2(.5, .11), Vector2(.76, .11), Vector2(.38, .22), Vector2(.62, .22), Vector2(.14, .27),
		Vector2(.86, .27), Vector2(.5, .33), Vector2(.4, .46), Vector2(.64, .53), Vector2(.1, .73), Vector2(.4, .64), Vector2(.62, .72),
		Vector2(.9, .73), Vector2(.5, .88)]
	var etoiles: Array = []
	var principaux: Array = []
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var fond := StyleBoxFlat.new()
		fond.bg_color = Charte.PELOUSE
		fond.set_corner_radius_all(maxi(3, C.px(6)))
		draw_style_box(fond, Rect2(Vector2.ZERO, size))
		var ligne_t := Color(Charte.CREME, .22)
		draw_line(Vector2(0, size.y * .5), Vector2(size.x, size.y * .5), ligne_t, 1.0)
		draw_rect(Rect2(size.x * .3, 0, size.x * .4, size.y * .05), ligne_t, false, 1.0)
		draw_rect(Rect2(size.x * .3, size.y * .95, size.x * .4, size.y * .05), ligne_t, false, 1.0)
		var r := minf(size.x * .085, size.y * .055)
		var police: Font = C.font(800)
		var taille := maxi(10, int(r * 1.15))
		for i in 15:
			var centre := Vector2(PLACES[i].x * size.x, PLACES[i].y * size.y)
			var e: float = float(etoiles[i]) if i < etoiles.size() else -1.0
			var teinte: Color = Color(Charte.CREME, .14) if e <= 0.0 else load("res://ui/carte_joueur_survol.gd").couleur_etoiles(e)
			if (i + 1) in principaux: draw_circle(centre, r + maxf(2.0, r * .22), Charte.CREME)
			draw_circle(centre, r, teinte)
			var texte := str(i + 1)
			var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
			var encre: Color = Charte.ENCRE if e > 0.0 else Charte.IVOIRE_3
			draw_string(police, centre + Vector2(-largeur / 2.0, police.get_ascent(taille) / 2.0 - 1.0), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, encre)

# --- Construction ----------------------------------------------------------------------------------------------------

static func _panneau(parent: Node, zone: Rect2, couleur: Color = Charte.PANNEAU, rayon: int = Charte.RAYON_CARTE) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", Charte.sans_ombre(C.box(couleur, Color.TRANSPARENT, rayon, 0)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	D.place(p, zone)
	return p

static func _etoiles(parent: Node, zone: Rect2, valeur: float, nom: String = "") -> Control:
	var e := Etoiles.new()
	e.valeur = valeur
	e.couleur = couleur_etoiles(valeur)
	if not nom.is_empty(): e.name = nom
	parent.add_child(e)
	D.place(e, zone)
	return e

static func _titre(parent: Node, x: float, y: float, texte: String, largeur: float) -> Label:
	var l := D.text(parent, x, y, texte.to_upper(), 24, Charte.IVOIRE, 700, largeur)
	return l

static func _nombre(v: Variant) -> bool:
	return Knowledge.number(v)

static func _teinte_note(note: float) -> Color:
	if note >= 8.0: return Charte.ATTRIBUT_85
	if note >= 7.0: return Charte.ATTRIBUT_75
	if note >= 6.5: return Charte.ATTRIBUT_65
	if note >= 6.0: return Charte.ATTRIBUT_55
	if note >= 5.0: return Charte.ATTRIBUT_40
	return Charte.ATTRIBUT_0

static func construire(app: Control, player: Dictionary, source: String, direct: Dictionary = {}) -> Panel:
	var v := variante()
	var largeur := 1260.0 if v == "A" else 780.0
	var carte := Panel.new()
	carte.name = NOM
	carte.z_index = 100
	carte.set_meta("variante", v)
	var fond := C.box(Charte.PANNEAU_3, Color.TRANSPARENT, Charte.RAYON_PANNEAU, 0)
	fond.shadow_color = Color(0, 0, 0, .55)
	fond.shadow_size = maxi(4, C.px(18))
	carte.add_theme_stylebox_override("panel", fond)
	var y := _entete(carte, app, player, source, largeur, v)
	if not direct.is_empty() and direct.has("energie"): y = _bande_match(carte, direct, largeur, y + 18.0, v)
	if v == "A": y = _corps_a(carte, app, player, source, largeur, y + 18.0)
	else: y = _corps_b(carte, app, player, source, largeur, y + 18.0)
	carte.size = Vector2(largeur, y + 24.0) * C.density
	_ignorer_souris(carte)
	return carte

## En-tête : portrait, numéro, nom, postes, origine et mensurations ; à droite (A) contrat, salaire et valeur.
static func _entete(carte: Panel, app: Control, player: Dictionary, source: String, largeur: float, v: String) -> float:
	var cote := 176.0 if v == "A" else 132.0
	var cadre := _panneau(carte, Rect2(24, 24, cote, cote), Charte.PANNEAU)
	cadre.clip_contents = true
	cadre.name = "CarteJoueurPortrait"
	if not str(player.get("id", "")).is_empty():
		var portrait := G.portrait(int(player.get("portraitIndex", 0)), C.px(cote), player)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cadre.add_child(portrait)
		D.place(portrait, Rect2(0, 0, cote, cote))
	var x := 24.0 + cote + 24.0
	var droite := largeur - 24.0 - (330.0 if v == "A" else 0.0)
	var numero: Variant = player.get("shirtNumber")
	var nom_x := x
	if _nombre(numero):
		var pastille := _panneau(carte, Rect2(x, 30, 58, 46), Charte.VERT_FRANC, Charte.RAYON_PETIT)
		pastille.name = "CarteJoueurNumero"
		var chiffre := D.text(pastille, 29, 36, G.n(numero), 30, Charte.CREME, 800, 58, HORIZONTAL_ALIGNMENT_CENTER)
		chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA)
		nom_x += 72.0
	var nom := D.text(carte, nom_x, 70, str(player.get("name", "—")).to_upper(), 40 if v == "A" else 34, Charte.CREME, 800, droite - nom_x)
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	nom.name = "CarteJoueurNom"
	# Postes : principal, puis les secondaires (numéros).
	var postes: Array[String] = []
	var principal: Variant = player.get("primaryPosition")
	var poste_txt := str(player.get("pos", "—"))
	for n: Variant in player.get("primaryPositions", [principal] if _nombre(principal) else []):
		if _nombre(n): postes.append(str(int(n)))
	var secondaires: Array[String] = []
	for n: Variant in player.get("secondaryPositions", []):
		if _nombre(n): secondaires.append(str(int(n)))
	var ligne_poste := poste_txt + ("  ·  n° " + " · ".join(postes) if not postes.is_empty() else "") + ("  (" + " · ".join(secondaires) + ")" if not secondaires.is_empty() else "")
	D.text(carte, x, 114 if v == "A" else 106, ligne_poste, 22, Charte.IVOIRE, 600, droite - x).name = "CarteJoueurPostes"
	# Origine : drapeau, pays, âge, taille et poids, sélections.
	var facts: Dictionary = player.get("playerFacts", {}) if player.get("playerFacts") is Dictionary else {}
	var ox := x
	var drapeau := Identity.flag_texture(str(facts.get("flagCode", "")) if facts.get("flagCode") is String else "")
	var base_origine := 150.0 if v == "A" else 140.0
	if drapeau != null:
		var image := TextureRect.new()
		image.texture = drapeau
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		carte.add_child(image)
		D.place(image, Rect2(ox, base_origine - 18, 30, 20))
		ox += 40.0
	var origine: Array[String] = []
	if facts.get("nationality") is String and not str(facts.nationality).is_empty(): origine.append(str(facts.nationality))
	if _nombre(player.get("age")): origine.append(G.n(player.age) + " ans")
	if _nombre(facts.get("heightCm")): origine.append(("%.2f m" % (float(facts.heightCm) / 100.0)).replace(".", ","))
	if _nombre(facts.get("weightKg")): origine.append(G.n(facts.weightKg) + " kg")
	if _nombre(facts.get("seniorCaps")) and int(facts.seniorCaps) > 0: origine.append(G.n(facts.seniorCaps) + " sél.")
	D.text(carte, ox, base_origine, "  ·  ".join(origine), 20, Charte.IVOIRE_2, 600, droite - ox).name = "CarteJoueurOrigine"
	# Statut (pastille) et contrat.
	var commune := _commune()
	var statut := str(player.get("status", "")) if source == "squad" else str(commune.statut_feuille(player, source))
	var base_statut := 186.0 if v == "A" else 174.0
	var sx := x
	if not statut.is_empty():
		var police: Font = C.font(700)
		var w := police.get_string_size(statut, HORIZONTAL_ALIGNMENT_LEFT, -1, C.font_px(19)).x / C.density + 28.0
		var pastille := _panneau(carte, Rect2(sx, base_statut - 24, w, 32), Charte.VOILE_VERT, Charte.RAYON_PETIT)
		pastille.name = "CarteJoueurStatut"
		D.text(pastille, 14, 22, statut, 19, Charte.VERT_CLAIR, 700, w - 28)
		sx += w + 14.0
	var dispo: Dictionary = commune.disponibilite(app, player, source)
	if not dispo.etat in ["apte"]:
		D.text(carte, sx, base_statut, str(dispo.texte), 19, dispo.couleur, 700, droite - sx).name = "CarteJoueurDispo"
	elif v == "B":
		var contrat: Array[String] = []
		if _nombre(player.get("contractEnd")): contrat.append("contrat " + str(commune.echeance(app, player)).replace(" ⧗ fin de saison", " ⧗"))
		if _nombre(player.get("salary")): contrat.append(G.salary(player.salary))
		D.text(carte, sx, base_statut, "  ·  ".join(contrat), 19, Charte.IVOIRE_2, 600, droite - sx).name = "CarteJoueurContrat"
	if v == "A":
		# Colonne de droite : contrat, salaire, valeur (libellé à gauche, valeur à droite).
		var gx := largeur - 24.0 - 310.0
		_panneau(carte, Rect2(gx, 24, 310, cote), Charte.PANNEAU)
		var lignes := [["CONTRAT", str(commune.echeance(app, player)).replace(" ⧗ fin de saison", " ⧗") if _nombre(player.get("contractEnd")) else "—"],
			["SALAIRE", G.salary(player.salary) if _nombre(player.get("salary")) else "—"],
			["VALEUR", G.euros(player.marketValue) if _nombre(player.get("marketValue")) else "—"]]
		for i in lignes.size():
			var by := 24.0 + 46.0 + i * 52.0
			D.text(carte, gx + 18, by, lignes[i][0], 18, Charte.IVOIRE_2, 700, 110)
			D.text(carte, gx + 292, by, lignes[i][1], 24, Charte.CREME, 700, 180, HORIZONTAL_ALIGNMENT_RIGHT).name = "CarteJoueurContrat%d" % i
	return maxf(24.0 + cote, base_statut + 14.0)

## L'état du joueur dans ce match : note, énergie, plaquages (et manqués), courses, passes, état après la causerie.
static func _bande_match(carte: Panel, direct: Dictionary, largeur: float, y: float, v: String) -> float:
	var hauteur := 96.0
	var bande := _panneau(carte, Rect2(24, y, largeur - 48, hauteur), Charte.PANNEAU)
	bande.name = "CarteJoueurMatch"
	var tuiles: Array = []
	var note := float(direct.get("note", 6.5))
	tuiles.append(["NOTE", ("%.1f" % note).replace(".", ","), _teinte_note(note), "note"])
	var energie := float(direct.get("energie", 100))
	tuiles.append(["ÉNERGIE", "%d %%" % roundi(energie), Charte.CONDITION if energie >= 70 else (Charte.INTENSIF if energie >= 50 else Charte.PERTE), "energie"])
	var manques := int(direct.get("plaquages_manques", 0))
	tuiles.append(["PLAQUAGES", str(int(direct.get("plaquages", 0))) + (" / %d raté%s" % [manques, "s" if manques > 1 else ""] if manques > 0 and v == "A" else ""), Charte.CREME, ""])
	if v == "A":
		tuiles.append(["COURSES", str(int(direct.get("courses", 0))), Charte.CREME, ""])
		tuiles.append(["PASSES", str(int(direct.get("passes", 0))), Charte.CREME, ""])
	var humeur: Variant = direct.get("etat", {})
	var alerte := str(direct.get("alerte", ""))
	var etat := alerte.get_slice(",", 0) if not alerte.is_empty() else (str(humeur.get("label", "")) if humeur is Dictionary else "")
	tuiles.append(["ÉTAT", etat if not etat.is_empty() else "—", Charte.PERTE if not alerte.is_empty() else Charte.MORAL, ""])
	var w := (largeur - 48.0) / tuiles.size()
	for i in tuiles.size():
		var t: Array = tuiles[i]
		var tx := i * w
		if i > 0: D.line(bande, Vector2(tx, 16), Vector2(tx, hauteur - 16), Charte.FILET)
		D.text(bande, tx + 18, 34, t[0], 18, Charte.IVOIRE_2, 700, w - 30)
		if t[3] == "note":
			var pastille := _panneau(bande, Rect2(tx + 18, 46, 72, 38), t[2], Charte.RAYON_PETIT)
			pastille.name = "CarteJoueurMatchNote"
			D.text(pastille, 36, 30, t[1], 26, Charte.ENCRE, 800, 72, HORIZONTAL_ALIGNMENT_CENTER)
		elif t[3] == "energie":
			var valeur := D.text(bande, tx + 18, 80, t[1], 26, t[2], 800, 80)
			valeur.name = "CarteJoueurMatchEnergie"
			D.bar(bande, Rect2(tx + 100, 68, w - 124, 10), energie, t[2])
		else:
			D.text(bande, tx + 18, 80, t[1], 26, t[2], 800, w - 30).name = "CarteJoueurMatch_" + str(t[0]).validate_node_name()
	return y + hauteur

## Option A : grille des 36 attributs (quatre familles), puis rapport du staff, état et polyvalence.
static func _corps_a(carte: Panel, app: Control, player: Dictionary, source: String, largeur: float, y: float) -> float:
	var commune := _commune()
	var valeurs: Dictionary = commune.valeurs(player, source)
	var grille := _panneau(carte, Rect2(24, y, largeur - 48, 384), Charte.PANNEAU)
	grille.name = "CarteJoueurAttributs"
	commune.grille_attributs(grille, Vector2(20, 14), Vector2(largeur - 88, 350), valeurs, "CarteJoueurAttribut_", {"titre": 22, "libelle": 19, "valeur": 26, "pas": 36, "ecart": 30, "corps": false, "mot_moyenne": false})
	if valeurs.is_empty(): D.text(grille, 20, 200, "À observer", 22, Charte.IVOIRE_3, 600, 300)
	y += 384.0 + 18.0
	var h := 236.0
	var w1 := 330.0
	var w2 := 260.0
	var w3 := largeur - 48.0 - w1 - w2 - 36.0
	_rapport_staff(carte, app, player, source, Rect2(24, y, w1, h), false)
	_etat(carte, app, player, source, Rect2(24 + w1 + 18, y, w2, h))
	_polyvalence(carte, player, Rect2(24 + w1 + w2 + 36, y, w3, h), 3)
	return y + h

## Option B : postes en étoiles et mini-terrain, six attributs clés du poste en jauges, rapport du staff.
static func _corps_b(carte: Panel, app: Control, player: Dictionary, source: String, largeur: float, y: float) -> float:
	_polyvalence(carte, player, Rect2(24, y, largeur - 48, 236), 3)
	y += 236.0 + 18.0
	var cles := _cles_poste(player)
	var valeurs: Dictionary = _commune().valeurs(player, source)
	var bloc := _panneau(carte, Rect2(24, y, largeur - 48, 238), Charte.PANNEAU)
	bloc.name = "CarteJoueurAttributsCles"
	_titre(bloc, 20, 38, "Attributs clés au poste", 500)
	var libelles := {}
	for groupe: Array in PlayerAttributes.GROUPS:
		for paire: Array in groupe[1]: libelles[paire[0]] = paire[1]
	var colonne := (largeur - 48.0 - 60.0) / 2.0
	for i in cles.size():
		var cx := 20.0 + (i % 2) * (colonne + 20.0)
		var cy := 60.0 + floorf(i / 2.0) * 58.0
		var valeur: Variant = valeurs.get(cles[i])
		D.text(bloc, cx, cy + 22, str(libelles.get(cles[i], cles[i])), 19, Charte.IVOIRE, 600, colonne - 70)
		var chiffre := D.text(bloc, cx + colonne, cy + 24, PlayerAttributes.caption(valeur), 26, Charte.couleur_attribut(valeur), 800, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		chiffre.name = "CarteJoueurCle_" + str(cles[i])
		D.bar(bloc, Rect2(cx, cy + 34, colonne - 70, 10), float(valeur) if _nombre(valeur) else 0.0, Charte.couleur_attribut(valeur))
	y += 238.0 + 18.0
	_rapport_staff(carte, app, player, source, Rect2(24, y, largeur - 48, 128), true)
	return y + 128.0

static func _cles_poste(player: Dictionary) -> Array:
	var principal := int(player.get("primaryPosition", 0)) if _nombre(player.get("primaryPosition")) else 0
	principal = int(FAMILLE_CLES.get(principal, principal))
	return CLES_POSTE.get(principal, CLES_POSTE[10])

## Rapport du staff : niveau actuel et potentiel en étoiles, chiffre écrit (fourchette si le staff hésite), progression
## de la saison (flèche) quand elle est connue.
static func _rapport_staff(carte: Panel, app: Control, player: Dictionary, source: String, zone: Rect2, en_ligne: bool) -> void:
	var bloc := _panneau(carte, zone, Charte.PANNEAU)
	bloc.name = "CarteJoueurRapport"
	var w := zone.size.x
	_titre(bloc, 20, 38, "Rapport du staff", w - 40)
	var propre: bool = _commune().notre_joueur(source)
	var niveau := Knowledge.bounds(player, "rating", propre)
	var potentiel := Knowledge.bounds(player, "potential", propre)
	var lignes := [["Niveau actuel", niveau, G.rating_text(player, propre)], ["Potentiel", potentiel, G.potential_text(player)]]
	for i in lignes.size():
		var x := 20.0 + (i * (w - 40.0) / 2.0 if en_ligne else 0.0)
		var by := 82.0 if en_ligne else 84.0 + i * 74.0
		var bornes: Dictionary = lignes[i][1]
		D.text(bloc, x, by, lignes[i][0], 19, Charte.IVOIRE_2, 600, 160)
		if bornes.is_empty():
			D.text(bloc, x, by + 34, "—", 26, Charte.IVOIRE_3, 800, 100)
			continue
		var milieu := (float(bornes.min) + float(bornes.max)) / 2.0
		_etoiles(bloc, Rect2(x, by + 10, 170, 32), etoiles_niveau(milieu), "CarteJoueurEtoiles" + ("Niveau" if i == 0 else "Potentiel"))
		D.text(bloc, x + 184, by + 36, str(lignes[i][2]), 26, Charte.couleur_attribut(milieu), 800, 110).name = "CarteJoueurChiffre" + ("Niveau" if i == 0 else "Potentiel")
	# Progression de la saison (suivi individuel du moteur) : flèche et écart.
	var gain: Variant = null
	for person: Variant in app.model.get("decisions", {}).get("development", {}).get("professionals", []):
		if person is Dictionary and str(person.get("id", "")) == str(player.get("id", "")):
			var dev: Variant = person.get("development")
			if dev is Dictionary and _nombre(dev.get("seasonStart")) and _nombre(player.get("rating")): gain = roundi(float(player.rating) - float(dev.seasonStart))
	if gain != null and int(gain) != 0:
		var hausse := int(gain) > 0
		D.text(bloc, w - 20, 38, ("▲ +%d" if hausse else "▼ %d") % int(gain), 22, Charte.GAIN if hausse else Charte.PERTE, 800, 120, HORIZONTAL_ALIGNMENT_RIGHT).name = "CarteJoueurProgression"

## État : condition (jauge verte), charge de travail, forme (cinq dernières notes), moral du groupe (bleu).
static func _etat(carte: Panel, app: Control, player: Dictionary, _source: String, zone: Rect2) -> void:
	var bloc := _panneau(carte, zone, Charte.PANNEAU)
	bloc.name = "CarteJoueurEtat"
	var w := zone.size.x
	_titre(bloc, 20, 38, "État", w - 40)
	var condition: Variant = _commune().condition(player)
	D.text(bloc, 20, 82, "Condition", 19, Charte.IVOIRE_2, 600, 140)
	if condition != null:
		D.text(bloc, w - 20, 84, "%d %%" % roundi(float(condition)), 26, Charte.CONDITION, 800, 100, HORIZONTAL_ALIGNMENT_RIGHT).name = "CarteJoueurCondition"
		D.bar(bloc, Rect2(20, 94, w - 40, 10), float(condition), Charte.CONDITION)
	var moral: Variant = app.model.get("meta", {}).get("morale")
	D.text(bloc, 20, 144, "Moral du groupe", 19, Charte.IVOIRE_2, 600, 170)
	if _nombre(moral):
		D.text(bloc, w - 20, 146, G.n(roundi(float(moral))), 26, Charte.MORAL, 800, 80, HORIZONTAL_ALIGNMENT_RIGHT).name = "CarteJoueurMoral"
		D.bar(bloc, Rect2(20, 156, w - 40, 10), float(moral), Charte.MORAL)
	D.text(bloc, 20, 208, "Forme", 19, Charte.IVOIRE_2, 600, 100)
	var forme := NotesMatch.forme(NotesMatch.joueur(app.model, str(player.get("id", ""))))
	if forme.is_empty():
		D.text(bloc, w - 20, 210, "—", 24, Charte.IVOIRE_3, 800, 60, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		var dernieres := forme.slice(maxi(0, forme.size() - 4))
		for i in dernieres.size():
			var note := float(dernieres[i]) if _nombre(dernieres[i]) else 0.0
			var px := w - 20 - (dernieres.size() - i) * 46.0
			var p := _panneau(bloc, Rect2(px, 186, 40, 30), _teinte_note(note), Charte.RAYON_PETIT)
			D.text(p, 20, 23, ("%.1f" % note).replace(".", ","), 18, Charte.ENCRE, 800, 40, HORIZONTAL_ALIGNMENT_CENTER)

## Polyvalence : les meilleurs postes en étoiles (numéros et rôle) et le mini-terrain des 15 postes.
static func _polyvalence(carte: Panel, player: Dictionary, zone: Rect2, combien: int) -> void:
	var bloc := _panneau(carte, zone, Charte.PANNEAU)
	bloc.name = "CarteJoueurPolyvalence"
	var w := zone.size.x
	var terrain_l := 138.0
	_titre(bloc, 20, 38, "Postes", w - terrain_l - 60)
	var postes := postes_tries(player)
	if postes.is_empty():
		D.text(bloc, 20, 92, str(player.get("pos", "—")), 22, Charte.IVOIRE, 600, w - terrain_l - 60)
		D.text(bloc, 20, 130, "Étoiles à observer", 19, Charte.IVOIRE_3, 600, w - terrain_l - 60)
		return
	var liste_l := w - terrain_l - 56.0
	for i in mini(combien, postes.size()):
		var p: Dictionary = postes[i]
		var by := 84.0 + i * 52.0
		var numeros: Array[String] = []
		for n: int in p.numeros: numeros.append(str(n))
		D.text(bloc, 20, by + 8, " · ".join(numeros), 24, Charte.CREME, 800, 70).add_theme_font_override("font", Charte.TITRE_EXTRA)
		D.text(bloc, 96, by + 8, str(p.poste), 20, Charte.IVOIRE, 600, liste_l - 96 - 160)
		_etoiles(bloc, Rect2(20 + liste_l - 150, by - 14, 150, 28), float(p.etoiles), "CarteJoueurEtoilesPoste_%d" % int(p.numeros[0]))
	var terrain := MiniTerrain.new()
	terrain.name = "CarteJoueurMiniTerrain"
	var etoiles: Array = []
	for n in range(1, 16): etoiles.append(etoiles_poste(player, n))
	terrain.etoiles = etoiles
	terrain.principaux = player.get("primaryPositions", []) if player.get("primaryPositions") is Array else []
	bloc.add_child(terrain)
	D.place(terrain, Rect2(w - terrain_l - 18, 16, terrain_l, zone.size.y - 32))

## La carte ne capte jamais la souris : le survol reste au nom ou à la tuile, qui la referme en sortant.
static func _ignorer_souris(noeud: Node) -> void:
	if noeud is Control:
		noeud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		noeud.tooltip_text = ""
	for enfant in noeud.get_children(): _ignorer_souris(enfant)
