extends SceneTree
var failures: Array[String] = []
var checks := 0
var calls := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ",message)
func run() -> void:
	root.gui_embed_subwindows = true
	var implementation: Script = load("res://ui/decision_preview.gd")
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_DECISION_PREVIEW06").path_join("cases.json")))
	for case: Dictionary in cases:
		var original := JSON.stringify(case.model)
		var detail: Dictionary = implementation.describe(case.command,case.payload,case.model)
		check(JSON.stringify(case.model)==original,"Consultation pure "+case.command)
		if case.get("empty",false):
			check(detail.is_empty(),"Pas de montant inventé "+case.command)
			continue
		check(not detail.is_empty(),"Devis disponible "+case.command)
		if detail.is_empty(): continue
		check(detail.amount==case.amount and detail.direction==case.direction,"Sens et montant réels "+case.command)
		if case.has("recurring"):check(detail.recurring_amount==case.recurring,"Engagement récurrent "+case.command)
		check(not str(detail.caution).is_empty(),"Contrepartie ou incertitude explicite "+case.command)
		if case.command=="club_academy_investment":check(str(detail.later).contains("séance"),"Coût à la séance, pas à la confirmation")
	var model: Dictionary = cases[2].model
	var detail: Dictionary = implementation.describe(cases[2].command,cases[2].payload,model)
	var host := Control.new();root.add_child(host)
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		root.size=resolution;root.content_scale_size=Vector2i.ZERO
		var d: ConfirmationDialog = implementation.open(host,"Engager le club","Financer un projet d’organisation pour le club ?",detail,func():calls+=1)
		for frame in 6:await process_frame
		check(calls==0,"Ouvrir un devis n'applique aucune décision")
		check(d.size.x<=resolution.x and d.size.y<=resolution.y,"Confirmation contenue "+str(resolution))
		var body: Control = d.get_node("DecisionPreviewBody")
		check(body.size.x<=d.size.x and body.size.y<d.size.y,"Faits dans le dialogue "+str(resolution))
		check(d.get_ok_button().is_visible_in_tree() and d.get_cancel_button().is_visible_in_tree(),"Deux choix visibles")
		d.canceled.emit();await process_frame
	check(calls==0,"Annuler ne transmet aucune commande")
	var d: ConfirmationDialog = implementation.open(host,"Valider","Projet",detail,func():calls+=1)
	await process_frame;d.confirmed.emit();await process_frame
	check(calls==1,"Une confirmation déclenche une seule décision")
	host.queue_free();await process_frame
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
