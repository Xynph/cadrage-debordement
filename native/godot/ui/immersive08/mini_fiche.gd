extends RefCounted
## Mini-fiche joueur au survol (design/ux/mini-fiche-joueur.md, décision de Léo du 19/11/2026) : un Control flottant
## posé dans la coque, jamais une fenêtre ni un popup. Survol du nom ou du « i » voisin : elle apparaît près du nom,
## toujours entière dans l'écran ; la souris part : elle disparaît ; clic sur le nom : fiche complète (inchangé).
## Clavier : focus sur le nom puis touche I (montre / cache) ; elle part avec le focus.
## Exemple : `MiniFiche.lier(app, lien_du_nom, str(player.id), "squad")` puis `MiniFiche.icone(app, ligne, Rect2(…), id, "squad")`.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Identity = preload("res://ui/player_identity.gd")
const NOM := "MiniFicheJoueur"
const LARGEUR := 860.0
const HAUTEUR := 668.0
const MARGE := 8.0

## Chargés à l'usage : fiche_commune et squad_canvas chargent eux-mêmes ce script.
static func _commune() -> Script:
	return load("res://ui/immersive08/fiche_commune.gd")

static func _roster() -> Script:
	return load("res://ui/immersive08/squad_canvas.gd")

## Branche la mini-fiche sur le nom d'un joueur (lien) ou sur son « i ». L'info-bulle système (une fenêtre) est retirée :
## la mini-fiche la remplace ; le nom accessible reste.
static func lier(app: Control, controle: Control, player_id: String, source: String = "") -> void:
	if player_id.is_empty(): return
	controle.tooltip_text = ""
	controle.set_meta("mini_fiche_joueur", player_id)
	controle.set_meta("mini_fiche_source", source)
	controle.mouse_entered.connect(func(): montrer(app, player_id, source, controle))
	controle.mouse_exited.connect(func(): cacher(app, controle))
	controle.focus_exited.connect(func(): cacher(app, controle))
	controle.tree_exiting.connect(func(): cacher(app, controle))
	if controle.focus_mode == Control.FOCUS_NONE: return
	controle.gui_input.connect(func(event: InputEvent):
		var touche := event as InputEventKey
		if touche == null or not touche.pressed or touche.echo or touche.ctrl_pressed or touche.alt_pressed or touche.meta_pressed: return
		if touche.keycode != KEY_I: return
		if visible_pour(app, controle): cacher(app, controle)
		else: montrer(app, player_id, source, controle)
		controle.accept_event())

## Petit « i » placé juste après le nom (unités du gabarit) : survol = mini-fiche.
static func icone(app: Control, parent: Control, zone: Rect2, player_id: String, source: String = "") -> Control:
	var info := C.icon("info", int(zone.size.x), Charte.IVOIRE_2)
	info.name = "MiniFicheInfo_" + player_id.validate_node_name()
	info.mouse_filter = Control.MOUSE_FILTER_STOP
	info.mouse_default_cursor_shape = Control.CURSOR_HELP
	parent.add_child(info)
	D.place(info, zone)
	lier(app, info, player_id, source)
	return info

## Mini-fiche affichée (ou null).
static func actuelle(app: Control) -> Control:
	var fiche := app.get_node_or_null(NOM) as Control
	return fiche if fiche != null and not fiche.is_queued_for_deletion() else null

static func visible_pour(app: Control, controle: Control) -> bool:
	var fiche := actuelle(app)
	return fiche != null and fiche.get_meta("ancre", null) == controle

static func montrer(app: Control, player_id: String, source: String, ancre: Control) -> Control:
	cacher(app)
	if not is_instance_valid(ancre) or not ancre.is_inside_tree(): return null
	var trouve: Dictionary = _commune().trouver(app, player_id, source)
	if trouve.is_empty(): return null
	var fiche := construire(app, trouve.joueur, trouve.source)
	fiche.set_meta("ancre", ancre)
	fiche.set_meta("player_id", player_id)
	app.add_child(fiche)
	placer(fiche, ancre, app.get_viewport_rect().size)
	return fiche

## Retire la mini-fiche ; avec `ancre`, seulement celle ouverte par ce contrôle.
static func cacher(app: Control, ancre: Control = null) -> void:
	if not is_instance_valid(app): return
	var fiche := actuelle(app)
	if fiche == null: return
	if ancre != null and fiche.get_meta("ancre", null) != ancre: return
	# Pas de remove_child : la coque peut être en train de retirer ses enfants (nouveau rendu) ; la fiche est cachée,
	# renommée (le nom reste libre pour la suivante) et libérée à la fin de l'image.
	fiche.hide()
	fiche.name = NOM + "Fermee"
	fiche.queue_free()

## Sous le nom (au-dessus s'il manque la place), recalée dans l'écran.
static func placer(fiche: Control, ancre: Control, ecran: Vector2) -> void:
	var transformation := ancre.get_global_transform_with_canvas()
	var zone := Rect2(transformation.origin, ancre.size * transformation.get_scale())
	var taille := fiche.size
	var position := Vector2(zone.position.x - 12.0, zone.end.y + 6.0)
	if position.y + taille.y > ecran.y - MARGE: position.y = zone.position.y - taille.y - 6.0
	position.x = clampf(position.x, MARGE, maxf(MARGE, ecran.x - taille.x - MARGE))
	position.y = clampf(position.y, MARGE, maxf(MARGE, ecran.y - taille.y - MARGE))
	fiche.position = position

static func _italique(label: Label) -> Label:
	label.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	return label

static func construire(app: Control, player: Dictionary, source: String) -> Panel:
	var commune := _commune()
	var fiche := Panel.new()
	fiche.name = NOM
	fiche.z_index = 100
	var fond := C.box(Charte.PANNEAU_3, Charte.FILET, 6, 0)
	fond.shadow_color = Color(0, 0, 0, .5)
	fond.shadow_size = maxi(4, C.px(14))
	fiche.add_theme_stylebox_override("panel", fond)
	fiche.size = Vector2(LARGEUR, HAUTEUR) * C.density
	# En-tête : vignette et numéro, nom, poste · statut, drapeau + pays · âge, niveau et potentiel.
	var vignette := D.rect(fiche, Rect2(20, 20, 128, 120), Charte.PANNEAU_2, 4)
	vignette.clip_contents = true
	if not str(player.get("id", "")).is_empty():
		var portrait := G.portrait(int(player.get("portraitIndex", 0)), C.px(120), player)
		vignette.add_child(portrait)
		D.place(portrait, Rect2(0, 0, 128, 120))
	var numero: Variant = player.get("shirtNumber")
	if numero is int or numero is float:
		_italique(D.text(fiche, 186, 138, G.n(numero), 60, Color(Charte.IVOIRE, .82), 800, 70, HORIZONTAL_ALIGNMENT_RIGHT)).name = "MiniFicheNumero"
	_italique(D.text(fiche, 196, 62, str(player.get("name", "—")).to_upper(), 36, Charte.IVOIRE, 800, 440)).name = "MiniFicheNom"
	var statut: String = commune.statut_feuille(player, source)
	var poste: String = _roster().primary_caption(player)
	D.text(fiche, 196, 98, poste + (" · " + statut if not statut.is_empty() else ""), 21, Charte.IVOIRE, 600, 460).name = "MiniFichePoste"
	var facts: Dictionary = player.get("playerFacts", {}) if player.get("playerFacts") is Dictionary else {}
	var pays := str(facts.get("nationality", "")) if facts.get("nationality") is String else ""
	var code := str(facts.get("flagCode", "")) if facts.get("flagCode") is String else ""
	var x := 196.0
	var drapeau := Identity.flag_texture(code)
	if drapeau != null:
		var image := TextureRect.new()
		image.name = "MiniFicheDrapeau"
		image.texture = drapeau
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fiche.add_child(image)
		D.place(image, Rect2(x, 112, 30, 20))
		x += 40
	elif not code.is_empty():
		D.text(fiche, x, 128, code.to_upper(), 18, Charte.IVOIRE_2, 700, 54).name = "MiniFicheCodePays"
		x += 58
	var origine: Array[String] = []
	if not pays.is_empty(): origine.append(pays)
	if player.get("age") is int or player.get("age") is float: origine.append(G.n(player.age) + " ans")
	D.text(fiche, x, 128, " · ".join(origine), 20, Charte.IVOIRE_2, 500, 640 - x).name = "MiniFicheOrigine"
	D.text(fiche, 840, 42, "NIVEAU", 16, Charte.IVOIRE_2, 700, 160, HORIZONTAL_ALIGNMENT_RIGHT)
	_italique(D.text(fiche, 840, 100, G.rating_text(player, commune.notre_joueur(source)), 56, Charte.IVOIRE, 800, 200, HORIZONTAL_ALIGNMENT_RIGHT)).name = "MiniFicheNiveau"
	D.text(fiche, 840, 132, "pot. " + G.potential_text(player), 19, Charte.IVOIRE_2, 500, 200, HORIZONTAL_ALIGNMENT_RIGHT).name = "MiniFichePotentiel"
	D.line(fiche, Vector2(20, 158), Vector2(LARGEUR - 20, 158), Charte.FILET)
	# Forme, ou la raison de l'absence (blessé, suspendu, en sélection) avec le retour connu.
	var dispo: Dictionary = commune.disponibilite(app, player, source)
	var forme: Variant = commune.condition(player)
	if dispo.etat in ["apte", "reprise"]:
		D.text(fiche, 26, 196, "Forme", 20, Charte.IVOIRE_2, 500, 220, HORIZONTAL_ALIGNMENT_LEFT, true)
		var texte := str(dispo.texte)
		if forme != null:
			D.bar(fiche, Rect2(440, 188, 190, 6), float(forme), Charte.V if float(forme) >= 85 else Charte.N)
			texte = "%d %% · %s" % [roundi(float(forme)), texte]
		D.text(fiche, 840, 196, texte, 20, Charte.IVOIRE, 600, 190, HORIZONTAL_ALIGNMENT_RIGHT, true).name = "MiniFicheForme"
	else:
		D.text(fiche, 26, 196, "Disponibilité", 20, Charte.IVOIRE_2, 500, 220, HORIZONTAL_ALIGNMENT_LEFT, true)
		D.text(fiche, 840, 196, str(dispo.texte), 20, dispo.couleur, 700, 580, HORIZONTAL_ALIGNMENT_RIGHT, true).name = "MiniFicheRaison"
	var contrat: Array[String] = []
	var fin: String = commune.echeance(app, player)
	if fin != "—": contrat.append(fin)
	if player.get("salary") is int or player.get("salary") is float: contrat.append(G.salary(player.salary))
	if not contrat.is_empty():
		D.text(fiche, 26, 228, "Contrat", 20, Charte.IVOIRE_2, 500, 220, HORIZONTAL_ALIGNMENT_LEFT, true)
		D.text(fiche, 840, 228, " · ".join(contrat), 20, Charte.IVOIRE, 600, 580, HORIZONTAL_ALIGNMENT_RIGHT, true).name = "MiniFicheContrat"
	D.line(fiche, Vector2(20, 250), Vector2(LARGEUR - 20, 250), Charte.FILET)
	# Les 36 attributs (familles réelles du jeu), « — » s'ils sont inconnus.
	var valeurs: Dictionary = commune.valeurs(player, source)
	commune.grille_attributs(fiche, Vector2(26, 262), Vector2(808, 300), valeurs, "MiniFicheAttribut_", {"titre":15, "libelle":17, "valeur":19, "pas":28, "ecart":16, "corps":false, "mot_moyenne":false})
	D.line(fiche, Vector2(20, 566), Vector2(LARGEUR - 20, 566), Charte.FILET)
	var lecture := "36 attributs, note de 1 à 100" if not valeurs.is_empty() else "Fais-le observer pour connaître ses attributs"
	D.text(fiche, 26, 596, lecture, 17, Charte.IVOIRE_2 if not valeurs.is_empty() else Charte.IVOIRE_3, 500, 380, HORIZONTAL_ALIGNMENT_LEFT, true).name = "MiniFicheLecture"
	commune.legende(fiche, 834, 596, 16)
	D.line(fiche, Vector2(20, 614), Vector2(LARGEUR - 20, 614), Charte.FILET)
	D.text(fiche, 26, 648, "Clic : fiche complète", 19, Charte.IVOIRE, 700, 400).name = "MiniFichePied"
	D.text(fiche, 834, 648, "I : aperçu au clavier", 16, Charte.IVOIRE_2, 500, 320, HORIZONTAL_ALIGNMENT_RIGHT, true)
	_ignorer_souris(fiche)
	return fiche

## La mini-fiche ne capte jamais la souris : le survol reste au nom, qui la referme en sortant.
static func _ignorer_souris(noeud: Node) -> void:
	if noeud is Control:
		noeud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		noeud.tooltip_text = ""
	for enfant in noeud.get_children(): _ignorer_souris(enfant)
