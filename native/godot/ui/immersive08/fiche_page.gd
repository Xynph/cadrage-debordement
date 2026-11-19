extends RefCounted
## Page « Fiche joueur » d'une piste du marché (route Recrutement) ou d'un Espoir (route Formation) : l'état de lecture
## `management_ui.fiche_joueur = {id, source}` (posé par navigation_controller.open_entity, gardé par l'historique)
## remplace l'écran d'origine par la fiche complète (player_canvas.gd). L'effectif garde son entrée historique
## (méta `immersive08_full_player`).
const Commune = preload("res://ui/immersive08/fiche_commune.gd")
const PlayerCanvas = preload("res://ui/immersive08/player_canvas.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const C = preload("res://ui/immersive08/components.gd")

## Fiche demandée pour la route affichée : {joueur, source} ou {}.
static func actuelle(app: Control) -> Dictionary:
	var etat: Variant = app.management_ui.get("fiche_joueur")
	if not etat is Dictionary: return {}
	var source := str(etat.get("source", ""))
	if source not in ["market", "academy"] or str(Commune.ROUTES.get(source, "")) != app.route: return {}
	return Commune.trouver(app, str(etat.get("id", "")), source)

static func build(app: Control, canvas: Control) -> void:
	var trouve := actuelle(app)
	if trouve.is_empty(): return
	var page := PlayerCanvas.build(app, trouve.joueur, trouve.source)
	canvas.add_child(page)
	canvas.custom_minimum_size.y = maxf(canvas.custom_minimum_size.y, PlayerCanvas.HAUTEUR * C.density)
	D.place(page, Rect2(0, 0, 2248, PlayerCanvas.HAUTEUR))
