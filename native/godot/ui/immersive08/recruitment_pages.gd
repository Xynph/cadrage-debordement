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
const EnPlace = preload("res://ui/confirmation_en_place.gd")
const HOTE := "RecrutementHote"
const PAGES := ["releve", "interclub", "offres", "missions", "negociation", "rapport", "dossier"]
const TITRES := {"releve":"Repérer la relève", "interclub":"Marché entre clubs", "offres":"Offres reçues", "missions":"Besoins, missions et rapports", "negociation":"Offre au joueur", "rapport":"Rapport d’observation", "dossier":"Dossier"}
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
	# Depuis la fiche d'une piste (« Approcher le joueur ») : la sous-page remplace la fiche (le retour mène à la liste).
	app.management_ui.erase("fiche_joueur")
	app._navigate("Recrutement", true, true)
	var cible := app.root_content.find_child("RecrutementRetour", true, false) as Control
	if cible != null and page != "negociation": cible.grab_focus.call_deferred()

static func fermer(app: Control) -> void:
	_vider_hote(app)
	app.management_ui.erase("recrutement_page")
	app._navigate("Recrutement", true, true)

## « ← Retour » : un dossier revient au catalogue d'où il vient (relève ou marché entre clubs), le reste à la liste.
static func retour(app: Control) -> void:
	var courant := etat(app)
	if str(courant.get("kind", "")) == "dossier" and str(courant.get("retour", "")) in ["releve", "interclub"]: ouvrir(app, str(courant.retour))
	else: fermer(app)

## Dossier d'une piste de la relève ou du marché entre clubs : sous-page (portrait, onglets, retour au catalogue).
static func ouvrir_dossier(app: Control, source: String, id: String) -> bool:
	var Prospect: Variant = load("res://ui/prospect_profile.gd")
	if not Prospect.target_available(app, source, id): return false
	var origine := actuelle(app)
	var retour_vers := origine if origine in ["releve", "interclub"] else "interclub" if source == "interclub" else "releve"
	ouvrir(app, "dossier", {"source": source, "id": id, "retour": retour_vers})
	return true

## Clé d'historique d'une sous-page (une étape Précédent / Suivant par page et par dossier) et son inverse.
static func cle(courant: Dictionary) -> String:
	var kind := str(courant.get("kind", ""))
	if kind != "dossier": return kind
	return "dossier|%s|%s|%s" % [str(courant.get("source", "")), str(courant.get("id", "")), str(courant.get("retour", ""))]

static func depuis_cle(valeur: String) -> Dictionary:
	if not valeur.begins_with("dossier|"): return {"kind": valeur}
	var morceaux := valeur.split("|")
	return {"kind": "dossier", "source": morceaux[1] if morceaux.size() > 1 else "", "id": morceaux[2] if morceaux.size() > 2 else "", "retour": morceaux[3] if morceaux.size() > 3 else "releve"}

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

## Page entière : barre de retour, titre, contenu adopté (ou dossier construit ici).
static func build(app: Control, page: Control, kind: String) -> void:
	var courant := etat(app)
	var libelle_retour := "← Retour au recrutement"
	if kind == "dossier": libelle_retour = "← Retour " + ("au marché entre clubs" if str(courant.get("retour", "")) == "interclub" else "à la relève")
	var lien_retour := Kit.lien(page, Rect2(0, 4, 0, 38), libelle_retour, func(): retour(app), "RecrutementRetour", 20)
	lien_retour.tooltip_text = ""
	Kit.touche(page, lien_retour.size.x / C.density + 10, 32, "Échap")
	var titre := Kit.titre_page(page, 0, 98, str(TITRES.get(kind, "")), 38, 1400)
	titre.name = "RecrutementSubpageTitle"
	D.line(page, Vector2(0, 122), Vector2(2248, 122), Charte.FILET)
	var cadre := D.rect(page, Rect2(0, 146, LARGEUR, 1000), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	cadre.name = "RecrutementSubpage_" + kind
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	cadre.clip_contents = true
	if kind == "dossier":
		_dossier(app, cadre, titre, courant)
		return
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
	_charte(zone)
	_suivre_ajouts(zone)
	# Boutons de la fenêtre d'origine (valider / annuler) : repris dans le pied de la page.
	var pied := Rect2(24, 930, LARGEUR - 48, 56)
	var ok := fenetre.get_ok_button()
	var confirmation := fenetre is ConfirmationDialog
	var annuler: Button = (fenetre as ConfirmationDialog).get_cancel_button() if confirmation else null
	if confirmation and ok.visible:
		# Offre au joueur : « Envoyer l'offre » ouvre une confirmation EN PLACE (récapitulatif + « Confirmer »), jamais un engagement
		# en un seul clic ; les autres vues ont leur propre confirmation en place.
		var deux_temps := kind == "negociation"
		var libelle := "Envoyer l’offre" if deux_temps else str(ok.text)
		var valider := Kit.bouton_ivoire(cadre, Rect2(pied.position.x, pied.position.y, 560, 46), libelle, func(): _valider(app, cadre, zone, ok, deux_temps), "RecrutementPageValider")
		valider.disabled = ok.disabled
		valider.set_meta("source", ok)
		var suivi := Timer.new()
		suivi.wait_time = .25
		suivi.autostart = true
		suivi.timeout.connect(func():
			if is_instance_valid(ok) and is_instance_valid(valider):
				valider.disabled = ok.disabled
				if not deux_temps: valider.text = str(ok.text).to_upper())
		valider.add_child(suivi)
		var lien := Kit.lien(cadre, Rect2(pied.position.x + 600, pied.position.y + 4, 0, 38), str(annuler.text).capitalize(), func():
				if is_instance_valid(annuler):
					annuler.pressed.emit(), "RecrutementPageAnnuler", 20)
		lien.set_meta("source", annuler)
		(lien as Control).grab_focus.call_deferred()

## Premier clic sur le bouton principal d'une offre : confirmation EN PLACE ; le second (« Confirmer … ») envoie.
static func _valider(app: Control, cadre: Control, zone: Control, ok: Button, deux_temps: bool) -> void:
	if not is_instance_valid(ok) or ok.disabled: return
	if not deux_temps:
		ok.pressed.emit()
		return
	var envoi := func():
		if is_instance_valid(ok): ok.pressed.emit()
	# Offre au joueur (choix de Léo du 21/11/2026) : le récapitulatif figé en pièces visuelles, sans phrase.
	var toile := zone.find_child("OffreVisuelle", true, false) as Control
	if toile != null and toile.has_meta("recap"):
		var bloc_visuel := EnPlace.ouvrir(app, cadre, "ContractSignatureConfirmation", "Confirmer l’offre", [], "Confirmer : autoriser la signature si accord", envoi)
		var recap: Control = (toile.get_meta("recap") as Callable).call()
		var colonne := bloc_visuel.get_child(0)
		colonne.add_child(recap)
		colonne.move_child(recap, 1)
		var haut_bloc := 18 + float(toile.get_meta("y_confirmation", 320.0))
		D.place(bloc_visuel, Rect2(24, haut_bloc, LARGEUR - 48, 10))
		# Le bloc recouvre toute la partie réglable de l'écran (jusqu'au pied) : l'offre se relit figée.
		bloc_visuel.custom_minimum_size.y = (18 + toile.size.y / C.density - haut_bloc + 20) * C.density
		var pied_page: Array[Control] = []
		for nom_pied in ["RecrutementPageValider", "RecrutementPageAnnuler"]:
			var bouton := cadre.get_node_or_null(nom_pied) as Control
			if bouton != null:
				bouton.visible = false
				pied_page.append(bouton)
		bloc_visuel.tree_exited.connect(func():
			for bouton: Control in pied_page:
				if is_instance_valid(bouton): bouton.visible = true)
		return
	var lignes: Array = []
	var resume := zone.find_child("OfferSummary", true, false) as Label
	if resume != null: lignes.append({"id":"ContractSignatureSummary", "text":resume.text})
	lignes.append({"id":"ContractSignaturePhrase", "text":"En confirmant, tu envoies ces conditions. Si le joueur accepte, le contrat est signé et la prime est débitée. Sinon, seule la discussion est enregistrée."})
	var envoyer := func():
		if is_instance_valid(ok): ok.pressed.emit()
	var bloc := EnPlace.ouvrir(app, cadre, "ContractSignatureConfirmation", "Confirmer l’offre", lignes, "Confirmer : autoriser la signature si accord", envoyer)
	D.place(bloc, Rect2(24, 470, LARGEUR - 48, 10))
	var valider := cadre.get_node_or_null("RecrutementPageValider") as Control
	if valider != null: valider.visible = false
	bloc.tree_exited.connect(func():
		if is_instance_valid(valider): valider.visible = true)

# --- Habillage aux jetons de la charte des vues adoptées (anciennes fenêtres) --------------------------------------------

## Or / jaune → ivoire (l'or est réservé à Continuer), vert du carnet → vert de la charte, fonds verts → panneau.
static func _teinte(couleur: Color, fond: bool = false) -> Color:
	if couleur.a <= .01: return couleur
	if couleur.r > .7 and couleur.g > .5 and couleur.b < .55: return Charte.FILET if fond else Charte.IVOIRE
	if couleur.g > couleur.r + .04 and couleur.g > couleur.b + .02: return Charte.PANNEAU_3 if fond and couleur.v < .5 else Charte.V
	return couleur

static func _teindre(noeud: Node) -> void:
	if not is_instance_valid(noeud) or not noeud is Control: return
	if noeud.get_meta("style_charte", false): return
	var controle := noeud as Control
	for cle_couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_placeholder_color"]:
		if controle.has_theme_color_override(cle_couleur): controle.add_theme_color_override(cle_couleur, _teinte(controle.get_theme_color(cle_couleur)))
	for etat_style in ["panel", "normal", "hover", "pressed", "focus", "disabled", "read_only", "fill", "background"]:
		if not controle.has_theme_stylebox_override(etat_style): continue
		var style := controle.get_theme_stylebox(etat_style) as StyleBoxFlat
		if style == null: continue
		style.bg_color = _teinte(style.bg_color, true)
		style.border_color = _teinte(style.border_color, true)
		style.set_corner_radius_all(_rayon_charte(etat_style, controle))
	# Boutons d'action d'une ancienne fenêtre : style « lien » de la charte (un seul ivoire plein par écran, celui de la page).
	if noeud is Button and not (noeud is CheckBox or noeud is OptionButton or noeud is MenuButton or noeud is CheckButton):
		C.style_bouton_lien(noeud as Button, 19)

## Rayon de la charte finale selon le rôle du style : panneau 12 (dans la page), jauge pilule, champ de texte multiligne 6, champs et boutons pilule.
static func _rayon_charte(etat_style: String, controle: Control) -> int:
	if etat_style == "panel": return Charte.RAYON_CARTE
	if etat_style == "fill" or etat_style == "background": return Charte.RAYON_PILULE
	if controle is TextEdit or controle is ItemList or controle is Tree: return Charte.RAYON_PETIT
	return Charte.RAYON_PILULE

static func _charte(racine: Node) -> void:
	_teindre(racine)
	for enfant in racine.find_children("*", "Control", true, false): _teindre(enfant)

## Les vues adoptées se redessinent (nouvelles cartes, nouveaux boutons) : chaque ajout reçoit le même habillage.
static func _suivre_ajouts(zone: Control) -> void:
	var arbre := zone.get_tree()
	if arbre == null: return
	var accroche := func(ajout: Node):
		if is_instance_valid(zone) and zone.is_ancestor_of(ajout): _teindre.call_deferred(ajout)
	arbre.node_added.connect(accroche)
	zone.tree_exiting.connect(func():
		if arbre.node_added.is_connected(accroche): arbre.node_added.disconnect(accroche))

# --- Dossier (relève, marché entre clubs) ------------------------------------------------------------------------------

## Dossier d'une piste : identité, onglets Profil / Observation / Contrat / Ton effectif (mêmes lectures que l'ancienne
## fenêtre `prospect_profile.gd`). Lecture seule : aucune commande. Nom = fiche complète quand la piste est aussi sur le marché.
static func _dossier(app: Control, cadre: Control, titre: Label, courant: Dictionary) -> void:
	var Prospect: Variant = load("res://ui/prospect_profile.gd")
	var G = load("res://ui/carnet_skin.gd")
	var source := str(courant.get("source", ""))
	var id := str(courant.get("id", ""))
	var personne: Dictionary = Prospect.projected_person(app, source, id)
	if personne.is_empty():
		D.text(cadre, 28, 60, "Ce dossier n’est plus disponible.", 22, Charte.IVOIRE_2, 600, 1200)
		return
	titre.text = ("Dossier · " + str(personne.get("name", ""))).to_upper()
	var portrait: Control = G.portrait(0, 72, personne)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(portrait)
	D.place(portrait, Rect2(28, 24, 96, 96))
	var sur_le_marche: bool = not load("res://ui/immersive08/fiche_commune.gd").trouver(app, id, "market").is_empty()
	var nom_texte := str(personne.get("name", "—"))
	if sur_le_marche:
		Kit.nom(app, cadre, Rect2(148, 30, 700, 44), nom_texte, id, "ProspectProfileName", Charte.IVOIRE, 30)
	else:
		var nom_label := D.text(cadre, 148, 62, nom_texte, 30, Charte.IVOIRE, 700, 900)
		nom_label.name = "ProspectProfileName"
	Kit.texte(cadre, 148, 104, "%s · %s ans" % [str(personne.get("pos", "—")), G.n(personne.get("age", "—"))], Charte.IVOIRE_2, 800, 19)
	if sur_le_marche:
		var fiche := Kit.lien(cadre, Rect2(1180, 36, 0, 38), "Ouvrir la fiche complète →", func(): app.navigation_controller.open_entity({"kind":"market", "id":id}), "ProspectOpenSheet", 19, true)
		fiche.tooltip_text = ""
	var onglets := TabContainer.new()
	onglets.name = "ProspectProfileTabs"
	cadre.add_child(onglets)
	D.place(onglets, Rect2(24, 140, LARGEUR - 48, 820))
	var profil: VBoxContainer = G.scroll(onglets)
	profil.get_parent().name = "Profil"
	Prospect._profile(profil, personne, source)
	var observation: VBoxContainer = G.scroll(onglets)
	observation.get_parent().name = "Observation"
	Prospect._observation(observation, personne)
	var contrat: VBoxContainer = G.scroll(onglets)
	contrat.get_parent().name = "Contrat"
	Prospect._contract(contrat, personne, source)
	var effectif: VBoxContainer = G.scroll(onglets)
	effectif.get_parent().name = "Ton effectif"
	Prospect._squad(effectif, app.model.get("squad", []), personne)
	_charte(cadre)

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
