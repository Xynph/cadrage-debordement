extends "res://ui/immersive08/recruitment_socle.gd"
## Écran Recrutement : titre et budget, tuiles de transferts, besoins du club, onglets et sources (découpe de recruitment_canvas.gd, sans changement).

# --- En-tête, budget, besoins -----------------------------------------------------------------------------------

## Même geste que les onglets : passe à « Recherche » (1), « Joueurs suivis » (2)…
func _ouvrir_onglet(index: int) -> void:
	state.immersive_tab = index
	state.navigation_id = ""
	state.followed = index == 2
	state.page = 0
	state.focus = "MarketSearch" if index == 1 else "MarketFollowed" if index == 2 else "MarketTab" + str(index)
	app._render(false)

func _vers_finances(onglet: String) -> void:
	app.navigation_controller.open_entity({"kind":"finance", "id":onglet})

func _header() -> void:
	var titre := Kit.titre_page(self, 0, 44, "Recrutement", 38, 700)
	titre.name = "RecruitmentTitle"
	# Calendrier du recrutement (calendrier-mutations.cjs, model.mutations) : période des joueurs sans club en pastille
	# (icône + « Ouvert · 31 déc. ») ; la raison et la période des mutations restent dans l'infobulle.
	var calendrier: Dictionary = app.model.get("mutations", {}) if app.model.get("mutations") is Dictionary else {}
	if calendrier.get("available", false):
		var libres: Dictionary = calendrier.get("freeAgents", {}) if calendrier.get("freeAgents") is Dictionary else {}
		var ouvert: bool = libres.get("open", true)
		Pieces.pastille(self, 0, 58, fenetre_courte(str(calendrier.get("summary", ""))), "check" if ouvert else "clock", "RecruitmentWindow", str(calendrier.get("detail", "")), Pieces.VERT if ouvert else Pieces.ROUGE, Charte.PANNEAU_3, func(): _ouvrir_onglet(1))

const MOIS_COURTS := {"janvier": "janv.", "février": "févr.", "mars": "mars", "avril": "avr.", "mai": "mai", "juin": "juin", "juillet": "juil.", "août": "août", "septembre": "sept.", "octobre": "oct.", "novembre": "nov.", "décembre": "déc."}

## « Joueurs libres : ouvert jusqu’au 31 décembre » → « Ouvert · 31 déc. » ; « Joueurs supplémentaires : 2 sur 3 » → « Supplémentaires · 2/3 ».
static func fenetre_courte(resume: String) -> String:
	var lecture := RegEx.create_from_string("^Joueurs libres : (ouvert|fermé) jusqu[’'](?:au|à) (\\S+) (\\S+)$").search(resume)
	if lecture != null:
		var mois := lecture.get_string(3)
		return "%s · %s %s" % [lecture.get_string(1).capitalize(), lecture.get_string(2), MOIS_COURTS.get(mois, mois)]
	var supp := RegEx.create_from_string("^Joueurs supplémentaires : (\\d+) sur (\\d+)$").search(resume)
	if supp != null: return "Supplémentaires · %s/%s" % [supp.get_string(1), supp.get_string(2)]
	return resume


## Tuiles du budget de transferts (finance.transferBudget) : alloué, engagé, restant (« après l'offre » si une piste est
## choisie). Absent ou inactif : la trésorerie du club reste la seule référence. Clic = Finances.
func _tuiles() -> void:
	for enfant in tiles.get_children():
		tiles.remove_child(enfant)
		enfant.queue_free()
	var budget := Budget.data(app.model)
	var cash: Variant = app.model.get("finance", {}).get("cash")
	var fee: Variant = _selected.get("fee") if not _selected.is_empty() and tab != 3 else null
	if budget.is_empty():
		_tuile(1700, 380, "Trésorerie du club", G.euros(cash) if cash is int or cash is float else "—", "", "RecruitmentTransferBudget", true, "Trésorerie du club")
	else:
		var total := Budget.season_total(budget)
		var depense := int(budget.get("depense", 0))
		var part := roundi(100.0 * depense / total) if total > 0 else 0
		var alloue := _tuile(1130, 292, "Budget alloué", G.euros(total), "", "RecruitmentBudgetAllocated", false, "")
		alloue.tooltip_text = Budget.allocated(budget)
		# Part engagée : une barre sous le montant (le pourcentage est dit au survol).
		var engage := _tuile(1430, 262, "Engagé", G.euros(depense), "", "RecruitmentBudgetSpent", false, "")
		var barre := D.rect(engage, Rect2(16, 98, 262 - 32, 8), Charte.PANNEAU_3, Charte.RAYON_PILULE)
		barre.name = "RecruitmentBudgetShare"
		if part > 0: D.rect(barre, Rect2(0, 0, maxf(8.0, (262 - 32) * clampf(float(part) / 100.0, 0, 1)), 8), Charte.IVOIRE_2, Charte.RAYON_PILULE)
		engage.tooltip_text = "%d %% du budget" % part
		var apres := Budget.LABEL
		if fee is int or fee is float: apres = "%s après l’offre" % G.euros(int(budget.get("disponible", 0)) - int(fee))
		var restant := _tuile(1700, 380, "Restant", Budget.remaining(budget), apres, "RecruitmentTransferBudget", true, Budget.LABEL)
		restant.tooltip_text = Budget.detail(budget, cash)
	var finances := Kit.lien(tiles, Rect2(2248, 100, 0, 36), "Finances →", func(): app.navigation_controller.open_entity({"kind":"finance", "id":"summary"}), "RecruitmentFinances", 19, true)
	finances.tooltip_text = ""

func _tuile(x: float, largeur: float, etiquette: String, montant: String, suite: String, id: String, marque: bool, libelle: String) -> Button:
	var tuile := Button.new()
	tuile.name = id
	tuile.flat = true
	tuile.focus_mode = Control.FOCUS_ALL
	tuile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var fond := C.box(Charte.PANNEAU, Color.TRANSPARENT, 16, 0)
	tuile.add_theme_stylebox_override("normal", fond)
	tuile.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 16, 0))
	tuile.add_theme_stylebox_override("pressed", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 16, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 16, 0)
	focus.set_border_width_all(2)
	tuile.add_theme_stylebox_override("focus", focus)
	tiles.add_child(tuile)
	D.place(tuile, Rect2(x, 6, largeur, 116))
	if marque: Kit.marqueur(tuile, Rect2(12, 22, 6, 72))
	var gauche := 34 if marque else 16
	var courant := D.text(tuile, gauche, 36, etiquette.to_upper(), 16, Charte.IVOIRE_2, 700, largeur - 30)
	if id == "RecruitmentTransferBudget": courant.name = "RecruitmentTransferBudgetLabel"
	var valeur := D.text(tuile, gauche, 82, montant, 46, Charte.IVOIRE, 800, largeur - 30)
	valeur.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	if id == "RecruitmentTransferBudget": valeur.name = "RecruitmentTransferBudgetAmount"
	elif id == "RecruitmentBudgetAllocated": valeur.name = "RecruitmentTransferBudgetAllocated"
	if not suite.is_empty(): D.text(tuile, gauche, 108, suite, 16, Charte.IVOIRE_2, 600, largeur - 30)
	for enfant in tuile.get_children():
		if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Link.bind(tuile, app, {"kind":"finance", "id":"transfers"}, libelle if not libelle.is_empty() else etiquette)
	tuile.tooltip_text = ""
	return tuile

## « 10 fin(s) de contrat » du moteur : accord au nombre (jamais « fin(s) » à l'écran).
static func _pluriel(texte: String) -> String:
	if not texte.contains("(s)"): return texte
	var chiffres := ""
	for lettre in texte:
		if lettre >= "0" and lettre <= "9": chiffres += lettre
		elif not chiffres.is_empty(): break
	return texte.replace("(s)", "s" if not chiffres.is_empty() and int(chiffres) > 1 else "")
## Raison d'un besoin : « n fin(s) de contrat » est un total du club dans les données ; ici, le nombre AU POSTE (lu dans
## l'effectif), ou rien s'il n'y en a pas. Les autres raisons (relève insuffisante…) sont gardées telles quelles.
func _raison_au_poste(raison: String, role: String) -> String:
	if not raison.contains("contrat"): return _pluriel(raison)
	var saison := int(app.model.get("meta", {}).get("season", 1))
	var fins := 0
	for joueur: Dictionary in app.model.get("squad", []):
		var fin: Variant = joueur.get("contractEnd")
		if str(joueur.get("pos", "")) == role and (fin is int or fin is float) and int(fin) <= saison: fins += 1
	return P.plural(fins, "fin de contrat", "fins de contrat") + " à ce poste cette saison" if fins > 0 else ""

## « 1 fin de contrat à ce poste cette saison » → « 1 fin » ; les autres raisons (relève insuffisante…) restent en mots courts.
static func _raison_courte(raison: String) -> String:
	var lecture := RegEx.create_from_string("^(\\d+) fins? de contrat à ce poste cette saison$").search(raison)
	if lecture != null: return "%s fin%s" % [lecture.get_string(1), "s" if int(lecture.get_string(1)) > 1 else ""]
	return raison

func _needs() -> void:
	var needs: Array = []
	var seen: Array = []
	for need: Dictionary in data.get("needs", []):
		var position: Variant = need.get("pos")
		if position in seen: continue
		seen.append(position)
		needs.append(need)
		if needs.size() == 3: break
	if needs.is_empty():
		Kit.texte(self, 0, 168, "Les besoins de l’effectif ne sont pas renseignés.", Charte.IVOIRE_2, 1400, 19).name = "RecruitmentNoNeeds"
		return
	var largeur := (WIDTH - 2 * 14.0) / 3.0
	for i in mini(3, needs.size()):
		var need: Dictionary = needs[i]
		var role := str(need.get("pos", "Poste inconnu"))
		var choisi := str(state.get("position", "Tous")) == role
		var x := i * (largeur + 14)
		var stock: int = app.model.get("market", []).filter(func(p: Dictionary): return p.get("pos") == role).size()
		var suivies: int = app.model.get("market", []).filter(func(p: Dictionary): return p.get("pos") == role and str(p.id) in app.management_ui.shortlist).size()
		var carte: Control
		if stock > 0:
			var bouton_carte := Button.new()
			bouton_carte.flat = true
			bouton_carte.focus_mode = Control.FOCUS_ALL
			bouton_carte.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			bouton_carte.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU_3 if choisi else Charte.PANNEAU, Color.TRANSPARENT, 16, 0))
			bouton_carte.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 16, 0))
			bouton_carte.add_theme_stylebox_override("pressed", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 16, 0))
			var focus_carte := C.box(Color.TRANSPARENT, Charte.IVOIRE, 16, 0)
			focus_carte.set_border_width_all(2)
			bouton_carte.add_theme_stylebox_override("focus", focus_carte)
			bouton_carte.accessibility_name = "Filtrer sur %s" % role
			bouton_carte.pressed.connect(func(): Decisions.open_market_position(app, role))
			add_child(bouton_carte)
			D.place(bouton_carte, Rect2(x, 136, largeur, 90))
			carte = bouton_carte
		else:
			# Aucune piste pour ce poste : la carte n'est pas un lien vers une liste vide, elle propose une mission.
			carte = D.rect(self, Rect2(x, 136, largeur, 90), Charte.PANNEAU, 16)
			carte.mouse_filter = Control.MOUSE_FILTER_PASS
		carte.name = "MarketNeed_" + str(i)
		Kit.marqueur(carte, Rect2(18, 16, 8, 58), Charte.IVOIRE if i == 0 else Charte.IVOIRE_2)
		var mot := ("PRIORITÉ %d" if need.get("need", false) else "À SURVEILLER %d") % (i + 1)
		if i == 0 and need.get("need", false): mot += " · URGENT"
		D.text(carte, 44, 30, mot, 16, Charte.IVOIRE_2, 700, 330)
		var nom := D.text(carte, 44, 70, role, 34, Charte.IVOIRE, 800, 340)
		nom.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		var raisons: Array = need.get("reasons", [])
		var raison := _raison_au_poste(str(raisons[0]), role) if not raisons.is_empty() else "Couverture du poste à examiner"
		# Pastilles (de droite à gauche) : fins de contrat au poste, pistes, pistes suivies.
		var pastilles: Array = []
		if not raison.is_empty(): pastilles.append([_raison_courte(raison), "MarketNeedReason_" + str(i), raison, Pieces.ORANGE, func(): _fins_de_contrat() if raison.contains("contrat") else Decisions.open_market_position(app, role)])
		if stock > 0:
			pastilles.append([P.plural(stock, "piste", "pistes"), "MarketPriorityStock" if i == 0 else "MarketNeedStock_" + str(i), "", Pieces.BLEU, func(): Decisions.open_market_position(app, role)])
			pastilles.append([P.plural(suivies, "suivie", "suivies"), "MarketNeedFollowed_" + str(i), "", Pieces.TURQUOISE, func(): _ouvrir_onglet(2)])
		var droite_pastille := largeur - 20.0
		for k in range(pastilles.size() - 1, -1, -1):
			var largeur_pastille := minf(Pieces.largeur_pastille(str(pastilles[k][0])), 300.0)
			droite_pastille -= largeur_pastille
			Pieces.pastille(carte, droite_pastille, 28, str(pastilles[k][0]), "", str(pastilles[k][1]), str(pastilles[k][2]), pastilles[k][3], Charte.FILET if choisi else Charte.PANNEAU_3, pastilles[k][4])
			droite_pastille -= 8.0
		for enfant in carte.get_children():
			if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if stock == 0:
			var libelle_mission := "Lancer une mission pour ce poste →"
			var largeur_mission := Kit.largeur(libelle_mission, 18) + 14
			var lien_mission := Kit.lien(self, Rect2(x + largeur - 20 - largeur_mission, 136 + 50, largeur_mission, 34), libelle_mission, func(): _recherche(role), "MarketNeedMission_" + str(i), 18)
			lien_mission.tooltip_text = ""


func _tabs() -> void:
	var x := 0.0
	for i in TABS.size():
		var id := "MarketFollowed" if i == 2 else "MarketTab" + str(i)
		var libelle: String = TABS[i]
		if i == 2: libelle += " %d" % app.management_ui.shortlist.size()
		if i == 3: libelle += " %d" % data.get("reports", []).size()
		var choisi := tab == i
		var largeur := Kit.largeur(libelle, 19) + 44
		var bouton := Button.new()
		bouton.name = id
		bouton.text = libelle
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# Charte §7.1 : onglet en pilule ; actif = aplat crème, texte PANNEAU.
		bouton.add_theme_font_override("font", Charte.TITRE_GRAS if choisi else Charte.TITRE)
		bouton.add_theme_font_size_override("font_size", maxi(12, C.px(21)))
		D.tab_state(bouton, Vector2(largeur, 44), choisi, "")
		bouton.icon = null
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE, 18)
		focus.set_border_width_all(2)
		focus.set_expand_margin_all(2)
		bouton.add_theme_stylebox_override("focus", focus)
		bouton.toggle_mode = true
		bouton.button_pressed = choisi
		bouton.pressed.connect(func():
			state.immersive_tab = i
			state.navigation_id = ""
			state.followed = i == 2
			state.page = 0
			state.focus = "MarketSearch" if i == 1 else id
			app._render(false))
		add_child(bouton)
		D.place(bouton, Rect2(x, 244, largeur, 44))
		x += largeur + 8
	# Sources : le marché des joueurs (cette liste), les autres clubs et la relève sont des écrans à part.
	var droite := float(WIDTH) - 8.0
	var sources :=[["Relève", "releve", "OpenRegenScouting", "Repérer la relève : agents libres majeurs, centres de formation et petits clubs"], ["Entre clubs", "interclub", "OpenInterclubMarket", ""], ["Marché joueurs %d" % app.model.get("market", []).size(), "", "MarketSourcePlayers", ""]]
	var calendrier: Dictionary = app.model.get("mutations", {}) if app.model.get("mutations") is Dictionary else {}
	for source: Array in sources:
		var actif: bool = str(source[1]).is_empty()
		var largeur := Kit.largeur(str(source[0]), 18) + 40
		droite -= largeur
		var bouton := Button.new()
		bouton.name = str(source[2])
		bouton.text = str(source[0])
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		C.style_bouton_lien(bouton, 20, actif)
		bouton.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if actif:
			bouton.pressed.connect(func():
				state.immersive_tab = 1
				state.followed = false
				state.navigation_id = ""
				state.focus = "MarketSearch"
				app._render(false))
		else:
			var page: String = source[1]
			bouton.pressed.connect(func(): Pages.ouvrir(app, page))
		if str(source[2]) == "OpenInterclubMarket": bouton.tooltip_text = str(calendrier.get("interclub", {}).get("note", ""))
		elif not str(source[3]).is_empty(): bouton.tooltip_text = str(source[3])
		add_child(bouton)
		D.place(bouton, Rect2(droite, 248, largeur, 38))
		droite -= 8
	var etiquette := Kit.etiquette(self, droite - 8, 274, "Source", 90, true)
	etiquette.name = "RecruitmentSourceLabel"
	# Liens d'action de la ligne des onglets, de droite à gauche ; ce qui ne tient pas passe sur la ligne des filtres.
	var limite := droite - 8 - Kit.largeur("SOURCE", 16) - 40
	var libre := x + 24
	var offres := (SalesView.sales(app.model).get("offers", []) as Array).size()
	var expirant: int = (data.get("expiring", []) as Array).size()
	var liens: Array = [["OpenScoutMission", "Lancer une mission →", func(): _staff(1), false]]
	liens.append(["OpenPlayerSales", SalesView.caption(app.model) + " →", func(): Pages.ouvrir(app, "offres"), offres > 0])
	if expirant > 0: liens.append(["OpenExpiringContracts", P.plural(expirant, "fin de contrat", "fins de contrat") + " →", func(): _fins_de_contrat(), false])
	for lien: Array in liens:
		var largeur_lien := Kit.largeur(str(lien[1]), 18) + 12
		if limite - largeur_lien < libre:
			_liens_filtre.append(lien)
			continue
		var bouton := Kit.lien(self, Rect2(limite - largeur_lien, 250, largeur_lien, 36), str(lien[1]), lien[2], str(lien[0]), 18)
		bouton.tooltip_text = ""
		if lien[3]: bouton.add_theme_font_override("font", Charte.TITRE_GRAS)
		if lien[0] == "OpenPlayerSales": bouton.accessibility_name = bouton.text
		if lien[0] == "OpenExpiringContracts": bouton.accessibility_name = "Voir les fins de contrat de la saison dans l'effectif"
		limite -= largeur_lien + 18
