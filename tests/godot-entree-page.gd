extends SceneTree
## Entrée des pages dessinées (ui/entree_page.gd) : cascade seulement à l'arrivée sur la page, jamais au rafraîchissement,
## rien en « Mouvement réduit », état final identique à la page posée sans animation (positions, opacité, jauges).
const EntreePage = preload("res://ui/entree_page.gd")
const D = preload("res://ui/immersive08/primitives.gd")
class Prefs extends RefCounted:
	var data := {"reduced_motion": false}
class FauxApp extends Control:
	var user_preferences := Prefs.new()
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: " + message)
func page_test(app: Control) -> Control:
	var page := Control.new()
	app.add_child(page)
	for i in 3:
		var bloc := Panel.new()
		page.add_child(bloc)
		D.place(bloc, Rect2(i * 300, 0 if i < 2 else 400, 280, 200))
	D.bar(page.get_child(0), Rect2(10, 10, 200, 8), 60.0)
	return page
func run() -> void:
	var app := FauxApp.new()
	root.add_child(app)
	var page := page_test(app)
	var attendu: Array = page.get_children().map(func(n): return n.position)
	var barre: Control = null
	for n in page.get_child(0).get_children(): if n.has_meta(EntreePage.META_JAUGE): barre = n
	check(barre != null, "D.bar marque son remplissage")
	var largeur := barre.size.x
	var tween := EntreePage.animer(app, page, "Bureau", true)
	check(tween != null, "arrivée sur le Bureau : animation lancée")
	check(page.get_child(0).modulate.a < 0.01 and barre.size.x < 1.0, "départ : bloc transparent, jauge vide")
	check(page.get_child(2).position.y > float(attendu[2].y), "départ : le bloc monte vers sa place")
	await tween.finished
	for i in 3: check(page.get_child(i).position.is_equal_approx(attendu[i]) and is_equal_approx(page.get_child(i).modulate.a, 1.0), "fin : bloc %d à sa place, opaque" % i)
	check(is_equal_approx(barre.size.x, largeur), "fin : jauge remplie à sa valeur")
	page.queue_free()
	page = page_test(app)
	check(EntreePage.animer(app, page, "Bureau", true) == null, "rafraîchissement du Bureau : pas de nouvelle cascade")
	check(is_equal_approx(page.get_child(0).modulate.a, 1.0), "rafraîchissement : page posée d'emblée")
	EntreePage.arrivee(app, "Effectif")
	app.user_preferences.data.reduced_motion = true
	check(EntreePage.animer(app, page, "Bureau", true) == null, "Mouvement réduit : aucune animation")
	app.user_preferences.data.reduced_motion = false
	EntreePage.arrivee(app, "Effectif")
	check(EntreePage.animer(app, page, "Bureau") == null, "suite lancée avec --script : page posée sans animation")
	print("godot-entree-page : %d vérifications, %d échec(s)" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
