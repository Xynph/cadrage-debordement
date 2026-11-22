extends RefCounted
## Préparation › Dossier adverse › « Rapport adverse » (idée n° 10 de la revue FM27, planche A/B du 22/11/2026) :
## XV habituel avec la fréquence de chaque titulaire au maillot, zones d'où partent les essais marqués / encaissés
## (profondeur du départ de l'action), essais par tranche de 10 minutes. Données réelles de la fiche du club
## (club-sheet.cjs `rapport`) : essais de l'historique (minute, origine, profondeur) et feuilles de match.
## Option A (lignes, style Effectif) : liste des 15 maillots, deux bandes de terrain colorées, barres miroir par tranche.
## Option B (terrain) : les 15 maillots placés sur un terrain, grille minute × zone pour marqués et encaissés.
## Tout chiffre de zone / tranche / maillot ouvre une petite fenêtre visuelle (Échap, ✕, clic à côté la ferment).
## `page` : le canevas de la Préparation (preparation_canvas.gd), dont on réutilise les aides.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Charte = preload("res://ui/charte.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Link = preload("res://ui/entity_link.gd")
const ClubSheet = preload("res://ui/immersive08/club_sheet_canvas.gd")

## Zones de départ de l'action (mètres de la ligne d'essai visée) : [libellé, borne haute incluse].
const ZONES := [["+50 m", 100], ["22-50 m", 50], ["5-22 m", 22], ["0-5 m", 5]]
const ORIGINES := {"j": ["Jeu courant", R.BLEU, "ballon"], "b": ["Ballon porté", R.ORANGE, "people"], "m": ["Mêlée", R.VIOLET, "people"]}
const TRANCHES := 8
## Terrain vertical (option B) : place de chaque maillot, l'adversaire attaque vers le haut.
const PLACES := {1: Vector2(.3, .12), 2: Vector2(.5, .12), 3: Vector2(.7, .12), 4: Vector2(.4, .23), 5: Vector2(.6, .23),
	6: Vector2(.2, .29), 7: Vector2(.8, .29), 8: Vector2(.5, .34), 9: Vector2(.5, .45), 10: Vector2(.42, .56),
	12: Vector2(.3, .665), 13: Vector2(.18, .77), 11: Vector2(.09, .6), 14: Vector2(.91, .6), 15: Vector2(.5, .88)}

static func variante() -> String:
	return "B" if OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper() == "B" else "A"

## Construit la sous-page ; rend sa hauteur (unités du gabarit).
static func construire(page, section: Control) -> float:
	page._retour(section)
	var adversaire: Dictionary = page._opponent()
	if adversaire.is_empty(): return 70.0
	var club_id := int(adversaire.get("id", -1))
	var donnees: Dictionary = ClubSheet.cached(page.app, club_id) if club_id >= 0 else {}
	if donnees.is_empty():
		var attente: Panel = page._panneau(section, Rect2(0, 66, 2248, 150), "Rapport adverse", "PreparationRapportAdverse")
		page._texte(attente, 24, 100, "…", 22, Charte.IVOIRE_2, 300)
		if club_id >= 0: ClubSheet.request(page.app, club_id)
		return 216.0
	var rapport: Dictionary = donnees.get("rapport", {})
	var effectif := {}
	for joueur: Dictionary in donnees.get("squad", []): effectif[str(joueur.get("id", ""))] = joueur
	var etat := {"page": page, "club_id": club_id, "adversaire": adversaire, "effectif": effectif, "rapport": rapport,
		"essais": rapport.get("essais", []), "matchs": int(rapport.get("sheets", 0))}
	# Bandeau d'en-tête : écusson, nom (fiche du club), matchs observés, essais pour / contre en tuiles.
	_entete(etat, section)
	if variante() == "B": return _option_b(etat, section)
	return _option_a(etat, section)

static func _entete(etat: Dictionary, section: Control) -> void:
	var page = etat.page
	var adversaire: Dictionary = etat.adversaire
	var x := 600.0
	page._crest(section, adversaire, Rect2(x, 4, 44, 44))
	Link.name_link(page.app, section, C.reach_rect(Rect2(x + 54, 6, 520, 42)), "club", str(etat.club_id), G.club_name(adversaire).to_upper(), 24, Charte.IVOIRE, "RapportAdverseClub")
	var pour := _filtre(etat.essais, true).size()
	var contre := _filtre(etat.essais, false).size()
	var droite := 2248.0
	for tuile: Array in [["%d" % contre, "encaissés", R.ROUGE, "RapportAdverseContre"], ["%d" % pour, "marqués", R.VERT, "RapportAdversePour"], ["%d" % int(etat.matchs), "matchs", Charte.IVOIRE, "RapportAdverseMatchs"]]:
		var large := 200.0
		droite -= large
		R.tuile(section, Rect2(droite, 0, large, 52), str(tuile[0]), str(tuile[1]), tuile[2], str(tuile[3]), 32)
		droite -= 12.0

## ---- Option A : lignes ---------------------------------------------------------------------------------

static func _option_a(etat: Dictionary, section: Control) -> float:
	var page = etat.page
	var hauteur := 880.0
	_xv_liste(etat, section, Rect2(0, 66, 1100, hauteur))
	var zones: Panel = page._panneau(section, Rect2(1116, 66, 1132, 470), "D'où partent leurs essais", "RapportAdverseZones")
	_bande(etat, zones, Rect2(24, 86, 1084, 150), true)
	_bande(etat, zones, Rect2(24, 296, 1084, 150), false)
	var temps: Panel = page._panneau(section, Rect2(1116, 550, 1132, hauteur - 484), "Essais par tranche de 10 min", "RapportAdverseTemps")
	_miroir(etat, temps, Rect2(24, 60, 1084, hauteur - 484 - 76))
	return 66.0 + hauteur

## XV habituel : un maillot par ligne, titulaire le plus fréquent, fréquence en chiffre et barre, autre choix.
static func _xv_liste(etat: Dictionary, section: Control, rectangle: Rect2) -> void:
	var page = etat.page
	var panneau: Panel = page._panneau(section, rectangle, "XV habituel", "RapportAdverseXV", "%d feuilles" % int(etat.matchs))
	var colonnes := [["N°", 24.0], ["Titulaire", 96.0], ["Poste", 470.0], ["Titul.", 640.0], ["Autre choix", 820.0]]
	for colonne: Array in colonnes: page._etiquette(panneau, colonne[1], 86, str(colonne[0]), 220)
	var pas := (rectangle.size.y - 110.0) / 15.0
	var maillots: Array = etat.rapport.get("maillots", [])
	for index in 15:
		var y := 100.0 + pas * index
		var centre := y + pas / 2.0
		page._rayer(panneau, Rect2(0, y, rectangle.size.x, pas - 2), index)
		var choix: Array = maillots[index] if index < maillots.size() else []
		var zone: Button = page._survol_ligne(page._zone(panneau, Rect2(0, y, rectangle.size.x, pas - 2), _fenetre_maillot.bind(etat, index), "RapportAdverseMaillot%d" % (index + 1), "Maillot %d" % (index + 1)))
		zone.accessibility_name = "Maillot %d · titulaires" % (index + 1)
		page._titre(panneau, 70, centre + 9, str(index + 1), 26, Charte.IVOIRE_2, 50, HORIZONTAL_ALIGNMENT_RIGHT)
		if choix.is_empty():
			page._texte(panneau, 96, centre + 7, "—", 18, Charte.IVOIRE_2, 300)
			continue
		var premier: Dictionary = etat.effectif.get(str(choix[0].get("id", "")), {})
		if not premier.is_empty():
			page._lien_joueur(panneau, Rect2(96, y, 360, pas), premier, 19, "RapportAdverseTitulaire%d" % (index + 1), etat.club_id)
			page._texte(panneau, 470, centre + 7, str(premier.get("pos", "")), 17, Charte.IVOIRE_2, 160)
		var titul := int(choix[0].get("starts", 0))
		var part := float(titul) / maxf(1.0, float(etat.matchs))
		var teinte := _teinte_part(part)
		page._titre(panneau, 640, centre + 9, "%d/%d" % [titul, int(etat.matchs)], 22, teinte, 70)
		var rail := D.rect(panneau, Rect2(716, centre - 5, 84, 10), Charte.PANNEAU_3, Charte.RAYON_PILULE)
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var plein := D.rect(panneau, Rect2(716, centre - 5, maxf(10.0, 84.0 * clampf(part, 0, 1)), 10), teinte, Charte.RAYON_PILULE)
		plein.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if choix.size() > 1:
			var second: Dictionary = etat.effectif.get(str(choix[1].get("id", "")), {})
			if not second.is_empty():
				var nom := "%s  %d" % [_nom_court(str(second.get("name", ""))), int(choix[1].get("starts", 0))]
				page._lien_joueur(panneau, Rect2(820, y, 260, pas), second, 17, "RapportAdverseSecond%d" % (index + 1), etat.club_id, nom)

## Bande de terrain : quatre zones de départ de l'action, colorées selon le nombre d'essais ; en-but à droite.
static func _bande(etat: Dictionary, panneau: Panel, rectangle: Rect2, pour: bool) -> void:
	var page = etat.page
	var essais := _filtre(etat.essais, pour)
	var couleur: Color = R.VERT if pour else R.ROUGE
	R.pastille(panneau, rectangle.position.x, rectangle.position.y - 8, "Marqués %d" % essais.size() if pour else "Encaissés %d" % essais.size(), couleur, "haut" if pour else "bas", "RapportAdverseBande" + ("Pour" if pour else "Contre"), 18)
	var comptes := _par_zone(essais)
	var maxi_zone := maxi(1, comptes.max())
	var en_but := 70.0
	var largeur := (rectangle.size.x - en_but) / ZONES.size()
	var haut := rectangle.position.y + 14.0
	var hauteur := rectangle.size.y - 50.0
	var pelouse := D.rect(panneau, Rect2(rectangle.position.x, haut, rectangle.size.x, hauteur), Charte.PELOUSE, Charte.RAYON_PETIT)
	pelouse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in ZONES.size():
		var x := rectangle.position.x + i * largeur
		var n: int = comptes[i]
		var voile := D.rect(panneau, Rect2(x + 2, haut + 2, largeur - 4, hauteur - 4), Color(couleur, .3 + .6 * float(n) / float(maxi_zone)) if n > 0 else Color(0, 0, 0, 0), Charte.RAYON_PETIT)
		voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var zone: Button = page._zone(panneau, Rect2(x, haut, largeur, hauteur), _fenetre_essais.bind(etat, _filtre_zone(essais, i), "%s · %s" % ["Marqués" if pour else "Encaissés", ZONES[i][0]]), "RapportAdverseZone%s%d" % ["Pour" if pour else "Contre", i], "%d essais · %s" % [n, ZONES[i][0]])
		_survol_clair(page, zone)
		var chiffre := D.text(panneau, x + largeur / 2.0, haut + hauteur / 2.0 + 18, str(n), 48, Charte.IVOIRE if n > 0 else Charte.IVOIRE_3, 800, largeur, HORIZONTAL_ALIGNMENT_CENTER)
		chiffre.add_theme_font_override("font", Charte.TITRE_FICHE)
		chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page._etiquette(panneau, x + largeur / 2.0, haut + hauteur + 26, str(ZONES[i][0]), largeur, HORIZONTAL_ALIGNMENT_CENTER)
		if i > 0: D.line(panneau, Vector2(x, haut), Vector2(x, haut + hauteur), Color(Charte.IVOIRE, .35), 2)
	var but_x := rectangle.position.x + rectangle.size.x - en_but
	D.line(panneau, Vector2(but_x, haut), Vector2(but_x, haut + hauteur), Charte.IVOIRE, 3)
	var en_but_fond := D.rect(panneau, Rect2(but_x + 2, haut, en_but - 2, hauteur), Color(Charte.IVOIRE, .06), Charte.RAYON_PETIT)
	en_but_fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var marque: Control = page._marque(panneau, but_x + en_but / 2.0 - 12, haut + hauteur / 2.0, 24, "droite", Charte.IVOIRE_2)
	marque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Origine des essais : pastilles couleur + mot + nombre, à droite du titre de la bande.
	var x_origine := rectangle.position.x + 250.0
	for code: String in ["j", "b", "m"]:
		var n := essais.filter(func(e: Dictionary): return str(e.get("origin", "")) == code).size()
		var libelle := "%s %d" % [ORIGINES[code][0], n]
		R.pastille(panneau, x_origine, rectangle.position.y - 8, libelle, ORIGINES[code][1], "", "RapportAdverseOrigine%s%s" % ["Pour" if pour else "Contre", code], 17)
		x_origine += R.largeur(libelle, 17) + 40.0

## Barres miroir par tranche de 10 min : marqués vers le haut (vert), encaissés vers le bas (rouge).
static func _miroir(etat: Dictionary, panneau: Panel, rectangle: Rect2) -> void:
	var page = etat.page
	var pour := _par_tranche(_filtre(etat.essais, true))
	var contre := _par_tranche(_filtre(etat.essais, false))
	var maxi_t := maxi(1, maxi(pour.max(), contre.max()))
	var largeur := rectangle.size.x / TRANCHES
	var milieu := rectangle.position.y + rectangle.size.y / 2.0 - 10.0
	var demi := rectangle.size.y / 2.0 - 40.0
	D.line(panneau, Vector2(rectangle.position.x, milieu), Vector2(rectangle.position.x + rectangle.size.x, milieu), Charte.FILET, 2)
	for t in TRANCHES:
		var x := rectangle.position.x + t * largeur
		var liste: Array = etat.essais.filter(func(e: Dictionary): return _tranche(e) == t)
		page._survol_ligne(page._zone(panneau, Rect2(x + 4, rectangle.position.y, largeur - 8, rectangle.size.y), _fenetre_essais.bind(etat, liste, "%s" % _libelle_tranche(t)), "RapportAdverseTranche%d" % t, "%s · %d marqués · %d encaissés" % [_libelle_tranche(t), pour[t], contre[t]]))
		for sens in 2:
			var n: int = pour[t] if sens == 0 else contre[t]
			var h := demi * float(n) / float(maxi_t)
			var couleur: Color = R.VERT if sens == 0 else R.ROUGE
			if n > 0:
				var barre := D.rect(panneau, Rect2(x + largeur * .22, milieu - h if sens == 0 else milieu, largeur * .56, h), couleur, Charte.RAYON_PETIT)
				barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var chiffre := D.text(panneau, x + largeur / 2.0, (milieu - h - 8) if sens == 0 else (milieu + h + 26), str(n), 22, couleur if n > 0 else Charte.IVOIRE_3, 800, largeur, HORIZONTAL_ALIGNMENT_CENTER)
			chiffre.add_theme_font_override("font", Charte.TITRE_FICHE)
			chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page._etiquette(panneau, x + largeur / 2.0, rectangle.position.y + rectangle.size.y + 6, _libelle_tranche(t), largeur, HORIZONTAL_ALIGNMENT_CENTER)

## ---- Option B : terrain --------------------------------------------------------------------------------

static func _option_b(etat: Dictionary, section: Control) -> float:
	var page = etat.page
	var hauteur := 880.0
	var terrain: Panel = page._panneau(section, Rect2(0, 66, 760, hauteur), "XV habituel", "RapportAdverseXV", "%d feuilles" % int(etat.matchs))
	_terrain_xv(etat, terrain, Rect2(24, 64, 712, hauteur - 88))
	var grille: Panel = page._panneau(section, Rect2(776, 66, 1472, hauteur), "Zones et minutes des essais", "RapportAdverseGrille")
	_grille(etat, grille, Rect2(24, 70, 1424, 380), true)
	_grille(etat, grille, Rect2(24, 480, 1424, 380), false)
	return 66.0 + hauteur

## Les 15 maillots sur un terrain (attaque vers le haut) : numéro, nom, fréquence du titulaire en pastille colorée.
static func _terrain_xv(etat: Dictionary, panneau: Panel, rectangle: Rect2) -> void:
	var page = etat.page
	var pelouse := D.rect(panneau, rectangle, Charte.PELOUSE, Charte.RAYON_CARTE)
	pelouse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for bande in 10:
		if bande % 2 == 1:
			var rayure := D.rect(panneau, Rect2(rectangle.position.x, rectangle.position.y + bande * rectangle.size.y / 10.0, rectangle.size.x, rectangle.size.y / 10.0), Charte.PELOUSE_2)
			rayure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for repere: float in [.06, .22, .5, .78, .94]:
		var yy := rectangle.position.y + rectangle.size.y * repere
		D.line(panneau, Vector2(rectangle.position.x, yy), Vector2(rectangle.position.x + rectangle.size.x, yy), Color(Charte.IVOIRE, .45 if repere in [.06, .5, .94] else .22), 2)
	var maillots: Array = etat.rapport.get("maillots", [])
	for numero: int in PLACES.keys():
		var place: Vector2 = PLACES[numero]
		var centre := rectangle.position + Vector2(rectangle.size.x * place.x, rectangle.size.y * place.y)
		var choix: Array = maillots[numero - 1] if numero - 1 < maillots.size() else []
		var titul := int(choix[0].get("starts", 0)) if not choix.is_empty() else 0
		var part := float(titul) / maxf(1.0, float(etat.matchs))
		var teinte := _teinte_part(part) if not choix.is_empty() else Charte.IVOIRE_3
		var rond := D.rect(panneau, Rect2(centre.x - 24, centre.y - 24, 48, 48), Color(teinte, .92), Charte.RAYON_PILULE, Charte.IVOIRE)
		rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var num := D.text(panneau, centre.x, centre.y + 10, str(numero), 26, Charte.ENCRE, 800, 48, HORIZONTAL_ALIGNMENT_CENTER)
		num.add_theme_font_override("font", Charte.TITRE_FICHE)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var joueur: Dictionary = etat.effectif.get(str(choix[0].get("id", "")), {}) if not choix.is_empty() else {}
		var nom := _nom_court(str(joueur.get("name", "—"))) if not joueur.is_empty() else "—"
		var plaque := D.rect(panneau, Rect2(centre.x - 70, centre.y + 26, 140, 28), Color(Charte.PANNEAU, .9), Charte.RAYON_PETIT)
		plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frac_texte := "%d/%d" % [titul, int(etat.matchs)] if not choix.is_empty() else ""
		var frac_large := R.largeur(frac_texte, 15) + 6.0
		var etiquette := D.text(plaque, 6, 20, nom, 13, Charte.IVOIRE, 700, 128 - frac_large)
		etiquette.clip_text = true
		etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var frac := D.text(plaque, 134 - frac_large, 20, frac_texte, 15, teinte, 800, frac_large, HORIZONTAL_ALIGNMENT_RIGHT)
		frac.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var zone: Button = page._zone(panneau, Rect2(centre.x - 70, centre.y - 26, 140, 82), _fenetre_maillot.bind(etat, numero - 1), "RapportAdverseMaillot%d" % numero, "Maillot %d · %s" % [numero, nom])
		_survol_clair(page, zone)
		zone.move_to_front()

## Grille minute × zone : lignes = zones de départ (de la ligne d'essai vers le large), colonnes = tranches de 10 min.
static func _grille(etat: Dictionary, panneau: Panel, rectangle: Rect2, pour: bool) -> void:
	var page = etat.page
	var essais := _filtre(etat.essais, pour)
	var couleur: Color = R.VERT if pour else R.ROUGE
	R.pastille(panneau, rectangle.position.x, rectangle.position.y - 4, ("Marqués %d" if pour else "Encaissés %d") % essais.size(), couleur, "haut" if pour else "bas", "RapportAdverseGrille" + ("Pour" if pour else "Contre"), 18)
	var x_origine := rectangle.position.x + 260.0
	for code: String in ["j", "b", "m"]:
		var n := essais.filter(func(e: Dictionary): return str(e.get("origin", "")) == code).size()
		var libelle := "%s %d" % [ORIGINES[code][0], n]
		R.pastille(panneau, x_origine, rectangle.position.y - 4, libelle, ORIGINES[code][1], "", "RapportAdverseOrigine%s%s" % ["Pour" if pour else "Contre", code], 17)
		x_origine += R.largeur(libelle, 17) + 40.0
	var gauche := 130.0
	var droite := 110.0
	var haut := rectangle.position.y + 26.0
	var lignes := ZONES.size()
	var cellule := Vector2((rectangle.size.x - gauche - droite) / TRANCHES, (rectangle.size.y - 26.0 - 44.0) / lignes)
	var cases := []
	var maxi_case := 1
	for z in lignes:
		var rang := []
		for t in TRANCHES:
			var liste: Array = essais.filter(func(e: Dictionary): return _zone_de(e) == z and _tranche(e) == t)
			rang.append(liste)
			maxi_case = maxi(maxi_case, liste.size())
		cases.append(rang)
	for z in lignes:
		var y := haut + z * cellule.y
		page._etiquette(panneau, rectangle.position.x + gauche - 14, y + cellule.y / 2.0 + 6, str(ZONES[z][0]), gauche, HORIZONTAL_ALIGNMENT_RIGHT)
		var total_zone := 0
		for t in TRANCHES:
			var liste: Array = cases[z][t]
			total_zone += liste.size()
			var x := rectangle.position.x + gauche + t * cellule.x
			var n := liste.size()
			var fond := D.rect(panneau, Rect2(x + 3, y + 3, cellule.x - 6, cellule.y - 6), Color(couleur, .14 + .72 * float(n) / float(maxi_case)) if n > 0 else Charte.PANNEAU_3, Charte.RAYON_PETIT)
			fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if n > 0:
				var chiffre := D.text(panneau, x + cellule.x / 2.0, y + cellule.y / 2.0 + 12, str(n), 30, Charte.IVOIRE, 800, cellule.x, HORIZONTAL_ALIGNMENT_CENTER)
				chiffre.add_theme_font_override("font", Charte.TITRE_FICHE)
				chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_survol_clair(page, page._zone(panneau, Rect2(x + 3, y + 3, cellule.x - 6, cellule.y - 6), _fenetre_essais.bind(etat, liste, "%s · %s · %s" % ["Marqués" if pour else "Encaissés", ZONES[z][0], _libelle_tranche(t)]), "RapportAdverseCase%s%d_%d" % ["Pour" if pour else "Contre", z, t], "%d essais" % n))
		var somme := D.text(panneau, rectangle.position.x + rectangle.size.x - droite / 2.0, y + cellule.y / 2.0 + 12, str(total_zone), 28, couleur if total_zone > 0 else Charte.IVOIRE_3, 800, droite, HORIZONTAL_ALIGNMENT_CENTER)
		somme.add_theme_font_override("font", Charte.TITRE_FICHE)
	for t in TRANCHES:
		var x := rectangle.position.x + gauche + t * cellule.x
		var total := 0
		for z in lignes: total += (cases[z][t] as Array).size()
		page._etiquette(panneau, x + cellule.x / 2.0, haut + lignes * cellule.y + 24, _libelle_tranche(t), cellule.x, HORIZONTAL_ALIGNMENT_CENTER)
		var bas := D.text(panneau, x + cellule.x / 2.0, haut + lignes * cellule.y + 44, "%d" % total, 15, couleur if total > 0 else Charte.IVOIRE_3, 700, cellule.x, HORIZONTAL_ALIGNMENT_CENTER)
		bas.mouse_filter = Control.MOUSE_FILTER_IGNORE

## ---- Petites fenêtres ----------------------------------------------------------------------------------

## Liste des essais : minute, adversaire (écusson + nom), score du match, origine, zone ; ligne cliquable = fiche du club.
static func _fenetre_essais(etat: Dictionary, liste: Array, titre: String) -> void:
	var page = etat.page
	var lignes := mini(liste.size(), 10)
	var hauteur := 120.0 + maxf(1, lignes) * 58.0 + 20.0
	var fond := Fenetre.ouvrir(page, "RapportAdverseFenetre", titre.to_upper(), "", 980, hauteur)
	if liste.is_empty():
		page._texte(fond, 28, 130, "0", 26, Charte.IVOIRE_3, 200)
		return
	var tries := liste.duplicate()
	tries.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("minute", 0)) < int(b.get("minute", 0)))
	for i in lignes:
		var essai: Dictionary = tries[i]
		var y := 96.0 + i * 58.0
		page._rayer(fond, Rect2(0, y, 980, 56), i)
		var adverse: Dictionary = page._club(essai.get("opponent"))
		var cible: Button = page._survol_ligne(page._zone(fond, Rect2(0, y, 980, 56), page._ouvrir_club.bind(adverse), "RapportAdverseEssai%d" % i, G.club_name(adverse)))
		cible.mouse_filter = Control.MOUSE_FILTER_STOP
		var minute := D.text(fond, 90, y + 40, "%d′" % int(essai.get("minute", 0)), 30, R.VERT if essai.get("for", false) else R.ROUGE, 800, 70, HORIZONTAL_ALIGNMENT_RIGHT)
		minute.add_theme_font_override("font", Charte.TITRE_FICHE)
		page._crest(fond, adverse, Rect2(110, y + 10, 36, 36))
		page._texte(fond, 156, y + 36, G.club_name(adverse), 19, Charte.IVOIRE, 330)
		var score: Array = essai.get("score", [0, 0])
		var issue := "V" if int(score[0]) > int(score[1]) else "D" if int(score[0]) < int(score[1]) else "N"
		page._pastille(fond, Rect2(500, y + 14, 40, 28), issue, "RapportAdverseIssue%d" % i)
		page._titre(fond, 552, y + 37, "%d–%d" % [int(score[0]), int(score[1])], 22, Charte.IVOIRE, 90)
		var origine: Array = ORIGINES.get(str(essai.get("origin", "j")), ORIGINES.j)
		R.pastille(fond, 660, y + 35, str(origine[0]), origine[1], "", "RapportAdverseEssaiOrigine%d" % i, 16)
		page._etiquette(fond, 950, y + 35, str(ZONES[_zone_de(essai)][0]), 140, HORIZONTAL_ALIGNMENT_RIGHT)

## Titulaires d'un maillot : portrait, nom (fiche), titularisations en barre colorée.
static func _fenetre_maillot(etat: Dictionary, index: int) -> void:
	var page = etat.page
	var maillots: Array = etat.rapport.get("maillots", [])
	var choix: Array = maillots[index] if index < maillots.size() else []
	var hauteur := 120.0 + maxf(1, choix.size()) * 96.0 + 10.0
	var fond := Fenetre.ouvrir(page, "RapportAdverseFenetre", "MAILLOT %d" % (index + 1), "", 760, hauteur)
	if choix.is_empty():
		page._texte(fond, 28, 130, "—", 26, Charte.IVOIRE_3, 200)
		return
	for i in choix.size():
		var joueur: Dictionary = etat.effectif.get(str(choix[i].get("id", "")), {})
		if joueur.is_empty(): continue
		var y := 92.0 + i * 96.0
		page._rayer(fond, Rect2(0, y, 760, 92), i)
		var portrait := G.portrait(0, 0, joueur)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fond.add_child(portrait)
		D.place(portrait, Rect2(24, y + 6, 72, 80))
		page._lien_joueur(fond, Rect2(112, y + 8, 360, 40), joueur, 21, "RapportAdverseMaillotJoueur%d" % i, etat.club_id)
		page._texte(fond, 116, y + 74, str(joueur.get("pos", "")), 16, Charte.IVOIRE_2, 300)
		var titul := int(choix[i].get("starts", 0))
		var part := float(titul) / maxf(1.0, float(etat.matchs))
		var teinte := _teinte_part(part)
		var rail := D.rect(fond, Rect2(480, y + 40, 160, 12), Charte.PANNEAU_3, Charte.RAYON_PILULE)
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var plein := D.rect(fond, Rect2(480, y + 40, maxf(12.0, 160.0 * clampf(part, 0, 1)), 12), teinte, Charte.RAYON_PILULE)
		plein.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page._titre(fond, 736, y + 56, "%d/%d" % [titul, int(etat.matchs)], 26, teinte, 90, HORIZONTAL_ALIGNMENT_RIGHT)

## Survol translucide : la couleur de la case reste visible sous le voile clair.
static func _survol_clair(page, zone: Button) -> void:
	zone.add_theme_stylebox_override("hover", page._style(Color(Charte.IVOIRE, .10), Charte.IVOIRE, 2))
	zone.add_theme_stylebox_override("pressed", page._style(Color(Charte.IVOIRE, .16), Charte.IVOIRE, 2))

## ---- Calculs -------------------------------------------------------------------------------------------

static func _filtre(essais: Array, pour: bool) -> Array:
	return essais.filter(func(e: Dictionary): return bool(e.get("for", false)) == pour)

static func _zone_de(essai: Dictionary) -> int:
	var profondeur := int(essai.get("depth", 0))
	if profondeur <= 5: return 3
	if profondeur <= 22: return 2
	if profondeur <= 50: return 1
	return 0

static func _par_zone(essais: Array) -> Array:
	var comptes: Array = [0, 0, 0, 0]
	for essai: Dictionary in essais: comptes[_zone_de(essai)] += 1
	return comptes

static func _filtre_zone(essais: Array, zone: int) -> Array:
	return essais.filter(func(e: Dictionary): return _zone_de(e) == zone)

static func _tranche(essai: Dictionary) -> int:
	return clampi(int(essai.get("minute", 0)) / 10, 0, TRANCHES - 1)

static func _par_tranche(essais: Array) -> Array:
	var comptes := []
	comptes.resize(TRANCHES)
	comptes.fill(0)
	for essai: Dictionary in essais: comptes[_tranche(essai)] += 1
	return comptes

static func _libelle_tranche(t: int) -> String:
	return "%d-%d′" % [t * 10, (t + 1) * 10] if t < TRANCHES - 1 else "70-80′+"

## Fréquence d'un titulaire : vert = indiscutable, citron = habituel, orange = tournant, rouge = rare.
static func _teinte_part(part: float) -> Color:
	if part >= .75: return R.VERT
	if part >= .5: return Color("d4e35c")
	if part >= .3: return R.ORANGE
	return R.ROUGE

static func _nom_court(nom: String) -> String:
	var morceaux := nom.strip_edges().split(" ", false)
	if morceaux.size() <= 1: return nom
	return morceaux[0].left(1) + ". " + " ".join(morceaux.slice(1))
