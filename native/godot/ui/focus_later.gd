extends RefCounted
## Focus demandé au tour suivant de la boucle, une fois le nœud ajouté à l'arbre. Si le nœud a quitté l'arbre
## entre-temps (écran reconstruit par une réponse du moteur arrivée dans la même image, dialogue fermé), rien n'est fait :
## Godot refuse le focus hors de l'arbre (« Condition "!is_inside_tree()" is true » dans grab_focus).

## Demande le focus de `control` au prochain passage de la boucle, s'il est encore affiché dans l'arbre.
static func grab(control: Object) -> void:
	if control == null:
		return
	var ref := weakref(control)
	var apply := func() -> void:
		var target := ref.get_ref() as Control
		if target != null and target.is_inside_tree():
			target.grab_focus()
	apply.call_deferred()
