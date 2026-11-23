extends RefCounted
## Discussion avec l'agent d'une piste du marché (revue FM27, idée 24, choix de Léo du 23/11/2026) : même fenêtre que la
## discussion avec un joueur (fenetre_discussion.gd). Ouverte depuis le Rapport du recruteur (pastille « Parler à
## l'agent ») et la piste choisie du Recrutement (« Parler à l'agent → »). L'agent n'a pas de nom.
##  - Gauche : le joueur (visage, nom, poste, âge), le rapport du recruteur (lettre, note au poste /100 colorée,
##    familiarité au poste, rang chez nous, Pour / Contre en icônes vertes / rouges), la relation avec l'agent (5 crans,
##    valeur gardée d'une journée à l'autre), la demande de la journée et le nombre de propositions.
##  - Droite : l'échelle de la relation, le fil en trois tours (le ton ; une question sur le rôle attendu ou la durée ;
##    faire une offre ou en rester là). Un clic sur une phrase la dit tout de suite : aucun bouton Valider.
## Ton (moteur native/engine/ton-agent.cjs, commande agent_ton, projection market[].agent) : À tout prix demande +6 %,
## 4 propositions, relation +2 ; Enthousiaste demande inchangée, 3, +1 ; Curieux −3 %, 2, −1. Un ton par piste et par
## journée, avant la première proposition.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const FenetreDiscussion = preload("res://ui/fenetre_discussion.gd")
const Familiarite = preload("res://ui/familiarite_poste.gd")
const Role = preload("res://ui/role_contrat.gd")
const G = preload("res://ui/game_skin.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")
const Link = preload("res://ui/entity_link.gd")

const NOM := "DiscussionAgent"
const CLE := "agent_tons"
const ORDRE := ["tout_prix", "enthousiaste", "curieux"]
## Tons : mot, nos mots, couleur, icône, écart de demande (%), propositions, relation (mêmes règles que le moteur).
const TONS := {
	"tout_prix": {"mot": "À tout prix", "phrase": "On le veut, quoi qu’il en coûte.", "couleur": Pastilles.ORANGE, "icone": "target", "ecart": 6, "essais": 4, "relation": 2},
	"enthousiaste": {"mot": "Enthousiaste", "phrase": "Il nous plaît beaucoup.", "couleur": Pastilles.VERT, "icone": "star", "ecart": 0, "essais": 3, "relation": 1},
	"curieux": {"mot": "Curieux", "phrase": "On se renseigne, sans plus.", "couleur": Pastilles.BLEU, "icone": "search", "ecart": -3, "essais": 2, "relation": -1}}
## Relation avec l'agent : 5 crans (moteur : Froide ≤ −6 < Distante ≤ −2 < Neutre < 2 ≤ Bonne < 6 ≤ Proche).
const RELATIONS := [["Froide", Pastilles.ROUGE, "warning"], ["Distante", Pastilles.ORANGE, "info"], ["Neutre", Charte.IVOIRE_2, "people"],
	["Bonne", Pastilles.BLEU, "check"], ["Proche", Pastilles.VERT, "heart"]]
## Deuxième tour : nos questions.
const QUESTIONS := {"role": {"texte": "Quel rôle il attend chez nous ?", "icone": "flag", "couleur": Pastilles.VIOLET},
	"duree": {"texte": "Il signerait pour combien de saisons ?", "icone": "calendar", "couleur": Pastilles.TURQUOISE}}

static func cran(r: int) -> int:
	return 0 if r <= -6 else 1 if r <= -2 else 2 if r < 2 else 3 if r < 6 else 4

# --- État de l'écran (deuxième et troisième tours, phrase envoyée) --------------------------------------------------------

static func _etat(app: Control, id: String) -> Dictionary:
	var tout: Variant = app.management_ui.get(CLE)
	if not tout is Dictionary:
		tout = {}
		app.management_ui[CLE] = tout
	var semaine := "%s:%s" % [str(app.model.get("meta", {}).get("roundLabel", "")), str(app.model.get("meta", {}).get("week", 0))]
	var e: Variant = tout.get(id)
	if not (e is Dictionary and str(e.get("semaine", "")) == semaine):
		e = {"semaine": semaine}
		tout[id] = e
	return e

# --- Données -----------------------------------------------------------------------------------------------------------

static func _piste(app: Control, id: String) -> Dictionary:
	for p: Variant in app.model.get("market", []):
		if p is Dictionary and str(p.get("id", "")) == id: return p
	return {}

static func donnees(app: Control, id: String) -> Dictionary:
	var p := _piste(app, id)
	if p.is_empty(): return {}
	var a: Dictionary = p.get("agent", {}) if p.get("agent") is Dictionary else {}
	var e := _etat(app, id)
	var ton := str(a.get("ton", ""))
	if not ton.is_empty(): e.erase("envoi")
	var roles: Variant = p.get("roles")
	return {"p": p, "id": id, "r": load("res://ui/immersive08/rapport_recruteur.gd").lire(app, p), "ton": ton, "e": e,
		"essais": int(a.get("essais", 3)), "faites": int(a.get("faites", 0)), "effet": a.get("effet", {}) if a.get("effet") is Dictionary else {}, "relation": int(a.get("relation", 0)), "avant": int(a.get("avant", a.get("relation", 0))),
		"libre": bool(a.get("libre", false)) and not e.has("envoi"), "ouvert": bool(p.get("available", false)),
		"salaire": int(p.get("salary", 0)) if p.get("salary") is int or p.get("salary") is float else 0,
		"attendu": str(roles.get("attendu", "")) if roles is Dictionary else "", "max": int(p.get("maxYears", 1)),
		"nego": p.get("negotiation", {}) if p.get("negotiation") is Dictionary else {}, "prenom": Kit.casse(str(p.get("name", "—")), true)}

# --- Ouverture ---------------------------------------------------------------------------------------------------------

## Ouvre (ou redessine) la fenêtre sur `page` (toile du Rapport du recruteur).
static func ouvrir(app: Control, page: Control, p: Dictionary) -> void:
	if p.is_empty() or page == null: return
	_dessiner(app, page, str(p.get("id", "")))

static func _redessiner(app: Control, page: Control, id: String) -> void:
	if is_instance_valid(page): _dessiner(app, page, id)

static func _pages() -> Variant:
	return load("res://ui/immersive08/recruitment_pages.gd")

## Ton : la phrase s'affiche aussitôt, le moteur enregistre le ton, la page revient avec la fenêtre rouverte.
static func _choisir_ton(app: Control, page: Control, d: Dictionary, ton: String) -> void:
	d.e["envoi"] = ton
	_pages().etat(app)["agent"] = true
	_redessiner(app, page, d.id)
	app._command("agent_ton", {"playerId": d.id, "ton": ton})

static func _demander(app: Control, page: Control, d: Dictionary, q: String) -> void:
	d.e["question"] = q
	_redessiner(app, page, d.id)

static func _conclure(app: Control, page: Control, d: Dictionary) -> void:
	d.e["fin"] = true
	_redessiner(app, page, d.id)

static func _offre(app: Control, page: Control, id: String) -> Callable:
	return func():
		Fenetre.fermer(page, NOM)
		_pages().ouvrir(app, "negociation", {"player_id": id})

static func _fiche(app: Control, page: Control, id: String) -> Callable:
	return func():
		Fenetre.fermer(page, NOM)
		app.navigation_controller.open_entity({"kind": "market", "id": id})

static func _fermer(page: Control) -> Callable:
	return func(): Fenetre.fermer(page, NOM)

static func _dessiner(app: Control, page: Control, id: String) -> void:
	var d := donnees(app, id)
	if d.is_empty(): return
	FenetreDiscussion.ouvrir(page, {"nom": NOM, "titre": "Agent de " + Kit.casse(str(d.p.get("name", "—"))), "icone": "people", "prefixe": "Agent",
		"gauche": func(f: Control, zone: Rect2): _gauche(app, page, f, zone, d),
		"echelle": {"paliers": RELATIONS, "avant": cran(int(d.avant)), "apres": cran(int(d.relation))},
		"visage": func() -> Control: return _visage(52),
		"fil": _fil(d), "choix": _choix(app, page, d)})

# --- Fil et choix ------------------------------------------------------------------------------------------------------

static func accueil(d: Dictionary) -> String:
	match cran(int(d.avant)):
		0: return "Encore vous. Faites vite."
		1: return "%s ? J’écoute." % str(d.prenom)
		3: return "Content de vous entendre. %s ?" % str(d.prenom)
		4: return "Toujours un plaisir. On parle de %s ?" % str(d.prenom)
	return "Vous vouliez me parler de %s ?" % str(d.prenom)

static func reponse_ton(d: Dictionary) -> String:
	var montant := G.salary(int(d.salaire))
	match str(d.ton):
		"tout_prix": return "Alors ce sera %s, pas moins." % montant
		"enthousiaste": return "Il sera ravi. On part sur %s." % montant
		"curieux": return "%s. D’autres clubs appellent." % montant
	return ""

static func reponse_question(d: Dictionary, q: String) -> String:
	if q == "role":
		return "Il se voit %s." % Role.libelle(str(d.attendu)).to_lower() if not str(d.attendu).is_empty() else "Il veut jouer, c’est tout."
	var n := clampi(int(d.max), 1, 3)
	return "Une saison, pas plus." if n == 1 else "Jusqu’à %d saisons." % n

static func _fil(d: Dictionary) -> Array:
	var fil: Array = [{"qui": "lui", "id": "AgentBulleAccueil", "texte": accueil(d), "couleur": Pastilles.BLEU}]
	var e: Dictionary = d.e
	var ton := str(d.ton) if not str(d.ton).is_empty() else str(e.get("envoi", ""))
	if not ton.is_empty():
		var t: Dictionary = TONS[ton]
		fil.append({"qui": "moi", "id": "AgentBulleTon", "texte": str(t.phrase), "couleur": t.couleur})
		if not str(d.ton).is_empty():
			fil.append({"qui": "lui", "id": "AgentBulleDemande", "texte": reponse_ton(d), "couleur": Pastilles.BLEU, "effet": _effets(str(d.ton))})
	elif not bool(d.libre):
		# Négociation déjà commencée cette journée sans ton : plus de ton possible.
		fil.append({"qui": "repere", "id": "AgentNegoEnCours", "controle": Pastilles.pastille("Négociation en cours", Pastilles.ORANGE, "renew", "Proposition déjà faite cette journée", 16, "AgentNegoEnCoursPastille")})
	var q := str(e.get("question", ""))
	if not q.is_empty() and not str(d.ton).is_empty():
		var question: Dictionary = QUESTIONS[q]
		fil.append({"qui": "moi", "id": "AgentBulleQuestion", "texte": str(question.texte), "couleur": question.couleur})
		var effet: Control = Role.pastille(str(d.attendu), 15) if q == "role" and not str(d.attendu).is_empty() else null
		fil.append({"qui": "lui", "id": "AgentBulleReponse", "texte": reponse_question(d, q), "couleur": Pastilles.BLEU, "effet": effet})
	if bool(e.get("fin", false)):
		fil.append({"qui": "moi", "id": "AgentBulleFin", "texte": "On en reste là pour l’instant.", "couleur": Charte.IVOIRE_2})
		fil.append({"qui": "lui", "id": "AgentBulleAuRevoir", "texte": "Ne tardez pas trop.", "couleur": Pastilles.BLEU})
	return fil

## Effets d'un ton en pastilles : demande, propositions, relation.
static func _effets(ton: String) -> Control:
	var t: Dictionary = TONS[ton]
	var ligne := C.h(8)
	ligne.name = "AgentEffets"
	var ecart := int(t.ecart)
	ligne.add_child(Pastilles.pastille(("Demande %+d %%" % ecart).replace("-", "−") if ecart != 0 else "Demande =", Pastilles.ROUGE if ecart > 0 else Pastilles.VERT if ecart < 0 else Charte.IVOIRE_2, "money", "Demande de salaire", 15, "AgentEffetDemande"))
	var n := int(t.essais)
	ligne.add_child(Pastilles.pastille("%d propositions" % n, Pastilles.VERT if n > 3 else Pastilles.ROUGE if n < 3 else Charte.IVOIRE_2, "renew", "Propositions avant la rupture", 15, "AgentEffetEssais"))
	var rel := int(t.relation)
	ligne.add_child(Pastilles.pastille(("Relation %+d" % rel).replace("-", "−"), Pastilles.VERT if rel > 0 else Pastilles.ROUGE, "heart", "Relation avec l’agent", 15, "AgentEffetRelation"))
	return ligne

static func _bulle_ton(cle: String) -> String:
	var t: Dictionary = TONS[cle]
	var ecart := int(t.ecart)
	return ("Demande %+d %%" % ecart if ecart != 0 else "Demande =").replace("-", "−") + " · %d propositions · " % int(t.essais) + ("Relation %+d" % int(t.relation)).replace("-", "−")

static func _choix(app: Control, page: Control, d: Dictionary) -> Array:
	var e: Dictionary = d.e
	if bool(e.get("fin", false)): return []
	var choix: Array = []
	if str(d.ton).is_empty() and (bool(d.libre) or e.has("envoi")):
		for cle: String in ORDRE:
			var t: Dictionary = TONS[cle]
			var ton := cle
			choix.append({"id": "AgentTon_" + cle, "texte": "%s · « %s »" % [str(t.mot).to_upper(), str(t.phrase)], "icone": t.icone, "couleur": t.couleur,
				"bulle": _bulle_ton(cle), "action": func(): _choisir_ton(app, page, d, ton), "actif": bool(d.libre), "choisi": str(e.get("envoi", "")) == cle})
		return choix
	if not str(d.ton).is_empty() and str(e.get("question", "")).is_empty():
		for q: String in ["role", "duree"]:
			var question: Dictionary = QUESTIONS[q]
			var cle_q := q
			choix.append({"id": "AgentQuestion_" + q, "texte": str(question.texte), "icone": question.icone, "couleur": question.couleur,
				"action": func(): _demander(app, page, d, cle_q)})
		return choix
	var bulle := "Faire une offre" if d.ouvert else str(d.p.get("reason", "Transfert fermé"))
	choix.append({"id": "AgentFaireOffre", "texte": "Je vous fais une offre.", "icone": "money", "couleur": Pastilles.VERT, "bulle": bulle,
		"action": _offre(app, page, str(d.id)), "actif": bool(d.ouvert)})
	choix.append({"id": "AgentEnResterLa", "texte": "On en reste là pour l’instant.", "icone": "clock", "couleur": Charte.IVOIRE_2,
		"action": func(): _conclure(app, page, d)})
	return choix

# --- Gauche : joueur, rapport du recruteur, relation ----------------------------------------------------------------------

static func _visage(cote: float) -> Control:
	var fond := PanelContainer.new()
	fond.add_theme_stylebox_override("panel", C.box(Charte.PANNEAU_3.lerp(Pastilles.BLEU, .22), Color.TRANSPARENT, int(cote * .5), 0))
	fond.custom_minimum_size = Vector2(C.px(cote), C.px(cote))
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := C.icon("people", int(cote * .55), Pastilles.BLEU)
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fond.add_child(image)
	return fond

static func _section(parent: Control, x: float, base: float, texte: String, icone: String, couleur: Color) -> void:
	var image := C.icon(icone, 22, couleur)
	parent.add_child(image)
	D.place(image, Rect2(x, base - 20, 22, 22))
	D.text(parent, x + 32, base, texte.to_upper(), 20, Charte.IVOIRE_2, 700, 480)

static func _gauche(app: Control, page: Control, f: Control, zone: Rect2, d: Dictionary) -> void:
	var x0 := zone.position.x + 20
	var l := zone.size.x - 40
	var y := zone.position.y + 20
	var fiche := _fiche(app, page, str(d.id))
	# Joueur : visage, nom (fiche + carte au survol), poste, âge, transfert.
	var cadre := D.rect(f, Rect2(x0, y, 120, 120), Charte.PANNEAU_3, Charte.RAYON_CARTE)
	cadre.clip_contents = true
	var visage: Control = load("res://ui/carnet_skin.gd").portrait(0, int(120 * C.density), d.p)
	visage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(visage)
	visage.position = Vector2.ZERO
	visage.size = Vector2(120, 120) * C.density
	var lien := Pieces.rendre_cliquable(cadre, Vector2(120, 120), fiche, "AgentPortrait", str(d.p.get("name", "")), "", Charte.RAYON_CARTE)
	CarteSurvol.lier(app, lien, str(d.id), "market")
	var xn := x0 + 140
	var nom := Link.styled_button(f, Rect2(xn, y + 4, l - 140, 48), Kit.casse(str(d.p.get("name", "—"))), 34, Charte.IVOIRE, "AgentJoueurNom")
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	nom.pressed.connect(fiche)
	CarteSurvol.lier(app, nom, str(d.id), "market")
	var x := xn
	x += Pastilles.poser(f, Pastilles.pastille(str(d.r.poste), Charte.IVOIRE_2, "people", "Poste", 18, "AgentPoste", fiche), x, y + 62) + 10
	x += Pastilles.poser(f, Pastilles.pastille("%s ans" % G.n(d.p.get("age", "—")), Charte.IVOIRE_2, "calendar", "Âge", 18, "AgentAge", fiche), x, y + 62) + 10
	Pastilles.poser(f, Pastilles.pastille("Transfert ouvert" if d.ouvert else "Transfert fermé", Pastilles.VERT if d.ouvert else Pastilles.ROUGE, "check" if d.ouvert else "lock",
		"" if d.ouvert else str(d.p.get("reason", "")), 18, "AgentTransfert", _offre(app, page, str(d.id)) if d.ouvert else Callable()), x, y + 62)
	# Rapport du recruteur : une ligne façon Effectif (lettre, note au poste, familiarité, rang chez nous).
	y += 160
	_section(f, x0, y, "Rapport du recruteur", "search", Pastilles.BLEU)
	y += 14
	var r: Dictionary = d.r
	var ligne := Button.new()
	ligne.name = "AgentRapportLigne"
	ligne.accessibility_name = "Rapport du recruteur"
	Kit.styler_ligne(ligne, Charte.PANNEAU_3)
	f.add_child(ligne)
	D.place(ligne, Rect2(x0, y, l, 92))
	ligne.pressed.connect(_fermer(page))
	var lettre := D.text(ligne, 50, 70, str(r.lettre), 64, r.couleur, 800, 100, HORIZONTAL_ALIGNMENT_CENTER)
	lettre.add_theme_font_override("font", Charte.TITRE_FICHE)
	lettre.name = "AgentRapportLettre"
	Kit.etiquette(ligne, 120, 30, "Note au poste", 160)
	Familiarite.poser_note(ligne, 120, 76, float(r.note), 38, 70, "AgentNotePoste").add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	Kit.etiquette(ligne, 300, 30, "Familiarité", 200)
	Familiarite.poser(ligne, 300, 72, Familiarite.niveau(r.piste, int(r.numero)), 22, "AgentFamiliarite")
	Kit.etiquette(ligne, 540, 30, "Rang chez nous", 200)
	var rang := D.text(ligne, 540, 76, "%d / %d" % [int(r.rang), int(r.total)], 36, Pastilles.VERT if int(r.rang) == 1 else Charte.IVOIRE, 800, 190)
	rang.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	for enfant in ligne.get_children():
		if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pour / Contre : deux colonnes de lignes, icônes vertes / rouges.
	y += 112
	var demi := (l - 16) / 2.0
	_raisons(f, x0, y, demi, "Pour", "check", Pastilles.VERT, r.pour, "AgentPour")
	_raisons(f, x0 + demi + 16, y, demi, "Contre", "warning", Pastilles.ROUGE, r.contre, "AgentContre")
	# Relation avec l'agent : 5 crans, mot, valeur, pastilles d'effet ; puis demande et propositions de la journée.
	y = zone.end.y - 226
	_section(f, x0, y, "Relation avec l’agent", "heart", RELATIONS[cran(int(d.relation))][1])
	_relation(f, Rect2(x0, y + 16, l, 64), d)
	Pastilles.poser(f, effets_relation(d.effet, "Agent"), x0, y + 70)
	y += 148
	var dx := x0
	var ecart := (0 if str(d.ton).is_empty() else int(TONS[d.ton].ecart)) + int(d.effet.get("demande", 0))
	dx += Pastilles.poser(f, Pastilles.tuile(G.salary(int(d.salaire)), "demande", Pastilles.ROUGE if ecart > 0 else Pastilles.VERT if ecart < 0 else Pastilles.BLEU, Charte.PANNEAU_3, 26, "AgentDemande", true, _offre(app, page, str(d.id))), dx, y) + 32
	var essais := int(d.essais)
	var faites := int(d.faites)
	Pastilles.poser(f, _propositions(essais, faites), dx, y + 4)

static func _relation(f: Control, zone: Rect2, d: Dictionary) -> void:
	var n := cran(int(d.relation))
	var ecart := 8.0
	var lc := (zone.size.x - 150 - ecart * 4) / 5.0
	for i in 5:
		var a: Array = RELATIONS[i]
		var actif := i == n
		var case_ := D.rect(f, Rect2(zone.position.x + i * (lc + ecart), zone.position.y, lc, 44), Color(a[1], .88 if actif else (.30 if i < n else .10)), Charte.RAYON_PETIT)
		case_.name = "AgentRelationCran_%d" % i
		case_.tooltip_text = str(a[0])
		case_.mouse_filter = Control.MOUSE_FILTER_PASS
		D.text(case_, lc * .5, 30, str(a[0]), 17, Charte.ENCRE if actif else Color(a[1], .8), 700, lc - 6, HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var valeur := int(d.relation)
	var chiffre := D.text(f, zone.end.x, zone.position.y + 36, ("%+d" % valeur).replace("-", "−") if valeur != 0 else "0", 34, RELATIONS[n][1], 800, 130, HORIZONTAL_ALIGNMENT_RIGHT)
	chiffre.name = "AgentRelationValeur"
	chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	chiffre.tooltip_text = "Relation avec l’agent (−10 à +10)"
	chiffre.mouse_filter = Control.MOUSE_FILTER_PASS

## Effet de la relation sur la négociation (moteur : market[].agent.effet) : demande, propositions, minimum accepté.
## Neutre : une pastille « Sans effet ». Couleur : vert si ça nous aide, rouge sinon.
static func effets_relation(effet: Dictionary, prefixe: String, taille := 15) -> Control:
	var ligne := C.h(8)
	ligne.name = prefixe + "EffetsRelation"
	var demande := int(effet.get("demande", 0))
	var essais := int(effet.get("essais", 0))
	var seuil := int(effet.get("seuil", 0))
	if demande == 0 and essais == 0 and seuil == 0:
		ligne.add_child(Pastilles.pastille("Sans effet", Charte.IVOIRE_2, "people", "Relation sans effet sur la négociation", taille, prefixe + "EffetRelationNeutre"))
		return ligne
	if demande != 0:
		ligne.add_child(Pastilles.pastille(("Demande %+d %%" % demande).replace("-", "−"), Pastilles.ROUGE if demande > 0 else Pastilles.VERT, "money", "Demande de salaire", taille, prefixe + "EffetRelationDemande"))
	if essais != 0:
		ligne.add_child(Pastilles.pastille(("%+d proposition" % essais).replace("-", "−"), Pastilles.VERT if essais > 0 else Pastilles.ROUGE, "renew", "Propositions avant la rupture", taille, prefixe + "EffetRelationEssais"))
	if seuil != 0:
		ligne.add_child(Pastilles.pastille(("Minimum %+d %%" % seuil).replace("-", "−"), Pastilles.ROUGE if seuil > 0 else Pastilles.VERT, "check", "Salaire minimum accepté", taille, prefixe + "EffetRelationSeuil"))
	return ligne

## Propositions de la journée : une pastille par essai (faites en orange).
static func _propositions(essais: int, faites: int) -> Control:
	var ligne := C.h(6)
	ligne.name = "AgentPropositions"
	ligne.tooltip_text = "Propositions avant la rupture"
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	ligne.add_child(C.icon("renew", 22, Charte.IVOIRE_2))
	for i in essais:
		var faite := i < faites
		var rond := PanelContainer.new()
		rond.name = "AgentProposition_%d" % (i + 1)
		rond.add_theme_stylebox_override("panel", C.box(Charte.PANNEAU_3.lerp(Pastilles.ORANGE, .45) if faite else Charte.PANNEAU_3, Pastilles.ORANGE if faite else Charte.FILET, Charte.RAYON_PILULE, 0))
		rond.custom_minimum_size = Vector2(C.px(40), C.px(36))
		rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var chiffre := C.label(str(i + 1), 18, Pastilles.ORANGE if faite else Charte.IVOIRE, true, 700)
		chiffre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chiffre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rond.add_child(chiffre)
		ligne.add_child(rond)
	return ligne

## Lignes Pour / Contre : icône teintée + mot + chiffre ; ligne cliquable (action du rapport).
static func _raisons(parent: Control, x: float, y: float, l: float, titre: String, icone: String, couleur: Color, raisons: Array, id: String, max_lignes := 4, pas := 50.0) -> void:
	var tete := C.icon(icone, 22, couleur)
	parent.add_child(tete)
	D.place(tete, Rect2(x, y, 22, 22))
	var t := D.text(parent, x + 32, y + 20, "%s · %d" % [titre.to_upper(), raisons.size()], 20, couleur, 800, l - 40)
	t.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	var ly := y + 34
	for i in mini(raisons.size(), max_lignes):
		var raison: Array = raisons[i]
		var ligne := Button.new()
		ligne.name = "%s_%d" % [id, i]
		ligne.accessibility_name = "%s %s" % [raison[1], raison[2]]
		Kit.styler_ligne(ligne, Charte.PANNEAU_3 if i % 2 == 0 else Charte.PANNEAU)
		parent.add_child(ligne)
		D.place(ligne, Rect2(x, ly, l, pas - 6))
		if (raison[3] as Callable).is_valid(): ligne.pressed.connect(raison[3])
		var image := C.icon(str(raison[0]), 20, couleur)
		ligne.add_child(image)
		D.place(image, Rect2(10, (pas - 6 - 20) / 2.0, 20, 20))
		D.text(ligne, 40, (pas - 6) / 2.0 + 7, str(raison[1]), 18, Charte.IVOIRE, 600, l - 120, HORIZONTAL_ALIGNMENT_LEFT, true).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not str(raison[2]).is_empty():
			var chiffre := D.text(ligne, l - 12, (pas - 6) / 2.0 + 8, str(raison[2]), 20, couleur, 800, 80, HORIZONTAL_ALIGNMENT_RIGHT)
			chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
			chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for enfant in ligne.get_children():
			if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		ly += pas
	if raisons.size() > max_lignes: Kit.texte(parent, x + 10, ly + 18, "+%d" % (raisons.size() - max_lignes), Charte.IVOIRE_3, 80, 16)
