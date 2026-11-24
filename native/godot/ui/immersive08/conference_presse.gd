extends RefCounted
## Conférence de presse (revue FM27, idée 27 ; choix de Léo du 23/11/2026 : option A) dans la salle de presse
## (press_room_view.gd), une question à la fois. À gauche : le journaliste, sa question en bulle, le sujet, le joueur
## concerné (un vrai joueur choisi par le moteur selon l'actualité) ; à droite : les cinq réponses rangées en familles
## Positif / Neutre / Offensif, avec leur pastille de ton. Aucun effet n'est montré avant de répondre : un clic dit la
## réponse tout de suite (aucun bouton Confirmer), la question suivante s'affiche, et la réaction se découvre ensuite en
## flèches colorées par domaine (moral du joueur, médias, supporters, pression, relation), jamais en chiffres. Une réponse
## dite ne se reprend pas. La dernière réponse publie la conférence (commande moteur `press_conference`).
## Clic sur le journaliste ou sur le joueur : petite fenêtre visuelle (fenetre_visuelle.gd ; Échap, ✕, clic à côté).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Notes = preload("res://ui/notes_match.gd")
const Visuel = preload("res://ui/immersive08/centre_visuel.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")

## Ton du moteur → [mot, couleur, icône].
const TONS := {
	"confident": ["Affirmé", Charte.GAIN, "check"],
	"humour": ["Humour", Charte.CONFIANCE, "star"],
	"honest": ["Honnête", Charte.MORAL, "people"],
	"cautious": ["Prudent", Charte.REPOS, "info"],
	"aggressive": ["Agressif", Charte.PERTE, "warning"],
}
## Familles de ton : [mot, couleur, tons].
const FAMILLES := [["POSITIF", Charte.GAIN, ["confident", "humour"]], ["NEUTRE", Charte.MORAL, ["honest", "cautious"]], ["OFFENSIF", Charte.PERTE, ["aggressive"]]]
## Domaines de la réaction : [clé de l'effet, mot, plus = bien ?]. « Moral » = moral du joueur concerné.
const DOMAINES := [["player", "Moral", true], ["media", "Médias", true], ["fans", "Supporters", true], ["pressure", "Pression", false], ["relation", "Relation", true]]
## Actualité du joueur (moteur) → [mot, icône, couleur].
const ACTUALITES := {
	"blesse": ["Blessé", "heart", Charte.PERTE], "forme": ["En forme", "star", Charte.GAIN], "recrue": ["Recrue", "people", Charte.MORAL],
	"jeune": ["Jeune qui perce", "star", Charte.CONFIANCE], "meforme": ["Méforme", "warning", Charte.INTENSIF], "cadre": ["Cadre", "check", Charte.IVOIRE_2],
}
## Relation du moteur → [couleur, icône].
const ATTITUDES := {"Complice": [Charte.GAIN, "star"], "En confiance": [Charte.CONDITION, "check"], "À découvrir": [Charte.IVOIRE_2, "info"],
	"Aucun échange": [Charte.IVOIRE_2, "info"], "Méfiance": [Charte.INTENSIF, "warning"], "Tendue": [Charte.PERTE, "warning"]}
const REALISME := {"modeste": Charte.REPOS, "realiste": Charte.GAIN, "ambitieux": Charte.INTENSIF, "irrealiste": Charte.PERTE}

## Flèche dessinée (aucune police du jeu n'a ▲ ▼) : sens > 0 vers le haut, < 0 vers le bas, 0 = signe égal.
class Fleche extends Control:
	var sens := 0
	var couleur := Color.WHITE
	func _draw() -> void:
		var w := size.x
		var h := size.y
		if sens > 0: draw_colored_polygon(PackedVector2Array([Vector2(w / 2.0, 0), Vector2(w, h), Vector2(0, h)]), couleur)
		elif sens < 0: draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w / 2.0, h)]), couleur)
		else:
			var e := maxf(2.0, h * .2)
			draw_rect(Rect2(0, h * .2, w, e), couleur)
			draw_rect(Rect2(0, h * .8 - e, w, e), couleur)

## Flèche d'un écart : sens et couleur (vert si favorable, rouge sinon, gris si rien ne bouge). `cote` en pixels.
static func fleche(valeur: float, bien_si_plus: bool, cote: float) -> Control:
	var f := Fleche.new()
	f.name = "Fleche"
	f.sens = 0 if is_zero_approx(valeur) else (1 if valeur > 0 else -1)
	f.couleur = Charte.IVOIRE_3 if f.sens == 0 else (Charte.GAIN if (valeur > 0) == bien_si_plus else Charte.PERTE)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.custom_minimum_size = Vector2(cote, cote * .8)
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return f

## Flèche posée dans le gabarit (unités).
static func _fleche_a(parent: Control, r: Rect2, valeur: float, bien_si_plus: bool) -> Control:
	var f := fleche(valeur, bien_si_plus, 1)
	f.custom_minimum_size = Vector2.ZERO
	parent.add_child(f)
	D.place(f, r)
	return f

## Voile sombre posé sur la photo de la salle de presse : le même pour les questions et pour le compte-rendu.
static func voile(view: Control) -> ColorRect:
	var rideau := ColorRect.new()
	rideau.name = "PressFmVoile"
	rideau.color = Color(Charte.NOIR_PANNEAU, .86)
	rideau.mouse_filter = Control.MOUSE_FILTER_STOP
	view.ui.add_child(rideau)
	rideau.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rideau

## Salle de presse : remplace son panneau tant qu'une conférence est à répondre. Voile sombre sur la photo de la salle,
## contenu dans un gabarit 2248 × 1300 (écran plein : 2560 × 1440 unités).
static func construire(view: Control) -> void:
	voile(view)
	var page := Control.new()
	page.name = "PressFmPage"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.ui.add_child(page)
	D.place(page, Rect2(156, 70, 2248, 1300))
	var questions: Array = view._questions()
	var index: int = clampi(view.question_index, 0, questions.size() - 1)
	var q: Dictionary = questions[index]
	var titre := D.text(page, 0, 64, "CONFÉRENCE DE PRESSE", 64, Charte.IVOIRE, 800, 1060)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	var x := _progression(view, page, questions, view.choices, index, Vector2(1090, 26))
	_moment(view, page, x + 14.0)
	var app: Control = view.app
	_journaliste(view, page, q)
	_sujet(page, q)
	_carte_joueur(app, page, Rect2(0, 598, 1060, 196), q)
	_reaction(page, Rect2(0, 806, 1060, 108), questions, view.choices, index)
	_promesse(view, page, Rect2(0, 926, 1060, 256))
	_reponses(view, page, q, view.choices)
	_gabi(view, page)

## Une pastille par question : dite = ton choisi (couleur + mot), en cours = crème, à venir = grise ; clic sur une
## question déjà dite = la revoir avec sa réaction (on ne reprend pas une réponse). Rend la fin de la rangée.
static func _progression(view: Control, page: Control, questions: Array, choix: Dictionary, index: int, at: Vector2) -> float:
	var x := at.x
	for k in questions.size():
		var qk: Dictionary = questions[k]
		var mot := "Q%d" % (k + 1)
		var couleur: Color = Charte.IVOIRE_2
		var fond: Color = Charte.PANNEAU_3
		var r := _reponse_dite(qk, choix)
		if not r.is_empty():
			var ton: Array = TONS.get(str(r.tone), ["", Charte.IVOIRE])
			mot += " · " + str(ton[0])
			couleur = Charte.ENCRE
			fond = ton[1]
		if k == index:
			couleur = Charte.ENCRE
			if r.is_empty(): fond = Charte.IVOIRE
		var w := Pieces.pastille(page, x, at.y, mot, "", "PressQuestionPill_%d" % k, "", couleur, fond)
		if k == index: D.rect(page.get_node("PressQuestionPill_%d" % k), Rect2(-3, -3, w + 6, 40), Color.TRANSPARENT, Charte.RAYON_PILULE, Charte.IVOIRE).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cible := k
		if k != index and (not r.is_empty() or view._next_unanswered(-1) == k):
			Pieces.rendre_cliquable(page.get_node("PressQuestionPill_%d" % k), Vector2(w, 34), func(): view._select_question(cible), "PressQuestionPillOpen_%d" % k, mot, "", Charte.RAYON_PILULE)
		x += w + 10
	return x

## Enjeu de la conférence : grand moment (plus de questions, en personne) ou conférence ordinaire.
static func _moment(view: Control, page: Control, x: float) -> void:
	var conference: Dictionary = view.data.get("conference", {})
	var moment: Variant = conference.get("moment")
	if moment is Dictionary: Pieces.pastille(page, x, 26, str(moment.get("label", "Grand moment")), "star", "PressMoment", "", Charte.DORE)
	else: Pieces.pastille(page, x, 26, "Ordinaire", "info", "PressMoment", "", Charte.IVOIRE_2)

static func _reponse_dite(q: Dictionary, choix: Dictionary) -> Dictionary:
	var id := str(choix.get(str(q.get("id", "")), ""))
	if id.is_empty(): return {}
	for r: Dictionary in q.get("answers", []):
		if str(r.get("id", "")) == id: return r
	return {}

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

static func _initiales(nom: String) -> String:
	var mots := nom.split(" ", false)
	return "".join(PackedStringArray(Array(mots).map(func(w: String): return w.substr(0, 1)))).substr(0, 2).to_upper()

static func _rond(parent: Control, r: Rect2, nom: String, couleur: Color) -> void:
	var rond := D.rect(parent, r, Color(couleur, .3), 999, couleur)
	rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := D.text(rond, r.size.x / 2, r.size.y * .64, _initiales(nom), int(r.size.y * .4), Charte.IVOIRE, 800, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Attitude du journaliste en pastille (mot du moteur + icône + couleur).
static func _attitude(parent: Control, x: float, y: float, relation: Dictionary, id: String) -> float:
	var mot := str(relation.get("label", "À découvrir"))
	var a: Array = ATTITUDES.get(mot, [Charte.IVOIRE_2, "info"])
	return Pieces.pastille(parent, x, y, mot, str(a[1]), id, "", a[0])

# --- Gauche ----------------------------------------------------------------------------------------------------------

## Journaliste (rond, nom, média, style, attitude ; clic = sa petite fenêtre) et sa question en bulle.
static func _journaliste(view: Control, page: Control, q: Dictionary) -> void:
	var j: Dictionary = q.get("journalist", {})
	var cadre := D.rect(page, Rect2(0, 110, 1060, 380), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	cadre.name = "PressJournalistCard"
	_rond(cadre, Rect2(28, 30, 120, 120), str(j.get("name", "")), Charte.DORE)
	var nom := D.text(cadre, 172, 72, str(j.get("name", "")), 34, Charte.IVOIRE, 800, 520)
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	nom.name = "PressJournalistName"
	D.text(cadre, 172, 108, str(j.get("outlet", "")), 20, Charte.IVOIRE_2, 600, 520)
	D.text(cadre, 720, 56, "ATTITUDE", 15, Charte.IVOIRE_3, 700, 200)
	_attitude(cadre, 720, 70, q.get("relation", {}), "PressAttitude")
	if not str(j.get("styleLabel", "")).is_empty(): Pieces.pastille(cadre, 172, 124, str(j.get("styleLabel", "")), "tactic", "PressStyle", "", Charte.IVOIRE_2)
	var qui := str(j.get("id", ""))
	Pieces.rendre_cliquable(cadre, Vector2(1060, 170), func(): _fenetre_journaliste(view, page, qui, q), "PressJournalistOpen", str(j.get("name", "")), "", Charte.RAYON_PANNEAU)
	var bulle := D.rect(cadre, Rect2(28, 186, 1004, 166), Charte.MORAL, Charte.RAYON_CARTE)
	bulle.name = "PressQuestionBubble"
	bulle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var question := _para(bulle, Rect2(30, 18, 944, 136), str(q.get("question", "")), 27, Charte.ENCRE, 700)
	question.name = "PressQuestion"

## Sujet de la question (thème + sujet du moteur), relance d'une déclaration archivée.
static func _sujet(page: Control, q: Dictionary) -> void:
	var sujet := D.rect(page, Rect2(0, 506, 1060, 78), Charte.PANNEAU, Charte.RAYON_CARTE)
	sujet.name = "PressTopic"
	D.text(sujet, 24, 48, "SUJET", 15, Charte.IVOIRE_3, 700, 120)
	var x := 110.0 + Pieces.pastille(sujet, 110, 22, str(q.get("label", "")), "info", "PressTheme", "", Charte.DORE) + 10
	if not str(q.get("subject", "")).is_empty(): x += Pieces.pastille(sujet, x, 22, str(q.get("subject", "")), "", "PressSubject", "", Charte.IVOIRE_2) + 10
	if q.get("followUp") is Dictionary: Pieces.pastille(sujet, x, 22, "Relance", "warning", "PressArchivedSource", "", Charte.INTENSIF)

## Joueur de l'effectif visé par la question (moteur), {} si aucun.
static func joueur(app: Control, q: Dictionary) -> Dictionary:
	var vise: Variant = q.get("player")
	if not vise is Dictionary: return {}
	for p: Variant in app.model.get("squad", []):
		if p is Dictionary and str(p.get("id", "")) == str(vise.get("id", "")): return p
	return {"id": vise.get("id"), "name": vise.get("name", "")}

## Suivi du vestiaire du joueur : moral (satisfaction) et confiance envers le coach, {} si non suivi.
static func _vestiaire(app: Control, id: String) -> Dictionary:
	for m: Variant in app.model.get("clubLife", {}).get("relationships", {}).get("players", []):
		if m is Dictionary and str(m.get("id", "")) == id: return m
	return {}

## Carte du joueur concerné : visage, nom, poste, âge, actualité, forme ; clic = sa petite fenêtre.
static func _carte_joueur(app: Control, page: Control, r: Rect2, q: Dictionary) -> void:
	var carte := D.rect(page, r, Charte.PANNEAU, Charte.RAYON_CARTE)
	carte.name = "PressPlayerCard"
	var p := joueur(app, q)
	if p.is_empty():
		Pieces.pastille(carte, 24, 24, "Groupe", "people", "PressPlayerNone", "", Charte.IVOIRE_2)
		return
	D.text(carte, 24, 34, "JOUEUR CONCERNÉ", 15, Charte.IVOIRE_3, 700, 300)
	Visuel.portrait(carte, Rect2(24, 50, 96, 96), p, Charte.IVOIRE, true)
	var nom := D.text(carte, 140, 88, str(p.get("name", "")), 30, Charte.IVOIRE, 800, 560)
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	nom.name = "PressPlayerName"
	if p.has("pos"): D.text(carte, 140, 124, "%s · %d ans" % [str(p.get("pos", "")), int(p.get("age", 0))], 19, Charte.IVOIRE_2, 600, 520)
	var actu: Array = ACTUALITES.get(str(q.get("player", {}).get("news", "")), [])
	if not actu.is_empty(): Pieces.pastille(carte, r.size.x - 40 - Pieces.largeur_pastille(str(actu[0]), str(actu[1])), 24, str(actu[0]), str(actu[1]), "PressPlayerNews", "", actu[2])
	D.text(carte, 24, 178, "FORME", 15, Charte.IVOIRE_3, 700, 120)
	Notes.pastilles(carte, Vector2(110, 154), Notes.forme(Notes.joueur(app.model, str(p.get("id", "")))), Vector2(56, 34), 8)
	Pieces.rendre_cliquable(carte, r.size, func(): _fenetre_joueur(app, page, p, q), "PressPlayerOpen", str(p.get("name", "")), "", Charte.RAYON_CARTE)

## Réaction à la réponse dite (question affichée, sinon la dernière dite) : une flèche par domaine, jamais de chiffre.
static func _reaction(page: Control, r: Rect2, questions: Array, choix: Dictionary, index: int) -> void:
	var montre := -1
	if not _reponse_dite(questions[index], choix).is_empty(): montre = index
	else:
		for k in questions.size():
			if not _reponse_dite(questions[k], choix).is_empty(): montre = k
	if montre < 0: return
	var q: Dictionary = questions[montre]
	var dite := _reponse_dite(q, choix)
	var carte := D.rect(page, r, Charte.PANNEAU, Charte.RAYON_CARTE)
	carte.name = "PressReaction"
	D.text(carte, 24, 34, "RÉACTION · Q%d" % (montre + 1), 15, Charte.IVOIRE_3, 700, 300)
	var ton: Array = TONS.get(str(dite.get("tone", "")), ["", Charte.IVOIRE, "info"])
	Pieces.pastille(carte, 24, 56, str(ton[0]), str(ton[2]), "PressReactionTone", "", ton[1])
	_fleches(carte, Vector2(230, 38), dite.get("effects", {}), 166.0, "PressReaction_")

## Rangée des cinq domaines : mot en petit, flèche colorée dessous.
static func _fleches(parent: Control, at: Vector2, effets: Dictionary, pas: float, prefixe: String) -> void:
	for k in DOMAINES.size():
		var d: Array = DOMAINES[k]
		var v := float(effets.get(d[0], effets.get("morale", 0) if d[0] == "player" else 0))
		var x := at.x + k * pas
		D.text(parent, x, at.y, str(d[1]).to_upper(), 14, Charte.IVOIRE_3, 700, pas - 10)
		_fleche_a(parent, Rect2(x + 4, at.y + 14, 34, 28), v, d[2]).name = prefixe + str(d[0])

## Objectif public (facultatif, début de saison) : un clic retient l'objectif, annoncé avec la dernière réponse ;
## un second clic l'annule. Aucune réaction annoncée d'avance.
static func _promesse(view: Control, page: Control, r: Rect2) -> void:
	var offre: Dictionary = view._promise_offer()
	if offre.is_empty(): return
	var cadre := D.rect(page, r, Charte.PANNEAU, Charte.RAYON_CARTE)
	cadre.name = "PressPromiseOffer"
	D.text(cadre, 24, 34, "OBJECTIF PUBLIC", 15, Charte.IVOIRE_3, 700, 300)
	_para(cadre, Rect2(24, 44, r.size.x - 48, 56), str(offre.get("question", "")), 19, Charte.IVOIRE, 600)
	var options: Array = offre.get("options", []).duplicate()
	if offre.get("refuse") is Dictionary: options.append(offre.refuse)
	var x := 24.0
	var y := 112.0
	for o: Dictionary in options:
		var id := str(o.get("id", ""))
		var refus := id == "refuse"
		var mot := "Ne rien promettre" if refus else str(o.get("label", ""))
		var couleur: Color = Charte.IVOIRE_2 if refus else REALISME.get(str(o.get("realism", "")), Charte.IVOIRE)
		var choisi: bool = view.promise_choice == id
		var w := Pieces.largeur_pastille(mot, "check" if choisi else "")
		if x + w > r.size.x - 24:
			x = 24.0
			y += 42.0
		Pieces.pastille(cadre, x, y, mot, "check" if choisi else "", "PressPromiseChip_" + id.replace(":", "_"), "", Charte.ENCRE if choisi else couleur, couleur if choisi else Charte.PANNEAU_3)
		Pieces.rendre_cliquable(cadre.get_node("PressPromiseChip_" + id.replace(":", "_")), Vector2(w, 34), func(): view._choose_promise(id), "PressPromise_" + id.replace(":", "_"), mot, "", Charte.RAYON_PILULE)
		x += w + 10
	if not view.promise_choice.is_empty():
		var o: Variant = view._promise_option(view.promise_choice)
		if o is Dictionary:
			var resume := Label.new()
			resume.name = "PressPromiseSummary"
			resume.text = "Refus" if view.promise_choice == "refuse" else "Annonce · " + str(o.get("label", ""))
			resume.visible = false
			cadre.add_child(resume)

## Gabi répond à la place du manager (conférence ordinaire) : un clic ; sinon « En personne ». Réglage des conférences
## ordinaires en deux pastilles (Y aller / Envoyer l'adjoint).
static func _gabi(view: Control, page: Control) -> void:
	var conference: Dictionary = view.data.get("conference", {})
	var delegation: Dictionary = conference.get("delegation", {})
	var y := 1196.0
	var x := 0.0
	if not delegation.is_empty():
		if bool(delegation.get("allowed", false)):
			var w := Pieces.pastille(page, x, y, "Laisser Gabi répondre", "people", "PressDelegateCard", "", Charte.IVOIRE_2)
			Pieces.rendre_cliquable(page.get_node("PressDelegateCard"), Vector2(w, 34), func(): view._delegate(), "PressDelegate", "Laisser Gabi répondre", "", Charte.RAYON_PILULE).set_meta("contextual_enabled", true)
			x += w + 24
		else:
			x += Pieces.pastille(page, x, y, "En personne", "warning", "PressDelegateReason", "", Charte.DORE) + 24
	var reglage: Dictionary = view.data.get("policy", {})
	if reglage.is_empty(): return
	D.text(page, x, y + 24, "ORDINAIRES", 14, Charte.IVOIRE_3, 700, 140)
	x += 130
	for option: Array in [["moi", "Y aller", "check"], ["adjoint", "Envoyer l’adjoint", "people"]]:
		var cle: String = option[0]
		var actif: bool = str(reglage.get("ordinary", "moi")) == cle
		var w := Pieces.pastille(page, x, y, option[1], option[2], "PressPolicyChip_" + cle, "", Charte.ENCRE if actif else Charte.IVOIRE_2, Charte.GAIN if actif else Charte.PANNEAU_3)
		if not actif: Pieces.rendre_cliquable(page.get_node("PressPolicyChip_" + cle), Vector2(w, 34), func(): view._set_policy(cle), "PressPolicy_" + cle, option[1], "", Charte.RAYON_PILULE).set_meta("contextual_enabled", true)
		x += w + 10

# --- Droite : réponses -----------------------------------------------------------------------------------------------

## Réponses rangées par famille de ton. Question non répondue : un clic dit la réponse. Question déjà dite : la réponse
## retenue est entourée, avec sa réaction en flèches ; les autres sont éteintes.
static func _reponses(view: Control, page: Control, q: Dictionary, choix: Dictionary) -> void:
	var droite := D.rect(page, Rect2(1090, 110, 1158, 1050), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	droite.name = "PressAnswers"
	var dite := _reponse_dite(q, choix)
	var y := 28.0
	for fam: Array in FAMILLES:
		var reponses: Array = q.get("answers", []).filter(func(r: Dictionary): return str(r.tone) in fam[2])
		if reponses.is_empty(): continue
		D.rect(droite, Rect2(28, y + 4, 6, 30), fam[1], 3)
		D.text(droite, 46, y + 30, str(fam[0]), 24, fam[1], 800, 300).add_theme_font_override("font", Charte.TITRE_FICHE)
		y += 48
		for r: Dictionary in reponses:
			var ton: Array = TONS.get(str(r.tone), ["", Charte.IVOIRE, "info"])
			var retenue := not dite.is_empty() and str(dite.get("id", "")) == str(r.id)
			var eteinte := not dite.is_empty() and not retenue
			var h := 196.0 if retenue else 120.0
			var carte := D.rect(droite, Rect2(28, y, 1102, h), Color(ton[1], .06 if eteinte else .14), Charte.RAYON_CARTE, Charte.IVOIRE if retenue else Color.TRANSPARENT)
			carte.name = "PressAnswerCard_" + str(r.id)
			if eteinte: carte.modulate = Color(1, 1, 1, .45)
			D.rect(carte, Rect2(0, 0, 6, h), ton[1], 3).mouse_filter = Control.MOUSE_FILTER_IGNORE
			Pieces.pastille(carte, 22, 14, str(ton[0]), str(ton[2]), "PressAnswerTone_" + str(r.id), "", ton[1])
			_para(carte, Rect2(22, 54, 1060, 60), str(r.text), 19, Charte.IVOIRE, 500)
			if retenue: _fleches(carte, Vector2(22, 140), r.get("effects", {}), 180.0, "PressAnswerReaction_")
			elif dite.is_empty():
				var qid := str(q.get("id", ""))
				var rid := str(r.get("id", ""))
				Pieces.rendre_cliquable(carte, Vector2(1102, h), func(): view._choose_answer(qid, rid), "PressAnswer_%s_%s" % [qid, rid], str(ton[0]), "", Charte.RAYON_CARTE).set_meta("contextual_enabled", true)
			y += h + 8
		y += 10

# --- Petites fenêtres ------------------------------------------------------------------------------------------------

static func _couleur_moral(v: float) -> Color:
	return Charte.GAIN if v >= 70 else Charte.INTENSIF if v >= 45 else Charte.PERTE

## Joueur concerné : visage, poste, actualité ; tuiles Forme (5 dernières notes), Moral et Confiance envers le coach.
static func _fenetre_joueur(app: Control, page: Control, p: Dictionary, q: Dictionary) -> void:
	var fond := Fenetre.ouvrir(page, "PressPlayerWindow", str(p.get("name", "")), "people", 980, 470)
	Visuel.portrait(fond, Rect2(36, 92, 120, 120), p, Charte.IVOIRE, true)
	if p.has("pos"): D.text(fond, 180, 132, "%s · %d ans" % [str(p.get("pos", "")), int(p.get("age", 0))], 22, Charte.IVOIRE_2, 600, 500)
	var actu: Array = ACTUALITES.get(str(q.get("player", {}).get("news", "")), [])
	if not actu.is_empty(): Pieces.pastille(fond, 180, 152, str(actu[0]), str(actu[1]), "PressPlayerWindowNews", "", actu[2])
	if p.get("injury") is Dictionary or (p.get("injury") is float and float(p.get("injury")) > 0): Pieces.pastille(fond, 180 + (Pieces.largeur_pastille(str(actu[0]), str(actu[1])) + 10 if not actu.is_empty() else 0), 152, "Blessé", "heart", "PressPlayerWindowInjured", "", Charte.PERTE)
	# Forme : les cinq dernières notes en pastilles colorées.
	var forme := D.rect(fond, Rect2(36, 240, 420, 190), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	forme.name = "PressPlayerWindowForm"
	D.text(forme, 18, 34, "FORME", 15, Charte.IVOIRE_3, 700, 200)
	var notes: Array = Notes.forme(Notes.joueur(app.model, str(p.get("id", ""))))
	if notes.is_empty(): D.text(forme, 18, 110, "—", 40, Charte.IVOIRE_3, 800, 200)
	else: Notes.pastilles(forme, Vector2(18, 70), notes, Vector2(70, 44), 8)
	var suivi := _vestiaire(app, str(p.get("id", "")))
	var tuiles := [["score", "Moral", "heart", "PressPlayerWindowMorale"], ["trust", "Confiance", "people", "PressPlayerWindowTrust"]]
	for k in tuiles.size():
		var t: Array = tuiles[k]
		var v: Variant = suivi.get(t[0])
		var zone := Rect2(476 + k * 240, 240, 228, 190)
		var tuile := Pieces.tuile(fond, zone, "—" if v == null else str(roundi(float(v))), str(t[1]), Charte.IVOIRE_3 if v == null else _couleur_moral(float(v)), str(t[3]), 52, "", str(t[2]))
		if v != null: D.bar(tuile, Rect2(12, 60, 204, 10), float(v), _couleur_moral(float(v)))

## Journaliste : média, style, attitude ; jauge de relation, nombre d'échanges, derniers tons répondus avec leur effet.
static func _fenetre_journaliste(view: Control, page: Control, id: String, q: Dictionary) -> void:
	var j: Dictionary = q.get("journalist", {})
	var fond := Fenetre.ouvrir(page, "PressJournalistWindow", str(j.get("name", "")), "", 980, 470)
	_rond(fond, Rect2(36, 92, 110, 110), str(j.get("name", "")), Charte.DORE)
	D.text(fond, 170, 126, str(j.get("outlet", "")), 22, Charte.IVOIRE_2, 600, 500)
	var x := 170.0
	if not str(j.get("styleLabel", "")).is_empty(): x += Pieces.pastille(fond, x, 146, str(j.get("styleLabel", "")), "tactic", "PressJournalistWindowStyle", "", Charte.IVOIRE_2) + 10
	var relation: Dictionary = q.get("relation", {})
	_attitude(fond, x, 146, relation, "PressJournalistWindowAttitude")
	var a: Array = ATTITUDES.get(str(relation.get("label", "")), [Charte.IVOIRE_2, "info"])
	# Relation : jauge de −100 à +100 centrée.
	var jauge := D.rect(fond, Rect2(36, 240, 420, 190), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	jauge.name = "PressJournalistWindowRelation"
	D.text(jauge, 18, 34, "RELATION", 15, Charte.IVOIRE_3, 700, 200)
	var score := clampf(float(relation.get("score", 0)), -100, 100)
	D.rect(jauge, Rect2(18, 100, 384, 12), Charte.PANNEAU_3, 6).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var milieu := 18 + 192.0
	var largeur := absf(score) / 100.0 * 192.0
	if largeur > 0: D.rect(jauge, Rect2(milieu if score > 0 else milieu - largeur, 100, largeur, 12), a[0], 6).mouse_filter = Control.MOUSE_FILTER_IGNORE
	D.rect(jauge, Rect2(milieu - 1, 92, 2, 28), Charte.IVOIRE_2).mouse_filter = Control.MOUSE_FILTER_IGNORE
	D.text(jauge, 18, 160, str(relation.get("label", "")), 26, a[0], 800, 384)
	Pieces.tuile(fond, Rect2(476, 240, 228, 190), str(int(relation.get("encounters", 0))), "Échanges", Charte.IVOIRE, "PressJournalistWindowEncounters", 52, "", "people")
	# Mémoire : derniers tons répondus à ce journaliste, flèche de l'effet sur la relation.
	var memoire := D.rect(fond, Rect2(716, 240, 228, 190), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	memoire.name = "PressJournalistWindowMemory"
	D.text(memoire, 14, 34, "DERNIERS TONS", 15, Charte.IVOIRE_3, 700, 200)
	var souvenirs: Array = []
	for personne: Variant in view.data.get("people", []):
		if personne is Dictionary and str(personne.get("id", "")) == id: souvenirs = personne.get("memory", [])
	var y := 50.0
	for e: Variant in souvenirs.slice(-3):
		if not e is Dictionary: continue
		var mot := str(e.get("toneLabel", ""))
		var couleur: Color = Charte.IVOIRE_2
		for cle: String in TONS:
			if TONS[cle][0] == mot: couleur = TONS[cle][1]
		var w := Pieces.pastille(memoire, 14, y, mot, "", "", "", couleur)
		_fleche_a(memoire, Rect2(14 + w + 10, y + 8, 22, 18), float(e.get("delta", 0)), true)
		y += 42
	if souvenirs.is_empty(): D.text(memoire, 14, 110, "—", 40, Charte.IVOIRE_3, 800, 200)
