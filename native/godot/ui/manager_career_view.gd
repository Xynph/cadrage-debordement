extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const World = preload("res://ui/world_view.gd")

static func _club(app: Control, id: Variant) -> String:
	return World._club(app, id)

static func _player(app: Control, id: String) -> String:
	for p: Dictionary in app.model.get("market", []):
		if p.id == id: return str(p.name)
	for p: Dictionary in app.model.get("squad", []):
		if p.id == id: return str(p.name)
	return "Profil suivi " + id

static func _confirm(app: Control, context: Dictionary, offer: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirmer la prise de poste"
	dialog.dialog_text = "Rejoindre %s en saison %s ?\nLes comptes, joueurs et centres restent dans leur club.\nLes dossiers de recrutement actifs seront clos au changement de bureau.\nAucun salaire personnel ni indemnité de manager." % [_club(app, offer.clubId), int(context.season) + 1]
	dialog.ok_button_text = "Confirmer la saison suivante"
	dialog.cancel_button_text = "Rester sur le carnet"
	dialog.confirmed.connect(func(): app._command("manager_career_accept", {"context":context,"offerId":offer.id,"confirmed":true}); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	dialog.popup_centered(Vector2i(660, 270))

static func build(app: Control) -> Control:
	var page := G.h(18)
	page.name = "CarnetManagerCareer"
	G.fill(page, true)
	var data: Dictionary = app.model.get("clubLife", {}).get("managerCareer", {})
	var context: Dictionary = data.get("context", {})
	var left := G.panel(page, 1.0)
	G.chapter(left, "19", "Votre carrière", "Un poste unique, un parcours conservé.", app.accent)
	var career := G.scroll(left)
	G.photo_note(career, app.model.club, "Votre mandat", G.club_name(app.model.club), "city", 150)
	career.add_child(G.wrap(data.get("notice", "La mobilité reste disponible après la fin de toutes les compétitions."), 14))
	if not data.get("active", false):
		var activate := G.button("ACTIVER LES CANDIDATURES", func(): app._command("manager_career_activate", {"context":context}))
		activate.name = "ManagerCareerActivate"
		activate.disabled = not data.get("available", false)
		career.add_child(activate)
	else:
		career.add_child(G.wrap("Mandat à %s depuis la saison %s" % [_club(app, data.clubId), int(data.currentFrom)], 20, G.INK))
		var pending: Variant = data.get("pending")
		if pending is Dictionary:
			career.add_child(G.section("La prochaine saison", _club(app, pending.toClub)))
			var cancel := G.button("ANNULER LA PRISE DE POSTE", func(): app._command("manager_career_cancel", {"context":context}))
			cancel.name = "ManagerCareerCancel"
			cancel.disabled = not data.get("window", false)
			career.add_child(cancel)
		if data.get("window", false):
			career.add_child(G.section("Candidater", "Les deux divisions sont ouvertes. Une candidature peut être refusée."))
			var opportunities: Array = data.get("opportunities", []).filter(func(o): return not o.applied)
			var select := OptionButton.new()
			select.name = "ManagerCareerClub"
			select.custom_minimum_size.y = 44
			select.fit_to_longest_item = false
			for opportunity: Dictionary in opportunities:
				select.add_item(_club(app, opportunity.clubId) + " · " + {"elite":"Élite","accession":"Accession"}.get(opportunity.leagueId, "Championnat"))
			career.add_child(select)
			var apply := G.button("ENVOYER LA CANDIDATURE", func():
				if select.selected >= 0: app._command("manager_career_apply", {"context":context,"clubId":opportunities[select.selected].clubId}))
			apply.name = "ManagerCareerApply"
			apply.disabled = pending != null or opportunities.is_empty()
			career.add_child(apply)
		else:
			career.add_child(G.wrap("Les candidatures ouvriront après la dernière compétition, avant de lancer la saison suivante.", 16))
		career.add_child(G.section("Offres et candidatures"))
		if data.get("applications", []).is_empty(): career.add_child(G.wrap("Aucune candidature enregistrée.", 14))
		for a: Dictionary in data.get("applications", []):
			career.add_child(G.wrap("S%s · %s" % [int(a.season), _club(app, a.clubId)], 18, G.INK))
			career.add_child(G.wrap({"offer":"La direction accepte votre candidature.","stable":"Le club conserve son technicien.","finances":"La situation financière bloque ce changement.","reputation":"Parcours insuffisant pour les attentes du club.","declined":"Offre refusée.","cancelled":"Prise de poste annulée.","expired":"Offre expirée.","completed":"Prise de poste effectuée."}.get(a.reason, str(a.status)), 14))
			if a.status == "offered" and data.get("window", false) and pending == null:
				var accept := G.button("EXAMINER ET CONFIRMER L’OFFRE", func(): _confirm(app, context, a), true)
				accept.name = "ManagerCareerAccept_" + str(a.clubId)
				career.add_child(accept)
				career.add_child(G.button("REFUSER", func(): app._command("manager_career_decline", {"context":context,"offerId":a.id})))
			career.add_child(G.separator())
	career.add_child(G.section("Le parcours"))
	for h: Dictionary in data.get("history", []):
		career.add_child(G.wrap("S%s · %s → %s" % [int(h.arrivalSeason), _club(app, h.fromClub), _club(app, h.toClub)], 15))
	career.add_child(G.section("Les archives des clubs"))
	for archive: Dictionary in data.get("archives", []):
		career.add_child(G.wrap("%s · S%s · %s écritures conservées · %s bilans du conseil" % [_club(app, archive.clubId), int(archive.season), archive.ledger.size(), archive.boardHistory.size()], 14))
	var seasons: Array = app.model.get("archives",{}).get("seasons",[])
	if seasons.any(func(year: Dictionary): return year.get("japan") is Dictionary and not year.japan.get("pairs",[]).is_empty()):
		var archives := G.button("Archives des saisons · barrages du Japon",func(): app.ClubViews.season_archives(app))
		archives.name = "CareerJapanSeasonArchives"
		career.add_child(archives)
	var right := G.panel(page, 1.2)
	G.chapter(right, "20", "Construire la suite", "Suivis persistants et engagements connus.", app.accent)
	var recruitment := G.scroll(right)
	recruitment.add_child(G.section("Le plan sur trois saisons"))
	for year: Dictionary in data.get("plan", []):
		var season := G.card(recruitment, G.accent_ink(app.accent))
		season.add_child(G.section("Saison %s" % int(year.year), "%s poste(s) fragiles" % int(year.thin)))
		G.gauge(season, "Postes couverts", float(year.covered), 15)
		season.add_child(G.wrap("Masse salariale connue : %s · %s semaines payées" % [G.euros(year.payroll), int(year.payments)], 14))
	recruitment.add_child(G.wrap(data.get("planNotice", ""), 13))
	recruitment.add_child(G.separator())
	recruitment.add_child(G.section("Le carnet du recrutement"))
	var candidates: Array = data.get("recruitment", [])
	if not candidates.is_empty():
		var choose := OptionButton.new()
		choose.name = "ManagerRecruitmentPlayer"
		choose.custom_minimum_size.y = 44
		choose.fit_to_longest_item = false
		for p: Dictionary in candidates: choose.add_item(("★ " if p.watched else "") + _player(app, p.playerId) + " · " + str(p.pos))
		recruitment.add_child(choose)
		var detail := G.v(8)
		recruitment.add_child(detail)
		var draw := func(index: int):
			for child in detail.get_children(): detail.remove_child(child); child.queue_free()
			var p: Dictionary = candidates[index]
			detail.add_child(G.wrap(_player(app, p.playerId), 23, G.INK))
			var follow := G.button("RETIRER DU SUIVI" if p.watched else "SUIVRE CE PROFIL", func(): app._command("manager_recruitment_watch", {"context":context,"playerId":p.playerId}))
			follow.name = "ManagerRecruitmentWatch"
			follow.disabled = not data.get("recruitmentAvailable", false)
			detail.add_child(follow)
			for term: Dictionary in p.get("terms", []):
				detail.add_child(G.wrap("%s saison(s) · %s semaines · salaire demandé %s / sem.\nPrime %s · engagement indicatif %s" % [int(term.years), int(term.payments), G.euros(term.salary), G.euros(term.fee), G.euros(term.knownCommitment)], 14))
			detail.add_child(G.wrap("Salaire demandé à cette date. La négociation peut aboutir à d’autres conditions ; aucune signature depuis ce devis.", 12))
		choose.item_selected.connect(draw)
		draw.call(0)
	recruitment.add_child(G.section("Rapports datés"))
	for report: Dictionary in data.get("reports", []).slice(-8):
		recruitment.add_child(G.wrap("%s · S%s semaine %s · rapport %s" % [_player(app, report.playerId), int(report.season), int(report.week), report.grade], 14))
	return page

