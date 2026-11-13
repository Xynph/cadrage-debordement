extends SceneTree
# Mode Monde : un joueur « depth-… » (créé par le moteur pour tenir 40 pros) est
# présenté comme tel dans l'onglet des repères ; un joueur d'origine ne l'est pas.
const PlayerCanvas = preload("res://ui/immersive08/player_canvas.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func heading(player: Dictionary) -> String:
	var card := Panel.new()
	root.add_child(card)
	PlayerCanvas._sources(card, null, player)
	var label := card.find_child("PlayerSourcesHeading", true, false) as Label
	var text := "" if label == null else label.text
	card.queue_free()
	return text

func run() -> void:
	var file := FileAccess.open(OS.get_environment("CD_DEPTH_FIXTURE"), FileAccess.READ)
	check(file != null, "Fixture lisible")
	if file != null:
		var fixture: Dictionary = JSON.parse_string(file.get_as_text())
		var generated: Dictionary = fixture.generated
		var original: Dictionary = fixture.original
		check(str(generated.id).begins_with("depth-") and not str(original.id).begins_with("depth-"), "Fixture : un joueur généré et un joueur d'origine du mode Monde")
		check(PlayerAttributes.is_generated(generated) and not PlayerAttributes.is_generated(original), "Détection des joueurs générés")
		check(not PlayerAttributes.is_generated({}), "Joueur sans identifiant : jamais présenté comme généré")
		check(heading(generated) == "Joueur généré pour compléter l’effectif", "Repères d'un joueur généré : titre explicite")
		check(heading(original) == "Repères du joueur dans votre carrière", "Repères d'un joueur d'origine inchangés")
	print("depth-player-label : %d contrôles, %d échec(s)" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
