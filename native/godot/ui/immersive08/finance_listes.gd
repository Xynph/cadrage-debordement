extends RefCounted
## Finances : onglets Salaires, Transferts et Classement des clubs.
const FocusLater = preload("res://ui/focus_later.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Link = preload("res://ui/entity_link.gd")
const G = preload("res://ui/game_skin.gd")
const Health = preload("res://ui/immersive08/finance_health.gd")
const Charte = preload("res://ui/charte.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const F = preload("res://ui/immersive08/finance_canvas.gd")
const Brique = preload("res://ui/immersive08/finance_briques.gd")
const Journal = preload("res://ui/immersive08/finance_journal.gd")

static func _wage_sort(app: Control, key: String) -> void:
	var due_only: bool = app.management_ui.get(F.WAGES_SCOPE_KEY,false)
	var state: Dictionary = app.management_ui.get("finance_wage_sort",{"key":"contractEnd" if due_only else "salary","descending":not due_only})
	app.management_ui.finance_wage_sort = {"key":key,"descending":not bool(state.get("descending",false)) if state.get("key") == key else key == "salary"}
	app.management_ui["finance_wage_scroll"] = 0
	app._render()
	var button := app.find_child("FinanceSort_"+key,true,false)
	if button != null: FocusLater.grab(button)

static func _wages(app: Control, canvas: Control, zone: Rect2, finance: Dictionary) -> void:
	var largeur := zone.size.x
	var wages := Brique._panneau(canvas, Rect2(zone.position.x, zone.position.y, largeur, zone.size.y), "Contrats et salaires", "FinanceSalaryTable")
	var all_players: Array = app.model.get("squad", [])
	var due_only: bool = app.management_ui.get(F.WAGES_SCOPE_KEY, false)
	var squad := P.contracts(app.model) if due_only else all_players.duplicate()
	if due_only:
		var horizon := int(app.model.meta.get("season", 1)) + 1
		var fin_saison: int = P.contract_counts(app.model).end_of_season
		var horizon_texte := "Jusqu’à la fin de %s" % G.season_label(horizon)
		var largeur_echeances := Pieces.pastille(wages, 380, 10, P.plural(squad.size(), "échéance", "échéances"), "calendar", "FinanceWagesScope", horizon_texte, Pieces.BLEU, Charte.PANNEAU_3, func(): F._vers_contrats(app))
		Pieces.pastille(wages, 380 + largeur_echeances + 8, 10, "%d en fin de saison" % fin_saison, "", "FinanceWagesSeasonEnd", "", Pieces.ORANGE, Charte.PANNEAU_3, func(): F._vers_contrats(app))
		Brique._bouton(wages, Rect2(largeur - 330, 10, 310, 36), "Tous les %d joueurs" % all_players.size(), func(): F._open_wages(app, false), "lien", "arrow", "FinanceWagesAll")
	else:
		var texte_joueurs := P.plural(squad.size(), "joueur", "joueurs")
		Pieces.pastille(wages, largeur - 20 - Pieces.largeur_pastille(texte_joueurs, "people"), 10, texte_joueurs, "people", "FinanceWagesCount", "", Pieces.BLEU, Charte.PANNEAU_3, func(): app._navigate("Effectif"))
	var sort_state: Dictionary = app.management_ui.get("finance_wage_sort", {"key":"contractEnd" if due_only else "salary", "descending":not due_only})
	squad = F.wage_rows(squad,str(sort_state.key),bool(sort_state.descending))
	Brique._bloc(wages, Rect2(12, 62, largeur - 24, 38), Charte.PANNEAU_2)
	var colonnes := [["JOUEUR",25,"name",520],["POSTE",575,"pos",250],["FIN DE CONTRAT",850,"contractEnd",260],[G.salary_period().to_upper(),1130,"salary",230]]
	for item: Array in colonnes:
		var arrow := (" ▼" if sort_state.descending else " ▲") if sort_state.key == item[2] else " ↕"
		var tri := Brique._bouton(wages, Rect2(item[1]-4, 63, item[3], 36), str(item[0])+arrow, _wage_sort.bind(app,str(item[2])), "lien", "", "FinanceSort_"+str(item[2]))
		tri.alignment = HORIZONTAL_ALIGNMENT_RIGHT if item[2] == "salary" else HORIZONTAL_ALIGNMENT_LEFT
	var scroll := ScrollContainer.new()
	scroll.name = "FinanceWageScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_force_pass_scroll_events = false
	wages.add_child(scroll)
	D.place(scroll,Rect2(12,104,largeur - 24,zone.size.y - 120))
	var rows := Control.new()
	rows.name = "FinanceWageRows"
	rows.custom_minimum_size = Vector2(C.px(largeur - 50),C.px(maxi(1,squad.size())*34))
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(rows)
	scroll.set_deferred("scroll_vertical",int(app.management_ui.get("finance_wage_scroll",0)))
	scroll.get_v_scroll_bar().value_changed.connect(func(value): app.management_ui["finance_wage_scroll"] = int(value))
	for i in squad.size():
		var player: Dictionary = squad[i]
		var y := i*34
		Brique._zone(rows, Rect2(0,y,largeur - 50,33), func(): _open_player(app, str(player.id)), "FinanceWageRow_"+str(player.id).validate_node_name(), "Consulter le contrat · " + str(player.get("name","")), true)
		var name_link := Brique._bouton(rows, Rect2(21,y+1,520,31), str(player.get("name","—")), func(): pass, "lien", "", "FinancePlayerName_"+str(player.id).validate_node_name())
		name_link.alignment = HORIZONTAL_ALIGNMENT_LEFT
		Link.bind(name_link,app,{"kind":"player","id":str(player.id),"section":"contract"},"Consulter le contrat · " + str(player.get("name","")))
		MiniFiche.lier(app, name_link, str(player.id), "squad")
		D.text(rows, 575, y + 23, player.get("pos","—"), 18, Charte.IVOIRE_2, 500, 250, HORIZONTAL_ALIGNMENT_LEFT, true)
		D.text(rows, 850, y + 23, G.contract_year(player.get("contractEnd")), 18, Charte.IVOIRE_2, 500, 260, HORIZONTAL_ALIGNMENT_LEFT, true)
		D.text(rows, 1330, y + 23, G.salary_amount(player.get("salary",0)), 18, Charte.IVOIRE, 700, 200, HORIZONTAL_ALIGNMENT_RIGHT)
		Brique._bouton(rows, Rect2(1356,y+1,200,31), "Voir le contrat", func(): _open_player(app, str(player.id)), "lien", "arrow", "FinancePlayer_"+str(player.id).replace(":","_"))
	if squad.is_empty():
		var empty := "Aucun contrat à anticiper d’ici cette échéance." if due_only else "Aucun joueur sous contrat dans cette carrière."
		Brique._titre(wages, 24, 153, empty, 28, Charte.IVOIRE_2, largeur - 48)

static func _open_player(app: Control, player_id: String) -> void:
	app.navigation_controller.open_entity({"kind":"player","id":player_id,"section":"contract"})

static func _transfers(app: Control, canvas: Control, zone: Rect2, ledger: Array) -> void:
	var contracts := ledger.filter(func(entry: Dictionary): return Journal._category(str(entry.get("title","")))[0] == "Contrat")
	var gauche := 1070.0
	var x := zone.position.x
	Journal._ledger(Brique._panneau(canvas, Rect2(x, zone.position.y, gauche, zone.size.y), "Mouvements de contrats et transferts", "FinanceTransferLedger"), app, contracts, 20, "transfers", gauche)
	var card := Brique._panneau(canvas, Rect2(x + gauche + 16, zone.position.y, zone.size.x - gauche - 16, zone.size.y), "Préparer le recrutement", "FinanceTransferActions")
	var largeur := zone.size.x - gauche - 16
	var market: Array = app.model.get("market",[])
	Brique._titre(card, 23, 132, "%d profils au marché" % market.size(), 40, Charte.IVOIRE, largeur - 46)
	Brique._bouton(card, Rect2(23, 196, largeur - 46, 50), "OUVRIR LE RECRUTEMENT", func(): app._navigate("Recrutement"), "ivoire", "arrow", "FinanceRecruitment")
	D.line(card, Vector2(23, 280), Vector2(largeur - 23, 280), Charte.FILET)
	Brique._titre(card, 23, 336, "Contrats du groupe", 34, Charte.IVOIRE, largeur - 46)
	Brique._bouton(card, Rect2(23, 394, largeur - 46, 44), "Consulter les salaires et les échéances", func(): F._open_wages(app, false), "lien", "arrow", "FinanceTransferContracts")

# Classement financier du championnat (native/engine/club-finance-health.cjs) : du club le plus solide au plus fragile,
# avec l’étiquette, le propriétaire et la courbe des trois dernières saisons. Aucun montant : un club ne publie pas sa caisse.
static func _clubs(app: Control, canvas: Control, zone: Rect2, accounts: Dictionary) -> void:
	var clubs: Array = accounts.get("clubs", [])
	var largeur := zone.size.x
	var panel := Brique._panneau(canvas, Rect2(zone.position.x, zone.position.y, largeur, zone.size.y), "Santé financière des clubs · %s" % P.league_name(app.model), "FinanceClubsHealth")
	if clubs.is_empty():
		Brique._titre(panel, 25, 140, "Les comptes des clubs ne sont pas encore connus.", 28, Charte.IVOIRE_2, largeur - 50)
		return
	# Sans saison close, la même phrase sur chaque ligne n'apprend rien : elle est dite une fois, ici.
	var sans_courbe := clubs.all(func(club: Dictionary): return not (club.get("courbe") is Array) or (club.courbe as Array).is_empty())
	Brique._info_titre(panel, "Santé financière des clubs · %s" % P.league_name(app.model), "Du plus solide au plus fragile, d’après la trésorerie de chaque club rapportée à la réserve qu’il se fixe.", "FinanceClubsInfo")
	var head := [["#",25,60],["Club",95,440],["Santé",560,170],["Propriétaire",760,300],["Trois dernières saisons" + (" · à venir" if sans_courbe else ""),1090,480]]
	for h: Array in head: D.text(panel, h[1], 126, h[0], 15, Charte.IVOIRE_2, 600, h[2])
	var row_height := minf(38.0, (zone.size.y - 150.0) / maxf(1.0, clubs.size()))
	for i in clubs.size():
		var club: Dictionary = clubs[i]
		var y := 140.0 + i * row_height
		var own := bool(club.get("own", false))
		if own:
			# Ton club : fond relevé + liseré ivoire à gauche (pas de cadre complet), et « · ton club » écrit.
			Brique._bloc(panel, Rect2(14, y + 1, largeur - 28, row_height - 2), Charte.PANNEAU_3)
			Brique._bloc(panel, Rect2(14, y + 1, 5, row_height - 2), Charte.IVOIRE)
		else: Brique._rayer(panel, Rect2(14, y + 1, largeur - 28, row_height - 2), i)
		var base := y + row_height * .72
		D.text(panel, 25, base, str(i + 1), 20, Charte.IVOIRE_2, 600, 60)
		var caption := G.club_name(club) + ("  · ton club" if own else "")
		Link.name_link(app, panel, Rect2(95, y + 3, 440, row_height - 6), "club", str(int(club.get("id", -1))), caption, 21, Charte.IVOIRE, "FinanceClubName" + str(i))
		# Santé : liseré teinté + mot (charte : ni pastille arrondie ni cadre complet, la couleur jamais seule).
		var sante := Control.new()
		sante.name = "FinanceClubHealth" + str(i)
		sante.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(sante)
		D.place(sante, Rect2(560, y + (row_height - 32) * .5, 180, 32))
		Brique._bloc(sante, Rect2(0, 5, 8, 22), Health.color(club))
		D.text(sante, 20, 24, Health.label(club), 20, Charte.IVOIRE, 700, 160).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(panel, 760, base, Health.owner(club), 20, Charte.IVOIRE, 500, 300)
		Health.sparkline(panel, Rect2(1090, y + 3, 120, row_height - 6), club, "FinanceClubCurve" + str(i))
		if not sans_courbe: D.text(panel, 1230, base, Health.reading(club), 17, Charte.IVOIRE_2, 500, largeur - 1250)
