extends RefCounted
# Reprise de l'entraînement (reprise.cjs) : date de reprise du club, groupe à la reprise
# (internationaux en congés, jeunes convoqués), conseil de Gabi et bilan de la préparation.
# Lecture du modèle seulement : chaque choix passe par une commande du moteur.
const G = preload("res://ui/carnet_skin.gd")
const MONTHS := ["janvier","février","mars","avril","mai","juin","juillet","août","septembre","octobre","novembre","décembre"]
const DAYS := ["lundi","mardi","mercredi","jeudi","vendredi","samedi","dimanche"]

static func day_text(iso: String, weekday: bool = true) -> String:
	var parts := iso.split("-")
	if parts.size() != 3: return iso
	var y := int(parts[0]); var m := int(parts[1]); var d := int(parts[2])
	var unix := Time.get_unix_time_from_datetime_dict({"year":y,"month":m,"day":d,"hour":12,"minute":0,"second":0})
	var dow := int(Time.get_datetime_dict_from_unix_time(unix).weekday) # 0 = dimanche
	var name: String = DAYS[(dow + 6) % 7]
	return ("%s %d %s" % [name, d, MONTHS[m - 1]]) if weekday else ("%d %s" % [d, MONTHS[m - 1]])

static func weeks_text(weeks: float) -> String:
	return ("%.1f" % weeks).replace(".", ",").trim_suffix(",0") + " sem."

static func consequences(effects: Dictionary) -> String:
	var parts: Array[String] = []
	if int(effects.get("fatigue", 0)) > 0: parts.append("joueurs moins reposés (charge +%d)" % int(effects.fatigue))
	if int(effects.get("lateCondition", 0)) > 0: parts.append("fraîcheur entamée en fin de saison")
	if int(effects.get("conditionGap", 0)) > 0: parts.append("condition en retard aux premiers matchs (−%d)" % int(effects.conditionGap))
	if float(effects.get("injuryRisk", 0)) > 0: parts.append("risque de blessure plus élevé en début de saison")
	var auto := int(effects.get("automatismes", 0))
	if auto > 0: parts.append("automatismes en avance (+%d %%)" % auto)
	elif auto < 0: parts.append("automatismes en retard au départ (%d %%), le temps que le groupe soit au complet" % auto)
	var morale := int(effects.get("morale", 0))
	if morale > 0: parts.append("effectif frais, bon moral")
	elif morale < 0: parts.append("moral un peu entamé")
	if parts.is_empty(): return "Préparation équilibrée."
	var text := ", ".join(parts)
	return text.substr(0, 1).to_upper() + text.substr(1) + "."

static func relevant(model: Dictionary) -> bool:
	var r: Dictionary = model.get("clubLife", {}).get("reprise", {})
	if not bool(r.get("available", false)): return false
	return r.get("today") != null or bool(r.get("editable", false)) or (r.get("report") is Dictionary and int(model.get("meta", {}).get("week", 99)) <= 6)

static func build(app: Control, parent: Control) -> void:
	var r: Dictionary = app.model.get("clubLife", {}).get("reprise", {})
	if not bool(r.get("available", false)): return
	var panel := G.panel(parent)
	panel.name = "RepriseDecision"
	var club: Dictionary = r.get("club", {})
	var subtitle := "Préparation d’avant-saison · aujourd’hui %s" % day_text(str(r.get("calendarToday", ""))) if r.get("today") != null else ("Saison suivante : choix pour la prochaine reprise" if bool(r.get("nextSeason", false)) else "Première rencontre officielle le %s" % day_text(str(club.get("firstMatch", ""))))
	G.chapter(panel, "00", "La reprise", subtitle, app.accent)
	var editable := bool(r.get("editable", false))
	var head := G.h(18)
	panel.add_child(head)
	head.add_child(G.metric(day_text(str(club.get("date", "")), false) if club.get("date") != null else "—", "Reprise du groupe"))
	head.add_child(G.metric(weeks_text(float(club.get("weeks", 0))), "De préparation"))
	head.add_child(G.metric(str((club.get("friendlies", []) as Array).size()), "Matchs amicaux"))
	var group: Dictionary = r.get("group", {})
	head.add_child(G.metric("%d / %d" % [int(group.get("atReprise", 0)), int(group.get("total", 0))], "Joueurs à la reprise"))
	if club.get("habitual") != null:
		panel.add_child(G.wrap("Date habituelle du club : %s%s." % [day_text(str(club.habitual)), " (une semaine plus tard après la finale)" if bool(club.get("finalShift", false)) else ""], 14))
	# Lundis proposés.
	var options: Array = r.get("options", [])
	if editable and not options.is_empty():
		panel.add_child(G.label("CHOISIR LA DATE DE REPRISE", 13, G.GOLD, true))
		var row := HFlowContainer.new()
		row.name = "RepriseOptions"
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		panel.add_child(row)
		for option: Dictionary in options:
			var date := str(option.get("date", ""))
			var caption := "%s\n%s · %d amica%s%s" % [day_text(date).to_upper(), weeks_text(float(option.get("weeks", 0))), int(option.get("friendlies", 0)), "ux" if int(option.get("friendlies", 0)) > 1 else "l", " · habituelle" if bool(option.get("habitual", false)) else ""]
			var button := G.button(caption, func():
				var payload := {"habitual": true} if bool(option.get("habitual", false)) else {"date": date}
				app._command("reprise_choose", payload))
			button.name = "RepriseOption_" + date
			button.tooltip_text = consequences(option.get("effects", {}))
			button.custom_minimum_size = Vector2(170, 58)
			if date == str(club.get("date", "")): G.selected(button, app.accent)
			row.add_child(button)
	var effects: Dictionary = club.get("effects", {}) if club.get("effects") is Dictionary else {}
	var effect_line := G.wrap(consequences(effects), 15, G.INK)
	effect_line.name = "RepriseConsequences"
	panel.add_child(effect_line)
	# Conseil de Gabi.
	var advice: Variant = r.get("advice")
	if advice is Dictionary and editable:
		var card := G.card(panel, app.accent)
		card.name = "RepriseGabi"
		var line := G.h(12)
		card.add_child(line)
		var words := G.v(2)
		G.fill(words)
		line.add_child(words)
		words.add_child(G.label("GABI · CONSEIL", 12, G.GOLD, true))
		words.add_child(G.wrap("« %s » Reprise conseillée : %s." % [str(advice.get("text", "")), day_text(str(advice.get("date", "")))], 15, G.INK))
		if str(advice.get("date", "")) != str(club.get("date", "")):
			var follow := G.button("Suivre le conseil", func():
				var hit := options.filter(func(o): return str(o.get("date", "")) == str(advice.get("date", "")))
				if hit.is_empty(): return
				app._command("reprise_choose", {"habitual": true} if bool(hit[0].get("habitual", false)) else {"date": str(advice.date)}))
			follow.name = "RepriseFollowAdvice"
			line.add_child(follow)
	# Internationaux en congés.
	var internationals: Array = r.get("internationals", [])
	if not internationals.is_empty():
		panel.add_child(G.label("INTERNATIONAUX DE LA TOURNÉE D’ÉTÉ · %d" % internationals.size(), 13, G.GOLD, true))
		panel.add_child(G.wrap("Ils rejoignent le groupe après leurs congés, quel que soit le lundi choisi : la cohésion se construit en deux temps.", 13))
		var list := GridContainer.new()
		list.name = "RepriseInternationals"
		list.columns = 2
		list.add_theme_constant_override("h_separation", 18)
		panel.add_child(list)
		for p: Dictionary in internationals.slice(0, 12):
			var text := "%s · %s · %s" % [str(p.get("name", "")), str(p.get("nation", "")), str(p.get("status", "")).replace(str(p.get("returnDate", "")), day_text(str(p.get("returnDate", "")), false))]
			var cell := G.label(text, 13, G.ALERT if str(p.get("status", "")).begins_with("en congés") else G.MUTED)
			cell.clip_text = true
			cell.custom_minimum_size.x = 340
			list.add_child(cell)
		if internationals.size() > 12: panel.add_child(G.wrap("… et %d autres." % (internationals.size() - 12), 13))
	# Jeunes du centre convoqués pour la préparation.
	var youth: Dictionary = r.get("youth", {})
	var candidates: Array = youth.get("candidates", [])
	if not candidates.is_empty():
		var selected: Array = youth.get("selected", [])
		panel.add_child(G.label("JEUNES DU CENTRE EN PRÉPARATION · %d / %d" % [selected.size(), int(youth.get("max", 8))], 13, G.GOLD, true))
		panel.add_child(G.wrap("Ils complètent le groupe et jouent les amicaux : du temps de jeu, une légère progression, l’occasion de se montrer." + (" Sélection proposée par le staff." if bool(youth.get("staff", false)) else ""), 13))
		var flow := HFlowContainer.new()
		flow.name = "RepriseYouth"
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		panel.add_child(flow)
		for p: Dictionary in candidates:
			var id := str(p.get("id", ""))
			var chosen := selected.has(id)
			var button := G.button("%s · %s · %d ans" % [str(p.get("name", "")), str(p.get("pos", "")), int(p.get("age", 0))], func():
				if not editable: return
				var next := selected.duplicate()
				if next.has(id): next.erase(id)
				elif next.size() < int(youth.get("max", 8)): next.append(id)
				app._command("reprise_youth", {"playerIds": next}))
			button.name = "RepriseYouth_" + id
			button.disabled = not editable
			if chosen: G.selected(button, app.accent)
			flow.add_child(button)
	# Avance pendant la préparation.
	if r.get("today") != null:
		var actions := G.h(10)
		actions.name = "RepriseAdvance"
		panel.add_child(actions)
		var today := str(r.get("calendarToday", ""))
		if club.get("date") != null and str(club.date) > today:
			actions.add_child(G.button("Avancer jusqu’à la reprise  →", func(): app._command("reprise_advance", {"fromDate": today, "until": "reprise"})))
		actions.add_child(G.button("Semaine suivante  →", func(): app._command("reprise_advance", {"fromDate": today, "until": "semaine"})))
		actions.add_child(G.button("Aller à l’ouverture du calendrier  →", func(): app._command("reprise_advance", {"fromDate": today, "until": "saison"}), true))
	var report: Variant = r.get("report")
	if report is Dictionary:
		var minutes := 0
		for y: Dictionary in report.get("youth", []): minutes += int(y.get("minutes", 0))
		var done := G.wrap("Bilan de la préparation %s : reprise le %s, %s, %d match%s amica%s, %d jeune%s du centre pour %d minutes de jeu." % ["(gérée par le staff)" if bool(report.get("auto", false)) else "", day_text(str(report.get("date", "")), false), weeks_text(float(report.get("weeks", 0))), int(report.get("friendlies", 0)), "s" if int(report.get("friendlies", 0)) > 1 else "", "ux" if int(report.get("friendlies", 0)) > 1 else "l", (report.get("youth", []) as Array).size(), "s" if (report.get("youth", []) as Array).size() > 1 else "", minutes], 14, G.INK)
		done.name = "RepriseReport"
		panel.add_child(done)
