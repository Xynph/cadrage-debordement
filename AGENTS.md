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

## Remontée automatique CI (PR)

- `Validation CI` reste la seule autorité technique de fusion, et les tests complets de PR sont inchangés.
- Sur PR issue de ce dépôt, le job final publie **un commentaire de verdict à la fin de l'exécution** (succès ou échec), uniquement si la PR est encore ouverte sur le même SHA. Ce commentaire est informatif : il ne permet pas la fusion et son échec n'annule pas le verdict CI.
- Ne pas sonder GitHub toutes les quelques secondes : laisser GitHub terminer, puis retrouver le verdict sur la PR ou dans les notifications GitHub. S'il est absent, consulter le contrôle natif `Validation CI` et utiliser `ci/release-gate.cjs` avant fusion.
- Ne pas annoncer une notification directement dans ChatGPT : GitHub n'a pas de canal de transmission automatique vers cette conversation.
