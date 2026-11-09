extends SceneTree
const Portrait = preload("res://ui/regen_portrait.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message);printerr("FAIL: "+message)
func run() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_REGEN_FIXTURES")))
	for row: Dictionary in fixtures:
		var actual := Portrait.describe(row.person)
		for field in row.expected:
			if row.expected[field] is float or row.expected[field] is int:
				check(is_equal_approx(float(actual[field]),float(row.expected[field])),"Profil partagé Node/Godot : "+str(field))
			else: check(actual[field]==row.expected[field],"Profil partagé Node/Godot : "+str(field))
	Portrait.clear_cache()
	var player := {"id":"regen:player:7","age":23}
	var staff := {"id":"staff:converted:7","sourcePlayerId":"regen:player:7","age":48,"appearanceAge":23,"portraitRole":"staff"}
	check(Portrait.texture(player)==Portrait.texture(staff),"Un joueur devenu staff garde exactement sa base de visage")
	var r := TextureRect.new();root.add_child(r)
	check(Portrait.apply(r,player),"Le portrait de joueur est réellement raccordé")
	check(r.texture is ImageTexture and r.texture.get_size()==Vector2(256,256),"Le visage est un crop local, sans UV d’une autre cellule")
	check(r.material is ShaderMaterial and not r.material.shader.code.is_empty(),"Composition locale et shader présents")
	check(r.tooltip_text.contains("composition locale") and r.tooltip_text.contains("non garanties"),"Origine et limites affichées honnêtement")
	var original_texture := r.texture
	var original_material := r.material
	check(Portrait.apply(r,player) and r.texture==original_texture and r.material==original_material,"Même identité réutilise texture et matériau")
	for i in 220:
		var person := {"id":"regen:cache:"+str(i),"portraitRole":"staff" if i%2 else "player","appearanceAge":40+i%40,"age":42+i%40}
		check(Portrait.texture(person)!=null and Portrait.material(person)!=null,"Base et composition disponibles : "+str(i))
	var cache := Portrait.cache_info()
	check(cache.textures<=48 and cache.materials<=128,"Caches bornés après 220 identités")
	var unknown := Portrait.describe({"id":"staff:unknown","portraitRole":"staff"})
	check(unknown.ageBasis=="illustrative" and unknown.referenceAge==null,"L’âge absent reste explicitement illustratif")
	check(Portrait.describe({"id":"staff:fixed","portraitRole":"staff","appearanceAge":54,"age":54}).cell==Portrait.describe({"id":"staff:fixed","portraitRole":"staff","appearanceAge":54,"age":78}).cell,"L’âge courant ne change pas le visage de référence")
	r.queue_free();await process_frame
	print("Portraits hors ligne : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
