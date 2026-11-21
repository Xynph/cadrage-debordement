extends RefCounted
## « Dernière rencontre » sur l'avant-match (option B choisie par Léo le 21/11/2026) : une pastille « résultat ·
## écusson adverse · score » dans le bandeau haut ouvre la petite fenêtre visuelle du bilan complet (cadre
## fenetre_visuelle.gd) : score et écussons, tes choix (pastilles icône + mot → Plan de jeu), les phases par plan et
## les faits (tuiles chiffres), zone du club adverse → sa fiche. Aucune phrase : les notes du staff deviennent des
## pastilles. Données : `decisions.report` du modèle natif (native/engine/decisions.cjs), remis à zéro à chaque
## nouvelle saison : sans match joué, pas de pastille.

const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")

const FENETRE := "MatchBilanFenetre"
const LARGEUR := 1560.0
const HAUTEUR := 820.0

## Le bilan de la dernière rencontre du club (vide sans match joué ou si le compte rendu est incomplet).
static func rapport(model: Dictionary) -> Dictionary:
	var report: Variant = model.get("decisions", {}).get("report") if model.get("decisions") is Dictionary else null
	if not report is Dictionary: return {}
	var score: Variant = report.get("score")
	var teams: Variant = report.get("teams")
	if not score is Array or score.size() != 2 or not teams is Array or teams.size() != 2: return {}
	var side := int(report.get("side", -1))
	if side < 0 or side > 1: return {}
	return report

static func _cote(report: Dictionary) -> int:
	return int(report.get("side", 0))

static func resultat(report: Dictionary) -> String:
	var s: Array = report.score
	var nous := int(s[_cote(report)])
	var eux := int(s[1 - _cote(report)])
	return "V" if nous > eux else "D" if nous < eux else "N"

static func _club(model: Dictionary, team: Dictionary) -> Dictionary:
	var id: Variant = team.get("id")
	if id == null: return team
	var cle := str(int(id)) if id is int or id is float else str(id)
	for ligue: Variant in model.get("leagues", []):
		if ligue is Dictionary:
			for club: Variant in ligue.get("rows", []):
				if club is Dictionary and club.get("id") != null and (str(int(club.id)) if club.id is int or club.id is float else str(club.id)) == cle: return club
	for club: Variant in (model.get("league", []) if model.get("league") is Array else []):
		if club is Dictionary and club.get("id") != null and (str(int(club.id)) if club.id is int or club.id is float else str(club.id)) == cle: return club
	var next: Variant = model.get("next")
	if next is Dictionary:
		for club: Variant in [next.get("home"), next.get("away")]:
			if club is Dictionary and club.get("id") != null and (str(int(club.id)) if club.id is int or club.id is float else str(club.id)) == cle: return club
	if model.get("club") is Dictionary and str(model.club.get("id")) == str(id): return model.club
	return team

static func _plan(model: Dictionary, cle: String, id: Variant) -> String:
	for option: Variant in model.get("tactics", {}).get(cle, []):
		if option is Dictionary and str(option.get("id")) == str(id): return str(option.get("label", id))
	return str(id).capitalize()

static func _n(value: Variant) -> int:
	return roundi(float(value)) if value is int or value is float else 0

## Faits marquants : les règles des notes du staff (debriefNotes), en pastilles [texte, couleur, icône].
static func faits_marquants(report: Dictionary) -> Array:
	var faits: Array = []
	var cote := _cote(report)
	var stats: Variant = report.get("tacticalStats")
	if not stats is Array or stats.size() != 2 or not stats[cote] is Dictionary: return faits
	var own: Dictionary = stats[cote]
	var porteurs := _n(own.get("carries"))
	var avances := _n(own.get("advances"))
	var penalites := _n(report.get("stats", [{}, {}])[cote].get("penalties")) if report.get("stats") is Array and report.stats.size() == 2 and report.stats[cote] is Dictionary else 0
	if porteurs < 5: faits.append(["Peu de ballons", R.ORANGE, "info"])
	else:
		var taux := roundi(100.0 * avances / porteurs)
		faits.append(["%d %% d'avancée" % taux, R.ROUGE if taux < 40 else R.VERT, "warning" if taux < 40 else "check"])
	if str(report.get("weather", "")) == "Pluie" and _n(own.get("handErrors")) >= 3: faits.append(["Pluie · %d en-avant" % _n(own.get("handErrors")), R.ORANGE, "cloud"])
	var pression: Variant = report.get("plans", {}).get("defence", {}).get("pression") if report.get("plans") is Dictionary else null
	if pression is Dictionary and _n(pression.get("phases")) > 0 and penalites >= 4: faits.append(["Montée · %d pénalités" % penalites, R.ROUGE, "shield"])
	elif penalites >= 4: faits.append(["%d pénalités" % penalites, R.ROUGE, "warning"])
	else: faits.append(["%d pénalité%s" % [penalites, "s" if penalites > 1 else ""], R.VERT if penalites <= 2 else R.ORANGE, "shield"])
	return faits

static func _M(value: float) -> int:
	return roundi(value * C.density / 0.75)

static func _ecusson(model: Dictionary, team: Dictionary, cote: int) -> Control:
	var e := G.crest(_club(model, team), cote)
	e.custom_minimum_size = Vector2(cote, cote)
	e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e

static func _score_texte(report: Dictionary) -> String:
	return "%d – %d" % [_n(report.score[0]), _n(report.score[1])]

static func _pastille_resultat(avant: Control, res: String, taille: float) -> Control:
	var p: Button = avant.pastille(res, taille)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.focus_mode = Control.FOCUS_NONE
	return p

# ---- Pastille du dernier match dans le bandeau haut ---------------------------------------------------

static func pastille_bandeau(avant: Control, model: Dictionary) -> Control:
	var report := rapport(model)
	if report.is_empty(): return null
	var cadre := PanelContainer.new()
	cadre.name = "MatchLastMatchChip"
	cadre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Charte.PANNEAU_3, .9)
	style.set_corner_radius_all(_M(20))
	style.content_margin_left = _M(6)
	style.content_margin_right = _M(14)
	style.content_margin_top = _M(3)
	style.content_margin_bottom = _M(3)
	cadre.add_theme_stylebox_override("panel", style)
	var ligne := HBoxContainer.new()
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_theme_constant_override("separation", _M(8))
	cadre.add_child(ligne)
	ligne.add_child(_pastille_resultat(avant, resultat(report), 24))
	var adverse: Dictionary = report.teams[1 - _cote(report)]
	ligne.add_child(_ecusson(model, adverse, _M(26)))
	var score := C.label(_score_texte(report), roundi(15 / 0.75), Charte.IVOIRE, true, 800)
	score.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(score)
	var bouton := R.cliquable(cadre, func(): ouvrir(avant, model), "MatchLastMatchOpen", "Dernière rencontre : tes choix, les faits")
	for etat: String in ["normal", "hover", "pressed", "focus"]:
		var s := (bouton.get_theme_stylebox(etat) as StyleBoxFlat).duplicate() as StyleBoxFlat
		s.set_corner_radius_all(_M(20))
		bouton.add_theme_stylebox_override(etat, s)
	return cadre

# ---- Petite fenêtre du bilan complet -------------------------------------------------------------------------------

static func ouvrir(avant: Control, model: Dictionary) -> void:
	var report := rapport(model)
	if report.is_empty(): return
	var scene: Control = avant.find_child("MatchStage", true, false)
	if scene == null: scene = avant
	var declencheur := avant.find_child("MatchLastMatchOpen", true, false) as Control
	var fond := Fenetre.ouvrir(scene, FENETRE, "DERNIÈRE RENCONTRE", "calendar", LARGEUR, HAUTEUR, func(): if is_instance_valid(declencheur): declencheur.grab_focus())
	# Hors coque : le calque et son voile couvrent tout l'écran, le panneau est centré.
	var calque := fond.get_parent() as Control
	calque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var voile := calque.find_child(FENETRE + "Voile", false, false) as Control
	if voile != null: voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fond.position = ((scene.size - fond.size) / 2.0).floor()
	_contenu(fond, avant, model, report)

static func _contenu(fond: Control, avant: Control, model: Dictionary, report: Dictionary) -> void:
	var cote := _cote(report)
	var app: Control = avant.app
	# Bandeau du score : écussons, noms, score, résultat.
	var milieu := LARGEUR / 2.0
	for i in 2:
		var club := _club(model, report.teams[i])
		var e := G.crest(club, C.px(96))
		e.name = "BilanEcusson%d" % i
		fond.add_child(e)
		D.place(e, Rect2(70.0 if i == 0 else LARGEUR - 166.0, 98, 96, 96))
		var nom := D.text(fond, 186.0 if i == 0 else LARGEUR - 186.0, 158, G.club_name(club).to_upper(), 30, Charte.IVOIRE if i == cote else Charte.IVOIRE_2, 800, 430, HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT)
		nom.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		if i != cote:
			var zone := D.rect(fond, Rect2(LARGEUR - 640.0, 92, 580, 110), Color.TRANSPARENT, 12)
			R.cliquable(zone, func(): _vers(avant, func(): avant._ouvrir_club(club)), "BilanClubAdverse", "Fiche du club adverse")
	var score := D.text(fond, milieu, 168, _score_texte(report), 80, Charte.IVOIRE, 800, 360, HORIZONTAL_ALIGNMENT_CENTER)
	score.name = "BilanScoreValeur"
	score.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	var res := resultat(report)
	var mot_res: String = {"V": "Victoire", "N": "Nul", "D": "Défaite"}[res]
	var couleur_res: Color = R.VERT if res == "V" else R.ROUGE if res == "D" else R.BLEU
	var w_res := R.largeur(mot_res, 20) + 12 + 22 + 7 + 14
	R.pastille(fond, milieu - w_res / 2.0, 226, mot_res, couleur_res, "trophy" if res == "V" else "flag", "BilanResultat", 20)
	if report.get("weather") is String and not str(report.weather).is_empty():
		R.pastille(fond, milieu + w_res / 2.0 + 12, 226, str(report.weather), R.BLEU, "cloud", "BilanMeteo", 20)
	D.line(fond, Vector2(40, 262), Vector2(LARGEUR - 40, 262), Charte.FILET)
	# Tes choix : plan au coup d'envoi, conseil du staff suivi ou non (clic : le plan de jeu).
	_titre(fond, 60, 312, "TES CHOIX", "BilanTitreChoix")
	var prep: Variant = report.get("preparation")
	var x := 250.0
	if prep is Dictionary:
		var choix := [
			[_plan(model, "attacks", prep.get("attack")), R.BLEU, "ball", "BilanChoixAttaque"],
			[_plan(model, "defenses", prep.get("defence")), R.VIOLET, "shield", "BilanChoixDefense"],
		]
		var suivi := str(prep.get("attack")) == str(prep.get("recommendedAttack")) and str(prep.get("defence")) == str(prep.get("recommendedDefence"))
		choix.append(["Conseil du staff suivi" if suivi else "Staff : %s · %s" % [_plan(model, "attacks", prep.get("recommendedAttack")), _plan(model, "defenses", prep.get("recommendedDefence"))], R.VERT if suivi else R.ORANGE, "check" if suivi else "people", "BilanChoixStaff"])
		for c: Array in choix:
			var p := R.pastille(fond, x, 312, str(c[0]), c[1], str(c[2]), str(c[3]), 20)
			R.cliquable(p, func(): _vers(avant, func(): app._navigate("Plan de jeu")), str(c[3]) + "Lien", "Plan de jeu")
			x += p.size.x / C.density + 12.0
	else:
		R.pastille(fond, x, 312, "Plan non conservé", Charte.IVOIRE_2, "info", "BilanChoixAbsent", 20)
	# Phases jouées par plan (attaque bleu, défense violet).
	var plans: Variant = report.get("plans")
	var tuiles: Array = []
	if plans is Dictionary:
		for id: Variant in plans.get("attack", {}):
			var u: Variant = plans.attack[id]
			if u is Dictionary and _n(u.get("phases")) > 0: tuiles.append([str(_n(u.phases)), _plan(model, "attacks", id), R.BLEU])
		for id: Variant in plans.get("defence", {}):
			var u: Variant = plans.defence[id]
			if u is Dictionary and _n(u.get("phases")) > 0: tuiles.append([str(_n(u.phases)), _plan(model, "defenses", id), R.VIOLET])
	tuiles = tuiles.slice(0, 4)
	if not tuiles.is_empty():
		D.text(fond, 60, 372, "PHASES PAR PLAN", 17, Charte.IVOIRE_2, 700, 300)
		var w := (LARGEUR - 120 - 16.0 * 3) / 4.0
		for i in tuiles.size():
			R.tuile(fond, Rect2(60 + i * (w + 16), 386, w, 84), tuiles[i][0], tuiles[i][1], tuiles[i][2], "BilanPlan%d" % i, 40)
	D.line(fond, Vector2(40, 500), Vector2(LARGEUR - 40, 500), Charte.FILET)
	# Les faits : pastilles des faits marquants, puis les chiffres des deux camps.
	_titre(fond, 60, 550, "LES FAITS", "BilanTitreFaits")
	x = 250.0
	var n := 0
	for fait: Array in faits_marquants(report):
		var p := R.pastille(fond, x, 550, str(fait[0]), fait[1], str(fait[2]), "BilanFait%d" % n, 20)
		x += p.size.x / C.density + 12.0
		n += 1
	var stats: Variant = report.get("tacticalStats")
	if stats is Array and stats.size() == 2 and stats[cote] is Dictionary and stats[1 - cote] is Dictionary:
		var own: Dictionary = stats[cote]
		var opp: Dictionary = stats[1 - cote]
		var penalites := _n(report.stats[cote].get("penalties")) if report.get("stats") is Array and report.stats.size() == 2 and report.stats[cote] is Dictionary else 0
		var chiffres := [
			["%d/%d" % [_n(own.get("advances")), _n(own.get("carries"))], "Progressions", R.VERT],
			[str(_n(own.get("metres"))), "Mètres portés", R.VERT],
			[str(_n(own.get("kicks"))), "Pied en jeu", R.BLEU],
			[str(_n(own.get("handErrors"))), "Fautes de main", R.ROUGE if _n(own.get("handErrors")) >= 3 else R.ORANGE],
			["%d/%d" % [_n(opp.get("advances")), _n(opp.get("carries"))], "Leurs progressions", R.ROUGE],
			[str(_n(opp.get("metres"))), "Mètres concédés", R.ROUGE],
			[str(penalites), "Pénalités concédées", R.ROUGE if penalites >= 4 else R.ORANGE],
			[str(_n(opp.get("handErrors"))), "Leurs fautes de main", R.VERT],
		]
		var w := (LARGEUR - 120 - 16.0 * 3) / 4.0
		for i in chiffres.size():
			var ligne := i / 4
			var colonne := i % 4
			R.tuile(fond, Rect2(60 + colonne * (w + 16), 586 + ligne * 104, w, 88), chiffres[i][0], chiffres[i][1], chiffres[i][2], "BilanChiffre%d" % i, 40)

static func _titre(fond: Control, x: float, baseline: float, texte: String, id: String) -> void:
	var t := D.text(fond, x, baseline + 4, texte, 26, Charte.IVOIRE, 800, 180)
	t.name = id
	t.add_theme_font_override("font", Charte.TITRE_FICHE)

## Ferme la fenêtre puis mène à la destination.
static func _vers(avant: Control, action: Callable) -> void:
	Fenetre.fermer(avant, FENETRE)
	action.call()
