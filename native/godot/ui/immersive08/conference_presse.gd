extends RefCounted
## Planche « Conférence de presse » (revue FM27, idée 27) sous CD_VARIANTE_VISUELLE=A|B : dans la salle de presse
## (press_room_view.gd), une question à la fois. Un clic sur une réponse la retient et passe à la question suivante ;
## la dernière réponse publie la conférence (commande moteur `press_conference`) : plus de bouton « Publier ».
## Données du moteur : questions (journaliste, média, style, relation, thème, sujet), cinq réponses par question avec leur
## ton et leurs effets (moral, médias, supporters, pression, relation). Attitude du journaliste = libellé de relation du
## moteur (Complice, En confiance, À découvrir, Méfiance, Tendue). Le moteur ne dit pas quel joueur une question
## concerne : la carte joueur est choisie ici d'après le thème (blessures → un blessé ; sinon le joueur le plus en forme),
## à remplacer par un joueur tiré avec la question à l'intégration.
##  A : bulle du journaliste à gauche, carte du joueur et sa forme dessous ; réponses à droite rangées en trois familles
##      de ton colorées (positif / neutre / offensif), effets en petites pastilles.
##  B : façon Effectif — journaliste et joueur en bandeau, puis les cinq réponses en lignes avec une colonne par effet.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Press = preload("res://ui/press_view.gd")
const Notes = preload("res://ui/notes_match.gd")
const Visuel = preload("res://ui/immersive08/centre_visuel.gd")

## Ton du moteur → [mot, couleur, icône].
const TONS := {
	"confident": ["Affirmé", Charte.GAIN, "check"],
	"humour": ["Humour", Charte.CONFIANCE, "star"],
	"honest": ["Honnête", Charte.MORAL, "people"],
	"cautious": ["Prudent", Charte.REPOS, "info"],
	"aggressive": ["Agressif", Charte.PERTE, "warning"],
}
## Familles de ton (option A) : [mot, couleur, tons].
const FAMILLES := [["POSITIF", Charte.GAIN, ["confident", "humour"]], ["NEUTRE", Charte.MORAL, ["honest", "cautious"]], ["OFFENSIF", Charte.PERTE, ["aggressive"]]]
## Effet → [mot court, plus = bien ?].
const EFFETS := [["morale", "Moral", true], ["media", "Médias", true], ["fans", "Supporters", true], ["pressure", "Pression", false], ["relation", "Relation", true]]
## Relation du moteur → [couleur, icône].
const ATTITUDES := {"Complice": [Charte.GAIN, "star"], "En confiance": [Charte.CONDITION, "check"], "À découvrir": [Charte.IVOIRE_2, "info"],
	"Aucun échange": [Charte.IVOIRE_2, "info"], "Méfiance": [Charte.INTENSIF, "warning"], "Tendue": [Charte.PERTE, "warning"]}

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

## Salle de presse (vue contextuelle `press_room_view.gd`) : remplace son panneau quand une conférence est à répondre.
## Voile sombre sur la salle 3D, contenu centré dans un gabarit 2248 × 1240 (écran plein : 2560 × 1440 unités).
static func construire(view: Control) -> void:
	var voile := ColorRect.new()
	voile.name = "PressFmVoile"
	voile.color = Color(Charte.NOIR_PANNEAU, .86)
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	view.ui.add_child(voile)
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := Control.new()
	page.name = "PressFmPage"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.ui.add_child(page)
	D.place(page, Rect2(156, 70, 2248, 1300))
	var questions: Array = view._questions()
	var index: int = clampi(view.question_index, 0, questions.size() - 1)
	var q: Dictionary = questions[index]
	var titre := D.text(page, 0, 64, "CONFÉRENCE DE PRESSE", 64, Charte.IVOIRE, 800, 1100)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	_progression(view, page, questions, view.choices, index, Vector2(1180, 26))
	var app: Control = view.app
	if variante() == "B": _b(app, page, view, q, view.choices)
	else: _a(app, page, view, q, view.choices)
	# Gabi peut répondre à la place du manager (conférence ordinaire) : un clic, comme aujourd'hui.
	if bool(view.data.get("conference", {}).get("delegation", {}).get("allowed", false)):
		var w := Pieces.pastille(page, 0, 1250, "Laisser Gabi répondre", "people", "PressFmDelegate", "", Charte.IVOIRE_2)
		Pieces.rendre_cliquable(page.get_node("PressFmDelegate"), Vector2(w, 34), func(): view._delegate(), "PressFmDelegateOpen", "Laisser Gabi répondre", "", Charte.RAYON_PILULE)

## Une pastille par question : faite = ton choisi (couleur + mot), en cours = crème, à venir = grise ; clic = y aller.
static func _progression(view: Control, page: Control, questions: Array, choix: Dictionary, index: int, at: Vector2) -> void:
	var x := at.x
	for k in questions.size():
		var qk: Dictionary = questions[k]
		var mot := "Q%d" % (k + 1)
		var couleur: Color = Charte.IVOIRE_2
		var fond: Color = Charte.PANNEAU_3
		if choix.has(str(qk.id)):
			for r: Dictionary in qk.answers:
				if str(r.id) == str(choix[str(qk.id)]):
					mot += " · " + str(TONS.get(str(r.tone), ["", Charte.IVOIRE])[0])
					couleur = Charte.ENCRE
					fond = TONS.get(str(r.tone), ["", Charte.IVOIRE])[1]
		elif k == index:
			couleur = Charte.ENCRE
			fond = Charte.IVOIRE
		var w := Pieces.pastille(page, x, at.y, mot, "", "PressQuestionPill_%d" % k, "", couleur, fond)
		var cible := k
		Pieces.rendre_cliquable(page.get_node("PressQuestionPill_%d" % k), Vector2(w, 34), func(): view._select_question(cible), "PressQuestionPillOpen_%d" % k, mot, "", Charte.RAYON_PILULE)
		x += w + 10

## Un clic = réponse retenue ; question suivante, ou publication quand tout est répondu (plus de bouton Publier).
static func _repondre(view: Control, q: Dictionary, reponse: Dictionary) -> void:
	view._choose_answer(str(q.id), str(reponse.id))
	if view._complete(): view._publish()
	else: view._render_ui()

static func _para(parent: Control, r: Rect2, texte: String, taille: int, couleur: Color, poids := 500) -> Label:
	var l := C.label(texte, taille, couleur, false, poids)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	parent.add_child(l)
	D.place(l, r)
	# Retour à la ligne posé une fois la largeur connue (sinon la hauteur minimale explose).
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2.ZERO
	l.size = Vector2(C.px(r.size.x), C.px(r.size.y))
	return l

static func _signe(v: int) -> String:
	return "=" if v == 0 else "%+d" % v

static func _couleur(v: int, bien_si_plus: bool) -> Color:
	if v == 0: return Charte.IVOIRE_3
	return Charte.GAIN if (v > 0) == bien_si_plus else Charte.PERTE

## Joueur concerné (provisoire, voir l'en-tête) : un blessé pour les blessures, sinon le meilleur en forme récente.
static func joueur(app: Control, q: Dictionary) -> Dictionary:
	var squad: Array = app.model.get("squad", [])
	if str(q.get("theme", "")) == "blessures":
		for p: Variant in squad:
			if p is Dictionary and p.get("injury") != null and p.get("injury") is Dictionary: return p
	var meilleur := {}
	var score := -1.0
	for p: Variant in squad:
		if not p is Dictionary: continue
		var f: Array = Notes.forme(Notes.joueur(app.model, str(p.get("id", ""))))
		var s := 0.0
		for v: Variant in f: s += float(v)
		s = s / maxf(1, f.size()) + f.size() * .01 + float(p.get("rating", 0)) * .0001
		if s > score:
			score = s
			meilleur = p
	return meilleur

## Attitude du journaliste en pastille (mot du moteur + icône + couleur).
static func _attitude(parent: Control, x: float, y: float, q: Dictionary) -> float:
	var mot := str(q.get("relation", {}).get("label", "À découvrir"))
	var a: Array = ATTITUDES.get(mot, [Charte.IVOIRE_2, "info"])
	return Pieces.pastille(parent, x, y, mot, str(a[1]), "PressAttitude", "", a[0])

static func _initiales(nom: String) -> String:
	var mots := nom.split(" ", false)
	return "".join(PackedStringArray(Array(mots).map(func(w: String): return w.substr(0, 1)))).substr(0, 2).to_upper()

static func _rond(parent: Control, r: Rect2, nom: String, couleur: Color) -> void:
	var rond := D.rect(parent, r, Color(couleur, .3), 999, couleur)
	rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := D.text(rond, r.size.x / 2, r.size.y * .64, _initiales(nom), int(r.size.y * .4), Charte.IVOIRE, 800, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Carte joueur : visage, nom, poste, âge, forme (5 dernières notes). Neutre : on ne quitte pas la salle en pleine conférence.
static func _carte_joueur(app: Control, parent: Control, r: Rect2, p: Dictionary) -> void:
	var carte := D.rect(parent, r, Charte.PANNEAU, Charte.RAYON_CARTE)
	carte.name = "PressPlayerCard"
	if p.is_empty():
		Pieces.pastille(carte, 24, 24, "Aucun joueur visé", "people", "PressPlayerNone", "", Charte.IVOIRE_2)
		return
	D.text(carte, 24, 34, "JOUEUR CONCERNÉ", 15, Charte.IVOIRE_3, 700, 300)
	Visuel.portrait(carte, Rect2(24, 50, 96, 96), p, Charte.IVOIRE, true)
	var nom := D.text(carte, 140, 88, str(p.get("name", "")), 30, Charte.IVOIRE, 800, r.size.x - 160)
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	D.text(carte, 140, 124, "%s · %d ans" % [str(p.get("pos", "")), int(p.get("age", 0))], 19, Charte.IVOIRE_2, 600, r.size.x - 160)
	D.text(carte, 24, 184, "FORME", 15, Charte.IVOIRE_3, 700, 120)
	var f: Array = Notes.forme(Notes.joueur(app.model, str(p.get("id", ""))))
	Notes.pastilles(carte, Vector2(110, 160), f, Vector2(56, 34), 8)
	if p.get("injury") is Dictionary: Pieces.pastille(carte, r.size.x - 150, 24, "Blessé", "heart", "PressPlayerInjured", "", Charte.PERTE)

# --- A ---------------------------------------------------------------------------------------------------------------

static func _a(app: Control, page: Control, view: Control, q: Dictionary, choix: Dictionary) -> void:
	var j: Dictionary = q.journalist
	# Journaliste : rond, nom, média, attitude ; bulle de la question.
	var cadre := D.rect(page, Rect2(0, 110, 1060, 380), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	cadre.name = "PressJournalistCard"
	_rond(cadre, Rect2(28, 30, 120, 120), str(j.get("name", "")), Charte.DORE)
	var nom := D.text(cadre, 172, 72, str(j.get("name", "")), 34, Charte.IVOIRE, 800, 520)
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	D.text(cadre, 172, 108, str(j.get("outlet", "")), 20, Charte.IVOIRE_2, 600, 520)
	D.text(cadre, 720, 56, "ATTITUDE", 15, Charte.IVOIRE_3, 700, 200)
	_attitude(cadre, 720, 70, q)
	Pieces.pastille(cadre, 172, 124, str(j.get("styleLabel", "")), "tactic", "PressStyle", "", Charte.IVOIRE_2)
	var bulle := D.rect(cadre, Rect2(28, 186, 1004, 166), Charte.MORAL, Charte.RAYON_CARTE)
	bulle.name = "PressQuestionBubble"
	bulle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_para(bulle, Rect2(30, 22, 944, 130), str(q.get("question", "")), 30, Charte.ENCRE, 700)
	# Sujet de la question (thème + sujet du moteur) et joueur concerné.
	var sujet := D.rect(page, Rect2(0, 510, 1060, 90), Charte.PANNEAU, Charte.RAYON_CARTE)
	sujet.name = "PressTopic"
	D.text(sujet, 24, 54, "SUJET", 15, Charte.IVOIRE_3, 700, 120)
	var xs := 110.0 + Pieces.pastille(sujet, 110, 28, str(q.get("label", "")), "info", "PressTheme", "", Charte.DORE) + 10
	if not str(q.get("subject", "")).is_empty(): Pieces.pastille(sujet, xs, 28, str(q.get("subject", "")), "", "PressSubject", "", Charte.IVOIRE_2)
	_carte_joueur(app, page, Rect2(0, 620, 1060, 230), joueur(app, q))
	# Réponses rangées par famille de ton.
	var droite := D.rect(page, Rect2(1090, 110, 1158, 1040), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	droite.name = "PressAnswers"
	var y := 28.0
	for fam: Array in FAMILLES:
		var reponses: Array = q.answers.filter(func(r: Dictionary): return str(r.tone) in fam[2])
		if reponses.is_empty(): continue
		D.rect(droite, Rect2(28, y + 4, 6, 30), fam[1], 3)
		D.text(droite, 46, y + 30, str(fam[0]), 24, fam[1], 800, 300).add_theme_font_override("font", Charte.TITRE_FICHE)
		y += 48
		for r: Dictionary in reponses:
			var ton: Array = TONS.get(str(r.tone), ["", Charte.IVOIRE, "info"])
			var choisie: bool = str(choix.get(str(q.id), "")) == str(r.id)
			var carte := D.rect(droite, Rect2(28, y, 1102, 156), Color(ton[1], .14), Charte.RAYON_CARTE, Charte.IVOIRE if choisie else Color.TRANSPARENT)
			carte.name = "PressAnswerCard_" + str(r.id)
			D.rect(carte, Rect2(0, 0, 6, 156), ton[1], 3).mouse_filter = Control.MOUSE_FILTER_IGNORE
			Pieces.pastille(carte, 22, 14, str(ton[0]), str(ton[2]), "PressAnswerTone_" + str(r.id), "", ton[1])
			_para(carte, Rect2(22, 52, 1060, 62), str(r.text), 19, Charte.IVOIRE, 500)
			var x := 22.0
			var effets: Dictionary = r.get("effects", {})
			for e: Array in EFFETS:
				var v := int(effets.get(e[0], 0))
				if v == 0: continue
				x += _mini(carte, x, 120, "%s %s" % [e[1], _signe(v)], _couleur(v, e[2])) + 8
			var reponse := r
			Pieces.rendre_cliquable(carte, Vector2(1102, 156), func(): _repondre(view, q, reponse), "PressAnswerPick_" + str(r.id), str(ton[0]), "", Charte.RAYON_CARTE)
			y += 164
		y += 10

static func _mini(parent: Control, x: float, y: float, mot: String, couleur: Color) -> float:
	var largeur := C.BODY.get_string_size(mot, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(10, C.px(16))).x / C.density + 20
	var p := D.rect(parent, Rect2(x, y, largeur, 28), Color(couleur, .2), Charte.RAYON_PILULE)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	D.text(p, 10, 20, mot, 16, couleur, 700, largeur - 12).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return largeur

# --- B ---------------------------------------------------------------------------------------------------------------

const COLS_B := [["TON", 20.0, 170.0], ["RÉPONSE", 200.0, 1150.0], ["MORAL", 1380.0, 130.0], ["MÉDIAS", 1520.0, 130.0], ["SUPPORTERS", 1660.0, 150.0], ["PRESSION", 1820.0, 140.0], ["RELATION", 1970.0, 140.0]]

static func _b(app: Control, page: Control, view: Control, q: Dictionary, choix: Dictionary) -> void:
	var j: Dictionary = q.journalist
	# Bandeau : journaliste en ligne (rond, nom, média, attitude, relation chiffrée, style), joueur concerné à droite.
	var bandeau := D.rect(page, Rect2(0, 110, 2248, 150), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	bandeau.name = "PressJournalistCard"
	_rond(bandeau, Rect2(24, 22, 106, 106), str(j.get("name", "")), Charte.DORE)
	var nom := D.text(bandeau, 154, 66, str(j.get("name", "")), 32, Charte.IVOIRE, 800, 440)
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	D.text(bandeau, 154, 104, str(j.get("outlet", "")), 19, Charte.IVOIRE_2, 600, 440)
	D.text(bandeau, 620, 50, "ATTITUDE", 14, Charte.IVOIRE_3, 700, 200)
	_attitude(bandeau, 620, 62, q)
	D.text(bandeau, 860, 50, "RELATION", 14, Charte.IVOIRE_3, 700, 200)
	var score := int(q.get("relation", {}).get("score", 0))
	var rel := D.text(bandeau, 860, 98, _signe(score), 40, _couleur(score, true) if score != 0 else Charte.IVOIRE, 800, 120)
	rel.add_theme_font_override("font", Charte.TITRE_FICHE)
	D.text(bandeau, 1000, 50, "SUJET", 14, Charte.IVOIRE_3, 700, 200)
	Pieces.pastille(bandeau, 1000, 62, str(q.get("label", "")), "info", "PressTheme", "", Charte.DORE)
	# Joueur concerné en ligne : visage, nom, forme.
	var p := joueur(app, q)
	if not p.is_empty():
		var zone := D.rect(bandeau, Rect2(1400, 14, 830, 122), Charte.PANNEAU_3, Charte.RAYON_CARTE)
		zone.name = "PressPlayerCard"
		Visuel.portrait(zone, Rect2(16, 16, 90, 90), p, Charte.IVOIRE, true)
		var pn := D.text(zone, 124, 52, str(p.get("name", "")), 26, Charte.IVOIRE, 800, 330)
		pn.add_theme_font_override("font", Charte.TITRE_FICHE)
		D.text(zone, 124, 88, "%s · %d ans" % [str(p.get("pos", "")), int(p.get("age", 0))], 17, Charte.IVOIRE_2, 600, 330)
		Notes.pastilles(zone, Vector2(470, 44), Notes.forme(Notes.joueur(app.model, str(p.get("id", "")))), Vector2(60, 36), 6)
	# Question en grand.
	var question := D.rect(page, Rect2(0, 280, 2248, 150), Charte.MORAL, Charte.RAYON_CARTE)
	question.name = "PressQuestionBubble"
	_para(question, Rect2(34, 24, 2180, 110), str(q.get("question", "")), 32, Charte.ENCRE, 700)
	# Réponses en lignes (style Effectif) : ton en pastille, réponse, une colonne par effet.
	var table := D.rect(page, Rect2(0, 450, 2248, 700), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	table.name = "PressAnswers"
	D.rect(table, Rect2(0, 0, 2248, 50), Charte.BANDEAU_ENTETE, Charte.RAYON_PANNEAU).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for col: Array in COLS_B: D.text(table, float(col[1]) + 10, 33, str(col[0]), 16, Charte.IVOIRE_3, 700, float(col[2]))
	var ordre := ["confident", "humour", "honest", "cautious", "aggressive"]
	var reponses: Array = q.answers.duplicate()
	reponses.sort_custom(func(a: Dictionary, b: Dictionary): return ordre.find(str(a.tone)) < ordre.find(str(b.tone)))
	for i in reponses.size():
		var r: Dictionary = reponses[i]
		var ton: Array = TONS.get(str(r.tone), ["", Charte.IVOIRE, "info"])
		var y := 58.0 + i * 126.0
		var choisie: bool = str(choix.get(str(q.id), "")) == str(r.id)
		var ligne := D.rect(table, Rect2(8, y, 2232, 120), Color(Charte.IVOIRE, .035) if i % 2 == 1 else Color.TRANSPARENT, Charte.RAYON_PETIT, Charte.IVOIRE if choisie else Color.TRANSPARENT)
		ligne.name = "PressAnswerRow_" + str(r.id)
		D.rect(ligne, Rect2(0, 10, 6, 100), ton[1], 3).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Pieces.pastille(ligne, 22, 43, str(ton[0]), str(ton[2]), "PressAnswerTone_" + str(r.id), "", ton[1])
		_para(ligne, Rect2(202, 18, 1150, 90), str(r.text), 20, Charte.IVOIRE, 500)
		var effets: Dictionary = r.get("effects", {})
		for k in EFFETS.size():
			var e: Array = EFFETS[k]
			var v := int(effets.get(e[0], 0))
			var t := D.text(ligne, float(COLS_B[k + 2][1]) + 4, 74, _signe(v), 38, _couleur(v, e[2]), 800, 120)
			t.add_theme_font_override("font", Charte.TITRE_FICHE)
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var reponse := r
		Pieces.rendre_cliquable(ligne, Vector2(2232, 120), func(): _repondre(view, q, reponse), "PressAnswerPick_" + str(r.id), str(ton[0]), "", Charte.RAYON_PETIT)
