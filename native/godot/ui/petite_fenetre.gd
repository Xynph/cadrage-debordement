extends RefCounted
## Petites fenêtres (règle de Léo du 21/11/2026 : permises si elles restent visuelles) et la touche Échap.
## Toute petite fenêtre s'enregistre ici ; Échap ferme d'abord la plus récente encore visible et ne fait rien d'autre.
## Sans petite fenêtre ouverte, Échap garde son rôle (menu de la carrière, menu du match, retour d'une sous-page).
## Exemple, à l'ouverture d'une fenêtre : `PetiteFenetre.enregistrer(calque, fermer_ma_fenetre)`.
## Les gestionnaires d'Échap (main.gd, raccourcis_clavier.gd, contextual/director.gd, contextual/live_view.gd)
## appellent `PetiteFenetre.fermer_derniere(get_tree())` avant leur propre action.

const GROUPE := &"petite_fenetre"
const FERMER := &"petite_fenetre_fermer"

## Inscrit `fenetre` (le calque ou le panneau affiché) ; `fermer` la referme proprement. Sans `fermer`, la fenêtre est
## libérée. L'ordre d'inscription fait foi : la dernière ouverte est la première fermée.
static func enregistrer(fenetre: Node, fermer: Callable = Callable()) -> void:
	if fenetre == null: return
	fenetre.add_to_group(GROUPE)
	fenetre.set_meta(FERMER, fermer)
	fenetre.set_meta(&"petite_fenetre_ordre", Time.get_ticks_usec())

## Une petite fenêtre est-elle ouverte (visible, pas en cours de libération) ?
static func ouverte(arbre: SceneTree) -> Node:
	if arbre == null: return null
	var derniere: Node = null
	var ordre := -1
	for noeud: Node in arbre.get_nodes_in_group(GROUPE):
		if noeud.is_queued_for_deletion() or not noeud.is_inside_tree(): continue
		if noeud is CanvasItem and not (noeud as CanvasItem).is_visible_in_tree(): continue
		var rang := int(noeud.get_meta(&"petite_fenetre_ordre", 0))
		if rang >= ordre:
			ordre = rang
			derniere = noeud
	return derniere

## Ferme la petite fenêtre ouverte la plus récente ; true si une fenêtre a été fermée (Échap s'arrête là).
static func fermer_derniere(arbre: SceneTree) -> bool:
	var fenetre := ouverte(arbre)
	if fenetre == null: return false
	var fermer: Variant = fenetre.get_meta(FERMER, Callable())
	fenetre.remove_from_group(GROUPE)
	if fermer is Callable and (fermer as Callable).is_valid(): (fermer as Callable).call()
	else: fenetre.queue_free()
	return true
