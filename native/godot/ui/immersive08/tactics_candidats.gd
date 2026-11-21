extends RefCounted
## Candidats pour le poste choisi (maquette 10-composition-1, sous le terrain) : tout l'effectif dans un tableau dense
## trié par note au poste (barème coloré de la charte, chiffre toujours écrit, « — » si inconnue), condition (repère
## 80 %), statut en mots et action (Choisir, Échanger, Libérer). Les joueurs non qualifiés ou indisponibles restent
## visibles en bas, grisés, avec leur raison. Filtre « Hors feuille seulement », recherche par nom, tri par en-tête.
## Emprunt de la variante 3 : sur les n° 1-3 et 16-18, l'encart « Première ligne formée » (loi 3) se place à droite.
## Toute affectation passe par la commande du moteur `set_lineup` (tactics_selection.gd), jamais par l'interface.
## Exemple : `Candidats.build(app, page, Rect2(0, 914, 2248, 386), premiere_ligne, choisir)`.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Selection = preload("res://ui/immersive08/tactics_selection.gd")
const Commune = preload("res://ui/immersive08/fiche_commune.gd")
const PersonName = preload("res://ui/person_name.gd")
const P = preload("res://ui/immersive08/projection.gd")
const LIGNE := 33.0
const ENCART := 720.0

static func lecture(app: Control) -> Dictionary:
	if not app.management_ui.get("candidates_reading") is Dictionary:
		app.management_ui.candidates_reading = {"key":"note", "descending":true, "hors_feuille":false, "recherche":""}
	return app.management_ui.candidates_reading

static func build(app: Control, page: Control, zone: Rect2, premiere: Dictionary, choisir: Callable, avis_haut: float = 0.0) -> Panel:
	var bloc := D.rect(page, zone, Charte.PANNEAU, Charte.RAYON_PANNEAU)
	bloc.name = "TacticsCandidates"
	bloc.mouse_filter = Control.MOUSE_FILTER_PASS
	var slot: int = clampi(int(app.selected_slot), 0, 22)
	var poste := Selection.slot(app.model, slot)
	var numero := slot + 1
	var titre := "Candidats pour le poste n° %d · %s" % [numero, str(poste.get("label", ""))] if slot < 15 else "Candidats pour le n° %d · %s remplaçant" % [numero, str(poste.get("label", "")).to_lower()]
	Kit.titre(bloc, 22, 34, titre, 24, 1000).name = "TacticsCandidatesTitle"
	var etat := lecture(app)
	var w := zone.size.x
	# Filtre et recherche, à droite du titre.
	var recherche := LineEdit.new()
	recherche.name = "TacticsCandidateSearch"
	recherche.placeholder_text = "Nom…"
	recherche.text = str(etat.recherche)
	recherche.add_theme_font_override("font", Charte.TEXTE)
	recherche.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	recherche.add_theme_color_override("font_color", Charte.IVOIRE)
	recherche.add_theme_color_override("font_placeholder_color", Charte.IVOIRE_2)
	var champ := C.box(Charte.PANNEAU_3, Charte.IVOIRE_3, Charte.RAYON_PILULE, 8)
	recherche.add_theme_stylebox_override("normal", champ)
	var champ_focus := C.box(Charte.PANNEAU_3, Charte.IVOIRE, Charte.RAYON_PILULE, 8)
	champ_focus.set_border_width_all(2)
	recherche.add_theme_stylebox_override("focus", champ_focus)
	recherche.accessibility_name = "Rechercher un candidat par son nom"
	bloc.add_child(recherche)
	D.place(recherche, Rect2(w - 22 - 190, 10, 190, 34))
	var filtre := CheckBox.new()
	filtre.name = "TacticsCandidateOutsideOnly"
	# Petite fenêtre : libellé court, la case reste visible avec son état (carré plein si cochée).
	filtre.text = "Hors feuille" if C.dense() else "Hors feuille seulement"
	filtre.button_pressed = bool(etat.hors_feuille)
	filtre.accessibility_name = "Hors feuille seulement"
	Kit.styler_case(filtre)
	bloc.add_child(filtre)
	D.place(filtre, Rect2(w - 22 - 190 - 16 - 250, 10, 250, 34))
	var compte := Kit.etiquette(bloc, w - 22 - 190 - 16 - 250 - 16, 32, "", 520, true)
	compte.name = "TacticsCandidateCount"
	D.line(bloc, Vector2(22, 48), Vector2(w - 22, 48), Charte.FILET)
	var haut := 48.0 + avis_haut
	var encart := Selection.place_premiere_ligne(app.model, slot)
	var largeur_table := w - 44 - (ENCART + 24 if encart else 0.0)
	if encart: _encart(app, bloc, Rect2(w - 22 - ENCART, haut + 8, ENCART, zone.size.y - haut - 16), slot, premiere, choisir)
	var message := Kit.texte(bloc, 22, zone.size.y - 12, str(Selection.state(app).get("message", "")), Charte.IVOIRE_2, largeur_table)
	message.name = "TacticsCandidateMessage"
	var colonnes := _colonnes(largeur_table)
	var entete := Control.new()
	entete.name = "TacticsCandidateHeader"
	entete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(entete)
	D.place(entete, Rect2(22, haut + 4, largeur_table, 32))
	var defilement := ScrollContainer.new()
	defilement.name = "TacticsCandidateScroll"
	defilement.follow_focus = true
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bloc.add_child(defilement)
	var bas := zone.size.y - 30
	D.place(defilement, Rect2(22, haut + 38, largeur_table, bas - haut - 38))
	var lignes := Control.new()
	lignes.name = "TacticsCandidateRows"
	lignes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	defilement.add_child(lignes)
	var remplir := func(): _remplir(app, lignes, compte, slot, largeur_table, colonnes)
	_entete(app, entete, colonnes, remplir)
	recherche.text_changed.connect(func(texte: String):
		etat.recherche = texte
		remplir.call())
	filtre.toggled.connect(func(actif: bool):
		etat.hors_feuille = actif
		remplir.call())
	remplir.call()
	defilement.set_deferred("scroll_vertical", int(Selection.state(app).get("scroll", 0)))
	defilement.get_v_scroll_bar().value_changed.connect(func(valeur: float): Selection.state(app).scroll = int(valeur))
	return bloc

## Colonnes du tableau selon sa largeur : [clé, titre, x, largeur, alignement à droite].
static func _colonnes(largeur: float) -> Dictionary:
	var k := largeur / 2204.0
	return {"name":[8, 400 * k], "positions":[420 * k, 180 * k], "note":[600 * k, 210 * k], "condition":[850 * k, 230 * k],
		"status":[1110 * k, largeur - 1110 * k - 200 * k], "action":[largeur - 190 * k, 180 * k]}

static func _entete(app: Control, entete: Control, colonnes: Dictionary, remplir: Callable) -> void:
	var etat := lecture(app)
	var large := float(colonnes.note[1]) >= 180
	for colonne: Array in [["name", "Joueur"], ["positions", "Postes maîtrisés" if large else "Postes"], ["note", "Note au poste" if large else "Note"], ["condition", "Condition"], ["status", "Statut"]]:
		var cle: String = colonne[0]
		var place: Array = colonnes[cle]
		var droite := cle == "note"
		var fleche: String = (" ▼" if etat.descending else " ▲") if etat.key == cle else ""
		if cle == "status":
			Kit.etiquette(entete, place[0], 22, colonne[1], place[1])
			continue
		var tri := Kit.lien(entete, Rect2(float(place[0]) - 4, 0, float(place[1]) + 8, 30), str(colonne[1]).to_upper() + fleche, func():
			etat.descending = not etat.descending if etat.key == cle else cle in ["note", "condition"]
			etat.key = cle
			app._render()
			var cible: Control = app.root_content.find_child("CandidateSort_" + cle, true, false)
			if cible != null: cible.grab_focus.call_deferred(), "CandidateSort_" + cle, 16)
		tri.add_theme_font_override("font", C.DISPLAY)
		tri.add_theme_color_override("font_color", Charte.IVOIRE if etat.key == cle else Charte.IVOIRE_2)
		if droite: tri.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tri.tooltip_text = "Trier par " + str(colonne[1]).to_lower()
	D.line(entete, Vector2(0, 31), Vector2(entete.size.x / C.density, 31), Charte.FILET)

## Statut lisible d'un candidat pour la place choisie : {texte, couleur, eligible, action}.
static func statut(app: Control, person: Dictionary, slot: int) -> Dictionary:
	var id := str(person.get("id", ""))
	var source := Selection.source(app.model, id)
	var qualifie: bool = id in Selection.slot(app.model, slot).get("eligibleIds", [])
	var dispo := Commune.disponibilite(app, person, "squad")
	if source == slot:
		return {"texte":("Titulaire n° %d (actuel)" if slot < 15 else "Remplaçant n° %d (actuel)") % (slot + 1), "couleur":Charte.IVOIRE, "eligible":true, "action":"Libérer"}
	if dispo.etat in ["blesse", "suspendu"]:
		return {"texte":("✚ " if dispo.etat == "blesse" else "! ") + str(dispo.texte), "couleur":Charte.D, "eligible":false, "action":""}
	if not qualifie:
		var raison := "Non qualifié au poste" if dispo.etat in ["apte", "reprise"] else str(dispo.texte)
		return {"texte":raison, "couleur":Charte.IVOIRE_2, "eligible":false, "action":""}
	if source >= 0:
		return {"texte":("Titulaire n° %d · échanger" if source < 15 else "Remplaçant n° %d · échanger") % (source + 1), "couleur":Charte.IVOIRE, "eligible":true, "action":"Échanger →"}
	var texte := "Hors groupe"
	if dispo.etat in ["selection", "reprise"]: texte += " · " + str(dispo.texte).to_lower()
	return {"texte":texte, "couleur":Charte.IVOIRE, "eligible":true, "action":"Choisir →"}

static func _remplir(app: Control, lignes: Control, compte: Label, slot: int, largeur: float, colonnes: Dictionary) -> void:
	for enfant in lignes.get_children():
		lignes.remove_child(enfant)
		enfant.queue_free()
	var etat := lecture(app)
	var recherche := str(etat.recherche).strip_edges().to_lower()
	var qualifies: Array = []
	var autres: Array = []
	for person: Dictionary in app.model.get("squad", []):
		var id := str(person.get("id", ""))
		if bool(etat.hors_feuille) and Selection.source(app.model, id) >= 0 and Selection.source(app.model, id) != slot: continue
		if not recherche.is_empty() and not str(person.get("name", "")).to_lower().contains(recherche): continue
		var s := statut(app, person, slot)
		(qualifies if s.eligible else autres).append({"person":person, "statut":s})
	var cle := str(etat.key)
	var tri := func(a: Dictionary, b: Dictionary) -> bool:
		var va: Variant = _valeur(app, a.person, slot, cle)
		var vb: Variant = _valeur(app, b.person, slot, cle)
		if va == null and vb != null: return false
		if vb == null and va != null: return true
		if va != vb and va != null: return (va > vb) if etat.descending else (va < vb)
		return str(a.person.get("id", "")) < str(b.person.get("id", ""))
	qualifies.sort_custom(tri)
	autres.sort_custom(tri)
	var toutes: Array = qualifies + autres
	compte.text = ("%d candidat%s · %d plus bas" % [qualifies.size(), "s" if qualifies.size() > 1 else "", autres.size()] if C.dense() else "%d candidat%s · %d non qualifié%s plus bas" % [qualifies.size(), "s" if qualifies.size() > 1 else "", autres.size(), "s" if autres.size() > 1 else ""]).to_upper()
	lignes.custom_minimum_size = Vector2(C.px(largeur), C.px(maxf(LIGNE, toutes.size() * LIGNE)))
	if toutes.is_empty():
		Kit.texte(lignes, 8, 23, "Aucun joueur ne correspond.", Charte.IVOIRE_2, largeur - 16)
	for i in toutes.size():
		_ligne(app, lignes, i, toutes[i].person, toutes[i].statut, slot, largeur, colonnes)

static func _valeur(app: Control, person: Dictionary, slot: int, cle: String) -> Variant:
	match cle:
		"note": return Selection.rating(app.model, person, slot)
		"condition":
			var v: Variant = person.get("condition")
			return float(v) if v is int or v is float else null
		"positions": return Selection.positions(person)
	return str(person.get("name", ""))

static func _ligne(app: Control, parent: Control, rang: int, person: Dictionary, s: Dictionary, slot: int, largeur: float, colonnes: Dictionary) -> void:
	var id := str(person.get("id", ""))
	var source := Selection.source(app.model, id)
	var actuel := source == slot
	var bouton := Selection.PlayerButton.new()
	bouton.name = "TacticsCandidate_" + id.validate_node_name()
	bouton.set_meta("player_id", id)
	Kit.styler_ligne(bouton, Charte.PANNEAU_2 if rang % 2 == 1 else Charte.PANNEAU, actuel)
	parent.add_child(bouton)
	D.place(bouton, Rect2(0, rang * LIGNE, largeur, LIGNE))
	Selection.wire(bouton, app, id, source, -1, str(person.get("name", "")))
	if actuel: Kit.marqueur(bouton, Rect2(1, 5, 4, LIGNE - 10))
	var gris := not bool(s.eligible)
	var encre := Charte.IVOIRE_3 if gris else Charte.IVOIRE
	var portrait := G.portrait(int(person.get("portraitIndex", 0)), C.px(26), person)
	portrait.name = "TacticsPortrait_" + id.validate_node_name()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if gris: portrait.modulate = Color(1, 1, 1, .55)
	bouton.add_child(portrait)
	D.place(portrait, Rect2(colonnes.name[0], 3, 27, 27))
	Kit.nom(app, bouton, Rect2(colonnes.name[0] + 36, 3, colonnes.name[1] - 40, 27), str(person.get("name", "")), id, "TacticsCandidateName_" + id.validate_node_name(), encre)
	Kit.texte(bouton, colonnes.positions[0], 23, Selection.positions(person), Charte.IVOIRE_3 if gris else Charte.IVOIRE_2, colonnes.positions[1], 16)
	var note: Variant = Selection.rating(app.model, person, slot)
	var non_qualifie := str(s.texte) == "Non qualifié au poste"
	var chiffre := D.text(bouton, colonnes.note[0] + colonnes.note[1], 23, "—" if non_qualifie else Selection.rating_text(app.model, person, slot), 18, Charte.IVOIRE_3 if gris else Charte.couleur_attribut(note), 700, colonnes.note[1], HORIZONTAL_ALIGNMENT_RIGHT, true)
	chiffre.add_theme_font_override("font", Kit.texte_gras())
	chiffre.name = "TacticsCandidateRating"
	if gris:
		var v: Variant = person.get("condition")
		Kit.texte(bouton, colonnes.condition[0] + 140, 23, ("%d %%" % roundi(float(v))) if v is int or v is float else "—", Charte.IVOIRE_3, 74, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		Kit.condition(bouton, colonnes.condition[0], 23, person.get("condition"), 76)
	var texte := Kit.texte(bouton, colonnes.status[0], 23, str(s.texte), s.couleur, colonnes.status[1])
	texte.name = "TacticsCandidateStatus"
	if s.couleur == Charte.D: texte.add_theme_font_override("font", Kit.texte_gras())
	var action := str(s.action)
	if not action.is_empty() and Selection.editable(app):
		var quoi: Callable = (func(): liberer(app, id, slot)) if actuel else (func(): activer(app, id, slot))
		var lien := Kit.lien(bouton, Rect2(colonnes.action[0] + colonnes.action[1], 0, 0, LIGNE), action, quoi, "LineupRemove" if actuel else "TacticsCandidateAction_" + id.validate_node_name(), 18, true)
		lien.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lien.focus_mode = Control.FOCUS_NONE
		lien.mouse_filter = Control.MOUSE_FILTER_PASS
	bouton.accessibility_name = "%s · %s · note au poste %s · %s" % [str(person.get("name", "")), Selection.positions(person), Selection.rating_text(app.model, person, slot), str(s.texte)]
	bouton.pressed.connect(func(): activer(app, id, slot))

## Clic ou Entrée sur un candidat : affecte (ou échange) par la commande du moteur ; « Libérer » pour le joueur en place ;
## un candidat non qualifié n'est jamais affecté : sa raison s'écrit sous le tableau.
static func activer(app: Control, id: String, slot: int) -> void:
	var lecture_tactique := Selection.state(app)
	if not Selection.editable(app):
		lecture_tactique.message = "La feuille ne se modifie plus : match en cours ou commande en attente."
		_message(app)
		return
	var person := Selection.player(app.model, id)
	var s := statut(app, person, slot)
	if Selection.source(app.model, id) == slot:
		lecture_tactique.message = "%s tient déjà le n° %d : « Libérer » (ou Suppr sur sa carte) le retire de la feuille." % [str(person.get("name", "")), slot + 1]
		_message(app)
		return
	if not s.eligible:
		lecture_tactique.message = "%s ne peut pas tenir le n° %d : %s." % [str(person.get("name", "")), slot + 1, str(s.texte).to_lower().trim_prefix("✚ ").trim_prefix("! ")]
		_message(app)
		return
	lecture_tactique.message = "%s au n° %d." % [str(person.get("name", "")), slot + 1]
	lecture_tactique.focus = "LineupSlot%02d" % (slot + 1)
	Selection.apply(app, Selection.payload(app, id, Selection.source(app.model, id)), slot)

## « Libérer » (lien du titulaire, Suppr sur sa carte) : petite confirmation autorisée par Léo (19/11/2026), puis la
## commande set_lineup du moteur vide la place.
static func liberer(app: Control, id: String, slot: int) -> void:
	if not Selection.editable(app) or Selection.source(app.model, id) != slot: return
	var nom := str(Selection.player(app.model, id).get("name", ""))
	app.confirm("Libérer le n° %d ?" % (slot + 1), "%s quitte la feuille et rejoint le groupe ; le n° %d reste vide jusqu’à ton prochain choix." % [Kit.casse(nom), slot + 1], func():
		var lecture_tactique := Selection.state(app)
		lecture_tactique.message = "Poste n° %d libéré : %s rejoint le groupe." % [slot + 1, Kit.casse(nom)]
		lecture_tactique.focus = "LineupSlot%02d" % (slot + 1)
		app._command("set_lineup", {"playerId":null, "slot":slot}), true)
	for enfant in app.get_children():
		if enfant is ConfirmationDialog and enfant.visible:
			enfant.name = "LineupReleaseConfirm"
			enfant.get_ok_button().text = "LIBÉRER"

static func _message(app: Control) -> void:
	var label := app.root_content.find_child("TacticsCandidateMessage", true, false) as Label
	if label != null: label.text = str(Selection.state(app).get("message", ""))

## Encart « Première ligne formée » (emprunt de la variante 3) : la règle en une phrase, puis pilier gauche, talonneur,
## pilier droit avec le titulaire, le remplaçant désigné et le nombre de formés parmi eux.
static func _encart(app: Control, bloc: Control, zone: Rect2, slot: int, premiere: Dictionary, choisir: Callable) -> void:
	var cadre := D.rect(bloc, zone, Charte.PANNEAU, Charte.RAYON_CARTE)
	cadre.name = "TacticsFrontRowRule"
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	var cible := int(premiere.cible)
	var formes := int(premiere.formes)
	var regle := D.rect(cadre, Rect2(0, 0, zone.size.x, 64), Charte.PANNEAU_2, Charte.RAYON_PETIT)
	D.rect(regle, Rect2(0, 0, 4, 64), Charte.IVOIRE_2, 0)
	var poste_courant := {}
	for poste: Dictionary in premiere.postes:
		if int(poste.titulaire) == slot or int(poste.remplacant) == slot: poste_courant = poste
	var role := str(poste_courant.get("libelle", "première ligne")).to_lower()
	var phrase := "Loi 3 · %d formés requis · le n° %d reste %s formé" % [cible, slot + 1, role]
	if formes < cible: phrase = "Loi 3 · %d formés sur %d requis · feuille bloquée" % [formes, cible]
	var reduit := P.reduced_bench_number(app.model)
	var texte := Kit.texte(regle, 18, 26, phrase, Charte.IVOIRE, zone.size.x - 30, 17)
	texte.name = "TacticsFrontRowSentence"
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.max_lines_visible = 2
	texte.size.y = C.px(48)
	texte.position.y = C.px(8)
	var y := 96.0
	Kit.titre(cadre, 0, y, "Première ligne formée · %d/%d" % [mini(formes, cible), cible], 22, zone.size.x * .6).name = "TacticsFrontRowTitle"
	Kit.etiquette(cadre, zone.size.x, y - 2, "Loi 3 · feuille à 23" if reduit == 0 else "Loi 3 · feuille à 22 : cinq formés", 320, true)
	D.line(cadre, Vector2(0, y + 10), Vector2(zone.size.x, y + 10), Charte.FILET)
	var xs := [8.0, 168.0, 400.0, zone.size.x - 8]
	for i in 4:
		Kit.etiquette(cadre, xs[i], y + 36, ["Poste", "Titulaire", "Remplaçant", "Formés"][i], 200, i == 3)
	for i: int in (premiere.postes as Array).size():
		var poste: Dictionary = premiere.postes[i]
		var haut: float = y + 46 + i * LIGNE
		if i % 2 == 1: D.rect(cadre, Rect2(0, haut, zone.size.x, LIGNE), Charte.PANNEAU_2, 0)
		if int(poste.titulaire) == slot or int(poste.remplacant) == slot:
			Kit.marqueur(cadre, Rect2(1, haut + 5, 4, LIGNE - 10))
		Kit.texte(cadre, xs[0], haut + 23, str(poste.libelle), Charte.IVOIRE_2, 156, 16)
		for j in 2:
			var place: int = int(poste.titulaire) if j == 0 else int(poste.remplacant)
			var person := Selection.occupant(app.model, place)
			# Le numéro montre les candidats de la place ; le nom ouvre la fiche (survol = mini-fiche).
			var numero := Kit.lien(cadre, Rect2(xs[j + 1] - 6, haut, 0, LIGNE), "%d ·" % (place + 1), func(): choisir.call(place), "TacticsFrontRowSlot%02d" % (place + 1), 18)
			numero.accessibility_name = "Voir les candidats du n° %d" % (place + 1)
			var x_nom: float = xs[j + 1] - 6 + numero.size.x / C.density
			if person.is_empty():
				Kit.texte(cadre, x_nom, haut + 23, "place vide", Charte.IVOIRE_2, 160)
			else:
				var court := Kit.casse(str(person.get("name", "")), true)
				Kit.nom(app, cadre, Rect2(x_nom, haut + 3, Kit.largeur(court, 18) + 4, LIGNE - 6), court, str(person.get("id", "")), "TacticsFrontRowName%02d" % (place + 1), Charte.IVOIRE, 18)
		var ok := int(poste.formes) >= 2
		var marque := Kit.texte(cadre, xs[3], haut + 23, "%d %s" % [int(poste.formes), "✓" if ok else "!"], Charte.IVOIRE if ok else Charte.D, 90, 18, HORIZONTAL_ALIGNMENT_RIGHT)
		marque.add_theme_font_override("font", Kit.texte_gras())
		marque.name = "TacticsFrontRowCount%d" % int(poste.poste)
