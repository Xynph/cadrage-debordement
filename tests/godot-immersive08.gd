extends SceneTree

var checks := 0
var failures: Array[String] = []
var app: Control

func settle() -> void:
	for i in 8: await process_frame

func worker() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Réponse du vrai moteur")
	app.timer.stop()
	await settle()

func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await worker()
	check(app.bridge.last_response_ok, "Commande native : " + id + " " + app.last_error)

func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	if is_instance_valid(app.coach): app.coach.close()
	await settle()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(OS.get_environment("CD_IMMERSIVE_ARTIFACTS").path_join(id + ".png")) == OK, "Capture native : " + id)

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
	check(kit.font(700).resource_path.ends_with("BarlowCondensed-Bold.ttf"), "Graisse700 exacte des titres approuvés")
	check(kit.font(500).resource_path.ends_with("BarlowCondensed-Medium.ttf"), "Graisse500 exacte des libellés approuvés")
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
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(2560, 1440)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await worker()
	await command("new_career", {"club":0, "mode":"fiction"})
	app._navigate("Bureau")
	await settle()
	check(app.find_child("ImmersiveShell", true, false) != null, "Raccordement dans le vrai rendu du jeu")
	var output := FileAccess.open(OS.get_environment("CD_IMMERSIVE_ARTIFACTS").path_join("model.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(app.model))
	output.close()
	check(ResourceLoader.exists("res://ui/immersive08/shell.gd"), "Shell immersif natif disponible")
	if ResourceLoader.exists("res://ui/immersive08/shell.gd"):
		var shell: GDScript = load("res://ui/immersive08/shell.gd")
		await command("export")
		var before: String = app.model.meta.exportText
		var disk := str(app.model.meta.dataDir).path_join("donnees.json")
		var bytes := FileAccess.get_file_as_bytes(disk)
		check(shell.render(app), "Rendu natif du Bureau pris en charge")
		await settle()
		for id in ["ImmersiveShell", "ImmersiveSidebar", "ImmersiveTopbar", "OfficeFixture", "OfficeDecisions", "OfficeGroup", "OfficeStandings", "OfficeJournal", "OfficeRecruitment", "OfficeTimeline"]:
			check(app.find_child(id, true, false) != null, "Élément réel : " + id)
		check(app.size.x >= 2500, "2560p exploités sans agrandir un canvas 1600p")
		for id in ["OfficeFixture", "OfficeDecisions", "OfficeGroup", "OfficeStandings", "OfficeJournal", "OfficeRecruitment", "OfficeTimeline"]:
			var tile: Control = app.find_child(id, true, false)
			if tile == null: continue
			check(tile.get_global_rect().end.x <= app.size.x + 1, "Tuile dans la largeur : " + id)
			check(tile.size.x >= 300, "Largeur utile en 1440p : " + id)
			check(tile.get_global_rect().end.y <= app.body_scroll.get_global_rect().end.y + 1, "Tuile entièrement visible en 1440p : " + id)
		check(app.find_child("Art_office_hero", true, false) != null, "Image originale présente dans le Bureau réel")
		var positions := {"OfficeFixture":Vector2(280,220), "OfficeDecisions":Vector2(1656,220), "OfficeGroup":Vector2(280,654), "OfficeStandings":Vector2(718,654), "OfficeJournal":Vector2(1418,654), "OfficeRecruitment":Vector2(1982,654), "OfficeTimeline":Vector2(280,1118)}
		for id in positions:
			var tile: Control = app.find_child(id,true,false)
			check(tile != null and tile.global_position.distance_to(positions[id]) <= 1.5, "Coordonnées exactes du gabarit : " + id + " " + str(tile.global_position if tile != null else Vector2.ZERO))
		await capture("01-bureau-2560x1440")
		app._navigate("Effectif")
		shell.render(app)
		await settle()
		var roster: Control = app.find_child("ImmersiveRosterTable", true, false)
		if OS.get_environment("CD_IMMERSIVE_SCOPE") != "office": check(roster != null, "Table Effectif dense de la référence 1440p")
		if roster != null:
			var list: VBoxContainer = app.find_child("ImmersiveRosterRows", true, false)
			var row_buttons: Array = list.get_children().filter(func(node:Node):return node is Button)
			check(row_buttons.size() == mini(24,app.model.squad.size()), "24 lignes du gabarit approuvé, pagination des joueurs supplémentaires")
			var all_ids: Array = row_buttons.map(func(node:Node):return str(node.get_meta("player_id")))
			var next_page: Button = app.find_child("RosterPaginationNext",true,false)
			check(next_page != null, "Pagination conservée depuis natif07")
			while next_page != null and not next_page.disabled:
				next_page.pressed.emit()
				await settle()
				all_ids.append_array(list.get_children().filter(func(node:Node):return node is Button).map(func(node:Node):return str(node.get_meta("player_id"))))
			check(all_ids.size()==app.model.squad.size(), "Tout le groupe consultable à travers les pages")
			check(all_ids.all(func(id):return all_ids.count(id)==1), "Aucun joueur omis ou dupliqué dans la pagination")
			var saved_page: int = app.management_ui.roster.page
			app._navigate("Bureau");app._navigate("Effectif");await settle()
			check(int(app.management_ui.roster.page)==saved_page,"Retour respecte la page volontaire sans révéler à nouveau le dossier")
			list=app.find_child("ImmersiveRosterRows",true,false)
			for id in ["RosterColumnSalary", "RosterColumnFatigue", "RosterColumnPotential", "PlayerDossier", "OpenPlayerFull", "OfferRenewal", "OpenComparison"]:
				check(app.find_child(id, true, false) != null, "Fonction Effectif : " + id)
			var selected_before: String = app.selected_player
			var target: Dictionary = app.model.squad[1]
			var search: LineEdit = app.find_child("RosterSearch", true, false)
			search.text = str(target.name)
			search.text_changed.emit(search.text)
			await settle()
			check(list.get_children().filter(func(node:Node):return node is Button).size() == 1, "Recherche réelle réduit la liste")
			check(app.selected_player == selected_before, "Filtrer conserve le dossier lu")
			var person: Button = list.get_children().filter(func(node:Node):return node is Button)[0]
			person.pressed.emit()
			await settle()
			check(app.selected_player == str(target.id), "Sélection exacte par ID")
			check(str(app.find_child("PlayerDossier", true, false).get_meta("player_id", "")) == str(target.id), "Dossier actualisé sans changer la carrière")
			search.text = ""
			search.text_changed.emit("")
			await settle()
			check(list.get_children().filter(func(node:Node):return node is Button).size() == mini(24,app.model.squad.size()), "Effacer la recherche retrouve le groupe paginé")
			await capture("02-effectif-2560x1440")
			app.find_child("OpenPlayerFull",true,false).pressed.emit()
			await settle()
			var full:Control=app.find_child("ImmersivePlayerFull",true,false)
			check(full!=null,"La fiche complète est une vraie page, pas un bouton inerte")
			if full!=null:
				check(app.find_child("ProfilePlayerName",true,false).text.to_lower()==str(target.name).to_lower(),"Identité exacte dans la fiche complète")
				for attribute in target.get("attributes",{}):
					check(app.find_child("PlayerAttribute_"+attribute,true,false)!=null,"Aptitude réelle dans la fiche : "+attribute)
				check(app.find_child("OpenPlayerCoachNote",true,false)!=null,"Carnet personnel conservé sur la fiche")
				await capture("04-fiche-joueur-2560x1440")
				app.find_child("PlayerBackToSquad",true,false).pressed.emit()
				await settle()
				check(app.find_child("ImmersiveRosterTable",true,false)!=null,"Retour au tableau sans perdre le joueur")
			else:app.set_meta("immersive08_full_player",false)
		app._navigate("Composition")
		await settle()
		var tactics: Control = app.find_child("ImmersiveTactics",true,false)
		check(tactics != null,"Tactique native du gabarit approuvé")
		if tactics != null:
			for slot in 23:
				var jersey: Button = app.find_child("LineupSlot%02d" % (slot+1),true,false)
				check(jersey != null,"Poste réel disponible : "+str(slot+1))
			check(app.find_child("Art_tactics_briefing",true,false)!=null,"Image approuvée du briefing intégrée")
			check(app.find_child("TacticsIdentity",true,false)!=null,"Consignes et indicateurs du XV sélectionné")
			await capture("03-tactique-2560x1440")
		for pair in [["OfficePreparationAction", "Préparation"], ["OfficeSquadAction", "Effectif"], ["OfficeStandingsAction", "Classements"], ["OfficeCalendarAction", "Calendrier"]]:
			app._navigate("Bureau")
			shell.render(app)
			await settle()
			var action: Button = app.find_child(pair[0], true, false)
			check(action != null, "Action réelle : " + pair[0])
			if action != null:
				action.pressed.emit()
				await settle()
				check(app.route == pair[1], "Navigation : " + pair[0])
		await command("export")
		check(before == app.model.meta.exportText, "Rendu et navigation préservent état et RNG")
		check(bytes == FileAccess.get_file_as_bytes(disk), "Rendu et navigation ne modifient aucun octet du profil")
		app._navigate("Composition")
		await settle()
		var original_defense:String=app.model.tactics.defense
		var attack:Button=app.find_child("TacticsAttack_occupation",true,false)
		attack.pressed.emit()
		await worker()
		check(app.bridge.last_response_ok and app.model.tactics.attack=="occupation","Le bouton d’attaque commande réellement le moteur")
		check(app.model.tactics.defense==original_defense,"Changer l’attaque conserve la défense")
		app.find_child("TacticsSummary1",true,false).pressed.emit()
		await settle()
		var pressure:Button=app.find_child("TacticsDefense_pression",true,false)
		check(pressure!=null,"Sous-menu défensif fonctionnel")
		if pressure!=null:pressure.pressed.emit();await worker()
		check(app.bridge.last_response_ok and app.model.tactics.defense=="pression" and app.model.tactics.attack=="occupation","Consigne défensive enregistrée sans écraser l’attaque")
		app.find_child("LineupSlot01",true,false).pressed.emit()
		await settle()
		check(app.find_child("LineupCandidates",true,false)!=null,"Le maillot ouvre les choix du poste")
		var eligibility:Array=app.model.selection.slots[0].eligibleIds
		var chosen:String=""
		for candidate:Button in app.find_child("LineupCandidatesList",true,false).get_children():
			var player_id:String=candidate.get_meta("player_id")
			check(candidate.disabled==(player_id not in eligibility),"Qualifications réelles conservées : "+player_id)
			if chosen.is_empty() and not candidate.disabled and player_id!=str(app.model.selection.slots[0].playerId):chosen=player_id
		check(not chosen.is_empty(),"Autre joueur qualifié disponible dans la fixture")
		if not chosen.is_empty():
			app.find_child("LineupPlayer"+chosen.replace(":","_"),true,false).pressed.emit()
			await worker()
			check(app.bridge.last_response_ok and str(app.model.selection.slots[0].playerId)==chosen,"Affectation réelle du joueur qualifié")
			app.find_child("TacticsChoosePlayer",true,false).pressed.emit()
			await settle()
			var recovery:Button=app.find_child("IndividualLoad_repos",true,false)
			check(recovery!=null,"Sous-menu de consignes individuelles illustré")
			if recovery!=null:recovery.pressed.emit();await worker()
			var person:Dictionary=app.model.squad.filter(func(player:Dictionary):return str(player.id)==chosen)[0]
			check(app.bridge.last_response_ok and person.loadPlan=="repos","Charge individuelle enregistrée dans la partie")
		await command("save")
		await command("export")
		var saved:String=app.model.meta.exportText
		app.queue_free()
		await settle()
		app=load("res://main.tscn").instantiate()
		root.add_child(app)
		await worker()
		await command("export")
		check(saved==app.model.meta.exportText,"Reprise native : choix tactiques, composition et charge exactement conservés")
	app.queue_free()
	await settle()
	print("immersive08 : ", checks, " contrôles, ", failures.size(), " échecs")
	quit(0 if failures.is_empty() else 1)
