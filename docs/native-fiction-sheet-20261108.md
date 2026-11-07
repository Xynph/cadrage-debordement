# Déblocage des feuilles IA historiques — 8 novembre 2026

## Cause et correction

Sur les vrais ponts natifs aux graines 1 et 5, une blessure adverse produite
pendant J1 laisse respectivement un manque de demi de mêlée et de pilier droit
à J2. Le profil précédant le coup d’envoi reste valide. La construction du match
produisait ensuite un banc contenant `null` et seulement 22 joueurs désignés.
Le validateur refusait correctement cet état ; le pont restaurait carrière,
stockage et RNG. Ce refus bloquait la progression au début de J2.

`dist/rugby.js` raccorde maintenant la couverture IA existante
`CDFranceCareer.ensureAISheet` avant la construction d’une nouvelle rencontre
historique dont `aiRosterActive()` est vrai. Les deux participants IA sont
traités, y compris les rencontres simulées en arrière-plan. Le helper conserve
son exclusion du club humain. Le parcours France, déjà raccordé, est conservé.

Les marqueurs de gestion IA ne sont ni créés ni activés implicitement. Un ancien
format sans `aiRoster` conserve son comportement. Le nouveau raccord vérifie
l’existence du module et de son helper ; leur absence dans un ancien contexte
fiction ne provoque pas d’accès à `S.aiRoster.academies`. La conversion d’un
match historique déjà commencé, signalée par `legacy`, ne déclenche pas le
nouveau renfort. Le traitement antérieur de cette conversion en France reste
conservé. Aucun format de sauvegarde ni validateur n’a changé.

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
raccord trop large ; la garde de création corrige cette frontière. Les quatorze
groupes de vérification passent désormais :

- vrais ponts graines 1/5 : profil J1 sain rouvert, J2 réellement lancée, J3
  atteinte avec une continuation identique d’état et de RNG ; cas minimal 5
  `new_career → begin_match → delegate → finish_round → begin_match` ;
- couverture idempotente, aucun soin ni modification de joueur existant, de
  trésorerie immédiate ou d’historique ; salaire, contrat et événement vérifiés ;
- allocation finale de `managerSheet` : 23 identifiants uniques, joueurs
  disponibles et postes de titulaires/remplaçants éligibles ;
- deux participants IA couverts en arrière-plan, club humain exclu, promotion
  d’un espoir existant avant génération, collisions évitées dans les clubs,
  académies IA et humaine, marché et agents libres ;
- bornes 39/40/99/100, refus à 100 et rollback natif ;
- ancienne carrière inactive saine jouable sans migration, ancienne carrière
  carencée conservant son refus strict, conversion de live historique sans
  recrutement, contexte fiction sans module France ;
- chemin sans carence : état et RNG identiques au contexte sans helper ;
  parcours France/common, dont la conversion France préexistante, conservés ;
- export/import/redémarrage après renfort ; feuille falsifiée `null`/22 refusée
  malgré un checksum recalculé, sans mutation d’état, disque ou RNG ;
- véritable échec d’écriture sur disque pendant le coup d’envoi : rollback du
  renfort et de l’entraînement, erreur visible, puis reprise égale au contrôle.

Les deux fichiers `diagnostic-banc/seed-{1,5}/before-failure-profile.json`
conservés hors dépôt ont également été copiés et rouverts tels quels : le seul
`begin_match` lance J2 avec un renfort par carrière. Les octets des deux sources
restent inchangés. Le rapport local `native-fiction-sheet-preserved-profiles.json`
conserve leurs SHA-256 et les profils résultants.

Suites existantes exécutées avec succès : `rugby`, `match-rules`, `frontrow`,
`saves`, `v63-native-career-transactions`, `roster-foundation-versions` (véritable
export v1 S2 et continuation/RNG) et `france-saves`. Le premier lancement de
`france-saves` a échoué avant exécution parce que le dossier temporaire choisi
n’existait pas ; sa relance dans un dossier E: existant a été effectuée.

Ces vérifications utilisent Node sous Windows et le vrai pont moteur, ainsi que
les harnais VM existants. Elles ne constituent pas une réception de l’interface
Godot ni de son exécutable. La CI globale, la revue indépendante renforcée,
l’intégration et la publication relèvent de l’intégrateur. Aucun push ou
commentaire GitHub n’est effectué par ce lot local.
