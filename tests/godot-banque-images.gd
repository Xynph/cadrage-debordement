extends SceneTree
## Banque d'images du jeu (art/banque) : manifeste, règles de choix et écrans branchés, sans carrière.
## Captures (affichage graphique) : CD_BANQUE_OUTPUT=<dossier>.

const BanqueImages = preload("res://ui/banque_images.gd")
const Between = preload("res://ui/contextual/match_between.gd")
const ClubCanvas = preload("res://ui/immersive08/club_canvas.gd")

var failures: Array = []
var controles := 0
var sortie := OS.get_environment("CD_BANQUE_OUTPUT")

func verifier(ok: bool, message: String) -> void:
	controles += 1
	if not ok: failures.append(message)

func _initialize() -> void: call_deferred("executer")

func capturer(nom: String) -> void:
	if sortie.is_empty() or DisplayServer.get_name() == "headless": return
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image != null: image.save_jpg(sortie.path_join(nom + ".jpg"), 0.86)

func manifeste() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BanqueImages.MANIFESTE))
	verifier(data is Dictionary and data.get("images", []).size() > 0, "manifeste lisible")
	if not data is Dictionary: return
	for image: Dictionary in data.images:
		verifier(BanqueImages.texture(str(image.id)) != null, "texture %s" % image.id)
		verifier(BanqueImages.existe(str(image.get("repli", ""))), "repli connu pour %s" % image.id)

func regles() -> void:
	verifier(BanqueImages.moment("14:30", "2026-10-02") == "jour", "14 h 30 : jour")
	verifier(BanqueImages.moment("16:30", "2026-12-12") == "soir", "16 h 30 en décembre : soir")
	verifier(BanqueImages.moment("21:05", "2026-09-05") == "nuit", "21 h 05 : nuit")
	verifier(BanqueImages.resultat([20, 13], 0) == "victoire" and BanqueImages.resultat([20, 13], 1) == "defaite" and BanqueImages.resultat([9, 9], 1) == "nul", "résultat vu de chaque camp")
	verifier(BanqueImages.choisir("avant-match", {"moment": "jour", "meteo": "pluie"}) == "stade-pelouse-pluie-jour", "pelouse sous la pluie")
	verifier(BanqueImages.choisir("vestiaire", {"phase": "post", "resultat": "defaite"}) == "vestiaire-defaite", "vestiaire après une défaite")
	verifier(BanqueImages.choisir("apres-match", {"resultat": "victoire", "occasion": "championnat"}) == "resultat-victoire", "victoire de championnat (pas une finale)")
	verifier(BanqueImages.choisir("inconnu", {}) == "" and BanqueImages.texture("absent") == null, "écran ou image inconnus : rien")
	verifier(Between.photo_du_fait("try", "") == "action-essai" and Between.photo_du_fait("card", "Carton rouge") == "action-carton-rouge" and Between.photo_du_fait("kick", "") == "", "faits du moteur -> photos")

func stades() -> void:
	var attendus := {3000: "club-stade-niveau-1", 10000: "club-stade-niveau-3", 16000: "club-stade-niveau-4", 33000: "stade-grand-interieur-plein-jour"}
	var planche := HBoxContainer.new()
	root.add_child(planche)
	planche.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for capacite: int in attendus:
		var id := BanqueImages.choisir("infrastructures", {"categorie_image": "stade", "niveau_infrastructure": BanqueImages.niveau_stade(capacite)})
		verifier(id == attendus[capacite], "stade de %d places : %s (%s attendu)" % [capacite, id, attendus[capacite]])
		var colonne := VBoxContainer.new()
		colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		planche.add_child(colonne)
		var etiquette := Label.new()
		etiquette.text = "%d places" % capacite
		etiquette.add_theme_font_size_override("font_size", 30)
		colonne.add_child(etiquette)
		var image := TextureRect.new()
		image.texture = BanqueImages.texture(id)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.size_flags_vertical = Control.SIZE_EXPAND_FILL
		colonne.add_child(image)
	verifier(ClubCanvas.photo_entete({}, "overview") == "club-forest", "bandeau du club hors Infrastructures : inchangé")
	verifier(BanqueImages.niveau_stade(null) == 0 and BanqueImages.choisir("avant-match", {"moment": "jour"}) != "stade-grand-interieur-plein-jour", "grande enceinte réservée aux infrastructures")
	await capturer("stades-selon-capacite")
	planche.queue_free()

func ecran_entre_temps_forts() -> void:
	var hote := Control.new()
	root.add_child(hote)
	hote.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var between: Control = Between.new()
	hote.add_child(between)
	await process_frame
	var equipes := [{"id": 1, "name": "Hawthorn College XV", "colors": ["8c2f39", "f2ecdc"]}, {"id": 2, "name": "Alder Fen XV", "colors": ["1f5c43", "e0b35a"]}]
	var fil := [{"i": 0, "horloge": "4’", "kind": "kick", "texte": "Coup d’envoi d’Alder Fen.", "equipe": 1},
		{"i": 1, "horloge": "12’", "kind": "try", "texte": "Essai d’Alder Fen XV en coin.", "equipe": 1},
		{"i": 2, "horloge": "13’", "kind": "transformation", "texte": "Transformation réussie.", "equipe": 1},
		{"i": 3, "horloge": "21’", "kind": "card", "texte": "Carton jaune pour Hawthorn, plaquage haut.", "equipe": 0}]
	var live := {"teams": equipes, "score": [3, 7], "minute": 22, "events": fil, "finished": false, "paused": true}
	var direct := {"fil": fil, "camp": 1, "borne": 4}
	between.update_frame({"club": equipes[1]}, live, direct, func(_a, _b = null): pass)
	for i in 6: await process_frame
	var photo: TextureRect = between.find_child("MatchBetweenHighlightsPhoto", true, false)
	verifier(photo != null and str(photo.get_meta("photo", "")) == "action-carton-jaune" and photo.texture != null, "faits marquants : photo du dernier fait (%s)" % (photo.get_meta("photo", "") if photo else "absente"))
	await capturer("entre-temps-forts-carton")
	live.finished = true
	live.score = [13, 24]
	between.update_frame({"club": equipes[1]}, live, direct.merged({"fil": fil + [{"i": 4, "horloge": "80’", "kind": "end", "texte": "Fin du match.", "equipe": null}], "borne": 5}), func(_a, _b = null): pass)
	await process_frame
	verifier(str(photo.get_meta("photo", "")) == "resultat-victoire", "fin de match gagné : photo de victoire (%s)" % photo.get_meta("photo", ""))
	await capturer("entre-temps-forts-fin-victoire")
	hote.queue_free()

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	manifeste()
	regles()
	await ecran_entre_temps_forts()
	await stades()
	print("BANQUE " + JSON.stringify({"controles": controles, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
