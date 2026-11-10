extends "res://qa_runner.gd"

const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const RegenPortrait = preload("res://ui/regen_portrait.gd")
const ART := "res://art/immersive08/"

func _run() -> void:
	captures = OS.get_environment("CD_GODOT_QA_CAPTURES")
	if not captures.is_empty(): DirAccess.make_dir_recursive_absolute(captures)
	if not await _wait():
		await _finish()
		return
	engine_pid = app.bridge.child_pid
	app.timer.stop()
	var pristine: bool = not app._has_career() and app.route == "Accueil"
	_check(pristine, "Accueil du profil jetable, sans carrière existante")
	if not pristine:
		await app._close(2)
		return
	_verify_assets()
	await _resize_window(Vector2i(2560, 1440))
	await _visit("Accueil", "ImmersiveWelcome", "entry-ground", "01-accueil")
	app.pack_manager.creation_mode = "common"
	if not await _activate("EntryNewCareer"):
		await _finish()
		return
	await _capture("02-creation")
	if not await _activate("CreationStart") or not await _wait():
		await _finish()
		return
	_check(app._has_career(), "Le véritable sélecteur a créé une carrière")
	if not app._has_career():
		await _finish()
		return
	app.coach.speech.volume = 0
	await _ask("export")
	var baseline: String = app.model.meta.exportText
	var save_path := str(app.model.meta.dataDir).path_join("donnees.json")
	var digest := FileAccess.get_sha256(save_path)
	await _visit_office("03-bureau")
	await _find_club()
	await _visit("Réception", "ImmersiveInbox", "", "04-reception")
	await _visit("Effectif", "ImmersiveRosterTable", "", "05-effectif")
	if await _activate("OpenPlayerFull"):
		_assert_selected_portrait()
		await _capture("06-fiche")
	await _visit("Composition", "LineupSlot10", "tactics-briefing", "07-tactique")
	if await _activate("LineupSlot10"):
		await _resize_window(Vector2i(1280, 720))
		await _capture("08-candidats-720p")
		_dismiss()
		await _resize_window(Vector2i(2560, 1440))
	if await _activate("Nav_Entraînement"):
		_check(app.find_child("ImmersiveTraining", true, false) != null, "Entraînement du paquet")
		await _capture("09-entrainement")
		var command_id: int = app.bridge._next_id
		if await _activate("ImmersiveContinue"):
			var opening := app.root_content.find_child("MatchOpening", true, false) as Control
			_check(app.route == "Match" and opening != null and opening.is_visible_in_tree()
				and app._live().is_empty() and app.bridge._next_id == command_id, "Continuer ouvre l’avant-match sans commande")
			await _activate("NavigationBack")
			_check(app.find_child("ImmersiveTraining", true, false) != null and app.management_ui.preparation.tab == 2,
				"Le retour retrouve l’entraînement")
	await _visit("Club", "ClubStadium", "", "10-club")
	await _visit("Finances", "FinanceLedgerPlot", "finance-hospitality", "11-finances")
	await _visit("Recrutement", "ImmersiveMarketRows", "", "12-recrutement")
	await _visit("Formation", "AcademyImmersiveRows", "", "13-formation")
	await _visit("Classements", "StandingsRows", "", "14-classements")
	await _visit("Vestiaire", "ImmersiveLockerRoom", "lockerroom", "15-vestiaire")
	await _ask("export")
	_check(app.model.meta.exportText == baseline and not digest.is_empty() and FileAccess.get_sha256(save_path) == digest,
		"Consultation et images préservent le fichier et le générateur aléatoire")
	await _coach_reception()
	await _match_and_save()
	var world_fixture := OS.get_environment("CD_GODOT_QA_PUBLIC_WORLD")
	if not world_fixture.is_empty(): await _world_save(world_fixture)
	await _finish()

func _verify_assets() -> void:
	var ids := {}
	for name in ["manifest.json", "generated-manifest.json"]:
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART + name))
		_check(manifest is Dictionary and manifest.get("assets") is Array, "Manifeste emballé : " + name)
		if not manifest is Dictionary or not manifest.get("assets") is Array: continue
		for asset: Dictionary in manifest.assets:
			var id := str(asset.get("id", ""))
			var image := C.texture(id)
			_check(not ids.has(id) and image != null and image.get_size() == Vector2(asset.width, asset.height),
				"Photo décodée à sa résolution d’origine : " + id)
			ids[id] = true
	_check(ids.size() >= 43, "Toutes les photos approuvées et complémentaires sont emballées")
	for pair in [[500, "Medium"], [600, "SemiBold"], [700, "Bold"], [800, "ExtraBold"]]:
		_check(C.font(pair[0]).resource_path.ends_with("BarlowCondensed-" + pair[1] + ".ttf"), "Graisse emballée " + pair[1])
	_check(C.BODY.resource_path.ends_with("DMSans.ttf"), "DM Sans emballée")
	_check(C.icon_texture("tactic") != null, "Pictogrammes vectoriels embarqués")

func _activate(id: String) -> bool:
	var button := app.find_child(id, true, false) as Button
	var ready := button != null and button.is_visible_in_tree() and not button.disabled
	_check(ready, "Action native disponible : " + id)
	if not ready: return false
	button.pressed.emit()
	await _settle()
	return true

func _assert_art(id: String) -> void:
	var image := app.root_content.find_child("Art_" + id.replace("-", "_"), true, false) as TextureRect
	_check(_has_visible_texture(image), "Illustration affichée dans le jeu : " + id)

func _has_visible_texture(image: TextureRect) -> bool:
	return image != null and image.is_visible_in_tree() and image.texture != null and image.size.x > 0 and image.size.y > 0

func _assert_selected_portrait() -> void:
	var hero := app.root_content.find_child("FullPlayerHero", true, false) as Control
	var portrait := hero.get_child(0) as TextureRect if hero != null and hero.get_child_count() > 0 else null
	var player := P.player(app.model, app.selected_player)
	_check(not player.is_empty() and _has_visible_texture(portrait)
		and portrait.texture == RegenPortrait.texture(player) and portrait.material == RegenPortrait.material(player),
		"Portrait du joueur sélectionné affiché dans sa fiche")

func _visit_office(shot: String) -> void:
	await _visit("Bureau", "OfficeFixture", "", "")
	var identity := G.identity(app.model.club)
	var photos: Dictionary = identity.get("photos", {})
	var has_territory := false
	var illustrated := true
	for info in [["city", "OfficeCityPreview"], ["stadium", "OfficeStadiumPreview"]]:
		var place: Variant = identity.get(info[0])
		if (place == null or str(place).strip_edges().is_empty()) and photos.get(info[0], {}).is_empty(): continue
		has_territory = true
		var preview := app.root_content.find_child(info[1], true, false) as Control
		illustrated = illustrated and preview != null and preview.get_child_count() > 0 and _has_visible_texture(preview.get_child(0) as TextureRect)
	if not has_territory:
		_assert_art(P.fixture_ground(app.model.meta, "office-hero"))
	else:
		_check(illustrated, "Illustrations du territoire du club affichées au Bureau")
	await _capture(shot)

func _visit(route: String, expected: String, art: String, shot: String) -> void:
	app._navigate(route)
	await _settle()
	var node := app.root_content.find_child(expected, true, false) as Control
	_check(node != null and node.is_visible_in_tree(), "Gabarit visible dans l’exécutable : " + route)
	if not art.is_empty(): _assert_art(art)
	if not shot.is_empty(): await _capture(shot)

func _find_club() -> void:
	var teams: Array = app.model.get("staff", {}).get("teams", [])
	_check(not teams.is_empty(), "La carrière commune contient son annuaire des clubs")
	if teams.is_empty() or not await _activate("ImmersiveSearch"): return
	var target: Dictionary = teams.back()
	var palette := app.get_node_or_null("NavigationPalette") as AcceptDialog
	if palette == null:
		_check(false, "La palette est ouverte depuis la barre de navigation")
		return
	var search := palette.find_child("NavigationSearch", true, false) as LineEdit
	search.text = str(target.name)
	search.text_changed.emit(search.text)
	palette.confirmed.emit()
	await _settle()
	_check(app.route == "Staff" and app.selected_staff_club == int(target.id), "La recherche ouvre l’annuaire du club demandé")

func _match_and_save() -> void:
	await _coverage()
	app._navigate("Bureau")
	await _settle()
	if not await _activate("ImmersiveContinue"): return
	_check(app.route == "Préparation", "Continuer mène du Bureau au dossier de match")
	_assert_art("analysis-room")
	await _capture("15b-preparation-du-match")
	if not await _activate("PreparationGoMatch"): return
	var opening := app.root_content.find_child("MatchOpening", true, false) as Control
	_check(app.route == "Match" and opening != null and opening.is_visible_in_tree(), "Le dossier ouvre l’avant-match")
	_assert_art("match-tunnel")
	await _capture("16-avant-match")
	var kickoff: Button = app.match_screen.play if is_instance_valid(app.match_screen) else null
	var ready := kickoff != null and kickoff.is_visible_in_tree() and not kickoff.disabled
	_check(ready, "Le vrai bouton de coup d’envoi est disponible")
	if not ready: return
	kickoff.pressed.emit()
	if not await _wait(): return
	app.timer.stop()
	_check(is_instance_valid(app.match_view) and app.model.live is Dictionary, "Le vrai match 3D reçoit le direct")
	await _capture("17-direct")
	if not await _ask("delegate"): return
	_check(app.model.live is Dictionary and app.model.live.finished, "Le moteur a joué la rencontre")
	await _capture("18-resultat")
	if not await _ask("finish_round") or not await _ask("save") or not await _ask("export"): return
	var saved: String = app.model.meta.exportText
	var history: Array = app.model.history
	_check(not history.is_empty(), "La rencontre validée figure dans l’historique")
	if not await _ask("import", {"text": saved}) or not await _ask("export"): return
	var before: Variant = JSON.parse_string(saved)
	var after: Variant = JSON.parse_string(app.model.meta.exportText)
	_check(before is Dictionary and after is Dictionary, "Les deux exports contiennent un document de carrière")
	if not before is Dictionary or not after is Dictionary: return
	# Chaque export reçoit son propre horodatage. Le reste du document est stable.
	for document: Dictionary in [before, after]:
		var stamp := str(document.get("exportedAt", ""))
		_check(stamp.length() == 24 and stamp.ends_with("Z") and Time.get_unix_time_from_datetime_string(stamp.left(19)) > 0,
			"L’horodatage de l’export est valide")
		document.erase("exportedAt")
	_check(before == after, "Le paquet relit intégralement la carrière exportée, checksum et RNG compris")
	_check(not app.model.get("finance", {}).get("ledger", []).is_empty(), "Le journal financier de la carrière jouée contient des écritures")
	await _visit("Finances", "FinanceLedgerPlot", "finance-hospitality", "19-finances-apres-match")

func _world_save(path: String) -> void:
	var fixture := FileAccess.open(path, FileAccess.READ)
	_check(fixture != null, "Le vrai fichier de recette Monde est lisible")
	if fixture == null: return
	var bytes := fixture.get_length()
	fixture.close()
	_check(bytes > 8 * 1024 * 1024, "L’export Monde dépasse l’ancienne limite de 8 Mio")
	app.open_file(true)
	await _settle()
	_check(app.file_dialog.visible, "Le paquet ouvre son sélecteur d’import")
	app.file_dialog.file_selected.emit(path)
	await _settle()
	_confirm()
	if not await _wait(): return
	var meta: Dictionary = app.model.get("meta", {})
	var imported: bool = app.bridge.last_response_ok and meta.get("mode") == "world"
	_check(imported and not app.file_dialog.visible, "Le sélecteur importe la vraie carrière Monde et se ferme")
	if not imported: return
	var competitions: Array = app.model.get("leagues", []).map(func(league: Dictionary): return str(league.id))
	var results: int = app.model.get("history", []).size()
	_check(competitions.has("prem") and competitions.has("urc") and competitions.has("champions") and competitions.has("challenge") and results > 0,
		"Championnat, coupes et résultats de la carrière sont projetés dans le paquet")
	await _visit_office("20-bureau-monde")
	await _visit("Classements", "StandingsRows", "", "21-classements-monde")
	if await _activate("StandingsDivision_champions"): await _capture("22-poules-europe")
	if meta.get("canAdvanceSeason", false):
		var season := int(meta.season)
		if await _ask("next_season", {"confirmed": true}):
			_check(int(app.model.meta.season) == season + 1, "Le paquet ouvre la saison suivante de la vraie carrière Monde")
			await _visit("Club", "ImmersiveClub", "", "23-club-monde")
			if await _activate("ClubTab_history"): await _capture("24-palmares-monde")
	systems_reception["immersive_world"] = {"file_bytes": bytes, "imported_results": results, "competitions": competitions, "season": app.model.meta.season}
