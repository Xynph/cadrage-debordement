extends RefCounted
## Planche « Séance avec ses effets » (revue FM27, idée 25) sous CD_VARIANTE_VISUELLE=A|B : depuis Entraînement › Mois,
## clic sur une séance d'un jour = petite fenêtre pour la remplacer. Un clic sur une séance la choisit et la met en place
## (pas de bouton Confirmer). Données du moteur seulement :
##  - catalogue : les séances des semaines types (`calendarPlanning.templates[].slots` : famille + nom) ;
##  - effets : `calendarPlanning.sessionEffects` (fatigue, condition, progrès avants / arrières, organisation) ;
##  - intensité du jour : somme de la fatigue des séances du jour (match = jour de match).
## Le choix est gardé dans l'état de l'écran (`immersive_training.seances_choisies`) : le moteur n'a pas encore de
## commande pour remplacer une seule séance (à ajouter à l'intégration).
##  A : façon fiche de séance — bande de la semaine en haut, familles en onglets, liste à gauche, jauges à droite.
##  B : tableau façon Effectif — toutes les séances en lignes, une colonne par effet (barre + chiffre), tri par en-tête.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Agenda = preload("res://ui/immersive08/calendar_agenda.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const SurvolLigne = preload("res://ui/survol_ligne.gd")

const NOM := "TrainingSessionWindow"
const FAMILLES_ORDRE := ["intensif", "technique", "tactique", "recuperation"]
## Effet → [libellé, plus = gain ?] (fatigue : plus = coût).
const AXES := [
	["cohesion", "Organisation", true],
	["fatigue", "Fatigue", false],
	["condition", "Condition", true],
	["avants", "Progrès avants", true],
	["arrieres", "Progrès arrières", true],
]

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

## Remplace les séances choisies dans la liste des séances du jour (clé « date#rang »).
static func appliquer_choix(page: Control, seances: Dictionary) -> void:
	var choisies: Variant = page.state.get("seances_choisies", {})
	if not choisies is Dictionary: return
	for cle: String in choisies:
		var morceaux := cle.split("#")
		if morceaux.size() != 2 or not seances.has(morceaux[0]): continue
		var rang := morceaux[1].to_int()
		var liste: Array = seances[morceaux[0]]
		if rang < 0 or rang >= liste.size(): continue
		var s: Dictionary = (liste[rang] as Dictionary).duplicate()
		s.kind = str(choisies[cle].kind)
		s.label = str(choisies[cle].label)
		s.choisie = true
		liste[rang] = s

## Catalogue : chaque séance distincte des semaines types du moteur (famille, nom), dans l'ordre des familles.
static func catalogue(data: Dictionary) -> Array:
	var Mois = load("res://ui/immersive08/training_mois.gd")
	var vus := {}
	var sortie: Array = []
	for id: String in ["standard", "away", "congested", "break"]:
		for slot: Variant in Dictionary(data.modeles.get(id, {})).get("slots", []):
			if not slot is Dictionary: continue
			var cle := "%s|%s" % [slot.get("kind", ""), slot.get("label", "")]
			if vus.has(cle): continue
			vus[cle] = true
			sortie.append({"kind": str(slot.get("kind", "")), "label": str(slot.get("label", "")), "famille": Mois.FAMILLE_DE.get(str(slot.get("kind", "")), "technique")})
	sortie.sort_custom(func(a: Dictionary, b: Dictionary):
		var fa := FAMILLES_ORDRE.find(a.famille)
		var fb := FAMILLES_ORDRE.find(b.famille)
		return fa < fb if fa != fb else str(a.label) < str(b.label))
	return sortie

## Intensité d'un jour : [mot, couleur, part de la bande 0..1].
static func intensite(data: Dictionary, date: String) -> Array:
	if data.matchs.has(date): return ["Match", Charte.IVOIRE, 1.0]
	var seances: Array = data.seances.get(date, [])
	if seances.is_empty(): return ["Repos", Charte.REPOS, .12]
	var total := 0
	for s: Dictionary in seances: total += int(Dictionary(data.par_seance.get(str(s.get("kind", "")), {})).get("fatigue", 0))
	var part := clampf((total + 4) / 10.0, .15, 1.0)
	if total <= 0: return ["Légère", Charte.REPOS, part]
	if total <= 2: return ["Normale", Charte.GAIN, part]
	if total <= 4: return ["Soutenue", Charte.INTENSIF, part]
	return ["Forte", Charte.PERTE, part]

static func _max_axe(data: Dictionary, axe: String) -> int:
	var m := 1
	for k: String in data.par_seance: m = maxi(m, absi(int(Dictionary(data.par_seance[k]).get(axe, 0))))
	return m

## Ouvre la fenêtre pour la séance `rang` du jour `date`.
static func ouvrir(page: Control, date: String, rang: int) -> void:
	page.state.seance_cible = {"date": date, "rang": rang}
	page.state.erase("seance_famille")
	_rendre(page)

static func _rendre(page: Control) -> void:
	var Mois = load("res://ui/immersive08/training_mois.gd")
	var data: Dictionary = Mois._donnees(page)
	var cible: Dictionary = page.state.get("seance_cible", {})
	var date := str(cible.get("date", ""))
	var rang := int(cible.get("rang", 0))
	var du_jour: Array = data.seances.get(date, [])
	if rang >= du_jour.size(): return
	var actuelle: Dictionary = du_jour[rang]
	var fermeture := func():
		page.state.erase("seance_cible")
		page._open_tab(page.active_tab)
	if variante() == "B": _fenetre_b(page, data, date, rang, actuelle, fermeture)
	else: _fenetre_a(page, data, date, rang, actuelle, fermeture)

static func _choisir(page: Control, date: String, rang: int, s: Dictionary) -> void:
	if not page.state.get("seances_choisies") is Dictionary: page.state.seances_choisies = {}
	page.state.seances_choisies["%s#%d" % [date, rang]] = {"kind": s.kind, "label": s.label}
	_rendre(page)

# --- Bande de la semaine (commune) -----------------------------------------------------------------------------------

## Sept jours en colonnes : jour, créneaux (match crème, séances colorées), bande d'intensité dessous. Clic sur une
## séance = c'est elle qu'on remplace.
static func _semaine(page: Control, fond: Control, data: Dictionary, date: String, rang: int, zone: Rect2, creneaux_max: int) -> void:
	var Mois = load("res://ui/immersive08/training_mois.gd")
	var jours: Array = Agenda.week(date)
	var largeur := (zone.size.x - 6 * 10) / 7.0
	var hc := 34.0
	for j in 7:
		var d: String = jours[j]
		var x := zone.position.x + j * (largeur + 10)
		var cadre := D.rect(fond, Rect2(x, zone.position.y, largeur, zone.size.y), Color(Charte.PANNEAU_3, .7), Charte.RAYON_PETIT, Charte.IVOIRE if d == date else Color.TRANSPARENT)
		cadre.name = "TrainingSessionDay_" + d
		cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(cadre, 12, 28, "%s %d" % [Mois.JOURS[j], d.substr(8, 2).to_int()], 20, Charte.IVOIRE if d == date else Charte.IVOIRE_2, 700, largeur - 20).add_theme_font_override("font", Charte.TITRE_FICHE)
		var creneaux: Array = Mois._creneaux(data, d, creneaux_max)
		var rang_seance := 0
		for k in creneaux_max:
			var rc := Rect2(8, 40 + k * (hc + 5), largeur - 16, hc)
			if k >= creneaux.size():
				var vide := D.rect(cadre, rc, Color.TRANSPARENT, Charte.RAYON_PETIT, Charte.FILET)
				vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if k == 0: D.text(vide, 10, 23, "Repos", 15, Charte.IVOIRE_3, 600, rc.size.x - 14).mouse_filter = Control.MOUSE_FILTER_IGNORE
				continue
			var cr: Array = creneaux[k]
			if cr[0] == "match":
				var bloc := D.rect(cadre, rc, Charte.IVOIRE, Charte.RAYON_PETIT)
				bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var adv: Dictionary = Mois._adversaire(data, cr[2])
				D.text(bloc, 10, 24, Mois._court(adv) + "  " + Mois._lieu(data, cr[2]), 16, Charte.ENCRE, 800, rc.size.x - 14).mouse_filter = Control.MOUSE_FILTER_IGNORE
				continue
			var couleur: Color = Mois.FAMILLES[cr[0]][1]
			var visee: bool = d == date and rang_seance == rang
			var bloc := D.rect(cadre, rc, Color(couleur, .5 if visee else .22), Charte.RAYON_PETIT, Charte.IVOIRE if visee else Color.TRANSPARENT)
			bloc.name = "TrainingSessionSlot_%s_%d" % [d, rang_seance]
			D.rect(bloc, Rect2(0, 0, 5, hc), couleur, 2).mouse_filter = Control.MOUSE_FILTER_IGNORE
			var icone: TextureRect = Mois.icone_seance(str(cr[2].get("kind", "")), hc - 12)
			icone.modulate = Charte.IVOIRE if visee else couleur
			bloc.add_child(icone)
			D.place(icone, Rect2(10, 6, hc - 12, hc - 12))
			D.text(bloc, hc + 4, 24, str(cr[1]), 15, Charte.IVOIRE, 700 if visee else 600, rc.size.x - hc - 8).mouse_filter = Control.MOUSE_FILTER_IGNORE
			var cible_date := d
			var cible_rang := rang_seance
			Pieces.rendre_cliquable(bloc, rc.size, func(): ouvrir(page, cible_date, cible_rang), "TrainingSessionSlotOpen_%s_%d" % [d, rang_seance], str(cr[1]), "", Charte.RAYON_PETIT)
			rang_seance += 1
		# Bande d'intensité du jour : rail + remplissage coloré + mot.
		var it := intensite(data, d)
		var y_bande := zone.size.y - 30
		var rail := D.rect(cadre, Rect2(112, y_bande, largeur - 124, 12), Charte.FILET, Charte.RAYON_PILULE)
		rail.name = "TrainingSessionIntensity_" + d
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.rect(rail, Rect2(0, 0, (largeur - 124) * float(it[2]), 12), it[1], Charte.RAYON_PILULE).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(cadre, 12, y_bande + 13, str(it[0]), 16, it[1], 700, 96).mouse_filter = Control.MOUSE_FILTER_IGNORE

## Jauge centrée : zéro au milieu, gain vert vers la droite, coût rouge vers la gauche ; chiffre signé à droite.
static func _jauge(parent: Control, r: Rect2, valeur: int, maximum: int, gain_si_plus: bool, id: String) -> void:
	var rail := D.rect(parent, r, Charte.FILET, Charte.RAYON_PILULE)
	rail.name = id
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var milieu := r.size.x / 2.0
	D.rect(rail, Rect2(milieu - 1, -4, 2, r.size.y + 8), Charte.IVOIRE_3).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if valeur == 0: return
	var gain := (valeur > 0) == gain_si_plus
	var couleur: Color = Charte.GAIN if gain else Charte.PERTE
	var longueur := milieu * minf(1.0, absi(valeur) / float(maxi(1, maximum)))
	var x := milieu if gain else milieu - longueur
	D.rect(rail, Rect2(x, 0, longueur, r.size.y), couleur, Charte.RAYON_PILULE).mouse_filter = Control.MOUSE_FILTER_IGNORE

static func _signe(v: int) -> String:
	return "=" if v == 0 else ("+" if v > 0 else "−") + str(absi(v))

static func _couleur(v: int, gain_si_plus: bool) -> Color:
	if v == 0: return Charte.IVOIRE_3
	return Charte.GAIN if (v > 0) == gain_si_plus else Charte.PERTE

# --- A : fiche de séance -------------------------------------------------------------------------------------------

static func _fenetre_a(page: Control, data: Dictionary, date: String, rang: int, actuelle: Dictionary, fermeture: Callable) -> void:
	var Mois = load("res://ui/immersive08/training_mois.gd")
	var fond := Fenetre.ouvrir(page, NOM, "CHOISIR LA SÉANCE · " + Mois._date_longue(date).to_upper(), "train", 1960, 1110, fermeture)
	_semaine(page, fond, data, date, rang, Rect2(30, 84, 1900, 200), 3)
	var famille_actuelle: String = Mois.FAMILLE_DE.get(str(actuelle.get("kind", "")), "technique")
	var famille := str(page.state.get("seance_famille", famille_actuelle))
	# Familles en onglets (pilule pleine = onglet ouvert), compteur de séances de la famille.
	var tout := catalogue(data)
	var x := 30.0
	for f: String in FAMILLES_ORDRE:
		var m: Array = Mois.FAMILLES[f]
		var n := tout.filter(func(s: Dictionary): return s.famille == f).size()
		var mot := "%s  %d" % [m[0], n]
		var largeur := Pieces.largeur_pastille(mot, m[2]) + 24
		var ouvert := f == famille
		var onglet := D.rect(fond, Rect2(x, 306, largeur, 52), m[1] if ouvert else Color(m[1], .18), Charte.RAYON_PILULE)
		onglet.name = "TrainingSessionFamily_" + f
		var ic := C.icon(m[2], 24, Charte.ENCRE if ouvert else m[1])
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		onglet.add_child(ic)
		D.place(ic, Rect2(20, 14, 24, 24))
		D.text(onglet, 54, 35, mot, 22, Charte.ENCRE if ouvert else Charte.IVOIRE, 800, largeur - 60).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var choix := f
		Pieces.rendre_cliquable(onglet, Vector2(largeur, 52), func():
			page.state.seance_famille = choix
			_rendre(page), "TrainingSessionFamilyOpen_" + f, str(m[0]), "", Charte.RAYON_PILULE)
		x += largeur + 12
	# Liste de la famille (gauche) : une ligne par séance ; clic = choisie et en place.
	var liste := D.rect(fond, Rect2(30, 378, 760, 700), Color(Charte.PANNEAU_3, .45), Charte.RAYON_CARTE)
	liste.name = "TrainingSessionList"
	var couleur_f: Color = Mois.FAMILLES[famille][1]
	var lignes := tout.filter(func(s: Dictionary): return s.famille == famille)
	for i in lignes.size():
		var s: Dictionary = lignes[i]
		var en_place: bool = s.kind == str(actuelle.get("kind", "")) and s.label == str(actuelle.get("label", ""))
		var r := Rect2(12, 12 + i * 70, 736, 62)
		var ligne := D.rect(liste, r, Color(couleur_f, .26) if en_place else (Color(Charte.IVOIRE, .03) if i % 2 == 1 else Color.TRANSPARENT), Charte.RAYON_PETIT)
		ligne.name = "TrainingSessionRow%d" % i
		D.rect(ligne, Rect2(0, 0, 6, 62), couleur_f if en_place else Color(couleur_f, .45), 3).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icone: TextureRect = Mois.icone_seance(s.kind, 36)
		icone.modulate = couleur_f
		ligne.add_child(icone)
		D.place(icone, Rect2(22, 13, 36, 36))
		D.text(ligne, 74, 40, s.label, 26, Charte.IVOIRE, 700, 380).add_theme_font_override("font", Charte.TITRE_FICHE)
		if en_place: Pieces.pastille(ligne, 600, 14, "En place", "check", "TrainingSessionInPlace", "", couleur_f)
		else:
			# Fatigue de la séance en mini-pastille (l'effet qui règle l'intensité du jour).
			var fat := int(Dictionary(data.par_seance.get(s.kind, {})).get("fatigue", 0))
			D.text(ligne, 600, 40, _signe(fat), 22, _couleur(fat, false), 800, 50, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ic := C.icon("train", 20, _couleur(fat, false))
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ligne.add_child(ic)
			D.place(ic, Rect2(660, 21, 20, 20))
		var choix_s := s
		Pieces.rendre_cliquable(ligne, r.size, func(): _choisir(page, date, rang, choix_s), "TrainingSessionPick%d" % i, s.label, "", Charte.RAYON_PETIT)
	# Fiche de la séance en place (droite) : nom, famille, effets en jauges.
	var fiche := D.rect(fond, Rect2(814, 378, 1116, 700), Color(Charte.PANNEAU_3, .45), Charte.RAYON_CARTE)
	fiche.name = "TrainingSessionSheet"
	var fam_a: Array = Mois.FAMILLES[famille_actuelle]
	D.rect(fiche, Rect2(0, 0, 1116, 96), Color(fam_a[1], .3), Charte.RAYON_CARTE).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grande: TextureRect = Mois.icone_seance(str(actuelle.get("kind", "")), 60)
	grande.modulate = fam_a[1]
	fiche.add_child(grande)
	D.place(grande, Rect2(26, 18, 60, 60))
	var titre := D.text(fiche, 104, 64, str(actuelle.get("label", "")).to_upper(), 44, Charte.IVOIRE, 800, 640)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "TrainingSessionSheetTitle"
	Pieces.pastille(fiche, 880, 30, str(fam_a[0]), str(fam_a[2]), "TrainingSessionSheetFamily", "", fam_a[1])
	var it := intensite(data, date)
	Pieces.pastille(fiche, 104, 120, "Jour : " + str(it[0]), "train", "TrainingSessionDayIntensity", "", it[1])
	if bool(actuelle.get("choisie", false)): Pieces.pastille(fiche, 104 + Pieces.largeur_pastille("Jour : " + str(it[0]), "train") + 12, 120, "Changée", "check", "TrainingSessionChanged", "", Charte.DORE)
	var effets: Dictionary = data.par_seance.get(str(actuelle.get("kind", "")), {})
	for a in AXES.size():
		var axe: Array = AXES[a]
		var v := int(effets.get(axe[0], 0))
		var y := 196.0 + a * 96.0
		D.text(fiche, 40, y + 30, str(axe[1]), 26, Charte.IVOIRE, 700, 300)
		_jauge(fiche, Rect2(330, y + 12, 520, 22), v, _max_axe(data, axe[0]), axe[2], "TrainingSessionGauge_" + str(axe[0]))
		var mot := _signe(v) + ("%" if axe[0] in ["avants", "arrieres", "cohesion"] and v != 0 else "")
		D.text(fiche, 890, y + 34, mot, 32, _couleur(v, axe[2]), 800, 180).add_theme_font_override("font", Charte.TITRE_FICHE)
		D.line(fiche, Vector2(40, y + 64), Vector2(1076, y + 64), Charte.FILET)

# --- B : tableau façon Effectif ------------------------------------------------------------------------------------

const COLONNES_B := [["label", "SÉANCE", 0.0, 380.0], ["famille", "FAMILLE", 400.0, 200.0], ["cohesion", "ORGANISATION", 620.0, 190.0], ["fatigue", "FATIGUE", 830.0, 190.0], ["condition", "CONDITION", 1040.0, 190.0], ["avants", "PROGRÈS AV.", 1250.0, 190.0], ["arrieres", "PROGRÈS AR.", 1460.0, 190.0]]

static func _fenetre_b(page: Control, data: Dictionary, date: String, rang: int, actuelle: Dictionary, fermeture: Callable) -> void:
	var Mois = load("res://ui/immersive08/training_mois.gd")
	var fond := Fenetre.ouvrir(page, NOM, "SÉANCE · " + Mois._date_longue(date).to_upper(), "train", 1760, 1110, fermeture)
	_semaine(page, fond, data, date, rang, Rect2(30, 84, 1700, 170), 2)
	# Filtres en pastilles (bandeau de l'Effectif) : Toutes + une par famille.
	var filtre := str(page.state.get("seance_filtre", ""))
	var x := 30.0
	for f: String in [""] + FAMILLES_ORDRE:
		var mot := "Toutes" if f.is_empty() else str(Mois.FAMILLES[f][0])
		var couleur: Color = Charte.IVOIRE if f.is_empty() else Mois.FAMILLES[f][1]
		var icone := "" if f.is_empty() else str(Mois.FAMILLES[f][2])
		var actif := f == filtre
		var choix := f
		var w := Pieces.pastille(fond, x, 276, mot, icone, "TrainingSessionFilter_" + (f if not f.is_empty() else "toutes"), "", Charte.ENCRE if actif else couleur, couleur if actif else Charte.PANNEAU_3)
		var pil: Control = fond.get_node("TrainingSessionFilter_" + (f if not f.is_empty() else "toutes"))
		Pieces.rendre_cliquable(pil, Vector2(w, 34), func():
			page.state.seance_filtre = choix
			_rendre(page), "TrainingSessionFilterOpen_" + (f if not f.is_empty() else "toutes"), mot, "", Charte.RAYON_PILULE)
		x += w + 10
	# En-têtes de colonnes (clic = tri, flèche sur la colonne triée).
	var tri := str(page.state.get("seance_tri", "famille"))
	var tableau := D.rect(fond, Rect2(30, 330, 1700, 750), Color(Charte.PANNEAU_3, .35), Charte.RAYON_CARTE)
	tableau.name = "TrainingSessionTable"
	D.rect(tableau, Rect2(0, 0, 1700, 46), Charte.BANDEAU_ENTETE, Charte.RAYON_CARTE).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for col: Array in COLONNES_B:
		var titre := str(col[1]) + ("  ▼" if col[0] == tri else "")
		var en_tete := D.text(tableau, 24 + float(col[2]), 31, titre, 16, Charte.IVOIRE if col[0] == tri else Charte.IVOIRE_3, 700, float(col[3]))
		en_tete.name = "TrainingSessionHead_" + str(col[0])
		var zone := Control.new()
		zone.name = "TrainingSessionHeadZone_" + str(col[0])
		tableau.add_child(zone)
		D.place(zone, Rect2(14 + float(col[2]), 4, float(col[3]) + 10, 38))
		var cle := str(col[0])
		Pieces.rendre_cliquable(zone, Vector2(float(col[3]) + 10, 38), func():
			page.state.seance_tri = cle
			_rendre(page), "TrainingSessionSort_" + cle, str(col[1]), "", Charte.RAYON_PETIT)
	var lignes := catalogue(data).filter(func(s: Dictionary): return filtre.is_empty() or s.famille == filtre)
	if tri != "famille" and tri != "label":
		var gain_si_plus := tri != "fatigue"
		lignes.sort_custom(func(a: Dictionary, b: Dictionary):
			var va := int(Dictionary(data.par_seance.get(a.kind, {})).get(tri, 0)) * (1 if gain_si_plus else -1)
			var vb := int(Dictionary(data.par_seance.get(b.kind, {})).get(tri, 0)) * (1 if gain_si_plus else -1)
			return va > vb if va != vb else str(a.label) < str(b.label))
	elif tri == "label": lignes.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.label) < str(b.label))
	var h := minf(50.0, 690.0 / maxf(1, lignes.size()))
	for i in lignes.size():
		var s: Dictionary = lignes[i]
		var fam: Array = Mois.FAMILLES[s.famille]
		var en_place: bool = s.kind == str(actuelle.get("kind", "")) and s.label == str(actuelle.get("label", ""))
		var r := Rect2(8, 52 + i * h, 1684, h - 2)
		var ligne := D.rect(tableau, r, Color(Charte.IVOIRE, .035) if i % 2 == 1 else Color.TRANSPARENT, Charte.RAYON_PETIT, Charte.IVOIRE if en_place else Color.TRANSPARENT)
		ligne.name = "TrainingSessionRow%d" % i
		var icone: TextureRect = Mois.icone_seance(s.kind, h - 18)
		icone.modulate = fam[1]
		ligne.add_child(icone)
		D.place(icone, Rect2(16, 9, h - 18, h - 18))
		D.text(ligne, h + 6, h / 2 + 9, s.label, 22, Charte.IVOIRE, 800 if en_place else 600, 250).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if en_place:
			var coche := C.icon("check", 22, Charte.DORE)
			coche.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ligne.add_child(coche)
			D.place(coche, Rect2(340, h / 2 - 12, 22, 22))
		Pieces.pastille(ligne, 412, h / 2 - 18, str(fam[0]), str(fam[2]), "TrainingSessionRowFamily%d" % i, "", fam[1])
		var effets: Dictionary = data.par_seance.get(s.kind, {})
		for col: Array in COLONNES_B.slice(2):
			var axe := str(col[0])
			var gain_si_plus := axe != "fatigue"
			var v := int(effets.get(axe, 0))
			_jauge(ligne, Rect2(16 + float(col[2]), h / 2 - 5, 110, 10), v, _max_axe(data, axe), gain_si_plus, "TrainingSessionCell_%d_%s" % [i, axe])
			D.text(ligne, 140 + float(col[2]), h / 2 + 9, _signe(v), 20, _couleur(v, gain_si_plus), 800, 60).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var choix_s := s
		var bouton := Pieces.rendre_cliquable(ligne, r.size, func(): _choisir(page, date, rang, choix_s), "TrainingSessionPick%d" % i, s.label, "", Charte.RAYON_PETIT)
		bouton.move_to_front()
