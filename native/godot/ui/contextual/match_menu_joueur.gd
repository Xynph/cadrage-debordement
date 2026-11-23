extends RefCounted
## Menu d'un joueur en match (idée n° 32 de la revue FM27 de Léo) — PLANCHE A/B sous CD_VARIANTE_VISUELLE.
## Clic sur une carte de la bande Mon XV : poste (familiarité en barres + note au poste /100, plus d'étoiles), rôle
## (table rugby de la fiche, écran seulement), responsabilités en direct (buteur, lanceur, botteur… : vraie commande
## `set_role_direct`), « Remplacer par » (remplaçants : condition, moral, familiarité au poste, note au poste) ; un clic
## sur un remplaçant fait le changement (`substitute`), sans bouton Confirmer ; la carte sortie / entrée s'affiche
## ensuite sur le terrain.
## A : menu accroché à la carte cliquée, la liste des remplaçants s'ouvre à côté.
## B : petite fenêtre plus large, remplaçants en lignes façon Effectif, petit terrain des 15 postes.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const S = preload("res://ui/contextual/skin.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const FenetreVisuelle = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Familiarite = preload("res://ui/familiarite_poste.gd")
const Roles = preload("res://ui/immersive08/fiche_roles.gd")
const Commune = preload("res://ui/immersive08/fiche_commune.gd")
const Tableau = preload("res://ui/contextual/match_tableau_widgets.gd")

const NOM := "MatchMenuJoueur"
const POSTES := ["Pilier G", "Talonneur", "Pilier D", "2e ligne", "2e ligne", "3e ligne", "3e ligne", "Numéro 8",
	"Demi mêlée", "Ouvreur", "Ailier", "Centre", "Centre", "Ailier", "Arrière"]
const POSTES_COURTS := ["PG", "TA", "PD", "2L", "2L", "3L", "3L", "N8", "DM", "DO", "AI", "CE", "CE", "AI", "AR"]
## Moral de départ d'un remplaçant qui n'est pas encore entré (même table que dist/match-pilotage.js).
const MORAL_DEPART := {"galvanise": 72, "motive": 64, "serein": 60, "indifferent": 50, "tendu": 40, "vexe": 36, "relache": 44}
const PALIERS := [[78, "gonfle", "Gonflé à bloc"], [62, "confiant", "Confiant"], [42, "concentre", "Concentré"], [28, "inquiet", "Inquiet"], [0, "abattu", "Abattu"]]
## Places des 15 postes sur le petit terrain (B), attaque vers le haut.
const PLACES := [Vector2(.22, .90), Vector2(.5, .90), Vector2(.78, .90), Vector2(.39, .78), Vector2(.61, .78),
	Vector2(.16, .68), Vector2(.84, .68), Vector2(.5, .66), Vector2(.36, .53), Vector2(.6, .47), Vector2(.1, .2),
	Vector2(.38, .32), Vector2(.62, .32), Vector2(.9, .2), Vector2(.5, .1)]

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

static func teinte_moral(cle: String) -> Color:
	match cle:
		"gonfle": return Charte.NOTE_EXCELLENTE
		"confiant": return Charte.CONDITION
		"inquiet": return Charte.INTENSIF
		"abattu": return Charte.PERTE
	return Charte.MORAL

static func teinte_energie(e: float) -> Color:
	return Charte.CONDITION if e >= 75.0 else Charte.INTENSIF if e >= 55.0 else Charte.PERTE

# --- Données ---------------------------------------------------------------------------------------------------------

## Moral en direct (`live.pilotage.moral`), sinon départ d'après la réaction à la causerie (remplaçant pas encore entré).
static func moral(pilotage: Dictionary, id: String) -> Dictionary:
	var tous: Variant = pilotage.get("moral")
	if tous is Dictionary and (tous as Dictionary).get(id) is Dictionary:
		var m: Dictionary = tous[id]
		return {"valeur": int(m.get("valeur", 50)), "cle": str(m.get("cle", "")), "label": str(m.get("label", ""))}
	var etats: Variant = pilotage.get("joueurs")
	var etat: Dictionary = (etats as Dictionary).get(id, {}) if etats is Dictionary and (etats as Dictionary).get(id) is Dictionary else {}
	var v := int(MORAL_DEPART.get(str(etat.get("etat", "")), 50))
	for p: Array in PALIERS:
		if v >= int(p[0]): return {"valeur": v, "cle": p[1], "label": p[2]}
	return {"valeur": v, "cle": "concentre", "label": "Concentré"}

static func note_poste(joueur: Dictionary, numero: int) -> float:
	var notes: Variant = joueur.get("positionRatings")
	if not notes is Dictionary: return -1.0
	var n: Variant = (notes as Dictionary).get(str(numero))
	return float(n) if (n is float or n is int) and float(n) >= 0.0 else -1.0

static func _complet(app: Control, joueur: Dictionary) -> Dictionary:
	var trouve: Dictionary = Commune.trouver(app, str(joueur.get("id", "")), "squad")
	var complet: Dictionary = (trouve.joueur as Dictionary).duplicate() if not trouve.is_empty() else {}
	complet.merge(joueur, true)
	return complet

## Tout ce que montrent A et B pour le joueur `id` (titulaire) : {slot, numero, joueur, energie, moral, note, niveau,
## note_poste, roles, role, responsabilites, remplacants, restants}.
static func donnees(view: Control, id: String) -> Dictionary:
	var live: Dictionary = view._live()
	var lineup: Array = live.get("lineup", []) if live.get("lineup") is Array else []
	var slot := -1
	for i in lineup.size():
		if lineup[i] is Dictionary and str(lineup[i].get("id", "")) == id: slot = i
	if slot < 0: return {}
	var numero := slot + 1
	var joueur := _complet(view.app, lineup[slot])
	var pilotage: Dictionary = live.get("pilotage", {}) if live.get("pilotage") is Dictionary else {}
	var direct: Dictionary = live.get("direct", {}) if live.get("direct") is Dictionary else {}
	var notes: Dictionary = direct.get("notes", {}) if direct.get("notes") is Dictionary else {}
	var d := Tableau.donnees_joueur(joueur, notes, {}, {})
	var valeurs: Dictionary = Commune.valeurs(joueur, "squad")
	var roles: Array = []
	for r: Array in Roles.roles_famille(Roles.FAMILLE[numero - 1]):
		roles.append({"id": r[0], "nom": r[2], "note": Roles.note_role(valeurs, r)})
	var choisi: Dictionary = view.get_meta("menu_joueur_roles", {})
	var role := str(choisi.get(id, Roles.meilleur_role(valeurs, numero)))
	# Responsabilités en direct du moteur (pilotage.roles) : est-il en charge ? sa valeur dans l'attribut du rôle.
	var resp: Array = []
	var source: Variant = pilotage.get("roles")
	for r: Variant in (source.get("roles") if source is Dictionary and source.get("roles") is Array else []):
		if not r is Dictionary: continue
		var en_jeu: Variant = r.get("enJeu")
		var valeur := -1
		for c: Variant in (r.get("candidats") if r.get("candidats") is Array else []):
			if c is Dictionary and str(c.get("id", "")) == id: valeur = int(c.get("value", 0))
		resp.append({"id": str(r.get("id", "")), "nom": str(r.get("label", "")), "charge": en_jeu is Dictionary and str(en_jeu.get("id", "")) == id, "valeur": valeur})
	# Remplaçants : autorisés à ce poste par le moteur (match arrêté), sinon tous montrés.
	var autorises: Array = []
	for option: Variant in live.get("substitutions", []) if live.get("substitutions") is Array else []:
		if option is Dictionary and int(option.get("slot", -1)) == slot and option.get("inIds") is Array: autorises = option.inIds.map(func(x: Variant) -> String: return str(x))
	var arret := bool(live.get("paused", false))
	var note_sortant := note_poste(joueur, numero)
	var remplacants: Array = []
	var reserves: Array = live.get("reserves", []) if live.get("reserves") is Array else []
	for k in reserves.size():
		if not reserves[k] is Dictionary: continue
		var r := _complet(view.app, reserves[k])
		var rid := str(r.get("id", ""))
		var np := note_poste(r, numero)
		remplacants.append({"id": rid, "joueur": r, "numero": k + 16, "nom": str(r.get("name", "")), "poste": str(r.get("pos", "")),
			"energie": clampf(float(r.get("condition", 100)), 0.0, 100.0), "moral": moral(pilotage, rid),
			"familiarite": Familiarite.niveau(r, numero), "note_poste": np, "ecart": np - note_sortant if np >= 0.0 and note_sortant >= 0.0 else 0.0,
			"permis": (not arret) or autorises.is_empty() or rid in autorises, "blesse": int(r.get("injury", 0)) > 0})
	var tri := str(view.get_meta("menu_joueur_tri", "note"))
	remplacants.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.permis != b.permis: return a.permis
		match tri:
			"energie": return a.energie > b.energie
			"moral": return int(a.moral.valeur) > int(b.moral.valeur)
			"familiarite": return a.familiarite > b.familiarite or (a.familiarite == b.familiarite and a.note_poste > b.note_poste)
		return a.note_poste > b.note_poste)
	var restants: Variant = live.get("remplacementsRestants", live.get("substitutionsLeft"))
	return {"id": id, "slot": slot, "numero": numero, "joueur": joueur, "energie": clampf(float(d.energie), 0.0, 100.0),
		"moral": moral(pilotage, id), "note": float(d.note), "note_connue": notes.has(id), "familiarite": Familiarite.niveau(joueur, numero),
		"note_poste": note_sortant, "roles": roles, "role": role, "responsabilites": resp, "remplacants": remplacants,
		"restants": int(restants) if restants is int or restants is float else -1}

# --- Actions ---------------------------------------------------------------------------------------------------------

## Clic sur un remplaçant : le changement part tout de suite (aucune confirmation), le menu se ferme, la carte
## sortie / entrée s'affiche sur le terrain.
static func remplacer(view: Control, d: Dictionary, entrant: Dictionary) -> void:
	if not bool(entrant.get("permis", true)): return
	var sortant: Dictionary = d.joueur
	if not view.app._command("substitute", {"slot": int(d.slot), "outId": str(d.id), "inId": str(entrant.id)}): return
	PetiteFenetre.fermer_derniere(view.get_tree())
	var between: Variant = view.regie.between if view.get("regie") != null and view.regie != null else null
	if between != null: carte_changement(between.terrain, {"numero": int(d.numero), "nom": str(sortant.get("name", "")), "note": float(d.note), "energie": float(d.energie)},
		{"numero": int(d.numero), "nom": str(entrant.nom), "note_poste": float(entrant.note_poste), "energie": float(entrant.energie)})

static func choisir_responsabilite(view: Control, d: Dictionary, r: Dictionary) -> void:
	view.app._command("set_role_direct", {"role": str(r.id), "id": null if bool(r.charge) else str(d.id)})
	_plus_tard(view, str(d.id))

static func choisir_role(view: Control, d: Dictionary, role_id: String) -> void:
	var choisi: Dictionary = view.get_meta("menu_joueur_roles", {})
	choisi[str(d.id)] = role_id
	view.set_meta("menu_joueur_roles", choisi)
	view.set_meta("menu_joueur_volet", "remplacants")
	_rouvrir(view, str(d.id))

static func _rouvrir(view: Control, id: String) -> void:
	var ancre: Variant = view.get_meta("menu_joueur_ancre", null)
	ouvrir(view, id, ancre if ancre is Control and is_instance_valid(ancre) else null)

## Point d'entrée : clic sur une carte de la bande Mon XV.
static func ouvrir(view: Control, id: String, ancre: Control) -> void:
	var d := donnees(view, id)
	if d.is_empty(): return
	view.set_meta("menu_joueur_ancre", ancre)
	if variante() == "B": _ouvrir_b(view, d)
	else: _ouvrir_a(view, d, ancre)

# --- Pièces communes -------------------------------------------------------------------------------------------------

static func _visage(parent: Control, joueur: Dictionary, zone: Rect2, numero: int = 0) -> void:
	var disque := D.rect(parent, zone, Charte.PANNEAU_3, Charte.RAYON_PILULE)
	disque.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	disque.name = "Visage"
	var image: TextureRect = S.G.portrait_lazy(int(joueur.get("portraitIndex", 0)), C.px(zone.size.x * 1.2), joueur)
	image.tooltip_text = ""
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.custom_minimum_size = Vector2.ZERO
	disque.add_child(image)
	D.place(image, Rect2(-zone.size.x * .1, zone.size.y * .02, zone.size.x * 1.2, zone.size.y * 1.2))
	if numero > 0:
		var m := D.rect(parent, Rect2(zone.position.x - 4, zone.end.y - 24, 28, 28), Charte.FOND, Charte.RAYON_PILULE)
		D.text(m, 14, 20, str(numero), 15, Charte.IVOIRE, 800, 28, HORIZONTAL_ALIGNMENT_CENTER)

## Jauge courte d'énergie + valeur.
static func _energie(parent: Control, x: float, base: float, largeur: float, e: float, taille: int = 18) -> void:
	var t := teinte_energie(e)
	D.rect(parent, Rect2(x, base - 12, largeur, 8), Color(Charte.CREME, .12), 4)
	D.rect(parent, Rect2(x, base - 12, maxf(4.0, largeur * e / 100.0), 8), t, 4)
	D.text(parent, x + largeur + 8, base, "%d %%" % roundi(e), taille, t, 800, 60)

static func _moral(parent: Control, x: float, y: float, m: Dictionary, nom: String) -> float:
	return Pieces.pastille(parent, x, y, str(m.label), "", nom, "", teinte_moral(str(m.cle)))

static func _note(parent: Control, x_droite: float, base: float, note: float, taille: int, nom: String) -> void:
	Familiarite.poser_note(parent, x_droite - 64, base, note, taille, 64, nom)

static func _ligne_cliquable(parent: Control, zone: Rect2, nom: String, action: Callable, fond: Color = Color.TRANSPARENT) -> Panel:
	var ligne := D.rect(parent, zone, fond, Charte.RAYON_PETIT)
	ligne.name = nom
	Pieces.rendre_cliquable(ligne, zone.size, action, nom + "Lien", nom, "", Charte.RAYON_PETIT)
	return ligne

## Rangée d'un remplaçant (A et B) : visage, numéro et nom, poste, énergie, moral, familiarité au poste, note au poste,
## écart avec le sortant (B). Clic = changement.
static func _rangee_remplacant(view: Control, parent: Control, zone: Rect2, d: Dictionary, r: Dictionary, colonnes: Array, rang: int) -> void:
	var fond := Color(Charte.CREME, .035) if rang % 2 == 1 else Color.TRANSPARENT
	var ligne := _ligne_cliquable(parent, zone, "MatchMenuJoueurRemplacant%d" % int(r.numero), func(): remplacer(view, d, r), fond)
	ligne.modulate.a = 1.0 if r.permis else .38
	var h := zone.size.y
	var base := h / 2.0 + 8.0
	_visage(ligne, r.joueur, Rect2(colonnes[0], (h - 40) / 2.0, 40, 40))
	D.text(ligne, colonnes[1], base, "%d" % int(r.numero), 17, Charte.IVOIRE_2, 700, 34)
	D.text(ligne, colonnes[1] + 36, base, Tableau_nom(str(r.nom)), 20, Charte.IVOIRE, 700, colonnes[2] - colonnes[1] - 44)
	D.text(ligne, colonnes[2], base, str(r.poste) if colonnes.size() > 7 else _poste_court(r.joueur), 17, Charte.IVOIRE_2, 700, colonnes[3] - colonnes[2] - 10)
	_energie(ligne, colonnes[3], base, 70, float(r.energie), 17)
	_moral(ligne, colonnes[4], (h - 34) / 2.0, r.moral, "Moral")
	Familiarite.poser(ligne, colonnes[5], base, int(r.familiarite), 17, "Familiarite", colonnes.size() > 7)
	_note(ligne, colonnes[6], base, float(r.note_poste), 24, "NotePoste")
	if colonnes.size() > 7:
		var e := float(r.ecart)
		var t := Charte.GAIN if e > 0.5 else Charte.PERTE if e < -0.5 else Charte.IVOIRE_2
		D.text(ligne, colonnes[7], base, ("+%d" % roundi(e)) if e > 0.5 else ("%d" % roundi(e)) if e < -0.5 else "=", 20, t, 800, 60, HORIZONTAL_ALIGNMENT_RIGHT)

static func Tableau_nom(nom: String) -> String:
	var m := nom.strip_edges().split(" ", false)
	return nom if m.size() < 2 else "%s. %s" % [m[0].left(1), " ".join(m.slice(1)).to_upper()]

# --- Option A : menu accroché à la carte ------------------------------------------------------------------------------

## Calque du menu (pas de voile sombre : le direct reste lisible derrière, clic à côté = fermer) ; même pause que les
## petites fenêtres du direct.
static func _calque(view: Control) -> Control:
	view._ouvrir_fenetre(NOM + "Calque", "", 10, 10)
	var hote: Control = view.fenetre_hote
	var toile := hote.find_child("MatchFenetreToile", false, false) as Control
	var voile := hote.find_child("MatchFenetreACote", false, false) as Button
	if voile != null:
		for etat: String in ["normal", "hover", "pressed", "focus"]:
			var vide := StyleBoxFlat.new()
			vide.bg_color = Color(Charte.NUIT, .18)
			voile.add_theme_stylebox_override(etat, vide)
	# Le panneau minuscule du cadre commun disparaît : le menu se pose à la place.
	var panneau := toile.find_child(NOM + "CalquePanneau", true, false) as Control
	if panneau != null: panneau.visible = false
	return toile.find_child(NOM + "Calque", true, false) as Control

static func _ouvrir_a(view: Control, d: Dictionary, ancre: Control) -> void:
	var calque := _calque(view)
	if calque == null: return
	var hote: Control = view.fenetre_hote
	var toile := hote.find_child("MatchFenetreToile", false, false) as Control
	# Position de la carte cliquée en unités du gabarit (toile centrée 2248 × 1230).
	var taille := Vector2(2248, 1230) * C.density
	var origine := toile.get_global_rect().position
	var carte := Rect2(1124 - 60, 1100, 120, 100)
	if ancre != null:
		var g := ancre.get_global_rect()
		carte = Rect2((g.position - origine) / C.density, g.size / C.density)
	var largeur := 540.0
	var hauteur := 104.0 + 3 * 62.0 + 62.0 + 12.0
	# Partie visible de l'écran en unités du gabarit (la toile peut déborder de l'écran).
	var vue := view.get_viewport_rect()
	var vmin := (vue.position - origine) / C.density + Vector2(12, 12)
	var vmax := (vue.end - origine) / C.density - Vector2(12, 12)
	var x := clampf(carte.get_center().x - largeur / 2.0, vmin.x, vmax.x - largeur)
	var y := clampf(carte.position.y - hauteur - 12.0, vmin.y, vmax.y - hauteur)
	var menu := D.panel(calque, Rect2(x, y, largeur, hauteur), "", "", "", NOM)
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var j: Dictionary = d.joueur
	_visage(menu, j, Rect2(18, 14, 68, 68), int(d.numero))
	D.text(menu, 104, 46, Tableau_nom(str(j.get("name", ""))), 28, Charte.IVOIRE, 800, 280).add_theme_font_override("font", Charte.TITRE_EXTRA)
	D.text(menu, 104, 78, "N° %d · %s" % [int(d.numero), POSTES[int(d.numero) - 1]], 17, Charte.IVOIRE_2, 600, 260)
	_energie(menu, largeur - 170, 44, 90, float(d.energie), 20)
	var teinte_note: Color = Charte.couleur_note(float(d.note)) if d.note_connue else Charte.IVOIRE_3
	var pn := D.rect(menu, Rect2(largeur - 80, 56, 62, 32), teinte_note, Charte.RAYON_PETIT)
	D.text(pn, 31, 24, ("%.1f" % float(d.note)).replace(".", ",") if d.note_connue else "—", 19, Charte.encre_note(float(d.note)), 800, 62, HORIZONTAL_ALIGNMENT_CENTER)
	_moral(menu, largeur - 80 - 12 - Pieces.largeur_pastille(str(d.moral.label)), 55, d.moral, "MatchMenuJoueurMoral")
	D.line(menu, Vector2(16, 96), Vector2(largeur - 16, 96), Charte.FILET, 2)
	var volet := str(view.get_meta("menu_joueur_volet", "remplacants"))
	var yy := 104.0
	# Poste : familiarité (barres) et note au poste.
	var lp := _ligne_cliquable(menu, Rect2(10, yy, largeur - 20, 56), "MatchMenuJoueurPoste", func(): _volet(view, d, "poste"), Charte.PANNEAU_3 if volet == "poste" else Color.TRANSPARENT)
	D.text(lp, 12, 36, "POSTE", 15, Charte.IVOIRE_3, 700, 90)
	Familiarite.poser(lp, 110, 36, int(d.familiarite), 19, "Familiarite")
	_note(lp, largeur - 60, 38, float(d.note_poste), 26, "NotePoste")
	D.text(lp, largeur - 44, 36, "‹", 24, Charte.IVOIRE_2, 700, 20)
	yy += 62.0
	# Rôle (table rugby de la fiche).
	var role: Dictionary = {}
	for r: Dictionary in d.roles:
		if r.id == d.role: role = r
	var lr := _ligne_cliquable(menu, Rect2(10, yy, largeur - 20, 56), "MatchMenuJoueurRole", func(): _volet(view, d, "role"), Charte.PANNEAU_3 if volet == "role" else Color.TRANSPARENT)
	D.text(lr, 12, 36, "RÔLE", 15, Charte.IVOIRE_3, 700, 90)
	D.text(lr, 110, 37, str(role.get("nom", "—")), 21, Charte.IVOIRE, 700, 260)
	_note(lr, largeur - 60, 38, float(role.get("note", -1.0)), 26, "NoteRole")
	D.text(lr, largeur - 44, 36, "‹", 24, Charte.IVOIRE_2, 700, 20)
	yy += 62.0
	# Responsabilités en direct : une pastille par rôle du moteur, pleine s'il en a la charge.
	var lc := D.rect(menu, Rect2(10, yy, largeur - 20, 56), Color.TRANSPARENT, Charte.RAYON_PETIT)
	lc.name = "MatchMenuJoueurResponsabilites"
	D.text(lc, 12, 36, "EN CHARGE", 15, Charte.IVOIRE_3, 700, 96)
	var xc := 110.0
	for r: Dictionary in d.responsabilites:
		if xc + Pieces.largeur_pastille(str(r.nom)) > largeur - 24: break
		var rr := r
		xc += Pieces.pastille(lc, xc, 11, str(r.nom), "check" if r.charge else "", "Resp_" + str(r.id), "", Charte.DORE if r.charge else Charte.IVOIRE_2,
			Charte.VOILE_DORE if r.charge else Charte.PANNEAU_3, func(): choisir_responsabilite(view, d, rr)) + 8.0
	yy += 62.0
	# Remplacer par : l'aplat doré de l'écran.
	var lrp := _ligne_cliquable(menu, Rect2(10, yy, largeur - 20, 62), "MatchMenuJoueurRemplacer", func(): _volet(view, d, "remplacants"), Charte.DORE if volet == "remplacants" else Charte.PANNEAU_3)
	var encre := Charte.ENCRE if volet == "remplacants" else Charte.IVOIRE
	D.text(lrp, 14, 41, "‹  ⇄  REMPLACER PAR", 22, encre, 800, 300).add_theme_font_override("font", Charte.TITRE_EXTRA)
	if int(d.restants) >= 0: D.text(lrp, largeur - 36, 40, "%d" % int(d.restants), 22, encre, 800, 120, HORIZONTAL_ALIGNMENT_RIGHT)
	# Volet ouvert à côté du menu (côté où il y a la place).
	var vl := 820.0 if volet == "remplacants" else 520.0
	var a_gauche := x - vl - 10.0 >= vmin.x
	# Pas la place à gauche ni à droite : le menu glisse vers la droite pour que le volet tienne à sa gauche.
	if not a_gauche and x + largeur + 10.0 + vl > vmax.x and vmin.x + vl + 10.0 <= vmax.x - largeur:
		x = vmin.x + vl + 10.0
		menu.position.x = x * C.density
		a_gauche = true
	var vx := x - vl - 10.0 if a_gauche else x + largeur + 10.0
	match volet:
		"remplacants": _volet_remplacants_a(view, calque, d, vx, y + hauteur, vl, vmin.y)
		"role": _volet_roles(view, calque, d, vx, y + hauteur, vl)
		"poste": _volet_poste(calque, d, vx, y + hauteur, vl)
	view.director._refresh_controls()

static func _volet(view: Control, d: Dictionary, quoi: String) -> void:
	view.set_meta("menu_joueur_volet", quoi)
	_plus_tard(view, str(d.id))

static func _volet_remplacants_a(view: Control, calque: Control, d: Dictionary, x: float, bas: float, largeur: float, haut: float = 12.0) -> void:
	var liste: Array = d.remplacants
	var hauteur := 64.0 + liste.size() * 56.0 + 14.0
	var y := maxf(haut, bas - hauteur)
	var volet := D.panel(calque, Rect2(x, y, largeur, hauteur), "", "", "", "MatchMenuJoueurRemplacants")
	volet.mouse_filter = Control.MOUSE_FILTER_STOP
	D.text(volet, 20, 42, "%d REMPLAÇANTS" % liste.size(), 22, Charte.IVOIRE, 800, 260).add_theme_font_override("font", Charte.TITRE_EXTRA)
	var colonnes := [16.0, 66.0, 330.0, 410.0, 556.0, 700.0, largeur - 16.0]
	for e: Array in [[colonnes[3], "COND."], [colonnes[4], "MORAL"], [colonnes[5], "AU POSTE"], [largeur - 64.0, "NOTE"]]:
		D.text(volet, float(e[0]), 42, str(e[1]), 14, Charte.IVOIRE_3, 700, 110)
	for i in liste.size():
		_rangee_remplacant(view, volet, Rect2(0, 58 + i * 56.0, largeur, 56), d, liste[i], colonnes, i)

static func _volet_roles(view: Control, calque: Control, d: Dictionary, x: float, bas: float, largeur: float) -> void:
	var roles: Array = d.roles
	var hauteur := 64.0 + roles.size() * 60.0 + 14.0
	var volet := D.panel(calque, Rect2(x, maxf(12.0, bas - hauteur), largeur, hauteur), "", "", "", "MatchMenuJoueurRoles")
	volet.mouse_filter = Control.MOUSE_FILTER_STOP
	D.text(volet, 20, 42, "RÔLES · %s" % POSTES[int(d.numero) - 1].to_upper(), 22, Charte.IVOIRE, 800, 400).add_theme_font_override("font", Charte.TITRE_EXTRA)
	for i in roles.size():
		var r: Dictionary = roles[i]
		var actif: bool = r.id == d.role
		var l := _ligne_cliquable(volet, Rect2(10, 58 + i * 60.0, largeur - 20, 56), "MatchMenuJoueurRole_" + str(r.id), func(): choisir_role(view, d, str(r.id)), Charte.SELECTION if actif else Color.TRANSPARENT)
		if actif: D.rect(l, Rect2(0, 8, 5, 40), Charte.DORE, 2)
		D.text(l, 20, 37, str(r.nom), 21, Charte.IVOIRE, 700, 300)
		_note(l, largeur - 40, 38, float(r.note), 26, "Note")

static func _volet_poste(calque: Control, d: Dictionary, x: float, bas: float, largeur: float) -> void:
	var hauteur := 380.0
	var volet := D.panel(calque, Rect2(x, maxf(12.0, bas - hauteur), largeur, hauteur), "", "", "", "MatchMenuJoueurPostes")
	volet.mouse_filter = Control.MOUSE_FILTER_STOP
	_petit_terrain(volet, Rect2(16, 16, largeur - 32, hauteur - 32), d.joueur, int(d.numero))

# --- Option B : petite fenêtre en lignes façon Effectif -----------------------------------------------------------------

static func _ouvrir_b(view: Control, d: Dictionary) -> void:
	var j: Dictionary = d.joueur
	var liste: Array = d.remplacants
	var largeur := 1720.0
	var hauteur := maxf(800.0, 150.0 + liste.size() * 66.0 + 40.0)
	var fond: Panel = view._ouvrir_fenetre(NOM, "%s · N° %d" % [str(j.get("name", "")).to_upper(), int(d.numero)], largeur, hauteur)
	# Colonne gauche : le joueur.
	_visage(fond, j, Rect2(28, 84, 132, 132), int(d.numero))
	D.text(fond, 180, 112, POSTES[int(d.numero) - 1].to_upper(), 24, Charte.IVOIRE, 800, 300).add_theme_font_override("font", Charte.TITRE_EXTRA)
	Familiarite.poser(fond, 180, 150, int(d.familiarite), 19, "MatchMenuJoueurFamiliarite")
	_note(fond, 500, 154, float(d.note_poste), 34, "MatchMenuJoueurNotePoste")
	_energie(fond, 180, 196, 150, float(d.energie), 20)
	_moral(fond, 180, 208, d.moral, "MatchMenuJoueurMoral")
	var teinte_note: Color = Charte.couleur_note(float(d.note)) if d.note_connue else Charte.IVOIRE_3
	var pn := D.rect(fond, Rect2(436, 172, 64, 34), teinte_note, Charte.RAYON_PETIT)
	D.text(pn, 32, 25, ("%.1f" % float(d.note)).replace(".", ",") if d.note_connue else "—", 20, Charte.encre_note(float(d.note)), 800, 64, HORIZONTAL_ALIGNMENT_CENTER)
	_petit_terrain(fond, Rect2(28, 262, 472, 300), j, int(d.numero))
	# Rôles du poste : trois lignes, un clic choisit.
	var y := 582.0
	for r: Dictionary in d.roles:
		var actif: bool = r.id == d.role
		var rr := r
		var l := _ligne_cliquable(fond, Rect2(28, y, 472, 44), "MatchMenuJoueurRole_" + str(r.id), func(): choisir_role(view, d, str(rr.id)), Charte.SELECTION if actif else Color.TRANSPARENT)
		if actif: D.rect(l, Rect2(0, 6, 5, 32), Charte.DORE, 2)
		D.text(l, 16, 30, str(r.nom), 19, Charte.IVOIRE if actif else Charte.IVOIRE_2, 700, 300)
		_note(l, 460, 31, float(r.note), 22, "Note")
		y += 46.0
	var xc := 28.0
	y += 8.0
	for r: Dictionary in d.responsabilites:
		if xc + Pieces.largeur_pastille(str(r.nom)) > 500: break
		var rr := r
		xc += Pieces.pastille(fond, xc, y, str(r.nom), "check" if r.charge else "", "Resp_" + str(r.id), "", Charte.DORE if r.charge else Charte.IVOIRE_2,
			Charte.VOILE_DORE if r.charge else Charte.PANNEAU_3, func(): choisir_responsabilite(view, d, rr)) + 8.0
	# Colonne droite : remplaçants en lignes, en-têtes cliquables pour trier.
	var x0 := 540.0
	var lw := largeur - x0 - 28.0
	D.rect(fond, Rect2(x0 - 16, 84, 2, hauteur - 120), Charte.FILET)
	D.text(fond, x0, 116, "⇄  REMPLACER PAR", 26, Charte.DORE, 800, 400).add_theme_font_override("font", Charte.TITRE_EXTRA)
	if int(d.restants) >= 0: Pieces.pastille(fond, x0 + lw - Pieces.largeur_pastille("%d restants" % int(d.restants)), 90, "%d restants" % int(d.restants), "", "MatchMenuJoueurRestants")
	var colonnes := [12.0, 62.0, 320.0, 560.0, 730.0, 900.0, lw - 110.0, lw - 12.0]
	var tri := str(view.get_meta("menu_joueur_tri", "note"))
	var tetes := [[colonnes[3], "CONDITION", "energie"], [colonnes[4], "MORAL", "moral"], [colonnes[5], "AU POSTE", "familiarite"], [colonnes[6] - 70.0, "NOTE", "note"], [colonnes[7] - 70.0, "ÉCART", "note"]]
	var entete := D.rect(fond, Rect2(x0, 136, lw, 36), Charte.BANDEAU_ENTETE, Charte.RAYON_PETIT)
	entete.name = "MatchMenuJoueurEntetes"
	for t: Array in tetes:
		var cle := str(t[2])
		var tt := D.rect(entete, Rect2(float(t[0]), 0, 110, 36), Color.TRANSPARENT, Charte.RAYON_PETIT)
		tt.name = "Tri_" + str(t[1]).validate_node_name()
		D.text(tt, 0, 25, str(t[1]) + (" ▼" if cle == tri and str(t[1]) != "ÉCART" else ""), 14, Charte.DORE if cle == tri else Charte.IVOIRE_2, 700, 110)
		Pieces.rendre_cliquable(tt, Vector2(110, 36), func(): _trier(view, cle, str(d.id)), tt.name + "Lien", str(t[1]), "", Charte.RAYON_PETIT)
	var zone := Control.new()
	zone.name = "MatchMenuJoueurRemplacants"
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.add_child(zone)
	D.place(zone, Rect2(x0, 178, lw, liste.size() * 66.0))
	for i in liste.size():
		_rangee_remplacant(view, zone, Rect2(0, i * 66.0, lw, 62), d, liste[i], colonnes, i)

## Petit terrain des 15 postes : pastille numérotée à la couleur de la familiarité du joueur à chaque poste, son poste
## du moment cerclé de doré, la note au poste dessous.
static func _petit_terrain(parent: Control, zone: Rect2, joueur: Dictionary, numero: int) -> void:
	var pelouse := D.rect(parent, zone, Charte.PELOUSE, Charte.RAYON_CARTE)
	pelouse.name = "MatchMenuJoueurTerrain"
	for k in [0.5]: D.line(pelouse, Vector2(0, zone.size.y * k), Vector2(zone.size.x, zone.size.y * k), Color(Charte.CREME, .25), 2)
	for k in [0.22, 0.78]: D.line(pelouse, Vector2(0, zone.size.y * k), Vector2(zone.size.x, zone.size.y * k), Color(Charte.CREME, .12), 2)
	var r := minf(zone.size.x, zone.size.y) * 0.075
	for n in range(1, 16):
		var p: Vector2 = PLACES[n - 1] * zone.size
		var niveau := Familiarite.niveau(joueur, n)
		var t := Familiarite.couleur(niveau)
		if n == numero: D.rect(pelouse, Rect2(p.x - r - 5, p.y - r - 5, 2 * r + 10, 2 * r + 10), Color.TRANSPARENT, Charte.RAYON_PILULE, Charte.DORE).get_theme_stylebox("panel").set_border_width_all(maxi(2, C.px(4)))
		var rond := D.rect(pelouse, Rect2(p.x - r, p.y - r, 2 * r, 2 * r), t, Charte.RAYON_PILULE)
		rond.name = "Poste%d" % n
		rond.tooltip_text = "%d · %s · %s" % [n, POSTES[n - 1], Familiarite.mot(niveau)]
		rond.mouse_filter = Control.MOUSE_FILTER_PASS
		D.text(rond, r, r + 7, str(n), 18, Charte.ENCRE, 800, 2 * r, HORIZONTAL_ALIGNMENT_CENTER)

# --- Carte sortie / entrée sur le terrain ------------------------------------------------------------------------------

## Deux cartes maillot sur le terrain du direct : sortant en rouge (↓), entrant en vert (↑). A : côte à côte en haut
## du terrain ; B : bandeau bas. Elles restent quelques secondes.
static func carte_changement(terrain: Control, sortant: Dictionary, entrant: Dictionary) -> void:
	if terrain == null or not is_instance_valid(terrain): return
	var ancienne := terrain.find_child("MatchChangementCarte", false, false)
	if ancienne != null: ancienne.queue_free()
	var boite := HBoxContainer.new()
	boite.name = "MatchChangementCarte"
	boite.add_theme_constant_override("separation", C.px(14))
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terrain.add_child(boite)
	var b := variante() == "B"
	for k in 2:
		var p: Dictionary = sortant if k == 0 else entrant
		var t := Charte.PERTE if k == 0 else Charte.GAIN
		var carte := PanelContainer.new()
		carte.name = "Sortant" if k == 0 else "Entrant"
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.PANNEAU.lerp(t, .22)
		style.border_color = t
		style.set_border_width_all(maxi(2, C.px(4)))
		style.set_corner_radius_all(C.px(Charte.RAYON_CARTE))
		style.content_margin_left = C.px(16)
		style.content_margin_right = C.px(18)
		style.content_margin_top = C.px(8 if b else 12)
		style.content_margin_bottom = C.px(8 if b else 12)
		Charte.ombrer(style)
		carte.add_theme_stylebox_override("panel", style)
		carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boite.add_child(carte)
		var rang: BoxContainer = HBoxContainer.new() if b else VBoxContainer.new()
		rang.add_theme_constant_override("separation", C.px(10 if b else 2))
		rang.alignment = BoxContainer.ALIGNMENT_CENTER
		rang.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carte.add_child(rang)
		var fl := C.label("▼" if k == 0 else "▲", 26 if b else 22, t, true, 800)
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rang.add_child(fl)
		var maillot := C.label(str(int(p.numero)), 40 if not b else 30, Charte.IVOIRE, true, 800)
		maillot.add_theme_font_override("font", Charte.TITRE_EXTRA)
		maillot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rang.add_child(maillot)
		var nom := C.label(Tableau_nom(str(p.nom)), 22, Charte.IVOIRE, true, 700)
		nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rang.add_child(nom)
		var chiffre := ("%.1f" % float(p.note)).replace(".", ",") if k == 0 else "%d" % roundi(float(p.note_poste))
		var c := C.label(chiffre, 22, Charte.couleur_note(float(p.note)) if k == 0 else Charte.couleur_attribut(float(p.note_poste)), true, 800)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rang.add_child(c)
		var e := C.label("%d %%" % roundi(float(p.energie)), 18, teinte_energie(float(p.energie)), true, 700)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rang.add_child(e)
		if k == 0:
			var fleche := C.label("⇄", 34, Charte.DORE, true, 800)
			fleche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			fleche.mouse_filter = Control.MOUSE_FILTER_IGNORE
			boite.add_child(fleche)
	boite.reset_size()
	var placer := func():
		if not is_instance_valid(boite): return
		boite.reset_size()
		var sz := boite.get_combined_minimum_size()
		boite.size = sz
		# Le terrain du direct est petit : la carte se réduit pour tenir dedans.
		var k := minf(1.0, minf(terrain.size.x * 0.92 / maxf(1.0, sz.x), terrain.size.y * (0.5 if b else 0.86) / maxf(1.0, sz.y)))
		boite.scale = Vector2(k, k)
		boite.position = Vector2((terrain.size.x - sz.x * k) / 2.0, terrain.size.y - sz.y * k - C.px(10) if b else (terrain.size.y - sz.y * k) / 2.0)
	placer.call_deferred()
	terrain.resized.connect(placer)
	terrain.get_tree().create_timer(float(OS.get_environment("CD_CARTE_CHANGEMENT_S")) if OS.get_environment("CD_CARTE_CHANGEMENT_S").is_valid_float() else 6.0, true, false, true).timeout.connect(func():
		if is_instance_valid(boite): boite.queue_free())

## Rouvre le menu à l'image suivante (après une commande ou un choix).
static func _plus_tard(view: Control, id: String) -> void:
	view.get_tree().process_frame.connect(func(): _rouvrir(view, id), CONNECT_ONE_SHOT)

static func _trier(view: Control, cle: String, id: String) -> void:
	view.set_meta("menu_joueur_tri", cle)
	_plus_tard(view, id)

## Poste principal en abrégé (PG, TA, 2L, 3L…) pour la liste étroite de A.
static func _poste_court(joueur: Dictionary) -> String:
	var p: Variant = joueur.get("primaryPositions")
	var n: Variant = (p as Array)[0] if p is Array and not (p as Array).is_empty() else joueur.get("primaryPosition")
	return POSTES_COURTS[int(n) - 1] if (n is int or n is float) and int(n) >= 1 and int(n) <= 15 else str(joueur.get("pos", "")).left(3)
