extends SceneTree
## Case « Confier aussi les prolongations au staff » de l'onglet Contrats (Effectif), sur un modèle factice :
## présente et cochée/décochée selon decisions.delegation.contracts, détail (consigne, décisions de la saison),
## absente hors mode Monde (clé manquante), désactivée pendant un match, commande set_delegation envoyée au clic.
## Capture (hors CI) : CD_PROLONGATIONS_CAPTURES=<dossier> sous un affichage réel -> prolongations-staff.png.
const Review = preload("res://ui/contract_review.gd")

## Application factice : seulement ce que la vue lit (modèle, réglages d'interface, commandes envoyées).
class FakeApp extends Control:
	var model: Dictionary = {}
	var management_ui: Dictionary = {"roster": {}}
	var selected_player := ""
	var sent: Array = []
	var accept := true
	func _live() -> Dictionary: return model.live if model.get("live") is Dictionary else {}
	func _render() -> void: pass
	func _command(command: String, payload: Dictionary = {}, _target_route: String = "") -> bool:
		sent.append([command, payload])
		return accept

var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)

func settle(frames: int = 6) -> void:
	for i in frames: await process_frame

func capture(id: String) -> void:
	var directory := OS.get_environment("CD_PROLONGATIONS_CAPTURES")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(id + ".png"))

func model_with(delegation: Dictionary, live: Variant = null) -> Dictionary:
	return {"meta": {"season": 1, "mode": "world"}, "squad": [], "live": live, "decisions": {"delegation": delegation}}

func mount(model: Dictionary) -> Array:
	var app := FakeApp.new()
	app.model = model
	root.add_child(app)
	var view: Control = Review.build(app)
	view.size = Vector2(1800, 900)
	app.add_child(view)
	await settle()
	return [app, view]

func unmount(app: Node) -> void:
	root.remove_child(app)
	app.queue_free()

func run() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	# Cochée, avec consigne et décisions de la saison : « prolonger quand même » compte comme prolongé, une prolongation annulée comme un départ.
	var decided := [
		{"id": "p1", "name": "A", "pos": "Pilier", "decision": "prolonge", "state": "actif", "salary": 100000, "end": 3},
		{"id": "p2", "name": "B", "pos": "Centre", "decision": "libere", "state": "force", "salary": 90000, "end": 2},
		{"id": "p3", "name": "C", "pos": "Ailier", "decision": "libere", "state": "actif", "salary": 80000, "end": 1},
		{"id": "p4", "name": "D", "pos": "Talonneur", "decision": "prolonge", "state": "annule", "salary": 70000, "end": 1}]
	var on := model_with({"lineup": false, "contracts": true, "contractsPolicy": "jeunes", "contractsPolicyLabel": "miser sur les jeunes", "contractsDecided": decided})
	var pair: Array = await mount(on)
	var app: FakeApp = pair[0]
	var view: Control = pair[1]
	var box := view.find_child("ContractDelegationStaff", true, false) as CheckBox
	var detail := view.find_child("ContractDelegationDetail", true, false) as Label
	check(box != null and box.text == "Confier aussi les prolongations au staff", "Case « Confier aussi les prolongations au staff » présente")
	check(box != null and box.button_pressed and not box.disabled and box.custom_minimum_size.y == 36, "Cochée, active, hauteur 36")
	check(box != null and not box.tooltip_text.is_empty(), "Infobulle présente")
	check(detail != null and detail.text.contains("Le directeur sportif tranche en mars") and detail.text.contains("plafond de la ligue") and detail.text.contains("annulable"), "Détail cochée : principe du directeur sportif")
	check(detail != null and detail.text.contains("Consigne : miser sur les jeunes."), "Détail cochée : consigne donnée")
	check(detail != null and detail.text.ends_with("Cette saison : 2 prolongés, 2 laissés partir."), "Détail cochée : décisions de la saison (forcée gardée, annulée partie) : " + (detail.text if detail != null else ""))
	await capture("prolongations-staff")
	if box != null:
		box.button_pressed = false
		await settle(2)
		check(app.sent.size() == 1 and app.sent[0][0] == "set_delegation" and app.sent[0][1] == {"key": "contracts", "enabled": false}, "Décocher envoie set_delegation {contracts, false} : " + str(app.sent))
		check(detail.text == "Tu gères seul les prolongations : les contrats non prolongés partent à leur échéance.", "Détail décochée : " + detail.text)
		app.accept = false
		box.button_pressed = true
		await settle(2)
		check(not box.button_pressed, "Commande refusée : la case revient à son état")
	unmount(app)
	# Décochée dans le modèle.
	pair = await mount(model_with({"contracts": false}))
	box = pair[1].find_child("ContractDelegationStaff", true, false)
	detail = pair[1].find_child("ContractDelegationDetail", true, false)
	check(box != null and not box.button_pressed, "Décochée quand le moteur le dit")
	check(detail != null and detail.text.begins_with("Tu gères seul les prolongations"), "Détail décochée affiché d'emblée")
	unmount(pair[0])
	# Cochée sans décision ni consigne : pas de ligne « Cette saison ».
	pair = await mount(model_with({"contracts": true, "contractsPolicyLabel": "équilibre", "contractsDecided": []}))
	detail = pair[1].find_child("ContractDelegationDetail", true, false)
	check(detail != null and detail.text.ends_with("Consigne : équilibre.") and not detail.text.contains("Cette saison"), "Sans décision : pas de bilan de saison")
	unmount(pair[0])
	# Match en cours : case désactivée.
	pair = await mount(model_with({"contracts": true}, {"minute": 12}))
	box = pair[1].find_child("ContractDelegationStaff", true, false)
	check(box != null and box.disabled, "Désactivée pendant un match")
	unmount(pair[0])
	# Hors mode Monde : clé absente, ni case ni détail.
	pair = await mount(model_with({"lineup": false}))
	check(pair[1].find_child("ContractDelegationStaff", true, false) == null and pair[1].find_child("ContractDelegationDetail", true, false) == null, "Sans clé contracts : ni case ni détail")
	unmount(pair[0])
	var sans := {"meta": {"season": 1}, "squad": []}
	pair = await mount(sans)
	check(pair[1].find_child("ContractDelegationStaff", true, false) == null, "Sans decisions.delegation : aucune case")
	unmount(pair[0])
	# Courrier : la rubrique « contrats » du moteur arrive dans Direction et ouvre l'onglet Contrats.
	var Mail = load("res://ui/club_mail.gd")
	check(Mail.CATEGORY.get("contrats") == "Direction", "Courrier « Contrats » rangé dans Direction (icône et couleur existantes)")
	check(Mail.route_of("contrats") == "Effectif" and Mail.caption("contrats") == "Ouvrir · Contrats", "L'écran « contrats » ouvre l'Effectif, bouton « Contrats »")
	print("PROLONGATIONS_STAFF ", checks, " controles, ", failures.size(), " echec", "s" if failures.size() > 1 else "")
	quit(1 if failures.size() > 0 else 0)
