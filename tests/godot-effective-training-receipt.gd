extends SceneTree
const Feedback = preload("res://ui/decision_feedback.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: ",message)
func model(mode: String, status: String, trained: bool, reason: Variant = null) -> Dictionary:
	return {"club":{"id":13},"meta":{"mode":"fictional14","season":1,"week":2,"training":mode,"trained":trained,"morale":65},"finance":{"cash":1000,"wage":100},"squad":[],
		"clubLife":{"clubSupport":{"context":{"club":13,"season":1,"week":2},"training":{"session":{"status":status,"reason":reason}}}}}
func receipt(before: Dictionary, after: Dictionary, payload: Dictionary = {"mode":"intense"}, ok: bool = true) -> RefCounted:
	var feedback:=Feedback.new();feedback.begin("train",payload,before);feedback.complete("train",ok,after);return feedback
func run() -> void:
	var feedback:=Feedback.new()
	var before:=model("normal","pending",false)
	var quote: String="  « Récupération retenue : raison publiée exactement. »\nDeuxième ligne inchangée.  "
	var after:=model("repos","applied",true,quote)
	var original_before:=JSON.stringify(before);var original_after:=JSON.stringify(after)
	var request: Dictionary=feedback._training_request({"mode":"intense"},before)
	var result: Dictionary=feedback._training_result(request,after)
	check(result.applied=="repos" and result.detail=="Mode collectif appliqué : Repos · choix demandé : Travail intense.","Le repos appliqué précède le choix intense demandé, sans ambiguïté")
	check(result.reason==quote,"Raison publique recopiée mot pour mot, espaces et retours compris")
	check(JSON.stringify(before)==original_before and JSON.stringify(after)==original_after,"Résolution du reçu sans mutation des projections")
	var current: Dictionary=receipt(before,after).receipts()[0]
	check(current.text.begins_with(result.detail+"\n") and current.text.contains("Compte rendu de la séance : "+quote),"Nouveau reçu : mode appliqué et citation exacte, sans acteur inventé")
	check(current.summary.contains("appliqué : Repos") and current.summary.contains("choix demandé : Travail intense"),"Le pied de page ne présente plus l’intense demandé comme appliqué")
	check(current.title=="Séance effectuée" and current.before.cash==1000 and current.after.cash==1000,"Titre et faits financiers conservés")
	var same:=model("normal","applied",true)
	check(receipt(model("normal","pending",false),same,{"mode":"normal"}).receipts()[0].text.begins_with("Mode collectif appliqué : Travail normal."),"Mode demandé égal au mode connu : libellé simple")
	var configured:=model("intense","pending",false)
	check(feedback._training_request({},configured).requested=="intense","Sans champ mode, le réglage public réellement transmis par défaut est retenu")
	check(receipt(configured,after,{}).receipts()[0].text.begins_with("Mode collectif appliqué : Repos · choix demandé : Travail intense."),"La demande implicite n’est pas confondue avec le mode exécuté")
	check(feedback._training_requested_detail("")=="Choix d’entraînement transmis.","Choix non publié : formulation générique")
	var unknown_request: Dictionary=feedback._training_request({"mode":"future-mode"},before)
	check(unknown_request.requested.is_empty(),"Un code mode inconnu n’est pas traduit par devinette")
	var missing:=after.duplicate(true);missing.clubLife.clubSupport.training.erase("session")
	check(feedback._training_result(request,missing).detail=="Choix demandé : Travail intense." and feedback._training_result(request,missing).reason.is_empty(),"Sans session appliquée, seul le choix demandé est affirmé")
	missing=after.duplicate(true);missing.clubLife.clubSupport.training=null
	check(feedback._training_result(request,missing).applied.is_empty(),"Sous-système absent ou null sans erreur ni mode inventé")
	missing=before.duplicate(true);missing.clubLife.clubSupport.training=null
	check(not feedback._training_request({"mode":"intense"},missing).eligible,"Absence de session au départ sans transition fabriquée")
	missing=after.duplicate(true);missing.meta.training="future-mode"
	check(feedback._training_result(request,missing).detail=="Choix demandé : Travail intense." and feedback._training_result(request,missing).reason.is_empty(),"Mode actuel non publié : ni appliqué supposé ni citation d’un état incertain")
	missing=after.duplicate(true);missing.meta.erase("training")
	check(feedback._training_result(request,missing).applied.is_empty(),"Meta sans mode effectif : aucune déduction depuis la raison")
	missing=after.duplicate(true);missing.clubLife.clubSupport.training.session.status="pending"
	check(feedback._training_result(request,missing).applied.is_empty(),"Une prévision en attente ne devient pas un résultat")
	var stale:=after.duplicate(true);stale.clubLife.clubSupport.context.week+=1
	check(feedback._training_result(request,stale).applied.is_empty(),"Contexte public du compte rendu d’une autre semaine refusé")
	stale=before.duplicate(true);stale.clubLife.clubSupport.context.week+=1
	check(not feedback._training_request({"mode":"intense"},stale).eligible,"Contexte incohérent au vrai envoi : pas de réassociation ultérieure")
	for field in ["club","season","week"]:
		stale=after.duplicate(true)
		if field=="club":stale.club.id+=1
		else:stale.meta[field]+=1
		check(feedback._training_result(request,stale).applied.is_empty(),"Contexte de carrière changé : "+field)
	stale=after.duplicate(true);stale.meta.mode="common"
	check(feedback._training_result(request,stale).applied.is_empty(),"Autre univers de carrière, aucun mode appliqué raccordé")
	stale=after.duplicate(true);stale.clubLife.clubSupport.context.club="13"
	check(feedback._training_result(request,stale).applied.is_empty(),"Identifiant de contexte d’un autre type sans coercition ni erreur")
	stale=after.duplicate(true);stale.clubLife.clubSupport.training.session.status=true
	check(feedback._training_result(request,stale).applied.is_empty(),"Statut non textuel sans comparaison de types invalide")
	stale=after.duplicate(true);stale.meta.trained=false
	check(feedback._training_result(request,stale).applied.is_empty(),"Statut applied sans confirmation trained rejeté")
	stale=before.duplicate(true);stale.meta.trained="false"
	check(not feedback._training_request({"mode":"intense"},stale).eligible,"Le texte false ne constitue pas un état de séance en attente")
	var no_reason:=model("repos","applied",true)
	var no_reason_text: String=receipt(before,no_reason).receipts()[0].text
	check(no_reason_text.begins_with("Mode collectif appliqué : Repos") and not no_reason_text.contains("Compte rendu") and not no_reason_text.contains("préparateur"),"Mode connu sans raison/acteur publié : aucun pourquoi inventé")
	no_reason.clubLife.clubSupport.training.session.reason={"role":"SECRET","why":"SECRET"}
	check(feedback._training_result(request,no_reason).reason.is_empty(),"Raison non textuelle non convertie en citation")
	no_reason.clubLife.clubSupport.training.session.reason=" \n\t"
	check(feedback._training_result(request,no_reason).reason.is_empty(),"Raison vide sans bruit supplémentaire")
	# Projection-only counterexamples: the UI must follow the published result,
	# never reimplement the 75% rule or guess from observed physical outcomes.
	var projected:=model("normal","applied",true,"Travail collectif retenu avec une condition moyenne de 75%.")
	projected.squad=[{"id":"low","condition":1,"physicalLoad":100,"knowledge":{"owned":true}}]
	check(feedback._training_result(request,projected).applied=="normal","Borne 75 publiée en projection : aucune règle recalculée à partir du joueur à 1%")
	projected=after.duplicate(true)
	projected.clubLife.clubSupport.training.plans=[{"collective":{"mode":"intense","reason":"PRÉVISION À NE PAS COPIER"}}]
	check(feedback._training_result(request,projected).applied=="repos" and not receipt(before,projected).receipts()[0].text.contains("PRÉVISION"),"La prévision n’écrase jamais le compte rendu réellement appliqué")
	var history:=Feedback.new()
	var archived: Dictionary={"command":"train","title":"Séance effectuée","text":"Travail intense\n« Archive exacte, sans adaptation. »","summary":"Séance effectuée · Travail intense","before":{"cash":900},"after":{"cash":900},"targets":[]}
	history._receipts.append(archived.duplicate(true))
	history.begin("train",{"mode":"intense"},before);history.complete("train",true,after)
	check(history.receipts()[0]==archived,"Les anciens reçus/citations déjà stockés ne sont pas réécrits")
	var stored: Array=history.receipts()
	var changed:=after.duplicate(true);changed.meta.training="normal"
	history.begin("set_delegation",{"key":"training","enabled":false},changed);history.complete("set_delegation",true,changed)
	check(history.receipts()==stored,"Un changement ultérieur de réglage ne réinterprète pas la séance archivée")
	check(receipt(before,after,{"mode":"intense"},false).receipts().is_empty(),"Commande refusée sans compte rendu annoncé")
	check(receipt(after,after).receipts().is_empty(),"Séance déjà appliquée sans nouveau reçu de mode")
	var paid:=after.duplicate(true);paid.finance.cash=900
	var charged: Dictionary=receipt(before,paid).receipts()[0]
	check(charged.text.contains(feedback._metric_line("cash",1000,900)) and charged.before.cash==1000 and charged.after.cash==900,"Coûts réellement reçus conservés avec le nouveau mode")
	var actual_cases: Array=[]
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_EFFECTIVE_TRAINING_CASES")))
	for scenario: Dictionary in fixture.cases:
		var generated:=receipt(scenario.before,scenario.after,{"mode":scenario.requested})
		check(generated.receipts().size()==1,"Commandes publiques · un reçu pour "+str(scenario.id))
		if generated.receipts().is_empty():continue
		var item: Dictionary=generated.receipts()[0]
		var expected: String="Mode collectif appliqué : %s · choix demandé : Travail intense." % Feedback.TRAINING_LABELS[scenario.applied]
		check(item.text.begins_with(expected+"\n"),"Commandes publiques · demande intense distinguée du collectif "+str(scenario.applied))
		check(item.text.contains(str(scenario.after.clubLife.clubSupport.training.session.reason)),"Commandes publiques · raison exacte reçue et affichée")
		check(not item.text.contains("Mode collectif appliqué : Travail intense"),"Commandes publiques · aucun intense déclaré appliqué quand normal/repos l’a remplacé")
		actual_cases.append({"id":scenario.id,"requested":scenario.requested,"applied":scenario.applied,"text":item.text,"summary":item.summary})
	var output:=OS.get_environment("CD_EFFECTIVE_TRAINING_OUTPUT")
	var report: Dictionary={"checks":checks,"failures":failures,"publicCases":actual_cases,"sourceDataSha":fixture.sourceSha,"projectionCasesScope":"Protocol/legacy/stale/boundary counterexamples are synthetic projections, not real condition-threshold runs."}
	var file:=FileAccess.open(output.path_join("godot-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("EFFECTIVE TRAINING RECEIPT : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
