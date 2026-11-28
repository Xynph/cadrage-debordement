extends "res://ui/contextual/match_between_journee.gd"
## Mon XV, banc et changements de l'écran intermédiaire du match.

## Colonne de gauche (Gabi, événements, enjeu, bonus, banc) : le banc garde la hauteur de ses 8 lignes tant qu'il y a la
## place ; quand la colonne n'en a plus (bulles de Gabi, duel, bonus de fin de match), les événements cèdent leur hauteur
## et défilent, mesurés sur le cadre de la page : la barre de Mon XV ne sort plus de l'écran (relevé du 26/11 : page de
## 959 à 962 px pour 921 px de cadre à la 76e minute en 1920 × 1080).
func _tenir_gauche() -> void:
	if not is_instance_valid(_colonne_gauche) or not is_instance_valid(_page_fm) or not is_instance_valid(_defile_ev): return
	var avec_banc := is_instance_valid(_defile_banc) and is_instance_valid(zone_banc)
	var h_banc := ceilf(zone_banc.get_combined_minimum_size().y) if avec_banc else 0.0
	# Hauteur offerte par le cadre, pas celle de la page : une page trop pleine grandit au-delà de son cadre, et sa
	# propre taille ne disait plus qu'il fallait céder.
	var cadre := _page_fm.get_parent() as Control
	var h_page := cadre.size.y - _page_fm.offset_top + _page_fm.offset_bottom if cadre != null else _page_fm.size.y
	if h_page <= 0.0:
		if avec_banc and not is_equal_approx(_defile_banc.custom_minimum_size.y, h_banc): _defile_banc.custom_minimum_size.y = h_banc
		return
	var grille := _colonne_gauche.get_parent() as Control
	var ecart := float(_page_fm.get_theme_constant("separation"))
	var autres := 0.0
	var rangs := 0
	for e: Node in _page_fm.get_children():
		var c := e as Control
		if c == null or not c.visible or c.top_level: continue
		rangs += 1
		if c != grille: autres += c.get_combined_minimum_size().y
	var dispo_grille := h_page - autres - ecart * maxf(0.0, rangs - 1)
	# Ce que la colonne demande hors événements et hors banc (Gabi, duel ou arrêt, enjeu, bonus, cadres et écarts).
	var ev_visible := _defile_ev.is_visible_in_tree()
	var fixe := _colonne_gauche.get_combined_minimum_size().y - (_defile_ev.get_combined_minimum_size().y if ev_visible else 0.0) - (_defile_banc.custom_minimum_size.y if avec_banc and _defile_banc.is_visible_in_tree() else 0.0)
	var place := dispo_grille - fixe
	if ev_visible and _defile_ev.get_child_count() > 0:
		var h_contenu := (_defile_ev.get_child(0) as Control).get_combined_minimum_size().y
		var hauteur := floorf(clampf(h_contenu, 0.0, maxf(0.0, place - h_banc)))
		if not is_equal_approx(_defile_ev.custom_minimum_size.y, hauteur): _defile_ev.custom_minimum_size.y = hauteur
		place -= hauteur
	# Le banc garde ses 8 lignes (vérificateur du 24/11, godot-cris-banc) : il ne cède jamais sa hauteur.
	if avec_banc and not is_equal_approx(_defile_banc.custom_minimum_size.y, h_banc): _defile_banc.custom_minimum_size.y = h_banc

## D3 : carte haute d'un joueur (barre basse de Mon XV) : visage et numéro, nom, énergie (jauge et valeur ou alerte),
## note du match en pastille et plaquages.
func _remplir_carte_haute(case: Button, poste: int, joueur: Dictionary, info: Dictionary) -> Control:
	var condition := float(info.energie)
	var alerte := str(info.alerte)
	var grave := alerte in ["épuisé", "blessé"]
	var colonne := S.G.v(px(3))
	colonne.name = "MatchBetweenCardBody"
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	S.full(colonne)
	colonne.offset_left = px(8)
	colonne.offset_right = -px(8)
	colonne.offset_top = px(6)
	colonne.offset_bottom = -px(6)
	case.add_child(colonne)
	var haut := S.G.h(0)
	haut.alignment = BoxContainer.ALIGNMENT_CENTER
	haut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(haut)
	# Anneau d'énergie autour du visage (couleur de la jauge : vert en forme, orange, rouge).
	haut.add_child(_visage(joueur, px(56), _numero(str(info.id), poste + 1), condition))
	var nom := _nom_joueur(abreger_prenom(str(joueur.get("name", ""))), str(info.id), "", {})
	nom.set_meta("nom_carte", str(joueur.get("name", "")) + "|" + str(info.id))
	nom.custom_minimum_size.y = px(28)
	# Prénom en initiale sur la carte ; le nom complet reste celui du joueur (infobulle, fenêtre, tests).
	for lien_nom: Node in nom.find_children("MatchBetweenPlayerName_*", "Button", true, false): lien_nom.set_meta("nom_complet", str(joueur.get("name", "")))
	colonne.add_child(nom)
	var energie := S.G.h(px(6))
	energie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energie.custom_minimum_size.y = px(22)
	colonne.add_child(energie)
	if not alerte.is_empty():
		var mot := _texte(alerte.get_slice(",", 0), 17, Charte.PERTE if grave or alerte.begins_with("carton") or alerte == "exclu" else Charte.INTENSIF, false, true)
		mot.name = "MatchBetweenPlayerAlert"
		mot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		S.G.fill(mot)
		energie.add_child(mot)
	else:
		var jauge := Jauge.new()
		jauge.valeur = condition
		jauge.vive = true
		jauge.densite = _densite
		jauge.custom_minimum_size = Vector2(px(40), px(16))
		jauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		S.G.fill(jauge)
		energie.add_child(jauge)
	var valeur := _texte(("! " if condition < EPUISE else "") + "%d %%" % roundi(condition), 18, Jauge.teinte_vive(condition), false, true)
	valeur.add_theme_font_override("font", TITRES_EXTRA)
	valeur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	valeur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energie.add_child(valeur)
	var bas := S.G.h(px(6))
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(bas)
	var mot_plaq := _texte("PLAQ.", 17, DOUX, false, true)
	mot_plaq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mot_plaq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bas.add_child(mot_plaq)
	var plaq := _texte(str(int(info.get("plaquages", 0))), 18, IVOIRE, false, true)
	plaq.add_theme_font_override("font", TITRES_EXTRA)
	plaq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plaq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(plaq)
	bas.add_child(plaq)
	bas.add_child(_pastille_note(float(info.note)))
	# Moral du joueur en direct (moteur : départ = réaction à la causerie, puis les faits du match) : pastille + mot,
	# flèche quand il bouge nettement depuis 5 minutes.
	var moral := moral_joueur(_pilotage, str(info.id))
	var ligne_moral := S.G.h(px(5))
	ligne_moral.name = "MatchBetweenPlayerMorale"
	ligne_moral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne_moral.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_child(ligne_moral)
	var teinte_moral := teinte_moral(str(moral.get("cle", "")))
	var rond := PanelContainer.new()
	rond.add_theme_stylebox_override("panel", _case(teinte_moral, Charte.RAYON_PILULE))
	rond.custom_minimum_size = Vector2(px(12), px(12))
	rond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne_moral.add_child(rond)
	var tendance := int(moral.get("tendance", 0))
	var mot_moral := _texte(str(moral.get("label", "")) + (" ▲" if tendance > 0 else (" ▼" if tendance < 0 else "")), 16, teinte_moral, false, true)
	mot_moral.name = "MatchBetweenPlayerMoraleWord"
	mot_moral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne_moral.add_child(mot_moral)
	ligne_moral.visible = not moral.is_empty()
	case.custom_minimum_size = Vector2(px(130), px(172))
	return colonne

## La zone des tuiles de Mon XV garde la hauteur de ses tuiles (elle ne défile pas) : jamais écrasée par la page.
func _tenir_xv() -> void:
	if is_instance_valid(defile_xv) and is_instance_valid(xv): defile_xv.custom_minimum_size.y = xv.get_combined_minimum_size().y

## Tuile d'un joueur de Mon XV (carte rayon 12) : son visage découpé en rond (D2 : cerclé de l'anneau de son énergie)
## avec son numéro en médaillon ; son nom ; l'énergie (jauge et valeur, ou l'alerte écrite) ; plaquages et note du match
## en pastille. La tuile ouvre l'écran Équipe sur lui, son nom sa petite fenêtre.
func _tuile_joueur(poste: int, joueur: Dictionary, info: Dictionary) -> Button:
	var case := Button.new()
	case.name = "MatchBetweenPlayer%d" % (poste + 1)
	case.flat = false
	case.focus_mode = Control.FOCUS_ALL
	case.set_meta("contextual_enabled", true)
	var id_joueur := str(info.id)
	case.pressed.connect(func(): menu_vers.call(id_joueur, case) if menu_vers.is_valid() else ouvrir_fiche(id_joueur))
	var condition := float(info.energie)
	var alerte := str(info.alerte)
	var grave := alerte in ["épuisé", "blessé"]
	var fond := _case(Charte.VOILE_DORE if grave else RELIEF, Charte.RAYON_CARTE)
	var survol := _case(SURVOL, Charte.RAYON_CARTE)
	var focus := _case(SURVOL, Charte.RAYON_CARTE)
	_anneau(focus)
	for style: StyleBox in [fond, survol, focus]: style.set_content_margin_all(0)
	case.add_theme_stylebox_override("normal", fond)
	case.add_theme_stylebox_override("hover", survol)
	case.add_theme_stylebox_override("pressed", survol)
	case.add_theme_stylebox_override("focus", focus)
	case.add_theme_stylebox_override("disabled", fond)
	case.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	S.G.fill(case)
	case.set_meta("player_id", str(info.id))
	if grave: case.set_meta("signale", true)
	case.tooltip_text = str(info.detail)
	var app_carte: Object = _app()
	if app_carte is Control: CarteSurvol.lier(app_carte, case, str(info.id), "squad", func(): return _direct_carte(str(info.id)))
	_remplir_carte_haute(case, poste, joueur, info)
	# Changement en attente du prochain arrêt de jeu (rôle, consignes, sortie) : pastille dorée discrète.
	var badge: Array = MenuJoueur.texte_badge(_live_courant(), id_joueur)
	# Carte réutilisée tant que le joueur du poste ne change pas (_maj_tuiles_xv).
	case.set_meta("tuile_xv", true)
	case.set_meta("badge", str(badge[0]))
	case.set_meta("cle_carte", JSON.stringify([joueur.get("name", ""), info, _numero(id_joueur, poste + 1), badge, moral_joueur(_pilotage, id_joueur), _densite]))
	if not str(badge[0]).is_empty(): MenuJoueur.badge_attente(case, str(badge[0]), str(badge[1]))
	return case

## Remplacement du prochain arrêt de jeu tout juste fait : carte sortant (rouge) / entrant (vert) sur la phrase de jeu,
## jamais sur le terrain 2D, quand le direct montré (`montre` : composition d'avant la borne) l'a rejoint.
func _montrer_changement(live: Dictionary, direct: Dictionary, montre: Array) -> void:
	var faits: Array = MenuJoueur.arrets(live).get("appliques", []) if MenuJoueur.arrets(live).get("appliques") is Array else []
	var dernier: Dictionary = {}
	for f: Variant in faits:
		if f is Dictionary and str(f.get("type", "")) == "remplacement" and bool(f.get("ok", false)): dernier = f
	if dernier.is_empty():
		_changement_amorce = true
		return
	var n := int(dernier.get("n", -1))
	if _changement_vu < 0 and not _changement_amorce and n >= 0 and int(live.get("minute", 0)) - int(dernier.get("minute", 0)) > 2:
		_changement_vu = n
		return
	if n <= _changement_vu: return
	var slot := int(dernier.get("slot", -1))
	var entre: Variant = montre[slot] if slot >= 0 and slot < montre.size() else null
	if not (entre is Dictionary and str(entre.get("id", "")) == str(dernier.get("inId", ""))): return
	_changement_vu = n
	# Sur la bande de la phrase de jeu (même cachée pendant un temps fort 3D : la carte y reste quelques secondes).
	if not is_instance_valid(phrase_fm): return
	var zone: Control = phrase_fm
	var notes: Dictionary = direct.get("notes", {}) if direct.get("notes") is Dictionary else {}
	var sortant := {"numero": _numero(str(dernier.get("outId", "")), int(dernier.get("slot", 0)) + 1), "nom": "", "note": -1.0, "energie": 100.0}
	var entrant := {"numero": _numero(str(dernier.get("inId", "")), 0), "nom": "", "lettre_poste": {}, "energie": 100.0}
	for j: Variant in (live.get("lineup", []) if live.get("lineup") is Array else []) + (live.get("reserves", []) if live.get("reserves") is Array else []):
		if not j is Dictionary: continue
		if str(j.get("id", "")) == str(dernier.get("outId", "")):
			sortant.nom = str(j.get("name", ""))
			sortant.energie = float(j.get("condition", 100))
			sortant.note = float(W.donnees_joueur(j, notes, {}, {}).note) if notes.has(str(j.id)) else -1.0
		if str(j.get("id", "")) == str(dernier.get("inId", "")):
			entrant.nom = str(j.get("name", ""))
			entrant.energie = float(j.get("condition", 100))
			var complet: Dictionary = Commune.trouver(_app(), str(j.id), "squad").get("joueur", {}) if _app() is Control else {}
			if not complet.is_empty(): entrant.lettre_poste = Notation.lettre_poste(_app().get("model"), complet, int(dernier.get("slot", 0)) + 1, true)
	MenuJoueur.carte_changement(zone, sortant, entrant)

## Vues de la colonne Mon XV : « tableau » (Mon XV et le banc) ou « adverse » (le XV adverse).
func choisir_vue_xv(vue: String) -> void:
	vue_xv = "adverse" if vue == "adverse" else "tableau"
	_montrer_vue_xv()
	if not _xv_donnees.is_empty(): _remplir_xv(_xv_donnees[0], _xv_donnees[1])
	_appliquer_blocage()

func _montrer_vue_xv() -> void:
	if not is_instance_valid(titre_xv): return
	titre_xv.text = ("XV adverse" if vue_xv == "adverse" else "Mon XV").to_upper()
	lien_adverse.text = "← Mon XV" if vue_xv == "adverse" else "XV adverse →"
	# Le tri ne range que Mon XV : grisé (et dit) sur le XV adverse.
	for bouton: Button in entetes_tri:
		bouton.disabled = vue_xv == "adverse"
		if not bouton.has_meta("aide"): bouton.set_meta("aide", bouton.tooltip_text)
		bouton.tooltip_text = "Le tri range Mon XV." if vue_xv == "adverse" else str(bouton.get_meta("aide"))
	if is_instance_valid(zone_banc): zone_banc.visible = vue_xv != "adverse"
	if is_instance_valid(legende_notes): legende_notes.visible = vue_xv != "adverse"

## Joueur d'une pastille du terrain (« camp:poste ») : {nous, poste, id, nom, poste_nom} ; {} s'il est inconnu.
func joueur_de_pastille(cle: String) -> Dictionary:
	if cle.is_empty(): return {}
	var cote := int(cle.get_slice(":", 0))
	var poste := int(cle.get_slice(":", 1))
	var camp := int(_dernier[2].get("camp", -1)) if _dernier.size() > 2 and _dernier[2] is Dictionary else -1
	var nous := cote == (camp if camp in [0, 1] else 0)
	if nous:
		var lineup: Array = _xv_donnees[0] if not _xv_donnees.is_empty() else []
		if poste < lineup.size() and lineup[poste] is Dictionary:
			return {"nous": true, "poste": poste, "id": str(lineup[poste].get("id", "")), "nom": str(lineup[poste].get("name", "")), "poste_nom": str(lineup[poste].get("pos", ""))}
	else:
		var adverse: Array = _dernier[2].get("adversaire", []) if _dernier.size() > 2 and _dernier[2].get("adversaire") is Array else []
		if poste < adverse.size() and adverse[poste] is Dictionary:
			return {"nous": false, "poste": poste, "id": "", "nom": str(adverse[poste].get("nom", "")), "poste_nom": str(adverse[poste].get("poste", ""))}
	return {}

func _survol_pastille(cle: String) -> void:
	var app: Object = _app()
	if is_instance_valid(_ancre_pastille) and app is Control: MiniFiche.cacher(app, _ancre_pastille)
	var j := joueur_de_pastille(cle)
	terrain.tooltip_text = "" if j.is_empty() or j.nous else "%d · %s · %s" % [int(j.poste) + 1, str(j.poste_nom), str(j.nom)]
	if j.is_empty() or not j.nous or not app is Control or not terrain.centres_dessin.has(cle): return
	if not is_instance_valid(_ancre_pastille):
		_ancre_pastille = Control.new()
		_ancre_pastille.name = "MatchBetweenPitchAnchor"
		_ancre_pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		terrain.add_child(_ancre_pastille)
	var r := terrain.rayon_dessin
	_ancre_pastille.position = (terrain.centres_dessin[cle] as Vector2) - Vector2(r, r)
	_ancre_pastille.size = Vector2(r, r) * 2.0
	MiniFiche.montrer(app, str(j.id), "squad", _ancre_pastille)

## Clic sur une pastille d'un de nos joueurs : sa fiche complète (règle de Léo sur les noms ; « ← Retour au direct »
## la referme), sa ligne de Mon XV gardant le focus derrière (Entrée ouvre Équipe sur lui). Pour un adversaire (pas
## de fiche), le tableau passe au XV adverse.
func _choix_pastille(cle: String) -> void:
	var j := joueur_de_pastille(cle)
	if j.is_empty(): return
	if not j.nous:
		if vue_xv != "adverse": choisir_vue_xv("adverse")
		return
	if vue_xv != "tableau": choisir_vue_xv("tableau")
	selectionner_joueur(int(j.poste))
	ouvrir_fiche(str(j.id))

## Met le focus sur la ligne du poste dans Mon XV et la fait défiler dans la vue.
func selectionner_joueur(poste: int) -> void:
	var ligne := xv.find_child("MatchBetweenPlayer%d" % (poste + 1), false, false) as Control
	if ligne == null: return
	ligne.grab_focus()
	var defile := find_child("MatchBetweenSquadScroll", true, false) as ScrollContainer
	if defile != null: defile.ensure_control_visible(ligne)

## Mon XV (maquette, colonne Plaquages empruntée à la variante 2) : numéro, nom, énergie (jauge et valeur),
## plaquages réussis, note du match ; une ligne sur deux zébrée. La ligne (clic, ou ↑ ↓ puis Entrée) ouvre la
## fenêtre Équipe sur ce joueur ; le nom ouvre sa fiche (survol : mini-fiche). Alertes écrites (« épuisé »).
func _remplir_xv(joueurs: Array, direct: Dictionary) -> void:
	_xv_donnees = [joueurs, direct]
	_montrer_journee_direct()
	# Cartes de Mon XV mises à jour EN PLACE (vérificateur du 24/11 : recréées à chaque minute, survol perdu).
	if vue_xv != "adverse" and not joueurs.is_empty() and _maj_tuiles_xv(joueurs, direct): return
	S.clear(xv)
	# D : Mon XV en tuiles, trois par rangée ; le XV adverse reste un tableau.
	xv.columns = 5 if vue_xv == "adverse" else 15
	xv.add_theme_constant_override("h_separation", 0 if vue_xv == "adverse" else px(14))
	xv.add_theme_constant_override("v_separation", 0 if vue_xv == "adverse" else px(14))
	if is_instance_valid(pied_xv): S.clear(pied_xv)
	var infos := _infos_xv(joueurs, direct)
	_remplir_changement(infos)
	# Vue adverse : les alertes de Mon XV restent calculées pour Gabi.
	if vue_xv == "adverse":
		_alertes_seules(joueurs, direct)
		_remplir_xv_adverse(direct)
		return
	alertes_xv.clear()
	if joueurs.is_empty():
		var vide_xv := _texte("Composition indisponible.", 19, DOUX, true)
		vide_xv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xv.add_child(vide_xv)
		return
	var ordre := ordre_xv(joueurs, infos, tri_xv, tri_inverse)
	for rang_ligne in ordre.size():
		var poste: int = ordre[rang_ligne]
		var joueur: Variant = joueurs[poste]
		var info: Dictionary = infos[poste]
		if joueur is Dictionary:
			var tuile := _tuile_joueur(poste, joueur, info)
			if not str(info.alerte).is_empty(): alertes_xv.append({"poste": poste, "id": str(info.id), "nom": str(joueur.get("name", "")), "alerte": str(info.alerte), "condition": float(info.energie)})
			xv.add_child(tuile)
			continue
		var case := _ligne_joueur("MatchBetweenPlayer%d" % (poste + 1), rang_ligne, func(): joueur_choisi.emit(poste))
		var ligne: HBoxContainer = case.get_child(0)
		ligne.add_child(_cellule(str(poste + 1), int(COLONNES_XV[0][1]), DOUX, 19, true))
		if not joueur is Dictionary:
			ligne.add_child(_cellule("Poste vacant", 0, FAIBLE))
			case.tooltip_text = "%d · poste vacant" % (poste + 1)
			xv.add_child(case)
			continue
		var id := str(info.id)
		var condition: float = info.energie
		var alerte: String = info.alerte
		ligne.add_child(_nom_joueur(str(joueur.get("name", "")), id, alerte, Pilotage.etat_joueur(_pilotage, id)))
		var energie := S.G.h(px(6))
		energie.custom_minimum_size.x = px(int(COLONNES_XV[2][1]))
		energie.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var jauge := Jauge.new()
		jauge.valeur = condition
		jauge.vive = true
		jauge.densite = _densite
		jauge.custom_minimum_size = Vector2(px(80), px(20))
		jauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		S.G.fill(jauge)
		energie.add_child(jauge)
		var critique := condition < EPUISE
		var teinte_valeur: Color = Jauge.teinte_vive(condition)
		var valeur := _cellule(("! " if critique else "") + "%d %%" % roundi(condition), 74, teinte_valeur, 19, true)
		energie.add_child(valeur)
		ligne.add_child(energie)
		ligne.add_child(_cellule(str(int(info.get("plaquages", 0))), int(COLONNES_XV[3][1]), IVOIRE, 19, true))
		ligne.add_child(_cellule(("%.1f" % float(info.note)).replace(".", ","), int(COLONNES_XV[4][1]), _teinte_note(float(info.note)), 19, true))
		if not alerte.is_empty(): alertes_xv.append({"poste": poste, "id": id, "nom": str(joueur.get("name", "")), "alerte": alerte, "condition": condition})
		if alerte in ["épuisé", "blessé"]: _marquer_ligne(case)
		case.set_meta("player_id", id)
		case.tooltip_text = str(info.detail)
		xv.add_child(case)
	_ligne_equipe(direct.get("feuille", {}) if direct.get("feuille") is Dictionary else {}, int(direct.get("camp", -1)), joueurs.map(func(j: Variant) -> String: return str(j.get("id", "")) if j is Dictionary else ""))
	# Les tuiles gardent toujours leur hauteur (la zone ne défile pas) : jamais écrasées par le reste de la page.
	_tenir_xv.call_deferred()

## Mon XV en tuiles déjà posées pour les mêmes joueurs : chaque carte garde son nœud (survol, focus), seul son contenu
## change, et seulement quand ses chiffres changent ; le nom (lien survolable) reste tant qu'il ne change pas. Renvoie
## false s'il faut tout reposer (changement de joueur, poste vacant, autre vue).
func _maj_tuiles_xv(joueurs: Array, direct: Dictionary) -> bool:
	if xv.columns != 15 or xv.get_child_count() != joueurs.size(): return false
	var infos := _infos_xv(joueurs, direct)
	var cases := {}
	for poste in joueurs.size():
		var joueur: Variant = joueurs[poste]
		var case := xv.get_node_or_null("MatchBetweenPlayer%d" % (poste + 1)) as Button
		if not joueur is Dictionary or case == null or case.is_queued_for_deletion() or not case.has_meta("tuile_xv") or str(case.get_meta("player_id", "")) != str(infos[poste].id): return false
		cases[poste] = case
	if is_instance_valid(pied_xv): S.clear(pied_xv)
	_remplir_changement(infos)
	alertes_xv.clear()
	var ordre := ordre_xv(joueurs, infos, tri_xv, tri_inverse)
	for rang_ligne in ordre.size():
		var poste: int = ordre[rang_ligne]
		var joueur: Dictionary = joueurs[poste]
		var info: Dictionary = infos[poste]
		var case: Button = cases[poste]
		if not str(info.alerte).is_empty(): alertes_xv.append({"poste": poste, "id": str(info.id), "nom": str(joueur.get("name", "")), "alerte": str(info.alerte), "condition": float(info.energie)})
		xv.move_child(case, rang_ligne)
		var badge: Array = MenuJoueur.texte_badge(_live_courant(), str(info.id))
		var cle := JSON.stringify([joueur.get("name", ""), info, _numero(str(info.id), poste + 1), badge, moral_joueur(_pilotage, str(info.id)), _densite])
		if str(case.get_meta("cle_carte", "")) == cle: continue
		case.set_meta("cle_carte", cle)
		var grave := str(info.alerte) in ["épuisé", "blessé"]
		var fond := _case(Charte.VOILE_DORE if grave else RELIEF, Charte.RAYON_CARTE)
		fond.set_content_margin_all(0)
		case.add_theme_stylebox_override("normal", fond)
		case.add_theme_stylebox_override("disabled", fond)
		if grave: case.set_meta("signale", true)
		elif case.has_meta("signale"): case.remove_meta("signale")
		var ancien := case.get_node_or_null("MatchBetweenCardBody") as Control
		if ancien != null: ancien.name = "MatchBetweenCardBodyOld"
		var neuf := _remplir_carte_haute(case, poste, joueur, info)
		if ancien != null:
			# Le contenu neuf prend la place de l'ancien, morceau par morceau ; le nom (lien survolable) reste s'il est le même.
			var k := 0
			while neuf.get_child_count() > 0:
				var morceau := neuf.get_child(0)
				var vieux := ancien.get_child(k) if k < ancien.get_child_count() else null
				neuf.remove_child(morceau)
				if vieux != null and k == 1 and str(vieux.get_meta("nom_carte", "")) == str(morceau.get_meta("nom_carte", "-")):
					morceau.queue_free()
				else:
					if vieux != null:
						ancien.remove_child(vieux)
						vieux.queue_free()
					ancien.add_child(morceau)
					ancien.move_child(morceau, k)
				k += 1
			case.remove_child(neuf)
			neuf.queue_free()
			ancien.name = "MatchBetweenCardBody"
		var vieux_badge := case.find_child("MatchMenuJoueurAttenteBadge", false, false)
		if vieux_badge != null and str(case.get_meta("badge", "")) != str(badge[0]):
			case.remove_child(vieux_badge)
			vieux_badge.queue_free()
		case.set_meta("badge", str(badge[0]))
		if not str(badge[0]).is_empty(): MenuJoueur.badge_attente(case, str(badge[0]), str(badge[1]))
	_ligne_equipe(direct.get("feuille", {}) if direct.get("feuille") is Dictionary else {}, int(direct.get("camp", -1)), joueurs.map(func(j: Variant) -> String: return str(j.get("id", "")) if j is Dictionary else ""))
	_tenir_xv.call_deferred()
	return true

## Tri de Mon XV choisi par l'en-tête : la même colonne deux fois retourne le sens ; « N° » revient à l'ordre des postes.
func trier_xv(cle: String) -> void:
	if cle == "numero" and tri_xv.is_empty():
		tri_inverse = not tri_inverse
	elif cle == tri_xv: tri_inverse = not tri_inverse
	else:
		tri_xv = "" if cle == "numero" else cle
		tri_inverse = false
	_poser_entete_tri()
	if not _xv_donnees.is_empty(): _remplir_xv(_xv_donnees[0], _xv_donnees[1])
	_appliquer_blocage()

## Joueur du XV le plus en difficulté (blessé, sinon l'énergie la plus basse, les joueurs sanctionnés mis à
## part) s'il est blessé ou sous le seuil de fatigue : Gabi propose de le remplacer.
func _remplir_changement(infos: Array) -> void:
	var choisi := -1
	for poste in infos.size():
		var info: Dictionary = infos[poste]
		if info.get("vacant", false) or info.get("carton", false): continue
		if choisi < 0: choisi = poste
		else:
			var actuel: Dictionary = infos[choisi]
			if bool(info.blesse) != bool(actuel.blesse):
				if info.blesse: choisi = poste
			elif float(info.energie) < float(actuel.energie): choisi = poste
	var urgent := choisi >= 0 and (bool(infos[choisi].blesse) or float(infos[choisi].energie) < FATIGUE)
	changement_poste = choisi if urgent else -1

func _remplir_banc(live: Dictionary) -> void:
	if not is_instance_valid(banc): return
	var reserves: Array = live.get("reserves", []) if live.get("reserves") is Array else []
	var restants: Variant = live.get("remplacementsRestants", live.get("substitutionsLeft"))
	var cle := JSON.stringify([reserves.map(func(j: Variant): return [j.get("id"), j.get("name"), j.get("pos")] if j is Dictionary else null), restants, _densite, live.get("numeros")])
	if cle == _banc_cle: return
	_banc_cle = cle
	S.clear(banc)
	var nombre := "%d joueur%s" % [reserves.size(), "s" if reserves.size() > 1 else ""]
	precision_banc.text = nombre + ((" · %d changement%s possible%s" % [int(restants), "s" if int(restants) > 1 else "", "s" if int(restants) > 1 else ""]) if restants is int or restants is float else "")
	if reserves.is_empty():
		var vide_banc := _texte("Aucun remplaçant sur la feuille.", 18, DOUX, true)
		vide_banc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		banc.add_child(vide_banc)
		return
	for n in reserves.size():
		var joueur: Variant = reserves[n]
		if not joueur is Dictionary: continue
		var id_banc := str(joueur.get("id", ""))
		var case := _ligne_joueur("MatchBetweenBench%d" % (16 + n), floori(n / 2.0), func(): ouvrir_fiche(id_banc))
		case.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var ligne: HBoxContainer = case.get_child(0)
		case.custom_minimum_size.y = maxi(20, px(22))
		var numero := _numero(id_banc, 16 + n)
		ligne.add_child(_cellule(str(numero), 30, DOUX, 19, true))
		var visage := _visage(joueur, px(32), 0, clampf(float(joueur.get("condition", 100)), 0.0, 100.0))
		visage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(visage)
		ligne.add_child(_nom_joueur(str(joueur.get("name", "")), str(joueur.get("id", ""))))
		var poste := _cellule(poste_court(str(joueur.get("pos", ""))), 40, DOUX, 17)
		poste.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ligne.add_child(poste)
		case.tooltip_text = "%d · %s · %s\nClic : l'écran Équipe, pour le faire entrer." % [numero, str(joueur.get("pos", "")), str(joueur.get("name", ""))]
		case.set_meta("player_id", str(joueur.get("id", "")))
		banc.add_child(case)

## Ligne « Équipe » sous un XV : plaquages de toute l'équipe (feuille de statistiques), remplaçants sortis
## compris ; l'écart avec la somme des quinze lignes est le travail des joueurs déjà remplacés (infobulle).
func _ligne_equipe(feuille: Dictionary, camp: int, visibles: Array) -> void:
	var joueurs: Dictionary = feuille.get("joueurs", {}) if feuille.get("joueurs") is Dictionary else {}
	if joueurs.is_empty() or not camp in [0, 1]: return
	var total := {"plaquages": 0, "metres": 0, "essais": 0}
	var sortis := {"plaquages": 0, "metres": 0, "essais": 0}
	for id: String in joueurs:
		var f: Dictionary = joueurs[id]
		if int(f.get("camp", -1)) != camp: continue
		for cle: String in total:
			total[cle] += int(f.get(cle, 0))
			if not visibles.has(id): sortis[cle] += int(f.get(cle, 0))
	var ligne := S.G.h(px(8))
	ligne.custom_minimum_size.y = maxi(16, px(30))
	ligne.name = "MatchBetweenTeamTotal"
	ligne.tooltip_text = "Total de l'équipe, remplaçants sortis compris : %d plaquages, %d m, %d essai%s (%d plaquage%s, %d m, %d essai%s déjà aux joueurs remplacés)." % [total.plaquages, total.metres, total.essais, "s" if total.essais > 1 else "", sortis.plaquages, "s" if sortis.plaquages > 1 else "", sortis.metres, sortis.essais, "s" if sortis.essais > 1 else ""]
	ligne.mouse_filter = Control.MOUSE_FILTER_STOP
	# Total de l'équipe en pastilles chiffre + mot, sous les tuiles.
	var titre := _texte("ÉQUIPE", 16, DOUX, false, true)
	titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(titre)
	for morceau: Array in [[str(total.metres), "m"], [str(total.essais), "essai" + ("s" if total.essais > 1 else "")], [str(total.plaquages), "plaq."]]:
		var pastille := PanelContainer.new()
		var style := _case(RELIEF, Charte.RAYON_PILULE)
		style.content_margin_left = px(12)
		style.content_margin_right = px(12)
		style.content_margin_top = px(1)
		style.content_margin_bottom = px(1)
		pastille.add_theme_stylebox_override("panel", style)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dedans := S.G.h(px(5))
		dedans.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille.add_child(dedans)
		var chiffre := _texte(str(morceau[0]), 18, IVOIRE, false, true)
		chiffre.add_theme_font_override("font", TITRES_EXTRA)
		chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dedans.add_child(chiffre)
		var mot := _texte(str(morceau[1]), 16, DOUX, false, true)
		mot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dedans.add_child(mot)
		ligne.add_child(pastille)
	var marge := MarginContainer.new()
	marge.name = "MatchBetweenTeamTotalMargin"
	marge.mouse_filter = Control.MOUSE_FILTER_PASS
	marge.add_theme_constant_override("margin_left", px(6))
	marge.add_theme_constant_override("margin_right", px(6))
	marge.add_child(ligne)
	pied_xv.add_child(marge)
	_aligner_pied_xv.call_deferred()

## Le pied suit les marges des lignes (6 px) et la place de l'ascenseur quand il est visible : mêmes colonnes.
func _aligner_pied_xv() -> void:
	if not is_instance_valid(pied_xv) or not is_instance_valid(defile_xv): return
	var barre := defile_xv.get_v_scroll_bar()
	var droite := px(6) + (int(barre.size.x) if barre.visible else 0)
	for enfant: Node in pied_xv.get_children():
		if enfant is MarginContainer: (enfant as MarginContainer).add_theme_constant_override("margin_right", droite)

## XV adverse (`direct.adversaire`) : le même tableau ; notes bornées aux faits montrés. Les joueurs adverses
## ne sont pas à nous : leurs noms ne sont pas des liens (aucune fiche du club pour eux).
func _remplir_xv_adverse(direct: Dictionary) -> void:
	var liste: Array = direct.get("adversaire", []) if direct.get("adversaire") is Array else []
	var camp := int(direct.get("camp", -1))
	if liste.is_empty():
		var vide_xv := _texte("Composition adverse pas encore vue.", 19, DOUX, true)
		vide_xv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xv.add_child(vide_xv)
		return
	for poste in liste.size():
		var j: Variant = liste[poste]
		var ligne := S.G.h(px(8))
		ligne.name = "MatchBetweenOpponent%d" % (poste + 1)
		ligne.custom_minimum_size.y = maxi(18, px(32))
		ligne.mouse_filter = Control.MOUSE_FILTER_PASS
		ligne.add_child(_cellule(str(poste + 1), int(COLONNES_XV[0][1]), DOUX, 19, true))
		if not j is Dictionary:
			ligne.add_child(_cellule("Poste vacant", 0, FAIBLE))
			xv.add_child(ligne)
			continue
		var note := float(j.get("note", NOTE_DEPART))
		ligne.add_child(_cellule(str(j.get("nom", "")), 0, DOUX, 19))
		if j.get("energie") != null:
			var energie := S.G.h(px(6))
			energie.custom_minimum_size.x = px(int(COLONNES_XV[2][1]))
			energie.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var jauge := Jauge.new()
			jauge.valeur = float(j.energie)
			jauge.densite = _densite
			jauge.custom_minimum_size = Vector2(px(80), px(20))
			jauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			S.G.fill(jauge)
			energie.add_child(jauge)
			energie.add_child(_cellule("%d %%" % roundi(float(j.energie)), 74, IVOIRE, 19, true))
			ligne.add_child(energie)
		else: ligne.add_child(_cellule("—", int(COLONNES_XV[2][1]), FAIBLE, 19, true))
		ligne.add_child(_cellule(str(int(j.get("plaquages", 0))), int(COLONNES_XV[3][1]), IVOIRE, 19, true))
		ligne.add_child(_cellule(("%.1f" % note).replace(".", ","), int(COLONNES_XV[4][1]), _teinte_note(note), 19, true))
		ligne.tooltip_text = "%d · %s · %s\nNote %.1f (%d action%s montrée%s), %d m, %d essai%s" % [poste + 1, str(j.get("poste", "")), str(j.get("nom", "")), note, int(j.get("faits", 0)), "s" if int(j.get("faits", 0)) > 1 else "", "s" if int(j.get("faits", 0)) > 1 else "", int(j.get("metres", 0)), int(j.get("essais", 0)), "s" if int(j.get("essais", 0)) > 1 else ""]
		xv.add_child(ligne)
	var feuille: Dictionary = direct.get("feuille", {}) if direct.get("feuille") is Dictionary else {}
	_ligne_equipe(feuille, 1 - camp, liste.map(func(j: Variant) -> String: return str(j.get("joueur", "")) if j is Dictionary else ""))

## Alertes de Mon XV sans le tableau (onglet adverse ouvert) : Gabi les garde.
func _alertes_seules(joueurs: Array, direct: Dictionary) -> void:
	alertes_xv.clear()
	var cartons := {}
	for carton: Variant in direct.get("cartons", []):
		if carton is Dictionary: cartons[str(carton.get("id", ""))] = carton
	for poste in joueurs.size():
		var joueur: Variant = joueurs[poste]
		if not joueur is Dictionary: continue
		var id := str(joueur.get("id", ""))
		var condition := float(joueur.get("condition", 100))
		var alerte := ""
		if int(joueur.get("injury", 0)) > 0: alerte = "blessé"
		elif cartons.has(id): alerte = "carton jaune, retour %s′" % _minute(cartons[id].get("retour")) if cartons[id].get("retour") != null else "exclu"
		elif condition < EPUISE: alerte = "épuisé"
		elif condition < FATIGUE: alerte = "fatigué"
		if not alerte.is_empty(): alertes_xv.append({"poste": poste, "id": id, "nom": str(joueur.get("name", "")), "alerte": alerte, "condition": condition})
