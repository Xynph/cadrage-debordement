extends Node
# Extended career acceptance on the shipped Windows runtime and a fresh profile.
var app: Control
var qa: Node
var mode := "world-champ"
var pack_id := ""
var counts: Dictionary = {}
var completed_champ_season := false
var atlas_verified := false
var calendars_verified := false
var contracts_verified := false

func run(runner: Node) -> void:
	qa = runner
	app = runner.app
	await _reception()
	qa.world_reception = {"edition":mode,"pack":counts,"pack_id":pack_id,"season":app.model.get("meta",{}).get("season"),"champ_season2":completed_champ_season,"atlas_verified":atlas_verified,"calendars_verified":calendars_verified,"contracts_verified":contracts_verified}


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
	while app.model.get("meta",{}).get("champCatalogue",[]).size() == 0 and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	if not _check(app.model.get("meta",{}).get("champCatalogue",[]).size()==116,"catalogue Champ chargé"): return
	_check(app.model.meta.worldCatalogue.size()==58 and app.model.meta.pacificCatalogue.size()==68 and app.model.meta.japanCatalogue.size()==88 and app.model.meta.nationaleCatalogue.size()==102 and app.model.meta.legacyCatalogue.size()==30,"cinq catalogues précédents préservés")
	app._navigate("Création")
	await _settle()
	if not await _pick("CreationMode_world-champ"): return
	if not await _pick("CreationDivision_champ"): return
	var pack := OS.get_environment("CD_GODOT_CHAMP_PACK")
	var final_doc := OS.get_environment("CD_GODOT_CHAMP_FINAL_EXPORT")
	var full := OS.get_environment("CD_GODOT_CHAMP_EXPECT_COMPLETE") == "1"
	if not _check(FileAccess.file_exists(pack),"ZIP Champ fourni"): return
	app.pack_manager.open("creation")
	await _settle()
	app.pack_manager.choose_file()
	await _settle()
	_check(app.pack_manager.picker.visible,"sélecteur de pack natif")
	app.pack_manager.picker.hide()
	app.pack_manager.picker.file_selected.emit(pack)
	if not await _wait(): return
	var preview: Dictionary = app.pack_manager.preview()
	if not _check(not preview.is_empty(),"pack Champ reconnu"): return
	pack_id = str(preview.id)
	counts = preview.counts
	if full:
		_check(int(counts.clubs)==116 and int(counts.logos)==116 and int(counts.players)==int(app.model.meta.champDatabase.playerCount),"catalogue privé complet")
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
		for id in range(102,116):
			var c := app.find_child("CreationClub"+str(id),true,false) as Button
			all_visible = all_visible and c != null and list.get_global_rect().encloses(c.get_global_rect())
		_check(all_visible,"14 clubs visibles à "+str(size.x))
		var next_button := app.find_child("CreationStart",true,false) as Button
		_check(next_button != null and app.get_viewport_rect().encloses(next_button.get_global_rect()),"action de création à portée à "+str(size.x))
		await _capture("champ-creation-"+str(size.x))
	if not await _pick("CreationClub102"): return
	if not _press("CreationStart"): return
	_confirm()
	if not await _wait(): return
	_check(int(app.model.club.id)==102 and app.model.meta.leagueId=="champ" and app.model.meta.edition==mode and app.model.calendar.size()==26 and app.model.leagues.size()==11,"création Champ, 26 matchs et onze classements")
	_check(app.model.packs.career==pack_id and app.model.staff.teams.size()==116,"liaison privée de carrière et staff")
	_check(app.model.selection.valid,"composition Champ complète")
	if full:
		_check(FileAccess.file_exists(app.model.club.get("logoPath","")),"logo privé accessible")
		_check(app.model.squad.all(func(p):return FileAccess.file_exists(p.get("portraitPath",""))),"portraits privés de l’effectif accessibles")
		_check(not str(app.model.club.presentation.get("city","")).is_empty() and not str(app.model.club.stadium).is_empty() and str(app.model.club.stadium) != "Fenbank Ground","territoire et enceinte publiés")
		var club_staff: Dictionary = app.model.staff.teams.filter(func(t):return int(t.id)==102)[0]
		_check(club_staff.members.all(func(m):return FileAccess.file_exists(m.get("portraitPath",""))),"portraits privés du staff accessibles")
	for route in ["Bureau","Effectif","Composition","Calendrier","Classements","Staff","Rivalités"]:
		app._navigate(route)
		await _capture("champ-"+route.to_lower()+"-2560")
	app._navigate("Rivalités")
	await _settle()
	var first_date := str(app.model.calendar[0].date)
	for i in range(3):
		if app.model.get("next") is Dictionary: break
		if not _press("ChampPreparationAdvance"): return
		if not await _wait() or not _check(app.bridge.last_response_ok,"avance de préparation Champ"): return
	if not _check(app.model.get("next") is Dictionary and str(app.model.next.date)==first_date and str(app.model.next.scheduleSource).begins_with("rfu-published"),"arrêt au premier match du calendrier RFU"): return
	if not await _ask("begin_match",{},"Match"): return
	await _capture("champ-match-2560")
	if not await _ask("delegate"): return
	if not await _ask("finish_round",{},"Bureau"): return
	_check(app.model.history.any(func(r):return r.competitionId=="champ" and r.pair.any(func(id):return int(id)==102)),"résultat Champ enregistré")
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
	var championship: Dictionary = app.model.leagues.filter(func(l):return l.id=="champ")[0]
	_check(championship.get("champion") is Dictionary and not app.model.champBoundary.get("premExchange",true),"titre Champ et frontière PREM sans échange")
	if not await _ask("next_season",{"confirmed":true}): return
	completed_champ_season = _check(int(app.model.meta.season)==2 and app.model.archives.seasons.size()==1,"saison 2 et archive persistantes")
	if OS.get_environment("CD_GODOT_CHAMP_EXPECT_077") == "1": _receive_077_pools()
	app._navigate("Classements")
	await _capture("champ-saison2-2560")
	if not await _ask("pack_select",{"id":pack_id,"scope":"career","mode":mode}): return
	_check(app.model.packs.career==pack_id,"pack changeable après reprise")
	if OS.get_environment("CD_GODOT_CHAMP_EXPECT_ATLAS") == "1":
		await _receive_atlas()
	if OS.get_environment("CD_GODOT_CHAMP_EXPECT_077") == "1":
		await _receive_077_venue()
	if OS.get_environment("CD_GODOT_CHAMP_EXPECT_078") == "1":
		await _receive_078_calendars()

func _receive_atlas() -> void:
	var club_id := 30
	if not _check(int(counts.get("cityPhotos",0)) >= 10 and int(counts.get("stadiumPhotos",0)) >= 10,"inventaire des photos du territoire complet pour la PREM"): return
	if not await _ask("new_career",{"mode":mode,"club":club_id},"Club"): return
	var photos: Dictionary = app.model.club.presentation.get("photos",{})
	if not _check(int(app.model.club.id)==club_id and app.model.packs.career==pack_id and photos.has("city") and photos.has("stadium"),"bon club et les deux photos liées au pack"): return
	_check(str(app.model.club.presentation.get("city","")) == "Bath" and str(app.model.club.stadium).contains("Recreation Ground"),"ville et stade réels avec l’atlas de Bath")
	for key in ["city","stadium"]:
		var info: Dictionary = photos.get(key,{})
		_check(FileAccess.file_exists(info.get("path","")) and str(info.get("source","")).begins_with("https://") and str(info.get("license","")).begins_with("https://"),"photo attribuée : "+key)
	app._navigate("Club")
	await _settle()
	for key in ["city","stadium"]:
		var credit := app.find_child("VenuePhotoCredit_"+key,true,false) as Label
		_check(credit != null and credit.is_visible_in_tree() and credit.text.contains(photos[key].credit) and credit.tooltip_text.contains(photos[key].source),"crédit visible dans l’EXE : "+key)
	if OS.get_environment("CD_GODOT_CHAMP_EXPECT_078") == "1":
		var terms: Array = app.model.squad.filter(func(p):return p.id=="world:prem:112684" or p.id=="world:prem:130283")
		contracts_verified = _check(terms.size()==2 and terms.all(func(p):return int(p.contractEnd)==1),"deux échéances PREM documentées à la création de carrière")
		var postponed: Array = app.model.calendar.filter(func(f):return f.competitionId=="prem" and int(f.home.id)==30 and f.venue=="Stade à confirmer")
		_check(postponed.size()==2,"les deux rencontres déplacées ne sont pas annoncées au stade habituel")
	await _capture("atlas-prem-territoire-2560")
	app._navigate("Bureau")
	await _settle()
	for id in ["OfficeCityPreview","OfficeStadiumPreview"]:
		var tile := app.find_child(id,true,false) as Control
		_check(tile != null and tile.get_meta("photo_from_pack",false),"aperçu photo dans le Bureau : "+id)
	await _capture("atlas-prem-bureau-2560")
	if not await _ask("pack_select",{"id":"base","scope":"career","mode":mode},"Club"): return
	await _settle()
	_check(app.model.club.presentation.get("photos",{}).is_empty() and app.find_child("VenuePhotoCredit_city",true,false)==null,"retrait du pack et repli sans photo étrangère")
	await _capture("atlas-prem-territoire-sans-pack-2560")
	if not await _ask("pack_select",{"id":pack_id,"scope":"career","mode":mode},"Club"): return
	atlas_verified = _check(app.model.club.presentation.get("photos",{}).size()==2,"réactivation de l’atlas dans la même carrière")

func _receive_077_pools() -> void:
	var cup: Dictionary = app.model.leagues.filter(func(l): return l.id == "challenge")[0]
	var counts_by_pool: Array[int] = []
	for pool: Dictionary in cup.pools:
		var types: Dictionary = {"elite":0,"prem":0,"urc":0,"guest":0}
		for row: Dictionary in pool.rows:
			var id := int(row.id)
			var league := "urc" if id >= 40 and id < 56 else ("prem" if id >= 30 and id < 40 else ("guest" if id == 56 or id == 57 else "elite"))
			types[league] += 1
		counts_by_pool.append(int(types.urc))
		_check(int(types.elite)==2 and int(types.prem)<=1 and int(types.guest)<=1,"poule Challenge générée équilibrée")
	counts_by_pool.sort()
	_check(counts_by_pool==[2,3,3],"URC réparti dans les trois poules futures")

func _receive_077_venue() -> void:
	if not await _ask("new_career",{"mode":mode,"club":47},"Calendrier"): return
	var alternate: Array = app.model.calendar.filter(func(f): return f.competitionId == "challenge" and int(f.home.id) == 56)
	_check(alternate.size()==1 and str(alternate[0].venue)=="St Helen's","le déplacement européen à Swansea garde son stade publié")


func _click_calendar(control: Control) -> void:
	var point := control.get_viewport().get_screen_transform() * (control.get_global_transform_with_canvas() * (control.size / 2.0))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_tree().root.push_input(motion, true)
	await get_tree().process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.position = point
		event.global_position = point
		event.pressed = down
		get_tree().root.push_input(event, true)
		await get_tree().process_frame
	await _settle()


func _calendar_venue(fixture: Dictionary, venue: String) -> bool:
	var list := app.find_child("CalendarScroll", true, false)
	if not _check(list != null, "liste du calendrier visible"): return false
	var rows := list.find_children("*", "Control", true, false).filter(func(row: Node):
		return row.get_meta("fixture_id", "") == fixture.id)
	if not _check(rows.size() == 1, "ligne unique du calendrier : " + str(fixture.id)): return false
	var row: Control = rows.front()
	app.body_scroll.ensure_control_visible(row)
	await _settle()
	var captions := row.find_children("*", "Label", true, false).filter(func(label: Label):
		return label.is_visible_in_tree()).map(func(label: Label): return label.text)
	var parts := venue.split(" · ", false, 1)
	var shown := captions.has(venue) or (parts.size() == 2 and captions.has(parts[0]) and captions.has(parts[1]))
	var fallback := str(fixture.get("home", {}).get("stadium", ""))
	var different_home := not fallback.is_empty() and not venue.contains(fallback)
	var good := _check(shown and (not different_home or not captions.has(fallback)),
		"lieu exact de la ligne " + str(fixture.id) + " : " + venue)
	# Le calendrier historique présente le lieu directement, sans fenêtre de détail.
	if not row is Button: return good
	await _click_calendar(row)
	var detail := app.find_child("CompetitionFixtureDetails", true, false) as AcceptDialog
	if not _check(detail != null and detail.visible, "la ligne ouvre le vrai détail : " + str(fixture.id)): return false
	var full_venue := false
	var wrong_venue := false
	for label: Label in detail.find_children("*", "Label", true, false):
		if not label.is_visible_in_tree(): continue
		full_venue = full_venue or label.text.contains(venue)
		wrong_venue = wrong_venue or (different_home and label.text.contains(fallback))
	good = _check(full_venue and not wrong_venue, "lieu complet dans le détail : " + venue) and good
	await _click_calendar(detail.get_ok_button())
	return _check(not is_instance_valid(detail) or not detail.visible, "le détail du match se ferme") and good


func _receive_078_calendars() -> void:
	if not await _ask("new_career",{"mode":mode,"club":61},"Calendrier"): return
	var pacific: Array = app.model.calendar.filter(func(f):return f.competitionId=="srp")
	var shared: Array = pacific.filter(func(f):return f.neutral)
	var nz := "One New Zealand Stadium · Christchurch"
	var good := _check(pacific.size()==16 and str(pacific[0].venue)==nz and not pacific[0].neutral,"première journée du Pacifique sur son terrain publié")
	good = _check(shared.size()==1 and str(shared[0].venue)==nz and shared[0].date=="2027-04-02","Super Round de Christchurch conservé sur terrain neutre") and good
	if not pacific.is_empty(): good = (await _calendar_venue(pacific[0], nz)) and good
	await _capture("pacifique-calendrier-2560")
	if not await _ask("new_career",{"mode":mode,"club":85},"Calendrier"): return
	var sayama := "SECOM RUGBY STADIUM · Sayama"
	var jp: Array = app.model.calendar.filter(func(f):return f.competitionId=="jlo-d2")
	var first_home: Array = jp.filter(func(f):return int(f.home.id)==85 and f.date=="2026-12-27")
	good = _check(jp.size()==14 and first_home.size()==1 and first_home[0].venue==sayama,"premier match à domicile au stade de Sayama") and good
	good = _check(jp.any(func(f):return int(f.home.id)==85 and str(f.venue).contains("Kawagoe Sports Park")),"enceinte secondaire de Kawagoe distincte du stade principal") and good
	if first_home.size() == 1: good = (await _calendar_venue(first_home[0], sayama)) and good
	await _capture("japon-calendrier-2560")
	app._navigate("Club")
	await _settle()
	var credit := app.find_child("VenuePhotoCredit_stadium",true,false) as Label
	var photo: Dictionary = app.model.club.presentation.get("photos",{}).get("stadium",{})
	good = _check(int(counts.get("stadiumPhotos",0))==86 and FileAccess.file_exists(photo.get("path","")) and credit!=null and credit.is_visible_in_tree() and credit.text.contains("en construction"),"photo officielle du stade de Sayama, crédit visible") and good
	await _capture("atlas-japon-sayama-2560")
	calendars_verified = good
