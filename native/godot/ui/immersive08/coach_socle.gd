extends "res://guide/coach_guide.gd"
## Gabi adjoint, socle : constantes, état (bandeau, bulle, Bureau, contexte), portraits, habillage des boutons, placement du portrait,
## du voile et de la bulle (zones libres), fil de la remarque du bandeau (texte défilant, indice) et petites classes de dessin.
## Chaîne de l'écran : coach_guide.gd ← coach_socle.gd ← coach_bulle.gd ← coach_bandeau.gd ← coach_bureau.gd ← coach_canvas.gd (fichier public).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const ClubUI = preload("res://ui/immersive08/club_ui.gd")
const Link = preload("res://ui/entity_link.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const GabiPortrait = preload("res://guide/coach_portrait_3d.gd")
const Avis = preload("res://guide/gabi_avis.gd")
const Semaine = preload("res://guide/gabi_semaine.gd")
const Medaillon = preload("res://guide/gabi_medaillon.gd")
const PremiersPas = preload("res://guide/gabi_premiers_pas.gd")
const Accueil = preload("res://guide/gabi_accueil.gd")
const R = preload("res://ui/immersive08/reperes.gd")
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

## Coque commune (charte §7.1) : le bandeau n'est plus qu'un médaillon à côté de la touche « F1 » ; la remarque du
## moment et son titre ne sont plus affichés dans la barre (son avis reste au clic, l'indice sur le médaillon).
var _bandeau_compact := false

var _visage: Control
var _pastille: Panel
var _bandeau_titre: Label
var _fil: Control
var _fil_texte: Label
var _fil_fondu: TextureRect
var _fil_fondu_gauche: TextureRect

## Marge intérieure gauche du fil : la première lettre n'est jamais collée au bord qui coupe.
var _fil_marge := 0.0

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
var _bulle_detail: Label
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
var _bureau_extra: Callable = Callable()
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

## Deux premières semaines (gabi_accueil.gd) : réexamen périodique de l'écran quand la bulle est libre.
var _accueil_attente := 0.0

const PLAFOND_CANDIDATS := 28

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

## Bandeau de Gabi en service : carrière ouverte, Gabi activé, zone du bandeau construite par shell.gd.
func _adjoint_actif() -> bool:
	if not is_instance_valid(app) or not is_instance_valid(_bulle) or not app._has_career(): return false
	if not profile.data.enabled: return false
	return is_instance_valid(_bandeau) and _bandeau.is_inside_tree() and _bandeau.is_visible_in_tree() and (_bandeau.size.x >= (20.0 if _bandeau_compact else 40.0) or _bandeau_masque)

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

func _blocked_adjoint() -> bool:
	return _blocked() or not _adjoint_actif()

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
	var place := maxf(0.0, _fil.size.x - _fil_marge)
	var defile := width > place and not reduced
	_fil_largeur = C.BODY.get_string_size(_remarque + SEPARATEUR, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x if defile else 0.0
	_fil_texte.text = _remarque + SEPARATEUR + _remarque if defile else _remarque
	_fil_texte.tooltip_text = _remarque
	_fil_texte.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if defile else TextServer.OVERRUN_TRIM_ELLIPSIS
	_fil_texte.size.x = C.BODY.get_string_size(_fil_texte.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 4.0 if defile else place
	_fil_fondu.visible = defile or width > place
	if reset:
		_fil_decalage = 0.0
		_fil_pause = DEFILEMENT_PAUSE
	_fil_texte.position.x = _fil_marge - _fil_decalage
	if is_instance_valid(_fil_fondu_gauche): _fil_fondu_gauche.visible = defile and _fil_decalage > 0.0

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
	_fil_texte.position.x = _fil_marge - roundf(_fil_decalage * scale_) / scale_
	# Le fondu gauche n'apparaît qu'en cours de passage : au départ, le début du texte est entier.
	if is_instance_valid(_fil_fondu_gauche): _fil_fondu_gauche.visible = _fil_decalage > 0.0

func _maj_indice() -> void:
	if not _attente.is_empty() and _attente.get("partout", false): _attente.route = str(app.route)
	if not _attente.is_empty() and _attente.get("route") != str(app.route) and not _attente.get("partout", false):
		# Le message d'un écran ne suit pas le coach ailleurs : il revient à la prochaine visite.
		_attente.clear()
	if is_instance_valid(_visage): _visage.indice = not _attente.is_empty() and not _bulle.visible
	# Médaillon ovale : plus de pastille ; un mot en attente est dit en toutes lettres (infobulle, nom accessible).
	if _bandeau_compact and not _bandeau_masque and is_instance_valid(_bandeau):
		var waiting := not _attente.is_empty() and not _bulle.visible
		_bandeau.accessibility_name = "Gabi, ton adjoint · F1" + (" · un mot pour toi" if waiting else "")
		_bandeau.tooltip_text = ("Gabi a un mot pour toi · clic pour le lire" if waiting else "Gabi, ton adjoint · clic : son avis sur cet écran") + " · F1 : l'aide"
	_maj_remarque()

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
	_bulle_detail.add_theme_font_size_override("font_size", px - 2)
	_bulle_detail.custom_minimum_size.x = width - 36.0
	_bulle.size = Vector2(width, 0)
	_bulle.reset_size()
	var height := _bulle.get_combined_minimum_size().y
	_bulle.size = Vector2(width, height)
	var x := clampf(face.position.x - 22.0, 8.0, app.size.x - width - 8.0)
	var y := topbar.end.y + 12.0
	var en_colonne := false
	if _bandeau_masque and is_instance_valid(_bureau_figure) and _bureau_figure.is_inside_tree():
		# Visage masqué : la bulle sort de la colonne de Gabi, à sa gauche, sans pointe vers le bandeau.
		var colonne: Rect2 = (_bureau_figure.get_parent() as Control).get_global_rect()
		# DA du Bureau (19/11/2026) : la colonne de Gabi occupe tout le côté droit et le reste de l'écran est plein de commandes ;
		# la bulle s'ouvre donc dans la colonne, à gauche du buste, au-dessus de la bulle fixe du conseil.
		var buste: Rect2 = _bureau_figure.get_global_rect()
		x = clampf(maxf(colonne.position.x + 8.0, buste.position.x - width - 8.0), 8.0, app.size.x - width - 8.0)
		# À hauteur de la tête de Gabi (elle parle), pas en haut de l'écran où elle cacherait les priorités.
		var tete := _bureau_figure.get_global_rect().position.y + _bureau_figure.get_global_rect().size.y * 0.16
		y = clampf(minf(tete - 56.0, colonne.end.y - height - 12.0), y, maxf(y, app.size.y - height - 12.0))
		# Trop large pour tenir à gauche du buste : elle se pose juste au-dessus de lui, sans cacher son visage.
		if x + width > buste.position.x - 4.0: y = clampf(buste.position.y - height - 8.0, topbar.end.y + 12.0, maxf(topbar.end.y + 12.0, app.size.y - height - 12.0))
		en_colonne = true
		_bulle.vers_droite = true
		_bulle.pointe_y = clampf(tete - y, 24.0, height - 24.0)
	else: _bulle.vers_droite = false
	# Générique : la bulle ne recouvre aucun contrôle interactif de l'écran (boutons, champs, curseurs).
	var libre := Vector2(x, y) if en_colonne else _position_libre(Vector2(x, y), Vector2(width, height), topbar.end.y + 12.0)
	x = libre.x; y = libre.y
	if _bulle_tween == null or not _bulle_tween.is_running(): _bulle.global_position = Vector2(x, y)
	else: _bulle.global_position.x = x
	_bulle.pointe_x = clampf(face.get_center().x - x, 24.0, width - 24.0)
	_bulle.queue_redraw()

## Contrôles interactifs visibles sous la bulle (hors bulle et hors Gabi) : zones à ne pas recouvrir.
func _zones_interactives() -> Array[Rect2]:
	var zones: Array[Rect2] = []
	var pile: Array[Node] = [app]
	while not pile.is_empty():
		var node: Node = pile.pop_back()
		if node == _bulle: continue
		if node is Control:
			var c := node as Control
			if not c.visible: continue
			var interactif := (c is BaseButton or c is LineEdit or c is TextEdit or c is Range) and c.mouse_filter != Control.MOUSE_FILTER_IGNORE
			if interactif and c.is_visible_in_tree():
				var r := c.get_global_rect()
				if r.size.x > 4.0 and r.size.y > 4.0 and not (is_instance_valid(_bandeau) and _bandeau.is_ancestor_of(c)) and not (is_instance_valid(_bureau_figure) and (_bureau_figure == c or _bureau_figure.is_ancestor_of(c))):
					zones.append(r)
		for child in node.get_children(): pile.append(child)
	return zones

static func _aire_commune(a: Rect2, b: Rect2) -> float:
	var r := a.intersection(b)
	return r.size.x * r.size.y if r.size.x > 0.0 and r.size.y > 0.0 else 0.0

## Position la plus proche de `voulue` où la bulle (taille `taille`) ne recouvre aucun contrôle interactif ;
## à défaut, celle qui en recouvre le moins. Le haut est borné par `y_min` (sous la barre du haut).
## Coût borné : les rectangles sont calculés une fois, les candidats sont dédoublonnés et plafonnés
## (les plus proches de `voulue`), et chaque test s'arrête au premier recouvrement (écran Effectif : 296 contrôles).
func _position_libre(voulue: Vector2, taille: Vector2, y_min: float) -> Vector2:
	var zones := _zones_interactives()
	if zones.is_empty(): return voulue
	var marge := 4.0
	if not _recouvre(Rect2(voulue, taille).grow(marge), zones): return voulue
	var x_max := maxf(8.0, app.size.x - taille.x - 8.0)
	var y_max := maxf(y_min, app.size.y - taille.y - 8.0)
	var xs := {}
	var ys := {}
	for cx: float in [voulue.x, 8.0, app.size.x - taille.x - 8.0]: xs[roundi(clampf(cx, 8.0, x_max))] = true
	ys[roundi(clampf(voulue.y, y_min, y_max))] = true
	for z: Rect2 in zones:
		xs[roundi(clampf(z.end.x + 8.0, 8.0, x_max))] = true
		xs[roundi(clampf(z.position.x - taille.x - 8.0, 8.0, x_max))] = true
		ys[roundi(clampf(z.end.y + 8.0, y_min, y_max))] = true
		ys[roundi(clampf(z.position.y - taille.y - 8.0, y_min, y_max))] = true
	var cxs := _plus_proches(xs.keys(), voulue.x, PLAFOND_CANDIDATS)
	var cys := _plus_proches(ys.keys(), voulue.y, PLAFOND_CANDIDATS)
	var meilleur := voulue
	var meilleure_distance := INF
	for cy: float in cys:
		for cx: float in cxs:
			var p := Vector2(cx, cy)
			var distance := p.distance_to(voulue)
			if distance >= meilleure_distance: continue
			if not _recouvre(Rect2(p, taille).grow(marge), zones):
				meilleur = p; meilleure_distance = distance
	if meilleure_distance < INF: return meilleur
	# Aucune place libre : le candidat qui recouvre le moins (jeu réduit, cas rare).
	var meilleur_aire := INF
	var proches_x := cxs.slice(0, 12)
	var proches_y := cys.slice(0, 12)
	for cy: float in proches_y:
		for cx: float in proches_x:
			var p := Vector2(cx, cy)
			var cadre := Rect2(p, taille).grow(marge)
			var aire := 0.0
			for z: Rect2 in zones: aire += _aire_commune(cadre, z)
			var distance := p.distance_to(voulue)
			if aire < meilleur_aire - 0.5 or (absf(aire - meilleur_aire) <= 0.5 and distance < meilleure_distance):
				meilleur = p; meilleur_aire = aire; meilleure_distance = distance
	return meilleur

static func _recouvre(cadre: Rect2, zones: Array[Rect2]) -> bool:
	for z: Rect2 in zones:
		if cadre.intersects(z): return true
	return false

## Les `n` valeurs les plus proches de `cible`, de la plus proche à la plus éloignée.
static func _plus_proches(valeurs: Array, cible: float, n: int) -> Array[float]:
	var tri: Array = valeurs.duplicate()
	tri.sort_custom(func(a, b): return absf(float(a) - cible) < absf(float(b) - cible))
	var sortie: Array[float] = []
	for v in tri.slice(0, n): sortie.append(float(v))
	return sortie

## Panneau du carnet : surface plate `panneau`, rayon 0 (charte : ni cadre complet, ni ombre).
class Carnet extends Control:
	var pointe_x := 0.0
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Charte.PANNEAU_2)
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
