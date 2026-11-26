extends RefCounted
## « Dernière rencontre » sur l'avant-match (option B choisie par Léo le 21/11/2026) : une pastille « résultat ·
## écusson adverse · score » dans le bandeau haut ouvre une petite fenêtre visuelle (cadre fenetre_visuelle.gd).
## Depuis le 23/11/2026 (idée FM n°19, choix de Léo) elle montre la carte du compte rendu en version réduite
## (compte_rendu_carte.gd : bandeau du score, frise 0-80' des essais, stats en barres miroir, marqueurs), puis tes
## choix (pastilles icône + mot → Plan de jeu) ; zone du club adverse → sa fiche. Données : `decisions.report` du
## modèle natif (native/engine/decisions.cjs), remis à zéro à chaque nouvelle saison : sans match joué, pas de pastille.

const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")

const FENETRE := "MatchBilanFenetre"
const LARGEUR := 1560.0
const HAUT_CARTE := 88.0

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
	# Pastille décorative (le clic est celui de toute la pastille du bandeau) : nom propre, distinct des pastilles de
	# forme cliquables de l'affiche (« PastilleV », etc.), que les recherches par nom ne doivent pas confondre.
	p.name = "MatchLastMatchResult" + res
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

# ---- Petite fenêtre : carte du compte rendu (réduite) et tes choix -------------------------------------------------

static func ouvrir(avant: Control, model: Dictionary) -> void:
	var report := rapport(model)
	if report.is_empty(): return
	var scene: Control = avant.find_child("MatchStage", true, false)
	if scene == null: scene = avant
	var declencheur := avant.find_child("MatchLastMatchOpen", true, false) as Control
	var carte: Control = load("res://ui/immersive08/compte_rendu_carte.gd").carte_rapport(avant.app, LARGEUR - 80.0)
	var h_carte: float = float(carte.get_meta("hauteur", 520.0)) if carte != null else 0.0
	var hauteur := HAUT_CARTE + h_carte + 110.0
	var fond := Fenetre.ouvrir(scene, FENETRE, "DERNIÈRE RENCONTRE", "calendar", LARGEUR, hauteur, func(): if is_instance_valid(declencheur): declencheur.grab_focus())
	# Hors coque : le calque et son voile couvrent tout l'écran, le panneau est centré.
	var calque := fond.get_parent() as Control
	calque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var voile := calque.find_child(FENETRE + "Voile", false, false) as Control
	if voile != null: voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fond.position = ((scene.size - fond.size) / 2.0).floor()
	_contenu(fond, avant, model, report, carte, h_carte)

static func _contenu(fond: Control, avant: Control, model: Dictionary, report: Dictionary, carte: Control, h_carte: float) -> void:
	var cote := _cote(report)
	var app: Control = avant.app
	if carte != null:
		fond.add_child(carte)
		D.place(carte, Rect2(40, HAUT_CARTE, LARGEUR - 80.0, h_carte))
		# Zone du club adverse (écusson et nom dans le bandeau de la carte) → sa fiche, la fenêtre se ferme.
		var club := _club(model, report.teams[1 - cote])
		var demi := (LARGEUR - 80.0) / 2.0
		var zone := D.rect(fond, Rect2(40.0 + (demi + 200.0 if cote == 0 else 0.0), HAUT_CARTE, demi - 200.0, 112), Color.TRANSPARENT, 12)
		R.cliquable(zone, func(): _vers(avant, func(): avant._ouvrir_club(club)), "BilanClubAdverse", "Fiche du club adverse")
	# Tes choix : plan au coup d'envoi, conseil du staff suivi ou non (clic : le plan de jeu).
	var y := HAUT_CARTE + h_carte + 58.0
	_titre(fond, 60, y, "TES CHOIX", "BilanTitreChoix")
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
			var p := R.pastille(fond, x, y, str(c[0]), c[1], str(c[2]), str(c[3]), 20)
			R.cliquable(p, func(): _vers(avant, func(): app._navigate("Plan de jeu")), str(c[3]) + "Lien", "Plan de jeu")
			x += p.size.x / C.density + 12.0
	else:
		R.pastille(fond, x, y, "Plan non conservé", Charte.IVOIRE_2, "info", "BilanChoixAbsent", 20)

static func _titre(fond: Control, x: float, baseline: float, texte: String, id: String) -> void:
	var t := D.text(fond, x, baseline + 4, texte, 26, Charte.IVOIRE, 800, 180)
	t.name = id
	t.add_theme_font_override("font", Charte.TITRE_FICHE)

## Ferme la fenêtre puis mène à la destination.
static func _vers(avant: Control, action: Callable) -> void:
	Fenetre.fermer(avant, FENETRE)
	action.call()
