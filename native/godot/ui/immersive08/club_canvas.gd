extends RefCounted
## Écran Club (choix de Léo du 19/11/2026 : maquette « 1 · Deux colonnes, le conseil à gauche », avec le tableau
## « ce qui a fait bouger la confiance » de la maquette 2). Vue d'ensemble : titre et onglets, bandeau du club, à gauche
## le conseil (confiance, seuils, objectif, bilans) et les installations, à droite « À décider » et le vestiaire.
## Tout ce qui ressemble à un lien, une ligne ou un chiffre ouvre un écran ; aucune petite fenêtre (confirmations en place,
## actions longues du staff en sous-pages : club_pages.gd). Coordonnées en unités du gabarit (2248 de large), jetons de la charte.
const EntityLink = preload("res://ui/entity_link.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Palmares = preload("res://ui/immersive08/palmares_text.gd")
const G = preload("res://ui/game_skin.gd")
const ClubViews = preload("res://ui/club_views.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const History = preload("res://ui/club_memory_view.gd")
const World = preload("res://ui/immersive08/world_archive.gd")
const Strategy = preload("res://ui/strategy_view.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const HistoireVisuels = preload("res://ui/immersive08/histoire_visuels.gd")
const Pages = preload("res://ui/immersive08/club_pages.gd")
const Habillage = preload("res://ui/immersive08/recruitment_pages.gd")
const Etat = preload("res://ui/management_state.gd")
const StaffTable = preload("res://ui/staff_career_view.gd")
const KEY = "immersive08_club_tab"
const GOALS = {"wins":"Victoires", "points":"Points", "rank":"Place au classement", "cash":"Trésorerie"}
const GOAL_STATUS = {"pending":"À suivre", "met":"Atteint", "missed":"Manqué", "unverified":"Non vérifié"}
const W := 2248.0
const TOP := 132.0
const HAUT := 1244.0
const TABS := [["overview", "Vue d’ensemble"], ["direction", "Direction"], ["infrastructure", "Infrastructures"], ["staff", "Staff"], ["history", "Histoire"]]
## Seuils de la confiance du conseil (fiche UX 18, section 13) : Solide à partir de 70, Fragile de 40 à 69, Menacé en dessous.
const SEUIL_SOLIDE := 70
const SEUIL_FRAGILE := 40
const LIGNE := 32.0

## Case dessinée de la charte : coche (ok), point d'exclamation (alerte), croix (menace), tiret (neutre). Le sens est
## dans la forme, jamais dans la couleur seule.
class Coche extends Control:
	var genre := "ok"
	var couleur := Charte.IVOIRE
	func _draw() -> void:
		var s := minf(size.x, size.y)
		draw_rect(Rect2(Vector2.ZERO, Vector2(s, s)).grow(-1.0), couleur, false, maxf(1.5, s * .08))
		var w := maxf(1.5, s * .1)
		match genre:
			"ok": draw_polyline(PackedVector2Array([Vector2(s * .24, s * .54), Vector2(s * .44, s * .74), Vector2(s * .78, s * .28)]), couleur, w)
			"croix":
				draw_line(Vector2(s * .28, s * .28), Vector2(s * .72, s * .72), couleur, w)
				draw_line(Vector2(s * .72, s * .28), Vector2(s * .28, s * .72), couleur, w)
			"alerte":
				draw_line(Vector2(s * .5, s * .2), Vector2(s * .5, s * .6), couleur, w)
				draw_rect(Rect2(s * .44, s * .7, s * .12, s * .12), couleur)
			_: draw_line(Vector2(s * .28, s * .5), Vector2(s * .72, s * .5), couleur, w)

static func _coche(parent: Control, zone: Rect2, genre: String, couleur: Color = Charte.IVOIRE) -> Coche:
	var forme := Coche.new()
	forme.genre = genre
	forme.couleur = couleur
	forme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(forme)
	D.place(forme, zone)
	return forme

static func _navigation(app: Control) -> Node:
	for field: Dictionary in app.get_property_list():
		if field.name == "navigation_controller": return app.get("navigation_controller") as Node
	return null

static func _reading_area(app: Control, parent: Control, rectangle: Rect2, target: Dictionary, id: String, caption: String) -> Button:
	var navigation := _navigation(app)
	if not is_instance_valid(navigation) or not navigation.has_method("entity_available") or not navigation.entity_available(target): return null
	var button := Button.new()
	button.name = id
	button.flat = true
	button.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	button.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 0, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	EntityLink.bind(button, app, target, caption)
	button.tooltip_text = ""
	parent.add_child(button)
	D.place(button, rectangle)
	return button

static func build(app: Control, canvas: Control) -> void:
	canvas.name = "ImmersiveClub"
	var tab: String = str(app.management_ui.get(KEY, "history" if app.management_ui.get("club_tab", 0) == 1 else "overview"))
	match app.route:
		"Stratégie": tab = "direction"
		"Staff", "Travail du club": tab = "staff"
	_header(app, canvas, tab)
	if app.route == "Staff" and not Pages.actuelle(app).is_empty():
		Pages.build(app, canvas)
	else:
		var corps := Control.new()
		corps.name = "ClubBody"
		corps.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(corps)
		# Les onglets autres que la vue d'ensemble sont dessinés depuis y = 214 : le corps les remonte sous les onglets.
		corps.position = Vector2(0, (TOP - 214.0) * C.density)
		corps.size = Vector2(W, HAUT) * C.density
		match app.route:
			"Stratégie": _direction(app, corps)
			"Staff", "Travail du club": _staff_detail(app, corps)
			_:
				match tab:
					"infrastructure": _infrastructure_detail(app, corps)
					"history": _history(app, corps)
					"territory": _territory(app, corps)
					_: _overview(app, canvas)
	# Confirmations d'argent EN PLACE (main.gd les route ici) : bloc posé en haut de la page, jamais une fenêtre.
	var hote := VBoxContainer.new()
	hote.name = "ClubConfirmHote"
	hote.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.add_child(hote)
	D.place(hote, Rect2(0, TOP + 8, W - 40, 10))

## Bandeau du club : onglet Infrastructures -> le stade du club à sa taille (banque d'images, d'après la capacité),
## sinon la vue habituelle.
static func photo_entete(model: Dictionary, tab: String) -> String:
	if tab != "infrastructure":
		var sol := BanqueImages.region(G.identity(model.get("club", {})))
		return sol if not sol.is_empty() and BanqueImages.texture(sol) != null else "club-forest"
	var fans: Variant = U.strategy(model).get("fans", {})
	var niveau := BanqueImages.niveau_stade(fans.get("capacity") if fans is Dictionary else null)
	var id := BanqueImages.choisir("infrastructures", {"categorie_image": "stade", "niveau_infrastructure": niveau}) if niveau > 0 else ""
	return id if not id.is_empty() and BanqueImages.texture(id) != null else "club-forest"

## Président du conseil, lu dans les données du club quand elles le publient (jamais figé dans le code).
static func _president(app: Control) -> String:
	var sources: Array = [app.model.get("club", {}), app.model.get("clubLife", {}), U.strategy(app.model).get("board", {})]
	for source: Variant in sources:
		if not source is Dictionary: continue
		var valeur: Variant = source.get("president")
		if valeur is Dictionary and not str(valeur.get("name", "")).strip_edges().is_empty(): return str(valeur.name).strip_edges()
		if valeur is String and not valeur.strip_edges().is_empty(): return valeur.strip_edges()
	return ""

static func _sous_titre(app: Control) -> String:
	var identite := G.identity(app.model.club)
	var fans: Dictionary = U.strategy(app.model).get("fans", {})
	var parts: Array[String] = []
	var stade := str(identite.get("stadium", "")).strip_edges()
	if not stade.is_empty(): parts.append(stade)
	if fans.has("capacity"): parts.append(G.n(fans.capacity) + " places")
	var histoire: Variant = identite.get("history")
	if histoire is Dictionary and histoire.has("founded"): parts.append("fondé en %d" % int(histoire.founded))
	var president := _president(app)
	if not president.is_empty(): parts.append("conseil présidé par " + president)
	return " · ".join(parts)

static func _header(app: Control, canvas: Control, tab: String) -> void:
	var titre := Kit.titre_page(canvas, 0, 46, "Club", 40, 150)
	titre.name = "ClubTitle"
	var sous := Kit.texte(canvas, 150, 46, _sous_titre(app), Charte.IVOIRE_2, 1900, 19)
	sous.name = "ClubSubtitle"
	var x := 0.0
	for i in TABS.size():
		var key: String = TABS[i][0]
		var libelle: String = str(TABS[i][1])
		var choisi := key == tab or (key == "overview" and tab == "territory")
		var id := "ClubTab_" + key
		var largeur := C.DISPLAY.get_string_size(libelle, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(22))).x / C.density + 44
		var bouton := Button.new()
		bouton.name = id
		bouton.text = libelle
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# Charte §7.1 : onglet en pilule, bas de casse, comme les onglets de la coque ; actif = aplat crème, texte PANNEAU.
		bouton.add_theme_font_override("font", C.DISPLAY)
		bouton.add_theme_font_size_override("font_size", maxi(12, C.px(22)))
		D.tab_state(bouton, Vector2(largeur, 46), choisi, "")
		bouton.icon = null
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE, 18)
		focus.set_border_width_all(2)
		focus.set_expand_margin_all(2)
		bouton.add_theme_stylebox_override("focus", focus)
		bouton.toggle_mode = true
		bouton.button_pressed = choisi
		bouton.pressed.connect(func(): _tab(app, key, id))
		bouton.gui_input.connect(func(evenement: InputEvent):
			if evenement is InputEventKey and evenement.pressed and not evenement.echo and evenement.keycode in [KEY_LEFT, KEY_RIGHT]:
				var cible := clampi(i + (1 if evenement.keycode == KEY_RIGHT else -1), 0, TABS.size() - 1)
				if cible != i: _tab(app, TABS[cible][0], "ClubTab_" + str(TABS[cible][0]))
				bouton.accept_event())
		canvas.add_child(bouton)
		D.place(bouton, Rect2(x, 70, largeur, 46))
		x += largeur + 6
	D.line(canvas, Vector2(0, 117), Vector2(W, 117), Charte.FILET)
	# Raccourci ← → : en info-bulle des onglets, plus en mode d'emploi écrit (règle de Léo du 21/11/2026).
	for onglet: Node in canvas.get_children():
		if onglet is Button and str(onglet.name).begins_with("ClubTab_"): (onglet as Button).tooltip_text = "← → pour changer d’onglet"

static func _tab(app: Control, key: String, id: String = "") -> void:
	if key == "direction" or key == "staff":
		app.management_ui.erase("club_page")
		app._navigate("Stratégie" if key == "direction" else "Staff")
		return
	app.management_ui.erase("club_page")
	app.management_ui[KEY] = key
	app.management_ui.club_tab = 1 if key == "history" else 0
	if app.route != "Club": app._navigate("Club")
	else: U.select(app, KEY, key, id)

static func _open_strategy(app: Control, index: int) -> void:
	app.management_ui.immersive08_strategy_tab = index
	app._navigate("Stratégie")

# --- Vue d'ensemble ------------------------------------------------------------------------------------------------------

static func _panneau(parent: Control, zone: Rect2, titre: String, id: String, filet: bool = false) -> Panel:
	# Charte §3 : panneau de page rayon 18 px (24 en référence 2560, comme D.panel), sans bordure.
	var panneau := D.rect(parent, zone, Charte.PANNEAU, 24)
	panneau.name = id
	panneau.mouse_filter = Control.MOUSE_FILTER_PASS
	var entete := Kit.titre(panneau, 24, 40, titre, 28, zone.size.x - 300)
	entete.name = "CardTitle"
	if filet: D.line(panneau, Vector2(18, 56), Vector2(zone.size.x - 18, 56), Charte.FILET)
	return panneau

static func _overview(app: Control, canvas: Control) -> void:
	var strategie := U.strategy(app.model)
	var finance: Dictionary = strategie.get("finance", {})
	var board: Dictionary = strategie.get("board", {})
	var page := Control.new()
	page.name = "ClubOverview"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	D.place(page, Rect2(0, TOP, W, HAUT - TOP))
	_hero(app, page, strategie.get("fans", {}))
	var haut := 126.0
	var gauche := 1404.0
	var droite_x := gauche + 22.0
	var droite_l := W - droite_x
	_conseil(_panneau(page, Rect2(0, haut, gauche, 650), "Le conseil", "ClubCouncil"), app, finance, board)
	_installations(_panneau(page, Rect2(0, haut + 666, gauche, 302), "Installations", "ClubFacilities"), app, finance, strategie)
	var decider := _panneau(page, Rect2(droite_x, haut, droite_l, 436), "À décider", "ClubDecide")
	_decider(decider, app, finance, board, strategie)
	_vestiaire(_panneau(page, Rect2(droite_x, haut + 452, droite_l, 516), "Vestiaire", "ClubLocker"), app)

## Bandeau du club : écusson, nom, lieu et chiffres. Un clic ouvre « Le stade ».
static func _hero(app: Control, page: Control, fans: Dictionary) -> void:
	var bandeau := Button.new()
	bandeau.name = "ClubStadium"
	bandeau.flat = false # un bouton « flat » ne dessine ni son fond ni son ombre
	bandeau.focus_mode = Control.FOCUS_ALL
	bandeau.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bandeau.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU, Color.TRANSPARENT, 24, 0))
	bandeau.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 24, 0))
	bandeau.add_theme_stylebox_override("pressed", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 24, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 24, 0)
	focus.set_border_width_all(2)
	bandeau.add_theme_stylebox_override("focus", focus)
	bandeau.accessibility_name = "Voir le stade · " + str(G.identity(app.model.club).get("stadium", "le stade du club"))
	bandeau.pressed.connect(func(): _tab(app, "territory", "ClubTab_overview"))
	page.add_child(bandeau)
	bandeau.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	D.place(bandeau, Rect2(0, 0, W, 110))
	var photo := D.photo(bandeau, photo_entete(app.model, "overview"), Rect2(W * .4, 0, W * .6, 110), .5)
	photo.modulate = Color(1, 1, 1, .32)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ecusson := G.crest(app.model.club, C.px(88))
	ecusson.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bandeau.add_child(ecusson)
	D.place(ecusson, Rect2(24, 11, 88, 88))
	var identite := G.identity(app.model.club)
	var nom := D.text(bandeau, 134, 60, G.club_name(app.model.club).to_upper(), 44, Charte.IVOIRE, 800, 1100)
	nom.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	nom.name = "ClubHeroName"
	var x_tuile := 134.0
	if not str(identite.get("stadium", "")).is_empty():
		x_tuile += Kit.largeur(str(identite.stadium), 19) + 16.0
		Kit.texte(bandeau, 134, 92, str(identite.stadium), Charte.IVOIRE_2, 600, 19).name = "ClubStadiumName"
	for chiffre: Array in [["capacity", "places", Pastilles.TURQUOISE], ["expectedAttendance", "affluence", Pastilles.BLEU], ["subscribers", "abonnés", Pastilles.VIOLET]]:
		if not fans.has(chiffre[0]): continue
		var tuile := Pastilles.tuile(G.n(fans[chiffre[0]]), str(chiffre[1]), chiffre[2], Color(Charte.PANNEAU, .78), 24, "ClubStadium_" + str(chiffre[0]), true)
		tuile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		x_tuile += Pastilles.poser(bandeau, tuile, x_tuile, 70) + 8.0
	var voir := Kit.texte(bandeau, W - 28, 60, "Voir le stade →", Charte.IVOIRE, 300, 19, HORIZONTAL_ALIGNMENT_RIGHT)
	voir.add_theme_font_override("font", Kit.texte_gras())
	voir.name = "ClubSeeStadium"

static func _palier(valeur: Variant) -> Dictionary:
	if not (valeur is int or valeur is float): return {}
	if float(valeur) >= SEUIL_SOLIDE: return {"mot": "Solide", "rang": 1, "genre": "ok"}
	if float(valeur) >= SEUIL_FRAGILE: return {"mot": "Fragile", "rang": 2, "genre": "alerte"}
	return {"mot": "Menacé", "rang": 3, "genre": "croix"}

static func _signe(valeur: int) -> String:
	return "+%d" % valeur if valeur > 0 else ("−%d" % absi(valeur) if valeur < 0 else "0")

static func _texte_lignes(parent: Control, x: float, haut: float, largeur: float, valeur: String, taille: int, police: Font, couleur: Color, lignes: int) -> Label:
	var label := C.label(valeur, taille, couleur, false, 700)
	label.add_theme_font_override("font", police)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = lignes
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(label)
	D.place(label, Rect2(x, haut, largeur, taille * 1.32 * lignes + 4))
	return label

static func _conseil(panneau: Panel, app: Control, finance: Dictionary, board: Dictionary) -> void:
	var confiance: Variant = app.model.meta.get("trust")
	var historique: Array = finance.get("boardHistory", [])
	var dernier: Dictionary = historique[0] if not historique.is_empty() else {}
	var largeur := panneau.size.x / C.density
	if dernier.is_empty():
		Pastilles.poser_a_droite(panneau, Pastilles.pastille("1er bilan à venir", Pastilles.BLEU, "clock", "Le conseil rend son premier bilan après quelques journées.", 18, "ClubLastReview", func(): _open_strategy(app, 1)), largeur - 24, 14)
	else:
		Kit.texte(panneau, largeur - 24, 40, "dernier bilan après J%s" % G.n(dernier.round), Charte.IVOIRE_2, 400, 18, HORIZONTAL_ALIGNMENT_RIGHT).name = "ClubLastReview"
	Kit.etiquette(panneau, 24, 90, "Confiance du conseil", 500)
	var valeur := G.n(confiance) if confiance != null else "—"
	var chiffre := D.text(panneau, 24, 152, valeur, 66, Charte.IVOIRE, 800, 130)
	chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	chiffre.name = "ClubTrustValue"
	var largeur_chiffre := Charte.TITRE_EXTRA_ITALIQUE.get_string_size(valeur, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(66))).x / C.density
	Kit.texte(panneau, 24 + largeur_chiffre + 10, 150, "/ 100", Charte.IVOIRE_2, 80, 24)
	if not dernier.is_empty():
		var delta := int(dernier.after) - int(dernier.previous)
		var evolution := Kit.texte(panneau, largeur - 24, 150, "%s après J%s" % [_signe(delta), G.n(dernier.round)], Charte.IVOIRE, 400, 22, HORIZONTAL_ALIGNMENT_RIGHT)
		evolution.add_theme_font_override("font", Kit.texte_gras())
		evolution.name = "ClubTrustChange"
	var palier := _palier(confiance)
	if not palier.is_empty():
		_coche(panneau, Rect2(24, 168, 30, 30), palier.genre)
		var mot := Kit.titre(panneau, 64, 194, palier.mot, 30, 220)
		mot.name = "ClubTrustWord"
		Kit.texte(panneau, 64 + Charte.TITRE_GRAS_ITALIQUE.get_string_size(str(palier.mot).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(30))).x / C.density + 14, 194, "palier %d sur 3" % int(palier.rang), Charte.IVOIRE_2, 300, 18)
	_barre_seuils(panneau, 24, 214, largeur - 48, confiance, palier)
	D.line(panneau, Vector2(24, 306), Vector2(largeur - 24, 306), Charte.FILET)
	_objectif(panneau, app, board, 24, 322, 600)
	_bilans(panneau, app, historique, 664, 322, largeur - 664 - 24)

## Trois segments à l'échelle de 0 à 100 : Menacé (0-39), Fragile (40-69), Solide (70-100). Remplissage ivoire-2, repère incliné
## à la valeur ; chaque palier dit son nom et son seuil sous la barre (jamais la couleur seule).
static func _barre_seuils(panneau: Control, x: float, y: float, largeur: float, confiance: Variant, palier: Dictionary) -> void:
	var bornes := [[0, SEUIL_FRAGILE, "Menacé", "moins de %d" % SEUIL_FRAGILE, "croix", 3], [SEUIL_FRAGILE, SEUIL_SOLIDE, "Fragile", "de %d à %d" % [SEUIL_FRAGILE, SEUIL_SOLIDE - 1], "alerte", 2], [SEUIL_SOLIDE, 100, "Solide", "%d et plus" % SEUIL_SOLIDE, "ok", 1]]
	var ecart := 6.0
	var utile := largeur - ecart * 2.0
	var cursor := x
	var position_repere := -1.0
	for borne: Array in bornes:
		var part := utile * float(int(borne[1]) - int(borne[0])) / 100.0
		D.rect(panneau, Rect2(cursor, y, part, 14), Charte.PANNEAU_3, 0)
		if confiance != null and float(confiance) > float(borne[0]):
			var rempli := clampf((float(confiance) - float(borne[0])) / float(int(borne[1]) - int(borne[0])), 0.0, 1.0)
			D.rect(panneau, Rect2(cursor, y, part * rempli, 14), Charte.IVOIRE_2, 0)
			if rempli < 1.0 or int(borne[1]) == 100: position_repere = cursor + part * rempli
		var actif: bool = not palier.is_empty() and int(palier.rang) == int(borne[5])
		var couleur: Color = Charte.IVOIRE if actif else Charte.IVOIRE_2
		_coche(panneau, Rect2(cursor, y + 26, 20, 20), str(borne[4]), couleur)
		var nom := Kit.texte(panneau, cursor + 28, y + 42, str(borne[2]), couleur, 200, 18)
		nom.add_theme_font_override("font", Kit.texte_gras())
		Kit.texte(panneau, cursor, y + 66, str(borne[3]), Charte.IVOIRE_2, 300, 17)
		cursor += part + ecart
	if position_repere >= 0.0: Kit.marqueur(panneau, Rect2(position_repere - 3, y - 7, 6, 28), Charte.IVOIRE)

## Objectif de la saison : l'objectif du club, puis le classement, les promesses publiques et les jalons du conseil ;
## chaque ligne ouvre le suivi des objectifs.
static func _objectif(panneau: Panel, app: Control, board: Dictionary, x: float, y: float, largeur: float) -> void:
	var bloc := Control.new()
	bloc.name = "ClubObjectives"
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panneau.add_child(bloc)
	D.place(bloc, Rect2(x, y, largeur, 330))
	Kit.etiquette(bloc, 0, 22, "Objectif de la saison", largeur)
	var but := str(app.model.club.get("goal", "Projet sportif"))
	var titre := _texte_lignes(bloc, 0, 36, largeur, but, 28, Charte.TITRE_GRAS_ITALIQUE, Charte.IVOIRE, 2)
	titre.name = "ClubGoal"
	titre.tooltip_text = but
	var lignes: Array = []
	var metriques: Dictionary = board.get("metrics", {})
	var rang: Variant = metriques.get("rank", app.model.club.get("rank"))
	var jouees := int(app.model.club.get("played", 0))
	if P.standings_open(app.model.club) and rang != null:
		var place := "%s%s" % [G.n(rang), "er" if int(rang) == 1 else "e"]
		lignes.append({"genre": "ok", "texte": "En cours : %s après %s" % [place, P.plural(jouees, "journée", "journées")] if jouees > 0 else "En cours : %s" % place, "statut": ""})
	else:
		lignes.append({"genre": "neutre", "texte": "Pas encore de classement", "statut": ""})
	var promesses: Variant = app.model.get("clubLife", {}).get("pressPromises", {})
	var actives: Array = promesses.get("active", []) if promesses is Dictionary else []
	for i in mini(2, actives.size()):
		var promesse: Dictionary = actives[i]
		var avancement: Dictionary = promesse.get("progress", {})
		var suit: Variant = avancement.get("onTrack")
		lignes.append({"genre": "neutre" if suit == null else ("ok" if suit else "alerte"), "texte": str(promesse.get("short", "Promesse publique")), "detail": str(avancement.get("short", "")), "statut": "À suivre" if suit == null else ("En bonne voie" if suit else "En retard"), "promesse": i + 1, "bulle": "Promesse publique : " + str(promesse.get("label", "")) + "\n" + str(avancement.get("label", ""))})
	var objectifs: Array = board.get("objectives", [])
	for objectif: Dictionary in objectifs:
		if lignes.size() >= 5: break
		var genre := str(objectif.get("type", ""))
		var etat := str(objectif.get("status", "pending"))
		var cible: Variant = objectif.get("target")
		var chiffre := G.euros(cible) if genre == "cash" else G.n(cible)
		lignes.append({"genre": "ok" if etat == "met" else ("croix" if etat == "missed" else "neutre"), "texte": "%s : %s · sem. %s" % [GOALS.get(genre, "Jalon du conseil"), chiffre, G.n(objectif.get("deadline", "—"))], "statut": GOAL_STATUS.get(etat, etat)})
	var top := 118.0
	for i in lignes.size():
		var ligne: Dictionary = lignes[i]
		var rangee := Button.new()
		rangee.name = "ClubObjectiveRow%d" % i
		Kit.styler_ligne(rangee, Color.TRANSPARENT)
		rangee.accessibility_name = str(ligne.texte)
		rangee.pressed.connect(func(): _open_strategy(app, 1))
		bloc.add_child(rangee)
		D.place(rangee, Rect2(0, top + i * LIGNE, largeur, LIGNE))
		_coche(rangee, Rect2(4, 6, 20, 20), str(ligne.genre) if str(ligne.genre) != "neutre" else "neutre", Charte.IVOIRE if str(ligne.genre) != "neutre" else Charte.IVOIRE_2)
		var texte := Kit.texte(rangee, 36, 22, str(ligne.texte), Charte.IVOIRE, largeur - 36 - (130 if not str(ligne.statut).is_empty() else 0), 18)
		if ligne.has("promesse"):
			texte.name = "ClubPromise%d" % int(ligne.promesse)
			texte.tooltip_text = str(ligne.get("bulle", ""))
			texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not str(ligne.statut).is_empty(): Kit.texte(rangee, largeur - 6, 22, str(ligne.statut), Charte.IVOIRE_2, 124, 17, HORIZONTAL_ALIGNMENT_RIGHT)
	var suivre := Kit.lien(bloc, Rect2(0, top + 5 * LIGNE + 14, 0, 36), "Suivre les objectifs →", func(): _open_strategy(app, 1), "ClubBoardGoals", 19)
	suivre.tooltip_text = ""

## Ce qui a fait bouger la confiance : un bilan du conseil par ligne (journée, confiance après le bilan, évolution, résultat du match
## de la journée, cause). Une ligne ouvre le match quand il est connu, sinon les objectifs du conseil.
static func _bilans(panneau: Panel, app: Control, historique: Array, x: float, y: float, largeur: float) -> void:
	var bloc := Control.new()
	bloc.name = "ClubTrustTable"
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panneau.add_child(bloc)
	D.place(bloc, Rect2(x, y, largeur, 320))
	Kit.etiquette(bloc, 0, 22, "Ce qui a fait bouger la confiance", largeur)
	if historique.is_empty():
		Kit.texte(bloc, 0, 96, "—", Charte.IVOIRE_2, largeur, 34).name = "ClubTrustTableEmpty"
		return
	var colonnes := [["J.", 8.0, 50.0, false], ["Conf.", 70.0, 62.0, true], ["Évol.", 142.0, 60.0, true], ["Rés.", 224.0, 70.0, false], ["Cause", 310.0, largeur - 310.0, false]]
	for colonne: Array in colonnes:
		Kit.etiquette(bloc, float(colonne[1]) + (float(colonne[2]) if colonne[3] else 0.0), 60, str(colonne[0]), float(colonne[2]), colonne[3])
	D.line(bloc, Vector2(0, 70), Vector2(largeur, 70), Charte.FILET)
	var saison := int(app.model.get("meta", {}).get("season", 1))
	var club_id: Variant = app.model.club.id
	for i in mini(7, historique.size()):
		var bilan: Dictionary = historique[i]
		var rencontre := _rencontre_du_bilan(app, bilan, saison)
		var haut := 74.0 + i * LIGNE
		var rangee := Button.new()
		rangee.name = "ClubTrustRow%d" % i
		Kit.styler_ligne(rangee, Color.TRANSPARENT)
		bloc.add_child(rangee)
		D.place(rangee, Rect2(0, haut, largeur, LIGNE))
		# Charte : pas de bandes alternées, un filet entre deux lignes.
		if i > 0: D.line(bloc, Vector2(0, haut), Vector2(largeur, haut), Charte.FILET)
		var delta := int(bilan.after) - int(bilan.previous)
		Kit.texte(rangee, 8, 22, "J%s" % G.n(bilan.round), Charte.IVOIRE_2, 50, 18)
		var conf := Kit.texte(rangee, 132, 22, G.n(bilan.after), Charte.IVOIRE, 62, 18, HORIZONTAL_ALIGNMENT_RIGHT)
		conf.add_theme_font_override("font", Kit.texte_gras())
		Kit.texte(rangee, 202, 22, _signe(delta), Charte.IVOIRE_2, 60, 18, HORIZONTAL_ALIGNMENT_RIGHT)
		var cause := "Bilan du conseil · résultats %s, finances %s, formation %s" % [G.n(bilan.get("results", "—")), G.n(bilan.get("finances", "—")), G.n(bilan.get("youth", "—"))]
		var lettre := "—"
		if not rencontre.is_empty():
			var resume := _resume_rencontre(rencontre, club_id)
			lettre = str(resume.lettre)
			cause = str(resume.texte)
		if lettre == "—": Kit.texte(rangee, 258, 22, "—", Charte.IVOIRE_3, 40, 18, HORIZONTAL_ALIGNMENT_CENTER)
		else: _ovale_resultat(rangee, Rect2(232, 4, 52, 24), lettre)
		Kit.texte(rangee, 310, 22, cause, Charte.IVOIRE, largeur - 316, 18).tooltip_text = cause
		var cible: Dictionary = {}
		if not rencontre.is_empty():
			var office: Variant = load("res://ui/immersive08/office.gd")
			cible = office.score_reading_target(app, rencontre)
		var libelle := "Bilan du conseil, journée %s" % G.n(bilan.round)
		if not cible.is_empty(): EntityLink.bind(rangee, app, cible, cause)
		else:
			rangee.accessibility_name = libelle
			rangee.pressed.connect(func(): _open_strategy(app, 1))
	var plus := Kit.lien(bloc, Rect2(0, 74 + 7 * LIGNE + 12, 0, 34), "Tous les bilans du conseil →", func(): _open_strategy(app, 1), "ClubTrustAll", 18)
	plus.tooltip_text = ""

static func _rencontre_du_bilan(app: Control, bilan: Dictionary, saison: int) -> Dictionary:
	if int(bilan.get("season", saison)) != saison: return {}
	var etiquette := "Journée %d" % int(bilan.get("round", -1))
	for rencontre: Variant in app.model.get("calendar", []):
		if not rencontre is Dictionary or not rencontre.get("played", false): continue
		if str(rencontre.get("label", "")) != etiquette: continue
		if rencontre.get("score") is Array and rencontre.score.size() == 2: return rencontre
	return {}

## {lettre : V / N / D, texte : « Victoire 21-18 contre X » (ou « à X » à l'extérieur)} du point de vue du club.
static func _resume_rencontre(rencontre: Dictionary, club_id: Variant) -> Dictionary:
	var cote := 0 if rencontre.get("home", {}).get("id") == club_id else 1
	var adversaire: Dictionary = rencontre.away if cote == 0 else rencontre.home
	var score: Array = rencontre.score
	var lettre := "N"
	var mot := "Nul"
	var vainqueur: Variant = rencontre.get("winner")
	if score[cote] != score[1 - cote] or vainqueur != null:
		var gagne: bool = (vainqueur == club_id) if score[cote] == score[1 - cote] else score[cote] > score[1 - cote]
		lettre = "V" if gagne else "D"
		mot = "Victoire" if gagne else "Défaite"
	var lieu := "à " if P.fixture_location_kind(rencontre, club_id) == "away" else "contre "
	return {"lettre": lettre, "texte": "%s %s-%s %s%s" % [mot, G.n(score[cote]), G.n(score[1 - cote]), lieu, G.club_name(adversaire)]}

## Ovale V / N / D (charte §3) : plein pour une victoire, anneau pour le reste ; la lettre dit toujours le résultat.
static func _ovale_resultat(parent: Control, zone: Rect2, lettre: String) -> void:
	var forme := Kit.Ovale.new()
	forme.numero = lettre
	forme.police = Kit.texte_gras()
	forme.plein = lettre == "V"
	forme.fond = Charte.V
	forme.bordure = Charte.V if lettre == "V" else (Charte.D if lettre == "D" else Charte.IVOIRE_2)
	forme.texte = Charte.NUIT if lettre == "V" else forme.bordure
	forme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(forme)
	D.place(forme, zone)

# --- Installations -------------------------------------------------------------------------------------------------------

static func _segments(parent: Control, x: float, y: float, largeur: float, total: int, rempli: int) -> void:
	var ecart := 3.0
	var part := (largeur - ecart * (total - 1)) / total
	for i in total: D.rect(parent, Rect2(x + i * (part + ecart), y, part, 10), Charte.IVOIRE_2 if i < rempli else Charte.PANNEAU_3, 0)

static func _installations(panneau: Panel, app: Control, finance: Dictionary, strategie: Dictionary) -> void:
	var largeur := panneau.size.x / C.density
	for colonne: Array in [["Installation", 24.0, 400.0, false], ["Niveau", 470.0, 300.0, false], ["Prochaine amélioration", 800.0, 230.0, false], ["Coût", 1030.0, 130.0, true], ["Statut", 1194.0, 196.0, false]]:
		Kit.etiquette(panneau, float(colonne[1]) + (float(colonne[2]) if colonne[3] else 0.0), 82, str(colonne[0]), float(colonne[2]), colonne[3])
	D.line(panneau, Vector2(18, 92), Vector2(largeur - 18, 92), Charte.FILET)
	var devis: Variant = finance.get("facility")
	var academie: Variant = app.model.get("clubLife", {}).get("academyPathways", {}).get("facilities")
	var suivi: Dictionary = app.model.get("clubLife", {}).get("academyFollowUp", {})
	var centre_ouvert: bool = suivi.get("available", false) == true
	var soutien: Dictionary = app.model.get("clubLife", {}).get("clubSupport", {})
	var medical: Array = soutien.get("medical", {}).get("players", [])
	var fans: Dictionary = strategie.get("fans", {})
	var rangees: Array = []
	var statut := ""
	if devis is Dictionary:
		if devis.get("used", false): statut = "Fait cette saison"
		elif not devis.get("affordable", true): statut = "Trésorerie insuffisante"
		elif not strategie.get("available", false): statut = "Indisponible en ce moment"
		else: statut = "Devis disponible"
	rangees.append({"id": "ClubFacilityTraining", "nom": "Centre d’entraînement", "niveau": "%s / 10" % G.n(devis.level) if devis is Dictionary else "Niveau indisponible", "segments": [10, int(devis.level)] if devis is Dictionary else [], "suite": "Niveau %s" % G.n(devis.nextLevel) if devis is Dictionary else "—", "cout": G.euros(devis.cost) if devis is Dictionary else "", "statut": statut, "action": func(): _tab(app, "infrastructure", "ClubTab_infrastructure")})
	rangees.append({"id": "ClubFacilityMedical", "nom": "Cellule médicale", "niveau": "%s suivi%s" % [G.n(medical.size()), "s" if medical.size() > 1 else ""] if not soutien.is_empty() else "—", "segments": [], "suite": "Retour des blessés", "cout": "", "statut": "", "action": func(): app._navigate("Travail du club")})
	var academie_niveau := G.n(academie) + " / 3" if academie != null else "Niveau indisponible"
	var academie_suite := "Installations du centre"
	if academie == null and centre_ouvert:
		academie_niveau = "%s / %s" % [G.n(suivi.get("total", 0)), G.n(suivi.get("capacity", 75))]
		academie_suite = "%s Crabos · %s Espoirs" % [G.n(suivi.get("crabos", {}).get("count", 0)), G.n(suivi.get("espoirs", {}).get("count", 0))]
	rangees.append({"id": "ClubFacilityAcademy", "nom": "Académie", "niveau": academie_niveau, "segments": [3, int(academie)] if academie != null else [], "suite": academie_suite, "cout": "", "statut": "", "action": func(): app._navigate("Centre")})
	rangees.append({"id": "ClubFacilityStadium", "nom": str(G.identity(app.model.club).get("stadium", "Le stade")), "niveau": G.n(fans.capacity) + " places" if fans.has("capacity") else "—", "segments": [], "suite": "Affluence prévue " + G.n(fans.expectedAttendance) if fans.has("expectedAttendance") else "Photo, ville et crédits", "cout": "", "statut": "", "action": func(): _tab(app, "territory", "ClubTab_overview")})
	for i in rangees.size():
		var donnees: Dictionary = rangees[i]
		var rangee := Button.new()
		rangee.name = str(donnees.id)
		Kit.styler_ligne(rangee, Color.TRANSPARENT)
		rangee.accessibility_name = str(donnees.nom)
		rangee.pressed.connect(donnees.action)
		panneau.add_child(rangee)
		D.place(rangee, Rect2(18, 98 + i * 40, largeur - 36, 40))
		# Charte : pas de bandes alternées, un filet entre deux lignes.
		if i > 0: D.line(panneau, Vector2(18, 98 + i * 40), Vector2(largeur - 18, 98 + i * 40), Charte.FILET)
		var nom := Kit.texte(rangee, 6, 27, str(donnees.nom), Charte.IVOIRE, 400, 19)
		nom.add_theme_font_override("font", Kit.texte_gras())
		var segments: Array = donnees.segments
		if segments.is_empty(): Kit.texte(rangee, 452, 27, str(donnees.niveau), Charte.IVOIRE, 320, 18)
		else:
			_segments(rangee, 452, 15, 150, int(segments[0]), int(segments[1]))
			Kit.texte(rangee, 770, 27, str(donnees.niveau), Charte.IVOIRE, 90, 18, HORIZONTAL_ALIGNMENT_RIGHT).name = "ClubFacilityLevel"
		Kit.texte(rangee, 782, 27, str(donnees.suite), Charte.IVOIRE_2, 270, 18)
		if not str(donnees.cout).is_empty(): Kit.texte(rangee, 1142, 27, str(donnees.cout), Charte.IVOIRE, 130, 18, HORIZONTAL_ALIGNMENT_RIGHT)
		if not str(donnees.statut).is_empty(): Kit.texte(rangee, 1176, 27, str(donnees.statut), Charte.IVOIRE_2, 190, 17)
	var details := Kit.lien(panneau, Rect2(24, 270, 0, 34), "Projets et devis des installations →", func(): _tab(app, "infrastructure", "ClubTab_infrastructure"), "ClubFacilityDetails", 19)
	details.tooltip_text = ""

# --- À décider -----------------------------------------------------------------------------------------------------------

static func _decider(panneau: Panel, app: Control, finance: Dictionary, board: Dictionary, strategie: Dictionary) -> void:
	var largeur := panneau.size.x / C.density
	var elements: Array = []
	var en_attente: Array = board.get("objectives", []).filter(func(objectif: Dictionary): return objectif.get("status") == "pending")
	en_attente.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("deadline", 0)) < int(b.get("deadline", 0)))
	if en_attente.is_empty():
		elements.append({"id": "ClubFixMilestone", "genre": "alerte", "titre": "Aucune échéance fixée avec le conseil.", "detail": "", "bulle": "Fixe-en une : il en tiendra compte au bilan de fin de saison.", "action": "Fixer un jalon", "ouvrir": func(): _open_strategy(app, 1)})
	else:
		var jalon: Dictionary = en_attente[0]
		elements.append({"id": "ClubNextMilestone", "genre": "neutre", "titre": "Prochain jalon : %s" % str(GOALS.get(str(jalon.get("type", "")), "jalon du conseil")).to_lower(), "detail": "", "pastille": ["Sem. %s" % G.n(jalon.get("deadline", "—")), "flag", Pastilles.TURQUOISE, func(): _open_strategy(app, 1)], "action": "Suivre les objectifs", "ouvrir": func(): _open_strategy(app, 1)})
	var devis: Variant = finance.get("facility")
	if devis is Dictionary and not devis.get("used", false):
		var tuile_devis := [Pastilles.euros_courts(devis.cost), "1 par saison"]
		var pastille_devis: Array = []
		if not devis.get("affordable", true): pastille_devis = ["Trésorerie insuffisante", "warning", Pastilles.ORANGE, func(): app._navigate("Finances")]
		elements.append({"id": "ClubQuoteLink", "genre": "alerte", "titre": "Devis du centre d’entraînement, niveau %s" % G.n(devis.nextLevel), "detail": "", "tuile": tuile_devis, "pastille": pastille_devis, "bulle": "%s · une amélioration par saison" % G.euros(devis.cost), "action": "Voir le devis", "ouvrir": func(): _tab(app, "infrastructure", "ClubTab_infrastructure")})
	if strategie.get("available", false):
		elements.append({"id": "ClubBoardRequest", "genre": "alerte", "titre": "Demande à la direction possible.", "detail": "", "action": "Présenter la demande", "ouvrir": func(): _open_strategy(app, 1)})
	Kit.texte(panneau, largeur - 24, 40, str(elements.size()), Charte.IVOIRE_2, 60, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	D.line(panneau, Vector2(18, 56), Vector2(largeur - 18, 56), Charte.FILET)
	for i in mini(3, elements.size()):
		var element: Dictionary = elements[i]
		var haut := 66.0 + i * 86.0
		var cadre := D.rect(panneau, Rect2(18, haut, largeur - 36, 78), Charte.PANNEAU_2 if i == 0 else Color.TRANSPARENT, 16)
		cadre.name = "ClubDecideRow%d" % i
		_coche(panneau, Rect2(30, haut + 14, 26, 26), str(element.genre), Charte.IVOIRE)
		# Titre et détail sur une ligne chacun (texte complet en infobulle) : jamais de chevauchement, à 1280 comme à 1920.
		var a_detail: bool = element.has("tuile") or not (element.get("pastille", []) as Array).is_empty()
		var titre := _texte_lignes(panneau, 72, haut + (10 if a_detail else 26), 470, str(element.titre), 19, Kit.texte_gras(), Charte.IVOIRE, 1)
		titre.name = "ClubDecideTitle%d" % i
		titre.tooltip_text = str(element.titre)
		titre.mouse_filter = Control.MOUSE_FILTER_PASS
		titre.tooltip_text = str(element.get("bulle", element.titre))
		var x_detail := 72.0
		if element.has("tuile"):
			var tuile := Pastilles.tuile(str(element.tuile[0]), str(element.tuile[1]), Pastilles.ORANGE, Charte.PANNEAU_3 if i == 0 else Charte.PANNEAU_2, 22, "ClubDecideTile%d" % i, true, element.ouvrir)
			x_detail += Pastilles.poser(panneau, tuile, x_detail, haut + 38) + 8.0
		var pastille: Array = element.get("pastille", [])
		if not pastille.is_empty():
			var badge := Pastilles.pastille(str(pastille[0]), pastille[2], str(pastille[1]), "", 17, "ClubDecideBadge%d" % i, pastille[3])
			Pastilles.poser(panneau, badge, x_detail, haut + 42)
		if i == 0:
			Kit.bouton_ivoire(panneau, Rect2(largeur - 30 - 250, haut + 16, 250, 46), str(element.action), element.ouvrir, str(element.id))
		else:
			var lien := Kit.lien(panneau, Rect2(largeur - 30, haut + 22, 0, 34), str(element.action) + " →", element.ouvrir, str(element.id), 18, true)
			lien.tooltip_text = ""
	if elements.is_empty(): Kit.texte(panneau, 24, 100, "Rien à trancher cette semaine.", Charte.IVOIRE, 600, 20).name = "ClubDecideNone"
	D.line(panneau, Vector2(18, 330), Vector2(largeur - 18, 330), Charte.FILET)
	_footer(panneau, app, finance, board)

## Trésorerie et salaires : deux liens vers Finances (valeurs du moteur ; texte simple si la navigation est indisponible).
static func _footer(card: Panel, app: Control, finance: Dictionary, _board: Dictionary) -> void:
	var cash: Variant = finance.get("cash", app.model.get("club", {}).get("cash"))
	var largeur := card.size.x / C.density
	var texte_cash := "Trésorerie · " + U.amount(cash) + " →"
	var etiquette := Kit.texte(card, 30, 372, texte_cash, Charte.D if cash != null and float(cash) < 0.0 else Charte.IVOIRE, 500, 19)
	etiquette.add_theme_font_override("font", Kit.texte_gras())
	_reading_area(app, card, Rect2(24, 346, 520, 40), {"kind": "finance", "id": "cash"}, "ClubCashLink", "Trésorerie")
	var salaires := "Salaires et cotisations · %s par semaine →" % G.euros(P.payroll(app.model).charge_weekly)
	var etiquette_salaires := Kit.texte(card, 30, 410, salaires, Charte.IVOIRE, 760, 19)
	etiquette_salaires.add_theme_font_override("font", Kit.texte_gras())
	_reading_area(app, card, Rect2(24, 384, largeur - 48, 40), {"kind": "finance", "id": "wages"}, "ClubWagesLink", "Salaires")

# --- Vestiaire -----------------------------------------------------------------------------------------------------------

static func _vestiaire(panneau: Panel, app: Control) -> void:
	var largeur := panneau.size.x / C.density
	var lien := Kit.lien(panneau, Rect2(largeur - 24, 12, 0, 34), "Entrer au vestiaire →", func(): app._navigate("Vestiaire"), "ClubLockerAction", 18, true)
	lien.tooltip_text = ""
	var squad: Array = app.model.get("squad", [])
	var blesses := 0
	var suspendus := 0
	var selection := 0
	var absents: Array = []
	for joueur: Variant in squad:
		if not joueur is Dictionary: continue
		match Etat.indisponibilite(joueur):
			"blesse":
				blesses += 1
				absents.append(joueur)
			"suspendu":
				suspendus += 1
				absents.append(joueur)
			"selection":
				selection += 1
				absents.append(joueur)
	var details: Array[String] = []
	if blesses > 0: details.append(P.plural(blesses, "blessé", "blessés"))
	if suspendus > 0: details.append(P.plural(suspendus, "suspendu", "suspendus"))
	if selection > 0: details.append("%d en sélection" % selection)
	var moral: Variant = app.model.meta.get("morale")
	var cote := (largeur - 48.0 - 24.0) / 3.0
	var tuiles := [
		{"id": "ClubMorale", "etiquette": "Moral", "valeur": G.n(moral) if moral != null else "—", "sur": "/ 100", "barre": float(moral) if moral != null else -1.0, "suite": ""},
		{"id": "ClubAvailable", "etiquette": "Disponibles", "valeur": str(squad.size() - absents.size()), "sur": "/ %d" % squad.size(), "barre": -1.0, "suite": " · ".join(details) if not details.is_empty() else "Aucun absent"},
	]
	for i in tuiles.size():
		var tuile: Dictionary = tuiles[i]
		var bouton := Button.new()
		bouton.name = str(tuile.id)
		Kit.styler_ligne(bouton, Charte.PANNEAU_2)
		# Tuile de chiffre = carte rayon 12 px (16 en référence 2560, charte §3).
		for etat in ["normal", "hover", "pressed", "disabled", "focus"]:
			var fond := bouton.get_theme_stylebox(etat) as StyleBoxFlat
			if fond == null: continue
			fond.set_corner_radius_all(maxi(3, C.px(16)))
			Charte.ombrer(fond, 16)
		bouton.accessibility_name = "%s · %s %s · vestiaire" % [tuile.etiquette, tuile.valeur, tuile.sur]
		bouton.pressed.connect(func(): app._navigate("Vestiaire"))
		panneau.add_child(bouton)
		D.place(bouton, Rect2(24 + i * (cote + 12), 66, cote, 150))
		Kit.etiquette(bouton, 14, 30, str(tuile.etiquette), cote - 28)
		var chiffre := D.text(bouton, 14, 88, str(tuile.valeur), 46, Charte.IVOIRE, 800, 120)
		chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		var largeur_chiffre := Charte.TITRE_EXTRA_ITALIQUE.get_string_size(str(tuile.valeur), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(46))).x / C.density
		Kit.texte(bouton, 14 + largeur_chiffre + 8, 86, str(tuile.sur), Charte.IVOIRE_2, 80, 19)
		if float(tuile.barre) >= 0.0:
			D.rect(bouton, Rect2(14, 104, cote - 28, 8), Charte.PANNEAU_3, Charte.RAYON_PILULE)
			D.rect(bouton, Rect2(14, 104, (cote - 28) * clampf(float(tuile.barre) / 100.0, 0.0, 1.0), 8), Charte.IVOIRE_2, Charte.RAYON_PILULE)
		if not str(tuile.suite).is_empty(): _texte_lignes(bouton, 14, 112, cote - 28, str(tuile.suite), 16, Charte.TEXTE, Charte.IVOIRE_2, 2).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Leader du vestiaire : le nom ouvre la fiche, le survol la mini-fiche.
	var relation: Dictionary = app.model.get("clubLife", {}).get("relationships", {})
	var chef := P.player(app.model, str(relation.get("leaderId", "")))
	var tuile_chef := D.rect(panneau, Rect2(24 + 2 * (cote + 12), 66, cote, 150), Charte.PANNEAU_2, 16)
	tuile_chef.name = "ClubLeader"
	tuile_chef.mouse_filter = Control.MOUSE_FILTER_PASS
	Kit.etiquette(tuile_chef, 14, 30, "Leader", cote - 28)
	if chef.is_empty(): Kit.texte(tuile_chef, 14, 80, "À déterminer", Charte.IVOIRE_2, cote - 28, 20)
	else:
		var nom := Kit.nom(app, tuile_chef, Rect2(10, 48, cote - 20, 40), Kit.casse(str(chef.get("name", ""))), str(chef.get("id", "")), "ClubLeaderLink", Charte.IVOIRE, 24)
		nom.accessibility_name = str(chef.get("name", "")) + " · leader du vestiaire"
		Kit.texte(tuile_chef, 14, 112, "capitaine · %s" % str(chef.get("pos", "")) if not str(chef.get("pos", "")).is_empty() else "capitaine", Charte.IVOIRE_2, cote - 28, 17)
	Kit.etiquette(panneau, 24, 254, "Absents", 300)
	D.line(panneau, Vector2(18, 262), Vector2(largeur - 18, 262), Charte.FILET)
	absents.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("injury", 0)) > float(b.get("injury", 0)))
	var maximum := 8
	if absents.is_empty(): Kit.texte(panneau, 24, 300, "Aucun joueur absent cette semaine.", Charte.IVOIRE_2, 600, 19).name = "ClubAbsentNone"
	for i in mini(maximum, absents.size()):
		var joueur: Dictionary = absents[i]
		var haut := 266.0 + i * LIGNE
		if i > 0: D.line(panneau, Vector2(18, haut), Vector2(largeur - 18, haut), Charte.FILET)
		Kit.nom(app, panneau, Rect2(24, haut + 3, 330, LIGNE - 6), Kit.casse(str(joueur.get("name", ""))), str(joueur.get("id", "")), "ClubAbsentName%d" % i, Charte.IVOIRE, 18)
		Kit.texte(panneau, largeur - 24, haut + 22, _statut_absent(joueur), Charte.IVOIRE_2, largeur - 400, 17, HORIZONTAL_ALIGNMENT_RIGHT)
	if absents.size() > maximum:
		var reste := Kit.lien(panneau, Rect2(24, 266 + maximum * LIGNE + 10, 0, 34), "+ %d autres absents → vestiaire" % (absents.size() - maximum), func(): app._navigate("Vestiaire"), "ClubAbsentMore", 18)
		reste.tooltip_text = ""

static func _statut_absent(joueur: Dictionary) -> String:
	match Etat.indisponibilite(joueur):
		"blesse":
			var semaines := ceili(float(joueur.get("injury", 0)))
			return "Blessé · retour dans %s" % P.plural(semaines, "semaine", "semaines")
		"suspendu":
			return "Suspendu · %s" % P.plural(int(joueur.get("suspension", 1)), "match", "matchs")
		"selection": return "En sélection"
	return ""

# --- Onglets autres que la vue d'ensemble (dessinés depuis y = 214, remontés par le corps de la page) --------------------

static func _academy(model: Dictionary) -> Dictionary:
	return model.get("clubLife", {}).get("academyPathways", {})

static func _lien(parent: Control, zone: Rect2, texte: String, action: Callable, id: String, taille: int = 19) -> Button:
	var bouton := Kit.lien(parent, zone, texte, action, id, taille)
	bouton.tooltip_text = ""
	return bouton

static func _direction(app: Control, corps: Control) -> void:
	_lien(corps, Rect2(0, 220, 0, 34), "Ouvrir les finances →", func(): app._navigate("Finances"), "ClubDirectionFinance")
	var detail: Control = app.StrategyViews.build(app)
	var tabs: TabContainer = detail.find_child("StrategyTabs", true, false)
	if tabs != null:
		tabs.current_tab = clampi(int(app.management_ui.get("immersive08_strategy_tab", 1)), 0, 2)
		tabs.tab_changed.connect(func(index: int): app.management_ui.immersive08_strategy_tab = index)
	U.place_detail(corps, Rect2(0, 262, W, 960), detail)
	Legacy.apply(detail, app.accent)
	Habillage._charte(detail)
	Habillage._suivre_ajouts(detail)

static func _venue_caption(picture: Control) -> String:
	match picture.get_meta("photo_kind", ""):
		# Immersion : le crédit, jamais la provenance (pack, archive).
		"pack", "archive": return "Crédit photo"
		_: return "Vue du club"

static func _venue_credit(control: Control, photo: Dictionary) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.tooltip_text = "%s\nSource : %s\nLicence : %s" % [photo.get("credit", ""), photo.get("source", ""), photo.get("license", "")]
	control.accessibility_name = control.tooltip_text

static func _members(app: Control) -> Array:
	for team: Dictionary in app.model.get("staff", {}).get("teams", []):
		if int(team.get("id",-1)) == int(app.model.club.id): return team.get("members", [])
	return []

## Onglet Staff, colonne de gauche (DA du 20/11/2026, sans cadre ni numéro) : les responsables (visage, rôle, nom :
## clic = fiche du membre), le diagnostic de la semaine, puis contrats et engagements (chaque ligne mène quelque part).
const STAFF_GAUCHE := 540.0

static func _staff(card: Control, app: Control) -> void:
	var people := _members(app)
	var largeur := STAFF_GAUCHE
	var montres := 4
	for i in mini(montres, people.size()):
		var person: Dictionary = people[i]
		var y := 70.0 + i * 68.0
		if i > 0: D.line(card, Vector2(12, y), Vector2(largeur - 12, y), Charte.FILET)
		var visage := person.duplicate(true)
		visage.portraitRole = "staff"
		var portrait := G.portrait_lazy(0, C.px(52), visage)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)
		D.place(portrait, Rect2(20, y + 6, 48, 54))
		Kit.texte(card, 84, y + 26, str(person.get("roleLabel", person.get("role", "Encadrement"))), Charte.IVOIRE_2, largeur - 108, 16)
		var nom := Kit.texte(card, 84, y + 54, Kit.casse(str(person.get("name", "—"))), Charte.IVOIRE, largeur - 300, 19)
		nom.add_theme_font_override("font", Kit.texte_gras())
		if person.get("contractEnd") != null: Kit.texte(card, largeur - 24, y + 54, "fin " + G.season_label(person.contractEnd), Charte.IVOIRE_2, 200, 16, HORIZONTAL_ALIGNMENT_RIGHT)
		var staff_id := str(person.get("id", ""))
		var target := {"kind": "staff", "id": staff_id}
		_reading_area(app, card, Rect2(16, y + 4, 56, 58), target, "ClubStaffPortrait_" + staff_id.validate_node_name(), str(person.get("name", "")))
		_reading_area(app, card, Rect2(80, y + 34, largeur - 300, 28), target, "ClubStaffName_" + staff_id.validate_node_name(), str(person.get("name", "")))
	if people.is_empty():
		Kit.texte(card, 24, 100, "Annuaire indisponible pour cette carrière.", Charte.IVOIRE, largeur - 48, 19).name = "ClubStaffNone"
		Kit.texte(card, 24, 128, "Les responsabilités du staff restent accessibles.", Charte.IVOIRE_2, largeur - 48, 17)
	elif people.size() > montres:
		Kit.texte(card, 24, 70 + montres * 68 + 32, "+ %d autres membres dans le tableau" % (people.size() - montres), Charte.IVOIRE_2, largeur - 48, 17).name = "ClubStaffMore"

## Le compact (shell.gd) habille la page Staff : elle porte déjà ses styles de la charte ; seul le thème par défaut suit.
static func style_staff(detail: Control, accent: Color) -> void:
	if detail == null: return
	detail.theme = Legacy.theme(accent)

## Diagnostic de la semaine : trois valeurs du travail du club, le signe « ! » double toujours la couleur d'alerte.
static func _staff_diagnostic(card: Control, app: Control) -> void:
	var diagnostic: Dictionary = app.model.get("clubLife", {}).get("clubSupport", {}).get("diagnostic", {})
	var largeur := STAFF_GAUCHE
	if diagnostic.is_empty():
		Kit.texte(card, 24, 96, "Diagnostic indisponible dans cette carrière.", Charte.IVOIRE_2, largeur - 48, 18).name = "ClubStaffDiagnosticNone"
	else:
		var fatigue: Variant = diagnostic.get("fatigue")
		var alerte: bool = (fatigue is int or fatigue is float) and float(fatigue) > 0
		var ecrire := func(valeur: Variant) -> String: return G.n(valeur) if valeur is int or valeur is float else ("—" if valeur == null else str(valeur))
		var rows := [["Condition moyenne", ecrire.call(diagnostic.get("mean")), false], ["Moral du groupe", ecrire.call(diagnostic.get("morale")), false], ["Joueurs sous 65 de condition", ("! " if alerte else "") + ecrire.call(fatigue), alerte]]
		# Constat du staff : un compte « sous 85 » plutôt qu'une phrase (la phrase reste en info-bulle de la ligne).
		var fatigues: Variant = diagnostic.get("tired")
		if fatigues is int or fatigues is float:
			rows.append(["Joueurs sous 85 de condition", ("! " if float(fatigues) > 0 else "") + ecrire.call(fatigues), float(fatigues) > 0])
		for i in rows.size():
			var y := 70.0 + i * 34.0
			var ligne := Button.new()
			ligne.name = "ClubStaffDiagnosticRow%d" % i
			StaffTable.styler_rangee(ligne)
			ligne.accessibility_name = "%s · %s · travail du club" % [rows[i][0], rows[i][1]]
			ligne.pressed.connect(func(): app._navigate("Travail du club"))
			if i == 3: ligne.tooltip_text = str(diagnostic.get("reason", ""))
			card.add_child(ligne)
			D.place(ligne, Rect2(12, y, largeur - 24, 34))
			Kit.texte(ligne, 12, 23, str(rows[i][0]), Charte.IVOIRE, 360, 18)
			var valeur := Kit.texte(ligne, largeur - 36, 23, str(rows[i][1]), Charte.PERTE if rows[i][2] else Charte.IVOIRE, 120, 18, HORIZONTAL_ALIGNMENT_RIGHT)
			valeur.add_theme_font_override("font", Kit.texte_gras())
		var raison := str(diagnostic.get("reason", ""))
		if rows.size() < 4 and not raison.is_empty(): _texte_lignes(card, 24, 180, largeur - 48, raison, 16, Charte.TEXTE, Charte.IVOIRE_2, 2).name = "ClubStaffDiagnosticReason"
	_lien(card, Rect2(18, 258, 0, 34), "Travail du club →", func(): app._navigate("Travail du club"), "ClubStaffWork", 18)

## Contrats et engagements : chaque ligne ouvre la sous-page ou le tableau qui la détaille.
static func _staff_contrats(card: Control, app: Control) -> void:
	var largeur := STAFF_GAUCHE
	var people := _members(app)
	var saison := int(app.model.get("meta", {}).get("season", 0))
	var fin_saison := people.filter(func(p: Dictionary): return p.get("contractEnd") != null and int(p.contractEnd) <= saison).size()
	var vie: Dictionary = app.model.get("clubLife", {})
	var carriere: Dictionary = vie.get("staffCareer", {})
	var mentorat: Dictionary = vie.get("staffMentoring", {})
	var emploi: Dictionary = vie.get("staffEmployment", {})
	var lecture: Dictionary = app.StaffViews.reading(app)
	var vers_tableau := func(onglet: int):
		lecture.navigation_id = ""
		lecture.tab = onglet; lecture.page = 0; lecture.search = ""; lecture.scroll = 0
		app.management_ui.erase("club_page")
		if app.route != "Staff": app._navigate("Staff")
		else: app._render()
	var lignes: Array = [{"id": "ClubStaffCount", "texte": "Membres en poste", "valeur": G.n(people.size()), "action": vers_tableau.bind(0)}]
	if fin_saison > 0 or not people.is_empty(): lignes.append({"id": "ClubStaffContractsEnding", "texte": "Contrats finissant cette saison", "valeur": G.n(fin_saison), "action": vers_tableau.bind(0)})
	if carriere.get("active", false): lignes.append({"id": "ClubStaffCandidates", "texte": "Candidats disponibles", "valeur": G.n(carriere.get("candidates", []).size()), "action": vers_tableau.bind(1)})
	if mentorat.get("available", false):
		var duos: int = mentorat.get("assignments", []).size()
		lignes.append({"id": "ClubStaffMentoring", "texte": "Mentorat des jeunes", "valeur": "aucun duo" if duos == 0 else "%d duo%s" % [duos, "s" if duos > 1 else ""], "action": func(): Pages.ouvrir(app, "mentorat")})
	if emploi.get("enabled", false): lignes.append({"id": "ClubStaffBudget", "texte": "Budget du staff", "valeur": G.salary(emploi.get("weeklyWages", 0)), "action": func(): Pages.ouvrir(app, "engagements")})
	for i in mini(5, lignes.size()):
		var donnees: Dictionary = lignes[i]
		var ligne := Button.new()
		ligne.name = str(donnees.id)
		StaffTable.styler_rangee(ligne)
		ligne.accessibility_name = "%s · %s" % [donnees.texte, donnees.valeur]
		ligne.pressed.connect(donnees.action)
		card.add_child(ligne)
		D.place(ligne, Rect2(12, 70.0 + i * 34.0, largeur - 24, 34))
		Kit.texte(ligne, 12, 23, str(donnees.texte), Charte.IVOIRE, 330, 18)
		var valeur := Kit.texte(ligne, largeur - 36, 23, str(donnees.valeur) + " →", Charte.IVOIRE, 160, 18, HORIZONTAL_ALIGNMENT_RIGHT)
		valeur.add_theme_font_override("font", Kit.texte_gras())

static func _staff_detail(app: Control, canvas: Control) -> void:
	var gauche := STAFF_GAUCHE
	var blocs := [[214.0, 404.0, "L’encadrement", "ClubStaffPeople"], [634.0, 306.0, "Diagnostic de la semaine", "ClubStaffDiagnostic"], [956.0, 288.0, "Contrats et engagements", "ClubStaffContracts"]]
	var panneaux: Array[Panel] = []
	for bloc: Array in blocs:
		var panneau := _panneau(canvas, Rect2(0, float(bloc[0]), gauche, float(bloc[1])), str(bloc[2]), str(bloc[3]))
		# Titre sur toute la largeur de la colonne (jamais coupé en « … »).
		panneau.add_theme_stylebox_override("panel", Charte.style_panneau())
		var titre := panneau.get_node_or_null("CardTitle") as Label
		if titre != null: titre.size.x = (gauche - 48.0) * C.density
		panneaux.append(panneau)
	_staff(panneaux[0], app)
	_staff_diagnostic(panneaux[1], app)
	_staff_contrats(panneaux[2], app)
	var droite := gauche + 22.0
	var fond := D.rect(canvas, Rect2(droite, 214, W - droite, 1030), Charte.PANNEAU, 0)
	fond.add_theme_stylebox_override("panel", Charte.style_panneau())
	fond.name = "ClubStaffTable"
	var detail: Control = app.StaffViews.build(app) if app.route == "Staff" else app.SupportViews.build(app)
	var tabs: TabContainer = detail.find_child("SupportTabs", true, false)
	if tabs != null:
		tabs.current_tab = clampi(int(app.management_ui.get("immersive08_support_tab",0)), 0, 2)
		tabs.tab_changed.connect(func(index: int): app.management_ui.immersive08_support_tab = index)
	U.place_detail(canvas, Rect2(droite + 24, 230, W - droite - 48, 998), detail)
	if app.route == "Staff":
		style_staff(detail, app.accent)
		return
	Legacy.apply(detail, app.accent)
	# Habillage de la charte (boutons secondaires en liens) sans perdre la hauteur de clic des boutons (plancher 28 px).
	var hauteurs := {}
	for bouton: Button in detail.find_children("*", "Button", true, false): hauteurs[bouton] = bouton.custom_minimum_size.y
	Habillage._charte(detail)
	for bouton: Button in hauteurs:
		if is_instance_valid(bouton): bouton.custom_minimum_size.y = maxf(bouton.custom_minimum_size.y, float(hauteurs[bouton]))

static func _history(app: Control, canvas: Control) -> void:
	var card := D.panel(canvas, Rect2(0,214,610,612), "Les archives du club", "trophy", "", "ClubHistorySummary")
	D.photo(card, "ceremonie-remise-trophee" if BanqueImages.existe("ceremonie-remise-trophee") else "club-forest", Rect2(20,69,570,164))
	var data := History.project(app.model,int(app.model.club.id))
	var international: bool = app.model.meta.get("mode") == "world"
	if international: data.seasons = History.world_seasons(app,int(app.model.club.id))
	var titles := 0
	for year: Dictionary in data.seasons: titles += year.get("titles",[]).size()
	var rows := [["Saisons archivées",data.seasons.size()],["Titres conservés",titles],["Derniers résultats",data.events.size()]]
	var palmares: Dictionary = app.model.get("club",{}).get("palmares",{}) if international else {}
	if not palmares.is_empty():
		# Palmarès connu dès le premier jour, fusionné aux saisons jouées en carrière.
		rows = [["Titres au palmarès",Palmares.count_text(int(palmares.get("totalTitles",0)))],["Finales connues",Palmares.count_text(palmares.get("finals",[]).size())],["Saisons jouées avec toi",Palmares.count_text(int(palmares.get("careerSeasons",0)))]]
	# Vitrine : quelques trophées de la banque d'images posés sur la photo quand le club a des titres.
	var nb_titres := int(palmares.get("totalTitles", titles)) if not palmares.is_empty() else titles
	var vitrine := ["trophee-coupe-haute", "trophee-bouclier-bois-argent", "trophee-coupe-anses", "trophee-plaque-or"]
	for t in mini(nb_titres, vitrine.size()):
		if BanqueImages.existe(vitrine[t]):
			var coupe := D.photo(card, vitrine[t], Rect2(470 - t * 104, 129, 112, 112), 0.0)
			coupe.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			coupe.name = "ClubHistoryTrophy%d" % t
	for i in rows.size():
		var y := 278+i*73
		D.text(card, 24, y, rows[i][0], 29, C.IVORY, 600, 475)
		D.text(card, 586, y, rows[i][1], 35, C.MINT, 700, 118, HORIZONTAL_ALIGNMENT_RIGHT)
		D.line(card, Vector2(24,y+18), Vector2(586,y+18), Color(C.LINE,.6))
	_lien(card, Rect2(24,520,0,40), "Ouvrir les compétitions →", func(): app._navigate("Classements"), "ClubHistoryCompetitions")
	if international: _world_history(app,canvas,data)
	else: U.place_detail(canvas, Rect2(626,214,1622,1030), History.build(app))

static func _world_history(app: Control, canvas: Control, data: Dictionary) -> void:
	var card := D.panel(canvas,Rect2(626,214,1622,1030),"L’histoire de "+str(data.club_name),"trophy","","CarnetClubMemory")
	var scroll := ScrollContainer.new()
	scroll.name = "ClubMemoryScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	card.add_child(scroll)
	D.place(scroll,Rect2(22,69,1578,939))
	var list := C.v(15)
	C.fill(list)
	scroll.add_child(list)
	var years: Array = data.seasons
	# Revue du 21/11/2026, n° 8 (option B choisie par Léo) : frise des saisons et statistiques en barres.
	var analyse := C.v(15)
	analyse.name = "PerformanceAnalysis"
	C.fill(analyse)
	list.add_child(analyse)
	analyse.add_child(HistoireVisuels.build(app, years))
	if years.size() >= 2:
		analyse.add_child(C.rule())
		_world_comparison(app, analyse, years)
	var individuel := C.v(9)
	preload("res://ui/performance_analysis_view.gd")._individual(app, individuel)
	Legacy.apply(individuel, app.accent)
	analyse.add_child(individuel)
	list.add_child(C.rule())
	_world_coach(list, data)

static func _world_coach(list: VBoxContainer, data: Dictionary) -> void:
	list.add_child(C.label("LE PARCOURS DU COACH",27,C.GOLD,true,700))
	if data.manager_current_from != null: list.add_child(C.label("Mandat actuel depuis la saison "+G.season_label(data.manager_current_from),24))
	if data.manager_history.is_empty(): list.add_child(Pastilles.pastille("Aucune prise de poste", Charte.IVOIRE_2, "check", "Aucune prise de poste antérieure enregistrée.", 20, "ClubHistoryNoMove"))
	for move: Dictionary in data.manager_history:
		list.add_child(C.wrap("Saison %s · %s  →  %s" % [G.season_label(move.get("arrivalSeason","—")),move.from_name,move.to_name],23,C.IVORY,true))

static func _world_year(app: Control, year: Dictionary) -> PanelContainer:
	var card := C.card("Saison "+G.season_label(year.season))
	C.fill(card)
	var content := C.content(card)
	var rank := "%s · rang %s / %s" % [World.name_for(app.model,str(year.league_id)),G.n(year.rank),G.n(year.division_size)] if year.rank != null else "Rang de phase régulière indisponible"
	content.add_child(C.wrap(rank,25,C.IVORY,true,600))
	for id: String in year.titles:
		content.add_child(C.wrap("Champion · "+World.name_for(app.model,id),23,C.MINT,true,600))
	for line: String in World.movement_lines(app.model,str(year.league_id),bool(year.promoted),false): content.add_child(C.label(line,22,C.MINT))
	for line: String in World.movement_lines(app.model,str(year.league_id),false,bool(year.relegated)): content.add_child(C.label(line,22,C.AMBER))
	for line: String in year.get("nationale_lines",[]): content.add_child(C.wrap(line,22,C.IVORY))
	for barrage: Dictionary in year.japan_barrages:
		for line: String in World.japan_lines(app,barrage): content.add_child(C.wrap(line,22,C.IVORY))
	return card

static func _world_comparison(app: Control, list: VBoxContainer, years: Array) -> void:
	var panel := C.card("Comparer deux saisons")
	list.add_child(panel)
	var contents := C.content(panel)
	var selectors := C.h(16)
	var comparison := C.h(16)
	contents.add_child(selectors)
	contents.add_child(comparison)
	var indexes := [0,1]
	var redraw := func():
		for child in comparison.get_children():
			comparison.remove_child(child)
			child.queue_free()
		for index: int in indexes: comparison.add_child(_world_year(app,years[index]))
	for i in 2:
		var key := "club_memory_season_a" if i == 0 else "club_memory_season_b"
		var selector := OptionButton.new()
		selector.name = "ClubMemorySeasonA" if i == 0 else "ClubMemorySeasonB"
		selector.custom_minimum_size.y = C.px(40)
		C.fill(selector)
		var chosen := int(app.management_ui.get(key,years[i].season))
		for year: Dictionary in years:
			selector.add_item("Saison "+G.season_label(year.season),int(year.season))
			if int(year.season) == chosen: indexes[i] = selector.item_count-1
		selector.select(indexes[i])
		selectors.add_child(selector)
		selector.item_selected.connect(func(index: int):
			indexes[i] = index
			app.management_ui[key] = int(years[index].season)
			redraw.call())
	redraw.call()

static func _territory(app: Control, canvas: Control) -> void:
	var page := Control.new()
	page.name = "ClubTerritory"
	canvas.add_child(page)
	D.place(page, Rect2(0,214,2248,1030))
	var identity := G.identity(app.model.club)
	var city_picture := ClubViews.territory_city_picture(app.model.club, false)
	var stadium_width := 1480 if city_picture == null else 1116
	for i in 2:
		var kind := "stadium" if i == 0 else "city"
		var x := 0 if i == 0 else stadium_width + 16
		var width := stadium_width if i == 0 else 2248 - x
		var panel := D.panel(page, Rect2(x,0,width,821), "Le stade" if i == 0 else "Le territoire", "home")
		var picture := G.club_picture(app.model.club, kind, false) if i == 0 else city_picture
		if picture == null:
			D.text(panel, 24, 120, "Ville non renseignée", 43, C.IVORY, 700, width - 52)
			continue
		panel.add_child(picture)
		D.place(picture, Rect2(16,68,width - 32,642))
		var from_pack: bool = picture.get_meta("photo_kind") == "pack"
		D.text(panel, 24, 760, identity.get("stadium",app.model.club.get("stadium","Le stade")) if i == 0 else identity.get("city","Le territoire"), 43, C.IVORY, 700, width - 52)
		var photo: Dictionary = identity.get("photos", {}).get(kind, {})
		var credit := D.text(panel, 24, 798, "Photo · " + str(photo.get("credit", "")) if from_pack else _venue_caption(picture), 23, C.MUTED, 500, width - 52)
		if from_pack:
			credit.name = "VenuePhotoCredit_" + kind
			_venue_credit(credit, photo)
	var links := D.panel(page, Rect2(0,837,2248,193), "Un territoire, une identité", "shield")
	_lien(links, Rect2(1415,86,0,40), "Crédits et licences →", app._credits, "ClubAtlasCredits")
	Kit.bouton_ivoire(links, Rect2(1804,80,420,52), "Revenir à la vue d’ensemble", func(): _tab(app, "overview", "ClubTab_overview"), "ClubAtlasBack")

# Excédents réinvestis par le président (carrière Monde) : où en sont les travaux, l'accueil du stade et le staff.
# Colonne de droite du panneau « Les moyens du club », à côté du devis du manager ; rien sans excédent cette saison.
static func _president_projects(projects: Panel, inv: Variant) -> void:
	if not inv is Dictionary: return
	var box := Control.new()
	box.name = "ClubPresidentProjects"
	box.position = Vector2(800, 74) * C.density
	box.size = Vector2(474, 214) * C.density
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	projects.add_child(box)
	var inst: Dictionary = inv.get("installations", {})
	var acc: Dictionary = inv.get("accueil", {})
	var staff: Dictionary = inv.get("staff", {})
	D.text(box, 0, 28, "Excédents réinvestis · " + G.euros(inv.get("montant", 0)), 26, Charte.IVOIRE, 700, 474)
	var travaux := "Installations au maximum"
	if inst.get("devis") != null:
		travaux = "Travaux du niveau %s · %s %% financés" % [G.n(int(inst.get("niveau", 0)) + 1), G.n(roundi(100.0 * float(inst.get("avancement", 0))))]
	if int(inst.get("achevesCetteSaison", 0)) > 0:
		var faits := int(inst.get("achevesCetteSaison", 0))
		travaux += " · %s achevé%s" % [G.n(faits), "s" if faits > 1 else ""]
	D.text(box, 0, 64, travaux, 23, C.IVORY, 600, 474)
	D.rect(box, Rect2(0, 75, 474, 10), Charte.PANNEAU_3, 0)
	D.rect(box, Rect2(0, 75, 474.0 * clampf(float(inst.get("avancement", 0)), 0.0, 1.0), 10), Charte.IVOIRE_2, 0)
	var accueil := "Accueil du stade · niveau %s / %s" % [G.n(acc.get("niveau", 0)), G.n(acc.get("max", 5))]
	if float(acc.get("effet", 0)) > 0.0: accueil += " · guichet +%s %%" % ("%.1f" % (100.0 * float(acc.get("effet", 0)))).replace(".", ",")
	if acc.get("degrade", false) == true: accueil += " · en recul"
	D.text(box, 0, 114, accueil, 23, C.IVORY, 600, 474)
	for segment in int(acc.get("max", 5)):
		D.rect(box, Rect2(segment * 96, 125, 90, 10), Charte.IVOIRE_2 if segment < int(acc.get("niveau", 0)) else Charte.PANNEAU_3, 0)
	var points := int(staff.get("points", 0))
	var staff_txt := "Staff · aucune progression pour l’instant" if points == 0 else "Staff · %s point%s gagné%s par %s membre%s" % [G.n(points), "s" if points > 1 else "", "s" if points > 1 else "", G.n(staff.get("personnes", 0)), "s" if int(staff.get("personnes", 0)) > 1 else ""]
	D.text(box, 0, 164, staff_txt, 23, C.IVORY, 600, 474)
	D.text(box, 0, 194, "Dépensé : %s sur %s" % [G.euros(inv.get("depense", 0)), G.euros(inv.get("montant", 0))], 20, C.MUTED, 500, 474)

static func _infrastructure_detail(app: Control, corps: Control) -> void:
	var data := U.strategy(app.model)
	var finance: Dictionary = data.get("finance", {})
	_installations(_panneau(corps, Rect2(0, 214, 1404, 302), "Installations", "ClubFacilities"), app, finance, data)
	_stade(_panneau(corps, Rect2(1426, 214, W - 1426, 302), "Le stade", "ClubStadiumCard"), app, data.get("fans", {}))
	var projects := _panneau(corps, Rect2(0, 532, W, 640), "Les moyens du club", "ClubFacilityProjects", true)
	var quote: Variant = finance.get("facility")
	if quote is Dictionary:
		Kit.texte(projects, 24, 104, "Installations du club · niveau %s / 10" % G.n(quote.level), Charte.IVOIRE, 740, 26).add_theme_font_override("font", Kit.texte_gras())
		var tuile_niveau := Pastilles.tuile(Pastilles.euros_courts(quote.cost), "niveau %s" % G.n(quote.nextLevel), Pastilles.BLEU, Charte.PANNEAU_2, 26, "ClubFacilityNextLevel", true, func(): app._navigate("Finances"))
		Pastilles.poser(projects, tuile_niveau, 24, 108)
		var action := Kit.bouton_ivoire(projects, Rect2(24, 158, 300, 46), "Examiner le devis", func(): Strategy._send(app, "club_facility_upgrade", {"cost": quote.cost, "level": quote.level}, "Investir %s pour passer les installations au niveau %s ?" % [G.euros(quote.cost), G.n(quote.nextLevel)]), "ClubFacilityQuote")
		action.disabled = not data.get("available", false) or app.waiting or app.model.meta.get("trained", false) or app.model.meta.get("phase", "") != "league" or quote.used or not quote.affordable
		var reason := Pastilles.pastille("1 par saison", Charte.IVOIRE_2, "calendar", "Un investissement par saison, avant la séance de la semaine.", 18, "ClubFacilityReason")
		if quote.used: reason = Pastilles.pastille("Déjà engagée cette saison", Charte.IVOIRE_2, "check", "Une amélioration a déjà été engagée cette saison.", 18, "ClubFacilityReason")
		elif not quote.affordable: reason = Pastilles.pastille("Trésorerie insuffisante", Pastilles.ORANGE, "warning", "La trésorerie disponible est insuffisante pour ce devis.", 18, "ClubFacilityReason", func(): app._navigate("Finances"))
		Pastilles.poser(projects, reason, 24, 214)
	else: Pastilles.poser(projects, Pastilles.pastille("Aucun devis", Charte.IVOIRE_2, "warning", "Aucun devis d’installations disponible.", 18, "ClubFacilityNoQuote"), 24, 90)
	_president_projects(projects, finance.get("investissements"))
	D.line(projects, Vector2(24, 262), Vector2(W - 24, 262), Charte.FILET)
	Kit.texte(projects, 24, 304, "Centre de formation", Charte.IVOIRE, 740, 26).add_theme_font_override("font", Kit.texte_gras())
	Pastilles.poser(projects, Pastilles.info("L’investissement hebdomadaire suit la séance de formation.", "i", "ClubAcademyInfo"), 24 + Kit.largeur("Centre de formation", 26) + 14, 282)
	_lien(projects, Rect2(24, 352, 0, 34), "Ouvrir le centre de formation →", func(): app._navigate("Centre"), "ClubAcademyFacilities")
	D.line(projects, Vector2(24, 400), Vector2(W - 24, 400), Charte.FILET)
	var photo := D.photo(projects, "club-salle-recuperation-bains" if BanqueImages.existe("club-salle-recuperation-bains") else "medical-recovery", Rect2(1300, 290, 880, 320), .4)
	photo.modulate = Color(1, 1, 1, .4)
	Kit.texte(projects, 24, 442, "Cellule médicale", Charte.IVOIRE, 740, 26).add_theme_font_override("font", Kit.texte_gras())
	Pastilles.poser(projects, Pastilles.info("Protocoles et décisions de retour des joueurs suivis.", "i", "ClubMedicalInfo"), 24 + Kit.largeur("Cellule médicale", 26) + 14, 420)
	_lien(projects, Rect2(24, 490, 0, 34), "Ouvrir le travail du club →", func(): app._navigate("Travail du club"), "ClubFacilityMedical")
	_lien(projects, Rect2(24, 570, 0, 34), "Décisions d’investissement →", func(): _open_strategy(app, 0), "ClubFacilityStrategy")

## Carte du stade (photo du club, nom, capacité) : un clic ouvre « Le stade ».
static func _stade(panneau: Panel, app: Control, fans: Dictionary) -> void:
	var identite := G.identity(app.model.club)
	var image := G.club_picture(app.model.club, "stadium", false)
	panneau.clip_contents = true
	panneau.add_child(image)
	D.place(image, Rect2(0, 56, panneau.size.x / C.density, 150))
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Kit.texte(panneau, 24, 238, str(identite.get("stadium", "Le stade du club")), Charte.IVOIRE, 760, 24).add_theme_font_override("font", Kit.texte_gras())
	var x_tuile := 24.0
	for chiffre: Array in [["capacity", "places", Pastilles.TURQUOISE], ["expectedAttendance", "affluence", Pastilles.BLEU], ["subscribers", "abonnés", Pastilles.VIOLET]]:
		if not fans.has(chiffre[0]): continue
		x_tuile += Pastilles.poser(panneau, Pastilles.tuile(G.n(fans[chiffre[0]]), str(chiffre[1]), chiffre[2], Charte.PANNEAU_2, 22, "ClubStadiumFigure_" + str(chiffre[0]), true, func(): _tab(app, "territory", "ClubTab_overview")), x_tuile, 246) + 8.0
	var voir_stade := Kit.lien(panneau, Rect2(panneau.size.x / C.density - 24, 12, 0, 34), "Voir le stade →", func(): _tab(app, "territory", "ClubTab_overview"), "ClubSeeStadiumLink", 19, true)
	voir_stade.tooltip_text = ""
