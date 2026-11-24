extends "res://ui/immersive08/preparation_socle.gd"
## Préparation, panneaux du dossier adverse : danger, rapport, à faire, forme et face-à-face. Hérite du socle (preparation_socle.gd) ;
## l'écran se lit par preparation_canvas.gd.

## Bandeau « Danger » : la menace principale, lue dans les vrais chiffres du dossier ; le plan conseillé mène aux conseils.
func _danger(section: Control, rectangle: Rect2) -> void:
	var bande := Panel.new()
	bande.name = "PreparationDanger"
	bande.add_theme_stylebox_override("panel", Charte.ombrer_droit(_style(Charte.PANNEAU)))
	section.add_child(bande)
	D.place(bande, rectangle)
	_barre(bande, Rect2(0, 0, 6, rectangle.size.y), Charte.club_trait(app.accent))
	_etiquette(bande, 28, 46, "Danger", 110)
	var texte := _texte(bande, 140, 48, _danger_phrase(), 24, Charte.IVOIRE, 1340)
	texte.name = "PreparationDangerText"
	var conseil: Dictionary = reports.get("advice", {})
	if not conseil.is_empty():
		var tactiques: Dictionary = app.model.get("tactics", {})
		var plan := "Plan conseillé : %s · %s" % [_tactic_label(tactiques.get("attacks", []), conseil.get("attack")), _tactic_label(tactiques.get("defenses", []), conseil.get("defence"))]
		_bouton(bande, Rect2(1520, 13, 708, 50), plan, func(): _ouvrir_sous("conseils"), "lien", "arrow", "PreparationPlanLink")

func _danger_phrase() -> String:
	for signal_row: Dictionary in reports.get("signals", []):
		if signal_row.get("kind") == "warning": return "%s — %s" % [str(signal_row.get("title", "")), str(signal_row.get("evidence", ""))]
	var pire := {}
	var ecart := 0
	for domaine: Dictionary in reports.get("domains", []):
		if not (_nombre(domaine.get("own")) and _nombre(domaine.get("opponent"))): continue
		var difference := int(domaine.opponent) - int(domaine.own)
		if difference > ecart:
			ecart = difference
			pire = domaine
	if not pire.is_empty():
		return "Leur avantage le plus net : %s, %d contre %d pour toi (−%d)." % [str(pire.get("label", "secteur")).to_lower(), int(pire.opponent), int(pire.own), ecart]
	if not reports.get("domains", []).is_empty(): return "Aucun secteur ne penche en leur faveur : tu égales ou tu domines partout."
	var menaces: Array = reports.get("threats", [])
	if not menaces.is_empty(): return "À surveiller : %s (%s)." % [str(menaces[0].get("name", "")), str(menaces[0].get("role", ""))]
	return "Pas de danger précis relevé dans les observations disponibles."

const SECTEURS := {"scrum":"comp", "lineout":"comp", "power":"train", "backs":"plan", "kick":"plan", "discipline":"train"}
const DESTINATIONS := {"comp":"Composition", "plan":"Plan de jeu", "train":"Entraînement"}
const ICONES_ACTION := {"comp":"people", "plan":"tactic", "train":"train"}

func _agir(code: String) -> void:
	match code:
		"comp": app._navigate("Composition")
		"plan": app._navigate("Plan de jeu")
		"train": _choose(2)

## Rapport de force : nous (plein) face à eux (anneau), chiffres écrits, écart en mots ; chaque ligne mène à l'écran d'action.
## Pas des lignes du rapport de force : en petite fenêtre, assez haut pour le secteur et son action écrits l'un sous l'autre.
func _pas_rapport() -> float:
	return maxf(C.reach(44.0), 62.0) if C.dense() else C.reach(44.0)

func _rapport(section: Control, rectangle: Rect2) -> void:
	var domaines: Array = reports.get("domains", [])
	var pas := maxf(_pas_rapport(), (rectangle.size.y - 152.0) / 6.0)
	var panneau := _panneau(section, rectangle, "Rapport de force", "PreparationComparison")
	R.rond(panneau, 20 + R.largeur("RAPPORT DE FORCE", 26, 800) + 16, 31, "Évaluations sur 100, ajustées à la condition.\nÉcart « pour toi » ou « contre toi ».\nClic sur un secteur : composition, plan de jeu ou entraînement.", "i", "PreparationComparisonInfo")
	var nous: Dictionary = app.model.club
	var eux := _opponent()
	for i in 2:
		var club: Dictionary = nous if i == 0 else eux
		var couleur := _couleur_club(club, i == 0)
		var lisere: Color = Charte.club_trait(couleur if couleur.a > 0.0 else Charte.CLUB)
		var x := 24.0 if i == 0 else 1344.0 - 24.0 - 360.0
		var plaque := Panel.new()
		plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plaque.name = "PreparationTagUs" if i == 0 else "PreparationTagThem"
		plaque.add_theme_stylebox_override("panel", _style(Color(lisere, .28), Color.TRANSPARENT) if i == 0 else _style(Color.TRANSPARENT, lisere, 2))
		panneau.add_child(plaque)
		D.place(plaque, Rect2(x, 60, 360, 38))
		if i == 0: _barre(panneau, Rect2(x, 60, 6, 38), lisere)
		if club.get("id") != null and Link.available(app, "club", str(int(club.get("id")))):
			_zone(panneau, C.reach_rect(Rect2(x, 60, 360, 38)), _ouvrir_club.bind(club), "PreparationTagZone" + ("Us" if i == 0 else "Them"), "Ouvrir la fiche · " + G.club_name(club))
		var nom := G.club_name(club)
		var lien := Link.name_link(app, panneau, C.reach_rect(Rect2(x + 14, 60, 250, 38)), "club", str(int(club.get("id", -1))) if club.get("id") != null else "", nom.to_upper(), 21, Charte.IVOIRE, "PreparationOwnLink" if i == 0 else "PreparationOpponentLink")
		if lien is Label: (lien as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_texte(panneau, x + 346, 86, "nous" if i == 0 else "eux", 17, Charte.IVOIRE_2, 80, HORIZONTAL_ALIGNMENT_RIGHT)
	if domaines.is_empty():
		_texte(panneau, 28, 190, "La comparaison par secteur n’est pas disponible.", 22, Charte.IVOIRE_2, 1270)
	var echelle := 330.0
	for i in domaines.size():
		var domaine: Dictionary = domaines[i]
		var y := 108.0 + pas * i
		var code: String = SECTEURS.get(str(domaine.get("key", "")), "")
		var libelle := str(domaine.get("label", "Secteur"))
		_rayer(panneau, Rect2(0, y, 1344, pas - 2), i)
		if not code.is_empty():
			var destination: String = DESTINATIONS[code]
			_survol_ligne(_zone(panneau, Rect2(0, y, 1344, pas), _agir.bind(code), "PreparationSector_" + str(domaine.get("key", i)), "%s : agir dans « %s »" % [libelle, destination]))
		var centre := y + pas / 2.0
		var propre: Variant = domaine.get("own")
		var adverse: Variant = domaine.get("opponent")
		_titre(panneau, 24, centre + 11, G.n(propre) if _nombre(propre) else "—", 32, Charte.IVOIRE, 70)
		if _nombre(propre): _barre(panneau, Rect2(430.0 - echelle * clampf(float(propre) / 100.0, 0, 1), centre - 7, echelle * clampf(float(propre) / 100.0, 0, 1), 14), Charte.VERT_CLAIR)
		_texte(panneau, 590, centre + 7, libelle, 20, Charte.IVOIRE, 300, HORIZONTAL_ALIGNMENT_CENTER).add_theme_font_override("font", Charte.TITRE_GRAS)
		if not code.is_empty():
			# Une icône dit l'écran d'action (la ligne entière est cliquable ; le nom de l'écran est dans l'infobulle).
			var outil := C.icon(ICONES_ACTION[code], 20, Charte.IVOIRE_2)
			outil.name = "PreparationSectorIcon_" + str(domaine.get("key", i))
			panneau.add_child(outil)
			D.place(outil, Rect2(590 + R.largeur(libelle, 20) / 2.0 + 14, centre - 10, 20, 20))
		if _nombre(adverse): _barre(panneau, Rect2(750, centre - 7, echelle * clampf(float(adverse) / 100.0, 0, 1), 14), R.ORANGE).name = "PreparationBarreAdverse" + str(i)
		_titre(panneau, 1090, centre + 11, G.n(adverse) if _nombre(adverse) else "—", 32, Charte.IVOIRE, 70)
		if _nombre(propre) and _nombre(adverse):
			var delta := int(propre) - int(adverse)
			var mot := "+%d pour toi" % delta if delta > 0 else "−%d contre toi" % -delta if delta < 0 else "égalité"
			var couleur_delta: Color = R.VERT if delta > 0 else R.ROUGE if delta < 0 else Charte.N
			_marque(panneau, 1168, centre, 16, "haut" if delta > 0 else "bas" if delta < 0 else "egal", couleur_delta)
			_texte(panneau, 1194, centre + 7, mot, 19, couleur_delta, 140).add_theme_font_override("font", C.font(700))


## À faire avant le match : une ligne cliquable par repère, mêmes vraies données qu'avant.
func _a_faire(section: Control, rectangle: Rect2) -> void:
	var briefing := Briefing.project(app.model)
	var verifs: Array = briefing.checks
	var en_ordre := verifs.filter(func(check: Dictionary): return check.level == "info").size()
	var panneau := _panneau(section, rectangle, "À faire avant le match", "PreparationRecommendation", "%d sur %d en ordre" % [en_ordre, verifs.size()])
	var pas := C.reach(62.0)
	var limite := mini(verifs.size(), 5)
	for index in limite:
		var check: Dictionary = verifs[index]
		var y := 56.0 + pas * index
		_rayer(panneau, Rect2(0, y, rectangle.size.x, pas - 2), index)
		var zone := _survol_ligne(_zone(panneau, Rect2(0, y, rectangle.size.x, pas - 2), Briefing.open_action.bind(app, check.action, _choose.bind(1)), "PreparationBriefing_" + str(check.id), check.detail + "\n" + check.caption))
		zone.accessibility_name = check.title + " · " + check.detail
		# Repère en pastille ✓ / ! + deux mots (21/11) : le titre et le détail restent dans l'infobulle de la ligne.
		var grave: bool = check.level in ["urgent", "important"]
		var teinte: Color = R.ROUGE if check.level == "urgent" else R.ORANGE if check.level == "important" else R.VERT
		_etiquette(panneau, 22, y + pas / 2.0 + 5, str(REPERES.get(str(check.id), "REPÈRE")), 150)
		R.pastille(panneau, 190, y + pas / 2.0 + 7, _repere_court(check), teinte, "warning" if grave else "check", "PreparationBriefingTitle_" + str(check.id), 18).tooltip_text = str(check.title) + " · " + str(check.detail)
		_texte(panneau, rectangle.size.x - 52, y + pas / 2.0 + 5, str(check.caption), 16, Charte.IVOIRE, 215, HORIZONTAL_ALIGNMENT_RIGHT)
		_marque(panneau, rectangle.size.x - 40, y + pas / 2.0, 14, "droite", Charte.IVOIRE_2)
	var pied := 56.0 + pas * limite + 10.0
	var tous := _bouton(panneau, Rect2(14, pied, 330, 44), "Tous les repères (%d)" % verifs.size(), func(): _ouvrir_sous("reperes"), "lien", "", "PreparationBriefingAll")
	tous.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var conseil: Dictionary = reports.get("advice", {})
	var detail := _bouton(panneau, Rect2(350, pied, 250, 44), "Conseils détaillés", func(): _ouvrir_sous("conseils"), "lien", "arrow", "OpenOppositionDossier")
	detail.disabled = reports.is_empty()
	var adopte := _plan_adopte(conseil)
	var adopter := _bouton(panneau, Rect2(rectangle.size.x - 14 - 280, pied, 280, 44), "Plan du staff adopté" if adopte else "Adopter le plan du staff", func(): app._command("set_tactics", {"attack":conseil.attack, "defense":conseil.defence}), "lien", "check" if adopte else "arrow", "PreparationAdoptPlan")
	adopter.disabled = adopte or conseil.is_empty() or not app._live().is_empty() or app.model.meta.get("phase") == "ended"

## Les consignes en place sont déjà celles du plan conseillé par le staff.
func _plan_adopte(conseil: Dictionary) -> bool:
	var tactiques: Dictionary = app.model.get("tactics", {})
	return not conseil.is_empty() and tactiques.get("attack") == conseil.get("attack") and tactiques.get("defense") == conseil.get("defence")

## Deux mots pour un repère : « Jour J », « 2 blessés », « Feuille OK », « 15 h 00 », « Consignes OK »…
func _repere_court(check: Dictionary) -> String:
	match str(check.id):
		"day": return "Jour J"
		"injuries": return str(check.title).get_slice(" ", 0) + " blessé" + ("s" if str(check.title).get_slice(" ", 0) != "1" else "")
		"sheet": return "Feuille OK"
		"selection": return "Feuille incomplète"
		"tactics": return "Consignes OK"
		"press": return "Presse"
		"international":
			var nombre := RegEx.create_from_string("^(\\d+)").search(str(check.detail))
			return (nombre.get_string(1) + " absents") if nombre != null else "Absences"
		"calendar":
			var heure := RegEx.create_from_string("(\\d{1,2}):(\\d{2})").search(str(check.detail))
			return ("%s h %s" % [heure.get_string(1), heure.get_string(2)]) if heure != null else "À vérifier"
		"live": return "Résultat" if str(check.title).begins_with("Résultat") else "En cours"
		"ended": return "Saison close"
	return str(check.title)

const REPERES := {"press":"PRESSE", "selection":"FEUILLE", "day":"JOUR J", "international":"ABSENCES", "injuries":"INFIRMERIE", "sheet":"FEUILLE", "calendar":"RENDEZ-VOUS", "tactics":"CONSIGNES", "live":"MATCH", "ended":"SAISON"}

## Résultat V / N / D de l'adversaire pour une rencontre listée (point de vue du club adverse).
func _issue(resultat: Dictionary) -> String:
	var score: Array = resultat.get("score", [])
	if score.size() != 2: return ""
	var cote := int(resultat.get("side", 0))
	var nous := int(score[cote])
	var eux := int(score[1 - cote])
	return "V" if nous > eux else "D" if nous < eux else "N"

## Forme récente : pastilles V/N/D, derniers résultats cliquables, confrontations directes. Renvoie la hauteur.
func _forme(section: Control, rectangle: Rect2) -> float:
	var recent: Array = reports.get("recent", [])
	var pas := C.reach(26.0)
	var hauteur := 100.0 + 4.0 * pas + 44.0
	var panneau := _panneau(section, Rect2(rectangle.position, Vector2(rectangle.size.x, hauteur)), "Forme récente", "PreparationRecent", "%d résultat%s observé%s" % [recent.size(), "s" if recent.size() > 1 else "", "s" if recent.size() > 1 else ""] if not recent.is_empty() else "")
	var adversaire := _opponent()
	var nom := G.club_name(adversaire)
	Link.name_link(app, panneau, C.reach_rect(Rect2(20, 54, 250, 36)), "club", str(int(adversaire.get("id", -1))) if adversaire.get("id") != null else "", nom.to_upper(), 19, Charte.IVOIRE, "PreparationFormClub")
	var issues: Array[String] = []
	for i in mini(5, recent.size()):
		var issue := _issue(recent[i])
		if issue.is_empty(): continue
		issues.append(issue)
		var pastille := _pastille(panneau, Rect2(290 + (issues.size() - 1) * 48, 58, 40, 28), issue, "PreparationOpponentForm%d" % (issues.size() - 1))
		if Link.available(app, "club", str(int(adversaire.get("id", -1)))):
			var cible := _zone(panneau, C.reach_rect(Rect2(290 + (issues.size() - 1) * 48, 58, 40, 28)), _ouvrir_club.bind(adversaire), "PreparationOpponentFormZone%d" % (issues.size() - 1), "Résultats de %s : ouvrir sa fiche" % nom)
			cible.move_to_front()
			pastille.move_to_front()
	if not issues.is_empty():
		_texte(panneau, 880, 80, "%d V · %d N · %d D" % [issues.count("V"), issues.count("N"), issues.count("D")], 17, Charte.IVOIRE_2, 300, HORIZONTAL_ALIGNMENT_RIGHT)
	if recent.is_empty():
		_texte(panneau, 24, 130, "Résultats adverses non publiés dans ce dossier." if reports.is_empty() else "Aucun résultat adverse enregistré cette saison.", 19, Charte.IVOIRE_2, 850)
	for i in mini(4, recent.size()):
		var resultat: Dictionary = recent[i]
		var score: Array = resultat.get("score", [])
		var cote := int(resultat.get("side", 0))
		var autre := _club(resultat.get("opponentId"))
		var y := 100.0 + pas * i
		var etape := "J" + G.n(int(resultat.get("round", 0)) + 1) if resultat.get("phase") == "league" else str(resultat.get("phase", ""))
		_rayer(panneau, Rect2(0, y, 900, pas - 2), i)
		if autre.get("id") != null and Link.available(app, "club", str(int(autre.get("id")))):
			_survol_ligne(_zone(panneau, Rect2(0, y, 900, pas), _ouvrir_club.bind(autre), "PreparationFormRow%d" % i, "%s · %s : ouvrir la fiche de %s" % [etape, G.club_name(autre), G.club_name(autre)]))
		_texte(panneau, 24, y + pas / 2.0 + 6, etape, 16, Charte.IVOIRE_2, 110)
		Link.name_link(app, panneau, Rect2(130, y, 420, pas), "club", str(int(autre.get("id", -1))) if autre.get("id") != null else "", G.club_name(autre), 18, Charte.IVOIRE, "PreparationFormOpponent%d" % i)
		_titre(panneau, 700, y + pas / 2.0 + 8, "%s–%s" % [G.n(score[cote]), G.n(score[1 - cote])] if score.size() == 2 else "—", 24, Charte.IVOIRE, 120, HORIZONTAL_ALIGNMENT_RIGHT)
		_texte(panneau, 840, y + pas / 2.0 + 6, "dom." if cote == 0 else "ext.", 16, Charte.IVOIRE_2, 54, HORIZONTAL_ALIGNMENT_RIGHT)
	_face_a_face(panneau, 100.0 + 4.0 * pas + 8.0)
	return hauteur

## Confrontations directes (cinq dernières rencontres entre les deux clubs) : pastilles V/N/D et dernier score.
func _face_a_face(panneau: Panel, y: float) -> void:
	var lignes: Array = reports.get("headToHead", [])
	var issues: Array[String] = []
	for i in mini(5, lignes.size()):
		var issue := _issue(lignes[i])
		if not issue.is_empty(): issues.append(issue)
	_etiquette(panneau, 24, y + 24, "Face à eux")
	var adversaire := _opponent()
	var ouvrable := adversaire.get("id") != null and Link.available(app, "club", str(int(adversaire.get("id"))))
	if issues.is_empty():
		var aucune := R.tuile(panneau, C.reach_rect(Rect2(150, y - 2, 250, 36)), "0", "confrontation", Charte.IVOIRE, "PreparationHeadToHeadNone", 26)
		if ouvrable: R.cliquable(aucune, _ouvrir_club.bind(adversaire), "PreparationHeadToHeadNoneOuvrir", "Fiche de " + G.club_name(adversaire))
		return
	if ouvrable:
		_zone(panneau, C.reach_rect(Rect2(0, y - 4, 900, 40)), _ouvrir_club.bind(adversaire), "PreparationHeadToHeadRow", "Confrontations avec %s : ouvrir sa fiche" % G.club_name(adversaire))
		_texte(panneau, 880, y + 26, "Plus", 17, Charte.IVOIRE, 60, HORIZONTAL_ALIGNMENT_RIGHT).add_theme_font_override("font", C.font(700))
	var dernier: Array = lignes[0].get("score", [])
	var cote := int(lignes[0].get("side", 0))
	var lieu := "à domicile" if bool(lignes[0].get("home", cote == 0)) else "à l’extérieur"
	for i in issues.size(): _pastille(panneau, Rect2(150 + i * 44, y + 4, 38, 28), issues[i], "PreparationHeadToHead%d" % i)
	_texte(panneau, 150 + issues.size() * 44 + 12, y + 26, "%d V · %d N · %d D — dernier : %d-%d %s" % [issues.count("V"), issues.count("N"), issues.count("D"), int(dernier[cote]), int(dernier[1 - cote]), lieu], 17, Charte.IVOIRE_2, 560)
