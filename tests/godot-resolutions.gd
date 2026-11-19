extends SceneTree
## Écrans principaux dans les résolutions courantes, sur une vraie carrière Monde (moteur réel) :
## 1280 × 720, 1366 × 768, 1600 × 900, 1920 × 1080, 2560 × 1440, 3840 × 2160 (16:9), 1920 × 1200 (16:10),
## 2560 × 1080 et 3440 × 1440 (21:9).
## - la zone de travail (barre latérale, bandeau, contenu, pied) reste dans la fenêtre ;
## - en 16:9 et 16:10 elle occupe toute la largeur ; en ultra-large elle garde 16:9 au plus et se centre
##   (avant : collée à gauche, bande vide à droite, bandeau coupé net) ;
## - aucun contrôle visible ne sort de la fenêtre (hors zones de défilement) ;
## - les textes gardent une taille lisible à l'écran (≥ 11 px physiques) et ne grossissent pas sans fin en 4K.
const ContextualFlow = preload("helpers/contextual_flow.gd")
const TAILLES := [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160), Vector2i(1920, 1200), Vector2i(2560, 1080), Vector2i(3440, 1440)]
const ROUTES := ["Réception", "Bureau", "Effectif", "Composition", "Match", "Presse", "Recrutement", "Formation", "Classements"]
const RATIO_MAX := 16.0 / 9.0
var app: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)

func wait_model() -> void:
	var until := Time.get_ticks_msec() + 90000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Moteur réel disponible")

func settle() -> void:
	for i in 6: await process_frame
	var until := Time.get_ticks_msec() + 20000
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	for i in 4: await process_frame

func fermer_gabi() -> void:
	var coach: Variant = app.get("coach")
	if not is_instance_valid(coach): return
	if coach.has_method("fermer_bulle"): coach.fermer_bulle()
	if coach.get("expanded") == true and coach.has_method("close"): coach.close()

func taille(t: Vector2i) -> void:
	root.size = t
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(t)
	await settle()

## Contrôles visibles hors de la fenêtre (au-delà de 2 px), sans descendre dans les zones de défilement
## ni dans les fenêtres et vues 3D.
func hors_fenetre(noeud: Node, fenetre: Rect2, sortie: Array) -> void:
	for enfant in noeud.get_children():
		if enfant is Window or enfant is SubViewport or enfant is Node3D: continue
		if enfant is CanvasItem and not (enfant as CanvasItem).visible: continue
		if enfant is Control:
			var c: Control = enfant
			if c.size.x >= 4.0 and c.size.y >= 4.0 and c.modulate.a > 0.01 and (c is Label or c is BaseButton or c is LineEdit or c is TextureRect or c is PanelContainer):
				var r := c.get_global_rect()
				if r.position.x < fenetre.position.x - 2.0 or r.position.y < fenetre.position.y - 2.0 or r.end.x > fenetre.end.x + 2.0 or r.end.y > fenetre.end.y + 2.0:
					sortie.append("%s %s" % [c.name, str(r)])
			# Zones qui découpent leur contenu (défilement, bandeau défilant de Gabi) : le contenu peut déborder.
			if c is ScrollContainer or c.clip_contents: continue
		hors_fenetre(enfant, fenetre, sortie)

## Plus petite police affichée à l'écran parmi les libellés visibles (pixels physiques).
func police_min(noeud: Node, mini: Array) -> void:
	for enfant in noeud.get_children():
		if enfant is CanvasItem and not (enfant as CanvasItem).visible: continue
		if enfant is Label and not (enfant as Label).text.strip_edges().is_empty() and (enfant as Label).is_visible_in_tree():
			var l: Label = enfant
			var px := float(l.get_theme_font_size("font_size")) * l.get_global_transform_with_canvas().get_scale().y
			if px < mini[0]: mini[0] = px; mini[1] = str(l.text).left(30)
		police_min(enfant, mini)

func verifier(route: String, t: Vector2i) -> void:
	var nom := "%s %dx%d" % [route, t.x, t.y]
	var shell: Control = app.root_content
	check(shell != null and shell.name == "ImmersiveShell", nom + " : écran de gestion construit")
	if shell == null or shell.name != "ImmersiveShell": return
	var layout: Control = shell.get_node_or_null("ImmersiveLayout")
	check(layout != null, nom + " : zone de travail présente")
	if layout == null: return
	var fenetre := Rect2(Vector2.ZERO, Vector2(root.size))
	var zone := layout.get_global_rect()
	check(zone.position.x >= -1.0 and zone.position.y >= -1.0 and zone.end.x <= fenetre.end.x + 1.0 and zone.end.y <= fenetre.end.y + 1.0, nom + " : zone de travail dans la fenêtre " + str(zone))
	check(zone.size.x <= zone.size.y * RATIO_MAX + 3.0, nom + " : zone de travail 16:9 au plus " + str(zone.size))
	var gauche := zone.position.x
	var droite := fenetre.end.x - zone.end.x
	check(absf(gauche - droite) <= 2.0, nom + " : zone de travail centrée (marges %d / %d)" % [roundi(gauche), roundi(droite)])
	if float(t.x) / float(t.y) <= RATIO_MAX + 0.01:
		check(zone.size.x >= fenetre.size.x - 2.0, nom + " : toute la largeur occupée " + str(zone.size.x))
	var dehors: Array = []
	hors_fenetre(shell, fenetre, dehors)
	check(dehors.is_empty(), nom + " : contrôles hors de la fenêtre " + str(dehors.slice(0, 4)))
	var mini := [INF, ""]
	police_min(layout, mini)
	check(mini[0] >= 11.0, nom + " : texte lisible (plus petite police %.1f px : %s)" % [mini[0], mini[1]])
	# 4K : la mise en page grandit avec l'écran (pas d'interface minuscule), sans dépasser l'échelle d'origine × 1,6.
	if t.y >= 2160: check(layout.scale.y >= 1.4 and layout.scale.y <= 1.6, nom + " : interface à l'échelle de l'écran (%.2f)" % layout.scale.y)

func run() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await wait_model(); app.timer.stop()
	app._command("new_career", {"club": 0, "mode": "world-champ"}); await wait_model()
	await ContextualFlow.settle_club_meetings(app, self, check)
	check(str(app.model.meta.get("mode")) == "world", "Carrière Monde")
	for t: Vector2i in TAILLES:
		await taille(t)
		for route: String in ROUTES:
			fermer_gabi()
			app._navigate(route); await settle()
			fermer_gabi(); await settle()
			verifier(route, t)
		print("RESOLUTIONS ", t.x, "x", t.y, " ", failures.size(), " echec(s) cumulés")
	print("RESOLUTIONS ", checks, " controles, ", failures.size(), " echec", "s" if failures.size() > 1 else "")
	quit(1 if failures.size() > 0 else 0)
