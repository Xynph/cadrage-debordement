# GitHub privé et tests sur PC personnel — décision du 15 novembre 2026

## Organisation retenue par Léo
GitHub garde le code privé, les branches, PR, revues et la coordination Claude/Codex.
GitHub Actions orchestre les contrôles, mais leur calcul s'effectue uniquement sur le
PC personnel. Aucune machine de calcul GitHub hébergée ni Blacksmith, aucun repli cloud.
Budget supplémentaire autorisé : 0 EUR, calcul, stockage et services tiers compris.
Le PC professionnel ne reçoit ni installation du jeu, ni runner, ni données privées.

Quand le PC personnel est éteint, les nouvelles exécutions attendent puis peuvent
expirer ; les contrôles rouges/manquants ne sont jamais contournés. On peut lire,
modifier le code, préparer et revoir des PR à distance. Les fusions attendent les
contrôles exacts et verts. La gratuité ne garantit pas une disponibilité permanente.

## Préparation livrée dans #743, non activée
Les 57 workflows du main de référence b807b5c4 sont préparés pour 77 jobs personnels :
- Linux de test : [self-hosted, Linux, X64, rl27-linux] ;
- Linux de contrôle : [self-hosted, Linux, X64, rl27-control] ;
- Windows de test : [self-hosted, Windows, X64, rl27-windows].
Tous exigent un dépôt privé ; les PR de forks sont refusées.
Les dépendances, étapes et tests sont conservés. La garde Windows réservée auparavant
au dépôt public est remplacée par la garde privée.
Le profil Linux cloud privé antérieur et CD_PRIVATE_WINDOWS_CLOUD sont abandonnés.

Les sept shards JS sont conservés. Chaque agent de test lance une seule suite à la
fois (CD_SHARD_PARALLEL=1), avec 5120 Mo de réservation (CD_SHARD_MEMORY_MB).
L'ordonnanceur valide toujours le parallélisme. Délai d'un shard : 120 minutes.
Le contrôle de fusion doit tourner sur un agent distinct de ceux qu'il attend :
les jobs d'administration et classification/Validation CI ciblent rl27-control.
Les scripts de fusion conservent leurs critères, SHA et verdicts ; seule leur attente
bornée de CI passe de 32 à 300 minutes sur self-hosted, avec un job limité à 330 min.
Cette borne devra être reçue sur le matériel réel ; un dépassement reste un échec.

Le runner RTX existant dans oval-legacy-recette-windows reste distinct. Sa PR #3
prépare le checkout privé ; son enregistrement actuel ne dessert pas automatiquement
cadrage-debordement. Il faut enregistrer les nouveaux agents dans le dépôt principal.
Ne pas remplacer ni arrêter le service RTX existant pour faire cette installation.

## Ce qui reste accessible uniquement avec le PC et l'administration
Le PC personnel sera disponible plus tard le 15/11. Rien n'y a été installé dans
cette session. La copie locale de préparation est isolée dans /tmp, pas une
modification du checkout utilisé par les autres chantiers.

1. Vérifier le PC : Windows, RAM/CPU, virtualisation, espace, réseau, service RTX
   existant et capacité de GPU. Créer un environnement Linux Ubuntu 24.04 isolé
   (VM sans dossiers personnels montés), avec Node 22, Python, Git, gh, bash,
   outils de build, Xvfb/Mesa et dépendances nécessaires aux workflows. Aucun
   environnement Linux personnel existant n'est présumé adapté ou isolé.
2. Enregistrer des agents officiels GitHub dans des dossiers/comptes dédiés :
   contrôle Linux distinct ; agents Linux de test ; agent Windows non administrateur
   avec accès limité aux seuls dossiers de travail. Aucun accès aux profils,
   documents, navigateurs ou clés personnels. Dimensionner le nombre d'agents de
   test et la RAM sur mesures ; plusieurs services ne créent pas de puissance.
   Vérifier les dépendances Windows (les images hébergées préinstallaient des outils).
3. Configurer le secret CADRAGE_SOURCE_READ_TOKEN dans le dépôt de recette RTX :
   lecture Contents du seul dépôt source, durée limitée. Ne jamais mettre le jeton
   dans le chat, une issue ou un fichier. Le token de dispatch existant est distinct.
4. Vérifier dans Billing le blocage EFFECTIF de toute dépense Actions/stockage.
   Une alerte seule ne suffit pas ; ne pas supposer qu'un budget affiché à zéro
   équivaut à un blocage. Les artefacts, caches et logs restent des services GitHub,
   même avec des runners personnels. Les uploads/downloads inter-jobs existants
   sont conservés pour ne pas casser les recettes : rester dans les allocations
   incluses, réduire leur rétention ou conserver les preuves localement si nécessaire.
   Le stockage supplémentaire reste interdit. Ne rien activer sans contrôle effectif.
5. Recevoir les recettes sur le PC : service seul, échantillon Linux, sept shards,
   trois Godot, Windows et pipeline qui échange des artefacts. La migration Monde
   #742 doit être reçue au préalable ; aucun ancien mode de carrière n'est relancé.
6. Organiser une fenêtre de bascule avec l'intégrateur #591 : actualiser le main,
   gérer le démarrage privé des nouveaux workflows et recevoir la CI PR exacte,
   fusionner par le gate existant, puis recevoir le SHA réellement fusionné.
   Les nouveaux jobs sont volontairement inactifs sur le dépôt public : il n'y a
   pas de bootstrap public auto-hébergé autorisé par cette préparation. La procédure
   administrative de transition doit être vérifiée sur place ; ne pas fusionner en
   considérant les jobs sautés comme une preuve verte, ni supprimer les protections.
7. Vérifier apps Codex/Claude, protections Pro privé, environnements et liens de
   livraison qui lisaient les sources publiquement. Les réglages d'administration
   et la visibilité ne sont pas modifiés par les commits de cette PR.

Le connecteur n'expose pas les mutations de visibilité, secrets ou facturation.
Le navigateur administratif n'a pas pu être utilisé. Le dépôt reste public.
Aucune dépense engagée, aucune recette PC exécutée, aucune fusion revendiquée.

## Sauvegarde indépendante à réaliser sur le PC
GitHub n'est pas l'unique sauvegarde. Prévoir une copie chiffrée et versionnée sur
un autre support choisi par Léo, avec essai de restauration : dépôts Git et branches,
actifs privés, sauvegardes du jeu et configuration de reprise. Aucun jeton ne doit
être sauvegardé en clair. Aucun support disponible n'est présumé ; aucune sauvegarde
n'a été créée dans cette session.

## Vérifications effectuées
YAML des 57 workflows, garde privée/forks et absence de runner hébergé pour 77 jobs.
Tests locaux verts : ci-pc-only, ci-report (37 verdicts), ci-sharding, ci-shard-replay,
ci-quick-check, ci-runs-watchdog, ci-run-metrics, release-gate, chat-release (46 cas),
auto-release (14 cas), pr-preflight. Les critères des gates ne sont pas relâchés.
Ces vérifications portent sur l'infrastructure, pas sur une recette matérielle ni
sur la batterie fonctionnelle entière. Brouillon jusqu'à réception sur le PC.

## Relevé conservé
docs/ci-usage-20261114.json documente 155 runs du workflow principal créés le 14/11 UTC,
13818,2 minutes de jobs, hors autres workflows ; les exécutions peuvent déborder sur
le jour suivant. Les coûts cloud hypothétiques de ce relevé ne sont plus un budget
proposé : la décision actuelle est calcul exclusivement personnel.

Modèle/effort effectifs non exposés ; recommandation GPT-6.1 Sol : moyen.
