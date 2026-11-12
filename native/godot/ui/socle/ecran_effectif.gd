extends Control
## Écran Effectif construit sur le socle des menus : tableau commun, jetons de
## design, conteneurs. Il lit `app.model.squad` tel que le moteur l'envoie et ne
## déclenche aucune commande pour trier, filtrer ou sélectionner.

const J = preload("res://ui/socle/jetons.gd")
const Tableau = preload("res://ui/socle/tableau.gd")
const G = preload("res://ui/game_skin.gd")
const U = preload("res://ui/management_state.gd")
const Salaire = preload("res://ui/salary_display.gd")

## Lignes de l'équipe, dans l'ordre du moteur (`fam`), et places sur le terrain.
const LIGNES := [
	{"nom": "Piliers", "un": "pilier", "places": 2},
	{"nom": "Talonneurs", "un": "talonneur", "places": 1},
	{"nom": "Deuxièmes lignes", "un": "deuxième ligne", "places": 2},
	{"nom": "Troisièmes lignes", "un": "troisième ligne", "places": 3},
	{"nom": "Demis de mêlée", "un": "demi de mêlée", "places": 1},
	{"nom": "Demis d’ouverture", "un": "demi d’ouverture", "places": 1},
	{"nom": "Ailiers", "un": "ailier", "places": 2},
	{"nom": "Centres", "un": "centre", "places": 2},
	{"nom": "Arrières", "un": "arrière", "places": 1},
]
const ORDRE_LIGNES := [0, 1, 2, 3, 4, 5, 7, 6, 8]
const VUES := ["Vue d’ensemble", "Condition", "Contrats", "Développement"]
const NIVEAU_MIN := 40.0
const NIVEAU_MAX := 100.0

var app: Control
var etat: Dictionary
var tableau: Control
var colonne_droite: VBoxContainer
var pied: Label
var boutons_vue: Array = []
var boutons_filtre: Dictionary = {}
var saison := 1

static func actif(owner_app: Control) -> bool:
	return OS.get_environment("CD_SOCLE_EFFECTIF") == "1" or bool(owner_app.get_meta("socle_effectif", false))

static func build(owner_app: Control) -> Control:
	var page: Control = load("res://ui/socle/ecran_effectif.gd").new()
	page.app = owner_app
	page._construire()
	return page

# ---------------------------------------------------------------- lecture des joueurs

func _joueurs() -> Array:
	return app.model.get("squad", [])

## Ordre de lecture par défaut : titulaires, remplaçants, puis le reste, du
## meilleur niveau au moins bon. Le tableau le conserve tant qu'aucune colonne
## n'est triée.
func _joueurs_ordonnes() -> Array:
	var rang := func(j: Dictionary) -> int:
		return 3 if _blesse(j) else {"Titulaire": 0, "Remplaçant": 1}.get(str(j.get("status", "")), 2)
	var liste: Array = _joueurs().duplicate()
	liste.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: int = rang.call(a)
		var rb: int = rang.call(b)
		if ra != rb: return ra < rb
		var na := float(a.rating) if _nombre(a.get("rating")) else -1.0
		var nb := float(b.rating) if _nombre(b.get("rating")) else -1.0
		if na != nb: return na > nb
		return str(a.get("id", "")) < str(b.get("id", "")))
	return liste

static func _nombre(valeur: Variant) -> bool:
	return (valeur is int or valeur is float) and is_finite(float(valeur))

static func _blesse(joueur: Dictionary) -> bool:
	return float(joueur.get("injury", 0)) > 0

static func _statut(joueur: Dictionary) -> String:
	if _blesse(joueur):
		var semaines := int(ceilf(float(joueur.injury)))
		return "Blessé, %d semaine%s" % [semaines, "s" if semaines > 1 else ""]
	return str(joueur.get("status", "Hors groupe"))

static func _precision_poste(joueur: Dictionary) -> String:
	var famille := int(joueur.get("fam", -1))
	var postes: Array = joueur.get("primaryPositions", [])
	if famille == 0:
		var gauche := postes.has(1) or postes.has(1.0)
		var droit := postes.has(3) or postes.has(3.0)
		return "gauche et droit" if gauche and droit else "gauche" if gauche else "droit" if droit else ""
	if famille == 3:
		var centre := postes.has(8) or postes.has(8.0)
		var aile := postes.has(6) or postes.has(6.0) or postes.has(7) or postes.has(7.0)
		return "aile et centre" if centre and aile else "centre" if centre else "aile" if aile else ""
	return ""

static func _potentiel(joueur: Dictionary) -> Dictionary:
	var fourchette: Variant = joueur.get("potentialRange")
	if fourchette is Dictionary and _nombre(fourchette.get("min")) and _nombre(fourchette.get("max")):
		return {"min": float(fourchette.min), "max": float(fourchette.max)}
	if _nombre(joueur.get("potential")):
		return {"min": float(joueur.potential), "max": float(joueur.potential)}
	return {}

static func _texte_potentiel(joueur: Dictionary) -> String:
	var p := _potentiel(joueur)
	if p.is_empty(): return "—"
	return str(int(p.min)) if p.min == p.max else "%d à %d" % [int(p.min), int(p.max)]

func _fin_cette_saison(joueur: Dictionary) -> bool:
	return _nombre(joueur.get("contractEnd")) and int(joueur.contractEnd) <= saison

func _texte_contrat(joueur: Dictionary) -> String:
	return "Cette saison" if _fin_cette_saison(joueur) else G.contract_year(joueur.get("contractEnd"))

static func _couleur_condition(valeur: float) -> Color:
	return J.VERT if valeur >= 90.0 else J.JAUNE if valeur >= 75.0 else J.ALERTE

# ---------------------------------------------------------------- cellules dessinées

func _dessin_numero(zone: Control, rect: Rect2, joueur: Dictionary) -> void:
	var numero: Variant = joueur.get("shirtNumber")
	if not _nombre(numero): return
	var rayon := float(J.px(13))
	var centre := Vector2(rect.position.x + rayon + 1, rect.position.y + rect.size.y / 2.0)
	var titulaire := str(joueur.get("status", "")) == "Titulaire"
	if titulaire:
		zone.draw_circle(centre, rayon, J.TEXTE, true, -1.0, true)
	else:
		zone.draw_circle(centre, rayon - 1, J.TEXTE, false, maxf(1.5, J.px(1.5)), true)
	var texte := str(int(numero))
	var taille := J.px(15)
	var largeur := J.TITRE_GRAS.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	zone.draw_string(J.TITRE_GRAS, Vector2(centre.x - largeur / 2.0, centre.y + (J.TITRE_GRAS.get_ascent(taille) - J.TITRE_GRAS.get_descent(taille)) / 2.0).round(), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, J.FOND if titulaire else J.TEXTE)

func _dessin_niveau(zone: Control, rect: Rect2, joueur: Dictionary) -> void:
	var niveau: Variant = joueur.get("rating")
	var taille := J.px(J.T_CHIFFRE)
	var texte := str(int(niveau)) if _nombre(niveau) else "—"
	zone.draw_string(J.TITRE_GRAS, Vector2(rect.position.x, rect.position.y + (rect.size.y + J.TITRE_GRAS.get_ascent(taille) - J.TITRE_GRAS.get_descent(taille)) / 2.0).round(), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, J.TEXTE)
	var gauche := rect.position.x + J.px(38)
	var largeur := rect.size.x - J.px(38)
	if largeur < J.px(60): return
	_barre_niveau(zone, Rect2(gauche, rect.position.y + rect.size.y / 2.0 - J.px(3), largeur, J.px(6)), joueur)

func _barre_niveau(sur: CanvasItem, rail: Rect2, joueur: Dictionary) -> void:
	sur.draw_style_box(J.boite(J.RAIL, 3), rail)
	var place := func(valeur: float) -> float:
		return rail.position.x + rail.size.x * clampf((valeur - NIVEAU_MIN) / (NIVEAU_MAX - NIVEAU_MIN), 0.0, 1.0)
	var p := _potentiel(joueur)
	if not p.is_empty():
		var debut: float = place.call(p.min)
		var fin: float = maxf(place.call(p.max), debut + J.px(6))
		sur.draw_style_box(J.boite(J.OR, 3), Rect2(debut, rail.position.y, fin - debut, rail.size.y))
	if _nombre(joueur.get("rating")):
		var x: float = place.call(float(joueur.rating))
		var l := float(maxi(3, J.px(3.5)))
		sur.draw_style_box(J.boite(J.TEXTE, 1.5), Rect2(x - l / 2.0, rail.position.y - J.px(5), l, rail.size.y + J.px(10)))

func _dessin_condition(zone: Control, rect: Rect2, joueur: Dictionary) -> void:
	var valeur: Variant = joueur.get("condition")
	if not _nombre(valeur):
		zone.draw_string(J.CORPS, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.64).round(), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, J.px(J.T_CORPS), J.TEXTE_FAIBLE)
		return
	var taille := J.px(J.T_CORPS)
	var texte := "%d %%" % floori(float(valeur))
	var l_texte := float(J.px(48))
	var rail := Rect2(rect.position.x, rect.position.y + rect.size.y / 2.0 - J.px(2.5), maxf(J.px(30), rect.size.x - l_texte - J.px(12)), J.px(5))
	zone.draw_style_box(J.boite(J.RAIL, 3), rail)
	zone.draw_style_box(J.boite(_couleur_condition(float(valeur)), 3), Rect2(rail.position, Vector2(rail.size.x * clampf(float(valeur) / 100.0, 0.0, 1.0), rail.size.y)))
	zone.draw_string(J.CORPS, Vector2(rail.end.x + J.px(12), rect.position.y + (rect.size.y + J.CORPS.get_ascent(taille) - J.CORPS.get_descent(taille)) / 2.0).round(), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, J.TEXTE_DOUX)

func _vignette(joueur: Dictionary, diametre: float) -> Control:
	var cadre := Panel.new()
	cadre.custom_minimum_size = Vector2(diametre, diametre)
	cadre.size = Vector2(diametre, diametre)
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	cadre.add_theme_stylebox_override("panel", J.boite(J.PANNEAU_HAUT, diametre))
	var portrait: TextureRect = G.portrait(int(joueur.get("portraitIndex", 0)), int(diametre), joueur)
	portrait.tooltip_text = ""
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.custom_minimum_size = Vector2.ZERO
	portrait.position = Vector2.ZERO
	portrait.size = Vector2(diametre, diametre * 1.18)
	cadre.add_child(portrait)
	return cadre

# ---------------------------------------------------------------- colonnes

func _colonnes(vue: int) -> Array:
	var numero := {"id": "numero", "titre": "N°", "largeur": 34, "aide": "Numéro sur la prochaine feuille de match. Pastille pleine : titulaire. Cerclée : remplaçant.",
		"valeur": func(j: Dictionary) -> Variant: return j.get("shirtNumber"), "dessin": _dessin_numero,
		"infobulle": func(j: Dictionary) -> String: return _statut(j)}
	var joueur := {"id": "joueur", "titre": "Joueur", "largeur": 226, "souple": 1.0, "gras": true,
		"valeur": func(j: Dictionary) -> Variant: return j.get("name"), "texte": func(j: Dictionary) -> String: return str(j.get("name", "")),
		"second": _precision_poste, "vignette": _vignette,
		"infobulle": func(j: Dictionary) -> String: return "%s · %s · %s" % [j.get("name", ""), j.get("pos", ""), _statut(j)]}
	var age := {"id": "age", "titre": "Âge", "largeur": 40, "priorite": 3,
		"valeur": func(j: Dictionary) -> Variant: return j.get("age"), "texte": func(j: Dictionary) -> String: return str(int(j.age)) if _nombre(j.get("age")) else "—"}
	var niveau := {"id": "niveau", "titre": "Niveau et potentiel", "largeur": 250, "decroissant_d_abord": true,
		"valeur": func(j: Dictionary) -> Variant: return j.get("rating"), "dessin": _dessin_niveau,
		"infobulle": func(j: Dictionary) -> String: return "Niveau %s · potentiel estimé %s" % [str(int(j.rating)) if _nombre(j.get("rating")) else "inconnu", _texte_potentiel(j)]}
	var condition := {"id": "condition", "titre": "Condition", "largeur": 136, "priorite": 1,
		"valeur": func(j: Dictionary) -> Variant: return j.get("condition"), "dessin": _dessin_condition}
	var salaire := {"id": "salaire", "titre": Salaire.field_label(), "largeur": 132, "priorite": 2, "align": HORIZONTAL_ALIGNMENT_RIGHT, "decroissant_d_abord": true,
		"valeur": func(j: Dictionary) -> Variant: return j.get("salary"), "texte": func(j: Dictionary) -> String: return Salaire.amount(j.get("salary"))}
	var contrat := {"id": "contrat", "titre": "Fin de contrat", "largeur": 104, "priorite": 1,
		"valeur": func(j: Dictionary) -> Variant: return j.get("contractEnd"), "texte": _texte_contrat,
		"couleur": func(j: Dictionary) -> Color: return J.ALERTE if _fin_cette_saison(j) else J.TEXTE_DOUX}
	match vue:
		1:
			return [numero, joueur, age,
				{"id": "statut", "titre": "Situation", "largeur": 170, "valeur": _statut, "texte": _statut,
					"couleur": func(j: Dictionary) -> Color: return J.ALERTE if _blesse(j) else J.TEXTE if str(j.get("status", "")) == "Titulaire" else J.TEXTE_DOUX},
				condition,
				{"id": "charge", "titre": "Fatigue", "largeur": 76, "decroissant_d_abord": true, "valeur": func(j: Dictionary) -> Variant: return j.get("physicalLoad"),
					"texte": func(j: Dictionary) -> String: return "%d / 100" % int(j.physicalLoad) if _nombre(j.get("physicalLoad")) else "—",
					"couleur": func(j: Dictionary) -> Color: return J.ALERTE if float(j.get("physicalLoad", 0)) >= 70 else J.TEXTE_DOUX},
				{"id": "minutes", "titre": "Minutes", "largeur": 70, "priorite": 2, "align": HORIZONTAL_ALIGNMENT_RIGHT, "decroissant_d_abord": true,
					"valeur": func(j: Dictionary) -> Variant: return j.get("minutes"), "texte": func(j: Dictionary) -> String: return str(int(j.minutes)) if _nombre(j.get("minutes")) else "—"},
				{"id": "matchs", "titre": "Matchs", "largeur": 64, "priorite": 3, "align": HORIZONTAL_ALIGNMENT_RIGHT, "decroissant_d_abord": true,
					"valeur": func(j: Dictionary) -> Variant: return j.get("appearances"), "texte": func(j: Dictionary) -> String: return str(int(j.appearances)) if _nombre(j.get("appearances")) else "—"},
				{"id": "suivi", "titre": "À surveiller", "largeur": 190, "priorite": 4, "valeur": U.watch_reason, "texte": U.watch_reason,
					"couleur": func(_j: Dictionary) -> Color: return J.JAUNE}]
		2:
			return [numero, joueur, age, niveau, salaire, contrat,
				{"id": "prolongation", "titre": "Prolongation", "largeur": 150, "priorite": 1,
					"valeur": func(j: Dictionary) -> Variant: return 1 if j.get("renewal", {}).get("available", false) else 0,
					"texte": func(j: Dictionary) -> String: return "Ouverte" if j.get("renewal", {}).get("available", false) else "Pas encore",
					"couleur": func(j: Dictionary) -> Color: return J.VERT if j.get("renewal", {}).get("available", false) else J.TEXTE_FAIBLE}]
		3:
			return [numero, joueur, age, niveau,
				{"id": "potentiel", "titre": "Potentiel estimé", "largeur": 130, "decroissant_d_abord": true,
					"valeur": func(j: Dictionary) -> Variant: return _potentiel(j).get("max"), "texte": _texte_potentiel,
					"couleur": func(_j: Dictionary) -> Color: return J.OR},
				{"id": "marge", "titre": "Marge", "largeur": 70, "priorite": 2, "align": HORIZONTAL_ALIGNMENT_RIGHT, "decroissant_d_abord": true,
					"aide": "Écart entre le niveau actuel et le haut du potentiel estimé.",
					"valeur": func(j: Dictionary) -> Variant: return _potentiel(j).max - float(j.rating) if not _potentiel(j).is_empty() and _nombre(j.get("rating")) else null,
					"texte": func(j: Dictionary) -> String: return "+%d" % maxi(0, int(_potentiel(j).max - float(j.rating))) if not _potentiel(j).is_empty() and _nombre(j.get("rating")) else "—"},
				{"id": "minutes", "titre": "Minutes", "largeur": 70, "priorite": 3, "align": HORIZONTAL_ALIGNMENT_RIGHT, "decroissant_d_abord": true,
					"valeur": func(j: Dictionary) -> Variant: return j.get("minutes"), "texte": func(j: Dictionary) -> String: return str(int(j.minutes)) if _nombre(j.get("minutes")) else "—"}]
	return [numero, joueur, age, niveau, condition, salaire, contrat]

# ---------------------------------------------------------------- construction

func _bouton(texte: String, actif_: bool, pilule := false, action := Callable()) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.add_theme_font_override("font", J.TITRE if not pilule else J.corps_gras())
	bouton.add_theme_font_size_override("font_size", J.px(19 if not pilule else J.T_CORPS))
	_habiller(bouton, actif_, pilule)
	if action.is_valid(): bouton.pressed.connect(action)
	return bouton

func _habiller(bouton: Button, actif_: bool, pilule: bool) -> void:
	var rayon := 20.0 if pilule else 7.0
	var marges := func(style: StyleBoxFlat) -> StyleBoxFlat:
		style.content_margin_left = J.px(16); style.content_margin_right = J.px(16)
		style.content_margin_top = J.px(7 if pilule else 8); style.content_margin_bottom = J.px(7 if pilule else 8)
		return style
	bouton.add_theme_stylebox_override("normal", marges.call(J.boite(J.TEXTE if actif_ else (J.PANNEAU_HAUT if pilule else Color.TRANSPARENT), rayon)))
	bouton.add_theme_stylebox_override("hover", marges.call(J.boite(J.TEXTE if actif_ else J.CHOIX, rayon)))
	bouton.add_theme_stylebox_override("pressed", marges.call(J.boite(J.TEXTE, rayon)))
	bouton.add_theme_stylebox_override("focus", marges.call(J.boite(Color.TRANSPARENT, rayon, 0, J.OR)))
	for nom: String in ["font_color", "font_hover_color", "font_focus_color"]:
		bouton.add_theme_color_override(nom, J.FOND if actif_ else J.TEXTE)
	bouton.add_theme_color_override("font_pressed_color", J.FOND)

func _carte(marge := 18.0) -> PanelContainer:
	var carte := PanelContainer.new()
	carte.add_theme_stylebox_override("panel", J.boite(J.PANNEAU, J.RAYON, marge))
	return carte

func _construire() -> void:
	name = "SocleEffectif"
	J.regler(Vector2(app.get_window().size))
	saison = int(app.model.get("meta", {}).get("season", 1))
	if not app.management_ui.has("socle_effectif"):
		app.management_ui["socle_effectif"] = {"vue": 0, "filtre": "tous", "tri": "", "decroissant": false, "grouper": true, "recherche": ""}
	etat = app.management_ui.socle_effectif
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, J.px(420))
	var racine := VBoxContainer.new()
	racine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	racine.add_theme_constant_override("separation", J.px(J.E3))
	add_child(racine)

	# Barre : filtres à gauche, vues à droite.
	var barre := HBoxContainer.new()
	barre.add_theme_constant_override("separation", J.px(J.E2))
	racine.add_child(barre)
	var joueurs := _joueurs()
	var avants := joueurs.filter(func(j: Dictionary): return int(j.get("fam", 9)) <= 3).size()
	var fins := joueurs.filter(_fin_cette_saison).size()
	var suivis := joueurs.filter(func(j: Dictionary): return not U.watch_reason(j).is_empty() or _blesse(j)).size()
	for filtre: Array in [["tous", "Tous, %d" % joueurs.size()], ["avants", "Avants, %d" % avants], ["arrieres", "Arrières, %d" % (joueurs.size() - avants)], ["fin", "Fin de contrat cette saison, %d" % fins], ["suivi", "À surveiller, %d" % suivis]]:
		var id: String = filtre[0]
		var bouton := _bouton(filtre[1], etat.filtre == id, true, func(): _filtrer(id))
		bouton.name = "Filtre_" + id
		boutons_filtre[id] = bouton
		barre.add_child(bouton)
	var recherche := LineEdit.new()
	recherche.name = "RechercheEffectif"
	recherche.placeholder_text = "Chercher un joueur"
	recherche.tooltip_text = "Par nom ou par poste, sans tenir compte des accents."
	recherche.text = str(etat.recherche)
	recherche.clear_button_enabled = true
	recherche.custom_minimum_size = Vector2(J.px(200), 0)
	recherche.add_theme_font_override("font", J.CORPS)
	recherche.add_theme_font_size_override("font_size", J.px(J.T_CORPS))
	recherche.add_theme_color_override("font_color", J.TEXTE)
	recherche.add_theme_color_override("font_placeholder_color", J.TEXTE_FAIBLE)
	var champ := J.boite(J.PANNEAU_HAUT, 20)
	champ.content_margin_left = J.px(16); champ.content_margin_right = J.px(12); champ.content_margin_top = J.px(6); champ.content_margin_bottom = J.px(6)
	recherche.add_theme_stylebox_override("normal", champ)
	var champ_actif: StyleBoxFlat = champ.duplicate()
	champ_actif.border_color = J.OR; champ_actif.set_border_width_all(maxi(1, J.px(1)))
	recherche.add_theme_stylebox_override("focus", champ_actif)
	recherche.text_changed.connect(func(texte: String):
		etat.recherche = texte
		_appliquer_filtre())
	barre.add_child(recherche)
	var ressort := Control.new()
	ressort.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barre.add_child(ressort)
	var vues := PanelContainer.new()
	vues.add_theme_stylebox_override("panel", J.boite(J.PANNEAU, 9, 4))
	var rang_vues := HBoxContainer.new()
	rang_vues.add_theme_constant_override("separation", J.px(2))
	vues.add_child(rang_vues)
	for i in VUES.size():
		var bouton := _bouton(VUES[i], int(etat.vue) == i, false, func(): _changer_vue(i))
		bouton.name = "Vue_%d" % i
		boutons_vue.append(bouton)
		rang_vues.add_child(bouton)
	barre.add_child(vues)

	# Corps : tableau à gauche, fiche à droite.
	var corps := HBoxContainer.new()
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corps.add_theme_constant_override("separation", J.px(J.E4))
	racine.add_child(corps)
	var carte := _carte(J.E4)
	carte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corps.add_child(carte)
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", J.px(J.E2))
	carte.add_child(pile)
	tableau = Tableau.new()
	tableau.name = "TableauEffectif"
	tableau.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tableau.message_vide = "Aucun joueur ne correspond à cette recherche."
	tableau.entete_groupe = _entete_ligne
	tableau.ordre_groupes = ORDRE_LIGNES
	tableau.colonnes = _colonnes(int(etat.vue))
	tableau.tri_colonne = str(etat.tri)
	tableau.tri_decroissant = bool(etat.decroissant)
	tableau.ligne_choisie.connect(func(joueur: Dictionary):
		app.selected_player = str(joueur.id)
		_fiche())
	tableau.ligne_activee.connect(func(joueur: Dictionary):
		app.selected_player = str(joueur.id)
		_ouvrir_fiche())
	tableau.tri_change.connect(func(colonne: String, decroissant: bool):
		etat.tri = colonne
		etat.decroissant = decroissant)
	tableau.contenu_change.connect(_ecrire_pied)
	pile.add_child(tableau)
	var bas := HBoxContainer.new()
	bas.add_theme_constant_override("separation", J.px(J.E4))
	pile.add_child(bas)
	pied = J.texte("", J.T_PETIT, J.TEXTE_FAIBLE)
	pied.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pied.clip_text = true
	bas.add_child(pied)
	var grouper := _bouton("Grouper par ligne", bool(etat.grouper), true)
	grouper.name = "GrouperParLigne"
	grouper.add_theme_font_size_override("font_size", J.px(J.T_PETIT))
	grouper.pressed.connect(func():
		etat.grouper = not bool(etat.grouper)
		_habiller(grouper, bool(etat.grouper), true)
		_appliquer_groupes()
		tableau.definir_lignes(_joueurs_ordonnes()))
	bas.add_child(grouper)

	var defile := ScrollContainer.new()
	defile.name = "FicheEffectif"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.custom_minimum_size = Vector2(J.px(392), 0)
	corps.add_child(defile)
	colonne_droite = VBoxContainer.new()
	colonne_droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne_droite.add_theme_constant_override("separation", J.px(J.E3))
	defile.add_child(colonne_droite)

	_appliquer_groupes()
	tableau._filtre = _filtre_courant()
	tableau.definir_lignes(_joueurs_ordonnes())
	var visibles: Array = tableau.lignes_visibles()
	if visibles.filter(func(j: Dictionary): return str(j.id) == app.selected_player).is_empty() and not visibles.is_empty():
		app.selected_player = str(visibles[0].id)
	tableau.choisir(app.selected_player, false)
	_fiche()
	_caler_hauteur.call_deferred()

func _caler_hauteur() -> void:
	# Le corps de page défile ; l'écran, lui, tient dans la hauteur visible et fait défiler son tableau.
	await get_tree().process_frame
	if not is_instance_valid(app.body_scroll): return
	var ajuster := func():
		if is_instance_valid(self) and is_instance_valid(app.body_scroll):
			custom_minimum_size.y = maxf(J.px(320), app.body_scroll.size.y - 2)
	ajuster.call()
	app.body_scroll.resized.connect(ajuster)
	await get_tree().process_frame
	tableau.choisir(app.selected_player, true)

# ---------------------------------------------------------------- comportement

func _entete_ligne(famille: Variant, joueurs: Array) -> Dictionary:
	var ligne: Dictionary = LIGNES[int(famille)] if int(famille) >= 0 and int(famille) < LIGNES.size() else {"nom": "Autres", "places": 0}
	var banc := joueurs.filter(func(j: Dictionary): return str(j.get("status", "")) == "Remplaçant").size()
	var blesses := joueurs.filter(_blesse).size()
	var detail := "%d pour %d place%s" % [joueurs.size(), ligne.places, "s" if ligne.places > 1 else ""]
	if banc > 0: detail += ", %d sur le banc" % banc
	if blesses > 0: detail += ", %d blessé%s" % [blesses, "s" if blesses > 1 else ""]
	return {"titre": ligne.nom, "detail": detail}

func _appliquer_groupes() -> void:
	tableau.groupe_de = (func(j: Dictionary) -> Variant: return int(j.get("fam", 9))) if bool(etat.grouper) else Callable()

func _filtre_courant() -> Callable:
	var filtre := str(etat.filtre)
	var cherche := J.plier(str(etat.recherche).strip_edges())
	return func(j: Dictionary) -> bool:
		if filtre == "avants" and int(j.get("fam", 9)) > 3: return false
		if filtre == "arrieres" and int(j.get("fam", 9)) <= 3: return false
		if filtre == "fin" and not _fin_cette_saison(j): return false
		if filtre == "suivi" and U.watch_reason(j).is_empty() and not _blesse(j): return false
		if not cherche.is_empty() and J.plier(str(j.get("name", "")) + " " + str(j.get("pos", ""))).find(cherche) < 0: return false
		return true

func _appliquer_filtre() -> void:
	tableau.definir_filtre(_filtre_courant())

func _filtrer(id: String) -> void:
	etat.filtre = id
	for cle: String in boutons_filtre: _habiller(boutons_filtre[cle], cle == id, true)
	_appliquer_filtre()

func _changer_vue(indice: int) -> void:
	etat.vue = indice
	for i in boutons_vue.size(): _habiller(boutons_vue[i], i == indice, false)
	var colonnes := _colonnes(indice)
	if colonnes.filter(func(c: Dictionary): return c.id == etat.tri).is_empty():
		etat.tri = ""; etat.decroissant = false
		tableau.tri_colonne = ""; tableau.tri_decroissant = false
	tableau.colonnes = colonnes
	tableau.definir_lignes(_joueurs_ordonnes())

func _ecrire_pied(visibles: int, total: int) -> void:
	if not is_instance_valid(pied): return
	var debut := "%d joueur%s" % [total, "s" if total > 1 else ""] if visibles == total else "%d joueur%s sur %d" % [visibles, "s" if visibles > 1 else "", total]
	pied.text = debut + ". Pastille pleine : titulaire au prochain match. Cerclée : remplaçant. Entrée ou double-clic : fiche du joueur."

func _ouvrir_fiche() -> void:
	app.set_meta("immersive08_full_player", true)
	app._render()

# ---------------------------------------------------------------- fiche de droite

class Trait extends Control:
	var dessiner: Callable
	func _draw() -> void:
		if dessiner.is_valid(): dessiner.call(self)

func _joueur_choisi() -> Dictionary:
	for j: Dictionary in _joueurs():
		if str(j.get("id", "")) == app.selected_player: return j
	return {}

func _fiche() -> void:
	for enfant in colonne_droite.get_children():
		colonne_droite.remove_child(enfant)
		enfant.queue_free()
	var joueur := _joueur_choisi()
	if joueur.is_empty():
		var vide := _carte()
		vide.add_child(J.texte("Choisissez un joueur dans la liste.", J.T_CORPS, J.TEXTE_DOUX))
		colonne_droite.add_child(vide)
	else:
		colonne_droite.add_child(_carte_joueur(joueur))
		colonne_droite.add_child(_carte_contrat(joueur))
	colonne_droite.add_child(_carte_profondeur())

func _carte_joueur(joueur: Dictionary) -> Control:
	var carte := _carte()
	carte.name = "CarteJoueur"
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", J.px(J.E3))
	carte.add_child(pile)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", J.px(J.E4))
	pile.add_child(tete)
	var cadre := Panel.new()
	var cote := Vector2(J.px(92), J.px(104))
	cadre.custom_minimum_size = cote
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	cadre.add_theme_stylebox_override("panel", J.boite(J.PANNEAU_HAUT, 8))
	var portrait: TextureRect = G.portrait(int(joueur.get("portraitIndex", 0)), int(cote.x), joueur)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.custom_minimum_size = Vector2.ZERO
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cadre.add_child(portrait)
	tete.add_child(cadre)
	var identite := VBoxContainer.new()
	identite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identite.alignment = BoxContainer.ALIGNMENT_END
	identite.add_theme_constant_override("separation", J.px(2))
	tete.add_child(identite)
	var nom := J.texte(str(joueur.get("name", "")), 28, J.TEXTE, J.TITRE_GRAS)
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identite.add_child(nom)
	var precision := _precision_poste(joueur)
	var ligne_poste := str(joueur.get("pos", ""))
	if not precision.is_empty() and int(joueur.get("fam", -1)) == 3: ligne_poste += " " + precision
	if _nombre(joueur.get("age")): ligne_poste += ", %d ans" % int(joueur.age)
	identite.add_child(J.texte(ligne_poste, J.T_CORPS, J.TEXTE_DOUX))
	var numero: Variant = joueur.get("shirtNumber")
	var situation := _statut(joueur)
	if _nombre(numero) and not _blesse(joueur): situation += ", numéro %d" % int(numero)
	identite.add_child(J.texte(situation, J.T_CORPS, J.ALERTE if _blesse(joueur) else J.VERT if _nombre(numero) else J.TEXTE_FAIBLE))

	var chiffres := HBoxContainer.new()
	chiffres.add_theme_constant_override("separation", J.px(J.E2))
	pile.add_child(chiffres)
	var niveau := J.texte(str(int(joueur.rating)) if _nombre(joueur.get("rating")) else "—", J.T_GEANT, J.TEXTE, J.TITRE_GRAS)
	chiffres.add_child(niveau)
	var aujourd_hui := J.texte("aujourd’hui", J.T_CORPS, J.TEXTE_DOUX)
	aujourd_hui.size_flags_vertical = Control.SIZE_SHRINK_END
	chiffres.add_child(aujourd_hui)
	var p := _potentiel(joueur)
	if not p.is_empty():
		var espace := Control.new(); espace.custom_minimum_size = Vector2(J.px(J.E2), 0); chiffres.add_child(espace)
		var possible := J.texte(_texte_potentiel(joueur), 32, J.OR, J.TITRE_GRAS)
		possible.size_flags_vertical = Control.SIZE_SHRINK_END
		chiffres.add_child(possible)
		var suffixe := J.texte("possible", J.T_CORPS, J.TEXTE_DOUX)
		suffixe.size_flags_vertical = Control.SIZE_SHRINK_END
		chiffres.add_child(suffixe)
	var barre := Trait.new()
	barre.custom_minimum_size = Vector2(0, J.px(18))
	barre.dessiner = func(sur: Control): _barre_niveau(sur, Rect2(0, sur.size.y / 2.0 - J.px(3), sur.size.x, J.px(6)), joueur)
	pile.add_child(barre)

	if _nombre(joueur.get("condition")):
		var rang := HBoxContainer.new()
		pile.add_child(rang)
		var libelle := J.texte("Condition", J.T_CORPS, J.TEXTE_DOUX)
		libelle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rang.add_child(libelle)
		var charge := float(joueur.get("physicalLoad", 0))
		rang.add_child(J.texte("%d %%, fatigue %d / 100" % [floori(float(joueur.condition)), int(charge)], J.T_CORPS, J.TEXTE))
		var jauge := Trait.new()
		jauge.custom_minimum_size = Vector2(0, J.px(6))
		jauge.dessiner = func(sur: Control):
			sur.draw_style_box(J.boite(J.RAIL, 3), Rect2(Vector2.ZERO, sur.size))
			sur.draw_style_box(J.boite(_couleur_condition(float(joueur.condition)), 3), Rect2(0, 0, sur.size.x * clampf(float(joueur.condition) / 100.0, 0, 1), sur.size.y))
		pile.add_child(jauge)
	var suivi := U.watch_reason(joueur)
	if not suivi.is_empty():
		var alerte := J.texte("À surveiller : " + suivi, J.T_PETIT + 1, J.JAUNE)
		alerte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pile.add_child(alerte)

	var ouvrir := _bouton("Ouvrir sa fiche", true, false, _ouvrir_fiche)
	ouvrir.name = "OuvrirFicheJoueur"
	pile.add_child(ouvrir)
	return carte

func _carte_contrat(joueur: Dictionary) -> Control:
	var carte := _carte()
	carte.name = "CarteContrat"
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", J.px(J.E1))
	carte.add_child(pile)
	pile.add_child(J.texte("Son contrat", J.T_TITRE, J.TEXTE, J.TITRE))
	var rang := HBoxContainer.new()
	rang.add_theme_constant_override("separation", J.px(J.E2))
	pile.add_child(rang)
	rang.add_child(J.texte(Salaire.amount(joueur.get("salary")), 32, J.TEXTE, J.TITRE_GRAS))
	var fin := "jusqu’à la fin de cette saison" if _fin_cette_saison(joueur) else "jusqu’en " + G.contract_year(joueur.get("contractEnd"))
	var suite := J.texte(Salaire.period_label() + ", " + fin, J.T_CORPS, J.ALERTE if _fin_cette_saison(joueur) else J.TEXTE_DOUX)
	suite.size_flags_vertical = Control.SIZE_SHRINK_END
	rang.add_child(suite)
	# Repère factuel : rang du salaire dans sa ligne.
	var famille := int(joueur.get("fam", -1))
	var meme_ligne := _joueurs().filter(func(j: Dictionary): return int(j.get("fam", -2)) == famille and _nombre(j.get("salary")))
	if meme_ligne.size() > 1 and _nombre(joueur.get("salary")) and famille >= 0 and famille < LIGNES.size():
		var devant := meme_ligne.filter(func(j: Dictionary): return float(j.salary) > float(joueur.salary)).size()
		var repere := J.texte("%s salaire sur %d à ce poste (%s)." % ["1er" if devant == 0 else "%de" % (devant + 1), meme_ligne.size(), LIGNES[famille].un], J.T_CORPS, J.TEXTE_DOUX)
		repere.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pile.add_child(repere)
	if joueur.get("renewal", {}).get("available", false):
		var ouverte := J.texte("Prolongation ouverte.", J.T_CORPS, J.OR)
		ouverte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pile.add_child(ouverte)
	return carte

func _carte_profondeur() -> Control:
	var carte := _carte()
	carte.name = "CarteProfondeur"
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", J.px(3))
	carte.add_child(pile)
	var titre := J.texte("Profondeur par ligne", J.T_TITRE, J.TEXTE, J.TITRE)
	titre.tooltip_text = "Clair : sur la prochaine feuille de match. Sombre : en réserve. Rouge : blessé."
	titre.mouse_filter = Control.MOUSE_FILTER_PASS
	pile.add_child(titre)
	var joueurs := _joueurs()
	for famille: int in ORDRE_LIGNES:
		var ligne := joueurs.filter(func(j: Dictionary): return int(j.get("fam", -1)) == famille)
		var retenus := ligne.filter(func(j: Dictionary): return str(j.get("status", "")) in ["Titulaire", "Remplaçant"] and not _blesse(j)).size()
		var blesses := ligne.filter(_blesse).size()
		var rang := HBoxContainer.new()
		rang.add_theme_constant_override("separation", J.px(J.E2))
		pile.add_child(rang)
		var nom := J.texte(LIGNES[famille].nom, J.T_CORPS, J.TEXTE_DOUX)
		nom.custom_minimum_size = Vector2(J.px(134), 0)
		rang.add_child(nom)
		var cases := Trait.new()
		cases.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cases.custom_minimum_size = Vector2(0, J.px(18))
		var total := ligne.size()
		cases.dessiner = func(sur: Control):
			var l := float(J.px(11))
			var pas := l + J.px(3)
			for i in total:
				var couleur := J.TEXTE if i < retenus else J.ALERTE if i >= total - blesses else J.RESERVE
				sur.draw_style_box(J.boite(couleur, 2), Rect2(i * pas, (sur.size.y - l) / 2.0, l, l))
		cases.tooltip_text = "%d sur la feuille, %d en réserve%s" % [retenus, total - retenus - blesses, ", %d blessé%s" % [blesses, "s" if blesses > 1 else ""] if blesses > 0 else ""]
		cases.mouse_filter = Control.MOUSE_FILTER_PASS
		rang.add_child(cases)
		var compte := J.texte(str(total), J.T_CORPS, J.TEXTE, J.corps_gras())
		compte.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		compte.custom_minimum_size = Vector2(J.px(24), 0)
		rang.add_child(compte)
	return carte
