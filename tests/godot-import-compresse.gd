extends SceneTree
## Export compressé (exportVersion 4) : le contrôle d'import de Godot (NativeEngineBridge.import_preflight) laisse passer
## l'enveloppe compressée jusqu'à 24 Mio, sans pouvoir lire l'édition de la carrière (elle est dans le contenu
## compressé) : le moteur la décompresse puis compare le fichier au plafond de l'édition. Les autres refus sont inchangés.
const Bridge = preload("res://engine_bridge.gd")

var echecs: Array[String] = []
var controles := 0

func _initialize() -> void: call_deferred("executer")

func verifier(ok: bool, message: String) -> void:
	controles += 1
	if not ok:
		echecs.append(message)
		printerr("FAIL: ", message)

func enveloppe(compression: String, octets: int) -> String:
	var tete := "{\"format\":\"cadrage-debordement-save\",\"exportVersion\":4,\"exportedAt\":\"2026-11-25T00:00:00.000Z\",\"checksum\":\"0badf00d\",\"compression\":\"%s\",\"data\":\"" % compression
	return tete + "A".repeat(octets - tete.length() - 2) + "\"}"

func executer() -> void:
	var mio := 1024 * 1024
	var neuf := enveloppe("gzip", 9 * mio)
	verifier(neuf.to_utf8_buffer().size() == 9 * mio, "enveloppe de 9 Mio")
	verifier(Bridge.import_preflight(neuf, 9 * mio) == "", "enveloppe compressée de 9 Mio : transmise au moteur")
	var plein := enveloppe("gzip", 24 * mio)
	verifier(Bridge.import_preflight(plein, 24 * mio) == "", "enveloppe compressée de 24 Mio pile : transmise au moteur")
	verifier(Bridge.import_preflight(plein + " ", 24 * mio + 1).contains("24 Mio"), "au-delà de 24 Mio : refus inchangé")
	verifier(Bridge.import_preflight(enveloppe("zip", 9 * mio), 9 * mio).contains("8 Mio"), "compression inconnue : refus de 8 Mio inchangé")
	var ordinaire := "{\"format\":\"cadrage-debordement-save\",\"exportVersion\":1,\"state\":{\"pad\":\"" + "a".repeat(9 * mio) + "\"}}"
	verifier(Bridge.import_preflight(ordinaire, ordinaire.length()).contains("8 Mio"), "export ordinaire hors Monde de 9 Mio : refus inchangé")
	verifier(Bridge.import_preflight("{}", 2) == "", "petit fichier : transmis au moteur")
	if echecs.is_empty():
		print("Import compressé Godot · %d contrôles réussis" % controles)
		quit(0)
	else:
		quit(1)
