extends SceneTree
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for viewport_size in [Vector2(1280,800),Vector2(1440,900),Vector2(1600,1000),Vector2(1920,1080),Vector2(2560,1440)]:
		C.configure(viewport_size.y,viewport_size.x)
		var panel := Control.new();root.add_child(panel)
		var caption := D.text(panel,40,231,"Samedi 12 septembre 2026",27,C.IVORY,700,470)
		var hit := Rect2(Vector2(36,210)*C.density,Vector2(470,24)*C.density)
		var visible := caption.get_rect()
		var union := hit.merge(visible)
		var home := Rect2(Vector2(11,67)*C.density,Vector2(200,142)*C.density)
		var away := Rect2(Vector2(246,67)*C.density,Vector2(212,142)*C.density)
		var font_size := maxi(12,C.px(27))
		print("DATE_METRICS viewport=",viewport_size," density=",C.density," font=",C.font(700).resource_path," pixels=",font_size," ascent=",C.font(700).get_ascent(font_size)," height=",C.font(700).get_height(font_size)," label=",visible," original=",hit," enclosure=",hit.encloses(visible)," union=",union," home_overlap=",union.intersection(home)," away_overlap=",union.intersection(away))
		panel.queue_free()
	quit(0)
