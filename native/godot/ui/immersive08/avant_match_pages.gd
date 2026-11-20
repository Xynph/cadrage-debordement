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
	style.set_corner_radius_all(0)
	for side in ["left", "right"]: style.set("content_margin_" + side, ecran.M(28))
	style.content_margin_top = ecran.M(22)
	style.content_margin_bottom = ecran.M(24)
	cadre.add_theme_stylebox_override("panel", style)
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
	C.style_bouton_ivoire_plein(ok, roundi(20 / .75))
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

static func _delegation(ecran, app: Control, model: Dictionary, corps: VBoxContainer) -> void:
	_titre(ecran, corps, "Déléguer le match")
	var vacant := P.reduced_bench_number(model)
	var incomplete := vacant != 0 or not Espoir.offer(model).is_empty()
	corps.add_child(_paragraphe(ecran, "L'adjoint joue la rencontre à ta place, du coup d'envoi au coup de sifflet final. Tu retrouveras le résultat, le récit et les notes du match. Tu ne pourras pas le rejouer.", 16))
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
	corps.add_child(_paragraphe(ecran, Espoir.vacancy_text(model), 16, Charte.N))
	var choix := Espoir.add_choices(corps, model, true)
	var a22 := P.reduced_bench_number(model) != 0
	var note := "Comme en vrai, le jeune est prêté à l'équipe première pour ce match seulement : pas de contrat professionnel, il retourne au centre ensuite et gagne de l'expérience."
	if a22: note += "\nÀ 22, tu commences avec 15 titulaires et 7 remplaçants ; si la première ligne ne peut plus être complétée, les mêlées deviennent non disputées."
	corps.add_child(_paragraphe(ecran, note, 14, Charte.IVOIRE_2))
	_actions(ecran, corps, "COUP D'ENVOI", "FeuilleIncompleteConfirm", "FeuilleIncompleteCancel", func():
		if app.waiting or not choix.is_valid(): return
		var payload: Dictionary = choix.call().payload
		app.management_ui["avant_page"] = ""
		if app.route == "Match" and app.model.get("next") == fixture: app._command("begin_match", payload))
