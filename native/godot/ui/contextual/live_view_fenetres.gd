extends "res://ui/contextual/live_view_plaques.gd"
## Écran 13 « Match en direct » (live_view.gd), morceau : petites fenêtres du direct : club, joueur, consignes.

## Nom d'un de nos joueurs cliqué (journal, bannière d'essai, fenêtre Équipe, entracte) : sa petite fenêtre par-dessus
## le match (`ouvrir_fenetre_joueur`).
func ouvrir_joueur(id: String) -> void:
	ouvrir_fenetre_joueur(id)

func _suspendre() -> void:
	var live := _live()
	if live.is_empty() or live.get("finished", false): return
	var etat := _etat_bandeau()
	# Une petite fenêtre rouverte juste après en avoir fermé une : la reprise demandée à la fermeture est encore en
	# route (bandeau toujours sur « Reprendre ») ; la pause est redemandée dès la réponse du jeu.
	if str(etat.pause) != "PAUSE" and app.waiting and Time.get_ticks_msec() - _reprise_ms < 5000:
		_reprendre_apres = true
		_pause_voulue = 1
		return
	if str(etat.pause) != "PAUSE" or not bool(etat.pause_possible): return
	_reprendre_apres = true
	# Minute du direct en route (la 3D attend la suite d'un temps fort) : la pause prend la file du jeu et part
	# dans la même réponse, avant que la minute suivante ne se lance derrière la page ou la fenêtre.
	if app.waiting and str(app.get("last_command")) == "tick" and (app.get("queued_action") as Dictionary).is_empty():
		app._command("pause", {"paused": true})
		director._refresh_controls()
	elif app.waiting: _pause_voulue = 1
	else: director.command("pause", {"paused": true})

## Relance le match s'il est en pause (et pas fini).
func _relancer() -> void:
	_reprendre_apres = false
	var live := _live()
	if live.is_empty() or live.get("finished", false) or not director._talk().is_empty(): return
	_reprise_ms = Time.get_ticks_msec()
	if app.waiting: _pause_voulue = -1
	elif live.get("paused", false): director.command("pause", {"paused": false})

# --- Menu du match (Échap) ----------------------------------------------------------

## Plaque du club `cote` (0 : recevant, 1 : visiteur) : sa petite fenêtre.
func ouvrir_fiche_club(cote: int) -> void:
	var teams: Array = _live().get("teams", [])
	if cote < 0 or cote >= teams.size() or not teams[cote] is Dictionary or teams[cote].get("id") == null: return
	ouvrir_fiche_club_id(int(float(teams[cote].id)))

## Petite fenêtre d'un club par son identifiant (plaques, autres matchs et classement en direct de l'entracte) :
## écusson ou logo, rang et points, forme récente en pastilles ; s'il joue ce match, score et chiffres du match en tuiles.
func ouvrir_fiche_club_id(id: int) -> void:
	if id < 0: return
	var teams: Array = _live().get("teams", [])
	var cote := -1
	for i in teams.size():
		if teams[i] is Dictionary and teams[i].get("id") != null and int(float(teams[i].id)) == id: cote = i
	var ligne := _ligne_classement(id)
	var club: Dictionary = _club_complet(teams[cote] if cote >= 0 else ligne if not ligne.is_empty() else {"id": id})
	if cote < 0 and ligne.is_empty() and not club.has("name"): return
	var fond := _ouvrir_fenetre(FENETRE_CLUB, S.G.club_name(club).to_upper(), 960, 490 if cote >= 0 else 300)
	fond.set_meta("club_id", id)
	var ecusson := ecusson_club(club, C.px(150))
	ecusson.name = "MatchFenetreClubEcusson"
	ecusson.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.add_child(ecusson)
	D.place(ecusson, Rect2(36, 84, 150, 150))
	var rang := int(ligne.get("rank", club.get("rank", 0)))
	var nous: bool = app.model.get("club") is Dictionary and str(app.model.club.get("id", "")) == str(id)
	Pieces.tuile(fond, Rect2(216, 84, 176, 108), ("1er" if rang == 1 else "%de" % rang) if rang > 0 else "—", "classement", Charte.IVOIRE, "MatchFenetreClubRang", 46, "", "trophy")
	Pieces.tuile(fond, Rect2(406, 84, 176, 108), str(int(ligne.get("points", club.get("points", 0)))), "points", Charte.IVOIRE, "MatchFenetreClubPoints", 46)
	# Forme : les cinq derniers résultats de championnat, le plus récent à droite.
	var forme: Array = ligne.get("form", []) if ligne.get("form") is Array else []
	forme = forme.slice(maxi(0, forme.size() - 5))
	var bloc := D.rect(fond, Rect2(596, 84, 328, 108), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	bloc.name = "MatchFenetreClubForme"
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	D.text(bloc, 14, 98, "FORME", 14, Charte.IVOIRE_2, 600, 200)
	for i in forme.size():
		var code := str(forme[i])
		var teinte: Color = FORME_TEINTES.get(code, Charte.IVOIRE_2)
		var case := D.rect(bloc, Rect2(14 + i * 62, 14, 52, 52), Color(teinte, .2), Charte.RAYON_PETIT, teinte)
		case.name = "MatchFenetreClubForme%d" % i
		case.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(case, 26, 38, code, 26, teinte, 800, 52, HORIZONTAL_ALIGNMENT_CENTER)
	if forme.is_empty(): D.text(bloc, 14, 52, "—", 30, Charte.IVOIRE_3, 700, 100)
	# Où il joue ce match, et notre club.
	var x := 216.0
	if cote >= 0:
		var lieu := "Domicile" if cote == 0 else "Extérieur"
		x += Pieces.pastille(fond, x, 208, lieu, "home" if cote == 0 else "bus", "MatchFenetreClubLieu") + 10.0
	if nous: Pieces.pastille(fond, x, 208, "Nous", "star", "MatchFenetreClubNous", "", Charte.GAIN)
	if cote < 0: return
	# Le match en cours, jamais en avance sur l'image (le moteur a une minute d'avance en temps forts) : le score du
	# bandeau, la minute de l'horloge, les essais et chiffres du direct borné (tiroir Statistiques).
	var live := _live()
	var marque := score_affiche()
	var pour := marque[cote]
	var contre := marque[1 - cote]
	var minute := clock.text.strip_edges()
	D.text(fond, 36, 300, "MATCH · %s" % (minute if not minute.is_empty() else "%d’" % maxi(1, int(live.get("minute", 0)))), 16, Charte.IVOIRE_2, 700, 400)
	var tuiles: Array = [["%d – %d" % [pour, contre], "score", Charte.GAIN if pour > contre else Charte.PERTE if pour < contre else Charte.IVOIRE, "Score"]]
	tuiles.append([str(_essais_montres(cote)), "essais", Charte.IVOIRE, "Essais"])
	for libelle: Array in [["Possession", "possession"], ["Territoire", "territoire"], ["Pénalités concédées", "pénalités"]]:
		tuiles.append([_chiffre_match(str(libelle[0]), cote), str(libelle[1]), Charte.IVOIRE, str(libelle[0]).get_slice(" ", 0)])
	var largeur := (960.0 - 72.0 - 4 * 12.0) / 5.0
	for i in tuiles.size():
		var t: Array = tuiles[i]
		Pieces.tuile(fond, Rect2(36 + i * (largeur + 12.0), 318, largeur, 128), str(t[0]), str(t[1]), t[2], "MatchFenetreClub" + str(t[3]), 50 if i > 0 else 46)

## Petite fenêtre d'un de nos joueurs : portrait, poste et numéro, note du match, énergie (jauge), niveau, puis ses
## essais, plaquages et mètres du match en tuiles. Rien pour un adversaire (pas de fiche).
func ouvrir_fenetre_joueur(id: String) -> void:
	_mini_fiche().cacher(app)
	var trouve: Dictionary = load("res://ui/immersive08/fiche_commune.gd").trouver(app, id, "squad")
	if trouve.is_empty(): return
	var joueur: Dictionary = (trouve.joueur as Dictionary).duplicate()
	var live := _live()
	var numero := -1
	var titulaire := false
	for liste: String in ["lineup", "reserves"]:
		var rangs: Array = live.get(liste, []) if live.get(liste) is Array else []
		for n in rangs.size():
			if rangs[n] is Dictionary and str(rangs[n].get("id", "")) == id:
				joueur.merge(rangs[n], true)
				titulaire = liste == "lineup"
				numero = n + 1 if titulaire else n + 16
	var direct: Dictionary = live.get("direct", {}) if live.get("direct") is Dictionary else {}
	var notes: Dictionary = direct.get("notes", {}) if direct.get("notes") is Dictionary else {}
	var cartons := {}
	var liste_cartons: Array = direct.get("cartons", []) if direct.get("cartons") is Array else []
	for carton: Variant in liste_cartons:
		if carton is Dictionary: cartons[str(carton.get("id", ""))] = carton
	var feuille: Dictionary = direct.get("feuille", {}) if direct.get("feuille") is Dictionary else {}
	var d := Tableau.donnees_joueur(joueur, notes, cartons, feuille)
	var fond := _ouvrir_fenetre(FENETRE_JOUEUR, str(joueur.get("name", "")).to_upper(), 900, 420)
	fond.set_meta("player_id", id)
	# Portrait (carte rayon 12, image recadrée).
	var cadre := D.rect(fond, Rect2(36, 84, 190, 236), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "MatchFenetreJoueurPortrait"
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image: TextureRect = S.G.portrait_lazy(int(joueur.get("portraitIndex", 0)), C.px(236), joueur)
	image.tooltip_text = ""
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.custom_minimum_size = Vector2.ZERO
	cadre.add_child(image)
	D.place(image, Rect2(-23, 0, 236, 264))
	# Poste, numéro, état : pastilles.
	var x := 254.0
	var poste := str(joueur.get("pos", ""))
	if not poste.is_empty(): x += Pieces.pastille(fond, x, 84, poste, "people", "MatchFenetreJoueurPoste") + 10.0
	if numero > 0: x += Pieces.pastille(fond, x, 84, "N° %d" % numero, "", "MatchFenetreJoueurNumero") + 10.0
	if bool(d.get("blesse", false)): Pieces.pastille(fond, x, 84, "Blessé", "warning", "MatchFenetreJoueurEtat", "", Charte.PERTE)
	elif bool(d.get("carton", false)): Pieces.pastille(fond, x, 84, "Carton jaune", "warning", "MatchFenetreJoueurEtat", "", Charte.INTENSIF)
	elif numero > 0: Pieces.pastille(fond, x, 84, "Sur le terrain" if titulaire else "Banc", "check" if titulaire else "", "MatchFenetreJoueurEtat", "", Charte.GAIN if titulaire else Charte.IVOIRE_2)
	# Note du match (barème de l'entracte), énergie, niveau.
	var largeur := (900.0 - 254.0 - 36.0 - 2 * 12.0) / 3.0
	var note_connue := notes.has(id)
	var note := float(d.get("note", 6.5))
	var teinte_note: Color = load("res://ui/contextual/match_between.gd")._teinte_note(note) if note_connue else Charte.IVOIRE_3
	Pieces.tuile(fond, Rect2(254, 136, largeur, 116), ("%.1f" % note).replace(".", ",") if note_connue else "—", "note du match", teinte_note, "MatchFenetreJoueurNote", 50, "", "rating")
	var energie := clampf(float(d.get("energie", 100.0)), 0.0, 100.0)
	var teinte_energie := Charte.CONDITION if energie >= 75.0 else Charte.INTENSIF if energie >= 55.0 else Charte.PERTE
	var tuile_energie := Pieces.tuile(fond, Rect2(254 + largeur + 12.0, 136, largeur, 116), "%d %%" % roundi(energie), "énergie", teinte_energie, "MatchFenetreJoueurEnergie", 50, "", "heart")
	D.bar(tuile_energie, Rect2(12, 12, largeur - 52, 8), energie, teinte_energie)
	# Niveau : lettre du staff (notation façon FM), jamais le chiffre du moteur.
	var fiche_niv: Dictionary = joueur
	for p: Variant in app.model.get("squad", []):
		if p is Dictionary and str(p.get("id", "")) == str(joueur.get("id", "")): fiche_niv = p
	var Notation: Script = load("res://ui/notation_staff.gd")
	var l_niv: Dictionary = Notation.lettre_champ(fiche_niv, "rating", true, app.model)
	var niveau_connu := int(l_niv.bas) >= 0
	Pieces.tuile(fond, Rect2(254 + 2 * (largeur + 12.0), 136, largeur, 116), Notation.texte_note(l_niv) if niveau_connu else "—", "niveau", Notation.couleur(int(l_niv.haut)).lightened(.15) if niveau_connu else Charte.IVOIRE, "MatchFenetreJoueurNiveau", 50)
	# Ses chiffres du match.
	for i in 3:
		var cle: String = ["essais", "plaquages", "metres"][i]
		var valeur := str(int(d.get(cle, 0))) if note_connue or not feuille.is_empty() else "—"
		Pieces.tuile(fond, Rect2(254 + i * (largeur + 12.0), 264, largeur, 100), valeur, ["essais", "plaquages", "mètres"][i], Charte.IVOIRE, "MatchFenetreJoueur" + cle.capitalize(), 42)

## Ouvre le calque d'une petite fenêtre du direct et rend son panneau (unités du gabarit 2248 × 1230, centré).
## Une fenêtre déjà ouverte est remplacée. Le match se met en pause (sauf sous la fenêtre Équipe, qui tient la pause),
## sauf `pause` faux : le match continue derrière (fenêtre d'un joueur, idée 32).
func _ouvrir_fenetre(nom: String, titre: String, largeur: float, hauteur: float, pause: bool = true) -> Panel:
	_mini_fiche().cacher(app)
	if drawer.visible: _fermer_tiroir()
	_retirer_fenetre()
	if pause and not (is_instance_valid(equipe) and equipe.visible): _suspendre()
	var hote := Control.new()
	hote.name = "MatchFenetre"
	hote.mouse_filter = Control.MOUSE_FILTER_STOP
	hote.z_index = 5
	S.full(hote)
	add_child(hote)
	fenetre_hote = hote
	# Voile sur tout l'écran (le cadre commun ne couvre que la toile au gabarit) : clic à côté = fermer.
	var voile := Button.new()
	voile.name = "MatchFenetreACote"
	voile.focus_mode = Control.FOCUS_NONE
	for etat: String in ["normal", "hover", "pressed", "focus"]:
		var fond_voile := StyleBoxFlat.new()
		fond_voile.bg_color = Color(Charte.NUIT, .45)
		voile.add_theme_stylebox_override(etat, fond_voile)
	voile.pressed.connect(func(): PetiteFenetre.fermer_derniere(get_tree()))
	S.full(voile)
	hote.add_child(voile)
	var toile := Control.new()
	toile.name = "MatchFenetreToile"
	toile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var taille := Vector2(2248, 1230) * C.density
	toile.set_anchors_preset(Control.PRESET_CENTER)
	toile.offset_left = -taille.x / 2.0
	toile.offset_right = taille.x / 2.0
	toile.offset_top = -taille.y / 2.0
	toile.offset_bottom = taille.y / 2.0
	hote.add_child(toile)
	var fond := FenetreVisuelle.ouvrir(toile, nom, titre, "", largeur, hauteur, func(): _apres_fenetre(hote))
	# Le voile du cadre commun reste cliquable (fermer) mais transparent : celui de l'écran le remplace.
	var voile_cadre := toile.find_child(nom + "Voile", true, false) as Button
	if voile_cadre != null:
		for etat: String in ["normal", "hover", "pressed", "focus"]: voile_cadre.add_theme_stylebox_override(etat, StyleBoxEmpty.new())
	# Toutes les petites fenêtres du direct en ardoise claire (teinte D), comme la fenêtre d'un joueur (Léo, 23/11).
	preload("res://ui/contextual/match_menu_joueur.gd").habiller(fond, nom)
	director._refresh_controls()
	return fond

## Fenêtre refermée (Échap, ✕, clic à côté) : le match repart s'il jouait.
func _apres_fenetre(hote: Control) -> void:
	if is_instance_valid(hote): hote.queue_free()
	if hote != fenetre_hote: return
	fenetre_hote = null
	if _reprendre_apres and not (is_instance_valid(equipe) and equipe.visible): _relancer()
	director._refresh_controls()

## Retire la fenêtre ouverte sans relancer le match (une autre la remplace).
func _retirer_fenetre() -> void:
	if not is_instance_valid(fenetre_hote): return
	for noeud: Node in fenetre_hote.find_children("*", "", true, false):
		if noeud.is_in_group(PetiteFenetre.GROUPE): noeud.remove_from_group(PetiteFenetre.GROUPE)
	remove_child(fenetre_hote)
	fenetre_hote.queue_free()
	fenetre_hote = null

## Ferme la petite fenêtre ouverte comme Échap (tests, fin de match).
func fermer_fenetre() -> void:
	if not fenetre_ouverte(): return
	for noeud: Node in fenetre_hote.find_children("*", "", true, false):
		if noeud.is_in_group(PetiteFenetre.GROUPE):
			noeud.remove_from_group(PetiteFenetre.GROUPE)
			var fermer: Variant = noeud.get_meta(PetiteFenetre.FERMER, Callable())
			if fermer is Callable and (fermer as Callable).is_valid(): (fermer as Callable).call()
			return

# --- Idée FM27 n° 33 : consignes en petite fenêtre, le match continue derrière ------------------------------------

## Ouvre la petite fenêtre des consignes (sans pause) ; `envoyer(axe, valeur)` demande un cran, qui part au
## prochain arrêt de jeu. Une veille la redessine quand le moteur change ce qu'elle montre (arrêt de jeu, bilan…).
func ouvrir_fenetre_consignes(envoyer: Callable = Callable()) -> void:
	if envoyer.is_valid(): _consignes_envoyer = envoyer
	var p: Dictionary = Pilotage.pilotage(_live())
	var fond := _ouvrir_fenetre(ConsignesFenetre.NOM, "", ConsignesFenetre.LARGEUR, ConsignesFenetre.HAUTEUR, false)
	# Même cadre que la fenêtre d'un joueur (ardoise claire, idée 32).
	JoueurFenetre.habiller(fond, ConsignesFenetre.NOM)
	var choisir := func(axe: String):
		consignes_axe = axe
		ouvrir_fenetre_consignes()
	var demander := func(axe: String, valeur: String):
		consignes_axe = axe
		if _consignes_envoyer.is_valid(): _consignes_envoyer.call(axe, valeur)
		else: app._command(Pilotage.COMMANDE, Pilotage.charge(axe, valeur))
		_suivre_consignes()
	var minute := int(_live().get("minute", 0))
	ConsignesFenetre.construire(fond, p, consignes_axe, choisir, demander, minute)
	var veille := Timer.new()
	veille.name = "MatchFenetreConsignesVeille"
	veille.wait_time = 0.4
	veille.autostart = true
	veille.ignore_time_scale = true
	fond.add_child(veille)
	var empreinte := ConsignesFenetre.signature(p, minute)
	veille.timeout.connect(func():
		if bool(app.waiting): return
		if ConsignesFenetre.signature(Pilotage.pilotage(_live()), int(_live().get("minute", 0))) != empreinte: ouvrir_fenetre_consignes())

## Redessine la fenêtre des consignes dès que la réponse du moteur est là.
func _suivre_consignes() -> void:
	var attendre := func(rappel: Callable) -> void:
		if not is_instance_valid(self) or not fenetre_ouverte() or fenetre_hote.find_child(ConsignesFenetre.NOM, true, false) == null: return
		if bool(app.waiting):
			get_tree().process_frame.connect(rappel.bind(rappel), CONNECT_ONE_SHOT)
			return
		ouvrir_fenetre_consignes()
	get_tree().process_frame.connect(attendre.bind(attendre), CONNECT_ONE_SHOT)

# --- Petites fenêtres de l'écran 2D : fait, chiffre, match du multiplex -----------------------------------------
