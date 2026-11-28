extends RefCounted
## Sous-pages de l'écran Avant-match (décision de Léo du 19/11/2026 : jamais de petite fenêtre, un clic change d'écran).
## « Déléguer le match » et « Feuille incomplète » (appel d'un espoir ou match à 22 au coup d'envoi) remplacent les anciennes
## fenêtres de confirmation : la page occupe la place des vérifications, sous le même bandeau ; « Retour à l'avant-match »,
## Échap et Alt+← la ferment (étape d'historique `management_ui.avant_page`).
## Délégation : une case « Confier aussi la composition au staff », cochée par défaut ; le choix est mémorisé dans la
## carrière (decisions.delegation.matchLineup). Commandes : begin_match { delegated: true, composition } puis delegate
## (chaînées par app.queued_action) ; begin_match { espoirs } ou { reducedBench } pour la feuille incomplète.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const Espoir = preload("res://ui/espoir_appel.gd")
const Delegation = preload("res://ui/delegation_dialog.gd")
const P = preload("res://ui/immersive08/projection.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")

## Page demandée (« delegation » ou « espoir »), prête à être ajoutée sous le bandeau.
static func construire(ecran, app: Control, model: Dictionary, page: String) -> Control:
	var zone := MarginContainer.new()
	zone.name = "MatchPage"
	C.fill(zone, true)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right"]: zone.add_theme_constant_override("margin_" + edge, ecran.M(32))
	zone.add_theme_constant_override("margin_top", ecran.M(24))
	zone.add_theme_constant_override("margin_bottom", ecran.M(8))
	var cadre := PanelContainer.new()
	cadre.name = "MatchDelegationPage" if page == "delegation" else "FeuilleIncompletePage"
	cadre.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cadre.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cadre.custom_minimum_size.x = ecran.M(780)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Charte.PANNEAU, .95)
	style.set_corner_radius_all(Charte.RAYON_PANNEAU)
	for side in ["left", "right"]: style.set("content_margin_" + side, ecran.M(28))
	style.content_margin_top = ecran.M(22)
	style.content_margin_bottom = ecran.M(24)
	cadre.add_theme_stylebox_override("panel", Charte.ombrer(style))
	zone.add_child(cadre)
	var corps := VBoxContainer.new()
	corps.name = "MatchDelegationBody" if page == "delegation" else "FeuilleIncompleteBody"
	corps.add_theme_constant_override("separation", ecran.M(12))
	cadre.add_child(corps)
	if page == "delegation": _delegation(ecran, app, model, corps)
	else: _espoir(ecran, app, model, corps)
	return zone

static func _titre(ecran, corps: VBoxContainer, texte: String) -> void:
	var titre: Label = ecran.italique(ecran.texte(texte.to_upper(), 34, Charte.IVOIRE, true, 700))
	titre.name = "MatchPageTitle"
	corps.add_child(titre)

static func _paragraphe(ecran, texte: String, taille: float = 15, couleur: Color = Charte.IVOIRE) -> Label:
	var label: Label = ecran.lignes(texte, taille, couleur, 6, false, 500)
	label.add_theme_font_override("font", C.BODY)
	return label

## Pied de page : action principale ivoire pleine (la seule de la page) et « Annuler » en lien.
static func _actions(ecran, corps: VBoxContainer, libelle: String, nom_confirmer: String, nom_annuler: String, confirmer: Callable) -> Button:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", ecran.M(22))
	corps.add_child(ligne)
	var ok := Button.new()
	ok.name = nom_confirmer
	ok.text = libelle
	ok.set_meta("immersive_style_applied", true)
	# Bouton secondaire (contour) : le Coup d'envoi du bandeau reste le seul aplat doré de l'écran (charte finale).
	C.style_bouton_contour(ok, roundi(20 / .75))
	ok.pressed.connect(confirmer)
	ligne.add_child(ok)
	var annuler := Button.new()
	annuler.name = nom_annuler
	annuler.text = "Annuler"
	annuler.set_meta("immersive_style_applied", true)
	C.style_bouton_lien(annuler, roundi(18 / .75))
	annuler.pressed.connect(ecran.fermer_page)
	ligne.add_child(annuler)
	# Action irréversible : le focus part sur « Annuler » (fiche UX 12 §6.5).
	annuler.grab_focus.call_deferred()
	return ok

## Pastille d'état : icône et un mot de la couleur du jeton (jamais la couleur seule), explication en infobulle.
static func _pastille(ecran, icone: String, mot: String, couleur: Color, aide: String) -> Control:
	var pastille := PanelContainer.new()
	pastille.name = "MatchPastille_" + icone
	pastille.tooltip_text = aide
	pastille.accessibility_name = aide
	pastille.mouse_default_cursor_shape = Control.CURSOR_HELP
	var style := Charte.style_pilule(Color(couleur, .15), Color.TRANSPARENT, ecran.M(12), ecran.M(5))
	pastille.add_theme_stylebox_override("panel", style)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", ecran.M(6))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := C.icon(icone, 22, couleur)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(image)
	var label: Label = ecran.texte(mot, 15, couleur, false, 700)
	label.add_theme_font_override("font", C.BODY)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(label)
	pastille.add_child(ligne)
	return pastille

static func _delegation(ecran, app: Control, model: Dictionary, corps: VBoxContainer) -> void:
	_titre(ecran, corps, "Déléguer le match")
	var vacant := P.reduced_bench_number(model)
	var incomplete := vacant != 0 or not Espoir.offer(model).is_empty()
	var pastilles := HBoxContainer.new()
	pastilles.name = "MatchDelegationPastilles"
	pastilles.add_theme_constant_override("separation", ecran.M(8))
	pastilles.add_child(_pastille(ecran, "people", "L'adjoint joue", Charte.MORAL, "L'adjoint joue la rencontre à ta place, du coup d'envoi au coup de sifflet final"))
	pastilles.add_child(_pastille(ecran, "rating", "Récit et notes", Charte.CONDITION, "Tu retrouveras le résultat, le récit et les notes du match"))
	pastilles.add_child(_pastille(ecran, "lock", "Non rejouable", Charte.INTENSIF, "Tu ne pourras pas rejouer ce match"))
	corps.add_child(pastilles)
	var choix: Array = [Callable()]
	var bouton_ok: Array = [null]
	var maj := func():
		var ch: Dictionary = choix[0].call() if choix[0].is_valid() else {}
		if is_instance_valid(bouton_ok[0]): bouton_ok[0].text = "DÉLÉGUER À 22" if ch.get("id") == "a22" else "DÉLÉGUER LE MATCH"
	if incomplete:
		var reduit := _paragraphe(ecran, Espoir.vacancy_text(model), 15, Charte.N)
		reduit.name = "MatchDelegationReduced"
		corps.add_child(reduit)
		choix[0] = Espoir.add_choices(corps, model, true, maj)
	var case_composition := CheckBox.new()
	case_composition.name = "MatchDelegationComposition"
	case_composition.text = "Confier aussi la composition au staff"
	case_composition.button_pressed = Delegation.composition_confiee(model)
	case_composition.tooltip_text = "Le staff refait la feuille du jour avec la sélection automatique avant le match : les joueurs fatigués sont remplacés, la règle JIFF reste respectée."
	case_composition.custom_minimum_size.y = ecran.M(30)
	case_composition.add_theme_font_override("font", C.BODY)
	case_composition.add_theme_font_size_override("font_size", maxi(12, ecran.M(16)))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: case_composition.add_theme_color_override(key, Charte.IVOIRE)
	# Case de la charte : fond sobre à coins arrondis (rayon 6), cerclée d'ivoire au focus clavier, jamais de fond rouge.
	for etat in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var fond_case := StyleBoxFlat.new()
		fond_case.bg_color = Color.TRANSPARENT if etat == "focus" else (Charte.PANNEAU_3 if etat.contains("pressed") or etat == "hover" else Charte.PANNEAU_2)
		fond_case.set_corner_radius_all(Charte.RAYON_PETIT)
		if etat == "focus":
			fond_case.border_color = Charte.IVOIRE
			fond_case.set_border_width_all(2)
		for bord in ["left", "right"]: fond_case.set("content_margin_" + bord, ecran.M(10))
		case_composition.add_theme_stylebox_override(etat, fond_case)
	corps.add_child(case_composition)
	var detail := _paragraphe(ecran, "", 14, Charte.IVOIRE_2)
	detail.name = "MatchDelegationDetail"
	corps.add_child(detail)
	var maj_detail := func(): detail.text = Delegation.detail_texte(model, case_composition.button_pressed)
	case_composition.toggled.connect(func(_v: bool): maj_detail.call())
	maj_detail.call()
	bouton_ok[0] = _actions(ecran, corps, "DÉLÉGUER LE MATCH", "MatchDelegationConfirm", "MatchDelegationCancel", func():
		var payload := {"delegated": true, "composition": case_composition.button_pressed}
		if choix[0].is_valid(): payload.merge(choix[0].call().payload)
		Delegation.valider(app, payload))
	maj.call()

static func _espoir(ecran, app: Control, model: Dictionary, corps: VBoxContainer) -> void:
	_titre(ecran, corps, "Feuille incomplète")
	var fixture: Variant = model.get("next")
	# Le titre dit déjà « Feuille incomplète » : le paragraphe commence directement par la place vide.
	var constat := Espoir.vacancy_text(model).trim_prefix("Feuille incomplète : ")
	if not constat.is_empty(): constat = constat.left(1).to_upper() + constat.substr(1)
	corps.add_child(_paragraphe(ecran, constat, 16, Charte.N))
	var choix := Espoir.add_choices(corps, model, true)
	_joueurs_proposes(ecran, app, corps, model)
	var a22 := P.reduced_bench_number(model) != 0
	var note := "Comme en vrai, le jeune est prêté à l'équipe première pour ce match seulement : pas de contrat professionnel, il retourne au centre ensuite et gagne de l'expérience."
	if a22: note += "\nÀ 22, tu commences avec 15 titulaires et 7 remplaçants ; si la première ligne ne peut plus être complétée, les mêlées deviennent non disputées."
	corps.add_child(_paragraphe(ecran, note, 14, Charte.IVOIRE_2))
	_actions(ecran, corps, "COUP D'ENVOI", "FeuilleIncompleteConfirm", "FeuilleIncompleteCancel", func():
		if app.waiting or not choix.is_valid(): return
		var payload: Dictionary = choix.call().payload
		app.management_ui["avant_page"] = ""
		if app.route == "Match" and app.model.get("next") == fixture: app._command("begin_match", payload))

## Les jeunes proposés sont des noms : clic = fiche complète (Formation), survol = mini-fiche.
static func _joueurs_proposes(ecran, app: Control, corps: VBoxContainer, model: Dictionary) -> void:
	var offre := Espoir.offer(model)
	if offre.is_empty(): return
	var ligne := HFlowContainer.new()
	ligne.name = "FeuilleJeunesProposes"
	ligne.add_theme_constant_override("h_separation", ecran.M(28))  # place du bouton (i) à droite de chaque nom
	var intro: Label = ecran.texte("Jeunes proposés :", 15, Charte.IVOIRE_2, false, 500)
	intro.add_theme_font_override("font", C.BODY)
	ligne.add_child(intro)
	var vus := {}
	for slot_offre: Dictionary in offre.slots:
		for candidat: Dictionary in slot_offre.get("candidates", []):
			var identifiant := str(candidat.get("id", ""))
			if identifiant.is_empty() or vus.has(identifiant): continue
			vus[identifiant] = true
			var lien: Button = ecran._bouton_lien(str(candidat.get("name", "Jeune")), func(): app.navigation_controller.open_entity({"kind": "academy", "id": identifiant}), "FeuilleJeune_" + identifiant.validate_node_name(), 15)
			MiniFiche.lier(app, lien, identifiant, "academy")
			ligne.add_child(lien)
	corps.add_child(ligne)
