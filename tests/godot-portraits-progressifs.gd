extends SceneTree
## Portraits des longues listes : cache assez large pour un groupe pro, chargement
## progressif identique au chargement immédiat, replis sans erreur.
const G = preload("res://ui/game_skin.gd")
const Portrait = preload("res://ui/regen_portrait.gd")
const Loader = preload("res://ui/portrait_loader.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message);printerr("FAIL: "+message)
func people(count: int) -> Array:
	var result: Array = []
	for i in count: result.append({"id": "prog:%d" % i, "name": "Joueur %d" % i, "age": 20 + i % 15, "appearanceBankVersion": 2})
	return result
func run() -> void:
	Portrait.clear_cache()
	var squad := people(70)
	var host := Control.new()
	root.add_child(host)
	# 1. Cache froid : les cases sont créées vides, rien n'est décodé à la construction.
	var lazy: Array[TextureRect] = []
	for person: Dictionary in squad:
		var rect := G.portrait_lazy(0, 31, person)
		host.add_child(rect)
		lazy.append(rect)
	check(Loader.pending() == squad.size(), "Cache froid : 70 portraits en attente, aucun décodé")
	check(lazy[0].texture == null and lazy[0].tooltip_text == "Joueur 0", "Case vide mais survol et nom déjà présents")
	# 2. Remplissage progressif, quelques images suffisent à tout charger.
	var frames := 0
	while Loader.pending() > 0 and frames < 600:
		await process_frame
		frames += 1
	check(Loader.pending() == 0, "Le chargement progressif se termine (%d images)" % frames)
	check(frames > 1, "Le chargement est étalé sur plusieurs images")
	# 3. Même résultat que le chargement immédiat.
	var same := true
	for i in squad.size():
		var eager := G.portrait(0, 31, squad[i])
		if lazy[i].texture == null or lazy[i].texture != eager.texture or lazy[i].material != eager.material or lazy[i].tooltip_text != eager.tooltip_text: same = false
		eager.free()
	check(same, "Portraits progressifs identiques aux portraits immédiats (texture, matériau, survol)")
	# 4. Cache chaud : le groupe entier tient en cache, la visite suivante est immédiate.
	var cells := {}
	for person: Dictionary in squad: cells[Portrait._cache_key(Portrait.describe(person))] = true
	check(cells.size() > 48 and Portrait.cache_info().textures == cells.size(), "Le cache garde tous les visages du groupe (%d bases, plus que l'ancienne limite de 48)" % cells.size())
	var again := G.portrait_lazy(0, 31, squad[0])
	check(again.texture != null and Loader.pending() == 0, "Deuxième ouverture : visage déjà là, rien en attente")
	again.free()
	# 5. flush termine tout d'un coup.
	Portrait.clear_cache()
	var batch: Array[TextureRect] = []
	for person: Dictionary in squad.slice(0, 10):
		var rect := G.portrait_lazy(0, 31, person)
		host.add_child(rect)
		batch.append(rect)
	Loader.flush()
	check(Loader.pending() == 0 and batch.all(func(r: TextureRect): return r.texture != null), "flush() remplit tout de suite")
	# 6. Cases détruites avant leur tour : ignorées sans erreur.
	Portrait.clear_cache()
	var doomed := G.portrait_lazy(0, 31, squad[1])
	doomed.free()
	Loader.flush()
	check(Loader.pending() == 0, "Case libérée avant chargement : ignorée")
	# 7. Repli sans identifiant : planche éditoriale ou initiale, jamais d'erreur.
	var anonymous := G.portrait(3, 31, {"name": "Ana Lise"})
	check(anonymous.texture != null or anonymous.get_child_count() == 1, "Repli sans identifiant : planche ou initiale")
	anonymous.free()
	var initial := G._initial_label("Ana Lise")
	check(initial.text == "AL", "Initiales du repli")
	initial.free()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
