extends RefCounted
## Compatibilité : le brouillon européen n'est plus une fenêtre, c'est la page « Préparer l’Europe »
## (ui/immersive08/europe_canvas.gd). Cette entrée navigue vers elle.
static func open(owner_app: Control) -> void:
	load("res://ui/immersive08/europe_canvas.gd").open(owner_app)
