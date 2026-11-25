extends "res://ui/contextual/match_equipe_composition.gd"
## Onglet Consignes, cartes : point sur le match, avis du staff, plan de jeu, arbitre et ce que fait l'adversaire.
## Chaîne d'héritage de la fenêtre : socle ← outils ← terrain ← composition ← cartes ← consignes ← roles ← match_equipe.gd.

func _espace(hauteur: float) -> Control:
	var vide := Control.new()
	vide.custom_minimum_size.y = px(hauteur)
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return vide

func _entete_groupe(texte: String, sous: String) -> Control:
	var colonne := _v(4)
	var rangee := _h(10)
	var t := _titre_section(texte, 22)
	rangee.add_child(t)
	var precision := _texte(sous, 12, C.MUTED)
	precision.size_flags_vertical = Control.SIZE_SHRINK_END
	rangee.add_child(precision)
	colonne.add_child(rangee)
	var filet := ColorRect.new()
	filet.color = C.LINE
	filet.custom_minimum_size = Vector2(0, maxf(1.0, k))
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(filet)
	return colonne

## Point sur le match sous l'adversaire : score et temps, fatigue moyenne du XV, consignes en place.
func _carte_match(parent: Control, p: Dictionary) -> void:
	var cadre := _panneau(_plat(C.PANEL, Color.TRANSPARENT, 14, "left", 3, true))
	cadre.name = "TeamMatchSummary"
	parent.add_child(cadre)
	var colonne := _v(8)
	cadre.add_child(colonne)
	colonne.add_child(_titre_section("Où en est le match", 15))
	var total := 0.0
	var nombre := 0
	for joueur: Variant in _lineup():
		if joueur is Dictionary and joueur.get("condition") != null:
			total += float(joueur.condition)
			nombre += 1
	var rangee := _h(10)
	colonne.add_child(rangee)
	var score := _titre("%s · %s" % [_score(), _horloge()], 22, C.IVORY, 800)
	score.name = "TeamMatchScore"
	rangee.add_child(_coupe(score))
	if nombre > 0:
		var moyenne := roundi(total / nombre)
		var fatigue := _texte("Fatigue moyenne du XV : %d %%" % moyenne, 14, teinte_energie(float(moyenne)))
		fatigue.name = "TeamMatchFatigue"
		colonne.add_child(_coupe(fatigue))
	var actives := _consignes_actives(p)
	var consignes := _texte("Consignes : " + (", ".join(PackedStringArray(actives)) if not actives.is_empty() else "toutes au cran normal"), 12, C.MUTED)
	consignes.name = "TeamMatchConsignes"
	consignes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consignes.max_lines_visible = 4
	colonne.add_child(consignes)

## Avis du staff en bas de la colonne : ses propositions en attente (avant → après, et pourquoi) et le bouton
## « Appliquer ces consignes » ; sans avis, sa dernière décision du journal.
func _carte_staff(parent: Control, p: Dictionary) -> void:
	var staff: Dictionary = p.get("staff") if p.get("staff") is Dictionary else {}
	var propositions: Array = (staff.get("propositions") if staff.get("propositions") is Array else []).filter(func(x: Variant) -> bool: return x is Dictionary)
	var journal: Array = p.get("journal") if p.get("journal") is Array else []
	var faits: Array = journal.filter(func(e: Variant) -> bool: return e is Dictionary and str(e.get("auteur", "")) == "staff")
	if propositions.is_empty() and faits.is_empty(): return
	# Un seul filet à gauche : menthe quand le staff propose (le titre le dit), sinon aucun.
	var cadre := _panneau(_plat(C.PANEL, C.MINT if not propositions.is_empty() else Color.TRANSPARENT, 14, "left", 3, true))
	cadre.name = "TeamStaffNote"
	parent.add_child(cadre)
	var colonne := _v(8)
	cadre.add_child(colonne)
	if propositions.is_empty():
		colonne.add_child(_titre_section("Le staff", 15))
		var corps := _texte("%d′ · %s" % [int(faits[-1].get("minute", 0)), str(faits[-1].get("texte", ""))], 14, C.IVORY)
		corps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		corps.max_lines_visible = 4
		colonne.add_child(corps)
		return
	var tete := _h(8)
	tete.add_child(_coupe(_titre_section("Le staff conseille · %d′" % int(staff.get("minute", 0)), 15)))
	colonne.add_child(tete)
	var raisons: Array[String] = []
	for x: Dictionary in propositions.slice(0, 3):
		var ligne := _h(6)
		ligne.add_child(_texte(str(x.get("label", "")), 14, C.IVORY, _gras))
		ligne.add_child(_coupe(_texte("%s → %s" % [str(x.get("actuelLabel", "")), str(x.get("valeurLabel", ""))], 14, C.IVORY)))
		colonne.add_child(ligne)
		var raison := str(x.get("raison", ""))
		if not raison.is_empty() and not raison in raisons: raisons.append(raison)
	if not raisons.is_empty():
		var pourquoi := _texte(" ".join(raisons), 12, C.MUTED)
		pourquoi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pourquoi.max_lines_visible = 3
		colonne.add_child(pourquoi)
	var bouton := _bouton("Appliquer ces consignes →", appliquer_staff, "lien", 16, "TeamStaffApply")
	bouton.disabled = bool(app.waiting) or _attente == "staff"
	colonne.add_child(bouton)

func _pied_consignes(infos: HBoxContainer) -> void:
	if not _message.is_empty():
		infos.add_child(_coupe(_texte(_message, 13, _message_teinte)))
		return
	infos.add_child(_coupe(_texte("Les consignes en direct s'appliquent dès la reprise ; le plan de jeu demande l'arrêt du match.", 13, C.MUTED)))

## Plan de jeu (tiroir Tactique d'avant) : avec le ballon, sans le ballon, sur pénalité, en une rangée.
func _plan_de_jeu(colonne: VBoxContainer) -> void:
	var tactiques: Dictionary = _model.get("tactics", {}) if _model.get("tactics") is Dictionary else {}
	if tactiques.is_empty(): return
	var cadre := _panneau(_plat(C.RAISED, Color.TRANSPARENT, 0, "left", 3, true))
	cadre.name = "TeamGamePlan"
	var style := cadre.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = px(14)
	style.content_margin_right = px(14)
	style.content_margin_top = px(10)
	style.content_margin_bottom = px(10)
	colonne.add_child(cadre)
	var rangee := _h(10)
	cadre.add_child(rangee)
	var titre := _titre_section("Plan de jeu", 15)
	titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(titre)
	var autorise: bool = bool(_live().get("paused", false)) and not bool(_live().get("finished", false))
	for trio: Array in [["attack", "attacks", "Avec le ballon", "TeamPlanAttack"], ["defense", "defenses", "Sans le ballon", "TeamPlanDefense"], ["penalty", "penalties", "Sur pénalité", "TeamPlanPenalty"]]:
		var options: Array = tactiques.get(trio[1], []) if tactiques.get(trio[1]) is Array else []
		if options.is_empty(): continue
		var bloc := _v(2)
		bloc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bloc.add_child(_texte(trio[2], 12, C.MUTED))
		var choix := OptionButton.new()
		choix.name = trio[3]
		choix.fit_to_longest_item = false
		choix.clip_text = true
		choix.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		choix.add_theme_font_override("font", C.font(700))
		choix.add_theme_font_size_override("font_size", fs(16))
		# Un seul filet bas (charte §3) ; survol : filet ivoire ; focus : filet bas épais.
		var normal := _boite(C.PANEL, C.LINE, Charte.RAYON_PETIT, 1, 0, true)
		normal.content_margin_left = px(10)
		normal.content_margin_right = px(10)
		normal.content_margin_top = px(5)
		normal.content_margin_bottom = px(5)
		var survol := normal.duplicate() as StyleBoxFlat
		survol.border_color = C.IVORY
		var focus := _boite(Color.TRANSPARENT, C.IVORY, Charte.RAYON_PETIT, 2, 0, true)
		for paire: Array in [["normal", normal], ["hover", survol], ["pressed", survol], ["disabled", normal], ["focus", focus]]: choix.add_theme_stylebox_override(paire[0], paire[1])
		for cle: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: choix.add_theme_color_override(cle, C.IVORY)
		_habiller_menu(choix.get_popup())
		var ids: Array = []
		for option: Variant in options:
			if not option is Dictionary: continue
			choix.add_item(str(option.get("label", "")))
			choix.set_item_tooltip(choix.item_count - 1, str(option.get("description", "")))
			ids.append(option.get("id"))
		var cle_plan: String = trio[0]
		var courant: Variant = tactiques.get(cle_plan)
		choix.select(maxi(0, ids.find(courant)))
		choix.disabled = not autorise
		choix.tooltip_text = "Mets le match en pause pour changer le plan de jeu." if not autorise else str(trio[2])
		choix.item_selected.connect(_choisir_plan.bind(cle_plan, ids))
		bloc.add_child(choix)
		rangee.add_child(bloc)

## Menu déroulant d'un choix (exception permise) en ardoise claire (teinte D) des fenêtres du direct, sans ombre ;
## ligne survolée en case plus claire marquée d'un filet gauche ivoire ; textes ivoire.
func _habiller_menu(menu: PopupMenu) -> void:
	menu.add_theme_stylebox_override("panel", MenuJoueur.style_ardoise(px(6), false))
	var survol := StyleBoxFlat.new()
	survol.bg_color = MenuJoueur.PAL.case
	survol.set_corner_radius_all(0)
	survol.shadow_size = 0
	survol.border_color = Charte.IVOIRE
	survol.border_width_left = maxi(1, px(3))
	menu.add_theme_stylebox_override("hover", survol)
	for cle: String in ["font_color", "font_hover_color", "font_accelerator_color"]: menu.add_theme_color_override(cle, Charte.IVOIRE)
	menu.add_theme_color_override("font_disabled_color", MenuJoueur.PAL.encre3)
	menu.add_theme_color_override("font_separator_color", MenuJoueur.PAL.encre2)
	menu.add_theme_font_override("font", C.font(700))
	menu.add_theme_font_size_override("font_size", fs(16))
	menu.set_meta("habille", true)

func _choisir_plan(index: int, cle_plan: String, ids: Array) -> void:
	if index < 0 or index >= ids.size(): return
	if cle_plan == "penalty": app._command("set_penalty_policy", {"policy": ids[index]})
	else: _plan(cle_plan, ids[index])

## Carte de l'arbitre : photo à gauche, nom, quatre jauges de sévérité (1 à 5) et son profil.
func _carte_arbitre(parent: Control, p: Dictionary) -> void:
	var arbitre: Dictionary = p.get("arbitre") if p.get("arbitre") is Dictionary else {}
	var cadre := PanelContainer.new()
	cadre.name = "TeamReferee"
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	cadre.add_theme_stylebox_override("panel", _plat(C.PANEL, Color.TRANSPARENT, 0, "left", 3, true))
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(cadre)
	var rangee := _h(0)
	cadre.add_child(rangee)
	var nom := str(arbitre.get("nom", ""))
	var cadre_photo := Control.new()
	cadre_photo.custom_minimum_size = Vector2(px(130), px(190))
	cadre_photo.clip_contents = true
	cadre_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_child(cadre_photo)
	if BanqueImages.texture("arbitre") != null:
		var photo := C.photo("arbitre", Vector2.ZERO, true, 0.2)
		photo.name = "TeamRefereePhoto"
		photo.tooltip_text = ""
		S.full(photo)
		cadre_photo.add_child(photo)
	else:
		var lettres := PackedStringArray()
		for mot in nom.split(" ", false): lettres.append(mot.substr(0, 1))
		var initiales := _titre("".join(lettres), 48, C.IVORY)
		initiales.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		cadre_photo.add_child(initiales)
	var marge := MarginContainer.new()
	for cote: String in ["left", "right"]: marge.add_theme_constant_override("margin_" + cote, px(14))
	for cote: String in ["top", "bottom"]: marge.add_theme_constant_override("margin_" + cote, px(12))
	marge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_child(marge)
	var corps := _v(6)
	marge.add_child(corps)
	corps.add_child(_titre_section("L'arbitre", 15))
	var ligne_nom := _coupe(_titre(nom if not nom.is_empty() else "Non désigné", 24, C.IVORY))
	ligne_nom.name = "TeamRefereeName"
	ligne_nom.tooltip_text = (str(arbitre.get("civilite", "")) + " " + nom).strip_edges() + ("\n" + str(arbitre.get("resume", "")) if arbitre.has("resume") else "")
	ligne_nom.mouse_filter = Control.MOUSE_FILTER_PASS
	corps.add_child(ligne_nom)
	for paire: Array in ARBITRE_AXES:
		var niveau := clampi(int(arbitre.get(paire[0], 3)), 1, 5)
		var jauge := _h(8)
		jauge.name = "TeamRefereeGauge_" + str(paire[0])
		jauge.set_meta("niveau", niveau)
		var axe := _texte(paire[1], 12, C.MUTED)
		axe.custom_minimum_size.x = px(58)
		jauge.add_child(axe)
		var crans := _h(2)
		crans.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for n in 5:
			var cran := Panel.new()
			cran.custom_minimum_size = Vector2(px(12), px(8))
			cran.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cran.add_theme_stylebox_override("panel", _plat(C.IVORY if n < niveau else C.LINE))
			crans.add_child(cran)
		jauge.add_child(crans)
		jauge.add_child(_coupe(_texte(ARBITRE_MOTS[niveau], 12, C.ALERT if niveau >= 4 else (C.MINT if niveau <= 2 else C.MUTED))))
		corps.add_child(jauge)
	var resume := _texte(str(arbitre.get("resume", "")), 12, C.IVORY)
	resume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resume.max_lines_visible = 2
	corps.add_child(resume)

func _carte_adversaire(parent: Control, p: Dictionary, vue: Dictionary) -> void:
	var equipes: Array = _live().get("teams", [])
	var club_id := str(_model.get("club", {}).get("id", "")) if _model.get("club") is Dictionary else ""
	var adverse := {}
	for equipe: Variant in equipes:
		if equipe is Dictionary and str(equipe.get("id", "")) != club_id: adverse = equipe
	var nom := S.G.club_name(adverse).to_upper() if not adverse.is_empty() else "L'ADVERSAIRE"
	var cadre := _panneau(_plat(C.PANEL, Color.TRANSPARENT, 14, "left", 3, true))
	cadre.name = "TeamOpponent"
	parent.add_child(cadre)
	var colonne := _v(8)
	cadre.add_child(colonne)
	colonne.add_child(_coupe(_titre_section("Ce que fait " + nom, 19)))
	var source: Dictionary = p.get("adversaire") if p.get("adversaire") is Dictionary else {}
	var puces := HFlowContainer.new()
	puces.name = "TeamOpponentChips"
	puces.add_theme_constant_override("h_separation", px(6))
	puces.add_theme_constant_override("v_separation", px(6))
	puces.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var consignes: Variant = source.get("consignes")
	if consignes is Dictionary:
		for axe_v: Variant in Pilotage.axes(vue):
			if not axe_v is Dictionary or not (consignes as Dictionary).has(str(axe_v.get("id", ""))): continue
			var valeur := str(consignes[str(axe_v.id)])
			if valeur == cran_neutre(axe_v): continue
			for option: Variant in axe_v.get("options", []):
				if option is Dictionary and str(option.get("id", "")) == valeur:
					var dur := str(axe_v.id) in ["rucks", "discipline", "melee"]
					puces.add_child(_puce("%s · %s" % [str(axe_v.label), str(option.label)], C.ALERT if dur else C.IVORY, C.ALERT if dur else C.LINE, 12))
	elif consignes is Array:
		for c: Variant in consignes:
			var texte := str(c.get("label", c.get("texte", ""))) if c is Dictionary else str(c)
			if not texte.is_empty(): puces.add_child(_puce(texte, C.IVORY, C.LINE, 12))
	var causeries: Variant = source.get("causeries")
	if causeries is Dictionary:
		for paire: Array in [["pre", "Avant-match"], ["half", "Pause"]]:
			var c: Variant = (causeries as Dictionary).get(paire[0])
			if c is Dictionary and not str(c.get("label", "")).is_empty(): puces.add_child(_puce("%s : discours %s" % [paire[1], str(c.label).to_lower()], C.IVORY, C.LINE, 12))
	if puces.get_child_count() > 0: colonne.add_child(puces)
	var lignes: Array = []
	for cle: String in ["derniers", "journal", "lignes"]:
		if source.get(cle) is Array:
			var liste: Array = source[cle]
			for k_ in range(liste.size() - 1, -1, -1):
				var ligne: Variant = liste[k_]
				if ligne is Dictionary and not str(ligne.get("texte", "")).is_empty(): lignes.append(("%d′ " % int(ligne.minute) if ligne.get("minute") != null else "") + str(ligne.texte).trim_suffix("."))
				elif ligne is String and not ligne.is_empty(): lignes.append(ligne)
			break
	if not lignes.is_empty():
		var l := _texte(" · ".join(PackedStringArray(lignes.slice(0, 3))), 12, C.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = 3
		colonne.add_child(l)
	if puces.get_child_count() == 0 and lignes.is_empty():
		var rien := _texte("Le staff n'a rien repéré de marquant chez eux pour l'instant.", 12, C.MUTED)
		rien.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		colonne.add_child(rien)
	var lecture := str(source.get("lecture", ""))
	if not lecture.is_empty():
		var l := _texte(lecture, 12, C.MINT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = 3
		colonne.add_child(l)
