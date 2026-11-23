extends RefCounted
## Agents de joueurs nommés (retour de Léo du 23/11/2026 : « On a l'impression de parler avec le joueur… Donne un nom à
## chaque agent. Chaque agent gère un ou plusieurs joueurs comme dans la réalité »). Pièces communes à tous les écrans
## où l'agent apparaît (discussion, offre et négociation, Réception, fiche joueur) :
##  - données : clubLife.agentsJoueurs = {joueurs: {idJoueur: idAgent}, agents: {idAgent: {id, nom, agence, age, pays,
##    rang, rangMot, cran (relation 0..4), caractere (mot découvert ou ""), total, clients: [[id, nom, poste, âge, club,
##    idClub, où], …]}}} (moteur native/engine/agents-joueurs.cjs) ;
##  - portrait d'adulte : réserve des portraits du staff (regen_portrait.gd, rôle « staff »), jamais un visage de joueur ;
##  - nom cliquable → petite fenêtre de l'agent : portrait, nom, agence, relation (5 crans), caractère (« ? » tant qu'il
##    n'est pas découvert), puis « Ses joueurs » façon Effectif (clic = fiche du joueur ou du club). Aucun chiffre du
##    moteur, aucune phrase d'explication.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Link = preload("res://ui/entity_link.gd")
const G = preload("res://ui/game_skin.gd")

const NOM := "FenetreAgentJoueur"
## Relation avec l'agent : 5 crans (moteur ton-agent.cjs : Froide ≤ −6 < Distante ≤ −2 < Neutre < 2 ≤ Bonne < 6 ≤ Proche).
const RELATIONS := [["Froide", Pastilles.ROUGE, "warning"], ["Distante", Pastilles.ORANGE, "info"], ["Neutre", Charte.IVOIRE_2, "people"],
	["Bonne", Pastilles.BLEU, "check"], ["Proche", Pastilles.VERT, "heart"]]
## Rang de l'agence : couleur franche par rang.
const RANGS := {"grande": Pastilles.VIOLET, "moyenne": Pastilles.TURQUOISE, "petite": Pastilles.BLEU}
const LIGNE_H := 46.0
const LIGNES_MAX := 9

# --- Données -----------------------------------------------------------------------------------------------------------

static func vue(app: Control) -> Dictionary:
	var vie: Variant = app.model.get("clubLife", {})
	var v: Variant = vie.get("agentsJoueurs") if vie is Dictionary else null
	return v if v is Dictionary else {}

static func id_de(app: Control, joueur_id: String) -> String:
	var j: Variant = vue(app).get("joueurs", {})
	return str(j.get(joueur_id, "")) if j is Dictionary else ""

static func agent(app: Control, agent_id: String) -> Dictionary:
	var a: Variant = vue(app).get("agents", {})
	var x: Variant = a.get(agent_id) if a is Dictionary and not agent_id.is_empty() else null
	return x if x is Dictionary else {}

## Agent d'un joueur ({} : jeune du centre sans agent, ou joueur hors projection).
static func de_joueur(app: Control, joueur_id: String) -> Dictionary:
	return agent(app, id_de(app, joueur_id))

static func cran(a: Dictionary) -> int:
	return clampi(int(a.get("cran", 2)), 0, 4)

# --- Pièces ------------------------------------------------------------------------------------------------------------

## Apparence pour la réserve de portraits du staff (adulte, costume) : même visage pour le même agent.
static func apparence(a: Dictionary) -> Dictionary:
	return {"id": "agent:" + str(a.get("id", "")), "name": str(a.get("nom", "Agent")), "age": int(a.get("age", 45)), "appearanceAge": int(a.get("age", 45)), "portraitRole": "staff", "appearanceBankVersion": 2}

## Portrait posé dans `zone` (coordonnées du gabarit) de `parent`.
static func poser_portrait(parent: Control, zone: Rect2, a: Dictionary, id: String, bord: Color = Color.TRANSPARENT) -> Panel:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_3, Charte.RAYON_CARTE, bord)
	cadre.name = id
	cadre.clip_contents = true
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	var photo := G.portrait(0, int(zone.size.x * C.density), apparence(a))
	photo.name = id + "Photo"
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(photo)
	photo.position = Vector2.ZERO
	photo.size = zone.size * C.density
	return cadre

## Petit portrait de conteneur (bulles du fil de discussion, en-têtes) : `cote` en unités du gabarit.
static func visage(a: Dictionary, cote: float, id: String = "") -> Control:
	var fond := PanelContainer.new()
	if not id.is_empty(): fond.name = id
	fond.add_theme_stylebox_override("panel", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, Charte.RAYON_PETIT, 0))
	fond.custom_minimum_size = Vector2(C.px(cote), C.px(cote))
	fond.clip_contents = true
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var photo := G.portrait(0, C.px(cote), apparence(a))
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.add_child(photo)
	return fond

## Nom de l'agent cliquable (petite fenêtre de l'agent).
static func lien_nom(app: Control, page: Control, parent: Control, zone: Rect2, a: Dictionary, taille: int, id: String, couleur: Color = Charte.IVOIRE, joueur_id: String = "", ligne: Array = []) -> Button:
	var b := Link.styled_button(parent, zone, str(a.get("nom", "Agent")), taille, couleur, id)
	b.tooltip_text = str(a.get("agence", ""))
	b.accessibility_name = "Agent " + str(a.get("nom", ""))
	var ag := str(a.get("id", ""))
	b.pressed.connect(func(): ouvrir(app, page, ag, joueur_id, ligne))
	return b

## Relation avec l'agent : le mot du cran, sa couleur et son icône (aucun chiffre).
static func relation(n: int, prefixe: String, taille := 18) -> Control:
	var r: Array = RELATIONS[clampi(n, 0, 4)]
	return Pastilles.pastille(str(r[0]), r[1], str(r[2]), "Relation avec l’agent", taille, prefixe + "Relation")

## Caractère de l'agent : le mot une fois découvert, « ? » sinon (jamais ses effets).
static func caractere(mot: String, prefixe: String, taille := 16) -> Control:
	var connu := not mot.is_empty()
	return Pastilles.pastille(mot if connu else "?", Pastilles.VIOLET if connu else Charte.IVOIRE_2, "people" if connu else "search", "Caractère de l’agent", taille, prefixe + "Caractere")

## Agence : nom et rang (grande agence, agence, indépendant) en couleur franche.
static func agence(a: Dictionary, prefixe: String, taille := 18) -> Control:
	return Pastilles.pastille(str(a.get("agence", "")), RANGS.get(str(a.get("rang", "petite")), Pastilles.BLEU), "flag", str(a.get("rangMot", "")), taille, prefixe + "Agence")

## Cinq crans de la relation (en-tête de l'agent) : le cran courant plein ; l'ancien teinté et une flèche s'il a bougé.
static func crans(parent: Control, zone: Rect2, n: int, avant: int, prefixe: String) -> void:
	var ecart := 8.0
	var lc := (zone.size.x - ecart * 4) / 5.0
	for i in 5:
		var a: Array = RELATIONS[i]
		var actif := i == n
		var ancien := i == avant and avant != n
		var case_ := D.rect(parent, Rect2(zone.position.x + i * (lc + ecart), zone.position.y, lc, zone.size.y), Color(a[1], 1.0) if actif else Color(a[1], .24 if ancien else .07), Charte.RAYON_PETIT, Color(a[1]).lightened(.55) if actif else Color.TRANSPARENT)
		if actif: (case_.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(4)
		case_.name = prefixe + "RelationCran_%d" % i
		case_.tooltip_text = str(a[0])
		case_.mouse_filter = Control.MOUSE_FILTER_PASS
		D.text(case_, lc * .5, zone.size.y * .5 + 8, str(a[0]), 21 if actif else 17, Charte.ENCRE if actif else (a[1] if ancien else Color(a[1], .55)), 800 if actif else 500, lc - 6, HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if avant != n and avant >= 0:
		var a0 := zone.position.x + avant * (lc + ecart) + lc * .5
		var a1 := zone.position.x + n * (lc + ecart) + lc * .5
		var fleche := D.rect(parent, Rect2(minf(a0, a1), zone.end.y + 6, absf(a1 - a0), 5), Charte.IVOIRE, 2)
		fleche.name = prefixe + "RelationFleche"
		D.text(parent, a1 + (6 if a1 > a0 else -26), zone.end.y + 18, "▶" if a1 > a0 else "◀", 18, Charte.IVOIRE, 800, 22)

## Ligne « Ses joueurs » d'un joueur connu de l'écran (`ou` : effectif, marche ou club) : il reste en tête et surligné
## même s'il n'est pas parmi les lignes projetées de l'agent.
static func ligne_de(p: Dictionary, ou: String) -> Array:
	return [str(p.get("id", "")), str(p.get("name", "")), str(p.get("pos", "")), p.get("age", 0), "", null, ou]

## Ligne d'un joueur de notre effectif ou du marché (projection) ; vide s'il n'y est pas.
static func ligne_connue(app: Control, joueur_id: String) -> Array:
	for cle: String in ["squad", "market"]:
		for p: Variant in app.model.get(cle, []):
			if p is Dictionary and str(p.get("id", "")) == joueur_id: return ligne_de(p, "effectif" if cle == "squad" else "marche")
	return []

## Où joue un client : chez nous (vert), libre (bleu), sinon son club.
static func _ou(c: Array) -> Array:
	match str(c[6]):
		"effectif": return ["Chez nous", Pastilles.VERT, "people"]
		"marche": return ["Libre", Pastilles.BLEU, "search"]
	return [str(c[4]), Charte.IVOIRE_2, "flag"]

## Fiche d'un client : notre joueur ou une piste du marché (fiche complète), sinon la fiche de son club.
static func ouvrir_client(app: Control, c: Array) -> void:
	match str(c[6]):
		"effectif": app.navigation_controller.open_entity({"kind": "player", "id": str(c[0])})
		"marche": app.navigation_controller.open_entity({"kind": "market", "id": str(c[0])})
		_:
			if c[5] != null: app.navigation_controller.open_entity({"kind": "club", "id": int(c[5])})

## « Ses joueurs » façon Effectif : poste, nom, âge, club ; le joueur `focus` surligné (ajouté en tête s'il n'est pas
## parmi les lignes projetées) ; « +N » au-delà. `avant_clic` est appelé avant d'ouvrir une fiche (fermer la fenêtre).
static func clients(app: Control, parent: Control, zone: Rect2, a: Dictionary, focus: String, prefixe: String, avant_clic: Callable = Callable(), lignes_max := LIGNES_MAX, focus_ligne: Array = []) -> void:
	var liste: Array = (a.get("clients", []) as Array).duplicate() if a.get("clients") is Array else []
	var total := maxi(int(a.get("total", liste.size())), liste.size())
	if not focus.is_empty():
		var i := liste.find_custom(func(c: Variant) -> bool: return c is Array and str(c[0]) == focus)
		if i > 0: liste.push_front(liste.pop_at(i))
		elif i < 0 and focus_ligne.size() >= 7: liste.push_front(focus_ligne)
	var titre := D.text(parent, zone.position.x, zone.position.y + 24, "SES JOUEURS · %d" % total, 20, Pastilles.BLEU, 800, zone.size.x)
	titre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	titre.name = prefixe + "ClientsTitre"
	var y := zone.position.y + 40
	var n := 0
	for c: Variant in liste:
		if not c is Array or (c as Array).size() < 7: continue
		if n >= lignes_max or y + LIGNE_H > zone.end.y: break
		var ligne := Button.new()
		ligne.name = prefixe + "Client_%d" % n
		ligne.accessibility_name = str(c[1])
		var vise := str(c[0]) == focus
		Kit.styler_ligne(ligne, Charte.PANNEAU_3 if n % 2 == 0 else Charte.PANNEAU, vise, Charte.PANNEAU_3.lerp(Pastilles.ORANGE, .28))
		parent.add_child(ligne)
		D.place(ligne, Rect2(zone.position.x, y, zone.size.x, LIGNE_H - 4))
		if vise:
			var lisere := D.rect(ligne, Rect2(0, 0, 6, LIGNE_H - 4), Pastilles.ORANGE, 2)
			lisere.name = prefixe + "ClientVise"
		var client: Array = c
		ligne.pressed.connect(func():
			if avant_clic.is_valid(): avant_clic.call()
			ouvrir_client(app, client))
		var l := zone.size.x
		D.text(ligne, 18, LIGNE_H * .5 + 5, str(c[2]), 16, Charte.IVOIRE_2, 600, l * .26, HORIZONTAL_ALIGNMENT_LEFT, true)
		D.text(ligne, 18 + l * .27, LIGNE_H * .5 + 6, Kit.casse(str(c[1])), 19, Charte.IVOIRE, 700, l * .36, HORIZONTAL_ALIGNMENT_LEFT, true)
		D.text(ligne, 18 + l * .64, LIGNE_H * .5 + 6, "%s ans" % G.n(c[3]), 17, Charte.IVOIRE_2, 600, l * .1)
		var ou := _ou(client)
		var pas := Pastilles.pastille(str(ou[0]), ou[1], str(ou[2]), "", 14, prefixe + "ClientOu_%d" % n)
		Pastilles.poser_a_droite(ligne, pas, l - 10, (LIGNE_H - 4 - 30) * .5)
		for enfant in ligne.get_children():
			if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		y += LIGNE_H
		n += 1
	if total > n: Kit.texte(parent, zone.position.x + 10, y + 22, "+%d" % (total - n), Charte.IVOIRE_3, 80, 16).name = prefixe + "ClientsPlus"

# --- Petite fenêtre de l'agent -------------------------------------------------------------------------------------------

## Ouvre la petite fenêtre de l'agent sur `page` (toile de l'écran) : identité, relation, caractère, ses joueurs.
static func ouvrir(app: Control, page: Control, agent_id: String, focus: String = "", focus_ligne: Array = []) -> void:
	var a := agent(app, agent_id)
	if a.is_empty() or page == null: return
	if focus_ligne.is_empty() and not focus.is_empty(): focus_ligne = ligne_connue(app, focus)
	# Toile plus petite que le gabarit (offre, 1500 × 860) : fenêtre recentrée sur elle, hauteur réduite.
	var taille := page.size / C.density if page.size.x > 0 else Vector2(2248, 1230)
	var l := minf(960.0, taille.x - 40)
	var lignes := mini(11, maxi(1, (a.get("clients", []) as Array).size() + (1 if focus_ligne.size() >= 7 else 0))) if a.get("clients") is Array else 1
	var h := minf(minf(900.0, 92 + 176 + 92 + 40 + lignes * LIGNE_H + 70), taille.y - 40)
	var f := Fenetre.ouvrir(page, NOM, "Agent de joueurs", "people", l, h)
	if absf(taille.x - 2248) > 2 or absf(taille.y - 1230) > 2:
		var calque := f.get_parent() as Control
		D.place(calque, Rect2(Vector2.ZERO, taille))
		var voile := calque.get_node_or_null(NOM + "Voile") as Control
		if voile != null: D.place(voile, Rect2(Vector2.ZERO, taille))
		D.place(f, Rect2((taille.x - l) / 2.0, maxf(20.0, (taille.y - h) / 2.0), l, h))
	var x0 := 36.0
	var y := 92.0
	poser_portrait(f, Rect2(x0, y, 150, 150), a, "FenetreAgentPortrait", RANGS.get(str(a.get("rang", "petite")), Pastilles.BLEU))
	var nom := D.text(f, x0 + 176, y + 46, str(a.get("nom", "")), 40, Charte.IVOIRE, 800, l - x0 - 230)
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	nom.name = "FenetreAgentNom"
	var x := x0 + 176
	x += Pastilles.poser(f, agence(a, "FenetreAgent", 18), x, y + 66) + 10
	Pastilles.poser(f, Pastilles.pastille(str(a.get("rangMot", "")), RANGS.get(str(a.get("rang", "petite")), Pastilles.BLEU), "people", "", 16, "FenetreAgentRang"), x, y + 68)
	Kit.etiquette(f, x0 + 176, y + 140, "Caractère", 200)
	Pastilles.poser(f, caractere(str(a.get("caractere", "")), "FenetreAgent", 20), x0 + 176 + 130, y + 112)
	y += 176
	Kit.etiquette(f, x0, y, "Relation", 200)
	crans(f, Rect2(x0, y + 12, l - 2 * x0, 52), cran(a), cran(a), "FenetreAgent")
	y += 92
	var fermer := func(): Fenetre.fermer(page, NOM)
	clients(app, f, Rect2(x0, y, l - 2 * x0, h - y - 30), a, focus, "FenetreAgent", fermer, 11, focus_ligne)
