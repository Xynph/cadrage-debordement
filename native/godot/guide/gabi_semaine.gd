extends RefCounted
## « Ta semaine, vue par Gabi » : la synthèse que Gabi commente au Bureau, debout dans sa zone (option C,
## choisie par Léo le 13/11/2026). Quatre lignes, dans sa voix : prochain match, forme du groupe, l'alerte
## la plus importante, et un conseil avec une action (« Suivre le conseil »).
## Tout vient du modèle projeté par le moteur (ce que le manager voit) : jamais d'information cachée.
## Déterministe : mêmes données, même synthèse.

const Avis = preload("res://guide/gabi_avis.gd")
const P = preload("res://ui/immersive08/projection.gd")
const G = preload("res://ui/game_skin.gd")

const OR := "or"
const MENTHE := "menthe"
const AMBRE := "ambre"
const ROUGE := "rouge"
const JOURS := ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]

## {lignes: [{cle, libelle, icone, couleur, texte}], conseil: {texte, categorie, ton, action}}.
static func synthese(model: Dictionary) -> Dictionary:
	if not model.get("club") is Dictionary: return {}
	var fixture := prochain_match(model)
	var jours := jours_avant(model, fixture)
	var lignes: Array = [_ligne_match(model, fixture, jours), _ligne_groupe(model), _ligne_alerte(model, fixture, jours)]
	return {"lignes": lignes, "conseil": conseil(model, fixture, jours)}

static func _nombre(value: Variant, defaut: float = 0.0) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else defaut

## Prochaine rencontre du club : la feuille du jour, sinon la première rencontre non jouée du calendrier.
static func prochain_match(model: Dictionary) -> Dictionary:
	if model.get("next") is Dictionary and not (model.next as Dictionary).is_empty(): return model.next
	var own: Variant = model.get("club", {}).get("id")
	var week := int(_nombre(model.get("meta", {}).get("week"), 0))
	var best := {}
	for fixture: Variant in model.get("calendar", []) if model.get("calendar") is Array else []:
		if not fixture is Dictionary or fixture.get("played", false): continue
		if fixture.get("home", {}).get("id") != own and fixture.get("away", {}).get("id") != own: continue
		if int(_nombre(fixture.get("week"), 0)) < week: continue
		if best.is_empty() or int(_nombre(fixture.get("week"), 0)) < int(_nombre(best.get("week"), 0)): best = fixture
	return best

static func _unix(date: String) -> float:
	if date.length() < 10: return -1.0
	var day := date.substr(0, 10)
	var parts := day.split("-")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int(): return -1.0
	return float(Time.get_unix_time_from_datetime_string(day + "T12:00:00"))

## Jours entre aujourd'hui (calendrier du jeu) et la rencontre ; -1 si inconnu.
static func jours_avant(model: Dictionary, fixture: Dictionary) -> int:
	var meta: Dictionary = model.get("meta", {}) if model.get("meta") is Dictionary else {}
	var today := str(meta.get("calendarToday", model.get("calendarPlanning", {}).get("today", "") if model.get("calendarPlanning") is Dictionary else ""))
	var a := _unix(today)
	var b := _unix(str(fixture.get("date", "")))
	if a < 0 or b < 0: return -1
	return maxi(0, roundi((b - a) / 86400.0))

static func _adversaire(model: Dictionary, fixture: Dictionary) -> String:
	var own: Variant = model.get("club", {}).get("id")
	var home: Dictionary = fixture.get("home", {}) if fixture.get("home") is Dictionary else {}
	var away: Dictionary = fixture.get("away", {}) if fixture.get("away") is Dictionary else {}
	if home.get("id") == own: return G.club_name(away)
	if away.get("id") == own: return G.club_name(home)
	return ""

static func _jour(fixture: Dictionary) -> String:
	var unix := _unix(str(fixture.get("date", "")))
	if unix < 0: return ""
	var dict := Time.get_datetime_dict_from_unix_time(int(unix))
	return "%s %02d/%02d" % [JOURS[int(dict.weekday)], int(dict.day), int(dict.month)]

static func _ligne_match(model: Dictionary, fixture: Dictionary, jours: int) -> Dictionary:
	var ligne := {"cle": "match", "libelle": "PROCHAIN MATCH", "icone": "calendar", "couleur": OR}
	var adversaire := _adversaire(model, fixture)
	if fixture.is_empty() or adversaire.is_empty():
		ligne.texte = "Rien au calendrier pour l'instant. Profites-en pour régler les dossiers qui traînent."
		return ligne
	var lieu: String = {"home": "à la maison", "away": "chez eux", "neutral": "sur terrain neutre"}.get(P.fixture_location_kind(fixture, model.club.get("id")), "")
	var quand := _jour(fixture)
	var qui := adversaire + (" " + lieu if not lieu.is_empty() else "")
	if jours == 0: ligne.texte = "C'est aujourd'hui : %s. Vérifie la feuille, et laisse-les respirer." % qui
	elif jours == 1: ligne.texte = "Demain, %s. Séance légère, et tout le monde au lit tôt." % qui
	elif jours > 1 and jours <= 7: ligne.texte = "%s, %s : dans %d jours. Cette semaine compte." % [quand.capitalize(), qui, jours]
	elif jours > 7: ligne.texte = "%s, %s : dans %d jours. On a le temps de bien construire." % [quand.capitalize(), qui, jours]
	else: ligne.texte = "Prochain rendez-vous : %s." % qui
	return ligne

static func _ligne_groupe(model: Dictionary) -> Dictionary:
	var ligne := {"cle": "groupe", "libelle": "LE GROUPE", "icone": "people", "couleur": MENTHE}
	var groupe := P.group(model)
	var dispo := int(_nombre(groupe.get("available"), 0))
	var blesses := int(_nombre(groupe.get("injured"), 0))
	var condition := int(_nombre(groupe.get("condition"), 0))
	var moral := int(_nombre(model.get("meta", {}).get("morale"), -1))
	var faits := "%d disponibles, %d blessé%s, %d %% de condition" % [dispo, blesses, "s" if blesses > 1 else "", condition]
	if moral >= 0: faits += ", moral à %d" % moral
	var avis := "Rien d'inquiétant."
	if condition < 80: avis = "Ça tire dans les jambes : allège."; ligne.couleur = AMBRE
	elif moral >= 0 and moral < 50: avis = "Le moral est bas : un mot à chacun."; ligne.couleur = AMBRE
	elif blesses >= 3: avis = "L'infirmerie se remplit."; ligne.couleur = AMBRE
	elif condition >= 90 and (moral < 0 or moral >= 70): avis = "Le groupe est frais."
	ligne.texte = faits + ". " + avis
	return ligne

static func _expirants(model: Dictionary) -> int:
	var season := int(_nombre(model.get("meta", {}).get("season"), 1))
	var count := 0
	for person: Variant in Avis.squad(model):
		if person is Dictionary and person.get("contractEnd") != null and int(_nombre(person.contractEnd, 99)) <= season: count += 1
	return count

static func _fatigues(model: Dictionary) -> int:
	var count := 0
	for person: Variant in Avis.squad(model):
		if person is Dictionary and not Avis.blesse(person) and Avis.condition(person) < 75: count += 1
	return count

static func _feuille_a_faire(model: Dictionary, jours: int) -> bool:
	var selection: Variant = model.get("selection")
	return selection is Dictionary and not selection.get("valid", false) and jours >= 0 and jours <= 2

## L'alerte la plus importante, dans l'ordre : argent, résultats, confiance, infirmerie, feuille, contrats, fatigue.
static func _ligne_alerte(model: Dictionary, fixture: Dictionary, jours: int) -> Dictionary:
	var ligne := {"cle": "alerte", "libelle": "L'ALERTE", "icone": "warning", "couleur": ROUGE}
	var cash := _nombre(model.get("finance", {}).get("cash") if model.get("finance") is Dictionary else null, _nombre(model.get("club", {}).get("cash"), 0.0))
	var serie := Avis.serie(model)
	var trust := _nombre(model.get("meta", {}).get("trust"), 100.0)
	var blesses := int(_nombre(P.group(model).get("injured"), 0))
	if cash < 0:
		ligne.texte = "On est dans le rouge : %s de trésorerie. Plus un euro sans regarder les comptes." % G.salary_amount(cash)
	elif serie.get("issue") == "defaite" and int(serie.nombre) >= 3:
		ligne.texte = "%d défaites d'affilée. Il faut couper la série, même avec un match moche." % int(serie.nombre)
	elif trust < 45:
		ligne.texte = "La confiance du conseil est à %d sur 100. Ne promets rien, montre-leur un groupe qui se bat." % int(trust)
	elif blesses >= 3:
		ligne.texte = "%d blessés. Ne tire pas sur ceux qui restent." % blesses
		ligne.couleur = AMBRE
	elif _feuille_a_faire(model, jours) and not fixture.is_empty():
		ligne.texte = "La feuille de match n'est pas complète."
		ligne.couleur = AMBRE
	elif not fixture.is_empty() and not Avis.fatigue_donnees(model).is_empty():
		var titulaires := int(_nombre(Avis.fatigue_donnees(model).get("count"), 0))
		ligne.texte = "%d titulaire%s de la feuille sous 70 %% de condition. Il faut les faire souffler." % [titulaires, "s" if titulaires > 1 else ""]
		ligne.couleur = AMBRE
	elif _expirants(model) >= 5:
		ligne.texte = "%d contrats s'arrêtent en fin de saison. Il faudra trancher avant l'hiver." % _expirants(model)
		ligne.couleur = AMBRE
	elif _fatigues(model) >= 3:
		ligne.texte = "%d joueurs sous 75 %% de condition." % _fatigues(model)
		ligne.couleur = AMBRE
	else:
		ligne.texte = "Rien qui brûle cette semaine. C'est rare, savoure."
		ligne.couleur = MENTHE
	return ligne

static func _ecran(route: String, texte: String, categorie: String, ton: String, detail: String) -> Dictionary:
	return {"texte": texte, "categorie": categorie, "ton": ton, "action": {"type": "ecran", "route": route, "libelle": "Suivre le conseil", "detail": detail}}

## Le conseil de la semaine, toujours avec une action : un changement de composition le jour du match,
## sinon l'écran où agir (finances, composition, recrutement, effectif, entraînement, préparation).
static func conseil(model: Dictionary, fixture: Dictionary, jours: int) -> Dictionary:
	# Titulaires de la feuille sous 70 % de condition : le conseil le plus actionnable, avec « Suivre le conseil ».
	var fatigue := Avis.fatigue(model)
	if not fixture.is_empty() and not fatigue.is_empty():
		return fatigue.merged({"texte": _fatigue_courte(model, fatigue)}, true) if not fatigue.get("action", {}).is_empty() else fatigue
	if Avis._jour_de_match(model):
		var compo := Avis.composition(model)
		if not compo.get("action", {}).is_empty(): return compo.merged({"texte": _composition_courte(model, compo.action)}, true)
	var cash := _nombre(model.get("finance", {}).get("cash") if model.get("finance") is Dictionary else null, 0.0)
	if cash < 0:
		return _ecran("Finances", "Va voir les comptes avant de signer qui que ce soit : on redresse, puis on repeint.", "mise_en_garde", Avis.NEGATIF, "Ouvrir les finances")
	if _feuille_a_faire(model, jours) and not fixture.is_empty():
		return _ecran("Composition", "Fais ta feuille de match, je regarderai derrière toi : deux yeux valent mieux qu'un.", "consigne", Avis.NEUTRE, "Ouvrir la composition")
	var data: Dictionary = model.get("decisions", {}).get("recruitment", {}) if model.get("decisions") is Dictionary and model.decisions.get("recruitment") is Dictionary else {}
	var urgent: Array = (data.get("needs", []) if data.get("needs") is Array else []).filter(func(need: Variant) -> bool: return need is Dictionary and need.get("need", false))
	if not urgent.is_empty() and int(_nombre(data.get("places"), 0)) > 0:
		return _ecran("Recrutement", "Le vrai trou, c'est au poste de %s. Ouvre le recrutement, et dis-moi qui tu regardes." % str(urgent[0].get("pos", "?")).to_lower(), "mise_en_garde", Avis.NEUTRE, "Ouvrir le recrutement")
	var lourds := 0
	for person: Variant in Avis.squad(model):
		if person is Dictionary and not Avis.blesse(person) and _nombre(person.get("physicalLoad")) >= 70: lourds += 1
	if lourds >= 3 or _fatigues(model) >= 3:
		return _ecran("Entraînement", "Allège l'entraînement cette semaine : un pilier cuit ne pousse plus.", "mise_en_garde", Avis.NEUTRE, "Ouvrir l'entraînement")
	if _expirants(model) >= 5:
		return _ecran("Effectif", "Commence par prolonger ceux qui portent le maillot, pas ceux qui portent les beaux discours.", "consigne", Avis.NEUTRE, "Ouvrir l'effectif")
	if fixture.is_empty():
		return _ecran("Club", "Pas de match en vue : passe voir le club, les installations et le staff.", "consigne", Avis.NEUTRE, "Ouvrir le club")
	return _ecran("Préparation", "Prépare le prochain match dans l'ordre : l'effectif, la composition, puis le plan de jeu.", "consigne", Avis.POSITIF, "Ouvrir la préparation")

## Version courte du conseil de fatigue pour le carnet (le détail reste dans la bulle de Gabi).
static func _fatigue_courte(model: Dictionary, avis: Dictionary) -> String:
	var parts := PackedStringArray()
	for change: Variant in avis.get("action", {}).get("changements", []):
		if not change is Dictionary: continue
		var sortant := Avis.joueur(model, str(change.get("sortant", "")))
		var entrant := Avis.joueur(model, str(change.get("playerId", "")))
		parts.append("%s (%d %%) pour %s" % [Avis._nom(entrant), int(Avis.condition(entrant)), Avis._nom(sortant)])
	if parts.size() > 2: return "Je ferais souffler %d titulaires fatigués : %s et %d autre%s." % [parts.size(), ", ".join(parts.slice(0, 2)), parts.size() - 2, "s" if parts.size() > 3 else ""]
	return "Je ferais souffler les fatigués : %s." % " ; ".join(parts)

## Version courte du conseil de composition pour le carnet (le détail reste dans « Ton avis, Gabi ? »).
static func _composition_courte(model: Dictionary, action: Dictionary) -> String:
	var parts := PackedStringArray()
	for change: Variant in action.get("changements", []):
		if not change is Dictionary: continue
		var entrant := Avis._nom(Avis.joueur(model, str(change.get("playerId", ""))))
		var sortant := Avis._nom(Avis.joueur(model, str(change.get("sortant", ""))))
		var poste := ""
		for assignment: Variant in model.get("selection", {}).get("slots", []) if model.get("selection") is Dictionary else []:
			if assignment is Dictionary and int(_nombre(assignment.get("slot"), -1)) == int(_nombre(change.get("slot"), -2)): poste = str(assignment.get("label", "")).to_lower()
		var morceau := entrant + (" à la place " + _de(sortant) if not sortant.is_empty() else "")
		if not poste.is_empty(): morceau += " (" + poste + ")"
		parts.append(morceau)
	if parts.is_empty(): return "Je changerais la feuille avant le match."
	return "Pour le match, je changerais %s : %s. Les gars sont plus frais." % ["une chose" if parts.size() == 1 else "deux choses", " ; ".join(parts)]

## « de Smart », « d'Amos » (élision devant une voyelle).
static func _de(nom: String) -> String:
	return ("d'" if not nom.is_empty() and nom.left(1).to_upper() in ["A", "E", "I", "O", "U", "Y", "É", "È", "Ê", "Â", "Î", "Ô"] else "de ") + nom
