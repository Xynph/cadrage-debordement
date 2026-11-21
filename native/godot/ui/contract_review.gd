extends VBoxContainer
## Read-only horizons from the current squad projection. No invented deadlines.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const Pages = preload("res://ui/immersive08/recruitment_pages.gd")
const U = preload("res://ui/management_state.gd")
const G = preload("res://ui/game_skin.gd")
const Sales = preload("res://ui/player_sales_view.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const STATUS_OPTIONS := ["Tous","Prolongation accessible","Discussion en cours","Échanges clos","Sans contrat renseigné"]
var app: Control
var state: Dictionary
var _rows: VBoxContainer
var _coverage: VBoxContainer
var _count: Label
var _scroll: ScrollContainer
var _season: OptionButton
var _position: OptionButton
var _status_choice: OptionButton
var _precision_choice: OptionButton
var _headers: Dictionary = {}
## Colonnes du tableau : [clé, largeur minimale, poids]. Les poids reprennent les anciennes largeurs fixes (1920) ; le tableau
## se partage la largeur du panneau au lieu de la dépasser (1920, 1280, échelle d'interface 90-130 %).
const COLS := [["name", 126, 264], ["pos", 76, 160], ["rating", 40, 72], ["potential", 62, 84], ["age", 34, 60], ["contractEnd", 56, 145], ["salary", 62, 145], ["minutes", 34, 95], ["status", 62, 110], ["renewal", 44, 100], ["actions", 150, 276]]
const COL_GAP := 4
## Couleurs franches par sens (jamais seules : chaque couleur accompagne un chiffre, une icône ou un mot).
const ORANGE := Color("e0a04a")
const VERT := Color("7fbf7a")
const BLEU := Color("5b9bd5")
const CITRON := Color("d4e35c")
const ROUGE := Color("d9534a")
## Largeur de la page en dessous de laquelle le panneau « Échéances » passe sous le tableau.
const LARGEUR_DEUX_COLONNES := 1500.0
var _columns: BoxContainer
var _fenetre: Control
const SORT_KEYS := ["name","pos","rating","potential","age","contractEnd","salary","minutes","status","renewal"]

static func build(owner_app: Control) -> Control:
	var view: Control = load("res://ui/contract_review.gd").new()
	view.app = owner_app
	view._build()
	return view

static func action_id(prefix: String, player_id: String) -> String:
	return prefix + "_" + player_id.sha256_text().substr(0, 16)

## État de vente court pour la colonne Statut ("" : pas de vente en cours).
static func sale_caption(player: Dictionary) -> String:
	return Sales.short(player)

static func projected_mark(player: Dictionary, key: String) -> String:
	return G.potential_text(player) if key == "potential" else G.rating_text(player,true)

# SquadCanvas preloads this view: resolve its canonical presentation at runtime
# to reuse the principal-role rules without a circular preload dependency.
static func position_caption(player: Dictionary) -> String:
	return load("res://ui/immersive08/squad_canvas.gd").primary_caption(player)

static func position_text(player: Dictionary) -> String:
	var caption := position_caption(player)
	match caption:
		"Troisième ligne aile": return "3E L"
		"Troisième ligne centre": return "8"
		_: return caption

static func horizon(player: Dictionary) -> int:
	var value: Variant = player.get("contractEnd")
	return int(value) if (value is int or value is float) and float(value) == floorf(float(value)) and int(value) >= 0 else -1

static func filtered(players: Array, filters: Dictionary) -> Array:
	var result: Array = []
	for player: Dictionary in players:
		var ending := horizon(player)
		if int(filters.get("season", 0)) > 0 and ending != int(filters.season): continue
		var status := str(filters.get("status", "Tous"))
		var quote: Dictionary = player.get("renewal", {})
		var discussion: String = str(quote.get("negotiation", {}).get("status", ""))
		if status == "Prolongation accessible" and not bool(quote.get("available", false)): continue
		if status == "Discussion en cours" and not discussion in ["counter", "ready"]: continue
		if status == "Échanges clos" and discussion != "withdrawn": continue
		if str(filters.get("status", "Tous")) == "Sans contrat renseigné" and ending >= 0: continue
		if str(filters.get("precision", "Toutes")) == "Échéance connue" and ending < 0: continue
		if str(filters.get("precision", "Toutes")) == "Non renseignée" and ending >= 0: continue
		if str(filters.get("position", "Tous")) != "Tous" and position_caption(player) != str(filters.position): continue
		var query := U.fold(str(filters.get("search", "")).strip_edges())
		if not query.is_empty() and not U.fold(str(player.get("name", "")) + " " + position_caption(player) + " " + position_text(player) + " " + str(player.get("pos", ""))).contains(query): continue
		result.append(player)
	var sort_key := str(filters.get("sort", "contractEnd"))
	if not sort_key in SORT_KEYS: sort_key = "contractEnd"
	var descending := bool(filters.get("descending", false))
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		var first: Variant = sort_value(a, sort_key, bool(filters.get("live", false)))
		var second: Variant = sort_value(b, sort_key, bool(filters.get("live", false)))
		if first == null and second != null: return false
		if first != null and second == null: return true
		var comparison := 0
		if first != null:
			if first is String: comparison = U.fold(first).naturalnocasecmp_to(U.fold(str(second)))
			else: comparison = -1 if float(first) < float(second) else 1 if float(first) > float(second) else 0
		if comparison == 0: return str(a.id) < str(b.id)
		return comparison > 0 if descending else comparison < 0)
	return result

static func sort_value(player: Dictionary, key: String, live: bool = false) -> Variant:
	if key in ["rating","potential"]: return G.knowledge_sort_value(player,key,true)
	if key == "pos": return load("res://ui/immersive08/squad_canvas.gd").sort_value(player, "Poste")
	if key == "contractEnd": return horizon(player) if horizon(player) >= 0 else null
	if key == "renewal": return renewal_reason(player, live) if player.get("renewal") is Dictionary and not player.renewal.is_empty() else null
	var value: Variant = player.get(key)
	if key in ["rating","potential","age","salary","minutes"]:
		return value if (value is int or value is float) and is_finite(float(value)) else null
	return str(value) if value != null and not str(value).strip_edges().is_empty() else null

static func coverage(players: Array, season: int) -> Array:
	var groups: Dictionary = {}
	for player: Dictionary in players:
		var position := position_caption(player)
		if position.strip_edges().is_empty() or position == "—": position = "Poste non renseigné"
		if not groups.has(position): groups[position] = {"position":position,"total":0,"ending":0,"remaining":0,"unknown":0}
		groups[position].total += 1
		var ending := horizon(player)
		if ending < 0: groups[position].unknown += 1
		elif ending <= season: groups[position].ending += 1
		else: groups[position].remaining += 1
	var result: Array = groups.values()
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		if a.ending != b.ending: return a.ending > b.ending
		return str(a.position).naturalnocasecmp_to(str(b.position)) < 0)
	return result

static func renewal_reason(player: Dictionary, live: bool) -> String:
	if live: return "Match en cours : prolongation indisponible"
	var quote: Dictionary = player.get("renewal", {})
	if not str(quote.get("reason", "")).is_empty(): return str(quote.reason)
	if quote.get("negotiation", {}).get("status") == "withdrawn": return "Échanges clos pour cette journée"
	return "Prolongation accessible" if bool(quote.get("available", false)) else "Prolongation indisponible actuellement"

## Forme courte pour la colonne PROLONGATION (le motif complet reste en infobulle).
static func renewal_short(player: Dictionary, live: bool) -> String:
	var full := renewal_reason(player, live)
	if live: return "Match en cours"
	if full.begins_with("Prolongation accessible"): return "Accessible"
	if full.begins_with("Prolongation indisponible"): return "Indisponible"
	if full.begins_with("Échanges clos"): return "Échanges clos"
	if full.begins_with("Prêt entrant"): return "Prêt entrant"
	if full.begins_with("Pré-contrat"): return "Pré-contrat"
	return full

## Délégation des prolongations au directeur sportif (mode Monde : la clé « contracts » n'existe qu'alors).
func _delegation_staff(delegation: Dictionary) -> void:
	var box := CheckBox.new()
	box.name = "ContractDelegationStaff"
	box.text = "Confier aussi les prolongations au staff"
	box.button_pressed = bool(delegation.get("contracts", true))
	box.tooltip_text = "Le directeur sportif tranche en mars les fins de contrat que tu n'as pas réglées, dans la masse salariale que le club s'autorise et sous le plafond de la ligue."
	box.custom_minimum_size.y = 36
	box.add_theme_font_size_override("font_size", maxi(16, C.px(20)))
	box.disabled = not app._live().is_empty()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	row.add_child(box)
	# Le paragraphe d'aide devient une pastille compacte (icône + « Staff · mars · consigne ») ; le texte complet
	# reste en infobulle derrière le « i ». Le libellé complet est gardé dans ce nœud masqué (lecture et tests).
	var detail := _label(delegation_detail(app.model, box.button_pressed), 16, C.MUTED)
	detail.name = "ContractDelegationDetail"
	detail.visible = false
	row.add_child(detail)
	var chip := _chip_button("ContractDelegationChip", "people", C.MUTED, delegation_chip(app.model, box.button_pressed), detail.text, func(): app._navigate("Staff"), true)
	var chip_text := chip.get_meta("label") as Label
	row.add_child(chip)
	box.toggled.connect(func(value: bool):
		# Même mécanisme que les autres réglages de délégation (staff_view.gd) : décision optimiste côté interface.
		if app._command("set_delegation", {"key":"contracts", "enabled":value}):
			detail.text = delegation_detail(app.model, value)
			chip_text.text = delegation_chip(app.model, value)
			chip.tooltip_text = detail.text
		else:
			box.set_pressed_no_signal(not value))

## Texte court de la pastille à côté de la case (le texte complet est en infobulle).
static func delegation_chip(model: Dictionary, enabled: bool) -> String:
	if not enabled: return "Tu gères seul"
	var delegation: Dictionary = model.get("decisions", {}).get("delegation", {}) if model.get("decisions") is Dictionary and model.decisions.get("delegation") is Dictionary else {}
	var label := str(delegation.get("contractsPolicyLabel", ""))
	return "Staff · mars" + (" · " + label if not label.is_empty() else "")

## Texte sous la case selon l'état coché (testable sans interface).
static func delegation_detail(model: Dictionary, enabled: bool) -> String:
	if not enabled: return "Tu gères seul les prolongations : les contrats non prolongés partent à leur échéance."
	var delegation: Dictionary = model.get("decisions", {}).get("delegation", {}) if model.get("decisions") is Dictionary and model.decisions.get("delegation") is Dictionary else {}
	var text := "Le directeur sportif tranche en mars les échéances que tu n'as pas réglées, dans la masse que le club s'autorise et sous le plafond de la ligue ; chaque décision arrive au courrier, annulable."
	var label := str(delegation.get("contractsPolicyLabel", ""))
	if not label.is_empty(): text += " Consigne : %s." % label
	var decided: Array = delegation.get("contractsDecided", []) if delegation.get("contractsDecided") is Array else []
	if not decided.is_empty():
		var kept := 0
		var released := 0
		for entry: Variant in decided:
			if not entry is Dictionary: continue
			# Annulée par le manager : il part ; « prolonger quand même » : il reste.
			var state_name := str(entry.get("state", ""))
			if state_name == "force" or (state_name == "actif" and str(entry.get("decision", "")) == "prolonge"): kept += 1
			elif state_name == "annule" or str(entry.get("decision", "")) == "libere": released += 1
		text += " Cette saison : %d prolongé%s, %d laissé%s partir." % [kept, "s" if kept > 1 else "", released, "s" if released > 1 else ""]
	return text

func _label(text: String, size: int = 18, color: Color = C.IVORY, width: float = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", C.BODY)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0:
		label.custom_minimum_size.x = width
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return label

## Une colonne du tableau : largeur minimale réduite, le reste partagé selon le poids (même règle en-tête et lignes).
## Tuile de chiffre (libellé + nombre), cliquable : ouvre le marché des transferts.
func _tile(caption: String, value: int, id: String, tip: String, color: Color, glyph: String) -> Button:
	var tile := Button.new()
	tile.name = id
	tile.custom_minimum_size = Vector2(0, 66)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.tooltip_text = tip
	tile.accessibility_name = "%s : %d" % [caption, value]
	tile.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU_3, Charte.FILET, Charte.RAYON_CARTE, 10))
	tile.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_2, C.FAINT, Charte.RAYON_CARTE, 10))
	tile.add_theme_stylebox_override("pressed", C.box(Charte.SELECTION, C.IVORY, Charte.RAYON_CARTE, 10))
	tile.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, C.GOLD, Charte.RAYON_CARTE, 10))
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 0)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tint := color if value > 0 else Charte.GRIS_VERT
	var top_line := HBoxContainer.new()
	top_line.alignment = BoxContainer.ALIGNMENT_CENTER
	top_line.add_theme_constant_override("separation", 8)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(top_line)
	top_line.add_child(C.icon(glyph, 24, tint))
	var number := _label(str(value), 28, tint)
	number.autowrap_mode = TextServer.AUTOWRAP_OFF
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(number)
	var name_label := _label(caption, 16, C.MUTED)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)
	tile.pressed.connect(func(): Pages.ouvrir(app, "offres"))
	return tile

## Contenu non cliquable lui-même : tous les enfants laissent passer la souris au bouton qui les porte.
func _ignore_mouse(node: Node) -> void:
	if node is Control: (node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): _ignore_mouse(child)

## Bouton à contenu libre (tuile, pastille, ligne de barre) : fond teinté, survol, focus en anneau, curseur main.
func _link_button(id: String, content: Control, fill: Color, tip: String, action: Callable, radius: int = Charte.RAYON_CARTE, margin: int = 10) -> Button:
	var link := Button.new()
	link.name = id
	link.tooltip_text = tip
	link.focus_mode = Control.FOCUS_ALL
	link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	link.add_theme_stylebox_override("normal", C.box(fill, Color.TRANSPARENT, radius, margin))
	link.add_theme_stylebox_override("hover", C.box(fill.lerp(Color.WHITE, 0.06), Color.TRANSPARENT, radius, margin))
	link.add_theme_stylebox_override("pressed", C.box(fill.lerp(Color.WHITE, 0.12), Color.TRANSPARENT, radius, margin))
	link.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, Charte.IVOIRE, radius, margin))
	_ignore_mouse(content)
	link.add_child(content)
	link.custom_minimum_size = content.get_combined_minimum_size() + Vector2(margin * 2, margin * 2)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, margin)
	link.pressed.connect(action)
	return link

## Pastille cliquable : icône teintée + texte (+ « i » facultatif). Le libellé est gardé en méta « label ».
func _chip_button(id: String, glyph: String, tint: Color, text: String, tip: String, action: Callable, info: bool = false) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(C.icon(glyph, 18, tint))
	var label := _label(text, 16, C.IVORY)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	if info: row.add_child(C.icon("info", 16, C.MUTED))
	var chip := _link_button(id, row, Charte.PANNEAU_3, tip, action, Charte.RAYON_PILULE, 6)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.set_meta("label", label)
	return chip

## Petite fenêtre visuelle : les joueurs concernés en tuiles (portrait, prénom, NOM, poste, salaire). Échap, ✕ et clic à côté la ferment.
func _ouvrir_fenetre(titre: String, filtres: Dictionary, teinte: Color, focus: String) -> void:
	_fermer_fenetre()
	var joueurs: Array = filtered(app.model.get("squad", []), filtres)
	state.focus = focus
	var calque := Control.new()
	calque.name = "ContractWindowLayer"
	calque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	calque.z_index = 50
	app.add_child(calque)
	_fenetre = calque
	PetiteFenetre.enregistrer(calque, _fermer_fenetre)
	var voile := ColorRect.new()
	voile.name = "ContractWindowVeil"
	voile.color = Color(Charte.NUIT, 0.6)
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	voile.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: _fermer_fenetre())
	calque.add_child(voile)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.add_child(centre)
	var panneau := PanelContainer.new()
	panneau.name = "ContractWindow"
	panneau.add_theme_stylebox_override("panel", C.box(Charte.PANNEAU, teinte, Charte.RAYON_CARTE, 18))
	centre.add_child(panneau)
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 14)
	panneau.add_child(boite)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 14)
	boite.add_child(tete)
	var titre_label := _label(titre, 30, teinte)
	titre_label.name = "ContractWindowTitle"
	titre_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tete.add_child(titre_label)
	var compte := _label(str(joueurs.size()), 30, C.IVORY)
	compte.autowrap_mode = TextServer.AUTOWRAP_OFF
	tete.add_child(compte)
	var espace := Control.new()
	espace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(espace)
	var fermer := Button.new()
	fermer.name = "ContractWindowClose"
	fermer.text = "✕"
	fermer.focus_mode = Control.FOCUS_ALL
	fermer.custom_minimum_size = Vector2(44, 44)
	fermer.accessibility_name = "Fermer"
	fermer.pressed.connect(_fermer_fenetre)
	tete.add_child(fermer)
	var defilement := ScrollContainer.new()
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defilement.custom_minimum_size = Vector2(4 * 236 + 3 * 12, minf(560.0, 88.0 * ceilf(maxf(1.0, joueurs.size()) / 4.0)))
	boite.add_child(defilement)
	var grille := GridContainer.new()
	grille.columns = 4
	grille.add_theme_constant_override("h_separation", 12)
	grille.add_theme_constant_override("v_separation", 12)
	defilement.add_child(grille)
	for joueur: Dictionary in joueurs: grille.add_child(_tuile_joueur(joueur, teinte))
	var premier := grille.get_child(0) if grille.get_child_count() > 0 else fermer
	(premier as Control).call_deferred("grab_focus")

func _tuile_joueur(joueur: Dictionary, teinte: Color) -> Button:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 10)
	var portrait: Control = G.portrait(int(joueur.get("portraitIndex", 0)), 60, joueur)
	portrait.custom_minimum_size = Vector2(60, 60)
	ligne.add_child(portrait)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 0)
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	ligne.add_child(colonne)
	var mots := str(joueur.get("name", "Joueur")).split(" ", false)
	var nom_famille: Array = []
	var prenom: Array = []
	for mot: String in mots:
		if mot == mot.to_upper() and mot.length() > 1: nom_famille.append(mot)
		else: prenom.append(mot)
	if nom_famille.is_empty() and not prenom.is_empty(): nom_famille.append(prenom.pop_back())
	var petit := _label(" ".join(prenom), 14, C.MUTED)
	petit.autowrap_mode = TextServer.AUTOWRAP_OFF
	colonne.add_child(petit)
	var gras := _label(" ".join(nom_famille), 20, C.IVORY)
	gras.autowrap_mode = TextServer.AUTOWRAP_OFF
	colonne.add_child(gras)
	var pastilles := HBoxContainer.new()
	pastilles.add_theme_constant_override("separation", 6)
	colonne.add_child(pastilles)
	var poste := _label(position_text(joueur), 14, teinte)
	poste.autowrap_mode = TextServer.AUTOWRAP_OFF
	pastilles.add_child(poste)
	var salaire := _label(G.salary_amount(joueur.get("salary")), 14, BLEU)
	salaire.autowrap_mode = TextServer.AUTOWRAP_OFF
	pastilles.add_child(salaire)
	var identifiant := str(joueur.get("id", ""))
	var tuile := _link_button(action_id("ContractWindowPlayer", identifiant), ligne, Charte.PANNEAU_3.lerp(teinte, 0.14), str(joueur.get("name", "Joueur")), func():
		_fermer_fenetre()
		_open_profile(identifiant, "", action_id("ContractWindowPlayer", identifiant)), Charte.RAYON_PETIT, 8)
	tuile.custom_minimum_size = Vector2(236, 76)
	tuile.size_flags_horizontal = Control.SIZE_FILL
	return tuile

func _fermer_fenetre() -> void:
	if _fenetre != null and is_instance_valid(_fenetre):
		_fenetre.remove_from_group(PetiteFenetre.GROUPE)
		_fenetre.queue_free()
	_fenetre = null
	call_deferred("_restore_focus")

## Filtre posé depuis une tuile ou une barre : les menus et le tableau suivent.
func _apply_filter(values: Dictionary, focus: String) -> void:
	state.merge(values, true)
	state.scroll = 0
	state.focus = focus
	_sync_choices()
	_refresh()
	call_deferred("_restore_focus")

func _sync_choices() -> void:
	for index in _season.item_count:
		if int(_season.get_item_metadata(index)) == int(state.season): _season.select(index)
	_select_text(_status_choice, str(state.status), "Contrats : tous")
	_select_text(_precision_choice, str(state.precision), "Échéance : toutes")
	_select_text(_position, str(state.position), "Tous les postes")

func _select_text(choice: OptionButton, value: String, first: String) -> void:
	if choice == null: return
	choice.select(0)
	for index in choice.item_count:
		if choice.get_item_text(index) == value: choice.select(index)

func _fit(control: Control, key: String) -> Control:
	for column: Array in COLS:
		if column[0] == key:
			control.custom_minimum_size.x = column[1]
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			control.size_flags_stretch_ratio = column[2]
	return control

func _adapt() -> void:
	if _columns == null or _columns.get_child_count() < 2: return
	var host := get_parent_control()
	var width := host.size.x if host != null and host.size.x > 0 else size.x
	var wide := width >= LARGEUR_DEUX_COLONNES
	_columns.vertical = not wide
	var main_box := _columns.get_child(0) as Control
	var sidebar_box := _columns.get_child(1) as Control
	sidebar_box.custom_minimum_size = Vector2(440, 0) if wide else Vector2(0, 360)
	main_box.size_flags_stretch_ratio = 3.6 if wide else 1.0
	main_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_box.size_flags_stretch_ratio = 1.0
	# Page étroite : le panneau passe sous le tableau ; la page s'allonge (et défile) pour qu'il reste lisible.
	if host != null:
		if not host.has_meta("hauteur_page"): host.set_meta("hauteur_page", host.custom_minimum_size.y)
		var base := float(host.get_meta("hauteur_page"))
		host.custom_minimum_size.y = base if wide else maxf(base, position.y + get_combined_minimum_size().y + 40.0)

func _button(text: String, id: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	button.custom_minimum_size.y = 34
	button.add_theme_font_override("font", C.BOLD)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", C.IVORY)
	# Charte : pilule à contour FILET, focus en anneau doré (jamais de rectangle à angles vifs).
	var anneau := C.box(Color.TRANSPARENT, C.GOLD, 999, 14)
	anneau.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, C.LINE, 999, 14))
	button.add_theme_stylebox_override("hover", C.box(C.RAISED, C.FAINT, 999, 14))
	button.add_theme_stylebox_override("focus", anneau)
	button.pressed.connect(action)
	return button

func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", C.box(C.PANEL, C.LINE, 4, 10))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	return body

func _build() -> void:
	name = "ContractReview"
	add_theme_constant_override("separation", 10)
	if not app.management_ui.roster.has("contract_review"):
		app.management_ui.roster.contract_review = {"season":0,"status":"Tous","precision":"Toutes","position":"Tous","search":"","scroll":0,"focus":""}
	state = app.management_ui.roster.contract_review
	if not state.has("sort"): state.sort = "contractEnd"
	if not state.has("descending"): state.descending = false
	var delegation: Variant = app.model.get("decisions", {}).get("delegation") if app.model.get("decisions") is Dictionary else null
	if delegation is Dictionary and delegation.has("contracts"):
		_delegation_staff(delegation)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	var squad: Array = app.model.get("squad", [])
	var current := int(app.model.get("meta", {}).get("season", 1))
	var ending := squad.filter(func(player): return horizon(player) >= 0 and horizon(player) <= current).size()
	var renewals := squad.filter(func(player): return player.get("renewal", {}).get("available", false) and app._live().is_empty()).size()
	var known_wage := 0.0
	var unknown_wage := 0
	for player: Dictionary in squad:
		var wage: Variant = player.get("salary")
		if wage is int or wage is float: known_wage += float(wage)
		else: unknown_wage += 1
	var wage_note := " · %d ?" % unknown_wage if unknown_wage > 0 else ""
	# Vraies tuiles chiffre (comme le haut de l'Effectif) : icône teintée, gros chiffre coloré, légende courte, léger fond teinté.
	for metric in [["%d / %d" % [ending, squad.size()], "fin ≤ %s" % G.contract_year(current), "Échéances en %s ou avant : %d joueurs sur %d" % [G.contract_year(current), ending, squad.size()], "", ORANGE, "hourglass", "ContractReviewStatEnding", func(): _ouvrir_fenetre("Fin ≤ %s" % G.contract_year(current), {"season": current, "status": "Tous", "precision": "Toutes"}, ORANGE, "ContractReviewStatEnding")], ["%d" % renewals, "prolongeables", "Prolongations accessibles : %d joueurs" % renewals, "", VERT, "renew", "ContractReviewStatRenewable", func(): _ouvrir_fenetre("Prolongeables", {"season": 0, "status": "Prolongation accessible", "precision": "Toutes"}, VERT, "ContractReviewStatRenewable")], [G.salary_amount(known_wage), "salaires " + G.salary_period(true) + wage_note, "Salaires actuels projetés · " + G.salary_period() + " : ouvrir Finances, salaires", "ContractReviewWage", BLEU, "money", "ContractReviewStatWages", func(): _open_wages()]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		var glyph := C.icon(str(metric[5]), 34, metric[4])
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(glyph)
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", 0)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(texts)
		var value := _label(str(metric[0]), 34, metric[4])
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		if not str(metric[3]).is_empty(): value.name = str(metric[3])
		texts.add_child(value)
		var legend := _label(str(metric[1]), 16, C.MUTED)
		legend.autowrap_mode = TextServer.AUTOWRAP_OFF
		legend.clip_text = true
		legend.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		texts.add_child(legend)
		var stat := _link_button(str(metric[6]), line, Charte.PANNEAU.lerp(metric[4], 0.10), str(metric[2]), metric[7], Charte.RAYON_CARTE, 14)
		stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(stat)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	add_child(filters)
	var search := LineEdit.new()
	search.name = "ContractReviewSearch"
	search.placeholder_text = "Nom ou poste…"
	search.text = str(state.search)
	search.custom_minimum_size = Vector2(130, 36)
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.size_flags_stretch_ratio = 1.5
	search.add_theme_font_size_override("font_size", 18)
	filters.add_child(search)
	search.text_changed.connect(func(value): state.search = value; state.scroll = 0; _refresh())
	_season = _choice(filters, "ContractReviewSeason", "Toutes les années", func(index): state.season = int(_season.get_item_metadata(index)); state.scroll = 0; _refresh())
	_season.set_item_metadata(0, 0)
	var years: Array[int] = []
	for player: Dictionary in squad:
		var end := horizon(player)
		if end >= 0 and not end in years: years.append(end)
	years.sort()
	for year in years:
		_season.add_item("Fin " + G.contract_year(year))
		_season.set_item_metadata(_season.item_count - 1, year)
		if year == int(state.season): _season.select(_season.item_count - 1)
	var status := _choice(filters, "ContractReviewStatus", "Contrats : tous", func(index): state.status = STATUS_OPTIONS[index]; state.scroll = 0; _refresh())
	_status_choice = status
	_fill_choice(status, STATUS_OPTIONS.slice(1), str(state.status))
	var precision := _choice(filters, "ContractReviewPrecision", "Échéance : toutes", func(index): state.precision = ["Toutes","Échéance connue","Non renseignée"][index]; state.scroll = 0; _refresh())
	_precision_choice = precision
	_fill_choice(precision, ["Échéance connue", "Non renseignée"], str(state.precision))
	_position = _choice(filters, "ContractReviewPosition", "Tous les postes", func(index): state.position = "Tous" if index == 0 else _position.get_item_text(index); state.scroll = 0; _refresh())
	var positions: Array = []
	var previous_matches: Array = []
	for player: Dictionary in squad:
		var caption := position_caption(player)
		if caption.strip_edges().is_empty() or caption == "—": continue
		if not caption in positions: positions.append(caption)
		if str(player.get("pos", "")) == str(state.position) and not caption in previous_matches: previous_matches.append(caption)
	# Preserve an unambiguous remembered legacy filter; never rewrite player.pos.
	if str(state.position) != "Tous" and not str(state.position) in positions:
		state.position = previous_matches[0] if previous_matches.size() == 1 else "Tous"
	positions.sort()
	_fill_choice(_position, positions, str(state.position))
	filters.add_child(_button("Réinitialiser", "ContractReviewReset", _reset))
	_count = _label("", 16, C.MUTED)
	_count.name = "ContractReviewCount"
	add_child(_count)
	var columns := BoxContainer.new()
	_columns = columns
	columns.add_theme_constant_override("separation", 8)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(columns)
	var main := _panel(columns)
	main.get_parent().size_flags_stretch_ratio = 3.6
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", COL_GAP)
	var inset := Control.new()
	inset.custom_minimum_size.x = 8
	header.add_child(inset)
	for column in [["JOUEUR",0,"name"],["POSTE",0,"pos"],["NIV.",0,"rating"],["POT.",0,"potential"],["ÂGE",0,"age"],["FIN",0,"contractEnd"],["SALAIRE " + G.salary_period(true).to_upper(),0,"salary"],["MIN.",0,"minutes"],["STATUT",0,"status"],["PROLONG.",0,"renewal"],["CONSULTER",0,""]]:
		if str(column[2]).is_empty():
			header.add_child(_fit(_cell(column[0], 0, C.MUTED, 16), "actions"))
			continue
		var key := str(column[2])
		var sort := _button(str(column[0]), "ContractSort_" + key, func(): _sort(key))
		sort.custom_minimum_size.y = 30
		_fit(sort, key)
		sort.add_theme_font_size_override("font_size", 16)
		sort.clip_text = true
		sort.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		for mode in ["normal","hover","pressed"]:
			sort.add_theme_stylebox_override(mode, C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		sort.set_meta("caption", str(column[0]))
		sort.set_meta("tip", {"rating": "NIVEAU", "potential": "POTENTIEL", "contractEnd": "FIN DE CONTRAT", "renewal": "PROLONGATION"}.get(key, str(column[0])))
		header.add_child(sort)
		_headers[key] = sort
	var outset := Control.new()
	outset.custom_minimum_size.x = 8
	header.add_child(outset)
	main.add_child(header)
	_scroll = ScrollContainer.new()
	_scroll.name = "ContractReviewScroll"
	_scroll.follow_focus = true
	_scroll.mouse_force_pass_scroll_events = false
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = 400
	main.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.name = "ContractReviewRows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 2)
	_scroll.add_child(_rows)
	_scroll.get_v_scroll_bar().value_changed.connect(func(value): state.scroll = value)
	var sidebar := _panel(columns)
	sidebar.get_parent().size_flags_stretch_ratio = 1.0
	sidebar.get_parent().custom_minimum_size.x = 440
	resized.connect(_adapt)
	var host := get_parent_control()
	if host != null: host.resized.connect(_adapt)
	_adapt()
	# Marché des transferts (vente-joueurs.cjs) : joueurs proposés, offres reçues, ventes en attente.
	var sales := Sales.sales(app.model)
	if not sales.is_empty():
		sidebar.add_child(_label("Marché des transferts", 24))
		var tiles := HBoxContainer.new()
		tiles.name = "ContractReviewSalesSummary"
		tiles.add_theme_constant_override("separation", 8)
		sidebar.add_child(tiles)
		# Les trois chiffres ouvrent la même fenêtre (offres, ventes en attente, joueurs proposés).
		tiles.add_child(_tile("Proposés", (sales.get("listed", []) as Array).size(), "ContractReviewSalesListed", "Joueurs proposés aux autres clubs : ouvrir l'écran des offres", BLEU, "people"))
		tiles.add_child(_tile("Offres", (sales.get("offers", []) as Array).size(), "ContractReviewOpenSales", "Offres reçues : ouvrir l'écran des offres", VERT, "mail"))
		tiles.add_child(_tile("Ventes", (sales.get("pending", []) as Array).size(), "ContractReviewSalesPending", "Ventes en attente : ouvrir l'écran des offres", ORANGE, "money"))
	sidebar.add_child(_label("Échéances et postes à anticiper", 24))
	var departures := (sales.get("pending", []) as Array).size()
	var departures_chip := _chip_button("ContractReviewDepartures", "check" if departures == 0 else "warning", VERT if departures == 0 else ORANGE, "Aucun départ annoncé" if departures == 0 else "%d départ%s annoncé%s" % [departures, "s" if departures > 1 else "", "s" if departures > 1 else ""], "Ouvrir les offres et ventes (Recrutement)", func(): Pages.ouvrir(app, "offres"))
	sidebar.add_child(departures_chip)
	var side_scroll := ScrollContainer.new()
	side_scroll.follow_focus = true
	_scroll.mouse_force_pass_scroll_events = false
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(side_scroll)
	_coverage = VBoxContainer.new()
	_coverage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coverage.add_theme_constant_override("separation", 8)
	side_scroll.add_child(_coverage)
	_refresh()
	call_deferred("_restore_focus")

func _choice(parent: Node, id: String, first: String, changed: Callable) -> OptionButton:
	var choice := OptionButton.new()
	choice.name = id
	# Filtres : largeur minimale réduite, le reste partagé (la rangée tient en 1280 comme en 1920) ; texte coupé, valeur complète au survol.
	choice.custom_minimum_size = Vector2(110, 36)
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.clip_text = true
	choice.add_theme_font_override("font", C.BODY)
	choice.add_theme_font_size_override("font_size", 18)
	choice.fit_to_longest_item = false
	choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	choice.add_item(first)
	choice.item_selected.connect(changed)
	parent.add_child(choice)
	return choice

func _fill_choice(choice: OptionButton, values: Array, selected: String) -> void:
	for value in values:
		choice.add_item(str(value))
		if str(value) == selected: choice.select(choice.item_count - 1)

func _reset() -> void:
	state.merge({"season":0,"status":"Tous","precision":"Toutes","position":"Tous","search":"","scroll":0,"focus":"ContractReviewReset","sort":"contractEnd","descending":false}, true)
	app._render(false)

func _sort(key: String) -> void:
	state.descending = not bool(state.descending) if str(state.sort) == key else false
	state.sort = key
	state.scroll = 0
	state.focus = "ContractSort_" + key
	_refresh()
	_restore_focus()

func _refresh() -> void:
	for node in _rows.get_children(): _rows.remove_child(node); node.queue_free()
	for node in _coverage.get_children(): _coverage.remove_child(node); node.queue_free()
	var filters := state.duplicate(true)
	filters.live = not app._live().is_empty()
	var players := filtered(app.model.get("squad", []), filters)
	_count.text = "%d / %d" % [players.size(), app.model.get("squad", []).size()]
	for key: String in _headers:
		var sort: Button = _headers[key]
		var selected := str(state.sort) == key
		sort.text = str(sort.get_meta("caption")) + (" ▼" if state.descending else " ▲") if selected else str(sort.get_meta("caption")) + " ↕"
		sort.tooltip_text = "Trier par " + str(sort.get_meta("tip")) + (" · ordre décroissant" if selected and state.descending else " · ordre croissant" if selected else "")
		sort.accessibility_name = sort.tooltip_text
	if players.is_empty(): _rows.add_child(_label("Aucun joueur ne correspond. Modifie les filtres ou réinitialise la recherche.", 18, C.MUTED))
	for player: Dictionary in players: _row(player)
	var year := int(state.season) if int(state.season) > 0 else int(app.model.get("meta", {}).get("season", 1))
	_coverage.add_child(_label("Échéances par année", 19))
	var horizons: Dictionary = {}
	for player: Dictionary in app.model.get("squad", []):
		var end := horizon(player)
		horizons[end] = int(horizons.get(end, 0)) + 1
	var seasons: Array = horizons.keys()
	seasons.sort()
	for end in seasons:
		_bar(_coverage, "Non renseignée" if int(end) < 0 else "Fin " + G.contract_year(end), int(horizons[end]), app.model.get("squad", []).size(), C.MUTED if int(end) < 0 else ORANGE if int(end) <= year else CITRON if int(end) == year + 1 else VERT, "ContractReviewBar_" + str(end), func(): _ouvrir_fenetre("Non renseignée" if int(end) < 0 else "Fin " + G.contract_year(end), {"season": 0, "precision": "Non renseignée"} if int(end) < 0 else {"season": int(end), "precision": "Toutes"}, C.MUTED if int(end) < 0 else ORANGE if int(end) <= year else CITRON if int(end) == year + 1 else VERT, "ContractReviewBar_" + str(end)))
	_coverage.add_child(_label("Couverture · horizon " + G.contract_year(year), 19, C.IVORY))
	for group: Dictionary in coverage(app.model.get("squad", []), year):
		var button := _button("%s · %d / %d" % [group.position, group.ending, group.total], "ContractReviewCoverage_" + str(group.position).sha256_text().substr(0,16), func():
			state.position = str(group.position)
			state.focus = "ContractReviewCoverage_" + str(group.position).sha256_text().substr(0,16)
			for index in _position.item_count:
				if _position.get_item_text(index) == state.position: _position.select(index)
			_refresh()
			call_deferred("_restore_focus"))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text = "Filtrer le tableau sur ce poste"
		_coverage.add_child(button)
		var ratio := float(group.remaining) / maxf(1.0, float(group.total))
		var tint := ROUGE if ratio < 0.5 else ORANGE if ratio < 0.75 else VERT
		var progress := ProgressBar.new()
		progress.custom_minimum_size.y = 8
		progress.max_value = maxf(1, group.total)
		progress.value = group.remaining
		progress.show_percentage = false
		progress.add_theme_stylebox_override("background", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 4, 0))
		progress.add_theme_stylebox_override("fill", C.box(tint, Color.TRANSPARENT, 4, 0))
		_coverage.add_child(progress)
		var pill := PanelContainer.new()
		pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		pill.add_theme_stylebox_override("panel", Charte.style_pilule(Charte.PANNEAU.lerp(tint, 0.16), Color.TRANSPARENT, 12, 3))
		pill.tooltip_text = "%d sous contrat au-delà%s" % [group.remaining, " · %d sans échéance connue" % group.unknown if group.unknown > 0 else ""]
		var pill_text := _label("%d au-delà%s" % [group.remaining, " · %d ?" % group.unknown if group.unknown > 0 else ""], 16, tint)
		pill_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		pill.add_child(pill_text)
		_coverage.add_child(pill)
	_scroll.set_deferred("scroll_vertical", int(state.scroll))

func _cell(text: String, width: float, color: Color = C.IVORY, font_size: int = 18) -> Label:
	var label := _label(text, font_size, color, width)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = text
	return label

func _reading_cell(content: Control, player: Dictionary, prefix: String, section: String = "") -> Button:
	var player_id := str(player.id)
	var control_id := action_id(prefix, player_id)
	var link := Button.new()
	link.name = control_id
	link.custom_minimum_size = content.get_combined_minimum_size()
	link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	link.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	link.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, C.GOLD, 2, 0))
	link.set_meta("player_id", player_id)
	link.set_meta("entity_kind", "player")
	link.set_meta("entity_id", player_id)
	link.set_meta("entity_section", section)
	link.accessibility_name = ("Consulter le contrat · " if section == "contract" else "Consulter la fiche · ") + str(player.get("name", "Joueur"))
	link.tooltip_text = link.accessibility_name
	link.pressed.connect(func(): _open_profile(player_id, section, control_id))
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	link.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return link

func _bar(parent: Node, caption: String, value: int, total: int, color: Color, id: String = "", action: Callable = Callable()) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if action.is_valid():
		var link := _link_button(id, row, Color.TRANSPARENT, "%s : %d" % [caption, value], action, Charte.RAYON_PETIT, 4)
		link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		link.custom_minimum_size.y = 34
		parent.add_child(link)
	else:
		parent.add_child(row)
	row.add_child(_cell(caption, 142, C.MUTED, 16))
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(140, 12)
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.max_value = maxi(total, 1)
	progress.value = value
	progress.show_percentage = false
	progress.add_theme_stylebox_override("fill", C.box(color, Color.TRANSPARENT, 2, 0))
	row.add_child(progress)
	row.add_child(_cell(str(value), 40, color, 18))

func _row(player: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = action_id("ContractRow", str(player.id))
	panel.set_meta("player_id", str(player.id))
	panel.custom_minimum_size.y = 34
	var background := Color("18242a") if _rows.get_child_count() % 2 == 0 else Color("111b20")
	var style := C.box(background, Color.TRANSPARENT, 0, 0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	panel.add_theme_stylebox_override("panel", style)
	_rows.add_child(panel)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", COL_GAP)
	panel.add_child(line)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 6)
	_fit(identity, "name")
	line.add_child(identity)
	var portrait: Control = G.portrait(int(player.get("portraitIndex", 0)), 30, player)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(_reading_cell(portrait, player, "ContractPortraitLink"))
	identity.add_child(_fit(_reading_cell(_cell(str(player.get("name", "Joueur")), 0, C.IVORY, 18), player, "ContractNameLink"), "name"))
	identity.get_child(1).custom_minimum_size.x = 60
	var ending := horizon(player)
	var year := int(app.model.get("meta", {}).get("season", 1))
	var position := _fit(_cell(position_text(player), 0, C.MUTED, 16), "pos")
	position.name = action_id("ContractPosition", str(player.id))
	position.tooltip_text = "Poste principal · " + position_caption(player)
	line.add_child(position)
	var level := _fit(_cell(G.rating_text(player,true), 0, C.MINT, 16), "rating")
	level.name = action_id("ContractLevel", str(player.id))
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.tooltip_text = "Niveau global projeté / 100, identique à la fiche du joueur."
	line.add_child(level)
	var potential := _fit(_cell(G.potential_text(player), 0, Color("ffb454"), 16), "potential")
	potential.name = action_id("ContractPotential", str(player.id))
	potential.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	potential.tooltip_text = "Potentiel / 100. Ce plafond n’est pas garanti."
	line.add_child(potential)
	line.add_child(_fit(_cell(G.n(player.age) if player.get("age") != null else "—", 0, C.MUTED, 16), "age"))
	line.add_child(_fit(_reading_cell(_cell(G.contract_year(ending) if ending >= 0 else "Non renseignée", 0, C.GOLD if ending >= 0 and ending <= year else C.MINT if ending > year else C.MUTED, 16), player, "ContractEndLink", "contract"), "contractEnd"))
	var salary: Variant = player.get("salary")
	var salary_cell := _cell(G.salary_amount(salary) if salary is int or salary is float else "Non fourni", 0, C.IVORY, 16)
	salary_cell.name = action_id("ContractSalary",str(player.id))
	line.add_child(_fit(_reading_cell(salary_cell, player, "ContractSalaryLink", "contract"), "salary"))
	line.add_child(_fit(_cell(G.n(player.minutes) if player.get("minutes") != null else "—", 0, C.MUTED, 16), "minutes"))
	# Vente (vente-joueurs.cjs) : « En vente », « Offre reçue » ou « Départ prévu » remplace le statut ; détail en infobulle.
	var sale_short := sale_caption(player)
	var status_cell := _cell(sale_short if not sale_short.is_empty() else str(player.get("status", "—")), 0, C.GOLD if not sale_short.is_empty() else C.MUTED, 16)
	if not sale_short.is_empty():
		status_cell.name = action_id("ContractSale", str(player.id))
		status_cell.tooltip_text = Sales.status(player)
	line.add_child(_fit(status_cell, "status"))
	# Colonne PROLONGATION : icône seule (la forme porte le sens, pas la couleur) ; le motif exact est en infobulle.
	var can_renew: bool = app._live().is_empty() and renewal_short(player, false) == "Accessible"
	var renewal_icon := C.icon("renew" if can_renew else "lock", 24, VERT if can_renew else Charte.GRIS_VERT)
	var renewal_cell := _reading_cell(renewal_icon, player, "ContractRenewal", "contract")
	renewal_cell.tooltip_text = renewal_reason(player, not app._live().is_empty())
	renewal_cell.accessibility_name = "Prolongation · " + renewal_cell.tooltip_text
	renewal_cell.set_meta("renewal_short", renewal_short(player, not app._live().is_empty()))
	line.add_child(_fit(renewal_cell, "renewal"))
	var actions := HBoxContainer.new()
	_fit(actions, "actions")
	actions.add_theme_constant_override("separation", 6)
	line.add_child(actions)
	var id := str(player.id)
	var profile := _button("Fiche", action_id("ContractProfile", id), func(): _open_profile(id))
	profile.set_meta("player_id", id)
	profile.set_meta("entity_kind", "player")
	profile.set_meta("entity_id", id)
	_compact(profile, 1.0)
	actions.add_child(profile)
	var discussion: Dictionary = player.get("renewal", {}).get("negotiation", {})
	var quote := _button("Discussion" if not discussion.is_empty() else "Prolonger", action_id("ContractRenew", id), func(): _open_quote(id))
	quote.set_meta("player_id", id)
	_compact(quote, 1.6)
	quote.disabled = not app._live().is_empty() or (not bool(player.get("renewal", {}).get("available", false)) and discussion.is_empty())
	quote.tooltip_text = renewal_reason(player, not app._live().is_empty())
	actions.add_child(quote)

## Bouton d'action de ligne : largeur partagée, texte coupé plutôt que débordant, police de table.
func _compact(button: Button, ratio: float) -> void:
	button.custom_minimum_size.x = 40
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_stretch_ratio = ratio
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 16)

func _find(id: String) -> Dictionary:
	for player: Dictionary in app.model.get("squad", []):
		if str(player.id) == id: return player
	return {}

func _remember(id: String) -> void:
	state.focus = id
	state.scroll = _scroll.scroll_vertical

func _open_wages() -> void:
	app.management_ui["immersive08_finance_tab"] = "wages"
	app._navigate("Finances")

func _open_profile(id: String, section: String = "", control_id: String = "") -> void:
	if _find(id).is_empty(): return
	_remember(control_id if not control_id.is_empty() else action_id("ContractProfile", id))
	app.navigation_controller.open_entity({"kind":"player", "id":id, "section":section})

func _open_quote(id: String) -> void:
	var player := _find(id)
	if player.is_empty() or not app._live().is_empty(): return
	_remember(action_id("ContractRenew", id))
	app.selected_player = id
	app.SquadViews.contract(app, player, false)
	var dialog := app.get_node_or_null("ContractOffer")
	if dialog != null: dialog.tree_exited.connect(func(): call_deferred("_restore_focus"), CONNECT_ONE_SHOT)

func _restore_focus() -> void:
	if not is_inside_tree(): return
	if str(state.get("focus", "")).is_empty(): return
	var control := find_child(str(state.get("focus", "")), true, false) as Control
	if control != null and control.is_visible_in_tree(): control.grab_focus()
