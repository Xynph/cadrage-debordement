extends SceneTree
const Salary = preload("res://ui/salary_display.gd")
const Prefs = preload("res://ui/user_preferences.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var directory := OS.get_environment("CD_SALARY_TEST_DIR")
	check(Salary.configure("weekly"),"Hebdomadaire reconnu")
	check(Salary.format(1000)=="1 000 € /sem.","Montant hebdomadaire")
	check(Salary.configure("monthly") and Salary.format(1000)=="4 300 € /mois","Mensuel selon52/12")
	check(Salary.amount(8780)=="38 000 €","Exemple mensuel 38046,67 arrondi à 38000")
	check(Salary.configure("annual") and Salary.format(1000)=="52 000 € /an","Annuel selon52")
	check(Salary.amount(1009)=="52 500 €","Annuel arrondi à la centaine la plus proche")
	check(Salary.amount(1)=="100 €","Petit montant arrondi à la centaine")
	check(Salary.amount(-1)=="−100 €","Écart négatif arrondi symétriquement")
	check(Salary.amount(0)=="0 €","Zéro sans signe négatif ni décimales")
	check(Salary.amount(null)=="—","Absent reste absent")
	check(Salary.format(-1000)=="−52 000 € /an","Écart salarial négatif")
	check(not Salary.configure("invalid") and Salary.period=="annual","Choix invalide ne change pas unité")
	var spin := SpinBox.new();root.add_child(spin)
	for weekly in [1000,3497,8780,100000]:
		for period in Salary.PERIODS:
			Salary.configure(period)
			Salary.bind_input(spin,weekly,1000,100000)
			check(Salary.input_weekly(spin)==weekly,"Aller-retour exact sans édition "+str(weekly)+period)
			Salary.set_input_weekly(spin,weekly+0 if weekly<100000 else weekly)
			check(Salary.input_weekly(spin)==weekly,"Copie contre-offre exacte "+period)
	Salary.configure("monthly");Salary.bind_input(spin,1000,1000,100000)
	spin.value=10000
	check(Salary.input_weekly(spin)==2308,"Édition mensuelle arrondie en euros hebdomadaires")
	Salary.configure("annual");Salary.bind_input(spin,1000,1000,100000)
	spin.value=520000
	check(Salary.input_weekly(spin)==10000,"Édition annuelle vers montant moteur")
	var preference := Prefs.new()
	check(preference.load_profile(directory),"Chargement préférences temporaires")
	var legacy: Dictionary=Prefs.DEFAULTS.duplicate(true);legacy.erase("salary_period")
	check(preference._validated(legacy).salary_period=="weekly","Fichier antérieur sans unité compatible")
	check(preference.set_value("salary_period","monthly"),"Enregistrement mensuel : "+preference.last_error)
	var original := FileAccess.get_file_as_bytes(directory.path_join("interface.json"))
	var reopened := Prefs.new()
	check(reopened.load_profile(directory) and reopened.data.salary_period=="monthly" and Salary.period=="monthly","Choix retrouvé à réouverture")
	check(not reopened.set_value("salary_period","bad"),"Préférence invalide refusée")
	check(FileAccess.get_file_as_bytes(directory.path_join("interface.json"))==original and Salary.period=="monthly","Refus conserve fichier et affichage")
	check(DirAccess.make_dir_absolute(directory.path_join("interface.json.tmp"))==OK,"Obstacle écriture réel")
	check(not reopened.set_value("salary_period","annual"),"Écriture impossible refusée")
	check(reopened.data.salary_period=="monthly" and Salary.period=="monthly" and FileAccess.get_file_as_bytes(directory.path_join("interface.json"))==original,"Échec écriture sans bascule silencieuse")
	DirAccess.remove_absolute(directory.path_join("interface.json.tmp"))
	var bad: Dictionary=Prefs.DEFAULTS.duplicate(true);bad.salary_period=52
	check(preference._validated(bad).is_empty(),"Type numérique invalide refusé")
	spin.queue_free();await process_frame
	Salary.configure("weekly")
	print("AFFICHAGE SALAIRES : %d contrôles ; %d échecs" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
