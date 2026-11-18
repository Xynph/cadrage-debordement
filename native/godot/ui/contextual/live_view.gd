extends Control
const S = preload("res://ui/contextual/skin.gd")
const TempsForts = preload("res://ui/contextual/match_temps_forts.gd")
const Meteo = preload("res://ui/contextual/meteo_texte.gd")
const Pilotage = preload("res://ui/contextual/match_consignes.gd")
const FenetreEquipe = preload("res://ui/contextual/match_equipe.gd")
var director: Node
## Régie du match en temps forts (mode de base ; absente avec CD_MATCH_TEMPS_FORTS=0).
var regie: Node
var _cadence: OptionButton
var _niveau: OptionButton
var _niveaux: Array = []
var _reglages_temps_forts := false
var app: Control
var stage: Node3D
var model: Dictionary = {}
var clock: Label
var score: Label
## Météo et vent sous le score (même bandeau en 3D et pendant l'entracte 2D).
var meteo_ligne: Label
var home: Label
var away: Label
var play: Button
var finish: Button
var events: Label
var drawer: PanelContainer
var drawer_body: VBoxContainer
var journal: VBoxContainer
var _journal_shell: PanelContainer
## Tiroir des statistiques et du journal (menu Plus) ; composition et consignes sont dans la fenêtre Équipe.
var drawer_tab := ""
## Fenêtre « Équipe » (match_equipe.gd) : composition, banc, cris, consignes ; elle met le match en pause.
var equipe: Control
## Consignes en direct envoyées et pas encore confirmées par le moteur (axe → cran).
var _envois_consignes: Dictionary = {}
var _drawer_key := ""
var _camera_controls: Array[Button] = []
var _applied_camera := ""
var _applied_quality := ""
## Écusson et couleur de chaque club dans le bandeau (remplis au premier affichage).
var _ecussons: Array = [null, null]
var _ecussons_cle := ""
## Barre de commandes du bas : masquée pendant l'écran intermédiaire (il a sa propre barre).
var barre_commandes: Control
## Bande de commandes des temps forts, sous le bandeau du score : la même pendant les temps forts
## 3D et l'entracte 2D (demande de Léo, 12 novembre 2026). L'écran intermédiaire y pose sa barre.
var bande_temps_forts: HBoxContainer
## Lisibilité du bandeau et de la légende (lot 5, 16/11/2026) : tailles écrites pour 1080p,
## agrandies avec la hauteur de l'écran (×1,33 en 1440p), jamais réduites en dessous.
const BANDEAU_TAILLES := {"horloge": 32, "equipe": 32, "score": 60, "pause": 22, "legende": 24, "ecusson": 52, "meteo": 20}
const LEGENDE_LARGEUR := 720
var echelle := 1.0
var _legende: Control

func _ready() -> void:
	name = "ContextualLiveMatch"
	app = director.app
	var container := SubViewportContainer.new()
	container.name = "LiveMatchViewport"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(container)
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	stage = load("res://match_view.gd").new()
	if stage.has_method("set_club_identity"): stage.set_club_identity(app.model.get("club", {}))
	viewport.add_child(stage)
	var frame := S.frame(self, 18)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Bandeau de score façon retransmission : horloge en pastille, écusson et couleur de chaque
	# club, score très grand en police d'affichage. L'élément le plus visible de l'écran.
	var scoreboard := S.panel(frame, 8)
	var coque_score: PanelContainer = scoreboard.get_parent().get_parent()
	var fond := S.G.T.box(Color(0.05, 0.11, 0.09, 0.94), 12, Color(S.GOLD, 0.28))
	fond.shadow_color = Color(0, 0, 0, 0.3)
	fond.shadow_size = 8
	coque_score.add_theme_stylebox_override("panel", fond)
	var banner := S.G.h(14)
	scoreboard.add_child(banner)
	var pastille := PanelContainer.new()
	var style_pastille := S.G.T.box(S.GOLD, 20)
	style_pastille.content_margin_left = 16
	style_pastille.content_margin_right = 16
	style_pastille.content_margin_top = 2
	style_pastille.content_margin_bottom = 2
	pastille.add_theme_stylebox_override("panel", style_pastille)
	pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	banner.add_child(pastille)
	clock = S.label("", 28, Color("10201a"))
	clock.add_theme_font_override("font", S.G.T.DISPLAY)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock.custom_minimum_size.x = 92
	pastille.add_child(clock)
	home = S.label("", 24)
	home.add_theme_font_override("font", S.G.T.DISPLAY)
	home.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	home.clip_text = true
	home.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	S.G.fill(home)
	banner.add_child(home)
	_ecussons[0] = S.G.h(6)
	banner.add_child(_ecussons[0])
	var cadre_score := PanelContainer.new()
	var style_score := S.G.T.box(Color(0, 0, 0, 0.32), 10, Color(S.GOLD, 0.35))
	style_score.content_margin_left = 22
	style_score.content_margin_right = 22
	style_score.content_margin_top = 0
	style_score.content_margin_bottom = 0
	cadre_score.add_theme_stylebox_override("panel", style_score)
	banner.add_child(cadre_score)
	score = S.label("", 46, S.GOLD)
	score.add_theme_font_override("font", S.G.T.DISPLAY)
	score.custom_minimum_size.x = 150
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cadre_score.add_child(score)
	_ecussons[1] = S.G.h(6)
	banner.add_child(_ecussons[1])
	away = S.label("", 24)
	away.add_theme_font_override("font", S.G.T.DISPLAY)
	away.clip_text = true
	away.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	S.G.fill(away)
	banner.add_child(away)
	play = S.button("PAUSE", _pause)
	play.name = "MatchPauseButton"
	_habiller_pause(play)
	banner.add_child(play)
	meteo_ligne = S.label("", 18, S.MUTED)
	meteo_ligne.name = "MatchWeather"
	meteo_ligne.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meteo_ligne.clip_text = true
	meteo_ligne.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meteo_ligne.hide()
	scoreboard.add_child(meteo_ligne)
	if TempsForts.enabled():
		bande_temps_forts = S.G.h(12)
		bande_temps_forts.name = "MatchCommandBand"
		bande_temps_forts.alignment = BoxContainer.ALIGNMENT_END
		frame.add_child(bande_temps_forts)
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(space, true)
	frame.add_child(space)
	var event_row := S.G.h(10)
	frame.add_child(event_row)
	var event_panel := S.panel(event_row, 10)
	event_panel.get_parent().custom_minimum_size.x = LEGENDE_LARGEUR
	event_panel.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_legende = event_panel.get_parent()
	events = S.wrap("", 14, S.TEXT)
	event_panel.add_child(events)
	event_row.add_child(S.G.spacer())
	var controls := S.panel(frame, 8)
	barre_commandes = controls.get_parent().get_parent()
	var bar := S.G.h(7)
	controls.add_child(bar)
	var bouton_equipe := S.button("ÉQUIPE", func(): ouvrir_equipe())
	bouton_equipe.name = "MatchTeamButton"
	bouton_equipe.tooltip_text = "Composition, banc, cris de la touche et consignes (le match se met en pause)."
	bar.add_child(bouton_equipe)
	for title in ["Stats", "Journal"]:
		bar.add_child(S.button(title.to_upper(), func(): _toggle_drawer(title)))
	for pair in [["tv", "TV"], ["tactical", "VUE DE DESSUS"], ["action", "CONTACT"]]:
		var button := S.button(pair[1], func(): _choose_camera(pair[0]))
		_camera_controls.append(button)
		bar.add_child(button)
	_cadence = OptionButton.new()
	_cadence.custom_minimum_size.y = 38
	for text in ["Cadence ×1", "Cadence ×4", "Cadence ×12"]: _cadence.add_item(text)
	_cadence.select(maxi(0, [1, 4, 12].find(app.tick_steps)))
	_cadence.item_selected.connect(_choisir_cadence)
	_cadence.set_meta("contextual_enabled", true)
	bar.add_child(_cadence)
	# Ce que le match montre, des temps forts choisis au match complet : visible en temps forts.
	_niveau = OptionButton.new()
	_niveau.name = "MatchLevel"
	_niveau.custom_minimum_size.y = 38
	_niveau.tooltip_text = "Ce que le match montre : des temps forts choisis au match complet. Conservé pour les prochains matchs."
	_niveau.set_meta("contextual_enabled", true)
	_niveau.item_selected.connect(func(index: int): if regie != null and index >= 0 and index < _niveaux.size(): regie.choisir_niveau(str(_niveaux[index].get("id", ""))))
	_niveau.hide()
	bar.add_child(_niveau)
	if TempsForts.enabled():
		regie = TempsForts.new()
		add_child(regie)
		regie.setup(self, container, viewport, space)
	bar.add_child(S.G.spacer())
	bar.add_child(S.button("CONFIER LA FIN À L’ADJOINT", confier_fin))
	finish = S.button("VALIDER LA JOURNÉE  →", func(): director.command("finish_round"), false, true)
	bar.add_child(finish)
	drawer = PanelContainer.new()
	drawer.name = "MatchDrawer"
	drawer.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	drawer.offset_left = -450
	drawer.offset_right = -18
	drawer.offset_top = 100
	# En temps forts, le tiroir s'ouvre sous la bande de commandes : Équipe, Paramètres
	# et Plus restent cliquables tiroir ouvert.
	if bande_temps_forts != null:
		var caler := func():
			if is_instance_valid(drawer) and bande_temps_forts.is_inside_tree():
				drawer.offset_top = maxf(100.0, bande_temps_forts.get_global_rect().end.y - get_global_rect().position.y + 8.0)
		bande_temps_forts.resized.connect(caler)
		bande_temps_forts.item_rect_changed.connect(caler)
	drawer.anchor_bottom = 1
	drawer.offset_bottom = -90
	drawer.add_theme_stylebox_override("panel", S.G.T.box(S.PANEL, 5, Color("68785a")))
	add_child(drawer)
	var drawer_margin := S.G.margin(14)
	drawer.add_child(drawer_margin)
	var drawer_column := S.G.v(8)
	drawer_margin.add_child(drawer_column)
	drawer_column.add_child(S.button("FERMER  ×", _fermer_tiroir))
	drawer_body = S.G.scroll(drawer_column)
	S.G.fill(drawer_body.get_parent(), true)
	_journal_shell = PanelContainer.new()
	_journal_shell.add_theme_stylebox_override("panel", S.G.T.box(Color("e8dfce"), 3, S.G.LINE))
	S.G.fill(_journal_shell, true)
	drawer_column.add_child(_journal_shell)
	var journal_margin := S.G.margin(8)
	_journal_shell.add_child(journal_margin)
	journal = preload("res://ui/match_journal.gd").new()
	journal.setup(app)
	journal_margin.add_child(journal)
	_journal_shell.hide()
	drawer.hide()
	equipe = FenetreEquipe.new()
	equipe.view = self
	equipe.app = app
	add_child(equipe)
	app.match_view = stage
	app.pause_button = play
	app.match_finish = finish
	app.match_clock = clock
	_mettre_a_l_echelle()
	get_viewport().size_changed.connect(_mettre_a_l_echelle)
	apply_preferences()

## Bouton PAUSE / REPRENDRE du bandeau : même famille que les boutons Équipe et Paramètres de la
## bande de commandes (Barlow Condensed demi-gras, capitales, fond sapin à plat, survol or).
const POLICE_PAUSE = preload("res://fonts/BarlowCondensed-SemiBold.ttf")
static func _habiller_pause(bouton: Button) -> void:
	bouton.add_theme_font_override("font", POLICE_PAUSE)
	for etat in ["normal", "hover", "pressed"]:
		var style := S.G.T.box(Color("18231f") if etat == "normal" else Color("1f2e2b"), 10)
		style.set_border_width_all(0)
		style.content_margin_left = 22
		style.content_margin_right = 22
		bouton.add_theme_stylebox_override(etat, style)
	var focus := S.G.T.box(Color.TRANSPARENT, 10, Color("e0b35a"))
	focus.set_border_width_all(2)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.add_theme_color_override("font_color", Color("f2ecdc"))
	for couleur in ["font_hover_color", "font_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(couleur, Color("e0b35a"))

## Échelle de l'écran : 1 jusqu'en 1080p, puis proportionnelle à la hauteur (1,33 en 1440p).
static func echelle_pour(hauteur: float) -> float:
	return clampf(hauteur / 1080.0, 1.0, 2.0)

## Bandeau du score (le même en 3D et pendant l'entracte 2D) et légende du temps fort, lisibles
## d'un coup d'œil en 1080p comme en 1440p : horloge, noms, score, pause et légende agrandis.
func _mettre_a_l_echelle() -> void:
	if not is_instance_valid(clock): return
	echelle = echelle_pour(get_viewport().get_visible_rect().size.y)
	var t := func(cle: String) -> int: return roundi(float(BANDEAU_TAILLES[cle]) * echelle)
	clock.add_theme_font_size_override("font_size", t.call("horloge"))
	clock.custom_minimum_size.x = roundi(104 * echelle)
	for nom: Label in [home, away]: nom.add_theme_font_size_override("font_size", t.call("equipe"))
	score.add_theme_font_size_override("font_size", t.call("score"))
	score.custom_minimum_size.x = roundi(170 * echelle)
	play.add_theme_font_size_override("font_size", t.call("pause"))
	play.custom_minimum_size = Vector2(roundi(132 * echelle), roundi(46 * echelle))
	events.add_theme_font_size_override("font_size", t.call("legende"))
	meteo_ligne.add_theme_font_size_override("font_size", t.call("meteo"))
	events.add_theme_color_override("font_color", S.TEXT)
	if is_instance_valid(_legende): _legende.custom_minimum_size.x = roundi(LEGENDE_LARGEUR * echelle)
	_ecussons_cle = ""
	_poser_ecussons(_live().get("teams", []))

func update_frame(value: Dictionary) -> void:
	model = value
	if not is_node_ready(): return
	var live := _live()
	var teams: Array = live.get("teams", [{}, {}])
	if teams.size() >= 2:
		home.text = S.G.club_name(teams[0])
		away.text = S.G.club_name(teams[1])
		_poser_ecussons(teams)
	var scores: Array = live.get("score", [0, 0])
	score.text = "%d — %d" % [int(scores[0]), int(scores[1])]
	clock.text = "%d min" % int(live.get("minute", 0))
	if live.get("finished", false): clock.text = "TERMINÉ"
	elif live.get("atBreak", false): clock.text = "MI-TEMPS"
	play.text = "REPRENDRE" if live.get("paused", false) else "PAUSE"
	meteo_ligne.text = Meteo.bandeau(live)
	meteo_ligne.visible = not meteo_ligne.text.is_empty()
	meteo_ligne.add_theme_color_override("font_color", S.GOLD if live.get("atBreak", false) else S.MUTED)
	meteo_ligne.tooltip_text = Meteo.conseil(live)
	meteo_ligne.mouse_filter = Control.MOUSE_FILTER_PASS if not meteo_ligne.tooltip_text.is_empty() else Control.MOUSE_FILTER_IGNORE
	# Une causerie retenue par un temps fort : la reprise passera par elle.
	play.set_meta("contextual_enabled", not live.get("finished", false) and director._talk().is_empty())
	finish.visible = live.get("finished", false)
	finish.set_meta("contextual_enabled", live.get("finished", false))
	if stage.has_method("set_club_identity"): stage.set_club_identity(model.get("club", {}))
	if regie == null:
		stage.set_live_cadence(app.tick_steps)
		stage.apply_frame(live)
	var lines := PackedStringArray()
	var rows: Array = live.get("events", [])
	for event: Variant in rows.slice(maxi(0, rows.size() - 2)):
		if event is Dictionary: lines.append("%s'  %s" % [str(event.get("min", "")), sigles_affiches(str(event.get("text", "")), live.get("teams", []))])
		else: lines.append(str(event))
	events.text = "\n".join(lines)
	events.get_parent().get_parent().visible = not lines.is_empty()
	if regie != null:
		regie.receive(model, live)
		if live.get("direct") is Dictionary: montrer_reglages_temps_forts(live.direct, regie)
	_update_drawer()
	if is_instance_valid(equipe): equipe.update_frame(model)
	apply_preferences()
	director._refresh_controls()

## Fenêtre « Équipe » (choix de Léo, 18/11/2026 : un seul bouton à la place de Tactique et Banc) :
## plein écran, le match se met en pause à l'ouverture et repart avec « Valider et reprendre ».
## `onglet` : « composition » ou « consignes » ; `poste` : joueur du XV déjà choisi (0 à 14).
func ouvrir_equipe(onglet: String = "composition", poste: int = -1) -> void:
	if not is_instance_valid(equipe) or _live().get("finished", false): return
	if drawer.visible: _fermer_tiroir()
	equipe.update_frame(model)
	equipe.ouvrir(onglet, poste)
	director._refresh_controls()

func equipe_fermee() -> void:
	director._refresh_controls()

## Le journal du moteur nomme les clubs par leur sigle interne (« FDG ») ; l'écran affiche le
## sigle de leur identité (presentation.abbr). Même règle que match-direct.cjs (renommeur).
static func sigles_affiches(texte: String, equipes: Array) -> String:
	for equipe: Variant in equipes:
		if not equipe is Dictionary: continue
		var interne := str(equipe.get("abbr", ""))
		var identite: Variant = equipe.get("presentation")
		var affiche := str(identite.get("abbr", "")) if identite is Dictionary else ""
		if not RegEx.create_from_string("^[A-Z0-9]{2,5}$").search(interne) or affiche.is_empty() or affiche == interne: continue
		var motif := RegEx.create_from_string("\\b" + interne + "\\b")
		if motif != null: texte = motif.sub(texte, affiche, true)
	return texte

func _choisir_cadence(index: int) -> void:
	if _reglages_temps_forts:
		regie.choisir_horloge(["lente", "normale", "rapide", "eclair"][index])
		return
	app.tick_steps = [1, 4, 12][index]
	stage.set_live_cadence(app.tick_steps)

## Appelée par la régie quand le moteur projette les temps forts : l'horloge de l'écran
## intermédiaire remplace la cadence du direct, et le niveau se choisit dans la barre.
func montrer_reglages_temps_forts(direct: Dictionary, source: Node) -> void:
	if not _reglages_temps_forts:
		_reglages_temps_forts = true
		_cadence.clear()
		for text in ["Horloge posée", "Horloge normale", "Horloge rapide", "Horloge éclair"]: _cadence.add_item(text)
		_cadence.select(maxi(0, ["lente", "normale", "rapide", "eclair"].find(source.horloge)))
		_cadence.tooltip_text = "Vitesse de l’horloge entre deux temps forts. Un temps fort se joue toujours à vitesse réelle."
	var niveaux: Array = direct.get("niveaux", [])
	if JSON.stringify(niveaux) != JSON.stringify(_niveaux):
		_niveaux = niveaux.duplicate(true)
		_niveau.clear()
		for item: Dictionary in _niveaux: _niveau.add_item(str(item.get("label", "")))
	for index in _niveaux.size():
		if _niveaux[index].get("id") == source.niveau and _niveau.selected != index: _niveau.select(index)
	_niveau.visible = not _niveaux.is_empty()
	if source.get("between") != null: source.between.montrer_niveau(str(source.niveau))

## Vrai tant qu'un temps fort reste à montrer : la causerie attend la fin de l'action.
func retient_la_causerie(live: Dictionary) -> bool:
	return regie != null and regie.retient(live)

## Vrai quand la régie des temps forts cadence elle-même le match.
func temps_forts_actifs() -> bool:
	return regie != null and _live().get("direct") is Dictionary

func _live() -> Dictionary:
	return model.get("live", {}) if model.get("live") is Dictionary else {}

func confier_fin() -> void:
	app.confirm("Confier la fin du match", "L’adjoint prend en charge la fin de cette rencontre. Confirmer la délégation ?", func(): director.command("delegate"))

## Écussons et filets de couleur des deux clubs dans le bandeau de score.
func _poser_ecussons(teams: Array) -> void:
	var cle := JSON.stringify(teams.map(func(t: Variant): return [S.G.club_name(t), S.G.identity(t).get("color", "")] if t is Dictionary else []))
	if cle == _ecussons_cle or _ecussons[0] == null: return
	_ecussons_cle = cle
	for cote in 2:
		var boite: HBoxContainer = _ecussons[cote]
		for enfant in boite.get_children(): enfant.queue_free()
		if teams.size() <= cote or not teams[cote] is Dictionary: continue
		var filet := ColorRect.new()
		filet.color = Color.from_string(str(S.G.identity(teams[cote]).get("color", "#d8c183")), S.GOLD)
		filet.custom_minimum_size = Vector2(roundi(6 * echelle), roundi(46 * echelle))
		filet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ecusson := S.G.crest(teams[cote], roundi(BANDEAU_TAILLES.ecusson * echelle))
		ecusson.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if cote == 0:
			boite.add_child(ecusson)
			boite.add_child(filet)
		else:
			boite.add_child(filet)
			boite.add_child(ecusson)

func _pause() -> void:
	var live := _live()
	director.command("pause", {"paused":not live.get("paused", false)})

func choisir_camera(mode: String) -> void:
	_choose_camera(mode)

func _choose_camera(mode: String) -> void:
	var preferences: Variant = app.get("user_preferences")
	if preferences == null: stage.set_camera(mode); return
	if not preferences.set_value("camera", mode): app.notice("Réglage non enregistré", preferences.last_error)
	apply_preferences()

func apply_preferences() -> void:
	if not is_instance_valid(stage): return
	var preferences: Variant = app.get("user_preferences")
	if preferences == null: return
	var camera: String = preferences.effective_camera()
	var quality: String = str(preferences.data.quality)
	stage.set_stadium_evening(preferences.data.stadium == "evening")
	stage.set_action_motion(not bool(preferences.data.reduced_motion))
	if camera != _applied_camera:
		_applied_camera = camera
		stage.set_camera(camera)
	if quality != _applied_quality:
		_applied_quality = quality
		stage.set_quality(quality)
	for button: Button in _camera_controls:
		button.set_meta("contextual_enabled", not bool(preferences.data.reduced_motion))
		# Preferences can change without a worker/waiting transition.
		button.disabled = bool(app.waiting) or bool(preferences.data.reduced_motion)
		button.tooltip_text = "Mode calme : caméra tactique fixe." if preferences.data.reduced_motion else "Caméra conservée pour les prochains matchs."

func _toggle_drawer(title: String) -> void:
	# Composition, banc et consignes : la fenêtre Équipe (anciens onglets Tactique et Banc compris).
	if title in ["Équipe", "Banc", "Tactique"]:
		ouvrir_equipe("consignes" if title == "Tactique" else "composition")
		return
	if title == drawer_tab and drawer.visible:
		_fermer_tiroir()
		return
	drawer_tab = title
	drawer.show()
	_drawer_key = ""
	_update_drawer()
	if regie != null: regie.tiroir_ferme()

func _fermer_tiroir() -> void:
	drawer_tab = ""
	drawer.hide()
	if regie != null: regie.tiroir_ferme()

func _update_drawer() -> void:
	_journal_shell.visible = drawer_tab == "Journal"
	drawer_body.get_parent().visible = drawer_tab != "Journal"
	if drawer_tab.is_empty(): return
	var live := _live()
	if drawer_tab == "Journal":
		journal.update_frame(regie.montre(live) if regie != null else live)
		return
	var key := JSON.stringify([drawer_tab, _stats(live), live.get("finished")])
	if key == _drawer_key: return
	_drawer_key = key
	S.clear(drawer_body)
	drawer_body.add_child(S.label(drawer_tab, 23, S.GOLD))
	for stat: Dictionary in _stats(live):
		drawer_body.add_child(S.label(str(stat.get("label", "")), 13))
		drawer_body.add_child(S.label("%s    —    %s" % [str(stat.get("home", "")), str(stat.get("away", ""))], 23, S.GOLD))
	if _stats(live).is_empty(): drawer_body.add_child(S.wrap("Aucune statistique disponible pour cette rencontre.", 14))
	director._refresh_controls()

## Chiffres du tiroir : entre deux temps forts, ceux d'avant la borne du moteur (rien d'un temps fort à venir).
func _stats(live: Dictionary) -> Array:
	if regie != null and regie.etat != regie.JEU and live.get("direct") is Dictionary and live.direct.has("statsRows"): return live.direct.statsRows
	return live.get("statsRows", [])

## Consigne en direct (fenêtre Équipe, onglet Consignes) : sans pause, gardée à l'écran jusqu'à la réponse.
func _envoyer_consigne(axe: String, valeur: String) -> void:
	_envois_consignes[axe] = valeur
	if regie != null: regie.envoyer_consigne(axe, valeur)
	else: app._command(Pilotage.COMMANDE, Pilotage.charge(axe, valeur))
