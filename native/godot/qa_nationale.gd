extends Node
# Extended career acceptance on the shipped Windows runtime and a fresh profile.
var app: Control
var qa: Node
var mode := "world-nationale"
var pack_id := ""
var counts: Dictionary = {}

func run(runner: Node) -> void:
	qa = runner
	app = runner.app
	await _reception()
	qa.world_reception = {"edition":mode,"pack":counts,"pack_id":pack_id,"season":app.model.get("meta",{}).get("season")}


func _check(ok: bool, why: String) -> bool:
	qa._check(ok,why)
	return ok

func _settle() -> void:
	for i in 8:
		await get_tree().process_frame

func _wait() -> bool:
	var deadline := Time.get_ticks_msec() + 120000
	while app.waiting and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await _settle()
	return _check(not app.waiting, "réponse du moteur dans le délai")

func _press(id: String) -> bool:
	var b := app.find_child(id,true,false) as Button
	if not _check(b != null and b.visible and not b.disabled, "bouton actif : "+id):
		return false
	b.pressed.emit()
	return true

func _confirm() -> void:
	for d in app.find_children("*","ConfirmationDialog",true,false):
		if d.visible:
			d.confirmed.emit()
			d.hide()
			return

func _capture(name: String) -> void:
	await qa._capture(name)

func _resize(size: Vector2i) -> void:
	await qa._resize_window(size)

func _pick(id: String) -> bool:
	if not _press(id): return false
	await _settle()
	return true

func _ask(command: String, body: Dictionary = {}, route: String = "") -> bool:
	app._command(command,body,route)
	if not await _wait(): return false
	return _check(app.bridge.last_response_ok, "commande : "+command)

func _reception() -> void:
	var deadline := Time.get_ticks_msec()+60000
	while app.model.get("meta",{}).get("nationaleCatalogue",[]).size() == 0 and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	if not _check(app.model.get("meta",{}).get("nationaleCatalogue",[]).size()==102,"catalogue Nationale chargé"): return
	_check(app.model.meta.worldCatalogue.size()==58 and app.model.meta.pacificCatalogue.size()==68 and app.model.meta.japanCatalogue.size()==88 and app.model.meta.legacyCatalogue.size()==30,"quatre catalogues précédents préservés")
	app.pack_manager.creation_mode = "world-nationale"
	app._navigate("Création")
	await _settle()
	if not await _pick("CreationCountry_FR"): return
	if not await _pick("CreationDivision_nationale"): return
	var pack := OS.get_environment("CD_GODOT_NATIONALE_PACK")
	var final_doc := OS.get_environment("CD_GODOT_NATIONALE_FINAL_EXPORT")
	var full := OS.get_environment("CD_GODOT_NATIONALE_EXPECT_COMPLETE") == "1"
	if not _check(FileAccess.file_exists(pack),"ZIP Nationale fourni"): return
	app.pack_manager.open("creation")
	await _settle()
	app.pack_manager.choose_file()
	await _settle()
	_check(app.pack_manager.picker.visible,"sélecteur de pack natif")
	app.pack_manager.picker.hide()
	app.pack_manager.picker.file_selected.emit(pack)
	if not await _wait(): return
	var preview: Dictionary = app.pack_manager.preview()
	if not _check(not preview.is_empty(),"pack Nationale reconnu"): return
	pack_id = str(preview.id)
	counts = preview.counts
	if full:
		_check(int(counts.clubs)==102 and int(counts.logos)==102 and int(counts.players)==int(app.model.meta.nationaleDatabase.playerCount),"catalogue privé complet")
		_check(int(counts.official+counts.synthetic)==int(counts.players) and int(counts.staffOfficial+counts.staffSynthetic)==int(counts.staff),"tous les portraits ont une origine")
	app.pack_manager.install()
	if not await _wait() or not _check(app.bridge.last_response_ok,"installation du pack par l’interface"): return
	app.pack_manager.select(pack_id,"creation")
	if not await _wait() or not _check(app.bridge.last_response_ok,"sélection du pack de création"): return
	app._navigate("Création")
	await _settle()
	for size in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		await _resize(size)
		var list := app.find_child("CreationClubsScroll",true,false) as ScrollContainer
		var all_visible := list != null
		for id in range(88,102):
			var c := app.find_child("CreationClub"+str(id),true,false) as Button
			all_visible = all_visible and c != null and list.get_global_rect().encloses(c.get_global_rect())
		_check(all_visible,"14 clubs visibles à "+str(size.x))
		var next_button := app.find_child("CreationStart",true,false) as Button
		_check(next_button != null and app.get_viewport_rect().encloses(next_button.get_global_rect()),"action de création à portée à "+str(size.x))
		await _capture("nationale-creation-"+str(size.x))
	if not await _pick("CreationClub100"): return
	if not _press("CreationStart"): return
	_confirm()
	if not await _wait(): return
	_check(int(app.model.club.id)==100 and app.model.meta.leagueId=="nationale" and app.model.meta.edition==mode and app.model.calendar.size()==26 and app.model.leagues.size()==10,"création Nationale, 26 matchs et dix classements")
	_check(app.model.packs.career==pack_id and app.model.staff.teams.size()==102,"liaison privée de carrière et staff")
	_check(app.model.selection.valid,"composition Nationale complète")
	if full:
		_check(FileAccess.file_exists(app.model.club.get("logoPath","")),"logo privé accessible")
		_check(app.model.squad.all(func(p):return FileAccess.file_exists(p.get("portraitPath",""))),"portraits privés de l’effectif accessibles")
		_check(not str(app.model.club.presentation.get("city","")).is_empty() and not str(app.model.club.stadium).begins_with("Parc des "),"territoire et enceinte publiés")
	for route in ["Bureau","Effectif","Composition","Calendrier","Classements","Staff","Rivalités"]:
		app._navigate(route)
		await _capture("nationale-"+route.to_lower()+"-2560")
	if not _check(app.model.get("next") is Dictionary and str(app.model.next.date)=="2026-08-21","premier match publié sur le calendrier de carrière"): return
	if not await _ask("begin_match",{},"Match"): return
	await _capture("nationale-match-2560")
	if not await _ask("delegate"): return
	if not await _ask("finish_round",{},"Bureau"): return
	_check(app.model.history.any(func(r):return r.competitionId=="nationale" and r.pair.any(func(id):return int(id)==100)),"résultat de Nationale enregistré")
	if final_doc.is_empty(): return
	if not _check(FileAccess.file_exists(final_doc),"témoin de saison complète fourni"): return
	app.open_file(true)
	await _settle()
	_check(app.file_dialog.visible,"sélecteur de sauvegarde natif")
	app.file_dialog.hide()
	app.file_dialog.file_selected.emit(final_doc)
	await _settle()
	_confirm()
	if not await _wait(): return
	if not _check(app.bridge.last_response_ok and app.model.meta.canAdvanceSeason and app.model.meta.edition==mode,"saison complète importée par fichier"): return
	var movement: Dictionary = app.model.nationalePromotion.movement
	_check(movement.status=="ready" and movement.accession.size()==16 and movement.nationale.size()==14,"mouvement vérifié vers la Pro D2")
	if not await _ask("next_season",{"confirmed":true}): return
	_check(int(app.model.meta.season)==2 and app.model.archives.seasons.size()==1,"saison 2 et archive persistantes")
	app._navigate("Classements")
	await _capture("nationale-saison2-2560")
	if not await _ask("pack_select",{"id":pack_id,"scope":"career","mode":mode}): return
	_check(app.model.packs.career==pack_id,"pack changeable après reprise")
