extends RefCounted
# Les calculs appartiennent à la projection native ; cette vue ne reconstitue pas de statistiques.
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
		panel.add_child(G.wrap("Analyses indisponibles dans cette version du moteur.", 14))
		return panel
	var summary: Dictionary = data.get("summary", {})
	var count: int = int(summary.get("played", 0))
	panel.add_child(G.wrap(str(data.get("notice", "")), 12))
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
		var where: String = "Domicile" if bool(match.get("home",false)) else "Extérieur"
		var date: String = "Saison %d · %s" % [int(match.season), _phase(str(match.get("phase","")))]
		if match.get("round") != null: date += " · J%d" % (int(match.round)+1)
		var decision: String = " · après départage" if bool(match.get("decidedAfterTie",false)) else ""
		panel.add_child(G.wrap("%s · %s · %s · %d — %d contre %s%s" % [date, where, str(match.outcome), int(match.pointsFor), int(match.pointsAgainst), str(match.opponentName), decision], 14, G.INK))
	return panel
