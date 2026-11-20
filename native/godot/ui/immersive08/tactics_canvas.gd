extends RefCounted
## Écran Composition (route « Composition », chapitre Tactique) — choix de Léo du 19/11/2026 : variante 1 « Terrain au
## centre, candidats dessous » (design/ux/10-composition.md, direction-artistique/interface/revue-20261119) et l'encart
## « Première ligne formée » de la variante 3. En-tête (titre, affiche, Proposition du staff, Tireurs et lanceur,
## Valider la feuille), ligne de validité, onglets, puis terrain (tactics_terrain.gd), banc (tactics_banc.gd), impact
## (tactics_impact.gd) et candidats (tactics_candidats.gd). Jamais de petite fenêtre : les choix annexes sont des
## sous-pages (tactics_sous_pages.gd). L'interface n'écrit jamais l'état du jeu : commandes du moteur seulement.
## Exemple : page dédiée de la coque, `TacticsCanvas.build(app, canvas)`.
const FocusLater := preload("res://ui/focus_later.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Selection = preload("res://ui/immersive08/tactics_selection.gd")
const Terrain = preload("res://ui/immersive08/tactics_terrain.gd")
const Banc = preload("res://ui/immersive08/tactics_banc.gd")
const Impact = preload("res://ui/immersive08/tactics_impact.gd")
const Candidats = preload("res://ui/immersive08/tactics_candidats.gd")
const SousPages = preload("res://ui/immersive08/tactics_sous_pages.gd")
const Roles = preload("res://ui/immersive08/tactics_roles.gd")
const Cover = preload("res://ui/lineup_cover.gd")
const Espoir = preload("res://ui/espoir_appel.gd")
const PersonName = preload("res://ui/person_name.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
## Hauteur du gabarit (unités) ; largeur 2248 comme toutes les pages de la coque.
const HAUTEUR := 1305.0
const TERRAIN := Rect2(0, 246, 990, 693)
const BANC := Rect2(1012, 200, 624, 739)
const IMPACT := Rect2(1658, 200, 590, 739)
const CANDIDATS_Y := 955.0

## Page : Ctrl+Entrée valide la feuille depuis n'importe quel poste.
class PageComposition extends Control:
	func _input(event: InputEvent) -> void:
		var touche := event as InputEventKey
		if touche == null or not touche.pressed or touche.echo or not touche.ctrl_pressed: return
		if touche.keycode not in [KEY_ENTER, KEY_KP_ENTER] or not is_visible_in_tree(): return
		var bouton := find_child("TacticsValidate", true, false) as Button
		var vue := get_viewport()
		vue.set_input_as_handled()
		# Valider change d'écran (cette page quitte l'arbre) : différé pour finir le traitement de la touche d'abord.
		if bouton != null and not bouton.disabled: bouton.pressed.emit.call_deferred()

static func build(app: Control, canvas: Control = null) -> Control:
	var page := PageComposition.new()
	page.name = "ImmersiveTactics"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.custom_minimum_size = Vector2(2248, HAUTEUR) * C.density
	if canvas != null:
		canvas.add_child(page)
		canvas.custom_minimum_size.y = maxf(canvas.custom_minimum_size.y, HAUTEUR * C.density)
		D.place(page, Rect2(0, 0, 2248, HAUTEUR))
	app.selected_slot = clampi(int(app.selected_slot), 0, 22)
	# Première ouverture sous le budget de 250 ms (tests/godot-portraits-prechauffage.gd) : la feuille et l'effectif sont
	# indexés une fois pour toute la construction, et les fonds naissent sans rayon (charte §3) au lieu d'une passe sur
	# les ~1 500 nœuds de l'écran après coup. 171 ms → ~100 ms mesurés en local (61 joueurs).
	Selection.lecture_debut(app.model)
	C.rayon_nul = true
	var construite := _construire(app, page)
	C.rayon_nul = false
	Selection.lecture_fin()
	return construite

static func _construire(app: Control, page: Control) -> Control:
	var etat := Selection.state(app)
	var pris: Variant = etat.get("pris")
	if pris is Dictionary and Selection.payload(app, str(pris.get("player_id", "")), int(pris.get("source", -1))) == null: etat.erase("pris")
	var sous := SousPages.actuelle(app)
	if not sous.is_empty():
		SousPages.build(app, page, sous)
		Kit.angles_droits(page)
		return page
	var choisir_cb := func(slot: int): choisir(app, slot)
	var clavier_cb := func(event: InputEvent, slot: int, carte: Control): clavier(app, event, slot, carte)
	_entete(app, page)
	_onglets(app, page)
	var avis := Impact.avis(app)
	var bleus := _bleus_marques(app)
	var premiere := Selection.premiere_ligne(app.model)
	Kit.titre(page, 0, 226, "XV de départ", 24, 500)
	Kit.etiquette(page, TERRAIN.size.x, 224, "Note au poste /100 · Espace prendre / poser", 600, true)
	D.line(page, Vector2(0, 238), Vector2(TERRAIN.size.x, 238), Charte.FILET)
	Terrain.build(app, page, TERRAIN, choisir_cb, clavier_cb, avis, bleus)
	Banc.build(app, page, BANC, choisir_cb, clavier_cb, avis, bleus, premiere)
	Impact.build(app, page, IMPACT, _adversaire(app), choisir_cb)
	var alertes := _alertes(app)
	var bloc := Candidats.build(app, page, Rect2(0, CANDIDATS_Y, 2248, HAUTEUR - CANDIDATS_Y), premiere, choisir_cb, alertes.size() * 56.0)
	for i in alertes.size(): (alertes[i] as Callable).call(bloc, 52.0 + i * 56.0)
	_restore_focus.call_deferred(app)
	return page

## Affiche : « Domicile – Extérieur · Compétition, journée · date heure · stade · domicile ».
static func _affiche(app: Control) -> Array[String]:
	var match_ := P.next_fixture(app.model)
	if match_.is_empty(): return ["Aucun prochain match", ""]
	var equipes := G.club_name(match_.get("home", {})) + " – " + G.club_name(match_.get("away", {}))
	var reste: Array[String] = []
	if not str(match_.get("label", "")).is_empty(): reste.append(str(match_.label))
	var date := P.fixture_date(match_)
	if not date.is_empty(): reste.append(date)
	var stade := P.fixture_venue(match_, true, true)
	if not stade.is_empty(): reste.append(stade)
	var lieu: String = {"home":"domicile", "away":"extérieur", "neutral":"terrain neutre"}.get(P.fixture_location_kind(match_, app.model.get("club", {}).get("id")), "")
	if not lieu.is_empty(): reste.append(lieu)
	return [equipes, " · ".join(reste)]

static func _adversaire(app: Control) -> String:
	var match_ := P.next_fixture(app.model)
	if match_.is_empty(): return ""
	var club_id: Variant = app.model.get("club", {}).get("id")
	var autre: Dictionary = match_.get("away", {}) if match_.get("home", {}).get("id") == club_id else match_.get("home", {})
	return G.club_name(autre)

static func _entete(app: Control, page: Control) -> void:
	var titre := Kit.titre(page, 0, 40, "Composition", 38, 500)
	titre.name = "CompositionTitle"
	var largeur_titre := Charte.TITRE_GRAS_ITALIQUE.get_string_size("COMPOSITION", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(38))).x / C.density
	if P.is_derby(app.model): Kit.puce(page, Rect2(largeur_titre + 18, 14, 90, 26), "DERBY", Charte.PANNEAU_3, Charte.IVOIRE, "DerbyTag").tooltip_text = "Derby : une rivalité ancienne, plus de tension sur le terrain et dans les tribunes."
	var affiche := _affiche(app)
	var equipes := Kit.texte(page, 0, 72, affiche[0], Charte.IVOIRE, 0, 18)
	equipes.name = "TacticsFixture"
	if not affiche[1].is_empty():
		Kit.texte(page, Kit.largeur(affiche[0], 18) + 4, 72, " · " + affiche[1], Charte.IVOIRE_2, 1300 - Kit.largeur(affiche[0], 18), 18).name = "TacticsFixtureDetail"
	# Actions, de droite à gauche : touche Ctrl Entrée, Valider la feuille (seul bouton plein), liens.
	var droite := 2248.0
	droite -= Kit.touche(page, droite, 56, "Ctrl Entrée", true) + 14
	var selection: Dictionary = app.model.get("selection", {})
	var valider := Kit.bouton_ivoire(page, Rect2(droite - 250, 26, 250, 44), "Valider la feuille", func(): validate(app), "TacticsValidate")
	valider.disabled = not selection.get("valid", false) or not Selection.editable(app)
	valider.tooltip_text = "Valider la feuille et passer à la préparation · Ctrl+Entrée" if not valider.disabled else "Feuille à compléter : voir la ligne de validité"
	droite -= 250 + 30
	if not Roles.view(app.model).is_empty():
		var roles := Kit.lien(page, Rect2(droite, 30, 0, 38), "Tireurs et lanceur →", func(): SousPages.ouvrir(app, "roles"), "LineupRoles", 18, true)
		roles.tooltip_text = "Désigner le buteur, son remplaçant, le lanceur en touche et le joueur au pied d’occupation."
		droite -= roles.size.x / C.density + 22
	var auto := Kit.lien(page, Rect2(droite, 30, 0, 38), "Proposition du staff →", func(): app._command("auto_lineup"), "LineupAutomatic", 18, true)
	auto.disabled = not Selection.editable(app)
	auto.tooltip_text = "Appliquer la composition recommandée par le staff"
	_validite(app, page)
	D.line(page, Vector2(0, 122), Vector2(2248, 122), Charte.FILET)

## Ligne de validité (le moteur décide : selection.valid / errors) : ✓ ivoire, jamais de vert ; sinon la première raison
## et « Corriger → » ; premier avertissement de condition ; actions de feuille incomplète ; quota JIFF / EQP à droite.
static func _validite(app: Control, page: Control) -> void:
	var selection: Dictionary = app.model.get("selection", {})
	var valide := bool(selection.get("valid", false))
	var erreurs: Array = selection.get("errors", [])
	var curseur := {"x": 0.0}
	var ligne := 108.0
	var ajouter := func(texte: String, couleur: Color, gras: bool, id: String) -> Label:
		var label := Kit.texte(page, curseur.x, ligne, texte, couleur, Kit.largeur(texte, 18) + 6, 18)
		if gras: label.add_theme_font_override("font", Kit.texte_gras())
		if not id.is_empty(): label.name = id
		curseur.x += Kit.largeur(texte, 18) + (10 if gras else 6)
		return label
	var titulaires := 0
	var remplacants := 0
	for index in 23:
		if not Selection.occupant(app.model, index).is_empty():
			if index < 15: titulaires += 1
			else: remplacants += 1
	var premiere := Selection.premiere_ligne(app.model)
	if valide:
		ajouter.call("✓", Charte.IVOIRE, true, "")
		ajouter.call("Feuille valide", Charte.IVOIRE, true, "TacticsValidity")
		ajouter.call("· %d titulaires + %d remplaçants · première ligne %d/%d formés" % [titulaires, remplacants, mini(int(premiere.formes), int(premiere.cible)), int(premiere.cible)], Charte.IVOIRE_2, false, "TacticsValidityDetail")
	else:
		ajouter.call("!", Charte.D, true, "")
		ajouter.call("Feuille incomplète", Charte.IVOIRE, true, "TacticsValidity")
		if not erreurs.is_empty():
			var raison := str(erreurs[0])
			if raison.length() > 90: raison = raison.left(88) + "…"
			var label: Label = ajouter.call(": " + raison, Charte.IVOIRE_2, false, "TacticsLineupIssue")
			label.tooltip_text = "\n".join(erreurs)
			label.mouse_filter = Control.MOUSE_FILTER_PASS
			if erreurs.size() > 1: ajouter.call("(+%d)" % (erreurs.size() - 1), Charte.IVOIRE_2, false, "TacticsLineupIssueCount").tooltip_text = "\n".join(erreurs)
		var a_corriger := _place_a_corriger(app)
		if a_corriger >= 0:
			var corriger := Kit.lien(page, Rect2(curseur.x, ligne - 28, 0, 38), "Corriger →", func(): choisir(app, a_corriger), "TacticsCorriger")
			curseur.x += corriger.size.x / C.density + 12
		if not Espoir.offer(app.model).is_empty():
			var appel := Kit.lien(page, Rect2(curseur.x, ligne - 28, 0, 38), "Appeler un espoir →", func(): SousPages.ouvrir(app, "espoir"), "LineupCallEspoir")
			appel.tooltip_text = Espoir.vacancy_text(app.model)
			curseur.x += appel.size.x / C.density + 12
		elif P.reduced_bench_number(app.model) != 0:
			var a22 := Kit.lien(page, Rect2(curseur.x, ligne - 28, 0, 38), "Jour de match · feuille à 22 →", func(): app._navigate("Match"), "LineupOpenMatchAt22")
			a22.tooltip_text = P.reduced_bench_vacancy(P.reduced_bench_number(app.model))
			curseur.x += a22.size.x / C.density + 12
		var devis := Cover.data(app)
		if not devis.is_empty():
			var renforts := Kit.lien(page, Rect2(curseur.x, ligne - 28, 0, 38), Cover.caption(devis) + " →", func(): SousPages.ouvrir(app, "renforts"), "LineupCover")
			Cover.configure(renforts, devis)
			curseur.x += renforts.size.x / C.density + 12
	# Avertissements non bloquants : joueurs de la feuille sous 80 % de condition.
	var bas: Array = []
	for index in 23:
		var person := Selection.occupant(app.model, index)
		var forme: Variant = person.get("condition")
		if (forme is int or forme is float) and float(forme) < 80: bas.append([index, person, roundi(float(forme))])
	if not bas.is_empty() and curseur.x < 1500:
		D.line(page, Vector2(curseur.x + 4, ligne - 18), Vector2(curseur.x + 5, ligne + 4), Charte.FILET)
		curseur.x += 16
		# Menu déroulant (exception autorisée) : chaque joueur sous 80 %, l'entrée montre les candidats de son poste.
		var avertissements := "! %d avertissement%s ▾" % [bas.size(), "s" if bas.size() > 1 else ""]
		var menu := MenuButton.new()
		menu.name = "TacticsWarnings"
		menu.text = avertissements
		menu.flat = true
		menu.add_theme_font_override("font", Kit.texte_gras())
		menu.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
		for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: menu.add_theme_color_override(couleur, Charte.D)
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 2)
		focus.set_border_width_all(2)
		menu.add_theme_stylebox_override("focus", focus)
		Impact._styler_menu(menu.get_popup())
		for i in bas.size():
			menu.get_popup().add_item("%s (n° %d) · %d %% de condition" % [Kit.casse(str(bas[i][1].get("name", ""))), int(bas[i][0]) + 1, int(bas[i][2])], i)
		menu.get_popup().id_pressed.connect(func(i: int): choisir(app, int(bas[i][0])))
		page.add_child(menu)
		var large := Kit.largeur(avertissements, 18) + 16
		D.place(menu, Rect2(curseur.x - 6, ligne - 28, large, 38))
		curseur.x += large + 4
		# Premier avertissement : le nom ouvre la fiche (survol = mini-fiche), « voir le poste » ses candidats.
		var premier: Array = bas[0]
		var nom_joueur := Kit.casse(str(premier[1].get("name", "")), true)
		Kit.nom(app, page, Rect2(curseur.x, ligne - 24, Kit.largeur(nom_joueur, 18) + 4, 32), nom_joueur, str(premier[1].get("id", "")), "TacticsWarningName", Charte.IVOIRE, 18)
		curseur.x += Kit.largeur(nom_joueur, 18) + 8
		ajouter.call("(n° %d) à %d %% de condition" % [int(premier[0]) + 1, int(premier[2])], Charte.IVOIRE_2, false, "TacticsWarningDetail")
		Kit.lien(page, Rect2(curseur.x - 6, ligne - 28, 0, 38), "voir le poste →", func(): choisir(app, int(premier[0])), "TacticsWarning")
	# Quota du championnat (JIFF / EQP), à droite de la ligne.
	var quota: Dictionary = app.model.get("clubLife", {}).get("jiff", {})
	if bool(quota.get("applies", false)):
		var compte := int(quota.get("currentSheet", 0)) + int(quota.get("doublon", 0))
		var cible := int(quota.get("target", 16))
		var alerte := bool(quota.get("alert", false))
		var texte := "%s%s %d / %d" % ["! " if alerte else "", str(quota.get("label", "JIFF")), compte, cible]
		var puce := Kit.texte(page, 2248, ligne, texte, Charte.D if alerte else Charte.IVOIRE_2, 300, 18, HORIZONTAL_ALIGNMENT_RIGHT)
		puce.name = "LineupJiffNotice"
		puce.tooltip_text = app.SquadViews.quota_line(quota) + "\n" + app.SquadViews.quota_tooltip(quota)
		puce.mouse_filter = Control.MOUSE_FILTER_PASS

## Première place à corriger : vide, sinon tenue par un joueur que le moteur n'y accepte plus ; -1 sinon.
static func _place_a_corriger(app: Control) -> int:
	for index in 23:
		if Selection.slot(app.model, index).get("playerId") == null: return index
	for index in 23:
		var id: Variant = Selection.slot(app.model, index).get("playerId")
		if id != null and str(id) not in Selection.slot(app.model, index).get("eligibleIds", []): return index
	return -1

## Onglets du chapitre Tactique et résumé du plan (« Modifier → » ouvre les consignes).
static func _onglets(app: Control, page: Control) -> void:
	var onglets := [[0, "Composition"], [1, "Consignes"], [2, "Phases arrêtées"], [4, "Entraînement"]]
	var x := 0.0
	for onglet: Array in onglets:
		var index: int = onglet[0]
		var largeur := C.DISPLAY.get_string_size(str(onglet[1]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(20))).x / C.density + 40
		_onglet(app, page, Rect2(x, 132, largeur, 44), str(onglet[1]), index)
		x += largeur + 6
	D.line(page, Vector2(0, 176), Vector2(2248, 176), Charte.FILET)
	var tactique: Dictionary = app.model.get("tactics", {})
	var plan := _libelle(tactique.get("attacks", []), tactique.get("attack"))
	var defense := _libelle(tactique.get("defenses", []), tactique.get("defense"))
	var modifier := Kit.lien(page, Rect2(2248, 136, 0, 38), "Modifier →", func(): app.Immersive.open_preparation(app, 1), "TacticsPlanModify", 18, true)
	modifier.tooltip_text = "Consignes d’attaque et de défense"
	var resume := "Plan : %s · Défense : %s" % [plan, defense]
	var label := Kit.texte(page, 2248 - modifier.size.x / C.density - 14, 162, resume, Charte.IVOIRE_2, 800, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	label.name = "TacticsPlanSummary"

static func _libelle(options: Variant, id: Variant) -> String:
	if options is Array:
		for option: Variant in options:
			if option is Dictionary and option.get("id") == id: return str(option.get("label", id))
	return str(id) if id != null else "—"

static func _onglet(app: Control, page: Control, zone: Rect2, texte: String, index: int) -> void:
	var choisi := index == 0
	var bouton := Button.new()
	bouton.name = "TacticsTab" + str(index)
	bouton.text = texte.to_upper()
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.add_theme_font_override("font", C.DISPLAY)
	bouton.add_theme_font_size_override("font_size", maxi(12, C.px(20)))
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		bouton.add_theme_color_override(etat, Charte.IVOIRE if choisi else Charte.IVOIRE_2)
	var fond := C.box(Charte.PANNEAU_3 if choisi else Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	if choisi:
		fond.border_color = Charte.IVOIRE
		fond.border_width_bottom = maxi(2, C.px(4))
	for etat in ["normal", "pressed", "hover_pressed"]: bouton.add_theme_stylebox_override(etat, fond)
	bouton.add_theme_stylebox_override("hover", fond if choisi else C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 0, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
	focus.set_border_width_all(2)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.pressed.connect(func(): _ouvrir_onglet(app, index))
	page.add_child(bouton)
	D.place(bouton, zone)

## Composition (onglet courant) : focus sur les candidats du poste choisi ; les autres onglets changent d'écran.
static func _ouvrir_onglet(app: Control, index: int) -> void:
	match index:
		1: app.Immersive.open_preparation(app, 1)
		2:
			app.management_ui.playbook_tab = 1
			app._navigate("Plan de jeu")
		4: app.Immersive.open_training(app)
		_: choisir(app, app.selected_slot)

## Bandeaux d'alerte posés en tête des candidats : protocole des Bleus (liste des 33) et qualification de Nationale.
## Rend des Callable(bloc, y) ; leur nombre fixe la place réservée.
static func _alertes(app: Control) -> Array:
	var alertes: Array = []
	var bleus: Dictionary = app.SquadViews.bleus_resume(app)
	if not bleus.is_empty():
		alertes.append(func(bloc: Control, y: float): _bandeau_bleus(app, bloc, y, bleus))
	var notice: Dictionary = app.model.get("selection", {}).get("nationaleQualification", {}).get("notice", {})
	if not notice.is_empty():
		alertes.append(func(bloc: Control, y: float): _bandeau_nationale(bloc, y, notice))
	return alertes

static func _bandeau(bloc: Control, y: float, id: String, couleur: Color) -> Panel:
	var bandeau := D.rect(bloc, Rect2(22, y + 4, 2204, 48), Charte.PANNEAU_2, 0)
	bandeau.name = id
	bandeau.mouse_filter = Control.MOUSE_FILTER_PASS
	Kit.marqueur(bandeau, Rect2(6, 8, 4, 32), couleur)
	return bandeau

static func _bandeau_bleus(app: Control, bloc: Control, y: float, bleus: Dictionary) -> void:
	var bandeau := _bandeau(bloc, y, "LineupBleusNotice", Charte.D)
	bandeau.tooltip_text = "Liste de 33 joueurs du XV de France : les clubs les laissent hors de la feuille au moins 2 fois sur 8 rencontres. Ligne directrice, ajustable par accord avec le staff des Bleus.\n\nRemplaçants proposés par le staff :\n" + "\n".join(bleus.lignes)
	var titre := D.text(bandeau, 22, 31, str(bleus.titre), 20, Charte.D, 700, 900)
	titre.name = "LineupBleusTitle"
	var echanges: Array = bleus.echanges
	var aide := "Au moins 2 repos sur 8 matchs de club ; l’aligner quand même coûte la confiance du staff des Bleus. "
	aide += ("Remplaçant proposé : " + str(bleus.lignes[0])) if echanges.size() == 1 else ("Remplaçants proposés pour %d postes (repère « 33 »)." % echanges.size() if echanges.size() > 1 else "Aucun remplaçant disponible au même poste.")
	Kit.texte(bandeau, 940, 31, aide, Charte.IVOIRE_2, 1000, 17).name = "LineupBleusChanges"
	if echanges.is_empty(): return
	var faire := Kit.lien(bandeau, Rect2(2190, 5, 0, 38), "Faire souffler →" if echanges.size() == 1 else "Faire souffler les %d →" % echanges.size(), func(): app._command("set_lineup", {"changes": bleus.lot}), "LineupBleusRestAll", 18, true)
	faire.tooltip_text = "\n".join(bleus.lignes)
	faire.disabled = not Selection.editable(app)

static func _bandeau_nationale(bloc: Control, y: float, notice: Dictionary) -> void:
	var alerte: bool = notice.get("tone") == "alert"
	var bandeau := _bandeau(bloc, y, "NationaleLicenceNotice", Charte.D if alerte else Charte.IVOIRE_2)
	bandeau.tooltip_text = str(notice.get("detail", ""))
	D.text(bandeau, 22, 31, str(notice.get("title", "")), 20, Charte.IVOIRE, 700, 700).name = "NationaleQualificationTitle"
	Kit.texte(bandeau, 740, 31, str(notice.get("summary", "")), Charte.D if alerte else Charte.IVOIRE, 1440, 18).name = "NationaleQualificationSummary"

static func _bleus_marques(app: Control) -> Dictionary:
	var marques := {}
	var bleus: Dictionary = app.SquadViews.bleus_resume(app)
	for e: Dictionary in bleus.get("echanges", []): marques[int(e.slot)] = true
	return marques

## Choisir une place (carte, ligne du banc, doublure, encart) : sa liste de candidats s'affiche dessous. Un second appui
## sur la place déjà choisie met le focus sur le premier candidat (clavier : Entrée puis ↑ ↓).
static func choisir(app: Control, index: int) -> void:
	var etat := Selection.state(app)
	if app.selected_slot == index and app.root_content.find_child("TacticsCandidateRows", true, false) != null:
		_focus_candidat(app)
		return
	app.selected_slot = index
	etat.message = ""
	etat.scroll = 0
	etat.focus = "LineupSlot%02d" % (index + 1)
	app._render()
	_restore_focus(app)

static func _focus_candidat(app: Control) -> void:
	var lignes: Node = app.root_content.find_child("TacticsCandidateRows", true, false)
	if lignes == null: return
	for ligne in lignes.get_children():
		if ligne is Button:
			FocusLater.grab(ligne)
			return

## Clavier sur une place (terrain ou banc) : Espace prend puis pose (échange), Échap annule, Suppr libère (confirmation),
## Maj+Entrée ouvre la fiche, I montre la mini-fiche. Alternative complète au glisser-déposer (K6).
static func clavier(app: Control, event: InputEvent, slot: int, carte: Control) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo or touche.alt_pressed or touche.meta_pressed or touche.ctrl_pressed: return
	var etat := Selection.state(app)
	var pris: Dictionary = etat.get("pris", {}) if etat.get("pris") is Dictionary else {}
	var person := Selection.occupant(app.model, slot)
	var id := str(person.get("id", ""))
	match touche.keycode:
		KEY_SPACE:
			if touche.shift_pressed: return
			carte.accept_event()
			if pris.is_empty():
				if person.is_empty():
					_annoncer(app, "Poste n° %d vide : rien à prendre." % (slot + 1), carte)
					return
				if Selection.payload(app, id, slot) == null:
					_annoncer(app, "La feuille ne se modifie pas maintenant.", carte)
					return
				etat.pris = {"player_id":id, "source":slot}
				_annoncer(app, "%s (n° %d) pris : flèches vers sa nouvelle place, puis Espace pour poser. Échap annule." % [str(person.get("name", "")), slot + 1], carte, true)
				return
			etat.erase("pris")
			if int(pris.get("source", -1)) == slot:
				_annoncer(app, "Déplacement annulé.", carte, true)
				return
			var payload: Variant = Selection.payload(app, str(pris.get("player_id", "")), int(pris.get("source", -1)))
			if Selection.can_drop(app, payload, slot):
				var nom := str(Selection.player(app.model, str(pris.get("player_id", ""))).get("name", ""))
				etat.message = "%s posé au n° %d." % [nom, slot + 1]
				Selection.apply(app, payload, slot)
			else:
				_annoncer(app, "Ce joueur ne peut pas tenir le n° %d : déplacement annulé." % (slot + 1), carte, true)
		KEY_ESCAPE:
			if pris.is_empty(): return
			carte.accept_event()
			etat.erase("pris")
			_annoncer(app, "Déplacement annulé.", carte, true)
		KEY_ENTER, KEY_KP_ENTER:
			if not touche.shift_pressed or person.is_empty(): return
			carte.accept_event()
			app.navigation_controller.open_entity({"kind":"player", "id":id})
		KEY_DELETE:
			if person.is_empty() or not Selection.editable(app): return
			carte.accept_event()
			Candidats.liberer(app, id, slot)
		KEY_I:
			if person.is_empty() or touche.shift_pressed: return
			carte.accept_event()
			if MiniFiche.visible_pour(app, carte): MiniFiche.cacher(app, carte)
			else: MiniFiche.montrer(app, id, "squad", carte)

## Message lisible sous les candidats ; `rendre` redessine l'écran (marques « pris » / destinations) et garde le focus.
static func _annoncer(app: Control, texte: String, carte: Control, rendre: bool = false) -> void:
	var etat := Selection.state(app)
	etat.message = texte
	etat.focus = str(carte.name)
	if rendre:
		app._render()
		_restore_focus(app)
	else:
		Candidats._message(app)

static func _restore_focus(app: Control) -> void:
	var focus_id := str(Selection.state(app).get("focus", ""))
	if focus_id.is_empty(): return
	var focus: Control = app.root_content.find_child(focus_id, true, false)
	if focus != null: FocusLater.grab(focus)

## « Valider la feuille » : feuille valide → préparation du match. Sinon rien n'est envoyé : la ligne de validité dit
## pourquoi et « Corriger → » prend le focus (aucune fenêtre).
static func validate(app: Control) -> void:
	if app.model.get("selection", {}).get("valid", false):
		app._navigate("Préparation")
		return
	var corriger := app.root_content.find_child("TacticsCorriger", true, false) as Control
	if corriger != null: FocusLater.grab(corriger)

## Charge individuelle d'un joueur, ouverte depuis la fiche joueur : sous-page de la fiche (fiche_charge.gd), plus une
## fenêtre (décision de Léo du 19/11/2026).
static func _individual(app:Control,player:Dictionary) -> void:
	load("res://ui/immersive08/fiche_charge.gd").ouvrir(app,player)