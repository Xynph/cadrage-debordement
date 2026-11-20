extends RefCounted
## Onglet Staff de l'écran Club (charte finale de la graphiste, validée par Léo le 20/11/2026) : un tableau dense de
## l'encadrement (rôle, nom, âge, niveau, contrat, salaire, actions) dans un panneau arrondi sans bordure, filets entre
## les lignes, liens gris-vert + flèche, boutons en pilule (aucun aplat doré : Continuer reste l'action principale de la
## coque). Nom ou ligne = fiche du membre ; Prolonger / Recruter = sous-page « Contrat du staff » ; Libérer / Retraite =
## confirmation EN PLACE dans la page (main.gd → confirmation_en_place.gd), jamais une fenêtre.
const G = preload("res://ui/carnet_skin.gd")
const U = preload("res://ui/management_state.gd")
const Dialogs = preload("res://ui/decision_views.gd")
const C = preload("res://ui/immersive08/components.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Charte = preload("res://ui/charte.gd")
const PAGE_SIZE := 20
## Colonnes du tableau (unités du gabarit) : libellé, largeur, aligné à droite.
const COLONNES := [["Rôle", 330.0, false], ["Nom", 310.0, false], ["Âge", 64.0, true], ["Niveau", 84.0, true], ["Contrat", 200.0, true], ["€ / sem.", 130.0, true]]
## Ligne de tableau : 35 unités ≈ 26 px à 1920 (densité FM, choix de Léo du 20/11/2026).
const LIGNE := 35.0
const RAYON_LIGNE := Charte.RAYON_PETIT

# --- Éléments de la charte posés dans des conteneurs (composants propres au Staff) ---------------------------------------

## Texte DM Sans (18 unités = 13 px à 1920) ; largeur 0 = prend la place restante.
static func texte(valeur: Variant, taille: int = 18, couleur: Color = Charte.IVOIRE, largeur: float = 0.0, droite: bool = false) -> Label:
	var label := C.label(valeur, taille, couleur, false, 500)
	label.add_theme_font_override("font", Charte.TEXTE)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	if droite: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if largeur > 0.0: label.custom_minimum_size.x = C.px(largeur)
	else: label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

## En-tête de colonne, légende : Barlow Condensed SemiBold en capitales, texte faible (IVOIRE_3).
static func etiquette(valeur: String, largeur: float = 0.0, droite: bool = false, couleur: Color = Charte.IVOIRE_3) -> Label:
	var label := C.label(valeur.to_upper(), 16, couleur, true, 600)
	label.add_theme_font_override("font", Charte.TITRE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if droite: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if largeur > 0.0: label.custom_minimum_size.x = C.px(largeur)
	else: label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

## Surtitre doré (Barlow Condensed SemiBold, capitales) : rôle d'un membre en tête de sa fiche.
static func surtitre(valeur: String) -> Label:
	var label := etiquette(valeur, 0.0, false, Charte.OR)
	return label

## Titre de panneau : Barlow Condensed Bold, capitales, droit.
static func titre(valeur: String, taille: int = 26) -> Label:
	var label := C.label(valeur.to_upper(), taille, Charte.IVOIRE, true, 700)
	label.add_theme_font_override("font", Charte.TITRE_GRAS)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

## Anneau de focus de la charte : doré 2 px, décalé de 2 px.
static func anneau_focus(rayon: int = Charte.RAYON_PILULE) -> StyleBoxFlat:
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Charte.OR
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(rayon)
	focus.set_expand_margin_all(2)
	focus.anti_aliasing = true
	return focus

## Lien : sans fond ni contour, gris-vert (crème pour un nom), souligné au survol, focus doré.
static func lien(valeur: String, action: Callable, id: String, taille: int = 18, couleur: Color = Charte.IVOIRE_2) -> Button:
	var bouton := Button.new()
	bouton.name = id
	bouton.text = valeur
	bouton.flat = true
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	C.style_bouton_lien(bouton, taille)
	for etat in ["hover", "pressed"]:
		var souligne := bouton.get_theme_stylebox(etat) as StyleBoxFlat
		if souligne != null: souligne.border_color = couleur
	bouton.add_theme_stylebox_override("focus", anneau_focus(RAYON_LIGNE))
	bouton.add_theme_font_override("font", Charte.texte_moyen())
	bouton.add_theme_font_size_override("font_size", C.font_px(taille))
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: bouton.add_theme_color_override(etat, couleur)
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	bouton.custom_minimum_size.y = C.px(30)
	bouton.tooltip_text = ""
	bouton.set_meta("style_charte", true)
	bouton.pressed.connect(action)
	return bouton

## Bouton secondaire en pilule : contour FILET et texte crème, ou « plein » (VERT_FRANC, texte crème) pour l'action
## forte d'un panneau. Jamais doré : l'unique aplat doré de l'écran reste Continuer.
static func bouton(parent: Container, valeur: String, action: Callable, id: String, plein: bool = false) -> Button:
	var b := Button.new()
	b.name = id
	b.text = valeur
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", Charte.TITRE)
	b.add_theme_font_size_override("font_size", C.font_px(21))
	var repos := Charte.style_pilule(Charte.VERT_FRANC if plein else Color.TRANSPARENT, Color.TRANSPARENT if plein else Charte.FILET, C.px(20), C.px(5))
	var survol := Charte.style_pilule(Charte.VERT_FRANC.lightened(.08) if plein else Charte.PANNEAU_2, Color.TRANSPARENT if plein else Charte.IVOIRE_3, C.px(20), C.px(5))
	var enfonce := Charte.style_pilule(Charte.SELECTION, Charte.IVOIRE if not plein else Color.TRANSPARENT, C.px(20), C.px(5))
	var eteint := Charte.style_pilule(Color.TRANSPARENT, Charte.FILET, C.px(20), C.px(5))
	b.add_theme_stylebox_override("normal", repos)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", enfonce)
	b.add_theme_stylebox_override("hover_pressed", enfonce)
	b.add_theme_stylebox_override("disabled", eteint)
	b.add_theme_stylebox_override("focus", anneau_focus())
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: b.add_theme_color_override(etat, Charte.IVOIRE)
	b.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	b.custom_minimum_size.y = C.px(40)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = ""
	b.set_meta("style_charte", true)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

## Ancien nom gardé pour les appels existants : action d'un panneau en bouton secondaire plein.
static func bouton_principal(parent: Container, valeur: String, action: Callable, id: String, _largeur: float = 0.0) -> Button:
	return bouton(parent, valeur, action, id, true)

## Filet horizontal (séparation dans un panneau).
static func filet(parent: Container) -> ColorRect:
	var separation := ColorRect.new()
	separation.color = Charte.FILET
	separation.custom_minimum_size.y = maxf(1.0, C.px(1))
	separation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(separation)
	return separation

## Champ de la charte : pilule PANNEAU_3, contour FILET, anneau doré au focus.
static func styler_champ(champ: LineEdit) -> void:
	champ.add_theme_font_override("font", Charte.TEXTE)
	champ.add_theme_font_size_override("font_size", C.font_px(18))
	champ.add_theme_color_override("font_color", Charte.IVOIRE)
	champ.add_theme_color_override("font_placeholder_color", Charte.IVOIRE_3)
	champ.add_theme_color_override("caret_color", Charte.IVOIRE)
	champ.add_theme_color_override("selection_color", Charte.SELECTION)
	champ.add_theme_stylebox_override("normal", Charte.style_pilule(Charte.PANNEAU_3, Charte.FILET, C.px(16), C.px(5)))
	var focus := Charte.style_pilule(Charte.PANNEAU_3, Charte.OR, C.px(16), C.px(5))
	focus.set_border_width_all(2)
	champ.add_theme_stylebox_override("focus", focus)
	champ.custom_minimum_size.y = C.px(38)

## Menu déroulant (exception « menus déroulants » de Léo) : pilule comme un champ, liste en panneau arrondi.
static func styler_liste(liste: OptionButton, largeur: float) -> void:
	Kit.styler_liste(liste)
	var repos := Charte.style_pilule(Charte.PANNEAU_3, Charte.FILET, C.px(16), C.px(5))
	var survol := Charte.style_pilule(Charte.PANNEAU_2, Charte.IVOIRE_3, C.px(16), C.px(5))
	for etat in ["normal", "pressed", "disabled"]: liste.add_theme_stylebox_override(etat, repos)
	liste.add_theme_stylebox_override("hover", survol)
	liste.add_theme_stylebox_override("focus", anneau_focus())
	var menu := liste.get_popup()
	menu.add_theme_stylebox_override("panel", Charte.sans_ombre(Charte.style_panneau(Charte.PANNEAU, Charte.RAYON_CARTE, C.px(8))))
	var choix := Charte.style_panneau(Charte.PANNEAU_2, RAYON_LIGNE, C.px(4))
	menu.add_theme_stylebox_override("hover", choix)
	liste.custom_minimum_size = Vector2(C.px(largeur), C.px(38))
	liste.fit_to_longest_item = false
	liste.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

## Ligne de tableau cliquable : aucun fond au repos (pas de bandes), survol PANNEAU_2 arrondi à 6, focus doré, filet
## de 1 px en pied de ligne.
static func styler_rangee(ligne: Button) -> void:
	var repos := StyleBoxEmpty.new()
	var survol := Charte.style_panneau(Charte.PANNEAU_2, RAYON_LIGNE, 0)
	for etat in ["normal", "disabled"]: ligne.add_theme_stylebox_override(etat, repos)
	for etat in ["hover", "hover_pressed"]: ligne.add_theme_stylebox_override(etat, survol)
	ligne.add_theme_stylebox_override("pressed", Charte.style_panneau(Charte.SELECTION, RAYON_LIGNE, 0))
	ligne.add_theme_stylebox_override("focus", anneau_focus(RAYON_LIGNE))
	ligne.focus_mode = Control.FOCUS_ALL
	ligne.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var pied := ColorRect.new()
	pied.name = "Filet"
	pied.color = Charte.FILET
	pied.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(pied)
	pied.anchor_left = 0.0
	pied.anchor_right = 1.0
	pied.anchor_top = 1.0
	pied.anchor_bottom = 1.0
	pied.offset_top = -maxf(1.0, C.px(1))
	pied.offset_bottom = 0.0

## Rangée horizontale sans fond.
static func rangee(gap: float = 14.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", C.px(gap))
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	return row

## En-tête du tableau (capitales IVOIRE_3, alignées sur leurs valeurs) et filet dessous. `salaire` : colonne € / sem.
static func entete(parent: Container, salaire: bool) -> void:
	var tete := rangee()
	tete.name = "StaffTableHead"
	var marge := MarginContainer.new()
	marge.add_theme_constant_override("margin_left", C.px(10))
	marge.add_theme_constant_override("margin_right", C.px(10))
	parent.add_child(marge)
	marge.add_child(tete)
	for colonne: Array in COLONNES:
		if str(colonne[0]) == "€ / sem." and not salaire: continue
		tete.add_child(etiquette(str(colonne[0]), float(colonne[1]), bool(colonne[2])))
	tete.add_child(etiquette("", 0.0))
	filet(parent)

static func _salaire_visible(app: Control) -> bool:
	return app.model.get("clubLife", {}).get("staffEmployment", {}).get("enabled", false) == true

static func enable(app: Control, parent: Container, data: Dictionary) -> void:
	if not data.get("canEnable", false): return
	var button := bouton_principal(parent, "Activer les carrières du staff", func():
		var payload := {"confirmed":true,"context":data.context.duplicate(true)}
		app.confirm("Activer les carrières du staff", "Les membres du staff auront un contrat et pourront changer de poste ou prendre leur retraite. Confirmer ?", func(): app._command("staff_career_enable", payload)), "EnableStaffCareer", 380.0)
	button.accessibility_name = "Activer les carrières du staff"

static func build(app: Control, parent: Container, data: Dictionary) -> void:
	if not app.management_ui.get("staff") is Dictionary: app.management_ui.staff = {}
	var reading: Dictionary = app.management_ui.staff
	var overview := VBoxContainer.new()
	overview.add_theme_constant_override("separation", C.px(8))
	overview.name = "StaffCareerOverview"
	parent.add_child(overview)
	var outils := rangee(12)
	outils.name = "StaffToolbar"
	overview.add_child(outils)
	outils.add_child(titre("Encadrement"))
	var teams: Array = app.model.get("staff", {}).get("teams", data.get("teams", []))
	var chooser := OptionButton.new()
	chooser.name = "StaffClub"
	if not teams.any(func(t: Dictionary): return int(t.id) == app.selected_staff_club): app.selected_staff_club = int(app.model.club.id)
	for team: Dictionary in teams:
		chooser.add_item(str(team.name)); chooser.set_item_metadata(chooser.item_count - 1, int(team.id))
		if int(team.id) == app.selected_staff_club: chooser.select(chooser.item_count - 1)
	chooser.item_selected.connect(func(index: int):
		app.selected_staff_club = int(chooser.get_item_metadata(index)); app._render())
	styler_liste(chooser, 300)
	outils.add_child(chooser)
	var tabs := OptionButton.new()
	tabs.name = "StaffCareerTab"
	for title in ["Équipe du club", "Candidats disponibles", "Retraites et archives"]: tabs.add_item(title)
	tabs.select(clampi(int(reading.get("tab", 0)), 0, tabs.item_count - 1))
	styler_liste(tabs, 260)
	outils.add_child(tabs)
	var search := LineEdit.new()
	search.name = "StaffSearch"
	search.placeholder_text = "Nom ou rôle…"
	search.text = str(reading.get("search", ""))
	styler_champ(search)
	search.custom_minimum_size.x = C.px(340)
	outils.add_child(search)
	var count := texte("", 17, Charte.IVOIRE_2, 0.0, true)
	count.name = "StaffCount"
	outils.add_child(count)
	# Deuxième ligne : ce que dit le club du staff, puis les accès (mentorat, contrats rémunérés) et l'action principale.
	var acces := rangee(18)
	acces.name = "StaffAccess"
	overview.add_child(acces)
	var notice := texte("Seuls les contrats rémunérés sont imputés au budget du staff." if _salaire_visible(app) else str(data.get("notice", "")), 17, Charte.IVOIRE_2)
	notice.name = "StaffNotice"
	acces.add_child(notice)
	_mentoring(app, acces)
	_employment(app, acces)
	if int(reading.get("tab", 0)) != 1:
		bouton(acces, "Recruter un membre →", func():
			reading.tab = 1; reading.page = 0; reading.search = ""; reading.scroll = 0
			app._render(), "StaffRecruitOpen")
	entete(parent, _salaire_visible(app))
	var scroll := ScrollContainer.new()
	scroll.name = "StaffList"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	scroll.set_deferred("scroll_vertical", int(reading.get("scroll", 0)))
	scroll.get_v_scroll_bar().value_changed.connect(func(value: float): reading.scroll = value)
	var paging := rangee(12)
	paging.name = "StaffPaging"
	parent.add_child(paging)
	var local := reading
	if not local.has("page"): local.page = 0
	var previous := lien("← Page précédente", func(): pass, "StaffPagePrevious", 17)
	var next := lien("Page suivante →", func(): pass, "StaffPageNext", 17)
	var page_label := texte("", 17, Charte.IVOIRE_2, 160.0)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paging.add_child(previous); paging.add_child(page_label); paging.add_child(next)
	var generation := [0]
	var redraw := func():
		for child in list.get_children(): list.remove_child(child); child.queue_free()
		var people: Array = []
		if tabs.selected == 0:
			for team: Dictionary in teams:
				if int(team.id) == app.selected_staff_club: people = team.members
		elif tabs.selected == 1: people = data.get("candidates", [])
		else: people = data.get("retired", [])
		var query := U.fold(search.text).strip_edges()
		var filtered := people.filter(func(p: Dictionary): return query.is_empty() or U.fold(str(p.name) + " " + str(p.get("roleLabel", p.role))).contains(query))
		local.page = clampi(int(local.page), 0, maxi(0, ceili(float(filtered.size()) / PAGE_SIZE) - 1))
		var start: int = int(local.page) * PAGE_SIZE
		# Les premières cartes tout de suite, les autres sur les images suivantes.
		var own: bool = tabs.selected == 0 and app.selected_staff_club == int(app.model.club.id)
		var page_people: Array = filtered.slice(start, start + PAGE_SIZE)
		generation[0] += 1
		for person: Dictionary in page_people.slice(0, FIRST_CARDS): _person(app, list, person, data, own)
		if page_people.size() > FIRST_CARDS: _more_cards(app, list, page_people, data, own, generation, generation[0])
		count.text = "%d / %d membres · %s" % [filtered.size(), people.size(), ["staff en poste", "candidats recrutables", "archives conservées"][tabs.selected]]
		if filtered.is_empty():
			var vide := texte("Aucun profil dans cette sélection.", 18, Charte.IVOIRE_2)
			vide.name = "StaffListEmpty"
			list.add_child(vide)
		previous.disabled = int(local.page) == 0
		next.disabled = start + PAGE_SIZE >= filtered.size()
		page_label.text = "Page %d / %d" % [int(local.page) + 1, maxi(1, ceili(float(filtered.size()) / PAGE_SIZE))]
		paging.visible = filtered.size() > PAGE_SIZE
	previous.pressed.connect(func(): local.page -= 1; redraw.call())
	next.pressed.connect(func(): local.page += 1; redraw.call())
	tabs.item_selected.connect(func(index: int): reading.tab = index; local.page = 0; redraw.call())
	search.text_changed.connect(func(query: String): reading.search = query; local.page = 0; redraw.call())
	redraw.call()
	var note := texte("Âges et contrats de ta carrière ; seuls les contrats rémunérés pèsent sur le budget du club.", 16, Charte.IVOIRE_3)
	note.name = "StaffFootnote"
	parent.add_child(note)

const FIRST_CARDS := 6
const CARDS_PER_FRAME := 7

static func _more_cards(app: Control, list: VBoxContainer, people: Array, data: Dictionary, own: bool, generation: Array, mine: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var next := FIRST_CARDS
	while next < people.size():
		await tree.process_frame
		if not is_instance_valid(list) or not list.is_inside_tree() or generation[0] != mine: return
		for person: Dictionary in people.slice(next, next + CARDS_PER_FRAME): _person(app, list, person, data, own)
		next += CARDS_PER_FRAME
	var scroll := list.get_parent() as ScrollContainer
	var wanted := int(app.management_ui.get("staff", {}).get("scroll", 0))
	if scroll != null and wanted > 0:
		await tree.process_frame
		if is_instance_valid(scroll) and generation[0] == mine: scroll.scroll_vertical = wanted

## Une ligne du tableau : la ligne entière et le nom ouvrent la fiche du membre ; les actions sont des liens texte.
static func _person(app: Control, parent: Container, person: Dictionary, data: Dictionary, own: bool) -> void:
	var staff_id := str(person.get("id", ""))
	var staff_view = load("res://ui/staff_view.gd")
	var ligne := Button.new()
	ligne.name = "StaffRow_" + staff_id.validate_node_name()
	ligne.set_meta("staff_id", person.get("id", ""))
	styler_rangee(ligne)
	ligne.custom_minimum_size.y = C.px(LIGNE)
	ligne.accessibility_name = "Fiche · " + str(person.get("name", ""))
	ligne.pressed.connect(func(): app.navigation_controller.open_entity({"kind":"staff", "id":staff_id}))
	parent.add_child(ligne)
	var marge := MarginContainer.new()
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marge.add_theme_constant_override("margin_left", C.px(10))
	marge.add_theme_constant_override("margin_right", C.px(10))
	ligne.add_child(marge)
	marge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := rangee()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta("staff_id", person.get("id", ""))
	marge.add_child(row)
	# Annuaire (carrières du staff inactives) : la fonction écrite telle que l'annuaire du club la publie.
	var role := str(person.get("role", "Staff")) if data.get("role_publie", false) else str(person.get("roleLabel", data.get("roles", {}).get(person.get("role", ""), person.get("role", "Staff"))))
	if person.get("sourcePlayerId") != null: role += " · ancien joueur"
	if person.get("historical", false): role += " · ancien membre"
	row.add_child(texte(role, 18, Charte.IVOIRE_2, COLONNES[0][1]))
	var nom: Button = staff_view.name_link(app, person, 18)
	nom.custom_minimum_size.x = C.px(COLONNES[1][1])
	row.add_child(nom)
	row.add_child(texte(G.n(person.get("age")) if person.get("age") != null else "—", 18, Charte.IVOIRE_2, COLONNES[2][1], true))
	var niveau := texte(G.n(person.get("level")) if person.get("level") != null else "—", 18, Charte.IVOIRE, COLONNES[3][1], true)
	niveau.add_theme_font_override("font", Kit.texte_gras())
	row.add_child(niveau)
	row.add_child(texte("fin " + G.season_label(person.contractEnd) if person.get("contractEnd") != null else "—", 18, Charte.IVOIRE_2, COLONNES[4][1], true))
	var employment := _employment_person(app, str(person.id))
	if _salaire_visible(app):
		var paie := G.salary(employment.paidSalary) if employment.get("employed", false) else "—"
		row.add_child(texte(paie, 18, Charte.IVOIRE, COLONNES[5][1], true))
	var actions := rangee(4)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(actions)
	if own and not employment.is_empty() and not employment.get("employed", false) and app.model.get("clubLife", {}).get("staffEmployment", {}).get("enabled", false):
		var adopt := lien("Rémunérer →", func():
			var data_finance: Dictionary = app.model.clubLife.staffEmployment
			app.confirm("Rémunérer " + str(person.name), "%s, engagement restant %s €. Les autres dépenses du club continuent. Confirmer l’adoption volontaire ?" % [G.salary(employment.salary),G.n(employment.adoptionCommitment)], func(): app._command("staff_employment_adopt", {"confirmed":true,"context":data_finance.context.duplicate(true),"staffId":str(person.id),"salary":int(employment.salary)})), "StaffEmploymentAdopt", 17)
		adopt.disabled = app.model.clubLife.staffEmployment.get("locked", true)
		actions.add_child(adopt)
	if person.get("canHire", false):
		var hire := lien("Recruter →", func(): _contract(app, person, data, false), "StaffHire", 17)
		hire.set_meta("staff_id", person.id)
		actions.add_child(hire)
	if own and person.get("canRenew", false):
		var renew := lien("Prolonger →", func(): _contract(app, person, data, true), "StaffRenew", 17)
		renew.set_meta("staff_id", person.id)
		actions.add_child(renew)
	if own and person.get("canRelease", false): _departure(app, actions, person, data, "staff_release", "Libérer", "Le membre du staff redeviendra disponible au recrutement.")
	if own and person.get("canRetire", false): _departure(app, actions, person, data, "staff_retire", "Retraite", "Cette personne quittera définitivement le marché du staff.")

## Recruter ou prolonger : sous-page du Staff (club_pages.gd), jamais une fenêtre.
static func _contract(app: Control, person: Dictionary, _data: Dictionary, renew: bool) -> void:
	load("res://ui/immersive08/club_pages.gd").ouvrir(app, "contrat", {"staff_id": str(person.id), "renew": renew})

static func contrat_page(app: Control, list: VBoxContainer, person: Dictionary, data: Dictionary, renew: bool, fermer: Callable) -> void:
	list.add_child(G.section(person.name, person.get("roleLabel", person.get("role", "Staff"))))
	var employment: Dictionary = app.model.get("clubLife", {}).get("staffEmployment", {})
	var context_key := JSON.stringify(data.get("context",{}))
	if app.management_ui.get("staff_contract_context","") != context_key:
		app.management_ui.staff_contract_context = context_key
		app.management_ui.staff_contract_drafts = {}
	var drafts: Dictionary = app.management_ui.get("staff_contract_drafts",{})
	var draft_key := str(person.id) + (":renew" if renew else ":hire")
	var draft: Dictionary = drafts.get(draft_key,{})
	if draft.get("status","") == "submitted" and not app.get("waiting"): draft.status = "refused"
	var paid: bool = employment.get("enabled", false)
	var person_finance := _employment_person(app, str(person.id))
	list.add_child(G.wrap("Salaire de jeu : %s, sans prime de signature. Les autres charges du club continuent." % G.salary(person_finance.get("salary",0)) if paid else "Contrat descriptif : salaires et prime 0 €. Le contrat fixe la durée de présence dans le club.", 14))
	var years := OptionButton.new()
	years.name = "StaffContractYears"
	for n in range(int(person.get("minYears", 1)), int(person.get("maxYears", data.get("maxYears", 3))) + 1):
		years.add_item("%d saison%s" % [n, "s" if n > 1 else ""]); years.set_item_metadata(years.item_count - 1, n)
	for index in years.item_count:
		if int(years.get_item_metadata(index)) == int(draft.get("years",-1)): years.select(index)
	list.add_child(years)
	if draft.get("status","") == "refused":
		var retry := G.wrap("Le contrat n’a pas été appliqué. Ta durée est conservée ; vérifie le devis puis réessaie.",14,G.ALERT)
		retry.name = "StaffContractRetryNotice"
		list.add_child(retry)
	var remember := func():
		if years.selected < 0: return
		if not drafts.has(draft_key) and drafts.size() >= 32: drafts.erase(drafts.keys()[0])
		draft.years = int(years.get_item_metadata(years.selected))
		drafts[draft_key] = draft
		app.management_ui.staff_contract_drafts = drafts
	var commitment := G.wrap("", 14)
	commitment.name = "StaffEmploymentCommitment"
	list.add_child(commitment)
	var refresh_cost := func():
		if not paid or years.selected < 0: return
		var duration := int(years.get_item_metadata(years.selected))
		var payments := int(employment.get("remainingCurrentSeason",0)) + (duration - 1) * int(employment.get("weeksPerSeason",29))
		commitment.text = "Engagement projeté : %s € sur %d paies. Réserve 50 000 € et provision de huit paies du staff requises." % [G.n(payments * int(person_finance.get("salary",0))),payments]
	years.item_selected.connect(func(_i: int): remember.call(); refresh_cost.call())
	refresh_cost.call()
	var sign := G.button("CONFIRMER LE CONTRAT", func():
		var payload := {"confirmed":true,"context":data.context.duplicate(true),"years":int(years.get_item_metadata(years.selected))}
		payload["staffId" if renew else "candidateId"] = str(person.id)
		if paid: payload.salary = int(person_finance.get("salary",0)); payload.context = employment.context.duplicate(true)
		remember.call()
		draft.status = "submitted"
		var command := ("staff_employment_renew" if renew else "staff_employment_hire") if paid else ("staff_renew" if renew else "staff_hire")
		var bridge: Variant = app.get("bridge")
		var expected_end := int(payload.context.season) + int(payload.years) - 1
		if not paid and app.model.get("meta",{}).get("phase","") == "ended": expected_end += 1
		fermer.call()
		var sent: Variant = app._command(command,payload)
		if sent == true and bridge != null:
			_observe_contract(app,bridge,drafts,draft_key,draft,command,str(person.id),payload.context.duplicate(true),expected_end,paid,int(payload.get("salary",0)))
		else: draft.status = "refused", true)
	sign.name = "StaffContractConfirm"
	if draft.get("status","") == "refused": sign.text = "RÉESSAYER LE CONTRAT"
	sign.disabled = years.item_count == 0
	list.add_child(sign)

## Libérer / Retraite : lien rouge marqué ✕ (le mot et le signe disent l'action, pas la couleur seule) ; confirmation
## EN PLACE dans la page avec le coût écrit (indemnité de rupture quand le contrat est rémunéré).
static func _departure(app: Control, parent: Container, person: Dictionary, data: Dictionary, command: String, title: String, detail: String, libelle: String = "") -> Button:
	var button := lien("✕ " + (title if libelle.is_empty() else libelle), func():
		var payload := {"confirmed":true,"context":data.context.duplicate(true),"staffId":str(person.id)}
		var employment := _employment_person(app, str(person.id))
		var destination := command
		var message := detail
		if employment.get("employed",false):
			payload.severance = int(employment.severance)
			payload.context = app.model.clubLife.staffEmployment.context.duplicate(true)
			destination = "staff_employment_retire" if command == "staff_retire" else "staff_employment_release"
			message += " Indemnité de rupture : %s €, au plus deux paies." % G.n(employment.severance)
		app.confirm(title + " · " + str(person.name), message, func(): app._command(destination, payload)), "StaffRelease" if command == "staff_release" else "StaffRetire", 17, Charte.D)
	button.set_meta("staff_id", person.id)
	parent.add_child(button)
	return button

# Shared by the classic Staff page and its immersive styling.
static func _mentoring(app: Control, parent: Container) -> void:
	var data: Dictionary = app.model.get("clubLife", {}).get("staffMentoring", {})
	if not data.get("available", false): return
	var duos: int = data.get("assignments", []).size()
	var open := lien("Mentorat des jeunes · %s →" % ("aucun duo" if duos == 0 else "%d duo%s" % [duos, "s" if duos > 1 else ""]), func(): _mentor_overview(app, data), "StaffMentoringOpen", 18)
	parent.add_child(open)

static func _mentor_overview(app: Control, _data: Dictionary) -> void:
	load("res://ui/immersive08/club_pages.gd").ouvrir(app, "mentorat")

static func mentorat_page(app: Control, parent: VBoxContainer, data: Dictionary, fermer: Callable) -> void:
	parent.add_child(G.wrap(data.get("notice", ""), 14))
	if not data.get("enabled", false):
		var activate := G.button("ACTIVER LE MENTORAT", func():
			app.confirm("Activer le mentorat", "Cette carrière conservera les affectations et les séances réellement encadrées. Aucun point de croissance ni salaire supplémentaire.", func(): app._command("staff_mentoring_enable", {"confirmed":true,"context":data.context.duplicate(true)})))
		activate.name = "StaffMentoringEnable"
		activate.disabled = not data.get("canEnable", false)
		parent.add_child(activate)
	else:
		if int(data.get("dormantAssignments", 0)) > 0: parent.add_child(G.wrap("%d lien(s) devenus indisponibles seront libérés lors de ta prochaine affectation." % int(data.dormantAssignments), 12))
		for assignment: Dictionary in data.get("assignments", []):
			parent.add_child(G.wrap("%s → %s · %s · %d/8 séances · %d %% ciblés%s" % [assignment.staffName, assignment.playerName, assignment.focus, int(assignment.sessions), roundi(float(assignment.targetShare) * 100), " · " + str(assignment.reason) if not assignment.get("active", false) else ""], 13))
			var remove := G.button("LIBÉRER LE MENTOR", func():
				fermer.call(); app._command("staff_mentor_remove", {"confirmed":true,"context":data.context.duplicate(true),"staffId":str(assignment.staffId)}))
			remove.name = "StaffMentorRemove"
			remove.disabled = data.get("locked", true)
			parent.add_child(remove)
		var assign := G.button("CHOISIR UN MENTOR ET UN JEUNE →", func(): _mentor_dialog(app, data))
		assign.name = "StaffMentorAssign"
		assign.disabled = data.get("locked", true) or data.get("mentors", []).is_empty() or data.get("players", []).is_empty()
		parent.add_child(assign)
		if data.get("players", []).is_empty(): parent.add_child(G.wrap("Aucun jeune de 15 à 24 ans avec progression spécialisée disponible. Les courbes annuelles restent inchangées.", 12))

static func _mentor_dialog(app: Control, _data: Dictionary) -> void:
	load("res://ui/immersive08/club_pages.gd").ouvrir(app, "mentor")

static func mentor_page(app: Control, list: VBoxContainer, data: Dictionary, fermer: Callable) -> void:
	list.add_child(G.wrap("Le mentor consacre son suivi à un seul jeune. La qualité ciblée prend une part de son expérience générale. Un plan individuel explicite garde priorité. Changer de qualité remet à zéro ses XP ciblés partiels, selon la règle existante.", 14))
	var mentors := OptionButton.new()
	mentors.name = "StaffMentorChoice"
	for member: Dictionary in data.get("mentors", []):
		mentors.add_item("%s · %d/8 séances observées%s" % [member.name, int(member.observedSessions), " · ancien joueur" if member.get("converted", false) else ""])
		mentors.set_item_metadata(mentors.item_count - 1, member.id)
	list.add_child(mentors)
	var pupils := OptionButton.new()
	pupils.name = "StaffMentorPupil"
	for player: Dictionary in data.get("players", []):
		pupils.add_item(str(player.name) + " · " + str(player.pos))
		pupils.set_item_metadata(pupils.item_count - 1, player.id)
	list.add_child(pupils)
	var focus := OptionButton.new()
	focus.name = "StaffMentorFocus"
	list.add_child(focus)
	var refresh := func():
		focus.clear()
		if pupils.selected < 0: return
		var selected: Dictionary = data.players[pupils.selected]
		for quality: Dictionary in selected.get("focusOptions", []):
			focus.add_item(str(quality.label)); focus.set_item_metadata(focus.item_count - 1, quality.key)
	pupils.item_selected.connect(func(_index: int): refresh.call())
	refresh.call()
	var confirm := G.button("CONFIRMER L’AFFECTATION", func():
		if mentors.selected < 0 or pupils.selected < 0 or focus.selected < 0: return
		var payload := {"confirmed":true,"context":data.context.duplicate(true),"staffId":str(mentors.get_item_metadata(mentors.selected)),"playerId":str(pupils.get_item_metadata(pupils.selected)),"focus":str(focus.get_item_metadata(focus.selected))}
		fermer.call(); app._command("staff_mentor_assign", payload), true)
	confirm.name = "StaffMentorConfirm"
	list.add_child(confirm)

static func _employment_person(app: Control, staff_id: String) -> Dictionary:
	var data: Dictionary = app.model.get("clubLife", {}).get("staffEmployment", {})
	for person: Dictionary in data.get("own", []) + data.get("candidates", []):
		if str(person.id) == staff_id: return person
	return {}

static func _employment(app: Control, parent: Container) -> void:
	var data: Dictionary = app.model.get("clubLife", {}).get("staffEmployment", {})
	if not data.get("available", false): return
	if not data.get("enabled", false):
		var activate := lien("Activer les contrats rémunérés →",func(): app.confirm("Rémunération nominative du staff", "Activation gratuite, sans adoption des contrats en poste. Les futurs recrutements de ce club seront rémunérés selon le barème visible avant signature.",func():app._command("staff_employment_enable",{"confirmed":true,"context":data.context.duplicate(true)})), "StaffEmploymentEnable", 18)
		activate.disabled = not data.get("canEnable", false)
		parent.add_child(activate)
	else:
		var budget := lien("Budget du staff · %s →" % G.salary(data.get("weeklyWages",0)),func(): load("res://ui/immersive08/club_pages.gd").ouvrir(app, "engagements"), "StaffEmploymentBudgetOpen", 18)
		parent.add_child(budget)

# One in-flight observer per app, with paired cleanup on model OR transport error.
static func _forget_contract_observer(app: Control) -> void:
	if not app.has_meta("staff_contract_observer"): return
	var observer: Dictionary = app.get_meta("staff_contract_observer")
	app.remove_meta("staff_contract_observer")
	var bridge: Variant = observer.bridge.get_ref()
	if bridge == null: return
	if bridge.is_connected("model_changed",observer.model): bridge.disconnect("model_changed",observer.model)
	if bridge.is_connected("command_failed",observer.error): bridge.disconnect("command_failed",observer.error)

static func _contract_ack(model: Dictionary,command: String,staff_id: String,context: Dictionary,end_season: int,paid: bool,salary: int) -> bool:
	var action: Dictionary = model.get("meta",{}).get("staffEmploymentAction" if paid else "staffCareerAction",{})
	if str(action.get("command","")) != command: return false
	if not paid and str(action.get("staffId","")) != staff_id: return false
	var career: Dictionary = model.get("clubLife",{}).get("staffCareer",{})
	var data: Dictionary = model.get("clubLife",{}).get("staffEmployment",{}) if paid else career
	if data.get("context",{}) != context: return false
	var witnessed := false
	for team: Dictionary in career.get("teams",[]):
		if int(team.id) != int(context.club): continue
		for person: Dictionary in team.get("members",[]):
			if str(person.id) == staff_id and int(person.get("clubId",-1)) == int(context.club) and int(person.get("contractEnd",-1)) == end_season: witnessed = true
	if not witnessed: return false
	if paid:
		for person: Dictionary in data.get("own",[]):
			if str(person.id) == staff_id and person.get("employed",false) and int(person.get("paidSalary",-1)) == salary and int(person.get("contractEnd",-1)) == end_season: return true
		return false
	return true

static func _observe_contract(app: Control,bridge: Object,drafts: Dictionary,key: String,draft: Dictionary,command: String,staff_id: String,context: Dictionary,end_season: int,paid: bool,salary: int) -> void:
	_forget_contract_observer(app)
	var app_ref: WeakRef = weakref(app)
	var bridge_ref: WeakRef = weakref(bridge)
	var token := RefCounted.new()
	var on_model := func(model: Dictionary):
		var host: Control = app_ref.get_ref()
		var source: Object = bridge_ref.get_ref()
		if host == null or source == null or host.get_meta("staff_contract_observer",{}).get("token") != token: return
		var accepted: bool = source.get("last_response_ok") == true and _contract_ack(model,command,staff_id,context,end_season,paid,salary)
		_forget_contract_observer(host)
		if accepted: drafts.erase(key)
		else: draft.status = "refused"
	var on_error := func(_message: String):
		var host: Control = app_ref.get_ref()
		if host == null or host.get_meta("staff_contract_observer",{}).get("token") != token: return
		_forget_contract_observer(host)
		draft.status = "refused"
	app.set_meta("staff_contract_observer",{"bridge":bridge_ref,"model":on_model,"error":on_error,"token":token})
	bridge.connect("model_changed",on_model)
	bridge.connect("command_failed",on_error)

static func engagements_page(_app: Control, list: VBoxContainer, data: Dictionary) -> void:
	list.add_child(G.wrap(str(data.get("notice","")),14))
	list.add_child(G.wrap("Trésorerie : %s € · engagements staff : %s € · solde après ces seuls engagements : %s €. Autres recettes et dépenses exclues." % [G.n(data.get("cash",0)),G.n(data.get("knownCommitment",0)),G.n(data.get("forecastAfterKnownStaff",0))],15))
