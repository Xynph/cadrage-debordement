extends "res://ui/immersive08/preparation_xv.gd"
## Dossier adverse et intentions de jeu. Le troisième onglet ouvre le planning.
## Fichier public de l'écran (construction, compact, en-tête, onglets, dossier, restauration) ; le reste vit dans la chaîne
## preparation_socle.gd ← preparation_dossier.gd ← preparation_xv.gd.

static func build(application: Control, canvas: Control) -> void:
	var page := new()
	page.name = "ImmersivePreparation"
	page.app = application
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, 2248, 1230))
	page._build()

static func compact(app: Control) -> Control:
	var dossier: Control = app.SquadViews.preparation(app)
	var next: Variant = app.model.get("next")
	if not SeasonPreparation.is_japan(app.model.meta):
		var context: Control
		if next is Dictionary and not next.is_empty():
			context = _compact_fixture(app,next)
		else:
			var upcoming := _upcoming_preparation_note(app.model.meta)
			if not upcoming.is_empty():
				context = C.wrap(upcoming,26,C.GOLD,true,700)
				if SeasonPreparation.is_champ(app.model.meta):
					var summary := C.v(4)
					summary.add_child(context)
					summary.add_child(C.wrap(CHAMP_DOSSIER_PENDING,20,C.MUTED))
					context = summary
		if context != null:
			dossier.add_child(context)
			# Sous la bannière de la page, au-dessus de la barre d'onglets.
			var banner := dossier.get_node_or_null("PreparationBanner")
			dossier.move_child(context,banner.get_index() + 1 if banner != null else 0)
		return dossier
	var preparation := SeasonPreparation.data(app.model.meta)
	if preparation.is_empty() and not next is Dictionary: return dossier
	var page := C.v(10)
	C.fill(page,true)
	var card := C.card()
	page.add_child(card)
	var row := C.h(20)
	C.content(card).add_child(row)
	var summary := C.v(4)
	C.fill(summary)
	row.add_child(summary)
	summary.add_child(C.wrap(("PRÉPARATION · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "jlo-d1")))).to_upper(),30,C.GOLD,true,700))
	if not preparation.is_empty():
		summary.add_child(C.wrap(World.preparation_note(preparation),29,C.IVORY))
		var advance := C.button(app.primary_text(),app.primary_action,false,app.accent)
		advance.name = "JapanPreparationDossierAdvance"
		advance.disabled = app.waiting
		row.add_child(advance)
	else:
		summary.add_child(_compact_fixture(app,next,true))
	page.add_child(dossier)
	return page

static func _upcoming_preparation_note(meta: Dictionary) -> String:
	if meta.get("leagueId") not in ["srp", "champ"]: return ""
	var preparation := SeasonPreparation.data(meta)
	return "" if preparation.is_empty() else World.preparation_note(preparation)

static func _fixture_position(app: Control, next: Dictionary, show_date: bool) -> String:
	var position := P.fixture_position(next,app.model.club.get("id"))
	var date := P.fixture_date(next,true) if show_date else ""
	return position if date.is_empty() else position+"  ·  "+date

static func _compact_fixture(app: Control, next: Dictionary, show_date: bool = false) -> HBoxContainer:
	var row := C.h(16)
	var position := C.label(_fixture_position(app,next,show_date),26,C.GOLD,true,700)
	position.name = "PreparationFixturePosition"
	row.add_child(position)
	var venue_name := P.fixture_venue(next,false)
	if not venue_name.is_empty():
		var venue := C.wrap(venue_name,26,C.IVORY,true,600)
		venue.name = "PreparationFixtureVenue"
		C.fill(venue)
		row.add_child(venue)
	return row


## ---- Construction -----------------------------------------------------------------------------------

## Ouvre une sous-page pleine page de la Préparation (« planning », « reprise », « reperes », « conseils », « xv »), depuis
## n'importe quel écran : retour par « ← Retour » ou Échap, une étape d'historique (Précédent / Suivant).
static func ouvrir_sous_page(application: Control, sous_page: String) -> void:
	if not application.management_ui.get("preparation") is Dictionary:
		application.management_ui.preparation = {"tab":0,"outer":[0,0,0],"attack":0,"defense":0,"focus":["","",""]}
	if application.route != "Préparation": application._navigate("Préparation")
	var etat: Dictionary = application.management_ui.preparation
	etat.tab = 0
	etat.sub = sous_page
	etat.outer[0] = 0
	application._render()
	if is_instance_valid(application.navigation_controller): application.navigation_controller.observe("Préparation")

## Échap ferme la sous-page ouverte (règle unique : fenêtre, puis sous-écran, puis menu).
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or active_tab != 0 or str(state.get("sub", "")).is_empty(): return
	get_viewport().set_input_as_handled()
	_ouvrir_sous("")

func _build() -> void:
	if not app.management_ui.get("preparation") is Dictionary:
		app.management_ui.preparation = {"tab":0,"outer":[0,0,0],"attack":0,"defense":0,"focus":["","",""]}
	state = app.management_ui.preparation
	active_tab = clampi(int(state.tab), 0, 1)
	reports = app.model.get("decisions", {}).get("preparation") if app.model.get("decisions", {}).get("preparation") is Dictionary else {}
	fixture = app.model.get("next") if app.model.get("next") is Dictionary else {}
	_heading()
	var hauteur := 1230.0
	if active_tab == 0: hauteur = maxf(hauteur, 257.0 + _dossier() + 10.0)
	else: _consignes()
	var conteneur := get_parent() as Control
	size.y = C.px(hauteur)
	if conteneur != null: conteneur.custom_minimum_size.y = maxf(conteneur.custom_minimum_size.y, C.px(hauteur))
	add_child(match_context)
	match_context.bind(app)
	app.bridge.model_changed.connect(_refresh_briefing)
	_observe(self)
	if app.body_scroll != null:
		app.body_scroll.get_v_scroll_bar().value_changed.connect(func(value: float):
			if focus_ready: state.outer[active_tab] = int(value))
	_restore.call_deferred()

func _refresh_briefing(model: Dictionary) -> void:
	# Ticks update the live-state wording without rebuilding the focused page.
	var titre := find_child("PreparationBriefingTitle_live", true, false) as Label
	if titre == null: return
	for check: Dictionary in Briefing.project(model).checks:
		if check.id != "live": continue
		titre.text = check.title
		var bouton := find_child("PreparationBriefing_live", true, false) as Button
		if bouton == null: return
		bouton.tooltip_text = check.detail + "\n" + check.caption
		bouton.accessibility_name = check.title + " · " + check.detail

func _heading() -> void:
	var hero := D.panel(self, Rect2(0, 0, 2248, 167), "", "", "", "PreparationHero")
	hero.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var japan := SeasonPreparation.is_japan(app.model.meta)
	var preparation := SeasonPreparation.data(app.model.meta) if japan else {}
	if active_tab == 1:
		var surtitre := D.text(hero, 4, 34, ("PRÉPARATION · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "jlo-d1")))).to_upper() if japan else "", 20, Charte.IVOIRE_2, 600, 1065)
		surtitre.name = "PreparationLiveContext"
		match_context.live_context = surtitre
	var titre := ("Préparer la saison · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "jlo-d1")))) if not preparation.is_empty() else "Préparation"
	app.heading = _titre(hero, 4, 88, titre.to_upper(), 56, Charte.IVOIRE, 1355)
	app.heading.add_theme_font_override("font", Charte.TITRE_FICHE)
	if active_tab == 1:
		app.heading.name = "PreparationContextHeading"
		match_context.live_heading = app.heading
	_ligne_contexte(hero, preparation, 134)
	if P.is_derby(app.model) and preparation.is_empty(): D.derby_chip(hero, Rect2(2106, 118, 98, 30))
	var voir_match := MatchContext.match_available(app.model)
	# Commandes d'en-tête : lien « Revoir la composition » puis l'action principale (un seul ivoire plein).
	var droite := 2248.0
	if not preparation.is_empty():
		var avancer := _bouton(hero, Rect2(droite - 420, 50, 420, 54), app.primary_text().trim_suffix("  →"), app.primary_action, "ivoire", "arrow", "JapanPreparationDossierAdvance")
		avancer.disabled = app.waiting
		droite -= 440
	elif voir_match:
		match_context.match_button = _bouton(hero, Rect2(droite - 400, 50, 400, 54), "", match_context.open_match, "ivoire", "arrow", "PreparationGoMatch")
		_verrou_match(hero, match_context.match_button, droite)
		droite -= 420
	else:
		_bouton(hero, Rect2(droite - 400, 50, 400, 54), "Carnet de jeu", func(): app._navigate("Plan de jeu"), "ivoire", "arrow", "PreparationOpenPlaybook")
		droite -= 420
	_bouton(hero, Rect2(droite - 400, 50, 400, 54), "Revoir la composition", func(): app._navigate("Composition"), "lien", "arrow", "PreparationComposition")
	var barre := Control.new()
	barre.name = "PreparationTabs"
	barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(barre)
	D.place(barre, Rect2(0, 182, 2248, 57))
	var libelles := ["Dossier adverse", "Consignes", "Entraînement"]
	for i in TABS.size():
		var bouton := _bouton(barre, Rect2(i * 256, 0, 248, 55), libelles[i], func(): _choose(i), "onglet", "", "PreparationTab" + TABS[i], i == active_tab)
		if i == 1: match_context.focus_fallback = bouton
		bouton.toggle_mode = true
		bouton.set_pressed_no_signal(i == active_tab)
		bouton.gui_input.connect(func(event: InputEvent):
			if event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT, KEY_RIGHT]:
				bouton.accept_event()
				_choose(posmod(i + (1 if event.keycode == KEY_RIGHT else -1), TABS.size())))
	# Liens d'organisation, alignés à droite de la barre d'onglets.
	var x := 2248.0
	if voir_match:
		x -= 330
		_bouton(barre, Rect2(x, 0, 320, 55), "Carnet de jeu", func(): app._navigate("Plan de jeu"), "lien", "arrow", "PreparationOpenPlaybook")
	if not voir_match and preload("res://ui/reprise_view.gd").relevant(app.model):
		x -= 330
		_bouton(barre, Rect2(x, 0, 320, 55), "La reprise", func(): load("res://ui/reprise_dialog.gd").open(app), "lien", "calendar", "PreparationReprise")
	x -= 350
	_bouton(barre, Rect2(x, 0, 340, 55), "Préparer la suite", func(): load("res://ui/manager_planning.gd").open(app), "lien", "calendar", "PreparationManagerPlanning")
	D.line(self, Vector2(0, 241), Vector2(2248, 241), Color(Charte.FILET, .85))

## Le match n'est pas encore ouvert : bouton verrouillé (cadenas + raison écrite, jamais la couleur seule).
func _verrou_match(hero: Control, bouton: Button, droite: float) -> void:
	var live: Variant = app.model.get("live")
	if live is Dictionary and not live.is_empty(): return
	if app.model.get("meta", {}).get("calendarCadence", {}).get("matchReady", false): return
	bouton.disabled = true
	bouton.icon = null
	var style := bouton.get_theme_stylebox("disabled").duplicate() as StyleBoxFlat
	style.content_margin_right = C.px(48)
	bouton.add_theme_stylebox_override("disabled", style)
	_marque(hero, droite - 34, 77, 20, "cadenas", Charte.IVOIRE_2)
	var date := P.fixture_date(fixture)
	var raison := "S’ouvre le jour du match" + (" · " + date if not date.is_empty() else "")
	var etiquette := _texte(hero, droite, 124, raison, 15, Charte.IVOIRE_2, 400, HORIZONTAL_ALIGNMENT_RIGHT)
	etiquette.name = "PreparationGoMatchReason"
	bouton.tooltip_text = raison
	bouton.accessibility_name = "Aller au jour de match, verrouillé · " + raison

## Sous-titre : « Club – Adversaire · position et date · terrain · classements » ; les deux clubs sont cliquables.
func _ligne_contexte(hero: Control, preparation: Dictionary, baseline: float) -> void:
	var pose := 4.0
	if not preparation.is_empty():
		D.text(hero, pose, baseline, World.preparation_note(preparation), 20, Charte.IVOIRE, 500, 1700, HORIZONTAL_ALIGNMENT_LEFT, true)
		return
	if fixture.is_empty():
		var legende := _upcoming_preparation_note(app.model.meta)
		if legende.is_empty(): legende = P.next_fixture_caption(app.model, "Aucune rencontre annoncée")
		D.text(hero, pose, baseline, legende, 20, Charte.IVOIRE, 500, 1700, HORIZONTAL_ALIGNMENT_LEFT, true)
		return
	var domicile: Dictionary = fixture.get("home", {})
	var exterieur: Dictionary = fixture.get("away", {})
	var nous_id: Variant = app.model.club.get("id")
	for rang in 2:
		var club: Dictionary = domicile if rang == 0 else exterieur
		var nom := G.club_name(club)
		var largeur := _largeur(nom, 20, true) + 14
		Link.name_link(app, hero, C.reach_rect(Rect2(pose - 4, baseline - 26, largeur, 34)), "club", str(int(club.get("id", -1))) if club.get("id") != null else "", nom, 20, Charte.IVOIRE, "PreparationContextClub" + ("Own" if club.get("id") == nous_id else "Opponent"))
		pose += largeur
		if rang == 0:
			_texte(hero, pose, baseline, "–", 20, Charte.IVOIRE_2, 24)
			pose += 30
	var morceaux: Array[Array] = []
	var competition := str(fixture.get("label", ""))
	if not competition.is_empty(): morceaux.append([competition, ""])
	morceaux.append([_fixture_position(app, fixture, true), "PreparationFixturePosition"])
	var terrain := P.fixture_venue(fixture, false)
	if not terrain.is_empty(): morceaux.append([terrain, "PreparationFixtureVenue"])
	var classement := _classement_texte()
	if not classement.is_empty(): morceaux.append([classement, ""])
	for morceau: Array in morceaux:
		_texte(hero, pose, baseline, "·", 20, Charte.IVOIRE_2, 20)
		pose += 22
		var etiquette := _texte(hero, pose, baseline, str(morceau[0]), 20, Charte.IVOIRE, _largeur(str(morceau[0]), 20) + 8)
		if not str(morceau[1]).is_empty(): etiquette.name = str(morceau[1])
		pose += _largeur(str(morceau[0]), 20) + 14

func _classement_texte() -> String:
	var nous: Dictionary = app.model.club
	var eux := _opponent()
	if eux.is_empty() or not P.standings_open(nous) or not P.standings_open(eux): return ""
	var rang_nous := P.rank_ordinal(nous)
	var rang_eux := P.rank_ordinal(eux)
	if rang_nous == "—" or rang_eux == "—" or not _nombre(nous.get("points")) or not _nombre(eux.get("points")): return ""
	return "%s (%d pts) contre %s (%d pts)" % [rang_nous, int(nous.points), rang_eux, int(eux.points)]


func _observe(node: Node) -> void:
	if node is BaseButton and node.focus_mode != Control.FOCUS_NONE and node != match_context.pause_button:
		node.focus_entered.connect(func():
			if focus_ready: state.focus[active_tab] = str(node.name))
	for child in node.get_children(): _observe(child)

func _restore() -> void:
	if not is_inside_tree(): return
	var tree := get_tree()
	await tree.process_frame
	if not is_inside_tree(): return
	await tree.process_frame
	if not is_inside_tree(): return
	for pair: Array in [["PreparationAttackScroll", "attack"], ["PreparationDefenseScroll", "defense"]]:
		var scroll := find_child(pair[0], true, false) as ScrollContainer
		if scroll != null: scroll.scroll_vertical = int(state.get(pair[1], 0))
	if app.body_scroll != null: app.body_scroll.scroll_vertical = int(state.outer[active_tab])
	focus_ready = true
	var focus_id := str(state.focus[active_tab])
	if focus_id.is_empty(): return
	var previous := find_child(focus_id, true, false) as BaseButton
	if previous != null and previous.is_visible_in_tree():
		# Consigne grisée le temps que le moteur réponde (commande suivante, sauvegarde) : le focus l'attend
		# au lieu de retomber sur l'onglet, sauf si le joueur l'a posé ailleurs entre-temps.
		var frames := 0
		while previous.disabled and match_context != null and match_context._engine_busy() and frames < 240:
			await tree.process_frame
			frames += 1
			if not is_inside_tree() or not is_instance_valid(previous): return
			if get_viewport().gui_get_focus_owner() != null: return
		if previous.disabled: previous = find_child("PreparationTab" + TABS[active_tab], true, false) as BaseButton
		if previous != null: previous.grab_focus()

## ---- Onglet « Dossier adverse » ---------------------------------------------------------------------

## Construit le dossier (ou la sous-page demandée) et renvoie sa hauteur en unités du gabarit.
func _dossier() -> float:
	var section := _section("PreparationDossier")
	match str(state.get("sub", "")):
		"reperes": return _sous_reperes(section)
		"conseils": return _sous_conseils(section)
		"xv": return _sous_xv(section)
		"adversaire": return RapportAdverse.construire(self, section)
		"planning", "reprise": return _sous_externe(section, str(state.get("sub", "")))
	var opponent := _opponent()
	var haut := 0.0
	if reports.is_empty():
		var vide := _panneau(section, Rect2(0, 0, 1344, 540), "Dossier adverse", "PreparationUnknownOpponent")
		if not opponent.is_empty():
			_crest(vide, opponent, Rect2(30, 90, 92, 94))
			# Nom cliquable : fiche du club adverse.
			Link.name_link(app, vide, C.reach_rect(Rect2(146, 98, 1130, 50)), "club", str(int(opponent.get("id", -1))) if opponent.get("id") != null else "", G.club_name(opponent), 42, Charte.IVOIRE, "PreparationKnownOpponent")
			_etiquette(vide, 150, 176, "Adversaire annoncé au calendrier", 1130)
		var champ_preparing := fixture.is_empty() and SeasonPreparation.is_champ(app.model.meta) and not SeasonPreparation.data(app.model.meta).is_empty()
		var lines := D.words(CHAMP_DOSSIER_PENDING if champ_preparing else "Aucun dossier disponible pour cette rencontre.", 86, 3)
		for line in lines.size(): _texte(vide, 29, 252 + line * 34, lines[line], 26, Charte.IVOIRE, 1270)
		_texte(vide, 29, 340, "Les résultats récents, les notes et les joueurs adverses seront affichés", 20, Charte.IVOIRE_2, 1270)
		_texte(vide, 29, 372, "lorsque ces informations seront publiées.", 20, Charte.IVOIRE_2, 1270)
		_bouton(vide, Rect2(24, 460, 420, 50), "Voir le calendrier", func(): app._navigate("Calendrier"), "lien", "calendar", "PreparationOpenCalendar")
		_a_faire(section, Rect2(1361, 0, 887, 540))
		haut = 556.0
	else:
		_danger(section, Rect2(0, 0, 2248, 68))
		# Gabarit 1080p sans défilement (recette immersive08) : danger 76, rapport + repères ~440, forme + surveillés ~254, XV ~196.
		var hauteur_rapport := maxf(108.0 + 6.0 * _pas_rapport() + 44.0, 56.0 + 5.0 * C.reach(62.0) + 82.0)
		_rapport(section, Rect2(0, 82, 1344, hauteur_rapport))
		_a_faire(section, Rect2(1361, 82, 887, hauteur_rapport))
		haut = 82.0 + hauteur_rapport + 14.0
		var hauteur_bas := _forme(section, Rect2(0, haut, 900, 0))
		_surveiller(section, Rect2(916, haut, 1332, hauteur_bas))
		haut += hauteur_bas + 14.0
	if not opponent.is_empty(): haut += _xv_bande(section, Rect2(0, haut, 2248, 0), opponent)
	return haut

## ---- Onglet « Consignes » ----------------------------------------------------------------------------

## Une tuile à schéma de terrain par intention (preparation_consignes.gd).
func _consignes() -> void:
	Consignes.consignes(self)
