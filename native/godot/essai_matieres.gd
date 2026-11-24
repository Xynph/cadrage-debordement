extends RefCounted
## ESSAI « matières » (24/11/2026) : pelouse et tissu des maillots des temps forts 3D.
## Actif seulement si CD_ESSAI_MATIERES vaut A, B ou C ; absente, le jeu est strictement inchangé.
##   A = sobre : bandes de tonte marquées (reflet selon le côté de la caméra) + tissu discret
##   B = réaliste : A + variation de teinte (bruit), usure en-but/centre, relief des brins, plis du maillot
##   C = libre : tonte en damier + relief, maillot à panneaux aérés et chaussettes côtelées
## Textures : hauteurs exportées de Material Maker 1.8 (graphes .ptex à côté), normal map et
## grandes taches calculées ici (Image.bump_map_to_normal_map, FastNoiseLite). Présentation seule.

const DOSSIER := "res://essai_matieres_textures/"
const SURFACE := "res://shaders/stadium_surface_essai_matieres.gdshader"
const MAILLOT := "res://shaders/athlete_kit_essai_matieres.gdshader"

static var _textures: Dictionary = {}


static func option() -> int:
	match OS.get_environment("CD_ESSAI_MATIERES").strip_edges().to_upper():
		"A": return 1
		"B": return 2
		"C": return 3
	return 0


static func pelouse(grass: ShaderMaterial) -> void:
	var choix := option()
	if choix == 0:
		return
	grass.shader = load(SURFACE) as Shader
	grass.set_shader_parameter("option", choix)
	grass.set_shader_parameter("brins", _hauteur("pelouse_hauteur_mm.png"))
	grass.set_shader_parameter("brins_normal", _normal("pelouse_hauteur_mm.png", 6.0))
	grass.set_shader_parameter("taches", _bruit("taches", 512, 0.012, 4))


## Remplace le shader des tenues par sa copie « tissu » ; couleurs et paramètres inchangés.
static func maillot(material: ShaderMaterial) -> void:
	var choix := option()
	if choix == 0:
		return
	material.shader = load(MAILLOT) as Shader
	material.set_shader_parameter("option", choix)
	material.set_shader_parameter("maille", _hauteur("tissu_hauteur_mm.png"))
	material.set_shader_parameter("plis", _bruit("plis", 256, 0.02, 3))


static func _image(fichier: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DOSSIER + fichier))
	image.convert(Image.FORMAT_RGBA8)
	return image


static func _hauteur(fichier: String) -> Texture2D:
	var key := "h:" + fichier
	if not _textures.has(key):
		var image := _image(fichier)
		image.generate_mipmaps()
		_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]


static func _normal(fichier: String, force: float) -> Texture2D:
	var key := "n:" + fichier
	if not _textures.has(key):
		var image := _image(fichier)
		image.bump_map_to_normal_map(force)
		image.generate_mipmaps()
		_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]


static func _bruit(nom: String, taille: int, frequence: float, octaves: int) -> Texture2D:
	var key := "b:" + nom
	if not _textures.has(key):
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.seed = 2711 if nom == "taches" else 907
		noise.frequency = frequence
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = octaves
		var image := noise.get_seamless_image(taille, taille)
		image.convert(Image.FORMAT_RGBA8)
		image.generate_mipmaps()
		_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]
