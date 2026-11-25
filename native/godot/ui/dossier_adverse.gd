extends RefCounted
## Dossier d'un joueur d'un autre club : celui qu'ouvre le clic sur un joueur de l'effectif d'un club (page club), c'est-à-dire
## le marché entre clubs filtré sur son nom puis la fenêtre « Dossier · Nom » (prospect_profile.gd). Décision de Léo, 25/11/2026 :
## sur l'écran Préparation, un clic sur un joueur adverse ouvre sa fiche (avant-match et après-match gardent la mini-fiche).
const Profil = preload("res://ui/prospect_profile.gd")

static func disponible(app: Control, id: String) -> bool:
	return not id.is_empty() and Profil.target_available(app, "interclub", id)

## Vrai si le dossier s'est ouvert ; faux sinon (l'appelant ouvre alors le club).
static func ouvrir(app: Control, id: String, nom: String) -> bool:
	if not disponible(app, id): return false
	var marche: Variant = preload("res://ui/interclub_market_view.gd").open(app)
	if not is_instance_valid(marche): return false
	marche.search_field.text = nom
	marche.query = nom
	marche.page = 0
	marche._redraw()
	var fenetre := app.get_node_or_null("InterclubMarket") as Window
	return fenetre != null and Profil.open_target(app, "interclub", id, fenetre)
