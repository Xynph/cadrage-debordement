# Cadrage Débordement

Avant de modifier le comportement d’un match, d’un effectif, de la discipline ou
de la compétition, lire `docs/rugby-rules-reference.md`. Ce document conserve les
sources officielles, leurs dates d’application, les erreurs connues du moteur
et les vérifications restantes. Vérifier la loi exacte et la disposition de
compétition avant de coder. Le comportement actuel du jeu ou la réussite des
tests ne prouvent pas qu’une règle de rugby est correcte.

L’utilisateur souhaite une courte explication en français avant chaque phase de
travail. Poursuivre de manière autonome dans le périmètre demandé, sans lui
remettre systématiquement le jeu ni demander des confirmations répétées.
L’implémentation a été autorisée après l’audit des règles. Les évolutions et leurs
limites sont suivies dans les versions 7 à 16 du README.md. Terminer et publier
le lot autorisé, sans prétendre que toutes les règles du rugby sont implémentées.

Distinguer les lois, les dispositions françaises de compétition, les abstractions
volontaires et les détails non vérifiés. Fixer la saison simulée et l’édition des
règles avant d’appliquer une nouvelle loi. Ne jamais appliquer par défaut les
variantes amateurs, jeunes ou de rugby à sept au XV adulte d’élite.

Le dépôt GitHub `Xynph/cadrage-debordement` est la référence du projet. Vérifier
son état avant de modifier une copie locale et y enregistrer les évolutions.
Conserver la documentation et les explications destinées à Léo en français.
Avant d’intégrer des données réelles, consulter `docs/donnees-du-jeu.md` : la
trésorerie fictive actuelle ne doit pas être présentée comme un budget réel.

Pour la version portable, lire `offline/README.md`. Ne pas stocker les carrières
dans le dossier de l’exécutable et ne pas annoncer un test Windows natif si seul
le binaire croisé ou le lanceur Linux a été vérifié. Conserver les échecs
d’écriture visibles ; aucun repli silencieux vers un autre stockage.

## Continuité entre deux comptes ChatGPT — protocole obligatoire

Deux comptes ChatGPT interviennent comme développeurs de même niveau, **en alternance et jamais simultanément**. Aucun compte n'est le superviseur de l'autre. L'utilisateur alterne entre les comptes selon leurs quotas.

### À chaque nouvelle conversation ou reprise du développement

1. **Commencer par consulter le dépôt GitHub `Xynph/cadrage-debordement`**, avant de proposer ou d'effectuer des modifications. Examiner la branche principale, les derniers commits et leurs changements, les branches pertinentes, les pull requests ouvertes ou récemment fusionnées, ainsi que les consignes du présent `AGENTS.md`.
2. Reconstituer l'état réel du projet et les travaux précédents **directement depuis GitHub**. Ne jamais demander à l'utilisateur ce que l'autre compte ChatGPT a fait. Si les informations disponibles sur GitHub ne suffisent pas, signaler précisément ce qui manque sans inventer de modifications.
3. **GitHub est l'unique source de vérité du code et de l'avancement.** Ne jamais reprendre une copie locale ou un souvenir de conversation sans les confronter à la version actuelle du dépôt.
4. Partir de la dernière version pertinente. Pour une modification simple, une mise à jour directe de `main` est possible si elle est vérifiée ; pour un changement important ou risqué, utiliser une branche et une pull request, puis intégrer le travail validé. Ne pas laisser un chantier annoncé comme terminé uniquement sur une branche non fusionnée.
5. **Enregistrer chaque modification sur GitHub**, avec un message de commit explicite, puis vérifier le commit et le contenu effectivement publiés sur la branche visée. Une modification non publiée et vérifiée n'est pas terminée.
6. Exécuter les tests pertinents lorsque l'environnement le permet. Distinguer clairement les tests réussis, échoués et non exécutés ; ne jamais annoncer une validation qui n'a pas eu lieu.
7. En fin d'intervention, résumer en français les changements, les fichiers concernés, les références de commits et de pull requests, l'état des tests et les travaux restant à faire, pour que l'autre compte puisse reprendre sans perte de contexte.

Ce protocole s'applique à chaque session, même si l'utilisateur ne le rappelle pas explicitement. Il complète les autres consignes de ce fichier, notamment la vérification des règles de rugby avant tout changement du moteur.


### Journal de passation

À chaque reprise, lire également `DEVELOPPEMENT.md` après avoir vérifié les derniers changements sur GitHub. Ce journal consigne les travaux, décisions, problèmes connus, tests et priorités. À la fin de chaque chantier significatif, le mettre à jour, enregistrer cette mise à jour dans GitHub et vérifier le contenu publié. Si le journal et le code divergent, les commits et le code actuels prévalent.

## Procédure CI rapide et bornée (octobre 2026)

- Lire `main`, `AGENTS.md` et `DEVELOPPEMENT.md` **une seule fois** en début de chantier, en regroupant les requêtes indépendantes. Ne relire que les fichiers qui ont changé.
- Pendant le développement : tests ciblés ; un commit final par lot si possible, une PR, puis la CI complète de son dernier SHA. Éviter les commits cosmétiques après la dernière CI.
- Ne pas vérifier périodiquement les mêmes statuts : utiliser la page Actions ou `node ci/release-gate.cjs <PR>` une fois la CI achevée. Consulter les logs détaillés seulement si échec ou diagnostic nécessaire.
- Pour fusionner volontairement : `node ci/release-gate.cjs <PR> --merge` contrôle le SHA de la PR, le succès du workflow PR et de `Validation CI`, puis transmet le SHA attendu à GitHub. La fusion automatique native du dépôt reste désactivée ; **pas de contournement de la CI**.
- Après fusion : un contrôle unique du run `push` sur le SHA de fusion, avec toutes les suites. Si échec, diagnostiquer et corriger ; ne jamais déclarer la livraison totalement validée sans cette preuve.
- Écrire la passation et les mesures vérifiées dans le même commit que l'évolution quand c'est possible ; ne pas lancer un nouveau cycle CI uniquement pour recopier les IDs des workflows.

## Remontée automatique CI native

- Le job `Validation CI` publie un verdict, le SHA et le lien vers l'exécution **dans le résumé et les annotations GitHub Actions**. Aucun webhook, commentaire de PR, workflow additionnel ou permission d'écriture n'est nécessaire.
- La tentative initiale de commentaire de PR dans cette PR a échoué : GitHub a refusé l'écriture avec `Resource not accessible by integration`. Ne pas prétendre que des commentaires ou notifications de conversation sont envoyés.
- La conclusion native du contrôle `Validation CI` fait autorité ; le résumé n'autorise pas une fusion. Dernier SHA et CI complète restent exigés, puis CI post-fusion sur `main`.
- Ne pas faire de sondages répétitifs : se fier aux contrôles natifs GitHub et consulter la page de résultat une fois terminée. GitHub peut notifier les participants selon leurs réglages. Aucun message n'est envoyé automatiquement dans ChatGPT.

## Coordination prioritaire entre les deux comptes — consigne actualisée au 31 octobre 2026

En cas de contradiction avec l'ancien protocole d'alternance ci-dessus, suivre la répartition explicitement décidée par l'utilisateur : **le compte principal est seul responsable des validations finales et des fusions dans `main`** jusqu'à nouvel ordre ; l'autre compte développe les fonctionnalités hors match sur des branches et PR distinctes et **ne les fusionne pas**. Les PR en brouillon restent en préparation : ne jamais les déclarer prêtes ou les fusionner sans vérification de leur état réel et coordination effective avec leur auteur. Privilégier des intégrations jouables et testées plutôt que la multiplication des versions isolées. Les protections GitHub et la validation CI sur le dernier SHA demeurent obligatoires.


## Canal de coordination permanent — issue #73 (proposition, applicable après fusion)

**Salon partagé : https://github.com/Xynph/cadrage-debordement/issues/73**

Cette section précise le fonctionnement en parallèle déjà autorisé par l'utilisateur et prévaut sur l'ancienne formule « jamais simultanément » lorsqu'il existe des branches, périmètres et fichiers distincts. Elle ne change pas la règle : le compte principal reste le seul responsable des fusions dans `main`.

### Ouverture obligatoire d'une session
1. Vérifier le dernier `main`, les changements et PR/CI récents ; lire `AGENTS.md` et `DEVELOPPEMENT.md`.
2. Lire l'issue #73 **et ses commentaires récents** avant tout développement. Vérifier les revendications importantes dans les branches et PR : les commentaires ne sont pas une preuve de publication.
3. Déclarer dans #73 une **PRISE DE CHANTIER** avec rôle du compte, date UTC, branche, SHA de base, mission, chemins exacts réservés, chemins exclus et dépendances. Utiliser le modèle inscrit dans l'issue.
4. En cas de recouvrement de fichiers avec un chantier déclaré actif, s'arrêter sur ces fichiers et demander un arbitrage ; continuer uniquement sur une zone indépendante.
5. Si l'API de commentaires est indisponible ou renvoie une erreur d'autorisation, **ne jamais prétendre avoir envoyé un message** ; signaler le blocage et publier l'état dans la PR. Le titulaire doit vérifier les droits du connecteur.
6. Les réservations de fichiers sont **des conventions et non des verrous Git**. Recontrôler le SHA réel de la branche avant push, revue et fusion.

### Messages et fin de session
- Les échanges `MESSAGE / QUESTION`, `PRISE DE CHANTIER` et `PASSATION` suivent les formats décrits dans #73.
- Avant de terminer, publier une PASSATION dans #73 : commits et PR, chemins réellement modifiés, tests réussis/échoués/non exécutés, CI, risques, sauvegardes, décisions et fichiers libérés.
- Ne pas présenter la coordination comme une communication instantanée autonome : chaque compte intervient lorsqu'une session est active, sans surveillance continue.
- Garder #73 ouverte ; ne jamais y publier de jeton, clé API, sauvegarde personnelle ou secret.
- Pour les travaux de l'autre compte, prendre les **derniers commentaires** et le **GitHub actuel** comme références, non un ancien rapport de chat.
- Les règles de CI, vérification du dernier SHA et fusion réservée au compte principal restent intégralement en vigueur.


## Projet de double intégration — non activé sans décision et protections GitHub

La gouvernance permettant aux deux comptes de fusionner leurs propres PR est proposée dans `docs/gouvernance-deux-integrateurs.md`. **Tant que le propriétaire n'a pas approuvé et activé les protections de `main`, le compte principal reste le seul responsable des fusions.** Cette section ne constitue pas une autorisation implicite.

Prérequis à une transition : PR approuvée, protection/ruleset réellement appliqué à `main` (aucun bypass, contrôles obligatoires à jour et PR exigée), CI `Tests JavaScript / Validation CI` verte sur le dernier SHA, sauvegardes compatibles et revue des conflits. Privilégier la merge queue de GitHub, si disponible et correctement configurée. Les réservations de l'issue #73 ne sont pas des verrous. En l'absence de preuve d'une protection serveur stricte : **STOP, aucune fusion supplémentaire**. Après chaque fusion, vérifier la CI push sur le SHA résultant et avertir l'autre compte dans #73.
