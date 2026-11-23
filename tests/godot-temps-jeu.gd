extends SceneTree
## Fiche joueur › Contrat : temps de jeu promis (revue FM27, idée 16, choix A de Léo du 23/11/2026), sur un modèle factice.
## Colonne Temps de jeu : rôle promis (mot + couleur commune ui/role_contrat.gd), exigence en chiffres, mesure (moyenne /
## seuil, matchs joués pour un Espoir), humeur, 10 pastilles (tenu / manqué / absent), liste des matchs. Prolongation : ligne
## « Rôle promis » avec la demande de chaque rôle ; un clic l'applique (pas de bouton Valider), la proposition suit la
## demande ; rôle refusé barré, sans clic. Plus de variante CD_VARIANTE_VISUELLE.
const TempsJeu = preload("res://ui/immersive08/fiche_temps_jeu.gd")
const Prolongation = preload("res://ui/prolongation_visuelle.gd")
const Offre = preload("res://ui/offre_visuelle.gd")
const Role = preload("res://ui/role_contrat.gd")
const Salary = preload("res://ui/salary_display.gd")
const D = preload("res://ui/immersive08/primitives.gd")

class FakeApp extends Control:
	var model: Dictionary = {}
	var management_ui := {"immersive_player_tab": 3}
	var rendus := 0
	var waiting := false
	var navigation_controller: Object = null
	func _live() -> Dictionary: return {}
	func render() -> void: rendus += 1
	func _render(_complet: bool = true) -> void: rendus += 1
	func _command(_command: String, _payload: Dictionary = {}, _target_route: String = "") -> bool: return true
	func _navigate(_route: String, _a: bool = false, _b: bool = false) -> void: pass

var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)

func settle(frames: int = 4) -> void:
	for i in frames: await process_frame

func pastilles(minutes: Array, etats: Array) -> Array:
	var out := []
	for i in minutes.size(): out.append({"saison": 1, "semaine": i + 1, "adversaireId": 3, "adversaire": "Severn Crown XV", "minutes": minutes[i], "etat": etats[i]})
	return out

func joueur(tj: Dictionary) -> Dictionary:
	return {"id": "p1", "name": "Alasdair McCulloch", "pos": "Centre", "fam": 7, "age": 26, "rating": 70, "contractEnd": 1, "salary": 6000, "minutes": 427, "appearances": 6,
		"portraitIndex": 0, "roleContrat": {"role": tj.role, "deduit": tj.deduit, "saison": 1}, "tempsJeu": tj,
		"renewal": {"available": true, "salary": 6200, "fee": 12000, "minYears": 2, "maxYears": 3,
			"roles": {"attendu": "rotation", "liste": [
				{"role": "titulaire", "salary": 6500, "refus": ""}, {"role": "rotation", "salary": 6200, "refus": ""},
				{"role": "espoir", "salary": 6000, "refus": "Espoir : 21 ans et moins."}, {"role": "appoint", "salary": 6000, "refus": ""}]}}}

func colonne(app: FakeApp, player: Dictionary) -> Panel:
	var card := Panel.new()
	card.size = Vector2(756, 900)
	app.add_child(card)
	TempsJeu.temps(card, app, player, 756)
	await settle()
	return card

func texte(noeud: Node, nom: String) -> String:
	var n := noeud.find_child(nom, true, false)
	return (n as Label).text if n is Label else ""

func run() -> void:
	root.size = Vector2i(1920, 1080)
	var app := FakeApp.new()
	app.model = {"meta": {"season": 1}, "squad": []}
	root.add_child(app)
	# Rotation promise, 6 matchs comptés dont 2 absents : moyenne 38′ / 20′ (content).
	var tj := {"role": "rotation", "deduit": false, "saison": 1, "seuil": 20, "part": null, "juges": 6, "joues": 4, "moyenne": 38, "humeur": "content",
		"pastilles": pastilles([25, 0, 0, 81, 75, 0, 82, 0], ["tenu", "manque", "absent", "tenu", "tenu", "manque", "tenu", "absent"])}
	var player := joueur(tj)
	app.model.squad = [player]
	var card := await colonne(app, player)
	var titre := card.find_child("TempsJeuRole", true, false) as Label
	check(titre != null and titre.text == "ROTATION" and titre.get_theme_color("font_color") == Role.couleur("rotation"), "Rôle promis : ROTATION en violet")
	var exigence := card.find_child("TempsJeuExigence", true, false)
	check(exigence != null and str((exigence.get_child(0) as Label).text) == "20′ de moyenne", "Exigence de la rotation : 20′ de moyenne")
	var origine := card.find_child("TempsJeuOrigine", true, false)
	check(origine != null and str((origine.get_child(0) as Label).text).begins_with("Promis"), "Rôle promis à la signature")
	check(texte(card, "TempsJeuMesure") == "38′ / 20′", "Mesure : moyenne / seuil")
	check(card.find_child("TempsJeuHumeurLien", true, false) is Button, "Satisfaction cliquable")
	# 10 emplacements : les 2 premiers vides (8 matchs), puis les états du moteur.
	var etats := []
	for k in 10: etats.append((card.find_child("TempsJeuPastille" + str(k), true, false)).etat)
	check(etats == ["neutre", "neutre", "tenu", "manque", "absent", "tenu", "tenu", "manque", "tenu", "absent"], "Pastilles : %s" % [etats])
	check(card.find_child("TempsJeuPastilleLien2", true, false) is Button and card.find_child("TempsJeuPastilleLien0", true, false) == null, "Pastille d'un match cliquable, emplacement vide non")
	check(card.find_child("TempsJeuMatch7", true, false) != null and card.find_child("TempsJeuMatch8", true, false) == null, "Liste : un rang par match")
	var etat0 := card.find_child("TempsJeuEtat0", true, false)
	check(etat0 != null and str((etat0.get_child(0) as Label).text) == "Absent", "Dernier match en tête : Absent")
	(card.find_child("TempsJeuPastilleLien2", true, false) as Button).pressed.emit()
	check(app.management_ui.immersive_player_tab == 2 and app.rendus == 1, "Clic sur un match : onglet Performances")
	card.queue_free()
	# Espoir déduit de la hiérarchie : matchs joués / comptés ; Appoint : pas de mesure.
	var espoir := {"role": "espoir", "deduit": true, "saison": null, "seuil": null, "part": 0.25, "juges": 8, "joues": 1, "moyenne": 5, "humeur": "attentif", "pastilles": pastilles([0, 12], ["neutre", "tenu"])}
	card = await colonne(app, joueur(espoir))
	check(texte(card, "TempsJeuMesure") == "1 / 8", "Espoir : matchs joués / comptés")
	check(str((card.find_child("TempsJeuOrigine", true, false).get_child(0) as Label).text) == "Hiérarchie au poste", "Rôle déduit : hiérarchie au poste")
	check((card.find_child("TempsJeuRole", true, false) as Label).get_theme_color("font_color") == Role.couleur("espoir"), "Espoir en turquoise")
	card.queue_free()
	card = await colonne(app, joueur({"role": "appoint", "deduit": true, "seuil": null, "part": null, "juges": 0, "joues": 0, "moyenne": 0, "humeur": "neutre", "pastilles": []}))
	check(texte(card, "TempsJeuMesure") == "—", "Appoint : sans exigence")
	card.queue_free()
	# Colonnes Contrat et Primes : rôle et exigence en mots du jeu, couleur commune.
	var contrat := Panel.new()
	app.add_child(contrat)
	TempsJeu.primes(contrat, app, player, 730, 64, 84)
	await settle()
	var temps := contrat.find_child("TempsJeuPrime0", true, false)
	check(temps != null, "Primes : ligne temps de jeu promis")
	var valeurs := []
	for l in temps.find_children("*", "Label", true, false): valeurs.append((l as Label).text)
	check("Rotation · 20′ de moyenne" in valeurs, "Primes : « Rotation · 20′ de moyenne » (%s)" % [valeurs])
	contrat.queue_free()
	# Prolongation : ligne Rôle promis, demande de chaque rôle, clic = appliqué.
	var body := VBoxContainer.new()
	app.add_child(body)
	var salary := SpinBox.new()
	salary.max_value = 100000
	salary.step = 100
	Salary.set_input_weekly(salary, 6200)
	var years := SpinBox.new()
	years.min_value = 2
	years.max_value = 3
	years.value = 2
	var ctx := {"app": app, "player": player, "quote": player.renewal, "salary": salary, "years": years, "first_season": 1, "negotiation": {}, "phase": {"action": "Proposer", "blocked": false, "progress": ""}, "reuse": Button.new(), "prolongation": true}
	Prolongation.construire(body, ctx)
	await settle()
	check(str(ctx.get("role", "")) == "rotation", "Rôle proposé : celui de la hiérarchie (rotation)")
	check(Offre.valeurs(ctx).demande == 6200, "Demande : celle de la rotation")
	check(body.find_child("ProlongationRoleLien_titulaire", true, false) is Button, "Titulaire cliquable")
	check(body.find_child("ProlongationRoleLien_espoir", true, false) == null, "Espoir refusé : pas de clic")
	var bulle := body.find_child("ProlongationRole_espoir", true, false) as Control
	check(bulle != null and bulle.tooltip_text.contains("21 ans"), "Espoir refusé : raison en infobulle")
	(body.find_child("ProlongationRoleLien_titulaire", true, false) as Button).pressed.emit()
	await settle()
	check(str(ctx.role) == "titulaire", "Clic sur Titulaire : appliqué sans confirmation")
	check(Salary.input_weekly(salary) == 6500 and Offre.valeurs(ctx).demande == 6500, "Proposition et demande suivent le titulaire (6 500)")
	# Proposition modifiée à la main : un autre rôle ne l'écrase plus.
	Salary.set_input_weekly(salary, 7000)
	await settle()
	(body.find_child("ProlongationRoleLien_appoint", true, false) as Button).pressed.emit()
	await settle()
	check(str(ctx.role) == "appoint" and Salary.input_weekly(salary) == 7000 and Offre.valeurs(ctx).demande == 6000, "Proposition gardée, demande de l'appoint")
	body.queue_free()
	print("TEMPS_JEU ", checks, " controles, ", failures.size(), " echec", "s" if failures.size() > 1 else "")
	quit(1 if failures.size() > 0 else 0)
