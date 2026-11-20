extends RefCounted
## Sous-pages de la Composition (décision de Léo du 19/11/2026 : jamais de petite fenêtre, un clic change d'écran) :
## « Tireurs et lanceur », « Appeler un espoir », « Renforts d'urgence ». Chacune garde la coque, un retour
## « ← Retour à la composition » (Échap) et une étape d'historique Précédent / Suivant
## (`management_ui.composition_page`, voir navigation_controller.gd). Les choix passent par les commandes du moteur.
## Exemple : `SousPages.ouvrir(app, "roles")`.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Roles = preload("res://ui/immersive08/tactics_roles.gd")
const Espoir = preload("res://ui/espoir_appel.gd")
const Cover = preload("res://ui/lineup_cover.gd")
const PAGES := ["roles", "espoir", "renforts"]
const TITRES := {"roles":"Tireurs et lanceur", "espoir":"Appeler un espoir", "renforts":"Renforts d’urgence"}

## Sous-page demandée et encore pertinente (sinon "").
static func actuelle(app: Control) -> String:
	var page := str(app.management_ui.get("composition_page", ""))
	if page not in PAGES: return ""
	if page == "roles" and Roles.view(app.model).is_empty(): return ""
	if page == "espoir" and Espoir.offer(app.model).is_empty(): return ""
	if page == "renforts" and Cover.data(app).is_empty(): return ""
	return page

static func ouvrir(app: Control, page: String) -> void:
	app.management_ui.composition_page = page
	app._navigate("Composition", true, true)
	var cible := app.root_content.find_child("CompositionRetour", true, false) as Control
	if cible != null: cible.grab_focus.call_deferred()

static func fermer(app: Control) -> void:
	app.management_ui.erase("composition_page")
	app._navigate("Composition", true, true)

static func build(app: Control, page: Control, kind: String) -> void:
	var retour := Kit.lien(page, Rect2(0, 4, 0, 38), "← Retour à la composition", func(): fermer(app), "CompositionRetour", 20)
	retour.tooltip_text = "Retour à la composition · Échap"
	Kit.touche(page, retour.size.x / C.density + 10, 32, "Échap")
	var titre := Kit.titre(page, 0, 98, str(TITRES.get(kind, "")), 38, 1400)
	titre.name = "CompositionSubpageTitle"
	D.line(page, Vector2(0, 122), Vector2(2248, 122), Charte.FILET)
	var bloc := D.rect(page, Rect2(0, 146, 1500, 760), Charte.PANNEAU, 0)
	bloc.name = "CompositionSubpage_" + kind
	bloc.mouse_filter = Control.MOUSE_FILTER_PASS
	match kind:
		"roles": _roles(app, bloc)
		"espoir": _espoir(app, bloc)
		"renforts": _renforts(app, bloc)

static func _corps(bloc: Control) -> VBoxContainer:
	var corps := C.v(14)
	corps.name = "CompositionSubpageBody"
	bloc.add_child(corps)
	D.place(corps, Rect2(28, 24, 1444, 700))
	return corps

static func _paragraphe(corps: Control, texte: String, couleur: Color = Charte.IVOIRE, taille: int = 20) -> Label:
	var label := C.wrap(texte, taille, couleur)
	label.add_theme_font_override("font", Charte.TEXTE)
	corps.add_child(label)
	return label

## Tireurs et lanceur : une liste déroulante par rôle (choix du staff par défaut) ; chaque choix part au moteur.
static func _roles(app: Control, bloc: Control) -> void:
	var corps := _corps(bloc)
	var contenu := Roles.body(app.model, func(data: Dictionary): app._command("set_tactics", data))
	contenu.name = "TacticsRoles"
	corps.add_child(contenu)
	_charte(contenu)

## Appel d'un espoir du centre (feuille incomplète) : choix du jeune, puis la commande espoir_appeler.
static func _espoir(app: Control, bloc: Control) -> void:
	var corps := _corps(bloc)
	_paragraphe(corps, Espoir.vacancy_text(app.model), Charte.IVOIRE).name = "LineupEspoirVacancy"
	var choix := Espoir.add_choices(corps, app.model, false)
	_charte(corps)
	_paragraphe(corps, "Comme en vrai, le jeune est prêté à l’équipe première pour ce match seulement : pas de contrat professionnel, il retourne au centre ensuite et gagne de l’expérience.", Charte.IVOIRE_2, 18)
	var valider := Kit.bouton_ivoire(bloc, Rect2(28, 680, 300, 48), "Appeler le jeune", func():
		if app.waiting or not choix.is_valid(): return
		var entree: Dictionary = choix.call()
		if not entree.get("payload", {}).has("espoirs"): return
		app.management_ui.erase("composition_page")
		app._command("espoir_appeler", {"assignments": entree.payload.espoirs}), "LineupEspoirConfirm")
	valider.disabled = not choix.is_valid()
	Kit.lien(bloc, Rect2(360, 684, 0, 40), "Annuler", func(): fermer(app), "LineupEspoirCancel", 20)

## Renforts d'urgence : places, salaires ; « Signer les renforts » envoie promote_cover (confirmé).
static func _renforts(app: Control, bloc: Control) -> void:
	var quote := Cover.data(app)
	var corps := _corps(bloc)
	_paragraphe(corps, Cover.caption(quote), Charte.IVOIRE_2, 18).name = "LineupCoverCaption"
	_paragraphe(corps, Cover.detail(quote)).name = "LineupCoverDetail"
	var signer := Kit.bouton_ivoire(bloc, Rect2(28, 680, 320, 48), "Signer les renforts", func():
		if app.waiting: return
		app.management_ui.erase("composition_page")
		Cover.sign(app, quote), "LineupCoverConfirm")
	signer.disabled = int(quote.get("places", 0)) < (quote.get("slots", []) as Array).size()
	if signer.disabled: _paragraphe(corps, "Le groupe professionnel compte trop peu de places libres.", Charte.D, 18)
	Kit.lien(bloc, Rect2(380, 684, 0, 40), "Annuler", func(): fermer(app), "LineupCoverCancel", 20)

## Habille les contrôles génériques d'une sous-page aux jetons de la charte (pas de thème historique) : listes
## déroulantes, cases et boutons radio, textes en DM Sans.
static func _charte(racine: Node) -> void:
	for noeud in racine.find_children("*", "", true, false):
		if noeud is OptionButton: Kit.styler_liste(noeud)
		elif noeud is CheckBox: Kit.styler_case(noeud)
		elif noeud is Label:
			(noeud as Label).add_theme_font_override("font", Charte.TEXTE)