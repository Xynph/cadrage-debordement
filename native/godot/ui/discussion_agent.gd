extends RefCounted
## Discussion avec l'agent d'une piste du marché (revue FM27, idée 24) : petite fenêtre ouverte depuis le Rapport du
## recruteur (pastille « Agent ») ou la piste choisie (« Parler à l'agent → »). Planche A/B sous CD_VARIANTE_VISUELLE ;
## sans variable, rien ne change à l'écran.
##  A « face à face » : bandeau de l'agent (bulle, relation en 5 crans), rapport du recruteur à gauche (lettre, tuiles,
##    Pour / Contre en icônes vertes / rouges), les trois tons en cartes à droite avec leurs effets en pastilles.
##  B « tableau des tons » : jauge de relation en tête, les trois tons en lignes façon Effectif (écart de demande, salaire,
##    propositions, relation chiffrés), rapport en pastilles vertes / rouges, fil de bulles à droite.
## Le moteur n'a pas d'agent : « Agent de <joueur> », sans nom ni visage inventés (même convention que l'idée 18).
## Données lues : piste du marché (salaire demandé, transfert, discussion en cours) et rapport du recruteur
## (rapport_recruteur.gd : lettre, rang au poste, Pour / Contre). Le ton et ses effets (écart de demande, nombre de
## propositions, relation) sont une proposition d'ajout moteur : ici, affichage seul, gardé dans management_ui.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const G = preload("res://ui/game_skin.gd")
const K = preload("res://ui/player_knowledge_text.gd")
const Link = preload("res://ui/entity_link.gd")

const NOM := "DiscussionAgent"
const CLE := "agent_tons"
## Tons : mot, nos mots, couleur, icône, écart de demande (%), propositions avant rupture, relation (crans).
const ORDRE := ["tout_prix", "enthousiaste", "curieux"]
const TONS := {
	"tout_prix": {"mot": "À tout prix", "phrase": "On le veut, quoi qu’il en coûte.", "couleur": Pieces.ORANGE, "icone": "target", "ecart": 6, "essais": 4, "relation": 2},
	"enthousiaste": {"mot": "Enthousiaste", "phrase": "Il nous plaît beaucoup.", "couleur": Pieces.VERT, "icone": "star", "ecart": 0, "essais": 3, "relation": 1},
	"curieux": {"mot": "Curieux", "phrase": "On se renseigne, sans plus.", "couleur": Pieces.BLEU, "icone": "search", "ecart": -3, "essais": 2, "relation": -1}}
## Relation avec l'agent : 5 crans.
const RELATIONS := [["Froide", Pieces.ROUGE], ["Distante", Pieces.ORANGE], ["Neutre", Charte.IVOIRE_2], ["Bonne", Pieces.BLEU], ["Proche", Pieces.VERT]]

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

static func _etat(app: Control) -> Dictionary:
	var valeur: Variant = app.management_ui.get(CLE)
	if not valeur is Dictionary:
		valeur = {}
		app.management_ui[CLE] = valeur
	return valeur

# --- Données -----------------------------------------------------------------------------------------------------------

static func donnees(app: Control, p: Dictionary) -> Dictionary:
	var r: Dictionary = load("res://ui/immersive08/rapport_recruteur.gd").lire(app, p)
	var id := str(p.get("id", ""))
	var ton := str(_etat(app).get(id, ""))
	var nego: Dictionary = p.get("negotiation", {}) if p.get("negotiation") is Dictionary else {}
	# Relation de départ lue dans la discussion en cours : contre-offre = distante, rupture = froide, accord = bonne.
	var depart := {"counter": 1, "withdrawn": 0, "ready": 3, "signed": 4}.get(str(nego.get("status", "")), 2) as int
	var niveau := clampi(depart + (int(TONS[ton].relation) if TONS.has(ton) else 0), 0, 4)
	var salaire := float(p.get("salary", 0)) if K.number(p.get("salary")) else 0.0
	return {"p": p, "id": id, "r": r, "ton": ton, "depart": depart, "niveau": niveau, "salaire": salaire,
		"ouvert": bool(p.get("available", false)), "prenom": Kit.casse(str(p.get("name", "—")), true)}

static func demande(d: Dictionary, ton: String) -> int:
	var ecart := int(TONS[ton].ecart) if TONS.has(ton) else 0
	return int(roundf(float(d.salaire) * (1.0 + ecart / 100.0) / 10.0) * 10.0)

## Répliques de l'agent (courtes, chiffrées).
static func accueil(d: Dictionary) -> String:
	return "Tu voulais me parler de %s ?" % str(d.prenom)

static func reponse(d: Dictionary) -> String:
	if not bool(d.ouvert): return "Son club ne le laissera pas partir."
	match str(d.ton):
		"tout_prix": return "Alors ce sera %s, pas moins" % G.salary(demande(d, d.ton))
		"enthousiaste": return "Il sera ravi. On part sur %s" % G.salary(demande(d, d.ton))
		"curieux": return "%s, d’autres clubs appellent." % G.salary(demande(d, d.ton))
	return accueil(d)

# --- Ouverture ---------------------------------------------------------------------------------------------------------

## Ouvre (ou redessine) la fenêtre sur `page` (toile 2248 × 1230 de la sous-page du recrutement).
static func ouvrir(app: Control, page: Control, p: Dictionary) -> void:
	if p.is_empty() or page == null: return
	var d := donnees(app, p)
	if variante() == "B": _dessiner_b(app, page, d)
	else: _dessiner_a(app, page, d)

static func _choisir(app: Control, page: Control, p: Dictionary, ton: String) -> void:
	_etat(app)[str(p.get("id", ""))] = ton
	ouvrir(app, page, p)
	var cible := page.find_child("AgentTon_" + ton, true, false) as Control
	if cible != null: cible.grab_focus.call_deferred()

static func _offre(app: Control, id: String) -> Callable:
	return func(): load("res://ui/immersive08/recruitment_pages.gd").ouvrir(app, "negociation", {"player_id": id})

static func _fiche(app: Control, id: String) -> Callable:
	return func(): app.navigation_controller.open_entity({"kind": "market", "id": id})

## Lettre du rapport : clic = referme la fenêtre sur le Rapport du recruteur (ouvert derrière).
static func _rapport(app: Control, page: Control, id: String) -> Callable:
	return func():
		Fenetre.fermer(page, NOM)
		var pages: Variant = load("res://ui/immersive08/recruitment_pages.gd")
		if str(pages.etat(app).get("kind", "")) != "recruteur": pages.ouvrir(app, "recruteur", {"player_id": id})

# --- Pièces communes ---------------------------------------------------------------------------------------------------

## Visage de l'agent : rond neutre, silhouette (le moteur n'a pas d'agent, aucun visage inventé).
static func _agent(parent: Control, zone: Rect2, couleur: Color) -> void:
	var rond := D.rect(parent, zone, Charte.PANNEAU_3.lerp(couleur, .18), Charte.RAYON_PILULE)
	rond.name = "AgentSilhouette"
	rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := C.icon("people", int(zone.size.x * .5), couleur)
	rond.add_child(image)
	D.place(image, Rect2(zone.size.x * .25, zone.size.y * .25, zone.size.x * .5, zone.size.y * .5))

## Nom de la piste : bouton (fiche) + carte au survol.
static func _nom(app: Control, parent: Control, d: Dictionary, zone: Rect2, taille: int) -> void:
	var nom := Link.styled_button(parent, zone, Kit.casse(str(d.p.get("name", "—"))), taille, Charte.IVOIRE, "AgentJoueurNom")
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	nom.pressed.connect(_fiche(app, d.id))
	load("res://ui/carte_joueur_survol.gd").lier(app, nom, str(d.id), "market")

## Bulle : pilule teintée, texte sur une ligne. `droite` : x est le bord droit. Renvoie la largeur.
static func _bulle(parent: Control, x: float, y: float, texte: String, couleur: Color, id: String, droite := false, largeur_max := 640.0, taille := 22) -> float:
	var largeur := minf(Kit.largeur(texte, taille) + 48.0, largeur_max)
	var gauche := x - largeur if droite else x
	var fond := D.rect(parent, Rect2(gauche, y, largeur, 52), Charte.PANNEAU_3.lerp(couleur, .30), Charte.RAYON_CARTE)
	fond.name = id
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mot := D.text(fond, 24, 34, texte, taille, Charte.IVOIRE, 600, largeur - 40, HORIZONTAL_ALIGNMENT_LEFT, true)
	mot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Queue de la bulle : petit carré du côté de l'orateur.
	var queue := D.rect(parent, Rect2((gauche + largeur - 22) if droite else (gauche + 8), y + 40, 14, 14), Charte.PANNEAU_3.lerp(couleur, .30), 2)
	queue.rotation_degrees = 45
	queue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.move_child(queue, fond.get_index())
	return largeur

## Relation en 5 crans (le cran de départ marqué d'un liseré quand le ton l'a fait bouger).
static func _crans(parent: Control, x: float, y: float, d: Dictionary, largeur_cran := 62.0, hauteur := 16.0) -> void:
	var niveau := int(d.niveau)
	var couleur: Color = RELATIONS[niveau][1]
	for i in 5:
		var plein := i <= niveau
		var cran := D.rect(parent, Rect2(x + i * (largeur_cran + 6), y, largeur_cran, hauteur), couleur if plein else Charte.PANNEAU_3, Charte.RAYON_PILULE,
			Charte.IVOIRE_2 if i == int(d.depart) and int(d.depart) != niveau else Color.TRANSPARENT)
		cran.name = "AgentRelationCran_%d" % i
		cran.mouse_filter = Control.MOUSE_FILTER_IGNORE

static func _relation_mot(parent: Control, x: float, base: float, d: Dictionary, taille := 26) -> void:
	var niveau := int(d.niveau)
	var mot := D.text(parent, x, base, str(RELATIONS[niveau][0]).to_upper(), taille, RELATIONS[niveau][1], 800, 220)
	mot.name = "AgentRelationMot"
	mot.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	var ecart := niveau - int(d.depart)
	if ecart != 0:
		var fleche := D.text(parent, x + Kit.largeur(str(RELATIONS[niveau][0]).to_upper(), taille) + 16, base, ("▲ %d" if ecart > 0 else "▼ %d") % absi(ecart), 22, Pieces.VERT if ecart > 0 else Pieces.ROUGE, 800, 80)
		fleche.name = "AgentRelationEcart"

## Effets d'un ton en pastilles : écart de demande, propositions, relation. Renvoie la largeur posée.
static func _effets(parent: Control, x: float, y: float, ton: String, id: String) -> float:
	var t: Dictionary = TONS[ton]
	var ecart := int(t.ecart)
	var cx := x
	cx += Pieces.pastille(parent, cx, y, ("Demande %+d %%" % ecart) if ecart != 0 else "Demande =", "money", id + "Demande", "", Pieces.ROUGE if ecart > 0 else Pieces.VERT if ecart < 0 else Charte.IVOIRE_2) + 8
	cx += Pieces.pastille(parent, cx, y, "%d essais" % int(t.essais), "renew", id + "Essais", "", Pieces.VERT if int(t.essais) > 3 else Pieces.ROUGE if int(t.essais) < 3 else Charte.IVOIRE_2) + 8
	cx += Pieces.pastille(parent, cx, y, "Relation %+d" % int(t.relation), "heart", id + "Relation", "", Pieces.VERT if int(t.relation) > 0 else Pieces.ROUGE)
	return cx - x

## Lignes Pour / Contre : icône teintée + mot + chiffre ; ligne cliquable (action du rapport).
static func _raisons(parent: Control, x: float, y: float, l: float, titre: String, icone: String, couleur: Color, raisons: Array, id: String, max_lignes := 4, pas := 50.0) -> float:
	var tete := C.icon(icone, 24, couleur)
	parent.add_child(tete)
	D.place(tete, Rect2(x, y, 24, 24))
	var t := D.text(parent, x + 34, y + 21, "%s · %d" % [titre, raisons.size()], 22, couleur, 800, l - 40)
	t.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	var ly := y + 38
	for i in mini(raisons.size(), max_lignes):
		var raison: Array = raisons[i]
		var ligne := Button.new()
		ligne.name = "%s_%d" % [id, i]
		ligne.accessibility_name = "%s %s" % [raison[1], raison[2]]
		Kit.styler_ligne(ligne, Charte.PANNEAU_2 if i % 2 == 0 else Charte.PANNEAU)
		parent.add_child(ligne)
		D.place(ligne, Rect2(x, ly, l, pas - 6))
		if (raison[3] as Callable).is_valid(): ligne.pressed.connect(raison[3])
		var image := C.icon(str(raison[0]), 22, couleur)
		ligne.add_child(image)
		D.place(image, Rect2(12, (pas - 6 - 22) / 2.0, 22, 22))
		D.text(ligne, 46, (pas - 6) / 2.0 + 8, str(raison[1]), 20, Charte.IVOIRE, 600, l - 150).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not str(raison[2]).is_empty():
			var chiffre := D.text(ligne, l - 14, (pas - 6) / 2.0 + 9, str(raison[2]), 22, couleur, 800, 110, HORIZONTAL_ALIGNMENT_RIGHT)
			chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
			chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ly += pas
	if raisons.size() > max_lignes: Kit.texte(parent, x + 12, ly + 20, "+%d" % (raisons.size() - max_lignes), Charte.IVOIRE_3, 80, 18)
	return ly

## Lettre du recruteur : carré coloré cliquable.
static func _lettre(app: Control, page: Control, parent: Control, d: Dictionary, zone: Rect2, taille: int) -> void:
	var r: Dictionary = d.r
	var couleur: Color = r.couleur
	var bouton := Button.new()
	bouton.name = "AgentRapportLettre"
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.accessibility_name = "Avis du recruteur " + str(r.lettre)
	for etat in ["normal", "pressed", "focus"]: bouton.add_theme_stylebox_override(etat, C.box(Charte.PANNEAU_2.lerp(couleur, .22), Color.TRANSPARENT, Charte.RAYON_CARTE, 0))
	bouton.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3.lerp(couleur, .32), Color.TRANSPARENT, Charte.RAYON_CARTE, 0))
	parent.add_child(bouton)
	D.place(bouton, zone)
	var texte := D.text(bouton, zone.size.x / 2.0, zone.size.y * .5 + taille * .36, str(r.lettre), taille, couleur, 800, zone.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	texte.add_theme_font_override("font", Charte.TITRE_FICHE)
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bouton.pressed.connect(_rapport(app, page, d.id))

static func _note_texte(r: Dictionary) -> String:
	return G.n(roundi(float(r.note))) if float(r.note) >= 0 else "—"

# --- Option A : face à face ---------------------------------------------------------------------------------------------

static func _dessiner_a(app: Control, page: Control, d: Dictionary) -> void:
	const L := 1560.0
	const H := 900.0
	var f := Fenetre.ouvrir(page, NOM, "Discussion avec l’agent", "people", L, H)
	var r: Dictionary = d.r
	var ton := str(d.ton)
	var couleur_ton: Color = TONS[ton].couleur if TONS.has(ton) else Pieces.BLEU
	# Bandeau de l'agent.
	var bandeau := D.rect(f, Rect2(28, 84, L - 56, 184), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	bandeau.name = "AgentBandeau"
	bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_agent(f, Rect2(50, 104, 140, 140), couleur_ton)
	var portrait: Control = load("res://ui/carnet_skin.gd").portrait(0, int(64 * C.density), d.p)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(portrait)
	D.place(portrait, Rect2(146, 186, 64, 64))
	Kit.etiquette(f, 232, 124, "Agent de", 300)
	_nom(app, f, d, Rect2(228, 130, 520, 48), 32)
	Kit.texte(f, 232, 200, "%s · %s ans" % [r.poste, G.n(d.p.get("age", "—"))], Charte.IVOIRE_2, 400, 18)
	_bulle(f, 232, 214, reponse(d), couleur_ton if not ton.is_empty() else Pieces.BLEU, "AgentBulle", false, 760)
	Kit.etiquette(f, L - 420, 124, "Relation", 360)
	_crans(f, L - 420, 140, d)
	_relation_mot(f, L - 420, 194, d)
	# Rapport du recruteur (colonne gauche).
	Kit.etiquette(f, 28, 306, "Rapport du recruteur", 600)
	_lettre(app, page, f, d, Rect2(28, 322, 124, 116), 72)
	var id := str(d.id)
	Pieces.tuile(f, Rect2(166, 322, 170, 116), _note_texte(r), "Note au poste", Charte.couleur_attribut(r.note), "AgentTuileNote", 36, "", "rating", false, _fiche(app, id))
	Pieces.tuile(f, Rect2(348, 322, 170, 116), "%d / %d" % [r.rang, r.total], "Rang chez nous", Charte.IVOIRE, "AgentTuileRang", 36, "", "people", false, _rapport(app, page, id))
	Pieces.tuile(f, Rect2(530, 322, 170, 116), K.potential_text(d.p), "Potentiel", K.POTENTIAL_COLOR, "AgentTuilePotentiel", 36, "", "renew", false, _fiche(app, id))
	var montant := demande(d, ton)
	Pieces.tuile(f, Rect2(712, 322, 188, 116), G.salary_amount(montant), "Demande " + G.salary_period(true), Pieces.ROUGE if montant > d.salaire else Pieces.VERT if montant < d.salaire else Pieces.BLEU, "AgentTuileDemande", 36, "", "money", true, _offre(app, id))
	_raisons(f, 28, 466, 430, "POUR", "check", Pieces.VERT, r.pour, "AgentPour")
	_raisons(f, 470, 466, 430, "CONTRE", "warning", Pieces.ROUGE, r.contre, "AgentContre")
	# Les trois tons (colonne droite).
	Kit.etiquette(f, 936, 306, "Ton", 400)
	var y := 322.0
	for cle: String in ORDRE:
		var t: Dictionary = TONS[cle]
		var choisi := cle == ton
		var ligne := Button.new()
		ligne.name = "AgentTon_" + cle
		ligne.accessibility_name = str(t.mot)
		Kit.styler_ligne(ligne, Charte.PANNEAU_2, choisi, Charte.PANNEAU_3.lerp(t.couleur, .22))
		f.add_child(ligne)
		D.place(ligne, Rect2(936, y, L - 28 - 936, 136))
		ligne.pressed.connect(func(): _choisir(app, page, d.p, cle))
		if choisi: Kit.marqueur(ligne, Rect2(0, 10, 6, 116), t.couleur)
		var image := C.icon(str(t.icone), 28, t.couleur)
		ligne.add_child(image)
		D.place(image, Rect2(24, 20, 28, 28))
		var mot := D.text(ligne, 64, 44, str(t.mot).to_upper(), 28, t.couleur, 800, 300)
		mot.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		D.text(ligne, 64, 78, "« %s »" % t.phrase, 19, Charte.IVOIRE if choisi else Charte.IVOIRE_2, 600, L - 28 - 936 - 90, HORIZONTAL_ALIGNMENT_LEFT, true)
		_effets(ligne, 64, 90, cle, "AgentEffet_" + cle + "_")
		for enfant in ligne.get_children():
			if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		y += 148
	# Transfert et offre.
	var rx := 28.0
	rx += Pieces.pastille(f, rx, H - 66, "Transfert ouvert" if d.ouvert else "Transfert fermé", "check" if d.ouvert else "lock", "AgentTransfert", "", Pieces.VERT if d.ouvert else Pieces.ROUGE, Charte.PANNEAU_3, _offre(app, id)) + 10
	Pieces.pastille(f, rx, H - 66, "Rapport complet", "search", "AgentRapportComplet", "", Charte.IVOIRE_2, Charte.PANNEAU_3, _rapport(app, page, id))
	var offre := Kit.bouton_ivoire(f, Rect2(L - 28 - 360, H - 74, 360, 50), "Faire une offre", _offre(app, id), "AgentFaireOffre")
	offre.disabled = not bool(d.ouvert)

# --- Option B : tableau des tons ----------------------------------------------------------------------------------------

static func _dessiner_b(app: Control, page: Control, d: Dictionary) -> void:
	const L := 1760.0
	const H := 960.0
	var f := Fenetre.ouvrir(page, NOM, "Discussion avec l’agent", "people", L, H)
	var r: Dictionary = d.r
	var ton := str(d.ton)
	var id := str(d.id)
	# En-tête : visage du joueur, agent, jauge de relation.
	var portrait: Control = load("res://ui/carnet_skin.gd").portrait(0, int(96 * C.density), d.p)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(portrait)
	D.place(portrait, Rect2(28, 84, 96, 96))
	_agent(f, Rect2(96, 140, 48, 48), Pieces.BLEU)
	Kit.etiquette(f, 160, 104, "Agent de", 300)
	_nom(app, f, d, Rect2(156, 108, 560, 46), 30)
	Kit.texte(f, 160, 178, "%s · %s ans · %s" % [r.poste, G.n(d.p.get("age", "—")), G.salary(d.salaire)], Charte.IVOIRE_2, 560, 18)
	var gx := L - 28 - 5 * 158.0
	Kit.etiquette(f, gx, 100, "Relation avec l’agent", 500)
	for i in 5:
		var actif := i == int(d.niveau)
		var couleur: Color = RELATIONS[i][1]
		var cran := D.rect(f, Rect2(gx + i * 158, 112, 152, 52), Charte.PANNEAU_3.lerp(couleur, .55 if actif else .10), Charte.RAYON_PETIT,
			Charte.IVOIRE_2 if i == int(d.depart) and int(d.depart) != int(d.niveau) else Color.TRANSPARENT)
		cran.name = "AgentRelationCran_%d" % i
		cran.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mot := D.text(cran, 76, 34, str(RELATIONS[i][0]), 20, Charte.IVOIRE if actif else couleur, 800 if actif else 600, 148, HORIZONTAL_ALIGNMENT_CENTER)
		mot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ecart_rel := int(d.niveau) - int(d.depart)
	if ecart_rel != 0:
		var fl := D.text(f, gx + int(d.niveau) * 158 + 76, 190, ("▲ %d" if ecart_rel > 0 else "▼ %d") % absi(ecart_rel), 20, Pieces.VERT if ecart_rel > 0 else Pieces.ROUGE, 800, 80, HORIZONTAL_ALIGNMENT_CENTER)
		fl.name = "AgentRelationEcart"
	# Tableau des tons (façon Effectif).
	var colonnes := [["TON", 300], ["NOS MOTS", 0], ["DEMANDE", 140], ["SALAIRE", 200], ["ESSAIS", 130], ["RELATION", 160]]
	var fixe := 0.0
	for c: Array in colonnes: fixe += float(c[1])
	var largeur_tab := L - 56
	var y := 222.0
	D.rect(f, Rect2(28, y, largeur_tab, 34), Charte.BANDEAU_ENTETE, Charte.RAYON_PETIT)
	var cx := 28.0 + 20
	for c: Array in colonnes:
		var lc := float(c[1]) if float(c[1]) > 0 else largeur_tab - 20 - fixe
		D.text(f, cx, y + 23, str(c[0]), 15, Charte.IVOIRE_3, 700, lc - 8)
		cx += lc
	y += 40
	for i in ORDRE.size():
		var cle: String = ORDRE[i]
		var t: Dictionary = TONS[cle]
		var choisi := cle == ton
		var ligne := Button.new()
		ligne.name = "AgentTon_" + cle
		ligne.accessibility_name = str(t.mot)
		Kit.styler_ligne(ligne, Charte.PANNEAU_2 if i % 2 == 0 else Charte.PANNEAU, choisi, Charte.PANNEAU_3.lerp(t.couleur, .22))
		f.add_child(ligne)
		D.place(ligne, Rect2(28, y, largeur_tab, 62))
		ligne.pressed.connect(func(): _choisir(app, page, d.p, cle))
		Kit.marqueur(ligne, Rect2(0, 8, 6, 46), t.couleur if choisi else Charte.PANNEAU_3.lerp(t.couleur, .5))
		var image := C.icon(str(t.icone), 26, t.couleur)
		ligne.add_child(image)
		D.place(image, Rect2(20, 18, 26, 26))
		var mot := D.text(ligne, 58, 41, str(t.mot).to_upper(), 26, t.couleur, 800, 240)
		mot.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		var lx := 20.0 + 300
		var lm := largeur_tab - 20 - fixe
		D.text(ligne, lx, 39, "« %s »" % t.phrase, 19, Charte.IVOIRE if choisi else Charte.IVOIRE_2, 600, lm - 16, HORIZONTAL_ALIGNMENT_LEFT, true)
		lx += lm
		var ecart := int(t.ecart)
		var c_ecart: Color = Pieces.ROUGE if ecart > 0 else Pieces.VERT if ecart < 0 else Charte.IVOIRE_2
		var valeurs := [[("%+d %%" % ecart) if ecart != 0 else "=", c_ecart, 140], [G.salary_amount(demande(d, cle)), Pieces.BLEU, 200],
			[str(int(t.essais)), Pieces.VERT if int(t.essais) > 3 else Pieces.ROUGE if int(t.essais) < 3 else Charte.IVOIRE_2, 130],
			["%+d" % int(t.relation), Pieces.VERT if int(t.relation) > 0 else Pieces.ROUGE, 160]]
		for v: Array in valeurs:
			var chiffre := D.text(ligne, lx, 42, str(v[0]), 26, v[1], 800, float(v[2]) - 10)
			chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
			lx += float(v[2])
		for enfant in ligne.get_children():
			if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		y += 66
	# Rapport du recruteur en pastilles (gauche).
	var by := y + 30
	Kit.etiquette(f, 28, by, "Rapport du recruteur", 600)
	_lettre(app, page, f, d, Rect2(28, by + 16, 112, 104), 66)
	var rang := D.text(f, 160, by + 60, "n° %d / %d" % [r.rang, r.total], 30, Charte.IVOIRE, 800, 220)
	rang.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	Kit.texte(f, 160, by + 92, "%s · note %s" % [str(r.poste), _note_texte(r)], Charte.IVOIRE_2, 520, 18)
	var py := _pastilles(f, 28, by + 140, 820, r.pour, Pieces.VERT, "AgentPour", 6)
	_pastilles(f, 28, py + 8, 820, r.contre, Pieces.ROUGE, "AgentContre", 4)
	# Fil de la discussion (droite).
	var fx := 900.0
	var fl_ := L - 28 - fx
	var fil := D.rect(f, Rect2(fx, by - 10, fl_, H - 96 - by), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	fil.name = "AgentFil"
	fil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ty := by + 14
	_bulle(f, fx + 24, ty, accueil(d), Pieces.BLEU, "AgentBulleAccueil", false, fl_ - 120)
	if not ton.is_empty():
		ty += 78
		_bulle(f, fx + fl_ - 24, ty, str(TONS[ton].phrase), TONS[ton].couleur, "AgentBulleNous", true, fl_ - 120)
		ty += 78
		_bulle(f, fx + 24, ty, reponse(d), Pieces.BLEU, "AgentBulle", false, fl_ - 120)
	# Bas : transfert, offre.
	Pieces.pastille(f, 28, H - 66, "Transfert ouvert" if d.ouvert else "Transfert fermé", "check" if d.ouvert else "lock", "AgentTransfert", "", Pieces.VERT if d.ouvert else Pieces.ROUGE, Charte.PANNEAU_3, _offre(app, id))
	var offre := Kit.bouton_ivoire(f, Rect2(L - 28 - 360, H - 74, 360, 50), "Faire une offre", _offre(app, id), "AgentFaireOffre")
	offre.disabled = not bool(d.ouvert)

## Raisons en pastilles (icône + mot + chiffre), à la suite, retour à la ligne. Renvoie le bas posé.
static func _pastilles(parent: Control, x: float, y: float, l: float, raisons: Array, couleur: Color, id: String, max_n: int) -> float:
	var cx := x
	var cy := y
	for i in mini(raisons.size(), max_n):
		var raison: Array = raisons[i]
		var texte := str(raison[1]) + ((" " + str(raison[2])) if not str(raison[2]).is_empty() else "")
		var w := Pieces.largeur_pastille(texte, str(raison[0]))
		if cx + w > x + l and cx > x:
			cx = x
			cy += 42
		cx += Pieces.pastille(parent, cx, cy, texte, str(raison[0]), "%s_%d" % [id, i], "", couleur, Charte.PANNEAU_3, raison[3]) + 8
	if raisons.size() > max_n: Kit.texte(parent, cx + 4, cy + 24, "+%d" % (raisons.size() - max_n), Charte.IVOIRE_3, 60, 18)
	return cy + 42
