extends RefCounted
## Confirmation EN PLACE d'un engagement d'argent (décision de Léo du 19/11/2026 : jamais de petite fenêtre, seule exception
## « Libérer »). Deux temps dans la page : un premier clic ouvre ce bloc (phrase d'engagement, lignes de conséquence, montant),
## un second clic (« Confirmer … ») envoie la commande ; « Annuler » le referme sans rien envoyer (focus sur Annuler).
## Le résultat de la commande est affiché dans la page par la vue qui appelle.
## Exemple : `EnPlace.ouvrir(app, rows, "SaleConfirmation", "Vendre Dupont", lignes, "Vendre Dupont", func(): envoyer())`.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/carnet_skin.gd")

## Bloc de confirmation inséré dans `conteneur` (à la fin, ou juste après `apres`). Un bloc de même nom déjà présent est remplacé.
## `lignes` : textes ou {id, text}. Renvoie le bloc (nom = `id`) ; boutons `id + "Ok"` et `id + "Annuler"`.
static func ouvrir(app: Control, conteneur: Node, id: String, titre: String, lignes: Array, libelle_ok: String, au_ok: Callable, apres: Node = null, libelle_annuler: String = "Annuler") -> PanelContainer:
	var ancien := conteneur.get_node_or_null(id)
	if ancien != null:
		conteneur.remove_child(ancien)
		ancien.queue_free()
	var bloc := PanelContainer.new()
	bloc.name = id
	bloc.set_meta("immersive_style_applied", true)
	var fond := C.box(Charte.PANNEAU_3, Charte.IVOIRE, 0, 14)
	fond.set_border_width_all(2)
	fond.border_color = Charte.IVOIRE
	bloc.add_theme_stylebox_override("panel", fond)
	var contenu := C.v(8)
	bloc.add_child(contenu)
	var entete := C.label(titre.to_upper(), 22, Charte.IVOIRE, true, 700)
	entete.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	entete.name = id + "Titre"
	contenu.add_child(entete)
	for ligne: Variant in lignes:
		var texte := str(ligne.get("text", "")) if ligne is Dictionary else str(ligne)
		if texte.is_empty(): continue
		var label := C.wrap(texte, 18, Charte.IVOIRE)
		label.add_theme_font_override("font", Charte.TEXTE)
		label.name = str(ligne.get("id", "")) if ligne is Dictionary and not str(ligne.get("id", "")).is_empty() else id + "Ligne"
		contenu.add_child(label)
	var actions := C.h(18)
	contenu.add_child(actions)
	var ok := Button.new()
	ok.name = id + "Ok"
	ok.text = libelle_ok.to_upper()
	ok.focus_mode = Control.FOCUS_ALL
	ok.set_meta("style_charte", true)
	C.style_bouton_ivoire_plein(ok, 21)
	actions.add_child(ok)
	var annuler := Button.new()
	annuler.name = id + "Annuler"
	annuler.text = libelle_annuler
	annuler.focus_mode = Control.FOCUS_ALL
	annuler.set_meta("style_charte", true)
	C.style_bouton_lien(annuler, 20)
	actions.add_child(annuler)
	annuler.pressed.connect(func():
		if is_instance_valid(bloc):
			bloc.get_parent().remove_child(bloc)
			bloc.queue_free())
	ok.pressed.connect(func():
		if is_instance_valid(bloc) and bloc.get_parent() != null:
			bloc.get_parent().remove_child(bloc)
			bloc.queue_free()
		au_ok.call())
	conteneur.add_child(bloc)
	if apres != null and apres.get_parent() == conteneur: conteneur.move_child(bloc, apres.get_index() + 1)
	annuler.grab_focus.call_deferred()
	return bloc
