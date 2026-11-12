extends SceneTree
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.transparent_bg = true
	RenderingServer.set_default_clear_color(Color.TRANSPARENT)
	root.size = Vector2i(1280,800)
	root.content_scale_size = root.size
	DisplayServer.window_set_size(root.size)
	for viewport_size in [Vector2(1280,800),Vector2(1440,900),Vector2(1600,1000),Vector2(1920,1080),Vector2(2560,1440)]:
		C.configure(viewport_size.y,viewport_size.x)
		var panel := Control.new()
		root.add_child(panel)
		var label := D.text(panel,40,231,"12/09/2026 · 15:00",27,C.IVORY,700,470)
		var target := Rect2(Vector2(36,210)*C.density,Vector2(470,24)*C.density)
		target.size.y = maxf(18.0,maxf(target.size.y,ceilf(label.size.y)))
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var ink := Rect2(image.get_used_rect())
		print("DATE_INK ",JSON.stringify({"viewport":[viewport_size.x,viewport_size.y],"density":C.density,"label":[label.position.x,label.position.y,label.size.x,label.size.y],"target":[target.position.x,target.position.y,target.size.x,target.size.y],"ink":[ink.position.x,ink.position.y,ink.size.x,ink.size.y],"ink_enclosed":target.encloses(ink)}))
		panel.queue_free()
		await process_frame
	quit(0)
