extends RefCounted
## Écran pleine page « Comparateur » (décision de Léo du 19/11/2026 : jamais de petite fenêtre) : remplace l'ancienne
## fenêtre « Comparer deux joueurs » de l'Effectif, du Recrutement et de la fiche joueur. Deux à trois colonnes, un
## sélecteur de joueur par colonne (« Choisir un joueur » tant qu'il reste de la place), synthèse puis les 36 attributs
## côte à côte colorés au barème, la meilleure valeur de chaque ligne en gras avec ▲ (jamais la couleur seule).
## Échap, « ← Retour » et Précédent ramènent à l'écran d'origine (étape d'historique de la route « Comparateur »).
## Lecture seule : la mémoire des joueurs est `management_ui.compare` (3 maximum), partagée avec l'Effectif.
## Exemple : `Comparateur.ouvrir(app, "world:champ:…")`.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Commune = preload("res://ui/immersive08/fiche_commune.gd")
const Identity = preload("res://ui/player_identity.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const Attributs = preload("res://ui/player_attributes.gd")
const Base = preload("res://ui/immersive08/recruitment_comparison.gd")
const Radar = preload("res://ui/immersive08/comparateur_radar.gd")
const ROUTE := "Comparateur"
const MAX := 3
const LARGEUR := 2248.0
const Y_DETAIL := 300.0

## Ouvre le comparateur ; `ajouter` rejoint la mémoire (le plus ancien cède la place s'il y en a déjà trois).
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
	var variante: String = Radar.variante()
	var maximum := 2 if not variante.is_empty() else MAX
	var ids: Array = memoire.filter(func(id): return reserve.any(func(p: Dictionary): return str(p.get("id", "")) == str(id))).slice(0, maximum)
	memoire.assign(ids)
	var colonnes := clampi(ids.size() + 1, 2, maximum)
	var retour_lien := Kit.lien(page, Rect2(0, 4, 0, 38), _origine(app), func(): retour(app), "ComparateurRetour", 20)
	retour_lien.accessibility_name = _origine(app) + " · Échap"
	C.style_bouton_lien(retour_lien, 20)
	Kit.touche(page, retour_lien.size.x / C.density + 10, 32, "Échap")
	var titre := Kit.titre_page(page, 0, 98, "Comparateur", 56, 900)
	titre.name = "ComparateurTitre"
	Pieces.info(page, Pieces.largeur_titre("COMPARATEUR", 56) + 24.0, 64.0, "Jusqu’à trois joueurs côte à côte\n▲ : meilleure valeur de la ligne\nL’âge et le coût ne comptent pas comme un avantage", "ComparateurAide")
	var x0 := 330.0 if variante.is_empty() else 0.0
	var ecart := 28.0 if variante.is_empty() else 100.0
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
	if not variante.is_empty():
		# Planche FM27 n° 9 : comparaison en radar (deux joueurs, deux couleurs).
		Radar.liseres(page, joueurs, xs, largeur, Y_DETAIL - 8)
		if variante == "A": Radar.construire_a(app, page, joueurs, Y_DETAIL)
		else: Radar.construire_b(app, page, joueurs, Y_DETAIL)
		return
	D.line(page, Vector2(0, Y_DETAIL - 6), Vector2(LARGEUR, Y_DETAIL - 6), Charte.FILET)
	var defile := ScrollContainer.new()
	defile.name = "ComparateurDetails"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.follow_focus = true
	page.add_child(defile)
	D.place(defile, Rect2(0, Y_DETAIL, LARGEUR, 1244 - Y_DETAIL - 8))
	var contenu := Control.new()
	contenu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	defile.add_child(contenu)
	var etat := {"y": 0.0, "rang": 0, "n": 0}
	var pas := 36.0
	var ligne := func(titre_ligne: String, valeurs: Array, textes: Array, cle_meilleure: bool, nom: String) -> void:
		var y: float = etat.y
		D.line(contenu, Vector2(0, y + pas - 1), Vector2(LARGEUR, y + pas - 1), Color(Charte.FILET, .6))
		D.text(contenu, 16, y + 25, titre_ligne, 19, C.MUTED, 500, x0 - 30, HORIZONTAL_ALIGNMENT_LEFT, true)
		var meilleure := -INF
		var compte := 0
		for v: Variant in valeurs:
			if Base.numeric(v) and float(v) > meilleure: meilleure = float(v)
		for v: Variant in valeurs:
			if Base.numeric(v) and float(v) == meilleure: compte += 1
		for i in colonnes:
			if joueurs[i].is_empty(): continue
			var v: Variant = valeurs[i]
			var gagnant: bool = cle_meilleure and Base.numeric(v) and float(v) == meilleure and compte == 1 and joueurs.filter(func(p): return not p.is_empty()).size() > 1
			var couleur: Color = Charte.couleur_attribut(v) if nom.begins_with("Attribut") else C.IVORY
			var etiquette := D.text(contenu, x0 + i * (largeur + 28.0) + largeur - 40, y + 26, str(textes[i]) + (" ▲" if gagnant else ""), 22, couleur, 700, largeur - 60, HORIZONTAL_ALIGNMENT_RIGHT)
			etiquette.name = nom + "_" + str(i)
			if gagnant: etiquette.add_theme_font_override("font", C.EXTRA_BOLD)
		etat.y = y + pas
		etat.rang = int(etat.rang) + 1
	var section := func(titre_section: String) -> void:
		var y: float = float(etat.y) + 14.0
		var t := Kit.titre(contenu, 16, y + 24, titre_section, 24, 900)
		t.name = "ComparateurSection" + str(etat.n)
		etat.n = int(etat.n) + 1
		D.line(contenu, Vector2(0, y + 34), Vector2(LARGEUR, y + 34), Charte.FILET)
		etat.y = y + 44.0
		etat.rang = 0
	section.call("Synthèse")
	var proprietaire := func(i: int) -> bool: return bool(joueurs[i].get("__own", false)) if not joueurs[i].is_empty() else false
	var vals: Array = []
	var txts: Array = []
	for i in colonnes:
		var p: Dictionary = joueurs[i]
		vals.append(Base.value(p, "rating") if not p.is_empty() else null)
		txts.append(G.rating_text(p, proprietaire.call(i)) if not p.is_empty() else "")
	ligne.call("Niveau", vals, txts, true, "Synthese_niveau")
	vals = []; txts = []
	for i in colonnes:
		var p: Dictionary = joueurs[i]
		vals.append(Base.value(p, "potential") if not p.is_empty() else null)
		txts.append(G.potential_text(p) if not p.is_empty() else "")
	ligne.call("Potentiel", vals, txts, true, "Synthese_potentiel")
	vals = []; txts = []
	for i in colonnes:
		var p: Dictionary = joueurs[i]
		var forme: Variant = Commune.condition(p) if not p.is_empty() else null
		vals.append(forme)
		txts.append("%d %%" % roundi(float(forme)) if forme != null else "—")
	ligne.call("Condition", vals, txts, true, "Synthese_condition")
	vals = []; txts = []
	for i in colonnes:
		var p: Dictionary = joueurs[i]
		vals.append(null)
		txts.append(G.n(p.get("age", "—")) + " ans" if not p.is_empty() and p.has("age") else "—")
	ligne.call("Âge", vals, txts, false, "Synthese_age")
	vals = []; txts = []
	for i in colonnes:
		var p: Dictionary = joueurs[i]
		vals.append(null)
		txts.append(Commune.echeance(app, p) if not p.is_empty() else "")
	ligne.call("Fin de contrat", vals, txts, false, "Synthese_contrat")
	for groupe: Array in Attributs.GROUPS:
		section.call(str(groupe[0]))
		for paire: Array in groupe[1]:
			vals = []; txts = []
			for i in colonnes:
				var p: Dictionary = joueurs[i]
				var v: Variant = Base.value(p, "attribute:" + str(paire[0])) if not p.is_empty() else null
				vals.append(v)
				txts.append(Attributs.caption(v))
			ligne.call(str(paire[1]), vals, txts, true, "Attribut_" + str(paire[0]))
	contenu.custom_minimum_size = Vector2(C.px(LARGEUR), C.px(float(etat.y) + 20.0))

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
