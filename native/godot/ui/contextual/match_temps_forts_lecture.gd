extends "res://ui/contextual/match_temps_forts_moments.gd"
## Régie des temps forts : lecture d'un temps fort (liaison, chorégraphie, plans, plaquage).

## Chorégraphe de temps forts : éteint par défaut (CD_MATCH_CHOREGRAPHE=1 pour l'activer,
## côté moteur comme côté vue).
static func choregraphe_demande() -> bool:
	return OS.get_environment("CD_MATCH_CHOREGRAPHE") == "1"

## Liaisons et arbitre actifs (repli : CD_MATCH_LIAISON=0, comportement d'avant).
static func liaisons_actives() -> bool:
	return OS.get_environment("CD_MATCH_LIAISON") != "0"

func _sonner(kind: String, camp: int = -1) -> void:
	var sons: Variant = app.get("soundscape")
	if is_instance_valid(sons) and sons.has_method("play_shown"): sons.play_shown(kind, camp)

## Le match tel que l'image le permet : pendant un temps fort, le journal s'arrête à
## l'action montrée (le moteur a une minute d'avance).
func montre(live: Dictionary) -> Dictionary:
	# Temps fort retenu par l'entracte : son action n'est pas encore montrée.
	if etat != JEU and not _retenu.is_empty():
		if _retenu_vus >= live.get("events", []).size(): return live
		var cache := live.duplicate()
		cache["events"] = live.get("events", []).slice(0, _retenu_vus)
		return cache
	# Écran intermédiaire : rien d'un temps fort à venir (le moteur a une minute d'avance).
	if etat != JEU and live.get("direct") is Dictionary and live.direct.has("borne"):
		var borne := int(live.direct.borne)
		if borne >= live.get("events", []).size(): return live
		var vue := live.duplicate()
		vue["events"] = live.get("events", []).slice(0, borne)
		return vue
	if etat != JEU or index < 0 or index >= tf.get("plans", []).size(): return live
	# Liaison : le journal s'arrête au fait d'arrêt de jeu (rien du temps fort à venir).
	if phase == "liaison":
		var arrets: Array = liaison.get("arrets", [])
		var arret_plan: int = int(arrets[_liaison_plan]) if _liaison_plan < arrets.size() else int(liaison.get("arret", -1))
		var borne_liaison: int = maxi(arret_plan + 1, _vus)
		if borne_liaison >= _events.size(): return live
		var avant := live.duplicate()
		avant["events"] = _events.slice(0, borne_liaison)
		return avant
	# Un fait n'entre au journal qu'une fois à l'écran (même règle que la légende) : jalon des pistes,
	# résultat d'un tir après la frappe, essai une fois aplati.
	var plan: Dictionary = tf.plans[index]
	var kind := str(plan.get("kind", ""))
	var vu := fait_a_l_ecran(plan, phase, temps, _essai_montre, _jalon_montre)
	# Transformation : son fait du journal est celui de l'essai (même index), déjà montré.
	var avance := 1 if vu or (kind == "transformation" and phase != "choregraphie") else 0
	var jusque: int = maxi(int(plan.index) + avance, _vus)
	# Fait des lois écrit après le plan (coup franc, essai de pénalité…) : il entre au journal avec sa légende.
	if not _loi.is_empty(): jusque = maxi(jusque, int(_loi.get("i", -1)) + 1)
	# Le texte brut de l'essai dit déjà la transformation et le score : jusqu'au résultat du tir,
	# le journal garde la légende de l'essai (native/engine/match-direct.cjs, `legende`).
	var tronquer: bool = (kind == "try" or (kind == "transformation" and not vu)) and int(plan.index) >= _vus and int(plan.index) < mini(jusque, _events.size())
	if jusque >= _events.size() and not tronquer: return live
	var journal: Array = _events.slice(0, jusque)
	if tronquer and journal[int(plan.index)] is Dictionary:
		var fait: Dictionary = (journal[int(plan.index)] as Dictionary).duplicate()
		fait["text"] = sans_transformation(str(fait.get("text", "")))
		journal[int(plan.index)] = fait
	var copie := live.duplicate()
	copie["events"] = journal
	return copie

## Texte d'un essai sans sa transformation ni le score (même coupe que `legende` de match-direct.cjs).
static func sans_transformation(texte: String) -> String:
	var coupe := texte.find(", transform")
	return texte.substr(0, coupe) + "." if coupe > 0 else "Essai."

static func _positions(scene: Dictionary) -> Dictionary:
	var places: Dictionary = {}
	for joueur: Variant in scene.get("players", []):
		if joueur is Dictionary: places[str(joueur.get("id", ""))] = Vector2(float(joueur.get("x", 50.0)), float(joueur.get("y", 35.0)))
	return places

func _interpole(scene: Dictionary, avance: float) -> Dictionary:
	# Positions intermédiaires d'une progression : le porteur part du point de départ
	# de l'action, les autres de leur place précédente. Le point d'arrivée reste celui du moteur.
	var copie := scene.duplicate()
	var origine: Variant = scene.get("origin")
	var joueurs: Array = []
	for joueur: Dictionary in scene.get("players", []):
		var place := joueur.duplicate()
		var id := str(place.get("id", ""))
		var porteur: bool = place.get("featured", false) and int(place.get("side", -1)) == int(scene.get("possession", -2))
		if porteur and origine is Dictionary and origine.has("x") and origine.has("y"):
			place.x = lerpf(float(origine.x), float(joueur.x), avance)
			place.y = lerpf(float(origine.y), float(joueur.y), avance)
		elif _depuis.has(id):
			place.x = lerpf(_depuis[id].x, float(joueur.x), avance)
			place.y = lerpf(_depuis[id].y, float(joueur.y), avance)
		joueurs.append(place)
	copie.players = joueurs
	return copie

func _gestes_actifs() -> bool:
	# La vue 3D sait couper elle-même vers une remise en jeu quand ses gestes sont actifs.
	return stage.get("_gestes") != null

## Vitesse de chaque joueur à l'écran (départ d'une liaison : personne ne se fige) et plus grande
## allure d'une image à l'autre pendant un plan de liaison, en m/s (contrôle : aucun saut).
func _mesurer(delta: float) -> void:
	if delta <= 0.0: return
	# La régie passe avant la vue (process_priority) : le pas mesuré ici a été fait pendant l'image
	# précédente de la vue, sur sa durée à elle. Diviser par la durée de l'image courante gonflait
	# l'allure dès qu'une image longue suivait une courte (exécuteur de CI chargé : 32 m/s mesurés).
	var duree_vue: Variant = stage.get("dernier_delta")
	if (duree_vue is float) and float(duree_vue) > 0.0: delta = float(duree_vue)
	var coupe := phase == "liaison" and _liaison_t <= 0.0001
	for id: String in stage._actors:
		var at: Vector3 = (stage._actors[id].node as Node3D).position
		if _places.has(id):
			var pas: Vector3 = at - _places[id]
			_vitesses[id] = (_vitesses.get(id, Vector3.ZERO) as Vector3).lerp(pas / delta, 0.5)
			# Les deux premières images d'un plan reprennent la main sur le jeu : un petit recalage de groupe (~20 cm) n'est pas un saut.
			if phase == "liaison" and not coupe and not gel and _liaison_t > 0.1:
				# Allure d'une image à l'autre (m/s) : au-delà d'un sprint, ce serait un saut.
				_saut_max = maxf(_saut_max, Vector2(pas.x, pas.z).length() / delta)
		_places[id] = at

## Liaison vers le temps fort `candidat` s'il part là où le précédent s'est arrêté ; {} sinon.
func _preparer_liaison(candidat: Dictionary) -> Dictionary:
	if not liaisons_actives() or not stage.has_method("jouer_choregraphie") or tf.is_empty():
		return {}
	# Pistes du chorégraphe dès le premier plan : elles ont leur propre entrée.
	if choregraphe_demande() and candidat.get("choregraphie") is Dictionary and int(candidat.choregraphie.get("premier", -1)) == 0:
		return {}
	var info := Liaison.analyser(tf, candidat, _events)
	if info.is_empty(): return {}
	var joueurs: Dictionary = {}
	for id: String in stage._actors:
		var at: Vector3 = (stage._actors[id].node as Node3D).position
		var v: Vector3 = _vitesses.get(id, Vector3.ZERO)
		joueurs[id] = {"p": Vector2(at.x + 50.0, at.z + 35.0), "v": Vector2(v.x, v.z)}
	var porteur: String = str(stage._carrier_id) if bool(stage._ball_attached) else ""
	var marque: Vector2 = info.marque
	var ballon := {"p": (stage._ball as Node3D).global_position if stage._ball.visible else Vector3(marque.x - 50.0, 0.1, marque.y - 35.0), "porteur": porteur}
	var pos_arbitre := Vector2(arbitre.position.x + 50.0, arbitre.position.z + 35.0) if arbitre != null else Vector2(50, 35)
	var rencontre := str(_live.get("direct", {}).get("rencontre", ""))
	var lien := Liaison.construire(info, joueurs, ballon, pos_arbitre, Liaison.graine(rencontre, str(candidat.get("cle", ""))), _detail_precedent)
	if lien.is_empty(): return {}
	lien["arret"] = int(info.get("arret", -1))
	lien["texte"] = _nommer(str(lien.get("texte", "")))
	lien["textes"] = (lien.get("textes", []) as Array).map(func(t: Variant) -> String: return _nommer(str(t)))
	lien["plan_kind"] = str(info.get("plan_kind", ""))
	_detail_precedent = str(lien.get("detail", ""))
	return lien

## Sigles du journal remplacés par ceux affichés (même règle que le moteur, match-direct.cjs `renommeur`).
func _nommer(texte: String) -> String:
	for equipe: Variant in _teams:
		if not equipe is Dictionary: continue
		var sigle := str(equipe.get("abbr", ""))
		var montre := str((equipe.get("presentation", {}) as Dictionary).get("abbr", "")) if equipe.get("presentation") is Dictionary else ""
		if montre.is_empty() or sigle == montre or not RegEx.create_from_string("^[A-Z0-9]{2,5}$").search(sigle): continue
		texte = RegEx.create_from_string("(?<![\\p{L}\\p{N}])" + sigle + "(?![\\p{L}\\p{N}])").sub(texte, montre, true)
	return texte

func _demarrer(candidat: Dictionary, lien: Dictionary = {}) -> void:
	# Une suite peut arriver après un retour à l'écran intermédiaire (pause, arrêt) : la 3D
	# sort alors du fondu et le cadrage, relâché entre-temps, doit être reposé d'emblée.
	var depuis_inter := etat == INTER
	_entracte = -1.0
	_passer = false
	_moment_essai = 0.0
	_regler_ralenti()
	between.montrer_entracte("", false)
	tf = candidat
	# Ralenti de l'essai : la vue enregistre ce qu'elle montre seulement pour un temps fort avec un essai.
	_finir_rejeu()
	_rejeu_du = false
	if is_instance_valid(stage) and stage.has_method("enregistrer_rejeu"): stage.enregistrer_rejeu(rejeu_voulu(tf.get("plans", []), _calme()))
	index = 0
	_lois_plan = -1
	_lois = []
	_loi = {}
	etat = JEU
	_debut_ms = Time.get_ticks_msec()
	_score = tf.get("scoreAvant", _live.get("score", [0, 0]))
	_montrer_jeu(true)
	_presenter(true)
	stage.set_live_cadence(1)
	# Entrée dans un temps fort : le cadrage rapproché est posé d'emblée (la 3D sort du fondu).
	if cadrage != null and (depuis_inter or not tf.get("suite", false)) and lien.is_empty(): cadrage.couper()
	if arbitre != null: arbitre.habiller()
	var depart: Variant = tf.get("depart")
	if not tf.get("suite", false) and depart is Dictionary and lien.is_empty():
		# Coupe d'entrée : l'action reprend d'où elle se trouvait une minute plus tôt.
		stage.apply_frame(_image(depart, true, int(tf.get("debut", 0)) - 1))
		stage.apply_frame(_image(depart, false, int(tf.get("debut", 0)) - 1))
		_derniers = _positions(depart)
	suivi.append({"evenement": "temps_fort", "cle": str(tf.get("cle", "")), "type": str(tf.get("type", "")), "suite": bool(tf.get("suite", false)),
		"horloge": str(tf.get("horlogeDebut", "")), "plans": tf.plans.size(), "debut": int(tf.get("debut", -1)), "premier_plan": int(tf.plans[0].get("index", -1)) if not tf.plans.is_empty() else -1, "duree_prevue": float(tf.get("duree", 0.0)), "declenchement": tf.get("declenchement"), "debut_ms": _debut_ms,
		"contigu": not depuis_inter, "liaison": str(lien.get("type", ""))})
	if not lien.is_empty() and _jouer_liaison(lien):
		return
	_commencer_plan()
	# Entrée coupée : l'arbitre est déjà près de l'action.
	if arbitre != null and (depuis_inter or not tf.get("suite", false)):
		arbitre.dirige = false
		arbitre.placer(arbitre.place_de_jeu(stage._ball_target), stage._ball_target)

# --- Liaison entre deux temps forts contigus ------------------------------------

func _jouer_liaison(lien: Dictionary) -> bool:
	liaison = lien
	_liaison_plan = 0
	_liaison_total = 0.0
	_saut_max = 0.0
	if not _lancer_plan_liaison(0):
		liaison = {}
		phase = "jeu"
		between.forcer_etat("")
		suivi.append({"evenement": "liaison_refusee", "debut_ms": Time.get_ticks_msec()})
		return false
	suivi.append({"evenement": "liaison", "type": str(lien.type), "choix": str(lien.get("choix", "")), "coupe": bool(lien.coupe), "plans": (lien.plans as Array).size(),
		"duree_prevue": float(lien.duree), "duree_plans": (lien.plans as Array).map(func(p: Dictionary) -> float: return float(p.duree)),
		"detail": str(lien.get("detail", "")), "cle": str(tf.get("cle", "")), "debut_ms": Time.get_ticks_msec(), "bandeaux": (lien.get("bandeaux", []) as Array).map(func(b: Variant) -> String: return str(b.get("libelle", "")) if b is Dictionary else "")})
	return true

## Un plan de la liaison, toujours à vitesse réelle ; le plan B part d'une coupe franche.
func _lancer_plan_liaison(k: int) -> bool:
	var pistes: Dictionary = liaison.plans[k]
	if not stage.jouer_choregraphie(pistes, 1.0):
		return false
	phase = "liaison"
	_liaison_plan = k
	_liaison_t = 0.0
	var arrets: Array = liaison.get("arrets", [])
	_image_posee(int(arrets[k]) if k < arrets.size() else int(liaison.get("arret", -1)))
	if cadrage != null:
		# Plan A : large (le ballon qui sort, les joueurs autour) ; plan B : cadrage de la remise en jeu.
		# (« penalty » : plan d'arrêt de jeu, large, sans les extrémités d'un vol de ballon déjà fini.)
		cadrage.regler(true, "penalty" if k == 0 else str(liaison.get("plan_kind", "")), k == 0)
		if k > 0:
			cadrage.couper()
			stage._camera_cut = true
	_programme_arbitre(true)
	_habiller()
	return true

func _programme_arbitre(debut_plan: bool) -> void:
	if arbitre == null: return
	arbitre.dirige = true
	var courant: Dictionary = {}
	for etape: Dictionary in liaison.get("arbitre", []):
		if int(etape.plan) == _liaison_plan and float(etape.t) <= _liaison_t + 0.0001: courant = etape
	if courant.is_empty(): return
	var lieu: Vector2 = courant.lieu
	var monde := Vector3(lieu.x - 50.0, 0.0, lieu.y - 35.0)
	if debut_plan and _liaison_plan > 0: arbitre.placer(monde, stage._ball.global_position)
	arbitre.cible = monde
	arbitre.signal_bras = str(courant.get("signal", ""))
	var d: Vector2 = courant.get("direction", Vector2.ZERO)
	arbitre.direction_bras = Vector3(d.x, 0.0, d.y)
	arbitre.hauteur_bras = float(courant.get("hauteur", 0.0))

func _lire_liaison(reel: float) -> void:
	_liaison_t += reel
	_liaison_total += reel
	_programme_arbitre(false)
	var pistes: Dictionary = liaison.plans[_liaison_plan]
	var duree := float(pistes.duree)
	# Liaison continue : la caméra glisse du plan large vers le cadrage de la remise en jeu.
	if cadrage != null and _liaison_plan == 0 and not bool(liaison.coupe) and _liaison_t >= duree * 0.55 and cadrage.kind == "penalty":
		cadrage.regler(true, str(liaison.get("plan_kind", "")), false)
	var echue := _liaison_t > duree + ECHEANCE_LIAISON
	if stage.choregraphie_active() and not stage.choregraphie_finie() and not echue:
		return
	if echue: suivi.append({"evenement": "echeance", "cause": "liaison", "debut_ms": Time.get_ticks_msec()})
	if _liaison_plan + 1 < (liaison.plans as Array).size() and _lancer_plan_liaison(_liaison_plan + 1):
		return
	for i in range(suivi.size() - 1, -1, -1):
		if str(suivi[i].get("evenement", "")) == "liaison":
			suivi[i]["duree_reelle"] = _liaison_total
			suivi[i]["saut_max"] = _saut_max
			break
	stage.arreter_choregraphie()
	_derniers = {}
	for id: String in stage._actors:
		var at: Vector3 = (stage._actors[id].node as Node3D).position
		_derniers[id] = Vector2(at.x + 50.0, at.z + 35.0)
	var tenue: Dictionary = liaison.get("tenue", {})
	if arbitre != null: arbitre.dirige = false
	phase = "jeu"
	_sans_coupe = true
	liaison = {}
	between.forcer_etat("")
	_commencer_plan()
	if not tenue.is_empty() and stage.has_method("tenir_poses"): stage.tenir_poses(tenue)

## Faits des lois qui suivent le plan `k` du temps fort (direct.lois le plus récent, match-direct.cjs : `apres` = le
## fait du plan) ; aucun pour l'essai suivi de sa transformation (même fait : ils viennent après la transformation).
func lois_du_plan(k: int) -> Array:
	var plans: Array = tf.get("plans", [])
	if k < 0 or k >= plans.size() or not plans[k] is Dictionary: return []
	var fait := int(plans[k].get("index", -1))
	if fait < 0 or (k + 1 < plans.size() and plans[k + 1] is Dictionary and int(plans[k + 1].get("index", -1)) == fait): return []
	var direct: Variant = _live.get("direct")
	var lois: Variant = direct.get("lois") if direct is Dictionary else null
	var sortie: Array = []
	if lois is Array:
		for loi: Variant in lois:
			if loi is Dictionary and int(loi.get("apres", -1)) == fait: sortie.append(loi)
	return sortie

## Faits des lois du plan fini : chacun écrit à son tour dans la légende, le journal et la ligne d'état, l'image du
## plan tenue (aucun geste). Vrai tant qu'il en reste un à l'écran ; faux quand le plan peut céder la place.
func _tenir_lois(_plan: Dictionary, delta: float) -> bool:
	if _lois_plan != index:
		_lois_plan = index
		_lois = lois_du_plan(index)
		_loi = {}
		if not _lois.is_empty():
			_montrer_loi()
			return true
	if _loi.is_empty(): return false
	_loi_reste -= delta
	if _loi_reste > 0.0: return true
	if not _lois.is_empty():
		_montrer_loi()
		return true
	_loi = {}
	return false

## Score après un plan et les faits des lois qui le suivent (essai de pénalité : +7, drop réussi : +3).
func _score_apres(k: int) -> Array:
	var marque: Array = tf.plans[k].get("score", _score)
	for fait: Variant in lois_du_plan(k):
		if fait is Dictionary and fait.get("score") is Array and (fait.score as Array).size() == 2: marque = fait.score
	return marque

func _montrer_loi() -> void:
	_loi = _lois.pop_front() if _lois[0] is Dictionary else {}
	if _loi.is_empty():
		_lois.clear()
		return
	var loi := str(_loi.get("loi", ""))
	var camp := int(_loi.get("equipe", -1)) if _loi.get("equipe") != null else -1
	var marque: Variant = _loi.get("score")
	var points := marque is Array and (marque as Array).size() == 2 and _score.size() >= 2 and int(marque[0]) + int(marque[1]) > int(_score[0]) + int(_score[1])
	_loi_reste = LOI_POINTS if points else LOI_TENUE
	if marque is Array and (marque as Array).size() == 2: _score = marque
	# Texte seul : ni geste ni réaction du stade (le son suit le plan montré, godot-match-temps-forts).
	if loi == "essai-penalite":
		# Bannière « ESSAI » (texte seul, sans ralenti ni rejeu : rien à rejouer), à la couleur du club.
		var couleur := Color.TRANSPARENT
		var equipe := ""
		if camp in [0, 1] and camp < _teams.size() and _teams[camp] is Dictionary:
			couleur = Color.from_string(str(S.G.identity(_teams[camp]).get("color", "")), Charte.CLUB)
			equipe = S.G.club_name(_teams[camp])
		var minute := str(_loi.get("horloge", "")).trim_suffix("′").strip_edges()
		var contexte := ("%s · %se minute" % [equipe, minute] if not equipe.is_empty() else "%se minute" % minute) if minute.is_valid_int() else equipe
		montrer_bandeau("ESSAI", "Essai de pénalité", contexte, ESSAI_BANDEAU, couleur, "+7\n%d – %d" % [int(_score[0]), int(_score[1])] if _score.size() >= 2 else "+7")
	suivi.append({"evenement": "loi", "loi": loi, "i": int(_loi.get("i", -1)), "texte": str(_loi.get("texte", "")), "score": _score.duplicate(), "debut_ms": Time.get_ticks_msec()})
	_habiller()

## Pistes du chorégraphe qui passent un plan suivi de faits des lois : pas d'image à tenir (les pistes courent),
## ils entrent au journal du direct dans l'ordre.
func _lois_au_journal(k: int) -> void:
	for fait: Variant in lois_du_plan(k):
		if not fait is Dictionary: continue
		if view.has_method("ajouter_au_journal"): view.ajouter_au_journal(str(fait.get("texte", "")))
		suivi.append({"evenement": "loi", "loi": str(fait.get("loi", "")), "i": int(fait.get("i", -1)), "texte": str(fait.get("texte", "")), "journal": true, "debut_ms": Time.get_ticks_msec()})

func _commencer_plan() -> void:
	var plan: Dictionary = tf.plans[index]
	if str(plan.get("kind", "")) == "transformation" and plan.get("scene") is Dictionary and not plan.get("loi_8", false):
		# Transformation (loi 8) : défense derrière sa ligne de but, équipe du buteur derrière le ballon.
		plan.scene = ApresEssai.transformation(plan.scene)
		plan["loi_8"] = true
	if str(plan.get("loi", "")) == "essai-penalite" and plan.get("scene") is Dictionary and not plan.get("loi_8", false):
		# Essai de pénalité : la défense se replie dans son en-but, l'équipe qui marque recule vers les 22 mètres
		# (places d'une transformation, loi 8, sans buteur ni tir) ; l'arbitre va seul sous les poteaux.
		var camp_essai := int(plan.scene.get("team", plan.scene.get("possession", 0)))
		var replis: Dictionary = plan.scene.duplicate()
		replis.possession = camp_essai
		replis.origin = {"x": ApresEssai.but_x(camp_essai) + (-22.0 if camp_essai == 0 else 22.0), "y": 35.0}
		plan.scene = ApresEssai.transformation(replis)
		plan["loi_8"] = true
	var scene: Dictionary = plan.scene
	var tir := tir_au_but(plan)
	# Drop (loi « drop-reussi » ou « drop-rate ») : le botteur a déjà le ballon en main, sans élan.
	var drop := str(plan.get("loi", "")).begins_with("drop") and tir
	temps = 0.0
	sous_image = 0.0
	_tenu = 0.0
	phase = "jeu"
	_elan = not tir or drop
	_image_posee(int(plan.get("index", -1)))
	if cadrage != null:
		cadrage.regler(true, str(plan.get("kind", "")), float(plan.get("mouvement", 0.0)) >= 2.5)
		# Bandeau du score en haut, légende et commandes en bas : l'action est cadrée entre les deux.
		var hauteur := maxf(1.0, view.size.y)
		var legende: Control = view.events.get_parent().get_parent().get_parent()
		cadrage.couvrir(view.clock.get_global_rect().end.y / hauteur + 0.03, (hauteur - legende.get_global_rect().position.y) / hauteur + 0.02)
		if plan.get("coupe", false) and not _sans_coupe: cadrage.couper()
		# Tir au but : caméra dans l'axe, derrière le buteur, les deux poteaux au fond.
		# Drop : plan large de côté (_cadrer_drop), jamais le plan dans l'axe d'un tir au but.
		if tir and not drop and cadrage.has_method("viser_poteaux"): cadrage.viser_poteaux(stage._world(scene.origin), ApresEssai.poteaux_x(scene) - 50.0, ApresEssai.buteur(scene))
	_placer_arbitre_tir(plan if tir else {})
	_jouer_loi(plan)
	_sans_coupe = false
	if _jouer_choregraphie(plan):
		return
	if plan.get("coupe", false) and (not _gestes_actifs() or tir):
		# Coupe franche : la phase est montrée déjà en place (tir au but : buteur à quelques pas derrière
		# le ballon, qui s'élance ensuite ; la vue ne coupe pas d'elle-même vers un tir).
		var pret := ApresEssai.elan(scene, ApresEssai.ELAN) if tir and not drop else scene.duplicate()
		pret.key = str(scene.get("key", "")) + ":pret"
		# Drop : le botteur, à sa place, tient le ballon (porteur d'une course) avant de le laisser tomber.
		if drop: pret.kind = "carry"
		if str(plan.get("kind", "")) in DEPART_BALLON and scene.get("origin") is Dictionary: pret.ball = scene.origin
		stage.apply_frame(_image(pret, true, int(plan.index) - 1))
		stage.apply_frame(_image(pret, false, int(plan.index) - 1))
		_derniers = _positions(pret)
		if drop: _cadrer_drop(scene)
		if float(PRET.get(str(plan.get("kind", "")), 0.0)) > 0.0:
			phase = "pret"
			_habiller()
			return
	_jouer(plan)

## Drop (choix de Léo, 26/11/2026 : plan large de côté) : le botteur et les deux poteaux restent à l'image, du
## lâcher au passage du ballon ; la caméra de tribune est tournée en biais vers les poteaux (match_cadrage.gd,
## `biais`) pour qu'on voie le ballon passer entre les perches ou à côté.
func _cadrer_drop(scene: Dictionary) -> void:
	if cadrage == null: return
	var id := ApresEssai.buteur(scene)
	if stage._actors.has(id): cadrage.temoin = stage._actors[id].node
	var poteaux := ApresEssai.poteaux_x(scene) - 50.0
	cadrage.points_regie.assign([Vector3(poteaux, 0.0, -3.0), Vector3(poteaux, 0.0, 3.0), Vector3(poteaux, 8.0, 0.0)])
	cadrage.vers_poteaux(poteaux)

## Coup franc et essai de pénalité (`plan.loi`) : programme de l'arbitre (match_arbitre.gd, `loi`) et
## cadrage qui le garde à l'image. Tout autre plan efface le programme.
func _jouer_loi(plan: Dictionary) -> void:
	if arbitre == null: return
	var loi := str(plan.get("loi", ""))
	if loi not in ["coup-franc", "essai-penalite"] or not plan.get("scene") is Dictionary:
		if not arbitre.loi.is_empty():
			arbitre.loi = {}
			arbitre.dirige = false
		return
	var scene: Dictionary = plan.scene
	var camp := int(scene.get("team", scene.get("possession", 0)))
	var sens := 1.0 if ApresEssai.but_x(camp) > 50.0 else -1.0
	var marque: Vector3 = stage._world(scene.get("ball", {}))
	arbitre.dirige = true
	if loi == "coup-franc":
		# À côté de la marque, côté caméra et face à elle : le bras plié vers l'équipe se lit de profil.
		var place := Vector3(clampf(marque.x - sens * 2.5, -52.0, 52.0), 0.0, clampf(marque.z + 4.0, -31.0, 31.0))
		arbitre.loi = {"genre": loi, "place": place, "regard": place + Vector3(0.0, 0.0, 10.0), "dir": Vector3(sens, 0.0, 0.0), "t": 0.0}
		# Plan large de l'arrêt de jeu (choix de Léo) qui garde l'arbitre à l'image.
		if cadrage != null: cadrage.temoin = arbitre
		return
	# Essai de pénalité : sous les poteaux, face au terrain.
	var poteaux := ApresEssai.poteaux_x(scene) - 50.0
	var cote := signf(poteaux) if absf(poteaux) > 1.0 else sens
	var point := Vector3(poteaux - cote * 1.0, 0.0, 0.0)
	arbitre.loi = {"genre": loi, "point": point, "regard": point - Vector3(cote * 10.0, 0.0, 0.0), "dir": Vector3(0.0, 0.0, 1.0), "t": 0.0, "arrive": -1.0}
	# Bannière « ESSAI » (+7) : celle du fait des lois (direct.lois, _montrer_loi), écrite après ce plan pendant que
	# l'image est tenue ; l'arbitre garde alors le bras levé sous les poteaux (son programme dure jusqu'au plan suivant).
	if cadrage == null: return
	# Plan large (choix de Léo) : l'arbitre, les poteaux et le ballon au point de la faute, sans les joueurs qui
	# reculent vers les 22 mètres (match_cadrage.gd, « essai_penalite ») : les poteaux restent à l'image même loin.
	cadrage.regler(true, "essai_penalite", true)
	cadrage.temoin = arbitre
	cadrage.points_regie.assign([Vector3(poteaux, 0.0, -3.0), Vector3(poteaux, 7.0, 3.0)])

## Plan de tir au but (transformation, pénalité tentée) avec sa marque et son buteur.
static func tir_au_but(plan: Dictionary) -> bool:
	var scene: Variant = plan.get("scene")
	if str(plan.get("kind", "")) not in TIRS_AU_BUT or not scene is Dictionary: return false
	var origine: Variant = scene.get("origin")
	return origine is Dictionary and origine.has("x") and origine.has("y") and not ApresEssai.buteur(scene).is_empty()

## Tir au but : l'arbitre est déjà placé, devant la marque et sur le côté (coupe) ; il reprend
## le suivi du ballon au plan suivant.
func _placer_arbitre_tir(plan: Dictionary) -> void:
	if arbitre == null: return
	if plan.is_empty():
		if _arbitre_au_tir:
			_arbitre_au_tir = false
			arbitre.dirige = false
		return
	var scene: Dictionary = plan.scene
	var marque: Vector3 = stage._world(scene.origin)
	var poteaux := Vector3(ApresEssai.poteaux_x(scene) - 50.0, 0.0, 0.0)
	_arbitre_au_tir = true
	arbitre.dirige = true
	arbitre.signal_bras = ""
	arbitre.placer(ApresEssai.place_arbitre_tir(marque, poteaux.x), marque)

## Pistes continues du chorégraphe pour ce plan (moteur Node, CD_MATCH_CHOREGRAPHE=1) :
## la vue les suit à la place de l'interpolation et des gestes du plan. Sans pistes, ou
## si la vue les refuse, le plan se joue comme avant.
func _jouer_choregraphie(plan: Dictionary) -> bool:
	var pistes: Variant = tf.get("choregraphie")
	if not choregraphe_demande() or not pistes is Dictionary or int(pistes.get("premier", -1)) != index:
		return false
	var dernier := int(pistes.get("dernier", -1))
	if dernier < index or dernier >= tf.plans.size() or not pistes.get("jalons") is Array:
		suivi.append({"evenement": "choregraphie_refusee", "debut_ms": Time.get_ticks_msec()})
		return false
	# Joueurs pas encore à l'écran (premier temps fort du match, sans scène de départ) : la scène du
	# plan les pose d'abord, figée, pour que les pistes aient qui déplacer.
	if stage.has_method("jouer_choregraphie") and pistes.get("joueurs") is Array and plan.get("scene") is Dictionary:
		var absents := 0
		for joueur: Variant in pistes.joueurs:
			if joueur is Dictionary and not stage._actors.has(str(joueur.get("id", ""))): absents += 1
		if absents > 0:
			stage.apply_frame(_image(plan.scene, true, int(plan.get("index", 0)) - 1))
			_derniers = _positions(plan.scene)
	if not stage.has_method("jouer_choregraphie") or not stage.jouer_choregraphie(pistes, vitesse):
		suivi.append({"evenement": "choregraphie_refusee", "debut_ms": Time.get_ticks_msec()})
		return false
	phase = "choregraphie"
	_resultat_sonne = false
	# Pistes : l'essai a son propre jalon (clameur et légende), rien à différer ici.
	_essai_montre = true
	temps = 0.0
	_tenu = 0.0
	_jalon_montre = false
	_jalons_lus = 0
	# Plusieurs temps de jeu : cadrage rapproché du jeu courant, qui suit le ballon ; une remise en
	# jeu formée part d'une coupe.
	if cadrage != null:
		# Jeu au pied et pénalités : cadrage large des coups de pied ; franchissement : celui d'une
		# longue course ; ballon porté : cadrage rapproché du jeu courant.
		var genre := str(pistes.get("type", ""))
		# Même cadrage pour un essai en jeu courant et un franchissement : le plan ne trahit pas l'issue.
		# Pénalité jouée à la main : cadrage du jeu courant (le demi relance aussitôt).
		cadrage.regler(true, "kick" if genre in ["jeu_au_pied", "penalite_au_but", "penalite_en_touche"] else "carry", genre in ["franchissement", "essai_jeu_courant"])
		if pistes.get("coupe", false): cadrage.couper()
	suivi.append({"evenement": "choregraphie", "plan": str(plan.get("kind", "")), "type": str(pistes.get("type", "")), "premier": index, "dernier": dernier,
		"duree_prevue": float(pistes.get("duree", 0.0)), "debut_ms": Time.get_ticks_msec()})
	_habiller()
	return true

func _lire_choregraphie(reel: float) -> void:
	_tenu += reel
	var pistes: Dictionary = tf.choregraphie
	var jalons: Array = pistes.get("jalons", [])
	var dernier := int(pistes.get("dernier", index))
	# Chaque plan couvert prend la main à son jalon : légende, journal et score suivent l'image ;
	# la clameur et la légende de l'essai partent quand le ballon est aplati à l'écran.
	while _jalons_lus < jalons.size() and jalons[_jalons_lus] is Array and float(jalons[_jalons_lus][0]) <= stage.choregraphie_temps() + 0.0001:
		var k := clampi(int(jalons[_jalons_lus][1]), index, dernier)
		_jalons_lus += 1
		if k > index:
			for j in range(index, k): _lois_au_journal(j)
			_score = _score_apres(k - 1)
			index = k
		_jalon_montre = true
		_image_posee(int(tf.plans[index].get("index", -1)))
		if str(tf.plans[index].get("kind", "")) == "try":
			_sonner("try", _camp_du_plan(tf.plans[index]))
			# Essai aplati et annoncé : le bandeau passe aussitôt au nouveau score (+5).
			_score = tf.plans[index].get("score", _score)
			_celebrer_essai(tf.plans[index])
		# Tir au but : son jalon est le passage du ballon, le résultat est à l'écran.
		if tf.plans[index].has("annonce") and not _resultat_sonne:
			_resultat_sonne = true
			# Transformation ou tir vus : le score suit (+2 / +3), pas avant.
			_score = tf.plans[index].get("score", _score)
			_sonner("goal" if str(tf.plans[index].get("kind", "")) == "goal" else "miss", _camp_du_plan(tf.plans[index]))
		_habiller()
	var echue := _tenu > float(pistes.get("duree", 0.0)) / maxf(vitesse, 0.01) + ECHEANCE_CHOREGRAPHIE
	if stage.choregraphie_active() and not stage.choregraphie_finie() and not echue:
		return
	if echue: suivi.append({"evenement": "echeance", "cause": "choregraphie", "debut_ms": Time.get_ticks_msec()})
	for i in range(suivi.size() - 1, -1, -1):
		if str(suivi[i].get("evenement", "")) == "choregraphie":
			suivi[i]["duree_reelle"] = _tenu
			break
	_jalon_montre = true
	if index < dernier:
		for j in range(index, dernier): _lois_au_journal(j)
		_score = _score_apres(dernier - 1)
		index = dernier
	stage.arreter_choregraphie()
	# Places réelles en fin de pistes : point de départ du plan suivant.
	_derniers = {}
	for id: String in stage._actors:
		var at: Vector3 = (stage._actors[id].node as Node3D).position
		_derniers[id] = Vector2(at.x + 50.0, at.z + 35.0)
	# Le plan se termine comme un plan ordinaire : score, plan suivant ou fin du temps fort.
	phase = "jeu"
	_essai_montre = true
	temps = float(tf.plans[index].get("duree", 1.0))

func _jouer(plan: Dictionary) -> void:
	var scene: Dictionary = plan.scene
	# Transformation : la défense lancée à la course d'élan poursuit sa charge pendant le tir (loi 8).
	if str(plan.get("kind", "")) == "transformation" and tir_au_but(plan): scene = ApresEssai.charge(scene)
	phase = "jeu"
	temps = 0.0
	_attente_place = 0.0
	_resultat_sonne = false
	_plaque = false
	# La clameur et la légende de l'essai partent quand l'essai est à l'écran : fin de la course,
	# ou geste d'essai de la vue aplati (course, ballon porté), voir _essai_attendu.
	_essai_montre = str(plan.get("kind", "")) != "try"
	if str(plan.get("kind", "")) == "penalty": _sonner("penalty", _camp_du_plan(plan))
	if float(plan.get("mouvement", 0.0)) > 0.0:
		_depuis = _derniers.duplicate()
		stage.apply_frame(_image(_interpole(scene, clampf(PAS / float(plan.mouvement), 0.0, 1.0)), false, int(plan.index)))
	else:
		stage.apply_frame(_image(scene, false, int(plan.index)))
	_derniers = _positions(scene)
	_habiller()

## Fin d'une course balle en main : le porteur est plaqué au point où le moteur l'arrête,
## par l'adversaire le plus proche de la scène, puis se relève. Seulement avec la
## bibliothèque d'animations adaptées (CD_MATCH_ANIMATIONS) ; sans elle, rien ne change.
## Pas de plaquage quand le plan suivant est l'essai du même temps fort.
func _plaquer(plan: Dictionary) -> void:
	if str(plan.get("kind", "")) != "carry" or not stage.has_method("jouer_geste") or not stage.has_method("instant_geste"):
		return
	if index + 1 < tf.plans.size() and str(tf.plans[index + 1].get("kind", "")) == "try":
		return
	var scene: Dictionary = plan.scene
	var possession := int(scene.get("possession", -1))
	var porteur: Dictionary = {}
	for joueur: Dictionary in scene.get("players", []):
		if joueur.get("featured", false) and int(joueur.get("side", -1)) == possession:
			porteur = joueur
	if porteur.is_empty():
		return
	var point := Vector2(float(porteur.get("x", 0.0)), float(porteur.get("y", 0.0)))
	var plaqueur := ""
	var proche := 4.0
	for joueur: Dictionary in scene.get("players", []):
		if int(joueur.get("side", -1)) == possession: continue
		var distance := point.distance_to(Vector2(float(joueur.get("x", 0.0)), float(joueur.get("y", 0.0))))
		if distance < proche:
			proche = distance
			plaqueur = str(joueur.get("id", ""))
	# Personne au contact dans la scène : pas de plaquage inventé, le porteur ne tombe pas seul.
	if plaqueur.is_empty():
		return
	# Impact au sol un tiers de seconde après le contact ; le côté ou les jambes selon le joueur.
	var id := str(porteur.get("id", ""))
	var chute := "plaque_cote" if id.hash() % 2 == 0 else "plaque_jambes"
	if stage.jouer_geste(id, chute, maxf(0.0, stage.instant_geste(chute) - 0.35), -1.0, true, [["se_relever", 0.0, 1.9]]):
		stage.jouer_geste(plaqueur, "plaquage", maxf(0.0, stage.instant_geste("plaquage") - 0.35), -1.0, true)

## La phase courante commence à l'écran (plan, plan de liaison, jalon des pistes).
func _image_posee(journal: int) -> void:
	_image_ms = Time.get_ticks_msec()
	_image_journal = journal

## Plan d'essai encore en mouvement à l'instant `instant` (secondes depuis le début du plan) :
## le ballon n'est pas encore aplati à l'écran.
static func essai_en_cours(plan: Dictionary, instant: float) -> bool:
	return str(plan.get("kind", "")) == "try" and instant < float(plan.get("mouvement", 0.0))

## Le plan `index` est une conquête (ballon porté) que l'essai suit sans coupe : sa durée est un
## plancher que le geste de la vue absorbe, pour que la poussée continue jusqu'à la ligne.
static func enchaine_essai(plans: Array, index: int) -> bool:
	if index < 0 or index + 1 >= plans.size(): return false
	var suivant: Dictionary = plans[index + 1]
	return str(plans[index].get("kind", "")) == "setpiece-win" and str(suivant.get("kind", "")) == "try" and not suivant.get("coupe", false)

## Part de la durée d'un plan d'essai au-delà de laquelle il est légendé, même si le geste
## d'essai n'est pas aplati (repli : la légende ne manque jamais l'essai).
const ESSAI_REPLI := 0.85

## L'essai du plan courant n'est pas encore à l'écran : course encore en mouvement, ou geste
## d'essai de la vue (course, ballon porté) pas encore aplati dans l'en-but.
func _essai_attendu(plan: Dictionary) -> bool:
	if str(plan.get("kind", "")) != "try": return false
	if essai_en_cours(plan, temps): return true
	return temps < float(plan.get("duree", 0.0)) * ESSAI_REPLI and stage.has_method("essai_aplati") and not stage.essai_aplati()

## Légende et clameur de l'essai du plan joué, à l'instant où il est aplati à l'écran.
func _legender_essai() -> void:
	# Public de la vue 3D : il attend l'aplati montré (même instant que la légende et la clameur).
	if is_instance_valid(stage) and "essai_attendu_regie" in stage:
		stage.essai_attendu_regie = phase == "jeu" and not _essai_montre and index >= 0 and index < tf.plans.size() and str(tf.plans[index].get("kind", "")) == "try"
	if phase != "jeu" or _essai_montre or index < 0 or index >= tf.plans.size(): return
	if _essai_attendu(tf.plans[index]): return
	_essai_montre = true
	if is_instance_valid(stage) and "essai_attendu_regie" in stage: stage.essai_attendu_regie = false
	_sonner("try", _camp_du_plan(tf.plans[index]))
	# L'essai est aplati et légendé : le bandeau du score passe au nouveau score (+5) au même instant.
	_score = tf.plans[index].get("score", _score)
	_celebrer_essai(tf.plans[index])
	_habiller()

## Un fait vient d'être joué sur le terrain 2D : le bandeau du score le suit.
func _score_joue(marque: Array) -> void:
	if etat != INTER or marque.size() < 2: return
	var differe: Array = between.score_differe()
	var base: Dictionary = _live_inter if not _retenu.is_empty() and not _live_inter.is_empty() else _live
	var montre_score: Array = differe if not differe.is_empty() else base.get("direct", {}).get("score", base.get("score", marque))
	if montre_score.size() >= 2: view.score.text = "%d — %d" % [int(montre_score[0]), int(montre_score[1])]
