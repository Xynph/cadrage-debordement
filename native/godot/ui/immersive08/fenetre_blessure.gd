extends RefCounted
## Petite fenêtre « blessure » (revue FM27, idée 3) : silhouette face / dos avec la zone touchée, retour prévu et six
## jauges (forme, énergie, charge en match, charge à l'entraînement, fragilité, risque). Ouverte par un clic sur la
## pastille Blessé (Effectif, salle médicale). Cadre commun fenetre_visuelle.gd : Échap, ✕ et clic à côté la ferment.
## Deux présentations à trancher par Léo (CD_VARIANTE_VISUELLE) :
##   A : dossier en lignes (silhouettes à gauche, jauges segmentées en lignes comme l'Effectif) ;
##   B : corps et frise (grand corps, frise des semaines jusqu'au retour, six anneaux en rangée).
## Données lues telles que le moteur les envoie (`app.model.squad`, `clubLife.clubSupport.medical`) ; une jauge sans
## donnée du moteur reste grise avec « ? » (fragilité : aucune donnée exposée).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Charte = preload("res://ui/charte.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Panneaux = preload("res://ui/immersive08/panneaux_effectif.gd")

const NOM := "FenetreBlessure"
const GRIS := Color("5d6866")

## Zone touchée par type de blessure (données club-mail.json « blessures.types ») : point du corps (unités 100 × 240,
## côté droit du joueur vu de face), vue (F face, B dos, FB les deux), rayon, libellé court.
const ZONES := {
	"commotion": {"p": Vector2(50, 17), "vue": "FB", "r": 15.0, "mot": "Tête", "cote": false},
	"cou": {"p": Vector2(50, 35), "vue": "FB", "r": 9.0, "mot": "Cou", "cote": false},
	"epaule": {"p": Vector2(29, 45), "vue": "FB", "r": 11.0, "mot": "Épaule", "cote": true},
	"cotes": {"p": Vector2(38, 86), "vue": "F", "r": 13.0, "mot": "Côtes", "cote": true},
	"contusion": {"p": Vector2(42, 148), "vue": "F", "r": 14.0, "mot": "Cuisse", "cote": true},
	"ischios": {"p": Vector2(42, 152), "vue": "B", "r": 14.0, "mot": "Ischios", "cote": true},
	"genou": {"p": Vector2(42, 180), "vue": "F", "r": 10.0, "mot": "Genou", "cote": true},
	"croises": {"p": Vector2(42, 180), "vue": "FB", "r": 11.0, "mot": "Genou", "cote": true},
	"mollet": {"p": Vector2(42, 200), "vue": "B", "r": 11.0, "mot": "Mollet", "cote": true},
	"cheville": {"p": Vector2(42, 225), "vue": "FB", "r": 8.0, "mot": "Cheville", "cote": true},
}
const CAUSES := {"match": ["Match", "ball"], "entrainement": ["Entraînement", "train"], "rechute": ["Rechute", "renew"]}
const PROTOCOLES := {"prudent": "Prudent", "standard": "Standard", "accelere": "Accéléré"}

## Ouvre la fenêtre du joueur `id` sur `page` (toile de l'écran). `retour` : élément à qui rendre le focus.
static func ouvrir(page: Control, app: Control, id: String, retour: Control = null) -> void:
	var j := _joueur(app, id)
	if j.is_empty(): return
	var d := donnees(app.model, j)
	var b := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper() == "B"
	var apres := func(): if is_instance_valid(retour) and retour.is_visible_in_tree(): retour.grab_focus()
	var fond := Fenetre.ouvrir(page, NOM, "BLESSURE", "heart", 1360, 820 if b else 780, apres)
	fond.set_meta("variante", "B" if b else "A")
	fond.set_meta("player_id", id)
	if b: _variante_b(fond, page, app, j, d)
	else: _variante_a(fond, page, app, j, d)

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
	d.zone = (str(zone.mot) + ((" droit" if zone.mot in ["Genou", "Mollet", "Cou"] else " droite") if d.droite else (" gauche"))) if not zone.is_empty() and bool(zone.cote) else str(zone.get("mot", ""))
	if d.zone in ["Genou droite", "Ischios droite"]: d.zone = d.zone.replace("droite", "droit")
	# Les six jauges.
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
	jauges.append(_jauge("fragilite", "Fragilité", "shield", GRIS, -1.0, "?", "Pas de donnée"))
	# Risque : règle du moteur après un match (rugby.js : 7 % sous 55 de condition, 2,5 % sinon, au prorata des
	# minutes) et 1,8 % par séance intensive (game.js).
	var risque := (7.0 if condition >= 0 and condition < 55 else 2.5) + (1.8 if plan == "intense" else 0.0)
	jauges.append(_jauge("risque", "Risque", "warning", Charte.PERTE, clampf(risque / 8.8, 0.0, 1.0), ("%.1f %%" % risque).replace(".", ","),
		"Élevé" if risque >= 7 else "Moyen" if risque > 3 else "Normal", "par match"))
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

# ---------------------------------------------------------------- pièces communes

static func _entete(fond: Panel, page: Control, app: Control, j: Dictionary, x: float, y: float, largeur: float) -> void:
	Panneaux._portrait(fond, j, Rect2(x, y, 84, 84), R.ROUGE, 3)
	var nom := D.text(fond, x + 104, y + 38, str(j.get("name", "")).to_upper(), 32, Charte.IVOIRE, 700, largeur - 110)
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	nom.name = "FenetreBlessureNom"
	D.text(fond, x + 104, y + 74, str(j.get("pos", "")), 20, Charte.IVOIRE_2, 600, largeur - 110)
	var id := str(j.get("id", ""))
	_bouton(fond, Rect2(x - 6, y - 6, largeur, 96), func(): _fiche(page, app, id), "FenetreBlessureFiche", "Fiche du joueur")

static func _pastilles(fond: Control, d: Dictionary, x: float, base: float) -> float:
	var cx := x
	if not d.zone.is_empty():
		cx += R.pastille(fond, cx, base, "✚ " + d.zone, R.ROUGE, "", "FenetreBlessureZone", 21).size.x / C.density + 10
	if CAUSES.has(d.cause):
		cx += R.pastille(fond, cx, base, CAUSES[d.cause][0], R.ORANGE, CAUSES[d.cause][1], "FenetreBlessureCause", 21).size.x / C.density + 10
	if PROTOCOLES.has(d.protocole):
		cx += R.pastille(fond, cx, base, PROTOCOLES[d.protocole], R.BLEU, "heart", "FenetreBlessureProtocole", 21).size.x / C.density + 10
	return cx

static func _segments(parent: Control, rect: Rect2, valeur: float, couleur: Color, nombre: int) -> void:
	var ecart := 6.0
	var w := (rect.size.x - ecart * (nombre - 1)) / float(nombre)
	var pleins := 0 if valeur < 0 else maxi(1, roundi(valeur * nombre))
	for i in nombre:
		var plein := i < pleins
		var seg := D.rect(parent, Rect2(rect.position.x + i * (w + ecart), rect.position.y, w, rect.size.y), couleur if plein else Charte.PANNEAU_3, 4)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if valeur < 0 and i == 0: seg.self_modulate = Color(1, 1, 1, .6)

# ---------------------------------------------------------------- A : dossier en lignes

static func _variante_a(fond: Panel, page: Control, app: Control, j: Dictionary, d: Dictionary) -> void:
	# Silhouettes face / dos.
	var cadre := D.rect(fond, Rect2(28, 92, 470, 660), Charte.PANNEAU_3, Charte.RAYON_CARTE)
	cadre.name = "FenetreBlessureCorps"
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_silhouette(cadre, Rect2(28, 40, 190, 456), d, "F")
	_silhouette(cadre, Rect2(252, 40, 190, 456), d, "B")
	D.text(cadre, 123, 532, "FACE", 18, Charte.IVOIRE_3, 700, 120, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(cadre, 347, 532, "DOS", 18, Charte.IVOIRE_3, 700, 120, HORIZONTAL_ALIGNMENT_CENTER)
	if not d.zone.is_empty():
		var p := R.pastille(cadre, 0, 600, "✚ " + d.zone, R.ROUGE, "", "FenetreBlessureZoneCorps", 22)
		p.position.x = (470 * C.density - p.size.x) / 2.0
	# Droite : joueur, blessure, retour.
	var x := 530.0
	var l := 1360.0 - x - 36.0
	_entete(fond, page, app, j, x, 96, l)
	var titre := D.text(fond, x, 238, d.libelle.to_upper(), 34, R.ROUGE, 700, l)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "FenetreBlessureLibelle"
	_pastilles(fond, d, x, 284)
	# Retour : gros chiffre + date + une case par semaine restante.
	var retour := R.tuile(fond, Rect2(x, 312, 330, 84), str(d.semaines), "sem. · retour " + (d.retour if not d.retour.is_empty() else "?"), R.ROUGE, "FenetreBlessureRetour", 46, true)
	retour.name = "FenetreBlessureRetour"
	var cases := mini(d.semaines, 12)
	for i in cases:
		var cse := D.rect(fond, Rect2(x + 350 + i * 36, 336, 28, 36), Color(R.ROUGE, 1.0 - .5 * float(i) / maxf(1.0, cases)), 4)
		cse.name = "FenetreBlessureSemaine%d" % (i + 1)
	if d.semaines > 12: D.text(fond, x + 350 + 12 * 36, 362, "+%d" % (d.semaines - 12), 20, R.ROUGE, 700, 60)
	if not d.depuis.is_empty(): D.text(fond, x + 350, 392, "depuis le " + d.depuis, 17, Charte.IVOIRE_3, 600, 260)
	# Six jauges en lignes (grammaire de l'Effectif : libellé, barre, mot coloré, chiffre).
	var y := 424.0
	D.line(fond, Vector2(x, y - 4), Vector2(x + l, y - 4), Charte.FILET, 1)
	for jauge: Dictionary in d.jauges:
		var ligne := Control.new()
		ligne.name = "FenetreBlessureJauge_" + str(jauge.id)
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fond.add_child(ligne)
		D.place(ligne, Rect2(x, y, l, 54))
		var ic := C.icon(str(jauge.icone), 24, jauge.couleur)
		ligne.add_child(ic)
		D.place(ic, Rect2(6, 15, 24, 24))
		D.text(ligne, 42, 35, str(jauge.titre), 21, Charte.IVOIRE_2, 600, 250)
		_segments(ligne, Rect2(270, 18, 200, 18), float(jauge.valeur), jauge.couleur, 7)
		D.text(ligne, 488, 35, str(jauge.mot), 22, jauge.couleur if float(jauge.valeur) >= 0 else Charte.IVOIRE_3, 700, 140)
		var droite := str(jauge.chiffre) + (" · " + str(jauge.detail) if not str(jauge.detail).is_empty() else "")
		D.text(ligne, l - 8, 35, droite, 19, Charte.IVOIRE_3, 600, 160, HORIZONTAL_ALIGNMENT_RIGHT)
		if float(jauge.valeur) < 0: R.rond(ligne, 636, 27, "Le moteur n'envoie pas cette donnée", "i", "FenetreBlessureSansDonnee")
		D.line(ligne, Vector2(0, 53), Vector2(l, 53), Charte.FILET, 1)
		_bouton(ligne, Rect2(0, 0, l, 54), _action_jauge(page, app, str(j.get("id", "")), jauge), "FenetreBlessureJaugeClic_" + str(jauge.id), str(jauge.titre))
		y += 54.0

# ---------------------------------------------------------------- B : corps et frise

static func _variante_b(fond: Panel, page: Control, app: Control, j: Dictionary, d: Dictionary) -> void:
	_entete(fond, page, app, j, 36, 90, 600)
	var titre := D.text(fond, 1324, 130, d.libelle.to_upper(), 36, R.ROUGE, 700, 640, HORIZONTAL_ALIGNMENT_RIGHT)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "FenetreBlessureLibelle"
	var px := 1324.0
	# Pastilles alignées à droite sous le libellé.
	var tmp := Control.new()
	fond.add_child(tmp)
	var fin := _pastilles(tmp, d, 0, 0)
	tmp.queue_free()
	_pastilles(fond, d, px - fin + 10, 172)
	# Corps : face et dos côte à côte, grands, avec la zone reliée à son nom.
	var corps := D.rect(fond, Rect2(36, 200, 560, 400), Charte.PANNEAU_3, Charte.RAYON_CARTE)
	corps.name = "FenetreBlessureCorps"
	corps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_silhouette(corps, Rect2(40, 14, 150, 360), d, "F")
	_silhouette(corps, Rect2(230, 14, 150, 360), d, "B")
	D.text(corps, 75, 392, "FACE", 16, Charte.IVOIRE_3, 700, 80)
	D.text(corps, 272, 392, "DOS", 16, Charte.IVOIRE_3, 700, 80)
	if not d.zone.is_empty():
		var zone: Dictionary = ZONES.get(d.type, {})
		var vue := "F" if str(zone.vue).contains("F") else "B"
		var pt := _point(zone, d, vue)
		var origine := Vector2(40 if vue == "F" else 230, 14) + Vector2(pt.x * 1.5, pt.y * 1.5)
		D.line(corps, origine, Vector2(412, origine.y), R.ROUGE, 2)
		var etiquette := D.text(corps, 420, origine.y + 9, d.zone.to_upper(), 26, R.ROUGE, 700, 140)
		etiquette.add_theme_font_override("font", Charte.TITRE_FICHE)
		etiquette.name = "FenetreBlessureZoneCorps"
	# Frise du retour : une case par semaine, d'aujourd'hui au retour.
	var fx := 630.0
	var fl := 1324.0 - fx
	var gros := D.text(fond, fx, 330, str(d.semaines), 120, R.ROUGE, 700, 200)
	gros.add_theme_font_override("font", Charte.TITRE_FICHE)
	gros.name = "FenetreBlessureSemaines"
	var gw := R.largeur(str(d.semaines), 120, 700) + 24
	D.text(fond, fx + gw, 262, "SEMAINES", 26, Charte.IVOIRE, 700, 260).add_theme_font_override("font", Charte.TITRE_FICHE)
	var r := R.pastille(fond, fx + gw, 316, "⧗ Retour " + (d.retour if not d.retour.is_empty() else "?"), R.ORANGE, "", "FenetreBlessureRetour", 24)
	r.name = "FenetreBlessureRetourFond"
	var n := clampi(d.semaines, 1, 10)
	var cw := (fl - 8.0 * (n - 1)) / float(n)
	for i in n:
		var cx := fx + i * (cw + 8.0)
		var derniere := i == n - 1
		var cse := D.rect(fond, Rect2(cx, 380, cw, 54), Color(R.ROUGE, .85) if not derniere else Color(R.ORANGE, .85), 6)
		cse.name = "FenetreBlessureSemaine%d" % (i + 1)
		cse.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(cse, cw / 2.0, 36, ("S%d" % (i + 1)) if not derniere else "✓", 20, Charte.NUIT, 800, cw, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(fond, fx, 466, "▲ " + (("blessé le " + d.depuis) if not d.depuis.is_empty() else "aujourd'hui"), 18, Charte.IVOIRE_3, 600, 300)
	if not d.retour.is_empty():
		D.text(fond, fx + fl, 466, d.retour + " ▲", 18, R.ORANGE, 700, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	if d.semaines > 10: D.text(fond, fx + fl / 2.0 - 60, 466, "1 case ≈ %d sem." % ceili(d.semaines / 10.0), 18, Charte.IVOIRE_3, 600, 160)
	# Six anneaux.
	var ay := 628.0
	var aw := (1360.0 - 72.0) / 6.0
	for i: int in range(d.jauges.size()):
		var jauge: Dictionary = d.jauges[i]
		var ax := 36.0 + i * aw
		var bloc := Control.new()
		bloc.name = "FenetreBlessureJauge_" + str(jauge.id)
		bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fond.add_child(bloc)
		D.place(bloc, Rect2(ax, ay, aw, 176))
		var anneau := Anneau.new()
		anneau.valeur = float(jauge.valeur)
		anneau.couleur = jauge.couleur
		anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bloc.add_child(anneau)
		D.place(anneau, Rect2(aw / 2.0 - 46, 0, 92, 92))
		var chiffre := str(jauge.chiffre) if not str(jauge.chiffre).is_empty() else str(jauge.mot).substr(0, 3)
		var ch := D.text(anneau, 46, 54, chiffre.replace(" min", "'").replace(" %", "%"), 26, Charte.IVOIRE if float(jauge.valeur) >= 0 else Charte.IVOIRE_3, 800, 92, HORIZONTAL_ALIGNMENT_CENTER)
		ch.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		D.text(bloc, aw / 2.0, 126, str(jauge.titre).to_upper(), 16, Charte.IVOIRE_2, 700, aw - 8, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(bloc, aw / 2.0, 156, str(jauge.mot), 21, jauge.couleur if float(jauge.valeur) >= 0 else Charte.IVOIRE_3, 700, aw - 8, HORIZONTAL_ALIGNMENT_CENTER)
		if float(jauge.valeur) < 0: bloc.tooltip_text = "Le moteur n'envoie pas cette donnée"
		_bouton(bloc, Rect2(6, 0, aw - 12, 172), _action_jauge(page, app, str(j.get("id", "")), jauge), "FenetreBlessureJaugeClic_" + str(jauge.id), str(jauge.titre) + " · " + str(jauge.mot) + (" · " + str(jauge.detail) if not str(jauge.detail).is_empty() else ""))

# ---------------------------------------------------------------- dessins

static func _point(zone: Dictionary, d: Dictionary, vue: String) -> Vector2:
	var p: Vector2 = zone.p
	if not bool(zone.cote): return p
	# Côté droit du joueur : à gauche vu de face, à droite vu de dos.
	var a_gauche := bool(d.droite) == (vue == "F")
	return Vector2(p.x if a_gauche else 100.0 - p.x, p.y)

static func _silhouette(parent: Control, rect: Rect2, d: Dictionary, vue: String) -> void:
	var s := Silhouette.new()
	s.name = "FenetreBlessureSilhouette" + vue
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.vue = vue
	var zone: Dictionary = ZONES.get(d.type, {})
	if not zone.is_empty() and str(zone.vue).contains(vue):
		s.point = _point(zone, d, vue)
		s.rayon = float(zone.r)
	parent.add_child(s)
	D.place(s, rect)

## Corps stylisé (unités 100 × 240), face ou dos, et la zone touchée en halo rouge.
class Silhouette extends Control:
	var vue := "F"
	var point := Vector2(-1, -1)
	var rayon := 0.0
	const CORPS := Color("3a4645")
	const TRAIT := Color("56625f")

	func _k() -> float: return minf(size.x / 100.0, size.y / 240.0)
	func _o() -> Vector2: return Vector2((size.x - 100.0 * _k()) / 2.0, (size.y - 240.0 * _k()) / 2.0)
	func _v(x: float, y: float) -> Vector2: return _o() + Vector2(x, y) * _k()
	func _poly(points: Array, couleur: Color) -> void:
		var pts := PackedVector2Array()
		for p: Vector2 in points: pts.append(_v(p.x, p.y))
		draw_colored_polygon(pts, couleur)
	func _membre(points: Array) -> void:
		_poly(points, CORPS)
		var miroir: Array = []
		for p: Vector2 in points: miroir.append(Vector2(100.0 - p.x, p.y))
		_poly(miroir, CORPS)

	func _draw() -> void:
		var k := _k()
		draw_circle(_v(50, 17), 12.5 * k, CORPS)
		_poly([Vector2(44, 27), Vector2(56, 27), Vector2(57, 40), Vector2(43, 40)], CORPS)
		_poly([Vector2(27, 40), Vector2(73, 40), Vector2(76, 48), Vector2(70, 104), Vector2(66, 126), Vector2(34, 126), Vector2(30, 104), Vector2(24, 48)], CORPS)
		_membre([Vector2(25, 41), Vector2(17, 47), Vector2(12, 98), Vector2(19, 100), Vector2(27, 62)])
		_membre([Vector2(12, 98), Vector2(19, 100), Vector2(15, 140), Vector2(9, 140)])
		draw_circle(_v(11.5, 145), 5.0 * k, CORPS)
		draw_circle(_v(88.5, 145), 5.0 * k, CORPS)
		_membre([Vector2(34, 122), Vector2(50, 126), Vector2(49, 176), Vector2(37, 176)])
		_membre([Vector2(37, 176), Vector2(49, 176), Vector2(47, 224), Vector2(39, 224)])
		_membre([Vector2(36, 223), Vector2(48, 223), Vector2(49, 233), Vector2(33, 233)])
		# Repères : clavicules et ligne blanche de face, colonne et omoplates de dos.
		if vue == "F":
			draw_line(_v(36, 44), _v(48, 46), TRAIT, maxf(1.0, k * .8))
			draw_line(_v(64, 44), _v(52, 46), TRAIT, maxf(1.0, k * .8))
			draw_line(_v(50, 60), _v(50, 112), TRAIT, maxf(1.0, k * .6))
		else:
			draw_line(_v(50, 42), _v(50, 122), TRAIT, maxf(1.0, k * .8))
			draw_arc(_v(40, 58), 8 * k, PI * .2, PI * 1.1, 12, TRAIT, maxf(1.0, k * .6))
			draw_arc(_v(60, 58), 8 * k, -PI * .1, PI * .8, 12, TRAIT, maxf(1.0, k * .6))
		if point.x >= 0:
			var rouge := Color("d9634f")
			for i in 5:
				draw_circle(_v(point.x, point.y), (rayon * (1.0 + .28 * (4 - i))) * k, Color(rouge, .10 + .06 * i))
			draw_circle(_v(point.x, point.y), rayon * .55 * k, rouge)

## Anneau de jauge : rail sombre, arc de la couleur de la donnée ; sans donnée, rail pointillé gris.
class Anneau extends Control:
	var valeur := 0.0
	var couleur := Color.WHITE
	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 6.0
		var e := maxf(4.0, r * .2)
		if valeur < 0:
			for i in 24:
				if i % 2 == 0: draw_arc(c, r, TAU * i / 24.0, TAU * (i + 1) / 24.0, 4, Color("5d6866"), e * .6)
			return
		draw_arc(c, r, 0, TAU, 48, Color("222a2b"), e)
		if valeur > 0: draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * maxf(.02, valeur), 48, couleur, e, true)
