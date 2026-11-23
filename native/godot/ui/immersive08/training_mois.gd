extends RefCounted
## Plan d'entraînement › Mois (idée FM27 n° 6, choix de Léo du 22/11/2026 : grille du mois, option B). Un seul endroit
## pour le programme jour par jour : il remplace l'ancienne grille mensuelle du Calendrier (Compétitions), dont les
## liens mènent ici. Données du moteur :
##  - séances du jour : `calendarPlanning.sessions` (programme du staff : force, ateliers mêlée/touche, vidéo, jeu au pied,
##    mise en place, activation, récupération), trois créneaux par jour au plus ;
##  - matchs : `calendarPlanning.fixtures` / `calendar` (dates du calendrier réel) ;
##  - semaine type : modèle de chaque match (`calendarPlanning.programmeByFixture`) ; « Coller » et le choix d'une carte
##    = commande `calendar_template` ;
##  - effets de la semaine (`calendarPlanning.weeks`, `sessionEffects`, `templates[].effects`) : écart à la semaine type
##    standard sur la fatigue, la condition, la progression des avants / arrières et l'organisation collective ; ils
##    agissent sur la semaine simulée du club (calendar-planning.cjs weekEffects, programme-semaine.cjs) ;
##  - charge : intensité de la semaine choisie dans l'onglet Semaine (`meta.training`).
## Coordonnées en unités du gabarit (toile 2248 × 1230). `page` : la toile de l'entraînement (training_canvas.gd).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Agenda = preload("res://ui/immersive08/calendar_agenda.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")

const ONGLET := 5
const MOIS := ["JANVIER", "FÉVRIER", "MARS", "AVRIL", "MAI", "JUIN", "JUILLET", "AOÛT", "SEPTEMBRE", "OCTOBRE", "NOVEMBRE", "DÉCEMBRE"]
const JOURS := ["LUN", "MAR", "MER", "JEU", "VEN", "SAM", "DIM"]
const JOURS_LONGS := ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]
## Famille de séance → [mot, couleur franche, icône] (couleur jamais seule : toujours icône ou mot).
const FAMILLES := {
	"intensif": ["Intensif", Charte.INTENSIF, "train"],
	"technique": ["Technique", Charte.GAIN, "people"],
	"tactique": ["Tactique", Charte.MORAL, "tactic"],
	"recuperation": ["Récupération", Charte.REPOS, "heart"],
	"match": ["Match", Charte.IVOIRE, "ball"],
}
const FAMILLE_DE := {"strength": "intensif", "speed": "intensif", "team": "technique", "skills": "technique", "kicking": "technique", "tactics": "tactique", "video": "tactique", "recovery": "recuperation"}
## Pictogramme de chaque séance (tracés repris du programme du staff).
const ICONES := {
	"team":"M12 2a3 3 0 1 1 0 6 3 3 0 0 1 0-6ZM5 5a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5Zm14 0a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5ZM1 18v-3a4 4 0 0 1 6-3 6 6 0 0 0-1 4v2zm22 0h-5v-2a6 6 0 0 0-1-4 4 4 0 0 1 6 3zM7 22v-6a5 5 0 0 1 10 0v6z",
	"strength":"M1 8h3v8H1zm4-3h4v14H5zm5 5h4v4h-4zm5-5h4v14h-4zm5 3h3v8h-3z",
	"speed":"M13 1 3 14h7l-1 9 12-14h-7z",
	"tactics":"M2 3h20v18H2zm2 2v14h7v-3a4 4 0 0 1 0-8V5zm9 0v3a4 4 0 0 1 0 8v3h7V5zm-1 5a2 2 0 1 0 0 4 2 2 0 0 0 0-4",
	"skills":"M12 1a11 11 0 1 0 0 22 11 11 0 0 0 0-22Zm0 4a7 7 0 1 1 0 14 7 7 0 0 1 0-14Zm0 4a3 3 0 1 0 0 6 3 3 0 0 0 0-6Z",
	"recovery":"M12 21 3.5 13C-3 7 5 0 12 7c7-7 15 0 8.5 6z",
	"video":"M1 4h22v16H1zm9 4v8l7-4z",
	"kicking":"M21 3C10 0 0 10 3 21c11 3 21-7 18-18ZM8 14l6-6 2 2-6 6z",
}
## Modèle de semaine → [mot court, couleur, icône].
const MODELES := {
	"standard": ["Standard", Charte.GAIN, "calendar"],
	"away": ["Déplacement", Charte.MORAL, "bus"],
	"congested": ["Rapprochés", Charte.INTENSIF, "clock"],
	"break": ["Reprise", Charte.REPOS, "renew"],
}
## Effet → [abréviation, couleur, icône, suffixe, mot pour l'infobulle] ; fatigue : moins = mieux.
const EFFETS := {
	"fatigue": ["", Charte.INTENSIF, "train", "", "Fatigue"],
	"condition": ["", Charte.CONDITION, "heart", "", "Condition"],
	"avants": ["AV", Charte.CONFIANCE, "", "%", "Progression des avants"],
	"arrieres": ["AR", Charte.CONFIANCE, "", "%", "Progression des arrières"],
	"cohesion": ["", Charte.MORAL, "tactic", "%", "Organisation collective"],
}
const CHARGES := {"repos": ["Repos", Charte.REPOS], "normal": ["Normale", Charte.NORMAL], "intense": ["Intensive", Charte.INTENSIF]}
const HAUT := 250.0
const BAS := 1217.0
const GAUCHE := 330.0
static var _textures: Dictionary = {}

# --- Entrées depuis les autres écrans ---------------------------------------------------------------------------------

## Ouvre l'onglet Mois sur le mois de `date` (jour du jour si vide), et la petite fenêtre de ce jour si `jour`.
static func ouvrir(app: Control, date: String = "", jour: bool = false) -> void:
	if not app.management_ui.get("immersive_training") is Dictionary: app.management_ui.immersive_training = {}
	var state: Dictionary = app.management_ui.immersive_training
	state.tab = ONGLET
	if Agenda.valid_date(date):
		state.mois = date.substr(0, 7)
		if jour: state.jour_ouvert = date
	else:
		state.erase("mois")
	load("res://ui/immersive08/shell.gd").open_training(app)

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
	# Planche « Séance avec ses effets » (revue FM27, idée 25) : séances remplacées à la main.
	var Seance = load("res://ui/immersive08/seance_effets.gd")
	if not Seance.variante().is_empty(): Seance.appliquer_choix(page, seances)
	var modeles := {}
	for t: Variant in planning.get("templates", []):
		if t is Dictionary: modeles[str(t.get("id", ""))] = t
	var mois := str(page.state.get("mois", ""))
	if not Agenda.valid_date(mois + "-01"):
		mois = today.substr(0, 7) if not today.is_empty() else str(matchs.keys().min()).substr(0, 7) if not matchs.is_empty() else "2026-09"
	var annee := mois.substr(0, 4).to_int()
	var numero := mois.substr(5, 2).to_int()
	var premier := mois + "-01"
	var dernier := "%s-%02d" % [mois, longueur_mois(annee, numero)]
	var semaines: Array = []
	var lundi: String = Agenda.week(premier)[0]
	while not lundi.is_empty() and lundi <= dernier:
		semaines.append(_semaine(page, Agenda.week(lundi), matchs, planning, today))
		lundi = Agenda.shift(lundi, 7)
	var semaines_effets: Variant = planning.get("weeks", {})
	var par_seance: Variant = planning.get("sessionEffects", {})
	return {"today": today, "matchs": matchs, "seances": seances, "modeles": modeles, "semaines": semaines,
		"titre": "%s %d" % [MOIS[numero - 1], annee], "mois": mois, "club_id": club_id,
		"effets": semaines_effets if semaines_effets is Dictionary else {}, "par_seance": par_seance if par_seance is Dictionary else {},
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

## Créneaux d'un jour : [famille, libellé, séance ou match]. Match d'abord, puis les séances du staff.
static func _creneaux(data: Dictionary, date: String, limite: int = 3) -> Array:
	var sortie: Array = []
	if data.matchs.has(date): sortie.append(["match", "", data.matchs[date]])
	for s: Dictionary in data.seances.get(date, []):
		if sortie.size() >= limite: break
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
	return G.club_name(club).substr(0, 10)

# --- Écran -----------------------------------------------------------------------------------------------------------

static func construire(page: Control) -> void:
	var data := _donnees(page)
	_barre(page, data)
	_grille(page, data)
	# Lien venu d'un autre écran (séance du Calendrier, rendez-vous) : la petite fenêtre du jour s'ouvre d'elle-même.
	var jour := str(page.state.get("jour_ouvert", ""))
	page.state.erase("jour_ouvert")
	if Agenda.valid_date(jour): _fenetre_jour(page, data, jour)

## Barre du mois : ◀ ▶ MOIS ANNÉE, aujourd'hui, semaine copiée, légende des familles (icône + mot, cliquable).
static func _barre(page: Control, data: Dictionary) -> void:
	_bouton(page, Rect2(4, HAUT, 52, 46), "◀", "TrainingMonthPrev", func(): _decaler(page, data, -1))
	_bouton(page, Rect2(64, HAUT, 52, 46), "▶", "TrainingMonthNext", func(): _decaler(page, data, 1))
	var titre := D.text(page, 134, HAUT + 39, data.titre, 40, Charte.IVOIRE, 700, 330)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "TrainingMonthTitle"
	var x := 480.0
	if not data.today.is_empty() and data.mois != data.today.substr(0, 7):
		x += Pieces.pastille(page, x, HAUT + 6, "Aujourd'hui", "calendar", "TrainingMonthToday", "", Charte.IVOIRE, Charte.PANNEAU_3, func(): _decaler(page, data, 0)) + 12
	# Mois sans rencontre : la prochaine, en pastille (dans N jours, adversaire) ; clic = son mois.
	var prochain := _prochain_match(data)
	if not prochain.is_empty() and not data.matchs.keys().any(func(d: String): return d.begins_with(str(data.mois))):
		var jours := roundi((Time.get_unix_time_from_datetime_string(str(prochain.date) + "T00:00:00") - Time.get_unix_time_from_datetime_string(str(data.today) + "T00:00:00")) / 86400.0)
		var quand := "aujourd’hui" if jours <= 0 else "demain" if jours == 1 else "dans %d j" % jours
		var cible := str(prochain.date)
		x += Pieces.pastille(page, x, HAUT + 6, "Prochain match %s · %s" % [quand, _court(_adversaire(data, prochain))], "ball", "TrainingMonthNextMatch", "", Charte.IVOIRE, Charte.PANNEAU_3, func():
			page.state.mois = cible.substr(0, 7)
			page._open_tab(page.active_tab)) + 12
	# Sélections : joueurs du club retenus (nombre, retour prévu) ; clic = disponibilités internationales.
	var dispo := preload("res://ui/international_availability.gd")
	var etat_dispo: Dictionary = dispo.data(page.app.model)
	if bool(etat_dispo.get("clubManaged", false)) or int(etat_dispo.get("absentCount", 0)) > 0:
		var absents := int(etat_dispo.get("absentCount", 0))
		var mot := "%d en sélection · retour %s" % [absents, dispo._date(etat_dispo.get("nextReturn"))] if absents > 0 else "0 absent"
		x += Pieces.pastille(page, x, HAUT + 6, mot, "flag" if absents > 0 else "check", "TrainingMonthSelections", "", Charte.PERTE if absents > 0 else Charte.GAIN, Charte.PANNEAU_3, func(): dispo.open(page.app)) + 12
		# Même nom que l'ancien lien du Calendrier : suivi international (Sélections › Disponibilités).
		var lien := page.find_child("TrainingMonthSelectionsLien", true, false)
		if lien != null: lien.name = "InternationalAvailabilityOpen"
	var copie := str(page.state.get("modele_copie", ""))
	var legendes := ["intensif", "technique", "tactique", "recuperation", "match"]
	var largeurs := 0.0
	for k: String in legendes: largeurs += Pieces.largeur_pastille(FAMILLES[k][0], FAMILLES[k][2]) + 10
	var mot_copie := "Copiée · " + str(MODELES.get(copie, [copie])[0])
	if not copie.is_empty(): largeurs += Pieces.largeur_pastille(mot_copie, "check") + 24
	x = maxf(x + 20, 2244.0 - largeurs)
	if not copie.is_empty():
		x += Pieces.pastille(page, x, HAUT + 6, mot_copie, "check", "TrainingMonthCopied", "", MODELES.get(copie, ["", Charte.IVOIRE])[1], Charte.PANNEAU_3, func(): _fenetre_modele(page, data, {}, copie)) + 24
	for k: String in legendes:
		var famille := k
		x += Pieces.pastille(page, x, HAUT + 6, FAMILLES[k][0], FAMILLES[k][2], "TrainingMonthLegend_" + k, "", FAMILLES[k][1], Charte.PANNEAU_3, func(): _fenetre_famille(page, data, famille)) + 10

static func _prochain_match(data: Dictionary) -> Dictionary:
	if str(data.today).is_empty(): return {}
	var dates: Array = data.matchs.keys().filter(func(d: String): return d >= str(data.today) and not bool(data.matchs[d].get("played", false)))
	if dates.is_empty(): return {}
	dates.sort()
	return data.matchs[dates[0]]

static func _decaler(page: Control, data: Dictionary, sens: int) -> void:
	if sens == 0: page.state.erase("mois")
	else:
		var annee := str(data.mois).substr(0, 4).to_int()
		var numero := str(data.mois).substr(5, 2).to_int() + sens
		if numero > 12:
			numero = 1
			annee += 1
		elif numero < 1:
			numero = 12
			annee -= 1
		page.state.mois = "%04d-%02d" % [annee, numero]
	page._open_tab(page.active_tab)

## Grille du mois : colonne de la semaine (semaine type, effets, charge, copier / coller), puis 7 jours à 3 créneaux.
static func _grille(page: Control, data: Dictionary) -> void:
	var zone := Rect2(4, HAUT + 62, 2244, BAS - HAUT - 62)
	var panneau := D.panel(page, zone, "", "", "", "TrainingMonthGrid")
	var entete := Panel.new()
	entete.name = "TrainingMonthHeader"
	entete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Bandeau.peindre_entete(entete)
	panneau.add_child(entete)
	D.place(entete, Rect2(0, 0, zone.size.x, 46))
	var largeur_jour := (zone.size.x - GAUCHE - 12) / 7.0
	D.text(entete, 18, 30, "SEMAINE TYPE", 17, Charte.IVOIRE_3, 700, 200).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for j in 7:
		D.text(entete, GAUCHE + j * largeur_jour, 30, JOURS[j], 17, Charte.IVOIRE_3, 700, largeur_jour - 8, HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var semaines: Array = data.semaines
	var h := minf(170.0, (zone.size.y - 56) / maxf(1, semaines.size()))
	for i in semaines.size():
		var s: Dictionary = semaines[i]
		var y := 52.0 + i * h
		_colonne_semaine(page, data, panneau, s, Rect2(8, y, GAUCHE - 20, h - 6), i)
		for j in 7:
			_jour(page, data, panneau, Rect2(GAUCHE + j * largeur_jour, y, largeur_jour - 8, h - 6), str(s.dates[j]))

## Colonne de gauche d'une semaine : semaine type (clic = les quatre modèles), effets de la semaine, barre de charge,
## copier / coller.
static func _colonne_semaine(page: Control, data: Dictionary, panneau: Control, s: Dictionary, r: Rect2, i: int) -> void:
	var col := Control.new()
	col.name = "TrainingMonthWeek%d" % i
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panneau.add_child(col)
	D.place(col, r)
	D.rect(col, Rect2(Vector2.ZERO, r.size), Charte.PANNEAU_3 if bool(s.courante) else Color(Charte.PANNEAU_3, .5), Charte.RAYON_CARTE).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bool(s.passee): col.modulate = Color(1, 1, 1, .6)
	var x := 12.0
	if not str(s.modele).is_empty():
		var m: Array = MODELES.get(str(s.modele), [str(s.modele), Charte.IVOIRE, "calendar"])
		var semaine := s
		x += Pieces.pastille(col, 12, 10, m[0], m[2], "TrainingMonthModel%d" % i, "", m[1], Charte.PANNEAU_3, func(): _fenetre_modele(page, data, semaine, "")) + 8
	else:
		x += Pieces.pastille(col, 12, 10, "Sans match", "calendar", "TrainingMonthNoMatch%d" % i, "", Charte.IVOIRE_3) + 8
	if bool(s.courante): Pieces.pastille(col, x, 10, "En cours", "clock", "TrainingMonthNow%d" % i, "", Charte.IVOIRE)
	var effets: Variant = data.effets.get(str(s.dates[0]))
	if effets is Dictionary: _effets(col, Vector2(12, 52), effets, "TrainingMonthWeekEffect%d_" % i, r.size.x - 24)
	_barre_charge(page, data, col, s, Rect2(14, r.size.y - 74, r.size.x - 28, 10), i)
	_copier_coller(page, col, s, Vector2(12, r.size.y - 50), i)

## Effets en petites pilules (icône ou abréviation + valeur signée, couleur de la donnée) ; zéro : pilule « = » neutre.
## Renvoie la largeur posée.
static func _effets(parent: Control, at: Vector2, effets: Dictionary, prefixe: String, largeur_max: float) -> float:
	var x := at.x
	var aucun := true
	for cle: String in ["fatigue", "condition", "avants", "arrieres", "cohesion"]:
		var v := int(effets.get(cle, 0))
		if v == 0: continue
		aucun = false
		var e: Array = EFFETS[cle]
		var mot := ("+" if v > 0 else "−") + str(absi(v)) + str(e[3])
		if not str(e[0]).is_empty(): mot = str(e[0]) + " " + mot
		var w := _petite_pilule(parent, Vector2(x, at.y), mot, str(e[2]), e[1], prefixe + cle, "%s %s" % [e[4], mot])
		if x + w > at.x + largeur_max: (parent.get_node(prefixe + cle) as Control).visible = false
		x += w + 6
	if aucun: x += _petite_pilule(parent, at, "= moyenne", "", Charte.IVOIRE_2, prefixe + "aucun", "Semaine moyenne du programme du staff") + 6
	return x - at.x

static func _petite_pilule(parent: Control, at: Vector2, mot: String, icone: String, couleur: Color, id: String, bulle: String) -> float:
	var largeur := C.BODY.get_string_size(mot, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(10, C.px(15))).x / C.density + 18.0 + (20.0 if not icone.is_empty() else 0.0)
	var pilule := D.rect(parent, Rect2(at.x, at.y, largeur, 26), Charte.PANNEAU_3.lerp(couleur, .2), Charte.RAYON_PILULE)
	pilule.name = id
	pilule.tooltip_text = bulle
	var gauche := 9.0
	if not icone.is_empty():
		var image := TextureRect.new()
		image.texture = C.icon_texture(icone, couleur)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pilule.add_child(image)
		D.place(image, Rect2(8, 5, 16, 16))
		gauche = 28.0
	D.text(pilule, gauche, 19, mot, 15, couleur, 700, largeur - gauche - 4).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return largeur

## Un jour : numéro, trois créneaux (match puis séances), « Repos » en filet quand le jour est libre ; clic = petite
## fenêtre du jour.
static func _jour(page: Control, data: Dictionary, panneau: Control, r: Rect2, date: String) -> void:
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
	# Joueurs retenus par leur sélection (absence) ou de retour ce jour : pastille drapeau + nombre.
	var absences := Agenda.absence_events(page.app.model, date)
	if not absences.is_empty():
		var partis := absences.filter(func(e: Dictionary): return e.kind == "absence").size()
		var couleur: Color = Charte.PERTE if partis > 0 else Charte.GAIN
		_petite_pilule(cadre, Vector2(r.size.x - 70, 6), str(partis if partis > 0 else absences.size()), "flag", couleur, "TrainingMonthAbsence_" + date, "Sélection : %d absent(s), %d retour(s)" % [partis, absences.size() - partis])
	var creneaux := _creneaux(data, date)
	var hc := minf(32.0, (r.size.y - 40) / 3.0 - 4)
	for k in 3:
		var rc := Rect2(6, 36.0 + k * (hc + 4), r.size.x - 12, hc)
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
			if not _score(cr[2]).is_empty(): texte += "  " + _score(cr[2])
			D.text(bloc, hc + 6, hc - 9, texte, 16, Charte.ENCRE, 800, rc.size.x - hc - 10).mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			var couleur: Color = FAMILLES[cr[0]][1]
			bloc = D.rect(cadre, rc, Color(couleur, .22), Charte.RAYON_PETIT)
			D.rect(bloc, Rect2(0, 0, 5, hc), couleur, 2).mouse_filter = Control.MOUSE_FILTER_IGNORE
			var icone := icone_seance(str(cr[2].get("kind", "")), hc - 8)
			icone.modulate = couleur
			bloc.add_child(icone)
			D.place(icone, Rect2(11, 4, hc - 8, hc - 8))
			D.text(bloc, hc + 8, hc - 9, str(cr[1]), 16, Charte.IVOIRE, 600, rc.size.x - hc - 12).mouse_filter = Control.MOUSE_FILTER_IGNORE
		bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bloc.name = "TrainingMonthSlot_%s_%d" % [date, k]
	var jour := date
	Pieces.rendre_cliquable(cadre, r.size, func(): _fenetre_jour(page, data, jour), "TrainingMonthDayOpen_%s" % date, _date_longue(date), "", Charte.RAYON_PETIT)

# --- Pièces communes -------------------------------------------------------------------------------------------------

## Charge collective (intensité de la semaine) en barre (repos 1/3, normale 2/3, intensive 3/3) + mot ; clic = Semaine.
static func _barre_charge(page: Control, data: Dictionary, parent: Control, s: Dictionary, r: Rect2, i: int) -> void:
	var vide := bool(s.passee) or Dictionary(s.fixture).is_empty() and not bool(s.courante)
	var c: Array = CHARGES.get(str(data.charge), CHARGES.normal)
	var part: float = {"repos": 1.0 / 3.0, "normal": 2.0 / 3.0, "intense": 1.0}.get(str(data.charge), 2.0 / 3.0)
	var largeur_barre := r.size.x - 120
	var fond := D.rect(parent, Rect2(r.position, Vector2(largeur_barre, r.size.y)), Charte.FILET, Charte.RAYON_PILULE)
	fond.name = "TrainingMonthChargeBar%d" % i
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vide: return
	D.rect(fond, Rect2(0, 0, largeur_barre * part, r.size.y), c[1], Charte.RAYON_PILULE).mouse_filter = Control.MOUSE_FILTER_IGNORE
	D.text(parent, r.position.x + largeur_barre + 10, r.position.y + 12, str(c[0]), 17, c[1], 700, 110).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var zone := Control.new()
	zone.name = "TrainingMonthChargeZone%d" % i
	parent.add_child(zone)
	D.place(zone, Rect2(r.position.x - 6, r.position.y - 10, r.size.x + 12, 30))
	Pieces.rendre_cliquable(zone, Vector2(r.size.x + 12, 30), func(): page._open_tab(0), "TrainingMonthCharge%d" % i, "Charge " + str(c[0]), "", Charte.RAYON_PETIT)

## Copier (retient le modèle de la semaine) / Coller (l'applique à cette semaine : commande moteur calendar_template).
static func _copier_coller(page: Control, parent: Control, s: Dictionary, at: Vector2, i: int) -> void:
	var copie := str(page.state.get("modele_copie", ""))
	var modele := str(s.modele)
	var semaine := s
	var copier := _bouton(parent, Rect2(at.x, at.y, 136, 40), "Copier", "TrainingMonthCopy%d" % i, func():
		page.state.modele_copie = modele
		page._open_tab(page.active_tab))
	copier.disabled = modele.is_empty()
	var coller := _bouton(parent, Rect2(at.x + 148, at.y, 136, 40), "Coller", "TrainingMonthPaste%d" % i, func(): appliquer(page, semaine, copie))
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

## Applique un modèle à la semaine (son match) : commande moteur `calendar_template`.
static func appliquer(page: Control, s: Dictionary, modele: String) -> void:
	var f: Dictionary = s.get("fixture", {})
	if modele.is_empty() or f.is_empty() or not bool(s.get("modifiable", false)): return
	page.app._command("calendar_template", {"fixtureId": str(f.get("id", "")), "template": modele})

static func _ouvrir_match(page: Control, data: Dictionary, f: Dictionary) -> void:
	if not bool(f.get("played", false)) and str(f.get("date", "")) >= str(data.today):
		page.app.Immersive.open_preparation(page.app, 0)
	else:
		page.app.navigation_controller.open_entity({"kind": "club", "id": str(_adversaire(data, f).get("id", "")), "section": ""})

static func icone_seance(kind: String, taille: float) -> TextureRect:
	if not ICONES.has(kind): kind = "team"
	if not _textures.has(kind):
		var image := Image.new()
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="72" height="72" viewBox="0 0 24 24"><path d="%s" fill="#f2ecdc" fill-rule="evenodd"/></svg>' % ICONES[kind]
		if image.load_svg_from_string(svg) == OK: _textures[kind] = ImageTexture.create_from_image(image)
	var icone := TextureRect.new()
	icone.texture = _textures.get(kind)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.custom_minimum_size = Vector2(C.px(taille), C.px(taille))
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icone

# --- Petites fenêtres visuelles --------------------------------------------------------------------------------------

## Le jour : match (blason, lieu, score) et chaque séance en carte colorée (icône, nom, groupes, effets de la séance).
static func _fenetre_jour(page: Control, data: Dictionary, date: String) -> void:
	var creneaux := _creneaux(data, date, 99)
	var absences := Agenda.absence_events(page.app.model, date)
	var lignes_absences := ceili(absences.size() / 2.0)
	var fond := Fenetre.ouvrir(page, "TrainingMonthDayWindow", _date_longue(date).to_upper(), "calendar", 900, 150.0 + maxf(1, creneaux.size()) * 96.0 + lignes_absences * 70.0)
	# Sélections : un joueur par pilule (drapeau, nom, absent / retour) ; clic = sa fiche.
	for a in absences.size():
		var e: Dictionary = absences[a]
		var joueur: Dictionary = e.get("player", {})
		var y_abs := 92.0 + maxf(1, creneaux.size()) * 96.0 + floori(a / 2.0) * 70.0
		var parti: bool = e.kind == "absence"
		var couleur: Color = Charte.PERTE if parti else Charte.GAIN
		var carte := D.rect(fond, Rect2(30 + (a % 2) * 425, y_abs, 415, 60), Color(couleur, .16), Charte.RAYON_CARTE)
		carte.name = "TrainingMonthDayAbsence%d" % a
		var ic := C.icon("flag", 26, couleur)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carte.add_child(ic)
		D.place(ic, Rect2(16, 17, 26, 26))
		D.text(carte, 54, 38, str(joueur.get("name", "")), 22, Charte.IVOIRE, 700, 220).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(carte, 280, 38, "Absent" if parti else "Retour", 18, couleur, 700, 120, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var id := str(joueur.get("id", ""))
		if not id.is_empty():
			Pieces.rendre_cliquable(carte, Vector2(415, 60), func():
				page.app.selected_player = id
				page.app.navigation_controller.open_entity({"kind": "player", "id": id, "section": ""}), "TrainingMonthDayAbsenceOpen%d" % a, str(joueur.get("name", "")), "", Charte.RAYON_CARTE)
	if creneaux.is_empty():
		Pieces.pastille(fond, 34, 96, "Repos", "heart", "TrainingMonthDayRest", "", Charte.REPOS)
		return
	for k in creneaux.size():
		var cr: Array = creneaux[k]
		var y := 92.0 + k * 96.0
		if cr[0] == "match":
			var f: Dictionary = cr[2]
			var adv := _adversaire(data, f)
			var carte := D.rect(fond, Rect2(30, y, 840, 84), Charte.IVOIRE, Charte.RAYON_CARTE)
			carte.name = "TrainingMonthDayMatch"
			var crest := G.crest(adv, C.px(62))
			crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
			carte.add_child(crest)
			D.place(crest, Rect2(14, 11, 62, 62))
			D.text(carte, 92, 52, G.club_name(adv), 30, Charte.ENCRE, 800, 500).add_theme_font_override("font", Charte.TITRE_FICHE)
			D.text(carte, 620, 52, _lieu(data, f) + ("   " + _score(f) if not _score(f).is_empty() else ""), 28, Charte.ENCRE, 800, 200, HORIZONTAL_ALIGNMENT_RIGHT)
			var fixture := f
			Pieces.rendre_cliquable(carte, Vector2(840, 84), func(): _ouvrir_match(page, data, fixture), "TrainingMonthDayMatchOpen", G.club_name(adv), "", Charte.RAYON_CARTE)
			continue
		var s: Dictionary = cr[2]
		var couleur: Color = FAMILLES[cr[0]][1]
		var carte := D.rect(fond, Rect2(30, y, 840, 84), Color(couleur, .18), Charte.RAYON_CARTE)
		carte.name = "TrainingMonthDaySession%d" % k
		D.rect(carte, Rect2(0, 0, 8, 84), couleur, 4)
		var icone := icone_seance(str(s.get("kind", "")), 48)
		icone.modulate = couleur
		carte.add_child(icone)
		D.place(icone, Rect2(24, 18, 48, 48))
		D.text(carte, 92, 40, str(s.get("label", "")), 30, Charte.IVOIRE, 700, 300).add_theme_font_override("font", Charte.TITRE_FICHE)
		var sous: String = str(FAMILLES[cr[0]][0])
		if s.has("forwards"): sous = "Av. %s · Ar. %s" % [str(s.forwards), str(s.backs)]
		D.text(carte, 92, 68, sous, 18, couleur, 600, 300)
		var effets: Variant = data.par_seance.get(str(s.get("kind", "")))
		if effets is Dictionary: _effets(carte, Vector2(420, 29), effets, "TrainingMonthDayEffect%d_" % k, 410)
		var Seance = load("res://ui/immersive08/seance_effets.gd")
		if not Seance.variante().is_empty():
			var rang: int = Array(data.seances.get(date, [])).find(s)
			var jour := date
			Pieces.rendre_cliquable(carte, Vector2(840, 84), func(): Seance.ouvrir(page, jour, rang), "TrainingMonthDaySessionOpen%d" % k, str(s.get("label", "")), "", Charte.RAYON_CARTE)

## Une famille sur le mois : un jour par case avec le nombre de séances de la famille (couleur), clic = le jour.
static func _fenetre_famille(page: Control, data: Dictionary, famille: String) -> void:
	var couleur: Color = FAMILLES[famille][1]
	var semaines: Array = data.semaines
	var fond := Fenetre.ouvrir(page, "TrainingMonthFamilyWindow", str(FAMILLES[famille][0]).to_upper(), FAMILLES[famille][2], 760, 150 + semaines.size() * 70.0)
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

## Les quatre semaines types en cartes : mini-bande J-5 … J+2 (familles des séances du moteur), effets de la semaine ;
## clic = l'appliquer à cette semaine (ou la retenir comme semaine copiée depuis la pastille « Copiée »).
static func _fenetre_modele(page: Control, data: Dictionary, s: Dictionary, retenu: String) -> void:
	var actuel := str(s.get("modele", retenu))
	var fond := Fenetre.ouvrir(page, "TrainingMonthModelWindow", "SEMAINE TYPE", "calendar", 960, 600)
	var ids := ["standard", "away", "congested", "break"]
	for k in ids.size():
		var id: String = ids[k]
		var m: Array = MODELES[id]
		var t: Dictionary = data.modeles.get(id, {})
		var r := Rect2(30 + (k % 2) * 455, 92 + (k / 2) * 240, 440, 224)
		var carte := D.rect(fond, r, Color(m[1], .16), Charte.RAYON_CARTE, m[1] if id == actuel else Color.TRANSPARENT)
		carte.name = "TrainingMonthModelCard_" + id
		var icone := C.icon(m[2], 34, m[1])
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carte.add_child(icone)
		D.place(icone, Rect2(20, 18, 34, 34))
		D.text(carte, 66, 46, str(t.get("label", m[0])).to_upper(), 28, Charte.IVOIRE, 700, 300).add_theme_font_override("font", Charte.TITRE_FICHE)
		if id == actuel: Pieces.pastille(carte, 310, 16, "En place", "check", "TrainingMonthModelActive", "", m[1])
		# Mini-bande : un jour par case de J-5 à J+2 (séances du modèle, match crème au centre).
		var familles := {}
		for slot: Variant in t.get("slots", []):
			if slot is Dictionary:
				var off := int(slot.get("offset", 0))
				if off >= -5 and off <= 2: familles[off] = FAMILLE_DE.get(str(slot.get("kind", "")), "technique")
		for d in 8:
			var off := d - 5
			var fam: String = "match" if off == 0 else str(familles.get(off, ""))
			var c: Color = Charte.FILET if fam.is_empty() else FAMILLES[fam][1]
			D.rect(carte, Rect2(20 + d * 51, 72, 44, 52), c, Charte.RAYON_PETIT).mouse_filter = Control.MOUSE_FILTER_IGNORE
			if not fam.is_empty():
				var ic := C.icon(FAMILLES[fam][2], 24, Charte.ENCRE)
				ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				carte.add_child(ic)
				D.place(ic, Rect2(30 + d * 51, 86, 24, 24))
			D.text(carte, 20 + d * 51, 146, ("J" if off == 0 else "%+d" % off), 15, Charte.IVOIRE_3, 700, 44, HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var effets: Variant = t.get("effects")
		if effets is Dictionary: _effets(carte, Vector2(20, 176), effets, "TrainingMonthModelEffect_%s_" % id, 400)
		var semaine := s
		var modele := id
		if not s.is_empty() and bool(s.get("modifiable", false)) and id != actuel:
			Pieces.rendre_cliquable(carte, r.size, func(): appliquer(page, semaine, modele), "TrainingMonthModelPick_" + id, str(m[0]), "", Charte.RAYON_CARTE)
		elif s.is_empty():
			Pieces.rendre_cliquable(carte, r.size, func():
				page.state.modele_copie = modele
				page._open_tab(page.active_tab), "TrainingMonthModelPick_" + id, str(m[0]), "", Charte.RAYON_CARTE)

# --- Dates -----------------------------------------------------------------------------------------------------------

static func longueur_mois(annee: int, numero: int) -> int:
	if numero == 2: return 29 if annee % 4 == 0 and (annee % 100 != 0 or annee % 400 == 0) else 28
	return 30 if numero in [4, 6, 9, 11] else 31

static func jour_semaine(date: String) -> int:
	var stamp := int(Time.get_unix_time_from_datetime_string(date + "T00:00:00"))
	return (int(Time.get_datetime_dict_from_unix_time(stamp).weekday) + 6) % 7

static func _date_longue(date: String) -> String:
	if not Agenda.valid_date(date): return date
	return "%s %d %s" % [JOURS_LONGS[jour_semaine(date)], date.substr(8, 2).to_int(), MOIS[date.substr(5, 2).to_int() - 1].to_lower()]
