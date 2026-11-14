extends "res://guide/coach_guide.gd"
## Le guide de carrière utilise le portrait 3D quand son GLB est installé (ou le Gabi Mixamo privé,
## voir coach_portrait_3d.gd).
##
## Gabi adjoint (choix de Léo, 13/11/2026 à 23h53 : option « A + C ») :
## A. Gabi vit dans le bandeau du haut (shell.gd, zone « GabiBandeau ») : son visage 3D animé dans un disque,
##    sa remarque du moment sur une ligne (défilante si longue, façon fil d'info), un indice discret (point
##    or et carnet) quand il a quelque chose à dire. Un clic ouvre son avis (« Ton avis, Gabi ? » + menu :
##    aide de l'écran, visite guidée) dans une bulle qui descend du bandeau, se ferme d'un clic ailleurs
##    et ne reste pas ouverte. Il ne recouvre rien et ne prend aucune place : le bandeau existait déjà.
## C. Au Bureau, Gabi est chez lui : debout, en entier (3D animé, carnet contre lui), dans une vraie zone de
##    l'écran (office_canvas.gd, « GabiBureau »), sous son carnet de la semaine (gabi_semaine.gd).
## Conservés de #684 : conseils avec « Suivre le conseil » (composition, recrutement, et au Bureau le conseil
## de la semaine), moments clés en grand avec écran assombri (début de carrière, veille de finale, fin de
## saison, grosse crise), limite d'une bulle spontanée par jour de jeu, réglage pour couper Gabi.
## Le médaillon du coin bas droit, la bande basse réservée et la réduction de la mise en page sont retirés.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const GabiPortrait = preload("res://guide/coach_portrait_3d.gd")
const Avis = preload("res://guide/gabi_avis.gd")
const Semaine = preload("res://guide/gabi_semaine.gd")
const Medaillon = preload("res://guide/gabi_medaillon.gd")
const ACCENT = Color("176e49")
const FOND = Color("10241b")
## Bulle spontanée (première visite d'un écran, conseil de composition) : au plus une par jour de jeu.
## Les autres attendent sous l'indice du bandeau (point or et carnet, remarque dans le fil).
const SPONTANE_PAR_JOUR := 1
## La bulle du bandeau ne reste pas ouverte : elle se ferme d'elle-même après un temps de lecture
## (suspendu tant que la souris est dessus), plus long quand elle propose une action.
const BULLE_DUREE := 8.0
const BULLE_PAR_CARACTERE := 0.05
const BULLE_ACTION := 1.8
## Fil de la remarque : vitesse (pixels physiques par seconde) et pause au début de chaque passage.
const DEFILEMENT := 46.0
const DEFILEMENT_PAUSE := 2.4
const SEPARATEUR := "      ◆      "
## Textes des moments clés (mode grand). Une idée par bulle, phrases prononçables.
const MOMENTS_CLES := {
	"debut": ["bienvenue", "Te voilà dans la maison, coach. Moi, je suis là-haut, dans le bandeau : quand tu veux mon avis, clique sur ma tête. Et au Bureau, c'est chez moi."],
	"finale": ["bureau", "Demain, c'est une finale. Ne change rien qui marche, dors bien, et rappelle-leur qu'une mêlée qui tient, ça fait taire un stade."],
	"crise": ["bureau", "Ça ne va pas, et tout le monde le voit. On ne repeint pas une armoire bancale : on revient aux bases, la conquête, la défense, et on se serre les coudes."],
}

## Portraits hors mode grand : vivants (animés, rendus) mais posés hors de l'écran ; le bandeau et le Bureau
## n'affichent que leur texture.
var _coulisse: Control
## Bandeau du haut (reconstruit à chaque écran par shell.gd).
var _bandeau: Control
## Au Bureau, Gabi en pied tient déjà la colonne : le visage et la remarque du bandeau sont masqués.
var _bandeau_masque := false
var _visage: Control
var _pastille: Panel
var _bandeau_titre: Label
var _fil: Control
var _fil_texte: Label
var _fil_fondu: TextureRect
var _fil_largeur := 0.0
var _fil_decalage := 0.0
var _fil_pause := DEFILEMENT_PAUSE
var _remarque := ""
var _remarque_cle := ""
var _survol := false
## Bulle qui descend du bandeau.
var _bulle: Control
var _bulle_titre: Label
var _bulle_texte: Label
var _bulle_actions: HBoxContainer
var _bulle_menu: HBoxContainer
var _bulle_suivre: Button
var _bulle_reste := 0.0
var _bulle_tween: Tween
var _voile: ColorRect
## Zone de Gabi au Bureau (reconstruite à chaque affichage du Bureau par office_canvas.gd).
var _pied: TextureRect
var _bureau: Control
var _bureau_figure: TextureRect
var _bureau_suivre: Button
var _semaine: Dictionary = {}
## Contenu de la bulle affichée : {genre: avis|menu|contexte|humeur|fait, texte, action, route, cle}.
var _contenu: Dictionary = {}
## Message en attente sous l'indice du bandeau (même forme).
var _attente: Dictionary = {}
## Commandes du conseil suivi, envoyées une à une après chaque réponse du moteur.
var _file: Array = []
var _file_message := ""
var _humeur_cle := ""
var _jour_spontane := ""
var _spontanes := 0
var _ecartes: Dictionary = {}
## Contexte de carrière déjà examiné une fois le bandeau de Gabi en place (moment clé au premier écran).
var _contexte_examine := ""
## Moment clé affiché (clé du profil) : rendu s'il est interrompu par une fenêtre ou un écran bloquant.
var _moment_courant := ""

func _make_portrait() -> TextureRect:
	var model := GabiPortrait.load_model()
	if model == null: return super._make_portrait()
	var display := GabiPortrait.new()
	display.model = model
	return display

func _portrait_extent(short_layout: bool) -> Vector2:
	if not portrait is GabiPortrait: return super._portrait_extent(short_layout)
	var height := app.get_window().size.y
	var side := 320.0 if height >= 1440 else (256.0 if height >= 1080 else 152.0)
	return Vector2(side, side)

func _allows_automatic_speech() -> bool:
	return false

func _request_portrait_gesture(opening: bool) -> void:
	if portrait is GabiPortrait:
		portrait.request_gesture(opening and app._has_career())

func _build() -> void:
	theme=Legacy.theme(ACCENT)
	super._build()
	_title.add_theme_font_override("font",C.BOLD)
	_title.add_theme_font_size_override("font_size",17)
	_title.add_theme_color_override("font_color",C.GOLD)
	_title.add_theme_stylebox_override("normal",_surface(C.BG,C.GOLD))
	_settings_panel.add_theme_stylebox_override("panel",_surface(C.PANEL,C.LINE))
	_error_panel.add_theme_stylebox_override("panel",_surface(Color("282020"),C.ALERT))
	_build_adjoint()

func _label(parent: Node, text: String, size: int = 13) -> Label:
	var label := super._label(parent,text,size)
	label.add_theme_font_override("font",C.BODY)
	label.add_theme_color_override("font_color",C.IVORY)
	return label

func _button(parent: Node, text: String, id: String, action: Callable) -> Button:
	var button := super._button(parent,text,id,action)
	button.add_theme_font_override("font",C.DISPLAY)
	button.add_theme_font_size_override("font_size",16)
	_skin_button(button,false)
	return button

func _primary(button: Button, active: bool) -> void:
	_skin_button(button,active)

func _skin_button(button: Button, active: bool) -> void:
	var color := ACCENT.darkened(.29) if active else C.PANEL
	var edge := C.MINT if active else C.LINE
	button.add_theme_stylebox_override("normal",_surface(color,edge))
	button.add_theme_stylebox_override("hover",_surface(color.lightened(.12),C.GOLD))
	button.add_theme_stylebox_override("pressed",_surface(color.darkened(.16),edge))
	button.add_theme_stylebox_override("disabled",_surface(C.BG,C.LINE))
	var focus := _surface(Color.TRANSPARENT,C.GOLD)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus",focus)
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
		button.add_theme_color_override(state,C.IVORY)
	button.add_theme_color_override("font_disabled_color",C.MUTED)

func _surface(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=color
	style.border_color=Color(border,.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left=7
	style.content_margin_right=7
	style.content_margin_top=3
	style.content_margin_bottom=3
	return style

# --- Construction : coulisse, bulle, voile ---------------------------------------------------------------

func _build_adjoint() -> void:
	_coulisse = Control.new()
	_coulisse.name = "GabiCoulisse"
	_coulisse.top_level = true
	_coulisse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coulisse.position = Vector2(-8192, -8192)
	_coulisse.size = Vector2(4, 4)
	add_child(_coulisse)
	_bulle = Bulle.new()
	_bulle.name = "GabiBulle"
	_bulle.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = FOND
	style.border_color = Color(C.GOLD, .75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, .45)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	for side in [SIDE_LEFT, SIDE_RIGHT]: style.set_content_margin(side, 18)
	style.set_content_margin(SIDE_TOP, 12)
	style.set_content_margin(SIDE_BOTTOM, 14)
	_bulle.add_theme_stylebox_override("panel", style)
	add_child(_bulle)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bulle.add_child(column)
	var head := HBoxContainer.new(); head.mouse_filter = Control.MOUSE_FILTER_IGNORE; column.add_child(head)
	_bulle_titre = Label.new(); _bulle_titre.name = "GabiBulleTitre"
	_bulle_titre.add_theme_font_override("font", C.BOLD)
	_bulle_titre.add_theme_color_override("font_color", C.GOLD)
	_bulle_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bulle_titre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_bulle_titre)
	var fermer := Button.new(); fermer.name = "GabiBulleFermer"; fermer.text = "×"; fermer.flat = true
	fermer.tooltip_text = "Fermer la bulle"
	fermer.focus_mode = Control.FOCUS_NONE
	fermer.add_theme_color_override("font_color", C.MUTED)
	fermer.add_theme_color_override("font_hover_color", C.IVORY)
	fermer.pressed.connect(fermer_bulle)
	head.add_child(fermer)
	_bulle_texte = Label.new(); _bulle_texte.name = "GabiBulleTexte"
	_bulle_texte.add_theme_font_override("font", C.BODY)
	_bulle_texte.add_theme_color_override("font_color", C.IVORY)
	_bulle_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_bulle_texte)
	_bulle_actions = HBoxContainer.new(); _bulle_actions.name = "GabiBulleActions"
	_bulle_actions.add_theme_constant_override("separation", 8)
	_bulle_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_bulle_actions)
	var trait_ := ColorRect.new(); trait_.name = "GabiBulleTrait"; trait_.color = Color(C.GOLD, .22)
	trait_.custom_minimum_size.y = 1; trait_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(trait_)
	_bulle_menu = HBoxContainer.new(); _bulle_menu.name = "GabiBulleMenu"
	_bulle_menu.add_theme_constant_override("separation", 8)
	_bulle_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_bulle_menu)
	_bulle.hide()
	_voile = ColorRect.new()
	_voile.name = "GabiVoile"
	_voile.color = Color(0.02, 0.05, 0.04, 0.55)
	_voile.mouse_filter = Control.MOUSE_FILTER_STOP
	_voile.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed: close())
	_voile.hide()

## Bandeau de Gabi en service : carrière ouverte, Gabi activé, zone du bandeau construite par shell.gd.
func _adjoint_actif() -> bool:
	if not is_instance_valid(app) or not is_instance_valid(_bulle) or not app._has_career(): return false
	if not profile.data.enabled: return false
	return is_instance_valid(_bandeau) and _bandeau.is_inside_tree() and _bandeau.is_visible_in_tree() and (_bandeau.size.x >= 40.0 or _bandeau_masque)

## Mode grand (moments clés, aide, visite) ou écran sans bandeau : le portrait rejoint la grande bulle.
## Sinon il reste en coulisse, cadré sur le visage, et le bandeau affiche sa texture.
func _place_portrait() -> void:
	if not is_instance_valid(portrait) or not is_instance_valid(_coulisse): return
	var grand := expanded or not _adjoint_actif()
	if grand and portrait.get_parent() != _body:
		if portrait.get_parent() != null: portrait.get_parent().remove_child(portrait)
		_body.add_child(portrait); _body.move_child(portrait, 0)
		_balloon.speaker = portrait
		if portrait.has_method("set_framing"): portrait.set_framing("portrait")
	elif not grand and portrait.get_parent() != _coulisse:
		if portrait.get_parent() != null: portrait.get_parent().remove_child(portrait)
		_coulisse.add_child(portrait)
		portrait.position = Vector2.ZERO
		portrait.size = Vector2(4, 4)
		if portrait.has_method("set_framing"): portrait.set_framing("visage")

func _layout() -> void:
	if not is_instance_valid(_compact): return
	_place_portrait()
	super._layout()
	if not is_instance_valid(_bulle): return
	var actif := _adjoint_actif()
	_compact.visible = not expanded and not actif
	# Mode grand : une scène sous le bandeau ; changer de coin n'a plus de sens.
	var move: Control = find_child("GuideMove", true, false)
	if is_instance_valid(move): move.visible = not actif
	if not actif or expanded: _bulle.hide()
	_layout_voile()
	var reduced: bool = is_instance_valid(app.user_preferences) and bool(app.user_preferences.data.get("reduced_motion", false))
	if is_instance_valid(_visage): _visage.reduced_motion = reduced
	if _bulle.visible: _layout_bulle()

func _layout_voile() -> void:
	if not is_instance_valid(_voile): return
	if not is_instance_valid(app) or get_parent() != app: return
	if _voile.get_parent() != app: app.add_child(_voile)
	# Juste sous Gabi : même plan (z_index), dessiné avant lui.
	_voile.z_index = z_index
	var target := get_index()
	if _voile.get_index() > target: app.move_child(_voile, target)
	elif _voile.get_index() < target - 1: app.move_child(_voile, target - 1)
	_voile.position = Vector2.ZERO
	_voile.size = app.size
	_voile.visible = expanded and visible

# --- A. Le bandeau du haut ------------------------------------------------------------------------------

## Appelé par shell.gd à chaque construction du bandeau : visage, remarque du moment, indice.
func installer_bandeau(zone: Control) -> void:
	_bandeau = zone
	_bandeau_masque = bool(zone.get_meta("masque", false))
	_visage = null
	if not is_instance_valid(app) or not profile.data.enabled or not app._has_career():
		zone.hide()
		return
	_place_portrait()
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE if _bandeau_masque else Control.MOUSE_FILTER_STOP
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zone.focus_mode = Control.FOCUS_NONE if _bandeau_masque else Control.FOCUS_ALL
	zone.tooltip_text = "Gabi, ton adjoint · clic : son avis sur cet écran, l'aide, la visite guidée"
	_pastille = Panel.new()
	_pastille.name = "GabiPastille"
	_pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(_pastille)
	_visage = Medaillon.new()
	zone.add_child(_visage)
	_visage.afficher(portrait)
	_bandeau_titre = Label.new()
	_bandeau_titre.name = "GabiBandeauTitre"
	_bandeau_titre.add_theme_font_override("font", C.BOLD)
	_bandeau_titre.add_theme_color_override("font_color", C.GOLD)
	_bandeau_titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bandeau_titre.clip_text = true
	zone.add_child(_bandeau_titre)
	_fil = Control.new()
	_fil.name = "GabiFil"
	_fil.clip_contents = true
	_fil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(_fil)
	_fil_texte = Label.new()
	_fil_texte.name = "GabiRemarque"
	_fil_texte.add_theme_font_override("font", C.BODY)
	_fil_texte.add_theme_color_override("font_color", C.IVORY)
	_fil_texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fil.add_child(_fil_texte)
	_fil_fondu = TextureRect.new()
	_fil_fondu.name = "GabiFilFondu"
	_fil_fondu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.set_color(0, Color(FOND, 0.0)); gradient.set_color(1, FOND)
	var fade := GradientTexture2D.new(); fade.gradient = gradient; fade.width = 32; fade.height = 2
	_fil_fondu.texture = fade
	_fil_fondu.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fil_fondu.stretch_mode = TextureRect.STRETCH_SCALE
	_fil.add_child(_fil_fondu)
	zone.gui_input.connect(_entree_bandeau)
	zone.mouse_entered.connect(func(): _survol = true; _style_pastille())
	zone.mouse_exited.connect(func(): _survol = false; _style_pastille())
	zone.resized.connect(_disposer_bandeau)
	_remarque_cle = ""
	if _bandeau_masque:
		for masque: Control in [_pastille, _visage, _bandeau_titre, _fil]: masque.hide()
	_disposer_bandeau()
	_maj_indice()

func _style_pastille() -> void:
	if not is_instance_valid(_pastille): return
	var style := StyleBoxFlat.new()
	style.bg_color = FOND.lightened(.06) if _survol else FOND
	style.border_color = Color(C.GOLD, .7 if _survol else .38)
	style.set_border_width_all(1)
	style.set_corner_radius_all(maxi(4, roundi(_pastille.size.y * .5)))
	_pastille.add_theme_stylebox_override("panel", style)
	if is_instance_valid(_visage): _visage.set_hover(_survol)

func _disposer_bandeau() -> void:
	if not is_instance_valid(_bandeau) or not is_instance_valid(_visage): return
	var s := _bandeau.size
	var h := s.y
	var d := roundf(h * 0.97)
	_visage.position = Vector2(0, (h - d) / 2.0)
	_visage.size = Vector2(d, d)
	_pastille.position = Vector2(d * 0.5, h * 0.1)
	_pastille.size = Vector2(maxf(0.0, s.x - d * 0.5), h * 0.8)
	_style_pastille()
	var left := d + h * 0.2
	var title_px := maxi(12, roundi(h * 0.235))
	var line_px := maxi(13, roundi(h * 0.31))
	_bandeau_titre.add_theme_font_size_override("font_size", title_px)
	_fil_texte.add_theme_font_size_override("font_size", line_px)
	var title_h := C.BOLD.get_height(title_px)
	var line_h := C.BODY.get_height(line_px)
	var top := (h - title_h - line_h) / 2.0
	_bandeau_titre.position = Vector2(left, top)
	_bandeau_titre.size = Vector2(maxf(0.0, s.x - left - h * 0.4), title_h)
	_fil.position = Vector2(left, top + title_h)
	_fil.size = Vector2(maxf(0.0, s.x - left - h * 0.4), line_h)
	_fil_texte.position.y = 0
	_fil_texte.size.y = line_h
	_fil_fondu.position = Vector2(_fil.size.x - h * 0.5, 0)
	_fil_fondu.size = Vector2(h * 0.5, line_h)
	# Rendu net : deux fois les pixels physiques du disque, ni plus ni moins.
	var physical := d * _bandeau.get_global_transform_with_canvas().get_scale().y
	if _bandeau_masque: return
	if portrait is GabiPortrait and portrait.framing == "visage": portrait.set_render_size(Vector2i.ONE * roundi(physical * 2.0))
	_fil_regle(true)

func _entree_bandeau(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_bandeau.accept_event()
		_clic_bandeau()
	elif event.is_action_pressed("ui_accept"):
		_bandeau.accept_event()
		_clic_bandeau()

func _blocked_adjoint() -> bool:
	return _blocked() or not _adjoint_actif()

## Clic sur Gabi (bandeau ou Bureau) : le message en attente, sinon son avis sur l'écran (+ menu).
func _clic_bandeau() -> void:
	if _blocked_adjoint(): return
	if _bulle.visible: fermer_bulle(); return
	if not _attente.is_empty() and _attente.get("route") == str(app.route):
		var message := _attente.duplicate(true)
		_consommer(message)
		_montrer(message)
		return
	demander_avis()

## « Ton avis, Gabi ? » : avis contextuel de l'écran affiché.
func demander_avis() -> void:
	if _blocked_adjoint(): return
	var avis := Avis.avis(str(app.route), app.model, _focus_recrutement())
	if not _attente.is_empty() and _attente.get("genre") == "avis" and _attente.get("route") == str(app.route): _attente.clear()
	if avis.is_empty():
		_montrer({"genre": "menu", "titre": "TON AVIS, GABI ?", "texte": "Ici, je te laisse faire, coach. Si tu veux, je te montre comment marche cet écran, ou toute la maison.", "categorie": "question", "ton": Avis.NEUTRE})
		return
	_montrer(avis.merged({"genre": "avis", "titre": "TON AVIS, GABI ?"}))

## Joueur du marché dont le dossier est ouvert (écran Recrutement).
func _focus_recrutement() -> String:
	if str(app.route) != "Recrutement" or not is_instance_valid(app.root_content): return ""
	var dossier: Control = app.root_content.find_child("RecruitmentProfile", true, false)
	return str(dossier.get_meta("player_id", "")) if is_instance_valid(dossier) else ""

## Remarque du moment (fil du bandeau) : le message en attente, sinon l'avis de l'écran, sinon l'aide.
func _maj_remarque() -> void:
	if not is_instance_valid(_fil_texte) or not is_instance_valid(app): return
	var live: Dictionary = app._live()
	var running: bool = not live.is_empty() and not live.get("paused", false) and not live.get("finished", false)
	var focus := _focus_recrutement()
	var cle := "%s|%s|%s|%s|%s|%s|%s" % [app.route, _career_context(app.model), _attente.get("texte", ""), app.model.get("meta", {}).get("calendarToday", ""), running, focus, app.model.get("selection", {}).hash() if app.route in ["Composition", "Match"] else 0]
	if cle == _remarque_cle: return
	_remarque_cle = cle
	var texte := ""
	var titre := "GABI · TON ADJOINT"
	if not _attente.is_empty():
		texte = str(_attente.get("texte", ""))
		titre = "GABI · UN MOT POUR TOI"
	elif running:
		texte = "Je regarde le match avec toi. On en reparle après le coup de sifflet."
		titre = "GABI · EN TRIBUNE"
	else:
		texte = str(Avis.avis(str(app.route), app.model, focus).get("texte", ""))
		if texte.is_empty():
			var fragments: Array = Content.fragments(Content.for_route(str(app.route), app.model))
			if not fragments.is_empty(): texte = str(fragments[mini(1, fragments.size() - 1)].get("text", ""))
	_bandeau_titre.text = titre
	_bandeau_titre.add_theme_color_override("font_color", C.GOLD if _attente.is_empty() else C.AMBER)
	if texte != _remarque:
		_remarque = texte
		_fil_regle(true)

## Prépare le fil : texte simple s'il tient, sinon texte + séparateur + texte pour défiler en boucle.
func _fil_regle(reset: bool) -> void:
	if not is_instance_valid(_fil_texte) or not is_instance_valid(_fil): return
	var px := _fil_texte.get_theme_font_size("font_size")
	var width := C.BODY.get_string_size(_remarque, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var reduced: bool = is_instance_valid(app.user_preferences) and bool(app.user_preferences.data.get("reduced_motion", false))
	var defile := width > _fil.size.x and not reduced
	_fil_largeur = C.BODY.get_string_size(_remarque + SEPARATEUR, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x if defile else 0.0
	_fil_texte.text = _remarque + SEPARATEUR + _remarque if defile else _remarque
	_fil_texte.tooltip_text = _remarque
	_fil_texte.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if defile else TextServer.OVERRUN_TRIM_ELLIPSIS
	_fil_texte.size.x = C.BODY.get_string_size(_fil_texte.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 4.0 if defile else _fil.size.x
	_fil_fondu.visible = defile or width > _fil.size.x
	if reset:
		_fil_decalage = 0.0
		_fil_pause = DEFILEMENT_PAUSE
	_fil_texte.position.x = -_fil_decalage

func _defiler(delta: float) -> void:
	if not is_instance_valid(_fil_texte) or _fil_largeur <= 0.0 or not _fil_texte.is_visible_in_tree(): return
	if _survol or (is_instance_valid(_bulle) and _bulle.visible): return
	if _fil_pause > 0.0:
		_fil_pause -= delta
		return
	var scale_ := maxf(0.01, _fil.get_global_transform_with_canvas().get_scale().x)
	_fil_decalage += DEFILEMENT * delta / scale_
	if _fil_decalage >= _fil_largeur:
		_fil_decalage = 0.0
		_fil_pause = DEFILEMENT_PAUSE
	_fil_texte.position.x = -roundf(_fil_decalage * scale_) / scale_

# --- La bulle qui descend du bandeau ------------------------------------------------------------------

func _montrer(contenu: Dictionary) -> void:
	_contenu = contenu.duplicate(true)
	_contenu.route = str(app.route)
	_bulle_titre.text = str(contenu.get("titre", "GABI"))
	_bulle_texte.text = str(contenu.get("texte", ""))
	for row in [_bulle_actions, _bulle_menu]:
		for child in row.get_children():
			row.remove_child(child); child.queue_free()
	_bulle_suivre = null
	var action: Dictionary = contenu.get("action", {}) if contenu.get("action") is Dictionary else {}
	if not action.is_empty():
		_bulle_suivre = _button(_bulle_actions, str(action.get("libelle", "Suivre le conseil")), "GabiSuivreConseil", suivre_conseil)
		_primary(_bulle_suivre, true)
		_bulle_suivre.disabled = app.waiting or not app._live().is_empty()
		_bulle_suivre.tooltip_text = "Applique la proposition de Gabi (tu peux toujours la défaire)"
		_button(_bulle_actions, "Je garde mon idée", "GabiIgnorer", func(): _ecarter(); fermer_bulle())
	_bulle_actions.visible = _bulle_actions.get_child_count() > 0
	if contenu.get("genre") != "fait":
		if contenu.get("genre") != "avis" and not Avis.ecran(str(app.route), app.model).is_empty():
			_button(_bulle_menu, "Ton avis, Gabi ?", "GabiMenuAvis", demander_avis)
		_button(_bulle_menu, "Aide de l'écran", "GabiMenuAide", func(): fermer_bulle(); open_help())
		_button(_bulle_menu, "Visite guidée", "GabiMenuVisite", func(): fermer_bulle(); open_tour())
	_bulle_menu.visible = _bulle_menu.get_child_count() > 0
	_bulle_menu.get_parent().get_node("GabiBulleTrait").visible = _bulle_menu.visible and _bulle_actions.visible
	var was_open := _bulle.visible
	_bulle.show()
	_bulle_reste = (BULLE_DUREE + _bulle_texte.text.length() * BULLE_PAR_CARACTERE) * (BULLE_ACTION if not action.is_empty() else 1.0)
	_layout_bulle()
	call_deferred("_layout_bulle")
	if not was_open: _descendre()
	_moment_portraits({"id": "adjoint:" + str(hash(_bulle_texte.text)), "categorie": str(contenu.get("categorie", "consigne")), "ton": str(contenu.get("ton", Avis.NEUTRE))})
	if portrait.has_method("mime"): portrait.mime(_bulle_texte.text)
	_maj_indice()

## Geste de Gabi (catégorie et ton du moment) dans le bandeau et, s'il est affiché, au Bureau.
func _moment_portraits(moment: Dictionary) -> void:
	if portrait.has_method("set_moment"): portrait.set_moment(moment)
	if is_instance_valid(_pied) and _pied.has_method("set_moment"): _pied.set_moment(moment)

## La bulle descend du bandeau (sans animation si le mouvement est réduit).
func _descendre() -> void:
	if _bulle_tween != null: _bulle_tween.kill()
	_layout_bulle()
	var reduced: bool = is_instance_valid(app.user_preferences) and bool(app.user_preferences.data.get("reduced_motion", false))
	if reduced:
		_bulle.modulate.a = 1.0
		return
	var target := _bulle.position
	_bulle.position.y = target.y - 14.0
	_bulle.modulate.a = 0.0
	_bulle_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bulle_tween.tween_property(_bulle, "position:y", target.y, 0.18)
	_bulle_tween.tween_property(_bulle, "modulate:a", 1.0, 0.14)

func _layout_bulle() -> void:
	if not is_instance_valid(_bulle) or not _bulle.visible: return
	if not is_instance_valid(_bandeau) or not _bandeau.is_inside_tree(): return
	var zone := _bandeau.get_global_rect()
	var face := _visage.get_global_rect() if is_instance_valid(_visage) else zone
	var topbar := (_bandeau.get_parent() as Control).get_global_rect() if _bandeau.get_parent() is Control else zone
	var px := clampi(roundi(app.size.y / 1080.0 * 17.0), 14, 24)
	_bulle_texte.add_theme_font_size_override("font_size", px)
	_bulle_titre.add_theme_font_size_override("font_size", px - 1)
	var bouton := (_bulle.find_child("GabiBulleFermer", true, false) as Button)
	bouton.add_theme_font_size_override("font_size", px + 4)
	for row in [_bulle_actions, _bulle_menu]:
		for button in row.get_children():
			if button is Button:
				button.add_theme_font_size_override("font_size", px - (2 if row == _bulle_menu else 0))
				button.custom_minimum_size.y = roundf(px * 2.0)
	var width := clampf(app.size.x * 0.3, 380.0, 660.0)
	width = maxf(width, _bulle_actions.get_combined_minimum_size().x + 40.0)
	width = maxf(width, _bulle_menu.get_combined_minimum_size().x + 40.0)
	_bulle_texte.custom_minimum_size.x = width - 36.0
	_bulle.size = Vector2(width, 0)
	_bulle.reset_size()
	var height := _bulle.get_combined_minimum_size().y
	_bulle.size = Vector2(width, height)
	var x := clampf(face.position.x - 22.0, 8.0, app.size.x - width - 8.0)
	var y := topbar.end.y + 12.0
	if _bandeau_masque and is_instance_valid(_bureau_figure) and _bureau_figure.is_inside_tree():
		# Visage masqué : la bulle sort de la colonne de Gabi, à sa gauche, sans pointe vers le bandeau.
		var colonne: Rect2 = (_bureau_figure.get_parent() as Control).get_global_rect()
		x = clampf(colonne.position.x - width - 16.0, 8.0, app.size.x - width - 8.0)
		# À hauteur de la tête de Gabi (elle parle), pas en haut de l'écran où elle cacherait les priorités.
		var tete := _bureau_figure.get_global_rect().position.y + _bureau_figure.get_global_rect().size.y * 0.16
		y = clampf(tete - 56.0, y, maxf(y, app.size.y - height - 12.0))
		_bulle.vers_droite = true
		_bulle.pointe_y = clampf(tete - y, 24.0, height - 24.0)
	else: _bulle.vers_droite = false
	if _bulle_tween == null or not _bulle_tween.is_running(): _bulle.global_position = Vector2(x, y)
	else: _bulle.global_position.x = x
	_bulle.pointe_x = clampf(face.get_center().x - x, 24.0, width - 24.0)
	_bulle.queue_redraw()

func fermer_bulle() -> void:
	if is_instance_valid(_bulle): _bulle.hide()
	_contenu.clear()
	if is_instance_valid(_visage): _maj_indice()

## Un clic ailleurs ferme la bulle (le clic continue vers ce qu'il visait) ; Échap aussi.
func _input(event: InputEvent) -> void:
	if not is_instance_valid(_bulle) or not _bulle.visible: return
	if event is InputEventMouseButton and event.pressed:
		var at: Vector2 = event.position
		if _bulle.get_global_rect().grow(4).has_point(at): return
		if is_instance_valid(_bandeau) and _bandeau.get_global_rect().has_point(at): return
		if is_instance_valid(_bureau_figure) and _bureau_figure.is_visible_in_tree() and _bureau_figure.get_global_rect().has_point(at): return
		fermer_bulle()
	elif event.is_action_pressed("ui_cancel"):
		fermer_bulle()
		get_viewport().set_input_as_handled()

func _ecarter() -> void:
	var cle := _cle_conseil(str(app.route))
	if not cle.is_empty(): _ecartes[cle] = true
	_attente.clear(); _maj_indice()

func _cle_conseil(route: String) -> String:
	return Avis.ecran(route, app.model) + ":" + _career_context(app.model)

# --- « Suivre le conseil » ---------------------------------------------------------------------------

func suivre_conseil(action_: Dictionary = {}) -> void:
	var action: Dictionary = action_ if not action_.is_empty() else (_contenu.get("action", {}) if _contenu.get("action") is Dictionary else {})
	if action.is_empty() or app.waiting or not app._live().is_empty(): return
	_file.clear()
	match str(action.get("type", "")):
		"ecran":
			fermer_bulle()
			var route := str(action.get("route", ""))
			if route == "Entraînement": app.Immersive.open_training(app)
			elif not route.is_empty(): app._navigate(route)
			return
		"composition":
			for change: Dictionary in action.get("changements", []):
				_file.append({"command": "set_lineup", "payload": {"playerId": str(change.playerId), "slot": int(change.slot)}})
			_file_message = "C'est fait. Si tu n'es pas d'accord, remets-le : c'est toi qui signes la feuille."
		"recrutement":
			var id := str(action.get("playerId", ""))
			var context: Variant = app.model.get("clubLife", {}).get("managerCareer", {}).get("context")
			var watched: bool = id in app.management_ui.get("shortlist", [])
			var verdict := str(action.get("verdict", ""))
			if context is Dictionary and ((verdict in ["fonce", "a_suivre"] and not watched) or (verdict == "passe" and watched)):
				_file.append({"command": "manager_recruitment_watch", "payload": {"context": context.duplicate(true), "playerId": id}})
			_file_message = {"fonce": "Je l'ai mis en tête de ta liste. Approche-le maintenant, sans surenchérir.", "a_suivre": "Il est dans ta liste. On le regarde jouer avant de parler argent.", "passe": "Rayé de la liste. Le bon, on le trouvera."}.get(verdict, "C'est noté.")
			if verdict == "fonce": _file.append({"ouvrir_contrat": id})
	_ecarter()
	_suite_file()

func _suite_file() -> void:
	if app.waiting: return
	if _file.is_empty():
		if not _file_message.is_empty():
			var message := _file_message
			_file_message = ""
			_montrer({"genre": "fait", "titre": "GABI", "texte": message, "categorie": "approbation", "ton": Avis.POSITIF})
		return
	var next: Dictionary = _file.pop_front()
	if next.has("ouvrir_contrat"):
		var player := Avis.marche(app.model, str(next.ouvrir_contrat))
		if not player.is_empty():
			fermer_bulle()
			app.SquadViews.contract(app, player, true)
		_suite_file()
		return
	if not app._command(str(next.command), next.payload):
		_file.clear(); _file_message = ""

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(_bulle): return
	if (not _file.is_empty() or not _file_message.is_empty()) and not app.waiting:
		if not app.bridge.last_response_ok or not str(app.last_error).is_empty():
			_file.clear(); _file_message = ""
			_montrer({"genre": "fait", "titre": "GABI", "texte": "Le changement n'est pas passé : " + str(app.last_error) + " On regardera autrement.", "categorie": "regret", "ton": Avis.NEGATIF})
		else:
			_suite_file()
	if _bulle.visible:
		if _contenu.get("route", "") != str(app.route) or not _adjoint_actif(): fermer_bulle()
		elif _file.is_empty() and not _bulle.get_global_rect().has_point(get_viewport().get_mouse_position()):
			_bulle_reste -= delta
			if _bulle_reste <= 0.0: fermer_bulle()
	# Le premier écran d'une carrière se construit avant le bandeau : on réexamine le contexte une fois
	# Gabi en place (début de carrière, première visite).
	if not app.waiting and not expanded and _adjoint_actif():
		var context := _career_context(app.model)
		if not context.is_empty() and context + "|" + str(app.route) != _contexte_examine:
			_contexte_examine = context + "|" + str(app.route)
			consider_context(str(app.route), app.model, "", true)
	if is_instance_valid(_bulle_suivre) and _bulle.visible: _bulle_suivre.disabled = app.waiting or not app._live().is_empty()
	if _adjoint_actif():
		_maj_remarque()
		if not _bandeau_masque: _defiler(delta)
	_maj_pied()

# --- C. Gabi chez lui, au Bureau -------------------------------------------------------------------------

## Le Bureau réserve une zone à Gabi quand il est activé, en carrière (sinon : mise en page classique).
func bureau_disponible() -> bool:
	return is_instance_valid(app) and is_instance_valid(_bulle) and app._has_career() and profile.data.enabled

## Appelé par office_canvas.gd : carnet de la semaine (synthèse et conseil) au-dessus, Gabi debout dessous.
func installer_bureau(zone: Control) -> void:
	_bureau = zone
	_semaine = Semaine.synthese(app.model)
	zone.resized.connect(_disposer_bureau.bind(zone))
	_disposer_bureau(zone)
	var conseil: Dictionary = _semaine.get("conseil", {})
	if is_instance_valid(_pied) and _pied.has_method("set_moment") and not conseil.is_empty():
		_pied.set_moment({"id": "semaine:" + _career_context(app.model) + ":" + str(hash(conseil.get("texte", ""))), "categorie": str(conseil.get("categorie", "consigne")), "ton": str(conseil.get("ton", Avis.NEUTRE))})

func _couleur(nom: String) -> Color:
	return {"or": C.GOLD, "menthe": C.MINT, "ambre": C.AMBER, "rouge": C.ALERT}.get(nom, C.GOLD)

func _disposer_bureau(zone: Control) -> void:
	if not is_instance_valid(zone) or zone != _bureau: return
	for child in zone.get_children():
		zone.remove_child(child); child.queue_free()
	_bureau_figure = null
	_bureau_suivre = null
	var w := zone.size.x / C.density
	var h := zone.size.y / C.density
	if w < 120 or h < 200: return
	var pad := 22.0
	var text_w := w - pad * 2 - 34
	# Carnet de la semaine : un panneau vert sombre cerclé d'or, avec une pointe vers Gabi.
	var carnet := Carnet.new()
	carnet.name = "GabiCarnet"
	carnet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(carnet)
	var y := 40.0
	var titre := D.text(carnet, pad, y, "TA SEMAINE, VUE PAR GABI", 21, C.GOLD, 700, w - pad * 2)
	titre.name = "GabiCarnetTitre"
	y += 14
	D.line(carnet, Vector2(pad, y), Vector2(w - pad, y), Color(C.GOLD, .3))
	y += 12
	var lignes: Array = _semaine.get("lignes", [])
	for ligne: Dictionary in lignes:
		y = _ligne_carnet(carnet, pad, y, text_w, str(ligne.get("libelle", "")), str(ligne.get("texte", "")), str(ligne.get("icone", "info")), _couleur(str(ligne.get("couleur", "or"))), "GabiLigne_" + str(ligne.get("cle", "")))
	var conseil: Dictionary = _semaine.get("conseil", {})
	if not conseil.is_empty():
		y = _ligne_carnet(carnet, pad, y, text_w, "MON CONSEIL", str(conseil.get("texte", "")), "star", C.GOLD, "GabiLigne_conseil")
		var action: Dictionary = conseil.get("action", {}) if conseil.get("action") is Dictionary else {}
		if not action.is_empty():
			_bureau_suivre = D.button(carnet, Rect2(pad + 34, y - 2, w - pad * 2 - 34, 42), str(action.get("libelle", "Suivre le conseil")), suivre_conseil.bind(action), true, "arrow", true, ACCENT, "GabiBureauSuivre")
			_bureau_suivre.tooltip_text = str(action.get("detail", "Applique la proposition de Gabi (tu peux toujours la défaire)"))
			_bureau_suivre.disabled = app.waiting or not app._live().is_empty()
			y += 42 + 16
	var carnet_h := y + 6
	D.place(carnet, Rect2(0, 0, w, carnet_h))
	# Gabi debout, en entier, sous son carnet : il occupe le reste de la zone, pieds en bas.
	var top := carnet_h + 18
	var figure_h := h - top - 4
	if figure_h < 140: return
	# Chez lui : une lumière chaude derrière Gabi, comme une lampe de bureau, et son ombre au sol.
	var halo := TextureRect.new()
	halo.name = "GabiHalo"
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := Gradient.new()
	glow.set_color(0, Color(C.GOLD, .13)); glow.set_color(1, Color(C.GOLD, 0.0))
	var radial := GradientTexture2D.new()
	radial.gradient = glow; radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(.5, .5); radial.fill_to = Vector2(.5, 0.0)
	radial.width = 128; radial.height = 128
	halo.texture = radial
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	zone.add_child(halo)
	D.place(halo, Rect2(-w * .15, top - 20, w * 1.3, figure_h * .95))
	var sol := Sol.new()
	sol.name = "GabiSol"
	sol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(sol)
	D.place(sol, Rect2(w * .18, h - 40, w * .64, 30))
	_bureau_figure = TextureRect.new()
	_bureau_figure.name = "GabiBureauFigure"
	_bureau_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bureau_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bureau_figure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bureau_figure.mouse_filter = Control.MOUSE_FILTER_STOP
	_bureau_figure.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bureau_figure.tooltip_text = "Gabi · clic : son avis"
	_bureau_figure.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_bureau_figure.accept_event(); _clic_bandeau())
	zone.add_child(_bureau_figure)
	D.place(_bureau_figure, Rect2(0, top, w, figure_h))
	carnet.pointe_x = zone.size.x * 0.5
	var source := _source_pied()
	if source == null: return
	_bureau_figure.texture = source.texture
	_bureau_figure.material = source.material if not source is GabiPortrait else null
	if source is GabiPortrait:
		var physical := _bureau_figure.size * _bureau_figure.get_global_transform_with_canvas().get_scale().y
		if physical.x < 8: physical = _bureau_figure.size
		source.set_render_size(Vector2i(roundi(physical.x * 1.25), roundi(physical.y * 1.25)))

## Gabi en pied : un second portrait 3D (même modèle), cadré en entier ; repli : le portrait 2D du guide.
func _source_pied() -> TextureRect:
	if not portrait is GabiPortrait: return portrait
	if not is_instance_valid(_pied):
		_pied = GabiPortrait.new()
		_pied.model = portrait.model
		_pied.framing = "pied"
		_pied.name = "GabiPortraitPied"
		_coulisse.add_child(_pied)
		_pied.size = Vector2(4, 4)
		_pied.visible = false
		var reduced: bool = is_instance_valid(app.user_preferences) and bool(app.user_preferences.data.get("reduced_motion", false))
		_pied.set_reduced_motion(reduced)
	return _pied

## Gabi en pied ne vit (et ne se rend) que pendant l'affichage du Bureau.
func _maj_pied() -> void:
	if not is_instance_valid(_pied): return
	var montrer := is_instance_valid(_bureau_figure) and _bureau_figure.is_visible_in_tree() and visible
	if _pied.visible != montrer: _pied.visible = montrer
	if montrer and is_instance_valid(_bureau_suivre): _bureau_suivre.disabled = app.waiting or not app._live().is_empty()

func _ligne_carnet(parent: Control, pad: float, y: float, text_w: float, libelle: String, texte: String, icone: String, couleur: Color, id: String) -> float:
	var icon := C.icon(icone, 20, couleur)
	parent.add_child(icon)
	D.place(icon, Rect2(pad, y + 2, 20, 20))
	D.text(parent, pad + 34, y + 17, libelle, 16, couleur, 700, text_w).name = id + "_libelle"
	var label := Label.new()
	label.name = id
	label.text = texte
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", C.BODY)
	var px := maxi(12, C.px(19))
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", C.IVORY)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	var height := C.BODY.get_multiline_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, C.px(text_w), px).y / C.density
	D.place(label, Rect2(pad + 34, y + 24, text_w, height + 2))
	return y + 24 + height + 16

## Panneau du carnet, avec une pointe vers Gabi (en bas).
class Carnet extends Control:
	var pointe_x := 0.0
	func _draw() -> void:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("10241b")
		style.border_color = Color(Color("d7ad59"), .55)
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		if pointe_x <= 0: return
		var w := 14.0
		var points := PackedVector2Array([Vector2(pointe_x - w, size.y - 1), Vector2(pointe_x, size.y + 14), Vector2(pointe_x + w, size.y - 1)])
		draw_colored_polygon(points, style.bg_color)
		draw_polyline(points, style.border_color, 1.0, true)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: queue_redraw()

## Ombre au sol sous les pieds de Gabi.
class Sol extends Control:
	func _draw() -> void:
		var center := size / 2.0
		for i in 5:
			var k := 1.0 - i * 0.18
			draw_set_transform(center, 0.0, Vector2(1.0, size.y / maxf(1.0, size.x)))
			draw_circle(Vector2.ZERO, size.x * 0.5 * k, Color(0, 0, 0, 0.09))
		draw_set_transform(Vector2.ZERO)

## Bulle du bandeau : panneau vert sombre cerclé d'or, pointe vers le visage de Gabi (en haut).
class Bulle extends PanelContainer:
	var pointe_x := 40.0
	## Au Bureau (visage du bandeau masqué), la bulle sort à gauche de Gabi en pied : pointe vers la droite.
	var vers_droite := false
	var pointe_y := 40.0
	func _draw() -> void:
		var style := get_theme_stylebox("panel") as StyleBoxFlat
		if style == null: return
		var w := 13.0
		if vers_droite:
			var cote := PackedVector2Array([Vector2(size.x - 1, pointe_y - w), Vector2(size.x + 12, pointe_y), Vector2(size.x - 1, pointe_y + w)])
			draw_colored_polygon(cote, style.bg_color)
			draw_polyline(cote, style.border_color, 1.0, true)
			draw_line(cote[0] + Vector2(-0.5, 1), cote[2] + Vector2(-0.5, -1), style.bg_color, 2.0)
			return
		var points := PackedVector2Array([Vector2(pointe_x - w, 1), Vector2(pointe_x, -12), Vector2(pointe_x + w, 1)])
		draw_colored_polygon(points, style.bg_color)
		draw_polyline(points, style.border_color, 1.0, true)
		draw_line(points[0] + Vector2(1, 0.5), points[2] + Vector2(-1, 0.5), style.bg_color, 2.0)

# --- Contexte : moments clés, première visite, humeur, indice ----------------------------------------

func consider_context(route: String, model: Dictionary, command: String, response_ok: bool) -> void:
	if is_instance_valid(_bulle) and is_instance_valid(app) and app._has_career() and profile.data.enabled and route not in ["Accueil", "Création", "Packs"] and not _adjoint_actif():
		# Écran de carrière dont le bandeau n'est pas encore construit : on attend qu'il le soit (_process)
		# plutôt que d'ouvrir l'ancienne bulle flottante.
		var live: Dictionary = app._live()
		if live.is_empty() or live.get("finished", false):
			_contexte_examine = ""
			return
	if not is_instance_valid(_bulle) or not _adjoint_actif():
		super.consider_context(route, model, command, response_ok)
		return
	if not response_ok or app.waiting or app.closing or expanded: return
	if app.connection_error or not str(app.last_error).is_empty(): return
	_humeur(model)
	if _blocked(): return
	if _moment_cle(model): return
	super.consider_context(route, model, command, response_ok)
	_conseil_composition(route, model)
	_alerte_fatigue(model)
	_maj_indice()

## Moments clés (mode grand, écran assombri) : une seule fois chacun (clé dans le profil du guide).
func _moment_cle(model: Dictionary) -> bool:
	var context := _career_context(model)
	if context.is_empty(): return false
	var parts := context.split(":")
	var keys := {
		"debut": "debut:%s:%s:0:" % [parts[0], parts[1]],
		"finale": "finale:%s:%s:%s:" % [parts[0], parts[1], parts[2]],
		"crise": "crise:%s:%s:0:" % [parts[0], parts[1]],
	}
	var due := ""
	if keys.debut not in profile.data.events: due = "debut"
	elif Avis.finale(model) and keys.finale not in profile.data.events: due = "finale"
	elif Avis.crise(model) and keys.crise not in profile.data.events: due = "crise"
	if due.is_empty(): return false
	var moment: Array = MOMENTS_CLES[due]
	super._deliver_context(moment[0], {"id": "moment-" + due, "text": moment[1]}, "", keys[due])
	_moment_courant = keys[due] if expanded else ""
	return true

## Première visite d'un écran, contrat signé, fin de saison, trésorerie : la fin de saison et un compte
## dans le rouge sont des moments clés (mode grand) ; le reste passe par le bandeau (bulle ou indice).
func _deliver_context(id: String, fragment: Dictionary, visit: String, event: String) -> void:
	if not _adjoint_actif() or event.begins_with("season:") or event.begins_with("cash:"):
		super._deliver_context(id, fragment, visit, event)
		return
	var fragments: Array = Content.fragments(id)
	var short: Dictionary = fragment
	# La bulle du bandeau prend la version courte (première bulle numérotée) plutôt que le portrait complet.
	if event.is_empty() and fragments.size() > 1 and str(fragment.get("id", "")).ends_with("-caractere"): short = fragments[1]
	var page: Array = Content.page(id)
	var moment: Dictionary = Moments.moment(id, str(short.get("id", "")), app.model)
	var message := {"genre": "contexte", "titre": "GABI · " + str(page[1]).to_upper(), "texte": str(short.get("text", "")), "categorie": moment.categorie, "ton": moment.ton, "route": str(app.route), "visit": visit, "event": event}
	if _spontane_permis():
		_consommer(message)
		_montrer(message)
	else:
		_attente = message
		_maj_indice()

func _consommer(message: Dictionary) -> void:
	var visit := str(message.get("visit", ""))
	var event := str(message.get("event", ""))
	var changed := false
	if not visit.is_empty() and visit not in profile.data.seen: profile.data.seen.append(visit); changed = true
	if not event.is_empty() and event not in profile.data.events:
		profile.data.events.append(event); changed = true
		while profile.data.events.size() > Profile.EVENT_LIMIT: profile.data.events.pop_front()
	if message == _attente or (not _attente.is_empty() and _attente.get("texte") == message.get("texte")): _attente.clear()
	if changed: profile.save_profile(profile.data); _status()

## Limite de fréquence des interventions spontanées : une bulle ouverte d'office par jour de jeu.
func _spontane_permis() -> bool:
	var meta: Dictionary = app.model.get("meta", {}) if app.model.get("meta") is Dictionary else {}
	var day := str(meta.get("calendarToday", meta.get("date", ""))) + ":" + _career_context(app.model)
	if day != _jour_spontane: _jour_spontane = day; _spontanes = 0
	if _spontanes >= SPONTANE_PAR_JOUR or (_bulle.visible and _contenu.get("genre") != "fait"): return false
	_spontanes += 1
	return true

## Avant la validation d'une composition (jour de match) : si Gabi changerait quelqu'un, il le signale.
func _conseil_composition(route: String, model: Dictionary) -> void:
	if Avis.ecran(route, model) != "composition" or route == "Match" or not Avis._jour_de_match(model): return
	if _ecartes.has(_cle_conseil(route)) or (_bulle.visible and _contenu.get("genre") == "avis"): return
	var avis := Avis.composition(model)
	if avis.get("action", {}).is_empty(): return
	var message: Dictionary = avis.merged({"genre": "avis", "titre": "GABI · AVANT DE VALIDER", "route": route})
	if _attente.get("texte", "") == message.texte: return
	if _spontane_permis(): _montrer(message)
	else: _attente = message

## Alerte de fatigue : des titulaires de la feuille du prochain match sont sous 70 % de condition. Gabi le
## signale avec « Suivre le conseil » (ils soufflent, remplacés par le meilleur remplaçant frais au poste).
## Une alerte par jour de jeu au plus (clé dans le profil du guide), sur n'importe quel écran : la bulle s'ouvre
## d'elle-même si la limite des interventions spontanées le permet, sinon Gabi l'indique dans le bandeau.
func _alerte_fatigue(model: Dictionary) -> void:
	var avis := Avis.fatigue(model)
	var meta: Dictionary = model.get("meta", {}) if model.get("meta") is Dictionary else {}
	var event := "fatigue:%s:%s" % [_career_context(model), str(meta.get("calendarToday", meta.get("date", "")))]
	var attente_event := str(_attente.get("event", ""))
	# Alerte périmée (autre jour, ou plus personne de fatigué sur la feuille) : elle disparaît du bandeau.
	if attente_event.begins_with("fatigue:") and (avis.is_empty() or attente_event != event): _attente.clear()
	if avis.is_empty() or event in profile.data.events or attente_event == event: return
	if not _attente.is_empty(): return
	var message: Dictionary = avis.merged({"genre": "avis", "titre": "GABI · FATIGUE", "route": str(app.route), "partout": true, "event": event})
	if _spontane_permis():
		_consommer(message)
		_montrer(message)
	else: _attente = message

## Humeur après un match : joie après une victoire, mine sombre après une défaite (une fois par match).
func _humeur(model: Dictionary) -> void:
	var humeur := Avis.humeur(model)
	if str(humeur.cle).is_empty() or humeur.cle == _humeur_cle: return
	var first := _humeur_cle.is_empty()
	_humeur_cle = humeur.cle
	_moment_portraits({"id": humeur.cle, "categorie": humeur.categorie if not first else "consigne", "ton": humeur.ton})
	if first: return  # Résultat déjà connu à l'ouverture de la partie : simple ton, sans réaction.
	var dernier := Avis.dernier_resultat(model)
	var texte: String = {
		"victoire": "On a gagné %d-%d contre %s. Savoure ce soir ; demain, on regarde ce qui a coincé, il y a toujours quelque chose.",
		"defaite": "On a perdu %d-%d contre %s. Pas de coupable ce soir : on en reparle demain, à froid, le carnet ouvert.",
		"nul": "Match nul, %d-%d contre %s. Ni fête ni drame : un point, ça se garde au chaud.",
	}.get(str(dernier.get("issue", "")), "")
	if texte.is_empty(): return
	_attente = {"genre": "humeur", "titre": "GABI · APRÈS LE MATCH", "texte": texte % [dernier.pour, dernier.contre, dernier.adversaire], "categorie": humeur.categorie, "ton": humeur.ton, "route": str(app.route), "partout": true}

func _maj_indice() -> void:
	if not _attente.is_empty() and _attente.get("partout", false): _attente.route = str(app.route)
	if not _attente.is_empty() and _attente.get("route") != str(app.route) and not _attente.get("partout", false):
		# Le message d'un écran ne suit pas le coach ailleurs : il revient à la prochaine visite.
		_attente.clear()
	if is_instance_valid(_visage): _visage.indice = not _attente.is_empty() and not _bulle.visible
	_maj_remarque()

func refresh() -> void:
	var moment := _moment_courant if expanded and mode == "context" else ""
	super.refresh()
	if not moment.is_empty() and not expanded and moment in profile.data.events:
		# Fermé par une fenêtre ou un blocage, pas par le coach : le moment reviendra.
		profile.data.events.erase(moment)
		profile.save_profile(profile.data)
		_contexte_examine = ""
	if not expanded: _moment_courant = ""
	if is_instance_valid(_bulle):
		if not _safe: fermer_bulle()
		_maj_indice()

func _show_context(id: String, fragment: Dictionary) -> void:
	fermer_bulle()
	super._show_context(id, fragment)

func _open() -> void:
	fermer_bulle()
	var was_disabled: bool = not profile.data.enabled
	super._open()
	# Gabi réactivé (F1, aide) : le bandeau et le Bureau le retrouvent.
	if was_disabled and profile.data.enabled and is_instance_valid(app) and app._has_career(): app.call_deferred("_render")

func disable() -> void:
	fermer_bulle()
	super.disable()
	# Gabi coupé : le bandeau se vide et le Bureau reprend sa mise en page classique.
	if is_instance_valid(app) and app._has_career(): app.call_deferred("_render")

func _avoid_primary_controls() -> void:
	# Mode grand : une courte scène, écran assombri ; Gabi reste sous le bandeau.
	if is_instance_valid(_bulle) and _adjoint_actif(): return
	super._avoid_primary_controls()

func destroy() -> void:
	if is_instance_valid(_voile): _voile.queue_free()
	super.destroy()
