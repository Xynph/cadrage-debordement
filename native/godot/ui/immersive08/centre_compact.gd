extends "res://ui/immersive08/centre_compact_filieres_passerelle.gd"
## Centre de formation en affichage compact (fenêtre sous 1280 × 720), parcours actifs : mêmes six onglets, mêmes
## structures et mêmes couleurs que la page façon Effectif (centre_visuel.gd / centre_onglets.gd), mais en conteneurs
## qui s'adaptent à la place (le gabarit de 2248 de large ne tient pas sous 1280 × 720) : tuiles chiffres, onglets en
## pilules, panneaux à titre Anton, listes à lignes (survol de ligne, carte joueur au survol, tri par en-tête, filtres en
## pastilles) et réglages en pastilles. Les petites fenêtres (parcours individuel, candidats, prêt, saison junior) sont
## celles de la grande page, posées sur une toile à l'échelle du gabarit au-dessus de la page.
## Aucune nouvelle commande : tout passe par V.envoyer (mêmes confirmations de dépense).
## Découpe : constantes, pièces, listes et onglets sont dans centre_compact_*.gd (chaîne d'héritage qui finit ici) ; ce fichier garde `build` et `_remplir`.

# --- Page ------------------------------------------------------------------------------------------------------------

static func build(app: Control, initial_tab: String = "") -> Control:
	var data: Dictionary = app.model.get("clubLife", {}).get("academyPathways", {})
	if not app.management_ui.get("immersive_centre") is Dictionary:
		app.management_ui.immersive_centre = {"tab": "", "scroll": {}}
	var state: Dictionary = app.management_ui.immersive_centre
	var club: Variant = app.model.get("club", {}).get("id")
	if state.get("club") != club:
		state.clear()
		state.merge({"club": club, "tab": "", "scroll": {}})
	if not state.get("scroll") is Dictionary: state.scroll = {}
	if initial_tab in V.ONGLETS: state.tab = initial_tab
	var racine := VBoxContainer.new()
	racine.name = NOM_PAGE
	racine.add_theme_constant_override("separation", ECART)
	C.fill(racine, true)
	var ctx := {"app": app, "data": data, "state": state, "racine": racine, "hote": null, "page": null}
	ctx.reconstruire = func(): _remplir(ctx)
	_remplir(ctx)
	var rouvrir: Variant = state.get("fenetre")
	if rouvrir is Dictionary and str(rouvrir.get("kind", "")) == "joueur":
		(func():
			if is_instance_valid(racine) and racine.is_inside_tree():
				_preparer(ctx)
				V.fenetre_parcours(ctx, str(rouvrir.get("id", "")))).call_deferred()
	return racine

static func _remplir(ctx: Dictionary) -> void:
	var racine: VBoxContainer = ctx.racine
	var hote: Variant = ctx.get("hote")
	if is_instance_valid(hote): (hote as Node).queue_free()
	ctx.hote = null
	ctx.page = null
	for enfant in racine.get_children():
		racine.remove_child(enfant)
		enfant.queue_free()
	var onglet := str(ctx.state.get("tab", ""))
	if not onglet in V.ONGLETS: onglet = "Centre"
	ctx.onglet = onglet
	racine.set_meta("onglet", onglet)
	_entete(ctx)
	_onglets(ctx)
	var defile := ScrollContainer.new()
	defile.name = "CentreCompactDefile"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.follow_focus = true
	C.fill(defile, true)
	racine.add_child(defile)
	var contenu := VBoxContainer.new()
	contenu.name = "CentreCompactContenu"
	contenu.add_theme_constant_override("separation", ECART)
	C.fill(contenu)
	defile.add_child(contenu)
	match onglet:
		"Parcours": _parcours(ctx, contenu)
		"Centres": _centres(ctx, contenu)
		"Filières": _filieres(ctx, contenu)
		"Passerelle pro": _passerelle(ctx, contenu)
		"Générations": _generations(ctx, contenu)
		_: _centre(ctx, contenu)
	for enfant in racine.get_children(): _marquer(enfant)
	var memoire: Dictionary = ctx.state.scroll
	var cle := "compact/" + onglet
	defile.get_v_scroll_bar().value_changed.connect(func(v: float): memoire[cle] = int(v))
	var position := int(memoire.get(cle, 0))
	if position > 0:
		(func():
			if not is_instance_valid(defile): return
			await defile.get_tree().process_frame
			await defile.get_tree().process_frame
			if is_instance_valid(defile): defile.scroll_vertical = position).call_deferred()
