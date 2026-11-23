extends RefCounted
## Discussion avec l'agent d'une piste du marché (revue FM27, idée 24, choix de Léo du 23/11/2026) : même fenêtre que la
## discussion avec un joueur (fenetre_discussion.gd). Ouverte depuis le Rapport du recruteur (pastille « Parler à
## <agent> ») et la piste choisie du Recrutement (« Parler à l'agent → »). Retour de Léo du 23/11 au soir : c'est l'AGENT
## qu'on voit (agent nommé, ui/agent_joueur.gd), il parle de son client à la 3e personne ; la relation n'apparaît
## qu'une fois, dans son en-tête (pas d'échelle au-dessus du fil).
##  - Gauche : en-tête de l'agent (portrait d'adulte, nom cliquable → sa petite fenêtre, agence, caractère « ? » tant
##    qu'il n'est pas découvert, humeur, relation en 5 crans qui s'allume et bouge pendant l'échange) ; carte « Au sujet
##    de » (photo, nom, poste, âge, demande, transfert, rapport du recruteur compact : lettre, note au poste /100,
##    familiarité, rang chez nous) ; « Ses joueurs » façon Effectif (le joueur concerné surligné ; clic = fiche).
##  - Droite : le fil en trois tours (le ton ; une question sur le rôle attendu ou la durée ; faire une offre ou en rester
##    là), les bulles de l'agent avec SON portrait. Un clic sur une phrase la dit tout de suite : aucun bouton Valider.
## Ton (moteur native/engine/ton-agent.cjs, commandes agent_ton / agent_question, projection market[].agent) : il fait
## pencher demande et patience EN MOYENNE (avec la relation, le caractère caché et le hasard) ; aucun effet chiffré n'est
## montré. Un ton par piste et par journée, avant la première proposition. La question du 2e tour découvre le caractère.
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
const AgentJoueur = preload("res://ui/agent_joueur.gd")

const NOM := "DiscussionAgent"
const CLE := "agent_tons"
const ORDRE := ["tout_prix", "enthousiaste", "curieux"]
## Tons : mot, nos mots, couleur, icône (effets cachés, dans le moteur).
const TONS := {
	"tout_prix": {"mot": "À tout prix", "phrase": "On le veut, quoi qu’il en coûte.", "couleur": Pastilles.ORANGE, "icone": "target"},
	"enthousiaste": {"mot": "Enthousiaste", "phrase": "Il nous plaît beaucoup.", "couleur": Pastilles.VERT, "icone": "star"},
	"curieux": {"mot": "Curieux", "phrase": "On se renseigne, sans plus.", "couleur": Pastilles.BLEU, "icone": "search"}}
## Humeur de l'agent (moteur : selon sa patience cachée, brouillée) : mot, couleur, icône, réplique.
const HUMEURS := {"calme": ["Calme", Pastilles.VERT, "check", "On peut encore en parler."],
	"agace": ["Agacé", Pastilles.ORANGE, "info", "Mon client commence à s’impatienter."],
	"tendu": ["Tendu", Pastilles.ROUGE, "warning", "Ne me faites pas perdre mon temps."],
	"rompu": ["Parti", Pastilles.ROUGE, "lock", "On arrête là pour aujourd’hui."]}
## Relation avec l'agent : 5 crans (moteur : Froide ≤ −6 < Distante ≤ −2 < Neutre < 2 ≤ Bonne < 6 ≤ Proche).
const RELATIONS := AgentJoueur.RELATIONS
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
		"faites": int(a.get("faites", 0)), "cran": clampi(int(a.get("cran", 2)), 0, 4), "avant": clampi(int(a.get("avant", a.get("cran", 2))), 0, 4),
		"caractere": str(a.get("caractere", "")), "humeur": str(a.get("humeur", "calme")) if HUMEURS.has(str(a.get("humeur", ""))) else "calme",
		"libre": bool(a.get("libre", false)) and not e.has("envoi"), "ouvert": bool(p.get("available", false)),
		"salaire": int(p.get("salary", 0)) if p.get("salary") is int or p.get("salary") is float else 0,
		"attendu": str(roles.get("attendu", "")) if roles is Dictionary else "", "max": int(p.get("maxYears", 1)),
		"nego": p.get("negotiation", {}) if p.get("negotiation") is Dictionary else {}, "prenom": Kit.casse(str(p.get("name", "—")), true),
		"ag": _agent_nomme(app, id, a)}

## Agent nommé du joueur (annuaire projeté) ; à défaut, son nom porté par la piste.
static func _agent_nomme(app: Control, id: String, a: Dictionary) -> Dictionary:
	var ag := AgentJoueur.de_joueur(app, id)
	if not ag.is_empty(): return ag
	return {"id": str(a.get("agent", "")), "nom": str(a.get("nom", "Agent")), "agence": "", "cran": int(a.get("cran", 2)), "caractere": str(a.get("caractere", "")), "clients": [], "total": 0}

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

## Question du 2e tour : l'agent se dévoile (le moteur découvre son caractère), la page revient avec la fenêtre rouverte.
static func _demander(app: Control, page: Control, d: Dictionary, q: String) -> void:
	d.e["question"] = q
	_pages().etat(app)["agent"] = true
	_redessiner(app, page, d.id)
	app._command("agent_question", {"playerId": d.id})

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
	FenetreDiscussion.ouvrir(page, {"nom": NOM, "titre": "Discussion avec l’agent", "icone": "people", "prefixe": "Agent",
		"gauche": func(f: Control, zone: Rect2): _gauche(app, page, f, zone, d),
		"visage": func() -> Control: return AgentJoueur.visage(d.ag, 52, "AgentVisage"),
		"fil": _fil(d), "choix": _choix(app, page, d)})

# --- Fil et choix ------------------------------------------------------------------------------------------------------

static func accueil(d: Dictionary) -> String:
	match int(d.avant):
		0: return "Encore vous. Faites vite : mon client a d’autres pistes."
		1: return "Mon client %s ? J’écoute." % str(d.prenom)
		3: return "Content de vous entendre. Vous appelez pour mon client %s ?" % str(d.prenom)
		4: return "Toujours un plaisir. On parle de mon client %s ?" % str(d.prenom)
	return "Vous vouliez me parler de mon client %s ?" % str(d.prenom)

static func reponse_ton(d: Dictionary) -> String:
	var montant := G.salary(int(d.salaire))
	match str(d.ton):
		"tout_prix": return "Alors pour mon client, ce sera %s, pas moins." % montant
		"enthousiaste": return "Mon client sera ravi. On part sur %s." % montant
		"curieux": return "%s. D’autres clubs appellent pour lui." % montant
	return ""

static func reponse_question(d: Dictionary, q: String) -> String:
	if q == "role":
		return "Mon client se voit %s." % Role.libelle(str(d.attendu)).to_lower() if not str(d.attendu).is_empty() else "Mon client veut jouer, c’est tout."
	var n := clampi(int(d.max), 1, 3)
	return "Mon client signe pour une saison, pas plus." if n == 1 else "Mon client signerait jusqu’à %d saisons." % n

static func _fil(d: Dictionary) -> Array:
	var fil: Array = [{"qui": "lui", "id": "AgentBulleAccueil", "texte": accueil(d), "couleur": Pastilles.BLEU}]
	var e: Dictionary = d.e
	var ton := str(d.ton) if not str(d.ton).is_empty() else str(e.get("envoi", ""))
	if not ton.is_empty():
		var t: Dictionary = TONS[ton]
		fil.append({"qui": "moi", "id": "AgentBulleTon", "texte": str(t.phrase), "couleur": t.couleur})
		if not str(d.ton).is_empty():
			fil.append({"qui": "lui", "id": "AgentBulleDemande", "texte": reponse_ton(d), "couleur": Pastilles.BLEU})
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
		fil.append({"qui": "lui", "id": "AgentBulleAuRevoir", "texte": "Ne tardez pas trop : mon client ne vous attendra pas.", "couleur": Pastilles.BLEU})
	return fil

static func _choix(app: Control, page: Control, d: Dictionary) -> Array:
	var e: Dictionary = d.e
	if bool(e.get("fin", false)): return []
	var choix: Array = []
	if str(d.ton).is_empty() and (bool(d.libre) or e.has("envoi")):
		for cle: String in ORDRE:
			var t: Dictionary = TONS[cle]
			var ton := cle
			choix.append({"id": "AgentTon_" + cle, "texte": "%s · « %s »" % [str(t.mot).to_upper(), str(t.phrase)], "icone": t.icone, "couleur": t.couleur,
				"bulle": str(t.mot), "action": func(): _choisir_ton(app, page, d, ton), "actif": bool(d.libre), "choisi": str(e.get("envoi", "")) == cle})
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

# --- Gauche : l'agent (en-tête), le joueur dont on parle, ses autres joueurs ---------------------------------------------

static func _section(parent: Control, x: float, base: float, texte: String, icone: String, couleur: Color) -> void:
	var image := C.icon(icone, 22, couleur)
	parent.add_child(image)
	D.place(image, Rect2(x, base - 20, 22, 22))
	D.text(parent, x + 32, base, texte.to_upper(), 20, Charte.IVOIRE_2, 700, 480)

static func _gauche(app: Control, page: Control, f: Control, zone: Rect2, d: Dictionary) -> void:
	var x0 := zone.position.x + 20
	var l := zone.size.x - 40
	var y := zone.position.y + 20
	var ag: Dictionary = d.ag
	# En-tête de l'agent : portrait, nom (petite fenêtre), agence, caractère, humeur, puis la relation en 5 crans.
	var portrait := AgentJoueur.poser_portrait(f, Rect2(x0, y, 130, 130), ag, "AgentPortrait", AgentJoueur.RANGS.get(str(ag.get("rang", "petite")), Pastilles.BLEU))
	if not str(ag.get("id", "")).is_empty():
		Pieces.rendre_cliquable(portrait, Vector2(130, 130), func(): AgentJoueur.ouvrir(app, page, str(ag.id), str(d.id), AgentJoueur.ligne_de(d.p, "marche")), "AgentPortraitLien", str(ag.get("nom", "")), str(ag.get("agence", "")), Charte.RAYON_CARTE)
	var xn := x0 + 150
	var nom := AgentJoueur.lien_nom(app, page, f, Rect2(xn, y, l - 150, 52), ag, 34, "AgentNom", Charte.IVOIRE, str(d.id), AgentJoueur.ligne_de(d.p, "marche"))
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	if not str(ag.get("agence", "")).is_empty(): Pastilles.poser(f, AgentJoueur.agence(ag, "Agent", 17), xn, y + 58)
	Kit.etiquette(f, xn, y + 118, "Caractère", 200)
	Kit.etiquette(f, xn + 280, y + 118, "Humeur", 200)
	Pastilles.poser(f, caractere(str(d.caractere), "Agent", 22), xn, y + 126)
	Pastilles.poser(f, humeur(str(d.humeur), "Agent", 22), xn + 280, y + 126)
	y += 190
	Kit.etiquette(f, x0, y, "Relation", 200)
	AgentJoueur.crans(f, Rect2(x0, y + 10, l, 50), int(d.cran), int(d.avant), "Agent")
	# Au sujet de : le joueur (fiche, carte au survol), sa demande, le transfert, le rapport du recruteur compact.
	y += 108
	_section(f, x0, y, "Au sujet de", "search", Pastilles.ORANGE)
	y += 12
	_sujet(app, page, f, Rect2(x0, y, l, 196), d)
	# Ses joueurs : les clients de l'agent façon Effectif (le joueur concerné surligné ; clic = fiche).
	y += 212
	AgentJoueur.clients(app, f, Rect2(x0, y, l, zone.end.y - y - 12), ag, str(d.id), "Agent", func(): Fenetre.fermer(page, NOM), 6, AgentJoueur.ligne_de(d.p, "marche"))

## Carte « Au sujet de » : photo, nom, poste, âge, demande, transfert ; dessous le rapport du recruteur en une ligne.
static func _sujet(app: Control, page: Control, f: Control, zone: Rect2, d: Dictionary) -> void:
	var carte := D.rect(f, zone, Charte.PANNEAU_3.lerp(Pastilles.ORANGE, .06), Charte.RAYON_CARTE, Color(Pastilles.ORANGE, .5))
	carte.name = "AgentSujet"
	carte.mouse_filter = Control.MOUSE_FILTER_PASS
	var fiche := _fiche(app, page, str(d.id))
	var x0 := zone.position.x + 14
	var y := zone.position.y + 14
	var cadre := D.rect(f, Rect2(x0, y, 84, 84), Charte.PANNEAU_3, Charte.RAYON_PETIT)
	cadre.clip_contents = true
	var visage: Control = load("res://ui/carnet_skin.gd").portrait(0, int(84 * C.density), d.p)
	visage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(visage)
	visage.position = Vector2.ZERO
	visage.size = Vector2(84, 84) * C.density
	var lien := Pieces.rendre_cliquable(cadre, Vector2(84, 84), fiche, "AgentJoueurPortrait", str(d.p.get("name", "")), "", Charte.RAYON_PETIT)
	CarteSurvol.lier(app, lien, str(d.id), "market")
	var xn := x0 + 102
	var l := zone.size.x - 116
	var nom := Link.styled_button(f, Rect2(xn, y - 2, l - 200, 42), Kit.casse(str(d.p.get("name", "—"))), 28, Charte.IVOIRE, "AgentJoueurNom")
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	nom.pressed.connect(fiche)
	CarteSurvol.lier(app, nom, str(d.id), "market")
	var x := xn
	x += Pastilles.poser(f, Pastilles.pastille(str(d.r.poste), Charte.IVOIRE_2, "people", "Poste", 16, "AgentPoste", fiche), x, y + 46) + 8
	x += Pastilles.poser(f, Pastilles.pastille("%s ans" % G.n(d.p.get("age", "—")), Charte.IVOIRE_2, "calendar", "Âge", 16, "AgentAge", fiche), x, y + 46) + 8
	Pastilles.poser(f, Pastilles.pastille(G.salary(int(d.salaire)), Pastilles.BLEU, "money", "Demande", 16, "AgentDemande", _offre(app, page, str(d.id)) if d.ouvert else Callable()), x, y + 46)
	# Transfert : à droite du nom (la ligne des pastilles reste dans la carte).
	Pastilles.poser_a_droite(f, Pastilles.pastille("Transfert ouvert" if d.ouvert else "Transfert fermé", Pastilles.VERT if d.ouvert else Pastilles.ROUGE, "check" if d.ouvert else "lock",
		"" if d.ouvert else str(d.p.get("reason", "")), 16, "AgentTransfert", _offre(app, page, str(d.id)) if d.ouvert else Callable()), zone.end.x - 14, y + 2)
	# Rapport du recruteur compact : lettre, note au poste /100, familiarité, rang chez nous (clic = ferme, rapport dessous).
	var r: Dictionary = d.r
	var ligne := Button.new()
	ligne.name = "AgentRapportLigne"
	ligne.accessibility_name = "Rapport du recruteur"
	Kit.styler_ligne(ligne, Charte.PANNEAU_2)
	f.add_child(ligne)
	D.place(ligne, Rect2(x0, y + 96, zone.size.x - 28, 74))
	ligne.pressed.connect(_fermer(page))
	var lettre := D.text(ligne, 40, 56, str(r.lettre), 50, r.couleur, 800, 80, HORIZONTAL_ALIGNMENT_CENTER)
	lettre.add_theme_font_override("font", Charte.TITRE_FICHE)
	lettre.name = "AgentRapportLettre"
	Kit.etiquette(ligne, 100, 26, "Note au poste", 160)
	Familiarite.poser_note(ligne, 100, 62, float(r.note), 30, 60, "AgentNotePoste").add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	Kit.etiquette(ligne, 270, 26, "Familiarité", 200)
	Familiarite.poser(ligne, 270, 58, Familiarite.niveau(r.piste, int(r.numero)), 20, "AgentFamiliarite")
	Kit.etiquette(ligne, 500, 26, "Rang chez nous", 200)
	var rang := D.text(ligne, 500, 62, "%d / %d" % [int(r.rang), int(r.total)], 30, Pastilles.VERT if int(r.rang) == 1 else Charte.IVOIRE, 800, 190)
	rang.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	for enfant in ligne.get_children():
		if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

## Caractère de l'agent : le mot une fois découvert, « ? » sinon (jamais ses effets).
static func caractere(mot: String, prefixe: String, taille := 16) -> Control:
	return AgentJoueur.caractere(mot, prefixe, taille)

## Humeur de l'agent : mot, couleur et icône (aucun chiffre).
static func humeur(cle: String, prefixe: String, taille := 16) -> Control:
	var h: Array = HUMEURS.get(cle, HUMEURS.calme)
	return Pastilles.pastille(str(h[0]), h[1], str(h[2]), "Humeur de l’agent", taille, prefixe + "Humeur")
