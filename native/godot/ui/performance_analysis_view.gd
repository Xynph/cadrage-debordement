extends RefCounted
# Les calculs appartiennent à la projection native ; cette vue ne reconstitue pas de statistiques.
const Copy = preload("res://ui/management_copy.gd")
const G = preload("res://ui/carnet_skin.gd")

static func _decimal(value: float) -> String:
	return ("%.1f" % value).replace(".", ",")

static func _phase(value: String) -> String:
	return {"league":"Championnat", "pool":"Poules", "r16":"Huitième", "quarter":"Quart", "semi":"Demi-finale", "final":"Finale", "access":"Accession", "barrage":"Barrage"}.get(value, "Rencontre")

static func build(app: Control) -> Control:
	var panel := G.v(9)
	panel.name = "PerformanceAnalysis"
	G.fill(panel)
	panel.add_child(G.section("Comprendre nos cinq dernières rencontres", "Scores et statistiques collectives réellement conservés."))
	var data: Dictionary = app.model.get("clubLife", {}).get("performanceAnalysis", {})
	if not bool(data.get("available", false)):
		panel.add_child(G.wrap("Analyses indisponibles pour cette carrière.", 14))
		return panel
	var summary: Dictionary = data.get("summary", {})
	var count: int = int(summary.get("played", 0))
	panel.add_child(G.wrap(Copy.notice("performance", data.get("notice", "")), 12))
	_individual(app, panel)
	if count == 0:
		panel.add_child(G.wrap("Aucune rencontre conservée pour ce club cette saison. Le bilan apparaîtra après les premiers matchs.", 16, G.INK))
		return panel
	panel.add_child(G.wrap("%d rencontres · %d V / %d N / %d D · %d points marqués / %d encaissés" % [count, int(summary.get("won",0)), int(summary.get("drawn",0)), int(summary.get("lost",0)), int(summary.get("pointsFor",0)), int(summary.get("pointsAgainst",0))], 17, G.INK))
	for metric: Array in [["lineouts", "Touche"], ["scrums", "Mêlée"]]:
		var m: Dictionary = data.get("metrics", {}).get(metric[0], {})
		var rate: String = "taux inconnu (aucune tentative documentée)" if m.get("rate") == null else _decimal(float(m.rate)*100.0) + " %"
		panel.add_child(G.wrap("%s · %d / %d ballons conservés · %s · couverture %d / %d rencontres" % [metric[1], int(m.get("won",0)), int(m.get("attempts",0)), rate, int(m.get("matches",0)), count], 14))
	var penalties: Dictionary = data.get("metrics", {}).get("penalties", {})
	var penalty_average: String = "moyenne inconnue" if penalties.get("average") == null else _decimal(float(penalties.average)) + " par rencontre documentée"
	panel.add_child(G.wrap("Discipline · %d pénalités concédées · %s · couverture %d / %d rencontres" % [int(penalties.get("total",0)), penalty_average, int(penalties.get("matches",0)), count], 14))
	if data.get("comparison") is Dictionary:
		var c: Dictionary = data.comparison
		panel.add_child(G.wrap("Trois dernières / deux précédentes · points marqués : %s / %s par match · encaissés : %s / %s" % [_decimal(float(c.recent.pointsFor)), _decimal(float(c.previous.pointsFor)), _decimal(float(c.recent.pointsAgainst)), _decimal(float(c.previous.pointsAgainst))], 14, G.INK))
		panel.add_child(G.wrap(str(c.notice), 12))
	else:
		panel.add_child(G.wrap("La comparaison des deux périodes demande cinq rencontres conservées.", 12))
	for advice: Dictionary in data.get("advice", []):
		var card := G.card(panel, G.GOLD)
		card.add_child(G.wrap(str(advice.title), 16, G.INK))
		card.add_child(G.wrap(str(advice.evidence), 14))
		card.add_child(G.wrap(str(advice.action), 14))
	for match: Dictionary in data.get("matches", []):
		var where: String = "Lieu non conservé"
		if match.get("neutral") != null:
			where = "Terrain neutre" if bool(match.neutral) else ("Domicile" if bool(match.get("home",false)) else "Extérieur")
		var date: String = "Saison %d · %s" % [int(match.season), _phase(str(match.get("phase","")))]
		if match.get("competitionRound") != null: date += " · J%d" % (int(match.competitionRound)+1)
		elif match.get("week") != null: date += " · Semaine %d" % (int(match.week)+1)
		elif match.get("round") != null: date += " · J%d" % (int(match.round)+1)
		var decision: String = " · après départage" if bool(match.get("decidedAfterTie",false)) else ""
		panel.add_child(G.wrap("%s · %s · %s · %d — %d contre %s%s" % [date, where, str(match.outcome), int(match.pointsFor), int(match.pointsAgainst), str(match.opponentName), decision], 14, G.INK))
	return panel

static func _value(value: Variant) -> String:
	return "inconnu" if value == null else str(int(value))

static func _individual(app: Control, panel: Container) -> void:
	var data: Dictionary = app.model.get("clubLife", {}).get("playerMatchHistory", {})
	if not data.get("available", false): return
	panel.add_child(G.separator())
	panel.add_child(G.section("Performances individuelles mesurées", "Cinq dernières feuilles conservées par joueur · registre limité à 40 rencontres."))
	panel.add_child(G.wrap(Copy.notice("performance", data.get("notice", "")), 12))
	if not data.get("enabled", false):
		var enable := G.button("ACTIVER LE SUIVI INDIVIDUEL", func():
			app.confirm("Conserver les performances individuelles", "Seules les prochaines rencontres jouées seront conservées, dans cette carrière.", func(): app._command("player_match_history_enable", {"context":data.context.duplicate(true),"confirmed":true})))
		enable.name = "PlayerMatchHistoryEnable"
		enable.disabled = not data.get("canEnable", false)
		panel.add_child(enable)
		return
	panel.add_child(G.wrap("%d / 40 rencontres conservées. Les archives survivent aux changements de saison et de club." % int(data.get("recordedMatches",0)), 13))
	var players: Array = data.get("players", [])
	if players.is_empty():
		panel.add_child(G.wrap("Aucun joueur dans l’effectif actuel.", 14))
		return
	var choice := OptionButton.new()
	choice.name = "PerformancePlayerChoice"
	choice.fit_to_longest_item = false
	choice.custom_minimum_size.y = 40
	choice.get_popup().max_size.y = 320
	G.fill(choice)
	for player: Dictionary in players:
		choice.add_item("%s · %s · %d feuille(s)" % [str(player.name), str(player.pos), player.get("matches",[]).size()])
	panel.add_child(choice)
	var details := G.v(8)
	details.name = "PerformancePlayerDetail"
	G.fill(details)
	panel.add_child(details)
	var draw := func(index: int):
		for child in details.get_children():
			details.remove_child(child)
			child.queue_free()
		if index < 0 or index >= players.size(): return
		var player: Dictionary = players[index]
		var matches: Array = player.get("matches", [])
		details.add_child(G.wrap(str(player.name), 17, G.INK))
		if matches.is_empty():
			details.add_child(G.wrap("Aucune feuille conservée pour ce joueur. Les anciennes apparitions ne sont pas reconstruites.", 14))
			return
		details.add_child(G.wrap("%s minutes connues · couverture %d / %d feuilles" % [_value(player.get("minutes")), int(player.get("measuredMatches",0)), matches.size()], 14))
		for metric: Array in [["tries","Essais"],["penaltyGoals","Pénalités réussies"],["penaltyMisses","Tirs de pénalité manqués"]]:
			var m: Dictionary = player.get("metrics",{}).get(metric[0],{})
			var ratio := "inconnu"
			if m.get("per80") != null: ratio = ("%.2f" % float(m.per80)).replace(".", ",")
			details.add_child(G.wrap("%s · total connu %s sur %d / %d feuilles · par 80 min : %s (%d feuilles, %s minutes)" % [str(metric[1]), _value(m.get("total")), int(m.get("matches",0)), matches.size(), ratio, int(m.get("ratioMatches",0)), _value(m.get("minutes"))], 14))
		for appearance: Dictionary in matches:
			details.add_child(G.wrap("Saison %d · semaine %d · club #%d contre #%d · %s minutes · essais %s · pénalités réussies %s / manquées %s" % [int(appearance.season), int(appearance.week)+1, int(appearance.clubId), int(appearance.opponent), _value(appearance.get("minutes")), _value(appearance.get("tries")), _value(appearance.get("penaltyGoals")), _value(appearance.get("penaltyMisses"))], 13))
	choice.item_selected.connect(draw)
	choice.select(0)
	draw.call(0)
