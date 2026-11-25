extends "res://ui/immersive08/centre_compact_pieces.gd"
## Centre compact : listes à lignes (groupes, ligne, cellules, cellule joueur) et chemin en étapes (découpe de centre_compact.gd,
## sans changement).

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
	if not source.is_empty() and not str(p.get("id", "")).is_empty(): CarteSurvol.lier_info(ctx.app, nom, str(p.id), source)

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
