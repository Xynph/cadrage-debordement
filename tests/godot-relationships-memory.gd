extends SceneTree
const View = preload("res://ui/relationships_view.gd")
var failures: Array[String] = []
var checks := 0

class Host extends Control:
	var model: Dictionary = {}
	var management_ui: Dictionary = {}
	var accent := Color("#6f9ac9")
	var commands := 0
	func _command(_command: String, _payload: Dictionary) -> void: commands += 1

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for frame in 4: await process_frame
func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_RELATIONSHIP_MEMORY_FIXTURE")))
	var host := Host.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	host.model = fixture.model
	host.management_ui = {"relationships":{"playerId":fixture.player_id}}
	var original := JSON.stringify(host.model)
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = resolution
		var page := View.build(host)
		host.add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await settle()
		var personality: Label = page.find_child("RelationshipPersonality", true, false)
		check(personality != null and personality.text.contains(fixture.trait), "Trait de la personne sélectionnée " + str(resolution))
		var memories := page.find_children("RelationshipConversationMemory", "Label", true, false)
		check(memories.size() == 1 and memories[0].text.contains("Rassurer"), "Choix individuel réellement pris, sans confusion avec un autre joueur")
		var events := page.find_children("RelationshipEventMemory", "Label", true, false)
		check(events.size() == 1 and events[0].text.contains(fixture.event_title) and events[0].text.contains("Confier un rôle"), "Mémoire exacte de l’événement et du choix")
		check(not events[0].text.contains("Satisfaction"), "Aucun effet historique inventé pour l’événement sans mesure archivée")
		var chooser := page.find_child("RelationshipPlayer", true, false) as OptionButton
		chooser.grab_focus(); await settle()
		check(chooser.has_focus(), "Sélecteur accessible au clavier")
		check(host.commands == 0 and JSON.stringify(host.model) == original, "Consultation sans commande ni mutation du modèle")
		if OS.get_environment("CD_RELATIONSHIP_MEMORY_GRAPHICS") == "1" and resolution == Vector2i(2560,1440):
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			check(picture.get_width() == 2560 and picture.get_height() == 1440, "Vraie capture 2560×1440")
			check(picture.save_png(OS.get_environment("CD_RELATIONSHIP_MEMORY_ARTIFACTS").path_join("relationships-memory-2560.png")) == OK, "Capture du vestiaire")
		host.remove_child(page); page.queue_free(); await settle()
	# A legacy projection without personality/history remains readable and does
	# not invent either identity, reaction, or an action for an unknown field.
	for person: Dictionary in host.model.clubLife.relationships.players: person.erase("personality")
	host.model.clubLife.relationships.conversationHistory = []
	host.model.clubLife.relationships.history = []
	var legacy := View.build(host); host.add_child(legacy); await settle()
	check(legacy.find_child("RelationshipPersonality", true, false) == null, "Personnalité absente laissée inconnue")
	check(legacy.find_child("RelationshipEventMemory", true, false) == null, "Aucune histoire fabriquée pour l’ancienne projection")
	check(host.commands == 0, "Aucune consultation transformée en décision")
	var report := {"checks":checks,"failures":failures}
	var file := FileAccess.open(OS.get_environment("CD_RELATIONSHIP_MEMORY_ARTIFACTS").path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	print("MÉMOIRE DU VESTIAIRE : %s contrôles ; %s échec(s)" % [checks,failures.size()])
	host.queue_free(); await settle(); quit(0 if failures.is_empty() else 1)
