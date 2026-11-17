extends RefCounted
## Écran « Options de carrière » : grammaire commune des blocs (cadre sombre, titre doré, squelettes,
## dates courtes) et accès à l'aperçu du club (commande moteur en lecture seule `club_preview`).
## Aucun état de jeu ici : l'aperçu est demandé au moteur, jamais pendant la construction de la page.
const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/carnet_skin.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const ENTRY := "res://ui/entry_screens.gd"
## Club pour lequel l'aperçu a été demandé (une seule demande par club), club dont la demande a échoué,
## et dernier aperçu reçu (le modèle suivant peut ne plus le porter).
const PREVIEW_REQUESTED := "club_preview_requested"
const PREVIEW_FAILED := "club_preview_failed"
const PREVIEW_CACHE := "club_preview_cache"
const SURFACE := Color("182426")
const DEEP := Color("111b1c")
const GHOST := Color(0.95, 0.93, 0.86, 0.07)
const MONTHS := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
const MONTHS_SHORT := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
const DAYS := ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
static var _caps: FontVariation

## Script de l'écran d'entrée, chargé à l'usage (pas de préchargement croisé avec entry_screens.gd).
static func entry() -> Variant:
	return load(ENTRY)

## Police des titres de bloc : capitales espacées.
static func caps_font() -> Font:
	if _caps == null:
		_caps = FontVariation.new()
		_caps.base_font = C.BOLD
		_caps.spacing_glyph = 1
	return _caps

static func caps(text: String, size: int = 19, color: Color = Editorial.RAIL_GOLD) -> Label:
	var label := C.label(text.to_upper(), size, color, true, 700)
	label.add_theme_font_override("font", caps_font())
	return label

## Cadre d'un bloc : surface sombre, filet, titre doré en capitales et emplacement à droite du titre
## (meta « aside ») pour une mention discrète. Rend la colonne de contenu.
static func block(parent: Node, id: String, title: String, ratio: float = 1.0, expand: bool = false, fill: Color = SURFACE, padding: int = 16) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.name = id
	frame.set_meta("immersive_style_applied", true)
	var style := C.box(fill, Editorial.LINE, 0, padding)
	style.set_corner_radius_all(0)
	frame.add_theme_stylebox_override("panel", style)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = ratio
	if expand: frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)
	var column := C.v(8)
	frame.add_child(column)
	if not title.is_empty():
		var head := C.h(10)
		column.add_child(head)
		var heading := caps(title)
		heading.name = id + "Title"
		heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(C.fill(heading))
		column.set_meta("aside", head)
	return column

## Bloc posé sur une photo d'ambiance (art/immersive08), assombrie par un voile : même titre et même
## colonne de contenu que `block`. `focus` : cadrage vertical de la photo (0 haut, 1 bas).
static func photo_block(parent: Node, id: String, title: String, art: String, ratio: float = 1.0, expand: bool = false, focus: float = .5, veil: float = .78) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.name = id
	frame.set_meta("immersive_style_applied", true)
	var style := C.box(DEEP, Editorial.LINE, 0, 0)
	style.set_corner_radius_all(0)
	style.content_margin_left = 1
	style.content_margin_right = 1
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	frame.add_theme_stylebox_override("panel", style)
	frame.clip_contents = true
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = ratio
	if expand: frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)
	var picture := C.photo(art, Vector2.ZERO, true, focus)
	picture.name = id + "Photo"
	frame.add_child(picture)
	var shade := ColorRect.new()
	shade.color = Color(DEEP, veil)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(shade)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(DEEP, .92), Color(DEEP, .35), Color(DEEP, .0)])
	gradient.offsets = PackedFloat32Array([0.0, .45, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 0)
	var sweep := TextureRect.new()
	sweep.texture = texture
	sweep.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(sweep)
	var inset := C.margin(16)
	frame.add_child(inset)
	var column := C.v(8)
	inset.add_child(column)
	if not title.is_empty():
		var head := C.h(10)
		column.add_child(head)
		var heading := caps(title)
		heading.name = id + "Title"
		heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(C.fill(heading))
		column.set_meta("aside", head)
	return column

static func aside(column: VBoxContainer) -> HBoxContainer:
	return column.get_meta("aside") if column.has_meta("aside") else null

## Mention discrète (« indicatif ») : petite pastille au filet fin.
static func tag(text: String, color: Color = C.MUTED) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.set_meta("immersive_style_applied", true)
	var style := C.box(Color.TRANSPARENT, color, 3, 0)
	style.content_margin_left = C.px(7)
	style.content_margin_right = C.px(7)
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.border_color = Color(color, .55)
	frame.add_theme_stylebox_override("panel", style)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	var caption := C.label(text, 16, color, false, 600)
	frame.add_child(caption)
	return frame

## Emplacement en attente des données (aucun texte) : barre pâle aux coins doux.
static func ghost(width: float = 0.0, height: float = 18.0, expand: bool = false) -> Panel:
	var bar := Panel.new()
	bar.set_meta("immersive_style_applied", true)
	bar.name = "CreationOptionsGhost"
	var style := StyleBoxFlat.new()
	style.bg_color = GHOST
	style.set_corner_radius_all(maxi(2, C.px(5)))
	bar.add_theme_stylebox_override("panel", style)
	bar.custom_minimum_size = Vector2(C.px(width), C.px(height))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand: bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return bar

static func disc_ghost(diameter: float) -> Control:
	var disc := DiscGhost.new()
	disc.custom_minimum_size = Vector2(C.px(diameter), C.px(diameter))
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return disc

class DiscGhost extends Control:
	func _draw() -> void:
		draw_circle(size / 2.0, minf(size.x, size.y) / 2.0, GHOST)

## Filet vertical fin entre deux faits.
static func divider(parent: Container) -> void:
	Editorial.divider(parent)

## Grand chiffre et sa légende.
static func figure(parent: Container, value: String, caption: String, value_color: Color = C.IVORY, size: int = 40) -> VBoxContainer:
	var column := C.v(0)
	parent.add_child(column)
	column.add_child(C.label(value, size, value_color, true, 800))
	column.add_child(C.label(caption, 17, C.MUTED, false, 600))
	return column

# --- Dates ---

static func parse(iso: String) -> Dictionary:
	var parts := iso.substr(0, 10).split("-")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int(): return {}
	var y := int(parts[0])
	var m := clampi(int(parts[1]), 1, 12)
	var d := int(parts[2])
	var unix := Time.get_unix_time_from_datetime_dict({"year":y, "month":m, "day":d, "hour":12, "minute":0, "second":0})
	var weekday := (int(Time.get_datetime_dict_from_unix_time(unix).weekday) + 6) % 7
	return {"year":y, "month":m, "day":d, "weekday":weekday, "unix":unix}

## « lun. 13 juil. »
static func short_date(iso: String) -> String:
	var date := parse(iso)
	if date.is_empty(): return ""
	return "%s %d %s" % [str(DAYS[date.weekday]).substr(0, 3) + ".", int(date.day), MONTHS_SHORT[int(date.month) - 1]]

## « 13 juil. »
static func day_month(iso: String) -> String:
	var date := parse(iso)
	if date.is_empty(): return ""
	return "%d %s" % [int(date.day), MONTHS_SHORT[int(date.month) - 1]]

static func weekday(iso: String) -> String:
	var date := parse(iso)
	return "" if date.is_empty() else str(DAYS[date.weekday])

static func month(iso: String) -> String:
	var date := parse(iso)
	return "" if date.is_empty() else str(MONTHS[int(date.month) - 1])

# --- Aperçu du club (commande moteur `club_preview`) ---

## Aperçu reçu pour ce club, sinon {}. Garde en mémoire le dernier aperçu reçu.
static func preview(app: Control, club_id: int) -> Dictionary:
	var live: Variant = app.model.get("meta", {}).get("clubPreview")
	if live is Dictionary and int(live.get("club", -1)) == club_id:
		app.management_ui[PREVIEW_CACHE] = (live as Dictionary).duplicate(true)
	var cached: Variant = app.management_ui.get(PREVIEW_CACHE, {})
	if cached is Dictionary and int(cached.get("club", -1)) == club_id: return cached
	return {}

## « ready » (aperçu reçu), « pending » (demande en cours ou à venir : squelettes) ou « fallback »
## (moteur sans cette commande ou réponse vide : les blocs se replient sur le catalogue de création).
static func preview_state(app: Control, club_id: int) -> String:
	if not preview(app, club_id).is_empty(): return "ready"
	if int(app.management_ui.get(PREVIEW_FAILED, -1)) == club_id: return "fallback"
	if int(app.management_ui.get(PREVIEW_REQUESTED, -1)) == club_id and not app.waiting: return "fallback"
	return "pending"

## Demande l'aperçu une seule fois par club, après la construction de la page (la réponse la reconstruit).
## Une commande déjà en cours (mesure de la machine) repousse la demande au rendu suivant.
static func request_preview(app: Control, club_id: int) -> void:
	if preview_state(app, club_id) != "pending" or int(app.management_ui.get(PREVIEW_REQUESTED, -1)) == club_id: return
	var send := func() -> void:
		if not is_instance_valid(app) or app.waiting or app.route != "Création": return
		if int(app.management_ui.get(PREVIEW_REQUESTED, -1)) == club_id: return
		app.management_ui[PREVIEW_REQUESTED] = club_id
		# Un refus ne reconstruit pas la page : on la reconstruit ici, en mode repli.
		app.bridge.command_failed.connect(func(_message: String) -> void:
			if not is_instance_valid(app): return
			app.management_ui[PREVIEW_FAILED] = club_id
			if app.route == "Création": app.call_deferred("_render", false), CONNECT_ONE_SHOT)
		# Sans carrière, toute réponse reconstruit la page ; avec une carrière en cours, l'écran pourrait être
		# jugé à jour (rafraîchissement par écran) : on le reconstruit ici.
		app.bridge.model_changed.connect(func(_model: Dictionary) -> void:
			if is_instance_valid(app) and app._has_career() and app.route == "Création": app.call_deferred("_render", false), CONNECT_ONE_SHOT)
		app._command("club_preview", {"club": club_id})
	send.call_deferred()

# --- Clubs du catalogue ---

static func club_by_id(app: Control, id: Variant) -> Dictionary:
	if id == null: return {}
	for club: Dictionary in app.pack_manager.creation_catalogue():
		if int(club.get("id", -1)) == int(id): return club
	return {}

## Écusson d'un club du catalogue (identité du pack), sinon blason généré à partir du nom.
static func crest(app: Control, id: Variant, name: String, width: int) -> Control:
	var club := club_by_id(app, id)
	var base: bool = app.pack_manager.selected_id("creation") == "base"
	var control: Control = entry().call("_creation_crest", club, width, base) if not club.is_empty() else G.crest({"name":name, "abbr":_initials(name)}, width)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return control

static func club_name(app: Control, id: Variant, fallback: String) -> String:
	var club := club_by_id(app, id)
	return G.club_name(club) if not club.is_empty() else fallback

static func _initials(name: String) -> String:
	var letters := ""
	for word: String in name.split(" ", false):
		if word.length() > 2: letters += word.substr(0, 1).to_upper()
	return letters.substr(0, 3) if not letters.is_empty() else "XV"

## Libellé court d'une étiquette bornée (ellipse) : jamais de texte coupé net.
static func ellipsis(label: Label, lines: int = 1) -> Label:
	label.clip_text = lines == 1
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if lines > 1:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = lines
	return label
