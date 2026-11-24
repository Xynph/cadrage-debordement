extends RefCounted
## Comparateur en radar (idée FM27 n° 9, option A choisie par Léo le 23/11/2026) : deux joueurs, un
## radar à 8 axes rugby en deux couleurs (turquoise ● pour le premier, orange ■ pour le second : la forme du repère
## double toujours la couleur). Chaque axe est la moyenne d'attributs existants du moteur (attributesV2, 36 clés,
## chacune dans un seul axe), rien de nouveau n'est calculé par le moteur.
## Grand radar entre deux colonnes de synthèse (note au poste principal en lettre du staff E- à S+, jamais de chiffre ni
## d'étoiles : décisions de Léo des 23 et 24/11/2026) ; clic sur un axe ou sur le point fort / faible = petite fenêtre visuelle des attributs de
## l'axe en barres miroir.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Commune = preload("res://ui/immersive08/fiche_commune.gd")
const Attributs = preload("res://ui/player_attributes.gd")
const Base = preload("res://ui/immersive08/recruitment_comparison.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Notation = preload("res://ui/notation_staff.gd")

## Axes dans l'ordre des aiguilles d'une montre depuis le haut : le haut du radar parle des avants (conquête, défense,
## physique), le bas des trois-quarts (vitesse, attaque, jeu au pied, technique).
const AXES := [
	["Défense", ["tackling", "jackal", "ruckClearout", "positioning", "discipline"]],
	["Physique", ["strength", "endurance", "explosiveness", "workRate"]],
	["Vitesse", ["acceleration", "topSpeed", "agility", "evasion"]],
	["Attaque", ["ballCarry", "offload", "passing", "vision"]],
	["Jeu au pied", ["kickDistance", "kickAccuracy", "goalAccuracy", "kickChase"]],
	["Technique", ["ballHandling", "receiving", "aerialAbility", "jumping"]],
	["Mental", ["decisions", "anticipation", "composure", "leadership", "teamwork"]],
	["Conquête", ["scrumTechnique", "hooking", "lineoutThrow", "lineoutJump", "lineoutLift", "maul"]],
]
const COULEURS := [Charte.REPOS, Charte.INTENSIF]
const MARQUES := ["●", "■"]
## Échelle du radar : 30 au centre, 100 au bord (les notes du moteur vivent entre 30 et 95).
const BAS := 30.0

static func libelle(cle: String) -> String:
	for groupe: Array in Attributs.GROUPS:
		for paire: Array in groupe[1]:
			if str(paire[0]) == cle: return str(paire[1])
	return cle

## Valeur d'un attribut, null si inconnu (joueur non observé).
static func attribut(joueur: Dictionary, cle: String) -> Variant:
	if joueur.is_empty(): return null
	var v: Variant = Base.value(joueur, "attribute:" + cle)
	return float(v) if Base.numeric(v) else null

## Moyenne arrondie des attributs de l'axe, null si l'un d'eux est inconnu.
static func axe(joueur: Dictionary, indice: int) -> Variant:
	var cles: Array = AXES[indice][1]
	var somme := 0.0
	for cle: String in cles:
		var v: Variant = attribut(joueur, cle)
		if v == null: return null
		somme += float(v)
	return roundf(somme / cles.size())

static func axes(joueur: Dictionary) -> Array:
	var sortie: Array = []
	for i in AXES.size(): sortie.append(axe(joueur, i))
	return sortie

## Note du moteur au poste principal du joueur (positionRatings, sur 100) ; null si inconnue (joueur non observé).
static func note_poste(joueur: Dictionary) -> Variant:
	var postes: Variant = joueur.get("primaryPositions")
	var notes: Variant = joueur.get("positionRatings")
	if not postes is Array or (postes as Array).is_empty() or not notes is Dictionary: return null
	var v: Variant = (notes as Dictionary).get(str(int((postes as Array)[0])))
	return float(v) if Base.numeric(v) else null

## Note au poste principal en lettre du staff ({bas, haut}, double « B/A » si le staff n'est pas sûr ; jamais de chiffre).
static func lettre_poste(app: Control, joueur: Dictionary) -> Dictionary:
	if joueur.is_empty(): return {"bas": -1, "haut": -1}
	var postes: Variant = joueur.get("primaryPositions")
	var numero := int((postes as Array)[0]) if postes is Array and not (postes as Array).is_empty() and Base.numeric((postes as Array)[0]) else 0
	return Notation.lettre_poste(app.model, joueur, numero, bool(joueur.get("__own", false)))

static func _texte(v: Variant) -> String:
	return str(int(v)) if v != null else "?"

## 0 ou 1 si un joueur a strictement plus, -1 sinon.
static func _meilleur(a: Variant, b: Variant) -> int:
	if a == null or b == null or float(a) == float(b): return -1
	return 0 if float(a) > float(b) else 1

static func _direction(i: int) -> Vector2:
	var angle := -PI / 2.0 + i * TAU / AXES.size()
	return Vector2(cos(angle), sin(angle))

## Radar dessiné (lecture seule, ne capte pas la souris) ; `choisi` éclaire un axe.
static func radar(parent: Control, centre: Vector2, rayon: float, series: Array, choisi: int, nom: String) -> Control:
	var zone := Control.new()
	zone.name = nom
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(zone)
	D.place(zone, Rect2(centre.x - rayon, centre.y - rayon, rayon * 2.0, rayon * 2.0))
	zone.draw.connect(func():
		var c := zone.size / 2.0
		var r := minf(zone.size.x, zone.size.y) / 2.0
		var epaisseur := maxf(1.0, C.density)
		var fond := PackedVector2Array()
		for i in AXES.size(): fond.append(c + _direction(i) * r)
		zone.draw_colored_polygon(fond, Color(Charte.NOIR_PANNEAU, .55))
		for k in range(1, 5):
			var anneau := PackedVector2Array()
			for i in AXES.size() + 1: anneau.append(c + _direction(i % AXES.size()) * r * k / 4.0)
			zone.draw_polyline(anneau, Color(Charte.IVOIRE, .24 if k == 4 else .09), epaisseur, true)
		for i in AXES.size():
			var vif := i == choisi
			zone.draw_line(c, c + _direction(i) * r, Color(Charte.IVOIRE, .55 if vif else .12), epaisseur * (3.0 if vif else 1.0), true)
		for s: Dictionary in series:
			var valeurs: Array = s.valeurs
			if valeurs.any(func(v): return v == null): continue
			var points := PackedVector2Array()
			for i in AXES.size():
				var part := clampf((float(valeurs[i]) - BAS) / (100.0 - BAS), .03, 1.0)
				points.append(c + _direction(i) * r * part)
			zone.draw_colored_polygon(points, Color(s.couleur, .20))
			var ferme := points.duplicate()
			ferme.append(points[0])
			zone.draw_polyline(ferme, s.couleur, epaisseur * 3.0, true)
			var cote := 7.0 * C.density
			for p: Vector2 in points:
				if int(s.rang) == 0: zone.draw_circle(p, cote, s.couleur)
				else: zone.draw_rect(Rect2(p - Vector2(cote, cote), Vector2(cote, cote) * 2.0), s.couleur)
	)
	zone.queue_redraw()
	return zone

static func _series(joueurs: Array) -> Array:
	var series: Array = []
	for i in mini(2, joueurs.size()):
		if (joueurs[i] as Dictionary).is_empty(): continue
		series.append({"rang": i, "couleur": COULEURS[i], "valeurs": axes(joueurs[i])})
	return series

## Bandeau de couleur sous l'en-tête de chaque joueur (repère du radar).
static func liseres(page: Control, joueurs: Array, xs: Array, largeur: float, y: float) -> void:
	for i in mini(2, joueurs.size()):
		if (joueurs[i] as Dictionary).is_empty(): continue
		var bande := D.rect(page, Rect2(float(xs[i]), y, largeur, 6), COULEURS[i], 3)
		bande.name = "RadarLisere" + str(i)
		D.text(page, float(xs[i]) + largeur - 4, y - 12, MARQUES[i], 26, COULEURS[i], 800, 40, HORIZONTAL_ALIGNMENT_RIGHT)

static func construire(app: Control, page: Control, joueurs: Array, y0: float) -> void:
	var centre := Vector2(1124, y0 + 470)
	var rayon := 318.0
	radar(page, centre, rayon, _series(joueurs), -1, "RadarDessin")
	for i in AXES.size():
		var d := _direction(i)
		var ancre := centre + d * (rayon + 58.0)
		var a: Variant = axe(joueurs[0], i) if joueurs.size() > 0 else null
		var b: Variant = axe(joueurs[1], i) if joueurs.size() > 1 else null
		var bouton := Button.new()
		bouton.name = "RadarAxe" + str(i)
		bouton.flat = true
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		bouton.accessibility_name = str(AXES[i][0])
		Kit.styler_ligne(bouton, Color.TRANSPARENT)
		page.add_child(bouton)
		var largeur := 210.0
		var x := ancre.x - largeur / 2.0
		if d.x > .3: x = ancre.x - 20.0
		elif d.x < -.3: x = ancre.x - largeur + 20.0
		D.place(bouton, Rect2(x, ancre.y - 40, largeur, 78))
		bouton.pressed.connect(func(): fenetre_axe(page, joueurs, i, bouton))
		var aligne := HORIZONTAL_ALIGNMENT_CENTER
		var tx := largeur / 2.0
		if d.x > .3:
			aligne = HORIZONTAL_ALIGNMENT_LEFT
			tx = 12.0
		elif d.x < -.3:
			aligne = HORIZONTAL_ALIGNMENT_RIGHT
			tx = largeur - 12.0
		var titre := D.text(bouton, tx, 32, str(AXES[i][0]).to_upper(), 24, Charte.IVOIRE, 800, largeur - 24, aligne)
		titre.add_theme_font_override("font", C.EXTRA_BOLD)
		titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gagnant := _meilleur(a, b)
		var morceaux := [[_texte(a) + (" ▲" if gagnant == 0 else ""), COULEURS[0]], [_texte(b) + (" ▲" if gagnant == 1 else ""), COULEURS[1]]]
		var largeurs := [Kit.largeur(morceaux[0][0], 26) + 8.0, Kit.largeur(morceaux[1][0], 26)]
		var total: float = largeurs[0] + 18.0 + largeurs[1]
		var depart := tx - total / 2.0 if aligne == HORIZONTAL_ALIGNMENT_CENTER else (tx if aligne == HORIZONTAL_ALIGNMENT_LEFT else tx - total)
		for k in 2:
			if joueurs.size() <= k or (joueurs[k] as Dictionary).is_empty(): continue
			var chiffre := D.text(bouton, depart, 66, morceaux[k][0], 26, morceaux[k][1], 800)
			chiffre.name = "RadarAxe%dValeur%d" % [i, k]
			chiffre.add_theme_font_override("font", C.EXTRA_BOLD)
			chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
			depart += largeurs[k] + 18.0
	for k in mini(2, joueurs.size()):
		_colonne_synthese(app, page, joueurs, k, Rect2(0.0 if k == 0 else 1728.0, y0 + 24, 520, 860))

## Colonne de synthèse d'un joueur (grammaire de l'Effectif : libellé gris, chiffre coloré, ▲ au meilleur).
static func _colonne_synthese(app: Control, page: Control, joueurs: Array, k: int, zone: Rect2) -> void:
	var joueur: Dictionary = joueurs[k]
	if joueur.is_empty(): return
	var autre: Dictionary = joueurs[1 - k] if joueurs.size() > 1 else {}
	var panneau := Panel.new()
	panneau.name = "RadarSynthese" + str(k)
	panneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panneau.add_theme_stylebox_override("panel", Charte.style_panneau(Charte.NOIR_PANNEAU, Charte.RAYON_PANNEAU))
	page.add_child(panneau)
	D.place(panneau, zone)
	var droite := k == 1
	var marge := 28.0
	var t := Kit.titre(panneau, marge, 50, MARQUES[k] + "  " + Kit.casse(str(joueur.get("name", "")), true).to_upper(), 26, zone.size.x - 2 * marge)
	t.add_theme_color_override("font_color", COULEURS[k])
	if droite: t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var lignes: Array = []
	var propre := bool(joueur.get("__own", false))
	# Niveau, Potentiel et Au poste : lettres du staff en pastille, ▲ comparé sur les lettres MONTRÉES (aucun chiffre,
	# aucune fuite de la valeur cachée en mode fourchette).
	var propre_autre := bool(autre.get("__own", false)) if not autre.is_empty() else false
	var l_niv := Notation.lettre_champ(joueur, "rating", propre, app.model)
	var l_pot := Notation.lettre_champ(joueur, "potential", propre, app.model)
	var l_poste := lettre_poste(app, joueur)
	var rang := func(l: Dictionary) -> Variant: return Notation.rang_lettre(l) if Notation.rang_lettre(l) >= 0.0 else null
	var sans := autre.is_empty()
	lignes.append(["Niveau", "", rang.call(l_niv), null if sans else rang.call(Notation.lettre_champ(autre, "rating", propre_autre, app.model)), true, l_niv])
	lignes.append(["Potentiel", "", rang.call(l_pot), null if sans else rang.call(Notation.lettre_champ(autre, "potential", propre_autre, app.model)), true, l_pot])
	var forme: Variant = Commune.condition(joueur)
	lignes.append(["Condition", "%d %%" % roundi(float(forme)) if forme != null else "—", forme, Commune.condition(autre) if not autre.is_empty() else null, true, null])
	lignes.append(["Au poste", "", rang.call(l_poste), null if sans else rang.call(lettre_poste(app, autre)), true, l_poste])
	lignes.append(["Âge", G.n(joueur.get("age", "—")) + " ans", null, null, false, null])
	lignes.append(["Contrat", Commune.echeance(app, joueur), null, null, false, null])
	var valeurs := axes(joueur)
	var meilleur := -1
	for i in valeurs.size():
		if valeurs[i] != null and (meilleur < 0 or float(valeurs[i]) > float(valeurs[meilleur])): meilleur = i
	var faible := -1
	for i in valeurs.size():
		if valeurs[i] != null and (faible < 0 or float(valeurs[i]) < float(valeurs[faible])): faible = i
	var y := 96.0
	for ligne: Array in lignes:
		D.line(panneau, Vector2(marge, y + 50), Vector2(zone.size.x - marge, y + 50), Color(Charte.FILET, .8))
		var mieux: bool = bool(ligne[4]) and Base.numeric(ligne[2]) and Base.numeric(ligne[3]) and float(ligne[2]) > float(ligne[3])
		var couleur: Color = Charte.IVOIRE
		if str(ligne[0]) == "Condition" and Base.numeric(ligne[2]): couleur = Charte.CONDITION
		D.text(panneau, zone.size.x - marge if droite else marge, y + 34, str(ligne[0]), 19, Charte.IVOIRE_2, 500, 200, HORIZONTAL_ALIGNMENT_RIGHT if droite else HORIZONTAL_ALIGNMENT_LEFT, true)
		var valeur := D.text(panneau, marge if droite else zone.size.x - marge, y + 36, (("▲ " if mieux else "") + str(ligne[1])) if droite else (str(ligne[1]) + (" ▲" if mieux else "")), 26, couleur, 800, zone.size.x - 2 * marge - 210, HORIZONTAL_ALIGNMENT_LEFT if droite else HORIZONTAL_ALIGNMENT_RIGHT)
		valeur.name = "RadarSynthese%d_%s" % [k, str(ligne[0]).replace(" ", "")]
		if droite: valeur.position.x = C.px(marge)
		valeur.add_theme_font_override("font", C.EXTRA_BOLD)
		if ligne[5] is Dictionary:
			var lettre: Dictionary = ligne[5]
			valeur.add_theme_color_override("font_color", Charte.GAIN)
			var taille := 40.0
			var w := Notation.largeur_note(lettre, taille)
			var decale := 34.0 if mieux else 0.0
			Notation.pastille_note(panneau, marge + decale if droite else zone.size.x - marge - decale - w, y + 26, lettre, taille, "RadarSynthese%d_%sLettre" % [k, str(ligne[0]).replace(" ", "")])
			if str(ligne[0]) == "Au poste":
				# Emplacement réservé au futur mot de familiarité au poste (système en préparation) : vide pour l'instant.
				var familiarite := D.text(panneau, zone.size.x - marge - 96 if droite else marge + 96, y + 34, "", 19, Charte.IVOIRE_2, 600, 160, HORIZONTAL_ALIGNMENT_RIGHT if droite else HORIZONTAL_ALIGNMENT_LEFT, true)
				familiarite.name = "RadarFamiliarite%d" % k
		y += 60.0
	y += 26.0
	for paire: Array in [["Point fort", meilleur, Charte.GAIN, "▲"], ["Point faible", faible, Charte.PERTE, "▼"]]:
		if int(paire[1]) < 0: continue
		D.text(panneau, zone.size.x - marge if droite else marge, y + 34, str(paire[0]), 19, Charte.IVOIRE_2, 500, 200, HORIZONTAL_ALIGNMENT_RIGHT if droite else HORIZONTAL_ALIGNMENT_LEFT, true)
		var texte := "%s %s %d" % [str(paire[3]), str(AXES[int(paire[1])][0]), int(valeurs[int(paire[1])])]
		var lien := Kit.lien(panneau, Rect2(marge if droite else zone.size.x - marge - 300, y + 4, 300, 44), texte, func(): fenetre_axe(page, joueurs, int(paire[1]), null), "RadarSynthese%d_%s" % [k, str(paire[0]).replace(" ", "")], 22, false)
		lien.add_theme_color_override("font_color", paire[2])
		lien.alignment = HORIZONTAL_ALIGNMENT_LEFT if droite else HORIZONTAL_ALIGNMENT_RIGHT
		y += 60.0

## Petite fenêtre visuelle d'un axe : un attribut par ligne, barres miroir aux couleurs des deux joueurs.
static func fenetre_axe(page: Control, joueurs: Array, i: int, retour: Control) -> void:
	var cles: Array = AXES[i][1]
	var hauteur := 190.0 + cles.size() * 64.0 + 70.0
	var fond := Fenetre.ouvrir(page, "RadarAxeFenetre", str(AXES[i][0]).to_upper(), "", 1040, hauteur, func(): if is_instance_valid(retour): retour.grab_focus())
	var y := 96.0
	for k in mini(2, joueurs.size()):
		var joueur: Dictionary = joueurs[k]
		if joueur.is_empty(): continue
		var nom := D.text(fond, 40.0 if k == 0 else 1000.0, y + 28, (MARQUES[k] + "  " + Kit.casse(str(joueur.get("name", "")), true)) if k == 0 else (Kit.casse(str(joueur.get("name", "")), true) + "  " + MARQUES[k]), 24, COULEURS[k], 800, 420, HORIZONTAL_ALIGNMENT_LEFT if k == 0 else HORIZONTAL_ALIGNMENT_RIGHT)
		nom.add_theme_font_override("font", C.EXTRA_BOLD)
	y += 56.0
	var lignes: Array = []
	for cle: String in cles: lignes.append([libelle(cle), attribut(joueurs[0], cle) if joueurs.size() > 0 else null, attribut(joueurs[1], cle) if joueurs.size() > 1 else null, "RadarFenetreLigne_" + cle])
	lignes.append(["Moyenne", axe(joueurs[0], i) if joueurs.size() > 0 else null, axe(joueurs[1], i) if joueurs.size() > 1 else null, "RadarFenetreMoyenne"])
	for n in lignes.size():
		var ligne: Array = lignes[n]
		if n == lignes.size() - 1:
			D.line(fond, Vector2(40, y + 2), Vector2(1000, y + 2), Charte.FILET, 2)
			y += 10.0
		_ligne_miroir(fond, Rect2(40, y, 960, 56), str(ligne[0]), ligne[1], ligne[2], str(ligne[3]), n == lignes.size() - 1)
		y += 64.0

## Ligne miroir : libellé au centre, barre du premier joueur vers la gauche, du second vers la droite.
static func _ligne_miroir(parent: Control, zone: Rect2, titre: String, a: Variant, b: Variant, nom: String, gras: bool) -> void:
	var milieu := zone.position.x + zone.size.x / 2.0
	var demi := 250.0
	var hb := 14.0
	var yb := zone.position.y + zone.size.y / 2.0 - hb / 2.0
	var gagnant := _meilleur(a, b)
	D.rect(parent, Rect2(milieu - 110 - demi, yb, demi, hb), Charte.PANNEAU_3, 4)
	D.rect(parent, Rect2(milieu + 110, yb, demi, hb), Charte.PANNEAU_3, 4)
	if a != null:
		var la := demi * clampf(float(a) / 100.0, 0.0, 1.0)
		D.rect(parent, Rect2(milieu - 110 - la, yb, la, hb), Color(COULEURS[0], 1.0 if gagnant != 1 else .55), 4)
	if b != null:
		var lb := demi * clampf(float(b) / 100.0, 0.0, 1.0)
		D.rect(parent, Rect2(milieu + 110, yb, lb, hb), Color(COULEURS[1], 1.0 if gagnant != 0 else .55), 4)
	var etiquette := D.text(parent, milieu, zone.position.y + 36, titre, 20 if not gras else 22, Charte.IVOIRE if gras else Charte.IVOIRE_2, 700 if gras else 500, 210, HORIZONTAL_ALIGNMENT_CENTER, not gras)
	etiquette.name = nom
	var va := D.text(parent, milieu - 110 - demi - 14, zone.position.y + 38, ("▲ " if gagnant == 0 else "") + _texte(a), 26, Charte.couleur_attribut(a) if a != null else Charte.IVOIRE_3, 800, 120, HORIZONTAL_ALIGNMENT_RIGHT)
	va.add_theme_font_override("font", C.EXTRA_BOLD)
	va.name = nom + "_0"
	var vb := D.text(parent, milieu + 110 + demi + 14, zone.position.y + 38, _texte(b) + (" ▲" if gagnant == 1 else ""), 26, Charte.couleur_attribut(b) if b != null else Charte.IVOIRE_3, 800, 120)
	vb.add_theme_font_override("font", C.EXTRA_BOLD)
	vb.name = nom + "_1"
