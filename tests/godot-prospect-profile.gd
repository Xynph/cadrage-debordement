extends SceneTree
const Profile = preload("res://ui/prospect_profile.gd")

class Host extends Control:
	var model: Dictionary
	var accent := Color("176e49")
	var commands := 0
	func _prepare_dialog(dialog: AcceptDialog, width: int) -> void:
		load("res://ui/immersive08/dialogs.gd").prepare(dialog, width, accent)
	func _command(_name: String, _payload: Dictionary = {}) -> void: commands += 1

class Source extends AcceptDialog:
	var query := "Centre"
	var page := 3
	var scroll := 142
	var offer_fee := 43210
	var offer_salary := 6543
	var negotiation := {"winner":2}
	func reading() -> String:
		return JSON.stringify([query, page, scroll, offer_fee, offer_salary, negotiation])

var checks := 0
var failures: Array[String] = []
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description); printerr("FAIL: ", description)
func _initialize() -> void: call_deferred("run")
func words(node: Node) -> String:
	var result := str(node.text) + "\n" if node is Label or node is Button else ""
	for child in node.get_children(): result += words(child)
	return result
func settle() -> void:
	for frame in 4: await process_frame
func run() -> void:
	root.size = Vector2i(2560,1440)
	var app := Host.new()
	root.add_child(app)
	var current := {"id":"known:one","name":"Prospect actuel","pos":"Centre","age":23,"salary":5400,"fee":30000,"rating":99,"potential":100,"sourceSalary":838383,"knowledge":{"owned":false,"stage":"unobserved"},"origin":{"label":"Centre de formation"},"terms":[{"years":2,"payments":50,"fee":30000,"salary":5400,"knownCommitment":300000}]}
	var archive := current.duplicate(true)
	archive.name = "Profil conservé"
	app.model = {"squad":[{"id":"own:one","name":"Joueur du club","pos":"Centre","age":27,"rating":78,"salary":5100,"contractEnd":3}],"clubLife":{"regenScouting":{"candidates":[current],"shortlist":[archive]},"interclubMarket":{"candidates":[{"id":"seller:one","name":"Joueur du vendeur","club":"Club adverse","clubId":2,"pos":"Pilier gauche","age":30,"salary":6400,"sourceSalary":838383,"fee":50000,"contractEnd":3}]}}}
	var original := JSON.stringify(app.model)
	check(Profile.target_available(app,"regen-candidates","known:one"),"Candidat connu absent du marché général consultable")
	check(Profile.projected_person(app,"regen-shortlist","known:one").name == "Profil conservé","Source archives exacte sans repli sur candidat homonyme")
	check(not Profile.target_available(app,"regen-candidates","missing"),"ID absent refusé")
	check(not Profile.target_available(app,"unknown","known:one"),"Source inconnue refusée")
	app.model.clubLife.regenScouting.candidates.append(current.duplicate(true))
	check(not Profile.target_available(app,"regen-candidates","known:one"),"ID ambigu refusé")
	app.model.clubLife.regenScouting.candidates.pop_back()
	var owner := Source.new()
	owner.name = "ProspectSourceFixture"
	app.add_child(owner)
	var focus := Button.new()
	focus.text = "Origine du lien"
	owner.add_child(focus)
	owner.popup_centered(Vector2i(880,580))
	await settle()
	focus.grab_focus()
	var draft_before := owner.reading()
	check(Profile.open_target(app,"regen-candidates","known:one",owner),"Dossier limité ouvert dans une fenêtre enfant")
	await settle()
	var dialog := owner.get_node_or_null("ProspectProfile") as AcceptDialog
	check(dialog != null and dialog.visible and dialog.get_parent() == owner and owner.visible,"Source métier conservée et enfant visible")
	check(dialog.find_child("ProspectProfileName",true,false).text == "Prospect actuel","Identité exacte du candidat")
	check(not words(dialog).contains("838383") and not words(dialog).contains("99"),"Salaire source et niveau brut cachés non révélés")
	check(words(dialog).contains("Joueur du club") and words(dialog).contains("78"),"Repères de votre effectif au même poste disponibles")
	check(dialog.find_children("Offer*","Button",true,false).is_empty() and dialog.find_children("Observe*","Button",true,false).is_empty(),"Aucune offre ou observation dans le dossier")
	check(not Profile.open_target(app,"regen-candidates","known:one",owner),"Aucune fenêtre détail dupliquée")
	dialog.canceled.emit()
	await settle()
	check(owner.visible and owner.get_node_or_null("ProspectProfile") == null,"Retour ferme uniquement le détail")
	check(focus.has_focus(),"Focus rendu au contrôle d’origine")
	check(owner.reading() == draft_before,"Conditions et lecture de la source conservées")
	check(Profile.open_target(app,"interclub","seller:one",owner),"Même dossier pour joueur interclubs hors marché général")
	await settle()
	dialog = owner.get_node("ProspectProfile")
	check(dialog.find_child("ProspectProfileName",true,false).text == "Joueur du vendeur","Interclubs vise le vendeur exact")
	check(not words(dialog).contains("838383"),"Salaire de concurrence interne jamais affiché")
	dialog.confirmed.emit()
	await settle()
	check(JSON.stringify(app.model) == original and app.commands == 0,"Modèle inchangé et aucune commande métier")
	app.queue_free()
	await settle()
	print("PROSPECT_PROFILE ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
