extends RefCounted
## Zone de lecture cliquable (règle de Léo : tout ce qui ressemble à une tuile, un anneau, une jauge, une pastille ou un
## chiffre ouvre l'écran qui le détaille ; jamais une petite fenêtre). Rend n'importe quel contrôle (anneau, jauge, tuile
## chiffre, pastille) activable à la souris (clic gauche) et au clavier (Entrée / Espace), avec la main au survol, un
## léger éclaircissement et l'anneau de focus de la charte. L'info-bulle annonce la destination.
## Exemple : `LienZone.relier(anneau, "SupportLien_Moral", "Vestiaire", func(): app._navigate("Vestiaire"))`.
const Charte = preload("res://ui/charte.gd")

static func relier(zone: Control, nom: String, destination: String, action: Callable) -> Control:
	zone.name = nom
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.focus_mode = Control.FOCUS_ALL
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var bulle := "Ouvrir · " + destination
	zone.tooltip_text = bulle if zone.tooltip_text.is_empty() else zone.tooltip_text + "\n" + bulle
	zone.accessibility_name = zone.tooltip_text
	zone.set_meta("lien_destination", destination)
	# Survol et appui : retour commun des tuiles cliquables (ui/retour_tuile.gd).
	load("res://ui/retour_tuile.gd").brancher(zone, zone, Charte.RAYON_PETIT)
	zone.focus_entered.connect(func(): zone.queue_redraw())
	zone.focus_exited.connect(func(): zone.queue_redraw())
	zone.draw.connect(func():
		if zone.has_focus():
			var anneau := StyleBoxFlat.new()
			anneau.draw_center = false
			anneau.border_color = Charte.IVOIRE
			anneau.set_border_width_all(2)
			anneau.set_corner_radius_all(Charte.RAYON_PETIT)
			zone.draw_style_box(anneau, Rect2(Vector2(-3, -3), zone.size + Vector2(6, 6))))
	zone.gui_input.connect(func(evenement: InputEvent):
		var clic: bool = evenement is InputEventMouseButton and evenement.button_index == MOUSE_BUTTON_LEFT and evenement.pressed
		var touche: bool = evenement is InputEventKey and evenement.pressed and not evenement.echo and evenement.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		if clic or touche:
			zone.accept_event()
			action.call())
	return zone
