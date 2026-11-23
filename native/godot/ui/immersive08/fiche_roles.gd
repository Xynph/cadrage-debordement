extends RefCounted
## Fiche joueur : rôles du poste → qualités clés (idée n° 1 de la revue FM27, option A choisie par Léo le 22/11/2026).
## Le moteur ne connaît pas de rôles : cette table rugby (trois rôles par poste) n'est lue que par l'écran. Chaque rôle
## a quatre qualités clés (vert) et quatre utiles (bleu), prises dans les 36 attributs (attributesV2).
## Note du rôle = capacité au rôle : moyenne pondérée (clé × 2, utile × 1) sur 100, colorée avec le barème des
## attributs, la même pour tous les clubs ; à côté, la familiarité au poste du rôle (barres 5 crans, familiarite_poste.gd).
## Qualités inconnues (joueur non observé) : rôles affichés, note « ? ». Terrain : couleur de la familiarité au poste.
## Carte Postes : liste des rôles triée par note (style Effectif), qualités du rôle choisi, terrain des 15 postes
## coloré par familiarité ; un clic sur un rôle surligne ses qualités dans la grille des attributs (bandes).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")
const Carte = preload("res://ui/carte_joueur_survol.gd")
const Roster = preload("res://ui/immersive08/squad_canvas.gd")
const Liste = preload("res://ui/immersive08/liste_etoiles.gd")
const Familiarite = preload("res://ui/familiarite_poste.gd")

const CLE := Charte.CONDITION
const UTILE := Charte.MORAL
const LIGNES_MAX := 6

## Famille de chaque maillot (1 à 15).
const FAMILLE := ["pilier", "talonneur", "pilier", "deuxieme", "deuxieme", "aile", "aile", "huit", "demi", "ouvreur",
	"ailier", "centre", "centre", "ailier", "arriere"]
const POSTE := {"pilier": "Pilier", "talonneur": "Talonneur", "deuxieme": "2e ligne", "aile": "3e ligne aile",
	"huit": "N° 8", "demi": "Demi de mêlée", "ouvreur": "Ouvreur", "ailier": "Ailier", "centre": "Centre", "arriere": "Arrière"}
## [id, famille, nom, [4 qualités clés], [4 qualités utiles]]
const ROLES := [
	["pilier-conquerant", "pilier", "Conquérant", ["scrumTechnique", "strength", "maul", "endurance"], ["lineoutLift", "ruckClearout", "tackling", "discipline"]],
	["pilier-mobile", "pilier", "Mobile", ["ballCarry", "workRate", "tackling", "endurance"], ["offload", "ruckClearout", "receiving", "acceleration"]],
	["pilier-deblayeur", "pilier", "Déblayeur", ["ruckClearout", "strength", "tackling", "workRate"], ["jackal", "maul", "explosiveness", "discipline"]],
	["talon-lanceur", "talonneur", "Lanceur", ["lineoutThrow", "hooking", "scrumTechnique", "composure"], ["maul", "strength", "discipline", "decisions"]],
	["talon-gratteur", "talonneur", "Gratteur", ["jackal", "tackling", "ballCarry", "workRate"], ["acceleration", "offload", "anticipation", "ruckClearout"]],
	["talon-perforateur", "talonneur", "Perforateur", ["ballCarry", "strength", "explosiveness", "offload"], ["hooking", "lineoutThrow", "endurance", "evasion"]],
	["deux-sauteur", "deuxieme", "Sauteur", ["lineoutJump", "jumping", "aerialAbility", "decisions"], ["lineoutLift", "maul", "receiving", "anticipation"]],
	["deux-pousseur", "deuxieme", "Pousseur", ["scrumTechnique", "strength", "ruckClearout", "maul"], ["tackling", "endurance", "lineoutLift", "workRate"]],
	["deux-mobile", "deuxieme", "Mobile", ["workRate", "ballCarry", "tackling", "endurance"], ["offload", "passing", "acceleration", "lineoutJump"]],
	["aile-gratteur", "aile", "Gratteur", ["jackal", "tackling", "anticipation", "workRate"], ["positioning", "ruckClearout", "acceleration", "discipline"]],
	["aile-perforateur", "aile", "Perforateur", ["ballCarry", "explosiveness", "offload", "strength"], ["lineoutJump", "workRate", "evasion", "endurance"]],
	["aile-plaqueur", "aile", "Plaqueur", ["tackling", "workRate", "endurance", "positioning"], ["anticipation", "strength", "ruckClearout", "discipline"]],
	["huit-porteur", "huit", "Porteur", ["ballCarry", "strength", "offload", "explosiveness"], ["scrumTechnique", "ballHandling", "endurance", "evasion"]],
	["huit-liant", "huit", "Liant", ["ballHandling", "decisions", "passing", "vision"], ["teamwork", "lineoutJump", "receiving", "offload"]],
	["huit-meneur", "huit", "Meneur", ["leadership", "decisions", "tackling", "lineoutJump"], ["discipline", "composure", "workRate", "scrumTechnique"]],
	["demi-eclaireur", "demi", "Éclaireur", ["acceleration", "evasion", "anticipation", "ballCarry"], ["passing", "decisions", "agility", "receiving"]],
	["demi-animateur", "demi", "Animateur", ["passing", "decisions", "vision", "teamwork"], ["kickAccuracy", "leadership", "composure", "ballHandling"]],
	["demi-tacticien", "demi", "Tacticien", ["kickDistance", "kickAccuracy", "passing", "decisions"], ["kickChase", "composure", "vision", "positioning"]],
	["ouvreur-stratege", "ouvreur", "Stratège", ["kickDistance", "kickAccuracy", "decisions", "vision"], ["goalAccuracy", "composure", "positioning", "leadership"]],
	["ouvreur-attaquant", "ouvreur", "Attaquant", ["passing", "vision", "evasion", "ballHandling"], ["acceleration", "decisions", "offload", "agility"]],
	["ouvreur-buteur", "ouvreur", "Buteur", ["goalAccuracy", "kickAccuracy", "composure", "kickDistance"], ["decisions", "discipline", "positioning", "passing"]],
	["centre-perceur", "centre", "Perceur", ["ballCarry", "strength", "evasion", "explosiveness"], ["offload", "tackling", "acceleration", "receiving"]],
	["centre-distributeur", "centre", "Distributeur", ["passing", "vision", "ballHandling", "decisions"], ["kickDistance", "receiving", "offload", "tackling"]],
	["centre-verrou", "centre", "Verrou", ["tackling", "positioning", "anticipation", "jackal"], ["workRate", "strength", "decisions", "discipline"]],
	["ailier-finisseur", "ailier", "Finisseur", ["topSpeed", "acceleration", "evasion", "agility"], ["receiving", "ballCarry", "composure", "offload"]],
	["ailier-chasseur", "ailier", "Chasseur", ["kickChase", "aerialAbility", "tackling", "topSpeed"], ["workRate", "positioning", "jumping", "receiving"]],
	["ailier-perforateur", "ailier", "Perforateur", ["ballCarry", "strength", "explosiveness", "evasion"], ["topSpeed", "offload", "receiving", "tackling"]],
	["arriere-relanceur", "arriere", "Relanceur", ["evasion", "topSpeed", "receiving", "vision"], ["passing", "acceleration", "agility", "decisions"]],
	["arriere-rempart", "arriere", "Dernier rempart", ["aerialAbility", "positioning", "tackling", "receiving"], ["kickDistance", "composure", "anticipation", "jumping"]],
	["arriere-botteur", "arriere", "Botteur", ["kickDistance", "kickAccuracy", "aerialAbility", "positioning"], ["goalAccuracy", "decisions", "composure", "kickChase"]],
]

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

## Note du rôle sur 100 (clé × 2, utile × 1) ; -1 si une qualité est inconnue.
static func note_role(values: Dictionary, r: Array) -> float:
	var total := 0.0
	var poids := 0.0
	for k in 2:
		for cle: String in r[3 + k]:
			var v: Variant = values.get(cle)
			if not (v is int or v is float): return -1.0
			total += (2.0 if k == 0 else 1.0) * float(v)
			poids += 2.0 if k == 0 else 1.0
	return total / poids if poids > 0.0 else -1.0

## Maillots du joueur : principaux puis autres postes maîtrisés.
static func numeros(player: Dictionary) -> Array[int]:
	var liste: Array[int] = Roster.primary_numbers(player)
	for n: int in Roster.secondary_numbers(player):
		if not n in liste: liste.append(n)
	return liste

## Rôles des postes du joueur, triés par note (ordre des postes si inconnues) : [{role, note, numero, rang}].
static func roles_joueur(player: Dictionary, values: Dictionary) -> Array:
	var vus := {}
	var liste: Array = []
	var rang := 0
	for n: int in numeros(player):
		for r: Array in roles_famille(FAMILLE[n - 1]):
			if vus.has(r[0]): continue
			vus[r[0]] = true
			liste.append({"role": r, "note": note_role(values, r), "numero": n, "rang": rang})
			rang += 1
	liste.sort_custom(func(a: Dictionary, b: Dictionary): return a.note > b.note or (a.note == b.note and a.rang < b.rang))
	return liste

## Meilleur rôle d'un poste (premier du poste si les qualités sont inconnues).
static func meilleur_role(values: Dictionary, numero: int) -> String:
	var choix := ""
	var meilleur := -2.0
	for r: Array in roles_famille(FAMILLE[numero - 1]):
		var s := note_role(values, r)
		if s > meilleur:
			meilleur = s
			choix = r[0]
	return choix

## Choix de la fiche : {joueur, role, numero}. Par défaut, le meilleur rôle du poste principal.
static func etat(app: Control, player: Dictionary, values: Dictionary) -> Dictionary:
	var id := str(player.get("id", ""))
	var e: Variant = app.management_ui.get("fiche_roles")
	if e is Dictionary and str(e.get("joueur", "")) == id and not role(str(e.get("role", ""))).is_empty(): return e
	var principaux := Roster.primary_numbers(player)
	if principaux.is_empty(): return {"joueur": id, "role": "", "numero": 0}
	return {"joueur": id, "role": meilleur_role(values, principaux[0]), "numero": principaux[0]}

static func choisir(app: Control, player: Dictionary, role_id: String, numero: int) -> void:
	app.management_ui["fiche_roles"] = {"joueur": str(player.get("id", "")), "role": role_id, "numero": numero}
	app._render()

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

## À poser avant la grille : bande verte (clé) ou bleue (utile) derrière chaque qualité du rôle, avec un liseré.
static func bandes(card: Control, origine: Vector2, dimension: Vector2, r: Array) -> void:
	if r.is_empty(): return
	for k in 2:
		var couleur: Color = CLE if k == 0 else UTILE
		for cle: String in r[3 + k]:
			var zone := _ligne(origine, dimension, cle)
			var bande := D.rect(card, zone, Color(couleur, .2), 6)
			bande.name = ("RoleCle_" if k == 0 else "RoleUtile_") + cle
			D.rect(card, Rect2(zone.position.x, zone.position.y, 5, zone.size.y), couleur, 2)

# --- Carte Postes et rôles ---------------------------------------------------------------------------------------

static func _bouton(parent: Control, zone: Rect2, id: String, choisi: bool, action: Callable) -> Button:
	var b := Button.new()
	b.name = id
	b.flat = false
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Ligne choisie : aplat vert franc (charte 5/7) ; les autres restent neutres, survol en panneau clair.
	var fond := Charte.sans_ombre(C.box(Charte.VERT_FRANC if choisi else Color.TRANSPARENT, Color.TRANSPARENT, 6, 0))
	var survol := Charte.sans_ombre(C.box(Charte.VERT_FRANC if choisi else Charte.PANNEAU_2, Color(Charte.CREME, .25), 6, 0))
	for s in ["normal", "pressed", "focus"]: b.add_theme_stylebox_override(s, fond)
	for s in ["hover", "hover_pressed"]: b.add_theme_stylebox_override(s, survol)
	b.pressed.connect(action)
	parent.add_child(b)
	D.place(b, zone)
	return b

static func _qualite(parent: Control, x: float, y: float, cle: String, valeur: Variant, couleur: Color, largeur: float) -> void:
	D.rect(parent, Rect2(x, y - 13, 12, 12), couleur, 6)
	D.text(parent, x + 20, y, libelle(cle), 18, Charte.IVOIRE, 500, largeur - 66, HORIZONTAL_ALIGNMENT_LEFT, true)
	var chiffre := D.text(parent, x + largeur, y, PlayerAttributes.caption(valeur), 20, Charte.couleur_attribut(valeur), 700, 44, HORIZONTAL_ALIGNMENT_RIGHT)
	chiffre.name = "PlayerRoleQuality_" + cle

## Haut de la carte (zone 0-1420 × 60-280) ; la courbe des notes reste dessous.
static func carte(card: Control, app: Control, player: Dictionary, values: Dictionary) -> void:
	var e := etat(app, player, values)
	D.text(card, 24, 86, "RÔLE", 16, Charte.IVOIRE_2, 700, 200)
	D.text(card, 230, 86, "POSTE", 16, Charte.IVOIRE_2, 700, 200)
	D.text(card, 544, 86, "NOTE", 16, Charte.IVOIRE_2, 700, 60, HORIZONTAL_ALIGNMENT_RIGHT)
	D.text(card, 556, 86, "FAMILIARITÉ", 16, Charte.IVOIRE_2, 700, 110)
	# Son rôle : meilleur rôle au poste principal (qualités connues seulement), marqué en permanence.
	var principaux := Roster.primary_numbers(player)
	var son_role := meilleur_role(values, principaux[0]) if not principaux.is_empty() and not values.is_empty() else ""
	var liste := roles_joueur(player, values).slice(0, LIGNES_MAX)
	var y := 92.0
	for item: Dictionary in liste:
		var r: Array = item.role
		var choisi: bool = r[0] == e.role
		var b := _bouton(card, Rect2(16, y, 640, 28), "PlayerRole_" + str(r[0]), choisi, func(): choisir(app, player, str(r[0]), int(item.numero)))
		b.tooltip_text = "%s · %s" % [r[2], POSTE[r[1]]]
		if choisi:
			D.rect(card, Rect2(16, y, 8, 28), CLE, 3).name = "PlayerRoleSelection"
			D.text(card, 30, y + 21, "▶", 16, Charte.CREME, 800, 20).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nom := D.text(card, 50, y + 21, r[2], 20, Charte.CREME if choisi else Charte.IVOIRE_2, 800 if choisi else 500, 175)
		nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(card, 230, y + 21, "%s · %s" % [item.numero, POSTE[r[1]]], 18, Charte.CREME if choisi else Charte.IVOIRE_2, 500, 160).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if r[0] == son_role:
			var pastille := D.rect(card, Rect2(398, y + 4, 92, 20), Charte.CREME, 10)
			pastille.name = "PlayerRoleSien"
			D.text(card, 444, y + 19, "SON RÔLE", 13, Charte.ENCRE, 800, 92, HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Note du rôle sur 100 (barème des attributs, la même pour tous les clubs) puis familiarité au poste du rôle.
		Familiarite.poser_note(card, 500, y + 22, float(item.note), 21, 44, "PlayerRoleNote_" + str(r[0])).tooltip_text = "Note au rôle · %s" % r[2]
		Familiarite.poser(card, 556, y + 20, Familiarite.niveau(player, int(item.numero)), 17, "PlayerRoleFamiliarite_" + str(r[0]))
		y += 29
	var r: Array = role(str(e.role))
	if not r.is_empty():
		D.text(card, 690, 86, "%s · %s" % [str(r[2]).to_upper(), POSTE[r[1]].to_upper()], 16, Charte.IVOIRE_2, 700, 460).name = "PlayerRoleChoisi"
		for k in 2:
			var ligne := 116.0
			for cle: String in r[3 + k]:
				_qualite(card, 690 + k * 262, ligne, cle, values.get(cle), CLE if k == 0 else UTILE, 240)
				ligne += 30
		D.rect(card, Rect2(690, 254, 12, 12), CLE, 6)
		D.text(card, 708, 266, "Clé", 16, CLE, 700, 60)
		D.rect(card, Rect2(952, 254, 12, 12), UTILE, 6)
		D.text(card, 970, 266, "Utile", 16, UTILE, 700, 80)
	_terrain(card, app, player, values, Rect2(1226, 64, 160, 214))

## Terrain des 15 postes coloré par familiarité au poste ; un maillot = son meilleur rôle.
static func _terrain(card: Control, app: Control, player: Dictionary, values: Dictionary, zone: Rect2) -> void:
	var terrain := Carte.MiniTerrain.new()
	terrain.name = "PlayerRolePitch"
	for n in range(1, 16):
		var niveau := Familiarite.niveau(player, n)
		terrain.couleurs.append(Familiarite.couleur(niveau) if niveau >= 0 else null)
	terrain.principaux = Roster.primary_numbers(player)
	card.add_child(terrain)
	D.place(terrain, zone)
	var places: Array = Carte.MiniTerrain.PLACES
	var rayon := minf(zone.size.x * .085, zone.size.y * .055) + 4
	for i in 15:
		var n := i + 1
		var centre := zone.position + Vector2(places[i].x * zone.size.x, places[i].y * zone.size.y)
		var b := _bouton(card, Rect2(centre - Vector2(rayon, rayon), Vector2(rayon, rayon) * 2), "PlayerRolePitchPost%d" % n, false,
			func(): choisir(app, player, meilleur_role(values, n), n))
		var note := Liste.note_poste(player, n)
		b.tooltip_text = "%d · %s · %s · %s" % [n, POSTE[FAMILLE[i]], Familiarite.mot(Familiarite.niveau(player, n)), str(int(note)) if note >= 0.0 else "?"]
