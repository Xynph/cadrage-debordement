extends SceneTree
var app: Control
func _initialize() -> void: call_deferred("run")
func wait_engine() -> bool:
 var deadline := Time.get_ticks_msec()+90000
 while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
 return not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok
func run() -> void:
 root.size=Vector2i(1920,1080)
 app=load("res://main.tscn").instantiate()
 root.add_child(app)
 if not await wait_engine(): printerr("OFF_UI initial worker failed");quit(1);return
 app._command("new_career", {"mode":"common","club":29})
 if not await wait_engine(): printerr("OFF_UI career failed");quit(1);return
 app.timer.stop()
 var profile := OS.get_environment("CD_GODOT_DATA_DIR").path_join("donnees.json")
 var before := FileAccess.get_sha256(profile)
 app._navigate("Effectif")
 for i in 20: await process_frame
 var absent := app.find_child("SocleEffectif",true,false)==null
 var no_write := before==FileAccess.get_sha256(profile)
 var legacy_present: bool = app.find_child("CarnetSquad",true,false)!=null and app.route=="Effectif"
 print("SOCLE_OFF_UI ",JSON.stringify({"flag":OS.get_environment("CD_SOCLE_EFFECTIF"),"newScreenAbsent":absent,"profileUnchanged":no_write,"legacyScreenPresent":legacy_present,"bodyChildren":app.body.get_children().map(func(n):return n.name)}))
 quit(0 if absent and no_write and legacy_present else 1)
