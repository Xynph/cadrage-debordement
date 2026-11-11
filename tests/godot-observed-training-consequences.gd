extends SceneTree
const Feedback = preload("res://ui/decision_feedback.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message);printerr("FAIL: ",message)
func person(id: String, name: String, condition: float, charge: float, level: float, owned: Variant = true) -> Dictionary:
	var row := {"id":id,"name":name,"condition":condition,"physicalLoad":charge,"rating":level,"potential":99,"potentialRange":{"min":95,"max":99}}
	if owned!=null: row.knowledge={"owned":owned,"stage":"club" if owned==true else "deep"}
	return row
func model(rows: Array, trained: bool = false) -> Dictionary:
	return {"club":{"id":13},"meta":{"mode":"fictional14","season":1,"week":2,"trained":trained,"morale":65},"finance":{"cash":1000,"wage":100},"squad":rows}
func legacy(source: Dictionary) -> Dictionary:
	var result:=source.duplicate(true)
	for row: Dictionary in result.get("squad",[]):row.erase("knowledge")
	return result
func receipt(before: Dictionary, after: Dictionary, mode: String = "normal", ok: bool = true) -> RefCounted:
	var feedback:=Feedback.new()
	feedback.begin("train",{"mode":mode},before)
	feedback.complete("train",ok,after)
	return feedback
func run() -> void:
	var feedback:=Feedback.new()
	var before:=model([person("a","Camille Martin",80,30,60),person("b","Camille Martin",60,50,70),person("opponent","SECRET ADVERSE",0,0,99,false),person("legacy","LEGACY",0,0,99,null),person("dup","Doublon 1",99,99,99),person("dup","Doublon 2",0,0,0)])
	before.market=[person("market","SECRET MARCHÉ",0,0,99)]
	before.decisions={"development":{"academy":[person("academy","SECRET ACADÉMIE",0,0,99)]}}
	var after:=before.duplicate(true)
	after.meta.trained=true
	after.squad[0].condition=82;after.squad[0].physicalLoad=20;after.squad[0].rating=61
	after.squad[1].condition=64;after.squad[1].physicalLoad=40;after.squad[1].rating=71
	after.squad[2].condition=100;after.squad[2].physicalLoad=100;after.squad[2].rating=1
	var before_text:=JSON.stringify(before);var after_text:=JSON.stringify(after)
	var captured: Dictionary=feedback._training_snapshot(before)
	check(not captured.people.has("opponent") and not captured.people.has("legacy") and not captured.people.has("dup"),"Adversaire, legacy non explicite et ID ambigu exclus")
	check(not captured.people.has("market") and not captured.people.has("academy"),"Marché et académie ne deviennent pas l’effectif professionnel observé")
	check(not JSON.stringify(captured).contains("potential") and not JSON.stringify(captured).contains("SECRET"),"La whitelist ne copie ni potentiel ni personnes cachées")
	var observed: Dictionary=feedback._training_changes(captured,after)
	check(observed.lines==["Condition moyenne de 2 joueurs présents avant et après : 70 → 73 %.","Charge moyenne de 2 joueurs présents avant et après : 40 → 30 / 100.","Niveau moyen de 2 joueurs présents avant et après : 65 → 66 / 100."],"Trois comparaisons de mêmes IDs, valeurs publiques exactes et texte naturel")
	check(observed.targets.map(func(item):return item.target.id)==["b","a"],"Deux variations significatives reliées par ID malgré les homonymes")
	check(JSON.stringify(before)==before_text and JSON.stringify(after)==after_text,"Observer ne modifie aucune projection")
	var reordered:=after.duplicate(true);reordered.squad.reverse()
	check(feedback._training_changes(captured,reordered)==observed,"L’ordre des lignes ne change ni comparaison ni cibles")
	var arrivals:=model([person("b","Camille Martin",64,40,71),person("new","Nouvelle recrue",99,0,99)],true)
	var common: Dictionary=feedback._training_changes(captured,arrivals)
	check(common.lines[0]=="Condition moyenne de 1 joueur présent avant et après : 60 → 64 %.","Arrivée et départ ne changent pas le dénominateur des mêmes joueurs")
	check(common.targets.size()==1 and common.targets[0].target.id=="b","Une arrivée n’est pas présentée comme une conséquence de la séance")
	var missing:=after.duplicate(true);missing.squad[0].erase("condition")
	check(feedback._training_changes(captured,missing).lines[0]=="Condition moyenne de 1 joueur présent avant et après : 60 → 64 %.","Valeur manquante exclue sans zéro inventé, effectif comparable indiqué")
	var foreign:=after.duplicate(true);foreign.club.id=7
	check(feedback._training_changes(captured,foreign).lines.is_empty(),"Changement de club sans comparaison trompeuse")
	foreign=after.duplicate(true);foreign.meta.week+=1
	check(feedback._training_changes(captured,foreign).lines.is_empty(),"Autre semaine hors du reçu de cette séance")
	var unowned:=after.duplicate(true)
	for row: Dictionary in unowned.squad:row.knowledge={"owned":false}
	check(feedback._training_changes(captured,unowned).lines.is_empty(),"Aucune ancienne donnée exacte réutilisée après perte de visibilité")
	check(feedback._training_snapshot(legacy(before)).people.is_empty(),"Ancienne projection sans owned explicite : aucun ajout")
	var string_owner:=model([person("text","SECRET OWNER STRING",1,1,99,"true")])
	check(feedback._training_snapshot(string_owner).people.is_empty(),"Le texte true n’autorise pas une connaissance de propriétaire")
	var invalid:=model([person("nan","Valeur absente",NAN,INF,-1),person("range","Hors bornes",101,-1,1000)])
	var invalid_snapshot: Dictionary=feedback._training_snapshot(invalid)
	check(invalid_snapshot.people.nan.size()==1 and invalid_snapshot.people.range.size()==1,"NaN, infini et hors bornes ne sont jamais des mesures")
	check(is_nan(invalid.squad[0].condition) and is_inf(invalid.squad[0].physicalLoad),"Le contrôle des nombres ne répare pas le modèle")
	var tiny:=before.duplicate(true);tiny.meta.trained=true
	tiny.squad[0].condition+=0.000001;tiny.squad[1].condition+=0.000001
	var noise: Dictionary=feedback._training_changes(captured,tiny)
	check(noise.lines.is_empty() and noise.targets.is_empty(),"Même valeur affichée : aucune ligne 0→0 ni lien vers du bruit")
	var unchanged:=before.duplicate(true);unchanged.meta.trained=true
	check(feedback._training_changes(captured,unchanged).lines.is_empty(),"Valeurs stables sans ajout à la séance existante")
	var snapshot_before:=feedback._training_snapshot(before)
	var edited_copy:=before.duplicate(true);edited_copy.squad[0].condition=1
	check(snapshot_before.people.a.condition==80,"Les mesures au vrai envoi sont conservées comme valeurs, sans référence mutable")
	var baseline:=receipt(legacy(before),legacy(after),"intense")
	var enriched:=receipt(before,after,"intense")
	var old: Dictionary=baseline.receipts()[0];var current: Dictionary=enriched.receipts()[0]
	check(current.text.begins_with(old.text+"\n") and current.title==old.title and current.summary==old.summary and current.before==old.before and current.after==old.after,"Coûts, titre, pied de page et préfixe du reçu strictement inchangés")
	check(current.text.trim_prefix(old.text+"\n").split("\n").size()==3 and current.targets.size()==2,"Au plus trois lignes compactes et deux fiches")
	check(not current.text.to_lower().contains("potentiel") and not current.text.to_lower().contains("grâce") and not current.text.to_lower().contains("garanti"),"Aucune fuite de potentiel ou assurance causale")
	check(receipt(before,after,"normal",false).receipts().is_empty(),"Refus réel sans conséquence annoncée")
	var already:=before.duplicate(true);already.meta.trained=true
	check(receipt(already,after).receipts().is_empty(),"Séance déjà appliquée sans second reçu")
	for case: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_OBSERVED_TRAINING_CASES"))).cases:
		var actual_before: Dictionary=case.before;var actual_after: Dictionary=case.after
		var before_json:=JSON.stringify(actual_before);var after_json:=JSON.stringify(actual_after)
		var actual:=receipt(actual_before,actual_after,case.mode,case.ok)
		if case.get("noNewReceipt",false):
			check(actual.receipts().is_empty(),"Worker réel · répétition refusée ou sans effet, aucun reçu ajouté")
			continue
		check(actual.receipts().size()==1,"Worker réel · unique reçu de "+str(case.id))
		if actual.receipts().is_empty():continue
		var value: Dictionary=actual.receipts()[0]
		var old_receipt:=receipt(legacy(actual_before),legacy(actual_after),case.mode,case.ok)
		var old_prefix: String=old_receipt.receipts()[0].text
		var expected_lines: Array[String]=[]
		for metric: Dictionary in case.expected:
			if not metric.visible:continue
			var label: String={"condition":"Condition moyenne","physicalLoad":"Charge moyenne","rating":"Niveau moyen"}[metric.field]
			var ending: String=" %" if metric.field=="condition" else " / 100"
			expected_lines.append("%s de %d joueur%s présent%s avant et après : %s → %s%s." % [label,int(metric.count),"s" if metric.count>1 else "","s" if metric.count>1 else "",metric.beforeText,metric.afterText,ending])
		check(value.text==old_prefix+("\n"+"\n".join(expected_lines) if not expected_lines.is_empty() else ""),"Worker réel · mesures publiques du même groupe exactement rendues · "+str(case.id))
		check(value.targets.size()<=2,"Worker réel · deux cibles au plus · "+str(case.id))
		for target: Dictionary in value.targets:
			check(actual_before.squad.any(func(row):return row.id==target.target.id and row.knowledge.owned==true) and actual_after.squad.any(func(row):return row.id==target.target.id and row.knowledge.owned==true),"Worker réel · chaque cible connue avant ET après · "+str(case.id))
		check(JSON.stringify(actual_before)==before_json and JSON.stringify(actual_after)==after_json,"Worker réel · projections source intactes · "+str(case.id))
	var report: Dictionary={"checks":checks,"failures":failures,"scope":"Godot receipt observations and privacy cases plus actual public worker training alternatives. No new game engine, style, opponent data or exact potential."}
	var output:=OS.get_environment("CD_OBSERVED_TRAINING_OUTPUT")
	var file:=FileAccess.open(output.path_join("godot-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("OBSERVED TRAINING CONSEQUENCES : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
