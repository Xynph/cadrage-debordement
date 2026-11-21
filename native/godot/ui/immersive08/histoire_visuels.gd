extends RefCounted
## Club › Histoire : deux options visuelles à départager (revue du 21/11/2026, n° 8), provisoires.
## CD_VARIANTE_VISUELLE=A : tuiles et anneaux (bilan, touche, mêlée, discipline), plaques de score, tuiles trophée.
## CD_VARIANTE_VISUELLE=B : frise des saisons sur la photo du trophée voilée, statistiques en barres à côté.
## Sans la variable : rien de ce fichier n'est utilisé (écran actuel). Tout est cliquable (compétitions, rencontre, club).
## Les chiffres viennent de la projection (performanceAnalysis, palmares) : aucun calcul de jeu ici.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/game_skin.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const Palmares = preload("res://ui/immersive08/palmares_text.gd")
const EntityLink = preload("res://ui/entity_link.gd")
const Analyse = preload("res://ui/performance_analysis_view.gd")
const Competition = preload("res://ui/immersive08/competition_canvas.gd")

const TOUCHE := Charte.MORAL       ## bleu
const MELEE := Charte.CONFIANCE    ## violet
const DISCIPLINE := Charte.INTENSIF ## orange
const POUR := Charte.GAIN
const CONTRE := Charte.PERTE

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

static func build(app: Control, years: Array) -> Control:
	var racine := C.v(22)
	racine.name = "ClubHistoryVisual" + variante()
	C.fill(racine)
	if variante() == "B": _option_b(app, racine, years)
	else: _option_a(app, racine, years)
	Pastilles._marquer(racine)
	return racine

# --- Données ---------------------------------------------------------------------------------------

static func _analyse(app: Control) -> Dictionary:
	return app.model.get("clubLife", {}).get("performanceAnalysis", {})

static func _taux(m: Dictionary) -> float:
	return -1.0 if m.get("rate") == null else float(m.rate) * 100.0

static func _couleur_issue(issue: String) -> Color:
	match issue.to_upper().left(1):
		"V": return POUR
		"D": return CONTRE
	return Charte.IVOIRE_2

static func _aller_classements(app: Control, onglet: String = "") -> Callable:
	return func():
		if not onglet.is_empty():
			if not app.management_ui.get("competition") is Dictionary: app.management_ui.competition = {}
			app.management_ui.competition.tab = onglet
		app._navigate("Classements")

static func _aller_archives(app: Control) -> Callable:
	return func():
		app._navigate("Classements")
		var lien := app.find_child("OpenArchives", true, false) as Button
		if lien != null: lien.pressed.emit()

## Destination d'une rencontre : la feuille du match si elle est encore publiée, sinon la fiche de l'adversaire.
static func _cible_match(app: Control, match: Dictionary, club_id: Variant) -> Dictionary:
	var cible := Analyse._match_target(app, match, club_id)
	if cible.is_empty() and EntityLink.available(app, "club", match.get("opponent")): cible = EntityLink.target("club", match.get("opponent"))
	return cible

# --- Petits composants ------------------------------------------------------------------------------

static func _titre(texte: String, bulle: String = "") -> HBoxContainer:
	var ligne := C.h(10)
	ligne.add_child(C.label(texte, 27, Charte.IVOIRE, true, 700))
	if not bulle.is_empty():
		var info := Pastilles.info(bulle, "i")
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(info)
	return ligne

static func _carte(fond: Color = Charte.PANNEAU_2, marge: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", C.box(fond, Color.TRANSPARENT, Charte.RAYON_CARTE, marge))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Contenu cliquable : un MarginContainer porte le contenu et, par-dessus, un bouton plat de même taille (survol, focus).
## Le bouton est rangé dans la méta « bouton » du conteneur rendu.
static func _cliquable(contenu: Control, action: Callable, nom: String, bulle: String) -> MarginContainer:
	var boite := MarginContainer.new()
	boite.name = nom
	for bord in ["left", "right", "top", "bottom"]: boite.add_theme_constant_override("margin_" + bord, 0)
	boite.add_child(contenu)
	Pastilles._ignorer(contenu)
	var b := Button.new()
	b.name = "Bouton"
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = bulle
	var vide := StyleBoxFlat.new()
	vide.bg_color = Color.TRANSPARENT
	vide.set_corner_radius_all(C.px(Charte.RAYON_CARTE))
	var survol := vide.duplicate() as StyleBoxFlat
	survol.bg_color = Color(Charte.IVOIRE, .08)
	var focus := vide.duplicate() as StyleBoxFlat
	focus.set_border_width_all(2)
	focus.border_color = Charte.IVOIRE
	for etat in ["normal", "disabled"]: b.add_theme_stylebox_override(etat, vide)
	for etat in ["hover", "pressed"]: b.add_theme_stylebox_override(etat, survol)
	b.add_theme_stylebox_override("focus", focus)
	b.pressed.connect(action)
	boite.add_child(b)
	boite.set_meta("bouton", b)
	return boite

static func _lien_entite(app: Control, contenu: Control, cible: Dictionary, nom: String, bulle: String) -> Control:
	if cible.is_empty(): return contenu
	var b := _cliquable(contenu, func(): pass, nom, bulle)
	EntityLink.bind(b.get_meta("bouton"), app, cible, bulle)
	return b

## Anneau de pourcentage : arc coloré, gros chiffre au centre.
class Anneau extends Control:
	var valeur := 0.0
	var couleur := Color.WHITE
	var texte := ""
	func _draw() -> void:
		var e := size.x * 0.11
		var centre := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - e / 2.0
		draw_arc(centre, r, 0.0, TAU, 80, Charte.PANNEAU_3, e, true)
		if valeur > 0.0: draw_arc(centre, r, -PI / 2.0, -PI / 2.0 + TAU * clampf(valeur / 100.0, 0.0, 1.0), 80, couleur, e, true)
		var police: Font = C.EXTRA_BOLD
		var t := int(size.x * 0.3)
		var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, t).x
		draw_string(police, centre + Vector2(-largeur / 2.0, t * 0.36), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, t, Charte.IVOIRE)

static func _anneau(valeur: float, couleur: Color, texte: String, cote: float) -> Anneau:
	var a := Anneau.new()
	a.valeur = valeur
	a.couleur = couleur
	a.texte = texte
	a.custom_minimum_size = Vector2(C.px(cote), C.px(cote))
	a.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return a

## Barre horizontale : rail sombre, remplissage coloré (valeur sur 100).
class Barre extends Control:
	var valeur := 0.0
	var couleur := Color.WHITE
	func _draw() -> void:
		var r := size.y / 2.0
		draw_rect(Rect2(Vector2.ZERO, size), Charte.PANNEAU_3)
		var w := size.x * clampf(valeur / 100.0, 0.0, 1.0)
		if w > 0.0: draw_rect(Rect2(0, 0, w, size.y), couleur)

static func _barre(valeur: float, couleur: Color, hauteur: float = 14.0) -> Barre:
	var b := Barre.new()
	b.valeur = valeur
	b.couleur = couleur
	b.custom_minimum_size = Vector2(C.px(120), C.px(hauteur))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

## Pastille carrée de résultat (V, N, D) : lettre dans la couleur, voile de la couleur.
static func _lettre(issue: String, cote: float = 40.0) -> PanelContainer:
	var lettre := issue.to_upper().left(1)
	var couleur := _couleur_issue(lettre)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", C.box(Color(couleur, .2), couleur, Charte.RAYON_PETIT, 2))
	p.custom_minimum_size = Vector2(C.px(cote), C.px(cote))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := C.label(lettre, cote * 0.62, couleur, true, 800)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

static func _ecusson(app: Control, club_id: Variant, largeur: int) -> Control:
	var club: Dictionary = app.model.get("club", {}) if str(club_id) == str(app.model.get("club", {}).get("id", "")) else Competition._target_club(app, str(club_id))
	var e := G.crest(club, C.px(largeur))
	e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return e

# --- Option A : tuiles et anneaux -------------------------------------------------------------------

static func _option_a(app: Control, racine: VBoxContainer, years: Array) -> void:
	var data := _analyse(app)
	var resume: Dictionary = data.get("summary", {})
	var joues := int(resume.get("played", 0))
	racine.add_child(_titre("LES CINQ DERNIERS MATCHS", "Résultats et statistiques collectives du club."))
	if not bool(data.get("available", false)) or joues == 0:
		racine.add_child(Pastilles.pastille("Aucun match joué", Charte.IVOIRE_2, "clock", "", 20, "ClubHistoryNoMatchA"))
	else:
		var tuiles := C.h(14)
		racine.add_child(tuiles)
		# Bilan V / N / D : trois chiffres colorés avec leur lettre.
		var bilan := _carte()
		var col := C.v(6)
		bilan.add_child(col)
		var vnd := C.h(14)
		for t: Array in [["V", int(resume.get("won", 0))], ["N", int(resume.get("drawn", 0))], ["D", int(resume.get("lost", 0))]]:
			var bloc := C.h(6)
			bloc.add_child(_lettre(t[0], 34))
			bloc.add_child(C.label(str(t[1]), 46, _couleur_issue(t[0]) if int(t[1]) > 0 else Charte.IVOIRE_2, true, 800))
			vnd.add_child(bloc)
		col.add_child(vnd)
		col.add_child(C.label("BILAN · %d MATCH%s" % [joues, "S" if joues > 1 else ""], 17, Charte.IVOIRE_2, true, 600))
		tuiles.add_child(_cliquable(bilan, _aller_classements(app), "ClubHistoryBilan", "Bilan"))
		# Points marqués / encaissés.
		var points := _carte()
		var pcol := C.v(6)
		points.add_child(pcol)
		var prow := C.h(10)
		prow.add_child(C.label(str(int(resume.get("pointsFor", 0))), 46, POUR, true, 800))
		prow.add_child(C.label("/", 34, Charte.IVOIRE_3, true, 600))
		prow.add_child(C.label(str(int(resume.get("pointsAgainst", 0))), 46, CONTRE, true, 800))
		pcol.add_child(prow)
		pcol.add_child(C.label("POINTS POUR / CONTRE", 17, Charte.IVOIRE_2, true, 600))
		tuiles.add_child(_cliquable(points, _aller_classements(app, "stats"), "ClubHistoryPoints", "Points marqués / encaissés"))
		# Anneaux Touche, Mêlée.
		for m: Array in [["lineouts", "TOUCHE", TOUCHE], ["scrums", "MÊLÉE", MELEE]]:
			var mesure: Dictionary = data.get("metrics", {}).get(m[0], {})
			var taux := _taux(mesure)
			var carte := _carte()
			var acol := C.v(4)
			carte.add_child(acol)
			acol.add_child(_anneau(maxf(taux, 0.0), m[2], "—" if taux < 0 else "%d %%" % roundi(taux), 112))
			var leg := C.label("%s · %d / %d" % [m[1], int(mesure.get("won", 0)), int(mesure.get("attempts", 0))], 17, Charte.IVOIRE_2, true, 600)
			leg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			acol.add_child(leg)
			tuiles.add_child(_cliquable(carte, _aller_classements(app, "stats"), "ClubHistoryRing_" + str(m[0]), str(m[1]).capitalize()))
		# Discipline.
		var pen: Dictionary = data.get("metrics", {}).get("penalties", {})
		var disc := _carte(Charte.PANNEAU_2.lerp(DISCIPLINE, .1))
		var dcol := C.v(6)
		disc.add_child(dcol)
		var drow := C.h(10)
		drow.add_child(C.icon("flag-solid", 34, DISCIPLINE))
		drow.add_child(C.label(str(int(pen.get("total", 0))), 46, DISCIPLINE, true, 800))
		if pen.get("average") != null: drow.add_child(C.label("%s / match" % Analyse._decimal(float(pen.average)), 22, Charte.IVOIRE_2, true, 600))
		dcol.add_child(drow)
		dcol.add_child(C.label("PÉNALITÉS CONCÉDÉES", 17, Charte.IVOIRE_2, true, 600))
		tuiles.add_child(_cliquable(disc, _aller_classements(app, "stats"), "ClubHistoryDiscipline", "Discipline"))
		for enfant in tuiles.get_children(): (enfant as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Plaques de score des derniers matchs.
		var plaques := C.h(14)
		racine.add_child(plaques)
		for match: Dictionary in data.get("matches", []):
			plaques.add_child(_plaque(app, match, data.get("clubId")))
	racine.add_child(C.rule())
	_palmares_a(app, racine, years)

static func _plaque(app: Control, match: Dictionary, club_id: Variant) -> Control:
	var carte := _carte(Charte.PANNEAU_2, 12)
	var col := C.v(6)
	carte.add_child(col)
	var haut := C.h(10)
	var domicile := bool(match.get("home", false))
	var nous := int(match.get("pointsFor", 0))
	var eux := int(match.get("pointsAgainst", 0))
	var gauche := [club_id, nous] if domicile else [match.get("opponent"), eux]
	var droite := [match.get("opponent"), eux] if domicile else [club_id, nous]
	haut.add_child(_ecusson(app, gauche[0], 54))
	var score := C.label("%d – %d" % [int(gauche[1]), int(droite[1])], 40, Charte.IVOIRE, true, 800)
	score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	haut.add_child(score)
	haut.add_child(_ecusson(app, droite[0], 54))
	haut.add_child(_lettre(str(match.get("outcome", "")), 40))
	col.add_child(haut)
	var lieu := "Domicile" if domicile else "Extérieur"
	if match.get("neutral") != null and bool(match.neutral): lieu = "Terrain neutre"
	var journee := ""
	if match.get("competitionRound") != null: journee = "J%d · " % (int(match.competitionRound) + 1)
	elif match.get("round") != null: journee = "J%d · " % (int(match.round) + 1)
	col.add_child(C.label("%s%s · %s" % [journee, lieu, str(match.get("opponentName", ""))], 18, Charte.IVOIRE_2, true, 600))
	var cible := _cible_match(app, match, club_id)
	return _lien_entite(app, carte, cible, "ClubHistoryScore_" + str(match.get("fixtureId", "")).validate_node_name(), "%d – %d" % [nous, eux])

static func _palmares_a(app: Control, racine: VBoxContainer, _years: Array) -> void:
	var palmares: Dictionary = app.model.get("club", {}).get("palmares", {})
	racine.add_child(_titre("LE PALMARÈS", "Les rangs concernent la phase régulière."))
	if palmares.is_empty() or bool(palmares.get("vide", false)):
		racine.add_child(Pastilles.pastille("Aucun titre", Pastilles.BLEU, "trophy", "", 22, "ClubPalmaresVide", _aller_archives(app)))
		return
	var rangee := C.h(14)
	racine.add_child(rangee)
	# Grande tuile trophée : le total des titres.
	var total := int(palmares.get("totalTitles", 0))
	var grande := _carte(Charte.PANNEAU_2.lerp(Charte.V, .12), 16)
	var gl := C.h(14)
	grande.add_child(gl)
	gl.add_child(C.icon("trophy", 64, Charte.V))
	var gcol := C.v(0)
	gcol.add_child(C.label(str(total), 58, Charte.V, true, 800))
	gcol.add_child(C.label("TITRE%s" % ("S" if total > 1 else ""), 18, Charte.IVOIRE_2, true, 600))
	gl.add_child(gcol)
	rangee.add_child(_cliquable(grande, _aller_archives(app), "ClubPalmaresTotal", "%d titre%s" % [total, "s" if total > 1 else ""]))
	# Une tuile par compétition gagnée.
	for titre: Dictionary in palmares.get("titles", []):
		var nombre := int(titre.get("count", 0))
		var carte := _carte(Charte.PANNEAU_2, 14)
		var col := C.v(4)
		carte.add_child(col)
		var l := C.h(8)
		l.add_child(C.icon("trophy", 30, Charte.V))
		l.add_child(C.label("× %d" % nombre, 30, Charte.V, true, 800))
		col.add_child(l)
		col.add_child(C.label(Palmares.competition(app.model, str(titre.get("competition", ""))), 19, Charte.IVOIRE, true, 600))
		rangee.add_child(_cliquable(carte, _aller_archives(app), "ClubPalmaresTitle_" + str(titre.get("competition", "")).validate_node_name(), "Palmarès"))
	# Saisons récentes : une tuile par saison, rang ou titre en gros.
	for ligne: Dictionary in palmares.get("recent", []).slice(0, 4):
		var champion := str(ligne.get("text", "")).to_lower().begins_with("champion")
		var carte := _carte(Charte.PANNEAU_2.lerp(Charte.V, .1) if champion else Charte.PANNEAU_2, 14)
		var col := C.v(2)
		carte.add_child(col)
		col.add_child(C.label(str(ligne.get("season", "")), 19, Charte.IVOIRE_2, true, 600))
		var issue := C.h(8)
		if champion: issue.add_child(C.icon("trophy", 28, Charte.V))
		issue.add_child(C.label(str(ligne.get("text", "")), 30, Charte.V if champion else Charte.IVOIRE, true, 800))
		col.add_child(issue)
		col.add_child(C.label(Palmares.competition(app.model, str(ligne.get("competition", ""))), 16, Charte.IVOIRE_3, true, 600))
		rangee.add_child(_cliquable(carte, _aller_archives(app), "ClubPalmaresSeason_" + str(ligne.get("season", "")).validate_node_name(), str(ligne.get("season", ""))))

# --- Option B : frise des saisons + barres -----------------------------------------------------------

static func _option_b(app: Control, racine: VBoxContainer, years: Array) -> void:
	var rangee := C.h(28)
	racine.add_child(rangee)
	rangee.add_child(_frise(app, years))
	var droite := C.v(18)
	C.fill(droite)
	droite.size_flags_stretch_ratio = 1.25
	rangee.add_child(droite)
	_barres(app, droite)

## Frise verticale : du plus ancien au présent, posée sur la photo du trophée voilée.
static func _frise(app: Control, years: Array) -> Control:
	var cadre := PanelContainer.new()
	cadre.add_theme_stylebox_override("panel", C.box(Charte.PANNEAU, Color.TRANSPARENT, Charte.RAYON_CARTE, 0))
	cadre.clip_contents = true
	C.fill(cadre)
	var fond := Control.new()
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(fond)
	var photo := C.photo("ceremonie-remise-trophee" if C.BanqueImages.existe("ceremonie-remise-trophee") else "club-forest")
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo.modulate = Color(1, 1, 1, .32)
	fond.add_child(photo)
	var voile := C.veil(fond, true)
	voile.modulate = Color(1, 1, 1, .85)
	var marge := C.margin(26)
	cadre.add_child(marge)
	var col := C.v(0)
	marge.add_child(col)
	col.add_child(_titre("LA FRISE DU CLUB", "Les rangs concernent la phase régulière."))
	var espace := Control.new()
	espace.custom_minimum_size.y = C.px(14)
	col.add_child(espace)
	var palmares: Dictionary = app.model.get("club", {}).get("palmares", {})
	var etapes: Array = []
	var recentes: Array = palmares.get("recent", []).duplicate()
	recentes.reverse()
	for ligne: Dictionary in recentes:
		var champion := str(ligne.get("text", "")).to_lower().begins_with("champion")
		etapes.append({"saison": str(ligne.get("season", "")), "mot": str(ligne.get("text", "")), "comp": Palmares.competition(app.model, str(ligne.get("competition", ""))), "couleur": Charte.V if champion else Charte.IVOIRE, "icone": "trophy" if champion else "flag"})
	for year: Dictionary in years:
		var titre: bool = not year.get("titles", []).is_empty()
		etapes.append({"saison": G.season_label(year.season), "mot": "Champion" if titre else ("%se" % G.n(year.rank) if year.rank != null else "—"), "comp": "", "couleur": Charte.V if titre else Charte.IVOIRE, "icone": "trophy" if titre else "flag"})
	var club: Dictionary = app.model.get("club", {})
	var meta: Dictionary = app.model.get("meta", {})
	var rang: Variant = club.get("rank", club.get("position", null))
	etapes.append({"saison": G.season_label(meta.get("season", "")), "mot": "En cours" + (" · %se" % G.n(rang) if rang != null else ""), "comp": "", "couleur": Charte.REPOS, "icone": "clock", "present": true})
	for i in etapes.size():
		col.add_child(_etape(app, etapes[i], i == etapes.size() - 1))
	return cadre

class Fil extends Control:
	var couleur := Color.WHITE
	var dernier := false
	func _draw() -> void:
		var x := size.x / 2.0
		var r := size.x * 0.32
		if not dernier: draw_rect(Rect2(x - 2, r * 2.0, 4, size.y - r * 2.0), Charte.FILET.lightened(.25))
		draw_circle(Vector2(x, r + 4), r, Color(couleur, .25))
		draw_arc(Vector2(x, r + 4), r, 0, TAU, 40, couleur, 3, true)

static func _etape(app: Control, etape: Dictionary, dernier: bool) -> Control:
	var ligne := C.h(16)
	var fil := Fil.new()
	fil.couleur = etape.couleur
	fil.dernier = dernier
	fil.custom_minimum_size = Vector2(C.px(56), C.px(118 if not dernier else 72))
	fil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pile := Control.new()
	pile.custom_minimum_size = fil.custom_minimum_size
	pile.add_child(fil)
	fil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var picto := C.icon(str(etape.icone), 24, etape.couleur)
	picto.position = Vector2(C.px(28) - C.px(12), C.px(4) + C.px(18) - C.px(12))
	pile.add_child(picto)
	ligne.add_child(pile)
	var col := C.v(0)
	col.add_child(C.label(str(etape.saison), 22, Charte.IVOIRE_2, true, 600))
	col.add_child(C.label(str(etape.mot), 38, etape.couleur, true, 800))
	if not str(etape.comp).is_empty(): col.add_child(C.label(str(etape.comp), 18, Charte.IVOIRE_3, true, 600))
	ligne.add_child(col)
	var action := _aller_classements(app) if bool(etape.get("present", false)) else _aller_archives(app)
	return _cliquable(ligne, action, "ClubHistoryStep_" + str(etape.saison).validate_node_name(), str(etape.saison))

static func _ligne_barre(icone: String, mot: String, valeur: float, couleur: Color, chiffre: String, detail: String) -> HBoxContainer:
	var l := C.h(12)
	l.add_child(C.icon(icone, 26, couleur))
	var m := C.label(mot, 22, Charte.IVOIRE, true, 700)
	m.custom_minimum_size.x = C.px(150)
	l.add_child(m)
	l.add_child(_barre(valeur, couleur, 16))
	var c := C.label(chiffre, 30, couleur, true, 800)
	c.custom_minimum_size.x = C.px(92)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_child(c)
	var d := C.label(detail, 18, Charte.IVOIRE_2, true, 600)
	d.custom_minimum_size.x = C.px(90)
	l.add_child(d)
	return l

static func _barres(app: Control, droite: VBoxContainer) -> void:
	var data := _analyse(app)
	var resume: Dictionary = data.get("summary", {})
	var joues := int(resume.get("played", 0))
	droite.add_child(_titre("LES CINQ DERNIERS MATCHS", "Résultats et statistiques collectives du club."))
	if not bool(data.get("available", false)) or joues == 0:
		droite.add_child(Pastilles.pastille("Aucun match joué", Charte.IVOIRE_2, "clock", "", 20, "ClubHistoryNoMatchB"))
		return
	# Bilan en barre empilée V / N / D.
	var bilan := C.h(12)
	var v := int(resume.get("won", 0))
	var n := int(resume.get("drawn", 0))
	var d := int(resume.get("lost", 0))
	var pile := C.h(3)
	C.fill(pile)
	for t: Array in [["V", v], ["N", n], ["D", d]]:
		if int(t[1]) <= 0: continue
		var seg := _carte(Color(_couleur_issue(t[0]), .85), 4)
		seg.custom_minimum_size.y = C.px(44)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.size_flags_stretch_ratio = float(t[1])
		var lab := C.label("%d %s" % [int(t[1]), t[0]], 24, Charte.ENCRE, true, 800)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		seg.add_child(lab)
		pile.add_child(seg)
	bilan.add_child(pile)
	droite.add_child(_cliquable(bilan, _aller_classements(app), "ClubHistoryBilanB", "%d V · %d N · %d D" % [v, n, d]))
	var pour := int(resume.get("pointsFor", 0))
	var contre := int(resume.get("pointsAgainst", 0))
	var maxi_points := float(maxi(1, maxi(pour, contre)))
	var lignes := C.v(14)
	lignes.add_child(_ligne_barre("target", "Marqués", pour / maxi_points * 100.0, POUR, str(pour), "points"))
	lignes.add_child(_ligne_barre("shield", "Encaissés", contre / maxi_points * 100.0, CONTRE, str(contre), "points"))
	for m: Array in [["lineouts", "Touche", TOUCHE, "people"], ["scrums", "Mêlée", MELEE, "people"]]:
		var mesure: Dictionary = data.get("metrics", {}).get(m[0], {})
		var taux := _taux(mesure)
		lignes.add_child(_ligne_barre(m[3], m[1], maxf(taux, 0.0), m[2], "—" if taux < 0 else "%d %%" % roundi(taux), "%d / %d" % [int(mesure.get("won", 0)), int(mesure.get("attempts", 0))]))
	var pen: Dictionary = data.get("metrics", {}).get("penalties", {})
	var moyenne := float(pen.average) if pen.get("average") != null else 0.0
	lignes.add_child(_ligne_barre("flag-solid", "Pénalités", minf(moyenne / 15.0 * 100.0, 100.0), DISCIPLINE, str(int(pen.get("total", 0))), "%s / match" % Analyse._decimal(moyenne)))
	droite.add_child(_cliquable(lignes, _aller_classements(app, "stats"), "ClubHistoryBars", "Statistiques"))
	droite.add_child(C.rule())
	# Derniers matchs en lignes courtes : lettre, score, adversaire.
	for match: Dictionary in data.get("matches", []):
		var l := C.h(14)
		l.add_child(_lettre(str(match.get("outcome", "")), 40))
		l.add_child(C.label("%d – %d" % [int(match.get("pointsFor", 0)), int(match.get("pointsAgainst", 0))], 34, Charte.IVOIRE, true, 800))
		l.add_child(_ecusson(app, match.get("opponent"), 40))
		var adv := C.label(str(match.get("opponentName", "")), 24, Charte.IVOIRE_2, true, 600)
		adv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.add_child(adv)
		var tuile := _carte(Charte.PANNEAU_2, 10)
		tuile.add_child(l)
		droite.add_child(_lien_entite(app, tuile, _cible_match(app, match, data.get("clubId")), "ClubHistoryMatchB_" + str(match.get("fixtureId", "")).validate_node_name(), str(match.get("opponentName", ""))))
