extends SceneTree
## Rendu moderne du match (match_rendu.gd), vérifié en --headless.
## 1. Sous gl_compatibility (méthode réelle ici) : rien n'est installé ni modifié,
##    même avec CD_MATCH_RENDU=moderne, à tous les niveaux, jour et soir.
## 2. Méthode Forward+ simulée : les réglages de chaque niveau s'appliquent, sont
##    réversibles d'un niveau à l'autre et suivent la caméra ; CD_MATCH_RENDU=actuel
##    coupe tout ; CD_MATCH_RENDU_TONEMAP=filmique change la courbe et l'étalonnage.

const View = preload("res://match_view.gd")
const Rendu = preload("res://match_rendu.gd")
const SURFACE := "res://shaders/stadium_surface.gdshader"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func fixture() -> Dictionary:
	var players: Array[Dictionary] = []
	for side in 2:
		for slot in 15:
			players.append({"id": "%d-%d" % [side, slot], "side": side, "slot": slot, "featured": side == 0 and slot == 0,
				"x": 34.0 + side * 21.0 + (slot % 3) * 2.5, "y": 7.0 + slot * 4.0})
	return {"paused": true, "scene": {"kind": "carry", "possession": 0, "players": players, "ball": {"x": 51.0, "y": 35.0}},
		"teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}]}


func build(quality: String, evening: bool) -> Array:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(viewport)
	var view: NativeMatchView = View.new()
	view.set_quality(quality)
	view.set_stadium_evening(evening)
	viewport.add_child(view)
	view.set_process(false)
	view.apply_frame(fixture())
	view._process(1.0)
	return [viewport, view]


func release(pair: Array) -> void:
	root.remove_child(pair[0])
	pair[0].free()


func day_environment(view: NativeMatchView) -> Environment:
	if is_instance_valid(view._stadium_kit):
		return view._stadium_kit._day
	return (view.find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment).environment


func spectators_srgb(view: NativeMatchView) -> bool:
	for child: Node in view.get_children():
		if str(child.name).begins_with("Spectators"):
			return ((child as MultiMeshInstance3D).material_override as StandardMaterial3D).vertex_color_is_srgb
	return false


func contact_shadows(view: NativeMatchView) -> int:
	var count := 0
	for entry: Dictionary in view._actors.values():
		if (entry.node as Node3D).get_node_or_null("ContactShadow"):
			count += 1
	return count


## Sous gl_compatibility : état strictement identique à l'avant-projet.
func check_untouched(label: String) -> void:
	for quality in ["economy", "balanced", "detail"]:
		for evening in [false, true]:
			var pair := build(quality, evening)
			var viewport: SubViewport = pair[0]
			var view: NativeMatchView = pair[1]
			var tag := "%s %s %s" % [label, quality, "soir" if evening else "jour"]
			var day := day_environment(view)
			check(view._rendu == null, tag + " : rendu moderne absent")
			check(viewport.msaa_3d == Viewport.MSAA_2X, tag + " : MSAA du jeu inchangé")
			check(day.tonemap_mode == Environment.TONE_MAPPER_LINEAR and is_equal_approx(day.tonemap_exposure, 1.0), tag + " : courbe d'origine")
			check(day.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and is_equal_approx(day.ambient_light_energy, 0.43), tag + " : ambiance d'origine")
			check(not day.ssao_enabled and not day.ssil_enabled and not day.glow_enabled and not day.fog_enabled, tag + " : aucun effet d'image")
			check(is_equal_approx(view._sun.light_energy, 0.10 if evening else 0.92), tag + " : énergie du soleil d'origine")
			check(view._sun.shadow_enabled == (quality != "economy"), tag + " : ombres du soleil d'origine")
			check(view._sun.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY and is_zero_approx(view._sun.light_angular_distance), tag + " : soleil d'origine")
			check(is_equal_approx(view._sun.directional_shadow_split_1, 0.1) and is_equal_approx(view._sun.directional_shadow_split_3, 0.5), tag + " : cascades d'origine")
			check(is_equal_approx(view._camera.far, 500.0), tag + " : plan lointain d'origine")
			check(view._grass.shader.resource_path == SURFACE, tag + " : pelouse d'origine")
			check(contact_shadows(view) == 0, tag + " : aucune ombre de contact")
			check(not spectators_srgb(view), tag + " : couleurs du public d'origine")
			var layers_ok := true
			for mesh: MeshInstance3D in view._ground_meshes:
				layers_ok = layers_ok and mesh.layers == 1
			check(view._ground_meshes.size() > 40 and layers_ok, tag + " : calques du sol d'origine")
			if evening:
				var evening_env: Environment = view._stadium_kit._evening
				check(evening_env.tonemap_mode == Environment.TONE_MAPPER_LINEAR and is_equal_approx(evening_env.ambient_light_energy, 0.38), tag + " : soir d'origine")
				for spot: SpotLight3D in view._stadium_kit.get_node("Floodlights").get_children():
					check(not spot.shadow_enabled and is_equal_approx(spot.light_energy, 2.25), tag + " : projecteur d'origine")
			release(pair)


func check_modern() -> Dictionary:
	var metrics := {}
	var pair := build("balanced", false)
	var viewport: SubViewport = pair[0]
	var view: NativeMatchView = pair[1]
	check(view._rendu != null, "Forward+ simulé : rendu moderne installé")
	if view._rendu == null:
		release(pair)
		return metrics
	check(is_equal_approx(view._camera.far, Rendu.PLAN_LOINTAIN), "plan lointain resserré")
	check(spectators_srgb(view), "couleurs du public lues en sRGB")
	check(contact_shadows(view) == 30, "une ombre de contact par joueur")
	var sol := true
	for mesh: MeshInstance3D in view._ground_meshes:
		sol = sol and (mesh.layers & Rendu.CALQUE_SOL) != 0 and (mesh.layers & 1) != 0
	check(sol, "sol sur le calque des ombres de contact")
	var origin_sun := 0.92
	# Trois passages pour vérifier qu'aucune valeur ne s'accumule.
	for round in 3:
		for quality in ["economy", "balanced", "detail"]:
			view.set_quality(quality)
			var r := Rendu.reglages(quality)
			var day := day_environment(view)
			var tag := "%s (passage %d)" % [r.niveau, round]
			check(view._rendu.niveau() == r.niveau, tag + " : niveau")
			check(viewport.msaa_3d == (Viewport.MSAA_2X if r.msaa < 0 else r.msaa), tag + " : MSAA")
			check(view._sun.shadow_enabled == r.ombres_soleil, tag + " : ombres du soleil")
			check(is_equal_approx(view._sun.light_angular_distance, r.penombre_deg), tag + " : pénombre")
			check(view._sun.directional_shadow_blend_splits == r.fondu_cascades, tag + " : fondu des cascades")
			check(is_equal_approx(view._sun.light_energy, origin_sun * Rendu.ETALONNAGE.lineaire.soleil), tag + " : soleil étalonné, sans cumul")
			check(view._sun.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY, tag + " : soleil hors du ciel ambiant")
			check(day.ssao_enabled == r.ssao, tag + " : occlusion")
			check(day.tonemap_mode == Environment.TONE_MAPPER_LINEAR, tag + " : courbe linéaire par défaut")
			check(day.ambient_light_source == Environment.AMBIENT_SOURCE_SKY and is_equal_approx(day.ambient_light_energy, Rendu.ETALONNAGE.lineaire.ambiance_jour), tag + " : ambiance du ciel")
			check(not day.glow_enabled and not day.fog_enabled and not day.ssil_enabled, tag + " : ni halo, ni brouillard, ni SSIL")
			check(view._grass.shader.resource_path == Rendu.SURFACE_MODERNE and is_equal_approx(float(view._grass.get_shader_parameter("relief")), r.relief_pelouse), tag + " : pelouse moderne")
			check(is_equal_approx(float(view._grass.get_shader_parameter("micro_detail")), {"economy": 0.0, "balanced": 0.1, "detail": 0.16}[quality]), tag + " : grain de la pelouse conservé")
			var visible := true
			for entry: Dictionary in view._actors.values():
				visible = visible and (entry.node as Node3D).get_node("ContactShadow").visible == r.ombres_contact
			check(visible, tag + " : ombres de contact")
	# Cascades : fin de chaque cascade à la distance prévue pour chaque caméra.
	for camera in ["tv", "action", "tactical"]:
		view.set_camera(camera)
		var ends: Array = Rendu.CASCADES[camera]
		var span: float = view._camera.far - view._camera.near
		var first: float = view._camera.near + view._sun.directional_shadow_split_1 * span
		var last: float = view._camera.near + view._sun.directional_shadow_split_3 * span
		check(absf(first - ends[0]) < 0.01 and absf(last - ends[2]) < 0.01, camera + " : cascades réglées")
		metrics[camera] = [snappedf(first, 0.1), snappedf(last, 0.1)]
	view.set_camera("tv")
	# Soir : ambiance couleur, projecteurs étalonnés sans cumul, ombres en élevé.
	for round in 2:
		for quality in ["economy", "detail", "balanced"]:
			view.set_quality(quality)
			view.set_stadium_evening(true)
			var r := Rendu.reglages(quality)
			var evening_env: Environment = view._stadium_kit._evening
			check(evening_env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and is_equal_approx(evening_env.ambient_light_energy, Rendu.ETALONNAGE.lineaire.ambiance_soir), "soir %s : ambiance" % quality)
			check(evening_env.ssao_enabled == r.ssao, "soir %s : occlusion" % quality)
			check(is_equal_approx(view._sun.light_energy, 0.10), "soir %s : lune du kit intacte" % quality)
			for spot: SpotLight3D in view._stadium_kit.get_node("Floodlights").get_children():
				check(spot.shadow_enabled == r.ombres_projecteurs and is_equal_approx(spot.light_energy, 2.25 * Rendu.ETALONNAGE.lineaire.projecteurs), "soir %s : projecteur" % quality)
			check(viewport.positional_shadow_atlas_size >= (4096 if r.ombres_projecteurs else 0), "soir %s : atlas des projecteurs" % quality)
			view.set_stadium_evening(false)
			check(is_equal_approx(view._sun.light_energy, origin_sun * Rendu.ETALONNAGE.lineaire.soleil), "retour au jour %s : soleil" % quality)
	release(pair)
	# Courbe filmique en option.
	OS.set_environment("CD_MATCH_RENDU_TONEMAP", "filmique")
	pair = build("balanced", false)
	view = pair[1]
	var filmic := day_environment(view)
	check(filmic.tonemap_mode == Environment.TONE_MAPPER_FILMIC and is_equal_approx(filmic.tonemap_exposure, Rendu.ETALONNAGE.filmique.exposition_jour), "option filmique : courbe et exposition")
	check(is_equal_approx(view._sun.light_energy, 0.92), "option filmique : soleil d'origine")
	release(pair)
	OS.unset_environment("CD_MATCH_RENDU_TONEMAP")
	# CD_MATCH_RENDU=actuel coupe le rendu moderne même sous Forward+.
	OS.set_environment("CD_MATCH_RENDU", "actuel")
	check(not Rendu.actif(), "CD_MATCH_RENDU=actuel : rendu moderne coupé")
	OS.unset_environment("CD_MATCH_RENDU")
	return metrics


func run() -> void:
	var method := RenderingServer.get_current_rendering_method()
	check(method == "gl_compatibility", "méthode réelle gl_compatibility en --headless")
	check(not Rendu.actif(), "rendu moderne inactif sous gl_compatibility")
	check_untouched("compat")
	OS.set_environment("CD_MATCH_RENDU", "moderne")
	check(not Rendu.actif(), "CD_MATCH_RENDU=moderne ne force rien sous gl_compatibility")
	check_untouched("compat+variable")
	OS.unset_environment("CD_MATCH_RENDU")
	Rendu.methode_simulee = "forward_plus"
	var metrics := check_modern()
	Rendu.methode_simulee = ""
	print("MATCH_RENDU_CHECKS ", JSON.stringify({"checks": checks, "failures": failures, "method": method, "cascades_m": metrics}))
	quit(0 if failures.is_empty() else 1)
