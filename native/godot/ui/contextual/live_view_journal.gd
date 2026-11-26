extends "res://ui/contextual/live_view_fenetres_stat.gd"
## Écran 13 « Match en direct » (live_view.gd), morceau : journal du direct, noms liés, mini-fiche, bandeau du score.

## Le texte du dernier fait a changé (régie ou repli) : il passe en tête du journal, l'ancien descend.
func _suivre_journal() -> void:
	var texte := events.text.strip_edges()
	if texte == _journal_texte: return
	_journal_texte = texte
	if texte.is_empty(): return
	if not _journal.is_empty() and str(_journal[0].texte) == texte: return
	_journal.push_front({"minute": minute_de(clock.text), "texte": texte})
	if _journal.size() > 2: _journal.resize(2)
	_dessiner_journal()

## Un fait écrit au journal sans passer par la légende (faits des lois passés par les pistes du chorégraphe).
func ajouter_au_journal(texte: String) -> void:
	texte = texte.strip_edges()
	if texte.is_empty(): return
	if not _journal.is_empty() and str(_journal[0].texte) == texte: return
	_journal.push_front({"minute": minute_de(clock.text), "texte": texte})
	if _journal.size() > 2: _journal.resize(2)
	_dessiner_journal()

func _dessiner_journal() -> void:
	var joueurs: Array = model.get("squad", []) if model.get("squad") is Array else []
	# Journal vide : le panneau ne montre pas une bande sans texte.
	if is_instance_valid(_legende): _legende.self_modulate.a = 0.0 if _journal.is_empty() else 1.0
	for rang in _journal_lignes.size():
		var ligne: Array = _journal_lignes[rang]
		var fait: Dictionary = _journal[rang] if rang < _journal.size() and _journal[rang] is Dictionary else {}
		(ligne[2] as Control).visible = not fait.is_empty()
		(ligne[0] as Label).text = str(fait.get("minute", ""))
		var riche: RichTextLabel = ligne[1]
		# Un fait = une ligne (hauteur fixe de deux faits) : un texte trop long s'arrête sur un mot entier « … ».
		var bbcode := liens_joueurs(ligne_tenue(str(fait.get("texte", "")), Charte.texte_moyen(), riche.get_theme_font_size("normal_font_size"), _largeur_journal()), joueurs)
		if riche.text != bbcode: riche.text = bbcode

## Texte d'un fait en BBCode : chaque nom d'un de nos joueurs (nom complet, ou nom de famille sans
## ambiguïté) devient un lien [url=id] ; le reste est échappé. Les adversaires restent du texte.
static func liens_joueurs(texte: String, joueurs: Array) -> String:
	var motifs: Array = []
	var familles := {}
	for joueur: Variant in joueurs:
		if not joueur is Dictionary or joueur.get("id") == null: continue
		var nom := str(joueur.get("name", "")).strip_edges()
		if nom.is_empty(): continue
		var id := str(joueur.id)
		motifs.append([nom, id])
		var famille := nom.get_slice(" ", nom.get_slice_count(" ") - 1)
		if famille.length() >= 4 and famille != nom: familles[famille] = "" if familles.has(famille) else id
	for famille: String in familles:
		if not str(familles[famille]).is_empty(): motifs.append([famille, familles[famille]])
	motifs.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]).length() > str(b[0]).length())
	var pris: Array = []
	for motif: Array in motifs:
		var mot := str(motif[0])
		var depuis := 0
		while true:
			var i := texte.find(mot, depuis)
			if i < 0: break
			var f := i + mot.length()
			depuis = f
			if (i > 0 and _lettre(texte[i - 1])) or (f < texte.length() and _lettre(texte[f])): continue
			if pris.any(func(p: Array) -> bool: return i < int(p[1]) and f > int(p[0])): continue
			pris.append([i, f, motif[1]])
	pris.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var sortie := ""
	var curseur := 0
	for p: Array in pris:
		sortie += _echapper(texte.substr(curseur, int(p[0]) - curseur)) + "[url=%s]%s[/url]" % [str(p[2]), _echapper(texte.substr(int(p[0]), int(p[1]) - int(p[0])))]
		curseur = int(p[1])
	return sortie + _echapper(texte.substr(curseur))

## Nom du marqueur dans la bannière d'essai (match_temps_forts.gd) : l'un de nos joueurs devient un lien (souligné,
## main, mini-fiche au survol, fiche complète au clic) ; sinon le texte reste inerte, sans soulignement.
func lier_nom_bandeau(etiquette: Label, nom: String) -> void:
	if etiquette == null: return
	var id := joueur_par_nom(nom, model.get("squad", []) if model.get("squad") is Array else [])
	etiquette.set_meta("joueur_id", id)
	if not etiquette.has_meta("lien_pose"):
		etiquette.set_meta("lien_pose", true)
		var trait_nom := ColorRect.new()
		trait_nom.name = "Souligne"
		trait_nom.color = Charte.IVOIRE
		trait_nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trait_nom.anchor_top = 1.0
		trait_nom.anchor_bottom = 1.0
		trait_nom.offset_top = -2.0
		etiquette.add_child(trait_nom)
		# Le trait suit la longueur du nom, pas la largeur de la colonne.
		var caler := func():
			var police: Font = etiquette.get_theme_font("font")
			trait_nom.offset_right = police.get_string_size(etiquette.text, HORIZONTAL_ALIGNMENT_LEFT, -1, etiquette.get_theme_font_size("font_size")).x if police != null else etiquette.size.x
		etiquette.resized.connect(caler)
		etiquette.set_meta("caler_souligne", caler)
		etiquette.gui_input.connect(func(evenement: InputEvent):
			var clic := evenement as InputEventMouseButton
			var cible := str(etiquette.get_meta("joueur_id", ""))
			if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT and not cible.is_empty():
				etiquette.accept_event()
				ouvrir_joueur(cible))
		etiquette.mouse_entered.connect(func():
			var cible := str(etiquette.get_meta("joueur_id", ""))
			if not cible.is_empty(): _survol_joueur(cible, etiquette))
		etiquette.mouse_exited.connect(func(): _mini_fiche().cacher(app, etiquette))
	var lie := not id.is_empty()
	etiquette.mouse_filter = Control.MOUSE_FILTER_STOP if lie else Control.MOUSE_FILTER_IGNORE
	etiquette.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if lie else Control.CURSOR_ARROW
	etiquette.tooltip_text = "Voir sa fiche" if lie else ""
	(etiquette.get_node("Souligne") as Control).visible = lie
	(etiquette.get_meta("caler_souligne") as Callable).call()
