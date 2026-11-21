extends RefCounted
## Bulle au survol, sans clic (planches de Léo du 21/11/2026 : écusson → mini-carte club, chiffre → mini-courbe).
## Même mécanique que la carte joueur au survol (carte_joueur_survol.gd) : la bulle apparaît après DELAI à côté du
## contrôle survolé, disparaît quand la souris part ; Échap la ferme ; un clic garde son effet habituel et la range.
## Exemple : `BulleSurvol.lier(ecusson, "club:12", func(): return CarteClub.construire(app, club))`.
const C = preload("res://ui/immersive08/components.gd")
const NOM := "BulleSurvol"
const GUETTEUR := "BulleSurvolGuetteur"
## Même délai que la carte joueur : un passage rapide de la souris n'ouvre rien.
const DELAI := 0.35
const MARGE := 8.0

## Variante de planche (CD_VARIANTE_VISUELLE) : ECUSSON_A|ECUSSON_B|COURBE_A|COURBE_B|REBOURS_A|REBOURS_B.
static func variante() -> String:
	return OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()

static func active(prefixe: String) -> bool:
	return variante().begins_with(prefixe + "_")

## Branche une bulle sur un contrôle. `fabrique` (sans argument) renvoie le Control de la bulle, construit à
## l'apparition (données lues à ce moment-là). L'info-bulle système est retirée : la bulle la remplace.
static func lier(controle: Control, cle: String, fabrique: Callable) -> void:
	if not is_instance_valid(controle) or not fabrique.is_valid(): return
	controle.tooltip_text = ""
	controle.set_meta("bulle_survol", cle)
	controle.set_meta("bulle_fabrique", fabrique)
	if controle.mouse_filter == Control.MOUSE_FILTER_IGNORE: controle.mouse_filter = Control.MOUSE_FILTER_PASS
	if controle.is_inside_tree(): guetteur(controle)
	else: controle.tree_entered.connect(func(): guetteur(controle), CONNECT_ONE_SHOT)

## Le guetteur vit à la racine de l'arbre : il reçoit Échap avant l'écran en cours.
static func guetteur(controle: Node) -> Node:
	var racine := controle.get_tree().root
	var existant := racine.get_node_or_null(GUETTEUR)
	if existant != null: return existant
	var g := Guetteur.new()
	g.name = GUETTEUR
	racine.add_child.call_deferred(g)
	return g

## Contrôle plein écran qui porte l'interface (enfant direct de la racine) : la bulle y est ajoutée.
static func hote(controle: Node) -> Control:
	var n := controle
	while n != null and n.get_parent() != null and not n.get_parent() is Window: n = n.get_parent()
	return n as Control

static func actuelle(controle: Node) -> Control:
	var h := hote(controle) if is_instance_valid(controle) else null
	var bulle := h.get_node_or_null(NOM) as Control if h != null else null
	return bulle if bulle != null and not bulle.is_queued_for_deletion() else null

static func cacher(controle: Node) -> void:
	var bulle := actuelle(controle)
	if bulle == null: return
	bulle.hide()
	bulle.name = NOM + "Fermee"
	bulle.queue_free()

## Montre la bulle de `ancre` tout de suite (guetteur et suites).
static func montrer(ancre: Control) -> Control:
	cacher(ancre)
	if not is_instance_valid(ancre) or not ancre.is_inside_tree() or not ancre.has_meta("bulle_fabrique"): return null
	var fabrique: Callable = ancre.get_meta("bulle_fabrique")
	if not fabrique.is_valid(): return null
	var bulle: Variant = fabrique.call()
	if not bulle is Control: return null
	var h := hote(ancre)
	(bulle as Control).name = NOM
	(bulle as Control).set_meta("ancre", ancre)
	h.add_child(bulle)
	for n: Node in [bulle] + (bulle as Control).find_children("*", "Control", true, false): (n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	placer(bulle, ancre, h.get_viewport_rect().size)
	# L'info-bulle système d'un parent (ligne du classement…) masquerait la bulle : retirée le temps du survol.
	var n: Node = ancre.get_parent()
	while n != null and n != h:
		if n is Control and not (n as Control).tooltip_text.is_empty():
			n.set_meta("bulle_infobulle", (n as Control).tooltip_text)
			(n as Control).tooltip_text = ""
			bulle.tree_exiting.connect(func(): if is_instance_valid(n): (n as Control).tooltip_text = str(n.get_meta("bulle_infobulle", "")))
		n = n.get_parent()
	return bulle

## Sous l'ancre (au-dessus s'il manque la place), alignée sur son bord gauche ; toujours entière dans l'écran.
static func placer(bulle: Control, ancre: Control, ecran: Vector2) -> void:
	bulle.size = bulle.custom_minimum_size
	var t := ancre.get_global_transform_with_canvas()
	var zone := Rect2(t.origin, ancre.size * t.get_scale())
	var taille := bulle.size
	var ecart := maxf(6.0, C.px(10))
	var y := zone.end.y + ecart
	if y + taille.y > ecran.y - MARGE: y = zone.position.y - taille.y - ecart
	var x := zone.position.x
	bulle.position = Vector2(clampf(x, MARGE, maxf(MARGE, ecran.x - taille.x - MARGE)), clampf(y, MARGE, maxf(MARGE, ecran.y - taille.y - MARGE)))

## Suit le contrôle survolé ; même logique que le guetteur de la carte joueur.
class Guetteur extends Node:
	var Bulle = load("res://ui/bulle_survol.gd")
	var cle := ""
	var ancre: Control
	var depuis := 0
	var masque := ""

	func _process(_delta: float) -> void:
		var survole := get_viewport().gui_get_hovered_control()
		var lie := _lie(survole) if survole != null else null
		var id := str(lie.get_meta("bulle_survol")) if lie != null else ""
		if id != cle:
			if is_instance_valid(ancre): Bulle.cacher(ancre)
			cle = id
			ancre = lie
			depuis = Time.get_ticks_msec()
			if masque != id: masque = ""
		if lie != null: ancre = lie
		if id.is_empty() or id == masque or not is_instance_valid(ancre): return
		if Bulle.actuelle(ancre) != null: return
		if Time.get_ticks_msec() - depuis < int(Bulle.DELAI * 1000.0): return
		Bulle.montrer(ancre)

	func _lie(controle: Control) -> Control:
		var n: Node = controle
		while n != null and n is Control:
			if n.has_meta("bulle_survol"): return n
			n = n.get_parent()
		return null

	func _input(event: InputEvent) -> void:
		if not is_instance_valid(ancre) or Bulle.actuelle(ancre) == null: return
		var touche := event as InputEventKey
		if touche != null and touche.pressed and not touche.echo and touche.keycode == KEY_ESCAPE:
			masque = cle
			Bulle.cacher(ancre)
			get_viewport().set_input_as_handled()
			return
		var clic := event as InputEventMouseButton
		if clic != null and clic.pressed:
			masque = cle
			Bulle.cacher(ancre)
