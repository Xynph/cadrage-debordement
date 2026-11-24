extends RefCounted
## Coque commune : en-tête de page, onglets de page, pied de page et ligne d'état.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const Raccourcis = preload("res://ui/raccourcis_clavier.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Reception = preload("res://ui/immersive08/reception_canvas.gd")
const FinanceCanvas = preload("res://ui/immersive08/finance_canvas.gd")
const Selections = preload("res://ui/international_view.gd")
const G = preload("res://ui/game_skin.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Outils = preload("res://ui/immersive08/shell_outils.gd")
const Shell = preload("res://ui/immersive08/shell.gd")

## Chiffre clé de l'en-tête Effectif : gros chiffre et légende sur le fond sombre des blocs (comme
## « 65 aujourd’hui » de la fiche joueur), à la place des pastilles en petit texte vert sur vert.
static func _key_figure(row: Control, area: Rect2, index: int, item: Array) -> Panel:
	var frame := D.rect(row,area,C.PANEL,16)
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

## Titre du Bureau (maquette « Affiche et Gabi ») : « LE BUREAU » en Anton, la saison à droite (plus de phrase d'accueil, 21/11).
static func _entete_bureau(row: Control, app: Control) -> void:
	app.heading.add_theme_font_override("font", Charte.TITRE_FICHE)
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
	app.heading = D.text(row,-1,56 if app.route=="Bureau" else 76,"LE BUREAU" if app.route=="Bureau" else app.route.to_upper(),53,C.IVORY,800 if app.route=="Bureau" else 700,1190)
	app.heading.add_theme_font_override("font", Charte.TITRE_FICHE)
	if app.route=="Bureau": _entete_bureau(row,app)
	if Shell.COMPACT_ART.has(app.route):
		var image := D.panel(row,Rect2(1438,6,810,89),"","","","CompactRouteArt")
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if app.route == "Finances":
			FinanceCanvas.hospitality(image, Rect2(2,2,806,85))
		else:
			D.photo(image,Shell.COMPACT_ART[app.route],Rect2(2,2,806,85),.16)
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
			D.rect(row,Rect2(x,15,236,58),C.PANEL,16)
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
	if app.route=="Composition" or app.route=="Effectif": return
	for group: Array in Shell.GROUPS:
		if app.route not in group[2] or group[2].size() < 2: continue
		var row := C.h(8)
		row.name = "ChapterSubnavigation"
		parent.add_child(row)
		for destination: String in group[2]:
			var action := onglet(destination, app.route == destination, func(): app._navigate(destination))
			action.name = "Section_" + destination
			row.add_child(action)
		return

## Onglet de page (charte §7.1) : pilule en Barlow Condensed SemiBold, bas de casse ; actif = aplat crème, texte
## PANNEAU ; inactif = texte gris-vert sans fond, survol panneau-2 ; focus anneau doré. Jamais d'onglet actif vert ni doré.
static func onglet(caption: String, active: bool, callback: Callable) -> Button:
	var tab := Button.new()
	tab.text = caption
	tab.focus_mode = Control.FOCUS_ALL
	tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tab.set_meta("immersive_style_applied", true)
	tab.set_meta("onglet_actif", active)
	tab.custom_minimum_size.y = C.px(43)
	tab.add_theme_font_override("font", C.DISPLAY)
	tab.add_theme_font_size_override("font_size", maxi(12, C.px(22)))
	var fills := {"normal": C.IVORY if active else Color.TRANSPARENT, "hover": C.IVORY if active else C.RAISED,
		"pressed": C.IVORY if active else C.SELECTED, "hover_pressed": C.IVORY if active else C.SELECTED, "disabled": Color.TRANSPARENT}
	for state: String in fills:
		var style := Outils._style(fills[state], Charte.RAYON_PILULE)
		style.content_margin_left = C.px(21)
		style.content_margin_right = C.px(21)
		tab.add_theme_stylebox_override(state, style)
	var focus := Outils._style(Color.TRANSPARENT, Charte.RAYON_PILULE, C.OR, 2)
	focus.set_expand_margin_all(2)
	tab.add_theme_stylebox_override("focus", focus)
	for key in ["font_color", "font_focus_color"]: tab.add_theme_color_override(key, Charte.PANNEAU if active else C.MUTED)
	for key in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]: tab.add_theme_color_override(key, Charte.PANNEAU if active else C.IVORY)
	tab.add_theme_color_override("font_disabled_color", C.FAINT)
	tab.pressed.connect(callback)
	return tab

static func _footer(parent: Node, app: Control, layout: Control) -> void:
	var row := Control.new()
	row.name = "ImmersiveFooter"
	row.custom_minimum_size.y = maxf(C.px(44),38.0/layout.scale.y)
	C.fill(row)
	parent.add_child(row)
	layout.set_meta("immersive_footer",row)
	D.line(row,Vector2(0,-Shell.FOOTER_RISE),Vector2(2248,-Shell.FOOTER_RISE),Color(C.LINE,.7))
	app.status = D.text(row,2,36,app._status_line_text(),17,C.ALERT if app._status_has_error() else C.MUTED,500,900)
	app.status.name = "ImmersiveSaveStatus"
	# Une seule ligne, jamais coupée : le texte se resserre au lieu de passer à la ligne (voir _fit_status).
	app.status.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Rappel des raccourcis sur tous les écrans, Bureau compris : le pied de page est hors de la zone défilante
	# (Gabi, blocs et frise y restent), donc il ne recouvre rien ; le bouton Continuer est dans le bandeau du haut.
	var shortcuts := D.text(row,782,36-Shell.FOOTER_RISE,Raccourcis.pied_de_page(),17,C.FAINT,400,800,HORIZONTAL_ALIGNMENT_LEFT,true)
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
	status.position.y = row.size.y-C.px(8+Shell.FOOTER_RISE)-font.get_ascent(pixels)
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
		shortcuts.position=Vector2(shortcuts_x,C.px(36-Shell.FOOTER_RISE)-shortcut_font.get_ascent(shortcut_px))
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
