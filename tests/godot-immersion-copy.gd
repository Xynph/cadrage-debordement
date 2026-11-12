extends SceneTree
const Copy = preload("res://ui/management_copy.gd")
const Reception = preload("res://ui/immersive08/reception_canvas.gd")
class Host extends Control:
	const Immersive = preload("res://ui/immersive08/shell.gd")
	var model: Dictionary = {}
var checks := 0
var failures: Array[String] = []
func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures.append(text); printerr("FAIL ", text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var first := "Émile fictif rejoint Généré Rugby après concurrence entre 3 club(s), pour 80 000 € (accord fictif)."
	var second := "Mathis généré rejoint Les Fictifs depuis Le Club fictif : accord fictif de 250 000 €, fin de contrat S3."
	var plain := "Le capitaine fictif dit : accord fictif de prudence, fin de contrat Sincertaine."
	check(Copy.news(first) == "Émile fictif rejoint Généré Rugby après concurrence entre 3 club(s), pour 80 000 €.", "competition template, player and club names preserved")
	check(Copy.news(second) == "Mathis généré rejoint Les Fictifs depuis Le Club fictif : accord de 250 000 €, fin de contrat S3.", "direct template, amount and contract preserved")
	check(Copy.news(plain) == plain, "ordinary quote not rewritten")
	check(Copy.news("« " + first + " »") == "« " + first + " »", "quoted template not rewritten")
	check(Copy.news(first.replace("80 000 €", "une somme")) == first.replace("80 000 €", "une somme"), "non canonical amount left untouched")
	var host := Host.new(); root.add_child(host)
	host.model = {"messages":[first,second,plain],"calendarMail":[]}
	var before := JSON.stringify(host.model)
	var rows: Array = Reception._messages(host)
	for original: String in host.model.messages:
		var id := original.sha256_text() + "-1"
		check(rows.any(func(row: Dictionary): return row.id == id and row.text == Copy.news(original)), "message retains original ID and adapted rendering")
	check(JSON.stringify(host.model) == before, "saved text and model remain unchanged")
	var scouting := Copy.notice("scouting", "Agents libres majeurs issus des centres ou du bassin abstrait des petits clubs. Une shortlist ne réserve pas le joueur. Mission existante : 5 000 € fictifs, deux journées de travail, tous agents libres répondant aux critères. Les intervalles datés restent des estimations, pas une garantie de progression.")
	check(scouting.contains("5 000 €") and scouting.contains("deux journées") and scouting.contains("estimations") and not scouting.contains("fictif"), "scouting cost duration and uncertainty retained")
	var interclub := Copy.notice("interclub", "Accord de libération anticipée fictif. Indemnité intégralement versée au club vendeur ; salaire proposé +5 % (minimum 1 000 €/semaine), échéance conservée. Réserve de 400 000 € et provision des huit prochaines semaines du nouveau salaire ; aucune inscription réglementaire automatique.")
	check(interclub.contains("+5 %") and interclub.contains("400 000 €") and interclub.contains("huit prochaines semaines") and interclub.contains("aucune inscription réglementaire automatique"), "market financial and regulatory limits retained")
	var support := Copy.notice("support", "Arbitrages fictifs du jeu. Le suivi médical générique ne représente ni une commotion, ni un protocole HIA, ni un avis de santé. Les budgets sont fictifs.")
	check(support.contains("commotions") and support.contains("HIA") and not support.contains("fictif"), "medical coverage limit retained")
	host.free()
	print("IMMERSION_COPY_PROBE ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
