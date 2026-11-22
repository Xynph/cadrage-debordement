extends RefCounted
## Panneaux latéraux de l'Effectif (choix de Léo du 21/11/2026, planche PANNEAUX_A / PANNEAUX_B), à GAUCHE du tableau
## (charte : rien à droite, rien ne suit la ligne choisie). Un seul état, mémorisé dans les préférences d'interface :
##  - déplié : colonne de trois panneaux empilés XV / SEMAINE / GROUPE, chacun repliable par son en-tête ; « « » range
##    la colonne en rail (replier le dernier panneau ouvert fait de même) ;
##  - replié : rail d'icônes avec mini-repères, le tableau reprend sa largeur ; un clic sur une icône rouvre la colonne
##    avec ce panneau ouvert.
## Données du moteur uniquement : feuille de match (numéros 1-15, condition), programme de la semaine jour par jour
## (clubLife.weekProgram), moral, confiance des joueurs et tensions du vestiaire (clubLife.relationships).
## Tout est cliquable : Composition, fiche du joueur, Entraînement, Vestiaire, petite fenêtre visuelle des tensions.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Charte = preload("res://ui/charte.gd")
const FenetreVisuelle = preload("res://ui/immersive08/fenetre_visuelle.gd")

const LARGEUR := 470.0
const RAIL := 84.0
const ENTETE := 62.0
const PANNEAUX := ["xv", "semaine", "groupe"]
const TITRES := {"xv": "XV", "semaine": "SEMAINE", "groupe": "GROUPE"}
const ICONES := {"xv": "tactic", "semaine": "calendar", "groupe": "people"}
const ECRANS := {"xv": "Composition", "semaine": "Entraînement", "groupe": "Vestiaire"}
const CLE := "panneaux_effectif"
const DEFAUT := {"replie": false, "xv": true, "semaine": true, "groupe": true}
## Places du XV sur le mini-terrain (fractions largeur, hauteur ; on attaque vers le haut).
const PLACES := {1: Vector2(.32, .13), 2: Vector2(.5, .13), 3: Vector2(.68, .13), 4: Vector2(.41, .26), 5: Vector2(.59, .26),
	6: Vector2(.24, .37), 8: Vector2(.5, .39), 7: Vector2(.76, .37), 9: Vector2(.42, .52), 10: Vector2(.6, .6),
	11: Vector2(.09, .74), 12: Vector2(.36, .72), 13: Vector2(.64, .72), 14: Vector2(.91, .74), 15: Vector2(.5, .88)}
## Jours du programme : couleur de la charte et icône (jamais la couleur seule).
const JOURS := {"match": ["ball", "Match"], "veille": ["flag", "Veille"], "seance": ["train", "Séance"], "recuperation": ["heart", "Récupération"], "repos": ["", "Repos"]}
const CHARGES := {"repos": "Repos", "normal": "Normal", "intense": "Intensif"}
const NIVEAUX := ["Calme", "Faible", "Vive", "Crise"]
const RAISONS := {"mecontent": "heart", "promesse": "warning", "rivalite": "people"}

# ---------------------------------------------------------------- état (préférence d'interface)

static func etat(app: Control) -> Dictionary:
	var e: Dictionary = DEFAUT.duplicate()
	var prefs: Variant = app.get("user_preferences")
	if prefs != null and prefs.data.get(CLE) is Dictionary: e.merge(prefs.data[CLE], true)
	elif app.management_ui.get(CLE) is Dictionary: e.merge(app.management_ui[CLE], true)
	if OS.get_environment("CD_PANNEAUX_REPLIES") == "1" and not app.management_ui.has(CLE + "_capture"):
		app.management_ui[CLE + "_capture"] = true
		e.replie = true
		_garder(app, e)
	return e

## Mémorise l'état : fichier des préférences s'il est chargé, sinon l'état de l'interface de la session.
static func _garder(app: Control, e: Dictionary) -> void:
	app.management_ui[CLE] = e.duplicate()
	var prefs: Variant = app.get("user_preferences")
	if prefs != null: prefs.set_value(CLE, e.duplicate())

static func _changer(app: Control, e: Dictionary) -> void:
	if not bool(e.replie) and PANNEAUX.all(func(id: String): return not bool(e.get(id, true))): e.replie = true
	_garder(app, e)
	app._render(false)

## Largeur réservée à gauche du tableau (unités du gabarit 2248).
static func reserve(app: Control) -> float:
	return RAIL + 18.0 if bool(etat(app).replie) else LARGEUR + 24.0

static func construire(page: Control, app: Control, y: float, bas: float) -> void:
	if bool(etat(app).replie): _rail(page, app, y, bas)
	else: _colonne(page, app, y, bas)

# ---------------------------------------------------------------- déplié : colonne empilée

static func _colonne(page: Control, app: Control, y: float, bas: float) -> void:
	var e := etat(app)
	var hauteurs := {"xv": 372.0, "semaine": 214.0, "groupe": 300.0}
	var ouverts := PANNEAUX.filter(func(id: String): return bool(e.get(id, true)))
	var libre := (bas - y) - PANNEAUX.size() * ENTETE - (PANNEAUX.size() - 1) * 14.0
	var voulu := 0.0
	for id: String in ouverts: voulu += hauteurs[id]
	var echelle := minf(1.0, libre / maxf(1.0, voulu))
	var cy := y
	for i in PANNEAUX.size():
		var id: String = PANNEAUX[i]
		var ouvert := bool(e.get(id, true))
		var h := ENTETE + (float(hauteurs[id]) * echelle if ouvert else 0.0)
		var panneau := D.panel(page, Rect2(0, cy, LARGEUR, h), "", "", "", "PanneauEffectif_" + id)
		panneau.clip_contents = true
		Charte.ombre_derriere(panneau) # le panneau rogne son contenu : l'ombre passe à un calque frère
		_entete(panneau, app, id, ouvert, func():
			e[id] = not bool(e.get(id, true))
			_changer(app, e), i == 0)
		if ouvert: _contenu(panneau, page, app, id, Rect2(18, ENTETE, LARGEUR - 36, h - ENTETE - 14))
		cy += h + 14.0

## En-tête = poignée : icône, titre Anton, résumé visuel quand replié, flèche vers l'écran, chevron ; « « » sur le premier.
static func _entete(panneau: Control, app: Control, id: String, ouvert: bool, basculer: Callable, ranger: bool) -> void:
	var poignee := Button.new()
	poignee.name = "PanneauPoignee_" + id
	poignee.focus_mode = Control.FOCUS_ALL
	poignee.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	poignee.accessibility_name = ("Replier " if ouvert else "Déplier ") + str(TITRES[id])
	poignee.tooltip_text = poignee.accessibility_name
	_styles(poignee, 24, .06)
	panneau.add_child(poignee)
	D.place(poignee, Rect2(0, 0, LARGEUR, ENTETE))
	poignee.pressed.connect(basculer)
	var icone := C.icon(ICONES[id], 26, Charte.IVOIRE_2)
	poignee.add_child(icone)
	D.place(icone, Rect2(20, (ENTETE - 26) / 2.0, 26, 26))
	var titre := D.text(poignee, 58, ENTETE / 2.0 + 12, TITRES[id], 30, Charte.IVOIRE, 700, 160)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not ouvert: _resume(poignee, app, id, Vector2(58 + R.largeur(TITRES[id], 30) + 22, ENTETE / 2.0))
	var chevron := D.text(poignee, LARGEUR - 30, ENTETE / 2.0 + 9, "▾" if ouvert else "▸", 26, Charte.IVOIRE_2, 700, 24, HORIZONTAL_ALIGNMENT_CENTER)
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var aller := _bouton(panneau, Rect2(LARGEUR - 108, 11, 58, ENTETE - 22), func(): _ecran(app, id), "PanneauEcran_" + id, ECRANS[id])
	var fleche := C.icon("arrow", 22, Charte.IVOIRE)
	aller.add_child(fleche)
	D.place(fleche, Rect2(18, (ENTETE - 22 - 22) / 2.0, 22, 22))
	if ranger and ouvert:
		var rail := _bouton(panneau, Rect2(LARGEUR - 166, 11, 50, ENTETE - 22), func():
			var e := etat(app)
			e.replie = true
			_changer(app, e), "PanneauxReplier", "Replier les panneaux")
		D.text(rail, 25, (ENTETE - 22) / 2.0 + 9, "«", 28, Charte.IVOIRE_2, 700, 50, HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE

## Résumé visuel d'un panneau replié (ligne d'en-tête) : pas de phrase.
static func _resume(parent: Control, app: Control, id: String, at: Vector2) -> void:
	match id:
		"xv":
			var xv := _xv(app)
			var x := at.x
			for n in range(1, 16):
				var j: Dictionary = xv.get(n, {})
				D.rect(parent, Rect2(x, at.y - 6, 12, 12), _teinte_condition(j) if not j.is_empty() else Charte.FILET, 99)
				x += 14.5
		"semaine":
			var jours := _jours_programme(app)
			for i in jours.size():
				var j: Dictionary = jours[i]
				D.rect(parent, Rect2(at.x + i * 30.0, at.y - 11, 24, 22), _couleur_jour(j), 6)
				if bool(j.get("today", false)): D.rect(parent, Rect2(at.x + i * 30.0 + 6, at.y + 14, 12, 3), Charte.IVOIRE, 2)
		"groupe":
			var rel := _relations(app)
			var x := at.x
			for m: Array in [[rel.get("morale"), Charte.MORAL, "heart"], [rel.get("playerTrust"), Charte.CONFIANCE, "shield"]]:
				var p := R.pastille(parent, x, at.y + 8, _n(m[0]), m[1], m[2], "", 19)
				x += p.size.x / C.density + 8.0
			var t := _tensions(app)
			if not t.is_empty(): R.pastille(parent, x, at.y + 8, str(t.players.size()), _couleur_niveau(int(t.level)), "warning", "", 19)

static func _contenu(panneau: Control, page: Control, app: Control, id: String, zone: Rect2) -> void:
	match id:
		"xv": _terrain(panneau, page, app, zone)
		"semaine": _semaine(panneau, app, zone)
		"groupe": _groupe(panneau, page, app, zone)

# ---------------------------------------------------------------- replié : rail d'icônes

static func _rail(page: Control, app: Control, y: float, bas: float) -> void:
	var rail := D.panel(page, Rect2(0, y, RAIL, bas - y), "", "", "", "PanneauxRail")
	for i in PANNEAUX.size():
		var id: String = PANNEAUX[i]
		var zone := Rect2(10, 12 + i * 112.0, RAIL - 20, 100)
		var fond := D.rect(rail, zone, Charte.PANNEAU_3, 12)
		var icone := C.icon(ICONES[id], 30, Charte.IVOIRE_2)
		fond.add_child(icone)
		D.place(icone, Rect2((zone.size.x - 30) / 2.0, 16, 30, 30))
		_marque_rail(fond, app, id, zone.size.x)
		_bouton(rail, zone, func():
			var e := etat(app)
			e.replie = false
			e[id] = true
			_changer(app, e), "PanneauOnglet_" + id, TITRES[id])

static func _marque_rail(fond: Control, app: Control, id: String, l: float) -> void:
	match id:
		"xv":
			var xv := _xv(app)
			var bas := xv.values().filter(func(j: Dictionary): return float(j.get("condition", 100)) < 85).size()
			D.rect(fond, Rect2((l - 40) / 2.0, 62, 40, 22), (R.ORANGE if bas > 0 else R.VERT).lerp(Charte.PANNEAU_3, .55), 11)
			D.text(fond, l / 2.0, 79, str(xv.size()), 17, Charte.IVOIRE, 700, 40, HORIZONTAL_ALIGNMENT_CENTER)
		"semaine":
			var jours := _jours_programme(app)
			for i in jours.size():
				var j: Dictionary = jours[i]
				D.rect(fond, Rect2((l - 7 * 8.0) / 2.0 + i * 8.0, 66, 6, 18 if bool(j.get("today", false)) else 14), _couleur_jour(j), 2)
		"groupe":
			var t := _tensions(app)
			var niveau := int(t.get("level", 0))
			D.rect(fond, Rect2(l / 2.0 - 22, 66, 12, 12), Charte.MORAL, 99)
			D.rect(fond, Rect2(l / 2.0 - 6, 66, 12, 12), Charte.CONFIANCE, 99)
			D.rect(fond, Rect2(l / 2.0 + 10, 66, 12, 12), _couleur_niveau(niveau) if niveau > 0 else Charte.FILET, 99)

# ---------------------------------------------------------------- contenus

## Mini-terrain : les quinze numéros de la feuille, pastille teintée par la condition, clic = fiche du joueur.
static func _terrain(parent: Control, page: Control, app: Control, zone: Rect2) -> void:
	var cote := minf(zone.size.x, (zone.size.y - 30) / 0.86)
	var terrain := Rect2(zone.position.x + (zone.size.x - cote) / 2.0, zone.position.y + 6, cote, minf(zone.size.y - 36, cote * 0.86))
	var pelouse := D.rect(parent, terrain, Color("1e3a2a"), 12)
	pelouse.name = "PanneauTerrain"
	var ligne := Color(Charte.IVOIRE, .22)
	for f: float in [.06, .28, .5, .72, .94]:
		D.line(pelouse, Vector2(10, terrain.size.y * f), Vector2(terrain.size.x - 10, terrain.size.y * f), ligne if f in [.06, .5, .94] else Color(ligne, .5), 2 if f in [.06, .94] else 1)
	_bouton(parent, terrain, func(): _ecran(app, "xv"), "PanneauTerrainOuvrir", "Composition")
	var xv := _xv(app)
	var d := clampf(terrain.size.x * .095, 30.0, 46.0)
	for n: int in PLACES:
		var c: Vector2 = terrain.position + Vector2(PLACES[n].x * terrain.size.x, PLACES[n].y * terrain.size.y)
		var j: Dictionary = xv.get(n, {})
		var rect := Rect2(c - Vector2(d, d) / 2.0, Vector2(d, d))
		if j.is_empty():
			var vide := D.rect(parent, rect, Color.TRANSPARENT, 99, Charte.IVOIRE_2)
			D.text(vide, d / 2.0, d / 2.0 + 7, str(n), 19, Charte.IVOIRE_2, 700, d, HORIZONTAL_ALIGNMENT_CENTER)
			_bouton(parent, rect, func(): _ecran(app, "xv"), "PanneauPoste_%d" % n, "N° %d · Composition" % n)
			continue
		var rond := D.rect(parent, rect, _teinte_condition(j), 99)
		rond.name = "PanneauRond_%d" % n
		D.text(rond, d / 2.0, d / 2.0 + 7, str(n), 20, Charte.NUIT, 800, d, HORIZONTAL_ALIGNMENT_CENTER)
		var id := str(j.get("id", ""))
		_bouton(parent, rect.grow(4), func(): _fiche(page, app, id), "PanneauJoueur_%d" % n, "%s · %d %%" % [str(j.get("name", "")), int(j.get("condition", 0))])
	# Légende par forme et couleur (le numéro est écrit, la condition est dans l'infobulle).
	var ly := terrain.end.y + 26
	var lx := terrain.position.x
	for k: Array in [[R.VERT, "85+"], [R.ORANGE, "60+"], [R.ROUGE, "−60"]]:
		if ly > zone.end.y + 10: break
		D.rect(parent, Rect2(lx, ly - 12, 14, 14), k[0], 99)
		D.text(parent, lx + 20, ly, k[1], 17, Charte.IVOIRE_2, 700, 60)
		lx += 90.0

## Semaine : sept jours du programme du moteur (couleur + icône), repère sur aujourd'hui, puis la charge de la séance.
static func _semaine(parent: Control, app: Control, zone: Rect2) -> void:
	var jours := _jours_programme(app)
	if jours.is_empty(): return
	var gap := 8.0
	var l := (zone.size.x - gap * 6) / 7.0
	var h := minf(96.0, zone.size.y - 98)
	for i in jours.size():
		var j: Dictionary = jours[i]
		var aujourdhui := bool(j.get("today", false))
		var r := Rect2(zone.position.x + i * (l + gap), zone.position.y + 30, l, h)
		D.text(parent, r.position.x + l / 2.0, zone.position.y + 22, str(j.get("lettre", "")), 18, Charte.IVOIRE if aujourdhui else Charte.IVOIRE_2, 700, l, HORIZONTAL_ALIGNMENT_CENTER)
		var kind := str(j.get("kind", "repos"))
		var case_ := D.rect(parent, r, _couleur_jour(j), 10, Charte.IVOIRE if aujourdhui else Color.TRANSPARENT)
		case_.name = "PanneauJour_%d" % i
		if bool(j.get("past", false)): case_.modulate = Color(1, 1, 1, .55)
		var icone: String = JOURS.get(kind, ["", ""])[0]
		if bool(j.get("done", false)) or (kind == "match" and bool(j.get("played", false))): icone = "check"
		if not icone.is_empty():
			var im := C.icon(icone, 26, Charte.NUIT if kind != "repos" else Charte.IVOIRE_2)
			case_.add_child(im)
			D.place(im, Rect2((l - 26) / 2.0, (h - 26) / 2.0, 26, 26))
		if aujourdhui: D.rect(parent, Rect2(r.position.x + l / 2.0 - 12, r.end.y + 6, 24, 5), Charte.IVOIRE, 2)
		var aide := "%s · %s" % [str(j.get("date", "")), JOURS.get(kind, ["", kind])[1]]
		if kind == "seance": aide += " · " + str(CHARGES.get(str(j.get("charge", "normal")), ""))
		_bouton(parent, r, func(): _ecran(app, "semaine"), "PanneauJourOuvrir_%d" % i, aide)
	var mode := str(_programme(app).get("charge", "normal"))
	var x := zone.position.x
	var base := zone.position.y + 30 + h + 52
	for k: Array in [["repos", Charte.REPOS, "heart"], ["normal", Charte.NORMAL, "train"], ["intense", Charte.INTENSIF, "train"]]:
		var choisi: bool = k[0] == mode
		var p := R.pastille(parent, x, base, CHARGES[k[0]], k[1] if choisi else Charte.IVOIRE_3, k[2], "PanneauCharge_" + str(k[0]), 19)
		if choisi: (p.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(k[1], .32)
		R.cliquable(p, func(): _ecran(app, "semaine"), "PanneauChargeOuvrir_" + str(k[0]), str(CHARGES[k[0]]))
		x += p.size.x / C.density + 10.0

## Groupe : jauges moral et confiance des joueurs, tensions en pastille + portraits, relais pressenti.
static func _groupe(parent: Control, page: Control, app: Control, zone: Rect2) -> void:
	var rel := _relations(app)
	var y := zone.position.y + 8
	for m: Array in [["morale", "Moral", Charte.MORAL, "heart"], ["playerTrust", "Confiance", Charte.CONFIANCE, "shield"]]:
		var v: Variant = rel.get(m[0])
		var ligne := Rect2(zone.position.x, y, zone.size.x, 50)
		var icone := C.icon(m[3], 24, m[2])
		parent.add_child(icone)
		D.place(icone, Rect2(ligne.position.x, y + 13, 24, 24))
		D.text(parent, ligne.position.x + 34, y + 33, m[1], 20, Charte.IVOIRE, 700, 130)
		var rail := Rect2(ligne.position.x + 160, y + 20, zone.size.x - 160 - 62, 10)
		D.rect(parent, rail, Charte.PANNEAU_3, 5)
		if v != null:
			D.rect(parent, Rect2(rail.position, Vector2(maxf(10.0, rail.size.x * clampf(float(v) / 100.0, 0, 1)), rail.size.y)), m[2], 5)
		var chiffre := D.text(parent, ligne.end.x, y + 36, _n(v), 28, m[2], 800, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		var jauge := _bouton(parent, ligne, func(): _ecran(app, "groupe"), "PanneauJauge_" + str(m[0]), "%s %s" % [m[1], _n(v)])
		# Survol : mini-courbe des relevés hebdomadaires (groupHistory : moral, confiance).
		preload("res://ui/mini_courbe_survol.gd").lier(app, jauge, "morale" if m[0] == "morale" else "confiance", "Moral du vestiaire" if m[0] == "morale" else "Confiance des joueurs")
		y += 60.0
	# Tensions : pastille (niveau, nombre de joueurs) + portraits cerclés ; clic = petite fenêtre visuelle.
	var t := _tensions(app)
	var concernes := _joueurs_tension(app, t)
	var niveau := int(t.get("level", 0))
	var ty := y + 10
	var p := R.pastille(parent, zone.position.x, ty + 30, "%s · %d" % [NIVEAUX[clampi(niveau, 0, 3)], concernes.size()], _couleur_niveau(niveau) if niveau > 0 else Charte.IVOIRE_3, "warning", "PanneauTensions", 20)
	var x := zone.position.x + p.size.x / C.density + 14
	for j: Dictionary in concernes.slice(0, 4):
		if x + 48 > zone.end.x: break
		_portrait(parent, j, Rect2(x, ty, 48, 48), _couleur_niveau(niveau))
		x += 56.0
	_bouton(parent, Rect2(zone.position.x - 4, ty - 6, zone.size.x + 8, 60), func(): fenetre_tensions(page, app), "PanneauTensionsOuvrir", "Tensions")
	# Relais pressenti : étoile + portrait (clic = fiche).
	var relais := P.player(app.model, str(rel.get("leaderId", "")))
	var ry := ty + 76
	if not relais.is_empty() and ry + 48 <= zone.end.y + 14:
		var etoile := C.icon("star", 24, Charte.IVOIRE)
		parent.add_child(etoile)
		D.place(etoile, Rect2(zone.position.x + 4, ry + 12, 24, 24))
		_portrait(parent, relais, Rect2(zone.position.x + 40, ry, 48, 48), Color.TRANSPARENT)
		D.text(parent, zone.position.x + 100, ry + 32, str(relais.get("name", "")), 20, Charte.IVOIRE, 700, zone.size.x - 110)
		var rid := str(relais.get("id", ""))
		_bouton(parent, Rect2(zone.position.x, ry - 4, zone.size.x, 56), func(): _fiche(page, app, rid), "PanneauRelais", "Relais")

## Petite fenêtre visuelle des tensions (aussi ouverte depuis le Vestiaire) : niveau, portraits des joueurs concernés avec
## leurs raisons en icônes (cœur = mécontent, alerte = parole non tenue, groupe = rivalité) et leur satisfaction, duos à
## risque reliés en rouge. Clic sur un joueur = sa fiche ; sur un duo = le Vestiaire (entretiens et duos).
static func fenetre_tensions(page: Control, app: Control) -> void:
	var t := _tensions(app)
	var joueurs := _joueurs_tension(app, t)
	var niveau := int(t.get("level", 0))
	var fond := FenetreVisuelle.ouvrir(page, "FenetreTensions", "TENSIONS", "warning", 1040, 600)
	R.pastille(fond, 40, 96, NIVEAUX[clampi(niveau, 0, 3)], _couleur_niveau(niveau) if niveau > 0 else R.VERT, "warning" if niveau > 0 else "check", "FenetreTensionsNiveau", 24)
	var x := 40.0
	var y := 130.0
	for j: Dictionary in joueurs.slice(0, 6):
		_portrait(fond, j, Rect2(x, y, 110, 110), _couleur_niveau(niveau), 4)
		var rx := x
		for raison: Variant in j.get("_raisons", []):
			var pastille := D.rect(fond, Rect2(rx, y + 118, 30, 30), R.ROUGE if raison != "rivalite" else R.ORANGE, 99)
			pastille.name = "FenetreTensionsRaison_%s_%s" % [str(j.get("id", "")).replace(":", "_"), str(raison)]
			var im := C.icon(RAISONS.get(raison, "warning"), 18, Charte.NUIT)
			pastille.add_child(im)
			D.place(im, Rect2(6, 6, 18, 18))
			rx += 36.0
		R.pastille(fond, x + 4, y + 182, _n(j.get("_satisfaction")), Charte.MORAL, "heart", "", 18)
		D.text(fond, x + 55, y + 222, _nom_court(str(j.get("name", ""))), 18, Charte.IVOIRE, 700, 150, HORIZONTAL_ALIGNMENT_CENTER)
		var id := str(j.get("id", ""))
		_bouton(fond, Rect2(x - 6, y - 6, 122, 236), func():
			FenetreVisuelle.fermer(page, "FenetreTensions")
			_fiche(page, app, id), "FenetreTensionsJoueur_" + id.replace(":", "_"), str(j.get("name", "")))
		x += 160.0
	y = 400.0
	x = 40.0
	for duo: Variant in t.get("duos", []).slice(0, 3):
		var a := P.player(app.model, str(duo.get("a", "")))
		var b := P.player(app.model, str(duo.get("b", "")))
		if a.is_empty() or b.is_empty(): continue
		_portrait(fond, a, Rect2(x, y, 80, 80), Color.TRANSPARENT)
		_portrait(fond, b, Rect2(x + 120, y, 80, 80), Color.TRANSPARENT)
		D.line(fond, Vector2(x + 84, y + 40), Vector2(x + 116, y + 40), R.ROUGE, 3)
		R.pastille(fond, x + 50, y + 116, _n(duo.get("score")), R.ROUGE, "people", "", 18)
		_bouton(fond, Rect2(x - 6, y - 6, 212, 130), func():
			FenetreVisuelle.fermer(page, "FenetreTensions")
			_ecran(app, "groupe"), "FenetreTensionsDuo", "Vestiaire")
		x += 320.0

# ---------------------------------------------------------------- données (moteur)

## Les quinze de la feuille, par numéro.
static func _xv(app: Control) -> Dictionary:
	var xv := {}
	for p: Variant in app.model.get("squad", []):
		if not p is Dictionary: continue
		var n: Variant = p.get("shirtNumber")
		if (n is int or n is float) and int(n) >= 1 and int(n) <= 15: xv[int(n)] = p
	return xv

static func _teinte_condition(j: Dictionary) -> Color:
	var c := float(j.get("condition", 100))
	return R.VERT if c >= 85 else R.ORANGE if c >= 60 else R.ROUGE

static func _relations(app: Control) -> Dictionary:
	var rel: Variant = app.model.get("clubLife", {}).get("relationships", {})
	return rel if rel is Dictionary else {}

static func _tensions(app: Control) -> Dictionary:
	var t: Variant = _relations(app).get("tensions")
	return t if t is Dictionary else {}

## Joueurs concernés par les tensions, fiche de l'effectif enrichie (raisons, satisfaction).
static func _joueurs_tension(app: Control, t: Dictionary) -> Array:
	var sortie: Array = []
	for row: Variant in t.get("players", []):
		if not row is Dictionary: continue
		var j := P.player(app.model, str(row.get("id", "")))
		if j.is_empty(): continue
		j = j.duplicate()
		j["_raisons"] = row.get("raisons", [])
		j["_satisfaction"] = row.get("satisfaction")
		sortie.append(j)
	return sortie

static func _programme(app: Control) -> Dictionary:
	var w: Variant = app.model.get("clubLife", {}).get("weekProgram")
	return w if w is Dictionary else {}

static func _jours_programme(app: Control) -> Array:
	var jours: Variant = _programme(app).get("days", [])
	return jours if jours is Array and jours.size() == 7 else []

static func _couleur_jour(j: Dictionary) -> Color:
	match str(j.get("kind", "")):
		"match": return Charte.IVOIRE
		"veille": return Charte.IVOIRE_2
		"recuperation": return Charte.REPOS
		"seance":
			match str(j.get("charge", "normal")):
				"repos": return Charte.REPOS
				"intense": return Charte.INTENSIF
			return Charte.NORMAL
	return Charte.PANNEAU_3

static func _couleur_niveau(niveau: int) -> Color:
	return R.ROUGE if niveau >= 2 else R.ORANGE if niveau == 1 else R.VERT

static func _n(v: Variant) -> String:
	return str(int(round(float(v)))) if v is int or v is float else "—"

static func _nom_court(nom: String) -> String:
	var morceaux := nom.split(" ", false)
	return morceaux[morceaux.size() - 1] if not morceaux.is_empty() else nom

# ---------------------------------------------------------------- actions et pièces

static func _ecran(app: Control, id: String) -> void:
	match id:
		"xv": app._navigate("Composition")
		"semaine": preload("res://ui/immersive08/shell.gd").open_training(app)
		"groupe": app._navigate("Vestiaire")

static func _fiche(page: Control, app: Control, id: String) -> void:
	if id.is_empty(): return
	if page.has_method("_ouvrir"): page._ouvrir(id, "")
	else:
		app.selected_player = id
		app.navigation_controller.open_entity({"kind": "player", "id": id, "section": ""})

static func _portrait(parent: Control, j: Dictionary, rect: Rect2, bord: Color, epaisseur: int = 2) -> void:
	var cadre := D.rect(parent, rect, Charte.PANNEAU_3, 99, bord)
	if bord != Color.TRANSPARENT: (cadre.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(epaisseur)))
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var portrait: Control = G.portrait_lazy(int(j.get("portraitIndex", 0)), C.px(rect.size.x), j)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(portrait)
	D.place(portrait, Rect2(0, 0, rect.size.x, rect.size.y * 1.15))

static func _styles(bouton: Button, rayon: int, survol: float) -> void:
	for nom: String in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(Charte.IVOIRE, {"normal": 0.0, "hover": survol, "pressed": survol + .06, "focus": 0.0}[nom])
		s.set_corner_radius_all(maxi(3, C.px(rayon)))
		if nom == "focus":
			s.border_color = Charte.IVOIRE
			s.set_border_width_all(1)
		bouton.add_theme_stylebox_override(nom, s)

## Bouton plat qui couvre une zone : voile clair au survol, main, focus visible.
static func _bouton(parent: Control, zone: Rect2, action: Callable, id: String, aide: String) -> Button:
	var bouton := Button.new()
	bouton.name = id
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.tooltip_text = aide
	bouton.accessibility_name = aide
	_styles(bouton, 10, .10)
	parent.add_child(bouton)
	D.place(bouton, zone)
	bouton.pressed.connect(action)
	return bouton
