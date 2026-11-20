extends RefCounted
## Grammaire visuelle des compositions approuvées ; aucune donnée de carrière.

const BanqueImages = preload("res://ui/banque_images.gd")
const Base = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
## Alias historiques des écrans, rabattus sur les jetons de la charte (ui/charte.gd, une seule direction artistique) :
## noir chaud et ivoire partout. L'or n'est plus un accent : GOLD (accent, titres, focus) devient l'ivoire ;
## le vrai or (Continuer, héritage) est OR / OR_VIF. Les couleurs à sens suivent v / d / n.
const BG = Charte.FOND
const PANEL = Charte.PANNEAU
const RAISED = Charte.PANNEAU_2
const SELECTED = Charte.PANNEAU_3
const LINE = Charte.FILET
const IVORY = Charte.IVOIRE
const MUTED = Charte.IVOIRE_2
const FAINT = Charte.IVOIRE_3
const MINT = Charte.V
const GOLD = Charte.IVOIRE
const OR = Charte.OR
const OR_VIF = Charte.OR_VIF
const AMBER = Charte.N
const ALERT = Charte.D
const BLUE = Charte.IVOIRE_2
const DISPLAY = preload("res://fonts/BarlowCondensed-SemiBold.ttf")
const MEDIUM = preload("res://ui/immersive08/fonts/BarlowCondensed-Medium.ttf")
const BOLD = preload("res://ui/immersive08/fonts/BarlowCondensed-Bold.ttf")
const EXTRA_BOLD = preload("res://ui/immersive08/fonts/BarlowCondensed-ExtraBold.ttf")
const BODY = preload("res://fonts/DMSans.ttf")
static var density := 1.0
## Charte §3 « rayons 0 » posée à la création : vrai le temps de construire un écran qui veut des angles droits partout
## (Composition), au lieu d'une passe sur tous ses nœuds après coup (Kit.angles_droits).
static var rayon_nul := false
static var _textures: Dictionary = {}

class ArtTexture extends TextureRect:
	var source: Texture2D
	var vertical_focus := 0.0
	func _ready() -> void:
		resized.connect(_fit)
		_fit()
	func _fit() -> void:
		if source == null or size.x < 1 or size.y < 1 or stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_COVERED: return
		var source_size := source.get_size()
		var ratio := size.x / size.y
		var crop := source_size
		if source_size.x / source_size.y < ratio: crop.y = source_size.x / ratio
		else: crop.x = source_size.y * ratio
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(Vector2((source_size.x-crop.x)/2.0, (source_size.y-crop.y)*vertical_focus), crop)
		texture = atlas

static func configure(height: float, width: float = 2560.0) -> void:
	density = clampf(minf(height / 1440.0, width / 2560.0), .5, 1.0)

static func px(value: float) -> int:
	return roundi(value * density)

## Taille de police avec le plancher commun de 12 px (même règle que label et D.text).
static func font_px(value: float) -> int:
	return maxi(12, px(value))

## Cible minimale d'une commande, en pixels de fenêtre : 25 px, soit ≈ 24 px affichés une fois le gabarit
## ajusté au pied de page (shell._fit_layout, facteur ≥ 0,977 dès 1280 × 720).
const TARGET_MIN := 25.0

## Hauteur (unités du gabarit 2560 × 1440) d'une commande dense. Les gabarits dessinés pour 1920 et plus restent
## intacts ; sous la densité 0,75 (fenêtres plus petites que 1920 × 1080), la hauteur monte jusqu'à TARGET_MIN.
static func reach(height: float) -> float:
	if density >= .75: return height
	return maxf(height, ceilf(TARGET_MIN / density))

## Rectangle de commande agrandi verticalement autour de son centre (voir reach).
static func reach_rect(rectangle: Rect2) -> Rect2:
	var height := reach(rectangle.size.y)
	return Rect2(rectangle.position.x, rectangle.position.y - (height - rectangle.size.y) / 2.0, rectangle.size.x, height)

## Petites fenêtres (densité < 0,75) : les gabarits riches réorganisent leurs commandes les plus serrées.
static func dense() -> bool:
	return density < .75

## Toutes les commandes d'une vue métier (thème Legacy) gardent la cible minimale en petite fenêtre.
static func reach_controls(root: Node) -> void:
	if not dense(): return
	for node: Node in root.find_children("*", "BaseButton", true, false):
		var control := node as Control
		control.custom_minimum_size = control.custom_minimum_size.max(Vector2(TARGET_MIN, TARGET_MIN))

static func box(color: Color = PANEL, border: Color = LINE, radius: int = 8, padding: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(border, .65)
	style.set_border_width_all(1 if border.a > 0 else 0)
	style.set_corner_radius_all(0 if rayon_nul else maxi(3, px(radius)))
	style.content_margin_left = px(padding)
	style.content_margin_right = px(padding)
	style.content_margin_top = px(padding)
	style.content_margin_bottom = px(padding)
	return style

static func font(weight: int = 600) -> Font:
	if weight >= 800: return EXTRA_BOLD
	if weight >= 700: return BOLD
	if weight >= 600: return DISPLAY
	return MEDIUM

static func label(text: Variant, font_size: int = 22, color: Color = IVORY, display: bool = true, weight: int = 600) -> Label:
	var control := Label.new()
	control.text = Base.n(text) if text is float or text is int else str(text)
	control.add_theme_font_override("font", font(weight) if display else BODY)
	control.add_theme_font_size_override("font_size", maxi(12, px(font_size)))
	control.add_theme_color_override("font_color", color)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.set_meta("immersive_style_applied",true)
	return control

static func wrap(text: Variant, font_size: int = 20, color: Color = MUTED, display: bool = false, weight: int = 600) -> Label:
	var control := label(text, font_size, color, display, weight)
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return control

static func h(gap: int = 16) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", px(gap))
	return row

static func v(gap: int = 12) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", px(gap))
	return column

static func fill(control: Control, vertical: bool = false, ratio: float = 1.0) -> Control:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vertical: control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	control.size_flags_stretch_ratio = ratio
	return control

## Style de bouton « LIEN » commun à tous les écrans (charte §7, décision de Léo du 19/11/2026) : texte ivoire (+ flèche ou
## symbole si le bouton en porte une), sans cadre ni fond, rayon 0 ; souligné au survol et au focus. À appliquer à toute
## action secondaire (Favori, Archiver, « Ouvrir … → », Annuler, pièces liées). L'action principale de l'écran, elle,
## prend `style_bouton_ivoire_plein` (un seul par écran). Avec `souligne_au_repos`, le lien actif se reconnaît d'emblée
## (nom de joueur, de club) ; un nom sans destination reste du texte gris non souligné (jamais de faux lien).
static func style_bouton_lien(bouton: BaseButton, taille: int = 19, souligne_au_repos: bool = false) -> void:
	for look in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.set_corner_radius_all(0)
		style.content_margin_left = px(6)
		style.content_margin_right = px(6)
		style.content_margin_top = px(4)
		style.content_margin_bottom = px(4)
		var souligne: bool = look in ["hover", "pressed", "focus"] or (souligne_au_repos and look == "normal")
		style.border_color = Charte.IVOIRE if look != "disabled" else Color(0, 0, 0, 0)
		style.border_width_bottom = maxi(1, px(2 if look in ["hover", "pressed", "focus"] else 1)) if souligne else 0
		bouton.add_theme_stylebox_override(look, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		bouton.add_theme_color_override(key, Charte.IVOIRE)
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	bouton.add_theme_font_override("font", BOLD)
	bouton.add_theme_font_size_override("font_size", maxi(12, px(taille)))
	bouton.custom_minimum_size.y = 0
	if bouton is Button:
		(bouton as Button).alignment = HORIZONTAL_ALIGNMENT_LEFT
		(bouton as Button).icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

## Bouton d'action PRINCIPALE de l'écran : ivoire plein, texte nuit, rayon 0 (charte §7). Un seul par écran ; jamais d'or
## (réservé à Continuer).
static func style_bouton_ivoire_plein(bouton: BaseButton, taille: int = 21) -> void:
	for look in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.IVOIRE if look != "hover" else Charte.IVOIRE.lightened(.12)
		style.set_corner_radius_all(0)
		style.content_margin_left = px(18)
		style.content_margin_right = px(18)
		style.content_margin_top = px(7)
		style.content_margin_bottom = px(7)
		bouton.add_theme_stylebox_override(look, style)
	var off := StyleBoxFlat.new()
	off.bg_color = PANEL
	off.border_color = LINE
	off.set_border_width_all(1)
	off.set_corner_radius_all(0)
	off.content_margin_left = px(18)
	off.content_margin_right = px(18)
	bouton.add_theme_stylebox_override("disabled", off)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		bouton.add_theme_color_override(key, Charte.NUIT)
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	bouton.add_theme_font_override("font", BOLD)
	bouton.add_theme_font_size_override("font_size", maxi(12, px(taille)))
	if bouton is Button:
		(bouton as Button).icon = null

static func margin(padding: int = 18) -> MarginContainer:
	var control := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]: control.add_theme_constant_override("margin_" + edge, px(padding))
	return control

static func rule() -> HSeparator:
	var control := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color(LINE, .65)
	style.thickness = 1
	control.add_theme_stylebox_override("separator", style)
	return control

static func card(title: String = "", minimum: Vector2 = Vector2.ZERO) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.set_meta("immersive_style_applied",true)
	frame.custom_minimum_size = minimum * density
	frame.add_theme_stylebox_override("panel", box())
	var content := v(8)
	frame.add_child(content)
	frame.set_meta("content", content)
	if not title.is_empty():
		var heading := label(title.to_upper(), 26, IVORY, true, 700)
		heading.name = "CardTitle"
		content.add_child(heading)
		content.add_child(rule())
	return frame

static func content(frame: Control) -> VBoxContainer:
	return frame.get_meta("content")

static func readable_primary_fill(color: Color) -> Color:
	var limit := (IVORY.srgb_to_linear().get_luminance() + .05) / 4.6 - .05
	while color.srgb_to_linear().get_luminance() > limit:
		color = color.darkened(.05)
	return color

static func button(text: String, callback: Callable, primary: bool = false, accent: Color = Color("176e49")) -> Button:
	var control := Button.new()
	control.set_meta("immersive_style_applied",true)
	control.text = text
	control.custom_minimum_size.y = px(46)
	control.add_theme_font_override("font", BOLD)
	control.add_theme_font_size_override("font_size", maxi(14, px(25)))
	var fill := readable_primary_fill(accent) if primary else accent
	control.add_theme_stylebox_override("normal", box(fill.darkened(.2) if primary else PANEL, accent.lightened(.3) if primary else LINE, 5, 12))
	control.add_theme_stylebox_override("hover", box(fill if primary else RAISED, IVORY, 5, 12))
	control.add_theme_stylebox_override("pressed", box(fill.darkened(.4) if primary else SELECTED, IVORY, 5, 12))
	control.add_theme_stylebox_override("disabled", box(PANEL, LINE, 5, 12))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = control.get_theme_stylebox(state)
		style.content_margin_top = px(7)
		style.content_margin_bottom = px(7)
	var focus := box(Color.TRANSPARENT, GOLD, 5, 12)
	focus.set_border_width_all(2)
	if primary: focus.set_expand_margin_all(2)
	control.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: control.add_theme_color_override(state, IVORY)
	control.add_theme_color_override("font_disabled_color", FAINT)
	control.pressed.connect(callback)
	return control

static func icon_texture(id: String, color: Color = IVORY) -> Texture2D:
	var key := "icon:" + id + ":" + color.to_html()
	if _textures.has(key): return _textures[key]
	var paths: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ui/immersive08/icon-paths.json"))
	if not paths.has(id): return null
	var ink := "#" + color.to_html(false)
	var paint := 'fill="%s" fill-rule="evenodd"' % ink if id.ends_with("-solid") else 'fill="none" stroke="%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"' % ink
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="72" height="72" viewBox="0 0 24 24"><path d="%s" %s/></svg>' % [paths[id], paint]
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK: return null
	var value := ImageTexture.create_from_image(image)
	_textures[key] = value
	return value

static func icon(id: String, width: int = 25, color: Color = GOLD) -> TextureRect:
	var image := TextureRect.new()
	image.texture = icon_texture(id, color)
	image.custom_minimum_size = Vector2(px(width), px(width))
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

static func fixture_location_icon(kind: String, solid: bool = false) -> String:
	var id: String = {"home": "home", "away": "bus", "neutral": "flag"}.get(kind, "")
	if id.is_empty(): return "calendar"
	return id + "-solid" if solid else id

static func chip(text: String, color: Color = MINT) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", box(Color(color, .10), color, 5, 8))
	var caption := label(text, 21, color)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(caption)
	return frame

## Pastille dorée « DERBY » (Bureau, Préparation, Composition) : fond ambre sombre, liseré et texte or.
static func derby_chip() -> PanelContainer:
	var frame := PanelContainer.new()
	frame.name = "DerbyTag"
	frame.add_theme_stylebox_override("panel", box(RAISED, GOLD, 5, 8))
	var caption := label("DERBY", 21, AMBER, true, 700)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(caption)
	frame.tooltip_text = "Derby : une rivalité ancienne, plus de tension sur le terrain et dans les tribunes."
	return frame

static func gauge(value: float, color: Color = MINT, height: int = 7) -> ProgressBar:
	var control := ProgressBar.new()
	control.value = clampf(value, 0, 100)
	control.show_percentage = false
	control.custom_minimum_size.y = maxi(4, px(height))
	control.add_theme_stylebox_override("background", box(SELECTED, Color.TRANSPARENT, 3, 0))
	control.add_theme_stylebox_override("fill", box(color, Color.TRANSPARENT, 3, 0))
	return control

static func texture(id: String) -> Texture2D:
	if _textures.has(id): return _textures[id]
	if not id.is_valid_filename() or id.contains("."): return null
	var path := "res://art/immersive08/" + id + ".png"
	var value: Texture2D = null
	if FileAccess.file_exists(path) or ResourceLoader.exists(path): value = load(path)
	elif BanqueImages.existe(id): value = BanqueImages.texture(id)
	else: return null
	if value != null: _textures[id] = value
	return value

static func photo(id: String, minimum: Vector2 = Vector2.ZERO, cover: bool = true, vertical_focus: float = 0.0) -> TextureRect:
	var control := ArtTexture.new()
	control.source = texture(id)
	control.vertical_focus = clampf(vertical_focus, 0.0, 1.0)
	control.texture = control.source
	control.name = "Art_" + id.replace("-", "_")
	control.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	control.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	control.custom_minimum_size = minimum * density
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.tooltip_text = "Vue du club"
	control.set_meta("immersive_art", id)
	return control

static func veil(parent: Control, horizontal: bool = true) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(BG, 1.0))
	gradient.set_color(1, Color(BG, 0.0))
	gradient.add_point(.48, Color(BG, .97))
	gradient.add_point(.73, Color(BG, .4))
	var image := GradientTexture2D.new()
	image.gradient = gradient
	image.fill_from = Vector2.ZERO
	image.fill_to = Vector2.RIGHT if horizontal else Vector2.DOWN
	var overlay := TextureRect.new()
	overlay.texture = image
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(overlay)
	return overlay
