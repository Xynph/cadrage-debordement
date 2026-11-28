extends "res://ui/immersive08/match_avant_affiche.gd"
## Écran « Avant-match » (voir match_avant.gd) — Vérifications : « Ta feuille » (titulaires, condition, blessés) et « Conditions du match » (météo, vent, arbitre).

## 1. Ta feuille : repères de condition des quinze titulaires (clic = fiche, survol = mini-fiche), alerte en mots.
func _feuille(model: Dictionary, etat: Dictionary) -> Control:
	var legende := "%d / %d" % [etat.remplis, etat.total]
	if etat.valide and etat.total > 0: legende += " · complète"
	var column := _tuile("TuileFeuille", "Ta feuille", legende)
	var selection: Dictionary = model.get("selection", {})
	var conditions: Array = []
	var noms: Array = []
	var ids: Array = []
	for i in 15: conditions.append(-1.0); noms.append(""); ids.append("")
	for assignment: Dictionary in selection.get("slots", []):
		var slot := int(assignment.get("slot", -1))
		if slot < 0 or slot >= 15: continue
		var person := Present.player(model, str(assignment.get("playerId", "")))
		if person.is_empty() or not (person.get("condition") is float or person.get("condition") is int): continue
		conditions[slot] = float(person.condition)
		noms[slot] = str(person.get("name", ""))
		ids[slot] = str(person.get("id", ""))
	# Petite fenêtre (1280 × 720) : deux rangées de repères (1 à 8, 9 à 15) pour garder des cibles d'au moins 20 px.
	var deux_rangees := C.dense()
	var barres := VBoxContainer.new()
	barres.name = "FeuilleConditions"
	barres.add_theme_constant_override("separation", M(4))
	barres.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rangees: Array[HBoxContainer] = []
	for r in (2 if deux_rangees else 1):
		var rangee := HBoxContainer.new()
		rangee.add_theme_constant_override("separation", M(3))
		rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rangee.size_flags_vertical = Control.SIZE_EXPAND_FILL
		barres.add_child(rangee)
		rangees.append(rangee)
	barres.custom_minimum_size.y = M(270 if deux_rangees else 150)
	for i in 15:
		var barre := Barre.new()
		barre.name = "FeuilleBarre%d" % (i + 1)
		barre.valeur = conditions[i]
		barre.numero = i + 1
		barre.mini = CONDITION_MINI
		barre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		barre.size_flags_vertical = Control.SIZE_EXPAND_FILL
		barre.custom_minimum_size = Vector2(M(18), M(132 if deux_rangees else 130))
		if not str(ids[i]).is_empty():
			barre.tooltip_text = ""
			barre.accessibility_name = "N° %d, %s, condition %d %%" % [i + 1, noms[i], roundi(conditions[i])]
			var id: String = ids[i]
			barre.pressed.connect(func(): _ouvrir_joueur(id))
			MiniFiche.lier(app, barre, id, "squad")
			# Le (i) occupe sa propre rangée en haut de la barre (sinon il recouvre la valeur de condition).
			var info_barre := barre.find_child("CarteJoueurInfo_*", true, false) as Control
			if info_barre != null:
				barre.reserve_info = 18.0
				var centrer := func():
					if is_instance_valid(info_barre) and is_instance_valid(barre): info_barre.position = Vector2((barre.size.x - info_barre.size.x) / 2.0, 1.0)
				barre.resized.connect(centrer)
				centrer.call()
		else:
			barre.disabled = true
			barre.mouse_default_cursor_shape = Control.CURSOR_ARROW
		rangees[1 if deux_rangees and i >= 8 else 0].add_child(barre)
	if deux_rangees:
		var vide := Control.new()
		vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rangees[1].add_child(vide)
	column.add_child(barres)
	var alerte: bool = etat.incomplete or etat.bas.size() > 0
	var note := HBoxContainer.new()
	note.name = "FeuilleAlerte"
	note.add_theme_constant_override("separation", M(6))
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var symbole := C.icon("warning" if alerte else "check", roundi(14 / .75), Charte.D if alerte else Charte.V)
	symbole.custom_minimum_size = Vector2(M(14), M(14))
	symbole.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	note.add_child(symbole)
	if etat.incomplete or etat.bas.is_empty():
		var texte_simple := (str(etat.erreurs[0]) if not etat.erreurs.is_empty() else "Il manque des joueurs sur la feuille.") if etat.incomplete else "Tous les titulaires à %d %% ou plus" % CONDITION_MINI
		var phrase := lignes(texte_simple, 13, Charte.IVOIRE, 2, false, 500)
		phrase.name = "FeuilleAlerteTexte"
		C.fill(phrase)
		note.add_child(phrase)
	else:
		# Les joueurs sous le repère sont des noms : clic = fiche complète, survol = mini-fiche.
		var flux := HFlowContainer.new()
		flux.add_theme_constant_override("h_separation", M(4))
		flux.add_theme_constant_override("v_separation", 0)
		flux.mouse_filter = Control.MOUSE_FILTER_IGNORE
		C.fill(flux)
		var intro_alerte := texte("%d titulaire%s sous %d %% :" % [etat.bas.size(), "s" if etat.bas.size() > 1 else "", CONDITION_MINI], 13, Charte.IVOIRE, false, 500)
		intro_alerte.add_theme_font_override("font", C.BODY)
		flux.add_child(intro_alerte)
		for b: Dictionary in etat.bas.slice(0, 2):
			var identifiant := str(b.id)
			var nom_lien := _bouton_lien(str(b.name), _ouvrir_joueur.bind(identifiant), "FeuilleAlerteNom_" + identifiant.validate_node_name(), 13, true)
			nom_lien.tooltip_text = ""
			MiniFiche.lier(app, nom_lien, identifiant, "squad")
			flux.add_child(nom_lien)
			var suite_nom := texte("(n° %d) à %d %%" % [b.slot + 1, b.condition], 13, Charte.IVOIRE, false, 500)
			suite_nom.add_theme_font_override("font", C.BODY)
			flux.add_child(suite_nom)
		note.add_child(flux)
	column.add_child(note)
	# L'état du groupe est un lien entier (blessés, fatigue, forme) vers l'Effectif.
	var injured := int(Present.group(model).get("injured", 0))
	var groupe := _bouton_lien(("%d blessé%s écarté%s" % [injured, "s" if injured > 1 else "", "s" if injured > 1 else ""] if injured > 0 else "Aucun blessé") + " · état du groupe →", func(): _aller("Effectif"), "MatchOpenSquad", 13)
	groupe.tooltip_text = "Ouvrir l'effectif : blessures, fatigue, forme"
	column.add_child(groupe)
	_pousse(column)
	var liens_feuille: Array = [["Vérifier la feuille →", func(): _aller("Composition"), "MatchOpenSheet", "Ouvrir la composition"]]
	# Tests physiques des joueurs revenus de blessure (idée FM27 n° 36) : sous-page de l'avant-match.
	var lien_tests: Array = Tests.lien(self, model)
	if not lien_tests.is_empty(): liens_feuille.append(lien_tests)
	_liens(column, liens_feuille)
	return _tile_of(column)

## Barre de condition d'un titulaire : valeur au-dessus (jamais la couleur seule), numéro dessous, repère à 80 %.
class Barre extends Button:
	var valeur := -1.0
	var numero := 0
	var mini := 80
	var reserve_info := 0.0
	func _ready() -> void:
		flat = true
		for look in ["normal", "hover", "pressed", "focus", "disabled"]: add_theme_stylebox_override(look, StyleBoxEmpty.new())
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		resized.connect(queue_redraw)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	func _draw() -> void:
		var police: Font = Charte.TEXTE
		var taille := 12
		# Barres étroites (fenêtre 1280) : les valeurs voisines se décalent d'un étage pour ne pas se chevaucher.
		var etage: bool = size.x < float(taille) * 1.9
		var haut := float(taille) * (2.0 if etage else 1.0) + 4.0 + reserve_info
		var bas := float(taille) + 4.0
		var zone := Rect2(0, haut, size.x, maxf(4.0, size.y - haut - bas))
		draw_rect(zone, Charte.PANNEAU_2)
		var bas_niveau := valeur >= 0.0 and valeur < float(mini)
		if valeur >= 0.0:
			var hauteur := zone.size.y * clampf(valeur / 100.0, .04, 1.0)
			draw_rect(Rect2(zone.position.x, zone.end.y - hauteur, zone.size.x, hauteur), Charte.IVOIRE_3 if bas_niveau else Charte.IVOIRE_2)
		var y_mini := zone.end.y - zone.size.y * float(mini) / 100.0
		for x in range(0, int(zone.size.x), 6): draw_line(Vector2(zone.position.x + x, y_mini), Vector2(minf(zone.end.x, zone.position.x + x + 3), y_mini), Color(Charte.IVOIRE, .7), 1.0)
		# Sous le repère : « ! » devant la valeur, toujours (le signal ne tient jamais à la couleur seule).
		var texte_valeur := ("!" if bas_niveau else "") + ("%d" % roundi(valeur) if valeur >= 0.0 else "—")
		var y_valeur := haut - 4.0 - (float(taille) if etage and numero % 2 == 0 else 0.0)
		draw_string(police, Vector2(-4.0, y_valeur), texte_valeur, HORIZONTAL_ALIGNMENT_CENTER, size.x + 8.0, taille, Charte.D if bas_niveau else Charte.IVOIRE)
		draw_string(police, Vector2(0, size.y - 3.0), str(numero), HORIZONTAL_ALIGNMENT_CENTER, size.x, taille, Charte.IVOIRE_2)
		if is_hovered() or has_focus(): draw_rect(Rect2(0, 0, size.x, size.y), Charte.IVOIRE, false, 2.0 if has_focus() else 1.0)

## 2. Conditions du match : météo annoncée la veille, vent, conseil du staff, arbitre et ses quatre tendances en mots.
func _meteo(model: Dictionary, next: Dictionary, nous: int, data: Dictionary) -> Control:
	var bloc := MeteoTexte.avant_match(next, str(model.get("meta", {}).get("calendarToday", "")))
	var legende := "Annoncées la veille" if next.get("meteo") is Dictionary else ""
	var column := _tuile("TuileMeteo", "Conditions du match", legende)
	var annonce := MeteoTexte.annonce(next)
	var arbitre: Dictionary = data.get("arbitre") if data.get("arbitre") is Dictionary and not str(data.arbitre.get("nom", "")).is_empty() else {}
	if annonce.is_empty():
		var message := lignes(str(bloc.conseil), 15, Charte.IVOIRE, 2, false, 600)
		message.name = "MeteoAnnonce"
		column.add_child(message)
		column.add_child(lignes("Annoncées la veille", 13, Charte.IVOIRE_2, 2))
	else:
		var meteo: Dictionary = next.meteo
		var ciel_ligne := HBoxContainer.new()
		ciel_ligne.add_theme_constant_override("separation", M(8))
		ciel_ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icone := TextureRect.new()
		icone.texture = icone_meteo(meteo, Charte.IVOIRE)
		icone.custom_minimum_size = Vector2(M(20), M(20))
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ciel_ligne.add_child(icone)
		var ciel := texte(str(bloc.ciel), 15, Charte.IVOIRE, false, 700)
		ciel.add_theme_font_override("font", C.BODY)
		ciel.name = "MeteoCiel"
		ciel_ligne.add_child(ciel)
		var pelouse := texte("· pelouse %s" % ("lourde" if str(meteo.get("terrain", "")) == "lourd" else "souple"), 13, Charte.IVOIRE_2, false, 500)
		pelouse.add_theme_font_override("font", C.BODY)
		ciel_ligne.add_child(pelouse)
		_rang(column, "Météo", ciel_ligne, "MeteoLigne")
		var phrase := phrase_vent(next, nous)
		var vent := HBoxContainer.new()
		vent.add_theme_constant_override("separation", M(8))
		vent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vent.add_child(_jauge_vent(int(meteo.get("vent", 0))))
		var mot_vent: String = ["Pas de vent notable", "Vent", "Grand vent"][clampi(int(meteo.get("vent", 0)), 0, 2)]
		# Deux lignes, une par période (sinon le mot du vent seul) : jamais tronquées, même en 1280.
		var lignes_vent := phrase_vent_lignes(next, nous)
		var detail_vent := lignes("\n".join(lignes_vent) if not lignes_vent.is_empty() else mot_vent, 13, Charte.IVOIRE, 2, false, 500)
		detail_vent.name = "MeteoVent"
		C.fill(detail_vent)
		vent.add_child(detail_vent)
		_rang(column, "Vent", vent, "MeteoVentLigne")
		var conseil_texte := MeteoTexte.conseil(annonce)
		if not conseil_texte.is_empty():
			var conseil := lignes("« %s »" % conseil_texte, 13, Charte.IVOIRE, 2, false, 500)
			conseil.name = "MeteoConseil"
			conseil.tooltip_text = conseil_texte
			conseil.mouse_filter = Control.MOUSE_FILTER_PASS
			column.add_child(conseil)
	if not arbitre.is_empty(): _arbitre(column, arbitre)
	_pousse(column)
	_liens(column, [["Adapter le plan de jeu →", func(): _aller("Plan de jeu"), "MatchOpenWeatherPlan", "Ouvrir le plan de jeu"]])
	return _tile_of(column)

func _jauge_vent(level: int) -> Control:
	var gauge := HBoxContainer.new()
	gauge.name = "MeteoForceVent"
	gauge.add_theme_constant_override("separation", M(3))
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var bar := Panel.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size = Vector2(M(6), M(8 + i * 5))
		bar.size_flags_vertical = Control.SIZE_SHRINK_END
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.IVOIRE if level > 0 and i <= level else Color(Charte.IVOIRE, .2)
		style.set_corner_radius_all(Charte.RAYON_PILULE)
		bar.add_theme_stylebox_override("panel", style)
		gauge.add_child(bar)
	return gauge

## Arbitre : nom et ses quatre tendances en mots (souple / équilibré / pointilleux) avec repères.
func _arbitre(column: VBoxContainer, arbitre: Dictionary) -> void:
	var bloc := VBoxContainer.new()
	bloc.name = "MatchArbitre"
	bloc.add_theme_constant_override("separation", M(1))
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bloc)
	var nom := texte(str(arbitre.get("nom", "")), 13, Charte.IVOIRE, false, 700)
	nom.add_theme_font_override("font", C.BODY)
	nom.name = "MatchArbitreNom"
	nom.clip_text = true
	nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var resume := str(arbitre.get("resume", "")).strip_edges()
	if not resume.is_empty():
		nom.tooltip_text = resume
		nom.mouse_filter = Control.MOUSE_FILTER_PASS
	_rang(bloc, "Arbitre", nom)
	for axe: Array in [["rucks", "Rucks"], ["melee", "Mêlée"], ["horsJeu", "Hors-jeu"], ["cartons", "Cartons"]]:
		_rang(bloc, str(axe[1]), jauge_arbitre(str(axe[1]), arbitre.get(axe[0])))
