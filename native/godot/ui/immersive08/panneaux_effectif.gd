extends RefCounted
## PLANCHE (pas d'intégration) : panneaux contextuels repliables de l'Effectif, idée de Léo du 21/11/2026.
## Trois panneaux visuels, sans phrase : XV (mini-terrain, numéros 1 à 15 teintés par la condition), SEMAINE (jours,
## intensité en couleurs de la charte) et GROUPE (moral, confiance, tensions). Tout est cliquable : écran pertinent
## (Composition, Entraînement, Vestiaire), fiche du joueur, ou petite fenêtre visuelle (tensions).
## Variantes (CD_VARIANTE_VISUELLE) :
##   PANNEAUX_A : colonne à GAUCHE du tableau, trois panneaux empilés repliables séparément (en-tête = poignée).
##   PANNEAUX_B : rail d'onglets-icônes à GAUCHE ; un seul panneau à la fois, en tiroir posé sur le tableau.
## Charte « pas de fiche à droite qui suit la sélection » : rien à droite, rien ne suit la ligne choisie.
## CD_PANNEAUX_REPLIES=1 : état replié (captures).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Charte = preload("res://ui/charte.gd")
const FenetreVisuelle = preload("res://ui/immersive08/fenetre_visuelle.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")

const LARGEUR_A := 470.0
const RAIL_B := 84.0
const TIROIR_B := 600.0
const ENTETE := 62.0
const PANNEAUX := ["xv", "semaine", "groupe"]
const TITRES := {"xv": "XV", "semaine": "SEMAINE", "groupe": "GROUPE"}
const ICONES := {"xv": "tactic", "semaine": "train", "groupe": "people"}
const JOURS := ["L", "M", "M", "J", "V", "S", "D"]
## Places du XV sur le mini-terrain (fractions largeur, hauteur ; on attaque vers le haut).
const PLACES := {1: Vector2(.32, .13), 2: Vector2(.5, .13), 3: Vector2(.68, .13), 4: Vector2(.41, .26), 5: Vector2(.59, .26),
	6: Vector2(.24, .37), 8: Vector2(.5, .39), 7: Vector2(.76, .37), 9: Vector2(.42, .52), 10: Vector2(.6, .6),
	11: Vector2(.09, .74), 12: Vector2(.36, .72), 13: Vector2(.64, .72), 14: Vector2(.91, .74), 15: Vector2(.5, .88)}

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE")
	return v if v in ["PANNEAUX_A", "PANNEAUX_B"] else ""

static func etat(app: Control) -> Dictionary:
	if not app.management_ui.get("panneaux_effectif") is Dictionary:
		var replie := OS.get_environment("CD_PANNEAUX_REPLIES") == "1"
		app.management_ui["panneaux_effectif"] = {"xv": not replie, "semaine": not replie, "groupe": not replie, "tiroir": "" if replie else "xv"}
	return app.management_ui.panneaux_effectif

## Largeur réservée à gauche du tableau (unités du gabarit 2248).
static func reserve(app: Control) -> float:
	match variante():
		"PANNEAUX_A": return LARGEUR_A + 24.0
		"PANNEAUX_B": return RAIL_B + 18.0
	return 0.0

static func construire(page: Control, app: Control, y: float, bas: float) -> void:
	match variante():
		"PANNEAUX_A": _colonne(page, app, y, bas)
		"PANNEAUX_B": _rail(page, app, y, bas)

# ---------------------------------------------------------------- A : colonne empilée

static func _colonne(page: Control, app: Control, y: float, bas: float) -> void:
	var e := etat(app)
	var hauteurs := {"xv": 372.0, "semaine": 204.0, "groupe": 300.0}
	var ouverts := PANNEAUX.filter(func(id: String): return bool(e.get(id, true)))
	var libre := (bas - y) - PANNEAUX.size() * ENTETE - (PANNEAUX.size() - 1) * 14.0
	var voulu := 0.0
	for id: String in ouverts: voulu += hauteurs[id]
	var echelle := minf(1.0, libre / maxf(1.0, voulu))
	var cy := y
	for id: String in PANNEAUX:
		var ouvert := bool(e.get(id, true))
		var h := ENTETE + (float(hauteurs[id]) * echelle if ouvert else 0.0)
		var panneau := D.panel(page, Rect2(0, cy, LARGEUR_A, h), "", "", "", "PanneauEffectif_" + id)
		panneau.clip_contents = true
		_entete(panneau, app, id, LARGEUR_A, ouvert, func():
			e[id] = not bool(e.get(id, true))
			app._render(false))
		if ouvert: _contenu(panneau, page, app, id, Rect2(18, ENTETE, LARGEUR_A - 36, h - ENTETE - 14))
		cy += h + 14.0

## En-tête = poignée : icône, titre Anton, résumé visuel quand replié, flèche vers l'écran, chevron.
static func _entete(panneau: Control, app: Control, id: String, l: float, ouvert: bool, basculer: Callable) -> void:
	var poignee := Button.new()
	poignee.name = "PanneauPoignee_" + id
	poignee.focus_mode = Control.FOCUS_ALL
	poignee.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	poignee.accessibility_name = ("Replier " if ouvert else "Déplier ") + str(TITRES[id])
	for nom: String in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(Charte.IVOIRE, {"normal": 0.0, "hover": .06, "pressed": .1, "focus": 0.0}[nom])
		s.set_corner_radius_all(maxi(3, C.px(24)))
		if nom == "focus": s.border_color = Charte.IVOIRE; s.set_border_width_all(1)
		poignee.add_theme_stylebox_override(nom, s)
	panneau.add_child(poignee)
	D.place(poignee, Rect2(0, 0, l, ENTETE))
	poignee.pressed.connect(basculer)
	var icone := C.icon(ICONES[id], 26, Charte.IVOIRE_2)
	poignee.add_child(icone)
	D.place(icone, Rect2(20, (ENTETE - 26) / 2.0, 26, 26))
	var titre := D.text(poignee, 58, ENTETE / 2.0 + 12, TITRES[id], 30, Charte.IVOIRE, 700, 160)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not ouvert: _resume(poignee, app, id, Vector2(58 + R.largeur(TITRES[id], 30) + 22, ENTETE / 2.0))
	var chevron := D.text(poignee, l - 30, ENTETE / 2.0 + 9, "▾" if ouvert else "▸", 26, Charte.IVOIRE_2, 700, 24, HORIZONTAL_ALIGNMENT_CENTER)
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var aller := _bouton(panneau, Rect2(l - 108, 11, 58, ENTETE - 22), func(): _ecran(app, id), "PanneauEcran_" + id, {"xv": "Composition", "semaine": "Entraînement", "groupe": "Vestiaire"}[id])
	var fleche := C.icon("arrow", 22, Charte.IVOIRE)
	aller.add_child(fleche)
	D.place(fleche, Rect2(18, (ENTETE - 22 - 22) / 2.0, 22, 22))

## Résumé visuel d'un panneau replié (ligne d'en-tête) : pas de phrase.
static func _resume(parent: Control, app: Control, id: String, at: Vector2) -> void:
	match id:
		"xv":
			var xv := _xv(app)
			var x := at.x
			for n in range(1, 16):
				var j: Dictionary = xv.get(n, {})
				var couleur := _teinte_condition(j) if not j.is_empty() else Charte.FILET
				D.rect(parent, Rect2(x, at.y - 6, 12, 12), couleur, 99)
				x += 14.5
		"semaine":
			var jours := _semaine(app)
			for i in 7:
				D.rect(parent, Rect2(at.x + i * 30.0, at.y - 11, 24, 22), _couleur_jour(jours[i]), 6)
		"groupe":
			var rel := _relations(app)
			var x := at.x
			for m: Array in [[rel.get("morale"), Charte.MORAL, "heart"], [rel.get("trust"), Charte.CONFIANCE, "shield"]]:
				var p := R.pastille(parent, x, at.y + 8, _n(m[0]), m[1], m[2], "", 19)
				x += p.size.x / C.density + 8.0
			var t := _tensions(app)
			if t.size() > 0: R.pastille(parent, x, at.y + 8, str(t.size()), R.ROUGE, "warning", "", 19)

static func _contenu(panneau: Control, page: Control, app: Control, id: String, zone: Rect2) -> void:
	match id:
		"xv": _terrain(panneau, page, app, zone)
		"semaine": _jours(panneau, app, zone)
		"groupe": _groupe(panneau, page, app, zone)

# ---------------------------------------------------------------- B : rail + tiroir unique

static func _rail(page: Control, app: Control, y: float, bas: float) -> void:
	var e := etat(app)
	var actif := str(e.get("tiroir", ""))
	var rail := D.panel(page, Rect2(0, y, RAIL_B, bas - y), "", "", "", "PanneauxRail")
	for i in PANNEAUX.size():
		var id: String = PANNEAUX[i]
		var choisi := id == actif
		var zone := Rect2(10, 12 + i * 112.0, RAIL_B - 20, 100)
		var fond := D.rect(rail, zone, Charte.SELECTION if choisi else Charte.PANNEAU_3, 12)
		if choisi: D.rect(rail, Rect2(0, zone.position.y + 18, 5, zone.size.y - 36), Charte.IVOIRE, 2)
		var icone := C.icon(ICONES[id], 30, Charte.IVOIRE if choisi else Charte.IVOIRE_2)
		fond.add_child(icone)
		D.place(icone, Rect2((zone.size.x - 30) / 2.0, 16, 30, 30))
		# Repère de couleur sous l'icône : l'état du panneau en un coup d'œil (forme + couleur).
		_marque_rail(fond, app, id, zone.size.x)
		var bouton := _bouton(rail, zone, func():
			e.tiroir = "" if str(e.get("tiroir", "")) == id else id
			app._render(false), "PanneauOnglet_" + id, TITRES[id])
		bouton.toggle_mode = false
	if actif.is_empty(): return
	var x := RAIL_B + 12.0
	var tiroir := D.panel(page, Rect2(x, y, TIROIR_B, bas - y), "", "", "", "PanneauTiroir_" + actif)
	tiroir.clip_contents = true
	tiroir.mouse_filter = Control.MOUSE_FILTER_STOP
	var fermer := func():
		e.tiroir = ""
		if is_instance_valid(app): app._render(false)
	# Échap ferme le tiroir avant le menu (mécanisme commun des petites fenêtres).
	PetiteFenetre.enregistrer(tiroir, fermer)
	_entete(tiroir, app, actif, TIROIR_B, true, fermer)
	var hauteurs := {"xv": 470.0, "semaine": 250.0, "groupe": 380.0}
	_contenu(tiroir, page, app, actif, Rect2(22, ENTETE + 6, TIROIR_B - 44, minf(float(hauteurs[actif]), bas - y - ENTETE - 24)))
	if actif == "xv":
		_vignettes_xv(tiroir, page, app, Rect2(22, ENTETE + 500, TIROIR_B - 44, bas - y - ENTETE - 520))

static func _marque_rail(fond: Control, app: Control, id: String, l: float) -> void:
	match id:
		"xv":
			var xv := _xv(app)
			var bas := xv.values().filter(func(j: Dictionary): return float(j.get("condition", 100)) < 85).size()
			D.rect(fond, Rect2((l - 40) / 2.0, 62, 40, 22), (R.ORANGE if bas > 0 else R.VERT).lerp(Charte.PANNEAU_3, .55), 11)
			D.text(fond, l / 2.0, 79, str(xv.size()), 17, Charte.IVOIRE, 700, 40, HORIZONTAL_ALIGNMENT_CENTER)
		"semaine":
			var jours := _semaine(app)
			for i in 7: D.rect(fond, Rect2((l - 7 * 8.0) / 2.0 + i * 8.0, 66, 6, 14), _couleur_jour(jours[i]), 2)
		"groupe":
			var rel := _relations(app)
			var t := _tensions(app).size()
			D.rect(fond, Rect2(l / 2.0 - 22, 66, 12, 12), Charte.MORAL, 99)
			D.rect(fond, Rect2(l / 2.0 - 6, 66, 12, 12), Charte.CONFIANCE, 99)
			D.rect(fond, Rect2(l / 2.0 + 10, 66, 12, 12), R.ROUGE if t > 0 else Charte.FILET, 99)
	
# ---------------------------------------------------------------- contenus

## Mini-terrain : les quinze numéros de la feuille, pastille teintée par la condition, clic = fiche du joueur.
static func _terrain(parent: Control, page: Control, app: Control, zone: Rect2) -> void:
	var cote := minf(zone.size.x, zone.size.y / 0.86)
	var terrain := Rect2(zone.position.x + (zone.size.x - cote) / 2.0, zone.position.y + 6, cote, minf(zone.size.y - 6, cote * 0.86))
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
		var couleur := _teinte_condition(j)
		var rond := D.rect(parent, rect, couleur, 99)
		rond.name = "PanneauRond_%d" % n
		D.text(rond, d / 2.0, d / 2.0 + 7, str(n), 20, Charte.NUIT, 800, d, HORIZONTAL_ALIGNMENT_CENTER)
		var id := str(j.get("id", ""))
		_bouton(parent, rect.grow(4), func(): _fiche(page, app, id), "PanneauJoueur_%d" % n, "%s · %d %%" % [str(j.get("name", "")), int(j.get("condition", 0))])
	# Légende par forme et couleur (jamais la couleur seule : le numéro est écrit, la condition est dans l'infobulle).
	var ly := terrain.end.y + 26
	var lx := terrain.position.x
	for k: Array in [[R.VERT, "85+"], [R.ORANGE, "60+"], [R.ROUGE, "−60"]]:
		if ly > zone.end.y + 10: break
		D.rect(parent, Rect2(lx, ly - 12, 14, 14), k[0], 99)
		D.text(parent, lx + 20, ly, k[1], 17, Charte.IVOIRE_2, 700, 60)
		lx += 90.0

## Tiroir B : portraits du XV sous le terrain (place disponible en tiroir).
static func _vignettes_xv(parent: Control, page: Control, app: Control, zone: Rect2) -> void:
	if zone.size.y < 90: return
	var xv := _xv(app)
	var cote := 62.0
	var par_ligne := int(floor((zone.size.x + 8) / (cote + 8)))
	var i := 0
	for n in range(1, 16):
		var j: Dictionary = xv.get(n, {})
		if j.is_empty(): continue
		var x := zone.position.x + (i % par_ligne) * (cote + 10)
		var y := zone.position.y + int(i / par_ligne) * (cote + 34)
		if y + cote > zone.end.y: break
		var cadre := D.rect(parent, Rect2(x, y, cote, cote), Charte.PANNEAU_3, 99)
		cadre.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		var portrait: Control = G.portrait_lazy(int(j.get("portraitIndex", 0)), C.px(cote), j)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cadre.add_child(portrait)
		D.place(portrait, Rect2(0, 0, cote, cote * 1.15))
		D.rect(parent, Rect2(x + cote - 22, y + cote - 22, 24, 24), _teinte_condition(j), 99)
		D.text(parent, x + cote - 10, y + cote - 4, str(n), 14, Charte.NUIT, 800, 24, HORIZONTAL_ALIGNMENT_CENTER)
		var id := str(j.get("id", ""))
		_bouton(parent, Rect2(x - 2, y - 2, cote + 4, cote + 4), func(): _fiche(page, app, id), "PanneauVignette_%d" % n, str(j.get("name", "")))
		i += 1

## Semaine : sept jours, couleur = intensité (charte), ballon = match, repère = aujourd'hui ; puis les trois charges.
static func _jours(parent: Control, app: Control, zone: Rect2) -> void:
	var jours := _semaine(app)
	var aujourdhui := _jour_semaine(_date_du_jour(app))
	var gap := 8.0
	var l := (zone.size.x - gap * 6) / 7.0
	var h := minf(96.0, zone.size.y - 88)
	for i in 7:
		var r := Rect2(zone.position.x + i * (l + gap), zone.position.y + 30, l, h)
		D.text(parent, r.position.x + l / 2.0, zone.position.y + 22, JOURS[i], 18, Charte.IVOIRE if i == aujourdhui else Charte.IVOIRE_2, 700, l, HORIZONTAL_ALIGNMENT_CENTER)
		var j: String = jours[i]
		var case_ := D.rect(parent, r, _couleur_jour(j), 10)
		case_.name = "PanneauJour_%d" % i
		var icone: String = {"match": "ball", "repos": "clock", "normal": "train", "intense": "train"}.get(j, "")
		if not icone.is_empty():
			var im := C.icon(icone, 26, Charte.NUIT if j != "libre" else Charte.IVOIRE_2)
			case_.add_child(im)
			D.place(im, Rect2((l - 26) / 2.0, (h - 26) / 2.0, 26, 26))
		if i == aujourdhui:
			D.rect(parent, Rect2(r.position.x + l / 2.0 - 12, r.end.y + 6, 24, 5), Charte.IVOIRE, 2)
		_bouton(parent, r, func(): _ecran(app, "semaine"), "PanneauJourOuvrir_%d" % i, JOURS[i])
	var mode := _mode(app)
	var x := zone.position.x
	var base := zone.position.y + 30 + h + 50
	for k: Array in [["repos", "Repos", Charte.REPOS, "clock"], ["normal", "Normal", Charte.NORMAL, "train"], ["intense", "Intensif", Charte.INTENSIF, "train"]]:
		var choisi: bool = k[0] == mode
		var p := R.pastille(parent, x, base, k[1], k[2] if choisi else Charte.IVOIRE_3, k[3], "PanneauCharge_" + str(k[0]), 19)
		if choisi: (p.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(k[2], .32)
		R.cliquable(p, func(): _ecran(app, "semaine"), "PanneauChargeOuvrir_" + str(k[0]), str(k[1]))
		x += p.size.x / C.density + 10.0

## Groupe : jauges moral et confiance, tensions en pastille + portraits, relais pressenti.
static func _groupe(parent: Control, page: Control, app: Control, zone: Rect2) -> void:
	var rel := _relations(app)
	var y := zone.position.y + 8
	for m: Array in [["morale", "Moral", Charte.MORAL, "heart"], ["trust", "Confiance", Charte.CONFIANCE, "shield"]]:
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
		_bouton(parent, ligne, func(): _ecran(app, "groupe"), "PanneauJauge_" + str(m[0]), "%s %s" % [m[1], _n(v)])
		y += 60.0
	# Tensions : pastille rouge + portraits cerclés de rouge ; clic = petite fenêtre visuelle.
	var tensions := _tensions(app)
	var ty := y + 10
	var p := R.pastille(parent, zone.position.x, ty + 30, "%d" % tensions.size(), R.ROUGE if tensions.size() > 0 else Charte.IVOIRE_3, "warning", "PanneauTensions", 22)
	var x := zone.position.x + p.size.x / C.density + 14
	for j: Dictionary in tensions.slice(0, 5):
		var cadre := D.rect(parent, Rect2(x, ty, 48, 48), Charte.PANNEAU_3, 99, R.ROUGE)
		cadre.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		var portrait: Control = G.portrait_lazy(int(j.get("portraitIndex", 0)), C.px(48), j)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cadre.add_child(portrait)
		D.place(portrait, Rect2(0, 0, 48, 55))
		x += 56.0
	_bouton(parent, Rect2(zone.position.x - 4, ty - 6, zone.size.x + 8, 60), func(): _fenetre_tensions(page, app), "PanneauTensionsOuvrir", "Tensions")
	# Relais pressenti : étoile + portrait (clic = fiche).
	var relais := P.player(app.model, str(rel.get("leaderId", "")))
	var ry := ty + 76
	if not relais.is_empty() and ry + 48 <= zone.end.y + 14:
		var etoile := C.icon("star", 24, Charte.IVOIRE)
		parent.add_child(etoile)
		D.place(etoile, Rect2(zone.position.x + 4, ry + 12, 24, 24))
		var cadre := D.rect(parent, Rect2(zone.position.x + 40, ry, 48, 48), Charte.PANNEAU_3, 99)
		cadre.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		var portrait: Control = G.portrait_lazy(int(relais.get("portraitIndex", 0)), C.px(48), relais)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cadre.add_child(portrait)
		D.place(portrait, Rect2(0, 0, 48, 55))
		D.text(parent, zone.position.x + 100, ry + 32, str(relais.get("name", "")), 20, Charte.IVOIRE, 700, zone.size.x - 110)
		var rid := str(relais.get("id", ""))
		_bouton(parent, Rect2(zone.position.x, ry - 4, zone.size.x, 56), func(): _fiche(page, app, rid), "PanneauRelais", "Relais")

## Petite fenêtre visuelle des tensions : portraits, anneau de satisfaction, duos au lien faible.
static func _fenetre_tensions(page: Control, app: Control) -> void:
	var tensions := _tensions(app)
	var duos := _duos_faibles(app)
	var fond := FenetreVisuelle.ouvrir(page, "FenetreTensions", "TENSIONS", "warning", 980, 560)
	var x := 40.0
	var y := 100.0
	if tensions.is_empty() and duos.is_empty():
		R.pastille(fond, 40, 150, "0", R.VERT, "check", "FenetreTensionsAucune", 24)
	for j: Dictionary in tensions.slice(0, 6):
		var cadre := D.rect(fond, Rect2(x, y, 110, 110), Charte.PANNEAU_3, 99, R.ROUGE)
		(cadre.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(4)))
		cadre.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		var portrait: Control = G.portrait_lazy(int(j.get("portraitIndex", 0)), C.px(110), j)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cadre.add_child(portrait)
		D.place(portrait, Rect2(0, 0, 110, 126))
		R.pastille(fond, x + 4, y + 146, _n(j.get("_satisfaction")), R.ROUGE, "heart", "", 18)
		D.text(fond, x + 55, y + 186, _nom_court(str(j.get("name", ""))), 18, Charte.IVOIRE, 700, 150, HORIZONTAL_ALIGNMENT_CENTER)
		var id := str(j.get("id", ""))
		_bouton(fond, Rect2(x - 6, y - 6, 122, 200), func():
			FenetreVisuelle.fermer(page, "FenetreTensions")
			_fiche(page, app, id), "FenetreTensionsJoueur_" + id, str(j.get("name", "")))
		x += 150.0
	y = 330.0
	x = 40.0
	for duo: Array in duos.slice(0, 3):
		for k in 2:
			var j: Dictionary = duo[k]
			var cadre := D.rect(fond, Rect2(x + k * 120, y, 80, 80), Charte.PANNEAU_3, 99)
			cadre.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
			var portrait: Control = G.portrait_lazy(int(j.get("portraitIndex", 0)), C.px(80), j)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cadre.add_child(portrait)
			D.place(portrait, Rect2(0, 0, 80, 92))
		D.line(fond, Vector2(x + 84, y + 40), Vector2(x + 116, y + 40), R.ROUGE, 3)
		R.pastille(fond, x + 50, y + 116, _n(duo[2]), R.ROUGE, "people", "", 18)
		_bouton(fond, Rect2(x - 6, y - 6, 212, 130), func():
			FenetreVisuelle.fermer(page, "FenetreTensions")
			_ecran(app, "groupe"), "FenetreTensionsDuo", "Vestiaire")
		x += 300.0

# ---------------------------------------------------------------- données

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

## Joueurs suivis dont la satisfaction est basse (moins de 45), du plus bas au plus haut, fiche de l'effectif enrichie.
static func _tensions(app: Control) -> Array:
	var sortie: Array = []
	for p: Variant in _relations(app).get("players", []):
		if not p is Dictionary or p.get("score") == null or float(p.score) >= 45: continue
		var j := P.player(app.model, str(p.get("id", "")))
		if j.is_empty(): continue
		j = j.duplicate()
		j["_satisfaction"] = float(p.score)
		sortie.append(j)
	sortie.sort_custom(func(a: Dictionary, b: Dictionary): return float(a._satisfaction) < float(b._satisfaction))
	return sortie

static func _duos_faibles(app: Control) -> Array:
	var sortie: Array = []
	for d: Variant in _relations(app).get("pairs", []):
		if not d is Dictionary or float(d.get("score", 100)) >= 40: continue
		var a := P.player(app.model, str(d.get("a", "")))
		var b := P.player(app.model, str(d.get("b", "")))
		if not a.is_empty() and not b.is_empty(): sortie.append([a, b, d.score])
	return sortie

static func _mode(app: Control) -> String:
	var m := str(app.model.get("meta", {}).get("training", "normal"))
	return m if m in ["repos", "normal", "intense"] else "normal"

static func _date_du_jour(app: Control) -> String:
	var meta: Dictionary = app.model.get("meta", {})
	return str(meta.get("calendarToday", meta.get("date", "")))

## 0 = lundi … 6 = dimanche, -1 si inconnu.
static func _jour_semaine(date: String) -> int:
	if date.length() < 10: return -1
	var d := Time.get_datetime_dict_from_datetime_string(date.substr(0, 10) + "T12:00:00", true)
	return (int(d.weekday) + 6) % 7

## Programme lu dans le moteur : jour du match (calendrier) et charge de la séance collective. Le moteur ne publie pas
## de programme jour par jour : la séance est posée à J-3 du match, le lendemain du match en repos (planche seulement).
static func _semaine(app: Control) -> Array:
	var jours: Array = ["libre", "libre", "libre", "libre", "libre", "libre", "libre"]
	var match_ := P.next_fixture(app.model)
	var jm := _jour_semaine(str(match_.get("date", match_.get("kickoff", ""))))
	if jm < 0: jm = 5
	jours[jm] = "match"
	jours[(jm + 7 - 3) % 7] = _mode(app)
	jours[(jm + 7 - 1) % 7] = "repos"
	return jours

static func _couleur_jour(j: String) -> Color:
	match j:
		"match": return Charte.IVOIRE
		"repos": return Charte.REPOS
		"normal": return Charte.NORMAL
		"intense": return Charte.INTENSIF
	return Charte.PANNEAU_3

static func _n(v: Variant) -> String:
	return str(int(round(float(v)))) if v is int or v is float else "—"

static func _nom_court(nom: String) -> String:
	var morceaux := nom.split(" ", false)
	return morceaux[morceaux.size() - 1] if not morceaux.is_empty() else nom

# ---------------------------------------------------------------- actions

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

## Bouton plat qui couvre une zone : voile clair au survol, main, focus visible.
static func _bouton(parent: Control, zone: Rect2, action: Callable, id: String, aide: String) -> Button:
	var bouton := Button.new()
	bouton.name = id
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.tooltip_text = aide
	bouton.accessibility_name = aide
	for nom: String in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(Charte.IVOIRE, {"normal": 0.0, "hover": .10, "pressed": .16, "focus": 0.0}[nom])
		s.set_corner_radius_all(maxi(3, C.px(10)))
		if nom == "focus": s.border_color = Charte.IVOIRE; s.set_border_width_all(1)
		bouton.add_theme_stylebox_override(nom, s)
	parent.add_child(bouton)
	D.place(bouton, zone)
	bouton.pressed.connect(action)
	return bouton
