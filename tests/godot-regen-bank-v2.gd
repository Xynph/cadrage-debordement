extends SceneTree
const Portrait = preload("res://ui/regen_portrait.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures.append(message);printerr("FAIL: "+message)
func run() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_REGEN_BANK_FIXTURES")))
	check(fixtures.size()==200,"Catalogue réel de200bases")
	var source_images: Dictionary = {}
	for item: Dictionary in fixtures:
		var actual := Portrait.describe(item.person)
		for key in item.profile:
			if item.profile[key] is float or item.profile[key] is int: check(is_equal_approx(float(actual[key]),float(item.profile[key])),"Descripteur partagé "+str(key))
			else: check(actual[key]==item.profile[key],"Descripteur partagé "+str(key))
		var texture := Portrait.texture(item.person)
		check(texture!=null,"PNG réellement disponible : "+str(item.base.id))
		if texture==null:continue
		if not source_images.has(item.absoluteAsset):source_images[item.absoluteAsset]=Image.load_from_file(item.absoluteAsset)
		var source: Image = source_images[item.absoluteAsset]
		var columns: int = int(item.asset.grid[0]);var rows: int = int(item.asset.grid[1]);var cell: int = int(item.base.cell)
		var left := floori(float(source.get_width())*(cell%columns)/columns)
		var top := floori(float(source.get_height())*floori(float(cell)/columns)/rows)
		var right := floori(float(source.get_width())*((cell%columns)+1)/columns)
		var bottom := floori(float(source.get_height())*(floori(float(cell)/columns)+1)/rows)
		var expected := source.get_region(Rect2i(left,top,right-left,bottom-top));expected.resize(256,256,Image.INTERPOLATE_LANCZOS)
		expected.convert(Image.FORMAT_RGBA8)
		var actual_image := texture.get_image();actual_image.convert(Image.FORMAT_RGBA8)
		check(texture.get_size()==Vector2(256,256) and actual_image.get_data()==expected.get_data(),"Crop exact de la cellule cataloguée : "+str(item.base.id))
		check(Portrait.material(item.person)!=null,"Variation locale réellement disponible")
	var cache := Portrait.cache_info()
	check(cache.textures<=48 and cache.materials<=128,"Caches bornés après200bases")
	if OS.get_environment("CD_REGEN_BANK_GRAPHICS")=="1":
		for kind in ["player","staff"]:await contact_sheet(fixtures,kind)
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
func contact_sheet(fixtures: Array,kind: String) -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(1280,1550 if kind=="player" else 720)
	var panel:=ColorRect.new();panel.color=Color("10191a");panel.size=root.size;root.add_child(panel)
	var grid:=GridContainer.new();grid.columns=16 if kind=="player" else 10;grid.position=Vector2(8,8);grid.add_theme_constant_override("h_separation",0);grid.add_theme_constant_override("v_separation",4);panel.add_child(grid)
	for item: Dictionary in fixtures:
		if item.base.kind!=kind:continue
		var card:=VBoxContainer.new();card.custom_minimum_size=Vector2(79 if kind=="player" else 126,146 if kind=="player" else 170);grid.add_child(card)
		var portrait:=TextureRect.new();portrait.custom_minimum_size=Vector2(78 if kind=="player" else 125,125 if kind=="player" else 145);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;Portrait.apply(portrait,item.person);card.add_child(portrait)
		var label:=Label.new();label.text=str(item.base.id);label.add_theme_font_size_override("font_size",10);card.add_child(label)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("CD_REGEN_BANK_OUTPUT").path_join(kind+"-bases.png"))==OK,"Planche "+kind+" complète")
	root.remove_child(panel);panel.queue_free();await process_frame
