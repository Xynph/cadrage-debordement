extends RefCounted
## Matières du match 3D (option B de l'essai du 24/11/2026, choisie par Léo) :
## textures de la pelouse et du tissu des tenues. Présentation seule.
## Hauteurs et relief : art/matieres/ (graphes Material Maker .ptex à côté,
## normal map tirée de la hauteur par Image.bump_map_to_normal_map) ;
## taches de la pelouse et plis des maillots : FastNoiseLite, calculés une fois.

const PELOUSE_HAUTEUR := preload("res://art/matieres/pelouse_hauteur.png")
const PELOUSE_NORMAL := preload("res://art/matieres/pelouse_normal.png")
const TISSU_MAILLE := preload("res://art/matieres/tissu_maille.png")

static var _bruits: Dictionary = {}


static func pelouse(grass: ShaderMaterial) -> void:
	grass.set_shader_parameter("brins", PELOUSE_HAUTEUR)
	grass.set_shader_parameter("brins_normal", PELOUSE_NORMAL)
	grass.set_shader_parameter("taches", _bruit("taches", 512, 0.012, 4, 2711))


static func maillot(material: ShaderMaterial) -> void:
	material.set_shader_parameter("maille", TISSU_MAILLE)
	material.set_shader_parameter("plis", _bruit("plis", 256, 0.02, 2, 907))


static func _bruit(nom: String, taille: int, frequence: float, octaves: int, graine: int) -> Texture2D:
	if not _bruits.has(nom):
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.seed = graine
		noise.frequency = frequence
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = octaves
		var image := noise.get_seamless_image(taille, taille)
		image.convert(Image.FORMAT_RGBA8)
		image.generate_mipmaps()
		_bruits[nom] = ImageTexture.create_from_image(image)
	return _bruits[nom]
