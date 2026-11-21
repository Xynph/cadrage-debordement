extends RefCounted
## Applique les surfaces immersives aux contrôles métier montés dans une tuile.
## Les marges, signaux, états et sélections appartiennent toujours à leur vue.
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Paper = preload("res://ui/carnet_skin.gd")
const TEXT_CONTRAST = 4.6
## Corps minimal du texte courant au gabarit 2560 (14 px à 1920).
const BODY_MIN := 19.0

static func apply(root: Control, accent: Color) -> void:
	root.theme = theme(accent)
	_style(root,accent)

static func theme(accent: Color) -> Theme:
	var theme := Paper.T.make()
	theme.default_font = C.BODY
	theme.default_font_size = maxi(14,C.px(18))
	for kind in ["Label","Button","OptionButton","CheckBox","CheckButton","PopupMenu","Tree","ItemList"]:
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_selected_color"]:
			theme.set_color(state,kind,C.IVORY)
		theme.set_color("font_disabled_color",kind,C.MUTED)
	# Charte finale : boutons, onglets et champs en pilule (secondaire à contour FILET), focus doré ; panneaux et
	# fenêtres arrondis sans bordure ; aucune couleur de club en fond (`accent` ne sert plus qu'aux encres de texte).
	var pill := Charte.RAYON_PILULE
	for kind in ["Button","OptionButton"]:
		theme.set_font("font",kind,C.DISPLAY)
		theme.set_stylebox("normal",kind,_pill(Color.TRANSPARENT,C.LINE))
		theme.set_stylebox("hover",kind,_pill(C.RAISED,C.FAINT))
		theme.set_stylebox("pressed",kind,_pill(Charte.SELECTION,C.IVORY))
		theme.set_stylebox("disabled",kind,_pill(Color.TRANSPARENT,C.LINE))
		theme.set_stylebox("focus",kind,_focus_ring())
	for kind in ["LineEdit","TextEdit"]:
		theme.set_stylebox("normal",kind,C.box(C.SELECTED,C.LINE,pill if kind=="LineEdit" else 16,10))
		var edit_focus := C.box(C.SELECTED,Charte.OR,pill if kind=="LineEdit" else 16,10)
		edit_focus.set_border_width_all(2)
		theme.set_stylebox("focus",kind,Charte.sans_ombre(edit_focus))
		theme.set_color("font_color",kind,C.IVORY)
		theme.set_color("font_placeholder_color",kind,C.MUTED)
		theme.set_color("caret_color",kind,C.IVORY)
		theme.set_color("selection_color",kind,Charte.SELECTION)
	theme.set_stylebox("panel","PopupMenu",Charte.sans_ombre(C.box(C.PANEL,Color.TRANSPARENT,16,8)))
	theme.set_stylebox("hover","PopupMenu",C.box(C.SELECTED,Color.TRANSPARENT,8,6))
	theme.set_color("font_color","PopupMenu",C.IVORY)
	theme.set_color("font_hover_color","PopupMenu",C.IVORY)
	theme.set_color("font_disabled_color","PopupMenu",C.MUTED)
	for kind in ["AcceptDialog","FileDialog","Window"]:
		theme.set_stylebox("panel",kind,_panel(24,14))
	for kind in ["PanelContainer","Tree","ItemList"]:
		theme.set_stylebox("panel",kind,_panel(16,10))
	for kind in ["Tree","ItemList"]:
		for state in ["selected","selected_focus"]:
			theme.set_stylebox(state,kind,C.box(Charte.SELECTION,Color.TRANSPARENT,8,4))
	theme.set_font("title_font","Window",C.BOLD)
	theme.set_font_size("title_font_size","Window",maxi(17,C.px(25)))
	theme.set_color("title_color","Window",C.IVORY)
	theme.set_stylebox("panel","TabContainer",_panel(24,10))
	for kind in ["TabContainer","TabBar"]:
		theme.set_font("font",kind,C.DISPLAY)
		theme.set_font_size("font_size",kind,tab_font_size())
		theme.set_constant("tab_separation",kind,C.px(TAB_GAP))
		theme.set_color("font_selected_color",kind,Charte.PANNEAU)
		theme.set_color("font_hovered_color",kind,C.IVORY)
		theme.set_color("font_unselected_color",kind,C.MUTED)
		theme.set_stylebox("tab_selected",kind,_tab(C.IVORY,Color.TRANSPARENT))
		theme.set_stylebox("tab_unselected",kind,_tab(Color.TRANSPARENT,C.LINE))
		theme.set_stylebox("tab_hovered",kind,_tab(C.RAISED,C.FAINT))
	return theme

## Onglet de la graphiste (gabarit 2560 ; à 1920 : 40 px de haut, 18 px de marge intérieure, 8 px entre onglets),
## texte au corps des onglets de la coque (Barlow Condensed SemiBold, `C.px(22)`).
const TAB_HEIGHT := 53.0
const TAB_PADDING := 24
const TAB_GAP := 11
const TAB_FONT := 22

static func tab_font_size() -> int:
	return maxi(12,C.px(TAB_FONT))

static func _tab(fill: Color, border: Color) -> StyleBoxFlat:
	var style := C.box(fill,border,Charte.RAYON_PILULE,TAB_PADDING)
	var vertical := maxf(0.0,(C.px(TAB_HEIGHT)-C.DISPLAY.get_height(tab_font_size()))/2.0)
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style

## Pilule de la charte (bouton, onglet) : aplat `fill`, contour fin `border`, jamais d'ombre.
static func _pill(fill: Color, border: Color, padding: int = 12) -> StyleBoxFlat:
	var style := C.box(fill,border,Charte.RAYON_PILULE,padding)
	style.content_margin_top = C.px(6)
	style.content_margin_bottom = C.px(6)
	return style

## Anneau de focus clavier : doré, 2 px, en pilule.
static func _focus_ring() -> StyleBoxFlat:
	var ring := C.box(Color.TRANSPARENT,Charte.OR,Charte.RAYON_PILULE,12)
	ring.set_border_width_all(2)
	ring.set_expand_margin_all(2)
	return ring

## Panneau ou carte de la charte : PANNEAU, sans bordure, rayon (gabarit 2560 : 24 panneau, 16 carte) et ombre.
static func _panel(radius: int, padding: int) -> StyleBoxFlat:
	return C.box(C.PANEL,Color.TRANSPARENT,radius,padding)

static func _style(node: Node, accent: Color) -> void:
	if not node is Control or node.get_meta("immersive_style_applied",false) or node.has_meta("semantic_role"): return
	node.set_meta("immersive_style_applied",true)
	if node is Label:
		node.begin_bulk_theme_override()
		var color: Color = node.get_theme_color("font_color")
		var font: Font = node.get_theme_font("font")
		var height: int = node.get_theme_font_size("font_size")
		if color.a > 0: node.add_theme_color_override("font_color",C.IVORY if color==Color("303f44") else _ink(color,accent))
		# Titres et étiquettes (police d'affiche) restent en Barlow ; le texte courant passe en DM Sans, 14 px au moins à
		# 1920 (`C.px(19)`).
		if font==Paper.T.DISPLAY:
			node.add_theme_font_override("font",C.font(700 if height>=17 else 600))
			node.add_theme_font_size_override("font_size",maxi(12,C.px(float(height)*1.36)))
		else:
			node.add_theme_font_override("font",Charte.TEXTE)
			node.add_theme_font_size_override("font_size",maxi(12,C.px(maxf(BODY_MIN,float(height)*1.36))))
		node.end_bulk_theme_override()
	elif node is Button and not node is CheckButton and not node is CheckBox:
		_button(node,accent)
	elif node is LinkButton:
		node.focus_mode = Control.FOCUS_ALL
		node.add_theme_font_override("font",C.BODY)
		node.add_theme_color_override("font_color",C.GOLD)
		for state in ["font_hover_color","font_pressed_color","font_focus_color"]:
			node.add_theme_color_override(state,C.IVORY)
		node.add_theme_stylebox_override("focus",_focus_ring())
	elif node is CheckBox or node is CheckButton:
		node.custom_minimum_size.y = maxf(25,node.custom_minimum_size.y)
	elif node is LineEdit or node is TextEdit:
		node.begin_bulk_theme_override()
		node.add_theme_font_override("font",C.BODY)
		node.add_theme_color_override("font_color",C.IVORY)
		node.add_theme_color_override("font_placeholder_color",C.MUTED)
		node.add_theme_color_override("caret_color",C.IVORY)
		node.add_theme_color_override("selection_color",Charte.SELECTION)
		var round_edit := Charte.RAYON_PILULE if node is LineEdit else 16
		node.add_theme_stylebox_override("normal",C.box(C.SELECTED,C.LINE,round_edit,10))
		var edit_focus := C.box(C.SELECTED,Charte.OR,round_edit,10)
		edit_focus.set_border_width_all(2)
		node.add_theme_stylebox_override("focus",Charte.sans_ombre(edit_focus))
		node.end_bulk_theme_override()
	elif node is Panel or node is PanelContainer:
		_surface(node)
	elif node is TabContainer:
		node.theme=theme(accent)
		for state in ["tab_selected","tab_unselected","tab_hovered"]:
			node.remove_theme_stylebox_override(state)
		for state in ["font_selected_color","font_unselected_color","font_hovered_color"]:
			node.remove_theme_color_override(state)
		# Corps et gabarit des onglets : ceux du thème (règle de la graphiste), pas un corps posé par la vue.
		node.remove_theme_font_size_override("font_size")
	elif node is ProgressBar:
		node.add_theme_stylebox_override("background",C.box(C.SELECTED,Color.TRANSPARENT,Charte.RAYON_PILULE,0))
		var fill: StyleBox = node.get_theme_stylebox("fill")
		if fill is StyleBoxFlat:
			node.add_theme_stylebox_override("fill",C.box(_ink(fill.bg_color),Color.TRANSPARENT,Charte.RAYON_PILULE,0))
	elif node is HSeparator:
		var rule := StyleBoxLine.new()
		rule.color = Color(C.LINE,.65)
		rule.thickness = 1
		node.add_theme_stylebox_override("separator",rule)
	for child in node.get_children(): _style(child,accent)
	if node is Container: node.child_entered_tree.connect(_new_child.bind(accent))

static func _new_child(child: Node, accent: Color) -> void:
	if child is Control and not child.get_meta("immersive_style_applied",false): _style_entered.call_deferred(child,accent)

static func _style_entered(child: Control, accent: Color) -> void:
	if is_instance_valid(child) and child.is_inside_tree(): _style(child,accent)

static func _surface(node: Control) -> void:
	var original := node.get_theme_stylebox("panel")
	if not original is StyleBoxFlat or original.bg_color.a < .25: return
	var style: StyleBoxFlat = original.duplicate()
	style.bg_color = C.PANEL if original.bg_color.get_luminance()>.22 else C.PANEL.lerp(original.bg_color,.35)
	# Carte de la charte : sans bordure (ni liseré du club), rayon des cartes, ombre portée des jetons.
	style.set_border_width_all(0)
	style.set_corner_radius_all(maxi(3,C.px(16)))
	node.add_theme_stylebox_override("panel",Charte.ombrer(style,Charte.RAYON_CARTE))

static func _button(button: Button, accent: Color) -> void:
	# Un seul recalcul de thème (forme du texte, taille minimale) pour la douzaine de réglages.
	button.begin_bulk_theme_override()
	_in_bulk = true
	_button_overrides(button,accent)
	_in_bulk = false
	button.end_bulk_theme_override()

static func _button_overrides(button: Button, accent: Color) -> void:
	# Lien de lecture (nom ou portrait du joueur dans le dossier) : ni fond ni bordure, seul l'anneau du focus clavier.
	if button.get_meta("plain_link", false):
		for state in ["normal","hover","pressed","hover_pressed","disabled"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		var anneau := C.box(Color.TRANSPARENT,C.GOLD,5,0)
		anneau.set_border_width_all(2)
		button.add_theme_stylebox_override("focus",anneau)
		return
	var original := button.get_theme_stylebox("normal")
	var selected: bool = button.get_meta("carnet_selected",false)
	var primary: bool = original is StyleBoxFlat and (original.bg_color==Paper.INK or original.bg_color==Charte.OR or button.get_theme_color("font_color")==C.BG)
	button.add_theme_font_override("font",C.BOLD if primary else C.DISPLAY)
	button.add_theme_font_size_override("font_size",maxi(12,C.px(20)))
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y,C.px(36))
	var paint := _button_surfaces.bind(accent,primary)
	button.set_meta("carnet_selection_skin",paint)
	paint.call(button,selected)
	button.add_theme_stylebox_override("focus",_focus_ring())
	button.add_theme_color_override("font_disabled_color",C.MUTED)

static var _in_bulk := false

## Habillage d'un bouton de vue ancienne (charte §7) : pilule. Onglet ou choix courant (`selected`, ou bouton à bascule
## d'un groupe enfoncé) = aplat crème, texte PANNEAU, comme les onglets du socle ; bouton principal de la vue = contour
## crème (l'aplat doré reste à Continuer, un seul par écran) ; les autres = contour FILET, texte crème.
static func _button_surfaces(button: Button, selected: bool, _accent: Color, primary: bool) -> void:
	var own_bulk := not _in_bulk
	if own_bulk: button.begin_bulk_theme_override()
	var group_toggle: bool = button.toggle_mode and button.button_group!=null
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var old := button.get_theme_stylebox("pressed" if state=="hover_pressed" else state)
		var pressed: bool = state=="pressed" or state=="hover_pressed"
		var cream: bool = (selected and state!="disabled") or (pressed and group_toggle)
		var style: StyleBoxFlat
		if cream: style = _pill(C.IVORY,Color.TRANSPARENT)
		elif state=="hover": style = _pill(C.RAISED,C.FAINT)
		elif pressed: style = _pill(Charte.SELECTION,C.IVORY)
		elif state=="disabled": style = _pill(Color.TRANSPARENT,C.LINE)
		else: style = _pill(Color.TRANSPARENT,C.IVORY if primary else C.LINE)
		if old != null:
			for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
				style.set_content_margin(side,maxf(old.get_content_margin(side),style.get_content_margin(side)))
		button.add_theme_stylebox_override(state,style)
	var ink := Charte.PANNEAU if selected else C.IVORY
	for key in ["font_color","font_hover_color","font_focus_color"]: button.add_theme_color_override(key,ink)
	for key in ["font_pressed_color","font_hover_pressed_color"]: button.add_theme_color_override(key,Charte.PANNEAU if selected or group_toggle else C.IVORY)
	if own_bulk: button.end_bulk_theme_override()

static func _luminance(color: Color) -> float:
	return color.srgb_to_linear().get_luminance()

static func _ink(color: Color, accent: Color = Color.TRANSPARENT) -> Color:
	if color==Paper.INK: return C.IVORY
	if color==Paper.MUTED: return C.MUTED
	if color==Paper.GOLD: return C.GOLD
	if color==Paper.ALERT: return C.ALERT
	if color==Paper.GOOD: return C.MINT
	if accent.a>0 and color==Paper.accent_ink(accent):
		var minimum_ink := (_luminance(C.PANEL.lerp(accent,.10))+.05)*TEXT_CONTRAST-.05
		var ink := accent
		while _luminance(ink)<minimum_ink: ink=ink.lightened(.10)
		return ink
	if color.get_luminance()>=.31: return color
	if color.s<.28: return C.MUTED
	return P.safe_accent(color)
