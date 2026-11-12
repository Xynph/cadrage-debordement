extends Node
## Visage de Gabi dans le portrait 3D : regard, clignements, sourire et chaleur du regard.
## Fonctionne avec le Gabi d'origine comme avec le Gabi Mixamo : chaque forme est cherchée par son
## nom, et une forme absente ne fait rien.
##
## - Regard : les yeux sont des maillages à part (Gabi_Oeil_D, Gabi_Oeil_G). S'ils n'ont pas déjà
##   des formes RegardGauche/RegardDroite/RegardHaut/RegardBas, elles sont construites ici, au
##   chargement, en tournant le globe autour de son centre (aucun fichier modifié). Petites saccades
##   autour du joueur ; regard vers le carnet ou la tablette quand il les consulte ; regard de côté
##   quand il réfléchit.
## - Clignements : forme « Clignement » (si le modèle la fournit), toutes les 3 à 6 s, plus rares
##   pendant l'écoute attentive (question posée au coach), parfois doublés.
## - Sourire : petites valeurs de MouthWide/MouthPress au repos, de temps en temps, seulement si le
##   ton est neutre ou positif et jamais pendant la parole (la synchronisation labiale garde la main).
##   « SourireYeux » le suit ; « SourcilsDoux » donne un regard chaleureux au repos.

const EYES := [&"Gabi_Oeil_D", &"Gabi_Oeil_G"]
const GAZE_SHAPES := [&"RegardGauche", &"RegardDroite", &"RegardHaut", &"RegardBas"]
## Amplitude des formes de regard construites (degrés) : gauche/droite, haut, bas.
## Haut et bas limités à 5° : au-delà, la cornée (globe ellipsoïdal) traverse la paupière.
const GAZE_ANGLES := Vector3(14.0, 5.0, 5.0)
const BLINK := &"Clignement"
const EYE_SMILE := &"SourireYeux"
const SOFT_BROWS := &"SourcilsDoux"
## Valeurs de repos conseillées pour un regard chaleureux.
const EYE_SMILE_REST := 0.3
const SOFT_BROWS_REST := 0.4
## Sourire au repos, à pleine intensité (calibré sur les formes de bouche de Gabi).
const SMILE_WIDE := 0.75
const SMILE_PRESS := 0.3
const BLINK_TIME := Vector3(0.07, 0.04, 0.13)  # fermeture, tenue, ouverture
## La paupière supérieure suit le regard vers le bas (part de « Clignement » à RegardBas = 1) : sans
## elle, l'iris descend sous une paupière immobile et le blanc apparaît au-dessus (regard fixe).
const LID_FOLLOW := 0.12

var tone := "neutre"
var speaking := false
var attentive := false
## « joueur », « carnet » ou « pensif ».
var look := "joueur"
var gaze := Vector2.ZERO
var gaze_target := Vector2.ZERO
var smile := 0.0
var blink := 0.0
var random := RandomNumberGenerator.new()

var _shapes := {}  # nom → Array de [MeshInstance3D, index]
var _mouth: MeshInstance3D
var _mouth_press := -1
var _mouth_wide := -1
var _saccade_wait := 0.0
var _blink_wait := 0.0
var _blink_phase := -1.0
var _double_blink := false
var _smile_wait := 0.0
var _smile_phase := -1.0
var _smile_peak := 0.0
var _smile_hold := 0.0
var _static := false


func setup(character: Node3D, mouth: MeshInstance3D) -> void:
	name = "GabiVisage"
	random.randomize()
	_mouth = mouth
	if mouth != null:
		_mouth_press = mouth.find_blend_shape_by_name(&"MouthPress")
		_mouth_wide = mouth.find_blend_shape_by_name(&"MouthWide")
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if StringName(mesh.name) in EYES and mesh.find_blend_shape_by_name(GAZE_SHAPES[0]) < 0:
			_build_gaze_shapes(mesh)
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for shape: StringName in GAZE_SHAPES + [BLINK, EYE_SMILE, SOFT_BROWS]:
			var index := mesh.find_blend_shape_by_name(shape)
			if index >= 0:
				if not _shapes.has(shape): _shapes[shape] = []
				_shapes[shape].append([mesh, index])
	_blink_wait = random.randf_range(1.0, 3.0)
	_smile_wait = random.randf_range(2.0, 5.0)
	_apply()


func has_shape(shape: StringName) -> bool:
	return _shapes.has(shape)


## Le globe tourne autour de son centre : quatre formes de regard (vertex, normale, tangente).
func _build_gaze_shapes(instance: MeshInstance3D) -> void:
	var source := instance.mesh as ArrayMesh
	if source == null or source.get_surface_count() == 0 or source.get_blend_shape_count() > 0: return
	var built := ArrayMesh.new()
	built.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	for shape: StringName in GAZE_SHAPES: built.add_blend_shape(shape)
	var center := source.get_aabb().get_center()
	var turns := [Basis(Vector3.UP, deg_to_rad(GAZE_ANGLES.x)), Basis(Vector3.UP, -deg_to_rad(GAZE_ANGLES.x)),
		Basis(Vector3.RIGHT, -deg_to_rad(GAZE_ANGLES.y)), Basis(Vector3.RIGHT, deg_to_rad(GAZE_ANGLES.z))]
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		var shapes := []
		for turn: Basis in turns:
			var shape := []
			shape.resize(Mesh.ARRAY_MAX)
			var moved := PackedVector3Array()
			moved.resize(vertices.size())
			for i in vertices.size(): moved[i] = center + turn * (vertices[i] - center)
			shape[Mesh.ARRAY_VERTEX] = moved
			if not normals.is_empty():
				var turned := PackedVector3Array()
				turned.resize(normals.size())
				for i in normals.size(): turned[i] = turn * normals[i]
				shape[Mesh.ARRAY_NORMAL] = turned
			if not tangents.is_empty():
				var rotated := tangents.duplicate()
				for i in tangents.size() / 4:
					var t := turn * Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2])
					rotated[i * 4] = t.x; rotated[i * 4 + 1] = t.y; rotated[i * 4 + 2] = t.z
				shape[Mesh.ARRAY_TANGENT] = rotated
			shapes.append(shape)
		var flags := source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		built.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, shapes, {}, flags)
		built.surface_set_material(surface, source.surface_get_material(surface))
	built.resource_name = source.resource_name
	instance.mesh = built


## Mouvement réduit ou guide masqué : visage posé, regard droit, sans clignement ni sourire.
func set_static(value: bool) -> void:
	_static = value
	set_process(not value)
	if value:
		gaze = Vector2.ZERO; gaze_target = Vector2.ZERO; blink = 0.0; smile = 0.0
		_blink_phase = -1.0; _smile_phase = -1.0
	_apply()


func set_tone(value: String) -> void:
	tone = value
	if tone == "negatif":
		_smile_phase = -1.0
		smile = 0.0
	_apply()


func set_speaking(value: bool) -> void:
	speaking = value
	# La parole reprend la bouche aussitôt ; le sourire repartira de zéro.
	if value:
		smile = 0.0
		_smile_phase = -1.0
	_saccade_wait = minf(_saccade_wait, 0.4)


## Sourire franc tout de suite (bonne nouvelle, approbation), si le ton le permet.
func smile_now(strength := 1.0) -> void:
	if _static or tone == "negatif" or speaking: return
	_smile_peak = clampf(strength, 0.0, 1.0)
	_smile_hold = random.randf_range(2.0, 3.5)
	_smile_phase = 0.0


## Direction du regard selon le geste joué.
func follow_gesture(clip: StringName, carnet: Array, pensive: Array) -> void:
	var previous := look
	look = "carnet" if clip in carnet else ("pensif" if clip in pensive else "joueur")
	if look != previous:
		_saccade_wait = 0.0
		if look != "joueur" and random.randf() < 0.5 and _blink_phase < 0.0: _blink_phase = 0.0


func _process(delta: float) -> void:
	if _static: return
	_update_gaze(delta)
	_update_blink(delta)
	_update_smile(delta)
	_apply()


func _update_gaze(delta: float) -> void:
	_saccade_wait -= delta
	if _saccade_wait <= 0.0:
		match look:
			"carnet":
				gaze_target = Vector2(random.randf_range(0.15, 0.35), random.randf_range(-1.0, -0.8))
				_saccade_wait = random.randf_range(0.5, 1.2)
			"pensif":
				gaze_target = Vector2(random.randf_range(-0.6, -0.4), random.randf_range(0.25, 0.5))
				_saccade_wait = random.randf_range(0.8, 1.6)
			_:
				# Petites saccades autour du visage du joueur ; parfois exactement dans les yeux.
				var low := -0.25 if tone == "negatif" else 0.0
				gaze_target = Vector2.ZERO if random.randf() < 0.3 else Vector2(random.randf_range(-0.22, 0.22), random.randf_range(-0.15, 0.12) + low)
				_saccade_wait = random.randf_range(1.2, 3.0) if speaking else random.randf_range(0.7, 2.6)
	# Saccade : mouvement très rapide (≈ 0,1 s), puis fixation.
	gaze = gaze.lerp(gaze_target, 1.0 - exp(-28.0 * delta))


func _update_blink(delta: float) -> void:
	if _blink_phase < 0.0:
		_blink_wait -= delta
		if _blink_wait > 0.0: return
		_blink_phase = 0.0
		_double_blink = random.randf() < 0.15
	_blink_phase += delta
	var close := BLINK_TIME.x
	var hold := close + BLINK_TIME.y
	var end := hold + BLINK_TIME.z
	if _blink_phase < close: blink = _blink_phase / close
	elif _blink_phase < hold: blink = 1.0
	elif _blink_phase < end: blink = 1.0 - (_blink_phase - hold) / BLINK_TIME.z
	else:
		blink = 0.0
		if _double_blink:
			# Courte pause, puis second clignement.
			_double_blink = false
			_blink_phase = -1.0
			_blink_wait = 0.12
			return
		_blink_phase = -1.0
		_blink_wait = random.randf_range(5.0, 9.0) if attentive else random.randf_range(3.0, 6.0)


func _update_smile(delta: float) -> void:
	if tone == "negatif" or speaking:
		smile = move_toward(smile, 0.0, delta * 4.0)
		return
	if _smile_phase < 0.0:
		_smile_wait -= delta
		if _smile_wait > 0.0: return
		_smile_phase = 0.0
		_smile_peak = random.randf_range(0.6, 1.0) if tone == "positif" else random.randf_range(0.4, 0.75)
		_smile_hold = random.randf_range(1.5, 3.5)
	_smile_phase += delta
	var rise := 0.5
	var fall := 0.8
	if _smile_phase < rise: smile = _smile_peak * smoothstep(0.0, 1.0, _smile_phase / rise)
	elif _smile_phase < rise + _smile_hold: smile = _smile_peak
	elif _smile_phase < rise + _smile_hold + fall: smile = _smile_peak * (1.0 - smoothstep(0.0, 1.0, (_smile_phase - rise - _smile_hold) / fall))
	else:
		smile = 0.0
		_smile_phase = -1.0
		_smile_wait = random.randf_range(3.0, 8.0) if tone == "positif" else random.randf_range(6.0, 13.0)


## Bouche au repos (hors parole) : valeurs MouthPress et MouthWide du sourire.
func mouth_rest() -> Vector2:
	return Vector2(SMILE_PRESS, SMILE_WIDE) * smile if not speaking and not _static else Vector2.ZERO


func _apply() -> void:
	_weight(&"RegardGauche", maxf(gaze.x, 0.0))
	_weight(&"RegardDroite", maxf(-gaze.x, 0.0))
	_weight(&"RegardHaut", maxf(gaze.y, 0.0))
	_weight(&"RegardBas", maxf(-gaze.y, 0.0))
	_weight(BLINK, maxf(blink, LID_FOLLOW * maxf(-gaze.y, 0.0)))
	var warm := 0.0 if tone == "negatif" else EYE_SMILE_REST
	_weight(EYE_SMILE, clampf(warm + 0.35 * smile, 0.0, 1.0))
	_weight(SOFT_BROWS, SOFT_BROWS_REST)
	if _mouth != null and not speaking:
		var rest := mouth_rest()
		if _mouth_press >= 0: _mouth.set_blend_shape_value(_mouth_press, rest.x)
		if _mouth_wide >= 0: _mouth.set_blend_shape_value(_mouth_wide, rest.y)


func shape_value(shape: StringName) -> float:
	if not _shapes.has(shape): return 0.0
	var entry: Array = _shapes[shape][0]
	return (entry[0] as MeshInstance3D).get_blend_shape_value(entry[1])


func _weight(shape: StringName, weight: float) -> void:
	for entry: Array in _shapes.get(shape, []):
		(entry[0] as MeshInstance3D).set_blend_shape_value(entry[1], weight)
