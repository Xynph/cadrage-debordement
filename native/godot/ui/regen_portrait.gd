extends RefCounted
## Éléments IA prégénérés + composition locale ; aucune inférence d'IA.
const VERSION := 1
const MAX_TEXTURES := 48
const MAX_MATERIALS := 128
static var _textures: Dictionary = {}
static var _materials: Dictionary = {}
static var _shader: Shader
const SHADER := """
shader_type canvas_item;
uniform float face_width = 1.0;
uniform float eye_spacing = 0.0;
uniform float nose_width = 0.0;
uniform float jaw_width = 0.0;
uniform float zoom = 1.0;
uniform vec2 crop = vec2(0.0);
uniform float saturation = 1.0;
uniform float exposure = 1.0;
uniform float shirt = 0.0;
uniform bool mirrored = false;
uniform float maturity = 0.0;
void fragment() {
 vec2 p = (UV - vec2(0.5)) / zoom + vec2(0.5) + crop;
 if (mirrored) { p.x = 1.0 - p.x; }
 // Smooth, bounded horizontal warps preserve eyes, nose and jaw continuity.
 float face = smoothstep(0.04,0.20,p.y) * (1.0-smoothstep(0.71,0.84,p.y));
 float eyes = exp(-pow((p.y-0.36)/0.085,2.0));
 float nose = exp(-pow((p.y-0.49)/0.09,2.0));
 float jaw = exp(-pow((p.y-0.68)/0.10,2.0));
 p.x = 0.5 + (p.x-0.5) * (1.0 + (face_width-1.0)*face + nose_width*nose + jaw_width*jaw);
 p.x += eye_spacing * eyes * sin((p.x-0.5)*8.0);
 vec4 color = texture(TEXTURE,clamp(p,vec2(0.001),vec2(0.999)));
 float luminance = dot(color.rgb,vec3(0.2126,0.7152,0.0722));
 color.rgb = mix(vec3(luminance),color.rgb,saturation) * exposure;
 // Recolour only the lower shirt, not skin or facial features.
 float cloth = smoothstep(0.83,0.94,p.y);
 vec3 cloth_tint = mix(vec3(0.72,0.92,1.03),vec3(1.03,0.86,0.72),shirt);
 color.rgb *= mix(vec3(1.0),cloth_tint,cloth*0.35);
 // Tiny age-dependent texture variation; not a promise of photoreal ageing.
 float wrinkle = sin(p.y*240.0) * 0.012 * maturity;
 float forehead = exp(-pow((p.y-0.24)/0.055,2.0)) * (1.0-smoothstep(0.19,0.35,abs(p.x-0.5)));
 color.rgb += vec3(wrinkle * forehead);
 // Silver only neutral dark hair-like pixels inside the crown/beard zones;
 // warm skin-coloured pixels are excluded, and the effect remains restrained.
 float warm = smoothstep(1.12,1.28,color.r/max(color.g,0.015));
 float neutral_dark = (1.0-warm) * (1.0-smoothstep(0.18,0.33,luminance));
 float crown = 1.0-smoothstep(0.09,0.17,p.y);
 float beard = smoothstep(0.61,0.66,p.y)*(1.0-smoothstep(0.76,0.81,p.y))*(1.0-smoothstep(0.19,0.27,abs(p.x-0.5)));
 float silver = neutral_dark * max(crown,beard) * maturity * 0.22;
 color.rgb = mix(color.rgb,vec3(0.48,0.49,0.47),silver);
 COLOR = clamp(color,0.0,1.0);
}
"""

static func _key(value: Variant) -> String:
	return value if value is String and not value.is_empty() and value.length() <= 256 else ""
static func _age(value: Variant) -> int:
	return int(value) if (value is int or value is float) and is_finite(float(value)) and float(value)==int(value) and value>=0 and value<=120 else -1
static func identity_hash(value: String) -> int:
	var result := 2166136261
	for byte in value.to_utf8_buffer(): result = ((result ^ byte) * 16777619) & 0xffffffff
	return result
static func _next(state: Array[int]) -> float:
	var value := state[0]
	value = (value ^ (value << 13)) & 0xffffffff
	value = (value ^ (value >> 17)) & 0xffffffff
	value = (value ^ (value << 5)) & 0xffffffff
	state[0] = value
	return float(value)/4294967296.0

static func describe(person: Dictionary = {}) -> Dictionary:
	var source := _key(person.get("sourcePlayerId"))
	var appearance_id := _key(person.get("appearanceId"))
	if appearance_id.is_empty(): appearance_id = source
	if appearance_id.is_empty(): appearance_id = _key(person.get("id"))
	if appearance_id.is_empty(): appearance_id = "anonymous"
	var staff: bool = person.get("portraitRole","")=="staff" or person.get("appearanceRole","")=="staff" or (person.get("role") is String and not person.has("pos"))
	var origin := "player" if not source.is_empty() or not staff else "staff"
	var seed := identity_hash(appearance_id)
	var state: Array[int] = [seed if seed != 0 else 1]
	var reference := _age(person.get("appearanceAge"))
	var current := _age(person.get("age"))
	var band := (int((seed >> 8) % 4) if reference < 0 else clampi(int(floor((reference-40)/10.0)),0,3)) if origin=="staff" else -1
	var requested_bank: Variant = person.get("appearanceBankVersion")
	var bank: int = 2 if (requested_bank is int or requested_bank is float) and requested_bank==2 else 1
	var cell := band*(10 if bank==2 else 4)+seed%(10 if bank==2 else 4) if origin=="staff" else seed%(160 if bank==2 else 32)
	var face_width := .965+_next(state)*.07
	var eye_spacing := -.010+_next(state)*.020
	var nose_width := -.012+_next(state)*.024
	var jaw_width := -.012+_next(state)*.024
	var zoom := 1.005+_next(state)*.025
	var crop_x := -.008+_next(state)*.016
	var crop_y := -.006+_next(state)*.012
	var saturation := .94+_next(state)*.12
	var exposure := .97+_next(state)*.06
	var shirt := _next(state)
	var mirror := _next(state)>=.5
	var visual_age := current if current>=0 else reference if reference>=0 else 45+band*10 if origin=="staff" else 25
	var result := {"version":VERSION,"appearanceId":appearance_id,"seed":seed,"origin":origin,"atlas":"staff" if origin=="staff" else "players","cell":cell,"ageBasis":"current-age" if current>=0 else "appearance-reference" if reference>=0 else "illustrative","referenceAge":reference if reference>=0 else null,"ageBand":band if band>=0 else null,"maturity":clampf((visual_age-30)/50.0,0,1),"faceWidth":face_width,"eyeSpacing":eye_spacing,"noseWidth":nose_width,"jawWidth":jaw_width,"zoom":zoom,"cropX":crop_x,"cropY":crop_y,"saturation":saturation,"exposure":exposure,"shirt":shirt,"mirror":mirror}
	if bank==2:
		var within := cell%10
		var new_staff := origin=="staff" and within>=4
		var path: String = ("res://assets/editorial/portraits-%d.webp" % (cell/16) if cell<32 else "res://art/regen-bank-v2/players-%02d.png" % (cell/16)) if origin=="player" else "res://art/regen-bank-v2/staff-01.png" if new_staff else "res://art/regen-staff-atlas.png"
		result.merge({"version":2,"bankVersion":2,"baseId":"%s:%03d" % [result.atlas,cell],"assetPath":path,"columns":6 if new_staff else 4,"rows":4,"assetCell":cell%16 if origin=="player" else band*(6 if new_staff else 4)+(within-4 if new_staff else within)},true)
	return result

static func texture(person: Dictionary = {}) -> Texture2D:
	var profile := describe(person)
	var cache_key := "%s:%s:%d" % [profile.get("bankVersion",1),profile.atlas,profile.cell]
	if _textures.has(cache_key): return _textures[cache_key]
	var path: String = profile.get("assetPath","res://art/regen-staff-atlas.png" if profile.atlas=="staff" else "res://assets/editorial/portraits-%d.webp" % (int(profile.cell)/16))
	if not ResourceLoader.exists(path): return null
	var source := load(path) as Texture2D
	if source==null: return null
	# Material UVs must be local to this face, never coordinates of the whole
	# atlas. Crop/resize are native Image operations, once per base cell.
	var image := source.get_image()
	if image==null or image.is_empty(): return null
	var index: int = int(profile.get("assetCell",int(profile.cell)%16))
	var columns: int = int(profile.get("columns",4))
	var rows: int = int(profile.get("rows",4))
	var column := index%columns
	var row := int(index/columns)
	var left := int(floor(image.get_width()*column/float(columns)))
	var top := int(floor(image.get_height()*row/float(rows)))
	var right := int(floor(image.get_width()*(column+1)/float(columns)))
	var bottom := int(floor(image.get_height()*(row+1)/float(rows)))
	var face := image.get_region(Rect2i(left,top,right-left,bottom-top))
	face.resize(256,256,Image.INTERPOLATE_LANCZOS)
	var crop := ImageTexture.create_from_image(face)
	if _textures.size()>=MAX_TEXTURES: _textures.erase(_textures.keys()[0])
	_textures[cache_key] = crop
	return crop

static func material(person: Dictionary = {}) -> ShaderMaterial:
	var profile := describe(person)
	var cache_key := JSON.stringify(profile)
	if _materials.has(cache_key): return _materials[cache_key]
	if _shader==null:
		_shader = Shader.new()
		_shader.code = SHADER
	var result := ShaderMaterial.new()
	result.shader = _shader
	for field in ["faceWidth","eyeSpacing","noseWidth","jawWidth","zoom","saturation","exposure","shirt","maturity"]:
		var parameter: String = {"faceWidth":"face_width","eyeSpacing":"eye_spacing","noseWidth":"nose_width","jawWidth":"jaw_width"}.get(field,field)
		result.set_shader_parameter(parameter,profile[field])
	result.set_shader_parameter("crop",Vector2(profile.cropX,profile.cropY))
	result.set_shader_parameter("mirrored",profile.mirror)
	if _materials.size()>=MAX_MATERIALS: _materials.erase(_materials.keys()[0])
	_materials[cache_key] = result
	return result

static func apply(rect: TextureRect, person: Dictionary = {}) -> bool:
	var image := texture(person)
	if image==null: return false
	rect.texture = image
	rect.material = material(person)
	rect.tooltip_text = "Illustration fictive · éléments IA prégénérés et composition locale · ressemblance et unicité non garanties"
	return true

static func cache_info() -> Dictionary:
	return {"textures":_textures.size(),"materials":_materials.size(),"maxTextures":MAX_TEXTURES,"maxMaterials":MAX_MATERIALS}
static func clear_cache() -> void:
	_textures.clear();_materials.clear()
