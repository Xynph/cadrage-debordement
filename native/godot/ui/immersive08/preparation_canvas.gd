extends Control
## Dossier adverse et intentions de jeu. Le troisième onglet ouvre le planning.
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
const Savoir = preload("res://ui/player_knowledge_text.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const ClubSheet = preload("res://ui/immersive08/club_sheet_canvas.gd")
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

static func build(application: Control, canvas: Control) -> void:
	var page := new()
	page.name = "ImmersivePreparation"
	page.app = application
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, 2248, 1230))
	page._build()

static func compact(app: Control) -> Control:
	var dossier: Control = app.SquadViews.preparation(app)
	var next: Variant = app.model.get("next")
	if not SeasonPreparation.is_japan(app.model.meta):
		var context: Control
		if next is Dictionary and not next.is_empty():
			context = _compact_fixture(app,next)
		else:
			var upcoming := _upcoming_preparation_note(app.model.meta)
			if not upcoming.is_empty():
				context = C.wrap(upcoming,26,C.GOLD,true,700)
				if SeasonPreparation.is_champ(app.model.meta):
					var summary := C.v(4)
					summary.add_child(context)
					summary.add_child(C.wrap(CHAMP_DOSSIER_PENDING,20,C.MUTED))
					context = summary
		if context != null:
			dossier.add_child(context)
			# Sous la bannière de la page, au-dessus de la barre d'onglets.
			var banner := dossier.get_node_or_null("PreparationBanner")
			dossier.move_child(context,banner.get_index() + 1 if banner != null else 0)
		return dossier
	var preparation := SeasonPreparation.data(app.model.meta)
	if preparation.is_empty() and not next is Dictionary: return dossier
	var page := C.v(10)
	C.fill(page,true)
	var card := C.card()
	page.add_child(card)
	var row := C.h(20)
	C.content(card).add_child(row)
	var summary := C.v(4)
	C.fill(summary)
	row.add_child(summary)
	summary.add_child(C.wrap(("PRÉPARATION · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "jlo-d1")))).to_upper(),30,C.GOLD,true,700))
	if not preparation.is_empty():
		summary.add_child(C.wrap(World.preparation_note(preparation),29,C.IVORY))
		var advance := C.button(app.primary_text(),app.primary_action,false,app.accent)
		advance.name = "JapanPreparationDossierAdvance"
		advance.disabled = app.waiting
		row.add_child(advance)
	else:
		summary.add_child(_compact_fixture(app,next,true))
	page.add_child(dossier)
	return page

static func _upcoming_preparation_note(meta: Dictionary) -> String:
	if meta.get("leagueId") not in ["srp", "champ"]: return ""
	var preparation := SeasonPreparation.data(meta)
	return "" if preparation.is_empty() else World.preparation_note(preparation)

static func _fixture_position(app: Control, next: Dictionary, show_date: bool) -> String:
	var position := P.fixture_position(next,app.model.club.get("id"))
	var date := P.fixture_date(next,true) if show_date else ""
	return position if date.is_empty() else position+"  ·  "+date

static func _compact_fixture(app: Control, next: Dictionary, show_date: bool = false) -> HBoxContainer:
	var row := C.h(16)
	var position := C.label(_fixture_position(app,next,show_date),26,C.GOLD,true,700)
	position.name = "PreparationFixturePosition"
	row.add_child(position)
	var venue_name := P.fixture_venue(next,false)
	if not venue_name.is_empty():
		var venue := C.wrap(venue_name,26,C.IVORY,true,600)
		venue.name = "PreparationFixtureVenue"
		C.fill(venue)
		row.add_child(venue)
	return row

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

## ---- Construction -----------------------------------------------------------------------------------

## Ouvre une sous-page pleine page de la Préparation (« planning », « reprise », « reperes », « conseils », « xv »), depuis
## n'importe quel écran : retour par « ← Retour » ou Échap, une étape d'historique (Précédent / Suivant).
static func ouvrir_sous_page(application: Control, sous_page: String) -> void:
	if not application.management_ui.get("preparation") is Dictionary:
		application.management_ui.preparation = {"tab":0,"outer":[0,0,0],"attack":0,"defense":0,"focus":["","",""]}
	if application.route != "Préparation": application._navigate("Préparation")
	var etat: Dictionary = application.management_ui.preparation
	etat.tab = 0
	etat.sub = sous_page
	etat.outer[0] = 0
	application._render()
	if is_instance_valid(application.navigation_controller): application.navigation_controller.observe("Préparation")

## Échap ferme la sous-page ouverte (règle unique : fenêtre, puis sous-écran, puis menu).
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or active_tab != 0 or str(state.get("sub", "")).is_empty(): return
	get_viewport().set_input_as_handled()
	_ouvrir_sous("")

func _build() -> void:
	if not app.management_ui.get("preparation") is Dictionary:
		app.management_ui.preparation = {"tab":0,"outer":[0,0,0],"attack":0,"defense":0,"focus":["","",""]}
	state = app.management_ui.preparation
	active_tab = clampi(int(state.tab), 0, 1)
	reports = app.model.get("decisions", {}).get("preparation") if app.model.get("decisions", {}).get("preparation") is Dictionary else {}
	fixture = app.model.get("next") if app.model.get("next") is Dictionary else {}
	_heading()
	var hauteur := 1230.0
	if active_tab == 0: hauteur = maxf(hauteur, 257.0 + _dossier() + 10.0)
	else: _consignes()
	var conteneur := get_parent() as Control
	size.y = C.px(hauteur)
	if conteneur != null: conteneur.custom_minimum_size.y = maxf(conteneur.custom_minimum_size.y, C.px(hauteur))
	add_child(match_context)
	match_context.bind(app)
	app.bridge.model_changed.connect(_refresh_briefing)
	_observe(self)
	if app.body_scroll != null:
		app.body_scroll.get_v_scroll_bar().value_changed.connect(func(value: float):
			if focus_ready: state.outer[active_tab] = int(value))
	_restore.call_deferred()

func _refresh_briefing(model: Dictionary) -> void:
	# Ticks update the live-state wording without rebuilding the focused page.
	var titre := find_child("PreparationBriefingTitle_live", true, false) as Label
	if titre == null: return
	for check: Dictionary in Briefing.project(model).checks:
		if check.id != "live": continue
		titre.text = check.title
		var bouton := find_child("PreparationBriefing_live", true, false) as Button
		if bouton == null: return
		bouton.tooltip_text = check.detail + "\n" + check.caption
		bouton.accessibility_name = check.title + " · " + check.detail

func _heading() -> void:
	var hero := D.panel(self, Rect2(0, 0, 2248, 167), "", "", "", "PreparationHero")
	hero.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var japan := SeasonPreparation.is_japan(app.model.meta)
	var preparation := SeasonPreparation.data(app.model.meta) if japan else {}
	if active_tab == 1:
		var surtitre := D.text(hero, 4, 34, ("PRÉPARATION · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "jlo-d1")))).to_upper() if japan else "", 20, Charte.IVOIRE_2, 600, 1065)
		surtitre.name = "PreparationLiveContext"
		match_context.live_context = surtitre
	var titre := ("Préparer la saison · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "jlo-d1")))) if not preparation.is_empty() else "Préparation"
	app.heading = _titre(hero, 4, 88, titre.to_upper(), 56, Charte.IVOIRE, 1355)
	app.heading.add_theme_font_override("font", Charte.TITRE_FICHE)
	if active_tab == 1:
		app.heading.name = "PreparationContextHeading"
		match_context.live_heading = app.heading
	_ligne_contexte(hero, preparation, 134)
	if P.is_derby(app.model) and preparation.is_empty(): D.derby_chip(hero, Rect2(2106, 118, 98, 30))
	var voir_match := MatchContext.match_available(app.model)
	# Commandes d'en-tête : lien « Revoir la composition » puis l'action principale (un seul ivoire plein).
	var droite := 2248.0
	if not preparation.is_empty():
		var avancer := _bouton(hero, Rect2(droite - 420, 50, 420, 54), app.primary_text().trim_suffix("  →"), app.primary_action, "ivoire", "arrow", "JapanPreparationDossierAdvance")
		avancer.disabled = app.waiting
		droite -= 440
	elif voir_match:
		match_context.match_button = _bouton(hero, Rect2(droite - 400, 50, 400, 54), "", match_context.open_match, "ivoire", "arrow", "PreparationGoMatch")
		_verrou_match(hero, match_context.match_button, droite)
		droite -= 420
	else:
		_bouton(hero, Rect2(droite - 400, 50, 400, 54), "Carnet de jeu", func(): app._navigate("Plan de jeu"), "ivoire", "arrow", "PreparationOpenPlaybook")
		droite -= 420
	_bouton(hero, Rect2(droite - 400, 50, 400, 54), "Revoir la composition", func(): app._navigate("Composition"), "lien", "arrow", "PreparationComposition")
	var barre := Control.new()
	barre.name = "PreparationTabs"
	barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(barre)
	D.place(barre, Rect2(0, 182, 2248, 57))
	var libelles := ["Dossier adverse", "Consignes", "Entraînement"]
	for i in TABS.size():
		var bouton := _bouton(barre, Rect2(i * 256, 0, 248, 55), libelles[i], func(): _choose(i), "onglet", "", "PreparationTab" + TABS[i], i == active_tab)
		if i == 1: match_context.focus_fallback = bouton
		bouton.toggle_mode = true
		bouton.set_pressed_no_signal(i == active_tab)
		bouton.gui_input.connect(func(event: InputEvent):
			if event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT, KEY_RIGHT]:
				bouton.accept_event()
				_choose(posmod(i + (1 if event.keycode == KEY_RIGHT else -1), TABS.size())))
	# Liens d'organisation, alignés à droite de la barre d'onglets.
	var x := 2248.0
	if voir_match:
		x -= 330
		_bouton(barre, Rect2(x, 0, 320, 55), "Carnet de jeu", func(): app._navigate("Plan de jeu"), "lien", "arrow", "PreparationOpenPlaybook")
	if not voir_match and preload("res://ui/reprise_view.gd").relevant(app.model):
		x -= 330
		_bouton(barre, Rect2(x, 0, 320, 55), "La reprise", func(): load("res://ui/reprise_dialog.gd").open(app), "lien", "calendar", "PreparationReprise")
	x -= 350
	_bouton(barre, Rect2(x, 0, 340, 55), "Préparer la suite", func(): load("res://ui/manager_planning.gd").open(app), "lien", "calendar", "PreparationManagerPlanning")
	D.line(self, Vector2(0, 241), Vector2(2248, 241), Color(Charte.FILET, .85))

## Le match n'est pas encore ouvert : bouton verrouillé (cadenas + raison écrite, jamais la couleur seule).
func _verrou_match(hero: Control, bouton: Button, droite: float) -> void:
	var live: Variant = app.model.get("live")
	if live is Dictionary and not live.is_empty(): return
	if app.model.get("meta", {}).get("calendarCadence", {}).get("matchReady", false): return
	bouton.disabled = true
	bouton.icon = null
	var style := bouton.get_theme_stylebox("disabled").duplicate() as StyleBoxFlat
	style.content_margin_right = C.px(48)
	bouton.add_theme_stylebox_override("disabled", style)
	_marque(hero, droite - 34, 77, 20, "cadenas", Charte.IVOIRE_2)
	var date := P.fixture_date(fixture)
	var raison := "S’ouvre le jour du match" + (" · " + date if not date.is_empty() else "")
	var etiquette := _texte(hero, droite, 124, raison, 15, Charte.IVOIRE_2, 400, HORIZONTAL_ALIGNMENT_RIGHT)
	etiquette.name = "PreparationGoMatchReason"
	bouton.tooltip_text = raison
	bouton.accessibility_name = "Aller au jour de match, verrouillé · " + raison

## Sous-titre : « Club – Adversaire · position et date · terrain · classements » ; les deux clubs sont cliquables.
func _ligne_contexte(hero: Control, preparation: Dictionary, baseline: float) -> void:
	var pose := 4.0
	if not preparation.is_empty():
		D.text(hero, pose, baseline, World.preparation_note(preparation), 20, Charte.IVOIRE, 500, 1700, HORIZONTAL_ALIGNMENT_LEFT, true)
		return
	if fixture.is_empty():
		var legende := _upcoming_preparation_note(app.model.meta)
		if legende.is_empty(): legende = P.next_fixture_caption(app.model, "Aucune rencontre annoncée")
		D.text(hero, pose, baseline, legende, 20, Charte.IVOIRE, 500, 1700, HORIZONTAL_ALIGNMENT_LEFT, true)
		return
	var domicile: Dictionary = fixture.get("home", {})
	var exterieur: Dictionary = fixture.get("away", {})
	var nous_id: Variant = app.model.club.get("id")
	for rang in 2:
		var club: Dictionary = domicile if rang == 0 else exterieur
		var nom := G.club_name(club)
		var largeur := _largeur(nom, 20, true) + 14
		Link.name_link(app, hero, C.reach_rect(Rect2(pose - 4, baseline - 26, largeur, 34)), "club", str(int(club.get("id", -1))) if club.get("id") != null else "", nom, 20, Charte.IVOIRE, "PreparationContextClub" + ("Own" if club.get("id") == nous_id else "Opponent"))
		pose += largeur
		if rang == 0:
			_texte(hero, pose, baseline, "–", 20, Charte.IVOIRE_2, 24)
			pose += 30
	var morceaux: Array[Array] = []
	var competition := str(fixture.get("label", ""))
	if not competition.is_empty(): morceaux.append([competition, ""])
	morceaux.append([_fixture_position(app, fixture, true), "PreparationFixturePosition"])
	var terrain := P.fixture_venue(fixture, false)
	if not terrain.is_empty(): morceaux.append([terrain, "PreparationFixtureVenue"])
	var classement := _classement_texte()
	if not classement.is_empty(): morceaux.append([classement, ""])
	for morceau: Array in morceaux:
		_texte(hero, pose, baseline, "·", 20, Charte.IVOIRE_2, 20)
		pose += 22
		var etiquette := _texte(hero, pose, baseline, str(morceau[0]), 20, Charte.IVOIRE, _largeur(str(morceau[0]), 20) + 8)
		if not str(morceau[1]).is_empty(): etiquette.name = str(morceau[1])
		pose += _largeur(str(morceau[0]), 20) + 14

func _classement_texte() -> String:
	var nous: Dictionary = app.model.club
	var eux := _opponent()
	if eux.is_empty() or not P.standings_open(nous) or not P.standings_open(eux): return ""
	var rang_nous := P.rank_ordinal(nous)
	var rang_eux := P.rank_ordinal(eux)
	if rang_nous == "—" or rang_eux == "—" or not _nombre(nous.get("points")) or not _nombre(eux.get("points")): return ""
	return "%s (%d pts) contre %s (%d pts)" % [rang_nous, int(nous.points), rang_eux, int(eux.points)]

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

func _observe(node: Node) -> void:
	if node is BaseButton and node.focus_mode != Control.FOCUS_NONE and node != match_context.pause_button:
		node.focus_entered.connect(func():
			if focus_ready: state.focus[active_tab] = str(node.name))
	for child in node.get_children(): _observe(child)

func _restore() -> void:
	if not is_inside_tree(): return
	var tree := get_tree()
	await tree.process_frame
	if not is_inside_tree(): return
	await tree.process_frame
	if not is_inside_tree(): return
	for pair: Array in [["PreparationAttackScroll", "attack"], ["PreparationDefenseScroll", "defense"]]:
		var scroll := find_child(pair[0], true, false) as ScrollContainer
		if scroll != null: scroll.scroll_vertical = int(state.get(pair[1], 0))
	if app.body_scroll != null: app.body_scroll.scroll_vertical = int(state.outer[active_tab])
	focus_ready = true
	var focus_id := str(state.focus[active_tab])
	if focus_id.is_empty(): return
	var previous := find_child(focus_id, true, false) as BaseButton
	if previous != null and previous.is_visible_in_tree():
		# Consigne grisée le temps que le moteur réponde (commande suivante, sauvegarde) : le focus l'attend
		# au lieu de retomber sur l'onglet, sauf si le joueur l'a posé ailleurs entre-temps.
		var frames := 0
		while previous.disabled and match_context != null and match_context._engine_busy() and frames < 240:
			await tree.process_frame
			frames += 1
			if not is_inside_tree() or not is_instance_valid(previous): return
			if get_viewport().gui_get_focus_owner() != null: return
		if previous.disabled: previous = find_child("PreparationTab" + TABS[active_tab], true, false) as BaseButton
		if previous != null: previous.grab_focus()

## ---- Onglet « Dossier adverse » ---------------------------------------------------------------------

## Construit le dossier (ou la sous-page demandée) et renvoie sa hauteur en unités du gabarit.
func _dossier() -> float:
	var section := _section("PreparationDossier")
	match str(state.get("sub", "")):
		"reperes": return _sous_reperes(section)
		"conseils": return _sous_conseils(section)
		"xv": return _sous_xv(section)
		"planning", "reprise": return _sous_externe(section, str(state.get("sub", "")))
	var opponent := _opponent()
	var haut := 0.0
	if reports.is_empty():
		var vide := _panneau(section, Rect2(0, 0, 1344, 540), "Dossier adverse", "PreparationUnknownOpponent")
		if not opponent.is_empty():
			_crest(vide, opponent, Rect2(30, 90, 92, 94))
			# Nom cliquable : fiche du club adverse.
			Link.name_link(app, vide, C.reach_rect(Rect2(146, 98, 1130, 50)), "club", str(int(opponent.get("id", -1))) if opponent.get("id") != null else "", G.club_name(opponent), 42, Charte.IVOIRE, "PreparationKnownOpponent")
			_etiquette(vide, 150, 176, "Adversaire annoncé au calendrier", 1130)
		var champ_preparing := fixture.is_empty() and SeasonPreparation.is_champ(app.model.meta) and not SeasonPreparation.data(app.model.meta).is_empty()
		var lines := D.words(CHAMP_DOSSIER_PENDING if champ_preparing else "Aucun dossier disponible pour cette rencontre.", 86, 3)
		for line in lines.size(): _texte(vide, 29, 252 + line * 34, lines[line], 26, Charte.IVOIRE, 1270)
		_texte(vide, 29, 340, "Les résultats récents, les notes et les joueurs adverses seront affichés", 20, Charte.IVOIRE_2, 1270)
		_texte(vide, 29, 372, "lorsque ces informations seront publiées.", 20, Charte.IVOIRE_2, 1270)
		_bouton(vide, Rect2(24, 460, 420, 50), "Voir le calendrier", func(): app._navigate("Calendrier"), "lien", "calendar", "PreparationOpenCalendar")
		_a_faire(section, Rect2(1361, 0, 887, 540))
		haut = 556.0
	else:
		_danger(section, Rect2(0, 0, 2248, 68))
		# Gabarit 1080p sans défilement (recette immersive08) : danger 76, rapport + repères ~440, forme + surveillés ~254, XV ~196.
		var hauteur_rapport := maxf(108.0 + 6.0 * _pas_rapport() + 44.0, 56.0 + 5.0 * C.reach(62.0) + 82.0)
		_rapport(section, Rect2(0, 82, 1344, hauteur_rapport))
		_a_faire(section, Rect2(1361, 82, 887, hauteur_rapport))
		haut = 82.0 + hauteur_rapport + 14.0
		var hauteur_bas := _forme(section, Rect2(0, haut, 900, 0))
		_surveiller(section, Rect2(916, haut, 1332, hauteur_bas))
		haut += hauteur_bas + 14.0
	if not opponent.is_empty(): haut += _xv_bande(section, Rect2(0, haut, 2248, 0), opponent)
	return haut

## Bandeau « Danger » : la menace principale, lue dans les vrais chiffres du dossier ; le plan conseillé mène aux conseils.
func _danger(section: Control, rectangle: Rect2) -> void:
	var bande := Panel.new()
	bande.name = "PreparationDanger"
	bande.add_theme_stylebox_override("panel", Charte.ombrer_droit(_style(Charte.PANNEAU)))
	section.add_child(bande)
	D.place(bande, rectangle)
	_barre(bande, Rect2(0, 0, 6, rectangle.size.y), Charte.club_trait(app.accent))
	_etiquette(bande, 28, 46, "Danger", 110)
	var texte := _texte(bande, 140, 48, _danger_phrase(), 24, Charte.IVOIRE, 1340)
	texte.name = "PreparationDangerText"
	var conseil: Dictionary = reports.get("advice", {})
	if not conseil.is_empty():
		var tactiques: Dictionary = app.model.get("tactics", {})
		var plan := "Plan conseillé : %s · %s" % [_tactic_label(tactiques.get("attacks", []), conseil.get("attack")), _tactic_label(tactiques.get("defenses", []), conseil.get("defence"))]
		_bouton(bande, Rect2(1520, 13, 708, 50), plan, func(): _ouvrir_sous("conseils"), "lien", "arrow", "PreparationPlanLink")

func _danger_phrase() -> String:
	for signal_row: Dictionary in reports.get("signals", []):
		if signal_row.get("kind") == "warning": return "%s — %s" % [str(signal_row.get("title", "")), str(signal_row.get("evidence", ""))]
	var pire := {}
	var ecart := 0
	for domaine: Dictionary in reports.get("domains", []):
		if not (_nombre(domaine.get("own")) and _nombre(domaine.get("opponent"))): continue
		var difference := int(domaine.opponent) - int(domaine.own)
		if difference > ecart:
			ecart = difference
			pire = domaine
	if not pire.is_empty():
		return "Leur avantage le plus net : %s, %d contre %d pour toi (−%d)." % [str(pire.get("label", "secteur")).to_lower(), int(pire.opponent), int(pire.own), ecart]
	if not reports.get("domains", []).is_empty(): return "Aucun secteur ne penche en leur faveur : tu égales ou tu domines partout."
	var menaces: Array = reports.get("threats", [])
	if not menaces.is_empty(): return "À surveiller : %s (%s)." % [str(menaces[0].get("name", "")), str(menaces[0].get("role", ""))]
	return "Pas de danger précis relevé dans les observations disponibles."

const SECTEURS := {"scrum":"comp", "lineout":"comp", "power":"train", "backs":"plan", "kick":"plan", "discipline":"train"}
const DESTINATIONS := {"comp":"Composition", "plan":"Plan de jeu", "train":"Entraînement"}
const ICONES_ACTION := {"comp":"people", "plan":"tactic", "train":"train"}

func _agir(code: String) -> void:
	match code:
		"comp": app._navigate("Composition")
		"plan": app._navigate("Plan de jeu")
		"train": _choose(2)

## Rapport de force : nous (plein) face à eux (anneau), chiffres écrits, écart en mots ; chaque ligne mène à l'écran d'action.
## Pas des lignes du rapport de force : en petite fenêtre, assez haut pour le secteur et son action écrits l'un sous l'autre.
func _pas_rapport() -> float:
	return maxf(C.reach(44.0), 62.0) if C.dense() else C.reach(44.0)

func _rapport(section: Control, rectangle: Rect2) -> void:
	var domaines: Array = reports.get("domains", [])
	var pas := maxf(_pas_rapport(), (rectangle.size.y - 152.0) / 6.0)
	var panneau := _panneau(section, rectangle, "Rapport de force", "PreparationComparison")
	R.rond(panneau, 20 + R.largeur("RAPPORT DE FORCE", 26, 800) + 16, 31, "Évaluations sur 100, ajustées à la condition.\nÉcart « pour toi » ou « contre toi ».\nClic sur un secteur : composition, plan de jeu ou entraînement.", "i", "PreparationComparisonInfo")
	var nous: Dictionary = app.model.club
	var eux := _opponent()
	for i in 2:
		var club: Dictionary = nous if i == 0 else eux
		var couleur := _couleur_club(club, i == 0)
		var lisere: Color = Charte.club_trait(couleur if couleur.a > 0.0 else Charte.CLUB)
		var x := 24.0 if i == 0 else 1344.0 - 24.0 - 360.0
		var plaque := Panel.new()
		plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plaque.name = "PreparationTagUs" if i == 0 else "PreparationTagThem"
		plaque.add_theme_stylebox_override("panel", _style(Color(lisere, .28), Color.TRANSPARENT) if i == 0 else _style(Color.TRANSPARENT, lisere, 2))
		panneau.add_child(plaque)
		D.place(plaque, Rect2(x, 60, 360, 38))
		if i == 0: _barre(panneau, Rect2(x, 60, 6, 38), lisere)
		if club.get("id") != null and Link.available(app, "club", str(int(club.get("id")))):
			_zone(panneau, C.reach_rect(Rect2(x, 60, 360, 38)), _ouvrir_club.bind(club), "PreparationTagZone" + ("Us" if i == 0 else "Them"), "Ouvrir la fiche · " + G.club_name(club))
		var nom := G.club_name(club)
		var lien := Link.name_link(app, panneau, C.reach_rect(Rect2(x + 14, 60, 250, 38)), "club", str(int(club.get("id", -1))) if club.get("id") != null else "", nom.to_upper(), 21, Charte.IVOIRE, "PreparationOwnLink" if i == 0 else "PreparationOpponentLink")
		if lien is Label: (lien as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_texte(panneau, x + 346, 86, "nous" if i == 0 else "eux", 17, Charte.IVOIRE_2, 80, HORIZONTAL_ALIGNMENT_RIGHT)
	if domaines.is_empty():
		_texte(panneau, 28, 190, "La comparaison par secteur n’est pas disponible.", 22, Charte.IVOIRE_2, 1270)
	var echelle := 330.0
	for i in domaines.size():
		var domaine: Dictionary = domaines[i]
		var y := 108.0 + pas * i
		var code: String = SECTEURS.get(str(domaine.get("key", "")), "")
		var libelle := str(domaine.get("label", "Secteur"))
		if i % 2 == 1: _barre(panneau, Rect2(0, y, 1344, pas - 2), Charte.PANNEAU_2)
		if not code.is_empty():
			var destination: String = DESTINATIONS[code]
			_zone(panneau, Rect2(0, y, 1344, pas), _agir.bind(code), "PreparationSector_" + str(domaine.get("key", i)), "%s : agir dans « %s »" % [libelle, destination])
		var centre := y + pas / 2.0
		var propre: Variant = domaine.get("own")
		var adverse: Variant = domaine.get("opponent")
		_titre(panneau, 24, centre + 11, G.n(propre) if _nombre(propre) else "—", 32, Charte.IVOIRE, 70)
		if _nombre(propre): _barre(panneau, Rect2(430.0 - echelle * clampf(float(propre) / 100.0, 0, 1), centre - 7, echelle * clampf(float(propre) / 100.0, 0, 1), 14), Charte.VERT_CLAIR)
		_texte(panneau, 590, centre + 7, libelle, 20, Charte.IVOIRE, 300, HORIZONTAL_ALIGNMENT_CENTER).add_theme_font_override("font", Charte.TITRE_GRAS)
		if not code.is_empty():
			# Une icône dit l'écran d'action (la ligne entière est cliquable ; le nom de l'écran est dans l'infobulle).
			var outil := C.icon(ICONES_ACTION[code], 20, Charte.IVOIRE_2)
			outil.name = "PreparationSectorIcon_" + str(domaine.get("key", i))
			panneau.add_child(outil)
			D.place(outil, Rect2(590 + R.largeur(libelle, 20) / 2.0 + 14, centre - 10, 20, 20))
		if _nombre(adverse): _barre(panneau, Rect2(750, centre - 7, echelle * clampf(float(adverse) / 100.0, 0, 1), 14), R.ORANGE).name = "PreparationBarreAdverse" + str(i)
		_titre(panneau, 1090, centre + 11, G.n(adverse) if _nombre(adverse) else "—", 32, Charte.IVOIRE, 70)
		if _nombre(propre) and _nombre(adverse):
			var delta := int(propre) - int(adverse)
			var mot := "+%d pour toi" % delta if delta > 0 else "−%d contre toi" % -delta if delta < 0 else "égalité"
			var couleur_delta: Color = R.VERT if delta > 0 else R.ROUGE if delta < 0 else Charte.N
			_marque(panneau, 1168, centre, 16, "haut" if delta > 0 else "bas" if delta < 0 else "egal", couleur_delta)
			_texte(panneau, 1194, centre + 7, mot, 19, couleur_delta, 140).add_theme_font_override("font", C.font(700))


## À faire avant le match : une ligne cliquable par repère, mêmes vraies données qu'avant.
func _a_faire(section: Control, rectangle: Rect2) -> void:
	var briefing := Briefing.project(app.model)
	var verifs: Array = briefing.checks
	var en_ordre := verifs.filter(func(check: Dictionary): return check.level == "info").size()
	var panneau := _panneau(section, rectangle, "À faire avant le match", "PreparationRecommendation", "%d sur %d en ordre" % [en_ordre, verifs.size()])
	var pas := C.reach(62.0)
	var limite := mini(verifs.size(), 5)
	for index in limite:
		var check: Dictionary = verifs[index]
		var y := 56.0 + pas * index
		if index % 2 == 1: _barre(panneau, Rect2(0, y, rectangle.size.x, pas - 2), Charte.PANNEAU_2)
		var zone := _zone(panneau, Rect2(0, y, rectangle.size.x, pas - 2), Briefing.open_action.bind(app, check.action, _choose.bind(1)), "PreparationBriefing_" + str(check.id), check.detail + "\n" + check.caption)
		zone.accessibility_name = check.title + " · " + check.detail
		# Repère en pastille ✓ / ! + deux mots (21/11) : le titre et le détail restent dans l'infobulle de la ligne.
		var grave: bool = check.level in ["urgent", "important"]
		var teinte: Color = R.ROUGE if check.level == "urgent" else R.ORANGE if check.level == "important" else R.VERT
		_etiquette(panneau, 22, y + pas / 2.0 + 5, str(REPERES.get(str(check.id), "REPÈRE")), 150)
		R.pastille(panneau, 190, y + pas / 2.0 + 7, _repere_court(check), teinte, "warning" if grave else "check", "PreparationBriefingTitle_" + str(check.id), 18).tooltip_text = str(check.title) + " · " + str(check.detail)
		_texte(panneau, rectangle.size.x - 52, y + pas / 2.0 + 5, str(check.caption), 16, Charte.IVOIRE, 215, HORIZONTAL_ALIGNMENT_RIGHT)
		_marque(panneau, rectangle.size.x - 40, y + pas / 2.0, 14, "droite", Charte.IVOIRE_2)
	var pied := 56.0 + pas * limite + 10.0
	var tous := _bouton(panneau, Rect2(14, pied, 330, 44), "Tous les repères (%d)" % verifs.size(), func(): _ouvrir_sous("reperes"), "lien", "", "PreparationBriefingAll")
	tous.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var conseil: Dictionary = reports.get("advice", {})
	var detail := _bouton(panneau, Rect2(350, pied, 250, 44), "Conseils détaillés", func(): _ouvrir_sous("conseils"), "lien", "arrow", "OpenOppositionDossier")
	detail.disabled = reports.is_empty()
	var adopte := _plan_adopte(conseil)
	var adopter := _bouton(panneau, Rect2(rectangle.size.x - 14 - 280, pied, 280, 44), "Plan du staff adopté" if adopte else "Adopter le plan du staff", func(): app._command("set_tactics", {"attack":conseil.attack, "defense":conseil.defence}), "lien", "check" if adopte else "arrow", "PreparationAdoptPlan")
	adopter.disabled = adopte or conseil.is_empty() or not app._live().is_empty() or app.model.meta.get("phase") == "ended"

## Les consignes en place sont déjà celles du plan conseillé par le staff.
func _plan_adopte(conseil: Dictionary) -> bool:
	var tactiques: Dictionary = app.model.get("tactics", {})
	return not conseil.is_empty() and tactiques.get("attack") == conseil.get("attack") and tactiques.get("defense") == conseil.get("defence")

## Deux mots pour un repère : « Jour J », « 2 blessés », « Feuille OK », « 15 h 00 », « Consignes OK »…
func _repere_court(check: Dictionary) -> String:
	match str(check.id):
		"day": return "Jour J"
		"injuries": return str(check.title).get_slice(" ", 0) + " blessé" + ("s" if str(check.title).get_slice(" ", 0) != "1" else "")
		"sheet": return "Feuille OK"
		"selection": return "Feuille incomplète"
		"tactics": return "Consignes OK"
		"press": return "Presse"
		"international":
			var nombre := RegEx.create_from_string("^(\\d+)").search(str(check.detail))
			return (nombre.get_string(1) + " absents") if nombre != null else "Absences"
		"calendar":
			var heure := RegEx.create_from_string("(\\d{1,2}):(\\d{2})").search(str(check.detail))
			return ("%s h %s" % [heure.get_string(1), heure.get_string(2)]) if heure != null else "À vérifier"
		"live": return "Résultat" if str(check.title).begins_with("Résultat") else "En cours"
		"ended": return "Saison close"
	return str(check.title)

const REPERES := {"press":"PRESSE", "selection":"FEUILLE", "day":"JOUR J", "international":"ABSENCES", "injuries":"INFIRMERIE", "sheet":"FEUILLE", "calendar":"RENDEZ-VOUS", "tactics":"CONSIGNES", "live":"MATCH", "ended":"SAISON"}

## Résultat V / N / D de l'adversaire pour une rencontre listée (point de vue du club adverse).
func _issue(resultat: Dictionary) -> String:
	var score: Array = resultat.get("score", [])
	if score.size() != 2: return ""
	var cote := int(resultat.get("side", 0))
	var nous := int(score[cote])
	var eux := int(score[1 - cote])
	return "V" if nous > eux else "D" if nous < eux else "N"

## Forme récente : pastilles V/N/D, derniers résultats cliquables, confrontations directes. Renvoie la hauteur.
func _forme(section: Control, rectangle: Rect2) -> float:
	var recent: Array = reports.get("recent", [])
	var pas := C.reach(26.0)
	var hauteur := 100.0 + 4.0 * pas + 44.0
	var panneau := _panneau(section, Rect2(rectangle.position, Vector2(rectangle.size.x, hauteur)), "Forme récente", "PreparationRecent", "%d résultat%s observé%s" % [recent.size(), "s" if recent.size() > 1 else "", "s" if recent.size() > 1 else ""] if not recent.is_empty() else "")
	var adversaire := _opponent()
	var nom := G.club_name(adversaire)
	Link.name_link(app, panneau, C.reach_rect(Rect2(20, 54, 250, 36)), "club", str(int(adversaire.get("id", -1))) if adversaire.get("id") != null else "", nom.to_upper(), 19, Charte.IVOIRE, "PreparationFormClub")
	var issues: Array[String] = []
	for i in mini(5, recent.size()):
		var issue := _issue(recent[i])
		if issue.is_empty(): continue
		issues.append(issue)
		var pastille := _pastille(panneau, Rect2(290 + (issues.size() - 1) * 48, 58, 40, 28), issue, "PreparationOpponentForm%d" % (issues.size() - 1))
		if Link.available(app, "club", str(int(adversaire.get("id", -1)))):
			var cible := _zone(panneau, C.reach_rect(Rect2(290 + (issues.size() - 1) * 48, 58, 40, 28)), _ouvrir_club.bind(adversaire), "PreparationOpponentFormZone%d" % (issues.size() - 1), "Résultats de %s : ouvrir sa fiche" % nom)
			cible.move_to_front()
			pastille.move_to_front()
	if not issues.is_empty():
		_texte(panneau, 880, 80, "%d V · %d N · %d D" % [issues.count("V"), issues.count("N"), issues.count("D")], 17, Charte.IVOIRE_2, 300, HORIZONTAL_ALIGNMENT_RIGHT)
	if recent.is_empty():
		_texte(panneau, 24, 130, "Résultats adverses non publiés dans ce dossier." if reports.is_empty() else "Aucun résultat adverse enregistré cette saison.", 19, Charte.IVOIRE_2, 850)
	for i in mini(4, recent.size()):
		var resultat: Dictionary = recent[i]
		var score: Array = resultat.get("score", [])
		var cote := int(resultat.get("side", 0))
		var autre := _club(resultat.get("opponentId"))
		var y := 100.0 + pas * i
		var etape := "J" + G.n(int(resultat.get("round", 0)) + 1) if resultat.get("phase") == "league" else str(resultat.get("phase", ""))
		if i % 2 == 0: _barre(panneau, Rect2(0, y, 900, pas - 2), Charte.PANNEAU_2)
		if autre.get("id") != null and Link.available(app, "club", str(int(autre.get("id")))):
			_zone(panneau, Rect2(0, y, 900, pas), _ouvrir_club.bind(autre), "PreparationFormRow%d" % i, "%s · %s : ouvrir la fiche de %s" % [etape, G.club_name(autre), G.club_name(autre)])
		_texte(panneau, 24, y + pas / 2.0 + 6, etape, 16, Charte.IVOIRE_2, 110)
		Link.name_link(app, panneau, Rect2(130, y, 420, pas), "club", str(int(autre.get("id", -1))) if autre.get("id") != null else "", G.club_name(autre), 18, Charte.IVOIRE, "PreparationFormOpponent%d" % i)
		_titre(panneau, 700, y + pas / 2.0 + 8, "%s–%s" % [G.n(score[cote]), G.n(score[1 - cote])] if score.size() == 2 else "—", 24, Charte.IVOIRE, 120, HORIZONTAL_ALIGNMENT_RIGHT)
		_texte(panneau, 840, y + pas / 2.0 + 6, "dom." if cote == 0 else "ext.", 16, Charte.IVOIRE_2, 54, HORIZONTAL_ALIGNMENT_RIGHT)
	_face_a_face(panneau, 100.0 + 4.0 * pas + 8.0)
	return hauteur

## Confrontations directes (cinq dernières rencontres entre les deux clubs) : pastilles V/N/D et dernier score.
func _face_a_face(panneau: Panel, y: float) -> void:
	var lignes: Array = reports.get("headToHead", [])
	var issues: Array[String] = []
	for i in mini(5, lignes.size()):
		var issue := _issue(lignes[i])
		if not issue.is_empty(): issues.append(issue)
	_etiquette(panneau, 24, y + 24, "Face à eux")
	var adversaire := _opponent()
	var ouvrable := adversaire.get("id") != null and Link.available(app, "club", str(int(adversaire.get("id"))))
	if issues.is_empty():
		var aucune := R.tuile(panneau, C.reach_rect(Rect2(150, y - 2, 250, 36)), "0", "confrontation", Charte.IVOIRE, "PreparationHeadToHeadNone", 26)
		if ouvrable: R.cliquable(aucune, _ouvrir_club.bind(adversaire), "PreparationHeadToHeadNoneOuvrir", "Fiche de " + G.club_name(adversaire))
		return
	if ouvrable:
		_zone(panneau, C.reach_rect(Rect2(0, y - 4, 900, 40)), _ouvrir_club.bind(adversaire), "PreparationHeadToHeadRow", "Confrontations avec %s : ouvrir sa fiche" % G.club_name(adversaire))
		_texte(panneau, 880, y + 26, "Plus", 17, Charte.IVOIRE, 60, HORIZONTAL_ALIGNMENT_RIGHT).add_theme_font_override("font", C.font(700))
	var dernier: Array = lignes[0].get("score", [])
	var cote := int(lignes[0].get("side", 0))
	var lieu := "à domicile" if bool(lignes[0].get("home", cote == 0)) else "à l’extérieur"
	for i in issues.size(): _pastille(panneau, Rect2(150 + i * 44, y + 4, 38, 28), issues[i], "PreparationHeadToHead%d" % i)
	_texte(panneau, 150 + issues.size() * 44 + 12, y + 26, "%d V · %d N · %d D — dernier : %d-%d %s" % [issues.count("V"), issues.count("N"), issues.count("D"), int(dernier[cote]), int(dernier[1 - cote]), lieu], 17, Charte.IVOIRE_2, 560)

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

## Joueurs à surveiller : portrait, nom cliquable, poste, âge, note, rôle.
func _surveiller(section: Control, rectangle: Rect2) -> void:
	var panneau := _panneau(section, rectangle, "Joueurs à surveiller", "PreparationThreats")
	var menaces: Array = reports.get("threats", [])
	var club_id := int(_opponent().get("id", -1))
	var haut_carte := rectangle.size.y - 58.0 - 52.0
	if menaces.is_empty():
		_texte(panneau, 24, 110, "Liste adverse non publiée dans le dossier." if reports.is_empty() else "Aucun joueur projeté à surveiller.", 22, Charte.IVOIRE_2, 1200)
	for i in mini(3, menaces.size()):
		var menace: Dictionary = menaces[i]
		var x := 20.0 + i * 436.0
		var carte := Panel.new()
		carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carte.name = "PreparationThreat%d" % i
		carte.add_theme_stylebox_override("panel", Charte.ombrer_droit(_style(Charte.PANNEAU_2)))
		panneau.add_child(carte)
		D.place(carte, Rect2(x, 58, 420, haut_carte))
		if _joueur_ouvrable(menace, club_id): _zone_joueur(carte, Rect2(0, 0, 420, haut_carte), menace, club_id, "PreparationThreatCard%d" % i)
		if not str(menace.get("id", "")).is_empty():
			var portrait := G.portrait(0, 0, menace)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			carte.add_child(portrait)
			D.place(portrait, Rect2(8, 8, 104, haut_carte - 16))
		else:
			var neutre := C.icon("people", 48, Charte.IVOIRE_3)
			carte.add_child(neutre)
			D.place(neutre, Rect2(32, 40, 48, 48))
		_lien_joueur(carte, Rect2(122, 4, 212, 34), menace, 21, "PreparationThreatName%d" % i, club_id)
		var age := "  ·  %d ans" % int(menace.get("age", 0)) if _nombre(menace.get("age")) else ""
		_texte(carte, 126, 60, "%s%s" % [str(menace.get("pos", "")), age], 16, Charte.IVOIRE_2, 205)
		var note: Variant = menace.get("note")
		# Danger du joueur (les étoiles ont été rejetées par Léo le 21/11/2026) : sa note au poste en chiffre si elle est
		# connue, sinon la fourchette de niveau publiée par le recrutement, sinon « ? » non observé ; pastille colorée par
		# paliers, chiffre ou mot toujours écrit.
		var fourchette := Savoir.bounds(menace, "rating")
		var valeur := ""
		var legende := "Au poste"
		var fond := Charte.PANNEAU_3
		var encre := Charte.IVOIRE_2
		if _nombre(note):
			valeur = str(roundi(float(note)))
			fond = Charte.couleur_attribut(note)
			encre = Charte.ENCRE
		elif not fourchette.is_empty():
			valeur = "%d–%d" % [roundi(float(fourchette.min)), roundi(float(fourchette.max))]
			legende = "Niveau"
			fond = Charte.couleur_attribut((float(fourchette.min) + float(fourchette.max)) / 2.0)
			encre = Charte.ENCRE
		else:
			valeur = "?"
			legende = "Non observé"
		var large := 68.0 if valeur.length() <= 3 else 92.0
		var pastille := D.rect(carte, Rect2(408 - large, 12, large, 38), fond, Charte.RAYON_PILULE)
		pastille.name = "PreparationThreatLevel%d" % i
		pastille.set_meta("valeur", valeur)
		if _nombre(note): pastille.set_meta("note", roundi(float(note)))
		var chiffre := D.text(pastille, large / 2.0, 28, valeur, 24 if large < 80 else 20, encre, 700, large, HORIZONTAL_ALIGNMENT_CENTER)
		chiffre.name = "Chiffre"
		_etiquette(carte, 408 - large / 2.0, 72, legende, 110, HORIZONTAL_ALIGNMENT_CENTER).name = "PreparationThreatLevelLabel%d" % i
		_texte(carte, 126, 112, str(menace.get("role", "")), 16, Charte.IVOIRE, 285)
		if _nombre(menace.get("fitness")) and not C.dense(): _texte(carte, 126, 130, "Condition %d %%" % int(menace.fitness), 15, Charte.IVOIRE_2, 285)
	var signaux: Array = reports.get("signals", [])
	var phrase := ("%d signa%s" % [signaux.size(), "ux" if signaux.size() > 1 else "l"]) if not signaux.is_empty() else "Non observé" if reports.is_empty() else "—"
	if signaux.is_empty():
		# Rien à ouvrir : simple constat, sans flèche ni lien.
		_texte(panneau, 24, rectangle.size.y - 20, phrase, 18, Charte.IVOIRE_2, 1200)
	else:
		var fin := _bouton(panneau, Rect2(14, rectangle.size.y - 48, 260, 44), phrase, func(): _ouvrir_sous("conseils"), "lien", "arrow", "PreparationSignalsLink")
		fin.tooltip_text = "Signaux relevés : détails dans les conseils"
		fin.alignment = HORIZONTAL_ALIGNMENT_LEFT

## Leur XV probable, en bande de quinze cases : numéro, nom (fiche), poste, remarque de l'adjoint ; le tableau complet est une sous-page.
func _xv_bande(section: Control, rectangle: Rect2, adversaire: Dictionary) -> float:
	var club_id := int(adversaire.get("id", -1))
	var donnees: Dictionary = ClubSheet.cached(app, club_id) if club_id >= 0 else {}
	if donnees.is_empty():
		var attente := _panneau(section, Rect2(rectangle.position, Vector2(rectangle.size.x, 110)), "Leur XV probable", "PreparationTheirXI")
		_texte(attente, 24, 90, "Le XV probable de %s se prépare…" % G.club_name(adversaire), 20, Charte.IVOIRE_2, 1500)
		if club_id >= 0: ClubSheet.request(app, club_id)
		return 110.0
	var xv: Dictionary = donnees.get("xv", {})
	var effectif := {}
	for joueur: Dictionary in donnees.get("squad", []): effectif[str(joueur.get("id", ""))] = joueur
	var menaces := {}
	for menace: Dictionary in reports.get("threats", []): menaces[str(menace.get("id", ""))] = str(menace.get("role", ""))
	var adjoint := _adjoint()
	var hauteur_case := 140.0
	var hauteur := 56.0 + hauteur_case + 12.0
	var panneau := _panneau(section, Rect2(rectangle.position, Vector2(rectangle.size.x, hauteur)), "Leur XV probable", "PreparationTheirXI")
	var tableau := "Tableau détaillé · remarques de %s" % str(adjoint.get("name", "")) if not adjoint.is_empty() else "Tableau détaillé · remarques du staff"
	_bouton(panneau, Rect2(rectangle.size.x - 20 - 760, 6, 760, 44), tableau, func(): _ouvrir_sous("xv"), "lien", "arrow", "PreparationTheirXIAll")
	_marque(panneau, rectangle.size.x - 20 - 760 - 200, 28, 14, "losange", Charte.IVOIRE)
	_texte(panneau, rectangle.size.x - 20 - 760 - 178, 34, "à surveiller", 16, Charte.IVOIRE_2, 170)
	var largeur := 135.0
	for index in 15:
		var emplacement: Dictionary = {}
		for candidat: Dictionary in xv.get("slots", []):
			if int(candidat.get("jersey", 0)) == index + 1: emplacement = candidat
		var joueur: Dictionary = effectif.get(str(emplacement.get("id", "")), {})
		var x := 14.0 + index * (largeur + 14.0)
		var cellule := Panel.new()
		cellule.name = "PreparationTheirXICell%d" % (index + 1)
		cellule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cellule.add_theme_stylebox_override("panel", Charte.ombrer_droit(_style(Charte.PANNEAU_2)))
		panneau.add_child(cellule)
		D.place(cellule, Rect2(x, 56, largeur, hauteur_case))
		if not joueur.is_empty() and _joueur_ouvrable(joueur, club_id): _zone_joueur(cellule, Rect2(0, 0, largeur, hauteur_case), joueur, club_id, "PreparationTheirXICellZone%d" % (index + 1))
		_anneau(cellule, Rect2(8, 6, 40, 26), str(index + 1))
		if joueur.is_empty():
			_texte(cellule, 8, 64, "Non pourvu", 15, Charte.IVOIRE_2, largeur - 12)
			continue
		var menace := str(menaces.get(str(joueur.get("id", "")), ""))
		if not menace.is_empty(): _marque(cellule, largeur - 24, 19, 14, "losange", Charte.IVOIRE)
		var lien := _lien_joueur(cellule, Rect2(2, 34, largeur - 4, 28), joueur, 17, "PreparationTheirXIName_%d" % (index + 1), club_id, PersonName.surname(str(joueur.get("name", ""))))
		lien.set_meta("jersey", index + 1)
		# Poste entier (jamais tronqué) : une ou deux lignes ; la remarque prend les lignes restantes.
		var lignes_poste := D.words(str(joueur.get("pos", "")), 15, 2)
		for ligne in lignes_poste.size(): _texte(cellule, 8, 80 + ligne * 17, lignes_poste[ligne], 15, Charte.IVOIRE_2, largeur - 8)
		var remarque := _remarque(joueur, menace)
		# Dans la case, seule la première remarque tient ; le tableau détaillé donne les deux.
		var lignes_remarque := D.words(str(remarque[0]).split("  ·  ")[0], 17, 4 - lignes_poste.size())
		for ligne in lignes_remarque.size():
			_texte(cellule, 8, 80 + (lignes_poste.size() + ligne) * 17 + 2, lignes_remarque[ligne], 15, Charte.D if remarque[1] else Charte.IVOIRE, largeur - 12)
	return hauteur

## Petit anneau numéroté (cases du XV) : jamais une couleur seule, le numéro est écrit.
func _anneau(parent: Control, rectangle: Rect2, libelle: String) -> void:
	var anneau := Panel.new()
	anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _style(Color.TRANSPARENT, Charte.IVOIRE_2, 2)
	style.set_corner_radius_all(maxi(1, C.px(rectangle.size.y / 2.0)))
	anneau.add_theme_stylebox_override("panel", style)
	parent.add_child(anneau)
	D.place(anneau, rectangle)
	D.text(anneau, rectangle.size.x / 2.0, rectangle.size.y / 2.0 + 6, libelle, 17, Charte.IVOIRE, 700, rectangle.size.x, HORIZONTAL_ALIGNMENT_CENTER)

## « Préparer la suite » et « La reprise » : écrans pleins (aucune fenêtre), contenus des vrais ateliers du jeu.
func _sous_externe(section: Control, sous_page: String) -> float:
	_retour(section)
	var titre := "Préparer la suite du club" if sous_page == "planning" else "La reprise"
	var panneau := _panneau(section, Rect2(0, 66, 2248, 880), titre, "PreparationSub_" + sous_page)
	var hote := Control.new()
	hote.name = "PreparationSubHost"
	hote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panneau.add_child(hote)
	D.place(hote, Rect2(20, 66, 2208, 796))
	if sous_page == "planning": load("res://ui/manager_planning.gd").embed(app, hote)
	else: load("res://ui/reprise_dialog.gd").embed(app, hote)
	return 66.0 + 880.0

func _sous_xv(section: Control) -> float:
	_retour(section)
	var adversaire := _opponent()
	if adversaire.is_empty(): return 70.0
	return 66.0 + _xv_tableau(section, Rect2(0, 66, 2248, 0), adversaire)

## Leur XV probable : tableau des 15 titulaires, note, matchs, essais, et remarque de l'adjoint dérivée des vraies statistiques.
func _xv_tableau(section: Control, rectangle: Rect2, adversaire: Dictionary) -> float:
	var club_id := int(adversaire.get("id", -1))
	var donnees: Dictionary = ClubSheet.cached(app, club_id) if club_id >= 0 else {}
	var pas := C.reach(34.0)
	var adjoint := _adjoint()
	var legende := "Remarques de %s" % str(adjoint.get("name", "")) if not adjoint.is_empty() else "Remarques du staff"
	if donnees.is_empty():
		var attente := _panneau(section, Rect2(rectangle.position, Vector2(rectangle.size.x, 150)), "Leur XV probable", "PreparationTheirXITable")
		_texte(attente, 24, 100, "Le XV probable de %s se prépare…" % G.club_name(adversaire), 22, Charte.IVOIRE_2, 1500)
		if club_id >= 0: ClubSheet.request(app, club_id)
		return 150.0
	var xv: Dictionary = donnees.get("xv", {})
	var effectif := {}
	for joueur: Dictionary in donnees.get("squad", []): effectif[str(joueur.get("id", ""))] = joueur
	var menaces := {}
	for menace: Dictionary in reports.get("threats", []): menaces[str(menace.get("id", ""))] = str(menace.get("role", ""))
	var hauteur := 100.0 + 15.0 * pas + 92.0
	var panneau := _panneau(section, Rect2(rectangle.position, Vector2(rectangle.size.x, hauteur)), "Leur XV probable", "PreparationTheirXITable", "Entrée sur un joueur : sa fiche · losange : à surveiller")
	var colonnes := [["N°", 24.0, 60.0, HORIZONTAL_ALIGNMENT_RIGHT], ["Joueur", 108.0, 420.0, HORIZONTAL_ALIGNMENT_LEFT], ["Poste", 548.0, 300.0, HORIZONTAL_ALIGNMENT_LEFT], ["Âge", 850.0, 70.0, HORIZONTAL_ALIGNMENT_RIGHT], ["Matchs", 1030.0, 90.0, HORIZONTAL_ALIGNMENT_RIGHT], ["Titul.", 1130.0, 90.0, HORIZONTAL_ALIGNMENT_RIGHT], ["Essais", 1230.0, 90.0, HORIZONTAL_ALIGNMENT_RIGHT], ["Note moy.", 1330.0, 110.0, HORIZONTAL_ALIGNMENT_RIGHT]]
	# Le niveau n'est affiché que si le staff le connaît (données de la fiche du club) : jamais une colonne de tirets.
	var niveau_connu: bool = effectif.values().any(func(p: Dictionary): return _nombre(p.get("rating")))
	if niveau_connu: colonnes.insert(4, ["Niveau", 930.0, 90.0, HORIZONTAL_ALIGNMENT_RIGHT])
	for colonne: Array in colonnes:
		var gauche: float = colonne[1] + (colonne[2] if colonne[3] == HORIZONTAL_ALIGNMENT_RIGHT else 0.0)
		_etiquette(panneau, gauche, 86, str(colonne[0]), colonne[2], colonne[3])
	_etiquette(panneau, 1480, 86, "Remarque de ton adjoint" if not adjoint.is_empty() else "Remarque du staff", 740)
	for index in 15:
		var emplacement: Dictionary = {}
		for candidat: Dictionary in xv.get("slots", []):
			if int(candidat.get("jersey", 0)) == index + 1: emplacement = candidat
		var joueur: Dictionary = effectif.get(str(emplacement.get("id", "")), {})
		var y := 100.0 + pas * index
		var centre := y + pas / 2.0
		if index % 2 == 1: _barre(panneau, Rect2(0, y, rectangle.size.x, pas - 2), Charte.PANNEAU_2)
		_titre(panneau, 84, centre + 9, str(index + 1), 24, Charte.IVOIRE_2, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		if joueur.is_empty():
			_texte(panneau, 108, centre + 7, "Poste non pourvu", 18, Charte.IVOIRE_2, 420)
			continue
		var menace := str(menaces.get(str(joueur.get("id", "")), ""))
		if not menace.is_empty(): _marque(panneau, 6, centre, 12, "losange", Charte.IVOIRE)
		var nom := _lien_joueur(panneau, Rect2(108, y, 420, pas), joueur, 19, "PreparationTheirXIName_%d" % (index + 1), club_id)
		nom.set_meta("jersey", index + 1)
		_texte(panneau, 548, centre + 7, str(joueur.get("pos", "")), 17, Charte.IVOIRE_2, 300)
		_texte(panneau, 920, centre + 7, G.n(joueur.get("age")) if _nombre(joueur.get("age")) else "—", 18, Charte.IVOIRE_2, 70, HORIZONTAL_ALIGNMENT_RIGHT)
		var niveau: Variant = joueur.get("rating")
		if niveau_connu: _texte(panneau, 1020, centre + 7, G.n(niveau) if _nombre(niveau) else "—", 19, Charte.couleur_attribut(niveau), 90, HORIZONTAL_ALIGNMENT_RIGHT).add_theme_font_override("font", C.font(700))
		_texte(panneau, 1120, centre + 7, str(int(joueur.get("matches", 0))), 18, Charte.IVOIRE, 90, HORIZONTAL_ALIGNMENT_RIGHT)
		_texte(panneau, 1220, centre + 7, str(int(emplacement.get("starts", joueur.get("starts", 0)))), 18, Charte.IVOIRE, 90, HORIZONTAL_ALIGNMENT_RIGHT)
		_texte(panneau, 1320, centre + 7, str(int(joueur.get("tries", 0))), 18, Charte.IVOIRE, 90, HORIZONTAL_ALIGNMENT_RIGHT)
		var moyenne: Variant = joueur.get("average")
		_texte(panneau, 1440, centre + 7, ("%.1f" % float(moyenne)).replace(".", ",") if _nombre(moyenne) else "—", 18, Charte.IVOIRE, 110, HORIZONTAL_ALIGNMENT_RIGHT)
		var remarque := _remarque(joueur, menace)
		if not str(remarque[0]).is_empty():
			var ligne := _texte(panneau, 1480, centre + 7, str(remarque[0]), 17, Charte.D if remarque[1] else Charte.IVOIRE, 740)
			ligne.name = "PreparationTheirXIRemark_%d" % (index + 1)
	var bas := 100.0 + 15.0 * pas + 38.0
	_etiquette(panneau, 24, bas, "Banc probable")
	var banc: Array = xv.get("bench", [])
	var ids: Array = banc.map(func(e: Dictionary): return str(e.get("id", ""))) if not banc.is_empty() else xv.get("probableBench", [])
	var x := 200.0
	var pose := 0
	for pid: Variant in ids:
		var joueur: Dictionary = effectif.get(str(pid), {})
		if joueur.is_empty() or pose >= 8: continue
		var nom := str(joueur.get("name", ""))
		var largeur := _largeur(nom, 18, true) + 16
		_lien_joueur(panneau, Rect2(x, bas - 26, largeur, 34), joueur, 18, "PreparationTheirBench%d" % pose, club_id)
		x += largeur + 14
		pose += 1
	if not adjoint.is_empty():
		_texte(panneau, 24, hauteur - 14, "Remarques lues dans les statistiques du dossier par", 15, Charte.IVOIRE_2, 520)
		Link.name_link(app, panneau, C.reach_rect(Rect2(520, hauteur - 40, 500, 34)), "staff", str(adjoint.get("id", "")), "%s, %s" % [str(adjoint.get("name", "")), str(adjoint.get("roleLabel", "adjoint")).to_lower()], 17, Charte.IVOIRE, "PreparationAdjointLink")
	else: _texte(panneau, 24, hauteur - 14, legende + " : tirées des statistiques de la saison.", 15, Charte.IVOIRE_2, 1200)
	return hauteur

## Remarque de l'adjoint pour un joueur adverse : disponibilité, rôle signalé par le dossier, puis statistiques ; omise sans donnée.
func _remarque(joueur: Dictionary, menace: String) -> Array:
	var morceaux := PackedStringArray()
	var grave := false
	if int(joueur.get("injury", 0)) > 0:
		morceaux.append("Blessé (%d sem.)" % int(joueur.get("injury", 0)))
		grave = true
	elif int(joueur.get("suspension", 0)) > 0:
		morceaux.append("Suspendu")
		grave = true
	elif joueur.get("onInternationalDuty", false): morceaux.append("En sélection nationale")
	if not menace.is_empty(): morceaux.append(menace)
	var essais := int(joueur.get("tries", 0))
	if essais >= 2: morceaux.append("%d essais cette saison" % essais)
	if int(joueur.get("playerOfMatch", 0)) > 0: morceaux.append("Homme du match × %d" % int(joueur.get("playerOfMatch", 0)))
	var retenus := PackedStringArray()
	for i in mini(2, morceaux.size()): retenus.append(morceaux[i])
	return ["  ·  ".join(retenus), grave]

## ---- Sous-pages du dossier ---------------------------------------------------------------------------

func _retour(section: Control) -> void:
	var retour := _bouton(section, Rect2(0, 0, 560, 50), "←  Retour au dossier adverse", func(): _ouvrir_sous(""), "lien", "", "PreparationSubBack")
	retour.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _sous_reperes(section: Control) -> float:
	_retour(section)
	var verifs: Array = Briefing.project(app.model).checks
	var pas := C.reach(92.0)
	var hauteur := 84.0 + pas * maxi(1, verifs.size()) + 24.0
	var panneau := _panneau(section, Rect2(0, 66, 2248, hauteur), "Avant le coup d’envoi", "PreparationAllChecks", "%d repères" % verifs.size())
	for index in verifs.size():
		var check: Dictionary = verifs[index]
		var y := 64.0 + pas * index
		if index % 2 == 1: _barre(panneau, Rect2(0, y, 2248, pas - 2), Charte.PANNEAU_2)
		var zone := _zone(panneau, Rect2(0, y, 2248, pas - 2), Briefing.open_action.bind(app, check.action, func(): _choose(1)), "PreparationBriefingAll_" + str(check.id), check.detail)
		zone.accessibility_name = check.title + " · " + check.detail
		var grave: bool = check.level in ["urgent", "important"]
		var teinte: Color = Charte.D if check.level == "urgent" else Charte.N if check.level == "important" else Charte.V
		_etiquette(panneau, 70, y + pas / 2.0 + 6, str(REPERES.get(str(check.id), "REPÈRE")), 170)
		# Plus de phrase d'aide (21/11) : pastille ✓ / ! + deux mots, le titre et le détail restent dans l'infobulle.
		R.pastille(panneau, 250, y + pas / 2.0 + 7, _repere_court(check), teinte, "warning" if grave else "check", "PreparationAllChecksTitle_" + str(check.id), 20).tooltip_text = str(check.title) + " · " + str(check.detail)
		_texte(panneau, 2188, y + pas / 2.0 + 7, str(check.caption), 19, Charte.IVOIRE, 420, HORIZONTAL_ALIGNMENT_RIGHT)
		_marque(panneau, 2204, y + pas / 2.0, 14, "droite", Charte.IVOIRE_2)
	return 66.0 + hauteur

## Le plan proposé par le staff : barres du rapport de force, pastilles d'effet (preparation_consignes.gd).
func _sous_conseils(section: Control) -> float:
	return Consignes.conseils(self, section)

## ---- Onglet « Consignes » ----------------------------------------------------------------------------

## Une tuile à schéma de terrain par intention (preparation_consignes.gd).
func _consignes() -> void:
	Consignes.consignes(self)

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
