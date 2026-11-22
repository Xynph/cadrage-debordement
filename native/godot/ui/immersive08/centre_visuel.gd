extends RefCounted
## Centre de formation « plus visuel » (demande de Léo du 22/11/2026 : écrans du Centre « pas très visuels »).
## Deux directions à comparer sur planche, jamais intégrées sans son choix : `CD_VARIANTE_VISUELLE=A` (cartes des
## Espoirs, réglages en petites fenêtres de tuiles) ou `B` (chemin de l'académie à l'équipe première). Sans variante,
## le Centre garde sa vue actuelle (centre_canvas.gd + academy_pathways_view.gd).
## Ce fichier porte le commun aux deux directions : barre d'onglets, zone qui défile, portraits ronds liés à la carte
## joueur au survol, envoi des commandes (mêmes commandes et confirmations que la vue actuelle), palette des données
## et petite fenêtre du parcours individuel d'un Espoir. Coordonnées en unités du gabarit (toile 2248 × 1230).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/carnet_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")
const Academy = preload("res://ui/academy_pathways_view.gd")

## Couleur franche par donnée (palette commune de charte.gd, retour de Léo du 21/11/2026) : toujours avec un chiffre,
## un mot ou une forme.
const COHESION := Charte.MORAL           ## bleu
const REPUTATION := Charte.CONFIANCE     ## violet
const MINUTES := Charte.REPOS            ## turquoise
const PROGRES := Charte.GAIN             ## vert
const DEPENSE := Charte.INTENSIF         ## orange : ce qui coûte
const ALERTE := Charte.PERTE             ## rouge
const NEUTRE := Charte.IVOIRE_2

const ONGLETS := [
	["Centre", "school"], ["Parcours", "people"], ["Centres", "search"],
	["Filières", "globe"], ["Passerelle pro", "bus"], ["Générations", "trophy"],
]

## Trajectoire d'un Espoir : [valeur moteur, libellé, icône, couleur].
const TRAJECTOIRES := [
	["equilibre", "Équilibre", "target", Charte.MORAL],
	["minutes", "Minutes", "clock", Charte.REPOS],
	["progression", "Potentiel", "rating", Charte.CONFIANCE],
	["professionnel", "Passage pro", "trophy", Charte.INTENSIF],
]

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

static func _script(v: String) -> Script:
	return load("res://ui/immersive08/centre_visuel_%s.gd" % v.to_lower())

# --- Construction ---------------------------------------------------------------------------------------------------

## Pose la direction `v` dans `surface` (panneau de travail du Centre). `page` = toile du Centre (petites fenêtres).
static func construire(app: Control, page: Control, surface: Control, v: String) -> void:
	for enfant in surface.get_children():
		surface.remove_child(enfant)
		enfant.queue_free()
	var data: Dictionary = app.model.get("clubLife", {}).get("academyPathways", {})
	var state: Dictionary = app.management_ui.immersive_centre
	if not state.get("scroll") is Dictionary: state.scroll = {}
	var onglet := str(state.get("tab", ""))
	if not ONGLETS.any(func(o: Array): return o[0] == onglet): onglet = "Centre"
	var largeur := surface.size.x / C.density
	var hauteur := surface.size.y / C.density
	var ctx := {"app": app, "page": page, "surface": surface, "data": data, "state": state, "variante": v, "onglet": onglet,
		"largeur": largeur, "hauteur": hauteur}
	ctx.reconstruire = func(): construire(app, page, surface, v)
	var racine := Control.new()
	racine.name = "CentreVisuel"
	racine.set_meta("onglet", onglet)
	racine.set_meta("variante", v)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(racine)
	D.place(racine, Rect2(0, 0, largeur, hauteur))
	ctx.racine = racine
	_onglets(ctx)
	var zone := Rect2(16, 84, largeur - 32, hauteur - 96)
	_script(v).onglet(ctx, onglet, zone)
	var rouvrir: Variant = state.get("fenetre")
	if rouvrir is Dictionary and str(rouvrir.get("kind", "")) == "joueur":
		(func(): if is_instance_valid(page) and page.is_inside_tree(): fenetre_parcours(ctx, str(rouvrir.get("id", "")))).call_deferred()

static func _compte(data: Dictionary, onglet: String) -> String:
	match onglet:
		"Parcours": return G.n(data.get("players", []).size())
		"Centres": return G.n(data.get("centers", []).filter(func(c: Dictionary): return c.get("scouted", false) and not c.get("own", false)).size())
		"Filières": return G.n(data.get("prospects", []).size())
		"Passerelle pro": return G.n(data.get("loans", []).size())
		"Générations": return G.n(data.get("generations", []).size())
	return ""

## Barre d'onglets en pilules (charte §7.1) : icône, nom et compteur ; actif = aplat crème.
static func _onglets(ctx: Dictionary) -> void:
	var x := 16.0
	for o: Array in ONGLETS:
		var nom: String = o[0]
		var actif: bool = nom == ctx.onglet
		var compte := _compte(ctx.data, nom)
		var libelle := nom if compte.is_empty() else "%s   %s" % [nom, compte]
		var largeur := C.BOLD.get_string_size(libelle, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(25))).x / C.density + 78.0
		var b := Button.new()
		b.name = "CentreVisuelOnglet_" + nom.validate_node_name()
		b.text = libelle
		b.toggle_mode = true
		b.button_pressed = actif
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", C.BOLD)
		b.add_theme_font_size_override("font_size", maxi(12, C.px(25)))
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", C.px(24))
		b.add_theme_constant_override("h_separation", C.px(10))
		D.tab_state(b, Vector2(largeur, 52), actif, str(o[1]))
		ctx.racine.add_child(b)
		D.place(b, Rect2(x, 16, largeur, 52))
		b.pressed.connect(func():
			ctx.state.tab = nom
			ctx.state.erase("fenetre")
			(ctx.reconstruire as Callable).call())
		x += largeur + 10.0

## Zone qui défile verticalement ; renvoie le contenu (unités du gabarit), haut `hauteur_contenu`.
static func zone_defilante(ctx: Dictionary, zone: Rect2, hauteur_contenu: float, nom: String = "CentreVisuelDefile") -> Control:
	var defile := ScrollContainer.new()
	defile.name = nom
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.follow_focus = true
	ctx.racine.add_child(defile)
	D.place(defile, zone)
	var contenu := Control.new()
	contenu.name = nom + "Contenu"
	contenu.mouse_filter = Control.MOUSE_FILTER_PASS
	contenu.custom_minimum_size = Vector2(zone.size.x - 18, maxf(hauteur_contenu, zone.size.y)) * C.density
	defile.add_child(contenu)
	var cle := "%s/%s" % [ctx.onglet, nom]
	var memoire: Dictionary = ctx.state.scroll
	defile.get_v_scroll_bar().value_changed.connect(func(valeur: float): memoire[cle] = int(valeur))
	var position := int(memoire.get(cle, 0))
	if position > 0:
		(func():
			if not is_instance_valid(defile): return
			await defile.get_tree().process_frame
			if is_instance_valid(defile): defile.scroll_vertical = position).call_deferred()
	return contenu

# --- Pièces ---------------------------------------------------------------------------------------------------------

## Portrait rond (visage du pack ou généré), cerclé de `bord` ; survol = carte joueur (Espoirs : source « academy »).
static func portrait(ctx: Dictionary, parent: Control, zone: Rect2, joueur: Dictionary, bord: Color = Color.TRANSPARENT, epaisseur: int = 3, source: String = "academy") -> Panel:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_3, 999, bord)
	cadre.name = "Portrait_" + str(joueur.get("id", "")).validate_node_name()
	if bord != Color.TRANSPARENT: (cadre.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(epaisseur)))
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var image: Control = G.portrait_lazy(int(joueur.get("portraitIndex", 0)), C.px(zone.size.x), joueur)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(image)
	D.place(image, Rect2(0, zone.size.y * .04, zone.size.x, zone.size.y * 1.12))
	if not source.is_empty() and not str(joueur.get("id", "")).is_empty():
		cadre.mouse_filter = Control.MOUSE_FILTER_PASS
		CarteSurvol.lier(ctx.app, cadre, str(joueur.id), source)
	return cadre

## Bouton plat couvrant `zone` de `parent` : survol éclairé, main, focus (retour commun des tuiles).
static func cliquable(parent: Control, zone: Rect2, action: Callable, id: String, libelle: String, rayon: int = Charte.RAYON_CARTE) -> Button:
	var porteur := Control.new()
	porteur.name = id + "Zone"
	porteur.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(porteur)
	D.place(porteur, zone)
	return Pieces.rendre_cliquable(porteur, zone.size, action, id, libelle, "", rayon)

## Texte en police titre (Barlow Condensed extra-gras) : chiffres et noms.
static func chiffre(parent: Node, x: float, base: float, valeur: Variant, taille: int, couleur: Color = Charte.IVOIRE, largeur: float = 0.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := D.text(parent, x, base, valeur, taille, couleur, 800, largeur, align)
	l.add_theme_font_override("font", Charte.TITRE_EXTRA)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func petit(parent: Node, x: float, base: float, valeur: Variant, taille: int = 16, couleur: Color = Charte.IVOIRE_2, largeur: float = 0.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := D.text(parent, x, base, valeur, taille, couleur, 700, largeur, align)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Carte (rayon 12) d'un fond teinté de `couleur` (16 %) ou neutre.
static func carte(parent: Node, zone: Rect2, couleur: Color = Color.TRANSPARENT, id: String = "") -> Panel:
	var fond := Charte.PANNEAU_2 if couleur == Color.TRANSPARENT else Charte.PANNEAU_2.lerp(couleur, .16)
	var c := D.rect(parent, zone, fond, Charte.RAYON_CARTE)
	if not id.is_empty(): c.name = id
	return c

## Icône teintée posée dans `zone`.
static func icone(parent: Node, zone: Rect2, id: String, couleur: Color) -> TextureRect:
	var i := C.icon(id, int(zone.size.x), couleur)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(i)
	D.place(i, zone)
	return i

## Petite jauge en pilule (rail + remplissage), part de 0 à 1.
static func jauge(parent: Node, zone: Rect2, part: float, couleur: Color) -> void:
	D.rect(parent, zone, Charte.PANNEAU_3, Charte.RAYON_PILULE)
	var plein := zone
	plein.size.x = maxf(zone.size.y, zone.size.x * clampf(part, 0.0, 1.0)) if part > 0.0 else 0.0
	if plein.size.x > 0: D.rect(parent, plein, couleur, Charte.RAYON_PILULE)

## Rangée de `total` crans (niveau d'installations, observations) dont `pleins` colorés.
static func crans(parent: Node, x: float, y: float, pleins: int, total: int, couleur: Color, largeur: float = 34.0, hauteur: float = 12.0) -> void:
	for i in total:
		D.rect(parent, Rect2(x + i * (largeur + 6.0), y, largeur, hauteur), couleur if i < pleins else Charte.PANNEAU_3, Charte.RAYON_PILULE)

# --- Données --------------------------------------------------------------------------------------------------------

static func trajectoire(path: String) -> Array:
	for t: Array in TRAJECTOIRES:
		if t[0] == path: return t
	return TRAJECTOIRES[0]

## Valeur chiffrée (niveau ou potentiel) pour la couleur : moyenne de la fourchette si le chiffre exact est inconnu.
static func valeur(joueur: Dictionary, champ: String) -> float:
	var v: Variant = joueur.get(champ)
	if v is int or v is float: return float(v)
	var f: Variant = joueur.get(champ + "Range")
	if f is Dictionary and f.has("min"): return (float(f.min) + float(f.max)) / 2.0
	return -1.0

static func niveau_txt(joueur: Dictionary) -> String:
	return G.rating_text(joueur, true)

static func potentiel_txt(joueur: Dictionary) -> String:
	return G.potential_text(joueur)

static func couleur(v: float) -> Color:
	return Charte.couleur_attribut(v) if v >= 0.0 else Charte.IVOIRE_3

## Envoie une commande du Centre (mêmes commandes, mêmes confirmations de dépense que la vue actuelle).
static func envoyer(ctx: Dictionary, commande: String, payload: Dictionary = {}, cout: int = -1, titre: String = "") -> void:
	if ctx.data.get("locked", false) or ctx.app.waiting: return
	var detail := "Confirmer cette décision ?" if cout == 0 else "Dépense de %s pour le centre. Confirmer ?" % G.euros(cout)
	Academy._send(ctx.app, ctx.data, commande, payload, titre if cout >= 0 else "", detail if cout >= 0 else "")

static func joueur(data: Dictionary, id: String) -> Dictionary:
	for p: Dictionary in data.get("players", []):
		if str(p.id) == id: return p
	return {}

static func plan_de(data: Dictionary, id: String) -> String:
	for p: Dictionary in data.get("plans", []):
		if str(p.get("id", "")) == id: return str(p.get("target", ""))
	return ""

static func promesse_de(data: Dictionary, id: String) -> String:
	for p: Dictionary in data.get("promises", []):
		if str(p.get("id", "")) == id: return str(p.get("answer", ""))
	return ""

# --- Petite fenêtre du parcours individuel --------------------------------------------------------------------------

const NOM_FENETRE := "CentreVisuelParcours"

## Tuile de choix : icône, mot, chiffre éventuel ; choisie = contour et fond de sa couleur.
static func tuile_choix(parent: Control, zone: Rect2, libelle: String, icone_id: String, teinte: Color, choisie: bool, action: Callable, id: String, chiffre_txt: String = "", actif: bool = true) -> Panel:
	var fond := Charte.PANNEAU_2.lerp(teinte, .30 if choisie else .08)
	var c := D.rect(parent, zone, fond, Charte.RAYON_CARTE, teinte if choisie else Color.TRANSPARENT)
	c.name = id
	if choisie: (c.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(3)))
	var encre := teinte if actif else Charte.IVOIRE_3
	if not icone_id.is_empty(): icone(c, Rect2(14, (zone.size.y - 26) / 2.0, 26, 26), icone_id, encre)
	var gauche := 50.0 if not icone_id.is_empty() else 14.0
	if chiffre_txt.is_empty():
		petit(c, gauche, zone.size.y / 2.0 + 8, libelle, 21, Charte.IVOIRE if actif else Charte.IVOIRE_3, zone.size.x - gauche - 8)
	else:
		petit(c, gauche, zone.size.y / 2.0 - 4, libelle, 18, Charte.IVOIRE if actif else Charte.IVOIRE_3, zone.size.x - gauche - 8)
		chiffre(c, gauche, zone.size.y / 2.0 + 22, chiffre_txt, 22, encre, zone.size.x - gauche - 8)
	if choisie: icone(c, Rect2(zone.size.x - 30, 8, 20, 20), "check", teinte)
	if actif: Pieces.rendre_cliquable(c, zone.size, action, id + "Lien", libelle, "", Charte.RAYON_CARTE)
	else: c.modulate = Color(1, 1, 1, .55)
	return c

## Groupe de tuiles (titre court + rangée) ; renvoie le bas du groupe.
static func groupe(parent: Control, x: float, y: float, largeur: float, titre: String, options: Array, courant: Variant, au_choix: Callable, id: String, actif: bool = true, par_ligne: int = 0) -> float:
	petit(parent, x, y + 20, titre.to_upper(), 17, Charte.IVOIRE_3, largeur)
	var n := options.size()
	var colonnes := par_ligne if par_ligne > 0 else n
	var ecart := 10.0
	var w := (largeur - ecart * (colonnes - 1)) / colonnes
	var h := 62.0 if options.any(func(o: Array): return o.size() > 4 and not str(o[4]).is_empty()) else 52.0
	for i in n:
		var o: Array = options[i]
		var zone := Rect2(x + (i % colonnes) * (w + ecart), y + 32 + floori(i / float(colonnes)) * (h + ecart), w, h)
		var valeur_o: Variant = o[0]
		var choisi: bool = courant != null and str(courant) == str(valeur_o)
		var fin_actif := actif and (o.size() <= 5 or bool(o[5]))
		tuile_choix(parent, zone, str(o[1]), str(o[2]), o[3], choisi, func(): au_choix.call(valeur_o), "%s_%s" % [id, str(valeur_o).validate_node_name()], str(o[4]) if o.size() > 4 else "", fin_actif)
	var lignes := ceili(n / float(colonnes))
	return y + 32 + lignes * (h + ecart)

## Ouvre la petite fenêtre du parcours individuel d'un Espoir : en-tête (visage, niveau, potentiel, minutes) puis
## chaque réglage en tuiles. Commun aux deux directions.
static func fenetre_parcours(ctx: Dictionary, id: String) -> void:
	var data: Dictionary = ctx.data
	var p := joueur(data, id)
	if p.is_empty(): return
	ctx.state.fenetre = {"kind": "joueur", "id": id}
	var etat: Dictionary = ctx.state
	var L := 1960.0
	var H := 1130.0
	var fond := Fenetre.ouvrir(ctx.page, NOM_FENETRE, str(p.name).to_upper(), "school", L, H, func(): etat.erase("fenetre"))
	var verrou: bool = data.get("locked", false)
	var traj := trajectoire(str(p.path))
	# En-tête : visage, poste, âge, niveau et potentiel en grand, anneau des minutes.
	portrait(ctx, fond, Rect2(30, 80, 120, 120), p, traj[3], 4)
	petit(fond, 170, 112, "%s · %s ans" % [p.pos, G.n(p.age)], 22, Charte.IVOIRE_2, 520)
	Pieces.pastille(fond, 170, 132, str(traj[1]), str(traj[2]), NOM_FENETRE + "Trajectoire", "", traj[3])
	var nv := valeur(p, "rating")
	var pt := valeur(p, "potential")
	_bloc_chiffre(fond, Rect2(700, 76, 200, 128), niveau_txt(p), "Niveau", couleur(nv))
	_bloc_chiffre(fond, Rect2(915, 76, 240, 128), potentiel_txt(p), "Potentiel", couleur(pt))
	_bloc_chiffre(fond, Rect2(1170, 76, 200, 128), "%d%%" % int(p.condition), "Condition", Charte.CONDITION)
	var cible := float(p.target)
	var anneau = load("res://ui/jauge_anneau.gd").new(float(p.minutes), "Minutes", MINUTES, maxf(cible, float(p.minutes)) if cible > 0 else maxf(480.0, float(p.minutes)), "clock")
	anneau.diametre = 96.0
	anneau.name = NOM_FENETRE + "Minutes"
	fond.add_child(anneau)
	D.place(anneau, Rect2(1400, 70, 156, 142))
	var aller_fiche := func():
		PetiteFenetre.fermer_derniere(ctx.page.get_tree())
		ctx.app.selected_player = id
		ctx.app.navigation_controller.open_entity({"kind": "player", "id": id, "section": ""})
	Pieces.pastille(fond, 1600, 104, "Fiche", "people", NOM_FENETRE + "Fiche", "", Charte.IVOIRE, Charte.PANNEAU_3, aller_fiche)
	D.line(fond, Vector2(30, 222), Vector2(L - 30, 222))
	var envoi := func(commande: String, cle: String) -> Callable:
		return func(v: Variant): envoyer(ctx, commande, {"playerId": id, cle: v})
	var col := (L - 60.0 - 40.0) / 2.0
	var x1 := 30.0
	var x2 := 30.0 + col + 40.0
	var y := 236.0
	var opts_traj: Array = []
	for t: Array in TRAJECTOIRES: opts_traj.append([t[0], t[1], t[2], t[3]])
	y = groupe(fond, x1, y, col, "Trajectoire", opts_traj, p.path, envoi.call("academy_path", "strategy"), "CVTrajectoire", not verrou) + 14
	y = groupe(fond, x1, y, col, "Objectif de minutes", [[480, "480", "clock", MINUTES], [960, "960", "clock", MINUTES], [1440, "1 440", "clock", MINUTES]], int(p.target) if float(p.target) > 0 else null, envoi.call("academy_target", "minutes"), "CVMinutes", not verrou) + 14
	y = groupe(fond, x1, y, col, "Objectif individuel", [["minutes", "Temps de jeu", "clock", MINUTES], ["progression", "Progression", "rating", PROGRES], ["regularite", "Régularité", "renew", COHESION]], plan_de(data, id), envoi.call("academy_plan", "target"), "CVObjectif", not verrou) + 14
	y = groupe(fond, x1, y, col, "Spécialisation", [["puissance", "Puissance", "shield", ALERTE], ["vitesse", "Vitesse", "arrow", MINUTES], ["endurance", "Endurance", "heart", PROGRES], ["technique", "Technique", "ball", REPUTATION]], p.get("program"), envoi.call("academy_specialize", "kind"), "CVSpecialisation", not verrou) + 14
	y = groupe(fond, x1, y, col, "Charge de travail", [["allegee", "Allégée", "heart", Charte.REPOS], ["equilibree", "Équilibrée", "target", Charte.NORMAL], ["intensive", "Intensive", "train", Charte.INTENSIF]], p.get("load"), envoi.call("academy_load", "load"), "CVCharge", not verrou)
	# Colonne de droite : accompagnement, mentor, entretien, ambition, contrats.
	var mentor := Academy.cost(data, "mentor", 8000)
	var y2 := 236.0
	y2 = groupe(fond, x2, y2, col, "Accompagnement de la semaine", [["technique", "Technique", "ball", REPUTATION, G.euros(mentor)], ["mental", "Mental", "heart", COHESION, G.euros(mentor)], ["physique", "Physique", "shield", ALERTE, G.euros(mentor)]], null, func(v: Variant): envoyer(ctx, "academy_mentor", {"playerId": id, "focus": v}, mentor, "Accompagnement " + str(v)), "CVAccompagnement", not verrou and not data.get("weekMentored", false)) + 14
	y2 = _mentors(ctx, fond, x2, y2, col, p, verrou) + 14
	y2 = groupe(fond, x2, y2, col, "Entretien", [["minutes", "Minutes", "clock", MINUTES], ["promouvoir", "Promotion", "trophy", Charte.INTENSIF], ["preter", "Prêt", "bus", COHESION], ["refuser", "Refus", "lock", ALERTE]], promesse_de(data, id), envoi.call("academy_interview", "answer"), "CVEntretien", not verrou) + 14
	y2 = groupe(fond, x2, y2, col, "Ambition", [["accompagner", "Accompagner", "people", PROGRES], ["patienter", "Patienter", "hourglass", COHESION], ["professionnel", "Passer pro", "trophy", Charte.INTENSIF], ["pret", "Prêt", "bus", REPUTATION]], null, envoi.call("academy_ambition", "decision"), "CVAmbition", not verrou) + 14
	_contrats(ctx, fond, x2, y2, col, p, verrou)

static func _bloc_chiffre(parent: Control, zone: Rect2, valeur_txt: String, legende: String, teinte: Color) -> void:
	var c := carte(parent, zone, teinte)
	c.name = "CVBloc_" + legende.validate_node_name()
	chiffre(c, zone.size.x / 2.0, 78, valeur_txt, 52, teinte, zone.size.x - 12, HORIZONTAL_ALIGNMENT_CENTER)
	petit(c, zone.size.x / 2.0, 112, legende.to_upper(), 16, Charte.IVOIRE_2, zone.size.x - 12, HORIZONTAL_ALIGNMENT_CENTER)

## Mentors : visages des professionnels du même poste (23 ans et plus), le choisi cerclé.
static func _mentors(ctx: Dictionary, parent: Control, x: float, y: float, largeur: float, p: Dictionary, verrou: bool) -> float:
	petit(parent, x, y + 20, "MENTOR DE SAISON", 17, Charte.IVOIRE_3, largeur)
	var seniors: Array = ctx.data.get("seniors", []).filter(func(s: Dictionary): return s.pos == p.pos and int(s.age) >= 23)
	if seniors.is_empty():
		petit(parent, x, y + 66, "—", 26, Charte.IVOIRE_3)
		return y + 84
	var cote := 64.0
	for i in mini(seniors.size(), 6):
		var s: Dictionary = seniors[i]
		var choisi := str(p.get("mentor", "")) == str(s.id)
		var bx := x + i * (cote + 128.0)
		portrait(ctx, parent, Rect2(bx, y + 34, cote, cote), s, REPUTATION if choisi else Color.TRANSPARENT, 3, "squad")
		var nom := str(s.name).split(" ")
		petit(parent, bx + cote + 8, y + 62, nom[nom.size() - 1], 17, Charte.IVOIRE if choisi else Charte.IVOIRE_2, 116)
		chiffre(parent, bx + cote + 8, y + 90, niveau_txt(s), 20, couleur(valeur(s, "rating")), 116)
		if not verrou:
			var sid := str(s.id)
			cliquable(parent, Rect2(bx - 4, y + 30, cote + 124, cote + 8), func(): envoyer(ctx, "academy_pair", {"playerId": str(p.id), "seniorId": sid}), "CVMentor_" + sid.validate_node_name(), str(s.name), 12)
	return y + 34 + cote + 6

## Contrats : stage U20, fidélisation, engagement Espoir et premier contrat pro (1, 2 ou 3 ans) en tuiles chiffrées.
static func _contrats(ctx: Dictionary, parent: Control, x: float, y: float, largeur: float, p: Dictionary, verrou: bool) -> void:
	var data: Dictionary = ctx.data
	var id := str(p.id)
	var opts: Array = []
	for an in [1, 2, 3]:
		var frais := int(p.contractFees[an - 1]) if p.get("contractFees") is Array and p.contractFees.size() >= an else 0
		opts.append([an, "Espoir %d an%s" % [an, "s" if an > 1 else ""], "school", COHESION, G.euros(frais)])
	var bas := groupe(parent, x, y, largeur, "Engagement Espoir", opts, null, func(v: Variant):
		var frais := int(p.contractFees[int(v) - 1])
		envoyer(ctx, "academy_contract", {"playerId": id, "years": v}, frais, "Engagement Espoir"), "CVEngagement", not verrou)
	var pro: Array = []
	for an in [1, 2, 3]:
		var salaire := int(p.promotionSalary[an - 1]) if p.get("promotionSalary") is Array and p.promotionSalary.size() >= an else 0
		pro.append([an, "Pro %d an%s" % [an, "s" if an > 1 else ""], "trophy", Charte.INTENSIF, G.salary(salaire)])
	bas = groupe(parent, x, bas + 14, largeur, "Premier contrat pro", pro, null, func(v: Variant):
		var salaire := int(p.promotionSalary[int(v) - 1])
		Academy._send(ctx.app, data, "academy_promote", {"playerId": id, "years": v}, "Premier contrat professionnel", "%s · %s · %d saison(s)" % [p.name, G.salary(salaire), int(v)]), "CVPro", not verrou and data.get("promotionAvailable", false))
	var autres: Array = [["u20", "Stage U20", "flag", COHESION, "", not (int(p.age) > 20 or int(p.get("injury", 0)) > 0)]]
	for offre: Dictionary in data.get("offers", []):
		if str(offre.id) == id and not offre.get("clubs", []).is_empty():
			autres.append(["fideliser", "Fidéliser", "shield", ALERTE, G.euros(offre.fee), not offre.get("retained", false)])
	groupe(parent, x, bas + 14, largeur, "Autres décisions", autres, null, func(v: Variant):
		if str(v) == "u20": envoyer(ctx, "academy_u20", {"playerId": id})
		else:
			for offre: Dictionary in data.get("offers", []):
				if str(offre.id) == id: envoyer(ctx, "academy_retain", {"playerId": id, "clubId": offre.clubs[0].clubId}, int(offre.fee), "Fidéliser"), "CVAutres", not verrou, 2)

## Petite fenêtre de choix en tuiles (réglage du centre) : `options` = [valeur, libellé, icône, couleur, chiffre?].
static func fenetre_choix(ctx: Dictionary, nom: String, titre: String, icone_id: String, options: Array, courant: Variant, au_choix: Callable) -> void:
	var n := options.size()
	var L := clampf(140.0 + n * 250.0, 760.0, 1400.0)
	var fond := Fenetre.ouvrir(ctx.page, nom, titre.to_upper(), icone_id, L, 300.0)
	groupe(fond, 30, 76, L - 60, "", options, courant, func(v: Variant):
		Fenetre.fermer(ctx.page, nom)
		au_choix.call(v), nom + "Choix", not ctx.data.get("locked", false))
