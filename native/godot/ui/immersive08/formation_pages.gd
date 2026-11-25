extends RefCounted
## Sous-pages de la Formation (décision de Léo du 19/11/2026 : jamais de petite fenêtre, un clic change d'écran) :
## « Suivi des jeunes » (objectifs et gains observés, ancienne fenêtre youth_development_view) et « Nouvelle génération du
## centre » (revue d'effectif : garder / libérer, ancienne fenêtre academy_intake_view). Chacune garde la coque, un retour
## « ← Retour à la formation » et une étape d'historique Précédent / Suivant (`management_ui.formation_page`).
## Le suivi des jeunes construit encore son contenu dans une fenêtre : elle est construite puis ADOPTÉE (masquée, son contenu
## passe dans la page), comme pour le Recrutement (recruitment_pages.gd). La revue d'effectif est dessinée ici.
## Exemple : `Pages.ouvrir(app, "suivi")`, `Pages.ouvrir(app, "suivi", {"player_id": id})`, `Pages.ouvrir(app, "revue")`.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const EnPlace = preload("res://ui/confirmation_en_place.gd")
const G = preload("res://ui/game_skin.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const HOTE := "FormationHote"
const PAGES := ["suivi", "revue", "pret"]
const TITRES := {"suivi":"Suivi des jeunes", "revue":"Nouvelle génération du centre", "pret":"Prêt d’un jeune professionnel"}
const LARGEUR := 1700.0
## Le suivi des jeunes (grille de trois tuiles, choix de Léo du 21/11/2026) prend toute la largeur de la page.
const LARGEUR_SUIVI := 2248.0

static func _largeur(kind: String) -> float:
	return LARGEUR_SUIVI if kind == "suivi" else LARGEUR

static func actuelle(app: Control) -> String:
	var etat_page: Variant = app.management_ui.get("formation_page")
	if not etat_page is Dictionary: return ""
	var page := str(etat_page.get("kind", ""))
	return page if page in PAGES else ""

static func etat(app: Control) -> Dictionary:
	var valeur: Variant = app.management_ui.get("formation_page")
	return valeur if valeur is Dictionary else {}

## Ouvre une sous-page : `args` = {player_id} pour le suivi.
static func ouvrir(app: Control, page: String, args: Dictionary = {}) -> void:
	if page not in PAGES: return
	_vider_hote(app)
	var contenu := {"kind": page}
	contenu.merge(args)
	app.management_ui.formation_page = contenu
	app.management_ui.erase("fiche_joueur")
	app._navigate("Formation", true, true)
	var cible := app.root_content.find_child("FormationRetour", true, false) as Control
	if cible != null: cible.grab_focus.call_deferred()

static func fermer(app: Control) -> void:
	_vider_hote(app)
	app.management_ui.erase("formation_page")
	app._navigate("Formation", true, true)

## Quitter la Formation (menu, historique) : la sous-page et sa fenêtre d'origine sont oubliées.
static func oublier(app: Control) -> void:
	_vider_hote(app)
	app.management_ui.erase("formation_page")

static func cle(app: Control) -> String:
	var page := actuelle(app)
	var joueur := str(etat(app).get("player_id", ""))
	return page if joueur.is_empty() else page + "|" + joueur

static func depuis_cle(valeur: String) -> Dictionary:
	var morceaux := valeur.split("|")
	var contenu := {"kind": morceaux[0]}
	if morceaux.size() > 1: contenu["player_id"] = morceaux[1]
	return contenu

static func _vider_hote(app: Control) -> void:
	var hote := app.get_node_or_null(HOTE)
	if hote == null: return
	var fenetre: Variant = hote.get_meta("fenetre", null)
	hote.name = HOTE + "Ferme"
	app.remove_child(hote)
	hote.queue_free()
	if is_instance_valid(fenetre) and fenetre is Window:
		fenetre.set_meta("en_page", false)
		fenetre.hide()
		fenetre.queue_free()

## Page entière : barre de retour, titre, contenu adopté ou dessiné ici.
static func build(app: Control, page: Control, kind: String) -> void:
	var lien_retour := Kit.lien(page, Rect2(0, 4, 0, 38), "← Retour à la formation", func(): fermer(app), "FormationRetour", 20)
	lien_retour.tooltip_text = ""
	Kit.touche(page, lien_retour.size.x / C.density + 10, 32, "Échap")
	var titre := Kit.titre_page(page, 0, 98, str(TITRES.get(kind, "")).to_upper(), 38, 1400)
	titre.name = "FormationSubpageTitle"
	D.line(page, Vector2(0, 122), Vector2(2248, 122), Charte.FILET)
	var cadre := D.rect(page, Rect2(0, 146, _largeur(kind), 1000), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	cadre.name = "FormationSubpage_" + kind
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	cadre.clip_contents = true
	if kind == "revue":
		_revue(app, cadre)
		return
	var hote := _hote(app, kind)
	if hote == null:
		D.text(cadre, 28, 60, "Cet écran n’est pas disponible pour le moment.", 22, Charte.IVOIRE_2, 600, 1200)
		return
	var fenetre := hote.get_meta("fenetre") as AcceptDialog
	var zone := Control.new()
	zone.name = "FormationAdopte"
	cadre.add_child(zone)
	D.place(zone, Rect2(24, 18, _largeur(kind) - 48, 940))
	for enfant: Variant in hote.get_meta("contenu", []):
		if not is_instance_valid(enfant): continue
		if enfant.get_parent() != null: enfant.get_parent().remove_child(enfant)
		zone.add_child(enfant)
		(enfant as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		(enfant as Control).theme = fenetre.theme
	var Recrutement: Script = load("res://ui/immersive08/recruitment_pages.gd")
	Recrutement._charte(zone)
	Recrutement._suivre_ajouts(zone)

static func _hote(app: Control, kind: String) -> Control:
	var hote := app.get_node_or_null(HOTE) as Control
	if hote != null and str(hote.get_meta("kind", "")) == kind and is_instance_valid(hote.get_meta("fenetre", null)): return hote
	if hote != null: _vider_hote(app)
	var etat_courant := etat(app)
	var joueur := str(etat_courant.get("player_id", ""))
	var fenetre: AcceptDialog = load("res://ui/academy_pathways_view.gd").open_professional(app, joueur) if kind == "pret" else load("res://ui/youth_development_view.gd").open(app, joueur, true)
	if fenetre == null: return null
	hote = Control.new()
	hote.name = HOTE
	hote.visible = false
	hote.set_meta("kind", kind)
	app.add_child(hote)
	hote.set_meta("fenetre", fenetre)
	fenetre.set_meta("en_page", true)
	var contenu: Array = []
	for enfant in fenetre.get_children():
		if enfant is Control:
			fenetre.remove_child(enfant)
			hote.add_child(enfant)
			contenu.append(enfant)
	hote.set_meta("contenu", contenu)
	fenetre.hide()
	# La fenêtre d'origine se ferme (OK, nettoyage des fenêtres) : la page se ferme avec elle.
	fenetre.tree_exiting.connect(func():
		if not is_instance_valid(app): return
		var courant := app.get_node_or_null(HOTE)
		if courant == null or courant.get_meta("fenetre", null) != fenetre: return
		_apres_fermeture.call_deferred(app, kind), CONNECT_ONE_SHOT)
	return hote

## Confirmation d'une décision prise dans une vue adoptée : EN PLACE dans la page (jamais une fenêtre) ; hors page (écran
## compact), la confirmation d'origine est conservée. Boutons « AdoptedConfirmationOk » et « AdoptedConfirmationAnnuler ».
static func confirmer(app: Control, titre: String, texte: String, au_ok: Callable) -> void:
	var zone := app.find_child("FormationAdopte", true, false) as Control if is_instance_valid(app) else null
	if zone == null or not zone.is_visible_in_tree():
		app.confirm(titre, texte, au_ok)
		return
	var bloc := EnPlace.ouvrir(app, zone, "AdoptedConfirmation", titre, [texte], "Confirmer", au_ok)
	D.place(bloc, Rect2(0, 0, 1100, 10))
	bloc.z_index = 20

static func _apres_fermeture(app: Variant, kind: String) -> void:
	if not is_instance_valid(app) or actuelle(app) != kind: return
	fermer(app)

# --- Revue d'effectif : nouvelle génération (garder / libérer) ---------------------------------------------------------

static func _revue(app: Control, cadre: Control) -> void:
	var donnees: Dictionary = app.model.get("clubLife", {}).get("academyIntake", {})
	var academie: Array = app.model.get("decisions", {}).get("development", {}).get("academy", [])
	if not donnees.get("available", false):
		D.text(cadre, 28, 60, "Aucune nouvelle génération à examiner pour le moment.", 22, Charte.IVOIRE_2, 600, 1400)
		return
	var garder := {}
	var liberer := {}
	var candidats: Array = donnees.get("players", [])
	var crabos_maintenant := int(donnees.get("crabos", 0))
	var plafond := int(donnees.get("crabosCap", 35))
	var capacite := int(donnees.get("capacity", 75))
	var texte_effectif := D.text(cadre, 28, 52, "", 20, Charte.IVOIRE, 700, 1500)
	texte_effectif.name = "AcademyIntakeCounter"
	D.text(cadre, 28, 84, "Garde ceux que tu veux former. Les autres quittent le centre. Sans décision avant la première journée, le responsable de la formation choisira pour toi.", 17, Charte.IVOIRE_2, 500, 1500)
	var envoi: Array = [Callable()]
	var valider: Button = Kit.bouton_ivoire(cadre, Rect2(28, 112, 420, 46), "Valider le choix", func(): envoi[0].call(), "AcademyIntakeValider")
	var info_blocage := D.text(cadre, 470, 142, "", 17, Charte.D, 600, 1000)
	var defilement := ScrollContainer.new()
	defilement.name = "AcademyIntakeScroll"
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defilement.follow_focus = true
	cadre.add_child(defilement)
	D.place(defilement, Rect2(24, 176, LARGEUR - 48, 790))
	var liste := C.v(4)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.add_child(liste)
	var rafraichir := func():
		var crabos_liberes := 0
		for joueur: Dictionary in academie:
			if liberer.has(str(joueur.id)) and int(joueur.age) <= 17: crabos_liberes += 1
		var total_crabos := crabos_maintenant - crabos_liberes + garder.size()
		var tous := int(donnees.get("academy", 0)) - liberer.size() + garder.size()
		var plein := total_crabos > plafond or tous > capacite
		texte_effectif.text = "Crabos après ton choix : %d / %d · centre : %d / %d" % [total_crabos, plafond, tous, capacite]
		info_blocage.text = "Fais de la place avant de valider." if plein else ""
		valider.disabled = plein or app.waiting
	var ligne_titre := func(texte: String, aide: String):
		var titre := C.label(texte.to_upper(), 24, Charte.IVOIRE, true, 700)
		titre.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
		liste.add_child(titre)
		var note := C.wrap(aide, 17, Charte.IVOIRE_2)
		liste.add_child(note)
	ligne_titre.call("Les candidats", "Garde ceux que tu veux former.")
	for joueur: Dictionary in candidats:
		var case_ := CheckBox.new()
		case_.name = "Keep_" + str(joueur.id).replace("-", "_")
		case_.text = _ligne(joueur)
		case_.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		Kit.styler_case(case_)
		case_.toggled.connect(func(actif: bool):
			if actif: garder[str(joueur.id)] = true
			else: garder.erase(str(joueur.id))
			rafraichir.call())
		liste.add_child(case_)
	ligne_titre.call("Faire de la place", "Les jeunes libérés quittent définitivement le centre. Un nom ouvre sa fiche.")
	for joueur: Dictionary in academie:
		var rang := C.h(10)
		liste.add_child(rang)
		var case_ := CheckBox.new()
		case_.name = "Release_" + str(joueur.id).replace("-", "_")
		case_.text = ("Crabos · " if int(joueur.age) <= 17 else "Espoirs · ") + _ligne(joueur)
		case_.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		case_.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Kit.styler_case(case_)
		case_.toggled.connect(func(actif: bool):
			if actif: liberer[str(joueur.id)] = true
			else: liberer.erase(str(joueur.id))
			rafraichir.call())
		rang.add_child(case_)
		var fiche := Button.new()
		fiche.name = "IntakeSheet_" + str(joueur.id).validate_node_name()
		fiche.text = "Fiche →"
		fiche.focus_mode = Control.FOCUS_ALL
		fiche.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		C.style_bouton_lien(fiche, 18)
		var cible := {"kind":"academy", "id":str(joueur.id)}
		fiche.pressed.connect(func(): app.navigation_controller.open_entity(cible))
		rang.add_child(fiche)
		MiniFiche.lier(app, fiche, str(joueur.id), "academy")
	rafraichir.call()
	envoi[0] = (func():
		if valider.disabled: return
		var lignes: Array = [{"id":"AcademyIntakeResume", "text":"Tu gardes %d jeune(s) et tu en libères %d." % [garder.size(), liberer.size()]}]
		if not liberer.is_empty(): lignes.append({"id":"AcademyIntakeIrreversible", "text":"Les jeunes libérés quittent définitivement le centre : ce n’est pas réversible."})
		var envoyer := func(): app._command("academy_intake_confirm", {"context": donnees.get("context"), "confirmed": true, "keep": garder.keys(), "release": liberer.keys()})
		var bloc := EnPlace.ouvrir(app, cadre, "AcademyIntakeConfirm", "Libérer et valider" if not liberer.is_empty() else "Valider le choix", lignes, "Libérer et valider" if not liberer.is_empty() else "Confirmer", envoyer)
		D.place(bloc, Rect2(470, 112, 900, 10)))

static func _ligne(p: Dictionary) -> String:
	# Notation façon FM : lettres du staff, jamais les chiffres du moteur.
	var niveau := "niveau %s" % G.rating_text(p, true)
	var plafond_potentiel := " · potentiel %s" % G.potential_text(p)
	var prodige := " · prodige" if p.get("prodigy", false) else ""
	return "%s · %s · %d ans · %s%s%s" % [p.name, p.pos, int(p.age), niveau, plafond_potentiel, prodige]

