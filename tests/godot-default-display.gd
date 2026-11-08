extends SceneTree
class QaResizeProbe extends "res://qa_runner.gd":
	func _ready() -> void: pass
var failures: Array[String] = []
var checks := 0
var app: Control
var directory := OS.get_environment("CD_DEFAULT_DISPLAY_ARTIFACTS")
var native := DisplayServer.get_name() == "Windows"
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: " + message)
func settle() -> void:
	await create_timer(.2).timeout
	for i in 5: await process_frame
func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new(); event.keycode = code; event.pressed = down
		Input.parse_input_event(event); await process_frame
	await settle()
func geometry(dialog: AcceptDialog, button: Button, label: String) -> void:
	var client := root.get_visible_rect().size
	check(Vector2(dialog.size).x <= client.x and Vector2(dialog.size).y <= client.y,"Dialogue contenu : " + label)
	check(button.is_visible_in_tree() and button.get_global_rect().end.y <= dialog.size.y,"Action visible : " + label)
	check(button.has_focus(),"Focus conservé : " + label)
func capture(label: String) -> void:
	if not native: return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK,"Capture " + label)
func run() -> void:
	# Removing the startup mode or accidentally choosing exclusive fullscreen breaks this contract.
	check(ProjectSettings.get_setting("display/window/size/mode") == Window.MODE_FULLSCREEN,"Le lancement configure le plein écran standard")
	if native:
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,"Le vrai lancement Windows ouvre en plein écran")
	else: print("SKIP réception physique plein écran/fenêtré : DisplayServer ",DisplayServer.get_name())
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop(); await settle()
	check(not app.model.is_empty() and app.route == "Accueil","Accueil réel chargé sans carrière")
	await capture("accueil-plein-ecran")
	app.settings(); await settle()
	var dialog: AcceptDialog = app.find_child("PreferencesDialog",true,false)
	var tabs: TabContainer = dialog.find_child("PreferencesTabs",true,false)
	check(tabs != null and tabs.get_tab_count() == 3,"Trois rubriques de paramètres accessibles")
	if tabs != null: tabs.current_tab = 2
	await settle()
	var fullscreen: Button = dialog.find_child("PreferencesFullscreen",true,false)
	var windowed: Button = dialog.find_child("PreferencesWindowed",true,false)
	check(fullscreen != null and windowed != null,"Deux actions d'affichage identifiables")
	if fullscreen != null and windowed != null:
		check(fullscreen.get_index() < windowed.get_index(),"Plein écran proposé avant le mode fenêtré")
		check(not fullscreen.tooltip_text.is_empty() and not windowed.tooltip_text.is_empty(),"Options d'affichage expliquées")
		if native:
			windowed.grab_focus(); await settle(); await key(KEY_ENTER)
			check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_size() == Vector2i(1440,900),"Vrai bouton clavier ouvre la fenêtre 1440×900")
			geometry(dialog,windowed,"fenêtré"); await capture("preferences-fenetre")
			fullscreen.grab_focus(); await settle(); await key(KEY_ENTER)
			check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,"Vrai bouton clavier rétablit le plein écran standard")
			geometry(dialog,fullscreen,"plein écran"); await capture("preferences-plein-ecran")
	check(not FileAccess.file_exists(str(app.model.meta.dataDir).path_join("donnees.json")),"Changer l'affichage ne crée pas de carrière")
	dialog.hide(); dialog.queue_free(); await settle()
	var resize_probe := QaResizeProbe.new(); resize_probe.app = app; root.add_child(resize_probe)
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		await resize_probe._resize_window(resolution)
	checks += resize_probe.checks; failures.append_array(resize_probe.failures)
	resize_probe.queue_free()
	var file := FileAccess.open(directory.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"native_display":DisplayServer.get_name(),"physical_modes_tested":native},"  ")); file.close()
	app.closing = true; app.bridge.stop()
	print("Affichage par défaut : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
