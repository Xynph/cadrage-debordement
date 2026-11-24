extends "res://ui/immersive08/squad_tableau.gd"
## Écran Effectif (maquette validée du 19/11/2026, variante « nouvelle 1 ») : titre et quatre tuiles, onglets,
## puces de filtre, tableau pleine largeur groupé Avants / Arrières. Pas de fiche à droite : le survol d'un nom
## (ou du « i ») montre la mini-fiche, le clic ouvre la fiche complète. Tout est dessiné sur le gabarit 2248 de large
## et sert à toutes les tailles de fenêtre ; en fenêtre étroite on retire des colonnes plutôt que de réduire le texte.
const Socle = preload("res://ui/immersive08/squad_socle.gd")

## Points d'entrée publics (fiches, comparateur, tests) : redéfinis ici, car `has_method` d'un script ne voit pas les statiques hérités.
static func primary_numbers(player: Dictionary) -> Array[int]: return Socle.primary_numbers(player)
static func primary_caption(player: Dictionary) -> String: return Socle.primary_caption(player)
static func fitted_position(caption: String, label: Label) -> String: return Socle.fitted_position(caption, label)
static func secondary_numbers(player: Dictionary) -> Array[int]: return Socle.secondary_numbers(player)
static func secondary_caption(player: Dictionary) -> String: return Socle.secondary_caption(player)
static func secondary_roles(player: Dictionary) -> Array[String]: return Socle.secondary_roles(player)
static func secondary_tooltip(player: Dictionary, model: Dictionary) -> String: return Socle.secondary_tooltip(player, model)
static func sort_value(player: Dictionary, key: String) -> Variant: return Socle.sort_value(player, key)
static func ordered_players(source: Array, reading: Dictionary, season: int) -> Array: return Socle.ordered_players(source, reading, season)

static func build(owner_app: Control) -> Control:
	var page: Control = load("res://ui/immersive08/squad_canvas.gd").new()
	page.app = owner_app
	page._build()
	return page

func _build() -> void:
	name = "CarnetSquad"
	custom_minimum_size = Vector2(LARGEUR, HAUT_PAGE) * C.density
	C.fill(self, true)
	state = app.management_ui.roster
	state.family = app.roster_filter
	state.sort = app.roster_sort
	if state.sort == "Note":
		state.sort = "Niveau"; state.descending = true; app.roster_sort = "Niveau"
	elif state.sort == "Étoiles":
		state.sort = "Note au poste"; app.roster_sort = "Note au poste"
	_entete_page()
	_onglets()
	if int(state.get("immersive_tab", 0)) == 2:
		var review := preload("res://ui/contract_review.gd").build(app)
		add_child(review)
		D.place(review, Rect2(0, Y_FILTRES, LARGEUR, HAUT_PAGE - Y_FILTRES - 40))
		return
	if int(state.get("immersive_tab", 0)) == 4:
		# Planificateur d'effectif (revue FM27, idée 11) : terrain + liste du poste, saisons à venir (planificateur.gd).
		preload("res://ui/immersive08/planificateur.gd").construire(self, app, Y_FILTRES, HAUT_PAGE - 4)
		return
	_dy = DY_RANGEES
	_poste = int(state.get("etoiles_poste", 0))
	# Panneaux latéraux à gauche : bandeau des filtres, totaux, pastilles de poste et tableau prennent la largeur restante.
	_x0 = Panneaux.reserve(app)
	_lt = LARGEUR - _x0
	_filtres()
	_rangees_listes()
	_tableau()
	_bandeau_filtres()
	Panneaux.construire(self, app, Y_FILTRES - 10.0, HAUT_PAGE - 4)
	_refresh(true)
	_restaurer()

## Bandeau des filtres (demande de Léo du 21/11/2026) : recherche, puces, tuiles des totaux, pastilles de poste et
## en-têtes de colonnes dans un panneau teinté détouré, aligné sur la largeur réelle du tableau.
func _bandeau_filtres() -> void:
	var haut := Y_FILTRES - 10.0
	# Un seul bloc, recherche comprise, aligné sur le tableau à droite des panneaux latéraux (même haut que la colonne).
	var bandeau := Bandeau.poser(self, Rect2(_x0, haut, _lt, Y_ENTETE + _dy + 36.0 - haut), 40.0)
	var table := get_node_or_null("ImmersiveRosterTable") as Control
	if table != null: bandeau.suivre(table)

## Rend la lecture (focus, défilement) puis, si personne n'a fait défiler la liste, ramène le joueur choisi dans la zone visible.
func _restaurer() -> void:
	_restaurant = true
	# Une case de forme porte le même nom sur chaque ligne : on ne lui rend pas le focus (il sauterait en tête de liste).
	if str(state.get("focus", "")).begins_with("FormeMatch"): state.focus = ""
	await U.restore(app, self, "roster")
	_restaurant = false
	if not is_instance_valid(self) or not is_inside_tree() or int(state.get("scroll", 0)) > 0: return
	await get_tree().process_frame
	var defile := find_child("SquadScroll", true, false) as ScrollContainer
	if defile == null: return
	for ligne: Node in rows.get_children():
		if ligne.get_meta("player_id", "") == app.selected_player:
			defile.ensure_control_visible(ligne as Control)
			break

# ---------------------------------------------------------------- pastilles de poste et tuiles des totaux

func _choisir_groupe(id: String) -> void:
	state.poste_groupe = id
	state.scroll = 0
	state.focus = "PostePastille_" + (id if not id.is_empty() else "tous")
	app._render(false)

## Poste choisi (clic sur un maillot du terrain XV ; 0 = ✕) : la liste se classe par note au poste ; sans
## poste, retour au tri par poste.
func choisir_etoiles(numero: int) -> void:
	state.etoiles_poste = numero
	state.scroll = 0
	if numero > 0:
		state.sort = "Note au poste"; state.descending = true; app.roster_sort = "Note au poste"
	elif str(state.sort) == "Note au poste":
		state.sort = "Poste"; state.descending = false; app.roster_sort = "Poste"
	state.focus = ("PanneauJoueur_%d" % numero) if numero > 0 else ""
	app._render(false)

func poste_etoiles() -> int:
	return _poste

func _rangees_listes() -> void:
	var joueurs: Array = app.model.get("squad", [])
	Listes.pastilles_postes(self, Vector2(_x0 + Bandeau.MARGE, Y_POSTES), Listes.compter_groupes(joueurs), joueurs.size(), str(state.get("poste_groupe", "")), _choisir_groupe)
	# Poste choisi sur le terrain XV : titre, nombre de Naturels et de Confirmés, ✕ (au bout de la rangée).
	Etoiles.titre_poste(self, _x0 + _lt - Bandeau.MARGE, Y_POSTES, joueurs, _poste, choisir_etoiles)
	_bandeau_totaux = Control.new()
	_bandeau_totaux.name = "RosterTuilesTotaux"
	add_child(_bandeau_totaux)
	D.place(_bandeau_totaux, Rect2(_x0 + Bandeau.MARGE, Y_TOTAUX, _lt - 2.0 * Bandeau.MARGE, 62))
