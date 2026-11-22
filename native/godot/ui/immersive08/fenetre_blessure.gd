extends RefCounted
## Petite fenêtre « blessure » (revue FM27, idée 3 ; option A choisie par Léo le 22/11/2026) : silhouette face / dos
## avec la zone touchée en halo rouge, retour prévu, puis les jauges en lignes comme l'Effectif (forme, énergie,
## charge en match, charge à l'entraînement, fragilité, risque de blessure au prochain match, risque de rechute).
## Ouverte par un clic sur la pastille Blessé (Effectif, salle médicale). Cadre commun fenetre_visuelle.gd : Échap, ✕
## et clic à côté la ferment. Données lues telles que le moteur les envoie (`app.model.squad` : fragilite,
## risqueBlessure, rechute ; `clubLife.clubSupport.medical` : protocole). Silhouette : art/corps (CC0, voir CREDITS.md).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Charte = preload("res://ui/charte.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Panneaux = preload("res://ui/immersive08/panneaux_effectif.gd")
const CORPS = preload("res://art/corps/corps-rugbyman.svg")

const NOM := "FenetreBlessure"
const GRIS := Color("5d6866")
const LARGEUR := 1360.0
const HAUTEUR := 830.0
const LIGNE := 52.0

## Zone touchée par type de blessure (données club-mail.json « blessures.types ») : points dans le dessin
## corps-rugbyman.svg (752 × 1584, vu de face) pour le côté droit du joueur (d, à gauche du dessin) et le gauche (g),
## vue (F face, B dos, FB les deux), rayon. Vu de dos, le dessin est retourné : la droite du joueur passe à droite.
const ZONES := {
	"commotion": {"d": Vector2(410, 85), "g": Vector2(410, 85), "vue": "FB", "r": 72.0, "mot": "Tête", "cote": false},
	"cou": {"d": Vector2(405, 200), "g": Vector2(405, 200), "vue": "FB", "r": 38.0, "mot": "Cou", "cote": false},
	"epaule": {"d": Vector2(215, 290), "g": Vector2(575, 290), "vue": "FB", "r": 55.0, "mot": "Épaule", "cote": true},
	"cotes": {"d": Vector2(295, 500), "g": Vector2(495, 500), "vue": "F", "r": 55.0, "mot": "Côtes", "cote": true},
	"contusion": {"d": Vector2(265, 900), "g": Vector2(485, 900), "vue": "F", "r": 68.0, "mot": "Cuisse", "cote": true},
	"ischios": {"d": Vector2(265, 920), "g": Vector2(485, 920), "vue": "B", "r": 68.0, "mot": "Ischios", "cote": true},
	"genou": {"d": Vector2(232, 1120), "g": Vector2(465, 1120), "vue": "F", "r": 44.0, "mot": "Genou", "cote": true},
	"croises": {"d": Vector2(232, 1120), "g": Vector2(465, 1120), "vue": "FB", "r": 48.0, "mot": "Genou", "cote": true},
	"mollet": {"d": Vector2(222, 1235), "g": Vector2(460, 1235), "vue": "B", "r": 50.0, "mot": "Mollet", "cote": true},
	"cheville": {"d": Vector2(150, 1450), "g": Vector2(480, 1440), "vue": "FB", "r": 32.0, "mot": "Cheville", "cote": true},
}
const CAUSES := {"match": ["Match", "ball"], "entrainement": ["Entraînement", "train"], "rechute": ["Rechute", "renew"]}
const PROTOCOLES := {"prudent": "Prudent", "standard": "Standard", "accelere": "Accéléré"}

## Ouvre la fenêtre du joueur `id` sur `page` (toile de l'écran). `retour` : élément à qui rendre le focus.
static func ouvrir(page: Control, app: Control, id: String, retour: Control = null) -> void:
	var j := _joueur(app, id)
	if j.is_empty(): return
	var d := donnees(app.model, j)
	var apres := func(): if is_instance_valid(retour) and retour.is_visible_in_tree(): retour.grab_focus()
	var fond := Fenetre.ouvrir(page, NOM, "BLESSURE", "heart", LARGEUR, HAUTEUR, apres)
	fond.set_meta("player_id", id)
	_contenu(fond, page, app, j, d)

## Fenêtre posée sur un écran plein (salle médicale) : un hôte centré porte la toile du gabarit.
static func ouvrir_sur_salle(salle: Control, app: Control, id: String, retour: Control = null) -> void:
	var hote := salle.get_node_or_null("FenetreBlessureHote") as Control
	if hote == null:
		hote = Control.new()
		hote.name = "FenetreBlessureHote"
		hote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		salle.add_child(hote)
	var largeur := 2248.0 * C.density
	hote.position = Vector2(maxf(0.0, (salle.size.x - largeur) / 2.0), maxf(0.0, (salle.size.y - 1230.0 * C.density) / 2.0))
	hote.size = Vector2(largeur, 1230.0 * C.density)
	ouvrir(hote, app, id, retour)

static func _joueur(app: Control, id: String) -> Dictionary:
	for p: Variant in app.model.get("squad", []):
		if p is Dictionary and str(p.get("id", "")) == id: return p
	return {}

# ---------------------------------------------------------------- données (moteur)

static func _n(v: Variant, defaut: float = -1.0) -> float:
	return float(v) if (v is int or v is float) and is_finite(float(v)) else defaut

static func _date(model: Dictionary, jours: int) -> String:
	var meta: Dictionary = model.get("meta", {})
	var aujourdhui := str(meta.get("calendarToday", meta.get("date", "")))
	if aujourdhui.length() < 10: return ""
	var instant := Time.get_unix_time_from_datetime_string(aujourdhui.substr(0, 10) + "T00:00:00")
	if instant <= 0: return ""
	var date := Time.get_datetime_dict_from_unix_time(int(instant) + jours * 86400)
	return "%02d/%02d" % [date.day, date.month]

static func _jj_mm(iso: String) -> String:
	return "%s/%s" % [iso.substr(8, 2), iso.substr(5, 2)] if iso.length() >= 10 else ""

static func _pourcent(v: float) -> String:
	return (("%d" % roundi(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v).replace(".", ",")) + " %"

## Tout ce que la fenêtre affiche, calculé une fois (et lisible par les tests).
static func donnees(model: Dictionary, j: Dictionary) -> Dictionary:
	var d := {}
	var semaines := ceili(maxf(0.0, _n(j.get("injury"), 0.0)))
	d.semaines = semaines
	d.type = str(j.get("injuryType", ""))
	d.libelle = str(preload("res://ui/club_mail.gd").injury_label(model, j))
	d.retour = _date(model, semaines * 7)
	var commotion: Variant = j.get("commotion")
	if commotion is Dictionary and bool(commotion.get("enCours", false)) and str(commotion.get("retour", "")).length() >= 10:
		d.retour = _jj_mm(str(commotion.retour))
	d.depuis = _jj_mm(str(j.get("injuryDate", "")))
	d.cause = str(j.get("injuryCause", ""))
	var suivi := {}
	for row: Variant in model.get("clubLife", {}).get("clubSupport", {}).get("medical", {}).get("players", []):
		if row is Dictionary and str(row.get("id", "")) == str(j.get("id", "")): suivi = row
	d.protocole = str(suivi.get("protocol", ""))
	# Côté touché : stable par joueur (le moteur ne le tire pas).
	d.droite = hash(str(j.get("id", "")) + ":cote") % 2 == 0
	var zone: Dictionary = ZONES.get(d.type, {})
	var mot := str(zone.get("mot", ""))
	d.zone = mot
	if not zone.is_empty() and bool(zone.cote):
		var masculin := mot in ["Genou", "Mollet", "Ischios"]
		d.zone = mot + (" droit" if masculin else " droite") if d.droite else mot + " gauche"
	# Les jauges.
	var condition := _n(j.get("condition"))
	var fatigue := _n(j.get("physicalLoad"))
	if j.get("physicalLoad") is Dictionary: fatigue = _n(j.physicalLoad.get("fatigue"))
	var minutes := _n(j.get("minutes"), 0.0)
	var matchs := int(_n(j.get("appearances"), 0.0))
	var max_minutes := 1.0
	for p: Variant in model.get("squad", []):
		if p is Dictionary: max_minutes = maxf(max_minutes, _n(p.get("minutes"), 0.0))
	var plan := str(j.get("loadPlan", "collective"))
	if semaines > 0: plan = "repos"  # un blessé est au repos pendant la séance (moteur : physicalModeFor)
	var jauges: Array = []
	jauges.append(_jauge("forme", "Forme", "heart", Charte.CONDITION, condition / 100.0, "%d" % roundi(condition) if condition >= 0 else "?",
		"Affûté" if condition >= 90 else "Correct" if condition >= 75 else "Juste" if condition >= 60 else "Peu affûté"))
	var energie := 100.0 - fatigue if fatigue >= 0 else -1.0
	jauges.append(_jauge("energie", "Énergie", "clock", Charte.REPOS, energie / 100.0, "%d" % roundi(energie) if energie >= 0 else "?",
		"Frais" if energie >= 75 else "Entamé" if energie >= 50 else "Fatigué" if energie >= 30 else "Épuisé"))
	var ratio := minutes / max_minutes
	jauges.append(_jauge("match", "Charge en match", "ball", Charte.INTENSIF, ratio, "%d min" % roundi(minutes),
		"Légère" if ratio < .34 else "Moyenne" if ratio < .67 else "Lourde", "%d match%s" % [matchs, "s" if matchs > 1 else ""]))
	var niveaux := {"repos": [.25, "Repos", Charte.REPOS], "normal": [.5, "Normale", Charte.NORMAL], "collective": [.5, "Collectif", Charte.NORMAL], "intense": [1.0, "Intensive", Charte.INTENSIF]}
	var n: Array = niveaux.get(plan, niveaux.collective)
	jauges.append(_jauge("entrainement", "Charge à l'entraînement", "train", n[2], n[0], "", n[1]))
	# Fragilité (moteur : fragilite.cjs, 0 à 100) : module le risque de blessure de −25 % à +25 %.
	var fragilite := _n(j.get("fragilite"))
	jauges.append(_jauge("fragilite", "Fragilité", "shield", R.VIOLET, fragilite / 100.0, "%d" % roundi(fragilite) if fragilite >= 0 else "?",
		"Très solide" if fragilite < 20 else "Solide" if fragilite < 40 else "Dans la moyenne" if fragilite < 60 else "Fragile" if fragilite < 80 else "Très fragile",
		("%+d %% de risque" % roundi((fragilite - 50.0) * .5)) if fragilite >= 0 else ""))
	# Risque de blessure au prochain match (moteur : model.cjs risqueBlessure, règle d'après match × fragilité).
	var risque := _n(j.get("risqueBlessure"))
	jauges.append(_jauge("risque", "Risque de blessure", "warning", Charte.PERTE, risque / 8.75, _pourcent(risque) if risque >= 0 else "?",
		"Élevé" if risque >= 6 else "Moyen" if risque > 3 else "Faible", "prochain match"))
	# Risque de rechute à la guérison (moteur : model.cjs rechute, suivi du médecin × fragilité).
	if j.has("rechute"):
		var rechute := _n(j.get("rechute"), 0.0)
		jauges.append(_jauge("rechute", "Risque de rechute", "renew", Charte.PERTE, rechute / 25.0, _pourcent(rechute),
			"Aucun" if rechute <= 0 else "Élevé" if rechute >= 15 else "Moyen" if rechute >= 8 else "Faible", "au retour"))
	d.jauges = jauges
	return d

static func _jauge(id: String, titre: String, icone: String, couleur: Color, valeur: float, chiffre: String, mot: String, detail: String = "") -> Dictionary:
	var sans := valeur < 0.0
	return {"id": id, "titre": titre, "icone": icone, "couleur": GRIS if sans else couleur, "valeur": -1.0 if sans else clampf(valeur, 0.0, 1.0), "chiffre": chiffre, "mot": mot, "detail": detail}

# ---------------------------------------------------------------- destinations

static func _fiche(page: Control, app: Control, id: String) -> void:
	Fenetre.fermer(page, NOM)
	Panneaux._fiche(page, app, id)

static func _semaine(page: Control, app: Control) -> void:
	Fenetre.fermer(page, NOM)
	preload("res://ui/immersive08/shell.gd").open_training(app)

## Forme, énergie et entraînement → la Semaine (charge des séances) ; le reste → la fiche du joueur.
static func _action_jauge(page: Control, app: Control, id: String, jauge: Dictionary) -> Callable:
	if float(jauge.valeur) < 0.0: return Callable()
	if jauge.id in ["forme", "energie", "entrainement"]: return func(): _semaine(page, app)
	return func(): _fiche(page, app, id)

static func _bouton(parent: Control, rect: Rect2, action: Callable, id: String, aide: String) -> void:
	if not action.is_valid(): return
	var cible := Control.new()
	cible.name = id + "Zone"
	parent.add_child(cible)
	D.place(cible, rect)
	R.cliquable(cible, action, id, aide)

# ---------------------------------------------------------------- contenu

static func _contenu(fond: Panel, page: Control, app: Control, j: Dictionary, d: Dictionary) -> void:
	var id := str(j.get("id", ""))
	# Silhouettes face / dos, zone touchée en halo rouge.
	var cadre := D.rect(fond, Rect2(28, 92, 470, HAUTEUR - 120), Charte.PANNEAU_3, Charte.RAYON_CARTE)
	cadre.name = "FenetreBlessureCorps"
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_silhouette(cadre, Rect2(22, 30, 205, 492), d, "F")
	_silhouette(cadre, Rect2(243, 30, 205, 492), d, "B")
	D.text(cadre, 124, 556, "FACE", 18, Charte.IVOIRE_3, 700, 120, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(cadre, 345, 556, "DOS", 18, Charte.IVOIRE_3, 700, 120, HORIZONTAL_ALIGNMENT_CENTER)
	if not d.zone.is_empty():
		var p := R.pastille(cadre, 0, 640, "✚ " + d.zone, R.ROUGE, "", "FenetreBlessureZoneCorps", 22)
		p.position.x = (470 * C.density - p.size.x) / 2.0
	# Droite : joueur, blessure, retour.
	var x := 530.0
	var l := LARGEUR - x - 36.0
	Panneaux._portrait(fond, j, Rect2(x, 96, 84, 84), R.ROUGE, 3)
	var nom := D.text(fond, x + 104, 134, str(j.get("name", "")).to_upper(), 32, Charte.IVOIRE, 700, l - 110)
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	nom.name = "FenetreBlessureNom"
	D.text(fond, x + 104, 170, str(j.get("pos", "")), 20, Charte.IVOIRE_2, 600, l - 110)
	_bouton(fond, Rect2(x - 6, 90, l, 96), func(): _fiche(page, app, id), "FenetreBlessureFiche", "Fiche du joueur")
	var titre := D.text(fond, x, 238, d.libelle.to_upper(), 34, R.ROUGE, 700, l)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "FenetreBlessureLibelle"
	var cx := x
	if CAUSES.has(d.cause):
		cx += R.pastille(fond, cx, 284, CAUSES[d.cause][0], R.ORANGE, CAUSES[d.cause][1], "FenetreBlessureCause", 21).size.x / C.density + 10
	if PROTOCOLES.has(d.protocole):
		R.pastille(fond, cx, 284, PROTOCOLES[d.protocole], R.BLEU, "heart", "FenetreBlessureProtocole", 21)
	# Retour : gros chiffre + date + une case par semaine restante.
	R.tuile(fond, Rect2(x, 312, 330, 84), str(d.semaines), "sem. · retour " + (d.retour if not d.retour.is_empty() else "?"), R.ROUGE, "FenetreBlessureRetour", 46, true)
	var cases := mini(d.semaines, 12)
	for i in cases:
		var cse := D.rect(fond, Rect2(x + 350 + i * 36, 336, 28, 36), Color(R.ROUGE, 1.0 - .5 * float(i) / maxf(1.0, cases)), 4)
		cse.name = "FenetreBlessureSemaine%d" % (i + 1)
	if d.semaines > 12: D.text(fond, x + 350 + 12 * 36, 362, "+%d" % (d.semaines - 12), 20, R.ROUGE, 700, 60)
	if not d.depuis.is_empty(): D.text(fond, x + 350, 392, "depuis le " + d.depuis, 17, Charte.IVOIRE_3, 600, 260)
	# Jauges en lignes (grammaire de l'Effectif : libellé, barre, mot coloré, chiffre).
	var y := 424.0
	D.line(fond, Vector2(x, y - 4), Vector2(x + l, y - 4), Charte.FILET, 1)
	for jauge: Dictionary in d.jauges:
		var ligne := Control.new()
		ligne.name = "FenetreBlessureJauge_" + str(jauge.id)
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fond.add_child(ligne)
		D.place(ligne, Rect2(x, y, l, LIGNE))
		var ic := C.icon(str(jauge.icone), 24, jauge.couleur)
		ligne.add_child(ic)
		D.place(ic, Rect2(6, 14, 24, 24))
		D.text(ligne, 42, 34, str(jauge.titre), 21, Charte.IVOIRE_2, 600, 230)
		_segments(ligne, Rect2(270, 17, 190, 18), float(jauge.valeur), jauge.couleur, 7)
		D.text(ligne, 478, 34, str(jauge.mot), 22, jauge.couleur if float(jauge.valeur) >= 0 else Charte.IVOIRE_3, 700, 150)
		var droite := str(jauge.chiffre) + (" · " + str(jauge.detail) if not str(jauge.detail).is_empty() else "")
		D.text(ligne, l - 8, 34, droite, 19, Charte.IVOIRE_3, 600, 170, HORIZONTAL_ALIGNMENT_RIGHT)
		D.line(ligne, Vector2(0, LIGNE - 1), Vector2(l, LIGNE - 1), Charte.FILET, 1)
		_bouton(ligne, Rect2(0, 0, l, LIGNE), _action_jauge(page, app, id, jauge), "FenetreBlessureJaugeClic_" + str(jauge.id), str(jauge.titre) + " · " + str(jauge.mot))
		y += LIGNE

static func _segments(parent: Control, rect: Rect2, valeur: float, couleur: Color, nombre: int) -> void:
	var ecart := 6.0
	var w := (rect.size.x - ecart * (nombre - 1)) / float(nombre)
	var pleins := 0 if valeur <= 0 else maxi(1, roundi(valeur * nombre))
	for i in nombre:
		var seg := D.rect(parent, Rect2(rect.position.x + i * (w + ecart), rect.position.y, w, rect.size.y), couleur if i < pleins else Charte.PANNEAU_3.lightened(.06), 4)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ---------------------------------------------------------------- silhouette

## Point de la zone dans le dessin tel qu'affiché (dos : dessin retourné), ou (-1, -1) si la vue ne la montre pas.
static func point_zone(type: String, droite: bool, vue: String) -> Vector2:
	var zone: Dictionary = ZONES.get(type, {})
	if zone.is_empty() or not str(zone.vue).contains(vue): return Vector2(-1, -1)
	var p: Vector2 = zone.d if droite else zone.g
	return p if vue == "F" else Vector2(Silhouette.TAILLE.x - p.x, p.y)

static func _silhouette(parent: Control, rect: Rect2, d: Dictionary, vue: String) -> void:
	var s := Silhouette.new()
	s.name = "FenetreBlessureSilhouette" + vue
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.dos = vue == "B"
	s.point = point_zone(d.type, bool(d.droite), vue)
	s.rayon = float(ZONES.get(d.type, {}).get("r", 0.0))
	parent.add_child(s)
	D.place(s, rect)

## Silhouette de rugbyman (art/corps/corps-rugbyman.svg) ajustée au cadre, retournée pour le dos, quelques repères
## (clavicules et ligne du torse de face ; colonne et omoplates de dos) et la zone touchée en halo rouge.
class Silhouette extends Control:
	const TAILLE := Vector2(752, 1584)
	const TRAIT := Color("7c8a85")
	var dos := false
	var point := Vector2(-1, -1)
	var rayon := 0.0

	func _draw() -> void:
		var k := minf(size.x / TAILLE.x, size.y / TAILLE.y)
		var o := (size - TAILLE * k) / 2.0
		var v := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * k
		if dos:
			draw_set_transform(Vector2(o.x * 2.0 + TAILLE.x * k, 0), 0.0, Vector2(-1, 1))
			draw_texture_rect(CORPS, Rect2(o, TAILLE * k), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(CORPS, Rect2(o, TAILLE * k), false)
		var e := maxf(1.0, 5.0 * k)
		if dos:
			draw_line(v.call(395, 250), v.call(395, 740), TRAIT, e)
			draw_arc(v.call(320, 400), 70 * k, PI * .15, PI * 1.05, 16, TRAIT, e)
			draw_arc(v.call(470, 400), 70 * k, -PI * .05, PI * .85, 16, TRAIT, e)
		else:
			draw_line(v.call(300, 262), v.call(388, 280), TRAIT, e)
			draw_line(v.call(490, 262), v.call(402, 280), TRAIT, e)
			draw_line(v.call(395, 430), v.call(395, 720), TRAIT, e)
			draw_arc(v.call(330, 390), 75 * k, PI * .1, PI * .9, 16, TRAIT, e)
			draw_arc(v.call(460, 390), 75 * k, PI * .1, PI * .9, 16, TRAIT, e)
		if point.x < 0: return
		var c: Vector2 = v.call(point.x, point.y)
		var rouge := Color("d9634f")
		for i in 6:
			draw_circle(c, rayon * k * (1.0 + .3 * (5 - i)), Color(rouge, .08 + .06 * i))
		draw_circle(c, rayon * k * .45, rouge)
