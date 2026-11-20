extends RefCounted
## Sous-pages du Recrutement (décision de Léo du 19/11/2026 : jamais de petite fenêtre, un clic change d'écran) :
## « Repérer la relève », « Marché entre clubs », « Offres reçues », « Missions et rapports », « Offre au joueur »
## (négociation du contrat) et « Rapport d'observation ». Chacune garde la coque, un retour « ← Retour au recrutement »
## (Échap) et une étape d'historique Précédent / Suivant (`management_ui.recrutement_page`, voir navigation_controller.gd).
##
## Les vues existantes (regen_scouting_view, interclub_market_view, player_sales_view, contract_negotiation,
## decision_views) construisent encore leur contenu dans une fenêtre. Ici, la fenêtre est construite puis ADOPTÉE : elle est
## masquée (jamais affichée), son contenu passe dans la page, et ses boutons « valider / annuler » deviennent ceux de la page.
## Le contenu survit aux rendus de l'écran (il retourne dans un hôte caché de l'application, puis dans la page suivante) ;
## la fermeture de la fenêtre d'origine (`queue_free` après une action) ferme la page. Aucune commande n'est dupliquée.
## Exemple : `Pages.ouvrir(app, "releve")`, `Pages.ouvrir(app, "negociation", {"player_id": id})`.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const HOTE := "RecrutementHote"
const PAGES := ["releve", "interclub", "offres", "missions", "negociation", "rapport"]
const TITRES := {"releve":"Repérer la relève", "interclub":"Marché entre clubs", "offres":"Offres reçues", "missions":"Besoins, missions et rapports", "negociation":"Offre au joueur", "rapport":"Rapport d’observation"}
const LARGEUR := 1560.0

## Sous-page demandée (sinon "").
static func actuelle(app: Control) -> String:
	var etat: Variant = app.management_ui.get("recrutement_page")
	if not etat is Dictionary: return ""
	var page := str(etat.get("kind", ""))
	return page if page in PAGES else ""

static func etat(app: Control) -> Dictionary:
	var valeur: Variant = app.management_ui.get("recrutement_page")
	return valeur if valeur is Dictionary else {}

## Ouvre une sous-page : `args` = {player_id, tab, role, report_id} selon la page.
static func ouvrir(app: Control, page: String, args: Dictionary = {}) -> void:
	if page not in PAGES: return
	_vider_hote(app)
	var contenu := {"kind": page}
	contenu.merge(args)
	app.management_ui.recrutement_page = contenu
	app._navigate("Recrutement", true, true)
	var cible := app.root_content.find_child("RecrutementRetour", true, false) as Control
	if cible != null and page != "negociation": cible.grab_focus.call_deferred()

static func fermer(app: Control) -> void:
	_vider_hote(app)
	app.management_ui.erase("recrutement_page")
	app._navigate("Recrutement", true, true)

static func _vider_hote(app: Control) -> void:
	var hote := app.get_node_or_null(HOTE)
	if hote == null: return
	var fenetre: Variant = hote.get_meta("fenetre", null)
	app.remove_child(hote)
	hote.queue_free()
	if is_instance_valid(fenetre) and fenetre is Window:
		fenetre.set_meta("en_page", false)
		fenetre.hide()
		fenetre.queue_free()

## Page entière : barre de retour, titre, contenu adopté.
static func build(app: Control, page: Control, kind: String) -> void:
	var retour := Kit.lien(page, Rect2(0, 4, 0, 38), "← Retour au recrutement", func(): fermer(app), "RecrutementRetour", 20)
	retour.tooltip_text = ""
	Kit.touche(page, retour.size.x / C.density + 10, 32, "Échap")
	var titre := Kit.titre(page, 0, 98, str(TITRES.get(kind, "")), 38, 1400)
	titre.name = "RecrutementSubpageTitle"
	D.line(page, Vector2(0, 122), Vector2(2248, 122), Charte.FILET)
	var cadre := D.rect(page, Rect2(0, 146, LARGEUR, 1000), Charte.PANNEAU, 0)
	cadre.name = "RecrutementSubpage_" + kind
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	cadre.clip_contents = true
	var hote := _hote(app, kind)
	if hote == null:
		D.text(cadre, 28, 60, "Cet écran n’est pas disponible pour le moment.", 22, Charte.IVOIRE_2, 600, 1200)
		return
	var fenetre := hote.get_meta("fenetre") as AcceptDialog
	var contenu: Array = hote.get_meta("contenu", [])
	var zone := Control.new()
	zone.name = "RecrutementAdopte"
	cadre.add_child(zone)
	D.place(zone, Rect2(24, 18, LARGEUR - 48, 900))
	for enfant: Variant in contenu:
		if not is_instance_valid(enfant): continue
		if enfant.get_parent() != null: enfant.get_parent().remove_child(enfant)
		zone.add_child(enfant)
		(enfant as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		(enfant as Control).theme = fenetre.theme
	# Boutons de la fenêtre d'origine (valider / annuler) : repris dans le pied de la page.
	var pied := Rect2(24, 930, LARGEUR - 48, 56)
	var ok := fenetre.get_ok_button()
	var confirmation := fenetre is ConfirmationDialog
	var annuler: Button = (fenetre as ConfirmationDialog).get_cancel_button() if confirmation else null
	if confirmation and ok.visible:
		var valider := Kit.bouton_ivoire(cadre, Rect2(pied.position.x, pied.position.y, 560, 46), str(ok.text), func():
			if is_instance_valid(ok) and not ok.disabled:
				ok.pressed.emit(), "RecrutementPageValider")
		valider.disabled = ok.disabled
		valider.set_meta("source", ok)
		var suivi := Timer.new()
		suivi.wait_time = .25
		suivi.autostart = true
		suivi.timeout.connect(func():
			if is_instance_valid(ok) and is_instance_valid(valider):
				valider.disabled = ok.disabled
				valider.text = str(ok.text).to_upper())
		valider.add_child(suivi)
		var lien := Kit.lien(cadre, Rect2(pied.position.x + 600, pied.position.y + 4, 0, 38), str(annuler.text).capitalize(), func():
				if is_instance_valid(annuler):
					annuler.pressed.emit(), "RecrutementPageAnnuler", 20)
		lien.set_meta("source", annuler)
		(lien as Control).grab_focus.call_deferred()

## Hôte du contenu adopté pour cette page : créé au premier affichage (construit la fenêtre d'origine puis l'adopte).
static func _hote(app: Control, kind: String) -> Control:
	var hote := app.get_node_or_null(HOTE) as Control
	if hote != null and str(hote.get_meta("kind", "")) == kind and is_instance_valid(hote.get_meta("fenetre", null)): return hote
	if hote != null: _vider_hote(app)
	var fenetre := _creer(app, kind)
	if fenetre == null: return null
	return _adopter(app, kind, fenetre)

static func _derniere_fenetre(app: Control) -> AcceptDialog:
	for i in range(app.get_child_count() - 1, -1, -1):
		var enfant := app.get_child(i)
		if enfant is AcceptDialog and enfant != app.get("file_dialog") and not enfant.is_queued_for_deletion() and not bool(enfant.get_meta("en_page", false)): return enfant
	return null

static func _creer(app: Control, kind: String) -> AcceptDialog:
	var args := etat(app)
	match kind:
		"releve":
			return load("res://ui/regen_scouting_view.gd").open(app)
		"interclub":
			return load("res://ui/interclub_market_view.gd").open(app)
		"offres":
			return load("res://ui/player_sales_view.gd").open(app)
		"missions":
			load("res://ui/decision_views.gd").recruitment(app)
			var fenetre := _derniere_fenetre(app)
			if fenetre == null: return null
			var onglets := fenetre.find_child("ScoutTabs", true, false) as TabContainer
			if onglets != null: onglets.current_tab = clampi(int(args.get("tab", 0)), 0, maxi(0, onglets.get_tab_count() - 1))
			var famille := fenetre.find_child("ScoutFamily", true, false) as OptionButton
			var role := str(args.get("role", ""))
			if famille != null and not role.is_empty():
				var familles := [["Pilier"], ["Talonneur"], ["Deuxième"], ["Troisième", "Flanker", "Numéro 8"], ["Demi de mêlée"], ["Ouvreur", "Ouverture", "Demi d’ouverture"], ["Ailier"], ["Centre"], ["Arrière"]]
				for i in familles.size():
					for prefixe: String in familles[i]:
						if role.begins_with(prefixe): famille.select(i)
			return fenetre
		"negociation":
			var joueur := {}
			for candidat: Variant in app.model.get("market", []):
				if candidat is Dictionary and str(candidat.get("id", "")) == str(args.get("player_id", "")): joueur = candidat
			if joueur.is_empty(): return null
			load("res://ui/contract_negotiation.gd").open(app, joueur, true, str(args.get("answer", "")))
			return _derniere_fenetre(app)
		"rapport":
			var Recruitment: Variant = load("res://ui/immersive08/recruitment_canvas.gd")
			if not Recruitment.open_report(app, str(args.get("report_id", ""))): return null
			return _derniere_fenetre(app)
	return null

static func _adopter(app: Control, kind: String, fenetre: AcceptDialog) -> Control:
	var hote := Control.new()
	hote.name = HOTE
	hote.visible = false
	hote.set_meta("kind", kind)
	app.add_child(hote)
	_prendre(app, kind, hote, fenetre)
	return hote

## Reprend le contenu d'une fenêtre : masquée (jamais affichée), ses contrôles passent dans l'hôte.
static func _prendre(app: Control, kind: String, hote: Control, fenetre: AcceptDialog) -> void:
	hote.set_meta("fenetre", fenetre)
	fenetre.set_meta("en_page", true)
	var contenu: Array = []
	for enfant in fenetre.get_children():
		if enfant is Control:
			fenetre.remove_child(enfant)
			hote.add_child(enfant)
			contenu.append(enfant)
	hote.set_meta("contenu", contenu)
	fenetre.hide()
	# La fenêtre d'origine se ferme (queue_free après une action) : la page se ferme, sauf si une nouvelle fenêtre de la
	# même vue la remplace (devis rouvert avec la réponse du conseil) : elle est alors adoptée à son tour.
	# La fonction ne capture que l'application et la fenêtre (l'hôte peut déjà être libéré à ce moment).
	fenetre.tree_exiting.connect(func():
		if not is_instance_valid(app): return
		var courant := app.get_node_or_null(HOTE)
		if courant == null or courant.get_meta("fenetre", null) != fenetre: return
		_relais.call_deferred(app, kind, 0), CONNECT_ONE_SHOT)

## Après la fermeture d'une fenêtre adoptée : la page suit la fenêtre qui la remplace, attend la réponse du moteur,
## ou se ferme.
static func _relais(app: Variant, kind: String, essai: int) -> void:
	if not is_instance_valid(app): return
	var hote := app.get_node_or_null(HOTE) as Control
	if hote == null or actuelle(app) != kind: return
	var suivante := _derniere_fenetre(app)
	if suivante != null and (kind == "negociation" or not suivante is ConfirmationDialog):
		for ancien: Variant in hote.get_meta("contenu", []):
			if is_instance_valid(ancien):
				if ancien.get_parent() != null: ancien.get_parent().remove_child(ancien)
				ancien.queue_free()
		_prendre(app, kind, hote, suivante)
		app._navigate("Recrutement", true, true)
		return
	# Réponse du moteur attendue (offre envoyée, rallonge demandée) : on laisse jusqu'à 6 s à la vue pour se rouvrir.
	var attente: bool = bool(app.get("waiting")) or (essai < 4 and str(app.get("last_command")) == "transfer_budget_extension")
	if kind == "negociation" and essai < 24 and attente:
		app.get_tree().create_timer(.25).timeout.connect(func(): _relais(app, kind, essai + 1))
		return
	fermer(app)
