extends RefCounted
## Stable IDs are persisted separately from the career. Only UI navigation is offered.
const TOUR := ["bienvenue", "club", "bureau", "effectif", "composition", "entrainement", "tactique", "premier-match", "resultat", "calendrier", "classements", "finances", "recrutement", "territoire", "packs"]
const PAGES := {
	"bienvenue": ["Accueil", "Gaston, dit Gabi", "Moi, c'est Gaston Darroux. Mais appelle-moi Gabi. Quarante ans de rugby dans le Sud-Ouest : pilier, puis entraîneur. J'ai gardé les oreilles et le carnet. Ici, c'est toi qui entraînes ; moi, je t'aide à trouver tes repères. On fera les choses sérieusement, sans oublier de se régaler. Allez, bienvenue au club !"],
	"club": ["Création", "Un club à faire grandir", "Choisir un club, c'est choisir les gens avec qui on va vivre la saison. Regarde la division et l'objectif avant de prendre les rênes. La base anonymisée permet de jouer tout de suite. Et si tu remplaces une carrière, lis bien la confirmation : on ne range pas une histoire sans savoir où on la met."],
	"bureau": ["Bureau", "On fait le point", "Viens, on pose le carnet. D'abord la prochaine rencontre, puis les décisions qui attendent. Les raccourcis t'emmènent directement au bon endroit. La carrière se sauvegarde toute seule ; le menu permet aussi d'en garder une copie. Mon vieux conseil : une chose après l'autre. Le club ne se construit pas en une matinée."],
	"effectif": ["Effectif", "Des hommes, pas seulement des notes", "Avant de parler de tactique, connais ton groupe. Poste, condition, disponibilité : commence par là, puis ouvre une fiche. Un bon joueur fatigué reste un joueur fatigué. Les filtres t'aident à repérer blessés et joueurs hors groupe. Ne regarde pas seulement les quinze premiers : la saison se gagne avec tout le monde."],
	"composition": ["Composition", "Chacun à sa place", "La première ligne, j'y ai laissé quelques oreilles : on ne bricole pas ses qualifications. Choisis un poste, regarde les joueurs autorisés et prépare aussi le banc. Vérifie toute la feuille avant de partir. Pendant le match, les changements se feront dans l'onglet Banc, en pause. Et le dernier mot reste le tien."],
	"entrainement": ["Préparation", "Travailler juste", "Faire transpirer tout le monde, c'est facile. Faire progresser le groupe sans le mettre à plat, voilà le métier. Regarde la condition et la charge avant de choisir récupération, normal ou intensif. Une séance collective par semaine : une fois faite, elle est faite. Prépare-la avant le coup d'envoi, avec le prochain match en tête."],
	"tactique": ["Préparation", "Un plan qu'on comprend", "Un plan, il faut pouvoir l'expliquer simplement. Lis le dossier adverse, puis choisis ton attaque et ta défense. Le conseil du staff donne des raisons, pas une recette miracle. Regarde aussi qui peut réellement jouer. Tu pourras ajuster tes consignes en pause ; on s'adapte à ce qu'on voit, pas à ce qu'on espérait."],
	"premier-match": ["Match", "Allez, on y est", "Bon. La feuille, les consignes, un dernier regard au banc… et coup d'envoi. Direct pour suivre, Banc pour changer, Stats pour prendre du recul. Mets en pause quand tu veux décider tranquillement. Maintenant je te laisse le terrain. Je peux être bavard, mais je sais aussi me taire quand le ballon vit."],
	"resultat": ["Match", "Le match après le match", "Le résultat est là. Gagné ou perdu, on prend le temps de comprendre. Regarde la conquête, la discipline et la réussite au but, puis les moments du match. Les chiffres donnent des pistes ; ils ne prouvent pas tout. Quand tu as fait ton bilan, valide la journée. Et demain, on retourne travailler. Sans s'emballer, sans baisser la tête."],
	"calendrier": ["Calendrier", "Garder un peu de réserve", "Une saison, c'est long. Regarde ce qui vient avant de demander encore un effort aux mêmes joueurs. Ici, tu retrouves les résultats et les rencontres à jouer. Les phases finales se précisent avec la compétition. Prépare le prochain rendez-vous, mais garde un œil sur celui d'après : les jambes ont une mémoire, elles aussi."],
	"classements": ["Classements", "Les pieds sur terre", "Le classement, on le regarde en face. Points, matchs joués, différence : vérifie tout avant de comparer. Les onglets montrent les deux divisions et les archives gardent les saisons terminées. Une victoire ne fait pas de nous des champions ; une défaite ne défait pas tout le travail. Continue à construire."],
	"finances": ["Finances", "La maison doit tenir", "Dans mon premier club, on comptait jusqu'aux ampoules du vestiaire. Ici aussi, regarde les moyens avant de promettre. La prime se paie tout de suite, les salaires reviennent chaque semaine de jeu. Le journal garde les mouvements. Ces montants sont fictifs : ils servent à gérer notre projet, pas à raconter les comptes des vrais clubs."],
	"packs": ["Packs", "À chacun son carnet", "Tu peux jouer avec la base anonymisée ou importer un pack personnalisé. Lis son aperçu, installe-le, puis sélectionne-le. Les identités changent, les progrès de ta carrière restent. Si un pack manque, réimporte-le depuis cette page. Le rugby reste le même ; chacun met ses couleurs sur le carnet."],
	"recrutement": ["Recrutement", "Le bon renfort, au bon endroit", "Avant de chercher un grand nom, cherche ce qui manque à ton équipe. Regarde la couverture des postes et les fins de contrat. Une piste te plaît ? Lis le salaire, la durée et le coût avant de proposer. Une contre-offre, ça se discute ; une promesse, ça se tient. Et une proposition n'est pas encore une signature."],
	"territoire": ["Club", "On joue pour quelque part", "Regarde un peu autour de nous. Un club, c'est une ville, un stade et des gens qui reviennent, même sous la pluie. Ces photos d'archive donnent un visage au territoire ; leurs crédits sont accessibles ici. Les murs ne gagnent pas les matchs, d'accord. Mais savoir pour qui on joue, ça compte."]
}
static func fragments(id: String) -> Array:
	var content = JSON.parse_string(FileAccess.get_file_as_string("res://guide/dialogues.json"))
	if content is Dictionary:
		for page in content.get("pages", []):
			if page.id == id: return page.fragments
	return [{"id":id + "-01", "text":str(PAGES.get(id, PAGES.bienvenue)[2])}]

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
	return "bienvenue"
