extends RefCounted
## Écran pleine page « Comparateur » (décision de Léo du 19/11/2026 : jamais de petite fenêtre) : remplace l'ancienne
## fenêtre « Comparer deux joueurs » de l'Effectif, du Recrutement et de la fiche joueur. Deux colonnes (choix de Léo
## du 23/11/2026 : plus de troisième joueur), un sélecteur de joueur par colonne (« Choisir un joueur » tant qu'il reste
## de la place), puis le radar à 8 axes (comparateur_radar.gd) : synthèse de chaque joueur de part et d'autre, clic sur
## un axe = ses qualités en barres miroir dans une petite fenêtre visuelle.
## Échap, « ← Retour » et Précédent ramènent à l'écran d'origine (étape d'historique de la route « Comparateur »).
## Lecture seule : la mémoire des joueurs est `management_ui.compare` (2 maximum), partagée avec l'Effectif.
## Exemple : `Comparateur.ouvrir(app, "world:champ:…")`.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Identity = preload("res://ui/player_identity.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const Base = preload("res://ui/immersive08/recruitment_comparison.gd")
const Radar = preload("res://ui/immersive08/comparateur_radar.gd")
const ROUTE := "Comparateur"
const MAX := 2
const LARGEUR := 2248.0
const Y_DETAIL := 300.0

## Ouvre le comparateur ; `ajouter` rejoint la mémoire (le plus ancien cède la place s'il y en a déjà deux).
static func ouvrir(app: Control, ajouter: String = "") -> void:
	var memoire: Array = app.management_ui.compare
	if not ajouter.is_empty() and not ajouter in memoire:
		if memoire.size() >= MAX: memoire.remove_at(0)
		memoire.append(ajouter)
	if app.route != ROUTE: app.management_ui.comparateur_origine = app.route
	app._navigate(ROUTE)
	var premier := app.root_content.find_child("ComparateurJoueur0", true, false) as Control
	if premier != null: premier.grab_focus.call_deferred()

## Retour à l'écran d'où l'on vient (même mécanisme que Précédent).
static func retour(app: Control) -> void:
	var navigation: Node = app.get("navigation_controller")
	if is_instance_valid(navigation) and navigation._destination(-1) >= 0:
		navigation._travel(-1)
		return
	app._navigate(str(app.management_ui.get("comparateur_origine", "Effectif")))

static func _origine(app: Control) -> String:
	return {"Effectif": "← Retour à l’effectif", "Recrutement": "← Retour au recrutement", "Formation": "← Retour à la formation"}.get(str(app.management_ui.get("comparateur_origine", "Effectif")), "← Retour")

static func caption(app: Control) -> String:
	return "Comparateur · %d joueur%s" % [app.management_ui.compare.size(), "s" if app.management_ui.compare.size() > 1 else ""]

static func build(app: Control, canvas: Control) -> void:
	var page := Control.new()
	page.name = "ImmersiveComparateur"
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, LARGEUR, 1244))
	_construire(app, page)

static func _construire(app: Control, page: Control) -> void:
	var reserve: Array = Base.pool(app.model)
	var propres: Array = app.model.get("squad", []).map(func(p: Dictionary): return str(p.get("id", "")))
	var memoire: Array = app.management_ui.compare
	var maximum := MAX
	var ids: Array = memoire.filter(func(id): return reserve.any(func(p: Dictionary): return str(p.get("id", "")) == str(id))).slice(0, maximum)
	memoire.assign(ids)
	var colonnes := clampi(ids.size() + 1, 2, maximum)
	var retour_lien := Kit.lien(page, Rect2(0, 4, 0, 38), _origine(app), func(): retour(app), "ComparateurRetour", 20)
	retour_lien.accessibility_name = _origine(app) + " · Échap"
	C.style_bouton_lien(retour_lien, 20)
	Kit.touche(page, retour_lien.size.x / C.density + 10, 32, "Échap")
	var titre := Kit.titre_page(page, 0, 98, "Comparateur", 56, 900)
	titre.name = "ComparateurTitre"
	Pieces.info(page, Pieces.largeur_titre("COMPARATEUR", 56) + 24.0, 64.0, "Deux joueurs côte à côte\n▲ : meilleure valeur\nClic sur un axe : ses qualités", "ComparateurAide")
	var x0 := 0.0
	var ecart := 100.0
	var largeur := (LARGEUR - x0 - ecart * (colonnes - 1)) / colonnes
	var joueurs: Array[Dictionary] = []
	var xs: Array = []
	for i in colonnes:
		var x := x0 + i * (largeur + ecart)
		xs.append(x)
		var trouve: Dictionary = {}
		var id := str(ids[i]) if i < ids.size() else ""
		for p: Dictionary in reserve:
			if str(p.get("id", "")) == id: trouve = Base.prepared(app, p, id in propres)
		joueurs.append(trouve)
		_entete(app, page, i, x, largeur, trouve, reserve, propres)
	# Comparaison en radar (idée FM27 n° 9, option A retenue par Léo le 23/11/2026).
	Radar.liseres(page, joueurs, xs, largeur, Y_DETAIL - 8)
	Radar.construire(app, page, joueurs, Y_DETAIL)

static func _entete(app: Control, page: Control, i: int, x: float, largeur: float, joueur: Dictionary, reserve: Array, propres: Array) -> void:
	var choix := OptionButton.new()
	choix.name = "ComparateurJoueur" + str(i)
	choix.accessibility_name = "Joueur " + str(i + 1) + " : choisir le joueur à comparer"
	choix.fit_to_longest_item = false
	choix.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	choix.add_theme_font_override("font", C.BODY)
	choix.add_theme_font_size_override("font_size", maxi(12, C.px(19)))
	choix.get_popup().add_theme_font_size_override("font_size", maxi(12, C.px(19)))
	for nom: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		choix.add_theme_color_override(nom, Charte.IVOIRE)
	for etat: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.PANNEAU_2 if etat != "hover" else Charte.PANNEAU_3
		style.border_color = Charte.IVOIRE if etat == "focus" else Charte.FILET
		style.set_border_width_all(1)
		style.set_corner_radius_all(Charte.RAYON_PILULE)
		style.content_margin_left = C.px(18)
		style.content_margin_right = C.px(12)
		choix.add_theme_stylebox_override(etat, style)
	var vide := joueur.is_empty()
	var courant := -1
	if vide:
		choix.add_item("Choisir un joueur")
		choix.set_item_metadata(0, "")
	var indice := choix.item_count
	for p: Dictionary in reserve:
		var id := str(p.get("id", ""))
		var mien := id in propres
		choix.add_item("%s · %s%s" % [str(p.get("name", id)), str(p.get("pos", "")), "" if mien else " · piste"])
		choix.set_item_metadata(choix.item_count - 1, id)
		if not vide and id == str(joueur.get("id", "")): courant = choix.item_count - 1
		indice += 1
	choix.select(0 if vide else maxi(0, courant))
	choix.item_selected.connect(func(index: int): _choisir(app, i, str(choix.get_item_metadata(index))))
	page.add_child(choix)
	D.place(choix, C.reach_rect(Rect2(x, 166, largeur, 40)))
	if vide:
		var emplacement := Button.new()
		emplacement.name = "ComparateurVide" + str(i)
		emplacement.text = "Choisir un joueur →"
		emplacement.alignment = HORIZONTAL_ALIGNMENT_LEFT
		emplacement.add_theme_font_override("font", C.BODY)
		emplacement.add_theme_font_size_override("font_size", maxi(12, C.px(20)))
		for nom: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			emplacement.add_theme_color_override(nom, Charte.IVOIRE_2)
		for etat: String in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(Charte.PANNEAU, 1.0) if etat == "normal" else Charte.PANNEAU_2
			style.border_color = Charte.IVOIRE if etat == "focus" else Charte.FILET
			style.set_border_width_all(1)
			style.set_corner_radius_all(C.px(16))
			style.content_margin_left = C.px(16)
			emplacement.add_theme_stylebox_override(etat, Charte.ombrer(style, 16))
		emplacement.pressed.connect(func(): choix.show_popup())
		page.add_child(emplacement)
		D.place(emplacement, Rect2(x, 216, largeur, 70))
		return
	var id := str(joueur.get("id", ""))
	var source := "squad" if id in propres else "market"
	var vignette := G.portrait_lazy(int(joueur.get("portraitIndex", 0)), C.px(60), joueur)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(vignette)
	D.place(vignette, Rect2(x, 218, 64, 62))
	var faits: Dictionary = joueur.get("playerFacts", {}) if joueur.get("playerFacts") is Dictionary else {}
	var drapeau := Identity.flag_texture(str(faits.get("flagCode", ""))) if faits.get("flagCode") is String else null
	var nom_x := x + 80.0
	if drapeau != null:
		var image := TextureRect.new()
		image.texture = drapeau
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(image)
		D.place(image, Rect2(nom_x, 252, 28, 18))
		nom_x += 36.0
	var nom := Kit.lien(page, Rect2(x + 74, 214, largeur - 230, 36), str(joueur.get("name", "")), func(): _ouvrir_fiche(app, id, source), "ComparateurNom" + str(i), 24)
	C.style_bouton_lien(nom, 24, true)
	MiniFiche.lier(app, nom, id, source)
	var detail := "%s · %s ans" % [str(joueur.get("pos", "")), G.n(joueur.get("age", "—"))]
	Kit.texte(page, nom_x, 276, detail, Charte.IVOIRE_2, largeur - 240, 18)
	var retirer := Kit.lien(page, Rect2(x + largeur - 150, 232, 150, 36), "Retirer ✕", func(): _retirer(app, id), "ComparateurRetirer" + str(i), 18)
	C.style_bouton_lien(retirer, 18)

static func _choisir(app: Control, colonne: int, id: String) -> void:
	if id.is_empty(): return
	var liste: Array = app.management_ui.compare.duplicate()
	liste.erase(id)
	if colonne < liste.size(): liste[colonne] = id
	else: liste.append(id)
	app.management_ui.compare.assign(liste.slice(0, MAX))
	app.management_ui.comparateur_focus = "ComparateurJoueur" + str(colonne)
	app._render(false)
	var cible := app.root_content.find_child("ComparateurJoueur" + str(colonne), true, false) as Control
	if cible != null: cible.grab_focus.call_deferred()

static func _retirer(app: Control, id: String) -> void:
	app.management_ui.compare.erase(id)
	app._render(false)

static func _ouvrir_fiche(app: Control, id: String, source: String) -> void:
	app.navigation_controller.open_entity({"kind": "player" if source == "squad" else "market", "id": id})
