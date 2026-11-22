extends RefCounted
## Effectif › Planificateur (revue FM27, idée 11, PLANCHE A/B du 22/11/2026, non tranchée).
## Terrain du XV : à chaque poste, l'ordre de nos joueurs (titulaire, doublure, 3e) et leurs étoiles au poste,
## pour la saison actuelle, la prochaine ou la suivante. Projection faite avec les seules données du moteur :
## fin de contrat (contractEnd : le joueur disparaît de la saison d'après, signalé), âge (+1 par saison) et espoirs
## du centre de formation (19 ans et plus cette saison-là). Les notes au poste restent celles d'aujourd'hui : le
## moteur ne prévoit pas la progression.
## Étoiles RELATIVES à notre effectif (bareme_etoiles.gd) : le repère d'un poste est notre meilleur joueur à ce poste
## AUJOURD'HUI, gardé pour les saisons suivantes (un départ fait donc baisser les étoiles du poste).
##  A : terrain à gauche (un repère par poste), liste du poste choisi à droite, grammaire de l'Effectif.
##  B : terrain pleine largeur, chaque poste porte directement son ordre (3 ou 4 noms) et les départs barrés.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Charte = preload("res://ui/charte.gd")
const Bareme = preload("res://ui/bareme_etoiles.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")

## Postes du XV regroupés (paires : 2 titulaires) : nom, sigle, numéros, place A (fractions du terrain), place B.
const POSTES := [
	{"nom": "Pilier gauche", "sigle": "PG", "n": [1], "a": Vector2(.2, .09), "b": Vector2(.17, .0)},
	{"nom": "Talonneur", "sigle": "T", "n": [2], "a": Vector2(.5, .09), "b": Vector2(.5, .0)},
	{"nom": "Pilier droit", "sigle": "PD", "n": [3], "a": Vector2(.8, .09), "b": Vector2(.83, .0)},
	{"nom": "Deuxième ligne", "sigle": "2L", "n": [4, 5], "a": Vector2(.5, .25), "b": Vector2(.5, 1.0)},
	{"nom": "3e ligne aile", "sigle": "3L", "n": [6, 7], "a": Vector2(.24, .4), "b": Vector2(.17, 1.0)},
	{"nom": "Numéro 8", "sigle": "N8", "n": [8], "a": Vector2(.76, .4), "b": Vector2(.83, 1.0)},
	{"nom": "Demi de mêlée", "sigle": "DM", "n": [9], "a": Vector2(.3, .56), "b": Vector2(.33, 2.0)},
	{"nom": "Demi d’ouverture", "sigle": "DO", "n": [10], "a": Vector2(.7, .56), "b": Vector2(.67, 2.0)},
	{"nom": "Centre", "sigle": "C", "n": [12, 13], "a": Vector2(.38, .72), "b": Vector2(.5, 3.0)},
	{"nom": "Ailier", "sigle": "AL", "n": [11, 14], "a": Vector2(.8, .72), "b": Vector2(.17, 3.0)},
	{"nom": "Arrière", "sigle": "AR", "n": [15], "a": Vector2(.5, .88), "b": Vector2(.83, 3.0)},
]
const SAISONS := ["ACTUELLE", "PROCHAINE", "SUIVANTE"]
const AGE_ESPOIR := 19
const AGE_JEUNE := 21
const AGE_VETERAN := 33
const CLE_SAISON := "plan_saison"
const CLE_POSTE := "plan_poste"

static func variante() -> String:
	return "B" if OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper() == "B" else "A"

# ---------------------------------------------------------------- données (moteur seulement)

static func _nombre(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v))

static func _numeros(p: Dictionary, cle: String) -> Array:
	var sortie: Array = []
	var source: Variant = p.get(cle, [])
	if cle == "primaryPositions" and not (source is Array and not (source as Array).is_empty()): source = [p.get("primaryPosition")]
	if source is Array:
		for v: Variant in source:
			if _nombre(v): sortie.append(int(v))
	return sortie

## Note au poste (meilleure des numéros du groupe) ; -1 si inconnue.
static func note_groupe(p: Dictionary, numeros: Array) -> float:
	var notes: Variant = p.get("positionRatings")
	if not notes is Dictionary: return -1.0
	var meilleure := -1.0
	for n: int in numeros:
		var v: Variant = (notes as Dictionary).get(str(n))
		if Bareme.etoiles_sur_100(v) >= 0.0: meilleure = maxf(meilleure, float(v))
	return meilleure

static func _au_poste(p: Dictionary, numeros: Array) -> String:
	for n: int in _numeros(p, "primaryPositions"):
		if n in numeros: return "naturel"
	for n: int in _numeros(p, "secondaryPositions"):
		if n in numeros: return "depanne"
	return ""

## Projection de la saison `decalage` (0 actuelle, 1 prochaine, 2 suivante) :
## {saison, presents: [{p, age, espoir, derniere}], partis: [{p, fin}], references: {indice: note}}.
static func projection(app: Control, decalage: int) -> Dictionary:
	var saison := int(app.model.get("meta", {}).get("season", 1))
	var cible := saison + decalage
	var effectif: Array = app.model.get("squad", [])
	var presents: Array = []
	var partis: Array = []
	for v: Variant in effectif:
		if not v is Dictionary: continue
		var p: Dictionary = v
		var fin: Variant = p.get("contractEnd")
		var vente: Variant = p.get("sale")
		var depart_vente: bool = vente is Dictionary and (vente as Dictionary).get("pending") is Dictionary
		var age := int(p.get("age", 0)) + decalage if _nombre(p.get("age")) else -1
		if decalage > 0 and ((_nombre(fin) and int(fin) < cible) or depart_vente):
			partis.append({"p": p, "fin": int(fin) if _nombre(fin) else saison, "vente": depart_vente})
			continue
		presents.append({"p": p, "age": age, "espoir": false, "derniere": _nombre(fin) and int(fin) == cible})
	if decalage > 0:
		for v: Variant in app.model.get("decisions", {}).get("development", {}).get("academy", []):
			if not v is Dictionary or not _nombre(v.get("age")): continue
			if int(v.age) + decalage < AGE_ESPOIR: continue
			presents.append({"p": v, "age": int(v.age) + decalage, "espoir": true, "derniere": false})
	var references := {}
	for i in POSTES.size():
		var notes: Array = []
		for v: Variant in effectif:
			if v is Dictionary and not _au_poste(v, POSTES[i].n).is_empty(): notes.append(note_groupe(v, POSTES[i].n))
		references[i] = Bareme.meilleure_note(notes)
	return {"saison": cible, "presents": presents, "partis": partis, "references": references}

## Ordre du poste `i` : [{e, note, etoiles, depanne}] trié par note, puis départs du poste (dans `partis`).
static func ordre(proj: Dictionary, i: int) -> Dictionary:
	var numeros: Array = POSTES[i].n
	var reference: float = proj.references.get(i, -1.0)
	var liste: Array = []
	for e: Dictionary in proj.presents:
		var place := _au_poste(e.p, numeros)
		if place.is_empty(): continue
		var note := note_groupe(e.p, numeros)
		liste.append({"e": e, "note": note, "etoiles": Bareme.etoiles_relatives(note, reference), "depanne": place == "depanne"})
	liste.sort_custom(func(a: Dictionary, b: Dictionary): return a.note > b.note or (a.note == b.note and not a.depanne and b.depanne))
	# Espoirs : seulement ceux qui entrent dans l'ordre du poste (titulaire, doublure ou 3e).
	var profondeur_max: int = numeros.size() * 3
	var gardes: Array = []
	for k in liste.size():
		if not bool(liste[k].e.espoir) or (gardes.size() < profondeur_max and not liste[k].depanne): gardes.append(liste[k])
	liste = gardes
	var partis: Array = []
	for d: Dictionary in proj.partis:
		if _au_poste(d.p, numeros) == "naturel":
			var note := note_groupe(d.p, numeros)
			partis.append({"d": d, "note": note, "etoiles": Bareme.etoiles_relatives(note, reference)})
	return {"liste": liste, "partis": partis, "titulaires": numeros.size()}

## Joueurs à 4 étoiles et plus au poste.
static func profondeur(o: Dictionary) -> int:
	return o.liste.filter(func(x: Dictionary): return float(x.etoiles) >= 4.0).size()

static func couleur_profondeur(n: int, titulaires: int) -> Color:
	if n < titulaires: return R.ROUGE
	if n == titulaires: return R.ORANGE
	return R.VERT

static func role(rang: int, titulaires: int) -> String:
	if rang < titulaires: return "TIT"
	if rang < titulaires * 2: return "DOUB"
	if rang < titulaires * 3: return "3e"
	return ""

static func couleur_age(age: int) -> Color:
	if age < 0: return Charte.IVOIRE_3
	if age <= AGE_JEUNE: return R.VERT
	if age >= AGE_VETERAN: return R.ORANGE
	return Charte.IVOIRE

# ---------------------------------------------------------------- entrée

static func construire(page: Control, app: Control, y: float, bas: float) -> void:
	var state: Dictionary = app.management_ui.roster
	var decalage := clampi(int(state.get(CLE_SAISON, 0)), 0, 2)
	var proj := projection(app, decalage)
	var ordres: Array = []
	for i in POSTES.size(): ordres.append(ordre(proj, i))
	_entete(page, app, state, decalage, proj, ordres, y)
	if variante() == "B": _option_b(page, app, proj, ordres, Rect2(0, y + 70, page.LARGEUR, bas - y - 74))
	else: _option_a(page, app, state, proj, ordres, Rect2(0, y + 70, page.LARGEUR, bas - y - 74))

static func _changer(app: Control, cle: String, valeur: int) -> void:
	app.management_ui.roster[cle] = valeur
	app._render(false)

static func _bouton(parent: Control, zone: Rect2, action: Callable, id: String, aide: String, rayon := 10) -> Button:
	var bouton := Button.new()
	bouton.name = id
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.tooltip_text = aide
	bouton.accessibility_name = aide
	for etat: String in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(Charte.IVOIRE, {"normal": 0.0, "hover": .08, "pressed": .14, "focus": 0.0}[etat])
		s.set_corner_radius_all(maxi(2, C.px(rayon)))
		if etat == "focus":
			s.border_color = Charte.IVOIRE
			s.set_border_width_all(1)
		bouton.add_theme_stylebox_override(etat, s)
	parent.add_child(bouton)
	D.place(bouton, zone)
	bouton.pressed.connect(action)
	return bouton

static func _fiche(app: Control, id: String, section: String = "") -> void:
	if id.is_empty(): return
	app.selected_player = id
	app.navigation_controller.open_entity({"kind": "player", "id": id, "section": section})

## Nom cliquable (fiche) avec carte joueur au survol.
static func _nom(parent: Control, app: Control, p: Dictionary, x: float, base: float, h: float, largeur_max: float, taille: int, couleur: Color, prefixe: String, espoir := false) -> float:
	var nom := str(p.get("name", ""))
	var etiquette := D.text(parent, x, base, nom, taille, couleur, 600, largeur_max, HORIZONTAL_ALIGNMENT_LEFT, true)
	var police := etiquette.get_theme_font("font")
	var l := minf(largeur_max, police.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, etiquette.get_theme_font_size("font_size")).x / C.density)
	var id := str(p.get("id", ""))
	var lien := _bouton(parent, Rect2(x - 4, base - h * .7, l + 8, h), func():
		if espoir: app._navigate("Formation")
		else: _fiche(app, id), prefixe + id.validate_node_name(), "")
	if not espoir: CarteSurvol.lier(app, lien, id, "squad")
	else: lien.tooltip_text = "Centre de formation"
	return l

# ---------------------------------------------------------------- en-tête commun : saisons et totaux

static func _entete(page: Control, app: Control, state: Dictionary, decalage: int, proj: Dictionary, ordres: Array, y: float) -> void:
	var saison := int(app.model.get("meta", {}).get("season", 1))
	var x := 0.0
	for k in 3:
		var texte := "%s  %s" % [SAISONS[k], G.season_label(saison + k)]
		var l := R.largeur(texte, 20, 800) + 48.0
		var actif := k == decalage
		var fond := D.rect(page, Rect2(x, y, l, 48), Charte.CREME if actif else Charte.PANNEAU_3, Charte.RAYON_PILULE)
		fond.name = "PlanSaisonFond%d" % k
		var t := D.text(fond, l / 2.0, 32, texte, 20, Charte.ENCRE if actif else Charte.IVOIRE_2, 800, l, HORIZONTAL_ALIGNMENT_CENTER)
		t.name = "PlanSaison%d" % k
		_bouton(page, Rect2(x, y, l, 48), _changer.bind(app, CLE_SAISON, k), "PlanSaisonOuvrir%d" % k, "Saison " + G.season_label(saison + k), 999)
		x += l + 10.0
	# Totaux de la saison affichée : départs (rouge), espoirs (vert), postes sans doublure à 4 étoiles (orange).
	var departs: int = proj.partis.size()
	var vus := {}
	for o: Dictionary in ordres:
		for item: Dictionary in o.liste:
			if bool(item.e.espoir): vus[str(item.e.p.get("id", ""))] = true
	var espoirs: int = vus.size()
	var derniers: int = proj.presents.filter(func(e: Dictionary): return bool(e.derniere)).size()
	var faibles := 0
	for o: Dictionary in ordres:
		if profondeur(o) < int(o.titulaires) * 2: faibles += 1
	var tuiles := [
		{"v": departs, "l": "départs", "c": R.ROUGE, "act": func(): app.management_ui.roster.immersive_tab = 2; app._render(false), "id": "Departs", "aide": "Contrats"},
		{"v": derniers, "l": "dernière année", "c": R.ORANGE, "act": func(): app.management_ui.roster.immersive_tab = 2; app._render(false), "id": "Derniers", "aide": "Contrats"},
		{"v": espoirs, "l": "espoirs", "c": R.VERT, "act": func(): app._navigate("Formation"), "id": "Espoirs", "aide": "Formation"},
		{"v": faibles, "l": "postes courts", "c": R.ORANGE if faibles > 0 else R.VERT, "act": func(): app._navigate("Recrutement"), "id": "Courts", "aide": "Recrutement"},
	]
	var droite: float = page.LARGEUR
	for i in range(tuiles.size() - 1, -1, -1):
		var d: Dictionary = tuiles[i]
		var valeur := str(d.v)
		var l := 14.0 + R.largeur(valeur, 34, 800) + 12.0 + R.largeur(str(d.l).to_upper(), 17) + 22.0
		var zone := Rect2(droite - l, y - 2, l, 52)
		var tuile := R.tuile(page, zone, valeur, str(d.l), d.c, "PlanTotal" + str(d.id), 34, int(d.v) > 0)
		R.cliquable(tuile, d.act, "PlanTotalOuvrir" + str(d.id), str(d.aide))
		droite -= l + 10.0

# ---------------------------------------------------------------- option A : terrain + liste du poste choisi

static func _option_a(page: Control, app: Control, state: Dictionary, proj: Dictionary, ordres: Array, zone: Rect2) -> void:
	# Poste par défaut : le premier qui perd un joueur cette saison-là, sinon le centre.
	var defaut := 8
	for k in ordres.size():
		if not (ordres[k].partis as Array).is_empty():
			defaut = k
			break
	var choisi := clampi(int(state.get(CLE_POSTE, defaut)), 0, POSTES.size() - 1)
	var gauche := Rect2(zone.position, Vector2(700, zone.size.y))
	var panneau := D.rect(page, gauche, Charte.PANNEAU, Charte.RAYON_PANNEAU)
	panneau.name = "PlanTerrainPanneau"
	var terrain := Rect2(gauche.position + Vector2(22, 22), Vector2(gauche.size.x - 44, gauche.size.y - 44))
	_pelouse(page, terrain)
	var lb := 180.0
	var hb := 100.0
	for i in POSTES.size():
		var o: Dictionary = ordres[i]
		var c: Vector2 = terrain.position + Vector2(POSTES[i].a.x * terrain.size.x, POSTES[i].a.y * terrain.size.y + 28)
		var r := Rect2(c - Vector2(lb / 2.0, hb / 2.0), Vector2(lb, hb))
		var prof := profondeur(o)
		var cp := couleur_profondeur(prof, int(o.titulaires))
		var fond := D.rect(page, r, Charte.SELECTION if i == choisi else Color(Charte.NOIR_PANNEAU, .86), Charte.RAYON_CARTE, Charte.IVOIRE if i == choisi else cp)
		(fond.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(1, C.px(2.5 if i == choisi else 1.5)))
		fond.name = "PlanPoste_%d" % i
		D.text(fond, 14, 30, POSTES[i].sigle, 24, Charte.IVOIRE, 800, 60).add_theme_font_override("font", Charte.TITRE_FICHE)
		# Pastille de profondeur : nombre de joueurs à ★4+ (forme ronde + chiffre).
		var pastille := D.rect(fond, Rect2(lb - 46, 9, 34, 26), Color(cp, .22), 99)
		D.text(pastille, 17, 20, str(prof), 18, cp, 800, 34, HORIZONTAL_ALIGNMENT_CENTER)
		# Deux rangées : le moins bon des titulaires, puis la meilleure doublure (vide = rouge « — »).
		var t := int(o.titulaires)
		for k in 2:
			var rang := t - 1 if k == 0 else t
			var yy := 42.0 + k * 26.0
			D.text(fond, 14, yy + 17, "TIT" if k == 0 else "DOUB", 14, Charte.IVOIRE_2 if k == 0 else Charte.IVOIRE_3, 700, 46)
			if rang < o.liste.size(): CarteSurvol.poser_etoiles(fond, Rect2(60, yy + 2, 100, 20), float(o.liste[rang].etoiles), "PlanPosteEtoiles_%d_%d" % [i, k])
			else: D.text(fond, 62, yy + 18, "—", 20, R.ROUGE, 800, 40)
		_bouton(page, r, _changer.bind(app, CLE_POSTE, i), "PlanPosteOuvrir_%d" % i, "%s · %d × ★4+" % [POSTES[i].nom, prof], 12)
	_liste_poste(page, app, proj, ordres[choisi], choisi, Rect2(zone.position.x + 724, zone.position.y, zone.size.x - 724, zone.size.y))

static func _pelouse(parent: Control, terrain: Rect2) -> void:
	var pelouse := D.rect(parent, terrain, Color("1e3a2a"), 12)
	pelouse.name = "PlanPelouse"
	pelouse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ligne := Color(Charte.IVOIRE, .2)
	for f: float in [.04, .24, .5, .76, .96]:
		D.line(pelouse, Vector2(12, terrain.size.y * f), Vector2(terrain.size.x - 12, terrain.size.y * f), ligne if f in [.04, .5, .96] else Color(ligne, .45), 2 if f in [.04, .96] else 1)

const COLONNES_A := [
	{"t": "RANG", "x": 0.0, "w": 96.0}, {"t": "JOUEUR", "x": 110.0, "w": 520.0}, {"t": "ÂGE", "x": 650.0, "w": 70.0},
	{"t": "★ AU POSTE", "x": 740.0, "w": 150.0}, {"t": "NOTE", "x": 910.0, "w": 80.0}, {"t": "CONTRAT", "x": 1010.0, "w": 150.0},
	{"t": "STATUT", "x": 1180.0, "w": 330.0},
]

static func _liste_poste(page: Control, app: Control, proj: Dictionary, o: Dictionary, i: int, zone: Rect2) -> void:
	var panneau := D.rect(page, zone, Charte.PANNEAU, Charte.RAYON_PANNEAU)
	panneau.name = "PlanListe"
	var titre := D.text(panneau, 28, 54, "★ " + str(POSTES[i].nom).to_upper(), 34, Charte.IVOIRE, 800, 700)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "PlanListeTitre"
	var prof := profondeur(o)
	var tx := 28.0 + R.largeur("★ " + str(POSTES[i].nom).to_upper(), 34, 800) + 22.0
	R.pastille(panneau, tx, 50, "%d × ★4+" % prof, couleur_profondeur(prof, int(o.titulaires)), "", "PlanListeProfondeur", 19)
	var bouton_recherche := R.pastille(panneau, zone.size.x - 28 - R.largeur("Recruter", 19) - 60, 50, "Recruter", R.BLEU, "search", "PlanRecruter", 19)
	R.cliquable(bouton_recherche, func(): app._navigate("Recrutement"), "PlanRecruterOuvrir", "Recrutement · " + str(POSTES[i].nom))
	var y := 84.0
	var entete := D.rect(panneau, Rect2(16, y, zone.size.x - 32, 40), Charte.BANDEAU_ENTETE, Charte.RAYON_PETIT)
	for col: Dictionary in COLONNES_A:
		D.text(entete, 14 + col.x, 27, col.t, 17, Charte.IVOIRE_3, 700, col.w)
	y += 48.0
	var h := 50.0
	var rang := 0
	for item: Dictionary in o.liste:
		if y + h > zone.size.y - 10: break
		_ligne_a(panneau, app, item, rang, int(o.titulaires), Rect2(16, y, zone.size.x - 32, h))
		if role(rang, int(o.titulaires)) != role(rang + 1, int(o.titulaires)) and rang + 1 < o.liste.size() and rang < int(o.titulaires) * 3:
			D.line(panneau, Vector2(24, y + h + 2), Vector2(zone.size.x - 24, y + h + 2), Color(Charte.IVOIRE, .18), 1)
		y += h + 4
		rang += 1
	if o.liste.is_empty():
		D.text(panneau, 40, y + 34, "—", 26, R.ROUGE, 800, 80)
		y += h
	# Départs du poste avant cette saison : lignes estompées, barrées, pastille rouge.
	for d: Dictionary in o.partis:
		if y + h > zone.size.y - 10: break
		_ligne_partie(panneau, app, d, Rect2(16, y, zone.size.x - 32, h))
		y += h + 4

static func _ligne_a(parent: Control, app: Control, item: Dictionary, rang: int, titulaires: int, r: Rect2) -> void:
	var e: Dictionary = item.e
	var p: Dictionary = e.p
	var ligne := D.rect(parent, r, Charte.PANNEAU_2 if rang % 2 == 0 else Color.TRANSPARENT, Charte.RAYON_PETIT)
	ligne.name = "PlanLigne_%d" % rang
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base := r.size.y / 2.0 + 7.0
	var etiquette := role(rang, titulaires)
	var cr := Charte.IVOIRE if etiquette == "TIT" else Charte.IVOIRE_2 if etiquette == "DOUB" else Charte.IVOIRE_3
	var ovale := D.rect(ligne, Rect2(12, r.size.y / 2.0 - 15, 34, 30), cr if etiquette == "TIT" else Color.TRANSPARENT, 99, cr)
	D.text(ovale, 17, 22, str(rang + 1), 18, Charte.ENCRE if etiquette == "TIT" else cr, 800, 34, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(ligne, 54, base, etiquette, 16, cr, 700, 50)
	var portrait: Control = G.portrait_lazy(int(p.get("portraitIndex", 0)), C.px(34), p)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(portrait)
	D.place(portrait, Rect2(124, (r.size.y - 34) / 2.0, 35, 34))
	var l := _nom(ligne, app, p, 172, base, r.size.y - 8, 300, 21, Charte.IVOIRE, "PlanNom_", bool(e.espoir))
	if item.depanne: R.pastille(ligne, 172 + l + 12, base, "Dépanne", Charte.IVOIRE_2, "", "PlanDepanne", 16)
	D.text(ligne, 664, base, str(e.age) if int(e.age) >= 0 else "—", 21, couleur_age(int(e.age)), 700, 60)
	CarteSurvol.poser_etoiles(ligne, Rect2(754, r.size.y / 2.0 - 12, 124, 24), float(item.etoiles), "PlanEtoiles")
	var note: float = item.note
	D.text(ligne, 924, base, str(roundi(note)) if note >= 0.0 else "—", 22, Charte.couleur_attribut(note) if note >= 0.0 else Charte.IVOIRE_3, 800, 60)
	if not e.espoir:
		var fin: Variant = p.get("contractEnd")
		var annee := G.contract_year(fin)
		var cc := R.ORANGE if e.derniere else Charte.IVOIRE_2
		var pc := R.pastille(ligne, 1024, base, annee, cc, "calendar", "PlanContrat", 18)
		R.cliquable(pc, _fiche.bind(app, str(p.get("id", "")), "contract"), "PlanContratOuvrir", "Contrat · " + str(p.get("name", "")))
	var sx := 1194.0
	if e.espoir:
		var pe := R.pastille(ligne, sx, base, "▲ Espoir", R.VERT, "", "PlanEspoir", 18)
		R.cliquable(pe, func(): app._navigate("Formation"), "PlanEspoirOuvrir", "Formation")
	elif e.derniere:
		var pd := R.pastille(ligne, sx, base, "⧗ Dernière année", R.ORANGE, "", "PlanDerniere", 18)
		R.cliquable(pd, _fiche.bind(app, str(p.get("id", "")), "contract"), "PlanDerniereOuvrir", "Prolonger · " + str(p.get("name", "")))
	elif int(e.age) >= AGE_VETERAN:
		R.pastille(ligne, sx, base, "%d ans" % int(e.age), R.ORANGE, "", "PlanVeteran", 18)

static func _ligne_partie(parent: Control, app: Control, d: Dictionary, r: Rect2) -> void:
	var p: Dictionary = d.d.p
	var ligne := D.rect(parent, r, Color(R.ROUGE, .07), Charte.RAYON_PETIT)
	ligne.name = "PlanParti"
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base := r.size.y / 2.0 + 7.0
	D.text(ligne, 20, base, "✕", 22, R.ROUGE, 800, 30)
	var l := _nom(ligne, app, p, 172, base, r.size.y - 8, 300, 21, Charte.IVOIRE_3, "PlanPartiNom_")
	D.line(ligne, Vector2(168, base - 7), Vector2(176 + l, base - 7), Color(Charte.IVOIRE_3, .9), 2)
	CarteSurvol.poser_etoiles(ligne, Rect2(754, r.size.y / 2.0 - 12, 124, 24), float(d.etoiles), "PlanPartiEtoiles")
	var texte := "Vendu" if d.d.vente else "Fin de contrat " + G.contract_year(d.d.fin)
	var pp := R.pastille(ligne, 1024, base, texte, R.ROUGE, "", "PlanPartiMotif", 18)
	R.cliquable(pp, _fiche.bind(app, str(p.get("id", "")), "contract"), "PlanPartiOuvrir", "Contrat · " + str(p.get("name", "")))

# ---------------------------------------------------------------- option B : terrain pleine largeur, ordre sur chaque poste

static func _option_b(page: Control, app: Control, proj: Dictionary, ordres: Array, zone: Rect2) -> void:
	var panneau := D.rect(page, zone, Charte.PANNEAU, Charte.RAYON_PANNEAU)
	panneau.name = "PlanTerrainLarge"
	var terrain := Rect2(zone.position + Vector2(20, 20), zone.size - Vector2(40, 40))
	_pelouse(page, terrain)
	var lc := 560.0
	var rangs := 4
	var hc := (terrain.size.y - 24.0 - (rangs - 1) * 18.0) / rangs
	for i in POSTES.size():
		var place: Vector2 = POSTES[i].b
		var cx: float = terrain.position.x + place.x * terrain.size.x
		var cy: float = terrain.position.y + 12.0 + place.y * (hc + 18.0)
		_carte_b(page, app, ordres[i], i, Rect2(cx - lc / 2.0, cy, lc, hc))

static func _carte_b(page: Control, app: Control, o: Dictionary, i: int, r: Rect2) -> void:
	var prof := profondeur(o)
	var cp := couleur_profondeur(prof, int(o.titulaires))
	var carte := D.rect(page, r, Color(Charte.NOIR_PANNEAU, .92), Charte.RAYON_CARTE)
	carte.name = "PlanCarte_%d" % i
	# Liseré gauche à la couleur de la profondeur (avec le chiffre, jamais la couleur seule).
	D.rect(carte, Rect2(0, 10, 5, r.size.y - 20), cp, 3)
	var titre := D.text(carte, 18, 34, str(POSTES[i].nom).to_upper(), 22, Charte.IVOIRE, 800, 300)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	var l_titre := R.largeur(str(POSTES[i].nom).to_upper(), 22, 800)
	var pastille := R.pastille(carte, r.size.x - 18 - R.largeur("%d × ★4+" % prof, 17) - 26, 31, "%d × ★4+" % prof, cp, "", "PlanCarteProfondeur_%d" % i, 17)
	R.cliquable(pastille, func(): app._navigate("Recrutement"), "PlanCarteRecruter_%d" % i, "Recrutement · " + str(POSTES[i].nom))
	var y := 46.0
	var h := 31.0
	var max_lignes := int((r.size.y - y - 6) / h)
	var lignes := 0
	var titulaires := int(o.titulaires)
	var montrees := mini(o.liste.size(), titulaires * 2 + (1 if titulaires == 1 else 0))
	for k in montrees:
		if lignes >= max_lignes: break
		var item: Dictionary = o.liste[k]
		var e: Dictionary = item.e
		var base := y + h / 2.0 + 7
		var etiquette := role(k, titulaires)
		var cr := Charte.IVOIRE if etiquette == "TIT" else Charte.IVOIRE_2 if etiquette == "DOUB" else Charte.IVOIRE_3
		if etiquette == "TIT": D.rect(carte, Rect2(12, y + 2, r.size.x - 24, h - 2), Color(Charte.IVOIRE, .05), Charte.RAYON_PETIT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(carte, 20, base, etiquette, 15, cr, 700, 48)
		var couleur_nom := Charte.IVOIRE if etiquette == "TIT" else Charte.IVOIRE_2
		var l := _nom(carte, app, e.p, 72, base, h, 220, 19, couleur_nom, "PlanCarteNom_%d_" % i, bool(e.espoir))
		var mx := 72.0 + l + 8.0
		if e.espoir: D.text(carte, mx, base, "▲", 16, R.VERT, 800, 20).tooltip_text = "Espoir"
		elif e.derniere: D.text(carte, mx, base, "⧗", 17, R.ORANGE, 800, 20).tooltip_text = "Dernière année de contrat"
		elif item.depanne: D.text(carte, mx, base, "DÉP", 13, Charte.IVOIRE_3, 700, 34).tooltip_text = "Dépanne"
		D.text(carte, 330, base, str(e.age) if int(e.age) >= 0 else "", 18, couleur_age(int(e.age)), 700, 40)
		CarteSurvol.poser_etoiles(carte, Rect2(380, y + h / 2.0 - 10, 104, 20), float(item.etoiles), "PlanCarteEtoiles")
		var note: float = item.note
		D.text(carte, 496, base, str(roundi(note)) if note >= 0.0 else "—", 19, Charte.couleur_attribut(note) if note >= 0.0 else Charte.IVOIRE_3, 800, 46)
		y += h
		lignes += 1
	if o.liste.is_empty():
		D.text(carte, 20, y + h / 2.0 + 7, "—", 20, R.ROUGE, 800, 40)
		y += h
		lignes += 1
	for d: Dictionary in o.partis:
		if lignes >= max_lignes: break
		var base := y + h / 2.0 + 7
		var p: Dictionary = d.d.p
		D.text(carte, 22, base, "✕", 17, R.ROUGE, 800, 30)
		var l := _nom(carte, app, p, 72, base, h, 220, 19, Charte.IVOIRE_3, "PlanCartePartiNom_%d_" % i)
		D.line(carte, Vector2(70, base - 6), Vector2(74 + l, base - 6), Charte.IVOIRE_3, 2)
		var texte := "Vendu" if d.d.vente else "Fin " + G.contract_year(d.d.fin)
		var pp := R.pastille(carte, 330, base, texte, R.ROUGE, "", "PlanCartePartiMotif", 16)
		R.cliquable(pp, _fiche.bind(app, str(p.get("id", "")), "contract"), "PlanCartePartiOuvrir_%d" % i, "Contrat · " + str(p.get("name", "")))
		y += h
		lignes += 1
