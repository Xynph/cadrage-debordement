extends "res://ui/immersive08/recruitment_lignes.gd"
## Écran Recrutement : colonnes, en-têtes de tri, pied, filtrage, rafraîchissement et clavier (découpe de recruitment_canvas.gd, sans changement).

# --- Tableau ----------------------------------------------------------------------------------------------------

## Colonnes selon l'onglet et les données connues : une colonne sans aucune valeur (club, attributs, fin de contrat) est omise.
func _columns_for(players: Array) -> Array:
	if tab == 3:
		return [{"id":"nom", "titre":"JOUEUR OBSERVÉ", "tri":"Nom", "x":128, "w":520, "align":0},
			{"id":"poste", "titre":"POSTE", "tri":"Poste", "x":680, "w":330, "align":0},
			{"id":"date", "titre":"RAPPORT", "tri":"Date du rapport", "x":1040, "w":520, "align":0},
			{"id":"obs", "titre":"OBSERVATION", "tri":"Avis", "x":1600, "w":420, "align":0}]
	var avec_club := players.any(func(p: Dictionary): return not _club(p).is_empty())
	var avec_attributs := C.density >= .75 and players.any(func(p: Dictionary): return not Attributs.detail(p, false).is_empty())
	var avec_fin := C.density >= .75 and players.any(func(p: Dictionary): return p.get("contractEnd") is int or p.get("contractEnd") is float)
	# Forme récente (5 dernières notes de match) dès qu'une piste a joué un match noté.
	var avec_forme := players.any(func(p: Dictionary): return p.get("formeRecente") is Dictionary)
	var definitions: Array = [["nom", "JOUEUR", "Nom", 330, 0], ["poste", "POSTE", "Poste", 190, 0]]
	if avec_club: definitions.append(["club", "CLUB", "", 280, 0])
	definitions.append_array([["age", "ÂGE", "Âge", 60, 2], ["niveau", "NIV.", "Niveau", 80, 2], ["potentiel", "POT.", "Potentiel", 120, 2]])
	if avec_forme: definitions.append(["forme", "FORME", "", 196, 0])
	if avec_attributs:
		for attribut: Array in [["touche", "TOUCHE"], ["melee", "MÊLÉE"], ["gratt", "GRATT."], ["plaq", "PLAQ."]]: definitions.append([attribut[0], attribut[1], "", 66 if avec_forme else 84, 2])
	if avec_fin: definitions.append(["fin", "FIN CTR", "", 100, 2])
	definitions.append_array([["indemnite", "INDEMNITÉ", "Prime", 160, 2], ["salaire", "SALAIRE / SEM.", "Salaire", 170, 2]])
	var colonnes: Array = [{"id":"suivi", "titre":"★", "tri":"Suivi", "x":8.0, "w":44.0, "align":0}]
	var x := 128.0
	for definition: Array in definitions:
		colonnes.append({"id":definition[0], "titre":definition[1], "tri":definition[2], "x":x, "w":float(definition[3]), "align":definition[4]})
		x += float(definition[3]) + 22
	var action := 150.0
	colonnes.append({"id":"obs", "titre":"OBSERVATION", "tri":"Avis", "x":x, "w":WIDTH - x - action - 22, "align":0})
	colonnes.append({"id":"action", "titre":"ACTION", "tri":"", "x":WIDTH - action, "w":action, "align":1})
	return colonnes

func _table() -> void:
	var panel := D.rect(self, Rect2(0, TABLE_TOP + _dy, WIDTH, HEADER_H + ROWS_H - _dy + 4), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	panel.name = "ImmersiveMarketTable"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var entete := D.rect(panel, Rect2(0, 0, WIDTH, HEADER_H), Color.TRANSPARENT, 0)
	entete.name = "MarketHeader"
	Bandeau.peindre_entete(entete)
	entete.set_meta("rows_origin", Vector2(0, TABLE_TOP + _dy))
	table_scroll = ScrollContainer.new()
	table_scroll.name = "MarketScroll"
	table_scroll.follow_focus = true
	table_scroll.mouse_force_pass_scroll_events = false
	table_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(table_scroll)
	D.place(table_scroll, Rect2(0, HEADER_H, WIDTH, ROWS_H - _dy))
	table_scroll.get_v_scroll_bar().value_changed.connect(func(value: float): state.scroll = int(value))
	table_rows = Control.new()
	table_rows.name = "ImmersiveMarketRows"
	table_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_scroll.add_child(table_rows)

## En-têtes : boutons de tri aux colonnes de l'onglet courant (recréés à chaque rafraîchissement).
func _entetes() -> void:
	var entete := get_node("ImmersiveMarketTable/MarketHeader") as Control
	# Mêmes colonnes qu'au rafraîchissement précédent : les boutons de tri restent les mêmes (le focus clavier y reste).
	var signature := str(tab) + ":" + ",".join(columns.map(func(col: Dictionary): return str(col.id) + str(int(col.x))))
	if signature == _signature_entetes and not sort_headers.is_empty(): return
	_signature_entetes = signature
	for enfant in entete.get_children():
		entete.remove_child(enfant)
		enfant.queue_free()
	sort_headers.clear()
	for col: Dictionary in columns:
		if str(col.tri) == "":
			if col.id == "action": D.text(entete, col.x + col.w - 4, 22, "ACTION", 16, Charte.IVOIRE_2, 700, col.w, HORIZONTAL_ALIGNMENT_RIGHT)
			else: D.text(entete, col.x + (col.w if col.align == 2 else 0), 22, str(col.titre), 16, Charte.IVOIRE_2, 700, col.w, HORIZONTAL_ALIGNMENT_RIGHT if col.align == 2 else HORIZONTAL_ALIGNMENT_LEFT)
			continue
		var tri := Button.new()
		tri.name = "MarketSort_" + str(col.tri)
		tri.text = str(col.titre) + " ↕"
		tri.flat = true
		tri.alignment = HORIZONTAL_ALIGNMENT_RIGHT if col.align == 2 else HORIZONTAL_ALIGNMENT_LEFT
		tri.clip_text = true
		tri.add_theme_font_override("font", Charte.TITRE_GRAS)
		tri.add_theme_font_size_override("font_size", maxi(12, C.px(16)))
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: tri.add_theme_color_override(etat, Charte.IVOIRE_2)
		tri.add_theme_color_override("font_hover_color", Charte.IVOIRE)
		tri.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 8, 0))
		tri.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 8, 0))
		tri.add_theme_stylebox_override("pressed", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 8, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 8, 0)
		focus.set_border_width_all(2)
		tri.add_theme_stylebox_override("focus", focus)
		tri.set_meta("sort_caption", str(col.titre))
		var cle: String = col.tri
		sort_headers[cle] = tri
		tri.pressed.connect(func():
			var same: bool = _sort_column() == cle
			state["report_descending" if tab == 3 else "descending"] = not _sort_descending() if same else cle in ["Niveau", "Potentiel", "Date du rapport", "Suivi"]
			state["report_sort" if tab == 3 else "sort"] = cle
			_filter_changed())
		entete.add_child(tri)
		D.place(tri, Rect2(col.x - 8, 0, col.w + 16, HEADER_H))
		# En-tête souligné à la largeur de son texte, comme sur l'Effectif (choix de Léo du 21/11/2026).
		var lt := Kit.largeur(str(col.titre) + " ▼", 16) + 30.0
		tri.alignment = HORIZONTAL_ALIGNMENT_CENTER
		D.place(tri, Rect2((col.x + col.w - lt + 12.0) if col.align == 2 else col.x - 12.0, 1, lt, HEADER_H - 2))

func _pied() -> void:
	D.line(self, Vector2(0, HAUTEUR - 52), Vector2(WIDTH, HAUTEUR - 52), Charte.FILET)
	# Compteurs en pastilles (« 9 / 90 pistes », « 0 suivie ») ; le tri se lit sur l'en-tête et sur le lien de sens.
	count = Control.new()
	count.name = "MarketCount"
	add_child(count)
	D.place(count, Rect2(0, HAUTEUR - 46, 900, 36))
	direction = Kit.lien(self, Rect2(1010, HAUTEUR - 46, 0, 34), "↓ Décroissant", func():
		state["report_descending" if tab == 3 else "descending"] = not _sort_descending()
		_filter_changed(), "MarketDirection", 17)
	direction.tooltip_text = ""
	_refresh_count()
	# Raccourcis clavier : un « ? » en bas à droite, la liste des touches au survol.
	Pieces.info(self, WIDTH - 30, HAUTEUR - 42, "Raccourcis : ↑ ↓ choisir une piste · A approcher · I aperçu · Échap menu", "Raccourcis", "?")


func _refresh_count() -> void:
	if count == null: return
	for ancien in count.get_children():
		count.remove_child(ancien)
		ancien.queue_free()
	var total: int = app.model.get("market", []).size()
	var suivies: int = app.management_ui.shortlist.size()
	var x := 0.0
	if tab == 3:
		x += Pieces.pastille(count, x, 1, P.plural(data.get("reports", []).size(), "rapport", "rapports"), "", "MarketCountReports") + 8.0
	else:
		# Comptes cliquables vers l'onglet qui les détaille (neutres quand on y est déjà).
		var vers_recherche := Callable(self, "_ouvrir_onglet").bind(1) if tab != 1 else Callable()
		var vers_suivis := Callable(self, "_ouvrir_onglet").bind(2) if tab != 2 else Callable()
		x += Pieces.pastille(count, x, 1, "%d / %d pistes" % [_results_count, total], "", "MarketCountTracks", "", Pieces.BLEU if tab != 1 else Charte.IVOIRE, Charte.PANNEAU_3, vers_recherche) + 8.0
		x += Pieces.pastille(count, x, 1, P.plural(suivies, "suivie", "suivies"), "", "MarketCountFollowed", "", Pieces.TURQUOISE if tab != 2 else Charte.IVOIRE, Charte.PANNEAU_3, vers_suivis) + 8.0
	direction.text = "↓ Décroissant" if _sort_descending() else "↑ Croissant"
	direction.position.x = C.px(x + 16)

func _filtered() -> Array:
	if tab == 3:
		var archive: Array = data.get("reports", []).duplicate()
		return Sort.sorted(archive, _sort_column(), _sort_descending(), report_by_player, true)
	var query_state := state.duplicate()
	query_state.search = ""
	var players := U.players(app.model.get("market", []), query_state, int(app.model.meta.get("season", 1)), true, app.management_ui.shortlist, false)
	var terms: PackedStringArray = []
	if str(state.get("navigation_id", "")).is_empty():
		terms = U.fold(str(state.get("search", ""))).split(" ", false)
	var fee := float({"≤ 100 k€": 100000, "≤ 400 k€": 400000, "≤ 1 M€": 1000000}.get(state.get("budget_filter"), INF))
	var ages: Vector2 = {"≤ 22 ans": Vector2(0, 22), "23–28 ans": Vector2(23, 28), "≥ 29 ans": Vector2(29, INF)}.get(state.get("age_filter"), Vector2(0, INF))
	var observation := str(state.get("observation", "Toutes"))
	var filtered := players.filter(func(p: Dictionary):
		var raw_age: Variant = p.get("age")
		var age_known: bool = (raw_age is int or raw_age is float) and is_finite(float(raw_age))
		var raw_fee: Variant = p.get("fee")
		var fee_known: bool = (raw_fee is int or raw_fee is float) and is_finite(float(raw_fee))
		if tab != 3 and not str(state.get("poste_groupe", "")).is_empty() and Listes.groupe_de(p) != str(state.poste_groupe): return false
		var searchable := U.fold(str(p.get("name", "")) + " " + str(p.get("pos", "")))
		for term in terms:
			if not searchable.contains(term): return false
		if state.available == "Indisponibles" and p.get("available", false): return false
		if state.get("age_filter", "Tous") != "Tous" and (not age_known or float(raw_age) < ages.x or float(raw_age) > ages.y): return false
		if state.get("budget_filter", "Toutes") != "Toutes" and (not fee_known or float(raw_fee) > fee): return false
		var observe: bool = _observed(p)
		if observation == "Observées" and not observe: return false
		if observation == "Non observées" and observe: return false
		return true)
	if _sort_column() == "Suivi":
		# Suivies d'abord (ou en dernier), puis l'ordre des postes.
		var base: Array = Sort.sorted(filtered, "Poste", false, report_by_player)
		var suivies: Array = base.filter(func(p: Dictionary): return str(p.id) in app.management_ui.shortlist)
		var autres: Array = base.filter(func(p: Dictionary): return str(p.id) not in app.management_ui.shortlist)
		return suivies + autres if _sort_descending() else autres + suivies
	return Sort.sorted(filtered, _sort_column(), _sort_descending(), report_by_player)

func _sort_arrows() -> void:
	for column: String in sort_headers:
		var button: Button = sort_headers[column]
		var active := column == _sort_column()
		button.text = str(button.get_meta("sort_caption")) + (" ↓" if _sort_descending() else " ↑") if active else str(button.get_meta("sort_caption")) + " ↕"
		button.add_theme_color_override("font_color", Charte.IVOIRE if active else Charte.IVOIRE_2)
		button.tooltip_text = "Trier par %s · %s · valeurs inconnues en dernier" % ["observation" if column == "Avis" else "indemnité" if column == "Prime" else column.to_lower(), "croissant au prochain clic" if active and _sort_descending() else "décroissant au prochain clic" if active else "activer le tri"]
		button.accessibility_name = button.text + " · " + button.tooltip_text
		Listes.styler_entete(button, null, active, _sort_descending(), str(button.get_meta("sort_caption")))

func _refresh() -> void:
	var scroll := table_scroll.scroll_vertical
	_clear(table_rows)
	var results := _filtered()
	_results_count = results.size()
	_ids_affiches = results.map(func(p: Dictionary): return str(p.get("playerId", p.id)))
	columns = _columns_for(results if tab != 3 else [])
	_entetes()
	table_rows.custom_minimum_size = Vector2(0, C.px(maxi(80, results.size() * ROW_HEIGHT) + BAS_TABLEAU))
	var current := str(state.get("report_id" if tab == 3 else "player_id", ""))
	if not results.is_empty() and not results.any(func(p: Dictionary): return str(p.id) == current):
		current = str(results[0].id)
		state["report_id" if tab == 3 else "player_id"] = current
	_refresh_count()
	_sort_arrows()
	var selected_index := -1
	_selected = {}
	for i in results.size():
		if str(results[i].id) == current:
			_selected = results[i]
			selected_index = i
			break
	_generation += 1
	var built := mini(results.size(), FIRST_ROWS)
	if selected_index >= 0: built = maxi(built, mini(results.size(), selected_index + VISIBLE_MARGIN))
	_build_rows(results, current, 0, built)
	if built < results.size(): _build_remaining(results, current, built, _generation)
	if results.is_empty():
		var caption := "Aucun rapport conservé" if tab == 3 else "Aucune piste"
		if tab == 0 and str(state.get("position", "Tous")) != "Tous": caption = "Aucune piste pour ce poste"
		Kit.texte(table_rows, 24, 40, caption, Charte.IVOIRE_2, WIDTH - 50, 20)
		if tab == 0 and str(state.get("position", "Tous")) != "Tous":
			var tout := Kit.lien(table_rows, Rect2(20, 56, 0, 34), "Voir tout le marché →", func():
				state.immersive_tab = 1
				state.position = "Tous"
				state.position_libre = true
				app._render(false), "MarketShowAll", 19)
			tout.tooltip_text = ""
	_tuiles()
	_cout()
	table_scroll.set_deferred("scroll_vertical", scroll)

func _build_rows(items: Array, current: String, from: int, to: int) -> void:
	for i in range(from, to):
		var item: Dictionary = items[i]
		_row(item, i, str(item.id) == current)

func _build_remaining(items: Array, current: String, from: int, generation: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var next := from
	while next < items.size():
		await tree.process_frame
		if not is_instance_valid(self) or generation != _generation or not is_inside_tree(): return
		var upto := mini(items.size(), next + ROWS_PER_FRAME)
		_build_rows(items, current, next, upto)
		next = upto

## Raccourcis écrits au pied de page : « A » approche la piste choisie, ↑ ↓ passent à la piste voisine (focus sur une ligne).
func _input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo or touche.ctrl_pressed or touche.alt_pressed or touche.meta_pressed: return
	if not is_visible_in_tree() or tab == 3 or table_rows == null or not Pages.actuelle(app).is_empty(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is OptionButton or focus is SpinBox or focus is TextEdit: return
	if touche.keycode == KEY_A and not touche.shift_pressed:
		var offre := cost.find_child("OfferRecruitment", true, false) as Button
		if offre != null and not offre.disabled:
			get_viewport().set_input_as_handled()
			offre.pressed.emit()
	elif touche.keycode in [KEY_UP, KEY_DOWN] and focus is Button and focus.has_meta("player_id") and table_rows.is_ancestor_of(focus):
		var rang := _ids_affiches.find(str(focus.get_meta("player_id")))
		var voisin := rang + (1 if touche.keycode == KEY_DOWN else -1)
		if rang < 0 or voisin < 0 or voisin >= _ids_affiches.size(): return
		get_viewport().set_input_as_handled()
		state.player_id = str(_ids_affiches[voisin])
		_refresh()
		var cible := table_rows.get_node_or_null("MarketPlayer_" + str(_ids_affiches[voisin]).replace(":", "_")) as Button
		if cible != null: FocusLater.grab(cible)
