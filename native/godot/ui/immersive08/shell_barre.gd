extends RefCounted
## Coque commune : sauvegarde, barre haute (fil d'Ariane, recherche, date, Gabi, Continuer).
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const P = preload("res://ui/immersive08/projection.gd")
const FichePage = preload("res://ui/immersive08/fiche_page.gd")
const Academy = preload("res://ui/immersive08/academy_canvas.gd")
const Recruitment = preload("res://ui/immersive08/recruitment_canvas.gd")
const ClubCanvas = preload("res://ui/immersive08/club_canvas.gd")
const ClubSheet = preload("res://ui/immersive08/club_sheet_canvas.gd")
const Comparateur = preload("res://ui/immersive08/comparateur_canvas.gd")
const EuropePage = preload("res://ui/immersive08/europe_canvas.gd")
const Selections = preload("res://ui/international_view.gd")
const G = preload("res://ui/game_skin.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Outils = preload("res://ui/immersive08/shell_outils.gd")
const Rail = preload("res://ui/immersive08/shell_rail.gd")
const Shell = preload("res://ui/immersive08/shell.gd")

## Sauvegarde directe (Ctrl S, Sauvegarder, « Réessayer ») : aucune boîte ; la ligne passe à « Sauvegarde… ».
static func save_now(app: Control) -> void:
	if not app._has_career(): return
	if app._command("save"): refresh_save_line(app)

static func _short_date(date: String) -> String:
	var parts := date.split("-")
	if parts.size() != 3 or not parts[1].is_valid_int() or not parts[2].is_valid_int(): return ""
	var stamp := Time.get_unix_time_from_datetime_string(date.substr(0, 10) + "T12:00:00")
	var weekday := int(Time.get_datetime_dict_from_unix_time(stamp).get("weekday", -1))
	return ("%s %s/%s" % [Shell.JOURS[weekday], parts[2].substr(0, 2), parts[1]]) if weekday >= 0 and weekday < 7 else "%s/%s" % [parts[2].substr(0, 2), parts[1]]

## Ligne d'état de la sauvegarde dans le pied du rail : [texte, couleur, picto, infobulle].
static func save_caption(app: Control) -> Array:
	var meta: Dictionary = app.model.get("meta", {})
	if bool(app.get("waiting")) and str(app.get("last_command")) == "save": return ["Sauvegarde…", C.MUTED, "sauver", "Sauvegarde en cours"]
	var failed: bool = bool(meta.get("saveError", false)) or (app.has_method("_storage_has_error") and app._storage_has_error())
	if failed: return ["Échec de la sauvegarde · Réessayer", Charte.D, "alerte", "La dernière sauvegarde n'a pas pu être écrite. Clique pour réessayer."]
	var info: Variant = meta.get("autosave")
	var last := str(info.get("lastSave", "")) if info is Dictionary and info.get("lastSave") != null else ""
	if last.is_empty(): return ["Pas encore sauvegardé", C.MUTED, "sauver", "Clique pour sauvegarder maintenant."]
	var policy := str({"jour":"chaque jour", "semaine":"chaque semaine", "mois":"chaque mois"}.get(str(info.get("policy", "")), ""))
	return ["Sauvegardé " + _short_date(last), Charte.V, "coche", "Dernière sauvegarde complète le %s%s. Clique pour sauvegarder maintenant." % [_short_date(last), " · automatique " + policy if not policy.is_empty() else ""]]

static func refresh_save_line(app: Control, line: Button = null) -> void:
	if line == null and is_instance_valid(app.get("root_content")): line = app.root_content.find_child("ImmersiveSaveLine", true, false) as Button
	if not is_instance_valid(line): return
	var state := save_caption(app)
	var caption := str(state[0])
	if Outils._rw(C.BODY, caption, 19) > Shell.RAIL_WIDTH - 2.0 * Shell.RAIL_INSET - Shell.RAIL_LABEL - 8.0:
		# Place comptée : le jour de la semaine tombe, la date reste ; le texte complet est dans l'infobulle.
		var compact := RegEx.create_from_string("\\s[^\\s\\d]+\\.?(?=\\s\\d)").sub(caption, "")
		if not compact.is_empty(): caption = compact
		# Toujours trop large (rail étroit, 1280) : le picto ✓ dit « sauvegardé », il ne reste que la date.
		if caption.begins_with("Sauvegardé ") and Outils._rw(C.BODY, caption, 19) > Shell.RAIL_WIDTH - 2.0 * Shell.RAIL_INSET - Shell.RAIL_LABEL - 8.0:
			caption = caption.get_slice(" ", caption.get_slice_count(" ") - 1)
	line.text = caption
	line.tooltip_text = state[3]
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: line.add_theme_color_override(key, state[1])
	var picto := line.get_node_or_null("SaveLinePicto") as Outils.Picto
	if picto != null:
		picto.forme = state[2]
		picto.couleur = state[1]
		picto.queue_redraw()

## Barre haute (48 px à 1920, 64 en référence) : Menu « Échap », Précédent / Suivant, fil d'Ariane cliquable,
## Rechercher « Ctrl K » (champ, aucune fenêtre), date + journée (Calendrier), médaillon de Gabi « F1 »,
## « +1 j » discret, Continuer (seul aplat doré : pilule de 40 px, « Espace » ou ce qui l'arrête).
static func _topbar(parent: Node, app: Control, layout: Control) -> void:
	var panel := Control.new()
	panel.name = "ImmersiveTopbar"
	panel.custom_minimum_size.y = C.px(Shell.TOPBAR_HEIGHT)
	C.fill(panel)
	parent.add_child(panel)
	var background := ColorRect.new()
	background.name = "ImmersiveTopbarBackground"
	background.color = C.PANEL
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bottom := ColorRect.new()
	bottom.name = "ImmersiveTopbarRule"
	bottom.color = C.LINE
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -1
	var national := Selections.nation_only(app.model)
	var ch := C.reach(43.0)
	var cy := (Shell.TOPBAR_HEIGHT - ch) / 2.0
	var square := C.reach(48.0)
	var sy := (Shell.TOPBAR_HEIGHT - square) / 2.0
	# Gauche : Menu (menu pause, la seule fenêtre de la coque), historique, filet.
	# Bouton secondaire de la charte : pilule à contour FILET, ☰ + « Menu » (Barlow Condensed) + touche « Échap ».
	var menu_text := Outils._rw(C.DISPLAY, "Menu", 21)
	var menu_width := 16.0 + 21.0 + 10.0 + menu_text + 10.0 + Outils._key_width("Échap") + 10.0
	var menu := Outils._shell_button("ImmersiveMenu", true, Charte.RAYON_PILULE)
	menu.tooltip_text = "Menu : sauvegardes, réglages, quitter · Échap"
	menu.accessibility_name = "Menu · Échap"
	panel.add_child(menu)
	D.place(menu, Rect2(21, cy, menu_width, ch))
	menu.pressed.connect(app.pause_menu)
	Outils._picto(menu, Rect2(16, (ch - 21) / 2.0, 21, 21), "burger", C.IVORY)
	Outils._label(menu, Rect2(47, 0, menu_text + 2, ch), "Menu", 21, C.IVORY, C.DISPLAY)
	Outils._key(menu, 47 + menu_text + 10, (ch - 27) / 2.0, "Échap")
	var x := 21.0 + menu_width + 27.0
	# Précédent / Suivant : cases à contour FILET, rayon 6 px.
	var back := Outils._shell_button("NavigationBack", true, Shell.RAYON_PETIT_REF)
	var forward := Outils._shell_button("NavigationForward", true, Shell.RAYON_PETIT_REF)
	for item: Array in [[back, "gauche", "Page précédente · Alt+←"], [forward, "droite", "Page suivante · Alt+→"]]:
		var arrow: Button = item[0]
		arrow.set_meta("coque", true)
		arrow.tooltip_text = item[2]
		arrow.accessibility_name = item[2]
		panel.add_child(arrow)
		D.place(arrow, Rect2(x, sy, square, square))
		Outils._picto(arrow, Rect2(square * .27, square * .27, square * .46, square * .46), item[1], C.IVORY, arrow)
		x += square + 11.0
	if is_instance_valid(app.navigation_controller): app.navigation_controller.bind_history_buttons(back, forward)
	x += 16.0
	D.line(panel, Vector2(x, 16), Vector2(x, 48), C.LINE)
	var crumbs_left := x + 28.0
	# Droite, de droite à gauche : Continuer, +1 j, F1 et Gabi, date, recherche ; le fil prend le reste.
	var right := Shell.TOPBAR_WIDTH - 11.0
	# Bouton principal de la charte : pilule dorée de 40 px (53,3 en référence).
	var continue_height := C.reach(Shell.RAIL_PILL)
	var continue_rect := Rect2(right - Shell.CONTINUE_WIDTH, (Shell.TOPBAR_HEIGHT - continue_height) / 2.0, Shell.CONTINUE_WIDTH, continue_height)
	right -= Shell.CONTINUE_WIDTH + 16.0
	var office_live: bool = app.route == "Bureau" and not app._live().is_empty()
	var single_day: bool = not office_live and app.has_method("next_day_available") and app.next_day_available()
	var next_day: Button = null
	if single_day:
		var day_width := Outils._rw(C.BODY, "+1 j", 17) + 22.0
		next_day = Outils._shell_button("ImmersiveNextDay", false, Charte.RAYON_PILULE)
		next_day.text = "+1 j"
		next_day.alignment = HORIZONTAL_ALIGNMENT_CENTER
		next_day.add_theme_font_size_override("font_size", Outils._fpx(17))
		for key in ["font_color", "font_focus_color"]: next_day.add_theme_color_override(key, C.MUTED)
		next_day.tooltip_text = "Jour suivant : avancer d’un seul jour (Ctrl+J)"
		next_day.accessibility_name = "Jour suivant"
		panel.add_child(next_day)
		D.place(next_day, Rect2(right - day_width, cy, day_width, ch))
		next_day.pressed.connect(app.next_day_action)
		right -= day_width + 16.0
	# Médaillon ovale de Gabi (charte §5 : 40 px de haut, cadre doré ; 80 × 53,3 en référence) et sa touche « F1 »
	# écrite à côté : cibles d'au moins 28 px réels (58 de haut à 1280 × 720). Les deux s'affichent ensemble ou pas du
	# tout (Bureau : Gabi en pied, coach coupé).
	var target := ceilf(28.0 / maxf(.01, C.density * Outils._coque_factor))
	var medallion_height := clampf(maxf(Shell.RAIL_PILL, target), Shell.RAIL_PILL, Shell.TOPBAR_HEIGHT - 4.0)
	var medallion_width := medallion_height * 1.5
	var f1_width := maxf(Outils._key_width("F1") + 8.0, target)
	var help := Outils._shell_button("GabiF1")
	help.tooltip_text = "Aide de Gabi · F1"
	help.accessibility_name = "Aide de Gabi · F1"
	panel.add_child(help)
	D.place(help, Rect2(right - f1_width, (Shell.TOPBAR_HEIGHT - medallion_height) / 2.0, f1_width, medallion_height))
	help.pressed.connect(func(): app._open_coach())
	Outils._key(help, (f1_width - Outils._key_width("F1")) / 2.0, (medallion_height - 27) / 2.0, "F1", C.RAISED)
	right -= f1_width + 4.0
	# Gabi en pied n'existe que dans le Bureau dessiné (OfficeCanvas, dès 1600 px de large) ; en dessous, le Bureau classique
	# n'a pas sa colonne : le médaillon du bandeau reste affiché, sinon Gabi disparaît de l'écran.
	var gabi_en_pied: bool = app.route == "Bureau" and app.get_window().size.x >= Shell.OFFICE_CANVAS_MIN_WIDTH and not national and is_instance_valid(app.get("coach")) and app.coach.has_method("bureau_disponible") and app.coach.bureau_disponible()
	var gabi := Control.new()
	gabi.name = "GabiBandeau"
	gabi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gabi.set_meta("masque", gabi_en_pied)
	gabi.set_meta("compact", true)
	panel.add_child(gabi)
	D.place(gabi, Rect2(right - medallion_width, (Shell.TOPBAR_HEIGHT - medallion_height) / 2.0, medallion_width, medallion_height))
	right -= medallion_width + 27.0
	# Date + journée : « mar. 17 nov. · J9 » ; clic : Calendrier (au jour courant).
	var caption := date_caption(app.model)
	var widest := maxf(Outils._rw(Charte.texte_moyen(), caption[0], 17), Outils._rw(Charte.texte_moyen(), "mer. 28 sept.", 17))
	var round_width := Outils._rw(Charte.TITRE_GRAS_ITALIQUE, "· J30", 20) + 6.0
	var date_width := widest + round_width + 16.0
	var calendar := Outils._shell_button("ImmersiveCalendarDate")
	calendar.accessibility_name = "Ouvrir le calendrier"
	panel.add_child(calendar)
	D.place(calendar, Rect2(right - date_width, cy, date_width, ch))
	calendar.pressed.connect(Callable(Shell, "_open_current_calendar").bind(app))
	app.header_date = Outils._label(calendar, Rect2(8, 0, widest, ch), "", 17, C.IVORY, Charte.texte_moyen(), HORIZONTAL_ALIGNMENT_RIGHT)
	app.header_date.name = "ImmersiveDateText"
	app.header_date.set_meta("coque", true)
	app.header_date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var round_label := Outils._label(calendar, Rect2(8 + widest + 4, 0, round_width, ch), "", 20, C.IVORY, Charte.TITRE_GRAS_ITALIQUE)
	round_label.name = "ImmersiveRound"
	app._update_header_date()
	right -= date_width + 27.0
	var crumbs := _crumbs(app)
	var crumbs_width := _crumbs_width(crumbs)
	# Compte à rebours du prochain match (choix de Léo, 21/11/2026) → avant-match ; il cède la place au fil d'Ariane
	# et à la recherche réduite (forme courte sans le mot DOM./EXT., ou rien).
	var Rebours = preload("res://ui/rebours_match.gd")
	var fil_entier := func(prise: float) -> bool:
		var reste := right - prise
		var recherche := clampf(reste - crumbs_left - minf(crumbs_width, 520.0) - 27.0, 293.0, 400.0)
		return reste - recherche - 27.0 - crumbs_left >= crumbs_width
	var place_rebours := 0.0
	for prise: float in [Rebours.PLEINE + Rebours.ECART, Rebours.COURTE + Rebours.ECART]:
		if fil_entier.call(prise):
			place_rebours = prise
			break
	right -= Rebours.poser(panel, app, right + 12.0, ch, cy, Callable(Outils, "_shell_button"), place_rebours)
	# Recherche : 400 (300 px à 1920), réduite jusqu'à 293 (220 px) si le fil manque de place.
	var search_width := clampf(right - crumbs_left - minf(crumbs_width, 520.0) - 27.0, 293.0, 400.0)
	var search := _search_field(panel, app, Rect2(right - search_width, cy, search_width, ch))
	right -= search_width + 27.0
	_place_crumbs(panel, app, crumbs, crumbs_left, right, ch, cy)
	_continue_button(panel, app, continue_rect)
	if next_day != null: next_day.focus_neighbor_right = app.primary_button.get_path()
	if is_instance_valid(app.coach) and app.coach.has_method("installer_bandeau"): app.coach.installer_bandeau(gabi)
	else: gabi.hide()
	# « F1 » n'est jamais seul dans la barre : il suit le médaillon (masqué au Bureau, où Gabi est en pied).
	help.visible = gabi.visible and not gabi_en_pied

## Date du jeu de la barre haute : [« mar. 17 nov. », « J9 » ou vide, infobulle].
static func date_caption(model: Dictionary) -> Array:
	var meta: Dictionary = model.get("meta", {})
	var round_label := str(meta.get("roundLabel", ""))
	var planning: Dictionary = model.get("calendarPlanning", {}) if model.get("calendarPlanning") is Dictionary else {}
	var today: Variant = planning.get("today", meta.get("calendarToday", meta.get("date", "")))
	var date: String = today if today is String else ""
	var parts := date.split("-")
	var text := ""
	if parts.size() == 3 and parts[1].is_valid_int() and int(parts[1]) in range(1, 13) and parts[2].substr(0, 2).is_valid_int():
		var stamp := Time.get_unix_time_from_datetime_string(date.substr(0, 10) + "T12:00:00")
		var weekday := int(Time.get_datetime_dict_from_unix_time(stamp).get("weekday", -1))
		text = "%s%d %s" % [(Shell.JOURS[weekday] + " ") if weekday >= 0 and weekday < 7 else "", int(parts[2].substr(0, 2)), Shell.MOIS[int(parts[1]) - 1]]
	else:
		text = "Saison " + G.season_label(meta.get("season", 1))
	# Journée : celle du libellé de la semaine (« Journée 9 · … ») ; sinon celle de la prochaine rencontre du club
	# (« Journée 2 », relectures du 19/11/2026 : l'avant-saison et les semaines sans libellé gardent leur repère).
	var journee := ""
	var pattern := RegEx.create_from_string("(?i)journée\\s+(\\d+)")
	var matched := pattern.search(round_label)
	if matched == null: matched = pattern.search(str(P.next_fixture(model).get("label", "")))
	if matched != null: journee = "J" + matched.get_string(1)
	return [text, journee, round_label]

## Fil d'Ariane : [libellé, action]. Club → fiche du club ; section → page racine de la section ; sous-page → la page.
static func _crumbs(app: Control) -> Array:
	var national := Selections.nation_only(app.model)
	var club: Dictionary = app.model.get("club", {}) if app.model.get("club") is Dictionary else {}
	var identity := str(Selections.managed_team(app.model).get("name", "Sélection")) if national else G.club_name(club)
	var result := []
	result.append([identity, func():
		if national: app._navigate("Sélections")
		elif not club.has("id") or not app.navigation_controller.open_entity({"kind":"club", "id":str(int(club.get("id", -1)))}): app._navigate("Club")])
	var section := Rail.rail_section(app.route)
	var section_root: String = section[1]
	result.append([str(section[0]), func(): app._navigate(section_root)])
	var page := _page_caption(app)
	if not page.is_empty() and page != str(section[0]):
		var route: String = app.route
		result.append([page, func(): app._navigate(route, true, true)])
	return result

static func _page_caption(app: Control) -> String:
	if app.route == "Effectif" and app.get_meta("immersive08_full_player", false): return "Fiche joueur : " + str(P.player(app.model, app.selected_player).get("name", ""))
	var fiche := FichePage.actuelle(app)
	if not fiche.is_empty(): return "Fiche joueur : " + str(fiche.joueur.get("name", ""))
	if app.route == ClubSheet.ROUTE: return "Fiche club : " + ClubSheet.caption(app)
	if app.route == "Formation" and not Academy.Pages.actuelle(app).is_empty(): return str(Academy.Pages.TITRES.get(Academy.Pages.actuelle(app), "Formation"))
	if app.route == "Staff" and not ClubCanvas.Pages.actuelle(app).is_empty(): return str(ClubCanvas.Pages.TITRES.get(ClubCanvas.Pages.actuelle(app), "Staff"))
	if app.route == "Recrutement" and not Recruitment.Pages.actuelle(app).is_empty(): return str(Recruitment.Pages.TITRES.get(Recruitment.Pages.actuelle(app), "Recrutement"))
	# Liste du Recrutement : le fil d'Ariane dit aussi l'onglet courant (Besoins du club, Recherche, Joueurs suivis, Rapports).
	if app.route == "Recrutement" and FichePage.actuelle(app).is_empty() and app.management_ui.get("market") is Dictionary:
		return str(Recruitment.TABS[clampi(int(app.management_ui.market.get("immersive_tab", 0)), 0, Recruitment.TABS.size() - 1)])
	# Tactique : le fil d'Ariane dit l'onglet courant (Consignes, Phases arrêtées, Entraînement).
	if app.route == "Composition" and int(app.management_ui.get("tactique_onglet", 0)) in [1, 2, 4]: return str(["", "Consignes", "Phases arrêtées", "", "Entraînement"][int(app.management_ui.tactique_onglet)])
	if app.route == Comparateur.ROUTE: return Comparateur.caption(app)
	if app.route == EuropePage.ROUTE: return "Préparer l’Europe"
	if Shell._is_training(app): return "Entraînement"
	if app.route == "Recherche":
		var query := str(app.management_ui.get("search_query", "")).strip_edges()
		return "« %s »" % query if not query.is_empty() else "Résultats"
	return {"Effectif":"Vue d'ensemble", "Composition":"Composition", "Classements":"Classements", "Réception":"Courrier", "Bureau":"Ta semaine"}.get(app.route, app.route)

static func _crumbs_width(crumbs: Array) -> float:
	var total := 0.0
	for i in crumbs.size():
		var last: bool = i == crumbs.size() - 1
		total += Outils._rw(Charte.texte_moyen() if last else C.BODY, str(crumbs[i][0]), 17) + 8.0
		if not last: total += Outils._rw(C.BODY, "/", 17) + 22.0
	return total

## Place les morceaux du fil entre `left` et `right` ; s'il manque de place, il perd ses premiers morceaux.
static func _place_crumbs(panel: Control, app: Control, crumbs: Array, left: float, right: float, ch: float, cy: float) -> void:
	var shown := crumbs.duplicate()
	while shown.size() > 1 and _crumbs_width(shown) > right - left: shown.pop_front()
	var x := left
	var first_index := crumbs.size() - shown.size()
	for i in shown.size():
		var last: bool = i == shown.size() - 1
		var font: Font = Charte.texte_moyen() if last else C.BODY
		# Le dernier morceau (la page) se resserre jusqu'au plancher de 12 px avant tout « … ».
		var size := 17.0
		var room := maxf(40.0, right - x)
		while Outils._fpx(size) > Outils._coque_floor and Outils._rw(font, str(shown[i][0]), size) + 8.0 > room: size -= 1.0
		var width := minf(Outils._rw(font, str(shown[i][0]), size) + 8.0, room)
		var crumb := Outils._shell_button("ImmersiveCrumb%d" % (first_index + i))
		crumb.text = str(shown[i][0])
		crumb.tooltip_text = str(shown[i][0])
		crumb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		crumb.add_theme_font_override("font", font)
		crumb.add_theme_font_size_override("font_size", Outils._fpx(size))
		if not last:
			for key in ["font_color", "font_focus_color"]: crumb.add_theme_color_override(key, C.MUTED)
		else: crumb.set_meta("ariane_ici", true)
		crumb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(crumb)
		D.place(crumb, Rect2(x, cy, width, ch))
		crumb.pressed.connect(shown[i][1])
		x += width
		if not last:
			Outils._label(panel, Rect2(x + 7, cy, Outils._rw(C.BODY, "/", 17) + 8, ch), "/", 17, C.FAINT, C.BODY, HORIZONTAL_ALIGNMENT_CENTER)
			x += Outils._rw(C.BODY, "/", 17) + 22.0

## Champ « Rechercher » (Ctrl K) : pilule panneau-3, contour FILET, focus anneau doré ; Entrée ouvre l'écran Recherche.
static func _search_field(panel: Control, app: Control, rect: Rect2) -> LineEdit:
	var field := LineEdit.new()
	field.name = "ImmersiveSearch"
	field.set_meta("immersive_style_applied", true)
	var national := Selections.nation_only(app.model)
	var hint := "Rechercher un écran…" if national else "Rechercher un joueur, un club…"
	field.placeholder_text = hint if Outils._rw(C.BODY, hint, 17) <= rect.size.x - 47.0 - Outils._key_width("Ctrl K") - 24.0 else "Rechercher…"
	field.tooltip_text = "Rechercher un joueur, un club ou un écran · Ctrl K · Entrée : résultats"
	field.accessibility_name = "Rechercher · Ctrl K"
	field.add_theme_font_override("font", C.BODY)
	field.add_theme_font_size_override("font_size", Outils._fpx(17))
	field.add_theme_color_override("font_color", C.IVORY)
	field.add_theme_color_override("font_placeholder_color", C.MUTED)
	field.add_theme_color_override("caret_color", C.IVORY)
	field.add_theme_color_override("selection_color", C.LINE)
	var normal := Outils._style(C.SELECTED, Charte.RAYON_PILULE, C.LINE)
	var focus := Outils._style(Color.TRANSPARENT, Charte.RAYON_PILULE, C.OR, 2)
	focus.set_expand_margin_all(2)
	for style: StyleBoxFlat in [normal, focus]:
		style.content_margin_left = C.px(47)
		style.content_margin_right = C.px(Outils._key_width("Ctrl K") + 20.0)
	field.add_theme_stylebox_override("normal", normal)
	field.add_theme_stylebox_override("read_only", normal)
	field.add_theme_stylebox_override("focus", focus)
	if app.route == "Recherche": field.text = str(app.management_ui.get("search_query", ""))
	panel.add_child(field)
	D.place(field, rect)
	Outils._picto(field, Rect2(16, (rect.size.y - 21) / 2.0, 21, 21), "loupe", C.MUTED)
	var key := Outils._key(field, rect.size.x - Outils._key_width("Ctrl K") - 12.0, (rect.size.y - 27) / 2.0, "Ctrl K", C.RAISED)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.text_submitted.connect(func(text: String): app.navigation_controller.submit_search(text))
	field.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			field.accept_event()
			if not field.text.is_empty(): field.clear()
			else: field.release_focus())
	if is_instance_valid(app.navigation_controller): app.navigation_controller.bind_search_field(field)
	return field

## Continuer : pilule dorée (seul aplat doré de l'écran), texte PANNEAU en Barlow Condensed Bold, bas de casse ;
## « Espace » à droite, ou ce qui l'arrête (« Préparer », « Conf. de presse »…). main.gd écrit l'état dans `text` (invisible) : sync_continue
## le recopie dans les libellés visibles.
static func _continue_button(panel: Control, app: Control, rect: Rect2) -> void:
	var button := Outils._shell_button("ImmersiveContinue")
	button.text = "Continuer"
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]: button.add_theme_color_override(key, Color.TRANSPARENT)
	var focus := Outils._style(Color.TRANSPARENT, Charte.RAYON_PILULE, C.OR, 2)
	focus.set_expand_margin_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_font_override("font", C.BOLD)
	button.add_theme_font_size_override("font_size", Outils._fpx(24))
	panel.add_child(button)
	D.place(button, rect)
	var plate := Outils._aplat(button, Rect2(Vector2.ZERO, rect.size), C.OR, C.px(Charte.RAYON_PILULE))
	plate.name = "ContinuePlate"
	plate.show_behind_parent = true
	plate.couleur_survol = C.OR_VIF
	plate.source = button
	button.draw.connect(plate.queue_redraw)
	var label := Outils._label(button, Rect2(24, 0, rect.size.x - 150, rect.size.y), "Continuer", 24, Charte.PANNEAU, C.BOLD)
	label.name = "ContinueLabel"
	var rule := ColorRect.new()
	rule.name = "ContinueRule"
	rule.color = Color(Charte.PANNEAU, .35)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(rule)
	var hint := Outils._label(button, Rect2(rect.size.x - 120, 0, 85, rect.size.y), "Espace", 16, Charte.PANNEAU, C.BODY, HORIZONTAL_ALIGNMENT_RIGHT)
	hint.name = "ContinueHint"
	app.primary_button = button
	button.pressed.connect(app.primary_action)
	button.tooltip_text = app.primary_tooltip() if app.has_method("primary_tooltip") else app.primary_text()
	sync_continue(app)

## Recopie l'état de Continuer (texte court posé par main.gd) dans ses libellés visibles.
static func sync_continue(app: Control) -> void:
	var button := app.get("primary_button") as Button
	if not is_instance_valid(button) or button.name != "ImmersiveContinue": return
	var label := button.get_node_or_null("ContinueLabel") as Label
	var hint := button.get_node_or_null("ContinueHint") as Label
	var rule := button.get_node_or_null("ContinueRule") as ColorRect
	if label == null or hint == null or rule == null: return
	var state := str(button.text).strip_edges()
	var own_head: bool = state in ["Relancer", "Retour au direct", "Valider le résultat", "Après-match"]
	label.text = state if own_head else "Continuer"
	# « Espace » au repos ; « ! » + raison courte seulement quand quelque chose arrête Continuer (main.continue_block),
	# jamais d'après l'état désactivé ni d'après la prochaine étape ordinaire (« Préparer »).
	var block: String = str(app.continue_block()) if app.has_method("continue_block") else ""
	hint.text = "Espace" if block.is_empty() else "! " + block
	button.accessibility_name = label.text.capitalize() + " · " + (block + " (clic : l'écran qui bloque)" if not block.is_empty() else "touche Espace")
	var width_ref := button.size.x / C.density if button.size.x > 0 else Shell.CONTINUE_WIDTH
	var height_ref := button.size.y / C.density if button.size.y > 0 else Shell.TOPBAR_HEIGHT - 16
	# Jamais de « … » : le libellé et la raison se resserrent jusqu'au plancher de 12 px pour tenir entiers.
	var hint_size := 16.0
	var label_size := 24.0
	var hint_right := width_ref - 35.0
	while hint_size > 1.0 and Outils._fpx(hint_size) > Outils._coque_floor and Outils._rw(C.BODY, hint.text, hint_size) + 4.0 > width_ref * .55: hint_size -= 1.0
	var hint_width := Outils._rw(C.BODY, hint.text, hint_size) + 4.0
	var label_room := hint_right - hint_width - 37.0 - 24.0
	while label_size > 1.0 and Outils._fpx(label_size) > Outils._coque_floor and Outils._rw(C.BOLD, label.text, label_size) > label_room: label_size -= 1.0
	hint.add_theme_font_size_override("font_size", Outils._fpx(hint_size))
	label.add_theme_font_size_override("font_size", Outils._fpx(label_size))
	hint.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	hint.tooltip_text = hint.text
	D.place(hint, Rect2(hint_right - hint_width, 0, hint_width, height_ref))
	D.place(rule, Rect2(hint_right - hint_width - 13.0, height_ref * .28, 1.0 / C.density, height_ref * .44))
	D.place(label, Rect2(24, 0, maxf(40.0, label_room), height_ref))
