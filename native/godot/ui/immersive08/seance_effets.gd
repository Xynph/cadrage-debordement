extends RefCounted
## Fiche de séance (revue FM27, idée 25, choix A de Léo du 23/11/2026) : depuis Entraînement › Mois, clic sur une
## séance d'un jour = petite fenêtre pour la remplacer. Un clic sur une séance de la liste l'applique au jour tout de
## suite (commande moteur `calendar_session`, pas de bouton Confirmer) ; la fenêtre reste ouverte sur la séance en place.
## Données du moteur :
##  - catalogue : `calendarPlanning.sessionCatalogue` (famille + nom, séances des semaines types et des blocs) ;
##  - effets : `calendarPlanning.sessionEffects` (organisation, fatigue, condition, progrès avants / arrières, risque de
##    blessure, moral) ; ils agissent sur la séance collective de la semaine (calendar-planning.cjs, programme-semaine.cjs) ;
##  - intensité du jour : somme de la fatigue des séances du jour (match = jour de match).
## Une séance est désignée par son identifiant d'origine (`sourceId` si elle a déjà été remplacée, sinon `id`).
## Mise en page : bande de la semaine en haut, familles en onglets, liste à gauche, grande fiche avec jauges à droite.
## Entraînement ciblé (choix de Léo du 24/11/2026) : chaque séance ne fait progresser que son groupe de qualités
## (`sessionQualities` par séance et `qualites` du catalogue : avants / arrières, calendar-planning.cjs). La fiche montre ce groupe (chevrons verts, sans chiffre :
## tendance seulement) ; le survol d'une ligne de la liste le montre aussi, avant de la choisir.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Agenda = preload("res://ui/immersive08/calendar_agenda.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")
const Fleches = preload("res://ui/fleches_progression.gd")
const Bulle = preload("res://ui/bulle_survol.gd")

const NOM := "TrainingSessionWindow"
const FAMILLES_ORDRE := ["intensif", "technique", "tactique", "recuperation"]
## Effet → [libellé, plus = gain ?, suffixe] (fatigue et risque : plus = coût).
const AXES := [
	["cohesion", "Organisation", true, "%"],
	["fatigue", "Fatigue", false, ""],
	["condition", "Condition", true, ""],
	["avants", "Progrès avants", true, "%"],
	["arrieres", "Progrès arrières", true, "%"],
	["blessure", "Risque de blessure", false, ""],
	["moral", "Moral", true, ""],
]

## Identifiant d'origine d'une séance (stable quand on la remplace).
static func source(s: Dictionary) -> String:
	return str(s.get("sourceId", s.get("id", "")))

## Catalogue : chaque séance au choix (famille, nom), dans l'ordre des familles puis des noms.
static func catalogue(page: Control) -> Array:
	var Mois = load("res://ui/immersive08/training_mois.gd")
	var planning: Variant = page.app.model.get("calendarPlanning", {})
	var brut: Variant = planning.get("sessionCatalogue", []) if planning is Dictionary else []
	var sortie: Array = []
	for item: Variant in brut if brut is Array else []:
		if not item is Dictionary: continue
		sortie.append({"kind": str(item.get("kind", "")), "label": str(item.get("label", "")), "famille": Mois.FAMILLE_DE.get(str(item.get("kind", "")), "technique"), "qualites": item.get("qualites", {}) if item.get("qualites") is Dictionary else {}})
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

## Ouvre la fenêtre pour la séance `id` (identifiant d'origine) du jour `date`.
static func ouvrir(page: Control, date: String, id: String) -> void:
	page.state.seance_cible = {"date": date, "id": id}
	page.state.erase("seance_famille")
	rendre(page)

## Rend la fenêtre si une séance est visée (appelé aussi après chaque réponse du moteur : l'onglet est reconstruit).
static func rendre(page: Control) -> void:
	var Mois = load("res://ui/immersive08/training_mois.gd")
	var data: Dictionary = Mois._donnees(page)
	var cible: Dictionary = page.state.get("seance_cible", {})
	var date := str(cible.get("date", ""))
	var du_jour: Array = data.seances.get(date, [])
	var rang := -1
	for i in du_jour.size():
		if source(du_jour[i]) == str(cible.get("id", "")): rang = i
	if rang < 0:
		page.state.erase("seance_cible")
		return
	var fermeture := func():
		page.state.erase("seance_cible")
		page._open_tab(page.active_tab)
	_fenetre(page, data, date, rang, du_jour[rang], fermeture)

## Séance encore modifiable : à venir, hors match en direct, et pas dans la semaine dont la séance collective est faite.
static func modifiable(page: Control, data: Dictionary, s: Dictionary) -> bool:
	if bool(s.get("completed", false)) or not page.app._live().is_empty(): return false
	var today := str(data.today)
	if today.is_empty() or str(s.get("date", "")) < today: return false
	if bool(page.app.model.get("meta", {}).get("trained", false)) and Agenda.week(str(s.get("date", "")))[0] == Agenda.week(today)[0]: return false
	return true

## Un clic = la séance choisie remplace celle du jour (commande moteur), sans confirmation.
static func _choisir(page: Control, actuelle: Dictionary, s: Dictionary) -> void:
	page.app._command("calendar_session", {"sessionId": source(actuelle), "kind": str(s.kind), "label": str(s.label)})

# --- Bande de la semaine ----------------------------------------------------------------------------------------------

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
		if not str(data.today).is_empty() and d < str(data.today): cadre.modulate = Color(1, 1, 1, .6)
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
			var cible_id := source(cr[2])
			Pieces.rendre_cliquable(bloc, rc.size, func(): ouvrir(page, cible_date, cible_id), "TrainingSessionSlotOpen_%s_%d" % [d, rang_seance], str(cr[1]), "", Charte.RAYON_PETIT)
			rang_seance += 1
		# Bande d'intensité du jour : rail + remplissage coloré + mot.
		var it := intensite(data, d)
		var y_bande := zone.size.y - 30
		var rail := D.rect(cadre, Rect2(112, y_bande, largeur - 124, 12), Charte.FILET, Charte.RAYON_PILULE)
		rail.name = "TrainingSessionIntensity_" + d
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.rect(rail, Rect2(0, 0, (largeur - 124) * float(it[2]), 12), it[1], Charte.RAYON_PILULE).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(cadre, 12, y_bande + 13, str(it[0]), 16, it[1], 700, 96).mouse_filter = Control.MOUSE_FILTER_IGNORE

## Jauge centrée : zéro au milieu, gain vert vers la droite, coût rouge vers la gauche.
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

## Petit chiffre signé + icône dans une ligne de la liste (fatigue, risque).
static func _mini(parent: Control, x: float, v: int, gain_si_plus: bool, icone: String, id: String) -> void:
	var ic := C.icon(icone, 20, _couleur(v, gain_si_plus))
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ic)
	D.place(ic, Rect2(x, 21, 20, 20))
	var t := D.text(parent, x + 28, 40, _signe(v), 22, _couleur(v, gain_si_plus), 800, 50)
	t.name = id
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE

# --- Fenêtre ----------------------------------------------------------------------------------------------------------

static func _fenetre(page: Control, data: Dictionary, date: String, rang: int, actuelle: Dictionary, fermeture: Callable) -> void:
	var Mois = load("res://ui/immersive08/training_mois.gd")
	var fond := Fenetre.ouvrir(page, NOM, "CHOISIR LA SÉANCE · " + Mois._date_longue(date).to_upper(), "train", 1960, 1110, fermeture)
	_semaine(page, fond, data, date, rang, Rect2(30, 84, 1900, 200), 3)
	var ouvert_au_choix := modifiable(page, data, actuelle)
	var famille_actuelle: String = Mois.FAMILLE_DE.get(str(actuelle.get("kind", "")), "technique")
	var famille := str(page.state.get("seance_famille", famille_actuelle))
	# Familles en onglets (pilule pleine = onglet ouvert), compteur de séances de la famille.
	var tout := catalogue(page)
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
			rendre(page), "TrainingSessionFamilyOpen_" + f, str(m[0]), "", Charte.RAYON_PILULE)
		x += largeur + 12
	# Liste de la famille (gauche), façon Effectif : une ligne par séance, rayures, fatigue et risque en chiffres
	# colorés ; clic = la séance remplace celle du jour, tout de suite.
	var liste := D.rect(fond, Rect2(30, 378, 760, 700), Color(Charte.PANNEAU_3, .45), Charte.RAYON_CARTE)
	liste.name = "TrainingSessionList"
	var couleur_f: Color = Mois.FAMILLES[famille][1]
	var entete := D.rect(liste, Rect2(0, 0, 760, 44), Charte.BANDEAU_ENTETE, Charte.RAYON_CARTE)
	entete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	D.text(entete, 74, 29, "SÉANCE", 16, Charte.IVOIRE_3, 700, 200).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for col: Array in [[560.0, "FATIGUE"], [662.0, "RISQUE"]]:
		D.text(entete, col[0], 29, col[1], 16, Charte.IVOIRE_3, 700, 100).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lignes := tout.filter(func(s: Dictionary): return s.famille == famille)
	for i in lignes.size():
		var s: Dictionary = lignes[i]
		var en_place: bool = s.kind == str(actuelle.get("kind", "")) and s.label == str(actuelle.get("label", ""))
		var r := Rect2(12, 54 + i * 70, 736, 62)
		var ligne := D.rect(liste, r, Color(couleur_f, .26) if en_place else (Color(Charte.IVOIRE, .03) if i % 2 == 1 else Color.TRANSPARENT), Charte.RAYON_PETIT)
		ligne.name = "TrainingSessionRow%d" % i
		D.rect(ligne, Rect2(0, 0, 6, 62), couleur_f if en_place else Color(couleur_f, .45), 3).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icone: TextureRect = Mois.icone_seance(s.kind, 36)
		icone.modulate = couleur_f
		ligne.add_child(icone)
		D.place(icone, Rect2(22, 13, 36, 36))
		D.text(ligne, 74, 40, s.label, 26, Charte.IVOIRE, 700, 290).add_theme_font_override("font", Charte.TITRE_FICHE)
		if en_place: Pieces.pastille(ligne, 384, 14, "En place", "check", "TrainingSessionInPlace", "", couleur_f)
		var effets: Dictionary = data.par_seance.get(s.kind, {})
		_mini(ligne, 548, int(effets.get("fatigue", 0)), false, "train", "TrainingSessionRowFatigue%d" % i)
		_mini(ligne, 650, int(effets.get("blessure", 0)), false, "warning", "TrainingSessionRowRisk%d" % i)
		var cible_survol: Control = ligne
		if ouvert_au_choix and not en_place:
			var choix_s := s
			cible_survol = Pieces.rendre_cliquable(ligne, r.size, func(): _choisir(page, actuelle, choix_s), "TrainingSessionPick%d" % i, s.label, "", Charte.RAYON_PETIT)
		var groupe_s: Dictionary = s.get("qualites", {})
		var titre_s := str(s.label)
		var couleur_s := couleur_f
		Bulle.lier(cible_survol, "seance:%s|%s" % [s.kind, s.label], func(): return _bulle_qualites(titre_s, groupe_s, couleur_s))
	# Fiche de la séance en place (droite) : nom, famille, intensité du jour, effets en jauges vert = gain / rouge = coût.
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
	var xp := 104.0
	xp += Pieces.pastille(fiche, xp, 112, "Jour : " + str(it[0]), "train", "TrainingSessionDayIntensity", "", it[1]) + 12
	if bool(actuelle.get("swapped", false)): xp += Pieces.pastille(fiche, xp, 112, "Changée", "renew", "TrainingSessionChanged", "", Charte.DORE) + 12
	if not ouvert_au_choix: Pieces.pastille(fiche, xp, 112, "Faite" if bool(actuelle.get("completed", false)) else "Verrouillée", "lock", "TrainingSessionLocked", "", Charte.IVOIRE_3)
	var effets_a: Dictionary = data.par_seance.get(str(actuelle.get("kind", "")), {})
	for a in AXES.size():
		var axe: Array = AXES[a]
		var v := int(effets_a.get(axe[0], 0))
		var y := 150.0 + a * 50.0
		D.text(fiche, 40, y + 30, str(axe[1]), 26, Charte.IVOIRE, 700, 300)
		_jauge(fiche, Rect2(360, y + 12, 500, 22), v, _max_axe(data, axe[0]), axe[2], "TrainingSessionGauge_" + str(axe[0]))
		var mot := _signe(v) + (str(axe[3]) if v != 0 else "")
		D.text(fiche, 890, y + 34, mot, 32, _couleur(v, axe[2]), 800, 180).add_theme_font_override("font", Charte.TITRE_FICHE)
		D.line(fiche, Vector2(40, y + 46), Vector2(1076, y + 46), Charte.FILET)
	# Qualités travaillées par la séance en place (avants / arrières), sans chiffre.
	var par_id: Variant = page.app.model.get("calendarPlanning", {}).get("sessionQualities", {})
	_qualites(fiche, Rect2(40, 510, 1036, 184), par_id.get(str(actuelle.get("id", "")), {}) if par_id is Dictionary else {}, "TrainingSessionQualities")

# --- Qualités travaillées ---------------------------------------------------------------------------------------------

## Libellé d'une qualité (36 qualités de la fiche joueur).
static func libelle_qualite(cle: String) -> String:
	for groupe: Array in PlayerAttributes.GROUPS:
		for pair: Array in groupe[1]:
			if str(pair[0]) == cle: return str(pair[1])
	return cle

## Puce d'une qualité travaillée : chevron vert (tendance, sans chiffre) + nom. Renvoie sa largeur.
static func _puce(parent: Control, x: float, y: float, cle: String, id: String) -> float:
	var mot := libelle_qualite(cle)
	var largeur := largeur_puce(cle)
	var pilule := D.rect(parent, Rect2(x, y, largeur, 40), Color(Charte.GAIN, .18), Charte.RAYON_PILULE)
	pilule.name = id
	pilule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chevron := Fleches.Fleche.new()
	chevron.cran = 1
	pilule.add_child(chevron)
	D.place(chevron, Rect2(13, 5, 20, 30))
	D.text(pilule, 40, 28, mot, 20, Charte.IVOIRE, 700, largeur - 44).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return largeur

static func largeur_puce(cle: String) -> float:
	return C.font(700).get_string_size(libelle_qualite(cle), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(20))).x / C.density + 58

## Lignes « Avants » / « Arrières » (une seule « Qualités » si identiques), puces à la suite, retour à la ligne quand
## la place manque ; « Aucune qualité travaillée » si rien n'est travaillé (récupération).
static func _qualites(parent: Control, zone: Rect2, groupe: Variant, id: String) -> void:
	var g: Dictionary = groupe if groupe is Dictionary else {}
	var avants: Array = g.get("avants", []) if g.get("avants") is Array else []
	var arrieres: Array = g.get("arrieres", []) if g.get("arrieres") is Array else []
	var cadre := Control.new()
	cadre.name = id
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cadre)
	D.place(cadre, zone)
	var lignes: Array = []
	if avants == arrieres: lignes.append(["QUALITÉS", avants])
	else:
		if not avants.is_empty(): lignes.append(["AVANTS", avants])
		if not arrieres.is_empty(): lignes.append(["ARRIÈRES", arrieres])
	if lignes.is_empty() or (lignes.size() == 1 and (lignes[0][1] as Array).is_empty()):
		var repos := D.text(cadre, 0, 30, "Aucune qualité travaillée", 22, Charte.IVOIRE_3, 700, zone.size.x)
		repos.name = id + "None"
		return
	var y := 0.0
	for ligne: Array in lignes:
		D.text(cadre, 0, y + 27, str(ligne[0]), 17, Charte.IVOIRE_3, 700, 130).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var x := 130.0
		for cle: Variant in ligne[1]:
			var l := largeur_puce(str(cle))
			if x + l > zone.size.x and x > 130.0:
				x = 130.0
				y += 46.0
			x += _puce(cadre, x, y, str(cle), "%s_%s_%s" % [id, str(ligne[0]).left(3), str(cle)]) + 10
		y += 46.0

## Bulle au survol d'une ligne de la liste : nom de la séance et qualités qu'elle travaille.
static func _bulle_qualites(titre: String, groupe: Dictionary, couleur: Color) -> Control:
	var bulle := Panel.new()
	bulle.add_theme_stylebox_override("panel", Charte.ombrer(Charte.style_panneau(Charte.PANNEAU, Charte.RAYON_CARTE, 0)))
	var taille := Vector2(1000, 250)
	bulle.custom_minimum_size = taille * C.density
	bulle.size = bulle.custom_minimum_size
	D.rect(bulle, Rect2(0, 0, 8, taille.y), couleur, 4).mouse_filter = Control.MOUSE_FILTER_IGNORE
	D.text(bulle, 28, 38, titre.to_upper(), 20, Charte.IVOIRE, 800, 860).add_theme_font_override("font", Charte.TITRE_FICHE)
	_qualites(bulle, Rect2(28, 62, 950, 184), groupe, "TrainingSessionHoverQualities")
	return bulle
