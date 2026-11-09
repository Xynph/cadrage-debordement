extends Node3D
## Kit de présentation autonome pour le stade générique du MatchView.

var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _day: Environment
var _evening: Environment
var _day_energy: float


func attach(view: NativeMatchView) -> void:
	if get_parent() == view:
		return
	for child: Node in view.get_children():
		if child is WorldEnvironment:
			_world_environment = child
			break
	_sun = view._sun
	_day = _world_environment.environment
	_day_energy = _sun.light_energy
	_evening = _day.duplicate() as Environment
	_evening.background_mode = Environment.BG_COLOR
	_evening.background_color = Color("101a32")
	_evening.ambient_light_color = Color("a9bddf")
	_evening.ambient_light_energy = 0.38
	_build_modules()
	name = "StadiumEvening"
	visible = false
	view.add_child(self)


func set_evening(enabled: bool) -> void:
	_world_environment.environment = _evening if enabled else _day
	_sun.light_energy = 0.10 if enabled else _day_energy
	visible = enabled


func _build_modules() -> void:
	var metal: Array[Transform3D] = []
	var bright: Array[Transform3D] = []
	var floodlights := Node3D.new()
	floodlights.name = "Floodlights"
	add_child(floodlights)
	for x in [-62.0, 62.0]:
		for z in [-43.5, 43.5]:
			var side := signf(z)
			# Les luminaires utilisent les quatre mâts du stade existant.
			for lamp in 5:
				var lens := Vector3(x - 1.4 + lamp * 0.7, 18.03, z - side * 0.27)
				bright.append(_box(lens, Vector3(0.50, 0.62, 0.04)))
			var light := SpotLight3D.new()
			floodlights.add_child(light)
			var origin := Vector3(x, 18.0, z - side * 0.3)
			var aim := Vector3(x * 0.18, 0.0, z * 0.12)
			light.transform = Transform3D(Basis.looking_at(aim - origin), origin)
			light.light_color = Color("dceaff")
			light.light_energy = 2.25
			light.spot_range = 142.0
			light.spot_angle = 62.0
			light.spot_attenuation = 0.70
			light.spot_angle_attenuation = 0.65
			light.shadow_enabled = false
	for side in [-1.0, 1.0]:
		# Liserés discrets sur les panneaux, assise et fascia sous les abris.
		for panel in 8:
			bright.append(_box(Vector3(-56.0 + panel * 16.0, 1.15, side * 41.04),
				Vector3(14.7, 0.035, 0.04)))
		var x: float = side * 18.0
		metal.append(_box(Vector3(x, 0.52, 43.5), Vector3(10.5, 0.16, 0.48)))
		metal.append(_box(Vector3(x, 0.27, 43.5), Vector3(10.5, 0.38, 0.11)))
		bright.append(_box(Vector3(x, 2.10, 42.08), Vector3(10.7, 0.09, 0.035)))
	_batch("BenchModules", metal, Color("28465f"), false)
	_batch("LightModules", bright, Color("b9def7"), true)


func _box(position: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), position)


func _batch(label: String, transforms: Array[Transform3D], color: Color, unshaded: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for index in transforms.size():
		batch.set_instance_transform(index, transforms[index])
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = batch
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
