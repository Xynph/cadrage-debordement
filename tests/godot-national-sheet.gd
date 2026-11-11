extends SceneTree

func _initialize() -> void:
	var path := "res://ui/national_sheet.gd"
	if not ResourceLoader.exists(path):
		printerr("FAIL: La feuille nationale doit normaliser les choix du joueur.")
		quit(1)
		return
	var sheet: GDScript = load(path)
	var slots: Array = []
	slots.resize(23)
	for index in slots.size(): slots[index] = ["test-a", "test-b"]
	slots[2] = ["test-c"]
	var draft: Array = []
	draft.resize(23)
	draft[0] = "test-a"
	draft[1] = "test-a"
	draft[2] = "test-b"
	draft[15] = "test-b"
	draft[16] = "test-a"
	var clean: Array = sheet.normalize(draft, slots)
	var ok: bool = (clean.size() == 23 and clean[0] == "test-a" and clean[1] == null
		and clean[2] == null and clean[15] == "test-b" and clean[16] == null)
	if not ok: printerr("FAIL: La feuille conserve les choix admissibles uniques et replace les autres en automatique.")
	print("Feuille nationale : ", "1 contrôle réussi" if ok else "1 échec")
	quit(0 if ok else 1)
