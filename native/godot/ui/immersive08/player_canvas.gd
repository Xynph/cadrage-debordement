extends RefCounted
## Fiche joueur complète (design/ux/08-fiche-joueur.md, maquette validée du 19/11/2026) : barre de retour et de
## précédent / suivant, bandeau d'identité, onglets ; la Vue d'ensemble montre les 36 attributs au barème de la charte.
## Sources : effectif (« squad »), piste du marché (« market »), Espoir du centre (« academy ») ; toute valeur vient du
## joueur projeté, une donnée absente est omise.
const C = preload("res://ui/immersive08/components.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Tactics = preload("res://ui/immersive08/tactics_canvas.gd")
const Training = preload("res://ui/immersive08/training_canvas.gd")
const Notes = preload("res://ui/coach_notes_view.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const ClubUI = preload("res://ui/immersive08/club_ui.gd")
const Academy = preload("res://ui/immersive08/academy_canvas.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")
const Roster = preload("res://ui/immersive08/squad_canvas.gd")
const NotesMatch = preload("res://ui/notes_match.gd")
const Charte = preload("res://ui/charte.gd")
const Commune = preload("res://ui/immersive08/fiche_commune.gd")
const Identity = preload("res://ui/player_identity.gd")
const Link = preload("res://ui/entity_link.gd")
const Observation = preload("res://ui/player_observation.gd")
const Sort = preload("res://ui/recruitment_sort.gd")
const Sales = preload("res://ui/player_sales_view.gd")
const FicheCharge = preload("res://ui/immersive08/fiche_charge.gd")
const FicheRoles = preload("res://ui/immersive08/fiche_roles.gd")
const TempsJeu = preload("res://ui/immersive08/fiche_temps_jeu.gd")
const Progression = preload("res://ui/immersive08/progression_fiche.gd")
const AgentJoueur = preload("res://ui/agent_joueur.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const FicheBlessures = preload("res://ui/immersive08/fiche_blessures.gd")

## Onglets : [index d'état, libellé]. L'index 1 (ancien onglet Attributs) n'existe plus : ses 36 attributs sont en
## première page ; un état resté sur 1 ouvre la Vue d'ensemble.
const ONGLETS := [[0, "Vue d’ensemble"], [2, "Performances"], [3, "Contrat"], [4, "Développement"], [5, "Repères"], [6, "Blessures"]]
const HAUTEUR := 1296
const HAUT := 332
const GAUCHE := 1420
const DROITE_X := 1440
const DROITE := 808

class ConditionDial extends Control:
	var condition := 0.0
	var ink := C.MINT

	func _draw() -> void:
		var radius := size.x * .43
		var width := maxf(1, C.px(7))
		draw_arc(size * .5, radius, -PI * .5, PI * 1.5, 64, C.LINE, width, true)
		if condition > 0:
			draw_arc(size * .5, radius, -PI * .5, -PI * .5 + TAU * condition / 100.0, 64, ink, width, true)

## Courbe des notes de match de la saison (notes enregistrées, 1 à 10), moyenne en pointillé.
class NoteCurve extends Control:
	var notes: Array[float] = []
	var etiquettes: Array[String] = []
	var moyenne := 6.5
	var ink := Charte.CLUB_TRAIT

	func _y(valeur: float, bas: float, haut: float) -> float:
		var top := float(C.px(26))
		var bottom := size.y - C.px(34)
		return lerpf(bottom, top, inverse_lerp(bas, haut, valeur))

	func _draw() -> void:
		if notes.is_empty(): return
		var font := C.font(600)
		var pixels := maxi(12, C.px(18))
		var bas := clampf(floorf(minf(notes.min(), moyenne) - .5), 1.0, 9.0)
		var haut := clampf(ceilf(maxf(notes.max(), moyenne) + .5), bas + 1.0, 10.0)
		var left := float(C.px(64))
		var right := size.x - C.px(24)
		for valeur: float in [haut, (haut + bas) / 2.0, bas]:
			var y := _y(valeur, bas, haut)
			draw_string(font, Vector2(0, y + pixels * .35), ("%.1f" % valeur).replace(".", ","), HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Charte.IVOIRE_2)
			draw_line(Vector2(left, y), Vector2(right, y), Color(Charte.FILET, .7), 1.0)
		var ya := _y(moyenne, bas, haut)
		draw_dashed_line(Vector2(left, ya), Vector2(right, ya), Color(Charte.IVOIRE_2, .8), maxf(1.0, C.px(1.5)), C.px(8))
		draw_string(font, Vector2(left + C.px(8), ya + pixels + C.px(2)), "moyenne " + ("%.1f" % moyenne).replace(".", ","), HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Charte.IVOIRE_2)
		var points := PackedVector2Array()
		for i in notes.size():
			var fraction := float(i) / (notes.size() - 1) if notes.size() > 1 else .5
			points.append(Vector2(lerpf(left + C.px(40), right - C.px(20), fraction), _y(notes[i], bas, haut)))
		if points.size() > 1: draw_polyline(points, ink, maxf(1.5, C.px(3)), true)
		for i in points.size():
			draw_circle(points[i], maxf(3.0, C.px(6)), ink, true, -1, true)
			var texte := ("%.1f" % notes[i]).replace(".", ",")
			var largeur := font.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
			draw_string(font, points[i] + Vector2(-largeur / 2.0, -C.px(12)), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Charte.IVOIRE)
			var mot := etiquettes[i] if i < etiquettes.size() else ""
			var large := font.get_string_size(mot, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
			draw_string(font, Vector2(points[i].x - large / 2.0, size.y - C.px(6)), mot, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Charte.IVOIRE_2)

static func build(app:Control,player:Dictionary,source:String="squad") -> Control:
	var page:=Control.new();page.name="ImmersivePlayerFull";page.custom_minimum_size=Vector2(2248,HAUTEUR)*C.density;C.fill(page,true)
	page.set_meta("player_id",str(player.get("id","")))
	page.set_meta("fiche_source",source)
	# Charge individuelle : sous-page de la fiche (jamais une fenêtre), avec retour et historique.
	if source=="squad" and FicheCharge.active(app,player):
		FicheCharge.build(app,page,player)
		return page
	var detailed := Commune.valeurs(player,source)
	_barre(page,app,player,source)
	_bandeau(page,app,player,source)
	var onglets: Array = ONGLETS if source=="squad" else ([[0,"Vue d’ensemble"],[4,"Développement"]] if source=="academy" else [[0,"Vue d’ensemble"]])
	var active:=int(app.management_ui.get("immersive_player_tab",0))
	if not onglets.any(func(o:Array): return int(o[0])==active): active=0
	for k in onglets.size():
		var index:int=onglets[k][0]
		_onglet(page,app,Rect2(k*236,276,224,44),str(onglets[k][1]),index,active==index)
	var top := HAUT
	match active:
		0:
			_attributs(D.panel(page,Rect2(0,top,GAUCHE,430),"","","","PlayerDetailedAttributes"),app,player,source,detailed)
			_postes(D.panel(page,Rect2(0,top+446,GAUCHE,HAUTEUR-top-446-50),"","","","PlayerPositionsCard"),app,player,source)
			if source=="market":
				_recrutement(D.panel(page,Rect2(DROITE_X,top,DROITE,500),"","","","PlayerRecruitmentCard"),app,player)
				_valeur(D.panel(page,Rect2(DROITE_X,top+516,DROITE,210),"","","","PlayerValueCard"),detailed)
			else:
				_disponibilite(D.panel(page,Rect2(DROITE_X,top,DROITE,300),"","","","PlayerAvailabilityCard"),app,player,source)
				_valeur(D.panel(page,Rect2(DROITE_X,top+316,DROITE,210),"","","","PlayerValueCard"),detailed)
				if source=="squad": _contrat_resume(D.panel(page,Rect2(DROITE_X,top+542,DROITE,HAUTEUR-top-542-50),"","","","PlayerContractCard"),app,player)
				else: _formation(D.panel(page,Rect2(DROITE_X,top+542,DROITE,HAUTEUR-top-542-50),"","","","PlayerAcademyCard"),app,player)
		2:
			_usage(D.panel(page,Rect2(0,top,1670,270),"PERFORMANCES DE LA SAISON","trophy"),app,player)
			_history(D.panel(page,Rect2(0,top+286,1670,420),"HISTORIQUE DES MATCHS","calendar","","PlayerMatchHistory"),app,player)
			_health(D.panel(page,Rect2(1686,top,562,520),"DISPONIBILITÉ","heart"),app,player)
			_selection(D.panel(page,Rect2(1686,top+536,562,270),"SÉLECTION","flag","","PlayerSelectionNotes"),app,player)
		3:
			_contrat_temps_jeu(page,app,player,top)
		4 when source=="squad" and not Progression.valeurs(player).is_empty():
			# Progression par qualité (idée FM27 n° 14) : courbe 12 mois du relevé mensuel, grille des 36 qualités à cocher.
			Progression.construire(page,app,player,top)
		4:
			_development(D.panel(page,Rect2(0,top,1670,560),"DÉVELOPPEMENT ET PROGRESSION","school","","PlayerDevelopmentCard"),app,player,source)
			var poste := BanqueImages.poste(str(player.get("pos", "")))
			D.photo(page,poste if not poste.is_empty() else "academy-player",Rect2(1686,top,562,560))
		5:
			_contexts(D.panel(page,Rect2(0,top,1498,806),"LE JOUEUR DANS LE GROUPE","people","","FullPlayerContexts"),app,player)
			_sources(D.panel(page,Rect2(1514,top,734,520),"REPÈRES DE DÉPART","info","","FullPlayerSources"),app,player)
			D.photo(page,"scouting",Rect2(1514,top+536,734,270))
		6:
			# Blessures en cours et passées (idée FM27 n° 36), dernier test de reprise à droite.
			FicheBlessures.construire(D.panel(page,Rect2(0,top,1670,HAUTEUR-top-50),"BLESSURES","heart","","PlayerInjuryHistory"),app,player)
			var test := D.panel(page,Rect2(1686,top,562,330),"TEST DE REPRISE","heart","","PlayerReturnTest")
			if not FicheBlessures.test_reprise(test,app,player):
				test.queue_free()
				D.photo(page,"medical-recovery",Rect2(1686,top,562,330))
			else: D.photo(page,"medical-recovery",Rect2(1686,top+346,562,HAUTEUR-top-50-346))
	_pied(page,app,player,source)
	return page

## Anton droite (jeton Charte.TITRE_FICHE) : nom, numéro, niveau, potentiel et titres de blocs de la fiche.
static func _anton(label: Label) -> Label:
	label.add_theme_font_override("font", Charte.TITRE_FICHE)
	return label

## Titre de carte en capitales Anton, badge à droite, filet dessous (gabarit de la maquette).
static func _titre(card: Panel, titre: String, badge: String = "") -> void:
	var largeur := card.size.x / C.density
	_anton(D.text(card,24,40,titre,26,Charte.IVOIRE,800,largeur*.5)).name = "CardTitle"
	if not badge.is_empty(): D.text(card,largeur-24,38,badge,17,Charte.IVOIRE_2,700,largeur*.45,HORIZONTAL_ALIGNMENT_RIGHT)
	D.line(card,Vector2(20,56),Vector2(largeur-20,56),Color(Charte.FILET,.9))

## Touche de clavier dessinée (« Échap », « Maj ← → ») ; renvoie sa largeur en unités.
static func _touche(parent: Control, x: float, ligne: float, texte: String) -> float:
	var police := C.font(700)
	var largeur := police.get_string_size(texte,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(12,C.px(17))).x/C.density+20
	D.rect(parent,Rect2(x,ligne-22,largeur,30),Charte.PANNEAU_3,3)
	D.text(parent,x+10,ligne-1,texte,17,Charte.IVOIRE_2,700,largeur-12)
	return largeur

## Largeur (unités) d'un texte de lien en DM Sans 500.
static func _largeur(texte: String, taille: int) -> float:
	return Charte.texte_moyen().get_string_size(texte,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(12,C.px(taille))).x/C.density + 12

## Lien texte (« ← Retour… », « Comparer → ») : bouton plat en DM Sans, focus visible ; largeur 0 = celle du texte.
static func _lien(parent: Control, zone: Rect2, texte: String, action: Callable, id: String, taille: int = 21) -> Button:
	if zone.size.x <= 0: zone.size.x = _largeur(texte,taille)
	var bouton := Link.styled_button(parent,zone,texte,taille,Charte.IVOIRE,id)
	bouton.add_theme_font_override("font",Charte.texte_moyen())
	bouton.pressed.connect(action)
	bouton.tooltip_text = texte
	return bouton

static func _barre(page: Control, app: Control, player: Dictionary, source: String) -> void:
	var retour := _lien(page,Rect2(0,4,0,38),"← "+str(Commune.RETOURS.get(source,"Retour")),func():
		app.set_meta("immersive08_full_player",false)
		app.management_ui.erase("fiche_joueur")
		app._navigate(str(Commune.ROUTES.get(source,"Effectif"))),"PlayerBackToSquad")
	retour.tooltip_text = retour.text.trim_prefix("← ") + " · Échap"
	var x := retour.size.x/C.density + 8
	x += _touche(page,x,32,"Échap") + 36
	var ids: Array[String] = Commune.liste(app,source)
	var id := str(player.get("id",""))
	var rang := ids.find(id)
	var precedent := ids[rang-1] if rang > 0 else ""
	var suivant := ids[rang+1] if rang >= 0 and rang < ids.size()-1 else ""
	var voisin := func(cible: String, sens: String, debut: float, nom: String) -> float:
		var personne: Dictionary = Commune.trouver(app,cible,source).get("joueur",{})
		var texte := sens if cible.is_empty() else (("‹ " + str(personne.get("name",""))) if sens=="‹" else (str(personne.get("name","")) + " ›"))
		var bouton := _lien(page,Rect2(debut,4,0,38),texte,func(): _ouvrir(app,cible,source),nom,20)
		bouton.disabled = cible.is_empty()
		bouton.tooltip_text = ("Joueur précédent" if sens=="‹" else "Joueur suivant") + (" · Maj+" + ("←" if sens=="‹" else "→") if not cible.is_empty() else " · début de la liste" if sens=="‹" else " · fin de la liste")
		return bouton.size.x/C.density
	x += voisin.call(precedent,"‹",x,"FichePrecedent") + 10
	var rang_texte := ("%d / %d · %s" % [rang+1,ids.size(),Commune.libelle_liste(app,source)]) if rang >= 0 else Commune.libelle_liste(app,source)
	var position := D.text(page,x,32,rang_texte,19,Charte.IVOIRE_2,500,_largeur(rang_texte,19),HORIZONTAL_ALIGNMENT_LEFT,true)
	position.name = "FicheRangListe"
	x += _largeur(rang_texte,19) + 10
	x += voisin.call(suivant,"›",x,"FicheSuivant") + 8
	_touche(page,x,32,"Maj ← →")
	if source == "squad":
		var note := "Ma note →"
		var largeur_note := _largeur(note,21)
		_lien(page,Rect2(2248-largeur_note,4,largeur_note,38),note,func():Notes.open(app,str(player.id)),"OpenPlayerCoachNote")
		var comparer := "Comparer →"
		var largeur_comparer := _largeur(comparer,21)
		# Comparateur pleine page : cette fiche rejoint la mémoire (trois joueurs au plus) puis l'écran s'ouvre.
		_lien(page,Rect2(2248-largeur_note-28-largeur_comparer,4,largeur_comparer,38),comparer,func(): load("res://ui/immersive08/comparateur_canvas.gd").ouvrir(app,str(player.id)),"FullPlayerCompare")

## Joueur voisin de la liste d'origine (Maj+← / Maj+→) : même historique que tout lien joueur.
static func _ouvrir(app: Control, id: String, source: String) -> void:
	if id.is_empty(): return
	var kind: String = {"squad":"player","market":"market","academy":"academy"}.get(source,"player")
	app.navigation_controller.open_entity({"kind":kind,"id":id})

static func _bandeau(page: Control, app: Control, player: Dictionary, source: String) -> void:
	var hero:=D.panel(page,Rect2(0,52,2248,210),"","","","FullPlayerHero")
	hero.clip_contents = true
	var portrait: TextureRect
	if not str(player.get("id","")).is_empty():
		portrait = G.portrait(int(player.get("portraitIndex",0)),C.px(210),player)
	else:
		portrait = C.photo("player-hero",Vector2.ZERO,false)
		portrait.tooltip_text = "Portrait du joueur"
	hero.add_child(portrait)
	D.place(portrait,Rect2(1,1,208,208))
	var shirt_number: Variant = player.get("shirtNumber")
	var number := G.n(shirt_number) if shirt_number != null else "—"
	var shirt := _anton(D.text(hero,212,196,number,120,Color(Charte.IVOIRE,.16),800,120))
	shirt.name="FullPlayerNumber"
	shirt.mouse_filter = Control.MOUSE_FILTER_PASS
	shirt.tooltip_text = "Numéro sur la feuille de match" if shirt_number != null else "Aucun numéro sur la feuille de match"
	D.text(hero,300,36,"FICHE JOUEUR · "+Roster.primary_caption(player).to_upper(),17,Charte.IVOIRE_2,700,1200).name = "FullPlayerKicker"
	var heading:=_anton(D.text(hero,298,92,str(player.name).to_upper(),52,Charte.IVOIRE,800,1220))
	heading.name="ProfilePlayerName"
	var facts: Dictionary = player.get("playerFacts", {}) if player.get("playerFacts") is Dictionary else {}
	var identite: HBoxContainer
	if not facts.is_empty():
		identite = Identity.row(facts,22,Charte.IVOIRE_2,app)
	else:
		identite = C.h(7)
		identite.name = "PlayerIdentityFacts"
	var age := C.label(G.n(player.get("age","—"))+" ans",22,Charte.IVOIRE_2)
	age.name = "PlayerAgeFact"
	identite.add_child(age)
	# Ordre de la maquette : drapeau, pays, âge, taille, poids, sélections.
	var origine := identite.get_node_or_null("PlayerOriginFact")
	if origine != null:
		var point := C.label("·",22,Charte.IVOIRE_2)
		identite.add_child(point)
		identite.move_child(point,origine.get_index()+1)
		identite.move_child(age,origine.get_index()+2)
		var pays := origine as Label
		pays.add_theme_color_override("font_color",Charte.IVOIRE)
	# Agent du joueur (agents nommés, ui/agent_joueur.gd) : « Agent : <nom> », clic = sa petite fenêtre.
	var agent := AgentJoueur.de_joueur(app, str(player.get("id","")))
	if not agent.is_empty():
		identite.add_child(C.label("·",22,Charte.IVOIRE_2))
		identite.add_child(AgentJoueur.visage(agent,30,"PlayerAgentFace"))
		var lien := Button.new()
		lien.name = "PlayerAgentLink"
		lien.text = "Agent : " + str(agent.get("nom",""))
		lien.tooltip_text = str(agent.get("agence",""))
		lien.flat = true
		lien.focus_mode = Control.FOCUS_ALL
		lien.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		lien.add_theme_font_override("font",C.font(700))
		lien.add_theme_font_size_override("font_size",maxi(12,C.px(22)))
		for etat in ["font_color","font_focus_color"]: lien.add_theme_color_override(etat,Pastilles.BLEU)
		lien.add_theme_color_override("font_hover_color",Charte.IVOIRE)
		var plat := C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,0)
		for etat in ["normal","hover","pressed","focus"]: lien.add_theme_stylebox_override(etat,plat)
		var ag := str(agent.get("id",""))
		var pid := str(player.get("id",""))
		var ligne := AgentJoueur.ligne_de(player,"effectif" if source == "squad" else "marche" if source == "market" else "club")
		lien.pressed.connect(func(): AgentJoueur.ouvrir(app,page,ag,pid,ligne))
		identite.add_child(lien)
	hero.add_child(identite)
	D.place(identite,Rect2(300,106,1220,34))
	var autres := Roster.secondary_tooltip(player,app.model)
	# Petite fenêtre : le plancher de 12 px ne laisse pas la place à cette ligne ; les postes restent dans la carte Postes.
	if autres != "—" and not C.dense():
		var noms: Array[String] = []
		for ligne: String in autres.split("\n"): noms.append(ligne.get_slice(" · ",1))
		D.text(hero,300,166,"Autres postes : "+", ".join(noms),19,Charte.IVOIRE_2,500,1220,HORIZONTAL_ALIGNMENT_LEFT,true).name = "PlayerOtherRoles"
	_verdict(hero,app,player,source)
	# Niveau et potentiel, à droite du bandeau.
	D.line(hero,Vector2(1600,22),Vector2(1601,188),Color(Charte.FILET,.9))
	D.text(hero,1640,40,"NIVEAU",17,Charte.IVOIRE_2,700,200)
	var niveau := _anton(D.text(hero,1640,104,G.rating_text(player,Commune.notre_joueur(source)),56,Charte.IVOIRE,800,150))
	niveau.name = "PlayerGlobalRating"
	# Flèche du niveau (moyenne des 36 qualités sur 4 semaines), comme dans l'Effectif et la Formation.
	if source=="squad" or source=="academy":
		var fl_niveau: Dictionary = load("res://ui/fleches_progression.gd").donnees(app,player).get("niveau",{})
		if not fl_niveau.is_empty(): load("res://ui/fleches_progression.gd").marquer(app,niveau,int(fl_niveau.cran),fl_niveau.serie,"Niveau","NiveauFiche")
	var largeur_niveau := Charte.TITRE_FICHE.get_string_size(niveau.text,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(12,C.px(56))).x/C.density
	D.text(hero,1640+largeur_niveau+10,104,"/ 100",22,Charte.IVOIRE_2,500,80)
	D.text(hero,1930,40,"POTENTIEL",17,Charte.IVOIRE_2,700,200)
	var potential := _anton(D.text(hero,1930,104,G.potential_text(player),56,Charte.IVOIRE,800,300))
	potential.name = "PlayerGlobalPotential"
	potential.mouse_filter = Control.MOUSE_FILTER_PASS
	potential.tooltip_text = G.potential_tooltip(player)
	var dispo := Commune.disponibilite(app,player,source)
	var etat := "Disponible" if dispo.etat == "apte" else str(dispo.texte)
	D.text(hero,1640,150,etat,20,dispo.couleur,600,580,HORIZONTAL_ALIGNMENT_LEFT,true).name = "PlayerHeroAvailability"
	if facts.get("listeElite", false):
		var liste := D.text(hero,1640,182,"Liste des 33 · XV de France",19,Charte.IVOIRE_2,600,580,HORIZONTAL_ALIGNMENT_LEFT,true)
		liste.name = "PlayerHeroListeElite"
		liste.mouse_filter = Control.MOUSE_FILTER_PASS
		liste.tooltip_text = "Liste élite du XV de France (protocole FFR-LNR) : au moins 2 repos sur 8 matchs de club."

## Verdict en une ligne : statut de feuille · condition · contrat (le contrat ouvre l'onglet Contrat).
static func _verdict(hero: Panel, app: Control, player: Dictionary, source: String) -> void:
	D.rect(hero,Rect2(300,178,6,30),Charte.club_trait(app.accent),0)
	var morceaux: Array[String] = []
	var statut := Commune.statut_feuille(player,source)
	if not statut.is_empty(): morceaux.append(statut.left(1).to_upper()+statut.substr(1))
	var forme: Variant = Commune.condition(player)
	if forme != null: morceaux.append("%d %%" % roundi(float(forme)))
	var texte := " · ".join(morceaux)
	var ligne := D.text(hero,322,202,texte,22,Charte.IVOIRE,600,700,HORIZONTAL_ALIGNMENT_LEFT,true)
	ligne.name = "PlayerVerdict"
	var fin := Commune.echeance(app,player)
	if source == "squad" and fin != "—":
		var police := C.BODY
		var x := 322.0 + (police.get_string_size(texte,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(12,C.px(22))).x/C.density if not texte.is_empty() else 0.0)
		if not texte.is_empty():
			D.text(hero,x+4,202,"·",22,Charte.IVOIRE,600,20)
			x += 18
		var lien := _lien(hero,Rect2(x,172,0,36),"contrat jusqu’en "+fin,func():
			app.management_ui.immersive_player_tab = 3
			app._render()
			ClubUI.focus(app,"FullPlayerTab3"),"PlayerVerdictContract",21)
		lien.tooltip_text = "Ouvrir le contrat et la prolongation"

static func _onglet(page: Control, app: Control, zone: Rect2, texte: String, index: int, choisi: bool) -> void:
	var id := "FullPlayerTab"+str(index)
	var tab := Button.new()
	tab.name = id
	tab.text = texte
	tab.toggle_mode = true
	tab.set_pressed_no_signal(choisi)
	tab.focus_mode = Control.FOCUS_ALL
	tab.add_theme_font_override("font",Charte.texte_moyen() if choisi else C.BODY)
	tab.add_theme_font_size_override("font_size",maxi(12,C.px(21)))
	for etat in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
		tab.add_theme_color_override(etat,Charte.PANNEAU if choisi else Charte.IVOIRE_2)
	# Charte finale : onglet en pilule, actif = aplat crème (texte panneau).
	var fond := C.box(Charte.IVOIRE if choisi else Color.TRANSPARENT,Color.TRANSPARENT,Charte.RAYON_PILULE,12)
	var survol := C.box(Charte.PANNEAU_2,Color.TRANSPARENT,Charte.RAYON_PILULE,12)
	for etat in ["normal","pressed","hover_pressed"]: tab.add_theme_stylebox_override(etat,fond)
	tab.add_theme_stylebox_override("hover",survol if not choisi else fond)
	var focus := C.box(Color.TRANSPARENT,Charte.OR,Charte.RAYON_PILULE,0)
	focus.set_border_width_all(2)
	tab.add_theme_stylebox_override("focus",focus)
	tab.pressed.connect(func():
		app.management_ui.immersive_player_tab=index
		app._render()
		ClubUI.focus(app,id))
	page.add_child(tab)
	D.place(tab,zone)

static func _attributs(card: Panel, app: Control, player: Dictionary, source: String, values: Dictionary) -> void:
	_titre(card,"ATTRIBUTS")
	Commune.legende(card,1110,40,20)
	if values.is_empty():
		var bouton := Button.new()
		Observation.configure(bouton,app,player)
		bouton.name = "PlayerObserveAttributes"
		bouton.text = "Fais-le observer pour connaître ses attributs"
		bouton.flat = true
		bouton.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bouton.add_theme_font_override("font",C.BODY)
		bouton.add_theme_font_size_override("font_size",maxi(12,C.px(18)))
		bouton.add_theme_color_override("font_color",Charte.IVOIRE)
		bouton.add_theme_color_override("font_disabled_color",Charte.IVOIRE_3)
		if not bouton.visible:
			# Aucune mission possible (joueur sans dossier d'observation) : la phrase reste lisible et mène au recrutement.
			bouton.visible = true
			bouton.disabled = not app.navigation_controller.entity_available({"kind":"menu","route":"Recrutement"})
			bouton.pressed.connect(func(): app.navigation_controller.open_entity({"kind":"menu","route":"Recrutement"}))
			bouton.tooltip_text = "Confie une mission d’observation dans Recrutement"
		card.add_child(bouton)
		D.place(bouton,Rect2(1120,14,280,36))
		bouton.custom_minimum_size = Vector2.ZERO
		bouton.size = Vector2(280,36)*C.density
		bouton.clip_text = true
		bouton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	else:
		D.text(card,1396,38,"36 ATTRIBUTS",17,Charte.IVOIRE_2,700,240,HORIZONTAL_ALIGNMENT_RIGHT)
	FicheRoles.bandes(card,Vector2(24,72),Vector2(1372,340),FicheRoles.role(str(FicheRoles.etat(app,player,values).role)))
	Commune.grille_attributs(card,Vector2(24,72),Vector2(1372,340),values,"PlayerDetailedAttribute_",{"app":app,"joueur":player} if source=="squad" else {})

## Carte Postes et rôles : rôles des postes du joueur (note du rôle + familiarité au poste), qualités du rôle choisi,
## terrain des 15 postes coloré par familiarité (fiche_roles.gd), puis courbe des notes de match.
static func _postes(card: Panel, app: Control, player: Dictionary, source: String) -> void:
	_titre(card,"POSTES ET RÔLES")
	FicheRoles.carte(card,app,player,Commune.valeurs(player,source))
	# Apprendre un poste (23/11/2026) : joueurs de notre effectif seulement, à droite du titre.
	if source != "market" and _dans_effectif(app,str(player.get("id",""))): FicheRoles.apprendre(card,app,player,card.size.x/C.density-24)
	_courbe(card,app,player,source)

static func _dans_effectif(app: Control, id: String) -> bool:
	for p: Variant in app.model.get("squad",[]):
		if p is Dictionary and str(p.get("id","")) == id: return true
	return false

static func _courbe(card: Panel, app: Control, player: Dictionary, source: String) -> void:
	if source == "market": return
	# Courbe des notes match par match (notes enregistrées de la saison, la plus ancienne à gauche).
	var notes := NotesMatch.joueur(app.model,str(player.id))
	var lignes: Array = notes.get("historique",[]) if notes.get("historique") is Array else []
	var hauteur := card.size.y / C.density
	if lignes.is_empty():
		D.text(card,24,300,"NOTE MATCH PAR MATCH",17,Charte.IVOIRE_2,700,600)
		D.text(card,24,344,"Aucun match noté cette saison",20,Charte.IVOIRE_3,500,1300,HORIZONTAL_ALIGNMENT_LEFT,true).name = "PlayerNoteCurveEmpty"
		return
	var choisies := lignes.slice(0,12)
	choisies.reverse()
	var courbe := NoteCurve.new()
	courbe.name = "PlayerNoteCurve"
	courbe.ink = Charte.club_trait(app.accent)
	for ligne: Variant in choisies:
		if not ligne is Dictionary: continue
		courbe.notes.append(float(ligne.get("note",6.5)))
		courbe.etiquettes.append("S"+G.n(int(ligne.get("semaine",0))+1))
	courbe.moyenne = float(notes.get("moyenne",6.5)) if notes.get("moyenne") != null else 6.5
	courbe.mouse_filter = Control.MOUSE_FILTER_PASS
	var resume: Array[String] = []
	for ligne: Variant in choisies:
		if ligne is Dictionary: resume.append("S%s %s : %s" % [G.n(int(ligne.get("semaine",0))+1),str(ligne.get("adversaire","")),NotesMatch.texte_note(ligne.get("note"))])
	courbe.tooltip_text = "\n".join(resume)
	D.text(card,24,292,"NOTE MATCH PAR MATCH · %s À %s" % [courbe.etiquettes[0],courbe.etiquettes[-1]],17,Charte.IVOIRE_2,700,900)
	card.add_child(courbe)
	D.place(courbe,Rect2(24,300,1372,hauteur-312))

## Colonne droite : condition, fatigue, plan de charge, satisfaction, blessure.
static func _disponibilite(card: Panel, app: Control, player: Dictionary, source: String) -> void:
	var dispo := Commune.disponibilite(app,player,source)
	_titre(card,"DISPONIBILITÉ")
	var forme: Variant = Commune.condition(player)
	var y := 96.0
	if forme != null:
		_ligne(card,y,"Condition","%d %%" % roundi(float(forme)),Charte.IVOIRE,"PlayerConditionValue")
		D.bar(card,Rect2(430,y-12,200,6),float(forme),Charte.V if float(forme) >= 85 else Charte.N)
		y += 34
	var charge: Variant = player.get("physicalLoad")
	if charge is int or charge is float:
		_ligne(card,y,"Fatigue",G.n(charge)+" / 100",Charte.IVOIRE,"PlayerFatigueValue")
		D.bar(card,Rect2(430,y-12,200,6),float(charge),Charte.N)
		y += 34
	if source == "squad":
		var plan: String = Training.INDIVIDUAL.get(player.get("loadPlan",""),"Non renseigné")
		_ligne(card,y,"Plan de charge",plan,Charte.IVOIRE,"PlayerTrainingLoadPlan")
		y += 34
		var satisfaction: Variant = null
		for member: Dictionary in app.model.get("clubLife",{}).get("relationships",{}).get("players",[]):
			if member.get("id") == player.id:
				satisfaction = member.get("score")
				break
		if satisfaction != null:
			_ligne(card,y,"Satisfaction",G.n(satisfaction)+" / 100",Charte.IVOIRE,"PlayerSatisfaction")
			y += 34
	var etat := "aucune" if dispo.etat in ["apte","reprise"] else str(dispo.texte)
	if dispo.etat == "reprise": etat = "en reprise"
	_ligne(card,y,"Blessure" if dispo.etat in ["apte","reprise","blesse"] else "Disponibilité",etat,dispo.couleur if dispo.etat != "apte" else Charte.IVOIRE,"PlayerAvailability")
	if source == "squad":
		_lien(card,Rect2(18,246,420,38),"Régler la charge individuelle →",func():Tactics._individual(app,player),"PlayerLoad",20)

static func _ligne(card: Panel, y: float, libelle: String, valeur: String, couleur: Color, id: String) -> Label:
	var largeur := card.size.x / C.density
	D.text(card,24,y,libelle,20,Charte.IVOIRE_2,500,400,HORIZONTAL_ALIGNMENT_LEFT,true)
	var texte := D.text(card,largeur-24,y,valeur,20,couleur,600,largeur-460,HORIZONTAL_ALIGNMENT_RIGHT,true)
	texte.name = id
	return texte

## Trois points forts et trois points à travailler sur les 36 attributs.
static func _valeur(card: Panel, values: Dictionary) -> void:
	_titre(card,"VALEUR","SUR 36 ATTRIBUTS")
	var paires := Commune.points(values)
	if values.is_empty():
		D.text(card,24,110,"Attributs inconnus : fais-le observer.",20,Charte.IVOIRE_3,500,700,HORIZONTAL_ALIGNMENT_LEFT,true)
		return
	for k in 2:
		var x := 24.0 + k * 392
		D.text(card,x,88,["POINTS FORTS","À TRAVAILLER"][k],16,Charte.IVOIRE_2,700,360)
		var liste: Array = paires[k]
		for i in liste.size():
			var entree: Array = liste[i]
			var y := 124.0 + i * 30
			D.text(card,x,y,str(entree[1]),19,Charte.IVOIRE,500,200,HORIZONTAL_ALIGNMENT_LEFT,true)
			D.bar(card,Rect2(x+214,y-10,90,5),float(entree[2]),Charte.IVOIRE_2)
			D.text(card,x+360,y,PlayerAttributes.caption(entree[2]),20,Charte.couleur_attribut(entree[2]),700,46,HORIZONTAL_ALIGNMENT_RIGHT).name = ("PlayerStrength_" if k == 0 else "PlayerWeakness_") + str(entree[0])

## Contrat en résumé (Vue d'ensemble) : salaire, échéance, prolongation, action.
static func _contrat_resume(card: Panel, app: Control, player: Dictionary) -> void:
	var fin: Variant = player.get("contractEnd")
	var echeance_saison: bool = fin != null and int(fin) <= int(app.model.get("meta",{}).get("season",1))
	_titre(card,"CONTRAT","ÉCHÉANCE CETTE SAISON" if echeance_saison else "")
	var y := 96.0
	if player.get("salary") is int or player.get("salary") is float:
		_ligne(card,y,"Salaire",G.salary(player.salary),Charte.IVOIRE,"PlayerSalaryValue")
		y += 34
	_ligne(card,y,"Fin de contrat",Commune.echeance(app,player),Charte.IVOIRE,"PlayerContractEndValue")
	y += 34
	var renewal: Dictionary = player.get("renewal", {}) if player.get("renewal") is Dictionary else {}
	var reason := str(renewal.get("reason", ""))
	var etat := "Disponible" if renewal.get("available",false) else (reason if not reason.is_empty() else "Non ouverte")
	_ligne(card,y,"Prolongation",etat,Charte.IVOIRE if renewal.get("available",false) else Charte.IVOIRE_2,"PlayerRenewalState")
	y += 34
	var vente := Sales.short(player)
	_ligne(card,y,"Transferts",vente if not vente.is_empty() else "Non proposé",Charte.IVOIRE if not vente.is_empty() else Charte.IVOIRE_2,"PlayerSaleShort")
	_lien(card,Rect2(470,y+34,0,40),"Marché des transferts →",func():
		app.management_ui.immersive_player_tab = 3
		app._render()
		ClubUI.focus(app,"PlayerSaleToggle","FullPlayerTab3"),"PlayerSaleOpen",20)
	y -= 34
	# Pilule à contour (charte §7.1) : Continuer porte l'unique aplat doré de l'écran.
	var offer:=Kit.bouton_ivoire(card,Rect2(24,y+64,440,48),"Proposer une prolongation",func():app.SquadViews.contract(app,player,false),"OfferRenewal")
	offer.disabled=not renewal.get("available",false) or not app._live().is_empty()
	if not reason.is_empty(): offer.tooltip_text = reason

## Piste du marché : conditions connues et actions du recrutement (suivre, observer, approcher).
static func _recrutement(card: Panel, app: Control, player: Dictionary) -> void:
	_titre(card,"RECRUTEMENT",Sort.report_label(player).to_upper())
	var player_id := str(player.get("id",""))
	var y := 96.0
	var fee: Variant = player.get("fee")
	_ligne(card,y,"Prime d’acquisition",G.euros(fee) if fee is int or fee is float else "—",Charte.IVOIRE,"PlayerMarketFee")
	y += 34
	_ligne(card,y,"Salaire demandé",G.salary(player.get("salary")) if player.get("salary") is int or player.get("salary") is float else "—",Charte.IVOIRE,"PlayerMarketSalary")
	y += 34
	var max_years := int(player.get("maxYears",0))
	if max_years > 0:
		_ligne(card,y,"Durée proposée","%s à %s ans" % [G.n(player.get("minYears",1)),G.n(max_years)] if max_years > 1 else "1 an",Charte.IVOIRE,"PlayerMarketYears")
		y += 34
	var warning := str(player.get("reason",""))
	if not warning.is_empty():
		D.text(card,24,y,warning,19,Charte.D,500,760,HORIZONTAL_ALIGNMENT_LEFT,true).name = "PlayerMarketReason"
		y += 34
	var context: Variant = app.model.get("clubLife", {}).get("managerCareer", {}).get("context")
	var can_track: bool = not app.waiting and app._live().is_empty() and app.model.get("meta",{}).get("phase", "") != "ended"
	var suivi: bool = player_id in app.management_ui.get("shortlist",[])
	var track := D.button(card,Rect2(24,y+20,370,46),"Retirer du suivi" if suivi else "Suivre cette piste",func():
		app._command("manager_recruitment_watch", {"context": context.duplicate(true), "playerId": player_id}),false,"star",true,app.accent,"Follow"+player_id.replace(":","_"))
	track.disabled = not can_track or not context is Dictionary
	if player.get("scouting") is Dictionary:
		var observer := D.button(card,Rect2(410,y+20,374,46),"",func(): pass,false,"search",true,app.accent,"ObserveRecruitment")
		Observation.configure(observer,app,player)
	var consultation_only: bool = player.get("negotiation",{}).get("status","") == "withdrawn"
	var offer := D.button(card,Rect2(24,y+82,760,50),"Consulter la discussion" if consultation_only else "Approcher le joueur",func(): app.SquadViews.contract(app, player, true),false,"arrow",false,app.accent,"OfferRecruitment")
	offer.set_meta("player_id",player_id)
	offer.disabled = app.waiting or (not player.get("available", false) and not consultation_only) or not app._live().is_empty()
	if not warning.is_empty(): offer.tooltip_text = warning

## Espoir du centre : temps de jeu et suivi individuel (spécialisation dans l'onglet Développement).
static func _formation(card: Panel, app: Control, player: Dictionary) -> void:
	_titre(card,"FORMATION")
	var y := 96.0
	if player.get("minutes") is int or player.get("minutes") is float:
		_ligne(card,y,"Temps de jeu",G.n(player.minutes)+" min",Charte.IVOIRE,"PlayerAcademyMinutes")
		y += 34
	var progress: Dictionary = player.get("development",{}) if player.get("development") is Dictionary else {}
	var options := {}
	for option: Variant in progress.get("options",[]):
		if option is Dictionary: options[option.get("id")] = option.get("label")
	if progress.get("focus") != null and options.has(progress.focus):
		_ligne(card,y,"Spécialisation",str(options[progress.focus]),Charte.IVOIRE,"PlayerAcademyFocus")
		y += 34
	_lien(card,Rect2(18,y+6,520,38),"Suivi individuel et spécialisation →",func():
		app.management_ui.immersive_player_tab = 4
		app._render()
		ClubUI.focus(app,"FullPlayerTab4"),"PlayerAcademyProgress",20)

static func _pied(page: Control, app: Control, player: Dictionary, source: String) -> void:
	var ids := Commune.liste(app,source)
	var rang := ids.find(str(player.get("id","")))
	var gauche := str(player.get("name","")) + ((" · %d / %d · %s" % [rang+1,ids.size(),Commune.libelle_liste(app,source)]) if rang >= 0 else "")
	D.text(page,0,HAUTEUR-14,gauche,18,Charte.IVOIRE_2,500,1100,HORIZONTAL_ALIGNMENT_LEFT,true).name = "FichePied"

static func _health(card:Panel,app:Control,player:Dictionary) -> void:
	var injury := float(player.get("injury", 0))
	var recovering := injury <= 0 and P.player_in_recovery(app.model, str(player.id))
	var condition := clampf(float(player.get("condition", 0)), 0, 100)
	var condition_color := C.AMBER if condition < 85 else C.MINT
	var dial := ConditionDial.new()
	dial.name = "PlayerConditionDial"
	dial.condition = condition
	dial.ink = condition_color
	dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(dial)
	D.place(dial, Rect2(23,68,86,86))
	var pulse := C.icon("heart", 38, condition_color)
	dial.add_child(pulse)
	D.place(pulse, Rect2(24,24,38,38))
	D.text(card,123,112,G.n(condition)+" %",62,condition_color,700,180)
	D.text(card,123,149,"CONDITION PHYSIQUE",22,C.MUTED,500,180)
	D.line(card,Vector2(319,70),Vector2(319,154))
	D.text(card,348,112,G.n(player.get("physicalLoad",0)),62,C.GOLD,700,190)
	D.text(card,348,149,"FATIGUE",22,C.MUTED,500,190)
	D.line(card,Vector2(24,175),Vector2(538,175))
	var available := "Disponible pour le groupe"
	if injury > 0: available = preload("res://ui/club_mail.gd").injury_label(app.model, player)+" · "+G.n(injury)+" sem."
	elif recovering: available = "En reprise"
	D.text(card,24,222,available,29,C.ALERT if injury>0 else C.GOLD if recovering else C.MINT,700,514).name = "PlayerAvailability"
	var show_medical := injury > 0 or recovering
	if show_medical: D.photo(card,"medical-recovery",Rect2(306,245,232,174))
	var satisfaction: Variant = null
	for member: Dictionary in app.model.get("clubLife",{}).get("relationships",{}).get("players",[]):
		if member.get("id") == player.id:
			satisfaction = member.get("score")
			break
	var width := 266 if show_medical else 514
	_health_fact(card,245,width,"SATISFACTION DU JOUEUR",G.n(satisfaction)+" / 100" if satisfaction!=null else "Non renseignée","PlayerSatisfaction")
	var plan: String = Training.INDIVIDUAL.get(player.get("loadPlan",""),"Non renseigné")
	_health_fact(card,335,width,"PLAN DE CHARGE",plan,"PlayerTrainingLoadPlan")
	D.button(card,Rect2(24,447,514,45),"Régler la charge individuelle",func():Tactics._individual(app,player),false,"arrow",true,app.accent,"PlayerLoad")

static func _health_fact(card: Panel, y: int, width: int, caption: String, value: String, id: String) -> void:
	var fact := D.rect(card,Rect2(24,y,width,80),Color("121c1c"),5,C.LINE)
	D.text(fact,14,29,caption,20,C.MUTED,600,width-28)
	D.text(fact,14,61,value,28,C.IVORY,600,width-28).name = id

static func _usage(card:Panel,app:Control,player:Dictionary) -> void:
	var stats:Array=[[G.n(player.get("appearances",0)),"APPARITIONS"],[G.n(player.get("minutes",0)),"MINUTES"]]
	for i in stats.size():
		var x:=24+i*196
		D.text(card,x,145,stats[i][0],64,C.IVORY,700,180)
		D.text(card,x,182,stats[i][1],22,C.MUTED,600,180)
	# Notes de match (match-notes.cjs) : moyenne de la saison et forme des 5 derniers matchs.
	var notes := NotesMatch.joueur(app.model,str(player.id))
	var moyenne: Variant = notes.get("moyenne")
	if moyenne != null:
		var pastille := NotesMatch.pastille(card,Rect2(416,88,124,66),float(moyenne),0.95)
		pastille.name = "FullPlayerNoteAverage"
	else:
		D.text(card,478,145,"—",64,C.MUTED,700,124,HORIZONTAL_ALIGNMENT_CENTER).name = "FullPlayerNoteAverage"
	var matchs := int(notes.get("matchs",0))
	# Deux lignes (le libellé entier ne tient pas sur 184 px) : « MOYENNE SAISON » puis « N matchs ».
	# Petite fenêtre (1280×720) : la police ne descend pas sous 12 px, le libellé entier déborderait : forme courte.
	var libelle := "MOYENNE SAISON"
	if C.BODY.get_string_size(libelle,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(12,C.px(20))).x > C.px(184): libelle = "MOY. SAISON"
	var legende := D.text(card,416,182,libelle,20,C.MUTED,600,184,HORIZONTAL_ALIGNMENT_LEFT,true)
	legende.name = "FullPlayerNoteMatches"
	legende.tooltip_text = "Moyenne de la saison en cours sur %d match%s (notes de 1 à 10, 6,5 au coup d’envoi)." % [matchs,"s" if matchs>1 else ""]
	if matchs>0:
		var nombre := D.text(card,416,210,"%d match%s" % [matchs,"s" if matchs>1 else ""],20,C.IVORY,600,184,HORIZONTAL_ALIGNMENT_LEFT,true)
		nombre.name = "FullPlayerNoteCount"
		nombre.tooltip_text = legende.tooltip_text
	NotesMatch.pastilles(card,Vector2(600,96),NotesMatch.forme(notes),Vector2(54,50),7.0,0.7).name = "FullPlayerForm"
	var titres := int(notes.get("hommeDuMatch",0))
	var xv := int(notes.get("selections",0))
	D.text(card,600,182,"FORME · 5 DERNIERS" + (" · %d× HOMME DU MATCH" % titres if titres>0 else "") + (" · %d× XV DE LA JOURNÉE" % xv if xv>0 else ""),22,C.GOLD if titres>0 or xv>0 else C.MUTED,600,300)
	_moyennes(card,notes)
	D.line(card,Vector2(914,80),Vector2(914,245))
	D.text(card,946,111,"MON CARNET PERSONNEL",26,C.GOLD,700,690)
	var note := _note(app,player)
	var preview := "Conserve tes observations sur ce joueur." if note.is_empty() else str(note.get("text","")).replace("\n"," ")
	D.text(card,946,151,preview,19,C.MUTED,400,690,HORIZONTAL_ALIGNMENT_LEFT,true).name="FullPlayerNotePreview"
	D.button(card,Rect2(946,181,670,48),"Ouvrir ma note",func():Notes.open(app,str(player.id)),false,"mail",true,app.accent,"OpenPlayerNoteFromUsage")

## Nom lisible de la compétition d'une ligne d'historique : le nom affiché du championnat (identités de compétition
## appliquées au modèle, comme partout dans le jeu), pas l'identifiant interne du registre (« Champ Rugby »).
static func _competition(model:Dictionary,ligne:Dictionary) -> String:
	var id := str(ligne.get("competitionId",""))
	if not id.is_empty():
		for league in model.get("leagues",[]):
			if league is Dictionary and str(league.get("id",""))==id and not str(league.get("name","")).is_empty(): return str(league.name)
	return str(ligne.get("competition",""))

## Historique des matchs de la saison (note enregistrée, minutes, essais, plaquages, mètres, passes,
## franchissements : feuille réaliste du match, la même que l'écran de match), moyennes par match de la
## saison, puis le résumé des saisons passées. « — » : match d'une ancienne sauvegarde (champ absent).
## L'adversaire est un lien vers la fiche de son club.
static func _history(card:Panel,app:Control,player:Dictionary) -> void:
	var notes := NotesMatch.joueur(app.model,str(player.id))
	var lignes: Array = notes.get("historique",[]) if notes.get("historique") is Array else []
	var saisons: Array = notes.get("saisons",[]) if notes.get("saisons") is Array else []
	var colonnes := [["SEM.",24,70],["ADVERSAIRE",104,360],["COMPÉTITION",474,280],["MIN.",764,70],["NOTE",844,90],["ESSAIS",944,80],["PLAQ.",1034,80],["MÈTRES",1124,100],["PASSES",1234,90],["FRANCH.",1334,100],["",1444,200]]
	for colonne: Array in colonnes:
		D.text(card,colonne[1],98,colonne[0],18,C.MUTED,600,colonne[2])
	D.line(card,Vector2(20,110),Vector2(1650,110))
	var distinctions: Array = notes.get("distinctions",[]) if notes.get("distinctions") is Array else []
	if lignes.is_empty() and saisons.is_empty() and distinctions.is_empty():
		D.text(card,24,160,"Aucun match noté cette saison",22,C.MUTED,400,1600,HORIZONTAL_ALIGNMENT_LEFT,true).name = "PlayerMatchHistoryEmpty"
		return
	var liste := _scroll(card,Rect2(20,118,1630,286))
	liste.add_theme_constant_override("separation",C.px(2))
	liste.name = "PlayerMatchHistoryRows"
	for i in lignes.size():
		var ligne: Dictionary = lignes[i]
		var rang := Control.new()
		rang.custom_minimum_size = Vector2(C.px(1630),C.px(36))
		rang.name = "PlayerMatchRow"+str(i)
		liste.add_child(rang)
		var rayure = load("res://ui/survol_ligne.gd").rayure(rang,i)
		if rayure != null: D.place(rayure,Rect2(0,0,1630,36))
		D.text(rang,4,26,"S"+G.n(int(ligne.get("semaine",0))+1),20,C.MUTED,500,70)
		var adversaire := str(ligne.get("adversaire",""))
		var club: Variant = ligne.get("adversaireId")
		Link.name_link(app,rang,Rect2(80,1,364,34),"club",str(int(club)) if club is int or club is float else "",adversaire,21,C.IVORY,"PlayerMatchOpponent"+str(i))
		D.text(rang,454,26,_competition(app.model,ligne),19,C.MUTED,500,280)
		D.text(rang,744,26,G.n(ligne.get("minutes",0))+"′",20,C.IVORY,500,70)
		NotesMatch.pastille(rang,Rect2(820,3,72,30),float(ligne.get("note",6.5)),0.62)
		D.text(rang,924,26,G.n(ligne.get("essais",0)),20,C.IVORY if int(ligne.get("essais",0))>0 else C.MUTED,500,80)
		D.text(rang,1014,26,G.n(ligne.get("plaquages",0)),20,C.MUTED,500,80)
		D.text(rang,1104,26,G.n(ligne.get("metres",0))+" m",20,C.MUTED,500,100)
		D.text(rang,1214,26,_stat(ligne.get("passes")),20,C.MUTED,500,90)
		D.text(rang,1314,26,_stat(ligne.get("franchissements")),20,C.IVORY if int(ligne.get("franchissements",0) if ligne.get("franchissements")!=null else 0)>0 else C.MUTED,500,100)
		if ligne.get("hommeDuMatch",false): D.chip(rang,Rect2(1424,4,190,28),"Homme du match",C.GOLD)
	# Repères de carrière : équipes de la saison (XV type du championnat, saison régulière).
	for d: Variant in distinctions:
		if not d is Dictionary: continue
		var repere := Control.new()
		repere.custom_minimum_size = Vector2(C.px(1630),C.px(34))
		repere.name = "PlayerSeasonXV"
		liste.add_child(repere)
		D.text(repere,4,25,"XV de la saison %s · %s · moyenne %s sur %d matchs" % [str(d.get("libelleSaison","")),str(d.get("championnat","")),NotesMatch.texte_note(d.get("moyenne")),int(d.get("matchs",0))],19,C.GOLD,700,1600)
	for saison: Variant in saisons:
		if not saison is Dictionary: continue
		var rang := Control.new()
		rang.custom_minimum_size = Vector2(C.px(1630),C.px(34))
		liste.add_child(rang)
		D.text(rang,4,25,"Saison %s · %s · %d matchs · moyenne %s · %d essai%s%s" % [G.season_label(saison.get("saison",0)),str(saison.get("club","")),int(saison.get("matchs",0)),NotesMatch.texte_note(saison.get("moyenne")),int(saison.get("essais",0)),"s" if int(saison.get("essais",0))>1 else "",(" · %d× homme du match" % int(saison.hommeDuMatch)) if int(saison.get("hommeDuMatch",0))>0 else ""]+((" · %s plaquages · %s m" % [G.n(saison.plaquages),G.n(saison.metres)]) if saison.get("plaquages")!=null and saison.get("metres")!=null else ""),19,C.GOLD,500,1600)

## Chiffre d'une ligne de feuille ; « — » quand l'ancienne sauvegarde ne l'a pas.
static func _stat(valeur: Variant) -> String:
	return "—" if valeur == null else G.n(valeur)

## Moyennes par match de la saison (feuille réaliste), sous les compteurs des performances.
static func _moyennes(card:Panel,notes:Dictionary) -> void:
	var m := int(notes.get("matchs",0))
	if m <= 0: return
	var par := func(cle:String) -> String:
		var v: Variant = notes.get(cle)
		if v == null: return "—"
		return String.num(float(v)/m,1).replace(".",",")
	var texte := "PAR MATCH  ·  %s plaquages  ·  %s m  ·  %s passes  ·  %s essai  ·  %s franch." % [par.call("plaquages"),par.call("metres"),par.call("passes"),par.call("essais"),par.call("franchissements")]
	D.text(card,24,236,texte,21,C.GOLD,600,880).name = "PlayerSeasonPerMatch"

## Matchs internationaux notés (même calcul que le club) : moyenne, forme, dernières rencontres.
static func _selection(card:Panel,app:Control,player:Dictionary) -> void:
	var notes := NotesMatch.joueur(app.model,str(player.id))
	var sel: Variant = notes.get("selection")
	if not sel is Dictionary:
		D.text(card,24,110,"Aucun match international noté.",21,C.MUTED,400,510,HORIZONTAL_ALIGNMENT_LEFT,true).name = "PlayerSelectionEmpty"
		return
	NotesMatch.pastille(card,Rect2(24,70,86,44),float(sel.get("moyenne",6.5)),0.7).name = "PlayerSelectionAverage"
	var n := int(sel.get("matchs",0))
	D.text(card,122,90,("MOYENNE · %d DERNIÈRES" % n) if n>=10 else ("MOYENNE · %d sélection%s" % [n,"s" if n>1 else ""]),17,C.MUTED,600,170).tooltip_text = "Moyenne des notes des %d dernières sélections (notes de 1 à 10)." % n
	var titres := int(sel.get("hommeDuMatch",0))
	if titres>0: D.text(card,122,112,"%d× HOMME DU MATCH" % titres,17,C.GOLD,600,170)
	NotesMatch.pastilles(card,Vector2(300,74),sel.get("forme",[]) if sel.get("forme") is Array else [],Vector2(42,36),5.0,0.5).name = "PlayerSelectionForm"
	var lignes: Array = sel.get("historique",[]) if sel.get("historique") is Array else []
	for i in mini(lignes.size(),3):
		var ligne: Dictionary = lignes[i]
		var y := 128 + i*40
		D.text(card,24,y+24,str(ligne.get("date","")).substr(5,5).replace("-","/"),18,C.MUTED,500,60)
		D.text(card,90,y+24,str(ligne.get("adversaire","")),19,C.IVORY,600,230)
		D.text(card,324,y+24,str(ligne.get("competition","")),16,C.MUTED,500,130)
		NotesMatch.pastille(card,Rect2(470,y+4,68,28),float(ligne.get("note",6.5)),0.6).name = "PlayerSelectionRow"+str(i)

## Onglet Contrat (temps de jeu promis, choix A de Léo du 23/11/2026, ui/immersive08/fiche_temps_jeu.gd) : contrat,
## primes et clauses + marché, temps de jeu.
static func _contrat_temps_jeu(page:Control,app:Control,player:Dictionary,top:float) -> void:
	var bas := HAUTEUR-50-top
	TempsJeu.contrat(D.panel(page,Rect2(0,top,730,bas),"CONTRAT","money","","PlayerContractTerms"),app,player,730,64,84)
	TempsJeu.primes(D.panel(page,Rect2(746,top,730,500),"PRIMES ET CLAUSES","trophy","","PlayerContractClauses"),app,player,730,64,84)
	_sale(D.panel(page,Rect2(746,top+516,730,bas-516),"MARCHÉ DES TRANSFERTS","money","","PlayerSalePanel"),app,player,730)
	TempsJeu.temps(D.panel(page,Rect2(1492,top,756,bas),"TEMPS DE JEU","calendar","","PlayerPlayingTime"),app,player,756)

## Marché des transferts (vente-joueurs.cjs, `squad[].sale`) : état de vente, raison d'un blocage écrite en clair,
## Disponibilité (petite fenêtre : liste des transferts, prêt) et accès aux offres reçues.
static func _sale(card:Panel,app:Control,player:Dictionary,width:float) -> void:
	var sale: Dictionary = player.get("sale",{}) if player.get("sale") is Dictionary else {}
	var pending: bool = sale.get("pending") is Dictionary
	var listed := bool(sale.get("listed",false))
	var blocked := str(sale.get("blocked",""))
	var status := Sales.status(player)
	if status.is_empty(): status = "Valeur estimée %s. Il n’est pas proposé aux autres clubs." % G.euros(sale.get("value",0))
	D.text(card,24,94,status,28,C.GOLD if pending else C.IVORY,600,width-48).name = "PlayerSaleStatus"
	# Pré-contrat (calendrier-mutations.cjs, `squad[].preContract`) : approché par un autre club (prolongation à proposer
	# avant l'échéance) ou parti à la fin de son contrat ; remplace la raison de blocage, qui dit la même chose.
	var pre: Dictionary = player.get("preContract",{}) if player.get("preContract") is Dictionary else {}
	if not pre.is_empty():
		var line := D.text(card,24,142,str(pre.get("short",pre.get("label",""))),26,C.GOLD if str(pre.get("state","")) == "approche" else C.ALERT,600,width-48)
		line.name = "PlayerPreContract"
		line.tooltip_text = str(pre.get("label",""))
		line.mouse_filter = Control.MOUSE_FILTER_PASS
	elif not blocked.is_empty() and not pending:
		D.text(card,24,142,blocked,26,C.ALERT,500,width-48).name = "PlayerSaleReason"
	var half := (width-60)/2.0
	# Disponibilité (idée FM 18, choix de Léo du 23/11/2026) : petite fenêtre avec la phrase de l'agent, liste des transferts
	# ou prêt, qui remplace le bouton « Proposer aux autres clubs ».
	var Nego := preload("res://ui/negociation_agent.gd")
	var toggle := D.button(card,Rect2(24,162,half,52),Nego.libelle_disponibilite(player),func(): Nego.ouvrir_disponibilite(card.get_parent(),app,player),not listed,"money",false,app.accent,"PlayerSaleToggle")
	toggle.add_theme_font_size_override("font_size",maxi(14,C.px(28)))
	toggle.disabled = not Nego.disponibilite_possible(app,player) or not app._live().is_empty()
	if toggle.disabled: toggle.tooltip_text = blocked if not blocked.is_empty() else status
	var offers := D.button(card,Rect2(36+half,162,half,52),Sales.caption(app.model),func(): Sales.open(app),false,"arrow",false,app.accent,"PlayerSaleOffers")
	offers.add_theme_font_size_override("font_size",maxi(14,C.px(28)))

## Suivi individuel dans la fiche (plus de fenêtre « Progression ») : bilans annuels, progression de la saison et
## spécialisation (commande `set_development_focus` du moteur, comme l'ancienne fenêtre).
static func _development(card:Panel,app:Control,player:Dictionary,source:String="squad") -> void:
	var player_id := str(player.id)
	var record: Dictionary = player if source == "academy" else Academy.professional_progress(app, player_id)
	var development: Dictionary = record.get("development", {}) if record.get("development") is Dictionary else {}
	D.text(card,820,108,"POTENTIEL  "+G.potential_text(player),26,C.IVORY,700,700)
	D.text(card,24,108,"NIVEAU ACTUEL  "+G.rating_text(player,true),26,C.IVORY,700,700)
	if record.is_empty():
		D.text(card,24,163,"Suivi individuel indisponible pour ce joueur.",22,C.MUTED,400,1550,HORIZONTAL_ALIGNMENT_LEFT,true)
		return
	var bilan: Array[String] = []
	if record.get("minutes") is int or record.get("minutes") is float: bilan.append(G.n(record.minutes) + " minutes")
	if record.get("appearances") is int or record.get("appearances") is float: bilan.append(G.n(record.appearances) + (" apparition" if int(record.appearances) == 1 else " apparitions"))
	var start: Variant = development.get("seasonStart")
	if (start is int or start is float) and (player.get("rating") is int or player.get("rating") is float):
		var gain := roundi(float(player.rating) - float(start))
		bilan.append(("+%d" % gain if gain > 0 else str(gain)) + " de progression cette saison")
	D.text(card,24,163," · ".join(bilan) if not bilan.is_empty() else "Bilan et objectifs de ce joueur.",22,C.MUTED,400,1550,HORIZONTAL_ALIGNMENT_LEFT,true).name = "PlayerDevelopmentSummary"
	var history:Array=development.get("history",[]) if development.get("history") is Array else []
	if history.is_empty():D.text(card,24,223,"Premier bilan annuel à venir.",25,C.MUTED,500,1550)
	for i in mini(4,history.size()):
		var year:Dictionary=history[history.size()-1-i]
		D.text(card,24,223+i*42,"Saison %s · %s → %s · %s minutes" % [G.season_label(year.get("season","—")),G.n(year.get("start","—")),G.n(year.get("end","—")),G.n(year.get("minutes","—"))],24,C.IVORY,500,1500)
	var choices := {}
	for option: Variant in development.get("options", []):
		if option is Dictionary: choices[option.get("id")] = option.get("label")
	if choices.is_empty(): return
	D.text(card,24,420,"SPÉCIALISATION",18,C.MUTED,700,600)
	var control := Academy._option("Focus" + player_id.replace(":", "_"), "Spécialisation", choices, development.get("focus"), func(value):
		app._command("set_development_focus", {"playerId":record.get("id", player_id), "focus":value}))
	control.disabled = not development.get("available", false)
	control.tooltip_text = "Changer d’axe remet à zéro l’expérience partielle non dépensée. Les qualités déjà acquises sont conservées."
	card.add_child(control)
	D.place(control,Rect2(24,436,760,48))
	D.text(card,24,520,str(development.get("reason", "")) if control.disabled else "",19,C.MUTED,400,1600,HORIZONTAL_ALIGNMENT_LEFT,true).name = "PlayerDevelopmentFocusNote"

static func _sources(card:Panel,_app:Control,player:Dictionary) -> void:
	var profile:Dictionary=player.rosterProfile if player.get("rosterProfile") is Dictionary else {}
	if profile.is_empty():
		var heading := PlayerAttributes.GENERATED_TITLE if PlayerAttributes.is_generated(player) else "Repères du joueur dans ta carrière"
		D.text(card,24,120,heading,31,C.IVORY,700,686).name = "PlayerSourcesHeading"
		D.text(card,24,179,str(player.get("pos","—"))+" · "+G.n(player.get("age","—"))+" ans",22,C.MUTED,400,686,HORIZONTAL_ALIGNMENT_LEFT,true)
		return
	var pos:Dictionary=profile.get("position",{})
	var contract:Dictionary=profile.get("contract",{})
	var status:Dictionary=profile.get("status",{})
	var qualifications: Array=pos.get("qualifications",[])
	var details:Array=["Poste d’origine : "+str(pos.get("primary",player.pos)),"Qualifications de départ : "+(", ".join(qualifications) if not qualifications.is_empty() else "Non renseignées"),"Statut initial : "+str(status.get("value","—")),"Échéance de départ : "+G.n(contract.get("endYear","—"))]
	var scroll := _scroll(card,Rect2(22,72,690,422))
	for i in details.size(): scroll.add_child(C.wrap(details[i],23,C.IVORY if i==0 else C.MUTED,true,600 if i==0 else 500))

static func _contexts(card: Panel, app: Control, player: Dictionary) -> void:
	var content := _scroll(card,Rect2(20,74,1458,710))
	var entry := _note(app,player)
	var note: VBoxContainer
	if not entry.is_empty():
		note=C.v(4)
		note.name="ProfileNoteContent"
		note.add_child(C.label("MA NOTE · %s / SEMAINE %s" % [G.season_label(entry.get("season",1)),G.n(int(entry.get("week",0))+1)],19,C.GOLD))
		var preview := C.wrap(entry.get("text",""),19,C.IVORY)
		preview.name="ProfileNotePreview"
		preview.max_lines_visible=4
		preview.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		note.add_child(preview)
		content.add_child(note)
	app.SquadViews._profile_contexts(content,player,app)
	content.get_node("ProfileContexts").show()
	if note!=null: note.reparent(content.find_child("ProfileStaffNoteSlot",true,false),false)
	Legacy.apply(content,app.accent)

static func _scroll(parent: Control, rectangle: Rect2) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.follow_focus=true
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	D.place(scroll,rectangle)
	var content := C.v(10)
	C.fill(content)
	scroll.add_child(content)
	return content

static func _note(app: Control, player: Dictionary) -> Dictionary:
	for entry: Dictionary in app.model.get("clubLife",{}).get("coachNotebook",{}).get("entries",[]):
		if str(entry.get("target",""))==str(player.id): return entry
	return {}
