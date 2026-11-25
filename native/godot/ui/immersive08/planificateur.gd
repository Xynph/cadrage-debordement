extends RefCounted
## Effectif › Planificateur (revue FM27, idée 11 ; choix de Léo du 23/11/2026 : les deux options réunies).
## À gauche, le terrain du XV : à chaque poste, ses 3 ou 4 premiers joueurs (titulaire, doublure, 3e) avec leurs
## signes (▲ espoir, ⧗ dernière année, DÉP dépanne, NÉGO prolongation en négociation, pastille orange = titulaire à
## deux postes), la familiarité au poste en barres et la note au poste en lettre du staff (E- à S+, jamais de chiffre :
## décision de Léo du 24/11). Un clic sur un poste affiche à droite la
## liste complète du poste, classée (un clic suffit, rien à valider). Saisons actuelle / prochaine / suivante.
## Projection faite avec les seules données du moteur : fin de contrat (contractEnd : le joueur quitte la saison d'après,
## sauf prolongation en négociation), départ vendu, âge (+1 par saison), espoirs du centre (19 ans et plus cette
## saison-là), familiarité au poste (familiarite_poste.gd) et note au poste (positionRatings).
## Note future (saisons prochaine et suivante) : estimation simple et déterministe (note_future), selon l'âge et le
## potentiel (milieu de la fourchette affichée) ; la familiarité reste celle d'aujourd'hui.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Charte = preload("res://ui/charte.gd")
const Familiarite = preload("res://ui/familiarite_poste.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")
const Notation = preload("res://ui/notation_staff.gd")

## Postes du XV regroupés (paires : 2 titulaires) : nom, sigle, numéros, place sur le terrain (colonne 0-1, rangée 0-3).
const POSTES := [
	{"nom": "Pilier gauche", "sigle": "PG", "n": [1], "b": Vector2(.0, .0)},
	{"nom": "Talonneur", "sigle": "T", "n": [2], "b": Vector2(.5, .0)},
	{"nom": "Pilier droit", "sigle": "PD", "n": [3], "b": Vector2(1.0, .0)},
	{"nom": "Deuxième ligne", "sigle": "2L", "n": [4, 5], "b": Vector2(.5, 1.0)},
	{"nom": "3e ligne aile", "sigle": "3L", "n": [6, 7], "b": Vector2(.0, 1.0)},
	{"nom": "Numéro 8", "sigle": "N8", "n": [8], "b": Vector2(1.0, 1.0)},
	{"nom": "Demi de mêlée", "sigle": "DM", "n": [9], "b": Vector2(.25, 2.0)},
	{"nom": "Demi d’ouverture", "sigle": "DO", "n": [10], "b": Vector2(.75, 2.0)},
	{"nom": "Centre", "sigle": "C", "n": [12, 13], "b": Vector2(.5, 3.0)},
	{"nom": "Ailier", "sigle": "AL", "n": [11, 14], "b": Vector2(.0, 3.0)},
	{"nom": "Arrière", "sigle": "AR", "n": [15], "b": Vector2(1.0, 3.0)},
]
const SAISONS := ["ACTUELLE", "PROCHAINE", "SUIVANTE"]
const AGE_ESPOIR := 19
const AGE_JEUNE := 21
const AGE_VETERAN := 33
const CLE_SAISON := "plan_saison"
const CLE_POSTE := "plan_poste"
const LARGEUR_TERRAIN := 1150.0
const LARGEUR_CARTE := 356.0

# ---------------------------------------------------------------- données (moteur seulement)

static func _nombre(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v))

## Milieu de la fourchette (potentialRange / ratingRange) ou valeur exacte ; -1 si inconnue.
static func _valeur(p: Dictionary, exacte: String, fourchette: String) -> float:
	if _nombre(p.get(exacte)) and float(p.get(exacte)) >= 0.0: return float(p.get(exacte))
	var f: Variant = p.get(fourchette)
	if f is Dictionary and _nombre(f.get("min")) and _nombre(f.get("max")): return (float(f.min) + float(f.max)) / 2.0
	return -1.0

static func note_globale(p: Dictionary) -> float: return _valeur(p, "rating", "ratingRange")
static func potentiel(p: Dictionary) -> float: return _valeur(p, "potential", "potentialRange")

## Note au poste (meilleure des numéros du groupe, positionRatings du moteur) ; -1 si inconnue.
static func note_groupe(p: Dictionary, numeros: Array) -> float:
	var meilleure := -1.0
	for n: int in numeros: meilleure = maxf(meilleure, CarteSurvol.note_poste(p, n))
	return meilleure

## Lettre du staff (Notation.lettre_note, échelle du Niveau) d'une note au poste du groupe : `note` = note d'aujourd'hui
## ou estimée pour la saison affichée (-1 : estimée d'après la fourchette d'observation). Même empreinte que la note au
## poste ailleurs dans le jeu (numéro du groupe où il est le meilleur). Jamais de chiffre à l'écran.
static func lettre_poste(model: Dictionary, p: Dictionary, numeros: Array, note: float, niveau: int) -> Dictionary:
	var meilleur: int = int(numeros[0])
	for n: int in numeros:
		if CarteSurvol.note_poste(p, n) > CarteSurvol.note_poste(p, meilleur): meilleur = n
	return Notation.lettre_note(model, p, note, true, Notation.cle_poste(meilleur), niveau)

## Familiarité au poste (la meilleure des numéros du groupe) ; -1 si inconnue.
static func niveau_groupe(p: Dictionary, numeros: Array) -> int:
	var meilleur := -1
	for n: int in numeros: meilleur = maxi(meilleur, Familiarite.niveau(p, n))
	return meilleur

## Note globale estimée après `saisons` saisons, pour un joueur de `age` ans aujourd'hui. Chaque saison :
## jusqu'à 29 ans, il comble une part de l'écart à son potentiel (40 % jusqu'à 20 ans, 30 % jusqu'à 23, 15 % jusqu'à
## 26, 5 % ensuite) ; dès 30 ans, il perd 1 point (30-31 ans), 2 (32-33) puis 3 (34 et plus). Potentiel inconnu :
## pas de progression, le déclin s'applique quand même.
static func globale_future(globale: float, age: int, pot: float, saisons: int) -> float:
	var r := globale
	for k in maxi(0, saisons):
		var a := age + k
		if a >= 34: r -= 3.0
		elif a >= 32: r -= 2.0
		elif a >= 30: r -= 1.0
		elif pot > r:
			var part := .40 if a <= 20 else .30 if a <= 23 else .15 if a <= 26 else .05
			r += part * (pot - r)
	return r

## Note au poste estimée dans `saisons` saisons : la note au poste d'aujourd'hui + l'évolution de la note globale
## (globale_future), entre 1 et 99, arrondie. -1 si la note au poste est inconnue ; inchangée sans âge ni note globale.
static func note_future(note: float, age: int, globale: float, pot: float, saisons: int) -> float:
	if note < 0.0: return -1.0
	if saisons <= 0 or age < 0 or globale < 0.0: return note
	return clampf(roundf(note + globale_future(globale, age, pot, saisons) - globale), 1.0, 99.0)

## Prolongation en cours de négociation (contre-offre de l'agent : renewal.negotiation.status == "counter").
static func en_negociation(p: Dictionary) -> bool:
	var renouvellement: Variant = p.get("renewal")
	if not renouvellement is Dictionary: return false
	var nego: Variant = (renouvellement as Dictionary).get("negotiation")
	return nego is Dictionary and str((nego as Dictionary).get("status", "")) == "counter"

## Projection de la saison `decalage` (0 actuelle, 1 prochaine, 2 suivante) à partir du modèle du jeu :
## {saison, decalage, presents: [{p, age, espoir, derniere, nego}], partis: [{p, fin, vente}]}.
## Un joueur en fin de contrat dont la prolongation est en négociation reste dans l'effectif, marqué « nego ».
static func projection(model: Dictionary, decalage: int) -> Dictionary:
	var saison := int(model.get("meta", {}).get("season", 1))
	var cible := saison + decalage
	var presents: Array = []
	var partis: Array = []
	for v: Variant in model.get("squad", []):
		if not v is Dictionary: continue
		var p: Dictionary = v
		var fin: Variant = p.get("contractEnd")
		var vente: Variant = p.get("sale")
		var depart_vente: bool = vente is Dictionary and (vente as Dictionary).get("pending") is Dictionary
		var age := int(p.get("age", 0)) + decalage if _nombre(p.get("age")) else -1
		var nego := en_negociation(p)
		var fin_passee := _nombre(fin) and int(fin) < cible
		if decalage > 0 and (depart_vente or (fin_passee and not nego)):
			partis.append({"p": p, "fin": int(fin) if _nombre(fin) else saison, "vente": depart_vente})
			continue
		presents.append({"p": p, "age": age, "espoir": false, "derniere": _nombre(fin) and int(fin) == cible, "nego": nego and _nombre(fin) and int(fin) <= cible})
	if decalage > 0:
		for v: Variant in model.get("decisions", {}).get("development", {}).get("academy", []):
			if not v is Dictionary or not _nombre(v.get("age")): continue
			if int(v.age) + decalage < AGE_ESPOIR: continue
			presents.append({"p": v, "age": int(v.age) + decalage, "espoir": true, "derniere": false, "nego": false})
	return {"saison": cible, "decalage": decalage, "presents": presents, "partis": partis, "model": model}

## Ordre du poste `i` : {liste: [{e, note, actuelle, niveau, depanne}] triée par note (estimée pour les saisons à
## venir), partis (titulaires naturels qui s'en vont), titulaires}. Entrent dans la liste tous les joueurs qui peuvent
## jouer au poste (Dépanne et mieux) ; les espoirs du centre seulement s'ils sont Confirmés ou Naturels et entrent dans
## les 3 premiers rangs.
static func ordre(proj: Dictionary, i: int) -> Dictionary:
	var numeros: Array = POSTES[i].n
	var decalage := int(proj.get("decalage", 0))
	var liste: Array = []
	for e: Dictionary in proj.presents:
		var niveau := niveau_groupe(e.p, numeros)
		if niveau < Familiarite.DEPANNE: continue
		var actuelle := note_groupe(e.p, numeros)
		var age_aujourdhui := int(e.age) - decalage if int(e.age) >= 0 else -1
		var note := note_future(actuelle, age_aujourdhui, note_globale(e.p), potentiel(e.p), decalage)
		# Ordre = lettre MONTRÉE (estimation du staff), puis familiarité, puis identifiant : jamais la note cachée.
		var rang := Notation.rang_lettre(lettre_poste(proj.get("model", Notation.modele), e.p, numeros, note, niveau)) if note >= 0.0 else -1.0
		liste.append({"e": e, "note": note, "rang": rang, "actuelle": actuelle, "niveau": niveau, "depanne": niveau == Familiarite.DEPANNE})
	liste.sort_custom(func(a: Dictionary, b: Dictionary): return a.rang > b.rang or (a.rang == b.rang and (a.niveau > b.niveau or (a.niveau == b.niveau and str(a.e.p.get("id", "")) < str(b.e.p.get("id", ""))))))
	var profondeur_max: int = numeros.size() * 3
	var gardes: Array = []
	for item: Dictionary in liste:
		if not bool(item.e.espoir) or (gardes.size() < profondeur_max and int(item.niveau) >= Familiarite.CONFIRME): gardes.append(item)
	var partis: Array = []
	for d: Dictionary in proj.partis:
		if niveau_groupe(d.p, numeros) == Familiarite.NATUREL:
			partis.append({"d": d, "note": note_groupe(d.p, numeros), "niveau": Familiarite.NATUREL, "numeros": numeros})
	return {"liste": gardes, "partis": partis, "titulaires": numeros.size()}

static func ordres(proj: Dictionary) -> Array:
	var sortie: Array = []
	for i in POSTES.size(): sortie.append(ordre(proj, i))
	return sortie

## Joueurs titulaires à plusieurs postes la même saison : {id: [indices des postes]} (gardés aux deux, signalés).
static func titulaires_multiples(liste_ordres: Array) -> Dictionary:
	var postes := {}
	for i in liste_ordres.size():
		var o: Dictionary = liste_ordres[i]
		for rang in mini(int(o.titulaires), o.liste.size()):
			var id := str(o.liste[rang].e.p.get("id", ""))
			if id.is_empty(): continue
			if not postes.has(id): postes[id] = []
			postes[id].append(i)
	var sortie := {}
	for id: String in postes:
		if (postes[id] as Array).size() > 1: sortie[id] = postes[id]
	return sortie

## Joueurs Naturels ou Confirmés au poste.
static func profondeur(o: Dictionary) -> int:
	return o.liste.filter(func(x: Dictionary): return int(x.niveau) >= Familiarite.CONFIRME).size()

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

## Sens estimé par rapport à aujourd'hui (note future - note actuelle) : « ▲ » / « ▼ » et couleur, jamais l'écart
## chiffré (décision de Léo du 24/11) ; "" si nul ou inconnu.
static func ecart(item: Dictionary) -> Array:
	if float(item.actuelle) < 0.0 or float(item.note) < 0.0: return ["", Charte.IVOIRE_3]
	var d := roundi(float(item.note) - roundf(float(item.actuelle)))
	if d == 0: return ["", Charte.IVOIRE_3]
	return ["▲" if d > 0 else "▼", R.VERT if d > 0 else R.ROUGE]

# ---------------------------------------------------------------- entrée

static func construire(page: Control, app: Control, y: float, bas: float) -> void:
	var state: Dictionary = app.management_ui.roster
	var decalage := clampi(int(state.get(CLE_SAISON, 0)), 0, 2)
	var proj := projection(app.model, decalage)
	var liste_ordres := ordres(proj)
	var doubles := titulaires_multiples(liste_ordres)
	_entete(page, app, decalage, proj, liste_ordres, y)
	var zone := Rect2(0, y + 70, page.LARGEUR, bas - y - 74)
	# Poste par défaut : le premier qui perd un joueur cette saison-là, sinon le centre.
	var defaut := 8
	for k in liste_ordres.size():
		if not (liste_ordres[k].partis as Array).is_empty():
			defaut = k
			break
	var choisi := clampi(int(state.get(CLE_POSTE, defaut)), 0, POSTES.size() - 1)
	_terrain(page, app, liste_ordres, doubles, choisi, decalage, Rect2(zone.position, Vector2(LARGEUR_TERRAIN, zone.size.y)))
	_liste_poste(page, app, liste_ordres[choisi], doubles, choisi, decalage, Rect2(zone.position.x + LARGEUR_TERRAIN + 20, zone.position.y, zone.size.x - LARGEUR_TERRAIN - 20, zone.size.y))

## Un clic applique tout de suite (règle de Léo du 23/11 : jamais de bouton Valider).
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

## Nom cliquable (fiche, ou Formation pour un espoir) avec carte joueur au survol. Renvoie la largeur posée.
static func _nom(parent: Control, app: Control, p: Dictionary, x: float, base: float, h: float, largeur_max: float, taille: int, couleur: Color, prefixe: String, espoir := false) -> float:
	var nom := str(p.get("name", ""))
	var etiquette := D.text(parent, x, base, nom, taille, couleur, 600, largeur_max, HORIZONTAL_ALIGNMENT_LEFT, true)
	etiquette.clip_text = true
	# Largeur réelle (police du corps de texte) : les signes se posent juste après le nom.
	var l := minf(largeur_max, C.BODY.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille))).x / C.density)
	var id := str(p.get("id", ""))
	var lien := _bouton(parent, Rect2(x - 4, base - h * .7, l + 8, h), func():
		if espoir: app._navigate("Formation")
		else: _fiche(app, id), prefixe + id.validate_node_name(), "")
	if not espoir: CarteSurvol.lier_info(app, lien, id, "squad")
	else: lien.tooltip_text = "Centre de formation"
	return l

static func _noms_postes(indices: Array, sauf: int) -> String:
	var noms: Array = []
	for k: int in indices:
		if k != sauf: noms.append(str(POSTES[k].nom))
	return ", ".join(noms)

# ---------------------------------------------------------------- en-tête : saisons et totaux

static func _entete(page: Control, app: Control, decalage: int, proj: Dictionary, liste_ordres: Array, y: float) -> void:
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
	# Totaux de la saison affichée : départs, dernière année, négociations, espoirs, postes courts.
	var vus := {}
	for o: Dictionary in liste_ordres:
		for item: Dictionary in o.liste:
			if bool(item.e.espoir): vus[str(item.e.p.get("id", ""))] = true
	var derniers: int = proj.presents.filter(func(e: Dictionary): return bool(e.derniere) and not bool(e.nego)).size()
	var negos: int = proj.presents.filter(func(e: Dictionary): return bool(e.nego)).size()
	var faibles := 0
	for o: Dictionary in liste_ordres:
		if profondeur(o) < int(o.titulaires) * 2: faibles += 1
	var contrats := func(): app.management_ui.roster.immersive_tab = 2; app._render(false)
	var tuiles := [
		{"v": proj.partis.size(), "l": "départs", "c": R.ROUGE, "act": contrats, "id": "Departs", "aide": "Contrats"},
		{"v": derniers, "l": "dernière année", "c": R.ORANGE, "act": contrats, "id": "Derniers", "aide": "Contrats"},
		{"v": negos, "l": "en négociation", "c": R.BLEU, "act": contrats, "id": "Negos", "aide": "Contrats"},
		{"v": vus.size(), "l": "espoirs", "c": R.VERT, "act": func(): app._navigate("Formation"), "id": "Espoirs", "aide": "Formation"},
		{"v": faibles, "l": "postes courts", "c": R.ORANGE if faibles > 0 else R.VERT, "act": func(): app._navigate("Recrutement"), "id": "Courts", "aide": "Recrutement"},
	]
	var droite: float = page.LARGEUR
	for i in range(tuiles.size() - 1, -1, -1):
		var d: Dictionary = tuiles[i]
		var valeur := str(d.v)
		var l := 14.0 + R.largeur(valeur, 34, 800) + 12.0 + R.largeur(str(d.l).to_upper(), 17) + 22.0
		var tuile := R.tuile(page, Rect2(droite - l, y - 2, l, 52), valeur, str(d.l), d.c, "PlanTotal" + str(d.id), 34, int(d.v) > 0)
		R.cliquable(tuile, d.act, "PlanTotalOuvrir" + str(d.id), str(d.aide))
		droite -= l + 10.0

# ---------------------------------------------------------------- terrain : 3 ou 4 noms par poste

static func _pelouse(parent: Control, terrain: Rect2) -> void:
	var pelouse := D.rect(parent, terrain, Color("1e3a2a"), 12)
	pelouse.name = "PlanPelouse"
	pelouse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ligne := Color(Charte.IVOIRE, .2)
	for f: float in [.04, .24, .5, .76, .96]:
		D.line(pelouse, Vector2(12, terrain.size.y * f), Vector2(terrain.size.x - 12, terrain.size.y * f), ligne if f in [.04, .5, .96] else Color(ligne, .45), 2 if f in [.04, .96] else 1)

static func _terrain(page: Control, app: Control, liste_ordres: Array, doubles: Dictionary, choisi: int, decalage: int, zone: Rect2) -> void:
	var panneau := D.rect(page, zone, Charte.PANNEAU, Charte.RAYON_PANNEAU)
	panneau.name = "PlanTerrainPanneau"
	var terrain := Rect2(zone.position + Vector2(18, 18), zone.size - Vector2(36, 36))
	_pelouse(page, terrain)
	var x0 := terrain.position.x + 6.0
	var x2 := terrain.end.x - 6.0 - LARGEUR_CARTE
	var ecart_rangs := 12.0
	var hc := (terrain.size.y - 12.0 - 3.0 * ecart_rangs) / 4.0
	for i in POSTES.size():
		var place: Vector2 = POSTES[i].b
		var r := Rect2(x0 + place.x * (x2 - x0), terrain.position.y + 6.0 + place.y * (hc + ecart_rangs), LARGEUR_CARTE, hc)
		_carte(page, app, liste_ordres[i], doubles, i, i == choisi, decalage, r)

## Signes d'un joueur au poste : [{t, c, aide, rond}] (▲ espoir, NÉGO, ⧗ dernière année, DÉP, pastille orange « 2 »).
static func signes(item: Dictionary, i: int, doubles: Dictionary) -> Array:
	var e: Dictionary = item.e
	var sortie: Array = []
	var id := str(e.p.get("id", ""))
	if doubles.has(id): sortie.append({"t": str((doubles[id] as Array).size()), "c": R.ORANGE, "aide": "Titulaire aussi · " + _noms_postes(doubles[id], i), "rond": true})
	if bool(e.espoir): sortie.append({"t": "▲", "c": R.VERT, "aide": "Espoir", "rond": false})
	elif bool(e.nego): sortie.append({"t": "NÉGO", "c": R.BLEU, "aide": "Prolongation en négociation", "rond": false})
	elif bool(e.derniere): sortie.append({"t": "⧗", "c": R.ORANGE, "aide": "Dernière année de contrat", "rond": false})
	if bool(item.depanne): sortie.append({"t": "DÉP", "c": Charte.IVOIRE_3, "aide": "Dépanne", "rond": false})
	return sortie

static func _largeur_signes(liste: Array) -> float:
	var l := 0.0
	for s: Dictionary in liste: l += (20.0 if s.rond else R.largeur(str(s.t), 15, 800)) + 6.0
	return l

static func _poser_signes(parent: Control, liste: Array, x: float, base: float, nom: String) -> void:
	for s: Dictionary in liste:
		if s.rond:
			var rond := D.rect(parent, Rect2(x, base - 15, 20, 19), s.c, 99)
			rond.name = nom + "Double"
			rond.tooltip_text = str(s.aide)
			rond.mouse_filter = Control.MOUSE_FILTER_PASS
			D.text(rond, 10, 14.5, str(s.t), 13, Charte.ENCRE, 800, 20, HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
			x += 26.0
		else:
			var t := D.text(parent, x, base, str(s.t), 15 if str(s.t).length() == 1 else 13, s.c, 800, R.largeur(str(s.t), 15, 800) + 2)
			t.tooltip_text = str(s.aide)
			t.mouse_filter = Control.MOUSE_FILTER_PASS
			x += R.largeur(str(s.t), 15, 800) + 6.0

static func _carte(page: Control, app: Control, o: Dictionary, doubles: Dictionary, i: int, actif: bool, decalage: int, r: Rect2) -> void:
	var prof := profondeur(o)
	var cp := couleur_profondeur(prof, int(o.titulaires))
	var carte := D.rect(page, r, Charte.SELECTION if actif else Color(Charte.NOIR_PANNEAU, .92), Charte.RAYON_CARTE, Charte.IVOIRE if actif else Color.TRANSPARENT)
	if actif: (carte.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(1, C.px(2.5)))
	carte.name = "PlanCarte_%d" % i
	# Toute la carte choisit le poste (la liste complète s'affiche à droite, tout de suite).
	_bouton(carte, Rect2(Vector2.ZERO, r.size), _changer.bind(app, CLE_POSTE, i), "PlanPosteOuvrir_%d" % i, "%s · liste du poste" % POSTES[i].nom, 12)
	# Liseré gauche à la couleur de la profondeur (avec le chiffre, jamais la couleur seule).
	D.rect(carte, Rect2(0, 10, 5, r.size.y - 20), cp, 3).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var titre := D.text(carte, 16, 33, str(POSTES[i].nom).to_upper(), 21, Charte.IVOIRE, 800, 230)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Profondeur : barres « Confirmé » + nombre de Naturels et Confirmés.
	var xb := r.size.x - 64.0
	var lb := Familiarite.poser_barres(carte, xb, 32, Familiarite.CONFIRME, 17, "PlanCarteProfondeurBarres_%d" % i)
	(carte.get_node(NodePath("PlanCarteProfondeurBarres_%d" % i)) as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chiffre := D.text(carte, xb + lb + 6, 32, str(prof), 20, cp, 800, 30)
	chiffre.name = "PlanCarteProfondeur_%d" % i
	chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var y := 44.0
	var h := 30.0
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
		if etiquette == "TIT": D.rect(carte, Rect2(10, y + 2, r.size.x - 20, h - 2), Color(Charte.IVOIRE, .05), Charte.RAYON_PETIT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(carte, 16, base, etiquette, 13, cr, 700, 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Signes en colonne, calés à droite avant l'âge ; le nom prend la place restante.
		var marques := signes(item, i, doubles)
		var xs := 204.0 - _largeur_signes(marques)
		_nom(carte, app, e.p, 56, base, h, xs - 62.0, 17, Charte.IVOIRE if etiquette == "TIT" else Charte.IVOIRE_2, "PlanCarteNom_%d_" % i, bool(e.espoir))
		_poser_signes(carte, marques, xs, base, "PlanCarteSigne_%d_%d" % [i, k])
		D.text(carte, 216, base, str(e.age) if int(e.age) >= 0 else "", 16, couleur_age(int(e.age)), 700, 30, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var barres := Familiarite.poser_barres(carte, 256, base + 2, int(item.niveau), 15, "PlanCarteFamiliarite")
		var noeud_barres := carte.get_child(carte.get_child_count() - 1) as Control
		noeud_barres.tooltip_text = "Familiarité au poste · " + Familiarite.mot(int(item.niveau))
		var nx := 256.0 + barres + 4.0
		var lettre := lettre_poste(app.model, e.p, POSTES[i].n, float(item.note), int(item.niveau))
		var ln := maxf(322.0 - nx, Notation.largeur_note(lettre, 18 * 1.35))
		Familiarite.poser_note(carte, nx, base, lettre, 18, ln, "PlanCarteNote")
		if decalage > 0:
			var ec := ecart(item)
			if not str(ec[0]).is_empty():
				var fl := D.text(carte, maxf(324.0, nx + ln + 2.0), base - 1, str(ec[0]), 12, ec[1], 800, 28)
				fl.name = "PlanCarteEcart"
				fl.tooltip_text = "Aujourd’hui · " + Notation.texte_note(lettre_poste(app.model, e.p, POSTES[i].n, float(item.actuelle), int(item.niveau)))
				fl.mouse_filter = Control.MOUSE_FILTER_PASS
		y += h
		lignes += 1
	if o.liste.is_empty():
		D.text(carte, 18, y + h / 2.0 + 7, "—", 20, R.ROUGE, 800, 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
		y += h
		lignes += 1
	for d: Dictionary in o.partis:
		if lignes >= max_lignes: break
		var base := y + h / 2.0 + 7
		var p: Dictionary = d.d.p
		D.text(carte, 18, base, "✕", 16, R.ROUGE, 800, 30).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _nom(carte, app, p, 56, base, h, 150, 17, Charte.IVOIRE_3, "PlanCartePartiNom_%d_" % i)
		D.line(carte, Vector2(54, base - 6), Vector2(58 + l, base - 6), Charte.IVOIRE_3, 2).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texte := "Vendu" if d.d.vente else "Fin " + G.contract_year(d.d.fin)
		var pp := R.pastille(carte, 222, base, texte, R.ROUGE, "", "PlanCartePartiMotif", 15)
		R.cliquable(pp, _fiche.bind(app, str(p.get("id", "")), "contract"), "PlanCartePartiOuvrir_%d" % i, "Contrat · " + str(p.get("name", "")))
		y += h
		lignes += 1

# ---------------------------------------------------------------- liste complète du poste choisi

const COLONNES := [
	{"t": "RANG", "x": 0.0, "w": 86.0}, {"t": "JOUEUR", "x": 96.0, "w": 260.0}, {"t": "ÂGE", "x": 366.0, "w": 50.0},
	{"t": "FAMILIARITÉ", "x": 430.0, "w": 170.0}, {"t": "NOTE", "x": 612.0, "w": 110.0}, {"t": "CONTRAT", "x": 730.0, "w": 100.0},
	{"t": "STATUT", "x": 840.0, "w": 210.0},
]

static func _liste_poste(page: Control, app: Control, o: Dictionary, doubles: Dictionary, i: int, decalage: int, zone: Rect2) -> void:
	var panneau := D.rect(page, zone, Charte.PANNEAU, Charte.RAYON_PANNEAU)
	panneau.name = "PlanListe"
	var nom := str(POSTES[i].nom).to_upper()
	var titre := D.text(panneau, 28, 54, nom, 34, Charte.IVOIRE, 800, 600)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "PlanListeTitre"
	var prof := profondeur(o)
	var cp := couleur_profondeur(prof, int(o.titulaires))
	var tx := 28.0 + R.largeur(nom, 34, 800) + 22.0
	var lb := Familiarite.poser_barres(panneau, tx, 52, Familiarite.CONFIRME, 20, "PlanListeProfondeurBarres")
	var chiffre := D.text(panneau, tx + lb + 8, 52, str(prof), 24, cp, 800, 40)
	chiffre.name = "PlanListeProfondeur"
	chiffre.tooltip_text = "Naturels et Confirmés · %d" % prof
	chiffre.mouse_filter = Control.MOUSE_FILTER_PASS
	var bouton_recherche := R.pastille(panneau, zone.size.x - 28 - R.largeur("Recruter", 19) - 60, 50, "Recruter", R.BLEU, "search", "PlanRecruter", 19)
	R.cliquable(bouton_recherche, func(): app._navigate("Recrutement"), "PlanRecruterOuvrir", "Recrutement · " + str(POSTES[i].nom))
	var y := 84.0
	var entete := D.rect(panneau, Rect2(16, y, zone.size.x - 32, 40), Charte.BANDEAU_ENTETE, Charte.RAYON_PETIT)
	for col: Dictionary in COLONNES:
		var t := str(col.t)
		if t == "NOTE" and decalage > 0: t = "NOTE ESTIMÉE"
		D.text(entete, 14 + col.x, 27, t, 17, Charte.IVOIRE_3, 700, col.w + 20)
	y += 48.0
	var h := 50.0
	var rang := 0
	for item: Dictionary in o.liste:
		if y + h > zone.size.y - 10: break
		_ligne(panneau, app, item, rang, int(o.titulaires), doubles, i, decalage, Rect2(16, y, zone.size.x - 32, h))
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

static func _ligne(parent: Control, app: Control, item: Dictionary, rang: int, titulaires: int, doubles: Dictionary, i: int, decalage: int, r: Rect2) -> void:
	var e: Dictionary = item.e
	var p: Dictionary = e.p
	var id := str(p.get("id", ""))
	var ligne := D.rect(parent, r, Charte.PANNEAU_2 if rang % 2 == 0 else Color.TRANSPARENT, Charte.RAYON_PETIT)
	ligne.name = "PlanLigne_%d" % rang
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base := r.size.y / 2.0 + 7.0
	var etiquette := role(rang, titulaires)
	var cr := Charte.IVOIRE if etiquette == "TIT" else Charte.IVOIRE_2 if etiquette == "DOUB" else Charte.IVOIRE_3
	var ovale := D.rect(ligne, Rect2(12, r.size.y / 2.0 - 15, 34, 30), cr if etiquette == "TIT" else Color.TRANSPARENT, 99, cr)
	D.text(ovale, 17, 22, str(rang + 1), 18, Charte.ENCRE if etiquette == "TIT" else cr, 800, 34, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(ligne, 52, base, etiquette, 15, cr, 700, 44)
	var portrait: Control = G.portrait_lazy(int(p.get("portraitIndex", 0)), C.px(34), p)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(portrait)
	D.place(portrait, Rect2(110, (r.size.y - 34) / 2.0, 35, 34))
	_nom(ligne, app, p, 154, base, r.size.y - 8, 220, 20, Charte.IVOIRE, "PlanNom_", bool(e.espoir))
	D.text(ligne, 380, base, str(e.age) if int(e.age) >= 0 else "—", 20, couleur_age(int(e.age)), 700, 50)
	Familiarite.poser(ligne, 444, base, int(item.niveau), 17, "PlanFamiliarite")
	Familiarite.poser_note(ligne, 626, base, lettre_poste(app.model, p, POSTES[i].n, float(item.note), int(item.niveau)), 22, 40, "PlanNote")
	if decalage > 0:
		var ec := ecart(item)
		if not str(ec[0]).is_empty():
			var d := D.text(ligne, 672, base - 2, str(ec[0]), 15, ec[1], 800, 50)
			d.name = "PlanEcart"
			d.tooltip_text = "Aujourd’hui · " + Notation.texte_note(lettre_poste(app.model, p, POSTES[i].n, float(item.actuelle), int(item.niveau)))
			d.mouse_filter = Control.MOUSE_FILTER_PASS
	if not e.espoir:
		var cc := R.BLEU if e.nego else R.ORANGE if e.derniere else Charte.IVOIRE_2
		var pc := R.pastille(ligne, 744, base, G.contract_year(p.get("contractEnd")), cc, "calendar", "PlanContrat", 17)
		R.cliquable(pc, _fiche.bind(app, id, "contract"), "PlanContratOuvrir", "Contrat · " + str(p.get("name", "")))
	# Statut : pastilles courtes et cliquables, tant qu'elles tiennent.
	var sx := 854.0
	var fin_statut := r.size.x - 8.0
	var statuts: Array = []
	if doubles.has(id):
		var autres: Array = (doubles[id] as Array).filter(func(k: int): return k != i)
		statuts.append({"t": "%d postes" % (doubles[id] as Array).size(), "c": R.ORANGE, "id": "PlanDouble", "aide": "Titulaire aussi · " + _noms_postes(doubles[id], i), "act": _changer.bind(app, CLE_POSTE, int(autres[0]) if not autres.is_empty() else i)})
	if e.espoir: statuts.append({"t": "▲ Espoir", "c": R.VERT, "id": "PlanEspoir", "aide": "Formation", "act": func(): app._navigate("Formation")})
	elif e.nego: statuts.append({"t": "En négociation", "c": R.BLEU, "id": "PlanNego", "aide": "Prolongation · " + str(p.get("name", "")), "act": _fiche.bind(app, id, "contract")})
	elif e.derniere: statuts.append({"t": "⧗ Dernière année", "c": R.ORANGE, "id": "PlanDerniere", "aide": "Prolonger · " + str(p.get("name", "")), "act": _fiche.bind(app, id, "contract")})
	elif int(e.age) >= AGE_VETERAN: statuts.append({"t": "%d ans" % int(e.age), "c": R.ORANGE, "id": "PlanVeteran", "aide": str(p.get("name", "")), "act": _fiche.bind(app, id, "")})
	for s: Dictionary in statuts:
		var l := 24.0 + R.largeur(str(s.t), 16) + 2.0
		if sx + l > fin_statut: break
		var pastille := R.pastille(ligne, sx, base, str(s.t), s.c, "", str(s.id), 16)
		R.cliquable(pastille, s.act, str(s.id) + "Ouvrir", str(s.aide))
		sx += l + 6.0

static func _ligne_partie(parent: Control, app: Control, d: Dictionary, r: Rect2) -> void:
	var p: Dictionary = d.d.p
	var ligne := D.rect(parent, r, Color(R.ROUGE, .07), Charte.RAYON_PETIT)
	ligne.name = "PlanParti"
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base := r.size.y / 2.0 + 7.0
	D.text(ligne, 20, base, "✕", 22, R.ROUGE, 800, 30)
	var l := _nom(ligne, app, p, 154, base, r.size.y - 8, 220, 20, Charte.IVOIRE_3, "PlanPartiNom_")
	D.line(ligne, Vector2(150, base - 7), Vector2(158 + l, base - 7), Color(Charte.IVOIRE_3, .9), 2)
	Familiarite.poser(ligne, 444, base, int(d.niveau), 17, "PlanPartiFamiliarite")
	Familiarite.poser_note(ligne, 626, base, lettre_poste(app.model, p, d.numeros, float(d.note), int(d.niveau)), 22, 40, "PlanPartiNote")
	var texte := "Vendu" if d.d.vente else "Fin de contrat " + G.contract_year(d.d.fin)
	var pp := R.pastille(ligne, 744, base, texte, R.ROUGE, "", "PlanPartiMotif", 17)
	R.cliquable(pp, _fiche.bind(app, str(p.get("id", "")), "contract"), "PlanPartiOuvrir", "Contrat · " + str(p.get("name", "")))
