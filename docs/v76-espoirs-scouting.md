# V76 — Marché Espoirs, détection et recrutement

## Fonctionnement joueur
- Les 44 identités de centres V75 participent au marché, y compris les centres ayant changé de division.
- Le manager contrôle le centre associé à son club en Élite, choisit un autre centre puis achète un rapport de détection pour 1 200 € de crédits fictifs.
- Chaque rapport révèle jusqu'à cinq talents, leur poste, leur niveau, leur potentiel et le montant minimal accepté face à la concurrence simulée des autres académies. Une offre suffisante recrute immédiatement le jeune : retrait réel de son centre, ajout effectif au centre du manager, conservation de l'identité, de la progression et du potentiel.
- Les prix et l'attractivité financière des 44 centres sont déterministes ; 12 rapports et 3 recrutements maximum par saison. Les centres vendeurs doivent conserver au moins 15 joueurs, et le centre acheteur ne peut dépasser 40 joueurs. Aucun nouveau joueur artificiel n'est créé.
- Les crédits V76 sont une **enveloppe fictive de formation** séparée de la trésorerie de l'équipe senior ; il ne s'agit pas de montants réels de clubs ni d'un modèle de transferts FFR homologué.

## Sauvegardes et transitions
- Champ facultatif `v76Scouting` (version 1), créé à la demande pour les sauvegardes anciennes ; mutation refusée en cas de structure V76 invalide.
- Comptes financiers par identité V75, réinitialisés à chaque changement de saison. Historique des recrutements borné à 4 saisons.
- Les effectifs modifiés sont recopiés dans `v75Movement.rosters` : V75 transporte ces jeunes lors des montées et descentes et au changement de saison. Le centre du manager répercute les recrues dans `development.academy` pour les outils de formation natifs.
- Une sauvegarde refusée fait revenir en arrière budget, effectifs et historique, et ne valide pas le recrutement.
- Un seul nouveau script est ajouté dans `dist/index.html`, après V75. Aucun changement aux compétitions, au moteur, à Rugby Réel, au calendrier officiel ou au MATCH 3D.

## Limites
Concurrence via seuils d'offres déterministes (pas de négociation en plusieurs tours), budget de centre indépendant (pas de débit du compte senior) et détection uniquement depuis l'interface Formation > dossiers. Les mutations d'effectifs sont testées mais aucune qualification native Windows n'est revendiquée.

## Tests
`node tests/v76-espoirs-scouting.cjs` : 44 centres, offres insuffisantes, refus de sauvegarde, recrutements réels, conservation du potentiel, budget, sérialisation, cinq transitions de saison et compatibilité ancienne sauvegarde. CI complète à recevoir sur le HEAD GitHub de la PR.
