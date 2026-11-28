extends RefCounted
## Entrée d'une page dessinée (Bureau d'abord, 28/11/2026) : les blocs apparaissent en cascade (fondu + montée de
## quelques pixels) et les jauges se remplissent depuis zéro. Seulement quand on ARRIVE sur la page (pas à chaque
## rafraîchissement : décision, Continuer, retour de fenêtre). Court (< 0,45 s en tout), jamais bloquant : les clics
## et le clavier marchent pendant l'animation. « Mouvement réduit » dans les Préférences : aucune animation.
##
## Usage : `EntreePage.animer(app, page, "Bureau")` après la construction de la page ; les barres de jauge (D.bar)
## portent la méta META_JAUGE (largeur finale) et se remplissent.

const C = preload("res://ui/immersive08/components.gd")
const DUREE := 0.20
const DECALAGE := 0.045
const MONTEE := 14.0
const META_ROUTE := "entree_page_route"
const META_JAUGE := "entree_page_jauge"

## Mémorise la page affichée et dit si l'on vient d'arriver dessus (route différente de la précédente).
static func arrivee(app: Node, route: String) -> bool:
	var avant := str(app.get_meta(META_ROUTE, ""))
	app.set_meta(META_ROUTE, route)
	return avant != route

static func mouvement_reduit(app: Node) -> bool:
	var preferences: Variant = app.get("user_preferences")
	if preferences == null: return false
	var data: Variant = preferences.get("data")
	return data is Dictionary and bool((data as Dictionary).get("reduced_motion", false))

## Suites Godot et outils de capture (lancés avec --script) : page posée d'emblée, mesures et captures sans attente.
static func sous_script() -> bool:
	var args := OS.get_cmdline_args()
	return args.has("--script") or args.has("-s")

## Retourne le Tween lancé (null sans animation). `forcer` : pour la suite qui vérifie l'animation elle-même.
static func animer(app: Node, page: Control, route: String, forcer := false) -> Tween:
	if not arrivee(app, route) or mouvement_reduit(app) or not is_instance_valid(page) or not page.is_inside_tree(): return null
	if sous_script() and not forcer: return null
	var blocs: Array[Control] = []
	for enfant in page.get_children():
		if enfant is Control and (enfant as Control).visible: blocs.append(enfant)
	# Ordre de lecture : de haut en bas, puis de gauche à droite.
	blocs.sort_custom(func(a: Control, b: Control) -> bool:
		return a.position.x < b.position.x if is_equal_approx(a.position.y, b.position.y) else a.position.y < b.position.y)
	if blocs.is_empty(): return null
	var tween := page.create_tween().set_parallel(true)
	# Dans un conteneur (Bureau classique des petits écrans), la mise en page replace les blocs : fondu seul.
	var montee := 0.0 if page is Container else MONTEE * C.density
	# Un bloc et son ombre portée (même rectangle, nœud voisin) partent ensemble.
	var rang := -1
	var precedent := Rect2(-1, -1, -1, -1)
	for bloc in blocs:
		var fin := bloc.position
		if not Rect2(fin, bloc.size).is_equal_approx(precedent): rang += 1
		precedent = Rect2(fin, bloc.size)
		bloc.modulate.a = 0.0
		var delai := rang * DECALAGE
		tween.tween_property(bloc, "modulate:a", 1.0, DUREE).set_delay(delai).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if montee <= 0.0: continue
		bloc.position.y = fin.y + montee
		tween.tween_property(bloc, "position:y", fin.y, DUREE).set_delay(delai).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var jauges: Array[Control] = []
	_jauges(page, jauges)
	for barre in jauges:
		var largeur := float(barre.get_meta(META_JAUGE))
		barre.size.x = 0.0
		tween.tween_property(barre, "size:x", largeur, 0.42).set_delay(0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween

static func _jauges(noeud: Node, sortie: Array[Control]) -> void:
	for enfant in noeud.get_children():
		if enfant is Control and enfant.has_meta(META_JAUGE): sortie.append(enfant)
		_jauges(enfant, sortie)
