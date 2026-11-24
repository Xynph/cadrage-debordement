extends "res://ui/immersive08/centre_compact_socle.gd"
## Centre compact : pièces composées (pilule, panneau à titre, lignes de chiffres, jauges, portrait, blason), tuile, en-tête et
## onglets (découpe de centre_compact.gd, sans changement).

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
