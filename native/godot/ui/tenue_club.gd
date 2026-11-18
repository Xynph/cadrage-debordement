extends RefCounted
## Maillots et écussons de la banque d'images recolorés aux couleurs d'un club (shaders/recoloration.gdshader).
## Couleur de base : la couleur du club ; motif : sa deuxième couleur (ui/couleurs_clubs.json, repli sur l'encre de
## contraste). Motif et forme d'écusson : stables pour un même club.

const BanqueImages = preload("res://ui/banque_images.gd")
const RoomIdentity = preload("res://ui/contextual/rooms/room_identity.gd")
const SHADER = preload("res://shaders/recoloration.gdshader")
const MOTIFS := ["uni", "cerceaux", "bandes-verticales", "quartiers", "chevron", "ceinture", "manches-contrastees", "col-poignets-contrastes"]
const BAS := ["uni", "bande", "deux-bandes"]
const ECUSSONS := ["bouclier-classique", "bouclier-moderne", "blason-banniere", "rond", "ovale", "hexagone", "losange", "etoile"]

static func _identite(club: Dictionary) -> Dictionary:
	return club.get("presentation", club) if club.get("presentation") is Dictionary else club

static func _graine(club: Dictionary) -> int:
	var c := _identite(club)
	return absi(hash(str(c.get("slug", club.get("id", c.get("name", ""))))))

static func couleurs(club: Dictionary) -> Array[Color]:
	var base := RoomIdentity.primary(_identite(club))
	return [base, RoomIdentity.secondary(_identite(club), base)]

static func motif(club: Dictionary) -> String: return MOTIFS[_graine(club) % MOTIFS.size()]
static func forme_ecusson(club: Dictionary) -> String: return ECUSSONS[(_graine(club) / 7) % ECUSSONS.size()]

## TextureRect recoloré ; null si la banque n'a pas l'image ou son masque.
static func image(id: String, base: Color, motif_couleur: Color, taille: Vector2 = Vector2.ZERO, dominer: bool = true) -> TextureRect:
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
	if dominer and float(BanqueImages.info(id + "-masque").get("part_blanche", 1.0)) < 0.4:
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

## Short et chaussettes : short dans l'encre de contraste (liseré à la couleur du club), chaussettes à la
## couleur du club (bandes dans l'encre). Variante stable par club.
static func bas(club: Dictionary, piece: String, taille: Vector2 = Vector2.ZERO) -> TextureRect:
	var c := couleurs(club)
	var variante: String = BAS[(_graine(club) / 11) % BAS.size()]
	var id := "%s-%s-face" % [piece, variante]
	var rect: TextureRect
	if piece == "short": rect = image(id, c[1] if variante == "uni" else c[0], c[1], taille, false)
	else: rect = image(id, c[0], c[1], taille, true)
	if rect != null: rect.name = "ClubKit" + piece.capitalize()
	return rect

## Planche de la tenue complète : maillot de face et de dos, short, chaussettes ; null sans images.
static func planche(club: Dictionary, hauteur: float = 300.0) -> Control:
	var face := maillot(club, Vector2(hauteur, hauteur))
	if face == null: return null
	var rangee := HBoxContainer.new()
	rangee.name = "ClubKitBoard"
	rangee.alignment = BoxContainer.ALIGNMENT_CENTER
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := couleurs(club)
	for piece: Control in [face, image("maillot-%s-dos" % motif(club), c[0], c[1], Vector2(hauteur, hauteur)), bas(club, "short", Vector2(hauteur * 0.8, hauteur * 0.8)), bas(club, "chaussettes", Vector2(hauteur * 0.6, hauteur * 0.8))]:
		if piece != null:
			piece.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			rangee.add_child(piece)
	return rangee
