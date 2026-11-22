extends RefCounted
## Intensité d'entraînement automatique par forme (revue FM27, idée 13 « intensite-auto », planche A/B du 22/11/2026).
## Onglet Individuel de l'Entraînement, sous CD_VARIANTE_VISUELLE=A|B (hors variante : écran habituel).
##  - A « Règle en tête » : 5 niveaux de forme (cœurs colorés) avec l'intensité choisie pour chacun, liste de l'effectif
##    (forme, charge, fragilité, risque, avis du kiné, intensité appliquée), colonne des 5 niveaux de risque à droite.
##  - B « Risques d'abord » : 5 onglets de risque, règle en colonne à gauche (3 choix en ligne par niveau), liste du
##    niveau choisi avec le facteur principal et le choix de l'intensité directement dans la ligne.
## Données du moteur : condition, physicalLoad (fatigue), loadPlan (charge individuelle, commande set_player_load),
## fragilite et risqueBlessure (fragilite.cjs, model.cjs), injury. La règle par forme n'existe pas encore au moteur :
## gardée ici dans management_ui (planche), voir le retour de l'agent.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Fatigue = preload("res://ui/immersive08/fatigue_overview.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")

const FORMES := ["Très basse", "Basse", "Correcte", "Bonne", "Très bonne"]
const SEUILS_FORME := [60.0, 70.0, 80.0, 90.0]
const REGLE_DEFAUT := ["repos", "repos", "normal", "normal", "intense"]
const MODES := ["repos", "normal", "intense"]
const NOMS_MODE := {"repos":"Repos", "normal":"Normal", "intense":"Intensif", "collective":"Auto"}
const ICONES_MODE := {"repos":"renew", "normal":"train", "intense":"warning"}
const RISQUES := ["Très élevé", "Élevé", "Accru", "Normal", "Faible"]

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

# ---------------------------------------------------------------------------------------------- données
static func couleur_forme(niveau: int) -> Color:
	return [Charte.ATTRIBUT_0, Charte.ATTRIBUT_40, Charte.ATTRIBUT_55, Charte.ATTRIBUT_65, Charte.ATTRIBUT_85][clampi(niveau, 0, 4)]

static func couleur_risque(niveau: int) -> Color:
	return [Charte.PERTE, Charte.INTENSIF, Charte.ATTRIBUT_55, Charte.GRIS_VERT, Charte.GAIN][clampi(niveau, 0, 4)]

static func couleur_mode(mode: String) -> Color:
	return {"repos":Charte.REPOS, "normal":Charte.NORMAL, "intense":Charte.INTENSIF}.get(mode, Charte.GRIS_VERT)

static func niveau_forme(p: Dictionary) -> int:
	var c := float(p.get("condition", 0))
	var n := 0
	for s: float in SEUILS_FORME:
		if c >= s: n += 1
	return n

static func regles(app: Control) -> Array:
	var r: Variant = app.management_ui.get("intensite_auto_regles")
	if r is Array and r.size() == 5: return r
	app.management_ui.intensite_auto_regles = REGLE_DEFAUT.duplicate()
	return app.management_ui.intensite_auto_regles

static func auto(p: Dictionary) -> bool:
	return str(p.get("loadPlan", "collective")) == "collective" and float(p.get("injury", 0)) <= 0

## Intensité appliquée : blessé = repos (moteur), choix individuel sinon, sinon la règle de son niveau de forme.
static func intensite(app: Control, p: Dictionary) -> String:
	if float(p.get("injury", 0)) > 0: return "repos"
	var plan := str(p.get("loadPlan", "collective"))
	if plan in MODES: return plan
	return str(regles(app)[niveau_forme(p)])

## Avis du kiné : même règle que le moteur applique aux clubs de l'ordinateur (fatigue ≥ 55 ou condition < 60 → repos),
## plus l'intensif pour un joueur frais, en forme et solide.
static func kine(p: Dictionary) -> String:
	var charge := float(p.get("physicalLoad", 0))
	var condition := float(p.get("condition", 0))
	if float(p.get("injury", 0)) > 0 or charge >= 55 or condition < 60: return "repos"
	if charge < 25 and condition >= 85 and float(p.get("fragilite", 50)) < 60: return "intense"
	return "normal"

## Risque combiné (0 = très élevé … 4 = faible) : risque au prochain match du moteur, fatigue, intensité appliquée.
static func score_risque(app: Control, p: Dictionary) -> float:
	var base := float(p.get("risqueBlessure", 2.5))
	var mode := intensite(app, p)
	return base + float(p.get("physicalLoad", 0)) / 20.0 + (1.6 if mode == "intense" else -0.6 if mode == "repos" else 0.0)

static func niveau_risque(app: Control, p: Dictionary) -> int:
	var s := score_risque(app, p)
	return 0 if s >= 8.0 else 1 if s >= 6.0 else 2 if s >= 4.6 else 3 if s >= 3.2 else 4

## Facteur principal du risque : [mot, icône].
static func facteur(app: Control, p: Dictionary) -> Array:
	if float(p.get("injury", 0)) > 0: return ["Blessé", "heart"]
	if float(p.get("condition", 100)) < 60: return ["Condition", "heart"]
	if float(p.get("physicalLoad", 0)) >= 45: return ["Fatigue", "hourglass"]
	if intensite(app, p) == "intense": return ["Intensif", "warning"]
	if float(p.get("fragilite", 50)) >= 65: return ["Fragilité", "shield"]
	return ["Aucun", "check"]

# ---------------------------------------------------------------------------------------------- petits éléments
static func _coeur(parent: Node, rectangle: Rect2, niveau: int) -> void:
	var fond := D.rect(parent, Rect2(rectangle.position, rectangle.size), Color(couleur_forme(niveau), .18), int(rectangle.size.x / 2.0))
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icone := C.icon("heart", int(rectangle.size.x * .68), couleur_forme(niveau))
	parent.add_child(icone)
	var m := rectangle.size.x * .16
	D.place(icone, Rect2(rectangle.position + Vector2(m, m), rectangle.size - Vector2(m, m) * 2))

static func _zone(parent: Node, rectangle: Rect2, id: String, bulle: String, action: Callable) -> Button:
	var zone := Button.new()
	zone.name = id
	zone.focus_mode = Control.FOCUS_ALL
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zone.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 6, 0))
	for etat in ["hover", "pressed", "hover_pressed"]: zone.add_theme_stylebox_override(etat, C.box(Color(1, 1, 1, .07), Color.TRANSPARENT, 6, 0))
	zone.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, Charte.DORE, 6, 0))
	zone.tooltip_text = bulle
	zone.accessibility_name = bulle
	zone.pressed.connect(action)
	parent.add_child(zone)
	D.place(zone, rectangle)
	return zone

## Pilule d'intensité : voile de la couleur, icône + mot ; pleine si `plein`.
static func _pilule(parent: Node, rectangle: Rect2, mode: String, plein: bool, taille: int = 18) -> void:
	var couleur := couleur_mode(mode)
	D.rect(parent, rectangle, couleur if plein else Color(couleur, .16), Charte.RAYON_PETIT)
	var encre := Charte.ENCRE if plein else couleur
	if ICONES_MODE.has(mode):
		var icone := C.icon(ICONES_MODE[mode], taille, encre)
		parent.add_child(icone)
		D.place(icone, Rect2(rectangle.position.x + 10, rectangle.position.y + (rectangle.size.y - taille) / 2.0, taille, taille))
	D.text(parent, rectangle.position.x + 16 + taille, rectangle.position.y + rectangle.size.y / 2.0 + taille * .36, NOMS_MODE.get(mode, mode), taille, encre, 700, rectangle.size.x - 22 - taille)

static func _pastille(parent: Node, rectangle: Rect2, texte: String, couleur: Color, taille: int = 17) -> void:
	D.rect(parent, rectangle, Color(couleur, .17), Charte.RAYON_PETIT)
	D.text(parent, rectangle.position.x + rectangle.size.x / 2.0, rectangle.position.y + rectangle.size.y / 2.0 + taille * .36, texte, taille, couleur, 700, rectangle.size.x - 8, HORIZONTAL_ALIGNMENT_CENTER)

static func _jauge(parent: Node, rectangle: Rect2, valeur: float, couleur: Color) -> void:
	D.rect(parent, rectangle, Charte.PANNEAU_3, 3)
	D.rect(parent, Rect2(rectangle.position, Vector2(maxf(3.0, rectangle.size.x * clampf(valeur / 100.0, 0, 1)), rectangle.size.y)), couleur, 3)

static func _portrait(parent: Node, p: Dictionary, rectangle: Rect2) -> void:
	var portrait := G.portrait(int(p.get("portraitIndex", 0)), 0, p)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(portrait)
	D.place(portrait, rectangle)

static func _cle(p: Dictionary) -> String:
	return str(p.get("id", "")).replace(":", "_")

static func _choisir_joueur(app: Control, p: Dictionary, mode: String) -> void:
	app._command("set_player_load", {"playerId":p.id, "mode":mode})

static func _choisir_regle(app: Control, niveau: int, mode: String) -> void:
	regles(app)[niveau] = mode
	app._render()

static func _trier(app: Control, liste: Array, tri: String) -> Array:
	var copie := liste.duplicate()
	copie.sort_custom(func(a: Dictionary, b: Dictionary):
		match tri:
			"nom": return str(a.get("name", "")) < str(b.get("name", ""))
			"forme":
				if float(a.get("condition", 0)) != float(b.get("condition", 0)): return float(a.get("condition", 0)) < float(b.get("condition", 0))
			"fragilite":
				if float(a.get("fragilite", 50)) != float(b.get("fragilite", 50)): return float(a.get("fragilite", 50)) > float(b.get("fragilite", 50))
			"charge":
				if float(a.get("physicalLoad", 0)) != float(b.get("physicalLoad", 0)): return float(a.get("physicalLoad", 0)) > float(b.get("physicalLoad", 0))
		var ra := score_risque(app, a)
		var rb := score_risque(app, b)
		if ra != rb: return ra > rb
		return str(a.get("id", "")) < str(b.get("id", "")))
	return copie

static func _entete(app: Control, parent: Node, x: float, y: float, largeur: float, texte: String, cle: String, state: Dictionary, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var actif := str(state.get("intensite_tri", "risque")) == cle
	var gauche := x if align == HORIZONTAL_ALIGNMENT_LEFT else x - largeur / 2.0
	D.text(parent, x, y, texte + (" ▼" if actif else ""), 16, Charte.DORE if actif else Charte.IVOIRE_3, 700, largeur, align)
	if not cle.is_empty():
		_zone(parent, Rect2(gauche - 6, y - 24, largeur + 12, 34), "IntensiteTri_" + cle, "Trier · " + texte.capitalize(), func():
			state.intensite_tri = cle
			app._render())

# ---------------------------------------------------------------------------------------------- petites fenêtres
## Choix de l'intensité d'un niveau de forme : trois grandes tuiles colorées.
static func fenetre_regle(app: Control, page: Control, niveau: int) -> void:
	var fond := Fenetre.ouvrir(page, "IntensiteRegleFenetre", "FORME " + FORMES[niveau].to_upper(), "", 820, 330)
	_coeur(fond, Rect2(720 - 80, 20, 44, 44), niveau)
	var actuel := str(regles(app)[niveau])
	for i in 3:
		var mode: String = MODES[i]
		var r := Rect2(28 + i * 258, 96, 246, 200)
		var couleur := couleur_mode(mode)
		D.rect(fond, r, couleur if mode == actuel else Color(couleur, .16), Charte.RAYON_CARTE)
		var encre := Charte.ENCRE if mode == actuel else couleur
		var icone := C.icon(ICONES_MODE[mode], 64, encre)
		fond.add_child(icone)
		D.place(icone, Rect2(r.position.x + (r.size.x - 64) / 2.0, r.position.y + 30, 64, 64))
		D.text(fond, r.position.x + r.size.x / 2.0, r.position.y + 150, NOMS_MODE[mode].to_upper(), 30, encre, 800, r.size.x - 20, HORIZONTAL_ALIGNMENT_CENTER)
		_zone(fond, r, "IntensiteRegleChoix_" + mode, NOMS_MODE[mode], func():
			Fenetre.fermer(page, "IntensiteRegleFenetre")
			_choisir_regle(app, niveau, mode))

## Choix d'un joueur : portrait, forme, risque, puis Auto / Repos / Normal / Intensif (avis du kiné marqué).
static func fenetre_joueur(app: Control, page: Control, p: Dictionary) -> void:
	var fond := Fenetre.ouvrir(page, "IntensiteJoueurFenetre", str(p.get("name", "")).to_upper(), "", 980, 420)
	_portrait(fond, p, Rect2(28, 78, 92, 100))
	var niveau := niveau_forme(p)
	_coeur(fond, Rect2(140, 84, 40, 40), niveau)
	D.text(fond, 192, 114, "%s %%" % G.n(p.get("condition", 0)), 26, couleur_forme(niveau), 800, 120)
	D.text(fond, 140, 162, str(p.get("pos", "")), 18, Charte.IVOIRE_2, 600, 260)
	var nr := niveau_risque(app, p)
	_pastille(fond, Rect2(420, 86, 190, 36), RISQUES[nr], couleur_risque(nr), 18)
	D.text(fond, 420, 160, "RISQUE", 15, Charte.IVOIRE_3, 700, 190)
	var avis := kine(p)
	_pilule(fond, Rect2(660, 86, 170, 36), avis, false, 18)
	D.text(fond, 660, 160, "KINÉ", 15, Charte.IVOIRE_3, 700, 170)
	var choix := ["collective"] + MODES
	var actuel := str(p.get("loadPlan", "collective"))
	for i in choix.size():
		var mode: String = choix[i]
		var r := Rect2(28 + i * 233, 200, 222, 180)
		var couleur := couleur_mode(intensite(app, {"condition":p.get("condition", 0)}) if mode == "collective" else mode)
		var pris := mode == actuel
		D.rect(fond, r, couleur if pris else Color(couleur, .14), Charte.RAYON_CARTE)
		var encre := Charte.ENCRE if pris else couleur
		var icone := C.icon("renew" if mode == "collective" else ICONES_MODE[mode], 50, encre)
		fond.add_child(icone)
		D.place(icone, Rect2(r.position.x + (r.size.x - 50) / 2.0, r.position.y + 24, 50, 50))
		D.text(fond, r.position.x + r.size.x / 2.0, r.position.y + 118, NOMS_MODE[mode].to_upper(), 27, encre, 800, r.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
		if mode == "collective":
			D.text(fond, r.position.x + r.size.x / 2.0, r.position.y + 152, "→ " + NOMS_MODE[str(regles(app)[niveau])], 18, encre, 600, r.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
		if mode == avis:
			D.rect(fond, Rect2(r.end.x - 70, r.position.y + 10, 60, 24), Charte.IVOIRE if not pris else Charte.ENCRE, Charte.RAYON_PETIT)
			D.text(fond, r.end.x - 40, r.position.y + 28, "KINÉ", 14, Charte.ENCRE if not pris else Charte.IVOIRE, 800, 58, HORIZONTAL_ALIGNMENT_CENTER)
		_zone(fond, r, "IntensiteJoueurChoix_" + mode, NOMS_MODE[mode], func():
			Fenetre.fermer(page, "IntensiteJoueurFenetre")
			_choisir_joueur(app, p, mode))

# ---------------------------------------------------------------------------------------------- option A
static func build_a(app: Control, page: Control, state: Dictionary, squad: Array) -> void:
	var regle := regles(app)
	# Règle par forme : cinq colonnes.
	var haut := D.panel(page, Rect2(4, 252, 1740, 206), "Intensité selon la forme", "heart", "", "IntensiteRegle")
	var compte := [0, 0, 0, 0, 0]
	for p: Dictionary in squad: compte[niveau_forme(p)] += 1
	for i in 5:
		var x := 18.0 + i * 342.0
		var carte := D.rect(haut, Rect2(x, 70, 330, 122), Charte.PANNEAU_2, Charte.RAYON_CARTE)
		carte.name = "IntensiteForme_" + str(i)
		_coeur(carte, Rect2(14, 12, 46, 46), i)
		D.text(carte, 72, 34, FORMES[i].to_upper(), 20, couleur_forme(i), 800, 190)
		D.text(carte, 72, 56, "%s" % (("< %d %%" % SEUILS_FORME[0]) if i == 0 else ("≥ %d %%" % SEUILS_FORME[i - 1])), 15, Charte.IVOIRE_3, 600, 120)
		D.text(carte, 316, 50, str(compte[i]), 34, Charte.IVOIRE, 800, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		_pilule(carte, Rect2(14, 72, 302, 38), str(regle[i]), true, 19)
		var niveau := i
		_zone(carte, Rect2(0, 0, 330, 122), "IntensiteRegle_" + str(i), "Forme %s · %s" % [FORMES[i], NOMS_MODE[str(regle[i])]], func(): fenetre_regle(app, page, niveau))
	# Liste de l'effectif.
	var filtre := int(state.get("intensite_risque", -1))
	var liste := D.panel(page, Rect2(4, 472, 1740, 738), "", "", "", "IntensiteListe")
	var colonnes := [["JOUEUR", 66, 330, "nom"], ["POSTE", 404, 170, ""], ["FORME", 586, 150, "forme"], ["CHARGE", 748, 150, "charge"], ["FRAGILITÉ", 912, 140, "fragilite"], ["RISQUE", 1068, 170, "risque"], ["KINÉ", 1252, 160, ""], ["INTENSITÉ", 1428, 290, ""]]
	for col: Array in colonnes: _entete(app, liste, col[1], 40, col[2], col[0], col[3], state)
	D.line(liste, Vector2(18, 54), Vector2(1722, 54), Charte.FILET)
	var joueurs := squad.filter(func(p: Dictionary): return filtre < 0 or niveau_risque(app, p) == filtre)
	_lignes(app, page, liste, Rect2(10, 60, 1720, 670), _trier(app, joueurs, str(state.get("intensite_tri", "risque"))), func(ligne: Control, p: Dictionary, h: float):
		var m := h / 2.0
		var niveau := niveau_forme(p)
		D.text(ligne, 396, m + 7, str(p.get("pos", "")), 17, Charte.IVOIRE_2, 500, 170)
		_coeur(ligne, Rect2(578, m - 14, 28, 28), niveau)
		D.text(ligne, 614, m + 7, "%s %%" % G.n(p.get("condition", 0)), 19, couleur_forme(niveau), 700, 90)
		var charge := float(p.get("physicalLoad", 0))
		_jauge(ligne, Rect2(740, m - 5, 92, 10), charge, Charte.INTENSIF if charge >= 55 else Charte.NORMAL)
		D.text(ligne, 840, m + 7, G.n(charge), 17, Charte.IVOIRE, 600, 40)
		var frag := float(p.get("fragilite", 50))
		D.text(ligne, 904, m + 7, G.n(frag), 19, Charte.couleur_attribut(100.0 - frag), 700, 50)
		var nr := niveau_risque(app, p)
		_pastille(ligne, Rect2(1060, m - 15, 150, 30), RISQUES[nr], couleur_risque(nr))
		var avis := kine(p)
		_pilule(ligne, Rect2(1244, m - 15, 140, 30), avis, false, 16)
		var avis_zone := _zone(ligne, Rect2(1244, m - 15, 140, 30), "IntensiteKine_" + _cle(p), "Avis du kiné · " + NOMS_MODE[avis], func(): _choisir_joueur(app, p, avis))
		avis_zone.disabled = avis == str(p.get("loadPlan", ""))
		var mode := intensite(app, p)
		_pilule(ligne, Rect2(1420, m - 16, 200, 32), mode, true, 17)
		var marque := "↻ AUTO" if auto(p) else "✋ CHOIX" if float(p.get("injury", 0)) <= 0 else "BLESSÉ"
		D.text(ligne, 1630, m + 6, marque, 14, Charte.IVOIRE_2 if auto(p) else Charte.DORE, 800, 90)
		_zone(ligne, Rect2(1414, 2, 306, h - 4), "IntensiteJoueur_" + _cle(p), str(p.get("name", "")) + " · intensité", func(): fenetre_joueur(app, page, p)))
	# Colonne des risques : cinq niveaux, un clic filtre la liste.
	var droite := D.panel(page, Rect2(1760, 252, 488, 958), "Risque de blessure", "warning", "", "IntensiteRisques")
	var par_niveau := [0, 0, 0, 0, 0]
	for p: Dictionary in squad: par_niveau[niveau_risque(app, p)] += 1
	for i in 5:
		var r := Rect2(18, 74 + i * 112, 452, 100)
		var choisi := filtre == i
		D.rect(droite, r, Color(couleur_risque(i), .26 if choisi else .1), Charte.RAYON_CARTE, couleur_risque(i) if choisi else Color.TRANSPARENT)
		D.rect(droite, Rect2(r.position.x, r.position.y + 14, 6, r.size.y - 28), couleur_risque(i), 3)
		D.text(droite, r.position.x + 24, r.position.y + 42, RISQUES[i].to_upper(), 24, couleur_risque(i), 800, 260)
		D.text(droite, r.end.x - 20, r.position.y + 70, str(par_niveau[i]), 52, Charte.IVOIRE, 800, 120, HORIZONTAL_ALIGNMENT_RIGHT)
		# Visages des trois premiers.
		var gens := _trier(app, squad.filter(func(p: Dictionary): return niveau_risque(app, p) == i), "risque")
		for k in mini(4, gens.size()): _portrait(droite, gens[k], Rect2(r.position.x + 24 + k * 40, r.position.y + 54, 34, 38))
		var niveau := i
		_zone(droite, r, "IntensiteRisque_" + str(i), "Risque %s · %d" % [RISQUES[i], par_niveau[i]], func():
			state.intensite_risque = -1 if int(state.get("intensite_risque", -1)) == niveau else niveau
			app._render())
	var tous := Rect2(18, 74 + 5 * 112, 452, 64)
	D.rect(droite, tous, Color(Charte.IVOIRE, .1 if filtre < 0 else .04), Charte.RAYON_CARTE, Charte.IVOIRE if filtre < 0 else Color.TRANSPARENT)
	D.text(droite, tous.position.x + 24, tous.position.y + 41, "TOUT L’EFFECTIF", 22, Charte.IVOIRE, 800, 300)
	D.text(droite, tous.end.x - 20, tous.position.y + 43, str(squad.size()), 30, Charte.IVOIRE, 800, 100, HORIZONTAL_ALIGNMENT_RIGHT)
	_zone(droite, tous, "IntensiteRisqueTous", "Tout l’effectif", func():
		state.intensite_risque = -1
		app._render())
	# Avis du kiné pour tous les joueurs en auto.
	var kine_tous := Rect2(18, 74 + 5 * 112 + 80, 452, 120)
	D.rect(droite, kine_tous, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	var ecarts := squad.filter(func(p: Dictionary): return float(p.get("injury", 0)) <= 0 and kine(p) != intensite(app, p)).size()
	var icone := C.icon("heart", 34, Charte.REPOS)
	droite.add_child(icone)
	D.place(icone, Rect2(kine_tous.position.x + 22, kine_tous.position.y + 20, 34, 34))
	D.text(droite, kine_tous.position.x + 70, kine_tous.position.y + 46, "AVIS DU KINÉ", 22, Charte.IVOIRE, 800, 260)
	D.text(droite, kine_tous.end.x - 20, kine_tous.position.y + 50, str(ecarts), 40, Charte.REPOS, 800, 90, HORIZONTAL_ALIGNMENT_RIGHT)
	D.text(droite, kine_tous.position.x + 70, kine_tous.position.y + 78, "ÉCARTS", 15, Charte.IVOIRE_3, 700, 200)
	_pilule(droite, Rect2(kine_tous.position.x + 22, kine_tous.position.y + 88, 120, 24), "normal", false, 13)
	D.text(droite, kine_tous.position.x + 160, kine_tous.position.y + 106, "→ TOUT APPLIQUER", 15, Charte.REPOS, 800, 260)
	_zone(droite, kine_tous, "IntensiteKineTous", "Avis du kiné pour tous", func():
		for p: Dictionary in squad:
			if float(p.get("injury", 0)) <= 0 and kine(p) != intensite(app, p): _choisir_joueur(app, p, kine(p)))

# ---------------------------------------------------------------------------------------------- option B
static func build_b(app: Control, page: Control, state: Dictionary, squad: Array) -> void:
	var regle := regles(app)
	# Onglets des cinq niveaux de risque.
	var par_niveau := [0, 0, 0, 0, 0]
	for p: Dictionary in squad: par_niveau[niveau_risque(app, p)] += 1
	var filtre := int(state.get("intensite_onglet", -1))
	for i in 6:
		var r := Rect2(4 + i * 374, 252, 362, 74)
		var choisi := filtre == i or (i == 5 and filtre < 0)
		var couleur := couleur_risque(i) if i < 5 else Charte.IVOIRE
		D.rect(page, r, Color(couleur, .2) if choisi else Charte.PANNEAU, Charte.RAYON_CARTE)
		D.rect(page, Rect2(r.position.x + 16, r.end.y - 6, r.size.x - 32, 5), couleur if choisi else Color(couleur, .35), 2)
		if i < 5:
			var icone := C.icon("warning", 26, couleur)
			page.add_child(icone)
			D.place(icone, Rect2(r.position.x + 18, r.position.y + 20, 26, 26))
		D.text(page, r.position.x + (56 if i < 5 else 20), r.position.y + 44, ("RISQUE " + RISQUES[i].to_upper()) if i < 5 else "TOUT L’EFFECTIF", 22, couleur if i < 5 else Charte.IVOIRE, 800, 240)
		D.text(page, r.end.x - 18, r.position.y + 50, str(par_niveau[i] if i < 5 else squad.size()), 38, Charte.IVOIRE, 800, 70, HORIZONTAL_ALIGNMENT_RIGHT)
		var onglet := i if i < 5 else -1
		_zone(page, r, "IntensiteOnglet_" + str(i), ("Risque " + RISQUES[i]) if i < 5 else "Tout l’effectif", func():
			state.intensite_onglet = onglet
			app._render())
	# Règle par forme : colonne de gauche, trois choix en ligne.
	var gauche := D.panel(page, Rect2(4, 342, 560, 868), "Règle auto", "renew", "", "IntensiteRegle")
	for i in 5:
		var y := 76.0 + i * 128.0
		var compte := squad.filter(func(p: Dictionary): return niveau_forme(p) == i).size()
		_coeur(gauche, Rect2(20, y, 50, 50), i)
		D.text(gauche, 84, y + 24, FORMES[i].to_upper(), 21, couleur_forme(i), 800, 280)
		D.text(gauche, 84, y + 48, (("< %d %%" % SEUILS_FORME[0]) if i == 0 else ("≥ %d %%" % SEUILS_FORME[i - 1])), 15, Charte.IVOIRE_3, 600, 150)
		D.text(gauche, 540, y + 40, str(compte), 30, Charte.IVOIRE, 800, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		for k in 3:
			var mode: String = MODES[k]
			var r := Rect2(20 + k * 176, y + 62, 170, 44)
			_pilule(gauche, r, mode, str(regle[i]) == mode, 17)
			var niveau := i
			_zone(gauche, r, "IntensiteRegle_%d_%s" % [i, mode], "Forme %s · %s" % [FORMES[i], NOMS_MODE[mode]], func(): _choisir_regle(app, niveau, mode))
	var bas := 76.0 + 5 * 128.0 + 10
	D.line(gauche, Vector2(18, bas), Vector2(542, bas), Charte.FILET)
	var ecarts := squad.filter(func(p: Dictionary): return float(p.get("injury", 0)) <= 0 and kine(p) != intensite(app, p)).size()
	var r_kine := Rect2(20, bas + 16, 522, 72)
	D.rect(gauche, r_kine, Color(Charte.REPOS, .14), Charte.RAYON_CARTE)
	var icone_k := C.icon("heart", 30, Charte.REPOS)
	gauche.add_child(icone_k)
	D.place(icone_k, Rect2(r_kine.position.x + 18, r_kine.position.y + 21, 30, 30))
	D.text(gauche, r_kine.position.x + 62, r_kine.position.y + 46, "SUIVRE LE KINÉ", 22, Charte.REPOS, 800, 300)
	D.text(gauche, r_kine.end.x - 18, r_kine.position.y + 50, "%d ≠" % ecarts, 30, Charte.IVOIRE, 800, 120, HORIZONTAL_ALIGNMENT_RIGHT)
	_zone(gauche, r_kine, "IntensiteKineTous", "Avis du kiné pour tous", func():
		for p: Dictionary in squad:
			if float(p.get("injury", 0)) <= 0 and kine(p) != intensite(app, p): _choisir_joueur(app, p, kine(p)))
	# Liste du niveau choisi.
	var liste := D.panel(page, Rect2(578, 342, 1670, 868), "", "", "", "IntensiteListe")
	var colonnes := [["JOUEUR", 66, 320, "nom"], ["POSTE", 398, 150, ""], ["FORME", 556, 140, "forme"], ["FRAGILITÉ", 708, 120, "fragilite"], ["FACTEUR", 842, 200, ""], ["INTENSITÉ", 1060, 520, ""]]
	for col: Array in colonnes: _entete(app, liste, col[1], 40, col[2], col[0], col[3], state)
	D.line(liste, Vector2(18, 54), Vector2(1652, 54), Charte.FILET)
	var joueurs := squad.filter(func(p: Dictionary): return filtre < 0 or niveau_risque(app, p) == filtre)
	_lignes(app, page, liste, Rect2(10, 60, 1650, 800), _trier(app, joueurs, str(state.get("intensite_tri", "risque"))), func(ligne: Control, p: Dictionary, h: float):
		var m := h / 2.0
		var niveau := niveau_forme(p)
		var nr := niveau_risque(app, p)
		D.rect(ligne, Rect2(0, 6, 5, h - 12), couleur_risque(nr), 2)
		D.text(ligne, 390, m + 7, str(p.get("pos", "")), 17, Charte.IVOIRE_2, 500, 150)
		_coeur(ligne, Rect2(548, m - 14, 28, 28), niveau)
		D.text(ligne, 584, m + 7, "%s %%" % G.n(p.get("condition", 0)), 19, couleur_forme(niveau), 700, 90)
		var frag := float(p.get("fragilite", 50))
		_jauge(ligne, Rect2(700, m - 5, 70, 10), frag, Charte.couleur_attribut(100.0 - frag))
		D.text(ligne, 778, m + 7, G.n(frag), 17, Charte.IVOIRE, 600, 40)
		var f := facteur(app, p)
		var fc := Charte.GAIN if f[0] == "Aucun" else couleur_risque(mini(nr, 2))
		var fi := C.icon(f[1], 20, fc)
		ligne.add_child(fi)
		D.place(fi, Rect2(834, m - 10, 20, 20))
		D.text(ligne, 862, m + 7, f[0], 18, fc, 700, 170)
		# Intensité : Auto + trois choix en ligne ; avis du kiné = point sur le segment conseillé.
		var plan := str(p.get("loadPlan", "collective"))
		var applique := intensite(app, p)
		var blesse := float(p.get("injury", 0)) > 0
		var ra := Rect2(1052, m - 16, 108, 32)
		D.rect(ligne, ra, Color(Charte.IVOIRE, .85) if plan == "collective" and not blesse else Charte.PANNEAU_3, Charte.RAYON_PETIT)
		D.text(ligne, ra.position.x + ra.size.x / 2.0, m + 6, "↻ AUTO", 15, Charte.ENCRE if plan == "collective" and not blesse else Charte.IVOIRE_2, 800, 100, HORIZONTAL_ALIGNMENT_CENTER)
		if not blesse: _zone(ligne, ra, "IntensiteAuto_" + _cle(p), str(p.get("name", "")) + " · auto", func(): _choisir_joueur(app, p, "collective"))
		var avis := kine(p)
		for k in 3:
			var mode: String = MODES[k]
			var r := Rect2(1170 + k * 150, m - 16, 144, 32)
			var plein := applique == mode
			var couleur := couleur_mode(mode)
			D.rect(ligne, r, couleur if plein else Color(couleur, .12), Charte.RAYON_PETIT)
			D.text(ligne, r.position.x + r.size.x / 2.0, m + 6, NOMS_MODE[mode], 16, Charte.ENCRE if plein else Color(couleur, .9), 700, r.size.x - 20, HORIZONTAL_ALIGNMENT_CENTER)
			if mode == avis:
				D.rect(ligne, Rect2(r.end.x - 18, r.position.y + 10, 12, 12), Charte.ENCRE if plein else Charte.IVOIRE, 6)
			if not blesse:
				var z := _zone(ligne, r, "IntensiteChoix_%s_%s" % [_cle(p), mode], "%s · %s%s" % [p.get("name", ""), NOMS_MODE[mode], " · avis du kiné" if mode == avis else ""], func(): _choisir_joueur(app, p, mode))
				z.disabled = plan == mode
	)
	# Légende du point du kiné (forme, pas de phrase).
	D.rect(liste, Rect2(1556, 26, 12, 12), Charte.IVOIRE, 6)
	D.text(liste, 1578, 38, "KINÉ", 15, Charte.IVOIRE_3, 700, 70)

# ---------------------------------------------------------------------------------------------- lignes communes
static func _lignes(app: Control, page: Control, parent: Control, zone: Rect2, joueurs: Array, dessiner: Callable) -> void:
	var defile := ScrollContainer.new()
	defile.name = "IntensiteDefile"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(defile)
	D.place(defile, zone)
	var colonne := C.v(2)
	C.fill(colonne)
	defile.add_child(colonne)
	var h := C.reach(44)
	for i in joueurs.size():
		var p: Dictionary = joueurs[i]
		var ligne := Control.new()
		ligne.name = "IntensiteLigne_" + _cle(p)
		ligne.custom_minimum_size = Vector2(zone.size.x * C.density, C.px(h))
		ligne.mouse_filter = Control.MOUSE_FILTER_PASS
		colonne.add_child(ligne)
		if i % 2 == 1: D.rect(ligne, Rect2(0, 0, zone.size.x, h), Color(Charte.IVOIRE, .025), Charte.RAYON_PETIT)
		var lien := Fatigue.profile_link(app, ligne, Rect2(8, 2, 330, h - 4), p, "IntensiteFiche_" + _cle(p))
		_portrait(lien, p, Rect2(6, (h - 36) / 2.0, 32, 36))
		D.text(lien, 50, h / 2.0 + 7, str(p.get("name", "")), 20, Charte.IVOIRE, 700, 270)
		dessiner.call(ligne, p, h)
	if joueurs.is_empty():
		var vide := C.label("—", 30, Charte.IVOIRE_3)
		colonne.add_child(vide)
