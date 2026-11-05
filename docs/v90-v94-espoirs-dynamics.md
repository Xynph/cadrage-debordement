# V90–V94 — Vie des jeunes et mémoire du centre

## Valeur jouable

- **V90 · Révélations :** rapport déterministe des Espoirs sous-estimés, en progression forte, en stagnation ou simplement suivis. Les critères utilisent les vraies notes simulées, le potentiel et les minutes du championnat Espoirs V73.
- **V91 · Concurrence :** centres concurrents intéressés par les hauts potentiels, déterminés par un hachage stable par joueur, club et saison. Le manager peut fidéliser un joueur pour une dépense **fictive** et une hausse de moral. **Aucun transfert automatique**, aucune modification de DATA/LNR ni du marché central.
- **V92 · Spécialisation :** quatre programmes (puissance, vitesse, endurance, technique), jusqu’à trois décisions individuelles par saison. Bilan annuel : au plus un point de note, si le potentiel le permet, avec une baisse de condition plafonnée.
- **V93 · Entretiens :** promouvoir, prêter, garantir des minutes ou refuser. Le moral évolue immédiatement et les promesses sont évaluées à la clôture de saison, entraînant un bonus/malus. Les actions concrètes de promotion ou de prêt restent du ressort des modules V77/V78.
- **V94 · Héritage :** regroupement des diplômés des promotions V77 par saison et potentiel moyen. Les données historiques disponibles sont celles conservées par V77 (historique borné) ; ne pas présenter cette vue comme l’historique complet des 20 saisons antérieures.

## Technique

Module autonome : `dist/espoirs-dynamics-v90-v94.js` ; API `CDEspoirsDynamicsV90V94`. Stockage facultatif dans `state.v90to94` (version 1). Les anciennes sauvegardes restent acceptées : l’état est créé à la première utilisation. Les actions sont transactionnelles, avec rollback en cas d’échec du stockage. Les archives sont limitées à 12 saisons, les événements à 160 et les profils à 90.

Ne modifie aucun fichier de la compétition, du moteur, des transferts, du mod réel, des sauvegardes centrales ou du MATCH 3D.

## Tests

`node tests/v90-v94-espoirs-dynamics.cjs` vérifie les révélations, la convoitise simulée, le rollback des frais de fidélisation, les plans et la fatigue, les entretiens, la clôture idempotente, le JSON, l’import legacy, les données invalides et 16 transitions de saison. Les tests Node locaux de la version initiale ont réussi. La CI de la PR sur le HEAD exact est la preuve requise pour la version publiée.

## Intégration différée

Le fichier `dist/index.html` est réservé à V82–V85 (issue #73). **Ce lot ne l’édite pas.** Une fois cette réservation libérée, inclure `espoirs-dynamics-v90-v94.js` après V77–V89 dans la page de jeu, puis réaliser tests Chromium PC et tests natifs de sauvegardes anciennes / import-export / saisons successives avant READY. Le module est DRAFT tant que ce raccordement n’est pas fait.

L’univers alternatif reste fictif, sans nouveaux journalistes, clubs réels ni calendriers officiels. La convoitise est un événement de management simulé, pas une négociation réelle entre IA de clubs.
