extends "res://ui/immersive08/academy_decision.gd"
## Écran Formation (découpe de academy_canvas.gd, sans changement) : tableau des jeunes (colonnes, lignes, courbes, noms, drapeaux).

# --- Tableau -----------------------------------------------------------------------------------------------------------

func _columns() -> Array:
	if active_tab == 1:
		return [{"id":"num", "titre":"#", "tri":"source", "x":22.0, "w":40.0, "align":1}, {"id":"name", "titre":"JOUEUR", "tri":"name", "x":132.0, "w":420.0, "align":0},
			{"id":"pos", "titre":"POSTE", "tri":"pos", "x":580.0, "w":200.0, "align":0}, {"id":"age", "titre":"ÂGE", "tri":"age", "x":800.0, "w":70.0, "align":2},
			{"id":"start", "titre":"NIV. EN JUILLET", "tri":"start", "x":890.0, "w":170.0, "align":2}, {"id":"note", "titre":"NIV.", "tri":"note", "x":1080.0, "w":80.0, "align":2},
			{"id":"trend", "titre":"SAISONS PASSÉES", "tri":"", "x":1220.0, "w":520.0, "align":0},
			{"id":"minutes", "titre":"MINUTES", "tri":"minutes", "x":1780.0, "w":140.0, "align":2}, {"id":"status", "titre":"STATUT", "tri":"status", "x":1950.0, "w":290.0, "align":0}]
	return [{"id":"num", "titre":"#", "tri":"source", "x":22.0, "w":40.0, "align":1}, {"id":"name", "titre":"JOUEUR", "tri":"name", "x":132.0, "w":420.0, "align":0},
		{"id":"pos", "titre":"POSTE", "tri":"pos", "x":580.0, "w":190.0, "align":0}, {"id":"age", "titre":"ÂGE", "tri":"age", "x":790.0, "w":70.0, "align":2},
		{"id":"note", "titre":"NIV.", "tri":"note", "x":880.0, "w":80.0, "align":2}, {"id":"potential", "titre":"POTENTIEL", "tri":"potential", "x":980.0, "w":150.0, "align":2},
		{"id":"minutes", "titre":"MINUTES", "tri":"minutes", "x":1180.0, "w":130.0, "align":2},
		{"id":"contract", "titre":"FIN DU CONTRAT", "tri":"contract", "x":1350.0, "w":170.0, "align":2}, {"id":"status", "titre":"STATUT", "tri":"status", "x":1570.0, "w":670.0, "align":0}]

func _col(columns: Array, id: String) -> Dictionary:
	for col: Dictionary in columns:
		if col.id == id: return col
	return {}

func _table(group: String) -> void:
	var columns := _columns()
	var panel := D.rect(self, Rect2(0, TABLE_TOP, WIDTH, HEADER_H + ROWS_H + 4), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	panel.name = "AcademyImmersiveTable"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var header := D.rect(panel, Rect2(0, 0, WIDTH, HEADER_H), Color.TRANSPARENT, 0)
	header.name = "AcademyHeader"
	Bandeau.peindre_entete(header)
	for col: Dictionary in columns:
		var key: String = col.tri
		if key.is_empty():
			D.text(header, col.x, 23, str(col.titre), 16, Charte.IVOIRE_2, 700, col.w)
			continue
		var tri := Button.new()
		tri.name = "AcademySort_" + key
		var actif := str(state.get("table_sort", "decide")) == key
		tri.text = str(col.titre) + ((" ↓" if state.get("table_descending", false) else " ↑") if actif else " ↕")
		tri.flat = true
		tri.alignment = HORIZONTAL_ALIGNMENT_RIGHT if col.align == 2 else HORIZONTAL_ALIGNMENT_CENTER if col.align == 1 else HORIZONTAL_ALIGNMENT_LEFT
		tri.clip_text = true
		tri.add_theme_font_override("font", Charte.TITRE_GRAS)
		tri.add_theme_font_size_override("font_size", maxi(12, C.px(16)))
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: tri.add_theme_color_override(etat, Charte.IVOIRE if actif else Charte.IVOIRE_2)
		tri.add_theme_color_override("font_hover_color", Charte.IVOIRE)
		tri.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 8, 0))
		tri.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 8, 0))
		tri.add_theme_stylebox_override("pressed", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 8, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 8, 0)
		focus.set_border_width_all(2)
		tri.add_theme_stylebox_override("focus", focus)
		tri.tooltip_text = "Trier par " + str(col.titre).to_lower() + " · valeurs inconnues en dernier"
		tri.pressed.connect(_sort_by.bind(key))
		header.add_child(tri)
		D.place(tri, Rect2(col.x - 8, 0, col.w + 16, HEADER_H))
	var scroll := ScrollContainer.new()
	scroll.name = "AcademyPlayerScroll"
	scroll.mouse_force_pass_scroll_events = false
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	D.place(scroll, Rect2(0, HEADER_H, WIDTH, ROWS_H))
	rows = Control.new()
	rows.name = "AcademyImmersiveRows"
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.custom_minimum_size = Vector2(C.px(WIDTH), C.px(ROW * maxi(1, shown.size()) + BAS_TABLEAU))
	scroll.add_child(rows)
	_draw_rows(columns)
	scroll.get_v_scroll_bar().value_changed.connect(func(value): state.table_scroll = value)
	scroll.set_deferred("scroll_vertical", int(state.get("table_scroll", 0)))

func _sort_by(key: String) -> void:
	state.table_descending = not state.get("table_descending", false) if state.get("table_sort", "decide") == key else key in ["note", "potential", "change"]
	state.table_sort = key
	state.table_scroll = 0
	app._render()
	U.focus(app, "AcademySort_" + key)

func _draw_rows(columns: Array) -> void:
	if shown.is_empty():
		D.text(rows, 24, 52, "Aucun jeune ne correspond.", 26, Charte.IVOIRE, 600, 1301)
		var efface := Kit.lien(rows, Rect2(24, 66, 0, 36), "Effacer les filtres →", func():
			state.erase("status"); state.erase("position"); state.erase("search")
			app._render(), "AcademyClearFilters", 19)
		efface.tooltip_text = ""
		return
	for i in shown.size():
		var p: Dictionary = shown[i]
		var status := _status(p)
		var hit := Button.new()
		hit.name = "AcademyRow_" + str(p.id).replace(":", "_")
		hit.focus_mode = Control.FOCUS_ALL
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.set_meta("development_id", p.id)
		hit.set_meta("zebra", i % 2)
		hit.accessibility_name = "%s · %s · %s" % [str(p.name), str(p.pos), str(status[0])]
		hit.tooltip_text = ""
		rows.add_child(hit)
		D.place(hit, Rect2(0, i * ROW, WIDTH, ROW))
		hit.pressed.connect(func(): _select(p))
		load("res://ui/survol_ligne.gd").appliquer(hit, p.id == selected.get("id"), Color.TRANSPARENT, app.accent)
		_cellule(hit, _col(columns, "num"), G.n(_source_index(p) + 1), Charte.IVOIRE_2)
		_portrait(hit, p, Rect2(64, 1, 28, 28))
		_drapeau(hit, p, Rect2(98, 6, 26, 18))
		var nom := D.text(hit, 132, 21, str(p.name), 20, Charte.IVOIRE, 700, 340)
		nom.name = "AcademyNom"
		_cellule(hit, _col(columns, "pos"), str(p.pos), Charte.IVOIRE_2)
		_cellule(hit, _col(columns, "age"), G.n(p.age), Charte.IVOIRE)
		var niveau: Variant = G.knowledge_sort_value(p, "rating")
		var niv_cellule := _cellule(hit, _col(columns, "note"), G.rating_text(p, true), Charte.couleur_attribut(niveau) if niveau != null else Charte.IVOIRE_3, true)
		var fl_niv: Dictionary = Fleches.donnees(app, p).get("niveau", {})
		if niv_cellule != null and not fl_niv.is_empty(): Fleches.marquer(app, niv_cellule, int(fl_niv.cran), fl_niv.serie, "Niveau", "Niveau_" + str(p.id).replace(":", "_"))
		var potentiel: Variant = G.knowledge_sort_value(p, "potential")
		if not _col(columns, "potential").is_empty():
			var texte_pot := ("★ " if _pepite(p) else "") + G.potential_text(p)
			_cellule(hit, _col(columns, "potential"), texte_pot, Charte.couleur_attribut(potentiel) if potentiel != null else Charte.IVOIRE_3, true)
		var gain: Variant = _delta(p)
		if not _col(columns, "change").is_empty():
			var colonne_gain := _col(columns, "change")
			var mot := "—" if gain == null else ("▲ +%d" % int(gain)) if int(gain) > 0 else ("▼ %d" % int(gain)) if int(gain) < 0 else "—"
			_cellule(hit, colonne_gain, mot, Charte.V if gain != null and int(gain) > 0 else Charte.D if gain != null and int(gain) < 0 else Charte.IVOIRE_3, true)
		if not _col(columns, "start").is_empty():
			var depart: Variant = p.get("development", {}).get("seasonStart")
			_cellule(hit, _col(columns, "start"), G.n(depart) if depart is int or depart is float else "—", Charte.IVOIRE_2)
		if not _col(columns, "trend").is_empty(): _courbe(hit, p, _col(columns, "trend"))
		_cellule(hit, _col(columns, "minutes"), G.n(_minutes(p)) + " min", Charte.IVOIRE_2)
		if not _col(columns, "contract").is_empty():
			var fin: Variant = p.get("contractEnd")
			var colonne_fin := _col(columns, "contract")
			_cellule(hit, colonne_fin, G.contract_year(fin) if fin is int or fin is float else "—", Charte.IVOIRE if _a_decider(p) else Charte.IVOIRE_2)
		var colonne_statut := _col(columns, "status")
		_statut(hit, p, colonne_statut.x)
		D.line(hit, Vector2(0, ROW - 1), Vector2(WIDTH, ROW - 1), Color(Charte.FILET, .5))
		var police_nom := nom.get_theme_font("font")
		var largeur_nom: float = police_nom.get_string_size(nom.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nom.get_theme_font_size("font_size")).x / C.density if police_nom != null else Kit.largeur(str(p.name), 20)
		_lien_nom(hit, p, Rect2(60, 0, 520, ROW), largeur_nom)

func _cellule(row: Control, col: Dictionary, texte: String, couleur: Color, gras: bool = false) -> Label:
	if col.is_empty(): return null
	var align := HORIZONTAL_ALIGNMENT_RIGHT if col.align == 2 else HORIZONTAL_ALIGNMENT_CENTER if col.align == 1 else HORIZONTAL_ALIGNMENT_LEFT
	# D.text prend le bord droit pour un texte aligné à droite et le centre pour un texte centré.
	var ancre: float = col.x + col.w if col.align == 2 else col.x + col.w / 2.0 if col.align == 1 else col.x
	var cellule := D.text(row, ancre, 21, texte, 20, couleur, 700 if gras else 500, col.w, align)
	cellule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cellule

## Statut écrit, jamais la couleur seule : puce (symbole) + mot ; une blessure s'ajoute avec sa durée.
func _statut(row: Control, p: Dictionary, x: float) -> void:
	var courant := x
	var principal := _status(p)
	if _a_decider(p):
		Kit.puce(row, Rect2(courant, 5, 20, 20), "!", Charte.IVOIRE, Charte.ENCRE)
		D.text(row, courant + 28, 21, "À décider", 20, Charte.IVOIRE, 700, 140)
		courant += 170
	var blessure := float(p.get("injury", 0))
	if blessure > 0:
		Kit.puce(row, Rect2(courant, 5, 20, 20), "✕", Charte.VOILE_DORE, Charte.D)
		D.text(row, courant + 28, 21, "Blessé · %d sem." % ceili(blessure), 20, Charte.D, 700, 200)
		return
	if _a_decider(p): return
	var symbole := "✓" if principal[1] == Charte.V else "!" if principal[1] == Charte.N else "•"
	Kit.puce(row, Rect2(courant, 5, 20, 20), symbole, principal[1] if principal[1] != Charte.IVOIRE else Charte.IVOIRE_2, Charte.ENCRE)
	D.text(row, courant + 28, 21, str(principal[0]), 20, Charte.IVOIRE_2 if principal[1] == Charte.IVOIRE or principal[1] == Charte.V else principal[1], 600, 280)

func _courbe(parent: Control, p: Dictionary, col: Dictionary) -> void:
	var history: Array = p.get("development", {}).get("history", [])
	var courbe := Trend.new()
	courbe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for year: Dictionary in history:
		var value: Variant = year.get("end")
		if value is float or value is int: courbe.levels.append(float(value))
	if p.get("rating") is float or p.get("rating") is int: courbe.levels.append(float(p.rating))
	if courbe.levels.size() < 2:
		D.text(parent, col.x, 21, "Historique à l’intersaison", 17, Charte.IVOIRE_3, 500, col.w)
		courbe.queue_free()
		return
	courbe.minimum = maxf(0, floorf((float(courbe.levels.min()) - 2) / 5.0) * 5.0)
	courbe.maximum = minf(100, ceilf((float(courbe.levels.max()) + 2) / 5.0) * 5.0)
	parent.add_child(courbe)
	D.place(courbe, Rect2(col.x, 4, col.w, ROW - 8))

## Nom d'un jeune : survol (ou focus + I) = mini-fiche, clic = fiche complète ; « i » après le nom.
func _lien_nom(parent: Control, p: Dictionary, zone: Rect2, largeur_mesuree: float = -1.0) -> void:
	var id := str(p.get("id", ""))
	var pro := _professional(p)
	var cible := {"kind":"player" if pro else "academy", "id":id}
	if id.is_empty() or not app.navigation_controller.entity_available(cible): return
	var lien := Button.new()
	lien.name = "AcademyName_" + id.validate_node_name()
	lien.flat = true
	lien.focus_mode = Control.FOCUS_ALL
	lien.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	lien.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 8, 0))
	lien.add_theme_stylebox_override("hover", C.box(Color(Charte.IVOIRE, .06), Color.TRANSPARENT, 8, 0))
	lien.add_theme_stylebox_override("pressed", C.box(Color(Charte.IVOIRE, .1), Color.TRANSPARENT, 8, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 8, 0)
	focus.set_border_width_all(2)
	lien.add_theme_stylebox_override("focus", focus)
	lien.accessibility_name = "Ouvrir la fiche · " + str(p.get("name", ""))
	lien.pressed.connect(func(): app.navigation_controller.open_entity(cible))
	parent.add_child(lien)
	var largeur: float = largeur_mesuree if largeur_mesuree > 0 else Kit.largeur(str(p.get("name", "")), 20)
	D.place(lien, Rect2(zone.position.x, 0, 72 + 70 + minf(340.0, largeur) + 8, ROW))
	MiniFiche.lier(app, lien, id, "squad" if pro else "academy")
	var taille_i := maxf(20.0, ceilf(16.0 / C.density))
	MiniFiche.icone(app, parent, Rect2(132 + minf(340.0, largeur) + 8, (ROW - taille_i) / 2.0, taille_i, taille_i), id, "squad" if pro else "academy")

func _drapeau(parent: Control, p: Dictionary, zone: Rect2) -> void:
	var facts: Variant = p.get("playerFacts")
	if not facts is Dictionary: facts = _path(p).get("playerFacts")
	if not facts is Dictionary: facts = P.player(app.model, str(p.get("id", ""))).get("playerFacts")
	if not facts is Dictionary: return
	var drapeau := Identity.flag_texture(str(facts.get("flagCode", "")))
	if drapeau == null: return
	var image := TextureRect.new()
	image.name = "AcademyDrapeau"
	image.texture = drapeau
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.tooltip_text = str(facts.get("nationality", ""))
	parent.add_child(image)
	D.place(image, zone)
