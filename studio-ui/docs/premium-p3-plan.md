# Reprise Premium PC — plan du 7 novembre 2026

Objectif : poursuivre la direction artistique déjà demandée et validée par Léo : quatre écrans rugby éditoriaux, fonds photographiques IA, blasons et visages. Périmètre atelier seulement, même PR #372, sans fusion. Réservation #73 : 6699868628.

Base vérifiée : P2 `167b6723fd9d44286e16d974316748dacf221574` ; main `512e296467985d95284e1c3c3959b23e569019d2`. CI P2 #42315641272 SUCCESS. Penpot indisponible (aucune instance connectée). Aucun nouveau travail Penpot revendiqué.

## Étapes

- [x] Inspecter les captures P2 et vérifier sa CI dédiée 14/14 ; diagnostiquer les limites du navigateur local.
- [x] Produire un atlas photographique propre de neuf identités fictives et un fond de stade horizontal sans texte. Conserver les anciens assets ; intégrer les nouveaux sous des noms distincts.
- [x] Associer chaque identité à un portrait constant dans sa liste et son dossier ; associer les attributs au joueur sélectionné ; traiter la recherche vide. Rendre le bouton Bureau → Tactiques effectif.
- [x] Tester quatre pages à 1920×1080 et 1440×900 : pas de scroll global, images chargées et suffisamment définies, clavier, sélection et recherche. Vite PASS ; Storybook local bloqué par l'environnement, réception distante requise (voir rapport).
- [ ] Revue, publication sur la même branche avec contrôle du HEAD, réception CI et passation #73.

## Contrat

`Portrait` consomme un index stable 0…8 dans un atlas 3×3 ; la même identité garde le même index dans toutes ses représentations. Les données restent des fixtures et les photos des personnages fictifs générés. Les textes et chiffres restent en HTML.

## Points de revue

Visage coupé ou miniature agrandie ; mauvais portrait au changement de sélection ; recherche sans résultat incompréhensible ; bouton de préparation inactif ; débordement vertical à 1440×900. Les tests existants et de nouveaux parcours ciblés couvrent ces risques. Penpot et raccordement au jeu sont des limites explicites.
