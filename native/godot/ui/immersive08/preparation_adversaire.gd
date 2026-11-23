extends RefCounted
## Rapport sur l'adversaire (idée n° 10 de la revue FM27, choix de Léo du 23/11/2026) : à gauche, le XV habituel en
## maillots sur un terrain, la fréquence de chaque titulaire colorée (vert ≥ 75 %, citron ≥ 50 %, orange ≥ 30 %,
## gris en dessous) ; à droite, les bandes du terrain d'où partent les essais marqués / encaissés (profondeur du
## départ de l'action) et les essais par tranche de 10 minutes. Données réelles de la fiche du club
## (club-sheet.cjs `rapport`) : essais de l'historique (minute, origine, profondeur) et feuilles de match.
## Deux entrées : la sous-page « Rapport adverse » de la Préparation (`construire`, avec en tête les points forts /
## faibles de l'idée 29, adversaire_forces.gd) et l'onglet « Rapport » de la fiche du club (`onglet_club`).
## Le petit terrain montre au choix (un clic sur la pastille) le XV habituel, celui du dernier match ou le XV probable. Tout chiffre de zone / tranche / maillot ouvre une petite fenêtre visuelle
## (Échap, ✕, clic à côté la ferment).
## `page` : un canevas de Préparation (preparation_canvas.gd), dont on réutilise les aides de dessin ;
## `hote` : le nœud plein écran qui reçoit les petites fenêtres.
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
## Fréquence d'un titulaire au maillot (choix de Léo) : [seuil bas, couleur, légende], du plus fort au plus faible.
const PALIERS := [[.75, R.VERT, "75 %"], [.5, Charte.ATTRIBUT_55, "50 %"], [.3, R.ORANGE, "30 %"], [0.0, Charte.GRIS_VERT, "−30 %"]]
## Terrain vertical : place de chaque maillot, l'équipe attaque vers le haut. Deux maillots qui se recouvrent en largeur
## sont séparés d'au moins 0,115 de hauteur (rond + plaque = 76 unités, terrain de 718 au moins).
const PLACES := {1: Vector2(.3, .09), 2: Vector2(.5, .09), 3: Vector2(.7, .09), 4: Vector2(.4, .205), 5: Vector2(.6, .205),
	6: Vector2(.17, .27), 7: Vector2(.83, .27), 8: Vector2(.5, .32), 9: Vector2(.5, .435), 10: Vector2(.4, .55),
	12: Vector2(.3, .665), 13: Vector2(.18, .78), 11: Vector2(.09, .6), 14: Vector2(.91, .6), 15: Vector2(.5, .9)}
## Rond du numéro et plaque du nom sous chaque maillot (unités du gabarit).
const ROND := 44.0
const PLAQUE := Vector2(132, 28)
## Largeur du terrain du XV (gauche) ; la colonne des essais prend le reste des 2248 du gabarit.
const LARGEUR_XV := 760.0

## Sous-page de la Préparation ; rend sa hauteur (unités du gabarit).
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
	var etat := _etat(page, page, club_id, donnees)
	var x := 600.0
	page._crest(section, adversaire, Rect2(x, 4, 44, 44))
	Link.name_link(page.app, section, C.reach_rect(Rect2(x + 54, 6, 520, 42)), "club", str(club_id), G.club_name(adversaire).to_upper(), 24, Charte.IVOIRE, "RapportAdverseClub")
	# Points forts / faibles et hommes clés (revue FM27, idée 29) en tête ; le rapport dessous.
	var forces: float = load("res://ui/immersive08/adversaire_forces.gd").construire(page, section, donnees)
	var bas := Control.new()
	bas.name = "RapportAdverseBas"
	bas.mouse_filter = Control.MOUSE_FILTER_PASS
	section.add_child(bas)
	D.place(bas, Rect2(0, 66.0 + forces, 2248, 946))
	return 66.0 + forces + _dessiner(etat, bas, 880.0, 0.0)

## Onglet « Rapport » de la fiche du club (club_sheet_canvas.gd) : `zone` = l'espace de l'onglet (2248 × `hauteur`),
## `hote` = la fiche, qui reçoit les petites fenêtres. Les aides de dessin sont celles de la Préparation, portées par
## un canevas caché sans construction (aucun écran de Préparation n'est bâti, aucune commande envoyée).
static func onglet_club(app: Control, hote: Control, zone: Control, club_id: int, donnees: Dictionary, hauteur: float) -> void:
	var page: Control = load("res://ui/immersive08/preparation_canvas.gd").new()
	page.name = "RapportAdverseOutils"
	page.app = app
	page.visible = false
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.set_process_unhandled_key_input(false)
	# Le contexte de match de la Préparation n'est jamais lié ici (pas de commande de match depuis une fiche).
	if is_instance_valid(page.match_context): page.match_context.free()
	zone.add_child(page)
	_dessiner(_etat(page, hote, club_id, donnees), zone, hauteur - 66.0, 0.0)

static func _etat(page, hote: Control, club_id: int, donnees: Dictionary) -> Dictionary:
	var rapport: Dictionary = donnees.get("rapport", {})
	var effectif := {}
	for joueur: Dictionary in donnees.get("squad", []): effectif[str(joueur.get("id", ""))] = joueur
	return {"page": page, "hote": hote, "club_id": club_id, "effectif": effectif, "rapport": rapport,
		"essais": rapport.get("essais", []), "matchs": int(rapport.get("sheets", 0))}

## XV montré sur le petit terrain : habituel (titularisations), dernier match, probable (composition automatique).
const MODES_XV := [["habituel", "Habituel"], ["dernier", "Dernier match"], ["probable", "Probable"]]
static var mode_xv := "habituel"

## Joueur au maillot `index` selon le mode, et ses titularisations à ce maillot : [id, titularisations] ou [] (vide).
static func _au_maillot(etat: Dictionary, index: int, mode: String) -> Array:
	var maillots: Array = etat.rapport.get("maillots", [])
	var choix: Array = maillots[index] if index < maillots.size() and maillots[index] is Array else []
	if mode == "habituel":
		return [str(choix[0].get("id", "")), int(choix[0].get("starts", 0))] if not choix.is_empty() else []
	var liste: Variant = etat.rapport.get(mode)
	if not liste is Array or index >= liste.size() or liste[index] == null: return []
	var id := str(liste[index])
	for c: Dictionary in choix:
		if str(c.get("id", "")) == id: return [id, int(c.get("starts", 0))]
	return [id, 0]

## En-tête (tuiles matchs / marqués / encaissés à droite), puis le terrain du XV à gauche, les essais à droite.
## `hauteur` : hauteur de la colonne des essais (sous les tuiles) ; `haut_xv` : haut du terrain du XV (66 sous le retour
## et le nom du club dans la Préparation, 0 dans la fiche du club où l'en-tête est déjà là).
static func _dessiner(etat: Dictionary, section: Control, hauteur: float, haut_xv: float) -> float:
	var page = etat.page
	var droite := 2248.0
	var pour := _filtre(etat.essais, true).size()
	var contre := _filtre(etat.essais, false).size()
	for tuile: Array in [["%d" % contre, "encaissés", R.ROUGE, "RapportAdverseContre"], ["%d" % pour, "marqués", R.VERT, "RapportAdversePour"], ["%d" % int(etat.matchs), "matchs", Charte.IVOIRE, "RapportAdverseMatchs"]]:
		droite -= 200.0
		R.tuile(section, Rect2(droite, 0, 200, 52), str(tuile[0]), str(tuile[1]), tuile[2], str(tuile[3]), 32)
		droite -= 12.0
	var haut_terrain := 66.0 + hauteur - haut_xv
	var terrain: Panel = page._panneau(section, Rect2(0, haut_xv, LARGEUR_XV, haut_terrain), "Leur XV", "RapportAdverseXV")
	var pelouse := Control.new()
	pelouse.name = "RapportAdverseXVPelouse"
	pelouse.mouse_filter = Control.MOUSE_FILTER_PASS
	terrain.add_child(pelouse)
	D.place(pelouse, Rect2(0, 0, LARGEUR_XV, haut_terrain))
	var zone_xv := Rect2(24, 64, LARGEUR_XV - 48, haut_terrain - 126)
	_modes_xv(etat, terrain, pelouse, zone_xv)
	_terrain_xv(etat, pelouse, zone_xv)
	_legende(terrain, Vector2(24, haut_terrain - 28))
	var x := LARGEUR_XV + 16.0
	var large := 2248.0 - x
	var haut_zones := roundf(hauteur * .53)
	var bande := (haut_zones - 170.0) / 2.0
	var zones: Panel = page._panneau(section, Rect2(x, 66, large, haut_zones), "D'où partent leurs essais", "RapportAdverseZones")
	_bande(etat, zones, Rect2(24, 86, large - 48, bande), true)
	_bande(etat, zones, Rect2(24, 146 + bande, large - 48, bande), false)
	var haut_temps := hauteur - haut_zones - 14.0
	var temps: Panel = page._panneau(section, Rect2(x, 66 + haut_zones + 14.0, large, haut_temps), "Essais par tranche de 10 min", "RapportAdverseTemps")
	_miroir(etat, temps, Rect2(24, 60, large - 48, haut_temps - 76))
	return 66.0 + hauteur

## Pastilles du mode du petit terrain (en-tête du panneau) : un clic change le XV montré, sans autre bouton.
static func _modes_xv(etat: Dictionary, terrain: Panel, pelouse: Control, zone_xv: Rect2) -> void:
	var ancien := terrain.get_node_or_null("RapportAdverseXVModes")
	if ancien != null:
		ancien.name = "RapportAdverseXVModesAncien"
		ancien.queue_free()
	var barre := Control.new()
	barre.name = "RapportAdverseXVModes"
	barre.mouse_filter = Control.MOUSE_FILTER_PASS
	terrain.add_child(barre)
	D.place(barre, Rect2(0, 0, LARGEUR_XV, 60))
	var x := LARGEUR_XV - 20.0
	for i in range(MODES_XV.size() - 1, -1, -1):
		var mode: String = MODES_XV[i][0]
		var texte: String = MODES_XV[i][1]
		x -= R.largeur(texte, 17) + 26.0
		var actif := mode == mode_xv
		var pa := R.pastille(barre, x, 38, texte, R.BLEU if actif else Charte.IVOIRE_3, "", "RapportAdverseXVMode_" + mode, 17)
		R.cliquable(pa, func():
			mode_xv = mode
			for enfant in pelouse.get_children():
				pelouse.remove_child(enfant)
				enfant.queue_free()
			_modes_xv(etat, terrain, pelouse, zone_xv)
			_terrain_xv(etat, pelouse, zone_xv), "RapportAdverseXVModeLien_" + mode, texte)
		x -= 8.0

## Légende des fréquences : une pastille de couleur et son seuil, rien d'autre.
static func _legende(panneau: Panel, origine: Vector2) -> void:
	var x := origine.x
	for palier: Array in PALIERS:
		var rond := D.rect(panneau, Rect2(x, origine.y - 9, 18, 18), palier[1], Charte.RAYON_PILULE)
		rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texte := D.text(panneau, x + 26, origine.y + 6, str(palier[2]), 16, Charte.IVOIRE_2, 700, 90)
		texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		x += 26.0 + R.largeur(str(palier[2]), 16) + 34.0

## Les 15 maillots sur un terrain (attaque vers le haut) : numéro dans un rond coloré par la fréquence du titulaire,
## nom et titularisations / feuilles dessous. Clic = petite fenêtre des titulaires du maillot.
static func _terrain_xv(etat: Dictionary, panneau: Control, rectangle: Rect2) -> void:
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
	for numero: int in PLACES.keys():
		var place: Vector2 = PLACES[numero]
		var centre := rectangle.position + Vector2(rectangle.size.x * place.x, rectangle.size.y * place.y)
		var choix: Array = _au_maillot(etat, numero - 1, mode_xv)
		var titul := int(choix[1]) if not choix.is_empty() else 0
		var part := float(titul) / maxf(1.0, float(etat.matchs))
		var teinte := teinte_part(part) if not choix.is_empty() else Charte.IVOIRE_3
		var demi := ROND / 2.0
		var rond := D.rect(panneau, Rect2(centre.x - demi, centre.y - demi, ROND, ROND), teinte, Charte.RAYON_PILULE, Charte.IVOIRE)
		rond.name = "RapportAdverseRond%d" % numero
		rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var num := D.text(panneau, centre.x, centre.y + 9, str(numero), 24, Charte.ENCRE, 800, ROND, HORIZONTAL_ALIGNMENT_CENTER)
		num.add_theme_font_override("font", Charte.TITRE_FICHE)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var joueur: Dictionary = etat.effectif.get(str(choix[0]), {}) if not choix.is_empty() else {}
		var nom := _nom_court(str(joueur.get("name", "—"))) if not joueur.is_empty() else "—"
		var plaque := D.rect(panneau, Rect2(centre.x - PLAQUE.x / 2.0, centre.y + demi + 2, PLAQUE.x, PLAQUE.y), Color(Charte.PANNEAU, .9), Charte.RAYON_PETIT)
		plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frac_texte := "%d/%d" % [titul, int(etat.matchs)] if not choix.is_empty() else ""
		var frac_large := R.largeur(frac_texte, 15) + 6.0
		var place_nom := PLAQUE.x - 10.0 - frac_large
		# Nom raccourci à sa place (mesuré dans la police du libellé) : il ne passe jamais sous le chiffre.
		var etiquette := D.text(plaque, 5, 20, _couper(nom, 13, place_nom), 13, Charte.IVOIRE, 700, place_nom)
		etiquette.tooltip_text = nom
		# Aligné à droite : `D.text` prend alors x comme bord droit.
		var frac := D.text(plaque, PLAQUE.x - 5.0, 20, frac_texte, 15, teinte, 800, frac_large, HORIZONTAL_ALIGNMENT_RIGHT)
		frac.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var zone: Button = page._zone(panneau, Rect2(centre.x - PLAQUE.x / 2.0, centre.y - demi - 2, PLAQUE.x, ROND + PLAQUE.y + 6), _fenetre_maillot.bind(etat, numero - 1), "RapportAdverseMaillot%d" % numero, "Maillot %d · %s" % [numero, nom])
		_survol_clair(page, zone)
		zone.move_to_front()

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

## ---- Petites fenêtres ----------------------------------------------------------------------------------

## Liste des essais : minute, adversaire (écusson + nom), score du match, origine, zone ; ligne cliquable = fiche du club.
static func _fenetre_essais(etat: Dictionary, liste: Array, titre: String) -> void:
	var page = etat.page
	var lignes := mini(liste.size(), 10)
	var hauteur := 120.0 + maxf(1, lignes) * 58.0 + 20.0
	var fond := Fenetre.ouvrir(etat.hote, "RapportAdverseFenetre", titre.to_upper(), "", 980, hauteur)
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
	var fond := Fenetre.ouvrir(etat.hote, "RapportAdverseFenetre", "MAILLOT %d" % (index + 1), "", 760, hauteur)
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
		var teinte := teinte_part(part)
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

## Fréquence d'un titulaire au maillot (titularisations / feuilles) : vert ≥ 75 %, citron ≥ 50 %, orange ≥ 30 %, gris.
static func teinte_part(part: float) -> Color:
	for palier: Array in PALIERS:
		if part >= float(palier[0]): return palier[1]
	return Charte.GRIS_VERT

## Texte raccourci (« … ») jusqu'à tenir dans `largeur` unités à la taille `taille` (poids 700).
static func _couper(texte: String, taille: int, largeur: float) -> String:
	if R.largeur(texte, taille) <= largeur: return texte
	var court := texte
	while court.length() > 1 and R.largeur(court + "…", taille) > largeur: court = court.left(court.length() - 1)
	return court.strip_edges() + "…"

static func _nom_court(nom: String) -> String:
	var morceaux := nom.strip_edges().split(" ", false)
	if morceaux.size() <= 1: return nom
	return morceaux[0].left(1) + ". " + " ".join(morceaux.slice(1))
