extends RefCounted
## Fiche joueur : rôles du poste → qualités clés (idée n° 1 de la revue FM27, 22/11/2026, planche A/B).
## Le moteur ne connaît pas de rôles : cette table, petite et rugby, est une proposition (deux rôles par poste),
## lue seulement par l'écran. Chaque rôle a trois qualités clés (vert) et trois utiles (bleu), prises dans les 36
## attributs (attributesV2). Étoiles du rôle = capacité au rôle : moyenne pondérée (clé × 2, utile × 1) sur 100,
## ramenée sur 5 par demi-étoile (40 → 0, 85 → 5). Pas de rôle si le staff ne connaît pas ses attributs.
## Variante sous CD_VARIANTE_VISUELLE : A = liste des rôles triée + terrain coloré, bandes pleines dans la grille ;
## B = terrain cliquable (choix du poste) puis rôles en lignes avec leurs qualités en pastilles, grille estompée.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")
const Carte = preload("res://ui/carte_joueur_survol.gd")
const Roster = preload("res://ui/immersive08/squad_canvas.gd")

const CLE := Charte.CONDITION
const UTILE := Charte.MORAL

## Famille de chaque maillot (1 à 15).
const FAMILLE := ["pilier", "talonneur", "pilier", "deuxieme", "deuxieme", "aile", "aile", "huit", "demi", "ouvreur",
	"ailier", "centre", "centre", "ailier", "arriere"]
const POSTE := {"pilier": "Pilier", "talonneur": "Talonneur", "deuxieme": "2e ligne", "aile": "3e ligne aile",
	"huit": "N° 8", "demi": "Demi de mêlée", "ouvreur": "Ouvreur", "ailier": "Ailier", "centre": "Centre", "arriere": "Arrière"}
## [id, famille, nom, [3 qualités clés], [3 qualités utiles]]
const ROLES := [
	["pilier-conquete", "pilier", "Conquérant", ["scrumTechnique", "strength", "maul"], ["endurance", "lineoutLift", "ruckClearout"]],
	["pilier-mobile", "pilier", "Mobile", ["ballCarry", "workRate", "tackling"], ["offload", "endurance", "ruckClearout"]],
	["talon-lanceur", "talonneur", "Lanceur", ["lineoutThrow", "hooking", "scrumTechnique"], ["maul", "composure", "strength"]],
	["talon-gratteur", "talonneur", "Gratteur", ["jackal", "tackling", "ballCarry"], ["workRate", "acceleration", "offload"]],
	["deux-sauteur", "deuxieme", "Sauteur", ["lineoutJump", "jumping", "aerialAbility"], ["lineoutLift", "maul", "decisions"]],
	["deux-pousseur", "deuxieme", "Pousseur", ["scrumTechnique", "strength", "ruckClearout"], ["maul", "tackling", "endurance"]],
	["aile-gratteur", "aile", "Gratteur", ["jackal", "tackling", "anticipation"], ["workRate", "positioning", "ruckClearout"]],
	["aile-perforateur", "aile", "Perforateur", ["ballCarry", "explosiveness", "offload"], ["strength", "lineoutJump", "workRate"]],
	["huit-porteur", "huit", "Porteur", ["ballCarry", "strength", "offload"], ["explosiveness", "scrumTechnique", "ballHandling"]],
	["huit-liant", "huit", "Liant", ["ballHandling", "decisions", "passing"], ["vision", "teamwork", "lineoutJump"]],
	["demi-eclaireur", "demi", "Éclaireur", ["acceleration", "evasion", "anticipation"], ["ballCarry", "passing", "decisions"]],
	["demi-animateur", "demi", "Animateur", ["passing", "decisions", "vision"], ["kickAccuracy", "teamwork", "leadership"]],
	["ouvreur-stratege", "ouvreur", "Stratège", ["kickDistance", "kickAccuracy", "decisions"], ["goalAccuracy", "composure", "positioning"]],
	["ouvreur-attaquant", "ouvreur", "Attaquant", ["passing", "vision", "evasion"], ["ballHandling", "acceleration", "decisions"]],
	["centre-perceur", "centre", "Perceur", ["ballCarry", "strength", "evasion"], ["offload", "explosiveness", "tackling"]],
	["centre-distributeur", "centre", "Distributeur", ["passing", "vision", "ballHandling"], ["decisions", "kickDistance", "tackling"]],
	["ailier-finisseur", "ailier", "Finisseur", ["topSpeed", "acceleration", "evasion"], ["receiving", "agility", "ballCarry"]],
	["ailier-chasseur", "ailier", "Chasseur", ["kickChase", "aerialAbility", "tackling"], ["workRate", "topSpeed", "positioning"]],
	["arriere-relanceur", "arriere", "Relanceur", ["evasion", "topSpeed", "receiving"], ["vision", "passing", "acceleration"]],
	["arriere-rempart", "arriere", "Dernier rempart", ["aerialAbility", "kickDistance", "positioning"], ["tackling", "receiving", "composure"]],
]

static func variante() -> String:
	return "B" if OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper() == "B" else "A"

static func role(id: String) -> Array:
	for r: Array in ROLES:
		if r[0] == id: return r
	return []

static func roles_famille(famille: String) -> Array:
	return ROLES.filter(func(r: Array): return r[1] == famille)

static func libelle(cle: String) -> String:
	for groupe: Array in PlayerAttributes.GROUPS:
		for pair: Array in groupe[1]:
			if pair[0] == cle: return str(pair[1])
	return cle

## Note du rôle sur 100 (clé × 2, utile × 1) ; -1 si un attribut manque.
static func note_role(values: Dictionary, r: Array) -> float:
	var total := 0.0
	for k: String in r[3]:
		var v: Variant = values.get(k)
		if not (v is int or v is float): return -1.0
		total += 2.0 * float(v)
	for k: String in r[4]:
		var v: Variant = values.get(k)
		if not (v is int or v is float): return -1.0
		total += float(v)
	return total / 9.0

static func etoiles_role(values: Dictionary, r: Array) -> float:
	var note := note_role(values, r)
	if note < 0.0: return -1.0
	return clampf(roundf((note - 40.0) / 9.0 * 2.0) / 2.0, 0.0, 5.0)

## Maillots du joueur : principaux puis autres postes maîtrisés.
static func numeros(player: Dictionary) -> Array[int]:
	var liste: Array[int] = Roster.primary_numbers(player)
	for n: int in Roster.secondary_numbers(player):
		if not n in liste: liste.append(n)
	return liste

## Rôles des postes du joueur, triés par étoiles : [{role, etoiles, numero}].
static func roles_joueur(player: Dictionary, values: Dictionary) -> Array:
	var vus := {}
	var liste: Array = []
	for n: int in numeros(player):
		for r: Array in roles_famille(FAMILLE[n - 1]):
			if vus.has(r[0]): continue
			vus[r[0]] = true
			liste.append({"role": r, "etoiles": etoiles_role(values, r), "numero": n, "principal": n in Roster.primary_numbers(player)})
	liste.sort_custom(func(a: Dictionary, b: Dictionary): return a.etoiles > b.etoiles or (a.etoiles == b.etoiles and a.numero < b.numero))
	return liste

## État de la fiche : {joueur, role, numero}. Remis à zéro quand on change de joueur.
static func etat(app: Control, player: Dictionary, values: Dictionary) -> Dictionary:
	var id := str(player.get("id", ""))
	var e: Variant = app.management_ui.get("fiche_roles")
	if e is Dictionary and str(e.get("joueur", "")) == id and not role(str(e.get("role", ""))).is_empty(): return e
	var principaux := Roster.primary_numbers(player)
	var numero := principaux[0] if not principaux.is_empty() else 0
	var choix := ""
	var meilleur := -2.0
	if numero > 0:
		for r: Array in roles_famille(FAMILLE[numero - 1]):
			var s := etoiles_role(values, r)
			if s > meilleur:
				meilleur = s
				choix = r[0]
	return {"joueur": id, "role": choix, "numero": numero}

static func choisir(app: Control, player: Dictionary, role_id: String, numero: int) -> void:
	app.management_ui["fiche_roles"] = {"joueur": str(player.get("id", "")), "role": role_id, "numero": numero}
	app._render()

static func choisir_poste(app: Control, player: Dictionary, values: Dictionary, numero: int) -> void:
	var choix := ""
	var meilleur := -2.0
	for r: Array in roles_famille(FAMILLE[numero - 1]):
		var s := etoiles_role(values, r)
		if s > meilleur:
			meilleur = s
			choix = r[0]
	choisir(app, player, choix, numero)

# --- Grille des attributs ----------------------------------------------------------------------------------------

## Géométrie de Commune.grille_attributs (valeurs par défaut) : rectangle de la ligne de `cle`.
static func _ligne(origine: Vector2, dimension: Vector2, cle: String) -> Rect2:
	var ecart := 28.0
	var colonne := (dimension.x - ecart * 3.0) / 4.0
	for i in PlayerAttributes.GROUPS.size():
		var entries: Array = PlayerAttributes.GROUPS[i][1]
		for j in entries.size():
			if entries[j][0] == cle:
				var y := origine.y + 20 + 10 + 33.0 * (j + 1) - 33.0 * .28
				return Rect2(origine.x + i * (colonne + ecart) - 10, y - 25, colonne + 20, 32)
	return Rect2()

## Avant la grille (variante A) : bande pleine verte (clé) ou bleue (utile) derrière chaque ligne, avec un liseré.
static func bandes(card: Control, origine: Vector2, dimension: Vector2, r: Array) -> void:
	if r.is_empty() or variante() != "A": return
	for k in 2:
		var couleur: Color = CLE if k == 0 else UTILE
		for cle: String in r[3 + k]:
			var zone := _ligne(origine, dimension, cle)
			var bande := D.rect(card, zone, Color(couleur, .2), 6)
			bande.name = ("RoleCle_" if k == 0 else "RoleUtile_") + cle
			D.rect(card, Rect2(zone.position.x, zone.position.y, 5, zone.size.y), couleur, 2)

## Après la grille (variante B) : tout le reste s'estompe ; libellés clés en vert, utiles en bleu, pastille devant.
static func estomper(card: Control, origine: Vector2, dimension: Vector2, prefixe: String, r: Array) -> void:
	if r.is_empty() or variante() != "B": return
	var garder := {}
	for cle: String in r[3]: garder[cle] = CLE
	for cle: String in r[4]: garder[cle] = UTILE
	for groupe: Array in PlayerAttributes.GROUPS:
		for pair: Array in groupe[1]:
			var cle: String = pair[0]
			var chiffre := card.get_node_or_null(prefixe + cle) as Label
			var zone := _ligne(origine, dimension, cle)
			if garder.has(cle):
				var pastille := D.rect(card, Rect2(zone.position.x - 4, zone.position.y + 9, 14, 14), garder[cle], 7)
				pastille.name = ("RoleCle_" if garder[cle] == CLE else "RoleUtile_") + cle
				for enfant in card.get_children():
					if enfant is Label and (enfant as Label).text == str(pair[1]): (enfant as Label).add_theme_color_override("font_color", garder[cle])
			else:
				if chiffre: chiffre.modulate = Color(1, 1, 1, .3)
				for enfant in card.get_children():
					if enfant is Label and (enfant as Label).text == str(pair[1]): (enfant as Label).modulate = Color(1, 1, 1, .3)

# --- Carte Postes ------------------------------------------------------------------------------------------------

static func _bouton(parent: Control, zone: Rect2, id: String, choisi: bool, action: Callable) -> Button:
	var b := Button.new()
	b.name = id
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var fond := C.box(Charte.SELECTION if choisi else Color.TRANSPARENT, Color.TRANSPARENT, 6, 0)
	Charte.sans_ombre(fond)
	var survol := C.box(Charte.PANNEAU_2 if not choisi else Charte.SELECTION, Color(Charte.CREME, .25), 6, 0)
	Charte.sans_ombre(survol)
	for s in ["normal", "pressed", "focus"]: b.add_theme_stylebox_override(s, fond)
	for s in ["hover", "hover_pressed"]: b.add_theme_stylebox_override(s, survol)
	b.pressed.connect(action)
	parent.add_child(b)
	D.place(b, zone)
	return b

## Terrain coloré (étoiles au poste) ; chaque maillot cliquable.
static func _terrain(card: Control, app: Control, player: Dictionary, values: Dictionary, zone: Rect2, choisi: int) -> void:
	var terrain := Carte.MiniTerrain.new()
	terrain.name = "PlayerRolePitch"
	for n in range(1, 16): terrain.etoiles.append(Carte.etoiles_poste(player, n))
	terrain.principaux = Roster.primary_numbers(player)
	card.add_child(terrain)
	D.place(terrain, zone)
	var places: Array = Carte.MiniTerrain.PLACES
	var r := minf(zone.size.x * .085, zone.size.y * .055) + 4
	for i in 15:
		var centre := zone.position + Vector2(places[i].x * zone.size.x, places[i].y * zone.size.y)
		var n := i + 1
		var b := _bouton(card, Rect2(centre - Vector2(r, r), Vector2(r, r) * 2), "PlayerRolePitchPost%d" % n, false, func(): choisir_poste(app, player, values, n))
		b.tooltip_text = "%d · %s" % [n, POSTE[FAMILLE[i]]]
		if n == choisi and variante() == "B":
			var anneau := D.rect(card, Rect2(centre - Vector2(r + 3, r + 3), Vector2(r + 3, r + 3) * 2), Color.TRANSPARENT, int(r + 3), Charte.DORE)
			anneau.name = "PlayerRolePitchChoisi"

static func _etoiles(parent: Control, zone: Rect2, valeur: float, nom: String) -> void:
	if valeur < 0.0:
		D.text(parent, zone.position.x, zone.position.y + zone.size.y - 2, "—", 20, Charte.IVOIRE_3, 700, 40)
		return
	Carte.poser_etoiles(parent, zone, valeur, nom)

static func _qualite(parent: Control, x: float, y: float, cle: String, valeur: Variant, couleur: Color, largeur: float) -> void:
	D.rect(parent, Rect2(x, y - 13, 12, 12), couleur, 6)
	D.text(parent, x + 20, y, libelle(cle), 18, Charte.IVOIRE, 500, largeur - 70, HORIZONTAL_ALIGNMENT_LEFT, true)
	D.text(parent, x + largeur, y, PlayerAttributes.caption(valeur), 20, Charte.couleur_attribut(valeur), 700, 44, HORIZONTAL_ALIGNMENT_RIGHT)

## Haut de la carte Postes (zone 0-1420 × 60-275). Le reste (courbe des notes) est inchangé.
static func carte(card: Control, app: Control, player: Dictionary, values: Dictionary) -> void:
	var e := etat(app, player, values)
	if variante() == "B": _carte_b(card, app, player, values, e)
	else: _carte_a(card, app, player, values, e)

## A : liste des rôles (style Effectif) triée par étoiles, qualités du rôle choisi, terrain coloré à droite.
static func _carte_a(card: Control, app: Control, player: Dictionary, values: Dictionary, e: Dictionary) -> void:
	D.text(card, 24, 86, "RÔLE", 16, Charte.IVOIRE_2, 700, 200)
	D.text(card, 250, 86, "POSTE", 16, Charte.IVOIRE_2, 700, 200)
	D.text(card, 470, 86, "CAPACITÉ", 16, Charte.IVOIRE_2, 700, 200)
	var liste := roles_joueur(player, values).slice(0, 5)
	var y := 94.0
	for item: Dictionary in liste:
		var r: Array = item.role
		var choisi: bool = r[0] == e.role
		var b := _bouton(card, Rect2(16, y, 640, 34), "PlayerRole_" + str(r[0]), choisi, func(): choisir(app, player, str(r[0]), int(item.numero)))
		b.tooltip_text = str(r[2])
		if choisi: D.rect(card, Rect2(16, y, 5, 34), Charte.CREME, 2)
		var nom := D.text(card, 30, y + 25, r[2], 21, Charte.CREME if choisi else Charte.IVOIRE, 700 if choisi else 600, 210)
		nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(card, 250, y + 25, "%s · %s" % [item.numero, POSTE[r[1]]], 19, Charte.IVOIRE_2, 500, 210).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_etoiles(card, Rect2(470, y + 7, 130, 22), item.etoiles, "PlayerRoleStars_" + str(r[0]))
		y += 36
	var r: Array = role(str(e.role))
	if not r.is_empty():
		D.text(card, 690, 86, str(r[2]).to_upper(), 16, Charte.IVOIRE_2, 700, 360)
		var ligne := 116.0
		for k in 2:
			for cle: String in r[3 + k]:
				_qualite(card, 690, ligne, cle, values.get(cle), CLE if k == 0 else UTILE, 340)
				ligne += 27
		D.rect(card, Rect2(690, 270 - 12, 12, 12), CLE, 6)
		D.text(card, 708, 270, "Clé", 16, CLE, 700, 60)
		D.rect(card, Rect2(770, 270 - 12, 12, 12), UTILE, 6)
		D.text(card, 788, 270, "Utile", 16, UTILE, 700, 80)
	_terrain(card, app, player, values, Rect2(1170, 64, 160, 214), int(e.numero))

## B : terrain cliquable à gauche (choix du poste), puis les rôles de ce poste en lignes avec leurs qualités en pastilles.
static func _carte_b(card: Control, app: Control, player: Dictionary, values: Dictionary, e: Dictionary) -> void:
	_terrain(card, app, player, values, Rect2(24, 64, 160, 214), int(e.numero))
	var numero := int(e.numero)
	if numero <= 0: return
	var famille: String = FAMILLE[numero - 1]
	D.text(card, 214, 92, "%d · %s" % [numero, POSTE[famille].to_upper()], 24, Charte.CREME, 800, 500).name = "PlayerRolePoste"
	_etoiles(card, Rect2(520, 74, 130, 22), Carte.etoiles_poste(player, numero), "PlayerRolePosteStars")
	var y := 108.0
	for r: Array in roles_famille(famille):
		var choisi: bool = r[0] == e.role
		var b := _bouton(card, Rect2(204, y, 1192, 78), "PlayerRole_" + str(r[0]), choisi, func(): choisir(app, player, str(r[0]), numero))
		b.tooltip_text = str(r[2])
		if choisi: D.rect(card, Rect2(204, y, 5, 78), Charte.CREME, 2)
		D.text(card, 222, y + 32, r[2], 23, Charte.CREME if choisi else Charte.IVOIRE, 700, 230).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_etoiles(card, Rect2(222, y + 44, 130, 22), etoiles_role(values, r), "PlayerRoleStars_" + str(r[0]))
		var x := 470.0
		for k in 2:
			var couleur: Color = CLE if k == 0 else UTILE
			for cle: String in r[3 + k]:
				var ligne := y + (24.0 if k == 0 else 60.0)
				var mot := libelle(cle)
				var valeur: Variant = values.get(cle)
				var police := C.font(600)
				var large := police.get_string_size(mot, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(17))).x / C.density + 64
				var px := x + 0.0
				D.rect(card, Rect2(px, ligne - 18, large, 28), Color(couleur, .22), 14)
				D.text(card, px + 12, ligne + 2, mot, 17, couleur, 600, large - 50).mouse_filter = Control.MOUSE_FILTER_IGNORE
				D.text(card, px + large - 10, ligne + 2, PlayerAttributes.caption(valeur), 18, Charte.couleur_attribut(valeur), 800, 40, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
				x += large + 10
			x = 470.0
		y += 84
