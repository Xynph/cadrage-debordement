extends SceneTree
## Tour des écrans filmé : capture tous les écrans de gestion du vrai jeu sans écran ni clic.
##
## Charge le vrai jeu (main.tscn) avec un profil temporaire, importe une carrière Monde
## (tools/ecrans-filmes/preparer-carriere.cjs : jour de match, une rencontre déjà jouée), puis, pour
## chaque taille demandée, ouvre chaque écran comme le ferait la navigation du jeu (app._navigate), ferme
## les bulles de Gabi, attend que l'image ne bouge plus et l'enregistre (<ecran>-<largeur>.png, voir suffixe_taille). Écrans :
## la liste ROUTES de tests/small-window-geometry.gd, puis fiche joueur, fiche d'un club adverse,
## calendrier en semaine, options, et pour finir le direct et la fenêtre Équipe (coup d'envoi donné dans
## le profil jetable). Écrit report.json (écrans réussis/échoués, débordements : contrôles hors de
## l'écran, textes probablement tronqués) et une planche par taille (planche-<largeur>.png ; hors 16:9,
## <largeur>x<hauteur> : planche-2560x1080.png, bureau-3440x1440.png).
## Point d'entrée habituel : scripts/ecrans-filmes.ps1 (bureau Windows séparé, pilote audio muet).
##
##   godot --path native/godot --audio-driver Dummy --script tools/ecrans-filmes/visite.gd -- \
##     --ecrans-filmes --sortie <dossier> --export <carriere.json> [--tailles 1920x1080,1280x720] \
##     [--ecrans reception,fiche-joueur,...] [--duree-max 900] [--sans-planche] [--sans-direct]
##
## CD_GODOT_DATA_DIR est obligatoire (profil jetable) : l'outil refuse de tourner sur le profil réel.
## Le jeu normal n'est pas touché : ce script n'est chargé qu'avec --script.

const TAILLE_MIN := Vector2i(800, 450)
const TAILLES_DEFAUT := "1920x1080,1280x720"
## Copie de ROUTES (tests/small-window-geometry.gd), utilisée si ce fichier n'est pas lisible ;
## tests/godot-ecrans-filmes.cjs vérifie que les deux listes restent identiques.
const ROUTES_GEOMETRIE := ["Réception","Bureau","Effectif","Composition","Préparation","Plan de jeu","Vestiaire","Match","Recrutement","Formation","Centre","Suivi des jeunes","Club","Staff","Travail du club","Stratégie","Finances","Calendrier","Classements","Rivalités","Carrière","Sélections","Presse","Accueil","Création","Packs"]
## Écrans hors carrière : visités après les écrans de gestion (ils ne changent rien à la carrière).
const HORS_CARRIERE := ["Accueil", "Création", "Packs"]
const EXTRAS := [
	{"id": "calendrier-semaine", "libelle": "Calendrier (semaine)", "type": "calendrier_semaine"},
	{"id": "entrainement-semaine", "libelle": "Entraînement · onglet Semaine", "type": "entrainement_onglet", "onglet": 0},
	{"id": "tactique-consignes", "libelle": "Tactique · onglet Consignes (depuis la Composition)", "type": "tactique_onglet", "onglet": 1},
	{"id": "tactique-phases", "libelle": "Tactique · onglet Phases arrêtées (depuis la Composition)", "type": "tactique_onglet", "onglet": 2},
	{"id": "tactique-entrainement", "libelle": "Tactique · onglet Entraînement (depuis la Composition)", "type": "tactique_onglet", "onglet": 4},
	{"id": "tactique-alertes", "libelle": "Tactique · pastilles Bleus et Nationale (maquette)", "type": "tactique_alertes"},
	{"id": "tactique-bleus", "libelle": "Tactique · petite fenêtre des Bleus (maquette)", "type": "tactique_alertes", "fenetre": "LineupBleusNoticeLien"},
	{"id": "tactique-nationale", "libelle": "Tactique · petite fenêtre des qualifications FFR (maquette)", "type": "tactique_alertes", "fenetre": "NationaleLicenceNoticeLien"},
	{"id": "entrainement-groupes", "libelle": "Entraînement · onglet Groupes", "type": "entrainement_onglet", "onglet": 1},
	{"id": "entrainement-mois", "libelle": "Entraînement · onglet Mois", "type": "entrainement_onglet", "onglet": 5},
	{"id": "entrainement-mois-jour", "libelle": "Entraînement · Mois · petite fenêtre d'un jour", "type": "entrainement_onglet", "onglet": 5, "jour": true},
	{"id": "salle-entrainement", "libelle": "Observer la préparation (salle d'entraînement)", "type": "salle_entrainement"},
	{"id": "salle-entrainement-joueur", "libelle": "Observer la préparation · petite fenêtre d'un joueur", "type": "salle_entrainement", "joueur": true},
	{"id": "fiche-joueur", "libelle": "Fiche joueur", "type": "joueur"},
	## Apprendre un poste (23/11/2026) : fiche du même joueur avec une cible choisie, puis la petite fenêtre des postes.
	{"id": "fiche-joueur-apprendre", "libelle": "Fiche joueur · Apprendre un poste (cible choisie)", "type": "joueur", "apprendre": true},
	{"id": "fiche-joueur-apprendre-fenetre", "libelle": "Fiche joueur · Apprendre un poste (petite fenêtre)", "type": "joueur", "apprendre": true, "ouvrir": "PlayerLearnPosition"},
	{"id": "mini-fiche", "libelle": "Mini-fiche au survol (Effectif)", "type": "mini_fiche"},
	{"id": "progression", "libelle": "Fiche joueur · progression par qualité", "type": "progression"},
	{"id": "progression-niveau", "libelle": "Fiche joueur · progression, vue Niveau", "type": "progression", "autre": true},
	{"id": "equilibre-postes", "libelle": "Équilibre par poste (infobulle Aptes)", "type": "equilibre_postes"},
	{"id": "comparateur", "libelle": "Comparateur (deux joueurs)", "type": "comparateur"},
	{"id": "radar", "libelle": "Comparateur en radar (deux joueurs du même poste)", "type": "comparateur_radar"},
	{"id": "radar-axe", "libelle": "Comparateur en radar · clic sur un axe", "type": "comparateur_radar", "axe": 6},
	{"id": "salle-conseil", "libelle": "Salle du conseil", "type": "salle_conseil"},
	{"id": "salle-conseil-fenetre", "libelle": "Salle du conseil · petite fenêtre", "type": "salle_conseil", "fenetre": true},
	{"id": "salle-conseil-match", "libelle": "Salle du conseil · fenêtre d'un match", "type": "salle_conseil", "ballon": true},
	{"id": "presse-ouverte", "libelle": "Presse : conférence avec questions ouvertes", "type": "presse_ouverte"},
	{"id": "presse-conference", "libelle": "Presse : Conférence", "type": "presse_onglet", "onglet": 1},
	{"id": "presse-historique", "libelle": "Presse : Historique", "type": "presse_onglet", "onglet": 2},
	{"id": "presse-portraits", "libelle": "Presse : Portraits", "type": "presse_onglet", "onglet": 3},
	{"id": "v2-recrutement-offre", "libelle": "Recrutement : écran Offre au joueur", "type": "recrutement_etape", "etape": "offre"},
	{"id": "v2-recrutement-confirmation", "libelle": "Recrutement : confirmation en place de l'offre", "type": "recrutement_etape", "etape": "offre_confirmation"},
	{"id": "v2-recrutement-offre-fenetre", "libelle": "Recrutement : petite fenêtre du salaire sur l'offre", "type": "recrutement_etape", "etape": "offre_fenetre"},
	{"id": "v2-recrutement-observation", "libelle": "Recrutement : confirmation en place de l'observation", "type": "recrutement_etape", "etape": "observation"},
	{"id": "fiche-club", "libelle": "Fiche d'un club adverse", "type": "club"},
	{"id": "fiche-club-rapport", "libelle": "Fiche d'un club adverse · onglet Rapport", "type": "club", "onglet": 4},
	{"id": "classements-rencontre", "libelle": "Classements · sous-page d'une rencontre", "type": "classements_page", "page": "rencontre"},
	{"id": "classements-archives", "libelle": "Classements · sous-page des archives des saisons", "type": "classements_page", "page": "archives"},
	{"id": "classements-phases", "libelle": "Classements · onglet Phases finales", "type": "classements_onglet", "onglet": "playoffs"},
	{"id": "classements-stats", "libelle": "Classements · onglet Statistiques", "type": "classements_onglet", "onglet": "stats"},
	{"id": "formation-suivi", "libelle": "Formation · sous-page Suivi des jeunes", "type": "formation_suivi"},
	{"id": "options", "libelle": "Options", "type": "options"},
	{"id": "recherche", "libelle": "Recherche (résultats de la barre haute)", "type": "recherche"},
	{"id": "creation-options", "libelle": "Création · étape 2 Carrière (options)", "type": "creation_options"},
	{"id": "avant-match-delegation", "libelle": "Avant-match · sous-page Déléguer le match", "type": "avant_delegation"},
	{"id": "avant-match-bilan", "libelle": "Avant-match · petite fenêtre de la dernière rencontre", "type": "avant_bilan"},
	{"id": "compte-rendu", "libelle": "Réception · article du dernier match (carte du compte rendu)", "type": "reception_article"},
	{"id": "preparation-bas", "libelle": "Préparation · leur XV probable (bas de page)", "type": "preparation_bas"},
	{"id": "preparation-consignes", "libelle": "Préparation · onglet Consignes", "type": "preparation_onglet", "onglet": 1},
	{"id": "preparation-conseils", "libelle": "Préparation · conseils détaillés (sous-page)", "type": "preparation_sous", "sous": "conseils"},
	{"id": "preparation-reperes", "libelle": "Préparation · tous les repères (sous-page)", "type": "preparation_sous", "sous": "reperes"},
	{"id": "preparation-adversaire", "libelle": "Préparation · rapport adverse (sous-page)", "type": "preparation_sous", "sous": "adversaire"},
	{"id": "effectif-contrats", "libelle": "Effectif · onglet Contrats", "type": "effectif_onglet", "onglet": 2},
	{"id": "contrats-prolongation", "libelle": "Effectif · Contrats · prolongation d'un joueur", "type": "effectif_onglet", "onglet": 2, "ouvrir_prefixe": "ContractRenew_"},
	{"id": "contrats-prolongation-fenetre", "libelle": "Effectif · Contrats · petite fenêtre de la prolongation", "type": "effectif_onglet", "onglet": 2, "ouvrir_prefixe": "ContractRenew_", "puis": ["ProlongationApresLien"]},
	{"id": "contrats-fenetre-echeance", "libelle": "Effectif · Contrats · petite fenêtre des échéances", "type": "effectif_onglet", "onglet": 2, "ouvrir_prefixe": "ContractReviewBar_"},
	{"id": "effectif-condition", "libelle": "Effectif · onglet Condition", "type": "effectif_onglet", "onglet": 1},
	{"id": "effectif-poste", "libelle": "Effectif · liste classée au poste 12 (clic sur le maillot du XV)", "type": "effectif_onglet", "onglet": 0, "poste_xv": 12},
	{"id": "effectif-developpement", "libelle": "Effectif · onglet Développement", "type": "effectif_onglet", "onglet": 3},
	{"id": "planificateur", "libelle": "Effectif · Planificateur", "type": "effectif_onglet", "onglet": 4},
	{"id": "planificateur-prochaine", "libelle": "Effectif · Planificateur · saison prochaine", "type": "effectif_onglet", "onglet": 4, "ouvrir": "PlanSaisonOuvrir1"},
	## Forme récente (21/11/2026) : petite fenêtre du dernier match noté d’un joueur.
	{"id": "effectif-forme-fenetre", "libelle": "Effectif · petite fenêtre d'un match de la forme récente", "type": "effectif_onglet", "onglet": 0, "ouvrir": "FormeMatch4"},
	## Bandeau des filtres et restes des listes (21/11/2026) : courbe au survol, calendrier en tableau, « Entre clubs ».
	{"id": "effectif-courbe", "libelle": "Effectif · mini-courbe au survol de la condition", "type": "effectif_onglet", "onglet": 0, "survol": "TotalTuileOuvrir_Condition"},
	{"id": "classements-calendrier", "libelle": "Classements · onglet Calendrier (tableau)", "type": "classements_onglet", "onglet": "calendar"},
	{"id": "recrutement-entre-clubs", "libelle": "Recrutement · sous-page Marché entre clubs", "type": "recrutement_sous", "page": "interclub"},
	{"id": "recrutement-entre-clubs-offre", "libelle": "Recrutement · Marché entre clubs, offre guidée par le recruteur", "type": "recrutement_sous", "page": "interclub", "offre": true},
	{"id": "recrutement-rapport-recruteur", "libelle": "Recrutement · Rapport du recruteur", "type": "recrutement_sous", "page": "recruteur"},
	{"id": "finances-tresorerie", "libelle": "Finances · onglet Trésorerie (colonne de verdict)", "type": "finances_onglet", "onglet": "cash"},
	{"id": "finances-salaires", "libelle": "Finances · onglet Salaires", "type": "finances_onglet", "onglet": "wages"},
	{"id": "finances-budget", "libelle": "Finances · onglet Budget", "type": "finances_onglet", "onglet": "budget"},
	{"id": "finances-classement", "libelle": "Finances · onglet Classement", "type": "finances_onglet", "onglet": "clubs"},
	{"id": "finances-transferts", "libelle": "Finances · onglet Transferts", "type": "finances_onglet", "onglet": "transfers"},
	{"id": "strategie-finances", "libelle": "Club › Direction · onglet Finances", "type": "strategie_onglet", "onglet": 0},
	{"id": "strategie-projet", "libelle": "Club › Direction · onglet Projet sportif", "type": "strategie_onglet", "onglet": 1},
	{"id": "strategie-supporters", "libelle": "Club › Direction · onglet Supporters", "type": "strategie_onglet", "onglet": 2},
	{"id": "strategie-public", "libelle": "Club › Direction · petite fenêtre Le public", "type": "strategie_onglet", "onglet": 2, "zone": "DirectionLien_Sentiment"},
	{"id": "club-infrastructures", "libelle": "Club · onglet Infrastructures", "type": "onglet_cle", "route": "Club", "cle": "immersive08_club_tab", "onglet": "infrastructure", "repos": "overview"},
	{"id": "club-histoire", "libelle": "Club · onglet Histoire", "type": "onglet_cle", "route": "Club", "cle": "immersive08_club_tab", "onglet": "history", "repos": "overview"},
	## Staff par service (23/11/2026) : un poste en plus visé (même commande que le clic « + ») dans chaque service qui a un membre en surnombre.
	{"id": "staff-services-renfort", "libelle": "Staff par service · postes en plus visés", "type": "staff_services"},
	{"id": "vestiaire-entretiens", "libelle": "Vestiaire · onglet Entretiens et duos", "type": "onglet_cle", "route": "Vestiaire", "cle": "immersive08_locker_tab", "onglet": "people", "repos": "week"},
	{"id": "selections-offres", "libelle": "Sélections · onglet Offres", "type": "onglet_cle", "route": "Sélections", "cle": "international_section", "onglet": "offers", "repos": "callups"},
	{"id": "selections-disponibilites", "libelle": "Sélections · onglet Disponibilités", "type": "onglet_cle", "route": "Sélections", "cle": "international_section", "onglet": "availability", "repos": "callups"},
	{"id": "vestiaire-entretiens-duos", "libelle": "Vestiaire · Entretiens et duos, bas de la colonne (duos)", "type": "onglet_cle", "route": "Vestiaire", "cle": "immersive08_locker_tab", "onglet": "people", "repos": "week", "defiler": "RelationshipPeopleScroll"},
	{"id": "vestiaire-groupe", "libelle": "Vestiaire · petite fenêtre du groupe (portraits)", "type": "onglet_cle", "route": "Vestiaire", "cle": "immersive08_locker_tab", "onglet": "people", "repos": "week", "presser": "RelationshipAllPortraits"},
	{"id": "carriere-mobilite", "libelle": "Carrière · onglet Mobilité et recrutement", "type": "onglet_cle", "route": "Carrière", "cle": "immersive08_career_tab", "onglet": "details", "repos": "summary"},
	{"id": "vestiaire-historique", "libelle": "Vestiaire · onglet Engagements et historique", "type": "onglet_cle", "route": "Vestiaire", "cle": "immersive08_locker_tab", "onglet": "history", "repos": "week"},
	## Onglets du Centre (parcours activés) : un écran par onglet ; Parcours avec le parcours individuel du premier Espoir ouvert.
	{"id": "centre-parcours", "libelle": "Centre · onglet Parcours (parcours individuel ouvert)", "type": "centre_onglet", "onglet": "Parcours", "texte": "OUVRIR LE PARCOURS INDIVIDUEL"},
	{"id": "centre-centres", "libelle": "Centre · onglet Centres", "type": "centre_onglet", "onglet": "Centres"},
	{"id": "centre-filieres", "libelle": "Centre · onglet Filières", "type": "centre_onglet", "onglet": "Filières"},
	{"id": "centre-passerelle", "libelle": "Centre · onglet Passerelle pro", "type": "centre_onglet", "onglet": "Passerelle pro"},
	{"id": "centre-generations", "libelle": "Centre · onglet Générations", "type": "centre_onglet", "onglet": "Générations"},
	{"id": "centre-bas", "libelle": "Centre · bas de l'onglet Centre (rencontres juniors, équipe 1re, réglages)", "type": "centre_onglet", "onglet": "Centre", "defiler_visuel": "CentreCompactDefile"},
	{"id": "centre-parcours-fenetre", "libelle": "Centre · parcours individuel en petite fenêtre", "type": "centre_onglet", "onglet": "Parcours", "presser_visuel": "CentreVisuelJoueur0"},
	## Causerie d'avant-match (coup d'envoi donné : à filmer en dernier, une taille par lancement).
	{"id": "causerie", "libelle": "Vestiaire · causerie d'avant-match", "type": "causerie"},
	{"id": "causerie-reactions", "libelle": "Vestiaire · causerie, réactions des joueurs", "type": "causerie", "reactions": true},
]
## Écrans du match en direct : le coup d'envoi est donné une fois, après tous les autres écrans.
const EN_DIRECT := [
	## Entracte 2D d'un vrai match arrêté à la mi-temps (horloge Éclair, aucun temps fort : le match y va vite).
	{"id": "entracte", "libelle": "Entracte 2D (mi-temps)", "type": "direct", "entracte": true},
	{"id": "direct", "libelle": "Match en direct", "type": "direct"},
	{"id": "equipe-composition", "libelle": "Fenêtre Équipe · composition", "type": "equipe", "onglet": "composition"},
	{"id": "equipe-consignes", "libelle": "Fenêtre Équipe · consignes", "type": "equipe", "onglet": "consignes"},
	## Toujours le dernier : la fin du match est confiée à l'adjoint, puis l'après-match s'affiche (résultat à valider).
	{"id": "apres-match", "libelle": "Après-match (match joué jusqu'au bout)", "type": "apres_match"},
]
## Autres noms acceptés par --ecrans (forme normalisée par `slug`).
const ALIAS := {"transferts": ["recrutement"], "classement": ["classements"], "equipe": ["equipe-composition", "equipe-consignes"],
	"fenetre-equipe": ["equipe-composition", "equipe-consignes"], "joueur": ["fiche-joueur"], "preferences": ["options"], "reglages": ["options"], "semaine": ["calendrier-semaine"]}
const SEUIL_NOIR := 0.03
## Détails gardés par écran dans report.json (les totaux restent exacts).
const MAX_DETAILS := 40

var app: Control
var vignettes: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

# --- Logique pure (testée par tests/godot-ecrans-filmes.gd, sans rendu) ----------------------------

## Nom de fichier d'un écran : minuscules, sans accents, mots reliés par des tirets (« Plan de jeu » → plan-de-jeu).
static func slug(texte: String) -> String:
	var accents := {"à": "a", "â": "a", "ä": "a", "á": "a", "ç": "c", "é": "e", "è": "e", "ê": "e", "ë": "e", "î": "i", "ï": "i", "í": "i",
		"ô": "o", "ö": "o", "ó": "o", "ù": "u", "û": "u", "ü": "u", "ú": "u", "œ": "oe", "æ": "ae", "ÿ": "y", "ñ": "n"}
	var sortie := ""
	for c in texte.to_lower():
		var lettre: String = accents.get(c, c)
		var code := lettre.unicode_at(0)
		if lettre.length() > 1 or (code >= 97 and code <= 122) or (code >= 48 and code <= 57): sortie += lettre
		else: sortie += "-"
	while sortie.contains("--"): sortie = sortie.replace("--", "-")
	return sortie.trim_prefix("-").trim_suffix("-")

## Suffixe d'une taille : « 1920 » en 16:9, « 2560x1080 » sinon (2560 × 1440 et 2560 × 1080 ne s'écrasent pas).
static func suffixe_taille(largeur: int, hauteur: int = 0) -> String:
	if hauteur <= 0 or hauteur == roundi(largeur * 9.0 / 16.0): return str(largeur)
	return "%dx%d" % [largeur, hauteur]

static func nom_fichier(id: String, largeur: int, hauteur: int = 0) -> String:
	return "%s-%s.png" % [id, suffixe_taille(largeur, hauteur)]

static func nom_planche(largeur: int, hauteur: int = 0) -> String:
	return "planche-%s.png" % suffixe_taille(largeur, hauteur)

## ROUTES lues dans le texte de tests/small-window-geometry.gd ([] si introuvables).
static func routes_depuis_texte(texte: String) -> Array:
	var bloc := RegEx.create_from_string("const ROUTES\\s*=\\s*\\[([^\\]]*)\\]").search(texte)
	var routes: Array = []
	if bloc == null: return routes
	for nom in RegEx.create_from_string("\"([^\"]*)\"").search_all(bloc.get_string(1)): routes.append(nom.get_string(1))
	return routes

## Liste complète, dans l'ordre de visite : écrans de gestion, compléments, écrans hors carrière, direct.
static func liste_ecrans(routes: Array) -> Array:
	var liste: Array = []
	for route in routes:
		if not str(route) in HORS_CARRIERE: liste.append({"id": slug(str(route)), "libelle": str(route), "type": "route", "route": str(route)})
	for ecran: Dictionary in EXTRAS: liste.append(ecran.duplicate())
	for route in routes:
		if str(route) in HORS_CARRIERE: liste.append({"id": slug(str(route)), "libelle": str(route), "type": "route", "route": str(route)})
	for ecran: Dictionary in EN_DIRECT: liste.append(ecran.duplicate())
	return liste

## Garde les écrans demandés (identifiant, libellé ou alias ; accents et majuscules indifférents).
## Renvoie {"ecrans": [...], "inconnus": [...]} ; sans demande, toute la liste.
static func filtrer(liste: Array, demandes: Array) -> Dictionary:
	var inconnus: Array = []
	if demandes.is_empty(): return {"ecrans": liste.duplicate(), "inconnus": inconnus}
	var ids: Array = liste.map(func(e: Dictionary): return str(e.id))
	var voulus := {}
	for demande in demandes:
		var cle := slug(str(demande))
		if cle.is_empty(): continue
		var cibles: Array = ALIAS.get(cle, [cle])
		var trouve := false
		for cible in cibles:
			if cible in ids:
				voulus[cible] = true
				trouve = true
		if not trouve: inconnus.append(str(demande).strip_edges())
	return {"ecrans": liste.filter(func(e: Dictionary): return voulus.has(str(e.id))), "inconnus": inconnus}

## « 1920x1080,1280x720 » → {"tailles": [Vector2i...], "erreurs": [...]} (doublons retirés, ordre gardé).
static func lire_tailles(texte: String) -> Dictionary:
	var tailles: Array = []
	var erreurs: Array = []
	for morceau in texte.split(",", false):
		var parts := morceau.strip_edges().to_lower().split("x")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int() and int(parts[0]) >= TAILLE_MIN.x and int(parts[1]) >= TAILLE_MIN.y:
			var taille := Vector2i(int(parts[0]), int(parts[1]))
			if not taille in tailles: tailles.append(taille)
		else: erreurs.append("--tailles : « %s » n'est pas LxH, %dx%d au moins." % [morceau.strip_edges(), TAILLE_MIN.x, TAILLE_MIN.y])
	if tailles.is_empty() and erreurs.is_empty(): erreurs.append("--tailles : au moins une taille LxH.")
	return {"tailles": tailles, "erreurs": erreurs}

static func defauts() -> Dictionary:
	return {"sortie": "", "export": "", "tailles": [Vector2i(1920, 1080), Vector2i(1280, 720)], "ecrans": [], "duree_max": 900.0, "planche": true, "direct": true}

## Lit les arguments placés après « -- ». Renvoie {"options": {...}, "erreurs": [...]}.
static func lire_options(args: PackedStringArray) -> Dictionary:
	var o := defauts()
	var erreurs: Array = []
	var i := 0
	while i < args.size():
		var arg := args[i]
		var valeur := args[i + 1] if i + 1 < args.size() else ""
		i += 1
		if arg == "--ecrans-filmes": continue
		if arg == "--sans-planche":
			o.planche = false
			continue
		if arg == "--sans-direct":
			o.direct = false
			continue
		if not arg in ["--sortie", "--export", "--tailles", "--ecrans", "--duree-max"]:
			erreurs.append("Argument inconnu : " + arg)
			continue
		i += 1
		if valeur.is_empty() or valeur.begins_with("--"):
			erreurs.append(arg + " attend une valeur.")
			i -= 1
			continue
		match arg:
			"--sortie": o.sortie = valeur
			"--export": o.export = valeur
			"--tailles":
				var lu := lire_tailles(valeur)
				erreurs.append_array(lu.erreurs)
				if lu.erreurs.is_empty(): o.tailles = lu.tailles
			"--ecrans":
				var noms: Array = []
				for nom in valeur.split(",", false):
					if not nom.strip_edges().is_empty(): noms.append(nom.strip_edges())
				o.ecrans = noms
			"--duree-max":
				if valeur.is_valid_float() and float(valeur) >= 30.0: o.duree_max = float(valeur)
				else: erreurs.append("--duree-max : nombre de secondes, 30 au moins.")
	if not str(o.sortie).is_absolute_path(): erreurs.append("--sortie : dossier absolu requis.")
	if not str(o.export).is_absolute_path(): erreurs.append("--export : fichier absolu requis (carrière préparée).")
	return {"options": o, "erreurs": erreurs}

## Luminance moyenne (0 à 1) sur une grille de points : assez pour distinguer une image noire.
static func luminance(image: Image) -> float:
	if image == null or image.is_empty(): return 0.0
	var total := 0.0
	var n := 0
	var pas := Vector2i(maxi(1, image.get_width() / 48), maxi(1, image.get_height() / 27))
	for y in range(pas.y / 2, image.get_height(), pas.y):
		for x in range(pas.x / 2, image.get_width(), pas.x):
			total += image.get_pixel(x, y).get_luminance()
			n += 1
	return total / maxi(1, n)

## Planche : vignettes déjà réduites en grille, de gauche à droite puis de haut en bas.
static func planche(images: Array, colonnes: int) -> Image:
	if images.is_empty(): return null
	var premiere: Image = images[0]
	var largeur := premiere.get_width()
	var hauteur := premiere.get_height()
	var marge := 6
	var lignes := int(ceil(float(images.size()) / colonnes))
	var colonnes_utiles := mini(colonnes, images.size())
	var feuille := Image.create_empty(marge + colonnes_utiles * (largeur + marge), marge + lignes * (hauteur + marge), false, Image.FORMAT_RGB8)
	feuille.fill(Color(0.08, 0.09, 0.1))
	for k in images.size():
		var petite: Image = images[k]
		feuille.blit_rect(petite, Rect2i(Vector2i.ZERO, petite.get_size().min(Vector2i(largeur, hauteur))), Vector2i(marge + (k % colonnes) * (largeur + marge), marge + (k / colonnes) * (hauteur + marge)))
	return feuille

## Vignette de planche : copie RGB8 réduite à `largeur` pixels.
static func vignette(image: Image, largeur: int) -> Image:
	var copie := image.duplicate() as Image
	copie.convert(Image.FORMAT_RGB8)
	copie.resize(largeur, maxi(1, int(round(float(largeur) * image.get_height() / maxi(1, image.get_width())))), Image.INTERPOLATE_BILINEAR)
	return copie

## Dépassement d'un rectangle hors de `cadre` : [gauche, haut, droite, bas] en pixels.
static func depassement(r: Rect2, cadre: Rect2) -> Array:
	return [maxf(0, cadre.position.x - r.position.x), maxf(0, cadre.position.y - r.position.y), maxf(0, r.end.x - cadre.end.x), maxf(0, r.end.y - cadre.end.y)]

static func arrondi(r: Rect2) -> Array:
	return [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]

## Texte probablement tronqué : libellé plus large que sa place (coupé ou « … »), lignes masquées,
## bouton à texte coupé. Approximation simple (marges du style retirées) : à confirmer sur l'image.
static func texte_tronque(c: Control) -> bool:
	if c.size.x < 4.0: return false
	if c is Label:
		var l: Label = c
		var texte := l.text.to_upper() if l.uppercase else l.text
		if texte.strip_edges().is_empty(): return false
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF: return l.get_line_count() > l.get_visible_line_count()
		if not l.clip_text and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING: return false
		var police: Font = l.get_theme_font("font")
		if police == null: return false
		var style: StyleBox = l.get_theme_stylebox("normal")
		var marge := style.get_minimum_size().x if style != null else 0.0
		return police.get_multiline_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x > l.size.x - marge + 1.0
	if c is Button:
		var b: Button = c
		if b.text.strip_edges().is_empty() or b.autowrap_mode != TextServer.AUTOWRAP_OFF: return false
		if not b.clip_text and b.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING: return false
		var police: Font = b.get_theme_font("font")
		if police == null: return false
		var style: StyleBox = b.get_theme_stylebox("normal")
		var marge := style.get_minimum_size().x if style != null else 0.0
		var icone := 0.0
		if b.icon != null and not b.expand_icon: icone = b.icon.get_width() + b.get_theme_constant("h_separation")
		return police.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x + icone > b.size.x - marge + 1.0
	return false

static func utile(c: Control) -> bool:
	return not c is ScrollBar and (c is BaseButton or c is LineEdit or c is TextEdit or c is Label or c is RichTextLabel or c is Range)

# --- Tour dans le vrai jeu ------------------------------------------------------------------------

func echouer(message: String, code := 2) -> void:
	printerr("ECRANS_FILMES erreur : " + message)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	quit(code)

func profil() -> String:
	var dossier := OS.get_environment("CD_GODOT_DATA_DIR")
	# Même normalisation que native/engine/worker.cjs.
	if dossier.replace("\\", "/").trim_suffix("/").get_file() != "PrototypeGodot": dossier = dossier.path_join("PrototypeGodot")
	return dossier

func couper_le_son() -> void:
	for bus in AudioServer.bus_count: AudioServer.set_bus_mute(bus, true)

## ROUTES de tests/small-window-geometry.gd lues dans le dépôt, sinon la copie de ce script.
func routes_geometrie() -> Dictionary:
	var chemin := ProjectSettings.globalize_path("res://").path_join("../../tests/small-window-geometry.gd").simplify_path()
	if FileAccess.file_exists(chemin):
		var routes := routes_depuis_texte(FileAccess.get_file_as_string(chemin))
		if not routes.is_empty(): return {"routes": routes, "source": "tests/small-window-geometry.gd"}
	return {"routes": ROUTES_GEOMETRIE.duplicate(), "source": "copie de visite.gd"}

## Laisse l'écran se construire : un court délai, quelques images, puis la fin de toute commande en cours.
func stabiliser() -> void:
	await create_timer(0.15).timeout
	for k in 8: await process_frame
	var limite := Time.get_ticks_msec() + 20000
	while app.waiting and Time.get_ticks_msec() < limite: await process_frame

## Ferme la bulle et le grand mode de Gabi (aide, visite) : ils masqueraient l'écran.
func fermer_aide() -> void:
	var coach: Variant = app.get("coach")
	if not is_instance_valid(coach): return
	if coach.has_method("fermer_bulle"): coach.fermer_bulle()
	if coach.get("expanded") == true and coach.has_method("close"): coach.close()

## Ferme les fenêtres (dialogues) restées ouvertes par l'écran précédent.
func fermer_fenetres() -> void:
	var fenetres: Array = []
	for parent: Node in [app, root]:
		for enfant in parent.get_children():
			if enfant is Window and enfant != root and (enfant as Window).visible: fenetres.append(enfant)
	for fenetre: Window in fenetres:
		fenetre.hide()
		if fenetre is AcceptDialog and fenetre != app.file_dialog: fenetre.queue_free()

func appliquer_taille(taille: Vector2i) -> Dictionary:
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# Sans bordure : la zone de rendu fait exactement la taille demandée, même égale à celle de l'écran.
	root.borderless = true
	root.size = taille
	DisplayServer.window_set_size(taille)
	await create_timer(0.3).timeout
	await stabiliser()
	var fenetre := DisplayServer.window_get_size()
	var rendu := Vector2i(root.get_texture().get_size())
	return {"demandee": [taille.x, taille.y], "fenetre": [fenetre.x, fenetre.y], "rendu": [rendu.x, rendu.y], "conforme": rendu == taille}

## Image de l'écran une fois stable : deux images identiques à 0,25 s d'écart (8 essais au plus ; les écrans
## animés, comme le direct, gardent la dernière image avec « stable » faux).
func image_stable() -> Dictionary:
	var precedente: Image = null
	for essai in 8:
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if image != null and precedente != null and image.get_size() == precedente.get_size() and image.get_data() == precedente.get_data():
			return {"image": image, "stable": true, "essais": essai + 1}
		if image != null: precedente = image
		await create_timer(0.25).timeout
	return {"image": precedente, "stable": false, "essais": 8}

func chemin(noeud: Node) -> String:
	return str(app.get_path_to(noeud)) if app.is_ancestor_of(noeud) else str(noeud.get_path())

## Débordements de l'écran affiché : contrôles hors de l'écran (hors zone de défilement) et fenêtres
## qui dépassent ; textes probablement tronqués.
func analyser() -> Dictionary:
	var resultat := {"debordements": [], "textes_tronques": [], "nombre_debordements": 0, "nombre_textes_tronques": 0}
	parcourir(root, Rect2(Vector2.ZERO, Vector2(root.size)), Vector2.ZERO, false, resultat)
	return resultat

func parcourir(noeud: Node, vue: Rect2, decalage: Vector2, dans_defilement: bool, resultat: Dictionary) -> void:
	if noeud is Node3D: return
	if noeud is Viewport and noeud != root:
		if not noeud is Window: return
		var fenetre: Window = noeud
		if not fenetre.visible: return
		decalage = Vector2(fenetre.position)
		var cadre := Rect2(decalage, Vector2(fenetre.size))
		if depassement(cadre, vue).max() > 1.5:
			resultat.nombre_debordements += 1
			if resultat.debordements.size() < MAX_DETAILS: resultat.debordements.append({"chemin": chemin(fenetre), "fenetre": true, "rect": arrondi(cadre), "depassement": depassement(cadre, vue)})
	if noeud is CanvasLayer and not (noeud as CanvasLayer).visible: return
	if noeud is Control and not (noeud as Control).is_visible_in_tree(): return
	# Sous un défilement ou un contrôle qui rogne son contenu (bandeau défilant de Gabi…), un enfant qui
	# dépasse est coupé net : seul le cadre lui-même compte comme débordement.
	var defile := dans_defilement or noeud is ScrollContainer or (noeud is Control and (noeud as Control).clip_contents)
	if noeud is Control and utile(noeud):
		var c: Control = noeud
		var r := Rect2(c.get_global_rect().position + decalage, c.get_global_rect().size)
		if not dans_defilement and r.size.x > 0.5 and r.size.y > 0.5 and depassement(r, vue).max() > 1.5:
			resultat.nombre_debordements += 1
			if resultat.debordements.size() < MAX_DETAILS: resultat.debordements.append({"chemin": chemin(c), "type": c.get_class(), "rect": arrondi(r), "depassement": depassement(r, vue)})
		if vue.intersects(r) and texte_tronque(c):
			resultat.nombre_textes_tronques += 1
			if resultat.textes_tronques.size() < MAX_DETAILS: resultat.textes_tronques.append({"chemin": chemin(c), "texte": str(c.get("text")).left(80), "rect": arrondi(r)})
	for enfant in noeud.get_children(): parcourir(enfant, vue, decalage, defile, resultat)

func ident(valeur: Variant) -> String:
	if valeur is int or valeur is float: return str(int(valeur))
	return str(valeur) if valeur != null else ""

## Un club adverse : l'adversaire du prochain match, sinon le premier club du catalogue.
func club_adverse() -> String:
	var club: Variant = app.model.get("club")
	var propre := ident(club.get("id")) if club is Dictionary else ""
	var prochain: Variant = app.model.get("next")
	if prochain is Dictionary:
		for cote in ["home", "away"]:
			var equipe: Variant = prochain.get(cote)
			if equipe is Dictionary and not ident(equipe.get("id")).is_empty() and ident(equipe.get("id")) != propre: return ident(equipe.get("id"))
	for entree in app.catalogue:
		if entree is Dictionary and not ident(entree.get("id")).is_empty() and ident(entree.get("id")) != propre: return ident(entree.get("id"))
	return ""

## La Presse ne s'ouvre que depuis un courrier (main._navigate) : la conférence de la semaine si elle
## existe, sinon le courrier du club comme origine (ui/club_mail.gd).
func preparer_presse() -> void:
	var conference: Dictionary = app.model.get("clubLife", {}).get("press", {}).get("conference", {})
	if conference.get("available", false) and conference.get("invitationId") is String:
		app.set_meta("press_mail_origin", conference.invitationId)
		app.management_ui.press_tab = 1
	elif not app.has_meta("press_mail_origin"): app.set_meta("press_mail_origin", "courrier-club")

## Ouvre un écran hors direct. Renvoie {"statut": ok|redirige|indisponible|echec, "route", "note"}.
func ouvrir(ecran: Dictionary) -> Dictionary:
	fermer_fenetres()
	await retirer_maquette_tactique()
	# Bulle de survol montrée par programme pour l'écran précédent : rangée avant l'écran suivant.
	load("res://ui/bulle_survol.gd").cacher(app)
	# La salle d'entraînement couvre tout l'écran : refermée avant l'écran suivant.
	if bool(app.contextual_director.get("training_open")) and str(ecran.type) != "salle_entrainement":
		app.contextual_director.close_training()
		await stabiliser()
	match str(ecran.type):
		"route":
			var route := str(ecran.route)
			if route == "Presse": preparer_presse()
			app._navigate(route)
			await stabiliser()
			# CD_FILM_COURRIER_REPONSES=1 : la Réception s'ouvre sur un courrier du club qui attend une réponse (cartes A/B/C).
			if route == "Réception" and OS.get_environment("CD_FILM_COURRIER_REPONSES") == "1":
				var attend := ""
				for courrier: Dictionary in load("res://ui/club_mail.gd").mails(app.model):
					if load("res://ui/club_mail.gd").awaiting(app.model, courrier) and (courrier.get("reponses", []) as Array).size() >= 2: attend = str(courrier.id)
				if attend.is_empty(): return {"statut": "indisponible", "note": "aucun courrier à réponses dans la carrière filmée"}
				app._reset_reception(attend)
				app._navigate("Réception", false)
				await stabiliser()
			if app.route != route: return {"statut": "redirige", "note": "le jeu affiche « %s » à la place" % app.route}
		"reception_article":
			var article := ""
			for courrier: Dictionary in load("res://ui/club_mail.gd").mails(app.model):
				if str(courrier.get("type", "")) == "article": article = str(courrier.id); break
			if article.is_empty(): return {"statut": "indisponible", "note": "aucun article de match dans la carrière filmée"}
			app._reset_reception(article)
			app._navigate("Réception", false)
			await stabiliser()
			var carte_cr := app.find_child("CompteRenduCarte", true, false) as Control
			if carte_cr == null: return {"statut": "echec", "note": "carte du compte rendu absente"}
			# La carte entière à l'écran : la lecture défile jusqu'à elle (le titre du journal passe au-dessus).
			var lecture := app.find_child("InboxReadingScroll", true, false) as ScrollContainer
			if lecture != null:
				lecture.scroll_vertical = int(carte_cr.global_position.y - lecture.global_position.y) + lecture.scroll_vertical - 12
				await stabiliser()
		"tactique_onglet":
			app._navigate("Composition")
			await stabiliser()
			var onglet_tactique := app.find_child("TacticsTab%d" % int(ecran.onglet), true, false) as Button
			if onglet_tactique == null: return {"statut": "echec", "note": "onglet de la Tactique absent"}
			onglet_tactique.pressed.emit()
			await stabiliser()
		"tactique_alertes":
			# Maquette d'affichage (la carrière filmée n'a ni liste des 33 ni Nationale) : données posées sur la projection
			# seulement, le temps de la capture ; le prochain retour du moteur les efface.
			app._navigate("Composition")
			await stabiliser()
			var slots: Array = app.model.get("selection", {}).get("slots", [])
			if slots.size() < 23: return {"statut": "indisponible", "note": "feuille incomplète"}
			# Valeurs d'origine gardées : retirer_maquette_tactique() les remet avant l'écran suivant.
			if not has_meta("maquette_tactique"):
				set_meta("maquette_tactique", {"doublons": app.model.clubLife.get("doublons"), "nationale": app.model.selection.get("nationaleQualification")})
			var titulaires := [str(slots[1].get("playerId", "")), str(slots[9].get("playerId", ""))]
			app.model.clubLife["doublons"] = {"applies": true, "reposer": [{"playerId": titulaires[0]}, {"playerId": titulaires[1]}],
				"changes": [{"slot": 1, "playerId": slots[15].get("playerId"), "sortant": titulaires[0], "entrantCondition": 94}, {"slot": 9, "playerId": slots[20].get("playerId"), "sortant": titulaires[1], "entrantCondition": 88}]}
			var entrees: Array = []
			for i in 23: entrees.append({"playerId": str(slots[i].get("playerId", "")), "code": ["A", "A", "B", "A", "C", null, "A", "B"][i % 8]})
			app.model.selection["nationaleQualification"] = {"notice": {"title": "Qualifications FFR", "summary": "", "detail": "", "tone": "alert"},
				"verified": {"A": 12, "B": 6, "C": 3}, "limits": {"bc": 8, "c": 2}, "unverified": 2, "entries": entrees}
			app._render()
			await stabiliser()
			if ecran.has("fenetre"):
				var lien := app.find_child(str(ecran.fenetre), true, false) as Button
				if lien == null: return {"statut": "echec", "note": "pastille absente"}
				lien.pressed.emit()
				await stabiliser()
		"entrainement_onglet":
			# Plan d'entraînement complet (même chemin que le bouton « Plan d'entraînement » de la Tactique) : l'onglet
			# Entraînement de la Composition n'est qu'un résumé et n'ouvre pas la page complète.
			if not app.management_ui.get("immersive_training") is Dictionary: app.management_ui.immersive_training = {}
			app.management_ui.immersive_training.tab = int(ecran.onglet)
			app.Immersive.open_training(app)
			await stabiliser()
			var entrainement := app.find_child("ImmersiveTraining", true, false)
			if entrainement == null: return {"statut": "echec", "note": "entraînement non ouvert"}
			entrainement._open_tab(int(ecran.onglet))
			await stabiliser()
			if bool(ecran.get("jour", false)):
				# Jour le plus chargé du mois (le plus de créneaux) : sa petite fenêtre.
				var page := app.find_child("ImmersiveTraining", true, false)
				var choix: Button = null
				var plein := -1
				for b: Node in page.find_children("TrainingMonthDayOpen_*", "Button", true, false):
					var n: int = b.get_parent().get_child_count()
					if n > plein:
						plein = n
						choix = b
				if choix == null: return {"statut": "echec", "note": "aucun jour"}
				choix.pressed.emit()
				await stabiliser()
		"salle_entrainement":
			app._navigate("Préparation")
			await stabiliser()
			app.contextual_director.open_training()
			await stabiliser()
			var salle: Control = app.find_child("ContextualTraining", true, false)
			if salle == null: return {"statut": "echec", "note": "salle d'entraînement non ouverte"}
			if bool(ecran.get("joueur", false)):
				var visuels = load("res://ui/contextual/training_visuels.gd")
				var blesses: Array = app.model.get("squad", []).filter(func(j: Dictionary) -> bool: return int(j.get("injury", 0)) > 0)
				visuels.ouvrir_joueur(salle, blesses[0] if not blesses.is_empty() else app.model.squad[0])
				await stabiliser()
		"salle_conseil":
			if not (app.contextual_director.active() and app.contextual_director.kind == "board"):
				if not app._command("new_career", {"mode": "world-champ", "club": 102, "start": "premiers-clubs"}): return {"statut": "echec", "note": "carrière neuve refusée"}
				while app.waiting: await process_frame
				app.timer.stop()
				var muet_c := func(_ok: bool, _message: String) -> void: pass
				await load("res://qa_runner.gd").settle_club_meetings(app, self, muet_c, "board")
				app.contextual_director.sync()
				await stabiliser()
			if app.contextual_director.kind != "board": return {"statut": "indisponible", "note": "pas de rendez-vous de la direction"}
			if bool(ecran.get("fenetre", false)):
				var vue: Control = app.contextual_director.view
				var cible := vue.find_child("BoardFinance_cash", true, false) as BaseButton
				if cible != null: cible.pressed.emit()
				await stabiliser()
			if bool(ecran.get("ballon", false)):
				var frise: Node = app.contextual_director.view.find_child("BoardSeasonFrise", true, false)
				var ballons: Array = frise.ballons if frise != null else []
				if ballons.is_empty(): return {"statut": "indisponible", "note": "aucun match sur la frise"}
				(ballons[0] as BaseButton).pressed.emit()
				await stabiliser()
				var vue_m: Control = app.contextual_director.view
				if vue_m.find_child("BoardMatchWindow", true, false) == null: return {"statut": "echec", "note": "le ballon n'a pas ouvert la fenêtre du match"}
				if app.contextual_director.kind != "board": return {"statut": "echec", "note": "la réunion s'est fermée"}
		"presse_ouverte":
			# Même recette que tests/godot-presse-da.gd : carrière neuve, avance jusqu'à la conférence d'arrivée,
			# puis page Presse avec l'origine du courrier (questions ouvertes sous les yeux).
			var recette := GDScript.new()
			recette.source_code = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../../tests/helpers/contextual_flow.gd"))
			if recette.reload() != OK: return {"statut": "indisponible", "note": "recette de conférence illisible"}
			var muet := func(_ok: bool, _message: String) -> void: pass
			if not app._command("new_career", {"mode": "world-champ", "club": 102, "start": "premiers-clubs"}): return {"statut": "echec", "note": "carrière neuve refusée"}
			while app.waiting: await process_frame
			app.timer.stop()
			var ouverte: bool = await recette.reach_press_conference(app, self, muet)
			if not ouverte: return {"statut": "echec", "note": "aucune conférence ouverte atteinte"}
			var conference: Dictionary = app.model.clubLife.press.conference
			# La salle 3D prend la main si l'origine est posée avant la navigation : page d'abord, origine ensuite.
			app.management_ui.press_tab = 0
			if app.has_meta("press_mail_origin"): app.remove_meta("press_mail_origin")
			app._navigate("Presse")
			await stabiliser()
			if app.route != "Presse": return {"statut": "redirige", "note": "le jeu affiche « %s » à la place" % app.route}
			var canvas := app.find_child("CarnetPresse", true, false)
			if canvas == null: return {"statut": "echec", "note": "page Presse absente"}
			app.set_meta("press_mail_origin", conference.invitationId)
			canvas._select(1)
			await stabiliser()
		"strategie_onglet":
			app.management_ui.immersive08_strategy_tab = int(ecran.onglet)
			app._navigate("Stratégie")
			await stabiliser()
			if app.route != "Stratégie": return {"statut": "redirige", "note": "le jeu affiche « %s » à la place" % app.route}
			var onglets := app.find_child("StrategyTabs", true, false) as TabContainer
			if onglets == null or onglets.current_tab != int(ecran.onglet): return {"statut": "echec", "note": "onglet de Direction non affiché"}
			if ecran.has("zone"):
				var zone := app.find_child(str(ecran.zone), true, false) as Control
				if zone == null: return {"statut": "echec", "note": "zone %s absente" % ecran.zone}
				var clic := InputEventMouseButton.new()
				clic.button_index = MOUSE_BUTTON_LEFT
				clic.pressed = true
				zone.gui_input.emit(clic)
				await stabiliser()
		"presse_onglet":
			preparer_presse()
			app.management_ui.press_tab = int(ecran.onglet)
			app._navigate("Presse")
			await stabiliser()
			if app.route != "Presse": return {"statut": "redirige", "note": "le jeu affiche « %s » à la place" % app.route}
		"recrutement_etape":
			# Étapes du Recrutement (relecture du 20/11) : écran d'offre, confirmation en place de l'offre, de l'observation.
			app.management_ui.erase("recrutement_page")
			app._navigate("Recrutement")
			await stabiliser()
			if app.route != "Recrutement": return {"statut": "redirige", "note": "le jeu affiche « %s » à la place" % app.route}
			var liste: Node = app.find_child("CarnetMarket", true, false)
			if liste == null: return {"statut": "echec", "note": "écran Recrutement absent"}
			var etape := str(ecran.etape)
			var cible := liste.find_child("ObserveRecruitment" if etape == "observation" else "OfferRecruitment", true, false) as Button
			if cible == null or cible.disabled: return {"statut": "indisponible", "note": "action absente ou grisée pour la piste choisie"}
			cible.pressed.emit()
			await stabiliser()
			if etape == "offre_fenetre":
				var salaire := app.find_child("OffreRegleEcartZoneLien", true, false) as Button
				if salaire == null: return {"statut": "echec", "note": "chiffre du salaire absent de l'offre"}
				salaire.pressed.emit()
				await stabiliser()
				if app.find_child("OffreFenetreSalaire", true, false) == null: return {"statut": "echec", "note": "petite fenêtre du salaire non ouverte"}
			if etape == "offre_confirmation":
				var valider := app.find_child("RecrutementPageValider", true, false) as Button
				if valider == null or valider.disabled: return {"statut": "indisponible", "note": "offre non envoyable pour cette piste"}
				valider.pressed.emit()
				await stabiliser()
		"recrutement_sous":
			app.management_ui.erase("recrutement_page")
			app._navigate("Recrutement")
			await stabiliser()
			if app.route != "Recrutement": return {"statut": "redirige", "note": "le jeu affiche « %s » à la place" % app.route}
			load("res://ui/immersive08/recruitment_pages.gd").ouvrir(app, str(ecran.page))
			await stabiliser()
			await stabiliser()
			if app.find_child("RecrutementSubpage_" + str(ecran.page), true, false) == null: return {"statut": "echec", "note": "sous-page non ouverte"}
			if ecran.get("offre", false):
				# Offre guidée entre clubs : premier joueur proposable du catalogue.
				var vue: Node = null
				for fenetre: Node in app.find_children("InterclubMarket", "", true, false):
					if fenetre.has_method("_offer"): vue = fenetre
				var personne: Dictionary = {}
				for candidat: Variant in app.model.get("clubLife", {}).get("interclubMarket", {}).get("candidates", []):
					if candidat is Dictionary and candidat.get("available", false) and int(candidat.get("clause", 0)) > 0 and int(candidat.get("fee", 0)) >= 100000:
						personne = candidat
						break
				if vue == null or personne.is_empty(): return {"statut": "indisponible", "note": "aucun joueur proposable"}
				vue._offer(personne)
				await stabiliser()
				if app.find_child("InterclubGuidee", true, false) == null: return {"statut": "echec", "note": "bande du recruteur absente"}
		"classements_page":
			# Sous-pages de Classements (décision de Léo du 19/11/2026 : plus de petite fenêtre) : une rencontre du calendrier du club, les archives.
			app.management_ui.erase("competition_page")
			app._navigate("Classements")
			await stabiliser()
			var ouvrir: Button = app.find_child("OpenArchives" if str(ecran.page) == "archives" else "CalendarFixture_*", true, false) as Button
			if ouvrir == null and str(ecran.page) == "rencontre":
				var lignes := app.find_children("CalendarFixture_*", "Button", true, false)
				if not lignes.is_empty(): ouvrir = lignes[0]
			if ouvrir == null: return {"statut": "indisponible", "note": "aucune ligne de calendrier ni lien d'archives"}
			ouvrir.pressed.emit()
			await stabiliser()
			if app.find_child("CompetitionPageBack", true, false) == null: return {"statut": "echec", "note": "la sous-page ne s'est pas ouverte"}
		"classements_onglet":
			# Onglets de Classements : l'onglet est mémorisé dans l'état de l'écran, puis l'écran est rendu.
			app.management_ui.erase("competition_page")
			if not app.management_ui.get("competition") is Dictionary: app.management_ui.competition = {}
			app.management_ui.competition.tab = str(ecran.onglet)
			app._navigate("Classements")
			await stabiliser()
			if app.route != "Classements": return {"statut": "redirige", "note": "le jeu affiche « %s » à la place" % app.route}
		"formation_suivi":
			app._navigate("Formation")
			await stabiliser()
			var suivi := app.find_child("OpenYouthDevelopment", true, false) as Button
			if suivi == null or suivi.disabled: return {"statut": "indisponible", "note": "lien du suivi des jeunes absent"}
			suivi.pressed.emit()
			await stabiliser()
			if app.find_child("FormationRetour", true, false) == null: return {"statut": "echec", "note": "la sous-page ne s'est pas ouverte"}
		"staff_services":
			var services: Array = app.model.get("clubLife", {}).get("staffServices", {}).get("services", [])
			if services.is_empty(): return {"statut": "indisponible", "note": "staff par service absent"}
			for s: Dictionary in services:
				if (s.get("surnombre", []) as Array).is_empty() or int(s.get("cible", 0)) > 0: continue
				app._command("staff_services_target", {"service": str(s.id), "cible": 1})
				while app.waiting: await process_frame
			app.management_ui.erase("staff_services_vue")
			app.StaffViews.reading(app).navigation_id = ""
			app._navigate("Staff")
			await stabiliser()
			if app.find_child("StaffService_coaching", true, false) == null: return {"statut": "echec", "note": "vue par service absente"}
		"calendrier_semaine":
			app._navigate("Calendrier")
			await stabiliser()
			var mois: Node = app.find_child("CarnetCalendar", true, false)
			if mois == null or not mois.has_method("_view_as"): return {"statut": "indisponible", "note": "calendrier mensuel absent"}
			mois._view_as("week")
			await stabiliser()
		"joueur":
			var effectif: Array = app.model.get("squad", [])
			if effectif.is_empty(): return {"statut": "indisponible", "note": "effectif vide"}
			app._navigate("Effectif")
			await stabiliser()
			var ouvert: bool = app.navigation_controller.open_entity({"kind": "player", "id": ident(effectif[0].get("id"))})
			await stabiliser()
			if not ouvert or app.route != "Effectif" or not bool(app.get_meta("immersive08_full_player", false)): return {"statut": "echec", "note": "fiche joueur non ouverte"}
			if ecran.get("apprendre", false):
				# Cible d'apprentissage : premier poste hors 1re ligne qu'il peut apprendre (même commande que le clic).
				var postes: Array = load("res://ui/immersive08/fiche_roles.gd").postes_a_apprendre(effectif[0])
				var cible := 0
				for n: int in postes:
					if n > 3: cible = n; break
				if cible > 0 and int(effectif[0].get("positionLearning", 0) if effectif[0].get("positionLearning") != null else 0) != cible:
					app._command("set_position_learning", {"playerId": str(effectif[0].get("id", "")), "numero": cible})
					while app.waiting: await process_frame
					await stabiliser()
				if ecran.has("ouvrir"):
					var bouton := app.find_child(str(ecran.ouvrir), true, false) as Button
					if bouton == null: return {"statut": "echec", "note": "élément introuvable : " + str(ecran.ouvrir)}
					bouton.pressed.emit()
					await stabiliser()
		"progression":
			var effectif_p: Array = app.model.get("squad", [])
			if effectif_p.is_empty(): return {"statut": "indisponible", "note": "effectif vide"}
			var jeune: Dictionary = effectif_p[0]
			for p: Dictionary in effectif_p:
				if p.get("attributesV2") is Dictionary and int(p.get("age", 99)) < int(jeune.get("age", 99)) and int(p.get("age", 0)) >= 21: jeune = p
			app.management_ui.erase("progression")
			app.management_ui.immersive_player_tab = 4
			app._navigate("Effectif")
			await stabiliser()
			var ouvert_p: bool = app.navigation_controller.open_entity({"kind": "player", "id": ident(jeune.get("id"))})
			await stabiliser()
			if not ouvert_p: return {"statut": "echec", "note": "fiche joueur non ouverte"}
			if ecran.get("autre", false):
				var vue: Dictionary = app.management_ui.get("progression", {})
				var cible := "ProgressionVue_qualites" if str(vue.get("vue", "")) == "niveau" else "ProgressionVue_niveau"
				var pilule := app.root_content.find_child(cible, true, false) as BaseButton
				if pilule == null: return {"statut": "echec", "note": "pilule de vue absente"}
				pilule.pressed.emit()
				await stabiliser()
		"mini_fiche":
			# Le bureau séparé n'a pas de souris : la mini-fiche est affichée par programme sur le nom d'un joueur
			# (même appel que le survol, ui/immersive08/mini_fiche.gd).
			var effectif: Array = app.model.get("squad", [])
			if effectif.is_empty(): return {"statut": "indisponible", "note": "effectif vide"}
			app._navigate("Effectif")
			await stabiliser()
			var liens: Array = app.root_content.find_children("SquadOpenPlayer_*", "Button", true, false)
			if liens.is_empty(): return {"statut": "indisponible", "note": "aucun nom de joueur cliquable"}
			var lien: Button = liens[mini(3, liens.size() - 1)]
			var defilement := app.find_child("SquadScroll", true, false) as ScrollContainer
			if defilement != null: defilement.ensure_control_visible(lien)
			await stabiliser()
			var mini_fiche: Control = load("res://ui/immersive08/mini_fiche.gd").montrer(app, str(lien.get_meta("entity_id", "")), "squad", lien)
			await stabiliser()
			if mini_fiche == null or not is_instance_valid(mini_fiche): return {"statut": "echec", "note": "mini-fiche non affichée"}
		"avant_delegation":
			# Sous-page de l'avant-match (aucune fenêtre) : ouverte par le même appel que le lien « Déléguer le match ».
			app._navigate("Match")
			await stabiliser()
			var avant: Control = app.match_screen.find_child("MatchOpening", true, false) if app.match_screen != null else null
			if avant == null or not avant.is_visible_in_tree(): return {"statut": "indisponible", "note": "avant-match absent (match en cours ou aucune rencontre)"}
			avant.ouvrir_page("delegation")
			await stabiliser()
			if app.find_child("MatchDelegationPage", true, false) == null: return {"statut": "echec", "note": "sous-page de délégation non ouverte"}
		"equilibre_postes":
			app._navigate("Effectif")
			await stabiliser()
			var tuile := app.find_child("EffectifTuileAptes", true, false) as Control
			if tuile == null: return {"statut": "indisponible", "note": "tuile Aptes absente"}
			tuile.mouse_entered.emit()
			await stabiliser()
			if app.get_node_or_null("EquilibrePostes") == null: return {"statut": "echec", "note": "infobulle non affichée"}
		"comparateur":
			var effectif_cmp: Array = app.model.get("squad", [])
			if effectif_cmp.size() < 3: return {"statut": "indisponible", "note": "effectif trop court"}
			app.management_ui.compare = [ident(effectif_cmp[0].get("id")), ident(effectif_cmp[1].get("id"))]
			app._navigate("Effectif")
			await stabiliser()
			load("res://ui/immersive08/comparateur_canvas.gd").ouvrir(app)
			await stabiliser()
			if app.route != "Comparateur": return {"statut": "echec", "note": "comparateur non ouvert"}
		"comparateur_radar":
			var effectif_r: Array = app.model.get("squad", [])
			if effectif_r.size() < 2: return {"statut": "indisponible", "note": "effectif trop court"}
			var premier_r: Dictionary = effectif_r[0]
			var second_r: Dictionary = effectif_r[1]
			for p: Dictionary in effectif_r.slice(1):
				if str(p.get("pos", "")) == str(premier_r.get("pos", "")):
					second_r = p
					break
			app.management_ui.compare = [ident(premier_r.get("id")), ident(second_r.get("id"))]
			app.management_ui.erase("radar_axe")
			app._navigate("Effectif")
			await stabiliser()
			load("res://ui/immersive08/comparateur_canvas.gd").ouvrir(app)
			await stabiliser()
			if app.route != "Comparateur": return {"statut": "echec", "note": "comparateur non ouvert"}
			if ecran.has("axe"):
				var axe_r := app.root_content.find_child("RadarAxe" + str(ecran.axe), true, false) as BaseButton
				if axe_r == null: return {"statut": "echec", "note": "axe du radar absent"}
				axe_r.pressed.emit()
				await stabiliser()
		"club":
			var id := club_adverse()
			if id.is_empty(): return {"statut": "indisponible", "note": "aucun club adverse connu"}
			var ouvert: bool = app.navigation_controller.open_entity({"kind": "club", "id": id})
			await stabiliser()
			if not ouvert: return {"statut": "echec", "note": "fiche du club %s non ouverte" % id}
			if ecran.has("onglet"):
				var onglet := app.root_content.find_child("ClubSheetTab%d" % int(ecran.onglet), true, false) as BaseButton
				if onglet == null: return {"statut": "echec", "note": "onglet %d de la fiche du club absent" % int(ecran.onglet)}
				onglet.pressed.emit()
				await stabiliser()
		"preparation_bas":
			app._navigate("Préparation")
			await stabiliser()
			# Leur XV probable arrive par la lecture seule « club_sheet » : on laisse la page se reconstruire, puis on descend.
			for _i in 90: await process_frame
			await stabiliser()
			if app.body_scroll != null: app.body_scroll.scroll_vertical = int(app.body_scroll.get_v_scroll_bar().max_value)
			await stabiliser()
		"preparation_sous":
			app._navigate("Préparation")
			await stabiliser()
			app.management_ui.preparation.sub = str(ecran.sous)
			app._render()
			await stabiliser()
		"preparation_onglet":
			app._navigate("Préparation")
			await stabiliser()
			app.management_ui.preparation.tab = int(ecran.onglet)
			app.management_ui.preparation.sub = ""
			app._render()
			await stabiliser()
		"effectif_onglet":
			app.management_ui.roster.immersive_tab = int(ecran.onglet)
			# Poste choisi sur le terrain XV (même état qu'un clic sur le maillot, sans bascule d'une taille à l'autre).
			if ecran.has("poste_xv"):
				app.management_ui.roster.etoiles_poste = int(ecran.poste_xv)
				app.management_ui.roster.sort = "Note au poste"
				app.management_ui.roster.descending = true
				app.roster_sort = "Note au poste"
			app._navigate("Effectif")
			await stabiliser()
			if ecran.has("ouvrir"):
				var cible := app.find_child(str(ecran.ouvrir), true, false) as Button
				if cible == null: return {"statut": "echec", "note": "élément introuvable : " + str(ecran.ouvrir)}
				cible.pressed.emit()
				await stabiliser()
			if ecran.has("survol"):
				# Pas de souris sur le bureau séparé : la bulle du survol est montrée par programme (ui/bulle_survol.gd).
				var ancre := app.find_child(str(ecran.survol), true, false) as Control
				if ancre == null or not ancre.has_meta("bulle_fabrique"): return {"statut": "indisponible", "note": "pas de bulle sur " + str(ecran.survol)}
				load("res://ui/bulle_survol.gd").montrer(ancre)
				await stabiliser()
			if ecran.has("ouvrir_prefixe"):
				# Joueur le plus parlant : prolongation ouverte dont la demande s'écarte le plus du salaire actuel.
				var premier: Button = null
				var meilleur := -1
				for joueur: Variant in app.model.get("squad", []):
					if not joueur is Dictionary or not (joueur.get("renewal", {}) is Dictionary) or not bool(joueur.renewal.get("available", false)): continue
					var bouton := app.find_child(str(ecran.ouvrir_prefixe) + str(joueur.id).sha256_text().substr(0, 16), true, false) as Button
					if bouton == null or not bouton.is_visible_in_tree() or bouton.disabled: continue
					var ecart := absi(int(joueur.renewal.get("salary", 0)) - int(joueur.get("salary", 0)))
					if ecart > meilleur:
						meilleur = ecart
						premier = bouton
				if premier == null: return {"statut": "echec", "note": "aucun bouton " + str(ecran.ouvrir_prefixe)}
				premier.pressed.emit()
				await stabiliser()
				await stabiliser()
				for nom_suite: String in ecran.get("puis", []):
					var suite := app.find_child(nom_suite, true, false) as Button
					if suite == null: continue
					suite.pressed.emit()
					await stabiliser()
					break
		"onglet_cle":
			app.management_ui[str(ecran.cle)] = str(ecran.onglet)
			app._navigate(str(ecran.route))
			await stabiliser()
			if ecran.has("defiler"):
				var colonne := app.find_child(str(ecran.defiler), true, false) as ScrollContainer
				if colonne == null: return {"statut": "echec", "note": "colonne %s absente" % ecran.defiler}
				colonne.scroll_vertical = int(colonne.get_v_scroll_bar().max_value)
				await stabiliser()
			if ecran.has("presser"):
				var bouton := app.find_child(str(ecran.presser), true, false) as Button
				if bouton == null: return {"statut": "echec", "note": "bouton %s absent" % ecran.presser}
				bouton.pressed.emit()
				await stabiliser()
		"centre_onglet":
			app.management_ui.immersive_centre = {"club": app.model.get("club", {}).get("id"), "tab": str(ecran.onglet), "scroll": {}}
			app._navigate("Centre")
			await stabiliser()
			# Centre en pages façon Effectif (parcours actifs) : onglets dessinés, sans TabContainer.
			var visuel := app.find_child("CentreVisuel", true, false)
			# Affichage compact (sous 1280 × 720) : mêmes pages en conteneurs, page « CarnetAcademyPathways » portant l'onglet.
			if visuel == null:
				var compact := app.find_child("CarnetAcademyPathways", true, false)
				if compact != null and compact.has_meta("onglet"): visuel = compact
			if visuel != null:
				if str(visuel.get_meta("onglet", "")) != str(ecran.onglet): return {"statut": "echec", "note": "onglet %s non ouvert" % ecran.onglet}
				# Affichage compact : la page défile (le bas de l'onglet porte rencontres juniors et réglages).
				if ecran.has("defiler_visuel"):
					var colonne := app.find_child(str(ecran.defiler_visuel), true, false) as ScrollContainer
					if colonne != null:
						await stabiliser()
						colonne.scroll_vertical = int(colonne.get_v_scroll_bar().max_value)
						await stabiliser()
				if ecran.has("presser_visuel"):
					var cible := app.find_child(str(ecran.presser_visuel), true, false) as Button
					if cible == null: return {"statut": "echec", "note": "bouton %s absent" % ecran.presser_visuel}
					cible.pressed.emit()
					await stabiliser()
					await stabiliser()
				return {"statut": "ok"}
			if ecran.has("presser_visuel"): return {"statut": "indisponible", "note": "parcours du centre non activés"}
			var onglets := app.find_child("AcademyTabs", true, false) as TabContainer
			if onglets == null: return {"statut": "indisponible", "note": "parcours du centre non activés"}
			if str(onglets.get_tab_control(onglets.current_tab).name) != str(ecran.onglet): return {"statut": "echec", "note": "onglet %s non ouvert" % ecran.onglet}
			if ecran.has("texte"):
				for bouton: Node in onglets.get_tab_control(onglets.current_tab).find_children("*", "Button", true, false):
					if (bouton as Button).text == str(ecran.texte):
						(bouton as Button).pressed.emit()
						break
				await stabiliser()
		"finances_onglet":
			app.management_ui["immersive08_finance_tab"] = str(ecran.onglet)
			app._navigate("Finances")
			await stabiliser()
		"creation_options":
			app._navigate("Création")
			await stabiliser()
			var grille := app.find_child("CreationClubGrid", true, false) as GridContainer
			if grille == null or grille.get_child_count() == 0: return {"statut": "echec", "note": "grille des clubs absente"}
			(grille.get_child(0) as BaseButton).pressed.emit()
			await stabiliser()
			var etape := app.find_child("CreationStepCareer", true, false) as BaseButton
			if etape == null or etape.disabled: return {"statut": "echec", "note": "étape Carrière inaccessible"}
			etape.pressed.emit()
			await stabiliser()
			if app.find_child("CreationCareerOptions", true, false) == null: return {"statut": "echec", "note": "options de carrière non ouvertes"}
		"options":
			app._navigate("Bureau")
			await stabiliser()
			# En carrière, Réglages est un écran de la coque (plus de fenêtre).
			app.settings()
			await stabiliser()
			if app.route != "Réglages" or app.root_content.find_child("PreferencesPage", true, false) == null: return {"statut": "echec", "note": "écran Réglages non ouvert"}
		"recherche":
			app._navigate("Bureau")
			await stabiliser()
			# Comme Ctrl+K puis Entrée dans la barre haute : résultats de la requête « a » dans la coque.
			app.navigation_controller.submit_search("a")
			await stabiliser()
			if app.route != "Recherche" or app.root_content.find_child("SearchResult0", true, false) == null: return {"statut": "echec", "note": "écran Recherche sans résultat"}
		"causerie":
			var limite_causerie := Time.get_ticks_msec() + 120000
			var envoye := false
			while Time.get_ticks_msec() < limite_causerie:
				var scene_c: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
				if scene_c is Dictionary and app.contextual_director.kind == "locker" and not app.waiting: break
				if not envoye and not app.waiting and scene_c == null and not app.model.get("live") is Dictionary:
					envoye = true
					app._command("begin_match", {})
				for k in 5: await process_frame
			var scene_v: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
			if not scene_v is Dictionary: return {"statut": "echec", "note": "causerie absente : " + str(app.last_error)}
			if bool(ecran.get("reactions", false)) and not scene_v.get("decision") is Dictionary:
				var options: Array = scene_v.get("options", [])
				if options.is_empty(): return {"statut": "echec", "note": "aucune phrase de causerie"}
				app._command("match_talk_decide", {"key": scene_v.key, "phase": scene_v.phase, "choiceId": options[2 if options.size() > 2 else 0].get("id"), "audience": "group", "playerIds": []})
				var limite_d := Time.get_ticks_msec() + 60000
				while Time.get_ticks_msec() < limite_d and not app.model.get("clubLife", {}).get("matchTalks", {}).get("scene", {}).get("decision") is Dictionary: await process_frame
			await stabiliser()
			await stabiliser()
		"avant_bilan":
			# Bilan de la dernière rencontre : pastille du bandeau → petite fenêtre.
			app._navigate("Match")
			await stabiliser()
			var ouvre := app.find_child("MatchLastMatchOpen", true, false) as Button
			if ouvre == null: return {"statut": "indisponible", "note": "pas de pastille du dernier match (aucun match joué)"}
			ouvre.pressed.emit()
			await stabiliser()
			if app.find_child("MatchBilanFenetre", true, false) == null: return {"statut": "echec", "note": "petite fenêtre du bilan non ouverte"}
		_:
			return {"statut": "echec", "note": "type d'écran inconnu : " + str(ecran.type)}
	return {"statut": "ok"}

## Remet l'écran dans son état ordinaire après la capture.
func refermer(ecran: Dictionary) -> void:
	if str(ecran.type) == "calendrier_semaine":
		var mois: Node = app.find_child("CarnetCalendar", true, false)
		if mois != null and mois.has_method("_view_as"): mois._view_as("month")
	if str(ecran.type) == "mini_fiche": load("res://ui/immersive08/mini_fiche.gd").cacher(app)
	if str(ecran.type) == "avant_bilan": load("res://ui/petite_fenetre.gd").fermer_derniere(app.get_tree())
	if str(ecran.type) == "avant_delegation":
		var avant: Control = app.match_screen.find_child("MatchOpening", true, false) if app.match_screen != null else null
		if avant != null: avant.fermer_page()
	if str(ecran.type) in ["preparation_bas", "preparation_sous"] and app.management_ui.get("preparation") is Dictionary: app.management_ui.preparation.sub = ""
	if str(ecran.type) == "preparation_onglet" and app.management_ui.get("preparation") is Dictionary: app.management_ui.preparation.tab = 0
	if str(ecran.type) == "creation_options":
		app.management_ui.erase("creation_step")
		app.management_ui.erase("creation_selection")
	if str(ecran.type) == "effectif_onglet":
		app.management_ui.roster.immersive_tab = 0
		app.management_ui.roster.erase("plan_saison")
	if ecran.has("poste_xv"):
		app.management_ui.roster.etoiles_poste = 0
		app.management_ui.roster.sort = "Poste"
		app.management_ui.roster.descending = false
		app.roster_sort = "Poste"
	if str(ecran.type) == "finances_onglet": app.management_ui["immersive08_finance_tab"] = "summary"
	if str(ecran.type) == "centre_onglet": app.management_ui.immersive_centre = {"club": app.model.get("club", {}).get("id"), "tab": "", "scroll": {}}
	if str(ecran.type) == "onglet_cle":
		if ecran.has("presser"): load("res://ui/petite_fenetre.gd").fermer_derniere(app.get_tree())
		app.management_ui[str(ecran.cle)] = str(ecran.repos)
	if str(ecran.type) == "classements_onglet" and app.management_ui.get("competition") is Dictionary: app.management_ui.competition.tab = "league"
	if str(ecran.type) == "formation_suivi": load("res://ui/immersive08/formation_pages.gd").oublier(app)
	if str(ecran.type) == "equilibre_postes": app.find_child("EffectifTuileAptes", true, false).mouse_exited.emit()
	fermer_fenetres()

func surface() -> Control:
	var director: Node = app.contextual_director
	return director.view if director.active() and director.kind == "live" else null

## Coup d'envoi comme le bouton du jeu, causeries passées comme le ferait un joueur (même logique que
## tools/match-filme/match_filme.gd). Renvoie "" si le direct est ouvert, sinon la raison.
## Données de maquette des pastilles Bleus / Nationale (captures seulement) : remises à leur valeur d'origine.
func retirer_maquette_tactique() -> void:
	if not has_meta("maquette_tactique"): return
	var origine: Dictionary = get_meta("maquette_tactique")
	remove_meta("maquette_tactique")
	for paire: Array in [[app.model.get("clubLife", {}), "doublons", origine.doublons], [app.model.get("selection", {}), "nationaleQualification", origine.nationale]]:
		if paire[2] == null: (paire[0] as Dictionary).erase(paire[1])
		else: paire[0][paire[1]] = paire[2]
	app._render()
	await stabiliser()

func ouvrir_direct() -> String:
	fermer_fenetres()
	var limite := Time.get_ticks_msec() + 180000
	var envois := 0
	while Time.get_ticks_msec() < limite and surface() == null:
		var causerie: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		var pret: bool = app.model.get("meta", {}).get("calendarCadence", {}).get("matchReady", false)
		if not app.waiting and causerie is Dictionary and app.contextual_director.kind == "locker":
			app._command("match_talk_continue", {"key": causerie.key, "phase": causerie.phase, "skip": true})
		elif not app.waiting and causerie == null and not app.model.get("live") is Dictionary and app.model.get("next") != null:
			if not pret: return "pas de match ce jour dans la carrière importée"
			if envois >= 3: return "coup d'envoi refusé : " + str(app.last_error)
			envois += 1
			print("ECRANS_FILMES coup d'envoi")
			app._command("begin_match", {})
		for k in 10: await process_frame
	if surface() == null: return "le direct ne s'est pas ouvert : " + str(app.last_error)
	couper_le_son()
	# Laisse passer l'ouverture du direct (scène 3D, bandeau) avant la première image.
	await create_timer(4.0).timeout
	return ""

func ouvrir_en_direct(ecran: Dictionary) -> Dictionary:
	var vue: Control = surface()
	if vue == null: return {"statut": "echec", "note": "direct fermé"}
	var equipe: Variant = vue.get("equipe")
	if str(ecran.type) == "apres_match": return await ouvrir_apres_match(vue)
	if str(ecran.type) == "direct":
		if is_instance_valid(equipe) and equipe.visible: equipe.fermer(false)
		if bool(ecran.get("entracte", false)): return await ouvrir_entracte()
		await stabiliser()
		return {"statut": "ok"}
	if not is_instance_valid(equipe) or not vue.has_method("ouvrir_equipe"): return {"statut": "indisponible", "note": "fenêtre Équipe absente"}
	if not equipe.visible: vue.ouvrir_equipe(str(ecran.get("onglet", "composition")))
	else: equipe.choisir_onglet(str(ecran.get("onglet", "composition")))
	await stabiliser()
	if not equipe.visible: return {"statut": "echec", "note": "fenêtre Équipe non ouverte (match terminé ?)"}
	return {"statut": "ok"}

## Entracte 2D d'un vrai match : horloge Éclair et aucun temps fort (réglages du jeu), causeries passées comme le
## ferait un joueur, arrêts de jeu repris ; s'arrête à la mi-temps quand l'écran intermédiaire est affiché. Si la
## mi-temps passe sans lui (causerie), le match est mis en pause dans l'entracte suivant (commande du jeu).
func ouvrir_entracte() -> Dictionary:
	var limite := Time.get_ticks_msec() + 300000
	var note := ""
	while Time.get_ticks_msec() < limite:
		var vue: Control = surface()
		var live: Dictionary = app.model.get("live", {}) if app.model.get("live") is Dictionary else {}
		var causerie: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if live.get("finished", false): return {"statut": "echec", "note": "match fini avant la mi-temps"}
		if not app.waiting and causerie is Dictionary and app.contextual_director.kind == "locker":
			app._command("match_talk_continue", {"key": causerie.key, "phase": causerie.phase, "skip": true})
		elif vue != null and vue.get("regie") != null and not app.waiting:
			var regie: Node = vue.regie
			if regie.horloge != "eclair": regie.choisir_horloge("eclair")
			if regie.niveau != "aucun": regie.choisir_niveau("aucun")
			var montre: bool = regie.between.is_visible_in_tree() and regie.etat == regie.INTER
			if montre and live.get("atBreak", false):
				note = "mi-temps"
				break
			if montre and int(live.get("minute", 0)) > 40 and live.get("paused", false) and note == "pause":
				break
			if montre and int(live.get("minute", 0)) > 40 and not live.get("paused", false):
				app._command("pause", {"paused": true})
				note = "pause"
			elif regie.etat == regie.SORTIE: regie.passer()
			elif not regie.arret.is_empty(): regie.between.reprise_demandee.emit()
			elif live.get("paused", false) and not live.get("atBreak", false) and regie.arret.is_empty() and note.is_empty():
				app._command("pause", {"paused": false})
		for k in 5: await process_frame
	if note.is_empty(): return {"statut": "echec", "note": "mi-temps non atteinte"}
	print("ECRANS_FILMES entracte : ", note)
	await create_timer(3.0).timeout
	await stabiliser()
	return {"statut": "ok", "note": "entracte arrêté (%s)" % note}

## Après-match d'un vrai match : la fin est confiée à l'adjoint (commande du jeu), le débrief du vestiaire est passé
## comme le ferait un joueur, puis l'écran attend que l'après-match (ui/contextual/apres_match.gd) soit affiché.
func ouvrir_apres_match(vue: Control) -> Dictionary:
	var equipe: Variant = vue.get("equipe")
	if is_instance_valid(equipe) and equipe.visible: equipe.fermer(false)
	var limite := Time.get_ticks_msec() + 240000
	var delegue := false
	while Time.get_ticks_msec() < limite:
		var actuelle: Control = surface()
		var apres: Variant = actuelle.get("apres_match") if actuelle != null else null
		if apres is Control and is_instance_valid(apres) and (apres as Control).is_visible_in_tree(): break
		var live: Variant = app.model.get("live")
		var causerie: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if not app.waiting and causerie is Dictionary and app.contextual_director.kind == "locker":
			app._command("match_talk_continue", {"key": causerie.key, "phase": causerie.phase, "skip": true})
		elif not app.waiting and not delegue and live is Dictionary and not bool(live.get("finished", false)):
			delegue = true
			print("ECRANS_FILMES fin confiée à l'adjoint")
			app._command("delegate", {})
		for k in 10: await process_frame
	var vue_finale: Control = surface()
	var ecran_final: Variant = vue_finale.get("apres_match") if vue_finale != null else null
	if not (ecran_final is Control and is_instance_valid(ecran_final) and (ecran_final as Control).is_visible_in_tree()):
		return {"statut": "echec", "note": "après-match non affiché : " + str(app.last_error)}
	await create_timer(2.0).timeout
	await stabiliser()
	return {"statut": "ok"}

## Capture et analyse l'écran ouvert ; complète l'entrée du rapport.
func capturer(entree: Dictionary, o: Dictionary, taille: Vector2i) -> void:
	fermer_aide()
	await stabiliser()
	fermer_aide()
	# CD_FILM_SURVOL_LIGNE=1 : une ligne survolée (et une choisie) dans chaque liste visible (ui/survol_ligne.gd).
	if OS.get_environment("CD_FILM_SURVOL_LIGNE") == "1":
		print("ECRANS_FILMES survol de ligne : ", load("res://ui/survol_ligne.gd").simuler(self), " liste(s)")
		await stabiliser()
	# CD_FILM_RETOUR_TUILE=1 : une tuile survolée et une enfoncée (ui/retour_tuile.gd) ; CD_FILM_RETOUR_TUILE_CIBLES
	# choisit les zones par nom.
	if OS.get_environment("CD_FILM_RETOUR_TUILE") == "1":
		print("ECRANS_FILMES retour de tuile : ", load("res://ui/retour_tuile.gd").simuler(self))
		print("ECRANS_FILMES lignes : ", load("res://ui/survol_ligne.gd").simuler(self), " survolée(s), ", load("res://ui/survol_ligne.gd").simuler_appui(self), " enfoncée(s)")
		await stabiliser()
	# CD_FILM_BLESSURE=n : ouvre la petite fenêtre « blessure » du n-ième blessé (pastille Blessé de l'écran, 1 = premier).
	if OS.get_environment("CD_FILM_BLESSURE").is_valid_int() and int(OS.get_environment("CD_FILM_BLESSURE")) >= 1:
		var pastilles := get_nodes_in_group(&"ouvre_blessure").filter(func(b: Node) -> bool: return b is BaseButton and (b as Control).is_visible_in_tree())
		var rang := mini(int(OS.get_environment("CD_FILM_BLESSURE")), pastilles.size()) - 1
		print("ECRANS_FILMES blessure : ", pastilles.size(), " pastille(s)")
		if rang >= 0:
			(pastilles[rang] as BaseButton).pressed.emit()
			await stabiliser()
	if OS.get_environment("CD_FILM_AUDIT_TUILES") == "1":
		for ligne in load("res://ui/retour_tuile.gd").auditer(self): print("AUDIT_TUILE ", entree.id, "|", ligne)
	var prise: Dictionary = await image_stable()
	var image: Image = prise.image
	if image == null:
		entree.statut = "echec"
		entree.note = "aucune image rendue"
		return
	var fichier := nom_fichier(str(entree.id), taille.x, taille.y)
	if image.save_png(str(o.sortie).path_join(fichier)) != OK:
		entree.statut = "echec"
		entree.note = "écriture impossible : " + fichier
		return
	entree.fichier = fichier
	entree.stable = prise.stable
	entree.luminance = snappedf(luminance(image), 0.001)
	if entree.luminance < SEUIL_NOIR:
		entree.statut = "echec"
		entree.note = "image noire"
	entree.merge(analyser())
	if o.planche:
		if not vignettes.has(taille): vignettes[taille] = []
		vignettes[taille].append(vignette(image, 384))

func run() -> void:
	var lu := lire_options(OS.get_cmdline_user_args())
	if not lu.erreurs.is_empty():
		echouer("\n".join(PackedStringArray(lu.erreurs)))
		return
	var o: Dictionary = lu.options
	var source := routes_geometrie()
	var choix := filtrer(liste_ecrans(source.routes), o.ecrans)
	if not choix.inconnus.is_empty():
		echouer("Écrans inconnus : " + ", ".join(PackedStringArray(choix.inconnus)) + ". Connus : " + ", ".join(PackedStringArray(liste_ecrans(source.routes).map(func(e: Dictionary): return str(e.id)))))
		return
	var ecrans: Array = choix.ecrans
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty() or not OS.get_environment("CD_GODOT_DATA_DIR").is_absolute_path():
		echouer("CD_GODOT_DATA_DIR (profil jetable, chemin absolu) est obligatoire : aucune vraie carrière n'est utilisée.")
		return
	if DisplayServer.get_name() == "headless":
		echouer("--headless ne rend aucune image : lancer avec un affichage (scripts/ecrans-filmes.ps1 le fait sur un bureau séparé).")
		return
	if not FileAccess.file_exists(o.export):
		echouer("Carrière introuvable : " + str(o.export))
		return
	if DirAccess.make_dir_recursive_absolute(o.sortie) != OK:
		echouer("Dossier de sortie inaccessible : " + str(o.sortie))
		return
	var debut := Time.get_ticks_msec()
	var fin_au_plus_tard: float = debut + float(o.duree_max) * 1000.0
	couper_le_son()
	DirAccess.make_dir_recursive_absolute(profil())
	var reglages := FileAccess.open(profil().path_join("interface.json"), FileAccess.WRITE)
	reglages.store_string(JSON.stringify({"version": 1, "volume": 0, "reduced_motion": false, "quality": "balanced", "camera": "tv"}, "  "))
	reglages.close()
	Engine.max_fps = 30
	app = load("res://main.tscn").instantiate()
	# Le jeu remet sa fenêtre en plein écran maximisé au démarrage : ici la fenêtre garde la taille
	# demandée (le retour différé lit `closing` et ne fait rien pendant la première image).
	app.closing = true
	root.add_child(app)
	for signal_fenetre: Signal in [root.size_changed, root.focus_entered]:
		if signal_fenetre.is_connected(app._keep_filled_display): signal_fenetre.disconnect(app._keep_filled_display)
	await process_frame
	app.closing = false
	var limite := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < limite: await process_frame
	couper_le_son()
	print("ECRANS_FILMES import")
	if not app._command("import", {"text": FileAccess.get_file_as_string(o.export)}):
		echouer("Import de la carrière refusé : " + str(app.last_error))
		return
	limite = Time.get_ticks_msec() + 180000
	while app.waiting and Time.get_ticks_msec() < limite: await process_frame
	if not app._has_career():
		echouer("Aucune carrière après l'import : " + str(app.last_error))
		return
	# Rendez-vous du club en attente (carrière reprise telle quelle) : réglés comme dans les tests de géométrie,
	# sinon la navigation reste bloquée sur le rendez-vous.
	if app.model.get("clubLife", {}).get("clubMeetings", {}).get("scene") is Dictionary:
		var salles = load("res://qa_runner.gd")
		await salles.settle_club_meetings(app, self, func(_ok: bool, _message: String): pass)
		# settle_club_meetings arrête l'horloge du direct : elle repart pour le match filmé à la fin.
		if app.timer.is_stopped(): app.timer.start()
		await stabiliser()
	var club: Dictionary = app.model.get("club", {})
	var report := {"options": {"tailles": o.tailles.map(func(t: Vector2i): return "%dx%d" % [t.x, t.y]), "ecrans": o.ecrans, "duree_max": o.duree_max, "direct": o.direct},
		"source_ecrans": source.source, "pilote": RenderingServer.get_current_rendering_driver_name(), "carte": RenderingServer.get_video_adapter_name(), "audio": AudioServer.get_driver_name(),
		"carriere": {"club": str(club.get("name", "")), "date": str(app.model.get("meta", {}).get("calendarToday", ""))},
		"tailles": [], "ecrans": [], "planches": []}
	var hors_direct: Array = ecrans.filter(func(e: Dictionary): return not str(e.type) in ["direct", "equipe", "apres_match"])
	var en_direct: Array = ecrans.filter(func(e: Dictionary): return str(e.type) in ["direct", "equipe", "apres_match"])
	var delai_depasse := false
	for taille: Vector2i in o.tailles:
		var obtenue: Dictionary = await appliquer_taille(taille)
		report.tailles.append(obtenue)
		for ecran: Dictionary in hors_direct:
			var entree := {"id": ecran.id, "libelle": ecran.libelle, "taille": "%dx%d" % [taille.x, taille.y]}
			report.ecrans.append(entree)
			if Time.get_ticks_msec() > fin_au_plus_tard:
				delai_depasse = true
				entree.statut = "non_visite"
				continue
			var ouvert: Dictionary = await ouvrir(ecran)
			entree.merge(ouvert)
			entree.route = app.route
			if entree.statut == "ok": await capturer(entree, o, taille)
			refermer(ecran)
			print("ECRANS_FILMES ", entree.taille, " ", entree.id, " ", entree.statut, " debordements=", entree.get("nombre_debordements", 0), " tronques=", entree.get("nombre_textes_tronques", 0))
	if not en_direct.is_empty():
		var raison := "désactivé (--sans-direct)" if not o.direct else ("durée maximale atteinte" if Time.get_ticks_msec() > fin_au_plus_tard else "")
		if raison.is_empty():
			app._navigate("Bureau")
			await stabiliser()
			raison = await ouvrir_direct()
		for taille: Vector2i in o.tailles:
			if raison.is_empty(): await appliquer_taille(taille)
			for ecran: Dictionary in en_direct:
				var entree := {"id": ecran.id, "libelle": ecran.libelle, "taille": "%dx%d" % [taille.x, taille.y]}
				report.ecrans.append(entree)
				if not raison.is_empty():
					entree.statut = "non_visite" if not o.direct or raison.begins_with("durée") else ("indisponible" if raison.begins_with("pas de match") else "echec")
					entree.note = raison
					continue
				if Time.get_ticks_msec() > fin_au_plus_tard:
					delai_depasse = true
					entree.statut = "non_visite"
					continue
				var dans_le_direct: Dictionary = await ouvrir_en_direct(ecran)
				entree.merge(dans_le_direct)
				if entree.statut == "ok": await capturer(entree, o, taille)
				print("ECRANS_FILMES ", entree.taille, " ", entree.id, " ", entree.statut)
	if o.planche:
		for taille_planche: Vector2i in vignettes:
			var nom := nom_planche(taille_planche.x, taille_planche.y)
			var feuille := planche(vignettes[taille_planche], 5)
			if feuille != null and feuille.save_png(str(o.sortie).path_join(nom)) == OK: report.planches.append(nom)
	var compte := {"ok": 0, "echec": 0, "redirige": 0, "indisponible": 0, "non_visite": 0}
	var debordements := 0
	var tronques := 0
	for entree: Dictionary in report.ecrans:
		compte[entree.statut] = int(compte.get(entree.statut, 0)) + 1
		debordements += int(entree.get("nombre_debordements", 0))
		tronques += int(entree.get("nombre_textes_tronques", 0))
	report.reussis = compte.ok
	report.echecs = compte.echec
	report.redirections = compte.redirige
	report.indisponibles = compte.indisponible
	report.non_visites = compte.non_visite
	report.debordements = debordements
	report.textes_tronques = tronques
	report.ecrans_en_echec = report.ecrans.filter(func(e: Dictionary): return e.statut == "echec").map(func(e: Dictionary): return "%s-%s : %s" % [e.id, e.taille, e.get("note", "")])
	report.delai_depasse = delai_depasse
	report.duree_s = snappedf((Time.get_ticks_msec() - debut) / 1000.0, 0.1)
	var fichier := FileAccess.open(str(o.sortie).path_join("report.json"), FileAccess.WRITE)
	fichier.store_string(JSON.stringify(report, "  "))
	fichier.close()
	print("ECRANS_FILMES_FIN ", JSON.stringify({"reussis": report.reussis, "echecs": report.echecs, "redirections": report.redirections, "non_visites": report.non_visites, "debordements": debordements, "textes_tronques": tronques, "secondes": report.duree_s, "pilote": report.pilote, "audio": report.audio}))
	app.closing = true
	app.bridge.stop()
	for k in 10: await process_frame
	quit(0 if report.reussis > 0 and report.echecs == 0 and not delai_depasse else 3)
