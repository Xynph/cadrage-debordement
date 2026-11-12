extends SceneTree
const Relationships = preload("res://ui/relationships_view.gd")
const Feedback = preload("res://ui/decision_feedback.gd")
var checks := 0
var failures: Array[String] = []

class ReadingNavigation extends Node:
	var known: Array[String] = ["a","b"]
	var opened: Array = []
	var sources: Array = []
	func entity_available(target: Dictionary) -> bool: return str(target.get("id","")) in known
	func open_entity(target: Dictionary, source: Window = null) -> bool:
		if not entity_available(target): return false
		opened.append(target.duplicate(true)); sources.append(source)
		return true

class Reader extends Control:
	var model: Dictionary = {}
	var management_ui: Dictionary = {}
	var navigation_controller: Node
	var accent := Color("6f9ac9")
	var commands := 0
	func _command(_name: String, _payload: Dictionary) -> void: commands += 1

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 4: await process_frame
func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.pressed=down
		root.push_input(event,true); await process_frame
	await settle()
func sample() -> Dictionary:
	var person := {"id":"a","name":"Camille Martin","pos":"Centre","score":60,"condition":90,"injury":0,"minutes":30,"loadPlan":"normal","conversationAvailable":false,"promiseAvailable":false,"promiseHistory":[]}
	var other := person.duplicate(true); other.id="b"
	return {"meta":{"morale":65},"finance":{"cash":1000,"wage":100},"squad":[person,other],
		"clubLife":{"relationships":{"active":true,"context":{"season":1,"week":1,"club":0},"players":[person.duplicate(true),other.duplicate(true)],"leaderId":"a","conversations":[],"duoActions":[],"pairs":[{"a":"a","b":"b","score":18}],"commitments":[{"playerId":"a","status":"open","target":60,"dueWeek":3},{"playerId":"gone","status":"expired","target":60,"dueWeek":2}],"conversationHistory":[],"promiseOptions":[],"history":[{"playerId":"a","season":1,"week":0,"title":"« Ses mots, exactement. »","choice":"ecouter"},{"playerId":"gone","season":1,"week":0,"title":"Archive du joueur parti","choice":"cadrer"}],"event":{"key":"event:one","playerId":"a","title":"Un entretien précis","context":"Contexte exact, sans réécriture.","trait":"Loyal","leadership":70,"choices":[],"available":true}}}}
func labels(node: Node) -> String:
	var result := str(node.text)+"\n" if node is Label else ""
	for child in node.get_children(): result += labels(child)
	return result
func run() -> void:
	root.size=Vector2i(1280,720)
	root.gui_embed_subwindows=true
	var app := Reader.new(); root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.navigation_controller=ReadingNavigation.new(); app.add_child(app.navigation_controller)
	app.model=sample(); app.management_ui={"relationships":{"playerId":"a"}}
	var original := JSON.stringify(app.model)
	var page := Relationships.build(app); app.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); await settle()
	for id in ["RelationshipPlayerLink","RelationshipPortraitLink","RelationshipEventPlayerLink","RelationshipCommitmentPlayerLink","RelationshipHistoryPlayerLink","RelationshipLeaderPlayerLink","RelationshipDuoPlayerALink","RelationshipDuoPlayerBLink"]:
		var button := page.find_child(id,true,false) as Button
		check(button!=null,"Lien du vestiaire rendu : "+id)
		if button!=null:
			check(button.focus_mode==Control.FOCUS_ALL and not button.accessibility_name.is_empty(),"Accès clavier et libellé : "+id)
			button.pressed.emit()
			check(app.navigation_controller.opened.back().id==("b" if id=="RelationshipDuoPlayerBLink" else "a"),"Identifiant exact malgré les homonymes : "+id)
	check(labels(page).contains("« Ses mots, exactement. »"),"Citation archivée mot pour mot")
	check(not page.find_children("*","Button",true,false).any(func(button): return button.get_meta("entity_id","")=="gone"),"Le joueur parti n’a aucun lien vers un homonyme")
	check(JSON.stringify(app.model)==original and app.commands==0,"Construire et lire ne modifie ni modèle ni métier")
	app.remove_child(page); page.queue_free(); await settle()
	# A stale history ID stays archived even if the navigation stub itself would
	# accept it; the squad membership check must precede that controller call.
	app.navigation_controller.known.append("gone")
	check(Relationships._player_target(app,"gone").is_empty(),"Aucune fiche extrapolée pour un départ absent de la projection")
	var feedback := Feedback.new(); feedback.setup(app)
	var after := app.model.duplicate(true)
	after.squad[0].loadPlan="repos"
	feedback.begin("set_player_load",{"playerId":"a","mode":"repos"},app.model)
	feedback.complete("set_player_load",true,after)
	var receipt: Dictionary=feedback.receipts().back()
	check(receipt.targets.size()==1 and receipt.targets[0].target=={"kind":"player","id":"a"},"Le reçu retient l’ID du vrai envoi, sans recherche sur le nom")
	check(feedback._targets("relationship_duo",{"a":"a","b":"b"},app.model).map(func(item):return item.target.id)==["a","b"],"Deux partenaires distincts conservés")
	check(feedback._targets("locker_room_decision",{"eventKey":"wrong"},app.model).is_empty(),"Événement périmé sans cible inventée")
	check(feedback._targets("locker_room_decision",{"eventKey":"event:one"},app.model)[0].target.id=="a","Événement relié seulement par sa clé exacte")
	check(feedback._targets("train",{},app.model).is_empty(),"Décision globale sans dossier inventé")
	check(feedback._targets("extend_contract",{"playerId":"a"},app.model)[0].target.section=="contract","Contrat ciblé dans sa section")
	var with_talk := app.model.duplicate(true)
	with_talk.clubLife.clubSupport={"agents":{"talks":[{"key":"talk:exact","id":"b","status":"ready"}]}}
	check(feedback._targets("agent_confirm",{"key":"talk:exact"},with_talk)[0].target.id=="b","Accord agent résolu par clé exacte")
	check(feedback._targets("agent_confirm",{"key":"talk:absent"},with_talk).is_empty(),"Accord agent absent sans cible devinée")
	var text_before: String=receipt.text
	feedback._open(); await settle()
	var dialog := app.get_node_or_null("DecisionFeedbackDialog") as AcceptDialog
	check(dialog!=null and dialog.get_meta("navigation_read_only",false),"Fenêtre de reçus déclarée lecture seule")
	if dialog!=null:
		var link := dialog.find_child("DecisionReceiptPlayerLink",true,false) as Button
		check(link!=null and link.get_meta("entity_id")=="a","Bouton de reçu rendu vers l’ID d’origine")
		check(labels(dialog).contains(text_before),"Texte du reçu conservé intégralement à côté du lien")
		await key(KEY_TAB)
		check(link!=null and link.has_focus(),"Tab atteint le premier lien après FERMER")
		await key(KEY_ENTER)
		check(app.navigation_controller.opened.back().id=="a" and app.navigation_controller.sources.back()==dialog,"Clavier transmet la fiche et sa fenêtre source à la garde commune")
		dialog.queue_free(); await settle()
	app.navigation_controller.known.erase("a")
	feedback._open(); await settle()
	dialog=app.get_node_or_null("DecisionFeedbackDialog") as AcceptDialog
	check(dialog!=null and dialog.find_child("DecisionReceiptPlayerLink",true,false)==null,"Un reçu reste lisible quand son ancienne destination n’est plus disponible")
	check(feedback.receipts().back().text==text_before and app.commands==0,"Les liens ne réécrivent jamais le reçu et ne lancent aucune commande")
	if dialog!=null: dialog.queue_free()
	app.queue_free(); await settle()
	var report := {"checks":checks,"failures":failures,"scope":"Isolated existing Godot page and receipt controls, exact-ID contracts; common controller modal return tested separately."}
	var output := OS.get_environment("CD_MANAGEMENT_READING_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	print("MANAGEMENT READING LINKS : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
