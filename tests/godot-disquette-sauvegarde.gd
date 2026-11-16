extends SceneTree
## Disquette de sauvegarde en arrière-plan (décision de Léo, 16/11/2026), sans moteur :
##   - le pont lit « CD_EVENT {json} » sur la sortie d'erreur sans jamais l'annoncer comme erreur ;
##   - la disquette n'apparaît qu'après le délai, reste un minimum, puis s'efface ;
##   - écriture rapide : rien n'apparaît ; échec : rouge, visible jusqu'à la sauvegarde suivante ;
##   - elle ne capte ni souris ni focus (le jeu reste jouable pendant la sauvegarde).
## CD_DISQUETTE_CAPTURE=<dossier> : captures PNG (rendu fenêtré requis).
const Bridge = preload("res://engine_bridge.gd")
const SaveIndicator = preload("res://ui/save_indicator.gd")

var echecs: Array[String] = []
var controles := 0
var sortie := OS.get_environment("CD_DISQUETTE_CAPTURE")

func _initialize() -> void: call_deferred("executer")

func verifier(ok: bool, message: String) -> void:
	controles += 1
	if not ok:
		echecs.append(message)
		printerr("FAIL: ", message)

func attendre(secondes: float) -> void:
	var fin := Time.get_ticks_msec() + int(secondes * 1000.0)
	while Time.get_ticks_msec() < fin: await process_frame

func capture(nom: String) -> void:
	for i in 4: await process_frame
	if DisplayServer.get_name() == "headless" or sortie.is_empty(): return
	verifier(root.get_texture().get_image().save_png(sortie.path_join(nom + ".png")) == OK, "capture " + nom)

func executer() -> void:
	# 1. Pont : événements reconnus, lignes inconnues ignorées, jamais d'erreur annoncée.
	var bridge: Node = Bridge.new()
	root.add_child(bridge)
	var etats: Array[String] = []
	var erreurs: Array[String] = []
	bridge.persist_changed.connect(func(state: String, _m: String): etats.append(state))
	bridge.command_failed.connect(func(m: String): erreurs.append(m))
	bridge._report_stderr('CD_EVENT {"event":"persist","state":"started","command":"advance_day"}')
	bridge._report_stderr('CD_EVENT {"event":"persist","state":"done"}')
	verifier(not bridge.handle_engine_event('{"event":"persist","state":"bizarre"}'), "état inconnu ignoré")
	verifier(not bridge.handle_engine_event("pas du json"), "ligne illisible ignorée")
	verifier(not bridge.handle_engine_event('{"event":"autre","state":"done"}'), "événement inconnu ignoré")
	verifier(etats == ["started", "done"], "pont : début puis fin (%s)" % str(etats))
	verifier(erreurs.is_empty(), "pont : aucun événement pris pour une erreur (%s)" % str(erreurs))
	bridge._report_stderr("vraie erreur")
	verifier(erreurs.size() == 1, "pont : une vraie ligne d'erreur reste annoncée")
	bridge.queue_free()

	# Fond et bouton derrière la disquette : il doit rester cliquable.
	var fond := ColorRect.new()
	fond.color = Color("0b1012")
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(fond)
	var bouton := Button.new()
	bouton.text = "Continuer"
	bouton.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bouton.offset_left = -220; bouton.offset_top = -80; bouton.offset_right = -4; bouton.offset_bottom = -4
	root.add_child(bouton)
	var disquette: Control = SaveIndicator.new()
	disquette.show_delay = 0.2
	disquette.min_shown = 0.4
	disquette.fade = 0.0
	root.add_child(disquette)
	await process_frame
	verifier(disquette.mouse_filter == Control.MOUSE_FILTER_IGNORE, "disquette : ne capte pas la souris")
	verifier(disquette.focus_mode == Control.FOCUS_NONE, "disquette : ne prend pas le focus")
	verifier(not disquette.visible, "disquette : cachée au départ")

	# 2. Écriture rapide : rien n'apparaît.
	disquette.apply_state("started")
	await attendre(0.05)
	disquette.apply_state("done")
	await attendre(0.3)
	verifier(not disquette.visible and disquette.phase == "idle", "écriture rapide : rien n'apparaît")

	# 3. Écriture longue : apparaît après le délai, reste le minimum, puis s'efface.
	disquette.apply_state("started")
	await attendre(0.1)
	verifier(not disquette.visible, "avant le délai : encore cachée")
	await attendre(0.2)
	verifier(disquette.visible and disquette.phase == "shown", "après le délai : visible")
	verifier(disquette.tooltip_text == "Sauvegarde en cours…", "info-bulle pendant la sauvegarde")
	bouton.grab_focus()
	await process_frame
	verifier(bouton.has_focus(), "jeu jouable pendant la sauvegarde : le bouton garde le focus")
	var r := disquette.get_global_rect()
	verifier(r.position.x > 0 and r.end.x <= root.get_visible_rect().size.x and r.end.y <= root.get_visible_rect().size.y and r.size.x <= 40.0, "disquette discrète dans le coin bas droit (%s)" % str(r))
	await capture("01-disquette-en-cours")
	disquette.apply_state("done")
	await attendre(0.1)
	verifier(disquette.visible, "fin reçue : reste le temps minimum")
	await attendre(0.5)
	verifier(not disquette.visible and disquette.phase == "idle", "après le minimum : effacée")

	# 4. Échec : rouge, visible jusqu'à la sauvegarde suivante, puis redevient normale.
	disquette.apply_state("started")
	disquette.apply_state("failed")
	await process_frame
	verifier(disquette.visible and disquette.phase == "failed", "échec : visible tout de suite")
	verifier(disquette.tooltip_text.begins_with("La sauvegarde a échoué"), "échec : info-bulle explicite")
	await attendre(1.0)
	verifier(disquette.visible, "échec : reste affichée")
	await capture("02-disquette-echec")
	disquette.apply_state("started")
	verifier(disquette.phase == "shown", "nouvelle sauvegarde après échec : redevient normale")
	disquette.apply_state("done")
	await attendre(0.6)
	verifier(not disquette.visible, "sauvegarde réussie après échec : effacée")

	# 5. Mouvements réduits : aucun fondu ni pulsation, mêmes règles d'affichage.
	disquette.fade = 0.18
	disquette.apply_state("started", false)
	await attendre(0.3)
	verifier(disquette.visible and is_equal_approx(disquette.modulate.a, 1.0), "mouvements réduits : affichée d'un coup")

	if echecs.is_empty(): print("Disquette de sauvegarde Godot · %d contrôles réussis" % controles)
	else: printerr("Disquette de sauvegarde Godot · %d échec(s) sur %d" % [echecs.size(), controles])
	quit(0 if echecs.is_empty() else 1)
