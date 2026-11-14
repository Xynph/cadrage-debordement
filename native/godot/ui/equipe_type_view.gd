extends Control
## XV type : « XV de la journée » (note du match) et « XV de la saison » (moyenne de la saison
## régulière) d'un championnat, en carte à partager façon visuel hebdomadaire du Top 14 : un terrain
## vu de dessus, quinze joueurs en formation de rugby, chacun sur sa carte aux couleurs de son club
## (portrait, numéro, nom, écusson, note). Données du moteur (clubLife.matchNotes.equipeType, notes de
## match déterministes) ; rien n'est tiré ici. Écussons et portraits passent par G.crest / G.portrait :
## logo et photo du pack d'identité s'il est installé (logoPath, portraitPath), sinon ceux du jeu.
## Ouverture : equipe_type_view.ouvrir(app, championnat, mode) depuis l'actualité et Compétitions.

const Tableau = preload("res://ui/contextual/match_tableau_widgets.gd")
const G = preload("res://ui/game_skin.gd")
const Notes = preload("res://ui/notes_match.gd")

const SCENE := Vector2(1920, 1080)
const TERRAIN := Rect2(456, 124, 1008, 936)
const CARTE := Vector2(156, 132)
## Hauteur de la fenêtre du portrait (couleurs du club), puis bande du nom et ligne de légende.
const HAUT_PORTRAIT := 88.0
const ECHELLE_VEDETTE := 1.15
## Centre de chaque carte (fractions du terrain), maillots 1 à 15 : avants devant (en haut),
## charnière puis trois-quarts, ailiers sur les côtés, l'arrière au fond (en bas).
const PLACES := {
	1: Vector2(0.22, 0.09), 2: Vector2(0.50, 0.09), 3: Vector2(0.78, 0.09),
	4: Vector2(0.36, 0.25), 5: Vector2(0.64, 0.25),
	6: Vector2(0.19, 0.41), 8: Vector2(0.50, 0.41), 7: Vector2(0.81, 0.41),
	9: Vector2(0.36, 0.57), 10: Vector2(0.64, 0.57),
	11: Vector2(0.085, 0.737), 12: Vector2(0.365, 0.737), 13: Vector2(0.635, 0.737), 14: Vector2(0.915, 0.737),
	15: Vector2(0.50, 0.91),
}
const FOND := Color("07100c")
const PANNEAU := Color("0e1a15")
const TRAIT := Color("2c3d36")
const ROUGE := Color("c8463c")

var app: Control
var donnees: Dictionary = {}
var ligue: Dictionary = {}
var mode := "journee"
var scene: Control

## Ouvre la vue (une seule à la fois) ; mode « journee » ou « saison ».
static func ouvrir(owner_app: Control, championnat := "", mode_voulu := "journee") -> Control:
	var ancienne := owner_app.get_node_or_null("EquipeTypeVue")
	if ancienne: ancienne.free()
	var vue: Control = load("res://ui/equipe_type_view.gd").new()
	vue.app = owner_app
	vue.name = "EquipeTypeVue"
	vue.donnees = Notes.bilan(owner_app.model).get("equipeType", {})
	vue.mode = mode_voulu
	vue.choisir(championnat)
	owner_app.add_child(vue)
	vue.construire()
	return vue

static func disponible(model: Dictionary) -> bool:
	var ligues: Variant = Notes.bilan(model).get("equipeType", {}).get("ligues", [])
	return ligues is Array and not ligues.is_empty()

func choisir(championnat: String) -> void:
	var ligues: Array = donnees.get("ligues", [])
	ligue = {}
	for l: Dictionary in ligues:
		if str(l.get("id", "")) == championnat: ligue = l
	if ligue.is_empty() and not ligues.is_empty(): ligue = ligues[0]
	# Le mode demandé doit exister pour ce championnat.
	if mode == "journee" and ligue.get("journee") == null and ligue.get("saison") != null: mode = "saison"
	if mode == "saison" and ligue.get("saison") == null and ligue.get("journee") != null: mode = "journee"

func _ready() -> void:
	# Plein écran au-dessus du jeu : l'écran derrière ne doit pas transparaître (carte opaque).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FOND)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()

func construire() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for enfant in get_children():
		enfant.queue_free()
	queue_redraw()
	scene = Control.new()
	scene.name = "EquipeTypeScene"
	scene.size = SCENE
	scene.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scene)
	var fond := FondCarte.new()
	fond.name = "EquipeTypeFond"
	fond.size = SCENE
	scene.add_child(fond)
	_ajuster()
	if not resized.is_connected(_ajuster): resized.connect(_ajuster)
	var equipe: Variant = ligue.get(mode)
	if not equipe is Dictionary:
		_texte(scene, Rect2(460, 480, 1000, 80), "Pas encore d'équipe-type : elle est publiée après chaque journée de championnat.", 30, Tableau.IVOIRE, HORIZONTAL_ALIGNMENT_CENTER)
		_commandes({})
		return
	_entete(equipe)
	_terrain()
	_joueurs(equipe)
	_gauche(equipe)
	_commandes(equipe)

func _ajuster() -> void:
	if scene == null or size.x <= 0.0: return
	var k := minf(size.x / SCENE.x, size.y / SCENE.y)
	scene.scale = Vector2(k, k)
	scene.position = (size - SCENE * k) * 0.5

## Fond de la carte : vert très sombre, halo doux au centre, filet or en haut.
class FondCarte extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("07100c"))
		for i in 8:
			var r := 980.0 - i * 110.0
			draw_circle(Vector2(size.x * 0.5, size.y * 0.55), r, Color(0.10, 0.22, 0.15, 0.035))
		# Fines rayures obliques, comme un visuel imprimé.
		for x in range(-1100, int(size.x), 22):
			draw_line(Vector2(x, size.y), Vector2(x + 1100, 0), Color(1, 1, 1, 0.012), 1.0)

# ---- Éléments de base -----------------------------------------------------------------------

func _texte(parent: Control, zone: Rect2, texte: String, corps: int, couleur: Color, alignement := HORIZONTAL_ALIGNMENT_LEFT, police: Font = null, nom := "") -> Label:
	var l := Label.new()
	l.text = texte
	l.position = zone.position
	l.size = zone.size
	l.horizontal_alignment = alignement
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", corps)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_constant_override("line_spacing", -2)
	if police: l.add_theme_font_override("font", police)
	if not nom.is_empty(): l.name = nom
	parent.add_child(l)
	# Taille posée en dernier : les réglages de police ne doivent pas élargir le libellé.
	l.size = zone.size
	l.set_meta("largeur", zone.size.x)
	return l

## Réduit le corps d'un libellé d'une ligne jusqu'à ce qu'il tienne (nom long), sans descendre sous « minimum ».
func _ajuste(l: Label, minimum: int) -> Label:
	var police: Font = Tableau.CHIFFRES
	var corps := l.get_theme_font_size("font_size")
	var largeur: float = l.get_meta("largeur", l.size.x)
	while corps > minimum and police.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x > largeur:
		corps -= 1
	# Nom composé très long : l'initiale du prénom saute avant toute coupe.
	if police.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x > largeur and l.text.find(". ") == 1:
		l.text = l.text.substr(3)
	l.add_theme_font_size_override("font_size", corps)
	l.size = Vector2(largeur, l.size.y)
	return l

func _paragraphe(parent: Control, zone: Rect2, texte: String, corps: int, couleur: Color, alignement := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := _texte(parent, zone, texte, corps, couleur, alignement)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	# Largeur imposée après le passage en lignes multiples (sinon la ligne unique élargit le libellé).
	l.custom_minimum_size = Vector2(zone.size.x, 0)
	l.size = zone.size
	return l

func _boite(parent: Control, zone: Rect2, couleur: Color, rayon := 8, bord := Color.TRANSPARENT, epaisseur := 0) -> Panel:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = couleur
	s.set_corner_radius_all(rayon)
	if epaisseur > 0:
		s.border_color = bord
		s.set_border_width_all(epaisseur)
	p.add_theme_stylebox_override("panel", s)
	p.position = zone.position
	p.size = zone.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

## Halo autour d'une carte (joueur de la journée, joueur du club du manager).
func _halo(parent: Control, zone: Rect2, couleur: Color, rayon: int, largeur: int) -> Panel:
	var p := _boite(parent, zone, Color.TRANSPARENT, rayon)
	var s: StyleBoxFlat = p.get_theme_stylebox("panel")
	s.shadow_color = couleur
	s.shadow_size = largeur
	return p

static func _couleur_club(club: Dictionary) -> Color:
	var source: Dictionary = club.get("presentation", club) if club.get("presentation") is Dictionary else club
	var c := str(source.get("color", club.get("color", "")))
	return Color(c) if c.begins_with("#") and (c.length() == 7 or c.length() == 9) else Tableau.VERT

## Teinte lisible sur fond sombre (une couleur de club trop sombre est éclaircie).
static func _lisible(c: Color) -> Color:
	return c.lightened(0.45) if c.get_luminance() < 0.32 else c

static func _ordinal(n: int) -> String:
	return "1re" if n <= 1 else str(n) + "e"

static func _court(nom: String) -> String:
	var morceaux := nom.strip_edges().split(" ", false)
	if morceaux.size() < 2: return nom.to_upper()
	return (morceaux[0].substr(0, 1) + ". " + " ".join(morceaux.slice(1))).to_upper()

func _nombre_clubs(joueurs: Array) -> int:
	var vus := {}
	for j: Dictionary in joueurs: vus[str(j.get("club", {}).get("id", ""))] = true
	return vus.size()

# ---- En-tête, terrain ------------------------------------------------------------------------

func _entete(equipe: Dictionary) -> void:
	_boite(scene, Rect2(0, 0, SCENE.x, 108), Color("0b1a13"))
	_boite(scene, Rect2(0, 104, SCENE.x, 4), Tableau.OR)
	_boite(scene, Rect2(28, 22, 10, 64), ROUGE, 2)
	var nom_ligue := str(ligue.get("nom", ""))
	var joueurs: Array = equipe.get("joueurs", [])
	var titre := ""
	var sous := ""
	if mode == "journee":
		titre = "XV DE LA %s JOURNÉE" % _ordinal(int(equipe.get("numero", 1))).to_upper()
		var libelle := str(equipe.get("libelleSaison", ""))
		sous = "%s · note du match · %d clubs représentés" % [libelle if libelle.begins_with("Saison") else "Saison " + libelle, _nombre_clubs(joueurs)]
	else:
		titre = "XV DE LA SAISON %s" % str(equipe.get("libelleSaison", ""))
		sous = "Moyenne de la saison régulière · %d journées · %d clubs représentés" % [int(equipe.get("journees", 0)), _nombre_clubs(joueurs)]
	_ajuste(_texte(scene, Rect2(54, 2, 1400, 76), titre + " · " + nom_ligue.to_upper(), 68, Tableau.OR, HORIZONTAL_ALIGNMENT_LEFT, Tableau.CHIFFRES, "EquipeTypeTitre"), 44)
	_texte(scene, Rect2(56, 70, 1340, 32), sous, 23, Tableau.IVOIRE, HORIZONTAL_ALIGNMENT_LEFT, null, "EquipeTypeSousTitre")
	_texte(scene, Rect2(1480, 12, 412, 44), "RUGBY LEGACY 27", 30, Tableau.FAIBLE, HORIZONTAL_ALIGNMENT_RIGHT, Tableau.CHIFFRES)
	var badge := _boite(scene, Rect2(1712, 58, 180, 36), ROUGE, 6)
	_texte(badge, Rect2(0, 0, 180, 36), "XV TYPE", 26, Tableau.IVOIRE, HORIZONTAL_ALIGNMENT_CENTER, Tableau.CHIFFRES)

func _terrain() -> void:
	var t := TerrainDessin.new()
	t.name = "EquipeTypeTerrain"
	t.position = TERRAIN.position
	t.size = TERRAIN.size
	scene.add_child(t)

## Terrain vu de dessus, vertical : en-buts, bandes d'herbe, lignes d'essai, des 22 mètres, des
## 10 mètres (tirets) et médiane, tirets des 5 et 15 mètres, poteaux en H.
class TerrainDessin extends Control:
	const HERBE_A := Color("123b26")
	const HERBE_B := Color("17432c")
	const EN_BUT := Color("0f2f1f")
	const TRAIT_TERRAIN := Color(0.95, 0.93, 0.86, 0.42)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ligne(y: float, epaisseur := 3.0, couleur := TRAIT_TERRAIN) -> void:
		draw_line(Vector2(0, size.y * y), Vector2(size.x, size.y * y), couleur, epaisseur)

	func _tirets(y: float) -> void:
		draw_dashed_line(Vector2(0, size.y * y), Vector2(size.x, size.y * y), Color(TRAIT_TERRAIN, 0.30), 2.0, 16.0)

	func _poteaux(y: float, sens: float) -> void:
		var c := Vector2(size.x * 0.5, size.y * y)
		draw_line(c - Vector2(28, 0), c + Vector2(28, 0), Color(1, 1, 1, 0.55), 4.0)
		draw_circle(c - Vector2(28, 0), 5.0, Color(1, 1, 1, 0.7))
		draw_circle(c + Vector2(28, 0), 5.0, Color(1, 1, 1, 0.7))
		draw_line(c - Vector2(28, 0), c - Vector2(28, 10 * sens), Color(1, 1, 1, 0.3), 2.0)
		draw_line(c + Vector2(28, 0), c + Vector2(28, 10 * sens), Color(1, 1, 1, 0.3), 2.0)

	func _draw() -> void:
		var bandes := 14
		var h := size.y / bandes
		for i in bandes:
			draw_rect(Rect2(0, i * h, size.x, h + 1), HERBE_A if i % 2 == 0 else HERBE_B)
		# En-buts.
		draw_rect(Rect2(0, 0, size.x, size.y * 0.045), EN_BUT)
		draw_rect(Rect2(0, size.y * 0.955, size.x, size.y * 0.045), EN_BUT)
		# Vignettage sur les bords.
		for i in 10:
			var a := 0.035 * (10 - i) / 10.0
			draw_rect(Rect2(i * 6, 0, 6, size.y), Color(0, 0, 0, a))
			draw_rect(Rect2(size.x - (i + 1) * 6, 0, 6, size.y), Color(0, 0, 0, a))
		_ligne(0.045, 4.0)
		_ligne(0.955, 4.0)
		_ligne(0.235)
		_ligne(0.765)
		_ligne(0.5, 3.5)
		_tirets(0.385)
		_tirets(0.615)
		for x in [0.05, 0.15, 0.85, 0.95]:
			draw_dashed_line(Vector2(size.x * x, size.y * 0.06), Vector2(size.x * x, size.y * 0.94), Color(TRAIT_TERRAIN, 0.16), 2.0, 22.0)
		draw_arc(Vector2(size.x * 0.5, size.y * 0.5), 64.0, 0.0, TAU, 48, Color(TRAIT_TERRAIN, 0.5), 2.5)
		_poteaux(0.045, -1.0)
		_poteaux(0.955, 1.0)
		draw_rect(Rect2(2, 2, size.x - 4, size.y - 4), Color("e0b35a"), false, 3.0)

## Fond d'une carte de joueur : couleurs du club en diagonale derrière le portrait.
class FondJoueur extends Control:
	var teinte := Color.WHITE
	var haut := 88.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var base := teinte.darkened(0.55)
		draw_rect(Rect2(0, 0, size.x, haut), base)
		var bande := PackedVector2Array([Vector2(size.x * 0.52, 0), Vector2(size.x * 0.78, 0), Vector2(size.x * 0.42, haut), Vector2(size.x * 0.16, haut)])
		draw_colored_polygon(bande, Color(teinte, 0.55))
		var fine := PackedVector2Array([Vector2(size.x * 0.84, 0), Vector2(size.x * 0.92, 0), Vector2(size.x * 0.56, haut), Vector2(size.x * 0.48, haut)])
		draw_colored_polygon(fine, Color(teinte.lightened(0.2), 0.35))
		for i in 6:
			draw_rect(Rect2(0, haut - (i + 1) * 6, size.x, 6), Color(0, 0, 0, 0.05 * (6 - i)))
		draw_rect(Rect2(0, haut - 3, size.x, 3), teinte)

# ---- Cartes des joueurs ------------------------------------------------------------------------

func _joueurs(equipe: Dictionary) -> void:
	# La vedette en dernier, au-dessus de ses voisines.
	var liste: Array = equipe.get("joueurs", []).duplicate()
	liste.sort_custom(func(a: Dictionary, b: Dictionary): return not bool(a.get("etoile", false)) and bool(b.get("etoile", false)))
	for j: Dictionary in liste:
		var numero := int(j.get("numero", 0))
		if not PLACES.has(numero): continue
		var centre: Vector2 = TERRAIN.position + Vector2(PLACES[numero].x * TERRAIN.size.x, PLACES[numero].y * TERRAIN.size.y)
		var carte := _carte(j, CARTE)
		carte.position = centre - CARTE * 0.5
		scene.add_child(carte)

func _carte(j: Dictionary, taille: Vector2) -> Control:
	var club: Dictionary = j.get("club", {})
	var teinte := _couleur_club(club)
	var etoile := bool(j.get("etoile", false))
	var notre := bool(j.get("manager", false))
	var racine := Control.new()
	racine.name = "EquipeTypeCarte%d" % int(j.get("numero", 0))
	racine.size = taille
	var legende_info := "%s sélection en XV de la journée" % _ordinal(int(j.get("selections", 0))) if mode == "journee" else "%d matchs · moyenne %s" % [int(j.get("matchs", 0)), Notes.texte_note(j.get("noteMatch"))]
	racine.tooltip_text = "%s · %s · n° %d\n%s\n%s" % [str(j.get("name", "")), str(j.get("poste", "")), int(j.get("numero", 0)), G.club_name(club), legende_info]
	racine.mouse_filter = Control.MOUSE_FILTER_PASS
	if etoile: _halo(racine, Rect2(Vector2.ZERO, taille), Color(Tableau.OR, 0.55), 12, 16)
	elif notre: _halo(racine, Rect2(Vector2.ZERO, taille), Color(Tableau.VERT, 0.55), 12, 10)
	var bord := Tableau.OR if etoile else (Tableau.VERT if notre else TRAIT)
	var epaisseur := 4 if etoile else (3 if notre else 2)
	var corps := _boite(racine, Rect2(Vector2.ZERO, taille), Color("0c1512"), 10)
	corps.name = "Corps"
	corps.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var fond := FondJoueur.new()
	fond.teinte = teinte
	fond.haut = HAUT_PORTRAIT
	fond.size = taille
	corps.add_child(fond)
	var portrait := G.portrait(int(j.get("portraitIndex", 0)), 84, j)
	portrait.name = "Portrait"
	portrait.position = Vector2((taille.x - 84) * 0.5, HAUT_PORTRAIT - 84 - 3)
	portrait.size = Vector2(84, 84)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corps.add_child(portrait)
	# Bande du nom, puis légende : sélections (journée) ou matchs (saison), sigle du club.
	_ajuste(_texte(corps, Rect2(8, HAUT_PORTRAIT + 1, taille.x - 14, 25), _court(str(j.get("name", ""))), 21, Tableau.IVOIRE, HORIZONTAL_ALIGNMENT_LEFT, Tableau.CHIFFRES, "Nom"), 15)
	if etoile:
		_boite(corps, Rect2(0, taille.y - 20, taille.x, 20), Tableau.OR, 0)
		_ajuste(_texte(corps, Rect2(4, taille.y - 20, taille.x - 8, 20), "★ JOUEUR DU JOUR" if mode == "journee" else "★ MEILLEURE MOYENNE", 12, Tableau.FOND, HORIZONTAL_ALIGNMENT_CENTER, Tableau.CHIFFRES, "Legende"), 11)
	else:
		var selections := int(j.get("selections", 0))
		var legende := ("%s sélection" % _ordinal(selections)) if mode == "journee" else "%d matchs" % int(j.get("matchs", 0))
		# Fiche d'un club : légende fournie (titularisations), voir club_sheet_canvas.gd.
		if j.get("legende") is String: legende = j.legende
		var couleur := Tableau.OR if (mode == "journee" and selections >= 3) else Color("a9b5ae")
		_texte(corps, Rect2(8, taille.y - 22, taille.x - 50, 20), legende, 15, couleur, HORIZONTAL_ALIGNMENT_LEFT, null, "Legende")
		_texte(corps, Rect2(taille.x - 50, taille.y - 22, 42, 20), G.club_abbr(club), 15, Tableau.VERT if notre else _lisible(teinte), HORIZONTAL_ALIGNMENT_RIGHT, Tableau.CHIFFRES, "Sigle")
	# Cadre par-dessus le contenu découpé (or : vedette ; vert : club du manager).
	_boite(racine, Rect2(Vector2.ZERO, taille), Color.TRANSPARENT, 10, bord, epaisseur).name = "Cadre"
	# Pastilles au-dessus du portrait : numéro (couleurs du club), note, écusson.
	var disque := Tableau.Numero.new()
	disque.numero = str(int(j.get("numero", 0)))
	disque.teinte = teinte.darkened(0.1) if teinte.get_luminance() < 0.75 else teinte.darkened(0.45)
	disque.densite = 0.9
	disque.position = Vector2(3, 3)
	disque.size = Vector2(38, 38)
	racine.add_child(disque)
	# Sans note connue (fiche d'un club avant toute note), pas de pastille trompeuse à 6,5.
	if j.has("noteMatch") and j.noteMatch == null:
		var ecusson_seul := G.crest(club, 36)
		ecusson_seul.name = "Ecusson"
		ecusson_seul.position = Vector2(taille.x - 42, HAUT_PORTRAIT - 42)
		ecusson_seul.size = Vector2(36, 36)
		racine.add_child(ecusson_seul)
		return racine
	var fond_note := _boite(racine, Rect2(taille.x - 62, 5, 57, 32), Color(0.03, 0.06, 0.05, 0.86), 7)
	fond_note.name = "FondNote"
	var note := Tableau.Note.new()
	note.valeur = float(j.get("noteMatch", 6.5))
	note.densite = 1.0
	note.position = Vector2(taille.x - 62, 5)
	note.size = Vector2(57, 32)
	note.name = "Note"
	racine.add_child(note)
	var ecusson := G.crest(club, 36)
	ecusson.name = "Ecusson"
	ecusson.position = Vector2(taille.x - 42, HAUT_PORTRAIT - 42)
	ecusson.size = Vector2(36, 36)
	racine.add_child(ecusson)
	_lien_club(racine, club, Rect2(taille.x - 50, HAUT_PORTRAIT - 4, 50, taille.y - HAUT_PORTRAIT + 4))
	# Le joueur de la journée est plus grand que les autres (même centre).
	if etoile:
		racine.pivot_offset = taille * 0.5
		racine.scale = Vector2(ECHELLE_VEDETTE, ECHELLE_VEDETTE)
		racine.z_index = 2
	return racine

## Sigle du club cliquable : ferme la carte et ouvre la fiche du club (ou l'écran Club pour le vôtre).
func _lien_club(racine: Control, club: Dictionary, zone: Rect2) -> void:
	if app == null or not is_instance_valid(app.navigation_controller) or club.get("id") == null: return
	var cible := {"kind":"club", "id":str(int(club.id))}
	if not app.navigation_controller.entity_available(cible): return
	var b := Button.new()
	b.name = "EquipeTypeClub"
	b.flat = true
	b.position = zone.position
	b.size = zone.size
	b.tooltip_text = "Ouvrir la fiche · " + G.club_name(club)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.pressed.connect(func():
		var proprietaire := app
		queue_free()
		proprietaire.navigation_controller.open_entity(cible))
	racine.add_child(b)

# ---- Colonne gauche : joueur mis en avant, entraîneur, club du manager ------------------------------

func _gauche(equipe: Dictionary) -> void:
	var liste: Array = equipe.get("joueurs", [])
	var vedette: Dictionary = {}
	var nous := PackedStringArray()
	var club_manager := ""
	for j: Dictionary in liste:
		if bool(j.get("etoile", false)): vedette = j
		if bool(j.get("manager", false)):
			nous.append(_court(str(j.get("name", ""))).replace(". ", ".\u00a0"))
			club_manager = G.club_name(j.get("club", {}))
	if not vedette.is_empty(): _vedette(vedette)
	_entraineur(equipe)
	var mien := _boite(scene, Rect2(28, 880, 408, 84), Color("0f1d17"), 12, Tableau.VERT if not nous.is_empty() else TRAIT, 3 if not nous.is_empty() else 2)
	mien.name = "EquipeTypeManager"
	var phrase := "Aucun joueur de votre club cette fois." if nous.is_empty() else "%d joueur%s de %s : %s" % [nous.size(), "s" if nous.size() > 1 else "", club_manager, (", ".join(nous.slice(0, 2)) + " et " + nous[2]) if nous.size() == 3 else (", ".join(nous.slice(0, 3)) + " et %d autre%s" % [nous.size() - 3, "s" if nous.size() > 4 else ""] if nous.size() > 3 else " et ".join(nous))]
	if mode == "saison" and nous.is_empty(): phrase = "Aucun joueur de votre club dans le XV de la saison."
	_paragraphe(mien, Rect2(16, 6, 376, 72), phrase, 17, Tableau.VERT if not nous.is_empty() else Tableau.FAIBLE).name = "ManagerTexte"
	var regle := "Un joueur par poste, sur la note du match (40 minutes jouées au moins) ; à égalité : minutes, essais." if mode == "journee" else "Moyenne de la saison régulière, la moitié des journées au moins ; à égalité : sélections en XV de la journée, puis matchs."
	_paragraphe(scene, Rect2(28, 972, 408, 84), regle, 17, Tableau.FAIBLE, HORIZONTAL_ALIGNMENT_LEFT)

func _vedette(vedette: Dictionary) -> void:
	var club: Dictionary = vedette.get("club", {})
	var teinte := _couleur_club(club)
	var zone := Rect2(28, 124, 408, 584)
	_halo(scene, zone, Color(Tableau.OR, 0.35), 16, 14)
	var cadre := _boite(scene, zone, PANNEAU, 16)
	cadre.name = "EquipeTypeVedette"
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var fond := FondJoueur.new()
	fond.teinte = teinte
	fond.haut = 300.0
	fond.size = zone.size
	cadre.add_child(fond)
	var bandeau := _boite(cadre, Rect2(0, 0, zone.size.x, 44), Tableau.OR, 0)
	_texte(bandeau, Rect2(0, 0, zone.size.x, 44), "★  JOUEUR DE LA JOURNÉE  ★" if mode == "journee" else "★  MEILLEURE MOYENNE  ★", 30, Tableau.FOND, HORIZONTAL_ALIGNMENT_CENTER, Tableau.CHIFFRES)
	var p := G.portrait(int(vedette.get("portraitIndex", 0)), 250, vedette)
	p.position = Vector2((zone.size.x - 250) * 0.5, 297 - 250)
	p.size = Vector2(250, 250)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(p)
	var disque := Tableau.Numero.new()
	disque.numero = str(int(vedette.get("numero", 0)))
	disque.teinte = teinte.darkened(0.1) if teinte.get_luminance() < 0.75 else teinte.darkened(0.45)
	disque.densite = 2.0
	disque.position = Vector2(14, 56)
	disque.size = Vector2(70, 70)
	cadre.add_child(disque)
	var ec := G.crest(club, 72)
	ec.position = Vector2(zone.size.x - 88, 214)
	ec.size = Vector2(72, 72)
	cadre.add_child(ec)
	_ajuste(_texte(cadre, Rect2(16, 306, zone.size.x - 32, 52), str(vedette.get("name", "")).to_upper(), 44, Tableau.IVOIRE, HORIZONTAL_ALIGNMENT_CENTER, Tableau.CHIFFRES, "VedetteNom"), 28)
	_texte(cadre, Rect2(16, 356, zone.size.x - 32, 30), "%s · %s" % [str(vedette.get("poste", "")), G.club_name(club)], 21, Color("a9b5ae"), HORIZONTAL_ALIGNMENT_CENTER)
	var note := Tableau.Note.new()
	note.valeur = float(vedette.get("noteMatch", 6.5))
	note.densite = 2.4
	note.position = Vector2(24, 402)
	note.size = Vector2(150, 74)
	note.name = "VedetteNote"
	cadre.add_child(note)
	_texte(cadre, Rect2(24, 476, 150, 24), "NOTE DU MATCH" if mode == "journee" else "MOYENNE", 17, Tableau.FAIBLE, HORIZONTAL_ALIGNMENT_CENTER, Tableau.CHIFFRES)
	var selections := int(vedette.get("selections", 0))
	var grand := _ordinal(selections) if mode == "journee" else str(int(vedette.get("matchs", 0)))
	_texte(cadre, Rect2(196, 398, 188, 78), grand, 66, Tableau.OR, HORIZONTAL_ALIGNMENT_CENTER, Tableau.CHIFFRES, "VedetteCompteur")
	_texte(cadre, Rect2(196, 476, 188, 24), "SÉLECTION EN XV" if mode == "journee" else "MATCHS JOUÉS", 17, Tableau.FAIBLE, HORIZONTAL_ALIGNMENT_CENTER, Tableau.CHIFFRES)
	_boite(scene, zone, Color.TRANSPARENT, 16, Tableau.OR, 4).name = "EquipeTypeVedetteCadre"
	var detail := "%s fois dans le XV de la journée cette saison." % selections if mode == "journee" else "%d sélection%s en XV de la journée cette saison." % [selections, "s" if selections > 1 else ""]
	if mode == "journee" and selections <= 1: detail = "Première sélection dans le XV de la journée cette saison."
	_paragraphe(cadre, Rect2(20, 512, zone.size.x - 40, 60), detail, 20, Tableau.IVOIRE)

func _entraineur(equipe: Dictionary) -> void:
	var zone := Rect2(28, 724, 408, 140)
	if mode != "journee":
		var info := _boite(scene, zone, PANNEAU, 14, TRAIT, 2)
		info.name = "EquipeTypeBas"
		_texte(info, Rect2(20, 14, 368, 34), "SAISON RÉGULIÈRE", 26, Tableau.OR, HORIZONTAL_ALIGNMENT_LEFT, Tableau.CHIFFRES)
		_paragraphe(info, Rect2(20, 50, 368, 80), "%d journées prises en compte ; les phases finales ne comptent pas." % int(equipe.get("journees", 0)), 21, Tableau.IVOIRE, HORIZONTAL_ALIGNMENT_LEFT)
		return
	var cadre := _boite(scene, zone, PANNEAU, 14, Tableau.OR, 2)
	cadre.name = "EquipeTypeBas"
	_texte(cadre, Rect2(18, 10, 372, 30), "ENTRAÎNEUR DE LA JOURNÉE", 24, Tableau.OR, HORIZONTAL_ALIGNMENT_LEFT, Tableau.CHIFFRES)
	var coach: Variant = equipe.get("entraineur")
	if not coach is Dictionary:
		_paragraphe(cadre, Rect2(18, 46, 372, 80), "Pas d'entraîneur de la journée (aucune victoire).", 21, Tableau.FAIBLE, HORIZONTAL_ALIGNMENT_LEFT)
		return
	var club: Dictionary = coach.get("club", {})
	var ec := G.crest(club, 76)
	ec.position = Vector2(18, 48)
	ec.size = Vector2(76, 76)
	cadre.add_child(ec)
	var nom := str(coach.get("nom", ""))
	if nom.is_empty(): nom = "Staff de " + G.club_name(club)
	_texte(cadre, Rect2(108, 44, 284, 44), nom, 34, Tableau.IVOIRE, HORIZONTAL_ALIGNMENT_LEFT, Tableau.CHIFFRES, "EntraineurNom")
	_texte(cadre, Rect2(108, 84, 284, 56), "%s\nvictoire +%d" % [G.club_name(club), int(coach.get("marge", 0))], 20, Tableau.VERT if bool(coach.get("manager", false)) else Color("a9b5ae"), HORIZONTAL_ALIGNMENT_LEFT, null, "EntraineurClub")

# ---- Colonne droite : championnat, équipe, légende ; fermer ------------------------------------------

func _commandes(equipe: Dictionary) -> void:
	var x := 1488.0
	var y := 124.0
	var ligues: Array = donnees.get("ligues", [])
	_texte(scene, Rect2(x, y, 404, 30), "CHAMPIONNAT", 22, Tableau.FAIBLE, HORIZONTAL_ALIGNMENT_LEFT, Tableau.CHIFFRES)
	y += 34
	for l: Dictionary in ligues:
		var identifiant := str(l.get("id", ""))
		_bouton("EquipeTypeLigue_" + identifiant, Rect2(x, y, 404, 50), str(l.get("nom", "")), identifiant == str(ligue.get("id", "")), func(): _changer(identifiant, mode))
		y += 58
		if y > 560: break
	y += 12
	_texte(scene, Rect2(x, y, 404, 30), "ÉQUIPE", 22, Tableau.FAIBLE, HORIZONTAL_ALIGNMENT_LEFT, Tableau.CHIFFRES)
	y += 34
	var courant := str(ligue.get("id", ""))
	if ligue.get("journee") != null:
		_bouton("EquipeTypeModeJournee", Rect2(x, y, 404, 50), "XV de la journée", mode == "journee", func(): _changer(courant, "journee"))
		y += 58
	if ligue.get("saison") != null:
		_bouton("EquipeTypeModeSaison", Rect2(x, y, 404, 50), "XV de la saison", mode == "saison", func(): _changer(courant, "saison"))
		y += 58
	if not equipe.is_empty(): _legende(Rect2(x, y + 18, 404, 196))
	_bouton("EquipeTypeFermer", Rect2(x, 990, 404, 64), "Fermer  (Échap)", false, queue_free)

## Légende de lecture : pastilles de note, cadre or, liseré vert.
func _legende(zone: Rect2) -> void:
	var cadre := _boite(scene, zone, PANNEAU, 12, TRAIT, 2)
	cadre.name = "EquipeTypeLegende"
	_texte(cadre, Rect2(16, 8, 372, 28), "LIRE LE XV", 21, Tableau.FAIBLE, HORIZONTAL_ALIGNMENT_LEFT, Tableau.CHIFFRES)
	var y := 44.0
	for exemple: Array in [[7.5, "7 et plus"], [6.5, "6 à 6,9"], [5.5, "sous 6"]]:
		var n := Tableau.Note.new()
		n.valeur = exemple[0]
		n.densite = 0.75
		n.position = Vector2(16 + [0, 124, 248][[7.5, 6.5, 5.5].find(exemple[0])], y)
		n.size = Vector2(44, 26)
		cadre.add_child(n)
		_texte(cadre, Rect2(n.position.x + 50, y, 76, 26), exemple[1], 16, Color("a9b5ae"))
	y += 40
	_boite(cadre, Rect2(16, y + 3, 40, 26), Color.TRANSPARENT, 6, Tableau.OR, 3)
	_texte(cadre, Rect2(68, y, 320, 32), "Joueur de la journée" if mode == "journee" else "Meilleure moyenne", 18, Tableau.IVOIRE)
	y += 40
	_boite(cadre, Rect2(16, y + 3, 40, 26), Color.TRANSPARENT, 6, Tableau.VERT, 3)
	_texte(cadre, Rect2(68, y, 320, 32), "Joueur de votre club", 18, Tableau.IVOIRE)
	y += 40
	_texte(cadre, Rect2(16, y, 372, 28), "Survol d'une carte : détail du joueur.", 15, Tableau.FAIBLE)

func _changer(championnat: String, nouveau: String) -> void:
	mode = nouveau
	choisir(championnat)
	construire()

func _bouton(nom: String, zone: Rect2, texte: String, actif: bool, rappel: Callable) -> Button:
	var b := Button.new()
	b.name = nom
	b.text = texte
	# Un nom de championnat long (« Japan Rugby League One · Division 1 ») ne doit pas élargir le bouton
	# au-delà de la colonne ni sortir de l'écran : texte tronqué (…), nom complet en infobulle.
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.tooltip_text = texte
	b.position = zone.position
	b.size = zone.size
	b.focus_mode = Control.FOCUS_NONE
	# Police réduite jusqu'à ce que le nom tienne en entier (deux divisions japonaises se distinguent par leur fin).
	var taille := 26
	var police: Font = b.get_theme_font("font")
	while taille > 17 and police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > zone.size.x - 28.0: taille -= 1
	b.add_theme_font_size_override("font_size", taille)
	b.add_theme_color_override("font_color", Tableau.FOND if actif else Tableau.IVOIRE)
	b.add_theme_color_override("font_hover_color", Tableau.FOND if actif else Tableau.OR)
	b.add_theme_color_override("font_pressed_color", Tableau.FOND)
	for etat in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Tableau.OR if actif else (Color("1b2a25") if etat != "normal" else Color("111d19"))
		s.set_corner_radius_all(8)
		s.set_border_width_all(2)
		s.border_color = Tableau.OR if actif else TRAIT
		b.add_theme_stylebox_override(etat, s)
	b.pressed.connect(rappel)
	scene.add_child(b)
	return b

## Vignette cliquable d'un XV (actualité) : le terrain en petit, quinze points aux couleurs des clubs.
class Vignette extends Button:
	var points: Array = []

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		tooltip_text = "Ouvrir le XV type"

	func _draw() -> void:
		for i in 6:
			draw_rect(Rect2(0, i * size.y / 6.0, size.x, size.y / 6.0 + 1), Color("123b26") if i % 2 == 0 else Color("17432c"))
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), Color("e0b35a"), false, 2.0)
		for p: Dictionary in points:
			var c: Vector2 = p.get("place", Vector2.ZERO)
			draw_circle(Vector2(c.x * size.x, c.y * size.y), maxf(2.0, size.x * 0.05), p.get("couleur", Color("f2ecdc")))

static func vignette(equipe: Dictionary, zone: Rect2, rappel: Callable) -> Button:
	var v := Vignette.new()
	v.name = "EquipeTypeVignette"
	v.position = zone.position
	v.size = zone.size
	for j: Dictionary in equipe.get("joueurs", []):
		var n := int(j.get("numero", 0))
		if not PLACES.has(n): continue
		var c := _couleur_club(j.get("club", {}))
		v.points.append({"place": PLACES[n], "couleur": Tableau.OR if bool(j.get("etoile", false)) else (Tableau.VERT if bool(j.get("manager", false)) else c)})
	v.pressed.connect(rappel)
	return v
