extends RefCounted
## Tactique › Phases arrêtées en combinaisons (idée n° 21 de la revue FM27, planche A/B du 22/11/2026).
## Touche, mêlée, pénalité, renvoi ; attaque ou défense ; plusieurs combinaisons enregistrées par phase. Les joueurs du XV
## sont des pastilles lettrées colorées par groupe (L1, A2, B3…), chacune avec sa consigne.
## Ce qui agit sur le match : le choix pivot de chaque phase d'attaque est traduit vers le carnet du moteur
## (`playbook_set` scrum / lineout / kickoff, effets win/gain/finish de dist/playbook.js). Le reste (nombre de joueurs
## alignés, consigne par joueur, défense, pénalité hors match) est gardé par l'écran seulement : données à ajouter au moteur.
## Option A (CD_VARIANTE_VISUELLE=A) : consignes par groupe à gauche (glisser une consigne d'un groupe à l'autre),
## terrain à droite. Option B : liste des combinaisons à gauche, schéma au centre, étapes et effets à droite.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Selection = preload("res://ui/immersive08/tactics_selection.gd")
const Vertical = preload("res://ui/immersive08/tactics_vertical.gd")
const Rules = preload("res://ui/playbook_view.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")

const HAUT := 196.0
const BAS := 1298.0
const PHASES := [["lineout", "Touche", "flag", Color("4fb3a9")], ["scrum", "Mêlée", "people", Color("e0a04a")],
	["penalty", "Pénalité", "target", Color("d9634f")], ["kickoff", "Renvoi", "ball", Color("5b9bd5")]]
const ATTAQUE := Color("5b9bd5")
const DEFENSE := Color("a88bd6")
## Couleurs des groupes (lettre → couleur franche de la charte).
const GROUPES := {"L": Color("4fb3a9"), "A": Color("e0a04a"), "B": Color("5b9bd5"), "C": Color("a88bd6"), "D": Color("7fbf7a"), "E": Color("d9634f")}

## Pivot de chaque phase : [clé, libellé, [[id, libellé], ...]].
const PIVOTS := {
	"lineout": [["alignement", "Alignement", [["4", "4 joueurs"], ["5", "5 joueurs"], ["7", "7 joueurs"]]],
		["cible", "Sauteur visé", [["devant", "Devant"], ["milieu", "Milieu"], ["fond", "Fond"]]],
		["suite", "Puis", [["maul", "Ballon porté"], ["deploye", "Jeu déployé"], ["ras", "Au ras du 9"]]]],
	"scrum": [["sortie", "Sortie", [["pousser", "Pousser"], ["vite", "Jouer vite"], ["huit", "8 qui part"]]],
		["cote", "Côté", [["ferme", "Fermé"], ["ouvert", "Ouvert"]]]],
	"penalty": [["choix", "Choix", [["touche", "Pied en touche"], ["but", "Au but"], ["rapide", "Jeu rapide"], ["staff", "Selon le score"]]]],
	"kickoff": [["renvoi", "Renvoi", [["normal", "Standard"], ["court", "Court"], ["long", "Long"]]]],
}
const PIVOTS_DEFENSE := {
	"lineout": [["contre", "Contester", [["devant", "Devant"], ["milieu", "Milieu"], ["non", "Ne pas sauter"]]],
		["maul", "Ballon porté", [["stopper", "Stopper"], ["laisser", "Laisser former"]]]],
	"scrum": [["sortie", "Sur leur introduction", [["pousser", "Pousser"], ["stable", "Rester stable"]]]],
	"penalty": [["repli", "Repli", [["vite", "Repli rapide"], ["mur", "Mur sur la ligne"]]]],
	"kickoff": [["reception", "Réception", [["avants", "Avants"], ["profonde", "Profonde"]]]],
}

# --- Données des combinaisons ----------------------------------------------------------------------------------------

## Groupes d'une phase : [{lettre, nom, lignes: [{id, numero, x, y, options: [[id, libellé]], attr, attr_nom}]}].
## Position (x, y) en mètres dans une fenêtre de 40 × 50 m : x depuis la touche, y = 0 vers l'en-but adverse.
static func groupes(phase: String, scenario: String) -> Array:
	if scenario == "defense":
		match phase:
			"lineout": return [
				_g("A", "Contre", [["A1", 4, 6.3, 24.0, [["sauter", "Sauter devant"], ["feinte", "Feinte"]], "lineoutJump", "Saut"], ["A2", 5, 9.9, 24.0, [["sauter", "Sauter au milieu"], ["feinte", "Feinte"]], "lineoutJump", "Saut"]]),
				_g("B", "Soutiens", [["B1", 1, 4.5, 24.0, [["lift", "Soulever"], ["maul", "Contrer le maul"]], "lineoutLift", "Soutien"], ["B2", 3, 8.1, 24.0, [["lift", "Soulever"], ["maul", "Contrer le maul"]], "lineoutLift", "Soutien"], ["B3", 6, 11.7, 24.0, [["maul", "Contrer le maul"], ["chasse", "Monter sur le 9"]], "tackling", "Plaquage"]]),
				_g("C", "Première rideau", [["C1", 7, 15.5, 21.5, [["chasse", "Monter sur le 9"], ["couvrir", "Couvrir le fermé"]], "tackling", "Plaquage"], ["C2", 10, 21, 18, [["monter", "Montée rapide"], ["glisser", "Glisser"]], "tackling", "Plaquage"]]),
				_g("D", "Fond", [["D1", 15, 22, 16, [["fond", "Rester au fond"]], "aerialAbility", "Jeu aérien"]]),
			]
			"scrum": return [
				_g("A", "Première ligne", [["A1", 1, 18.5, 23.5, [["pousser", "Pousser"], ["tenir", "Tenir"]], "scrumTechnique", "Mêlée"], ["A2", 2, 20, 23.5, [["contrer", "Contrer le talonnage"], ["tenir", "Tenir"]], "hooking", "Talonnage"], ["A3", 3, 21.5, 23.5, [["pousser", "Pousser"], ["tenir", "Tenir"]], "scrumTechnique", "Mêlée"]]),
				_g("C", "Troisième ligne", [["C1", 8, 20, 19.8, [["rester", "Rester lié"], ["chasse", "Monter sur le 9"]], "tackling", "Plaquage"], ["C2", 7, 23, 22.2, [["chasse", "Monter sur le 9"], ["couvrir", "Couvrir"]], "tackling", "Plaquage"]]),
				_g("D", "Charnière", [["D1", 9, 24.2, 24.5, [["presser", "Presser le 9"], ["couvrir", "Couvrir"]], "tackling", "Plaquage"]]),
			]
			"penalty": return [
				_g("A", "Mur", [["A1", 1, 17, 14, [["mur", "Tenir la ligne"]], "tackling", "Plaquage"], ["A2", 4, 20, 14, [["mur", "Tenir la ligne"]], "tackling", "Plaquage"], ["A3", 5, 23, 14, [["mur", "Tenir la ligne"]], "tackling", "Plaquage"]]),
				_g("D", "Fond", [["D1", 15, 22, 4, [["fond", "Couvrir le fond"]], "aerialAbility", "Jeu aérien"]]),
			]
			_: return [
				_g("A", "Receveurs", [["A1", 4, 15, 12, [["recevoir", "Recevoir"], ["lift", "Soulever"]], "aerialAbility", "Jeu aérien"], ["A2", 5, 25, 12, [["recevoir", "Recevoir"], ["lift", "Soulever"]], "aerialAbility", "Jeu aérien"]]),
				_g("D", "Fond", [["D1", 15, 20, 4, [["fond", "Couvrir le fond"]], "aerialAbility", "Jeu aérien"]]),
			]
	match phase:
		"lineout": return [
			_g("L", "Lancer", [["L1", 2, 1.4, 25.5, [["sur", "Lancer sûr"], ["normal", "Lancer normal"], ["risque", "Lancer risqué"]], "lineoutThrow", "Lancer"]]),
			_g("A", "Sauteurs", [["A1", 4, 6.3, 25.5, [["sauter", "Sauter"], ["feinte", "Feinte"], ["lift", "Soulever"]], "lineoutJump", "Saut"], ["A2", 5, 9.9, 25.5, [["sauter", "Sauter"], ["feinte", "Feinte"], ["lift", "Soulever"]], "lineoutJump", "Saut"], ["A3", 6, 13.5, 25.5, [["sauter", "Sauter"], ["feinte", "Feinte"], ["lift", "Soulever"]], "lineoutJump", "Saut"]]),
			_g("B", "Soutiens", [["B1", 1, 4.5, 25.5, [["lift", "Soulever"], ["maul", "Lier le maul"]], "lineoutLift", "Soutien"], ["B2", 3, 8.1, 25.5, [["lift", "Soulever"], ["maul", "Lier le maul"]], "lineoutLift", "Soutien"], ["B3", 8, 11.7, 25.5, [["lift", "Soulever"], ["maul", "Lier le maul"], ["relais", "Relais"]], "lineoutLift", "Soutien"]]),
			_g("C", "Après la prise", [["C1", 7, 15.3, 25.5, [["maul", "Pousser le maul"], ["relais", "Relais au 9"], ["percer", "Percée au ras"]], "maul", "Maul"], ["C2", 9, 17, 28.5, [["recevoir", "Recevoir"], ["ras", "Jouer au ras"]], "passing", "Passe"]]),
			_g("D", "Lignes arrières", [["D1", 10, 20.5, 32, [["milieu", "Attaque au milieu"], ["pied", "Jeu au pied"], ["croisee", "Croisée"]], "decisions", "Décisions"], ["D2", 12, 25.5, 35.5, [["percer", "Percée"], ["croisee", "Croisée"], ["fixer", "Fixer"]], "ballCarry", "Porteur"], ["D3", 15, 21, 46, [["intercaler", "S'intercaler"], ["couvrir", "Couvrir"]], "topSpeed", "Vitesse"]]),
		]
		"scrum": return [
			_g("A", "Première ligne", [["A1", 1, 18.5, 26.5, [["pousser", "Pousser"], ["tenir", "Tenir"]], "scrumTechnique", "Mêlée"], ["A2", 2, 20, 26.5, [["talonner", "Talonner vite"], ["pousser", "Pousser"]], "hooking", "Talonnage"], ["A3", 3, 21.5, 26.5, [["pousser", "Pousser"], ["tenir", "Tenir"]], "scrumTechnique", "Mêlée"]]),
			_g("B", "Deuxième ligne", [["B1", 4, 19.2, 28.3, [["pousser", "Pousser"]], "strength", "Force"], ["B2", 5, 20.8, 28.3, [["pousser", "Pousser"]], "strength", "Force"]]),
			_g("C", "Troisième ligne", [["C1", 6, 17, 27.8, [["lier", "Rester lié"], ["fermer", "Fixer le fermé"]], "strength", "Force"], ["C2", 8, 20, 30.2, [["talonner", "Contrôler"], ["partir", "Partir seul"]], "ballCarry", "Porteur"], ["C3", 7, 23, 27.8, [["soutien", "Soutien"], ["lier", "Rester lié"]], "workRate", "Volume"]]),
			_g("D", "Charnière", [["D1", 9, 15.8, 26.3, [["vite", "Sortir vite"], ["attendre", "Attendre la poussée"]], "passing", "Passe"], ["D2", 10, 12.5, 32, [["ouvrir", "Ouvrir"], ["pied", "Jeu au pied"]], "decisions", "Décisions"]]),
		]
		"penalty": return [
			_g("A", "Buteur", [["A1", 10, 20, 25, [["but", "Taper au but"], ["touche", "Taper en touche"]], "goalAccuracy", "But"]]),
			_g("B", "Jeu rapide", [["B1", 9, 19, 26.5, [["taper", "Taper-jouer"], ["attendre", "Attendre"]], "topSpeed", "Vitesse"], ["B2", 8, 22, 28, [["porter", "Porteur"], ["soutien", "Soutien"]], "ballCarry", "Porteur"]]),
			_g("L", "Touche", [["L1", 2, 3, 13, [["sur", "Lancer sûr"], ["maul", "Ballon porté"]], "lineoutThrow", "Lancer"]]),
		]
		_: return [
			_g("A", "Botteur", [["A1", 10, 20, 48, [["normal", "Taper"]], "kickDistance", "Jeu au pied"]]),
			_g("B", "Chasseurs", [["B1", 4, 13, 44, [["chasser", "Chasser"], ["sauter", "Sauter"]], "aerialAbility", "Jeu aérien"], ["B2", 14, 4, 44, [["chasser", "Chasser"]], "topSpeed", "Vitesse"], ["B3", 6, 27, 44, [["chasser", "Chasser"], ["sauter", "Sauter"]], "aerialAbility", "Jeu aérien"]]),
			_g("D", "Couverture", [["D1", 15, 20, 49, [["fond", "Couvrir le fond"]], "aerialAbility", "Jeu aérien"]]),
		]

static func _g(lettre: String, nom: String, lignes: Array) -> Dictionary:
	var sortie: Array = []
	for l: Array in lignes:
		sortie.append({"id": l[0], "numero": l[1], "x": float(l[2]), "y": float(l[3]), "options": l[4], "attr": l[5], "attr_nom": l[6]})
	return {"lettre": lettre, "nom": nom, "lignes": sortie}

## Combinaisons enregistrées par défaut (une liste par phase et par scénario).
static func _defauts(phase: String, scenario: String) -> Array:
	if scenario == "defense":
		match phase:
			"lineout": return [{"nom": "Contre devant", "choix": {"contre": "devant", "maul": "stopper"}}, {"nom": "Laisser lancer", "choix": {"contre": "non", "maul": "stopper"}}]
			"scrum": return [{"nom": "Mêlée solide", "choix": {"sortie": "stable"}}]
			"penalty": return [{"nom": "Repli", "choix": {"repli": "vite"}}]
			_: return [{"nom": "Réception", "choix": {"reception": "avants"}}]
	match phase:
		"lineout": return [{"nom": "Maul des 22", "choix": {"alignement": "7", "cible": "milieu", "suite": "maul"}},
			{"nom": "Touche courte", "choix": {"alignement": "4", "cible": "devant", "suite": "deploye"}},
			{"nom": "Fond pour le 12", "choix": {"alignement": "5", "cible": "fond", "suite": "deploye"}}]
		"scrum": return [{"nom": "Mêlée poussée", "choix": {"sortie": "pousser", "cote": "ferme"}}, {"nom": "Sortie vite", "choix": {"sortie": "vite", "cote": "ouvert"}}]
		"penalty": return [{"nom": "Pénaltouche", "choix": {"choix": "touche"}}, {"nom": "Les points", "choix": {"choix": "but"}}]
		_: return [{"nom": "Renvoi standard", "choix": {"renvoi": "normal"}}, {"nom": "Renvoi court", "choix": {"renvoi": "court"}}]

static func etat(app: Control) -> Dictionary:
	var e: Variant = app.management_ui.get("combinaisons")
	if not e is Dictionary:
		var depart := OS.get_environment("CD_COMBI_PHASE")
		e = {"phase": depart if depart in ["lineout", "scrum", "penalty", "kickoff"] else "lineout", "scenario": "attaque", "listes": {}, "actives": {}}
		app.management_ui.combinaisons = e
	return e

static func _cle(e: Dictionary) -> String:
	return "%s_%s" % [e.phase, e.scenario]

static func liste(app: Control) -> Array:
	var e := etat(app)
	var cle := _cle(e)
	if not e.listes.has(cle):
		e.listes[cle] = _defauts(e.phase, e.scenario)
		e.actives[cle] = _depart(app, e.phase, e.scenario, e.listes[cle])
	return e.listes[cle]

## Combinaison active au départ : celle qui correspond au choix actuel du moteur.
static func _depart(app: Control, phase: String, scenario: String, combos: Array) -> int:
	if scenario != "attaque": return 0
	var choisi := _moteur_actuel(app, phase)
	for i in combos.size():
		if _vers_moteur(phase, combos[i].choix) == choisi: return i
	return 0

static func active(app: Control) -> Dictionary:
	var combos := liste(app)
	var e := etat(app)
	return combos[clampi(int(e.actives.get(_cle(e), 0)), 0, combos.size() - 1)]

static func pivots(app: Control) -> Array:
	var e := etat(app)
	return (PIVOTS_DEFENSE if e.scenario == "defense" else PIVOTS).get(e.phase, [])

static func couleur_phase(phase: String) -> Color:
	for p: Array in PHASES:
		if p[0] == phase: return p[3]
	return Charte.IVOIRE

# --- Lien avec le moteur ---------------------------------------------------------------------------------------------

## Choix du carnet du moteur correspondant aux choix d'une combinaison d'attaque ("" = aucun effet aujourd'hui).
static func _vers_moteur(phase: String, choix: Dictionary) -> String:
	match phase:
		"lineout":
			if str(choix.get("suite", "")) == "maul": return "maul"
			return {"devant": "courte", "fond": "fond"}.get(str(choix.get("cible", "")), "equilibre")
		"scrum": return {"pousser": "pousser", "vite": "securiser"}.get(str(choix.get("sortie", "")), "equilibre")
		"kickoff": return str(choix.get("renvoi", "normal"))
	return ""

static func _moteur_actuel(app: Control, phase: String) -> String:
	for p: Dictionary in app.model.get("clubLife", {}).get("playbook", {}).get("setPieces", []):
		if str(p.get("key", "")) == phase: return str(p.get("selected", ""))
	return ""

## Effets réels du moteur (dist/playbook.js setPieceEffects, kickoffPolicy) : [libellé, valeur, unité].
static func effets(phase: String, scenario: String, choix: Dictionary) -> Array:
	if scenario != "attaque": return []
	var m := _vers_moteur(phase, choix)
	match phase:
		"lineout", "scrum":
			var table := {"equilibre": [0, 0, 0], "securiser": [2.5, -2, -3], "pousser": [-4, 4, 4], "courte": [4, -3, -3], "fond": [-5, 5, 4], "maul": [-2.5, 2, 5]}
			var v: Array = table.get(m, [0, 0, 0])
			return [["Conquête", v[0], "%"], ["Mètres", v[1], "m"], ["Essai", v[2], "%"]]
		"kickoff":
			var r := {"normal": [0, 0], "court": [12, -12], "long": [-5, 12]}
			var k: Array = r.get(m, [0, 0])
			return [["Récupération", k[0], "%"], ["Territoire", k[1], "m"]]
	return []

## Le moteur lit-il ce pivot aujourd'hui ?
static func pivot_agit(phase: String, scenario: String, cle: String) -> bool:
	if scenario != "attaque": return false
	return (phase == "lineout" and cle in ["cible", "suite"]) or (phase == "scrum" and cle == "sortie") or (phase == "kickoff" and cle == "renvoi")

static func _appliquer(app: Control) -> void:
	var e := etat(app)
	if e.scenario != "attaque": return
	var m := _vers_moteur(e.phase, active(app).choix)
	var carnet: Dictionary = app.model.get("clubLife", {}).get("playbook", {})
	if m.is_empty() or not bool(carnet.get("available", false)) or bool(app.get("waiting")): app._render(); return
	if m != _moteur_actuel(app, e.phase): Rules._choose(app, e.phase, m)
	else: app._render()

static func choisir_phase(app: Control, phase: String) -> void:
	etat(app).phase = phase
	app._render()

static func choisir_scenario(app: Control, scenario: String) -> void:
	etat(app).scenario = scenario
	app._render()

static func choisir_combo(app: Control, index: int) -> void:
	var e := etat(app)
	e.actives[_cle(e)] = index
	_appliquer(app)

static func ajouter_combo(app: Control) -> void:
	var combos := liste(app)
	var copie: Dictionary = active(app).duplicate(true)
	copie.nom = "Combinaison %d" % (combos.size() + 1)
	combos.append(copie)
	choisir_combo(app, combos.size() - 1)

static func choisir_pivot(app: Control, cle: String, valeur: String) -> void:
	active(app).choix[cle] = valeur
	_appliquer(app)

static func consigne(app: Control, ligne: Dictionary) -> String:
	var c: Variant = active(app).get("lignes", {})
	if c is Dictionary and c.has(ligne.id): return str(c[ligne.id])
	return str(ligne.options[0][0])

static func choisir_consigne(app: Control, id: String, valeur: String) -> void:
	var combo := active(app)
	if not combo.get("lignes") is Dictionary: combo.lignes = {}
	combo.lignes[id] = valeur
	app._render()

## Groupe d'une ligne (glisser d'un groupe à l'autre) : lettre d'origine par défaut.
static func groupe_de(app: Control, ligne_id: String) -> String:
	var g: Variant = active(app).get("groupes", {})
	if g is Dictionary and g.has(ligne_id): return str(g[ligne_id])
	return ligne_id.left(1)

static func deplacer(app: Control, ligne_id: String, lettre: String) -> void:
	var combo := active(app)
	if not combo.get("groupes") is Dictionary: combo.groupes = {}
	combo.groupes[ligne_id] = lettre
	app._render()

## Groupes réorganisés selon les glisser : {lettre: [lignes]} dans l'ordre des groupes d'origine.
static func lignes_par_groupe(app: Control) -> Array:
	var e := etat(app)
	var base := groupes(e.phase, e.scenario)
	var sortie: Array = []
	for g: Dictionary in base: sortie.append({"lettre": g.lettre, "nom": g.nom, "lignes": []})
	for g: Dictionary in base:
		for l: Dictionary in g.lignes:
			var cible := groupe_de(app, l.id)
			for s: Dictionary in sortie:
				if s.lettre == cible: s.lignes.append(l)
	return sortie

## Lignes visibles : en touche, l'alignement retire les joueurs en trop (4 = sans B3/A3/C1 ; 5 = sans B3/C1).
static func visible(app: Control, ligne: Dictionary) -> bool:
	var e := etat(app)
	if e.phase != "lineout" or e.scenario != "attaque": return true
	var n := str(active(app).choix.get("alignement", "7"))
	if n == "4": return not ligne.id in ["A3", "B3", "C1"]
	if n == "5": return not ligne.id in ["B3", "C1"]
	return true

# --- Joueurs ---------------------------------------------------------------------------------------------------------

static func joueur(app: Control, numero: int) -> Dictionary:
	return Selection.occupant(app.model, numero - 1)

static func valeur(p: Dictionary, attr: String) -> Variant:
	var v: Dictionary = PlayerAttributes.detail(p, true)
	return v.get(attr)

static func libelle_option(ligne: Dictionary, id: String) -> String:
	for o: Array in ligne.options:
		if o[0] == id: return o[1]
	return str(ligne.options[0][1])

# --- Pièces communes aux deux options --------------------------------------------------------------------------------

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

## Puce d'effet ▲/▼ (vert/rouge), « = » neutre.
static func puce_effet(parent: Control, x: float, y: float, e: Array, id: String) -> float:
	var v := float(e[1])
	var signe := "▲" if v > 0 else ("▼" if v < 0 else "=")
	var couleur := Charte.GAIN if v > 0 else (Charte.PERTE if v < 0 else Charte.IVOIRE_2)
	var texte := "%s %s %s%s" % [str(e[0]), signe, str(absf(v)).trim_suffix(".0").replace(".", ","), " " + str(e[2]) if v != 0 else ""]
	return Pieces.pastille(parent, x, y, texte if v != 0 else "%s =" % str(e[0]), "", id, "", couleur)

## Petite fenêtre des consignes d'une ligne : une tuile par consigne, la retenue en couleur.
static func fenetre_consigne(app: Control, page: Control, ligne: Dictionary, couleur: Color) -> void:
	var p := joueur(app, int(ligne.numero))
	var n: int = ligne.options.size()
	var largeur := maxf(620.0, 40 + n * 250.0)
	var fond := Fenetre.ouvrir(page, "CombiFenetre", "%s · %s" % [ligne.id, Kit.casse(str(p.get("name", "N° %d" % ligne.numero)), true).to_upper()], "", largeur, 300)
	var actuelle := consigne(app, ligne)
	for i in n:
		var o: Array = ligne.options[i]
		var rect := Rect2(28 + i * 250, 100, 234, 150)
		var oui := str(o[0]) == actuelle
		var tuile := D.rect(fond, rect, Color(couleur, .22) if oui else Charte.PANNEAU_2, Charte.RAYON_CARTE, couleur if oui else Color.TRANSPARENT)
		tuile.name = "CombiOption_" + str(o[0])
		jeton(tuile, Vector2(40, 44), ligne.id, couleur, 22)
		D.text(tuile, 20, 110, str(o[1]), 22, couleur if oui else Charte.IVOIRE, 700, 200)
		var id_ := str(ligne.id)
		var valeur_ := str(o[0])
		Pieces.rendre_cliquable(tuile, rect.size, func():
			Fenetre.fermer(page, "CombiFenetre")
			choisir_consigne(app, id_, valeur_), "CombiOption_%s_%s" % [ligne.id, o[0]], str(o[1]), "", Charte.RAYON_CARTE)

## Fenêtre des combinaisons enregistrées (choisir, ajouter).
static func fenetre_combos(app: Control, page: Control) -> void:
	var combos := liste(app)
	var e := etat(app)
	var couleur := couleur_phase(e.phase)
	var fond := Fenetre.ouvrir(page, "CombiListe", "COMBINAISONS", "", 640, 150 + (combos.size() + 1) * 70)
	var actif := int(e.actives.get(_cle(e), 0))
	for i in combos.size() + 1:
		var rect := Rect2(28, 96 + i * 70, 584, 60)
		var ligne := D.rect(fond, rect, Charte.PANNEAU_3 if i == actif else Charte.PANNEAU_2, Charte.RAYON_PETIT)
		ligne.name = "CombiListe_%d" % i
		if i < combos.size():
			Kit.puce(ligne, Rect2(14, 15, 34, 30), str(i + 1), couleur, Charte.ENCRE)
			D.text(ligne, 64, 39, str(combos[i].nom), 22, couleur if i == actif else Charte.IVOIRE, 700, 380)
			var index := i
			Pieces.rendre_cliquable(ligne, rect.size, func():
				Fenetre.fermer(page, "CombiListe")
				choisir_combo(app, index), "CombiListeChoix%d" % i, str(combos[i].nom), "", Charte.RAYON_PETIT)
		else:
			D.text(ligne, 64, 39, "+  Nouvelle", 22, Charte.IVOIRE_2, 700, 380)
			Pieces.rendre_cliquable(ligne, rect.size, func():
				Fenetre.fermer(page, "CombiListe")
				ajouter_combo(app), "CombiListeNouvelle", "Nouvelle", "", Charte.RAYON_PETIT)

# --- Schéma (pelouse et pastilles) -----------------------------------------------------------------------------------

## Pelouse zoomée sur la phase (fenêtre de 40 × 50 m), adversaires en ronds sombres, flèches du choix.
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
	var points: Array = []  ## [{x, y, couleur}]

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
		match phase:
			"lineout":
				draw_line(m(0, 0), m(0, 50), Color(1, 1, 1, .9), e * 2.5)
				draw_dashed_line(m(5, 0), m(5, 50), craie, e, size.y * .02)
				draw_dashed_line(m(15, 0), m(15, 50), craie, e, size.y * .02)
				for k in 7: draw_circle(m(4.5 + k * 1.8, 24.0 if scenario == "attaque" else 25.5), r, eux)
				if scenario == "attaque":
					var cible := {"devant": 6.3, "milieu": 9.9, "fond": 13.5}.get(str(choix.get("cible", "milieu")), 11.0) as float
					_fleche(m(1.6, 25.2), m(cible, 25.0), accent, e * 2.2, -size.x * .05)
					match str(choix.get("suite", "")):
						"maul": _fleche(m(cible, 27.5), m(cible + 1, 17), Color(Charte.IVOIRE, .9), e * 3)
						"ras": _fleche(m(17, 29.5), m(18.5, 19), Color(Charte.IVOIRE, .9), e * 2.4)
						_: _fleche(m(17.6, 29.2), m(25, 34.5), Color(Charte.IVOIRE, .9), e * 2.4, size.x * .03)
				else:
					draw_circle(m(1.4, 25.5), r, eux)
			"scrum":
				draw_line(m(20, 4), m(20, 46), Color(1, 1, 1, .25), e)
				for p in [Vector2(18.5, 23.5), Vector2(20, 23.5), Vector2(21.5, 23.5), Vector2(19.2, 21.7), Vector2(20.8, 21.7), Vector2(17, 22.2), Vector2(23, 22.2), Vector2(20, 19.8)]:
					if scenario == "attaque": draw_circle(m(p.x, p.y), r, eux)
				if scenario == "defense":
					for p in [Vector2(18.5, 26.5), Vector2(20, 26.5), Vector2(21.5, 26.5), Vector2(19.2, 28.3), Vector2(20.8, 28.3), Vector2(17, 27.8), Vector2(23, 27.8), Vector2(20, 30.2), Vector2(15.8, 26.3)]:
						draw_circle(m(p.x, p.y), r, eux)
				if scenario == "attaque":
					match str(choix.get("sortie", "")):
						"pousser": _fleche(m(20, 33), m(20, 18), accent, e * 4)
						"huit": _fleche(m(20, 31.2), m(23.0 if str(choix.get("cote", "ferme")) == "ferme" else 16.0, 19), accent, e * 3)
						_: _fleche(m(15.8, 27.2), m(13, 31), accent, e * 3)
			"penalty":
				draw_line(m(0, 2), m(40, 2), Color(1, 1, 1, .9), e * 2)
				draw_line(m(0, 0), m(0, 50), Color(1, 1, 1, .9), e * 2.5)
				draw_line(m(0, 24), m(40, 24), craie, e)
				draw_line(m(18.5, 2), m(18.5, -4), Color.WHITE, e * 2)
				draw_line(m(21.5, 2), m(21.5, -4), Color.WHITE, e * 2)
				draw_line(m(18.5, 1), m(21.5, 1), Color.WHITE, e * 2)
				draw_circle(m(20, 24.5), r * .8, Charte.IVOIRE)
				for k in 6: draw_circle(m(14 + k * 2.4, 14), r, eux)
				if scenario == "attaque":
					match str(choix.get("choix", "")):
						"but": _fleche(m(20, 24), m(20, 3), accent, e * 3)
						"touche": _fleche(m(20, 24), m(1.5, 13.5), accent, e * 3, size.x * .04)
						"rapide":
							_fleche(m(19, 26), m(17, 16), accent, e * 3)
							_fleche(m(22, 28), m(24, 16), Color(Charte.IVOIRE, .9), e * 2.4)
						_:
							_fleche(m(20, 24), m(20, 3), Color(accent, .5), e * 2)
							_fleche(m(20, 24), m(1.5, 13.5), Color(accent, .5), e * 2, size.x * .04)
			_:
				draw_line(m(0, 25), m(40, 25), Color(1, 1, 1, .9), e * 2)
				draw_dashed_line(m(0, 15), m(40, 15), craie, e, size.y * .02)
				var portee := {"court": Vector2(10, 14), "long": Vector2(25, 35)}.get(str(choix.get("renvoi", "")), Vector2(10, 22)) as Vector2
				if scenario == "attaque":
					draw_rect(Rect2(m(2, 25 - portee.y), m(36, portee.y - portee.x)), Color(accent, .3))
					_fleche(m(20, 47), m(20, 25 - (portee.x + portee.y) / 2.0), accent, e * 3, size.x * .06)
				for k in 5: draw_circle(m(6 + k * 7, 8 + (k % 2) * 4), r, eux)
