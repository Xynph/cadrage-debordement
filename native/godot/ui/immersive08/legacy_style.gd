extends RefCounted
## Applique les surfaces immersives aux contrôles métier montés dans une tuile.
## Les marges, signaux, états et sélections appartiennent toujours à leur vue.
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Paper = preload("res://ui/carnet_skin.gd")

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
	for kind in ["Button","OptionButton"]:
		theme.set_font("font",kind,C.DISPLAY)
		theme.set_stylebox("normal",kind,C.box(C.PANEL,C.LINE,6,8))
		theme.set_stylebox("hover",kind,C.box(C.RAISED,P.safe_accent(accent),6,8))
		theme.set_stylebox("pressed",kind,C.box(accent.darkened(.48),P.safe_accent(accent),6,8))
		theme.set_stylebox("disabled",kind,C.box(C.BG,C.LINE,6,8))
		theme.set_stylebox("focus",kind,C.box(Color.TRANSPARENT,C.GOLD,6,8))
	for kind in ["LineEdit","TextEdit"]:
		theme.set_stylebox("normal",kind,C.box(C.BG,C.LINE,5,6))
		theme.set_stylebox("focus",kind,C.box(Color.TRANSPARENT,C.GOLD,5,6))
		theme.set_color("font_color",kind,C.IVORY)
		theme.set_color("font_placeholder_color",kind,C.MUTED)
		theme.set_color("caret_color",kind,C.IVORY)
		theme.set_color("selection_color",kind,accent.darkened(.45))
	theme.set_stylebox("panel","PopupMenu",C.box(C.PANEL,C.LINE,6,8))
	theme.set_stylebox("hover","PopupMenu",C.box(C.RAISED,C.GOLD,4,6))
	theme.set_color("font_color","PopupMenu",C.IVORY)
	theme.set_color("font_hover_color","PopupMenu",C.IVORY)
	theme.set_color("font_disabled_color","PopupMenu",C.MUTED)
	for kind in ["AcceptDialog","FileDialog","Window","PanelContainer","Tree","ItemList"]:
		theme.set_stylebox("panel",kind,C.box(C.PANEL,C.LINE,7,10))
	for kind in ["Tree","ItemList"]:
		for state in ["selected","selected_focus"]:
			theme.set_stylebox(state,kind,C.box(accent.darkened(.44),P.safe_accent(accent),4,4))
	theme.set_font("title_font","Window",C.BOLD)
	theme.set_font_size("title_font_size","Window",maxi(17,C.px(25)))
	theme.set_color("title_color","Window",C.IVORY)
	for kind in ["TabContainer","TabBar"]:
		theme.set_font("font",kind,C.DISPLAY)
		for state in ["font_selected_color","font_hovered_color"]: theme.set_color(state,kind,C.IVORY)
		theme.set_color("font_unselected_color",kind,C.MUTED)
		theme.set_stylebox("tab_selected",kind,C.box(accent.darkened(.5),P.safe_accent(accent),5,9))
		theme.set_stylebox("tab_unselected",kind,C.box(C.PANEL,C.LINE,5,9))
		theme.set_stylebox("tab_hovered",kind,C.box(C.RAISED,C.LINE,5,9))
	return theme

static func _style(node: Node, accent: Color) -> void:
	if not node is Control or node.get_meta("immersive_style_applied",false): return
	node.set_meta("immersive_style_applied",true)
	if node is Label:
		var color: Color = node.get_theme_color("font_color")
		var font: Font = node.get_theme_font("font")
		var height: int = node.get_theme_font_size("font_size")
		if color.a > 0: node.add_theme_color_override("font_color",C.IVORY if color==Color("303f44") else _ink(color))
		if font==Paper.T.DISPLAY:
			node.add_theme_font_override("font",C.font(700 if height>=17 else 600))
		else: node.add_theme_font_override("font",C.BODY)
		node.add_theme_font_size_override("font_size",maxi(12,C.px(float(height)*1.36)))
	elif node is Button and not node is CheckButton and not node is CheckBox:
		_button(node,accent)
	elif node is LineEdit or node is TextEdit:
		node.add_theme_font_override("font",C.BODY)
		node.add_theme_color_override("font_color",C.IVORY)
		node.add_theme_color_override("font_placeholder_color",C.MUTED)
		node.add_theme_color_override("caret_color",C.IVORY)
		node.add_theme_color_override("selection_color",accent.darkened(.48))
		node.add_theme_stylebox_override("normal",C.box(C.BG,C.LINE,5,6))
		node.add_theme_stylebox_override("focus",C.box(Color.TRANSPARENT,C.GOLD,5,6))
	elif node is Panel or node is PanelContainer:
		_surface(node)
	elif node is TabContainer:
		node.theme=theme(accent)
		for state in ["tab_selected","tab_unselected","tab_hovered"]:
			node.remove_theme_stylebox_override(state)
		for state in ["font_selected_color","font_unselected_color","font_hovered_color"]:
			node.remove_theme_color_override(state)
	elif node is ProgressBar:
		node.add_theme_stylebox_override("background",C.box(Color("283634"),Color.TRANSPARENT,3,0))
		var fill: StyleBox = node.get_theme_stylebox("fill")
		if fill is StyleBoxFlat:
			node.add_theme_stylebox_override("fill",C.box(_ink(fill.bg_color),Color.TRANSPARENT,3,0))
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
	style.border_color = C.LINE if original.border_color.s<.27 else P.safe_accent(original.border_color)
	style.set_corner_radius_all(maxi(3,C.px(6)))
	node.add_theme_stylebox_override("panel",style)

static func _button(button: Button, accent: Color) -> void:
	var original := button.get_theme_stylebox("normal")
	var selected: bool = button.get_meta("carnet_selected",false)
	var primary: bool = original is StyleBoxFlat and (original.bg_color==Paper.INK or button.get_theme_color("font_color")==C.BG)
	button.add_theme_font_override("font",C.BOLD if primary else C.DISPLAY)
	button.add_theme_font_size_override("font_size",maxi(12,C.px(20)))
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y,C.px(36))
	for state in ["normal","hover","pressed","disabled"]:
		var old := button.get_theme_stylebox(state)
		var emphasis := selected or primary
		var fill := accent.darkened(.48) if emphasis else C.PANEL
		if state=="hover": fill=fill.lightened(.13)
		if state=="pressed": fill=fill.darkened(.16)
		if state=="disabled": fill=C.BG
		var style := C.box(fill,P.safe_accent(accent) if emphasis else C.LINE,5,10)
		for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
			style.set_content_margin(side,old.get_content_margin(side))
		if selected: style.border_width_left=maxi(2,C.px(4))
		button.add_theme_stylebox_override(state,style)
	var focus := C.box(Color.TRANSPARENT,C.GOLD,5,0)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus",focus)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: button.add_theme_color_override(key,C.IVORY)
	button.add_theme_color_override("font_disabled_color",C.MUTED)

static func _ink(color: Color) -> Color:
	if color==Paper.INK: return C.IVORY
	if color==Paper.MUTED: return C.MUTED
	if color==Paper.GOLD: return C.GOLD
	if color==Paper.ALERT: return C.ALERT
	if color==Paper.GOOD: return C.MINT
	if color.get_luminance()>=.31: return color
	if color.s<.28: return C.MUTED
	return P.safe_accent(color)
