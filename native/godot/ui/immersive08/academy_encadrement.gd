extends "res://ui/immersive08/academy_passerelles.gd"
## Écran Formation (découpe de academy_canvas.gd, sans changement) : onglet Encadrement (staff de l’académie).

# --- Encadrement -------------------------------------------------------------------------------------------------------

func _staff_page() -> void:
	var panel := D.rect(self, Rect2(0, 216, WIDTH, 980), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	panel.name = "AcademyStaffPane"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	Kit.titre(panel, 24, 52, "Le centre de formation", 30, 1200)
	Kit.texte(panel, 24, 86, Copy.notice("academy", pathway.get("description", "Aucune donnée d’encadrement disponible.")), Charte.IVOIRE_2, 1700, 18)
	var labels := [["Éducateurs", G.n(pathway.get("coaches", "—")), "Staff", "AcademyTileCoaches"], ["Installations", G.n(pathway.get("facilities", "—")), "Club", "AcademyTileFacilities"], ["Cohésion", G.n(pathway.get("cohesion", "—")), "Centre", "AcademyTileCohesion"]]
	var largeur := (WIDTH - 48.0 - 2 * 24.0) / 3.0
	for i in labels.size():
		var item: Array = labels[i]
		var tuile := Button.new()
		tuile.name = str(item[3])
		tuile.flat = true
		tuile.focus_mode = Control.FOCUS_ALL
		tuile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tuile.accessibility_name = "%s : %s" % [str(item[0]), str(item[1])]
		tuile.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 16, 0))
		tuile.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 16, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 16, 0)
		focus.set_border_width_all(2)
		tuile.add_theme_stylebox_override("focus", focus)
		var destination: String = item[2]
		tuile.pressed.connect(func(): app._navigate(destination))
		panel.add_child(tuile)
		D.place(tuile, Rect2(24 + i * (largeur + 24.0), 122, largeur, 140))
		Kit.marqueur(tuile, Rect2(12, 24, 6, 92), Charte.IVOIRE if i == 0 else Charte.IVOIRE_2)
		D.text(tuile, 34, 40, str(item[0]).to_upper(), 16, Charte.IVOIRE_2, 700, largeur - 60)
		D.text(tuile, 34, 108, str(item[1]), 64, Charte.IVOIRE, 800, largeur - 60).add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		D.text(tuile, largeur - 20, 124, "ouvrir →", 17, Charte.IVOIRE_2, 600, 160, HORIZONTAL_ALIGNMENT_RIGHT)
		for enfant in tuile.get_children():
			if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Kit.etiquette(panel, 24, 318, "Encadrement de l’académie", 600)
	for i in 3:
		var p: Dictionary = staff[i] if i < staff.size() else {}
		var etiquette: Array = [["Éducateurs", "Niveau " + G.n(pathway.get("coaches", "—"))], ["Installations", "Niveau " + G.n(pathway.get("facilities", "—"))], ["Cohésion du centre", G.n(pathway.get("cohesion", "—")) + " / 100"]][i]
		var ligne := Button.new()
		ligne.name = "AcademyStaffRow" + str(i)
		ligne.flat = true
		ligne.focus_mode = Control.FOCUS_ALL
		ligne.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ligne.accessibility_name = "%s : %s" % [str(p.get("name", etiquette[0])), str(p.get("role", etiquette[1]))]
		ligne.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 8, 0))
		ligne.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 8, 0))
		var focus_ligne := C.box(Color.TRANSPARENT, Charte.IVOIRE, 8, 0)
		focus_ligne.set_border_width_all(2)
		ligne.add_theme_stylebox_override("focus", focus_ligne)
		ligne.pressed.connect(func(): app._navigate("Staff"))
		panel.add_child(ligne)
		D.place(ligne, Rect2(24, 336 + i * 64, 1100, 60))
		_portrait(ligne, p, Rect2(8, 6, 48, 48), false, ["training-coach", "mail-trainer", "mail-medical"][i])
		D.text(ligne, 72, 28, str(p.get("name", etiquette[0])), 24, Charte.IVOIRE, 700, 700)
		D.text(ligne, 72, 52, str(p.get("role", etiquette[1])), 18, Charte.IVOIRE_2, 500, 700)
		for enfant in ligne.get_children():
			if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gerer := Kit.lien(panel, Rect2(24, 560, 0, 40), "Gérer le centre →", func(): app._navigate("Centre"), "AcademyManageCentre", 20)
	gerer.tooltip_text = ""
	var suivi := Kit.lien(panel, Rect2(24, 608, 0, 40), "Suivi des jeunes →", func(): Pages.ouvrir(app, "suivi"), "AcademyFollowUp", 20)
	suivi.tooltip_text = ""
	var equipe := Kit.lien(panel, Rect2(24, 656, 0, 40), "Ouvrir le staff →", func(): app._navigate("Staff"), "AcademyOpenStaff", 20)
	equipe.tooltip_text = ""
