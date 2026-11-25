extends RefCounted
## Coque du jeu (main.gd) : rendu complet d'un écran (accueil, création, packs, coque de carrière classique),
## rail de gauche, sous-navigation d'un chapitre, date de l'en-tête et bandeau du direct (bouton principal).
## L'écran immersif courant est dessiné par ui/immersive08/shell.gd (Immersive.render) ; ce module ne construit
## l'ancienne coque que pour les écrans qu'il ne prend pas.
## Fonctions statiques ; `m` est la coque (main.gd), qui garde l’état et les noms appelés de l’extérieur.
const G = preload("res://ui/game_skin.gd")
const Immersive = preload("res://ui/immersive08/shell.gd")
const ImmersiveEntry = preload("res://ui/immersive08/entry_canvas.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")
const Entry = preload("res://ui/entry_screens.gd")
const ClubViews = preload("res://ui/club_views.gd")
const SquadViews = preload("res://ui/squad_views.gd")
const MatchUI = preload("res://ui/match_screen.gd")
const PackViews = preload("res://ui/pack_views.gd")
const StaffViews = preload("res://ui/staff_view.gd")
const DevelopmentViews = preload("res://ui/development_view.gd")
const PressViews = preload("res://ui/press_view.gd")
const RelationshipsViews = preload("res://ui/relationships_view.gd")
const WorldViews = preload("res://ui/world_view.gd")
const StrategyViews = preload("res://ui/strategy_view.gd")
const AcademyViews = preload("res://ui/academy_pathways_view.gd")
const AcademyFollowUpViews = preload("res://ui/academy_follow_up_view.gd")
const SupportViews = preload("res://ui/support_view.gd")
const ManagerCareerViews = preload("res://ui/manager_career_view.gd")
const PlaybookViews = preload("res://ui/playbook_view.gd")

## Rendu complet de l'écran ; note son état (ScreenRefresh.stamp) quand un nouvel arbre a été construit.
static func render(m: Control, remember_ui: bool) -> void:
	var before: int = m.root_content.get_instance_id() if is_instance_valid(m.root_content) else 0
	m._render_screen(remember_ui)
	var after: int = m.root_content.get_instance_id() if is_instance_valid(m.root_content) else 0
	if after != before:
		m.screen_renders += 1
		m._screen_stamp = m._screen_state()

static func render_screen(m: Control, remember_ui: bool) -> void:
	if not Immersive.Selections.navigation_allowed(m.model, m.route): m.route = "Réception"
	if m.route != "Accueil" and m.has_meta("accueil_sub"): m.remove_meta("accueil_sub")
	m.call_deferred("_refresh_coach")
	m.call_deferred("_observe_navigation")
	for chapter: Dictionary in m.NAV_CHAPTERS:
		if m.route in chapter.routes: m.chapter_routes[chapter.label] = m.route
	if remember_ui: SquadViews.U.remember(m)
	SquadViews.U.sync(m)
	if is_instance_valid(m.contextual_director) and m.contextual_director.render_if_needed(): return
	if Immersive.render(m):
		if is_instance_valid(m.contextual_director): m.contextual_director.call_deferred("install_entrypoints")
		return
	if is_instance_valid(m.root_content):
		m.remove_child(m.root_content)
		m.root_content.queue_free()
	m.match_screen = null
	m.match_view = null
	m.match_page = null
	m.workspace_inset = null
	m.body_scroll = null
	m.entry_scroll = null
	var root_content := Control.new()
	m.root_content = root_content
	root_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_child(root_content)
	m.move_child(root_content, 0)
	var bg := ColorRect.new()
	bg.color = G.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_content.add_child(bg)
	if m.route == "Accueil":
		m._entry_workspace(ImmersiveEntry.home(m))
		return
	if m.route == "Création":
		m._entry_workspace(ImmersiveEntry.workspace(m,Entry.creation(m),true))
		return
	if m.route == "Packs":
		m._entry_workspace(ImmersiveEntry.workspace(m,PackViews.page(m),false))
		return
	if not m._has_career():
		m.route = "Accueil"
		m._render()
		return
	var shell := G.h(0)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_content.add_child(shell)
	m._build_sidebar(shell)
	var inset := G.margin(8)
	m.workspace_inset = inset
	# Container sorting can happen after the deferred coach refresh. Reposition
	# on its actual geometry, including the sidebar width, after every rebuild.
	inset.item_rect_changed.connect(Callable(m, "_layout_coach"))
	G.fill(inset, true)
	shell.add_child(inset)
	var content := G.v(6 if m.size.y <= 760 else 8)
	content.name = "CareerContent"
	inset.add_child(content)
	var header:=PanelContainer.new()
	header.name="CareerHeader"
	var header_style:=G.T.box(Color("202a2e"),3,Color("3b494e"))
	header_style.set_border_width_all(0)
	header_style.border_width_top=3
	header_style.border_color=m.accent
	header_style.content_margin_left=10;header_style.content_margin_right=10
	header_style.content_margin_top=5;header_style.content_margin_bottom=5
	header.add_theme_stylebox_override("panel",header_style)
	content.add_child(header)
	var top := G.h(8)
	header.add_child(top)
	var chapter_label:="Bureau"
	var chapter_number:=1
	for i in m.NAV_CHAPTERS.size():
		if m.route in m.NAV_CHAPTERS[i].routes:
			chapter_label=m.NAV_CHAPTERS[i].label
			chapter_number=i+1
	var chapter_mark:=G.v(0)
	chapter_mark.custom_minimum_size.x=30
	top.add_child(chapter_mark)
	chapter_mark.add_child(G.label("%02d"%chapter_number,27,G.INK,true))
	chapter_mark.add_child(G.Art.glyph(chapter_label,G.MUTED,16))
	var titles := G.v(0)
	G.fill(titles)
	top.add_child(titles)
	var overline:=G.h(8)
	titles.add_child(overline)
	overline.add_child(G.label(chapter_label.to_upper(),11,G.INK))
	var header_date := G.label("", 11, G.MUTED)
	m.header_date = header_date
	overline.add_child(header_date)
	m._update_header_date()
	var heading := G.label(m.route.to_upper(), 35, G.INK, true)
	m.heading = heading
	heading.add_theme_font_override("font", G.T.BODY)
	heading.add_theme_font_size_override("font_size", 20)
	titles.add_child(heading)
	var save_action:=G.button("SAUVEGARDER", func(): m._command("save"))
	save_action.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	top.add_child(save_action)
	var primary_button := G.button(m.primary_text(), Callable(m, "primary_action"), true)
	m.primary_button = primary_button
	primary_button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	top.add_child(primary_button)
	var minibar := G.label("", 12, G.GOLD)
	m.minibar = minibar
	content.add_child(minibar)
	PackViews.missing_warning(m, content, "career")
	m._build_subnavigation(content)
	var body := G.v(6)
	m.body = body
	G.fill(body, true)
	var body_scroll := ScrollContainer.new()
	m.body_scroll = body_scroll
	body_scroll.name = "CareerWorkspace"
	body_scroll.follow_focus = true
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	G.fill(body_scroll, true)
	content.add_child(body_scroll)
	body_scroll.add_child(body)
	var footer := G.h(8)
	content.add_child(footer)
	var status := G.label(m._settled_status_text(), 11, Color("f1b6a9") if m._status_has_error() else G.MUTED)
	m.status = status
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	G.fill(status)
	footer.add_child(status)
	if m.decision_feedback != null: footer.add_child(m.decision_feedback.control())
	var coach_dock := Control.new()
	coach_dock.name = "CoachCompactDock"
	coach_dock.custom_minimum_size = Vector2(330,34)
	coach_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coach_dock.visible = is_instance_valid(m.coach)
	footer.add_child(coach_dock)
	match m.route:
		"Bureau": body.add_child(ClubViews.office(m))
		"Club": body.add_child(ClubViews.club(m))
		"Calendrier": body.add_child(ClubViews.calendar(m))
		"Classements": body.add_child(ClubViews.tables(m))
		"Finances": body.add_child(ClubViews.finance(m))
		"Effectif": body.add_child(SquadViews.squad(m))
		"Composition": body.add_child(SquadViews.lineup(m))
		"Préparation": body.add_child(SquadViews.preparation(m))
		"Plan de jeu": body.add_child(PlaybookViews.build(m))
		"Recrutement": body.add_child(SquadViews.market(m))
		"Staff": body.add_child(StaffViews.build(m))
		"Formation": body.add_child(DevelopmentViews.build(m))
		"Presse": body.add_child(PressViews.build(m))
		"Vestiaire": body.add_child(RelationshipsViews.build(m))
		"Rivalités": body.add_child(WorldViews.build(m))
		"Stratégie": body.add_child(StrategyViews.build(m))
		"Centre": body.add_child(AcademyViews.build(m))
		"Suivi des jeunes": body.add_child(AcademyFollowUpViews.build(m))
		"Travail du club": body.add_child(SupportViews.build(m))
		"Carrière": body.add_child(ManagerCareerViews.build(m))
		"Match":
			var match_screen := MatchUI.new()
			m.match_screen = match_screen
			match_screen.app = m
			body.add_child(match_screen)
			m.match_page = match_screen
			match_screen.update_frame(m.model)
	m._update_live_bar()

static func entry_workspace(m: Control, page: Control) -> void:
	var entry_scroll := ScrollContainer.new()
	m.entry_scroll = entry_scroll
	entry_scroll.name = "EntryWorkspace"
	entry_scroll.follow_focus = true
	entry_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	entry_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.root_content.add_child(entry_scroll)
	page.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	page.custom_minimum_size.y = 720
	G.fill(page, true)
	entry_scroll.add_child(page)

static func build_subnavigation(m: Control, parent: Container) -> void:
	for chapter: Dictionary in m.NAV_CHAPTERS:
		if m.route not in chapter.routes or chapter.routes.size() < 2: continue
		var band:=PanelContainer.new()
		band.name="ChapterNavigationBand"
		var band_style:=G.T.box(Color("1c262b"),3,Color("354249"))
		band_style.content_margin_left=4;band_style.content_margin_right=4
		band_style.content_margin_top=3;band_style.content_margin_bottom=3
		band.add_theme_stylebox_override("panel",band_style)
		parent.add_child(band)
		var row := G.h(7)
		row.name = "ChapterSubnavigation"
		band.add_child(row)
		for target: String in chapter.routes:
			var button := G.nav_button(target.to_upper(), func(): m._navigate(target), m.accent, m.route == target)
			button.name = "Section_" + target
			button.custom_minimum_size.y = 28
			button.add_theme_font_size_override("font_size", 12)
			G.fill(button)
			row.add_child(button)
		return

static func update_header_date(m: Control) -> void:
	if not is_instance_valid(m.header_date): return
	var header_date: Label = m.header_date
	# Barre haute de la coque : « mar. 17 nov. » et « · J9 » (shell.gd, date_caption).
	if header_date.has_meta("coque"):
		var caption: Array = Immersive.date_caption(m.model)
		header_date.text = str(caption[0])
		var round_text: Label = header_date.get_parent().get_node_or_null("ImmersiveRound")
		if round_text != null: round_text.text = "· " + str(caption[1]) if not str(caption[1]).is_empty() else ""
		var date_button := header_date.get_parent() as Button
		if date_button != null:
			date_button.accessibility_description = str(caption[0]) + (" · " + str(caption[2]) if not str(caption[2]).is_empty() else "")
			date_button.tooltip_text = "Ouvrir le calendrier · " + date_button.accessibility_description
		return
	var meta: Dictionary = m.model.get("meta", {})
	var round_label := str(meta.get("roundLabel", "Journée " + G.n(int(meta.get("round", 0))+1)))
	var planning: Dictionary = m.model.get("calendarPlanning", {})
	var today: Variant = planning.get("today", meta.get("date", ""))
	var date: String = today if today is String else ""
	var parts := date.split("-")
	if parts.size()==3 and parts[1].is_valid_int() and int(parts[1]) in range(1,13):
		var months := ["JANV.","FÉVR.","MARS","AVR.","MAI","JUIN","JUIL.","AOÛT","SEPT.","OCT.","NOV.","DÉC."]
		header_date.text = "%s %s %s" % [parts[2],months[int(parts[1])-1],parts[0]]
		header_date.tooltip_text = round_label
	else:
		var short_round := round_label.get_slice(" · ",0) if round_label.begins_with("Semaine ") else round_label
		if round_label == "Saison terminée": short_round = "Terminée"
		header_date.text = ("SAISON %s  /  %s" % [G.season_label(meta.get("season", 1)),short_round]).to_upper()
		header_date.tooltip_text = round_label if short_round!=round_label else ""
	var calendar := header_date.get_parent() as Button
	if calendar != null:
		calendar.accessibility_description = header_date.text
		if not header_date.tooltip_text.is_empty():
			calendar.accessibility_description += " · " + header_date.tooltip_text
		calendar.tooltip_text = "Ouvrir le calendrier · " + calendar.accessibility_description

static func build_sidebar(m: Control, parent: Node) -> void:
	var rail := PanelContainer.new()
	rail.name="CareerRail"
	rail.custom_minimum_size.x = 176
	var rail_style:=G.T.box(Color("10181c"),0,Color("3b494e"))
	rail_style.set_border_width_all(0)
	rail_style.border_width_right=1
	rail_style.content_margin_left=0;rail_style.content_margin_right=0
	rail_style.content_margin_top=0;rail_style.content_margin_bottom=0
	rail.add_theme_stylebox_override("panel",rail_style)
	parent.add_child(rail)
	var margin := G.margin(6)
	rail.add_child(margin)
	var left := G.v(4)
	margin.add_child(left)
	var logo := G.button("", Callable(m, "pause_menu"))
	logo.tooltip_text = "Rugby Legacy 27 — Menu et sauvegardes"
	var bitmap := TextureRect.new()
	bitmap.texture = load("res://branding/rugby-legacy-27-logo.png")
	bitmap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bitmap.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bitmap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bitmap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var composite := ShaderMaterial.new()
	composite.shader = load("res://branding/black_key.gdshader")
	bitmap.material = composite
	logo.add_child(bitmap)
	logo.add_theme_font_override("font", G.T.DISPLAY)
	logo.add_theme_font_size_override("font_size", 18)
	logo.custom_minimum_size.y = 48
	logo.add_theme_stylebox_override("normal",G.T.box(Color("1d2a30"),3,Color("445259")))
	left.add_child(logo)
	left.add_child(G.separator())
	var club_frame:=PanelContainer.new()
	club_frame.name="SidebarClubIdentity"
	var club_style:=G.T.box(Color("202a2e").lerp(Color(m.accent,1),.12),3,Color("445259"))
	club_style.set_border_width_all(0)
	club_style.border_width_top=3;club_style.border_color=m.accent
	club_style.content_margin_top=5;club_style.content_margin_bottom=6
	club_frame.add_theme_stylebox_override("panel",club_style)
	left.add_child(club_frame)
	var club_identity:=G.v(2)
	club_frame.add_child(club_identity)
	var club_marks:=G.h(6)
	club_identity.add_child(club_marks)
	club_marks.add_child(G.crest(m.model.club,40))
	var club_context:=G.v(0)
	G.fill(club_context)
	club_marks.add_child(club_context)
	club_context.add_child(G.label(G.club_abbr(m.model.club),23,G.INK,true))
	club_context.add_child(G.label("TON CLUB",9,G.MUTED))
	var name := G.label(G.club_name(m.model.club), 16, G.INK, true)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.max_lines_visible=2
	name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	name.tooltip_text=G.club_name(m.model.club)
	club_identity.add_child(name)
	if is_instance_valid(m.navigation_controller): left.add_child(m.navigation_controller.controls())
	left.add_child(G.separator())
	var navigation := G.scroll(left)
	navigation.get_parent().name = "CareerNavigation"
	navigation.add_child(G.label("CARNET DE L'ENTRAÎNEUR", 10, G.MUTED))
	for chapter: Dictionary in m.NAV_CHAPTERS:
		var active: bool = m.route in chapter.routes
		var destination: String = str(m.route if active else m.chapter_routes.get(chapter.label, chapter.routes[0]))
		var b := G.nav_button(str(chapter.label).to_upper(), func(): m._navigate(destination), m.accent, active,str(chapter.label))
		b.name = "Chapter_" + str(chapter.label)
		b.custom_minimum_size.y = 28
		navigation.add_child(b)
	left.add_child(G.label("PRÉALPHA %s  /  WINDOWS" % ProjectSettings.get_setting("application/config/version"), 9, G.GOLD))
	left.add_child(G.button("MENU & SAUVEGARDES", Callable(m, "pause_menu")))

static func update_live_bar(m: Control) -> void:
	if not is_instance_valid(m.minibar): return
	var minibar: Label = m.minibar
	var live: Dictionary = m._live()
	var office_status := minibar.name == "ImmersiveOfficeMatchStatus"
	if office_status: minibar.visible = not live.is_empty()
	if not live.is_empty():
		var teams: Array = live.get("teams", [{},{}])
		var score: Array = live.get("score", [0,0])
		var score_line := "%s  %s — %s  %s" % [G.club_abbr(teams[0]),G.n(score[0]),G.n(score[1]),G.club_abbr(teams[1])]
		var minute := G.n(live.get("minute",0)) + " min"
		if office_status:
			var state := "MATCH TERMINÉ" if live.get("finished",false) else ("PAUSE" if live.get("paused",false) else "EN DIRECT")
			minibar.text = score_line + "\n" + minute + "  ·  " + state
			minibar.tooltip_text = minibar.text
		else:
			minibar.text = score_line + "   ·   " + minute + ("  /  PAUSE" if live.get("paused",false) else "")
	else:
		var meta: Dictionary = m.model.get("meta", {})
		var club_count := int(meta.get("database", {}).get("clubCount", 0))
		match meta.get("mode"):
			"world": minibar.text = "CARRIÈRE MONDIALE  /  %s CLUBS" % G.n(club_count)
			"france30", "common": minibar.text = "ÉLITE & ACCESSION  /  %s CLUBS" % G.n(club_count)
			_: minibar.text = "CARRIÈRE HISTORIQUE  /  14 CLUBS"
	if is_instance_valid(m.primary_button):
		var primary_button: Button = m.primary_button
		var action: String = m.primary_text()
		primary_button.text = "Continuer" if primary_button.name == "ImmersiveContinue" else action
		primary_button.disabled = false
		if live.is_empty():
			if m._press_required():
				if primary_button.name == "ImmersiveContinue": primary_button.text = "Conf. de presse"
			elif not Immersive.Selections.current_fixture(m.model).is_empty():
				if primary_button.name == "ImmersiveContinue": primary_button.text = "Courrier match"
			elif not m.model.meta.get("canAdvanceSeason", false):
				var daily: Dictionary = m._daily_progression()
				if primary_button.name == "ImmersiveContinue": primary_button.text = daily.get("short", "Continuer")
				# Coque commune : Continuer bloqué reste actif (« ! » + raison, clic = écran qui bloque).
				primary_button.disabled = bool(daily.get("disabled", false)) and primary_button.name != "ImmersiveContinue"
		if office_status and not live.is_empty():
			primary_button.text = "Valider le résultat" if live.get("finished",false) else "Retour au direct"
		if primary_button.name == "ImmersiveContinue" and live.get("finished",false) and is_instance_valid(m.contextual_director) and m.contextual_director.en_consultation():
			primary_button.text = "Après-match"
		if m.connection_error and m.bridge.child_pid <= 0 and primary_button.name == "ImmersiveContinue": primary_button.text = "Relancer"
		primary_button.tooltip_text = m.primary_tooltip()
		if primary_button.name == "ImmersiveContinue": Immersive.sync_continue(m)
		else: fit_button_text(primary_button)
	if m.waiting and SeasonPreparation.is_advance(m.last_command): SeasonPreparation.show_pending(m, true)

## Bouton à texte rogné (clip_text) : réduit la police jusqu'à ce que le libellé tienne en entier, icône comprise
## (recette native du 16/11/2026 : « Décision attendue » s'affichait « Décision attendu »). Plancher : 12 px.
static func fit_button_text(button: Button) -> void:
	if not is_instance_valid(button) or button.size.x <= 0: return
	if not button.has_meta("fit_base_font_size"): button.set_meta("fit_base_font_size", button.get_theme_font_size("font_size"))
	var size_px := int(button.get_meta("fit_base_font_size"))
	var font := button.get_theme_font("font")
	var style := button.get_theme_stylebox("normal")
	var room := button.size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
	if button.icon != null: room -= button.get_theme_constant("icon_max_width") + button.get_theme_constant("h_separation")
	while size_px > 12 and font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > room: size_px -= 1
	button.add_theme_font_size_override("font_size", size_px)
