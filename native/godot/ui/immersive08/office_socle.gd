extends RefCounted
## Écran Bureau, socle (découpe de office_canvas.gd, sans changement) : préloads, constantes, petites aides de dessin
## en statiques (plaque, titre, liens, zones cliquables, pastilles, forme), lignes du classement court, noms de joueurs cliquables.
## Chaîne d’héritage : socle ← affiche du prochain match ← priorités et groupe ← rangée du bas (classement, courrier, prochains matchs) ← office_canvas.gd (fichier public).
const Copy = preload("res://ui/management_copy.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/management_state.gd")
const G = preload("res://ui/game_skin.gd")
const Avis = preload("res://guide/gabi_avis.gd")
const Office = preload("res://ui/immersive08/office.gd")
const World = preload("res://ui/immersive08/world_archive.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")
const Zones = preload("res://ui/immersive08/standings_zones.gd")
const Charte = preload("res://ui/charte.gd")
const Link = preload("res://ui/entity_link.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const EquipeType = preload("res://ui/equipe_type_view.gd")
const NotesMatch = preload("res://ui/notes_match.gd")

const PAGE_WIDTH := 2248
const GABI_WIDTH := 736
const GAP := 16
## Haut de page : le titre est dans l'en-tête de la coque (shell._entete_bureau) ; les blocs commencent à TOP.
const TOP := 0
## Bandeau d'illustration voilé de l'affiche (≤ 160 px réels : 170 unités ≈ 124 px à 1920).
const BAND := 118
const FIXTURE_H := 430
const ROW2_H := 430
const ROW3_H := 295
## Lignes du classement court (notre club et ses voisines).
const STANDINGS_ROWS := 4
const TIMELINE_H := 190
const JOURS := ["DIMANCHE", "LUNDI", "MARDI", "MERCREDI", "JEUDI", "VENDREDI", "SAMEDI"]

# ---------------------------------------------------------------------------------------------------------
# Éléments communs
# ---------------------------------------------------------------------------------------------------------

static func _box(color: Color, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(0)
	return style

## Panneau de page (charte §3, comme D.panel) : jeton `panneau`, rayon 18 px (24 en référence 2560), sans bordure, avec
## l'ombre portée de la charte, posé aux coordonnées de la page.
static func _plate(parent: Node, rectangle: Rect2, id: String) -> Panel:
	var panel := Panel.new()
	panel.name = id
	panel.add_theme_stylebox_override("panel", Charte.style_panneau(Charte.PANNEAU, maxi(3, C.px(24)), 0))
	parent.add_child(panel)
	D.place(panel, rectangle)
	return panel

static func _titre(card: Control, titre: String, badge: String = "") -> Label:
	var largeur := card.size.x / C.density
	var label := _ex(D.text(card, 24, 40, titre, 26, Charte.IVOIRE, 800, largeur * .6))
	label.name = "CardTitle"
	if not badge.is_empty(): D.text(card, largeur - 24, 38, badge, 17, Charte.IVOIRE_2, 700, largeur * .4, HORIZONTAL_ALIGNMENT_RIGHT)
	D.line(card, Vector2(20, 56), Vector2(largeur - 20, 56), Color(Charte.FILET, .9))
	return label

## Titre en Barlow Condensed ExtraBold Italic (vraie italique de la charte, 10°).
static func _ex(label: Label) -> Label:
	label.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	return label

static func _largeur(texte: String, taille: int, police: Font = null) -> float:
	var font: Font = police if police != null else Charte.texte_moyen()
	return font.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille))).x / C.density

## Lien texte avec flèche (« Réception → ») : bouton plat DM Sans, focus visible ; `droite` : bord droit à x.
static func _lien(parent: Control, x: float, y: float, texte: String, action: Callable, id: String, taille: int = 20, droite: bool = false) -> Button:
	var largeur := _largeur(texte, taille) + 16
	var bouton := Link.styled_button(parent, Rect2(x - largeur if droite else x, y, largeur, maxf(32, C.reach(32))), texte, taille, Charte.IVOIRE, id)
	bouton.add_theme_font_override("font", Charte.texte_moyen())
	bouton.pressed.connect(action)
	bouton.tooltip_text = texte
	return bouton

## Action principale de la page : pilule à contour, texte crème, Barlow italique (l'aplat doré reste à Continuer).
static func _principal(parent: Control, rectangle: Rect2, caption: String, action: Callable, id: String, accent: Color) -> Button:
	var bouton := D.button(parent, rectangle, caption, action, true, "arrow", false, accent, id)
	bouton.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	bouton.add_theme_font_size_override("font_size", maxi(12, C.px(25)))
	# Continuer (coque) porte l'unique aplat doré de l'écran : ce bouton est une pilule à contour `LINE`, texte crème.
	var pilule := Charte.RAYON_PILULE
	var etats := {"normal": C.box(Color.TRANSPARENT, C.LINE, pilule, 18), "hover": C.box(C.RAISED, C.FAINT, pilule, 18),
		"pressed": C.box(Charte.SELECTION, Charte.IVOIRE, pilule, 18), "disabled": C.box(Color.TRANSPARENT, C.LINE, pilule, 18)}
	for mode: String in etats:
		var style := etats[mode] as StyleBoxFlat
		style.content_margin_left = C.px(18)
		style.content_margin_right = C.px(18)
		bouton.add_theme_stylebox_override(mode, style)
	var focus := C.box(Color.TRANSPARENT, Charte.OR, pilule, 18)
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(C.px(3))
	bouton.add_theme_stylebox_override("focus", focus)
	for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(couleur, Charte.IVOIRE)
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	bouton.icon = C.icon_texture("arrow", Charte.IVOIRE)
	return bouton

## Bouton transparent qui couvre une zone entière (ligne, compteur) : texte en haut à gauche si `marge_bas` > 0.
static func _zone(parent: Control, rectangle: Rect2, caption: String, action: Callable, id: String, taille: int = 21, marge_gauche: float = 0.0, marge_bas: float = 0.0) -> Button:
	var bouton := Link.styled_button(parent, rectangle, caption, taille, Charte.IVOIRE, id)
	bouton.add_theme_font_override("font", C.font(700))
	for etat in ["normal", "hover", "pressed"]:
		var style := bouton.get_theme_stylebox(etat) as StyleBoxFlat
		style.content_margin_left = C.px(marge_gauche + 4)
		style.content_margin_bottom = C.px(marge_bas)
		style.set_corner_radius_all(0)
		if etat != "normal": style.bg_color = Color(Charte.IVOIRE, .06)
	var focus := bouton.get_theme_stylebox("focus") as StyleBoxFlat
	focus.set_corner_radius_all(0)
	bouton.pressed.connect(action)
	# Survol et appui : retour commun des tuiles cliquables (ui/retour_tuile.gd) ; les priorités gardent leur barre
	# d'urgence à gauche (pas de liseré du club par-dessus) et se lisent comme des lignes (jamais d'ombre).
	load("res://ui/retour_tuile.gd").brancher(bouton, bouton, 0.0, true, marge_gauche <= 0.0)
	return bouton

static func _crest(parent: Node, club: Dictionary, rectangle: Rect2) -> void:
	var image := G.crest(club, C.px(rectangle.size.x))
	parent.add_child(image)
	D.place(image, rectangle)

static func _label_reading(app: Control, parent: Node, label: Label, target: Dictionary, id: String, caption: String) -> Button:
	return Office.reading_overlay(app, parent, Rect2(label.position / C.density, label.size / C.density), target, id, caption)

static func _scheduled_reading(app: Control, parent: Node, fixture: Dictionary, opponent: Label, timing: Label) -> void:
	var club := Office.fixture_opponent(app.model, fixture)
	_label_reading(app, parent, opponent, Office.club_reading_target(app, club), "OfficeScheduledOpponent", opponent.text)
	_label_reading(app, parent, timing, Office.date_reading_target(app, fixture), "OfficeScheduledDate", timing.text)

## Pastille ovale V / N / D : la lettre dit le sens, la couleur le confirme (défaite en rouge, comme au classement).
static func _pastille(parent: Control, x: float, y: float, lettre: String, largeur: float = 30, hauteur: float = 24) -> void:
	var couleur: Color = Charte.PERTE if lettre == "D" else Charte.N if lettre == "N" else Charte.V
	var ovale := D.rect(parent, Rect2(x, y, largeur, hauteur), Color(couleur, .16), 0)
	var style := _box(Color(couleur, .16), couleur, 1)
	style.set_corner_radius_all(C.px(hauteur / 2.0))
	ovale.add_theme_stylebox_override("panel", style)
	D.text(ovale, largeur / 2.0, hauteur / 2.0 + 7, lettre, 17, couleur, 700, largeur, HORIZONTAL_ALIGNMENT_CENTER)

static func _forme(parent: Control, x: float, y: float, forme: Array, droite: bool = false) -> void:
	var nombre := mini(5, forme.size())
	var depart := x - nombre * 34.0 + 4.0 if droite else x
	for i in nombre: _pastille(parent, depart + i * 34.0, y, str(forme[i]))

static func _ligne_club(model: Dictionary, club_id: Variant) -> Dictionary:
	for league: Dictionary in model.get("leagues", []):
		if league.get("id") != model.get("meta", {}).get("leagueId"): continue
		for row: Dictionary in league.get("rows", []):
			if row.get("id") == club_id: return row
	for row: Dictionary in model.get("league", []):
		if row.get("id") == club_id: return row
	return {}

# ---------------------------------------------------------------------------------------------------------
# Noms de joueurs et classement court
# ---------------------------------------------------------------------------------------------------------

## Lignes du classement court : `nombre` lignes consécutives qui gardent notre club (au centre quand c'est possible).
static func short_rows(rows: Array, own_id: Variant, nombre: int) -> Array:
	if rows.size() <= nombre: return rows
	var own := 0
	for i in rows.size():
		if rows[i].get("id") == own_id: own = i
	var debut := clampi(own - (nombre - 1) / 2, 0, rows.size() - nombre)
	return rows.slice(debut, debut + nombre)

## Joueurs de l'effectif cités dans `texte` : nom complet, sinon nom de famille isolé (≥ 4 lettres, unique dans l'effectif).
## Renvoie [{id, start, end}] triés, sans chevauchement.
static func names_in(model: Dictionary, texte: String) -> Array:
	var trouves: Array = []
	var familles := {}
	var squad: Array = model.get("squad", [])
	for player: Dictionary in squad:
		var parts := str(player.get("name", "")).split(" ", false)
		if not parts.is_empty(): familles[parts[parts.size() - 1].to_lower()] = int(familles.get(parts[parts.size() - 1].to_lower(), 0)) + 1
	for player: Dictionary in squad:
		var nom := str(player.get("name", "")).strip_edges()
		if nom.is_empty() or str(player.get("id", "")).is_empty(): continue
		var debut := texte.find(nom)
		var fin := debut + nom.length()
		if debut < 0:
			var parts := nom.split(" ", false)
			var famille := parts[parts.size() - 1]
			if famille.length() < 4 or int(familles.get(famille.to_lower(), 0)) != 1: continue
			debut = -1
			var depart := 0
			while true:
				var at := texte.findn(famille, depart)
				if at < 0: break
				var avant := texte[at - 1] if at > 0 else " "
				var apres := texte[at + famille.length()] if at + famille.length() < texte.length() else " "
				if not _lettre(avant) and not _lettre(apres):
					debut = at
					break
				depart = at + 1
			if debut < 0: continue
			fin = debut + famille.length()
		trouves.append({"id": str(player.id), "start": debut, "end": fin})
	trouves.sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	var net: Array = []
	var limite := -1
	for trouve: Dictionary in trouves:
		if trouve.start >= limite:
			net.append(trouve)
			limite = trouve.end
	return net

static func _lettre(c: String) -> bool:
	return c.to_lower() != c.to_upper() or c.is_valid_int()

## Pose, sur chaque nom de joueur du texte écrit dans `zone` (unités de la page), un bouton transparent : clic = fiche
## du joueur, survol = mini-fiche. `zone` est le rectangle du texte (largeur de retour à la ligne comprise).
static func noms_cliquables(app: Control, parent: Control, zone: Rect2, texte: String, taille: int, police: Font) -> void:
	if app.get("navigation_controller") == null or not is_instance_valid(app.get("navigation_controller")): return
	var trouves := names_in(app.model, texte)
	if trouves.is_empty(): return
	var px := maxi(12, C.px(taille))
	var paragraphe := TextParagraph.new()
	paragraphe.add_string(texte, police, px)
	paragraphe.width = C.px(zone.size.x)
	paragraphe.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	for trouve: Dictionary in trouves:
		var cible := {"kind": "player", "id": str(trouve.id)}
		if not app.navigation_controller.entity_available(cible): continue
		for ligne in paragraphe.get_line_count():
			var plage := paragraphe.get_line_range(ligne)
			if int(trouve.start) < plage.x or int(trouve.end) > plage.y: continue
			var avant := police.get_string_size(texte.substr(plage.x, int(trouve.start) - plage.x), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x / C.density
			var large := police.get_string_size(texte.substr(int(trouve.start), int(trouve.end) - int(trouve.start)), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x / C.density
			var haut := paragraphe.get_line_size(ligne).y / C.density
			var hauteur := maxf(haut, C.reach(haut))
			var lien := Link.styled_button(parent, Rect2(zone.position.x + avant - 2, zone.position.y + ligne * haut, large + 4, hauteur), "", taille, Charte.IVOIRE, "OfficeNom_%s_%d" % [str(trouve.id).validate_node_name(), int(trouve.start)])
			lien.accessibility_name = "Ouvrir la fiche · " + texte.substr(int(trouve.start), int(trouve.end) - int(trouve.start))
			lien.pressed.connect(func(): app.navigation_controller.open_entity(cible))
			MiniFiche.lier(app, lien, str(trouve.id), "squad")
			break
