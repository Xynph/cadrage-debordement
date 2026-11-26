extends "res://ui/contextual/match_between_fil.gd"
## Regard de l'adjoint, « pourquoi » et arrêts de jeu de l'écran intermédiaire du match.

## Arrêt-décision (maquette 14-match-entracte-3) : dans la colonne de droite, le motif et la minute, ce
## qui se passe, les choix proposés par le staff (le conseillé en tête), puis « Valider le choix » ; le
## match reste arrêté jusqu'à la décision.
func _arret_decision() -> void:
	var colonne := _panneau(colonne_droite, px(20))
	arret = colonne.get_parent().get_parent()
	arret.name = "MatchBetweenStop"
	S.G.fill(arret, true)
	colonne.add_theme_constant_override("separation", px(12))
	var tete := S.G.h(px(10))
	colonne.add_child(tete)
	arret_titre = _titre_bloc("", 30)
	S.G.fill(arret_titre)
	tete.add_child(arret_titre)
	var reste := _texte("le match reste arrêté", 17, DOUX)
	reste.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(reste)
	arret_texte = _texte("", 20, IVOIRE, true)
	colonne.add_child(arret_texte)
	arret_sous_titre = _texte("CHOIX PROPOSÉS PAR LE STAFF", 16, DOUX, false, true)
	colonne.add_child(arret_sous_titre)
	# Remplacement forcé : une ligne par joueur possible, le choix du staff en tête.
	arret_options = S.G.v(px(4))
	arret_options.name = "MatchBetweenStopOptions"
	arret_options.hide()
	colonne.add_child(arret_options)
	var choix := S.G.h(px(16))
	colonne.add_child(choix)
	arret_reprendre = _bouton("REPRENDRE LE MATCH", _valider_arret, true, true)
	arret_reprendre.name = "MatchBetweenStopResume"
	arret_reprendre.add_theme_font_override("font", TITRES_EXTRA)
	choix.add_child(arret_reprendre)
	choix.add_child(_touche("Entrée"))
	arret_aide = _texte("Équipe, Réglages, Mon XV et le banc reviennent après ce choix.", 17, DOUX, true)
	arret_aide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	S.G.fill(arret_aide)
	choix.add_child(arret_aide)
	var vers_equipe := _lien("Ouvrir l’équipe →", func(): tiroir_demande.emit("Équipe"), "MatchBetweenStopTeam")
	vers_equipe.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	colonne.add_child(vers_equipe)
	arret.hide()

## Bouton du panneau d'arrêt : tant que le choix est à faire, il valide l'option qui a le focus (celle du
## staff sinon) ; une fois le choix enregistré (ou sans choix à faire), il reprend le match.
func _valider_arret() -> void:
	if _choix_en_attente():
		var cible: Button = null
		var focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
		for bouton: Node in arret_options.get_children():
			if bouton is Button and (bouton == focus or (cible == null and bouton.has_meta("retenue"))): cible = bouton
		if cible == null and arret_options.get_child_count() > 0: cible = arret_options.get_child(0) as Button
		if cible != null and not cible.disabled: cible.pressed.emit()
		return
	reprise_demandee.emit()

## La phrase la plus parlante : la lecture du match si elle existe, sinon la première raison qui
## propose quelque chose (pas « Aucun signal… »), réduite à sa première phrase.
static func _phrase_forte(raisons: Array) -> String:
	var choisie := str(raisons[0])
	for raison: Variant in raisons:
		var texte := str(raison)
		if not muette(texte):
			choisie = texte
			break
	var coupe := choisie.find(". ")
	return choisie.substr(0, coupe + 1) if coupe > 0 else choisie

## Raison du conseiller qui ne propose rien (« Aucun signal… », « Pas assez d’observations… »,
## « Les indicateurs ne justifient pas… ») : Gabi lit alors le match montré, plutôt que de la répéter.
static func muette(raison: String) -> bool:
	return raison.begins_with("Aucun") or raison.begins_with("Pas assez") or raison.begins_with("Les indicateurs ne justifient")

## Une phrase répétée d'une raison à l'autre (« Conservez la consigne en place. ») n'est dite
## qu'une fois, à la dernière raison qui la contient.
static func _sans_redites(raisons: Array) -> Array:
	var dites := {}
	var sortie: Array = []
	for n in range(raisons.size() - 1, -1, -1):
		var gardees: PackedStringArray = []
		for phrase: String in str(raisons[n]).split(". ", false):
			var cle := phrase.strip_edges().trim_suffix(".")
			if cle.is_empty() or dites.has(cle): continue
			dites[cle] = true
			gardees.append(cle)
		if not gardees.is_empty(): sortie.push_front(". ".join(gardees) + ".")
	return sortie

## Gabi : son portrait et une seule phrase forte (l'alerte la plus grave, sinon sa lecture du
## match, sinon sa première raison), le reste en infobulle, et l'action qui va avec.
func _remplir_adjoint(conseil: Variant, live: Dictionary, direct: Dictionary, appliquer: Callable) -> void:
	S.clear(adjoint)
	# Coup de sifflet final : Gabi annonce l'homme du match (note enregistrée, match-notes.cjs).
	var fini: bool = live.get("finished", false)
	var homme: Variant = direct.get("hommeDuMatch")
	var pourquoi: Variant = direct.get("pourquoi")
	adjoint_cadre.visible = not fini or homme is Dictionary or (pourquoi is Dictionary and not (pourquoi.get("raisons", []) as Array).is_empty())
	var carte := S.G.h(px(18))
	adjoint.add_child(carte)
	var portrait := TextureRect.new()
	var image := AtlasTexture.new()
	image.atlas = PORTRAIT
	image.region = Rect2(0, 0, 313.5, 313.5)
	image.filter_clip = true
	portrait.texture = image
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Carte de hauteur bornée (celle du portrait) ; la phrase sur deux lignes au plus (le reste en infobulle).
	portrait.custom_minimum_size = Vector2(px(84), px(84))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var matte := ShaderMaterial.new()
	matte.shader = MATTE
	portrait.material = matte
	carte.add_child(portrait)
	# Liseré droit à la couleur de notre club (liseré permis par la charte), entre le portrait et la parole de Gabi.
	var trait_club := Control.new()
	trait_club.name = "MatchBetweenAdviceStroke"
	trait_club.custom_minimum_size = Vector2(px(22), px(84))
	trait_club.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var teinte_club: Color = Charte.club_trait(terrain.couleurs[clampi(int(direct.get("camp", 0)), 0, 1)]) if terrain != null else IVOIRE
	trait_club.draw.connect(func():
		var h := trait_club.size.y
		trait_club.draw_line(Vector2(trait_club.size.x * 0.5, 0), Vector2(trait_club.size.x * 0.5, h), teinte_club, maxf(2.0, px(4))))
	carte.add_child(trait_club)
	var colonne := S.G.v(px(6))
	S.G.fill(colonne)
	colonne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	carte.add_child(colonne)
	var signature := _texte("GABI, TON ADJOINT", 16, DOUX, false, true)
	signature.name = "MatchBetweenAdviceName"
	colonne.add_child(signature)
	var graves := alertes_xv.filter(func(a: Dictionary): return a.alerte != "fatigué")
	var fatigues := alertes_xv.filter(func(a: Dictionary): return a.alerte == "fatigué")
	var phrases: Array = []
	var remplacer := -1
	if fini and homme is Dictionary:
		var equipes: Array = live.get("teams", [])
		var club := S.G.club_name(equipes[int(homme.get("camp", 0))]) if equipes.size() >= 2 else ""
		var detail := "Homme du match : %s%s, %s." % [str(homme.get("nom", "")), (" (" + club + ")") if not club.is_empty() else "", ("%.1f" % float(homme.get("note", 6.5) if homme.get("note") is float or homme.get("note") is int else 6.5)).replace(".", ",")]
		phrases.append([detail, OR])
		var chiffres: Array = []
		if int(homme.get("essais", 0)) > 0: chiffres.append("%d essai%s" % [int(homme.essais), "s" if int(homme.essais) > 1 else ""])
		if int(homme.get("plaquages", 0)) > 0: chiffres.append("%d plaquages" % int(homme.plaquages))
		if int(homme.get("metres", 0)) > 0: chiffres.append("%d m gagnés" % int(homme.metres))
		if not chiffres.is_empty(): phrases.append([" · ".join(chiffres), IVOIRE])
	for alerte: Dictionary in ([] if fini else (graves + fatigues).slice(0, 1)):
		var texte := "N° %d %s : %s." % [int(alerte.poste) + 1, str(alerte.nom), str(alerte.alerte)]
		if str(alerte.alerte) in ["épuisé", "fatigué"]: texte = "N° %d %s : %d %% d’énergie, à surveiller." % [int(alerte.poste) + 1, str(alerte.nom), roundi(float(alerte.condition))]
		if str(alerte.alerte) == "épuisé": texte = "N° %d %s est à bout (%d %%) : un remplacement s’impose." % [int(alerte.poste) + 1, str(alerte.nom), roundi(float(alerte.condition))]
		if str(alerte.alerte) in ["épuisé", "fatigué", "blessé"]: remplacer = int(alerte.poste)
		phrases.append([texte, IVOIRE, str(alerte.id)])
	var raisons: Array = []
	if conseil is Dictionary:
		for raison in [conseil.get("attackReason", ""), conseil.get("defenceReason", "")]:
			if not str(raison).is_empty(): raisons.append(str(raison))
	var lecture := _lecture(direct)
	if not lecture.is_empty(): raisons.push_front(lecture)
	raisons = _sans_redites(raisons)
	var parlantes := raisons.filter(func(r: String): return not muette(r))
	# Lecture générale sans alerte : ton posé et en retrait (ivoire atténué), l'alerte garde la couleur.
	if phrases.is_empty() and parlantes.is_empty(): phrases.append([_lecture_generale(direct), DOUX])
	if phrases.is_empty() and not raisons.is_empty(): phrases.append([_phrase_forte(raisons), IVOIRE])
	for phrase: Array in phrases:
		var etiquette := _texte("« %s »" % str(phrase[0]), 22, phrase[1], true)
		etiquette.add_theme_font_override("font", Charte.texte_moyen())
		etiquette.max_lines_visible = 4 if phrases.size() == 1 else 2
		etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		etiquette.tooltip_text = "\n".join(raisons) if not raisons.is_empty() else str(phrase[0])
		etiquette.mouse_filter = Control.MOUSE_FILTER_PASS
		# La phrase nomme un de nos joueurs : son nom mène à lui (survol : mini-fiche ; clic : sa fiche).
		if phrase.size() > 2 and not str(phrase[2]).is_empty():
			var id_phrase := str(phrase[2])
			var app_phrase: Object = _app()
			etiquette.name = "MatchBetweenAdvicePlayer"
			etiquette.mouse_filter = Control.MOUSE_FILTER_STOP
			etiquette.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			etiquette.set_meta("player_id", id_phrase)
			etiquette.gui_input.connect(func(evenement: InputEvent):
				var clic := evenement as InputEventMouseButton
				if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT: ouvrir_fiche(id_phrase))
			if app_phrase is Control: load("res://ui/carte_joueur_survol.gd").lier(app_phrase, etiquette, id_phrase, "squad")
		colonne.add_child(etiquette)
		# Lignes réservées (un texte à la ligne tronqué n'en réserve qu'une) : la carte garde la hauteur
		# du portrait et la phrase n'est jamais coupée à mi-hauteur.
		etiquette.custom_minimum_size.y = hauteur_lignes(etiquette, etiquette.max_lines_visible)
	# Les actions à droite de la carte (Gabi en largeur, sous le tableau de bord).
	var actions := S.G.h(px(10))
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if fini: _remplir_pourquoi(colonne, direct, actions)
	# D3 : Gabi dans la colonne de gauche, ses actions sous sa phrase.
	adjoint.add_child(actions)
	# L'action qui va avec la phrase : remplacer le joueur signalé, ou appliquer les consignes
	# proposées (seulement si l'adjoint propose autre chose que les consignes en place).
	if remplacer >= 0:
		var poste := remplacer
		# Le remplaçant conseillé par le staff (`live.pilotage.conseilChangement`), s'il vise ce joueur.
		# Avec la file du prochain arrêt, le remplaçant conseillé est dans la bulle de Gabi (pas en double ici).
		var entrant := "" if not MenuJoueur.arrets(live).is_empty() else _entrant_conseille(live, str(alertes_xv.filter(func(a: Dictionary): return int(a.poste) == poste)[0].id) if alertes_xv.any(func(a: Dictionary): return int(a.poste) == poste) else "")
		var libelle := "Remplacer le %d" % (poste + 1) + (" par %s" % _nom_court(entrant) if not entrant.is_empty() else "") + " →"
		var bouton_remplacer := _bouton(libelle, func(): joueur_choisi.emit(poste))
		bouton_remplacer.name = "MatchBetweenReplace"
		bouton_remplacer.tooltip_text = "L'écran Équipe sur ce joueur (le match se met en pause) · Entrée"
		bouton_remplacer.set_meta("contextual_enabled", true)
		actions.add_child(bouton_remplacer)
		actions.add_child(_touche("Entrée"))
	# Match avec file du prochain arrêt de jeu : le plan de jeu conseillé passe par les bulles de Gabi (un clic).
	elif not fini and conseil is Dictionary and (conseil.get("attackChanged", false) or conseil.get("defenceChanged", false)) and MenuJoueur.arrets(live).is_empty():
		var possible: bool = conseil.get("canAct", false) and conseil.get("defenceAvailable", false)
		var bouton := _bouton("Appliquer ses consignes →", func(): appliquer.call(conseil), possible)
		bouton.name = "MatchBetweenApplyAdvice"
		bouton.tooltip_text = "Appliquer les consignes proposées." if possible else "Mets le match en pause pour modifier tes consignes."
		actions.add_child(bouton)
		if not possible:
			# Bloqué : la touche de la pause dessinée (plus de phrase de mode d'emploi, règle du 21/11/2026).
			var raison := _touche("Espace")
			raison.name = "MatchBetweenApplyAdviceReason"
			raison.tooltip_text = "Pause (Espace) pour changer de consignes."
			raison.mouse_filter = Control.MOUSE_FILTER_PASS
			actions.add_child(raison)

## Nom du remplaçant que le staff conseille pour le joueur `sortant` (vide sans conseil ou s'il n'est plus sur le banc).
func _entrant_conseille(live: Dictionary, sortant: String) -> String:
	var conseil: Variant = _pilotage.get("conseilChangement")
	if not conseil is Dictionary or sortant.is_empty() or str(conseil.get("outId", "")) != sortant: return ""
	for joueur: Variant in live.get("reserves", []) if live.get("reserves") is Array else []:
		if joueur is Dictionary and str(joueur.get("id", "")) == str(conseil.get("inId", "")): return str(joueur.get("name", ""))
	return ""

## « Pourquoi » au coup de sifflet final (moteur : native/engine/match-pourquoi.cjs, `direct.pourquoi`) :
## trois raisons au plus, classées, chacune avec son levier ; une action par écran concerné.
func _remplir_pourquoi(colonne: VBoxContainer, direct: Dictionary, actions: HBoxContainer) -> void:
	var bloc: Variant = direct.get("pourquoi")
	if not bloc is Dictionary or not bloc.get("raisons") is Array or bloc.raisons.is_empty(): return
	var titre: String = {"victoire": "Pourquoi on a gagné", "defaite": "Pourquoi on a perdu", "nul": "Pourquoi ce nul"}.get(str(bloc.get("issue", "")), "Pourquoi ce résultat")
	var entete := _texte(titre, 22, OR)
	entete.name = "MatchWhyTitle"
	colonne.add_child(entete)
	var routes := {}
	for raison: Variant in bloc.raisons:
		if not raison is Dictionary: continue
		var ligne := S.G.h(px(10))
		ligne.name = "MatchWhy%d" % int(raison.get("rang", 0))
		colonne.add_child(ligne)
		var levier := _texte(str(raison.get("levierLabel", "")).to_upper(), 18, LEVIER_TEINTES.get(str(raison.get("levier", "")), FAIBLE))
		levier.custom_minimum_size.x = px(150)
		levier.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ligne.add_child(levier)
		var texte := _texte(str(raison.get("texte", "")), 22, IVOIRE if raison.get("sens") == "negatif" else Charte.V, true)
		texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texte.max_lines_visible = 2
		texte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		texte.tooltip_text = str(raison.get("texte", ""))
		texte.mouse_filter = Control.MOUSE_FILTER_PASS
		ligne.add_child(texte)
		var route := str(raison.get("route", ""))
		if route.is_empty() or routes.has(route): continue
		routes[route] = true
		var bouton := _bouton(str(raison.get("action", "Voir")) + " →", func(): levier_choisi.emit(route), true)
		bouton.name = "MatchWhyAction_" + str(raison.get("levier", ""))
		bouton.custom_minimum_size.y = px(48)
		bouton.tooltip_text = "Ouvrir l’écran " + route + " (le résultat reste à valider)."
		actions.add_child(bouton)

func _passe(model: Dictionary, live: Dictionary, direct: Dictionary) -> Dictionary:
	var n: int = live.get("events", []).size()
	var actuel := {"n": n, "lineup": live.get("lineup", []), "conseil": model.get("decisions", {}).get("liveAdvice")}
	if _releves.is_empty() or int(_releves[-1].n) < n: _releves.append(actuel)
	elif int(_releves[-1].n) == n: _releves[-1] = actuel
	else: _releves = [actuel]
	while _releves.size() > 60: _releves.remove_at(0)
	var borne := int(direct.get("borne", n))
	var choisi: Dictionary = {}
	for releve: Dictionary in _releves:
		if int(releve.n) <= borne: choisi = releve
	# Aucun relevé assez ancien : la composition sans alerte nouvelle, pas de conseil.
	if choisi.is_empty(): return {"lineup": _releves[0].lineup, "conseil": null}
	return choisi

## Lecture utile dès la première minute (quand le conseil du moteur n'a encore rien à dire) :
## occupation, possession et score de ce qui a été montré.
func _lecture_generale(direct: Dictionary) -> String:
	var camp := int(direct.get("camp", -1))
	if not camp in [0, 1] or est_court(direct): return "Le match se met en place : je te signale le premier joueur en difficulté."
	var valeurs := {}
	for rang: Variant in direct.get("tableau", []):
		if rang is Dictionary and not rang.get("vide", false): valeurs[str(rang.get("cle", ""))] = rang.get("valeurs", [0, 0])
	var score: Array = direct.get("score", [0, 0]) if direct.get("score") is Array else [0, 0]
	var ecart := int(score[camp]) - int(score[1 - camp]) if score.size() == 2 else 0
	if valeurs.has("occupation"):
		var o := int(valeurs.occupation[camp])
		if o >= SEUIL_LECTURE: return ("On joue dans leur moitié (%d %% d’occupation) : reste patients, les points viendront." % o) if ecart <= 0 else ("On mène et on occupe leur camp (%d %%) : garde cette pression." % o)
		if o <= 100 - SEUIL_LECTURE: return "On joue beaucoup dans notre moitié (%d %% d’occupation) : un dégagement au pied nous ferait du bien." % o
	if valeurs.has("possession"):
		var p := int(valeurs.possession[camp])
		if p >= SEUIL_LECTURE: return "On a le ballon (%d %%) : cherchons maintenant à gagner la ligne d’avantage." % p
		if p <= 100 - SEUIL_LECTURE: return "Ils ont davantage le ballon (%d %%) : une défense qui monte groupée les gênera." % (100 - p)
	if ecart < 0: return "Menés de %d point%s, mais le match reste ouvert : pas de précipitation." % [-ecart, "s" if -ecart > 1 else ""]
	return "Début de match équilibré : j’observe leur organisation et je te signale le premier joueur en difficulté."

## Une phrase tirée des chiffres du moteur : qui domine depuis cinq minutes, la discipline.
## Rien tant que l'échantillon est court (premières minutes) : l'adjoint ne s'alarme pas d'un départ.
func _lecture(direct: Dictionary) -> String:
	var camp := int(direct.get("camp", -1))
	if not camp in [0, 1] or est_court(direct): return ""
	var minutes: Array = direct.get("domination", {}).get("minutes", []) if direct.get("domination") is Dictionary else []
	if minutes.size() >= 5:
		var somme := 0.0
		for v: Variant in minutes.slice(minutes.size() - 5): somme += float(v)
		var nous := somme / 5.0 * (1.0 if camp == 0 else -1.0)
		if nous <= -35.0: return "Ils nous font reculer depuis cinq minutes : cherchons à sortir de notre camp."
		if nous >= 35.0: return "On domine depuis cinq minutes : à nous de concrétiser cette pression."
	for rang: Variant in direct.get("tableau", []):
		if rang is Dictionary and str(rang.get("cle", "")) == "penalites":
			var v: Array = rang.get("valeurs", [0, 0])
			if int(v[camp]) >= int(v[1 - camp]) + 3: return "Déjà %d pénalités concédées : attention à la discipline." % int(v[camp])
	return ""

## Entracte : la régie annonce encore son compte à rebours ; l'écran ne l'affiche plus.
func montrer_entracte(texte: String, bouton: bool, _force: bool = false) -> void:
	_entracte = [texte, bouton]

func montrer_arret(valeur: Dictionary) -> void:
	_arret = valeur
	_poser_arret_commandes()
	# La ligne d'état et sa phrase de jeu suivent l'arrêt ouvert ou fermé (carte « CARTON JAUNE » ouverte alors que le
	# terrain 2D, en retard, disait encore « X a le ballon » ; godot-match-arrets-ecran).
	if not _dernier.is_empty() and is_instance_valid(etat): _etat(_dernier[1], _dernier[2], _equipes)
	if valeur.is_empty():
		montrer_droite(vue_droite)
		return
	var cle := str(valeur.get("cle", ""))
	if str(_choix_fait.get("cle", "")) != cle: _choix_fait = {}
	arret_titre.text = "%s · %s" % [titre_arret(valeur), str(valeur.get("horloge", ""))]
	var choix: Variant = valeur.get("choix")
	var options: Array = choix.get("options", []) if choix is Dictionary and choix.get("options") is Array else []
	for enfant in arret_options.get_children():
		arret_options.remove_child(enfant)
		enfant.queue_free()
	arret_options.visible = options.size() > 1
	arret_sous_titre.visible = options.size() > 1
	if options.size() <= 1:
		arret_texte.text = str(valeur.get("texte", "")) + "\nLe match est en pause : réorganise ton équipe si besoin, puis reprends."
		_poser_arret_bouton()
		montrer_droite(vue_droite)
		return
	var entrant := str(choix.get("type", "entrant")) != "sortant"
	var staff: Dictionary = options[0]
	for option: Variant in options:
		if option is Dictionary and option.get("actuel", false): staff = option
	var retenu: Variant = _choix_fait.get("id") if not _choix_fait.is_empty() else null
	var focus: Button = null
	for option: Variant in options:
		if not option is Dictionary: continue
		var id: Variant = option.get("id")
		var bouton := Button.new()
		bouton.text = libelle_option(option)
		bouton.name = "MatchBetweenStopOption%d" % arret_options.get_child_count()
		bouton.disabled = retenu != null
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bouton.pressed.connect(_choisir_option.bind(cle, id, str(option.get("nom", "")), entrant))
		bouton.set_meta("contextual_enabled", retenu == null)
		bouton.set_meta("option_id", id)
		_style_option(bouton, false)
		if option == staff: bouton.tooltip_text = "Proposé par le staff."
		# Le nom du joueur proposé : sa mini-fiche au survol (il faut savoir qui entre ou sort).
		var app_arret: Object = _app()
		if app_arret is Control and id != null and not str(id).is_empty():
			load("res://ui/carte_joueur_survol.gd").lier(app_arret, bouton, str(id), "squad")
			# « i » à droite de la ligne : la fiche complète (le clic sur la ligne reste le choix).
			var info := _lien("i", ouvrir_fiche.bind(str(id)), "MatchBetweenStopInfo")
			info.tooltip_text = "Sa fiche complète (le choix attend) · survol de la ligne : sa mini-fiche"
			info.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
			info.offset_left = -px(44)
			info.offset_right = -px(8)
			info.offset_top = -px(18)
			info.offset_bottom = px(18)
			info.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			info.set_meta("player_id", str(id))
			bouton.add_child(info)
		var marque := (str(id) == str(retenu)) if retenu != null else bool(option.get("actuel", false))
		if marque: _marquer_option(bouton)
		if option == staff: focus = bouton
		arret_options.add_child(bouton)
	if retenu != null:
		arret_texte.text = str(valeur.get("texte", "")) + "\n" + _phrase_choix(str(_choix_fait.get("nom", "")), entrant)
		focus = arret_reprendre
	else:
		arret_texte.text = str(valeur.get("texte", "")) + "\nLe staff propose %s. Choisis qui %s :" % [_nom_initiale(str(staff.get("nom", ""))), "entre" if entrant else "sort"]
	_poser_arret_bouton()
	montrer_droite(vue_droite)
	# Clavier et manette : le choix du staff a le focus (Entrée le confirme), puis Reprendre.
	if focus != null: focus.call_deferred("grab_focus")

## Bouton du panneau d'arrêt : « Valider le choix » tant que le choix est à faire, puis « Reprendre le match ».
func _poser_arret_bouton() -> void:
	var attente := _choix_en_attente()
	arret_reprendre.text = "VALIDER LE CHOIX" if attente else "REPRENDRE LE MATCH"
	arret_aide.visible = attente
	_poser_arret_commandes()
	var equipe_lien := find_child("MatchBetweenStopTeam", true, false) as Button
	if equipe_lien != null:
		equipe_lien.disabled = attente
		equipe_lien.set_meta("contextual_enabled", not attente)

## Une décision à la fois (fiche UX §6.3) : Équipe et Réglages attendent la fin du choix du staff.
func _poser_arret_commandes() -> void:
	_appliquer_blocage()
	var bloque := _choix_en_attente()
	for bouton: BaseButton in [equipe, parametres]:
		if not is_instance_valid(bouton): continue
		bouton.set_meta("contextual_enabled", not bloque)
		bouton.disabled = bloque
		bouton.tooltip_text = "Après le choix du staff." if bloque else ("Composition, banc, cris de la touche et consignes (le match se met en pause) · T" if bouton == equipe else "Temps forts montrés.")

## Ligne d'option du panneau d'arrêt : texte crème à gauche, case rayon 6 ; survol `PANNEAU_2`, l'option
## retenue sur `SELECTION` (avec sa coche), focus : anneau doré.
func _style_option(bouton: Button, retenue: bool) -> void:
	for etat_bouton in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := _case(Charte.SELECTION if retenue else (RELIEF if etat_bouton in ["hover", "pressed"] else Color(0, 0, 0, 0)))
		if etat_bouton == "focus": _anneau(style)
		style.content_margin_left = px(16)
		style.content_margin_right = px(16)
		style.content_margin_top = px(6)
		style.content_margin_bottom = px(6)
		bouton.add_theme_stylebox_override(etat_bouton, style)
	for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(couleur, IVOIRE)
	bouton.add_theme_color_override("font_disabled_color", IVOIRE if retenue else FAIBLE)
	bouton.add_theme_font_override("font", Charte.texte_moyen())
	bouton.add_theme_font_size_override("font_size", fpx(20))
	bouton.custom_minimum_size.y = maxi(26, px(46))

## Titre du panneau d'arrêt selon le motif projeté par le moteur (`live.direct.arret.raison`).
static func titre_arret(valeur: Dictionary) -> String:
	match str(valeur.get("raison", "carton")):
		"blessure": return "BLESSURE"
		"saignement": return "SAIGNEMENT"
		"hia", "commotion": return "CHOC À LA TÊTE"
		"premiere-ligne": return "PREMIÈRE LIGNE"
	return "CARTON ROUGE" if valeur.get("rouge", false) else "CARTON JAUNE"

## « J. Dupont · Talonneur · 82 % » : nom, poste et énergie du joueur proposé.
static func libelle_option(option: Dictionary) -> String:
	var morceaux: Array[String] = [_nom_initiale(str(option.get("nom", "")))]
	var poste := str(option.get("poste", "")).strip_edges()
	if not poste.is_empty(): morceaux.append(poste.substr(0, 1).to_upper() + poste.substr(1))
	morceaux.append("%d %%" % int(option.get("energie", 0)))
	return " · ".join(morceaux)

static func _phrase_choix(nom: String, entrant: bool) -> String:
	return "Choix enregistré : %s %s." % [_nom_initiale(nom), "entre" if entrant else "sort"]

## Option retenue (choix du staff, puis choix du manager) : filet ivoire et marqueur à gauche.
func _marquer_option(bouton: Button) -> void:
	bouton.set_meta("retenue", true)
	_style_option(bouton, true)
	_cocher(bouton, true)

func _choisir_option(cle: String, id: Variant, nom: String, entrant: bool) -> void:
	if not _choix_fait.is_empty() or cle != str(_arret.get("cle", "")): return
	var app: Object = _app()
	if app == null or not app._command("match_incident_choice", {"cle": cle, "id": id}):
		arret_texte.text = str(_arret.get("texte", "")) + "\nUne décision est déjà en cours : réessaie dans un instant."
		return
	_choix_fait = {"cle": cle, "id": id, "nom": nom}
	montrer_arret(_arret)
	if not _dernier.is_empty(): _poser_phase(_dernier[1])

## Choix devenu impossible côté moteur (`live.incidentChoix` vide sans réponse du manager) :
## le staff garde sa décision, les options se figent.
func _suivre_choix(live: Dictionary) -> void:
	if _arret.is_empty() or not _choix_fait.is_empty() or not _arret.get("choix") is Dictionary: return
	if not live.has("incidentChoix") or live.incidentChoix != null: return
	var cle := str(_arret.get("cle", ""))
	if arret_options.get_child_count() == 0 or (arret_options.get_child(0) as Button).disabled: return
	for bouton: Button in arret_options.get_children(): bouton.disabled = true
	arret_texte.text = str(_arret.get("texte", "")) + "\nLe staff garde sa décision. Reprends quand tu veux."
	_poser_arret_bouton()
	_poser_arret_commandes()
	if cle != "" and arret.visible: arret_reprendre.call_deferred("grab_focus")
