extends RefCounted
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const SearchPage = preload("res://ui/immersive08/search_canvas.gd")
const Preferences = preload("res://ui/preferences_dialog.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const Raccourcis = preload("res://ui/raccourcis_clavier.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Office = preload("res://ui/immersive08/office.gd")
const OfficeCanvas = preload("res://ui/immersive08/office_canvas.gd")
const SquadCanvas = preload("res://ui/immersive08/squad_canvas.gd")
const SocleEffectif = preload("res://ui/socle/ecran_effectif.gd")
const TacticsCanvas = preload("res://ui/immersive08/tactics_canvas.gd")
const PlayerCanvas = preload("res://ui/immersive08/player_canvas.gd")
const FichePage = preload("res://ui/immersive08/fiche_page.gd")
const Reception = preload("res://ui/immersive08/reception_canvas.gd")
const Training = preload("res://ui/immersive08/training_canvas.gd")
const Academy = preload("res://ui/immersive08/academy_canvas.gd")
const Recruitment = preload("res://ui/immersive08/recruitment_canvas.gd")
const Competition = preload("res://ui/immersive08/competition_canvas.gd")
const MonthCalendar = preload("res://ui/immersive08/month_calendar.gd")
const ClubCanvas = preload("res://ui/immersive08/club_canvas.gd")
const FinanceCanvas = preload("res://ui/immersive08/finance_canvas.gd")
const Preparation = preload("res://ui/immersive08/preparation_canvas.gd")
const Playbook = preload("res://ui/immersive08/playbook_canvas.gd")
const Centre = preload("res://ui/immersive08/centre_canvas.gd")
const Press = preload("res://ui/immersive08/press_canvas.gd")
const Rivalry = preload("res://ui/immersive08/rivalry_canvas.gd")
const ClubSheet = preload("res://ui/immersive08/club_sheet_canvas.gd")
const Locker = preload("res://ui/immersive08/locker_canvas.gd")
const Career = preload("res://ui/immersive08/career_canvas.gd")
const Selections = preload("res://ui/international_view.gd")
const MatchCanvas = preload("res://ui/immersive08/match_canvas.gd")
const MatchCompact = preload("res://ui/immersive08/match_compact.gd")
const G = preload("res://ui/game_skin.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const ClubUI = preload("res://ui/immersive08/club_ui.gd")
## Gabarits riches (référence 2560 × 1440) ouverts dès 1280 × 720 (densité 0,5). Les gabarits sont
## proportionnels (C.px, D.place) et tout texte passe par un plancher de 12 px (C.label, D.text) :
## à 1280 × 720 le plus petit texte rendu fait 12 × 0,977 ≈ 11,7 px (pied de page compris, voir _fit_layout).
## Préparation (Entraînement compris), Plan de jeu et Centre en font partie : sous la densité 0,75, leurs commandes
## serrées gardent une cible d'au moins 25 px de fenêtre (C.reach, C.reach_controls) et se réorganisent au besoin
## (XV en colonnes, repères et vigilance sur des lignes plus hautes). Seul le Calendrier en tableau hors
## Nationale/Champ garde sa page simple. Le Match (avant le coup d'envoi) suit le même seuil RICH_MIN_SIZE ;
## le direct est l'écran contextuel.
const RICH_MIN_SIZE := Vector2i(1280,720)
const RICH_FROM_720P := ["Rivalités","Classements","Finances","Recrutement","Club","Staff","Travail du club","Stratégie",
	"Carrière","Presse","Vestiaire","Formation","Préparation","Plan de jeu","Centre"]

const FOOTER_RISE := 14

const GROUPS = [
	["Bureau", "Bureau", ["Bureau"]],
	["Effectif", "Effectif", ["Effectif", "Vestiaire"]],
	["Tactique", "Composition", ["Composition", "Préparation", "Plan de jeu", "Match"]],
	["Recrutement", "Recrutement", ["Recrutement"]],
	["Club", "Club", ["Club", "Staff", "Travail du club", "Stratégie"]],
	["Finances", "Finances", ["Finances"]],
	["Compétitions", "Classements", ["Classements", "Calendrier", "Rivalités"]],
	["Formation", "Formation", ["Formation", "Centre", "Suivi des jeunes"]],
	["Carrière", "Carrière", ["Carrière"]]
]
const TITLES = {"Bureau":"Ta semaine commence ici.", "Effectif":"Les hommes du projet.", "Composition":"Le XV de départ.", "Préparation":"La semaine se gagne ici.", "Plan de jeu":"Ton identité de jeu.", "Vestiaire":"Un groupe, une ambition.", "Recrutement":"Le prochain renfort.", "Club":"Un club. Un territoire.", "Finances":"Garder une longueur d’avance.", "Classements":"Chaque point compte.", "Calendrier":"Le fil de ta saison.", "Formation":"Le futur porte nos couleurs.", "Centre":"Les chemins de la progression.", "Suivi des jeunes":"Ils grandissent sous nos couleurs.", "Staff":"Le collectif derrière le collectif.", "Travail du club":"Des décisions qui engagent.", "Stratégie":"Construire dans la durée.", "Presse":"La voix du club.", "Rivalités":"Ta place dans le rugby.", "Carrière":"Une carrière à écrire.", "Match":"Le jour de match.", "Recherche":"Un joueur, un club, un écran.", "Réglages":"Ton confort de jeu."}
## Rapport largeur/hauteur maximal de la zone de travail (16:9) ; au-delà, elle est centrée.
const LARGEUR_MAX_RATIO := 16.0/9.0
const COMPACT_ART = {
	"Finances":"finance-hospitality", "Calendrier":"stadium", "Formation":"academy-training",
	"Plan de jeu":"lineout-analysis", "Centre":"academy-training", "Suivi des jeunes":"academy-training", "Préparation":"analysis-room",
	"Recrutement":"scouting", "Classements":"trophy", "Club":"club-forest", "Staff":"mail-staff",
	"Travail du club":"analysis-room", "Stratégie":"club-forest", "Presse":"press-room",
	"Rivalités":"trophy", "Vestiaire":"lockerroom", "Carrière":"entry-ground",
}

static func render(app: Control) -> bool:
	if not app.model.get("club") is Dictionary or app.route in ["Accueil", "Création", "Packs"]: return false
	var window := app.get_window()
	var physical := window.size
	# Une scène se construit aux pixels de la fenêtre. Les changements de taille
	# suivants ajustent son emprise sans détruire les contrôles ni les brouillons.
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if physical.x >= 1280 and physical.y >= 720:
		window.content_scale_size = physical
	C.configure(minf(physical.y,1440),minf(physical.x,2560))
	if app.selected_player.is_empty():app.set_meta("immersive08_full_player",false)
	if is_instance_valid(app.root_content):
		app.remove_child(app.root_content)
		app.root_content.queue_free()
	app.match_screen = null
	app.match_page = null
	app.match_view = null
	app.entry_scroll = null
	app.root_content = Control.new()
	app.root_content.name = "ImmersiveShell"
	app.root_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_child(app.root_content)
	app.move_child(app.root_content, 0)
	var background := ColorRect.new()
	background.color = C.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.root_content.add_child(background)
	# Fond photo très discret de l'écran (banque d'images « fond-* »), sous les panneaux.
	var fond := fond_ecran(app.route, str(app.model.get("meta", {}).get("phase", "")))
	if not fond.is_empty():
		var photo := TextureRect.new()
		photo.name = "ScreenBackdrop"
		photo.texture = BanqueImages.texture(fond)
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		photo.modulate = Color(1, 1, 1, FOND_OPACITE)
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		photo.set_meta("banque_image", fond)
		app.root_content.add_child(photo)
	var layout := Control.new()
	layout.name = "ImmersiveLayout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.root_content.add_child(layout)
	var reference := Vector2(2560,1440)*C.density
	_coque_factor = maxf(.5, _predicted_factor(Vector2(physical), reference))
	_coque_floor = ceili(12.0 / _coque_factor - .001)
	_fit_layout(app.root_content,layout,reference)
	app.root_content.resized.connect(_fit_layout.bind(app.root_content,layout,reference))
	var shell := C.h(0)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_child(shell)
	_sidebar(shell, app)
	var workspace := C.v(0)
	C.fill(workspace, true)
	shell.add_child(workspace)
	_topbar(workspace, app, layout)
	Raccourcis.installer(app)
	var inset := C.margin(32)
	app.workspace_inset = inset
	inset.add_theme_constant_override("margin_top", C.px(22))
	inset.item_rect_changed.connect(app._layout_coach)
	# Les gabarits des écrans sont dessinés pour une zone de travail de 2312 de large (rail de 248) ; le rail de la
	# coque commune en fait 309 : la zone de contenu garde ses gabarits et se met à l'échelle de la place restante
	# (0,974 à 16:9), sans toucher aux mesures du rail ni de la barre haute.
	var stage := Control.new()
	stage.name = "ImmersiveContentStage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(stage, true)
	workspace.add_child(stage)
	stage.add_child(inset)
	stage.resized.connect(_fit_content.bind(stage, inset))
	_fit_content(stage, inset)
	var content := C.v(16)
	content.name = "CareerContent"
	inset.add_child(content)
	var canvas_script := _dedicated_page(app,physical)
	var immersive_match: bool = app.route=="Match" and physical.x>=RICH_MIN_SIZE.x and physical.y>=RICH_MIN_SIZE.y
	var monthly_calendar: bool = app.route=="Calendrier" and not Selections.nation_only(app.model) and not app.get_meta("calendar_table",false)
	if canvas_script!=null or immersive_match or monthly_calendar or (app.route=="Effectif" and app.get_meta("immersive08_full_player",false)):
		app.heading=null
		app.minibar=C.label("",17,C.GOLD);app.minibar.visible=false;content.add_child(app.minibar)
	else: _heading(content, app)
	if app.route=="Bureau":
		layout.set_meta("immersive_office_match_status",app.minibar)
		_position_office_match_status(app.minibar,layout.scale.y)
	_pack_warning(app,content,layout)
	if canvas_script==null and not immersive_match: _subnavigation(content, app)
	app.body_scroll = ScrollContainer.new()
	app.body_scroll.name = "CareerWorkspace"
	app.body_scroll.follow_focus = true
	app.body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	C.fill(app.body_scroll, true)
	content.add_child(app.body_scroll)
	app.body = C.v(16)
	C.fill(app.body, true)
	app.body_scroll.add_child(app.body)
	if canvas_script!=null:
		var canvas := Control.new()
		canvas.custom_minimum_size=Vector2(2248,1244)*C.density
		C.fill(canvas,true)
		app.body.add_child(canvas)
		canvas_script.build(app,canvas)
		if app.route == "Calendrier":
			D.button(canvas,Rect2(1830,147,395,40),"Vue mensuelle",_calendar_table.bind(app,false),false,"calendar",true,app.accent,"CalendarShowMonth")
	elif app.route == "Bureau": app.body.add_child(OfficeCanvas.build(app) if physical.x >= 1600 else Office.build(app))
	else: _existing_page(app,immersive_match)
	_footer(content, app, layout)
	app._update_live_bar()
	app.call_deferred("_refresh_coach")
	app.call_deferred("_observe_navigation")
	return true

## Largeur de référence des gabarits de contenu (2560 − rail historique de 248).
const CONTENT_REFERENCE_WIDTH := 2312.0

static func _fit_content(stage: Control, inset: Control) -> void:
	var width := C.px(CONTENT_REFERENCE_WIDTH)
	var factor := minf(1.0, stage.size.x / width) if stage.size.x > 0 and width > 0 else 1.0
	if factor <= 0.0: return
	inset.scale = Vector2.ONE * factor
	inset.position = Vector2.ZERO
	inset.size = stage.size / factor

static func _fit_layout(root: Control, layout: Control, reference: Vector2) -> void:
	if root.size.x<=0 or root.size.y<=0: return
	var factor := minf(root.size.x/reference.x, root.size.y/reference.y)
	var base_footer := C.px(44)
	if base_footer*factor<38.0 and root.size.y>38.0:
		factor=minf(factor,(root.size.y-38.0)/(reference.y-base_footer))
	layout.scale = Vector2.ONE*factor
	layout.size = root.size/factor
	# Écrans ultra-larges (21:9, 32:9) : les gabarits sont dessinés pour 16:9 au plus. Au-delà, la zone de
	# travail garde la largeur 16:9 et se centre ; le fond photo remplit les côtés (comme le direct).
	var largeur_max := ceilf(layout.size.y*LARGEUR_MAX_RATIO)
	if layout.size.x > largeur_max+1.0:
		layout.size.x = largeur_max
		layout.position.x = roundf((root.size.x-largeur_max*factor)/2.0)
	else:
		layout.position.x = 0.0
	if layout.has_meta("immersive_footer"):
		var footer: Control = layout.get_meta("immersive_footer")
		footer.custom_minimum_size.y=maxf(base_footer,38.0/factor)
		_position_footer(footer)
	if layout.has_meta("immersive_office_match_status"):
		var match_status: Label = layout.get_meta("immersive_office_match_status")
		_position_office_match_status(match_status,factor)
		_sync_office_props(match_status)
	if layout.has_meta("immersive_pack_warning"):
		_fit_pack_warning(layout.get_meta("immersive_pack_warning"),factor)

static func _pack_warning(app: Control, parent: Container, layout: Control) -> void:
	var row := C.h(16)
	app.PackViews.missing_warning(app,row,"career")
	if row.get_child_count()==0:
		row.free()
		return
	var banner := PanelContainer.new()
	banner.name = "ImmersivePackWarning"
	banner.add_theme_stylebox_override("panel",C.box(C.RAISED,C.ALERT,5,8))
	parent.add_child(banner)
	banner.add_child(row)
	Legacy.apply(row,app.accent)
	for child in row.get_children():
		if child is Control: child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if child is Label:
			C.fill(child)
			child.add_theme_color_override("font_color",C.ALERT)
	layout.set_meta("immersive_pack_warning",row)
	_fit_pack_warning(row,layout.scale.y)

static func _fit_pack_warning(row: HBoxContainer, factor: float) -> void:
	var minimum_font := ceili(14.0/factor)
	for child in row.get_children():
		if child is Label:
			child.add_theme_font_size_override("font_size",maxi(C.px(20),minimum_font))
		elif child is Button:
			child.add_theme_font_size_override("font_size",maxi(C.px(22),minimum_font))
			child.custom_minimum_size.y = maxf(C.px(44),36.0/factor)
			var focus := child.get_theme_stylebox("focus") as StyleBoxFlat
			if focus!=null: focus.set_border_width_all(maxi(2,ceili(2.0/factor)))

static func _is_training(app: Control) -> bool:
	return app.route=="Préparation" and app.management_ui.get("preparation",{}).get("tab",0)==2

static func open_training(app: Control) -> void:
	open_preparation(app,2)

static func open_preparation(app: Control, tab: int) -> void:
	if not app.management_ui.get("preparation") is Dictionary:
		app.management_ui.preparation={"tab":tab,"outer":[0,0,0],"attack":0,"defense":0,"focus":["","",""]}
	else: app.management_ui.preparation.tab=tab
	app._navigate("Préparation",true,true)

static func _dedicated_page(app: Control, size: Vector2i) -> Script:
	# Fiche d'un club : gabarit à l'échelle, lisible dès 1280 × 720.
	if app.route == ClubSheet.ROUTE: return ClubSheet
	# Fiche complète d'une piste du marché ou d'un Espoir (clic sur le nom), à toutes les tailles.
	if not FichePage.actuelle(app).is_empty(): return FichePage
	# Composition (choix de Léo du 19/11/2026, variante 1) : page dédiée à toutes les tailles, avec son propre en-tête.
	if app.route == "Composition": return TacticsCanvas
	if app.route == "Calendrier" and Selections.nation_only(app.model): return null
	if app.route == "Calendrier" and not app.get_meta("calendar_table",false): return null
	if app.route=="Calendrier" and size.x>=1280 and size.y>=720 and app.model.meta.get("leagueId") in ["nationale","champ"]: return Competition
	if size.x<1920 or size.y<1080:
		if size.x<RICH_MIN_SIZE.x or size.y<RICH_MIN_SIZE.y or app.route not in RICH_FROM_720P: return null
	if _is_training(app): return Training
	match app.route:
		"Préparation": return Preparation
		"Plan de jeu": return Playbook
		"Formation": return Academy
		"Centre": return Centre
		"Recrutement": return Recruitment
		"Classements", "Calendrier": return Competition
		"Presse": return Press
		"Rivalités": return Rivalry
		"Club", "Staff", "Travail du club", "Stratégie": return ClubCanvas
		"Finances": return FinanceCanvas
		"Vestiaire": return Locker
		"Carrière": return Career
	return null

# --- Coque commune : rail de gauche et barre haute (charte §7.1, design/ux/coque-commune.md) --------------------
# Mesures en pixels de référence 2560 × 1440 (maquette 1920 × 1080 × 4/3), mises à l'échelle par C.px / D.place.
# Une seule direction artistique : jetons de ui/charte.gd, rayons 0 (2 px pour les champs), aucune ombre ni dégradé,
# un seul aplat or (Continuer). Aucun numéro devant les entrées : les touches 1 à 9 sont dites dans l'infobulle.

## Rail : [libellé, destination, routes où l'entrée est active]. Touches 1 à 9 dans cet ordre (raccourcis_clavier.gd).
## Entraînement est rangé sous Tactique (onglet « Entraînement » de Tactique et de la Préparation).
const RAIL_SECTIONS := [
	["Bureau", "Bureau", ["Bureau"]],
	["Réception", "Réception", ["Réception"]],
	["Effectif", "Effectif", ["Effectif", "Vestiaire"]],
	["Tactique", "Composition", ["Composition", "Préparation", "Plan de jeu", "Match"]],
	["Recrutement", "Recrutement", ["Recrutement"]],
	["Club", "Club", ["Club", "Staff", "Travail du club", "Stratégie"]],
	["Finances", "Finances", ["Finances"]],
	["Compétitions", "Classements", ["Classements", "Calendrier", "Rivalités", "Fiche club"]],
	["Formation", "Formation", ["Formation", "Centre", "Suivi des jeunes"]],
]
const RAIL_NATION := [["Réception", "Réception", ["Réception"]], ["Sélections", "Sélections", ["Sélections"]], ["Calendrier", "Calendrier", ["Calendrier"]]]
## Écrans propres à la coque (aucune fenêtre) : résultats de recherche et réglages.
const SHELL_ROUTES := ["Recherche", "Réglages"]
const RAIL_WIDTH := 309.0
const RAIL_HEADER := 152.0
const RAIL_TOP := 169.0
const RAIL_ROW := 83.0
const RAIL_ROW_MIN := 59.0
const RAIL_ROW_SMALL := 72.0
const RAIL_GAP := 23.0
const RAIL_DOCK := 293.0
const RAIL_TEXT := 29.0
const TOPBAR_HEIGHT := 64.0
const TOPBAR_WIDTH := 2560.0 - RAIL_WIDTH
const CONTINUE_WIDTH := 389.0
const JOURS := ["dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."]
const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]

## Parallélogramme incliné de 10° (logo) : liseré du club, marqueur de l'entrée active, badge, fond de Continuer.
## `pente_gauche` faux : bord gauche droit (Continuer n'a que son bord droit incliné).
class Incline extends Control:
	var couleur := Color.WHITE
	var couleur_survol := Color.TRANSPARENT
	var source: BaseButton
	var pente_gauche := true
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var h := size.y
		var d := h * 0.17633
		var c := couleur
		if is_instance_valid(source):
			if source.disabled: c = Color(couleur, .55)
			elif couleur_survol.a > 0.0 and (source.is_hovered() or source.button_pressed or source.has_focus()): c = couleur_survol
		draw_colored_polygon(PackedVector2Array([Vector2(d if pente_gauche else 0.0, 0.0), Vector2(size.x, 0.0), Vector2(size.x - d, h), Vector2(0.0, h)]), c)

## Pictogrammes de la coque, dessinés au trait (charte §7.1 : pas de caractère de police, pas de bibliothèque).
class Picto extends Control:
	var forme := ""
	var couleur := Color.WHITE
	var couleur_inactive := Color.WHITE
	var source: BaseButton
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _p(x: float, y: float) -> Vector2:
		return Vector2(x * size.x, y * size.y)
	func _draw() -> void:
		var c := couleur_inactive if is_instance_valid(source) and source.disabled else couleur
		var w := maxf(1.5, size.x * .085)
		match forme:
			"burger":
				for y in [.24, .5, .76]: draw_line(_p(.1, y), _p(.9, y), c, w)
			"gauche", "droite":
				var s := -1.0 if forme == "gauche" else 1.0
				var tip := .5 + s * .34
				draw_line(_p(.5 - s * .34, .5), _p(tip, .5), c, w)
				draw_line(_p(tip, .5), _p(tip - s * .28, .24), c, w)
				draw_line(_p(tip, .5), _p(tip - s * .28, .76), c, w)
				# Impossible (bord de l'historique) : flèche barrée, en plus de la teinte ivoire-3 (couleur jamais seule).
				if is_instance_valid(source) and source.disabled: draw_line(_p(.18, .86), _p(.82, .14), c, w)
			"loupe":
				draw_arc(_p(.42, .42), size.x * .28, 0.0, TAU, 32, c, w, true)
				draw_line(_p(.62, .62), _p(.9, .9), c, w)
			"carriere":
				draw_arc(_p(.5, .52), size.x * .34, deg_to_rad(-60.0), deg_to_rad(230.0), 32, c, w, true)
				var bout := _p(.5, .52) + Vector2.from_angle(deg_to_rad(-60.0)) * size.x * .34
				draw_line(bout, bout + Vector2(-size.x * .2, -size.y * .04), c, w)
				draw_line(bout, bout + Vector2(size.x * .02, size.y * .2), c, w)
			"reglages":
				draw_arc(_p(.5, .5), size.x * .17, 0.0, TAU, 24, c, w, true)
				for i in 8:
					var a := TAU * i / 8.0
					draw_line(_p(.5, .5) + Vector2.from_angle(a) * size.x * .28, _p(.5, .5) + Vector2.from_angle(a) * size.x * .44, c, w)
			"sauver":
				draw_line(_p(.5, .1), _p(.5, .66), c, w)
				draw_line(_p(.5, .66), _p(.26, .42), c, w)
				draw_line(_p(.5, .66), _p(.74, .42), c, w)
				draw_line(_p(.14, .9), _p(.86, .9), c, w)
			"coche":
				draw_polyline(PackedVector2Array([_p(.12, .54), _p(.4, .8), _p(.88, .24)]), c, w, true)
			"alerte":
				draw_line(_p(.5, .1), _p(.5, .62), c, w * 1.2)
				draw_circle(_p(.5, .86), w * .8, c)

## Plancher des textes de la coque en pixels de construction : 12 px réels une fois le gabarit mis à l'échelle
## (_fit_layout peut le réduire de quelques pour cent pour loger le pied de page, 0,977 à 1280 × 720).
static var _coque_floor := 12
## Facteur prévu du gabarit (_fit_layout) pour la fenêtre en cours : cibles de la coque en pixels réels.
static var _coque_factor := 1.0

static func _fpx(size_ref: float) -> int:
	return maxi(_coque_floor, C.px(size_ref))

## Facteur que _fit_layout appliquera au gabarit pour cette taille de fenêtre.
static func _predicted_factor(size: Vector2, reference: Vector2) -> float:
	if size.x <= 0 or size.y <= 0: return 1.0
	var factor := minf(size.x / reference.x, size.y / reference.y)
	var base_footer := C.px(44)
	if base_footer * factor < 38.0 and size.y > 38.0: factor = minf(factor, (size.y - 38.0) / (reference.y - base_footer))
	return factor

## Largeur d'un texte en unités de référence (mesuré à la taille réellement rendue, plancher 12 px compris).
static func _rw(font: Font, text: String, size_ref: float) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fpx(size_ref)).x / C.density

static func _style(color: Color, radius: float = 0.0, border: Color = Color.TRANSPARENT, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.draw_center = color.a > 0.0
	style.set_corner_radius_all(C.px(radius) if radius > 0.0 else 0)
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(border_width)
	return style

## Bouton de la coque : fond transparent, survol panneau-2, pressé panneau-3, focus clavier contour ivoire 2 px
## décalé de 2 px (charte §7.1, États). `contour` : filet 1 px ivoire-3, rayon 2 (Menu, Précédent, Suivant).
static func _shell_button(id: String, contour: bool = false) -> Button:
	var button := Button.new()
	button.name = id
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.set_meta("immersive_style_applied", true)
	var border := C.FAINT if contour else Color.TRANSPARENT
	var radius := 3.0 if contour else 0.0
	var fills := {"normal":Color.TRANSPARENT, "hover":C.RAISED, "pressed":C.SELECTED, "hover_pressed":C.SELECTED, "disabled":Color.TRANSPARENT}
	for state: String in fills: button.add_theme_stylebox_override(state, _style(fills[state], radius, C.LINE if state == "disabled" and contour else border))
	var focus := _style(Color.TRANSPARENT, 0.0, C.IVORY, 2)
	focus.set_expand_margin_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_font_override("font", C.BODY)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: button.add_theme_color_override(state, C.IVORY)
	button.add_theme_color_override("font_disabled_color", C.FAINT)
	return button

static func _button_margins(button: Button, left: float, right: float = 0.0) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style := button.get_theme_stylebox(state)
		style.content_margin_left = C.px(left)
		style.content_margin_right = C.px(right)

static func _label(parent: Node, rect: Rect2, text: String, size_ref: float, color: Color, font: Font, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", _fpx(size_ref))
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("immersive_style_applied", true)
	parent.add_child(label)
	D.place(label, rect)
	return label

## Touche écrite (« Échap », « Ctrl K », « Ctrl S », « F1 ») : pavé panneau-3, Barlow Condensed SemiBold ivoire-2.
static func _key(parent: Node, x: float, y: float, text: String, fond: Color = C.SELECTED) -> Panel:
	var width := _rw(C.DISPLAY, text, 16) + 16.0
	var chip := Panel.new()
	chip.name = "Touche_" + text.replace(" ", "")
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _style(fond, 3.0))
	parent.add_child(chip)
	D.place(chip, Rect2(x, y, width, 27))
	_label(chip, Rect2(0, 0, width, 27), text, 16, C.MUTED, C.DISPLAY, HORIZONTAL_ALIGNMENT_CENTER)
	return chip

static func _key_width(text: String) -> float:
	return _rw(C.DISPLAY, text, 16) + 16.0

static func _picto(parent: Node, rect: Rect2, forme: String, color: Color = C.MUTED, source: BaseButton = null) -> Picto:
	var picto := Picto.new()
	picto.name = "Picto_" + forme
	picto.forme = forme
	picto.couleur = color
	picto.couleur_inactive = C.FAINT
	picto.source = source
	parent.add_child(picto)
	D.place(picto, rect)
	if source != null: source.draw.connect(picto.queue_redraw)
	return picto

static func _incline(parent: Node, rect: Rect2, color: Color, pente_gauche: bool = true) -> Incline:
	var shape := Incline.new()
	shape.couleur = color
	shape.pente_gauche = pente_gauche
	parent.add_child(shape)
	D.place(shape, rect)
	return shape

## Section du rail qui contient la route (fil d'Ariane, entrée active).
static func rail_section(route: String) -> Array:
	for entry: Array in RAIL_SECTIONS + [["Presse", "Presse", ["Presse"]], ["Sélections", "Sélections", ["Sélections"]], ["Carrière", "Carrière", ["Carrière"]], ["Réglages", "Réglages", ["Réglages"]], ["Recherche", "Recherche", ["Recherche"]]]:
		if route in entry[2]: return entry
	return [route, route, [route]]

## « Division · rang » sous le nom du club, lus dans les données du club en cours (jeu de base ou pack Rugby Réel).
static func club_context(model: Dictionary) -> String:
	var division := P.league_name(model)
	var club: Dictionary = model.get("club", {}) if model.get("club") is Dictionary else {}
	var rank := P.rank_ordinal(club)
	return division if rank == "—" else division + " · " + rank

## « Division · rang » ajusté à `room` (unités de référence) : [texte, taille, lignes]. Une ligne en 16 (12 px à
## 1920), sinon deux lignes, puis la taille descend jusqu'au plancher de 12 px réels ; si cela ne suffit toujours pas,
## la division est raccourcie avec « … » mais « · rang » reste entier.
static func fit_context(context: String, rank: String, room: float) -> Array:
	if _rw(C.BODY, context, 16) <= room: return [context, 16.0, 1]
	var size := 16.0
	while true:
		if D.title_lines(C.BODY, context, _fpx(size), room * C.density) <= 2: return [context, size, 2]
		if _fpx(size) <= _coque_floor or size <= 1.0: break
		size -= 1.0
	var suffix := " · " + rank if not rank.is_empty() and context.ends_with(" · " + rank) else ""
	var division := context.trim_suffix(suffix)
	while division.length() > 1:
		division = division.substr(0, division.length() - 1).strip_edges()
		var candidate := division + "…" + suffix
		if D.title_lines(C.BODY, candidate, _fpx(size), room * C.density) <= 2: return [candidate, size, 2]
	return [context, size, 2]
static func _rail_entries(app: Control) -> Array:
	return RAIL_NATION if Selections.nation_only(app.model) else RAIL_SECTIONS

static func _sidebar(parent: Node, app: Control) -> void:
	var rail := Control.new()
	rail.name = "ImmersiveSidebar"
	rail.custom_minimum_size.x = C.px(RAIL_WIDTH)
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(rail)
	var background := ColorRect.new()
	background.name = "ImmersiveSidebarBackground"
	background.color = C.PANEL
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var national := Selections.nation_only(app.model)
	_rail_header(rail, app, national)
	var sections: Array = _rail_entries(app)
	var secondary: Array = []
	if not national:
		secondary.append(["Presse", "Presse", ["Presse"]])
		if app.model.get("international") is Dictionary: secondary.append(["Sélections", "Sélections", ["Sélections"]])
	# Lignes de 83 (62 px à 1920) compressibles jusqu'à 59 (44 px) ; au-delà, le groupe central défile, le pied reste fixe.
	var height: float = app.get_window().size.y / C.density
	var available := maxf(RAIL_ROW_MIN, height - RAIL_TOP - RAIL_DOCK - 8.0)
	var gap := RAIL_GAP if not secondary.is_empty() else 0.0
	var weight := sections.size() + secondary.size() * RAIL_ROW_SMALL / RAIL_ROW
	var row := clampf(floorf((available - gap) / weight), RAIL_ROW_MIN, RAIL_ROW)
	var small := roundf(row * RAIL_ROW_SMALL / RAIL_ROW)
	var total := sections.size() * row + gap + secondary.size() * small
	var scroll := ScrollContainer.new()
	scroll.name = "ImmersiveSidebarSections"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if total > available else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	rail.add_child(scroll)
	D.place(scroll, Rect2(0, RAIL_TOP, RAIL_WIDTH, minf(total, available)))
	var column := Control.new()
	column.name = "ImmersiveSidebarColumn"
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.custom_minimum_size = Vector2(RAIL_WIDTH, total) * C.density
	scroll.add_child(column)
	var y := 0.0
	for i in sections.size():
		_rail_entry(column, app, sections[i], y, row, i)
		y += row
	if not secondary.is_empty():
		D.line(column, Vector2(27, y + 11), Vector2(RAIL_WIDTH - 27, y + 11), C.LINE)
		y += gap
		for entry: Array in secondary:
			_rail_entry(column, app, entry, y, small, -1)
			y += small
	_rail_dock(rail, app, national)

## En-tête : écusson, nom du club (Barlow Condensed ExtraBold Italic, capitales), « division · rang », liseré club-trait
## incliné. Un clic ouvre la fiche du club (pour son propre club : l'écran Club, décision de Léo du 14/11/2026).
static func _rail_header(rail: Control, app: Control, national: bool) -> void:
	var header := _shell_button("ImmersiveClubHeader")
	header.tooltip_text = "Fiche du club"
	if app.route == "Club" and not national: header.add_theme_stylebox_override("normal", _style(C.SELECTED))
	(header.get_theme_stylebox("focus") as StyleBoxFlat).set_expand_margin_all(0)
	rail.add_child(header)
	D.place(header, Rect2(0, 0, RAIL_WIDTH, RAIL_HEADER))
	var club: Dictionary = app.model.get("club", {}) if app.model.get("club") is Dictionary else {}
	header.pressed.connect(func():
		if national: app._navigate("Sélections")
		elif not club.has("id") or not app.navigation_controller.open_entity({"kind":"club", "id":str(int(club.get("id", -1)))}): app._navigate("Club"))
	var nation := Selections.managed_team(app.model)
	var identity := str(nation.get("name", "Sélection")) if national else G.club_name(club)
	var crest: Control = Selections.nation_badge(nation, C.px(53)) if national else G.crest(club, C.px(53))
	crest.name = "ImmersiveClubCrest"
	header.add_child(crest)
	D.place(crest, Rect2(27, 36, 53, 67))
	for node in [crest] + crest.find_children("*", "Control", true, false): (node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Nom : une ligne en 27 (20 px à 1920), sinon deux lignes (jusqu'à 21) ; jamais de « … », infobulle complète.
	var room := RAIL_WIDTH - 96.0 - 21.0
	var font: Font = Charte.TITRE_EXTRA_ITALIQUE
	var caption := identity.to_upper()
	var chosen := 27.0
	var lines := 1
	if _rw(font, caption, 27) > room:
		lines = 2
		chosen = 21.0
		for candidate in [24.0, 23.0, 22.0, 21.0]:
			if _lines_ref(font, caption, candidate, room) <= 2:
				chosen = candidate
				break
	var line_height := font.get_height(_fpx(chosen)) / C.density
	var top := 40.0 if lines == 1 else 30.0
	var name_label := _label(header, Rect2(96, top, room, line_height * lines), caption, chosen, C.IVORY, font)
	name_label.name = "ImmersiveClubName"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if lines == 2 else TextServer.AUTOWRAP_OFF
	name_label.max_lines_visible = 2
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# La taille minimale mise en cache (texte sur une ligne) bornerait la largeur : on la recalcule avant de placer.
	name_label.update_minimum_size()
	D.place(name_label, Rect2(96, top, room, line_height * lines))
	header.tooltip_text = identity + " · fiche du club" if not national else identity
	var context := "Sélection nationale" if national else club_context(app.model)
	# « Division · rang » : même calcul sur tous les écrans (fit_context) : une ligne, puis deux lignes, puis 12 px,
	# puis la division se raccourcit — le rang n'est jamais perdu ; texte complet en infobulle.
	var rank := "" if national or P.rank_ordinal(app.model.get("club", {}) if app.model.get("club") is Dictionary else {}) == "—" else P.rank_ordinal(app.model.club)
	var fitted := fit_context(context, rank, room)
	var sub := _label(header, Rect2(96, top + line_height * lines + 2, room, 21), str(fitted[0]), float(fitted[1]), C.MUTED, C.BODY)
	sub.name = "ImmersiveClubContext"
	sub.tooltip_text = context
	sub.set_meta("context_complet", context)
	sub.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	if int(fitted[2]) == 2:
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.max_lines_visible = 2
		sub.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	sub.update_minimum_size()
	D.place(sub, Rect2(96, top + line_height * lines + 2, room, 21 * int(fitted[2])))
	header.tooltip_text = (identity + " · " + context + " · fiche du club") if not national else identity
	var stripe := _incline(header, Rect2(27, RAIL_HEADER - 17, RAIL_WIDTH - 48, 4), Charte.club_trait(app.accent))
	stripe.name = "ImmersiveClubStripe"

## Nombre de lignes d'un texte coupé aux mots (largeur en unités de référence).
static func _lines_ref(font: Font, text: String, size_ref: float, width_ref: float) -> int:
	return D.title_lines(font, text, _fpx(size_ref), width_ref * C.density)

static func _rail_entry(column: Control, app: Control, entry: Array, y: float, height: float, index: int) -> Button:
	var caption: String = entry[0]
	var destination: String = entry[1]
	var selected: bool = app.route in entry[2]
	var button := _shell_button("Nav_" + caption)
	button.text = caption
	button.add_theme_font_override("font", Charte.texte_moyen() if selected else C.BODY)
	button.add_theme_font_size_override("font_size", _fpx(24))
	button.tooltip_text = caption + (" · touche %d" % (index + 1) if index >= 0 and index < 9 else "")
	button.accessibility_name = caption
	if selected:
		button.add_theme_stylebox_override("normal", _style(C.SELECTED))
		button.add_theme_stylebox_override("hover", _style(C.SELECTED))
		button.set_meta("rail_actif", true)
	column.add_child(button)
	D.place(button, Rect2(4, y, RAIL_WIDTH - 8, height))
	_button_margins(button, RAIL_TEXT - 4, 70 if destination == "Réception" else 12)
	button.pressed.connect(func(): app._navigate(destination))
	if selected:
		var marker := _incline(button, Rect2(7, 15, 4 + 0.17633 * (height - 30), height - 30), C.IVORY)
		marker.name = "RailActiveMarker"
	if destination == "Réception":
		var unread: int = Reception.unread(app)
		if unread > 0:
			var text := "99+" if unread > 99 else str(unread)
			var width := maxf(37.0, _rw(C.BODY, text, 21) + 20.0)
			var badge := _incline(button, Rect2(RAIL_WIDTH - 8 - 21 - width, (height - 32) / 2.0, width, 32), C.IVORY)
			badge.name = "RailUnreadBadge"
			_label(badge, Rect2(0, 0, width, 32), text, 21, Charte.NUIT, C.BOLD, HORIZONTAL_ALIGNMENT_CENTER).name = "RailUnreadCount"
			button.accessibility_name = "Réception, %d message%s non lu%s" % [unread, "s" if unread > 1 else "", "s" if unread > 1 else ""]
	return button

## Pied du rail : Carrière, Réglages, Sauvegarder (« Ctrl S »), puis la ligne « ✓ Sauvegardé <date du jeu> ».
static func _rail_dock(rail: Control, app: Control, national: bool) -> void:
	var dock := Control.new()
	dock.name = "ImmersiveSidebarDock"
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(dock)
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -C.px(RAIL_DOCK)
	D.line(dock, Vector2(27, 0), Vector2(RAIL_WIDTH - 27, 0), C.LINE)
	var actions := [["Carrière", "carriere", "Carrière"], ["Réglages", "reglages", "Réglages"], ["Sauvegarder", "sauver", ""]]
	var y := 11.0
	for i in actions.size():
		if i == 0 and national: continue
		var item: Array = actions[i]
		var route: String = item[2]
		var selected: bool = not route.is_empty() and app.route == route
		var button := _shell_button("ImmersiveSidebarAction" + str(i))
		button.text = item[0]
		button.add_theme_font_override("font", Charte.texte_moyen() if selected else C.BODY)
		button.add_theme_font_size_override("font_size", _fpx(24))
		if selected:
			button.add_theme_stylebox_override("normal", _style(C.SELECTED))
			button.set_meta("rail_actif", true)
		dock.add_child(button)
		D.place(button, Rect2(4, y, RAIL_WIDTH - 8, RAIL_ROW_SMALL))
		_button_margins(button, 68, 12)
		_picto(button, Rect2(RAIL_TEXT - 4, (RAIL_ROW_SMALL - 27) / 2.0, 27, 27), item[1], C.IVORY if selected else C.MUTED)
		match i:
			0: button.pressed.connect(func(): app._navigate("Carrière"))
			1: button.pressed.connect(func(): app._navigate("Réglages"))
			2:
				button.pressed.connect(func(): save_now(app))
				button.tooltip_text = "Sauvegarder la carrière maintenant · Ctrl S"
				var key_width := _key_width("Ctrl S")
				_key(button, RAIL_WIDTH - 8 - 21 - key_width, (RAIL_ROW_SMALL - 27) / 2.0, "Ctrl S")
		if i == 0: button.tooltip_text = "Ta carrière de manager"
		if i == 1: button.tooltip_text = "Réglages : confort, son, affichage, raccourcis"
		y += RAIL_ROW_SMALL
	var line := _shell_button("ImmersiveSaveLine")
	line.add_theme_font_size_override("font_size", _fpx(19))
	dock.add_child(line)
	D.place(line, Rect2(4, y + 6, RAIL_WIDTH - 8, 40))
	_button_margins(line, 52, 8)
	_picto(line, Rect2(RAIL_TEXT - 4, 10, 20, 20), "coche", Charte.V).name = "SaveLinePicto"
	line.pressed.connect(func(): save_now(app))
	refresh_save_line(app, line)

## Sauvegarde directe (Ctrl S, Sauvegarder, « Réessayer ») : aucune boîte ; la ligne passe à « Sauvegarde… ».
static func save_now(app: Control) -> void:
	if not app._has_career(): return
	if app._command("save"): refresh_save_line(app)

static func _short_date(date: String) -> String:
	var parts := date.split("-")
	if parts.size() != 3 or not parts[1].is_valid_int() or not parts[2].is_valid_int(): return ""
	var stamp := Time.get_unix_time_from_datetime_string(date.substr(0, 10) + "T12:00:00")
	var weekday := int(Time.get_datetime_dict_from_unix_time(stamp).get("weekday", -1))
	return ("%s %s/%s" % [JOURS[weekday], parts[2].substr(0, 2), parts[1]]) if weekday >= 0 and weekday < 7 else "%s/%s" % [parts[2].substr(0, 2), parts[1]]

## Ligne d'état de la sauvegarde dans le pied du rail : [texte, couleur, picto, infobulle].
static func save_caption(app: Control) -> Array:
	var meta: Dictionary = app.model.get("meta", {})
	if bool(app.get("waiting")) and str(app.get("last_command")) == "save": return ["Sauvegarde…", C.MUTED, "sauver", "Sauvegarde en cours"]
	var failed: bool = bool(meta.get("saveError", false)) or (app.has_method("_storage_has_error") and app._storage_has_error())
	if failed: return ["Échec de la sauvegarde · Réessayer", Charte.D, "alerte", "La dernière sauvegarde n'a pas pu être écrite. Clique pour réessayer."]
	var info: Variant = meta.get("autosave")
	var last := str(info.get("lastSave", "")) if info is Dictionary and info.get("lastSave") != null else ""
	if last.is_empty(): return ["Pas encore sauvegardé", C.MUTED, "sauver", "Clique pour sauvegarder maintenant."]
	var policy := str({"jour":"chaque jour", "semaine":"chaque semaine", "mois":"chaque mois"}.get(str(info.get("policy", "")), ""))
	return ["Sauvegardé " + _short_date(last), Charte.V, "coche", "Dernière sauvegarde complète le %s%s. Clique pour sauvegarder maintenant." % [_short_date(last), " · automatique " + policy if not policy.is_empty() else ""]]

static func refresh_save_line(app: Control, line: Button = null) -> void:
	if line == null and is_instance_valid(app.get("root_content")): line = app.root_content.find_child("ImmersiveSaveLine", true, false) as Button
	if not is_instance_valid(line): return
	var state := save_caption(app)
	line.text = state[0]
	line.tooltip_text = state[3]
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: line.add_theme_color_override(key, state[1])
	var picto := line.get_node_or_null("SaveLinePicto") as Picto
	if picto != null:
		picto.forme = state[2]
		picto.couleur = state[1]
		picto.queue_redraw()

## Barre haute (48 px à 1920, 64 en référence) : Menu « Échap », Précédent / Suivant, fil d'Ariane cliquable,
## Rechercher « Ctrl K » (champ, aucune fenêtre), date + journée (Calendrier), médaillon de Gabi « F1 »,
## « +1 j » discret, Continuer (seul aplat or, bord droit incliné, « Espace » ou ce qui l'arrête).
static func _topbar(parent: Node, app: Control, layout: Control) -> void:
	var panel := Control.new()
	panel.name = "ImmersiveTopbar"
	panel.custom_minimum_size.y = C.px(TOPBAR_HEIGHT)
	C.fill(panel)
	parent.add_child(panel)
	var background := ColorRect.new()
	background.name = "ImmersiveTopbarBackground"
	background.color = C.PANEL
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bottom := ColorRect.new()
	bottom.name = "ImmersiveTopbarRule"
	bottom.color = C.LINE
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -1
	var national := Selections.nation_only(app.model)
	var ch := C.reach(43.0)
	var cy := (TOPBAR_HEIGHT - ch) / 2.0
	var square := C.reach(48.0)
	var sy := (TOPBAR_HEIGHT - square) / 2.0
	# Gauche : Menu (menu pause, la seule fenêtre de la coque), historique, filet.
	var menu_text := _rw(Charte.texte_moyen(), "Menu", 17)
	var menu_width := 8.0 + 21.0 + 11.0 + menu_text + 11.0 + _key_width("Échap") + 8.0
	var menu := _shell_button("ImmersiveMenu", true)
	menu.tooltip_text = "Menu : sauvegardes, réglages, quitter · Échap"
	menu.accessibility_name = "Menu · Échap"
	panel.add_child(menu)
	D.place(menu, Rect2(21, cy, menu_width, ch))
	menu.pressed.connect(app.pause_menu)
	_picto(menu, Rect2(8, (ch - 21) / 2.0, 21, 21), "burger", C.IVORY)
	_label(menu, Rect2(40, 0, menu_text + 2, ch), "Menu", 17, C.IVORY, Charte.texte_moyen())
	_key(menu, 40 + menu_text + 11, (ch - 27) / 2.0, "Échap")
	var x := 21.0 + menu_width + 27.0
	var back := _shell_button("NavigationBack", true)
	var forward := _shell_button("NavigationForward", true)
	for item: Array in [[back, "gauche", "Page précédente · Alt+←"], [forward, "droite", "Page suivante · Alt+→"]]:
		var arrow: Button = item[0]
		arrow.set_meta("coque", true)
		arrow.tooltip_text = item[2]
		arrow.accessibility_name = item[2]
		panel.add_child(arrow)
		D.place(arrow, Rect2(x, sy, square, square))
		_picto(arrow, Rect2(square * .27, square * .27, square * .46, square * .46), item[1], C.IVORY, arrow)
		x += square + 11.0
	if is_instance_valid(app.navigation_controller): app.navigation_controller.bind_history_buttons(back, forward)
	x += 16.0
	D.line(panel, Vector2(x, 16), Vector2(x, 48), C.LINE)
	var crumbs_left := x + 28.0
	# Droite, de droite à gauche : Continuer, +1 j, F1 et Gabi, date, recherche ; le fil prend le reste.
	var right := TOPBAR_WIDTH - 11.0
	var continue_height := C.reach(48.0)
	var continue_rect := Rect2(right - CONTINUE_WIDTH, (TOPBAR_HEIGHT - continue_height) / 2.0, CONTINUE_WIDTH, continue_height)
	right -= CONTINUE_WIDTH + 16.0
	var office_live: bool = app.route == "Bureau" and not app._live().is_empty()
	var single_day: bool = not office_live and app.has_method("next_day_available") and app.next_day_available()
	var next_day: Button = null
	if single_day:
		var day_width := _rw(C.BODY, "+1 j", 17) + 22.0
		next_day = _shell_button("ImmersiveNextDay")
		next_day.text = "+1 j"
		next_day.alignment = HORIZONTAL_ALIGNMENT_CENTER
		next_day.add_theme_font_size_override("font_size", _fpx(17))
		for key in ["font_color", "font_focus_color"]: next_day.add_theme_color_override(key, C.MUTED)
		next_day.tooltip_text = "Jour suivant : avancer d’un seul jour (Ctrl+J)"
		next_day.accessibility_name = "Jour suivant"
		panel.add_child(next_day)
		D.place(next_day, Rect2(right - day_width, cy, day_width, ch))
		next_day.pressed.connect(app.next_day_action)
		right -= day_width + 16.0
	# Médaillon ovale de Gabi (72 × 48 en référence, 54 × 36 px à 1920) et sa touche « F1 » : cibles d'au moins 28 px
	# réels (58 de haut à 1280 × 720), et au moins 50 pour rester ≥ 24 px si la fenêtre passe de 2560 à 1280 sans
	# reconstruction. Les deux s'affichent ensemble ou pas du tout (Bureau : Gabi en pied, coach coupé).
	var target := ceilf(28.0 / maxf(.01, C.density * _coque_factor))
	var medallion_height := clampf(maxf(50.0, target), 50.0, TOPBAR_HEIGHT - 4.0)
	var medallion_width := medallion_height * 1.5
	var f1_width := maxf(_key_width("F1") + 8.0, target)
	var help := _shell_button("GabiF1")
	help.tooltip_text = "Aide de Gabi · F1"
	help.accessibility_name = "Aide de Gabi · F1"
	panel.add_child(help)
	D.place(help, Rect2(right - f1_width, (TOPBAR_HEIGHT - medallion_height) / 2.0, f1_width, medallion_height))
	help.pressed.connect(func(): app._open_coach())
	_key(help, (f1_width - _key_width("F1")) / 2.0, (medallion_height - 27) / 2.0, "F1", C.RAISED)
	right -= f1_width + 4.0
	var gabi_en_pied: bool = app.route == "Bureau" and not national and is_instance_valid(app.get("coach")) and app.coach.has_method("bureau_disponible") and app.coach.bureau_disponible()
	var gabi := Control.new()
	gabi.name = "GabiBandeau"
	gabi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gabi.set_meta("masque", gabi_en_pied)
	gabi.set_meta("compact", true)
	panel.add_child(gabi)
	D.place(gabi, Rect2(right - medallion_width, (TOPBAR_HEIGHT - medallion_height) / 2.0, medallion_width, medallion_height))
	right -= medallion_width + 27.0
	# Date + journée : « mar. 17 nov. · J9 » ; clic : Calendrier (au jour courant).
	var caption := date_caption(app.model)
	var widest := maxf(_rw(Charte.texte_moyen(), caption[0], 17), _rw(Charte.texte_moyen(), "mer. 28 sept.", 17))
	var round_width := _rw(Charte.TITRE_GRAS_ITALIQUE, "· J30", 20) + 6.0
	var date_width := widest + round_width + 16.0
	var calendar := _shell_button("ImmersiveCalendarDate")
	calendar.accessibility_name = "Ouvrir le calendrier"
	panel.add_child(calendar)
	D.place(calendar, Rect2(right - date_width, cy, date_width, ch))
	calendar.pressed.connect(_open_current_calendar.bind(app))
	app.header_date = _label(calendar, Rect2(8, 0, widest, ch), "", 17, C.IVORY, Charte.texte_moyen(), HORIZONTAL_ALIGNMENT_RIGHT)
	app.header_date.name = "ImmersiveDateText"
	app.header_date.set_meta("coque", true)
	app.header_date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var round_label := _label(calendar, Rect2(8 + widest + 4, 0, round_width, ch), "", 20, C.IVORY, Charte.TITRE_GRAS_ITALIQUE)
	round_label.name = "ImmersiveRound"
	app._update_header_date()
	right -= date_width + 27.0
	# Recherche : 400 (300 px à 1920), réduite jusqu'à 293 (220 px) si le fil manque de place.
	var crumbs := _crumbs(app)
	var crumbs_width := _crumbs_width(crumbs)
	var search_width := clampf(right - crumbs_left - minf(crumbs_width, 520.0) - 27.0, 293.0, 400.0)
	var search := _search_field(panel, app, Rect2(right - search_width, cy, search_width, ch))
	right -= search_width + 27.0
	_place_crumbs(panel, app, crumbs, crumbs_left, right, ch, cy)
	_continue_button(panel, app, continue_rect)
	if next_day != null: next_day.focus_neighbor_right = app.primary_button.get_path()
	if is_instance_valid(app.coach) and app.coach.has_method("installer_bandeau"): app.coach.installer_bandeau(gabi)
	else: gabi.hide()
	# « F1 » n'est jamais seul dans la barre : il suit le médaillon (masqué au Bureau, où Gabi est en pied).
	help.visible = gabi.visible and not gabi_en_pied

## Date du jeu de la barre haute : [« mar. 17 nov. », « J9 » ou vide, infobulle].
static func date_caption(model: Dictionary) -> Array:
	var meta: Dictionary = model.get("meta", {})
	var round_label := str(meta.get("roundLabel", ""))
	var planning: Dictionary = model.get("calendarPlanning", {}) if model.get("calendarPlanning") is Dictionary else {}
	var today: Variant = planning.get("today", meta.get("calendarToday", meta.get("date", "")))
	var date: String = today if today is String else ""
	var parts := date.split("-")
	var text := ""
	if parts.size() == 3 and parts[1].is_valid_int() and int(parts[1]) in range(1, 13) and parts[2].substr(0, 2).is_valid_int():
		var stamp := Time.get_unix_time_from_datetime_string(date.substr(0, 10) + "T12:00:00")
		var weekday := int(Time.get_datetime_dict_from_unix_time(stamp).get("weekday", -1))
		text = "%s%d %s" % [(JOURS[weekday] + " ") if weekday >= 0 and weekday < 7 else "", int(parts[2].substr(0, 2)), MOIS[int(parts[1]) - 1]]
	else:
		text = "Saison " + G.season_label(meta.get("season", 1))
	# Journée : celle du libellé de la semaine (« Journée 9 · … ») ; sinon celle de la prochaine rencontre du club
	# (« Journée 2 », relectures du 19/11/2026 : l'avant-saison et les semaines sans libellé gardent leur repère).
	var journee := ""
	var pattern := RegEx.create_from_string("(?i)journée\\s+(\\d+)")
	var matched := pattern.search(round_label)
	if matched == null: matched = pattern.search(str(P.next_fixture(model).get("label", "")))
	if matched != null: journee = "J" + matched.get_string(1)
	return [text, journee, round_label]

## Fil d'Ariane : [libellé, action]. Club → fiche du club ; section → page racine de la section ; sous-page → la page.
static func _crumbs(app: Control) -> Array:
	var national := Selections.nation_only(app.model)
	var club: Dictionary = app.model.get("club", {}) if app.model.get("club") is Dictionary else {}
	var identity := str(Selections.managed_team(app.model).get("name", "Sélection")) if national else G.club_name(club)
	var result := []
	result.append([identity, func():
		if national: app._navigate("Sélections")
		elif not club.has("id") or not app.navigation_controller.open_entity({"kind":"club", "id":str(int(club.get("id", -1)))}): app._navigate("Club")])
	var section := rail_section(app.route)
	var section_root: String = section[1]
	result.append([str(section[0]), func(): app._navigate(section_root)])
	var page := _page_caption(app)
	if not page.is_empty() and page != str(section[0]):
		var route: String = app.route
		result.append([page, func(): app._navigate(route, true, true)])
	return result

static func _page_caption(app: Control) -> String:
	if app.route == "Effectif" and app.get_meta("immersive08_full_player", false): return "Fiche joueur : " + str(P.player(app.model, app.selected_player).get("name", ""))
	var fiche := FichePage.actuelle(app)
	if not fiche.is_empty(): return "Fiche joueur : " + str(fiche.joueur.get("name", ""))
	if app.route == ClubSheet.ROUTE: return "Fiche club : " + ClubSheet.caption(app)
	if _is_training(app): return "Entraînement"
	if app.route == "Recherche":
		var query := str(app.management_ui.get("search_query", "")).strip_edges()
		return "« %s »" % query if not query.is_empty() else "Résultats"
	return {"Effectif":"Vue d'ensemble", "Composition":"Composition", "Classements":"Classements", "Réception":"Courrier", "Bureau":"Ta semaine"}.get(app.route, app.route)

static func _crumbs_width(crumbs: Array) -> float:
	var total := 0.0
	for i in crumbs.size():
		var last: bool = i == crumbs.size() - 1
		total += _rw(Charte.texte_moyen() if last else C.BODY, str(crumbs[i][0]), 17) + 8.0
		if not last: total += _rw(C.BODY, "/", 17) + 22.0
	return total

## Place les morceaux du fil entre `left` et `right` ; s'il manque de place, il perd ses premiers morceaux.
static func _place_crumbs(panel: Control, app: Control, crumbs: Array, left: float, right: float, ch: float, cy: float) -> void:
	var shown := crumbs.duplicate()
	while shown.size() > 1 and _crumbs_width(shown) > right - left: shown.pop_front()
	var x := left
	var first_index := crumbs.size() - shown.size()
	for i in shown.size():
		var last: bool = i == shown.size() - 1
		var font: Font = Charte.texte_moyen() if last else C.BODY
		# Le dernier morceau (la page) se resserre jusqu'au plancher de 12 px avant tout « … ».
		var size := 17.0
		var room := maxf(40.0, right - x)
		while _fpx(size) > _coque_floor and _rw(font, str(shown[i][0]), size) + 8.0 > room: size -= 1.0
		var width := minf(_rw(font, str(shown[i][0]), size) + 8.0, room)
		var crumb := _shell_button("ImmersiveCrumb%d" % (first_index + i))
		crumb.text = str(shown[i][0])
		crumb.tooltip_text = str(shown[i][0])
		crumb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		crumb.add_theme_font_override("font", font)
		crumb.add_theme_font_size_override("font_size", _fpx(size))
		if not last:
			for key in ["font_color", "font_focus_color"]: crumb.add_theme_color_override(key, C.MUTED)
		else: crumb.set_meta("ariane_ici", true)
		crumb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(crumb)
		D.place(crumb, Rect2(x, cy, width, ch))
		crumb.pressed.connect(shown[i][1])
		x += width
		if not last:
			_label(panel, Rect2(x + 7, cy, _rw(C.BODY, "/", 17) + 8, ch), "/", 17, C.FAINT, C.BODY, HORIZONTAL_ALIGNMENT_CENTER)
			x += _rw(C.BODY, "/", 17) + 22.0

## Champ « Rechercher » (Ctrl K) : fond panneau-3, contour ivoire-3, rayon 2 ; Entrée ouvre l'écran Recherche.
static func _search_field(panel: Control, app: Control, rect: Rect2) -> LineEdit:
	var field := LineEdit.new()
	field.name = "ImmersiveSearch"
	field.set_meta("immersive_style_applied", true)
	var national := Selections.nation_only(app.model)
	var hint := "Rechercher un écran…" if national else "Rechercher un joueur, un club…"
	field.placeholder_text = hint if _rw(C.BODY, hint, 17) <= rect.size.x - 39.0 - _key_width("Ctrl K") - 20.0 else "Rechercher…"
	field.tooltip_text = "Rechercher un joueur, un club ou un écran · Ctrl K · Entrée : résultats"
	field.accessibility_name = "Rechercher · Ctrl K"
	field.add_theme_font_override("font", C.BODY)
	field.add_theme_font_size_override("font_size", _fpx(17))
	field.add_theme_color_override("font_color", C.IVORY)
	field.add_theme_color_override("font_placeholder_color", C.MUTED)
	field.add_theme_color_override("caret_color", C.IVORY)
	field.add_theme_color_override("selection_color", C.LINE)
	var normal := _style(C.SELECTED, 3.0, C.FAINT)
	var focus := _style(Color.TRANSPARENT, 0.0, C.IVORY, 2)
	focus.set_expand_margin_all(2)
	for style: StyleBoxFlat in [normal, focus]:
		style.content_margin_left = C.px(39)
		style.content_margin_right = C.px(_key_width("Ctrl K") + 14.0)
	field.add_theme_stylebox_override("normal", normal)
	field.add_theme_stylebox_override("read_only", normal)
	field.add_theme_stylebox_override("focus", focus)
	if app.route == "Recherche": field.text = str(app.management_ui.get("search_query", ""))
	panel.add_child(field)
	D.place(field, rect)
	_picto(field, Rect2(12, (rect.size.y - 21) / 2.0, 21, 21), "loupe", C.MUTED)
	var key := _key(field, rect.size.x - _key_width("Ctrl K") - 8.0, (rect.size.y - 27) / 2.0, "Ctrl K", C.RAISED)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.text_submitted.connect(func(text: String): app.navigation_controller.submit_search(text))
	field.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			field.accept_event()
			if not field.text.is_empty(): field.clear()
			else: field.release_focus())
	if is_instance_valid(app.navigation_controller): app.navigation_controller.bind_search_field(field)
	return field

## Continuer : aplat or (seul aplat or de la coque), texte nuit, bord droit incliné 10° ; « Espace » à droite, ou ce
## qui l'arrête (« Préparer », « Conf. de presse »…). main.gd écrit l'état dans `text` (invisible) : sync_continue
## le recopie dans les libellés visibles.
static func _continue_button(panel: Control, app: Control, rect: Rect2) -> void:
	var button := _shell_button("ImmersiveContinue")
	button.text = "Continuer"
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]: button.add_theme_color_override(key, Color.TRANSPARENT)
	var focus := _style(Color.TRANSPARENT, 0.0, C.IVORY, 2)
	focus.set_expand_margin_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	button.add_theme_font_size_override("font_size", _fpx(24))
	panel.add_child(button)
	D.place(button, rect)
	var plate := _incline(button, Rect2(Vector2.ZERO, rect.size), C.OR, false)
	plate.name = "ContinuePlate"
	plate.show_behind_parent = true
	plate.couleur_survol = C.OR_VIF
	plate.source = button
	button.draw.connect(plate.queue_redraw)
	var label := _label(button, Rect2(24, 0, rect.size.x - 150, rect.size.y), "CONTINUER", 24, Charte.NUIT, Charte.TITRE_EXTRA_ITALIQUE)
	label.name = "ContinueLabel"
	var rule := ColorRect.new()
	rule.name = "ContinueRule"
	rule.color = Color(Charte.NUIT, .35)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(rule)
	var hint := _label(button, Rect2(rect.size.x - 120, 0, 85, rect.size.y), "Espace", 16, Charte.NUIT, C.BODY, HORIZONTAL_ALIGNMENT_RIGHT)
	hint.name = "ContinueHint"
	app.primary_button = button
	button.pressed.connect(app.primary_action)
	button.tooltip_text = app.primary_tooltip() if app.has_method("primary_tooltip") else app.primary_text()
	sync_continue(app)

## Recopie l'état de Continuer (texte court posé par main.gd) dans ses libellés visibles.
static func sync_continue(app: Control) -> void:
	var button := app.get("primary_button") as Button
	if not is_instance_valid(button) or button.name != "ImmersiveContinue": return
	var label := button.get_node_or_null("ContinueLabel") as Label
	var hint := button.get_node_or_null("ContinueHint") as Label
	var rule := button.get_node_or_null("ContinueRule") as ColorRect
	if label == null or hint == null or rule == null: return
	var state := str(button.text).strip_edges()
	var own_head: bool = state in ["Relancer", "Retour au direct", "Valider le résultat", "Après-match"]
	label.text = state.to_upper() if own_head else "CONTINUER"
	# « Espace » au repos ; « ! » + raison courte seulement quand quelque chose arrête Continuer (main.continue_block),
	# jamais d'après l'état désactivé ni d'après la prochaine étape ordinaire (« Préparer »).
	var block: String = str(app.continue_block()) if app.has_method("continue_block") else ""
	hint.text = "Espace" if block.is_empty() else "! " + block
	button.accessibility_name = label.text.capitalize() + " · " + (block + " (clic : l'écran qui bloque)" if not block.is_empty() else "touche Espace")
	var width_ref := button.size.x / C.density if button.size.x > 0 else CONTINUE_WIDTH
	var height_ref := button.size.y / C.density if button.size.y > 0 else TOPBAR_HEIGHT - 16
	# Jamais de « … » : le libellé et la raison se resserrent jusqu'au plancher de 12 px pour tenir entiers.
	var hint_size := 16.0
	var label_size := 24.0
	var hint_right := width_ref - 35.0
	while hint_size > 1.0 and _fpx(hint_size) > _coque_floor and _rw(C.BODY, hint.text, hint_size) + 4.0 > width_ref * .55: hint_size -= 1.0
	var hint_width := _rw(C.BODY, hint.text, hint_size) + 4.0
	var label_room := hint_right - hint_width - 37.0 - 24.0
	while label_size > 1.0 and _fpx(label_size) > _coque_floor and _rw(Charte.TITRE_EXTRA_ITALIQUE, label.text, label_size) > label_room: label_size -= 1.0
	hint.add_theme_font_size_override("font_size", _fpx(hint_size))
	label.add_theme_font_size_override("font_size", _fpx(label_size))
	hint.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	hint.tooltip_text = hint.text
	D.place(hint, Rect2(hint_right - hint_width, 0, hint_width, height_ref))
	D.place(rule, Rect2(hint_right - hint_width - 13.0, height_ref * .28, 1.0 / C.density, height_ref * .44))
	D.place(label, Rect2(24, 0, maxf(40.0, label_room), height_ref))

## Chiffre clé de l'en-tête Effectif : gros chiffre et légende sur le fond sombre des blocs (comme
## « 65 aujourd’hui » de la fiche joueur), à la place des pastilles en petit texte vert sur vert.
static func _key_figure(row: Control, area: Rect2, index: int, item: Array) -> Panel:
	var frame := D.rect(row,area,Color("16201f"),7,Color("415451"))
	frame.name = "EffectifChiffre%d" % index
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	var value := str(item[0])
	var pixels := maxi(12,C.px(40))
	var width := C.font(700).get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x / C.density
	width = minf(width, area.size.x * .5)
	var figure := D.text(frame,18,47,value,40,item[2],700,width+2)
	figure.name = "EffectifChiffreValeur"
	var legend := D.text(frame,18+width+10,45,str(item[1]),21,C.MUTED,500,area.size.x-width-46)
	legend.name = "EffectifChiffreLegende"
	frame.tooltip_text = value + " " + str(item[1])
	frame.accessibility_name = frame.tooltip_text
	return frame

## Titre du Bureau (maquette « Affiche et Gabi ») : « LE BUREAU » en italique, sa phrase d'accueil, la saison à droite.
static func _entete_bureau(row: Control, app: Control) -> void:
	app.heading.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	var largeur := C.font(800).get_string_size("LE BUREAU", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(53))).x / C.density
	D.text(row, largeur + 28, 54, "Ta semaine commence ici.", 21, Charte.IVOIRE_2, 500, 700, HORIZONTAL_ALIGNMENT_LEFT, true).name = "OfficeSubtitle"
	var meta: Dictionary = app.model.get("meta", {})
	if meta.has("season"):
		D.text(row, 2248, 54, "Saison %s · semaine %d" % [G.season_label(meta.season), int(meta.get("week", 0)) + 1], 21, Charte.IVOIRE_2, 500, 700, HORIZONTAL_ALIGNMENT_RIGHT, true).name = "OfficeSeason"
static func _position_office_match_status(status: Label, factor: float) -> void:
	if factor<=0: return
	status.add_theme_font_size_override("font_size",maxi(C.px(25),ceili(14.0/factor)))

static func _heading(parent: Node, app: Control) -> void:
	var row := Control.new()
	row.custom_minimum_size.y = C.px(91 if app.route=="Effectif" else 88 if app.route=="Composition" else 112 if app.route=="Réception" else 80 if app.route=="Bureau" else 104)
	C.fill(row)
	parent.add_child(row)
	if app.route=="Réception":
		app.heading=Reception.heading(row,app)
		app.minibar=C.label("",17,C.GOLD)
		app.minibar.visible=false
		parent.add_child(app.minibar)
		return
	if app.route!="Bureau": D.text(row,1,19,{"Bureau":"LE BUREAU","Effectif":"LE GROUPE PROFESSIONNEL","Composition":"LE PLAN DE JEU"}.get(app.route,app.route.to_upper()),19,app.accent.lightened(.48),600,1040)
	app.heading = D.text(row,-1,56 if app.route=="Bureau" else 76,"LE BUREAU" if app.route=="Bureau" else TITLES.get(app.route,app.route),53,C.IVORY,800 if app.route=="Bureau" else 700,1190)
	if app.route=="Bureau": _entete_bureau(row,app)
	if COMPACT_ART.has(app.route):
		var image := D.panel(row,Rect2(1438,6,810,89),"","","","CompactRouteArt")
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if app.route == "Finances":
			FinanceCanvas.hospitality(image, Rect2(2,2,806,85))
		else:
			D.photo(image,COMPACT_ART[app.route],Rect2(2,2,806,85),.16)
	var values := P.group(app.model)
	var injury_count: int = values.injured
	var injury_caption := "%d blessé%s" % [injury_count, "s" if injury_count > 1 else ""]
	var metrics: Array = [[(P.rank_ordinal(app.model.club) if P.standings_open(app.model.club) else "Pas classé")+" · "+G.n(app.model.club.get("points",0))+" pts","trophy",C.GOLD],[str(values.available)+" disponibles","people",C.MINT],[injury_caption,"heart",C.ALERT if injury_count > 0 else C.MUTED]]
	# Effectif : chiffres clés en gros chiffre + légende (valeur, légende, couleur du chiffre).
	if app.route=="Effectif": metrics=[[G.n(values.total),"joueur%s" % ("s" if int(values.total) > 1 else ""),C.IVORY],[G.n(values.available),"disponible%s" % ("s" if int(values.available) > 1 else ""),C.MINT],[G.n(injury_count),"blessé%s" % ("s" if injury_count > 1 else ""),C.ALERT if injury_count > 0 else C.IVORY],[str(values.rating),"niveau moyen",C.GOLD]]
	# Bureau (Affiche et Gabi) et Composition (page dédiée) n'ont plus de pastilles d'en-tête.
	else: metrics=[]
	if app.get_window().size.x >= 1600:
		for i in metrics.size():
			var item: Array = metrics[i]
			if app.route=="Effectif":
				_key_figure(row,Rect2(1242+i*253,13,241,64),i,item)
				continue
			var x := 1512+i*250
			D.rect(row,Rect2(x,15,236,58),Color("16201f"),7,Color("415451"))
			var symbol := C.icon(item[1],25,item[2])
			row.add_child(symbol)
			D.place(symbol,Rect2(x+16,32,25,25))
			D.text(row,x+53,54,item[0],25,item[2],600,179)
	if app.route=="Bureau":
		var match_status := D.text(row,590,49,"",25,C.GOLD,700,630)
		match_status.name = "ImmersiveOfficeMatchStatus"
		match_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		D.place(match_status,Rect2(590,3,630,91))
		match_status.visible = not app._live().is_empty()
		match_status.visibility_changed.connect(_sync_office_props.bind(match_status))
		_sync_office_props(match_status)
		app.minibar = match_status
	else:
		app.minibar = C.label("",17,C.GOLD)
		parent.add_child(app.minibar)
		app.minibar.hide()

## Décor du bureau (ballon, coupe) : la scène n'est chargée qu'une fois ; un rendu sur deux
## relisait ballon.glb (et son avertissement d'UID) faute de référence gardée.
const OFFICE_PROPS_PATH := "res://art/office_props/office_props.tscn"
## Décor 3D du Bureau (ballon, coupe) retiré par la direction artistique du 19/11/2026 : le bandeau d'illustration voilé le remplace.
const OFFICE_PROPS_ENABLED := false
static var _office_props_scene: PackedScene

static func _sync_office_props(match_status: Label) -> void:
	if not match_status.is_inside_tree(): return
	var row := match_status.get_parent()
	var props := row.get_node_or_null("OfficeProps") as TextureRect
	if match_status.get_window().size.x < 1600 or match_status.visible:
		if props != null:
			row.remove_child(props)
			props.queue_free()
	elif props == null and OFFICE_PROPS_ENABLED:
		if _office_props_scene == null:
			_office_props_scene = load(OFFICE_PROPS_PATH) as PackedScene
		props = _office_props_scene.instantiate() as TextureRect
		row.add_child(props)
		D.place(props,Rect2(1080,5,260,78))

static func _subnavigation(parent: Node, app: Control) -> void:
	if Selections.nation_only(app.model): return
	if app.route=="Composition" or (app.route=="Effectif" and app.get_window().size.x>=1600): return
	for group: Array in GROUPS:
		if app.route not in group[2] or group[2].size() < 2: continue
		var row := C.h(8)
		row.name = "ChapterSubnavigation"
		parent.add_child(row)
		for destination: String in group[2]:
			var action := C.button(destination.to_upper(), func(): app._navigate(destination), app.route == destination, app.accent)
			action.name = "Section_" + destination
			action.custom_minimum_size.y = C.px(38)
			C.fill(action)
			row.add_child(action)
		return

static func _footer(parent: Node, app: Control, layout: Control) -> void:
	var row := Control.new()
	row.name = "ImmersiveFooter"
	row.custom_minimum_size.y = maxf(C.px(44),38.0/layout.scale.y)
	C.fill(row)
	parent.add_child(row)
	layout.set_meta("immersive_footer",row)
	D.line(row,Vector2(0,-FOOTER_RISE),Vector2(2248,-FOOTER_RISE),Color(C.LINE,.7))
	app.status = D.text(row,2,36,app._status_line_text(),17,C.ALERT if app._status_has_error() else C.MUTED,500,900)
	app.status.name = "ImmersiveSaveStatus"
	# Une seule ligne, jamais coupée : le texte se resserre au lieu de passer à la ligne (voir _fit_status).
	app.status.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Rappel des raccourcis sur tous les écrans, Bureau compris : le pied de page est hors de la zone défilante
	# (Gabi, blocs et frise y restent), donc il ne recouvre rien ; le bouton Continuer est dans le bandeau du haut.
	var shortcuts := D.text(row,782,36-FOOTER_RISE,Raccourcis.pied_de_page(),17,C.FAINT,400,800,HORIZONTAL_ALIGNMENT_LEFT,true)
	shortcuts.name = "ImmersiveShortcuts"
	if app.decision_feedback != null:
		var feedback: Button = app.decision_feedback.control()
		feedback.add_theme_font_override("font",C.DISPLAY)
		row.add_child(feedback)
	row.resized.connect(_position_footer.bind(row))
	# Le texte change après chaque réponse du moteur (main.gd) : il redemande l'ajustement à ce pied de page.
	app.status.set_meta("refit",_position_footer.bind(row))
	_position_footer(row)

static func _position_footer(row: Control) -> void:
	var factor := row.get_global_transform().get_scale().x
	if factor<=0 or row.size.x<=0: return
	var feedback: Button = row.get_node_or_null("DecisionFeedbackButton")
	if feedback!=null:
		feedback.size=Vector2(maxf(C.px(180),146.0/factor),maxf(C.px(34),30.0/factor))
		feedback.position=Vector2(row.size.x-feedback.size.x,row.size.y-feedback.size.y-1.0/factor)
		feedback.add_theme_font_size_override("font_size",maxi(C.px(17),roundi(13.0/factor)))
	var status: Label = row.get_node_or_null("ImmersiveSaveStatus")
	if status==null: return
	var gap := maxf(C.px(16),8.0/factor)
	var right := (feedback.position.x if feedback!=null else row.size.x)-gap
	var shortcuts: Label = row.get_node_or_null("ImmersiveShortcuts")
	var compact := C.px(24)*factor<14.0
	var side_by_side := shortcuts != null and not compact and row.size.x*factor>=1650
	var shortcuts_x := maxf(C.px(782),630.0/factor)
	var pixels := maxi(C.px(17),ceili(14.0/factor))
	var font := status.get_theme_font("font")
	var smallest := maxi(12,ceili(11.0/factor))
	# Côte à côte, la ligne d'état n'a que la place avant le pied de raccourcis : si son texte n'y tient pas
	# même resserré, elle passe sous les raccourcis, sur toute la largeur (comme en fenêtre compacte).
	if side_by_side and font.get_string_size(status.text,HORIZONTAL_ALIGNMENT_LEFT,-1,smallest).x > minf(right,shortcuts_x-gap)-status.position.x:
		side_by_side = false
		compact = true
	if side_by_side: right = minf(right,shortcuts_x-gap)
	status.add_theme_font_size_override("font_size",pixels)
	status.position.y = row.size.y-C.px(8+FOOTER_RISE)-font.get_ascent(pixels)
	status.size = Vector2(maxf(0.0,right-status.position.x),font.get_height(pixels))
	_fit_status(status,pixels,smallest)
	if shortcuts==null: return
	shortcuts.visible=compact or side_by_side
	var shortcut_font := C.MEDIUM if compact else C.BODY
	var shortcut_px := pixels if compact else maxi(12,C.px(17))
	var shortcut_height := shortcut_font.get_height(shortcut_px)
	shortcuts.add_theme_font_override("font",shortcut_font)
	shortcuts.add_theme_font_size_override("font_size",shortcut_px)
	shortcuts.add_theme_color_override("font_color",C.MUTED if compact else C.FAINT)
	if compact:
		shortcuts.position=Vector2(status.position.x,status.position.y-shortcut_height-1.0/factor)
		shortcuts.size=Vector2(status.size.x,shortcut_height)
	else:
		shortcuts.position=Vector2(shortcuts_x,C.px(36-FOOTER_RISE)-shortcut_font.get_ascent(shortcut_px))
		shortcuts.size=Vector2(C.px(800),shortcut_height)

## Ligne d'état du pied de page (« Conférence tenue · Moral collectif : 75 → 87 / 100 », erreurs, sauvegarde) :
## toujours sur une seule ligne et entière. Si le texte dépasse la place libre, on réduit la taille jusqu'à
## `smallest` (≈ 11 px écran) ; seulement ensuite le bout est remplacé par « … » (texte complet en infobulle).
static func _fit_status(status: Label, pixels: int, smallest: int) -> void:
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var font := status.get_theme_font("font")
	var chosen := pixels
	while chosen > smallest and font.get_string_size(status.text,HORIZONTAL_ALIGNMENT_LEFT,-1,chosen).x > status.size.x: chosen -= 1
	if chosen != pixels:
		status.add_theme_font_size_override("font_size",chosen)
		status.position.y += font.get_ascent(pixels)-font.get_ascent(chosen)
		status.size.y = font.get_height(chosen)
	status.tooltip_text = status.text

static func _open_current_calendar(app: Control) -> void:
	app.set_meta("calendar_table",false)
	app._navigate("Calendrier")
	var calendar: Control = app.body.find_child("CarnetCalendar",true,false)
	if calendar != null and not calendar.today.is_empty():
		calendar._jump_to_today()

static func _calendar_table(app: Control, show_table: bool) -> void:
	app.set_meta("calendar_table",show_table)
	app._render(false)

static func _existing_page(app: Control, immersive_match: bool) -> void:
	match app.route:
		"Réception": app.body.add_child(Reception.build(app))
		"Sélections":
			var page := Selections.build(app)
			app.body.add_child(page)
			Legacy.apply(page, app.accent)
		"Club": app.body.add_child(app.ClubViews.club(app))
		"Calendrier":
			if Selections.nation_only(app.model): app.body.add_child(Selections.calendar(app))
			elif app.get_meta("calendar_table",false):
				D.button(app.heading.get_parent(),Rect2(1050,16,340,52),"Vue mensuelle",_calendar_table.bind(app,false),false,"calendar",true,app.accent,"CalendarShowMonth")
				app.body.add_child(app.ClubViews.calendar(app))
			else:
				app.body.add_child(MonthCalendar.build(app,_calendar_table.bind(app,true)))
		"Classements": app.body.add_child(app.ClubViews.tables(app))
		"Finances": app.body.add_child(app.ClubViews.finance(app))
		"Effectif":
			var player:=P.player(app.model,app.selected_player)
			if app.get_meta("immersive08_full_player",false) and not player.is_empty():app.body.add_child(PlayerCanvas.build(app,player))
			elif SocleEffectif.actif(app):app.body.add_child(SocleEffectif.build(app))
			elif app.get_window().size.x>=1600:app.body.add_child(SquadCanvas.build(app))
			else:
				var roster: Control = app.SquadViews.squad(app)
				app.body.add_child(roster)
				Legacy.apply(roster, app.accent)
		"Préparation": app.body.add_child(Preparation.compact(app))
		"Plan de jeu": app.body.add_child(app.PlaybookViews.build(app))
		"Recrutement": app.body.add_child(app.SquadViews.market(app))
		"Staff": app.body.add_child(app.StaffViews.build(app))
		"Formation": app.body.add_child(app.DevelopmentViews.build(app))
		"Presse":
			# Plus d'ancienne vue (papier, or, arrondis) : la page Presse de la direction artistique sert à toutes les tailles.
			var hote := Control.new()
			hote.custom_minimum_size = Vector2(0, Press.HEIGHT * C.density)
			app.body.add_child(hote)
			Press.build(app, hote)
		"Vestiaire": app.body.add_child(app.RelationshipsViews.build(app))
		"Rivalités": app.body.add_child(app.WorldViews.build(app))
		"Stratégie": app.body.add_child(app.StrategyViews.build(app))
		"Centre": app.body.add_child(app.AcademyViews.build(app))
		"Suivi des jeunes": app.body.add_child(app.AcademyFollowUpViews.build(app))
		"Travail du club": app.body.add_child(app.SupportViews.build(app))
		"Carrière": app.body.add_child(app.ManagerCareerViews.build(app))
		"Recherche": app.body.add_child(SearchPage.build(app))
		"Réglages":
			var preferences := Preferences.page(app, app.user_preferences)
			app.body.add_child(preferences)
			Legacy.apply(preferences, app.accent)
		"Match":
			app.match_screen = MatchCanvas.new() if immersive_match else MatchCompact.new()
			app.match_screen.app = app
			app.body.add_child(app.match_screen)
			app.match_page = app.match_screen
			app.match_screen.update_frame(app.model)
	if app.route == "Staff": ClubCanvas.style_staff(app.body.get_child(0), app.accent)
	elif COMPACT_ART.has(app.route): Legacy.apply(app.body.get_child(0), app.accent)


## Fonds d'écran de la banque d'images par route (très atténués : les panneaux restent la lecture).
const FOND_OPACITE := 0.16
const FONDS := {"Bureau":"fond-bureau", "Effectif":"fond-effectif", "Composition":"fond-composition", "Préparation":"fond-tactique",
	"Plan de jeu":"fond-tactique", "Recrutement":"fond-transferts", "Finances":"fond-finances", "Calendrier":"fond-calendrier",
	"Classements":"fond-classements", "Rivalités":"fond-palmares", "Presse":"fond-presse", "Formation":"fond-jeunes", "Centre":"fond-jeunes",
	"Suivi des jeunes":"fond-jeunes", "Travail du club":"fond-medical", "Carrière":"fond-palmares"}

static func fond_ecran(route: String, phase: String = "") -> String:
	var id := str(FONDS.get(route, ""))
	if route == "Bureau" and phase in ["offseason", "ended", "intersaison"]: id = "fond-fin-de-saison"
	return id if not id.is_empty() and BanqueImages.texture(id) != null else ""
