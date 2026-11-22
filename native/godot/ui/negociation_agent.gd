extends RefCounted
## Négociation avec l'agent (idée FM 18, planche du 22/11/2026, CD_VARIANTE_VISUELLE=A|B ; sans variable : écran inchangé).
## L'agent répond en bulles courtes, chaque ligne du contrat acceptée passe au vert, effet sur la masse salariale et le
## budget de transferts, étape « promesses » (rôle Titulaire / Rotation / Espoir / Appoint) avant le contrat.
## A : trois colonnes (budgets à gauche, lignes du contrat au centre, agent à droite), promesses en tête de la liste.
## B : deux étapes (promesses en liste, puis table face à face toi / l'agent), budgets en jauges en bas.
## Affichage seul : les champs OfferSalary / OfferYears de contract_negotiation.gd restent les seuls envoyés au moteur.
## Le rôle promis n'est pas encore lu par le moteur (idée 16, branche claude/fm-temps-jeu) : il est gardé dans l'écran.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const G = preload("res://ui/game_skin.gd")
const Salary = preload("res://ui/salary_display.gd")
const Offre = preload("res://ui/offre_visuelle.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const LARGEUR := 1500.0
const HAUTEUR := 860.0
const ROLES := ["titulaire", "rotation", "espoir", "appoint"]
const ROLE_NOM := {"titulaire":"Titulaire", "rotation":"Rotation", "espoir":"Espoir", "appoint":"Appoint"}
## Repères de l'idée 16 (minutes par match) : Titulaire ≥ 50, Rotation ≥ 20, Espoir et Appoint au moins un match.
const ROLE_MINUTES := {"titulaire":"≥ 50 min", "rotation":"≥ 20 min", "espoir":"1 match / 4", "appoint":"—"}
const ROLE_ICONE := {"titulaire":"star", "rotation":"renew", "espoir":"school", "appoint":"people"}

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

static func role_couleur(role: String) -> Color:
	return {"titulaire":Pieces.VERT, "rotation":Pieces.BLEU, "espoir":Pieces.VIOLET, "appoint":Charte.IVOIRE_2}.get(role, Charte.IVOIRE_2)

# --- Données -----------------------------------------------------------------------------------------------------------

## Rôle attendu par le joueur : rang de sa note parmi les joueurs du poste (lui compris), places du XV à ce poste
## (même règle que l'idée 16).
static func role_attendu(app: Control, joueur: Dictionary) -> String:
	var pos := str(joueur.get("pos", ""))
	var notes: Array = []
	var places := 0
	var dedans := false
	for q: Dictionary in app.model.get("squad", []):
		if str(q.get("pos", "")) != pos: continue
		if str(q.get("id", "")) == str(joueur.get("id", "")): dedans = true
		notes.append(_note(q))
		var numero: Variant = q.get("shirtNumber")
		if (numero is int or numero is float) and int(numero) <= 15: places += 1
	if not dedans: notes.append(_note(joueur))
	places = maxi(1, places)
	var note := _note(joueur)
	var rang := 0
	for n: float in notes:
		if n > note: rang += 1
	if rang < places: return "titulaire"
	if rang < 2 * places: return "rotation"
	return "espoir" if int(joueur.get("age", 30)) <= 21 else "appoint"

static func _note(joueur: Dictionary) -> float:
	var r: Variant = joueur.get("rating")
	return float(r) if r is int or r is float else 0.0

static func _etat_ui(app: Control, cle: String) -> Dictionary:
	var valeur: Variant = app.management_ui.get(cle)
	if not valeur is Dictionary:
		valeur = {}
		app.management_ui[cle] = valeur
	return valeur

static func role_choisi(app: Control, id: String) -> String:
	return str(_etat_ui(app, "negociation_roles").get(id, ""))

static func etape(app: Control, id: String) -> String:
	return str(_etat_ui(app, "negociation_etapes").get(id, "promesses"))

## État d'une ligne : "ok" (accord, vert), "proche" (orange), "loin" (rouge), "attente" (gris, étape non faite).
static func donnees(ctx: Dictionary) -> Dictionary:
	var val := Offre.valeurs(ctx)
	var app: Control = ctx.app
	var joueur: Dictionary = ctx.player
	var id := str(joueur.get("id", ""))
	var negociation: Dictionary = ctx.negotiation
	var contre := str(negociation.get("status", "")) == "counter"
	var retrait := bool(ctx.phase.get("blocked", false))
	var cible := int(negociation.get("salary", val.demande)) if contre else int(val.demande)
	var propose := int(val.propose)
	var etat_salaire := "ok" if propose >= cible else "proche" if float(propose) >= .9 * cible else "loin"
	var etat_duree := "ok"
	if contre and int(val.annees) != int(negociation.get("years", val.annees)): etat_duree = "proche"
	var fee := maxi(0, int(val.fee))
	var budget: Dictionary = val.budget
	var etat_prime := "ok"
	if not budget.is_empty() and int(budget.get("disponible", 0)) < fee: etat_prime = "loin"
	elif val.prolongation and (val.cash is int or val.cash is float) and int(val.cash) < fee: etat_prime = "loin"
	var attendu := role_attendu(app, joueur)
	var choisi := role_choisi(app, id)
	var etat_role := "attente"
	if not choisi.is_empty():
		var ecart := ROLES.find(choisi) - ROLES.find(attendu)
		etat_role = "ok" if ecart <= 0 else "proche" if ecart == 1 else "loin"
	var paie := P.payroll(app.model)
	var masse := float(paie.players_weekly)
	var ajout := propose - (int(val.actuel) if val.prolongation else 0)
	var finance: Dictionary = app.model.get("finance", {})
	var saison: Variant = finance.get("budget")
	var d := val.duplicate()
	d.merge({"id":id, "contre":contre, "retrait":retrait, "cible":cible, "tentatives":int(negociation.get("attempts", 0)),
		"contre_annees":int(negociation.get("years", 0)), "salaire":etat_salaire, "duree":etat_duree, "prime":etat_prime,
		"attendu":attendu, "choisi":choisi, "role":etat_role, "masse":masse, "ajout":ajout, "apres":masse + ajout,
		"semaines":int(paie.weeks), "saison":saison if saison is Dictionary else {}})
	d["accords"] = [etat_role, etat_salaire, etat_duree, etat_prime].count("ok")
	return d

static func couleur_etat(etat: String) -> Color:
	return {"ok":Pieces.VERT, "proche":Pieces.ORANGE, "loin":Pieces.ROUGE}.get(etat, Charte.IVOIRE_3)

static func icone_etat(etat: String) -> String:
	return {"ok":"check", "proche":"renew", "loin":"warning"}.get(etat, "lock")

static func mot_etat(etat: String) -> String:
	return {"ok":"Accord", "proche":"Écart", "loin":"Refus"}.get(etat, "À faire")

## Bulles de l'agent (citations courtes, chiffrées) : [texte, couleur, agent?].
static func bulles(d: Dictionary) -> Array:
	var liste: Array = []
	if d.retrait:
		liste.append(["On arrête là pour aujourd’hui.", Pieces.ROUGE, true])
		return liste
	liste.append(["Il demande %s." % G.salary(d.demande), Charte.IVOIRE, true])
	if int(d.min) != int(d.max): liste.append(["%d à %d saisons." % [int(d.min), int(d.max)], Charte.IVOIRE, true])
	else: liste.append(["%d saison." % int(d.min), Charte.IVOIRE, true])
	var choisi := str(d.choisi)
	if choisi.is_empty(): liste.append(["Quel rôle pour lui ?", Pieces.BLEU, true])
	else:
		liste.append([ROLE_NOM[choisi], role_couleur(choisi), false])
		liste.append([{"ok":"Ça lui va.", "proche":"Il espérait mieux.", "loin":"Hors de question."}[str(d.role)], couleur_etat(str(d.role)), true])
	if d.contre:
		liste.append(["Pas sous %s." % G.salary(d.cible), Pieces.ORANGE, true])
	liste.append([G.salary(d.propose) + " · %d an%s" % [int(d.annees), "s" if int(d.annees) > 1 else ""], Pieces.BLEU, false])
	if str(d.salaire) == "ok" and str(d.role) == "ok": liste.append(["Marché conclu si tu envoies.", Pieces.VERT, true])
	elif str(d.salaire) != "ok": liste.append(["Trop bas.", couleur_etat(str(d.salaire)), true])
	return liste

# --- Construction ------------------------------------------------------------------------------------------------------

## Remplace la toile de l'offre (offre_visuelle / prolongation_visuelle) par celle de la variante.
static func construire(body: Control, ctx: Dictionary, v: String) -> Control:
	var toile := Control.new()
	toile.name = "OffreVisuelle"
	toile.custom_minimum_size = Vector2(LARGEUR, HAUTEUR) * C.density
	toile.mouse_filter = Control.MOUSE_FILTER_PASS
	toile.set_meta("negociation_variante", v)
	body.add_child(toile)
	body.move_child(toile, 0)
	var dessin := Control.new()
	dessin.name = "NegoDessin"
	dessin.mouse_filter = Control.MOUSE_FILTER_PASS
	toile.add_child(dessin)
	D.place(dessin, Rect2(0, 0, LARGEUR, HAUTEUR))
	for champ: SpinBox in [ctx.salary, ctx.years]:
		if champ.get_parent() != null: champ.get_parent().remove_child(champ)
		toile.add_child(champ)
	var redessiner := func(): _dessiner(toile, dessin, ctx, v)
	ctx["redessiner"] = redessiner
	ctx.salary.value_changed.connect(func(_x: float): redessiner.call())
	ctx.years.value_changed.connect(func(_x: float): redessiner.call())
	redessiner.call()
	toile.set_meta("recap", func() -> Control: return Offre.recap(ctx))
	toile.set_meta("y_confirmation", 170.0)
	return toile

static func _dessiner(toile: Control, dessin: Control, ctx: Dictionary, v: String) -> void:
	if not is_instance_valid(dessin): return
	Offre._vider(dessin)
	var d := donnees(ctx)
	if v == "A": _option_a(toile, dessin, ctx, d)
	else: _option_b(toile, dessin, ctx, d)
	Offre._marquer(toile)

static func _choisir_role(ctx: Dictionary, role: String) -> void:
	_etat_ui(ctx.app, "negociation_roles")[str(ctx.player.get("id", ""))] = role
	(ctx.redessiner as Callable).call()

static func _aller(ctx: Dictionary, vers: String) -> void:
	_etat_ui(ctx.app, "negociation_etapes")[str(ctx.player.get("id", ""))] = vers
	(ctx.redessiner as Callable).call()

static func _titre(parent: Node, x: float, y: float, texte: String, couleur: Color = Charte.IVOIRE_2, taille: int = 17, largeur: float = 500) -> Label:
	var l := D.text(parent, x, y, texte.to_upper(), taille, couleur, 700, largeur)
	l.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	return l

static func _gros(parent: Node, x: float, y: float, texte: String, couleur: Color, taille: int = 30, largeur: float = 300, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := D.text(parent, x, y, texte, taille, couleur, 800, largeur, align)
	l.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	return l

static func _icone(parent: Node, zone: Rect2, id: String, couleur: Color) -> TextureRect:
	var image := TextureRect.new()
	image.texture = C.icon_texture(id, couleur)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	D.place(image, zone)
	return image

## Rond d'état (forme + couleur) : ✓ accord, ↻ écart, ⚠ refus, cadenas à faire.
static func _rond(parent: Node, x: float, y: float, etat: String, diametre: float = 38) -> void:
	var couleur := couleur_etat(etat)
	var rond := D.rect(parent, Rect2(x, y, diametre, diametre), Color(couleur, .2), Charte.RAYON_PILULE, couleur)
	rond.name = "NegoEtat"
	_icone(rond, Rect2(diametre * .22, diametre * .22, diametre * .56, diametre * .56), icone_etat(etat), couleur)

## Bulle : à gauche pour l'agent (fond panneau), à droite pour toi (bleu). Renvoie la hauteur prise.
static func _bulle(parent: Node, x: float, y: float, largeur_max: float, texte: String, couleur: Color, agent: bool, id: String) -> float:
	var px := maxi(12, C.px(19))
	var w := minf(largeur_max, C.BODY.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x / C.density + 32)
	var bx := x if agent else x + largeur_max - w
	var fond := Charte.PANNEAU_3.lerp(couleur, .22) if couleur != Charte.IVOIRE else Charte.PANNEAU_3
	var bulle := D.rect(parent, Rect2(bx, y, w, 44), fond, 14, Color(couleur, .7) if couleur != Charte.IVOIRE else Color.TRANSPARENT)
	bulle.name = id
	D.text(bulle, 16, 29, texte, 19, couleur if couleur != Charte.IVOIRE else Charte.IVOIRE, 600, w - 24, HORIZONTAL_ALIGNMENT_LEFT, true).name = id + "Texte"
	return 52.0

static func _avatar_agent(parent: Node, x: float, y: float, d: float) -> Panel:
	var rond := D.rect(parent, Rect2(x, y, d, d), Color(Pieces.BLEU, .18), Charte.RAYON_PILULE, Pieces.BLEU)
	rond.name = "NegoAgentAvatar"
	_icone(rond, Rect2(d * .2, d * .2, d * .6, d * .6), "people", Pieces.BLEU)
	return rond

static func _identite(toile: Control, parent: Node, ctx: Dictionary, zone: Rect2, d: Dictionary) -> void:
	var joueur: Dictionary = ctx.player
	var cote := zone.size.y - 20
	var portrait := G.portrait(0, int(cote), joueur)
	portrait.name = "ContractPlayerPortrait"
	portrait.set_meta("player_id", str(joueur.get("id", "")))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.custom_minimum_size = Vector2.ZERO
	portrait.clip_contents = true
	parent.add_child(portrait)
	D.place(portrait, Rect2(zone.position.x + 10, zone.position.y + 10, cote, cote))
	var app: Control = ctx.app
	var fiche := {"kind":"player", "id":str(joueur.get("id", ""))} if ctx.get("prolongation", false) else {"kind":"market", "id":str(joueur.get("id", ""))}
	var cadre := D.rect(parent, Rect2(zone.position.x + 10, zone.position.y + 10, cote, cote), Color.TRANSPARENT, Charte.RAYON_CARTE, Charte.FILET)
	cadre.name = "NegoPortraitCadre"
	Pieces.rendre_cliquable(cadre, Vector2(cote, cote), func(): app.navigation_controller.open_entity(fiche), "NegoPortraitLien", "Fiche · " + str(joueur.get("name", "")), "", Charte.RAYON_CARTE)
	var x := zone.position.x + cote + 30
	var nom := _gros(parent, x, zone.position.y + 52, str(joueur.get("name", "—")).to_upper(), Charte.IVOIRE, 36, zone.size.x - cote - 40)
	nom.name = "NegoNom"
	D.fit_title(nom, zone.size.x - cote - 40, 60, 2, 20)
	D.text(parent, x, zone.position.y + 84, "%s · %s ans" % [str(joueur.get("pos", "—")), G.n(joueur.get("age", "—"))], 17, Charte.IVOIRE_2, 600, zone.size.x - cote - 40, HORIZONTAL_ALIGNMENT_LEFT, true)
	var tentative := mini(3, int(d.tentatives) + 1)
	Pieces.pastille(parent, x, zone.position.y + zone.size.y - 48, "Discussion close" if d.retrait else "Proposition %d/3" % tentative, "lock" if d.retrait else "mail", "NegoTentative", "",
		Pieces.ROUGE if d.retrait else Pieces.BLEU, Charte.PANNEAU_3, func(): Offre._fenetre_discussion(toile, ctx, d))

# --- Option A : trois colonnes -------------------------------------------------------------------------------------------

static func _option_a(toile: Control, parent: Control, ctx: Dictionary, d: Dictionary) -> void:
	# Colonne gauche : joueur, masse salariale, budget de transferts (ou trésorerie en prolongation).
	var gauche := D.rect(parent, Rect2(0, 0, 400, 200), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	gauche.name = "NegoAIdentite"
	_identite(toile, gauche, ctx, Rect2(0, 0, 400, 200), d)
	_carte_masse(toile, parent, Rect2(0, 216, 400, 310), d, true)
	_carte_transferts(toile, parent, Rect2(0, 542, 400, 300), d, true)
	# Centre : promesses puis contrat, une ligne par clause.
	var centre := D.rect(parent, Rect2(416, 0, 660, 842), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	centre.name = "NegoAContrat"
	_titre(centre, 24, 40, "1 · Promesses", Pieces.BLEU, 18)
	D.text(centre, 636, 40, "%d / 4 accords" % int(d.accords), 18, Pieces.VERT if int(d.accords) == 4 else Charte.IVOIRE_2, 700, 220, HORIZONTAL_ALIGNMENT_RIGHT).name = "NegoAAccords"
	_ligne_a(centre, Rect2(12, 56, 636, 180), "Rôle promis", str(d.role), "NegoLigneRole")
	var y_role := 56.0
	var x := 84.0
	for role: String in ROLES:
		var choisi := str(d.choisi) == role
		var couleur := role_couleur(role)
		var largeur := 132.0
		var pilule := D.rect(centre, Rect2(x, y_role + 64, largeur, 92), Charte.PANNEAU_3.lerp(couleur, .28 if choisi else .06), Charte.RAYON_CARTE, couleur if choisi else Color.TRANSPARENT)
		pilule.name = "NegoRoleCarte_" + role
		_icone(pilule, Rect2(12, 12, 22, 22), ROLE_ICONE[role], couleur)
		D.text(pilule, 40, 31, ROLE_NOM[role], 19, couleur if role != "appoint" else Charte.IVOIRE, 700, largeur - 46)
		D.text(pilule, 12, 66, ROLE_MINUTES[role], 17, Charte.IVOIRE_2, 600, largeur - 20, HORIZONTAL_ALIGNMENT_LEFT, true)
		if role == str(d.attendu): _icone(pilule, Rect2(largeur - 30, 12, 20, 20), "flag", Pieces.ORANGE).name = "NegoRoleAttendu"
		var r := role
		Pieces.rendre_cliquable(pilule, Vector2(largeur, 92), func(): _choisir_role(ctx, r), "NegoRole_" + role, ROLE_NOM[role], "", Charte.RAYON_CARTE)
		x += largeur + 8
	_titre(centre, 24, 276, "2 · Contrat", Pieces.BLEU if not str(d.choisi).is_empty() else Charte.IVOIRE_3, 18)
	var bloque := str(d.choisi).is_empty()
	var lignes := [
		["Salaire " + G.salary_period(true), d.salaire, G.salary(d.propose), "Agent " + G.salary(d.cible), "NegoLigneSalaire", func(): Offre._fenetre_salaire(toile, d)],
		["Durée", d.duree, "%d an%s · fin %s" % [int(d.annees), "s" if int(d.annees) > 1 else "", str(d.fin)], "Agent %d à %d ans" % [int(d.min), int(d.max)] if not d.contre else "Agent %d an%s" % [int(d.contre_annees), "s" if int(d.contre_annees) > 1 else ""], "NegoLigneDuree", func(): Offre._fenetre_duree(toile, d)],
		["Prime de prolongation" if d.prolongation else "Prime à la signature", d.prime, G.euros(maxi(0, int(d.fee))) if int(d.fee) >= 0 else "—", "Fixe", "NegoLignePrime", func(): Offre._fenetre_budget(toile, d)],
	]
	var y := 292.0
	for l: Array in lignes:
		var etat: String = "attente" if bloque else str(l[1])
		var ligne := _ligne_a(centre, Rect2(12, y, 636, 108), str(l[0]), etat, str(l[4]))
		_gros(ligne, 72, 82, str(l[2]), couleur_etat(etat) if etat != "attente" else Charte.IVOIRE_2, 28, 330)
		D.text(ligne, 620, 30, str(l[3]), 17, Charte.IVOIRE_2, 600, 240, HORIZONTAL_ALIGNMENT_RIGHT, true)
		Pieces.rendre_cliquable(ligne, Vector2(380, 108), l[5], str(l[4]) + "Lien", str(l[0]), "", Charte.RAYON_CARTE)
		y += 120
	# Champs réglables posés sur les lignes Salaire et Durée.
	D.place(ctx.salary, Rect2(416 + 12 + 400, 292 + 44, 220, 48))
	D.place(ctx.years, Rect2(416 + 12 + 400, 412 + 44, 220, 48))
	ctx.salary.visible = true
	ctx.years.visible = true
	# Fin de contrat et écart : deux tuiles chiffre sous les lignes.
	var ecart := roundi(float(int(d.propose) - int(d.cible)) / 100.0) * 100
	Pieces.tuile(centre, Rect2(24, 662, 300, 84), ("+" if ecart > 0 else "−" if ecart < 0 else "") + G.salary_amount(absi(ecart)), "écart avec l’agent", couleur_etat(str(d.salaire)), "NegoATuileEcart", 30, "", icone_etat(str(d.salaire)), true, func(): Offre._fenetre_salaire(toile, d))
	Pieces.tuile(centre, Rect2(336, 662, 300, 84), str(d.fin), "fin du contrat", Offre.COULEUR_DUREE, "NegoATuileFin", 30, "", "calendar", true, func(): Offre._fenetre_duree(toile, d))
	if d.contre:
		var reprendre: Button = ctx.reuse
		Pieces.pastille(centre, 24, 770, "Reprendre sa contre-offre", "mail", "NegoAReprendre", "", Pieces.ORANGE, Charte.PANNEAU_3, func(): if is_instance_valid(reprendre) and not reprendre.disabled: reprendre.pressed.emit())
	# Droite : l'agent et ses bulles.
	var droite := D.rect(parent, Rect2(1092, 0, 408, 842), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	droite.name = "NegoAAgent"
	_avatar_agent(droite, 20, 20, 64)
	_titre(droite, 100, 50, "Agent", Pieces.BLEU, 22, 280)
	D.text(droite, 100, 78, "de " + str(ctx.player.get("name", "")), 18, Charte.IVOIRE_2, 600, 290, HORIZONTAL_ALIGNMENT_LEFT, true)
	Pieces.rendre_cliquable(droite.get_node("NegoAgentAvatar"), Vector2(64, 64), func(): Offre._fenetre_discussion(toile, ctx, d), "NegoAgentLien", "Agent", "", Charte.RAYON_PILULE)
	D.line(droite, Vector2(20, 104), Vector2(388, 104), Charte.FILET)
	var by := 122.0
	var i := 0
	for b: Array in bulles(d):
		by += _bulle(droite, 20, by, 368, str(b[0]), b[1], bool(b[2]), "NegoBulle_%d" % i)
		i += 1
	# Compteur des propositions en bas de la colonne : trois pastilles.
	_titre(droite, 20, 790, "Propositions", Charte.IVOIRE_2, 16, 160)
	for n in 3:
		var faite := n < int(d.tentatives)
		var couleur := Pieces.ROUGE if d.retrait else Pieces.ORANGE if faite else Charte.IVOIRE_3
		D.rect(droite, Rect2(196 + n * 64, 766, 52, 34), Charte.PANNEAU_3.lerp(couleur, .3 if faite else 0.0), Charte.RAYON_PILULE, couleur).name = "NegoAPropo_%d" % (n + 1)
		D.text(droite, 196 + n * 64 + 26, 790, str(n + 1), 18, couleur if faite else Charte.IVOIRE_2, 700, 40, HORIZONTAL_ALIGNMENT_CENTER)

## Ligne du contrat (grammaire de l'Effectif) : liseré et fond verts quand l'agent accepte.
static func _ligne_a(parent: Node, zone: Rect2, libelle: String, etat: String, id: String) -> Panel:
	var couleur := couleur_etat(etat)
	var fond := Charte.PANNEAU.lerp(couleur, .14) if etat == "ok" else Charte.PANNEAU
	var ligne := D.rect(parent, zone, fond, Charte.RAYON_PETIT)
	ligne.name = id
	D.rect(ligne, Rect2(0, 0, 6, zone.size.y), couleur if etat != "attente" else Charte.FILET, 3)
	_rond(ligne, 20, 14, etat, 36)
	_titre(ligne, 72, 38, libelle, Charte.IVOIRE if etat != "attente" else Charte.IVOIRE_3, 18, 330)
	return ligne

static func _barre(parent: Node, zone: Rect2, parts: Array, total: float, repere: float = -1.0) -> void:
	D.rect(parent, zone, Charte.PANNEAU_3, Charte.RAYON_PILULE)
	var x := zone.position.x
	for p: Array in parts:
		var w := zone.size.x * clampf(float(p[0]) / maxf(1.0, total), 0, 1)
		w = minf(w, zone.position.x + zone.size.x - x)
		if w > 1: D.rect(parent, Rect2(x, zone.position.y, w, zone.size.y), p[1], Charte.RAYON_PILULE if w > zone.size.y else 2)
		x += w
	if repere >= 0:
		var rx := zone.position.x + zone.size.x * clampf(repere / maxf(1.0, total), 0, 1)
		D.rect(parent, Rect2(rx - 2, zone.position.y - 8, 4, zone.size.y + 16), Pieces.ROUGE, 2).name = "NegoBarreRepere"

static func _carte_masse(toile: Control, parent: Node, zone: Rect2, d: Dictionary, colonne: bool) -> void:
	var carte := D.rect(parent, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	carte.name = "NegoMasse"
	_titre(carte, 20, 36, "Masse salariale " + G.salary_period(true), Pieces.BLEU, 17, zone.size.x - 40)
	var ajout := int(d.ajout)
	var plafond := float(d.saison.get("plafondSalarial", 0)) if d.saison.get("plafondSalarial") != null else 0.0
	var semaines := maxi(1, int(d.semaines)) if int(d.semaines) > 0 else 52
	var total := maxf(float(d.apres), float(d.masse)) * 1.08
	if plafond > 0: total = maxf(total, plafond / semaines * 1.04)
	var largeur := zone.size.x - 40
	if colonne:
		var tuiles := [[G.salary_amount(d.masse), "actuelle", Charte.IVOIRE, "lock"], [("+" if ajout >= 0 else "−") + G.salary_amount(absi(ajout)), "ce contrat", Pieces.ORANGE if ajout > 0 else Pieces.VERT, "people"], [G.salary_amount(d.apres), "après", Pieces.BLEU, "money"]]
		for i in 3:
			var t: Array = tuiles[i]
			Pieces.tuile(carte, Rect2(20, 54 + i * 74, largeur, 66), t[0], t[1], t[2], "NegoMasseTuile_%d" % i, 28, "", t[3], i > 0)
		_barre(carte, Rect2(20, 284, largeur, 14), [[d.masse, Charte.IVOIRE_3], [maxi(0, ajout), Pieces.ORANGE]], total, plafond / semaines if plafond > 0 else -1.0)
	else:
		D.text(carte, zone.size.x - 20, 36, "%s → %s" % [G.salary_amount(d.masse), G.salary_amount(d.apres)], 22, Pieces.BLEU, 700, 500, HORIZONTAL_ALIGNMENT_RIGHT)
		_barre(carte, Rect2(20, 62, largeur, 22), [[d.masse, Charte.IVOIRE_3], [maxi(0, ajout), Pieces.ORANGE]], total, plafond / semaines if plafond > 0 else -1.0)
		var x := 20.0
		x += Pieces.pastille(carte, x, 100, "Actuelle " + G.salary_amount(d.masse), "lock", "NegoMasseActuelle", "", Charte.IVOIRE) + 10
		x += Pieces.pastille(carte, x, 100, ("+" if ajout >= 0 else "−") + G.salary_amount(absi(ajout)) + " ce contrat", "people", "NegoMasseAjout", "", Pieces.ORANGE if ajout > 0 else Pieces.VERT) + 10
		if plafond > 0: Pieces.pastille(carte, x, 100, "Plafond " + G.salary_amount(plafond / semaines), "shield", "NegoMassePlafond", "", Pieces.ROUGE)
	Pieces.rendre_cliquable(carte, zone.size, func(): _fenetre_masse(toile, d), "NegoMasseLien", "Masse salariale", "", Charte.RAYON_CARTE)

static func _carte_transferts(toile: Control, parent: Node, zone: Rect2, d: Dictionary, colonne: bool) -> void:
	var carte := D.rect(parent, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	carte.name = "NegoTransferts"
	var budget: Dictionary = d.budget
	var fee := maxi(0, int(d.fee))
	var titre := "Trésorerie" if budget.is_empty() else "Budget transferts"
	_titre(carte, 20, 36, titre, Offre.COULEUR_PRIME, 17, zone.size.x - 40)
	var dispo := float(budget.get("disponible", 0)) if not budget.is_empty() else float(d.cash) if (d.cash is int or d.cash is float) else 0.0
	var engage := float(budget.get("depense", 0)) if not budget.is_empty() else 0.0
	var reste := dispo - fee
	var largeur := zone.size.x - 40
	var total := maxf(1.0, engage + dispo)
	if colonne:
		var tuiles := [[G.euros(dispo), "disponible", Charte.IVOIRE, "shield"], [("−" if fee > 0 else "") + G.euros(fee), "cette prime", Offre.COULEUR_PRIME, "money"], [G.euros(reste), "reste", Pieces.VERT if reste >= 0 else Pieces.ROUGE, "check" if reste >= 0 else "warning"]]
		for i in 3:
			var t: Array = tuiles[i]
			Pieces.tuile(carte, Rect2(20, 54 + i * 74, largeur, 66), t[0], t[1], t[2], "NegoTransfertsTuile_%d" % i, 28, "", t[3], i > 0)
		_barre(carte, Rect2(20, 280, largeur, 14), [[engage, Charte.IVOIRE_3], [fee, Offre.COULEUR_PRIME], [maxf(0, reste), Pieces.VERT]], total)
	else:
		D.text(carte, zone.size.x - 20, 36, "Reste " + G.euros(reste), 22, Pieces.VERT if reste >= 0 else Pieces.ROUGE, 700, 500, HORIZONTAL_ALIGNMENT_RIGHT)
		_barre(carte, Rect2(20, 62, largeur, 22), [[engage, Charte.IVOIRE_3], [fee, Offre.COULEUR_PRIME], [maxf(0, reste), Pieces.VERT]], total)
		var x := 20.0
		if engage > 0: x += Pieces.pastille(carte, x, 100, "Engagé " + G.euros(engage), "lock", "NegoTransfertsEngage", "", Charte.IVOIRE) + 10
		x += Pieces.pastille(carte, x, 100, "Prime " + G.euros(fee), "money", "NegoTransfertsPrime", "", Offre.COULEUR_PRIME) + 10
		Pieces.pastille(carte, x, 100, "Disponible " + G.euros(dispo), "shield", "NegoTransfertsDispo", "", Charte.IVOIRE)
	Pieces.rendre_cliquable(carte, zone.size, func(): Offre._fenetre_budget(toile, d), "NegoTransfertsLien", titre, "", Charte.RAYON_CARTE)

static func _fenetre_masse(toile: Control, d: Dictionary) -> void:
	var tuiles: Array = [[G.salary(d.masse), "Actuelle", Charte.IVOIRE, "lock"], [("+" if int(d.ajout) >= 0 else "−") + G.salary(absi(int(d.ajout))), "Ce contrat", Pieces.ORANGE, "people"], [G.salary(d.apres), "Après", Pieces.BLEU, "money"]]
	var marge: Variant = d.saison.get("margePlafond")
	if marge is int or marge is float:
		var semaines := int(d.semaines) if int(d.semaines) > 0 else 52
		var apres := float(marge) - float(d.ajout) * semaines
		tuiles.append([G.euros(apres), "Marge plafond / an", Pieces.VERT if apres >= 0 else Pieces.ROUGE, "shield"])
	Offre._fenetre(toile, "NegoFenetreMasse", "Masse salariale", tuiles, Pieces.BLEU)

# --- Option B : deux étapes, table face à face ------------------------------------------------------------------------------

static func _option_b(toile: Control, parent: Control, ctx: Dictionary, d: Dictionary) -> void:
	var haut := D.rect(parent, Rect2(0, 0, LARGEUR, 150), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	haut.name = "NegoBBandeau"
	_identite(toile, haut, ctx, Rect2(0, 0, 760, 150), d)
	var promesses := etape(ctx.app, str(d.id)) != "contrat" or str(d.choisi).is_empty()
	# Étapes : promesses → contrat → signature, en chevrons colorés.
	var etapes := [["1 Promesses", "promesses", "ok" if not str(d.choisi).is_empty() else "attente"], ["2 Contrat", "contrat", "ok" if int(d.accords) == 4 else "attente"], ["3 Signature", "", "attente"]]
	var x := 800.0
	for i in 3:
		var e: Array = etapes[i]
		var courant := (i == 0 and promesses) or (i == 1 and not promesses)
		var couleur := Pieces.BLEU if courant else couleur_etat(str(e[2])) if str(e[2]) == "ok" else Charte.IVOIRE_3
		var pilule := D.rect(haut, Rect2(x, 52, 210, 52), Charte.PANNEAU_3.lerp(couleur, .3 if courant else .12), Charte.RAYON_PILULE, couleur if courant else Color.TRANSPARENT)
		pilule.name = "NegoBEtape_%d" % (i + 1)
		_icone(pilule, Rect2(16, 15, 22, 22), "check" if str(e[2]) == "ok" else "arrow" if courant else "lock", couleur)
		D.text(pilule, 46, 34, str(e[0]).to_upper(), 19, couleur if courant or str(e[2]) == "ok" else Charte.IVOIRE_2, 700, 156)
		if not str(e[1]).is_empty() and not (str(e[1]) == "contrat" and str(d.choisi).is_empty()):
			var vers := str(e[1])
			Pieces.rendre_cliquable(pilule, Vector2(210, 52), func(): _aller(ctx, vers), "NegoBEtapeLien_%d" % (i + 1), str(e[0]), "", Charte.RAYON_PILULE)
		x += 228
	if promesses: _b_promesses(toile, parent, ctx, d)
	else: _b_contrat(toile, parent, ctx, d)

static func _b_agent(parent: Node, zone: Rect2, d: Dictionary, liste: Array) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "NegoBAgent"
	_avatar_agent(cadre, 18, (zone.size.y - 56) / 2, 56)
	_titre(cadre, 90, zone.size.y / 2 + 7, "Agent", Pieces.BLEU, 20, 120)
	var x := 190.0
	var i := 0
	for b: Array in liste:
		var texte := str(b[0])
		var w := minf(zone.size.x - x - 20, C.BODY.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(19))).x / C.density + 32)
		if w < 80: break
		_bulle(cadre, x, (zone.size.y - 44) / 2, w, texte, b[1], true, "NegoBulle_%d" % i)
		x += w + 12
		i += 1

static func _b_promesses(toile: Control, parent: Control, ctx: Dictionary, d: Dictionary) -> void:
	ctx.salary.visible = false
	ctx.years.visible = false
	var choisi := str(d.choisi)
	var liste: Array = [["Quel rôle pour lui ?", Pieces.BLEU, true]]
	if not choisi.is_empty(): liste = [[ROLE_NOM[choisi] + " ?", role_couleur(choisi), true], [{"ok":"Ça lui va.", "proche":"Il espérait mieux.", "loin":"Hors de question."}[str(d.role)], couleur_etat(str(d.role)), true]]
	_b_agent(parent, Rect2(0, 166, LARGEUR, 90), d, liste)
	var table := D.rect(parent, Rect2(0, 272, LARGEUR, 480), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	table.name = "NegoBRoles"
	var entete := [["Rôle promis", 70], ["Temps de jeu par match", 520], ["Réaction de l’agent", 900]]
	for e: Array in entete: _titre(table, float(e[1]), 40, str(e[0]), Charte.IVOIRE_2, 16, 360)
	D.line(table, Vector2(20, 56), Vector2(LARGEUR - 20, 56), Charte.FILET)
	var y := 68.0
	for role: String in ROLES:
		var ecart := ROLES.find(role) - ROLES.find(str(d.attendu))
		var reaction := "ok" if ecart <= 0 else "proche" if ecart == 1 else "loin"
		var mot: String = {"ok":"D’accord", "proche":"Hésite", "loin":"Refuse"}[reaction]
		if ecart < 0: mot = "Ravi"
		var selection := role == choisi
		var couleur := role_couleur(role)
		var ligne := D.rect(table, Rect2(12, y, LARGEUR - 24, 90), Charte.SELECTION if selection else Charte.PANNEAU, Charte.RAYON_PETIT, couleur if selection else Color.TRANSPARENT)
		ligne.name = "NegoBRole_" + role
		D.rect(ligne, Rect2(0, 0, 6, 90), couleur, 3)
		_icone(ligne, Rect2(24, 26, 36, 36), ROLE_ICONE[role], couleur)
		_gros(ligne, 76, 58, ROLE_NOM[role].to_upper(), couleur if role != "appoint" else Charte.IVOIRE, 32, 360)
		if role == str(d.attendu): Pieces.pastille(ligne, 300, 28, "Attendu", "flag", "NegoBRoleAttendu", "", Pieces.ORANGE)
		_gros(ligne, 508, 58, ROLE_MINUTES[role], Charte.IVOIRE, 28, 300)
		Pieces.pastille(ligne, 888, 28, mot, icone_etat(reaction), "NegoBReaction_" + role, "", couleur_etat(reaction))
		if selection: _icone(ligne, Rect2(LARGEUR - 24 - 64, 24, 40, 40), "check", Pieces.VERT)
		var r := role
		Pieces.rendre_cliquable(ligne, Vector2(LARGEUR - 24, 90), func(): _choisir_role(ctx, r), "NegoRole_" + role, ROLE_NOM[role], "", Charte.RAYON_PETIT)
		y += 100
	var suite := Kit.bouton_ivoire(parent, Rect2(LARGEUR - 380, 776, 380, 56), "Passer au contrat →", func(): _aller(ctx, "contrat"), "NegoEtapeContrat")
	suite.disabled = choisi.is_empty()

static func _b_contrat(toile: Control, parent: Control, ctx: Dictionary, d: Dictionary) -> void:
	var liste := bulles(d)
	_b_agent(parent, Rect2(0, 166, LARGEUR, 90), d, liste.slice(maxi(0, liste.size() - 3)))
	var table := D.rect(parent, Rect2(0, 272, LARGEUR, 410), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	table.name = "NegoBTable"
	_titre(table, 70, 40, "Ta proposition", Pieces.BLEU, 18, 400)
	D.text(table, LARGEUR / 2, 40, "%d / 4 ACCORDS" % int(d.accords), 18, Pieces.VERT if int(d.accords) == 4 else Charte.IVOIRE_2, 700, 300, HORIZONTAL_ALIGNMENT_CENTER).name = "NegoBAccords"
	_titre(table, LARGEUR - 450, 40, "L’agent", Pieces.BLEU, 18, 400)
	D.line(table, Vector2(20, 56), Vector2(LARGEUR - 20, 56), Charte.FILET)
	var choisi := str(d.choisi)
	var lignes := [
		["Rôle", d.role, ROLE_NOM.get(choisi, "—"), ROLE_NOM[str(d.attendu)], "NegoLigneRole", func(): _aller(ctx, "promesses")],
		["Salaire", d.salaire, "", G.salary(d.cible), "NegoLigneSalaire", func(): Offre._fenetre_salaire(toile, d)],
		["Durée", d.duree, "", "%d à %d ans" % [int(d.min), int(d.max)] if not d.contre else "%d an%s" % [int(d.contre_annees), "s" if int(d.contre_annees) > 1 else ""], "NegoLigneDuree", func(): Offre._fenetre_duree(toile, d)],
		["Prime", d.prime, G.euros(maxi(0, int(d.fee))), G.euros(maxi(0, int(d.fee))), "NegoLignePrime", func(): Offre._fenetre_budget(toile, d)],
	]
	var y := 66.0
	for l: Array in lignes:
		var etat := str(l[1])
		var couleur := couleur_etat(etat)
		var ligne := D.rect(table, Rect2(12, y, LARGEUR - 24, 78), Charte.PANNEAU.lerp(couleur, .16) if etat == "ok" else Charte.PANNEAU, Charte.RAYON_PETIT)
		ligne.name = str(l[4])
		D.rect(ligne, Rect2(0, 0, 6, 78), couleur, 3)
		_titre(ligne, 24, 46, str(l[0]), Charte.IVOIRE_2, 18, 130)
		if not str(l[2]).is_empty(): _gros(ligne, 160, 52, str(l[2]), Pieces.BLEU, 28, 380)
		# Centre : rond d'état + mot.
		_rond(ligne, LARGEUR / 2 - 90, 20, etat, 38)
		D.text(ligne, LARGEUR / 2 - 40, 47, mot_etat(etat).to_upper(), 20, couleur, 800, 160)
		_gros(ligne, LARGEUR - 48, 52, str(l[3]), Charte.IVOIRE, 28, 420, HORIZONTAL_ALIGNMENT_RIGHT)
		Pieces.rendre_cliquable(ligne, Vector2(10, 78), l[5], str(l[4]) + "Lien", str(l[0]), "", Charte.RAYON_PETIT)
		var lien := ligne.get_node(str(l[4]) + "Lien") as Control
		D.place(lien, Rect2(LARGEUR / 2 - 140, 0, LARGEUR / 2 - 24 + 140 - 12, 78))
		y += 86
	# Champs réglables dans la colonne « ta proposition ».
	ctx.salary.visible = true
	ctx.years.visible = true
	D.place(ctx.salary, Rect2(12 + 160, 272 + 66 + 86 + 15, 260, 48))
	D.place(ctx.years, Rect2(12 + 160, 272 + 66 + 172 + 15, 260, 48))
	D.text(table, 12 + 440, 66 + 172 + 48, "fin " + str(d.fin), 18, Offre.COULEUR_DUREE, 700, 140).name = "NegoBFin"
	# Bas : jauges des budgets.
	_carte_masse(toile, parent, Rect2(0, 698, 740, 150), d, false)
	_carte_transferts(toile, parent, Rect2(760, 698, 740, 150), d, false)

# --- Petite fenêtre « Disponibilité » (fiche joueur, Marché des transferts) ------------------------------------------------

## Phrase de l'agent selon la situation du joueur (statut, marché, approche d'un autre club).
static func phrase_disponibilite(joueur: Dictionary) -> Array:
	var sale: Dictionary = joueur.get("sale", {}) if joueur.get("sale") is Dictionary else {}
	var pre: Dictionary = joueur.get("preContract", {}) if joueur.get("preContract") is Dictionary else {}
	if not pre.is_empty(): return ["Un autre club l’a approché.", Pieces.ORANGE]
	if bool(sale.get("listed", false)): return ["Il sait qu’il est sur le marché.", Pieces.ORANGE]
	match str(joueur.get("status", "")):
		"Blessé": return ["Il pense d’abord à revenir.", Charte.IVOIRE]
		"Hors groupe": return ["Il veut jouer. Il écoute les autres clubs.", Pieces.ROUGE]
		"Remplaçant": return ["Il attend plus de temps de jeu.", Pieces.ORANGE]
	return ["Il est heureux ici.", Pieces.VERT]

## Fenêtre « Disponibilité » : phrase de l'agent, deux choix (pas proposé / proposé aux clubs), valeur estimée, Confirmer.
static func ouvrir_disponibilite(page: Control, app: Control, joueur: Dictionary) -> void:
	var v := variante()
	var sale: Dictionary = joueur.get("sale", {}) if joueur.get("sale") is Dictionary else {}
	var liste := bool(sale.get("listed", false))
	var bloque := str(sale.get("blocked", ""))
	var etat := {"choix": liste}
	var panneau := Fenetre.ouvrir(page, "NegoDispo", "DISPONIBILITÉ", "money", 900, 560)
	var contenu := Control.new()
	contenu.name = "NegoDispoContenu"
	panneau.add_child(contenu)
	D.place(contenu, Rect2(0, 0, 900, 560))
	var dessiner := func(soi: Callable) -> void:
		Offre._vider(contenu)
		var phrase := phrase_disponibilite(joueur)
		# Agent : avatar + bulle (A) ou bandeau pleine largeur teinté (B).
		_avatar_agent(contenu, 28, 84, 64)
		_titre(contenu, 108, 108, "Agent de " + str(joueur.get("name", "")), Pieces.BLEU, 18, 600)
		if v == "B":
			var bande := D.rect(contenu, Rect2(108, 122, 760, 44), Charte.PANNEAU_3.lerp(phrase[1], .22), 14, Color(phrase[1], .7))
			bande.name = "NegoDispoPhrase"
			D.text(bande, 16, 29, str(phrase[0]), 20, phrase[1] if phrase[1] != Charte.IVOIRE else Charte.IVOIRE, 600, 730, HORIZONTAL_ALIGNMENT_LEFT, true)
		else: _bulle(contenu, 108, 122, 760, str(phrase[0]), phrase[1], true, "NegoDispoPhrase")
		var choix := [[false, "Pas proposé", "lock", Charte.IVOIRE], [true, "Proposé aux clubs", "money", Pieces.ORANGE]]
		var y := 196.0
		for c: Array in choix:
			var actif := bool(etat.choix) == bool(c[0])
			var interdit := bool(c[0]) and not liste and not bloque.is_empty()
			var couleur: Color = c[3] if not interdit else Charte.IVOIRE_3
			var ligne := D.rect(contenu, Rect2(28, y, 844, 74), Charte.SELECTION if actif else Charte.PANNEAU_2, Charte.RAYON_PETIT, couleur if actif else Color.TRANSPARENT)
			ligne.name = "NegoDispoChoix_%s" % ("liste" if c[0] else "garde")
			D.rect(ligne, Rect2(0, 0, 6, 74), couleur, 3)
			_icone(ligne, Rect2(24, 20, 34, 34), str(c[2]), couleur)
			_gros(ligne, 76, 48, str(c[1]).to_upper(), couleur if c[3] != Charte.IVOIRE else Charte.IVOIRE, 28, 420)
			if bool(c[0]): Pieces.pastille(ligne, 520, 20, "Valeur " + G.euros(sale.get("value", 0)), "money", "NegoDispoValeur", "", Offre.COULEUR_PRIME)
			if interdit: Pieces.pastille(ligne, 724, 20, "Bloqué", "warning", "NegoDispoBloque", bloque, Pieces.ROUGE)
			if actif: _icone(ligne, Rect2(844 - 56, 20, 34, 34), "check", Pieces.VERT)
			if not interdit:
				var valeur := bool(c[0])
				Pieces.rendre_cliquable(ligne, Vector2(844, 74), func():
					etat.choix = valeur
					soi.call(soi), "NegoDispoChoixLien_%s" % ("liste" if c[0] else "garde"), str(c[1]), "", Charte.RAYON_PETIT)
			y += 86
		var tuiles := [[G.euros(sale.get("value", 0)), "valeur estimée", Offre.COULEUR_PRIME, "money"], [G.salary(joueur.get("salary", 0)), "salaire", Pieces.BLEU, "people"], [G.contract_year(joueur.get("contractEnd")) if joueur.get("contractEnd") != null else "—", "fin de contrat", Offre.COULEUR_DUREE, "calendar"]]
		for i in 3:
			var t: Array = tuiles[i]
			Pieces.tuile(contenu, Rect2(28 + i * 290, 380, 274, 76), t[0], t[1], t[2], "NegoDispoTuile_%d" % i, 28, "", t[3], true)
		var confirmer := Kit.bouton_ivoire(contenu, Rect2(28, 480, 400, 54), "Confirmer", func():
			if bool(etat.choix) != liste: load("res://ui/player_sales_view.gd").toggle(app, joueur)
			Fenetre.fermer(page, "NegoDispo"), "NegoDispoConfirmer")
		confirmer.disabled = bool(etat.choix) == liste
		Kit.lien(contenu, Rect2(460, 488, 0, 38), "Annuler", func(): Fenetre.fermer(page, "NegoDispo"), "NegoDispoAnnuler", 20)
		Offre._marquer(contenu)
	dessiner.call(dessiner)
