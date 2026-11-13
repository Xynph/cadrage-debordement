extends SceneTree
## Gabi adjoint (guide/gabi_avis.gd) sur de vrais modèles de carrière Monde écrits par godot-gabi-adjoint.cjs.
const Avis = preload("res://guide/gabi_avis.gd")
const Semaine = preload("res://guide/gabi_semaine.gd")
const ROUTES := ["Réception", "Bureau", "Effectif", "Composition", "Préparation", "Recrutement", "Club", "Finances", "Classements", "Formation"]
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _model(name: String) -> Dictionary:
	var path := OS.get_environment("CD_GABI_ADJOINT_MODELES").path_join(name)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "Modèle lisible : " + name)
	return parsed if parsed is Dictionary else {}

func _sentences(text: String) -> int:
	var regex := RegEx.create_from_string("[.!?…](\\s|$)")
	return regex.search_all(text.strip_edges()).size()

func _run() -> void:
	for name in ["creation.json", "apres-match.json"]:
		var model := _model(name)
		if model.is_empty(): continue
		for route: String in ROUTES:
			var avis := Avis.avis(route, model)
			var text := str(avis.get("texte", ""))
			_check(not text.is_empty(), "%s · %s : un avis" % [name, route])
			var count := _sentences(text)
			_check(count >= 1 and count <= 3, "%s · %s : 1 à 3 phrases (%d) : %s" % [name, route, count, text])
			_check(not text.contains("%d") and not text.contains("%s") and not text.contains("{"), "%s · %s : aucun gabarit oublié" % [name, route])
			_check(avis.get("categorie", "") != "" and avis.get("ton", "") in [Avis.POSITIF, Avis.NEUTRE, Avis.NEGATIF], "%s · %s : catégorie et ton de geste" % [name, route])
			_check(Avis.avis(route, model) == avis, "%s · %s : déterministe" % [name, route])
			print("AVIS ", name, " ", route, " : ", text)
	_contexte()
	_composition()
	_recrutement()
	_humeur()
	_semaine()
	print("GABI_ADJOINT %d controles, %d echec%s" % [checks, failures, "s" if failures > 1 else ""])
	quit(1 if failures > 0 else 0)

## L'avis cite l'état réel : adversaire du prochain match au Bureau, joueur le plus fatigué à l'Effectif.
func _contexte() -> void:
	var model := _model("apres-match.json")
	if model.is_empty(): return
	var opponent := Avis.adversaire(model)
	if not opponent.is_empty():
		_check(str(Avis.avis("Bureau", model).texte).contains(opponent) or Avis.serie(model).get("nombre", 0) >= 3, "Bureau : l'adversaire réel est nommé (" + opponent + ")")
	var tired: Dictionary = model.squad[3].duplicate(true)
	var changed := model.duplicate(true)
	for person: Dictionary in changed.squad:
		person.injury = 0
		person.condition = 100.0
	changed.squad[3].condition = 52.0
	var effectif := str(Avis.avis("Effectif", changed).texte)
	_check(effectif.contains(Avis._nom(tired)) and effectif.contains("52 %"), "Effectif : le joueur réellement fatigué est nommé avec sa condition : " + effectif)
	var broke := model.duplicate(true)
	broke.finance.cash = -120000
	_check(str(Avis.avis("Finances", broke).texte).contains("rouge"), "Finances : trésorerie négative signalée")

## Conseil de composition : un titulaire épuisé, un remplaçant éligible frais et en forme -> changement
## proposé, valide pour le moteur (éligible, non blessé), jamais un joueur déjà titulaire ; jeune protégé.
func _composition() -> void:
	var model := _model("apres-match.json")
	if model.is_empty(): return
	var base := Avis.composition(model)
	for change: Dictionary in base.get("action", {}).get("changements", []):
		_check(_valid_change(model, change), "Composition réelle : changement proposé valide " + str(change))
	var slots: Array = model.selection.slots
	var target := -1
	var candidate := ""
	var starters := {}
	for assignment: Dictionary in slots:
		if int(assignment.slot) < 15 and assignment.get("playerId") is String: starters[assignment.playerId] = true
	for assignment: Dictionary in slots:
		if int(assignment.slot) >= 15 or not assignment.get("playerId") is String: continue
		for id: Variant in assignment.get("eligibleIds", []):
			if not starters.has(str(id)): target = int(assignment.slot); candidate = str(id); break
		if target >= 0: break
	_check(target >= 0, "Composition : un poste a un remplaçant éligible")
	if target < 0: return
	var tired := model.duplicate(true)
	var out_id := ""
	for assignment: Dictionary in tired.selection.slots:
		if int(assignment.slot) == target: out_id = str(assignment.playerId)
	for person: Dictionary in tired.squad:
		if str(person.id) == out_id: person.condition = 58.0
		if str(person.id) == candidate: person.condition = 100.0; person.injury = 0; person.age = 27
	var advice := Avis.composition(tired)
	var changes: Array = advice.get("action", {}).get("changements", [])
	_check(changes.any(func(c: Dictionary) -> bool: return int(c.slot) == target), "Composition : le titulaire à 58 % est remplacé : " + str(advice.texte))
	_check(str(advice.get("action", {}).get("libelle", "")) == "Suivre le conseil", "Composition : bouton « Suivre le conseil »")
	_check(str(advice.texte).contains("58 %"), "Composition : l'argument cite la condition réelle : " + str(advice.texte))
	for change: Dictionary in changes:
		_check(_valid_change(tired, change), "Composition : changement valide " + str(change))
	_check(Avis.composition(tired) == advice, "Composition : conseil déterministe")
	_check(changes.size() <= Avis.CHANGEMENTS_MAX, "Composition : deux changements au plus")
	# Un jeune ne remplace un titulaire que pour un écart nettement plus grand (prudence).
	var young := tired.duplicate(true)
	for person: Dictionary in young.squad:
		if str(person.id) == out_id: person.condition = 84.0
		if str(person.id) == candidate: person.age = 19
	var young_changes: Array = Avis.composition(young).get("action", {}).get("changements", [])
	var gain := Avis.valeur(young, _player(young, candidate), _number(young, target)) - Avis.valeur(young, _player(young, out_id), _number(young, target))
	if gain < Avis.SEUIL_JEUNE:
		_check(not young_changes.any(func(c: Dictionary) -> bool: return str(c.playerId) == candidate), "Composition : un jeune de 19 ans n'est pas lancé pour un petit écart")
	# Un blessé n'est jamais proposé.
	var injured := tired.duplicate(true)
	for person: Dictionary in injured.squad:
		if str(person.id) == candidate: person.injury = 3
	_check(not Avis.composition(injured).get("action", {}).get("changements", []).any(func(c: Dictionary) -> bool: return str(c.playerId) == candidate), "Composition : jamais un blessé")

func _player(model: Dictionary, id: String) -> Dictionary:
	return Avis.joueur(model, id)

func _number(model: Dictionary, slot: int) -> int:
	for assignment: Dictionary in model.selection.slots:
		if int(assignment.slot) == slot: return int(assignment.get("positionNumber", slot + 1))
	return slot + 1

func _valid_change(model: Dictionary, change: Dictionary) -> bool:
	for assignment: Dictionary in model.selection.slots:
		if int(assignment.slot) != int(change.slot): continue
		var person := Avis.joueur(model, str(change.playerId))
		var starter := false
		for other: Dictionary in model.selection.slots:
			if int(other.slot) < 15 and str(other.get("playerId", "")) == str(change.playerId): starter = true
		return str(change.playerId) in assignment.get("eligibleIds", []) and not person.is_empty() and not Avis.blesse(person) and not starter
	return false

## Recrutement : jamais d'information cachée (couche connaissance), verdicts argumentés.
func _recrutement() -> void:
	var model := _model("apres-match.json")
	if model.is_empty() or not model.get("market") is Array or model.market.is_empty(): return
	var hidden: Dictionary = {}
	for player: Dictionary in model.market:
		if player.get("knowledge", {}).get("stage", "") == "unobserved": hidden = player.duplicate(true); break
	_check(not hidden.is_empty(), "Recrutement : un joueur non observé sur le marché")
	if not hidden.is_empty():
		hidden.rating = 97
		hidden.potential = 99
		hidden.ratingRange = {"min": 95, "max": 99}
		var avis := Avis.recrutement(model, hidden)
		_check(str(avis.action.get("verdict", "")) == "a_suivre" and str(avis.texte).contains("jamais vu"), "Recrutement : non observé -> à observer : " + str(avis.texte))
		_check(not str(avis.texte).contains("97") and not str(avis.texte).contains("95") and not str(avis.texte).contains("99"), "Recrutement : aucune note cachée citée")
	var pos := str(model.squad[0].pos)
	var average: Variant = Avis._moyenne_poste(model, pos)
	_check(average != null, "Recrutement : moyenne de l'effectif au poste")
	if average == null: return
	var good: Dictionary = (model.market[0] as Dictionary).duplicate(true)
	good.pos = pos; good.available = true; good.age = 26; good.salary = 900; good.maxYears = 3; good.minYears = 1
	good.knowledge = {"version": 1, "owned": false, "stage": "observed", "observedAt": null}
	good.ratingRange = {"min": int(average) + 5, "max": int(average) + 8}
	good.potentialRange = null
	var rich := model.duplicate(true)
	rich.clubLife.clubStrategy.finance.weeklyIncome = 400000
	rich.decisions.recruitment.places = 2
	var fonce := Avis.recrutement(rich, good)
	_check(str(fonce.action.get("verdict", "")) == "fonce" and str(fonce.texte).contains("an"), "Recrutement : renfort au-dessus de la moyenne -> offre suggérée : " + str(fonce.texte))
	var full := rich.duplicate(true)
	full.decisions.recruitment.places = 0
	_check(str(Avis.recrutement(full, good).action.get("verdict", "")) == "passe", "Recrutement : effectif plein -> passe ton chemin")
	var costly := good.duplicate(true)
	costly.salary = 300000
	var heavy := Avis.recrutement(rich, costly)
	_check(str(heavy.action.get("verdict", "")) == "passe" and str(heavy.texte).contains("trop lourd"), "Recrutement : salaire hors marge -> passe : " + str(heavy.texte))
	var weak := good.duplicate(true)
	weak.ratingRange = {"min": maxi(1, int(average) - 12), "max": maxi(2, int(average) - 9)}
	_check(str(Avis.recrutement(rich, weak).action.get("verdict", "")) == "passe", "Recrutement : plus faible que l'effectif -> passe")

func _humeur() -> void:
	var model := _model("apres-match.json")
	if model.is_empty(): return
	var dernier := Avis.dernier_resultat(model)
	_check(not dernier.is_empty(), "Humeur : dernier résultat du club lu dans l'historique")
	var humeur := Avis.humeur(model)
	_check(humeur.ton == {"victoire": Avis.POSITIF, "defaite": Avis.NEGATIF, "nul": Avis.NEUTRE}.get(dernier.get("issue", ""), ""), "Humeur : ton conforme au résultat")
	var crisis := model.duplicate(true)
	crisis.meta.trust = 20
	_check(Avis.crise(crisis), "Crise : confiance des dirigeants sous 30")
	var final := model.duplicate(true)
	if final.get("next") is Dictionary:
		final.next.label = "Finale"
		_check(Avis.finale(final), "Finale : prochain match « Finale »")
		final.next.label = "Demi-finale"
		_check(not Avis.finale(final), "Finale : une demi-finale n'est pas une finale")

## Au Bureau, Gabi commente la semaine (gabi_semaine.gd) : prochain match, groupe, alerte, conseil avec action.
func _semaine() -> void:
	for name in ["creation.json", "apres-match.json"]:
		var model := _model(name)
		if model.is_empty(): continue
		var synthese := Semaine.synthese(model)
		var lignes: Array = synthese.get("lignes", [])
		_check(lignes.map(func(l: Dictionary) -> String: return str(l.cle)) == ["match", "groupe", "alerte"], "%s · semaine : trois lignes (match, groupe, alerte)" % name)
		for ligne: Dictionary in lignes:
			var text := str(ligne.get("texte", ""))
			_check(not text.is_empty() and not text.contains("%d") and not text.contains("%s"), "%s · semaine %s : texte complet : %s" % [name, ligne.cle, text])
			_check(_sentences(text) >= 1 and _sentences(text) <= 2, "%s · semaine %s : une ou deux phrases" % [name, ligne.cle])
			print("SEMAINE ", name, " ", ligne.cle, " : ", text)
		var conseil: Dictionary = synthese.get("conseil", {})
		_check(not str(conseil.get("texte", "")).is_empty() and str(conseil.get("action", {}).get("libelle", "")) == "Suivre le conseil", "%s · semaine : conseil avec « Suivre le conseil »" % name)
		print("SEMAINE ", name, " conseil : ", conseil.get("texte", ""), " -> ", conseil.get("action", {}).get("route", conseil.get("action", {}).get("type", "")))
		_check(Semaine.synthese(model) == synthese, "%s · semaine : déterministe" % name)
		_check(str(conseil.get("texte", "")).length() <= 220, "%s · semaine : conseil assez court pour le carnet (%d)" % [name, str(conseil.get("texte", "")).length()])
		var fixture := Semaine.prochain_match(model)
		if not fixture.is_empty():
			var own: Variant = model.club.id
			var opponent: Dictionary = fixture.away if fixture.get("home", {}).get("id") == own else fixture.home
			_check(str(lignes[0].texte).contains(Avis.G.club_name(opponent)), "%s · semaine : l'adversaire réel est nommé : %s" % [name, lignes[0].texte])
	var model := _model("apres-match.json")
	if model.is_empty(): return
	var broke := model.duplicate(true)
	broke.finance.cash = -250000
	broke.meta.calendarCadence = {"matchReady": false}
	var rouge := Semaine.synthese(broke)
	_check(str(rouge.lignes[2].texte).contains("rouge") and str(rouge.conseil.action.get("route", "")) == "Finances", "Semaine : trésorerie négative -> alerte et conseil vers les finances")
	var infirmerie := model.duplicate(true)
	for i in 4: infirmerie.squad[i].injury = 3
	_check(str(Semaine.synthese(infirmerie).lignes[2].texte).contains("blessés"), "Semaine : infirmerie pleine -> alerte")
