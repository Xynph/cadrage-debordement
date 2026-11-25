extends "res://ui/immersive08/match_avant_verifications.gd"
## Écran « Avant-match » (voir match_avant.gd) — Vérifications : « L'adversaire » (plan, joueurs à surveiller, mini-fiche, force relative) et mot de Gabi.

## 3. L'adversaire : plan probable lu par le staff, point fort, joueurs à surveiller (clic : dossier adverse), rapport de force.
const CONFIANCE := {"sure": "Lecture nette", "probable": "Probable", "incertaine": "Incertain"}

func _adversaire(model: Dictionary, next: Dictionary, data: Dictionary, nous: int) -> Control:
	var plan: Dictionary = data.get("planAdverse") if data.get("planAdverse") is Dictionary else {}
	var eux: Dictionary = next.get("away", {}) if nous == 0 else next.get("home", {})
	var legende := ""
	if Present.standings_open(eux): legende = "%s · %s pts" % [Present.rank_ordinal(eux), G.n(eux.get("points", 0))]
	var column := _tuile("TuileJoueurs", "L’adversaire", legende)
	if not plan.is_empty(): _plan_adverse(column, plan)
	else:
		column.add_child(lignes("Plan encore inconnu", 13, Charte.IVOIRE_2, 2))
	var surveiller: Dictionary = data.get("aSurveiller", {})
	var joueurs: Array = surveiller.get("joueurs", [])
	if not plan.is_empty(): joueurs = joueurs.slice(0, 2)
	if joueurs.is_empty() and plan.is_empty():
		column.add_child(lignes("Effectif encore inconnu", 13, Charte.IVOIRE_2, 3))
	for joueur: Dictionary in joueurs:
		var ligne := HBoxContainer.new()
		ligne.name = "Surveille_" + str(joueur.get("categorie", ""))
		ligne.add_theme_constant_override("separation", M(8))
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var numero := PanelContainer.new()
		numero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Charte.NUIT, .4)
		style.border_color = Charte.IVOIRE
		style.set_border_width_all(1)
		style.set_corner_radius_all(M(11))
		numero.add_theme_stylebox_override("panel", style)
		numero.custom_minimum_size = Vector2(M(24), M(22))
		numero.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var n := texte(str(int(joueur.get("numero", 0))) if joueur.get("numero") != null else "—", 13, Charte.IVOIRE, true, 700)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		numero.add_child(n)
		ligne.add_child(numero)
		var id := str(joueur.get("id", ""))
		# Clic : le XV de son club (fiche du club adverse) ; survol : ce que le jeu connaît de lui.
		var lien := _bouton_lien(str(joueur.get("name", "")), _ouvrir_joueur_adverse.bind(id, str(joueur.get("name", "")), eux), "SurveilleNom_" + str(joueur.get("categorie", "")), 13, true)
		lien.set_meta("joueur_id", id)
		_lier_mini_adverse(lien, joueur, eux)
		ligne.add_child(lien)
		var detail := "%s · %s" % [str(joueur.get("poste", "")), str(joueur.get("role", ""))]
		if joueur.get("chiffre") is String: detail += " · " + str(joueur.chiffre)
		var role := lignes(detail, 13, Charte.IVOIRE_2, 1, false, 500)
		role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		C.fill(role)
		ligne.add_child(role)
		column.add_child(ligne)
	_force_relative(column, data, nous)
	_pousse(column)
	var liens: Array = []
	if not plan.is_empty():
		var route := "Plan de jeu" if str(plan.get("action", "")) == "consignes" else "Composition"
		liens.append([str(plan.get("libelle", "Ouvrir la composition")) + " →", func(): _aller(route), "MatchCounterPlan", "Conseil de Gabi : " + str(plan.get("conseil", ""))])
	liens.append(["Dossier adverse →", _ouvrir_preparation, "MatchOpenPreparation", "Préparation : dossier de l'adversaire et rapport de force"])
	_liens(column, liens)
	return _tile_of(column)

## Mini-fiche d'un joueur adverse : survol du bouton (i) posé près du nom pendant 0,5 s (rien au survol du nom), ou touche I
## au clavier ; ce que le jeu connaît de lui, sans inventer.
## Clic sur un joueur adverse : son dossier (comme depuis la page club), sinon l'XV de son club.
func _ouvrir_joueur_adverse(id: String, nom: String, club: Dictionary) -> void:
	if not load("res://ui/prospect_profile.gd").ouvrir_dossier_adverse(app, id, nom): _ouvrir_club(club)

func _lier_mini_adverse(controle: Control, joueur: Dictionary, club: Dictionary) -> void:
	controle.tooltip_text = ""
	var info := C.icon("info", 18, Charte.IVOIRE_2)
	var taille := maxf(14.0, info.custom_minimum_size.x)
	info.name = "CarteJoueurInfo_adverse_" + str(joueur.get("categorie", "")).validate_node_name()
	info.mouse_filter = Control.MOUSE_FILTER_STOP
	info.mouse_default_cursor_shape = Control.CURSOR_HELP
	info.custom_minimum_size = Vector2(taille, taille)
	info.size = Vector2(taille, taille)
	info.z_index = 1
	info.set_meta("carte_info", true)
	controle.add_child(info)
	var poser := func():
		if is_instance_valid(info) and is_instance_valid(controle): info.position = Vector2(controle.size.x + 4.0, (controle.size.y - taille) / 2.0)
	controle.resized.connect(poser)
	poser.call()
	var delai := Timer.new()
	delai.one_shot = true
	delai.wait_time = 0.5
	info.add_child(delai)
	delai.timeout.connect(func(): _montrer_mini_adverse(joueur, club, info))
	info.mouse_entered.connect(func(): delai.start())
	info.mouse_exited.connect(func():
		delai.stop()
		MiniFiche.cacher(app, info))
	info.tree_exiting.connect(func(): MiniFiche.cacher(app, info))
	controle.mouse_exited.connect(func(): MiniFiche.cacher(app, controle))
	controle.focus_exited.connect(func(): MiniFiche.cacher(app, controle))
	controle.tree_exiting.connect(func(): MiniFiche.cacher(app, controle))
	controle.gui_input.connect(func(event: InputEvent):
		var touche := event as InputEventKey
		if touche == null or not touche.pressed or touche.echo or touche.keycode != KEY_I: return
		if MiniFiche.visible_pour(app, controle): MiniFiche.cacher(app, controle)
		else: _montrer_mini_adverse(joueur, club, controle)
		controle.accept_event())

func _montrer_mini_adverse(joueur: Dictionary, club: Dictionary, ancre: Control) -> void:
	MiniFiche.cacher(app)
	if not is_instance_valid(ancre) or not ancre.is_inside_tree(): return
	var fiche := PanelContainer.new()
	fiche.name = MiniFiche.NOM
	fiche.z_index = 100
	var fond := StyleBoxFlat.new()
	fond.bg_color = Charte.PANNEAU_3
	fond.border_color = Charte.FILET
	fond.set_border_width_all(1)
	fond.set_corner_radius_all(Charte.RAYON_CARTE)
	for cote in ["left", "right"]: fond.set("content_margin_" + cote, M(18))
	fond.content_margin_top = M(14)
	fond.content_margin_bottom = M(14)
	fiche.add_theme_stylebox_override("panel", Charte.ombrer(fond))
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", M(4))
	colonne.custom_minimum_size.x = M(340)
	fiche.add_child(colonne)
	var nom := italique(texte(str(joueur.get("name", "—")).to_upper(), 24, Charte.IVOIRE, true, 800), true)
	nom.name = "MiniFicheNom"
	colonne.add_child(nom)
	var poste_ligne: Array[String] = []
	if joueur.get("numero") != null: poste_ligne.append("n° %d" % int(joueur.numero))
	if not str(joueur.get("poste", "")).is_empty(): poste_ligne.append(str(joueur.poste))
	poste_ligne.append(G.club_name(club))
	var poste := texte(" · ".join(poste_ligne), 14, Charte.IVOIRE_2, false, 500)
	poste.add_theme_font_override("font", C.BODY)
	colonne.add_child(poste)
	var connu: Array[String] = []
	if not str(joueur.get("role", "")).is_empty(): connu.append("Rôle : " + str(joueur.role))
	if joueur.get("chiffre") is String: connu.append("%s%s" % [str(joueur.chiffre), (" · " + str(joueur.detail)) if joueur.get("detail") is String else ""])
	elif joueur.get("detail") == null: connu.append("Titulaire probable")
	for ligne_connue in connu:
		var l := lignes(ligne_connue, 14, Charte.IVOIRE, 2, false, 500)
		colonne.add_child(l)
	var inconnu := lignes("Âge, niveau et attributs : — (à observer)", 13, Charte.IVOIRE_3, 2, false, 500)
	inconnu.name = "MiniFicheInconnu"
	colonne.add_child(inconnu)
	var pied := texte("Clic : le XV de son club", 14, Charte.IVOIRE, false, 700)
	pied.add_theme_font_override("font", C.BODY)
	pied.name = "MiniFichePied"
	colonne.add_child(pied)
	MiniFiche._ignorer_souris(fiche)
	fiche.set_meta("ancre", ancre)
	app.add_child(fiche)
	fiche.size = fiche.get_combined_minimum_size()
	MiniFiche.placer(fiche, ancre, app.get_viewport_rect().size)

## « Mêlée : 64 contre 67 ▼ −3 » depuis `forces` (moyennes de la saison, la nôtre contre la leur) ; ligne omise sans donnée.
func _force_relative(column: VBoxContainer, data: Dictionary, nous: int) -> void:
	var forces: Variant = data.get("forces")
	if not forces is Dictionary: return
	var equipes: Array = forces.get("equipes", [])
	if equipes.size() < 2 or not equipes[0] is Dictionary or not equipes[1] is Dictionary: return
	var moi: Dictionary = equipes[nous]
	var lui: Dictionary = equipes[1 - nous]
	for axe: Array in [["melees", "Mêlée"], ["touches", "Touche"]]:
		var a: Variant = moi.get(axe[0])
		var b: Variant = lui.get(axe[0])
		if not (a is int or a is float) or not (b is int or b is float): continue
		var ecart := roundi(float(a)) - roundi(float(b))
		var signe := "▲ +%d" % ecart if ecart > 0 else "▼ −%d" % absi(ecart) if ecart < 0 else "= 0"
		var valeur := lignes("%d %% contre %d %% · %s" % [roundi(float(a)), roundi(float(b)), signe], 13, Charte.IVOIRE, 1, false, 500)
		valeur.name = "Force_" + str(axe[0])
		_rang(column, str(axe[1]), valeur)
		return

func _plan_adverse(column: VBoxContainer, plan: Dictionary) -> void:
	var bloc := VBoxContainer.new()
	bloc.name = "PlanAdverse"
	bloc.add_theme_constant_override("separation", 0)
	bloc.mouse_filter = Control.MOUSE_FILTER_PASS
	var lecteur: Dictionary = plan.get("lecteur", {}) if plan.get("lecteur") is Dictionary else {}
	var source := "Lecture de %s (%s)" % [str(lecteur.nom), str(lecteur.get("role", "staff"))] if lecteur.get("nom") is String else "Lecture du staff"
	bloc.tooltip_text = "%s, d'après leurs derniers matchs, la météo annoncée et notre feuille actuelle. Une lecture peut se tromper." % source
	column.add_child(bloc)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", M(8))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var puce := PanelContainer.new()
	puce.name = "PlanAdverseConfiance"
	puce.set_meta("confiance", str(plan.get("confiance", "")))
	puce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Charte.PANNEAU_3
	style.set_corner_radius_all(Charte.RAYON_PILULE)
	style.content_margin_left = M(6)
	style.content_margin_right = M(6)
	style.content_margin_top = M(1)
	style.content_margin_bottom = M(1)
	puce.add_theme_stylebox_override("panel", style)
	puce.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	puce.add_child(texte(str(CONFIANCE.get(str(plan.get("confiance", "probable")), "Probable")).to_upper(), 12, Charte.IVOIRE, true, 700))
	ligne.add_child(puce)
	var titre := lignes(str(plan.get("titre", "")), 13, Charte.IVOIRE, 1, false, 700)
	titre.name = "PlanAdverseTitre"
	C.fill(titre)
	ligne.add_child(titre)
	_rang(bloc, "Plan", ligne, "PlanLigne")
	var raison := str(plan.get("raison", ""))
	var pourquoi := lignes(raison.substr(0, 1).to_upper() + raison.substr(1), 13, Charte.IVOIRE, 2, false, 500)
	pourquoi.name = "PlanAdverseRaison"
	pourquoi.tooltip_text = raison
	pourquoi.mouse_filter = Control.MOUSE_FILTER_PASS
	_rang(bloc, "Point fort", pourquoi)
## 4. Le mot de Gabi : trois clés (numéros, titre, précision), plan de jeu et causerie ; médaillon de Gabi cliquable.
func _gabi(data: Dictionary) -> Control:
	var column := _tuile("TuileGabi", "Le mot de Gabi", "%d clés" % data.get("gabi", {}).get("cles", []).size() if data.get("gabi", {}).get("cles") is Array and not data.get("gabi", {}).get("cles", []).is_empty() else "")
	var gabi: Dictionary = data.get("gabi", {})
	var phrase := lignes("« %s »" % str(gabi.get("phrase", "On prépare ce match ensemble. Trois clés pour moi :")), 13, Charte.IVOIRE_2, 2, false, 500)
	phrase.name = "GabiPhrase"
	column.add_child(phrase)
	var cles := VBoxContainer.new()
	cles.name = "GabiCles"
	cles.add_theme_constant_override("separation", M(4))
	cles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(cles)
	var liste: Array = gabi.get("cles", []) if gabi.get("cles") is Array else []
	if liste.is_empty():
		cles.add_child(lignes("Gabi n'a pas de clés pour ce match.", 13, Charte.IVOIRE_2, 2))
	var rang := 0
	for cle: Dictionary in liste:
		rang += 1
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", M(10))
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var numero := italique(texte(str(rang), 17, Charte.IVOIRE, true, 700))
		numero.custom_minimum_size.x = M(14)
		numero.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ligne.add_child(numero)
		var mots := VBoxContainer.new()
		mots.add_theme_constant_override("separation", 0)
		mots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		C.fill(mots)
		var titre := texte(str(cle.get("titre", "")), 14, Charte.IVOIRE, false, 700)
		titre.add_theme_font_override("font", C.BODY)
		titre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		titre.clip_text = true
		mots.add_child(titre)
		var detail := lignes(str(cle.get("detail", "")), 12, Charte.IVOIRE_2, 2, false, 500)
		mots.add_child(detail)
		ligne.add_child(mots)
		cles.add_child(ligne)
	_pousse(column)
	var bas := HBoxContainer.new()
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bas.add_theme_constant_override("separation", M(8))
	var liens := VBoxContainer.new()
	liens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(liens)
	liens.add_theme_constant_override("separation", M(2))
	bas.add_child(liens)
	var plan := _bouton_lien("Ouvrir le plan de jeu →", func(): _aller("Plan de jeu"), "MatchOpenPlaybook", 14)
	var causerie := _bouton_lien("Préparer la causerie →", func(): _aller("Vestiaire"), "MatchOpenTalk", 14)
	causerie.tooltip_text = "La causerie se tient au vestiaire, au coup d'envoi : l'humeur du groupe pour la préparer."
	liens.add_child(plan)
	liens.add_child(causerie)
	var medaillon := Control.new()
	medaillon.name = "GabiMedaillon"
	medaillon.custom_minimum_size = Vector2(M(84), M(56))
	medaillon.size_flags_vertical = Control.SIZE_SHRINK_END
	medaillon.set_meta("compact", true)
	bas.add_child(medaillon)
	column.add_child(bas)
	if is_instance_valid(app.get("coach")) and app.coach.has_method("installer_bandeau"):
		app.coach.installer_bandeau(medaillon)
		_relayer_gabi.call_deferred()
		# Le portrait ne se place (et ne se dessine) qu'une fois la zone visible et dimensionnée : à chaque changement, Gabi remet sa page en ordre.
		for signal_zone: Signal in [medaillon.resized, medaillon.visibility_changed]:
			signal_zone.connect(func():
				if is_instance_valid(app) and is_instance_valid(app.get("coach")) and app.coach.has_method("_layout"): app.coach._layout.call_deferred())
	else: medaillon.hide()
	return _tile_of(column)

## Le médaillon de Gabi attend que sa zone ait une taille : le portrait ne se place qu'à la mise en page suivante (comme dans la coque).
func _relayer_gabi() -> void:
	# L'arbre est gardé : l'écran peut quitter la scène (fermeture, changement d'écran) pendant l'attente.
	if not is_inside_tree(): return
	var arbre := get_tree()
	await arbre.process_frame
	await arbre.process_frame
	# Écran encore caché ou zone sans taille (ouverture en fondu) : quelques images de plus avant de remettre Gabi en place.
	var essais := 0
	while is_inside_tree() and essais < 40 and (not is_instance_valid(app) or not _medaillon_pret()):
		essais += 1
		await arbre.process_frame
	if not is_inside_tree() or not is_instance_valid(app): return
	var coach: Variant = app.get("coach")
	if is_instance_valid(coach) and coach.has_method("_layout"): coach._layout()

func _medaillon_pret() -> bool:
	var zone := find_child("GabiMedaillon", true, false) as Control
	return zone != null and zone.is_visible_in_tree() and zone.size.x >= 20.0
