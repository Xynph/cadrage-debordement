extends "res://ui/immersive08/match_avant_adversaire.gd"
## Écran « Avant-match » (écran 12 de la revue DA du 19/11/2026, variante 1 « L'affiche, puis les quatre vérifications »,
## plaques inclinées de la variante 3). Hors coque (charte §7) : illustration du tunnel plein cadre (variantes météo),
## bandeau haut (Menu, statut de feuille, date, « Déléguer le match », « COUP D'ENVOI » : le seul aplat or de l'écran),
## affiche (compétition, journée, lieu ; plaques inclinées aux couleurs des deux clubs ; heure ; forme, classement,
## confrontations, météo) puis quatre vérifications : feuille, conditions du match, adversaire, mot de Gabi. Chaque
## vérification mène à l'écran où l'on agit (Composition, Plan de jeu, Effectif, Préparation, Vestiaire).
## Clic sur un nom de joueur : fiche complète ; survol : mini-fiche (mini_fiche.gd). Aucune fenêtre : la délégation et
## l'appel d'un espoir sont des sous-pages (avant_match_pages.gd) gardées par l'historique (`management_ui.avant_page`).
## Toutes les valeurs viennent du modèle natif : `next`, `selection`, `squad`, `clubLife.avantMatch`
## (native/engine/avant-match.cjs). Rien n'est inventé : une donnée absente devient une phrase ou une ligne omise.
## Tailles données en pixels d'un écran 1080p (`M`), à l'échelle de la fenêtre comme le reste de l'interface.

## Le corps est réparti en chaîne d'héritage (même objet, mêmes noms) : match_avant_socle.gd ← match_avant_outils.gd ← match_avant_bandeau.gd ← match_avant_affiche.gd ← match_avant_verifications.gd ← match_avant_adversaire.gd ← ce fichier (construction de l'écran).

func _construire(model: Dictionary, next: Dictionary, play: Button, etat: Dictionary, page: String) -> void:
	var data: Dictionary = model.get("clubLife", {}).get("avantMatch") if model.get("clubLife", {}).get("avantMatch") is Dictionary else {}
	if str(data.get("fixtureId", "")) != str(next.get("id", data.get("fixtureId", ""))): data = {}
	var fond := Control.new()
	fond.name = "MatchPoster"
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(fond, true)
	content.add_child(fond)
	_fond(fond, model, next)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 0)
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fond.add_child(colonne)
	colonne.add_child(_bandeau(next, play, etat, not page.is_empty()))
	if next.is_empty():
		colonne.add_child(_vide(model))
		colonne.add_child(_pied(false))
		return
	if not page.is_empty():
		# Tests physiques d'avant-match (idée FM27 n° 36) : sous-page en liste.
		if page == "tests": colonne.add_child(Tests.page(self, app, model))
		else: colonne.add_child(Pages.construire(self, app, model, page))
		colonne.add_child(_pied(true))
		return
	var cote := _cote(model, next)
	colonne.add_child(_affiche(model, next, data, cote))
	# Les deux XV face à face sur un terrain, météo dessus, dans l'espace libre sous l'affiche (hors petite fenêtre).
	if FaceAFace.visible():
		colonne.add_child(FaceAFace.section(self, app, model, next, cote))
	else:
		var vide := Control.new()
		vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
		colonne.add_child(vide)
	colonne.add_child(_verifications(model, next, data, cote, etat))
	colonne.add_child(_pied(false))
	_donner_le_focus.call_deferred(page)

func _donner_le_focus(page: String) -> void:
	if not is_instance_valid(kickoff) or not kickoff.is_inside_tree() or not page.is_empty(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and focus != kickoff and is_ancestor_of(focus): return
	if not kickoff.disabled: kickoff.grab_focus()

func _cote(model: Dictionary, next: Dictionary) -> int:
	var club_id: Variant = model.get("club", {}).get("id")
	return 1 if next.get("away", {}).get("id") == club_id and club_id != null else 0

func _vide(model: Dictionary) -> Control:
	var zone := CenterContainer.new()
	C.fill(zone, true)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", M(12))
	zone.add_child(colonne)
	var fin: bool = model.get("meta", {}).get("canAdvanceSeason", false)
	var message := texte("Saison terminée." if fin else "Aucune rencontre à préparer pour le moment.", 26, C.IVORY, true, 700)
	message.name = "MatchAucuneRencontre"
	colonne.add_child(message)
	var calendrier := _bouton_lien("Voir le calendrier →", func(): _aller("Calendrier"), "MatchOpenCalendar", 18)
	colonne.add_child(calendrier)
	return zone

# ---- Fond -------------------------------------------------------------------------------------------------------

func _verifications(model: Dictionary, next: Dictionary, data: Dictionary, nous: int, etat: Dictionary) -> Control:
	var marge := MarginContainer.new()
	marge.name = "MatchPrematchTiles"
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right"]: marge.add_theme_constant_override("margin_" + edge, M(32))
	var ligne := HBoxContainer.new()
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_theme_constant_override("separation", M(16))
	marge.add_child(ligne)
	ligne.add_child(_feuille(model, etat))
	ligne.add_child(_meteo(model, next, nous, data))
	ligne.add_child(_adversaire(model, next, data, nous))
	ligne.add_child(_gabi(data))
	return marge

## Contrôle « rien ne déborde » (tests) : chaque tuile contient son contenu, l'écran tient dans sa zone.
func overflows() -> Array:
	var failures: Array = []
	for tile in find_children("*", "PanelContainer", true, false):
		if not tile.get_meta("prematch_tile", false): continue
		var inner: Control = tile.get_meta("content")
		var needed: Vector2 = tile.get_combined_minimum_size()
		if needed.y > tile.size.y + 0.5 or needed.x > tile.size.x + 0.5: failures.append("%s : %s pour %s" % [tile.name, needed, tile.size])
		if inner.get_combined_minimum_size().y > inner.size.y + 0.5: failures.append("%s : contenu %s pour %s" % [tile.name, inner.get_combined_minimum_size(), inner.size])
	var needed_all := get_combined_minimum_size()
	if needed_all.y > size.y + 0.5: failures.append("écran : %s pour %s" % [needed_all, size])
	return failures
