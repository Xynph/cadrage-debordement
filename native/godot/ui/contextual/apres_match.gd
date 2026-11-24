extends "res://ui/contextual/apres_match_classement.gd"
## Après-match (design/ux/15-apres-match.md ; choix de Léo du 19/11/2026 : « verdict en tête » avec le classement
## complet de la division). Posé par la vue du direct (live_view.gd) une fois tout le match montré et avant la
## validation du résultat : bandeau vestiaire, pastille V/N/D en pilule et score, les trois raisons du « Pourquoi » avec
## leur levier, fil du score, Gabi ; à droite le classement complet après la journée (zones réelles du championnat),
## ta place, les autres matchs de la journée et le seul aplat doré de l’écran, « Valider le résultat ».
## Tout ce qui ressemble à un lien ouvre un écran du jeu par `director.consulter(cible)` (match_immersed laisse alors
## naviguer ; « Continuer » de la coque ou Espace ramène ici). Aucune donnée inventée : une donnée absente est omise.
## Données : `live.direct` (pourquoi, hommeDuMatch, marques, notes, journee, statsRows, camp) et le modèle.
## Chaîne d'héritage de l'écran : socle ← outils ← joueurs ← bandeau ← verdict ← classement ← apres_match.gd.

func _ready() -> void:
	name = "ApresMatch"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(func(): _cle = ""; _reconstruire())

func update_frame(value: Dictionary) -> void:
	model = value
	_reconstruire()

func _reconstruire() -> void:
	if not is_inside_tree(): return
	var vue := get_viewport_rect().size
	_e = clampf(minf(vue.x / 1920.0, vue.y / 1080.0), 0.5, 2.0)
	var cle := JSON.stringify([vue, detail, _live().get("score"), _live().get("finished"), _direct().get("pourquoi"), _direct().get("hommeDuMatch"), _direct().get("marques"),
		_journee(), _direct().get("notes"), _direct().get("statsRows"), _live().get("events", []).size(), _fixture().get("label")])
	if cle == _cle: return
	_cle = cle
	_indexer_clubs()
	for enfant in get_children():
		remove_child(enfant)
		enfant.queue_free()
	bouton_valider = null
	_ta_place = null
	_autres = null
	var fond := ColorRect.new()
	fond.color = Charte.FOND
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var colonne := _v(16)
	colonne.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(colonne)
	colonne.add_child(_bandeau())
	var marge := MarginContainer.new()
	for bord: String in ["left", "right"]: marge.add_theme_constant_override("margin_" + bord, _d(24))
	marge.add_theme_constant_override("margin_bottom", _d(40))
	marge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(marge)
	var corps := _h(24)
	marge.add_child(corps)
	var gauche := _v(12)
	gauche.name = "ApresMatchGauche"
	C.fill(gauche, true, 1116)
	corps.add_child(gauche)
	_droite = _v(10)
	_droite.name = "ApresMatchDroite"
	C.fill(_droite, true, 732)
	corps.add_child(_droite)
	if detail: _sous_page(gauche)
	else:
		_pourquoi(gauche)
		var vide := Control.new()
		vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gauche.add_child(vide)
		_fil_du_score(gauche)
		var vide_bas := Control.new()
		vide_bas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vide_bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gauche.add_child(vide_bas)
		_gabi(gauche)
	_colonne_classement(_droite)
	for b: Node in find_children("*", "BaseButton", true, false):
		if b.has_meta("indisponible") and not (b as Control).tooltip_text.begins_with(str(b.get_meta("indisponible"))): _aide(b, (b as Control).tooltip_text)
	if is_instance_valid(director) and director.has_method("_refresh_controls"): director._refresh_controls()
	_ajuster.call_deferred()
	_focus_valider.call_deferred()

func _focus_valider() -> void:
	if is_instance_valid(bouton_valider) and bouton_valider.is_inside_tree() and bouton_valider.is_visible_in_tree(): bouton_valider.grab_focus()

## La colonne de droite tient dans l'écran : « Ta place » passe sur une ligne, puis les autres matchs en sigles.
## Rien n'est retiré.
func _ajuster() -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_instance_valid(_droite) or not _droite.is_inside_tree(): return
	var dispo := get_viewport_rect().size.y - _droite.get_global_rect().position.y - float(_d(40))
	if dispo <= 0: return
	if is_instance_valid(_ta_place) and not bool(_ta_place.get_meta("condense", false)) and _droite.get_combined_minimum_size().y > dispo + 1.0:
		_remplacer(_ta_place, _place(_classement(), true))
		await get_tree().process_frame
		if not is_instance_valid(_droite): return
	if is_instance_valid(_autres) and not bool(_autres.get_meta("sigles", false)) and _droite.get_combined_minimum_size().y > dispo + 1.0:
		_remplacer(_autres, _autres_matchs(true))

func _remplacer(ancien: Control, nouveau: Control) -> void:
	if not is_instance_valid(ancien) or nouveau == null: return
	var parent := ancien.get_parent()
	var index := ancien.get_index()
	parent.remove_child(ancien)
	ancien.queue_free()
	parent.add_child(nouveau)
	parent.move_child(nouveau, index)
	if ancien == _ta_place: _ta_place = nouveau
	elif ancien == _autres: _autres = nouveau
	if is_instance_valid(director) and director.has_method("_refresh_controls"): director._refresh_controls()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	var avant := clavier
	if event is InputEventKey and event.pressed: clavier = true
	elif event is InputEventMouseButton and event.pressed: clavier = false
	if avant != clavier: _maj_focus_clavier()
