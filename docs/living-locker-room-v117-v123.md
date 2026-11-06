# V117–V123 — Monde vivant & Vestiaire (lot PRODUCTEUR)

## Audit du code avant développement (main fd1727ef7fa55d473a4d77ef527ace9d469303d0)

- **Déjà présent :** satisfaction et promesses V36/V37 (effets sur les minutes), V64 climat du vestiaire et entretiens individuels, V65 réunion de staff, V70 duos/rivalités/leadership et bonus sportifs bornés, V60 relations presse, V101–V116 raccordées sur main via PR #328.
- **Manque réel :** profils humains stables et lisibles, événements déclenchés par la situation de l'effectif, traçabilité des arbitrages et engagements pouvant réussir/échouer plus tard.
- **Limite volontaire :** ne pas créer de deuxième gestionnaire des promesses V36, ne pas recopier les liens V70, ne pas retoucher le moteur, la sauvegarde centrale, la simulation officielle ou les clubs adverses.

## Livraison

- **V117** : profil de personnalité stable par identifiant fictif, indice de leadership dérivé des caractéristiques existantes (pas de données biographiques prétendument réelles).
- **V118** : sélection déterministe d'un événement hebdomadaire selon satisfaction, fatigue, âge/temps de jeu, contrat, leadership, avec anti-répétition des joueurs.
- **V119** : trois arbitrages exclusifs : écouter, cadrer, responsabiliser.
- **V120** : conséquences directes bornées sur satisfaction individuelle, moral collectif et confiance de direction.
- **V121** : engagement optionnel de 60 minutes sur deux semaines après responsabilisation ; vérification automatique via le temps de jeu déjà enregistré, suspension en cas de blessure.
- **V122** : historique persistant plafonné à 80 événements, engagements plafonnés à 30, aucun écrasement rétroactif des sauvegardes.
- **V123** : panneau Bureau du manager, messages au staff et retour lisible des conséquences. Une décision hebdomadaire hors match uniquement.

## Compatibilité et implémentation

Le fichier `dist/living-locker-room-v117-v123.js` est chargé après les modules actuels du Bureau et avant MATCH 3D. Le module s'appuie sur `managerOffice`, `managerWeek`, `managerMessage`, `save` et `render` ; il ne remplace pas le fonctionnement des autres modules. Le champ facultatif `livingLockerRoom` n'est créé **que lors d'une décision**. L'affichage seul ne modifie pas l'état : anciennes sauvegardes acceptées sans migration forcée. Les effets sauvegardés sont les mêmes champs déjà utilisés dans les autres systèmes. Les décisions refusent une sauvegarde en échec et restaurent la situation initiale.

Les noms et personnalités sont simulés ; pas de revendication de tempérament réel des joueurs du mod Rugby Réel. Aucune modification de `world-data.js`, DATA/LNR, calendrier, MATCH 3D, R&D ou du gate.

## Validation attendue

- `node --check dist/living-locker-room-v117-v123.js`
- `node tests/living-locker-room-v117-v123.cjs` : déterminisme, compatibilité ancienne sauvegarde, choix, suivi, refus de doublon, rollback en cas d'échec de stockage, persistance JSON, idempotence et carrière longue.
- CI GitHub Tests JavaScript : classification + 5 suites + Validation CI sur HEAD exact.
- Réception Chromium PC du Bureau et des boutons : **non incluse dans le lot de tests dédié** ; nécessaire avant toute qualification définitive READY par l'intégrateur. Le module ne prouve pas que tous les scénarios sont ergonomiques ou parfaitement équilibrés.

## Dépendances et gouvernance

Branche dédiée sans reprise des PR #325/#326/#327 DRAFT et sans modification de #332. PR maintenue **DRAFT**, pas de gate ni fusion PRODUCTEUR. Réservation puis passation dans #73.
