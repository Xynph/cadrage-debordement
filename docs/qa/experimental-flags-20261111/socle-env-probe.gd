extends SceneTree
func _initialize() -> void:
 var screen = load("res://ui/socle/ecran_effectif.gd")
 var app := Control.new()
 var active: bool = screen.actif(app)
 app.set_meta("socle_effectif",true)
 print("ENV_SOCLE ",JSON.stringify({"environment":OS.get_environment("CD_SOCLE_EFFECTIF"), "active":active,"metadataEnabled":screen.actif(app)}))
 app.free()
 quit(0)
