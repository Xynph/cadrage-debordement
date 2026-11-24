extends Control
## Socle de l'écran Préparation : constantes, état de la page, pièces de dessin communes (marques, panneaux, boutons, zones cliquables, pastilles),
## choix d'onglet, ouverture de fiches (club, joueur) et petits accesseurs du dossier. Chaîne de l'écran :
## socle ← preparation_dossier.gd ← preparation_xv.gd ← preparation_canvas.gd (fichier public).
const FocusLater := preload("res://ui/focus_later.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")
const World = preload("res://ui/immersive08/world_archive.gd")
const Decisions = preload("res://ui/decision_views.gd")
const MatchContext = preload("res://ui/preparation_match_context.gd")
const Briefing = preload("res://ui/preparation_briefing.gd")
const PersonName = preload("res://ui/person_name.gd")
const Link = preload("res://ui/entity_link.gd")
const Charte = preload("res://ui/charte.gd")
const SurvolLigne = preload("res://ui/survol_ligne.gd")
const Savoir = preload("res://ui/player_knowledge_text.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const ClubSheet = preload("res://ui/immersive08/club_sheet_canvas.gd")
const RapportAdverse = preload("res://ui/immersive08/preparation_adversaire.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Consignes = preload("res://ui/immersive08/preparation_consignes.gd")
const TABS = ["Dossier", "Consignes", "Entrainement"]
const CHAMP_DOSSIER_PENDING = "Le dossier adverse sera disponible la semaine du match."

var app: Control
var state: Dictionary
var active_tab := 0
var focus_ready := false
var reports: Dictionary
var fixture: Dictionary
var match_context := MatchContext.new()


## ---- Pièces communes de la direction artistique (design/ux/11-preparation.md, revue du 19/11/2026) --------------------

## Marque pleine dessinée (flèche haut / bas, losange, égalité) : jamais un glyphe de police, toujours accompagnée d'un mot.
class Marque extends Control:
	var forme := "haut"
	var couleur := Charte.IVOIRE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		match forme:
			"haut": draw_colored_polygon(PackedVector2Array([Vector2(w * .5, h * .08), Vector2(w * .96, h * .92), Vector2(w * .04, h * .92)]), couleur)
			"bas": draw_colored_polygon(PackedVector2Array([Vector2(w * .04, h * .08), Vector2(w * .96, h * .08), Vector2(w * .5, h * .92)]), couleur)
			"cadenas":
				draw_rect(Rect2(w * .12, h * .45, w * .76, h * .5), couleur)
				draw_arc(Vector2(w * .5, h * .45), w * .26, PI, TAU, 16, couleur, maxf(1.5, w * .1))
			"droite": draw_colored_polygon(PackedVector2Array([Vector2(w * .1, h * .04), Vector2(w * .94, h * .5), Vector2(w * .1, h * .96)]), couleur)
			"losange": draw_colored_polygon(PackedVector2Array([Vector2(w * .5, 0), Vector2(w, h * .5), Vector2(w * .5, h), Vector2(0, h * .5)]), couleur)
			_:
				draw_rect(Rect2(w * .1, h * .22, w * .8, h * .2), couleur)
				draw_rect(Rect2(w * .1, h * .58, w * .8, h * .2), couleur)

static func _style(fond: Color, bord: Color = Color.TRANSPARENT, epaisseur: int = 0, bas_seulement: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.set_corner_radius_all(0)
	if bord.a > 0.0 and epaisseur > 0:
		style.border_color = bord
		if bas_seulement: style.border_width_bottom = epaisseur
		else: style.set_border_width_all(epaisseur)
	return style

static func _pilule(fond: Color, contour: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := C.box(fond, contour, Charte.RAYON_PILULE, 12)
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

static func _nombre(valeur: Variant) -> bool:
	return valeur is int or valeur is float

## Titre de panneau ou chiffre fort : Barlow Condensed italique (inclinaison du logo).
func _titre(parent: Node, x: float, baseline: float, valeur: String, taille: int, couleur: Color = Charte.IVOIRE, largeur: float = 0.0, aligne: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := D.text(parent, x, baseline, valeur, taille, couleur, 700, largeur, aligne)
	label.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	return label

func _texte(parent: Node, x: float, baseline: float, valeur: String, taille: int, couleur: Color = Charte.IVOIRE, largeur: float = 0.0, aligne: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return D.text(parent, x, baseline, valeur, taille, couleur, 500, largeur, aligne, true)

## Petite étiquette en capitales (colonnes, repères).
func _etiquette(parent: Node, x: float, baseline: float, valeur: String, largeur: float = 0.0, aligne: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return D.text(parent, x, baseline, valeur.to_upper(), 15, Charte.IVOIRE_2, 600, largeur, aligne)

func _panneau(parent: Node, rectangle: Rect2, titre: String, id: String, legende: String = "") -> Panel:
	var panel := Panel.new()
	panel.name = id
	panel.add_theme_stylebox_override("panel", Charte.ombrer_droit(_style(Charte.PANNEAU)))
	parent.add_child(panel)
	D.place(panel, rectangle)
	if not titre.is_empty():
		var entete := _titre(panel, 20, 40, titre.to_upper(), 26, Charte.IVOIRE, rectangle.size.x - 40)
		entete.name = "CardTitle"
		if not legende.is_empty():
			var droite := _etiquette(panel, rectangle.size.x - 20, 38, legende, rectangle.size.x * .6, HORIZONTAL_ALIGNMENT_RIGHT)
			droite.name = "CardCaption"
	return panel

func _marque(parent: Node, x: float, centre_y: float, taille: float, forme: String, couleur: Color) -> Marque:
	var marque := Marque.new()
	marque.forme = forme
	marque.couleur = couleur
	marque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(marque)
	D.place(marque, Rect2(x, centre_y - taille / 2.0, taille, taille))
	return marque

func _barre(parent: Node, rectangle: Rect2, fond: Color, bord: Color = Color.TRANSPARENT) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(fond, bord, 2 if bord.a > 0.0 else 0))
	parent.add_child(panel)
	D.place(panel, rectangle)
	return panel

## Rayure d'une ligne sur deux (rang impair), comme l'Effectif (ui/survol_ligne.gd).
func _rayer(parent: Control, rectangle: Rect2, rang: int) -> void:
	var rayure := SurvolLigne.rayure(parent, rang)
	if rayure != null: D.place(rayure, rectangle)

## Survol de ligne commun sur la zone cliquable d'une ligne (la rayure est posée à part par `_rayer`).
func _survol_ligne(zone: Button) -> Button:
	var fond = SurvolLigne.appliquer(zone, false, Color.TRANSPARENT, app.accent)
	fond.sans_rayure = true
	return zone

## Pastille de forme ovale : la lettre V / N / D est toujours écrite.
func _pastille(parent: Control, rectangle: Rect2, lettre: String, nom: String) -> Panel:
	var couleur: Color = Charte.PERTE if lettre == "D" else Charte.N if lettre == "N" else Charte.V
	var panel := Panel.new()
	panel.name = nom
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _style(Color(couleur, .16), couleur, 2)
	style.set_corner_radius_all(maxi(1, C.px(rectangle.size.y / 2.0)))
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	D.place(panel, rectangle)
	D.text(panel, rectangle.size.x / 2.0, rectangle.size.y / 2.0 + 6, lettre, 17, Charte.IVOIRE, 700, rectangle.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	return panel

## Boutons de la charte : « lien » (texte ivoire + flèche), « ivoire » (une action principale par écran, jamais l'or),
## « onglet » (actif : fond relevé et filet ivoire dessous), « choix » (consigne ; choisie : cadre ivoire + coche).
func _bouton(parent: Node, rectangle: Rect2, libelle: String, action: Callable, mode: String, icone: String, id: String, choisi: bool = false) -> Button:
	var bouton := Button.new()
	bouton.name = id
	bouton.text = libelle
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.clip_text = true
	bouton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.alignment = HORIZONTAL_ALIGNMENT_LEFT if mode in ["choix", "onglet"] else HORIZONTAL_ALIGNMENT_RIGHT
	var titre := mode in ["ivoire", "onglet"]
	bouton.add_theme_font_override("font", Charte.TITRE_GRAS if titre else C.font(600))
	bouton.add_theme_font_size_override("font_size", C.font_px(21 if titre else 18))
	var texte: Color = Charte.IVOIRE_2 if mode == "onglet" and not choisi else Charte.IVOIRE
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		bouton.add_theme_color_override(etat, texte)
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	var normal := _style(Charte.PANNEAU_3 if (mode == "onglet" and choisi) or (mode == "choix" and choisi) else Charte.PANNEAU_2 if mode == "choix" else Charte.IVOIRE if mode == "ivoire" else Color.TRANSPARENT, Charte.IVOIRE if choisi else Color.TRANSPARENT, 3 if mode == "onglet" else 2, mode == "onglet")
	var survol := _style(Charte.IVOIRE_2 if mode == "ivoire" else Charte.PANNEAU_3 if (mode == "onglet" and choisi) else Charte.PANNEAU_2, Charte.IVOIRE if choisi else Color.TRANSPARENT, 3 if mode == "onglet" else 2, mode == "onglet")
	var enfonce := _style(Charte.IVOIRE_2 if mode == "ivoire" else Charte.PANNEAU_3, Charte.IVOIRE if choisi else Color.TRANSPARENT, 3 if mode == "onglet" else 2, mode == "onglet")
	var focus := _style(Color.TRANSPARENT, Charte.IVOIRE, 2)
	var inactif := _style(Charte.PANNEAU_3 if mode == "ivoire" else Color.TRANSPARENT)
	if mode in ["onglet", "ivoire"]:
		# Charte finale : pilule. Onglet actif = aplat crème ; bouton « ivoire » = pilule à contour (un seul aplat doré : Continuer).
		var plein := mode == "onglet" and choisi
		normal = _pilule(Charte.IVOIRE if plein else Color.TRANSPARENT, Charte.FILET if mode == "ivoire" else Color.TRANSPARENT)
		survol = _pilule(Charte.IVOIRE if plein else Charte.PANNEAU_2, Charte.IVOIRE_3 if mode == "ivoire" else Color.TRANSPARENT)
		enfonce = _pilule(Charte.IVOIRE if plein else Charte.PANNEAU_3, Charte.IVOIRE if mode == "ivoire" else Color.TRANSPARENT)
		inactif = _pilule(Color.TRANSPARENT, Charte.FILET if mode == "ivoire" else Color.TRANSPARENT)
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			bouton.add_theme_color_override(etat, Charte.PANNEAU if plein else (Charte.IVOIRE_2 if mode == "onglet" and etat == "font_color" else Charte.IVOIRE))
	# Choix d'une consigne : pilule aussi (choisie = contour crème, sinon contour FILET), jamais un rectangle à angles vifs.
	if mode == "choix":
		normal = _pilule(Charte.PANNEAU_3 if choisi else Charte.PANNEAU_2, Charte.IVOIRE if choisi else Charte.FILET)
		survol = _pilule(Charte.PANNEAU_3, Charte.IVOIRE if choisi else Charte.IVOIRE_3)
		enfonce = _pilule(Charte.PANNEAU_3, Charte.IVOIRE)
		inactif = _pilule(Color.TRANSPARENT, Charte.FILET)
		focus = _pilule(Color.TRANSPARENT, Charte.IVOIRE)
		focus.set_border_width_all(2)
	for style: StyleBoxFlat in [normal, survol, enfonce, inactif]:
		style.content_margin_left = C.px(12)
		style.content_margin_right = C.px(12)
		style.content_margin_top = 0
		style.content_margin_bottom = 0
	bouton.add_theme_stylebox_override("normal", normal)
	bouton.add_theme_stylebox_override("hover", survol)
	bouton.add_theme_stylebox_override("pressed", enfonce)
	bouton.add_theme_stylebox_override("hover_pressed", enfonce)
	bouton.add_theme_stylebox_override("disabled", inactif)
	bouton.add_theme_stylebox_override("focus", focus)
	if not icone.is_empty():
		bouton.icon = C.icon_texture(icone, Charte.PANNEAU if mode == "onglet" and choisi else Charte.IVOIRE)
		bouton.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bouton.expand_icon = true
		bouton.add_theme_constant_override("icon_max_width", C.px(20))
	bouton.pressed.connect(action)
	parent.add_child(bouton)
	D.place(bouton, C.reach_rect(rectangle))
	return bouton

## Zone cliquable d'une ligne (posée AVANT son texte : les libellés laissent passer la souris).
func _zone(parent: Node, rectangle: Rect2, action: Callable, id: String, infobulle: String) -> Button:
	var zone := Button.new()
	zone.name = id
	zone.flat = true
	zone.focus_mode = Control.FOCUS_ALL
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zone.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	zone.add_theme_stylebox_override("hover", _style(Charte.PANNEAU_2))
	zone.add_theme_stylebox_override("pressed", _style(Charte.PANNEAU_3))
	zone.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, Charte.IVOIRE, 2))
	zone.tooltip_text = infobulle
	zone.accessibility_name = infobulle
	zone.pressed.connect(action)
	parent.add_child(zone)
	D.place(zone, rectangle)
	return zone

func _largeur(valeur: String, taille: int, gras: bool = false) -> float:
	var police: Font = C.font(700) if gras else C.BODY
	return police.get_string_size(valeur, HORIZONTAL_ALIGNMENT_LEFT, -1, C.font_px(taille)).x / maxf(C.density, .01)

func _couleur_club(club: Dictionary, nous: bool) -> Color:
	if nous: return app.accent
	var identite := G.identity(club)
	var brut := str(identite.get("color", club.get("color", "")))
	return Color.from_string(brut, Color(0, 0, 0, 0)) if not brut.is_empty() else Color(0, 0, 0, 0)

## Adjoint du staff du club (fonction « adjoint »), lu dans les vraies données ; {} si le club n'en a pas.
func _adjoint() -> Dictionary:
	var club_id: Variant = app.model.get("club", {}).get("id")
	var equipes: Array = app.model.get("staff", {}).get("teams", [])
	var trouve := {}
	for equipe: Dictionary in equipes:
		for membre: Dictionary in equipe.get("members", []):
			var fonction := (str(membre.get("roleLabel", "")) + " " + str(membre.get("role", ""))).to_lower()
			if not (fonction.contains("adjoint") or str(membre.get("role", "")) == "assistant"): continue
			if equipe.get("id") == club_id: return membre
			if trouve.is_empty(): trouve = membre
	return trouve

func _choose(index: int) -> void:
	if index == active_tab:
		var current := find_child("PreparationTab" + TABS[index], true, false) as Button
		current.set_pressed_no_signal(true)
		return
	if app.body_scroll != null: state.outer[active_tab] = app.body_scroll.scroll_vertical
	state.tab = index
	state.sub = ""
	state.focus[index] = "PreparationTab" + TABS[index]
	var owner := app
	owner._render()
	if index == 2:
		var next := owner.find_child("TrainingTab0", true, false) as Button
		if next != null: FocusLater.grab(next)

## Sous-pages du dossier (jamais une fenêtre) : « reperes » = tous les repères, « conseils » = conseils détaillés du staff.
## Chaque ouverture est une étape d'historique (Précédent / Suivant de la coque).
func _ouvrir_sous(sous_page: String) -> void:
	if app.body_scroll != null: state.outer[0] = 0 if not sous_page.is_empty() else state.outer[0]
	state.sub = sous_page
	app._render()
	if is_instance_valid(app.navigation_controller): app.navigation_controller.observe("Préparation")

func _section(id: String) -> Control:
	var section := Control.new()
	section.name = id
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(section)
	D.place(section, Rect2(0, 257, 2248, 966))
	return section

func _tactic_label(options: Array, id: Variant) -> String:
	for entry: Dictionary in options:
		if entry.get("id") == id: return str(entry.get("label", "—"))
	return "—"

func _opponent() -> Dictionary:
	var opponent: Dictionary = reports.get("opponent", {})
	if opponent.is_empty():
		for key in ["home", "away"]:
			var club: Dictionary = fixture.get(key, {})
			if not club.is_empty() and club.get("id") != app.model.club.get("id"): return club
		return {}
	for key in ["home", "away"]:
		var club: Dictionary = fixture.get(key, {})
		if club.get("id") == opponent.get("id"): return club
	return _club(opponent.get("id"))

func _club(id: Variant) -> Dictionary:
	for club: Dictionary in app.model.get("league", []):
		if club.get("id") == id: return club
	for club: Dictionary in app.model.get("meta", {}).get("catalogue", []):
		if club.get("id") == id: return club
	return {"name":reports.get("opponent", {}).get("name", "Club"), "abbr":"XV"}

func _crest(parent: Node, data: Dictionary, rectangle: Rect2) -> void:
	var crest := G.crest(data, C.px(rectangle.size.x))
	parent.add_child(crest)
	D.place(crest, rectangle)

func _ouvrir_club_xv(club_id: int) -> void:
	app.management_ui.club_sheet = {"id":club_id, "tab":2, "sort":"fam", "descending":false}
	app.navigation_controller.open_entity({"kind":"club", "id":str(club_id)})

## Fiche d'un club (onglet « Vue d'ensemble ») : forme, résultats, confrontations.
func _ouvrir_club(club: Dictionary) -> void:
	if club.get("id") == null: return
	app.navigation_controller.open_entity({"kind":"club", "id":str(int(club.get("id")))})

## Clic sur un joueur (carte, case, ligne) : sa fiche si le jeu en a une, sinon l'XV de son club.
func _ouvrir_joueur(joueur: Dictionary, club_id: int) -> void:
	var pid := str(joueur.get("id", ""))
	for genre: String in ["player", "market"]:
		if Link.available(app, genre, pid):
			app.navigation_controller.open_entity({"kind":genre, "id":pid})
			return
	if club_id >= 0: _ouvrir_club_xv(club_id)

## Joueur adverse ou du club ouvrable (fiche ou XV de son club) ; jamais un bouton factice.
func _joueur_ouvrable(joueur: Dictionary, club_id: int) -> bool:
	var pid := str(joueur.get("id", ""))
	for genre: String in ["player", "market"]:
		if Link.available(app, genre, pid): return true
	return club_id >= 0 and Link.available(app, "club", str(club_id))

## Zone cliquable pour toute une carte ou une case (posée avant le texte) : clic = fiche, survol = mini-fiche.
func _zone_joueur(parent: Node, rectangle: Rect2, joueur: Dictionary, club_id: int, id: String) -> Button:
	var pid := str(joueur.get("id", ""))
	var zone := _zone(parent, C.reach_rect(rectangle), _ouvrir_joueur.bind(joueur, club_id), id, "Ouvrir · " + str(joueur.get("name", "")))
	var source := "squad" if not P.player(app.model, pid).is_empty() else "market" if Link.available(app, "market", pid) else "adverse"
	MiniFiche.lier(app, zone, pid, source)
	return zone

## Nom de joueur adverse ou du club : clic = fiche (la sienne si elle existe, sinon l'XV de son club), survol = mini-fiche.
func _lien_joueur(parent: Node, rectangle: Rect2, joueur: Dictionary, taille: int, id: String, club_id: int, legende: String = "") -> Control:
	var pid := str(joueur.get("id", ""))
	var nom := str(joueur.get("name", "—")) if legende.is_empty() else legende
	rectangle = C.reach_rect(rectangle)
	for genre: String in ["player", "market"]:
		if Link.available(app, genre, pid):
			var lien := Link.name_link(app, parent, rectangle, genre, pid, nom, taille, Charte.IVOIRE, id)
			var source := "squad" if not P.player(app.model, pid).is_empty() else "market"
			MiniFiche.lier(app, lien, pid, source)
			return lien
	if not _joueur_ouvrable(joueur, club_id):
		# Aucune fiche ni club ouvrable : simple texte, jamais un nom qui ressemble à un lien.
		var etiquette := C.label(nom, taille, Charte.IVOIRE, true, 700)
		etiquette.name = id
		etiquette.clip_text = true
		etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		etiquette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		parent.add_child(etiquette)
		etiquette.position = (rectangle.position + Vector2(4, 0)) * C.density
		etiquette.size = rectangle.size * C.density
		return etiquette
	var bouton := Link.styled_button(parent, rectangle, nom, taille, Charte.IVOIRE, id)
	bouton.tooltip_text = "Ouvrir · " + nom
	bouton.set_meta("entity_kind", "player")
	bouton.set_meta("entity_id", pid)
	bouton.pressed.connect(_ouvrir_joueur.bind(joueur, club_id))
	MiniFiche.lier(app, bouton, pid, "adverse")
	return bouton
