extends SceneTree
## Chargement, direction artistique « les deux, selon la durée » (choix de Léo du 20/11/2026) :
## - panneau sur le bureau (courts) : ≈ 40 % de la largeur, « Arrêter → » après 20 s, grisé avec sa raison si l'arrêt
##   n'est pas réel, actif (et il agit) s'il l'est ;
## - le stade, puis le terrain (longs, photo) : lieu, club · division · saison lus dans les données, barre
##   indéterminée sans pourcentage inventé, « Anecdote suivante → » (et Entrée) qui change vraiment la note ;
## - l'ovale du ballon (Continuer) : anneau, liste des jours tirée des vraies dates, « Arrêter → » qui agit ;
## - aucune petite fenêtre, aucune couleur en dur, aucun or hors de l'anneau de Continuer.
## Godot réel + worker réel, carrière Monde. Imprime CHARGEMENT_DA {checks, failures}.
## Captures (rendu graphique) : CD_CHARGEMENT_DA_CAPTURES=<dossier>, taille CD_CHARGEMENT_DA_SIZE=LxH.
const Charte = preload("res://ui/charte.gd")
const Overlay = preload("res://ui/command_wait_overlay.gd")
const Progress = preload("res://ui/continue_progress.gd")
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var capture_dir := OS.get_environment("CD_CHARGEMENT_DA_CAPTURES")
var capture_size := OS.get_environment("CD_CHARGEMENT_DA_SIZE")
var stops := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 6) -> void:
	if DisplayServer.get_name() != "headless": await create_timer(.3).timeout
	for frame in frames: await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await settle(4)
	var tag := capture_size.split("x")[0] if not capture_size.is_empty() else str(root.size.x)
	check(root.get_texture().get_image().save_png(capture_dir.path_join("apercu-chargement-%s-%s.png" % [name, tag])) == OK, "Capture " + name)

func windows() -> Array:
	return root.find_children("*", "Window", true, false).filter(func(w: Node) -> bool: return (w as Window).visible)

func close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < .01 and absf(a.g - b.g) < .01 and absf(a.b - b.b) < .01

func gold_on(control: Control) -> bool:
	var tones: Array[Color] = []
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		if control.has_theme_color_override(key): tones.append(control.get_theme_color(key))
	for key in ["normal", "hover", "pressed", "focus", "disabled", "panel"]:
		if control.has_theme_stylebox_override(key):
			var box := control.get_theme_stylebox(key) as StyleBoxFlat
			if box != null: tones.append_array([box.bg_color, box.border_color])
	for tone in tones:
		for reference: Color in [Charte.OR, Charte.OR_VIF]:
			if close(tone, reference) and tone.a > .05: return true
	return false

func gold_count(parent: Node) -> int:
	var count := 0
	for control in parent.find_children("*", "Control", true, false):
		if gold_on(control as Control): count += 1
	return count

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func run() -> void:
	var size := Vector2i(1920, 1080)
	if not capture_size.is_empty(): size = Vector2i(int(capture_size.split("x")[0]), int(capture_size.split("x")[1]))
	root.size = size
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(size)
	sources()
	await synthetic()
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	check(app._command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"}), "Commande acceptée · new_career")
	await wait_engine()
	await Flow.settle_club_meetings(app, self, check)
	if is_instance_valid(app.coach): app.coach.close()
	app._navigate("Bureau")
	await settle(8)
	await in_game()
	print("CHARGEMENT_DA ", JSON.stringify({"checks": checks, "failures": failures}))
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)

## Aucune couleur écrite en dur dans les deux écrans : tout vient de la charte.
func sources() -> void:
	for path: String in ["res://ui/command_wait_overlay.gd", "res://ui/continue_progress.gd"]:
		var text := FileAccess.get_file_as_string(path)
		var hard := RegEx.create_from_string("Color\\(\\s*\"|Color\\(\\s*-?[0-9]|Color\\.[A-Z]+[^_a-z]")
		var hits := hard.search_all(text).filter(func(m: RegExMatch) -> bool: return not m.get_string().begins_with("Color.WHITE"))
		check(hits.is_empty(), "%s : aucune couleur en dur (%d)" % [path, hits.size()])
		check(not text.contains("set_corner_radius") and not text.contains("shadow_size") and not text.contains("Gradient"), "%s : ni rayon, ni ombre, ni dégradé" % path)
		check(not text.contains("AcceptDialog") and not text.contains("PopupPanel") and not text.contains("Window.new"), "%s : aucune petite fenêtre" % path)

func make_overlay(context: Dictionary) -> Control:
	var host := Control.new()
	host.name = "Hote"
	host.size = Vector2(root.size)
	root.add_child(host)
	var overlay: Control = Overlay.new()
	host.add_child(overlay)
	overlay.set_context(context)
	return overlay

func synthetic() -> void:
	# 1. Panneau sur le bureau (court), puis « Plus long que prévu ».
	var panel := make_overlay({"kicker": "Calendrier", "date": "2026-11-17", "flip": true, "accent": Color("d43e47"), "notes": [{"kind": "tip", "title": "Le conseil de Gabi", "text": "Regarde la fraîcheur avant samedi."}]})
	panel.present("Passage au jour suivant…", false, 0.0)
	await settle()
	var frame: Control = panel.get_node("CommandWaitFrame")
	check(not panel.stage_mode() and panel.panel_visible(), "Court : panneau sur le bureau")
	var ratio := frame.size.x / panel.size.x
	check(ratio > 0.36 and ratio < 0.44, "Court : ≈ 40 %% de la largeur (%.2f)" % ratio)
	check(not panel.get_node("CommandWaitFrame/CommandWaitStop").visible, "Court : pas d'« Arrêter » avant 20 s")
	check(not panel.get_node("CommandWaitFrame/CommandWaitLong").visible, "Court : pas de « Plus long que prévu » avant 20 s")
	panel._since_ms -= 21000
	panel._layout()
	await settle(2)
	var stop: LinkButton = panel.get_node("CommandWaitFrame/CommandWaitStop")
	var long_line: Label = panel.get_node("CommandWaitFrame/CommandWaitLong")
	check(long_line.visible and long_line.text.begins_with("Plus long que prévu (2") and long_line.text.ends_with(" s)…"), "Long : « Plus long que prévu (N s)… » (%s)" % long_line.text)
	check(stop.visible and stop.disabled, "Long : « Arrêter → » grisé quand l'arrêt n'est pas réel")
	var reason: Label = panel.get_node("CommandWaitFrame/CommandWaitStopReason")
	check(reason.visible and reason.text.begins_with("Arrêt impossible"), "Long : la raison est écrite (%s)" % reason.text)
	panel.stop_requested.connect(func() -> void: stops += 1)
	check(stop.mouse_default_cursor_shape == Control.CURSOR_ARROW, "Long : le bouton grisé n'a pas l'air cliquable")
	panel.set_context({"kicker": "Calendrier", "cancellable": true})
	panel._since_ms -= 100
	await settle(2)
	check(not stop.disabled and not panel.get_node("CommandWaitFrame/CommandWaitStopReason").visible, "Arrêt réel : « Arrêter → » actif, sans excuse")
	stop.pressed.emit()
	check(stops == 1, "Arrêt réel : le clic demande l'arrêt")
	check(gold_count(panel) == 0, "Panneau : aucun or")
	check(windows().is_empty(), "Panneau : aucune fenêtre")
	panel.get_parent().queue_free()

	# 2. Le stade, puis le terrain.
	var notes := [{"kind": "fact", "title": "Au club", "text": "Première anecdote réelle."}, {"kind": "tip", "title": "Le conseil de Gabi", "text": "Seconde anecdote réelle."}]
	var stage := make_overlay({"kicker": "Nouvelle carrière", "photo": true, "note_seed": 0, "stadium": "Stade Essai", "club_name": "Club Essai", "division": "Division Essai", "season": "saison 2026-2027", "notes": notes, "accent": Color("d43e47")})
	stage.present("Création de la carrière…", false, 0.0)
	await settle()
	check(stage.stage_mode() and stage.get("_photo") != null, "Long : photo plein écran de la banque")
	check(stage.get_node("CommandWaitFrame/CommandWaitLegend").visible and stage.get_node("CommandWaitFrame/CommandWaitLegend").text == "Stade Essai", "Long : lieu lu du contexte")
	check(stage.get_node("CommandWaitFrame/CommandWaitClubLine").text == "Club Essai · Division Essai · saison 2026-2027", "Long : club · division · saison")
	check(not stage.get_node("CommandWaitFrame/CommandWaitPercent").visible, "Long : aucun pourcentage inventé (barre indéterminée)")
	check(not stage.get_node("CommandWaitFrame/CommandWaitStop").visible, "Long : aucun « Arrêter » qui ne ferait rien")
	check(stage.get_node("CommandWaitFrame/CommandWaitStatus").uppercase, "Long : titre en capitales")
	var link: LinkButton = stage.get_node("CommandWaitFrame/CommandWaitNextNote")
	var note: Label = stage.get_node("CommandWaitFrame/CommandWaitNote")
	check(link.visible and not link.disabled, "Long : « Anecdote suivante → » présent")
	var first := note.text
	link.pressed.emit()
	check(note.text != first and note.text == "Seconde anecdote réelle.", "Long : le clic change la note (%s)" % note.text)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	check(stage.handle_key(enter) and note.text == first, "Long : Entrée change aussi la note")
	stage.set_progress(0.5, "Étape réelle")
	await settle(2)
	check(stage.get_node("CommandWaitFrame/CommandWaitPercent").text == "50 %" and stage.get_node("CommandWaitFrame/CommandWaitProgressLabel").text == "Étape réelle", "Long : pourcentage réel affiché quand le moteur en donne un")
	check(gold_count(stage) == 0, "Stade : aucun or")
	check(windows().is_empty(), "Stade : aucune fenêtre")
	stage.get_parent().queue_free()
	# Donnée absente : lignes omises, jamais inventées.
	var bare := make_overlay({"photo": true, "notes": []})
	bare.present("Ouverture du bureau du manager…", false, 0.0)
	await settle()
	check(not bare.get_node("CommandWaitFrame/CommandWaitLegend").visible and not bare.get_node("CommandWaitFrame/CommandWaitClubLine").visible, "Sans données : ni lieu ni ligne de club")
	check(not bare.get_node("CommandWaitFrame/CommandWaitNextNote").visible and not bare.get_node("CommandWaitFrame/CommandWaitNote").visible, "Sans note : ni lien ni texte")
	bare.get_parent().queue_free()

	# 3. L'ovale du ballon.
	var host := Control.new()
	host.size = Vector2(root.size)
	root.add_child(host)
	var ring: Control = Progress.new()
	host.add_child(ring)
	ring.size = host.size
	var stopped := [0]
	ring.stop_requested.connect(func() -> void: stopped[0] += 1)
	ring.begin({"date": "2026-11-17", "accent": Color("d43e47"), "next": {"date": "2026-11-21", "opponent": "Club Adverse"}, "notes": [{"kind": "tip", "text": "Un conseil réel."}]}, false)
	await settle(4)
	check(ring.modulate.a > 0.99 and ring.size == host.size, "Continuer : opaque et plein cadre (%.2f, %s)" % [ring.modulate.a, str(ring.size)])
	check(ring.title.text == "Passage au jour suivant…" and ring.mouse_filter == Control.MOUSE_FILTER_STOP, "Continuer : écran plein cadre, titre de la maquette")
	check(ring.bar.determinate and is_equal_approx(ring.bar.value, 0.0), "Continuer : anneau à 0 % au départ")
	ring.advance_to({"today": "2026-11-19", "days": 2, "next": {"date": "2026-11-21", "opponent": "Club Adverse"}})
	await settle(4)
	check(absf(ring.bar.value - 0.5) < 0.01 and ring.counter.text.begins_with("Jour 3 sur 5"), "Continuer : 2 jours sur 4 = 50 %% (%s)" % ring.counter.text)
	var rows: Array = ring._days_box.get_children()
	var marks: Array[String] = []
	for row: Node in rows: marks.append(str((row.get_child(0).get_child(0) as Label).text))
	check(marks.has("✓") and marks.has("▸") and marks.has("·"), "Continuer : jours passés, en cours, à venir (%s)" % ",".join(marks))
	var last := str((rows.back().get_child(0).get_child(1) as Label).text)
	check(last.contains("sam. 21 nov.") and last.contains("match contre Club Adverse"), "Continuer : l'arrêt prévu écrit son vrai motif (%s)" % last)
	check(ring.detail.text.begins_with("Arrêt prévu : sam. 21 nov."), "Continuer : ligne « Arrêt prévu » (%s)" % ring.detail.text)
	check(ring.tip.text == "« Un conseil réel. »", "Continuer : conseil de Gabi réel")
	check(ring.stop_button.visible and not ring.stop_button.disabled and ring.hint.text == "Échap : arrêter", "Continuer : « Arrêter → » et « Échap : arrêter »")
	check(gold_count(ring) == 0, "Continuer : l'or reste dans l'anneau (aucun contrôle doré)")
	ring.stop_button.pressed.emit()
	check(ring.stopping and stopped[0] == 1, "Continuer : « Arrêter → » agit")
	ring.finish({"days": 2, "to": "2026-11-19", "stop": {"label": "Jour de match", "detail": "Rien d'autre."}})
	await settle(3)
	check(ring.title.text == "Jour de match" and ring.close_button.visible and not ring.stop_button.visible, "Continuer : motif d'arrêt et « Fermer → »")
	ring.close_button.pressed.emit()
	check(not ring.visible, "Continuer : « Fermer → » ferme")
	# Sans arrêt prévu : ni pourcentage ni liste inventés.
	ring.begin({"date": "2026-11-17", "accent": Color("d43e47")}, false)
	ring.advance_to({"today": "2026-11-18", "days": 1})
	await settle(3)
	check(not ring.bar.determinate and not ring._days_box.visible and not ring.counter.text.contains(" sur ") and ring.detail.text.is_empty(), "Sans arrêt prévu : aucune donnée inventée (%s)" % ring.counter.text)
	check(windows().is_empty(), "Continuer : aucune fenêtre")
	ring.dismiss()
	host.queue_free()

func in_game() -> void:
	var club: Dictionary = app.model.club
	var context: Dictionary = app._command_wait_context("new_career")
	check(str(context.club_name) == str(club.get("presentation", club).get("name", club.get("name", ""))) and not str(context.club_name).is_empty(), "Données : nom du club lu du modèle (%s)" % context.club_name)
	check(context.photo == true and app._command_wait_context("advance_day").photo == false, "Données : photo pour la création, pas pour le passage de jour")
	var stadium := str(club.get("presentation", club).get("stadium", ""))
	check(str(context.stadium) == stadium, "Données : stade lu du modèle (%s)" % stadium)
	check(str(context.season) == "saison " + app.G.season_label(app.model.meta.get("season", 1)), "Données : saison lue du modèle (%s)" % context.season)
	var overlay: Control = app.command_wait_overlay
	# Stade.
	overlay.set_context(context)
	overlay.present("Création de la carrière…", false, 0.0)
	await settle(8)
	check(overlay.stage_mode() and overlay.get_node("CommandWaitFrame/CommandWaitLegend").visible == not stadium.is_empty(), "Jeu : le lieu est celui du club")
	check(overlay.get_node("CommandWaitFrame/CommandWaitNextNote").visible, "Jeu : anecdotes à parcourir")
	await shot("stade")
	overlay.dismiss()
	await settle(4)
	# Panneau, après 20 s.
	var day: Dictionary = app._command_wait_context("advance_day")
	overlay.set_context(day)
	overlay.present("Passage au jour suivant…", false, 0.0)
	await settle(6)
	check(not overlay.stage_mode() and overlay.panel_visible(), "Jeu : passage de jour = panneau")
	overlay._since_ms -= 24000
	overlay._layout()
	await settle(4)
	await shot("panneau")
	check(gold_count(overlay) == 0 and windows().is_empty(), "Jeu : ni or ni fenêtre")
	overlay.dismiss()
	await settle(6)
	# Ovale : dates d'exemple à quatre jours du départ pour la capture (l'adversaire est lu du modèle).
	var ctx: Dictionary = app._continue_context()
	var from := str(ctx.date)
	var next: Variant = ctx.next
	var opponent := str(next.get("opponent", "")) if next is Dictionary else ""
	var origin := Time.get_unix_time_from_datetime_string(from + "T12:00:00")
	var target := Time.get_date_string_from_unix_time(origin + 4 * 86400)
	var demo_next := {"date": target, "opponent": opponent}
	ctx["next"] = demo_next
	app.continue_progress.begin(ctx, false)
	app.continue_progress.advance_to({"today": Time.get_date_string_from_unix_time(origin + 2 * 86400), "days": 2, "next": demo_next})
	app.continue_progress._started_ms -= 22000
	await settle(8)
	await shot("ovale")
	check(app.continue_progress.running and app.continue_progress.stop_button.visible, "Jeu : Continuer — « Arrêter → » présent")
	app.continue_progress.dismiss()
	check(windows().is_empty(), "Jeu : aucune fenêtre ouverte")
