# Passation automatique entre PRODUCTEUR et INTÉGRATEUR

Objectif : supprimer le copier-coller manuel des passations par Léo. La source de vérité reste GitHub : les PR, leurs SHA, GitHub Actions et l'issue [#73](https://github.com/Xynph/cadrage-debordement/issues/73).

## Déclenchement et livraison

Le workflow `producer-handoff.yml`, **exécuté sur le code de main**, réagit à `ready_for_review` et aux fins des workflows JavaScript / Chromium / carrières / audits connus. Aucune PR ne doit être fusionnée par ce workflow.

Le PRODUCTEUR publie sa PR et ses tests, puis la passe en **ready for review** après la réception des contrôles. Le workflow vérifie en lecture GitHub que :
- la PR est ouverte, non draft, dans le même dépôt, cible main et est `clean` ;
- le dernier run `Tests JavaScript` pour le HEAD exact est `completed/success`, avec **sept jobs uniques tous réussis** ;
- les autres workflows `pull_request` effectivement observés sur ce HEAD sont terminés avec succès (aucun rouge, pending ou cancelled) ;
- le SHA de l'événement correspond encore au HEAD de la PR.

Si toutes ces conditions sont réunies, le workflow publie automatiquement une **seule passation pour le couple PR/HEAD**, comportant numéro, SHA, liens vers chaque workflow et instructions de réception. Le marqueur `CD-AUTO-HANDOFF` est vérifié dans les commentaires paginés de #73 pour dédupliquer ; un groupe de concurrence sérialise les déclenchements d'un même SHA. Si la CI est incomplète, **aucune passation verte n'est créée** ; les prochains événements de CI ou une transition ultérieure vers ready-for-review permettent de revérifier.

## Sécurité et limites

Le workflow de notification utilise uniquement les API GitHub et un checkout du main **jamais du code de la PR**, avec permissions `actions:read`, `pull-requests:read`, `contents:read`, `issues:write`. Les commandes `/cd-check` et `/cd-merge` restent réservées au système officiel, avec autorisation spécifique de Léo sur numéro/HEAD. La passation **n'autorise aucun merge**. Les exigences du ruleset ne changent pas.

Le système publie une transmission automatique dans #73 et peut notifier les abonnés GitHub. **Il ne peut pas réveiller spontanément un compte ou une conversation ChatGPT**. L'INTÉGRATEUR doit consulter les passations dès sa prochaine reprise, ou avoir un agent de surveillance explicitement configuré pour lire #73. Les droits de notification GitHub n'accordent pas le droit de fusion.

L'activation ne commence **qu'après la fusion autorisée de la PR contenant ce workflow**. Tester l'installation sur une PR de validation ultérieure ; ne jamais affirmer que le transfert fonctionne en production avant un événement réel et un commentaire #73 observé.

## Coordination

Les réservations de fichiers et dépendances restent décrites dans #73. Une passation automatique ne remplace pas un diagnostic humain des sauvegardes, interfaces, risques de gameplay ou la réception finale du gate. Le PRODUCTEUR peut toujours consigner des preuves complémentaires manuellement ; Léo n'a pas à recopier ce message d'un compte à l'autre.
