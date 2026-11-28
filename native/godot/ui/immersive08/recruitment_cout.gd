extends "res://ui/immersive08/recruitment_filtres.gd"
## Écran Recrutement : bloc « Ce que coûte l'offre » de la piste choisie, observation payante (découpe de recruitment_canvas.gd, sans changement).

# --- Coût de l'offre --------------------------------------------------------------------------------------------

## « Ce que coûte l'offre » (maquette 3) : indemnité, salaire demandé, durée, effet sur le budget de transferts et la
## masse salariale de la piste choisie ; l'action principale de l'écran (ivoire plein) est ici et nulle part ailleurs.
func _cout() -> void:
	_clear(cost)
	D.rect(cost, Rect2(0, 0, WIDTH, 172), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	var player := _selected if tab != 3 else _market_player(str(_selected.get("playerId", "")))
	var report: Dictionary = _selected if tab == 3 else report_by_player.get(str(_selected.get("id", "")), {})
	Kit.etiquette(cost, 24, 34, "Ce que coûte l’offre", 330)
	if player.is_empty():
		Kit.texte(cost, 24, 84, "Aucune piste sélectionnée", Charte.IVOIRE_2, 1100, 19).name = "RecruitmentCostEmpty"
		var besoins := Kit.lien(cost, Rect2(24, 108, 0, 36), "Besoins, missions et rapports →", func(): _staff(0), "OpenEmptyRecruitmentNeeds", 19)
		besoins.tooltip_text = ""
		return
	var player_id := str(player.get("id", ""))
	var nom := D.text(cost, 24, 82, str(player.get("name", "—")).to_upper(), 36, Charte.IVOIRE, 800, 420)
	nom.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	nom.name = "RecruitmentCostName"
	var bouton_nom := _reading_area(cost, Rect2(20, 44, 430, 50), {"kind":"market", "id":player_id}, "RecruitmentNameLink", str(player.get("name", "Dossier")))
	if bouton_nom != null: CarteSurvol.lier_info(app, bouton_nom, player_id, "market")
	var statut: String = {"counter":"contre-offre reçue", "withdrawn":"discussion rompue", "signed":"contrat signé"}.get(str(player.get("negotiation", {}).get("status", "")) if player.get("negotiation") is Dictionary else "", "avant négociation")
	var detail := "%s · %s ans · %s" % [str(player.get("pos", "—")), G.n(player.get("age", "—")), statut]
	Kit.texte(cost, 24, 116, detail, Charte.IVOIRE_2, 470, 18 if C.density >= .75 else 16)
	# Budget de transferts : déjà engagé, cette indemnité, reste.
	var budget := Budget.data(app.model)
	var fee: Variant = player.get("fee")
	var fee_known: bool = fee is int or fee is float
	if not budget.is_empty():
		var total := Budget.season_total(budget)
		var depense := int(budget.get("depense", 0))
		Kit.etiquette(cost, 500, 34, "Budget de transferts · %s alloués" % G.euros(total), 520)
		var barre := Rect2(500, 52, 700, 20)
		D.rect(cost, barre, Charte.PANNEAU_3, Charte.RAYON_PILULE)
		if total > 0:
			var largeur_depense := 700.0 * clampf(float(depense) / total, 0, 1)
			var largeur_offre := 700.0 * clampf(float(fee if fee_known else 0) / total, 0, 1 - largeur_depense / 700.0)
			if largeur_depense > 0: D.rect(cost, Rect2(500, 52, largeur_depense, 20), Charte.IVOIRE_3, Charte.RAYON_PILULE)
			if largeur_offre > 0: D.rect(cost, Rect2(500 + largeur_depense, 52, largeur_offre, 20), Charte.IVOIRE, Charte.RAYON_PILULE)
			D.rect(cost, Rect2(500 + largeur_depense + largeur_offre, 52, maxf(0, 700 - largeur_depense - largeur_offre), 20), Color.TRANSPARENT, Charte.RAYON_PILULE, Charte.IVOIRE_3)
		var reste := int(budget.get("disponible", 0)) - (int(fee) if fee_known else 0)
		var legende := [["Déjà engagé", G.euros(depense), Charte.IVOIRE_3, true]]
		if fee_known: legende.append(["Cette indemnité", G.euros(fee), Charte.IVOIRE, true])
		legende.append(["Reste", G.euros(reste), Charte.IVOIRE_3, false])
		var lx := 500.0
		for element: Array in legende:
			D.rect(cost, Rect2(lx, 92, 14, 14), element[2] if element[3] else Color.TRANSPARENT, 4, Charte.IVOIRE_3 if not element[3] else Color.TRANSPARENT)
			var texte := "%s %s" % [element[0], element[1]]
			Kit.texte(cost, lx + 22, 104, texte, Charte.IVOIRE_2, 300, 17)
			lx += Kit.largeur(texte, 17) + 50
		if fee_known and reste < 0:
			Pieces.pastille(cost, 500, 124, "Hors budget", "warning", "RecruitmentCostOverBudget", "Le conseil peut accorder une rallonge si la caisse le permet.", Pieces.ROUGE, Charte.PANNEAU_3, func(): _vers_finances("transfers"))
	else:
		var cash: Variant = app.model.get("finance", {}).get("cash")
		Kit.etiquette(cost, 500, 34, "Trésorerie du club", 520)
		Kit.texte(cost, 500, 82, G.euros(cash) if cash is int or cash is float else "—", Charte.IVOIRE, 400, 30)
	# Indemnité, salaire, durée.
	var quote := player
	Kit.texte(cost, 1290, 34, "Indemnité de transfert", Charte.IVOIRE_2, 330, 17)
	var montant := D.text(cost, 1290, 84, _money(quote.get("fee", quote.get("price"))), 40, Charte.IVOIRE, 800, 330)
	montant.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	montant.name = "RecruitmentCostFee"
	var max_years := int(player.get("maxYears", 0))
	var annees := "%s–%s" % [G.n(player.get("minYears", 1)), G.n(max_years)] if max_years > 1 else "1" if max_years == 1 else "—"
	var negociation: Variant = player.get("negotiation")
	var reprise: bool = negociation is Dictionary and str(negociation.get("status", "")) == "withdrawn"
	var offre_ouverte: bool = not (app.waiting or (not player.get("available", false) and not reprise) or not app._live().is_empty())
	var vers_offre := Callable(self, "_approcher").bind(player) if offre_ouverte else Callable()
	# Coût de l'offre en tuiles : salaire demandé, durée, masse salariale sur la durée, frais d'observation.
	var tuile_y := 98.0
	Pieces.tuile(cost, Rect2(1290, tuile_y, 112, 62), G.salary_amount(quote.get("salary")), G.salary_period(C.density < .75), Pieces.BLEU if offre_ouverte else Charte.IVOIRE, "RecruitmentCostSalary", 24, "Salaire demandé", "", false, vers_offre)
	Pieces.tuile(cost, Rect2(1408, tuile_y, 112, 62), annees, "ans" if max_years != 1 else "an", Pieces.VIOLET if offre_ouverte else Charte.IVOIRE, "RecruitmentCostYears", 24, "Durée du contrat", "", false, vers_offre)
	if (quote.get("salary") is int or quote.get("salary") is float) and max_years > 0:
		var total_salaire := int(quote.salary) * WEEKS_PER_YEAR * max_years
		Pieces.tuile(cost, Rect2(1526, tuile_y, 112, 62), "+" + _compact(total_salaire), "sur %d %s" % [max_years, "an" if max_years == 1 else "ans"], Pieces.ORANGE, "RecruitmentCostPayroll", 24, "Masse salariale ajoutée sur la durée du contrat : %s" % G.euros(total_salaire), "", true, func(): _vers_finances("wages"))
	# Observation (frais et délai) lue sur le joueur, jamais inventée.
	var scouting: Dictionary = player.get("scouting", {}) if player.get("scouting") is Dictionary else {}
	var frais_valeur := ""
	var frais_delai := ""
	if not scouting.is_empty() and not scouting.get("pending", false) and scouting.has("cost"):
		frais_valeur = _compact(int(scouting.get("cost", 0)))
		var cycles := int(scouting.get("workCycles", 0))
		frais_delai = "%d %s" % [cycles, "sem." if scouting.get("workUnit") == "week" else "cycles"]
	if not frais_valeur.is_empty():
		var tuile_observation := Pieces.tuile(cost, Rect2(1644, tuile_y, 112, 62), frais_valeur, frais_delai, Pieces.TURQUOISE, "RecruitmentCostObservation", 24, "", "search")
		tuile_observation.tooltip_text = "Observer : %s · %s" % [G.euros(scouting.get("cost", 0)), frais_delai]
	# Actions : principale (ivoire plein), puis liens.
	# Actions : principale (ivoire plein, un seul par écran), puis liens à la suite.
	var consultation: bool = player.get("negotiation", {}).get("status", "") == "withdrawn" if player.get("negotiation") is Dictionary else false
	var observable := player.get("scouting") is Dictionary and not Observation.reason(app, player) == "Joueur de ton club"
	var principal := Kit.bouton_ivoire(cost, Rect2(1790, 20, 440, 44), "Consulter la discussion" if consultation else "Approcher le joueur", func(): _approcher(player), "OfferRecruitment")
	principal.set_meta("player_id", player_id)
	principal.disabled = app.waiting or (not player.get("available", false) and not consultation) or not app._live().is_empty()
	principal.tooltip_text = str(player.get("reason", "")) if not player.is_empty() else ""
	if principal.disabled and not str(player.get("reason", "")).is_empty():
		Kit.texte(cost, 1790, 92, str(player.get("reason", "")), Charte.D, 440, 17).name = "RecruitmentCostBlocked"
	var liens: Array = []
	if observable: liens.append(["Observer →" if Observation.caption(player) == "Observer" else Observation.caption(player) + " →", "ObserveRecruitment", func(): _confirmer_observation(player), not Observation.reason(app, player).is_empty()])
	liens.append(["Rapport du recruteur →", "OpenRecruiterReport", func(): Pages.ouvrir(app, "recruteur", {"player_id": player_id}), false])
	liens.append(["Parler à l’agent →", "OpenAgentTalk", func(): Pages.ouvrir(app, "recruteur", {"player_id": player_id, "agent": true}), false])
	liens.append(["Ouvrir la fiche →", "OpenRecruitmentPlayer", func(): app.navigation_controller.open_entity({"kind":"market", "id":player_id}), false])
	var context_suivi: Variant = app.model.get("clubLife", {}).get("managerCareer", {}).get("context")
	var peut_suivre: bool = not app.waiting and app._live().is_empty() and app.model.meta.get("phase", "") != "ended" and context_suivi is Dictionary
	liens.append(["Retirer du suivi" if player_id in app.management_ui.shortlist else "Suivre cette piste", "Follow" + player_id.replace(":", "_"), func(): app._command("manager_recruitment_watch", {"context": context_suivi.duplicate(true), "playerId": player_id}), not peut_suivre])
	if tab == 3 or not report.is_empty(): liens.append(["Lire le rapport complet →", "OpenScoutReport", func(): _report_page(report), false])
	var lx2 := 1790.0
	var ly := 100.0
	for lien: Array in liens:
		var largeur := Kit.largeur(str(lien[0]), 18) + 12
		if lx2 + largeur > 2240 and lx2 > 1790:
			lx2 = 1790.0
			ly += 30
		var bouton := Kit.lien(cost, Rect2(lx2, ly, largeur, 30), str(lien[0]), lien[2], str(lien[1]), 18)
		bouton.tooltip_text = ""
		bouton.disabled = lien[3]
		if str(lien[1]).begins_with("Follow"): bouton.set_meta("follow_id", player_id)
		lx2 += largeur + 18
	# La tuile des frais d'observation est cliquable comme le lien « Observer » : même confirmation en place.
	var tuile_observation := cost.find_child("RecruitmentCostObservation", false, false) as Control
	if tuile_observation != null and observable and Observation.reason(app, player).is_empty():
		var clic := Button.new()
		clic.name = "ObserveCostTile"
		clic.flat = true
		clic.focus_mode = Control.FOCUS_ALL
		clic.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		clic.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		# Voile de survol posé sur la tuile (déjà ombrée) : pas d'ombre propre, comme les autres liens de tuile.
		var voile := C.box(Color(Charte.IVOIRE, .08), Color.TRANSPARENT, Charte.RAYON_CARTE, 0)
		voile.shadow_size = 0
		clic.add_theme_stylebox_override("hover", voile)
		var focus_clic := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_CARTE, 0)
		focus_clic.set_border_width_all(2)
		clic.add_theme_stylebox_override("focus", focus_clic)
		clic.accessibility_name = "Observer %s" % str(player.get("name", ""))
		clic.tooltip_text = tuile_observation.tooltip_text
		clic.pressed.connect(func(): _confirmer_observation(player))
		tuile_observation.add_child(clic)
		D.place(clic, Rect2(0, 0, 112, 62))

## Observation payante : confirmation EN PLACE (deux temps, aucune fenêtre), sur la partie droite du bloc de coût.
func _confirmer_observation(player: Dictionary) -> void:
	if Observation.reason(app, player) != "" or not player.get("scouting") is Dictionary: return
	var scouting: Dictionary = player.scouting
	var phrase := "Frais : %s · délai : %s. Le rapport arrive à la fin de la mission." % [G.euros(scouting.get("cost", 0)), G.n(scouting.get("workCycles", 0)) + (" semaines" if scouting.get("workUnit") == "week" else " cycles")]
	var envoyer := func(): _observer(player)
	var bloc := EnPlace.ouvrir(app, cost, "ObservationConfirmation", "Observer " + str(player.get("name", "")), [{"id":"ObservationConfirmPhrase", "text":phrase}], "Lancer l’observation · " + G.euros(scouting.get("cost", 0)), envoyer)
	D.place(bloc, Rect2(1100, 0, WIDTH - 1100, 10))

func _observer(player: Dictionary) -> void:
	# Le coût et le délai sont écrits à côté du bouton : cliquer vaut confirmation (aucune fenêtre).
	if Observation.reason(app, player) != "" or not player.get("scouting") is Dictionary: return
	var context: Variant = player.scouting.get("context")
	if not context is Dictionary: return
	app._command("observe_player", {"playerId": Observation.player_id(player), "confirmed": true, "context": context.duplicate(true)})
