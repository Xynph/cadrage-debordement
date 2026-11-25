extends "res://ui/immersive08/recruitment_cout.gd"
## Écran Recrutement : une ligne du tableau (cellules, étoile, action, survol) (découpe de recruitment_canvas.gd, sans changement).

func _cellule(row: Control, id: String, valeur: String, couleur: Color = Charte.IVOIRE, gras: bool = false) -> Label:
	var col := _col(id)
	if col.is_empty(): return null
	var droite: bool = col.align == 2
	var texte := D.text(row, col.x + (col.w if droite else 0), 22, valeur, 20 if gras else 18, couleur, 700 if gras else 600, col.w, HORIZONTAL_ALIGNMENT_RIGHT if droite else HORIZONTAL_ALIGNMENT_LEFT)
	texte.tooltip_text = ""
	return texte

func _observation_text(item: Dictionary, report: Dictionary) -> Array:
	var scouting: Dictionary = item.get("scouting", {}) if item.get("scouting") is Dictionary else {}
	if scouting.get("pending", false):
		var job: Variant = scouting.get("job")
		var reste := ""
		if job is Dictionary and job.get("remainingWeeks") != null: reste = " · " + P.plural(int(job.remainingWeeks), "semaine restante", "semaines restantes")
		return ["◷ Observation en cours" + reste, Charte.IVOIRE]
	if not report.is_empty():
		var source := str(report.get("assessment", {}).get("source", ""))
		return [source if not source.is_empty() else "Rapport conservé", Charte.IVOIRE]
	if _observed(item): return [Sort.report_label(item), Charte.IVOIRE_2]
	return ["Non observé", Charte.IVOIRE_3]

func _row(item: Dictionary, index: int, selected: bool) -> void:
	var player := item if tab != 3 else _market_player(str(item.get("playerId", "")))
	var report: Dictionary = item if tab == 3 else report_by_player.get(str(item.id), {})
	var player_id := str(item.get("playerId", item.id))
	var row := Button.new()
	row.name = "MarketReport_" + str(item.id) if tab == 3 else "MarketPlayer_" + player_id.replace(":", "_")
	row.set_meta("player_id", player_id)
	row.accessibility_name = "%s, %s" % [item.get("name", "Joueur inconnu"), item.get("pos", "Poste inconnu")]
	load("res://ui/survol_ligne.gd").appliquer(row, selected, Color.TRANSPARENT, app.accent)
	table_rows.add_child(row)
	D.place(row, Rect2(0, index * ROW_HEIGHT, WIDTH, ROW_HEIGHT))
	D.line(row, Vector2(0, ROW_HEIGHT - 1), Vector2(WIDTH, ROW_HEIGHT - 1), Color(Charte.FILET, .5))
	var assessment: Dictionary = report.get("assessment", {})
	var suivi: bool = player_id in app.management_ui.shortlist
	_portrait(row, Rect2(56, 2, 28, 28), player, player_id)
	var drapeau := Identity.flag_texture(str(player.get("playerFacts", {}).get("flagCode", "")) if player.get("playerFacts") is Dictionary else "")
	var x_nom := 128.0
	if drapeau != null:
		var image := TextureRect.new()
		image.name = "MarketFlag"
		image.texture = drapeau
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(image)
		D.place(image, Rect2(92, 7, 26, 18))
		x_nom = 128.0
	var ligne_nom := D.text(row, x_nom, 22, str(item.get("name", "—")), 20, Charte.IVOIRE, 700, 300)
	ligne_nom.name = "MarketName"
	if tab == 3:
		_cellule(row, "poste", str(item.get("pos", "—")))
		_cellule(row, "date", str(assessment.get("source", "Date non conservée")), Charte.IVOIRE_2)
		_cellule(row, "obs", _report_label(report), Charte.IVOIRE)
	else:
		_cellule(row, "poste", str(item.get("pos", "—")), Charte.IVOIRE_2)
		var nom_club := _club(item)
		if not nom_club.is_empty(): _cellule(row, "club", nom_club, Charte.IVOIRE_2)
		_cellule(row, "age", G.n(item.get("age", "—")))
		var niveau: Variant = G.knowledge_sort_value(item, "rating")
		_cellule(row, "niveau", G.rating_text(item), Charte.couleur_attribut(niveau) if niveau != null else Charte.IVOIRE_3, true)
		_cellule(row, "potentiel", G.potential_text(item if not item.is_empty() else report), Charte.IVOIRE_2, true)
		var forme := _col("forme")
		if not forme.is_empty() and item.get("formeRecente") is Dictionary:
			Listes.dessiner_forme(self, row, Rect2(forme.x, 1, forme.w, ROW_HEIGHT - 2), item.formeRecente, str(item.get("name", "")), 34.0).name = "MarketForm"
		var attributs := Attributs.detail(item, false)
		if not attributs.is_empty():
			for pair: Array in [["touche", "lineoutThrow"], ["melee", "scrumTechnique"], ["gratt", "jackal"], ["plaq", "tackling"]]:
				var valeur: Variant = attributs.get(pair[1])
				if valeur is int or valeur is float: _cellule(row, pair[0], G.n(valeur), Charte.couleur_attribut(valeur), true)
		var fin: Variant = item.get("contractEnd")
		if fin is int or fin is float: _cellule(row, "fin", G.contract_year(fin), Charte.IVOIRE_2)
		_cellule(row, "indemnite", _money(item.get("fee")), Charte.IVOIRE, true)
		_cellule(row, "salaire", G.salary(item.get("salary")), Charte.IVOIRE_2)
		var observation := _observation_text(item, report)
		_cellule(row, "obs", str(observation[0]), observation[1])
	# Étoile : suivre / ne plus suivre (l'état est dit en mots dans l'infobulle et le nom accessible).
	if tab != 3 and not player.is_empty():
		var etoile := Button.new()
		etoile.name = "Star_" + player_id.replace(":", "_")
		etoile.flat = true
		etoile.text = "★" if suivi else "☆"
		etoile.add_theme_font_override("font", Charte.TITRE_GRAS)
		etoile.add_theme_font_size_override("font_size", maxi(12, C.px(20)))
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]: etoile.add_theme_color_override(etat, Charte.IVOIRE if suivi else Charte.IVOIRE_3)
		etoile.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 8, 0))
		etoile.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 8, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 8, 0)
		focus.set_border_width_all(2)
		etoile.add_theme_stylebox_override("focus", focus)
		etoile.accessibility_name = ("Retirer du suivi : " if suivi else "Suivre cette piste : ") + str(item.get("name", ""))
		etoile.tooltip_text = ""
		var context: Variant = app.model.get("clubLife", {}).get("managerCareer", {}).get("context")
		etoile.disabled = app.waiting or not app._live().is_empty() or app.model.meta.get("phase", "") == "ended" or not context is Dictionary
		etoile.pressed.connect(func(): app._command("manager_recruitment_watch", {"context": context.duplicate(true), "playerId": player_id}))
		row.add_child(etoile)
		D.place(etoile, Rect2(8, 0, 44, ROW_HEIGHT))
	# Action de la ligne : Observer (choisit la piste, le coût s'affiche en bas), En cours, Approcher (écran d'offre).
	if tab != 3 and not player.is_empty():
		var col := _col("action")
		var en_cours: bool = item.get("scouting", {}).get("pending", false) if item.get("scouting") is Dictionary else false
		var approcher: bool = _observed(item) and not en_cours
		var libelle := "En cours" if en_cours else "Approcher" if approcher else "Observer"
		var action := Button.new()
		action.name = "MarketRowAction_" + player_id.replace(":", "_")
		action.text = libelle
		action.focus_mode = Control.FOCUS_ALL
		action.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		C.style_bouton_lien(action, 17)
		action.add_theme_color_override("font_color", Charte.IVOIRE if approcher else Charte.IVOIRE_2)
		action.text = "Approcher →" if approcher else libelle
		action.alignment = HORIZONTAL_ALIGNMENT_LEFT
		action.disabled = en_cours
		action.accessibility_name = "%s : %s" % [libelle, item.get("name", "")]
		action.pressed.connect(func():
			if approcher: _approcher(item)
			else:
				state.player_id = str(item.id)
				_refresh()
				var bloc := cost.find_child("ObserveRecruitment", true, false) as Control
				if bloc != null: bloc.grab_focus.call_deferred())
		row.add_child(action)
		D.place(action, Rect2(col.x + 14, 3, col.w - 44, ROW_HEIGHT - 6))
	# Nom et portrait : survol (ou focus + I) = carte joueur, clic = fiche complète ; « i » juste après le nom.
	var entity_target := {"kind":"report", "id":str(item.id)} if tab == 3 else {"kind":"market", "id":player_id}
	if tab != 3 and not player.is_empty():
		var portrait_lien := _reading_area(row, Rect2(52, 0, 72, ROW_HEIGHT), entity_target, "MarketPortrait_" + str(item.id).validate_node_name(), str(item.get("name", "Dossier")))
		if portrait_lien != null: CarteSurvol.lier(app, portrait_lien, player_id, "market")
	var nom_lien := _reading_area(row, Rect2(x_nom - 4, 0, 330, ROW_HEIGHT), entity_target, "MarketEntity_" + str(item.id).validate_node_name(), str(item.get("name", "Dossier")))
	if tab != 3 and nom_lien != null and not player.is_empty():
		CarteSurvol.lier(app, nom_lien, player_id, "market")
		var police: Font = C.font(700)
		var largeur := minf(300.0, police.get_string_size(str(item.get("name", "—")), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(20))).x / C.density)
		CarteSurvol.icone(app, row, Rect2(x_nom + largeur + 8, 7, 18, 18), player_id, "market")
	if tab != 3 and not report.is_empty():
		var col := _col("obs")
		if not col.is_empty(): _reading_area(row, Rect2(col.x - 4, 0, mini(col.w, 360), ROW_HEIGHT), {"kind":"report", "id":str(report.get("id", ""))}, "MarketReportLink_" + str(report.get("id", "")).validate_node_name(), "Rapport d’observation · " + str(item.get("name", "")))
	row.pressed.connect(func():
		state["report_id" if tab == 3 else "player_id"] = str(item.id)
		var target := str(row.name)
		_refresh()
		var focused := table_rows.get_node_or_null(target) as Button
		if focused != null: FocusLater.grab(focused))
