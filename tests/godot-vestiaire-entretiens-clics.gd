extends SceneTree
## Vestiaire › Entretiens et duos (portraits et anneaux, revue du 21/11/2026, n° 4) : chaque carte, anneau, portrait et pastille
## cliquable déclenche bien son action ; « +N » ouvre la petite fenêtre du groupe, qui se ferme (Échap / ✕) ou choisit.
const View = preload("res://ui/relationships_view.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
var checks := 0
var failures: Array[String] = []

class Navigation extends Node:
	var opened: Array = []
	func entity_available(target: Dictionary) -> bool: return str(target.get("kind", "")) == "player"
	func open_entity(target: Dictionary, _source: Window = null) -> bool:
		opened.append(target.duplicate(true))
		return true

class Host extends Control:
	var model: Dictionary = {}
	var management_ui: Dictionary = {}
	var navigation_controller: Node
	var accent := Color("6f9ac9")
	var commands: Array = []
	var routes: Array = []
	var page: Control
	func _command(name: String, payload: Dictionary) -> void: commands.append([name, payload])
	func _navigate(route: String) -> void: routes.append(route)
	func _render() -> void:
		if is_instance_valid(page): remove_child(page); page.queue_free()
		page = View.build(self)
		add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for frame in 4: await process_frame

func discussion(rang: String) -> Dictionary:
	return {"situation": "normal", "hierarchie": rang, "attitude": 2, "attitudeAvant": 2, "accueil": "Oui, coach ?", "faite": false, "fil": [],
		"phrases": [{"id": "n_ecoute", "texte": "Dis-moi comment tu te sens.", "nature": "ecoute", "choice": "ecouter"},
			{"id": "n_soutien", "texte": "On compte sur toi.", "nature": "soutien", "choice": "rassurer"},
			{"id": "n_critique", "texte": "J’attends plus de toi.", "nature": "critique", "choice": "clarifier"}]}

func sample() -> Dictionary:
	var squad: Array = []
	var players: Array = []
	for i in 12:
		var id := "p%d" % i
		squad.append({"id": id, "name": "Joueur NUMERO%d" % i, "pos": "Centre", "portraitIndex": i})
		players.append({"id": id, "pos": "Centre", "score": 40 + i * 5, "condition": 88, "injury": 0, "minutes": 20 + i, "conversationAvailable": true, "promiseAvailable": true, "promiseHistory": [],
			"personality": {"trait": "Loyal", "leadership": 50 + i}, "discussion": discussion("relais" if i == 3 else "groupe")})
	return {"squad": squad, "clubLife": {"relationships": {"active": true, "context": {"season": 1, "week": 1}, "morale": 70, "trust": 80, "players": players, "leaderId": "p3",
		"conversations": [{"id": "ecouter", "label": "Écouter", "detail": "Satisfaction +2."}, {"id": "rassurer", "label": "Rassurer", "detail": "Satisfaction +1 ; premier entretien : moral +1."}],
		"promiseLastJourney": 24, "promiseOptions": [{"id": "rotation", "minutes": 80}, {"id": "titulaire", "minutes": 160}],
		"duoActions": [{"id": "mediation", "label": "Désamorcer une rivalité", "detail": "Dialogue encadré : lien +25, confiance de direction −1."}], "duoAvailable": true,
		"pairs": [{"a": "p1", "b": "p2", "score": 18}], "commitments": [{"playerId": "p1", "status": "open", "target": 60, "dueWeek": 3}],
		"conversationHistory": [{"playerId": "p0", "season": 1, "round": 2, "choice": "rassurer", "before": 40, "after": 41}],
		"history": [{"playerId": "p0", "season": 1, "week": 0, "title": "Un vestiaire tendu", "choice": "cadrer"}],
		"event": {"key": "event:one", "playerId": "p0", "title": "Une échéance pèse", "context": "Contexte.", "kind": "tension", "trait": "Loyal", "leadership": 63, "available": true,
			"choices": [{"id": "ecouter", "label": "L'écouter", "detail": "Satisfaction +4 ; moral +1."}, {"id": "cadrer", "label": "Rappeler les exigences", "detail": "Satisfaction −3 ; confiance de direction +2 ; moral −1."}]}}}}

func bouton(host: Host, id: String) -> Button:
	return host.find_child(id, true, false) as Button

func run() -> void:
	root.size = Vector2i(1920, 1080)
	var host := Host.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	host.navigation_controller = Navigation.new(); host.add_child(host.navigation_controller)
	host.model = sample()
	host.management_ui = {"relationships": {"playerId": "p0"}}
	host._render(); await settle()
	# Aucun bouton muet : tout bouton actif prend le focus clavier.
	for b: Button in host.page.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.disabled: check(b.focus_mode == Control.FOCUS_ALL, "Focus clavier : " + b.name)
	# Réponses, entretiens, promesses, duo : chaque carte envoie sa vraie commande.
	for attendu: Array in [["LockerDecision_ecouter", "locker_room_decision", "choice", "ecouter"], ["LockerDecision_cadrer", "locker_room_decision", "choice", "cadrer"],
			["Promise_rotation", "relationship_promise", "target", "rotation"], ["Promise_titulaire", "relationship_promise", "target", "titulaire"],
			["DuoAction_mediation", "relationship_duo", "mode", "mediation"]]:
		var b := bouton(host, attendu[0])
		check(b != null and not b.disabled, "Carte cliquable : " + attendu[0])
		if b == null: continue
		b.pressed.emit()
		var dernier: Array = host.commands.back() if not host.commands.is_empty() else ["", {}]
		check(dernier[0] == attendu[1] and str(dernier[1].get(attendu[2], "")) == attendu[3], "Commande de " + attendu[0])
	# Discussion : la carte « Discuter » ouvre la petite fenêtre (données à gauche, échelle, fil et phrases à droite) ;
	# un clic sur une phrase la dit tout de suite, sans bouton Valider.
	check(bouton(host, "Conversation_ecouter") == null, "Plus de lignes d'entretien : la discussion les remplace")
	host.commands.clear()
	bouton(host, "DiscussionOuvrir").pressed.emit(); await settle()
	var disc := host.find_child("DiscussionFenetre", true, false)
	check(disc != null and PetiteFenetre.ouverte(self) == disc, "Fenêtre de discussion ouverte et inscrite")
	for nom: String in ["DiscussionEchelleAttitude", "DiscussionFil", "DiscussionBulleAccueil", "DiscussionCourbeForme", "DiscussionHierarchie", "DiscussionAttitude", "DiscussionAnneauSatisfaction", "DiscussionAnneauConfiance"]:
		check(disc != null and disc.find_child(nom, true, false) != null, "Discussion : " + nom)
	var rang := disc.find_child("DiscussionHierarchie", true, false) if disc != null else null
	check(rang != null and (rang.find_children("*", "Label", true, false)[0] as Label).text == "Groupe", "Hiérarchie lue du moteur")
	check(disc != null and disc.find_children("DiscussionPhrase_*", "Button", true, false).size() == 3, "Trois phrases")
	for b: Button in (disc.find_children("*", "Button", true, false) if disc != null else []):
		check(not b.text.to_lower().contains("valider") and not b.text.to_lower().contains("confirmer"), "Aucun bouton Valider")
	bouton(host, "DiscussionPhrase_n_critique").pressed.emit(); await settle()
	var dit: Array = host.commands.back() if not host.commands.is_empty() else ["", {}]
	check(dit[0] == "relationship_conversation" and dit[1].get("choice") == "clarifier" and dit[1].get("phrase") == "n_critique" and dit[1].get("playerId") == "p0", "Un clic dit la phrase : %s" % [dit])
	check(host.find_child("DiscussionBulleCoachEnvoi", true, false) != null, "La phrase apparaît tout de suite dans le fil")
	check(bouton(host, "DiscussionPhrase_n_ecoute") != null and bouton(host, "DiscussionPhrase_n_ecoute").disabled, "Une seule phrase par semaine")
	# Réponse du moteur : sa réponse et l'effet dans le fil, l'échelle d'attitude bouge, « Vu cette semaine ».
	var p0: Dictionary = host.model.clubLife.relationships.players[0]
	p0.conversationAvailable = false
	p0.discussion.faite = true
	p0.discussion.attitudeAvant = 2
	p0.discussion.attitude = 0
	p0.discussion.fil = [{"season": 1, "round": 2, "phrase": "n_critique", "texte": "J’attends plus de toi.", "nature": "critique", "reponse": "Tu me parles pas comme ça.", "effet": -4, "avant": 50, "apres": 46}]
	host._render(); await settle()
	disc = host.find_child("DiscussionFenetre", true, false)
	var reponse := disc.find_child("DiscussionBulleJoueur0Texte", true, false) as Label if disc != null else null
	check(reponse != null and reponse.text == "Tu me parles pas comme ça.", "Réponse du joueur dans le fil")
	for nom: String in ["DiscussionBulleCoach0", "DiscussionEffet0", "DiscussionEchelleFleche", "DiscussionDejaVu"]:
		check(disc != null and disc.find_child(nom, true, false) != null, "Après la réponse : " + nom)
	check(disc != null and disc.find_child("DiscussionBulleCoachEnvoi", true, false) == null, "Phrase en attente remplacée par l'échange")
	check(PetiteFenetre.fermer_derniere(self), "Échap ferme la discussion")
	await settle()
	check(host.find_child("DiscussionFenetre", true, false) == null and not host.management_ui.has("discussion"), "Discussion refermée et oubliée")
	# Anneaux moral / conseil : ouvrent leur écran ; anneau de satisfaction et pastilles : la fiche du joueur.
	bouton(host, "RelationshipRingMorale").pressed.emit()
	bouton(host, "RelationshipRingTrust").pressed.emit()
	check(host.routes == ["Effectif", "Club"], "Anneaux moral et conseil vers leurs écrans")
	var avant: int = host.navigation_controller.opened.size()
	bouton(host, "RelationshipRingSatisfaction").pressed.emit()
	bouton(host, "RelationshipPersonalityTrait").pressed.emit()
	bouton(host, "RelationshipTileCondition").pressed.emit()
	check(host.navigation_controller.opened.size() == avant + 3 and host.navigation_controller.opened.back().id == "p0", "Anneau, trait et tuile ouvrent la fiche du joueur")
	# Rangée de portraits : relais présent, un clic choisit.
	check(bouton(host, "RelationshipPortrait_p3") != null, "Relais dans la rangée de portraits")
	bouton(host, "RelationshipPortrait_p3").pressed.emit(); await settle()
	check(host.management_ui.relationships.playerId == "p3", "Portrait choisi")
	host.commands.clear()
	bouton(host, "DiscussionOuvrir").pressed.emit(); await settle()
	var relais := host.find_child("DiscussionHierarchie", true, false)
	check(relais != null and (relais.find_children("*", "Label", true, false)[0] as Label).text == "Relais", "Le relais est marqué Relais")
	if bouton(host, "DiscussionPhrase_n_ecoute") != null: bouton(host, "DiscussionPhrase_n_ecoute").pressed.emit()
	check(not host.commands.is_empty() and host.commands.back()[1].playerId == "p3", "Discussion adressée au portrait choisi")
	PetiteFenetre.fermer_derniere(self); await settle()
	# « +N » : petite fenêtre de tout le groupe, fermée par le mécanisme commun (Échap), puis choix d'un portrait.
	var tous := bouton(host, "RelationshipAllPortraits")
	check(tous != null and not tous.disabled, "Tuile « +N » cliquable")
	tous.pressed.emit(); await settle()
	var fenetre := host.find_child("RelationshipPortraitsWindow", true, false)
	check(fenetre != null and PetiteFenetre.ouverte(self) == fenetre, "Petite fenêtre du groupe ouverte et inscrite")
	check(fenetre != null and fenetre.find_children("RelationshipPortrait_*", "Button", true, false).size() == 12, "Tout le groupe en portraits")
	check(PetiteFenetre.fermer_derniere(self), "Échap ferme la petite fenêtre")
	await settle()
	check(host.find_child("RelationshipPortraitsWindow", true, false) == null, "Petite fenêtre refermée")
	bouton(host, "RelationshipAllPortraits").pressed.emit(); await settle()
	fenetre = host.find_child("RelationshipPortraitsWindow", true, false)
	var croix := fenetre.find_child("RelationshipPortraitsClose", true, false) as Button if fenetre != null else null
	check(croix != null, "Croix de fermeture")
	if croix != null: croix.pressed.emit()
	await settle()
	check(host.find_child("RelationshipPortraitsWindow", true, false) == null, "La croix ferme la petite fenêtre")
	bouton(host, "RelationshipAllPortraits").pressed.emit(); await settle()
	fenetre = host.find_child("RelationshipPortraitsWindow", true, false)
	var dernier := fenetre.find_child("RelationshipPortrait_p11", true, false) as Button if fenetre != null else null
	if dernier != null: dernier.pressed.emit()
	await settle()
	check(host.management_ui.relationships.playerId == "p11" and host.find_child("RelationshipPortraitsWindow", true, false) == null, "Portrait de la petite fenêtre choisit et ferme")
	check(PetiteFenetre.ouverte(self) == null, "Aucune petite fenêtre restée inscrite")
	# Temps de jeu promis : la pastille d'échéance lit la journée du moteur (promiseLastJourney), « — » si le moteur ne la donne pas ; un clic ouvre le Calendrier.
	var echeance := bouton(host, "RelationshipPromiseDeadline")
	var texte_echeance := (echeance.find_children("*", "Label", true, false)[0] as Label).text if echeance != null else ""
	check(echeance != null and texte_echeance == "J24", "Pastille d'échéance des promesses : J24 d'après le moteur (« %s »)" % texte_echeance)
	host.routes.clear()
	if echeance != null: echeance.pressed.emit()
	check(host.routes == ["Calendrier"], "La pastille d'échéance ouvre le Calendrier")
	host.model.clubLife.relationships.erase("promiseLastJourney")
	host._render(); await settle()
	echeance = bouton(host, "RelationshipPromiseDeadline")
	texte_echeance = (echeance.find_children("*", "Label", true, false)[0] as Label).text if echeance != null else ""
	check(texte_echeance == "—", "Sans donnée du moteur : « — » (jamais un « J24 » écrit en dur)")
	print("VESTIAIRE_CLICS checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
