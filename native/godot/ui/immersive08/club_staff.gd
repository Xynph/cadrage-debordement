extends "res://ui/immersive08/club_installations.gd"
## Écran Club, onglets Staff et Direction : responsables, diagnostic, contrats et engagements.

## Onglet Staff, colonne de gauche (DA du 20/11/2026, sans cadre ni numéro) : les responsables (visage, rôle, nom :
## clic = fiche du membre), le diagnostic de la semaine, puis contrats et engagements (chaque ligne mène quelque part).
const STAFF_GAUCHE := 540.0

static func _staff(card: Control, app: Control) -> void:
	var people := _members(app)
	var largeur := STAFF_GAUCHE
	var montres := 4
	for i in mini(montres, people.size()):
		var person: Dictionary = people[i]
		var y := 70.0 + i * 68.0
		if i > 0: D.line(card, Vector2(12, y), Vector2(largeur - 12, y), Charte.FILET)
		var visage := person.duplicate(true)
		visage.portraitRole = "staff"
		var portrait := G.portrait_lazy(0, C.px(52), visage)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)
		D.place(portrait, Rect2(20, y + 6, 48, 54))
		Kit.texte(card, 84, y + 26, str(person.get("roleLabel", person.get("role", "Encadrement"))), Charte.IVOIRE_2, largeur - 108, 16)
		var nom := Kit.texte(card, 84, y + 54, Kit.casse(str(person.get("name", "—"))), Charte.IVOIRE, largeur - 300, 19)
		nom.add_theme_font_override("font", Kit.texte_gras())
		if person.get("contractEnd") != null: Kit.texte(card, largeur - 24, y + 54, "fin " + G.season_label(person.contractEnd), Charte.IVOIRE_2, 200, 16, HORIZONTAL_ALIGNMENT_RIGHT)
		var staff_id := str(person.get("id", ""))
		var target := {"kind": "staff", "id": staff_id}
		_reading_area(app, card, Rect2(16, y + 4, 56, 58), target, "ClubStaffPortrait_" + staff_id.validate_node_name(), str(person.get("name", "")))
		_reading_area(app, card, Rect2(80, y + 34, largeur - 300, 28), target, "ClubStaffName_" + staff_id.validate_node_name(), str(person.get("name", "")))
	if people.is_empty():
		Kit.texte(card, 24, 100, "Annuaire indisponible pour cette carrière.", Charte.IVOIRE, largeur - 48, 19).name = "ClubStaffNone"
		Kit.texte(card, 24, 128, "Les responsabilités du staff restent accessibles.", Charte.IVOIRE_2, largeur - 48, 17)
	elif people.size() > montres:
		Kit.texte(card, 24, 70 + montres * 68 + 32, "+ %d autres membres dans le tableau" % (people.size() - montres), Charte.IVOIRE_2, largeur - 48, 17).name = "ClubStaffMore"

## Le compact (shell.gd) habille la page Staff : elle porte déjà ses styles de la charte ; seul le thème par défaut suit.
static func style_staff(detail: Control, accent: Color) -> void:
	if detail == null: return
	detail.theme = Legacy.theme(accent)

## Diagnostic de la semaine : trois valeurs du travail du club, le signe « ! » double toujours la couleur d'alerte.
static func _staff_diagnostic(card: Control, app: Control) -> void:
	var diagnostic: Dictionary = app.model.get("clubLife", {}).get("clubSupport", {}).get("diagnostic", {})
	var largeur := STAFF_GAUCHE
	if diagnostic.is_empty():
		Kit.texte(card, 24, 96, "Diagnostic indisponible dans cette carrière.", Charte.IVOIRE_2, largeur - 48, 18).name = "ClubStaffDiagnosticNone"
	else:
		var fatigue: Variant = diagnostic.get("fatigue")
		var alerte: bool = (fatigue is int or fatigue is float) and float(fatigue) > 0
		var ecrire := func(valeur: Variant) -> String: return G.n(valeur) if valeur is int or valeur is float else ("—" if valeur == null else str(valeur))
		var rows := [["Condition moyenne", ecrire.call(diagnostic.get("mean")), false], ["Moral du groupe", ecrire.call(diagnostic.get("morale")), false], ["Joueurs sous 65 de condition", ("! " if alerte else "") + ecrire.call(fatigue), alerte]]
		# Constat du staff : un compte « sous 85 » plutôt qu'une phrase (la phrase reste en info-bulle de la ligne).
		var fatigues: Variant = diagnostic.get("tired")
		if fatigues is int or fatigues is float:
			rows.append(["Joueurs sous 85 de condition", ("! " if float(fatigues) > 0 else "") + ecrire.call(fatigues), float(fatigues) > 0])
		for i in rows.size():
			var y := 70.0 + i * 34.0
			var ligne := Button.new()
			ligne.name = "ClubStaffDiagnosticRow%d" % i
			StaffTable.styler_rangee(ligne)
			ligne.accessibility_name = "%s · %s · travail du club" % [rows[i][0], rows[i][1]]
			ligne.pressed.connect(func(): app._navigate("Travail du club"))
			if i == 3: ligne.tooltip_text = str(diagnostic.get("reason", ""))
			card.add_child(ligne)
			D.place(ligne, Rect2(12, y, largeur - 24, 34))
			Kit.texte(ligne, 12, 23, str(rows[i][0]), Charte.IVOIRE, 360, 18)
			var valeur := Kit.texte(ligne, largeur - 36, 23, str(rows[i][1]), Charte.PERTE if rows[i][2] else Charte.IVOIRE, 120, 18, HORIZONTAL_ALIGNMENT_RIGHT)
			valeur.add_theme_font_override("font", Kit.texte_gras())
		var raison := str(diagnostic.get("reason", ""))
		if rows.size() < 4 and not raison.is_empty(): _texte_lignes(card, 24, 180, largeur - 48, raison, 16, Charte.TEXTE, Charte.IVOIRE_2, 2).name = "ClubStaffDiagnosticReason"
	_lien(card, Rect2(18, 258, 0, 34), "Travail du club →", func(): app._navigate("Travail du club"), "ClubStaffWork", 18)

## Contrats et engagements : chaque ligne ouvre la sous-page ou le tableau qui la détaille.
static func _staff_contrats(card: Control, app: Control) -> void:
	var largeur := STAFF_GAUCHE
	var people := _members(app)
	var saison := int(app.model.get("meta", {}).get("season", 0))
	var fin_saison := people.filter(func(p: Dictionary): return p.get("contractEnd") != null and int(p.contractEnd) <= saison).size()
	var vie: Dictionary = app.model.get("clubLife", {})
	var carriere: Dictionary = vie.get("staffCareer", {})
	var mentorat: Dictionary = vie.get("staffMentoring", {})
	var emploi: Dictionary = vie.get("staffEmployment", {})
	var lecture: Dictionary = app.StaffViews.reading(app)
	var vers_tableau := func(onglet: int):
		lecture.navigation_id = ""
		lecture.tab = onglet; lecture.page = 0; lecture.search = ""; lecture.scroll = 0
		app.management_ui.erase("club_page")
		if app.route != "Staff": app._navigate("Staff")
		else: app._render()
	var lignes: Array = [{"id": "ClubStaffCount", "texte": "Membres en poste", "valeur": G.n(people.size()), "action": vers_tableau.bind(0)}]
	if fin_saison > 0 or not people.is_empty(): lignes.append({"id": "ClubStaffContractsEnding", "texte": "Contrats finissant cette saison", "valeur": G.n(fin_saison), "action": vers_tableau.bind(0)})
	if carriere.get("active", false): lignes.append({"id": "ClubStaffCandidates", "texte": "Candidats disponibles", "valeur": G.n(carriere.get("candidates", []).size()), "action": vers_tableau.bind(1)})
	if mentorat.get("available", false):
		var duos: int = mentorat.get("assignments", []).size()
		lignes.append({"id": "ClubStaffMentoring", "texte": "Mentorat des jeunes", "valeur": "aucun duo" if duos == 0 else "%d duo%s" % [duos, "s" if duos > 1 else ""], "action": func(): Pages.ouvrir(app, "mentorat")})
	if emploi.get("enabled", false): lignes.append({"id": "ClubStaffBudget", "texte": "Budget du staff", "valeur": G.salary(emploi.get("weeklyWages", 0)), "action": func(): Pages.ouvrir(app, "engagements")})
	for i in mini(5, lignes.size()):
		var donnees: Dictionary = lignes[i]
		var ligne := Button.new()
		ligne.name = str(donnees.id)
		StaffTable.styler_rangee(ligne)
		ligne.accessibility_name = "%s · %s" % [donnees.texte, donnees.valeur]
		ligne.pressed.connect(donnees.action)
		card.add_child(ligne)
		D.place(ligne, Rect2(12, 70.0 + i * 34.0, largeur - 24, 34))
		Kit.texte(ligne, 12, 23, str(donnees.texte), Charte.IVOIRE, 330, 18)
		var valeur := Kit.texte(ligne, largeur - 36, 23, str(donnees.valeur) + " →", Charte.IVOIRE, 160, 18, HORIZONTAL_ALIGNMENT_RIGHT)
		valeur.add_theme_font_override("font", Kit.texte_gras())

static func _staff_detail(app: Control, canvas: Control) -> void:
	# Revue FM27 n° 22 (choix A de Léo) : vue « par service » par défaut ; « Tout le staff » rend ce tableau.
	if StaffServices.actif(app):
		StaffServices.build(app, canvas)
		return
	if app.route == "Staff": StaffServices.bascule(app, canvas, false)
	var gauche := STAFF_GAUCHE
	var blocs := [[214.0, 404.0, "L’encadrement", "ClubStaffPeople"], [634.0, 306.0, "Diagnostic de la semaine", "ClubStaffDiagnostic"], [956.0, 288.0, "Contrats et engagements", "ClubStaffContracts"]]
	var panneaux: Array[Panel] = []
	for bloc: Array in blocs:
		var panneau := _panneau(canvas, Rect2(0, float(bloc[0]), gauche, float(bloc[1])), str(bloc[2]), str(bloc[3]))
		# Titre sur toute la largeur de la colonne (jamais coupé en « … »).
		panneau.add_theme_stylebox_override("panel", Charte.style_panneau())
		var titre := panneau.get_node_or_null("CardTitle") as Label
		if titre != null: titre.size.x = (gauche - 48.0) * C.density
		panneaux.append(panneau)
	_staff(panneaux[0], app)
	_staff_diagnostic(panneaux[1], app)
	_staff_contrats(panneaux[2], app)
	var droite := gauche + 22.0
	var fond := D.rect(canvas, Rect2(droite, 214, W - droite, 1030), Charte.PANNEAU, 0)
	fond.add_theme_stylebox_override("panel", Charte.style_panneau())
	fond.name = "ClubStaffTable"
	var detail: Control = app.StaffViews.build(app) if app.route == "Staff" else app.SupportViews.build(app)
	var tabs: TabContainer = detail.find_child("SupportTabs", true, false)
	if tabs != null:
		tabs.current_tab = clampi(int(app.management_ui.get("immersive08_support_tab",0)), 0, 2)
		tabs.tab_changed.connect(func(index: int): app.management_ui.immersive08_support_tab = index)
	U.place_detail(canvas, Rect2(droite + 24, 230, W - droite - 48, 998), detail)
	if app.route == "Staff":
		style_staff(detail, app.accent)
		return
	Legacy.apply(detail, app.accent)
	# Habillage de la charte (boutons secondaires en liens) sans perdre la hauteur de clic des boutons (plancher 28 px).
	var hauteurs := {}
	for bouton: Button in detail.find_children("*", "Button", true, false): hauteurs[bouton] = bouton.custom_minimum_size.y
	Habillage._charte(detail)
	for bouton: Button in hauteurs:
		if is_instance_valid(bouton): bouton.custom_minimum_size.y = maxf(bouton.custom_minimum_size.y, float(hauteurs[bouton]))

static func _direction(app: Control, corps: Control) -> void:
	_lien(corps, Rect2(0, 220, 0, 34), "Ouvrir les finances →", func(): app._navigate("Finances"), "ClubDirectionFinance")
	var detail: Control = app.StrategyViews.build(app)
	var tabs: TabContainer = detail.find_child("StrategyTabs", true, false)
	if tabs != null:
		tabs.current_tab = clampi(int(app.management_ui.get("immersive08_strategy_tab", 1)), 0, 2)
		tabs.tab_changed.connect(func(index: int): app.management_ui.immersive08_strategy_tab = index)
	U.place_detail(corps, Rect2(0, 262, W, 960), detail)
	Legacy.apply(detail, app.accent)
	Habillage._charte(detail)
	Habillage._suivre_ajouts(detail)
