# Règles et préférences du créateur

Tirées de ses consignes dans les conversations, de novembre 2026. Elles priment sur `AGENTS.md`, `CLAUDE.md` et le kit d'agents. Quand une règle est datée, la plus récente l'emporte sur l'ancienne (les remplacements sont signalés). En cas de doute sur un choix de jeu ou de visuel : ne pas l'intégrer, le signaler avec des options (voir [decisions-a-valider.md](decisions-a-valider.md)).

## 1. Façon de travailler et de communiquer

- **Réponses courtes, côté jeu, en français, toujours** (17/11 et 19/11). Dire ce qui change à l'écran ou dans la partie, ce qui marche, ce qui reste à voir. Pas de noms de fichiers, fonctions, commits, runs ni chiffres de tests sauf demande. Le détail technique va dans la PR. Y compris les petites phrases d'avancement : jamais en anglais.
- **Sous-agents systématiques** (17/11) : découper chaque chantier, confier le travail cadré à des sous-agents avec modèle et effort adaptés, citer modèle et effort utilisés dans le compte rendu. Sonnet pour le cadré, les tests, les vérifications chiffrées ; Opus seulement pour le moteur, l'économie, la 3D, les refontes d'interface (24/11). Pour escalader : d'abord un moyen de vérifier, puis l'effort, le modèle en dernier. Lancer les suites et saisons EN PARALLÈLE dans le quota, jamais en boucle séquentielle (24/11).
- **Économiser les tokens est toujours une priorité** (25/11). Passation dès qu'un chantier dépasse environ 2 lots ou 6 à 8 rapports d'agents (une passation reste sous 20 Ko, on remplace la section « état actuel » au lieu d'empiler). Ne pas lancer de nouveau chantier tant que les agents en cours ne sont pas finis ; ne donner le prompt de reprise qu'une fois tout terminé.
- **Carte du code dans les briefs** (24/11) : `ECRANS.md`, `carte-code.cjs`, agent `eclaireur`.
- **Utiliser le kit CCGS** (19/11) : rôles et commandes `/team-ui`, `/ux-review`, etc. pour structurer un chantier, au lieu d'agents génériques.
- **Donner modèle et effort sous chaque prompt de chantier** (19/11).
- **Autorisation large sauf payer** (19/11) : chercher sur le web, télécharger des ressources gratuites et sûres (polices OFL, sources officielles), valider, pousser et ouvrir des PR sans redemander. **Jamais payer.**
- **Rien du projet vers l'extérieur** (22/11) : dans une requête web, jamais l'adresse du dépôt, un pseudo, un nom ou une adresse électronique. Identifiant client générique. Si un site exige un contact : s'arrêter.
- **Ne pas toucher aux chantiers en cours** (19/11) : une PR ouverte appartient à une autre conversation ; choisir des fichiers qui ne la recoupent pas.
- **Demander avant d'intégrer en cas de doute** (20/11). Tout choix visuel ou de jeu non tranché par la charte ou par une décision du créateur : l'agent ne l'intègre pas, il le signale avec les options. Pour un choix visuel, présenter chaque option en vraie capture du jeu avant de passer la PR en prête. Exception : si le créateur dit « en autonomie, sans rien me demander » pour un chantier, trancher dans l'esprit de ses choix et lister ces choix dans la PR. Annoncer le coût en temps d'un dispositif de choix avant de le lancer.
- **Images : uniquement l'état après** (18/11). Plus jamais d'avant/après ni de côte à côte, sauf comparatif d'options à choisir.
- **Conversations qui obéissent à la direction** (27/11) : le créateur ne veut pas servir de relais entre conversations. Pendant son absence, le directeur du développement tranche à sa place ; si une conversation de chantier refuse encore de modifier un test sans l'accord tapé du créateur, ne pas contourner : le noter dans [decisions-a-valider.md](decisions-a-valider.md).
- **Ménage disque automatique** (26/11) : le disque local est tombé à zéro en plein travail. Chaque conversation supprime ses films dès le GO (garder rapports et une dizaine d'images) et son worktree dès la fusion de la PR. Ne jamais toucher aux PR ouvertes ni au travail sans PR.
- **Jamais de `git stash`** (20/11) : la pile est commune à tous les worktrees. Un worktree par chantier, commits locaux à la place.
- **Fusion auto en squash** à chaque PR prête (16/11), sans demander. Exception : changement visuel (voir validation).
- **Rappels fréquents plutôt qu'un seul gros rappel** (19/11) : suivre une PR par de petits rappels courts (environ toutes les 15 à 20 minutes), chacun autonome et idempotent.
- **Vérificateur avant « c'est fait »** (24/11) : agent indépendant, GO ou NO-GO sur le vrai jeu. Voir [LISEZ-MOI.md](LISEZ-MOI.md).

## 2. Tests : règles strictes

- **Jamais abaisser un seuil, relever une limite ou un délai sans mesure, affaiblir ou retirer un contrôle, sauter un test, marquer « attendu rouge »** (vérifié et répété depuis le 24/11). Un test rouge a trois causes possibles : (a) vrai défaut du jeu, on corrige le jeu et le test existant doit passer sans modification ; (b) test périmé (changement voulu du jeu), on prépare un correctif de test aux mêmes contrôles et mêmes seuils ; (c) hasard non figé, on fige la graine après avoir vérifié le test vert sur 3 graines et rouge si on casse la fonction.
- **Modifier un test existant demande l'accord du créateur** (26/11), cité dans le commit et la PR (« accord de Léo, <date> »). Le 27/11 il a étendu : les conversations obéissent à la direction, qui décide pour lui. En cloud, en son absence : préparer la PR de test, la laisser **sans fusion auto**, et la lister dans [decisions-a-valider.md](decisions-a-valider.md), sauf si l'accord figure déjà dans un document de cette passation.
- **Élargir l'échantillon plutôt que toucher le contrôle** : un test à graine fixe au bord de son seuil se corrige en augmentant le nombre de matchs, jamais en baissant le seuil.
- **Les tests ne doivent pas attendre en temps réel** (21/11, 27/11) : versions de test du jeu à vitesse maximale, attentes sur un état et non sur une minuterie. Une suite qui attend en temps réel est à corriger.
- **Mode Monde uniquement** (13/11) : aucun test dans l'ancien mode France.
- Un test que personne n'a vu rouge ne prouve rien ; des tests verts ne prouvent pas la conformité aux règles du rugby.

## 3. Interface, jeu et direction artistique

### Charte et style

- **Charte finale de la graphiste adoptée le 20/11** (`design/art/art-bible.md`, jetons `native/godot/ui/charte.gd`). Elle remplace la revue DA du 19/11 pour le style : plus d'inclinaison de 10° ni d'angles droits ; pilules, panneaux de rayon 18 sans bordure, cartes de 12, cases de 6, un seul aplat doré par écran.
- **Exceptions décidées par le créateur** : pas de fiche à droite qui suit la sélection ; titres droits ; police Barlow Condensed conservée ; photos d'ambiance voilées ; jaune des notes 55 à 64 passé au citron `d4e35c` ; **bandeaux d'équipe de l'Avant-match gardés en aplat aux couleurs des clubs** pour l'immersion ; fiche joueur et tous les grands titres d'écran en Anton (droit), titre de héros = nom de l'écran en capitales sans slogan ; après-match : bandeau photo à 30 %, nom coupé par une alerte longue remplacé par l'initiale du prénom ; ombres portées noir 50 %, sans décalage, étendue 4 px, sur panneaux, cartes et tuiles seulement (jamais sur pilules, boutons ni lignes) ; match : bannière d'essai en aplat à la couleur du club qui marque, bandeau du score sobre.
- **Plus de couleur** (21/11) : « fade » est un défaut. Une couleur franche par donnée, la même partout : condition, normal, gain vert `#7fbf7a` ; moral bleu `#5b9bd5` ; confiance violet `#a88bd6` ; repos turquoise `#4fb3a9` ; intensif orange `#e0a04a` ; perte rouge `#d9634f`. Icônes teintées, léger fond teinté sur les tuiles. Pas de doré hors « Continuer ». La couleur n'est jamais seule : un chiffre, un mot ou une forme la double.
- **Densité comme Football Manager** (19/11) : corps 13 px à 1080p, tableaux à lignes de 24 px, réglage d'échelle 90 à 130 %. Écran de match : textes grands, écran rempli, cibles 2560×1440 (la résolution du créateur) et 1920 ; 1280 ignoré pour le match (mais la mise en page des autres écrans est testée de 720p à 1440p).
- **Pas de phrases explicatives sur les écrans** (21/11) : ça « fait IA ». Un compteur devient une tuile chiffre, un état une pastille avec icône et un mot, une consigne d'usage rien ou une infobulle derrière un « i ». Une phrase ne reste que si elle porte une information de jeu, courte.
- **Style de l'écran Effectif** (22/11) : la référence est la liste à lignes (colonnes, visages, chiffres colorés, survol de ligne, tri par en-têtes, filtres en pastilles). Les grilles de tuiles empilées sont rejetées ; tuiles seulement pour quelques chiffres clés.
- **Écran de transferts : un écran par offre** (19/11) : le flux des jeux de gestion de référence (courrier, écran de l'offre, négociation dédiée), pas un tableau de bord qui regroupe tout.
- **Fenêtres du match 2D** (23/11) : toutes en fond **anthracite satiné** (bord biseauté, ombre portée), taille comparable (environ deux tiers de l'écran au plus). Une liste ouverte depuis un bouton s'ouvre juste en dessous, bouton allumé tant qu'elle est ouverte. Toute nouvelle fenêtre réutilise le style commun de la fenêtre du joueur.
- **Joueur 3D : modèle A** (24/11), corps re-skinnés sur le squelette du match, validé par le créateur (« parfait ») et intégré. Détails dans [moteur-match.md](moteur-match.md).

### Interactions

- **Tout est cliquable** (19/11, 21/11) : chaque tuile, pastille, anneau, jauge, nom, chiffre ou ligne ouvre quelque chose ; sans destination, apparence neutre. **Petites fenêtres permises** si elles sont visuelles (tuiles, portraits, couleurs), jamais un bloc de texte ; écran entier quand il y a de quoi faire. Échap ferme toujours la petite fenêtre ouverte avant d'ouvrir le menu pause.
- **Clic direct, sans confirmation** (23/11) : un clic sur un choix l'applique tout de suite, sans bouton Valider ou Confirmer. Exception possible seulement pour une action lourde et irréversible (signer un contrat), à demander.
- **Plein écran obligatoire : on n'en sort pas** (21/11) : réunion avec la direction, vestiaire d'avant-match, presse, infirmerie, entretiens. Pas de sortie avant d'avoir fini l'action, et surtout pas en cliquant sur un élément de l'écran : « tout cliquable » se fait par des petites fenêtres par-dessus la scène, jamais par une navigation vers un autre écran.
- **Survol et mini-fiche** (21/11, mis à jour 25/11) : une ligne de liste se démarque au survol. Le survol du **nom** d'un joueur ne fait rien. La mini-fiche (fiche complète en plus petit, textes plus petits) n'apparaît qu'après environ 0,5 s sur le bouton « (i) » à côté du nom. Le clic sur le nom ouvre la **fiche complète**. Exception match (pas de « (i) ») : clic sur le nom = mini-fiche, rien au survol. Clic sur un joueur adverse : Préparation = fiche complète ; avant et après-match = mini-fiche.
- **Étoiles** : seulement pour l'adaptabilité au poste, dans la section Postes de la carte joueur ; ailleurs chiffre ou barre avec marqueur poste naturel ou dépanne (les étoiles relatives au meilleur poste ont été rejetées). Niveau et potentiel en chiffres ou lettres, jamais en étoiles.
- **Note au poste en lettre** (25/11) ; attributs visibles par défaut, y compris ceux des autres clubs (comme Football Manager) ; une option à la création de carrière donne des fourchettes.
- **Échap** ouvre le menu pause (aussi un bouton « Menu »). Page « Centre » supprimée.

### Incertitude (23/11, précisé 25/11)

1. Jamais le chiffre exact du moteur avant d'agir (pas de « +1 proposition », « Demande −2 % ») ; l'effet se découvre après coup en ▲/▼.
2. Ce que prévoit le staff est une estimation dont la précision dépend de sa compétence.
3. Chaque effet réel a une part de hasard : une tendance claire, jamais une certitude.
4. Les jauges d'effet avant action deviennent des tendances (fort, léger, flèche).
5. Les caractères cachés (agent gourmand, pressé, etc.) se découvrent par un mot affiché, jamais par leur traduction en statistiques.

L'incertitude porte sur les **effets des décisions**, pas sur les attributs des joueurs. Un inventaire (environ 30 endroits montrent encore un chiffre exact avant d'agir, 34 de plus sont trop précis) a été fait ; la grammaire à appliquer partout attend le choix du créateur (voir [decisions-a-valider.md](decisions-a-valider.md)). Vérifier ce point en revue de chaque écran.

### Match

- **Pas de sortie en plein match** (16/11) : si le joueur force l'arrêt, la carrière reprend **avant le match**, jamais en plein match.
- **Pause toujours cliquable pendant un match** (fait, #1318).
- **Chaque match est unique** (vérifié : 600 déroulements différents sur 600). Changer tactique ou joueurs doit changer le match (en cours d'amélioration, voir [moteur-match.md](moteur-match.md)).
- **Calage réel par championnat** : le pourcentage de victoires des favoris, les matchs serrés (Top 14 environ 40 %), les points et essais par match sont calés sur la réalité. À surveiller à chaque lot du moteur.
- **Décisions de réalisme déjà prises** : maul, on laisse les têtes au contact (option A) ; gestes 3D du coup franc, de l'essai de pénalité et du drop : plan large partout ; coups de pied en temps fort : option B (chandelles reprises et rasants récupérés montrés en temps forts, avec légendes) ; transformation : défense en en-but puis charge, caméra sur le buteur (option A) ; en match, un clic sur le nom ouvre la mini-fiche.
- **Immersion** (10/11) : tout du point de vue du manager, vocabulaire du club ; aucun badge « fictif » ou « généré par IA » à l'écran.
- **Rugby** : XV adulte d'élite seulement ; lire `docs/rugby-rules-reference.md` avant tout travail sur les lois.

## 4. Données privées et dépôt public

- Le dépôt est public. Les vrais noms, photos et logos n'y entrent jamais ni dans le build du jeu de base ni dans ses tests. Des ressources privées existent hors dépôt : ne jamais les ajouter sans accord explicite du créateur, et ne rien y pousser sans lui avoir montré où ça va.
- Les vrais âges et postes des joueurs dans le jeu de base sont voulus : ne pas les signaler comme une fuite.
- Une animation ou un pack privé hors dépôt ne peut pas être intégré sans décision du créateur (voir [a-faire.md](a-faire.md), geste du botteur au drop).

## 5. Machine du créateur (si son PC est rallumé)

- Rien de visible, rien d'audible sur son PC : tout Godot passe par un verrou de places, sur un bureau Windows séparé, son coupé. Jamais de fenêtre sur son bureau.
- Limites de tests en parallèle : 10 Godot et 14 simulations Node quand il ne joue pas ; 5 et 5 quand il joue ; ne remonter que sur son ordre, ne jamais redescendre de soi-même sans qu'il l'ait dit.
- Godot dans un worktree neuf : préparer (staging puis import) avant de conclure à un rouge.
- En cloud, ces limites ne s'appliquent pas : utiliser la CI et `ci/en-ligne.sh` (voir [LISEZ-MOI.md](LISEZ-MOI.md)). Machine cloud : environ 3 simulations en parallèle.
