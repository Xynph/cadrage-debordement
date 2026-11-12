# Fluidité et atelier de préparation du manager

Lot du 12 novembre 2026, depuis main `3cc02a337c4bf02153b6c2401ed847ffcdee060b`.
Autorisation de Léo : réduire les réponses du moteur et réaliser les trois
ajouts proposés dans l'audit. L'économie est réservée au chantier Claude #552.

## Ce que le manager peut faire

« Préparer la suite du club », depuis le Bureau ou Préparation, ouvre trois
parcours dans une fenêtre adaptée à la taille disponible :

- **Trois rencontres** : consulter les trois prochaines rencontres publiées,
  préparer 23 intentions par rencontre parmi les joueurs qualifiés, lire
  blessures actuelles, sélections confirmées et engagements de minutes.
  Une composition provisoire ne devient jamais la feuille officielle.
- **Effectif futur** : consulter l'effectif maintenant, à la fin de la saison
  et la saison suivante, ses postes, échéances et retours de prêts renseignés.
  Comparer jusqu'à huit hypothèses de prolongation, recrutement et promotion.
  Les hypothèses affichent coût initial, masse salariale hebdomadaire et
  engagement des contrats envisagés. Aucune signature ni dépense n'est appliquée.
- **Objectif tactique** : démarrer un suivi de touches ou mêlées conservées,
  ou de pénalités concédées. Les rencontres documentées après ce choix
  apportent leurs mesures et leurs événements détaillés lorsqu'ils existent.
  Une donnée absente reste inconnue ; un écart ne prouve pas une causalité.

Les intentions sont conservées par identifiants dans `S.managerPlanning`,
avec validation stricte à l'import. Elles sont isolées par saison et club.
L'absence de cette rubrique reste acceptée. Aucun vrai nom n'est ajouté par
ces intentions ; la présentation utilise les identités du modèle public.

Les scénarios démarrent pendant la saison courante : une durée d'une saison
finit cette saison (`season + years - 1`), selon la convention actuelle du jeu.
La fin de saison montre encore les contrats qui arrivent à échéance ; la
saison suivante les retire, sauf hypothèse qui les couvre encore. Prolonger
un joueur en prêt entrant ne constitue pas un transfert de propriété et n'est
pas proposé. Les prix et durées saisis restent des hypothèses à revalider.

## Fluidité : protocole négocié et cache de lecture

Le premier modèle reste complet. Godot demande ensuite un transport versionné
avec sa révision : le worker ne renvoie que les branches modifiées et les
chemins retirés. Un lecteur sans cette option reçoit toujours le protocole
historique. Une base absente ou incorrecte redonne un modèle complet.
Le réassemblage s'effectue sur le thread du pont ; l'interface reçoit toujours
un dictionnaire complet détaché. Aucun champ supprimé ou reçu transitoire ne
doit survivre par fusion implicite.

Le transport travaille après la présentation des packs et la frontière des
connaissances. Il ne consulte pas les notes cachées. Seules les consultations
`snapshot` réutilisent les projections VM pures ; toutes les autres commandes,
y compris refusées, invalident le cache. Les copies de lecture restent
indépendantes. Sauvegarde, fichiers externes de sécurité et packs ne sont pas
mis en cache comme des objets d'interface.

### Mesure Cloud

Carrière commune, club29, graine27, Node24.22.1 ; un essai local, sans garantie
de durée sur Windows. Avec les nouvelles projections, le modèle complet fait
5 515 185 octets. Une consultation inchangée négociée fait **115 octets**.
Les trois lectures chaudes mesurées avec cache prennent **228 à 271 ms** de
calcul moteur ; les trois lectures sans cache de cet essai, **512 à 549 ms**.
Le premier chargement, l'interface et les commandes qui modifient l'état ne
sont pas assimilés à ces lectures chaudes. Le temps total du banc inclut aussi
la sérialisation complète utilisée pour la comparaison des tailles.

[Mesures brutes](manager-planning-20261112/performance.json).

## Réception

- Régressions moteur ciblées : **26 contrôles réussis**, aucun ignoré :
  décisions, délégation transactionnelle, connaissances des joueurs, copies
  de sécurité/imports, presse, finances et calculs de transfert, ainsi que
  les premiers contrôles du nouveau lot.
- Après les corrections de revue : **17 contrôles ciblés réussis**, aucun
  ignoré (projections, worker réel, reprise/import et vrai stdio).
- Godot4.7.2 Linux : navigation **155/0**, priorités du Bureau **107/0**.
- Atelier complet, vrais menus → vrai pont → vrai worker : **34/0**, avec
  commandes d'intention, comparaison de l'état canonique et géométrie à
  1280×720 et1920×1080. Captures X11/llvmpipe ci-dessous.
- Deux recettes de composants Godot : réassemblage et parcours du dialogue,
  sans erreur de script ; la fixture du dialogue est une vraie carrière.
- Stage des ressources et contrôles de données existants exécutés ; aucune
  donnée du jeu ou ressource de Gabi n'est versionnée dans ce lot.

Ces comptes sont ceux de bancs distincts et se recouvrent ; ils ne sont pas
additionnés en un total de couverture. Les journaux complets restent dans
`/workspace/work/manager-planning-evidence-20261112` pendant cette session.
La CI de la PR et la réception Windows sont des vérifications séparées.

![Trois rencontres à1280×720](manager-planning-20261112/01-trois-rencontres-1280.png)
![Effectif futur à1280×720](manager-planning-20261112/02-effectif-futur-1280.png)
![Objectif à1280×720](manager-planning-20261112/03-objectif-1280.png)
![Objectif à1920×1080](manager-planning-20261112/04-objectif-1920.png)

## Revue et décisions

Une revue indépendante a relevé quatre problèmes importants : parent vide
résiduel après suppression, qualifications non revérifiées à l'import,
échéance contractuelle décalée d'une saison et prolongation d'un prêt entrant.
Ils ont été reproduits par des tests rouges puis corrigés. Les tests d'import
recalculent le checksum pour atteindre réellement les validateurs de domaine.
Les devis de prolongation et le retrait d'hypothèses périmées ont également été
corrigés. La réception graphique a révélé le typage flottant des nombres JSON
Godot : la comparaison des numéros de poste est désormais explicite.

Décisions prises :

- Cache limité à `snapshot`, pour éviter une projection périmée pendant une
  commande qui vérifie puis modifie l'état. Coût : les commandes modificatrices
  ne bénéficient pas de ce cache de lecture.
- Hypothèses contractuelles au départ de la saison courante, avec la même
  convention d'échéance que le moteur. Les engagements différés ne sont pas
  modélisés dans ce premier lot.
- Conservation des intentions dont la source a disparu, avec motif et retrait
  possible ; elles sont exclues des totaux. Aucun joueur absent n'est recréé.

## Limites

Pas d'installation sur PC pro ou personnel, pas de recette Windows, pas de
nouvelle qualification de longue carrière sur toutes les éditions. Le premier
modèle reste volumineux ; pagination et chargement des dossiers à la demande
restent des améliorations possibles. Les événements historiques absents ne
sont pas inventés. Le suivi tactique utilise la rétention déjà disponible,
au plus40 rencontres, dans la saison et le club courants. Les frais non saisis,
les revenus futurs et les décisions de recrutement non confirmées ne sont
pas des engagements financiers réels.

Les anciennes carrières personnelles de Léo sont des tests ; aucune migration
de ces parties n'est demandée. Les scénarios de compatibilité restent des
vérifications du moteur, sans exigence de conserver son ancien pack.
