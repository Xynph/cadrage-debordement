extends "res://ui/contextual/match_equipe_outils.gd"
## Onglet Composition, terrain : médaillons des quinze, terrain dessiné, glisser-déposer des remplaçants.
## Chaîne d'héritage de la fenêtre : socle ← outils ← terrain ← composition ← cartes ← consignes ← roles ← match_equipe.gd.

## Terrain rayé : quinze médaillons à leur poste, avants à gauche.
class Terrain extends Control:
	const Charte = preload("res://ui/charte.gd")
	var k := 1.0
	var places: Dictionary = {}
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: placer()
	func placer() -> void:
		for enfant in get_children():
			if not enfant is Control or not places.has(enfant): continue
			var c: Control = enfant
			var cible: Vector2 = places[enfant]
			var centre := Vector2(cible.x / 100.0 * size.x, cible.y / 100.0 * size.y)
			c.size = c.get_combined_minimum_size()
			c.position = Vector2(clampf(centre.x - c.size.x / 2.0, 2.0, maxf(2.0, size.x - c.size.x - 2.0)), clampf(centre.y - c.size.y / 2.0, 2.0, maxf(2.0, size.y - c.size.y - 2.0)))
	## Pelouse à angles droits, bandes à plat (charte §3 : ni arrondi, ni voile en dégradé).
	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0: return
		var forme := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
		var bande := 60.0 * k
		var x := 0.0
		var n := 0
		while x < size.x:
			draw_rect(Rect2(x, 0, minf(bande, size.x - x), size.y), Charte.PELOUSE if n % 2 == 0 else Charte.PELOUSE_2)
			x += bande
			n += 1
		var epais := maxf(1.0, 2.0 * k)
		for paire: Array in [[0.05, 0.55, false], [0.27, 0.25, true], [0.5, 0.45, false], [0.73, 0.25, true], [0.95, 0.55, false]]:
			var lx := size.x * float(paire[0])
			var couleur := Color(Charte.IVOIRE, float(paire[1]))
			if paire[2]: draw_dashed_line(Vector2(lx, 0), Vector2(lx, size.y), couleur, epais, 8.0 * k)
			else: draw_line(Vector2(lx, 0), Vector2(lx, size.y), couleur, epais)
		var bord := forme.duplicate()
		bord.append(forme[0])
		draw_polyline(bord, Charte.PELOUSE_BORD, maxf(1.0, k), true)

## Médaillon d'un joueur : anneau d'énergie, portrait, numéro, niveau, nom et note, état.
class Medaillon extends Button:
	const C = preload("res://ui/immersive08/components.gd")
	var k := 1.0
	var energie := 100.0
	var teinte := C.MINT
	var numero := ""
	var niveau := ""
	var niveau_bas := -1
	var niveau_haut := -1
	var choisi := false
	var cible := false
	var calque: Control
	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		for etat in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]: add_theme_stylebox_override(etat, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	## Rayon extérieur de l'anneau (unités de la maquette) : visages bien lisibles (demande de Léo).
	const R := 37.0
	func centre() -> Vector2:
		return Vector2(size.x / 2.0, (R + 7.0) * k)
	func _draw() -> void:
		var c := centre()
		# Disque de terrain (seule forme ronde admise), sans ombre ; joueur choisi : anneau ivoire épais (et « X choisi »
		# écrit sous le terrain), jamais d'or.
		if choisi: draw_arc(c, (R + 4.5) * k, 0, TAU, 64, C.IVORY, 5.0 * k, true)
		elif cible:
			draw_circle(c, (R + 6.0) * k, Color(C.MINT, 0.18))
			draw_arc(c, (R + 5.0) * k, 0, TAU, 64, C.MINT, 3.0 * k, true)
		elif is_hovered(): draw_circle(c, (R + 6.0) * k, Color(C.IVORY, 0.24))
		if has_focus() and not choisi: draw_arc(c, (R + 6.0) * k, 0, TAU, 64, C.IVORY, 2.0 * k, true)
		draw_circle(c, R * k, C.BG)
		draw_arc(c, (R - 2.5) * k, 0, TAU, 64, C.LINE, 5.0 * k, true)
		if energie > 0.0: draw_arc(c, (R - 2.5) * k, -PI / 2.0, -PI / 2.0 + TAU * clampf(energie / 100.0, 0.0, 1.0), 64, teinte, 5.0 * k, true)
		draw_circle(c, (R - 5.0) * k, C.BG)
	func dessiner_badges() -> void:
		var c := centre()
		var police: Font = C.EXTRA_BOLD
		var corps := maxi(12, roundi(16.0 * k))
		var rond := c + Vector2(-R + 6.0, R - 8.0) * k
		calque.draw_circle(rond, 14.0 * k, C.BG)
		calque.draw_arc(rond, 13.0 * k, 0, TAU, 32, C.IVORY, 2.0 * k, true)
		var largeur := police.get_string_size(numero, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x
		calque.draw_string(police, rond + Vector2(-largeur / 2.0, (police.get_ascent(corps) - police.get_descent(corps)) / 2.0), numero, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, C.IVORY)
		if niveau.is_empty(): return
		var corps_n := maxi(12, roundi(17.0 * k))
		var l := police.get_string_size(niveau, HORIZONTAL_ALIGNMENT_LEFT, -1, corps_n).x
		var haut_b := 28.0 * k
		var large := maxf(haut_b, l + 12.0 * k)
		var boite := Rect2(c + Vector2(R + 12.0, 0.0) * k - Vector2(large, (R + 7.0) * k), Vector2(large, haut_b))
		# Badge du niveau : lettre du staff en pastille ronde à sa couleur (double : deux moitiés), ni ombre ni or.
		var Notation: Script = load("res://ui/notation_staff.gd")
		var style := StyleBoxFlat.new()
		style.bg_color = Notation.couleur(niveau_haut)
		style.set_corner_radius_all(roundi(haut_b / 2.0))
		calque.draw_style_box(style, boite)
		if niveau_bas != niveau_haut:
			var gauche := StyleBoxFlat.new()
			gauche.bg_color = Notation.couleur(niveau_bas)
			gauche.corner_radius_top_left = roundi(haut_b / 2.0)
			gauche.corner_radius_bottom_left = roundi(haut_b / 2.0)
			calque.draw_style_box(gauche, Rect2(boite.position, Vector2(boite.size.x / 2.0, haut_b)))
		calque.draw_string(police, Vector2(boite.position.x + (boite.size.x - l) / 2.0, boite.position.y + (boite.size.y + police.get_ascent(corps_n) - police.get_descent(corps_n)) / 2.0), niveau, HORIZONTAL_ALIGNMENT_LEFT, -1, corps_n, Notation.couleur_texte(niveau_haut if niveau_bas == niveau_haut else niveau_bas))

func _terrain(centre: VBoxContainer) -> void:
	var cadre := Control.new()
	cadre.name = "TeamPitch"
	cadre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	centre.add_child(cadre)
	# Le terrain est une tuile posée sur le fond : son ombre vient d'un fond plein juste derrière le dessin.
	var ombre := Panel.new()
	ombre.name = "TeamPitchOmbre"
	ombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ombre.add_theme_stylebox_override("panel", Charte.ombrer_droit(_boite(C.BG)))
	S.full(ombre)
	cadre.add_child(ombre)
	var terrain := Terrain.new()
	terrain.name = "TeamPitchField"
	terrain.k = k
	terrain.mouse_filter = Control.MOUSE_FILTER_PASS
	S.full(terrain)
	cadre.add_child(terrain)
	var sens := _titre("SENS DE L'ATTAQUE ▸", 15, Color(C.IVORY, 0.7), 700)
	sens.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	sens.offset_left = px(14)
	sens.offset_top = px(10)
	cadre.add_child(sens)
	var lineup := _lineup()
	var notes: Dictionary = _direct().get("notes", {}) if _direct().get("notes") is Dictionary else {}
	var cartons: Dictionary = {}
	for carton: Variant in _direct().get("cartons", []):
		if carton is Dictionary: cartons[str(carton.get("id", ""))] = carton
	var p := _pilotage()
	var cibles: Array = []
	if not entrant_choisi.is_empty():
		for slot in lineup.size():
			if _autorise(slot, entrant_choisi): cibles.append(slot)
	for slot in mini(15, lineup.size()):
		var joueur: Variant = lineup[slot]
		var medaillon := Medaillon.new()
		medaillon.name = "TeamPlayer%d" % (slot + 1)
		medaillon.k = k
		medaillon.numero = str(MenuJoueur.numero_feuille(_live(), str(joueur.get("id", "")), slot + 1) if joueur is Dictionary else slot + 1)
		medaillon.choisi = poste_choisi == slot
		medaillon.cible = slot in cibles
		medaillon.custom_minimum_size.x = px(128)
		var pile := _v(3)
		pile.alignment = BoxContainer.ALIGNMENT_BEGIN
		pile.position = Vector2(0, px(2.0 * Medaillon.R + 16.0))
		pile.size = Vector2(px(128), 0)
		medaillon.add_child(pile)
		if joueur is Dictionary:
			var d := W.donnees_joueur(joueur, notes, cartons)
			var id := str(d.id)
			medaillon.energie = float(d.energie)
			medaillon.teinte = C.ALERT if bool(d.blesse) else teinte_energie(float(d.energie))
			medaillon.niveau = _niveau(joueur)
			var l_niv := _lettre_niveau(joueur)
			medaillon.niveau_bas = int(l_niv.bas)
			medaillon.niveau_haut = int(l_niv.haut)
			var diametre := px(2.0 * (Medaillon.R - 6.0))
			var portrait := _portrait(joueur, diametre, -1.0, true)
			portrait.position = Vector2((px(128) - diametre) / 2.0, px(Medaillon.R + 7.0) - diametre / 2.0)
			medaillon.add_child(portrait)
			var etiquette := _panneau(_plat(Color(C.BG, 0.85)))
			var style_et := etiquette.get_theme_stylebox("panel") as StyleBoxFlat
			style_et.content_margin_left = px(7)
			style_et.content_margin_right = px(7)
			etiquette.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ligne := _h(5)
			etiquette.add_child(ligne)
			# Le clic sur le médaillon choisit le poste ; le NOM est un lien vers sa fiche (mini-fiche au survol).
			ligne.add_child(_nom_joueur(id, nom_court(str(d.nom)), 17, "TeamPlayerName", 104, C.font(700)))
			if notes.has(id):
				var note := _titre(("%.1f" % float(d.note)).replace(".", ","), 17, C.IVORY, 800)
				note.name = "TeamPlayerNote"
				ligne.add_child(note)
			pile.add_child(etiquette)
			var humeur := Pilotage.etat_joueur(p, id)
			var sens_humeur := Pilotage.sens_etat(str(humeur.get("etat", "")))
			var puce_texte := ""
			var puce_teinte := C.MINT
			if bool(d.blesse):
				puce_texte = "Blessé"
				puce_teinte = C.ALERT
			elif bool(d.carton):
				puce_texte = "Carton"
				puce_teinte = C.IVORY
			elif not str(MenuJoueur.texte_badge(_live(), id)[0]).is_empty():
				# Changement en attente du prochain arrêt de jeu (sortie, rôle, consignes) : « ⧗ », discret.
				puce_texte = str(MenuJoueur.texte_badge(_live(), id)[0])
				puce_teinte = C.IVORY
			elif not humeur.is_empty() and sens_humeur != 0:
				puce_texte = str(humeur.label)
				puce_teinte = C.MINT if sens_humeur > 0 else C.ALERT
			if not puce_texte.is_empty():
				# Pastille de la charte (§7.1) : voile tiré de la teinte + mot dans la teinte, coins 6 px ; jamais un
				# aplat doré (« Valider et reprendre » reste l'unique aplat doré de la fenêtre).
				var voile := Charte.VOILE_DORE if puce_teinte == C.ALERT else (Charte.VOILE_VERT if puce_teinte == C.MINT else Charte.PANNEAU_2)
				var puce := _panneau(_plat(voile))
				puce.name = "TeamPlayerState"
				var style_p := puce.get_theme_stylebox("panel") as StyleBoxFlat
				style_p.set_corner_radius_all(Charte.RAYON_PETIT)
				style_p.content_margin_left = px(8)
				style_p.content_margin_right = px(8)
				puce.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				puce.mouse_filter = Control.MOUSE_FILTER_IGNORE
				puce.add_child(_texte(puce_texte, 12, puce_teinte, _gras))
				pile.add_child(puce)
			medaillon.tooltip_text = "%d · %s · %s\nÉnergie %d %%%s" % [slot + 1, str(d.poste), str(d.nom), roundi(float(d.energie)), ("\nNote du match %s" % ("%.1f" % float(d.note)).replace(".", ",")) if notes.has(id) else ""]
			var eligibles := PackedStringArray()
			for x: Variant in _entrants(slot): eligibles.append(str(x))
			medaillon.set_drag_forwarding(Callable(), _peut_deposer.bind(eligibles), _deposer.bind(slot))
		else:
			medaillon.energie = 0.0
			pile.add_child(_titre("Poste vacant", 16, C.MUTED, 700))
			medaillon.tooltip_text = "%d · poste vacant" % (slot + 1)
		var calque := Control.new()
		calque.name = "Badges"
		calque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		S.full(calque)
		medaillon.add_child(calque)
		medaillon.calque = calque
		calque.draw.connect(medaillon.dessiner_badges)
		medaillon.pressed.connect(func(): choisir_poste(slot))
		if not entrant_choisi.is_empty() and not medaillon.cible: medaillon.modulate.a = 0.45
		medaillon.custom_minimum_size.y = px(2.0 * Medaillon.R + 16.0 + 50.0)
		terrain.add_child(medaillon)
		terrain.places[medaillon] = PLACES.get(slot + 1, Vector2(50, 50))
		medaillons[slot] = medaillon
	var aide := _panneau(_plat(Color(C.BG, 0.85)))
	aide.name = "TeamPitchHint"
	var style_aide := aide.get_theme_stylebox("panel") as StyleBoxFlat
	style_aide.content_margin_left = px(12)
	style_aide.content_margin_right = px(12)
	style_aide.content_margin_top = px(4)
	style_aide.content_margin_bottom = px(4)
	aide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texte_aide := "Glisse un remplaçant sur un joueur pour le changer · ou clique un joueur puis un remplaçant"
	var teinte_aide := Color(C.IVORY, 0.75)
	if not _message.is_empty():
		texte_aide = _message
		teinte_aide = _message_teinte
	elif poste_choisi >= 0 and poste_choisi < lineup.size() and lineup[poste_choisi] is Dictionary:
		var n := _entrants(poste_choisi).size()
		texte_aide = "%s choisi : %s" % [nom_court(str(lineup[poste_choisi].get("name", ""))), ("%d remplaçant%s possible%s, en vert sur le banc" % [n, "s" if n > 1 else "", "s" if n > 1 else ""]) if n > 0 else ("aucun remplaçant autorisé à ce poste" if bool(_live().get("paused", false)) else "les changements se font match arrêté")]
	elif not entrant_choisi.is_empty():
		texte_aide = "%s prêt à entrer : clique le joueur à remplacer (cerclé de vert)" % nom_court(str(_reserve(entrant_choisi).get("name", "")))
	var ligne_aide := _texte(texte_aide, 12, teinte_aide)
	ligne_aide.name = "TeamStatus"
	aide.add_child(ligne_aide)
	aide.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	aide.grow_horizontal = Control.GROW_DIRECTION_BOTH
	aide.grow_vertical = Control.GROW_DIRECTION_BEGIN
	aide.offset_bottom = -px(10)
	cadre.add_child(aide)
	terrain.placer.call_deferred()

func _peut_deposer(_a: Vector2, data: Variant, eligibles: PackedStringArray) -> bool:
	return data is Dictionary and eligibles.has(str(data.get("equipe_entrant", "")))

func _deposer(_a: Vector2, data: Variant, slot: int) -> void:
	if data is Dictionary: remplacer(slot, str(data.get("equipe_entrant", "")))

## Glisser un remplaçant : son portrait suit la souris, les joueurs qu'il peut remplacer sont cerclés.
func _glisser(_a: Vector2, joueur: Dictionary, tuile: Control) -> Variant:
	var apercu := _portrait(joueur, px(56))
	apercu.modulate.a = 0.9
	tuile.set_drag_preview(apercu)
	return {"equipe_entrant": str(joueur.get("id", ""))}
