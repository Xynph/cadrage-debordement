extends Control
## Écran Effectif (maquette validée du 19/11/2026, variante « nouvelle 1 ») : titre et quatre tuiles, onglets,
## puces de filtre, tableau pleine largeur groupé Avants / Arrières. Pas de fiche à droite : le survol d'un nom
## (ou du « i ») montre la mini-fiche, le clic ouvre la fiche complète. Tout est dessiné sur le gabarit 2248 de large
## et sert à toutes les tailles de fenêtre ; en fenêtre étroite on retire des colonnes plutôt que de réduire le texte.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const G = preload("res://ui/game_skin.gd")
const U = preload("res://ui/management_state.gd")
const Charte = preload("res://ui/charte.gd")
const Identity = preload("res://ui/player_identity.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")
const Notes = preload("res://ui/notes_match.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Sales = preload("res://ui/player_sales_view.gd")
const Panneaux = preload("res://ui/immersive08/panneaux_effectif.gd")
const Listes = preload("res://ui/immersive08/listes_joueurs.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")
const Courbe = preload("res://ui/mini_courbe_survol.gd")
const Etoiles = preload("res://ui/immersive08/liste_etoiles.gd")
const ROW_HEIGHT := 34
const GROUP_HEIGHT := 30
const FIRST_ROWS := 26
const ROWS_PER_FRAME := 18
const VISIBLE_MARGIN := 6
const LARGEUR := 2248.0
const HAUT_PAGE := 1244.0
const Y_ONGLETS := 130.0
const Y_FILTRES := 196.0
const Y_ENTETE := 254.0
const Y_LIGNES := 292.0
const Y_PIED := 1206.0
## Postes de l'équilibre du groupe : libellé et numéros de poste principal.
const POSTES := [["Pilier gauche",[1]],["Talonneur",[2]],["Pilier droit",[3]],["Deuxième ligne",[4,5]],["3e ligne aile",[6,7]],["Numéro 8",[8]],["Demi de mêlée",[9]],["Ouvreur",[10]],["Ailier",[11,14]],["Centre",[12,13]],["Arrière",[15]]]
const VUES := ["Vue d’ensemble","Condition","Contrats","Développement"]
const TRIS := ["Numéro","Poste","Autres postes","Nom","Niveau","Potentiel","Condition","Fatigue","Minutes","Moyenne","Forme","Statut","Âge","Salaire","Échéance","Motif"]
var app: Control
var state: Dictionary
var rows: VBoxContainer
var count: Label
var compare: Button
var sort_headers: Dictionary = {}
var _generation := 0
var _group := ""
var _puces: Dictionary = {}
var _marques_tuiles: Dictionary = {}
var _colonnes_actives: Array = []
## Vrai pendant que le focus mémorisé est rendu : il ne doit pas déplacer la sélection choisie ailleurs (palette, retour de fiche).
var _restaurant := false
## Panneaux latéraux à gauche (panneaux_effectif.gd) : décalage et largeur du tableau.
var _x0 := 0.0
var _lt := LARGEUR
## Rangées au-dessus du tableau (choix de Léo du 21/11/2026) : tuiles des totaux de la liste filtrée, puis pastilles de poste.
const Y_TOTAUX := Y_FILTRES + 52.0
const Y_POSTES := Y_FILTRES + 122.0
const DY_RANGEES := 118.0
var _dy := 0.0
var _bandeau_totaux: Control
## Poste (1-15) dont la liste montre les étoiles, choisi d'un clic sur un maillot du terrain XV ; 0 = aucun.
var _poste := 0

static func build(owner_app: Control) -> Control:
	var page: Control = load("res://ui/immersive08/squad_canvas.gd").new()
	page.app = owner_app
	page._build()
	return page

func _etroit() -> bool:
	return C.density < .7

func _build() -> void:
	name = "CarnetSquad"
	custom_minimum_size = Vector2(LARGEUR, HAUT_PAGE) * C.density
	C.fill(self, true)
	state = app.management_ui.roster
	state.family = app.roster_filter
	state.sort = app.roster_sort
	if state.sort == "Note":
		state.sort = "Niveau"; state.descending = true; app.roster_sort = "Niveau"
	_entete_page()
	_onglets()
	if int(state.get("immersive_tab", 0)) == 2:
		var review := preload("res://ui/contract_review.gd").build(app)
		add_child(review)
		D.place(review, Rect2(0, Y_FILTRES, LARGEUR, HAUT_PAGE - Y_FILTRES - 40))
		return
	_dy = DY_RANGEES
	_poste = int(state.get("etoiles_poste", 0))
	# Panneaux latéraux à gauche : bandeau des filtres, totaux, pastilles de poste et tableau prennent la largeur restante.
	_x0 = Panneaux.reserve(app)
	_lt = LARGEUR - _x0
	_filtres()
	_rangees_listes()
	_tableau()
	_bandeau_filtres()
	Panneaux.construire(self, app, Y_FILTRES - 10.0, HAUT_PAGE - 4)
	_refresh(true)
	_restaurer()

## Bandeau des filtres (demande de Léo du 21/11/2026) : recherche, puces, tuiles des totaux, pastilles de poste et
## en-têtes de colonnes dans un panneau teinté détouré, aligné sur la largeur réelle du tableau.
func _bandeau_filtres() -> void:
	var haut := Y_FILTRES - 10.0
	# Un seul bloc, recherche comprise, aligné sur le tableau à droite des panneaux latéraux (même haut que la colonne).
	var bandeau := Bandeau.poser(self, Rect2(_x0, haut, _lt, Y_ENTETE + _dy + 36.0 - haut), 40.0)
	var table := get_node_or_null("ImmersiveRosterTable") as Control
	if table != null: bandeau.suivre(table)

## Rend la lecture (focus, défilement) puis, si personne n'a fait défiler la liste, ramène le joueur choisi dans la zone visible.
func _restaurer() -> void:
	_restaurant = true
	# Une case de forme porte le même nom sur chaque ligne : on ne lui rend pas le focus (il sauterait en tête de liste).
	if str(state.get("focus", "")).begins_with("FormeMatch"): state.focus = ""
	await U.restore(app, self, "roster")
	_restaurant = false
	if not is_instance_valid(self) or not is_inside_tree() or int(state.get("scroll", 0)) > 0: return
	await get_tree().process_frame
	var defile := find_child("SquadScroll", true, false) as ScrollContainer
	if defile == null: return
	for ligne: Node in rows.get_children():
		if ligne.get_meta("player_id", "") == app.selected_player:
			defile.ensure_control_visible(ligne as Control)
			break

# ---------------------------------------------------------------- outils de dessin

## Fond plat de la charte (rayon en référence 2560) : 6 par défaut (case, ligne), 16 pour une tuile (12 px), pilule pour
## onglet, puce et champ.
## Champ de la charte : pilule, contour fin, jamais d'ombre.
static func _champ(fond: Color, bord: Color) -> StyleBoxFlat:
	var style := _plat(fond, bord, 1, Charte.RAYON_PILULE)
	style.content_margin_left = C.px(18)
	style.content_margin_right = C.px(18)
	return style

static func _plat(fond: Color, bord: Color = Color.TRANSPARENT, epaisseur: int = 0, rayon: int = Charte.RAYON_PETIT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.border_color = bord
	style.set_border_width_all(epaisseur)
	style.set_corner_radius_all(rayon if rayon >= Charte.RAYON_PILULE else maxi(3, C.px(rayon)))
	style.anti_aliasing = true
	return Charte.ombrer(style, rayon)

static func _italique(label: Label, gras := true) -> Label:
	label.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE if gras else Charte.TITRE_GRAS_ITALIQUE)
	return label

## Largeur d'un texte en unités du gabarit, mesurée avec la police et la taille réellement affichées.
static func _largeur(texte: String, taille: float, corps := true, graisse := 600) -> float:
	var police: Font = C.BODY if corps else C.font(graisse)
	return police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille))).x / C.density

## Parallélogramme incliné de 10° (marqueur de sélection et d'état actif).
static func _marqueur(parent: Control, zone: Rect2, couleur: Color = Charte.IVOIRE) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = couleur
	var h := zone.size.y * C.density
	var d := Charte.decalage(h)
	var l := zone.size.x * C.density
	poly.polygon = PackedVector2Array([Vector2(d, 0), Vector2(d + l, 0), Vector2(l, h), Vector2(0, h)])
	poly.position = zone.position * C.density
	parent.add_child(poly)
	return poly

func _lien(parent: Control, zone: Rect2, texte: String, action: Callable, id: String, couleur: Color = Charte.IVOIRE, taille := 19.0, aligne: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, lien_commun := false) -> Button:
	var bouton := Button.new()
	bouton.name = id
	bouton.text = texte
	bouton.flat = false
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.alignment = aligne
	bouton.clip_text = true
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.add_theme_font_override("font", C.BODY)
	bouton.add_theme_font_size_override("font_size", maxi(12, C.px(taille)))
	for nom: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		bouton.add_theme_color_override(nom, couleur)
	var marge := C.px(10)
	for etat: String in ["normal", "pressed"]:
		var style := _plat(Color.TRANSPARENT); style.content_margin_left = marge; style.content_margin_right = marge
		bouton.add_theme_stylebox_override(etat, style)
	var survol := _plat(Charte.PANNEAU_2); survol.content_margin_left = marge; survol.content_margin_right = marge
	bouton.add_theme_stylebox_override("hover", survol)
	var focus := _plat(Color.TRANSPARENT, Charte.IVOIRE, 1); focus.content_margin_left = marge; focus.content_margin_right = marge
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.pressed.connect(action)
	if lien_commun:
		C.style_bouton_lien(bouton, int(taille))
		bouton.alignment = aligne
	parent.add_child(bouton)
	D.place(bouton, C.reach_rect(zone))
	return bouton

# ---------------------------------------------------------------- titre et tuiles

func _entete_page() -> void:
	var saison := int(app.model.get("meta", {}).get("season", 1))
	var joueurs: Array = app.model.get("squad", [])
	var titre_effectif := D.text(self, 0, 64, "EFFECTIF", 58, C.IVORY, 800, 600)
	titre_effectif.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre_effectif.name = "RosterTitre"
	# Sous le titre : deux pastilles neutres « 36 joueurs » et « 2026-27 » (plus de phrase, 21/11).
	var nombre := R.pastille(self, 0, 104, "%d joueur%s" % [joueurs.size(), "s" if joueurs.size() > 1 else ""], Charte.IVOIRE_2, "people", "RosterSousTitre")
	R.cliquable(nombre, _tous_les_joueurs, "RosterSousTitreOuvrir", "Tous les joueurs sous contrat")
	var saison_p := R.pastille(self, nombre.size.x / C.density + 10, 104, _saison_courte(G.season_label(saison)), Charte.IVOIRE_2, "calendar", "RosterSaison")
	R.cliquable(saison_p, func(): app._navigate("Calendrier"), "RosterSaisonOuvrir", "Calendrier de la saison " + G.season_label(saison))
	_tuiles(joueurs, saison)

## Moyenne de niveau du XV (numéros 1 à 15) et son évolution depuis le début de saison, si elle est connue pour tout le XV.
func _xv() -> Dictionary:
	var debuts := {}
	for fiche: Variant in app.model.get("decisions", {}).get("development", {}).get("professionals", []):
		if fiche is Dictionary and fiche.get("development") is Dictionary and fiche.development.get("seasonStart") != null:
			debuts[str(fiche.get("id", ""))] = float(fiche.development.seasonStart)
	var total := 0.0
	var debut := 0.0
	var nombre := 0
	var connus := true
	for p: Variant in app.model.get("squad", []):
		if not p is Dictionary: continue
		var numero: Variant = p.get("shirtNumber")
		if not ((numero is int or numero is float) and int(numero) >= 1 and int(numero) <= 15): continue
		if not (p.get("rating") is int or p.get("rating") is float): return {}
		total += float(p.rating)
		nombre += 1
		if debuts.has(str(p.get("id", ""))): debut += float(debuts[str(p.id)])
		else: connus = false
	if nombre == 0: return {}
	var resultat := {"moyenne": total / nombre}
	if connus: resultat.evolution = (total - debut) / nombre
	return resultat

## Pastille « 36 joueurs » : retire filtres et recherche (tous onglets, y compris Contrats).
func _tous_les_joueurs() -> void:
	state.family = "Tous"
	state.contract = "Tous"
	state.search = ""
	state.scroll = 0
	app.roster_filter = "Tous"
	app._render(false)

## « 2026-2027 » devient « 2026-27 » comme dans la maquette.
static func _saison_courte(libelle: String) -> String:
	var m := RegEx.create_from_string("^(\\d{4})-(\\d{2})(\\d{2})$").search(libelle)
	return m.get_string(1) + "-" + m.get_string(3) if m != null else libelle

static func _decimal(valeur: float) -> String:
	return ("%.1f" % valeur).replace(".", ",")

func _tuiles(joueurs: Array, saison: int) -> void:
	var blesses := 0
	var suspendus := 0
	var selection := 0
	var fins := 0
	for p: Variant in joueurs:
		if not p is Dictionary: continue
		match U.indisponibilite(p):
			"blesse": blesses += 1
			"suspendu": suspendus += 1
			"selection": selection += 1
		if p.get("contractEnd") != null and int(p.contractEnd) <= saison: fins += 1
	var indispos := blesses + suspendus + selection
	var detail: Array[String] = []
	if blesses > 0: detail.append("%d blessé%s" % [blesses, "s" if blesses > 1 else ""])
	if suspendus > 0: detail.append("%d suspendu%s" % [suspendus, "s" if suspendus > 1 else ""])
	if selection > 0: detail.append("%d sél." % selection)
	var xv := _xv()
	var tendance := ""
	if xv.has("evolution"):
		var e: float = xv.evolution
		tendance = "—" if absf(e) < .05 else ("▲ +" if e > 0 else "▼ −") + _decimal(absf(e))
	var etroit := _etroit()
	var definitions := [
		{"id": "Aptes", "cap": "APTES ▾", "val": str(joueurs.size() - indispos), "suf": "/ %d" % joueurs.size(), "l": 250.0 if not etroit else 210.0, "act": "aptes", "aide": "Joueurs aptes : survol pour l’équilibre par poste, clic pour ne garder qu’eux."},
		{"id": "Indisponibles", "cap": "INDISPONIBLES", "val": str(indispos), "suf": " · ".join(detail) if not etroit else "", "l": 330.0 if not etroit else 250.0, "act": "indisponibles", "aide": "Indisponibles : " + (" · ".join(detail) if not detail.is_empty() else "aucun")},
		{"id": "Contrats", "cap": "FINS DE CONTRAT", "val": str(fins), "suf": "cette saison", "l": 290.0 if not etroit else 250.0, "act": "fin", "aide": "Contrats qui s’achèvent cette saison."},
		{"id": "Niveau", "cap": "NIVEAU MOYEN DU XV", "val": _decimal(xv.moyenne) if xv.has("moyenne") else "—", "suf": tendance if not etroit else "", "l": 360.0 if not etroit else 270.0, "act": "niveau", "aide": "Niveau moyen des quinze titulaires (clic : trier par niveau)." + ("\n" + ("Stable cette saison" if tendance == "—" else tendance + " cette saison") if not tendance.is_empty() else "")},
	]
	var x := LARGEUR
	for i in range(definitions.size() - 1, -1, -1):
		var d: Dictionary = definitions[i]
		x -= float(d.l)
		_tuile(Rect2(x, 0, float(d.l), 88), d)
		x -= 14.0

func _tuile(zone: Rect2, d: Dictionary) -> void:
	var tuile := Button.new()
	tuile.name = "EffectifTuile" + str(d.id)
	tuile.focus_mode = Control.FOCUS_ALL
	tuile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tuile.accessibility_name = "%s %s %s" % [str(d.cap).trim_suffix(" ▾"), d.val, d.suf]
	tuile.tooltip_text = "" if d.id == "Aptes" else str(d.aide)
	tuile.add_theme_stylebox_override("normal", _plat(Charte.PANNEAU, Color.TRANSPARENT, 0, 16))
	tuile.add_theme_stylebox_override("hover", _plat(Charte.PANNEAU_2, Color.TRANSPARENT, 0, 16))
	tuile.add_theme_stylebox_override("pressed", _plat(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 16))
	tuile.add_theme_stylebox_override("focus", _plat(Color.TRANSPARENT, Charte.IVOIRE, 2, 16))
	add_child(tuile)
	D.place(tuile, zone)
	load("res://ui/retour_tuile.gd").brancher(tuile, tuile, C.px(16))
	D.text(tuile, 16, 28, d.cap, 17, C.MUTED, 700, zone.size.x - 28)
	var valeur := _italique(D.text(tuile, 16, 72, d.val, 48, C.IVORY, 800, 200), false)
	valeur.name = "EffectifTuileValeur"
	var l := _largeur(str(d.val), 48, false, 800)
	if not str(d.suf).is_empty():
		D.text(tuile, 16 + l + 12, 68, d.suf, 18, C.MUTED, 500, zone.size.x - l - 40, HORIZONTAL_ALIGNMENT_LEFT, true).name = "EffectifTuileDetail"
	var marque_active := _marqueur(tuile, Rect2(0, 0, 6, zone.size.y))
	marque_active.name = "EffectifTuileActive"
	marque_active.visible = _tuile_active(str(d.act))
	_marques_tuiles[str(d.act)] = marque_active
	tuile.pressed.connect(_action_tuile.bind(str(d.act)))
	if d.id == "Aptes":
		tuile.mouse_entered.connect(_montrer_bulle.bind(tuile))
		tuile.mouse_exited.connect(_cacher_bulle)
		tuile.focus_entered.connect(_montrer_bulle.bind(tuile))
		tuile.focus_exited.connect(_cacher_bulle)
		tuile.tree_exiting.connect(_cacher_bulle)

## Le filtre de la tuile est celui qui est actif (marqueur ivoire incliné).
func _tuile_active(action: String) -> bool:
	match action:
		"aptes": return str(state.family) == "Aptes" and str(state.contract) == "Tous"
		"indisponibles": return str(state.family) == "Indisponibles" and str(state.contract) == "Tous"
		"fin": return str(state.contract) == "Fin de saison"
		"niveau": return str(state.sort) == "Niveau" and bool(state.descending) and int(state.get("immersive_tab", 0)) == 0
	return false

func _action_tuile(action: String) -> void:
	_cacher_bulle()
	if action == "niveau":
		state.immersive_tab = 0
		state.sort = "Niveau"; state.descending = true; app.roster_sort = "Niveau"
		state.scroll = 0
		state.focus = "EffectifTuileNiveau"
		app._render(false)
		return
	_appliquer_puce(action)

## Équilibre par poste : effectif, aptes et fins de contrat de la saison pour chaque poste (infobulle autorisée).
func _montrer_bulle(ancre: Control) -> void:
	_cacher_bulle()
	if not is_instance_valid(ancre) or not ancre.is_inside_tree(): return
	var saison := int(app.model.get("meta", {}).get("season", 1))
	var joueurs: Array = app.model.get("squad", [])
	var aptes_total := joueurs.filter(func(p: Dictionary): return U.indisponibilite(p).is_empty()).size()
	var fiche := Panel.new()
	fiche.name = "EquilibrePostes"
	fiche.z_index = 100
	fiche.add_theme_stylebox_override("panel", _plat(Charte.PANNEAU_3, Charte.FILET, 1))
	var hauteur := 118.0 + POSTES.size() * 34.0
	fiche.size = Vector2(720, hauteur) * C.density
	D.text(fiche, 22, 42, "ÉQUILIBRE PAR POSTE", 19, C.IVORY, 700, 400)
	D.text(fiche, 698, 42, "%d aptes sur %d" % [aptes_total, joueurs.size()], 18, C.MUTED, 500, 300, HORIZONTAL_ALIGNMENT_RIGHT, true)
	D.line(fiche, Vector2(22, 60), Vector2(698, 60), Charte.FILET)
	D.text(fiche, 22, 90, "POSTE", 16, C.MUTED, 700, 300)
	for colonne: Array in [["EFF.", 470.0], ["APTES", 590.0], ["FINS", 698.0]]:
		D.text(fiche, float(colonne[1]), 90, colonne[0], 16, C.MUTED, 700, 110, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in POSTES.size():
		var poste: Array = POSTES[i]
		var y := 128.0 + i * 34.0
		var effectif := 0
		var aptes := 0
		var fins := 0
		for p: Variant in joueurs:
			if not p is Dictionary: continue
			var numeros := primary_numbers(p)
			var present := false
			for numero: Variant in poste[1]:
				if int(numero) in numeros: present = true
			if not present: continue
			effectif += 1
			if U.indisponibilite(p).is_empty(): aptes += 1
			if p.get("contractEnd") != null and int(p.contractEnd) <= saison: fins += 1
		if i > 0: D.line(fiche, Vector2(12, y - 24), Vector2(708, y - 24), Charte.FILET)
		D.text(fiche, 22, y, poste[0], 19, C.IVORY, 500, 330, HORIZONTAL_ALIGNMENT_LEFT, true)
		D.text(fiche, 470, y, str(effectif), 19, C.IVORY, 600, 110, HORIZONTAL_ALIGNMENT_RIGHT)
		D.text(fiche, 590, y, str(aptes), 19, C.IVORY if aptes == effectif else C.MUTED, 600, 110, HORIZONTAL_ALIGNMENT_RIGHT)
		D.text(fiche, 698, y, "⧗ %d" % fins if fins > 0 else "—", 19, C.IVORY if fins > 0 else C.FAINT, 600, 110, HORIZONTAL_ALIGNMENT_RIGHT)
	MiniFiche._ignorer_souris(fiche)
	app.add_child(fiche)
	MiniFiche.placer(fiche, ancre, app.get_viewport_rect().size)

func _cacher_bulle() -> void:
	if not is_instance_valid(app): return
	var fiche := app.get_node_or_null("EquilibrePostes")
	if fiche == null: return
	fiche.hide()
	fiche.name = "EquilibrePostesFermee"
	fiche.queue_free()

# ---------------------------------------------------------------- onglets et liens

func _onglets() -> void:
	var courant := int(state.get("immersive_tab", 0))
	var x := 0.0
	for i in VUES.size():
		var largeur := _largeur(VUES[i], 19) + 44.0
		var onglet := _lien(self, Rect2(x, Y_ONGLETS, largeur, 44), VUES[i], func():
			state.immersive_tab = i
			state.sort = ["Poste","Condition","Échéance","Potentiel"][i]
			state.descending = i in [1,3]
			app.roster_sort = state.sort
			app._render(), "RosterTab" + str(i), Charte.IVOIRE if i == courant else Charte.IVOIRE_2, 19.0, HORIZONTAL_ALIGNMENT_CENTER)
		onglet.accessibility_name = "Onglet " + VUES[i] + (" · actif" if i == courant else "")
		# Charte §7.1 : onglet en pilule, même rendu que les onglets de la coque (D.tab_state, sans icône).
		D.tab_state(onglet, Vector2(largeur, 44), i == courant, "")
		onglet.icon = null
		var focus_onglet := _plat(Color.TRANSPARENT, Charte.IVOIRE, 2, Charte.RAYON_PILULE)
		focus_onglet.set_expand_margin_all(2)
		onglet.add_theme_stylebox_override("focus", focus_onglet)
		x += largeur + 8.0
	# À droite : changer d'onglet, comparer, Vestiaire.
	var droite := LARGEUR
	var vestiaire := _lien(self, Rect2(droite - 170, Y_ONGLETS, 170, 44), "Vestiaire →", func(): app._navigate("Vestiaire"), "RosterOpenLocker", Charte.IVOIRE, 19.0, HORIZONTAL_ALIGNMENT_CENTER, true)
	vestiaire.tooltip_text = "Ouvrir le vestiaire"
	droite -= 186.0
	var texte := "Comparer %d/3 →" % app.management_ui.compare.size()
	var largeur_comparer := _largeur("Comparer 3/3 →", 19) + 36.0
	compare = _lien(self, Rect2(droite - largeur_comparer, Y_ONGLETS, largeur_comparer, 44), texte, func(): app.SquadViews.comparison(app), "OpenComparison", Charte.IVOIRE, 19.0, HORIZONTAL_ALIGNMENT_CENTER, true)
	droite -= largeur_comparer + 16.0
	# « Ctrl Tab » (onglet suivant) est dans l'aide « ? » du pied du tableau (21/11).
	if app.model.get("epcrPreparation") is Dictionary:
		var europe := _lien(self, Rect2(droite - 300, Y_ONGLETS, 300, 44), "Préparer l’Europe →", func(): load("res://ui/immersive08/europe_canvas.gd").open(app), "OpenEpcrPreparation", Charte.IVOIRE, 19.0, HORIZONTAL_ALIGNMENT_CENTER, true)
		europe.tooltip_text = "Préparer la campagne européenne"

func _onglet_suivant() -> void:
	var i := (int(state.get("immersive_tab", 0)) + 1) % VUES.size()
	state.immersive_tab = i
	state.sort = ["Poste","Condition","Échéance","Potentiel"][i]
	state.descending = i in [1,3]
	app.roster_sort = state.sort
	app._render()

func _input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo or not is_visible_in_tree(): return
	if touche.keycode == KEY_TAB and touche.ctrl_pressed and not touche.alt_pressed:
		get_viewport().set_input_as_handled()
		_onglet_suivant()
		return
	var recherche := find_child("RosterSearch", true, false) as LineEdit
	if recherche != null and touche.keycode == KEY_SLASH and not touche.ctrl_pressed and not touche.alt_pressed and not (get_viewport().gui_get_focus_owner() is LineEdit):
		get_viewport().set_input_as_handled()
		recherche.grab_focus()

# ---------------------------------------------------------------- puces, recherche, menus

func _compte_puce(id: String) -> int:
	var saison := int(app.model.get("meta", {}).get("season", 1))
	var n := 0
	for p: Variant in app.model.get("squad", []):
		if not p is Dictionary: continue
		match id:
			"tous": n += 1
			"avants": n += 1 if float(p.get("fam", 0)) <= 3 else 0
			"arrieres": n += 1 if float(p.get("fam", 0)) > 3 else 0
			"indisponibles": n += 0 if U.indisponibilite(p).is_empty() else 1
			"aptes": n += 1 if U.indisponibilite(p).is_empty() else 0
			"fin": n += 1 if p.get("contractEnd") != null and int(p.contractEnd) <= saison else 0
			"surveiller": n += 0 if U.watch_reason(p).is_empty() else 1
	return n

func _puce_active(id: String) -> bool:
	var famille := str(state.family)
	if id == "fin": return str(state.contract) == "Fin de saison"
	if id == "tous": return famille == "Tous" and str(state.contract) == "Tous"
	if str(state.contract) != "Tous": return false
	return famille == {"avants": "Avants", "arrieres": "Arrières", "indisponibles": "Indisponibles", "aptes": "Aptes", "surveiller": U.WATCH_FILTER}.get(id, "?")

func _appliquer_puce(id: String) -> void:
	var etait_surveillance: bool = state.family == U.WATCH_FILTER
	state.family = "Tous"
	state.contract = "Tous"
	if id != "fin": state.family = {"avants": "Avants", "arrieres": "Arrières", "indisponibles": "Indisponibles", "aptes": "Aptes", "surveiller": U.WATCH_FILTER}.get(id, "Tous")
	else: state.contract = "Fin de saison"
	app.roster_filter = state.family
	state.scroll = 0
	if etait_surveillance != (state.family == U.WATCH_FILTER):
		state.focus = "RosterChip_" + id
		app._render(false)
	else:
		_refresh(false)
		_styler_puces()

func _styler_puces() -> void:
	for action: String in _marques_tuiles:
		(_marques_tuiles[action] as Node2D).visible = _tuile_active(action)
	for id: String in _puces:
		var puce: Button = _puces[id].bouton
		var active := _puce_active(id)
		# Charte §7.1 : puce de filtre en pilule ; active = aplat crème, texte PANNEAU ; inactive = contour FILET.
		var fond := _plat(Charte.IVOIRE if active else Color.TRANSPARENT, Color.TRANSPARENT if active else Charte.FILET, 0 if active else 1, Charte.RAYON_PILULE)
		fond.content_margin_left = C.px(17)
		puce.add_theme_stylebox_override("normal", fond)
		var survol := _plat(Charte.IVOIRE if active else Charte.PANNEAU_2, Color.TRANSPARENT if active else Charte.IVOIRE_3, 0 if active else 1, Charte.RAYON_PILULE)
		survol.content_margin_left = C.px(17)
		puce.add_theme_stylebox_override("hover", survol)
		var appui := _plat(Charte.IVOIRE if active else Charte.PANNEAU_3, Color.TRANSPARENT if active else Charte.FILET, 0 if active else 1, Charte.RAYON_PILULE)
		appui.content_margin_left = C.px(17)
		puce.add_theme_stylebox_override("pressed", appui)
		var focus := _plat(Color.TRANSPARENT, Charte.IVOIRE, 2, Charte.RAYON_PILULE)
		focus.set_expand_margin_all(2)
		puce.add_theme_stylebox_override("focus", focus)
		for cle in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: puce.add_theme_color_override(cle, Charte.PANNEAU if active else Charte.IVOIRE_2)
		(_puces[id].compte as Label).add_theme_color_override("font_color", Charte.PANNEAU if active else C.MUTED)
		_puces[id].marque.visible = false
		puce.accessibility_name = "%s, %d%s" % [_puces[id].texte, _puces[id].nombre, " · actif" if active else ""]

func _filtres() -> void:
	var y := Y_FILTRES
	var recherche := LineEdit.new()
	recherche.name = "RosterSearch"
	recherche.placeholder_text = "Rechercher un joueur…"
	recherche.text = str(state.search)
	recherche.clear_button_enabled = true
	recherche.accessibility_name = "Rechercher un joueur par nom ou poste"
	recherche.add_theme_font_override("font", C.BODY)
	recherche.add_theme_font_size_override("font_size", maxi(12, C.px(19)))
	recherche.add_theme_color_override("font_color", Charte.IVOIRE)
	recherche.add_theme_color_override("font_placeholder_color", Charte.IVOIRE_2)
	var champ := _plat(Charte.PANNEAU_2, Charte.FILET, 1, Charte.RAYON_PILULE)
	champ.content_margin_left = C.px(46)
	champ.content_margin_right = C.px(60)
	recherche.add_theme_stylebox_override("normal", champ)
	var champ_actif := _plat(Charte.PANNEAU_3, Charte.IVOIRE, 1, Charte.RAYON_PILULE)
	champ_actif.content_margin_left = C.px(46)
	champ_actif.content_margin_right = C.px(60)
	recherche.add_theme_stylebox_override("focus", champ_actif)
	add_child(recherche)
	# Colonne de panneaux dépliée : la rangée tient dans la largeur restante (recherche et menu Poste plus étroits).
	var l_rech := 440.0 if _lt > 2000.0 else 300.0
	var l_poste := 330.0 if _lt > 2000.0 else 250.0
	D.place(recherche, C.reach_rect(Rect2(_x0 + Bandeau.MARGE, y, l_rech, 42)))
	var loupe := C.icon("search", 21, Charte.IVOIRE_2)
	loupe.name = "RosterSearchGlyph"
	recherche.add_child(loupe)
	D.place(loupe, Rect2(14, 10, 21, 21))
	var touche := D.text(recherche, l_rech - 26.0, 28, "/", 19, C.MUTED, 700, 28, HORIZONTAL_ALIGNMENT_RIGHT)
	touche.name = "RosterSearchKey"
	recherche.text_changed.connect(func(valeur: String): state.search = valeur; state.scroll = 0; _refresh(false))
	var x := _x0 + Bandeau.MARGE + l_rech + 24.0
	var definitions := [["tous", "Tous"], ["avants", "Avants"], ["arrieres", "Arrières"], ["indisponibles", "Indisponibles"], ["fin", "Fin de contrat"], ["surveiller", "À surveiller"]]
	if str(state.family) == "Aptes": definitions.append(["aptes", "Aptes"])
	for definition: Array in definitions:
		var id: String = definition[0]
		var texte: String = definition[1]
		var nombre := _compte_puce(id)
		var l_texte := _largeur(texte, 19)
		var l_nombre := _largeur(str(nombre), 19)
		var largeur := 34.0 + l_texte + 12.0 + l_nombre
		var bouton := _lien(self, Rect2(x, y, largeur, 42), texte, _appliquer_puce.bind(id), "RosterChip_" + id, Charte.IVOIRE_2, 19.0)
		bouton.tooltip_text = ""
		var compte := D.text(bouton, 17 + l_texte + 12, 28, str(nombre), 19, C.MUTED, 600, l_nombre + 4)
		compte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var marque := _marqueur(bouton, Rect2(0, 0, 5, 42))
		_puces[id] = {"bouton": bouton, "marque": marque, "compte": compte, "texte": texte, "nombre": nombre}
		x += largeur + 8.0
	_styler_puces()
	# À droite : menu Poste et Filtres & tri (menus déroulants, pas de fenêtre).
	var largeur_filtres := _largeur("Filtres & tri", 19) + 22.0 + 40.0
	var filtres := MenuButton.new()
	filtres.name = "RosterMoreFilters"
	filtres.text = "Filtres & tri"
	filtres.flat = false
	filtres.focus_mode = Control.FOCUS_ALL
	filtres.icon = C.icon_texture("settings", Charte.IVOIRE)
	filtres.expand_icon = true
	C.style_bouton_lien(filtres, 19)
	filtres.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	filtres.add_theme_constant_override("icon_max_width", C.px(22))
	filtres.add_theme_constant_override("h_separation", C.px(8))
	add_child(filtres)
	D.place(filtres, C.reach_rect(Rect2(LARGEUR - Bandeau.MARGE - largeur_filtres, y, largeur_filtres, 42)))
	var menu := filtres.get_popup()
	menu.name = "RosterFiltersMenu"
	menu.about_to_popup.connect(_remplir_menu.bind(menu))
	menu.id_pressed.connect(_choix_menu)
	var poste := OptionButton.new()
	poste.name = "RosterPosition"
	poste.fit_to_longest_item = false
	poste.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	poste.tooltip_text = "Filtrer par poste"
	poste.add_theme_font_override("font", C.BODY)
	poste.add_theme_font_size_override("font_size", maxi(12, C.px(19)))
	for nom: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		poste.add_theme_color_override(nom, Charte.IVOIRE)
	poste.add_theme_stylebox_override("normal", _champ(Charte.PANNEAU_2, Charte.FILET))
	poste.add_theme_stylebox_override("hover", _champ(Charte.PANNEAU_3, Charte.IVOIRE_3))
	poste.add_theme_stylebox_override("pressed", _champ(Charte.PANNEAU_3, Charte.IVOIRE_3))
	poste.add_theme_stylebox_override("focus", _champ(Charte.PANNEAU_2, Charte.IVOIRE))
	var valeurs: Array = app.SquadViews._positions(app.model.get("squad", []))
	for valeur in valeurs: poste.add_item("Poste : " + str(valeur))
	poste.select(maxi(0, valeurs.find(str(state.position))))
	poste.item_selected.connect(func(index: int): state.position = str(valeurs[index]); _refresh(false))
	add_child(poste)
	D.place(poste, C.reach_rect(Rect2(LARGEUR - Bandeau.MARGE - largeur_filtres - 20 - l_poste, y, l_poste, 42)))

func _remplir_menu(menu: PopupMenu) -> void:
	menu.clear()
	menu.add_separator("Disponibilité")
	var i := 0
	for valeur: String in ["Tous", "Disponibles", "Blessés"]:
		menu.add_radio_check_item(valeur, 100 + i)
		menu.set_item_checked(menu.get_item_index(100 + i), str(state.available) == valeur)
		i += 1
	menu.add_separator("Contrat")
	i = 0
	for valeur: String in ["Tous", "Fin de saison", "Sans contrat"]:
		menu.add_radio_check_item(valeur, 200 + i)
		menu.set_item_checked(menu.get_item_index(200 + i), str(state.contract) == valeur)
		i += 1
	menu.add_separator("Groupe")
	menu.add_radio_check_item("Hors groupe seulement", 300)
	menu.set_item_checked(menu.get_item_index(300), str(state.family) == "Hors groupe")
	menu.add_separator("Trier par")
	i = 0
	for valeur: String in TRIS:
		menu.add_radio_check_item(valeur, 400 + i)
		menu.set_item_checked(menu.get_item_index(400 + i), str(state.sort) == valeur)
		i += 1
	menu.add_separator()
	menu.add_item("Changer le sens du tri", 500)
	menu.add_item("Réinitialiser les filtres", 600)

func _choix_menu(id: int) -> void:
	if id >= 100 and id < 103:
		state.available = ["Tous", "Disponibles", "Blessés"][id - 100]
	elif id >= 200 and id < 203:
		state.contract = ["Tous", "Fin de saison", "Sans contrat"][id - 200]
	elif id == 300:
		state.family = "Tous" if str(state.family) == "Hors groupe" else "Hors groupe"
		app.roster_filter = state.family
	elif id >= 400 and id < 400 + TRIS.size():
		state.sort = TRIS[id - 400]
		app.roster_sort = state.sort
		state.descending = state.sort in ["Niveau", "Potentiel", "Condition", "Fatigue", "Minutes", "Moyenne", "Forme"]
	elif id == 500:
		state.descending = not state.descending
	elif id == 600:
		app.management_ui.roster = U.defaults(); app.roster_filter = "Tous"; app.roster_sort = "Poste"
		app._render()
		return
	state.scroll = 0
	_refresh(false)
	_styler_puces()

# ---------------------------------------------------------------- tableau

## Colonnes de la vue : {k : genre de cellule, t : titre, s : clé de tri, x, w : position et largeur (unités), a : alignement}.
func _colonnes(vue: int, etroit: bool, surveillance: bool) -> Array:
	var gauche := HORIZONTAL_ALIGNMENT_LEFT
	var centre := HORIZONTAL_ALIGNMENT_CENTER
	var droite := HORIZONTAL_ALIGNMENT_RIGHT
	var num := {"k": "num", "t": "N°", "s": "Numéro", "x": 14.0, "w": 90.0, "a": gauche}
	var joueur := {"k": "joueur", "t": "JOUEUR", "s": "Nom", "x": 176.0, "w": 360.0 if not etroit else 440.0, "a": gauche}
	var motif := {"k": "motif", "t": "MOTIF DE SURVEILLANCE", "s": "Motif", "x": 1560.0, "w": 330.0, "a": gauche}
	var colonnes: Array = []
	match vue:
		1:
			if etroit:
				colonnes = [num, joueur, {"k": "cond", "t": "CONDITION", "s": "Condition", "x": 700.0, "w": 330.0, "a": gauche}, {"k": "fat", "t": "FAT.", "s": "Fatigue", "x": 1080.0, "w": 120.0, "a": droite}, {"k": "moy", "t": "MOY.", "s": "Moyenne", "x": 1260.0, "w": 130.0, "a": centre}, {"k": "statut", "t": "STATUT", "s": "Statut", "x": 1500.0, "w": 730.0, "a": gauche}]
			else:
				colonnes = [num, joueur, {"k": "poste", "t": "POSTE", "s": "Poste", "x": 560.0, "w": 250.0, "a": gauche}, {"k": "cond", "t": "CONDITION", "s": "Condition", "x": 850.0, "w": 290.0, "a": gauche}, {"k": "fat", "t": "FAT.", "s": "Fatigue", "x": 1170.0, "w": 100.0, "a": droite}, {"k": "min", "t": "MIN.", "s": "Minutes", "x": 1310.0, "w": 110.0, "a": droite}, {"k": "moy", "t": "MOY.", "s": "Moyenne", "x": 1470.0, "w": 110.0, "a": centre}, {"k": "forme", "t": "FORME", "s": "Forme", "x": 1620.0, "w": 260.0, "a": gauche}, {"k": "statut", "t": "STATUT", "s": "Statut", "x": 1890.0, "w": 280.0, "a": gauche}]
		3:
			if etroit:
				colonnes = [num, joueur, {"k": "age", "t": "ÂGE", "s": "Âge", "x": 700.0, "w": 90.0, "a": droite}, {"k": "niveau", "t": "NIV.", "s": "Niveau", "x": 880.0, "w": 100.0, "a": centre}, {"k": "pot", "t": "POT.", "s": "Potentiel", "x": 1060.0, "w": 170.0, "a": centre}, {"k": "min", "t": "MIN.", "s": "Minutes", "x": 1300.0, "w": 130.0, "a": droite}]
			else:
				colonnes = [num, joueur, {"k": "poste", "t": "POSTE", "s": "Poste", "x": 560.0, "w": 250.0, "a": gauche}, {"k": "age", "t": "ÂGE", "s": "Âge", "x": 830.0, "w": 80.0, "a": droite}, {"k": "niveau", "t": "NIV.", "s": "Niveau", "x": 960.0, "w": 80.0, "a": centre}, {"k": "pot", "t": "POT.", "s": "Potentiel", "x": 1060.0, "w": 150.0, "a": centre}, {"k": "min", "t": "MIN.", "s": "Minutes", "x": 1260.0, "w": 110.0, "a": droite}, {"k": "moy", "t": "MOY.", "s": "Moyenne", "x": 1420.0, "w": 110.0, "a": centre}, {"k": "forme", "t": "FORME", "s": "Forme", "x": 1580.0, "w": 260.0, "a": gauche}]
		_:
			if etroit:
				colonnes = [num, joueur, {"k": "poste", "t": "POSTE", "s": "Poste", "x": 640.0, "w": 330.0, "a": gauche}, {"k": "niveau", "t": "NIV.", "s": "Niveau", "x": 1000.0, "w": 100.0, "a": centre}, {"k": "cond", "t": "CONDITION", "s": "Condition", "x": 1150.0, "w": 300.0, "a": gauche}, {"k": "contrat", "t": "FIN DE CONTRAT", "s": "Échéance", "x": 1500.0, "w": 320.0, "a": gauche}, {"k": "statut", "t": "STATUT", "s": "Statut", "x": 1840.0, "w": 390.0, "a": gauche}]
			else:
				# Forme récente dans la vue d'ensemble (choix de Léo du 21/11/2026).
				colonnes = [num, joueur, {"k": "poste", "t": "POSTE", "s": "Poste", "x": 560.0, "w": 230.0, "a": gauche}, {"k": "niveau", "t": "NIV.", "s": "Niveau", "x": 810.0, "w": 80.0, "a": centre}, {"k": "pot", "t": "POT.", "s": "Potentiel", "x": 910.0, "w": 120.0, "a": centre}, {"k": "cond", "t": "CONDITION", "s": "Condition", "x": 1060.0, "w": 250.0, "a": gauche}, {"k": "forme", "t": "FORME", "s": "Forme", "x": 1340.0, "w": 250.0, "a": gauche}, {"k": "age", "t": "ÂGE", "s": "Âge", "x": 1590.0, "w": 60.0, "a": droite}, {"k": "contrat", "t": "FIN DE CONTRAT", "s": "Échéance", "x": 1680.0, "w": 200.0, "a": gauche}, {"k": "statut", "t": "STATUT", "s": "Statut", "x": 1890.0, "w": 280.0, "a": gauche}]
	if surveillance:
		var sans: Array = colonnes.filter(func(c: Dictionary): return c.k not in ["age", "contrat", "forme", "min", "moy"])
		var index := 0
		for i in sans.size():
			if sans[i].k == "statut": index = i
		if etroit: motif = motif.merged({"x": 1500.0, "w": 330.0})
		sans.insert(index, motif)
		if etroit:
			for c: Dictionary in sans:
				if c.k == "statut": c.x = 1860.0; c.w = 310.0
		else:
			for c: Dictionary in sans:
				if c.k == "statut": c.x = 1890.0; c.w = 280.0
		colonnes = sans
	# Poste choisi sur le terrain XV : la colonne POSTE devient « ★ CENTRE » (étoiles au poste + poste du joueur en petit).
	if _poste > 0:
		for i in colonnes.size():
			if colonnes[i].k == "poste":
				colonnes[i] = (colonnes[i] as Dictionary).merged({"k": "etoiles", "t": "★ " + Etoiles.nom_poste(_poste).to_upper(), "s": "Étoiles"}, true)
	return colonnes

func _tableau() -> void:
	var table := Control.new()
	table.name = "ImmersiveRosterTable"
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(table)
	D.place(table, Rect2(_x0, Y_ENTETE + _dy, _lt, HAUT_PAGE - Y_ENTETE - _dy))
	_colonnes_actives = _colonnes(int(state.get("immersive_tab", 0)), _etroit(), state.family == U.WATCH_FILTER)
	if _lt < LARGEUR: _colonnes_actives = _resserrer(_colonnes_actives)
	var entete := Control.new()
	entete.name = "RosterHeader"
	entete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.add_child(entete)
	D.place(entete, Rect2(0, 0, _lt, 36))
	D.line(entete, Vector2(0, 35), Vector2(_lt, 35), Charte.FILET)
	var noms := {"Salaire": "RosterColumnSalary", "Potentiel": "RosterColumnPotential", "Poste": "RosterColumn_POSTE", "Autres postes": "RosterColumnSecondaryPositions", "Moyenne": "RosterColumnNote", "Forme": "RosterColumnForm", "Fatigue": "RosterColumnFatigue"}
	for colonne: Dictionary in _colonnes_actives:
		var cle := str(colonne.s)
		var x: float = colonne.x
		var largeur: float = colonne.w
		var legende := D.text(entete, x, 26, colonne.t, 17, C.MUTED, 700, largeur, colonne.a)
		legende.name = noms.get(cle, "RosterColumn_" + str(colonne.t))
		var tri := Button.new()
		tri.name = "Sort_" + cle
		tri.flat = true
		tri.focus_mode = Control.FOCUS_ALL
		tri.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tri.add_theme_stylebox_override("hover", _plat(Color(Charte.PANNEAU_2, .7)))
		tri.add_theme_stylebox_override("focus", _plat(Color.TRANSPARENT, Charte.IVOIRE, 1))
		entete.add_child(tri)
		# En-tête souligné à la largeur de son texte, derrière la légende (choix de Léo du 21/11/2026).
		var lt := _largeur(str(colonne.t) + " ▼", 17, true, 700) + 26.0
		var x0: float = x - 13.0 if colonne.a == HORIZONTAL_ALIGNMENT_LEFT else (x + largeur - lt + 13.0 if colonne.a == HORIZONTAL_ALIGNMENT_RIGHT else x + largeur / 2.0 - lt / 2.0)
		D.place(tri, C.reach_rect(Rect2(x0, 2, lt, 32)))
		entete.move_child(tri, legende.get_index())
		sort_headers[cle] = {"label": legende, "caption": str(colonne.t), "button": tri}
		tri.pressed.connect(_toggle_sort.bind(cle))
	var defile := ScrollContainer.new()
	defile.name = "SquadScroll"
	defile.follow_focus = true
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	table.add_child(defile)
	D.place(defile, Rect2(0, Y_LIGNES - Y_ENTETE + Bandeau.ECART_LIGNES, _lt, Y_PIED - Y_LIGNES - 8 - _dy - Bandeau.ECART_LIGNES))
	rows = C.v(2)
	rows.add_theme_constant_override("separation", C.px(2))
	rows.name = "ImmersiveRosterRows"
	rows.custom_minimum_size.x = C.px(_lt)
	C.fill(rows)
	defile.add_child(rows)
	count = D.text(table, 0, Y_PIED - Y_ENTETE - _dy + 26, "", 18, C.MUTED, 500, 1000, HORIZONTAL_ALIGNMENT_LEFT, true)
	count.name = "RosterCount"
	# Raccourcis clavier derrière un « ? » (21/11) : plus de ligne de mode d'emploi au pied du tableau.
	var aide := "Raccourcis\n↑↓ : choisir un joueur\nEntrée : fiche complète\nMaj Espace : comparer\n/ : chercher dans le tableau\nCtrl Tab : onglet suivant\nÉchap : Menu\nSurvol d'un nom : aperçu · clic : fiche"
	R.rond(table, _lt - 30, Y_PIED - Y_ENTETE - _dy + 18, aide, "?", "RosterScrollHint", 28)


## Panneaux dépliés : colonnes après « Joueur » resserrées dans la largeur restante.
func _resserrer(colonnes: Array) -> Array:
	var k := (_lt - 560.0) / (LARGEUR - 560.0)
	var sortie: Array = []
	for c: Dictionary in colonnes:
		var d := c.duplicate()
		if float(d.x) >= 540.0:
			d.x = 560.0 + (float(d.x) - 560.0) * k
			d.w = float(d.w) * k
		sortie.append(d)
	return sortie

static func _known_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func primary_numbers(player: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var source: Variant = player.get("primaryPositions",[player.get("primaryPosition")])
	if not source is Array: return result
	for value: Variant in source:
		if not _known_number(value): continue
		var number := int(value)
		if float(value)==float(number) and number>=1 and number<=15 and not number in result: result.append(number)
	result.sort()
	return result

static func primary_caption(player: Dictionary) -> String:
	var numbers := primary_numbers(player)
	if numbers==[1,3]: return "Pilier G/D"
	if numbers==[6,7]: return "Troisième ligne aile"
	if numbers==[8]: return "Troisième ligne centre"
	return str(player.get("pos","—"))

## Libellé de poste qui tient dans la largeur réelle du label (police et taille mesurées) ; sinon sa forme courte.
static func fitted_position(caption: String, label: Label) -> String:
	var font: Font = label.get_theme_font("font")
	var pixels := label.get_theme_font_size("font_size")
	if font == null or font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x <= label.size.x: return caption
	var short := str(preload("res://ui/squad_views.gd").position_label(caption, true))
	return short if not short.is_empty() else caption

static func secondary_numbers(player: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var source: Variant = player.get("secondaryPositions")
	if not source is Array: return result
	var primary := primary_numbers(player)
	for value: Variant in source:
		if not _known_number(value): continue
		var number := int(value)
		if float(value) != float(number) or number < 1 or number > 15 or number in result or number in primary: continue
		result.append(number)
	result.sort()
	return result

static func secondary_caption(player: Dictionary) -> String:
	var roles := secondary_roles(player)
	return "·".join(roles) if not roles.is_empty() else "—"

static func secondary_roles(player: Dictionary) -> Array[String]:
	var labels := {1:"PG",2:"T",3:"PD",4:"2E L",5:"2E L",6:"3E L",7:"3E L",8:"8",9:"DM",10:"DO",11:"AL",12:"C",13:"C",14:"AL",15:"AR"}
	var found: Array[String] = []
	for number: int in secondary_numbers(player):
		var role: String = labels[number]
		if not role in found: found.append(role)
	var result: Array[String] = []
	for role: String in ["PG","PD","T","2E L","3E L","8","DM","DO","C","AL","AR"]:
		if role in found: result.append(role)
	return result

static func secondary_tooltip(player: Dictionary, _model: Dictionary) -> String:
	var result: Array[String] = []
	var names := {"PG":"Pilier gauche", "PD":"Pilier droit", "T":"Talonneur", "2E L":"Deuxième ligne (4–5)", "3E L":"Troisième ligne aile (6–7)", "8":"Troisième ligne centre", "DM":"Demi de mêlée", "DO":"Demi d’ouverture", "C":"Centre (12–13)", "AL":"Ailier (11 et 14)", "AR":"Arrière"}
	for role: String in secondary_roles(player): result.append(role+" · "+str(names[role]))
	return "\n".join(result) if not result.is_empty() else "—"

static func _compare_secondary(left: Array, right: Array) -> int:
	for index in mini(left.size(),right.size()):
		if int(left[index]) != int(right[index]): return -1 if int(left[index]) < int(right[index]) else 1
	if left.size() == right.size(): return 0
	return -1 if left.size() < right.size() else 1

static func sort_value(player: Dictionary, key: String) -> Variant:
	if key == "Étoiles":
		# Étoiles au poste choisi, puis niveau à égalité d'étoiles ; inconnues en dernier.
		var e := float(player.get("etoilesPoste", -1.0))
		if e < 0.0: return null
		return e * 1000.0 + (float(player.rating) if _known_number(player.get("rating")) else 0.0)
	if key in ["Niveau","Potentiel"]: return G.knowledge_sort_value(player,"rating" if key == "Niveau" else "potential",true)
	if key == "Autres postes":
		var order: Array[int] = []
		var roles: Array = ["PG","PD","T","2E L","3E L","8","DM","DO","C","AL","AR"]
		for role: String in secondary_roles(player): order.append(roles.find(role))
		return order if not order.is_empty() else null
	if key == "Statut":
		if _known_number(player.get("injury")) and float(player.injury) > 0: return U.fold("Blessé")
		var status: Variant = player.get("status")
		return U.fold(status.strip_edges()) if status is String and not status.strip_edges().is_empty() and status != "—" else null
	if key in ["Moyenne","Forme"]:
		var notes: Variant = player.get("matchNotes")
		if notes is Dictionary:
			if key == "Moyenne": return notes.get("moyenne")
			var forme: Array = notes.get("forme", [])
			if forme.is_empty(): return null
			var somme := 0.0
			for v: Variant in forme: somme += float(v)
			return somme / forme.size()
		return null
	if key == "Motif":
		var source := player.duplicate()
		if not _known_number(source.get("condition")): source.condition = 100
		if not _known_number(source.get("physicalLoad")): source.physicalLoad = 0
		var reason := U.watch_reason(source)
		return U.fold(reason) if not reason.is_empty() else null
	var field: String = {"Numéro":"shirtNumber","Poste":"pos","Nom":"name","Niveau":"rating","Potentiel":"potential","Condition":"condition","Âge":"age","Salaire":"salary","Échéance":"contractEnd","Fatigue":"physicalLoad","Minutes":"minutes"}.get(key,"pos")
	var value: Variant = primary_caption(player) if key == "Poste" else player.get(field)
	if key in ["Nom","Poste"]:
		if not value is String or value.strip_edges().is_empty() or value.strip_edges() in ["—","-"]: return null
		var text := U.fold(value.strip_edges())
		# Le tri de poste conserve les familles rugby du tableau, puis le poste.
		if key == "Poste" and _known_number(player.get("fam")): return "%03d/" % int(player.fam) + text
		return text
	return value if _known_number(value) else null

static func ordered_players(source: Array, reading: Dictionary, season: int) -> Array:
	# Réutiliser les filtres sans subir un premier tri numérique sur un inconnu.
	var filtering := reading.duplicate()
	filtering.sort = "Nom"
	filtering.descending = false
	var result := U.players(source,filtering,season)
	var key := str(reading.get("sort","Poste"))
	var descending: bool = reading.get("descending",false)
	result.sort_custom(func(a: Dictionary,b: Dictionary):
		var left: Variant = sort_value(a,key)
		var right: Variant = sort_value(b,key)
		if left == null and right == null: return str(a.get("id","")) < str(b.get("id",""))
		if left == null: return false
		if right == null: return true
		if key == "Autres postes":
			var comparison := _compare_secondary(left,right)
			if comparison == 0: return str(a.get("id","")) < str(b.get("id",""))
			return comparison > 0 if descending else comparison < 0
		if left == right: return str(a.get("id","")) < str(b.get("id",""))
		return left > right if descending else left < right)
	return result

func _players() -> Array:
	# Les notes de match (clubLife.matchNotes) accompagnent chaque joueur pour le tri.
	var source: Array = []
	for player: Variant in app.model.get("squad",[]):
		if player is Dictionary:
			var copie: Dictionary = player.duplicate()
			copie.matchNotes = Notes.joueur(app.model,str(player.get("id","")))
			copie.etoilesPoste = Etoiles.etoiles(player, _poste)
			source.append(copie)
	source = Listes.filtrer_groupe(source, str(state.get("poste_groupe", "")))
	return ordered_players(source,state,int(app.model.meta.get("season",1)))


func _toggle_sort(key: String) -> void:
	state.descending = not state.descending if state.sort == key else key in ["Niveau","Potentiel","Condition","Fatigue","Minutes","Moyenne","Forme","Étoiles"]
	state.sort = key
	app.roster_sort = key
	state.scroll = 0
	state.focus = "Sort_"+key
	var scroll := find_child("SquadScroll",true,false) as ScrollContainer
	if scroll != null: scroll.scroll_vertical = 0
	_refresh(false)
	var button := find_child("Sort_"+key,true,false) as Button
	if button != null: button.grab_focus()

func _sort_header_state() -> void:
	for key: String in sort_headers:
		var header: Dictionary = sort_headers[key]
		var active: bool = state.sort == key
		var direction := "décroissant" if state.descending else "croissant"
		header.label.text = header.caption + (" ▼" if state.descending else " ▲") if active else header.caption
		header.label.add_theme_color_override("font_color",C.IVORY if active else C.MUTED)
		var detail := "par famille puis poste" if key == "Poste" else "par "+key
		header.button.tooltip_text = "Tri "+direction+" "+detail+" · cliquer pour inverser" if active else "Trier "+detail+" · valeurs inconnues en dernier"
		if key == "Niveau": header.button.tooltip_text += "\nNiveau global du joueur / 100."
		if key == "Moyenne": header.button.tooltip_text += "\nMoyenne de la saison en cours (notes de match de 1 à 10)."
		if key == "Forme": header.button.tooltip_text += "\nCinq dernières notes de match, la plus récente à droite."
		header.button.accessibility_name = str(header.caption)+" · "+("tri "+direction if active else "trier")
		Listes.styler_entete(header.button, header.label, active, state.descending, header.caption)

func _refresh(reveal: bool) -> void:
	_sort_header_state()
	for child in rows.get_children():rows.remove_child(child);child.queue_free()
	var players := _players()
	if app.selected_player.is_empty() and not players.is_empty():app.selected_player=str(players[0].id)
	state.visible_player=app.selected_player
	count.text="%d / %d joueurs" % [players.size(),app.model.get("squad",[]).size()]
	_totaux(players)
	if compare != null: compare.text="Comparer %d/3 →" % app.management_ui.compare.size()
	# Construction progressive : les lignes visibles sont créées tout de suite, le reste sur les
	# images suivantes (60 lignes d'un coup coûtaient plus de 100 ms avant la première image).
	_generation += 1
	_group = ""
	var built := mini(players.size(),FIRST_ROWS)
	if reveal:
		for i in players.size():
			if str(players[i].id) == app.selected_player:
				built = maxi(built,mini(players.size(),i+VISIBLE_MARGIN))
				break
	_build_rows(players,0,built)
	if built < players.size(): _build_remaining(players,built,_generation)
	if players.is_empty():
		var nobody_watched: bool = state.family==U.WATCH_FILTER and str(state.search).strip_edges().is_empty()
		var empty:=C.wrap("Personne à surveiller cette semaine." if nobody_watched else "Aucun joueur ne correspond. Modifie les filtres ou réinitialise la recherche.",22,C.IVORY if nobody_watched else C.MUTED)
		empty.name = "RosterEmpty"
		rows.add_child(empty)
	if reveal:
		var scroll := find_child("SquadScroll",true,false) as ScrollContainer
		for row: Control in rows.get_children():
			if row.get_meta("player_id","") == app.selected_player and scroll != null:
				scroll.ensure_control_visible.call_deferred(row)
				break

func _build_rows(players: Array,from: int,to: int) -> void:
	for i in range(from,to):
		var player:Dictionary=players[i]
		var group := "AVANTS" if float(player.get("fam",0))<=3 else "ARRIÈRES"
		if state.sort=="Poste" and group!=_group:
			_group=group
			_bandeau_groupe(players, group)
		_row(player,i)

func _bandeau_groupe(players: Array, group: String) -> void:
	var banner:=Control.new()
	banner.name = "RosterGroup" + ("Avants" if group == "AVANTS" else "Arrieres")
	banner.custom_minimum_size=Vector2(C.px(_lt),C.px(C.reach(GROUP_HEIGHT)))
	rows.add_child(banner)
	var source: Array = players if state.family==U.WATCH_FILTER else app.model.get("squad",[])
	var membres: Array = source.filter(func(p:Dictionary):return (float(p.get("fam",0))<=3)==(group=="AVANTS"))
	var titulaires: Array[int] = []
	for p: Dictionary in membres:
		if p.get("shirtNumber") is int or p.get("shirtNumber") is float:
			if int(p.shirtNumber) <= 15: titulaires.append(int(p.shirtNumber))
	# Bandeau de groupe : « AVANTS 19 » (chiffre de tuile) et un « i » pour les numéros de la feuille (21/11).
	var h := C.reach(GROUP_HEIGHT)
	var filtre := "avants" if group == "AVANTS" else "arrieres"
	var ouvrir := Button.new()
	ouvrir.name = "RosterGroupFiltre" + ("Avants" if group == "AVANTS" else "Arrieres")
	ouvrir.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ouvrir.focus_mode = Control.FOCUS_NONE
	ouvrir.tooltip_text = "Ne garder que les " + group.to_lower()
	ouvrir.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	ouvrir.add_theme_stylebox_override("hover", _plat(Color(Charte.IVOIRE, .06)))
	ouvrir.add_theme_stylebox_override("pressed", _plat(Color(Charte.IVOIRE, .10)))
	banner.add_child(ouvrir)
	ouvrir.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ouvrir.pressed.connect(func(): _appliquer_puce(filtre))
	var titre := _italique(D.text(banner, 14, h / 2.0 + 8, group, 22, C.IVORY, 700, 200), false)
	var l := _largeur(group, 22, false, 700)
	var chiffre := _italique(D.text(banner, 14 + l + 14, h / 2.0 + 9, str(membres.size()), 26, C.IVORY, 800, 80), false)
	chiffre.name = "RosterGroupNombre"
	chiffre.tooltip_text = "%d joueur%s" % [membres.size(), "s" if membres.size() > 1 else ""]
	if not titulaires.is_empty():
		var lc := _largeur(str(membres.size()), 26, false, 800)
		R.rond(banner, 14 + l + 14 + lc + 14, h / 2.0, "N° %d à %d · ordre de la feuille" % [titulaires.min(), titulaires.max()], "i", "RosterGroupNumeros", 22)
	titre.name = "RosterGroupTitre"

func _build_remaining(players: Array,from: int,generation: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var next := from
	while next < players.size():
		await tree.process_frame
		if not is_instance_valid(self) or generation != _generation or not is_inside_tree(): return
		var upto := mini(players.size(),next+ROWS_PER_FRAME)
		_build_rows(players,next,upto)
		next = upto
	# Le défilement mémorisé n'existait pas tant que la liste était incomplète.
	var scroll := find_child("SquadScroll",true,false) as ScrollContainer
	if scroll != null and int(state.get("scroll",0)) > 0:
		await tree.process_frame
		if is_instance_valid(self) and generation == _generation and is_instance_valid(scroll): scroll.scroll_vertical = int(state.scroll)

# ---------------------------------------------------------------- lignes

## « 12/01 » : date du jour (état de la carrière) plus `jours`, ou "" si la date du jour est inconnue.
func _date_retour(jours: int) -> String:
	var meta: Dictionary = app.model.get("meta", {})
	var aujourdhui := str(meta.get("calendarToday", meta.get("date", "")))
	if aujourdhui.length() < 10: return ""
	var instant := Time.get_unix_time_from_datetime_string(aujourdhui.substr(0, 10) + "T00:00:00")
	if instant <= 0: return ""
	var date := Time.get_datetime_dict_from_unix_time(int(instant) + jours * 86400)
	return "%02d/%02d" % [date.day, date.month]

## Statut écrit de la ligne : {t : texte, c : couleur}. Blessé, suspendu et en sélection disent la raison et le retour connu.
func _statut(player: Dictionary) -> Dictionary:
	match U.indisponibilite(player):
		"blesse":
			var semaines := ceili(float(player.get("injury", 0)))
			var libelle := str(preload("res://ui/club_mail.gd").injury_label(app.model, player))
			var precision := "" if libelle == "Blessure" or libelle.length() > 12 else " (" + libelle.to_lower() + ")"
			var retour := _date_retour(semaines * 7)
			return {"t": "✚ Blessé" + precision + " · " + ("retour " + retour if not retour.is_empty() else "retour dans %d sem." % semaines), "c": C.ALERT, "pastille": "✚ " + (retour if not retour.is_empty() else "%d sem." % semaines)}
		"suspendu":
			var matchs := int(player.get("suspension", 1))
			return {"t": "! Suspendu (%d match%s)" % [matchs, "s" if matchs > 1 else ""], "c": C.ALERT}
		"selection":
			var retour := ""
			for sortie: Variant in app.model.get("international", {}).get("availability", {}).get("players", []):
				if sortie is Dictionary and str(sortie.get("id", "")) == str(player.get("id", "")) and str(sortie.get("returnDate", "")).length() >= 10:
					var jour := str(sortie.returnDate)
					retour = " · retour %s/%s" % [jour.substr(8, 2), jour.substr(5, 2)]
			return {"t": "◇ En sélection" + retour, "c": C.IVORY}
	var numero: Variant = player.get("shirtNumber")
	var statut := str(player.get("status", ""))
	if statut in ["Titulaire", "Remplaçant"]: return {"t": statut, "c": C.IVORY if statut == "Titulaire" else C.MUTED}
	if numero is int or numero is float: return {"t": "Titulaire" if int(numero) <= 15 else "Remplaçant", "c": C.IVORY if int(numero) <= 15 else C.MUTED}
	return {"t": "Hors groupe", "c": C.MUTED}

func _ovale(row: Control, zone: Rect2, plein: bool) -> void:
	var forme := Panel.new()
	forme.name = "RosterNumeroOvale"
	var style := StyleBoxFlat.new()
	style.bg_color = Charte.IVOIRE if plein else Color.TRANSPARENT
	style.border_color = Charte.IVOIRE
	style.set_border_width_all(0 if plein else maxi(1, C.px(2)))
	style.set_corner_radius_all(maxi(1, C.px(zone.size.y)))
	forme.add_theme_stylebox_override("panel", style)
	forme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(forme)
	D.place(forme, zone)

func _row(player:Dictionary,index:int) -> void:
	var id := str(player.id)
	var h := float(C.reach(ROW_HEIGHT))
	var base := h / 2.0 + 7.0
	var selectionne: bool = id == app.selected_player
	var statut := _statut(player)
	var row:=Button.new()
	row.name="SquadPlayer"+id.replace(":","_")
	row.set_meta("player_id",id)
	row.set_meta("index",index)
	row.custom_minimum_size=Vector2(C.px(_lt),C.px(h))
	row.clip_contents = true
	row.focus_mode = Control.FOCUS_ALL
	row.accessibility_name = "%s · %s · %s · ouvrir la fiche" % [str(player.name), primary_caption(player), str(statut.t)]
	load("res://ui/survol_ligne.gd").appliquer(row, selectionne, Color.TRANSPARENT, app.accent)
	rows.add_child(row)
	var filet := Panel.new()
	filet.name = "RosterFilet"
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filet.add_theme_stylebox_override("panel", _plat(Charte.FILET, Color.TRANSPARENT, 0, 0))
	row.add_child(filet)
	filet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	filet.offset_top = -1.0
	row.pressed.connect(func(): _ouvrir(id, ""))
	row.focus_entered.connect(func(): if not _restaurant: _selectionner(id))
	row.gui_input.connect(_row_key.bind(row))
	var reason := U.watch_reason(player) if state.family==U.WATCH_FILTER else ""
	if not reason.is_empty(): row.accessibility_name += " · " + reason
	var notes := Notes.joueur(app.model,id)
	for colonne: Dictionary in _colonnes_actives:
		var x: float = colonne.x
		var l: float = colonne.w
		var a: HorizontalAlignment = colonne.a
		match str(colonne.k):
			"num":
				var numero: Variant = player.get("shirtNumber")
				if numero is int or numero is float:
					_ovale(row, Rect2(x, h / 2.0 - 8, 28, 16), int(numero) <= 15)
					D.text(row, x + 44, base, G.n(numero), 20, C.IVORY, 600, 44).name = "RosterNumero"
				else:
					D.text(row, x + 4, base, "—", 20, C.FAINT, 600, 30).name = "RosterNumero"
			"joueur": _cellule_joueur(row, player, index, h, base)
			"poste":
				var poste := D.text(row,x,base,primary_caption(player),19,C.IVORY,500,l,HORIZONTAL_ALIGNMENT_LEFT,true)
				poste.name = "RosterPrimaryPosition"
				var fitted := fitted_position(primary_caption(player), poste)
				if fitted != poste.text: poste.text = fitted
				poste.mouse_filter = Control.MOUSE_FILTER_PASS
				var principaux: Array[String] = []
				for numero: int in primary_numbers(player): principaux.append(str(numero))
				poste.tooltip_text = "Poste principal · %s · %s" % ["·".join(principaux),primary_caption(player)] if not principaux.is_empty() else primary_caption(player)
				if not secondary_numbers(player).is_empty(): poste.tooltip_text += "\nAutres postes · " + secondary_tooltip(player,app.model).replace("\n"," ; ")
			"etoiles":
				var valeur := float(player.get("etoilesPoste", -1.0))
				if valeur < 0.0:
					D.text(row, x, base, "—", 19, C.FAINT, 500, 40).name = "RosterEtoilesInconnues"
				else:
					var etoiles := CarteSurvol.poser_etoiles(row, Rect2(x, h / 2.0 - 12, 124, 24), valeur, "RosterEtoiles")
					etoiles.tooltip_text = ("%s étoiles · %s" % [str(valeur), Etoiles.nom_poste(_poste)]).replace(".", ",")
					etoiles.mouse_filter = Control.MOUSE_FILTER_PASS
				var court := Etoiles.abrege(player)
				D.text(row, x + 136, base, court if not court.is_empty() else primary_caption(player), 17, C.MUTED, 600, maxf(20.0, l - 136), HORIZONTAL_ALIGNMENT_LEFT, true).name = "RosterPostePrincipal"
			"autres":
				var autres := D.text(row,x,base,secondary_caption(player),18,C.MUTED,600,l,HORIZONTAL_ALIGNMENT_LEFT,true)
				autres.name = "RosterSecondaryPositions"
				autres.mouse_filter = Control.MOUSE_FILTER_PASS
				autres.tooltip_text = secondary_tooltip(player,app.model)
				autres.accessibility_name = "Autres postes · "+autres.tooltip_text.replace("\n"," ; ")
				row.accessibility_name += " · autres postes " + autres.tooltip_text.replace("\n"," ; ")
			"niveau":
				var rating: Variant = player.get("rating")
				var niveau := D.text(row,x,base,G.rating_text(player,true),21,Charte.couleur_attribut(rating),700,l,a)
				niveau.name = "RosterLevel"
			"pot":
				var potentiel := D.text(row,x,base,G.potential_text(player),19,C.MUTED,500,l,a,true)
				potentiel.name = "RosterPotential"
				potentiel.mouse_filter = Control.MOUSE_FILTER_PASS
				potentiel.tooltip_text = G.potential_tooltip(player)
			"cond":
				var condition: float = float(player.get("condition",0))
				var ton := C.MINT if condition >= 85 else (C.AMBER if condition >= 60 else C.ALERT)
				D.bar(row,Rect2(x,h/2.0-3,l-110,6),condition,ton)
				var repere := D.rect(row,Rect2(x + (l - 110) * .8 - 1,h/2.0-8,2,16),Charte.IVOIRE_2)
				repere.name = "RosterCondition80"
				D.text(row,x+l,base,"%d %%" % condition,19,C.IVORY,600,100,HORIZONTAL_ALIGNMENT_RIGHT,true).name = "RosterCondition"
			"fat":
				var fatigue: float = float(player.get("physicalLoad",0))
				D.text(row,x+l,base,G.n(fatigue),19,C.IVORY if fatigue>50 else C.MUTED,500,l,HORIZONTAL_ALIGNMENT_RIGHT,true)
			"age":
				D.text(row,x+l,base,G.n(player.get("age","—")),19,C.MUTED,500,l,HORIZONTAL_ALIGNMENT_RIGHT,true)
			"min":
				D.text(row,x+l,base,G.n(player.get("minutes",0)),19,C.MUTED,500,l,HORIZONTAL_ALIGNMENT_RIGHT,true)
			"contrat":
				var echeance: String = _echeance(player)
				if echeance.contains("⧗"):
					# Fin de saison : pastille sablier + année (21/11) ; la précision dans l'infobulle.
					var annee := echeance.get_slice(" ⧗", 0)
					R.pastille(row, x, base, "⧗ " + annee, R.ORANGE, "", "RosterContractEnd", 21).tooltip_text = annee + " · fin de contrat en fin de saison"
				else:
					D.text(row,x,base,echeance,19,C.MUTED,500,l,HORIZONTAL_ALIGNMENT_LEFT,true).name = "RosterContractEnd"
				_lien_lecture(row, Rect2(x - 6, 2, l + 8, h - 4), player, "contract", "SquadOpenContract_")
			"moy":
				var moyenne: Variant = notes.get("moyenne")
				if moyenne != null:
					var pastille := Notes.pastille(row,Rect2(x + l / 2.0 - 26,5,52,h-10),float(moyenne),0.52)
					pastille.name = "RosterNoteAverage"
					pastille.tooltip_text = "Moyenne de la saison en cours : %s sur %d match%s" % [Notes.texte_note(moyenne),int(notes.get("matchs",0)),"s" if int(notes.get("matchs",0))>1 else ""]
					pastille.mouse_filter = Control.MOUSE_FILTER_PASS
				else:
					D.text(row,x + l / 2.0,base,"—",19,C.FAINT,500,52,HORIZONTAL_ALIGNMENT_CENTER,true).name = "RosterNoteAverage"
			"forme":
				# Cases ramenées dans la colonne quand les panneaux latéraux la resserrent.
				Listes.dessiner_forme(self, row, Rect2(x, 1, l, h - 2), notes, str(player.name), minf(44.0, (l - 24.0) / 5.0)).name = "RosterForm"
			"motif":
				D.text(row,x,base,reason,19,C.IVORY,600,l,HORIZONTAL_ALIGNMENT_LEFT,true).name="RosterWatchReason"
			"statut":
				if statut.has("pastille"):
					# Blessé : pastille croix + date de retour ; le motif complet dans l'infobulle.
					var pastille_statut := R.pastille(row, x, base, str(statut.pastille), R.ROUGE, "", "RosterStatut", 21)
					pastille_statut.tooltip_text = str(statut.t)
				else:
					var texte := D.text(row,x,base,str(statut.t),19,statut.c,600 if statut.c != C.MUTED else 500,l,HORIZONTAL_ALIGNMENT_LEFT,true)
					texte.name = "RosterStatut"
	var comparer_ligne := Button.new()
	comparer_ligne.name = "RosterCompare_" + id.validate_node_name()
	comparer_ligne.set_meta("player_id", id)
	comparer_ligne.focus_mode = Control.FOCUS_ALL
	C.style_bouton_lien(comparer_ligne, 19)
	comparer_ligne.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(comparer_ligne)
	D.place(comparer_ligne, C.reach_rect(Rect2(_lt - 78, 2, 70, h - 4)))
	comparer_ligne.pressed.connect(func(): _basculer_comparaison(id))
	_etat_comparaison(comparer_ligne, id, false)
	row.mouse_entered.connect(func(): _etat_comparaison(comparer_ligne, id, true))
	row.mouse_exited.connect(func(): _etat_comparaison(comparer_ligne, id, row.get_global_rect().has_point(row.get_global_mouse_position())))
	comparer_ligne.focus_entered.connect(func(): _etat_comparaison(comparer_ligne, id, true))
	comparer_ligne.focus_exited.connect(func(): _etat_comparaison(comparer_ligne, id, false))

## Repère du comparateur au bout de la ligne : « + » au survol, A / B / C une fois ajouté (jamais la couleur seule).
func _etat_comparaison(bouton: Button, id: String, survol: bool) -> void:
	var repere := _repere_comparaison(id)
	bouton.text = repere if not repere.is_empty() else "+"
	bouton.visible = not repere.is_empty() or survol
	bouton.tooltip_text = ("Retirer du comparateur (%s)" % repere) if not repere.is_empty() else "Ajouter au comparateur"
	bouton.accessibility_name = bouton.tooltip_text + " · " + id

func _basculer_comparaison(id: String) -> void:
	var memo: Array = app.management_ui.compare
	if id in memo: memo.erase(id)
	else:
		if memo.size() >= 3: memo.remove_at(0)
		memo.append(id)
	if compare != null: compare.text = "Comparer %d/3 →" % memo.size()
	for ligne: Node in rows.get_children():
		var pid := str(ligne.get_meta("player_id", ""))
		var b := ligne.get_node_or_null("RosterCompare_" + pid.validate_node_name()) as Button
		if b != null: _etat_comparaison(b, pid, false)

func _echeance(player: Dictionary) -> String:
	var fin: Variant = player.get("contractEnd")
	var texte := G.contract_year(fin)
	if texte != "—" and int(fin) <= int(app.model.get("meta", {}).get("season", 1)): texte += " ⧗ fin de saison"
	return texte

func _repere_comparaison(id: String) -> String:
	var memo: Array = app.management_ui.compare
	var rang := memo.find(id)
	return "" if rang < 0 else ["A", "B", "C"][rang]

## Portrait, drapeau, nom (souligné au survol) et « i » : le nom ouvre la fiche, le survol montre la carte joueur.
func _cellule_joueur(row: Control, player: Dictionary, index: int, h: float, base: float) -> void:
	var id := str(player.id)
	var portrait: Control = G.portrait_lazy(int(player.get("portraitIndex", 0)), C.px(31), player) if not id.is_empty() else C.photo("player-%02d" % posmod(int(player.get("portraitIndex", index)), 16))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	D.place(portrait, Rect2(96, (h - 30) / 2.0, 31, 30))
	var faits: Dictionary = player.get("playerFacts", {}) if player.get("playerFacts") is Dictionary else {}
	var code := str(faits.get("flagCode", "")) if faits.get("flagCode") is String else ""
	var drapeau := Identity.flag_texture(code)
	if drapeau != null:
		var image := TextureRect.new()
		image.name = "RosterDrapeau"
		image.texture = drapeau
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.tooltip_text = str(faits.get("nationality", ""))
		row.add_child(image)
		D.place(image, Rect2(138, h / 2.0 - 9, 28, 18))
	var sale: Variant = player.get("sale")
	var en_vente: bool = sale is Dictionary and bool(sale.get("listed", false)) and not sale.get("pending") is Dictionary
	var largeur_max := 190.0 if en_vente else 340.0
	var nom := D.text(row, 176, base, player.name, 20, C.IVORY, 600, largeur_max, HORIZONTAL_ALIGNMENT_LEFT, true)
	nom.name = "RosterNom"
	var largeur_nom := minf(largeur_max, _largeur(str(player.name), 20))
	var soulignement := ColorRect.new()
	soulignement.name = "RosterNomSouligne"
	soulignement.color = Charte.IVOIRE
	soulignement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soulignement.visible = false
	row.add_child(soulignement)
	D.place(soulignement, Rect2(176, base + 4, largeur_nom, 1.5))
	var lien := _lien_lecture(row, Rect2(96, 2, 80 + largeur_nom + 12, h - 4), player, "", "SquadOpenPlayer_")
	lien.mouse_entered.connect(func(): soulignement.visible = true)
	lien.mouse_exited.connect(func(): soulignement.visible = false)
	var taille_i := maxf(20.0, ceilf(16.0 / C.density))
	CarteSurvol.icone(app, row, Rect2(176 + largeur_nom + 12, (h - taille_i) / 2.0, taille_i, taille_i), id, "squad")
	var apres := 176 + largeur_nom + 12 + taille_i + 10
	if en_vente:
		_pastille_en_vente(row, player, apres, base, h)
		apres += R.largeur("En vente", 19) + 2.0 + 12.0 + 21.0 + 7.0 + 12.0 + 6.0
	# Badges courts derrière le nom (Offre, Départ, Jeune), dans la largeur de la colonne JOUEUR.
	Etoiles.poser_badges(app, row, player, apres, base, 548.0 - apres)

## Pastille « En vente » (bleu de la charte + pièces + mot) : le clic ouvre la fiche sur l'onglet Contrat (offres, retrait du marché).
func _pastille_en_vente(row: Control, player: Dictionary, x: float, base: float, h: float) -> void:
	var id := str(player.id)
	var fond := R.pastille(row, x, base, "En vente", R.BLEU, "money", "RosterEnVente", 19)
	var zone := Rect2(x, base - 19.0 * .78 - 6.5, R.largeur("En vente", 19) + 2.0 + 12.0 + 21.0 + 7.0 + 12.0, 32.0)
	var lien := _lien_lecture(row, zone, player, "contract", "RosterEnVenteLien_")
	lien.tooltip_text = "En vente · " + Sales.status(player)
	lien.accessibility_name = "En vente · ouvrir les offres · " + str(player.name)
	fond.tooltip_text = ""

func _lien_lecture(parent: Control, zone: Rect2, player: Dictionary, section: String, prefixe: String) -> Button:
	var id := str(player.id)
	var link := Button.new()
	link.name = prefixe + id.validate_node_name()
	link.custom_minimum_size = Vector2.ZERO
	link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	link.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	link.add_theme_stylebox_override("hover", _plat(Color(Charte.IVOIRE, .07)))
	link.add_theme_stylebox_override("pressed", _plat(Color(Charte.IVOIRE, .12)))
	link.add_theme_stylebox_override("focus", _plat(Color.TRANSPARENT, Charte.IVOIRE, 1))
	link.accessibility_name = ("Consulter le contrat · " if section == "contract" else "Consulter la fiche · ") + str(player.name)
	link.tooltip_text = link.accessibility_name if section == "contract" else ""
	link.set_meta("entity_kind", "player")
	link.set_meta("entity_id", id)
	link.set_meta("entity_section", section)
	link.pressed.connect(func(): _ouvrir(id, section))
	parent.add_child(link)
	D.place(link, zone)
	# Le nom et le portrait : survol (ou focus + I) = carte joueur, clic = fiche complète.
	if section.is_empty(): CarteSurvol.lier(app, link, id, "squad")
	return link

func _ouvrir(id: String, section: String) -> void:
	app.selected_player = id
	app.navigation_controller.open_entity({"kind":"player", "id":id, "section":section})

## Le focus clavier (ou le retour de fiche) change le joueur courant sans reconstruire la liste ni colorer la ligne.
func _selectionner(id: String) -> void:
	if app.selected_player == id: return
	app.selected_player = id
	state.visible_player = id
	for ligne: Node in rows.get_children():
		if ligne is Button and ligne.has_meta("player_id"):
			var choisi: bool = ligne.get_meta("player_id") == id
			load("res://ui/survol_ligne.gd").appliquer(ligne, choisi, Color.TRANSPARENT, app.accent)
	app._observe_navigation()

func _row_key(event: InputEvent, current: Button) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed: return
	if event.keycode == KEY_SPACE and event.shift_pressed:
		get_viewport().set_input_as_handled()
		_basculer_comparaison(str(current.get_meta("player_id", "")))
		return
	if event.keycode not in [KEY_HOME,KEY_END,KEY_PAGEUP,KEY_PAGEDOWN]: return
	var items := rows.get_children().filter(func(node: Node): return node is Button and node.has_meta("player_id"))
	if items.is_empty(): return
	var index := items.find(current)
	var scroll := find_child("SquadScroll",true,false) as ScrollContainer
	var stride := maxi(1,floori(scroll.size.y / float(C.px(C.reach(ROW_HEIGHT))+C.px(2)))-1)
	var target := 0 if event.keycode == KEY_HOME else items.size()-1 if event.keycode == KEY_END else clampi(index+(-stride if event.keycode == KEY_PAGEUP else stride),0,items.size()-1)
	get_viewport().set_input_as_handled()
	items[target].grab_focus()
	scroll.ensure_control_visible(items[target])
	state.scroll = scroll.scroll_vertical


# ---------------------------------------------------------------- pastilles de poste et tuiles des totaux

func _choisir_groupe(id: String) -> void:
	state.poste_groupe = id
	state.scroll = 0
	state.focus = "PostePastille_" + (id if not id.is_empty() else "tous")
	app._render(false)

## Poste des étoiles (clic sur un maillot du terrain XV ; 0 = ✕) : la liste se classe par étoiles à ce poste ; sans
## poste, retour au tri par poste.
func choisir_etoiles(numero: int) -> void:
	state.etoiles_poste = numero
	state.scroll = 0
	if numero > 0:
		state.sort = "Étoiles"; state.descending = true; app.roster_sort = "Étoiles"
	elif str(state.sort) == "Étoiles":
		state.sort = "Poste"; state.descending = false; app.roster_sort = "Poste"
	state.focus = ("PanneauJoueur_%d" % numero) if numero > 0 else ""
	app._render(false)

func poste_etoiles() -> int:
	return _poste

func _rangees_listes() -> void:
	var joueurs: Array = app.model.get("squad", [])
	Listes.pastilles_postes(self, Vector2(_x0 + Bandeau.MARGE, Y_POSTES), Listes.compter_groupes(joueurs), joueurs.size(), str(state.get("poste_groupe", "")), _choisir_groupe)
	# Poste choisi sur le terrain XV : titre, nombre de joueurs à 4 étoiles et plus, ✕ (au bout de la rangée).
	Etoiles.titre_poste(self, _x0 + _lt - Bandeau.MARGE, Y_POSTES, joueurs, _poste, choisir_etoiles)
	_bandeau_totaux = Control.new()
	_bandeau_totaux.name = "RosterTuilesTotaux"
	add_child(_bandeau_totaux)
	D.place(_bandeau_totaux, Rect2(_x0 + Bandeau.MARGE, Y_TOTAUX, _lt - 2.0 * Bandeau.MARGE, 62))

## Chiffres de la liste filtrée : {id, v, cap, c (couleur), act}. Pas de tuile « fins de contrat » : la tuile du haut
## de l'écran la donne déjà.
func _definitions_totaux(players: Array) -> Array:
	var t := Listes.calculer(players)
	var masse := G.salary_amount(t.masse) + " " + G.salary_period(true)
	return [
		{"id": "Joueurs", "v": str(t.n), "cap": "joueurs", "c": Charte.IVOIRE, "act": func(): _tous_les_joueurs()},
		{"id": "Lignes", "v": "%d · %d" % [t.avants, t.arrieres], "cap": "av. · arr.", "c": Charte.IVOIRE, "act": func(): _toggle_sort("Poste")},
		{"id": "Niveau", "v": "—" if t.niveau == null else str(roundi(float(t.niveau))), "cap": "niveau moyen", "c": Charte.couleur_attribut(t.niveau) if t.niveau != null else Charte.IVOIRE, "act": func(): _toggle_sort("Niveau")},
		{"id": "Condition", "v": "—" if t.condition == null else "%d %%" % roundi(float(t.condition)), "cap": "condition moy.", "c": Charte.CONDITION, "act": func(): _toggle_sort("Condition")},
		{"id": "Moral", "v": str(roundi(float(app.model.get("meta", {}).get("morale", 0)))) if app.model.get("meta", {}).get("morale") != null else "—", "cap": "moral", "c": Charte.MORAL, "act": func(): app._navigate("Vestiaire")},
		{"id": "Age", "v": Listes.decimal(t.age), "cap": "âge moyen", "c": Charte.IVOIRE, "act": func(): _toggle_sort("Âge")},
		{"id": "Masse", "v": masse, "cap": "masse salariale", "c": R.BLEU, "act": func(): app._navigate("Finances")},
	]

func _totaux(players: Array) -> void:
	if _bandeau_totaux == null: return
	for enfant in _bandeau_totaux.get_children():
		_bandeau_totaux.remove_child(enfant)
		enfant.queue_free()
	var x := 0.0
	for d: Dictionary in _definitions_totaux(players):
		var l := maxf(R.largeur(str(d.v), 34, 800) + R.largeur(str(d.cap).to_upper(), 17) + 52.0, 180.0)
		var tuile := R.tuile(_bandeau_totaux, Rect2(x, 0, l, 60), str(d.v), str(d.cap), d.c, "TotalTuile_" + str(d.id), 34)
		var bouton := R.cliquable(tuile, d.act, "TotalTuileOuvrir_" + str(d.id), str(d.cap))
		# Mini-courbe au survol (relevé hebdomadaire du moteur, mêmes bulles que le Bureau et l'Entraînement).
		if str(d.id) == "Condition": Courbe.lier(app, bouton, "condition", "Condition du groupe")
		elif str(d.id) == "Moral": Courbe.lier(app, bouton, "morale", "Moral du vestiaire")
		x += l + 12.0
