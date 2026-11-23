extends RefCounted
## Tactique › Phases arrêtées en combinaisons (idée n° 21 de la revue FM27, choix B de Léo du 23/11/2026).
## Touche, mêlée, pénalité, renvoi ; attaque ou défense ; plusieurs combinaisons enregistrées par phase (sauvegarde,
## `manager.playbook.combos`), une active. Tout vient du moteur (`clubLife.playbook.combinaisons`, native/engine/playbook.cjs) :
## listes, choix et effets réels sur le match (dist/playbook.js). Un clic sur une combinaison ou un choix l'applique aussitôt
## (`playbook_combo`), avant le match ou en pause.
## Ici : données, commandes, rôles « qui fait quoi » et schéma de la phase ; la mise en page est dans tactics_combinaisons_vues.gd.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Selection = preload("res://ui/immersive08/tactics_selection.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")

const PHASES := [["lineout", "Touche", "flag", Color("4fb3a9")], ["scrum", "Mêlée", "people", Color("e0a04a")],
	["penalty", "Pénalité", "target", Color("d9634f")], ["kickoff", "Renvoi", "ball", Color("5b9bd5")]]
const ATTAQUE := Color("5b9bd5")
const DEFENSE := Color("a88bd6")
## Couleurs des groupes (lettre → couleur franche de la charte).
const GROUPES := {"L": Color("4fb3a9"), "A": Color("e0a04a"), "B": Color("5b9bd5"), "C": Color("a88bd6"), "D": Color("7fbf7a"), "E": Color("d9634f")}
## Couleur d'un choix de pénalité (schéma et pastilles).
const COULEURS_PENALITE := {"staff": Color("c9c2b4"), "poteaux": Color("e8c547"), "touche": Color("4fb3a9"), "melee": Color("e0a04a"), "main": Color("d9634f")}

# --- Données (lues dans le moteur) -----------------------------------------------------------------------------------

static func carnet(app: Control) -> Dictionary:
	return app.model.get("clubLife", {}).get("playbook", {})

static func etat(app: Control) -> Dictionary:
	var e: Variant = app.management_ui.get("combinaisons")
	if not e is Dictionary:
		var depart := OS.get_environment("CD_COMBI_PHASE")
		e = {"phase": depart if depart in ["lineout", "scrum", "penalty", "kickoff"] else "lineout", "scenario": "attaque"}
		app.management_ui.combinaisons = e
	return e

static func cle(app: Control) -> String:
	var e := etat(app)
	return "%s_%s" % [e.phase, e.scenario]

static func donnees(app: Control) -> Dictionary:
	var toutes: Variant = carnet(app).get("combinaisons", {})
	if not toutes is Dictionary: return {}
	var d: Variant = toutes.get(cle(app), {})
	return d if d is Dictionary else {}

static func liste(app: Control) -> Array:
	return donnees(app).get("liste", [])

static func index_actif(app: Control) -> int:
	return int(donnees(app).get("active", 0))

static func active(app: Control) -> Dictionary:
	var l := liste(app)
	if l.is_empty(): return {"nom": "", "choix": {}, "effets": []}
	return l[clampi(index_actif(app), 0, l.size() - 1)]

static func pivots(app: Control) -> Array:
	return donnees(app).get("pivots", [])

## Les choix s'appliquent-ils maintenant (avant le match, ou match en pause) ?
static func modifiable(app: Control) -> bool:
	return bool(carnet(app).get("available", false)) and not bool(app.get("waiting"))

static func couleur_phase(phase: String) -> Color:
	for p: Array in PHASES:
		if p[0] == phase: return p[3]
	return Charte.IVOIRE

static func libelle_choix(pivot: Dictionary, valeur: String) -> String:
	for o: Dictionary in pivot.get("options", []):
		if str(o.get("id", "")) == valeur: return str(o.get("label", valeur))
	return valeur

# --- Commandes (un clic = appliqué) ----------------------------------------------------------------------------------

static func _commande(app: Control, payload: Dictionary) -> void:
	if not modifiable(app): return
	payload.context = carnet(app).get("context", {}).duplicate(true)
	payload.cle = cle(app)
	app._command("playbook_combo", payload)

static func choisir_phase(app: Control, phase: String) -> void:
	etat(app).phase = phase
	app._render()

static func choisir_scenario(app: Control, scenario: String) -> void:
	etat(app).scenario = scenario
	app._render()

static func choisir_combo(app: Control, index: int) -> void:
	if index == index_actif(app): return
	_commande(app, {"action": "choisir", "index": index})

static func ajouter_combo(app: Control) -> void:
	_commande(app, {"action": "ajouter"})

static func choisir_pivot(app: Control, pivot: String, valeur: String) -> void:
	if str(active(app).get("choix", {}).get(pivot, "")) == valeur: return
	_commande(app, {"action": "pivot", "pivot": pivot, "valeur": valeur})

# --- Joueurs et rôles (qui fait quoi) --------------------------------------------------------------------------------

## Groupes d'une phase : [{lettre, nom, lignes: [{id, numero, x, y, attr, attr_nom}]}].
## Position (x, y) en mètres dans une fenêtre de 40 × 50 m : x depuis la touche, y = 0 vers l'en-but adverse.
static func groupes(phase: String, scenario: String) -> Array:
	if scenario == "defense":
		match phase:
			"lineout": return [
				_g("A", "Contre", [["A1", 4, 6.3, 24.0, "lineoutJump", "Saut"], ["A2", 5, 9.9, 24.0, "lineoutJump", "Saut"]]),
				_g("B", "Soutiens", [["B1", 1, 4.5, 24.0, "lineoutLift", "Soutien"], ["B2", 3, 8.1, 24.0, "lineoutLift", "Soutien"], ["B3", 6, 11.7, 24.0, "tackling", "Plaquage"]]),
				_g("C", "Premier rideau", [["C1", 7, 15.5, 21.5, "tackling", "Plaquage"], ["C2", 10, 21, 18, "tackling", "Plaquage"]]),
				_g("D", "Fond", [["D1", 15, 22, 16, "aerialAbility", "Jeu aérien"]]),
			]
			"scrum": return [
				_g("A", "Première ligne", [["A1", 1, 18.5, 23.5, "scrumTechnique", "Mêlée"], ["A2", 2, 20, 23.5, "hooking", "Talonnage"], ["A3", 3, 21.5, 23.5, "scrumTechnique", "Mêlée"]]),
				_g("C", "Troisième ligne", [["C1", 8, 20, 19.8, "tackling", "Plaquage"], ["C2", 7, 23, 22.2, "tackling", "Plaquage"]]),
				_g("D", "Charnière", [["D1", 9, 24.2, 24.5, "tackling", "Plaquage"]]),
			]
			"penalty": return [
				_g("A", "Mur", [["A1", 1, 17, 14, "tackling", "Plaquage"], ["A2", 4, 20, 14, "tackling", "Plaquage"], ["A3", 5, 23, 14, "tackling", "Plaquage"]]),
				_g("C", "Repli", [["C1", 9, 12, 12, "topSpeed", "Vitesse"], ["C2", 7, 28, 12, "tackling", "Plaquage"]]),
				_g("D", "Fond", [["D1", 15, 22, 4, "aerialAbility", "Jeu aérien"]]),
			]
			_: return [
				_g("A", "Receveurs", [["A1", 4, 15, 12, "aerialAbility", "Jeu aérien"], ["A2", 5, 25, 12, "aerialAbility", "Jeu aérien"]]),
				_g("D", "Fond", [["D1", 15, 20, 4, "aerialAbility", "Jeu aérien"]]),
			]
	match phase:
		"lineout": return [
			_g("L", "Lancer", [["L1", 2, 1.4, 25.5, "lineoutThrow", "Lancer"]]),
			_g("A", "Sauteurs", [["A1", 4, 6.3, 25.5, "lineoutJump", "Saut"], ["A2", 5, 9.9, 25.5, "lineoutJump", "Saut"], ["A3", 6, 13.5, 25.5, "lineoutJump", "Saut"]]),
			_g("B", "Soutiens", [["B1", 1, 4.5, 25.5, "lineoutLift", "Soutien"], ["B2", 3, 8.1, 25.5, "lineoutLift", "Soutien"], ["B3", 8, 11.7, 25.5, "lineoutLift", "Soutien"]]),
			_g("C", "Après la prise", [["C1", 7, 15.3, 25.5, "maul", "Maul"], ["C2", 9, 17, 28.5, "passing", "Passe"]]),
			_g("D", "Lignes arrières", [["D1", 10, 20.5, 32, "decisions", "Décisions"], ["D2", 12, 25.5, 35.5, "ballCarry", "Porteur"], ["D3", 15, 21, 46, "topSpeed", "Vitesse"]]),
		]
		"scrum": return [
			_g("A", "Première ligne", [["A1", 1, 18.5, 26.5, "scrumTechnique", "Mêlée"], ["A2", 2, 20, 26.5, "hooking", "Talonnage"], ["A3", 3, 21.5, 26.5, "scrumTechnique", "Mêlée"]]),
			_g("B", "Deuxième ligne", [["B1", 4, 19.2, 28.3, "strength", "Force"], ["B2", 5, 20.8, 28.3, "strength", "Force"]]),
			_g("C", "Troisième ligne", [["C1", 6, 17, 27.8, "strength", "Force"], ["C2", 8, 20, 30.2, "ballCarry", "Porteur"], ["C3", 7, 23, 27.8, "workRate", "Volume"]]),
			_g("D", "Charnière", [["D1", 9, 15.8, 26.3, "passing", "Passe"], ["D2", 10, 12.5, 32, "decisions", "Décisions"]]),
		]
		"penalty": return [
			_g("A", "Buteur", [["A1", 10, 20, 25, "goalAccuracy", "But"]]),
			_g("B", "Jeu rapide", [["B1", 9, 19, 26.5, "topSpeed", "Vitesse"], ["B2", 8, 22, 28, "ballCarry", "Porteur"]]),
			_g("L", "Touche", [["L1", 2, 3, 13, "lineoutThrow", "Lancer"]]),
		]
		_: return [
			_g("A", "Botteur", [["A1", 10, 20, 48, "kickDistance", "Jeu au pied"]]),
			_g("B", "Chasseurs", [["B1", 4, 13, 44, "aerialAbility", "Jeu aérien"], ["B2", 14, 4, 44, "topSpeed", "Vitesse"], ["B3", 6, 27, 44, "aerialAbility", "Jeu aérien"]]),
			_g("D", "Couverture", [["D1", 15, 20, 49, "aerialAbility", "Jeu aérien"]]),
		]

static func _g(lettre: String, nom: String, lignes: Array) -> Dictionary:
	var sortie: Array = []
	for l: Array in lignes:
		sortie.append({"id": l[0], "numero": l[1], "x": float(l[2]), "y": float(l[3]), "attr": l[4], "attr_nom": l[5]})
	return {"lettre": lettre, "nom": nom, "lignes": sortie}

## Rôle d'un joueur, déduit des choix de la combinaison active (lecture seule).
static func role(phase: String, scenario: String, choix: Dictionary, ligne: Dictionary) -> String:
	var id := str(ligne.id)
	if scenario == "defense":
		match phase:
			"lineout":
				var contre := str(choix.get("contre", "lire"))
				if id.begins_with("A"): return "Contrer le maul" if contre == "maul" else ("Sauter devant" if contre == "devant" and id == "A1" else ("Sauter au fond" if contre == "fond" and id == "A2" else "Lire le lancer"))
				if id.begins_with("B"): return "Contrer le maul"
				return "Monter sur le 9" if id == "C1" else ("Rester au fond" if id == "D1" else "Défendre")
			"scrum":
				if id.begins_with("A"): return "Pousser" if str(choix.get("poussee", "")) == "pousser" else "Tenir"
				return "Monter sur le 9" if id in ["C2", "D1"] else "Rester lié"
			"penalty":
				var repli := str(choix.get("repli", "normal"))
				if id.begins_with("A"): return "Mur sur la ligne" if repli == "mur" else "Tenir la ligne"
				if id.begins_with("C"): return "Repli rapide" if repli == "vite" else "Se replacer"
				return "Couvrir le fond"
			_:
				var reception := str(choix.get("reception", "standard"))
				if id.begins_with("A"): return "Devant" if reception == "avants" else ("Au fond" if reception == "profonde" else "Recevoir")
				return "Couvrir le fond"
	match phase:
		"lineout":
			var cible := {"devant": "A1", "milieu": "A2", "fond": "A3"}.get(str(choix.get("cible", "milieu")), "A2") as String
			var suite := str(choix.get("suite", "deploye"))
			if id == "L1": return "Lancer"
			if id.begins_with("A"): return "Sauter" if id == cible else "Feinte"
			if id.begins_with("B"): return "Lier le maul" if suite == "maul" else "Soulever"
			if id == "C1": return "Pousser le maul" if suite == "maul" else ("Percée au ras" if suite == "ras" else "Relais au 9")
			if id == "C2": return "Au ras" if suite == "ras" else "Recevoir"
			if id == "D1": return "Attaque au milieu" if suite == "deploye" else "Fixer"
			if id == "D2": return "Percée" if suite == "deploye" else "Fixer"
			return "S'intercaler" if suite == "deploye" else "Couvrir"
		"scrum":
			var sortie := str(choix.get("sortie", "equilibre"))
			if id.begins_with("A") or id.begins_with("B"): return "Pousser" if sortie == "pousser" else ("Talonner vite" if id == "A2" and sortie == "vite" else "Tenir")
			if id == "C2": return "Partir seul" if sortie == "huit" else "Contrôler"
			if id.begins_with("C"): return "Soutien du 8" if sortie == "huit" else "Rester lié"
			if id == "D1": return "Sortir vite" if sortie == "vite" else "Attendre la poussée"
			return "Côté fermé" if str(choix.get("cote", "ouvert")) == "ferme" else "Ouvrir"
		"penalty":
			if id == "A1": return "Buteur"
			if id.begins_with("B"): return "Taper-jouer" if id == "B1" else "Porteur"
			return "Lancer"
		_:
			var renvoi := str(choix.get("renvoi", "normal"))
			if id == "A1": return "Court" if renvoi == "court" else ("Long" if renvoi == "long" else "Taper")
			if id == "D1": return "Couvrir le fond"
			return "Sauter" if renvoi == "court" and id in ["B1", "B3"] else "Chasser"

## Lignes visibles : en touche, l'alignement retire les joueurs en trop (4 = sans B3/A3/C1 ; 5 = sans B3/C1).
static func visible(app: Control, ligne: Dictionary) -> bool:
	var e := etat(app)
	if e.phase != "lineout" or e.scenario != "attaque": return true
	var n := str(active(app).get("choix", {}).get("alignement", "7"))
	if n == "4": return not ligne.id in ["A3", "B3", "C1"]
	if n == "5": return not ligne.id in ["B3", "C1"]
	return true

static func joueur(app: Control, numero: int) -> Dictionary:
	return Selection.occupant(app.model, numero - 1)

static func valeur(p: Dictionary, attr: String) -> Variant:
	var v: Dictionary = PlayerAttributes.detail(p, true)
	return v.get(attr)

static func ouvrir_joueur(app: Control, p: Dictionary) -> void:
	var id := str(p.get("id", ""))
	if not id.is_empty(): app.navigation_controller.open_entity({"kind": "player", "id": id})

# --- Pièces communes -------------------------------------------------------------------------------------------------

## Segment de pilules (choix exclusif) ; renvoie la largeur posée.
static func segments(parent: Control, x: float, y: float, options: Array, choisi: String, couleur: Color, id: String, action: Callable, h: float = 44, taille: int = 19) -> float:
	var depart := x
	for o: Array in options:
		var w := Kit.largeur(str(o[1]), taille) + 34
		var b := Button.new()
		b.name = "%s_%s" % [id, str(o[0])]
		var oui := str(o[0]) == choisi
		var fond := couleur if oui else Charte.PANNEAU_3
		var normal := C.box(fond, Color.TRANSPARENT, Charte.RAYON_PILULE, 0)
		Charte.sans_ombre(normal)
		var survol := C.box(fond.lightened(.12) if oui else Color(couleur, .28), Color.TRANSPARENT, Charte.RAYON_PILULE, 0)
		Charte.sans_ombre(survol)
		for etat_ in ["normal", "pressed", "disabled", "focus"]: b.add_theme_stylebox_override(etat_, normal)
		b.add_theme_stylebox_override("hover", survol)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.accessibility_name = str(o[1])
		var valeur_ := str(o[0])
		b.pressed.connect(func(): action.call(valeur_))
		parent.add_child(b)
		D.place(b, Rect2(x, y, w, h))
		var t := D.text(b, w / 2.0, h / 2.0 + 7, str(o[1]), taille, Charte.ENCRE if oui else Charte.IVOIRE, 700, w, HORIZONTAL_ALIGNMENT_CENTER)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		x += w + 8
	return x - depart - 8

## Pastille lettrée d'un groupe (A1, L1…).
static func jeton(parent: Control, centre: Vector2, texte: String, couleur: Color, r: float = 21) -> Panel:
	var rond := D.rect(parent, Rect2(centre - Vector2(r, r), Vector2(r, r) * 2), couleur, Charte.RAYON_PILULE)
	rond.name = "Jeton_" + texte
	var t := D.text(rond, r, r + 7, texte, 18 if r >= 18 else 15, Charte.ENCRE, 800, r * 2, HORIZONTAL_ALIGNMENT_CENTER)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rond

## Un effet est-il favorable ? [libellé, valeur, unité, sens] : sens 1 = plus est mieux, −1 = moins est mieux.
static func favorable(ef: Array) -> int:
	var v := float(ef[1]) * (float(ef[3]) if ef.size() > 3 else 1.0)
	return 0 if is_zero_approx(v) else (1 if v > 0 else -1)

# --- Schéma (pelouse et pastilles) -----------------------------------------------------------------------------------

## Fenêtre de terrain (mètres) montrée pour chaque phase : touche et mêlée zoomées, pénalité et renvoi plus larges.
static func fenetre(phase: String) -> Rect2:
	match phase:
		"lineout": return Rect2(0, 14, 30, 37.5)
		"scrum": return Rect2(8, 15, 24, 30)
	return Rect2(0, 0, 40, 50)

class Schema extends Control:
	var cadre_m := Rect2(0, 0, 40, 50)
	var phase := "lineout"
	var scenario := "attaque"
	var choix := {}
	var accent := Color.WHITE

	func m(x: float, y: float) -> Vector2:
		return Vector2((x - cadre_m.position.x) / cadre_m.size.x * size.x, (y - cadre_m.position.y) / cadre_m.size.y * size.y)

	func _fleche(a: Vector2, b: Vector2, couleur: Color, e: float, courbe: float = 0.0) -> void:
		var pts := PackedVector2Array()
		var n := Vector2(-(b - a).y, (b - a).x).normalized()
		for k in 17:
			var t := k / 16.0
			pts.append(a.lerp(b, t) + n * sin(t * PI) * courbe)
		for k in 16: draw_line(pts[k], pts[k + 1], couleur, e, true)
		var d := (pts[16] - pts[14]).normalized()
		var p := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([b + d * e * 2, b - d * e * 3 + p * e * 2.4, b - d * e * 3 - p * e * 2.4]), couleur)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Charte.PELOUSE)
		for k in 6:
			if k % 2 == 0: draw_rect(Rect2(m(0, k * 10), m(40, (k + 1) * 10) - m(0, k * 10)), Charte.PELOUSE_2)
		var craie := Color(1, 1, 1, .55)
		var e := maxf(1.5, size.x * .003)
		var r := size.x * .016
		var eux := Color(Charte.NOIR_PANNEAU, .85)
		var clair := Color(Charte.IVOIRE, .9)
		match phase:
			"lineout":
				draw_line(m(0, 0), m(0, 50), Color(1, 1, 1, .9), e * 2.5)
				draw_dashed_line(m(5, 0), m(5, 50), craie, e, size.y * .02)
				draw_dashed_line(m(15, 0), m(15, 50), craie, e, size.y * .02)
				for k in 7: draw_circle(m(4.5 + k * 1.8, 24.0 if scenario == "attaque" else 25.5), r, eux)
				if scenario == "attaque":
					var cible := {"devant": 6.3, "milieu": 9.9, "fond": 13.5}.get(str(choix.get("cible", "milieu")), 9.9) as float
					_fleche(m(1.6, 25.2), m(cible, 25.0), accent, e * 2.2, -size.x * .05)
					match str(choix.get("suite", "")):
						"maul": _fleche(m(cible, 27.5), m(cible + 1, 17), clair, e * 3)
						"ras": _fleche(m(17, 29.5), m(18.5, 19), clair, e * 2.4)
						_: _fleche(m(17.6, 29.2), m(25, 34.5), clair, e * 2.4, size.x * .03)
				else:
					draw_circle(m(1.4, 25.5), r, eux)
					match str(choix.get("contre", "lire")):
						"devant": _fleche(m(6.3, 22), m(6.3, 26.5), accent, e * 3)
						"fond": _fleche(m(9.9, 22), m(12.5, 26.5), accent, e * 3)
						"maul":
							for k in 3: _fleche(m(5 + k * 2.5, 21), m(6 + k * 2.5, 25), accent, e * 2.4)
			"scrum":
				draw_line(m(20, 4), m(20, 46), Color(1, 1, 1, .25), e)
				if scenario == "attaque":
					for p in [Vector2(18.5, 23.5), Vector2(20, 23.5), Vector2(21.5, 23.5), Vector2(19.2, 21.7), Vector2(20.8, 21.7), Vector2(17, 22.2), Vector2(23, 22.2), Vector2(20, 19.8)]:
						draw_circle(m(p.x, p.y), r, eux)
					var ferme := str(choix.get("cote", "ouvert")) == "ferme"
					match str(choix.get("sortie", "")):
						"pousser": _fleche(m(20, 33), m(20, 18), accent, e * 4)
						"huit": _fleche(m(20, 31.2), m(23.5 if ferme else 15.5, 19), accent, e * 3)
						"vite": _fleche(m(15.8, 27.2), m(12, 32) if not ferme else m(25, 31), accent, e * 3)
						_: _fleche(m(15.8, 27.2), m(13, 31) if not ferme else m(24, 30), Color(accent, .7), e * 2.4)
				else:
					for p in [Vector2(18.5, 26.5), Vector2(20, 26.5), Vector2(21.5, 26.5), Vector2(19.2, 28.3), Vector2(20.8, 28.3), Vector2(17, 27.8), Vector2(23, 27.8), Vector2(20, 30.2), Vector2(15.8, 26.3)]:
						draw_circle(m(p.x, p.y), r, eux)
					if str(choix.get("poussee", "")) == "pousser": _fleche(m(20, 18), m(20, 25), accent, e * 4)
			"penalty":
				draw_line(m(0, 2), m(40, 2), Color(1, 1, 1, .9), e * 2)
				draw_line(m(0, 0), m(0, 50), Color(1, 1, 1, .9), e * 2.5)
				draw_line(m(18.5, 2), m(18.5, -4), Color.WHITE, e * 2)
				draw_line(m(21.5, 2), m(21.5, -4), Color.WHITE, e * 2)
				draw_line(m(18.5, 1), m(21.5, 1), Color.WHITE, e * 2)
				if scenario == "attaque":
					# Trois bandes : dans leurs 22, à portée (22-40 m), loin ; une flèche par choix.
					var bandes := [["pres", 2.0, 24.0], ["portee", 24.0, 42.0], ["loin", 42.0, 50.0]]
					for k in bandes.size():
						var bande: Array = bandes[k]
						var v := str(choix.get(bande[0], "staff"))
						var couleur: Color = COULEURS_PENALITE.get(v, clair)
						draw_rect(Rect2(m(1, bande[1]), m(39, bande[2]) - m(1, bande[1])), Color(couleur, .24))
						draw_line(m(0, bande[2]), m(40, bande[2]), craie, e)
						# Point de la pénalité à droite de la bande (les joueurs sont au centre), une flèche courte par choix.
						var milieu: float = (float(bande[1]) + float(bande[2])) / 2.0
						var depart := m(31, milieu)
						draw_circle(depart, r * .55, Charte.IVOIRE)
						match v:
							"poteaux": _fleche(depart, m(22.5, maxf(4.0, milieu - 12.0)), couleur, e * 3)
							"touche": _fleche(depart, m(1.5, milieu - 5.0), couleur, e * 3, size.x * .02)
							"melee":
								for p in [Vector2(-1.5, -2.2), Vector2(0, -2.2), Vector2(1.5, -2.2), Vector2(-.8, -.6), Vector2(.8, -.6)]: draw_circle(depart + m(p.x, p.y) - m(0, 0), r * .8, couleur)
							"main": _fleche(depart, m(31, milieu - 6.0), couleur, e * 3)
							_:
								_fleche(depart, m(27, milieu - 5.0), Color(couleur, .8), e * 2)
								_fleche(depart, m(35, milieu - 5.0), Color(couleur, .8), e * 2)
				else:
					draw_circle(m(20, 24.5), r * .8, Charte.IVOIRE)
					for k in 3: draw_circle(m(17 + k * 3, 26), r, eux)
					match str(choix.get("repli", "normal")):
						"vite": draw_dashed_line(m(4, 14.5), m(36, 14.5), accent, e * 3, size.y * .02)
						"mur": draw_line(m(8, 6), m(32, 6), accent, e * 4)
						_: draw_dashed_line(m(4, 14.5), m(36, 14.5), Color(clair, .5), e * 2, size.y * .02)
			_:
				draw_line(m(0, 25), m(40, 25), Color(1, 1, 1, .9), e * 2)
				draw_dashed_line(m(0, 15), m(40, 15), craie, e, size.y * .02)
				if scenario == "attaque":
					var portee := {"court": Vector2(10, 14), "long": Vector2(18, 26)}.get(str(choix.get("renvoi", "")), Vector2(15, 25)) as Vector2
					draw_rect(Rect2(m(2, 25 - portee.y), m(36, 25 - portee.x) - m(2, 25 - portee.y)), Color(accent, .3))
					_fleche(m(20, 47), m(20, 25 - (portee.x + portee.y) / 2.0), accent, e * 3, size.x * .06)
					for k in 5: draw_circle(m(6 + k * 7, 8 + (k % 2) * 4), r, eux)
				else:
					# Leur renvoi part de la médiane (y = 25) vers nous ; bande de réception selon le choix.
					var zone := {"avants": Vector2(9, 16), "profonde": Vector2(0.5, 7)}.get(str(choix.get("reception", "")), Vector2(3, 14)) as Vector2
					draw_rect(Rect2(m(2, zone.x), m(38, zone.y) - m(2, zone.x)), Color(accent, .28))
					for k in 4: draw_circle(m(8 + k * 8, 28 + (k % 2) * 3), r, eux)
