extends RefCounted
## Fiche joueur › Contrat : temps de jeu promis au contrat (revue FM27, idée 16 ; choix A de Léo du 23/11/2026).
## Trois colonnes : contrat, primes et clauses (+ marché), temps de jeu (rôle promis, 10 pastilles, liste des matchs,
## satisfaction). Rôle, libellés et couleurs : base commune ui/role_contrat.gd (Charte.ROLE_*).
## Données : `squad[].tempsJeu` (native/engine/role-contrat.cjs) = {role, deduit, saison, seuil (minutes de moyenne,
## Titulaire 50 / Rotation 20), part (Espoir 0,25 = 1 match sur 4), juges, joues, moyenne, pastilles, humeur}.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Link = preload("res://ui/entity_link.gd")
const Sales = preload("res://ui/player_sales_view.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Role = preload("res://ui/role_contrat.gd")

## Exigence de chaque rôle (seuils de Léo du 23/11/2026), en chiffres.
const EXIGENCES := {"titulaire": "50′ de moyenne", "rotation": "20′ de moyenne", "espoir": "1 match sur 4", "appoint": "—"}
const HUMEURS := {"content": ["▲", "Content"], "attentif": ["●", "Attentif"], "mecontent": ["▼", "Mécontent"], "neutre": ["—", "En attente"]}
const ETATS := {"tenu": "Tenu", "manque": "Manqué", "absent": "Absent", "neutre": "—"}

static func couleur_etat(etat: String) -> Color:
	return Pieces.VERT if etat == "tenu" else Pieces.ROUGE if etat == "manque" else Charte.GRIS_VERT

static func couleur_humeur(h: String) -> Color:
	return Pieces.VERT if h == "content" else Pieces.ORANGE if h == "attentif" else Pieces.ROUGE if h == "mecontent" else Charte.GRIS_VERT

## Pastille ronde d'un match : pleine (vert = tenu, rouge = manqué), anneau gris (sans exigence) ou disque gris à croix
## de soin (absent : blessé ou suspendu, match non compté).
class Pastille extends Control:
	var etat := "neutre"
	func _draw() -> void:
		var r := minf(size.x, size.y) * .5
		var centre := size * .5
		var w := maxf(2.0, r * .16)
		if etat == "neutre":
			draw_arc(centre, r - w * .5, 0, TAU, 48, Color(Charte.GRIS_VERT, .55), w, true)
			draw_line(centre + Vector2(-r * .32, 0), centre + Vector2(r * .32, 0), Color(Charte.GRIS_VERT, .7), w, true)
			return
		if etat == "absent":
			draw_circle(centre, r, Color(Charte.GRIS_VERT, .35), true, -1.0, true)
			draw_line(centre + Vector2(0, -r * .42), centre + Vector2(0, r * .42), Charte.IVOIRE, w * 1.3, true)
			draw_line(centre + Vector2(-r * .42, 0), centre + Vector2(r * .42, 0), Charte.IVOIRE, w * 1.3, true)
			return
		draw_circle(centre, r, Pieces.VERT if etat == "tenu" else Pieces.ROUGE, true, -1.0, true)
		var encre := Charte.NOIR_PANNEAU
		if etat == "tenu":
			draw_polyline(PackedVector2Array([centre + Vector2(-r * .42, 0), centre + Vector2(-r * .12, r * .32), centre + Vector2(r * .44, -r * .34)]), encre, w * 1.2, true)
		else:
			draw_line(centre + Vector2(-r * .34, -r * .34), centre + Vector2(r * .34, r * .34), encre, w * 1.2, true)
			draw_line(centre + Vector2(-r * .34, r * .34), centre + Vector2(r * .34, -r * .34), encre, w * 1.2, true)

static func donnees(player: Dictionary) -> Dictionary:
	var tj: Variant = player.get("tempsJeu")
	return tj if tj is Dictionary else {}

## Rôle du joueur : celui du temps de jeu, sinon celui du contrat (Role.role).
static func role_de(player: Dictionary) -> String:
	var r := str(donnees(player).get("role", ""))
	return r if r in Role.ROLES else Role.role(player)

## Mesure de la satisfaction : moyenne / seuil (Titulaire, Rotation), matchs joués / comptés (Espoir), « — » (Appoint).
static func mesure(tj: Dictionary) -> String:
	if tj.get("seuil") is int or tj.get("seuil") is float:
		return "%s′ / %s′" % [G.n(int(tj.get("moyenne", 0))), G.n(int(tj.seuil))]
	if tj.get("part") is int or tj.get("part") is float:
		return "%d / %d" % [int(tj.get("joues", 0)), int(tj.get("juges", 0))]
	return "—"

static func _ouvrir_historique(app: Control) -> void:
	app.management_ui.immersive_player_tab = 2
	app.render()

static func _prolonger(app: Control, player: Dictionary) -> void:
	var renewal: Dictionary = player.get("renewal", {}) if player.get("renewal") is Dictionary else {}
	if bool(renewal.get("available", false)) and app._live().is_empty(): app.SquadViews.contract(app, player, false)

static func _court(nom: String) -> String:
	var mots := Array(nom.split(" ", false)).filter(func(m: String): return m != "XV" and m.length() > 2)
	return (str(mots[0]) if mots.size() > 0 else nom).substr(0, 9).to_upper()

static func _pilule(parent: Control, zone: Rect2, texte: String, couleur: Color, plein := true, taille := 20, id := "") -> Panel:
	var p := D.rect(parent, zone, couleur if plein else Color(couleur, .16), Charte.RAYON_PILULE)
	if not id.is_empty(): p.name = id
	_t(p, 0, zone.size.y * .5 + taille * .36, texte, taille, Charte.NOIR_PANNEAU if plein else couleur, 700, zone.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	return p

# --- Lignes « libellé / valeur » façon Effectif ----------------------------------------------------------------------

static func _ligne(card: Control, i: int, y: float, pas: float, largeur: float, libelle: String, valeur: String, couleur: Color, id: String, action := Callable(), taille := 24) -> Control:
	var rang := Control.new()
	rang.name = id
	card.add_child(rang)
	D.place(rang, Rect2(16, y, largeur - 32, pas - 4))
	var rayure = load("res://ui/survol_ligne.gd").rayure(rang, i)
	if rayure != null: D.place(rayure, Rect2(0, 0, largeur - 32, pas - 4))
	_t(rang, 12, pas * .5 + 6, libelle, 19, Charte.GRIS_VERT, 500, largeur * .5)
	var v := _t(rang, largeur * .42, pas * .5 + 8, valeur, taille, couleur, 700, largeur * .58 - 56, HORIZONTAL_ALIGNMENT_RIGHT)
	v.add_theme_font_override("font", Charte.texte_moyen())
	if action.is_valid(): Pieces.rendre_cliquable(rang, Vector2(largeur - 32, pas - 4), action, id + "Lien", libelle, "", Charte.RAYON_PETIT)
	return rang

static func _masse(app: Control, player: Dictionary) -> float:
	var total := 0.0
	for p: Variant in app.model.get("squad", []):
		if p is Dictionary and (p.get("salary") is int or p.get("salary") is float): total += float(p.salary)
	var w: Variant = player.get("salary", 0)
	return float(w) / total if total > 0 and (w is int or w is float) else 0.0

static func _restantes(app: Control, player: Dictionary) -> int:
	var fin: Variant = player.get("contractEnd")
	if not (fin is int or fin is float): return -1
	return int(fin) - int(app.model.get("meta", {}).get("season", 1))

static func contrat(card: Panel, app: Control, player: Dictionary, largeur: float, pas: float, y0: float) -> void:
	var role := role_de(player)
	var part := _masse(app, player)
	var reste := _restantes(app, player)
	var couleur_fin: Color = Pieces.ROUGE if reste <= 0 else Pieces.ORANGE if reste == 1 else Pieces.VERT
	var lignes := [
		["Salaire " + G.salary_period(true), G.salary(player.get("salary", 0)), Charte.IVOIRE],
		["Part de la masse salariale", ("%.1f %%" % (part * 100)).replace(".", ","), Pieces.BLEU],
		["Fin de contrat", G.contract_year(player.get("contractEnd")), couleur_fin],
		["Saisons restantes", "—" if reste < 0 else G.n(maxi(0, reste) + 1), couleur_fin],
		["Rôle promis", Role.libelle(role), Role.couleur(role)],
		["Minutes de la saison", G.n(player.get("minutes", 0)) + "′ · " + G.n(player.get("appearances", 0)) + " matchs", Charte.IVOIRE],
	]
	for i in lignes.size():
		var l: Array = lignes[i]
		var action := Callable()
		if i == 4: action = func(): _prolonger(app, player)
		elif i == 5: action = func(): _ouvrir_historique(app)
		_ligne(card, i, y0 + i * pas, pas, largeur, l[0], l[1], l[2], "TempsJeuContrat" + str(i), action, 24 if pas >= 50 else 21)
	var renewal: Dictionary = player.get("renewal", {}) if player.get("renewal") is Dictionary else {}
	var offre: Button = Kit.bouton_ivoire(card, Rect2(24, y0 + lignes.size() * pas + 12, largeur - 48, 46), "Proposer une prolongation", func(): app.SquadViews.contract(app, player, false), "OfferRenewal")
	offre.disabled = not renewal.get("available", false) or not app._live().is_empty()
	if renewal.has("reason"): offre.tooltip_text = str(renewal.reason)

static func primes(card: Panel, app: Control, player: Dictionary, largeur: float, pas: float, y0: float) -> void:
	var renewal: Dictionary = player.get("renewal", {}) if player.get("renewal") is Dictionary else {}
	var role := role_de(player)
	var actuel := int(player.get("salary", 0))
	var demande: Variant = renewal.get("salary")
	var ecart := (int(demande) - actuel) if (demande is int or demande is float) else 0
	var vente := Sales.short(player)
	var lignes := [
		["Temps de jeu promis", Role.libelle(role) + " · " + str(EXIGENCES.get(role, "—")), Role.couleur(role), "temps"],
		["Prime de prolongation", G.euros(renewal.get("fee")) if renewal.has("fee") else "—", Pieces.TURQUOISE, "prolonger"],
		["Salaire demandé", (G.salary(demande) + ("  ▲" if ecart > 0 else "  ▼" if ecart < 0 else "")) if demande != null else "—", Pieces.ROUGE if ecart > 0 else Pieces.VERT, "prolonger"],
		["Durée possible", ("%s à %s saisons" % [G.n(renewal.get("minYears", 1)), G.n(renewal.get("maxYears", 3))]) if renewal.has("maxYears") else "—", Pieces.VIOLET, "prolonger"],
		["Prolongation", "Ouverte" if bool(renewal.get("available", false)) else "Fermée", Pieces.VERT if bool(renewal.get("available", false)) else Pieces.ROUGE, "prolonger"],
		["Marché", vente if not vente.is_empty() else "Non proposé", Pieces.ORANGE if not vente.is_empty() else Charte.GRIS_VERT, ""],
	]
	for i in lignes.size():
		var l: Array = lignes[i]
		var action := Callable()
		if l[3] == "prolonger": action = func(): _prolonger(app, player)
		elif l[3] == "temps": action = func(): _ouvrir_historique(app)
		_ligne(card, i, y0 + i * pas, pas, largeur, l[0], l[1], l[2], "TempsJeuPrime" + str(i), action, 24 if pas >= 50 else 21)

# --- Temps de jeu : rôle, 10 pastilles, liste des matchs, satisfaction -----------------------------------------------

static func temps(card: Panel, app: Control, player: Dictionary, largeur: float) -> void:
	var tj := donnees(player)
	var role := role_de(player)
	var c := Role.couleur(role)
	var titre := _t(card, 24, 126, Role.libelle(role).to_upper(), 58, c, 400, 420)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "TempsJeuRole"
	var zone_role := Control.new()
	card.add_child(zone_role)
	D.place(zone_role, Rect2(16, 68, 430, 70))
	Pieces.rendre_cliquable(zone_role, Vector2(430, 70), func(): _prolonger(app, player), "TempsJeuRoleLien", "Rôle promis", "", Charte.RAYON_PETIT)
	var promis := not bool(tj.get("deduit", true))
	var saison: Variant = tj.get("saison")
	_pilule(card, Rect2(24, 146, 230, 34), ("Promis " + G.contract_year(int(saison) - 1)) if promis and (saison is int or saison is float) else "Hiérarchie au poste", c, false, 17, "TempsJeuOrigine")
	_pilule(card, Rect2(266, 146, 200, 34), str(EXIGENCES.get(role, "—")), c, false, 17, "TempsJeuExigence")
	var h := str(tj.get("humeur", "neutre"))
	var hc := couleur_humeur(h)
	var hum: Array = HUMEURS.get(h, HUMEURS.neutre)
	var bloc := D.rect(card, Rect2(largeur - 260, 72, 236, 108), Color(hc, .14), Charte.RAYON_CARTE)
	bloc.name = "TempsJeuHumeur"
	_t(bloc, 0, 48, mesure(tj), 36, hc, 800, 236, HORIZONTAL_ALIGNMENT_CENTER).name = "TempsJeuMesure"
	_t(bloc, 0, 90, hum[0] + " " + str(hum[1]).to_upper(), 22, hc, 700, 236, HORIZONTAL_ALIGNMENT_CENTER)
	Pieces.rendre_cliquable(bloc, Vector2(236, 108), func(): _ouvrir_historique(app), "TempsJeuHumeurLien", "Satisfaction", "", Charte.RAYON_CARTE)
	var pastilles: Array = tj.get("pastilles", []) if tj.get("pastilles") is Array else []
	var pas := (largeur - 48) / 10.0
	for k in 10:
		var i := k - (10 - pastilles.size())
		var x := 24 + k * pas
		var pastille := Pastille.new()
		pastille.name = "TempsJeuPastille" + str(k)
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(pastille)
		D.place(pastille, Rect2(x + (pas - 54) * .5, 214, 54, 54))
		if i < 0:
			pastille.etat = "neutre"
			pastille.modulate.a = .35
			continue
		var m: Dictionary = pastilles[i]
		pastille.etat = str(m.get("etat", "neutre"))
		_t(card, x, 296, G.n(m.get("minutes", 0)) + "′", 21, Charte.IVOIRE if int(m.get("minutes", 0)) > 0 else Charte.GRIS_VERT, 700, pas, HORIZONTAL_ALIGNMENT_CENTER)
		_t(card, x, 322, _court(str(m.get("adversaire", ""))), 14, Charte.GRIS_VERT, 600, pas, HORIZONTAL_ALIGNMENT_CENTER)
		var cible := Control.new()
		card.add_child(cible)
		D.place(cible, Rect2(x + 2, 206, pas - 4, 124))
		Pieces.rendre_cliquable(cible, Vector2(pas - 4, 124), func(): _ouvrir_historique(app), "TempsJeuPastilleLien" + str(k), "Match", "%s · %s′" % [str(m.get("adversaire", "")), G.n(m.get("minutes", 0))], Charte.RAYON_PETIT)
	D.line(card, Vector2(18, 344), Vector2(largeur - 18, 344), Color(C.LINE, .7))
	for col: Array in [["ADVERSAIRE", 28, 300], ["MIN.", 340, 90], ["PROMIS", 440, 140], ["", 590, 120]]:
		_t(card, col[1], 376, col[0], 16, Charte.IVOIRE_3, 600, col[2])
	var liste: Array = pastilles.duplicate()
	liste.reverse()
	var promis_match := ("≥ " + G.n(int(tj.seuil)) + "′") if (tj.get("seuil") is int or tj.get("seuil") is float) else "1 sur 4" if role == "espoir" else "—"
	for i in mini(liste.size(), 10):
		var m: Dictionary = liste[i]
		var y := 388 + i * 41
		var rang := Control.new()
		rang.name = "TempsJeuMatch" + str(i)
		card.add_child(rang)
		D.place(rang, Rect2(16, y, largeur - 32, 39))
		var rayure = load("res://ui/survol_ligne.gd").rayure(rang, i)
		if rayure != null: D.place(rayure, Rect2(0, 0, largeur - 32, 39))
		Link.name_link(app, rang, Rect2(10, 2, 300, 35), "club", str(int(m.get("adversaireId", -1))), str(m.get("adversaire", "")), 20, Charte.IVOIRE, "TempsJeuAdversaire" + str(i))
		_t(rang, 324, 28, G.n(m.get("minutes", 0)) + "′", 21, Charte.IVOIRE, 700, 90)
		_t(rang, 424, 28, promis_match, 19, c, 600, 140)
		var e := str(m.get("etat", "neutre"))
		_pilule(rang, Rect2(574, 5, 130, 29), str(ETATS.get(e, "—")), couleur_etat(e), e in ["tenu", "manque"], 16, "TempsJeuEtat" + str(i))

## D.text avec `x` = bord gauche de la zone quelle que soit l'alignement (D.text prend le bord droit ou le centre).
static func _t(parent: Node, x: float, baseline: float, value: Variant, taille: int = 22, couleur: Color = C.IVORY, poids: int = 600, largeur: float = 0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var ancre := x + largeur if align == HORIZONTAL_ALIGNMENT_RIGHT else x + largeur * .5 if align == HORIZONTAL_ALIGNMENT_CENTER else x
	return D.text(parent, ancre, baseline, value, taille, couleur, poids, largeur, align)
