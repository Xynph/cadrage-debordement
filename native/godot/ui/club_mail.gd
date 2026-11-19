extends RefCounted
## Courrier du club (moteur : native/engine/club-mail.cjs, données club-mail.json). Les mails sont rangés dans la
## Réception avec les autres courriers ; ceux qui appellent une réponse portent des boutons de réponse (commande
## `club_mail_reply`, affichée tout de suite par ui/optimistic_decisions.gd) et chacun un bouton vers l'écran
## concerné. Les arrêts informatifs de « Continuer » ouvrent directement l'écran utile (veille de match :
## composition ; rapport médical : infirmerie ; mi-saison et fin de phase : classement ; marché : recrutement ;
## recruteur : fiche du joueur ; courrier : le mail en Réception).
const U = preload("res://ui/management_state.gd")

## Catégorie du moteur -> rubrique de la Réception (filtres, icônes et couleurs existants).
const CATEGORY := {"infirmerie":"Médical", "commotion":"Médical", "vestiaire":"Staff", "staff":"Staff", "recrutement":"Recrutement", "presse":"Club", "direction":"Direction", "contrats":"Direction", "competition":"Compétitions", "formation":"Formation", "moments":"Club", "meteo":"Météo", "transferts":"Recrutement"}
## Écrans que le courrier et les arrêts peuvent ouvrir (routes de main.gd) ; « infirmerie », « contrats » et
## « fiche » sont des vues préparées (Effectif filtré, fiche d'un joueur).
const ROUTES := ["Composition", "Effectif", "Classements", "Recrutement", "Préparation", "Vestiaire", "Presse", "Club", "Finances", "Formation", "Calendrier", "Réception", "Bureau"]
## « ventes » : Recrutement, offres reçues ouvertes (ui/player_sales_view.gd).
const CAPTIONS := {"infirmerie":"Infirmerie", "contrats":"Contrats", "fiche":"Fiche du joueur", "ventes":"Offres reçues"}
## « prolongation » : un autre club approche un joueur en fin de contrat (calendrier-mutations.cjs) ; le lien ouvre sa
## fiche sur l'onglet Contrat pour lui proposer une prolongation.
const PROLONGATION := "Proposer une prolongation"

## Mails du club projetés par le moteur, du plus ancien au plus récent.
static func mails(model: Dictionary) -> Array:
	var box: Variant = model.get("clubLife", {}).get("clubMail")
	if not box is Dictionary or not box.get("mails") is Array: return []
	var result: Array = box.mails.duplicate()
	result.reverse()
	return result

## Réponse retenue (y compris celle affichée avant la réponse du moteur), ou "".
static func answer(model: Dictionary, mail: Dictionary) -> String:
	var answers: Variant = model.get("clubLife", {}).get("clubMail", {}).get("reponses")
	if answers is Dictionary and answers.has(mail.get("id", "")): return str(answers[mail.id])
	return str(mail.get("choice", "")) if mail.get("choice") is String else ""

## Vrai si le mail attend encore une réponse du manager.
static func awaiting(model: Dictionary, mail: Dictionary) -> bool:
	return str(mail.get("status", "")) == "nouveau" and answer(model, mail).is_empty() and not (mail.get("reponses", []) as Array).is_empty()

## Courriers de la Réception (même forme que les autres : id, subject, text, category, route, position).
static func messages(model: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mail: Dictionary in mails(model):
		var text := str(mail.get("corps", "")) + "\n\n— " + str(mail.get("expediteur", ""))
		var chosen := answer(model, mail)
		if not chosen.is_empty():
			var label := chosen
			for option: Dictionary in mail.get("reponses", []):
				if option.get("id") == chosen: label = str(option.get("libelle", chosen))
			text += "\n\nTa réponse : " + label + (("\n" + str(mail.resultat)) if mail.get("resultat") is String else "")
		elif str(mail.get("status", "")) == "classe": text += "\n\nSans réponse de ta part, le dossier a été classé."
		result.append({"id":str(mail.id), "subject":str(mail.get("sujet", "")), "text":text, "category":CATEGORY.get(str(mail.get("categorie", "")), "Club"),
			"route":route_of(str(mail.get("ecran", ""))), "position":100000 + int(str(mail.id).trim_prefix("mail-")), "club_mail":mail})
	return result

## Libellé du bouton vers l'écran concerné.
static func caption(ecran: String) -> String:
	if ecran == "prolongation": return PROLONGATION
	return "Ouvrir · " + str(CAPTIONS.get(ecran, ecran if ecran in ROUTES else "Bureau"))

static func route_of(ecran: String) -> String:
	if ecran in ["infirmerie", "contrats"]: return "Effectif"
	# Consignes de match (réponse « Régler les consignes » du plan adverse de la veille).
	if ecran == "Plan de jeu": return ecran
	if ecran == "fiche" or ecran == "ventes" or ecran == "prolongation": return "Recrutement"
	return ecran if ecran in ROUTES else "Bureau"

## Prépare l'écran utile (filtres de l'effectif) et rend la route à ouvrir ; "" si une fiche de joueur a été ouverte.
static func prepare(app: Control, ecran: String, joueur: String, deferred: bool) -> String:
	match ecran:
		"infirmerie", "contrats":
			var roster := U.defaults()
			if ecran == "infirmerie": roster.available = "Blessés"
			else:
				roster.contract = "Fin de saison"
				roster.sort = "Échéance"
				roster.immersive_tab = 2
			app.management_ui.roster = roster
			app.management_ui.profile_scroll = 0
			app.roster_filter = roster.family
			app.roster_sort = roster.sort
			app.selected_player = ""
			return "Effectif"
		"ventes":
			app.set_meta("open_player_sales", true)
			return "Recrutement"
		"fiche", "prolongation":
			if joueur.is_empty() or not is_instance_valid(app.navigation_controller): return "Recrutement"
			var target := {"kind":"player", "id":joueur}
			if ecran == "prolongation": target.section = "contract"
			if deferred: app.navigation_controller.call_deferred("open_entity", target)
			else: app.navigation_controller.open_entity(target)
			return ""
	return route_of(ecran)

## Bouton « Ouvrir » d'un mail ou réponse qui ouvre l'écran (« ouvrir » dans les données).
static func open_screen(app: Control, ecran: String, joueur: String) -> void:
	var target := prepare(app, ecran, joueur, false)
	# La Presse ne s'ouvre que depuis un courrier (main._navigate) : le mail du club en est l'origine.
	if target == "Presse" and not app.has_meta("press_mail_origin"): app.set_meta("press_mail_origin", "courrier-club")
	if not target.is_empty(): app._navigate(target, false)

## Arrêt informatif de « Continuer » : ouvre l'écran utile au lieu du seul panneau. Rend la route à afficher
## (la réponse du moteur redessine ensuite l'écran), ou "" si rien n'est à changer.
static func stop_route(app: Control, stop: Dictionary) -> String:
	var mail := str(stop.get("mail", ""))
	var ecran := str(stop.get("ecran", ""))
	if not mail.is_empty() or ecran == "Réception":
		app._reset_reception(mail)
		return "Réception"
	if ecran.is_empty(): return ""
	return prepare(app, ecran, str(stop.get("joueur", "")), true)

## Réponse du manager : commande du moteur (affichée tout de suite, annulée si le moteur la refuse).
static func reply(app: Control, mail_id: String, choice: String) -> bool:
	return app._command("club_mail_reply", {"id":mail_id, "choice":choice})

## Après la réponse du moteur : une réponse marquée « ouvrir » mène à l'écran du mail.
static func after_reply(app: Control) -> void:
	var receipt: Variant = app.model.get("meta", {}).get("clubMailReply")
	if receipt is Dictionary and receipt.get("ouvrir", false):
		open_screen(app, str(receipt.get("ecran", "")), str(receipt.get("joueur", "")) if receipt.get("joueur") is String else "")

## Type de blessure d'un joueur (moteur : club-mail.cjs, données « blessures ») ; « Blessure » si inconnu
## (ancienne sauvegarde, joueur rétabli).
static func injury_label(model: Dictionary, player: Dictionary) -> String:
	var key: Variant = player.get("injuryType")
	var labels: Variant = model.get("clubLife", {}).get("clubMail", {}).get("blessures")
	if key is String and labels is Dictionary and labels.get(key) is String: return str(labels[key])
	return "Blessure"

