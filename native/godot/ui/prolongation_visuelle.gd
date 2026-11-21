extends RefCounted
## Prolongation de contrat, option B de la planche (21/11/2026, CD_VARIANTE_VISUELLE=B) : mêmes pièces que l'offre au joueur
## (offre_visuelle.gd) avec l'ancien contrat mis en regard du nouveau : cartes « aujourd'hui → prolongé », règle de salaire
## avec le salaire actuel, frise à deux lignes (contrat en cours / nouveau contrat).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const G = preload("res://ui/game_skin.gd")
const Salary = preload("res://ui/salary_display.gd")
const O = preload("res://ui/offre_visuelle.gd")
const LARGEUR := O.LARGEUR
const HAUTEUR := 660.0

static func construire(body: Control, ctx: Dictionary) -> Control:
	ctx["avant_apres"] = true
	var toile := Control.new()
	toile.name = "OffreVisuelle"
	toile.custom_minimum_size = Vector2(LARGEUR, HAUTEUR) * C.density
	toile.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(toile)
	body.move_child(toile, 0)
	var dessin := Control.new()
	dessin.name = "OffreDessin"
	dessin.mouse_filter = Control.MOUSE_FILTER_PASS
	toile.add_child(dessin)
	D.place(dessin, Rect2(0, 0, LARGEUR, HAUTEUR))
	for champ: SpinBox in [ctx.salary, ctx.years]:
		if champ.get_parent() != null: champ.get_parent().remove_child(champ)
		toile.add_child(champ)
	D.place(ctx.salary, Rect2(1196, 232, 280, 50))
	D.place(ctx.years, Rect2(1196, 427, 280, 50))
	var redessiner := func(): _dessiner(toile, dessin, ctx)
	ctx.salary.value_changed.connect(func(_x: float): redessiner.call())
	ctx.years.value_changed.connect(func(_x: float): redessiner.call())
	redessiner.call()
	return toile

static func _dessiner(toile: Control, dessin: Control, ctx: Dictionary) -> void:
	if not is_instance_valid(dessin): return
	O._vider(dessin)
	var val := O.valeurs(ctx)
	O._identite(toile, dessin, ctx, val)
	_avant_apres(toile, dessin, val)
	_regle(toile, dessin, ctx, val, Rect2(0, 170, LARGEUR, 180))
	_frise(toile, dessin, ctx, val, Rect2(0, 365, LARGEUR, 185))
	O._jeton(toile, dessin, val, Rect2(0, 565, LARGEUR, 95))
	O._marquer(toile)

static func _fin_actuelle(val: Dictionary) -> String:
	return "—" if val.fin_actuelle == null else G.contract_year(val.fin_actuelle)

## Saisons restantes du contrat en cours, comptées depuis la première saison du nouveau contrat.
static func _restantes(val: Dictionary) -> int:
	if val.fin_actuelle == null: return 0
	return maxi(0, int(val.fin_actuelle) - int(val.premiere) + 1)

static func _largeur_chiffre(texte: String, taille: int) -> float:
	return Charte.TITRE_EXTRA_ITALIQUE.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille))).x / C.density

# --- Cartes « aujourd'hui → prolongé » -----------------------------------------------------------------------------------

static func _carte(parent: Control, zone: Rect2, id: String, titre: String, salaire: String, fin: String, couleur: Color, plein: bool) -> Panel:
	var carte := D.rect(parent, zone, Color(couleur, .16) if plein else Charte.PANNEAU_2, Charte.RAYON_CARTE, couleur if plein else Charte.FILET)
	carte.name = id
	var t := D.text(carte, 18, 30, titre, 15, couleur if plein else Charte.IVOIRE_2, 700, zone.size.x - 36)
	t.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	var s := D.text(carte, 18, 80, salaire, 34, couleur if plein else Charte.IVOIRE, 800, zone.size.x - 36)
	s.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	s.name = id + "Salaire"
	var f := D.text(carte, 18, 122, fin, 21, couleur if plein else Charte.IVOIRE_2, 700, zone.size.x - 36)
	f.name = id + "Fin"
	return carte

static func _avant_apres(toile: Control, parent: Control, val: Dictionary) -> void:
	var avant := _carte(parent, Rect2(1000, 0, 220, 150), "ProlongationAvant", "AUJOURD'HUI", G.salary_amount(val.actuel), "FIN " + _fin_actuelle(val), Charte.IVOIRE, false)
	var fleche := TextureRect.new()
	fleche.texture = C.icon_texture("arrow", Charte.IVOIRE_2)
	fleche.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fleche.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fleche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fleche)
	D.place(fleche, Rect2(1226, 57, 36, 36))
	var apres := _carte(parent, Rect2(1268, 0, 232, 150), "ProlongationApres", "PROLONGÉ", G.salary_amount(val.propose), "FIN " + str(val.fin), O.COULEUR_SALAIRE, true)
	for carte: Panel in [avant, apres]:
		Pieces.rendre_cliquable(carte, carte.size / C.density, func(): _fenetre_avant_apres(toile, val), carte.name + "Lien", "Ancien et nouveau contrat", "", Charte.RAYON_CARTE)

# --- Règle de salaire : actuel, demande, proposition --------------------------------------------------------------------

static func _regle(toile: Control, parent: Control, ctx: Dictionary, val: Dictionary, zone: Rect2) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "OffreRegle"
	O._etiquette(cadre, 24, 34, "Salaire " + G.salary_period(true), 300)
	var couleur := O._couleur_ecart(val)
	var x_ecart := 24 + Pieces.largeur_titre("SALAIRE " + G.salary_period(true).to_upper(), 16) + 22
	var texte_ecart := O._signe(int(val.ecart))
	var ecart := D.text(cadre, x_ecart, 38, texte_ecart, 30, couleur, 800, 260)
	ecart.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	ecart.name = "OffreRegleEcart"
	var largeur_ecart := _largeur_chiffre(texte_ecart, 30)
	O._lien(cadre, Rect2(16, 4, x_ecart + largeur_ecart - 8, 46), "OffreRegleEcartZone", "Salaire", func(): O._fenetre_salaire(toile, val))
	var hausse := O.hausse(val)
	Pieces.pastille(cadre, x_ecart + largeur_ecart + 22, 12, "%s vs actuel" % O.signe_salaire(hausse), "renew", "ProlongationHausse", "", Charte.IVOIRE,
		Charte.PANNEAU_3, func(): _fenetre_avant_apres(toile, val))
	var actuel := roundf(float(val.actuel) / 100.0) * 100.0
	var demande := roundf(float(val.demande) / 100.0) * 100.0
	var propose := roundf(float(val.propose) / 100.0) * 100.0
	var bas := maxf(0.0, minf(minf(demande * .5, propose * .8), actuel * .8))
	var haut := maxf(maxf(demande * 1.5, propose * 1.2), actuel * 1.2)
	bas = floorf(bas / 100.0) * 100.0
	haut = ceilf(haut / 100.0) * 100.0
	if haut <= bas: haut = bas + 100.0
	var x0 := 40.0
	var w := 1150.0 - x0
	var ty := 88.0
	var vers_x := func(valeur: float) -> float: return x0 + w * clampf((valeur - bas) / (haut - bas), 0, 1)
	D.rect(cadre, Rect2(x0, ty, w, 10), Charte.PANNEAU_3, Charte.RAYON_PILULE)
	for i in 5:
		var gx: float = vers_x.call(bas + (haut - bas) * i / 4.0)
		D.rect(cadre, Rect2(gx - 1, ty + 14, 2, 8), Charte.IVOIRE_3)
	var xa: float = vers_x.call(actuel)
	var xd: float = vers_x.call(demande)
	var xp: float = vers_x.call(propose)
	if absf(xp - xd) > 1: D.rect(cadre, Rect2(minf(xd, xp), ty, absf(xp - xd), 10), couleur, Charte.RAYON_PILULE).name = "OffreRegleEcartBande"
	# Salaire actuel : losange ivoire sur la règle.
	var losange := D.rect(cadre, Rect2(xa - 9, ty - 4, 18, 18), Charte.IVOIRE, 3)
	losange.pivot_offset = Vector2(9, 9) * C.density
	losange.rotation_degrees = 45
	losange.name = "ProlongationRegleActuel"
	D.text(cadre, xa, ty + 46, "ACTUEL " + G.salary_amount(val.actuel), 15, Charte.IVOIRE, 700, 220, HORIZONTAL_ALIGNMENT_CENTER)
	D.rect(cadre, Rect2(xd - 2, ty - 22, 4, 54), Pieces.VERT, 2).name = "OffreRegleDemande"
	D.text(cadre, xd, ty - 28, "DEMANDE " + G.salary_amount(val.demande), 15, Pieces.VERT, 700, 220, HORIZONTAL_ALIGNMENT_CENTER)
	var curseur := D.rect(cadre, Rect2(xp - 14, ty - 9, 28, 28), O.COULEUR_SALAIRE, Charte.RAYON_PILULE, Charte.IVOIRE)
	curseur.name = "OffreRegleCurseur"
	D.text(cadre, xp, ty + 74, "TA PROPOSITION " + G.salary_amount(val.propose), 16, O.COULEUR_SALAIRE, 700, 260, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(cadre, 1196, 54, "SALAIRE " + G.salary_period(true).to_upper(), 14, O.COULEUR_SALAIRE, 700, 280)
	var salaire: SpinBox = ctx.salary
	var clic := Button.new()
	clic.name = "OffreRegleClic"
	clic.flat = true
	clic.focus_mode = Control.FOCUS_NONE
	clic.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for etat in ["normal", "hover", "pressed", "focus"]: clic.add_theme_stylebox_override(etat, StyleBoxEmpty.new())
	clic.accessibility_name = "Régler le salaire sur la règle"
	cadre.add_child(clic)
	D.place(clic, Rect2(x0 - 20, ty - 40, w + 40, 100))
	clic.gui_input.connect(func(evenement: InputEvent):
		if evenement is InputEventMouseButton and evenement.pressed and evenement.button_index == MOUSE_BUTTON_LEFT and salaire.editable:
			var unites: float = evenement.position.x / C.density + (x0 - 20)
			var valeur := bas + (haut - bas) * clampf((unites - x0) / w, 0, 1)
			Salary.set_input_weekly(salaire, roundf(valeur / 100.0) * 100.0))

# --- Frise à deux lignes : contrat en cours / nouveau contrat -----------------------------------------------------------

static func _frise(toile: Control, parent: Control, ctx: Dictionary, val: Dictionary, zone: Rect2) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "OffreFrise"
	O._etiquette(cadre, 24, 34, "Durée", 200)
	var x_fin := 24 + Pieces.largeur_titre("DURÉE", 16) + 22
	var texte_fin := "FIN %s" % str(val.fin)
	var fin := D.text(cadre, x_fin, 38, texte_fin, 30, O.COULEUR_DUREE, 800, 300)
	fin.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	fin.name = "OffreFriseFin"
	var largeur_fin := _largeur_chiffre(texte_fin, 30)
	O._lien(cadre, Rect2(16, 4, x_fin + largeur_fin - 8, 46), "OffreFriseFinZone", "Durée du contrat", func(): O._fenetre_duree(toile, val))
	var restantes := _restantes(val)
	var gagnees := int(val.annees) - restantes
	Pieces.pastille(cadre, x_fin + largeur_fin + 22, 12, "%s%d saison%s" % ["+" if gagnees >= 0 else "−", absi(gagnees), "s" if absi(gagnees) > 1 else ""],
		"calendar", "ProlongationGain", "", O.COULEUR_DUREE if gagnees > 0 else Pieces.ORANGE, Charte.PANNEAU_3, func(): _fenetre_avant_apres(toile, val))
	var x0 := 150.0
	var w := 1150.0 - x0
	var annees: SpinBox = ctx.years
	var n := maxi(1, maxi(int(val.max), restantes))
	var pas := w / n
	# Ligne du contrat en cours.
	var y1 := 62.0
	O._etiquette(cadre, 24, y1 + 19, "Actuel", 120).name = "ProlongationFriseActuelTitre"
	for i in n:
		var pris := i < restantes
		var seg := D.rect(cadre, Rect2(x0 + i * pas + 3, y1, pas - 6, 24), Charte.IVOIRE_3 if pris else Color.TRANSPARENT, Charte.RAYON_PETIT, Color.TRANSPARENT if pris else Charte.FILET)
		seg.name = "ProlongationFriseActuel_%d" % (i + 1)
	# Ligne du nouveau contrat (un clic règle la durée) ; les saisons au-delà du contrat en cours portent un « + ».
	var y2 := 98.0
	var t2 := O._etiquette(cadre, 24, y2 + 22, "Nouveau", 120)
	t2.name = "ProlongationFriseNouveauTitre"
	t2.add_theme_color_override("font_color", O.COULEUR_DUREE)
	for i in n:
		var choisi := i < int(val.annees)
		var au_dela := i >= restantes
		var possible := i + 1 >= int(val.min) and i + 1 <= int(annees.max_value)
		var fond := (O.COULEUR_DUREE if au_dela else O.COULEUR_DUREE.darkened(.3)) if choisi else Charte.PANNEAU_3
		var seg := D.rect(cadre, Rect2(x0 + i * pas + 3, y2, pas - 6, 32), fond, Charte.RAYON_PETIT, Color.TRANSPARENT if choisi else Charte.FILET)
		seg.name = "OffreFriseSaison_%d" % (i + 1)
		D.text(seg, (pas - 6) / 2.0, 23, ("+" if choisi and au_dela else "") + "%d" % (i + 1), 17, Charte.ENCRE if choisi else Charte.IVOIRE_3, 800, pas - 12, HORIZONTAL_ALIGNMENT_CENTER)
		if possible:
			var duree := i + 1
			Pieces.rendre_cliquable(seg, Vector2(pas - 6, 32), func(): if annees.editable: annees.value = duree, "OffreFriseClic_%d" % duree, "%d saison(s)" % duree, "", Charte.RAYON_PETIT)
	for i in n + 1:
		var annee := G.contract_year(int(val.premiere) + i - 1)
		var nouvelle := i == int(val.annees)
		var ancienne := i == restantes and restantes > 0
		var couleur := O.COULEUR_DUREE if nouvelle else Charte.IVOIRE if ancienne else Charte.IVOIRE_3
		D.text(cadre, x0 + i * pas, y2 + 62, annee, 19 if nouvelle or ancienne else 16, couleur, 700, 90, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(cadre, 1196, 54, "SAISONS", 14, O.COULEUR_DUREE, 700, 280)

# --- Petite fenêtre ------------------------------------------------------------------------------------------------------

static func _fenetre_avant_apres(toile: Control, val: Dictionary) -> void:
	var hausse := O.hausse(val)
	O._fenetre(toile, "ProlongationFenetreAvantApres", "Ancien → nouveau contrat", [
		[G.salary(val.actuel), "Salaire actuel", Charte.IVOIRE, "lock"],
		[G.salary(val.propose), "Nouveau salaire", O.COULEUR_SALAIRE, "money"],
		[O.signe_salaire(hausse), "Écart", Pieces.VERT if hausse <= 0 else Pieces.ORANGE, "renew"],
		[_fin_actuelle(val), "Fin actuelle", Charte.IVOIRE, "calendar"],
		[str(val.fin), "Nouvelle fin", O.COULEUR_DUREE, "flag"],
	], O.COULEUR_SALAIRE)
