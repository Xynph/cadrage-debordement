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

Deux comptes ChatGPT peuvent successivement être **producteur ou intégrateur**, mais **jamais actifs simultanément**. Un seul compte actif et un seul intégrateur désigné à la fois. Chaque prise de relais et fin de session est consignée dans l'issue #73. Le rôle d'intégrateur ne constitue jamais une autorisation de fusion : **Léo doit autoriser explicitement chaque PR**. GitHub, les protections serveur vérifiées et le release gate restent les sources d'autorité technique.

### À chaque nouvelle conversation ou reprise du développement

1. **Commencer par consulter le dépôt GitHub `Xynph/cadrage-debordement`**, avant de proposer ou d'effectuer des modifications. Examiner la branche principale, les derniers commits et leurs changements, les branches pertinentes, les pull requests ouvertes ou récemment fusionnées, ainsi que les consignes du présent `AGENTS.md`.
2. Reconstituer l'état réel du projet et les travaux précédents **directement depuis GitHub**. Ne jamais demander à l'utilisateur ce que l'autre compte ChatGPT a fait. Si les informations disponibles sur GitHub ne suffisent pas, signaler précisément ce qui manque sans inventer de modifications.
3. **GitHub est l'unique source de vérité du code et de l'avancement.** Ne jamais reprendre une copie locale ou un souvenir de conversation sans les confronter à la version actuelle du dépôt.
4. Partir de la dernière version pertinente. Toute modification de code ou de documentation passe par une branche dédiée et une PR. **Aucun push direct sur `main`**, même pour les modifications simples. La fusion est interdite sans autorisation explicite de Léo pour cette PR, contrôle officiel du HEAD SHA et du main actuels, CI valide et release gate sans bypass. Le compte producteur ne fusionne pas lors de la même session ; la reprise du rôle d'intégrateur exige une passation #73 et une revue explicite. Ne pas laisser un chantier annoncé comme terminé uniquement sur une branche non fusionnée.
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

## Gouvernance définitive — producteur et intégrateur unique (31 octobre 2026)

- **Compte développeur** : conçoit les fonctionnalités, produit des branches et PR, corrige ses tests et documente ses livraisons dans l'issue #73. **Aucune fusion ni push sur `main`.**
- **Compte intégrateur (ce compte)** : lit #73, examine les PR et dépendances, vérifie la valeur jouable, les sauvegardes et le dernier SHA de `main`, réalise les raccordements sur une branche d'intégration si nécessaire, exécute la CI complète, puis **est seul habilité par la gouvernance du projet à fusionner**.
- La fusion exige la PR non brouillon, l'absence de conflits, les tests ciblés et la validation complète `Tests JavaScript` / `Validation CI` sur la tête exacte ; après fusion, contrôler la CI `push` sur le SHA fusionné. En cas d'échec, **STOP et correction**.
- Les travaux indépendants peuvent se poursuivre simultanément, avec réservation de chemins dans #73. La fusion n'est jamais autorisée par le seul message d'une issue.
- La PR #75 (double intégration) est abandonnée et doit rester non fusionnée.

## Canal de coordination permanent — issue #73 (en vigueur)

**Salon partagé : https://github.com/Xynph/cadrage-debordement/issues/73**

Le compte développeur produit les PR ; le compte intégrateur unique est seul responsable des fusions dans `main`. Les sessions peuvent être simultanées sur des branches et fichiers distincts.

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
- Les règles de CI, vérification du dernier SHA et fusion réservée au compte intégrateur unique restent intégralement en vigueur.

## Mode de travail rapide — deux comptes ChatGPT (31 octobre 2026)

**Objectif prioritaire : réduire le délai entre la demande et un résultat concret, sans affaiblir les règles de fusion.**

- Les deux comptes restent ChatGPT (développeur producteur et intégrateur unique) ; aucun outil tiers n'est requis. Lire le contexte pertinent en **un lot de requêtes indépendantes**, une seule fois au début de la session : main, AGENTS.md, DEVELOPPEMENT.md, #73, PR concernées. Ne relire ensuite que les informations réellement modifiées.
- Préférer une **modification fonctionnelle bornée et testable** à plusieurs petites PR cosmétiques. Développer avec les tests ciblés disponibles, préparer le journal avec le code et publier une seule tête de PR aussi stable que possible ; ne pas ajouter de commits de documentation après la CI complète sans nécessité.
- **Jamais d'attente active** pour les workflows : ne pas relancer des lectures de statut ni télécharger les logs en boucle. Lire les logs en détail seulement en cas d'échec, d'incohérence ou de vérification spécifique indispensable. La CI se déclenche sur GitHub ; elle ne nécessite pas de scrutation continue de ChatGPT.
- Si la CI distante n'est pas encore achevée dans le tour de travail, **rendre immédiatement** le code et la PR publiés, les tests réellement exécutés et le statut « CI en attente ; non fusionnée ». Le prochain tour de l'intégrateur pourra vérifier la conclusion et fusionner si toutes les conditions sont réunies. Ne jamais déclarer un résultat futur comme acquis.
- Ne pas relancer de longues campagnes pour une documentation pure ou une UI isolée lorsque les filtres du dépôt les excluent légitimement ; **les tests complets de PR, le gate Validation CI et la vérification post-fusion restent obligatoires** selon les règles existantes.
- Conclure en français avec le résultat utile, les liens de PR/commit et les éventuels blocages, sans journal minute par minute des opérations techniques. Ne jamais masquer un test échoué.


### Alternance exclusive et protections requises — proposition d'activation

- **Règle de sécurité :** vérifier `main`, HEAD, PR ouvertes, réservations #73 et CI avant toute mutation. L'autre compte doit être inactif pendant toute la session. Le dernier message #73 n'est pas un verrou GitHub atomique.
- **Rôles :** chacun peut être producteur puis intégrateur lors d'une session distincte, jamais deux sessions actives ni deux intégrateurs en parallèle. Une PR développée par soi exige une revue indépendante documentée autant que possible.
- **Fusion :** uniquement après autorisation explicite de Léo ciblant numéro et HEAD de la PR. `/cd-check` ne fusionne pas ; `/cd-merge` exige autorisation et mêmes contrôles. Utiliser `ci/release-gate.cjs` et `docs/chat-release-gate.md` sans les modifier ni désactiver leurs protections. Vérifier les sept jobs post-fusion sur le SHA du nouveau main.
- **Protection serveur :** demander et vérifier des rulesets main : PR requise, CI à jour, pas de push direct, force-push ni bypass administrateur. Ne pas annoncer leur activation sans preuve. Merge queue seulement si compatible avec `merge_group`.
- **Interdiction d'activation implicite :** cette proposition n'active ni accès GitHub ni droit de fusion ; la gouvernance courante reste applicable tant que cette PR n'est pas approuvée, intégrée et annoncée dans #73.
- **Compte rendu :** un seul feu 🟢 (autonomie), 🟠 (message à l'autre compte), 🔴 (décision de Léo nécessaire) ; finir par un bouton cliquable dont le libellé est **la prochaine étape précise**, jamais seulement « Continuer ».
