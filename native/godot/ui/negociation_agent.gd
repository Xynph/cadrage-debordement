extends RefCounted
## Négociation avec l'agent (idée FM 18, choix A de Léo du 23/11/2026) : écran de l'offre au recrutement ET à la
## prolongation, en trois colonnes :
##  - gauche : le joueur, l'effet sur la masse salariale (plafond de la ligue) et sur le budget de transferts (trésorerie
##    en prolongation) ;
##  - centre : 1 · Promesses (rôle promis Titulaire / Rotation / Espoir / Appoint, OBLIGATOIRE avant le contrat), puis
##    2 · Contrat, une ligne par clause ; chaque ligne acceptée par l'agent passe au vert ;
##  - droite : l'agent du joueur (anonyme : « Agent de <joueur> »), ses réponses en bulles chiffrées.
## Clic = appliqué : un rôle cliqué est promis, les champs règlent la proposition ; seul le bouton de signature (fenêtre
## de l'offre ou pied de la page Recrutement) envoie, en un clic (exception tolérée : signature d'un contrat).
## Données moteur : quote.roles {attendu, liste[{role, salary, refus}]} (native/engine/role-contrat.cjs) : demande et refus
## de chaque rôle ; ctx.role est envoyé avec l'offre (contract_negotiation.gd).
## Offre guidée (idée 17, native/engine/clauses-contrat.cjs, ui/offre_guidee.gd) : au recrutement, la prime à la signature
## (crans) et la clause libératoire (sans, haute, moyenne, basse) sont deux lignes du contrat, réglées d'un clic ; le
## conseil du recruteur est entouré d'orange.
## Petite fenêtre « Disponibilité » (fiche joueur) : remplace le bouton « Proposer aux autres clubs ».
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const G = preload("res://ui/game_skin.gd")
const Salary = preload("res://ui/salary_display.gd")
const Offre = preload("res://ui/offre_visuelle.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Role = preload("res://ui/role_contrat.gd")
const Guidee = preload("res://ui/offre_guidee.gd")
const LARGEUR := 1500.0
const HAUTEUR := 860.0
## Repères du temps de jeu promis (idée 16, native/engine/role-contrat.cjs SEUILS) : minutes par match.
const ROLE_MINUTES := {"titulaire":"50 min / match", "rotation":"20 min / match", "espoir":"1 match / 4", "appoint":"—"}
const ROLE_ICONE := {"titulaire":"ball", "rotation":"renew", "espoir":"school", "appoint":"people"}

# --- Données -----------------------------------------------------------------------------------------------------------

## Rôles de l'offre envoyés par le moteur : {role: {salary, refus}} (vide si le moteur ne les donne pas).
static func roles_offre(quote: Dictionary) -> Dictionary:
	var out := {}
	var roles: Variant = quote.get("roles")
	if roles is Dictionary and roles.get("liste") is Array:
		for r: Variant in roles.liste:
			if r is Dictionary and str(r.get("role", "")) in Role.ROLES: out[str(r.role)] = r
	return out

## Rôle que la hiérarchie du club lui donne (sans supplément de salaire).
static func role_attendu(quote: Dictionary) -> String:
	var roles: Variant = quote.get("roles")
	var attendu := str(roles.get("attendu", "")) if roles is Dictionary else ""
	return attendu if attendu in Role.ROLES else ""

## Le rôle promis est obligatoire dès que le moteur donne les rôles de l'offre.
static func role_requis(ctx: Dictionary) -> bool:
	return not roles_offre(ctx.quote).is_empty()

static func role_manquant(ctx: Dictionary) -> bool:
	return role_requis(ctx) and str(ctx.get("role", "")).is_empty()

static func _roles_memoire(app: Control) -> Dictionary:
	var valeur: Variant = app.management_ui.get("negociation_roles")
	if not valeur is Dictionary:
		valeur = {}
		app.management_ui["negociation_roles"] = valeur
	return valeur

## Rôle repris d'une discussion en cours (contre-offre reçue : l'offre se rouvre avec le rôle déjà promis).
static func _role_repris(ctx: Dictionary) -> String:
	if str(ctx.negotiation.get("status", "")) != "counter": return ""
	var r := str(_roles_memoire(ctx.app).get(str(ctx.player.get("id", "")), ""))
	var roles := roles_offre(ctx.quote)
	return r if roles.has(r) and str(roles[r].get("refus", "")).is_empty() else ""

## Offre guidée au recrutement : prime en crans et clause libératoire négociables (devis `offre` du moteur).
static func offre_guidee(ctx: Dictionary) -> bool:
	return not ctx.get("prolongation", false) and not Guidee.offre(ctx).is_empty()

## État d'une ligne : "ok" (accord, vert), "proche" (orange), "loin" (rouge), "attente" (gris, rôle pas encore promis).
static func donnees(ctx: Dictionary) -> Dictionary:
	var val := Offre.valeurs(ctx)
	var app: Control = ctx.app
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
	var choisi := str(ctx.get("role", ""))
	var attendu := role_attendu(ctx.quote)
	var etat_role := "ok" if not choisi.is_empty() or not role_requis(ctx) else "attente"
	var paie := P.payroll(app.model)
	var masse := float(paie.players_weekly)
	var ajout := propose - (int(val.actuel) if val.prolongation else 0)
	var finance: Dictionary = app.model.get("finance", {})
	var saison: Variant = finance.get("budget")
	var d := val.duplicate()
	d.merge({"id":str(ctx.player.get("id", "")), "contre":contre, "retrait":retrait, "cible":cible, "tentatives":int(negociation.get("attempts", 0)),
		"contre_annees":int(negociation.get("years", 0)), "salaire":etat_salaire, "duree":etat_duree, "prime":etat_prime,
		"attendu":attendu, "choisi":choisi, "role":etat_role, "requis":role_requis(ctx), "masse":masse, "ajout":ajout, "apres":masse + ajout,
		"semaines":int(paie.weeks), "saison":saison if saison is Dictionary else {}, "guidee":offre_guidee(ctx),
		"base":int(ctx.quote.get("salary", val.demande))})
	var etats: Array = [etat_role, etat_salaire, etat_duree, etat_prime]
	# Clause libératoire : l'agent l'accepte toujours (plus elle est basse, plus il baisse sa demande).
	if d.guidee: etats.append("ok")
	d["clauses"] = etats.size()
	d["accords"] = 0 if etat_role == "attente" else etats.count("ok")
	return d

static func couleur_etat(etat: String) -> Color:
	return {"ok":Pieces.VERT, "proche":Pieces.ORANGE, "loin":Pieces.ROUGE}.get(etat, Charte.IVOIRE_3)

static func icone_etat(etat: String) -> String:
	return {"ok":"check", "proche":"renew", "loin":"warning"}.get(etat, "lock")

## Écart de prix d'un rôle par rapport à sa place dans la hiérarchie (« +5 % », « −4 % », "" sans écart).
static func ecart_role(d: Dictionary, quote: Dictionary, role: String) -> String:
	var info: Dictionary = roles_offre(quote).get(role, {})
	var base := float(d.base)
	if base <= 0 or not (info.get("salary") is int or info.get("salary") is float): return ""
	var pct := roundi((float(info.salary) - base) / base * 100.0)
	return "" if pct == 0 else ("+%d %%" % pct if pct > 0 else "−%d %%" % absi(pct))

## Bulles de l'agent (réponses courtes, chiffrées) : [texte, couleur, agent?].
static func bulles(d: Dictionary, quote: Dictionary) -> Array:
	var liste: Array = []
	if d.retrait:
		liste.append(["On arrête là pour aujourd’hui.", Pieces.ROUGE, true])
		return liste
	var choisi := str(d.choisi)
	if bool(d.requis) and choisi.is_empty():
		liste.append(["Quel rôle pour lui ?", Pieces.BLEU, true])
		if not str(d.attendu).is_empty(): liste.append(["%s, il demande %s." % [Role.libelle(str(d.attendu)), G.salary(d.base)], Charte.IVOIRE, true])
		return liste
	if not choisi.is_empty():
		liste.append([Role.libelle(choisi), Role.couleur(choisi), false])
		var rang := Role.rang(choisi) - Role.rang(str(d.attendu))
		var ecart := ecart_role(d, quote, choisi)
		if str(d.attendu).is_empty() or rang == 0: liste.append(["Ça lui va.", Pieces.VERT, true])
		elif rang < 0: liste.append(["Il signe des deux mains." + (" " + ecart if not ecart.is_empty() else ""), Pieces.VERT, true])
		else: liste.append(["Il espérait mieux." + (" " + ecart if not ecart.is_empty() else ""), Pieces.ORANGE, true])
	liste.append(["Il demande %s." % G.salary(d.demande), Charte.IVOIRE, true])
	if int(d.min) != int(d.max): liste.append(["%d à %d saisons." % [int(d.min), int(d.max)], Charte.IVOIRE, true])
	else: liste.append(["%d saison." % int(d.min), Charte.IVOIRE, true])
	if d.contre: liste.append(["Pas sous %s." % G.salary(d.cible), Pieces.ORANGE, true])
	liste.append([G.salary(d.propose) + " · %d an%s" % [int(d.annees), "s" if int(d.annees) > 1 else ""], Pieces.BLEU, false])
	if str(d.salaire) == "ok" and str(d.prime) == "ok": liste.append(["Marché conclu si tu signes.", Pieces.VERT, true])
	elif str(d.salaire) != "ok": liste.append(["Trop bas.", couleur_etat(str(d.salaire)), true])
	else: liste.append(["La prime ne passe pas.", Pieces.ROUGE, true])
	return liste

# --- Construction ------------------------------------------------------------------------------------------------------

## Toile de l'offre (recrutement et prolongation) : remplace l'ancienne présentation, mêmes champs envoyés.
static func construire(body: Control, ctx: Dictionary) -> Control:
	var toile := Control.new()
	toile.name = "OffreVisuelle"
	toile.custom_minimum_size = Vector2(LARGEUR, HAUTEUR) * C.density
	toile.mouse_filter = Control.MOUSE_FILTER_PASS
	# Signature en un clic (règle du 23/11) : la page Recrutement n'ajoute pas de confirmation en place.
	toile.set_meta("signature_directe", true)
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
	if not ctx.has("role"):
		var repris := _role_repris(ctx)
		if not repris.is_empty(): ctx["role"] = repris
	var redessiner := func(): _dessiner(toile, dessin, ctx)
	ctx["redessiner"] = redessiner
	ctx.salary.value_changed.connect(func(_x: float): redessiner.call())
	ctx.years.value_changed.connect(func(_x: float): redessiner.call())
	redessiner.call()
	return toile

static func _dessiner(toile: Control, dessin: Control, ctx: Dictionary) -> void:
	if not is_instance_valid(dessin): return
	Offre._vider(dessin)
	var d := donnees(ctx)
	_colonnes(toile, dessin, ctx, d)
	Offre._marquer(toile)
	var maj: Variant = ctx.get("maj_signature")
	if maj is Callable and (maj as Callable).is_valid(): (maj as Callable).call()

## Clic sur un rôle : promis tout de suite ; la proposition suit la demande du rôle si elle y était.
static func choisir_role(ctx: Dictionary, role: String) -> void:
	var roles := roles_offre(ctx.quote)
	if not roles.has(role) or not str(roles[role].get("refus", "")).is_empty(): return
	var avant := Offre.demande_du_role(ctx.quote, str(ctx.get("role", "")))
	if avant < 0: avant = int(ctx.quote.get("salary", -1))
	ctx["role"] = role
	_roles_memoire(ctx.app)[str(ctx.player.get("id", ""))] = role
	var apres := Offre.demande_du_role(ctx.quote, role)
	if apres >= 0 and Salary.input_weekly(ctx.salary) == avant and apres != avant and ctx.salary.editable:
		Salary.set_input_weekly(ctx.salary, float(apres))
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

## Bulle : à gauche pour l'agent (fond panneau), à droite pour toi. Renvoie la hauteur prise.
static func _bulle(parent: Node, x: float, y: float, largeur_max: float, texte: String, couleur: Color, agent: bool, id: String) -> float:
	var px := maxi(12, C.px(19))
	var w := minf(largeur_max, C.BODY.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x / C.density + 32)
	var bx := x if agent else x + largeur_max - w
	var fond := Charte.PANNEAU_3.lerp(couleur, .22) if couleur != Charte.IVOIRE else Charte.PANNEAU_3
	var bulle := D.rect(parent, Rect2(bx, y, w, 44), fond, 14, Color(couleur, .7) if couleur != Charte.IVOIRE else Color.TRANSPARENT)
	bulle.name = id
	D.text(bulle, 16, 29, texte, 19, couleur, 600, w - 24, HORIZONTAL_ALIGNMENT_LEFT, true).name = id + "Texte"
	return 52.0

static func _avatar_agent(parent: Node, x: float, y: float, d: float) -> Panel:
	var rond := D.rect(parent, Rect2(x, y, d, d), Color(Pieces.BLEU, .18), Charte.RAYON_PILULE, Pieces.BLEU)
	rond.name = "NegoAgentAvatar"
	_icone(rond, Rect2(d * .2, d * .2, d * .6, d * .6), "people", Pieces.BLEU)
	return rond

static func _identite(toile: Control, parent: Node, ctx: Dictionary, zone: Rect2, d: Dictionary) -> void:
	var joueur: Dictionary = ctx.player
	var cote := 116.0
	var portrait := G.portrait(0, int(cote), joueur)
	portrait.name = "ContractPlayerPortrait"
	portrait.set_meta("player_id", str(joueur.get("id", "")))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.custom_minimum_size = Vector2.ZERO
	portrait.clip_contents = true
	parent.add_child(portrait)
	D.place(portrait, Rect2(zone.position.x + 16, zone.position.y + 16, cote, cote))
	var app: Control = ctx.app
	var fiche := {"kind":"player", "id":str(joueur.get("id", ""))} if ctx.get("prolongation", false) else {"kind":"market", "id":str(joueur.get("id", ""))}
	var cadre := D.rect(parent, Rect2(zone.position.x + 16, zone.position.y + 16, cote, cote), Color.TRANSPARENT, Charte.RAYON_CARTE, Charte.FILET)
	cadre.name = "OffrePortraitCadre"
	Pieces.rendre_cliquable(cadre, Vector2(cote, cote), func(): app.navigation_controller.open_entity(fiche), "OffrePortraitLien", "Fiche · " + str(joueur.get("name", "")), "", Charte.RAYON_CARTE)
	var x := zone.position.x + cote + 32
	var largeur := zone.size.x - cote - 44
	var nom := _gros(parent, x, zone.position.y + 50, str(joueur.get("name", "—")).to_upper(), Charte.IVOIRE, 32, largeur)
	nom.name = "OffreNom"
	D.fit_title(nom, largeur, 60, 2, 18)
	D.text(parent, x, zone.position.y + 82, "%s · %s ans" % [str(joueur.get("pos", "—")), G.n(joueur.get("age", "—"))], 17, Charte.IVOIRE_2, 600, largeur, HORIZONTAL_ALIGNMENT_LEFT, true).name = "OffreDetail"
	var tentative := mini(3, int(d.tentatives) + 1)
	Pieces.pastille(parent, x, zone.position.y + 100, "Discussion close" if d.retrait else "Proposition %d/3" % tentative, "lock" if d.retrait else "renew", "OffreEtape", "",
		Pieces.ROUGE if d.retrait else Pieces.BLEU, Charte.PANNEAU_3, func(): Offre._fenetre_discussion(toile, ctx, d))
	var role_actuel := Role.role(joueur) if ctx.get("prolongation", false) else ""
	if not role_actuel.is_empty():
		Pieces.pastille(parent, zone.position.x + 16, zone.position.y + 148, "Rôle actuel · " + Role.libelle(role_actuel), "flag", "NegoRoleActuel", "", Role.couleur(role_actuel))

# --- Trois colonnes ------------------------------------------------------------------------------------------------------

static func _colonnes(toile: Control, parent: Control, ctx: Dictionary, d: Dictionary) -> void:
	# Gauche : joueur, masse salariale, budget de transferts (ou trésorerie en prolongation).
	var gauche := D.rect(parent, Rect2(0, 0, 400, 200), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	gauche.name = "NegoIdentite"
	_identite(toile, gauche, ctx, Rect2(0, 0, 400, 200), d)
	_carte_masse(toile, parent, Rect2(0, 216, 400, 310), d)
	_carte_transferts(toile, parent, Rect2(0, 542, 400, 300), d)
	_centre(toile, parent, ctx, d)
	_agent(toile, parent, ctx, d)

static func _centre(toile: Control, parent: Control, ctx: Dictionary, d: Dictionary) -> void:
	var centre := D.rect(parent, Rect2(416, 0, 660, 842), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	centre.name = "NegoContrat"
	var accords := int(d.accords)
	var total := int(d.clauses)
	D.text(centre, 636, 40, "%d / %d accords" % [accords, total], 18, Pieces.VERT if accords == total else Charte.IVOIRE_2, 700, 220, HORIZONTAL_ALIGNMENT_RIGHT).name = "NegoAccords"
	var manque := bool(d.requis) and str(d.choisi).is_empty()
	_titre(centre, 24, 40, "1 · Rôle promis", Pieces.ORANGE if manque else Pieces.BLEU, 18)
	var roles := roles_offre(ctx.quote)
	if roles.is_empty():
		D.text(centre, 24, 110, "—", 28, Charte.IVOIRE_3, 700, 200)
	var x := 12.0
	var largeur := 153.0
	for role: String in Role.ROLES:
		if roles.is_empty(): break
		var info: Dictionary = roles.get(role, {})
		var refus := str(info.get("refus", ""))
		var choisi := str(d.choisi) == role
		var couleur: Color = Role.couleur(role) if refus.is_empty() else Charte.IVOIRE_3
		var carte := D.rect(centre, Rect2(x, 58, largeur, 160), Charte.PANNEAU_3.lerp(couleur, .30 if choisi else .06), Charte.RAYON_CARTE, couleur if choisi else (Color(Pieces.ORANGE, .55) if manque and refus.is_empty() else Color.TRANSPARENT))
		carte.name = "NegoRoleCarte_" + role
		D.rect(carte, Rect2(0, 0, largeur, 6), couleur, 3)
		_icone(carte, Rect2(14, 20, 24, 24), ROLE_ICONE[role], couleur)
		_titre(carte, 46, 40, Role.libelle(role), couleur if role != "appoint" or not refus.is_empty() else Charte.IVOIRE, 19, largeur - 54)
		if refus.is_empty():
			_gros(carte, 14, 86, G.salary_amount(info.get("salary", 0)), Charte.IVOIRE if not choisi else couleur, 26, largeur - 24).name = "NegoRoleDemande_" + role
			var ecart := ecart_role(d, ctx.quote, role)
			D.text(carte, 14, 114, ecart if not ecart.is_empty() else G.salary_period(true), 16, Pieces.ORANGE if ecart.begins_with("+") else Pieces.VERT if ecart.begins_with("−") else Charte.IVOIRE_2, 700, largeur - 24)
		else:
			D.text(carte, 14, 90, "✕", 30, Pieces.ROUGE, 800, 40).name = "NegoRoleRefus_" + role
			D.line(carte, Vector2(14, 34), Vector2(largeur - 14, 34), Color(Charte.IVOIRE_3, .8), 2)
			carte.tooltip_text = refus
			carte.mouse_filter = Control.MOUSE_FILTER_STOP
		D.text(carte, 14, 146, ROLE_MINUTES[role], 16, Charte.IVOIRE_2, 600, largeur - 24, HORIZONTAL_ALIGNMENT_LEFT, true)
		if role == str(d.attendu): _icone(carte, Rect2(largeur - 34, 18, 22, 22), "flag", Pieces.ORANGE).name = "NegoRoleAttendu"
		if choisi: _icone(carte, Rect2(largeur - 38, 120, 26, 26), "check", Pieces.VERT).name = "NegoRoleChoisi"
		if refus.is_empty() and not bool(d.retrait):
			var r := role
			Pieces.rendre_cliquable(carte, Vector2(largeur, 160), func(): choisir_role(ctx, r), "NegoRole_" + role, Role.libelle(role), "", Charte.RAYON_CARTE)
		x += largeur + 8
	_titre(centre, 24, 256, "2 · Contrat", Charte.IVOIRE_3 if manque else Pieces.BLEU, 18)
	var guidee := bool(d.guidee)
	var cs := Guidee.conseil(ctx, d) if guidee and not manque else {}
	var lignes := [
		["Salaire " + G.salary_period(true), d.salaire, G.salary(d.propose), "Agent " + G.salary(d.cible), "NegoLigneSalaire", func(): Offre._fenetre_salaire(toile, d)],
		["Durée", d.duree, "%d an%s · fin %s" % [int(d.annees), "s" if int(d.annees) > 1 else "", str(d.fin)], ("Agent %d à %d ans" % [int(d.min), int(d.max)]) if not d.contre else ("Agent %d an%s" % [int(d.contre_annees), "s" if int(d.contre_annees) > 1 else ""]), "NegoLigneDuree", func(): Offre._fenetre_duree(toile, d)],
		["Prime de prolongation" if d.prolongation else "Prime à la signature", d.prime, G.euros(maxi(0, int(d.fee))) if int(d.fee) >= 0 else "—", "" if guidee else "Fixe", "NegoLignePrime", func(): Offre._fenetre_budget(toile, d)],
	]
	if guidee:
		var niveau := str(Guidee.extras(ctx).clause)
		lignes.append(["Clause libératoire", "ok", "Sans" if niveau == "sans" else G.euros(int(d.get("clause_montant", 0))), "", "NegoLigneClause", Callable()])
	var pas := 104.0 if lignes.size() <= 3 else 96.0
	var hauteur := pas - 10
	var y := 270.0
	var y_champs := {}
	for l: Array in lignes:
		var etat: String = "attente" if manque else str(l[1])
		var ligne := _ligne(centre, Rect2(12, y, 636, hauteur), str(l[0]), etat, str(l[4]))
		if manque:
			D.text(ligne, 72, hauteur - 20, "—", 24, Charte.IVOIRE_3, 700, 120)
		else:
			var valeur := _gros(ligne, 72, hauteur - 16, str(l[2]), couleur_etat(etat), 26, 260)
			valeur.name = str(l[4]) + "Valeur"
			if str(l[4]) == "NegoLigneClause": valeur.add_theme_color_override("font_color", Guidee.COULEURS_CLAUSE.get(str(Guidee.extras(ctx).clause), Charte.IVOIRE))
			if not str(l[3]).is_empty(): D.text(ligne, 620, 30, str(l[3]), 17, Charte.IVOIRE_2, 600, 240, HORIZONTAL_ALIGNMENT_RIGHT, true)
			if (l[5] as Callable).is_valid(): Pieces.rendre_cliquable(ligne, Vector2(330, hauteur), l[5], str(l[4]) + "Lien", str(l[0]), "", Charte.RAYON_CARTE)
			if guidee and str(l[4]) == "NegoLignePrime": _crans_prime(ctx, ligne, d, cs, hauteur)
			if guidee and str(l[4]) == "NegoLigneClause": _niveaux_clause(ctx, ligne, cs, hauteur)
		y_champs[str(l[4])] = y
		y += pas
	# Champs réglables posés sur les lignes Salaire et Durée (cachés tant qu'aucun rôle n'est promis).
	D.place(ctx.salary, Rect2(416 + 12 + 400, float(y_champs.NegoLigneSalaire) + hauteur - 54, 220, 46))
	D.place(ctx.years, Rect2(416 + 12 + 400, float(y_champs.NegoLigneDuree) + hauteur - 54, 220, 46))
	ctx.salary.visible = not manque
	ctx.years.visible = not manque
	# Écart et fin de contrat : deux tuiles chiffre sous les lignes, s'il reste la place.
	if not manque and y + 84 <= 760:
		var ecart := roundi(float(int(d.propose) - int(d.cible)) / 100.0) * 100
		Pieces.tuile(centre, Rect2(24, y + 10, 300, 84), ("+" if ecart > 0 else "−" if ecart < 0 else "") + G.salary_amount(absi(ecart)), "écart avec l’agent", couleur_etat(str(d.salaire)), "NegoTuileEcart", 30, "", icone_etat(str(d.salaire)), true, func(): Offre._fenetre_salaire(toile, d))
		Pieces.tuile(centre, Rect2(336, y + 10, 300, 84), str(d.fin), "fin du contrat", Offre.COULEUR_DUREE, "NegoTuileFin", 30, "", "calendar", true, func(): Offre._fenetre_duree(toile, d))
	if d.contre:
		var reprendre: Button = ctx.reuse
		Pieces.pastille(centre, 24, 790, "Contre-offre %s · %d an(s)" % [G.salary(ctx.negotiation.get("salary")), int(ctx.negotiation.get("years", 1))], "mail", "OffreContreOffre", "", Pieces.ORANGE, Charte.PANNEAU_3,
			func(): if is_instance_valid(reprendre) and not reprendre.disabled and not manque: reprendre.pressed.emit())

## Crans de la prime à la signature dans sa ligne (offre guidée) : un clic applique ; conseil du recruteur en orange.
static func _crans_prime(ctx: Dictionary, ligne: Control, d: Dictionary, cs: Dictionary, hauteur: float) -> void:
	var liste := Guidee.crans(ctx, int(d.annees))
	var choisi := clampi(int(Guidee.extras(ctx).cran), 0, liste.size() - 1)
	var conseille := clampi(int(cs.get("cran", -1)), -1, liste.size() - 1)
	var pilules: Array = []
	for i in liste.size():
		var extra := int(liste[i])
		var cran := i
		pilules.append(["Base" if extra == 0 else "+" + Guidee.court(extra), Offre.COULEUR_PRIME, i == choisi, i == conseille, "NegoPrimeCran_%d" % i, func(): Guidee.choisir_cran(ctx, cran)])
	_pilules(ligne, hauteur, pilules)

## Niveaux de la clause libératoire dans sa ligne (offre guidée) : un clic applique ; conseil du recruteur en orange.
static func _niveaux_clause(ctx: Dictionary, ligne: Control, cs: Dictionary, hauteur: float) -> void:
	var niveau := str(Guidee.extras(ctx).clause)
	var pilules: Array = []
	for c: Variant in Guidee.clauses(ctx):
		if not c is Dictionary: continue
		var nom := str(c.get("niveau", "sans"))
		pilules.append([str(Guidee.NOMS.get(nom, nom)), Guidee.COULEURS_CLAUSE.get(nom, Charte.IVOIRE), nom == niveau, nom == str(cs.get("clause", "")), "NegoClause_" + nom, func(): Guidee.choisir_clause(ctx, nom)])
	_pilules(ligne, hauteur, pilules)

## Pilules cliquables à droite d'une ligne du contrat : [mot, couleur, choisi, conseil, id, action].
static func _pilules(ligne: Control, hauteur: float, pilules: Array) -> void:
	var n := pilules.size()
	if n <= 0: return
	var w := 72.0
	var x := 636.0 - 16 - n * (w + 6) + 6
	for p: Array in pilules:
		var couleur: Color = p[1]
		var choisi := bool(p[2])
		var bord: Color = couleur if choisi else Pieces.ORANGE if bool(p[3]) else Charte.FILET
		var pilule := D.rect(ligne, Rect2(x, hauteur - 50, w, 36), Charte.PANNEAU_3.lerp(couleur, .3 if choisi else 0.0), Charte.RAYON_PILULE, bord)
		pilule.name = str(p[4])
		D.text(pilule, w / 2.0, 24, str(p[0]), 15, couleur if choisi else Charte.IVOIRE, 700, w - 8, HORIZONTAL_ALIGNMENT_CENTER)
		if bool(p[3]): pilule.set_meta("conseil", true)
		Pieces.rendre_cliquable(pilule, Vector2(w, 36), p[5], str(p[4]) + "Lien", str(p[0]), "Conseil du recruteur" if bool(p[3]) else "", Charte.RAYON_PILULE)
		x += w + 6

static func _agent(toile: Control, parent: Control, ctx: Dictionary, d: Dictionary) -> void:
	var droite := D.rect(parent, Rect2(1092, 0, 408, 842), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	droite.name = "NegoAgent"
	_avatar_agent(droite, 20, 20, 64)
	_titre(droite, 100, 50, "Agent", Pieces.BLEU, 22, 280)
	D.text(droite, 100, 78, "de " + str(ctx.player.get("name", "")), 18, Charte.IVOIRE_2, 600, 290, HORIZONTAL_ALIGNMENT_LEFT, true).name = "NegoAgentNom"
	Pieces.rendre_cliquable(droite.get_node("NegoAgentAvatar"), Vector2(64, 64), func(): Offre._fenetre_discussion(toile, ctx, d), "NegoAgentLien", "Agent de " + str(ctx.player.get("name", "")), "", Charte.RAYON_PILULE)
	D.line(droite, Vector2(20, 104), Vector2(388, 104), Charte.FILET)
	var by := 122.0
	var i := 0
	for b: Array in bulles(d, ctx.quote):
		if by > 700: break
		by += _bulle(droite, 20, by, 368, str(b[0]), b[1], bool(b[2]), "NegoBulle_%d" % i)
		i += 1
	# Compteur des propositions en bas de la colonne : trois pastilles.
	_titre(droite, 20, 790, "Propositions", Charte.IVOIRE_2, 16, 160)
	for n in 3:
		var faite := n < int(d.tentatives)
		var couleur := Pieces.ROUGE if d.retrait else Pieces.ORANGE if faite else Charte.IVOIRE_3
		D.rect(droite, Rect2(196 + n * 64, 766, 52, 34), Charte.PANNEAU_3.lerp(couleur, .3 if faite else 0.0), Charte.RAYON_PILULE, couleur).name = "NegoPropo_%d" % (n + 1)
		D.text(droite, 196 + n * 64 + 26, 790, str(n + 1), 18, couleur if faite else Charte.IVOIRE_2, 700, 40, HORIZONTAL_ALIGNMENT_CENTER)

## Ligne du contrat (grammaire de l'Effectif) : liseré et fond verts quand l'agent accepte.
static func _ligne(parent: Node, zone: Rect2, libelle: String, etat: String, id: String) -> Panel:
	var couleur := couleur_etat(etat)
	var fond := Charte.PANNEAU.lerp(couleur, .14) if etat == "ok" else Charte.PANNEAU
	var ligne := D.rect(parent, zone, fond, Charte.RAYON_PETIT)
	ligne.name = id
	ligne.set_meta("etat", etat)
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

static func _carte_masse(toile: Control, parent: Node, zone: Rect2, d: Dictionary) -> void:
	var carte := D.rect(parent, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	carte.name = "NegoMasse"
	_titre(carte, 20, 36, "Masse salariale " + G.salary_period(true), Pieces.BLEU, 17, zone.size.x - 40)
	var ajout := int(d.ajout)
	var plafond := float(d.saison.get("plafondSalarial", 0)) if d.saison.get("plafondSalarial") != null else 0.0
	var semaines := int(d.semaines) if int(d.semaines) > 0 else 52
	var total := maxf(float(d.apres), float(d.masse)) * 1.08
	if plafond > 0: total = maxf(total, plafond / semaines * 1.04)
	var largeur := zone.size.x - 40
	var tuiles := [[G.salary_amount(d.masse), "actuelle", Charte.IVOIRE, "lock"], [("+" if ajout >= 0 else "−") + G.salary_amount(absi(ajout)), "ce contrat", Pieces.ORANGE if ajout > 0 else Pieces.VERT, "people"], [G.salary_amount(d.apres), "après", Pieces.BLEU, "money"]]
	for i in 3:
		var t: Array = tuiles[i]
		Pieces.tuile(carte, Rect2(20, 54 + i * 74, largeur, 66), t[0], t[1], t[2], "NegoMasseTuile_%d" % i, 28, "", t[3], i > 0)
	_barre(carte, Rect2(20, 284, largeur, 14), [[d.masse, Charte.IVOIRE_3], [maxi(0, ajout), Pieces.ORANGE]], total, plafond / semaines if plafond > 0 else -1.0)
	Pieces.rendre_cliquable(carte, zone.size, func(): _fenetre_masse(toile, d), "NegoMasseLien", "Masse salariale", "", Charte.RAYON_CARTE)

static func _carte_transferts(toile: Control, parent: Node, zone: Rect2, d: Dictionary) -> void:
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
	var tuiles := [[G.euros(dispo), "disponible", Charte.IVOIRE, "shield"], [("−" if fee > 0 else "") + G.euros(fee), "cette signature", Offre.COULEUR_PRIME, "money"], [G.euros(reste), "reste", Pieces.VERT if reste >= 0 else Pieces.ROUGE, "check" if reste >= 0 else "warning"]]
	for i in 3:
		var t: Array = tuiles[i]
		Pieces.tuile(carte, Rect2(20, 54 + i * 74, largeur, 66), t[0], t[1], t[2], "NegoTransfertsTuile_%d" % i, 28, "", t[3], i > 0)
	_barre(carte, Rect2(20, 280, largeur, 14), [[engage, Charte.IVOIRE_3], [fee, Offre.COULEUR_PRIME], [maxf(0, reste), Pieces.VERT]], total)
	Pieces.rendre_cliquable(carte, zone.size, func(): Offre._fenetre_budget(toile, d), "NegoTransfertsLien", titre, "", Charte.RAYON_CARTE)

static func _fenetre_masse(toile: Control, d: Dictionary) -> void:
	var tuiles: Array = [[G.salary(d.masse), "Actuelle", Charte.IVOIRE, "lock"], [("+" if int(d.ajout) >= 0 else "−") + G.salary(absi(int(d.ajout))), "Ce contrat", Pieces.ORANGE, "people"], [G.salary(d.apres), "Après", Pieces.BLEU, "money"]]
	var marge: Variant = d.saison.get("margePlafond")
	if marge is int or marge is float:
		var semaines := int(d.semaines) if int(d.semaines) > 0 else 52
		var apres := float(marge) - float(d.ajout) * semaines
		tuiles.append([G.euros(apres), "Marge plafond / an", Pieces.VERT if apres >= 0 else Pieces.ROUGE, "shield"])
	Offre._fenetre(toile, "NegoFenetreMasse", "Masse salariale", tuiles, Pieces.BLEU)

# --- Petite fenêtre « Disponibilité » (fiche joueur, Marché des transferts) ------------------------------------------------
# Remplace le bouton « Proposer aux autres clubs » : phrase de l'agent, puis trois lignes cliquables (clic = appliqué) :
#  - Pas disponible : retire de la liste des transferts (commande sale_list) ;
#  - Liste des transferts : propose aux autres clubs (sale_list, native/engine/vente-joueurs.cjs) ;
#  - Prêt : un clic ouvre les clubs d'accueil, un clic sur un club prête le joueur jusqu'à l'intersaison (academy_loan,
#    parcours du centre : 23 ans et moins, hors des 23, 3 prêts par saison ; dist/espoirs-parcours-v78-v81.js).

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

## Parcours du centre (prêts) : données du moteur, "" si le prêt est possible, sinon le motif court.
static func pret(app: Control, joueur: Dictionary) -> Dictionary:
	var data: Dictionary = app.model.get("clubLife", {}).get("academyPathways", {}) if app.model.get("clubLife") is Dictionary else {}
	var id := str(joueur.get("id", ""))
	var motif := ""
	if not bool(data.get("available", false)): motif = "Indisponible"
	elif not bool(data.get("active", false)): motif = "Parcours du centre inactifs"
	elif bool(data.get("locked", false)): motif = "Indisponible"
	elif int(joueur.get("age", 99)) > 23: motif = "23 ans et moins"
	elif (data.get("loans", []) as Array).size() >= 3: motif = "3 prêts cette saison"
	else:
		var eligible := false
		for s: Variant in data.get("seniors", []):
			if s is Dictionary and str(s.get("id", "")) == id: eligible = bool(s.get("loanEligible", false))
		if not eligible: motif = "Dans les 23" if joueur.get("shirtNumber") != null else "Sous contrat jusqu’au bout de la saison"
	return {"data":data, "motif":motif, "clubs":data.get("loanClubs", []) if data.get("loanClubs") is Array else []}

## Le bouton de la fiche ouvre-t-il quelque chose ? (sinon apparence neutre, grisé).
static func disponibilite_possible(app: Control, joueur: Dictionary) -> bool:
	var sale: Dictionary = joueur.get("sale", {}) if joueur.get("sale") is Dictionary else {}
	if sale.get("pending") is Dictionary: return false
	return bool(sale.get("listed", false)) or str(sale.get("blocked", "")).is_empty() or str(pret(app, joueur).motif).is_empty()

## Libellé du bouton de la fiche : « Disponibilité · <état> ».
static func libelle_disponibilite(joueur: Dictionary) -> String:
	var sale: Dictionary = joueur.get("sale", {}) if joueur.get("sale") is Dictionary else {}
	return "Disponibilité · " + ("Liste des transferts" if bool(sale.get("listed", false)) else "Pas disponible")

## Fenêtre « Disponibilité » : phrase de l'agent, trois lignes ; `vue` "clubs" montre les clubs d'accueil du prêt.
static func ouvrir_disponibilite(page: Control, app: Control, joueur: Dictionary, vue: String = "") -> void:
	var sale: Dictionary = joueur.get("sale", {}) if joueur.get("sale") is Dictionary else {}
	var liste := bool(sale.get("listed", false))
	var bloque := str(sale.get("blocked", ""))
	var prets := pret(app, joueur)
	var clubs: Array = (prets.clubs as Array).duplicate()
	clubs.sort_custom(func(a: Variant, b: Variant): return str(a.get("name", "")) < str(b.get("name", "")))
	var hauteur := 600.0 if vue != "clubs" else 300.0 + ceilf(clubs.size() / 3.0) * 58.0
	var panneau := Fenetre.ouvrir(page, "NegoDispo", "DISPONIBILITÉ", "money", 900, minf(1100.0, hauteur))
	var contenu := Control.new()
	contenu.name = "NegoDispoContenu"
	contenu.mouse_filter = Control.MOUSE_FILTER_PASS
	panneau.add_child(contenu)
	D.place(contenu, Rect2(0, 0, 900, hauteur))
	var phrase := phrase_disponibilite(joueur)
	_avatar_agent(contenu, 28, 84, 64)
	_titre(contenu, 108, 108, "Agent de " + str(joueur.get("name", "")), Pieces.BLEU, 18, 600)
	_bulle(contenu, 108, 122, 760, str(phrase[0]), phrase[1], true, "NegoDispoPhrase")
	if vue == "clubs":
		_dispo_clubs(page, app, joueur, contenu, prets, clubs)
		Offre._marquer(contenu)
		return
	var lignes := [
		["garde", "Pas disponible", "lock", Charte.IVOIRE, not liste, ""],
		["liste", "Liste des transferts", "money", Pieces.ORANGE, liste, "" if liste else bloque],
		["pret", "Prêt", "bus", Offre.COULEUR_PRIME, false, str(prets.motif)],
	]
	var y := 196.0
	for l: Array in lignes:
		var cle := str(l[0])
		var actif := bool(l[4])
		var motif := str(l[5])
		var couleur: Color = l[3] if motif.is_empty() else Charte.IVOIRE_3
		var ligne := D.rect(contenu, Rect2(28, y, 844, 74), Charte.SELECTION if actif else Charte.PANNEAU_2, Charte.RAYON_PETIT, couleur if actif else Color.TRANSPARENT)
		ligne.name = "NegoDispoChoix_" + cle
		D.rect(ligne, Rect2(0, 0, 6, 74), couleur, 3)
		_icone(ligne, Rect2(24, 20, 34, 34), str(l[2]), couleur)
		_gros(ligne, 76, 48, str(l[1]).to_upper(), couleur if l[3] != Charte.IVOIRE else Charte.IVOIRE, 28, 420)
		if cle == "liste": Pieces.pastille(ligne, 470, 20, "Valeur " + G.euros(sale.get("value", 0)), "money", "NegoDispoValeur", "", Offre.COULEUR_PRIME)
		if cle == "pret" and motif.is_empty(): Pieces.pastille(ligne, 470, 20, "%d clubs" % clubs.size(), "bus", "NegoDispoClubs", "", Offre.COULEUR_PRIME)
		if not motif.is_empty(): Pieces.pastille(ligne, 844 - 24 - Pieces.largeur_pastille(motif, "warning"), 20, motif, "warning", "NegoDispoBloque_" + cle, bloque if cle == "liste" else "", Pieces.ROUGE)
		elif actif: _icone(ligne, Rect2(844 - 56, 20, 34, 34), "check", Pieces.VERT).name = "NegoDispoActif"
		if motif.is_empty() and not actif:
			var action := Callable()
			match cle:
				"garde", "liste":
					action = func():
						Fenetre.fermer(page, "NegoDispo")
						load("res://ui/player_sales_view.gd").toggle(app, joueur)
				"pret":
					action = func(): ouvrir_disponibilite(page, app, joueur, "clubs")
			Pieces.rendre_cliquable(ligne, Vector2(844, 74), action, "NegoDispoChoixLien_" + cle, str(l[1]), "", Charte.RAYON_PETIT)
		y += 86
	var tuiles := [[G.euros(sale.get("value", 0)), "valeur estimée", Offre.COULEUR_PRIME, "money"], [G.salary(joueur.get("salary", 0)), "salaire", Pieces.BLEU, "people"], [G.contract_year(joueur.get("contractEnd")) if joueur.get("contractEnd") != null else "—", "fin de contrat", Offre.COULEUR_DUREE, "calendar"]]
	for i in 3:
		var t: Array = tuiles[i]
		Pieces.tuile(contenu, Rect2(28 + i * 290, 470, 274, 90), t[0], t[1], t[2], "NegoDispoTuile_%d" % i, 30, "", t[3], true)
	Offre._marquer(contenu)

## Clubs d'accueil du prêt : un clic sur un club prête le joueur (appliqué tout de suite).
static func _dispo_clubs(page: Control, app: Control, joueur: Dictionary, contenu: Control, prets: Dictionary, clubs: Array) -> void:
	_titre(contenu, 28, 206, "Prêt · club d’accueil", Offre.COULEUR_PRIME, 18, 600)
	Pieces.pastille(contenu, 900 - 28 - Pieces.largeur_pastille("Retour", "arrow"), 182, "Retour", "arrow", "NegoDispoRetour", "", Charte.IVOIRE, Charte.PANNEAU_3,
		func(): ouvrir_disponibilite(page, app, joueur))
	var id := str(joueur.get("id", ""))
	var data: Dictionary = prets.data
	for i in clubs.size():
		var club: Dictionary = clubs[i]
		var zone := Rect2(28 + (i % 3) * 286, 232 + floorf(i / 3.0) * 58, 274, 48)
		var pilule := D.rect(contenu, zone, Charte.PANNEAU_2, Charte.RAYON_PILULE)
		pilule.name = "NegoDispoClub_%d" % int(club.get("id", -1))
		_icone(pilule, Rect2(14, 12, 24, 24), "bus", Offre.COULEUR_PRIME)
		D.text(pilule, 48, 31, str(club.get("name", "")), 18, Charte.IVOIRE, 700, zone.size.x - 60, HORIZONTAL_ALIGNMENT_LEFT, true)
		var to := int(club.get("id", -1))
		Pieces.rendre_cliquable(pilule, zone.size, func():
			Fenetre.fermer(page, "NegoDispo")
			load("res://ui/academy_pathways_view.gd")._send(app, data, "academy_loan", {"playerId": id, "to": to, "confirmed": true}),
			"NegoDispoClubLien_%d" % to, str(club.get("name", "")), "", Charte.RAYON_PILULE)
