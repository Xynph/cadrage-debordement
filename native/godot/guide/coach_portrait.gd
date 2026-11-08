extends TextureRect
## Sixteen authored poses selected by context; cosmetic clock never touches engine RNG.
var frame_texture := AtlasTexture.new()
var speaking := false
var reduced_motion := false
var articulation := -1.0
var _elapsed := 0.0
var _idle_elapsed := 0.0
var _rest := 3
var _talk := 4
var _blink := 5
var pose_index := 3
func _ready() -> void:
	frame_texture.atlas = load("res://guide/assets/coach-poses.png")
	frame_texture.filter_clip = true
	texture = frame_texture
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var matte := ShaderMaterial.new(); matte.shader = load("res://guide/coach_matte.gdshader"); material = matte
	_frame(_rest)
func set_context(id: String) -> void:
	var poses := [3,4,5]
	if id in ["composition","premier-match"]: poses = [8,9,2]
	elif id in ["entrainement","tactique","staff"]: poses = [6,7,2]
	elif id in ["resultat","finances","recrutement"]: poses = [10,11,2]
	elif id in ["formation","classements","calendrier"]: poses = [14,15,2]
	elif id == "territoire": poses = [12,13,2]
	elif id == "effectif": poses = [0,1,2]
	_rest = poses[0]; _talk = poses[1]; _blink = poses[2]
	_frame(_talk if _mouth_can_open() else _rest)
func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_elapsed = 0.0; _idle_elapsed = 0.0
	_frame(_talk if _mouth_can_open() else _rest)
func set_speaking(value: bool) -> void:
	speaking = value; _elapsed = 0.0; _idle_elapsed = 0.0
	_frame(_talk if _mouth_can_open() else _rest)
func set_articulation(value: float) -> void:
	articulation = value
	if speaking: _frame(_talk if _mouth_can_open() and int(_elapsed / 0.18) % 3 != 1 else _rest)
func _mouth_can_open() -> bool:
	return speaking and not reduced_motion and articulation != 0.0
func _process(delta: float) -> void:
	if not is_visible_in_tree() or reduced_motion: return
	if speaking:
		_elapsed += delta
		_frame(_talk if _mouth_can_open() and int(_elapsed / 0.18) % 3 != 1 else _rest)
	else:
		_idle_elapsed += delta
		_frame(_blink if fmod(_idle_elapsed, 5.4) > 5.25 else _rest)
func _frame(index: int) -> void:
	pose_index = index
	frame_texture.region = Rect2((index % 4) * 313.5, int(index / 4) * 313.5, 313.5, 313.5)
