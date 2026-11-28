extends RefCounted
## Compte-rendu de la conférence de presse (Léo, 25/11/2026) : même mise en page que l'écran des questions — grand
## titre, cartes de couleur, flèches en grand — dans le gabarit 2248 × 1300 posé sur la photo voilée.
## Haut : cinq grandes cartes (une par domaine) ; gauche : joueurs et journalistes ; droite : les déclarations.
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const C = preload("res://ui/immersive08/components.gd")
const S = preload("res://ui/contextual/skin.gd")
const SeasonLabel = preload("res://ui/season_label.gd")
const Fm = preload("res://ui/immersive08/conference_presse.gd")

const DOMAINES := [["morale", "Groupe", true], ["mediaTrust", "Médias", true], ["fanTrust", "Supporters", true], ["boardPressure", "Pression", false], ["trust", "Direction", true]]

static func _ton(valeur: float, bien_si_plus: bool) -> Color:
	if is_zero_approx(valeur): return Charte.IVOIRE_3
	return Charte.GAIN if (valeur > 0) == bien_si_plus else Charte.PERTE

static func _fleche(parent: Control, r: Rect2, valeur: float, bien_si_plus: bool) -> void:
	var f := Fm.fleche(valeur, bien_si_plus, 1)
	f.custom_minimum_size = Vector2.ZERO
	parent.add_child(f)
	D.place(f, r)

## Carte teintée par le sens de l'écart : fond voilé, filet de la couleur.
static func _carte(parent: Control, r: Rect2, ton: Color, nom := "") -> Panel:
	var carte := D.rect(parent, r, Charte.PANNEAU.lerp(ton, .2), Charte.RAYON_CARTE, Color(ton, .55))
	if not nom.is_empty(): carte.name = nom
	return carte

static func construire(view: Control, outcome: Dictionary) -> void:
	var page := Control.new()
	page.name = "PressFmPage"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.ui.add_child(page)
	D.place(page, Rect2(156, 70, 2248, 1300))
	var contexte: Dictionary = view.data.get("context", {})
	var titre := D.text(page, 0, 64, "CONFÉRENCE D’APRÈS-MATCH" if view.meeting.get("postmatch", false) else "COMPTE-RENDU", 64, Charte.IVOIRE, 800, 1400)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	var x := 0.0
	var largeur_titre := Charte.TITRE_FICHE.get_string_size(titre.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x / maxf(C.density, .01)
	x = largeur_titre + 40.0
	x += Pieces.pastille(page, x, 26, "Saison %s · semaine %d" % [SeasonLabel.label(contexte.get("season", 0)), int(contexte.get("week", 0)) + 1], "info", "PressSaison", "", Charte.IVOIRE_2) + 10.0
	if outcome.get("delegated", false): Pieces.pastille(page, x, 26, "Gabi a répondu", "star", "PressGabi", "", Charte.DORE)
	var fin := S.button("CONTINUER  →", view.director.close_room, true, true)
	fin.name = "PressReturn"
	fin.add_theme_font_size_override("font_size", maxi(12, C.px(24)))
	page.add_child(fin)
	D.place(fin, Rect2(1948, 18, 300, 60))
	fin.visible = view.meeting.get("completed", false)

	var y := 110.0
	y = _promesses_en_cours(view, page, y)
	y = _domaines(page, outcome, y)
	var haut := y + 20.0
	var bas := _gauche(view, page, outcome, haut)
	var gauche_vide: bool = is_equal_approx(bas, haut) and not _annonce_presente(view)
	_droite(view, page, haut, gauche_vide)
	_annonce(view, page, bas + 14.0)

## Rappel des promesses en cours, en pastilles (couleur = bien partie ou non).
static func _promesses_en_cours(view: Control, page: Control, y: float) -> float:
	var actives: Array = view._promises().get("active", [])
	if actives.is_empty(): return y
	var rangee := Control.new()
	rangee.name = "PressPromiseBanner"
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(rangee)
	D.place(rangee, Rect2(0, y, 2248, 34))
	var x := 0.0
	for promesse: Dictionary in actives:
		var progres: Dictionary = promesse.get("progress", {})
		var piste: Variant = progres.get("onTrack")
		var ton: Color = Charte.IVOIRE_2 if piste == null else (Charte.VERT_CLAIR if piste else Charte.DORE)
		x += Pieces.pastille(rangee, x, 0, "%s · %s" % [str(promesse.get("label", "")), str(progres.get("label", ""))], "star", "", "", ton) + 10.0
	return y + 54.0

static func _domaines(page: Control, outcome: Dictionary, y: float) -> float:
	var delta: Dictionary = outcome.get("delta", {})
	var rangee := Control.new()
	rangee.name = "PressOutcomeHeadline"
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(rangee)
	D.place(rangee, Rect2(0, y, 2248, 130))
	var apres: Dictionary = outcome.get("after", {})
	var presents := DOMAINES.filter(func(e: Array): return delta.has(e[0]))
	var n := maxi(1, presents.size())
	var l := (2248.0 - 20.0 * (n - 1)) / n
	for k in presents.size():
		var e: Array = presents[k]
		var v := float(delta[e[0]])
		var ton := _ton(v, e[2])
		var carte := _carte(rangee, Rect2(k * (l + 20.0), 0, l, 130), ton, "PressOutcome_" + str(e[0]))
		D.text(carte, 28, 40, str(e[1]).to_upper(), 22, Charte.IVOIRE_2, 700, l - 56.0)
		# Valeur après la conférence si le modèle la donne, sinon le sens en toutes lettres.
		var ecart := "%+d" % roundi(v) if roundi(v) != 0 else "stable"
		if apres.has(e[0]):
			var valeur := D.text(carte, 28, 104, str(roundi(float(apres[e[0]]))), 52, Charte.IVOIRE, 800, 200)
			valeur.add_theme_font_override("font", Charte.TITRE_FICHE)
		else:
			ecart = "stable" if roundi(v) == 0 else ("en hausse" if v > 0 else "en baisse")
		D.text(carte, l - 200.0, 100, ecart, 30, ton, 800, 140, HORIZONTAL_ALIGNMENT_RIGHT)
		_fleche(carte, Rect2(l - 52.0, 76, 26, 21), v, e[2])
	return y + 130.0

static func _ligne(parent: Control, y: float, nom: String, qui: String, quoi: String, v: float, id: String, h := 76.0) -> void:
	var ton := _ton(v, true)
	var carte := _carte(parent, Rect2(0, y, 1060, h), ton, id)
	var m := h / 2.0
	D.rect(carte, Rect2(0, 12, 6, h - 24.0), ton, 3)
	var t := D.text(carte, 32, m + 10.0, qui, 30, Charte.IVOIRE, 800, 560)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	D.text(carte, 610, m + 8.0, quoi, 24, Charte.IVOIRE_2, 600, 180)
	D.text(carte, 800, m + 10.0, "%+d" % roundi(v) if roundi(v) != 0 else "stable", 28, ton, 800, 150, HORIZONTAL_ALIGNMENT_RIGHT)
	_fleche(carte, Rect2(980, m - 13.0, 32, 26), v, true)

## Joueurs visés (moral) puis journalistes (relation). Rend le bas de la colonne.
static func _gauche(view: Control, page: Control, outcome: Dictionary, y: float) -> float:
	var colonne := Control.new()
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(colonne)
	D.place(colonne, Rect2(0, y, 1060, 1300.0 - y))
	var cy := 0.0
	var joueurs: Array = outcome.get("players", [])
	var echanges: Array = outcome.get("exchanges", [])
	# Les lignes s'étirent pour remplir la hauteur (place gardée pour l'objectif annoncé), sans dépasser 150.
	var entetes := (36.0 if not joueurs.is_empty() else 0.0) + (36.0 if not echanges.is_empty() else 0.0)
	var lignes := joueurs.size() + echanges.size()
	var h := clampf((1300.0 - y - 120.0 - entetes) / maxf(1.0, lignes) - 10.0, 76.0, 150.0)
	if not joueurs.is_empty():
		D.text(colonne, 0, cy + 22, "JOUEURS", 20, Charte.IVOIRE_3, 700, 300)
		cy += 36.0
		for p: Dictionary in joueurs:
			_ligne(colonne, cy, "", str(p.get("name", "")), "Moral", float(p.get("delta", 0)), "PressOutcomePlayer_" + str(p.get("id", "")).validate_node_name(), h)
			cy += h + 10.0
	if not echanges.is_empty():
		D.text(colonne, 0, cy + 22, "JOURNALISTES", 20, Charte.IVOIRE_3, 700, 300)
		cy += 36.0
		for ex: Dictionary in echanges:
			var nom := "Identité indisponible"
			for personne: Dictionary in view.data.get("people", []):
				if personne.get("id") == ex.get("journalistId"): nom = str(personne.get("name", "")); break
			_ligne(colonne, cy, "", nom, "Relation", float(ex.get("delta", 0)), "PressOutcomeRelation_" + str(ex.get("journalistId", "")).validate_node_name(), h)
			cy += h + 10.0
	return y + cy

static func _annonce_presente(view: Control) -> bool:
	for promesse: Dictionary in view._promises().get("active", []):
		if view._context_key(promesse) == view._context: return true
	return false

## Déclarations ; elles prennent toute la largeur quand la colonne de gauche n'a rien à montrer.
static func _droite(view: Control, page: Control, y: float, pleine := false) -> void:
	var colonne := Control.new()
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(colonne)
	var x0 := 0.0 if pleine else 1100.0
	var lw := 2248.0 - x0
	D.place(colonne, Rect2(x0, y, lw, 1300.0 - y))
	var cy := 0.0
	var vus := 0
	for fiche: Dictionary in view.data.get("history", []):
		if view._context_key(fiche) != view._context or vus >= 4: continue
		vus += 1
		var journaliste: Dictionary = fiche.get("journalist", {})
		var carte := D.rect(colonne, Rect2(0, cy, lw, 204), Charte.PANNEAU, Charte.RAYON_CARTE)
		D.rect(carte, Rect2(0, 14, 6, 176), Charte.DORE, 3)
		D.text(carte, 32, 44, str(journaliste.get("name", "Identité indisponible")) + " · " + str(journaliste.get("outlet", "")), 24, Charte.DORE, 800, lw - 68.0)
		var question: Variant = fiche.get("question", fiche.get("questionText"))
		var reponse: Variant = fiche.get("answer", fiche.get("answerText"))
		if question is String: Fm._para(carte, Rect2(32, 50, lw - 64.0, 64), question, 21, Charte.IVOIRE_2, 500)
		if reponse is String: Fm._para(carte, Rect2(32, 116, lw - 64.0, 84), ("Gabi : " if fiche.get("delegated", false) else "") + reponse, 24, Charte.IVOIRE, 700)
		cy += 212.0

## Objectif annoncé avec la dernière réponse : réactions des supporters, médias, direction, pression.
static func _annonce(view: Control, page: Control, y: float) -> void:
	for promesse: Dictionary in view._promises().get("active", []):
		if view._context_key(promesse) != view._context: continue
		var annonce: Dictionary = promesse.get("announce", {})
		var carte := D.rect(page, Rect2(0, y, 1060, 90), Charte.PANNEAU, Charte.RAYON_CARTE, Color(Charte.DORE, .55))
		carte.name = "PressPromiseAnnounced"
		D.text(carte, 24, 40, "« %s »" % str(promesse.get("label", "")), 22, Charte.DORE, 700, 1010)
		var x := 24.0
		for cle: Array in [["fanTrust", "Supporters", true], ["mediaTrust", "Médias", true], ["trust", "Direction", true], ["boardPressure", "Pression", false]]:
			D.text(carte, x, 78, str(cle[1]), 20, Charte.IVOIRE_2, 600, 150)
			_fleche(carte, Rect2(x + 126, 52, 34, 27), float(annonce.get(cle[0], 0)), cle[2])
			x += 250.0
		return
