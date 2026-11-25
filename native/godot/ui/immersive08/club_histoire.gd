extends "res://ui/immersive08/club_staff.gd"
## Écran Club, onglets Histoire, Territoire et Infrastructures : mémoire du club, monde, projets du président.

static func _history(app: Control, canvas: Control) -> void:
	var card := D.panel(canvas, Rect2(0,214,610,612), "Les archives du club", "trophy", "", "ClubHistorySummary")
	D.photo(card, "ceremonie-remise-trophee" if BanqueImages.existe("ceremonie-remise-trophee") else "club-forest", Rect2(20,69,570,164))
	var data := History.project(app.model,int(app.model.club.id))
	var international: bool = app.model.meta.get("mode") == "world"
	if international: data.seasons = History.world_seasons(app,int(app.model.club.id))
	var titles := 0
	for year: Dictionary in data.seasons: titles += year.get("titles",[]).size()
	var rows := [["Saisons archivées",data.seasons.size()],["Titres conservés",titles],["Derniers résultats",data.events.size()]]
	var palmares: Dictionary = app.model.get("club",{}).get("palmares",{}) if international else {}
	if not palmares.is_empty():
		# Palmarès connu dès le premier jour, fusionné aux saisons jouées en carrière.
		rows = [["Titres au palmarès",Palmares.count_text(int(palmares.get("totalTitles",0)))],["Finales connues",Palmares.count_text(palmares.get("finals",[]).size())],["Saisons jouées avec toi",Palmares.count_text(int(palmares.get("careerSeasons",0)))]]
	# Vitrine : quelques trophées de la banque d'images posés sur la photo quand le club a des titres.
	var nb_titres := int(palmares.get("totalTitles", titles)) if not palmares.is_empty() else titles
	var vitrine := ["trophee-coupe-haute", "trophee-bouclier-bois-argent", "trophee-coupe-anses", "trophee-plaque-or"]
	for t in mini(nb_titres, vitrine.size()):
		if BanqueImages.existe(vitrine[t]):
			var coupe := D.photo(card, vitrine[t], Rect2(470 - t * 104, 129, 112, 112), 0.0)
			coupe.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			coupe.name = "ClubHistoryTrophy%d" % t
	for i in rows.size():
		var y := 278+i*73
		D.text(card, 24, y, rows[i][0], 29, C.IVORY, 600, 475)
		D.text(card, 586, y, rows[i][1], 35, C.MINT, 700, 118, HORIZONTAL_ALIGNMENT_RIGHT)
		D.line(card, Vector2(24,y+18), Vector2(586,y+18), Color(C.LINE,.6))
	_lien(card, Rect2(24,520,0,40), "Ouvrir les compétitions →", func(): app._navigate("Classements"), "ClubHistoryCompetitions")
	if international: _world_history(app,canvas,data)
	else: U.place_detail(canvas, Rect2(626,214,1622,1030), History.build(app))

static func _world_history(app: Control, canvas: Control, data: Dictionary) -> void:
	var card := D.panel(canvas,Rect2(626,214,1622,1030),"L’histoire de "+str(data.club_name),"trophy","","CarnetClubMemory")
	var scroll := ScrollContainer.new()
	scroll.name = "ClubMemoryScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	card.add_child(scroll)
	D.place(scroll,Rect2(22,69,1578,939))
	var list := C.v(15)
	C.fill(list)
	scroll.add_child(list)
	var years: Array = data.seasons
	# Revue du 21/11/2026, n° 8 (option B choisie par Léo) : frise des saisons et statistiques en barres.
	var analyse := C.v(15)
	analyse.name = "PerformanceAnalysis"
	C.fill(analyse)
	list.add_child(analyse)
	analyse.add_child(HistoireVisuels.build(app, years))
	if years.size() >= 2:
		analyse.add_child(C.rule())
		_world_comparison(app, analyse, years)
	var individuel := C.v(9)
	preload("res://ui/performance_analysis_view.gd")._individual(app, individuel)
	Legacy.apply(individuel, app.accent)
	analyse.add_child(individuel)
	list.add_child(C.rule())
	_world_coach(list, data)

static func _world_coach(list: VBoxContainer, data: Dictionary) -> void:
	list.add_child(C.label("LE PARCOURS DU COACH",27,C.GOLD,true,700))
	if data.manager_current_from != null: list.add_child(C.label("Mandat actuel depuis la saison "+G.season_label(data.manager_current_from),24))
	if data.manager_history.is_empty(): list.add_child(Pastilles.pastille("Aucune prise de poste", Charte.IVOIRE_2, "check", "Aucune prise de poste antérieure enregistrée.", 20, "ClubHistoryNoMove"))
	for move: Dictionary in data.manager_history:
		list.add_child(C.wrap("Saison %s · %s  →  %s" % [G.season_label(move.get("arrivalSeason","—")),move.from_name,move.to_name],23,C.IVORY,true))

static func _world_year(app: Control, year: Dictionary) -> PanelContainer:
	var card := C.card("Saison "+G.season_label(year.season))
	C.fill(card)
	var content := C.content(card)
	var rank := "%s · rang %s / %s" % [World.name_for(app.model,str(year.league_id)),G.n(year.rank),G.n(year.division_size)] if year.rank != null else "Rang de phase régulière indisponible"
	content.add_child(C.wrap(rank,25,C.IVORY,true,600))
	for id: String in year.titles:
		content.add_child(C.wrap("Champion · "+World.name_for(app.model,id),23,C.MINT,true,600))
	for line: String in World.movement_lines(app.model,str(year.league_id),bool(year.promoted),false): content.add_child(C.label(line,22,C.MINT))
	for line: String in World.movement_lines(app.model,str(year.league_id),false,bool(year.relegated)): content.add_child(C.label(line,22,C.AMBER))
	for line: String in year.get("nationale_lines",[]): content.add_child(C.wrap(line,22,C.IVORY))
	for barrage: Dictionary in year.japan_barrages:
		for line: String in World.japan_lines(app,barrage): content.add_child(C.wrap(line,22,C.IVORY))
	return card

static func _world_comparison(app: Control, list: VBoxContainer, years: Array) -> void:
	var panel := C.card("Comparer deux saisons")
	list.add_child(panel)
	var contents := C.content(panel)
	var selectors := C.h(16)
	var comparison := C.h(16)
	contents.add_child(selectors)
	contents.add_child(comparison)
	var indexes := [0,1]
	var redraw := func():
		for child in comparison.get_children():
			comparison.remove_child(child)
			child.queue_free()
		for index: int in indexes: comparison.add_child(_world_year(app,years[index]))
	for i in 2:
		var key := "club_memory_season_a" if i == 0 else "club_memory_season_b"
		var selector := OptionButton.new()
		selector.name = "ClubMemorySeasonA" if i == 0 else "ClubMemorySeasonB"
		selector.custom_minimum_size.y = C.px(40)
		C.fill(selector)
		var chosen := int(app.management_ui.get(key,years[i].season))
		for year: Dictionary in years:
			selector.add_item("Saison "+G.season_label(year.season),int(year.season))
			if int(year.season) == chosen: indexes[i] = selector.item_count-1
		selector.select(indexes[i])
		selectors.add_child(selector)
		selector.item_selected.connect(func(index: int):
			indexes[i] = index
			app.management_ui[key] = int(years[index].season)
			redraw.call())
	redraw.call()

static func _territory(app: Control, canvas: Control) -> void:
	var page := Control.new()
	page.name = "ClubTerritory"
	canvas.add_child(page)
	D.place(page, Rect2(0,214,2248,1030))
	var identity := G.identity(app.model.club)
	var city_picture := ClubViews.territory_city_picture(app.model.club, false)
	var stadium_width := 1480 if city_picture == null else 1116
	for i in 2:
		var kind := "stadium" if i == 0 else "city"
		var x := 0 if i == 0 else stadium_width + 16
		var width := stadium_width if i == 0 else 2248 - x
		var panel := D.panel(page, Rect2(x,0,width,821), "Le stade" if i == 0 else "Le territoire", "home")
		var picture := G.club_picture(app.model.club, kind, false) if i == 0 else city_picture
		if picture == null:
			D.text(panel, 24, 120, "Ville non renseignée", 43, C.IVORY, 700, width - 52)
			continue
		panel.add_child(picture)
		D.place(picture, Rect2(16,68,width - 32,642))
		var from_pack: bool = picture.get_meta("photo_kind") == "pack"
		D.text(panel, 24, 760, identity.get("stadium",app.model.club.get("stadium","Le stade")) if i == 0 else identity.get("city","Le territoire"), 43, C.IVORY, 700, width - 52)
		var photo: Dictionary = identity.get("photos", {}).get(kind, {})
		var credit := D.text(panel, 24, 798, "Photo · " + str(photo.get("credit", "")) if from_pack else _venue_caption(picture), 23, C.MUTED, 500, width - 52)
		if from_pack:
			credit.name = "VenuePhotoCredit_" + kind
			_venue_credit(credit, photo)
	var links := D.panel(page, Rect2(0,837,2248,193), "Un territoire, une identité", "shield")
	_lien(links, Rect2(1415,86,0,40), "Crédits et licences →", app._credits, "ClubAtlasCredits")
	Kit.bouton_ivoire(links, Rect2(1804,80,420,52), "Revenir à la vue d’ensemble", func(): _tab(app, "overview", "ClubTab_overview"), "ClubAtlasBack")

# Excédents réinvestis par le président (carrière Monde) : où en sont les travaux, l'accueil du stade et le staff.
# Colonne de droite du panneau « Les moyens du club », à côté du devis du manager ; rien sans excédent cette saison.
static func _president_projects(projects: Panel, inv: Variant) -> void:
	if not inv is Dictionary: return
	var box := Control.new()
	box.name = "ClubPresidentProjects"
	box.position = Vector2(800, 74) * C.density
	box.size = Vector2(474, 214) * C.density
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	projects.add_child(box)
	var inst: Dictionary = inv.get("installations", {})
	var acc: Dictionary = inv.get("accueil", {})
	var staff: Dictionary = inv.get("staff", {})
	D.text(box, 0, 28, "Excédents réinvestis · " + G.euros(inv.get("montant", 0)), 26, Charte.IVOIRE, 700, 474)
	var travaux := "Installations au maximum"
	if inst.get("devis") != null:
		travaux = "Travaux du niveau %s · %s %% financés" % [G.n(int(inst.get("niveau", 0)) + 1), G.n(roundi(100.0 * float(inst.get("avancement", 0))))]
	if int(inst.get("achevesCetteSaison", 0)) > 0:
		var faits := int(inst.get("achevesCetteSaison", 0))
		travaux += " · %s achevé%s" % [G.n(faits), "s" if faits > 1 else ""]
	D.text(box, 0, 64, travaux, 23, C.IVORY, 600, 474)
	D.rect(box, Rect2(0, 75, 474, 10), Charte.PANNEAU_3, 0)
	D.rect(box, Rect2(0, 75, 474.0 * clampf(float(inst.get("avancement", 0)), 0.0, 1.0), 10), Charte.IVOIRE_2, 0)
	var accueil := "Accueil du stade · niveau %s / %s" % [G.n(acc.get("niveau", 0)), G.n(acc.get("max", 5))]
	if float(acc.get("effet", 0)) > 0.0: accueil += " · guichet +%s %%" % ("%.1f" % (100.0 * float(acc.get("effet", 0)))).replace(".", ",")
	if acc.get("degrade", false) == true: accueil += " · en recul"
	D.text(box, 0, 114, accueil, 23, C.IVORY, 600, 474)
	for segment in int(acc.get("max", 5)):
		D.rect(box, Rect2(segment * 96, 125, 90, 10), Charte.IVOIRE_2 if segment < int(acc.get("niveau", 0)) else Charte.PANNEAU_3, 0)
	var points := int(staff.get("points", 0))
	var staff_txt := "Staff · aucune progression pour l’instant" if points == 0 else "Staff · %s point%s gagné%s par %s membre%s" % [G.n(points), "s" if points > 1 else "", "s" if points > 1 else "", G.n(staff.get("personnes", 0)), "s" if int(staff.get("personnes", 0)) > 1 else ""]
	D.text(box, 0, 164, staff_txt, 23, C.IVORY, 600, 474)
	D.text(box, 0, 194, "Dépensé : %s sur %s" % [G.euros(inv.get("depense", 0)), G.euros(inv.get("montant", 0))], 20, C.MUTED, 500, 474)

static func _infrastructure_detail(app: Control, corps: Control) -> void:
	var data := U.strategy(app.model)
	var finance: Dictionary = data.get("finance", {})
	_installations(_panneau(corps, Rect2(0, 214, 1404, 302), "Installations", "ClubFacilities"), app, finance, data)
	_stade(_panneau(corps, Rect2(1426, 214, W - 1426, 302), "Le stade", "ClubStadiumCard"), app, data.get("fans", {}))
	var projects := _panneau(corps, Rect2(0, 532, W, 640), "Les moyens du club", "ClubFacilityProjects", true)
	var quote: Variant = finance.get("facility")
	if quote is Dictionary:
		Kit.texte(projects, 24, 104, "Installations du club · niveau %s / 10" % G.n(quote.level), Charte.IVOIRE, 740, 26).add_theme_font_override("font", Kit.texte_gras())
		var tuile_niveau := Pastilles.tuile(Pastilles.euros_courts(quote.cost), "niveau %s" % G.n(quote.nextLevel), Pastilles.BLEU, Charte.PANNEAU_2, 26, "ClubFacilityNextLevel", true, func(): app._navigate("Finances"))
		Pastilles.poser(projects, tuile_niveau, 24, 108)
		var action := Kit.bouton_ivoire(projects, Rect2(24, 158, 300, 46), "Examiner le devis", func(): Strategy._send(app, "club_facility_upgrade", {"cost": quote.cost, "level": quote.level}, "Investir %s pour passer les installations au niveau %s ?" % [G.euros(quote.cost), G.n(quote.nextLevel)]), "ClubFacilityQuote")
		action.disabled = not data.get("available", false) or app.waiting or app.model.meta.get("trained", false) or app.model.meta.get("phase", "") != "league" or quote.used or not quote.affordable
		var reason := Pastilles.pastille("1 par saison", Charte.IVOIRE_2, "calendar", "Un investissement par saison, avant la séance de la semaine.", 18, "ClubFacilityReason")
		if quote.used: reason = Pastilles.pastille("Déjà engagée cette saison", Charte.IVOIRE_2, "check", "Une amélioration a déjà été engagée cette saison.", 18, "ClubFacilityReason")
		elif not quote.affordable: reason = Pastilles.pastille("Trésorerie insuffisante", Pastilles.ORANGE, "warning", "La trésorerie disponible est insuffisante pour ce devis.", 18, "ClubFacilityReason", func(): app._navigate("Finances"))
		Pastilles.poser(projects, reason, 24, 214)
	else: Pastilles.poser(projects, Pastilles.pastille("Aucun devis", Charte.IVOIRE_2, "warning", "Aucun devis d’installations disponible.", 18, "ClubFacilityNoQuote"), 24, 90)
	_president_projects(projects, finance.get("investissements"))
	D.line(projects, Vector2(24, 262), Vector2(W - 24, 262), Charte.FILET)
	Kit.texte(projects, 24, 304, "Centre de formation", Charte.IVOIRE, 740, 26).add_theme_font_override("font", Kit.texte_gras())
	Pastilles.poser(projects, Pastilles.info("L’investissement hebdomadaire suit la séance de formation.", "i", "ClubAcademyInfo"), 24 + Kit.largeur("Centre de formation", 26) + 14, 282)
	_lien(projects, Rect2(24, 352, 0, 34), "Ouvrir le centre de formation →", func(): app._navigate("Centre"), "ClubAcademyFacilities")
	D.line(projects, Vector2(24, 400), Vector2(W - 24, 400), Charte.FILET)
	var photo := D.photo(projects, "club-salle-recuperation-bains" if BanqueImages.existe("club-salle-recuperation-bains") else "medical-recovery", Rect2(1300, 290, 880, 320), .4)
	photo.modulate = Color(1, 1, 1, .4)
	Kit.texte(projects, 24, 442, "Cellule médicale", Charte.IVOIRE, 740, 26).add_theme_font_override("font", Kit.texte_gras())
	Pastilles.poser(projects, Pastilles.info("Protocoles et décisions de retour des joueurs suivis.", "i", "ClubMedicalInfo"), 24 + Kit.largeur("Cellule médicale", 26) + 14, 420)
	_lien(projects, Rect2(24, 490, 0, 34), "Ouvrir le travail du club →", func(): app._navigate("Travail du club"), "ClubFacilityMedical")
	_lien(projects, Rect2(24, 570, 0, 34), "Décisions d’investissement →", func(): _open_strategy(app, 0), "ClubFacilityStrategy")
