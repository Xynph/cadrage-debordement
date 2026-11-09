extends SceneTree
const Journal = preload("res://ui/match_journal.gd")
const Reader = preload("res://match_action_review.gd")
class Host extends Control:
	var management_ui: Dictionary = {}
	var accent := Color("b44443")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for frame in 8: await process_frame
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message); printerr("FAIL: "+message)
func run() -> void:
	root.gui_embed_subwindows=true
	var proof := OS.get_environment("CD_DEEPEN_MATCH_ARTIFACTS")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(proof.path_join("live.json")))
	var source: Dictionary = document.state
	var live: Dictionary = source.live.duplicate(true)
	live.teams=[source.clubs[live.pair[0]],source.clubs[live.pair[1]]]
	var host := Host.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var journal := Journal.new()
	host.add_child(journal)
	journal.setup(host)
	journal.size=Vector2(400,650)
	journal.update_frame(live)
	await settle()
	var reader: AcceptDialog = Reader.open(journal,live.events,live.teams)
	await settle()
	# Receive the actual 2D reader. The full client/worker is tested headless.
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		DisplayServer.window_set_size(resolution)
		await settle()
		reader.index=mini(3,reader.selection.size()-1)
		reader._show_event()
		reader.content_scroll.scroll_vertical=0
		await settle()
		check(reader.size.x<=resolution.x and reader.size.y<=resolution.y,"Fenêtre contenue "+str(resolution))
		check(reader.get_ok_button().is_visible_in_tree(),"Fermer visible "+str(resolution))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(proof.path_join("deepen-index-%dx%d.png" % [resolution.x,resolution.y]))
		reader.content_scroll.ensure_control_visible(reader.pitch)
		await settle()
		check(reader.content_scroll.get_global_rect().encloses(reader.pitch.get_global_rect()),"Terrain contenu "+str(resolution))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(proof.path_join("deepen-terrain-%dx%d.png" % [resolution.x,resolution.y]))
		reader._toggle_summary()
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(proof.path_join("deepen-bilan-%dx%d.png" % [resolution.x,resolution.y]))
		reader._toggle_summary()
	FileAccess.open(proof.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("Deepen match UI capture: %d checks, %d failures" % [checks,failures.size()])
	host.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
