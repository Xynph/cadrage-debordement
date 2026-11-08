extends SceneTree
const Atomic = preload("res://atomic_file.gd")
var failures: Array[String] = []
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("FAIL: ", label)
func write_file(filename: String, text: String) -> void:
	var file := FileAccess.open(filename, FileAccess.WRITE)
	check(file != null, "Temporaire ouvert")
	if file != null: file.store_string(text); file.flush(); file.close()
func _initialize() -> void:
	var directory := OS.get_environment("CD_ATOMIC_DIRECTORY")
	if directory.is_empty(): quit(2); return
	var destination := directory.path_join("préférences.json")
	var temporary := directory.path_join("temporaire fermé.json")
	var initial := FileAccess.get_file_as_string(destination)
	if OS.get_environment("CD_ATOMIC_GUIDE_FAILURE") == "1":
		var store = load("res://guide/guide_profile.gd").new()
		store.load_profile(directory)
		var previous: Dictionary = store.data.duplicate(true)
		var original := FileAccess.get_file_as_bytes(directory.path_join("guide.json"))
		var next: Dictionary = previous.duplicate(true)
		next.muted = not previous.muted
		check(not store.save_profile(next), "Guide : vrai refus de remplacement")
		check(not store.last_error.is_empty(), "Guide : refus visible")
		check(store.data == previous, "Guide : état mémoire précédent conservé")
		check(FileAccess.get_file_as_bytes(directory.path_join("guide.json")) == original, "Guide : octets précédents conservés")
		check(Array(DirAccess.get_files_at(directory)).filter(func(name): return name.begins_with("guide.json.tmp-")).is_empty(), "Guide : nettoie son seul temporaire")
		print("ATOMIC GUIDE REFUSAL : ", checks, " contrôles ; ", failures.size(), " échec(s)")
		quit(0 if failures.is_empty() else 1)
		return
	write_file(temporary, "nouveau")
	if OS.get_environment("CD_ATOMIC_RESPONSE_FAILURE") == "1":
		check(not Atomic.replace_staged(temporary, destination).is_empty(), "Erreur de protocole visible")
		check(FileAccess.get_file_as_string(destination) == initial, "Original intact")
		check(FileAccess.file_exists(temporary), "Temporaire laissé à l’appelant")
	else:
		var node_path := OS.get_environment("CD_NODE_EXECUTABLE")
		OS.set_environment("CD_NODE_EXECUTABLE", directory.path_join("runtime-absent.exe"))
		check(not Atomic.replace_staged(temporary, destination).is_empty(), "Runtime absent refuse sans repli")
		check(FileAccess.get_file_as_string(destination) == initial, "Original intact sans runtime")
		OS.set_environment("CD_NODE_EXECUTABLE", node_path)
		DirAccess.make_dir_recursive_absolute(directory.path_join("autre dossier accentué"))
		var french_error := Atomic.replace_staged(temporary, directory.path_join("autre dossier accentué/préférences.json"))
		check(french_error == "Remplacement refusé : Le temporaire et la destination doivent partager le même dossier.", "Erreur française décodée exactement après OS.execute")
		check(FileAccess.get_file_as_string(destination) == initial and FileAccess.get_file_as_string(temporary) == "nouveau", "Refus français conserve les fichiers accentués")
		check(not Atomic.replace_staged("relatif", destination).is_empty(), "Chemin relatif refusé")
		check(not Atomic.replace_staged(temporary + ".absent", destination).is_empty(), "Temporaire absent refusé")
		var successful := 0
		var refused := 0
		for attempt in 800:
			if successful == 80: break
			write_file(temporary, JSON.stringify({"sequence":successful + 1,"payload":"é".repeat(4096)}))
			var error := ""
			if OS.get_environment("CD_ATOMIC_LEGACY") == "1":
				var result := DirAccess.rename_absolute(temporary, destination)
				if result != OK: error = error_string(result)
			else:
				error = Atomic.replace_staged(temporary, destination)
			if error.is_empty(): successful += 1
			else:
				refused += 1
				var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(destination))
				check(previous is Dictionary and previous.get("sequence") == successful, "Refus conserve la version précédente")
				check(FileAccess.file_exists(temporary), "Refus conserve le temporaire")
		check(successful == 80, "80 remplacements réellement effectués")
		print("ATOMIC WRITES : ", successful, " succès ; ", refused, " refus explicites")
	print("ATOMIC GODOT : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)
