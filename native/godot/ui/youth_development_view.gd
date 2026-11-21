extends AcceptDialog
const Copy = preload("res://ui/management_copy.gd")
## Objectifs et changements réellement observés dans le club courant.
const G = preload("res://ui/carnet_skin.gd")
const U = preload("res://ui/management_state.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const Champs = preload("res://ui/immersive08/champs_charte.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const Jauges = preload("res://ui/jeune_jauges.gd")
const PAGE_SIZE := 20
const ATTRIBUTES := {"scrum":"Mêlée","lineout":"Touche","tackle":"Plaquage","speed":"Vitesse","pass":"Passe","kick":"Jeu au pied","goal":"But","power":"Puissance","stamina":"Endurance","mental":"Mental","discipline":"Discipline"}
const REASONS := {"enable":"Référence initiale","plan":"Objectif révisé","trainWeek":"Séance","recordDevelopmentMatch":"Match","rollDevelopmentYear":"Bilan annuel","advanceSeason":"Nouvelle saison","promoteYouth":"Passage professionnel","managerMobilityOnSeasonStart":"Changement de club"}
var app: Control
var state: Dictionary
var body: VBoxContainer
var scroll: ScrollContainer
var list: Container
var counter: Label
var previous: Button
var next: Button
var page_label: Label
var focused_player_id := ""
var show_all: Button
var en_page := false
## Sous-page : tuiles chiffres et pastilles d'état de l'en-tête, mises à jour à chaque redessin.
var tuiles := {}
var etat_suivi: HFlowContainer
var champ_recherche: LineEdit
var filtre_etape: OptionButton
var filtre_revue: CheckButton

const TEXTE_REGLES := "Les entraînements et les matchs font progresser les attributs et le niveau pendant la saison. Les plans orientent le travail à venir, sans gain immédiat ; le mentorat partage le même apprentissage. Pour les profils à progression annuelle, ces plans servent uniquement d’objectifs de suivi. Âge, personnalité, blessures, fatigue et temps de jeu influencent les progrès. Le potentiel peut évoluer au bilan de saison et ne garantit jamais le niveau atteint."
const TEXTE_TRAVAIL := "Progression par le travail : le plan répartit les efforts à venir, sans gain supplémentaire."
const TEXTE_ANNUEL := "Progression annuelle : les qualités évoluent au bilan annuel selon l’exposition réelle. La spécialisation n’est pas disponible pour ces profils."

static func entry(owner_app: Control,parent: Container) -> Button:
	var button := G.button("SUIVRE LES JEUNES →",func(): open(owner_app))
	button.name = "OpenYouthDevelopment"; parent.add_child(button); return button

## `en_page` : le contenu est adopté par la sous-page « Suivi des jeunes » de la Formation (habillage de la charte) ;
## sinon c'est l'ancienne fenêtre, qui garde son habillage d'origine.
static func open(owner_app: Control, player_id: String = "", en_page: bool = false) -> AcceptDialog:
	owner_app._clear_dialogs()
	var view: AcceptDialog = load("res://ui/youth_development_view.gd").new()
	view.app = owner_app; view.focused_player_id = player_id; view.en_page = en_page; view._build(); return view

# --- Habillage : charte (page) ou carnet d'origine (fenêtre) ---------------------------------------------------------------

## Texte courant. Les tailles du code d'origine sont des pixels réels à 1920 ; la charte les veut en unités du gabarit.
func _t(text: Variant, size: int = 15, color: Color = G.MUTED) -> Label:
	if not en_page: return G.wrap(text, size, color)
	var ton := Charte.IVOIRE if color == G.INK else Charte.D if color == G.ALERT else Charte.IVOIRE_2
	var etiquette := C.wrap(text, roundi(size / 0.75), ton, false, 500)
	etiquette.add_theme_font_override("font", Charte.TEXTE)
	return etiquette

## Titre de section : capitales droites (Barlow Condensed) en page, titre du carnet sinon.
func _titre(title: String, subtitle: String = "") -> VBoxContainer:
	if not en_page: return G.section(title, subtitle)
	var colonne := C.v(4)
	var titre := C.label(title.to_upper(), 34, Charte.IVOIRE, true, 800)
	titre.add_theme_font_override("font", Charte.TITRE_GRAS)
	colonne.add_child(titre)
	if not subtitle.is_empty(): colonne.add_child(_t(subtitle, 13))
	return colonne

## Action secondaire : pilule à contour fin `FILET` (survol `PANNEAU_3`, focus doré) en page ; bouton du carnet sinon.
func _b(text: String, action: Callable) -> Button:
	if not en_page: return G.button(text, action)
	var bouton := Button.new()
	var phrase := text.substr(0, 1) + text.substr(1).to_lower()
	bouton.text = phrase if "→" in phrase or "←" in phrase else phrase + " →"
	bouton.pressed.connect(action)
	var repos := Charte.style_pilule(Color.TRANSPARENT, Charte.FILET, C.px(16), C.px(6))
	var survol := Charte.style_pilule(Charte.PANNEAU_3, Charte.FILET, C.px(16), C.px(6))
	var focus := Charte.style_pilule(Color.TRANSPARENT, Charte.OR, C.px(16), C.px(6))
	focus.set_border_width_all(2)
	var eteint := Charte.style_pilule(Color.TRANSPARENT, Charte.FILET, C.px(16), C.px(6))
	for etat in ["normal"]: bouton.add_theme_stylebox_override(etat, repos)
	for etat in ["hover", "pressed"]: bouton.add_theme_stylebox_override(etat, survol)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.add_theme_stylebox_override("disabled", eteint)
	for cle in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(cle, Charte.IVOIRE)
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	bouton.add_theme_font_override("font", C.BOLD)
	bouton.add_theme_font_size_override("font_size", maxi(12, C.px(21)))
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bouton.set_meta("style_charte", true)
	bouton.set_meta("immersive_style_applied", true)
	return bouton

## Une fiche de jeune : en page, carte `PANNEAU_2` de rayon 12 dans le panneau de la sous-page, sans bordure.
func _carte(parent: Node) -> VBoxContainer:
	if not en_page: return G.card(parent)
	var carte := PanelContainer.new()
	carte.set_meta("immersive_style_applied", true)
	carte.add_theme_stylebox_override("panel", Charte.style_panneau(Charte.PANNEAU_2, Charte.RAYON_CARTE, C.px(16)))
	parent.add_child(carte)
	var contenu := C.v(7)
	carte.add_child(contenu)
	return contenu

## Champ de recherche, liste déroulante et case à cocher aux jetons de la charte finale (page seulement).
func _habiller(controle: Control) -> void:
	if not en_page: return
	if controle is OptionButton: Champs.liste(controle)
	elif controle is CheckButton: Champs.case(controle)
	elif controle is LineEdit: Champs.champ(controle)
## Nom du jeune : clic = fiche complète, survol (ou focus + I) = mini-fiche. Sans fiche à ouvrir, simple texte (jamais de faux lien).
func _nom(parent: Container, person: Dictionary) -> Control:
	var id := str(person.get("id", ""))
	var professionnel := str(person.get("stage", "")) == "professional"
	var cible := {"kind": "player" if professionnel else "academy", "id": id}
	var texte := str(person.get("name", ""))
	if id.is_empty() or not app.navigation_controller.entity_available(cible):
		var simple := _t(texte, 20, G.INK)
		parent.add_child(simple)
		return simple
	var lien := Button.new()
	lien.name = "YouthName_" + id.validate_node_name()
	lien.text = texte
	lien.flat = true
	lien.focus_mode = Control.FOCUS_ALL
	lien.accessibility_name = "Ouvrir la fiche · " + texte
	C.style_bouton_lien(lien, 27, true)
	lien.set_meta("style_charte", true)
	lien.set_meta("immersive_style_applied", true)
	if not en_page:
		for cle in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: lien.add_theme_color_override(cle, G.INK)
		for etat in ["normal", "hover", "pressed", "focus"]:
			var style := lien.get_theme_stylebox(etat) as StyleBoxFlat
			if style != null: style.border_color = G.INK
	lien.pressed.connect(func():
		if not en_page: app._clear_dialogs()
		app.navigation_controller.open_entity(cible))
	parent.add_child(lien)
	MiniFiche.lier(app, lien, id, "squad" if professionnel else "academy")
	return lien

func _data() -> Dictionary:
	return app.model.get("clubLife",{}).get("youthDevelopment",{})

func _build() -> void:
	name = "YouthDevelopment"; title = "Accompagner les jeunes"; get_ok_button().text = "FERMER"
	app._prepare_dialog(self,360)
	_sync_drafts()
	if not focused_player_id.is_empty():
		state.page = 0; state.query = ""; state.stage = 0; state.review = false
	scroll = ScrollContainer.new(); scroll.name = "YouthDevelopmentScroll"; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.follow_focus = true; add_child(scroll)
	body = G.v(10); G.fill(body,true); scroll.add_child(body)
	var data := _data()
	if _court():
		_entete(data)
	else:
		body.add_child(_titre("Des objectifs, puis des faits", "Académie et jeunes professionnels · club courant"))
		body.add_child(_t(TEXTE_REGLES,14))
		if not str(data.get("reason","")).is_empty(): body.add_child(_t(str(data.reason),13))
	if data.get("canEnable",false):
		var enable := _b("DÉMARRER LE SUIVI DES JEUNES",_enable); enable.name = "YouthDevelopmentEnable"; enable.disabled = app.waiting; body.add_child(enable)
		if _court(): enable.tooltip_text = str(data.get("reason",""))
	show_all = _b("REVENIR À TOUS LES JEUNES",func(): focused_player_id = ""; _redraw())
	show_all.name = "YouthDevelopmentShowAll"; body.add_child(show_all)
	var filters := HFlowContainer.new(); body.add_child(filters)
	var search := LineEdit.new(); search.name = "YouthDevelopmentSearch"; search.placeholder_text = "Nom ou poste…"; search.text = str(state.query); search.custom_minimum_size = Vector2(230,36); filters.add_child(search)
	search.text_changed.connect(func(value: String): focused_player_id = ""; state.query = value; state.page = 0; _redraw())
	var stage := OptionButton.new(); stage.name = "YouthDevelopmentStage"
	for label in ["Tous les jeunes","Académie","Jeunes professionnels"]: stage.add_item(label)
	stage.select(int(state.stage)); filters.add_child(stage)
	stage.item_selected.connect(func(index: int): focused_player_id = ""; state.stage = index; state.page = 0; _redraw())
	var review_filter := CheckButton.new(); review_filter.name = "YouthReviewFilter"; review_filter.text = "PARCOURS À REVOIR"; review_filter.button_pressed = bool(state.get("review",false)); filters.add_child(review_filter)
	review_filter.toggled.connect(func(value: bool): focused_player_id = ""; state.review = value; state.page = 0; _redraw())
	champ_recherche = search; filtre_etape = stage; filtre_revue = review_filter
	for controle: Control in [search, stage, review_filter]: _habiller(controle)
	if not _court():
		counter = _t("",13); counter.name = "YouthDevelopmentCount"; body.add_child(counter)
	if _court():
		var grille := GridContainer.new(); grille.columns = 3
		grille.add_theme_constant_override("h_separation", C.px(16)); grille.add_theme_constant_override("v_separation", C.px(16))
		list = grille
	else: list = G.v(8)
	list.name = "YouthDevelopmentRows"; body.add_child(list)
	var paging := G.h(8); body.add_child(paging)
	previous = _b("← PRÉCÉDENT",func(): state.page -= 1; _redraw()); previous.name = "YouthDevelopmentPrevious"; paging.add_child(previous)
	page_label = G.label("",12); paging.add_child(page_label)
	next = _b("SUIVANT →",func(): state.page += 1; _redraw()); next.name = "YouthDevelopmentNext"; paging.add_child(next)
	confirmed.connect(queue_free); canceled.connect(queue_free); app.add_child(self)
	app.bridge.model_changed.connect(func(_model: Dictionary):
		if not app.bridge.last_response_ok: return
		if app.last_command in ["new_career","import","recover_profile","restore_checkpoint"]: queue_free()
		else: _redraw())
	app.get_window().size_changed.connect(_fit)
	_redraw(); _fit()
	get_tree().process_frame.connect(_initial_focus.bind(search),CONNECT_ONE_SHOT | CONNECT_DEFERRED)

func _initial_focus(search: LineEdit) -> void:
	if not is_visible(): return
	search.grab_focus()
	scroll.scroll_vertical = 0

func _fit() -> void:
	var host: Vector2i = app.get_window().size
	var width := mini(1060,host.x-48)
	body.custom_minimum_size.x = width-48; scroll.custom_minimum_size.y = mini(600,host.y-160)
	Dialogs.show_centered(self,Vector2i(width,mini(780,host.y-80)))

# Only UI memory: U.sync discards it on new career/import, including equal IDs.
# A week/season/club change also makes an unconfirmed choice obsolete.
func _sync_drafts() -> void:
	if not app.management_ui.get("youth_development") is Dictionary:
		app.management_ui.youth_development = {"page":0,"query":"","stage":0,"review":false}
	state = app.management_ui.youth_development
	var context: Dictionary = _data().get("context",{}).duplicate(true)
	context.career = app.management_ui.get("career","")
	if state.get("draft_context",{}) != context:
		var previous: Dictionary = state.get("drafts",{})
		state.draft_notice = "Les choix locaux ont été réinitialisés : la semaine, la saison ou le club a changé. Relis le contexte avant de confirmer." if not previous.is_empty() else ""
		state.drafts = {}
		state.draft_context = context
	if not state.get("drafts") is Dictionary: state.drafts = {}

func _remember_draft(player_id: String, plan: String, focus: Variant) -> void:
	_sync_drafts()
	state.drafts[player_id] = {"plan":plan,"focus":focus}

func _redraw() -> void:
	_sync_drafts()
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	var query := U.fold(str(state.query)).strip_edges()
	var source: Array = _data().get("players",[])
	show_all.visible = not focused_player_id.is_empty()
	if not focused_player_id.is_empty(): source = source.filter(func(p: Dictionary): return str(p.id) == focused_player_id)
	var people := source.filter(func(p: Dictionary): return (query.is_empty() or U.fold(str(p.name)+" "+str(p.pos)).contains(query)) and (int(state.stage)==0 or str(p.stage)==["","academy","professional"][int(state.stage)]))
	if state.get("review",false): people = people.filter(func(p: Dictionary): return str(p.get("review",{}).get("status","")) in ["review","context"])
	state.page = clampi(int(state.page),0,maxi(0,ceili(float(people.size())/PAGE_SIZE)-1))
	var start: int = int(state.page)*PAGE_SIZE
	for person: Dictionary in people.slice(start,start+PAGE_SIZE):
		_person(person)
	if people.is_empty(): list.add_child(_t("Aucun jeune" if _court() else "Aucun jeune dans cette sélection.",14))
	if _court():
		_maj_entete(people)
	else:
		counter.text = "%d jeunes · %s" % [people.size(),"suivi actif" if _data().get("enabled",false) else "suivi à démarrer"]
		if not str(state.get("draft_notice","")).is_empty(): counter.text += "\n"+str(state.draft_notice)
		if _data().get("locked",false): counter.text += "\nObjectifs verrouillés : révise-les avant la séance, hors match et pendant la saison régulière."
	previous.disabled = start==0; next.disabled = start+PAGE_SIZE>=people.size()
	page_label.text = "%d / %d" % [int(state.page)+1,maxi(1,ceili(float(people.size())/PAGE_SIZE))]

func _person(person: Dictionary) -> void:
	if _court():
		_tuile_jeune(person); return
	var card := _carte(list); card.name = "YouthDevelopmentCard"; card.set_meta("player_id",str(person.id))
	var row := G.h(10); card.add_child(row)
	var portrait := G.portrait(0,64,person)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(portrait)
	var info := G.v(4); G.fill(info); row.add_child(info)
	var identite := G.h(8); info.add_child(identite)
	_nom(identite,person)
	var suite := _t("· %s · %s ans" % [str(person.pos),G.n(person.age)],20,G.INK)
	suite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identite.add_child(suite)
	var annual: bool = str(person.get("model",""))=="annual-v11"
	info.add_child(_t("Progression annuelle : les qualités évoluent au bilan annuel selon l’exposition réelle. La spécialisation n’est pas disponible pour ce profil." if annual else "Progression par le travail : le plan répartit les efforts à venir, sans gain supplémentaire.",13))
	info.add_child(_t("Niveau général %s · potentiel estimé au poste %s · condition %s %% · fatigue %s / 100 · blessure %s semaine(s)" % [G.rating_text(person,true),G.potential_text(person),G.n(person.get("condition",0)),G.n(person.get("fatigue",0)),G.n(person.get("injury",0))],13))
	var current: Dictionary = person.get("current",{})
	var minutes := "Minutes de carrière : %s" % G.n(person.get("careerMinutes",current.get("careerMinutes",0)))
	if not annual: minutes += " · progression générale %s · progression ciblée %s" % [_decimal(current.get("generalXP",0)),_decimal(current.get("focusedXP",0))]
	info.add_child(_t(minutes,12))
	var baseline: Variant = person.get("baseline")
	var deltas: Variant = person.get("deltas")
	if not baseline is Dictionary or not deltas is Dictionary:
		info.add_child(_t("Pas encore de référence suivie : aucun gain passé n’est attribué à cet objectif.",13))
	else:
		info.add_child(_t("Depuis %s · semaine %s : niveau %s · minutes %s" % [G.season_label(baseline.get("season","—")),G.n(baseline.get("week","—")),_signed(deltas.get("rating",0)),_signed(deltas.get("minutes",0))],13))
		var changes: Array[String] = []
		for key in ATTRIBUTES:
			var delta: float = float(deltas.get("attributes",{}).get(key,0))
			if not is_zero_approx(delta): changes.append(str(ATTRIBUTES[key])+" "+_signed(delta))
		info.add_child(_t(" · ".join(changes) if not changes.is_empty() else "Aucun changement de qualité observé depuis cette référence.",12))
	_review(info,person)
	for observation: Dictionary in person.get("observations",[]):
		info.add_child(_t("%s · semaine %s · %s · niveau %s · minutes %s" % [G.season_label(observation.get("season","—")),G.n(observation.get("week","—")),REASONS.get(str(observation.get("reason","")),"Observation"),_signed(observation.get("ratingDelta",0)),_signed(observation.get("minutesDelta",0))],12))
	for step: Dictionary in person.get("nextSteps",[]): info.add_child(_t(("✓ " if step.get("done",false) else "À préparer · ")+str(step.get("label",""))+" · "+Copy.notice("youth", step.get("detail","")),12))
	if not str(person.get("planReason","")).is_empty(): info.add_child(_t(str(person.planReason),13,G.ALERT))
	_objectif(card,person,annual)

## Objectif : liste des plans, qualité ciblée, confirmation et réorientation conseillée (communs aux trois dispositions).
func _objectif(card: Container, person: Dictionary, annual: bool) -> void:
	var draft: Dictionary = state.drafts.get(str(person.id),{})
	var options := HFlowContainer.new(); card.add_child(options)
	var plan := OptionButton.new(); plan.name = "YouthPlan"; plan.set_meta("player_id",str(person.id)); options.add_child(plan)
	var available: Array = person.get("availablePlans",[])
	for entry: Dictionary in _data().get("plans",[]):
		if str(entry.key) not in available: continue
		plan.add_item(str(entry.label)); plan.set_item_metadata(plan.item_count-1,str(entry.key)); plan.set_item_tooltip(plan.item_count-1,"Objectif de suivi uniquement : aucune modification de la progression annuelle ou du temps de jeu." if annual else str(entry.get("description","")))
		if entry.key==draft.get("plan",person.get("plan")): plan.select(plan.item_count-1)
	var focus := OptionButton.new(); focus.name = "YouthFocus"; options.add_child(focus)
	var selected_focus: Variant = draft.get("focus",person.get("focus"))
	if selected_focus == null: selected_focus = person.get("defaultFocus")
	for entry: Dictionary in person.get("focusOptions",[]):
		focus.add_item(str(entry.label)); focus.set_item_metadata(focus.item_count-1,str(entry.key))
		if entry.key==selected_focus: focus.select(focus.item_count-1)
	_habiller(plan); _habiller(focus)
	var description := _t("",12)
	if _court() and not str(person.get("planReason","")).is_empty():
		var ligne := C.h(8); card.add_child(ligne)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ligne.add_child(description)
		var raison := _info(str(person.planReason)); raison.name = "YouthPlanReason"
		ligne.add_child(raison)
	else: card.add_child(description)
	var update_focus := func():
		var chosen: String = str(plan.get_item_metadata(plan.selected)) if plan.item_count>0 else ""
		focus.visible = chosen in ["specialist","integration"] and focus.item_count>0
		for entry: Dictionary in _data().get("plans",[]):
			if entry.key==chosen:
				var sens := "Objectif de suivi uniquement : aucune modification de la courbe annuelle ou du temps de jeu." if annual else str(entry.get("description",""))
				var repartition := "%d %% générale / %d %% ciblée" % [roundi(float(entry.get("generalShare",0))*100),roundi(float(entry.get("targetShare",0))*100)]
				if _court():
					# Sans phrase : la répartition chiffrée reste écrite, le sens du plan passe en infobulle de la liste.
					plan.tooltip_text = sens
					description.text = "" if annual else "Répartition · " + repartition
					description.visible = not annual
				else:
					description.text = sens
					if not annual: description.text += " · répartition du budget : " + repartition
	var remember := func():
		if plan.item_count==0: return
		var key := str(plan.get_item_metadata(plan.selected))
		var selected: Variant = str(focus.get_item_metadata(focus.selected)) if key in ["specialist","integration"] and focus.item_count>0 else null
		_remember_draft(str(person.id),key,selected)
	plan.item_selected.connect(func(_index: int): update_focus.call(); remember.call())
	focus.item_selected.connect(func(_index: int): remember.call())
	update_focus.call()
	var save := _b("CONFIRMER CET OBJECTIF",func():
		var key := str(plan.get_item_metadata(plan.selected))
		var target: Variant = str(focus.get_item_metadata(focus.selected)) if key in ["specialist","integration"] and focus.item_count>0 else null
		_confirm_plan(person,key,target))
	save.name = "YouthPlanSave"; save.set_meta("player_id",str(person.id)); save.disabled = app.waiting or not person.get("canPlan",false) or plan.item_count==0; options.add_child(save)
	plan.disabled = save.disabled; focus.disabled = save.disabled
	var suggested: Variant = person.get("review",{}).get("recommendation",{}).get("suggestedPlan")
	if suggested != null and str(suggested) in available and str(suggested) != str(person.get("plan","")):
		var prepare := _b("PRÉPARER LA RÉORIENTATION CONSEILLÉE",func():
			for i in plan.item_count:
				if str(plan.get_item_metadata(i))==str(suggested): plan.select(i); update_focus.call(); remember.call(); save.grab_focus())
		prepare.name = "YouthReviewPrepare"; prepare.disabled = save.disabled; card.add_child(prepare)
		if _court(): prepare.tooltip_text = "Préparer ne modifie rien : relis la répartition, puis confirme l’objectif choisi."
		else: card.add_child(_t("Préparer ne modifie rien : relis la répartition, puis confirme l’objectif choisi.",12))

## `boutons` reçoit les actions (examiner, contrat, prêt) et `tete` l'état du suivi en icône + libellé (dispositions A/B).
func _review(parent: Container,person: Dictionary,boutons: Container = null,tete: Container = null) -> void:
	var review: Dictionary = person.get("review",{})
	if review.is_empty(): return
	if boutons == null: boutons = parent
	if tete != null:
		var statut := str(review.get("status",""))
		var etat := Jauges.pastille(str(review.get("label","Bilan intermédiaire")),Jauges.couleur_etat(statut),str(Jauges.ICONES_ETAT.get(statut,"info")),17)
		etat.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		etat.name = "YouthReviewState"
		etat.tooltip_text = str(review.get("basis","")); etat.mouse_filter = Control.MOUSE_FILTER_STOP
		(etat.get_child(0).get_child(1) as Label).name = "YouthReviewLabel"
		tete.add_child(etat)
	else:
		var label := _t(str(review.get("label","Bilan intermédiaire")),16,G.INK); label.name = "YouthReviewLabel"; parent.add_child(label)
	var objective: Variant = review.get("objective")
	if objective is Dictionary:
		var line := "Repère historique · "+str(objective.get("label","Objectif"))
		if objective.get("value") != null and objective.get("target") != null: line += " · %s / %s %s depuis la référence" % [_decimal(objective.value),_decimal(objective.target),str(objective.get("unit",""))]
		if objective.get("achieved",false): line += " · repère atteint"
		parent.add_child(_t(line.replace("Repère historique · ","Repère · ").replace(" depuis la référence","") if _court() else line,13))
	if not _court(): parent.add_child(_t(str(review.get("basis","")),12))
	var recent: Dictionary = review.get("recent",{})
	var recent_line := _t("",13)
	recent_line.name = "YouthRecentReview"
	if recent.get("available",false):
		recent_line.text = ("Période récente · %s semaine %s → semaine %s · %s semaines · %s minutes · niveau %s" if _court() else "Période récente observée · %s semaine %s → semaine %s · %s semaines · %s minutes · niveau %s. Fenêtre visée : quatre semaines, bornes réelles conservées.") % [G.season_label(recent.from.season),G.n(recent.from.week),G.n(recent.to.week),G.n(recent.weeks),_signed(recent.minutesDelta),_signed(recent.ratingDelta)]
	else:
		var reasons := {"untracked":"Démarrer le suivi.","insufficient":"Attendre deux mesures comparables de cette saison et de ce stade.","club":"Référence provenant d’un autre club.","counter":"Continuité du compteur à vérifier.","context":"Continuité du parcours à vérifier."}
		var raison := str(reasons.get(str(recent.get("reason","insufficient")),"Observations comparables insuffisantes."))
		recent_line.text = "Bilan récent indisponible" if _court() else "Bilan récent indisponible · "+raison
		if _court(): recent_line.tooltip_text = raison; recent_line.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(recent_line)
	if recent.get("available",false):
		var changes: Array[String] = []
		for key in ATTRIBUTES:
			var amount: float = float(recent.get("attributeDeltas",{}).get(key,0))
			if not is_zero_approx(amount): changes.append(str(ATTRIBUTES[key])+" "+_signed(amount))
		parent.add_child(_t("Qualités sur cette période · "+(" · ".join(changes) if not changes.is_empty() else "aucun changement observé"),12))

	var short: Variant = review.get("shortTermObjective")
	if short is Dictionary:
		var line := "Décision %s semaine %s · %s · " % [G.season_label(short.from.season),G.n(short.from.week),str(short.label)]
		line += "réexamen au bilan annuel %s" % G.season_label(short.due.season) if short.due.week == null else "réexamen %s semaine %s" % [G.season_label(short.due.season),G.n(short.due.week)]
		if short.get("value") != null and short.get("target") != null: line += " · %s / %s %s depuis cette décision" % [_decimal(short.value),_decimal(short.target),str(short.unit)]
		elif short.get("coverage")=="unavailable": line += " · mesure indisponible" if _court() else " · mesure depuis cette décision indisponible : son observation n’est plus conservée ou son contexte a changé"
		if short.get("expired",false): line += " · échéance de réexamen atteinte"
		if not _court(): line += ". Repère consultatif, sans gain ajouté ni effet causal attribué au plan."
		var dated := _t(line,13)
		dated.name = "YouthShortTermObjective"
		if _court():
			dated.tooltip_text = "Repère consultatif, sans gain ajouté ni effet causal attribué au plan." + (" La mesure depuis cette décision n’est plus conservée ou son contexte a changé." if short.get("coverage")=="unavailable" else "")
			dated.mouse_filter = Control.MOUSE_FILTER_STOP
		parent.add_child(dated)

	var advice: Dictionary = review.get("recommendation",{})
	if _court():
		var conseil := Jauges.pastille(str(advice.get("label","")),Charte.IVOIRE,"target",16,advice.get("destination") != null)
		conseil.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		conseil.tooltip_text = str(advice.get("detail","")); conseil.mouse_filter = Control.MOUSE_FILTER_STOP
		(conseil.get_child(0).get_child(1) as Label).name = "YouthReviewAdvice"
		parent.add_child(conseil)
	else:
		var detail := _t(str(advice.get("label",""))+" · "+str(advice.get("detail","")),13); detail.name = "YouthReviewAdvice"; parent.add_child(detail)
	var destination: Variant = advice.get("destination")
	if destination != null:
		var navigate := _b("EXAMINER LE PARCOURS →" if str(destination)=="Centre" else "EXAMINER L’EFFECTIF →",func(): app._clear_dialogs(); app.selected_player = str(person.id); app._navigate(str(destination)))
		navigate.name = "YouthReviewNavigate"; boutons.add_child(navigate)
		if _court():
			var conseil := parent.find_child("YouthReviewAdvice", true, false)
			if conseil != null: _cliquable(conseil.get_parent().get_parent() as Control, func(): navigate.pressed.emit())
	if str(advice.get("key","")) == "promotion":
		var promote := _b("EXAMINER LE PREMIER CONTRAT DE CE JOUEUR →",func():
			app._clear_dialogs()
			app.selected_player = str(person.id)
			app._navigate("Formation")
			preload("res://ui/development_view.gd").open_player(app,str(person.id)))
		promote.name = "YouthReviewPromotion"
		boutons.add_child(promote)
	elif str(advice.get("key","")) == "loan":
		var loan := _b("EXAMINER LE PRÊT DE CE JOUEUR →",func():
			app._clear_dialogs()
			app.selected_player = str(person.id)
			preload("res://ui/immersive08/formation_pages.gd").ouvrir(app,"pret",{"player_id":str(person.id)}))
		loan.name = "YouthReviewLoan"
		boutons.add_child(loan)


## Sous-page de la Formation (grille de tuiles, choix de Léo du 21/11/2026) : plus de phrase d'explication à l'écran ;
## compteurs en tuiles, états en pastilles, explications derrière un « i ». La fenêtre d'origine garde son texte.
func _court() -> bool:
	return en_page

## Tout ce qui ressemble à une tuile, une jauge, une pastille ou un chiffre ouvre quelque chose (règle de Léo,
## 21/11/2026) : clic gauche (ou Entrée sur le focus) = `action`, curseur main ; `survol` éclaircit un panneau au survol.
func _cliquable(controle: Control, action: Callable, survol: bool = false) -> void:
	if controle == null: return
	controle.mouse_filter = Control.MOUSE_FILTER_STOP
	controle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	controle.set_meta("youth_clic", true)
	controle.gui_input.connect(func(event: InputEvent):
		var souris := event as InputEventMouseButton
		if souris != null and souris.button_index == MOUSE_BUTTON_LEFT and not souris.pressed:
			controle.accept_event(); action.call()
		elif event.is_action_pressed("ui_accept") and controle.has_focus():
			controle.accept_event(); action.call())
	if survol and controle is PanelContainer:
		var repos := controle.get_theme_stylebox("panel") as StyleBoxFlat
		if repos == null: return
		var clair := repos.duplicate() as StyleBoxFlat
		clair.bg_color = Charte.PANNEAU_3
		controle.mouse_entered.connect(func(): controle.add_theme_stylebox_override("panel", clair))
		controle.mouse_exited.connect(func(): controle.add_theme_stylebox_override("panel", repos))

## Fiche complète du jeune, sur l'onglet voulu (0 vue d'ensemble / disponibilité, 2 performances, 4 développement).
func _ouvrir_fiche(person: Dictionary, onglet: int = 0) -> void:
	var professionnel := str(person.get("stage", "")) == "professional"
	var cible := {"kind": "player" if professionnel else "academy", "id": str(person.get("id", ""))}
	if not app.navigation_controller.entity_available(cible): return
	app.management_ui.immersive_player_tab = onglet if professionnel or onglet in [0, 4] else 0
	app.navigation_controller.open_entity(cible)

## Compteurs du haut = filtres de la liste (« Jeunes affichés » remet tout à zéro).
func _filtrer(etape: int, revue: bool) -> void:
	focused_player_id = ""
	state.query = ""; state.stage = etape; state.review = revue; state.page = 0
	if champ_recherche != null: champ_recherche.text = ""
	if filtre_etape != null: filtre_etape.select(etape)
	if filtre_revue != null: filtre_revue.set_pressed_no_signal(revue)
	_redraw()

## « i » : explication en infobulle, au survol.
func _info(texte: String) -> Control:
	var icone := C.icon("info",24,Charte.IVOIRE_2)
	icone.name = "YouthDevelopmentInfo"
	icone.mouse_filter = Control.MOUSE_FILTER_STOP
	icone.mouse_default_cursor_shape = Control.CURSOR_HELP
	icone.tooltip_text = texte
	icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icone

func _tuile(nom: String, legende: String) -> Label:
	var cadre := PanelContainer.new()
	cadre.name = nom
	cadre.add_theme_stylebox_override("panel",Charte.style_panneau(Charte.PANNEAU_2,Charte.RAYON_CARTE,C.px(14)))
	cadre.set_meta("style_charte",true); cadre.set_meta("immersive_style_applied",true)
	cadre.custom_minimum_size.x = C.px(170)
	var colonne := C.v(0); cadre.add_child(colonne)
	var chiffre := Jauges.chiffre("0",44,Charte.IVOIRE); colonne.add_child(chiffre)
	colonne.add_child(Jauges.legende(legende))
	tuiles[nom] = chiffre
	return chiffre

func _entete(data: Dictionary) -> void:
	var colonne := _titre("Des objectifs, puis des faits", "Académie et jeunes professionnels · club courant")
	body.add_child(colonne)
	var titre := colonne.get_child(0) as Control
	colonne.remove_child(titre)
	var ligne := C.h(12); ligne.add_child(titre); colonne.add_child(ligne); colonne.move_child(ligne, 0)
	ligne.add_child(_info(TEXTE_REGLES+"\n\n"+TEXTE_TRAVAIL+"\n"+TEXTE_ANNUEL))
	(colonne.get_child(1) as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
	var bandeau := C.h(14); body.add_child(bandeau)
	counter = _tuile("YouthTileCount","Jeunes affichés"); counter.name = "YouthDevelopmentCount"
	var filtres := {"YouthTileCount": [0, false], "YouthTileAcademy": [1, false], "YouthTilePro": [2, false], "YouthTileReview": [0, true]}
	bandeau.add_child(counter.get_parent().get_parent())
	for cle in [["YouthTileAcademy","Académie"],["YouthTilePro","Jeunes pros"],["YouthTileReview","Parcours à revoir"]]:
		bandeau.add_child(_tuile(cle[0],cle[1]).get_parent().get_parent())
	for nom: String in filtres:
		var reglage: Array = filtres[nom]
		_cliquable(bandeau.find_child(nom, false, false) as Control, func(): _filtrer(int(reglage[0]), bool(reglage[1])), true)
	etat_suivi = _flux(); etat_suivi.size_flags_horizontal = Control.SIZE_EXPAND_FILL; etat_suivi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bandeau.add_child(etat_suivi)

func _maj_entete(people: Array) -> void:
	var tous: Array = _data().get("players",[])
	counter.text = G.n(people.size())
	(tuiles.YouthTileAcademy as Label).text = G.n(tous.filter(func(p: Dictionary): return str(p.get("stage",""))=="academy").size())
	(tuiles.YouthTilePro as Label).text = G.n(tous.filter(func(p: Dictionary): return str(p.get("stage",""))=="professional").size())
	var a_revoir := tous.filter(func(p: Dictionary): return str(p.get("review",{}).get("status","")) in ["review","context"]).size()
	(tuiles.YouthTileReview as Label).text = G.n(a_revoir)
	(tuiles.YouthTileReview as Label).add_theme_color_override("font_color",Jauges.ORANGE if a_revoir > 0 else Charte.IVOIRE)
	for enfant in etat_suivi.get_children(): etat_suivi.remove_child(enfant); enfant.queue_free()
	var actif: bool = _data().get("enabled",false)
	var demarrable: bool = not actif and _data().get("canEnable",false) and not app.waiting
	var suivi := Jauges.pastille("Suivi actif" if actif else "Suivi à démarrer",Jauges.VERT if actif else Jauges.BLEU,"check" if actif else "clock",17,demarrable)
	suivi.name = "YouthTrackingState"
	etat_suivi.add_child(suivi)
	if demarrable: _cliquable(suivi, _enable)
	if _data().get("locked",false):
		var verrou := Jauges.pastille("Objectifs verrouillés",Jauges.ORANGE,"warning",17,false)
		verrou.tooltip_text = "Révise-les avant la séance, hors match et pendant la saison régulière."; verrou.mouse_filter = Control.MOUSE_FILTER_STOP
		etat_suivi.add_child(verrou)
	if not str(state.get("draft_notice","")).is_empty():
		var remis := Jauges.pastille("Choix réinitialisés",Jauges.ORANGE,"info",17,false)
		remis.tooltip_text = str(state.draft_notice); remis.mouse_filter = Control.MOUSE_FILTER_STOP
		etat_suivi.add_child(remis)

# --- Sous-page : tuiles des jeunes ------------------------------------------------------------------------------------

## Mêmes faits que la disposition d'origine, sans la phrase de modèle (écrite une fois en tête d'écran).
func _faits(parent: Container, person: Dictionary) -> void:
	var baseline: Variant = person.get("baseline")
	var deltas: Variant = person.get("deltas")
	if not baseline is Dictionary or not deltas is Dictionary:
		var sans := Jauges.pastille("Sans référence",Charte.IVOIRE_2,"info",16,false)
		sans.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		sans.tooltip_text = "Pas encore de référence suivie : aucun gain passé n’est attribué à cet objectif."; sans.mouse_filter = Control.MOUSE_FILTER_STOP
		parent.add_child(sans)
		return
	parent.add_child(_t("Depuis %s · semaine %s : niveau %s · minutes %s" % [G.season_label(baseline.get("season","—")),G.n(baseline.get("week","—")),_signed(deltas.get("rating",0)),_signed(deltas.get("minutes",0))],13))
	var changes: Array[String] = []
	for key in ATTRIBUTES:
		var delta: float = float(deltas.get("attributes",{}).get(key,0))
		if not is_zero_approx(delta): changes.append(str(ATTRIBUTES[key])+" "+_signed(delta))
	parent.add_child(_t(" · ".join(changes) if not changes.is_empty() else "Aucun changement de qualité observé depuis cette référence.",12))

func _suites(parent: Container, person: Dictionary) -> void:
	for observation: Dictionary in person.get("observations",[]):
		parent.add_child(_t("%s · semaine %s · %s · niveau %s · minutes %s" % [G.season_label(observation.get("season","—")),G.n(observation.get("week","—")),REASONS.get(str(observation.get("reason","")),"Observation"),_signed(observation.get("ratingDelta",0)),_signed(observation.get("minutesDelta",0))],12))
	for step: Dictionary in person.get("nextSteps",[]):
		var etape := _t(("✓ " if step.get("done",false) else "À préparer · ")+str(step.get("label","")),12)
		etape.tooltip_text = Copy.notice("youth", step.get("detail","")); etape.mouse_filter = Control.MOUSE_FILTER_STOP
		parent.add_child(etape)
	if not _court() and not str(person.get("planReason","")).is_empty(): parent.add_child(_t(str(person.planReason),13,G.ALERT))

func _modele(person: Dictionary) -> PanelContainer:
	var annual: bool = str(person.get("model",""))=="annual-v11"
	var chip := Jauges.pastille("Progression annuelle" if annual else "Progression par le travail",Charte.IVOIRE_2,"calendar" if annual else "train",16)
	chip.tooltip_text = TEXTE_ANNUEL if annual else TEXTE_TRAVAIL
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	return chip

func _blessure(person: Dictionary) -> String:
	var semaines := int(person.get("injury",0))
	return "aucune" if semaines <= 0 else "%s sem." % G.n(semaines)

func _portrait(person: Dictionary, taille: int) -> Control:
	var portrait := G.portrait(0,C.px(taille),person)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return portrait

func _identite(parent: Container, person: Dictionary) -> void:
	_nom(parent,person)
	parent.add_child(_t("%s · %s ans" % [str(person.pos),G.n(person.age)],16))

func _flux(ecart: int = 8) -> HFlowContainer:
	var flux := HFlowContainer.new()
	flux.add_theme_constant_override("h_separation",C.px(ecart))
	flux.add_theme_constant_override("v_separation",C.px(6))
	return flux

## Tuile (grille de trois) : portrait, niveau en gros chiffre au barème, potentiel dessous, niveau posé sur la fourchette
## de potentiel (40-100), progression, condition et fatigue en jauges ; état du suivi en icône ; détail des faits replié.
func _tuile_jeune(person: Dictionary) -> void:
	var card := _carte(list); card.name = "YouthDevelopmentCard"; card.set_meta("player_id",str(person.id))
	card.add_theme_constant_override("separation",C.px(10))
	var cadre := card.get_parent() as Control
	cadre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cadre.name = "YouthTile_" + str(person.id).validate_node_name()
	_cliquable(cadre, func(): _ouvrir_fiche(person, 0), true)
	MiniFiche.lier(app, cadre, str(person.id), "squad" if str(person.get("stage","")) == "professional" else "academy")
	var annual: bool = str(person.get("model",""))=="annual-v11"
	var current: Dictionary = person.get("current",{})
	var tete := C.h(16); card.add_child(tete)
	tete.add_child(_portrait(person,104))
	var identite := C.v(4); identite.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tete.add_child(identite)
	_identite(identite,person)
	var etat := C.h(6); identite.add_child(etat)
	var chiffres := C.v(0); tete.add_child(chiffres)
	var niveau: Variant = G.knowledge_sort_value(person,"rating",true)
	var gros := Jauges.chiffre(G.rating_text(person,true),64,Charte.couleur_attribut(niveau) if niveau != null else Charte.IVOIRE_3)
	gros.name = "YouthLevel"; gros.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; gros.tooltip_text = "Niveau général"
	chiffres.add_child(gros)
	var potentiel: Variant = G.knowledge_sort_value(person,"potential")
	var ligne_pot := C.h(6); ligne_pot.alignment = BoxContainer.ALIGNMENT_END; chiffres.add_child(ligne_pot)
	ligne_pot.add_child(Jauges.legende("Potentiel",15))
	var pot := Jauges.chiffre(G.potential_text(person),26,Charte.couleur_attribut(potentiel) if potentiel != null else Charte.IVOIRE_3)
	pot.tooltip_text = G.potential_tooltip(person)
	ligne_pot.add_child(pot)
	chiffres.name = "YouthLevelBlock"
	chiffres.tooltip_text = G.potential_tooltip(person)
	_cliquable(chiffres, func(): _ouvrir_fiche(person, 4))
	var barre_niveau := Jauges.barre_niveau_potentiel(G.knowledge_bounds(person,"rating",true),G.knowledge_bounds(person,"potential"),G.rating_text(person,true),G.potential_text(person))
	card.add_child(barre_niveau)
	_cliquable(barre_niveau, func(): _ouvrir_fiche(person, 4))
	if annual:
		var modele := _modele(person); modele.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; card.add_child(modele)
		_cliquable(modele, func(): _ouvrir_fiche(person, 4))
	else:
		var progression := C.v(3); card.add_child(progression)
		progression.name = "YouthProgressBlock"
		_cliquable(progression, func(): _ouvrir_fiche(person, 4))
		var libelle := C.h(8); progression.add_child(libelle)
		var leg := Jauges.legende("Progression générale"); leg.size_flags_horizontal = Control.SIZE_EXPAND_FILL; libelle.add_child(leg)
		libelle.add_child(Jauges.legende("%s · ciblée %s" % [_pourcent(current.get("generalXP",0)),_pourcent(current.get("focusedXP",0))],16,Charte.IVOIRE_2))
		var barre := Jauges.BarreFine.new(); barre.part = float(current.get("generalXP",0)); barre.couleur = Jauges.BLEU
		barre.custom_minimum_size = Vector2(0,maxi(4,C.px(8))); barre.name = "YouthGeneralProgress"
		progression.add_child(barre)
	var jauges := C.h(18); card.add_child(jauges)
	var condition := float(person.get("condition",0))
	var fatigue := float(person.get("fatigue",0))
	var blesse := int(person.get("injury",0)) > 0
	var jauge_condition := Jauges.mini_jauge("YouthCondition","Condition","%s %%" % G.n(condition),condition/100.0,Jauges.VERT,Charte.IVOIRE,110)
	var jauge_fatigue := Jauges.mini_jauge("YouthFatigue","Fatigue","%s / 100" % G.n(fatigue),fatigue/100.0,Jauges.ORANGE,Charte.IVOIRE,110)
	for jauge: Control in [jauge_condition,jauge_fatigue]:
		jauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		jauges.add_child(jauge)
	jauges.add_child(Jauges.mini_jauge("YouthInjury","Blessure",_blessure(person),-1.0,Jauges.ORANGE,Jauges.ORANGE if blesse else Charte.IVOIRE,100))
	for jauge: Control in jauges.get_children(): _cliquable(jauge, func(): _ouvrir_fiche(person, 0))
	var faits := _flux(); card.add_child(faits)
	var minutes := Jauges.pastille("%s min en carrière" % G.n(person.get("careerMinutes",current.get("careerMinutes",0))),Charte.IVOIRE_2,"clock",16)
	minutes.name = "YouthMinutes"
	faits.add_child(minutes)
	_cliquable(minutes, func(): _ouvrir_fiche(person, 2))
	var detail := C.v(5); detail.name = "YouthTileDetail"
	var actions := _flux(10)
	_faits(detail,person)
	_review(detail,person,actions,etat)
	_suites(detail,person)
	var deplier := Button.new(); deplier.name = "YouthTileToggle"; deplier.flat = true; deplier.focus_mode = Control.FOCUS_ALL
	C.style_bouton_lien(deplier,19); deplier.set_meta("style_charte",true); deplier.set_meta("immersive_style_applied",true)
	deplier.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	detail.visible = str(person.id) == focused_player_id
	var libeller := func(): deplier.text = "Masquer le détail du suivi ▴" if detail.visible else "Détail du suivi ▾"
	libeller.call()
	deplier.pressed.connect(func(): detail.visible = not detail.visible; libeller.call())
	_cliquable(etat.find_child("YouthReviewState", false, false) as Control, func(): deplier.pressed.emit())
	card.add_child(deplier)
	card.add_child(detail)
	if actions.get_child_count() > 0: card.add_child(actions)
	else: actions.queue_free()
	_objectif(card,person,annual)

func _enable() -> void:
	var payload := {"confirmed":true,"context":_data().get("context",{}).duplicate(true)}
	preload("res://ui/immersive08/formation_pages.gd").confirmer(app,"Démarrer le suivi des jeunes","Une référence sera conservée à partir d’aujourd’hui. Le suivi ne produit aucun gain immédiat. Confirmer ?",Callable(app,"_command").bind("youth_development_enable",payload))

func _confirm_plan(person: Dictionary,plan: String,focus: Variant) -> void:
	_remember_draft(str(person.id),plan,focus)
	var payload := {"confirmed":true,"context":_data().get("context",{}).duplicate(true),"playerId":str(person.id),"plan":plan,"focus":focus}
	var detail := "Cet objectif sert uniquement au suivi : il ne change ni la courbe annuelle, ni le temps de jeu." if str(person.get("model",""))=="annual-v11" else "Le plan répartit le travail à venir, sans gain immédiat."
	if str(person.get("model",""))!="annual-v11":
		detail += " Si la qualité ciblée change, la progression ciblée partielle non utilisée est remise à zéro ; les qualités déjà gagnées sont conservées."
	preload("res://ui/immersive08/formation_pages.gd").confirmer(app,"Adapter l’objectif de "+str(person.name),detail+" Confirmer date une nouvelle période de suivi à partir d’aujourd’hui, même si le plan reste identique. Les minutes, la fatigue et les blessures restent prises en compte. Confirmer ?",Callable(app,"_command").bind("youth_development_plan",payload))

static func _pourcent(value: Variant) -> String: return "%d %%" % roundi(float(value)*100)
static func _decimal(value: Variant) -> String: return "%.2f" % float(value)
static func _signed(value: Variant) -> String: return ("+" if float(value)>0 else "")+_decimal(value)
