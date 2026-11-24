extends "res://ui/contextual/live_view_etat.gd"
## Écran 13 « Match en direct » (live_view.gd), morceau : fonds, boutons et textes du direct ; états du bandeau ; réglages caméra.

## Fond des éléments posés sur l'image : panneau à 90 %, sans cadre ; rayon 18 (panneau) par défaut, 6 pour
## une case, `RAYON_PILULE` pour une commande (charte finale §3, §7).
static func _fond_hud(marges: Vector4, couleur: Color = Color(Charte.PANNEAU, 0.9), rayon: int = Charte.RAYON_PANNEAU) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = couleur
	style.set_corner_radius_all(rayon)
	style.anti_aliasing = true
	style.content_margin_left = marges.x
	style.content_margin_top = marges.y
	style.content_margin_right = marges.z
	style.content_margin_bottom = marges.w
	return Charte.ombrer(style, rayon)

## Puce de touche (« Espace », « Échap ») : panneau haut, texte ivoire secondaire.
static func _touche(texte: String) -> PanelContainer:
	var puce := PanelContainer.new()
	puce.name = "Touche"
	puce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Charte finale §3 : une puce de touche est une case (rayon 6).
	puce.add_theme_stylebox_override("panel", _fond_hud(Vector4(7, 1, 7, 1), Charte.PANNEAU_3, Charte.RAYON_PETIT))
	var lettre := Label.new()
	lettre.text = texte
	lettre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lettre.add_theme_font_override("font", Charte.TEXTE)
	lettre.add_theme_color_override("font_color", Charte.IVOIRE_2)
	lettre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	puce.add_child(lettre)
	return puce

## Commande du HUD (Pause, rappel Échap) : pilule, texte crème sur panneau 90 %, puce de la touche à droite (ou à
## gauche), survol en panneau plus clair, anneau doré au focus. Tout le pavé est cliquable.
func _bouton_hud(texte: String, touche: String, action: Callable, nom: String, puce_a_gauche: bool = false) -> Button:
	var bouton := Button.new()
	bouton.name = nom
	bouton.text = texte
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.set_meta("contextual_enabled", true)
	bouton.set_meta("puce_a_gauche", puce_a_gauche)
	bouton.pressed.connect(action)
	bouton.add_theme_font_override("font", Charte.texte_moyen())
	for cle in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(cle, Charte.IVOIRE)
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	var puce := _touche(touche)
	bouton.add_child(puce)
	bouton.resized.connect(_placer_puce.bind(bouton))
	return bouton

func _placer_puce(bouton: Button) -> void:
	var puce: Control = bouton.get_node_or_null("Touche")
	if puce == null: return
	puce.reset_size()
	var marge := roundf(12 * echelle)
	var x := marge if bool(bouton.get_meta("puce_a_gauche", false)) else bouton.size.x - puce.size.x - marge
	puce.position = Vector2(x, roundf((bouton.size.y - puce.size.y) * 0.5))

## Styles et tailles d'une commande du HUD à l'échelle courante.
func _habiller_bouton_hud(bouton: Button) -> void:
	var puce: PanelContainer = bouton.get_node_or_null("Touche")
	var eh := echelle * BARRE_HAUT
	var taille := roundi(BANDEAU_TAILLES.pause * eh)
	bouton.add_theme_font_size_override("font_size", taille)
	if puce != null: (puce.get_child(0) as Label).add_theme_font_size_override("font_size", taille)
	var largeur_puce := puce.get_combined_minimum_size().x if puce != null else 0.0
	var a_gauche := bool(bouton.get_meta("puce_a_gauche", false))
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var couleur := Color(Charte.PANNEAU, 0.9)
		if etat in ["hover", "pressed"]: couleur = Charte.PANNEAU_2
		if etat == "focus": couleur = Color(0, 0, 0, 0)
		var cote := roundf(16 * eh)
		var style := _fond_hud(Vector4(cote + (largeur_puce + 10 * eh if a_gauche else 0.0), 0, cote + (0.0 if a_gauche else largeur_puce + 10 * eh), 0), couleur, Charte.RAYON_PILULE)
		if etat in ["normal", "hover", "pressed", "disabled"]:
			style.border_color = LISERE
			style.set_border_width_all(1)
		if etat == "focus":
			# Anneau de focus de la charte : doré, 2 px, décalé de 2 px.
			style.border_color = Charte.OR
			style.set_border_width_all(2)
			style.set_expand_margin_all(2)
		bouton.add_theme_stylebox_override(etat, style)
	bouton.custom_minimum_size = Vector2(0, roundf(40 * eh))
	_placer_puce(bouton)

## Fond de la bande des commandes (phrase d'état, Équipe, Réglages, Plus), dans la continuité du bandeau du score :
## le même panneau à 90 %, rayon 18, à la même hauteur, derrière la phrase (à sa largeur de texte) et derrière le
## groupe des commandes. Sur la 3D, rien de la barre du haut ne reste posé à nu sur l'image.
func _fond_bande() -> void:
	var bande := bande_temps_forts
	if bande == null or not is_instance_valid(_coque_score): return
	var hauteur := maxf(_coque_score.size.y, bande.size.y)
	var haut := roundf((bande.size.y - hauteur) * 0.5)
	var marge := roundf(14 * echelle)
	var style := Charte.style_panneau(BandeauAngle.FOND, Charte.RAYON_PANNEAU, 0).duplicate() as StyleBoxFlat
	style.border_color = LISERE
	style.set_border_width_all(1)
	var groupe := Rect2()
	for enfant in bande.get_children():
		var c := enfant as Control
		if c == null or not c.visible: continue
		if c is Label and c.size_flags_horizontal & Control.SIZE_EXPAND:
			var texte := (c as Label).text.strip_edges()
			if texte.is_empty(): continue
			var largeur := c.get_theme_font("font").get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, c.get_theme_font_size("font_size")).x + 2.0 * marge
			bande.draw_style_box(style, Rect2(c.position.x, haut, minf(c.size.x, largeur), hauteur))
			continue
		var r := Rect2(c.position, c.size)
		groupe = r if groupe.size == Vector2.ZERO else groupe.merge(r)
	if groupe.size != Vector2.ZERO:
		bande.draw_style_box(style, Rect2(groupe.position.x - marge, haut, groupe.size.x + 2.0 * marge, hauteur))

func _suivre_fond_bande() -> void:
	if bande_temps_forts == null or not bande_temps_forts.visible: return
	var cle := str(bande_temps_forts.size)
	for enfant in bande_temps_forts.get_children():
		var c := enfant as Control
		if c == null: continue
		# La phrase garde une marge intérieure : son texte ne touche pas le bord de son fond.
		if c is Label and c.size_flags_horizontal & Control.SIZE_EXPAND and not c.has_theme_stylebox_override("normal"):
			var retrait := StyleBoxEmpty.new()
			retrait.content_margin_left = roundf(14 * echelle)
			retrait.content_margin_right = roundf(14 * echelle)
			c.add_theme_stylebox_override("normal", retrait)
		cle += "|%s%s%s" % [c.visible, c.position, (c as Label).text if c is Label else ""]
	if cle == _cle_bande: return
	_cle_bande = cle
	bande_temps_forts.queue_redraw()

func _segment(nom: String, fond: Color) -> PanelContainer:
	var segment := PanelContainer.new()
	segment.name = nom
	segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	segment.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	return segment

static func _texte(texte: String, police: Font, couleur: Color) -> Label:
	var etiquette := Label.new()
	etiquette.text = texte
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiquette.add_theme_font_override("font", police)
	etiquette.add_theme_color_override("font_color", couleur)
	etiquette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return etiquette

func _lien(texte: String, action: Callable) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.pressed.connect(action)
	bouton.set_meta("contextual_enabled", true)
	C.style_bouton_lien(bouton, 19)
	return bouton

## Échelle de l'écran : 1 jusqu'en 1080p, puis proportionnelle à la hauteur (1,33 en 1440p).
static func echelle_pour(hauteur: float) -> float:
	return clampf(hauteur / 1080.0, 1.0, 2.0)

## État du bandeau et du bouton de pause, sans nœud (testable seul).
## `regie_active` : la régie des temps forts cadence le match ; `action_3d` : un temps fort est
## à l'écran ; `action_figee` : ce temps fort est figé par une pause du manager ; `attente` : la 3D
## reste à l'écran entre deux temps forts contigus (le bandeau ne bat pas entre les deux).
## Rend {compact, pause (libellé), pause_possible}.
static func etat_bandeau(live: Dictionary, regie_active: bool, action_3d: bool, action_figee: bool, attente: bool = false) -> Dictionary:
	var fini := bool(live.get("finished", false))
	var arrete := bool(live.get("paused", false))
	var joue: bool
	var reduit: bool
	if regie_active:
		# Le moteur peut déjà être arrêté (mi-temps atteinte, pause d'avant l'action) pendant que le
		# temps fort se joue encore à l'écran : c'est l'image qui dit si le match joue.
		joue = (action_3d and not action_figee) or (not action_3d and not arrete)
		reduit = (action_3d and not action_figee) or (attente and not arrete)
	else:
		joue = not arrete
		reduit = not arrete and not bool(live.get("atBreak", false))
	joue = joue and not fini
	reduit = reduit and not fini and not live.is_empty()
	# Action montrée alors que le moteur est déjà arrêté : rien à mettre en pause, elle se termine.
	return {"compact": reduit, "pause": "PAUSE" if joue or (fini and not arrete) else "REPRENDRE",
		"pause_possible": not fini and not (joue and arrete)}

## Libellé affiché du bouton (« Pause » / « Reprendre ») pour l'état rendu par etat_bandeau.
static func libelle_pause(etat: Dictionary) -> String:
	return "Pause" if str(etat.get("pause", "")) == "PAUSE" else "Reprendre"

## Période sous l'horloge : « 1re MT », « 2e MT », « Prol. ».
static func periode_texte(live: Dictionary) -> String:
	if live.is_empty(): return ""
	var periode := int(live.get("period", 2 if int(live.get("minute", 0)) > 40 else 1))
	return "1re MT" if periode <= 1 else ("2e MT" if periode == 2 else "Prol.")

func _etat_bandeau() -> Dictionary:
	var action: bool = regie != null and regie.etat == regie.JEU
	var attente: bool = regie != null and regie.etat == regie.ATTENTE
	return etat_bandeau(_live(), temps_forts_actifs(), action, action and bool(regie.gel), attente)

## Pendant l'action 3D, la météo et le rappel Échap se retirent ; le bandeau du score reste entier.
func _appliquer_bandeau(valeur: bool) -> void:
	compact = valeur
	if is_instance_valid(_meteo_boite): _meteo_boite.visible = not compact
	_recouvrir = 2

## Le cadrage des temps forts tient compte de la part d'image cachée en haut et en bas.
## Même mesure que la régie au début de chaque plan.
func _recadrer() -> void:
	if regie == null or regie.etat != regie.JEU: return
	var cadrage: Variant = regie.get("cadrage")
	if cadrage == null or not is_instance_valid(clock): return
	var hauteur := maxf(1.0, size.y)
	var legende: Control = events.get_parent().get_parent().get_parent()
	cadrage.couvrir(clock.get_global_rect().end.y / hauteur + 0.03, (hauteur - legende.get_global_rect().position.y) / hauteur + 0.02)

## Minute affichée par l'horloge (« 27′ », « 40+2:15 » → « 27' », « 40+2' ») ; vide pour un mot.
static func minute_de(horloge: String) -> String:
	var tete := horloge.strip_edges()
	for coupure in ["′", ":", "'"]:
		var i := tete.find(coupure)
		if i > 0: tete = tete.substr(0, i)
	return tete + "'" if not tete.is_empty() and tete.replace("+", "").is_valid_int() else ""

## Largeur utile d'une ligne du journal (panneau moins marges et colonne des minutes).
func _largeur_journal() -> float:
	if not is_instance_valid(_legende): return 600.0
	return maxf(120.0, _legende.custom_minimum_size.x - roundf(32 * echelle) - roundf(32 * echelle) - roundf(12 * echelle) - 4.0)

## `texte` s'il tient sur une ligne de `largeur`, sinon coupé au dernier mot entier qui tient, suivi de « … ».
static func ligne_tenue(texte: String, police: Font, taille: int, largeur: float) -> String:
	if police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x <= largeur: return texte
	var mots := texte.split(" ", false)
	while mots.size() > 1:
		mots.remove_at(mots.size() - 1)
		var essai := " ".join(mots).trim_suffix(",").trim_suffix(":").strip_edges() + " …"
		if police.get_string_size(essai, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x <= largeur: return essai
	return texte.left(12) + " …"

static func _lettre(c: String) -> bool:
	return c.to_upper() != c.to_lower() or c.is_valid_int()

static func _echapper(texte: String) -> String:
	return texte.replace("[", "[lb]")

func _mini_fiche():
	return load("res://ui/immersive08/mini_fiche.gd")

func _survol_joueur(id: String, ancre: Control) -> void:
	var fiche: Control = _mini_fiche().montrer(app, id, "squad", ancre)
	# La mini-fiche se pose sur l'application : au-dessus de la scène du match (z 100).
	if fiche != null: fiche.z_index = 200

## Id de l'un de `joueurs` dont le nom est `nom` (« Eddie WHITWORTH » : casse ignorée), sinon d'après le seul nom de
## famille s'il n'appartient qu'à un joueur ; "" si personne (adversaire : pas de fiche complète).
static func joueur_par_nom(nom: String, joueurs: Array) -> String:
	var cherche := nom.strip_edges().to_lower()
	if cherche.is_empty(): return ""
	var famille := cherche.get_slice(" ", cherche.get_slice_count(" ") - 1)
	var par_famille: Array[String] = []
	for joueur: Variant in joueurs:
		if not joueur is Dictionary or joueur.get("id") == null: continue
		var complet := str(joueur.get("name", "")).strip_edges().to_lower()
		if complet.is_empty(): continue
		if complet == cherche: return str(joueur.id)
		if famille.length() >= 3 and complet.get_slice(" ", complet.get_slice_count(" ") - 1) == famille: par_famille.append(str(joueur.id))
	return par_famille[0] if par_famille.size() == 1 else ""

## Texte des deux lignes du journal (tests, captures) : [« 27' Bickerstaff gagne la touche », …].
func journal_affiche() -> Array[String]:
	var lignes: Array[String] = []
	for ligne: Array in _journal_lignes:
		if (ligne[2] as Control).visible: lignes.append(("%s %s" % [(ligne[0] as Label).text, (ligne[1] as RichTextLabel).get_parsed_text()]).strip_edges())
	return lignes

# --- Clavier : Échap, Espace, T ---------------------------------------------------

## Pastille d'état du menu (texte court, case ronde, jamais une phrase).
func _pastille_hud(texte: String, nom: String) -> PanelContainer:
	var pastille := PanelContainer.new()
	pastille.name = nom
	pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pastille.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pastille.add_theme_stylebox_override("panel", _fond_hud(Vector4(10, 2, 10, 2), Charte.PANNEAU_3, Charte.RAYON_PILULE))
	var mot := _texte(texte, Charte.texte_moyen(), Charte.IVOIRE)
	mot.name = "Mot"
	mot.add_theme_font_size_override("font_size", roundi(13 * echelle))
	pastille.add_child(mot)
	return pastille

## Petit « ? » : les raccourcis clavier s'affichent au survol ou au focus, jamais en ligne.
func _aide_touches(bulle: String, nom: String) -> PanelContainer:
	var cadre := PanelContainer.new()
	cadre.name = nom
	cadre.tooltip_text = bulle
	cadre.accessibility_name = bulle
	cadre.mouse_filter = Control.MOUSE_FILTER_STOP
	cadre.mouse_default_cursor_shape = Control.CURSOR_HELP
	cadre.custom_minimum_size = Vector2(roundf(28 * echelle), roundf(28 * echelle))
	cadre.add_theme_stylebox_override("panel", _fond_hud(Vector4.ZERO, Charte.PANNEAU_3, Charte.RAYON_PILULE))
	var signe := _texte("?", Charte.texte_moyen(), Charte.IVOIRE_2)
	signe.add_theme_font_size_override("font_size", maxi(12, roundi(14 * echelle)))
	signe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	signe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(signe)
	return cadre

func _filet() -> ColorRect:
	var filet := ColorRect.new()
	filet.color = Charte.FILET
	filet.custom_minimum_size.y = 1
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return filet

func _placer_menu() -> void:
	if not is_instance_valid(_menu_panneau): return
	_menu_panneau.reset_size()
	var taille := _menu_panneau.size
	_menu_panneau.position = Vector2(roundf((size.x - taille.x) * 0.5), roundf(maxf(size.y * 0.22, (size.y - taille.y) * 0.4)))

func _vitesse_libelle() -> String:
	if regie != null: return str(VITESSES_LIBELLES.get(str(regie.horloge), "Normale"))
	return "×%d" % int(app.tick_steps)

## Une petite fenêtre du direct est-elle ouverte ?
func fenetre_ouverte() -> bool:
	return is_instance_valid(fenetre_hote) and not fenetre_hote.is_queued_for_deletion()

static func neutraliser(racine: Node) -> Array[String]:
	var grises: Array[String] = []
	for noeud: Node in racine.find_children("*", "BaseButton", true, false):
		var bouton := noeud as BaseButton
		var nom := str(bouton.name)
		if ACTIONS_SUR_PLACE.any(func(prefixe: String) -> bool: return nom.begins_with(prefixe)): continue
		if bouton.has_meta("fiche_en_match"): continue
		# Le retour de la fiche (vers l'Effectif) est remplacé par « Retour au direct ».
		if nom == "PlayerBackToSquad":
			bouton.hide()
			continue
		bouton.disabled = true
		bouton.focus_mode = Control.FOCUS_NONE
		bouton.mouse_default_cursor_shape = Control.CURSOR_ARROW
		bouton.tooltip_text = "Disponible après le match."
		bouton.set_meta("indisponible_en_match", true)
		bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
		var repos: StyleBox = bouton.get_theme_stylebox("normal")
		if repos != null: bouton.add_theme_stylebox_override("disabled", repos)
		grises.append(nom)
	return grises

func equipe_fermee() -> void:
	director._refresh_controls()

func _choisir_cadence(index: int) -> void:
	if _reglages_temps_forts:
		regie.choisir_horloge(["lente", "normale", "rapide", "eclair"][index])
		return
	app.tick_steps = [1, 4, 12][index]
	stage.set_live_cadence(app.tick_steps)

## Appelée par la régie quand le moteur projette les temps forts : l'horloge de l'écran
## intermédiaire remplace la cadence du direct, et le niveau se choisit dans la barre.
func montrer_reglages_temps_forts(direct: Dictionary, source: Node) -> void:
	if not _reglages_temps_forts:
		_reglages_temps_forts = true
		_cadence.clear()
		for text in ["Horloge posée", "Horloge normale", "Horloge rapide", "Horloge éclair"]: _cadence.add_item(text)
		_cadence.select(maxi(0, ["lente", "normale", "rapide", "eclair"].find(source.horloge)))
		_cadence.tooltip_text = "Vitesse de l’horloge entre deux temps forts. Un temps fort se joue toujours à vitesse réelle."
	var niveaux: Array = direct.get("niveaux", [])
	if JSON.stringify(niveaux) != JSON.stringify(_niveaux):
		_niveaux = niveaux.duplicate(true)
		_niveau.clear()
		for item: Dictionary in _niveaux: _niveau.add_item(str(item.get("label", "")))
	for index in _niveaux.size():
		if _niveaux[index].get("id") == source.niveau and _niveau.selected != index: _niveau.select(index)
	_niveau.visible = not _niveaux.is_empty()
	if source.get("between") != null: source.between.montrer_niveau(str(source.niveau))

## Vrai tant qu'un temps fort reste à montrer : la causerie attend la fin de l'action.
func retient_la_causerie(live: Dictionary) -> bool:
	return regie != null and regie.retient(live)

## Vrai quand la régie des temps forts cadence elle-même le match.
func temps_forts_actifs() -> bool:
	return regie != null and _live().get("direct") is Dictionary

func _live() -> Dictionary:
	return model.get("live", {}) if model.get("live") is Dictionary else {}

func _pause() -> void:
	var live := _live()
	director.command("pause", {"paused":not live.get("paused", false)})

func choisir_camera(mode: String) -> void:
	_choose_camera(mode)

func _choose_camera(mode: String) -> void:
	var preferences: Variant = app.get("user_preferences")
	if preferences == null: stage.set_camera(mode); return
	if not preferences.set_value("camera", mode): app.notice("Réglage non enregistré", preferences.last_error)
	apply_preferences()

func apply_preferences() -> void:
	if not is_instance_valid(stage): return
	var preferences: Variant = app.get("user_preferences")
	if preferences == null: return
	var camera: String = preferences.effective_camera()
	var quality: String = str(preferences.data.quality)
	stage.set_stadium_evening(preferences.data.stadium == "evening")
	stage.set_action_motion(not bool(preferences.data.reduced_motion))
	if camera != _applied_camera:
		_applied_camera = camera
		stage.set_camera(camera)
	if quality != _applied_quality:
		_applied_quality = quality
		stage.set_quality(quality)
	for button: Button in _camera_controls:
		button.set_meta("contextual_enabled", not bool(preferences.data.reduced_motion))
		# Preferences can change without a worker/waiting transition.
		button.disabled = bool(app.waiting) or bool(preferences.data.reduced_motion)
		button.tooltip_text = "Mode calme : caméra tactique fixe." if preferences.data.reduced_motion else "Caméra conservée pour les prochains matchs."

func _fermer_tiroir() -> void:
	drawer_tab = ""
	drawer.hide()
	if regie != null: regie.tiroir_ferme()

## Chiffres du tiroir : entre deux temps forts, ceux d'avant la borne du moteur (rien d'un temps fort à venir).
func _stats(live: Dictionary) -> Array:
	if regie != null and regie.etat != regie.JEU and live.get("direct") is Dictionary and live.direct.has("statsRows"): return live.direct.statsRows
	return live.get("statsRows", [])

## Consigne en direct (fenêtre Équipe, onglet Consignes) : sans pause, gardée à l'écran jusqu'à la réponse.
func _envoyer_consigne(axe: String, valeur: String) -> void:
	_envois_consignes[axe] = valeur
	if regie != null: regie.envoyer_consigne(axe, valeur)
	else: app._command(Pilotage.COMMANDE, Pilotage.charge(axe, valeur))

## Identité de la rencontre affichée (projection du moteur, sinon les deux clubs) : l'après-match déjà montré.
static func cle_apres_match(live: Dictionary) -> String:
	var direct: Variant = live.get("direct")
	if direct is Dictionary and not str(direct.get("rencontre", "")).is_empty(): return str(direct.rencontre)
	var equipes: Array = live.get("teams", [])
	if equipes.size() < 2 or not equipes[0] is Dictionary or not equipes[1] is Dictionary: return ""
	return "%s|%s" % [str(equipes[0].get("id", "")), str(equipes[1].get("id", ""))]
