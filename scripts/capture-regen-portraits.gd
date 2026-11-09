extends SceneTree
const Portrait=preload("res://ui/regen_portrait.gd")
func _initialize():call_deferred("run")
func run():
	var output:=OS.get_environment("CD_REGEN_CONTACT_SHEET")
	if output.is_empty() or not output.is_absolute_path():
		printerr("Définir CD_REGEN_CONTACT_SHEET avec un PNG de sortie absolu.");quit(2);return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(1280,1400)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var backdrop:=ColorRect.new();backdrop.color=Color("0b1214");backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(backdrop)
	var grid:=GridContainer.new();grid.columns=4;grid.position=Vector2(32,26);grid.add_theme_constant_override("h_separation",18);grid.add_theme_constant_override("v_separation",18);root.add_child(grid)
	for row in 4:
		for column in 4:
			var box:=VBoxContainer.new();grid.add_child(box)
			var person:Dictionary
			if row==0:person={"id":"regen:player:"+str(column),"age":23}
			elif row==1:person={"id":"staff:converted:"+str(column),"sourcePlayerId":"regen:player:"+str(column),"appearanceAge":23,"age":53,"portraitRole":"staff"}
			elif row==2:person={"id":"staff:new:"+str(column),"appearanceAge":45+column*10,"age":45+column*10,"portraitRole":"staff"}
			else:person={"id":"regen:other:"+str(column),"age":27}
			var image:=TextureRect.new();image.custom_minimum_size=Vector2(286,286);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;box.add_child(image);Portrait.apply(image,person)
			var label:=Label.new();label.text=["Joueur · 23 ans","Même identité · staff 53 ans","Staff · apparence de référence","Autre identité · 27 ans"][row];label.add_theme_font_size_override("font_size",16);box.add_child(label)
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	if image.save_png(output)!=OK:
		printerr("Capture non enregistrée.");quit(1);return
	print("PORTRAIT_RENDER ",image.get_size()," ",RenderingServer.get_video_adapter_name())
	quit()
