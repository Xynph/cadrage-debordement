extends RefCounted

const T = preload("res://theme.gd")
const Knowledge = preload("res://ui/player_knowledge_text.gd")
const POTENTIAL_COLOR = Knowledge.POTENTIAL_COLOR
const W = preload("res://visual_widgets.gd")
const SeasonLabel = preload("res://ui/season_label.gd")
const Art = preload("res://ui/art_widgets.gd")
# Jetons communs du bureau du manager : seule source des couleurs d'encre et d'or.
# carnet_skin.gd (papier clair) et contextual/skin.gd (salles du club) les reprennent.
## Depuis la charte finale, ces noms pointent sur les jetons de `Charte` (ui/charte.gd), seule source des couleurs.
const Charte = preload("res://ui/charte.gd")
const BG = Charte.FOND
const PANEL = Charte.PANNEAU
const LINE = Charte.FILET
const INK = Charte.IVOIRE
const MUTED = Charte.IVOIRE_2
const GOLD = Charte.OR
## Or lisible sur papier clair uniquement (carnet) ; sur fond sombre, toujours GOLD.
const PAPER_GOLD = Charte.OR_ENCRE
const GOOD = Charte.V
## Trois rayons d'angle seulement (charte) : pastilles et cases, cartes, panneaux. Boutons et onglets : pilule.
const RADIUS_CHIP := Charte.RAYON_PETIT
const RADIUS_CONTROL := Charte.RAYON_CARTE
const RADIUS_PANEL := Charte.RAYON_PANNEAU
const RADII := {"chip": RADIUS_CHIP, "control": RADIUS_CONTROL, "panel": RADIUS_PANEL}
# Assez large pour un groupe pro entier (60 photos de 512 px) : plus petit, le cache
# se renouvelle à chaque ouverture de l'effectif. Les plus anciens partent en premier (LRU).
const PACK_TEXTURES := 128
static var textures: Dictionary = {}

# Dense carnet scale: explicit legacy sizes keep their role, without enlarging
# every heading and number into a second page at native desktop resolutions.
static func reading_size(requested: int) -> int:
	if requested >= 44: return 26
	if requested >= 34: return 20
	if requested >= 27: return 18
	if requested >= 23: return 16
	if requested >= 18: return 13
	if requested >= 15: return 12
	return mini(requested, 12)

## Rayon d'angle d'un rôle : "chip" (6), "control" (12, cartes) ou "panel" (18).
## Exemple : `G.radius("panel")` vaut 18 ; un rôle inconnu prend le rayon des cartes.
static func radius(kind: String) -> int:
	return int(RADII.get(kind, RADIUS_CONTROL))

## Fond à angles communs, seul point d'entrée des habillages pour T.box.
## Exemple : `G.box(G.PANEL, "panel", G.LINE)`.
static func box(color: Color, kind: String = "control", border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	return T.box(color, radius(kind), border)

static func label(text: Variant, size: int = 14, color: Color = INK, title: bool = false) -> Label:
	var l := Label.new()
	l.text = str(text)
	l.add_theme_font_size_override("font_size", reading_size(size))
	l.add_theme_color_override("font_color", color)
	if title: l.add_theme_font_override("font", T.DISPLAY)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func wrap(text: Variant, size: int = 14, color: Color = MUTED) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func button(text: String, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 32
	b.add_theme_font_size_override("font_size", 14)
	# Charte : pilule. Principal = aplat doré, texte PANNEAU ; secondaire = pilule du thème (contour FILET sur le
	# sombre, T.make ; papier clair, T.paper).
	if primary:
		b.add_theme_stylebox_override("normal", T.pilule(Charte.OR))
		b.add_theme_stylebox_override("hover", T.pilule(Charte.OR_VIF))
		b.add_theme_stylebox_override("pressed", T.pilule(Charte.OR.darkened(.15)))
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(key, Charte.PANNEAU)
	b.pressed.connect(callback)
	return b

static func h(gap: int = 6) -> HBoxContainer:
	var c := HBoxContainer.new()
	c.add_theme_constant_override("separation", mini(gap, 8))
	return c

static func nav_button(text:String,callback:Callable,accent:Color,selected:bool,chapter:String="") -> Button:
	var b:=button(text,callback)
	b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y=30
	b.add_theme_font_size_override("font_size",13)
	# Entrée de menu (charte) : pilule ; active = aplat crème, texte PANNEAU ; les autres sans fond, survol PANNEAU_2.
	# La couleur du club (`accent`) n'habille plus le menu.
	var normal:=T.pilule(Charte.CREME if selected else Color.TRANSPARENT)
	normal.content_margin_top=4
	normal.content_margin_bottom=4
	normal.content_margin_left=34 if not chapter.is_empty() else 12
	b.add_theme_stylebox_override("normal",normal)
	var hover:=normal.duplicate()
	if not selected: hover.bg_color=Charte.PANNEAU_2
	b.add_theme_stylebox_override("hover",hover)
	var pressed:=normal.duplicate()
	if not selected: pressed.bg_color=Charte.PANNEAU_3
	b.add_theme_stylebox_override("pressed",pressed)
	var focus:=T.pilule(Color.TRANSPARENT,Charte.OR)
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(2)
	b.add_theme_stylebox_override("focus",focus)
	var ink:=Charte.PANNEAU if selected else MUTED
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(state,ink)
	if not chapter.is_empty():
		var icon:=Art.glyph(chapter,ink,18)
		icon.name="ChapterIcon"
		b.add_child(icon)
		icon.position=Vector2(10,5)
		b.resized.connect(func():icon.position=Vector2(10,(b.size.y-18)*.5))
		b.set_meta("art_icon",icon)
	return b

static func v(gap: int = 6) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", mini(gap, 8))
	return c

static func fill(c: Control, vertical: bool = false, ratio: float = 1.0) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vertical: c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = ratio
	return c

static func margin(padding: int = 8) -> MarginContainer:
	var m := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + edge, padding)
	return m

static func panel(parent: Node, ratio: float = 1.0, color: Color = PANEL) -> VBoxContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = ratio
	# Panneau de la charte : sans bordure, rayon 18, ombre des jetons.
	p.add_theme_stylebox_override("panel",Charte.ombrer(box(color,"panel"),Charte.RAYON_PANNEAU))
	parent.add_child(p)
	var m := margin(4)
	p.add_child(m)
	var c := v()
	m.add_child(c)
	return c

static func section(title: String, subtitle: String = "") -> VBoxContainer:
	var c := v(3)
	c.add_child(label(title, 23, INK, true))
	if not subtitle.is_empty(): c.add_child(label(subtitle, 12, MUTED))
	return c

static func separator() -> HSeparator:
	var s := HSeparator.new()
	s.modulate = LINE
	return s

static func metric(number: Variant, caption: String, color: Color = INK) -> VBoxContainer:
	var c := v(0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(label(number, 37, color, true))
	c.add_child(label(caption.to_upper(), 12, MUTED))
	return c

static func n(number: Variant) -> String:
	return str(int(number)) if number is float or number is int else str(number)

static func euros(amount: Variant) -> String:
	var value := int(amount) if amount != null else 0
	var digits := str(absi(value))
	var formatted := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0: formatted += " "
		formatted += digits[i]
	return ("−" if value < 0 else "") + formatted + " €"

static func identity(club: Dictionary) -> Dictionary:
	return club.get("presentation", club) if club.get("presentation") is Dictionary else club

static func club_name(club: Dictionary) -> String:
	return str(identity(club).get("name", club.get("name", "—")))

static func club_abbr(club: Dictionary) -> String:
	return str(identity(club).get("abbr", "XV"))

static func crest(club: Dictionary, width: int = 56) -> Control:
	var c := identity(club)
	var provided := _pack_texture(str(c.get("logoPath", club.get("logoPath", "")))) != null
	var texture := crest_texture(club)
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(width, width)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.tooltip_text = "Blason fourni par le pack" if provided else "Blason de Rugby Legacy 27"
		return image
	# Sans blason : écusson de la banque d'images aux couleurs du club, initiales dessus.
	var recolore: Control = load("res://ui/tenue_club.gd").ecusson(club, width)
	if recolore != null:
		recolore.custom_minimum_size = Vector2(width, width)
		recolore.tooltip_text = "Blason de Rugby Legacy 27"
		return recolore
	var w := W.new()
	w.initials = str(c.get("abbr", "XV"))
	w.accent = Color(c.get("color", "#b94850"))
	w.custom_minimum_size = Vector2(width, width)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return w

## Blason réel du club pour les surfaces 3D (stade, salles) : celui du pack actif, sinon l'écusson officiel du
## championnat. Null sans blason : l'écusson recoloré à initiales de crest() reste propre à l'interface.
static func crest_texture(club: Dictionary) -> Texture2D:
	var c := identity(club)
	var texture := _pack_texture(str(c.get("logoPath", club.get("logoPath", ""))))
	if texture != null: return texture
	var slug := str(c.get("slug", ""))
	var badge := "res://art/pacific/badges/%s.svg" % slug if slug.begins_with("srp-") else "res://art/japan/badges/%s.svg" % slug if slug.begins_with("jlo-") else "res://art/nationale/badges/%s.svg" % slug if slug.begins_with("nat-") else "res://art/champ/badges/%s.svg" % slug if slug.begins_with("champ-") else ""
	if not badge.is_empty() and ResourceLoader.exists(badge): return load(badge) as Texture2D
	return null

static func _pack_texture(path: String) -> Texture2D:
	if path.is_empty() or not path.is_absolute_path() or not FileAccess.file_exists(path): return null
	if textures.has(path):
		var known: Texture2D = textures[path]
		textures.erase(path)
		textures[path] = known
		return known
	var image := Image.new()
	if image.load(path) != OK: return null
	var longest := maxi(image.get_width(), image.get_height())
	if longest > 512:
		var ratio := 512.0 / longest
		image.resize(maxi(1, roundi(image.get_width() * ratio)), maxi(1, roundi(image.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(image)
	if textures.size() >= PACK_TEXTURES: textures.erase(textures.keys()[0])
	textures[path] = texture
	return texture

static func portrait(index: int, width: int = 60, player: Dictionary = {}) -> TextureRect:
	var r := _portrait_rect(width, player)
	fill_portrait(r, index, player)
	return r

static func _portrait_rect(width: int, player: Dictionary) -> TextureRect:
	var r := TextureRect.new()
	var caption := str(player.get("name", "Portrait"))
	r.tooltip_text = caption if not caption.is_empty() else "Portrait"
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(width, width)
	return r

static func _pack_path(player: Dictionary) -> String:
	var identity_data: Dictionary = player.get("identity", {})
	return str(player.get("portraitPath", identity_data.get("portraitPath", "")))

## Applique la photo du pack, sinon le visage composé, sinon la planche
## éditoriale, sinon l'initiale. Même résultat qu'un portrait créé d'un coup.
static func fill_portrait(r: TextureRect, index: int, player: Dictionary) -> void:
	var caption := str(player.get("name", "Portrait"))
	if caption.is_empty(): caption = "Portrait"
	var path := _pack_path(player)
	var texture := _pack_texture(path)
	if texture != null:
		r.texture = texture
		r.tooltip_text = caption
	elif not str(player.get("id", "")).is_empty() and preload("res://ui/regen_portrait.gd").apply(r, player):
		r.tooltip_text = caption if path.is_empty() else "Image du pack indisponible · " + caption
	else:
		index = posmod(index, 32)
		var atlas_path := "res://assets/editorial/portraits-%d.webp" % (index / 16)
		# Planche absente (projet non importé, fichier retiré) : on garde l'initiale, sans erreur de chargement.
		var sheet := load(atlas_path) as Texture2D if ResourceLoader.exists(atlas_path) else null
		if sheet != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			var cell := sheet.get_size() / 4.0
			atlas.region = Rect2(Vector2(index % 4, (index % 16) / 4) * cell, cell)
			r.texture = atlas
		else:
			r.add_child(_initial_label(caption))
		r.tooltip_text = caption if path.is_empty() else "Image du pack indisponible · " + caption

## Préchauffe le cache d'un portrait sans créer de nœud (ui/portrait_warmup.gd) : mêmes étapes coûteuses et
## mêmes clés de cache que fill_portrait — photo du pack (textures[chemin]), sinon visage composé
## (regen_portrait.gd : base recadrée par planche et case, puis composition par profil). La planche éditoriale
## du dernier repli est une ressource déjà gardée par Godot : rien à préparer.
## Exemple : `G.warm_portrait(player)` puis `G._portrait_ready(player)` est vrai.
static func warm_portrait(player: Dictionary) -> void:
	if _pack_texture(_pack_path(player)) != null: return
	if str(player.get("id", "")).is_empty(): return
	if preload("res://ui/regen_portrait.gd").texture(player) != null: preload("res://ui/regen_portrait.gd").material(player)

## Portrait d'une liste longue : tout de suite s'il est déjà prêt (cache), sinon
## case vide et chargement progressif par `portrait_loader.gd`, lignes visibles d'abord.
static func portrait_lazy(index: int, width: int = 60, player: Dictionary = {}) -> TextureRect:
	if _portrait_ready(player): return portrait(index, width, player)
	var r := _portrait_rect(width, player)
	preload("res://ui/portrait_loader.gd").request(r, index, player)
	return r

static func _portrait_ready(player: Dictionary) -> bool:
	var path := _pack_path(player)
	if not path.is_empty() and textures.has(path): return true
	if not path.is_empty() and path.is_absolute_path() and FileAccess.file_exists(path): return false
	if str(player.get("id", "")).is_empty(): return true
	return preload("res://ui/regen_portrait.gd").cached(player)

static func _initial_label(caption: String) -> Label:
	var words := caption.strip_edges().split(" ", false)
	var initials := ""
	for word in words.slice(0, 2): initials += word.substr(0, 1).to_upper()
	var label := Label.new()
	label.text = initials if not initials.is_empty() else "?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", MUTED)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

static var venue_textures: Dictionary = {}
const TERRITORY_STANDALONE := [30, 61, 70]

static func _venue_texture(path: String) -> Texture2D:
	if path.is_empty() or not path.is_absolute_path() or not FileAccess.file_exists(path): return null
	if venue_textures.has(path): return venue_textures[path]
	var image := Image.new()
	if image.load(path) != OK or image.is_empty(): return null
	var texture := ImageTexture.create_from_image(image)
	if venue_textures.size() >= 6: venue_textures.erase(venue_textures.keys()[0])
	venue_textures[path] = texture
	return texture

static func _territory_texture(club: Dictionary, kind: String) -> Texture2D:
	var id := int(club.get("id", -1))
	var direct := "res://art/territories/%d-%s.png" % [id, kind]
	if ResourceLoader.exists(direct): return load(direct) as Texture2D
	if id >= 0 and id < 116 and id not in TERRITORY_STANDALONE:
		# Atlas order follows club IDs, skipping the standalone high-resolution views.
		var index := id
		for standalone: int in TERRITORY_STANDALONE:
			if id > standalone: index -= 1
		var path := "res://art/territories/%02d.png" % floori(index / 8.0)
		if ResourceLoader.exists(path):
			var atlas := load(path) as Texture2D
			var cell := atlas.get_size() / 4.0
			var slot := (index % 8) * 2 + (1 if kind == "city" else 0)
			var texture := AtlasTexture.new()
			texture.atlas = atlas
			texture.region = Rect2(Vector2(slot % 4, floori(slot / 4.0)) * cell + Vector2(4, 4), cell - Vector2(8, 8))
			texture.filter_clip = true
			return texture
	var fallback := "club-forest" if kind == "city" else "stadium"
	return load("res://art/immersive08/%s.png" % fallback) as Texture2D

static func club_picture(club: Dictionary, kind: String = "stadium", dark: bool = true) -> Control:
	var identity_data := identity(club)
	var supplied: Dictionary = identity_data.get("photos", {}).get(kind, {})
	var base := Control.new()
	base.clip_contents = true
	base.custom_minimum_size = Vector2(0, 140)
	var image := TextureRect.new()
	image.texture = _venue_texture(str(supplied.get("path", "")))
	var from_pack := image.texture != null
	if not from_pack and identity_data.get("licensedTerritoryArchive", false):
		var path := "res://assets/club-atlas/%s-%s.webp" % [identity_data.get("slug", ""), kind]
		if ResourceLoader.exists(path): image.texture = load(path)
	var from_archive := image.texture != null and not from_pack
	if image.texture == null: image.texture = _territory_texture(identity_data, kind)
	base.set_meta("has_photo", image.texture != null)
	base.set_meta("photo_from_pack", from_pack)
	base.set_meta("photo_kind", "pack" if from_pack else "archive" if from_archive else "generated")
	if from_pack:
		base.tooltip_text = "%s\n%s\n%s" % [supplied.get("credit", ""), supplied.get("source", ""), supplied.get("license", "")]
	elif from_archive:
		base.tooltip_text = "Photographie d’archive · Crédits et licences"
	else:
		base.tooltip_text = "Vue du club"
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.add_child(image)
	if dark:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.02, 0.04, 0.06, 0.70))
		gradient.set_color(1, Color(0.02, 0.04, 0.06, 0.98))
		gradient.add_point(0.40, Color(0.02, 0.04, 0.06, 0.12))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill_from = Vector2(0.5, 0)
		texture.fill_to = Vector2(0.5, 1)
		var shade := TextureRect.new()
		shade.texture = texture
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		base.add_child(shade)
	var overlay := margin(12)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.add_child(overlay)
	var content := v(8)
	overlay.add_child(content)
	base.set_meta("content", content)
	return base

static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

static func scroll(parent: Node) -> VBoxContainer:
	var s := ScrollContainer.new()
	s.follow_focus = true
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(s)
	var c := v(7)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(c)
	return c

static func cell(text: Variant, width: int, color: Color = INK, expand: bool = false) -> Label:
	var l := label(text, 13, color)
	l.custom_minimum_size.x = width
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if expand: l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

# Salary amounts always enter these helpers in engine weekly units.
static func salary(weekly: Variant) -> String:
	return preload("res://ui/salary_display.gd").format(weekly)

static func salary_amount(weekly: Variant) -> String:
	return preload("res://ui/salary_display.gd").amount(weekly)

static func salary_period(short: bool = false) -> String:
	return preload("res://ui/salary_display.gd").period_label(short)

# Native calendars start season n in 2025+n; contracts end the following year.
# Year only: the model supplies no exact expiry day.
static func season_label(season: Variant) -> String: return SeasonLabel.label(season)

static func contract_year(end_season: Variant) -> String:
	if not (end_season is int or end_season is float) or not is_finite(float(end_season)) or float(end_season) != floorf(float(end_season)) or end_season < 0 or end_season > 7973: return "—"
	return str(2026 + int(end_season))

static func rating_text(person: Dictionary, own_context: bool = false) -> String: return Knowledge.rating_text(person,own_context)
static func potential_text(person: Dictionary) -> String: return Knowledge.potential_text(person)
static func potential_tooltip(person: Dictionary) -> String: return Knowledge.potential_tooltip(person)
static func knowledge_sort_value(person: Dictionary, field: String, own_context: bool = false) -> Variant: return Knowledge.sort_value(person,field,own_context)
static func knowledge_bounds(person: Dictionary, field: String, own_context: bool = false) -> Dictionary: return Knowledge.bounds(person,field,own_context)
static func attributes_known(person: Dictionary, own_context: bool = false) -> bool: return Knowledge.attributes_known(person,own_context)
static func knowledge_delta(left: Dictionary, right: Dictionary, field: String, own_context: bool = false) -> String: return Knowledge.range_delta(left,right,field,own_context)
