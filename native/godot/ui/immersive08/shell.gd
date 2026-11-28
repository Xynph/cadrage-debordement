extends RefCounted
## Coque commune. Ce fichier garde les constantes, `render`, la mise à l'échelle, le choix de la page, les fonds d'écran et les passerelles publiques ; le reste est dans shell_outils.gd (briques), shell_rail.gd (rail), shell_barre.gd (sauvegarde, barre haute) et shell_entete.gd (en-tête de page, onglets, pied de page).
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
const EntreePage = preload("res://ui/entree_page.gd")
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
const TrainingMois = preload("res://ui/immersive08/training_mois.gd")
const ClubCanvas = preload("res://ui/immersive08/club_canvas.gd")
const FinanceCanvas = preload("res://ui/immersive08/finance_canvas.gd")
const Preparation = preload("res://ui/immersive08/preparation_canvas.gd")
const Playbook = preload("res://ui/immersive08/playbook_canvas.gd")
const Centre = preload("res://ui/immersive08/centre_canvas.gd")
const Press = preload("res://ui/immersive08/press_canvas.gd")
const Rivalry = preload("res://ui/immersive08/rivalry_canvas.gd")
const ClubSheet = preload("res://ui/immersive08/club_sheet_canvas.gd")
const Comparateur = preload("res://ui/immersive08/comparateur_canvas.gd")
const EuropePage = preload("res://ui/immersive08/europe_canvas.gd")
const Locker = preload("res://ui/immersive08/locker_canvas.gd")
const Career = preload("res://ui/immersive08/career_canvas.gd")
const Selections = preload("res://ui/international_view.gd")
const MatchCanvas = preload("res://ui/immersive08/match_canvas.gd")
const MatchCompact = preload("res://ui/immersive08/match_compact.gd")
const G = preload("res://ui/game_skin.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const ClubUI = preload("res://ui/immersive08/club_ui.gd")
const Outils = preload("res://ui/immersive08/shell_outils.gd")
const Rail = preload("res://ui/immersive08/shell_rail.gd")
const Barre = preload("res://ui/immersive08/shell_barre.gd")
const Entete = preload("res://ui/immersive08/shell_entete.gd")
## Gabarits riches (référence 2560 × 1440) ouverts dès 1280 × 720 (densité 0,5). Les gabarits sont
## proportionnels (C.px, D.place) et tout texte passe par un plancher de 12 px (C.label, D.text) :
## à 1280 × 720 le plus petit texte rendu fait 12 × 0,977 ≈ 11,7 px (pied de page compris, voir _fit_layout).
## Préparation (Entraînement compris), Plan de jeu et Centre en font partie : sous la densité 0,75, leurs commandes
## serrées gardent une cible d'au moins 25 px de fenêtre (C.reach, C.reach_controls) et se réorganisent au besoin
## (XV en colonnes, repères et vigilance sur des lignes plus hautes). Seul le Calendrier en tableau hors
## Nationale/Champ garde sa page simple. Le Match (avant le coup d'envoi) suit le même seuil RICH_MIN_SIZE ;
## le direct est l'écran contextuel.
## Titre de page = nom de l'écran en capitales : plus de slogan de héros (revue « phrases à retirer » du 21/11/2026).
const RICH_MIN_SIZE := Vector2i(1280,720)
## Largeur physique à partir de laquelle le Bureau est dessiné (OfficeCanvas, avec la colonne de Gabi en pied).
const OFFICE_CANVAS_MIN_WIDTH := 1600
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
## Rapport largeur/hauteur maximal de la zone de travail (16:9) ; au-delà, elle est centrée.
const LARGEUR_MAX_RATIO := 16.0/9.0
const COMPACT_ART = {
	"Finances":"finance-hospitality", "Calendrier":"stadium", "Formation":"academy-training",
	"Plan de jeu":"lineout-analysis", "Centre":"academy-training", "Suivi des jeunes":"academy-training", "Préparation":"analysis-room",
	"Recrutement":"scouting", "Classements":"trophy", "Club":"club-forest", "Staff":"mail-staff",
	"Travail du club":"analysis-room", "Stratégie":"club-forest", "Presse":"press-room",
	"Rivalités":"trophy", "Vestiaire":"lockerroom", "Carrière":"entry-ground",
}

## L'avant-match (route Match, aucun direct en cours, fenêtre assez grande pour l'écran riche) se joue hors coque.
static func avant_match_hors_coque(app: Control) -> bool:
	if app.route != "Match" or not app.model.get("club") is Dictionary or not app._live().is_empty(): return false
	var physical := app.get_window().size
	return physical.x >= RICH_MIN_SIZE.x and physical.y >= RICH_MIN_SIZE.y

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
	# Photo de fond propre à chaque page (banque d'images), voilée sur l'ardoise comme l'Effectif (charte finale ;
	# Léo, 21/11/2026 : « pas la même photo partout »). FOND_PHOTO = false donne l'aplat seul.
	var ui_gestion: Variant = app.get("management_ui")
	var fond := fond_ecran(app.route, str(app.model.get("meta", {}).get("phase", "")), ui_gestion if ui_gestion is Dictionary else {}) if FOND_PHOTO else ""
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
	Outils._coque_factor = maxf(.5, Outils._predicted_factor(Vector2(physical), reference))
	Outils._coque_floor = ceili(12.0 / Outils._coque_factor - .001)
	_fit_layout(app.root_content,layout,reference)
	app.root_content.resized.connect(_fit_layout.bind(app.root_content,layout,reference))
	var shell := C.h(0)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_child(shell)
	# Avant-match : écran hors coque (charte §7) ; ni rail ni barre haute, l'écran porte son propre bandeau.
	var hors_coque := avant_match_hors_coque(app)
	app.set_meta("hors_coque", hors_coque)
	# Sans bouton Continuer, l'ancien (libéré avec la coque précédente) ne doit plus être pointé.
	if hors_coque: app.primary_button = null
	if not hors_coque: Rail._sidebar(shell, app)
	var workspace := C.v(0)
	C.fill(workspace, true)
	shell.add_child(workspace)
	if not hors_coque: Barre._topbar(workspace, app, layout)
	Raccourcis.installer(app)
	var inset := C.margin(32)
	app.workspace_inset = inset
	inset.add_theme_constant_override("margin_top", C.px(22))
	if hors_coque:
		for edge in ["left", "top", "right", "bottom"]: inset.add_theme_constant_override("margin_" + edge, 0)
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
	if canvas_script!=null or immersive_match or app.route=="Effectif":
		app.heading=null
		app.minibar=C.label("",17,C.GOLD);app.minibar.visible=false;content.add_child(app.minibar)
	else: Entete._heading(content, app)
	if app.route=="Bureau":
		layout.set_meta("immersive_office_match_status",app.minibar)
		Entete._position_office_match_status(app.minibar,layout.scale.y)
	if not hors_coque: _pack_warning(app,content,layout)
	if canvas_script==null and not immersive_match: Entete._subnavigation(content, app)
	app.body_scroll = ScrollContainer.new()
	app.body_scroll.name = "CareerWorkspace"
	app.body_scroll.follow_focus = true
	app.body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	C.fill(app.body_scroll, true)
	_poser_espace_de_travail(content, app.body_scroll)
	app.body = C.v(16)
	C.fill(app.body, true)
	app.body_scroll.add_child(app.body)
	# Page à animer à l'arrivée (ui/entree_page.gd) : page dessinée, Bureau, ou corps des pages classiques (fondu seul).
	var page_entree: Control = app.body
	if canvas_script!=null:
		var canvas := Control.new()
		page_entree = canvas
		canvas.custom_minimum_size=Vector2(2248,1244)*C.density
		C.fill(canvas,true)
		app.body.add_child(canvas)
		canvas_script.build(app,canvas)
		if app.route == "Calendrier":
			D.button(canvas,Rect2(1830,147,395,40),"Programme du mois",func(): TrainingMois.ouvrir(app),false,"calendar",true,app.accent,"CalendarShowMonth")
	elif app.route == "Bureau":
		var bureau: Control = OfficeCanvas.build(app) if physical.x >= OFFICE_CANVAS_MIN_WIDTH else Office.build(app)
		app.body.add_child(bureau)
		page_entree = bureau
	else: _existing_page(app,immersive_match)
	# Arrivée sur une page : blocs en cascade et jauges qui se remplissent (pas à chaque rafraîchissement).
	# Page classique : un seul enfant dans le corps (souvent un conteneur) → on anime ses blocs à lui.
	if page_entree == app.body and app.body.get_child_count() == 1 and app.body.get_child(0) is Control:
		page_entree = app.body.get_child(0)
	EntreePage.animer(app, page_entree, app.route)
	if not hors_coque: Entete._footer(content, app, layout)
	app._update_live_bar()
	app.call_deferred("_refresh_coach")
	app.call_deferred("_observe_navigation")
	return true

## L'espace de travail défile (ScrollContainer) et rogne la page. Il rognait aussi l'ombre portée des panneaux et tuiles
## posés contre ses bords (charte : 4 px, choix de Léo du 20/11/2026). Le rognage passe à un cadre plus grand de
## OMBRE_TAILLE de chaque côté ; l'espace de travail garde exactement sa place, sa taille et son défilement.
static func _poser_espace_de_travail(content: Control, scroll: ScrollContainer) -> void:
	var place := Control.new()
	place.name = "CareerWorkspaceSlot"
	place.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(place, true)
	content.add_child(place)
	var cadre := CadreDeRognage.new()
	cadre.marge = float(Charte.OMBRE_TAILLE)
	cadre.name = "CareerWorkspaceClip"
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.clip_contents = true
	place.add_child(cadre)
	var marge := float(Charte.OMBRE_TAILLE)
	cadre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cadre.offset_left = -marge; cadre.offset_top = -marge; cadre.offset_right = marge; cadre.offset_bottom = marge
	scroll.clip_contents = false
	cadre.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = marge; scroll.offset_top = marge; scroll.offset_right = -marge; scroll.offset_bottom = -marge
	# La largeur minimale de la page (défilement horizontal coupé) continue de compter dans la mise en page.
	var suivre := func(): if is_instance_valid(place) and is_instance_valid(scroll): place.custom_minimum_size = scroll.get_combined_minimum_size()
	scroll.minimum_size_changed.connect(suivre)
	suivre.call()

## Cadre qui rogne le dessin `marge` px plus large que l'espace de travail, mais ne laisse pointer la souris que dans
## l'espace de travail lui-même (comme avant) : rien ne se survole ni ne se clique dans la bande de l'ombre.
class CadreDeRognage extends Control:
	var marge := 0.0
	func _has_point(point: Vector2) -> bool:
		return Rect2(Vector2.ONE * marge, size - Vector2.ONE * marge * 2.0).has_point(point)

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
		Entete._position_footer(footer)
	if layout.has_meta("immersive_office_match_status"):
		var match_status: Label = layout.get_meta("immersive_office_match_status")
		Entete._position_office_match_status(match_status,factor)
		Entete._sync_office_props(match_status)
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
	banner.add_theme_stylebox_override("panel",C.box(C.Charte.VOILE_DORE,Color.TRANSPARENT,16,8))
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
	if app.route == Comparateur.ROUTE: return Comparateur
	if app.route == EuropePage.ROUTE: return EuropePage
	# Fiche complète d'une piste du marché ou d'un Espoir (clic sur le nom), à toutes les tailles.
	if not FichePage.actuelle(app).is_empty(): return FichePage
	# Composition (choix de Léo du 19/11/2026, variante 1) : page dédiée à toutes les tailles, avec son propre en-tête.
	if app.route == "Composition": return TacticsCanvas
	if app.route == "Calendrier" and Selections.nation_only(app.model): return null
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
const SHELL_ROUTES := ["Recherche", "Réglages", "Comparateur", "Préparation Europe"]
const RAIL_WIDTH := 309.0
const RAIL_HEADER := 152.0
const RAIL_TOP := 169.0
## Entrées du menu latéral (charte §7.1) : pilule de 40 px (53,3 en référence 2560, 1920 = facteur 0,75), dans une
## ligne de 44 px (4 px d'air entre deux pilules), en retrait de 12 px des bords du rail ; icône 20 px.
const RAIL_ROW := 59.0
const RAIL_ROW_MIN := 55.0
const RAIL_ROW_SMALL := 59.0
const RAIL_PILL := 160.0 / 3.0
const RAIL_INSET := 16.0
const RAIL_ICON := 80.0 / 3.0
## Dans la pilule : 12 px avant l'icône, 9 px entre l'icône et le libellé.
const RAIL_PAD := 16.0
const RAIL_LABEL := RAIL_PAD + RAIL_ICON + 12.0
const RAIL_GAP := 23.0
const RAIL_DOCK := 252.0
const RAIL_TEXT := 29.0
## Rayon 6 px de la charte (pastilles, touches, cases) en unités de référence.
const RAYON_PETIT_REF := Charte.RAYON_PETIT / 0.75
## Icônes du rail (famille au trait d'icon-paths.json), gris-vert au repos, PANNEAU sur l'entrée active.
const RAIL_ICONS := {"Bureau":"home", "Réception":"mail", "Effectif":"people", "Tactique":"tactic", "Recrutement":"search",
	"Club":"shield", "Finances":"money", "Compétitions":"trophy", "Formation":"school", "Presse":"globe", "Sélections":"flag",
	"Calendrier":"calendar"}
const TOPBAR_HEIGHT := 64.0
const TOPBAR_WIDTH := 2560.0 - RAIL_WIDTH
const CONTINUE_WIDTH := 389.0
const JOURS := ["dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."]
const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]


## Date de la barre haute : le programme du mois (Entraînement › Mois), au mois du jour. Il remplace l'ancienne grille
## mensuelle du Calendrier (choix de Léo du 22/11/2026) ; la liste des rencontres reste dans Compétitions › Calendrier.
static func _open_current_calendar(app: Control) -> void:
	# Sélectionneur sans club : son calendrier international (Calendrier), pas d'entraînement de club.
	if Selections.nation_only(app.model): app._navigate("Calendrier")
	else: TrainingMois.ouvrir(app)

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
			else:
				D.button(app.heading.get_parent(),Rect2(1050,16,340,52),"Programme du mois",func(): TrainingMois.ouvrir(app),false,"calendar",true,app.accent,"CalendarShowMonth")
				app.body.add_child(app.ClubViews.calendar(app))
		"Classements": app.body.add_child(app.ClubViews.tables(app))
		"Finances": app.body.add_child(app.ClubViews.finance(app))
		"Effectif":
			var player:=P.player(app.model,app.selected_player)
			if app.get_meta("immersive08_full_player",false) and not player.is_empty():app.body.add_child(PlayerCanvas.build(app,player))
			elif SocleEffectif.actif(app):app.body.add_child(SocleEffectif.build(app))
			# Décision de Léo (19/11/2026) : un seul tableau, à toutes les tailles (colonnes retirées en fenêtre étroite).
			else:app.body.add_child(SquadCanvas.build(app))
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


## Fonds d'écran de la banque d'images par page : une photo par thème, jamais la même sur deux pages voisines
## (même groupe du rail ou onglets d'un même écran). Même voile pour toutes (FOND_OPACITE, réglage de l'Effectif) :
## la lecture des tableaux reste identique. Pages absentes (Staff, Réglages, Recherche) : aplat, image à créer
## (liste dans la PR « fonds photo par page »). Écrans plein écran (direct, réunion, avant-match) hors coque : sans fond.
const FOND_PHOTO := true
const FOND_OPACITE := 0.16
const FONDS := {"Bureau":"fond-bureau", "Réception":"mail-finances", "Effectif":"fond-effectif",
	"Vestiaire":"vestiaire-avant-match-neutre", "Composition":"fond-composition", "Préparation":"fond-tactique",
	"Plan de jeu":"mail-meteo-alerte", "Recrutement":"fond-transferts", "Club":"tribune-vide", "Stratégie":"mail-sponsor",
	"Travail du club":"fond-medical", "Finances":"fond-finances", "Calendrier":"fond-calendrier",
	"Classements":"fond-classements", "Rivalités":"mail-rivalite", "Formation":"fond-jeunes", "Centre":"mail-jeunes",
	"Suivi des jeunes":"chargement-08", "Presse":"fond-presse", "Sélections":"voyage-aeroport",
	"Carrière":"titre-nouvelle-carriere", "Réglages":"fond-reglages", "Recherche":"fond-recherche"}
## Onglets qui changent de thème dans une même route : Entraînement (Préparation, onglet 2), Club › Infrastructures
## et Club › Histoire.
const FOND_ENTRAINEMENT := "chargement-02"
const FONDS_CLUB := {"infrastructure":"club-stade-niveau-3", "history":"fond-palmares", "staff":"fond-staff"}

static func fond_ecran(route: String, phase: String = "", ui: Dictionary = {}) -> String:
	var id := str(FONDS.get(route, ""))
	if route == "Bureau" and phase in ["offseason", "ended", "intersaison"]: id = "fond-fin-de-saison"
	var preparation: Variant = ui.get("preparation")
	if route == "Préparation" and preparation is Dictionary and int(preparation.get("tab", 0)) == 2: id = FOND_ENTRAINEMENT
	if route == "Club": id = str(FONDS_CLUB.get(str(ui.get("immersive08_club_tab", "")), id))
	return id if not id.is_empty() and BanqueImages.texture(id) != null else ""

# --- Passerelles publiques : les appelants extérieurs (main_*.gd, navigation, tests) gardent ces noms sur la coque. ---
static func rail_section(route: String) -> Array:
	return Rail.rail_section(route)

static func club_context(model: Dictionary) -> String:
	return Rail.club_context(model)

static func fit_context(context: String, rank: String, room: float) -> Array:
	return Rail.fit_context(context, rank, room)

static func save_now(app: Control) -> void:
	Barre.save_now(app)

static func save_caption(app: Control) -> Array:
	return Barre.save_caption(app)

static func refresh_save_line(app: Control, line: Button = null) -> void:
	Barre.refresh_save_line(app, line)

static func date_caption(model: Dictionary) -> Array:
	return Barre.date_caption(model)

static func sync_continue(app: Control) -> void:
	Barre.sync_continue(app)

static func onglet(caption: String, active: bool, callback: Callable) -> Button:
	return Entete.onglet(caption, active, callback)
