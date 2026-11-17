extends SceneTree
## Préchauffage des portraits de l'effectif (ui/portrait_warmup.gd) en carrière Monde réelle (world-champ).
## Sans lui, la 1re ouverture de la Composition fabriquait ses 23 portraits d'un bloc (~10 ms chacun à froid).
## Vérifie : après un moment au repos sur le Bureau, tous les portraits de l'effectif sont en cache ; la 1re
## Composition se construit sous BUDGET_MS ; le préchauffage s'arrête quand une commande moteur est en attente
## et reprend ensuite, par petites étapes. Imprime CD_PRECHAUFFAGE (JSON).
const Flow = preload("helpers/contextual_flow.gd")
const G = preload("res://ui/game_skin.gd")
const Portrait = preload("res://ui/regen_portrait.gd")
const Warmup = preload("res://ui/portrait_warmup.gd")
const Loader = preload("res://ui/portrait_loader.gd")
## 1re Composition à froid : ~335 ms mesurés sans préchauffage, ~100 ms avec (rendu réel, PC de Léo).
## Marge large pour les machines de CI ; CD_PORTRAITS_BUDGET_MS l'ajuste.
const BUDGET_MS := 250.0
## Une seule étape (un portrait) ne doit pas geler une image bien au-delà du budget par image.
const STEP_BUDGET_MS := 50.0
var app: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames: int = 8) -> void:
	for frame in frames: await process_frame

func squad() -> Array:
	var value: Variant = app.model.get("squad")
	return value if value is Array else []

func ready_count() -> int:
	var total := 0
	for person: Variant in squad():
		if person is Dictionary and G._portrait_ready(person): total += 1
	return total

## Attend que le préchauffage ait vidé sa file (interface au repos), au plus `seconds`.
func wait_warmup(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while (Warmup.pending() > 0 or Loader.pending() > 0) and Time.get_ticks_msec() < until: await process_frame
	await settle(4)

func run() -> void:
	root.size = Vector2i(1920, 1080)
	var budget := BUDGET_MS
	if not OS.get_environment("CD_PORTRAITS_BUDGET_MS").is_empty(): budget = float(OS.get_environment("CD_PORTRAITS_BUDGET_MS"))
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach): app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 30000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	check(app._command("new_career", {"mode": "world-champ", "club": 0}), "Carrière Monde créée")
	until = Time.get_ticks_msec() + 60000
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()
	await Flow.settle_club_meetings(app, self, check)
	if is_instance_valid(app.coach): app.coach.close()
	var total := squad().size()
	check(total >= 23, "Effectif du club reçu (%d joueurs)" % total)

	# 1. Au repos sur le Bureau : le préchauffage remplit le cache de tout l'effectif.
	app._navigate("Bureau")
	await wait_warmup(20.0)
	var in_cache := ready_count()
	check(Warmup.pending() == 0, "File du préchauffage vide après un moment au repos (%d restants)" % Warmup.pending())
	check(in_cache == total, "Portraits de l'effectif en cache après le repos au Bureau : %d / %d" % [in_cache, total])
	check(Warmup.warmed > 0, "Le préchauffage a fabriqué des portraits (%d)" % Warmup.warmed)
	var step_ms: float = Warmup.longest_step_usec / 1000.0
	check(step_ms < STEP_BUDGET_MS, "Plus longue étape du préchauffage %.1f ms, budget %.0f ms" % [step_ms, STEP_BUDGET_MS])

	# 2. 1re ouverture de la Composition : plus aucun portrait à fabriquer d'un bloc.
	var started := Time.get_ticks_usec()
	app._navigate("Composition")
	var composition_ms := (Time.get_ticks_usec() - started) / 1000.0
	await settle()
	var portraits: Array[Node] = app.body.find_children("TacticsPortrait*", "TextureRect", true, false)
	var filled: int = portraits.filter(func(node: Node) -> bool: return (node as TextureRect).texture != null).size()
	check(portraits.size() >= 15, "Composition construite avec ses portraits (%d)" % portraits.size())
	check(filled == portraits.size(), "Portraits de la Composition remplis : %d / %d" % [filled, portraits.size()])
	check(composition_ms < budget, "1re Composition construite en %.0f ms, budget %.0f ms" % [composition_ms, budget])

	# 3. Commande moteur en attente : le préchauffage ne prend aucune image ; il reprend ensuite.
	app._navigate("Bureau")
	await settle()
	Warmup.reset()
	Portrait.clear_cache()
	G.textures.clear()
	var was_waiting: bool = app.waiting
	app.waiting = true
	Warmup.schedule(app)
	var queued: int = Warmup.pending()
	await settle(20)
	check(queued == total and Warmup.pending() == queued and Warmup.warmed == 0, "Rien n'est fabriqué tant qu'une commande est en attente (%d en file, %d fabriqués)" % [Warmup.pending(), Warmup.warmed])
	app.waiting = was_waiting
	var frames := 0
	until = Time.get_ticks_msec() + 20000
	while Warmup.pending() > 0 and Time.get_ticks_msec() < until:
		await process_frame
		frames += 1
	check(Warmup.pending() == 0 and ready_count() == total, "Le préchauffage reprend au repos et termine (%d / %d)" % [ready_count(), total])
	check(frames > 1, "Le préchauffage est étalé sur plusieurs images (%d)" % frames)

	print("CD_PRECHAUFFAGE ", JSON.stringify({"effectif": total, "en_cache": in_cache, "composition_ms": snappedf(composition_ms, 0.1), "etape_max_ms": snappedf(step_ms, 0.1), "images_reprise": frames}))
	print("PRECHAUFFAGE PORTRAITS : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
