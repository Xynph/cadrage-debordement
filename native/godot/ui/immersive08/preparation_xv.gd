extends "res://ui/immersive08/preparation_dossier.gd"
## Préparation, bas du dossier et sous-pages : joueurs à surveiller, leur XV probable (bande et tableau), sous-pages repères, conseils,
## planning et reprise. Hérite de preparation_dossier.gd ; l'écran se lit par preparation_canvas.gd.

## Joueurs à surveiller : portrait, nom cliquable, poste, âge, note, rôle.
func _surveiller(section: Control, rectangle: Rect2) -> void:
	var panneau := _panneau(section, rectangle, "Joueurs à surveiller", "PreparationThreats")
	var menaces: Array = reports.get("threats", [])
	var club_id := int(_opponent().get("id", -1))
	var haut_carte := rectangle.size.y - 58.0 - 52.0
	if menaces.is_empty():
		_texte(panneau, 24, 110, "Liste adverse non publiée dans le dossier." if reports.is_empty() else "Aucun joueur projeté à surveiller.", 22, Charte.IVOIRE_2, 1200)
	for i in mini(3, menaces.size()):
		var menace: Dictionary = menaces[i]
		var x := 20.0 + i * 436.0
		var carte := Panel.new()
		carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carte.name = "PreparationThreat%d" % i
		carte.add_theme_stylebox_override("panel", Charte.ombrer_droit(_style(Charte.PANNEAU_2)))
		panneau.add_child(carte)
		D.place(carte, Rect2(x, 58, 420, haut_carte))
		if _joueur_ouvrable(menace, club_id): _zone_joueur(carte, Rect2(0, 0, 420, haut_carte), menace, club_id, "PreparationThreatCard%d" % i)
		if not str(menace.get("id", "")).is_empty():
			var portrait := G.portrait(0, 0, menace)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			carte.add_child(portrait)
			D.place(portrait, Rect2(8, 8, 104, haut_carte - 16))
		else:
			var neutre := C.icon("people", 48, Charte.IVOIRE_3)
			carte.add_child(neutre)
			D.place(neutre, Rect2(32, 40, 48, 48))
		_lien_joueur(carte, Rect2(122, 4, 212, 34), menace, 21, "PreparationThreatName%d" % i, club_id)
		var age := "  ·  %d ans" % int(menace.get("age", 0)) if _nombre(menace.get("age")) else ""
		_texte(carte, 126, 60, "%s%s" % [str(menace.get("pos", "")), age], 16, Charte.IVOIRE_2, 205)
		var note: Variant = menace.get("note")
		# Danger du joueur (les étoiles ont été rejetées par Léo le 21/11/2026, le chiffre le 24/11) : sa note au poste en
		# LETTRE E- à S+ (échelle du Niveau, double « B/A » si le staff n'est pas sûr) si elle est connue, sinon le Niveau
		# estimé d'après l'observation du recrutement, sinon « ? » non observé ; mot toujours écrit dessous.
		var fourchette := Savoir.bounds(menace, "rating")
		var lettre := Notation.lettre_note(app.model, menace, float(note) if _nombre(note) else -1.0, false, "poste" if _nombre(note) else "niveau")
		var legende := "Au poste" if _nombre(note) else "Niveau" if not fourchette.is_empty() and int(lettre.bas) >= 0 else "Non observé"
		var taille_p := 44.0
		var large := Notation.largeur_note(lettre, taille_p)
		var pastille := Notation.pastille_note(carte, 400 - large, 32, lettre, taille_p, "PreparationThreatLevel%d" % i)
		pastille.set_meta("valeur", Notation.texte_note(lettre))
		# Petite fenêtre : la légende sous la pastille mordrait sur le poste du joueur ; elle passe en infobulle.
		var etiquette := _etiquette(carte, 400 - large / 2.0, 72, legende, 110, HORIZONTAL_ALIGNMENT_CENTER)
		etiquette.name = "PreparationThreatLevelLabel%d" % i
		if C.dense():
			etiquette.visible = false
			pastille.tooltip_text = legende
		_texte(carte, 126, 112, str(menace.get("role", "")), 16, Charte.IVOIRE, 285)
		if _nombre(menace.get("fitness")) and not C.dense(): _texte(carte, 126, 130, "Condition %d %%" % int(menace.fitness), 15, Charte.IVOIRE_2, 285)
	var signaux: Array = reports.get("signals", [])
	var phrase := ("%d signa%s" % [signaux.size(), "ux" if signaux.size() > 1 else "l"]) if not signaux.is_empty() else "Non observé" if reports.is_empty() else "—"
	if signaux.is_empty():
		# Rien à ouvrir : simple constat, sans flèche ni lien.
		_texte(panneau, 24, rectangle.size.y - 20, phrase, 18, Charte.IVOIRE_2, 1200)
	else:
		var fin := _bouton(panneau, Rect2(14, rectangle.size.y - 48, 260, 44), phrase, func(): _ouvrir_sous("conseils"), "lien", "arrow", "PreparationSignalsLink")
		fin.tooltip_text = "Signaux relevés : détails dans les conseils"
		fin.alignment = HORIZONTAL_ALIGNMENT_LEFT

## Leur XV probable, en bande de quinze cases : numéro, nom (fiche), poste, remarque de l'adjoint ; le tableau complet est une sous-page.
func _xv_bande(section: Control, rectangle: Rect2, adversaire: Dictionary) -> float:
	var club_id := int(adversaire.get("id", -1))
	var donnees: Dictionary = ClubSheet.cached(app, club_id) if club_id >= 0 else {}
	if donnees.is_empty():
		var attente := _panneau(section, Rect2(rectangle.position, Vector2(rectangle.size.x, 110)), "Leur XV probable", "PreparationTheirXI")
		_texte(attente, 24, 90, "Le XV probable de %s se prépare…" % G.club_name(adversaire), 20, Charte.IVOIRE_2, 1500)
		if club_id >= 0: ClubSheet.request(app, club_id)
		return 110.0
	var xv: Dictionary = donnees.get("xv", {})
	var effectif := {}
	for joueur: Dictionary in donnees.get("squad", []): effectif[str(joueur.get("id", ""))] = joueur
	var menaces := {}
	for menace: Dictionary in reports.get("threats", []): menaces[str(menace.get("id", ""))] = str(menace.get("role", ""))
	var adjoint := _adjoint()
	var hauteur_case := 140.0
	var hauteur := 56.0 + hauteur_case + 12.0
	var panneau := _panneau(section, Rect2(rectangle.position, Vector2(rectangle.size.x, hauteur)), "Leur XV probable", "PreparationTheirXI")
	var tableau := "Tableau détaillé · remarques de %s" % str(adjoint.get("name", "")) if not adjoint.is_empty() else "Tableau détaillé · remarques du staff"
	_bouton(panneau, Rect2(rectangle.size.x - 20 - 760, 6, 760, 44), tableau, func(): _ouvrir_sous("xv"), "lien", "arrow", "PreparationTheirXIAll")
	_bouton(panneau, Rect2(420, 6, 420, 44), "Rapport adverse", func(): _ouvrir_sous("adversaire"), "lien", "arrow", "PreparationRapportAdverseLien")
	_marque(panneau, rectangle.size.x - 20 - 760 - 200, 28, 14, "losange", Charte.IVOIRE)
	_texte(panneau, rectangle.size.x - 20 - 760 - 178, 34, "à surveiller", 16, Charte.IVOIRE_2, 170)
	var largeur := 135.0
	for index in 15:
		var emplacement: Dictionary = {}
		for candidat: Dictionary in xv.get("slots", []):
			if int(candidat.get("jersey", 0)) == index + 1: emplacement = candidat
		var joueur: Dictionary = effectif.get(str(emplacement.get("id", "")), {})
		var x := 14.0 + index * (largeur + 14.0)
		var cellule := Panel.new()
		cellule.name = "PreparationTheirXICell%d" % (index + 1)
		cellule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cellule.add_theme_stylebox_override("panel", Charte.ombrer_droit(_style(Charte.PANNEAU_2)))
		panneau.add_child(cellule)
		D.place(cellule, Rect2(x, 56, largeur, hauteur_case))
		if not joueur.is_empty() and _joueur_ouvrable(joueur, club_id): _zone_joueur(cellule, Rect2(0, 0, largeur, hauteur_case), joueur, club_id, "PreparationTheirXICellZone%d" % (index + 1))
		_anneau(cellule, Rect2(8, 6, 40, 26), str(index + 1))
		if joueur.is_empty():
			_texte(cellule, 8, 64, "Non pourvu", 15, Charte.IVOIRE_2, largeur - 12)
			continue
		var menace := str(menaces.get(str(joueur.get("id", "")), ""))
		if not menace.is_empty(): _marque(cellule, largeur - 24, 19, 14, "losange", Charte.IVOIRE)
		var lien := _lien_joueur(cellule, Rect2(2, 34, largeur - 4, 28), joueur, 17, "PreparationTheirXIName_%d" % (index + 1), club_id, PersonName.surname(str(joueur.get("name", ""))))
		lien.set_meta("jersey", index + 1)
		# Poste entier (jamais tronqué) : une ou deux lignes ; la remarque prend les lignes restantes.
		var lignes_poste := D.words(str(joueur.get("pos", "")), 15, 2)
		for ligne in lignes_poste.size(): _texte(cellule, 8, 80 + ligne * 17, lignes_poste[ligne], 15, Charte.IVOIRE_2, largeur - 8)
		var remarque := _remarque(joueur, menace)
		# Dans la case, seule la première remarque tient ; le tableau détaillé donne les deux.
		var lignes_remarque := D.words(str(remarque[0]).split("  ·  ")[0], 17, 4 - lignes_poste.size())
		for ligne in lignes_remarque.size():
			_texte(cellule, 8, 80 + (lignes_poste.size() + ligne) * 17 + 2, lignes_remarque[ligne], 15, Charte.D if remarque[1] else Charte.IVOIRE, largeur - 12)
	return hauteur

## Petit anneau numéroté (cases du XV) : jamais une couleur seule, le numéro est écrit.
func _anneau(parent: Control, rectangle: Rect2, libelle: String) -> void:
	var anneau := Panel.new()
	anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _style(Color.TRANSPARENT, Charte.IVOIRE_2, 2)
	style.set_corner_radius_all(maxi(1, C.px(rectangle.size.y / 2.0)))
	anneau.add_theme_stylebox_override("panel", style)
	parent.add_child(anneau)
	D.place(anneau, rectangle)
	D.text(anneau, rectangle.size.x / 2.0, rectangle.size.y / 2.0 + 6, libelle, 17, Charte.IVOIRE, 700, rectangle.size.x, HORIZONTAL_ALIGNMENT_CENTER)

## « Préparer la suite » et « La reprise » : écrans pleins (aucune fenêtre), contenus des vrais ateliers du jeu.
func _sous_externe(section: Control, sous_page: String) -> float:
	_retour(section)
	var titre := "Préparer la suite du club" if sous_page == "planning" else "La reprise"
	var panneau := _panneau(section, Rect2(0, 66, 2248, 880), titre, "PreparationSub_" + sous_page)
	var hote := Control.new()
	hote.name = "PreparationSubHost"
	hote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panneau.add_child(hote)
	D.place(hote, Rect2(20, 66, 2208, 796))
	if sous_page == "planning": load("res://ui/manager_planning.gd").embed(app, hote)
	else: load("res://ui/reprise_dialog.gd").embed(app, hote)
	return 66.0 + 880.0

func _sous_xv(section: Control) -> float:
	_retour(section)
	var adversaire := _opponent()
	if adversaire.is_empty(): return 70.0
	return 66.0 + _xv_tableau(section, Rect2(0, 66, 2248, 0), adversaire)

## Leur XV probable : tableau des 15 titulaires, note, matchs, essais, et remarque de l'adjoint dérivée des vraies statistiques.
func _xv_tableau(section: Control, rectangle: Rect2, adversaire: Dictionary) -> float:
	var club_id := int(adversaire.get("id", -1))
	var donnees: Dictionary = ClubSheet.cached(app, club_id) if club_id >= 0 else {}
	var pas := C.reach(34.0)
	var adjoint := _adjoint()
	var legende := "Remarques de %s" % str(adjoint.get("name", "")) if not adjoint.is_empty() else "Remarques du staff"
	if donnees.is_empty():
		var attente := _panneau(section, Rect2(rectangle.position, Vector2(rectangle.size.x, 150)), "Leur XV probable", "PreparationTheirXITable")
		_texte(attente, 24, 100, "Le XV probable de %s se prépare…" % G.club_name(adversaire), 22, Charte.IVOIRE_2, 1500)
		if club_id >= 0: ClubSheet.request(app, club_id)
		return 150.0
	var xv: Dictionary = donnees.get("xv", {})
	var effectif := {}
	for joueur: Dictionary in donnees.get("squad", []): effectif[str(joueur.get("id", ""))] = joueur
	var menaces := {}
	for menace: Dictionary in reports.get("threats", []): menaces[str(menace.get("id", ""))] = str(menace.get("role", ""))
	var hauteur := 100.0 + 15.0 * pas + 92.0
	var panneau := _panneau(section, Rect2(rectangle.position, Vector2(rectangle.size.x, hauteur)), "Leur XV probable", "PreparationTheirXITable", "Entrée sur un joueur : sa fiche · losange : à surveiller")
	var colonnes := [["N°", 24.0, 60.0, HORIZONTAL_ALIGNMENT_RIGHT], ["Joueur", 108.0, 420.0, HORIZONTAL_ALIGNMENT_LEFT], ["Poste", 548.0, 300.0, HORIZONTAL_ALIGNMENT_LEFT], ["Âge", 850.0, 70.0, HORIZONTAL_ALIGNMENT_RIGHT], ["Matchs", 1030.0, 90.0, HORIZONTAL_ALIGNMENT_RIGHT], ["Titul.", 1130.0, 90.0, HORIZONTAL_ALIGNMENT_RIGHT], ["Essais", 1230.0, 90.0, HORIZONTAL_ALIGNMENT_RIGHT], ["Note moy.", 1330.0, 110.0, HORIZONTAL_ALIGNMENT_RIGHT]]
	# Le niveau n'est affiché que si le staff le connaît (données de la fiche du club) : jamais une colonne de tirets.
	var niveau_connu: bool = effectif.values().any(func(p: Dictionary): return _nombre(p.get("rating")))
	if niveau_connu: colonnes.insert(4, ["Niveau", 930.0, 90.0, HORIZONTAL_ALIGNMENT_RIGHT])
	for colonne: Array in colonnes:
		var gauche: float = colonne[1] + (colonne[2] if colonne[3] == HORIZONTAL_ALIGNMENT_RIGHT else 0.0)
		_etiquette(panneau, gauche, 86, str(colonne[0]), colonne[2], colonne[3])
	_etiquette(panneau, 1480, 86, "Remarque de ton adjoint" if not adjoint.is_empty() else "Remarque du staff", 740)
	for index in 15:
		var emplacement: Dictionary = {}
		for candidat: Dictionary in xv.get("slots", []):
			if int(candidat.get("jersey", 0)) == index + 1: emplacement = candidat
		var joueur: Dictionary = effectif.get(str(emplacement.get("id", "")), {})
		var y := 100.0 + pas * index
		var centre := y + pas / 2.0
		_rayer(panneau, Rect2(0, y, rectangle.size.x, pas - 2), index)
		_titre(panneau, 84, centre + 9, str(index + 1), 24, Charte.IVOIRE_2, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		if joueur.is_empty():
			_texte(panneau, 108, centre + 7, "Poste non pourvu", 18, Charte.IVOIRE_2, 420)
			continue
		var menace := str(menaces.get(str(joueur.get("id", "")), ""))
		if not menace.is_empty(): _marque(panneau, 6, centre, 12, "losange", Charte.IVOIRE)
		var nom := _lien_joueur(panneau, Rect2(108, y, 420, pas), joueur, 19, "PreparationTheirXIName_%d" % (index + 1), club_id)
		nom.set_meta("jersey", index + 1)
		_texte(panneau, 548, centre + 7, str(joueur.get("pos", "")), 17, Charte.IVOIRE_2, 300)
		_texte(panneau, 920, centre + 7, G.n(joueur.get("age")) if _nombre(joueur.get("age")) else "—", 18, Charte.IVOIRE_2, 70, HORIZONTAL_ALIGNMENT_RIGHT)
		var niveau: Variant = joueur.get("rating")
		# Niveau adverse : lettre du staff (échelle de notre effectif), jamais le chiffre du moteur.
		if niveau_connu:
			var l_adv := Notation.lettre_champ(joueur, "rating", _nombre(niveau), app.model) if _nombre(niveau) else {"bas": -1, "haut": -1}
			if int(l_adv.bas) >= 0: Notation.pastille_note(panneau, 1020 - Notation.largeur_note(l_adv, 30), centre, l_adv, 30, "PreparationTheirXILevel_%d" % (index + 1))
			else: _texte(panneau, 1020, centre + 7, "—", 19, Charte.IVOIRE_3, 90, HORIZONTAL_ALIGNMENT_RIGHT)
		_texte(panneau, 1120, centre + 7, str(int(joueur.get("matches", 0))), 18, Charte.IVOIRE, 90, HORIZONTAL_ALIGNMENT_RIGHT)
		_texte(panneau, 1220, centre + 7, str(int(emplacement.get("starts", joueur.get("starts", 0)))), 18, Charte.IVOIRE, 90, HORIZONTAL_ALIGNMENT_RIGHT)
		_texte(panneau, 1320, centre + 7, str(int(joueur.get("tries", 0))), 18, Charte.IVOIRE, 90, HORIZONTAL_ALIGNMENT_RIGHT)
		var moyenne: Variant = joueur.get("average")
		_texte(panneau, 1440, centre + 7, ("%.1f" % float(moyenne)).replace(".", ",") if _nombre(moyenne) else "—", 18, Charte.IVOIRE, 110, HORIZONTAL_ALIGNMENT_RIGHT)
		var remarque := _remarque(joueur, menace)
		if not str(remarque[0]).is_empty():
			var ligne := _texte(panneau, 1480, centre + 7, str(remarque[0]), 17, Charte.D if remarque[1] else Charte.IVOIRE, 740)
			ligne.name = "PreparationTheirXIRemark_%d" % (index + 1)
	var bas := 100.0 + 15.0 * pas + 38.0
	_etiquette(panneau, 24, bas, "Banc probable")
	var banc: Array = xv.get("bench", [])
	var ids: Array = banc.map(func(e: Dictionary): return str(e.get("id", ""))) if not banc.is_empty() else xv.get("probableBench", [])
	var x := 200.0
	var pose := 0
	for pid: Variant in ids:
		var joueur: Dictionary = effectif.get(str(pid), {})
		if joueur.is_empty() or pose >= 8: continue
		var nom := str(joueur.get("name", ""))
		var largeur := _largeur(nom, 18, true) + 16
		_lien_joueur(panneau, Rect2(x, bas - 26, largeur, 34), joueur, 18, "PreparationTheirBench%d" % pose, club_id)
		x += largeur + 14
		pose += 1
	if not adjoint.is_empty():
		_texte(panneau, 24, hauteur - 14, "Remarques lues dans les statistiques du dossier par", 15, Charte.IVOIRE_2, 520)
		Link.name_link(app, panneau, C.reach_rect(Rect2(520, hauteur - 40, 500, 34)), "staff", str(adjoint.get("id", "")), "%s, %s" % [str(adjoint.get("name", "")), str(adjoint.get("roleLabel", "adjoint")).to_lower()], 17, Charte.IVOIRE, "PreparationAdjointLink")
	else: _texte(panneau, 24, hauteur - 14, legende + " : tirées des statistiques de la saison.", 15, Charte.IVOIRE_2, 1200)
	return hauteur

## Remarque de l'adjoint pour un joueur adverse : disponibilité, rôle signalé par le dossier, puis statistiques ; omise sans donnée.
func _remarque(joueur: Dictionary, menace: String) -> Array:
	var morceaux := PackedStringArray()
	var grave := false
	if int(joueur.get("injury", 0)) > 0:
		morceaux.append("Blessé (%d sem.)" % int(joueur.get("injury", 0)))
		grave = true
	elif int(joueur.get("suspension", 0)) > 0:
		morceaux.append("Suspendu")
		grave = true
	elif joueur.get("onInternationalDuty", false): morceaux.append("En sélection nationale")
	if not menace.is_empty(): morceaux.append(menace)
	var essais := int(joueur.get("tries", 0))
	if essais >= 2: morceaux.append("%d essais cette saison" % essais)
	if int(joueur.get("playerOfMatch", 0)) > 0: morceaux.append("Homme du match × %d" % int(joueur.get("playerOfMatch", 0)))
	var retenus := PackedStringArray()
	for i in mini(2, morceaux.size()): retenus.append(morceaux[i])
	return ["  ·  ".join(retenus), grave]

## ---- Sous-pages du dossier ---------------------------------------------------------------------------

func _retour(section: Control) -> void:
	var retour := _bouton(section, Rect2(0, 0, 560, 50), "←  Retour au dossier adverse", func(): _ouvrir_sous(""), "lien", "", "PreparationSubBack")
	retour.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _sous_reperes(section: Control) -> float:
	_retour(section)
	var verifs: Array = Briefing.project(app.model).checks
	var pas := C.reach(92.0)
	var hauteur := 84.0 + pas * maxi(1, verifs.size()) + 24.0
	var panneau := _panneau(section, Rect2(0, 66, 2248, hauteur), "Avant le coup d’envoi", "PreparationAllChecks", "%d repères" % verifs.size())
	for index in verifs.size():
		var check: Dictionary = verifs[index]
		var y := 64.0 + pas * index
		_rayer(panneau, Rect2(0, y, 2248, pas - 2), index)
		var zone := _survol_ligne(_zone(panneau, Rect2(0, y, 2248, pas - 2), Briefing.open_action.bind(app, check.action, func(): _choose(1)), "PreparationBriefingAll_" + str(check.id), check.detail))
		zone.accessibility_name = check.title + " · " + check.detail
		var grave: bool = check.level in ["urgent", "important"]
		var teinte: Color = Charte.D if check.level == "urgent" else Charte.N if check.level == "important" else Charte.V
		_etiquette(panneau, 70, y + pas / 2.0 + 6, str(REPERES.get(str(check.id), "REPÈRE")), 170)
		# Plus de phrase d'aide (21/11) : pastille ✓ / ! + deux mots, le titre et le détail restent dans l'infobulle.
		R.pastille(panneau, 250, y + pas / 2.0 + 7, _repere_court(check), teinte, "warning" if grave else "check", "PreparationAllChecksTitle_" + str(check.id), 20).tooltip_text = str(check.title) + " · " + str(check.detail)
		_texte(panneau, 2188, y + pas / 2.0 + 7, str(check.caption), 19, Charte.IVOIRE, 420, HORIZONTAL_ALIGNMENT_RIGHT)
		_marque(panneau, 2204, y + pas / 2.0, 14, "droite", Charte.IVOIRE_2)
	return 66.0 + hauteur

## Le plan proposé par le staff : barres du rapport de force, pastilles d'effet (preparation_consignes.gd).
func _sous_conseils(section: Control) -> float:
	return Consignes.conseils(self, section)
