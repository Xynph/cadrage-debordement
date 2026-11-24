extends "res://ui/contextual/apres_match_outils.gd"
## Après-match (apres_match.gd), morceau : noms de joueurs liés (fiche, mini-fiche) et mini-fiche d'un joueur adverse.
## Chaîne d'héritage de l'écran : socle ← outils ← joueurs ← bandeau ← verdict ← classement ← apres_match.gd.

## Nom d'un joueur : notre effectif = fiche complète au clic, mini-fiche au survol. Adversaire : clic = XV type de son
## club (fiche du club), survol = mini-fiche de ce que le jeu en connaît (celle du marché s'il y est suivi).
func _lien_joueur(id: String, nom: String, camp: int, taille: float = 13, police: Font = null) -> Control:
	var nous := camp == _camp()
	var a_nous := nous and _dans_effectif(id)
	var equipes: Array = _live().get("teams", [])
	var club: Dictionary = equipes[camp] if camp >= 0 and camp < equipes.size() and equipes[camp] is Dictionary else {}
	var cible: Dictionary = {}
	if a_nous: cible = {"kind": "player", "id": id}
	elif club.get("id") != null: cible = {"kind": "club", "id": _cle_id(club.get("id")), "onglet": 2}
	if nom.is_empty() or cible.is_empty(): return _texte(nom, taille, Charte.IVOIRE_2)
	var b := _lien(nom, cible, taille)
	if police != null: b.add_theme_font_override("font", police)
	b.name = "ApresMatchJoueur_" + id.validate_node_name()
	# Mini-fiche commune (mini_fiche.gd) : notre effectif, sinon l'adversaire lu dans la fiche de son club déjà chargée
	# (source « adverse », ce que le jeu en connaît), sinon une piste du marché ; à défaut, la fiche de ce match.
	var source_fiche := "squad" if a_nous else ""
	if not a_nous and app != null and app.get("model") is Dictionary:
		var commune: Script = load("res://ui/immersive08/fiche_commune.gd")
		for source: String in ["adverse", "market"]:
			if source_fiche.is_empty() and not (commune.trouver(app, id, source) as Dictionary).is_empty(): source_fiche = source
	if not source_fiche.is_empty():
		MiniFiche.lier(app, b, id, source_fiche)
		# La mini-fiche se pose sur l'application : au-dessus de la scène du match (z 100).
		b.mouse_entered.connect(func():
			var fiche := MiniFiche.actuelle(app)
			if fiche != null: fiche.z_index = 200)
	else: _lier_fiche_adverse(b, id, nom, club, camp)
	return b

## Survol (ou focus puis touche I) du nom d'un adversaire : poste, club, match du jour ; niveau et attributs « — »
## tant que le joueur n'est pas observé. Un Control posé dans l'écran, jamais une fenêtre.
func _lier_fiche_adverse(b: Button, id: String, nom: String, club: Dictionary, camp: int) -> void:
	b.tooltip_text = ""
	b.set_meta("fiche_adverse", id)
	b.mouse_entered.connect(func(): montrer_fiche_adverse(b, id, nom, club, camp))
	b.mouse_exited.connect(cacher_fiche_adverse)
	b.focus_exited.connect(cacher_fiche_adverse)
	b.tree_exiting.connect(cacher_fiche_adverse)
	b.gui_input.connect(func(event: InputEvent):
		var touche := event as InputEventKey
		if touche == null or not touche.pressed or touche.echo or touche.keycode != KEY_I: return
		if is_instance_valid(get_node_or_null("MiniFicheAdverse")): cacher_fiche_adverse()
		else: montrer_fiche_adverse(b, id, nom, club, camp)
		b.accept_event())

func _adversaire(id: String) -> Dictionary:
	for j: Variant in (_direct().get("adversaire", []) if _direct().get("adversaire") is Array else []):
		if j is Dictionary and str(j.get("joueur", "")) == id: return j
	return {}

func montrer_fiche_adverse(ancre: Control, id: String, nom: String, club: Dictionary, camp: int) -> Control:
	cacher_fiche_adverse()
	if not is_instance_valid(ancre) or not ancre.is_inside_tree(): return null
	var connu := _adversaire(id)
	var note: Variant = connu.get("note")
	var notes: Variant = _direct().get("notes")
	if note == null and notes is Dictionary and notes.get(id) is Dictionary: note = notes[id].get("note")
	var fiche := _panneau(Charte.PANNEAU_2, 16, 12, Charte.RAYON_CARTE)
	fiche.name = "MiniFicheAdverse"
	fiche.z_index = 200
	fiche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := fiche.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_width_left = maxi(2, _d(3))
	style.border_color = Charte.club_trait(_couleur(club))
	var col := _v(4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fiche.add_child(col)
	var tete := _h(8)
	tete.add_child(_sigle(club, 28, 20, 12))
	tete.add_child(_texte(nom, 16, Charte.IVOIRE, Charte.TITRE_GRAS))
	col.add_child(tete)
	var poste := str(connu.get("poste", ""))
	col.add_child(_texte(" · ".join(PackedStringArray(([poste] if not poste.is_empty() else []) + [G.club_name(club)])), 13, Charte.IVOIRE_2))
	col.add_child(_texte("CE QUE LE JEU CONNAÎT", 12, Charte.IVOIRE_3, Charte.TITRE))
	for ligne: Array in [["Niveau", "—"], ["Attributs", "— (joueur non observé)"]]:
		var r := _h(8)
		r.add_child(_texte(str(ligne[0]), 13, Charte.IVOIRE_2))
		r.add_child(_texte(str(ligne[1]), 13, Charte.IVOIRE, texte_gras()))
		col.add_child(r)
	var faits: Array[String] = []
	if note is float or note is int: faits.append("note " + note_texte(note))
	if int(connu.get("essais", 0)) > 0: faits.append("%d essai%s" % [int(connu.essais), "s" if int(connu.essais) > 1 else ""])
	if int(connu.get("plaquages", 0)) > 0: faits.append("%d plaquages" % int(connu.plaquages))
	if int(connu.get("metres", 0)) > 0: faits.append("%d m" % int(connu.metres))
	if not faits.is_empty():
		var r := _h(8)
		r.add_child(_texte("Ce match", 13, Charte.IVOIRE_2))
		r.add_child(_texte(" · ".join(PackedStringArray(faits)), 13, Charte.IVOIRE, texte_gras()))
		col.add_child(r)
	col.add_child(_texte("Clic : XV type de " + G.club_name(club), 12, Charte.IVOIRE_3))
	add_child(fiche)
	fiche.reset_size()
	var taille := fiche.get_combined_minimum_size()
	var vue := get_viewport_rect().size
	var r_ancre := ancre.get_global_rect()
	var pos := Vector2(r_ancre.position.x, r_ancre.end.y + _d(6))
	if pos.y + taille.y > vue.y - 8: pos.y = r_ancre.position.y - taille.y - _d(6)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, vue.x - taille.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, vue.y - taille.y - 8.0))
	fiche.global_position = pos
	fiche.set_meta("ancre", ancre)
	return fiche

func cacher_fiche_adverse() -> void:
	var fiche := get_node_or_null("MiniFicheAdverse")
	if fiche != null:
		remove_child(fiche)
		fiche.queue_free()

func _dans_effectif(id: String) -> bool:
	for p: Variant in model.get("squad", []):
		if p is Dictionary and str(p.get("id", "")) == id: return true
	return false
