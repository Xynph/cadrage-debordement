extends "res://ui/immersive08/office_affiche.gd"
## Écran Bureau : les trois priorités, objectif du conseil, état du groupe et pastilles d’alerte (découpe de office_canvas.gd, sans changement).

# ---------------------------------------------------------------------------------------------------------
# Priorités
# ---------------------------------------------------------------------------------------------------------

static func _priorities(card: Panel, app: Control, w: int = 900) -> void:
	_objectif(card, app, w)
	var tasks := Office.priorities(app.model)
	if tasks.is_empty(): D.text(card, 26, 130, "Reprends une carrière pour retrouver les décisions du club.", 21, Charte.IVOIRE_2, 400, w - 56, HORIZONTAL_ALIGNMENT_LEFT, true)
	for i in tasks.size():
		var y := 100.0 + i * 90.0
		var item: Dictionary = tasks[i]
		# Rouge si urgent, orange si c'est pour aujourd'hui, bleu sinon (le seul doré de l'écran reste Continuer).
		var tint: Color = R.ROUGE if item.level == "urgent" else R.ORANGE if str(item.deadline) in ["Aujourd’hui", "Maintenant", "Résultat en attente"] else R.BLEU
		D.line(card, Vector2(20, y), Vector2(w - 20, y), Color(Charte.FILET, .7))
		D.rect(card, Rect2(20, y + 10, 4, 66), tint).name = "OfficePriority" + str(i + 1)
		_ex(D.text(card, 44, y + 60, str(i + 1), 46, Charte.IVOIRE, 800, 44))
		var echeance_w := _largeur(str(item.deadline), 19, C.font(600)) + 70
		var action := _zone(card, Rect2(20, y + 2, w - 40, 84), str(item.title), Office.open_priority.bind(app, item), str(item.id), 22, 66, 40)
		action.set_meta("priority_number", i + 1)
		action.set_meta("inline_number", false)
		action.tooltip_text = item.title + "\n" + Office.priority_description(item)
		action.accessibility_name = action.tooltip_text.replace("\n", " · ")
		# Échéance : pastille (icône + mot) au bord droit ; plus de phrase d'explication sous le titre (21/11) :
		# le motif reste dans l'infobulle de la ligne, un compte devient une tuile (chiffre + légende courte).
		var pastille := R.pastille(card, 0, y + 30, str(item.deadline), tint, "calendar", "OfficePriorityDeadline" + str(i + 1), 21)
		pastille.position.x = C.px(w - 40) - pastille.size.x
		var compte: Variant = item.get("count")
		var tuile_seule: bool = bool(item.get("tile_only", false)) and compte != null
		if tuile_seule:
			action.text = ""
			R.tuile(card, Rect2(92, y + 14, minf(w - 150 - echeance_w, R.largeur(G.n(compte), 40, 800) + R.largeur(str(item.get("unit", "")).to_upper(), 17) + 56), 62), G.n(compte), str(item.get("unit", "")), R.ORANGE, "OfficePriorityTile" + str(i + 1), 40, true)
		elif compte != null:
			R.tuile(card, Rect2(92, y + 44, minf(w - 150 - echeance_w, R.largeur(G.n(compte), 26, 800) + R.largeur(str(item.get("unit", "")).to_upper(), 17) + 56), 38), G.n(compte), str(item.get("unit", "")), R.ROUGE if item.id == "OfficeMedicalPriorityAction" else R.ORANGE, "OfficePriorityTile" + str(i + 1), 26, true)
		else:
			for etat in ["normal", "hover", "pressed", "focus"]:
				var style := action.get_theme_stylebox(etat) as StyleBoxFlat
				if style != null: style.content_margin_bottom = 0
		# Noms de joueurs du titre : fiche au clic, mini-fiche au survol.
		if not tuile_seule: noms_cliquables(app, card, Rect2(90, y + (10 if compte != null else 28), w - 260, 30), str(item.title), 22, C.font(700))
	var y_pied := 100.0 + 3 * 90.0 + 14.0
	# « Mon carnet personnel » (une fenêtre) n'est plus au Bureau : décision de Léo, plus de petite fenêtre ; le carnet
	# de la semaine est celui de Gabi, à droite.
	if not tasks.any(func(item: Dictionary): return item.id == "OfficeTrainingAction") and not app.model.meta.get("canAdvanceSeason", false) and app.model.meta.get("phase", "") != "ended":
		_lien(card, 24, y_pied, "Entraînement →", func(): app.Immersive.open_training(app), "OfficeTrainingAction", 20)

## « Objectif du conseil : … » sous le titre ; sans objectif : « Aucun objectif fixé ».
static func _objectif(card: Panel, app: Control, w: int) -> void:
	var statut := objective_status(app.model, P.standings(app.model))
	var texte := "Aucun objectif fixé"
	if not statut.is_empty():
		var place := "" if statut.rank == null else " · %s%s" % [G.n(statut.rank), "er" if int(statut.rank) == 1 else "e"]
		texte = "%s%s · %s" % [str(statut.label), place, statut.trend]
	var libelle := D.text(card, 24, 84, "OBJECTIF DU CONSEIL", 16, Charte.IVOIRE_2, 700, 220)
	var objectif := D.text(card, 24 + _largeur("OBJECTIF DU CONSEIL", 16, C.font(700)) + 16, 84, texte, 20, Charte.IVOIRE, 600, w - 330, HORIZONTAL_ALIGNMENT_LEFT, true)
	objectif.name = "OfficeBoardObjective"
	libelle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not statut.is_empty(): objectif.tooltip_text = "Objectif du conseil : %s (place visée : %d)" % [str(statut.label), int(statut.target)]

# ---------------------------------------------------------------------------------------------------------
# État du groupe
# ---------------------------------------------------------------------------------------------------------

static func _group(card: Panel, app: Control, w: int = 580) -> void:
	var group := P.group(app.model)
	var right := w - 24
	var disponibles := _zone(card, Rect2(16, 66, 220, 70), "", app.navigation_controller.open_roster_group, "OfficeGroupAvailable", 20)
	disponibles.tooltip_text = "Voir les %s joueurs disponibles" % G.n(group.available)
	D.text(card, 24, 118, group.available, 52, Charte.V, 800, 90)
	D.text(card, 24 + _largeur(G.n(group.available), 52, C.font(800)) + 14, 116, "disponible" if int(group.available) <= 1 else "disponibles", 21, Charte.IVOIRE, 600, 130)
	var vers_blesses := func():
		if app.navigation_controller.has_method("open_roster_injured"): app.navigation_controller.open_roster_injured()
		else: app.navigation_controller.open_roster_group()
	var blesses := _zone(card, Rect2(250, 66, 220, 70), "", vers_blesses, "OfficeGroupInjured", 20)
	blesses.tooltip_text = "Voir les %s joueurs blessés" % G.n(group.injured)
	D.text(card, 258, 118, "! " + G.n(group.injured) if int(group.injured) > 0 else G.n(group.injured), 52, R.ROUGE if int(group.injured) > 0 else Charte.IVOIRE_2, 800, 100)
	var chiffre_blesses := "! " + G.n(group.injured) if int(group.injured) > 0 else G.n(group.injured)
	D.text(card, 258 + _largeur(chiffre_blesses, 52, C.font(800)) + 14, 116, "blessé" if int(group.injured) <= 1 else "blessés", 21, Charte.IVOIRE, 600, 110)
	var fatigue := Avis.fatigue_resume(app.model)
	var titulaires := int(fatigue.count)
	var jauges: Array = [
		["CONDITION PHYSIQUE", float(group.condition), "%d %%" % int(group.condition), Charte.V, float(fatigue.seuil)],
		["MORAL DU VESTIAIRE", float(app.model.meta.get("morale", 0)), "%d / 100" % int(float(app.model.meta.get("morale", 0))), Charte.IVOIRE_2, -1.0],
		["CONFIANCE DU CONSEIL", float(app.model.meta.get("trust", 0)), "%d / 100" % int(float(app.model.meta.get("trust", 0))), Charte.IVOIRE_2, -1.0],
	]
	for i in jauges.size():
		var jauge: Array = jauges[i]
		var y := 150.0 + i * 46.0
		D.text(card, 24, y, jauge[0], 16, Charte.IVOIRE_2, 700, 260)
		if float(jauge[4]) >= 0.0: D.text(card, right - 100, y, "SEUIL %d" % int(jauge[4]), 16, Charte.IVOIRE_2, 700, 130, HORIZONTAL_ALIGNMENT_RIGHT)
		D.text(card, right, y + 4, str(jauge[2]), 21, Charte.IVOIRE, 600, 110, HORIZONTAL_ALIGNMENT_RIGHT)
		D.bar(card, Rect2(24, y + 12, right - 24 - 130, 8), float(jauge[1]), jauge[3])
		if float(jauge[4]) >= 0.0: D.rect(card, Rect2(24 + (right - 24 - 130) * float(jauge[4]) / 100.0, y + 8, 2, 16), Charte.IVOIRE)
		# Condition → groupe, moral → vestiaire ; mini-courbe au survol (relevé hebdomadaire du moteur).
		if i < 2:
			var vers: Callable = app.navigation_controller.open_roster_group if i == 0 else func(): app._navigate("Vestiaire")
			var zone := _zone(card, Rect2(16, y - 14, right - 8, 36), "", vers, ["OfficeGroupCondition", "OfficeGroupMorale"][i], 16)
			zone.accessibility_name = "%s · %s" % [str(jauge[0]).capitalize(), str(jauge[2])]
			preload("res://ui/mini_courbe_survol.gd").lier(app, zone, ["condition", "morale"][i], ["Condition du groupe", "Moral du vestiaire"][i])
	# Alertes en pastilles cliquables (21/11) : « ⚠ 8 < 70 % » (titulaires fatigués → composition) et « ⚑ 15 »
	# (joueurs sous surveillance → effectif filtré) ; la phrase reste dans l'infobulle.
	var y_alerte := 296.0
	var x_pastille := 24.0
	if titulaires > 0:
		var texte_fatigue := "%d titulaire%s du prochain match sous %d %%" % [titulaires, "s" if titulaires > 1 else "", int(fatigue.seuil)]
		x_pastille += _pastille_action(card, x_pastille, 290, "%d < %d %%" % [titulaires, int(fatigue.seuil)], R.ORANGE, "warning", func(): app._navigate("Composition"), "OfficeFatigueAction", texte_fatigue + " · ouvrir la composition") + 12
		y_alerte = 336.0
	var x_exemple := x_pastille
	if group.watched > 0:
		x_exemple += _pastille_action(card, x_pastille, 290, G.n(group.watched), R.ORANGE, "flag", app.navigation_controller.open_watched_roster, "OfficeWatchedAction", U.watch_caption(group.watched)) + 14
		y_alerte = 336.0
	var avec_blesses := _blesses(card, app, y_alerte, w)
	if group.watched > 0:
		# Sans blessé : l'exemple du premier surveillé sous les pastilles. Avec blessés, « ! Blessés » garde cette ligne
		# et l'exemple se range à droite des pastilles (le surveillé reste lié à sa fiche).
		if avec_blesses: _exemple_surveille(card, app, x_exemple, 290, w - 24 - x_exemple)
		else: _exemple_surveille(card, app, 25, 350, w - 52)
	elif titulaires <= 0 and int(group.injured) <= 0:
		D.text(card, 25, 330, "Aucune alerte physique", 21, Charte.V, 600, w - 52).name = "OfficeNoAlert"
	_lien(card, 20, ROW2_H - 44, "Consulter le groupe →", app.navigation_controller.open_roster_group, "OfficeSquadAction", 21)

## Premier joueur surveillé (« nom · raison ») : ouvre sa fiche, mini-fiche au survol.
static func _exemple_surveille(card: Panel, app: Control, x: float, baseline: float, largeur: float) -> void:
	if largeur < 80.0: return
	for player: Dictionary in app.model.get("squad", []):
		var reason := U.watch_reason(player)
		if reason.is_empty(): continue
		var exemple := D.text(card, x, baseline, str(player.name) + " · " + reason, 19, Charte.IVOIRE_2, 500, largeur)
		exemple.tooltip_text = exemple.text
		var lien_exemple := _label_reading(app, card, exemple, {"kind": "player", "id": str(player.id)}, "OfficeWatchedPlayer_" + str(player.id).validate_node_name(), str(player.name))
		if lien_exemple != null: MiniFiche.lier(app, lien_exemple, str(player.id), "squad")
		return

## Blessés : « ! Blessés : nom, nom » ; chaque nom ouvre la fiche (mini-fiche au survol). Rien sans blessé.
static func _blesses(card: Panel, app: Control, baseline: float, w: int) -> bool:
	var noms: Array[Dictionary] = []
	for player: Dictionary in app.model.get("squad", []):
		if float(player.get("injury", 0)) > 0 and not str(player.get("id", "")).is_empty(): noms.append(player)
	if noms.is_empty(): return false
	var x := 25.0
	var entete := D.text(card, x, baseline, "! Blessés :", 20, R.ROUGE, 700, 130)
	entete.name = "OfficeInjuredHeading"
	x += 112
	for player: Dictionary in noms.slice(0, 2):
		var nom := str(player.get("name", ""))
		var largeur := _largeur(nom, 20) + 14
		if x + largeur > w - 24: break
		var lien := Link.styled_button(card, Rect2(x, baseline - 24, largeur, maxf(30, C.reach(30))), nom, 20, Charte.IVOIRE, "OfficeInjured_" + str(player.id).validate_node_name())
		lien.add_theme_font_override("font", Charte.texte_moyen())
		var cible := {"kind": "player", "id": str(player.id)}
		if app.navigation_controller.entity_available(cible):
			lien.pressed.connect(func(): app.navigation_controller.open_entity(cible))
			MiniFiche.lier(app, lien, str(player.id), "squad")
		x += largeur + 8
	if noms.size() > 2:
		var reste := "+%d blessé%s →" % [noms.size() - 2, "s" if noms.size() > 3 else ""]
		var plus := _lien(card, x, baseline - 24, reste, func():
			if app.navigation_controller.has_method("open_roster_injured"): app.navigation_controller.open_roster_injured()
			else: app.navigation_controller.open_roster_group(), "OfficeInjuredMore", 20)
		plus.tooltip_text = "Voir tous les joueurs blessés"
	return true

## Pastille d'alerte cliquable (contour fin = cliquable) ; renvoie sa largeur (gabarit).
static func _pastille_action(card: Panel, x: float, baseline: float, texte: String, couleur: Color, icone: String, action: Callable, id: String, aide: String) -> float:
	var fond := R.pastille(card, x, baseline, texte, couleur, icone, id + "Texte", 20)
	var style := (fond.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.border_color = Color(couleur, .55)
	style.set_border_width_all(1)
	fond.add_theme_stylebox_override("panel", style)
	var zone := Rect2(fond.position / C.density, fond.size / C.density)
	var bouton := _zone(card, zone, "", action, id, 20)
	bouton.tooltip_text = aide
	bouton.accessibility_name = aide
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return zone.size.x

## Objectif du conseil : place visée, place actuelle et tendance.
## Jalon « place au classement » de la direction s'il existe, sinon l'objectif sportif du club (« Top 6 », « Maintien »…).
static func objective_status(model: Dictionary, rows: Array) -> Dictionary:
	var club: Dictionary = model.get("club", {})
	var size := rows.size()
	for league in model.get("leagues", []):
		if league is Dictionary and league.get("id") == model.get("meta", {}).get("leagueId"): size = maxi(size, league.get("rows", []).size())
	var target := 0
	var label := ""
	var strategy: Variant = model.get("clubLife", {}).get("clubStrategy", {})
	var board: Dictionary = strategy.get("board", {}) if strategy is Dictionary and strategy.get("board") is Dictionary else {}
	for goal in board.get("objectives", []):
		if goal is Dictionary and str(goal.get("type", "")) == "rank" and str(goal.get("status", "pending")) == "pending" and goal.get("target") != null:
			target = int(goal.get("target"))
			label = "Top %d" % target if target > 1 else "Titre"
			break
	if target <= 0:
		var text := str(club.get("goal", "")).strip_edges()
		var lower := text.to_lower()
		if lower.begins_with("top "): target = int(text.substr(4))
		elif lower.contains("titre"): target = 2
		elif lower.contains("maintien") and size > 2: target = size - 2
		label = "Titre" if lower.contains("titre") else text
	if target <= 0 or size == 0: return {}
	var rank: Variant = null
	for row: Dictionary in rows:
		if row.get("id") == club.get("id") and P.standings_open(row): rank = row.get("rank")
	if rank == null: return {"label": label, "target": target, "rank": null, "trend": "à lancer", "tone": "muted"}
	var delta := target - int(rank)
	var trend := "en avance" if delta >= 2 else "dans l’objectif" if delta >= 0 else "à portée" if delta >= -2 else "en retard"
	return {"label": label, "target": target, "rank": int(rank), "trend": trend, "tone": "good" if delta >= 0 else "warn" if delta >= -2 else "bad"}
