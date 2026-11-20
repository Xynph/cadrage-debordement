extends Node
# Raccourcis clavier de la carrière (façon Football Manager). Un seul gestionnaire, installé par le décor
# immersif ; il ne touche ni au moteur ni aux commandes : il actionne les boutons que le manager voit.
#   Espace : Continuer (bouton visible et actif), et rien d'autre dans toute la coque      1 à 9 : menus de gauche, dans l'ordre affiché
#   Échap : referme la fiche ouverte (sinon le menu de la carrière, déjà géré)      Ctrl+F : accès rapide (Ctrl+K)
# Jamais actif : champ de saisie ayant le focus, fenêtre ou dialogue ouvert, réunion ou match en cours, intro.
# Les autres raccourcis (Ctrl+S, Ctrl+J, Ctrl+K, F1, Alt+←/→) restent dans navigation_controller.gd.
const NOM := "RaccourcisClavier"
const Reception = preload("res://ui/immersive08/reception_canvas.gd")
## Ancienne indication « prochain message » gardée pour la retirer des infobulles déjà écrites.
const INDICES := [" · Espace : continuer", " · Espace : prochain message"]
## Table unique des raccourcis : [touche, libellé court, explication, dans le pied de page]. Pied de page, paramètres et aide F1 la lisent.
const TABLE := [
	["Espace", "Continuer", "Continuer : passe à la suite du calendrier (ou ouvre ce qui l'arrête). Sur un bouton ciblé au clavier, Espace l'active lui-même.", true],
	["1 à 9", "Menus", "Ouvre l'écran du menu de gauche, dans l'ordre affiché.", true],
	["Échap", "Retour", "Referme la fiche ou la fenêtre au premier plan.", true],
	["Ctrl F", "Rechercher", "Cherche un joueur, un club ou un écran (Ctrl K aussi).", true],
	["F1", "Aide", "Les conseils de Gabi pour l'écran en cours.", true],
	["Ctrl S", "Sauvegarder", "Enregistre la carrière.", false],
	["Alt ← / →", "Historique", "Revient à l'écran précédent ou suivant.", false],
]
var app: Control
# Vrai après Tab ou une flèche : Espace appartient alors au bouton ciblé, pas à « Continuer ».
var _focus_clavier := false

## Pied de page : « Espace Continuer   ·   1 à 9 Menus … ».
static func pied_de_page() -> String:
	return "   ·   ".join(TABLE.filter(func(l: Array): return l[3]).map(func(l: Array): return "%s %s" % [l[0], l[1]]))

## Lignes de l'aide (F1) et de l'onglet « Raccourcis clavier » des paramètres (ui/preferences_dialog.gd) : « Espace : explication ».
static func lignes_aide() -> PackedStringArray:
	return PackedStringArray(TABLE.map(func(l: Array): return "%s : %s" % [l[0], l[2]]))

static func installer(owner_app: Control) -> void:
	var gestionnaire: Node = owner_app.get_node_or_null(NOM)
	if gestionnaire == null:
		gestionnaire = load("res://ui/raccourcis_clavier.gd").new()
		gestionnaire.name = NOM
		gestionnaire.app = owner_app
		owner_app.add_child(gestionnaire)
	gestionnaire.annoncer_continuer()

## Info-bulle « Espace : continuer », recalculée au survol et au focus (le texte est réécrit chaque jour).
func annoncer_continuer() -> void:
	var bouton: Button = app.primary_button if is_instance_valid(app) else null
	if not is_instance_valid(bouton): return
	for signal_bouton: Signal in [bouton.mouse_entered, bouton.focus_entered]:
		if not signal_bouton.is_connected(_ajouter_indice): signal_bouton.connect(_ajouter_indice.bind(bouton))

func _ajouter_indice(bouton: Button) -> void:
	if not is_instance_valid(bouton) or bouton.disabled: return
	var texte := bouton.tooltip_text
	for indice: String in INDICES: texte = texte.trim_suffix(indice)
	bouton.tooltip_text = texte + INDICES[0]

## Passe avant les contrôles uniquement quand Espace tombe sur « Continuer » lui-même, resté ciblé après un clic : il doit alors ouvrir le courrier non lu.
## Tout autre contrôle (bouton, liste, arbre, dialogue) reçoit Espace d'abord ; le gestionnaire ne voit la touche que par `_unhandled_key_input`.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed: _focus_clavier = false
	var touche := _touche(event)
	if touche == null: return
	# Fiche joueur : Maj+← / Maj+→ passent au joueur précédent / suivant de la liste d'origine (avant le focus des flèches).
	if touche.shift_pressed and not touche.ctrl_pressed and not touche.alt_pressed and not touche.meta_pressed and touche.keycode in [KEY_LEFT, KEY_RIGHT]:
		if _joueur_voisin(touche.keycode == KEY_RIGHT):
			get_viewport().set_input_as_handled()
			return
	if touche.keycode in [KEY_TAB, KEY_BACKTAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]: _focus_clavier = true
	if _focus_clavier or not _est_continuer(touche) or not is_instance_valid(app): return
	var focus := app.get_viewport().gui_get_focus_owner()
	if focus != null and focus == app.get("primary_button") and _continuer(): get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	var touche := _touche(event)
	if touche == null: return
	var utilise := false
	if _est_continuer(touche): utilise = _continuer()
	elif touche.keycode == KEY_ESCAPE: utilise = _retour()
	elif touche.keycode == KEY_F and touche.ctrl_pressed and not touche.alt_pressed: utilise = _recherche()
	elif not touche.ctrl_pressed and not touche.alt_pressed and not touche.meta_pressed:
		var rang := _rang_menu(touche)
		if rang >= 0: utilise = _menu(rang)
	if utilise: get_viewport().set_input_as_handled()

func _touche(event: InputEvent) -> InputEventKey:
	var touche := event as InputEventKey
	return touche if touche != null and touche.pressed and not touche.echo else null

func _est_continuer(event: InputEventKey) -> bool:
	return event.keycode in [KEY_SPACE] and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and not event.shift_pressed

## 0 à 8 pour les touches 1 à 9. `physical_keycode` couvre la rangée de chiffres d'un clavier AZERTY sans Maj.
func _rang_menu(event: InputEventKey) -> int:
	for code: int in [event.keycode, event.physical_keycode]:
		if code >= KEY_1 and code <= KEY_9: return code - KEY_1
		if code >= KEY_KP_1 and code <= KEY_KP_9: return code - KEY_KP_1
	return -1

## Aucun raccourci ne doit agir en dehors du bureau de la carrière.
func actif() -> bool:
	if not is_instance_valid(app) or app.closing or not app.has_method("_has_career") or not app._has_career(): return false
	if app.has_method("intro_active") and app.intro_active(): return false
	if app.route in ["Accueil", "Création", "Packs"] or not is_instance_valid(app.root_content): return false
	var directeur: Variant = app.get("contextual_director")
	if is_instance_valid(directeur) and (directeur.active_meeting() or directeur.match_immersed()): return false
	if is_instance_valid(app.get("continue_progress")) and app.continue_progress.running: return false
	if is_instance_valid(app.get("command_wait_overlay")) and app.command_wait_overlay.blocks_input(): return false
	var focus := app.get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or focus is SpinBox: return false
	return not _fenetre_ouverte(app)

func _fenetre_ouverte(noeud: Node) -> bool:
	for enfant in noeud.get_children():
		if enfant is Window and enfant.visible and not enfant.is_queued_for_deletion(): return true
		if _fenetre_ouverte(enfant): return true
	return false

## Coque commune (relecture UX du 19/11/2026) : Espace = Continuer partout, un seul sens. Le courrier non lu se lit
## par le bouton « Courrier suivant non lu » de la Réception ; Continuer s'arrête de lui-même sur ce qui compte.
func _continuer() -> bool:
	if not actif(): return false
	var bouton: Button = app.primary_button
	if not is_instance_valid(bouton) or bouton.disabled or not bouton.is_visible_in_tree(): return false
	# Un contrôle qui utilise Espace (bouton, liste, arbre) le garde pour lui.
	var focus := app.get_viewport().gui_get_focus_owner()
	if focus is ItemList or focus is Tree: return false
	if focus is BaseButton and focus != bouton: return false
	bouton.pressed.emit()
	return true

func _menu(rang: int) -> bool:
	if not actif(): return false
	var entrees: Array = app.root_content.find_children("Nav_*", "Button", true, false)
	if rang >= entrees.size(): return false
	var bouton: Button = entrees[rang]
	if bouton.disabled or not bouton.is_visible_in_tree(): return false
	bouton.pressed.emit()
	return true

## Échap referme d'abord la fiche ouverte. Sans fiche, on laisse le menu de la carrière (main.gd), qui ne quitte jamais seul.
func _retour() -> bool:
	if not actif(): return false
	# Sous-page « Charge individuelle » de la fiche : Échap revient à la fiche (avant le retour à la liste).
	var charge: Button = app.root_content.find_child("FicheChargeRetour", true, false) as Button
	if is_instance_valid(charge) and charge.is_visible_in_tree():
		charge.pressed.emit()
		return true
	var retour: Button = app.root_content.find_child("PlayerBackToSquad", true, false) as Button
	# Fiche joueur ouverte (effectif, piste du marché ou Espoir) : Échap revient à la liste d'origine.
	if is_instance_valid(retour) and retour.is_visible_in_tree():
		retour.pressed.emit()
		return true
	# Sous-page de la Composition (tireurs et lanceur, espoir, renforts) : Échap revient à la composition.
	var composition: Button = app.root_content.find_child("CompositionRetour", true, false) as Button
	if is_instance_valid(composition) and composition.is_visible_in_tree():
		composition.pressed.emit()
		return true
	# Sous-page du Recrutement (relève, entre clubs, offres, missions, négociation, rapport) : Échap revient au recrutement.
	var recrutement: Button = app.root_content.find_child("RecrutementRetour", true, false) as Button
	if is_instance_valid(recrutement) and recrutement.is_visible_in_tree():
		recrutement.pressed.emit()
		return true
	var navigation: Node = app.get("navigation_controller")
	if app.route == "Fiche club" and is_instance_valid(navigation):
		if navigation._destination(-1) >= 0: navigation._travel(-1)
		else: app._navigate("Classements")
		return true
	return false

## Joueur précédent / suivant d'une fiche joueur ouverte (boutons « ‹ » et « › » de sa barre).
func _joueur_voisin(suivant: bool) -> bool:
	if not actif(): return false
	var bouton := app.root_content.find_child("FicheSuivant" if suivant else "FichePrecedent", true, false) as Button
	if bouton == null or bouton.disabled or not bouton.is_visible_in_tree(): return false
	bouton.pressed.emit()
	return true

## Ctrl+F comme Ctrl+K : focus dans le champ « Rechercher » de la barre haute (aucune fenêtre) ;
## hors coque seulement, l'accès rapide.
func _recherche() -> bool:
	var navigation: Node = app.get("navigation_controller") if is_instance_valid(app) else null
	if not actif() or not is_instance_valid(navigation): return false
	if not navigation.focus_search(): navigation.open_palette()
	return true
