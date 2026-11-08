# Déblocage des feuilles IA historiques — 8 novembre 2026

## Cause et correction

Sur les vrais ponts natifs aux graines 1 et 5, une blessure adverse produite
pendant J1 laisse respectivement un manque de demi de mêlée et de pilier droit
à J2. Le profil précédant le coup d’envoi reste valide. La construction du match
produisait ensuite un banc contenant `null` et seulement 22 joueurs désignés.
Le validateur refusait correctement cet état ; le pont restaurait carrière,
stockage et RNG. Ce refus bloquait la progression au début de J2.

Le premier raccord global de `createRugbyMatch` a aussi modifié les simulations
historiques fiction/LNR : leur parité avec la version `9044998e` a échoué dans
la CI de la PR #395. Le diagnostic isole la première divergence à J4 : deux
événements `emergency` nouveaux pour les clubs 1 et 12, puis des résultats,
états et tirages différents. Le golden reste inchangé. Le core
`dist/rugby.js` retrouve donc son raccord **France uniquement**, tel qu’avant ce
correctif. Les rencontres fiction/LNR du web et les simulations de fond
conservent leur comportement historique.

La commande `begin_match` du pont `native/engine/worker.cjs` réutilise désormais
`CDFranceCareer.ensureAISheet` uniquement pour son nouveau live historique,
lorsque `aiRosterActive()` est vrai. Elle intercepte localement la construction
du match pendant l’appel synchrone à `beginMatch`, puis restaure la fonction
d’origine dans un `finally` **côté hôte**, directement par la référence
`ctx.createRugbyMatch`. Le `finally` interne reste une défense supplémentaire,
mais une interruption `vm.runInContext` peut le sauter. Le rétablissement hôte
ne dépend donc d’aucune nouvelle exécution de VM. La couverture a lieu après les
contrôles de la feuille humaine et l’entraînement habituels, avant la création du live. Cela
conserve le dossier établi avant entraînement et évite de recruter pour une
blessure d’une semaine qui vient de guérir. Toute erreur reste dans le rollback
existant de carrière, stockage, RNG et horloge.

L’interception exclut `legacy`, les matchs automatisés, les paires sans club
humain et les modes France déjà traités par le core. Le helper conserve son
exclusion du club humain. Les autres IA ne reçoivent aucun renfort lors de ce
coup d’envoi ou de `finish_round`. Aucun drapeau ni option de survie n’est ajouté
à la sauvegarde. Les marqueurs IA ne sont ni créés ni activés implicitement.
Un ancien format sans `aiRoster` conserve son comportement. Le raccord natif
vérifie l’existence du module/helper. La conversion d’un match historique
commencé et le traitement antérieur France restent conservés. Aucun format de
sauvegarde ni validateur n’a changé.

## Effets de gestion et limites conservées

Le helper cherche d’abord un joueur éligible déjà présent à l’académie IA. À
défaut, il utilise sa génération déterministe et son contrôle des collisions
d’identifiants, puis inscrit un événement `emergency`. Les deux reproductions
créent chacune exactement un joueur `youth-12-1-500` au poste manquant. Le helper
est idempotent et ne consomme pas de RNG. Les joueurs existants, leurs blessures,
minutes, historique et la trésorerie immédiate sont conservés.

Le renfort créé porte un salaire de 2 000 € par semaine, inclus dans la masse
salariale utilisée par la gestion, et un contrat jusqu’à la saison 3. L’absence
de débit immédiat ne supprime pas ces charges futures. Le plafond préexistant
de promotion à 40 et le plafond du renfort à 100 n’ont pas été rapprochés : à
40, un renfort de secours peut encore porter l’effectif à 41 ; à 99, il peut
atteindre 100 ; à 100, une nouvelle carence produit l’erreur explicite et le
rollback natif complet. Ces bornes sont vérifiées sans modification économique.

Le profil de lois `fr-pro-2025` et la saison abstraite historique sont inchangés.
Le [référentiel rugby](rugby-rules-reference.md) et la
[loi 3 World Rugby](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/3-l-equipe/),
paragraphes 3.4–3.12, ont été consultés pour le cadrage. Les 23 joueurs désignés
constituent ici le format interne attendu par le moteur. Ce correctif n’en fait
pas une obligation réglementaire universelle et n’applique aucune variante M19.
Le jeune de secours, parfois âgé de 17 ans, demeure une abstraction de gestion ;
ce mécanisme ne certifie pas son admissibilité administrative ou médicale en
élite adulte, ni la conformité intégrale aux lois du rugby.

## Preuves ciblées

Le test `tests/native-fiction-sheet.cjs` a d’abord échoué sur le code de base
pour les deux graines, avec le refus d’incohérence attendu à J2. Un deuxième
rouge a isolé la conversion `legacy` qui ajoutait un joueur après un premier
raccord trop large. Le rouge CI de `france-parity` a ensuite été reproduit sur
la tête `2a43c898` : hash saison fiction réel `62b7aeb5…` contre `c7d469c5…`
attendu. Après le déplacement dans la transaction native, les dix-sept groupes de
vérification passent :

- vrais ponts graines 1/5 : profil J1 sain rouvert, J2 réellement lancée, J3
  atteinte avec une continuation identique d’état et de RNG ; cas minimal 5
  `new_career → begin_match → delegate → finish_round → begin_match` ;
- couverture idempotente, aucun soin ni modification de joueur existant, de
  trésorerie immédiate ou d’historique ; salaire, contrat et événement vérifiés ;
- allocation finale de `managerSheet` : 23 identifiants uniques, joueurs
  disponibles et postes de titulaires/remplaçants éligibles ;
- vraie commande native : seul l’adversaire reçoit le renfort ; une autre IA
  blessée et le club humain restent sans renfort, une feuille humaine invalide
  entraîne le refus et le rollback ; promotion d’un espoir existant avant
  génération, collisions évitées dans les clubs, académies IA et humaine,
  marché et agents libres ;
- bornes 39/40/99/100, refus à 100 et rollback natif ;
- ancienne carrière inactive saine jouable sans migration, ancienne carrière
  carencée conservant son refus strict, conversion de live historique sans
  recrutement, contexte fiction sans module France ;
- chemin sans carence : état et RNG identiques au contexte sans helper ;
  parcours France/common, dont la conversion France préexistante, conservés ;
- export/import/redémarrage après renfort ; feuille falsifiée `null`/22 refusée
  malgré un checksum recalculé, sans mutation d’état, disque ou RNG ;
- véritable échec d’écriture sur disque pendant le coup d’envoi : rollback du
  renfort et de l’entraînement, erreur visible, puis reprise égale au contrôle ;
- blessure d’une semaine guérie par l’entraînement : aucun renfort inutile ;
- identité de la fonction restaurée après succès, refus humain, exception du
  helper, panne disque et absence de rencontre humaine ; ce dernier cas simule
  les autres IA sans les renforcer. L’observation se fait dans une copie
  instrumentée du worker ; aucun hook de test n’est ajouté au produit ;
- véritable timeout VM : l’ancien `finally` interne ne s’exécute pas et laisse
  la fonction interceptée, même après une reprise réussie. Le test a échoué sur
  `53ae9f7` avant le correctif hôte. Il interrompt réellement une boucle qui a
  consommé un tirage et modifié la carrière, vérifie fonction d’origine,
  état/disque, puis compare la reprise et la délégation suivante au contrôle,
  RNG compris. Seule cette invocation de la copie de test reçoit un timeout
  d’une seconde ; le délai produit de 15 000 ms n’a pas changé. La reproduction
  indépendante au délai complet de quinze secondes a aussi été rejouée avant
  puis après correction : identité, état/disque et reprise sont désormais
  conservés. Ce travail bloquant est injecté pour tester la frontière ; aucune
  carrière ordinaire lente n’est prétendue.

`tests/france-parity.cjs` et ses goldens n’ont pas été modifiés. Création, match
délégué, saison, intersaison, export et RNG fiction **et** LNR sont à nouveau
identiques à `9044998e`. Pour la saison fiction, le hash `c7d469c5…` et le RNG
`2965174150` sont retrouvés.

Les deux fichiers `diagnostic-banc/seed-{1,5}/before-failure-profile.json`
conservés hors dépôt ont également été copiés et rouverts tels quels : le seul
`begin_match` lance J2 avec un renfort par carrière. Les octets des deux sources
restent inchangés. Le rapport local `native-fiction-sheet-preserved-profiles.json`
conserve leurs SHA-256 et les profils résultants.

Suites existantes réexécutées avec succès après le correctif de parité :
`france-parity`, `godot-engine`, `rugby`, `match-rules`, `frontrow`, `saves`,
`v63-native-career-transactions`, `roster-foundation-versions` (véritable export
v1 S2 et continuation/RNG) et `france-saves`. Lors du premier lot, un lancement
de `france-saves` avait échoué avant exécution parce que le dossier temporaire
choisi n’existait pas ; sa relance dans un dossier E: existant avait réussi.
Après la correction de timeout hôte, les dix-sept groupes natifs,
`france-parity`, `v63-native-career-transactions` et le pont `godot-engine` ont été
réexécutés avec succès.

Ces vérifications utilisent Node sous Windows et le vrai pont moteur, ainsi que
les harnais VM existants. Elles ne constituent pas une réception de l’interface
Godot ni de son exécutable (`godot-engine` indique explicitement ce runtime non
exécuté sans `CD_GODOT_EXECUTABLE`). La CI globale, la revue indépendante renforcée,
l’intégration et la publication relèvent de l’intégrateur. Aucun push ou
commentaire GitHub n’est effectué par ce lot local.
