extends RefCounted
## Observer la préparation : deux options visuelles à départager (revue du 21/11/2026, n° 7), provisoires.
## CD_VARIANTE_VISUELLE=A : lignes joueur (portrait, prénom / NOM, jauges condition et charge, pastille blessure).
## CD_VARIANTE_VISUELLE=B : grille de portraits à anneau de condition, triée, et plans en tuiles à icône.
## Sans la variable : rien de ce fichier n'est utilisé (écran actuel).
## Tout est cliquable : un joueur ouvre sa petite fenêtre (Échap, ✕ ou clic à côté la ferment), d'où l'on ouvre sa fiche.
const S = preload("res://ui/contextual/skin.gd")
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")

const LARGEUR_COLONNE := 500.0

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

# --- Données lues (aucun calcul de jeu) -----------------------------------------------------------

static func charge(joueur: Dictionary) -> float:
	var f: Variant = joueur.get("physicalLoad", {})
	if f is Dictionary: f = f.get("fatigue", 0)
	return clampf(float(f) if (f is int or f is float) else 0.0, 0.0, 100.0)

static func condition(joueur: Dictionary) -> float:
	var c: Variant = joueur.get("condition", 0)
	return clampf(float(c) if (c is int or c is float) else 0.0, 0.0, 100.0)

static func blessure(joueur: Dictionary) -> int:
	return int(joueur.get("injury", 0))

## Couleur de la condition : vert franc au-dessus de 75, orange à surveiller, rouge sous 60 (toujours avec le chiffre).
static func couleur_condition(valeur: float) -> Color:
	if valeur >= 75.0: return Charte.CONDITION
	if valeur >= 60.0: return Charte.INTENSIF
	return Charte.PERTE

## Couleur de la charge : turquoise faible, orange soutenue, rouge au-delà du seuil de repos (45).
static func couleur_charge(valeur: float) -> Color:
	if valeur >= 45.0: return Charte.PERTE
	if valeur >= 25.0: return Charte.INTENSIF
	return Charte.REPOS

static func prenom_nom(joueur: Dictionary) -> Array:
	var complet := str(joueur.get("name", "")).strip_edges()
	var coupure := complet.find(" ")
	if coupure <= 0: return ["", complet]
	return [complet.substr(0, coupure), complet.substr(coupure + 1)]

# --- Petits composants -----------------------------------------------------------------------------

static func texte(valeur: Variant, taille: int, couleur: Color, police: Font = null) -> Label:
	var l := Label.new()
	l.text = str(valeur)
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_font_override("font", police if police != null else C.BOLD)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func carte(fond: Color = Charte.PANNEAU_2, rayon: int = Charte.RAYON_CARTE, marge: int = 8) -> PanelContainer:
	var p := PanelContainer.new()
	var style := Charte.style_panneau(fond, rayon, marge)
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Pictogramme (icon-paths.json) à taille fixe : les polices du jeu n'ont ni ♥ ni ✚ ni ▲.
static func icone(id: String, cote: float, couleur: Color) -> TextureRect:
	var r := TextureRect.new()
	r.texture = C.icon_texture(id, couleur)
	r.custom_minimum_size = Vector2(cote, cote)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Croix de blessure dessinée (pastille rouge, croix ivoire).
class Croix extends Control:
	var couleur := Color.WHITE
	var fond := Color.TRANSPARENT
	func _draw() -> void:
		var c := minf(size.x, size.y)
		var o := (size - Vector2(c, c)) / 2.0
		if fond.a > 0.0: draw_rect(Rect2(o, Vector2(c, c)), fond)
		var e := c * 0.2
		draw_rect(Rect2(o + Vector2((c - e) / 2.0, c * 0.2), Vector2(e, c * 0.6)), couleur)
		draw_rect(Rect2(o + Vector2(c * 0.2, (c - e) / 2.0), Vector2(c * 0.6, e)), couleur)

static func croix(cote: float, couleur: Color, fond: Color = Color.TRANSPARENT) -> Croix:
	var x := Croix.new()
	x.couleur = couleur
	x.fond = fond
	x.custom_minimum_size = Vector2(cote, cote)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return x

static func signe(id: String, cote: float, couleur: Color) -> Control:
	return croix(cote, couleur) if id == "croix" else icone(id, cote, couleur)

## Pastille : voile de la couleur, signe + mot dans la couleur (jamais la couleur seule).
static func pastille(signe_id: String, mot: String, couleur: Color, taille: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	var style := Charte.style_pilule(Color(couleur, .18), Color.TRANSPARENT, 8, 2)
	style.set_corner_radius_all(Charte.RAYON_PETIT)
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 5)
	if not signe_id.is_empty(): rangee.add_child(signe(signe_id, taille, couleur))
	rangee.add_child(texte(mot, taille, couleur))
	p.add_child(rangee)
	return p

## Contenu cliquable : un MarginContainer porte le contenu et, par-dessus, un bouton plat de même taille (survol ivoire 8 %,
## focus clavier). Le conteneur prend la taille réelle du contenu (aucune mesure avant l'entrée dans l'arbre).
## Le bouton est rangé dans la méta « bouton » du conteneur rendu.
static func cliquable(contenu: Control, action: Callable, nom: String, bulle: String = "") -> MarginContainer:
	var boite := MarginContainer.new()
	boite.name = nom
	for bord in ["left", "right", "top", "bottom"]: boite.add_theme_constant_override("margin_" + bord, 0)
	boite.add_child(contenu)
	_ignorer(contenu)
	var b := Button.new()
	b.name = "Bouton"
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = bulle
	var vide := StyleBoxFlat.new()
	vide.bg_color = Color.TRANSPARENT
	vide.set_corner_radius_all(Charte.RAYON_CARTE)
	var survol := vide.duplicate() as StyleBoxFlat
	survol.bg_color = Color(Charte.IVOIRE, .08)
	var focus := vide.duplicate() as StyleBoxFlat
	focus.set_border_width_all(2)
	focus.border_color = Charte.IVOIRE
	for etat in ["normal", "disabled"]: b.add_theme_stylebox_override(etat, vide)
	for etat in ["hover", "pressed"]: b.add_theme_stylebox_override(etat, survol)
	b.add_theme_stylebox_override("focus", focus)
	b.pressed.connect(action)
	boite.add_child(b)
	boite.set_meta("bouton", b)
	return boite

static func _ignorer(n: Node) -> void:
	if n is Control: (n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for e in n.get_children(): _ignorer(e)

## Jauge horizontale pleine : rail sombre, remplissage coloré.
class Jauge extends Control:
	var valeur := 0.0
	var couleur := Color.WHITE
	func _draw() -> void:
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Charte.PANNEAU_3)
		var w := size.x * clampf(valeur / 100.0, 0.0, 1.0)
		if w > 0.0: draw_rect(Rect2(0, 0, w, h), couleur)

static func jauge(valeur: float, couleur: Color, largeur: float, hauteur: float = 8.0) -> Jauge:
	var j := Jauge.new()
	j.valeur = valeur
	j.couleur = couleur
	j.custom_minimum_size = Vector2(largeur, hauteur)
	j.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	j.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return j

## Anneau de condition autour d'un portrait (ou seul) : arc coloré proportionnel à la valeur.
class Anneau extends Control:
	var valeur := 0.0
	var couleur := Color.WHITE
	var epaisseur := 5.0
	func _draw() -> void:
		var centre := size / 2.0
		var rayon := minf(size.x, size.y) / 2.0 - epaisseur / 2.0
		draw_arc(centre, rayon, 0.0, TAU, 64, Charte.PANNEAU_3, epaisseur, true)
		var fin := -PI / 2.0 + TAU * clampf(valeur / 100.0, 0.0, 1.0)
		if valeur > 0.0: draw_arc(centre, rayon, -PI / 2.0, fin, 64, couleur, epaisseur, true)

## Portrait entouré de son anneau de condition ; croix rouge en coin si blessé.
static func portrait_anneau(joueur: Dictionary, cote: float, epaisseur: float = 5.0) -> Control:
	var boite := Control.new()
	boite.custom_minimum_size = Vector2(cote, cote)
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var valeur := condition(joueur)
	var marge := epaisseur + 3.0
	var image := S.G.portrait(int(joueur.get("portraitIndex", 0)), int(cote - 2.0 * marge), joueur)
	image.position = Vector2(marge, marge)
	image.size = Vector2(cote - 2.0 * marge, cote - 2.0 * marge)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	boite.add_child(image)
	var anneau := Anneau.new()
	anneau.valeur = valeur
	anneau.couleur = couleur_condition(valeur)
	anneau.epaisseur = epaisseur
	anneau.position = Vector2.ZERO
	anneau.size = Vector2(cote, cote)
	boite.add_child(anneau)
	if blessure(joueur) > 0:
		var d := cote * 0.34
		var badge := croix(d, Charte.IVOIRE, Charte.PERTE)
		badge.position = Vector2(cote - d, 0)
		badge.size = Vector2(d, d)
		boite.add_child(badge)
	return boite

## Prénom petit, NOM gras, sur deux lignes ; la taille baisse si le nom dépasse (jamais tronqué).
static func nom_deux_lignes(joueur: Dictionary, largeur: float, taille_nom: int = 19) -> VBoxContainer:
	var bloc := VBoxContainer.new()
	bloc.add_theme_constant_override("separation", -4)
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts := prenom_nom(joueur)
	if not str(parts[0]).is_empty(): bloc.add_child(texte(parts[0], _taille(str(parts[0]), 14, C.MEDIUM, largeur), Charte.IVOIRE_2, C.MEDIUM))
	bloc.add_child(texte(str(parts[1]).to_upper(), _taille(str(parts[1]).to_upper(), taille_nom, C.EXTRA_BOLD, largeur), Charte.IVOIRE, C.EXTRA_BOLD))
	return bloc

static func _taille(valeur: String, taille: int, police: Font, largeur: float) -> int:
	var t := taille
	while t > 11 and police.get_string_size(valeur, HORIZONTAL_ALIGNMENT_LEFT, -1, t).x > largeur - 2.0: t -= 1
	return t

# --- Colonne « État du groupe » --------------------------------------------------------------------

## Trois tuiles de comptage en tête de colonne (aptes, blessés, chargés), toutes cliquables : elles filtrent la liste.
static func tuiles_groupe(vue: Control, effectif: Array) -> HBoxContainer:
	var aptes := 0
	var blesses := 0
	var charges := 0
	for j: Dictionary in effectif:
		if blessure(j) > 0: blesses += 1
		else: aptes += 1
		if charge(j) >= 45.0: charges += 1
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 8)
	var filtre := str(vue.get_meta("filtre_groupe", ""))
	for t: Array in [["aptes", aptes, "APTES", Charte.CONDITION, "check"], ["blesses", blesses, "BLESSÉS", Charte.PERTE, "croix"], ["charges", charges, "CHARGÉS", Charte.INTENSIF, "train"]]:
		var tuile := carte(Charte.PANNEAU_2.lerp(t[3], .16 if filtre == t[0] else .08), Charte.RAYON_CARTE, 6)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -2)
		var haut := HBoxContainer.new()
		haut.add_theme_constant_override("separation", 6)
		haut.add_child(signe(t[4], 20, t[3]))
		haut.add_child(texte(str(t[1]), 30, t[3], C.EXTRA_BOLD))
		col.add_child(haut)
		col.add_child(texte(t[2], 13, Charte.IVOIRE_2, C.MEDIUM))
		tuile.add_child(col)
		if filtre == t[0]:
			var style := (tuile.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
			style.set_border_width_all(2)
			style.border_color = t[3]
			tuile.add_theme_stylebox_override("panel", style)
		var cle: String = t[0]
		var bouton := cliquable(tuile, func():
			vue.set_meta("filtre_groupe", "" if str(vue.get_meta("filtre_groupe", "")) == cle else cle)
			vue.call("_draw"), "TrainingGroupTile_" + cle, "%d %s" % [t[1], str(t[2]).to_lower()])
		bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rangee.add_child(bouton)
	return rangee

static func filtrer(vue: Control, effectif: Array) -> Array:
	var filtre := str(vue.get_meta("filtre_groupe", ""))
	return effectif.filter(func(j: Dictionary) -> bool:
		match filtre:
			"aptes": return blessure(j) <= 0
			"blesses": return blessure(j) > 0
			"charges": return charge(j) >= 45.0
		return true)

## Option A : une ligne par joueur.
static func ligne_joueur(vue: Control, joueur: Dictionary) -> Control:
	var fond := carte(Charte.PANNEAU_2, Charte.RAYON_CARTE, 6)
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 10)
	fond.add_child(rangee)
	var image := S.G.portrait(int(joueur.get("portraitIndex", 0)), 44, joueur)
	image.custom_minimum_size = Vector2(44, 52)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rangee.add_child(image)
	var nom := nom_deux_lignes(joueur, 140)
	nom.custom_minimum_size.x = 140
	nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(nom)
	var jauges := VBoxContainer.new()
	jauges.add_theme_constant_override("separation", 2)
	jauges.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jauges.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(jauges)
	var cond := condition(joueur)
	var chg := charge(joueur)
	for m: Array in [["heart", cond, Charte.CONDITION], ["train", chg, couleur_charge(chg)]]:
		var l := HBoxContainer.new()
		l.add_theme_constant_override("separation", 6)
		l.add_child(icone(m[0], 15, m[2]))
		var j := jauge(m[1], m[2], 80, 7)
		j.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_child(j)
		var chiffre := texte(str(roundi(m[1])), 17, Charte.IVOIRE, C.EXTRA_BOLD)
		chiffre.custom_minimum_size.x = 30
		chiffre.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.add_child(chiffre)
		jauges.add_child(l)
	var semaines := blessure(joueur)
	if semaines > 0: rangee.add_child(pastille("croix", "%d sem." % semaines, Charte.PERTE, 14))
	return cliquable(fond, func(): ouvrir_joueur(vue, joueur), "TrainingPlayerRow_" + str(joueur.get("id", "")).validate_node_name(), str(joueur.get("name", "")))

## Option B : une case de la grille (portrait à anneau, chiffre de condition, NOM).
static func case_joueur(vue: Control, joueur: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var p := portrait_anneau(joueur, 74, 5)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(p)
	var cond := condition(joueur)
	var chiffre := texte(str(roundi(cond)), 19, couleur_condition(cond), C.EXTRA_BOLD)
	chiffre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(chiffre)
	var nom_seul := str(prenom_nom(joueur)[1]).to_upper()
	var nom := texte(nom_seul, _taille(nom_seul, 14, C.BOLD, 104), Charte.IVOIRE, C.BOLD)
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom.custom_minimum_size.x = 104
	col.add_child(nom)
	var b := cliquable(col, func(): ouvrir_joueur(vue, joueur), "TrainingPlayerCell_" + str(joueur.get("id", "")).validate_node_name(), str(joueur.get("name", "")))
	b.custom_minimum_size = Vector2(108, 122)
	return b

static func colonne_groupe(vue: Control, parent: Container, effectif: Array, var_: String) -> void:
	parent.add_child(tuiles_groupe(vue, effectif))
	var liste := filtrer(vue, effectif)
	if var_ == "B":
		liste.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return condition(a) < condition(b))
		var grille := GridContainer.new()
		grille.columns = 4
		grille.add_theme_constant_override("h_separation", 6)
		grille.add_theme_constant_override("v_separation", 6)
		for j: Dictionary in liste: grille.add_child(case_joueur(vue, j))
		parent.add_child(grille)
	else:
		for j: Dictionary in liste: parent.add_child(ligne_joueur(vue, j))

# --- Petite fenêtre du joueur ----------------------------------------------------------------------

static func ouvrir_joueur(vue: Control, joueur: Dictionary) -> void:
	fermer_joueur(vue)
	var calque := Control.new()
	calque.name = "TrainingPlayerWindow"
	calque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	calque.mouse_filter = Control.MOUSE_FILTER_STOP
	vue.add_child(calque)
	var voile := Button.new()
	voile.name = "TrainingPlayerVeil"
	voile.flat = true
	voile.focus_mode = Control.FOCUS_NONE
	var fond_voile := StyleBoxFlat.new()
	fond_voile.bg_color = Color(0, 0, 0, .5)
	for etat in ["normal", "hover", "pressed", "focus"]: voile.add_theme_stylebox_override(etat, fond_voile)
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	voile.pressed.connect(func(): fermer_joueur(vue))
	calque.add_child(voile)
	var panneau := carte(Charte.PANNEAU, Charte.RAYON_PANNEAU, 22)
	panneau.add_theme_stylebox_override("panel", Charte.ombrer(Charte.style_panneau(Charte.PANNEAU, Charte.RAYON_PANNEAU, 22), Charte.RAYON_PANNEAU))
	panneau.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panneau.custom_minimum_size = Vector2(560, 0)
	panneau.mouse_filter = Control.MOUSE_FILTER_STOP
	calque.add_child(panneau)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panneau.add_child(col)
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", 16)
	col.add_child(haut)
	haut.add_child(portrait_anneau(joueur, 128, 8))
	var ident := VBoxContainer.new()
	ident.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ident.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ident.add_child(nom_deux_lignes(joueur, 300, 30))
	var poste := str(joueur.get("pos", joueur.get("position", "")))
	if not poste.is_empty(): ident.add_child(texte(poste, 17, Charte.IVOIRE_2, C.MEDIUM))
	haut.add_child(ident)
	var fermer := Button.new()
	fermer.name = "TrainingPlayerClose"
	fermer.text = "×"
	fermer.tooltip_text = "Fermer"
	fermer.flat = true
	fermer.add_theme_font_size_override("font_size", 22)
	fermer.add_theme_color_override("font_color", Charte.IVOIRE_2)
	fermer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	fermer.pressed.connect(func(): fermer_joueur(vue))
	haut.add_child(fermer)
	var tuiles := HBoxContainer.new()
	tuiles.add_theme_constant_override("separation", 10)
	col.add_child(tuiles)
	var cond := condition(joueur)
	var chg := charge(joueur)
	for t: Array in [["heart", str(roundi(cond)), "CONDITION", couleur_condition(cond), cond], ["train", str(roundi(chg)), "CHARGE", couleur_charge(chg), chg]]:
		var tuile := carte(Charte.PANNEAU_2.lerp(t[3], .1), Charte.RAYON_CARTE, 10)
		tuile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		var l := HBoxContainer.new()
		l.add_theme_constant_override("separation", 6)
		l.add_child(icone(t[0], 22, t[3]))
		l.add_child(texte(t[1], 34, Charte.IVOIRE, C.EXTRA_BOLD))
		v.add_child(l)
		v.add_child(jauge(t[4], t[3], 200, 8))
		v.add_child(texte(t[2], 13, Charte.IVOIRE_2, C.MEDIUM))
		tuile.add_child(v)
		tuiles.add_child(tuile)
	var semaines := blessure(joueur)
	col.add_child(pastille("croix", "Blessé · %d sem." % semaines, Charte.PERTE, 17) if semaines > 0 else pastille("check", "Apte", Charte.CONDITION, 17))
	var fiche := S.button("Ouvrir la fiche", func():
		fermer_joueur(vue)
		var director: Node = vue.get("director")
		if director != null: director.close_training()
		var app: Control = vue.get("app")
		if app != null and is_instance_valid(app.navigation_controller): app.navigation_controller.open_entity({"kind": "player", "id": str(joueur.get("id", ""))}))
	fiche.name = "TrainingPlayerOpenSheet"
	fiche.add_theme_color_override("font_focus_color", Charte.IVOIRE)
	col.add_child(fiche)
	PetiteFenetre.enregistrer(calque, func(): fermer_joueur(vue))
	# Centrage après mesure (le panneau prend sa hauteur de contenu).
	panneau.reset_size()
	var taille := panneau.get_combined_minimum_size()
	panneau.offset_left = -taille.x / 2.0
	panneau.offset_right = taille.x / 2.0
	panneau.offset_top = -taille.y / 2.0
	panneau.offset_bottom = taille.y / 2.0
	fermer.grab_focus()

static func fermer_joueur(vue: Control) -> void:
	var ancien := vue.find_child("TrainingPlayerWindow", false, false)
	if ancien != null:
		vue.remove_child(ancien)
		ancien.queue_free()

# --- Option B : plans en tuiles à icône -------------------------------------------------------------

const PLANS_B := {
	"proteger": {"signe": "shield", "parts": [["XV", "Repos", Charte.REPOS], ["Remplaçants", "Normal", Charte.NORMAL]]},
	"relever": {"signe": "school", "parts": [["Jeunes", "Intensif", Charte.INTENSIF], ["XV fatigué", "Repos", Charte.REPOS]]},
	"equilibrer": {"signe": "renew", "parts": [["Chargés", "Repos", Charte.REPOS], ["Autres", "Collectif", Charte.NORMAL]]},
}

static func tuile_plan(plan: Dictionary, action: Callable, actif: bool) -> Control:
	var cle := str(plan.get("key", ""))
	var def: Dictionary = PLANS_B.get(cle, {"signe": "train", "parts": []})
	var fond := carte(Charte.PANNEAU_2, Charte.RAYON_CARTE, 10)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	fond.add_child(col)
	var titre := HBoxContainer.new()
	titre.add_theme_constant_override("separation", 8)
	titre.add_child(icone(def.signe, 24, Charte.IVOIRE))
	var nom := texte(str(plan.get("label", "")), 19, Charte.IVOIRE, C.BOLD)
	titre.add_child(nom)
	col.add_child(titre)
	var parts := HBoxContainer.new()
	parts.add_theme_constant_override("separation", 6)
	for p: Array in def.parts:
		var pilule := PanelContainer.new()
		var st := Charte.style_pilule(Color(p[2], .2), Color.TRANSPARENT, 8, 2)
		st.set_corner_radius_all(Charte.RAYON_PETIT)
		pilule.add_theme_stylebox_override("panel", st)
		var l := HBoxContainer.new()
		l.add_theme_constant_override("separation", 5)
		l.add_child(texte(p[0], 14, Charte.IVOIRE_2, C.MEDIUM))
		l.add_child(texte(str(p[1]), 14, p[2], C.BOLD))
		pilule.add_child(l)
		parts.add_child(pilule)
	col.add_child(parts)
	var b := cliquable(fond, action, "TrainingPlanTile_" + cle, str(plan.get("detail", "")))
	(b.get_meta("bouton") as Button).disabled = not actif
	return b
