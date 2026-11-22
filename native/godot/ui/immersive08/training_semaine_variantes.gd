extends RefCounted
## Plan d'entraînement › Semaine, variantes « façon Effectif » (planche A/B du 22/11/2026 ; rien d'intégré, Léo choisit).
## CD_VARIANTE_VISUELLE=A : tuiles-chiffres compactes dans l'en-tête (gabarit de l'Effectif), puis les sept volets en
##   sept LIGNES d'un tableau (volet | préparer + état | repères | suivre + état | repères), survol de ligne, rayures.
## CD_VARIANTE_VISUELLE=B : bandeau de cinq tuiles-chiffres colorées sous les onglets, programme des jours dans l'en-tête,
##   le même tableau dessous.
## Chaque case garde la destination de la carte qu'elle remplace (`_select` → Séance sélectionnée, puis son action) ;
## les repères (crans, portraits, blasons, cases) sont ceux des cartes actuelles (`_card_visual`) avec leurs liens.
## Coordonnées en unités du gabarit (toile 2248 × 1230). `page` : la toile de l'entraînement (training_canvas.gd).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")
const SurvolLigne = preload("res://ui/survol_ligne.gd")

## Volet : [titre, icône, couleur franche (palette commune)].
const VOLETS := [
	["Collectif", "train", Charte.GAIN],
	["Groupes", "people", Charte.MORAL],
	["Individuel", "star", Charte.CONFIANCE],
	["Vigilance", "heart", Charte.INTENSIF],
	["Consignes", "tactic", Charte.REPOS],
	["Match", "ball", Charte.PERTE],
	["Encadrement", "info", Charte.IVOIRE_2],
]
const LARGEUR := 1740.0
const X_VOLET := 236.0
const MOITIE := 748.0
const NOM_MARQUE := "TrainingWeekPick"

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

# --- En-tête --------------------------------------------------------------------------------------------------------

## Les quatre chiffres de l'en-tête actuel : [id, légende, valeur, suffixe, couleur, icône].
static func _chiffres(page: Control, meta: Dictionary) -> Array:
	var group := P.group(page.app.model)
	var total := 0.0
	for p: Dictionary in page.squad: total += float(p.get("physicalLoad", 0))
	var charge := roundi(total / maxi(1, page.squad.size()))
	var surveiller: int = page.watched.size()
	return [
		["Condition", "CONDITION", G.n(group.condition), "%", Charte.CONDITION, "heart"],
		["Moral", "MORAL", G.n(meta.get("morale", "—")), "/ 100", Charte.MORAL, "people"],
		["Charge", "CHARGE MOYENNE", str(charge), "/ 100", Charte.INTENSIF if charge >= 55 else Charte.NORMAL, "train"],
		["Surveiller", "À SURVEILLER", str(surveiller), "joueurs" if surveiller > 1 else "joueur", Charte.PERTE if surveiller > 0 else Charte.IVOIRE_3, "warning"],
	]

## A : tuiles compactes à droite du titre (gabarit de l'Effectif) ; B : rien ici (bandeau sous les onglets) et le
## programme des jours remonte dans l'en-tête.
static func entete(page: Control, meta: Dictionary) -> void:
	if page.variante == "B": return
	var chiffres := _chiffres(page, meta)
	var x := 1743.0
	for i in range(chiffres.size() - 1, -1, -1):
		x -= 218.0
		_tuile(page, Rect2(x, 26, 218, 92), chiffres[i], i, false)
		x -= 12.0

## Tuile-chiffre cliquable (même destination que les tuiles actuelles : moral → Vestiaire, le reste → Fatigue).
## `grande` : tuile du bandeau B (icône, fond teinté de la couleur de la donnée).
static func _tuile(page: Control, zone: Rect2, t: Array, i: int, grande: bool) -> Button:
	var tuile := Button.new()
	tuile.name = "TrainingMetric" + str(i)
	tuile.focus_mode = Control.FOCUS_ALL
	tuile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tuile.accessibility_name = "%s %s %s" % [t[1], t[2], t[3]]
	tuile.tooltip_text = ["Condition de l'effectif : ouvrir la fatigue", "Moral : ouvrir le vestiaire", "Charge moyenne : ouvrir la fatigue", "Joueurs à surveiller : ouvrir la fatigue", "Séance collective"][i]
	var fond: Color = Charte.PANNEAU.lerp(t[4], .14) if grande else Charte.PANNEAU
	tuile.add_theme_stylebox_override("normal", _plat(fond, 16))
	tuile.add_theme_stylebox_override("hover", _plat(fond.lerp(Charte.IVOIRE, .06), 16))
	tuile.add_theme_stylebox_override("pressed", _plat(fond.lerp(Charte.IVOIRE, .10), 16))
	var focus := _plat(Color.TRANSPARENT, 16)
	focus.border_color = Charte.IVOIRE
	focus.set_border_width_all(2)
	tuile.add_theme_stylebox_override("focus", focus)
	page.add_child(tuile)
	D.place(tuile, zone)
	load("res://ui/retour_tuile.gd").brancher(tuile, tuile, C.px(16))
	var gauche := 18.0
	if grande:
		var icone := C.icon(str(t[5]), 40, t[4])
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tuile.add_child(icone)
		D.place(icone, Rect2(22, (zone.size.y - 40) / 2.0, 40, 40))
		gauche = 82.0
	var legende := D.text(tuile, gauche, 30, t[1], 17, Charte.IVOIRE_2, 700, zone.size.x - gauche - 12)
	legende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var taille := 52 if grande else 46
	var base := zone.size.y - 16
	var valeur := D.text(tuile, gauche, base, t[2], taille, t[4], 800, zone.size.x - gauche - 12)
	valeur.add_theme_font_override("font", Charte.TITRE_EXTRA)
	valeur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	valeur.name = "TrainingMetricValue"
	if not str(t[3]).is_empty():
		var l: float = Charte.TITRE_EXTRA.get_string_size(str(t[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille))).x / C.density
		var suffixe := D.text(tuile, gauche + l + 10, base - 4, t[3], 18, Charte.IVOIRE_2, 500, zone.size.x - gauche - l - 22, HORIZONTAL_ALIGNMENT_LEFT, true)
		suffixe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if i < 4: tuile.pressed.connect(func(): page._open_metric(i))
	else: tuile.pressed.connect(func(): page._select(0))
	if i < 2: preload("res://ui/mini_courbe_survol.gd").lier(page.app, tuile, ["condition", "morale"][i], ["Condition du groupe", "Moral du vestiaire"][i])
	return tuile

static func _plat(fond: Color, rayon: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.set_corner_radius_all(maxi(3, C.px(rayon)))
	s.anti_aliasing = true
	return s

## B : cinq tuiles colorées sur toute la largeur (les quatre chiffres + la charge de la séance collective).
static func _bandeau(page: Control, y: float, h: float) -> void:
	var meta: Dictionary = page.app.model.get("meta", {})
	var chiffres := _chiffres(page, meta)
	var mode := str(page.state.get("mode", page.state.get("stored_mode", "normal")))
	var seance: Array = [["repos", "Repos", Charte.REPOS, "heart"], ["normal", "Normale", Charte.NORMAL, "train"], ["intense", "Intensive", Charte.INTENSIF, "train"]].filter(func(m: Array): return m[0] == mode)
	if seance.is_empty(): seance = [["normal", "Normale", Charte.NORMAL, "train"]]
	chiffres.append(["Seance", "SÉANCE", seance[0][1], "faite" if page.trained else "", seance[0][2], seance[0][3]])
	var ecart := 14.0
	var w := (LARGEUR - ecart * (chiffres.size() - 1)) / chiffres.size()
	for i in chiffres.size():
		_tuile(page, Rect2(4 + i * (w + ecart), y, w, h), chiffres[i], i, true)

# --- Onglet Semaine -------------------------------------------------------------------------------------------------

static func semaine(page: Control, fixture: Dictionary) -> void:
	page.teinte_date = Charte.IVOIRE
	var selected := clampi(int(page.state.get("slot", 0)), 0, _slots(page).size() - 1)
	if page.variante == "B":
		page._programme(Vector2(1015, 104))
		_bandeau(page, 242, 96)
		_tableau(page, Rect2(4, 352, LARGEUR, 522), 66.0, fixture, selected)
	else:
		page._programme()
		_tableau(page, Rect2(4, 278, LARGEUR, 546), 70.0, fixture, selected)
	# B : le tableau descend sous le bandeau, la rangée du bas se resserre (mêmes panneaux, trois lignes chacun).
	var y_bas := 884.0 if page.variante == "B" else 840.0
	var h_bas := 1217.0 - y_bas
	page._chart()
	page._vigilance()
	_lignes_survol(page.get_node_or_null("TrainingRisk"), "TrainingRisk_")
	page.week_panel = D.panel(page, Rect2(1760, 509, 488, 306), "Séance sélectionnée", "train", "", "TrainingSelectedSession")
	page._selection(selected)
	var art := D.panel(page, Rect2(4, y_bas, 1020, h_bas), "", "", "", "TrainingPhoto")
	art.clip_contents = true
	D.photo(art, page.photo_centre(page.app.model), Rect2(2, 2, 1016, h_bas - 4))
	var axes := D.panel(page, Rect2(1039, y_bas, 560, minf(341.0, h_bas)), "Axes individuels", "star", "", "TrainingAxes")
	page._axes(axes)
	_lignes_survol(axes, "TrainingAxis")
	page._staff_cards(D.panel(page, Rect2(1614, y_bas, 634, minf(341.0, h_bas)), "Encadrement", "people", "", "TrainingStaff"))

## Lignes-boutons déjà posées (vigilance, axes) : survol commun (bande claire + liseré club) et rayure une sur deux.
static func _lignes_survol(parent: Node, prefixe: String) -> void:
	if parent == null: return
	for enfant in parent.get_children():
		if enfant is Button and str(enfant.name).begins_with(prefixe) and not str(enfant.name).contains("Player"):
			SurvolLigne.appliquer(enfant, false, Color.TRANSPARENT, Color.TRANSPARENT)

## Tableau des sept volets : une ligne par volet, deux cases (préparer, suivre) par ligne.
static func _tableau(page: Control, zone: Rect2, h: float, fixture: Dictionary, selected: int) -> void:
	var panneau := D.panel(page, zone, "", "", "", "TrainingWeekTable")
	var entete := Panel.new()
	entete.name = "TrainingWeekHeader"
	entete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Bandeau.peindre_entete(entete)
	panneau.add_child(entete)
	D.place(entete, Rect2(0, 0, zone.size.x, 44))
	for col: Array in [["VOLET", 24.0], ["PRÉPARER", X_VOLET + 12], ["ÉTAT", X_VOLET + 268], ["SUIVRE", X_VOLET + MOITIE + 12], ["ÉTAT", X_VOLET + MOITIE + 268]]:
		D.text(entete, col[1], 29, col[0], 17, Charte.IVOIRE_3, 700, 200).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lignes := Control.new()
	lignes.name = "TrainingWeekRows"
	lignes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panneau.add_child(lignes)
	D.place(lignes, Rect2(8, 50, zone.size.x - 16, h * VOLETS.size()))
	var captions: Array = page._captions(fixture)
	var marques: Array = []
	for i in VOLETS.size():
		var v: Array = VOLETS[i]
		var ligne := Control.new()
		ligne.name = "TrainingWeekRow%d" % i
		lignes.add_child(ligne)
		D.place(ligne, Rect2(0, i * h, zone.size.x - 16, h - 2))
		SurvolLigne.poser(ligne)
		D.line(ligne, Vector2(0, h - 2), Vector2(zone.size.x - 16, h - 2), Charte.FILET)
		D.rect(ligne, Rect2(10, (h - 2) / 2.0 - 16, 5, 32), v[2], 3).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icone := C.icon(str(v[1]), 28, v[2])
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(icone)
		D.place(icone, Rect2(26, (h - 2) / 2.0 - 14, 28, 28))
		var titre := D.text(ligne, 66, (h - 2) / 2.0 + 11, str(v[0]).to_upper(), 27, Charte.IVOIRE, 700, 166)
		titre.add_theme_font_override("font", Charte.TITRE_FICHE)
		titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in 2:
			marques.append(_case(page, ligne, i * 2 + k, X_VOLET + k * MOITIE, h - 2, str(captions[i * 2 + k]), fixture, i * 2 + k == selected))
	page.set_meta("variante_marques", marques)

## Une case du tableau : icône + nom de l'étape, état en pastille, repères de la carte actuelle. Clic = `_select`.
static func _case(page: Control, ligne: Control, index: int, x: float, h: float, caption: String, fixture: Dictionary, choisie: bool) -> Panel:
	var slot: Array = _slots(page)[index]
	var bouton := Button.new()
	bouton.name = "TrainingStep" + str(index)
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.accessibility_name = str(slot[1])
	bouton.tooltip_text = str(slot[3])
	bouton.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	for etat in ["hover", "pressed", "hover_pressed"]: bouton.add_theme_stylebox_override(etat, _plat(Color(Charte.IVOIRE, .05), Charte.RAYON_PETIT))
	bouton.add_theme_stylebox_override("focus", SurvolLigne.style_focus())
	ligne.add_child(bouton)
	D.place(bouton, Rect2(x, 3, MOITIE - 8, h - 6))
	bouton.pressed.connect(func(): page._select(index))
	# Case retenue (celle de « Séance sélectionnée ») : contour crème discret, jamais de vert.
	var marque := Panel.new()
	marque.name = NOM_MARQUE + str(index)
	marque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _plat(Color.TRANSPARENT, Charte.RAYON_PETIT)
	style.draw_center = false
	style.border_color = Color(Charte.IVOIRE, .5)
	style.set_border_width_all(maxi(1, C.px(2)))
	marque.add_theme_stylebox_override("panel", style)
	marque.visible = choisie
	ligne.add_child(marque)
	D.place(marque, Rect2(x, 3, MOITIE - 8, h - 6))
	var icone := C.icon(str(slot[0]), 26, Charte.IVOIRE_2)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(icone)
	D.place(icone, Rect2(x + 12, h / 2.0 - 13, 26, 26))
	D.text(ligne, x + 50, h / 2.0 + 8, str(slot[1]), 22, Charte.IVOIRE, 700, 210).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Compétition du prochain match trop longue pour la colonne : derniers mots retirés, comme la carte actuelle.
	if index == 11:
		var mots := caption.split(" ", false)
		while mots.size() > 2 and (Pieces.largeur_pastille(" ".join(mots), "calendar") > 262.0 or mots[mots.size() - 1] == "·"): mots.resize(mots.size() - 1)
		caption = " ".join(mots)
	if not caption.is_empty():
		var look := _etat(page, index, caption)
		var largeur := Pieces.largeur_pastille(caption, str(look[1]))
		if largeur > 262.0: look[1] = ""
		Pieces.pastille(ligne, x + 264, h / 2.0 - 17, caption, str(look[1]), "TrainingWeekState%d" % index, "", look[0])
	# Repères de la carte actuelle (y 108-166 dans la carte) recentrés sur la ligne.
	var reperes := Control.new()
	reperes.name = "TrainingWeekVisual%d" % index
	reperes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(reperes)
	# Crans (charge collective, niveau adverse) : plus hauts que les portraits, recentrés à part.
	D.place(reperes, Rect2(x + 518, h / 2.0 - (131.0 if index in [0, 9] else 137.0), 220, 180))
	page._card_visual(reperes, index, fixture)
	return marque

## Couleur et icône de la pastille d'état (couleur jamais seule : toujours le mot de l'état).
static func _etat(page: Control, index: int, caption: String) -> Array:
	match index:
		0: return [Charte.GAIN, "check"] if page.trained else [Charte.IVOIRE_2, "clock"]
		1: return [Charte.GAIN, "flag"]
		2: return [Charte.MORAL, "people"]
		3: return [Charte.IVOIRE_2, "people"]
		4: return [Charte.CONFIANCE if not caption.begins_with("0 ") else Charte.IVOIRE_2, "star"]
		5: return [Charte.INTENSIF if not caption.begins_with("0 ") else Charte.IVOIRE_2, "train"]
		6: return [Charte.INTENSIF if not caption.begins_with("0 ") else Charte.GAIN, "warning" if not caption.begins_with("0 ") else "check"]
		7: return [Charte.PERTE if not caption.begins_with("0 ") else Charte.GAIN, "heart"]
		10:
			var valide: bool = page.app.model.get("selection", {}).get("valid", false)
			return [Charte.GAIN, "check"] if valide else [Charte.PERTE, "warning"]
		11: return [Charte.IVOIRE, "calendar"]
	return [Charte.IVOIRE_2, ""]

## Après un clic : le contour suit la case retenue.
static func marquer(page: Control, index: int) -> void:
	var marques: Variant = page.get_meta("variante_marques", [])
	if not marques is Array: return
	for k in (marques as Array).size():
		var m: Variant = marques[k]
		if is_instance_valid(m): (m as Control).visible = k == index

static func _slots(page: Control) -> Array:
	return page.get_script().get_script_constant_map().get("SLOTS", [])
