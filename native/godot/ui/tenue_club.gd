extends RefCounted
## Maillots et écussons de la banque d'images recolorés aux couleurs d'un club (shaders/recoloration.gdshader).
## Couleur de base : la couleur du club ; motif : l'encre neutre de contraste (comme la salle 3D du vestiaire,
## aucune seconde couleur de club n'est inventée). Motif et forme d'écusson : stables pour un même club.

const BanqueImages = preload("res://ui/banque_images.gd")
const RoomIdentity = preload("res://ui/contextual/rooms/room_identity.gd")
const SHADER = preload("res://shaders/recoloration.gdshader")
const MOTIFS := ["uni", "cerceaux", "bandes-verticales", "quartiers", "chevron", "ceinture", "manches-contrastees", "col-poignets-contrastes"]
const ECUSSONS := ["bouclier-classique", "bouclier-moderne", "blason-banniere", "rond", "ovale", "hexagone", "losange", "etoile"]

static func _identite(club: Dictionary) -> Dictionary:
	return club.get("presentation", club) if club.get("presentation") is Dictionary else club

static func _graine(club: Dictionary) -> int:
	var c := _identite(club)
	return absi(hash(str(c.get("slug", club.get("id", c.get("name", ""))))))

static func couleurs(club: Dictionary) -> Array[Color]:
	var base := RoomIdentity.primary(_identite(club))
	return [base, RoomIdentity.contrast(base)]

static func motif(club: Dictionary) -> String: return MOTIFS[_graine(club) % MOTIFS.size()]
static func forme_ecusson(club: Dictionary) -> String: return ECUSSONS[(_graine(club) / 7) % ECUSSONS.size()]

## TextureRect recoloré ; null si la banque n'a pas l'image ou son masque.
static func image(id: String, base: Color, motif_couleur: Color, taille: Vector2 = Vector2.ZERO) -> TextureRect:
	var carte := BanqueImages.texture(id)
	var masque := BanqueImages.texture(id + "-masque")
	if carte == null or masque == null: return null
	var rect := TextureRect.new()
	rect.texture = carte
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = taille
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Le club doit dominer : si le blanc du masque (zones recolorables) n'est qu'un motif minoritaire
	# (cerceaux, bandes, chevron…), la couleur du club passe sur le corps et l'encre sur le motif.
	if float(BanqueImages.info(id + "-masque").get("part_blanche", 1.0)) < 0.4:
		var echange := base
		base = motif_couleur
		motif_couleur = echange
	var materiau := ShaderMaterial.new()
	materiau.shader = SHADER
	materiau.set_shader_parameter("masque", masque)
	materiau.set_shader_parameter("couleur_base", base)
	materiau.set_shader_parameter("couleur_motif", motif_couleur)
	materiau.set_shader_parameter("gris_moyen", float(BanqueImages.info(id).get("gris_moyen", 0.62)))
	rect.material = materiau
	rect.set_meta("banque_image", id)
	return rect

static func maillot(club: Dictionary, taille: Vector2 = Vector2.ZERO) -> TextureRect:
	var c := couleurs(club)
	var rect := image("maillot-%s-face" % motif(club), c[0], c[1], taille)
	if rect != null: rect.name = "ClubKitShirt"
	return rect

## Écusson recoloré avec les initiales du club ; null sans image.
static func ecusson(club: Dictionary, largeur: int = 56) -> Control:
	var c := couleurs(club)
	var rect := image("ecusson-%s" % forme_ecusson(club), c[0], c[1], Vector2(largeur, largeur))
	if rect == null: return null
	rect.name = "ClubCrestRecolored"
	var initiales := Label.new()
	initiales.text = str(_identite(club).get("abbr", "XV"))
	initiales.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initiales.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initiales.add_theme_font_size_override("font_size", maxi(8, roundi(largeur * 0.26)))
	initiales.add_theme_color_override("font_color", c[1])
	initiales.add_theme_color_override("font_outline_color", c[0].darkened(0.5))
	initiales.add_theme_constant_override("outline_size", maxi(1, roundi(largeur * 0.03)))
	initiales.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	initiales.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.add_child(initiales)
	return rect
