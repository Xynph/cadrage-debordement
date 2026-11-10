extends RefCounted
## Stable IDs are persisted separately from the career. Only UI navigation is offered.
const TOUR := ["bienvenue", "club", "bureau", "effectif", "composition", "entrainement", "tactique", "premier-match", "resultat", "calendrier", "classements", "finances", "recrutement", "territoire", "packs"]
const CONTEXT_PAGES := ["bienvenue", "club", "bureau", "effectif", "composition", "entrainement", "tactique", "premier-match", "resultat", "calendrier", "classements", "finances", "recrutement", "territoire", "packs", "staff", "formation", "plan-jeu", "vestiaire", "centre", "presse", "rivalites", "travail-club", "strategie", "carriere"]
const PAGES := {
	"bienvenue": ["Accueil","Gaston, dit Gabi","J'étais menuisier, avant. Puis j'ai passé ma vie au bord des terrains. Les deux métiers se ressemblent : quand ça tient de travers, inutile de repeindre. J'ai passé la main, c'est toi le coach. Je te montre la maison, puis je te laisse faire. Si je remets les chaises droites, laisse : ça me démange."],
	"club": ["Création","Un club à faire grandir","Choisir un club, c'est choisir les gens avec qui on va vivre la saison. Regarde la division et l'objectif avant de prendre les rênes. Choisis un club dont tu as envie de connaître les gens. Les trophées, ça viendra peut-être. Le bonjour au gardien, ça commence demain matin."],
	"bureau": ["Bureau","On fait le point","Pose ton carnet. On prépare la semaine avant qu'elle nous tombe dessus. J'ai longtemps fait l'inverse ; ça explique quelques cheveux blancs. Un dossier à la fois. Quand j'avais l'atelier, ceux qui couraient partout étaient rarement ceux qui terminaient une armoire droite."],
	"effectif": ["Effectif","Des hommes, pas seulement des notes","Avant de parler de tactique, connais ton groupe. Poste, condition, disponibilité : commence par là, puis ouvre une fiche. Un bon joueur fatigué reste un joueur fatigué. Va aussi voir ceux qui jouent moins. Quand tu auras besoin d'eux un soir de pluie, ils se souviendront si tu connaissais leur prénom."],
	"composition": ["Composition","Chacun à sa place","Choisis des joueurs autorisés à tenir leur poste. Et prépare les remplaçants aussi sérieusement que les titulaires. Un banc, ce n'est pas une salle d'attente. Vérifie toute la feuille avant de partir. Pendant le match, les changements se feront dans l'onglet Banc, en pause. Et le dernier mot reste le tien."],
	"entrainement": ["Préparation","Travailler juste","Faire transpirer tout le monde, c'est facile. Faire progresser le groupe sans le mettre à plat, voilà le métier. Récupération, normal ou intensif : choisis pour les jambes que tu as aujourd'hui. Une séance de trop, c'est rarement l'entraîneur qui la paie avec ses genoux. Prépare-la avant le coup d'envoi, avec le prochain match en tête."],
	"tactique": ["Préparation","Un plan qu'on comprend","Un plan, il faut pouvoir l'expliquer simplement. Lis le dossier adverse, puis choisis ton attaque et ta défense. Le conseil du staff donne des raisons, pas une recette miracle. Moi, j'ai longtemps voulu tout régler devant. J'ai eu tort, parfois. Regarde ce que tes joueurs savent faire avant de défendre tes habitudes."],
	"premier-match": ["Match","Allez, on y est","La feuille, les consignes, le banc. C'est bon ? Alors on y va. J'ai beau avoir arrêté, juste avant le coup d'envoi, j'ai encore les mains moites. Direct pour suivre, Banc pour changer, Stats pour faire le point. Mets en pause pour décider tranquillement. Moi, je me tais. Profites-en."],
	"resultat": ["Match","Le match après le match","Le résultat est là. Gagné ou perdu, on prend le temps de comprendre. Regarde la conquête, la discipline et la réussite au but, puis les moments du match. La victoire ne rend pas tout juste, la défaite ne rend pas tout mauvais. Choisis deux choses à travailler. Pour les vingt autres, on a encore lundi."],
	"calendrier": ["Calendrier","Garder un peu de réserve","Une saison, c'est long. Regarde ce qui vient avant de demander encore un effort aux mêmes joueurs. Ici, tu retrouves les résultats et les rencontres à jouer. Les grands soirs se préparent les semaines ordinaires. Garde du monde frais. J'ai appris ça une demi-finale trop tard ; ça, je l'ai encore en travers."],
	"classements": ["Classements","Les pieds sur terre","Le classement, on le regarde en face. Points, matchs joués, différence : vérifie tout avant de comparer. Si ça sourit, garde les pieds au sol. Si ça tourne mal, garde la tête levée. Les gars te regardent encore plus quand le classement fait mal. Continue à construire."],
	"finances": ["Finances","La maison doit tenir","Dans mon premier club, on comptait jusqu'aux ampoules du vestiaire. Ici aussi, regarde les moyens avant de promettre. La prime part à la signature, les salaires reviennent chaque semaine. Une recrue doit trouver sa place sur le terrain et dans les comptes. Le journal dit où passe l'argent. Lis-le avant de promettre la lune. Chez nous, même les ampoules du vestiaire ont quelqu'un qui les paie."],
	"packs": ["Packs","À chacun son carnet","Je reconnais un club à son accueil avant de regarder son blason. Les maillots changent, les gens restent. Pense à eux quand tu prends une décision. Mon vieux carnet a changé trois fois de couverture. Les noms qu'il y a dedans comptent davantage. Et les bons souvenirs sentent encore le vestiaire mouillé."],
	"recrutement": ["Recrutement","Le bon renfort, au bon endroit","Avant de chercher un grand nom, cherche ce qui manque à ton équipe. Regarde la couverture des postes et les fins de contrat. Une piste te plaît ? Lis le salaire, la durée et le coût avant de proposer. Une contre-offre, ça se discute ; une promesse, ça se tient. Et une proposition n'est pas encore une signature."],
	"territoire": ["Club","On joue pour quelque part","Regarde un peu autour de nous. Un club, c'est une ville, un stade et des gens qui reviennent, même sous la pluie. J'ai connu un bénévole qui mettait les protections des poteaux avant chaque match. Trente ans. Jamais sur la photo avec la coupe. Ces gens-là, tu les oublies pas."]
}
static func fragments(id: String) -> Array:
	var content = JSON.parse_string(FileAccess.get_file_as_string("res://guide/dialogues.json"))
	if content is Dictionary:
		for page in content.get("pages", []):
			if page.id == id: return page.fragments.filter(func(item): return not item.get("contextOnly", false))
	return [{"id":id + "-01", "text":str(PAGES.get(id, PAGES.bienvenue)[2])}]

static func fragment(id: String) -> Dictionary:
	var content = JSON.parse_string(FileAccess.get_file_as_string("res://guide/dialogues.json"))
	if content is Dictionary:
		for item in content.get("pages", []):
			for part in item.fragments:
				if part.id == id: return part
	return {}

static func page(id: String) -> Array:
	if PAGES.has(id): return PAGES[id]
	var content = JSON.parse_string(FileAccess.get_file_as_string("res://guide/dialogues.json"))
	if content is Dictionary:
		for item in content.get("pages", []):
			if item.id == id: return [item.route, item.title, item.text]
	return PAGES.bienvenue

static func for_route(route: String, model: Dictionary) -> String:
	if route == "Staff": return "staff"
	if route == "Formation": return "formation"
	if route == "Match":
		var live: Dictionary = model.get("live", {}) if model.get("live") is Dictionary else {}
		return "resultat" if live.get("finished", false) else "premier-match"
	for id in PAGES:
		if PAGES[id][0] == route: return id
	var content = JSON.parse_string(FileAccess.get_file_as_string("res://guide/dialogues.json"))
	if content is Dictionary:
		for item in content.get("pages", []):
			if item.route == route: return item.id
	return ""
