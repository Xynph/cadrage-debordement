extends Node3D
## Ambiance du match 3D (24/11/2026, choix de Léo sur l'essai « ambiance ») : effets purement
## décoratifs, lus dans ce que la vue montre déjà ; aucun tirage, aucune règle, aucun résultat touché.
##   - foule vivante : bruit FastNoiseLite (NoiseTexture2D) lu par shaders/foule.gdshader : des poches
##     de public plus vives défilent lentement sur les tribunes, jamais tout le stade à la fois ;
##   - à chaque essai aplati montré (match_foule.gd, etat().essai) : confettis aux couleurs du club qui
##     marque et deux fumigènes francs de sa couleur, dans les tribunes du côté de l'en-but ;
##   - pluie quand le moteur l'annonce (`live.meteo.pluie` 1 ou 2 = forte, sinon `live.weather` = Pluie),
##     transmise aussi par les plans des temps forts ; de jour, ciel couvert et ombres adoucies.
## Particules natives, valables en gl_compatibility comme en Forward+ : CPUParticles3D pour les petits
## nombres (fumée, papiers), GPUParticles3D pour la pluie (sans collisions ni attracteurs).
## Variables : CD_MATCH_AMBIANCE=aucune coupe tout (comparaison) ; CD_AMBIANCE_CAPTURE=soir-pluie force
## le soir et le crachin (captures seulement) ; CD_AMBIANCE_MESURE=1 écrit les images/seconde au journal.

const BRUIT_FREQUENCE := 0.018
const CONFETTIS := 650
const CONFETTIS_POINTS := 450
const CONFETTIS_DUREE := 7.0
const FUMIGENES := 2
const FUMEE_DUREE := 30.0
const FUMEE_PARTICULES := 90
## Échelle finale d'une bouffée (m) : le panache s'élargit en montant.
const FUMEE_TAILLE_MAX := 6.0
## Hauteur maximale (m) des foyers : rangs bas, pour que le panache reste dans la tribune filmée.
const FUMEE_RANG_MAX := 5.0
## Gouttes par niveau de pluie du moteur (1 : pluie, 2 : forte pluie), nappe proche et lointaine.
const PLUIE_PROCHE := [0, 600, 1200]
const PLUIE_LOINTAINE := [0, 1600, 3000]
## Distance (m) du centre de chaque nappe devant la caméra.
const PLUIE_PROCHE_DISTANCE := 8.0
const PLUIE_LOINTAINE_DISTANCE := 30.0
## Ciel couvert de jour sous la pluie : énergie du soleil gardée et opacité des ombres.
const SOLEIL_CRACHIN := 0.55
const SOLEIL_FORTE_PLUIE := 0.4
const OMBRE_PLUIE := 0.35
const CIEL_COUVERT_HAUT := Color("68717a")
const CIEL_COUVERT_HORIZON := Color("a9afb3")

var actif := true
var _vue: Node3D
var _shader_foule: Shader
var _bruit_texture: NoiseTexture2D
var _confettis: CPUParticles3D
var _fumees: Array[CPUParticles3D] = []
var _fumee_restante := 0.0
var _fumee_texture: ImageTexture
var _essai_montre := false
var _essais := 0
var _pluies: Array[GPUParticles3D] = []
var _niveau_pluie := 0
var _soleil_pose := -1.0
var _soleil_base := 1.0
var _ombre_base := 1.0
var _ciel_origine: Array = []
var _capture := ""
var _mesure := false
var _images := 0
var _debut_us := 0
var _images_essai := 0
var _duree_essai_us := 0
var _dernier_us := 0


func _ready() -> void:
	name = "Ambiance"
	_vue = get_parent() as Node3D
	actif = OS.get_environment("CD_MATCH_AMBIANCE").strip_edges().to_lower() != "aucune" and _vue != null and _vue.has_method("set_stadium_evening")
	_capture = OS.get_environment("CD_AMBIANCE_CAPTURE").strip_edges().to_lower()
	_mesure = OS.get_environment("CD_AMBIANCE_MESURE") == "1"
	_debut_us = Time.get_ticks_usec()
	_dernier_us = _debut_us
	if actif:
		_confettis = _creer_confettis()
		for i in FUMIGENES:
			_fumees.append(_creer_fumigene())


## Image montrée (apply_frame de la vue) : seule la météo annoncée par le moteur est lue ici.
func observer(live: Dictionary) -> void:
	if not actif:
		return
	# Les images des temps forts sans météo (plans, gel) gardent la pluie déjà réglée.
	var niveau := _niveau_pluie
	var meteo: Variant = live.get("meteo")
	if meteo is Dictionary and (meteo as Dictionary).has("pluie"):
		niveau = clampi(int(round(float((meteo as Dictionary).get("pluie", 0)))), 0, 2)
	elif not str(live.get("weather", "")).is_empty():
		niveau = 1 if str(live.get("weather", "")).to_lower() == "pluie" else 0
	if _capture == "soir-pluie":
		niveau = maxi(niveau, 1)
	if niveau != _niveau_pluie:
		_regler_pluie(niveau)


func _process(delta: float) -> void:
	if _mesure:
		_compter()
	if _capture == "soir-pluie" and _vue and not bool(_vue.get("_stadium_evening")):
		_vue.call("set_stadium_evening", true)
	if not actif:
		return
	var matieres: Array = _vue.get("_foule_matieres")
	if not matieres.is_empty() and (matieres[0] as ShaderMaterial).get_shader_parameter("bruit_foule") != _bruit_texture or _bruit_texture == null:
		_foule_vivante(matieres)
	var essai := bool(_vue.get("foule").etat().get("essai", false))
	if essai and not _essai_montre:
		_feter_essai()
	_essai_montre = essai
	if _fumee_restante > 0.0:
		_fumee_restante -= delta
		if _fumee_restante <= 0.0:
			for fumee in _fumees:
				fumee.emitting = false
	_suivre_camera()
	_regler_ciel()


# --- Foule vivante --------------------------------------------------------------------------

func _foule_vivante(matieres: Array) -> void:
	if _bruit_texture == null:
		var bruit := FastNoiseLite.new()
		bruit.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		bruit.frequency = BRUIT_FREQUENCE
		bruit.fractal_octaves = 3
		bruit.seed = 1124
		_bruit_texture = NoiseTexture2D.new()
		_bruit_texture.width = 256
		_bruit_texture.height = 256
		_bruit_texture.seamless = true
		_bruit_texture.noise = bruit
	for matiere: ShaderMaterial in matieres:
		matiere.set_shader_parameter("bruit_foule", _bruit_texture)
		matiere.set_shader_parameter("bruit_force", 1.0)


# --- Essai : confettis et fumigènes ----------------------------------------------------------

## Têtes de spectateurs (repère de la vue) retenues par `filtre`, tirage décoratif à graine fixe.
func _tetes(filtre: Callable, nombre: int, graine: int) -> PackedVector3Array:
	var choix := PackedVector3Array()
	var tetes: PackedVector3Array = _vue.get("foule_tetes")
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var essais := 0
	while choix.size() < nombre and essais < nombre * 40 and not tetes.is_empty():
		essais += 1
		var p := tetes[rng.randi_range(0, tetes.size() - 1)]
		if filtre.call(p):
			choix.append(p)
	return choix


func _feter_essai() -> void:
	_essais += 1
	var camp := int(_vue.get("foule").essai_camp)
	var couleurs: Array = _vue.get("_team_colors")
	var club: Color = couleurs[camp] if camp in [0, 1] else Color(0.96, 0.95, 0.9)
	# Côté de l'en-but où le ballon est aplati : tribunes de ce bout du stade.
	var ballon := _vue.get("_ball") as Node3D
	var cote := signf(ballon.global_position.x) if ballon else 0.0
	var pres := func(p: Vector3) -> bool: return cote == 0.0 or p.x * cote > 20.0
	var points := _tetes(pres, CONFETTIS_POINTS, 4100 + _essais)
	if not points.is_empty():
		var rampe := Gradient.new()
		rampe.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		rampe.offsets = PackedFloat32Array([0.0, 0.4, 0.62])
		rampe.colors = PackedColorArray([club, club.lightened(0.3), Color(0.97, 0.96, 0.92)])
		_confettis.color_initial_ramp = rampe
		_confettis.emission_points = points
		_confettis.restart()
		_confettis.emitting = true
	# Fumigènes : rares (deux, à l'essai seulement) et localisés, dans la tribune derrière l'en-but
	# (celle que montrent le ralenti et la célébration).
	var foyers := _tetes(func(p: Vector3) -> bool: return cote != 0.0 and p.x * cote > 58.0 and absf(p.z) < 30.0 and p.y < FUMEE_RANG_MAX, FUMIGENES, 5200 + _essais)
	for i in mini(foyers.size(), _fumees.size()):
		var fumee := _fumees[i]
		var rampe_fumee := Gradient.new()
		rampe_fumee.offsets = PackedFloat32Array([0.0, 0.06, 0.35, 0.75, 1.0])
		rampe_fumee.colors = PackedColorArray([Color(club, 0.0), Color(club.lightened(0.1), 0.95), Color(club.lerp(Color(0.8, 0.8, 0.8), 0.3), 0.7), Color(club.lerp(Color(0.78, 0.78, 0.8), 0.7), 0.3), Color(0.78, 0.78, 0.8, 0.0)])
		fumee.color_ramp = rampe_fumee
		fumee.position = foyers[i] + Vector3(0, 0.3, 0)
		fumee.restart()
		fumee.emitting = true
	_fumee_restante = FUMEE_DUREE


func _creer_confettis() -> CPUParticles3D:
	var papier := QuadMesh.new()
	papier.size = Vector2(0.26, 0.2)
	var matiere := StandardMaterial3D.new()
	matiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Billboard simple qui garde l'échelle : les particules inactives (échelle 0) restent invisibles
	# (BILLBOARD_PARTICLES les dessinait en disques noirs à l'émetteur).
	matiere.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	matiere.billboard_keep_scale = true
	matiere.vertex_color_use_as_albedo = true
	matiere.cull_mode = BaseMaterial3D.CULL_DISABLED
	papier.material = matiere
	var confettis := CPUParticles3D.new()
	confettis.name = "Confettis"
	confettis.mesh = papier
	confettis.amount = CONFETTIS
	confettis.lifetime = CONFETTIS_DUREE
	confettis.one_shot = true
	confettis.emitting = false
	confettis.explosiveness = 0.55
	confettis.local_coords = false
	confettis.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	confettis.direction = Vector3(0, 1, 0)
	confettis.spread = 38.0
	confettis.initial_velocity_min = 2.0
	confettis.initial_velocity_max = 5.0
	confettis.gravity = Vector3(0.4, -1.4, 0.0)
	confettis.damping_min = 1.2
	confettis.damping_max = 2.2
	confettis.angle_min = 0.0
	confettis.angle_max = 360.0
	confettis.angular_velocity_min = -540.0
	confettis.angular_velocity_max = 540.0
	confettis.scale_amount_min = 0.7
	confettis.scale_amount_max = 1.3
	confettis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(confettis)
	return confettis


## Bouffée de fumée irrégulière (bruit FastNoiseLite sous un fondu radial), calculée une fois.
func _texture_fumee() -> ImageTexture:
	var bruit := FastNoiseLite.new()
	bruit.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	bruit.frequency = 0.07
	bruit.fractal_octaves = 4
	bruit.seed = 77
	var cote := 64
	var image := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
	for y in cote:
		for x in cote:
			var d := Vector2(x - cote * 0.5 + 0.5, y - cote * 0.5 + 0.5).length() / (cote * 0.5)
			var bord := clampf(1.0 - d, 0.0, 1.0)
			var n := bruit.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf(smoothstep(0.0, 0.75, bord) * (0.4 + 0.9 * n), 0.0, 1.0)
			var v := 0.82 + 0.18 * n
			image.set_pixel(x, y, Color(v, v, v, a))
	return ImageTexture.create_from_image(image)


## Fumigène : panache qui part serré d'un point bas de la tribune, monte vite, ralentit, s'élargit
## et dérive avec le vent ; dense et coloré à la source, gris et transparent en haut.
func _creer_fumigene() -> CPUParticles3D:
	if _fumee_texture == null:
		_fumee_texture = _texture_fumee()
	var matiere := StandardMaterial3D.new()
	matiere.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	matiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Billboard simple qui garde l'échelle : les particules inactives (échelle 0) restent invisibles
	# (BILLBOARD_PARTICLES les dessinait en disques noirs à l'émetteur).
	matiere.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	matiere.billboard_keep_scale = true
	matiere.vertex_color_use_as_albedo = true
	matiere.albedo_texture = _fumee_texture
	matiere.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	quad.material = matiere
	var taille := Curve.new()
	taille.max_value = FUMEE_TAILLE_MAX
	taille.add_point(Vector2(0.0, 0.5))
	taille.add_point(Vector2(0.35, 2.4))
	taille.add_point(Vector2(1.0, FUMEE_TAILLE_MAX))
	var fumee := CPUParticles3D.new()
	fumee.name = "Fumigene"
	fumee.mesh = quad
	fumee.amount = FUMEE_PARTICULES
	fumee.lifetime = 8.0
	fumee.emitting = false
	fumee.local_coords = false
	fumee.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fumee.emission_sphere_radius = 0.12
	fumee.direction = Vector3(0, 1, 0)
	fumee.spread = 8.0
	fumee.initial_velocity_min = 4.2
	fumee.initial_velocity_max = 5.4
	# Freinage : la colonne monte vite puis s'étale ; le vent la couche peu à peu.
	fumee.damping_min = 0.55
	fumee.damping_max = 0.75
	fumee.gravity = Vector3(1.1, 0.05, 0.3)
	fumee.tangential_accel_min = -0.4
	fumee.tangential_accel_max = 0.4
	fumee.angle_min = 0.0
	fumee.angle_max = 360.0
	fumee.angular_velocity_min = -25.0
	fumee.angular_velocity_max = 25.0
	fumee.scale_amount_min = 0.8
	fumee.scale_amount_max = 1.2
	fumee.scale_amount_curve = taille
	fumee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fumee)
	return fumee


# --- Pluie ----------------------------------------------------------------------------------
# Deux nappes de gouttes suivent la caméra : une proche (traits courts, nombreux, nets) et une
# lointaine entre la caméra et le jeu. Traits tournés vers la caméra (billboard qui garde
# l'échelle) : visibles aussi sous la caméra action, presque verticale, où des traits « debout »
# (BILLBOARD_FIXED_Y) étaient vus par la tranche. Forte pluie (niveau 2) : plus de gouttes, plus
# longues, plus opaques et penchées par le vent ; de jour, ciel couvert et ombres adoucies.

func _regler_pluie(niveau: int) -> void:
	_niveau_pluie = niveau
	if _mesure:
		print("[ambiance] pluie niveau %d" % niveau)
	for nappe in _pluies:
		if is_instance_valid(nappe):
			nappe.queue_free()
	_pluies.clear()
	if niveau <= 0:
		return
	var forte := niveau >= 2
	_pluies.append(_creer_nappe("PluieProche", PLUIE_PROCHE[niveau], Vector2(0.016, 0.9 if forte else 0.7), 0.5 if forte else 0.38, Vector3(6.0, 5.0, 6.0), forte))
	_pluies.append(_creer_nappe("PluieLointaine", PLUIE_LOINTAINE[niveau], Vector2(0.045, 1.8 if forte else 1.4), 0.55 if forte else 0.4, Vector3(22.0, 11.0, 22.0), forte))


func _creer_nappe(nom: String, nombre: int, taille: Vector2, opacite: float, etendue: Vector3, forte: bool) -> GPUParticles3D:
	var goutte := QuadMesh.new()
	goutte.size = taille
	var matiere := StandardMaterial3D.new()
	matiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	matiere.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	matiere.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	matiere.billboard_keep_scale = true
	matiere.albedo_color = Color(0.86, 0.9, 0.97, opacite)
	matiere.cull_mode = BaseMaterial3D.CULL_DISABLED
	goutte.material = matiere
	var processus := ParticleProcessMaterial.new()
	processus.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	processus.emission_box_extents = etendue
	processus.direction = Vector3(0.3 if forte else 0.1, -1.0, 0.0)
	processus.spread = 4.0
	processus.initial_velocity_min = 12.0 if forte else 9.0
	processus.initial_velocity_max = 15.0 if forte else 11.0
	processus.gravity = Vector3(0, -6.0, 0)
	var nappe := GPUParticles3D.new()
	nappe.name = nom
	nappe.amount = nombre
	nappe.lifetime = etendue.y * 2.0 / 11.0
	nappe.preprocess = nappe.lifetime
	nappe.local_coords = false
	nappe.process_material = processus
	nappe.draw_pass_1 = goutte
	nappe.visibility_aabb = AABB(-etendue * 2.0, etendue * 4.0)
	nappe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(nappe)
	return nappe


func _suivre_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _pluies.size() < 2:
		return
	var avant := -camera.global_transform.basis.z.normalized()
	_pluies[0].global_position = camera.global_position + avant * PLUIE_PROCHE_DISTANCE
	_pluies[1].global_position = camera.global_position + avant * PLUIE_LOINTAINE_DISTANCE


## Ciel couvert et ombres adoucies de jour sous la pluie ; tout est rendu tel quel sans pluie ou le soir
## (le stade du soir a son propre éclairage). Valeurs de départ relues si un autre module les change.
func _regler_ciel() -> void:
	var soleil := _vue.get("_sun") as DirectionalLight3D
	if soleil == null:
		return
	var couvert := _niveau_pluie > 0 and not bool(_vue.get("_stadium_evening"))
	if couvert:
		if not is_equal_approx(soleil.light_energy, _soleil_pose):
			_soleil_base = soleil.light_energy
			_ombre_base = soleil.shadow_opacity
		_soleil_pose = _soleil_base * (SOLEIL_FORTE_PLUIE if _niveau_pluie >= 2 else SOLEIL_CRACHIN)
		soleil.light_energy = _soleil_pose
		soleil.shadow_opacity = OMBRE_PLUIE
	elif _soleil_pose >= 0.0:
		if is_equal_approx(soleil.light_energy, _soleil_pose):
			soleil.light_energy = _soleil_base
			soleil.shadow_opacity = _ombre_base
		_soleil_pose = -1.0
	var ciel := _ciel_procedural()
	if ciel == null:
		return
	if couvert and _ciel_origine.is_empty():
		_ciel_origine = [ciel.sky_top_color, ciel.sky_horizon_color]
		ciel.sky_top_color = CIEL_COUVERT_HAUT
		ciel.sky_horizon_color = CIEL_COUVERT_HORIZON
	elif not couvert and not _ciel_origine.is_empty():
		ciel.sky_top_color = _ciel_origine[0]
		ciel.sky_horizon_color = _ciel_origine[1]
		_ciel_origine = []


func _ciel_procedural() -> ProceduralSkyMaterial:
	for enfant in _vue.get_children():
		if enfant is WorldEnvironment:
			var env := (enfant as WorldEnvironment).environment
			if env and env.sky and env.sky.sky_material is ProceduralSkyMaterial:
				return env.sky.sky_material as ProceduralSkyMaterial
	return null


# --- Mesure (CD_AMBIANCE_MESURE=1) ----------------------------------------------------------

func _compter() -> void:
	var maintenant := Time.get_ticks_usec()
	_images += 1
	if _vue and bool(_vue.get("foule").etat().get("essai", false)):
		_images_essai += 1
		_duree_essai_us += maintenant - _dernier_us
	_dernier_us = maintenant
	if _images % 600 == 0:
		_journal()


func _exit_tree() -> void:
	if _mesure:
		_journal()


func _journal() -> void:
	var total_s := maxf(0.001, (Time.get_ticks_usec() - _debut_us) / 1e6)
	var essai_s := maxf(0.001, _duree_essai_us / 1e6)
	print("[ambiance] %s images/s %.1f (essai %.1f sur %d images)" % ["actif" if actif else "aucune", _images / total_s, _images_essai / essai_s, _images_essai])
