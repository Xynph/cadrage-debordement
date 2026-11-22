extends RefCounted
## Centre de formation, parcours actifs (choix de Léo du 22/11/2026, après planche A/B) : structure B (le chemin) pour
## Centre, Parcours, Passerelle pro et Générations, structure A (les cartes) pour Centres et Filières, le tout habillé
## comme l'Effectif (« ça fait trop tuiles ») : en-tête titre + tuiles chiffres, onglets en pilules, panneaux à titre
## Anton, listes à lignes (colonnes, visage, chiffres colorés, survol de ligne, carte joueur au survol, tri par en-tête,
## filtres en pastilles) et réglages en pastilles compactes. Pleine largeur (plus de colonne de droite).
## Ce fichier porte la coque et les pièces communes ; les six onglets sont dans centre_onglets.gd.
## Coordonnées en unités du gabarit (toile 2248 × 1230).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/carnet_skin.gd")
const Charte = preload("res://ui/charte.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Listes = preload("res://ui/immersive08/listes_joueurs.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")
const Academy = preload("res://ui/academy_pathways_view.gd")
const Juniors = preload("res://ui/immersive08/centre_juniors.gd")

const LARGEUR := 2248.0
const Y_ONGLETS := 130.0
const Y_CONTENU := 196.0
const BAS := 1226.0
const ENTETE := 62.0
const LIGNE := 42.0
const COLONNE := 470.0

## Couleur franche par donnée (palette commune de charte.gd) : toujours avec un chiffre, un mot ou une forme.
const COHESION := Charte.MORAL
const REPUTATION := Charte.CONFIANCE
const MINUTES := Charte.REPOS
const PROGRES := Charte.GAIN
const DEPENSE := Charte.INTENSIF
const ALERTE := Charte.PERTE
const COULEURS := [Charte.REPOS, Charte.GAIN, Charte.MORAL, Charte.CONFIANCE, Charte.INTENSIF, Charte.PERTE]

const ONGLETS := ["Centre", "Parcours", "Centres", "Filières", "Passerelle pro", "Générations"]

## Trajectoire d'un Espoir : [valeur moteur, libellé, icône, couleur].
const TRAJECTOIRES := [
	["equilibre", "Équilibre", "target", Charte.MORAL],
	["minutes", "Minutes", "clock", Charte.REPOS],
	["progression", "Potentiel", "rating", Charte.CONFIANCE],
	["professionnel", "Passage pro", "trophy", Charte.INTENSIF],
]
## Étapes du chemin des Espoirs (âge), de l'académie vers l'équipe première.
const ETAPES := [
	["u17", "17 ans et moins", Charte.REPOS],
	["u19", "18-19 ans", Charte.GAIN],
	["u20", "20 ans et plus", Charte.INTENSIF],
]

static func _onglets_script() -> Script:
	return load("res://ui/immersive08/centre_onglets.gd")

# --- Coque ----------------------------------------------------------------------------------------------------------

## Pose la page du Centre (parcours actifs) dans `page`, la toile du Centre.
static func construire(app: Control, page: Control) -> void:
	for enfant in page.get_children():
		page.remove_child(enfant)
		enfant.queue_free()
	var data: Dictionary = app.model.get("clubLife", {}).get("academyPathways", {})
	var state: Dictionary = app.management_ui.immersive_centre
	if not state.get("scroll") is Dictionary: state.scroll = {}
	var onglet := str(state.get("tab", ""))
	if not onglet in ONGLETS: onglet = "Centre"
	var ctx := {"app": app, "page": page, "data": data, "state": state, "onglet": onglet}
	ctx.reconstruire = func(): construire(app, page)
	var racine := Control.new()
	racine.name = "CentreVisuel"
	racine.set_meta("onglet", onglet)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(racine)
	D.place(racine, Rect2(0, 0, LARGEUR, 1230))
	ctx.racine = racine
	_entete(ctx)
	_onglets(ctx)
	_onglets_script().onglet(ctx, onglet, Rect2(0, Y_CONTENU, LARGEUR, BAS - Y_CONTENU))
	var rouvrir: Variant = state.get("fenetre")
	if rouvrir is Dictionary and str(rouvrir.get("kind", "")) == "joueur":
		(func(): if is_instance_valid(page) and page.is_inside_tree(): fenetre_parcours(ctx, str(rouvrir.get("id", "")))).call_deferred()

static func aller(ctx: Dictionary, onglet: String, cle: String = "", valeur: Variant = null) -> Callable:
	return func():
		ctx.state.tab = onglet
		ctx.state.erase("fenetre")
		if not cle.is_empty(): ctx.state[cle] = valeur
		(ctx.reconstruire as Callable).call()

## Titre Anton, deux pastilles sous le titre et tuiles chiffres à droite (même gabarit que l'Effectif).
static func _entete(ctx: Dictionary) -> void:
	var app: Control = ctx.app
	var data: Dictionary = ctx.data
	var titre := D.text(ctx.racine, 0, 64, "CENTRE DE FORMATION", 58, Charte.IVOIRE, 800, 900)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "CentreTitre"
	app.heading = titre
	var n: int = data.get("players", []).size()
	var espoirs := R.pastille(ctx.racine, 0, 104, "%d Espoirs" % n, Charte.IVOIRE_2, "people", "CentreSousTitre")
	zone_cliquable(ctx.racine, Rect2(espoirs.position / C.density, espoirs.size / C.density), aller(ctx, "Parcours"), "CentreSousTitreOuvrir", "Espoirs du centre", 8)
	var saison := R.pastille(ctx.racine, espoirs.size.x / C.density + 10, 104, "Période %s / %s" % [G.n(data.get("juniorRound", 0)), G.n(data.get("totalRounds", 26))], MINUTES, "calendar", "CentreSaison")
	zone_cliquable(ctx.racine, Rect2(saison.position / C.density, saison.size / C.density), func(): Juniors.ouvrir(app, ctx.page), "CentreSaisonOuvrir", "Saison junior", 8)
	var tuiles := [
		["Cohesion", "COHÉSION", G.n(data.get("cohesion", 0)), "/ 100", COHESION, 250.0, aller(ctx, "Centre")],
		["Reputation", "RÉPUTATION", G.n(data.get("reputation", 0)), "/ 100", REPUTATION, 250.0, aller(ctx, "Générations")],
		["Enveloppe", "ENVELOPPE JUNIOR", mille(data.get("recruitBudget", 0)) + " €", "", DEPENSE, 330.0, aller(ctx, "Centres")],
		["Places", "PLACES PRO", G.n(data.get("places", 0)), "libres", PROGRES, 250.0, func(): app._navigate("Effectif")],
	]
	var x := LARGEUR
	for i in range(tuiles.size() - 1, -1, -1):
		var t: Array = tuiles[i]
		x -= float(t[5])
		_tuile(ctx, Rect2(x, 0, float(t[5]), 88), t)
		x -= 14.0

static func _tuile(ctx: Dictionary, zone: Rect2, t: Array) -> void:
	var tuile := Button.new()
	tuile.name = "CentreTuile" + str(t[0])
	tuile.focus_mode = Control.FOCUS_ALL
	tuile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tuile.accessibility_name = "%s %s %s" % [t[1], t[2], t[3]]
	tuile.add_theme_stylebox_override("normal", plat(Charte.PANNEAU, Color.TRANSPARENT, 0, 16))
	tuile.add_theme_stylebox_override("hover", plat(Charte.PANNEAU_2, Color.TRANSPARENT, 0, 16))
	tuile.add_theme_stylebox_override("pressed", plat(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 16))
	tuile.add_theme_stylebox_override("focus", plat(Color.TRANSPARENT, Charte.IVOIRE, 2, 16))
	ctx.racine.add_child(tuile)
	D.place(tuile, zone)
	load("res://ui/retour_tuile.gd").brancher(tuile, tuile, C.px(16))
	D.text(tuile, 16, 28, t[1], 17, Charte.IVOIRE_2, 700, zone.size.x - 28).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := chiffre(tuile, 16, 72, t[2], 48, t[4], 220)
	v.name = "CentreTuileValeur"
	if not str(t[3]).is_empty():
		var l := C.font(800).get_string_size(str(t[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(48))).x / C.density
		D.text(tuile, 16 + l + 12, 68, t[3], 18, Charte.IVOIRE_2, 500, zone.size.x - l - 40, HORIZONTAL_ALIGNMENT_LEFT, true).mouse_filter = Control.MOUSE_FILTER_IGNORE
	tuile.pressed.connect(t[6])

## Onglets en pilules (même rendu que l'Effectif) avec leur compteur, liens vers les écrans voisins à droite.
static func _onglets(ctx: Dictionary) -> void:
	var data: Dictionary = ctx.data
	var comptes := {
		"Parcours": data.get("players", []).size(),
		"Centres": data.get("centers", []).filter(func(c: Dictionary): return c.get("scouted", false) and not c.get("own", false)).size(),
		"Filières": data.get("prospects", []).size(),
		"Passerelle pro": data.get("loans", []).size(),
		"Générations": data.get("generations", []).size(),
	}
	var x := 0.0
	for nom: String in ONGLETS:
		var actif: bool = nom == ctx.onglet
		var libelle := nom if not comptes.has(nom) else "%s  %d" % [nom, comptes[nom]]
		var lo := largeur(libelle, 20) + 44.0
		var b := Button.new()
		b.name = "CentreOnglet_" + nom.validate_node_name()
		b.text = libelle
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", C.BODY)
		b.add_theme_font_size_override("font_size", maxi(12, C.px(20)))
		b.accessibility_name = "Onglet " + nom + (" · actif" if actif else "")
		D.tab_state(b, Vector2(lo, 44), actif, "")
		b.icon = null
		var focus := plat(Color.TRANSPARENT, Charte.IVOIRE, 2, Charte.RAYON_PILULE)
		focus.set_expand_margin_all(2)
		b.add_theme_stylebox_override("focus", focus)
		ctx.racine.add_child(b)
		D.place(b, C.reach_rect(Rect2(x, Y_ONGLETS, lo, 44)))
		b.pressed.connect(aller(ctx, nom))
		x += lo + 8.0
	var droite := LARGEUR
	for lien: Array in [["Formation →", "Formation", "CentreLienFormation"], ["Suivi des jeunes →", "Suivi des jeunes", "CentreLienSuivi"]]:
		var l := R.largeur(str(lien[0]), 19, 600) + 36.0
		droite -= l
		var route := str(lien[1])
		var b := Button.new()
		b.name = str(lien[2])
		b.text = str(lien[0])
		b.flat = true
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		C.style_bouton_lien(b, 19)
		ctx.racine.add_child(b)
		D.place(b, C.reach_rect(Rect2(droite, Y_ONGLETS, l, 44)))
		b.pressed.connect(func(): ctx.app._navigate(route))
		droite -= 16.0

# --- Pièces ---------------------------------------------------------------------------------------------------------

static func plat(fond: Color, bord: Color = Color.TRANSPARENT, epaisseur: int = 0, rayon: int = Charte.RAYON_PETIT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.border_color = bord
	s.set_border_width_all(maxi(epaisseur, C.px(epaisseur)) if epaisseur > 0 else 0)
	s.set_corner_radius_all(999 if rayon >= Charte.RAYON_PILULE else maxi(2, C.px(rayon)))
	s.anti_aliasing = true
	return s

static func chiffre(parent: Node, x: float, base: float, valeur: Variant, taille: int, couleur: Color = Charte.IVOIRE, largeur: float = 0.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := D.text(parent, x, base, valeur, taille, couleur, 800, largeur, align)
	l.add_theme_font_override("font", Charte.TITRE_EXTRA)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func texte(parent: Node, x: float, base: float, valeur: Variant, taille: int = 19, couleur: Color = Charte.IVOIRE, largeur: float = 0.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, graisse: int = 600, corps: bool = true) -> Label:
	var l := D.text(parent, x, base, valeur, taille, couleur, graisse, largeur, align, corps)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func icone(parent: Node, zone: Rect2, id: String, couleur: Color) -> TextureRect:
	var i := C.icon(id, int(zone.size.x), couleur)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(i)
	D.place(i, zone)
	return i

## Largeur (unités) d'un texte : police du corps (DM Sans) ou Barlow Condensed de graisse `graisse`.
static func largeur(t: String, taille: int, corps: bool = true, graisse: int = 600) -> float:
	var police: Font = C.BODY if corps else C.font(graisse)
	return police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille))).x / C.density

## Nombre avec espace des milliers (« 32 911 »).
static func mille(n: Variant) -> String:
	return G.euros(int(n) if n != null else 0).replace("€", "").strip_edges()

static func euros(n: Variant) -> String:
	return G.euros(int(n) if n != null else 0)

## Panneau de l'Effectif : fond PANNEAU, titre Anton avec pictogramme, flèche vers un écran ou un onglet à droite.
static func panneau(parent: Control, zone: Rect2, titre: String, icone_id: String, id: String, fleche: Callable = Callable(), compte: String = "", couleur_compte: Color = Charte.IVOIRE) -> Panel:
	var p := D.panel(parent, zone, "", "", "", id)
	icone(p, Rect2(20, (ENTETE - 26) / 2.0, 26, 26), icone_id, Charte.IVOIRE_2)
	var t := D.text(p, 58, ENTETE / 2.0 + 12, titre.to_upper(), 30, Charte.IVOIRE, 700, zone.size.x - 200)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not compte.is_empty():
		chiffre(p, 58 + R.largeur(titre.to_upper(), 30) + 18, ENTETE / 2.0 + 13, compte, 30, couleur_compte, 160)
	if fleche.is_valid():
		var b := zone_cliquable(p, Rect2(zone.size.x - 76, 11, 58, ENTETE - 22), fleche, id + "Fleche", titre)
		icone(b, Rect2(18, (ENTETE - 22 - 22) / 2.0, 22, 22), "arrow", Charte.IVOIRE)
	return p

## Bouton plat couvrant `zone` : voile clair au survol, main, focus.
static func zone_cliquable(parent: Control, zone: Rect2, action: Callable, id: String, aide: String, rayon: int = 10) -> Button:
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.accessibility_name = aide
	for etat: String in ["normal", "hover", "pressed", "focus"]:
		var s := plat(Color(Charte.IVOIRE, {"normal": 0.0, "hover": .08, "pressed": .14, "focus": 0.0}[etat]), Charte.IVOIRE if etat == "focus" else Color.TRANSPARENT, 1 if etat == "focus" else 0, rayon)
		b.add_theme_stylebox_override(etat, s)
	parent.add_child(b)
	D.place(b, zone)
	# Petite fenêtre (densité < 0,75) : cible d'au moins 25 px ; le bouton grandit vers le bas, son contenu reste en place.
	b.custom_minimum_size = Vector2(C.px(C.reach(zone.size.y)), C.px(C.reach(zone.size.y)))
	if action.is_valid(): b.pressed.connect(action)
	return b

## Pastille-bouton compacte (filtre, réglage, action) : choisie = aplat de sa couleur, texte sombre ; sinon contour
## discret et point de couleur. Renvoie la largeur posée.
static func pilule(parent: Control, x: float, y: float, libelle: String, couleur: Color, choisie: bool, action: Callable, id: String, nombre: String = "", actif: bool = true, h: float = 40.0, taille: int = 19) -> float:
	var point := couleur != Charte.IVOIRE and not choisie
	var l := largeur(libelle, taille) + (10.0 + largeur(nombre, taille, false, 700) if not nombre.is_empty() else 0.0) + 36.0 + (18.0 if point else 0.0)
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if actif else Control.CURSOR_ARROW
	b.accessibility_name = "%s %s%s" % [libelle, nombre, " · choisi" if choisie else ""]
	b.disabled = not actif
	for etat: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := plat(couleur if choisie else (Charte.PANNEAU_2 if etat == "hover" else Color.TRANSPARENT), Color.TRANSPARENT if choisie else (Charte.IVOIRE_3 if etat == "hover" else Charte.FILET), 0 if choisie else 1, Charte.RAYON_PILULE)
		if etat == "focus":
			s = plat(Color.TRANSPARENT, Charte.IVOIRE, 2, Charte.RAYON_PILULE)
			s.set_expand_margin_all(2)
		b.add_theme_stylebox_override(etat, s)
	parent.add_child(b)
	D.place(b, Rect2(x, y, l, h))
	b.custom_minimum_size = Vector2(C.px(C.reach(h)), C.px(C.reach(h)))
	var encre := Charte.PANNEAU if choisie else (Charte.IVOIRE if actif else Charte.IVOIRE_3)
	var gauche := 18.0
	if point:
		D.rect(b, Rect2(16, h / 2.0 - 5, 10, 10), couleur if actif else Charte.IVOIRE_3, Charte.RAYON_PILULE)
		gauche = 34.0
	texte(b, gauche, h / 2.0 + taille * .36, libelle, taille, encre, l)
	if not nombre.is_empty():
		var c := D.text(b, gauche + largeur(libelle, taille) + 10.0, h / 2.0 + taille * .36, nombre, taille, Charte.PANNEAU if choisie else (couleur if point else Charte.IVOIRE_2), 700, 160)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if actif: b.pressed.connect(action)
	return l

## Rangée de pilules (filtres ou réglage) : `defs` = [valeur, libellé, couleur, nombre?, actif?]. Renvoie la largeur.
static func pilules(parent: Control, x: float, y: float, defs: Array, courant: Variant, choisir: Callable, id: String, h: float = 40.0, taille: int = 19, largeur_max: float = 99999.0) -> Vector2:
	var cx := x
	var cy := y
	for d: Array in defs:
		var valeur: Variant = d[0]
		var nombre := str(d[3]) if d.size() > 3 else ""
		var actif: bool = bool(d[4]) if d.size() > 4 else true
		var l := largeur(str(d[1]), taille) + (10.0 + largeur(nombre, taille, false, 700) if not nombre.is_empty() else 0.0) + 54.0
		if cx > x and cx + l > x + largeur_max:
			cx = x
			cy += h + 8.0
		var choisie: bool = courant != null and str(courant) == str(valeur)
		cx += pilule(parent, cx, cy, str(d[1]), d[2], choisie, func(): choisir.call(valeur), "%s_%s" % [id, str(valeur).validate_node_name()], nombre, actif, h, taille) + 8.0
	return Vector2(cx - x, cy + h - y)

## Portrait carré de liste (comme l'Effectif) ; `rond` : disque cerclé (panneaux, fenêtres).
static func portrait(parent: Control, zone: Rect2, joueur: Dictionary, bord: Color = Color.TRANSPARENT, rond: bool = false) -> Control:
	if not rond:
		var image: Control = G.portrait_lazy(int(joueur.get("portraitIndex", 0)), C.px(zone.size.x), joueur)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(image)
		D.place(image, zone)
		return image
	var cadre := D.rect(parent, zone, Charte.PANNEAU_3, 999, bord)
	if bord != Color.TRANSPARENT: (cadre.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(3)))
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var im: Control = G.portrait_lazy(int(joueur.get("portraitIndex", 0)), C.px(zone.size.x), joueur)
	im.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(im)
	D.place(im, Rect2(0, zone.size.y * .04, zone.size.x, zone.size.y * 1.12))
	return cadre

## Cellule « joueur » d'une ligne (comme l'Effectif) : visage, nom, « i » ; survol du nom ou du « i » = carte joueur
## (si `source`), le clic garde l'action de la ligne.
static func cellule_joueur(ctx: Dictionary, ligne: Control, x: float, h: float, base: float, p: Dictionary, largeur: float, source: String = "academy") -> void:
	portrait(ligne, Rect2(x, (h - 30) / 2.0, 31, 30), p)
	var nom := str(p.get("name", ""))
	var l := minf(largeur - 80, largeur(nom, 20))
	var t := texte(ligne, x + 42, base, nom, 20, Charte.IVOIRE, largeur - 80)
	t.name = "CentreNom"
	if source.is_empty() or str(p.get("id", "")).is_empty(): return
	var zone := Control.new()
	zone.name = "CentreNomSurvol"
	zone.mouse_filter = Control.MOUSE_FILTER_PASS
	ligne.add_child(zone)
	D.place(zone, Rect2(x, 2, 42 + l + 4, h - 4))
	CarteSurvol.lier(ctx.app, zone, str(p.id), source)
	var taille_i := maxf(20.0, ceilf(16.0 / C.density))
	CarteSurvol.icone(ctx.app, ligne, Rect2(x + 42 + l + 10, (h - taille_i) / 2.0, taille_i, taille_i), str(p.id), source)

## Barre fine + texte à droite (minutes, nombre de jeunes…).
static func barre(parent: Control, zone: Rect2, part: float, couleur: Color, valeur: String) -> void:
	var rail := Rect2(zone.position.x, zone.position.y + zone.size.y / 2.0 - 4, zone.size.x - 118, 8)
	D.rect(parent, rail, Charte.PANNEAU_3, Charte.RAYON_PILULE)
	if part > 0.0: D.rect(parent, Rect2(rail.position, Vector2(maxf(8.0, rail.size.x * clampf(part, 0, 1)), 8)), couleur, Charte.RAYON_PILULE)
	texte(parent, zone.end.x, zone.position.y + zone.size.y / 2.0 + 7, valeur, 19, couleur, 112, HORIZONTAL_ALIGNMENT_RIGHT, 700, false)

## Crans (niveau, observations).
static func crans(parent: Node, x: float, y: float, pleins: int, total: int, couleur: Color, largeur: float = 30.0, hauteur: float = 10.0) -> void:
	for i in total:
		D.rect(parent, Rect2(x + i * (largeur + 5.0), y, largeur, hauteur), couleur if i < pleins else Charte.PANNEAU_3, Charte.RAYON_PILULE)

## Disque aux initiales (blason sobre d'un centre ou d'un club formateur).
static func blason(parent: Control, zone: Rect2, nom: String, teinte: Color) -> void:
	var rond := D.rect(parent, zone, Charte.PANNEAU_3.lerp(teinte, .35), 999, teinte)
	(rond.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(1, C.px(2)))
	var s := ""
	for m: String in nom.split(" ", false):
		if m.length() > 0 and m[0] == m[0].to_upper() and s.length() < 3: s += m[0]
	chiffre(rond, zone.size.x / 2.0, zone.size.y / 2.0 + zone.size.y * .17, s if not s.is_empty() else "XV", int(zone.size.y * .42), Charte.IVOIRE, zone.size.x - 4, HORIZONTAL_ALIGNMENT_CENTER)

# --- Liste à lignes (gabarit de l'Effectif) -------------------------------------------------------------------------

## Liste triable : bandeau (filtres posés par l'appelant dans ses `haut_filtres` premières unités + en-têtes de
## colonnes), lignes en boutons au survol commun (bande claire + liseré club), regroupements facultatifs.
## `colonnes` : [{k, t, x, w, a, tri}] ; `cellule(ligne, colonne, element, h, base)` ; `cle_tri(element, k)` ;
## `groupes` : [[titre, couleur, filtre(element) -> bool]] ; `au_clic(element, ligne)` ; `nom_ligne(element, rang)`.
static func liste(ctx: Dictionary, zone: Rect2, haut_filtres: float, colonnes: Array, elements: Array, cellule: Callable, cle_tri: Callable, au_clic: Callable, nom_ligne: Callable, id: String, groupes: Array = [], tri_defaut: Array = [], h_ligne: float = LIGNE) -> Control:
	# Abscisse d'ancrage du texte : bord gauche, droit ou centre selon l'alignement (D.text ancre à droite sur x).
	for col: Dictionary in colonnes:
		var al: int = col.get("a", HORIZONTAL_ALIGNMENT_LEFT)
		col.ax = float(col.x) + (float(col.w) if al == HORIZONTAL_ALIGNMENT_RIGHT else (float(col.w) / 2.0 if al == HORIZONTAL_ALIGNMENT_CENTER else 0.0))
	h_ligne = C.reach(h_ligne)
	var tri: Variant = ctx.state.get("tri_" + id)
	if not tri is Array or (tri as Array).size() < 2: tri = tri_defaut if tri_defaut.size() >= 2 else []
	var table := Control.new()
	table.name = id
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctx.racine.add_child(table)
	D.place(table, zone)
	var entete := Control.new()
	entete.name = id + "Entete"
	entete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.add_child(entete)
	D.place(entete, Rect2(0, haut_filtres, zone.size.x, 36))
	for col: Dictionary in colonnes:
		var k := str(col.k)
		var a: HorizontalAlignment = col.get("a", HORIZONTAL_ALIGNMENT_LEFT)
		var legende := D.text(entete, col.ax, 26, str(col.t), 17, Charte.IVOIRE_3, 700, col.w, a)
		legende.name = id + "Colonne_" + k
		if not col.get("tri", false): continue
		var b := Button.new()
		b.name = id + "Tri_" + k
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		entete.add_child(b)
		var lt := R.largeur(str(col.t) + " ▼", 17, 700) + 26.0
		var x0: float = col.x - 13.0 if a == HORIZONTAL_ALIGNMENT_LEFT else (col.x + col.w - lt + 13.0 if a == HORIZONTAL_ALIGNMENT_RIGHT else col.x + col.w / 2.0 - lt / 2.0)
		D.place(b, C.reach_rect(Rect2(x0, 2, lt, 32)))
		entete.move_child(b, legende.get_index())
		var actif: bool = tri is Array and (tri as Array).size() >= 2 and str(tri[0]) == k
		Listes.styler_entete(b, legende, actif, actif and bool(tri[1]), str(col.t))
		b.pressed.connect(func():
			var desc: bool = (not bool(tri[1])) if actif else bool(col.get("desc", true))
			ctx.state["tri_" + id] = [k, desc]
			(ctx.reconstruire as Callable).call())
	Bandeau.poser(table, Rect2(0, 0, zone.size.x, haut_filtres + 36), 36)
	var tries := elements.duplicate()
	if tri is Array and (tri as Array).size() >= 2:
		var k := str(tri[0])
		var desc := bool(tri[1])
		tries.sort_custom(func(x: Variant, y: Variant):
			var vx: Variant = cle_tri.call(x, k)
			var vy: Variant = cle_tri.call(y, k)
			if vx == vy: return false
			if vx == null: return false
			if vy == null: return true
			return (vx > vy) if desc else (vx < vy))
	var defile := ScrollContainer.new()
	defile.name = id + "Defile"
	defile.follow_focus = true
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	table.add_child(defile)
	var y0 := haut_filtres + 36 + Bandeau.ECART_LIGNES
	D.place(defile, Rect2(0, y0, zone.size.x, zone.size.y - y0))
	var lignes := VBoxContainer.new()
	lignes.name = id + "Lignes"
	lignes.add_theme_constant_override("separation", C.px(2))
	lignes.custom_minimum_size.x = C.px(zone.size.x - 14)
	defile.add_child(lignes)
	var memoire: Dictionary = ctx.state.scroll
	var cle := "%s/%s" % [ctx.onglet, id]
	defile.get_v_scroll_bar().value_changed.connect(func(v: float): memoire[cle] = int(v))
	var position := int(memoire.get(cle, 0))
	if position > 0:
		(func():
			if not is_instance_valid(defile): return
			await defile.get_tree().process_frame
			await defile.get_tree().process_frame
			if is_instance_valid(defile): defile.scroll_vertical = position).call_deferred()
	var rang := 0
	var paquets: Array = groupes if not groupes.is_empty() else [["", Charte.IVOIRE, func(_e: Variant): return true]]
	for g: Array in paquets:
		var contenu := tries.filter(g[2])
		if not str(g[0]).is_empty():
			if contenu.is_empty(): continue
			_groupe(lignes, zone.size.x - 14, str(g[0]), contenu.size(), g[1], id)
		for e: Variant in contenu:
			_ligne(ctx, lignes, zone.size.x - 14, h_ligne, colonnes, e, rang, cellule, au_clic, nom_ligne)
			rang += 1
	if rang == 0:
		var vide := Control.new()
		vide.custom_minimum_size = Vector2(C.px(zone.size.x - 14), C.px(80))
		lignes.add_child(vide)
		chiffre(vide, 20, 56, "0", 40, Charte.IVOIRE_3, 200)
	return table

static func _groupe(lignes: VBoxContainer, largeur: float, titre: String, n: int, couleur: Color, id: String) -> void:
	var g := Control.new()
	g.name = id + "Groupe_" + titre.validate_node_name()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.custom_minimum_size = Vector2(C.px(largeur), C.px(40))
	lignes.add_child(g)
	D.rect(g, Rect2(0, 10, 6, 24), couleur, 3)
	var t := D.text(g, 18, 32, titre.to_upper(), 22, Charte.IVOIRE, 800, 600)
	t.add_theme_font_override("font", Charte.TITRE_EXTRA)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chiffre(g, 18 + R.largeur(titre.to_upper(), 22, 800) + 12, 32, str(n), 22, couleur, 80)

static func _ligne(ctx: Dictionary, lignes: VBoxContainer, largeur: float, h: float, colonnes: Array, e: Variant, rang: int, cellule: Callable, au_clic: Callable, nom_ligne: Callable) -> void:
	var ligne := Button.new()
	ligne.name = str(nom_ligne.call(e, rang))
	ligne.set_meta("element", e)
	ligne.custom_minimum_size = Vector2(C.px(largeur), C.px(h))
	ligne.clip_contents = true
	ligne.focus_mode = Control.FOCUS_ALL
	load("res://ui/survol_ligne.gd").appliquer(ligne, false, Color.TRANSPARENT, ctx.app.accent)
	lignes.add_child(ligne)
	var filet := Panel.new()
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filet.add_theme_stylebox_override("panel", plat(Charte.FILET, Color.TRANSPARENT, 0, 0))
	ligne.add_child(filet)
	filet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	filet.offset_top = -1.0
	var base := h / 2.0 + 7.0
	for col: Dictionary in colonnes: cellule.call(ligne, col, e, h, base)
	ligne.pressed.connect(func(): au_clic.call(e, ligne))

# --- Données --------------------------------------------------------------------------------------------------------

static func trajectoire(path: String) -> Array:
	for t: Array in TRAJECTOIRES:
		if t[0] == path: return t
	return TRAJECTOIRES[0]

static func etape(p: Dictionary) -> String:
	var age := int(p.get("age", 0))
	return "u17" if age <= 17 else ("u19" if age <= 19 else "u20")

## Valeur chiffrée (niveau ou potentiel) : milieu de la fourchette si le chiffre exact est inconnu ; -1 sinon.
static func valeur(joueur: Dictionary, champ: String) -> float:
	var v: Variant = joueur.get(champ)
	if v is int or v is float: return float(v)
	var f: Variant = joueur.get(champ + "Range")
	if f is Dictionary and f.has("min"): return (float(f.min) + float(f.max)) / 2.0
	return -1.0

static func couleur(v: float) -> Color:
	return Charte.couleur_attribut(v) if v >= 0.0 else Charte.IVOIRE_3

static func niveau_txt(p: Dictionary) -> String:
	return G.rating_text(p, true)

static func potentiel_txt(p: Dictionary) -> String:
	return G.potential_text(p)

## Envoie une commande du Centre (mêmes commandes et confirmations de dépense que la vue des parcours).
static func envoyer(ctx: Dictionary, commande: String, payload: Dictionary = {}, cout: int = -1, titre: String = "") -> void:
	if ctx.data.get("locked", false) or ctx.app.waiting: return
	var detail := "Confirmer cette décision ?" if cout == 0 else "Dépense de %s pour le centre. Confirmer ?" % G.euros(cout)
	Academy._send(ctx.app, ctx.data, commande, payload, titre if cout >= 0 else "", detail if cout >= 0 else "")

static func cout(ctx: Dictionary, cle: String, defaut: int) -> int:
	return Academy.cost(ctx.data, cle, defaut)

static func joueur(data: Dictionary, id: String) -> Dictionary:
	for p: Dictionary in data.get("players", []):
		if str(p.id) == id: return p
	return {}

static func _entree(liste_: Array, id: String, champ: String) -> String:
	for p: Dictionary in liste_:
		if str(p.get("id", "")) == id: return str(p.get(champ, ""))
	return ""

static func ouvrir_fiche(ctx: Dictionary, id: String) -> void:
	if PetiteFenetre.ouverte(ctx.page.get_tree()) != null: PetiteFenetre.fermer_derniere(ctx.page.get_tree())
	ctx.app.selected_player = id
	ctx.app.navigation_controller.open_entity({"kind": "player", "id": id, "section": ""})

# --- Petite fenêtre du parcours individuel --------------------------------------------------------------------------

const NOM_FENETRE := "CentreVisuelParcours"

## Une ligne de réglage dans une fenêtre : intitulé court à gauche, pilules à droite. Renvoie le bas.
static func reglage(parent: Control, x: float, y: float, largeur: float, titre: String, defs: Array, courant: Variant, choisir: Callable, id: String) -> float:
	texte(parent, x, y + 27, titre.to_upper(), 17, Charte.IVOIRE_3, 230, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
	var taille := pilules(parent, x + 240, y, defs, courant, choisir, id, 40.0, 19, largeur - 240)
	return y + taille.y + 14.0

## Parcours individuel d'un Espoir : en-tête (visage, poste, âge, niveau, potentiel, condition, minutes) puis chaque
## réglage en ligne de pastilles compactes. La couleur d'une pastille choisie est celle de sa donnée.
static func fenetre_parcours(ctx: Dictionary, id: String) -> void:
	var data: Dictionary = ctx.data
	var p := joueur(data, id)
	if p.is_empty(): return
	ctx.state.fenetre = {"kind": "joueur", "id": id}
	var etat: Dictionary = ctx.state
	var L := 1840.0
	var H := 640.0
	var fond := Fenetre.ouvrir(ctx.page, NOM_FENETRE, str(p.name).to_upper(), "school", L, H, func(): etat.erase("fenetre"))
	var verrou: bool = data.get("locked", false)
	var traj := trajectoire(str(p.path))
	portrait(fond, Rect2(30, 78, 96, 96), p, traj[3], true)
	texte(fond, 146, 110, "%s · %s ans" % [p.pos, G.n(p.age)], 21, Charte.IVOIRE_2, 420)
	R.pastille(fond, 146, 150, str(traj[1]), traj[3], str(traj[2]), NOM_FENETRE + "Trajectoire", 19)
	var x := 620.0
	for f: Array in [[niveau_txt(p), "NIVEAU", couleur(valeur(p, "rating"))], [potentiel_txt(p), "POTENTIEL", couleur(valeur(p, "potential"))], ["%d %%" % int(p.condition), "CONDITION", Charte.CONDITION]]:
		chiffre(fond, x, 140, f[0], 54, f[2], 220)
		texte(fond, x, 168, f[1], 16, Charte.IVOIRE_3, 220, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
		x += 220.0
	var cible := float(p.target)
	texte(fond, 1290, 104, "MINUTES", 16, Charte.IVOIRE_3, 200, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
	barre(fond, Rect2(1290, 116, 380, 36), float(p.minutes) / (cible if cible > 0 else 480.0), MINUTES, "%s / %s" % [mille(p.minutes), mille(cible)] if cible > 0 else "%s min" % mille(p.minutes))
	pilule(fond, 1690, 98, "Fiche", Charte.IVOIRE, false, func(): ouvrir_fiche(ctx, id), NOM_FENETRE + "Fiche")
	D.line(fond, Vector2(30, 198), Vector2(L - 30, 198))
	var envoi := func(commande: String, cle: String) -> Callable:
		return func(v: Variant): envoyer(ctx, commande, {"playerId": id, cle: v})
	var col := (L - 60.0 - 50.0) / 2.0
	var x1 := 30.0
	var x2 := 30.0 + col + 50.0
	var y := 214.0
	var a := not verrou
	var traj_defs: Array = []
	for t: Array in TRAJECTOIRES: traj_defs.append([t[0], t[1], t[3], "", a])
	y = reglage(fond, x1, y, col, "Trajectoire", traj_defs, p.path, envoi.call("academy_path", "strategy"), "CVTrajectoire")
	y = reglage(fond, x1, y, col, "Minutes visées", [[480, "480", MINUTES, "", a], [960, "960", MINUTES, "", a], [1440, "1 440", MINUTES, "", a]], int(p.target) if cible > 0 else null, envoi.call("academy_target", "minutes"), "CVMinutes")
	y = reglage(fond, x1, y, col, "Objectif", [["minutes", "Temps de jeu", MINUTES, "", a], ["progression", "Progression", PROGRES, "", a], ["regularite", "Régularité", COHESION, "", a]], _entree(data.get("plans", []), id, "target"), envoi.call("academy_plan", "target"), "CVObjectif")
	y = reglage(fond, x1, y, col, "Spécialisation", [["puissance", "Puissance", ALERTE, "", a], ["vitesse", "Vitesse", MINUTES, "", a], ["endurance", "Endurance", PROGRES, "", a], ["technique", "Technique", REPUTATION, "", a]], p.get("program"), envoi.call("academy_specialize", "kind"), "CVSpecialisation")
	y = reglage(fond, x1, y, col, "Charge", [["allegee", "Allégée", Charte.REPOS, "", a], ["equilibree", "Équilibrée", Charte.NORMAL, "", a], ["intensive", "Intensive", Charte.INTENSIF, "", a]], p.get("load"), envoi.call("academy_load", "load"), "CVCharge")
	y = reglage(fond, x1, y, col, "Entretien", [["minutes", "Minutes", MINUTES, "", a], ["promouvoir", "Promotion", DEPENSE, "", a], ["preter", "Prêt", COHESION, "", a], ["refuser", "Refus", ALERTE, "", a]], _entree(data.get("promises", []), id, "answer"), envoi.call("academy_interview", "answer"), "CVEntretien")
	y = reglage(fond, x1, y, col, "Ambition", [["accompagner", "Accompagner", PROGRES, "", a], ["patienter", "Patienter", COHESION, "", a], ["professionnel", "Passer pro", DEPENSE, "", a], ["pret", "Prêt", REPUTATION, "", a]], null, envoi.call("academy_ambition", "decision"), "CVAmbition")
	# Colonne de droite : accompagnement, mentor, contrats.
	var mentor := cout(ctx, "mentor", 8000)
	var am: bool = a and not bool(data.get("weekMentored", false))
	var y2 := 214.0
	y2 = reglage(fond, x2, y2, col, "Accompagnement · " + euros(mentor), [["technique", "Technique", REPUTATION, "", am], ["mental", "Mental", COHESION, "", am], ["physique", "Physique", ALERTE, "", am]], null, func(v: Variant): envoyer(ctx, "academy_mentor", {"playerId": id, "focus": v}, mentor, "Accompagnement " + str(v)), "CVAccompagnement")
	y2 = _mentors(ctx, fond, x2, y2, col, p, a)
	var engagements: Array = []
	var pros: Array = []
	for an in [1, 2, 3]:
		var frais := int(p.contractFees[an - 1]) if p.get("contractFees") is Array and p.contractFees.size() >= an else 0
		var salaire := int(p.promotionSalary[an - 1]) if p.get("promotionSalary") is Array and p.promotionSalary.size() >= an else 0
		engagements.append([an, "%d an%s" % [an, "s" if an > 1 else ""], COHESION, euros(frais), a])
		pros.append([an, "%d an%s" % [an, "s" if an > 1 else ""], DEPENSE, G.salary(salaire), a and data.get("promotionAvailable", false)])
	y2 = reglage(fond, x2, y2, col, "Contrat Espoir", engagements, null, func(v: Variant): envoyer(ctx, "academy_contract", {"playerId": id, "years": v}, int(p.contractFees[int(v) - 1]), "Contrat Espoir"), "CVEngagement")
	y2 = reglage(fond, x2, y2, col, "Premier contrat pro", pros, null, func(v: Variant):
		var salaire := int(p.promotionSalary[int(v) - 1])
		Academy._send(ctx.app, data, "academy_promote", {"playerId": id, "years": v}, "Premier contrat professionnel", "%s · %s · %d saison(s)" % [p.name, G.salary(salaire), int(v)]), "CVPro")
	var autres: Array = [["u20", "Stage U20", COHESION, "", a and not (int(p.age) > 20 or int(p.get("injury", 0)) > 0)]]
	for offre: Dictionary in data.get("offers", []):
		if str(offre.id) == id and not offre.get("clubs", []).is_empty():
			autres.append(["fideliser", "Fidéliser", ALERTE, euros(offre.fee), a and not offre.get("retained", false)])
	reglage(fond, x2, y2, col, "Autres", autres, null, func(v: Variant): _autre(ctx, id, str(v)), "CVAutres")

static func _autre(ctx: Dictionary, id: String, quoi: String) -> void:
	if quoi == "u20":
		envoyer(ctx, "academy_u20", {"playerId": id})
		return
	for offre: Dictionary in ctx.data.get("offers", []):
		if str(offre.id) == id: envoyer(ctx, "academy_retain", {"playerId": id, "clubId": offre.clubs[0].clubId}, int(offre.fee), "Fidéliser")

## Mentors : visages des professionnels du même poste (23 ans et plus) en pastilles, le choisi en aplat.
static func _mentors(ctx: Dictionary, parent: Control, x: float, y: float, largeur: float, p: Dictionary, actif: bool) -> float:
	texte(parent, x, y + 27, "MENTOR", 17, Charte.IVOIRE_3, 230, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
	var seniors: Array = ctx.data.get("seniors", []).filter(func(s: Dictionary): return s.pos == p.pos and int(s.age) >= 23)
	if seniors.is_empty():
		texte(parent, x + 240, y + 28, "—", 22, Charte.IVOIRE_3)
		return y + 54.0
	var cx := x + 240.0
	for s: Dictionary in seniors.slice(0, 4):
		var choisi := str(p.get("mentor", "")) == str(s.id)
		var mots := str(s.name).split(" ")
		var nom: String = mots[mots.size() - 1]
		var l := largeur(nom, 19) + largeur(niveau_txt(s), 19, false, 700) + 80.0
		if cx + l > x + largeur: break
		var sid := str(s.id)
		var b := zone_cliquable(parent, Rect2(cx, y, l, 40), func(): envoyer(ctx, "academy_pair", {"playerId": str(p.id), "seniorId": sid}), "CVMentor_" + sid.validate_node_name(), str(s.name), Charte.RAYON_PILULE)
		b.add_theme_stylebox_override("normal", plat(Charte.PANNEAU_2.lerp(REPUTATION, .35) if choisi else Color.TRANSPARENT, REPUTATION if choisi else Charte.FILET, 1, Charte.RAYON_PILULE))
		b.disabled = not actif
		portrait(b, Rect2(4, 4, 32, 32), s, Color.TRANSPARENT, true)
		texte(b, 44, 27, nom, 19, Charte.IVOIRE, l)
		texte(b, 52 + largeur(nom, 19), 27, niveau_txt(s), 19, couleur(valeur(s, "rating")), 60, HORIZONTAL_ALIGNMENT_LEFT, 700)
		cx += l + 8.0
	return y + 54.0

## Petite fenêtre « liste » : lignes cliquables (clubs d'accueil, candidats…). `elements` = [{id, libelle, sous, couleur}].
static func fenetre_liste(ctx: Dictionary, nom: String, titre: String, icone_id: String, elements: Array, choisir: Callable) -> void:
	var L := 1000.0
	var H := 860.0
	var fond := Fenetre.ouvrir(ctx.page, nom, titre.to_upper(), icone_id, L, H)
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fond.add_child(defile)
	D.place(defile, Rect2(24, 80, L - 48, H - 104))
	var lignes := VBoxContainer.new()
	lignes.add_theme_constant_override("separation", C.px(2))
	lignes.custom_minimum_size.x = C.px(L - 66)
	defile.add_child(lignes)
	for i in elements.size():
		var e: Dictionary = elements[i]
		var ligne := Button.new()
		ligne.name = "%sLigne%d" % [nom, i]
		ligne.custom_minimum_size = Vector2(C.px(L - 66), C.px(C.reach(LIGNE)))
		load("res://ui/survol_ligne.gd").appliquer(ligne, false, Color.TRANSPARENT, ctx.app.accent)
		lignes.add_child(ligne)
		var teinte: Color = e.get("couleur", COULEURS[i % COULEURS.size()])
		blason(ligne, Rect2(8, 5, 32, 32), str(e.libelle), teinte)
		texte(ligne, 54, 28, str(e.libelle), 20, Charte.IVOIRE, 560)
		texte(ligne, L - 90, 28, str(e.get("sous", "")), 18, Charte.IVOIRE_2, 300, HORIZONTAL_ALIGNMENT_RIGHT)
		var v: Variant = e.id
		ligne.pressed.connect(func():
			Fenetre.fermer(ctx.page, nom)
			choisir.call(v))
