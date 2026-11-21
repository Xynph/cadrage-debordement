extends RefCounted
## En-tête visuel de la Composition (demande de Léo du 22/11/2026) : plus de lignes de texte sous le titre.
## Ligne 1 : titre, pastilles de la feuille (Valide, XV, Banc, 1re ligne, quota, avertissements), actions à icône
## (Proposition du staff, Tireurs et lanceur, Valider la feuille en aplat vert : le doré reste à Continuer).
## Ligne 2 : bandeau du match dans le style de l'Avant-match (plaques aux couleurs des clubs, écusson à mini-carte),
## compétition + journée, tuile date / heure, stade avec pastille DOM. / EXT. ; à droite, les actions d'une feuille
## incomplète et le premier joueur sous 80 %. Ligne des onglets : pastilles Plan et Défense (→ Consignes).
## Tout ce qui a une destination est cliquable ; le reste a une apparence neutre.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Selection = preload("res://ui/immersive08/tactics_selection.gd")
const SousPages = preload("res://ui/immersive08/tactics_sous_pages.gd")
const Roles = preload("res://ui/immersive08/tactics_roles.gd")
const Impact = preload("res://ui/immersive08/tactics_impact.gd")
const Cover = preload("res://ui/lineup_cover.gd")
const Espoir = preload("res://ui/espoir_appel.gd")
const CarteClub = preload("res://ui/carte_club_survol.gd")
const RI = preload("res://ui/contextual/rooms/room_identity.gd")
## Deux couleurs de club plus proches que cela : l'adversaire passe en anneau (comme l'Avant-match).
const CLUBS_PROCHES := 0.22
const LIGNE_1 := 12.0
const LIGNE_2 := 66.0
const HAUT_PLAQUE := 50.0

## `rappels` : {choisir: Callable(slot), valider: Callable(), corriger: int}.
static func build(app: Control, page: Control, rappels: Dictionary) -> void:
	var titre := Kit.titre_page(page, 0, 40, "Composition", 38, 500)
	titre.name = "CompositionTitle"
	var largeur_titre := Charte.TITRE_FICHE.get_string_size("COMPOSITION", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(38))).x / C.density
	titre.size.x = (largeur_titre + 4) * C.density
	var x := largeur_titre + 24
	if P.is_derby(app.model):
		Kit.puce(page, Rect2(x, 14, 90, 26), "DERBY", Charte.PANNEAU_3, Charte.IVOIRE, "DerbyTag").tooltip_text = "Derby : une rivalité ancienne, plus de tension sur le terrain et dans les tribunes."
		x += 108
	var gauche_actions := _actions(app, page, rappels)
	_feuille(app, page, x, gauche_actions - 24, rappels)
	var fin_bandeau := _bandeau(app, page)
	_suite_feuille(app, page, fin_bandeau + 24, rappels)
	D.line(page, Vector2(0, 122), Vector2(2248, 122), Charte.FILET)

# --- Actions (droite de la ligne 1) -------------------------------------------------------------------------------

## Rend l'abscisse gauche de la plus à gauche des actions.
static func _actions(app: Control, page: Control, rappels: Dictionary) -> float:
	var droite := 2248.0
	droite -= Kit.touche(page, droite, 40, "Ctrl Entrée", true) + 14
	var selection: Dictionary = app.model.get("selection", {})
	var valider := bouton(page, droite, "Valider la feuille", "check", rappels.valider, "TacticsValidate", true)
	valider.disabled = not selection.get("valid", false) or not Selection.editable(app)
	valider.tooltip_text = "Valider la feuille et passer à la préparation · Ctrl+Entrée" if not valider.disabled else "Feuille à compléter"
	droite -= valider.size.x / C.density + 16
	if not Roles.view(app.model).is_empty():
		var roles := bouton(page, droite, "Tireurs et lanceur", "target", func(): SousPages.ouvrir(app, "roles"), "LineupRoles")
		roles.tooltip_text = "Buteur, buteur de secours, lanceur en touche, jeu au pied d’occupation"
		droite -= roles.size.x / C.density + 12
	var auto := bouton(page, droite, "Proposition du staff", "people", func(): app._command("auto_lineup"), "LineupAutomatic")
	auto.disabled = not Selection.editable(app)
	auto.tooltip_text = "Composition recommandée par le staff"
	return droite - auto.size.x / C.density

## Bouton pilule à icône posé à gauche de `droite` (ligne 1). `principal` : aplat vert franc (jamais doré).
static func bouton(page: Control, droite: float, texte: String, icone: String, action: Callable, id: String, principal: bool = false) -> Button:
	var b := Button.new()
	b.name = id
	b.text = texte.to_upper() if principal else texte
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	C.style_bouton_contour(b, 21)
	var encre := Charte.IVOIRE
	if principal:
		var looks := {"normal": Charte.VERT_FRANC, "hover": Charte.VERT_FRANC.lightened(.12), "pressed": Charte.VERT_FRANC.darkened(.12), "disabled": Charte.PANNEAU_3}
		for look: String in looks:
			var style := C.box(looks[look], Color.TRANSPARENT, Charte.RAYON_PILULE, 18)
			style.content_margin_top = C.px(7)
			style.content_margin_bottom = C.px(7)
			Charte.sans_ombre(style)
			b.add_theme_stylebox_override(look, style)
		b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	else:
		b.add_theme_font_override("font", Charte.texte_moyen())
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE, 18)
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(2)
	b.add_theme_stylebox_override("focus", focus)
	b.icon = C.icon_texture(icone, encre)
	b.add_theme_constant_override("icon_max_width", C.px(20))
	b.add_theme_constant_override("h_separation", C.px(10))
	for etat in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]: b.add_theme_color_override(etat, Color.WHITE)
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, .4))
	b.pressed.connect(action)
	var police: Font = b.get_theme_font("font")
	var largeur := police.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x / C.density + 36 + 30 + 4
	page.add_child(b)
	D.place(b, Rect2(droite - largeur, LIGNE_1 - 2, largeur, 44))
	return b

# --- Pastilles de la feuille (ligne 1) -----------------------------------------------------------------------------

## Pastille de `Pieces` dont on garde les nœuds : rend [pilule, largeur].
static func _pastille(parent: Control, x: float, y: float, texte: String, icone: String, id: String, couleur: Color, action: Callable = Callable(), bulle: String = "") -> Array:
	var largeur := Pieces.pastille(parent, x, y, texte, icone, id, bulle, couleur, Charte.PANNEAU_3, action)
	return [parent.get_child(parent.get_child_count() - 1), largeur]

static func _feuille(app: Control, page: Control, x: float, limite: float, rappels: Dictionary) -> void:
	var selection: Dictionary = app.model.get("selection", {})
	var valide := bool(selection.get("valid", false))
	var erreurs: Array = selection.get("errors", [])
	var choisir: Callable = rappels.choisir
	var titulaires := 0
	var remplacants := 0
	var vide_xv := -1
	var vide_banc := -1
	for index in 23:
		var occupe := not Selection.occupant(app.model, index).is_empty()
		if index < 15:
			if occupe: titulaires += 1
			elif vide_xv < 0: vide_xv = index
		else:
			if occupe: remplacants += 1
			elif vide_banc < 0: vide_banc = index
	var premiere := Selection.premiere_ligne(app.model)
	var corriger := int(rappels.get("corriger", -1))
	var y := LIGNE_1 + 4
	# Valide / Incomplète : la raison du moteur au survol ; clic → place à corriger (sinon le bouton Valider).
	var etat: Array
	if valide:
		etat = _pastille(page, x, y, "Valide", "check", "TacticsValidity", Pieces.VERT, func(): _focus(app, "TacticsValidate"))
	else:
		etat = _pastille(page, x, y, "Incomplète", "warning", "TacticsValidity", Pieces.ROUGE, func(): choisir.call(maxi(corriger, 0)), "\n".join(erreurs))
		var lien := (etat[0] as Control).get_node_or_null("TacticsValidityLien")
		if lien != null: lien.name = "TacticsCorriger"
	x += float(etat[1]) + 10
	var cible := int(premiere.get("cible", 6))
	var formes := mini(int(premiere.get("formes", 0)), cible)
	var place_premiere := 0
	for poste: Dictionary in premiere.get("postes", []):
		if int(poste.get("formes", 0)) < 2:
			place_premiere = int(poste.titulaire) if not Selection.premiere_ligne_formee(app.model, Selection.occupant(app.model, int(poste.titulaire))) else int(poste.remplacant)
			break
	var compteurs := [
		["XV %d/15" % titulaires, titulaires >= 15, "TacticsCountStarters", maxi(vide_xv, 0)],
		["Banc %d/8" % remplacants, remplacants >= 8, "TacticsCountBench", vide_banc if vide_banc >= 0 else 15],
		["1re ligne %d/%d" % [formes, cible], formes >= cible, "TacticsCountFrontRow", place_premiere],
	]
	for c: Array in compteurs:
		var slot: int = c[3]
		var p := _pastille(page, x, y, str(c[0]), "check" if c[1] else "warning", str(c[2]), Pieces.VERT if c[1] else Pieces.ORANGE, func(): choisir.call(slot))
		x += float(p[1]) + 10
	# Quota du championnat (JIFF / EQP) : nom LineupJiffNotice conservé.
	var quota: Dictionary = app.model.get("clubLife", {}).get("jiff", {})
	if bool(quota.get("applies", false)):
		var compte := int(quota.get("currentSheet", 0)) + int(quota.get("doublon", 0))
		var alerte := bool(quota.get("alert", false))
		var texte := "%s %d/%d" % [str(quota.get("label", "JIFF")), compte, int(quota.get("target", 16))]
		var bulle: String = app.SquadViews.quota_line(quota) + "\n" + app.SquadViews.quota_tooltip(quota)
		var q := _pastille(page, x, y, texte, "warning" if alerte else "flag", "LineupJiffNotice", Pieces.ROUGE if alerte else Pieces.BLEU, Callable(), bulle)
		x += float(q[1]) + 10
	# Joueurs de la feuille sous 80 % : menu déroulant (exception autorisée) ; l'entrée montre les candidats du poste.
	var bas := sous_80(app)
	if not bas.is_empty() and x + 150 < limite:
		var menu := MenuButton.new()
		menu.name = "TacticsWarnings"
		menu.text = "%d sous 80 %% ▾" % bas.size()
		menu.flat = false
		menu.focus_mode = Control.FOCUS_ALL
		menu.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		menu.icon = C.icon_texture("heart", Pieces.ORANGE)
		menu.add_theme_constant_override("icon_max_width", C.px(18))
		menu.add_theme_font_override("font", C.BODY)
		menu.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
		for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: menu.add_theme_color_override(couleur, Pieces.ORANGE)
		var fond := C.box(Charte.PANNEAU_3.lerp(Pieces.ORANGE, .16), Color.TRANSPARENT, Charte.RAYON_PILULE, 13)
		fond.content_margin_top = 0
		fond.content_margin_bottom = 0
		Charte.sans_ombre(fond)
		for look in ["normal", "pressed", "hover"]: menu.add_theme_stylebox_override(look, fond if look != "hover" else _plus_clair(fond))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE, 2)
		focus.set_border_width_all(2)
		menu.add_theme_stylebox_override("focus", focus)
		Impact._styler_menu(menu.get_popup())
		for i in bas.size():
			menu.get_popup().add_item("%s (n° %d) · %d %% de condition" % [Kit.casse(str(bas[i][1].get("name", ""))), int(bas[i][0]) + 1, int(bas[i][2])], i)
		menu.get_popup().id_pressed.connect(func(i: int): choisir.call(int(bas[i][0])))
		page.add_child(menu)
		var large := C.BODY.get_string_size(menu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(18))).x / C.density + 26 + 34
		D.place(menu, Rect2(x, y, large, 34))

static func _plus_clair(style: StyleBoxFlat) -> StyleBoxFlat:
	var s := style.duplicate() as StyleBoxFlat
	s.bg_color = s.bg_color.lightened(.08)
	return s

## Joueurs de la feuille sous 80 % de condition : [index, joueur, condition arrondie].
static func sous_80(app: Control) -> Array:
	var bas: Array = []
	for index in 23:
		var person := Selection.occupant(app.model, index)
		var forme: Variant = person.get("condition")
		if (forme is int or forme is float) and float(forme) < 80: bas.append([index, person, roundi(float(forme))])
	return bas

static func _focus(app: Control, id: String) -> void:
	var cible := app.root_content.find_child(id, true, false) as Control
	if cible != null: cible.grab_focus()

# --- Bandeau du match (ligne 2) -----------------------------------------------------------------------------------

## Rend l'abscisse droite du bandeau.
static func _bandeau(app: Control, page: Control) -> float:
	var match_ := P.next_fixture(app.model)
	if match_.is_empty():
		Kit.texte(page, 0, LIGNE_2 + 32, "Aucun prochain match", Charte.IVOIRE_2, 400, 18).name = "TacticsFixture"
		return 400.0
	var clubs: Array = [match_.get("home", {}), match_.get("away", {})]
	var nous_id: Variant = app.model.get("club", {}).get("id")
	var nous := 1 if CarteClub.cle(clubs[1].get("id", "")) == CarteClub.cle(nous_id) else 0
	var couleurs: Array[Color] = [RI.primary(G.identity(clubs[0])), RI.primary(G.identity(clubs[1]))]
	var proches := Vector3(couleurs[0].r - couleurs[1].r, couleurs[0].g - couleurs[1].g, couleurs[0].b - couleurs[1].b).length() < CLUBS_PROCHES
	var x := 0.0
	for side in 2:
		var plaque := _plaque(app, page, x, clubs[side], couleurs[side], side == 1, proches and side != nous)
		plaque.name = "TacticsFixtureHome" if side == 0 else "TacticsFixtureAway"
		x += plaque.size.x / C.density
		if side == 0:
			D.text(page, x + 20, LIGNE_2 + 34, "–", 26, Charte.IVOIRE_2, 700, 40, HORIZONTAL_ALIGNMENT_CENTER)
			x += 40
	x += 20
	var y := LIGNE_2 + (HAUT_PLAQUE - 34) / 2.0
	var libelle := str(match_.get("label", ""))
	if not libelle.is_empty():
		x += _pastille(page, x, y, libelle, "trophy", "TacticsFixtureCompetition", Pieces.VIOLET, func(): app._navigate("Classements"))[1] + 12
	x += _tuile_date(app, page, x, match_) + 12
	var stade := P.fixture_venue(match_, true, true)
	var lieu := P.fixture_location_kind(match_, nous_id)
	if not stade.is_empty():
		var proprietaire: Dictionary = clubs[0]
		var action := Callable() if lieu == "neutral" else func(): _ouvrir_club(app, proprietaire)
		x += _pastille(page, x, y, stade, "flag" if lieu == "neutral" else "home", "TacticsFixtureVenue", Pieces.TURQUOISE, action)[1] + 8
	if lieu in ["home", "away"]:
		var dom := lieu == "home"
		x += _pastille(page, x, y, "DOM." if dom else "EXT.", "home-solid" if dom else "bus-solid", "TacticsFixturePlace", Pieces.VERT if dom else Charte.IVOIRE_2)[1]
	elif lieu == "neutral":
		x += _pastille(page, x, y, "NEUTRE", "flag-solid", "TacticsFixturePlace", Charte.IVOIRE_2)[1]
	return x

## Plaque de club (Avant-match en petit) : aplat aux couleurs du club, écusson (survol = mini-carte), nom en Anton.
## Clic → fiche du club. `anneau` : couleurs trop proches de l'autre club, contour seul.
static func _plaque(app: Control, page: Control, x: float, club: Dictionary, couleur: Color, droite: bool, anneau: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = ""
	b.accessibility_name = "Fiche du club %s" % G.club_name(club)
	var fond := C.box(Color.TRANSPARENT if anneau else couleur, couleur if anneau else Color.TRANSPARENT, Charte.RAYON_PILULE, 0)
	if anneau: fond.set_border_width_all(2)
	Charte.sans_ombre(fond)
	var survol := fond.duplicate() as StyleBoxFlat
	survol.bg_color = Color(Charte.IVOIRE, .10) if anneau else couleur.lightened(.12)
	for look in ["normal", "disabled"]: b.add_theme_stylebox_override(look, fond)
	for look in ["hover", "pressed", "hover_pressed"]: b.add_theme_stylebox_override(look, survol)
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE, 0)
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(2)
	b.add_theme_stylebox_override("focus", focus)
	b.pressed.connect(func(): _ouvrir_club(app, club))
	var encre := Charte.IVOIRE if anneau or Charte.contraste(Charte.IVOIRE, couleur) >= 3.0 else Charte.ENCRE
	var nom := G.club_name(club).to_upper()
	var taille := 24
	var largeur_nom := Charte.TITRE_FICHE.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille))).x / C.density
	var cote := 40.0
	var largeur := 10 + cote + 12 + largeur_nom + 22
	page.add_child(b)
	D.place(b, Rect2(x, LIGNE_2, largeur, HAUT_PLAQUE))
	var crest := G.crest(club, C.px(cote))
	crest.name = "Ecusson"
	b.add_child(crest)
	D.place(crest, Rect2(largeur - 10 - cote if droite else 10, (HAUT_PLAQUE - cote) / 2.0, cote, cote))
	CarteClub.lier(crest, club)
	var label := D.text(b, 22 if droite else 10 + cote + 12, HAUT_PLAQUE / 2.0 + 10, nom, taille, encre, 500, largeur_nom + 4)
	label.add_theme_font_override("font", Charte.TITRE_FICHE)
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.name = "Nom"
	label.tooltip_text = ""
	return b

static func _ouvrir_club(app: Control, club: Dictionary) -> void:
	var id: Variant = club.get("id")
	if (id is int or id is float or (id is String and not str(id).is_empty())) and app.navigation_controller.open_entity({"kind": "club", "id": CarteClub.cle(id)}): return
	app._navigate("Classements")

## Tuile date / heure : carte rayon 12, icône calendrier, date puis heure du coup d'envoi en grand. Clic → Calendrier.
static func _tuile_date(app: Control, page: Control, x: float, match_: Dictionary) -> float:
	var morceaux := P.fixture_date(match_).split(" · ")
	var date := morceaux[0] if morceaux.size() > 0 else ""
	var heure := morceaux[1] if morceaux.size() > 1 else ""
	if date.is_empty(): return 0.0
	var l_date := Kit.largeur(date, 18)
	var l_heure := Charte.TITRE_FICHE.get_string_size(heure, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(26))).x / C.density if not heure.is_empty() else 0.0
	var largeur := 14 + 22 + 10 + l_date + (14 + l_heure if not heure.is_empty() else 0.0) + 16
	var carte := D.rect(page, Rect2(x, LIGNE_2, largeur, HAUT_PLAQUE), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	carte.name = "TacticsFixtureDate"
	var icone := C.icon("calendar", 22, Pieces.BLEU)
	carte.add_child(icone)
	D.place(icone, Rect2(14, (HAUT_PLAQUE - 22) / 2.0, 22, 22))
	var t := Kit.texte(carte, 46, HAUT_PLAQUE / 2.0 + 7, date, Charte.IVOIRE, l_date + 4, 18)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.name = "Date"
	if not heure.is_empty():
		var h := D.text(carte, 46 + l_date + 14, HAUT_PLAQUE / 2.0 + 11, heure, 26, Pieces.BLEU, 500, l_heure + 4)
		h.add_theme_font_override("font", Charte.TITRE_FICHE)
		h.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.name = "Heure"
	Pieces.rendre_cliquable(carte, Vector2(largeur, HAUT_PLAQUE), func(): app._navigate("Calendrier"), "TacticsFixtureDateLien", "%s %s · Calendrier" % [date, heure], "", Charte.RAYON_CARTE)
	return largeur

# --- Suite de la feuille (ligne 2, à droite du bandeau) -----------------------------------------------------------

## Feuille incomplète : Appeler un espoir / feuille à 22 / Renforts ; premier joueur sous 80 % (nom → fiche, pastille → poste).
static func _suite_feuille(app: Control, page: Control, gauche: float, rappels: Dictionary) -> void:
	var choisir: Callable = rappels.choisir
	var y := LIGNE_2 + (HAUT_PLAQUE - 34) / 2.0
	var x := gauche
	var selection: Dictionary = app.model.get("selection", {})
	if not bool(selection.get("valid", false)):
		if not Espoir.offer(app.model).is_empty():
			var e := _pastille(page, x, y, "Appeler un espoir", "school", "LineupCallEspoir", Pieces.BLEU, func(): SousPages.ouvrir(app, "espoir"))
			(e[0] as Control).tooltip_text = Espoir.vacancy_text(app.model)
			x += float(e[1]) + 10
		elif P.reduced_bench_number(app.model) != 0:
			var a := _pastille(page, x, y, "Feuille à 22", "calendar", "LineupOpenMatchAt22", Pieces.BLEU, func(): app._navigate("Match"), P.reduced_bench_vacancy(P.reduced_bench_number(app.model)))
			x += float(a[1]) + 10
		var devis := Cover.data(app)
		if not devis.is_empty():
			var r := Kit.lien(page, Rect2(x, y - 2, 0, 38), Cover.caption(devis) + " →", func(): SousPages.ouvrir(app, "renforts"), "LineupCover")
			Cover.configure(r, devis)
			x += r.size.x / C.density + 12
	var bas := sous_80(app)
	if bas.is_empty() or x + 360 > 2248: return
	var premier: Array = bas[0]
	var nom_joueur := Kit.casse(str(premier[1].get("name", "")), true)
	Kit.nom(app, page, Rect2(x, y + 1, Kit.largeur(nom_joueur, 18) + 4, 32), nom_joueur, str(premier[1].get("id", "")), "TacticsWarningName", Charte.IVOIRE, 18)
	x += Kit.largeur(nom_joueur, 18) + 10
	var slot := int(premier[0])
	_pastille(page, x, y, "n° %d · %d %%" % [slot + 1, int(premier[2])], "heart", "TacticsWarning", Pieces.ORANGE, func(): choisir.call(slot))

# --- Ligne des onglets : Plan et Défense --------------------------------------------------------------------------

## Pastilles Plan (attaque) et Défense, à droite des onglets ; clic → onglet Consignes de la préparation.
static func plan(app: Control, page: Control, plan_: String, defense: String) -> void:
	var ouvrir := func(): app.Immersive.open_preparation(app, 1)
	var y := 137.0
	var l_def := Pieces.largeur_pastille("Défense · " + defense, "shield")
	var l_plan := Pieces.largeur_pastille("Plan · " + plan_, "tactic")
	var x := 2248.0 - l_def
	_pastille(page, x, y, "Défense · " + defense, "shield", "TacticsDefenseSummary", Pieces.VIOLET, ouvrir)
	x -= l_plan + 10
	var p := _pastille(page, x, y, "Plan · " + plan_, "tactic", "TacticsPlanSummary", Pieces.BLEU, ouvrir)
	var lien := (p[0] as Control).get_node_or_null("TacticsPlanSummaryLien")
	if lien != null: lien.name = "TacticsPlanModify"
