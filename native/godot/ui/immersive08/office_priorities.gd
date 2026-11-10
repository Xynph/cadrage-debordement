extends RefCounted
## Lecture seule : les urgences viennent des états publiés par le moteur.
## Aucun seuil nouveau ne modifie l'effectif, les contrats ou la trésorerie.

static func _item(id: String, title: String, detail: String, deadline: String, icon: String, action: String, level: String, player: String = "") -> Dictionary:
	return {"id":id,"title":title,"detail":detail,"deadline":deadline,"icon":icon,"action":action,"level":level,"player":player}

static func _date(value: Variant) -> String:
	var source := str(value)
	var parts := source.split("-")
	return "%s/%s/%s" % [parts[2],parts[1],parts[0]] if parts.size() == 3 else source

static func select(model: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not model.get("club") is Dictionary or model.club.is_empty(): return result
	var meta: Dictionary = model.get("meta", {})
	var season := int(meta.get("season",1))
	var live: Dictionary = model.get("live") if model.get("live") is Dictionary else {}
	var ended: bool = meta.get("canAdvanceSeason",false)
	var next: Dictionary = model.get("next") if model.get("next") is Dictionary else {}
	var today := str(meta.get("calendarToday",""))
	if not live.is_empty():
		var finished: bool = live.get("finished",false)
		result.append(_item("OfficeLivePriorityAction","Consulter le résultat" if finished else "Revenir au direct",
			"Le résultat attend votre validation dans le match." if finished else "Le match est en cours. Retrouvez le score et les décisions du direct.",
			"Résultat en attente" if finished else "Maintenant","trophy","match","urgent"))
	if bool(model.get("clubLife",{}).get("press",{}).get("conference",{}).get("required",false)):
		result.append(_item("OfficePressPriorityAction","Répondre à la presse",
			"L’invitation est dans la Réception. Vos réponses sont attendues pour poursuivre.",
			"Avant de continuer","mail","press","urgent"))
	if ended:
		result.append(_item("OfficeFinalStandingsAction","Consulter le classement final",
			"La saison %d est clôturée. Faites le bilan avant de préparer la suivante." % season,
			"Avant la saison suivante","trophy","standings","important"))
	elif not next.is_empty() and not bool(model.get("selection",{}).get("valid",false)) and live.is_empty():
		var errors: Array = model.get("selection",{}).get("errors",[])
		var detail := str(errors[0]) if not errors.is_empty() else "La feuille projetée n’est pas valide. Consultez les postes à compléter."
		result.append(_item("OfficeSelectionPriorityAction","Compléter la feuille de match",detail,
			"Avant le prochain match","people","selection","urgent"))
	var cash: Variant = model.get("finance",{}).get("cash",model.club.get("cash"))
	if cash is float or cash is int:
		if float(cash) < 0:
			result.append(_item("OfficeFinancePriorityAction","Examiner la trésorerie",
				"La trésorerie de jeu est négative. Consultez les flux et les engagements avant de décider.",
				"Avant un nouvel engagement","money","finance","urgent"))
	var international: Dictionary = model.get("international") if model.get("international") is Dictionary else {}
	var availability: Dictionary = international.get("availability") if international.get("availability") is Dictionary else {}
	var absent := int(availability.get("absentCount",0))
	if bool(availability.get("clubManaged",false)) and absent > 0:
		var return_date := str(availability.get("nextReturn",""))
		result.append(_item("OfficeInternationalPriorityAction","Anticiper %d absence%s internationale%s" % [absent,"s" if absent > 1 else "","s" if absent > 1 else ""],
			"Ces joueurs du club sont convoqués. Consultez les postes concernés et les retours annoncés.",
			"Retour à partir du " + _date(return_date) if not return_date.is_empty() else "Pendant la fenêtre internationale",
			"calendar","international","important"))
	var injured: Array = model.get("squad",[]).filter(func(player: Dictionary): return float(player.get("injury",0)) > 0)
	if not injured.is_empty() and not ended:
		result.append(_item("OfficeMedicalPriorityAction","Adapter le groupe aux blessures",
			"%d joueur%s blessé%s. Vérifiez les solutions disponibles dans l’effectif." % [injured.size(),"s" if injured.size() > 1 else "","s" if injured.size() > 1 else ""],
			"Avant la composition","heart","squad","important"))
	var contracts: Array = model.get("squad",[]).filter(func(player: Dictionary):
		return player.get("contractEnd") != null and int(player.contractEnd) <= season + 1)
	contracts.sort_custom(func(a: Dictionary,b: Dictionary):
		return str(a.get("id","")) < str(b.get("id","")) if int(a.contractEnd) == int(b.contractEnd) else int(a.contractEnd) < int(b.contractEnd))
	if not contracts.is_empty():
		var first: Dictionary = contracts[0]
		var expiry := int(first.contractEnd)
		var deadline := "Fin de cette saison" if expiry <= season else "Fin de saison %d" % expiry
		result.append(_item("OfficeContractsAction","Préparer %d échéance%s de contrat" % [contracts.size(),"s" if contracts.size() > 1 else ""],
			str(first.get("name","Joueur")) + " · " + str(first.get("contractLabel",deadline)),deadline,
			"people","contract","important" if expiry <= season else "normal",str(first.get("id",""))))
	if not ended and live.is_empty() and not next.is_empty():
		var when := str(next.get("date",""))
		result.append(_item("OfficeMatchPriorityAction","Préparer le prochain match",
			"Consultez l’adversaire et les choix de préparation avant de composer l’équipe.",
			"Aujourd’hui" if when == today and not today.is_empty() else "Le " + _date(when) if not when.is_empty() else "Prochaine rencontre",
			"trophy","preparation","important" if when == today and not today.is_empty() else "normal"))
	if not ended:
		var trained: bool = meta.get("trained",false)
		var training: Dictionary = model.get("decisions",{}).get("training",{})
		result.append(_item("OfficeTrainingAction","Revoir la préparation" if trained else "Préparer l’entraînement",
			"La séance a été effectuée. Les réglages restent consultables." if trained else str(training.get("advice","Consultez les choix collectifs et la charge du groupe.")),
			"Cette semaine","train","training","normal"))
	var market: Array = model.get("market",[])
	var offers := market.filter(func(player: Dictionary): return player.get("available",false)).size()
	result.append(_item("OfficeRecruitmentAction","Examiner le recrutement",
		"%d piste%s · %d offre%s possible%s dans le marché publié." % [market.size(),"s" if market.size() > 1 else "",offers,"s" if offers > 1 else "","s" if offers > 1 else ""] if model.has("market") else "Consultez les pistes et les conditions du marché.",
		"À anticiper","search","recruitment","normal"))
	result.append(_item("OfficeSquadPriorityAction","Consulter le groupe",
		"Retrouvez les joueurs, leurs contrats et leur condition dans l’effectif.",
		"Pour préparer la suite","people","squad","normal"))
	return result.slice(0,3)
