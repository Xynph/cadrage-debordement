extends SceneTree
## Banque d'images du jeu (art/banque) : manifeste, règles de choix et écrans branchés, sans carrière.
## Captures (affichage graphique) : CD_BANQUE_OUTPUT=<dossier>.

const BanqueImages = preload("res://ui/banque_images.gd")
const Between = preload("res://ui/contextual/match_between.gd")
const Tenue = preload("res://ui/tenue_club.gd")
const AvantMatch = preload("res://ui/immersive08/match_avant.gd")
const Reception = preload("res://ui/immersive08/reception_canvas.gd")
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

func tenues() -> void:
	var grille := GridContainer.new()
	grille.columns = 8
	root.add_child(grille)
	grille.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var teintes := ["8c2f39", "1f5c43", "1b3f8b", "e0b35a", "111418", "f2ecdc", "6b2d7a", "d9622b"]
	for n in 8:
		var club := {"id": n, "name": "Club %d" % n, "abbr": "C%d" % n, "color": "#" + teintes[n]}
		var c := Tenue.couleurs(club)
		var shirt := Tenue.image("maillot-%s-face" % Tenue.MOTIFS[n], c[0], c[1], Vector2(200, 200))
		verifier(shirt != null and shirt.material is ShaderMaterial, "maillot %s recolorable" % Tenue.MOTIFS[n])
		if shirt: grille.add_child(shirt)
	for n in 8:
		var club := {"id": n, "name": "Club %d" % n, "abbr": "ABC", "color": "#" + teintes[n]}
		var c := Tenue.couleurs(club)
		var ecu := Tenue.image("ecusson-%s" % Tenue.ECUSSONS[n], c[0], c[1], Vector2(200, 200))
		verifier(ecu != null, "écusson %s recolorable" % Tenue.ECUSSONS[n])
		if ecu: grille.add_child(ecu)
	for n in 8:
		var club := {"id": 100 + n, "slug": "club-%d" % n, "name": "Club %d" % n, "abbr": "RL%d" % n, "color": "#" + teintes[n]}
		var kit := Tenue.maillot(club, Vector2(200, 200))
		verifier(kit != null and Tenue.maillot(club) .get_meta("banque_image") == kit.get_meta("banque_image"), "même club, même motif")
		grille.add_child(kit)
	for n in 8:
		var club := {"id": 100 + n, "slug": "club-%d" % n, "name": "Club %d" % n, "abbr": "RL%d" % n, "color": "#" + teintes[n]}
		var ecu := Tenue.ecusson(club, 180)
		verifier(ecu != null, "écusson du club %d" % n)
		grille.add_child(ecu)
	var sans_blason: Control = preload("res://ui/game_skin.gd").crest({"id": 990, "name": "Club sans blason", "abbr": "CSB", "color": "#1b3f8b"}, 64)
	verifier(sans_blason.name == "ClubCrestRecolored", "club sans blason : écusson recoloré (%s)" % sans_blason.name)
	sans_blason.free()
	verifier(preload("res://ui/immersive08/club_sheet_canvas.gd") != null, "fiche club chargée")
	await capturer("tenues-recolorees")
	grille.queue_free()

func lot5() -> void:
	var sec := {"pluie": 0, "vent": 0, "chaleur": 0}
	verifier(AvantMatch.photo_meteo({"kickoffLocal": "15:00", "date": "2026-10-03", "capacity": 33000, "meteo": sec}) == "stade-grand-interieur-plein-jour", "grand stade en journée, temps sec")
	verifier(AvantMatch.photo_meteo({"kickoffLocal": "15:00", "date": "2026-10-03", "capacity": 9000, "meteo": sec}) == "stade-pelouse-sec-jour", "stade de club en journée")
	verifier(AvantMatch.photo_meteo({"kickoffLocal": "15:00", "date": "2026-10-03", "capacity": 33000, "meteo": {"pluie": 1}}).begins_with("match-tunnel"), "grand stade sous la pluie : tunnel")
	verifier(AvantMatch.photo_meteo({"kickoffLocal": "21:05", "date": "2026-10-03", "capacity": 33000, "meteo": sec}).begins_with("match-tunnel"), "grand stade le soir : tunnel validé")
	for cas: Array in [["Victoire 27-13 face à Vannes.", "resultat-victoire"], ["Victoire avec le bonus offensif à Pau.", "resultat-bonus-offensif"], ["Défaite en finale face à Toulouse.", "resultat-finale-perdue"],
			["Match nul 9-9 à Brive.", "resultat-nul"], ["Le club est sacré champion : le titre est à vous !", "resultat-titre-trophee-leve"], ["Le club est relégué en Pro D2.", "resultat-relegation"], ["Point sur la trésorerie.", "mail-pitch"]]:
		verifier(Reception.photo_resultat(cas[0]) == cas[1], "courrier « %s » : %s (%s)" % [cas[0], Reception.photo_resultat(cas[0]), cas[1]])
	verifier(Between.occasion_fin({"finale": true, "camp": 0}, "victoire") == "finale" and Between.occasion_fin({"essais": [5, 1], "camp": 0}, "victoire") == "bonus" and Between.occasion_fin({"essais": [5, 1], "camp": 1}, "defaite") == "championnat", "fin de match : finale, bonus, championnat")
	var club := {"id": 7, "slug": "club-7", "name": "Club 7", "abbr": "C7", "color": "#8c2f39"}
	var planche: Control = Tenue.planche(club, 300.0)
	verifier(planche != null and planche.get_child_count() == 4, "tenue complète : 4 pièces")
	if planche:
		root.add_child(planche)
		planche.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		await capturer("tenue-complete")
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
	await tenues()
	await lot5()
	print("BANQUE " + JSON.stringify({"controles": controles, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
