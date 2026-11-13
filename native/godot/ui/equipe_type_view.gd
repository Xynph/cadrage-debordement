extends Control
## XV type : « XV de la journée » (note du match) et « XV de la saison » (moyenne de la saison
## régulière) d'un championnat, en carte à partager : un terrain vu de dessus, quinze joueurs en
## formation de rugby, chacun sur sa carte (portrait, numéro, nom, club, note). Données du moteur
## (clubLife.matchNotes.equipeType, notes de match déterministes) ; rien n'est tiré ici.
## Ouverture : equipe_type_view.ouvrir(app, championnat, mode) depuis l'actualité et Compétitions.

const Tableau = preload("res://ui/contextual/match_tableau_widgets.gd")
const G = preload("res://ui/game_skin.gd")
const Notes = preload("res://ui/notes_match.gd")

const SCENE := Vector2(1920, 1080)
const TERRAIN := Rect2(460, 124, 1000, 828)
const CARTE := Vector2(176, 108)
## Centre de chaque carte (fractions du terrain), maillots 1 à 15 : avants devant (en haut),
## charnière puis trois-quarts, l'arrière au fond (en bas).
const PLACES := {
	1: Vector2(0.22, 0.095), 2: Vector2(0.50, 0.095), 3: Vector2(0.78, 0.095),
	4: Vector2(0.36, 0.245), 5: Vector2(0.64, 0.245),
	6: Vector2(0.20, 0.395), 8: Vector2(0.50, 0.395), 7: Vector2(0.80, 0.395),
	9: Vector2(0.37, 0.535), 10: Vector2(0.63, 0.535),
	12: Vector2(0.37, 0.69), 13: Vector2(0.63, 0.69), 11: Vector2(0.095, 0.69), 14: Vector2(0.905, 0.69),
	15: Vector2(0.50, 0.87),
}
const FOND_ECRAN := Color(0.03, 0.05, 0.05, 0.94)

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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200

## Fond plein écran : l'écran derrière reste à peine lisible, la carte se lit seule.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.035, 0.97))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()

func construire() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for enfant in get_children():
		enfant.queue_free()
	queue_redraw()
	scene = Control.new()
	scene.name = "EquipeTypeScene"
	scene.size = SCENE
	scene.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scene)
	_ajuster()
	if not resized.is_connected(_ajuster): resized.connect(_ajuster)
	var equipe: Variant = ligue.get(mode)
	if not equipe is Dictionary:
		_texte(scene, Rect2(460, 480, 1000, 80), "Pas encore d'équipe-type : elle est publiée après chaque journée de championnat.", 30, Tableau.IVOIRE, HORIZONTAL_ALIGNMENT_CENTER)
		_commandes()
		return
	_entete(equipe)
	_terrain()
	_joueurs(equipe)
	_gauche(equipe)
	_bas(equipe)
	_commandes()

func _ajuster() -> void:
	if scene == null or size.x <= 0.0: return
	var k := minf(size.x / SCENE.x, size.y / SCENE.y)
	scene.scale = Vector2(k, k)
	scene.position = (size - SCENE * k) * 0.5

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
	if police: l.add_theme_font_override("font", police)
	if not nom.is_empty(): l.name = nom
	parent.add_child(l)
	return l

func _paragraphe(parent: Control, zone: Rect2, texte: String, corps: int, couleur: Color) -> Label:
	var l := _texte(parent, zone, texte, corps, couleur, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.clip_text = true
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

func _couleur_club(club: Dictionary) -> Color:
	var c := str(club.get("color", ""))
	return Color(c) if c.begins_with("#") and (c.length() == 7 or c.length() == 9) else Tableau.VERT

static func _ordinal(n: int) -> String:
	return "1re" if n <= 1 else str(n) + "e"

static func _court(nom: String) -> String:
	var morceaux := nom.strip_edges().split(" ", false)
	if morceaux.size() < 2: return nom
	return morceaux[0].substr(0, 1) + ". " + " ".join(morceaux.slice(1))

# ---- En-tête, terrain ------------------------------------------------------------------------

func _entete(equipe: Dictionary) -> void:
	_boite(scene, Rect2(0, 0, SCENE.x, 112), Color("0d1d17"))
	_boite(scene, Rect2(0, 108, SCENE.x, 4), Tableau.OR)
	var titre := ""
	var sous := ""
	if mode == "journee":
		titre = "XV DE LA %s JOURNÉE" % _ordinal(int(equipe.get("numero", 1)))
		sous = "%s · saison %s · note du match" % [str(ligue.get("nom", "")), str(equipe.get("libelleSaison", ""))]
	else:
		titre = "XV DE LA SAISON %s" % str(equipe.get("libelleSaison", ""))
		sous = "%s · moyenne de la saison régulière (%d journées)" % [str(ligue.get("nom", "")), int(equipe.get("journees", 0))]
	_texte(scene, Rect2(40, 4, 1400, 72), titre + " · " + str(ligue.get("nom", "")).to_upper(), 64, Tableau.OR, HORIZONTAL_ALIGNMENT_LEFT, Tableau.CHIFFRES, "EquipeTypeTitre")
	_texte(scene, Rect2(42, 72, 1400, 34), sous, 24, Tableau.IVOIRE, HORIZONTAL_ALIGNMENT_LEFT, null, "EquipeTypeSousTitre")
	_texte(scene, Rect2(1500, 14, 380, 40), "RUGBY LEGACY 27", 28, Tableau.FAIBLE, HORIZONTAL_ALIGNMENT_RIGHT, Tableau.CHIFFRES)
	_texte(scene, Rect2(1500, 58, 380, 36), "XV TYPE", 26, Tableau.IVOIRE, HORIZONTAL_ALIGNMENT_RIGHT, Tableau.CHIFFRES)

func _terrain() -> void:
	var t := TerrainDessin.new()
	t.name = "EquipeTypeTerrain"
	t.position = TERRAIN.position
	t.size = TERRAIN.size
	scene.add_child(t)

## Terrain vu de dessus, vertical : bandes d'herbe, lignes de touche, des 22 mètres et de mi-terrain.
class TerrainDessin extends Control:
	const HERBE_A := Color("123422")
	const HERBE_B := Color("163a27")
	const TRAIT_TERRAIN := Color(0.95, 0.92, 0.86, 0.34)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var bandes := 12
		var h := size.y / bandes
		for i in bandes:
			draw_rect(Rect2(0, i * h, size.x, h + 1), HERBE_A if i % 2 == 0 else HERBE_B)
		draw_rect(Rect2(3, 3, size.x - 6, size.y - 6), Color("e0b35a"), false, 3.0)
		for y in [0.17, 0.5, 0.83]:
			draw_line(Vector2(3, size.y * y), Vector2(size.x - 3, size.y * y), TRAIT_TERRAIN, 3.0)
		for x in [0.12, 0.88]:
			draw_dashed_line(Vector2(size.x * x, 3), Vector2(size.x * x, size.y - 3), Color(TRAIT_TERRAIN, 0.22), 2.0, 14.0)
		draw_arc(Vector2(size.x * 0.5, size.y * 0.5), 74.0, 0.0, TAU, 48, TRAIT_TERRAIN, 3.0)

# ---- Cartes des joueurs ------------------------------------------------------------------------

func _joueurs(equipe: Dictionary) -> void:
	for j: Dictionary in equipe.get("joueurs", []):
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
	racine.tooltip_text = "%s · %s\n%s" % [str(j.get("name", "")), str(j.get("poste", "")), str(club.get("name", ""))]
	racine.mouse_filter = Control.MOUSE_FILTER_PASS
	var bord := Tableau.OR if etoile else (Tableau.VERT if notre else Color("34443f"))
	var epaisseur := 4 if (etoile or notre) else 2
	if notre: _boite(racine, Rect2(-6, -6, taille.x + 12, taille.y + 12), Color(Tableau.VERT, 0.30), 16)
	_boite(racine, Rect2(Vector2.ZERO, taille), Color("0f1718"), 10, bord, epaisseur)
	_boite(racine, Rect2(5, 5, taille.x - 10, 7), teinte, 3).name = "Bandeau"
	var portrait := G.portrait(int(j.get("portraitIndex", 0)), 58, j)
	portrait.position = Vector2(8, 16)
	portrait.size = Vector2(58, 58)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(portrait)
	var disque := Tableau.Numero.new()
	disque.numero = str(int(j.get("numero", 0)))
	disque.teinte = teinte.darkened(0.15)
	disque.densite = 0.7
	disque.position = Vector2(2, 52)
	disque.size = Vector2(30, 30)
	racine.add_child(disque)
	var note := Tableau.Note.new()
	note.valeur = float(j.get("noteMatch", 6.5))
	note.densite = 1.05
	note.position = Vector2(72, 16)
	note.size = Vector2(96, 34)
	note.name = "Note"
	racine.add_child(note)
	var ecusson := G.crest(club, 28)
	ecusson.position = Vector2(72, 54)
	ecusson.size = Vector2(28, 28)
	racine.add_child(ecusson)
	var legende := "%s sél." % _ordinal(int(j.get("selections", 0))) if mode == "journee" else "%d matchs" % int(j.get("matchs", 0))
	_texte(racine, Rect2(104, 54, 66, 28), legende, 15, Tableau.OR if etoile else Tableau.FAIBLE, HORIZONTAL_ALIGNMENT_LEFT, null, "Legende")
	_texte(racine, Rect2(8, 80, taille.x - 14, 24), _court(str(j.get("name", ""))), 20, Tableau.IVOIRE, HORIZONTAL_ALIGNMENT_LEFT, Tableau.CHIFFRES, "Nom")
	# Le joueur de la journée est plus grand que les autres (même centre).
	if etoile:
		racine.pivot_offset = taille * 0.5
		racine.scale = Vector2(1.16, 1.16)
		racine.z_index = 2
	return racine

# ---- Colonne gauche : joueur mis en avant ---------------------------------------------------------

func _gauche(equipe: Dictionary) -> void:
	var liste: Array = equipe.get("joueurs", [])
	var vedette: Dictionary = {}
	var nous := 0
	var club_manager := ""
	for j: Dictionary in liste:
		if bool(j.get("etoile", false)): vedette = j
		if bool(j.get("manager", false)):
			nous += 1
			club_manager = str(j.get("club", {}).get("name", ""))
	if vedette.is_empty(): return
	var club: Dictionary = vedette.get("club", {})
	var zone := Rect2(30, 138, 404, 560)
	_boite(scene, zone, Color("101a17"), 14, Tableau.OR, 4).name = "EquipeTypeVedette"
	_texte(scene, Rect2(zone.position.x + 20, zone.position.y + 12, zone.size.x - 40, 34), "JOUEUR DE LA JOURNÉE" if mode == "journee" else "MEILLEURE MOYENNE", 28, Tableau.OR, HORIZONTAL_ALIGNMENT_CENTER, Tableau.CHIFFRES)
	var p := G.portrait(int(vedette.get("portraitIndex", 0)), 210, vedette)
	p.position = Vector2(zone.position.x + (zone.size.x - 210) * 0.5, zone.position.y + 54)
	p.size = Vector2(210, 210)
	scene.add_child(p)
	_boite(scene, Rect2(p.position - Vector2(4, 4), Vector2(218, 218)), Color.TRANSPARENT, 10, Tableau.OR, 4).name = "EquipeTypeVedettePortrait"
	_texte(scene, Rect2(zone.position.x + 14, zone.position.y + 276, zone.size.x - 28, 48), str(vedette.get("name", "")), 40, Tableau.IVOIRE, HORIZONTAL_ALIGNMENT_CENTER, Tableau.CHIFFRES, "VedetteNom")
	_texte(scene, Rect2(zone.position.x + 14, zone.position.y + 322, zone.size.x - 28, 30), "%s · n° %d" % [str(vedette.get("poste", "")), int(vedette.get("numero", 0))], 22, Tableau.FAIBLE, HORIZONTAL_ALIGNMENT_CENTER)
	var ec := G.crest(club, 46)
	ec.position = Vector2(zone.position.x + 30, zone.position.y + 374)
	ec.size = Vector2(46, 46)
	scene.add_child(ec)
	_paragraphe(scene, Rect2(zone.position.x + 84, zone.position.y + 366, 176, 62), str(club.get("name", "")), 22, Tableau.IVOIRE).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var note := Tableau.Note.new()
	note.valeur = float(vedette.get("noteMatch", 6.5))
	note.densite = 2.2
	note.position = Vector2(zone.position.x + 270, zone.position.y + 368)
	note.size = Vector2(106, 58)
	note.name = "VedetteNote"
	scene.add_child(note)
	var selections := int(vedette.get("selections", 0))
	var detail := ""
	if mode == "journee":
		detail = "%s sélection en XV cette saison" % _ordinal(selections)
	else:
		detail = "%d matchs · %d sélection%s en XV de la journée" % [int(vedette.get("matchs", 0)), selections, "s" if selections > 1 else ""]
	_paragraphe(scene, Rect2(zone.position.x + 14, zone.position.y + 440, zone.size.x - 28, 68), detail, 22, Tableau.IVOIRE)
	var mien := _boite(scene, Rect2(30, 716, 404, 100), Color("0f1d17"), 12, Tableau.VERT if nous > 0 else Color("34443f"), 3)
	mien.name = "EquipeTypeManager"
	var phrase := "Liseré vert : joueur de votre club." if nous == 0 else "%d joueur%s de %s dans le XV." % [nous, "s" if nous > 1 else "", club_manager]
	_paragraphe(mien, Rect2(14, 8, 376, 84), phrase, 24, Tableau.VERT if nous > 0 else Tableau.FAIBLE)
	var regle := "Un joueur par poste, choisi sur la note du match (minutes, essais puis identifiant à égalité)." if mode == "journee" else "Moyenne de la saison régulière, au moins la moitié des journées jouées ; sélections en XV de la journée puis matchs à égalité."
	_paragraphe(scene, Rect2(30, 832, 404, 120), regle, 20, Tableau.FAIBLE)

# ---- Bas : entraîneur ; commandes -------------------------------------------------------------------

func _bas(equipe: Dictionary) -> void:
	var zone := Rect2(460, 966, 1000, 84)
	_boite(scene, zone, Color("101a17"), 14, Tableau.OR if mode == "journee" else Color("34443f"), 3).name = "EquipeTypeBas"
	if mode != "journee":
		_texte(scene, zone.grow(-20), "Sur la saison régulière · les phases finales ne comptent pas.", 26, Tableau.IVOIRE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var coach: Variant = equipe.get("entraineur")
	if not coach is Dictionary:
		_texte(scene, zone.grow(-20), "Pas d'entraîneur de la journée (aucune victoire).", 24, Tableau.FAIBLE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var club: Dictionary = coach.get("club", {})
	var ec := G.crest(club, 56)
	ec.position = zone.position + Vector2(18, 14)
	ec.size = Vector2(56, 56)
	scene.add_child(ec)
	_texte(scene, Rect2(zone.position.x + 90, zone.position.y + 6, 400, 30), "ENTRAÎNEUR DE LA JOURNÉE", 22, Tableau.OR, HORIZONTAL_ALIGNMENT_LEFT, Tableau.CHIFFRES)
	var nom := str(coach.get("nom", ""))
	if nom.is_empty(): nom = "Staff de " + str(club.get("name", ""))
	_texte(scene, Rect2(zone.position.x + 90, zone.position.y + 34, 540, 42), nom, 32, Tableau.IVOIRE, HORIZONTAL_ALIGNMENT_LEFT, Tableau.CHIFFRES, "EntraineurNom")
	_texte(scene, Rect2(zone.position.x + 600, zone.position.y + 12, 380, 60), "%s · victoire de %d points" % [str(club.get("abbr", "")), int(coach.get("marge", 0))], 24, Tableau.VERT if bool(coach.get("manager", false)) else Tableau.IVOIRE, HORIZONTAL_ALIGNMENT_RIGHT)

func _commandes() -> void:
	var x := 1486.0
	var y := 138.0
	var ligues: Array = donnees.get("ligues", [])
	_texte(scene, Rect2(x, y, 410, 30), "CHAMPIONNAT", 22, Tableau.FAIBLE, HORIZONTAL_ALIGNMENT_LEFT, Tableau.CHIFFRES)
	y += 36
	for l: Dictionary in ligues:
		var identifiant := str(l.get("id", ""))
		_bouton("EquipeTypeLigue_" + identifiant, Rect2(x, y, 410, 52), str(l.get("nom", "")), identifiant == str(ligue.get("id", "")), func(): _changer(identifiant, mode))
		y += 60
		if y > 640: break
	y += 14
	_texte(scene, Rect2(x, y, 410, 30), "ÉQUIPE", 22, Tableau.FAIBLE, HORIZONTAL_ALIGNMENT_LEFT, Tableau.CHIFFRES)
	y += 36
	var courant := str(ligue.get("id", ""))
	if ligue.get("journee") != null:
		_bouton("EquipeTypeModeJournee", Rect2(x, y, 410, 52), "XV de la journée", mode == "journee", func(): _changer(courant, "journee"))
		y += 60
	if ligue.get("saison") != null:
		_bouton("EquipeTypeModeSaison", Rect2(x, y, 410, 52), "XV de la saison", mode == "saison", func(): _changer(courant, "saison"))
		y += 60
	_bouton("EquipeTypeFermer", Rect2(x, 990, 410, 60), "Fermer", false, queue_free)

func _changer(championnat: String, nouveau: String) -> void:
	mode = nouveau
	choisir(championnat)
	construire()

func _bouton(nom: String, zone: Rect2, texte: String, actif: bool, rappel: Callable) -> Button:
	var b := Button.new()
	b.name = nom
	b.text = texte
	b.position = zone.position
	b.size = zone.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Tableau.FOND if actif else Tableau.IVOIRE)
	b.add_theme_color_override("font_hover_color", Tableau.FOND if actif else Tableau.OR)
	b.add_theme_color_override("font_pressed_color", Tableau.FOND)
	for etat in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Tableau.OR if actif else (Color("1b2a25") if etat != "normal" else Color("131e1b"))
		s.set_corner_radius_all(8)
		s.set_border_width_all(2)
		s.border_color = Tableau.OR if actif else Color("34443f")
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
			draw_rect(Rect2(0, i * size.y / 6.0, size.x, size.y / 6.0 + 1), Color("123422") if i % 2 == 0 else Color("163a27"))
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
		var c := Color(str(j.get("club", {}).get("color", "#f2ecdc")))
		v.points.append({"place": PLACES[n], "couleur": Tableau.VERT if bool(j.get("manager", false)) else c})
	v.pressed.connect(rappel)
	return v
