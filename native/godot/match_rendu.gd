extends RefCounted
## Rendu moderne du match 3D (Forward+), 11 novembre 2026.
##
## Le projet reste en gl_compatibility par défaut (project.godot inchangé). Ce
## module n'est instancié par NativeMatchView que si la méthode de rendu
## réellement active est Forward+ (lancement avec --rendering-method
## forward_plus) et si CD_MATCH_RENDU ne vaut pas « actuel ». Sous
## gl_compatibility il n'existe pas : l'image reste celle d'avant.
##
## Moyens techniques seulement : lumière, ombres, occlusion, anticrénelage,
## relief de la pelouse, ombres de contact (courbe filmique en option). Aucune
## couleur, palette, tenue, habillage ni élément d'interface n'est modifié ;
## l'éclairage est étalonné pour retrouver les couleurs moyennes de l'image
## actuelle (voir ETALONNAGE). Réglages globaux du RenderingServer touchés
## (atlas d'ombres, filtre doux, qualité d'occlusion) : Forward+ seulement.
## Documentation : docs/match-rendu-moderne-20261111.md.
##
## Les trois niveaux suivent le réglage de qualité existant du match :
## « economy » = bas, « balanced » = moyen, « detail » = élevé.

const MODERNE := "forward_plus"
const SURFACE_MODERNE := "res://shaders/stadium_surface_moderne.gdshader"
## Calque 20 : seul le sol (pelouse, lignes, poteaux) reçoit les ombres de contact.
const CALQUE_SOL := 1 << 19
## Profondeur utile des caméras orthographiques du match (contenu le plus
## lointain ≈ 175 m en caméra TV). Godot ignore la distance maximale d'ombre
## pour une caméra orthographique : les cascades s'étalent du plan proche au
## plan lointain, d'où ce plan lointain resserré (500 m auparavant).
const PLAN_LOINTAIN := 320.0
## Fin de chaque cascade d'ombre, en mètres depuis la caméra, par caméra.
## TV : terrain visible entre ≈ 64 et 122 m ; action : ≈ 14 à 30 m ;
## tactique : ≈ 135 à 155 m.
const CASCADES := {
	"tv": [75.0, 100.0, 130.0],
	"action": [26.0, 36.0, 60.0],
	"tactical": [132.0, 146.0, 162.0],
}

## Étalonnage. Forward+ éclaire en espace linéaire, gl_compatibility dans
## l'espace sRGB : à réglages égaux, Forward+ donne des ombres plus denses, une
## ambiance plus faible et une pelouse plus claire. Ces valeurs ont été mesurées
## (rendu logiciel, séquence témoin, caméra TV) pour retrouver les couleurs
## moyennes de l'image actuelle sur la pelouse, le bord du terrain et les
## maillots, au soleil comme à l'ombre (écart moyen ≈ 0,01 sur 1).
##   « lineaire » (défaut) : pas de courbe, couleurs non éclairées (marqueurs
##   d'équipe, halo du ballon, blason) strictement inchangées ;
##   « filmique » (CD_MATCH_RENDU_TONEMAP=filmique) : hautes lumières adoucies,
##   mais toutes les couleurs passent par la courbe, marqueurs compris : choix
##   de direction artistique laissé à la graphiste.
const ETALONNAGE := {
	"lineaire": {"soleil": 1.8 / 0.92, "ambiance_jour": 0.6, "ambiance_soir": 0.6, "projecteurs": 1.6,
		"exposition_jour": 1.0, "exposition_soir": 1.0, "blanc": 1.0},
	"filmique": {"soleil": 1.0, "ambiance_jour": 0.35, "ambiance_soir": 0.38, "projecteurs": 1.0,
		"exposition_jour": 1.5, "exposition_soir": 1.12, "blanc": 2.0},
}

## Pour les tests headless (toujours gl_compatibility) : simule la méthode de
## rendu active. Vide = méthode réelle du RenderingServer.
static var methode_simulee := ""

var _view: Node3D
var _surface_origine: Shader
var _soleil_origine := 0.92
var _msaa_origine := -1
var _atlas_projecteurs_origine := -1
var _texture_contact: Texture2D
var _niveau := ""


static func methode_active() -> String:
	if not methode_simulee.is_empty():
		return methode_simulee
	return RenderingServer.get_current_rendering_method()


## Valeur normalisée de CD_MATCH_RENDU : « actuel » coupe le rendu moderne
## même sous Forward+ (comparaison, ou repli si un effet pose problème).
static func choix() -> String:
	var value := OS.get_environment("CD_MATCH_RENDU").strip_edges().to_lower()
	return value if value in ["actuel", "moderne"] else "auto"


## Courbe de tons : « lineaire » (défaut) ou « filmique » (CD_MATCH_RENDU_TONEMAP).
static func courbe() -> String:
	var value := OS.get_environment("CD_MATCH_RENDU_TONEMAP").strip_edges().to_lower()
	return "filmique" if value in ["filmique", "filmic"] else "lineaire"


static func actif() -> bool:
	return methode_active() == MODERNE and choix() != "actuel"


## Réglages par niveau. Table pure : lue par les tests et par l'outil de capture.
static func reglages(profile: String) -> Dictionary:
	var r := {
		"niveau": "moyen", "msaa": Viewport.MSAA_4X, "ombres_soleil": true, "atlas_ombres": 4096,
		"filtre_ombres": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "penombre_deg": 0.0,
		"fondu_cascades": false, "ssao": true, "ssao_qualite": RenderingServer.ENV_SSAO_QUALITY_MEDIUM,
		"ssao_demi": true, "ombres_projecteurs": false, "relief_pelouse": 1.0, "ombres_contact": true,
		"ciel_ambiant": true, "courbe": courbe(),
	}
	match profile:
		"economy":
			# Coût proche de l'actuel : ni ombres du soleil (comme aujourd'hui en
			# Économie), ni occlusion ; MSAA du jeu (2x) conservé.
			r.merge({"niveau": "bas", "msaa": -1, "ombres_soleil": false, "ssao": false,
				"ssao_qualite": RenderingServer.ENV_SSAO_QUALITY_LOW, "relief_pelouse": 0.6}, true)
		"detail":
			r.merge({"niveau": "élevé", "msaa": Viewport.MSAA_8X, "atlas_ombres": 8192,
				"filtre_ombres": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "penombre_deg": 0.5,
				"fondu_cascades": true, "ssao_qualite": RenderingServer.ENV_SSAO_QUALITY_HIGH,
				"ssao_demi": false, "ombres_projecteurs": true}, true)
	return r


func _init(view: Node3D) -> void:
	_view = view
	if view._grass:
		_surface_origine = view._grass.shader
	if is_instance_valid(view._sun):
		_soleil_origine = view._sun.light_energy
	for mesh: MeshInstance3D in view._ground_meshes:
		mesh.layers |= CALQUE_SOL
	if is_instance_valid(view._camera):
		view._camera.far = PLAN_LOINTAIN
	# Couleurs du public (couleurs d'instance) : écrites en sRGB et lues telles
	# quelles par gl_compatibility ; Forward+ les croirait linéaires et
	# blanchirait la foule. Même correction d'espace colorimétrique que la pelouse.
	for child: Node in view.get_children():
		if child is MultiMeshInstance3D and str(child.name).begins_with("Spectators"):
			var material := (child as MultiMeshInstance3D).material_override as StandardMaterial3D
			if material and material.vertex_color_use_as_albedo:
				material.vertex_color_is_srgb = true
	_texture_contact = _make_contact_texture()


func niveau() -> String:
	return _niveau


## Applique le niveau courant. Idempotent ; appelé par set_quality,
## set_camera et set_stadium_evening de la vue.
func appliquer() -> void:
	var view := _view
	if not view.is_node_ready():
		return
	var r := reglages(view._quality)
	var e: Dictionary = ETALONNAGE[r.courbe]
	_niveau = r.niveau
	var viewport := view.get_viewport()
	if viewport:
		if _msaa_origine < 0:
			_msaa_origine = viewport.msaa_3d
			_atlas_projecteurs_origine = viewport.positional_shadow_atlas_size
		viewport.msaa_3d = _msaa_origine if int(r.msaa) < 0 else int(r.msaa)
		viewport.positional_shadow_atlas_size = maxi(_atlas_projecteurs_origine, 4096) if r.ombres_projecteurs else _atlas_projecteurs_origine
	RenderingServer.directional_shadow_atlas_set_size(int(r.atlas_ombres), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(int(r.filtre_ombres))
	RenderingServer.positional_soft_shadow_filter_set_quality(int(r.filtre_ombres))
	# Le flou d'occlusion s'éteint par défaut entre 50 et 300 m : nos caméras
	# orthographiques regardent le terrain entre 14 et 165 m.
	RenderingServer.environment_set_ssao_quality(int(r.ssao_qualite), bool(r.ssao_demi), 0.5, 2, PLAN_LOINTAIN - 20.0, PLAN_LOINTAIN)
	_apply_sun(r, e)
	_apply_day(r, e)
	_apply_evening(r, e)
	_apply_grass(r)
	for entry: Dictionary in view._actors.values():
		var shadow := (entry.node as Node3D).get_node_or_null("ContactShadow")
		if shadow:
			shadow.visible = r.ombres_contact


## Ombre de contact douce sous un joueur (décalque projeté sur le sol seul).
func equiper_joueur(actor: Node3D) -> void:
	var decal := Decal.new()
	decal.name = "ContactShadow"
	decal.size = Vector3(1.5, 0.8, 1.5)
	decal.texture_albedo = _texture_contact
	decal.modulate = Color(1, 1, 1, 0.42)
	decal.albedo_mix = 1.0
	decal.cull_mask = CALQUE_SOL
	decal.upper_fade = 0.15
	decal.lower_fade = 0.15
	decal.visible = reglages(_view._quality).ombres_contact
	actor.add_child(decal)


func _apply_sun(r: Dictionary, e: Dictionary) -> void:
	var sun: DirectionalLight3D = _view._sun
	if not is_instance_valid(sun):
		return
	# Le soir, le kit du stade règle lui-même la lune (0,10) : on n'y touche pas.
	if not _view._stadium_evening:
		sun.light_energy = _soleil_origine * float(e.soleil)
	sun.shadow_enabled = r.ombres_soleil
	# Le soleil éclaire déjà directement : il ne doit pas compter une seconde
	# fois dans l'ambiance tirée du ciel (le ciel n'est presque jamais à l'écran).
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sun.light_angular_distance = r.penombre_deg
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = r.fondu_cascades
	var near: float = _view._camera.near if is_instance_valid(_view._camera) else 0.5
	var far: float = _view._camera.far if is_instance_valid(_view._camera) else PLAN_LOINTAIN
	var ends: Array = CASCADES.get(_view._camera_mode, CASCADES.tv)
	var span := maxf(far - near, 1.0)
	sun.directional_shadow_split_1 = clampf((ends[0] - near) / span, 0.0, 1.0)
	sun.directional_shadow_split_2 = clampf((ends[1] - near) / span, 0.0, 1.0)
	sun.directional_shadow_split_3 = clampf((ends[2] - near) / span, 0.0, 1.0)


func _apply_day(r: Dictionary, e: Dictionary) -> void:
	var settings := _day_environment()
	if settings == null:
		return
	# Ambiance issue du ciel existant (mêmes couleurs) : dessus des volumes plus
	# clairs que les dessous, au lieu d'un aplat uniforme.
	if r.ciel_ambiant:
		settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		settings.ambient_light_sky_contribution = 0.55
		settings.ambient_light_energy = e.ambiance_jour
		settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_apply_common(settings, r, e, e.exposition_jour)


func _apply_evening(r: Dictionary, e: Dictionary) -> void:
	var kit: Node = _view._stadium_kit
	if not is_instance_valid(kit) or kit.get("_evening") == null:
		return
	var settings: Environment = kit._evening
	# La nuit, pas de ciel de jour dans l'ambiance : couleur d'origine du soir.
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_energy = e.ambiance_soir
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	_apply_common(settings, r, e, e.exposition_soir)
	var floodlights := kit.get_node_or_null("Floodlights")
	if floodlights:
		for light: Node in floodlights.get_children():
			if light is SpotLight3D:
				var spot := light as SpotLight3D
				if not spot.has_meta("energie_origine"):
					spot.set_meta("energie_origine", spot.light_energy)
				spot.light_energy = float(spot.get_meta("energie_origine")) * float(e.projecteurs)
				spot.shadow_enabled = r.ombres_projecteurs
				spot.shadow_bias = 0.06


func _apply_common(settings: Environment, r: Dictionary, e: Dictionary, exposure: float) -> void:
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC if r.courbe == "filmique" else Environment.TONE_MAPPER_LINEAR
	settings.tonemap_exposure = exposure
	settings.tonemap_white = e.blanc
	settings.ssao_enabled = r.ssao
	settings.ssao_radius = 1.1
	settings.ssao_intensity = 1.8
	settings.ssao_power = 1.4
	settings.ssao_detail = 0.5
	settings.ssao_horizon = 0.06
	settings.ssao_sharpness = 0.98
	# L'occlusion n'assombrit que la lumière ambiante : joueurs au soleil intacts.
	settings.ssao_light_affect = 0.0
	settings.ssil_enabled = false
	settings.sdfgi_enabled = false
	settings.glow_enabled = false
	settings.fog_enabled = false
	settings.volumetric_fog_enabled = false


func _apply_grass(r: Dictionary) -> void:
	var grass: ShaderMaterial = _view._grass
	if grass == null:
		return
	# Le grain réglé par set_quality est repris tel quel d'un shader à l'autre.
	var micro: Variant = grass.get_shader_parameter("micro_detail")
	if r.relief_pelouse > 0.0:
		if grass.shader == _surface_origine:
			grass.shader = load(SURFACE_MODERNE) as Shader
		grass.set_shader_parameter("relief", r.relief_pelouse)
	elif _surface_origine:
		grass.shader = _surface_origine
	if micro != null:
		grass.set_shader_parameter("micro_detail", micro)


func _day_environment() -> Environment:
	var kit: Node = _view._stadium_kit
	if is_instance_valid(kit) and kit.get("_day") != null:
		return kit._day
	for child: Node in _view.get_children():
		if child is WorldEnvironment:
			return (child as WorldEnvironment).environment
	return null


static func _make_contact_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 1))
	gradient.set_color(1, Color(0, 0, 0, 0))
	gradient.add_point(0.45, Color(0, 0, 0, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
