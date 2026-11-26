extends "res://ui/contextual/match_temps_forts_lecture.gd"
## Régie des temps forts (point d'entrée) : mise en place, API publique, réception du direct, entracte. Le reste est hérité (match_temps_forts_*.gd).

static func enabled() -> bool:
	return OS.get_environment("CD_MATCH_TEMPS_FORTS") != "0"

func setup(owner_view: Control, container: Control, target: SubViewport, space: Control) -> void:
	name = "MatchTempsForts"
	# Avant la vue 3D dans la même image : un plan posé par la régie est cadré tout de suite,
	# sans une image où le ballon a déjà changé de place et pas encore la caméra.
	process_priority = -10
	view = owner_view
	app = view.app
	stage = view.stage
	viewport = target
	# Niveau : le choix de la session, sinon celui imposé au lancement, sinon le réglage enregistré.
	var retenu := OS.get_environment("CD_MATCH_TEMPS_FORTS_NIVEAU")
	var preferences: Variant = app.get("user_preferences")
	if retenu.is_empty() and preferences != null: retenu = str(preferences.data.get("match_highlights", ""))
	var choisi := str(app.management_ui.get("match_temps_forts_niveau", retenu))
	niveau = choisi if choisi in NIVEAUX else "dynamique"
	var cadence := str(app.management_ui.get("match_temps_forts_horloge", OS.get_environment("CD_MATCH_TEMPS_FORTS_HORLOGE")))
	horloge = cadence if HORLOGES.has(cadence) else "normale"
	var allure := OS.get_environment("CD_MATCH_TEMPS_FORTS_VITESSE")
	vitesse = clampf(float(allure), 0.5, 4.0) if allure.is_valid_float() else 1.0
	entracte = ENTRACTE
	voile = ColorRect.new()
	voile.name = "MatchBetweenVeil"
	voile.color = preload("res://ui/charte.gd").FOND
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(voile)
	view.add_child(voile)
	view.move_child(voile, container.get_index() + 1)
	# Bandeau des grands moments : au-dessus de l'image 3D et du voile, sous le bandeau du score.
	_espace = space
	bandeau = construire_bandeau()
	view.add_child(bandeau)
	view.move_child(bandeau, voile.get_index() + 1)
	mention = construire_mention()
	view.add_child(mention)
	view.move_child(mention, bandeau.get_index() + 1)
	between = Between.new()
	between.horloge = horloge
	between.hote_barre = view.get("bande_temps_forts")
	space.add_child(between)
	between.niveau_choisi.connect(choisir_niveau)
	between.reprise_demandee.connect(func(): app._command("pause", {"paused": false}))
	between.tiroir_demande.connect(func(titre: String): view._toggle_drawer(titre))
	between.passer_demande.connect(passer)
	between.horloge_choisie.connect(choisir_horloge)
	# « Confier la fin à l'adjoint » : confirmée dans la colonne de droite de l'entracte (jamais une fenêtre).
	between.delegation_demandee.connect(func(): view.director.command("delegate"))
	between.pause_demandee.connect(func(): app._command("pause", {"paused": true}))
	# Fiche joueur lue pendant l'entracte : le match se met en pause, comme pour la fenêtre Équipe.
	between.fiche_ouverte.connect(func(ouverte: bool): tiroir_ouvert() if ouverte else tiroir_ferme())
	between.couvert = func() -> bool: return (is_instance_valid(view.get("equipe")) and view.equipe.visible) or (view.has_method("fenetre_ouverte") and view.fenetre_ouverte())
	# Nom d'un joueur de l'entracte : sa petite fenêtre par-dessus le match (jamais une page qui remplace la vue).
	if view.has_method("ouvrir_joueur"): between.fiche_vers = view.ouvrir_joueur
	# Carte de Mon XV : la fenêtre du joueur (idée 32), le match continue derrière.
	var MenuJoueur = load("res://ui/contextual/match_menu_joueur.gd")
	if view.has_method("_ouvrir_fenetre"): between.menu_vers = func(id: String, ancre: Control): MenuJoueur.ouvrir(view, id, ancre)
	# Repère de la domination, dernier fait, chiffre clé : le journal ou les statistiques ouverts à la bonne ligne.
	# Plein écran obligatoire (Léo, 21/11/2026) : un fait, un chiffre ou un match du multiplex cliqué ouvre sa petite
	# fenêtre par-dessus le match ; le journal et les statistiques s'ouvrent depuis elle (tiroirs du direct).
	between.journal_demande.connect(func(i: int): if view.has_method("ouvrir_fenetre_fait"): view.ouvrir_fenetre_fait(i) else: ouvrir_journal_a(i))
	between.stats_demandees.connect(ouvrir_stats_a)
	between.stat_demandee.connect(func(rang: Dictionary): if view.has_method("ouvrir_fenetre_stat"): view.ouvrir_fenetre_stat(rang))
	between.match_demande.connect(func(rencontre: Dictionary): if view.has_method("ouvrir_fenetre_match"): view.ouvrir_fenetre_match(rencontre))
	between.camera_demandee.connect(func(mode: String): view.choisir_camera(mode))
	# Club du multiplex ou du classement en direct : sa petite fenêtre par-dessus le match.
	between.club_demande.connect(func(id: int): if view.has_method("ouvrir_fiche_club_id"): view.ouvrir_fiche_club_id(id))
	# En 3D (entracte caché), « Confier la fin » du menu Plus se confirme dans le menu du match.
	between.confier_fin_demande.connect(func(): if view.has_method("confier_fin"): view.confier_fin())
	# Une seule barre de commandes : celle de l'écran intermédiaire, pendant qu'il est affiché.
	between.visibility_changed.connect(_barre_unique)
	# Mon XV : un joueur choisi ouvre la fenêtre Équipe sur lui (le match se met en pause).
	between.joueur_choisi.connect(func(poste: int): view.ouvrir_equipe("composition", poste))
	between.score_joue.connect(_score_joue)
	between.consigne_bonus.connect(appliquer_consigne_bonus)
	# Petite fenêtre des consignes (idée FM27 n° 33) : le match continue derrière, changements au prochain arrêt.
	between.consignes_demandees.connect(func(): if view.has_method("ouvrir_fenetre_consignes"): view.ouvrir_fenetre_consignes(envoyer_consigne))
	# « Pourquoi » d'après-match : l'action d'une raison ouvre l'écran de son levier.
	between.levier_choisi.connect(func(route: String): app._navigate(route))
	# Terrain 2D : il suit l'horloge de l'entracte et repart de la dernière image connue.
	between.terrain.cadence = float(HORLOGES[horloge]) / maxf(vitesse, 0.01)
	if preferences != null: between.terrain.calme = bool(preferences.data.get("reduced_motion", false))
	between.terrain.recaler(-1)

## Journal du match (volet de la vue) ouvert au fait `i` de `live.events` : sa ligne est amenée à l'écran et prend
## le focus (Entrée la relit). Sans la ligne (filtre du journal), le journal s'ouvre seulement.
func ouvrir_journal_a(i: int) -> void:
	if view.get("journal") == null: return
	if str(view.drawer_tab) != "Journal" or not view.drawer.visible: view._toggle_drawer("Journal")
	for k in 3: await get_tree().process_frame
	var journal: Node = view.journal
	var evenements: Array = journal.get("_events") if journal.get("_events") is Array else []
	if i < 0 or i >= evenements.size(): return
	var rang: int = (journal.visible_events as Array).find(evenements[i])
	var ligne: Control = journal.rows.get_node_or_null("JournalEvent%d" % rang) if rang >= 0 else null
	if ligne == null: return
	journal.set("_following", false)
	journal.scroll.ensure_control_visible(ligne)
	var lien: Control = ligne.get_node_or_null("JournalActionLink")
	if lien != null: lien.grab_focus()

## Statistiques complètes (volet de la vue) ouvertes à la ligne du chiffre clé cliqué (libellé du moteur) : la ligne
## est amenée à l'écran et surlignée.
func ouvrir_stats_a(libelle: String) -> void:
	if view.get("drawer_body") == null: return
	if str(view.drawer_tab) != "Stats" or not view.drawer.visible: view._toggle_drawer("Stats")
	for k in 3: await get_tree().process_frame
	var mot := libelle.strip_edges().split(" ", false)[0].to_lower() if not libelle.strip_edges().is_empty() else ""
	if mot.is_empty(): return
	var corps: Control = view.drawer_body
	for noeud: Node in corps.get_children():
		if not noeud is Label or not (noeud as Label).text.to_lower().contains(mot): continue
		var surligne := StyleBoxFlat.new()
		surligne.bg_color = preload("res://ui/charte.gd").PANNEAU_3
		surligne.set_corner_radius_all(Charte.RAYON_PETIT)
		(noeud as Label).add_theme_stylebox_override("normal", surligne)
		var defile := corps.get_parent()
		while defile != null and not defile is ScrollContainer: defile = defile.get_parent()
		if defile != null: (defile as ScrollContainer).ensure_control_visible(noeud)
		return

## Une seule barre de commandes, la même en 3D et pendant l'entracte : la bande sous le score
## (Équipe, Paramètres, Plus) ; le match fini rend la barre du bas (« Valider la journée »).
func _barre_unique() -> void:
	if view == null: return
	var fini := bool(_live.get("finished", false))
	var bande: Control = view.get("bande_temps_forts")
	if bande != null:
		bande.visible = not fini
		if view.barre_commandes != null: view.barre_commandes.visible = fini
	elif view.barre_commandes != null: view.barre_commandes.visible = not between.visible or fini

## Bande sous le score : seulement quand la régie cadence le match (projection présente) ;
## sinon (repli) et à la fin du match, la barre du bas du direct.
func _bande(live: Dictionary) -> void:
	var bande: Control = view.get("bande_temps_forts") if view != null else null
	if bande == null: return
	var active := live.get("direct") is Dictionary and not bool(live.get("finished", false))
	bande.visible = active
	if view.barre_commandes != null: view.barre_commandes.visible = not active

## Consigne en direct (fenêtre Équipe, onglet Consignes) : `set_consignes` sans pause ; pendant une minute
## en cours, la commande attend sa réponse puis part.
func envoyer_consigne(axe: String, valeur: String) -> void:
	suivi.append({"evenement": "consigne", "axe": axe, "valeur": valeur, "horloge": str(_live.get("minute", "")), "debut_ms": Time.get_ticks_msec()})
	app._command(Pilotage.COMMANDE, Pilotage.charge(axe, valeur))

func choisir_horloge(valeur: String) -> void:
	if not HORLOGES.has(valeur): return
	horloge = valeur
	app.management_ui["match_temps_forts_horloge"] = valeur
	if between != null: between.terrain.cadence = float(HORLOGES[horloge]) / maxf(vitesse, 0.01)

func choisir_niveau(id: String) -> void:
	if id not in NIVEAUX or id == niveau: return
	niveau = id
	app.management_ui["match_temps_forts_niveau"] = id
	# Le niveau choisi vaut pour les prochains matchs, comme la caméra.
	var preferences: Variant = app.get("user_preferences")
	if preferences != null and preferences.data.get("match_highlights") != id and not preferences.set_value("match_highlights", id):
		app.notice("Réglage non enregistré", preferences.last_error)
	if view.has_method("montrer_reglages_temps_forts") and _live.get("direct") is Dictionary:
		var direct: Dictionary = _live.direct.duplicate()
		direct["niveau"] = id
		view.montrer_reglages_temps_forts(direct, self)

## Premier modèle projeté par le moteur : la vue 3D passe en mode temps forts.
func _activer(direct: Dictionary) -> void:
	_actif = true
	if stage.has_method("set_cadrage"):
		cadrage = Cadrage.new(stage)
		stage.set_cadrage(cadrage)
	# Gestes et coupes vers les remises en jeu font partie du mode de base.
	if OS.get_environment("CD_MATCH_GESTES") != "0" and stage.has_method("set_gestes"): stage.set_gestes(true)
	if is_instance_valid(app.get("soundscape")) and app.soundscape.has_method("suivre_foule") and stage.get("foule") != null: app.soundscape.suivre_foule(stage.foule) # Clameur : la foule des images montrées.
	if view.has_method("montrer_reglages_temps_forts"): view.montrer_reglages_temps_forts(direct, self)
	# Arbitre : seulement dans le mode temps forts (le direct d'origine reste tel quel).
	if liaisons_actives() and stage.get("_athlete_scene") != null:
		arbitre = Arbitre.new(stage)
		stage.add_child(arbitre)
		if not arbitre.preparer():
			arbitre.queue_free()
			arbitre = null
		elif stage.has_method("inscrire_rejeu"):
			# Ralenti de l'essai : l'arbitre est rejoué et figé avec les joueurs.
			stage.inscrire_rejeu(arbitre, arbitre.model, arbitre.rig)
	if stage.has_signal("rejeu_fini") and not stage.is_connected("rejeu_fini", _rejeu_fini):
		stage.connect("rejeu_fini", _rejeu_fini)

func _exit_tree() -> void:
	_finir_rejeu()
	_presenter(false)

## Vrai tant qu'un temps fort reste à montrer : la causerie et le débrief attendent sa fin.
## La sortie des joueurs (mi-temps, fin de match) retient aussi la causerie et le débrief.
func retient(live: Dictionary) -> bool:
	if etat == JEU or etat == SORTIE: return true
	var direct: Variant = live.get("direct")
	if not direct is Dictionary: return false
	var rencontre := str(direct.get("rencontre", "")) + "|"
	if str(app.management_ui.get("match_temps_forts_rencontre", "")) != rencontre and int(live.get("minute", 0)) > 0: return false
	if sortie_due(live): return true
	if not direct.get("tempsFort") is Dictionary: return false
	return not deja_vu(rencontre + str(direct.tempsFort.get("cle", "")))

## Temps forts déjà montrés pendant la rencontre (clé « rencontre|cle ») : le dernier reste dans
## management_ui.match_temps_forts_cle ; les précédents sont gardés aussi (VUS_MAX au plus), pour qu'une vue
## recréée (causerie, reprise) ne rejoue jamais un temps fort déjà vu, même s'il n'est pas le dernier.
const VUS_MAX := 64
func deja_vu(cle: String) -> bool:
	if cle == str(app.management_ui.get("match_temps_forts_cle", "")): return true
	var vus: Variant = app.management_ui.get("match_temps_forts_vus")
	return vus is Array and cle in vus

func marquer_vu(cle: String) -> void:
	app.management_ui["match_temps_forts_cle"] = cle
	var vus: Variant = app.management_ui.get("match_temps_forts_vus")
	if not vus is Array: vus = []
	if cle in vus: return
	vus.append(cle)
	while vus.size() > VUS_MAX: vus.pop_front()
	app.management_ui["match_temps_forts_vus"] = vus

## Appelée par la vue à chaque modèle reçu, après la mise à jour du bandeau.
func receive(model: Dictionary, live: Dictionary) -> void:
	var direct: Variant = live.get("direct")
	_bande(live)
	if not direct is Dictionary:
		# Moteur sans projection (repli, ou projection indisponible) : le direct d'origine
		# garde la main, et un temps fort en cours s'efface devant lui.
		if etat != INTER or _actif:
			etat = INTER
			index = -1
			gel = false
			_live = {}
			_presenter(false)
			if cadrage != null: cadrage.regler(false)
			view.events.get_parent().get_parent().get_parent().show()
		voile.hide()
		between.hide()
		stage.set_live_cadence(app.tick_steps)
		stage.apply_frame(live)
		return
	if not _actif: _activer(direct)
	var connus := _events.size()
	_live = live
	_teams = live.get("teams", [])
	_events = live.get("events", [])
	_demande = false
	if live.get("paused", false): _pause_envoyee = false
	# Reprise demandée par le manager pendant la pause du tiroir : le tiroir ne repause plus.
	if _pause_tiroir and not live.get("paused", false) and str(app.get("last_command")) == "pause":
		_pause_tiroir = false
		_tiroir = false
	# Ce qui a déjà été joué est retenu par rencontre : la vue peut être recréée
	# (causerie de mi-temps) sans rejouer un temps fort, et un nouveau match repart de zéro.
	var rencontre := str(direct.get("rencontre", "")) + "|"
	var candidat: Variant = direct.get("tempsFort")
	var nouveau: bool = candidat is Dictionary and not deja_vu(rencontre + str(candidat.get("cle", "")))
	var signale: Variant = direct.get("arret")
	# Match repris en cours de route (sauvegarde) ou fin confiée à l'adjoint : ce que le
	# moteur a déjà joué n'est pas rejoué, l'écran intermédiaire montre où en est le match.
	var premiere: bool = str(app.management_ui.get("match_temps_forts_rencontre", "")) != rencontre
	app.management_ui["match_temps_forts_rencontre"] = rencontre
	var delegue: bool = live.get("finished", false) and str(app.get("last_command")) == "delegate"
	if (premiere and int(live.get("minute", 0)) > 0) or delegue:
		if candidat is Dictionary: marquer_vu(rencontre + str(candidat.get("cle", "")))
		# Mi-temps ou fin déjà passées (reprise), ou fin confiée à l'adjoint : pas de sortie mise en scène.
		if not cle_sortie(live).is_empty(): app.management_ui["match_temps_forts_sortie"] = cle_sortie(live)
		if etat == SORTIE: _finir_sortie(false)
		if signale is Dictionary: app.management_ui["match_temps_forts_arret"] = rencontre + str(signale.get("cle", ""))
		nouveau = false
		_arret_attendu = {}
		if etat != INTER:
			gel = false
			index = -1
			_vers_inter()
		# Le terrain 2D ne rejoue pas ce que le moteur a déjà joué : il part de la dernière image.
		between.terrain.recaler(-1)
		suivi.append({"evenement": "delegation" if delegue else "reprise", "horloge": str(direct.get("horloge", "")), "debut_ms": Time.get_ticks_msec()})
	if signale is Dictionary and rencontre + str(signale.get("cle", "")) != str(app.management_ui.get("match_temps_forts_arret", "")):
		app.management_ui["match_temps_forts_arret"] = rencontre + str(signale.get("cle", ""))
		_arret_attendu = signale
	if not arret.is_empty() and not live.get("paused", false) and not _pause_envoyee:
		arret = {}
		between.montrer_arret({})
	if not live.get("paused", false): _pause_au_depart = false
	# Entracte : un nouveau temps fort (pas une suite de l'action) attend la fin de l'entracte ;
	# l'écran intermédiaire garde alors le score, le fil et l'horloge d'avant lui.
	if (premiere and int(live.get("minute", 0)) > 0) or delegue: _retenu = {}
	if nouveau and (not _retenu.is_empty() or _doit_retenir(candidat)):
		if etat == ATTENTE: _vers_inter()
		if _retenu.is_empty() or str(_retenu.get("cle", "")) != str(candidat.get("cle", "")):
			_retenu_vus = connus
			_retenu_depuis = 0.0
			_retenu_reste = maxf(0.5, _duree_entracte() - _entracte)
			_retenu_part = _part_minute()
			suivi.append({"evenement": "entracte_retenu", "cle": str(candidat.get("cle", "")), "horloge": str(candidat.get("horlogeDebut", "")),
				"ecoule": _entracte, "debut_ms": Time.get_ticks_msec()})
		_retenu = candidat
		nouveau = false
	elif not nouveau:
		_retenu = {}
	if _retenu.is_empty():
		_live_inter = live
		var minute := int(live.get("minute", 0))
		if minute != _minute_inter:
			_minute_inter = minute
			_roule = 0.0
		_horloge_inter = str(direct.get("horloge", ""))
		_horloge_montree = str(direct.get("horlogeMontree", ""))
		between.update_frame(model, live, direct, func(conseil: Dictionary): app._command("set_tactics", {"attack": conseil.get("attack"), "defense": conseil.get("defence")}))
	if nouveau:
		# Un temps fort arrive pendant la sortie des joueurs : elle s'arrête là, le temps fort part.
		if etat == SORTIE: _finir_sortie(false)
		marquer_vu(rencontre + str(candidat.get("cle", "")))
		gel = false
		# Un match déjà en pause (reprise d'une sauvegarde) joue tout de même son temps fort.
		_pause_au_depart = live.get("paused", false)
		_vus = connus
		# Temps fort contigu au précédent (la 3D est encore à l'écran) : liaison plutôt qu'une coupe sèche.
		var lien: Dictionary = _preparer_liaison(candidat) if etat == ATTENTE else {}
		_demarrer(candidat, lien)
		# Le modèle arrive après la mise à jour de la vue 3D : on la rejoue sans faire avancer
		# le temps, pour que la première image du temps fort soit déjà placée et cadrée.
		stage._process(0.0)
	elif etat == JEU:
		# Même temps fort, nouveau modèle : seule une pause demandée par le manager le fige.
		var fige: bool = live.get("paused", false) and not _pause_au_depart and not live.get("atBreak", false) and not live.get("finished", false)
		if fige != gel:
			gel = fige
			_presenter(not gel)
			if phase == "choregraphie" or phase == "liaison": stage.figer_choregraphie(gel)
			elif index >= 0 and index < tf.plans.size(): stage.apply_frame(_image(tf.plans[index].scene, gel, int(tf.plans[index].index)))
	elif etat == ATTENTE:
		# Mi-temps ou fin de match annoncée pendant que la 3D attend la minute suivante : sortie des joueurs.
		if sortie_due(live): _debut_sortie()
		else: _vers_inter()
	elif etat == INTER and _retenu.is_empty() and sortie_due(live):
		# Mi-temps ou fin de match arrivée pendant l'écran intermédiaire : la 3D revient pour la sortie.
		_debut_sortie()
	if etat != JEU and etat != SORTIE:
		attente = 0.0
		# Un arrêt suit le temps fort retenu, jamais avant lui.
		if _retenu.is_empty(): _apres_lecture()
	if bool(live.get("finished", false)): _barre_unique()
	_habiller()

func _process(delta: float) -> void:
	if view == null or not is_instance_valid(stage): return
	_animer_bandeau(delta)
	if is_instance_valid(mention) and mention.visible: _placer_mention()
	_suivre_consigne_bonus()
	if etat == SORTIE:
		_lire_sortie(delta * vitesse)
		return
	# Pendant le ralenti, les joueurs montrent des poses passées : pas de vitesse mesurée sur elles.
	if (etat == JEU or etat == ATTENTE) and not rejeu_en_cours(): _mesurer(delta)
	if etat == JEU:
		between.terrain.gel = true
		_lire(delta * vitesse, delta)
		return
	if _entracte_et_horloge(delta): return
	if _live.is_empty() or app.waiting:
		_sans_reponse = 0.0
		return
	if _demande:
		# La requête est partie mais plus rien n'est en cours : on ne reste pas suspendu à elle.
		_sans_reponse += delta
		if _sans_reponse < ECHEANCE_DEMANDE: return
		_demande = false
		suivi.append({"evenement": "echeance", "cause": "demande", "debut_ms": Time.get_ticks_msec()})
	_sans_reponse = 0.0
	if not str(app.last_error).is_empty():
		_apres_erreur += delta
		if _apres_erreur < ECHEANCE_ERREUR: return
	_apres_erreur = 0.0
	if _live.get("paused", false) or _live.get("finished", false) or not arret.is_empty(): return
	attente += delta
	if etat == ATTENTE or _passer or attente >= float(HORLOGES[horloge]):
		attente = 0.0
		_demande = app._command("tick", {"minute": true, "temps_forts": niveau})

# --- Entracte entre deux temps forts ------------------------------------------

## Aucun temps fort n'est retenu : il part dès que le moteur le déclenche (décision de Léo).
func _doit_retenir(_candidat: Dictionary) -> bool:
	return false

## Une causerie (mi-temps, débrief) attend le temps fort : il se montre sans finir l'entracte
## (en pause, l'horloge de l'entracte est figée et la causerie n'ouvrirait jamais).
func _causerie_attend() -> bool:
	var scene: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
	return scene is Dictionary and not scene.is_empty()

## Tiroir Tactique ou Banc ouvert depuis l'écran intermédiaire : le match se met en pause le
## temps des changements (le moteur ne les accepte qu'en pause), rien ne part avant sa fermeture.
func tiroir_ouvert() -> void:
	_tiroir = etat != JEU
	if _tiroir: suivi.append({"evenement": "tiroir", "debut_ms": Time.get_ticks_msec()})

func tiroir_ferme() -> void:
	_tiroir = false
	if not _pause_tiroir: return
	_pause_tiroir = false
	if _live.get("paused", false) and not _live.get("finished", false) and arret.is_empty():
		app._command("pause", {"paused": false})

## Écran intermédiaire : horloge qui défile, entracte, pause du tiroir. Vrai si la régie
## doit attendre (temps fort retenu).
func _entracte_et_horloge(delta: float) -> bool:
	var fige: bool = _live.get("paused", false) and not _live.get("atBreak", false) and not _live.get("finished", false)
	if not fige:
		if _entracte >= 0.0: _entracte += delta
		_roule += delta
		if not _retenu.is_empty(): _retenu_depuis += delta
	# Le terrain 2D se fige avec le match (pause, tiroir ouvert, arrêt sur carton).
	between.terrain.gel = fige or _tiroir or not arret.is_empty()
	if _tiroir and not _pause_tiroir and not fige and not _live.is_empty() and not _live.get("finished", false) and not _live.get("atBreak", false) and not app.waiting:
		_pause_tiroir = app._command("pause", {"paused": true})
	_habiller_horloge()
	if _retenu.is_empty():
		return false
	if (fige and not _causerie_attend()) or _tiroir or app.waiting: return true
	# Entracte en cours seulement (_entracte < 0 : retenu pour le terrain 2D, pas pour l'entracte).
	if not _passer and _entracte >= 0.0 and _entracte < _duree_entracte() and not _causerie_attend(): return true
	_lancer_retenu()
	return true

func _lancer_retenu() -> void:
	var candidat := _retenu
	_retenu = {}
	var rencontre := str(_live.get("direct", {}).get("rencontre", "")) + "|"
	marquer_vu(rencontre + str(candidat.get("cle", "")))
	gel = false
	_pause_au_depart = _live.get("paused", false)
	_vus = _retenu_vus
	suivi.append({"evenement": "entracte_fin", "ecoule": _entracte, "passe": _passer, "debut_ms": Time.get_ticks_msec()})
	_demarrer(candidat)
	stage._process(0.0)
	_habiller()

func _lire(delta: float, reel: float) -> void:
	if gel or index < 0 or index >= tf.plans.size(): return
	# Ralenti de l'essai rejoué : la régie attend sa fin (rien n'avance, ni pistes, ni plan).
	if rejeu_en_cours(): return
	if _moment_essai > 0.0:
		_moment_essai = maxf(0.0, _moment_essai - delta)
		_regler_ralenti()
		# Fin de la célébration : le ralenti de l'essai, sous un autre angle, avant la suite.
		if _moment_essai <= 0.0 and _lancer_rejeu(): return
		# Essai aplati : ralenti puis image tenue ; la suite (transformation) attend la fin du moment.
		# Les pistes du chorégraphe continuent, au ralenti de la vue.
		if phase != "choregraphie": return
	if phase == "liaison":
		_lire_liaison(reel)
		return
	if phase == "choregraphie":
		_lire_choregraphie(reel)
		return
	# Une passe longue ou un geste de la vue tient l'image : la lecture l'attend, avec une échéance.
	if stage.is_presenting_extended_pass() and _tenu < ECHEANCE_GESTE:
		_tenu += reel
		if _tenu >= ECHEANCE_GESTE: suivi.append({"evenement": "echeance", "cause": "geste", "plan": str(tf.plans[index].get("kind", "")), "debut_ms": Time.get_ticks_msec()})
		# Ballon porté qui finit en essai : la durée du plan est un plancher, pas un ajout (le
		# regroupement ne s'arrête pas sept secondes avant de repartir vers la ligne).
		if phase == "jeu" and enchaine_essai(tf.get("plans", []), index): temps += delta
		# Le geste d'essai tient l'image jusqu'après la joie : l'essai est légendé dès qu'il est aplati.
		_legender_essai()
		return
	var plan: Dictionary = tf.plans[index]
	temps += delta
	if phase == "pret":
		if not _elan and temps >= float(PRET.get(str(plan.get("kind", "")), 0.0)) - PRET_ELAN:
			# Tir au but : le buteur s'élance vers le ballon (même image, aucun nouveau fait).
			_elan = true
			var elan := ApresEssai.elan(plan.scene, ApresEssai.FRAPPE)
			# Transformation (loi 8) : les défenseurs chargent dès que le buteur s'élance.
			if str(plan.get("kind", "")) == "transformation": elan = ApresEssai.charge(elan)
			elan.key = str(plan.scene.get("key", "")) + ":pret"
			stage.apply_frame(_image(elan, false, int(plan.index) - 1))
		if temps >= float(PRET.get(str(plan.get("kind", "")), 0.0)): _jouer(plan)
		return
	# Le résultat d'un tir s'affiche après la frappe, pas avant.
	if plan.has("annonce") and temps >= RESULTAT and not _resultat_sonne:
		_resultat_sonne = true
		var marque: Array = plan.get("score", _score)
		var reussi: bool = str(plan.get("kind", "")) == "goal" or (str(plan.get("kind", "")) == "transformation" and marque.size() >= 2 and _score.size() >= 2 and int(marque[0]) + int(marque[1]) > int(_score[0]) + int(_score[1]))
		# Le résultat est à l'écran : le bandeau du score le suit (la transformation vaut +2 à cet instant).
		_score = marque
		_habiller()
		_sonner("goal" if reussi else "miss", _camp_du_plan(plan))
	_legender_essai()
	var mouvement := float(plan.get("mouvement", 0.0))
	if mouvement > 0.0 and temps < mouvement + PAS:
		sous_image += delta
		if sous_image >= PAS:
			sous_image = 0.0
			stage.apply_frame(_image(_interpole(plan.scene, clampf(temps / mouvement, 0.0, 1.0)), false, int(plan.index)))
	if mouvement > 0.0 and temps >= mouvement and not _plaque:
		_plaque = true
		_plaquer(plan)
	if temps < float(plan.get("duree", 1.0)): return
	# Le plan n'est fini qu'une fois joué à l'écran : les joueurs proches du ballon ont rejoint leur place.
	if _attente_place < ECHEANCE_PLACE and stage.has_method("deplacement_restant") and stage.deplacement_restant() > 0.05:
		_attente_place += reel
		return
	_score = plan.get("score", _score)
	index += 1
	if index < tf.plans.size():
		_commencer_plan()
		return
	# Durée du temps fort : sur son entrée (les pistes du chorégraphe ont la leur, à la suite).
	for i in range(suivi.size() - 1, -1, -1):
		if str(suivi[i].get("evenement", "")) == "temps_fort":
			suivi[i]["duree_reelle"] = (Time.get_ticks_msec() - _debut_ms) / 1000.0
			break
	index = -1
	# L'entracte commence à la fin du temps fort.
	_entracte = 0.0
	if sortie_due(_live):
		# Dernier temps fort de la période : plan large et sortie des joueurs avant la causerie.
		_debut_sortie()
	elif _live.get("paused", false) or _live.get("finished", false) or not _arret_attendu.is_empty():
		_vers_inter()
		_apres_lecture()
		# Mi-temps ou fin de match : la causerie retenue pendant l'action peut s'ouvrir.
		if is_instance_valid(view.director): view.director.call_deferred("sync")
	else:
		# La minute suivante dira si l'action continue : la 3D reste à l'écran.
		etat = ATTENTE
	_habiller()
