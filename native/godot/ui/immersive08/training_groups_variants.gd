extends RefCounted
## Entraînement › Groupes : options visuelles A (barres empilées) et B (anneaux). PROVISOIRE : choisies par la variable
## d'environnement CD_VARIANTE_VISUELLE=A|B (revue du 21/11/2026, n° 6) ; absente, l'écran garde sa forme actuelle.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const R = preload("res://ui/repartition_trois_parts.gd")
const ICONES := {"proteger": "shield", "relever": "star", "equilibrer": "train"}

static func variante() -> String:
	return OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()

static func parts(plan: Dictionary) -> Array:
	var n: Dictionary = plan.get("counts", {})
	return [
		{"n": int(n.get("repos", 0)), "couleur": C.Charte.VERT_CLAIR, "encre": C.Charte.PANNEAU, "motif": R.MOTIF_DIAGONALE, "mot": "récupération"},
		{"n": int(n.get("normal", 0)) + int(n.get("collective", 0)), "couleur": C.Charte.VERT_FRANC, "encre": C.Charte.CREME, "motif": R.MOTIF_AUCUN, "mot": "normal ou collectif"},
		{"n": int(n.get("intense", 0)), "couleur": C.Charte.CREME, "encre": C.Charte.PANNEAU, "motif": R.MOTIF_POINTS, "mot": "intensif"},
	]

static func phrase(parent: Node, x: float, baseline: float, valeur: String, taille: int, largeur: float, lignes: int) -> Label:
	var etiquette := D.text(parent, x, baseline, valeur, taille, C.IVORY, 500, largeur)
	etiquette.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiquette.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	etiquette.size.y = C.font(500).get_height(maxi(12, C.px(taille))) * lignes * 1.12
	return etiquette

static func build(canvas: Control, section: Panel, plans: Array, disponible: bool, choix: String) -> void:
	var largeur := (1740.0 - 2.0 * 23.0 - 2.0 * 22.0) / 3.0
	var haut := 84.0
	var hauteur_tuile := 610.0 if choix == "A" else 690.0
	if choix == "B":
		# La photo reste, voilée, derrière les tuiles.
		D.photo(section, canvas.photo_centre(canvas.app.model), Rect2(18, 66, 1704, haut + hauteur_tuile + 24 - 66))
		D.rect(section, Rect2(18, 66, 1704, haut + hauteur_tuile + 24 - 66), Color(C.Charte.PANNEAU, 0.66))
	for i in plans.size():
		var plan: Dictionary = plans[i]
		var x := 23.0 + i * (largeur + 22.0)
		var cle := str(plan.get("key", ""))
		var icone: String = ICONES.get(cle, "train")
		var tuile := D.panel(section, Rect2(x, haut, largeur, hauteur_tuile), str(plan.label), icone, "", "TrainingPlanTile_" + cle)
		var donnees := parts(plan)
		var somme: int = R.total(donnees)
		if choix == "A": _tuile_a(canvas, tuile, plan, donnees, somme, largeur, hauteur_tuile, disponible)
		else: _tuile_b(canvas, tuile, plan, donnees, somme, largeur, hauteur_tuile, disponible)

static func _bouton(canvas: Control, tuile: Panel, plan: Dictionary, largeur: float, y: float, disponible: bool) -> void:
	var appliquer: Button = canvas._action(tuile, Rect2(22, y, largeur - 44, 56), "Appliquer le plan", func(): canvas.app._command("training_plan", {"context": canvas.support.context, "plan": plan.key}), false, "arrow", "SupportTraining_" + str(plan.key))
	appliquer.disabled = not disponible
	if not disponible: appliquer.tooltip_text = "Plan indisponible pour le moment (séance déjà faite, match ou fin de saison)."

static func _legende(tuile: Panel, donnees: Array, y: float, avec_chiffre: bool) -> void:
	for k in donnees.size():
		var part: Dictionary = donnees[k]
		var ligne := y + k * 44.0
		var pastille := D.rect(tuile, Rect2(24, ligne - 21, 28, 28), part.couleur, 6)
		if int(part.motif) != R.MOTIF_AUCUN:
			var repere := D.text(pastille, 14, 22, "//" if int(part.motif) == R.MOTIF_DIAGONALE else "••", 16, part.encre, 800, 28, HORIZONTAL_ALIGNMENT_CENTER)
			repere.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mot := str(part.mot).capitalize() if false else str(part.mot).substr(0, 1).to_upper() + str(part.mot).substr(1)
		if avec_chiffre:
			D.text(tuile, 70, ligne, str(part.n), 30, C.IVORY, 800, 60)
			D.text(tuile, 130, ligne, mot if int(part.n) > 0 else mot + " · aucun", 25, C.IVORY if int(part.n) > 0 else C.MUTED, 600, 380)
		else:
			D.text(tuile, 70, ligne, mot if int(part.n) > 0 else mot + " · aucun", 25, C.IVORY if int(part.n) > 0 else C.MUTED, 600, 440)

static func _tuile_a(canvas: Control, tuile: Panel, plan: Dictionary, donnees: Array, somme: int, largeur: float, hauteur: float, disponible: bool) -> void:
	phrase(tuile, 24, 98, str(plan.get("detail", "")), 25, largeur - 48, 3)
	D.chip(tuile, Rect2(24, 200, 130, 36), "%s joueurs" % G.n(somme), C.MUTED)
	R.barre(tuile, Rect2(24, 250, largeur - 48, 84), donnees, 36)
	_legende(tuile, donnees, 396, true)
	_bouton(canvas, tuile, plan, largeur, hauteur - 82, disponible)

static func _tuile_b(canvas: Control, tuile: Panel, plan: Dictionary, donnees: Array, somme: int, largeur: float, hauteur: float, disponible: bool) -> void:
	phrase(tuile, 24, 98, str(plan.get("detail", "")), 22, largeur - 48, 2)
	var centre := Vector2(largeur / 2.0, 285.0)
	R.anneau(tuile, centre, 280.0, 56.0, donnees, 30)
	D.text(tuile, centre.x, centre.y + 12, G.n(somme), 56, C.IVORY, 800, 140, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(tuile, centre.x, centre.y + 44, "joueurs", 24, C.MUTED, 600, 140, HORIZONTAL_ALIGNMENT_CENTER)
	_legende(tuile, donnees, 484, true)
	_bouton(canvas, tuile, plan, largeur, hauteur - 78, disponible)
