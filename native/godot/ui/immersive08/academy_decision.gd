extends "res://ui/immersive08/academy_entete.gd"
## Écran Formation (découpe de academy_canvas.gd, sans changement) : décision du jeune choisi (promouvoir), file « À décider », pied de page.

func _select(p: Dictionary) -> void:
	state.player = p.id
	selected = p
	for i in rows.get_child_count():
		var child := rows.get_child(i)
		if not child is Button or not child.has_meta("development_id"): continue
		var actif: bool = child.get_meta("development_id", "") == p.id
		load("res://ui/survol_ligne.gd").appliquer(child, actif, Color.TRANSPARENT, app.accent)
	_strip()

# --- Décision du jeune choisi ------------------------------------------------------------------------------------------

## Lettres du staff d'un jeune : [niveau, potentiel] (échelle E- à S+, relative à notre effectif).
func _lettres(p: Dictionary) -> Array:
	var note := Notation.resume(app.model, p, true)
	return [Notation.texte_lettre(int(note.niveau)), Notation.texte_lettre(int(note.potentiel))]

## Raison écrite de chaque ligne de la file « À décider » (données réelles du jeune uniquement).
func _raison(p: Dictionary) -> String:
	var parts: Array[String] = []
	# Notation façon FM : lettres du staff (E- à S+), jamais les chiffres du moteur.
	var lettres := _lettres(p)
	var niveau: String = lettres[0]
	var potentiel: String = lettres[1]
	if _a_decider(p):
		parts.append("Contrat d’espoir à trancher cette saison : %s avant qu’un autre club ne s’y intéresse." % ("le promouvoir" if development.get("promotionAvailable", false) else "décide de son avenir"))
	if _pepite(p): parts.append("Pépite : potentiel estimé %s, niveau %s." % [potentiel, niveau])
	var blessure := float(p.get("injury", 0))
	if blessure > 0: parts.append("Blessé %s ; il manque les prochains matchs." % P.plural(ceili(blessure), "semaine", "semaines"))
	var gain: Variant = _delta(p)
	if gain != null and int(gain) == 0 and int(p.get("age", 0)) >= 20: parts.append("Aucune progression cette saison à %d ans." % int(p.age))
	if parts.is_empty(): parts.append("Niveau %s, potentiel %s." % [niveau, potentiel])
	return " ".join(parts)

func _strip() -> void:
	if strip == null: return
	for enfant in strip.get_children():
		strip.remove_child(enfant)
		enfant.queue_free()
	var fond := D.rect(strip, Rect2(0, 0, WIDTH, 100), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if selected.is_empty():
		Pastilles.poser(strip, Pastilles.pastille("Aucun jeune choisi", Charte.IVOIRE_2, "clock", "Choisis un jeune dans la liste pour décider de son avenir.", 20, "AcademyNoSelection"), 22, 34)
		return
	var p := selected
	var pro := _professional(p)
	D.text(strip, 22, 26, "DÉCISION POUR", 16, Charte.IVOIRE_2, 700, 300)
	var nom := Button.new()
	nom.name = "AcademyDecisionName"
	nom.text = str(p.name)
	nom.flat = true
	nom.alignment = HORIZONTAL_ALIGNMENT_LEFT
	nom.focus_mode = Control.FOCUS_ALL
	nom.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	nom.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	nom.add_theme_font_size_override("font_size", maxi(12, C.px(32)))
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: nom.add_theme_color_override(etat, Charte.IVOIRE)
	var plat := C.box(Color.TRANSPARENT, Color.TRANSPARENT, 8, 0)
	plat.content_margin_left = 0
	nom.add_theme_stylebox_override("normal", plat)
	nom.add_theme_stylebox_override("hover", C.box(Color(Charte.IVOIRE, .06), Color.TRANSPARENT, 8, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 8, 0)
	focus.set_border_width_all(2)
	nom.add_theme_stylebox_override("focus", focus)
	var cible := {"kind":"player" if pro else "academy", "id":str(p.id)}
	nom.accessibility_name = "Ouvrir la fiche · " + str(p.name)
	nom.pressed.connect(func(): app.navigation_controller.open_entity(cible))
	strip.add_child(nom)
	D.place(nom, Rect2(22, 30, 480, 44))
	MiniFiche.lier(app, nom, str(p.id), "squad" if pro else "academy")
	var fin: Variant = p.get("contractEnd")
	var contrat := " · contrat d’espoir jusqu’en %s" % G.contract_year(fin) if (fin is int or fin is float) and not pro else ""
	Kit.texte(strip, 22, 92, "%s · %s ans%s" % [str(p.pos), G.n(p.age), contrat], Charte.IVOIRE_2, 520, 17)
	D.line(strip, Vector2(540, 14), Vector2(540, 86), Charte.FILET)
	if pro:
		var fiche := Kit.lien(strip, Rect2(570, 30, 0, 40), "Ouvrir sa fiche : suivi, contrat, développement →", func(): open_professional_progress(app, str(p.id)), "AcademyOpenProfessional", 19)
		fiche.tooltip_text = ""
		return
	var apercu: Dictionary = app.DevelopmentViews.contract_preview(app.model, p)
	var disponible: bool = development.get("promotionAvailable", false)
	var promouvoir := Kit.bouton_ivoire(strip, Rect2(570, 22, 300, 52), "Promouvoir" if disponible else "Premier contrat pro", func(): _confirmer_promotion(p), "AcademyPromoteSelected")
	promouvoir.set_meta("promote_id", p.id)
	promouvoir.disabled = app.waiting or not disponible
	var x := 900.0
	var termes := str(apercu.get("terms", ""))
	var restriction := str(apercu.get("restriction", ""))
	var capacite := str(apercu.get("capacity", ""))
	var texte_contrat := termes if disponible else (restriction + " " + capacite).strip_edges()
	if disponible:
		var salaire: Variant = p.get("salary")
		var fin_contrat := _saison_courte(season + 1)
		var x_tuile := x
		if salaire is int or salaire is float:
			x_tuile += Pastilles.poser(strip, Pastilles.tuile(Pastilles.euros_courts(salaire), "par semaine", Pastilles.BLEU, Charte.PANNEAU_2, 26, "AcademyContractSalary", false, _ouvrir_fiche.bind(p)), x_tuile, 12) + 8.0
		x_tuile += Pastilles.poser(strip, Pastilles.tuile(fin_contrat, "fin du contrat", Pastilles.TURQUOISE, Charte.PANNEAU_2, 26, "AcademyContractEnd", false, _ouvrir_fiche.bind(p)), x_tuile, 12) + 8.0
		for enfant in strip.get_children():
			if enfant.name in ["AcademyContractSalary", "AcademyContractEnd"]: (enfant as Control).tooltip_text = texte_contrat
	elif not texte_contrat.is_empty():
		var contrat_note := Pastilles.pastille(restriction.trim_suffix(".").replace("Signature indisponible", "Signature impossible") if not restriction.is_empty() else "Places limitées", Pastilles.ORANGE, "warning", texte_contrat, 18, "AcademyContractNote", func(): app._navigate("Effectif"))
		Pastilles.poser(strip, contrat_note, x, 16)
	if not disponible:
		var effectif := Kit.lien(strip, Rect2(x, 56, 0, 34), "Voir l’effectif et les places →", func(): app._navigate("Effectif"), "AcademyOpenSquad", 18)
		effectif.tooltip_text = ""
	elif pathway.get("active", false) and not _path(p).is_empty():
		var salaires: Array = _path(p).get("promotionSalary", [])
		var offre_x := x
		for i in salaires.size():
			var annees := i + 1
			var libelle := "%d saison%s · %s" % [annees, "s" if annees > 1 else "", G.salary(salaires[i])]
			var offre := Kit.lien(strip, Rect2(offre_x, 54, 0, 34), libelle + " →", func(): _confirmer_promotion(p, annees, salaires[annees - 1]), "AcademyOfferYears" + str(annees), 18)
			offre.disabled = pathway.get("locked", false) or not pathway.get("promotionAvailable", false) or app.waiting
			offre.tooltip_text = "Premier contrat professionnel de %d saison%s" % [annees, "s" if annees > 1 else ""]
			offre_x += offre.size.x / C.density + 26
	var intake: Dictionary = app.model.get("clubLife", {}).get("academyIntake", {})
	if intake.get("available", false):
		var revue := Kit.lien(strip, Rect2(WIDTH, 30, 0, 40), "Nouvelle génération : %s à examiner (garder, libérer) →" % P.plural(int(intake.get("players", []).size()), "jeune", "jeunes"), func(): Pages.ouvrir(app, "revue"), "AcademyIntakeOpen", 19, true)
		revue.tooltip_text = ""

## Promotion : confirmation EN PLACE (jamais une fenêtre), puis la commande du moteur.
func _confirmer_promotion(p: Dictionary, annees: int = 0, salaire: Variant = null) -> void:
	if app.waiting or p.is_empty() or _professional(p): return
	var fin_saison := season + (2 if app.model.get("meta", {}).get("phase") == "ended" else 1)
	var lignes: Array = []
	var envoyer: Callable
	if annees == 0:
		lignes.append("%s rejoindra l’effectif professionnel et ajoutera %s de salaire. Fin de contrat à la fin de la saison %s." % [p.name, G.salary(p.get("salary")), G.season_label(fin_saison)])
		envoyer = func(): app._command("promote_academy", {"playerId": p.id, "confirmed": true})
	else:
		lignes.append("%s quittera le centre et ajoutera %s à la masse salariale pour %d saison%s." % [p.name, G.salary(salaire), annees, "s" if annees > 1 else ""])
		var args: Dictionary = pathway.get("context", {}).duplicate()
		args.merge({"playerId": p.id, "years": annees, "confirmed": true})
		envoyer = func(): app._command("academy_promote", args)
	var bloc := EnPlace.ouvrir(app, self, "AcademyPromoteConfirm", "Promouvoir " + str(p.name), lignes, "Confirmer la promotion", envoyer)
	D.place(bloc, Rect2(570, STRIP_TOP - 6, 1100, 10))

func _cartes() -> void:
	if cards == null: return
	for enfant in cards.get_children():
		cards.remove_child(enfant)
		enfant.queue_free()
	var file: Array = []
	for p: Dictionary in Order.ordered(roster, "decide", false, _sort_value):
		if _a_decider(p) or _pepite(p) or float(p.get("injury", 0)) > 0: file.append(p)
	var titre := Kit.titre(cards, 0, 28, "À décider avant la fin de saison", 26, 800)
	titre.name = "AcademyDecisionsTitle"
	if file.is_empty():
		Pastilles.poser(cards, Pastilles.pastille("Aucune décision", Charte.IVOIRE_2, "check", "Aucun jeune ne demande de décision pour le moment.", 20, "AcademyNoDecision"), 0, 56)
		return
	var nombre := mini(4, file.size())
	var largeur := (WIDTH - (nombre - 1) * 14.0) / maxf(1.0, float(nombre)) if nombre > 0 else 0.0
	largeur = minf(largeur, 551.0)
	for i in nombre:
		var p: Dictionary = file[i]
		var carte := Button.new()
		carte.name = "AcademyDecisionCard_" + str(p.id).validate_node_name()
		carte.flat = true
		carte.focus_mode = Control.FOCUS_ALL
		carte.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		carte.accessibility_name = "Décider pour %s : %s" % [str(p.name), _raison(p)]
		var fond := C.box(Charte.PANNEAU_3 if p.id == selected.get("id") else Charte.PANNEAU, Color.TRANSPARENT, 16, 0)
		carte.add_theme_stylebox_override("normal", fond)
		carte.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 16, 0))
		carte.add_theme_stylebox_override("pressed", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 16, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 16, 0)
		focus.set_border_width_all(2)
		carte.add_theme_stylebox_override("focus", focus)
		carte.pressed.connect(func(): _choisir_depuis_carte(p))
		cards.add_child(carte)
		D.place(carte, Rect2(i * (largeur + 14.0), 44, largeur, 142))
		Kit.marqueur(carte, Rect2(14, 18, 8, 96), Charte.IVOIRE if p.id == selected.get("id") else Charte.IVOIRE_2)
		var entete := D.text(carte, 40, 38, "%s, %s, %s ans" % [str(p.name), str(p.pos).to_lower(), G.n(p.age)], 22, Charte.IVOIRE, 700, largeur - 60)
		entete.add_theme_font_override("font", Charte.TITRE_GRAS)
		var raison := _pastilles_raison(p)
		raison.name = "AcademyDecisionReasons"
		carte.add_child(raison)
		D.place(raison, Rect2(40, 62, largeur - 60, 76))
		_ignorer_souris(carte)

## Raison d'une carte « À décider » en pastilles : à trancher, pépite (★ potentiel · niveau), blessure, stagnation ; la phrase
## complète reste en infobulle et dans le nom accessible de la carte.
func _pastilles_raison(p: Dictionary) -> HFlowContainer:
	var flux := HFlowContainer.new()
	flux.add_theme_constant_override("h_separation", C.px(8))
	flux.add_theme_constant_override("v_separation", C.px(6))
	# Notation façon FM : lettres du staff (E- à S+), jamais les chiffres du moteur.
	var lettres := _lettres(p)
	var niveau: String = lettres[0]
	var potentiel: String = lettres[1]
	if _a_decider(p):
		var bulle := "Contrat d’espoir à trancher cette saison : %s avant qu’un autre club ne s’y intéresse." % ("le promouvoir" if development.get("promotionAvailable", false) else "décide de son avenir")
		flux.add_child(Pastilles.pastille("À trancher", Pastilles.ORANGE, "clock", bulle, 18))
	# Pépite : puce étoile puis les deux lettres en pastilles rondes (potentiel, niveau), comme le tableau (25/11).
	if _pepite(p):
		flux.add_child(Pastilles.pastille("pépite", Pastilles.TURQUOISE, "star", "Pépite : potentiel estimé %s, niveau %s." % [potentiel, niveau], 18))
		flux.add_child(_duo_lettres(p, true))
	var blessure := float(p.get("injury", 0))
	if blessure > 0: flux.add_child(Pastilles.pastille("%d sem." % ceili(blessure), Pastilles.ROUGE, "warning", "Blessé %s ; il manque les prochains matchs." % P.plural(ceili(blessure), "semaine", "semaines"), 18))
	var gain: Variant = _delta(p)
	if gain != null and int(gain) == 0 and int(p.get("age", 0)) >= 20: flux.add_child(Pastilles.pastille("Stagne", Pastilles.ORANGE, "clock", "Aucune progression cette saison à %d ans." % int(p.age), 18))
	if flux.get_child_count() == 0: flux.add_child(_duo_lettres(p, false))
	return flux

## Niveau et Potentiel du jeune en pastilles rondes (« niv. » / « pot. » en petit), dans l'ordre voulu.
func _duo_lettres(p: Dictionary, potentiel_d_abord: bool) -> HBoxContainer:
	var duo := HBoxContainer.new()
	duo.name = "AcademyDuoLettres"
	duo.add_theme_constant_override("separation", C.px(6))
	duo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paires := [["pot.", "potential"], ["niv.", "rating"]] if potentiel_d_abord else [["niv.", "rating"], ["pot.", "potential"]]
	for paire: Array in paires:
		var mot := C.label(str(paire[0]), 15, Charte.IVOIRE_2, false, 600)
		mot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		duo.add_child(mot)
		duo.add_child(Notation.porte_pastille(Notation.lettre_champ(p, str(paire[1]), true, app.model), 28.0, "AcademyDuo_" + str(paire[1])))
	return duo

func _ouvrir_fiche(p: Dictionary) -> void:
	app.navigation_controller.open_entity({"kind": "player" if _professional(p) else "academy", "id": str(p.id)})

func _choisir_depuis_carte(p: Dictionary) -> void:
	# La ligne doit exister dans le tableau : le filtre qui la cacherait est levé.
	var deja_visible := shown.any(func(x: Dictionary): return x.id == p.id)
	state.player = p.id
	if not deja_visible:
		state.erase("status"); state.erase("position"); state.erase("search")
		state.group = "professional" if _professional(p) else ("u18" if int(p.get("age", 0)) <= 18 else "u21")
		app._render()
		return
	_select(p)
	_cartes()
	var index := -1
	for i in shown.size():
		if shown[i].id == p.id: index = i
	var defilement := find_child("AcademyPlayerScroll", true, false) as ScrollContainer
	if defilement != null and index >= 0:
		defilement.scroll_vertical = int(maxf(0.0, index * ROW * C.density - defilement.size.y * .5))
	var action := strip.find_child("AcademyPromoteSelected", true, false) as Control
	if action != null and not (action as Button).disabled: action.grab_focus.call_deferred()

func _pied(group: String) -> void:
	D.line(self, Vector2(0, HAUTEUR - 52), Vector2(WIDTH, HAUTEUR - 52), Charte.FILET)
	var total := (professionals if group == "professional" else roster).size()
	var libelle: String = str(GROUPES.get(group, ""))
	var tri := str(TRIS.get(str(state.get("table_sort", "decide")), "colonne choisie"))
	var compte := Pastilles.tuile("%d / %d" % [shown.size(), total], libelle, Charte.IVOIRE, Charte.PANNEAU, 26, "AcademyCount", true)
	compte.tooltip_text = "%d sur %d jeunes · %s · tri : %s" % [shown.size(), total, libelle, tri.to_lower()]
	var x_pied := Pastilles.poser(self, compte, 0, HAUTEUR - 46) + 12.0
	var pepite := Pastilles.pastille("pépite", Charte.IVOIRE_2, "star", "", 18, "AcademyStarLegend")
	x_pied += Pastilles.poser(self, pepite, x_pied, HAUTEUR - 40) + 6.0
	Pastilles.poser(self, Pastilles.info("★ pépite : potentiel estimé ≥ 85. Tri : %s." % tri.to_lower(), "i", "AcademyLegendInfo"), x_pied, HAUTEUR - 41)
	var aide := Pastilles.info("I : aperçu du jeune · Échap : menu", "?", "AcademyShortcuts", 30)
	Pastilles.poser_a_droite(self, aide, WIDTH, HAUTEUR - 43)
