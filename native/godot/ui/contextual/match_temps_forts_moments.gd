extends "res://ui/contextual/match_temps_forts_bandeau.gd"
## Régie des temps forts : grands moments (essai, mi-temps, fin de match), ralenti de l'essai, affichage.

## Le son du stade suit ce qui est montré, pas l'avance du moteur.
func _presenter(valeur: bool) -> void:
	var sons: Variant = app.get("soundscape") if is_instance_valid(app) else null
	if is_instance_valid(sons) and sons.has_method("set_presenting"): sons.set_presenting(valeur)

## Camp (0 domicile, 1 extérieur) du fait montré, -1 si le plan ne le dit pas.
func _camp_du_plan(plan: Dictionary) -> int:
	var fait: Variant = plan.get("scene")
	var camp: Variant = fait.get("team", -1) if fait is Dictionary else -1
	return int(camp) if typeof(camp) in [TYPE_INT, TYPE_FLOAT] else -1

## Le fait du plan est à l'écran : la légende et le journal peuvent le dire. Pistes : à leur jalon ;
## tir au but : après la frappe (RESULTAT), jamais pendant la pose « prêt » ; essai : une fois aplati.
## Jamais quand le moteur le calcule ou quand la régie le met en file.
static func fait_a_l_ecran(plan: Dictionary, phase_plan: String, instant: float, essai_montre: bool, jalon_montre: bool) -> bool:
	if phase_plan == "choregraphie": return jalon_montre
	if plan.has("annonce") and (phase_plan == "pret" or instant < RESULTAT): return false
	if phase_plan == "jeu" and str(plan.get("kind", "")) == "try" and not essai_montre: return false
	return true

## Ligne d'état du haut pendant un plan : le fait du plan montré, jamais l'état du moteur (une minute
## d'avance, la mi-temps comprise). Arrêt de jeu (« Essai — X », « Touche pour X », « Mêlée pour X »,
## tir au but) ou possession et territoire de la scène affichée (Between.etat_du_fait).
static func etat_du_plan(plan: Dictionary, equipes: Array, kind: String = "") -> String:
	var scene: Variant = plan.get("scene")
	if not scene is Dictionary: return "Le match"
	var camp: Variant = scene.get("possession", scene.get("team", -1))
	# En-avant : l'équipe fautive, lue sur le fait du moteur (plan.equipe = scene.team du fait, match-direct.cjs) ;
	# la scène 3D normalisée n'a que la possession (vérificateur de #1319 : « En-avant » sans équipe en 3D).
	if (kind if not kind.is_empty() else str(plan.get("kind", ""))) == "hand-fault": camp = plan.get("equipe", scene.get("team", -1))
	if not (camp is int or camp is float): camp = -1
	var ballon: Variant = scene.get("ball")
	var x: float = float(ballon.x) if ballon is Dictionary and (ballon.get("x") is float or ballon.get("x") is int) else NAN
	return Between.etat_du_fait(kind if not kind.is_empty() else str(plan.get("kind", "")), int(camp), x, equipes)

## Ligne d'état pendant la lecture d'un plan, même règle que la légende (`fait_a_l_ecran`) : un arrêt
## de jeu (essai, touche, mêlée…) n'est dit qu'une fois à l'écran ; avant, la possession de la scène
## montrée (le porteur qui court vers la ligne). Tir au but : l'arrêt est connu dès la pose « prêt ».
## Faits sans arrêt de jeu propre (carton, remplacement, consigne, message) : ils tombent pendant
## l'arrêt en cours, le bandeau garde cet arrêt (match filmé du 25/11 : carton pendant une pénalité,
## bandeau revenu à « X a le ballon dans les 22 »).
const PLANS_DANS_L_ARRET := ["card", "sub", "tactic", "message"]

## Ligne d'état du plan `i` de `plans` : celle du plan (etat_montre), ou, pour un carton, un
## remplacement ou une consigne, celle du dernier plan qui porte l'arrêt de jeu (déjà montré).
static func etat_montre_dans(plans: Array, i: int, phase_plan: String, instant: float, essai_montre: bool, jalon_montre: bool, equipes: Array) -> String:
	var k := i
	while k > 0 and plans[k] is Dictionary and str(plans[k].get("kind", "")) in PLANS_DANS_L_ARRET:
		k -= 1
	if k == i: return etat_montre(plans[i], phase_plan, instant, essai_montre, jalon_montre, equipes)
	return etat_montre(plans[k], "jeu", INF, true, true, equipes)

## Bandeau d'une liaison : « Pénalité pour X », « Touche pour X », « Mêlée pour X » (remises en jeu,
## comme la ligne d'état des plans) ; « En-avant — X », « Essai — X » pour un fait ; libellé seul sans
## équipe. Match filmé du 25/11 : « Pénalité Alder Fen XV ».
const LIAISON_POUR := ["Touche", "Mêlée", "Pénalité", "Renvoi", "Renvoi aux 22", "Renvoi d'en-but"]
static func texte_bandeau(libelle: String, club: String) -> String:
	if libelle.is_empty() or club.is_empty(): return libelle
	return ("%s pour %s" if libelle in LIAISON_POUR else "%s — %s") % [libelle, club]

static func etat_montre(plan: Dictionary, phase_plan: String, instant: float, essai_montre: bool, jalon_montre: bool, equipes: Array) -> String:
	if plan.has("annonce") or fait_a_l_ecran(plan, phase_plan, instant, essai_montre, jalon_montre): return etat_du_plan(plan, equipes)
	return etat_du_plan(plan, equipes, "carry")

## Modèle tel que la ligne météo du bandeau peut le dire : pendant un temps fort, la mi-temps déjà
## atteinte par le moteur attend la fin de l'action.
static func meteo_montree(live: Dictionary, en_temps_fort: bool) -> Dictionary:
	if not en_temps_fort or not bool(live.get("atBreak", false)): return live
	var avant := live.duplicate()
	avant["atBreak"] = false
	return avant

func _duree_entracte() -> float:
	return 0.0 if niveau == "integral" else entracte / maxf(vitesse, 0.01)

## Vrai pendant l'entracte, temps fort reçu ou non (la commande « Passer » est proposée).
func entracte_en_cours() -> bool:
	return etat != JEU and (not _retenu.is_empty() or (_entracte >= 0.0 and _entracte < _duree_entracte()))

## « Passer » : l'entracte s'abrège ; sans temps fort reçu, les minutes s'enchaînent sans
## attendre l'horloge jusqu'au prochain.
func passer() -> void:
	# Ralenti de l'essai : abrégé, la vue normale reprend (célébration, puis transformation).
	if rejeu_en_cours():
		_rejeu_passe = true
		_finir_rejeu()
		return
	# Sortie des joueurs (mi-temps, fin de match) : abrégée, la causerie ou l'écran de fin suit.
	if etat == SORTIE:
		_finir_sortie(true)
		return
	if etat == JEU or _live.get("finished", false): return
	_passer = true
	suivi.append({"evenement": "entracte_passe", "debut_ms": Time.get_ticks_msec()})

## Horloge à montrer : `heure` (« 23 », « 40+2 ») et `secondes`, ou la plus avancée déjà montrée dans la
## période si elle est plus loin ([minute écrite, secondes]). Retient la plus avancée.
func retenir_horloge(heure: String, secondes: int) -> Array:
	var total := 0
	for morceau: String in heure.split("+"): total += int(morceau)
	total = total * 60 + secondes
	# Nouvelle période : « 40 » après « 40+2 » est le coup d'envoi de la seconde, pas un recul (vérificateur de
	# #1319, film 2 : « 40+2:05 » resté après la mi-temps).
	if _horloge_vue.size() >= 3 and nouvelle_periode(str(_horloge_vue[0]), heure): _horloge_vue = []
	if _horloge_vue.size() < 3 or total >= int(_horloge_vue[2]): _horloge_vue = [heure, secondes, total]
	return [str(_horloge_vue[0]), int(_horloge_vue[1])]

## `apres` est d'une période plus récente que `avant` : `avant` est un temps additionnel (« 40+2 ») et `apres`
## une minute simple au moins égale à sa base (« 40 », « 41 ») ; dans une même période, l'horloge ne revient
## jamais d'un temps additionnel à une minute simple.
static func nouvelle_periode(avant: String, apres: String) -> bool:
	avant = avant.trim_suffix("′").strip_edges()
	apres = apres.trim_suffix("′").strip_edges()
	if not "+" in avant or not apres.is_valid_int(): return false
	return int(apres) >= int(avant.split("+")[0])

static func _minute_lisible(texte: String) -> bool:
	return not texte.is_empty() and texte.replace("+", "").is_valid_int()

## Part écoulée de la minute affichée (0 à 1), d'après l'horloge choisie.
func _part_minute() -> float:
	return clampf(_roule / maxf(0.05, float(HORLOGES[horloge])), 0.0, 0.999)

## Horloge de l'écran intermédiaire : minute du moteur et secondes qui roulent (« 23:41 »,
## « 40+2:15 ») ; pendant un temps fort retenu, les secondes finissent la minute au rythme
## de l'entracte. Bandeau masqué par l'état (mi-temps, fin) sinon.
func _habiller_horloge() -> void:
	if etat == JEU or _live.is_empty(): return
	var montre_live: Dictionary = _live_inter if not _live_inter.is_empty() else _live
	if montre_live.get("finished", false) or _live.get("finished", false) or montre_live.get("atBreak", false):
		_horloge_vue = []
		between.montrer_entracte("", false)
		return
	var part := _part_minute()
	var reste := 0.0
	if not _retenu.is_empty():
		var k := clampf(_retenu_depuis / maxf(0.05, _retenu_reste), 0.0, 1.0)
		part = lerpf(_retenu_part, 0.999, k)
		reste = maxf(0.0, _duree_entracte() - _entracte) if _entracte >= 0.0 else 0.0
	var heure := _horloge_inter.trim_suffix("′").strip_edges()
	# Le terrain 2D rejoue encore des faits en retard : l'horloge suit la minute qu'il montre.
	var differee: String = between.horloge_differee().trim_suffix("′").strip_edges()
	# Sinon, la minute du dernier fait montré (le moteur a de l'avance : rien d'un temps fort à venir).
	if differee.is_empty(): differee = _horloge_montree.trim_suffix("′").strip_edges()
	# Fait d'une période finie (« 40+2 », le moteur déjà en seconde période) : ce n'est pas l'heure du jeu.
	if _minute_lisible(differee) and not (_minute_lisible(heure) and nouvelle_periode(differee, heure)): heure = differee
	# Arrêt-décision ouvert : sa carte dit la minute du fait (« CARTON JAUNE · 33′ ») ; l'horloge la rejoint, sans
	# jamais reculer (vérificateur de #1319, film 2 : carte « 33′ » sous une horloge à 31:59).
	var minute_arret := str(arret.get("horloge", "")).trim_suffix("′").strip_edges() if not arret.is_empty() else ""
	if _minute_lisible(minute_arret): retenir_horloge(minute_arret, 0)
	if _minute_lisible(heure):
		# Les sources de la minute (moteur, terrain 2D en retard, dernier fait montré) et des secondes (minute
		# qui roule, entracte d'un temps fort retenu) changent d'une image à l'autre : jamais en arrière.
		var montree := retenir_horloge(heure, int(part * 60.0))
		view.clock.text = "%s:%02d" % [montree[0], int(montree[1])]
	var texte := ""
	if not _retenu.is_empty() and not _passer:
		texte = "Prochaine action dans %d s" % ceili(reste) if reste > 0.0 else ""
		if _tiroir or _live.get("paused", false): texte = "Prochaine action à la reprise"
	between.montrer_entracte(texte, entracte_en_cours() or not _retenu.is_empty())

# --- Lecture d'un temps fort -------------------------------------------------

func _image(scene: Dictionary, fige: bool, jusque: int) -> Dictionary:
	# Le journal est tronqué à l'action montrée : les gestes de la vue le lisent.
	var journal: Array = _events.slice(0, jusque + 1) if jusque >= 0 and jusque < _events.size() else _events
	# Météo du direct transmise telle quelle : la vue en tire la pluie décorative (match_ambiance.gd).
	return {"scene": scene, "teams": _teams, "events": journal, "paused": fige, "finished": false, "atBreak": false,
		"meteo": _live.get("meteo"), "weather": _live.get("weather", "")}

## Bandeau du haut pendant le plan de liaison en cours : l'arrêt de jeu et l'équipe qu'il nomme.
func bandeau_liaison() -> String:
	var bandeaux: Array = liaison.get("bandeaux", [])
	if _liaison_plan >= bandeaux.size() or not bandeaux[_liaison_plan] is Dictionary: return ""
	var b: Dictionary = bandeaux[_liaison_plan]
	var libelle := str(b.get("libelle", ""))
	var camp := int(b.get("equipe", -1))
	if libelle.is_empty(): return ""
	if camp in [0, 1] and camp < _teams.size() and _teams[camp] is Dictionary: return texte_bandeau(libelle, S.G.club_name(_teams[camp]))
	return libelle

func _vers_inter() -> void:
	# Le terrain 2D reprend où le temps fort s'est arrêté : rien de ce qu'il a montré n'est rejoué.
	if etat != INTER and not tf.is_empty(): between.terrain.recaler(int(tf.get("fin", -1)))
	# L'entracte se compte depuis l'apparition de l'écran intermédiaire (l'attente en 3D n'en fait pas partie).
	if etat != INTER and _entracte >= 0.0: _entracte = 0.0
	etat = INTER
	attente = 0.0
	_moment_essai = 0.0
	_regler_ralenti()
	_finir_rejeu()
	_rejeu_du = false
	# Le bandeau « ESSAI » finit sa durée même si l'écran intermédiaire revient entre l'essai et la transformation.
	if _bandeau_titre != "ESSAI": _cacher_bandeau()
	_presenter(false)
	if cadrage != null: cadrage.regler(false)
	_montrer_jeu(false)
	suivi.append({"evenement": "intermediaire", "horloge": str(_live.get("direct", {}).get("horloge", "")), "debut_ms": Time.get_ticks_msec()})

func _apres_lecture() -> void:
	# Arrêt-décision : jamais au milieu d'un temps fort, toujours après.
	if _arret_attendu.is_empty(): return
	arret = _arret_attendu
	_arret_attendu = {}
	between.montrer_arret(arret)
	suivi.append({"evenement": "arret", "cle": str(arret.get("cle", "")), "horloge": str(arret.get("horloge", "")), "debut_ms": Time.get_ticks_msec()})
	if not _live.get("paused", false) and not _live.get("finished", false):
		_pause_envoyee = app._command("pause", {"paused": true})

# --- Affichage ---------------------------------------------------------------

func _montrer_jeu(visible_3d: bool) -> void:
	if _fondu != null and _fondu.is_valid(): _fondu.kill()
	# Animations réduites : coupe franche entre la 3D et l'entracte, sans fondu.
	if _calme():
		between.visible = not visible_3d
		between.modulate.a = 1.0
		voile.visible = not visible_3d
		voile.modulate.a = 1.0
		return
	if visible_3d:
		between.hide()
		if not voile.visible: return
		_fondu = create_tween()
		_fondu.tween_property(voile, "modulate:a", 0.0, FONDU)
		_fondu.tween_callback(voile.hide)
	else:
		voile.show()
		between.show()
		between.modulate.a = 0.0
		_fondu = create_tween().set_parallel(true)
		_fondu.tween_property(voile, "modulate:a", 1.0, FONDU)
		_fondu.tween_property(between, "modulate:a", 1.0, FONDU)
		# La 3D continue d'être rendue sous le voile : arrêter puis relancer la sous-vue
		# n'apportait qu'une économie et ajoutait un état de plus au moment des coupes.

func _habiller() -> void:
	# Mi-temps, fin de match : une fois le temps fort fini, la 3D restée à l'écran montre tout le terrain.
	if is_instance_valid(stage) and stage.has_method("set_plan_large"):
		stage.set_plan_large(etat != JEU and (bool(_live.get("atBreak", false)) or bool(_live.get("finished", false))))
	# Le journal ouvert suit l'image, pas l'avance du moteur.
	if view.drawer.visible and view.drawer_tab == "Journal": view._update_drawer()
	# Pendant un temps fort, le bandeau montre l'instant rejoué, pas l'état du moteur.
	var legende: Control = view.events.get_parent().get_parent().get_parent()
	# Ligne d'état du haut : pendant un plan, le fait du plan affiché (essai, touche, possession…),
	# jamais l'état du moteur (une minute d'avance, mi-temps comprise) ; en liaison, l'arrêt de jeu
	# (plus bas) ; la 3D tenue après le temps fort garde le dernier fait montré ; ailleurs (écran
	# intermédiaire, sortie), l'état du terrain 2D et du moteur borné (match_between.gd).
	if etat == JEU and phase != "liaison" and index >= 0 and index < tf.get("plans", []).size():
		between.forcer_etat(etat_montre_dans(tf.plans, index, phase, temps, _essai_montre, _jalon_montre, _teams))
	elif etat != JEU and etat != ATTENTE:
		between.forcer_etat("")
	_habiller_meteo()
	if etat == SORTIE:
		# Plan large et sortie des joueurs : score du moteur (tout a été montré), mi-temps ou fin.
		var marque_sortie: Array = _live.get("direct", {}).get("score", _live.get("score", [0, 0]))
		if marque_sortie.size() >= 2: view.score.text = "%d — %d" % [int(marque_sortie[0]), int(marque_sortie[1])]
		view.clock.text = "TERMINÉ" if _live.get("finished", false) else "MI-TEMPS"
		_horloge_vue = []
		legende.hide()
		_valider(false)
		return
	if etat == INTER:
		_legende_tracee = ""
		legende.hide()
		# Retour à l'état du moteur, avec la même écriture de l'horloge que pendant un
		# temps fort (40+2′ en arrêts de jeu).
		# Temps fort retenu par l'entracte : score et horloge d'avant lui (rien n'est annoncé avant l'image).
		var montre_live: Dictionary = _live_inter if not _retenu.is_empty() and not _live_inter.is_empty() else _live
		# Score de ce qui a été montré, pas celui du moteur (une minute d'avance).
		var marque: Array = montre_live.get("direct", {}).get("score", montre_live.get("score", [0, 0]))
		# Le terrain 2D rejoue encore des faits en retard sur le moteur : le score suit ce qu'il montre.
		var differe: Array = between.score_differe()
		if not differe.is_empty(): marque = differe
		if marque.size() >= 2: view.score.text = "%d — %d" % [int(marque[0]), int(marque[1])]
		var heure := str(montre_live.get("direct", {}).get("horloge", ""))
		if _live.get("finished", false) and _retenu.is_empty(): view.clock.text = "TERMINÉ"
		elif montre_live.get("atBreak", false): view.clock.text = "MI-TEMPS"
		elif not heure.is_empty(): view.clock.text = heure
		_habiller_horloge()
		_valider(_live.get("finished", false) and _retenu.is_empty())
		if not voile.visible:
			voile.modulate.a = 1.0
			voile.show()
			between.modulate.a = 1.0
			between.show()
		return
	if index < 0 or index >= tf.get("plans", []).size(): return
	var plan: Dictionary = tf.plans[index]
	# Le dernier temps fort se regarde avant de valider la journée.
	_valider(false)
	if phase == "liaison":
		# Liaison : le fait d'arrêt de jeu (touche, en-avant, pénalité), rien de l'action à venir ;
		# l'horloge reste celle du temps fort précédent (arrêt de jeu).
		if _score.size() >= 2: view.score.text = "%d — %d" % [int(_score[0]), int(_score[1])]
		var textes: Array = liaison.get("textes", [])
		view.events.text = str(textes[_liaison_plan]) if _liaison_plan < textes.size() else str(liaison.get("texte", ""))
		# Bandeau du haut : l'arrêt de jeu en cours (« Touche Toulouse Capitole XV »), pas la
		# situation du moteur (ballon dans les 22…) ni ce qui va suivre.
		between.forcer_etat(bandeau_liaison())
		view.events.get_parent().get_parent().visible = not view.events.text.is_empty()
		legende.visible = not view.events.text.is_empty()
		_tracer_legende()
		return
	view.clock.text = str(plan.get("horloge", ""))
	# La 3D a montré cette minute : l'écran intermédiaire qui suit ne revient pas avant elle.
	var minute_plan := str(plan.get("horloge", "")).trim_suffix("′").strip_edges()
	if not minute_plan.is_empty() and minute_plan.replace("+", "").is_valid_int(): retenir_horloge(minute_plan, 0)
	if _score.size() >= 2: view.score.text = "%d — %d" % [int(_score[0]), int(_score[1])]
	# Pistes : un plan n'est courant qu'à son jalon (passage du ballon pour un tir) : le résultat est montré.
	var attend_resultat: bool = plan.has("annonce") and phase != "choregraphie" and (phase == "pret" or temps < RESULTAT)
	view.events.text = str(plan.get("annonce" if attend_resultat else "texte", ""))
	# Essai : rien n'est écrit tant que le porteur n'a pas aplati à l'écran (lot 5, choix de Léo :
	# rien n'annonce le contenu d'une action avant qu'on la voie).
	if phase == "jeu" and not _essai_montre and str(plan.get("kind", "")) == "try": view.events.text = str(plan.get("annonce", ""))
	# Pistes du chorégraphe : jamais un fait (l'essai compris) annoncé avant d'être à l'écran.
	if phase == "choregraphie" and not _jalon_montre: view.events.text = ""
	view.events.get_parent().get_parent().visible = not view.events.text.is_empty()
	legende.visible = not view.events.text.is_empty()
	_tracer_legende()

## Diagnostic texte / image : chaque nouvelle légende entre au suivi de la régie avec l'instant où
## elle s'affiche et celui où la phase correspondante a commencé à l'écran (report.json du match
## filmé ; CD_MATCH_TRACE_LEGENDE=1 l'écrit aussi dans la sortie, préfixe LEGENDE_IMAGE).
func _tracer_legende() -> void:
	var texte := str(view.events.text)
	if texte == _legende_tracee: return
	_legende_tracee = texte
	if texte.is_empty(): return
	var maintenant := Time.get_ticks_msec()
	var plan: Dictionary = {}
	if index >= 0 and index < tf.get("plans", []).size(): plan = tf.plans[index]
	var fait := meta_legende(phase, plan, liaison, _liaison_plan)
	var trace := {"evenement": "legende", "texte": texte, "phase": phase, "kind": fait.kind, "journal": fait.journal,
		"horloge": fait.horloge, "texte_ms": maintenant, "image_ms": _image_ms, "image_journal": _image_journal,
		"ecart_ms": maintenant - _image_ms, "debut_ms": maintenant}
	suivi.append(trace)
	if OS.get_environment("CD_MATCH_TRACE_LEGENDE") == "1": print("LEGENDE_IMAGE ", JSON.stringify(trace))

## Fait que dit la légende : en liaison, c'est l'arrêt de jeu qui clôt le temps fort précédent (essai, touche...),
## pas le plan à venir (kind, journal et horloge du plan courant décriraient la suite, pas ce texte).
## L'horloge d'un arrêt n'est pas connue ici : vide plutôt que celle de la suite.
static func meta_legende(phase_: String, plan: Dictionary, lien: Dictionary, k: int) -> Dictionary:
	if phase_ == "liaison" and not lien.is_empty():
		var arrets: Array = lien.get("arrets", [])
		var kinds: Array = lien.get("kinds", [])
		return {"kind": str(kinds[k]) if k < kinds.size() else "", "journal": int(arrets[k]) if k < arrets.size() else int(lien.get("arret", -1)), "horloge": ""}
	return {"kind": str(plan.get("kind", "")), "journal": int(plan.get("index", -1)), "horloge": str(plan.get("horloge", ""))}

## Ligne météo du bandeau (posée par la vue avec l'état du moteur) : rien de la mi-temps avant la fin de l'action.
func _habiller_meteo() -> void:
	var ligne: Variant = view.get("meteo_ligne")
	if not ligne is Label: return
	var montre_live := meteo_montree(_live, etat == JEU)
	(ligne as Label).text = Meteo.bandeau(montre_live)
	(ligne as Label).visible = not (ligne as Label).text.is_empty()
	(ligne as Label).add_theme_color_override("font_color", Charte.IVOIRE if montre_live.get("atBreak", false) else Charte.IVOIRE_2)

func _valider(visible_fin: bool) -> void:
	if view.finish.visible == visible_fin: return
	view.finish.visible = visible_fin
	view.finish.set_meta("contextual_enabled", visible_fin)
	if is_instance_valid(view.director): view.director._refresh_controls()

# --- Grands moments : essai, mi-temps, fin de match ---------------------------

## Sortie des joueurs mise en scène (repli : CD_MATCH_SORTIE=0, causerie aussitôt comme avant).
static func sorties_actives() -> bool:
	return OS.get_environment("CD_MATCH_SORTIE") != "0"

## Clé de la sortie que ce modèle annonce : « <rencontre>|mi-temps » ou « <rencontre>|fin » ; vide
## hors mi-temps et fin de match, ou sans projection du moteur.
static func cle_sortie(live: Dictionary) -> String:
	var direct: Variant = live.get("direct")
	if not direct is Dictionary: return ""
	var rencontre := str(direct.get("rencontre", "")) + "|"
	if bool(live.get("finished", false)): return rencontre + "fin"
	if bool(live.get("atBreak", false)): return rencontre + "mi-temps"
	return ""

## Vrai quand la mi-temps ou la fin de match de ce modèle n'a pas encore eu sa sortie des joueurs
## (une fois par rencontre et par moment, même si la vue est recréée). Une fin confiée à l'adjoint
## passe directement au débrief.
func sortie_due(live: Dictionary) -> bool:
	if not sorties_actives() or not is_instance_valid(stage) or not stage.has_method("sortir_du_terrain"): return false
	var cle := cle_sortie(live)
	if cle.is_empty() or cle == str(app.management_ui.get("match_temps_forts_sortie", "")): return false
	return not (bool(live.get("finished", false)) and str(app.get("last_command")) == "delegate")

func sortie_en_cours() -> bool:
	return etat == SORTIE

## Plan large, bandeau « MI-TEMPS » ou « FIN DU MATCH » (score), puis la marche vers le tunnel.
## Depuis l'écran intermédiaire, la 3D revient sur la dernière scène du moteur.
func _debut_sortie() -> void:
	var depuis_inter := etat == INTER
	var cle := cle_sortie(_live)
	app.management_ui["match_temps_forts_sortie"] = cle
	_moment_essai = 0.0
	_regler_ralenti()
	# Mi-temps, fin de match : jamais de ralenti (ni rallongé, ni en cours).
	_finir_rejeu()
	_rejeu_du = false
	if depuis_inter or stage._actors.is_empty():
		var scene: Variant = _live.get("scene")
		if scene is Dictionary and scene.get("players") is Array and not (scene.players as Array).is_empty():
			# Posée d'un coup (coupe), puis vivante : les joueurs respirent sous le plan large.
			stage.apply_frame(_image(scene, true, _events.size() - 1))
			stage.apply_frame(_image(scene, false, _events.size() - 1))
	if stage._actors.is_empty():
		# Aucun joueur à montrer : pas de plan large d'un terrain vide, la causerie suit.
		suivi.append({"evenement": "sortie_refusee", "cle": cle, "debut_ms": Time.get_ticks_msec()})
		if etat != INTER: _vers_inter()
		_apres_lecture()
		if is_instance_valid(view.director): view.director.call_deferred("sync")
		return
	etat = SORTIE
	_sortie_depuis_inter = depuis_inter
	index = -1
	phase = "jeu"
	gel = false
	_sortie_t = 0.0
	if cadrage != null: cadrage.regler(false)
	if arbitre != null: arbitre.dirige = false
	_presenter(true)
	_montrer_jeu(true)
	stage.set_plan_large(true)
	var fin: bool = _live.get("finished", false)
	montrer_bandeau("FIN DU MATCH" if fin else "MI-TEMPS", _ligne_score(), "", SORTIE_LARGE + SORTIE_MARCHE)
	suivi.append({"evenement": "sortie", "moment": "fin" if fin else "mi-temps", "cle": cle, "depuis_inter": depuis_inter,
		"joueurs": stage._actors.size(), "debut_ms": Time.get_ticks_msec()})
	_habiller()

## Secondes de sortie écoulées (`pas` : temps de la régie, accéléré seulement dans les tests).
func _lire_sortie(pas: float) -> void:
	var avant := _sortie_t
	_sortie_t += pas
	if avant < SORTIE_LARGE and _sortie_t >= SORTIE_LARGE and stage.has_method("sortir_du_terrain"):
		stage.sortir_du_terrain(true)
		# Coupe sur le plan serré : le bandeau descend sur la même image.
		if bandeau != null and bandeau.visible: _placer_bandeau()
		_noter_sortie({"marche_ms": Time.get_ticks_msec(), "plan_serre": bool(stage.get("plan_sortie"))})
	if _sortie_t >= SORTIE_LARGE + SORTIE_MARCHE: _finir_sortie(false)

## Fin de la sortie (à son terme ou abrégée) : écran intermédiaire, puis causerie ou écran de fin.
func _finir_sortie(passe: bool) -> void:
	if etat != SORTIE: return
	var debut := 0
	for i in range(suivi.size() - 1, -1, -1):
		if str(suivi[i].get("evenement", "")) == "sortie":
			debut = int(suivi[i].get("debut_ms", 0))
			break
	_noter_sortie({"duree_reelle": (Time.get_ticks_msec() - debut) / 1000.0, "passe": passe, "marche": _sortie_t >= SORTIE_LARGE})
	_cacher_bandeau()
	# Venue de l'écran intermédiaire : le terrain 2D garde où il en était (rien n'est recalé).
	if _sortie_depuis_inter: etat = INTER
	_vers_inter()
	_apres_lecture()
	_habiller()
	# La causerie ou le débrief retenus par la sortie peuvent s'ouvrir.
	if is_instance_valid(view.director): view.director.call_deferred("sync")

func _noter_sortie(champs: Dictionary) -> void:
	for i in range(suivi.size() - 1, -1, -1):
		if str(suivi[i].get("evenement", "")) == "sortie":
			suivi[i].merge(champs, true)
			return

## Échap, Entrée, Espace ou un clic pendant la sortie ou le ralenti de l'essai : la séquence est abrégée.
func _input(event: InputEvent) -> void:
	if etat != SORTIE and not rejeu_en_cours(): return
	var touche := event as InputEventKey
	var souris := event as InputEventMouseButton
	if touche != null and touche.pressed and not touche.echo and (touche.is_action("ui_accept") or touche.is_action("ui_cancel") or touche.keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		passer()
	elif souris != null and souris.pressed and souris.button_index == MOUSE_BUTTON_LEFT:
		passer()

## Marqueur d'un essai d'après sa légende ou le journal (« TLS · Essai de Jean Dupont sur ballon
## porté. », « … Essai de J. Dupont, transformé. 7 – 0. ») ; vide si le texte ne le nomme pas.
static func marqueur_essai(texte: String) -> String:
	var corps := texte.strip_edges()
	var point := corps.find(" · ")
	if point >= 0: corps = corps.substr(point + 3)
	# Score en fin de ligne du journal (« 7 – 0. ») : retiré avant de lire le nom.
	corps = RegEx.create_from_string("\\s*\\d+\\s*[–-]\\s*\\d+\\.?$").sub(corps, "")
	var trouve := RegEx.create_from_string("^Essai(?: décisif)? de (.+?)(?: sur ballon porté| sur mêlée)?(?:,.*)?\\.?$").search(corps)
	return trouve.get_string(1).strip_edges() if trouve != null else ""

## Vitesse de la vue pendant le moment d'essai, d'après les secondes qui en restent : creux du
## ralenti au début, retour à la vitesse réelle avant l'image tenue de la fin.
static func ralenti_essai(reste: float) -> float:
	if reste <= 0.0: return 1.0
	var k := 1.0 - clampf(reste / ESSAI_MOMENT, 0.0, 1.0)
	return lerpf(ESSAI_RALENTI, 1.0, smoothstep(0.35, 0.75, k))

## Essai aplati à l'écran : bandeau « ESSAI » (marqueur, équipe), ralenti puis image tenue.
func _celebrer_essai(plan: Dictionary) -> void:
	_moment_essai = ESSAI_MOMENT
	ralenti_min = 1.0
	_regler_ralenti()
	# Ralenti de l'essai : la vue cale sa fenêtre sur l'aplati ; il partira à la fin du moment.
	_rejeu_du = not _calme() and is_instance_valid(stage) and stage.has_method("reperer_rejeu") and stage.reperer_rejeu()
	var camp := _camp_du_plan(plan)
	if camp not in [0, 1] and plan.get("scene") is Dictionary: camp = int(plan.scene.get("possession", -1))
	var equipe := S.G.club_name(_teams[camp]) if camp in [0, 1] and camp < _teams.size() and _teams[camp] is Dictionary else ""
	var nom := marqueur_essai(str(plan.get("texte", "")))
	var fait := int(plan.get("index", -1))
	if nom.is_empty() and fait >= 0 and fait < _events.size() and _events[fait] is Dictionary: nom = marqueur_essai(str(_events[fait].get("text", "")))
	# Bannière à la couleur du club qui marque (charte §7) : « Club · 52e minute », +5 et le score.
	var couleur := Color.TRANSPARENT
	if camp in [0, 1] and camp < _teams.size() and _teams[camp] is Dictionary:
		couleur = Color.from_string(str(S.G.identity(_teams[camp]).get("color", "")), Charte.CLUB)
	var contexte := equipe
	var minute := str(plan.get("horloge", "")).trim_suffix("′").strip_edges()
	if minute.is_valid_int(): contexte = "%s · %se minute" % [equipe, minute] if not equipe.is_empty() else "%se minute" % minute
	var marque: Array = plan.get("score", []) if plan.get("score") is Array else []
	var points := "+5\n%d – %d" % [int(marque[0]), int(marque[1])] if marque.size() >= 2 else "+5"
	montrer_bandeau("ESSAI", nom, contexte, ESSAI_BANDEAU, couleur, points)
	suivi.append({"evenement": "essai_moment", "cle": str(tf.get("cle", "")), "plan": index, "marqueur": nom, "equipe": equipe, "debut_ms": Time.get_ticks_msec()})

## Le temps fort mérite l'enregistrement du ralenti : il contient un essai, animations non réduites.
static func rejeu_voulu(plans: Array, calme: bool) -> bool:
	if calme: return false
	for plan: Variant in plans:
		if plan is Dictionary and str(plan.get("kind", "")) == "try": return true
	return false

func rejeu_en_cours() -> bool:
	return is_instance_valid(stage) and stage.has_method("rejeu_actif") and stage.rejeu_actif()

## Ce que montre la mention « RALENTI » (tests, match filmé).
func mention_affichee() -> bool:
	return is_instance_valid(mention) and mention.visible

## Fin du moment d'essai : le ralenti part s'il est dû (essai repéré, animations non réduites).
func _lancer_rejeu() -> bool:
	if not _rejeu_du: return false
	_rejeu_du = false
	if _calme() or not is_instance_valid(stage) or not stage.has_method("commencer_rejeu"): return false
	if not stage.commencer_rejeu(Rejeu.VITESSE * vitesse):
		suivi.append({"evenement": "rejeu_refuse", "cle": str(tf.get("cle", "")), "debut_ms": Time.get_ticks_msec()})
		return false
	var info: Dictionary = stage.rejeu_etat()
	_rejeu_passe = false
	montrer_mention()
	suivi.append({"evenement": "rejeu", "cle": str(tf.get("cle", "")), "plan": index, "vitesse": Rejeu.VITESSE, "vitesse_regie": vitesse,
		"duree_source": float(info.get("duree_source", 0.0)), "duree_prevue": float(info.get("duree_source", 0.0)) / Rejeu.VITESSE,
		"hauteur_camera": float(info.get("hauteur_camera", 0.0)), "gene_angle": float(info.get("gene_angle", 0.0)), "retrait": float(info.get("retrait", 0.0)), "debut_ms": Time.get_ticks_msec()})
	return true

## Abrège le ralenti en cours (l'état d'avant est remis par la vue, puis `_rejeu_fini`).
func _finir_rejeu() -> void:
	if rejeu_en_cours(): stage.finir_rejeu()
	elif mention_affichee(): _cacher_mention()

## La vue a fini le ralenti (à son terme ou abrégé) : mention retirée sur la même image, durée notée.
func _rejeu_fini() -> void:
	_cacher_mention()
	var info: Dictionary = stage.rejeu_etat() if is_instance_valid(stage) and stage.has_method("rejeu_etat") else {}
	for i in range(suivi.size() - 1, -1, -1):
		if str(suivi[i].get("evenement", "")) != "rejeu": continue
		if not suivi[i].has("duree_reelle"):
			suivi[i]["duree_reelle"] = (Time.get_ticks_msec() - int(suivi[i].get("debut_ms", 0))) / 1000.0
			suivi[i]["duree_lue"] = float(info.get("ecoule", 0.0))
			suivi[i]["passe"] = _rejeu_passe
			# Écart entre l'état remis et l'état d'avant (0 : identique ; 999 : joueur ou ballon différent).
			suivi[i]["ecart_restitution"] = minf(float(info.get("ecart_restitution", 999.0)), 999.0)
		break
	_rejeu_passe = false

## Mention « RALENTI » des retransmissions : petite pilule sur panneau 90 %, sans animation (charte finale).
static func construire_mention() -> PanelContainer:
	var cadre := PanelContainer.new()
	cadre.name = "MatchRalenti"
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(Charte.PANNEAU, 0.9)
	fond.set_corner_radius_all(Charte.RAYON_PILULE)
	fond.anti_aliasing = true
	fond.content_margin_left = 14
	fond.content_margin_right = 14
	fond.content_margin_top = 2
	fond.content_margin_bottom = 3
	cadre.add_theme_stylebox_override("panel", fond)
	var titre := S.label("RALENTI", 18, Charte.IVOIRE)
	titre.name = "MatchRalentiTitre"
	titre.add_theme_font_override("font", Charte.TITRE_GRAS)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(titre)
	cadre.hide()
	return cadre

## Taille du texte de la mention pour une image de `hauteur` pixels : discrète, lisible.
static func taille_mention(hauteur: float) -> int:
	return clampi(roundi(hauteur * MENTION_TAILLE), 16, 40)

## Place de la mention (repère de la vue) : coin haut droit de la zone libre qui commence à `haut_libre`.
static func place_mention(ecran: Vector2, taille: Vector2, haut_libre: float) -> Vector2:
	var marge := roundf(ecran.y * MENTION_MARGE)
	return Vector2(roundf(maxf(0.0, ecran.x - taille.x - marge)), roundf(haut_libre + marge))

func montrer_mention() -> void:
	if not is_instance_valid(mention) or view == null: return
	var titre: Label = mention.find_child("MatchRalentiTitre", true, false)
	if titre != null: titre.add_theme_font_size_override("font_size", taille_mention(maxf(1.0, view.size.y)))
	mention.reset_size()
	mention.show()
	_placer_mention()

func _placer_mention() -> void:
	if not is_instance_valid(mention) or view == null: return
	var haut: float = (_espace.get_global_rect().position.y if is_instance_valid(_espace) else view.clock.get_global_rect().end.y) - view.get_global_rect().position.y
	mention.reset_size()
	mention.position = place_mention(Vector2(view.size.x, maxf(1.0, view.size.y)), mention.size, haut)

func _cacher_mention() -> void:
	if is_instance_valid(mention): mention.hide()

func _regler_ralenti() -> void:
	if not is_instance_valid(stage) or not stage.has_method("set_ralenti"): return
	var facteur := 1.0 if _moment_essai <= 0.0 or _calme() else ralenti_essai(_moment_essai)
	ralenti_min = minf(ralenti_min, facteur)
	stage.set_ralenti(facteur)

func _ligne_score() -> String:
	var marque: Array = _live.get("direct", {}).get("score", _live.get("score", [0, 0]))
	if _teams.size() < 2 or marque.size() < 2 or not _teams[0] is Dictionary or not _teams[1] is Dictionary: return ""
	return "%s   %d — %d   %s" % [S.G.club_name(_teams[0]), int(marque[0]), int(marque[1]), S.G.club_name(_teams[1])]
