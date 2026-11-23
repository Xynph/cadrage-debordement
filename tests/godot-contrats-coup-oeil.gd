extends SceneTree
## Effectif › Contrats « en un coup d'œil » (revue FM27, idée 12, option A ; décision de Léo du 23/11/2026), sur un modèle
## factice : compteurs d'échéance 0-6 mois / 6-12 / 1-2 ans / 2 ans + (filtres), une ligne par joueur (part de la masse,
## rôle promis au contrat en pastille commune, temps de jeu, échéance colorée, conseil du staff venu du moteur, bouton
## Prolonger), tris par conseil, part de la masse et temps de jeu. Couleurs des rôles : un seul endroit (Charte.ROLE_*).
const Review = preload("res://ui/contract_review.gd")
const Role = preload("res://ui/role_contrat.gd")
const Charte = preload("res://ui/charte.gd")

class FakeApp extends Control:
	var model: Dictionary = {}
	var management_ui: Dictionary = {"roster": {}}
	var selected_player := ""
	var rendus := 0
	func _live() -> Dictionary: return model.live if model.get("live") is Dictionary else {}
	func _render(_complet: bool = true) -> void: rendus += 1
	func _command(_command: String, _payload: Dictionary = {}, _target_route: String = "") -> bool: return true
	func _navigate(_route: String, _a: bool = false, _b: bool = false) -> void: pass

var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)

func settle(frames: int = 6) -> void:
	for i in frames: await process_frame

func joueur(id: String, fin: int, salaire: int, minutes: int, role: String, deduit: bool, conseil: String, disponible: bool) -> Dictionary:
	return {"id": id, "name": "Joueur " + id.to_upper(), "pos": "Centre", "fam": 7, "age": 25, "rating": 70, "contractEnd": fin, "salary": salaire, "minutes": minutes, "appearances": minutes / 80,
		"portraitIndex": 0, "renewal": {"available": disponible}, "roleContrat": {"role": role, "deduit": deduit, "saison": 1}, "conseilStaff": {"conseil": conseil, "raison": "cadre"}}

## Saison 1 (2026-27), le 13/11/2026 : fin 1 = juin 2027 (7 mois), fin 2 = juin 2028, fin 3 = juin 2029.
func modele() -> Dictionary:
	var squad := [
		joueur("a", 1, 3000, 800, "titulaire", false, "prolonger", true),
		joueur("b", 1, 1000, 0, "appoint", true, "partir", true),
		joueur("c", 2, 2000, 400, "rotation", true, "garder", false),
		joueur("d", 3, 4000, 600, "espoir", false, "vendre", false),
		joueur("e", 3, 0, 100, "titulaire", true, "vente", false),
	]
	squad[4].erase("salary")
	return {"meta": {"season": 1, "calendarToday": "2026-11-13"}, "squad": squad}

func mount(model: Dictionary, state: Dictionary = {}) -> Array:
	var app := FakeApp.new()
	app.model = model
	if not state.is_empty(): app.management_ui.roster.contract_review = state
	root.add_child(app)
	var view: Control = Review.build(app)
	view.size = Vector2(1800, 900)
	app.add_child(view)
	await settle()
	return [app, view]

func unmount(app: Node) -> void:
	root.remove_child(app)
	app.queue_free()

func lignes(view: Control) -> Array:
	return view.find_child("ContractReviewRows", true, false).get_children().map(func(row): return str(row.get_meta("player_id", "")))

func run() -> void:
	root.size = Vector2i(1920, 1080)
	# Couleurs et libellés des rôles : un seul endroit.
	check(Role.couleur("titulaire") == Color("5b9bd5") and Role.couleur("rotation") == Color("a88bd6") and Role.couleur("espoir") == Color("4fb3a9") and Role.couleur("appoint") == Charte.GRIS_VERT, "Rôles : bleu, violet, turquoise, gris")
	check(Role.couleur("titulaire") == Charte.ROLE_TITULAIRE and Role.couleur("espoir") == Charte.ROLE_ESPOIR, "Rôles : couleurs tirées des jetons de la charte")
	check(Role.libelle("rotation") == "Rotation" and Role.libelle("x") == "—" and Role.rang("titulaire") == 0 and Role.rang("") == 4, "Rôles : libellés et rang de tri")
	check(Role.role({"roleContrat": {"role": "espoir", "deduit": false}}) == "espoir" and Role.promis({"roleContrat": {"role": "espoir", "deduit": false}}), "Rôle promis lu dans la projection")
	check(Role.role({}) == "" and not Role.promis({"roleContrat": {"role": "rotation", "deduit": true}}), "Sans contrat : pas de rôle ; rôle déduit : pas « promis »")
	# Tranches d'échéance.
	check(Review.tranche(Review.mois_restants({"contractEnd": 1}, "2026-11-13")) == "6-12", "Fin juin 2027 vue du 13/11/2026 : 6-12 mois")
	check(Review.tranche(Review.mois_restants({"contractEnd": 1}, "2027-02-01")) == "0-6", "Fin juin 2027 vue du 01/02/2027 : 0-6 mois")
	check(Review.tranche(Review.mois_restants({"contractEnd": 2}, "2026-11-13")) == "1-2" and Review.tranche(Review.mois_restants({"contractEnd": 3}, "2026-11-13")) == "2+", "1-2 ans et 2 ans +")
	check(Review.conseil({"conseilStaff": {"conseil": "vendre"}}) == "vendre" and Review.conseil({}) == "aucun" and Review.conseil({"conseilStaff": {"conseil": "inconnu"}}) == "aucun", "Conseil lu dans la projection du moteur")
	var pair: Array = await mount(modele())
	var app: FakeApp = pair[0]
	var view: Control = pair[1]
	for id: String in ["0-6", "6-12", "1-2", "2p"]: check(view.find_child("ContractTranche_" + id, true, false) is Button, "Compteur cliquable " + id)
	var nombre := func(id: String) -> String: return (view.find_child("ContractTrancheNombre_" + id, true, false) as Label).text
	check(nombre.call("0-6") == "0" and nombre.call("6-12") == "2" and nombre.call("1-2") == "1" and nombre.call("2p") == "2", "Compteurs : 0 / 2 / 1 / 2")
	check((view.find_child("ContractReviewWage", true, false) as Label).text != "" and view.find_child("ContractReviewStatWages", true, false) is Button, "Masse salariale en tuile cliquable")
	check(lignes(view).size() == 5, "Une ligne par joueur")
	for entete: String in ["name", "pos", "rating", "age", "salary", "share", "playtime", "contractEnd", "conseil"]: check(view.find_child("ContractSort_" + entete, true, false) is Button, "En-tête triable " + entete)
	for ancien: String in ["potential", "status", "renewal", "minutes"]: check(view.find_child("ContractSort_" + ancien, true, false) == null, "Ancienne colonne retirée : " + ancien)
	# Ligne : pastille du rôle (mot + couleur du rôle), conseil du moteur, part de la masse, Prolonger.
	for p: Dictionary in app.model.squad:
		var ligne := view.find_child(Review.action_id("ContractRow", str(p.id)), true, false)
		var pastille := ligne.find_child("RoleContrat_" + str(p.roleContrat.role), true, false) as PanelContainer
		check(pastille != null, str(p.id) + " : pastille du rôle")
		if pastille != null:
			var mot := pastille.get_child(0) as Label
			check(mot.text == Role.libelle(str(p.roleContrat.role)) and mot.get_theme_color("font_color") == Role.couleur(str(p.roleContrat.role)), str(p.id) + " : mot et couleur du rôle")
		var conseil := ligne.find_child(Review.action_id("ContractConseil", str(p.id)), true, false) as Button
		check(conseil != null and conseil.get_meta("conseil") == str(p.conseilStaff.conseil), str(p.id) + " : conseil du staff du moteur")
		var jeu := ligne.find_child(Review.action_id("ContractPlaytime", str(p.id)), true, false) as Button
		check(jeu != null and jeu.tooltip_text.contains("min") and (jeu.tooltip_text.contains("promis") == not bool(p.roleContrat.deduit)), str(p.id) + " : temps de jeu et promesse en infobulle")
		var prolonger := ligne.find_child(Review.action_id("ContractRenew", str(p.id)), true, false) as Button
		check(prolonger != null and prolonger.disabled == not bool(p.renewal.available), str(p.id) + " : bouton Prolonger selon le moteur")
	var part_a := view.find_child(Review.action_id("ContractShare", "a"), true, false) as Button
	check(part_a != null and part_a.tooltip_text.begins_with("30,0 %"), "Part de la masse : 3 000 sur 10 000 = 30,0 %")
	# Tris : conseil (prolonger, partir, vendre, vente, garder), part de la masse, temps de jeu.
	check(Review.filtered(app.model.squad, {"sort": "conseil"}).map(func(p): return p.id) == ["a", "b", "d", "e", "c"], "Tri par conseil")
	check(Review.filtered(app.model.squad, {"sort": "share", "descending": true}).map(func(p): return p.id) == ["d", "a", "c", "b", "e"], "Tri par part de la masse, salaire inconnu en dernier")
	check(Review.filtered(app.model.squad, {"sort": "playtime"}).map(func(p): return p.id) == ["b", "e", "c", "d", "a"], "Tri par temps de jeu")
	# Clic sur un compteur : filtre (second clic : retire le filtre).
	(view.find_child("ContractTranche_6-12", true, false) as Button).pressed.emit()
	check(app.rendus == 1 and app.management_ui.roster.contract_review.tranche == "6-12", "Compteur 6-12 mois : filtre posé")
	var etat: Dictionary = app.management_ui.roster.contract_review
	unmount(app)
	pair = await mount(modele(), etat)
	app = pair[0]
	view = pair[1]
	check(lignes(view) == ["a", "b"], "Filtre 6-12 mois : les deux contrats de juin 2027")
	check(bool((view.find_child("ContractTranche_6-12", true, false) as Button).get_meta("choisi")), "Compteur choisi marqué")
	(view.find_child("ContractTranche_6-12", true, false) as Button).pressed.emit()
	check(app.management_ui.roster.contract_review.tranche == "", "Second clic : filtre retiré")
	unmount(app)
	# Hors mode Monde (pas de conseil ni de rôle) : la ligne reste lisible.
	var nu := modele()
	for p: Dictionary in nu.squad: p.erase("conseilStaff"); p.erase("roleContrat")
	pair = await mount(nu)
	view = pair[1]
	var c := view.find_child(Review.action_id("ContractConseil", "a"), true, false) as Button
	check(c != null and c.get_meta("conseil") == "aucun", "Sans conseil du moteur : « — »")
	check(view.find_child("RoleContrat_titulaire", true, false) == null, "Sans rôle : pas de pastille")
	unmount(pair[0])
	print("CONTRATS_COUP_OEIL ", checks, " controles, ", failures.size(), " echec", "s" if failures.size() > 1 else "")
	quit(1 if failures.size() > 0 else 0)
