extends RefCounted
## Écran « Options de carrière » · « Le mot du président » : photo du bureau de la direction, silhouette et
## nom du président (s'il est connu), mot d'accueil au tutoiement tiré de l'objectif du conseil, du rang du
## club et de son histoire, puis l'objectif et la trésorerie de départ en grand.
const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/carnet_skin.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const Kit = preload("res://ui/creation_options/kit.gd")
const Defis = preload("res://ui/creation_options/defis.gd")

static func build(app: Control, parent: Node, selected: Dictionary, data: Dictionary, state: String) -> void:
	# Défi de départ choisi : le président fixe l'objectif du défi (le moteur le posera à la création).
	var defi := Defis.choix(app, int(selected.get("id", -1)))
	if not defi.is_empty():
		selected = selected.duplicate()
		selected.goal = str(defi.objectif)
	var column := Kit.block(parent, "CreationPresidentWord", "", 1.0, false, Kit.SURFACE, 0)
	column.add_theme_constant_override("separation", C.px(10))
	# Bandeau photo : bureau de la direction, titre en haut, silhouette et nom du président en bas.
	var banner := Control.new()
	banner.name = "CreationPresidentBanner"
	banner.clip_contents = true
	banner.custom_minimum_size.y = C.px(196)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(banner)
	var picture := C.photo("trophy", Vector2.ZERO, true, .35)
	banner.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(Kit.SURFACE, .15), Color(Kit.SURFACE, .55), Color(Kit.SURFACE, 1.0)])
	gradient.offsets = PackedFloat32Array([0.0, .55, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(.5, 0)
	texture.fill_to = Vector2(.5, 1)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := C.margin(16)
	banner.add_child(inset)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := C.v(0)
	inset.add_child(stack)
	var heading := Kit.caps("Le mot du président")
	heading.name = "CreationPresidentWordTitle"
	stack.add_child(heading)
	stack.add_child(C.fill(Control.new(), true))
	var identity := C.h(14)
	stack.add_child(identity)
	# Portrait de la direction (art/immersive08/mail-direction), sinon silhouette.
	var face := C.texture("mail-direction")
	var portrait: Control
	if face == null: portrait = Silhouette.new()
	else:
		var disc := PhotoDisc.new()
		disc.show_texture(face)
		portrait = disc
	portrait.name = "CreationPresidentPortrait"
	portrait.custom_minimum_size = Vector2(C.px(92), C.px(92))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_END
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(portrait)
	var who := C.v(0)
	who.alignment = BoxContainer.ALIGNMENT_END
	identity.add_child(C.fill(who))
	var president: Variant = data.get("president")
	var name := str((president as Dictionary).get("name", "")).strip_edges() if president is Dictionary else ""
	if state == "pending" and name.is_empty():
		who.add_child(Kit.ghost(200, 26))
		who.add_child(Kit.ghost(130, 14))
	else:
		var title := Kit.ellipsis(C.label(name if not name.is_empty() else "Le président", 30, C.IVORY, true, 800))
		title.name = "CreationPresidentName"
		who.add_child(title)
		who.add_child(C.label("Président · " + G.club_name(selected), 17, C.MUTED, false))
	# Mot d'accueil, guillemet doré.
	var body := C.margin(16)
	body.add_theme_constant_override("margin_top", 0)
	column.add_child(body)
	var text := C.v(10)
	body.add_child(text)
	var quote := C.h(8)
	text.add_child(quote)
	var mark := C.label("«", 52, Editorial.RAIL_GOLD, true, 800)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	quote.add_child(mark)
	var welcome := C.wrap(welcome_text(selected), 20, C.IVORY)
	if not defi.is_empty():
		var bandeau := C.label("Défi · %s   %s %s" % [defi.titre, Defis.etoiles(int(defi.difficulte)), defi.niveau], 18, Editorial.RAIL_GOLD, true, 700)
		bandeau.name = "CreationPresidentChallenge"
		bandeau.tooltip_text = str(defi.raison)
		bandeau.mouse_filter = Control.MOUSE_FILTER_PASS
		text.add_child(bandeau)
		text.move_child(bandeau, 0)
	welcome.name = "CreationPresidentWelcome"
	quote.add_child(C.fill(welcome))
	text.add_child(C.rule())
	var facts := C.h(14)
	facts.name = "CreationPresidentFacts"
	text.add_child(facts)
	var goal := str(selected.get("goal", "")).strip_edges()
	var aim := Kit.figure(facts, goal if not goal.is_empty() else "Développer le projet", "Objectif du conseil", Editorial.RAIL_GOLD, 32)
	aim.name = "CreationPresidentGoal"
	C.fill(aim)
	if selected.has("cashMillions"):
		Kit.divider(facts)
		var cash := Kit.figure(facts, millions(float(selected.cashMillions)), "Trésorerie de départ", C.IVORY, 32)
		cash.name = "CreationPresidentCash"
		cash.tooltip_text = G.euros(roundi(float(selected.cashMillions) * 1_000_000))
		cash.mouse_filter = Control.MOUSE_FILTER_PASS
		C.fill(cash)

static func millions(value: float) -> String:
	var text := String.num(value, 1).replace(".", ",").trim_suffix(",0")
	return text + " M€"

## Mot d'accueil au tutoiement : histoire (fondation, titres), rang du club (base) et objectif du conseil.
static func welcome_text(club: Dictionary) -> String:
	var parts: Array[String] = ["Bienvenue chez toi."]
	var history: Dictionary = club.get("history", {}) if club.get("history") is Dictionary else {}
	var titles := 0
	for result: Variant in history.get("results", []):
		if result is Dictionary: titles += int((result as Dictionary).get("titles", 0))
	if history.has("founded"):
		var years := 2026 - int(history.founded)
		if titles > 0: parts.append("%d ans d’histoire et %d titre%s : ce maillot pèse lourd." % [years, titles, "s" if titles > 1 else ""])
		else: parts.append("Ce club a %d ans, et ses supporters attendent qu’on lui écrive un palmarès." % years)
	elif titles > 0:
		parts.append("%d titre%s au palmarès : ce maillot pèse lourd." % [titles, "s" if titles > 1 else ""])
	var base := int(club.get("base", 0))
	match str(club.get("goal", "")):
		"Jouer le titre": parts.append("Ici, on joue pour gagner. Le conseil attend un titre, rien de moins.")
		"Top 4": parts.append("Le conseil te veut dans les quatre premiers : on a les moyens d’y croire.")
		"Top 6": parts.append("Une place dans les six qualifiés, voilà ce qu’attend le conseil.")
		"Top 8": parts.append("Viser la première moitié du tableau, et faire grandir le groupe.")
		"Maintien": parts.append("D’abord le maintien. Le reste viendra, avec du travail.")
		"Viser la montée": parts.append("Ici, on veut monter. Pas dans trois ans : cette saison.")
		"Phases finales": parts.append("Les phases finales, voilà le cap. Avec nos moyens, il faudra être malins.")
		_: parts.append("Le conseil compte sur toi pour faire grandir le projet sportif.")
	if base >= 82: parts.append("On sait recevoir, alors fais honneur à la maison.")
	elif base > 0 and base <= 68: parts.append("On n’a pas les moyens des gros, on aura le cœur.")
	else: parts.append("Mon bureau t’est ouvert.")
	return " ".join(parts)

## Portrait rond cerclé d'or (photo découpée en disque).
class PhotoDisc extends Control:
	var disc := Control.new()
	var image := TextureRect.new()
	func _init() -> void:
		disc.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.draw.connect(func() -> void: disc.draw_circle(disc.size / 2.0, minf(disc.size.x, disc.size.y) / 2.0, Color.WHITE))
		add_child(disc)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.add_child(image)
		resized.connect(_fit)
	func show_texture(texture: Texture2D) -> void:
		image.texture = texture
	func _fit() -> void:
		var gap := maxf(2.0, size.x * .05)
		disc.position = Vector2(gap, gap)
		disc.size = size - Vector2(gap, gap) * 2.0
		image.position = Vector2.ZERO
		image.size = disc.size
		disc.queue_redraw()
		queue_redraw()
	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0
		draw_circle(center, radius, Color("0f2a20"))
		draw_arc(center, radius - 1.5, 0, TAU, 64, Editorial.RAIL_GOLD, maxf(2.0, radius * .06), true)

## Silhouette du président (aucun portrait disponible) : buste stylisé dans un disque cerclé d'or.
class Silhouette extends Control:
	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0
		draw_circle(center, radius, Color("0f2a20"))
		var ink := Color(0.95, 0.93, 0.86, .78)
		draw_circle(center + Vector2(0, -radius * .2), radius * .3, ink)
		var shoulders := PackedVector2Array()
		for i in 25:
			var angle := PI + PI * i / 24.0
			shoulders.append(center + Vector2(cos(angle) * radius * .62, radius * .75 + sin(angle) * radius * .5))
		draw_colored_polygon(shoulders, ink)
		draw_arc(center, radius - 1.5, 0, TAU, 64, Editorial.RAIL_GOLD, maxf(2.0, radius * .06), true)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: queue_redraw()
