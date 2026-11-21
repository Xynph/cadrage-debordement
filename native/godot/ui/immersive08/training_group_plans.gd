extends RefCounted
## Entraînement › Groupes : trois plans de travail en tuiles, chacune avec un anneau (récupération / normal / intensif).
## Revue du 21/11/2026, n° 6, option B choisie par Léo. Couleurs de la palette commune (anneau_repartition.gd).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const R = preload("res://ui/anneau_repartition.gd")
const ICONES := {"proteger": "shield", "relever": "star", "equilibrer": "train"}
const TEINTES := {"proteger": R.REPOS, "relever": R.INTENSIF, "equilibrer": R.NORMAL}
## Règles de chaque plan en pastilles courtes [texte, couleur du mode] ; le texte complet reste en infobulle.
const REGLES := {
	"proteger": [["Titulaires → repos", R.REPOS], ["Remplaçants aptes → normal", R.NORMAL]],
	"relever": [["Jeunes aptes et frais → intensif", R.INTENSIF], ["Titulaires fatigués → repos", R.REPOS]],
	"equilibrer": [["Charge ou condition critique → repos", R.REPOS], ["Les autres → mode collectif", R.NORMAL]],
}
const HAUTEUR := 690.0
const MODES := [["repos"], ["normal", "collective"], ["intense"]]

static func parts(plan: Dictionary) -> Array:
	var n: Dictionary = plan.get("counts", {})
	var liste := [
		{"n": int(n.get("repos", 0)), "couleur": R.REPOS, "encre": C.Charte.PANNEAU, "mot": "récupération"},
		{"n": int(n.get("normal", 0)) + int(n.get("collective", 0)), "couleur": R.NORMAL, "encre": C.Charte.PANNEAU, "mot": "normal ou collectif"},
		{"n": int(n.get("intense", 0)), "couleur": R.INTENSIF, "encre": C.Charte.PANNEAU, "mot": "intensif"},
	]
	for part: Dictionary in liste: part["infobulle"] = "%d · %s : voir les joueurs" % [part.n, part.mot]
	return liste

## Joueurs (fiches de l'effectif) de la part `indice` du plan.
static func joueurs(canvas: Control, plan: Dictionary, indice: int) -> Array:
	var resultat: Array = []
	for ligne: Dictionary in plan.get("players", []):
		if str(ligne.get("plan", "")) in MODES[indice]:
			var fiche: Dictionary = canvas.P.player(canvas.app.model, str(ligne.get("id", "")))
			if not fiche.is_empty(): resultat.append(fiche)
	return resultat

static func ouvrir_part(canvas: Control, plan: Dictionary, donnees: Array, indice: int) -> void:
	if int(donnees[indice].n) <= 0: return
	var titre := "%s · %s" % [str(plan.get("label", "")), str(donnees[indice].mot)]
	canvas.Groupe.ouvrir(canvas, titre, donnees[indice].couleur, joueurs(canvas, plan, indice))

## Hauteur de la section « Plans de travail » (en-tête compris).
static func hauteur_section() -> float:
	return 84.0 + HAUTEUR + 24.0

static func build(canvas: Control, section: Panel, plans: Array, disponible: bool, raison: String) -> void:
	var largeur := (1740.0 - 2.0 * 23.0 - 2.0 * 22.0) / 3.0
	var haut := 84.0
	# La photo du centre d'entraînement reste en fond voilé derrière les tuiles.
	D.photo(section, canvas.photo_centre(canvas.app.model), Rect2(18, 66, 1704, haut + HAUTEUR + 24 - 66))
	D.rect(section, Rect2(18, 66, 1704, haut + HAUTEUR + 24 - 66), Color(C.Charte.PANNEAU, 0.66))
	for i in plans.size():
		var plan: Dictionary = plans[i]
		var cle := str(plan.get("key", ""))
		var teinte: Color = TEINTES.get(cle, R.NORMAL)
		var x := 23.0 + i * (largeur + 22.0)
		var tuile := D.panel(section, Rect2(x, haut, largeur, HAUTEUR), str(plan.label), str(ICONES.get(cle, "train")), "", "TrainingPlanTile_" + cle)
		# Léger fond teinté, icône teintée.
		tuile.add_theme_stylebox_override("panel", C.Charte.style_panneau(C.Charte.PANNEAU.lerp(teinte, 0.10), maxi(3, C.px(24)), 0))
		for enfant in tuile.get_children():
			if enfant is TextureRect:
				(enfant as TextureRect).texture = C.icon_texture(str(ICONES.get(cle, "train")), teinte)
				break
		_regles(tuile, plan, cle, largeur)
		var donnees := parts(plan)
		var somme: int = 0
		for part: Dictionary in donnees: somme += int(part.n)
		var centre := Vector2(largeur / 2.0, 305.0)
		R.anneau(tuile, centre, 280.0, 56.0, donnees, 30, func(i: int): ouvrir_part(canvas, plan, donnees, i))
		D.text(tuile, centre.x, centre.y + 12, G.n(somme), 56, C.IVORY, 800, 140, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(tuile, centre.x, centre.y + 44, "joueurs", 24, C.MUTED, 600, 140, HORIZONTAL_ALIGNMENT_CENTER)
		_legende(canvas, tuile, plan, donnees, 504)
		var appliquer: Button = canvas._action(tuile, Rect2(22, HAUTEUR - 78, largeur - 44, 56), "Appliquer le plan", func(): canvas.app._command("training_plan", {"context": canvas.support.context, "plan": plan.key}), false, "arrow", "SupportTraining_" + cle)
		appliquer.disabled = not disponible
		if not disponible: appliquer.tooltip_text = raison

static func _regles(tuile: Panel, plan: Dictionary, cle: String, largeur: float) -> void:
	var detail := str(plan.get("detail", ""))
	if not REGLES.has(cle):
		var libre := D.text(tuile, 24, 98, detail, 22, C.IVORY, 500, largeur - 48)
		libre.tooltip_text = detail
		return
	for k in REGLES[cle].size():
		var regle: Array = REGLES[cle][k]
		var pastille := D.chip(tuile, Rect2(24, 74 + k * 44, largeur - 48, 36), str(regle[0]), regle[1])
		pastille.mouse_filter = Control.MOUSE_FILTER_PASS
		pastille.tooltip_text = detail

static func _legende(canvas: Control, tuile: Panel, plan: Dictionary, donnees: Array, y: float) -> void:
	for k in donnees.size():
		var part: Dictionary = donnees[k]
		var ligne := y + k * 44.0
		D.rect(tuile, Rect2(24, ligne - 21, 28, 28), part.couleur, 6)
		var mot := str(part.mot).substr(0, 1).to_upper() + str(part.mot).substr(1)
		D.text(tuile, 70, ligne, str(part.n), 30, C.IVORY, 800, 60)
		D.text(tuile, 130, ligne, mot if int(part.n) > 0 else mot + " · aucun", 25, C.IVORY if int(part.n) > 0 else C.MUTED, 600, 380)
		if int(part.n) > 0:
			var indice := k
			canvas._zone(tuile, Rect2(14, ligne - 31, tuile.size.x / C.density - 28.0, 40), "TrainingPlanPart_%s_%d" % [plan.get("key", ""), k], str(part.infobulle), func(): ouvrir_part(canvas, plan, donnees, indice))
