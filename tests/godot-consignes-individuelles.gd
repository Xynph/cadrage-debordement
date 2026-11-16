extends SceneTree
## Tireurs et lanceur (écran Composition) : lignes par rôle, charge utile de set_tactics, fenêtre et
## mise en garde de Gabi sur un buteur médiocre. Projection du moteur simulée (tactics.roles).
const Roles = preload("res://ui/immersive08/tactics_roles.gd")
const Gabi = preload("res://guide/gabi_avis.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: ", message)
func person(id: String, name: String, pos: String, value: int) -> Dictionary:
	return {"id": id, "name": name, "pos": pos, "value": value}
func model(chosen: Variant = null, alerte: Variant = null, editable := true) -> Dictionary:
	var ouvreur := person("p10", "Hugo Martin", "Demi d’ouverture", 81)
	var ailier := person("p11", "Léo Petit", "Ailier", 42)
	var talon := person("p2", "Paul Durand", "Talonneur", 74)
	var role := func(id: String, label: String, attribute: String, staff: Dictionary, candidates: Array, choice: Variant) -> Dictionary:
		return {"id": id, "label": label, "attributeLabel": attribute, "staff": staff, "chosen": choice, "inLineup": true, "candidates": candidates}
	return {"tactics": {"attack": "large", "defense": "equilibre", "roles": {"editable": editable, "alerte": alerte, "roles": [
		role.call("buteur", "Buteur", "But", ouvreur, [ouvreur, ailier], chosen),
		role.call("secours", "Buteur de secours", "But", ailier, [ouvreur, ailier], null),
		role.call("lanceur", "Lanceur en touche", "Touche", talon, [talon, ailier], null),
		role.call("pied", "Jeu au pied d’occupation", "Jeu au pied", ouvreur, [ouvreur, ailier], null)]}}}
func _initialize() -> void:
	var rows := Roles.rows(model())
	check(rows.size() == 4, "Quatre rôles : buteur, secours, lanceur, jeu au pied")
	check(str(rows[0].labels[0]).begins_with("Choix du staff") and str(rows[0].labels[0]).contains("81"), "Premier choix : le staff, avec sa valeur")
	check(int(rows[0].selected) == 0 and str(rows[0].ids[0]) == "", "Sans désignation : choix du staff retenu")
	var chosen := Roles.rows(model(person("p11", "Léo Petit", "Ailier", 42)))
	check(int(chosen[0].selected) == 2, "Joueur désigné retenu dans la liste")
	var data := Roles.payload(model(), "buteur", "p11")
	check(data.attack == "large" and data.defense == "equilibre" and data.roles.buteur == "p11", "Charge utile : consignes d’équipe inchangées, buteur désigné")
	check(Roles.payload(model(), "lanceur", "").roles.lanceur == null, "Choix du staff : null")
	check(Roles.warning(model()).is_empty(), "Aucune mise en garde par défaut")
	var alerte := {"playerId": "p11", "name": "Léo Petit", "value": 42, "staffName": "Hugo Martin", "staffValue": 81}
	var with_alert := model(person("p11", "Léo Petit", "Ailier", 42), alerte)
	check(Roles.warning(with_alert).contains("Léo Petit") and Roles.warning(with_alert).contains("81"), "Mise en garde du staff")
	var sent: Array = []
	var body := Roles.body(with_alert, func(payload: Dictionary): sent.append(payload))
	root.add_child(body)
	var choice := body.find_child("TacticsRole_lanceur", true, false) as OptionButton
	check(choice != null and choice.item_count == 3 and not choice.disabled, "Liste du lanceur : staff + deux joueurs")
	if choice != null: choice.item_selected.emit(2)
	check(sent.size() == 1 and sent[0].roles.lanceur == "p11", "Sélection : set_tactics avec le lanceur choisi")
	check(body.find_child("TacticsRolesWarning", true, false) != null, "Mise en garde affichée")
	body.queue_free()
	var locked := Roles.body(model(null, null, false), func(_p: Dictionary): pass)
	root.add_child(locked)
	var buteur := locked.find_child("TacticsRole_buteur", true, false) as OptionButton
	check(buteur != null and buteur.disabled, "Pendant le match : listes verrouillées")
	locked.queue_free()
	check(Roles.view({}).is_empty() and Roles.rows({}).is_empty(), "Projection absente : rien à afficher")
	var avis := Gabi.buteur_mediocre(with_alert)
	check(str(avis.get("texte", "")).contains("Léo Petit") and str(avis.get("categorie", "")) == "mise_en_garde", "Gabi signale le buteur médiocre")
	check(Gabi.buteur_mediocre(model()).is_empty(), "Gabi se tait sans alerte")
	print("CONSIGNES INDIVIDUELLES : %d contrôles ; %d échecs" % [checks, failures])
	quit(0 if failures == 0 else 1)
