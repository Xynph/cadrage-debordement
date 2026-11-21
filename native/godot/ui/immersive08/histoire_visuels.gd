extends RefCounted
## Club › Histoire (revue du 21/11/2026, n° 8, option B choisie par Léo) : frise verticale des saisons sur la photo du
## trophée voilée (titres, rangs, saison en cours) ; à côté, bilan en barre empilée, statistiques en barres colorées et
## derniers matchs en lignes courtes. Tout est cliquable : frise -> archives ou Classements, barres -> statistiques,
## score -> page de la rencontre, adversaire -> fiche du club.
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

static func build(app: Control, years: Array) -> Control:
	var racine := C.v(22)
	racine.name = "ClubHistoryVisual"
	C.fill(racine)
	var rangee := C.h(28)
	racine.add_child(rangee)
	rangee.add_child(_frise(app, years))
	var droite := C.v(18)
	C.fill(droite)
	droite.size_flags_stretch_ratio = 1.25
	rangee.add_child(droite)
	_barres(app, droite)
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

# --- Frise des saisons + barres ---------------------------------------------------------------------

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
		etapes.append({"saison": _saison_courte(G.season_label(year.season)), "mot": "Champion" if titre else ("%se" % G.n(year.rank) if year.rank != null else "—"), "comp": "", "couleur": Charte.V if titre else Charte.IVOIRE, "icone": "trophy" if titre else "flag"})
	var club: Dictionary = app.model.get("club", {})
	var meta: Dictionary = app.model.get("meta", {})
	var rang: Variant = club.get("rank", club.get("position", null))
	etapes.append({"saison": _saison_courte(G.season_label(meta.get("season", ""))), "mot": "En cours" + (" · %se" % G.n(rang) if rang != null else ""), "comp": "", "couleur": Charte.REPOS, "icone": "clock", "present": true})
	for i in etapes.size():
		col.add_child(_etape(app, etapes[i], i == etapes.size() - 1))
	return cadre

## « 2026-2027 » -> « 2026-27 », comme les saisons du palmarès, pour une frise homogène.
static func _saison_courte(saison: String) -> String:
	var parts := saison.split("-")
	return "%s-%s" % [parts[0], parts[1].right(2)] if parts.size() == 2 and parts[1].length() == 4 else saison

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
	# Derniers matchs en lignes courtes : lettre, score (lien vers la rencontre), écusson et nom (lien vers le club).
	# Mêmes noms de liens que l'ancienne analyse : PerformanceMatchScore_<rencontre>, PerformanceOpponent_<rencontre>.
	for match: Dictionary in data.get("matches", []):
		var l := C.h(14)
		l.add_child(_lettre(str(match.get("outcome", "")), 40))
		var fixture := str(match.get("fixtureId", "")) if match.get("fixtureId") is String else ""
		var cle := fixture if not fixture.is_empty() else "%s_%s_%s_%s" % [match.get("season",""),match.get("week",match.get("round","")),match.get("phase",""),match.get("opponent","")]
		var texte_score := "%d – %d" % [int(match.get("pointsFor", 0)), int(match.get("pointsAgainst", 0))]
		l.add_child(_lien_texte(app, texte_score, Analyse._match_target(app, match, data.get("clubId")), "PerformanceMatchScore_" + fixture.validate_node_name(), 34, Charte.IVOIRE, 800))
		l.add_child(_ecusson(app, match.get("opponent"), 40))
		var club_cible := EntityLink.target("club", match.get("opponent")) if EntityLink.available(app, "club", match.get("opponent")) else {}
		l.add_child(_lien_texte(app, str(match.get("opponentName", "")), club_cible, "PerformanceOpponent_" + cle.validate_node_name(), 24, Charte.IVOIRE_2, 600))
		var tuile := _carte(Charte.PANNEAU_2, 10)
		tuile.add_child(l)
		droite.add_child(tuile)

## Texte cliquable (bouton plat, soulignement au survol) relié à une entité ; simple étiquette si la cible est absente.
static func _lien_texte(app: Control, texte: String, cible: Dictionary, nom: String, taille: int, couleur: Color, graisse: int) -> Control:
	if cible.is_empty():
		var l := C.label(texte, taille, couleur, true, graisse)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return l
	var b := Button.new()
	b.name = nom
	b.text = texte
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", C.font(graisse))
	b.add_theme_font_size_override("font_size", C.font_px(taille))
	for cle in ["font_color", "font_focus_color", "font_pressed_color"]: b.add_theme_color_override(cle, couleur)
	b.add_theme_color_override("font_hover_color", Charte.IVOIRE)
	var vide := StyleBoxFlat.new()
	vide.bg_color = Color.TRANSPARENT
	vide.content_margin_left = C.px(4)
	vide.content_margin_right = C.px(4)
	var survol := vide.duplicate() as StyleBoxFlat
	survol.bg_color = Color(Charte.IVOIRE, .08)
	survol.set_corner_radius_all(C.px(Charte.RAYON_PETIT))
	var focus := survol.duplicate() as StyleBoxFlat
	focus.bg_color = Color.TRANSPARENT
	focus.set_border_width_all(2)
	focus.border_color = Charte.IVOIRE
	for etat in ["normal", "disabled"]: b.add_theme_stylebox_override(etat, vide)
	for etat in ["hover", "pressed"]: b.add_theme_stylebox_override(etat, survol)
	b.add_theme_stylebox_override("focus", focus)
	EntityLink.bind(b, app, cible, texte)
	return b
