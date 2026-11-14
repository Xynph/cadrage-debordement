extends RefCounted
## « Ton avis, Gabi ? » : l'avis de Gaston Darroux, l'adjoint de confiance, sur l'écran affiché.
## Tout vient du modèle projeté par le moteur (ce que le manager voit) : jamais d'information cachée.
## Les joueurs du marché non observés n'ont ni note ni attributs dans le modèle (couche connaissance) ;
## Gabi le dit au lieu de deviner. Déterministe : mêmes données, même avis (la variante de phrase dépend
## de la semaine, pour ne pas radoter d'une semaine à l'autre).
## Ton : bienveillant, franc, imagé, un brin têtu sur la conquête, prudent avec les jeunes. 1 à 3 phrases.

const G = preload("res://ui/game_skin.gd")
const Knowledge = preload("res://ui/player_knowledge_text.gd")

const POSITIF := "positif"
const NEUTRE := "neutre"
const NEGATIF := "negatif"
## Écart minimal (points de note au poste, forme et fraîcheur comprises) pour proposer un changement.
const SEUIL_CHANGEMENT := 4.0
## Un jeune (20 ans ou moins) ne remplace un titulaire que pour un écart nettement plus grand.
const SEUIL_JEUNE := 8.0
const AGE_JEUNE := 20
const CHANGEMENTS_MAX := 2

## Écran principal (clé d'avis) d'une route du jeu.
static func ecran(route: String, model: Dictionary = {}) -> String:
	match route:
		"Réception": return "reception"
		"Bureau": return "bureau"
		"Effectif", "Vestiaire": return "effectif"
		"Composition", "Plan de jeu", "Match": return "composition"
		"Préparation": return "entrainement"
		"Recrutement": return "recrutement"
		"Club", "Staff", "Travail du club", "Stratégie": return "club"
		"Finances": return "finances"
		"Classements", "Calendrier", "Rivalités": return "competitions"
		"Formation", "Centre", "Suivi des jeunes": return "formation"
	return ""

## Avis sur l'écran : {texte, categorie (gabi_moments), ton, action (facultative)}.
## `focus` : identifiant d'un joueur du marché ouvert à l'écran Recrutement (dossier affiché).
static func avis(route: String, model: Dictionary, focus: String = "") -> Dictionary:
	if not model.get("club") is Dictionary: return {}
	match ecran(route, model):
		"reception": return _reception(model)
		"bureau": return _bureau(model)
		"effectif": return _effectif(model)
		"composition": return composition(model)
		"entrainement": return _entrainement(model)
		"recrutement":
			var cible := marche(model, focus)
			return recrutement(model, cible) if not cible.is_empty() else _besoins(model)
		"club": return _club(model)
		"finances": return _finances(model)
		"competitions": return _competitions(model)
		"formation": return _formation(model)
	return {}

# --- Lecture du modèle -------------------------------------------------------------------------------

static func _nombre(value: Variant, defaut: float = 0.0) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else defaut

static func _semaine(model: Dictionary) -> int:
	return int(_nombre(model.get("meta", {}).get("week", 0)))

static func _variante(model: Dictionary, choix: Array) -> String:
	return str(choix[posmod(_semaine(model), choix.size())])

static func _nom(joueur: Dictionary) -> String:
	var complet := str(joueur.get("name", "")).strip_edges()
	var morceaux := complet.split(" ", false)
	if morceaux.size() < 2: return complet
	var famille := " ".join(morceaux.slice(1))
	return famille.capitalize() if famille == famille.to_upper() else famille

static func _virgule(value: float) -> String:
	return ("%.1f" % value).replace(".", ",")

static func squad(model: Dictionary) -> Array:
	return model.get("squad", []) if model.get("squad") is Array else []

static func joueur(model: Dictionary, id: String) -> Dictionary:
	for person: Variant in squad(model):
		if person is Dictionary and str(person.get("id", "")) == id: return person
	return {}

static func marche(model: Dictionary, id: String) -> Dictionary:
	if id.is_empty(): return {}
	for person: Variant in model.get("market", []) if model.get("market") is Array else []:
		if person is Dictionary and str(person.get("id", "")) == id: return person
	return {}

## Notes de match enregistrées (dernières d'abord) pour un joueur du club.
static func notes(model: Dictionary, id: String) -> Array:
	var fiche: Variant = model.get("clubLife", {}).get("matchNotes", {}).get("joueurs", {}).get(id)
	if not fiche is Dictionary: return []
	var forme: Array = fiche.get("forme", []) if fiche.get("forme") is Array else []
	return forme.filter(func(v: Variant) -> bool: return v is int or v is float)

static func forme(model: Dictionary, id: String) -> Variant:
	var recentes := notes(model, id)
	if recentes.is_empty(): return null
	var dernieres := recentes.slice(maxi(0, recentes.size() - 3))
	var total := 0.0
	for value: Variant in dernieres: total += float(value)
	return total / dernieres.size()

static func condition(joueur_: Dictionary) -> float:
	return _nombre(joueur_.get("condition"), 100.0)

static func blesse(joueur_: Dictionary) -> bool:
	return _nombre(joueur_.get("injury")) > 0

## Dernier résultat du club : {issue: victoire|defaite|nul, pour, contre, adversaire, semaine}.
static func dernier_resultat(model: Dictionary) -> Dictionary:
	var club_id := str(model.get("club", {}).get("id", ""))
	var history: Array = model.get("history", []) if model.get("history") is Array else []
	for index in range(history.size() - 1, -1, -1):
		var match_: Variant = history[index]
		if not match_ is Dictionary or not match_.get("pair") is Array or not match_.get("score") is Array: continue
		var pair: Array = match_.pair
		var score: Array = match_.score
		if pair.size() != 2 or score.size() != 2: continue
		var side := 0 if str(pair[0]) == club_id else (1 if str(pair[1]) == club_id else -1)
		if side < 0: continue
		var ours := _nombre(score[side])
		var theirs := _nombre(score[1 - side])
		return {"issue": "victoire" if ours > theirs else ("defaite" if ours < theirs else "nul"), "pour": int(ours), "contre": int(theirs), "adversaire": _club_nom(model, pair[1 - side]), "semaine": int(_nombre(match_.get("week"), -1)), "saison": int(_nombre(match_.get("season"), -1))}
	return {}

## Série en cours du club (« victoire » ou « defaite »), en nombre de matchs.
static func serie(model: Dictionary) -> Dictionary:
	var club_id := str(model.get("club", {}).get("id", ""))
	var history: Array = model.get("history", []) if model.get("history") is Array else []
	var kind := ""
	var count := 0
	for index in range(history.size() - 1, -1, -1):
		var match_: Variant = history[index]
		if not match_ is Dictionary or not match_.get("pair") is Array or not match_.get("score") is Array: continue
		var pair: Array = match_.pair
		var side := 0 if str(pair[0]) == club_id else (1 if pair.size() > 1 and str(pair[1]) == club_id else -1)
		if side < 0: continue
		var score: Array = match_.score
		var issue := "victoire" if _nombre(score[side]) > _nombre(score[1 - side]) else ("defaite" if _nombre(score[side]) < _nombre(score[1 - side]) else "nul")
		if kind.is_empty(): kind = issue
		if issue != kind: break
		count += 1
	return {"issue": kind, "nombre": count}

static func _club_nom(model: Dictionary, id: Variant) -> String:
	for club: Variant in model.get("league", []) if model.get("league") is Array else []:
		if club is Dictionary and str(club.get("id", "")) == str(id): return G.club_name(club)
	var next: Variant = model.get("next")
	if next is Dictionary:
		for side in ["home", "away"]:
			var club: Variant = next.get(side)
			if club is Dictionary and str(club.get("id", "")) == str(id): return G.club_name(club)
	return "l'adversaire"

static func adversaire(model: Dictionary) -> String:
	var next: Variant = model.get("next")
	if not next is Dictionary: return ""
	var own := str(model.get("club", {}).get("id", ""))
	for side in ["home", "away"]:
		var club: Variant = next.get(side)
		if club is Dictionary and str(club.get("id", "")) != own: return G.club_name(club)
	return ""

static func _jour_de_match(model: Dictionary) -> bool:
	var cadence: Variant = model.get("meta", {}).get("calendarCadence")
	return model.get("next") is Dictionary and (not cadence is Dictionary or cadence.get("matchReady", false))

static func _marge(model: Dictionary) -> float:
	var finance: Variant = model.get("clubLife", {}).get("clubStrategy", {}).get("finance")
	if finance is Dictionary and finance.has("weeklyIncome"):
		return _nombre(finance.weeklyIncome) - _nombre(finance.get("weeklyCosts", finance.get("weeklyWages", 0)))
	return 0.0

static func _resultat(texte: String, categorie: String, ton: String, action: Dictionary = {}) -> Dictionary:
	return {"texte": texte, "categorie": categorie, "ton": ton, "action": action}

# --- Écrans -------------------------------------------------------------------------------------------

static func _reception(model: Dictionary) -> Dictionary:
	var dernier := dernier_resultat(model)
	var messages: Array = model.get("messages", []) if model.get("messages") is Array else []
	var count := messages.size()
	if not dernier.is_empty() and dernier.issue == "defaite":
		return _resultat("Le courrier ne rattrape pas un %d-%d. Lis ce qui concerne le groupe d'abord, la presse attendra : elle sait déjà ce qu'elle va écrire." % [dernier.pour, dernier.contre], "mauvaise_nouvelle", NEGATIF)
	if not dernier.is_empty() and dernier.issue == "victoire":
		return _resultat("Une victoire, ça remplit la boîte aux lettres. Profites-en, mais garde un œil sur les messages du staff : c'est là que se cachent les vrais soucis.", "bonne_nouvelle", POSITIF)
	return _resultat(_variante(model, [
		"%d message%s qui t'attendent. Trie comme à l'atelier : ce qui touche les joueurs avant ce qui touche les papiers." % [count, "s" if count > 1 else ""],
		"Rien d'urgent ne crie plus fort que le reste ici. Commence par le staff, finis par les partenaires.",
	]), "consigne", NEUTRE)

static func _bureau(model: Dictionary) -> Dictionary:
	var trust := _nombre(model.get("meta", {}).get("trust"), -1.0)
	var morale := _nombre(model.get("meta", {}).get("morale"), -1.0)
	var serie_ := serie(model)
	var opponent := adversaire(model)
	if serie_.get("issue") == "defaite" and int(serie_.nombre) >= 3:
		return _resultat("%d défaites d'affilée. On ne repeint pas une armoire bancale : reviens aux bases, la mêlée et la touche, et le reste suivra." % serie_.nombre, "mauvaise_nouvelle", NEGATIF)
	if trust >= 0 and trust < 45:
		return _resultat("La confiance des dirigeants est à %d sur 100. Ne promets rien cette semaine : montre-leur un groupe qui se bat." % int(trust), "mise_en_garde", NEGATIF)
	if not opponent.is_empty() and _jour_de_match(model):
		return _resultat("C'est jour de match contre %s. Vérifie la feuille, la fraîcheur des avants, et laisse les gars respirer." % opponent, "consigne", NEUTRE)
	if not opponent.is_empty():
		var texte := "Prochain rendez-vous : %s. " % opponent
		texte += "Le moral est haut (%d), ne le gaspille pas en séances de trop." % int(morale) if morale >= 75 else ("Le moral est bas (%d) : une séance légère et un mot à chacun, ça vaut mieux qu'un discours." % int(morale) if morale >= 0 and morale < 50 else "Prépare-le dans l'ordre : l'effectif, la composition, puis le plan de jeu.")
		return _resultat(texte, "consigne", POSITIF if morale >= 75 else NEUTRE)
	return _resultat("Pas de match à l'horizon immédiat. C'est le moment de régler les dossiers qui traînent : contrats, staff, jeunes.", "consigne", NEUTRE)

static func _effectif(model: Dictionary) -> Dictionary:
	var injured: Array = []
	var tired: Array = []
	var expiring: Array = []
	var best := {}
	var best_form := -1.0
	for person: Variant in squad(model):
		if not person is Dictionary: continue
		if blesse(person): injured.append(person)
		elif condition(person) < 75: tired.append(person)
		if int(_nombre(person.get("contractEnd"), 9)) <= 1: expiring.append(person)
		var f: Variant = forme(model, str(person.get("id", "")))
		if f != null and float(f) > best_form: best_form = float(f); best = person
	tired.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return condition(a) < condition(b))
	if injured.size() >= 3:
		return _resultat("%d blessés dans le groupe. Ne tire pas sur ceux qui restent : à force d'user les mêmes, on finit en demi-finale avec des fantômes." % injured.size(), "mauvaise_nouvelle", NEGATIF)
	if not tired.is_empty():
		var tired_player: Dictionary = tired[0]
		var texte := "%s est à %d %% de condition" % [_nom(tired_player), int(condition(tired_player))]
		texte += " et il n'est pas le seul (%d sous 75 %%). " % tired.size() if tired.size() > 1 else ". "
		texte += "Allège sa charge, ou il te lâchera au mauvais moment."
		return _resultat(texte, "mise_en_garde", NEUTRE)
	if expiring.size() >= 5:
		return _resultat("%d contrats s'arrêtent à la fin de la saison. Prolonge ceux qui portent le maillot, pas ceux qui portent les beaux discours." % expiring.size(), "mise_en_garde", NEUTRE)
	if not best.is_empty() and best_form >= 7.5:
		return _resultat("%s tourne à %s de moyenne sur ses derniers matchs. Dis-le-lui : un compliment au bon moment, ça vaut une semaine d'entraînement." % [_nom(best), _virgule(best_form)], "bonne_nouvelle", POSITIF)
	return _resultat("Le groupe est sain, personne ne tire la langue. Profite du calme pour regarder qui pousse derrière les titulaires.", "approbation", POSITIF)

static func _entrainement(model: Dictionary) -> Dictionary:
	var heavy := 0
	var low := 0
	for person: Variant in squad(model):
		if not person is Dictionary or blesse(person): continue
		if _nombre(person.get("physicalLoad")) >= 70: heavy += 1
		if condition(person) < 80: low += 1
	if heavy >= 3:
		return _resultat("%d joueurs sont dans le rouge côté charge. Une séance de conquête courte, sans plaquages, et tout le monde au bain froid." % heavy, "mise_en_garde", NEUTRE)
	if _jour_de_match(model):
		return _resultat("Veille ou jour de match : pas de charge. On répète les lancements de touche à vide, on rentre tôt.", "consigne", NEUTRE)
	if low >= 4:
		return _resultat("%d joueurs sous 80 %% de condition. Tu peux travailler, mais la conquête d'abord et le physique léger : un pilier cuit ne pousse plus." % low, "mise_en_garde", NEUTRE)
	return _resultat(_variante(model, [
		"Les organismes vont bien. Mets de la mêlée cette semaine : on n'a jamais perdu un match pour avoir trop poussé à l'entraînement.",
		"Le groupe est frais. Une bonne séance de touche, les sauteurs et les lanceurs ensemble : c'est là qu'on gagne les ballons qui comptent.",
	]), "consigne", POSITIF)

static func _besoins(model: Dictionary) -> Dictionary:
	var data: Dictionary = model.get("decisions", {}).get("recruitment", {}) if model.get("decisions", {}).get("recruitment") is Dictionary else {}
	var places := int(_nombre(data.get("places"), 0))
	var needs: Array = data.get("needs", []) if data.get("needs") is Array else []
	var urgent: Array = needs.filter(func(need: Variant) -> bool: return need is Dictionary and need.get("need", false))
	if places <= 0:
		return _resultat("L'effectif est plein. Avant d'acheter, il faut libérer une place : on ne rentre pas une armoire dans une pièce déjà meublée.", "mise_en_garde", NEUTRE)
	if not urgent.is_empty():
		var need: Dictionary = urgent[0]
		return _resultat("Le vrai trou, c'est au poste de %s. Ouvre un dossier et dis-moi qui tu regardes : j'ai mon avis." % str(need.get("pos", "?")).to_lower(), "mise_en_garde", NEUTRE)
	if not needs.is_empty():
		var first: Dictionary = needs[0]
		return _resultat("Rien d'urgent, %d place%s libre%s. Si tu dois renforcer, regarde au poste de %s : %s." % [places, "s" if places > 1 else "", "s" if places > 1 else "", str(first.get("pos", "?")).to_lower(), str((first.get("reasons", ["la relève"]) as Array)[0]) if first.get("reasons") is Array and not (first.reasons as Array).is_empty() else "la relève"], "consigne", NEUTRE)
	return _resultat("Choisis un dossier dans la liste et demande-moi. Je ne juge pas un joueur sur sa photo.", "question", NEUTRE)

static func _club(model: Dictionary) -> Dictionary:
	var strategy: Dictionary = model.get("clubLife", {}).get("clubStrategy", {}) if model.get("clubLife", {}).get("clubStrategy") is Dictionary else {}
	var board: Dictionary = strategy.get("board", {}) if strategy.get("board") is Dictionary else {}
	var facility: Dictionary = strategy.get("finance", {}).get("facility", {}) if strategy.get("finance") is Dictionary else {}
	var risks: Array = board.get("risks", []) if board.get("risks") is Array else []
	if not risks.is_empty():
		return _resultat("Le conseil s'inquiète. Va les voir avant qu'ils viennent te chercher : un président rassuré, c'est une semaine de gagnée.", "mise_en_garde", NEGATIF)
	if facility.get("affordable", false) and not facility.get("atMaximum", true) and not facility.get("used", false):
		return _resultat("Les installations peuvent passer au niveau %d, et on en a les moyens. Un vestiaire où l'eau chaude tient, ça se voit sur le terrain en février." % int(_nombre(facility.get("nextLevel"), 0)), "consigne", POSITIF)
	return _resultat("La maison tient debout. Pense aux bénévoles : ceux qui posent les protections des poteaux ne sont jamais sur la photo.", "souvenir", NEUTRE)

static func _finances(model: Dictionary) -> Dictionary:
	var cash := _nombre(model.get("finance", {}).get("cash"), _nombre(model.get("club", {}).get("cash")))
	var marge := _marge(model)
	if cash < 0:
		return _resultat("On est dans le rouge. Plus un euro sur un joueur tant que les comptes ne sont pas remis d'aplomb : redresse avant de repeindre.", "mauvaise_nouvelle", NEGATIF)
	if marge < 0:
		return _resultat("Chaque semaine coûte %s de plus qu'elle ne rapporte. Ça tient tant qu'il y a de la trésorerie, mais une saison, c'est long." % G.salary_amount(-marge), "mise_en_garde", NEUTRE)
	if marge > 0 and marge < 20000:
		return _resultat("La marge est mince : %s par semaine. Un gros salaire de plus et on passe dans le rouge, fais attention." % G.salary_amount(marge), "mise_en_garde", NEUTRE)
	return _resultat("Les comptes sont sains : %s de trésorerie. Garde une poire pour la soif, les blessures arrivent toujours en hiver." % G.salary_amount(cash), "approbation", POSITIF)

static func _competitions(model: Dictionary) -> Dictionary:
	var club: Dictionary = model.club
	if not club.get("standingsOpen", true):
		return _resultat("Pas encore de classement : personne n'a joué. Le premier match dira qui a bien préparé l'été.", "consigne", NEUTRE)
	var rank := int(_nombre(club.get("rank"), 0))
	var teams: int = (model.get("league", []) as Array).size() if model.get("league") is Array else 0
	if rank <= 0 or teams <= 0: return _resultat("Regarde l'écart avec les quatre premiers plutôt que ta place : en début de saison, la place ment.", "consigne", NEUTRE)
	if rank <= 2:
		return _resultat("%de sur %d. C'est bien, mais ne lis pas le classement tous les matins : ça rend sourd aux vrais problèmes." % [rank, teams] if rank > 1 else "Premiers. Savoure ce soir, et demain on regarde ce qui n'a pas marché : il y a toujours quelque chose.", "bonne_nouvelle", POSITIF)
	if rank > teams - 2:
		return _resultat("%de sur %d, on est dans la zone dangereuse. Les matchs à domicile, il faut les prendre tous, même moches." % [rank, teams], "mise_en_garde", NEGATIF)
	return _resultat("%de sur %d. Le peloton est serré : deux victoires et on change de monde, deux défaites aussi." % [rank, teams], "consigne", NEUTRE)

static func _formation(model: Dictionary) -> Dictionary:
	var follow: Dictionary = model.get("clubLife", {}).get("academyFollowUp", {}) if model.get("clubLife", {}).get("academyFollowUp") is Dictionary else {}
	var summary: Dictionary = follow.get("summary", {}) if follow.get("summary") is Dictionary else {}
	var cracks := int(_nombre(summary.get("cracks"), 0))
	var ending := int(_nombre(summary.get("ending"), 0))
	var injured := int(_nombre(summary.get("injured"), 0))
	if cracks > 0:
		var pronom := "les" if cracks > 1 else "la"
		return _resultat("On a %d pépite%s. Sécurise-%s par un contrat, mais ne %s jette pas en pro trop tôt : j'en ai brûlé un comme ça, je m'en veux encore." % [cracks, "s" if cracks > 1 else "", pronom, pronom], "regret", NEUTRE)
	if ending > 0:
		return _resultat("%d jeune%s arrive%s en fin de parcours. Décide pour chacun, et dis-le-leur en face : ils s'en souviendront toute leur vie." % [ending, "s" if ending > 1 else "", "nt" if ending > 1 else ""], "mise_en_garde", NEUTRE)
	if injured > 0:
		return _resultat("%d blessé%s chez les jeunes. À cet âge, on ne revient jamais trop tard." % [injured, "s" if injured > 1 else ""], "mise_en_garde", NEUTRE)
	return _resultat("Le centre tourne. Les gamins progressent en jouant, pas en regardant : laisse-les à leur niveau, ils viendront.", "consigne", NEUTRE)

# --- Composition ---------------------------------------------------------------------------------------

static func _note_poste(person: Dictionary, numero: int) -> float:
	var ratings: Variant = person.get("positionRatings")
	if ratings is Dictionary:
		var value: Variant = ratings.get(str(numero), ratings.get(numero))
		if value is int or value is float: return float(value)
	return _nombre(person.get("rating"), 0.0)

## Valeur d'un joueur à un poste pour le prochain match : note au poste, forme récente (notes de match),
## fraîcheur. Uniquement des données du club (connues du manager).
static func valeur(model: Dictionary, person: Dictionary, numero: int) -> float:
	var value := _note_poste(person, numero)
	var f: Variant = forme(model, str(person.get("id", "")))
	if f != null: value += (float(f) - 6.5) * 2.5
	var c := condition(person)
	if c < 90: value -= (90.0 - c) * 0.45
	return value

## Conseil de composition : {texte, categorie, ton, action {type: "composition", changements: [{slot, playerId, sort}]}}.
static func composition(model: Dictionary) -> Dictionary:
	var selection: Dictionary = model.get("selection", {}) if model.get("selection") is Dictionary else {}
	var slots: Array = selection.get("slots", []) if selection.get("slots") is Array else []
	if slots.is_empty(): return _resultat("Pas de feuille de match à regarder pour l'instant. Reviens me voir quand le prochain match approche.", "consigne", NEUTRE)
	var starters := {}
	for assignment: Variant in slots:
		if assignment is Dictionary and int(_nombre(assignment.get("slot"), 99)) < 15 and assignment.get("playerId") is String:
			starters[str(assignment.playerId)] = true
	var proposals: Array = []
	var vacant := 0
	for assignment: Variant in slots:
		if not assignment is Dictionary: continue
		var index := int(_nombre(assignment.get("slot"), 99))
		if index >= 15: continue
		var numero := int(_nombre(assignment.get("positionNumber"), index + 1))
		var current := joueur(model, str(assignment.get("playerId", ""))) if assignment.get("playerId") is String else {}
		if current.is_empty(): vacant += 1
		var current_value := valeur(model, current, numero) if not current.is_empty() else -INF
		var best := {}
		var best_gain := 0.0
		for candidate_id: Variant in assignment.get("eligibleIds", []) if assignment.get("eligibleIds") is Array else []:
			if starters.has(str(candidate_id)): continue
			var candidate := joueur(model, str(candidate_id))
			if candidate.is_empty() or blesse(candidate) or condition(candidate) < 80: continue
			var gain := valeur(model, candidate, numero) - current_value
			var needed := SEUIL_JEUNE if int(_nombre(candidate.get("age"), 30)) <= AGE_JEUNE else SEUIL_CHANGEMENT
			if gain >= needed and gain > best_gain: best_gain = gain; best = candidate
		if not best.is_empty():
			proposals.append({"slot": index, "numero": numero, "label": str(assignment.get("label", "")), "entrant": best, "sortant": current, "gain": best_gain})
	proposals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.gain > b.gain if a.gain != b.gain else a.slot < b.slot)
	var chosen: Array = []
	var used := {}
	for proposal: Dictionary in proposals:
		if used.has(str(proposal.entrant.id)): continue
		used[str(proposal.entrant.id)] = true
		chosen.append(proposal)
		if chosen.size() == CHANGEMENTS_MAX: break
	if chosen.is_empty():
		return _composition_validee(model, vacant)
	var phrases := PackedStringArray()
	for proposal: Dictionary in chosen:
		phrases.append(_argument(model, proposal))
	var texte := " ".join(phrases)
	texte += " Je ferais %s." % ("ce changement" if chosen.size() == 1 else "ces deux changements")
	var changes: Array = []
	for proposal: Dictionary in chosen:
		changes.append({"slot": proposal.slot, "playerId": str(proposal.entrant.id), "sortant": str(proposal.sortant.get("id", ""))})
	return _resultat(texte, "mise_en_garde", NEUTRE, {"type": "composition", "changements": changes, "libelle": "Suivre le conseil"})

## Alerte de fatigue : des titulaires de la feuille du prochain match sont sous 70 % de condition.
## Le moteur (selection.fatigue, position-aptitudes.cjs) propose pour chacun le meilleur remplaçant frais au
## poste, règle JIFF et admissibilité comprises ; Gabi le dit et « Suivre le conseil » les fait souffler
## (mêmes commandes set_lineup que le conseil de composition). Vide : aucune alerte.
const FATIGUE_CHANGEMENTS_MAX := 6

static func fatigue_donnees(model: Dictionary) -> Dictionary:
	var selection: Variant = model.get("selection")
	var data: Variant = selection.get("fatigue") if selection is Dictionary else null
	if not data is Dictionary or not data.get("starters") is Array or (data.starters as Array).is_empty(): return {}
	return data

static func _poste_du_slot(model: Dictionary, slot: int) -> String:
	for assignment: Variant in model.get("selection", {}).get("slots", []) if model.get("selection") is Dictionary else []:
		if assignment is Dictionary and int(_nombre(assignment.get("slot"), -1)) == slot: return str(assignment.get("label", "")).to_lower()
	return ""

static func _liste(noms: Array) -> String:
	if noms.size() <= 1: return "".join(noms)
	return ", ".join(noms.slice(0, noms.size() - 1)) + " et " + str(noms[noms.size() - 1])

static func fatigue(model: Dictionary) -> Dictionary:
	var data := fatigue_donnees(model)
	if data.is_empty(): return {}
	var seuil := int(_nombre(data.get("threshold"), 70))
	var changes: Array = []
	for change: Variant in data.get("changes", []) if data.get("changes") is Array else []:
		if change is Dictionary and change.get("playerId") is String and change.get("sortant") is String and changes.size() < FATIGUE_CHANGEMENTS_MAX:
			changes.append(change)
	var fatigues: Array = []
	for starter: Variant in data.starters:
		if starter is Dictionary: fatigues.append(starter)
	var noms: Array = []
	for starter: Dictionary in fatigues.slice(0, 3):
		noms.append("%s (%d %%)" % [_nom(joueur(model, str(starter.get("playerId", "")))), int(_nombre(starter.get("condition"), 0))])
	var reste := fatigues.size() - noms.size()
	var qui := _liste(noms) + (" et %d autre%s" % [reste, "s" if reste > 1 else ""] if reste > 0 else "")
	if changes.is_empty():
		return _resultat("%s %s sous les %d %% de condition, et je n'ai personne de frais au poste : prévois de %s sortir tôt." % [qui, "est" if fatigues.size() == 1 else "sont", seuil, "le" if fatigues.size() == 1 else "les"], "mise_en_garde", NEUTRE)
	var phrases := PackedStringArray()
	var entrants: Array = []
	for change: Dictionary in changes:
		var entrant := _nom(joueur(model, str(change.playerId)))
		var poste := _poste_du_slot(model, int(_nombre(change.get("slot"), -1)))
		phrases.append("%s%s" % [entrant, " en " + poste if not poste.is_empty() else ""])
		entrants.append(entrant)
	var texte := ""
	if fatigues.size() == 1 and changes.size() == 1:
		var change: Dictionary = changes[0]
		texte = "%s est à %d %% de condition : je le ferais souffler. %s est frais (%d %%) et vaut %d à ce poste." % [_nom(joueur(model, str(change.sortant))), int(_nombre(change.get("condition"), 0)), entrants[0], int(_nombre(change.get("entrantCondition"), 0)), int(_nombre(change.get("rating"), 0))]
	else:
		texte = "%s %s sous les %d %% de condition. Je les ferais souffler et je mettrais à leur place : %s." % [qui, "est" if fatigues.size() == 1 else "sont", seuil, _liste(Array(phrases))]
	if changes.size() < fatigues.size():
		texte += " Pour les autres, je n'ai personne de frais au poste."
	return _resultat(texte, "mise_en_garde", NEUTRE, {"type": "composition", "changements": changes.map(func(c: Dictionary) -> Dictionary: return {"slot": int(c.slot), "playerId": str(c.playerId), "sortant": str(c.sortant)}), "libelle": "Suivre le conseil", "detail": "Fait souffler les titulaires fatigués (tu peux toujours remettre la feuille comme avant)"})

static func _argument(model: Dictionary, proposal: Dictionary) -> String:
	var entrant: Dictionary = proposal.entrant
	var sortant: Dictionary = proposal.sortant
	var poste := str(proposal.label).to_lower() if not str(proposal.label).is_empty() else "ce poste"
	var raisons := PackedStringArray()
	if not sortant.is_empty():
		var c := condition(sortant)
		var f: Variant = forme(model, str(sortant.get("id", "")))
		if c < 85: raisons.append("%s est à %d %% de condition" % [_nom(sortant), int(c)])
		if f != null and float(f) < 6.3: raisons.append("tourne à %s de moyenne" % _virgule(float(f)) if raisons.size() > 0 else "%s tourne à %s de moyenne" % [_nom(sortant), _virgule(float(f))])
		var note_sortant := _note_poste(sortant, int(proposal.numero))
		if note_sortant + 5 <= _note_poste(entrant, int(proposal.numero)):
			raisons.append("ne vaut que %d à ce poste" % int(roundf(note_sortant)) if raisons.size() > 0 else "%s ne vaut que %d à ce poste" % [_nom(sortant), int(roundf(note_sortant))])
		if raisons.is_empty(): raisons.append("%s fait le travail" % _nom(sortant))
	var pour := PackedStringArray()
	var fe: Variant = forme(model, str(entrant.get("id", "")))
	if fe != null and float(fe) >= 6.8: pour.append("sort d'un %s" % _virgule(float(fe)))
	pour.append("est frais (%d %%)" % int(condition(entrant)) if condition(entrant) >= 95 else "est à %d %%" % int(condition(entrant)))
	pour.append("et vaut %d au poste" % int(roundf(_note_poste(entrant, int(proposal.numero)))))
	var texte := ""
	if sortant.is_empty(): texte = "En %s, la place est vide : %s %s." % [poste, _nom(entrant), " ".join(pour) if pour.size() == 1 else ", ".join(pour.slice(0, pour.size() - 1)) + " " + pour[pour.size() - 1]]
	else: texte = "En %s, %s, mais %s %s." % [poste, " et ".join(raisons), _nom(entrant), ", ".join(pour.slice(0, pour.size() - 1)) + " " + pour[pour.size() - 1]]
	if int(proposal.numero) in [1, 2, 3, 4, 5]: texte = texte.trim_suffix(".") + " ; devant, je ne transige pas sur la conquête."
	elif int(_nombre(entrant.get("age"), 30)) <= AGE_JEUNE: texte = texte.trim_suffix(".") + " ; il est jeune, protège-le."
	return texte

static func _composition_validee(model: Dictionary, vacant: int) -> Dictionary:
	if vacant > 0:
		return _resultat("Il manque encore %d titulaire%s sur la feuille. Complète-la, ou laisse le staff proposer : je regarderai après." % [vacant, "s" if vacant > 1 else ""], "mise_en_garde", NEUTRE)
	var low := {}
	for assignment: Variant in model.get("selection", {}).get("slots", []):
		if not assignment is Dictionary or int(_nombre(assignment.get("slot"), 99)) >= 15: continue
		var person := joueur(model, str(assignment.get("playerId", "")))
		if not person.is_empty() and (low.is_empty() or condition(person) < condition(low)): low = person
	if not low.is_empty() and condition(low) < 85:
		return _resultat("Je ne vois personne de mieux sur le banc. Mais %s n'est qu'à %d %% : prévois de le sortir à l'heure de jeu." % [_nom(low), int(condition(low))], "approbation", NEUTRE)
	return _resultat(_variante(model, [
		"C'est le XV que j'aurais aligné. Devant, ça pousse ; derrière, ça court. Valide et va dormir.",
		"Rien à redire, coach. Les gars sont frais et chacun est à sa place : on n'ajoute pas un clou à une charpente qui tient.",
	]), "approbation", POSITIF)

# --- Recrutement ------------------------------------------------------------------------------------

static func _moyenne_poste(model: Dictionary, pos: String) -> Variant:
	var total := 0.0
	var count := 0
	for person: Variant in squad(model):
		if person is Dictionary and str(person.get("pos", "")) == pos and (person.get("rating") is int or person.get("rating") is float):
			total += float(person.rating); count += 1
	return total / count if count > 0 else null

## Avis sur une cible du marché, à partir de ce que le club en sait (note connue, fourchette observée,
## ou rien). {texte, categorie, ton, action {type: "recrutement", verdict: fonce|a_suivre|passe, playerId}}.
static func recrutement(model: Dictionary, cible: Dictionary) -> Dictionary:
	var id := str(cible.get("id", ""))
	var pos := str(cible.get("pos", ""))
	var nom := _nom(cible)
	var data: Dictionary = model.get("decisions", {}).get("recruitment", {}) if model.get("decisions", {}).get("recruitment") is Dictionary else {}
	var places := int(_nombre(data.get("places"), 1))
	var need := false
	for item: Variant in data.get("needs", []) if data.get("needs") is Array else []:
		if item is Dictionary and str(item.get("pos", "")) == pos and item.get("need", false): need = true
	var average: Variant = _moyenne_poste(model, pos)
	var bounds: Dictionary = Knowledge.bounds(cible, "rating")
	var level: Variant = null
	if not bounds.is_empty(): level = (float(bounds.min) + float(bounds.max)) / 2.0
	var potential: Dictionary = Knowledge.bounds(cible, "potential")
	var age := int(_nombre(cible.get("age"), 25))
	var salary := _nombre(cible.get("salary"), 0.0)
	var marge := _marge(model)
	var cash := _nombre(model.get("finance", {}).get("cash"), 0.0)
	var too_expensive := salary > 0 and ((marge > 0 and salary > marge * 0.6) or marge <= 0 or cash < 0)
	var action := {"type": "recrutement", "playerId": id}
	if not cible.get("available", true):
		action.verdict = "passe"
		return _resultat("%s n'est pas libre de discuter (%s). Passe ton chemin, il y en aura d'autres." % [nom, str(cible.get("reason", "indisponible")).to_lower().trim_suffix(".")] , "mise_en_garde", NEUTRE, action.merged({"libelle": "Passer mon chemin"}))
	if level == null:
		action.verdict = "a_suivre"
		return _resultat("Je n'ai jamais vu jouer %s : ni note, ni rapport. Mets-le dans ta liste et envoie un recruteur avant de sortir le chéquier." % nom, "question", NEUTRE, action.merged({"libelle": "Suivre le conseil"}))
	var ecart: float = float(level) - float(average) if average != null else 0.0
	var range_text := "%d" % int(bounds.min) if int(bounds.min) == int(bounds.max) else "entre %d et %d" % [int(bounds.min), int(bounds.max)]
	var young_promise := age <= 21 and not potential.is_empty() and float(potential.max) >= float(level) + 8
	if places <= 0:
		action.verdict = "passe"
		return _resultat("%s est noté %s, mais l'effectif est plein. Libère une place d'abord, sinon passe ton chemin." % [nom, range_text], "mise_en_garde", NEUTRE, action.merged({"libelle": "Passer mon chemin"}))
	if too_expensive:
		action.verdict = "passe"
		return _resultat("%s demande %s : avec une marge de %s par semaine, c'est trop lourd. Passe ton chemin, on ne finance pas un joueur avec l'argent des ampoules." % [nom, G.salary(salary), G.salary_amount(marge)], "mise_en_garde", NEGATIF, action.merged({"libelle": "Passer mon chemin"}))
	if average != null and ecart >= 3:
		action.verdict = "fonce"
		var years := clampi(int(_nombre(cible.get("maxYears"), 2)), 1, 3) if age <= 29 else clampi(int(_nombre(cible.get("minYears"), 1)), 1, 2)
		action.annees = years
		var texte := "%s est noté %s, au-dessus de notre moyenne au poste (%d). " % [nom, range_text, int(average)]
		texte += "Il comble le trou qu'on a là. " if need else ""
		texte += "Propose-lui %d an%s à %s, sans surenchérir." % [years, "s" if years > 1 else "", G.salary(salary)]
		return _resultat(texte, "approbation", POSITIF, action.merged({"libelle": "Suivre le conseil"}))
	if young_promise:
		action.verdict = "a_suivre"
		return _resultat("%s a %d ans et du potentiel (jusqu'à %d). Pas pour jouer demain : suis-le, et ne le presse pas, un jeune qu'on brûle ne repousse pas." % [nom, age, int(potential.max)], "question", NEUTRE, action.merged({"libelle": "Suivre le conseil"}))
	if need and average != null and ecart >= -2:
		action.verdict = "a_suivre"
		return _resultat("%s (%s) ferait un renfort honnête là où on manque. Garde-le dans ta liste, et cherche mieux avant de signer." % [nom, range_text], "question", NEUTRE, action.merged({"libelle": "Suivre le conseil"}))
	action.verdict = "passe"
	var comparaison := " ; notre moyenne au poste est de %d" % int(average) if average != null else ""
	return _resultat("%s est noté %s%s. Il n'apporterait rien de plus : passe ton chemin." % [nom, range_text, comparaison], "mise_en_garde", NEUTRE, action.merged({"libelle": "Passer mon chemin"}))

# --- Humeur du médaillon et moments clés ---------------------------------------------------------------

## Humeur du médaillon : ton et catégorie du dernier résultat (joie après une victoire, mine sombre après
## une défaite), et clé unique par match pour ne réagir qu'une fois.
static func humeur(model: Dictionary) -> Dictionary:
	var dernier := dernier_resultat(model)
	if dernier.is_empty(): return {"cle": "", "ton": NEUTRE, "categorie": ""}
	var cle := "resultat:%d:%d:%s" % [dernier.saison, dernier.semaine, dernier.adversaire]
	match str(dernier.issue):
		"victoire": return {"cle": cle, "ton": POSITIF, "categorie": "bonne_nouvelle"}
		"defaite": return {"cle": cle, "ton": NEGATIF, "categorie": "mauvaise_nouvelle"}
	return {"cle": cle, "ton": NEUTRE, "categorie": "souvenir"}

## Grosse crise : quatre défaites de suite, ou confiance des dirigeants sous 30.
static func crise(model: Dictionary) -> bool:
	var s := serie(model)
	return (s.get("issue") == "defaite" and int(s.nombre) >= 4) or _nombre(model.get("meta", {}).get("trust"), 100.0) < 30

## Veille ou jour de finale : le prochain match porte le mot « finale » (pas les demi-finales).
static func finale(model: Dictionary) -> bool:
	var next: Variant = model.get("next")
	if not next is Dictionary: return false
	var label := (str(next.get("label", "")) + " " + str(next.get("round", "")) + " " + str(next.get("stage", ""))).to_lower()
	return label.contains("finale") and not label.contains("demi") and not label.contains("quart")
