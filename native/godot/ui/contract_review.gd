extends "res://ui/contract_review_corps.gd"
## Read-only horizons from the current squad projection. No invented deadlines.
## Chaîne d'héritage : socle ← aides ← corps ← ce fichier (public : lignes de joueurs et redéfinitions des statiques lus ailleurs).
const Parties = preload("res://ui/contract_review_corps.gd")

## Points d'entrée statiques publics (tests, squad_canvas) : redéfinis ici, car `has_method` d'un script ne voit pas les statiques hérités.
static func mois_restants(player: Dictionary, today: String) -> float: return Parties.mois_restants(player, today)
static func tranche(mois: float) -> String: return Parties.tranche(mois)
static func tranche_couleur(id: String) -> Color: return Parties.tranche_couleur(id)
static func contexte(model: Dictionary) -> Dictionary: return Parties.contexte(model)
static func part_masse(player: Dictionary, ctx: Dictionary) -> float: return Parties.part_masse(player, ctx)
static func temps_de_jeu(player: Dictionary, ctx: Dictionary) -> float: return Parties.temps_de_jeu(player, ctx)
static func conseil(player: Dictionary) -> String: return Parties.conseil(player)
static func build(owner_app: Control) -> Control: return Parties.build(owner_app)
static func action_id(prefix: String, player_id: String) -> String: return Parties.action_id(prefix, player_id)
static func sale_caption(player: Dictionary) -> String: return Parties.sale_caption(player)
static func projected_mark(player: Dictionary, key: String) -> String: return Parties.projected_mark(player, key)
static func position_caption(player: Dictionary) -> String: return Parties.position_caption(player)
static func position_text(player: Dictionary) -> String: return Parties.position_text(player)
static func horizon(player: Dictionary) -> int: return Parties.horizon(player)
static func filtered(players: Array, filters: Dictionary) -> Array: return Parties.filtered(players, filters)
static func sort_value(player: Dictionary, key: String, live: bool = false) -> Variant: return Parties.sort_value(player, key, live)
static func coverage(players: Array, season: int) -> Array: return Parties.coverage(players, season)
static func renewal_reason(player: Dictionary, live: bool) -> String: return Parties.renewal_reason(player, live)
static func renewal_short(player: Dictionary, live: bool) -> String: return Parties.renewal_short(player, live)
static func delegation_chip(model: Dictionary, enabled: bool) -> String: return Parties.delegation_chip(model, enabled)
static func delegation_detail(model: Dictionary, enabled: bool) -> String: return Parties.delegation_detail(model, enabled)
static func duree_texte(mois: float) -> String: return Parties.duree_texte(mois)
static func pourcent(part: float) -> String: return Parties.pourcent(part)

func _ligne_vide(player: Dictionary) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.name = action_id("ContractRow", str(player.id))
	panel.set_meta("player_id", str(player.id))
	panel.custom_minimum_size.y = 40
	var style := C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	panel.add_theme_stylebox_override("panel", style)
	# Rayure une ligne sur deux et survol de ligne communs à toutes les listes (ui/survol_ligne.gd).
	load("res://ui/survol_ligne.gd").poser(panel).rang_fixe = _rows.get_child_count()
	_rows.add_child(panel)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", COL_GAP)
	panel.add_child(line)
	return line

func _identite(line: HBoxContainer, player: Dictionary) -> void:
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 8)
	_fit(identity, "name")
	line.add_child(identity)
	var portrait: Control = G.portrait(int(player.get("portraitIndex", 0)), 34, player)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(_reading_cell(portrait, player, "ContractPortraitLink"))
	identity.add_child(_fit(_reading_cell(_cell(str(player.get("name", "Joueur")), 0, C.IVORY, 18), player, "ContractNameLink"), "name"))
	identity.get_child(1).custom_minimum_size.x = 60

## Conseil du staff : pastille icône + mot ; un clic agit (prolongation, offres) ou ouvre l'onglet Contrat de la fiche.
func _cellule_conseil(player: Dictionary) -> Control:
	var id := conseil(player)
	var def: Array = CONSEILS[id]
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 6)
	ligne.add_child(C.icon(str(def[1]), 18, def[2]))
	var mot := _label(str(def[0]), 16, def[2])
	mot.autowrap_mode = TextServer.AUTOWRAP_OFF
	ligne.add_child(mot)
	var pid := str(player.id)
	var c: Variant = player.get("conseilStaff")
	var bouton := _link_button(action_id("ContractConseil", pid), ligne, Charte.PANNEAU_3.lerp(def[2], 0.16), "Conseil du staff : " + str(def[0]), func(): _agir_conseil(pid, id), Charte.RAYON_PILULE, 5)
	bouton.set_meta("conseil", id)
	if c is Dictionary: bouton.set_meta("raison", str(c.get("raison", "")))
	bouton.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bouton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cadre := HBoxContainer.new()
	_fit(cadre, "conseil")
	cadre.add_child(bouton)
	return cadre

func _agir_conseil(pid: String, id: String) -> void:
	var player := _find(pid)
	if player.is_empty(): return
	match id:
		"prolonger":
			if bool(player.get("renewal", {}).get("available", false)) and app._live().is_empty(): _open_quote(pid)
			else: _open_profile(pid, "contract", action_id("ContractConseil", pid))
		"vente", "vendre": Pages.ouvrir(app, "offres")
		_: _open_profile(pid, "contract", action_id("ContractConseil", pid))

## Part de la masse salariale : barre bleue + pourcentage ; un clic ouvre Finances (salaires).
func _cellule_masse(player: Dictionary) -> Control:
	var part := part_masse(player, _ctx)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 8)
	var plafond := maxf(0.01, 3.0 / maxf(1.0, float(_ctx.n)))
	var barre := ProgressBar.new()
	barre.custom_minimum_size = Vector2(40, 10)
	barre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barre.max_value = plafond
	barre.value = clampf(part, 0.0, plafond)
	barre.show_percentage = false
	barre.add_theme_stylebox_override("background", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 3, 0))
	barre.add_theme_stylebox_override("fill", C.box(BLEU, Color.TRANSPARENT, 3, 0))
	ligne.add_child(barre)
	var chiffre := _label(pourcent(part), 16, BLEU)
	chiffre.autowrap_mode = TextServer.AUTOWRAP_OFF
	chiffre.custom_minimum_size.x = 56
	chiffre.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chiffre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(chiffre)
	var lien := _link_button(action_id("ContractShare", str(player.id)), ligne, Color.TRANSPARENT, "%s de la masse salariale : Finances" % pourcent(part), func(): _open_wages(), Charte.RAYON_PETIT, 2)
	_fit(lien, "share")
	return lien

## Rôle promis au contrat (pastille commune ui/role_contrat.gd) + temps de jeu réel en barre de la couleur du rôle.
func _cellule_jeu(player: Dictionary) -> Control:
	var part := temps_de_jeu(player, _ctx)
	var role := Role.role(player)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 8)
	if not role.is_empty(): ligne.add_child(Role.pastille(role, 16))
	var barre := ProgressBar.new()
	barre.custom_minimum_size = Vector2(40, 10)
	barre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barre.max_value = 1.0
	barre.value = part
	barre.show_percentage = false
	barre.add_theme_stylebox_override("background", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 3, 0))
	barre.add_theme_stylebox_override("fill", C.box(Role.couleur(role) if not role.is_empty() else Charte.GRIS_VERT, Color.TRANSPARENT, 3, 0))
	ligne.add_child(barre)
	var lien := _reading_cell(ligne, player, "ContractPlaytime")
	lien.tooltip_text = "%s%s · %d min · %d matchs" % [Role.libelle(role) if not role.is_empty() else "Sans contrat", " promis" if Role.promis(player) else "", int(player.get("minutes", 0)), int(player.get("appearances", 0))]
	lien.set_meta("role", role)
	_fit(lien, "playtime")
	return lien

## Échéance : pastille colorée par tranche (année de fin + durée restante) ; un clic ouvre l'onglet Contrat de la fiche.
func _cellule_echeance(player: Dictionary) -> Control:
	var mois := mois_restants(player, str(_ctx.today))
	var couleur := tranche_couleur(tranche(mois))
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 6)
	if horizon(player) < 0:
		ligne.add_child(_cell("Non renseignée", 0, C.MUTED, 16))
	else:
		var fond := PanelContainer.new()
		fond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fond.add_theme_stylebox_override("panel", Charte.style_pilule(Charte.PANNEAU.lerp(couleur, 0.22), Color.TRANSPARENT, 10, 2))
		var interieur := HBoxContainer.new()
		interieur.add_theme_constant_override("separation", 5)
		fond.add_child(interieur)
		interieur.add_child(C.icon("hourglass", 16, couleur))
		var txt := _label(G.contract_year(horizon(player)) + " · " + duree_texte(mois), 16, couleur)
		txt.autowrap_mode = TextServer.AUTOWRAP_OFF
		interieur.add_child(txt)
		ligne.add_child(fond)
	var lien := _reading_cell(ligne, player, "ContractEndLink", "contract")
	_fit(lien, "contractEnd")
	return lien

func _row(player: Dictionary) -> void:
	var line := _ligne_vide(player)
	_identite(line, player)
	var id := str(player.id)
	var position := _fit(_cell(position_text(player), 0, C.MUTED, 16), "pos")
	position.name = action_id("ContractPosition", id)
	position.tooltip_text = "Poste principal · " + position_caption(player)
	line.add_child(position)
	var level := _fit(_cell(G.rating_text(player, true), 0, C.MINT, 16), "rating")
	level.name = action_id("ContractLevel", id)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.tooltip_text = "Niveau global projeté / 100, identique à la fiche du joueur."
	line.add_child(level)
	line.add_child(_fit(_cell(G.n(player.age) if player.get("age") != null else "—", 0, C.MUTED, 16), "age"))
	var salary: Variant = player.get("salary")
	var salary_cell := _cell(G.salary_amount(salary) if salary is int or salary is float else "Non fourni", 0, C.IVORY, 16)
	salary_cell.name = action_id("ContractSalary", id)
	line.add_child(_fit(_reading_cell(salary_cell, player, "ContractSalaryLink", "contract"), "salary"))
	line.add_child(_cellule_masse(player))
	line.add_child(_cellule_jeu(player))
	line.add_child(_cellule_echeance(player))
	line.add_child(_cellule_conseil(player))
	# Prolonger (ou reprendre la discussion) : l'action de l'ancienne colonne PROLONG., motif exact en infobulle.
	var actions := HBoxContainer.new()
	_fit(actions, "actions")
	line.add_child(actions)
	var discussion: Dictionary = player.get("renewal", {}).get("negotiation", {})
	var quote := _button("Discussion" if not discussion.is_empty() else "Prolonger", action_id("ContractRenew", id), func(): _open_quote(id))
	quote.set_meta("player_id", id)
	_compact(quote, 1.0)
	quote.disabled = not app._live().is_empty() or (not bool(player.get("renewal", {}).get("available", false)) and discussion.is_empty())
	quote.tooltip_text = renewal_reason(player, not app._live().is_empty())
	actions.add_child(quote)
