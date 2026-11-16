extends RefCounted
## Championnats suivis « comme Football Manager » : chaque championnat du Monde est suivi
## en détail (moteur de match complet) ou suivi de loin, avec une jauge de fluidité
## estimée pour cette machine. Le moteur fournit le banc d'essai et le tableau des coûts ;
## l'interface additionne seulement ce tableau quand on coche ou décoche.
const G = preload("res://ui/carnet_skin.gd")
const Club = preload("res://ui/club_views.gd")
const SELECTION := "creation_detailed_leagues"
const CUSTOM := "creation_detailed_custom"
const REQUESTED := "league_benchmark_requested"
const CACHE := "league_benchmark"
const ORDER := ["elite", "accession", "nationale", "prem", "champ", "urc", "srp", "jlo-d1", "jlo-d2"]
const COUNTRY := {"elite":"FR", "accession":"FR", "nationale":"FR", "prem":"GB", "champ":"GB", "urc":"URC", "srp":"SRP", "jlo-d1":"JP", "jlo-d2":"JP"}

## Machine : cœurs logiques et mémoire physique (Go), lus par Godot au lancement.
static func machine() -> Dictionary:
	var result := {"cores": OS.get_processor_count()}
	var physical := float(OS.get_memory_info().get("physical", -1))
	if physical > 0: result["memoryGb"] = snappedf(physical / 1073741824.0, 0.1)
	return result

## Dernier banc d'essai reçu du moteur (mis en cache côté moteur dans le profil).
static func benchmark(app: Control) -> Dictionary:
	var bench: Variant = app.model.get("meta", {}).get("leagueBenchmark")
	if bench is Dictionary and bench.get("costs") is Dictionary: app.management_ui[CACHE] = bench.duplicate(true)
	var cached: Variant = app.management_ui.get(CACHE, {})
	return cached if cached is Dictionary else {}

static func request_benchmark(app: Control, refresh: bool = false) -> void:
	# Une page construite pendant une autre commande redemandera la mesure au prochain rendu.
	if app.waiting: return
	if not refresh and (bool(app.management_ui.get(REQUESTED, false)) or not benchmark(app).is_empty()): return
	app.management_ui[REQUESTED] = true
	var payload := machine()
	if refresh:
		payload["refresh"] = true
		app.management_ui.erase(CACHE)
	# Jamais pendant la construction de la page : la réponse la reconstruit.
	app.call_deferred("_command", "league_benchmark", payload)

static func league_name(app: Control, id: String) -> String:
	var identity: Dictionary = app.pack_manager.competition(id, "creation") if app.pack_manager.has_method("competition") else {}
	return str(identity.get("name", Club.competition_name(id)))

## Championnats du Monde présents dans le catalogue de création, dans l'ordre du jeu.
static func leagues(app: Control, catalogue: Array) -> Array:
	var counts := {}
	for club: Dictionary in catalogue:
		var division := str(club.get("division", ""))
		if not division.is_empty(): counts[division] = int(counts.get(division, 0)) + 1
	var result: Array = []
	for id: String in ORDER:
		if counts.has(id): result.append({"id":id, "clubs":counts[id], "name":league_name(app, id)})
	return result

static func ordered(ids: Array, all: Array) -> Array:
	var result: Array = []
	for league: Dictionary in all:
		if league.id in ids: result.append(league.id)
	return result

## Dernier cran de la jauge encore jugé confortable (Fluide, en vert) pour les choix par défaut.
const COMFORT_INDEX := 0

## Par défaut, comme FM : le championnat du club choisi (ses coupes d'Europe suivent dans
## le moteur), puis les autres championnats de son pays tant que la jauge de cette machine
## reste confortable. Sans mesure de la machine : le championnat du club seul.
static func default_for(own: String, all: Array, costs: Dictionary = {}) -> Array:
	var country: String = COUNTRY.get(own, "")
	var result: Array = []
	for league: Dictionary in all:
		if league.id == own: result.append(league.id)
	if costs.is_empty() or country.is_empty(): return result
	for league: Dictionary in all:
		if league.id == own or COUNTRY.get(league.id, "") != country: continue
		var trial := result.duplicate()
		trial.append(league.id)
		if int(estimate(costs, trial).get("index", 99)) <= COMFORT_INDEX: result = trial
	return ordered(result, all)

static func selected(app: Control, own: String, all: Array) -> Array:
	var ids: Array = []
	if bool(app.management_ui.get(CUSTOM, false)):
		var stored: Variant = app.management_ui.get(SELECTION, [])
		if stored is Array: ids = stored.duplicate()
	else:
		ids = default_for(own, all, benchmark(app).get("costs", {}))
	if not own.is_empty() and own not in ids: ids.append(own)
	return ordered(ids, all)

## Estimation : coût fixe de la saison plus le surcoût de chaque championnat détaillé.
static func estimate(costs: Dictionary, ids: Array) -> Dictionary:
	if costs.is_empty(): return {}
	var season := float(costs.get("baseSeasonMs", 0))
	var table: Dictionary = costs.get("leagues", {})
	for id: String in table:
		if id in ids: season += float(table[id].get("extraDetailedMs", 0))
	var weeks := maxi(1, int(costs.get("weeks", 46)))
	var week := season / weeks
	var levels: Array = costs.get("levels", [])
	var level: Dictionary = {}
	var index := 0
	for i in levels.size():
		level = levels[i]
		index = i
		var limit: Variant = level.get("maxWeekMs")
		if limit != null and week <= float(limit): break
	return {"weekMs":week, "seasonMs":season, "level":level, "index":index, "count":levels.size()}

static func duration(milliseconds: float) -> String:
	var seconds := roundi(milliseconds / 1000.0)
	if seconds < 60: return "%d s" % maxi(1, seconds)
	var minutes := roundi(seconds / 60.0)
	if minutes < 60: return "%d min" % minutes
	return "%d h %02d" % [int(minutes / 60.0), minutes % 60]

## Couleur d'état du carnet (succès, alerte, danger) : aucune couleur propre à la jauge.
static func state_color(level: Dictionary) -> Color:
	match str(level.get("state", "")):
		"succes": return G.GOOD
		"alerte": return G.GOLD
		"danger": return G.ALERT
	return G.MUTED

## Jauge à trois crans (Fluide, Correct, Lent) aux couleurs d'état du carnet.
static func gauge(parent: Node, app: Control, ids: Array) -> void:
	var bench := benchmark(app)
	var costs: Dictionary = bench.get("costs", {})
	var result := estimate(costs, ids)
	var block := G.v(5)
	block.name = "LeagueDetailGauge"
	parent.add_child(block)
	if result.is_empty():
		block.add_child(G.wrap("Mesure de votre machine en cours… La jauge s’affiche dans un instant.", 13, G.MUTED))
		return
	var level: Dictionary = result.level
	var tint := state_color(level)
	var head := G.h(10)
	block.add_child(head)
	var verdict := G.label(str(level.get("label", "")), 22, tint, true)
	verdict.name = "LeagueDetailVerdict"
	head.add_child(verdict)
	var timing := G.wrap("≈ %s par semaine de jeu · ≈ %s par saison" % [duration(result.weekMs), duration(result.seasonMs)], 13, G.INK)
	timing.name = "LeagueDetailTiming"
	G.fill(timing)
	timing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(timing)
	var bar := G.h(3)
	bar.name = "LeagueDetailBar"
	block.add_child(bar)
	var levels: Array = costs.get("levels", [])
	for i in levels.size():
		var notch := ColorRect.new()
		notch.custom_minimum_size = Vector2(0, 10)
		G.fill(notch)
		notch.color = state_color(levels[i]) if i <= int(result.index) else G.LINE
		notch.tooltip_text = str(levels[i].get("label", ""))
		bar.add_child(notch)
	var legend := G.h(3)
	block.add_child(legend)
	for i in levels.size():
		var caption := G.label(str(levels[i].get("label", "")), 10, G.INK if i == int(result.index) else G.MUTED)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		G.fill(caption)
		legend.add_child(caption)

static func machine_line(app: Control) -> String:
	var bench := benchmark(app)
	if bench.is_empty(): return "Votre machine : mesure en cours."
	var parts := PackedStringArray()
	if bench.get("cores") != null: parts.append("%d cœurs" % int(bench.cores))
	if bench.get("memoryGb") != null: parts.append("%s Go de mémoire" % str(snappedf(float(bench.memoryGb), 0.1)))
	parts.append("banc d’essai %d ms + %d ms" % [roundi(float(bench.get("serialMs", 0))), roundi(float(bench.get("computeMs", 0)))])
	return "Votre machine : " + " · ".join(parts) + "."

## Encart de la page de création : résumé, jauge et accès au choix détaillé.
static func summary(app: Control, parent: Node, own: String, catalogue: Array) -> void:
	var all := leagues(app, catalogue)
	if all.size() < 2: return
	request_benchmark(app)
	var ids := selected(app, own, all)
	var box := G.card(parent, G.GOLD)
	box.name = "CreationLeagueDetail"
	box.add_child(G.label("CHAMPIONNATS SUIVIS", 11, G.MUTED))
	box.add_child(G.wrap("%d suivi%s en détail sur %d · les autres suivis de loin." % [ids.size(), "s" if ids.size() > 1 else "", all.size()], 13, G.INK))
	gauge(box, app, ids)
	var open_button := G.button("Choisir les championnats…", func(): open(app, own, catalogue))
	open_button.name = "CreationLeagueDetailOpen"
	box.add_child(open_button)

## Liste envoyée à new_career (le moteur ajoute de toute façon le championnat du club).
static func payload(app: Control, own: String, catalogue: Array) -> Array:
	return selected(app, own, leagues(app, catalogue))

## Fenêtre de choix. `career` : la carrière existe déjà, le choix vaut pour la saison suivante.
static func open(app: Control, own: String, catalogue: Array, career: Dictionary = {}) -> void:
	var existing := app.get_node_or_null("LeagueDetailDialog")
	if existing != null:
		app.remove_child(existing)
		existing.queue_free()
	var all: Array = []
	var chosen: Array = []
	if career.is_empty():
		all = leagues(app, catalogue)
		chosen = selected(app, own, all)
	else:
		for league: Dictionary in career.get("leagues", []):
			all.append({"id":str(league.id), "clubs":int(league.get("clubs", 0)), "name":str(league.get("name", league.id))})
			if bool(league.get("next", league.get("detailed", true))): chosen.append(str(league.id))
	var dialog := AcceptDialog.new()
	dialog.name = "LeagueDetailDialog"
	dialog.title = "Championnats suivis"
	app._prepare_dialog(dialog, 760)
	dialog.get_ok_button().text = "Valider" if career.is_empty() else "Appliquer à la saison suivante"
	var body := G.panel(dialog)
	body.add_child(G.label("SUIVI DU RUGBY MONDIAL", 11, G.MUTED))
	body.add_child(G.wrap("Suivi en détail, votre cellule d’analyse décortique chaque rencontre : statistiques et notes des joueurs, équipe-type, feuilles de match complètes. Suivi de loin, vous recevez les scores, les classements, les blessures et l’évolution des joueurs, sans notes individuelles ni feuilles de match : le monde avance bien plus vite.", 13, G.INK))
	body.add_child(G.wrap("Toujours suivis en détail : votre championnat, vos coupes d’Europe, les phases finales et les clubs des joueurs que vous suivez au recrutement.", 13, G.GOLD))
	if not career.is_empty():
		body.add_child(G.wrap("Comme dans les grands jeux de gestion, le changement prend effet au début de la saison suivante, pour garder des statistiques de saison complètes.", 13, G.GOLD))
	var gauge_box := G.v(4)
	body.add_child(gauge_box)
	gauge(gauge_box, app, chosen)
	var refresh := func():
		for child in gauge_box.get_children():
			gauge_box.remove_child(child)
			child.queue_free()
		gauge(gauge_box, app, chosen)
	body.add_child(G.separator())
	var list := G.v(2)
	list.name = "LeagueDetailList"
	body.add_child(list)
	var checks := {}
	for league: Dictionary in all:
		var row := G.h(10)
		list.add_child(row)
		var check := CheckBox.new()
		check.name = "LeagueDetail_" + str(league.id)
		check.text = "%s · %d clubs" % [league.name, int(league.clubs)]
		check.button_pressed = league.id in chosen
		check.disabled = league.id == own
		check.add_theme_font_size_override("font_size", 14)
		# Couleurs du thème de la fenêtre (encre claire, grisé pour le championnat verrouillé) :
		# une encre forcée ici restait sombre sur le fond sombre des fenêtres du jeu.
		G.fill(check)
		row.add_child(check)
		var tag := G.label("", 11, G.MUTED)
		row.add_child(tag)
		var paint := func(on: bool):
			tag.text = "VOTRE CHAMPIONNAT" if league.id == own else ("SUIVI EN DÉTAIL" if on else "SUIVI DE LOIN")
			tag.add_theme_color_override("font_color", G.GOOD if on else G.MUTED)
		paint.call(check.button_pressed)
		checks[league.id] = check
		check.toggled.connect(func(on: bool):
			if on and league.id not in chosen: chosen.append(league.id)
			elif not on: chosen.erase(league.id)
			var sorted := ordered(chosen, all)
			chosen.clear()
			chosen.append_array(sorted)
			paint.call(on)
			refresh.call())
	var shortcuts := G.h(8)
	body.add_child(shortcuts)
	var set_all := func(on: bool):
		for id: String in checks:
			if id != own: checks[id].button_pressed = on
	shortcuts.add_child(G.button("Tout suivre en détail", set_all.bind(true)))
	shortcuts.add_child(G.button("Seulement mon championnat", set_all.bind(false)))
	var spacer := Control.new()
	G.fill(spacer)
	shortcuts.add_child(spacer)
	shortcuts.add_child(G.button("Mesurer à nouveau", func():
		dialog.queue_free()
		app.management_ui.erase(REQUESTED)
		request_benchmark(app, true)))
	body.add_child(G.wrap(machine_line(app), 12, G.MUTED))
	body.add_child(G.wrap("Estimation mesurée sur cette machine pour une semaine jouée en déléguant le match, réunions et conférence comprises.", 11, G.MUTED))
	dialog.confirmed.connect(func():
		var final := ordered(chosen, all)
		dialog.queue_free()
		if career.is_empty():
			app.management_ui[SELECTION] = final
			app.management_ui[CUSTOM] = true
			app._render(false)
		else:
			app._command("league_detail_set", {"detailed":final}))
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	dialog.popup_centered(Vector2i(760, 640))

## En carrière (Paramètres) : ouvre le choix pour la saison suivante.
static func open_career(app: Control) -> void:
	var projection: Variant = app.model.get("clubLife", {}).get("leagueDetail", {})
	if not projection is Dictionary or not bool(projection.get("available", false)): return
	open(app, str(projection.get("own", "")), [], projection)
