extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); printerr("FAIL: " + message)

func run() -> void:
	check(ResourceLoader.exists("res://ui/immersive08/components.gd"), "Composants natifs de la DA approuvée disponibles")
	if not failures.is_empty():
		print("immersive08 : ", checks, " contrôles, ", failures.size(), " échecs")
		quit(1)
		return
	var kit: GDScript = load("res://ui/immersive08/components.gd")
	var card: Control = kit.card("TITRE RÉEL", Vector2(600, 400))
	root.add_child(card)
	await process_frame
	check(card is PanelContainer, "Tuile native indépendante")
	check(card.find_child("CardTitle", true, false).text == "TITRE RÉEL", "Titre éditable, pas texte dans une image")
	var button: Button = kit.button("Décider", func(): card.set_meta("action", true), true)
	card.get_meta("content").add_child(button)
	button.pressed.emit()
	check(card.get_meta("action", false), "Bouton fonctionnel")
	check(button.focus_mode == Control.FOCUS_ALL, "Action accessible au clavier")
	var photo: Control = kit.photo("office-hero", Vector2(400, 280))
	card.get_meta("content").add_child(photo)
	check(photo is TextureRect and photo.texture != null, "Illustration décodée par Godot")
	check(photo.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Illustration ne bloque pas les actions")
	for id in ["brand", "tactics-briefing", "training-session", "stadium", "academy-training", "trophy", "scouting", "hospitality", "forest", "player-hero", "recruit-profile", "mail-staff"]:
		var texture: Texture2D = kit.texture(id)
		check(texture != null and texture.get_width() > 0, "Texture native : " + id)
	card.queue_free()
	await process_frame
	print("immersive08 : ", checks, " contrôles, ", failures.size(), " échecs")
	quit(0 if failures.is_empty() else 1)
