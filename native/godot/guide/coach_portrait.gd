extends TextureRect
## Six drawn poses. No transform tween and no random-number consumption.
var frame_texture := AtlasTexture.new()
var speaking := false
var _elapsed := 0.0
var _idle_elapsed := 0.0
var _pose := 0
func _ready() -> void:
	frame_texture.atlas = load("res://guide/assets/coach-sprites.png")
	frame_texture.filter_clip = true
	texture = frame_texture
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame(0)
func set_speaking(value: bool) -> void:
	speaking = value
	_elapsed = 0.0; _idle_elapsed = 0.0; _pose = 0
	_frame(1 if value else 0)
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	if speaking:
		_elapsed += delta
		var beat := int(_elapsed / 0.16)
		var gesture := int(_elapsed / 2.4) % 3 == 1
		_frame((3 if gesture else 0) + (1 if beat % 2 == 0 else 0))
	else:
		_idle_elapsed += delta
		var phase := fmod(_idle_elapsed, 4.3)
		_frame(2 if phase > 4.16 else 0)
func _frame(index: int) -> void:
	frame_texture.region = Rect2((index % 3) * 512, int(index / 3) * 512, 512, 512)
