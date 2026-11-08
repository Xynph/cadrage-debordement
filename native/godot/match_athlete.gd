extends RefCounted
## Maillage de présentation commun ; skinning et clips source conservés.
## UV/UV2 encodent la position originale et la région ; aucune position animée
## ni décision sportive ne sert à la couleur des tenues.

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _shader: Shader
const SHADER_PATH := "res://shaders/athlete_kit.gdshader"
const SKINS := ["d3b192", "bd8e6e", "af7958", "916043", "74472e", "513326"]
const HAIR := ["241f1c", "241f1c", "3b2a20", "3b2a20", "59432e", "766044", "67402c", "9b9688"]

static func prepare(model: Node3D) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh.resource_name == "AthleteRugbyOriginal":
			continue
		var key := str(instance.mesh.get_instance_id())
		if not _meshes.has(key):
			_meshes[key] = build_mesh(instance.mesh, instance.skin)
		instance.mesh = _meshes[key]

static func clear_palette() -> void:
	_materials.clear()

static func stable_identity(id: String) -> int:
	var value: int = 2166136261
	for byte in id.to_utf8_buffer():
		value = ((value ^ int(byte)) * 16777619) & 0x7fffffff
	return value

static func appearance(id: String) -> Dictionary:
	var value := stable_identity(id)
	return {"skin": Color(SKINS[value % SKINS.size()]), "hair": Color(HAIR[(value / SKINS.size()) % HAIR.size()])}

static func dress(model: Node3D, kit: Dictionary, id: String) -> void:
	var look := appearance(id)
	var key := (kit.shirt as Color).to_html() + (kit.detail as Color).to_html() + (kit.get("shorts", Color("202b35")) as Color).to_html() + (look.skin as Color).to_html() + (look.hair as Color).to_html()
	if not _materials.has(key):
		if not _shader:
			_shader = load(SHADER_PATH) as Shader
		var material := ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter("jersey_color", kit.shirt)
		material.set_shader_parameter("panel_color", (kit.shirt as Color).darkened(0.16))
		material.set_shader_parameter("trim_color", kit.detail)
		material.set_shader_parameter("shorts_color", kit.get("shorts", Color("202b35")))
		material.set_shader_parameter("socks_color", kit.shirt)
		material.set_shader_parameter("skin_color", look.skin)
		material.set_shader_parameter("hair_color", look.hair)
		_materials[key] = material
	for node in model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = _materials[key]

static func _closest(a: Vector3, b: Vector3, p: Vector3) -> Vector3:
	var delta := b - a
	return a + delta * clampf((p - a).dot(delta) / maxf(delta.length_squared(), 0.0000000001), 0.0, 1.0)

static func _morph(p: Vector3, part: int, binds: Dictionary) -> Vector3:
	if part in [4, 5, 6, 7, 8]:
		return p
	if part == 3:
		# Section de jambe seulement : hauteur au repos et longueurs inchangées.
		var side := "L" if p.x >= 0.0 else "R"
		var hip: Vector3 = binds["UpperLeg." + side]
		var knee: Vector3 = binds["LowerLeg." + side]
		var ankle: Vector3 = binds["Foot." + side]
		var center := _closest(hip, knee, p) if p.z > knee.z else _closest(knee, ankle, p)
		var radial := p - center
		radial.z = 0.0
		var ankle_fade := smoothstep(0.00207, 0.0069, p.z)
		var thigh := smoothstep(0.0128, 0.0170, p.z)
		var section := p + radial * ankle_fade * (0.23 + 0.14 * thigh)
		var waist := Vector3(p.x * 1.14, (p.y - 0.00025) * 1.12 + 0.00025, p.z)
		return section.lerp(waist, smoothstep(0.0210, 0.0240, p.z))
	# Un torse plus large/profond, sans toucher au cou, à la tête ni au rig.
	var chest := smoothstep(0.0270, 0.0360, p.z)
	var neck := 1.0 - smoothstep(0.0390, 0.0425, p.z)
	var width := 1.0 + (0.14 + 0.13 * chest) * neck
	var depth := 1.0 + (0.12 + 0.06 * chest) * neck
	var torso := Vector3(p.x * width, (p.y - 0.00025) * depth + 0.00025, p.z)
	if absf(p.x) <= 0.0045 or p.z >= 0.0415:
		return torso
	var side := "L" if p.x >= 0.0 else "R"
	var upper: Vector3 = binds["UpperArm." + side]
	var elbow: Vector3 = binds["LowerArm." + side]
	var wrist: Vector3 = binds["Palm." + side]
	var center := _closest(upper, elbow, p) if absf(p.x) < absf(elbow.x) else _closest(elbow, wrist, p)
	var forearm := smoothstep(absf(elbow.x), absf(wrist.x), absf(p.x))
	var radial_scale := lerpf(0.29, 0.0, forearm)
	var arm := p + (p - center) * radial_scale
	return torso.lerp(arm, smoothstep(0.0045, 0.0065, absf(p.x)))

static func _normal(p: Vector3, normal: Vector3, part: int, binds: Dictionary) -> Vector3:
	# Jacobienne de la déformation ; conserve les normales facettées d'origine.
	var step := 0.000001
	var dx := (_morph(p + Vector3(step, 0, 0), part, binds) - _morph(p - Vector3(step, 0, 0), part, binds)) / (2.0 * step)
	var dy := (_morph(p + Vector3(0, step, 0), part, binds) - _morph(p - Vector3(0, step, 0), part, binds)) / (2.0 * step)
	var dz := (_morph(p + Vector3(0, 0, step), part, binds) - _morph(p - Vector3(0, 0, step), part, binds)) / (2.0 * step)
	return (Basis(dx, dy, dz).inverse().transposed() * normal).normalized()

static func build_mesh(source: Mesh, skin: Skin) -> ArrayMesh:
	var binds: Dictionary = {}
	for i in skin.get_bind_count():
		binds[str(skin.get_bind_name(i))] = skin.get_bind_pose(i).affine_inverse().origin
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var rest_uv := PackedVector2Array()
	var rest_uv2 := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var names := ["Shirt2", "Shirt", "Skin", "Pants", "Shoes", "Socks", "Hair2", "Hair", "Eyes"]
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var part := names.find(source.surface_get_material(surface).resource_name)
		assert(part >= 0, "Région inconnue : préparation refusée")
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var offset := vertices.size()
		for index in positions.size():
			var p := positions[index]
			vertices.append(_morph(p, part, binds))
			normals.append(_normal(p, source_normals[index], part, binds))
			rest_uv.append(Vector2(p.z, p.x))
			rest_uv2.append(Vector2(p.y, float(part)))
		for index in arrays[Mesh.ARRAY_INDEX]:
			indices.append(offset + int(index))
		bones.append_array(arrays[Mesh.ARRAY_BONES])
		weights.append_array(arrays[Mesh.ARRAY_WEIGHTS])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = rest_uv
	arrays[Mesh.ARRAY_TEX_UV2] = rest_uv2
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.resource_name = "AthleteRugbyOriginal"
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
