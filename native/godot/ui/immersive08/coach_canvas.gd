extends "res://guide/coach_guide.gd"
## Le guide garde son atlas, ses répliques et son placement. Ses commandes
## reprennent les fontes et les couleurs des fenêtres de la carrière.
const C = preload("res://ui/immersive08/components.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const ACCENT = Color("176e49")

func _build() -> void:
	theme=Legacy.theme(ACCENT)
	super._build()
	_title.add_theme_font_override("font",C.BOLD)
	_title.add_theme_font_size_override("font_size",17)
	_title.add_theme_color_override("font_color",C.GOLD)
	_title.add_theme_stylebox_override("normal",_surface(C.BG,C.GOLD))
	_settings_panel.add_theme_stylebox_override("panel",_surface(C.PANEL,C.LINE))
	_error_panel.add_theme_stylebox_override("panel",_surface(Color("282020"),C.ALERT))

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
