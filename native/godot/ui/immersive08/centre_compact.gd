extends RefCounted
## Centre de formation en affichage compact (fenêtre sous 1280 × 720), parcours actifs : mêmes six onglets, mêmes
## structures et mêmes couleurs que la page façon Effectif (centre_visuel.gd / centre_onglets.gd), mais en conteneurs
## qui s'adaptent à la place (le gabarit de 2248 de large ne tient pas sous 1280 × 720) : tuiles chiffres, onglets en
## pilules, panneaux à titre Anton, listes à lignes (survol de ligne, carte joueur au survol, tri par en-tête, filtres en
## pastilles) et réglages en pastilles. Les petites fenêtres (parcours individuel, candidats, prêt, saison junior) sont
## celles de la grande page, posées sur une toile à l'échelle du gabarit au-dessus de la page.
## Aucune nouvelle commande : tout passe par V.envoyer (mêmes confirmations de dépense).
const V = preload("res://ui/immersive08/centre_visuel.gd")
const T = preload("res://ui/immersive08/centre_onglets.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/carnet_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")
const Juniors = preload("res://ui/immersive08/centre_juniors.gd")
const Listes = preload("res://ui/immersive08/listes_joueurs.gd")

const NOM_PAGE := "CarnetAcademyPathways"
const CORPS := 13
const PETIT := 12
const HAUT_LIGNE := 36.0
const HAUT_COMMANDE := 28.0
const ECART := 8

# --- Page ------------------------------------------------------------------------------------------------------------

static func build(app: Control, initial_tab: String = "") -> Control:
	var data: Dictionary = app.model.get("clubLife", {}).get("academyPathways", {})
	if not app.management_ui.get("immersive_centre") is Dictionary:
		app.management_ui.immersive_centre = {"tab": "", "scroll": {}}
	var state: Dictionary = app.management_ui.immersive_centre
	var club: Variant = app.model.get("club", {}).get("id")
	if state.get("club") != club:
		state.clear()
		state.merge({"club": club, "tab": "", "scroll": {}})
	if not state.get("scroll") is Dictionary: state.scroll = {}
	if initial_tab in V.ONGLETS: state.tab = initial_tab
	var racine := VBoxContainer.new()
	racine.name = NOM_PAGE
	racine.add_theme_constant_override("separation", ECART)
	C.fill(racine, true)
	var ctx := {"app": app, "data": data, "state": state, "racine": racine, "hote": null, "page": null}
	ctx.reconstruire = func(): _remplir(ctx)
	_remplir(ctx)
	var rouvrir: Variant = state.get("fenetre")
	if rouvrir is Dictionary and str(rouvrir.get("kind", "")) == "joueur":
		(func():
			if is_instance_valid(racine) and racine.is_inside_tree():
				_preparer(ctx)
				V.fenetre_parcours(ctx, str(rouvrir.get("id", "")))).call_deferred()
	return racine

static func _remplir(ctx: Dictionary) -> void:
	var racine: VBoxContainer = ctx.racine
	var hote: Variant = ctx.get("hote")
	if is_instance_valid(hote): (hote as Node).queue_free()
	ctx.hote = null
	ctx.page = null
	for enfant in racine.get_children():
		racine.remove_child(enfant)
		enfant.queue_free()
	var onglet := str(ctx.state.get("tab", ""))
	if not onglet in V.ONGLETS: onglet = "Centre"
	ctx.onglet = onglet
	racine.set_meta("onglet", onglet)
	_entete(ctx)
	_onglets(ctx)
	var defile := ScrollContainer.new()
	defile.name = "CentreCompactDefile"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.follow_focus = true
	C.fill(defile, true)
	racine.add_child(defile)
	var contenu := VBoxContainer.new()
	contenu.name = "CentreCompactContenu"
	contenu.add_theme_constant_override("separation", ECART)
	C.fill(contenu)
	defile.add_child(contenu)
	match onglet:
		"Parcours": _parcours(ctx, contenu)
		"Centres": _centres(ctx, contenu)
		"Filières": _filieres(ctx, contenu)
		"Passerelle pro": _passerelle(ctx, contenu)
		"Générations": _generations(ctx, contenu)
		_: _centre(ctx, contenu)
	for enfant in racine.get_children(): _marquer(enfant)
	var memoire: Dictionary = ctx.state.scroll
	var cle := "compact/" + onglet
	defile.get_v_scroll_bar().value_changed.connect(func(v: float): memoire[cle] = int(v))
	var position := int(memoire.get(cle, 0))
	if position > 0:
		(func():
			if not is_instance_valid(defile): return
			await defile.get_tree().process_frame
			await defile.get_tree().process_frame
			if is_instance_valid(defile): defile.scroll_vertical = position).call_deferred()

## Tout est déjà habillé ici : le style des vues anciennes (legacy_style.gd) ne doit rien repeindre.
static func _marquer(noeud: Node) -> void:
	if noeud is Control: (noeud as Control).set_meta("immersive_style_applied", true)
	for enfant in noeud.get_children(): _marquer(enfant)

## Toile des petites fenêtres : une page à l'échelle du gabarit (2248 × 1230), centrée au-dessus de toute la fenêtre.
static func _preparer(ctx: Dictionary) -> void:
	var hote: Variant = ctx.get("hote")
	if is_instance_valid(hote) and (hote as Node).is_inside_tree():
		ctx.page = (hote as Node).get_meta("toile")
		return
	var conteneur: Control = ctx.app.root_content if is_instance_valid(ctx.app.root_content) else ctx.app
	var nouvel := Control.new()
	nouvel.name = "CentreCompactFenetres"
	nouvel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteneur.add_child(nouvel)
	nouvel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var toile := Control.new()
	toile.name = "CentreCompactToile"
	toile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nouvel.add_child(toile)
	toile.size = Vector2(2248, 1230) * C.density
	var centrer := func():
		if is_instance_valid(toile) and is_instance_valid(nouvel): toile.position = ((nouvel.size - toile.size) / 2.0).round()
	nouvel.resized.connect(centrer)
	centrer.call()
	nouvel.set_meta("toile", toile)
	ctx.hote = nouvel
	ctx.page = toile

## Ouvre une petite fenêtre de la grande page : `ouvrir` reçoit le contexte dont `page` est la toile.
static func _fenetre(ctx: Dictionary, ouvrir: Callable) -> Callable:
	return func():
		_preparer(ctx)
		ouvrir.call()

# --- Pièces ----------------------------------------------------------------------------------------------------------

static func _ignorer(noeud: Node) -> void:
	if noeud is Control: (noeud as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

static func _mesure(texte: String, taille: int, police: Font = null) -> float:
	return (police if police != null else C.BODY).get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x

static func _txt(parent: Node, valeur: Variant, taille: int = CORPS, couleur: Color = Charte.IVOIRE, police: Font = null, alignement: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, coupe: bool = false) -> Label:
	var l := Label.new()
	l.text = str(valeur)
	l.add_theme_font_override("font", police if police != null else C.BODY)
	l.add_theme_font_size_override("font_size", maxi(PETIT, taille))
	l.add_theme_color_override("font_color", couleur)
	l.horizontal_alignment = alignement
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_meta("immersive_style_applied", true)
	if coupe:
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent != null: parent.add_child(l)
	return l

## Légende en capitales (Barlow gras), couleur faible.
static func _legende(parent: Node, texte: String, couleur: Color = Charte.IVOIRE_3, taille: int = PETIT) -> Label:
	return _txt(parent, texte.to_upper(), taille, couleur, C.BOLD)

## Chiffre en Barlow extra-gras de la couleur de sa donnée.
static func _chiffre(parent: Node, valeur: Variant, taille: int, couleur: Color = Charte.IVOIRE, alignement: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return _txt(parent, valeur, taille, couleur, Charte.TITRE_EXTRA, alignement)

static func _icone(parent: Node, id: String, cote: int, couleur: Color) -> TextureRect:
	var i := C.icon(id, roundi(cote / C.density), couleur)
	i.custom_minimum_size = Vector2(cote, cote)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if parent != null: parent.add_child(i)
	return i

static func _espace(parent: Node) -> Control:
	var e := Control.new()
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(e)
	return e

static func _rangee(parent: Node, ecart: int = ECART) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", ecart)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null: parent.add_child(h)
	return h

static func _flux(parent: Node, ecart: int = ECART) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", ecart)
	f.add_theme_constant_override("v_separation", ecart)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent != null: parent.add_child(f)
	return f

## Pastille d'état (voile de la couleur, icône et texte de la couleur) : jamais un bouton.
static func _pastille(parent: Node, texte: String, couleur: Color, icone: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := V.plat(Color(couleur, .15), Color.TRANSPARENT, 0, 8)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := _rangee(p, 5)
	if not icone.is_empty(): _icone(h, icone, 14, couleur)
	_txt(h, texte, PETIT, couleur, C.BOLD)
	if parent != null: parent.add_child(p)
	return p

## Bouton plat qui couvre sa place : voile clair au survol, main, focus. Les enfants ne reçoivent pas la souris.
static func _zone(action: Callable, id: String, aide: String, rayon: int = 8, haut: float = HAUT_COMMANDE, fond: Color = Color.TRANSPARENT, bord: Color = Color.TRANSPARENT) -> Button:
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.accessibility_name = aide
	b.custom_minimum_size.y = haut
	for etat: String in ["normal", "hover", "pressed", "focus"]:
		var s: StyleBoxFlat
		if etat == "focus": s = V.plat(Color.TRANSPARENT, Charte.IVOIRE, 1, rayon)
		elif etat == "normal": s = V.plat(fond, bord, 1 if bord.a > 0 else 0, rayon)
		else: s = V.plat(fond.lerp(Charte.IVOIRE, .08 if etat == "hover" else .14) if fond.a > 0 else Color(Charte.IVOIRE, .08 if etat == "hover" else .14), bord, 1 if bord.a > 0 else 0, rayon)
		b.add_theme_stylebox_override(etat, s)
	if action.is_valid(): b.pressed.connect(action)
	return b

## Rangée posée DANS un bouton (marges et centrage vertical) ; renvoie la rangée où poser les éléments.
static func _dans(bouton: Button, marge: int = 8, ecart: int = ECART) -> HBoxContainer:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", marge)
	m.add_theme_constant_override("margin_right", marge)
	bouton.add_child(m)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var h := _rangee(m, ecart)
	return h

## Pastille-bouton (filtre, réglage, action) : choisie = aplat de sa couleur, texte sombre ; sinon contour discret et
## point de couleur.
static func _pilule(parent: Node, libelle: String, couleur: Color, choisie: bool, action: Callable, id: String, nombre: String = "", actif: bool = true) -> Button:
	var point := couleur != Charte.IVOIRE and not choisie
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if actif else Control.CURSOR_ARROW
	b.accessibility_name = "%s %s%s" % [libelle, nombre, " · choisi" if choisie else ""]
	b.disabled = not actif
	for etat: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := V.plat(couleur if choisie else (Charte.PANNEAU_2 if etat == "hover" else Color.TRANSPARENT), Color.TRANSPARENT if choisie else (Charte.IVOIRE_3 if etat == "hover" else Charte.FILET), 0 if choisie else 1, Charte.RAYON_PILULE)
		if etat == "focus": s = V.plat(Color.TRANSPARENT, Charte.IVOIRE, 2, Charte.RAYON_PILULE)
		b.add_theme_stylebox_override(etat, s)
	var encre := Charte.PANNEAU if choisie else (Charte.IVOIRE if actif else Charte.IVOIRE_3)
	var largeur := 20.0 + _mesure(libelle, CORPS, C.BOLD) + (14.0 if point else 0.0) + (6.0 + _mesure(nombre, CORPS, C.BOLD) if not nombre.is_empty() else 0.0)
	b.custom_minimum_size = Vector2(largeur, HAUT_COMMANDE)
	var h := _dans(b, 10, 6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if point:
		var rond := Panel.new()
		rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rond.custom_minimum_size = Vector2(8, 8)
		rond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rond.add_theme_stylebox_override("panel", V.plat(couleur if actif else Charte.IVOIRE_3, Color.TRANSPARENT, 0, Charte.RAYON_PILULE))
		h.add_child(rond)
	_txt(h, libelle, CORPS, encre, C.BOLD)
	if not nombre.is_empty(): _txt(h, nombre, CORPS, Charte.PANNEAU if choisie else (couleur if point else Charte.IVOIRE_2), C.BOLD)
	if actif and action.is_valid(): b.pressed.connect(action)
	parent.add_child(b)
	return b

## Panneau de l'Effectif : fond PANNEAU, titre Anton avec pictogramme, flèche vers un écran ou un onglet. Renvoie la colonne
## où poser le contenu (le panneau porte le nom `id`).
static func _panneau(parent: Node, titre: String, icone_id: String, id: String, fleche: Callable = Callable(), compte: String = "", couleur_compte: Color = Charte.IVOIRE) -> VBoxContainer:
	var p := PanelContainer.new()
	p.name = id
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := C.box(Charte.PANNEAU, Color.TRANSPARENT, Charte.RAYON_PANNEAU, 0)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", ECART)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var tete := _rangee(v, 8)
	_icone(tete, icone_id, 18, Charte.IVOIRE_2)
	var t := _txt(tete, titre.to_upper(), 18, Charte.IVOIRE, Charte.TITRE_FICHE)
	t.name = id + "Titre"
	if not compte.is_empty(): _chiffre(tete, compte, 20, couleur_compte)
	_espace(tete)
	if fleche.is_valid():
		var b := _zone(fleche, id + "Fleche", titre, 8, HAUT_COMMANDE)
		b.custom_minimum_size.x = 36
		var m := _dans(b, 8)
		m.alignment = BoxContainer.ALIGNMENT_CENTER
		_icone(m, "arrow", 16, Charte.IVOIRE)
		tete.add_child(b)
	return v

## Ligne de chiffre dans un panneau : icône, intitulé, valeur colorée à droite ; toute la ligne mène à `action`.
static func _ligne_chiffre(parent: Node, icone_id: String, libelle: String, valeur: String, couleur: Color, action: Callable, id: String) -> Control:
	var h: HBoxContainer
	var racine: Control
	if action.is_valid():
		var b := _zone(action, id, libelle, 8, 30.0)
		h = _dans(b, 6, 8)
		racine = b
	else:
		h = _rangee(null, 8)
		h.custom_minimum_size.y = 30.0
		racine = h
	_icone(h, icone_id, 16, couleur)
	_txt(h, libelle, CORPS, Charte.IVOIRE, C.BOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	_chiffre(h, valeur, 20, couleur, HORIZONTAL_ALIGNMENT_RIGHT)
	if parent != null: parent.add_child(racine)
	return racine

static func _barre(parent: Node, part: float, couleur: Color, haut: float = 8.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 1.0
	b.value = clampf(part, 0.0, 1.0)
	b.show_percentage = false
	b.custom_minimum_size = Vector2(40, haut)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("background", V.plat(Charte.PANNEAU_3, Color.TRANSPARENT, 0, Charte.RAYON_PILULE))
	b.add_theme_stylebox_override("fill", V.plat(couleur, Color.TRANSPARENT, 0, Charte.RAYON_PILULE))
	if parent != null: parent.add_child(b)
	return b

## Jauge du panneau (Cohésion, Réputation) : icône, intitulé, rail coloré, chiffre.
static func _jauge(parent: Node, icone_id: String, libelle: String, v: float, couleur: Color, action: Callable, id: String) -> Control:
	var h: HBoxContainer
	var racine: Control
	if action.is_valid():
		var b := _zone(action, id, libelle, 8, 30.0)
		h = _dans(b, 6, 8)
		racine = b
	else:
		h = _rangee(null, 8)
		h.custom_minimum_size.y = 30.0
		racine = h
	_icone(h, icone_id, 16, couleur)
	var t := _txt(h, libelle, CORPS, Charte.IVOIRE, C.BOLD)
	t.custom_minimum_size.x = 76
	_barre(h, v / 100.0, couleur)
	var n := _chiffre(h, G.n(v), 20, couleur, HORIZONTAL_ALIGNMENT_RIGHT)
	n.custom_minimum_size.x = 30
	parent.add_child(racine)
	return racine

static func _crans(parent: Node, pleins: int, total: int, couleur: Color) -> void:
	var h := _rangee(parent, 3)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in total:
		var c := Panel.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.custom_minimum_size = Vector2(16, 8)
		c.add_theme_stylebox_override("panel", V.plat(couleur if i < pleins else Charte.PANNEAU_3, Color.TRANSPARENT, 0, Charte.RAYON_PILULE))
		h.add_child(c)

static func _portrait(parent: Node, p: Dictionary, cote: int = 26) -> Control:
	var image: Control = G.portrait_lazy(int(p.get("portraitIndex", 0)), cote, p)
	image.custom_minimum_size = Vector2(cote, cote)
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

## Disque aux initiales (blason sobre d'un centre ou d'un club formateur).
static func _blason(parent: Node, nom: String, teinte: Color, cote: int = 26) -> Panel:
	var rond := Panel.new()
	rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rond.custom_minimum_size = Vector2(cote, cote)
	rond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var s := V.plat(Charte.PANNEAU_3.lerp(teinte, .35), teinte, 2, Charte.RAYON_PILULE)
	rond.add_theme_stylebox_override("panel", s)
	var initiales := ""
	for m: String in nom.split(" ", false):
		if m.length() > 0 and m[0] == m[0].to_upper() and initiales.length() < 3: initiales += m[0]
	var l := _txt(rond, initiales if not initiales.is_empty() else "XV", PETIT, Charte.IVOIRE, Charte.TITRE_EXTRA, HORIZONTAL_ALIGNMENT_CENTER)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(rond)
	return rond

# --- En-tête et onglets ---------------------------------------------------------------------------------------------

static func _tuile(parent: Node, id: String, titre: String, valeur: String, suffixe: String, couleur: Color, action: Callable) -> Button:
	var b := _zone(action, "CentreTuile" + id, "%s %s %s" % [titre, valeur, suffixe], 12, 48.0, Charte.PANNEAU)
	b.custom_minimum_size.x = maxf(104.0, 22.0 + _mesure(titre, PETIT, C.BOLD))
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cote: String in ["left", "right"]: m.add_theme_constant_override("margin_" + cote, 10)
	m.add_theme_constant_override("margin_top", 4)
	m.add_theme_constant_override("margin_bottom", 4)
	b.add_child(m)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)
	_legende(v, titre, Charte.IVOIRE_2)
	var h := _rangee(v, 5)
	var n := _chiffre(h, valeur, 26, couleur)
	n.name = "CentreTuileValeur"
	if not suffixe.is_empty(): _txt(h, suffixe, PETIT, Charte.IVOIRE_2, C.BODY)
	parent.add_child(b)
	return b

## Deux pastilles (Espoirs, saison junior) et quatre tuiles chiffres (même contenu que la grande page).
static func _entete(ctx: Dictionary) -> void:
	var app: Control = ctx.app
	var data: Dictionary = ctx.data
	var f := _flux(ctx.racine)
	f.name = "CentreCompactEntete"
	var n: int = data.get("players", []).size()
	var espoirs := _zone(V.aller(ctx, "Parcours"), "CentreSousTitre", "Espoirs du centre", 14, 48.0, Charte.PANNEAU)
	espoirs.custom_minimum_size.x = 120.0
	var he := _dans(espoirs, 12, 8)
	_icone(he, "people", 18, Charte.IVOIRE_2)
	_chiffre(he, G.n(n), 26, Charte.IVOIRE)
	_txt(he, "Espoirs", CORPS, Charte.IVOIRE_2, C.BOLD)
	f.add_child(espoirs)
	var saison := _zone(_fenetre(ctx, func(): Juniors.ouvrir(app, ctx.page)), "CentreSaison", "Saison junior", 14, 48.0, Charte.PANNEAU)
	saison.custom_minimum_size.x = 150.0
	var hs := _dans(saison, 12, 8)
	_icone(hs, "calendar", 18, V.MINUTES)
	_txt(hs, "Période", CORPS, Charte.IVOIRE_2, C.BOLD)
	_chiffre(hs, "%s / %s" % [G.n(data.get("juniorRound", 0)), G.n(data.get("totalRounds", 26))], 22, V.MINUTES)
	f.add_child(saison)
	_tuile(f, "Cohesion", "COHÉSION", G.n(data.get("cohesion", 0)), "/ 100", V.COHESION, V.aller(ctx, "Centre"))
	_tuile(f, "Reputation", "RÉPUTATION", G.n(data.get("reputation", 0)), "/ 100", V.REPUTATION, V.aller(ctx, "Générations"))
	_tuile(f, "Enveloppe", "ENVELOPPE JUNIOR", V.mille(data.get("recruitBudget", 0)) + " €", "", V.DEPENSE, V.aller(ctx, "Centres"))
	_tuile(f, "Places", "PLACES PRO", G.n(data.get("places", 0)), "libres", V.PROGRES, func(): app._navigate("Effectif"))

## Onglets en pilules (même rendu que l'Effectif) avec leur compteur.
static func _onglets(ctx: Dictionary) -> void:
	var data: Dictionary = ctx.data
	var comptes := {
		"Parcours": data.get("players", []).size(),
		"Centres": data.get("centers", []).filter(func(c: Dictionary): return c.get("scouted", false) and not c.get("own", false)).size(),
		"Filières": data.get("prospects", []).size(),
		"Passerelle pro": data.get("loans", []).size(),
		"Générations": data.get("generations", []).size(),
	}
	var f := _flux(ctx.racine, 6)
	f.name = "CentreCompactOnglets"
	for nom: String in V.ONGLETS:
		var actif: bool = nom == ctx.onglet
		var libelle := nom if not comptes.has(nom) else "%s  %d" % [nom, comptes[nom]]
		var b := Button.new()
		b.name = "CentreOnglet_" + nom.validate_node_name()
		b.text = libelle
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", C.BODY)
		b.add_theme_font_size_override("font_size", CORPS)
		b.accessibility_name = "Onglet " + nom + (" · actif" if actif else "")
		D.tab_state(b, Vector2(0, HAUT_COMMANDE), actif, "")
		b.icon = null
		for etat: String in ["normal", "hover", "pressed", "hover_pressed"]:
			var s := b.get_theme_stylebox(etat) as StyleBoxFlat
			s.content_margin_left = 12
			s.content_margin_right = 12
			s.content_margin_top = 4
			s.content_margin_bottom = 4
		var focus := V.plat(Color.TRANSPARENT, Charte.IVOIRE, 2, Charte.RAYON_PILULE)
		focus.set_expand_margin_all(2)
		b.add_theme_stylebox_override("focus", focus)
		b.custom_minimum_size = Vector2(0, HAUT_COMMANDE)
		b.pressed.connect(V.aller(ctx, nom))
		f.add_child(b)

# --- Listes à lignes --------------------------------------------------------------------------------------------------

## Bandeau (filtres en pastilles + en-têtes de colonnes triables) puis lignes. `colonnes` : [{k, t, w, a, tri, desc}] ;
## une colonne sans `w` s'étire. `cellule(cellule, colonne, element)` pose le contenu d'une cellule (rangée) ;
## `groupes` : [[titre, couleur, filtre]].
static func _liste(ctx: Dictionary, parent: Node, colonnes: Array, elements: Array, cellule: Callable, cle_tri: Callable, au_clic: Callable, nom_ligne: Callable, id: String, filtres: Callable, groupes: Array = [], tri_defaut: Array = []) -> VBoxContainer:
	var tri: Variant = ctx.state.get("tri_" + id)
	if not tri is Array or (tri as Array).size() < 2: tri = tri_defaut if tri_defaut.size() >= 2 else []
	var bloc := VBoxContainer.new()
	bloc.name = id
	bloc.add_theme_constant_override("separation", 2)
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(bloc)
	var bandeau := PanelContainer.new()
	bandeau.name = id + "Bandeau"
	bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bandeau.add_theme_stylebox_override("panel", Bandeau.style(0))
	var sb := bandeau.get_theme_stylebox("panel") as StyleBoxFlat
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 4
	bloc.add_child(bandeau)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 4)
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bandeau.add_child(colonne)
	if filtres.is_valid():
		var flux := _flux(colonne, 6)
		flux.name = id + "Filtres"
		filtres.call(flux)
	var entete := _rangee(colonne, 6)
	entete.name = id + "Entete"
	for col: Dictionary in colonnes:
		var k := str(col.k)
		var al: HorizontalAlignment = col.get("a", HORIZONTAL_ALIGNMENT_LEFT)
		var b := Button.new()
		b.name = id + "Tri_" + k
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if col.get("tri", false) else Control.CURSOR_ARROW
		b.alignment = al
		b.clip_text = true
		b.add_theme_font_override("font", C.BOLD)
		b.add_theme_font_size_override("font_size", PETIT)
		b.custom_minimum_size = Vector2(float(col.get("w", 0)), 26.0)
		if not col.has("w"): b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var actif: bool = tri is Array and (tri as Array).size() >= 2 and str(tri[0]) == k
		Listes.styler_entete(b, null, actif, actif and bool(tri[1]), str(col.t))
		for etat: String in ["disabled", "hover_pressed"]: b.add_theme_stylebox_override(etat, b.get_theme_stylebox("normal"))
		b.add_theme_stylebox_override("focus", V.plat(Color.TRANSPARENT, Charte.IVOIRE, 1, 4))
		b.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
		if col.get("tri", false):
			b.pressed.connect(func():
				var desc: bool = (not bool(tri[1])) if actif else bool(col.get("desc", true))
				ctx.state["tri_" + id] = [k, desc]
				(ctx.reconstruire as Callable).call())
		else:
			b.disabled = true
			b.focus_mode = Control.FOCUS_NONE
		entete.add_child(b)
	var tries := elements.duplicate()
	if tri is Array and (tri as Array).size() >= 2:
		var k := str(tri[0])
		var desc := bool(tri[1])
		tries.sort_custom(func(x: Variant, y: Variant):
			var vx: Variant = cle_tri.call(x, k)
			var vy: Variant = cle_tri.call(y, k)
			if vx == vy: return false
			if vx == null: return false
			if vy == null: return true
			return (vx > vy) if desc else (vx < vy))
	var lignes := VBoxContainer.new()
	lignes.name = id + "Lignes"
	lignes.add_theme_constant_override("separation", 2)
	lignes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(lignes)
	var rang := 0
	var paquets: Array = groupes if not groupes.is_empty() else [["", Charte.IVOIRE, func(_e: Variant): return true]]
	for g: Array in paquets:
		var contenu := tries.filter(g[2])
		if not str(g[0]).is_empty():
			if contenu.is_empty(): continue
			_groupe(lignes, str(g[0]), contenu.size(), g[1], id)
		for e: Variant in contenu:
			_ligne(ctx, lignes, colonnes, e, rang, cellule, au_clic, nom_ligne)
			rang += 1
	if rang == 0:
		var vide := _rangee(lignes)
		vide.custom_minimum_size.y = 48
		_chiffre(vide, "0", 26, Charte.IVOIRE_3)
	return bloc

static func _groupe(lignes: Node, titre: String, n: int, couleur: Color, id: String) -> void:
	var g := _rangee(lignes, 8)
	g.name = id + "Groupe_" + titre.validate_node_name()
	g.custom_minimum_size.y = 30
	var bande := Panel.new()
	bande.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bande.custom_minimum_size = Vector2(4, 18)
	bande.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bande.add_theme_stylebox_override("panel", V.plat(couleur, Color.TRANSPARENT, 0, 3))
	g.add_child(bande)
	_txt(g, titre.to_upper(), 17, Charte.IVOIRE, Charte.TITRE_EXTRA)
	_chiffre(g, str(n), 17, couleur)

static func _ligne(ctx: Dictionary, lignes: Node, colonnes: Array, e: Variant, rang: int, cellule: Callable, au_clic: Callable, nom_ligne: Callable) -> void:
	var ligne := Button.new()
	ligne.name = str(nom_ligne.call(e, rang))
	ligne.set_meta("element", e)
	ligne.custom_minimum_size.y = HAUT_LIGNE
	ligne.clip_contents = true
	ligne.focus_mode = Control.FOCUS_ALL
	load("res://ui/survol_ligne.gd").appliquer(ligne, false, Color.TRANSPARENT, ctx.app.accent)
	lignes.add_child(ligne)
	var filet := Panel.new()
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filet.add_theme_stylebox_override("panel", V.plat(Charte.FILET, Color.TRANSPARENT, 0, 0))
	ligne.add_child(filet)
	filet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	filet.offset_top = -1.0
	var rangee := _dans(ligne, 8, 6)
	for col: Dictionary in colonnes:
		var cel := HBoxContainer.new()
		cel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cel.add_theme_constant_override("separation", 6)
		cel.clip_contents = true
		var al: HorizontalAlignment = col.get("a", HORIZONTAL_ALIGNMENT_LEFT)
		cel.alignment = BoxContainer.ALIGNMENT_END if al == HORIZONTAL_ALIGNMENT_RIGHT else BoxContainer.ALIGNMENT_BEGIN
		cel.custom_minimum_size.x = float(col.get("w", 0))
		if not col.has("w"): cel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rangee.add_child(cel)
		cellule.call(cel, col, e)
	ligne.pressed.connect(func(): au_clic.call(e, ligne))

## Texte simple d'une cellule, aligné comme sa colonne.
static func _cel(cel: Control, col: Dictionary, valeur: Variant, couleur: Color = Charte.IVOIRE, police: Font = null, taille: int = CORPS) -> Label:
	var al: HorizontalAlignment = col.get("a", HORIZONTAL_ALIGNMENT_LEFT)
	var l := _txt(cel, valeur, taille, couleur, police, al, true)
	return l

## Cellule « joueur » : visage, nom (survol = carte joueur si `source`), sous-titre facultatif.
static func _cel_joueur(ctx: Dictionary, cel: Control, p: Dictionary, source: String = "academy", sous: String = "") -> void:
	_portrait(cel, p, 26)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", -2)
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	cel.add_child(colonne)
	var nom := _txt(colonne, p.get("name", ""), CORPS, Charte.IVOIRE, C.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
	nom.name = "CentreNom"
	if not sous.is_empty(): _txt(colonne, sous, PETIT, Charte.IVOIRE_3, C.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
	if not source.is_empty() and not str(p.get("id", "")).is_empty(): CarteSurvol.lier(ctx.app, nom, str(p.id), source)

# --- Étapes (le chemin) ------------------------------------------------------------------------------------------------

## Bande de tuiles du chemin (étapes d'âge, statuts) : choisie = teinte de sa couleur ; un clic filtre la liste.
static func _chemin(ctx: Dictionary, parent: Node, etapes: Array, actif: String, cle: String, id: String, fin: Array) -> void:
	var f := _flux(parent, ECART)
	f.name = id
	for e: Array in etapes:
		var valeur := str(e[0])
		var choisi := valeur == actif
		var teinte: Color = e[2]
		var b := _zone(V.aller(ctx, ctx.onglet, cle, "" if choisi else valeur), "%sEtape_%s" % [id, valeur], str(e[1]), Charte.RAYON_CARTE, 48.0, Charte.PANNEAU_2.lerp(teinte, .28) if choisi else Charte.PANNEAU_2, teinte if choisi else Color.TRANSPARENT)
		b.custom_minimum_size.x = 150.0
		var h := _dans(b, 10, 8)
		var bande := Panel.new()
		bande.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bande.custom_minimum_size = Vector2(4, 28)
		bande.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bande.add_theme_stylebox_override("panel", V.plat(teinte, Color.TRANSPARENT, 0, 3))
		h.add_child(bande)
		_txt(h, str(e[1]).to_upper(), CORPS, Charte.IVOIRE, C.BOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
		_chiffre(h, str(e[3]), 28, teinte, HORIZONTAL_ALIGNMENT_RIGHT)
		f.add_child(b)
	if not fin.is_empty():
		var b2 := _zone(fin[4], id + "Fin", str(fin[0]), Charte.RAYON_CARTE, 48.0, Charte.PANNEAU_2)
		b2.custom_minimum_size.x = 200.0
		var h2 := _dans(b2, 10, 8)
		var bande2 := Panel.new()
		bande2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bande2.custom_minimum_size = Vector2(4, 28)
		bande2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bande2.add_theme_stylebox_override("panel", V.plat(fin[2], Color.TRANSPARENT, 0, 3))
		h2.add_child(bande2)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(col)
		_txt(col, str(fin[0]).to_upper(), CORPS, Charte.IVOIRE, C.BOLD)
		_txt(col, str(fin[3]), PETIT, Charte.IVOIRE_2, C.BODY)
		_chiffre(h2, str(fin[1]), 28, fin[2], HORIZONTAL_ALIGNMENT_RIGHT)
		f.add_child(b2)

# --- Centre : le chemin de la détection à l'équipe première -------------------------------------------------------------

static func _centre(ctx: Dictionary, parent: Node) -> void:
	var data: Dictionary = ctx.data
	var app: Control = ctx.app
	var verrou: bool = data.get("locked", false)
	var colonnes := _rangee(parent, ECART)
	colonnes.name = "CentreCompactChemin"
	var gauche := VBoxContainer.new()
	gauche.add_theme_constant_override("separation", ECART)
	gauche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauche.size_flags_stretch_ratio = 1.0
	colonnes.add_child(gauche)
	var droite := VBoxContainer.new()
	droite.add_theme_constant_override("separation", ECART)
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite.size_flags_stretch_ratio = 1.0
	colonnes.add_child(droite)
	# 1. Détection
	var det := _panneau(gauche, "Détection", "search", "CentreDetection", V.aller(ctx, "Filières"))
	var scout := V.cout(ctx, "scout", 35000)
	var faite: bool = data.get("nextScouted", false)
	_legende(det, "Détection annuelle")
	var rang := _rangee(det, ECART)
	_chiffre(rang, V.euros(scout), 30, Charte.IVOIRE_3 if faite else V.DEPENSE)
	_espace(rang)
	if faite: _pastille(rang, "Faite", V.PROGRES, "check").name = "CentreDetectionFaite"
	else: _pilule(rang, "Lancer", V.DEPENSE, true, func(): V.envoyer(ctx, "academy_scout", {}, scout, "Détection annuelle"), "CentreDetectionLancer", "", not verrou)
	var observes: int = data.get("centers", []).filter(func(c: Dictionary): return c.get("scouted", false) and not c.get("own", false)).size()
	var lignes := [
		["search", "Centres observés", G.n(observes), V.MINUTES, V.aller(ctx, "Centres")],
		["people", "Jeunes repérés", G.n(data.get("prospects", []).size()), V.PROGRES, V.aller(ctx, "Filières")],
		["flag", "Clubs partenaires", G.n(data.get("partners", []).size()), V.COHESION, V.aller(ctx, "Filières")],
		["money", "Enveloppe", V.mille(data.get("recruitBudget", 0)) + " €", V.DEPENSE, V.aller(ctx, "Centres")],
	]
	for i in lignes.size():
		var l: Array = lignes[i]
		_ligne_chiffre(det, l[0], l[1], l[2], l[3], l[4], "CentreDetectionLigne%d" % i)
	var regions: Array = data.get("regions", [])
	if not regions.is_empty():
		var prospects: Array = data.get("prospects", [])
		var max_r := 1
		for zr: Variant in regions: max_r = maxi(max_r, prospects.filter(func(q: Dictionary): return str(q.region) == str(zr)).size())
		var bloc := _zone(V.aller(ctx, "Filières"), "CentreDetectionRegions", "Jeunes repérés par région", 8, 10.0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bloc.add_child(v)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 4
		v.offset_right = -4
		v.offset_top = 4
		bloc.custom_minimum_size.y = regions.size() * 22.0 + 8.0
		for i in regions.size():
			var rg := str(regions[i])
			var teinte: Color = V.COULEURS[i % V.COULEURS.size()]
			var n := prospects.filter(func(q: Dictionary): return str(q.region) == rg).size()
			var r := _rangee(v, 6)
			r.custom_minimum_size.y = 20
			var t := _txt(r, rg, PETIT, Charte.IVOIRE_2, C.BOLD)
			t.custom_minimum_size.x = 86
			_barre(r, float(n) / max_r, teinte, 8.0)
			var c := _chiffre(r, G.n(n), 16, teinte, HORIZONTAL_ALIGNMENT_RIGHT)
			c.custom_minimum_size.x = 24
		det.add_child(bloc)
	# 2. Le centre
	var joueurs: Array = data.get("players", [])
	var ctr := _panneau(droite, "Le centre", "school", "CentreLeCentre", V.aller(ctx, "Parcours"), G.n(joueurs.size()), V.PROGRES)
	_jauge(ctr, "heart", "Cohésion", float(data.get("cohesion", 0)), V.COHESION, Callable(), "")
	_jauge(ctr, "star", "Réputation", float(data.get("reputation", 0)), V.REPUTATION, V.aller(ctx, "Générations"), "CentreJaugeReputation")
	var etapes := _rangee(ctr, ECART)
	for e: Array in V.ETAPES:
		var n := joueurs.filter(func(p: Dictionary): return V.etape(p) == str(e[0])).size()
		var c := _zone(V.aller(ctx, "Parcours", "etape", str(e[0])), "CentreEtape_" + str(e[0]), str(e[1]), Charte.RAYON_CARTE, 54.0, Charte.PANNEAU_2)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var m := MarginContainer.new()
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_theme_constant_override("margin_left", 12)
		m.add_theme_constant_override("margin_top", 2)
		c.add_child(m)
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", -4)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		m.add_child(cv)
		_chiffre(cv, G.n(n), 26, e[2])
		_legende(cv, str(e[1]), Charte.IVOIRE_2)
		var bande := Panel.new()
		bande.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bande.add_theme_stylebox_override("panel", V.plat(e[2], Color.TRANSPARENT, 0, 3))
		c.add_child(bande)
		bande.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		bande.offset_right = 4
		etapes.add_child(c)
	for k in 2:
		var kind := "facilities" if k == 0 else "coaches"
		var niveau := int(data.get(kind, 0))
		var prix := T._cout_niveau(data, kind, niveau, (niveau + 1) * (85000 if k == 0 else 55000)) if niveau < 3 else 0
		var titre := "Installations" if k == 0 else "Éducateurs"
		var r := _rangee(ctr, 8)
		r.custom_minimum_size.y = 32
		_icone(r, "home" if k == 0 else "people", 16, V.PROGRES)
		_txt(r, titre, CORPS, Charte.IVOIRE, C.BOLD)
		_crans(r, niveau, 3, V.PROGRES)
		_espace(r)
		if niveau < 3: _pilule(r, V.euros(prix), V.DEPENSE, false, func(): V.envoyer(ctx, "academy_upgrade", {"kind": kind}, prix, titre), "CentreAmeliorer_" + kind, "", not verrou)
		else: _pastille(r, "3 / 3", V.PROGRES, "check").name = "CentreMax_" + kind
	var reunion := V.cout(ctx, "meeting", 2000)
	var rr := _rangee(ctr, 8)
	rr.custom_minimum_size.y = 32
	_icone(rr, "people", 16, V.COHESION)
	_txt(rr, "Réunion de cohésion", CORPS, Charte.IVOIRE, C.BOLD)
	_espace(rr)
	_pilule(rr, V.euros(reunion), V.DEPENSE, false, func(): V.envoyer(ctx, "academy_meeting", {}, reunion, "Réunion de cohésion"), "CentreReunion", "", not verrou)
	# 3. Rencontres juniors
	var ouvrir_juniors := _fenetre(ctx, func(): Juniors.ouvrir(app, ctx.page))
	var ren := _panneau(gauche, "Rencontres juniors", "trophy", "CentreRencontres", ouvrir_juniors)
	var ronde := int(data.get("juniorRound", 0))
	var total := maxi(1, int(data.get("totalRounds", 26)))
	var rt := _rangee(ren, 6)
	_chiffre(rt, G.n(ronde), 34, V.MINUTES)
	_legende(rt, "/ %d périodes" % total, Charte.IVOIRE_2, CORPS)
	var segments := _rangee(ren, 2)
	for i in total:
		var s := Panel.new()
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.custom_minimum_size = Vector2(4, 10)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.add_theme_stylebox_override("panel", V.plat(Color(V.MINUTES, .9) if i < ronde else Charte.PANNEAU_3, Color.TRANSPARENT, 0, 3))
		segments.add_child(s)
	var resultats: Array = data.get("results", []).duplicate()
	resultats.reverse()
	var club := int(data.get("clubId", -1))
	if not resultats.is_empty(): _legende(ren, "Derniers matchs")
	for i in mini(resultats.size(), 6):
		var r: Dictionary = resultats[i]
		var dom := int(r.get("home", -1)) == club
		var pour := int(r.score[0] if dom else r.score[1])
		var contre := int(r.score[1] if dom else r.score[0])
		var teinte := V.PROGRES if pour > contre else (V.ALERTE if pour < contre else Charte.IVOIRE_2)
		var ligne := _zone(ouvrir_juniors, "CentreResultat%d" % i, "Période %d" % (int(r.get("round", 0)) + 1), 6, 30.0)
		var h := _dans(ligne, 6, 8)
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.custom_minimum_size = Vector2(24, 22)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_theme_stylebox_override("panel", V.plat(Color(teinte, .2), Color.TRANSPARENT, 0, 6))
		_chiffre(badge, "V" if pour > contre else ("D" if pour < contre else "N"), 17, teinte, HORIZONTAL_ALIGNMENT_CENTER)
		h.add_child(badge)
		_txt(h, "P%d" % (int(r.get("round", 0)) + 1), PETIT, Charte.IVOIRE_3, C.BOLD)
		_chiffre(h, "%d – %d" % [pour, contre], 20, Charte.IVOIRE)
		_txt(h, str(r.get("awayCenter") if dom else r.get("homeCenter")), CORPS, Charte.IVOIRE_2, C.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
		ren.add_child(ligne)
	var bilan := [0, 0, 0]
	var points := [0, 0]
	for r: Dictionary in resultats:
		var dom2 := int(r.get("home", -1)) == club
		var a2 := int(r.score[0] if dom2 else r.score[1])
		var b2 := int(r.score[1] if dom2 else r.score[0])
		points[0] += a2
		points[1] += b2
		bilan[0 if a2 > b2 else (1 if a2 == b2 else 2)] += 1
	if not resultats.is_empty():
		var tuiles := _rangee(ren, ECART)
		for t: Array in [[bilan[0], "VICTOIRES", V.PROGRES], [bilan[1], "NULS", Charte.IVOIRE_2], [bilan[2], "DÉFAITES", V.ALERTE]]:
			var c := PanelContainer.new()
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var sc := V.plat(Charte.PANNEAU_2.lerp(t[2], .12), Color.TRANSPARENT, 0, Charte.RAYON_CARTE)
			sc.content_margin_left = 10
			sc.content_margin_top = 4
			sc.content_margin_bottom = 4
			c.add_theme_stylebox_override("panel", sc)
			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", -4)
			cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(cv)
			_chiffre(cv, G.n(t[0]), 24, t[2])
			_legende(cv, t[1], Charte.IVOIRE_2)
			tuiles.add_child(c)
		_ligne_chiffre(ren, "ball", "Points marqués · encaissés", "%d · %d" % [points[0], points[1]], V.MINUTES, Callable(), "")
	var mode := "developpement" if str(data.get("mode", "")) == "formation" else str(data.get("mode", ""))
	for m: Array in T.MODES:
		if m[0] == mode:
			var pm := _pastille(null, str(m[1]), m[2], "calendar")
			pm.name = "CentrePlanActif"
			pm.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			ren.add_child(pm)
	# 4. Équipe première
	var prem := _panneau(droite, "Équipe 1re", "shield", "CentrePremiere", func(): app._navigate("Effectif"))
	var places := int(data.get("places", 0))
	var rp := _rangee(prem, 8)
	_chiffre(rp, G.n(places), 40, V.REPUTATION)
	_legende(rp, "places pro libres", Charte.IVOIRE_2, CORPS)
	var sieges := _flux(prem, 6)
	for i in places:
		var s := PanelContainer.new()
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.custom_minimum_size = Vector2(30, 30)
		var ss := V.plat(Color.TRANSPARENT, V.REPUTATION, 2, Charte.RAYON_PILULE)
		s.add_theme_stylebox_override("panel", ss)
		var cm := CenterContainer.new()
		cm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.add_child(cm)
		_icone(cm, "people", 16, Color(V.REPUTATION, .8))
		sieges.add_child(s)
	_ligne_chiffre(prem, "trophy", "Promus", G.n(data.get("promotions", []).size()), V.DEPENSE, V.aller(ctx, "Passerelle pro"), "CentrePromus")
	_ligne_chiffre(prem, "people", "Effectif pro", "%s / %s" % [G.n(data.get("occupied", 0)), G.n(data.get("capacity", 0))], Charte.IVOIRE, func(): app._navigate("Effectif"), "CentreEffectifPro")
	_ligne_chiffre(prem, "bus", "En prêt", G.n(data.get("loans", []).size()), V.COHESION, V.aller(ctx, "Passerelle pro"), "CentrePrets")
	# Réglages du centre : pastilles, la valeur active en aplat de sa couleur.
	var regl := _panneau(parent, "Réglages", "settings", "CentreReglages")
	var choix := func(commande: String, cle: String) -> Callable:
		return func(v: Variant): V.envoyer(ctx, commande, {cle: v})
	var rangs := [["Plan des rencontres", T.MODES, mode, choix.call("academy_mode", "mode"), "CentreMode"], ["Objectif annuel", T.OBJECTIFS, str(data.get("goal", "")), choix.call("academy_goal", "goal"), "CentreObjectif"], ["Identité", T.IDENTITES, str(data.get("identity", "")), choix.call("academy_identity", "identity"), "CentreIdentite"]]
	for rg: Array in rangs:
		var ligne := _rangee(regl, ECART)
		var t := _legende(ligne, str(rg[0]))
		t.custom_minimum_size.x = 120
		var f := _flux(ligne, 6)
		for o: Array in rg[1]:
			var valeur: Variant = o[0]
			_pilule(f, str(o[1]), o[2], str(rg[2]) == str(valeur), (rg[3] as Callable).bind(valeur), "%s_%s" % [rg[4], str(valeur).validate_node_name()], "", not verrou)

# --- Parcours : les Espoirs sur le chemin -----------------------------------------------------------------------------

static func _parcours(ctx: Dictionary, parent: Node) -> void:
	var data: Dictionary = ctx.data
	var app: Control = ctx.app
	var tous: Array = data.get("players", [])
	var etape := str(ctx.state.get("etape", ""))
	var filtre := str(ctx.state.get("filtre_traj", ""))
	var etapes: Array = []
	for e: Array in V.ETAPES:
		var liste: Array = tous.filter(func(p: Dictionary): return V.etape(p) == str(e[0]))
		etapes.append([e[0], e[1], e[2], liste.size()])
	_chemin(ctx, parent, etapes, etape, "etape", "CentreChemin", ["Équipe 1re", G.n(data.get("places", 0)), V.REPUTATION, "%s promus" % G.n(data.get("promotions", []).size()), func(): app._navigate("Effectif")])
	var joueurs: Array = tous.filter(func(p: Dictionary): return (etape.is_empty() or V.etape(p) == etape) and (filtre.is_empty() or str(p.path) == filtre))
	var colonnes := [
		{"k": "nom", "t": "JOUEUR", "tri": true, "desc": false},
		{"k": "poste", "t": "POSTE", "w": 108, "tri": true, "desc": false},
		{"k": "age", "t": "ÂGE", "w": 34, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "niv", "t": "NIV.", "w": 40, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "pot", "t": "POT.", "w": 48, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "traj", "t": "TRAJECTOIRE", "w": 112, "tri": true, "desc": false},
		{"k": "min", "t": "MINUTES", "w": 124, "tri": true},
	]
	var cellule := func(cel: Control, col: Dictionary, p: Dictionary):
		match str(col.k):
			"nom": _cel_joueur(ctx, cel, p)
			"poste": _cel(cel, col, p.pos, Charte.IVOIRE)
			"age": _cel(cel, col, G.n(p.age), Charte.IVOIRE_2)
			"niv": _cel(cel, col, V.niveau_txt(p), V.couleur_champ(p, "rating"), Charte.TITRE_EXTRA, 17)
			"pot": _cel(cel, col, V.potentiel_txt(p), V.couleur_champ(p, "potential"), Charte.TITRE_EXTRA, 17)
			"traj":
				var t := V.trajectoire(str(p.path))
				_pastille(cel, str(t[1]), t[3], str(t[2]))
			"min":
				var cible := float(p.get("target", 0))
				var m := float(p.get("minutes", 0))
				_barre(cel, m / (cible if cible > 0 else 480.0), V.MINUTES, 6.0)
				var l := _txt(cel, ("%s / %s" % [V.mille(m), V.mille(cible)]) if cible > 0 else V.mille(m), PETIT, V.MINUTES, C.BOLD, HORIZONTAL_ALIGNMENT_RIGHT)
				l.custom_minimum_size.x = 64 if cible > 0 else 30
	var cle := func(p: Dictionary, k: String) -> Variant:
		match k:
			"nom": return str(p.name)
			"poste": return str(p.pos)
			"age": return int(p.age)
			"niv": return V.valeur(p, "rating")
			"pot": return V.valeur(p, "potential")
			"traj": return str(V.trajectoire(str(p.path))[1])
			"min": return float(p.get("minutes", 0))
		return null
	var groupes: Array = []
	if etape.is_empty():
		for e: Array in V.ETAPES:
			var eid := str(e[0])
			groupes.append([str(e[1]), e[2], func(p: Dictionary): return V.etape(p) == eid])
	var filtres := func(flux: Control):
		var defs: Array = [["", "Tous", Charte.IVOIRE, G.n(tous.filter(func(p: Dictionary): return etape.is_empty() or V.etape(p) == etape).size())]]
		for t: Array in V.TRAJECTOIRES:
			var tid := str(t[0])
			defs.append([tid, t[1], t[3], G.n(tous.filter(func(p: Dictionary): return str(p.path) == tid and (etape.is_empty() or V.etape(p) == etape)).size())])
		for d: Array in defs:
			var valeur := str(d[0])
			_pilule(flux, str(d[1]), d[2], filtre == valeur, func():
				ctx.state.filtre_traj = valeur
				(ctx.reconstruire as Callable).call(), "CentreFiltreTrajectoire_" + valeur, str(d[3]))
	_liste(ctx, parent, colonnes, joueurs, cellule, cle, func(p: Dictionary, _l: Control): (_fenetre(ctx, func(): V.fenetre_parcours(ctx, str(p.id)))).call(), func(_p: Dictionary, rang: int): return "CentreVisuelJoueur%d" % rang, "CentreParcoursListe", filtres, groupes, ["pot", true])

# --- Centres : les centres des autres clubs ----------------------------------------------------------------------------

static func _centres(ctx: Dictionary, parent: Node) -> void:
	var data: Dictionary = ctx.data
	var world: bool = data.get("world", false)
	var verrou: bool = data.get("locked", false)
	var observe := V.cout(ctx, "centerScout", 1200)
	var centres: Array = data.get("centers", []).filter(func(c: Dictionary): return not c.get("own", false) and (not world or c.scouted or c.count > 15))
	var vus: Array = centres.filter(func(c: Dictionary): return c.scouted)
	var candidats: Array = []
	for c: Dictionary in vus:
		for p: Dictionary in c.get("candidates", []):
			var q := p.duplicate()
			q.centre = str(c.name)
			candidats.append(q)
	candidats.sort_custom(T._par_potentiel)
	var obs := _panneau(parent, "Observation", "search", "CentresObservation")
	var rangee := _rangee(obs, 16)
	for l: Array in [["search", "Centres observés", "%d / %d" % [vus.size(), centres.size()], V.MINUTES], ["money", "Une observation", V.euros(observe), V.DEPENSE], ["money", "Enveloppe", V.mille(data.get("recruitBudget", 0)) + " €", V.DEPENSE]]:
		var r := _ligne_chiffre(null, l[0], l[1], l[2], l[3], Callable(), "")
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rangee.add_child(r)
	var cand := _panneau(parent, "Candidats", "people", "CentresCandidats", Callable(), G.n(candidats.size()), V.PROGRES)
	var flux := _flux(cand, 6)
	for i in mini(candidats.size(), 8):
		var p: Dictionary = candidats[i]
		var fee := int(p.get("fee", 0))
		var pid := str(p.id)
		var pt := V.couleur_champ(p, "potential")
		var b := _zone(func(): V.envoyer(ctx, "academy_recruit", {"playerId": pid, "offer": fee}, fee, "Recruter " + str(p.name)), "CentresCandidat%d" % i, str(p.name), Charte.RAYON_CARTE, 46.0, Charte.PANNEAU_2)
		b.custom_minimum_size.x = 250.0
		var h := _dans(b, 8, 8)
		_portrait(h, p, 32)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(col)
		_txt(col, p.name, CORPS, Charte.IVOIRE, C.BOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
		_txt(col, p.pos, PETIT, Charte.IVOIRE_2, C.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
		var dr := VBoxContainer.new()
		dr.add_theme_constant_override("separation", -4)
		dr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dr.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(dr)
		_chiffre(dr, V.potentiel_txt(p), 22, pt, HORIZONTAL_ALIGNMENT_RIGHT)
		_txt(dr, V.euros(fee), PETIT, V.DEPENSE, C.BOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		flux.add_child(b)
	var filtre := str(ctx.state.get("filtre_centres", ""))
	var montres: Array = centres.filter(func(c: Dictionary): return filtre.is_empty() or (filtre == "vus") == bool(c.scouted))
	var max_n := 1
	for c: Dictionary in centres: max_n = maxi(max_n, int(c.count))
	var colonnes := [
		{"k": "nom", "t": "CENTRE", "tri": true, "desc": false},
		{"k": "n", "t": "JEUNES", "w": 120, "tri": true},
		{"k": "cand", "t": "CANDIDATS", "w": 110},
		{"k": "pot", "t": "MEILLEUR POT.", "w": 92, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "act", "t": "", "w": 118},
	]
	var meilleur := func(c: Dictionary) -> float:
		var m := -1.0
		for p: Dictionary in c.get("candidates", []): m = maxf(m, V.valeur(p, "potential"))
		return m
	var cellule := func(cel: Control, col: Dictionary, c: Dictionary):
		match str(col.k):
			"nom":
				_blason(cel, str(c.name), V.MINUTES if c.scouted else Charte.IVOIRE_3)
				_txt(cel, c.name, CORPS, Charte.IVOIRE, C.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
			"n":
				_barre(cel, float(c.count) / max_n, V.MINUTES if c.scouted else Charte.IVOIRE_2, 6.0)
				var l := _txt(cel, G.n(c.count), PETIT, V.MINUTES if c.scouted else Charte.IVOIRE_2, C.BOLD, HORIZONTAL_ALIGNMENT_RIGHT)
				l.custom_minimum_size.x = 26
			"cand":
				for p: Dictionary in c.get("candidates", []).slice(0, 4):
					_portrait(cel, p, 24)
			"pot":
				var m: float = meilleur.call(c)
				_cel(cel, col, "—" if m < 0 else str(roundi(m)), V.couleur(m), Charte.TITRE_EXTRA, 17)
			"act":
				if c.scouted: _pastille(cel, "Observé", V.PROGRES, "check")
				else: _pastille(cel, "Observer · " + V.euros(observe), V.DEPENSE, "search")
	var cle := func(c: Dictionary, k: String) -> Variant:
		match k:
			"nom": return str(c.name)
			"n": return int(c.count)
			"pot": return meilleur.call(c)
		return null
	var au_clic := func(c: Dictionary, _l: Control):
		if verrou: return
		if c.scouted: (_fenetre(ctx, func(): T._fenetre_candidats(ctx, c))).call()
		else: V.envoyer(ctx, "academy_center_scout", {"centerId": str(c.id)}, observe, "Observer " + str(c.name))
	var groupes: Array = [["Observés", V.MINUTES, func(c: Dictionary): return c.scouted], ["À observer", Charte.IVOIRE_3, func(c: Dictionary): return not c.scouted]]
	var filtres := func(fl: Control):
		for d: Array in [["", "Tous", Charte.IVOIRE, G.n(centres.size())], ["vus", "Observés", V.MINUTES, G.n(vus.size())], ["avoir", "À observer", Charte.IVOIRE_2, G.n(centres.size() - vus.size())]]:
			var valeur := str(d[0])
			_pilule(fl, str(d[1]), d[2], filtre == valeur, func():
				ctx.state.filtre_centres = valeur
				(ctx.reconstruire as Callable).call(), "CentresFiltre_" + valeur, str(d[3]))
	_liste(ctx, parent, colonnes, montres, cellule, cle, au_clic, func(c: Dictionary, _r: int): return "CentreLigne_" + str(c.id).validate_node_name(), "CentresListe", filtres, groupes, ["n", true])

# --- Filières : régions, clubs formateurs et jeunes repérés ------------------------------------------------------------

static func _filieres(ctx: Dictionary, parent: Node) -> void:
	var data: Dictionary = ctx.data
	var verrou: bool = data.get("locked", false)
	var prospects: Array = data.get("prospects", [])
	var regions: Array = data.get("regions", [])
	var region_f := str(ctx.state.get("region", ""))
	var discover := V.cout(ctx, "discover", 3000)
	var partner := V.cout(ctx, "partner", 2000)
	var reg := _panneau(parent, "Régions", "globe", "FilieresRegions")
	var flux := _flux(reg, 6)
	for i in regions.size():
		var region := str(regions[i])
		var teinte: Color = V.COULEURS[i % V.COULEURS.size()]
		var n := prospects.filter(func(p: Dictionary): return str(p.region) == region).size()
		var choisi := region == region_f
		var b := _zone(V.aller(ctx, "Filières", "region", "" if choisi else region), "FilieresRegion%d" % i, region, 8, 36.0, Charte.PANNEAU_2.lerp(teinte, .3) if choisi else Color.TRANSPARENT, teinte if choisi else Color.TRANSPARENT)
		b.custom_minimum_size.x = 236.0
		var h := _dans(b, 8, 8)
		var rond := Panel.new()
		rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rond.custom_minimum_size = Vector2(10, 10)
		rond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rond.add_theme_stylebox_override("panel", V.plat(teinte, Color.TRANSPARENT, 0, Charte.RAYON_PILULE))
		h.add_child(rond)
		_txt(h, region, CORPS, Charte.IVOIRE, C.BOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
		_chiffre(h, G.n(n), 20, teinte, HORIZONTAL_ALIGNMENT_RIGHT)
		_pilule(h, V.euros(discover), V.DEPENSE, false, func(): V.envoyer(ctx, "academy_discover", {"region": region}, discover, "Détecter · " + region), "FilieresDetecter%d" % i, "", not verrou)
		flux.add_child(b)
	var feeders: Array = data.get("feeders", [])
	var partenaires: Array = data.get("partners", [])
	var fp := _panneau(parent, "Clubs formateurs", "flag", "FilieresFormateurs", Callable(), G.n(partenaires.size()), V.PROGRES)
	var ff := _flux(fp, 6)
	for f: Dictionary in feeders:
		var fid := str(f.id)
		var ok := partenaires.has(fid)
		var nom_f := str(f.name)
		var b := _zone(func(): T._partenariat(ctx, fid, nom_f, ok or verrou, partner), "FilieresFormateur_" + fid.validate_node_name(), nom_f, 6, 30.0)
		b.custom_minimum_size.x = 276.0
		var h := _dans(b, 8, 8)
		_icone(h, "check" if ok else "flag", 16, V.PROGRES if ok else Charte.IVOIRE_3)
		_txt(h, nom_f, CORPS, Charte.IVOIRE if ok else Charte.IVOIRE_2, C.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
		_txt(h, "Partenaire" if ok else V.euros(partner), PETIT, V.PROGRES if ok else V.DEPENSE, C.BOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		ff.add_child(b)
	var filtre := str(ctx.state.get("filtre_prospects", ""))
	var garde := func(p: Dictionary, f: String) -> bool:
		match f:
			"zero": return int(p.scouted) == 0
			"suivis": return int(p.scouted) > 0 and not p.trial
			"essai": return bool(p.trial)
		return true
	var dans_region := prospects.filter(func(p: Dictionary): return region_f.is_empty() or str(p.region) == region_f)
	var montres := dans_region.filter(func(p: Dictionary): return garde.call(p, filtre))
	var watch := V.cout(ctx, "watch", 500)
	var trial := V.cout(ctx, "trial", 1000)
	var recruit := V.cout(ctx, "recruit", 8000)
	var colonnes := [
		{"k": "nom", "t": "JOUEUR", "tri": true, "desc": false},
		{"k": "poste", "t": "POSTE", "w": 108, "tri": true, "desc": false},
		{"k": "age", "t": "ÂGE", "w": 34, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "pot", "t": "POT.", "w": 40, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "obs", "t": "OBS.", "w": 62, "tri": true},
		{"k": "essai", "t": "ESSAI", "w": 56, "tri": true},
		{"k": "suite", "t": "", "w": 128},
	]
	var cellule := func(cel: Control, col: Dictionary, p: Dictionary):
		match str(col.k):
			"nom": _cel_joueur(ctx, cel, p, "", str(p.clubName))
			"poste": _cel(cel, col, p.pos, Charte.IVOIRE)
			"age": _cel(cel, col, G.n(p.age), Charte.IVOIRE_2)
			"pot":
				var vu := int(p.scouted) > 0
				_cel(cel, col, V.potentiel_txt(p) if vu else "?", V.couleur_champ(p, "potential") if vu else Charte.IVOIRE_3, Charte.TITRE_EXTRA, 17)
			"obs":
				_crans(cel, int(p.scouted), 3, V.MINUTES)
				_txt(cel, "%d/3" % int(p.scouted), PETIT, V.MINUTES if int(p.scouted) > 0 else Charte.IVOIRE_3, C.BOLD)
			"essai":
				if p.trial: _pastille(cel, "Fait", V.PROGRES, "check")
				else: _cel(cel, col, "—", Charte.IVOIRE_3)
			"suite":
				var s := T._suite_prospect(p, watch, trial, recruit)
				if not s.is_empty(): _pastille(cel, str(s[1]), s[2], str(s[3]))
	var cle := func(p: Dictionary, k: String) -> Variant:
		match k:
			"nom": return str(p.name)
			"poste": return str(p.pos)
			"age": return int(p.age)
			"pot": return V.valeur(p, "potential") if int(p.scouted) > 0 else -1.0
			"obs": return int(p.scouted)
			"essai": return 1 if p.trial else 0
		return null
	var filtres := func(fl: Control):
		for d: Array in [["", "Tous", Charte.IVOIRE, G.n(dans_region.size())], ["zero", "À observer", Charte.IVOIRE_2, G.n(dans_region.filter(func(p: Dictionary): return garde.call(p, "zero")).size())], ["suivis", "Observés", V.MINUTES, G.n(dans_region.filter(func(p: Dictionary): return garde.call(p, "suivis")).size())], ["essai", "Essai fait", V.PROGRES, G.n(dans_region.filter(func(p: Dictionary): return garde.call(p, "essai")).size())]]:
			var valeur := str(d[0])
			_pilule(fl, str(d[1]), d[2], filtre == valeur, func():
				ctx.state.filtre_prospects = valeur
				(ctx.reconstruire as Callable).call(), "FilieresFiltre_" + valeur, str(d[3]))
	_liste(ctx, parent, colonnes, montres, cellule, cle, func(p: Dictionary, _l: Control): (_fenetre(ctx, func(): T._fenetre_prospect(ctx, p))).call(), func(p: Dictionary, _r: int): return "FilieresJeune_" + str(p.id).validate_node_name(), "FilieresListe", filtres, [], ["obs", true])

# --- Passerelle pro : jeunes pros, prêts, retours -------------------------------------------------------------------------

static func _passerelle(ctx: Dictionary, parent: Node) -> void:
	var data: Dictionary = ctx.data
	var jeunes: Array = data.get("seniors", []).filter(func(s: Dictionary): return int(s.age) <= 23 or s.get("loanEligible", false))
	var prets: Array = data.get("loans", [])
	var hotes := {}
	for cl: Dictionary in data.get("loanClubs", []): hotes[int(cl.id)] = str(cl.name)
	var elements: Array = jeunes.duplicate()
	for pr: Dictionary in prets:
		var e := pr.duplicate()
		e.pret = true
		e.hote = hotes.get(int(pr.to), "club %d" % int(pr.to))
		elements.append(e)
	var pretables := jeunes.filter(func(s: Dictionary): return s.get("loanEligible", false))
	var etape := str(ctx.state.get("etape_pro", ""))
	var etapes := [
		["jeunes", "Jeunes pros", V.PROGRES, jeunes.size()],
		["pretables", "Prêtables", V.MINUTES, pretables.size()],
		["prets", "En prêt", V.REPUTATION, prets.size()],
	]
	_chemin(ctx, parent, etapes, etape, "etape_pro", "PasserelleChemin", ["Retour", G.n(prets.size()), V.COHESION, "à l’intersaison", Callable()])
	var montres := elements.filter(func(e: Dictionary): return T._garde_pro(e, etape))
	var colonnes := [
		{"k": "nom", "t": "JOUEUR", "tri": true, "desc": false},
		{"k": "poste", "t": "POSTE", "w": 108, "tri": true, "desc": false},
		{"k": "age", "t": "ÂGE", "w": 34, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "niv", "t": "NIV.", "w": 40, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "pot", "t": "POT.", "w": 48, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "statut", "t": "STATUT", "w": 176},
	]
	var cellule := func(cel: Control, col: Dictionary, e: Dictionary):
		var pret: bool = e.get("pret", false)
		match str(col.k):
			"nom": _cel_joueur(ctx, cel, e, "" if pret else "squad")
			"poste": _cel(cel, col, e.get("pos", "—"), Charte.IVOIRE)
			"age": _cel(cel, col, G.n(e.get("age", "—")), Charte.IVOIRE_2)
			"niv": _cel(cel, col, V.niveau_txt(e) if not pret else "—", V.couleur_champ(e, "rating"), Charte.TITRE_EXTRA, 17)
			"pot": _cel(cel, col, V.potentiel_txt(e) if not pret else "—", V.couleur_champ(e, "potential"), Charte.TITRE_EXTRA, 17)
			"statut":
				if pret: _pastille(cel, "En prêt · " + str(e.hote), V.REPUTATION, "bus")
				elif e.get("loanEligible", false): _pastille(cel, "Prêtable · Prêter", V.MINUTES, "bus")
				else: _pastille(cel, "Effectif", Charte.IVOIRE_3, "lock")
	var cle := func(e: Dictionary, k: String) -> Variant:
		match k:
			"nom": return str(e.get("name", ""))
			"poste": return str(e.get("pos", ""))
			"age": return int(e.get("age", 0))
			"niv": return V.valeur(e, "rating")
			"pot": return V.valeur(e, "potential")
		return null
	var au_clic := func(e: Dictionary, _l: Control):
		if e.get("pret", false): return
		var sid := str(e.id)
		if e.get("loanEligible", false) and not ctx.data.get("locked", false): (_fenetre(ctx, func(): T._fenetre_pret(ctx, sid))).call()
		else: V.ouvrir_fiche(ctx, sid)
	var groupes: Array = [["Prêtables", V.MINUTES, func(e: Dictionary): return e.get("loanEligible", false) and not e.get("pret", false)], ["En effectif", Charte.IVOIRE_3, func(e: Dictionary): return not e.get("loanEligible", false) and not e.get("pret", false)], ["En prêt", V.REPUTATION, func(e: Dictionary): return e.get("pret", false)]]
	var filtres := func(fl: Control):
		for d: Array in [["", "Tous", Charte.IVOIRE, G.n(elements.size())], ["pretables", "Prêtables", V.MINUTES, G.n(pretables.size())], ["prets", "En prêt", V.REPUTATION, G.n(prets.size())]]:
			var valeur := str(d[0])
			_pilule(fl, str(d[1]), d[2], etape == valeur, func():
				ctx.state.etape_pro = valeur
				(ctx.reconstruire as Callable).call(), "PasserelleFiltre_" + valeur, str(d[3]))
	_liste(ctx, parent, colonnes, montres, cellule, cle, au_clic, func(e: Dictionary, _r: int): return "PasserelleLigne_" + str(e.get("id", e.get("name", ""))).validate_node_name(), "PasserelleListe", filtres, groupes, ["age", false])

# --- Générations : la frise des saisons ------------------------------------------------------------------------------------

static func _generations(ctx: Dictionary, parent: Node) -> void:
	var data: Dictionary = ctx.data
	var gens: Array = data.get("generations", []).duplicate()
	var frise_def: Array = []
	for g: Dictionary in gens:
		frise_def.append({"titre": G.season_label(g.season), "joueurs": g.players, "promus": int(g.get("graduates", 0)), "reputation": int(g.get("reputation", 0))})
	frise_def.append({"titre": "En cours", "joueurs": data.get("players", []), "promus": data.get("promotions", []).size(), "reputation": int(data.get("reputation", 0)), "courante": true})
	var choix := clampi(int(ctx.state.get("generation", frise_def.size() - 1)), 0, frise_def.size() - 1)
	var frise := _panneau(parent, "La frise des générations", "trophy", "GenerationsFrise")
	var defile := ScrollContainer.new()
	defile.name = "GenerationsFriseDefile"
	defile.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.custom_minimum_size.y = 128
	frise.add_child(defile)
	var rail := _rangee(defile, ECART)
	var max_j := 1
	for f: Dictionary in frise_def: max_j = maxi(max_j, (f.joueurs as Array).size())
	for i in frise_def.size():
		var f: Dictionary = frise_def[i]
		var choisi := i == choix
		var teinte := V.MINUTES if f.get("courante", false) else V.REPUTATION
		var b := _zone(V.aller(ctx, "Générations", "generation", i), "GenerationsSaison%d" % i, str(f.titre), Charte.RAYON_CARTE, 116.0, Charte.PANNEAU_2.lerp(teinte, .18) if choisi else Charte.PANNEAU_2, teinte if choisi else Color.TRANSPARENT)
		b.custom_minimum_size.x = 210.0
		var m := MarginContainer.new()
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for cote: String in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + cote, 10)
		b.add_child(m)
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(v)
		var tete := _rangee(v, 6)
		var pt := Panel.new()
		pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pt.custom_minimum_size = Vector2(10, 10)
		pt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pt.add_theme_stylebox_override("panel", V.plat(teinte, Color.TRANSPARENT, 0, Charte.RAYON_PILULE))
		tete.add_child(pt)
		_txt(tete, str(f.titre).to_upper(), 18, Charte.IVOIRE, Charte.TITRE_FICHE)
		for br: Array in [[(f.joueurs as Array).size(), max_j, "JOUEURS", V.PROGRES], [int(f.promus), maxi(1, max_j / 4), "PROMUS", V.DEPENSE], [int(f.reputation), 100, "RÉPUTATION", V.REPUTATION]]:
			var r := _rangee(v, 6)
			r.custom_minimum_size.y = 20
			var t := _txt(r, br[2], PETIT, Charte.IVOIRE_2, C.BOLD)
			t.custom_minimum_size.x = 76
			_barre(r, float(br[0]) / float(br[1]), br[3], 8.0)
			var c := _chiffre(r, G.n(br[0]), 16, br[3], HORIZONTAL_ALIGNMENT_RIGHT)
			c.custom_minimum_size.x = 26
		rail.add_child(b)
	var f: Dictionary = frise_def[choix]
	var joueurs: Array = f.joueurs
	var colonnes := [
		{"k": "nom", "t": "JOUEUR", "tri": true, "desc": false},
		{"k": "poste", "t": "POSTE", "w": 108, "tri": true, "desc": false},
		{"k": "age", "t": "ÂGE", "w": 34, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "niv", "t": "NIV.", "w": 40, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "pot", "t": "POT.", "w": 48, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "min", "t": "MIN.", "w": 50, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "traj", "t": "TRAJECTOIRE", "w": 112, "tri": true, "desc": false},
	]
	var cellule := func(cel: Control, col: Dictionary, p: Dictionary):
		match str(col.k):
			"nom": _cel_joueur(ctx, cel, p, "academy" if not V.joueur(data, str(p.id)).is_empty() else "")
			"poste": _cel(cel, col, p.pos, Charte.IVOIRE)
			"age": _cel(cel, col, G.n(p.age), Charte.IVOIRE_2)
			"niv": _cel(cel, col, V.niveau_txt(p), V.couleur_champ(p, "rating"), Charte.TITRE_EXTRA, 17)
			"pot": _cel(cel, col, V.potentiel_txt(p), V.couleur_champ(p, "potential"), Charte.TITRE_EXTRA, 17)
			"min": _cel(cel, col, V.mille(p.get("minutes", 0)), V.MINUTES, C.BOLD)
			"traj":
				var t := V.trajectoire(str(p.get("path", p.get("strategy", "equilibre"))))
				_pastille(cel, str(t[1]), t[3], str(t[2]))
	var cle := func(p: Dictionary, k: String) -> Variant:
		match k:
			"nom": return str(p.name)
			"poste": return str(p.pos)
			"age": return int(p.age)
			"niv": return V.valeur(p, "rating")
			"pot": return V.valeur(p, "potential")
			"min": return int(p.get("minutes", 0))
			"traj": return str(p.get("path", p.get("strategy", "")))
		return null
	var au_clic := func(p: Dictionary, _l: Control):
		var pid := str(p.id)
		if not V.joueur(data, pid).is_empty(): (_fenetre(ctx, func(): V.fenetre_parcours(ctx, pid))).call()
		else: V.ouvrir_fiche(ctx, pid)
	var table := _liste(ctx, parent, colonnes, joueurs, cellule, cle, au_clic, func(p: Dictionary, _r: int): return "GenerationsJoueur_" + str(p.id).validate_node_name(), "GenerationsListe", Callable(), [], ["pot", true])
	table.set_meta("courante", f.get("courante", false))
