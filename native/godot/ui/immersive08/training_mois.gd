extends RefCounted
## Plan d'entraînement › Mois (planche FM27 n° 6 « calendrier d'entraînement du mois », 22/11/2026, NON intégrée :
## l'onglet n'existe que sous CD_VARIANTE_VISUELLE=A|B ; sans la variable, l'écran reste celui de main).
## Données du moteur, rien d'inventé :
##  - séances du jour : `calendarPlanning.sessions` (programme du staff, plusieurs séances par jour : force, ateliers
##    mêlée/touche, vidéo, jeu au pied, mise en place, activation, récupération) ;
##  - matchs : `calendarPlanning.fixtures` / `calendar` (dates du calendrier réel) ;
##  - semaine type : le modèle de chaque match (`calendarPlanning.programmeByFixture`, choisi ou proposé par le staff ;
##    standard, long déplacement, matchs rapprochés, reprise) ; « Coller » = commande moteur `calendar_template` ;
##  - charge : la séance collective de la semaine (`meta.training`, une par semaine, la seule simulée).
## A : semaines en LIGNES façon Effectif (bande des 7 jours en créneaux colorés, match, modèle, charge, copier/coller).
## B : GRILLE du mois (7 colonnes, 3 créneaux par jour), colonne de gauche par semaine (modèle, charge, copier/coller).
## Coordonnées en unités du gabarit (toile 2248 × 1230). `page` : la toile de l'entraînement (training_canvas.gd).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Agenda = preload("res://ui/immersive08/calendar_agenda.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const SurvolLigne = preload("res://ui/survol_ligne.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")
const Mensuel = preload("res://ui/immersive08/month_calendar.gd")

const MOIS := ["JANVIER", "FÉVRIER", "MARS", "AVRIL", "MAI", "JUIN", "JUILLET", "AOÛT", "SEPTEMBRE", "OCTOBRE", "NOVEMBRE", "DÉCEMBRE"]
const JOURS := ["LUN", "MAR", "MER", "JEU", "VEN", "SAM", "DIM"]
## Famille de séance → [mot, couleur franche] (type et intensité : couleur jamais seule, toujours icône ou mot).
const FAMILLES := {
	"intensif": ["Intensif", Charte.INTENSIF],
	"technique": ["Technique", Charte.GAIN],
	"tactique": ["Tactique", Charte.MORAL],
	"recuperation": ["Récupération", Charte.REPOS],
	"match": ["Match", Charte.IVOIRE],
}
const FAMILLE_DE := {"strength": "intensif", "speed": "intensif", "team": "technique", "skills": "technique", "kicking": "technique", "tactics": "tactique", "video": "tactique", "recovery": "recuperation"}
## Modèle de semaine → [mot court, couleur, icône].
const MODELES := {
	"standard": ["Standard", Charte.GAIN, "calendar"],
	"away": ["Déplacement", Charte.MORAL, "bus"],
	"congested": ["Rapprochés", Charte.INTENSIF, "clock"],
	"break": ["Reprise", Charte.REPOS, "renew"],
}
const CHARGES := {"repos": ["Repos", Charte.REPOS], "normal": ["Normale", Charte.NORMAL], "intense": ["Intensive", Charte.INTENSIF]}
const HAUT := 250.0
const BAS := 1217.0

static func variante() -> String:
	return OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()

static func active() -> bool:
	return variante() in ["A", "B"]

# --- Données ---------------------------------------------------------------------------------------------------------

static func _donnees(page: Control) -> Dictionary:
	var app: Control = page.app
	var planning: Dictionary = app.model.get("calendarPlanning", {}) if app.model.get("calendarPlanning") is Dictionary else {}
	var today := str(planning.get("today", app.model.get("meta", {}).get("calendarToday", "")))
	if not Agenda.valid_date(today): today = ""
	var club_id: Variant = app.model.get("club", {}).get("id")
	var matchs := {}
	for f: Dictionary in Agenda.unique_fixtures(planning.get("fixtures", app.model.get("calendar", []))):
		var date := str(f.get("date", ""))
		if not Agenda.valid_date(date): continue
		if club_id != null and f.get("home", {}).get("id") != club_id and f.get("away", {}).get("id") != club_id: continue
		matchs[date] = f
	var seances := {}
	for s: Variant in planning.get("sessions", []):
		if not s is Dictionary: continue
		var date := str(s.get("date", ""))
		if not Agenda.valid_date(date): continue
		if not seances.has(date): seances[date] = []
		seances[date].append(s)
	var modeles := {}
	for t: Variant in planning.get("templates", []):
		if t is Dictionary: modeles[str(t.get("id", ""))] = str(t.get("label", ""))
	var base := today if not today.is_empty() else str(matchs.keys().min() if not matchs.is_empty() else "")
	var decalage := int(page.state.get("mois_decalage", 0))
	var annee := 2026
	var mois := 1
	if Agenda.valid_date(base):
		annee = base.substr(0, 4).to_int()
		mois = base.substr(5, 2).to_int()
	mois += decalage
	while mois > 12:
		mois -= 12
		annee += 1
	while mois < 1:
		mois += 12
		annee -= 1
	var premier := "%04d-%02d-01" % [annee, mois]
	var dernier := "%04d-%02d-%02d" % [annee, mois, Mensuel._month_length(annee, mois)]
	var semaines: Array = []
	var lundi: String = Agenda.week(premier)[0]
	while not lundi.is_empty() and lundi <= dernier:
		semaines.append(_semaine(page, Agenda.week(lundi), matchs, planning, today))
		lundi = Agenda.shift(lundi, 7)
	return {"today": today, "matchs": matchs, "seances": seances, "modeles": modeles, "semaines": semaines,
		"titre": "%s %d" % [MOIS[mois - 1], annee], "mois": "%04d-%02d" % [annee, mois], "club_id": club_id,
		"charge": str(app.model.get("meta", {}).get("training", "normal"))}

## Une semaine : ses 7 dates, son match (le premier de la semaine), le modèle en vigueur et si on peut encore le changer.
static func _semaine(page: Control, dates: Array, matchs: Dictionary, planning: Dictionary, today: String) -> Dictionary:
	var fixture := {}
	for d: String in dates:
		if matchs.has(d):
			fixture = matchs[d]
			break
	var modele := ""
	if not fixture.is_empty(): modele = str(planning.get("programmeByFixture", {}).get(str(fixture.get("id", "")), ""))
	var passee := not today.is_empty() and str(dates[6]) < today
	var courante := not today.is_empty() and today in dates
	var modifiable: bool = not fixture.is_empty() and not bool(fixture.get("played", false)) and not today.is_empty() \
		and str(fixture.get("date", "")) >= today and page.app._live().is_empty()
	return {"dates": dates, "fixture": fixture, "modele": modele, "passee": passee, "courante": courante, "modifiable": modifiable}

## Créneaux d'un jour (3 au plus) : [famille, libellé, séance ou match]. Match d'abord, puis les séances du staff.
static func _creneaux(data: Dictionary, date: String) -> Array:
	var sortie: Array = []
	if data.matchs.has(date): sortie.append(["match", "", data.matchs[date]])
	for s: Dictionary in data.seances.get(date, []):
		if sortie.size() >= 3: break
		sortie.append([FAMILLE_DE.get(str(s.get("kind", "")), "technique"), str(s.get("label", "")), s])
	return sortie

static func _adversaire(data: Dictionary, f: Dictionary) -> Dictionary:
	return f.get("away", {}) if f.get("home", {}).get("id") == data.club_id else f.get("home", {})

static func _lieu(data: Dictionary, f: Dictionary) -> String:
	if bool(f.get("neutral", false)): return "NEU"
	return "DOM" if f.get("home", {}).get("id") == data.club_id else "EXT"

static func _score(f: Dictionary) -> String:
	var s: Variant = f.get("score")
	if s is Array and s.size() == 2: return "%d-%d" % [int(s[0]), int(s[1])]
	return ""

static func _court(club: Dictionary) -> String:
	var abbr := str(club.get("abbr", ""))
	if not abbr.is_empty() and abbr.length() <= 5: return abbr.to_upper()
	var nom := G.club_name(club)
	return nom.substr(0, 10)

# --- Entrée ----------------------------------------------------------------------------------------------------------

static func construire(page: Control) -> void:
	var data := _donnees(page)
	_barre(page, data)
	if variante() == "B": _grille(page, data)
	else: _lignes(page, data)

## Barre du mois : ◀ MOIS ANNÉE ▶, aujourd'hui, légende des créneaux (icône + mot), semaine copiée.
static func _barre(page: Control, data: Dictionary) -> void:
	_bouton(page, Rect2(4, HAUT, 52, 46), "◀", "TrainingMonthPrev", func(): _decaler(page, -1))
	_bouton(page, Rect2(64, HAUT, 52, 46), "▶", "TrainingMonthNext", func(): _decaler(page, 1))
	var titre := D.text(page, 134, HAUT + 39, data.titre, 40, Charte.IVOIRE, 700, 330)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "TrainingMonthTitle"
	var x := 480.0
	if int(page.state.get("mois_decalage", 0)) != 0:
		x += Pieces.pastille(page, x, HAUT + 6, "Aujourd'hui", "calendar", "TrainingMonthToday", "", Charte.IVOIRE, Charte.PANNEAU_3, func(): _decaler(page, 0)) + 12
	# Légende : une pastille par famille (clic = petite fenêtre des séances de cette famille sur le mois).
	var gauche := 2244.0
	var copie := str(page.state.get("modele_copie", ""))
	var legendes: Array = []
	for k: String in ["intensif", "technique", "tactique", "recuperation", "match"]:
		legendes.append(k)
	var largeurs := 0.0
	for k: String in legendes: largeurs += Pieces.largeur_pastille(FAMILLES[k][0], _icone_famille(k)) + 10
	if not copie.is_empty(): largeurs += Pieces.largeur_pastille("Copiée · " + str(MODELES.get(copie, [copie])[0]), "check") + 24
	x = maxf(x + 20, gauche - largeurs)
	if not copie.is_empty():
		x += Pieces.pastille(page, x, HAUT + 6, "Copiée · " + str(MODELES.get(copie, [copie])[0]), "check", "TrainingMonthCopied", "", MODELES.get(copie, ["", Charte.IVOIRE])[1], Charte.PANNEAU_3, func(): _fenetre_modele(page, data, {}, copie)) + 24
	for k: String in legendes:
		var famille := k
		x += Pieces.pastille(page, x, HAUT + 6, FAMILLES[k][0], _icone_famille(k), "TrainingMonthLegend_" + k, "", FAMILLES[k][1], Charte.PANNEAU_3, func(): _fenetre_famille(page, data, famille)) + 10

static func _icone_famille(k: String) -> String:
	return {"intensif": "train", "technique": "people", "tactique": "tactic", "recuperation": "heart", "match": "ball"}.get(k, "")

static func _decaler(page: Control, sens: int) -> void:
	page.state.mois_decalage = 0 if sens == 0 else int(page.state.get("mois_decalage", 0)) + sens
	page._open_tab(page.active_tab)

# --- Option A : semaines en lignes -----------------------------------------------------------------------------------

const A_COLS := {"semaine": 18.0, "jours": 190.0, "match": 1262.0, "modele": 1610.0, "charge": 1798.0, "actions": 1950.0}
const A_JOUR := 153.0

static func _lignes(page: Control, data: Dictionary) -> void:
	var zone := Rect2(4, HAUT + 62, 2244, BAS - HAUT - 62)
	var panneau := D.panel(page, zone, "", "", "", "TrainingMonthTable")
	var entete := Panel.new()
	entete.name = "TrainingMonthHeader"
	entete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Bandeau.peindre_entete(entete)
	panneau.add_child(entete)
	D.place(entete, Rect2(0, 0, zone.size.x, 46))
	D.text(entete, A_COLS.semaine, 30, "SEMAINE", 17, Charte.IVOIRE_3, 700, 160).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for j in 7:
		D.text(entete, A_COLS.jours + j * A_JOUR, 30, JOURS[j], 17, Charte.IVOIRE_3, 700, A_JOUR - 8, HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for col: Array in [["MATCH", A_COLS.match], ["SEMAINE TYPE", A_COLS.modele], ["CHARGE", A_COLS.charge]]:
		D.text(entete, col[1], 30, col[0], 17, Charte.IVOIRE_3, 700, 240).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var semaines: Array = data.semaines
	var h := minf(156.0, (zone.size.y - 56) / maxf(1, semaines.size()))
	for i in semaines.size():
		var ligne := Control.new()
		ligne.name = "TrainingMonthRow%d" % i
		panneau.add_child(ligne)
		D.place(ligne, Rect2(8, 52 + i * h, zone.size.x - 16, h - 2))
		SurvolLigne.poser(ligne)
		D.line(ligne, Vector2(0, h - 2), Vector2(zone.size.x - 16, h - 2), Charte.FILET)
		_ligne(page, data, ligne, semaines[i], i, h - 2)

static func _ligne(page: Control, data: Dictionary, ligne: Control, s: Dictionary, i: int, h: float) -> void:
	var dates: Array = s.dates
	var milieu := h / 2.0
	if bool(s.passee): ligne.modulate = Color(1, 1, 1, .6)
	# Semaine : numéro du lundi au dimanche ; la semaine en cours porte un liseré crème.
	if bool(s.courante): D.rect(ligne, Rect2(2, milieu - 26, 5, 52), Charte.IVOIRE, 3).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := D.text(ligne, A_COLS.semaine, milieu - 2, "%s → %s" % [_jj(dates[0]), _jj(dates[6])], 28, Charte.IVOIRE, 700, 170)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var etat := "En cours" if bool(s.courante) else "Passée" if bool(s.passee) else ""
	if not etat.is_empty(): Pieces.pastille(ligne, A_COLS.semaine, milieu + 10, etat, "clock" if bool(s.courante) else "check", "TrainingMonthWeekState%d" % i, "", Charte.IVOIRE if bool(s.courante) else Charte.IVOIRE_2)
	# Bande des 7 jours : par jour, jusqu'à 3 créneaux empilés (couleur = type/intensité), match en crème avec blason.
	for j in 7:
		var date: String = dates[j]
		var r := Rect2(A_COLS.jours + j * A_JOUR, 10, A_JOUR - 10, h - 20)
		var hors_mois := not date.begins_with(str(data.mois))
		var cadre := D.rect(ligne, r, Charte.PANNEAU_3 if not hors_mois else Color(Charte.PANNEAU_3, .4), Charte.RAYON_PETIT, Charte.IVOIRE if date == data.today else Color.TRANSPARENT)
		cadre.name = "TrainingMonthDay_%s" % date
		cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(cadre, 8, 22, str(date.substr(8, 2).to_int()), 17, Charte.IVOIRE_2 if not hors_mois else Charte.IVOIRE_3, 700, 30).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var creneaux := _creneaux(data, date)
		var hc := minf(26.0, (r.size.y - 34) / 3.0 - 4)
		for k in creneaux.size():
			var cr: Array = creneaux[k]
			var y := 30.0 + k * (hc + 4)
			if cr[0] == "match":
				var adv := _adversaire(data, cr[2])
				var bloc := D.rect(cadre, Rect2(6, y, r.size.x - 12, hc), Charte.IVOIRE, Charte.RAYON_PETIT)
				bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var crest := G.crest(adv, C.px(hc - 4))
				crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
				bloc.add_child(crest)
				D.place(crest, Rect2(3, 2, hc - 4, hc - 4))
				D.text(bloc, hc + 2, hc - 7, _court(adv), 16, Charte.ENCRE, 800, r.size.x - hc - 18).mouse_filter = Control.MOUSE_FILTER_IGNORE
			else:
				var couleur: Color = FAMILLES[cr[0]][1]
				var bloc := D.rect(cadre, Rect2(6, y, r.size.x - 12, hc), Color(couleur, .9), Charte.RAYON_PETIT)
				bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var icone := Mensuel._session_icon(str(cr[2].get("kind", "")))
				icone.modulate = Color(0.05, 0.08, 0.09)
				bloc.add_child(icone)
				D.place(icone, Rect2(5, 3, hc - 6, hc - 6))
				D.text(bloc, hc + 2, hc - 7, str(cr[1]), 15, Charte.ENCRE, 700, r.size.x - hc - 18).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var jour := date
		Pieces.rendre_cliquable(cadre, r.size, func(): _fenetre_jour(page, data, jour), "TrainingMonthDayOpen_%s" % date, _date_longue(date), "", Charte.RAYON_PETIT)
	# Match de la semaine : blason, adversaire, lieu, score ; clic = préparation (à venir) ou fiche du club.
	var f: Dictionary = s.fixture
	if f.is_empty():
		Pieces.pastille(ligne, A_COLS.match, milieu - 17, "Sans match", "calendar", "TrainingMonthNoMatch%d" % i, "", Charte.IVOIRE_3)
	else:
		var adv := _adversaire(data, f)
		var crest := G.crest(adv, C.px(52))
		crest.name = "TrainingMonthCrest%d" % i
		ligne.add_child(crest)
		D.place(crest, Rect2(A_COLS.match, milieu - 26, 52, 52))
		var nom := D.text(ligne, A_COLS.match + 64, milieu - 2, G.club_name(adv), 24, Charte.IVOIRE, 700, 300)
		nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var x := A_COLS.match + 64
		x += Pieces.pastille(ligne, x, milieu + 8, _lieu(data, f), {"DOM": "home", "EXT": "bus", "NEU": "flag"}[_lieu(data, f)], "TrainingMonthPlace%d" % i, "", Charte.IVOIRE_2) + 8
		# Match joué : le score remplace la date.
		var score := _score(f)
		if score.is_empty(): Pieces.pastille(ligne, x, milieu + 8, _jour_court(str(f.get("date", ""))), "calendar", "TrainingMonthDate%d" % i, "", Charte.IVOIRE_2)
		else: Pieces.pastille(ligne, x, milieu + 8, score, "check", "TrainingMonthScore%d" % i, "", Charte.IVOIRE)
		var fixture := f
		var zone_match := Control.new()
		zone_match.name = "TrainingMonthMatchZone%d" % i
		ligne.add_child(zone_match)
		D.place(zone_match, Rect2(A_COLS.match - 6, 6, 340, 50))
		Pieces.rendre_cliquable(zone_match, Vector2(340, 50), func(): _ouvrir_match(page, data, fixture), "TrainingMonthMatch%d" % i, G.club_name(adv), "", Charte.RAYON_PETIT)
	# Semaine type : pastille du modèle (clic = petite fenêtre des 4 modèles) ; copier / coller.
	if not str(s.modele).is_empty():
		var m: Array = MODELES.get(str(s.modele), [str(s.modele), Charte.IVOIRE, "calendar"])
		var semaine := s
		Pieces.pastille(ligne, A_COLS.modele, milieu - 17, m[0], m[2], "TrainingMonthModel%d" % i, "", m[1], Charte.PANNEAU_3, func(): _fenetre_modele(page, data, semaine, ""))
	else:
		D.text(ligne, A_COLS.modele + 10, milieu + 8, "—", 24, Charte.IVOIRE_3, 600, 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charge(page, data, ligne, s, Vector2(A_COLS.charge, milieu - 17), i)
	_copier_coller(page, data, ligne, s, Vector2(A_COLS.actions, milieu - 22), i, false)

# --- Option B : grille du mois ---------------------------------------------------------------------------------------

const B_GAUCHE := 330.0

static func _grille(page: Control, data: Dictionary) -> void:
	var zone := Rect2(4, HAUT + 62, 2244, BAS - HAUT - 62)
	var panneau := D.panel(page, zone, "", "", "", "TrainingMonthGrid")
	var entete := Panel.new()
	entete.name = "TrainingMonthHeader"
	entete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Bandeau.peindre_entete(entete)
	panneau.add_child(entete)
	D.place(entete, Rect2(0, 0, zone.size.x, 46))
	var largeur_jour := (zone.size.x - B_GAUCHE - 12) / 7.0
	D.text(entete, 18, 30, "SEMAINE TYPE", 17, Charte.IVOIRE_3, 700, 200).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for j in 7:
		D.text(entete, B_GAUCHE + j * largeur_jour, 30, JOURS[j], 17, Charte.IVOIRE_3, 700, largeur_jour - 8, HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var semaines: Array = data.semaines
	var h := minf(160.0, (zone.size.y - 56) / maxf(1, semaines.size()))
	for i in semaines.size():
		var s: Dictionary = semaines[i]
		var y := 52.0 + i * h
		# Colonne de gauche : la semaine type (modèle du match), la charge collective, copier / coller.
		var gauche := Control.new()
		gauche.name = "TrainingMonthWeek%d" % i
		gauche.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panneau.add_child(gauche)
		D.place(gauche, Rect2(8, y, B_GAUCHE - 20, h - 6))
		D.rect(gauche, Rect2(0, 0, B_GAUCHE - 20, h - 6), Charte.PANNEAU_3 if bool(s.courante) else Color(Charte.PANNEAU_3, .5), Charte.RAYON_CARTE).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if bool(s.passee): gauche.modulate = Color(1, 1, 1, .6)
		if not str(s.modele).is_empty():
			var m: Array = MODELES.get(str(s.modele), [str(s.modele), Charte.IVOIRE, "calendar"])
			var semaine := s
			Pieces.pastille(gauche, 12, 12, m[0], m[2], "TrainingMonthModel%d" % i, "", m[1], Charte.PANNEAU_3, func(): _fenetre_modele(page, data, semaine, ""))
		else:
			Pieces.pastille(gauche, 12, 12, "Sans match", "calendar", "TrainingMonthNoMatch%d" % i, "", Charte.IVOIRE_3)
		_barre_charge(page, data, gauche, s, Rect2(14, 58, B_GAUCHE - 48, 12), i)
		_copier_coller(page, data, gauche, s, Vector2(12, h - 58), i, true)
		for j in 7:
			_jour_b(page, data, panneau, s, Rect2(B_GAUCHE + j * largeur_jour, y, largeur_jour - 8, h - 6), j)

static func _jour_b(page: Control, data: Dictionary, panneau: Control, s: Dictionary, r: Rect2, j: int) -> void:
	var date: String = s.dates[j]
	var hors_mois := not date.begins_with(str(data.mois))
	var aujourdhui: bool = date == data.today
	var cadre := D.rect(panneau, r, Color(Charte.PANNEAU_3, .55 if not hors_mois else .2), Charte.RAYON_PETIT, Charte.IVOIRE if aujourdhui else Color.TRANSPARENT)
	cadre.name = "TrainingMonthDay_%s" % date
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not data.today.is_empty() and date < data.today: cadre.modulate = Color(1, 1, 1, .6)
	var numero := str(date.substr(8, 2).to_int())
	if date.substr(8, 2) == "01": numero += " " + MOIS[date.substr(5, 2).to_int() - 1].substr(0, 4).to_lower() + "."
	if aujourdhui:
		var w := Charte.TITRE_FICHE.get_string_size(numero, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(22))).x / C.density + 18
		D.rect(cadre, Rect2(6, 5, w, 26), Charte.IVOIRE, Charte.RAYON_PILULE).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := D.text(cadre, 15, 26, numero, 22, Charte.ENCRE if aujourdhui else (Charte.IVOIRE if not hors_mois else Charte.IVOIRE_3), 700, r.size.x - 20)
	n.add_theme_font_override("font", Charte.TITRE_FICHE)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Trois créneaux par jour : match, puis séances du staff ; « Repos » en filet quand le jour est libre.
	var creneaux := _creneaux(data, date)
	var hc := minf(32.0, (r.size.y - 40) / 3.0 - 4)
	for k in 3:
		var y := 36.0 + k * (hc + 4)
		var rc := Rect2(6, y, r.size.x - 12, hc)
		if k >= creneaux.size():
			if k == 0 and not hors_mois:
				var repos := D.rect(cadre, rc, Color.TRANSPARENT, Charte.RAYON_PETIT, Charte.FILET)
				repos.mouse_filter = Control.MOUSE_FILTER_IGNORE
				D.text(repos, 10, hc - 9, "Repos", 15, Charte.IVOIRE_3, 600, rc.size.x - 14).mouse_filter = Control.MOUSE_FILTER_IGNORE
			continue
		var cr: Array = creneaux[k]
		var bloc: Panel
		if cr[0] == "match":
			var adv := _adversaire(data, cr[2])
			bloc = D.rect(cadre, rc, Charte.IVOIRE, Charte.RAYON_PETIT)
			var crest := G.crest(adv, C.px(hc - 4))
			crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bloc.add_child(crest)
			D.place(crest, Rect2(4, 2, hc - 4, hc - 4))
			var texte := _court(adv) + "  " + _lieu(data, cr[2])
			var score := _score(cr[2])
			if not score.is_empty(): texte += "  " + score
			D.text(bloc, hc + 6, hc - 9, texte, 16, Charte.ENCRE, 800, rc.size.x - hc - 10).mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			var couleur: Color = FAMILLES[cr[0]][1]
			bloc = D.rect(cadre, rc, Color(couleur, .22), Charte.RAYON_PETIT)
			D.rect(bloc, Rect2(0, 0, 5, hc), couleur, 2).mouse_filter = Control.MOUSE_FILTER_IGNORE
			var icone := Mensuel._session_icon(str(cr[2].get("kind", "")))
			icone.modulate = couleur
			bloc.add_child(icone)
			D.place(icone, Rect2(11, 4, hc - 8, hc - 8))
			D.text(bloc, hc + 8, hc - 9, str(cr[1]), 16, Charte.IVOIRE, 600, rc.size.x - hc - 12).mouse_filter = Control.MOUSE_FILTER_IGNORE
		bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bloc.name = "TrainingMonthSlot_%s_%d" % [date, k]
	var jour := date
	Pieces.rendre_cliquable(cadre, r.size, func(): _fenetre_jour(page, data, jour), "TrainingMonthDayOpen_%s" % date, _date_longue(date), "", Charte.RAYON_PETIT)

# --- Pièces communes -------------------------------------------------------------------------------------------------

## Charge collective de la semaine (la seule séance simulée) : pastille ; clic = onglet Semaine (où on la choisit).
static func _charge(page: Control, data: Dictionary, parent: Control, s: Dictionary, at: Vector2, i: int) -> void:
	if bool(s.passee) or Dictionary(s.fixture).is_empty() and not bool(s.courante):
		D.text(parent, at.x + 10, at.y + 25, "—", 24, Charte.IVOIRE_3, 600, 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var c: Array = CHARGES.get(str(data.charge), CHARGES.normal)
	Pieces.pastille(parent, at.x, at.y, c[0], "train", "TrainingMonthCharge%d" % i, "", c[1], Charte.PANNEAU_3, func(): page._open_tab(0))

## Variante B : la charge en barre d'intensité (repos 1/3, normale 2/3, intensive 3/3) + mot ; clic = onglet Semaine.
static func _barre_charge(page: Control, data: Dictionary, parent: Control, s: Dictionary, r: Rect2, i: int) -> void:
	var vide := bool(s.passee) or Dictionary(s.fixture).is_empty() and not bool(s.courante)
	var c: Array = CHARGES.get(str(data.charge), CHARGES.normal)
	var part: float = {"repos": 1.0 / 3.0, "normal": 2.0 / 3.0, "intense": 1.0}.get(str(data.charge), 2.0 / 3.0)
	var fond := D.rect(parent, r, Charte.FILET, Charte.RAYON_PILULE)
	fond.name = "TrainingMonthChargeBar%d" % i
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vide: return
	D.rect(fond, Rect2(0, 0, r.size.x * part, r.size.y), c[1], Charte.RAYON_PILULE).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mot := D.text(parent, r.position.x, r.position.y + 40, "Charge " + str(c[0]).to_lower(), 18, c[1], 700, r.size.x)
	mot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var zone := Control.new()
	zone.name = "TrainingMonthChargeZone%d" % i
	parent.add_child(zone)
	D.place(zone, Rect2(r.position.x - 6, r.position.y - 8, r.size.x + 12, 56))
	Pieces.rendre_cliquable(zone, Vector2(r.size.x + 12, 56), func(): page._open_tab(0), "TrainingMonthCharge%d" % i, "Charge " + str(c[0]), "", Charte.RAYON_PETIT)

## Copier (retient le modèle de la semaine) / Coller (l'applique à cette semaine : commande moteur calendar_template).
static func _copier_coller(page: Control, data: Dictionary, parent: Control, s: Dictionary, at: Vector2, i: int, compact: bool) -> void:
	var copie := str(page.state.get("modele_copie", ""))
	var modele := str(s.modele)
	var w := 132.0 if compact else 130.0
	var semaine := s
	var copier := _bouton(parent, Rect2(at.x, at.y, w, 44), "Copier", "TrainingMonthCopy%d" % i, func():
		page.state.modele_copie = modele
		page._open_tab(page.active_tab))
	copier.disabled = modele.is_empty()
	var coller := _bouton(parent, Rect2(at.x + w + 12, at.y, w, 44), "Coller", "TrainingMonthPaste%d" % i, func(): _appliquer(page, semaine, copie))
	coller.disabled = copie.is_empty() or not bool(s.modifiable) or copie == modele

static func _bouton(parent: Control, r: Rect2, mot: String, id: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = id
	b.text = mot
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", C.BODY)
	b.add_theme_font_size_override("font_size", C.font_px(20))
	for etat: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var st := StyleBoxFlat.new()
		st.bg_color = {"normal": Charte.PANNEAU_3, "hover": Charte.PANNEAU_3.lerp(Charte.IVOIRE, .12), "pressed": Charte.PANNEAU_3.lerp(Charte.IVOIRE, .18), "disabled": Color(Charte.PANNEAU_3, .35), "focus": Color.TRANSPARENT}[etat]
		st.set_corner_radius_all(999)
		if etat == "focus":
			st.border_color = Charte.IVOIRE
			st.set_border_width_all(2)
		b.add_theme_stylebox_override(etat, st)
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(k, Charte.IVOIRE)
	b.add_theme_color_override("font_disabled_color", Color(Charte.IVOIRE_3, .6))
	b.pressed.connect(action)
	parent.add_child(b)
	D.place(b, r)
	return b

static func _appliquer(page: Control, s: Dictionary, modele: String) -> void:
	var f: Dictionary = s.get("fixture", {})
	if modele.is_empty() or f.is_empty() or not bool(s.get("modifiable", false)): return
	page.app._command("calendar_template", {"fixtureId": str(f.get("id", "")), "template": modele})

static func _ouvrir_match(page: Control, data: Dictionary, f: Dictionary) -> void:
	if not bool(f.get("played", false)) and str(f.get("date", "")) >= str(data.today):
		page.app.Immersive.open_preparation(page.app, 0)
	else:
		page.app.navigation_controller.open_entity({"kind": "club", "id": str(_adversaire(data, f).get("id", "")), "section": ""})

# --- Petites fenêtres visuelles --------------------------------------------------------------------------------------

## Le jour : match (blason, lieu, score) et chaque séance en carte colorée (icône, nom, groupes avants / arrières).
static func _fenetre_jour(page: Control, data: Dictionary, date: String) -> void:
	var creneaux: Array = []
	if data.matchs.has(date): creneaux.append(["match", "", data.matchs[date]])
	for s: Dictionary in data.seances.get(date, []): creneaux.append([FAMILLE_DE.get(str(s.get("kind", "")), "technique"), str(s.get("label", "")), s])
	var hauteur := 150.0 + maxf(1, creneaux.size()) * 96.0
	var fond := Fenetre.ouvrir(page, "TrainingMonthDayWindow", _date_longue(date).to_upper(), "calendar", 760, hauteur)
	if creneaux.is_empty():
		Pieces.pastille(fond, 34, 96, "Repos", "heart", "TrainingMonthDayRest", "", Charte.REPOS)
		return
	for k in creneaux.size():
		var cr: Array = creneaux[k]
		var y := 92.0 + k * 96.0
		if cr[0] == "match":
			var f: Dictionary = cr[2]
			var adv := _adversaire(data, f)
			var carte := D.rect(fond, Rect2(30, y, 700, 84), Charte.IVOIRE, Charte.RAYON_CARTE)
			carte.name = "TrainingMonthDayMatch"
			var crest := G.crest(adv, C.px(62))
			crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
			carte.add_child(crest)
			D.place(crest, Rect2(14, 11, 62, 62))
			D.text(carte, 92, 50, G.club_name(adv), 30, Charte.ENCRE, 800, 400).add_theme_font_override("font", Charte.TITRE_FICHE)
			D.text(carte, 520, 52, _lieu(data, f) + ("   " + _score(f) if not _score(f).is_empty() else ""), 28, Charte.ENCRE, 800, 170, HORIZONTAL_ALIGNMENT_RIGHT)
			var fixture := f
			Pieces.rendre_cliquable(carte, Vector2(700, 84), func(): _ouvrir_match(page, data, fixture), "TrainingMonthDayMatchOpen", G.club_name(adv), "", Charte.RAYON_CARTE)
			continue
		var s: Dictionary = cr[2]
		var couleur: Color = FAMILLES[cr[0]][1]
		var carte := D.rect(fond, Rect2(30, y, 700, 84), Color(couleur, .18), Charte.RAYON_CARTE)
		carte.name = "TrainingMonthDaySession%d" % k
		D.rect(carte, Rect2(0, 0, 8, 84), couleur, 4)
		var icone := Mensuel._session_icon(str(s.get("kind", "")))
		icone.modulate = couleur
		carte.add_child(icone)
		D.place(icone, Rect2(24, 18, 48, 48))
		D.text(carte, 92, 50, str(s.get("label", "")), 30, Charte.IVOIRE, 700, 300).add_theme_font_override("font", Charte.TITRE_FICHE)
		var x := 400.0
		if s.has("forwards"):
			x += Pieces.pastille(carte, x, 25, "Av. " + str(s.forwards), "people", "TrainingMonthDayForwards%d" % k, "", couleur) + 8
			Pieces.pastille(carte, x, 25, "Ar. " + str(s.backs), "people", "TrainingMonthDayBacks%d" % k, "", couleur)
		else:
			Pieces.pastille(carte, x, 25, FAMILLES[cr[0]][0], "check" if bool(s.get("completed", false)) else _icone_famille(cr[0]), "TrainingMonthDayFamily%d" % k, "", couleur)

## Une famille sur le mois : un jour par case avec le nombre de séances de la famille (couleur), clic = le jour.
static func _fenetre_famille(page: Control, data: Dictionary, famille: String) -> void:
	var couleur: Color = FAMILLES[famille][1]
	var semaines: Array = data.semaines
	var fond := Fenetre.ouvrir(page, "TrainingMonthFamilyWindow", str(FAMILLES[famille][0]).to_upper(), _icone_famille(famille), 760, 150 + semaines.size() * 70.0)
	for j in 7: D.text(fond, 40 + j * 98, 90, JOURS[j], 16, Charte.IVOIRE_3, 700, 88, HORIZONTAL_ALIGNMENT_CENTER)
	for i in semaines.size():
		for j in 7:
			var date: String = semaines[i].dates[j]
			var n := 0
			if famille == "match": n = 1 if data.matchs.has(date) else 0
			else:
				for s: Dictionary in data.seances.get(date, []):
					if FAMILLE_DE.get(str(s.get("kind", "")), "") == famille: n += 1
			var r := Rect2(40 + j * 98, 104 + i * 70, 88, 60)
			var case_ := D.rect(fond, r, Color(couleur, .22 + .3 * mini(n, 2)) if n > 0 else Color(Charte.PANNEAU_3, .6), Charte.RAYON_PETIT)
			case_.name = "TrainingMonthFamilyDay_%s" % date
			D.text(case_, 8, 22, str(date.substr(8, 2).to_int()), 15, Charte.IVOIRE_2, 700, 40)
			if n > 0:
				D.text(case_, 0, 50, str(n) if famille != "match" else "●", 24, Charte.IVOIRE, 800, 80, HORIZONTAL_ALIGNMENT_RIGHT)
				var jour := date
				Pieces.rendre_cliquable(case_, r.size, func(): _fenetre_jour(page, data, jour), "TrainingMonthFamilyOpen_%s" % date, _date_longue(date), "", Charte.RAYON_PETIT)

## Les quatre semaines types en cartes colorées (séances par jour en mini-bande) ; clic = l'appliquer à cette semaine.
static func _fenetre_modele(page: Control, data: Dictionary, s: Dictionary, retenu: String) -> void:
	var actuel := str(s.get("modele", retenu))
	var fond := Fenetre.ouvrir(page, "TrainingMonthModelWindow", "SEMAINE TYPE", "calendar", 900, 560)
	var ids := ["standard", "away", "congested", "break"]
	for k in ids.size():
		var id: String = ids[k]
		var m: Array = MODELES[id]
		var r := Rect2(30 + (k % 2) * 425, 92 + (k / 2) * 220, 410, 204)
		var carte := D.rect(fond, r, Color(m[1], .16), Charte.RAYON_CARTE, m[1] if id == actuel else Color.TRANSPARENT)
		carte.name = "TrainingMonthModelCard_" + id
		var icone := C.icon(m[2], 34, m[1])
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carte.add_child(icone)
		D.place(icone, Rect2(20, 20, 34, 34))
		D.text(carte, 66, 48, str(data.modeles.get(id, m[0])).to_upper(), 28, Charte.IVOIRE, 700, 330).add_theme_font_override("font", Charte.TITRE_FICHE)
		if id == actuel: Pieces.pastille(carte, 20, 150, "En place", "check", "TrainingMonthModelActive", "", m[1])
		# Mini-bande : J-5 … J+1, une case par jour d'entraînement du modèle (familles des séances).
		var bande: Array = _bande_modele(id)
		for d in bande.size():
			var fam: String = bande[d]
			var c: Color = Charte.FILET if fam.is_empty() else FAMILLES[fam][1]
			D.rect(carte, Rect2(20 + d * 52, 78, 44, 52), c, Charte.RAYON_PETIT).mouse_filter = Control.MOUSE_FILTER_IGNORE
			if not fam.is_empty():
				var ic := C.icon(_icone_famille(fam), 24, Charte.ENCRE)
				ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				carte.add_child(ic)
				D.place(ic, Rect2(30 + d * 52, 92, 24, 24))
		var semaine := s
		var modele := id
		if not s.is_empty() and bool(s.get("modifiable", false)) and id != actuel:
			Pieces.rendre_cliquable(carte, r.size, func(): _appliquer(page, semaine, modele), "TrainingMonthModelPick_" + id, str(m[0]), "", Charte.RAYON_CARTE)
		elif s.is_empty():
			Pieces.rendre_cliquable(carte, r.size, func():
				page.state.modele_copie = modele
				page._open_tab(page.active_tab), "TrainingMonthModelPick_" + id, str(m[0]), "", Charte.RAYON_CARTE)

## Familles du modèle, de J-5 à J+1 (miroir des programmes du moteur, calendar-planning.cjs) : vide = pas de séance.
static func _bande_modele(id: String) -> Array:
	match id:
		"standard": return ["intensif", "technique", "tactique", "technique", "tactique", "match", "recuperation"]
		"away": return ["intensif", "tactique", "technique", "technique", "", "match", "recuperation"]
		"congested": return ["", "", "", "tactique", "tactique", "match", "recuperation"]
		"break": return ["recuperation", "intensif", "intensif", "technique", "tactique", "match", "recuperation"]
	return []

# --- Dates -----------------------------------------------------------------------------------------------------------

static func _jj(date: String) -> String:
	return "%d/%d" % [date.substr(8, 2).to_int(), date.substr(5, 2).to_int()]

static func _jour_court(date: String) -> String:
	if not Agenda.valid_date(date): return ""
	return "%s %d" % [JOURS[Mensuel._weekday(date)].capitalize(), date.substr(8, 2).to_int()]

static func _date_longue(date: String) -> String:
	if not Agenda.valid_date(date): return date
	return "%s %d %s" % [Mensuel.WEEKDAYS[Mensuel._weekday(date)], date.substr(8, 2).to_int(), Mensuel.MONTHS[date.substr(5, 2).to_int() - 1].to_lower()]
