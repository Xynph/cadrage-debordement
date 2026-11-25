extends "res://ui/immersive08/squad_entete.gd"
## Écran Effectif : une ligne de joueur (statut, cellules, comparaison, ouverture de la fiche, clavier) (découpe de squad_canvas.gd, sans changement).

# ---------------------------------------------------------------- lignes

## « 12/01 » : date du jour (état de la carrière) plus `jours`, ou "" si la date du jour est inconnue.
func _date_retour(jours: int) -> String:
	var meta: Dictionary = app.model.get("meta", {})
	var aujourdhui := str(meta.get("calendarToday", meta.get("date", "")))
	if aujourdhui.length() < 10: return ""
	var instant := Time.get_unix_time_from_datetime_string(aujourdhui.substr(0, 10) + "T00:00:00")
	if instant <= 0: return ""
	var date := Time.get_datetime_dict_from_unix_time(int(instant) + jours * 86400)
	return "%02d/%02d" % [date.day, date.month]

## Statut écrit de la ligne : {t : texte, c : couleur}. Blessé, suspendu et en sélection disent la raison et le retour connu.
func _statut(player: Dictionary) -> Dictionary:
	match U.indisponibilite(player):
		"blesse":
			var semaines := ceili(float(player.get("injury", 0)))
			var libelle := str(preload("res://ui/club_mail.gd").injury_label(app.model, player))
			var precision := "" if libelle == "Blessure" or libelle.length() > 12 else " (" + libelle.to_lower() + ")"
			var retour := _date_retour(semaines * 7)
			return {"t": "✚ Blessé" + precision + " · " + ("retour " + retour if not retour.is_empty() else "retour dans %d sem." % semaines), "c": C.ALERT, "pastille": "✚ " + (retour if not retour.is_empty() else "%d sem." % semaines)}
		"suspendu":
			var matchs := int(player.get("suspension", 1))
			return {"t": "! Suspendu (%d match%s)" % [matchs, "s" if matchs > 1 else ""], "c": C.ALERT}
		"selection":
			var retour := ""
			for sortie: Variant in app.model.get("international", {}).get("availability", {}).get("players", []):
				if sortie is Dictionary and str(sortie.get("id", "")) == str(player.get("id", "")) and str(sortie.get("returnDate", "")).length() >= 10:
					var jour := str(sortie.returnDate)
					retour = " · retour %s/%s" % [jour.substr(8, 2), jour.substr(5, 2)]
			return {"t": "◇ En sélection" + retour, "c": C.IVORY}
	return _statut_feuille(player)

## Place sur la feuille de match : Titulaire, Remplaçant ou Hors groupe.
func _statut_feuille(player: Dictionary) -> Dictionary:
	var numero: Variant = player.get("shirtNumber")
	var statut := str(player.get("status", ""))
	if statut in ["Titulaire", "Remplaçant"]: return {"t": statut, "c": C.IVORY if statut == "Titulaire" else C.MUTED}
	if numero is int or numero is float: return {"t": "Titulaire" if int(numero) <= 15 else "Remplaçant", "c": C.IVORY if int(numero) <= 15 else C.MUTED}
	return {"t": "Hors groupe", "c": C.MUTED}

func _ovale(row: Control, zone: Rect2, plein: bool) -> void:
	var forme := Panel.new()
	forme.name = "RosterNumeroOvale"
	var style := StyleBoxFlat.new()
	style.bg_color = Charte.IVOIRE if plein else Color.TRANSPARENT
	style.border_color = Charte.IVOIRE
	style.set_border_width_all(0 if plein else maxi(1, C.px(2)))
	style.set_corner_radius_all(maxi(1, C.px(zone.size.y)))
	forme.add_theme_stylebox_override("panel", style)
	forme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(forme)
	D.place(forme, zone)

func _row(player:Dictionary,index:int) -> void:
	var id := str(player.id)
	var h := float(C.reach(ROW_HEIGHT))
	var base := h / 2.0 + 7.0
	var selectionne: bool = id == app.selected_player
	var statut := _statut(player)
	var row:=Button.new()
	row.name="SquadPlayer"+id.replace(":","_")
	row.set_meta("player_id",id)
	row.set_meta("index",index)
	row.custom_minimum_size=Vector2(C.px(_lt),C.px(h))
	row.clip_contents = true
	row.focus_mode = Control.FOCUS_ALL
	row.accessibility_name = "%s · %s · %s · ouvrir la fiche" % [str(player.name), primary_caption(player), str(statut.t)]
	load("res://ui/survol_ligne.gd").appliquer(row, selectionne, Color.TRANSPARENT, app.accent)
	rows.add_child(row)
	var filet := Panel.new()
	filet.name = "RosterFilet"
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filet.add_theme_stylebox_override("panel", _plat(Charte.FILET, Color.TRANSPARENT, 0, 0))
	row.add_child(filet)
	filet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	filet.offset_top = -1.0
	row.pressed.connect(func(): _ouvrir(id, ""))
	row.focus_entered.connect(func(): if not _restaurant: _selectionner(id))
	row.gui_input.connect(_row_key.bind(row))
	var reason := U.watch_reason(player) if state.family==U.WATCH_FILTER else ""
	if not reason.is_empty(): row.accessibility_name += " · " + reason
	var notes := Notes.joueur(app.model,id)
	for colonne: Dictionary in _colonnes_actives:
		var x: float = colonne.x
		var l: float = colonne.w
		var a: HorizontalAlignment = colonne.a
		match str(colonne.k):
			"num":
				var numero: Variant = player.get("shirtNumber")
				if numero is int or numero is float:
					_ovale(row, Rect2(x, h / 2.0 - 8, 28, 16), int(numero) <= 15)
					D.text(row, x + 44, base, G.n(numero), 20, C.IVORY, 600, 44).name = "RosterNumero"
				else:
					D.text(row, x + 4, base, "—", 20, C.FAINT, 600, 30).name = "RosterNumero"
			"joueur": _cellule_joueur(row, player, index, h, base)
			"poste":
				var poste := D.text(row,x,base,primary_caption(player),19,C.IVORY,500,l,HORIZONTAL_ALIGNMENT_LEFT,true)
				poste.name = "RosterPrimaryPosition"
				var fitted := fitted_position(primary_caption(player), poste)
				if fitted != poste.text: poste.text = fitted
				poste.mouse_filter = Control.MOUSE_FILTER_PASS
				var principaux: Array[String] = []
				for numero: int in primary_numbers(player): principaux.append(str(numero))
				poste.tooltip_text = "Poste principal · %s · %s" % ["·".join(principaux),primary_caption(player)] if not principaux.is_empty() else primary_caption(player)
				if not secondary_numbers(player).is_empty(): poste.tooltip_text += "\nAutres postes · " + secondary_tooltip(player,app.model).replace("\n"," ; ")
			"etoiles":
				# Note au poste en lettre (même échelle que le Niveau, jamais de chiffre) puis familiarité (barres 5 crans + mot).
				var lettre := Notation.lettre_poste(app.model, player, _poste, true)
				var lw := Notation.largeur_note(lettre, 22 * 1.4)
				var note := Familiarite.poser_note(row, x, base, lettre, 22, lw, "RosterNotePoste")
				note.tooltip_text = "%s · %s" % [Etoiles.nom_poste(_poste), Notation.texte_note(lettre)]
				var xf := x + maxf(48.0, lw + 10.0)
				var fam := int(player.get("familiarite", -1))
				var lf := Familiarite.poser(row, xf, base, fam, 17, "RosterFamiliarite")
				var court := Etoiles.abrege(player)
				var xc := xf + maxf(lf, Familiarite.largeur(Familiarite.CONFIRME, 17)) + 10
				D.text(row, xc, base, court if not court.is_empty() else primary_caption(player), 17, C.MUTED, 600, maxf(20.0, l - (xc - x)), HORIZONTAL_ALIGNMENT_LEFT, true).name = "RosterPostePrincipal"
			"autres":
				var autres := D.text(row,x,base,secondary_caption(player),18,C.MUTED,600,l,HORIZONTAL_ALIGNMENT_LEFT,true)
				autres.name = "RosterSecondaryPositions"
				autres.mouse_filter = Control.MOUSE_FILTER_PASS
				autres.tooltip_text = secondary_tooltip(player,app.model)
				autres.accessibility_name = "Autres postes · "+autres.tooltip_text.replace("\n"," ; ")
				row.accessibility_name += " · autres postes " + autres.tooltip_text.replace("\n"," ; ")
			"niveau":
				# Notation façon FM (planche 24/11) : lettre du staff, relative à notre effectif.
				var note_n := Notation.resume(app.model,player,true)
				var w_n := Notation.largeur_note(note_n.niveau_note, 32)
				var pastille_n := Notation.pastille_note(row,x+l/2.0-w_n/2.0,h/2.0,note_n.niveau_note,32,"RosterLevel")
				var fl_niveau: Dictionary = Fleches.donnees(app, player).get("niveau", {})
				if not fl_niveau.is_empty(): Fleches.marquer_pastille(app, pastille_n, int(fl_niveau.cran), fl_niveau.serie, "Niveau", "Niveau_" + str(player.id).replace(":", "_"))
			"pot":
				var note_p := Notation.resume(app.model,player,true)
				Notation.pastille(row,x+l/2.0-19,h/2.0,int(note_p.potentiel),32,"RosterPotential")
			"cond":
				var condition: float = float(player.get("condition",0))
				var ton := C.MINT if condition >= 85 else (C.AMBER if condition >= 60 else C.ALERT)
				D.bar(row,Rect2(x,h/2.0-3,l-110,6),condition,ton)
				var repere := D.rect(row,Rect2(x + (l - 110) * .8 - 1,h/2.0-8,2,16),Charte.IVOIRE_2)
				repere.name = "RosterCondition80"
				D.text(row,x+l,base,"%d %%" % condition,19,C.IVORY,600,100,HORIZONTAL_ALIGNMENT_RIGHT,true).name = "RosterCondition"
			"fat":
				var fatigue: float = float(player.get("physicalLoad",0))
				D.text(row,x+l,base,G.n(fatigue),19,C.IVORY if fatigue>50 else C.MUTED,500,l,HORIZONTAL_ALIGNMENT_RIGHT,true)
			"age":
				D.text(row,x+l,base,G.n(player.get("age","—")),19,C.MUTED,500,l,HORIZONTAL_ALIGNMENT_RIGHT,true)
			"min":
				D.text(row,x+l,base,G.n(player.get("minutes",0)),19,C.MUTED,500,l,HORIZONTAL_ALIGNMENT_RIGHT,true)
			"contrat":
				var echeance: String = _echeance(player)
				if echeance.contains("⧗"):
					# Fin de saison : pastille sablier + année (21/11) ; la précision dans l'infobulle.
					var annee := echeance.get_slice(" ⧗", 0)
					R.pastille(row, x, base, "⧗ " + annee, R.ORANGE, "", "RosterContractEnd", 21).tooltip_text = annee + " · fin de contrat en fin de saison"
				else:
					D.text(row,x,base,echeance,19,C.MUTED,500,l,HORIZONTAL_ALIGNMENT_LEFT,true).name = "RosterContractEnd"
				_lien_lecture(row, Rect2(x - 6, 2, l + 8, h - 4), player, "contract", "SquadOpenContract_")
			"moy":
				var moyenne: Variant = notes.get("moyenne")
				if moyenne != null:
					var pastille := Notes.pastille(row,Rect2(x + l / 2.0 - 26,5,52,h-10),float(moyenne),0.52)
					pastille.name = "RosterNoteAverage"
					pastille.tooltip_text = "Moyenne de la saison en cours : %s sur %d match%s" % [Notes.texte_note(moyenne),int(notes.get("matchs",0)),"s" if int(notes.get("matchs",0))>1 else ""]
					pastille.mouse_filter = Control.MOUSE_FILTER_PASS
				else:
					D.text(row,x + l / 2.0,base,"—",19,C.FAINT,500,52,HORIZONTAL_ALIGNMENT_CENTER,true).name = "RosterNoteAverage"
			"forme":
				# Cases ramenées dans la colonne quand les panneaux latéraux la resserrent.
				Listes.dessiner_forme(self, row, Rect2(x, 1, l, h - 2), notes, str(player.name), minf(44.0, (l - 24.0) / 5.0)).name = "RosterForm"
			"motif":
				D.text(row,x,base,reason,19,C.IVORY,600,l,HORIZONTAL_ALIGNMENT_LEFT,true).name="RosterWatchReason"
			"statut":
				# Place sur la feuille seulement ; blessé, suspendu et sélection sont des badges derrière le nom (22/11).
				var feuille := _statut_feuille(player)
				var texte := D.text(row,x,base,str(feuille.t),19,feuille.c,600 if feuille.c != C.MUTED else 500,l,HORIZONTAL_ALIGNMENT_LEFT,true)
				texte.name = "RosterStatut"
	var comparer_ligne := Button.new()
	comparer_ligne.name = "RosterCompare_" + id.validate_node_name()
	comparer_ligne.set_meta("player_id", id)
	comparer_ligne.focus_mode = Control.FOCUS_ALL
	C.style_bouton_lien(comparer_ligne, 19)
	comparer_ligne.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(comparer_ligne)
	D.place(comparer_ligne, C.reach_rect(Rect2(_lt - 78, 2, 70, h - 4)))
	comparer_ligne.pressed.connect(func(): _basculer_comparaison(id))
	_etat_comparaison(comparer_ligne, id, false)
	row.mouse_entered.connect(func(): _etat_comparaison(comparer_ligne, id, true))
	row.mouse_exited.connect(func(): _etat_comparaison(comparer_ligne, id, row.get_global_rect().has_point(row.get_global_mouse_position())))
	comparer_ligne.focus_entered.connect(func(): _etat_comparaison(comparer_ligne, id, true))
	comparer_ligne.focus_exited.connect(func(): _etat_comparaison(comparer_ligne, id, false))

## Repère du comparateur au bout de la ligne : « + » au survol, A / B / C une fois ajouté (jamais la couleur seule).
func _etat_comparaison(bouton: Button, id: String, survol: bool) -> void:
	var repere := _repere_comparaison(id)
	bouton.text = repere if not repere.is_empty() else "+"
	bouton.visible = not repere.is_empty() or survol
	bouton.tooltip_text = ("Retirer du comparateur (%s)" % repere) if not repere.is_empty() else "Ajouter au comparateur"
	bouton.accessibility_name = bouton.tooltip_text + " · " + id

func _basculer_comparaison(id: String) -> void:
	var memo: Array = app.management_ui.compare
	if id in memo: memo.erase(id)
	else:
		if memo.size() >= 2: memo.remove_at(0)
		memo.append(id)
	if compare != null: compare.text = "Comparer %d/2 →" % memo.size()
	for ligne: Node in rows.get_children():
		var pid := str(ligne.get_meta("player_id", ""))
		var b := ligne.get_node_or_null("RosterCompare_" + pid.validate_node_name()) as Button
		if b != null: _etat_comparaison(b, pid, false)

func _echeance(player: Dictionary) -> String:
	var fin: Variant = player.get("contractEnd")
	var texte := G.contract_year(fin)
	if texte != "—" and int(fin) <= int(app.model.get("meta", {}).get("season", 1)): texte += " ⧗ fin de saison"
	return texte

func _repere_comparaison(id: String) -> String:
	var memo: Array = app.management_ui.compare
	var rang := memo.find(id)
	return "" if rang < 0 else ["A", "B"][rang]

## Portrait, drapeau, nom (souligné au survol) et « i » : le nom ouvre la fiche, le survol montre la carte joueur.
func _cellule_joueur(row: Control, player: Dictionary, index: int, h: float, base: float) -> void:
	var id := str(player.id)
	var portrait: Control = G.portrait_lazy(int(player.get("portraitIndex", 0)), C.px(31), player) if not id.is_empty() else C.photo("player-%02d" % posmod(int(player.get("portraitIndex", index)), 16))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	D.place(portrait, Rect2(96, (h - 30) / 2.0, 31, 30))
	var faits: Dictionary = player.get("playerFacts", {}) if player.get("playerFacts") is Dictionary else {}
	var code := str(faits.get("flagCode", "")) if faits.get("flagCode") is String else ""
	var drapeau := Identity.flag_texture(code)
	if drapeau != null:
		var image := TextureRect.new()
		image.name = "RosterDrapeau"
		image.texture = drapeau
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.tooltip_text = str(faits.get("nationality", ""))
		row.add_child(image)
		D.place(image, Rect2(138, h / 2.0 - 9, 28, 18))
	var sale: Variant = player.get("sale")
	var en_vente: bool = sale is Dictionary and bool(sale.get("listed", false)) and not sale.get("pending") is Dictionary
	var largeur_max := 190.0 if en_vente else 340.0
	var nom := D.text(row, 176, base, player.name, 20, C.IVORY, 600, largeur_max, HORIZONTAL_ALIGNMENT_LEFT, true)
	nom.name = "RosterNom"
	var largeur_nom := minf(largeur_max, _largeur(str(player.name), 20))
	var soulignement := ColorRect.new()
	soulignement.name = "RosterNomSouligne"
	soulignement.color = Charte.IVOIRE
	soulignement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soulignement.visible = false
	row.add_child(soulignement)
	D.place(soulignement, Rect2(176, base + 4, largeur_nom, 1.5))
	var lien := _lien_lecture(row, Rect2(96, 2, 80 + largeur_nom + 12, h - 4), player, "", "SquadOpenPlayer_")
	lien.mouse_entered.connect(func(): soulignement.visible = true)
	lien.mouse_exited.connect(func(): soulignement.visible = false)
	var taille_i := maxf(20.0, ceilf(16.0 / C.density))
	CarteSurvol.icone(app, row, Rect2(176 + largeur_nom + 12, (h - taille_i) / 2.0, taille_i, taille_i), id, "squad")
	var apres := 176 + largeur_nom + 12 + taille_i + 10
	if en_vente:
		_pastille_en_vente(row, player, apres, base, h)
		apres += R.largeur("En vente", 19) + 2.0 + 12.0 + 21.0 + 7.0 + 12.0 + 6.0
	# Badges courts derrière le nom (Offre, Départ, Jeune), dans la largeur de la colonne JOUEUR.
	Etoiles.poser_badges(self, app, row, player, _indispo(player), apres, base, 548.0 - apres)

## Indisponibilité pour les badges : {etat, t (infobulle complète), court (pastille)} ; vide si disponible.
func _indispo(player: Dictionary) -> Dictionary:
	var etat := str(U.indisponibilite(player))
	if etat.is_empty(): return {}
	var statut := _statut(player)
	var court: String = str(statut.get("pastille", ""))
	if court.is_empty(): court = "! Susp." if etat == "suspendu" else "◇ Sél."
	return {"etat": etat, "t": str(statut.t), "court": court}

## Pastille « En vente » (bleu de la charte + pièces + mot) : le clic ouvre la fiche sur l'onglet Contrat (offres, retrait du marché).
func _pastille_en_vente(row: Control, player: Dictionary, x: float, base: float, h: float) -> void:
	var id := str(player.id)
	var fond := R.pastille(row, x, base, "En vente", R.BLEU, "money", "RosterEnVente", 19)
	var zone := Rect2(x, base - 19.0 * .78 - 6.5, R.largeur("En vente", 19) + 2.0 + 12.0 + 21.0 + 7.0 + 12.0, 32.0)
	var lien := _lien_lecture(row, zone, player, "contract", "RosterEnVenteLien_")
	lien.tooltip_text = "En vente · " + Sales.status(player)
	lien.accessibility_name = "En vente · ouvrir les offres · " + str(player.name)
	fond.tooltip_text = ""

func _lien_lecture(parent: Control, zone: Rect2, player: Dictionary, section: String, prefixe: String) -> Button:
	var id := str(player.id)
	var link := Button.new()
	link.name = prefixe + id.validate_node_name()
	link.custom_minimum_size = Vector2.ZERO
	link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	link.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	link.add_theme_stylebox_override("hover", _plat(Color(Charte.IVOIRE, .07)))
	link.add_theme_stylebox_override("pressed", _plat(Color(Charte.IVOIRE, .12)))
	link.add_theme_stylebox_override("focus", _plat(Color.TRANSPARENT, Charte.IVOIRE, 1))
	link.accessibility_name = ("Consulter le contrat · " if section == "contract" else "Consulter la fiche · ") + str(player.name)
	link.tooltip_text = link.accessibility_name if section == "contract" else ""
	link.set_meta("entity_kind", "player")
	link.set_meta("entity_id", id)
	link.set_meta("entity_section", section)
	link.pressed.connect(func(): _ouvrir(id, section))
	parent.add_child(link)
	D.place(link, zone)
	# Le nom et le portrait : survol (ou focus + I) = carte joueur, clic = fiche complète.
	if section.is_empty(): CarteSurvol.lier(app, link, id, "squad")
	return link

func _ouvrir(id: String, section: String) -> void:
	app.selected_player = id
	app.navigation_controller.open_entity({"kind":"player", "id":id, "section":section})

## Le focus clavier (ou le retour de fiche) change le joueur courant sans reconstruire la liste ni colorer la ligne.
func _selectionner(id: String) -> void:
	if app.selected_player == id: return
	app.selected_player = id
	state.visible_player = id
	for ligne: Node in rows.get_children():
		if ligne is Button and ligne.has_meta("player_id"):
			var choisi: bool = ligne.get_meta("player_id") == id
			load("res://ui/survol_ligne.gd").appliquer(ligne, choisi, Color.TRANSPARENT, app.accent)
	app._observe_navigation()

func _row_key(event: InputEvent, current: Button) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed: return
	if event.keycode == KEY_SPACE and event.shift_pressed:
		get_viewport().set_input_as_handled()
		_basculer_comparaison(str(current.get_meta("player_id", "")))
		return
	if event.keycode not in [KEY_HOME,KEY_END,KEY_PAGEUP,KEY_PAGEDOWN]: return
	var items := rows.get_children().filter(func(node: Node): return node is Button and node.has_meta("player_id"))
	if items.is_empty(): return
	var index := items.find(current)
	var scroll := find_child("SquadScroll",true,false) as ScrollContainer
	var stride := maxi(1,floori(scroll.size.y / float(C.px(C.reach(ROW_HEIGHT))+C.px(2)))-1)
	var target := 0 if event.keycode == KEY_HOME else items.size()-1 if event.keycode == KEY_END else clampi(index+(-stride if event.keycode == KEY_PAGEUP else stride),0,items.size()-1)
	get_viewport().set_input_as_handled()
	items[target].grab_focus()
	scroll.ensure_control_visible(items[target])
	state.scroll = scroll.scroll_vertical
