extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const World = preload("res://ui/world_view.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Link = preload("res://ui/entity_link.gd")
const Charte = preload("res://ui/charte.gd")
const Views = preload("res://ui/club_views.gd")
const FENETRE_OFFRE := "CareerOfferFenetre"
## État d'une candidature : un mot, une icône, une couleur (jamais la couleur seule) ; la phrase d'origine reste en infobulle.
const ETATS := {
	"offer": ["Offre reçue", "check", "vert", "La direction accepte ta candidature."],
	"stable": ["Technicien conservé", "shield", "bleu", "Le club conserve son technicien."],
	"finances": ["Finances", "warning", "rouge", "La situation financière bloque ce changement."],
	"reputation": ["Parcours insuffisant", "warning", "orange", "Parcours insuffisant pour les attentes du club."],
	"declined": ["Refusée", "lock", "gris", "Offre refusée."],
	"cancelled": ["Annulée", "lock", "gris", "Prise de poste annulée."],
	"expired": ["Expirée", "hourglass", "gris", "Offre expirée."],
	"completed": ["Effectuée", "check", "vert", "Prise de poste effectuée."],
}

static func _club(app: Control, id: Variant) -> String:
	return World._club(app, id)

static func _player(app: Control, id: String) -> String:
	for p: Dictionary in app.model.get("market", []):
		if p.id == id: return str(p.name)
	for p: Dictionary in app.model.get("squad", []):
		if p.id == id: return str(p.name)
	return "Profil suivi " + id

static func _identite(app: Control, id: Variant) -> Dictionary:
	if app.model.get("club", {}).get("id") == id: return app.model.get("club", {})
	for league: Dictionary in app.model.get("leagues", []):
		for club: Dictionary in league.get("rows", []):
			if club.get("id") == id: return club
	for club: Dictionary in app.model.get("meta", {}).get("catalogue", []):
		if club.get("id") == id: return club
	return {}

static func _couleur(nom: String) -> Color:
	return {"vert": Pastilles.VERT, "bleu": Pastilles.BLEU, "rouge": Pastilles.ROUGE, "orange": Pastilles.ORANGE}.get(nom, Charte.IVOIRE_2)

## Nom cliquable (fiche du club ou du joueur) ; sans destination, simple texte.
static func _lien(app: Control, kind: String, id: Variant, texte: String, taille: int = 20, nom: String = "") -> Control:
	if not Link.available(app, kind, id):
		return C.label(texte, taille, Charte.IVOIRE, true, 700)
	var bouton := Button.new()
	if not nom.is_empty(): bouton.name = nom
	bouton.text = texte
	bouton.set_meta("immersive_style_applied", true)
	C.style_bouton_lien(bouton, taille, true)
	Link.bind(bouton, app, Link.target(kind, id), texte)
	return bouton

static func _rangee(parent: Node, gap: int = 8) -> HFlowContainer:
	var rangee := HFlowContainer.new()
	rangee.add_theme_constant_override("h_separation", gap)
	rangee.add_theme_constant_override("v_separation", gap)
	parent.add_child(rangee)
	return rangee

static func _saison_pastille(saison: Variant) -> Control:
	return Pastilles.pastille(G.season_label(saison), Pastilles.BLEU, "calendar", "", 17)

## Prise de poste : petite fenêtre visuelle (deux écussons, saison, trois pastilles), Échap / ✕ / clic à côté la ferment.
static func _confirm(app: Control, context: Dictionary, offer: Dictionary) -> void:
	var page := app.find_child("ImmersiveManagerCareer", true, false) as Control
	var saison := G.season_label(int(context.season) + 1)
	var accepter := func(): app._command("manager_career_accept", {"context":context,"offerId":offer.id,"confirmed":true})
	if page == null:
		accepter.call()
		return
	var fond := Fenetre.ouvrir(page, FENETRE_OFFRE, "PRISE DE POSTE", "flag", 1000, 540)
	var mien: Dictionary = app.model.get("club", {})
	var autre := _identite(app, offer.clubId)
	for i in 2:
		var club: Dictionary = mien if i == 0 else autre
		var x := 120.0 if i == 0 else 700.0
		if not club.is_empty():
			var ecusson := G.crest(club, C.px(150))
			fond.add_child(ecusson)
			D.place(ecusson, Rect2(x + 25, 96, 150, 160))
		var nom := D.text(fond, x + 100, 296, G.club_name(club) if not club.is_empty() else _club(app, offer.clubId), 28, Charte.IVOIRE, 700, 300, HORIZONTAL_ALIGNMENT_CENTER)
		nom.name = "CareerOfferClub" + str(i)
	var fleche := C.icon("arrow", 44, Charte.IVOIRE_2)
	fond.add_child(fleche)
	D.place(fleche, Rect2(478, 150, 44, 44))
	Pieces.tuile(fond, Rect2(400, 206, 200, 84), saison, "saison", Charte.IVOIRE, "CareerOfferSaison", 34)
	var x := 28.0
	for pastille: Array in [["Effectif inchangé", "people", "Les comptes, joueurs et centres restent dans leur club.", "Effectif"], ["Suivis clos", "search", "Les dossiers de recrutement actifs seront clos au changement de bureau.", "Suivis"], ["Sans salaire", "money", "Aucun salaire personnel ni indemnité de manager.", "Salaire"]]:
		x += Pieces.pastille(fond, x, 340, pastille[0], pastille[1], "CareerOffer" + str(pastille[3]), pastille[2], Charte.IVOIRE, Charte.PANNEAU_3) + 10.0
	D.button(fond, Rect2(28, 430, 450, 62), "Rester sur le carnet", func(): Fenetre.fermer(page, FENETRE_OFFRE), false, "", false, Color("176e49"), "CareerOfferAnnuler")
	D.button(fond, Rect2(522, 430, 450, 62), "Confirmer la saison suivante", func():
		Fenetre.fermer(page, FENETRE_OFFRE)
		accepter.call(), false, "arrow", false, Color("176e49"), "CareerOfferConfirmer")

## Candidatures fermées : vitrine « Clubs à l’écoute » (choix de Léo, 21/11), grisée tant que c'est fermé.
## Trois pastilles en tête, puis huit cartes club ; chaque carte ouvre la fiche du club.
const ETATS_VITRINE := {
	"offer": ["Intéressé", "check", "vert"],
	"stable": ["Technicien en place", "shield", "bleu"],
	"reputation": ["Exigeant", "warning", "orange"],
	"finances": ["Finances", "warning", "rouge"],
}
const VITRINE_COLONNES := 4

static func _attente(app: Control, parent: Node, data: Dictionary) -> void:
	var vue: Variant = data.get("outlook")
	if not vue is Dictionary: return
	parent.add_child(G.section("Clubs à l’écoute"))
	var clubs: Array = (vue.get("clubs", []) as Array).filter(func(c): return c is Dictionary)
	var interesses: Array = clubs.filter(func(c): return c.get("reason") == "offer")
	var tete := _rangee(parent)
	tete.add_child(Pastilles.pastille("%d club%s intéressé%s" % [interesses.size(), "s" if interesses.size() > 1 else "", "s" if interesses.size() > 1 else ""], Pastilles.VERT, "check", "", 18, "VitrineCompte", func(): app._navigate("Classements")))
	tete.add_child(Pastilles.pastille("Réputation %d" % int(vue.get("reputation", 0)), Pastilles.VIOLET, "star", "", 18, "VitrineReputation", func(): app._navigate("Classements")))
	tete.add_child(Pastilles.pastille("%d sem." % int(vue.get("weeksLeft", 0)), Pastilles.TURQUOISE, "hourglass", "", 18, "VitrineSemaines", func(): app._navigate("Calendrier")))
	# Les plus prestigieux d'abord : intéressés, puis les autres.
	var tri := func(a, b): return int(a.get("clubReputation", 0)) > int(b.get("clubReputation", 0))
	interesses.sort_custom(tri)
	var autres: Array = clubs.filter(func(c): return c.get("reason") != "offer")
	autres.sort_custom(tri)
	var vitrine: Array = (interesses.slice(0, 6) + autres.slice(0, 2))
	var grille := GridContainer.new()
	grille.name = "VitrineClubs"
	# Une colonne au départ : la grille ne réclame jamais plus que la largeur de la colonne de gauche.
	grille.columns = 1
	grille.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grille.add_theme_constant_override("h_separation", C.px(10))
	grille.add_theme_constant_override("v_separation", C.px(10))
	parent.add_child(grille)
	for c: Dictionary in vitrine:
		grille.add_child(_carte_club(app, c))
	grille.resized.connect(func(): _colonnes_vitrine(grille))

## Autant de colonnes (4 au plus) que la largeur disponible en contient, sans jamais élargir la colonne.
static func _colonnes_vitrine(grille: GridContainer) -> void:
	var ecart := float(grille.get_theme_constant("h_separation"))
	var carte := 1.0
	for enfant in grille.get_children(): carte = maxf(carte, (enfant as Control).get_combined_minimum_size().x)
	var colonnes := clampi(int(floor((grille.size.x + ecart) / (carte + ecart))), 1, VITRINE_COLONNES)
	if colonnes != grille.columns: grille.columns = colonnes

static func _carte_club(app: Control, c: Dictionary) -> Control:
	var club := _identite(app, c.get("clubId"))
	var cadre := PanelContainer.new()
	cadre.name = "VitrineCarte_%d" % int(c.get("clubId", -1))
	cadre.add_theme_stylebox_override("panel", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, Charte.RAYON_CARTE, 0))
	cadre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var marge := MarginContainer.new()
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cote in ["left", "right", "top", "bottom"]: marge.add_theme_constant_override("margin_" + cote, C.px(10))
	cadre.add_child(marge)
	var colonne := C.v(6)
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marge.add_child(colonne)
	var haut := C.h(10)
	colonne.add_child(haut)
	if not club.is_empty():
		var ecusson := G.crest(club, C.px(48))
		ecusson.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		haut.add_child(ecusson)
	var noms := C.v(2)
	noms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(noms)
	# Noms longs : retour à la ligne plutôt que texte coupé.
	var nom := C.label(G.club_name(club) if not club.is_empty() else _club(app, c.get("clubId")), 20, Charte.IVOIRE, true, 700)
	nom.name = "Nom"
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nom.custom_minimum_size.x = C.px(90)
	noms.add_child(nom)
	var ligue := C.label(Views.competition_name(str(c.get("leagueId", "")), app.model), 14, Charte.IVOIRE_2, true, 600)
	ligue.name = "Championnat"
	ligue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ligue.custom_minimum_size.x = C.px(90)
	noms.add_child(ligue)
	var bas := HFlowContainer.new()
	bas.add_theme_constant_override("h_separation", C.px(6))
	bas.add_theme_constant_override("v_separation", C.px(6))
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(bas)
	var etat: Array = ETATS_VITRINE.get(str(c.get("reason", "")), ["—", "info", "gris"])
	bas.add_child(Pastilles.pastille(etat[0], _couleur(etat[2]), etat[1], "", 16, "Etat"))
	bas.add_child(Pastilles.tuile(str(int(c.get("affinity", 0))), "affinité", Charte.IVOIRE, Charte.PANNEAU_3, 18, "Affinite", true))
	# Grisé tant que les candidatures sont fermées ; la fiche du club reste ouverte au clic.
	cadre.modulate = Color(1, 1, 1, .62)
	Pastilles._ignorer(cadre)
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	if not Link.available(app, "club", c.get("clubId")): return cadre
	# Bouton transparent posé sur toute la carte (le cadre le dimensionne) : survol, focus clavier, clic -> fiche du club.
	var bouton := Button.new()
	bouton.name = "VitrineClub_%d" % int(c.get("clubId", -1))
	bouton.flat = true
	bouton.set_meta("immersive_style_applied", true)
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var vide := StyleBoxFlat.new()
	vide.bg_color = Color.TRANSPARENT
	vide.set_corner_radius_all(C.px(Charte.RAYON_CARTE))
	var survol := vide.duplicate() as StyleBoxFlat
	survol.bg_color = Color(Charte.IVOIRE, .1)
	var focus := vide.duplicate() as StyleBoxFlat
	focus.set_border_width_all(2)
	focus.border_color = Charte.IVOIRE
	for etat_bouton in ["normal", "disabled"]: bouton.add_theme_stylebox_override(etat_bouton, vide)
	for etat_bouton in ["hover", "pressed"]: bouton.add_theme_stylebox_override(etat_bouton, survol)
	bouton.add_theme_stylebox_override("focus", focus)
	cadre.add_child(bouton)
	Link.bind(bouton, app, Link.target("club", c.get("clubId")), nom.text)
	return cadre

static func build(app: Control) -> Control:
	var page := G.h(18)
	page.name = "CarnetManagerCareer"
	G.fill(page, true)
	var data: Dictionary = app.model.get("clubLife", {}).get("managerCareer", {})
	var context: Dictionary = data.get("context", {})
	var left := G.panel(page, 1.0)
	G.chapter(left, "19", "Ta carrière", "", app.accent, str(data.get("notice", "")))
	var career := G.scroll(left)
	G.photo_note(career, app.model.club, "Ton mandat", G.club_name(app.model.club), "city", 150)
	if not data.get("active", false):
		var activate := G.button("ACTIVER LES CANDIDATURES", func(): app._command("manager_career_activate", {"context":context}))
		activate.name = "ManagerCareerActivate"
		activate.disabled = not data.get("available", false)
		career.add_child(activate)
		_attente(app, career, data)
	else:
		var mandat := _rangee(career)
		mandat.add_child(_lien(app, "club", data.clubId, _club(app, data.clubId), 24, "ManagerCareerClubLien"))
		mandat.add_child(Pastilles.pastille("Depuis " + G.season_label(data.currentFrom), Pastilles.BLEU, "calendar", "Mandat depuis la saison " + G.season_label(data.currentFrom), 18, "ManagerCareerDepuis"))
		var pending: Variant = data.get("pending")
		if pending is Dictionary:
			var suite := _rangee(career)
			suite.add_child(Pastilles.pastille("Prochaine saison", Pastilles.VERT, "flag", "", 18, "ManagerCareerProchaine"))
			suite.add_child(_lien(app, "club", pending.toClub, _club(app, pending.toClub), 22, "ManagerCareerProchainClub"))
			var cancel := G.button("ANNULER LA PRISE DE POSTE", func(): app._command("manager_career_cancel", {"context":context}))
			cancel.name = "ManagerCareerCancel"
			cancel.disabled = not data.get("window", false)
			career.add_child(cancel)
		career.add_child(G.section("Candidater"))
		var etat := _rangee(career)
		if data.get("window", false):
			etat.add_child(Pastilles.pastille("Ouvertes", Pastilles.VERT, "mail", "Les deux divisions sont ouvertes. Une candidature peut être refusée.", 18, "ManagerCareerOuvertes"))
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
			etat.add_child(Pastilles.pastille("Fermées", Pastilles.ORANGE, "lock", "Les candidatures ouvriront après la dernière compétition, avant de lancer la saison suivante.", 18, "ManagerCareerFermees"))
			_attente(app, career, data)
		career.add_child(G.section("Offres et candidatures"))
		if data.get("applications", []).is_empty(): career.add_child(Pastilles.pastille("Aucune candidature", Charte.IVOIRE_2, "mail", "", 18, "ManagerCareerAucune"))
		for a: Dictionary in data.get("applications", []):
			var ligne := _rangee(career)
			ligne.add_child(_saison_pastille(a.season))
			ligne.add_child(_lien(app, "club", a.clubId, _club(app, a.clubId), 21))
			var motif: Array = ETATS.get(a.reason, [str(a.status), "info", "gris", ""])
			ligne.add_child(Pastilles.pastille(motif[0], _couleur(motif[2]), motif[1], motif[3], 18, "ManagerCareerEtat_" + str(a.clubId)))
			if a.status == "offered" and data.get("window", false) and pending == null:
				var accept := G.button("EXAMINER ET CONFIRMER L’OFFRE", func(): _confirm(app, context, a), true)
				accept.name = "ManagerCareerAccept_" + str(a.clubId)
				career.add_child(accept)
				career.add_child(G.button("REFUSER", func(): app._command("manager_career_decline", {"context":context,"offerId":a.id})))
			career.add_child(G.separator())
	career.add_child(G.section("Le parcours"))
	for h: Dictionary in data.get("history", []):
		var etape := _rangee(career)
		etape.add_child(_saison_pastille(h.arrivalSeason))
		etape.add_child(_lien(app, "club", h.fromClub, _club(app, h.fromClub), 20))
		etape.add_child(C.icon("arrow", 20, Charte.IVOIRE_2))
		etape.add_child(_lien(app, "club", h.toClub, _club(app, h.toClub), 20))
	career.add_child(G.section("Les archives des clubs"))
	for archive: Dictionary in data.get("archives", []):
		var ligne := _rangee(career)
		ligne.add_child(_lien(app, "club", archive.clubId, _club(app, archive.clubId), 20))
		ligne.add_child(_saison_pastille(archive.season))
		ligne.add_child(Pastilles.tuile(str(archive.ledger.size()), "écritures", Charte.IVOIRE, Charte.PANNEAU_2, 22, "ManagerCareerEcritures_" + str(archive.clubId), true))
		ligne.add_child(Pastilles.tuile(str(archive.boardHistory.size()), "bilans", Charte.IVOIRE, Charte.PANNEAU_2, 22, "ManagerCareerBilans_" + str(archive.clubId), true))
	var seasons: Array = app.model.get("archives",{}).get("seasons",[])
	if seasons.any(func(year: Dictionary): return year.get("japan") is Dictionary and not year.japan.get("pairs",[]).is_empty()):
		var archives := G.button("Archives des saisons · barrages du Japon",func(): app.ClubViews.season_archives(app))
		archives.name = "CareerJapanSeasonArchives"
		career.add_child(archives)
	var right := G.panel(page, 1.2)
	G.chapter(right, "20", "Construire la suite", "", app.accent, str(data.get("planNotice", "")))
	var recruitment := G.scroll(right)
	recruitment.add_child(G.section("Le plan sur trois saisons"))
	for year: Dictionary in data.get("plan", []):
		var season := G.card(recruitment, G.accent_ink(app.accent))
		var tete := _rangee(season)
		tete.add_child(C.label("Saison " + G.season_label(year.year), 24, Charte.IVOIRE, true, 700))
		var fragiles := int(year.thin)
		var texte_fragiles := "%d %s < 2 candidats" % [fragiles, "poste" if fragiles <= 1 else "postes"] if fragiles > 0 else "Tous couverts"
		tete.add_child(Pastilles.pastille(texte_fragiles, Pastilles.ORANGE if fragiles > 0 else Pastilles.VERT, "warning" if fragiles > 0 else "check", "Postes avec moins de deux candidats : %d." % fragiles, 17, "ManagerCareerFragiles" + G.n(year.year), func(): app._navigate("Recrutement")))
		G.gauge(season, "Postes couverts", float(year.covered), 15, Pastilles.VERT if int(year.covered) == 15 else Pastilles.ORANGE)
		var chiffres := _rangee(season)
		chiffres.add_child(Pastilles.tuile(Pastilles.euros_courts(year.payroll), "masse salariale", Charte.IVOIRE, Charte.PANNEAU_2, 24, "ManagerCareerMasse" + G.n(year.year), true, func(): app._navigate("Finances")))
		chiffres.add_child(Pastilles.tuile(str(int(year.payments)), "semaines payées", Charte.IVOIRE, Charte.PANNEAU_2, 24, "ManagerCareerSemaines" + G.n(year.year), true, func(): app._navigate("Finances")))
	recruitment.add_child(G.separator())
	recruitment.add_child(G.section("Le carnet du recrutement"))
	var candidates: Array = data.get("recruitment", [])
	if candidates.is_empty(): recruitment.add_child(Pastilles.pastille("Aucun profil", Charte.IVOIRE_2, "search", "", 18, "ManagerCarnetVide"))
	else:
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
			var entete := _rangee(detail)
			entete.add_child(_lien(app, "player", p.playerId, _player(app, p.playerId), 26, "ManagerRecruitmentLien"))
			entete.add_child(Pastilles.pastille(str(p.pos), Pastilles.BLEU, "", "", 18, "ManagerRecruitmentPoste"))
			entete.add_child(Pastilles.info("Salaire demandé à cette date. La négociation peut aboutir à d’autres conditions ; aucune signature depuis ce devis.", "i", "ManagerRecruitmentInfo"))
			var follow := G.button("RETIRER DU SUIVI" if p.watched else "SUIVRE CE PROFIL", func(): app._command("manager_recruitment_watch", {"context":context,"playerId":p.playerId}))
			follow.name = "ManagerRecruitmentWatch"
			follow.disabled = not data.get("recruitmentAvailable", false)
			detail.add_child(follow)
			for term: Dictionary in p.get("terms", []):
				var devis := _rangee(detail)
				devis.add_child(Pastilles.tuile("%d %s" % [int(term.years), "an" if int(term.years) <= 1 else "ans"], "durée", Charte.IVOIRE, Charte.PANNEAU_2, 24, "ManagerTermDuree", true))
				devis.add_child(Pastilles.tuile(str(int(term.payments)), "semaines", Charte.IVOIRE, Charte.PANNEAU_2, 24, "ManagerTermSemaines", true))
				devis.add_child(Pastilles.tuile(G.salary(term.salary), "salaire demandé", Pastilles.VERT, Charte.PANNEAU_2, 24, "ManagerTermSalaire", true))
				devis.add_child(Pastilles.tuile(Pastilles.euros_courts(term.fee), "prime", Charte.IVOIRE, Charte.PANNEAU_2, 24, "ManagerTermPrime", true))
				devis.add_child(Pastilles.tuile(Pastilles.euros_courts(term.knownCommitment), "engagement", Charte.IVOIRE, Charte.PANNEAU_2, 24, "ManagerTermEngagement", true))
		choose.item_selected.connect(draw)
		draw.call(0)
	recruitment.add_child(G.section("Rapports datés"))
	for report: Dictionary in data.get("reports", []).slice(-8):
		var ligne := _rangee(recruitment)
		ligne.add_child(_lien(app, "player", report.playerId, _player(app, report.playerId), 20))
		ligne.add_child(Pastilles.pastille("%s · S%d" % [G.season_label(report.season), int(report.week)], Pastilles.BLEU, "calendar", "", 17))
		var note := str(report.get("grade")) if report.get("grade") != null else "—"
		ligne.add_child(Pastilles.tuile(note, "note", Charte.IVOIRE, Charte.PANNEAU_2, 22, "ManagerRapportNote", true))
	return page
