extends Control
## Coque illustrée du Centre, autour des mêmes parcours et contrôles métier.
const Copy = preload("res://ui/management_copy.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const Academy = preload("res://ui/academy_pathways_view.gd")
const GREEN = Color("64e896")
const GOLD = Color("f8cd73")
const ACCENT = Color("09673e")

var app: Control
var data: Dictionary
var state: Dictionary
var restored_scrolls := {}

static func build(application: Control, canvas: Control) -> void:
	var page := new()
	page.app = application
	page.name = "ImmersiveCentre"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, 2248, 1230))
	page._build()

func _build() -> void:
	data = app.model.get("clubLife", {}).get("academyPathways", {})
	if not app.management_ui.get("immersive_centre") is Dictionary:
		app.management_ui.immersive_centre = {"tab":"","scroll":{}}
	state = app.management_ui.immersive_centre
	var club: Variant = app.model.get("club", {}).get("id")
	if state.get("club") != club:
		state.clear()
		state.merge({"club":club,"tab":"","scroll":{}})
	_hero()
	_workbench()
	_summary()

func _hero() -> void:
	var hero := D.panel(self, Rect2(0, 0, 2248, 200), "", "", "", "CentreHero")
	hero.clip_contents = true
	var sol := BanqueImages.region(G.identity(app.model.get("club", {})))
	D.photo(hero, sol if BanqueImages.existe(sol) else "club-forest", Rect2(1300, 1, 946, 198))
	D.fade_photo_edges(D.photo(hero, "academy-training", Rect2(998, 1, 790, 198)))
	D.text(hero, 26, 36, "LE CENTRE DE FORMATION", 28, GOLD, 700, 1120).add_theme_font_override("font", C.Charte.TITRE_FICHE)
	app.heading = D.text(hero, 25, 111, "Les chemins de la progression.", 68, C.IVORY, 800, 1140)
	var context := "Détection, mentorat et compétition junior" if data.get("available", false) else "Suivi des Espoirs dans Formation"
	D.text(hero, 28, 151, G.club_name(app.model.club) + "  ·  " + context, 25, C.IVORY, 500, 1100, HORIZONTAL_ALIGNMENT_LEFT, true)
	D.chip(hero, Rect2(29, 163, 288, 30), _pathway_status().to_upper(), GREEN if data.get("active", false) else GOLD)
	D.button(hero, Rect2(1840, 126, 388, 56), "Revenir à la formation", func(): app._navigate("Formation"), false, "arrow", false, ACCENT, "CentreBackFormation")

func _workbench() -> void:
	var surface := D.panel(self, Rect2(0, 218, 1513, 1005), "", "", "", "CentreWorkbench")
	surface.clip_contents = true
	if not data.get("active", false):
		_preview(surface)
		return
	# Les contrôles et commandes du Centre viennent de la vue métier partagée.
	# Son onglet international peut évoluer sans recopier ni figer sa structure.
	var viewport := ScrollContainer.new()
	viewport.name = "CentreWorkbenchViewport"
	viewport.follow_focus = true
	viewport.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	surface.add_child(viewport)
	D.place(viewport, Rect2(12, 12, 1489, 981))
	var controls := Academy.build(app, str(state.tab))
	viewport.add_child(controls)
	Legacy.apply(controls, ACCENT)
	C.reach_controls(controls)
	var tabs := controls.find_child("AcademyTabs", true, false) as TabContainer
	if tabs == null: return
	_style_tabs(tabs)
	var scrolls: Dictionary = {}
	for i in tabs.get_tab_count():
		var tab := tabs.get_tab_control(i)
		var key := str(tab.name)
		var nodes := tab.find_children("*", "ScrollContainer", true, false)
		if not nodes.is_empty():
			var scroll: ScrollContainer = nodes[0]
			scrolls[key] = scroll
			scroll.get_v_scroll_bar().value_changed.connect(func(value: float):
				if restored_scrolls.has(key): state.scroll[key] = int(value))
	tabs.tab_changed.connect(func(index: int):
		state.tab = str(tabs.get_tab_control(index).name)
		_restore_scroll.call_deferred(str(state.tab), scrolls.get(state.tab)))
	var active := str(tabs.get_tab_control(tabs.current_tab).name)
	_restore_scroll.call_deferred(active, scrolls.get(active))

func _pathway_status() -> String:
	if not data.get("available", false): return "Relève suivie en formation"
	return "Parcours actifs" if data.get("active", false) else "Parcours à activer"

func _preview(surface: Panel) -> void:
	var open: bool = data.get("available", false)
	D.text(surface, 30, 56, "LES PARCOURS DU CENTRE", 28, GOLD, 700, 1420)
	D.text(surface, 28, 127, "Trois outils pour suivre la relève." if open else "La relève se prépare au centre.", 58, C.IVORY, 800, 1440)
	var intro := Copy.notice("academy", data.get("description", "")) if open else "Détection, mentorat et compétition junior ouvriront avec le calendrier des Espoirs. D’ici là, la formation suit tes %s Espoirs : progression, promotions et spécialisations." % G.n(data.get("players", []).size())
	_note(surface, Rect2(31, 152, 1450, 52), intro, 24)
	var offers := [
		["Detection", "Détection", "scouting", "search", "Mener la campagne de détection du centre pour préparer la prochaine génération."],
		["Mentoring", "Mentorat", "analysis-room", "people", "Associer un Espoir à un joueur senior du même poste et suivre son accompagnement."],
		["Junior", "Compétition junior", "lineout-analysis", "trophy", "Préparer les rencontres juniors et suivre leur calendrier, distinct du championnat professionnel."],
	]
	for i in offers.size():
		var offer: Array = offers[i]
		var card := D.panel(surface, Rect2(25 + i * 490, 222, 483, 469), "", "", "", "CentreOffer" + str(offer[0]))
		card.clip_contents = true
		D.photo(card, offer[2], Rect2(13, 13, 457, 236), .4)
		if not open: _chip_fitted(card, Vector2(27, 27), "AU CALENDRIER DES ESPOIRS", GOLD, 423)
		D.line(card, Vector2(15, 271), Vector2(468, 271))
		var icon := C.icon(offer[3], 32, GOLD)
		card.add_child(icon)
		D.place(icon, Rect2(19, 294, 32, 32))
		D.text(card, 63, 325, offer[1], 38, C.IVORY, 800, 395)
		_note(card, Rect2(21, 352, 435, 103), offer[4], 26)
	if not open:
		var follow := D.panel(surface, Rect2(25, 713, 1463, 267), "En attendant", "school", "", "CentreFollow")
		D.text(follow, 24, 117, "Tes %s Espoirs restent au centre." % G.n(data.get("players", []).size()), 40, C.IVORY, 700, 900)
		_note(follow, Rect2(25, 143, 840, 85), "Leur progression, leurs promotions et leurs spécialisations se suivent dans Formation.", 25)
		var go := D.button(follow, Rect2(918, 130, 513, 66), "Consulter les Espoirs", func(): app._navigate("Formation"), false, "arrow", false, ACCENT, "CentreUnavailableFormation")
		go.add_theme_font_override("font", C.BOLD)
		go.add_theme_font_size_override("font_size", C.font_px(31))
		return
	var activation := D.panel(surface, Rect2(25, 713, 1463, 267), "Avant d’activer", "school", "", "CentreActivation")
	D.text(activation, 24, 117, "Tes %s Espoirs restent au centre." % G.n(data.get("players", []).size()), 40, C.IVORY, 700, 900)
	var locked: bool = data.get("locked", false)
	var note := "L’activation est indisponible pendant un match ou après la clôture de la saison." if locked else "Les parcours s’ajoutent à ton suivi actuel dans cette carrière."
	_note(activation, Rect2(25, 143, 840, 85), note, 25)
	var action := Academy._action(activation, app, data, "ACTIVER LES PARCOURS", "academy_activate", {}, 0)
	action.set_meta("carnet_selected", true)
	C.style_bouton_contour(action, 31)
	action.add_theme_font_override("font", C.BOLD)
	action.add_theme_font_size_override("font_size", C.font_px(31))
	D.place(action, Rect2(918, 130, 513, 66))

## Pastille dont la largeur suit son texte à la densité réelle (plancher de police 12 px en 1280 × 720) :
## jamais de points de suspension, au plus `limit` unités du gabarit.
func _chip_fitted(parent: Control, at: Vector2, caption: String, color: Color, limit: float) -> Panel:
	var pixels := C.font_px(19)
	var measured := C.font(600).get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	var width := clampf(ceilf(measured / maxf(C.density, .01)) + 30.0, 238.0, limit)
	return D.chip(parent, Rect2(at.x, at.y, width, 30), caption, color)

func _note(parent: Control, rectangle: Rect2, text: String, pixels: int) -> void:
	var label := C.wrap("", pixels, C.MUTED)
	parent.add_child(label)
	D.place(label, rectangle)
	label.text = text

func _style_tabs(tabs: TabContainer) -> void:
	tabs.add_theme_font_override("font", C.BOLD)
	tabs.add_theme_font_size_override("font_size", C.font_px(24))
	var selected := C.box(Color("0b5435"), GREEN, 6, 12)
	var unselected := C.box(Color("152322"), C.LINE, 6, 12)
	var hover := C.box(Color("204634"), GREEN, 6, 12)
	for style: StyleBoxFlat in [selected, unselected, hover]:
		style.content_margin_top = maxi(5, C.px(8))
		style.content_margin_bottom = maxi(5, C.px(8))
	tabs.add_theme_stylebox_override("tab_selected", selected)
	tabs.add_theme_stylebox_override("tab_unselected", unselected)
	tabs.add_theme_stylebox_override("tab_hovered", hover)
	tabs.add_theme_color_override("font_selected_color", C.IVORY)
	tabs.add_theme_color_override("font_unselected_color", C.MUTED)
	tabs.add_theme_color_override("font_hovered_color", C.IVORY)

func _restore_scroll(key: String, scroll: ScrollContainer) -> void:
	if scroll == null or restored_scrolls.has(key) or not is_inside_tree(): return
	var tree := get_tree()
	for frame in 2:
		await tree.process_frame
		if not is_inside_tree(): return
	if not scroll.is_visible_in_tree() or restored_scrolls.has(key): return
	scroll.scroll_vertical = int(state.scroll.get(key, 0))
	restored_scrolls[key] = true

func _summary() -> void:
	var active: bool = data.get("active", false)
	var facts := [
		["ESPOIRS SUIVIS", G.n(data.get("players", []).size()), "people", GREEN],
		["ENVELOPPE JUNIOR", G.euros(data.recruitBudget) if data.has("recruitBudget") else "—", "money", GOLD],
		["COHÉSION DU CENTRE", G.n(data.get("cohesion", "—")), "heart", GREEN],
		["RÉPUTATION", G.n(data.get("reputation", "—")), "star", GOLD],
	]
	facts = facts.filter(func(fact: Array): return str(fact[1]) != "—")
	# Une seule rangée de chiffres (Espoirs, enveloppe) : le panneau se resserre d'une rangée et la place
	# libérée revient à la photo du panneau du bas, au lieu d'une bande vide sous les tuiles.
	var rows := maxi(1, ceili(facts.size() / 2.0))
	var dy := (rows - 2) * 108 if rows < 2 else 0
	var panel := D.panel(self, Rect2(1531, 218, 717, 596 + dy), "Le tableau du centre", "school", "", "CentreStatus")
	for i in facts.size():
		var entry: Array = facts[i]
		# Tuile seule sur sa rangée : toute la largeur du panneau.
		var wide := i == facts.size() - 1 and i % 2 == 0
		var rect := Rect2(18 + (i % 2) * 345, 73 + floori(i / 2.0) * 108, 679 if wide else 334, 97)
		var tile := D.panel(panel, rect)
		var icon := C.icon(entry[2], 32, entry[3])
		tile.add_child(icon)
		D.place(icon, Rect2(15, 27, 32, 32))
		D.text(tile, 61, 35, entry[0], 21, C.MUTED, 700, rect.size.x - 69)
		D.text(tile, 61, 75, entry[1], 35, entry[3], 700, rect.size.x - 72)
	D.line(panel, Vector2(17, 293 + dy), Vector2(699, 293 + dy))
	D.text(panel, 22, 339 + dy, "SAISON JUNIOR", 24, GOLD, 700, 660)
	var round := _pathway_status()
	if active:
		round = "%s / %s périodes" % [G.n(data.get("juniorRound", "—")), G.n(data.get("totalRounds", "—"))]
	D.text(panel, 22, 394 + dy, round, 39, C.IVORY, 700, 672)
	var note := Copy.notice("academy", data.get("description", "Le centre est disponible dans une carrière active."))
	if not active:
		note = "L’activation ouvre le calendrier et les résultats juniors." if data.get("available", false) else "Détection, mentorat et compétition junior ouvriront avec le calendrier des Espoirs."
	var lines := D.words(note, 69, 3)
	for i in lines.size(): D.text(panel, 23, 439 + dy + i * 27, lines[i], 23, C.MUTED, 500, 675, HORIZONTAL_ALIGNMENT_LEFT, true)
	D.button(panel, Rect2(21, 522 + dy, 676, 55), "Consulter les Espoirs", func(): app._navigate("Formation"), false, "arrow", false, ACCENT, "CentreOpenAcademy")
	var lower := D.panel(self, Rect2(1531, 832 + dy, 717, 391 - dy), "De l’académie à l’équipe première", "trophy", "", "CentreDevelopment")
	D.photo(lower, "academy-training", Rect2(14, 70, 689, 211 - dy))
	var places := G.n(data.get("places", "—"))
	D.text(lower, 22, 328 - dy, "Places professionnelles disponibles", 26, C.IVORY, 700, 480)
	D.text(lower, 689, 340 - dy, places, 43, GREEN, 800, 183, HORIZONTAL_ALIGNMENT_RIGHT)
	D.text(lower, 23, 365 - dy, "La capacité tient compte des places réservées aux retours de prêt.", 20, C.MUTED, 500, 673, HORIZONTAL_ALIGNMENT_LEFT, true)
