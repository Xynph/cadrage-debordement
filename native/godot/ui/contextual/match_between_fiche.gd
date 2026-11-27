extends "res://ui/contextual/match_between_outils.gd"
## Fiche joueur ouverte pendant le match et textes d'état du terrain de l'écran intermédiaire du match.

## Ligne d'état du haut pour un fait montré : arrêt de jeu (« Essai — X », « Touche pour X »,
## « Mêlée pour X ») ou possession et territoire (« X a le ballon dans son camp »).
## `camp` : équipe concernée (0/1) ; `x` : position du ballon (NAN : inconnue). Règle commune à la
## 3D (plan affiché, match_temps_forts.gd) et au terrain 2D de l'écran intermédiaire.
static func etat_du_fait(kind: String, camp: int, x: float, equipes: Array) -> String:
	var club := ""
	if camp in [0, 1] and camp < equipes.size() and equipes[camp] is Dictionary: club = S.G.club_name(equipes[camp])
	if ETATS_ARRET.has(kind):
		var modele := str(ETATS_ARRET[kind])
		if not "%s" in modele: return modele
		return modele % club if not club.is_empty() else modele.replace(" — %s", "").replace(" pour %s", "")
	if club.is_empty(): return "Le match"
	var texte := "%s a le ballon" % club
	if not is_nan(x): texte += " " + _zone(x, camp)
	return texte

## Genre de la ligne d'état d'un fait d'en-but : sa cause (« En-avant dans l'en-but — X »…) quand le moteur la donne,
## sinon le genre inchangé (ballon mort : « X a le ballon… »).
static func genre_en_but(kind: String, cause: String) -> String:
	return cause if kind == "ingoal" and cause in ["ingoal-knock-on", "held-up", "attacking-kick-grounded"] else kind

## Ligne d'état d'un fait du terrain 2D (élément de direct.deroule), « » si inexploitable.
static func etat_du_deroule(item: Dictionary, equipes: Array) -> String:
	var scene: Variant = item.get("scene")
	if not scene is Dictionary: return ""
	var camp: Variant = scene.get("possession", item.get("equipe", -1))
	if not (camp is int or camp is float): camp = item.get("equipe", -1)
	# En-avant : l'équipe fautive (equipe du fait, scene.team du moteur), pas la possession.
	var genre_fait := str(item.get("kind", scene.get("kind", "")))
	if genre_fait == "hand-fault" or genre_en_but(genre_fait, str(item.get("cause", ""))) != genre_fait: camp = item.get("equipe", scene.get("team", -1))
	if not (camp is int or camp is float): camp = -1
	var b: Variant = scene.get("ballon")
	var x: float = float(b[0]) if b is Array and (b as Array).size() >= 1 and (b[0] is float or b[0] is int) else NAN
	var kind := str(item.get("kind", scene.get("kind", "")))
	if kind == "hand-fault" and str(item.get("cause", "")) == "forward-pass": kind = "passe-en-avant"
	kind = genre_en_but(kind, str(item.get("cause", "")))
	return etat_du_fait(kind, int(camp) if (camp is int or camp is float) else -1, x, equipes)

## Le carton est l'arrêt de jeu en cours : son arrêt-décision est ouvert, ou c'est le dernier fait joué par le
## terrain 2D. Faux dès la reprise du jeu (fait suivant joué) ou pendant un autre arrêt (blessure…) :
## la phrase de jeu ne dit plus le carton (vérificateur de #1305 : pastille « CARTON JAUNE » restée avec
## « X a le ballon… », puis carton réaffiché pendant l'arrêt Blessure suivant).
func carton_en_cours() -> bool:
	if not _arret.is_empty(): return str(_arret.get("raison", "carton")) == "carton"
	return terrain != null and terrain.joue is Dictionary and str(terrain.joue.get("kind", "")) == "card"

func forcer_etat(texte: String) -> void:
	if texte == etat_force: return
	etat_force = texte
	if not texte.is_empty() and is_instance_valid(etat):
		etat.text = texte
		# Le texte imposé remplace la phrase de jeu : la pastille « ESSAI » d'un essai récent part avec elle.
		var bulles := get_node_or_null(BullesAdjoint.NOM)
		if bulles != null: bulles.appliquer_phrase()
	elif not _dernier.is_empty() and is_instance_valid(etat): _etat(_dernier[1], _dernier[2], _equipes)

func _etat(live: Dictionary, direct: Dictionary, equipes: Array) -> void:
	var possession: Variant = direct.get("possession")
	if not etat_force.is_empty(): etat.text = etat_force
	elif live.get("finished", false): etat.text = "Match terminé"
	elif live.get("atBreak", false): etat.text = "Mi-temps · on change de camp" if live.get("meteo") is Dictionary and live.meteo.get("ventDos") is Array else "Mi-temps"
	elif terrain != null and terrain.en_retard():
		# Le terrain rejoue des faits en retard sur la borne : la ligne suit le dernier fait joué
		# (celui du bandeau du fil), pas le dernier fait de la borne.
		var montre := etat_du_deroule(terrain.joue, equipes)
		etat.text = montre if not montre.is_empty() else "Le match"
	elif (possession is float or possession is int) and equipes.size() >= 2:
		var cote := clampi(int(possession), 0, 1)
		etat.text = "%s a le ballon %s" % [S.G.club_name(equipes[cote]), _zone(float(direct.get("zone", {}).get("x", 50.0)), cote)]
	else: etat.text = "Le match"
	# Sens du jeu : l'équipe en possession et la direction de son attaque sur le terrain (gauche ou droite).
	if is_instance_valid(sens_jeu):
		var p: Variant = direct.get("possession")
		var montre_p: int = terrain.possession if terrain != null and terrain.possession in [0, 1] else (int(p) if (p is int or p is float) else -1)
		sens_jeu.text = ("%s attaque %s" % [S.G.club_name(equipes[montre_p]), "vers la droite" if montre_p == 0 else "vers la gauche"]) if montre_p in [0, 1] and equipes.size() >= 2 and equipes[montre_p] is Dictionary else ""
		etat.tooltip_text = sens_jeu.text
		if is_instance_valid(phrase_trait_fm):
			var c_possession: Variant = (terrain.couleurs[montre_p] if montre_p in [0, 1] and terrain.couleurs.size() == 2 else Color(0, 0, 0, 0))
			phrase_trait_fm.color = Charte.club_trait(c_possession) if montre_p in [0, 1] else Color(0, 0, 0, 0)
	# Phrase de jeu en aplat (carton, essai, but) : reposée à chaque écriture de la ligne, pour que le texte et
	# sa pastille aillent toujours ensemble (avant : la ligne revenait à la possession, la pastille restait).
	var bulles := get_node_or_null(BullesAdjoint.NOM)
	if bulles != null: bulles.appliquer_phrase()
	_ajuster_taille(etat)

## Phase du match, dans la barre de commandes : mi-temps, pause, défilement 2D et vitesse de l'horloge.
func _poser_phase(live: Dictionary) -> void:
	if not is_instance_valid(phase): return
	var vitesse: String = HORLOGES_COURTS[maxi(0, HORLOGES_IDS.find(horloge))]
	var titre := "Match terminé" if live.get("finished", false) else ("Mi-temps" if live.get("atBreak", false) else ("Arrêt de jeu" if not _arret.is_empty() else ("En pause" if live.get("paused", false) else "%d′" % roundi(float(live.get("minute", 0))))))
	# Juste l'état du jeu : la vitesse se règle dans « Plus » et n'a pas sa place ici (retouche de Léo du 21/11/2026).
	phase.text = ("%s · décision attendue" % titre) if not _arret.is_empty() else titre
	phase.tooltip_text = "Vitesse de l’horloge : %s (menu Plus)" % vitesse
	_poser_pied()
	_ajuster_phase()

## L'état du jeu tient dans sa place de la bande des commandes (bouton « Banc » ajouté le 24/11) : la police baisse un
## peu plutôt que de couper le mot (« En paus »).
func _ajuster_phase() -> void:
	if not is_instance_valid(phase) or phase.size.x <= 1.0: return
	if not phase.has_meta("taille_base"): phase.set_meta("taille_base", phase.get_theme_font_size("font_size"))
	if not phase.resized.is_connected(_ajuster_phase): phase.resized.connect(_ajuster_phase)
	var base := int(phase.get_meta("taille_base"))
	var cadre: StyleBox = phase.get_theme_stylebox("normal")
	var place := phase.size.x - (cadre.get_margin(SIDE_LEFT) + cadre.get_margin(SIDE_RIGHT) if cadre != null else 0.0)
	var police: Font = phase.get_theme_font("font")
	var taille := base
	while taille > maxi(12, roundi(base * 0.6)) and police.get_string_size(phase.text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > place: taille -= 1
	if phase.get_theme_font_size("font_size") != taille: phase.add_theme_font_size_override("font_size", taille)

## Pied : la vitesse de l'horloge (dans Réglages) et où trouver les autres matchs (menu Plus).
func _poser_pied() -> void:
	if not is_instance_valid(pied_reglages): return
	# Plus de « Vitesse · … » sur l'écran (réglée dans « Plus ») : le pied garde le « ? » des raccourcis.
	pied_reglages.visible = false
	pied_reglages.text = "Vitesse · %s" % HORLOGES_COURTS[maxi(0, HORLOGES_IDS.find(horloge))]

func _poser_legende(equipes: Array, camp: int) -> void:
	if not is_instance_valid(legende_chiffres): return
	var cle := JSON.stringify([_nom_club(equipes, 0), _nom_club(equipes, 1), camp, terrain.couleurs, legende_chiffres.get_instance_id()])
	if cle == _legende_cle: return
	_legende_cle = cle
	S.clear(legende_chiffres)
	var nous := camp if camp in [0, 1] else 0
	for cote: int in [nous, 1 - nous]:
		# Nous : case pleine vert clair ; eux : filet bas doré (le camp, pas le club ; le nom est écrit à côté).
		var marque := ColorRect.new()
		marque.color = _teintes_duel()[0] if cote == nous else Color(0, 0, 0, 0)
		marque.custom_minimum_size = Vector2(px(18), px(12))
		marque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		marque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if cote != nous:
			var cadre := Panel.new()
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = _teintes_duel()[1]
			# Marque « vide » de l'adversaire : un filet bas épais.
			style.set_border_width_all(0)
			style.border_width_bottom = maxi(2, px(3))
			cadre.add_theme_stylebox_override("panel", style)
			cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
			S.full(cadre)
			marque.add_child(cadre)
		var nom := _texte(_nom_club(equipes, cote), 18, DOUX)
		if cote == nous:
			legende_chiffres.add_child(marque)
			legende_chiffres.add_child(nom)
			var milieu := Control.new()
			milieu.mouse_filter = Control.MOUSE_FILTER_IGNORE
			S.G.fill(milieu)
			legende_chiffres.add_child(milieu)
		else:
			legende_chiffres.add_child(nom)
			legende_chiffres.add_child(marque)

# --- Fiche joueur pendant le match ---------------------------------------------

## Fiche complète d'un de nos joueurs, posée sur l'entracte (la navigation du jeu est fermée pendant un
## match) : « ← Retour au direct » (Échap) la referme, le match reste en pause le temps de la lire.
func ouvrir_fiche(id: String) -> void:
	if fiche_vers.is_valid() and not id.is_empty():
		fiche_vers.call(id)
		return
	var app: Object = _app()
	if not app is Control or id.is_empty(): return
	var trouve: Dictionary = load("res://ui/immersive08/fiche_commune.gd").trouver(app, id, "squad")
	if trouve.is_empty(): return
	MiniFiche.cacher(app)
	var deja := is_instance_valid(fiche_match)
	if deja:
		remove_child(fiche_match)
		fiche_match.queue_free()
	_fiche_id = id
	fiche_match = Control.new()
	fiche_match.name = "MatchBetweenPlayerSheet"
	fiche_match.mouse_filter = Control.MOUSE_FILTER_STOP
	S.full(fiche_match)
	add_child(fiche_match)
	var fond := ColorRect.new()
	fond.color = FOND
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	S.full(fond)
	fiche_match.add_child(fond)
	var colonne := S.G.v(px(12))
	S.full(colonne)
	colonne.offset_left = px(28)
	colonne.offset_right = -px(28)
	colonne.offset_top = px(8)
	colonne.offset_bottom = -px(8)
	fiche_match.add_child(colonne)
	var tete := S.G.h(px(12))
	colonne.add_child(tete)
	var retour := _lien("← Retour au direct", fermer_fiche, "MatchBetweenPlayerSheetBack")
	retour.tooltip_text = "Revenir à l’entracte · Échap"
	tete.add_child(retour)
	tete.add_child(_touche("Échap"))
	var precision := _texte("Le match reste en pause. Pendant un match, la fiche se lit seulement : contrat, note et comparaison reviennent après le coup de sifflet final.", 18, DOUX)
	precision.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(precision)
	var defile := ScrollContainer.new()
	defile.name = "MatchBetweenPlayerSheetScroll"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	S.G.fill(defile, true)
	colonne.add_child(defile)
	var page: Control = load("res://ui/immersive08/player_canvas.gd").build(app, trouve.joueur, "squad")
	defile.add_child(page)
	_brancher_fiche(page, app)
	if not deja: fiche_ouverte.emit(true)
	retour.call_deferred("grab_focus")

## La fiche est faite pour l'écran Effectif : en plein match, son retour revient à l'entracte, ses onglets et
## le joueur précédent / suivant restent dans la fiche ; ce qui mène à un autre écran attend la fin du match.
func _brancher_fiche(page: Control, app: Object) -> void:
	var ids: Array = load("res://ui/immersive08/fiche_commune.gd").liste(app, "squad")
	var rang := ids.find(_fiche_id)
	for noeud: Node in page.find_children("*", "BaseButton", true, false):
		var bouton := noeud as BaseButton
		var nom := str(bouton.name)
		if nom == "PlayerBackToSquad":
			_rebrancher(bouton, fermer_fiche)
			bouton.tooltip_text = "Revenir à l’entracte · Échap"
			if bouton is Button: (bouton as Button).text = "← Retour au direct"
		elif nom.begins_with("FullPlayerTab"):
			var cible := _fiche_id
			bouton.pressed.connect(func(): ouvrir_fiche.call_deferred(cible))
		elif nom in ["FichePrecedent", "FicheSuivant"]:
			var voisin := rang + (-1 if nom == "FichePrecedent" else 1)
			if rang >= 0 and voisin >= 0 and voisin < ids.size():
				var id_voisin := str(ids[voisin])
				_rebrancher(bouton, func(): ouvrir_fiche(id_voisin))
			else: bouton.disabled = true
		elif not bouton.disabled:
			bouton.disabled = true
			bouton.tooltip_text = "Disponible après le match."

static func _rebrancher(bouton: BaseButton, action: Callable) -> void:
	for lien: Dictionary in bouton.pressed.get_connections(): bouton.pressed.disconnect(lien.callable)
	bouton.pressed.connect(action)

func fermer_fiche() -> void:
	if not is_instance_valid(fiche_match): return
	var app: Object = _app()
	if app is Control: MiniFiche.cacher(app)
	remove_child(fiche_match)
	fiche_match.queue_free()
	fiche_match = null
	_fiche_id = ""
	fiche_ouverte.emit(false)
